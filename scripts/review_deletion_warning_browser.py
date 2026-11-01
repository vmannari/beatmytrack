"""Exercise the shipped deletion page/JS with intercepted APIs, never a real account.

Run with the backend Python, with .tools/review/Lib/site-packages on PYTHONPATH
to use the existing local Playwright installation. All browser traffic is mocked.
"""
import json
import sys
from dataclasses import replace
from pathlib import Path

from bmt_backend.app import create_app
from bmt_backend.config import Settings
from bmt_backend.privacy_pages import deletion_page
from bmt_backend.public_pages import ASSETS
from playwright.sync_api import sync_playwright
from starlette.requests import Request

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "docs/evidence/deletion-benefits-warning-2026-10-25"
VALUE = {"schema_version": 1, "player_id": "fixture-owner", "server_now": 1800000000,
    "publishing_slots": 7, "coins": 12345, "banked_resumes": 4, "cosmetic_unlocks": 9,
    "pending_purchases": 1, "ad_free": True, "ad_free_until": 1831536000, "ad_free_forever": False}


def main():
    app = create_app(Settings(environment="test"))
    app.state.settings = replace(app.state.settings, google_client_ids=("test-client",), google_web_client_id="test-client")
    # Call the actual public HTML handler without middleware, startup or a database.
    response = deletion_page(Request({"type": "http", "app": app}))
    assert response.status_code == 200
    errors, requests = [], []
    state = {"preview": VALUE.copy(), "fail_delete": True}
    checks = 0

    def check(condition, description):
        nonlocal checks
        checks += 1
        assert condition, description

    with sync_playwright() as driver:
        browser = driver.chromium.launch(headless=True, executable_path="C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe")
        context = browser.new_context(viewport={"width": 960, "height": 720})
        # Make only the five-second verification poll immediate in this mock test.
        context.add_init_script("const delay=window.setTimeout; window.setTimeout=(fn,ms,...args)=>delay(fn,ms===5000?0:ms,...args);")

        def route_handler(route):
            request = route.request
            path = request.url.removeprefix("https://fixture.example")
            if path == "/account-deletion":
                route.fulfill(status=200, headers=dict(response.headers), body=response.body)
            elif path in ("/privacy/deletion.js", "/privacy/style.css"):
                asset = ROOT / "backend/bmt_backend/privacy_ui" / path.rsplit("/", 1)[-1]
                route.fulfill(status=200, content_type="text/javascript" if path.endswith(".js") else "text/css", body=asset.read_bytes())
            elif path.startswith("/site/") and path[6:] in ASSETS:
                asset = ROOT / "backend/bmt_backend/public_ui" / path[6:]
                route.fulfill(status=200, content_type=ASSETS[path[6:]], body=asset.read_bytes())
            elif path == "/v1/auth/google/browser/start":
                route.fulfill(json={"poll_token": "fictional-verification", "browser_url": "https://fixture.example/v1/auth/google/browser#fictional"})
            elif path == "/v1/auth/google/browser":
                route.fulfill(body="Fictional Google verification completed")
            elif path == "/v1/privacy/web-session":
                route.fulfill(json={"status": "ready", "display_name": "<img src=x onerror=alert(1)>", "deletion_preview": state["preview"]})
            elif path == "/v1/privacy/web-delete":
                requests.append(request.post_data_json)
                route.fulfill(status=503 if state["fail_delete"] else 202,
                    json={"detail": "UNAVAILABLE"} if state["fail_delete"] else {"status": "requested"})
            else:
                route.abort()

        context.route("**/*", route_handler)
        page = context.new_page()
        page.on("pageerror", lambda error: errors.append(str(error)))
        page.on("console", lambda message: errors.append(message.text) if "Content Security Policy" in message.text else None)
        page.goto("https://fixture.example/account-deletion")
        check(page.locator("#delete").is_disabled(), "cannot delete before verification")

        def verify():
            page.locator("#signin").click()
            page.locator("#signin:not([disabled])").wait_for()

        verify()
        check(page.locator("#confirm").is_visible(), "verified snapshot is visible")
        text = page.locator("#benefits").inner_text()
        for fragment in ("Publishing slots: 7", "Coins: 12345", "Banked resumes: 4", "Online cosmetic unlocks: 9", "365 days, 0 hours", "UTC", "Pending purchases: 1"):
            check(fragment in text, "discloses "+fragment)
        check(page.locator("#name img").count() == 0 and "<img" in page.locator("#name").inner_text(), "account name uses safe text, never HTML")
        check(page.locator("#delete").is_disabled(), "requires explicit acknowledgement")
        page.locator("#agreement").check()
        check(page.locator("#delete").is_enabled(), "acknowledged valid snapshot enables deletion")
        page.screenshot(path=str(OUT / "web-deletion-960.png"), full_page=True)
        page.locator("#delete").click()
        page.locator("#signin:not([disabled])").wait_for()
        check(page.locator("#delete").is_enabled(), "lost response can retry the same operation")
        state["fail_delete"] = False
        page.locator("#delete").click()
        page.locator("#confirm").wait_for(state="hidden")
        check(len(requests) == 2 and requests[0] == requests[1], "deletion retries preserve token and operation identity")
        check(page.locator("#delete").is_disabled(), "completed deletion clears ready state")
        verify()
        check(not page.locator("#agreement").is_checked() and page.locator("#delete").is_disabled(), "new verification resets acknowledgement")
        for bad in (None, {**VALUE, "coins": -1}, {**VALUE, "ad_free": False}, {**VALUE, "ad_free_until": "tomorrow"}):
            state["preview"] = bad
            verify()
            check(page.locator("#confirm").is_hidden() and page.locator("#delete").is_disabled(), "missing or invalid preview never enables deletion")
        state["preview"] = {**VALUE, "ad_free": False, "ad_free_until": 0, "publishing_slots": 0, "pending_purchases": 0}
        verify()
        check("none active" in page.locator("#benefits").inner_text() and "Publishing slots: 0" in page.locator("#benefits").inner_text(), "zero and expired benefits are truthful")
        state["preview"] = {**VALUE, "ad_free_forever": True}
        verify()
        check("no scheduled expiry" in page.locator("#benefits").inner_text(), "legacy no-expiry access remains truthful")
        check(not errors, "no browser script or CSP errors: "+str(errors))
        browser.close()
    result = {"checks": checks, "failures": 0, "all_requests_intercepted": True, "real_account_changes": False}
    (OUT / "browser-results.json").write_text(json.dumps(result, indent=2)+"\n", encoding="utf-8")
    print(json.dumps(result))


if __name__ == "__main__":
    sys.exit(main())
