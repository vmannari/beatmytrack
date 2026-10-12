"""Read-only review of the owner-linked staging console; never log credentials."""

import hashlib
import json
import os
import subprocess
import sys
import urllib.error
import urllib.request
from datetime import datetime, timezone
from pathlib import Path

from playwright.sync_api import sync_playwright

ROOT = Path(__file__).resolve().parents[3]
OUTPUT = Path(__file__).resolve().parent
URL = "https://bmt-stg-e7a444ab-api-tzgxkrwzva-ew.a.run.app"
CONFIG_DIR = ROOT / ".tools/gcp-staging"


def main():
    sys.stdout.reconfigure(encoding="utf-8")
    config = json.loads((CONFIG_DIR / "config.json").read_text())
    os.environ["CLOUDSDK_CORE_CUSTOM_CA_CERTS_FILE"] = str(CONFIG_DIR / "windows-trust.pem")

    def cloud(*args):
        result = subprocess.run(
            [*config["gcloud"], "--project=" + config["project"], *args],
            capture_output=True, text=True, check=False,
        )
        if result.returncode:
            raise RuntimeError("Read-only cloud command failed; exit " + str(result.returncode))
        return result.stdout

    service = json.loads(cloud(
        "run", "services", "describe", "bmt-stg-" + config["owner"][:8] + "-api",
        "--region=" + config["region"], "--format=json",
    ))
    assert service["status"]["url"] == URL, "Linked service ownership differs"
    env = {
        row["name"]: row
        for row in service["spec"]["template"]["spec"]["containers"][0]["env"]
    }
    binding = env["BMT_ADMIN_OWNER_KEY"]["valueFrom"]["secretKeyRef"]
    credential = cloud(
        "secrets", "versions", "access", binding["key"], "--secret=" + binding["name"],
    ).strip()
    assert len(credential) >= 32, "Configured credential is unavailable"

    def get(path, authenticated=False):
        headers = {"Authorization": "Bearer " + credential} if authenticated else {}
        request = urllib.request.Request(URL + path, headers=headers, method="GET")
        try:
            with urllib.request.urlopen(request, timeout=30) as response:
                return response.status, response.read(), response.headers.get("X-Request-ID")
        except urllib.error.HTTPError as error:
            return error.code, error.read(), error.headers.get("X-Request-ID")

    def api(path):
        status, raw, _request_id = get("/v1/admin/" + path, True)
        assert status == 200, (path, status)
        return json.loads(raw)

    report = {
        "observed_at": datetime.now(timezone.utc).isoformat(),
        "url": URL,
        "read_only": True,
        "service_settings": {
            name: env.get(name, {}).get("value", "absent")
            for name in ("BMT_ENVIRONMENT", "BMT_OBJECT_BACKEND", "BMT_PURCHASE_SIMULATION_ENABLED")
        },
        "admin_access": {
            "owner_configured": bool(env.get("BMT_ADMIN_OWNER_KEY")),
            "analyst_configured": bool(env.get("BMT_ADMIN_ANALYST_KEY")),
            "unauthenticated_overview_status": get("/v1/admin/overview")[0],
        },
        "assets": {},
    }
    for name in ("index.html", "app.js", "commerce.js", "style.css"):
        path = "/admin" if name == "index.html" else "/admin/assets/" + name
        status, raw, _request_id = get(path)
        assert status == 200
        report["assets"][name] = {
            "bytes": len(raw), "sha256": hashlib.sha256(raw).hexdigest(),
            "matches_workspace": raw == (ROOT / "backend/bmt_backend/admin_ui" / name).read_bytes(),
        }
    bootstrap_status, bootstrap, _request_id = get("/v1/bootstrap")
    assert bootstrap_status == 200
    bootstrap = json.loads(bootstrap)
    report["bootstrap"] = {
        key: bootstrap.get(key)
        for key in ("purchase_simulation", "admin_console_configured", "test_drivers", "discovery_paging_version")
    }
    report["overview"] = api("overview?days=7")
    health = api("competition-health")
    report["health"] = {
        key: health.get(key) for key in (
            "status", "active_workers", "available_workers", "draining_workers", "stopped_workers",
            "queue_depth", "pending_races", "pending_track_validations", "oldest_age_seconds",
            "failed_last_5_minutes", "rejected_last_5_minutes",
            "infrastructure_failure_rate_last_5_minutes", "completion_latency_seconds_last_5_minutes",
            "storage_backend", "storage_free_bytes", "backup",
        )
    }
    products = api("products")
    report["products"] = {"editable": products["editable"], "items": products["items"]}
    purchases = api("purchases?limit=1")
    report["purchases"] = {
        "page_count": len(purchases["items"]), "has_next_page": bool(purchases["next_cursor"]),
    }
    report["player_projection_fields"] = []
    players = api("entities/players?limit=1")
    if players["items"]:
        report["player_projection_fields"] = sorted(players["items"][0])

    (OUTPUT / "review.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    with sync_playwright() as playwright:
        browser = playwright.chromium.launch(
            executable_path="C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe", headless=True,
        )
        page = browser.new_page(viewport={"width": 1600, "height": 1100}, device_scale_factor=1)
        errors = []
        page.on("pageerror", lambda error: errors.append(str(error)))
        page.goto(URL + "/admin#overview", wait_until="networkidle")
        page.locator("#key").fill(credential)
        page.get_by_role("button", name="Connect", exact=True).click()
        page.get_by_role("heading", name="The game, at a glance.").wait_for()
        observations = {}
        titles = {
            "overview": "The game, at a glance.",
            "analytics": "Driving analytics",
            "economy": "Purchases & catalog",
            "system": "System & access",
            "system/access": "System & access",
        }
        for route, title in titles.items():
            if route != "overview":
                with page.expect_response(lambda response: "/v1/admin/overview?" in response.url):
                    page.evaluate("route => location.hash = route", route)
            page.get_by_role("heading", name=title, exact=True).wait_for()
            page.wait_for_load_state("networkidle")
            text = page.locator("#main").inner_text()
            observations[route] = {
                "title": page.locator("#main h1").inner_text(),
                "error": page.locator("#main .console-error").count() > 0,
                "gcs_free_capacity_rendered_as_zero": "storage free gib\n0" in text.lower(),
            }
            page.screenshot(path=str(OUTPUT / (route.replace("/", "-") + ".png")), full_page=True)
        page.evaluate("location.hash='analytics'")
        page.get_by_role("heading", name="Driving analytics", exact=True).wait_for()
        with page.expect_response(lambda response: "/v1/admin/overview?days=90" in response.url):
            page.locator("#days").select_option("90")
        page.get_by_role("heading", name="Driving analytics", exact=True).wait_for()
        page.wait_for_load_state("networkidle")
        observations["analytics_90_days"] = {
            "rendered_bars": page.locator(".console-bar").count(),
            "caption": page.locator(".console-chart + .console-note").inner_text(),
        }
        page.screenshot(path=str(OUTPUT / "analytics-90-days.png"), full_page=True)
        page.locator("#logout").click()
        assert page.locator("#key").input_value() == ""
        browser.close()
        report["browser"] = {"routes": observations, "javascript_errors": errors, "lock_clears_key": True}

    (OUTPUT / "review.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(report, indent=2))


if __name__ == "__main__":
    main()
