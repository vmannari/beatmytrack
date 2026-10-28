"""Check the real private-proxy sign-in page without signing in or touching player data."""

import argparse
import json
import re
from pathlib import Path
from urllib.parse import urlsplit

from playwright.sync_api import expect, sync_playwright

ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "docs/evidence/studio-recovery-2026-10-25"


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--probe-csp", action="store_true")
    parser.add_argument("--expect-limited", action="store_true")
    args = parser.parse_args()
    output = ROOT / "docs/evidence/studio-shared-reporting-2026-10-25" if args.expect_limited else OUTPUT
    output.mkdir(parents=True, exist_ok=True)
    errors, failures = [], []
    with sync_playwright() as playwright:
        browser = playwright.chromium.launch(channel="msedge", headless=True)
        context = browser.new_context(viewport={"width": 1280, "height": 800})
        context.add_init_script("window.__studioCsp=[];document.addEventListener('securitypolicyviolation',e=>"
            "window.__studioCsp.push({blocked:e.blockedURI.split('?')[0],directive:e.violatedDirective}));")
        page = context.new_page()
        if args.probe_csp:
            def probe(route):
                response = route.fetch()
                headers = dict(response.headers)
                headers["content-security-policy"] = headers["content-security-policy"].replace(
                    "script-src 'self'", "script-src 'self' https://apis.google.com")
                route.fulfill(response=response, headers=headers)
            page.route("**/admin", probe)
        # Record only a provider error code in this isolated diagnostic browser.
        # The deployed page and authentication logic are otherwise unchanged.
        def instrument(route):
            response = route.fetch()
            source = response.text().replace("function errorText(error) {",
                "function errorText(error) { window.__studioErrorCode=error.code||error.name;")
            route.fulfill(response=response, body=source)
        page.route("**/admin/assets/signin.js", instrument)
        page.on("pageerror", lambda error: errors.append(str(error)))
        def response_seen(response):
            url = urlsplit(response.url)
            if response.status >= 400 and url.path != "/favicon.ico":
                failures.append({"host": url.netloc, "path": url.path, "status": response.status})
        page.on("response", response_seen)
        page.goto("http://127.0.0.1:8182/admin", wait_until="networkidle")
        google = page.get_by_role("button", name="Sign in with Google", exact=True)
        expect(google).to_be_visible(timeout=30000)
        expect(google).to_be_enabled()
        expect(page.locator("#role")).to_have_text("Authentication required")
        expect(page.locator("#key")).to_have_count(0)
        policy = page.request.get("http://127.0.0.1:8182/v1/admin/auth/config").json().get("reporting", {})
        if args.expect_limited:
            assert policy.get("mode") == "shared_limited" and policy.get("max_days") == 7
            assert policy.get("sql_budget_ms") == 1500
            assert page.locator('#days option[value="30"]').is_disabled()
            assert page.locator('#days option[value="90"]').is_disabled()
        page.screenshot(path=str(output / "live-signin-desktop.png"))
        page.set_viewport_size({"width": 390, "height": 844})
        expect(google).to_be_visible()
        assert page.evaluate("document.documentElement.scrollWidth <= innerWidth")
        page.screenshot(path=str(output / "live-signin-mobile.png"))
        # Exercise the real provider handoff only as far as Google's account
        # sign-in page. This fresh browser has no owner session or credentials.
        try:
            with page.expect_popup(timeout=20000) as opening:
                google.click()
        except Exception:
            print(json.dumps({"provider_error_code": page.evaluate("window.__studioErrorCode || null"),
                "javascript_errors": errors, "failed_requests": failures,
                "csp": page.evaluate("window.__studioCsp")}, indent=2))
            page.screenshot(path=str(output / "live-provider-diagnostic.png"))
            raise
        popup = opening.value
        popup.wait_for_url(re.compile(r"^https://accounts\.google\.com/"), timeout=30000)
        provider_host = urlsplit(popup.url).hostname
        popup.close()
        expect(google).to_be_enabled(timeout=10000)
        assert errors == [], json.dumps(errors)
        assert failures == [], json.dumps(failures)
        context.close()
        browser.close()
    result = {"google_button_visible_enabled": True, "legacy_key_field_absent": True,
        "csp_probe_override": args.probe_csp,
        "reporting_policy": policy,
        "desktop": "1280x800", "mobile": "390x844", "javascript_errors": errors,
        "failed_requests": failures, "google_provider_handoff": provider_host,
        "credentials_entered": False,
        "real_mfa_enrollment": "pending owner interaction", "player_writes": False}
    (output / "live-browser.json").write_text(json.dumps(result, indent=2), encoding="utf-8")
    print(json.dumps(result, indent=2))


if __name__ == "__main__":
    main()
