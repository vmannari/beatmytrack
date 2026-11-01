"""Read-only HTTP and Edge checks for the website review release.

All browser requests are limited to GET on the exact target origin. This does
not open Google's sign-in window, create a challenge, or submit credentials.
"""
import argparse
import hashlib
import json
import re
from pathlib import Path
from urllib.parse import urlsplit

import requests
from playwright.sync_api import sync_playwright

ROOT = Path(__file__).resolve().parents[1]
RELEASE = ROOT / ".tmp/website-improvements/release/release.json"
CA_FILE = ROOT / ".tools/gcp-staging/windows-trust.pem"
CANONICAL = "https://bmt-stg-e7a444ab-api-tzgxkrwzva-ew.a.run.app"


def validate_origin(url):
    parsed = urlsplit(url)
    hostname = parsed.hostname or ""
    allowed = re.fullmatch(
        r"(?:[a-z][a-z0-9-]{0,62}---)?bmt-stg-e7a444ab-api-tzgxkrwzva-ew\.a\.run\.app", hostname
    )
    if (parsed.scheme != "https" or not allowed or parsed.username or parsed.password
            or parsed.path not in ("", "/") or parsed.query or parsed.fragment or parsed.port):
        raise ValueError("The target must be the existing staging API or its tagged revision")
    return f"https://{hostname}"


