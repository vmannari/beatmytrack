"""Real browser acceptance against a newly owned loopback Studio fixture.

Seeded records are test evidence, not completed canonical races. No remote
endpoint, provider service or existing player database is accessed.
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
    from bmt_backend.commerce_models import Entitlements
    from bmt_backend.config import Settings
    from bmt_backend.identity_models import Identity, Player
    from bmt_backend.migrate import upgrade
    from bmt_backend.resume_models import ResumeRace, ResumeReceipt
    from bmt_backend.track_models import (
        Board,
        PersonalBest,
        Run,
        RunTicket,
        Track,
        TrackVersion,
        now,
    )

    config = json.loads((folder / "config.private.json").read_text())
    settings = Settings(
        environment="development", dev_auth_enabled=True,
        purchase_simulation_enabled=True, dev_auth_key=config["development"],
        admin_owner_key=config["owner"], admin_analyst_key=config["analyst"],
        database_url="sqlite:///" + (folder / "database.sqlite").as_posix(),
        object_dir=str(folder / "objects"), rate_limit_per_minute=10000,
        write_limit_per_minute=10000,
    )
    app = create_app(settings, verifier=FakeVerifier())
    upgrade(app.state.engine)
    document = {"theme": "pine", "points": [[0, 0], [50, 0], [50, 50], [0, 50], [0, 0]]}
    content_hash = app.state.blobs.put_json(document)
    with app.state.session_factory() as session:
        player = Player(display_name="Studio support driver", country_code="FI")
        artificial = Player(display_name="Studio artificial driver", is_test_driver=True)
        session.add_all((player, artificial))
        session.flush()
        session.add(Identity(player_id=player.id, provider="development", subject="PRIVATE_PROVIDER_SUBJECT"))
        session.add(Entitlements(player_id=player.id, slots=1, simulated_slots=0))
        track = Track(owner_id=player.id)
        session.add(track)
        session.flush()
        manifest = {**FakeVerifier().manifest(), "track_content_hash": content_hash}
        version = TrackVersion(track_id=track.id, number=1, name="Studio proof circuit",
            content_hash=content_hash, manifest=manifest, state="published", published_at=now())
        session.add(version)
        session.flush()
        pinned = {name: value for name, value in manifest.items() if name != "vehicles"}
        pinned.update(vehicle_id="compact", **manifest["vehicles"]["compact"])
        board = Board(id="b" * 64, version_id=version.id, vehicle_id="compact", manifest=pinned)
        session.add(board)
        session.flush()
        ticket = RunTicket(player_id=player.id, board_id=board.id,
            created_at=now() - 300, expires_at=now() + 3600)
        session.add(ticket)
        session.flush()
        run = Run(player_id=player.id, board_id=board.id, ticket_id=ticket.id,
            replay_hash="c" * 64, status="verified", time_ticks=7260,
            lap_ticks=[1500, 1440, 1440, 1440, 1440], created_at=now() - 100,
            finished_at=now() - 95, attempts=1, lease_token="PRIVATE_LEASE_TOKEN")
        session.add(run)
        session.flush()
        session.add(PersonalBest(player_id=player.id, board_id=board.id, run_id=run.id, time_ticks=7260))
        rewind = ResumeRace(player_id=player.id, ticket_id=ticket.id, used=1, expires_at=ticket.expires_at)
        session.add(rewind)
        session.flush()
        session.add(ResumeReceipt(race_id=rewind.id, ordinal=1, source="daily_free",
            input_offset=900, from_tick=1200, to_tick=900, created_at=now() - 150))
        session.commit()
        (folder / "fixture.json").write_text(json.dumps({
            "player_id": player.id, "run_id": run.id, "version_id": version.id,
            "content_hash": content_hash, "board_id": board.id,
            "artificial_player_id": artificial.id,
        }))
    uvicorn.run(app, host="127.0.0.1", port=port, log_level="warning")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--serve", type=Path)
    parser.add_argument("--port", type=int)
    parser.add_argument("--output", type=Path, default=ROOT / "docs/evidence/backend-studio-2026-10-11")
    args = parser.parse_args()
    if args.serve:
        serve(args.serve, args.port)
        return

    import httpx
    from playwright.sync_api import expect, sync_playwright

    folder = ROOT / "build" / ("backend-studio-browser-" + uuid4().hex[:8])
    folder.mkdir(parents=True)
    args.output.mkdir(parents=True, exist_ok=True)
    config = {name: secrets.token_urlsafe(32) for name in ("owner", "analyst", "development")}
    (folder / "config.private.json").write_text(json.dumps(config))
    with socket.socket() as reservation:
        reservation.bind(("127.0.0.1", 0))
        port = reservation.getsockname()[1]
    base = f"http://127.0.0.1:{port}"
    checks = []
    with (folder / "server.log").open("w", encoding="utf-8") as log:
        server = subprocess.Popen([sys.executable, str(Path(__file__).resolve()), "--serve", str(folder),
            "--port", str(port)], stdout=log, stderr=log, creationflags=subprocess.CREATE_NO_WINDOW)
        try:
            with httpx.Client(base_url=base, timeout=15) as http:
                for _attempt in range(100):
                    if server.poll() is not None:
                        raise RuntimeError("Owned Studio fixture failed; inspect its private server.log")
                    try:
                        if http.get("/health").status_code == 200:
                            break
                    except httpx.ConnectError:
                        pass
                    time.sleep(0.2)
                else:
                    raise RuntimeError("Owned Studio fixture did not become ready")
                fixture = json.loads((folder / "fixture.json").read_text())
                with sync_playwright() as playwright:
                    browser = playwright.chromium.launch(headless=True,
                        executable_path="C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe")
                    page = browser.new_page(viewport={"width": 1440, "height": 1000}, accept_downloads=True)
                    errors = []
                    writes = []
                    page.on("pageerror", lambda error: errors.append(str(error)))
                    page.on("request", lambda request: writes.append(request.url)
                        if request.method == "POST" and "/v1/admin/" in request.url else None)

                    def connect(role):
                        page.fill("#key", config[role])
                        page.locator("#login button").click()

                    def navigate(fragment):
                        if page.url.split("#", 1)[-1] == fragment:
                            page.locator("#refresh").click()
                        else:
                            page.evaluate("fragment => { location.hash = fragment; }", fragment)

                    def race():
                        navigate("races/" + fixture["run_id"])
                        expect(page.locator("#studio-export")).to_be_visible()

                    page.goto(base + "/admin#players/" + fixture["player_id"])
                    connect("owner")
                    expect(page.get_by_role("heading", name="Activity & evidence", exact=True)).to_be_visible()
                    expect(page.locator("#main")).to_contain_text("Real")
                    auth = {"Authorization": "Bearer " + config["owner"]}
                    overview = http.get("/v1/admin/overview", headers=auth).json()
                    players = http.get("/v1/admin/entities/players", headers=auth).json()
                    assert overview["players"] == players["total"] == 2
                    flags = {item["id"]: item["is_test_driver"] for item in players["items"]}
                    assert flags == {fixture["player_id"]: False, fixture["artificial_player_id"]: True}
                    checks.append("All player totals include both classes; development sign-in does not imply artificial")
                    navigate("players")
                    expect(page.locator("#filters")).to_be_visible()
                    expect(page.locator("#main")).to_contain_text("Real")
                    expect(page.locator("#main")).to_contain_text("Artificial")
                    page.screenshot(path=str(args.output / "players-1440.png"), full_page=True)
                    navigate("players/" + fixture["artificial_player_id"])
                    expect(page.get_by_role("heading", name="Activity & evidence", exact=True)).to_be_visible()
                    expect(page.locator("#main")).to_contain_text("Artificial")
                    page.screenshot(path=str(args.output / "artificial-player-1440.png"), full_page=True)
                    navigate("players/" + fixture["player_id"])
                    expect(page.get_by_role("heading", name="Activity & evidence", exact=True)).to_be_visible()
                    checks.append("Player list and support distinguish real/artificial using the stored flag")
                    page.locator("#main a[href^='#races/" + fixture["run_id"] + "']").first.click()
                    expect(page.locator("#studio-export")).to_be_visible()
                    text = page.locator("#main").inner_text()
                    assert "Studio proof circuit" in text and "7260" in text
                    assert "PRIVATE_PROVIDER_SUBJECT" not in text and "PRIVATE_LEASE_TOKEN" not in text
                    checks.append("Player activity opens its exact redacted race contract")

                    with page.expect_download() as download_info:
                        page.locator("#studio-export").click()
                    downloaded = download_info.value
                    exported = json.loads(Path(downloaded.path()).read_text())
                    downloaded.save_as(str(args.output / "race-evidence-fixture.json"))
                    raw = json.dumps(exported)
                    assert fixture["run_id"] in raw and fixture["version_id"] in raw
                    assert fixture["content_hash"] in raw and "7260" in raw
                    assert exported["player"]["is_test_driver"] is False
                    assert all(value not in raw for value in config.values())
                    assert "PRIVATE_PROVIDER_SUBJECT" not in raw and "PRIVATE_LEASE_TOKEN" not in raw
                    expect(page.locator("#studio-export")).to_be_enabled()
                    checks.append("Download preserves pinned identities/result and excludes credentials/subjects/leases")

                    page.locator("#main a[href^='#tracks/" + fixture["version_id"] + "']").click()
                    expect(page.get_by_role("heading", name="Studio proof circuit", exact=True)).to_be_visible()
                    expect(page.locator("#main")).to_contain_text(fixture["content_hash"])
                    race()
                    checks.append("Inspector resolves the immutable version and content hash from this race")

                    for width in (1440, 960, 390):
                        page.set_viewport_size({"width": width, "height": 1000})
                        page.evaluate("window.scrollTo(0, 0)")
                        page.wait_for_function("""() => {
                            const box = document.querySelector('.sidebar').getBoundingClientRect();
                            return innerWidth > 740 ? box.left >= -1 : box.right <= 1;
                        }""")
                        assert page.evaluate("document.documentElement.scrollWidth <= innerWidth + 1")
                        page.screenshot(path=str(args.output / f"race-{width}.png"), full_page=True)
                    checks.append("Race inspector contained at desktop, compact and mobile widths")

                    page.set_viewport_size({"width": 1440, "height": 1000})
                    navigate("studio")
                    expect(page.locator("#main")).to_contain_text("coverage")
                    expect(page.locator("#main")).to_contain_text("Unavailable")
                    page.evaluate("window.scrollTo(0, 0)")
                    page.screenshot(path=str(args.output / "coverage-1440.png"), full_page=True)
                    checks.append("Coverage shows unsupported sources without synthetic analytics")

                    race()
                    page.locator("#search").click()
                    expect(page.locator("#dialog")).to_be_visible()
                    page.locator("#dialog [data-close]").click()
                    expect(page.locator("#search")).to_be_focused()
                    checks.append("Dialog restores keyboard focus to its opener")

                    # A response for an abandoned route cannot overwrite the current page.
                    late_race = []
                    def stale_route(route):
                        late_race.append(route)
                    page.route("**/v1/admin/studio/races/*", stale_route)
                    navigate("races/" + fixture["run_id"])
                    for _attempt in range(100):
                        if late_race:
                            break
                        page.wait_for_timeout(20)
                    assert len(late_race) == 1
                    page.evaluate("location.hash = 'players'")
                    expect(page.locator("#filters")).to_be_visible()
                    late_race[0].fulfill(status=200, content_type="application/json", body=json.dumps(exported))
                    page.wait_for_load_state("networkidle")
                    expect(page.locator("#filters")).to_be_visible()
                    assert not page.locator("#studio-export").count()
                    page.unroute("**/v1/admin/studio/races/*", stale_route)
                    checks.append("Abandoned race request cannot replace the selected player list")

                    navigate("players/" + fixture["player_id"])
                    expect(page.locator("[data-support-action='simulate_purchase']")).to_be_visible()
                    page.locator("[data-support-action='simulate_purchase']").click()
                    preview_requests = []
                    def late_preview(route):
                        preview_requests.append(route)
                    page.route("**/development/preview", late_preview)
                    page.locator("#dev-preview").click()
                    for _attempt in range(100):
                        if preview_requests:
                            break
                        page.wait_for_timeout(20)
                    assert len(preview_requests) == 1
                    page.evaluate("document.querySelector('#logout').click()")
                    preview_requests[0].fulfill(status=200, content_type="application/json", body=json.dumps({
                        "preview_at": 1, "expected_hash": "a" * 64,
                        "before": {"access": {}}, "after": {"access": {}, "purchase": None},
                    }))
                    page.wait_for_load_state("networkidle")
                    expect(page.locator("#login")).to_be_visible()
                    expect(page.locator("#dialog")).not_to_be_visible()
                    assert not page.locator("#dev-confirm").count()
                    page.unroute("**/development/preview", late_preview)
                    assert not any(url.endswith("/development/commands") for url in writes)
                    checks.append("Lock fences pending support preview and sends no development command")

                    navigate("players/" + fixture["player_id"])
                    connect("analyst")
                    expect(page.get_by_role("heading", name="Activity & evidence", exact=True)).to_be_visible()
                    assert not page.locator("[data-support-action]").count()
                    assert not page.locator("#command").count()
                    race()
                    checks.append("Analyst can inspect/export evidence without mutation controls")

                    def fail_route(route):
                        route.fulfill(status=503, content_type="application/json",
                            body=json.dumps({"detail": "Fixture source unavailable"}))
                    page.route("**/v1/admin/studio/races/*", fail_route)
                    page.locator("#refresh").click()
                    expect(page.locator("#retry")).to_be_visible()
                    assert not page.locator("#studio-export").count()
                    page.unroute("**/v1/admin/studio/races/*", fail_route)
                    page.locator("#retry").click()
                    expect(page.locator("#studio-export")).to_be_visible()
                    checks.append("Failed source clears old evidence; Retry restores the same race")

                    page.locator("#logout").click()
                    expect(page.locator("#login")).to_be_visible()
                    assert page.locator("#key").input_value() == ""
                    assert not page.evaluate("Object.keys(localStorage).length + Object.keys(sessionStorage).length")
                    assert not errors, errors
                    browser.close()
                    checks.append("Lock clears access, no storage secrets or JavaScript exceptions")
        finally:
            server.terminate()
            try:
                server.wait(timeout=10)
            except subprocess.TimeoutExpired:
                server.kill()
                server.wait(timeout=5)
    receipt = {"fixture": "owned loopback seeded SQLite; no canonical/device/live verification",
        "checks": checks, "failures": 0}
    (args.output / "browser-receipt.json").write_text(json.dumps(receipt, indent=2) + "\n")
    print(f"BACKEND_STUDIO_BROWSER: {len(checks)} checks, zero failures")


if __name__ == "__main__":
    main()
