"""Real Edge workflows on a disposable loopback Studio service."""
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
sys.path[:0] = [str(ROOT / "backend"), str(ROOT / "backend/tests"), str(ROOT / "scripts")]


def serve(folder, port):
    from dataclasses import replace

    import uvicorn
    from bmt_backend.economy_models import CoinWallet
    from test_backend_studio_console import serve as base_serve
    original = uvicorn.run

    def seeded(app, **kwargs):
        app.state.settings = replace(app.state.settings, environment="production",
            dev_auth_enabled=False, purchase_simulation_enabled=False)
        fixture = json.loads((folder / "fixture.json").read_text())
        with app.state.session_factory() as db:
            db.add(CoinWallet(player_id=fixture["player_id"], balance=1250, revision=0))
            db.commit()
        original(app, **kwargs)

    uvicorn.run = seeded
    base_serve(folder, port)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--serve", type=Path)
    parser.add_argument("--port", type=int)
    parser.add_argument("--output", type=Path, default=ROOT / "docs/evidence/player-grants-2026-10-18")
    args = parser.parse_args()
    if args.serve:
        serve(args.serve, args.port)
        return
    import httpx
    from playwright.sync_api import expect, sync_playwright

    folder = ROOT / "build" / ("player-grants-browser-" + uuid4().hex[:8])
    folder.mkdir(parents=True)
    args.output.mkdir(parents=True, exist_ok=True)
    config = {name: secrets.token_urlsafe(32) for name in ("owner", "analyst", "development")}
    (folder / "config.private.json").write_text(json.dumps(config))
    with socket.socket() as reservation:
        reservation.bind(("127.0.0.1", 0))
        port = reservation.getsockname()[1]
    base = f"http://127.0.0.1:{port}"
    checks, errors, writes = [], [], []
    with (folder / "server.log").open("w", encoding="utf-8") as log:
        process = subprocess.Popen([sys.executable, str(Path(__file__).resolve()), "--serve", str(folder),
            "--port", str(port)], stdout=log, stderr=log, creationflags=subprocess.CREATE_NO_WINDOW)
        try:
            with httpx.Client(base_url=base, timeout=25) as http:
                for _ in range(100):
                    if process.poll() is not None:
                        raise RuntimeError("Owned fixture failed; inspect " + str(folder / "server.log"))
                    try:
                        if http.get("/health").status_code == 200:
                            break
                    except httpx.ConnectError:
                        pass
                    time.sleep(.25)
                else:
                    raise RuntimeError("Owned fixture did not become ready")
                fixture = json.loads((folder / "fixture.json").read_text())
                player = fixture["player_id"]
                auth = {"Authorization": "Bearer " + config["owner"]}
                endpoint = "/v1/admin/players/" + player

                def current():
                    response = http.get(endpoint + "/support", headers=auth)
                    response.raise_for_status()
                    return response.json()

                with sync_playwright() as playwright:
                    browser = playwright.chromium.launch(headless=True,
                        executable_path="C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe")
                    page = browser.new_page(viewport={"width": 1440, "height": 1050})
                    page.on("pageerror", lambda error: errors.append(str(error)))
                    page.on("request", lambda request: writes.append(request.post_data_json)
                        if request.method == "POST" and "/grants/commands" in request.url else None)

                    def visit(route):
                        page.evaluate("route=>location.hash=route", route)
                        expect(page.locator("#main")).not_to_have_attribute("aria-busy", "true")
                        page.wait_for_load_state("networkidle")

                    def open_grant(product="publishing_slots", quantity=1):
                        page.locator("#player-grant").click()
                        page.locator("#grant-product").select_option(product)
                        if not page.locator("#grant-quantity").is_disabled():
                            page.locator("#grant-quantity").fill(str(quantity))
                        page.locator("#grant-preview").click()
                        expect(page.locator("#grant-confirm")).to_be_visible()

                    def submit():
                        page.locator("#grant-reason").fill("Owned local support workflow acceptance")
                        page.locator("#grant-acknowledged").check()
                        page.locator("#grant-submit").click()

                    page.goto(base + "/admin#players")
                    page.locator("#key").fill(config["owner"])
                    page.locator("#login button").click()
                    expect(page.locator("#catalogue-filters")).to_be_visible()
                    page.locator("#catalogue-filters input[name=q]").fill("Studio support")
                    page.locator("#catalogue-filters button[type=submit],#catalogue-filters button.btn-primary").click()
                    page.locator(".stc-player-link").click()
                    expect(page.locator(".stc-player-hero h2")).to_have_text("Studio support driver")
                    page.locator(".stc-tabs").get_by_role("link", name="Purchases & grants").click()
                    expect(page.locator("#player-grant")).to_be_visible()
                    checks.append("Find selected player and open Purchases & grants with production simulation disabled")
                    open_grant(quantity=7)
                    page.evaluate("window.scrollTo(0,0)")
                    page.screenshot(path=str(args.output / "grant-preview-desktop.png"))
                    page.locator("#grant-reason").fill(" " * 8)
                    page.locator("#grant-acknowledged").check()
                    page.locator("#grant-submit").click()
                    expect(page.locator("#grant-error")).to_contain_text("eight nonblank characters")
                    page.locator("#dialog [data-close]").click()
                    assert current()["effective"]["publishing_slots"] == 1 and not writes
                    checks.append("Preview and Cancel leave account balances unchanged")

                    open_grant(quantity=7)
                    submit()
                    expect(page.locator("#dialog")).not_to_be_visible()
                    expect(page.locator("#player-grant")).to_be_visible()
                    assert current()["effective"]["publishing_slots"] == 8
                    assert current()["access"]["simulated_slots"] == 0
                    checks.append("Grant seven actual slots and refresh authoritative inventory")

                    kit = next(p["id"] for p in current()["grants"]["products"] if p["id"].startswith("kit/"))
                    page.locator("#player-grant").click()
                    page.locator("#grant-search").fill("no-matching-product")
                    expect(page.locator("#grant-preview")).to_be_disabled()
                    page.locator("#grant-search").fill("compact")
                    page.locator("#grant-product").select_option(kit)
                    expect(page.locator("#grant-quantity")).to_be_disabled()
                    page.locator("#grant-preview").click()
                    expect(page.locator("#grant-confirm")).to_be_visible()
                    # The server commits, but the browser receives an ambiguous delivery error.
                    lost = []
                    def lost_response(route):
                        if not lost:
                            response = route.fetch()
                            assert response.status == 200
                            lost.append(True)
                            route.fulfill(status=503, content_type="application/json", body='{"detail":"Delivery interrupted"}')
                        else:
                            route.continue_()
                    page.route("**/grants/commands", lost_response)
                    submit()
                    expect(page.locator("#grant-error")).to_contain_text("Delivery interrupted")
                    page.locator("#grant-submit").click()
                    expect(page.locator("#dialog")).not_to_be_visible()
                    expect(page.locator(".stc-owned-items")).to_contain_text(kit)
                    page.unroute("**/grants/commands", lost_response)
                    state = current()
                    assert state["grants"]["owned"] == [kit] and state["grants"]["coin_balance"] == 1250
                    assert writes[-1] == writes[-2]
                    checks.append("Search kits, grant free ownership, retain Coins and retry lost response with the exact command")

                    open_grant("ad_free_month")
                    submit()
                    expect(page.locator("#dialog")).not_to_be_visible()
                    expect(page.locator("#player-grant")).to_be_visible()
                    assert current()["effective"]["ad_free"]
                    open_grant("resumes", 3)
                    submit()
                    expect(page.locator("#dialog")).not_to_be_visible()
                    expect(page.locator("#player-grant")).to_be_visible()
                    assert current()["resumes"]["banked"] == 3
                    assert http.get("/v1/admin/purchases?player_id=" + player, headers=auth).json()["items"] == []
                    checks.append("Grant ad-free month and banked resumes without generating paid purchase records")
                    page.evaluate("window.scrollTo(0,0)")
                    page.screenshot(path=str(args.output / "player-grants-desktop.png"), full_page=True)

                    page.get_by_role("link", name="Grant audit history", exact=True).click()
                    expect(page.locator(".stc-timeline")).to_contain_text("Granted")
                    page.locator("[data-history-detail]").first.click()
                    expect(page.locator("#dialog")).to_contain_text("Owned local support workflow acceptance")
                    expect(page.locator("#dialog")).to_contain_text("support_grant")
                    page.screenshot(path=str(args.output / "grant-audit-desktop.png"), full_page=True)
                    page.locator("#dialog [data-close]").click()
                    checks.append("Audit history exposes recorded reason, target, item and before/after values")

                    visit("players/" + player + "?tab=purchases")
                    open_grant(quantity=2)
                    stale_slots = current()["effective"]["publishing_slots"]
                    other = {"command_id": str(uuid4()), "product_id": "publishing_slots", "quantity": 1}
                    value = http.post(endpoint + "/grants/preview", headers=auth, json=other).json()
                    delivered = http.post(endpoint + "/grants/commands", headers=auth, json={**other,
                        "preview_at": value["preview_at"], "expected_hash": value["expected_hash"],
                        "reason": "Second owner changes the previewed balance", "acknowledged": True})
                    assert delivered.status_code == 200
                    submit()
                    expect(page.locator("#grant-error")).to_contain_text("Close and preview")
                    expect(page.locator("#grant-submit")).to_be_disabled()
                    assert current()["effective"]["publishing_slots"] == stale_slots + 1
                    page.locator("#dialog [data-close]").click()
                    page.locator("#refresh").click()
                    expect(page.locator("#player-grant")).to_be_visible()
                    checks.append("Concurrent account change rejects stale preview and explains how to refresh")

                    page.set_viewport_size({"width": 390, "height": 844})
                    expect(page.locator("#player-grant")).to_be_visible()
                    page.screenshot(path=str(args.output / "player-grants-mobile.png"), full_page=True)
                    open_grant(quantity=2)
                    page.screenshot(path=str(args.output / "grant-preview-mobile.png"))
                    assert page.evaluate("document.documentElement.scrollWidth<=innerWidth+1")
                    assert page.locator("#dialog").evaluate("e=>e.scrollWidth<=e.clientWidth+1")
                    assert page.locator(".player-grant-comparison").evaluate("e=>e.scrollWidth<=e.clientWidth+1")
                    page.locator("#dialog [data-close]").click()
                    checks.append("390px inventory and preview fit without page or dialog horizontal overflow")

                    page.set_viewport_size({"width": 1440, "height": 1050})
                    page.locator("#player-grant").click()
                    abandoned = []
                    page.route("**/grants/preview", lambda route: abandoned.append(route))
                    page.locator("#grant-preview").click()
                    for _ in range(100):
                        if abandoned:
                            break
                        page.wait_for_timeout(20)
                    assert len(abandoned) == 1
                    count = len(writes)
                    page.evaluate("route=>location.hash=route", "players/" + fixture["artificial_player_id"] + "?tab=purchases")
                    expect(page.locator(".stc-player-hero h2")).to_have_text("Studio artificial driver")
                    abandoned[0].fulfill(status=200, content_type="application/json", body="{}")
                    page.wait_for_load_state("networkidle")
                    expect(page.locator(".stc-player-hero h2")).to_have_text("Studio artificial driver")
                    expect(page.locator("#dialog")).not_to_be_visible()
                    assert len(writes) == count
                    page.unroute("**/grants/preview")
                    visit("players/" + player + "?tab=purchases")
                    checks.append("Changing selected player fences the previous player's pending preview")

                    page.locator("#player-grant").click()
                    pending = []
                    page.route("**/grants/preview", lambda route: pending.append(route))
                    page.locator("#grant-preview").click()
                    for _ in range(100):
                        if pending:
                            break
                        page.wait_for_timeout(20)
                    assert len(pending) == 1
                    count = len(writes)
                    page.locator("#logout").evaluate("e=>e.click()")
                    pending[0].fulfill(status=200, content_type="application/json", body="{}")
                    page.wait_for_load_state("networkidle")
                    expect(page.locator("#dialog")).not_to_be_visible()
                    expect(page.locator("#login")).to_be_visible()
                    assert len(writes) == count
                    page.unroute("**/grants/preview")
                    checks.append("Lock fences a pending preview and clears selected-player mutation controls")

                    page.locator("#key").fill(config["analyst"])
                    page.locator("#login button").click()
                    expect(page.locator("#main")).to_contain_text("Owner access is required")
                    assert page.locator("#player-grant").count() == 0
                    expect(page.locator(".stc-owned-items")).to_contain_text(kit)
                    checks.append("Analyst inspects inventory with grant controls absent")
                    assert not errors, errors
                    browser.close()
            report = {"fixture": "Owned disposable loopback SQLite, Edge desktop/390px; no live mutation or device test",
                "checks": checks, "javascript_errors": errors, "grant_command_requests": len(writes)}
            (args.output / "browser.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
            print(json.dumps(report, indent=2))
        finally:
            process.terminate()
            try:
                process.wait(timeout=10)
            except subprocess.TimeoutExpired:
                process.kill()
                process.wait(timeout=5)


if __name__ == "__main__":
    main()