def verify(origin, output):
    origin = validate_origin(origin)
    output.mkdir(parents=True, exist_ok=True)
    release = json.loads(RELEASE.read_text(encoding="utf-8"))
    expected = release["overlay_sha256"]
    checks, errors, blocked, failed_responses = [], [], [], []

    def check(condition, description):
        checks.append({"description": description, "passed": bool(condition)})
        if not condition:
            (output / "failed-check.json").write_text(json.dumps({
                "origin": origin, "checks": checks, "browser_errors": errors,
                "blocked_requests": blocked, "failed_responses": failed_responses,
            }, indent=2) + "\n", encoding="utf-8")
            raise AssertionError(description)

    with requests.Session() as session:
        session.verify = str(CA_FILE)
        session.headers["Cache-Control"] = "no-cache"

        def get(path, status=200):
            response = session.get(origin + path, timeout=40, allow_redirects=False)
            check(response.status_code == status, f"GET {path} returned {status}")
            check("set-cookie" not in response.headers, f"GET {path} sets no cookie")
            return response

        for path in ("/health", "/ready"):
            get(path)

        home = get("/")
        check("RACE THE LINE." in home.text and "ACTUAL GAMEPLAY" in home.text,
              "Homepage serves the reviewed gameplay-led design")
        check("/site/style-v3.css" in home.text and "worlds-v1.webp" not in home.text,
              "Homepage loads the revised stylesheet and omits the illustrated montage")
        check(f'<link rel="canonical" href="{CANONICAL}/">' in home.text,
              "Canonical address uses the configured public origin")
        check(f'{CANONICAL}/site/social-gameplay-v1.png' in home.text,
              "Social preview uses actual gameplay")
        check(home.headers.get("x-robots-tag") == "noindex, nofollow", "Staging homepage is not indexed")
        csp = home.headers.get("content-security-policy", "")
        check("default-src 'none'" in csp and "frame-ancestors 'none'" in csp,
              "Homepage has restrictive content and framing policies")
        check(home.headers.get("x-content-type-options") == "nosniff", "Homepage prevents MIME sniffing")
        check("<script" not in home.text.lower(), "Homepage does not execute scripts")

        privacy = get("/privacy")
        check("Ville Mannari" in privacy.text and "[Developer name" not in privacy.text,
              "Privacy identifies the approved developer")
        check("[Privacy contact — to be confirmed]" in privacy.text,
              "Privacy contact is explicitly pending")

        deletion = get("/account-deletion")
        check('id="signin" disabled' not in deletion.text and 'id="signin"' in deletion.text,
              "Google verification is configured")
        check('id="delete" disabled' in deletion.text and 'id="confirm" hidden' in deletion.text
              and 'id="agreement"' in deletion.text and 'id="benefits"' in deletion.text,
              "Deletion requires verification, disclosure and explicit confirmation")
        check(deletion.headers.get("cross-origin-opener-policy") == "same-origin-allow-popups",
              "Deletion and Google verification use compatible popup isolation")
        check("frame-ancestors 'none'" in deletion.headers.get("content-security-policy", ""),
              "Deletion cannot be framed")
        google_page = get("/v1/auth/google/browser")
        check(google_page.headers.get("cross-origin-opener-policy") == "same-origin-allow-popups",
              "Google verification page uses compatible popup isolation")

        get("/community-rules")
        check("Disallow: /" in get("/robots.txt").text, "Staging robots disallows indexing")
        get("/sitemap.xml", status=404)
        get("/site/.env", status=404)

        for path, name in (("/site/style-v3.css", "public_ui/style-v3.css"),
                           ("/site/social-gameplay-v1.png", "public_ui/social-gameplay-v1.png"),
                           ("/privacy/deletion.js", "privacy_ui/deletion.js"),
                           ("/privacy/style.css", "privacy_ui/style.css")):
            response = get(path)
            check(hashlib.sha256(response.content).hexdigest() == expected[name],
                  f"{path} matches the frozen release")

    with sync_playwright() as driver:
        browser = driver.chromium.launch(channel="msedge", headless=True)
        try:
            for width, height in ((1440, 1000), (768, 1024), (390, 844), (320, 568)):
                context = browser.new_context(viewport={"width": width, "height": height}, reduced_motion="reduce")

                def guard(route):
                    request = route.request
                    parts = urlsplit(request.url)
                    target = urlsplit(origin)
                    if request.method != "GET" or (parts.scheme, parts.netloc) != (target.scheme, target.netloc):
                        blocked.append({"method": request.method, "url": request.url})
                        return route.abort()
                    return route.continue_()

                context.route("**/*", guard)
                context.on("response", lambda response: failed_responses.append(
                    {"url": response.url, "status": response.status}) if response.status >= 400 else None)
                page = context.new_page()
                page.on("pageerror", lambda error: errors.append(str(error)))
                page.on("console", lambda message: errors.append(message.text) if message.type == "error" else None)
                for path in ("/", "/privacy", "/account-deletion", "/community-rules"):
                    response = page.goto(origin + path, wait_until="networkidle", timeout=40000)
                    page.evaluate("() => document.fonts.ready")
                    for picture in page.locator("img").all():
                        picture.scroll_into_view_if_needed()
                    # String predicates passed to wait_for_function require
                    # unsafe-eval, which this site's CSP intentionally forbids.
                    page.evaluate("() => Promise.all(Array.from(document.images, image => image.decode()))")
                    check(response.status == 200, f"{width}px {path} renders")
                    check(page.evaluate("document.documentElement.scrollWidth <= innerWidth"),
                          f"{width}px {path} has no horizontal overflow")
                    check(context.cookies() == [], f"{width}px {path} browsing sets no cookies")
                    if path == "/account-deletion":
                        check(page.locator("#signin").is_enabled() and page.locator("#delete").is_disabled()
                              and page.locator("#confirm").is_hidden(),
                              f"{width}px deletion starts safely gated")
                    if width in (1440, 390) and path in ("/", "/account-deletion"):
                        page.evaluate("scrollTo(0, 0)")
                        page.screenshot(path=str(output / f"{path.strip('/') or 'home'}-{width}.png"), full_page=True)
                context.close()
        finally:
            browser.close()

    check(not errors, f"No browser errors: {errors}")
    check(not blocked, f"No external or mutating browser requests: {blocked}")
    check(not failed_responses, f"No failed page or asset responses: {failed_responses}")
    result = {"origin": origin, "checks": checks, "browser_errors": errors,
              "blocked_requests": blocked, "failed_responses": failed_responses,
              "real_google_verification": False, "account_mutation": False}
    (output / "verification.json").write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    return {"origin": origin, "checks": len(checks), "failures": 0,
            "real_google_verification": False, "account_mutation": False}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("origin")
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    print(json.dumps(verify(args.origin, args.output), indent=2))


if __name__ == "__main__":
    main()
