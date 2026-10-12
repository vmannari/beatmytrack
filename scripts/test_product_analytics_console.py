"""Isolated Studio product-analysis and request-budget browser acceptance.

Historical fixture observations go through authenticated in-process HTTP with
an explicit ingestion-clock fixture and the real bounded metric projector.
The browser reads the resulting prepared endpoint. No remote service or mobile
collection is exercised.
"""

import argparse
import json
import secrets
import socket
import subprocess
import sys
import time
from pathlib import Path
from uuid import uuid4

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "backend"))
sys.path.insert(0, str(ROOT / "backend/tests"))


def serve(folder, port):
    import uvicorn
    from test_domains import FakeVerifier

    from bmt_backend.app import create_app
    from bmt_backend.config import Settings
    from bmt_backend.migrate import upgrade

    config = json.loads((folder / "config.private.json").read_text())
    settings = Settings(
        environment="development",
        dev_auth_enabled=True,
        dev_auth_key=config["development"],
        test_drivers_enabled=True,
        telemetry_enabled=True,
        admin_owner_key=config["owner"],
        admin_analyst_key=config["analyst"],
        database_url="sqlite:///" + (folder / "database.sqlite").as_posix(),
        object_dir=str(folder / "objects"),
        rate_limit_per_minute=10000,
    )
    app = create_app(settings, verifier=FakeVerifier())
    upgrade(app.state.engine)
    seed_observations(app, config, folder)
    uvicorn.run(app, host="127.0.0.1", port=port, log_level="warning")


