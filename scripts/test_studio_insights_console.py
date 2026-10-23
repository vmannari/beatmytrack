"""Browser evidence against a newly owned SQLite service; all values are seeded.

No existing database, remote service, device or deployment is accessed.
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
    from dataclasses import replace

    import bmt_backend.app as application
    import bmt_backend.studio_alarms as alarms
    import uvicorn
    from test_backend_studio_console import serve as base_serve

    original_create, original_run = application.create_app, uvicorn.run

    def create(settings, **kwargs):
        return original_create(replace(settings, telemetry_enabled=True), **kwargs)

    def health(app, **kwargs):
        scenario = json.loads((folder / "scenario.json").read_text())
        if scenario.get("unavailable"):
            raise OSError("Seeded source unavailable")
        return {"status": "ready", "available_workers": 1, "queue_depth": 0,
            "oldest_age_seconds": 0, "queue_capacity": 100, "failed_last_5_minutes": 0,
            "storage_free_bytes": 25 * 1024**3, "backup": {"status": "complete"}, **scenario}

    def seeded(app, **kwargs):
        from bmt_backend.telemetry_models import (
            ProductMetric,
            ProductPlayerDay,
            ProductState,
        )
        from bmt_backend.track_models import now
        fixture = json.loads((folder / "fixture.json").read_text())
        at, day = now(), now() // 86400
        with app.state.session_factory() as session:
            state = session.get(ProductState, 1)
            state.collection_started_at = (day-14)*86400
            state.processed_through, state.latest_receipt_at, state.observed_at = at-20, at-15, at-10
            for offset, count in enumerate([1, 1, 2, 1, 2, 2, 2]):
                session.add(ProductMetric(day=day-6+offset, key="active_players", value=count))
                for player in [fixture["player_id"], fixture["artificial_player_id"]][:count]:
                    session.add(ProductPlayerDay(day=day-6+offset, player_id=player))
            for name, count in [("app_first_open", 2), ("menu_ready", 2), ("race_attempt", 2),
                ("race_started", 2), ("race_finished", 1), ("second_voluntary_race", 1)]:
                session.add(ProductMetric(day=day-4, key="first_race_"+name, value=count))
            session.commit()
        original_run(app, **kwargs)

    application.create_app, uvicorn.run = create, seeded
    alarms.competition_health = health
    base_serve(folder, port)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--serve", type=Path)
    parser.add_argument("--port", type=int)
    parser.add_argument("--output", type=Path, default=ROOT / "docs/evidence/studio-insights-2026-10-16")
    args = parser.parse_args()
    if args.serve:
        serve(args.serve, args.port)
        return
    import httpx
    from playwright.sync_api import expect, sync_playwright
    folder = ROOT / "build" / ("studio-insights-browser-" + uuid4().hex[:8])
    folder.mkdir(parents=True)
    output = args.output.resolve(); output.mkdir(parents=True, exist_ok=True)
    credentials = {name: secrets.token_urlsafe(32) for name in ("owner", "analyst", "development")}
    (folder / "config.private.json").write_text(json.dumps(credentials))
    scenario = folder / "scenario.json"
    scenario.write_text(json.dumps({"status": "worker_build_mismatch", "queue_depth": 4,
        "available_workers": 0, "oldest_age_seconds": 245, "failed_last_5_minutes": 2}))
    with socket.socket() as reservation:
        reservation.bind(("127.0.0.1", 0)); port = reservation.getsockname()[1]
    base = f"http://127.0.0.1:{port}"
    checks, errors = [], []
    with (folder / "server.log").open("w", encoding="utf-8") as log:
        process = subprocess.Popen([sys.executable, str(Path(__file__)), "--serve", str(folder), "--port", str(port)],
            stdout=log, stderr=log, creationflags=subprocess.CREATE_NO_WINDOW)
        try:
            with httpx.Client(base_url=base, timeout=10) as client:
                for _ in range(100):
                    if process.poll() is not None:
                        raise RuntimeError("Owned fixture exited; inspect " + str(folder / "server.log"))
                    try:
                        if client.get("/health").status_code == 200:
                            break
                    except httpx.ConnectError:
                        pass
                    time.sleep(.2)
                else:
                    raise RuntimeError("Owned fixture did not start")
            with sync_playwright() as driver:
                browser = driver.chromium.launch(headless=True,
                    executable_path="C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe")
                page = browser.new_page(viewport={"width": 1440, "height": 1050})
                page.on("pageerror", lambda error: errors.append(str(error)))
                # Preserve a same-fixture view with actual pre-change HTML/JS.
                before = ROOT / "build/studio-insights-2026-10-16/before"
                def original(route):
                    name = route.request.url.split("/")[-1].split("?")[0]
                    source = before / ("backend__bmt_backend__admin_ui__" + ("index.html" if name == "admin" else name))
                    if source.is_file():
                        route.fulfill(body=source.read_bytes(), content_type="text/html" if name == "admin" else "application/javascript")
                    else:
                        route.continue_()
                page.route(base + "/admin**", original)
                page.goto(base + "/admin#overview")
                page.fill("#key", credentials["owner"]); page.locator("#login button").click()
                expect(page.locator("h1")).to_have_text("Studio pulse")
                page.screenshot(path=str(output / "overview-before-1440.png"), full_page=True)
                page.unroute(base + "/admin**", original)
                page.reload(); page.fill("#key", credentials["owner"]); page.locator("#login button").click()
                expect(page.locator("h1")).to_have_text("Overview")
                expect(page.locator(".insight-pulse")).to_contain_text("critical backend condition")
                expect(page.locator("#main")).to_contain_text("Largest observed first-race drop-off")
                expect(page.locator(".insight-priority")).to_have_count(3)
                page.screenshot(path=str(output / "overview-after-1440.png"), full_page=True)
                checks.append("overview prioritises active issues and derives a scoped first-race finding with source links")
                page.locator(".insight-priority").filter(has_text="Verification workers unavailable").click()
                expect(page.locator("h1")).to_have_text("Alarms")
                expect(page.locator("#alarm-title")).to_have_text("Verification workers unavailable")
                expect(page.locator('[data-alarm-action="clear"]')).to_have_count(0)
                page.screenshot(path=str(output / "alarms-active-1440.png"), full_page=True)
                page.evaluate("scrollTo({top:650,behavior:'instant'})")
                assert page.locator('.alarm-detail').bounding_box()['y'] >= page.locator('.topbar').bounding_box()['height']
                page.evaluate("scrollTo({top:0,behavior:'instant'})")
                page.locator('[data-alarm-action="acknowledge"]').click()
                page.fill("#alarm-reason", "Compare worker build, then restart the matching verifier.")
                page.locator("#alarm-save").click()
                expect(page.locator(".alarm-history")).to_contain_text("Compare worker build")
                checks.append("overview deep-link opens evidence and guided investigation; acknowledgement is recorded")
                # Independent authenticated tab sees the same persisted decision.
                other = browser.new_page(viewport={"width": 1440, "height": 1000})
                other.goto(base + "/admin#alarms/verification_unavailable")
                other.fill("#key", credentials["analyst"]); other.locator("#login button").click()
                expect(other.locator(".alarm-detail-heading")).to_contain_text("Acknowledged")
                expect(other.locator("[data-alarm-action]")).to_have_count(0)
                checks.append("separate analyst tab sees shared acknowledgement and cannot mutate")
                for width in (1024, 390):
                    page.set_viewport_size({"width": width, "height": 900})
                    page.screenshot(path=str(output / f"alarms-after-{width}.png"), full_page=True)
                    assert page.evaluate("document.documentElement.scrollWidth<=innerWidth"), f"Overflow at {width}"
                page.set_viewport_size({"width": 1440, "height": 1050})
                scenario.write_text("{}")
                page.locator("#alarm-recheck").click()
                expect(page.locator('[data-alarm-action="clear"]')).to_be_visible()
                page.screenshot(path=str(output / "alarm-recovered-1440.png"), full_page=True)
                page.locator('[data-alarm-action="clear"]').click()
                page.fill("#alarm-reason", "Compatible worker restored; queue and builds rechecked.")
                page.locator("#alarm-save").click()
                expect(page.locator(".alarm-history")).to_contain_text("Cleared after recovery")
                page.reload(); page.fill("#key", credentials["owner"]); page.locator("#login button").click()
                expect(page.locator(".alarm-detail-heading")).to_contain_text("Cleared")
                checks.append("recovery enables closure; clear history survives lock and reload")
                page.evaluate("location.hash='alarms?status=cleared'")
                expect(page.locator(".alarm-row")).to_have_count(1)
                expect(page.locator(".alarm-row")).to_contain_text("Cleared")
                page.screenshot(path=str(output / "alarms-cleared-1440.png"), full_page=True)
                page.evaluate("location.hash='overview'")
                expect(page.locator(".insight-pulse")).to_contain_text("No configured alarm is firing")
                page.screenshot(path=str(output / "overview-healthy-1440.png"), full_page=True)
                page.evaluate("location.hash='alarms/verification_unavailable'")
                expect(page.locator("#alarm-recheck")).to_be_visible()
                checks.append("cleared-state filter retains history and recovered overview does not imply an active fault")
                scenario.write_text(json.dumps({"status": "worker_unavailable", "queue_depth": 2, "available_workers": 0}))
                page.locator("#alarm-recheck").click()
                expect(page.locator(".alarm-detail-heading")).to_contain_text("Needs action")
                checks.append("recurrence after closure returns to active action queue")
                page.locator('[data-alarm-action="acknowledge"]').click()
                page.fill("#alarm-reason", "<img src=x onerror=alert(1)> is plain evidence text")
                page.locator("#alarm-save").click()
                expect(page.locator(".alarm-history img")).to_have_count(0)
                expect(page.locator(".alarm-history")).to_contain_text("<img src=x")
                checks.append("recorded operator evidence is escaped")
                scenario.write_text("{}")
                page.locator("#alarm-recheck").click()
                page.locator('[data-alarm-action="clear"]').click()
                page.fill("#alarm-reason", "Recovery reviewed before committing closure")
                scenario.write_text(json.dumps({"unavailable": True}))
                page.locator("#alarm-save").click()
                expect(page.locator("#alarm-error")).to_contain_text("ALARM_NOT_RECOVERED")
                page.locator('[data-close]').click()
                page.locator("#alarm-recheck").click()
                expect(page.locator("#main")).to_contain_text("Some checks are unavailable")
                expect(page.locator('[data-alarm-action="clear"]')).to_have_count(0)
                checks.append("source loss between preview and commit cannot clear an alarm")
                scenario.write_text(json.dumps({"status": "worker_unavailable", "queue_depth": 2, "available_workers": 0}))
                page.evaluate("location.hash='alarms'")
                expect(page.locator("h1")).to_have_text("Alarms")
                page.fill('#alarm-filters input[name="q"]', "no matching alarm")
                page.locator('#alarm-filters button').click()
                expect(page.locator(".alarm-empty")).to_contain_text("No issues match")
                checks.append("filters have a distinct, useful no-match state")
                page.evaluate("location.hash='alarms/verification_unavailable'")
                expect(page.locator("#alarm-title")).to_be_visible()
                for width in (1024, 390):
                    page.set_viewport_size({"width": width, "height": 900})
                    assert page.evaluate("document.documentElement.scrollWidth<=innerWidth"), f"Overflow at {width}"
                page.evaluate("location.hash='overview'")
                expect(page.locator("h1")).to_have_text("Overview")
                page.screenshot(path=str(output / "overview-after-390.png"), full_page=True)
                assert page.evaluate("document.documentElement.scrollWidth<=innerWidth")
                checks.append("overview and selected alarm contain at 390px; alarm also contains at 1024px")
                page.set_viewport_size({"width": 1440, "height": 1000})
                page.route("**/v1/admin/alarms", lambda route: route.fulfill(status=503,
                    content_type="application/json", body='{"detail":"Seeded alarm source unavailable"}'))
                page.locator("#refresh").click()
                expect(page.locator(".insight-pulse")).to_contain_text("could not be loaded")
                expect(page.locator("#main")).to_contain_text("Seeded alarm source unavailable")
                checks.append("alarm read failure is shown as unavailable while operational overview remains usable")
                assert not errors, errors
                browser.close()
            (output / "browser.json").write_text(json.dumps({"checks": checks, "javascript_errors": errors,
                "fixture": "Owned loopback SQLite; seeded worker health and prepared activity", "screenshots":
                [file.name for file in output.glob("*.png")]}, indent=2) + "\n")
            print(json.dumps({"checks": len(checks), "javascript_errors": errors, "output": str(output)}))
        finally:
            process.terminate()
            try:
                process.wait(timeout=10)
            except subprocess.TimeoutExpired:
                process.kill(); process.wait(timeout=5)


if __name__ == "__main__":
    main()
