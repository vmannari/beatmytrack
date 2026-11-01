"""Check the real published website in a fresh browser, without signing in.

The only live writes are a temporary Google verification challenge and its
cancellation. Account deletion and credential submission are explicitly blocked.
"""
import argparse
import json
from pathlib import Path
from urllib.parse import urlsplit

from playwright.sync_api import expect, sync_playwright

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "docs/evidence/website-publication-2026-10-25"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("url")
    arguments = parser.parse_args()
    origin = arguments.url.rstrip("/")
    parsed = urlsplit(origin)
    assert parsed.scheme == "https" and parsed.hostname.endswith(".run.app")
    OUT.mkdir(parents=True, exist_ok=True)
    errors, failures, forbidden, checks = [], [], [], []
    temporary_token = None

    def check(value, description):
        checks.append({"description": description, "passed": bool(value)})
        assert value, description

    with sync_playwright() as driver:
        browser = driver.chromium.launch(channel="msedge", headless=True)
        context = browser.new_context(viewport={"width": 1440, "height": 1000}, reduced_motion="reduce")

        def deny(route):
            forbidden.append(urlsplit(route.request.url).path)
            route.abort()

        context.route("**/v1/privacy/web-delete", deny)
        context.route("**/v1/auth/google/browser/complete", deny)

        def response_seen(response):
            nonlocal temporary_token
            path = urlsplit(response.url).path
            if path == "/v1/auth/google/browser/start" and response.status == 201:
                temporary_token = response.json()["poll_token"]
            if response.status >= 400 and path != "/favicon.ico":
                failures.append({"host": urlsplit(response.url).hostname, "path": path, "status": response.status})

        page = context.new_page()
        page.on("pageerror", lambda error: errors.append(str(error)))
        context.on("response", response_seen)
        try:
            for width, height in ((1440, 1000), (390, 844)):
                page.set_viewport_size({"width": width, "height": height})
                response = page.goto(origin + "/", wait_until="networkidle")
                page.evaluate("document.fonts.ready")
                for picture in page.locator("img").all():
                    picture.scroll_into_view_if_needed()
                page.evaluate("() => Promise.all(Array.from(document.images, image => image.decode()))")
                check(response.status == 200, f"{width}: published homepage loads")
                check(page.evaluate("document.documentElement.scrollWidth <= innerWidth"), f"{width}: no horizontal overflow")
                check(page.locator(".site-header a[href='/account-deletion']").is_visible(), f"{width}: deletion link visible")
                check(context.cookies([origin]) == [], f"{width}: homepage sets no cookies before Google verification")
                page.evaluate("scrollTo(0,0)")
                page.screenshot(path=str(OUT / f"live-home-{width}.png"), full_page=True)
                page.screenshot(path=str(OUT / f"live-hero-{width}.png"))
                page.get_by_role("link", name="Delete account", exact=False).first.click()
                expect(page.locator("#signin")).to_be_enabled()
                check(page.locator("#delete").is_disabled(), f"{width}: cannot delete without verification")
                check(page.locator("#confirm").is_hidden(), f"{width}: confirmation remains hidden until verification")
                check(page.evaluate("document.documentElement.scrollWidth <= innerWidth"), f"{width}: deletion page fits")
                page.screenshot(path=str(OUT / f"live-delete-{width}.png"), full_page=True)
                page.get_by_role("link", name="Home", exact=True).click()
                expect(page.locator("h1")).to_be_visible()
                check(page.url == origin + "/", f"{width}: return to homepage")
            page.goto(origin + "/privacy")
            check(page.get_by_role("heading", name="Privacy policy", exact=True).is_visible(), "privacy page available")
            contact_pending = "[Privacy contact — to be confirmed]" in page.locator("body").inner_text()
            page.goto(origin + "/community-rules")
            check(page.get_by_role("heading", name="Public sharing rules", exact=True).is_visible(), "community rules available")
            page.goto(origin + "/account-deletion")
            with page.expect_popup(timeout=20000) as opening:
                page.locator("#signin").click()
            popup = opening.value
            popup.on("pageerror", lambda error: errors.append(str(error)))
            expect(popup.locator("#status")).to_contain_text("Continue with your Google account", timeout=30000)
            expect(popup.locator("#google iframe")).to_be_visible(timeout=30000)
            check(True, "Google verification challenge prepares and real Google button loads")
            popup.screenshot(path=str(OUT / "live-google-verification.png"))
            popup.close()
            check(page.locator("#delete").is_disabled(), "leaving Google verification never enables account deletion")
            provider_cookies = [{"name": item["name"], "domain": item["domain"]}
                                for item in context.cookies([origin])]
            check(all(item["name"] == "g_state" for item in provider_cookies),
                  "only Google's expected sign-in state cookie appears after opening Google verification")
            check(not forbidden, "no deletion or credential submission attempted")
            check(not errors, "no browser JavaScript errors")
            check(not failures, "no failed page, asset or provider requests: " + str(failures))
        finally:
            if temporary_token:
                response = context.request.post(origin + "/v1/auth/google/browser/cancel", data={"token": temporary_token})
                check(response.status == 204, "temporary verification challenge cancelled")
            context.close()
            browser.close()
    result = {"url": origin, "checks": checks, "failures": failures, "javascript_errors": errors,
              "credentials_entered": False, "account_deleted": False, "temporary_challenge_cancelled": True,
              "privacy_identity_contact_pending": contact_pending, "physical_device_test": False,
              "cookies_after_google_verification": provider_cookies}
    (OUT / "live-browser.json").write_text(json.dumps(result, indent=2)+"\n", encoding="utf-8")
    print(json.dumps({key: value for key, value in result.items() if key != "checks"}, indent=2))


if __name__ == "__main__":
    main()