def seed_observations(app, config, folder):
    from fastapi.testclient import TestClient

    from bmt_backend import telemetry
    from bmt_backend.identity_models import Player
    from bmt_backend.product_analytics import project_pending

    observed = int(time.time())
    today = observed // 86400
    day = 86400
    sessions = [str(uuid4()), str(uuid4()), str(uuid4())]
    at = telemetry.now
    try:
        with TestClient(app) as client:
            tokens = []
            for index, name in enumerate(("Analytics driver", "Analytics artificial", "Analytics new driver")):
                login = client.post("/v1/auth/development",
                    headers={"X-Dev-Auth-Key": config["development"]},
                    json={"subject": "analytics-fixture-" + str(index), "display_name": name})
                login.raise_for_status()
                tokens.append(login.json())
            with app.state.session_factory() as session:
                session.get(Player, tokens[1]["player"]["id"]).is_test_driver = True
                session.commit()
            sequence = [0, 0, 0]

            def batch(index, timestamp, names):
                telemetry.now = lambda: timestamp + 30
                events = []
                for offset, (name, properties) in enumerate(names):
                    sequence[index] += 1
                    events.append({
                        "id": str(uuid4()), "name": name, "occurred_at": timestamp + offset,
                        "session_id": sessions[index], "seq": sequence[index],
                        "monotonic_ms": sequence[index] * 1000, "properties": properties,
                    })
                result = client.post("/v1/telemetry/batches",
                    headers={"Authorization": "Bearer " + tokens[index]["access_token"]},
                    json={"schema": telemetry.SCHEMA, "purpose_policy": telemetry.POLICY,
                          "build_id": "owned-browser-fixture", "platform": "windows", "events": events})
                result.raise_for_status()
                assert all(row["status"] == "accepted" for row in result.json()["events"])
                duplicate = client.post("/v1/telemetry/batches",
                    headers={"Authorization": "Bearer " + tokens[index]["access_token"]},
                    json={"schema": telemetry.SCHEMA, "purpose_policy": telemetry.POLICY,
                          "build_id": "owned-browser-fixture", "platform": "windows", "events": events})
                duplicate.raise_for_status()
                assert all(row["status"] == "duplicate" for row in duplicate.json()["events"])
                return project_pending(app.state.session_factory, limit=500, at=timestamp + 31)

            origin = (today - 8) * day + 4 * 3600
            version_id = str(uuid4())
            challenge_id = str(uuid4())
            for index in (0, 1):
                names = [(name, {}) for name in
                         ("app_first_open", "menu_ready", "race_attempt", "race_started")]
                names.append(("race_started", {}))  # A pre-finish retry is not a second voluntary race.
                if index == 0:
                    names.append(("race_finished", {}))
                    names.append(("race_started", {}))
                    names.extend([
                        ("car_exposed", {"car_id": "compact"}),
                        ("car_selected", {"car_id": "compact"}),
                        ("track_exposed", {"biome": "desert", "car_id": "compact"}),
                        ("track_exposed", {"biome": "desert", "car_id": "compact"}),
                        ("track_selected", {"biome": "desert", "car_id": "compact"}),
                        ("editor_opened", {"biome": "desert"}),
                        ("draft_saved", {"biome": "desert"}),
                        ("publish_requested", {"biome": "desert"}),
                        ("store_opened", {}),
                        ("offer_exposed", {"product_id": "creator_slot_1"}),
                        ("offer_exposed", {"product_id": "creator_slot_1"}),
                        ("purchase_requested", {"product_id": "creator_slot_1"}),
                        ("challenge_opened", {"challenge_id": challenge_id}),
                        ("challenge_joined", {"challenge_id": challenge_id}),
                        ("challenge_created", {"challenge_id": challenge_id}),
                        ("share_clicked", {"challenge_id": challenge_id}),
                        ("collection_summary", {"dropped_events": 4, "rejected_events": 2,
                                                "persistence_failures": 1}),
                    ])
                batch(index, origin + index * 50, names)
            telemetry.now = lambda: origin + 211
            with app.state.session_factory() as session:
                telemetry.append_server_event(session, "track_published", str(uuid4()),
                    tokens[0]["player"]["id"],
                    {"biome": "desert", "track_version_id": version_id,
                     "owner_id": tokens[0]["player"]["id"], "published_at": origin + 200},
                    occurred_at=origin + 200)
                telemetry.append_server_event(session, "race_accepted", str(uuid4()),
                    tokens[0]["player"]["id"], {"car_id": "compact"}, occurred_at=origin + 210)
                telemetry.append_server_event(session, "race_accepted", str(uuid4()),
                    tokens[1]["player"]["id"],
                    {"car_id": "compact", "track_version_id": version_id,
                     "owner_id": tokens[0]["player"]["id"], "published_at": origin + 200},
                    occurred_at=origin + 210)
                session.commit()
            project_pending(app.state.session_factory, limit=500, at=origin + 212)
            batch(0, (today - 7) * day + 4 * 3600, [("session_started", {"reason": "launch"})])
            for index in (0, 1):
                batch(index, (today - 1) * day + 4 * 3600, [("session_started", {"reason": "launch"})])
                batch(index, max(today * day, observed - 60),
                      [("session_started", {"reason": "launch"})])
            batch(2, max(today * day, observed - 60),
                  [("app_first_open", {}), ("menu_ready", {})])
            project_pending(app.state.session_factory, limit=500, at=observed)
    finally:
        telemetry.now = at
    (folder / "fixture.json").write_text(json.dumps({
        "since": (today - 9) * day, "until": (today + 1) * day,
        "seed": "Authenticated TestClient HTTP; ingestion clock fixture; real prepared projector",
    }))

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--serve", type=Path)
    parser.add_argument("--port", type=int)
    parser.add_argument("--output", type=Path, default=ROOT / "docs/evidence/telemetry-analysis-2026-10-11")
    args = parser.parse_args()
    if args.serve:
        serve(args.serve, args.port)
        return

    import httpx
    from playwright.sync_api import sync_playwright

    folder = ROOT / "build" / ("product-analytics-browser-" + uuid4().hex[:8])
    folder.mkdir(parents=True)
    args.output.mkdir(parents=True, exist_ok=True)
    config = {name: secrets.token_urlsafe(32) for name in ("owner", "analyst", "development")}
    (folder / "config.private.json").write_text(json.dumps(config))
    with socket.socket() as reservation:
        reservation.bind(("127.0.0.1", 0))
        port = reservation.getsockname()[1]
    base = f"http://127.0.0.1:{port}"
    checks, errors, requests = [], [], []
    server = None
    with (folder / "server.log").open("w", encoding="utf-8") as log:
        try:
            server = subprocess.Popen(
                [sys.executable, str(Path(__file__).resolve()), "--serve", str(folder), "--port", str(port)],
                stdout=log, stderr=log, creationflags=subprocess.CREATE_NO_WINDOW,
            )
            with httpx.Client(base_url=base, timeout=10) as http:
                for _attempt in range(100):
                    if server.poll() is not None:
                        raise RuntimeError("Owned analytics fixture failed; inspect private server.log")
                    try:
                        if http.get("/health").status_code == 200:
                            break
                    except httpx.ConnectError:
                        pass
                    time.sleep(0.1)
                else:
                    raise RuntimeError("Owned fixture did not become ready")
                dates = json.loads((folder / "fixture.json").read_text())
                query = f"since={dates['since']}&until={dates['until']}"
                expected_response = http.get("/v1/admin/product-analytics?" + query,
                    headers={"Authorization": "Bearer " + config["owner"]})
                expected_response.raise_for_status()
                response = expected_response.json()
                assert response["period_active_players"] == response["weekly_active_players"] == 3
            with sync_playwright() as playwright:
                browser = playwright.chromium.launch(
                    headless=True,
                    executable_path="C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe",
                )
                page = browser.new_page(viewport={"width": 1440, "height": 900})
                page.on("pageerror", lambda error: errors.append(str(error)))
                page.on("request", lambda request: requests.append(request.url)
                        if "/v1/admin/" in request.url else None)
                failure = [False]
                hold = [False]
                deferred = []

                def prepared(route):
                    if hold[0]:
                        deferred.append(route)
                    elif failure[0]:
                        route.fulfill(status=503, json={"detail": "Owned analytics query failure"})
                    else:
                        route.continue_()

                page.route("**/v1/admin/product-analytics?*", prepared)
                original_route = "#product?" + query
                page.goto(base + "/admin" + original_route)
                page.fill("#key", config["owner"])
                page.locator("#login button").click()
                page.get_by_role("heading", name="Product analytics", exact=True).wait_for()
                assert len(requests) == 1 and "/product-analytics?" in requests[0], requests
                assert page.locator("#pa-dau").inner_text() == "3"
                assert page.locator("#pa-wau").inner_text() == "3"
                assert page.locator("#pa-period-active").inner_text() == "3"
                checks.append("Product view reads exactly one prepared bundle and no operational overview")

                page.locator(".studio-chart-data summary").click()
                rows = page.locator("#pa-daily-table tbody tr")
                assert "Not observed" in rows.nth(0).inner_text()
                assert rows.nth(3).locator("td").nth(0).inner_text() == "0"
                assert "In progress" in rows.last.inner_text()
                assert "50.0%" in page.locator("#pa-retention-table tbody tr").nth(0).inner_text()
                assert "100.0%" in page.locator("#pa-retention-table tbody tr").nth(0).inner_text()
                assert page.locator("#pa-retention-table tbody tr").last.get_by_text("Not mature").count() == 2
                assert "50.0%" in page.locator("#pa-first-race-funnel").inner_text()
                assert page.locator("#pa-first-race-funnel .pa-step-name").last.inner_text() == "Second voluntary race"
                assert page.locator("#pa-first-race-funnel .pa-step-count").last.inner_text().startswith("1")
                assert page.locator("#pa-creator-funnel .pa-step-count").last.inner_text().startswith("1")
                assert "compact" in page.locator("#pa-car-choices").inner_text()
                car_row = page.locator("#pa-car-choices tbody tr").filter(has_text="compact")
                assert car_row.locator("td").nth(0).inner_text() == "1"
                assert car_row.locator("td").nth(1).inner_text() == "1"
                assert "desert" in page.locator("#pa-biome-choices").inner_text()
                checks.append("Coverage, maturity and second voluntary race preserve observed versus eligible meanings")

                assert page.locator("#pa-store-opened").inner_text() == "1"
                store_offer = page.locator("#pa-store-offers tbody tr").filter(has_text="creator_slot_1")
                assert store_offer.locator("td").nth(0).inner_text() == "2"
                assert store_offer.locator("td").nth(1).inner_text() == "1"
                assert "fulfillment and revenue are unavailable" in page.locator("#main").inner_text()
                assert page.locator('[data-social-metric="challenge_opened"]').inner_text() == "1"
                assert page.locator('[data-social-metric="challenge_joined"]').inner_text() == "1"
                assert page.locator('[data-social-metric="challenge_created"]').inner_text() == "1"
                assert page.locator('[data-social-metric="share_clicked"]').inner_text() == "1"
                assert page.locator("#pa-creator-reach dd").last.inner_text() == "1 / 1"
                assert page.locator('[data-quality-metric="dropped_events"]').inner_text() == "4"
                assert page.locator('[data-quality-metric="rejected_events"]').inner_text() == "2"
                assert page.locator('[data-quality-metric="persistence_failures"]').inner_text() == "1"
                checks.append("Store and social observations remain separate from paid outcomes and published-track reach")

                count = len(requests)
                page.wait_for_timeout(1200)
                assert len(requests) == count
                page.locator("#refresh").click()
                page.get_by_role("heading", name="Product analytics", exact=True).wait_for()
                assert len(requests) == count + 1
                checks.append("Idle analytics does not poll and explicit refresh reads one bundle")

                for width, height in [(1440, 900), (1280, 800), (960, 720), (390, 844)]:
                    page.set_viewport_size({"width": width, "height": height})
                    page.evaluate("scrollTo(0,0)")
                    page.wait_for_timeout(200)
                    assert page.evaluate("document.documentElement.scrollWidth<=innerWidth")
                    page.screenshot(path=str(args.output / f"analytics-{width}.png"), full_page=True,
                                    animations="disabled")
                page.set_viewport_size({"width": 640, "height": 400})
                assert page.evaluate("document.documentElement.scrollWidth<=innerWidth")
                checks.append("Desktop, compact and narrow layouts contain tables and primary controls")
                page.set_viewport_size({"width": 1440, "height": 900})

                failure[0] = True
                page.locator("#refresh").click()
                page.get_by_role("heading", name="Unable to load records", exact=True).wait_for()
                assert not page.locator("#pa-dau").count()
                assert page.url.endswith(original_route)
                failure[0] = False
                page.locator("#retry").click()
                page.get_by_role("heading", name="Product analytics", exact=True).wait_for()
                assert page.locator("#pa-dau").inner_text() == "3"
                checks.append("Failed analytics never leaves old values fresh and Retry preserves its route")

                unknown_query = f"since={dates['since'] - 2 * 86400}&until={dates['since'] - 86400}"
                with page.expect_response(lambda result: "/product-analytics?" in result.url and unknown_query in result.url):
                    page.evaluate("route=>location.hash=route", "product?" + unknown_query)
                page.get_by_role("heading", name="Product analytics", exact=True).wait_for()
                assert page.locator("#pa-dau").inner_text() == "Not observed"
                assert page.locator("#pa-store-opened").inner_text() == "Not observed"
                assert page.locator('[data-social-metric="challenge_joined"]').inner_text() == "Not observed"
                assert all(value == "Not observed" for value in page.locator("#pa-first-race-funnel .pa-step-count").all_text_contents())
                assert all(value == "Not observed" for value in page.locator("#pa-creator-funnel .pa-step-count").all_text_contents())
                assert page.locator('[data-quality-metric="dropped_events"]').inner_text() == "Not observed"
                page.screenshot(path=str(args.output / "analytics-no-coverage.png"), full_page=True,
                                animations="disabled")
                checks.append("An unavailable reporting window never becomes zero store, social or active-player counts")

                page.evaluate("route=>location.hash=route", "product?" + query)
                page.locator("#refresh").click()
                page.get_by_role("heading", name="Product analytics", exact=True).wait_for()
                assert query in requests[-1]
                page.locator(".console-nav[data-route=tracks]").click()
                page.get_by_role("heading", name="Tracks & creators", exact=True).wait_for()
                assert "since=" in page.url and "until=" in page.url
                checks.append("Supported date context follows analytics into record navigation")

                hold[0] = True
                page.locator(".console-nav[data-route=product]").click()
                for _attempt in range(100):
                    if deferred:
                        break
                    page.wait_for_timeout(20)
                assert len(deferred) == 1
                page.evaluate("location.hash='tracks'")
                page.get_by_role("heading", name="Tracks & creators", exact=True).wait_for()
                deferred[0].fulfill(json=response)
                page.wait_for_load_state("networkidle")
                assert not page.locator("#pa-dau").count()
                hold[0] = False
                checks.append("Abandoned analytics response cannot replace the selected record workspace")

                page.locator("#logout").click()
                assert page.locator("#key").input_value() == ""
                assert not page.locator("#pa-dau").count()
                page.evaluate("route=>location.hash=route", "product?" + query)
                page.fill("#key", config["analyst"])
                start = len(requests)
                page.locator("#login button").click()
                page.get_by_role("heading", name="Product analytics", exact=True).wait_for()
                assert len(requests) == start + 1
                assert page.locator("#role").inner_text() == "analyst access"
                assert page.locator("#pa-dau").inner_text() == "3"
                assert not page.locator("[data-support-action], [data-product], #command").count()
                checks.append("Analyst reads the same prepared metrics through one authorized query")
                page.locator("#logout").click()
                assert not errors, errors
                browser.close()
                checks.append("Lock clears presented analytics without JavaScript exceptions")
        finally:
            if server:
                server.terminate()
                server.wait(timeout=15)
    receipt = {
        "checks": checks, "javascript_errors": errors, "admin_request_count": len(requests),
        "product_reads_per_refresh": 1,
        "response_decoded_bytes": len(expected_response.content),
        "prepared_daily_rows": len(response["daily"]),
        "fixture": "Owned loopback SQLite app. Authenticated TestClient HTTP seed with an ingestion-clock fixture; real prepared metric projector and analytics endpoint; isolated query-failure injection.",
    }
    (args.output / "browser-receipt.json").write_text(json.dumps(receipt, indent=2) + "\n")
    print(f"PRODUCT_ANALYTICS_BROWSER: {len(checks)} checks, zero failures")
    print("Owned loopback service stopped; private fixture retained under build/.")


if __name__ == "__main__":
    main()
