"""Exercise deletion verification and cancellation with a fully mocked browser.

No live provider, server, or player account is contacted.
"""
import json
from dataclasses import replace
from pathlib import Path

from bmt_backend.app import create_app
from bmt_backend.browser_auth import page as browser_page
from bmt_backend.config import Settings
from bmt_backend.privacy_pages import deletion_page
from bmt_backend.public_pages import ASSETS
from playwright.sync_api import sync_playwright
from starlette.requests import Request

ROOT = Path(__file__).resolve().parents[1]
ORIGIN = "https://fixture.example"
PREVIEW = {
    "schema_version": 1, "player_id": "fixture", "server_now": 1800000000,
    "publishing_slots": 1, "coins": 2, "banked_resumes": 0,
    "cosmetic_unlocks": 0, "pending_purchases": 0, "ad_free": False,
    "ad_free_until": 0, "ad_free_forever": False,
}


def main():
    app = create_app(Settings(environment="test"))
    app.state.settings = replace(app.state.settings, google_client_ids=("fixture",), google_web_client_id="fixture")
    html = deletion_page(Request({"type": "http", "app": app}))
    browser_response = browser_page()
    state = {"ready": False, "starts": 0, "sessions": 0, "completions": 0, "cancels": [], "deletes": 0}
    errors = []
    with sync_playwright() as driver:
        browser = driver.chromium.launch(
            headless=True, executable_path="C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe"
        )
        context = browser.new_context()

        def intercept(route):
            request = route.request
            if request.url == "https://accounts.google.com/gsi/client":
                route.fulfill(content_type="text/javascript", body="""
                    window.google = {accounts: {id: {
                      initialize: config => { window.fixtureConfig = config; },
                      renderButton: element => {
                        const button = document.createElement('button');
                        button.textContent = 'Simulate Google sign-in';
                        button.onclick = () => window.fixtureConfig.callback({credential: 'fixture-provider-token'});
                        element.appendChild(button);
                      }
                    }}};
                """)
                return
            assert request.url.startswith(ORIGIN + "/"), request.url
            path = request.url[len(ORIGIN):].split("#")[0]
            if path == "/account-deletion":
                route.fulfill(status=200, headers=dict(html.headers), body=html.body)
            elif path in ("/privacy/deletion.js", "/privacy/style.css"):
                asset = ROOT / "backend/bmt_backend/privacy_ui" / path.rsplit("/", 1)[-1]
                route.fulfill(content_type="text/javascript" if path.endswith(".js") else "text/css",
                              body=asset.read_bytes())
            elif path.startswith("/site/") and path[6:] in ASSETS:
                asset = ROOT / "backend/bmt_backend/public_ui" / path[6:]
                route.fulfill(content_type=ASSETS[path[6:]], body=asset.read_bytes())
            elif path == "/v1/auth/google/browser/start":
                state["starts"] += 1
                route.fulfill(json={"poll_token": "fixture-" + str(state["starts"]),
                                    "browser_url": ORIGIN + "/v1/auth/google/browser#fixture"})
            elif path == "/v1/auth/google/browser":
                route.fulfill(status=200, headers=dict(browser_response.headers), body=browser_response.body)
            elif path == "/v1/auth/google/browser/prepare":
                assert request.post_data_json == {"token": "fixture"}
                route.fulfill(json={"client_id": "fixture", "nonce": "fixture-nonce", "display_name": ""})
            elif path == "/v1/auth/google/browser/complete":
                assert request.post_data_json == {"token": "fixture", "id_token": "fixture-provider-token"}
                state["ready"] = True
                state["completions"] += 1
                route.fulfill(json={"status": "complete"})
            elif path == "/v1/privacy/web-session":
                state["sessions"] += 1
                route.fulfill(json=({"status": "ready", "display_name": "Fixture",
                                    "deletion_preview": PREVIEW} if state["ready"] else {"status": "pending"}))
            elif path == "/v1/auth/google/browser/cancel":
                state["cancels"].append(request.post_data_json["token"])
                route.fulfill(status=204)
            elif path == "/v1/privacy/web-delete":
                state["deletes"] += 1
                route.abort()
            else:
                raise AssertionError("Unexpected request: " + request.url)

        context.route("**/*", intercept)
        page = context.new_page()
        page.on("pageerror", lambda error: errors.append(str(error)))
        page.goto(ORIGIN + "/account-deletion")

        # Closing before completing sign-in promptly enables a fresh attempt.
        with page.expect_popup() as event:
            page.locator("#signin").click()
        popup = event.value
        popup.get_by_role("button", name="Simulate Google sign-in").wait_for()
        assert popup.url == ORIGIN + "/v1/auth/google/browser"
        page.wait_for_timeout(1500)
        assert page.locator("#signin").is_disabled(), "an open isolated popup is mistaken for a closed window"
        popup.close()
        page.get_by_text("Verification window closed. You can try again.").wait_for(timeout=6000)
        assert page.locator("#signin").is_enabled()
        assert page.locator("#confirm").is_hidden() and page.locator("#delete").is_disabled()
        page.wait_for_timeout(200)
        assert state["cancels"] == ["fixture-1"]

        # The real sign-in page can finish while its popup remains open.
        with page.expect_popup() as event:
            page.locator("#signin").click()
        popup = event.value
        popup.get_by_role("button", name="Simulate Google sign-in").click()
        popup.get_by_text("Signed in. You can return to the game.").wait_for()
        page.locator("#confirm").wait_for(state="visible", timeout=8000)
        assert not popup.is_closed()
        assert page.locator("#name").inner_text() == "Fixture"
        assert page.locator("#delete").is_disabled()
        popup.close()
        assert state["cancels"] == ["fixture-1"]

        # Google may finish just before the window closes: preserve the success.
        state["ready"] = False
        with page.expect_popup() as event:
            page.locator("#signin").click()
        popup = event.value
        popup.get_by_role("button", name="Simulate Google sign-in").click()
        popup.get_by_text("Signed in. You can return to the game.").wait_for()
        popup.close()
        page.locator("#confirm").wait_for(state="visible", timeout=6000)
        assert page.locator("#signin").is_enabled()
        assert page.locator("#delete").is_disabled()
        assert page.locator("#name").inner_text() == "Fixture"
        assert state["cancels"] == ["fixture-1"]

        # A blocked popup must not allocate a server-side verification challenge.
        blocked = context.new_page()
        blocked.add_init_script("window.open = () => null")
        blocked.goto(ORIGIN + "/account-deletion")
        blocked.locator("#signin").click()
        blocked.get_by_text("Allow the verification window, then retry.").wait_for()
        assert blocked.locator("#signin").is_enabled() and state["starts"] == 3
        assert not errors and state["deletes"] == 0 and state["completions"] == 2
        assert context.cookies() == []
        assert page.evaluate("localStorage.length + sessionStorage.length") == 0
        assert "#" not in page.url
        print(json.dumps({"status": "passed", **state, "errors": errors}))
        browser.close()
    app.state.engine.dispose()


if __name__ == "__main__":
    main()
