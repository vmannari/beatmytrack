"""Owned loopback pages and actual JS; Google identity completion is a fictional fixture."""
import argparse
import json
import os
import secrets
import socket
import subprocess
import sys
import time
from pathlib import Path
from urllib.request import Request, urlopen

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "backend"))


def serve(folder, port):
    import uvicorn
    from bmt_backend.app import create_app
    from bmt_backend.config import Settings
    from bmt_backend.identity_models import BrowserLogin, Identity, Player
    from bmt_backend.migrate import upgrade
    from bmt_backend.track_models import now
    from fastapi import HTTPException
    from sqlalchemy import select

    app = create_app(Settings(environment="development", database_url="sqlite:///" + str(folder / "db.sqlite"),
        object_dir=str(folder / "objects"), public_base_url=f"http://127.0.0.1:{port}",
        google_client_ids=("browser-fixture",), google_web_client_id="browser-fixture"))
    upgrade(app.state.engine)
    fixture_key = secrets.token_urlsafe(32)
    with app.state.session_factory() as session:
        player = Player(display_name="Browser <fixture>")
        session.add(player); session.flush()
        player_id = player.id
        session.add(Identity(player_id=player.id, provider="google", subject="fictional-browser-identity"))
        session.commit()
    (folder / "fixture.json").write_text(json.dumps({"key": fixture_key}), encoding="utf-8")

    @app.post("/fixture/complete")
    def complete(body: dict):
        if body != {"key": fixture_key}:
            raise HTTPException(403)
        with app.state.session_factory() as session:
            rows = session.scalars(select(BrowserLogin).where(BrowserLogin.consumed.is_(False),
                BrowserLogin.expires_at > now())).all()
            for row in rows:
                row.subject = "fictional-browser-identity"
            session.commit()
        return {"ok": True}

    @app.get("/fixture/state")
    def state():
        with app.state.session_factory() as session:
            return {"removed": session.get(Player, player_id).deleted_at is not None}

    uvicorn.run(app, host="127.0.0.1", port=port, log_level="warning", access_log=False)


def main():
    from playwright.sync_api import expect, sync_playwright
    folder = ROOT / ("build/privacy-20261014/browser-" + secrets.token_hex(4))
    folder.mkdir(parents=True, exist_ok=True)
    evidence = ROOT / "docs/evidence/account-privacy-2026-10-14/browser"
    evidence.mkdir(parents=True, exist_ok=True)
    with socket.socket() as reservation:
        reservation.bind(("127.0.0.1", 0)); port = reservation.getsockname()[1]
    base = f"http://127.0.0.1:{port}"
    log = (folder / "server.log").open("w", encoding="utf-8")
    secure_python = ROOT / ".tools/backend-secure-venv/Scripts/python.exe"
    server = subprocess.Popen([str(secure_python), str(Path(__file__)), "--serve", str(folder), "--port", str(port)],
        stdout=log, stderr=log, creationflags=subprocess.CREATE_NO_WINDOW if os.name == "nt" else 0)
    checks, errors, deleted_requests, external = [], [], [], []

    def check(value, label):
        assert value, label
        checks.append(label)

    try:
        for _ in range(100):
            try:
                with urlopen(base + "/health", timeout=1) as response:
                    if response.status == 200: break
            except OSError:
                time.sleep(.1)
        else: raise RuntimeError("Owned privacy service unavailable")
        fixture = json.loads((folder / "fixture.json").read_text())
        with sync_playwright() as driver:
            browser = driver.chromium.launch(headless=True, executable_path="C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe")
            context = browser.new_context(viewport={"width": 1440, "height": 1000})
            def boundary(route):
                if route.request.url.startswith(base + "/"):
                    route.continue_()
                else:
                    external.append("blocked external provider fixture asset")
                    route.abort()
            context.route("**/*", boundary)
            page = context.new_page()
            page.on("pageerror", lambda error: errors.append(str(error)))
            page.goto(base + "/privacy")
            expect(page.get_by_role("heading", name="Privacy policy", exact=True)).to_be_visible()
            check("placeholders" in page.locator("main").inner_text(), "policy clearly identifies unfinished legal contacts")
            check(context.cookies() == [], "public resource sets no tracking cookie")
            for width in [1440, 960, 390]:
                page.set_viewport_size({"width": width, "height": 1000})
                check(page.evaluate("document.documentElement.scrollWidth <= innerWidth"), f"policy contained at {width}px")
                page.screenshot(path=str(evidence / f"privacy-{width}.png"), full_page=True)
                page.goto(base + "/account-deletion")
                check(page.evaluate("document.documentElement.scrollWidth <= innerWidth"), f"deletion page contained at {width}px")
                page.screenshot(path=str(evidence / f"deletion-{width}.png"), full_page=True)
                page.goto(base + "/privacy")
            page.goto(base + "/account-deletion")
            check(page.locator("#confirm").is_hidden(), "deletion is unavailable before verification")
            with page.expect_popup() as popup:
                page.get_by_role("button", name="Verify with Google").click()
            popup.value.wait_for_url(base + "/v1/auth/google/browser*")
            with urlopen(Request(base + "/fixture/complete", data=json.dumps(fixture).encode(),
                headers={"Content-Type": "application/json"}), timeout=5): pass
            expect(page.locator("#confirm")).to_be_visible(timeout=20000)
            check(page.locator("#name").inner_text() == "Browser <fixture>", "verified name is text, never interpreted as HTML")
            check(page.locator("#delete").is_disabled(), "explicit confirmation is required after verification")
            page.locator("#agreement").check()
            def lose_first_ack(route):
                deleted_requests.append(route.request.post_data_json)
                if len(deleted_requests) == 1:
                    response = route.fetch()  # Server commits; caller loses only its acknowledgement.
                    check(response.status == 202, "first browser deletion receives a committed server response")
                    route.abort()
                else: route.continue_()
            page.route("**/v1/privacy/web-delete", lose_first_ack)
            page.locator("#delete").click()
            expect(page.locator("#status")).to_contain_text("Could not connect", timeout=20000)
            with urlopen(base + "/fixture/state", timeout=5) as response:
                check(json.load(response)["removed"], "lost browser acknowledgement follows a real committed removal")
            page.locator("#delete").click()
            expect(page.locator("#status")).to_contain_text("Account removed", timeout=20000)
            check(len(deleted_requests) == 2 and deleted_requests[0] == deleted_requests[1], "browser retry reuses the exact verified token and operation")
            check(page.evaluate("localStorage.length === 0 && sessionStorage.length === 0"), "browser leaves no credentials or recovery tokens in storage")
            page.screenshot(path=str(evidence / "deletion-confirmed-390.png"), full_page=True)
            check(errors == [], "main pages have no JavaScript exceptions")
            browser.close()
        result = {"checks": checks, "passed": len(checks), "errors": errors,
            "identity": "fictional completion fixture; no Google account or provider verification used",
            "external_assets_blocked": len(external), "owned_loopback_service": True}
        (evidence / "review.json").write_text(json.dumps(result, indent=2), encoding="utf-8")
        print("Privacy browser:", len(checks), "checks passed")
    finally:
        server.terminate()
        try: server.wait(timeout=10)
        except subprocess.TimeoutExpired: server.kill(); server.wait(timeout=5)
        log.close()


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--serve")
    parser.add_argument("--port", type=int)
    arguments = parser.parse_args()
    if arguments.serve: serve(Path(arguments.serve), arguments.port)
    else: main()
