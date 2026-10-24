"""Browser and native-client acceptance against a newly owned loopback fixture."""
import argparse
import json
import os
import secrets
import socket
import subprocess
import sys
import time
from pathlib import Path
from uuid import uuid4

ROOT = Path(__file__).resolve().parents[1]
sys.path[:0] = [str(ROOT / "backend"), str(ROOT / "backend/tests")]


def serve(folder, port):
    import uvicorn
    from bmt_backend.app import create_app
    from bmt_backend.config import Settings
    from bmt_backend.identity_models import Player
    from bmt_backend.migrate import upgrade
    from test_domains import FakeVerifier

    private = json.loads((folder / "config.private.json").read_text())
    app = create_app(Settings(environment="development", dev_auth_enabled=True, studio_legacy_keys_enabled=True,
        dev_auth_key=private["development"], admin_owner_key=private["owner"], admin_analyst_key=private["analyst"],
        database_url="sqlite:///" + (folder / "database.sqlite").as_posix(), object_dir=str(folder / "objects"),
        telemetry_enabled=True, rate_limit_per_minute=10000, write_limit_per_minute=10000), verifier=FakeVerifier())
    upgrade(app.state.engine)
    with app.state.session_factory() as db:
        player = Player(display_name="Configuration fixture driver", country_code="FI", analytics_enabled=True)
        db.add(player)
        db.commit()
        (folder / "fixture.json").write_text(json.dumps({"player_id": player.id}))
    uvicorn.run(app, host="127.0.0.1", port=port, log_level="warning")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--serve", type=Path)
    parser.add_argument("--port", type=int)
    parser.add_argument("--output", type=Path, default=ROOT / "docs/evidence/game-configuration-2026-10-24/browser")
    parser.add_argument("--native", action="store_true")
    args = parser.parse_args()
    if args.serve:
        serve(args.serve, args.port)
        return
    import httpx
    from playwright.sync_api import expect, sync_playwright

    folder = ROOT / ".tools" / ("game-config-browser-" + uuid4().hex[:10])
    folder.mkdir(parents=True)
    args.output.mkdir(parents=True, exist_ok=True)
    private = {key: secrets.token_urlsafe(32) for key in ("owner", "analyst", "development")}
    (folder / "config.private.json").write_text(json.dumps(private))
    with socket.socket() as reservation:
        reservation.bind(("127.0.0.1", 0))
        port = reservation.getsockname()[1]
    base = f"http://127.0.0.1:{port}"
    checks, errors = [], []
    headers = {"Authorization": "Bearer " + private["owner"]}
    server_log = (folder / "server.log").open("w", encoding="utf-8")
    server = subprocess.Popen([sys.executable, str(Path(__file__).resolve()), "--serve", str(folder), "--port", str(port)],
        stdout=server_log, stderr=server_log, creationflags=subprocess.CREATE_NO_WINDOW)
    try:
        with httpx.Client(base_url=base, timeout=20) as http:
            for _ in range(100):
                if server.poll() is not None:
                    raise RuntimeError("Owned fixture exited: " + str(folder / "server.log"))
                try:
                    if http.get("/health").status_code == 200:
                        break
                except httpx.ConnectError:
                    pass
                time.sleep(0.2)
            else:
                raise RuntimeError("Owned fixture did not start")
            with sync_playwright() as playwright:
                browser = playwright.chromium.launch(headless=True,
                    executable_path="C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe")
                page = browser.new_page(viewport={"width": 1440, "height": 1000})
                page.on("pageerror", lambda error: errors.append(str(error)))
                page.goto(base + "/admin#studio?tab=config")
                page.locator("#key").fill(private["owner"])
                page.locator("#login button").click()
                expect(page.get_by_role("heading", name="Current configuration", exact=True)).to_be_visible()
                checks.append("owner config overview")

                def save(reason):
                    dialog = page.locator("#dialog")
                    expect(dialog).to_be_visible()
                    dialog.locator('[name="reason"]').fill(reason)
                    dialog.get_by_role("button", name="Save", exact=True).click()
                    expect(dialog).not_to_be_visible(timeout=15000)

                page.locator("#gc-new").click()
                page.locator('#dialog [name="name"]').fill("Ad cadence fixture")
                save("Create fixture policy")
                expect(page.locator("#gc-settings")).to_be_visible()
                page.locator('[data-setting="ads.permitted"]').select_option("true")
                page.locator('[data-setting="ads.interstitial_enabled"]').select_option("true")
                page.locator('[data-setting="ads.races"]').fill("4")
                page.locator('[data-setting="ads.active_seconds"]').fill("360")
                page.locator('[data-setting="ads.trigger"]').select_option("both")
                page.locator('#gc-settings button[type="submit"], #gc-settings button:not([type])').first.click()
                save("Publish four races and six minutes")
                expect(page.locator("#gc-settings")).to_be_visible()
                checks.append("typed draft fields and reviewed save")
                page.evaluate("window.scrollTo(0,0)")
                page.screenshot(path=str(args.output / "settings-desktop.png"), full_page=True)
                page.locator('a[href*="view=audiences"]').first.click()
                audience = page.locator("#gc-audience")
                audience.locator('[name="name"]').fill("Android notice")
                audience.locator('[name="aud-platform"]').select_option(["android", "windows"])
                audience.locator('[name="aud-capabilities"]').select_option("menu_policy_v1")
                page.locator("#gc-audience-key").select_option("notice.message")
                page.locator('#gc-audience-value [data-setting="notice.message"]').fill("Welcome Android drivers")
                audience.get_by_role("button", name="Review audience override", exact=True).click()
                save("Add a platform-scoped menu notice")
                page.locator('[data-gc-edit-audience]').first.click()
                page.locator('#gc-audience [name="priority"]').fill("20")
                page.locator('#gc-audience-value [data-setting="notice.message"]').fill("Welcome to Beat my track")
                page.locator('#gc-audience button').filter(has_text="Review audience override").click()
                save("Edit the draft audience without publishing")
                expect(page.locator("#main").get_by_role("cell", name="20", exact=True)).to_be_visible()
                edited = http.get("/v1/admin/game-config", headers=headers).json()["drafts"][0]["audiences"][0]
                assert edited["conditions"]["platforms"] == ["android", "windows"]
                assert edited["conditions"]["capabilities"] == ["menu_policy_v1"]
                checks.append("typed audience creation and revision-fenced editing")
                page.locator('a[href*="view=preview"]').first.click()
                page.locator('#gc-preview [name="races"]').fill("4")
                page.locator('#gc-preview [name="active_seconds"]').fill("360")
                page.locator('#gc-preview [name="session_seconds"]').fill("360")
                page.locator('#gc-preview button').click()
                expect(page.locator('#gc-preview-result')).to_contain_text("Policy permits this opportunity")
                expect(page.locator('#gc-preview-result')).to_contain_text("Welcome to Beat my track")
                checks.append("hypothetical player resolution and session timeline preview")
                page.locator('a[href*="view=releases"]').first.click()
                page.locator("#gc-publish").click()
                page.locator('#dialog [name="rollout"]').select_option("10000")
                save("Activate isolated fixture policy")
                expect(page.get_by_role("heading", name="Published and scheduled versions")).to_be_visible()
                active = http.get("/v1/admin/game-config", headers=headers).json()["active"]
                assert active["policy"]["ads.races"] == 4 and active["policy"]["ads.trigger"] == "both"
                checks.append("browser publication reaches actual configuration API")
                page.goto(base + "/admin#studio?tab=experiments")
                page.locator("#gc-create-experiment").click()
                page.locator('#gc-experiment [name="name"]').fill("Cadence A/B/n fixture")
                page.locator('#gc-experiment [name="hypothesis"]').fill("Compare return rates without changing racing rules")
                page.locator('#gc-experiment [name="enrollment"]').fill("100")
                page.locator("#gc-add-variant").click()
                expect(page.locator("[data-variant]")).to_have_count(3)
                page.locator('#gc-experiment button[type="submit"], #gc-experiment button:not([type])').last.click()
                save("Register a three-arm fixed-horizon experiment")
                expect(page.get_by_text("Cadence A/B/n fixture", exact=True)).to_be_visible()
                page.locator('[data-gc-experiment-state="active"]').first.click()
                save("Start isolated assignment and exposure test")
                page.locator('[data-gc-score]').first.click()
                expect(page.locator('#gc-experiment-results')).to_contain_text("No automatic winner")
                checks.append("three-arm builder, allocation, activation and inconclusive results")
                if args.native:
                    environment = dict(os.environ, BMT_CONFIG_TEST_ORIGIN=base, BMT_CONFIG_TEST_KEY=private["development"],
                        APPDATA=str(folder / "native-user"))
                    native = subprocess.run(["powershell", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File",
                        str(ROOT / "scripts/dev.ps1"), "TestScript", "-ScriptPath", "res://tests/test_game_configuration_http.gd",
                        "-CommandTimeoutSeconds", "180"], cwd=ROOT, env=environment, capture_output=True, text=True,
                        timeout=210, check=False, creationflags=subprocess.CREATE_NO_WINDOW)
                    (args.output / "native-http.log").write_text(native.stdout + native.stderr, encoding="utf-8")
                    assert native.returncode == 0, "Native fixture failed; inspect native-http.log"
                    from bmt_backend.db import make_engine, make_session_factory
                    from bmt_backend.product_analytics import project_pending
                    engine = make_engine("sqlite:///" + (folder / "database.sqlite").as_posix())
                    try:
                        project_pending(make_session_factory(engine))
                    finally:
                        engine.dispose()
                    page.locator('[data-gc-score]').first.click()
                    expect(page.locator('#gc-experiment-results')).to_contain_text("Suppressed")
                    score = http.get("/v1/admin/experiments", headers=headers).json()["items"][0]
                    counts = http.get("/v1/admin/experiments/"+score["id"]+"/scorecard", headers=headers).json()
                    assert sum(v["assigned"] for v in counts["variants"]) == 1
                    assert sum(v["exposed"] for v in counts["variants"]) == 1
                    checks.append("actual Godot adapter to HTTP assignment, persisted telemetry and worker scorecard")
                page.evaluate("window.scrollTo(0,0)")
                page.screenshot(path=str(args.output / "experiments-desktop.png"), full_page=True)
                page.locator('[data-gc-promote]').first.click()
                page.locator('#dialog [name="variant"]').select_option("variant")
                save("Copy candidate into a reviewable policy draft")
                expect(page.locator("#gc-publish")).to_be_visible()
                checks.append("promotion pauses experiment and prepares a publication draft")
                page.goto(base + "/admin#studio?tab=config")
                page.locator('[data-gc-emergency="all"]').click()
                save("Stop fixture advertising")
                assert http.get("/v1/game-config/emergency").json()["restrictions"] == {"ads.permitted": False}
                expect(page.get_by_text("Active: All advertising disabled", exact=True)).to_be_visible()
                expect(page.locator("#main")).to_contain_text("Automatic ads disabled.")
                checks.append("browser emergency switch reaches permission API")
                with page.expect_download() as downloading:
                    page.locator("#gc-export").click()
                downloading.value.save_as(args.output / "policy-snapshot.json")
                exported = json.loads((args.output / "policy-snapshot.json").read_text())
                assert exported["schema_version"] == 1 and "settings" in exported
                checks.append("redacted policy snapshot download")
                page.set_viewport_size({"width": 390, "height": 844})
                expect(page.get_by_role("heading", name="Advertising restrictions", exact=True)).to_be_visible()
                page.screenshot(path=str(args.output / "overview-narrow.png"), full_page=True)
                assert page.evaluate("document.documentElement.scrollWidth <= innerWidth + 1")
                checks.append("390px responsive containment")
                page.get_by_role("button", name="Lock", exact=True).click()
                page.locator("#key").fill(private["analyst"])
                page.locator("#login button").click()
                expect(page.get_by_role("heading", name="Current configuration", exact=True)).to_be_visible()
                expect(page.locator("#gc-new")).to_have_count(0)
                expect(page.locator("[data-gc-emergency]")).to_have_count(0)
                checks.append("analyst sees configuration with no mutation controls")
                assert not errors, errors
                browser.close()
    finally:
        server.terminate()
        try:
            server.wait(timeout=15)
        except subprocess.TimeoutExpired:
            server.kill()
            server.wait(timeout=5)
        server_log.close()
        (args.output / "report.json").write_text(json.dumps({"checks": checks, "page_errors": errors}, indent=2), encoding="utf-8")
    print(json.dumps({"checks": len(checks), "page_errors": len(errors), "output": str(args.output)}))


if __name__ == "__main__":
    main()
