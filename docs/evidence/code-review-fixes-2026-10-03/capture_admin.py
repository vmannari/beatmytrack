"""Capture the operational console against a disposable local database."""
import secrets
import socket
import sys
import tempfile
import threading
import time
from pathlib import Path

import uvicorn
from playwright.sync_api import sync_playwright

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / "backend"))
from bmt_backend.app import create_app
from bmt_backend.config import Settings
from bmt_backend.migrate import upgrade
from bmt_backend.operations import heartbeat

scratch = (ROOT / ".tools/review-capture").resolve()
scratch.mkdir(exist_ok=True)
fixture_build = {"engine_version":"4.7.2.stable.official.ed1daf0bf", "verifier_version":"canonical-verifier-1",
                 "physics_version":"arcade-planar-0.49", "rules_key":"standing-5-road-gates-v14"}

class FixtureVerifier:
    def manifest(self):
        return fixture_build

with tempfile.TemporaryDirectory(prefix="admin-", dir=scratch) as temporary:
    directory = Path(temporary).resolve()
    assert directory.parent == scratch and directory.name.startswith("admin-")
    key = secrets.token_urlsafe(40)
    app = create_app(Settings(environment="test", database_url=f"sqlite:///{directory.as_posix()}/review.sqlite",
        object_dir=str(directory / "objects"), admin_analyst_key=key), verifier=FixtureVerifier())
    upgrade(app.state.engine)
    heartbeat(app, "review-fixture", phase="idle", build=fixture_build)
    listener = socket.socket()
    listener.bind(("127.0.0.1", 0))
    server = uvicorn.Server(uvicorn.Config(app, log_level="error", access_log=False))
    thread = threading.Thread(target=server.run, kwargs={"sockets":[listener]}, daemon=True)
    thread.start()
    try:
        for _ in range(100):
            if server.started: break
            time.sleep(0.05)
        assert server.started
        with sync_playwright() as playwright:
            browser = playwright.chromium.launch(headless=True, channel="chrome")
            page = browser.new_page(viewport={"width":1440,"height":1000})
            errors = []
            page.on("pageerror", lambda error: errors.append(str(error)))
            page.goto(f"http://127.0.0.1:{listener.getsockname()[1]}/admin/#system")
            page.locator("#key").fill(key)
            page.get_by_role("button",name="Connect",exact=True).click()
            page.get_by_role("heading",name="Verified competition",exact=True).wait_for()
            assert page.get_by_text("queue capacity",exact=True).is_visible()
            page.evaluate("""() => { const note=document.createElement('div'); note.textContent='DISPOSABLE REVIEW FIXTURE'; note.style='position:fixed;right:12px;bottom:12px;background:#ffc928;color:#18212d;padding:10px;z-index:9999'; document.body.append(note); }""")
            page.screenshot(path=str(Path(__file__).with_name("admin-health.png")),full_page=True)
            assert not errors, errors
            browser.close()
        print("ADMIN_CAPTURE: operational health UI, 0 JavaScript errors; fixture data only")
    finally:
        server.should_exit = True
        thread.join(timeout=10)
        listener.close()
        app.state.engine.dispose()
