"""Review the real public routes in a browser, using only a disposable test DB.

All browser traffic is intercepted into the local FastAPI TestClient. No real
Google verification, cloud service, player or purchase is contacted.
"""
import json
import sys
import tempfile
from pathlib import Path

from bmt_backend.app import create_app
from bmt_backend.config import Settings
from bmt_backend.migrate import upgrade
from fastapi.testclient import TestClient
from playwright.sync_api import sync_playwright

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "docs/evidence/game-website-2026-10-25"
ORIGIN = "https://website.example"


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    checks, errors, external, mutations, screenshots = [], [], [], [], []

    def check(condition, description):
        checks.append({"description": description, "passed": bool(condition)})
        if not condition:
            (OUT / "browser-results.json").write_text(json.dumps({"checks": checks, "errors": errors}, indent=2)+"\n", encoding="utf-8")
            raise AssertionError(description)

    with tempfile.TemporaryDirectory(prefix="bmt-website-") as temporary:
        folder = Path(temporary)
        settings = Settings(environment="test", database_url=f"sqlite:///{(folder / 'db.sqlite').as_posix()}",
                            object_dir=str(folder / "objects"), rate_limit_per_minute=10000)
        app = create_app(settings)
        upgrade(app.state.engine)
        try:
            with TestClient(app) as client, sync_playwright() as driver:
                browser = driver.chromium.launch(headless=True, executable_path="C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe")

                def handler(route):
                    request = route.request
                    if not request.url.startswith(ORIGIN + "/"):
                        external.append(request.url)
                        return route.abort()
                    if request.method != "GET":
                        mutations.append(request.url)
                        return route.abort()
                    response = client.get(request.url.removeprefix(ORIGIN))
                    headers = dict(response.headers)
                    # TestClient already decompresses the body.
                    headers.pop("content-encoding", None)
                    headers.pop("content-length", None)
                    route.fulfill(status=response.status_code, headers=headers, body=response.content)

                for width, height in ((1440, 1000), (1280, 720), (1024, 768), (768, 1024),
                                      (600, 800), (390, 844), (360, 740), (320, 568)):
                    context = browser.new_context(viewport={"width": width, "height": height}, reduced_motion="reduce")
                    context.route("**/*", handler)
                    page = context.new_page()
                    page.on("pageerror", lambda error: errors.append(str(error)))
                    page.on("console", lambda message: errors.append(message.text) if message.type == "error" else None)
                    response = page.goto(ORIGIN + "/")
                    page.evaluate("document.fonts.ready")
                    # Load every lazy image before inspecting dimensions/capturing.
                    for picture in page.locator("img").all():
                        picture.scroll_into_view_if_needed()
                    page.wait_for_function("Array.from(document.images).every(i => i.complete && i.naturalWidth > 0)")
                    check(response.status == 200, f"{width}: home is public")
                    check(page.locator("h1").count() == 1, f"{width}: one descriptive main heading")
                    check(page.evaluate("document.documentElement.scrollWidth <= innerWidth"), f"{width}: no horizontal page overflow")
                    overflow = page.evaluate("""() => Array.from(document.querySelectorAll('h1,h2,h3,p,li,nav,a')).filter(e => { const r=e.getBoundingClientRect(); return r.width && (r.left < -1 || r.right > innerWidth+1 || e.scrollWidth > e.clientWidth+1); }).map(e=>e.textContent.trim().slice(0,80))""")
                    check(not overflow, f"{width}: readable content fits: {overflow}")
                    check(page.locator(".site-header a[href='/account-deletion']").is_visible(), f"{width}: delete link visible in navigation")
                    for target in ("#game", "#create", "#garage", "#account"):
                        page.goto(ORIGIN + "/" + target)
                        check(page.locator(target).is_visible(), f"{width}: {target} section reachable")
                    check(context.cookies() == [], f"{width}: site sets no cookies")
                    check(page.evaluate("localStorage.length === 0 && sessionStorage.length === 0"), f"{width}: no browser storage")
                    check(page.locator("script").count() == 0, f"{width}: presentation works without scripts")
                    page.goto(ORIGIN + "/")
                    page.evaluate("document.fonts.ready")
                    page.get_by_role("link", name="Delete account", exact=False).first.click()
                    page.wait_for_url(ORIGIN + "/account-deletion")
                    check(page.locator("#delete").is_disabled(), f"{width}: visiting deletion never authorises it")
                    check(page.locator("#confirm").is_hidden(), f"{width}: identity verification required")
                    check(page.evaluate("document.documentElement.scrollWidth <= innerWidth"), f"{width}: deletion page fits")
                    if width in (1440, 390):
                        path = OUT / f"delete-{width}.png"
                        page.screenshot(path=str(path), full_page=True)
                        screenshots.append(path.name)
                    page.get_by_role("link", name="Home", exact=True).click()
                    page.wait_for_url(ORIGIN + "/")
                    check(page.locator("h1").is_visible(), f"{width}: return from deletion")
                    if width in (1440, 768, 390, 320):
                        page.evaluate("document.fonts.ready")
                        for picture in page.locator("img").all():
                            picture.scroll_into_view_if_needed()
                        page.wait_for_function("Array.from(document.images).every(i => i.complete && i.naturalWidth > 0)")
                        page.evaluate("scrollTo(0, 0)")
                        path = OUT / f"home-{width}.png"
                        page.screenshot(path=str(path), full_page=True)
                        screenshots.append(path.name)
                    context.close()

                context = browser.new_context(viewport={"width": 390, "height": 844}, java_script_enabled=False)
                context.route("**/*", handler)
                page = context.new_page()
                page.goto(ORIGIN + "/")
                check(page.get_by_role("link", name="Delete game account").count() == 1, "no JavaScript: account link is present")
                page.get_by_role("link", name="The game", exact=True).click()
                check(page.url.endswith("#game"), "no JavaScript: section navigation works")
                context.close()

                context = browser.new_context(viewport={"width": 1280, "height": 720})
                context.route("**/*", handler)
                page = context.new_page()
                page.goto(ORIGIN + "/")
                page.keyboard.press("Tab")
                check(page.locator(".skip-link").evaluate("e => e === document.activeElement"), "keyboard: skip link is first focus")
                page.keyboard.press("Enter")
                check(page.locator("main").evaluate("e => e === document.activeElement"), "keyboard: skip link focuses main content")
                context.close()
                browser.close()
        finally:
            app.state.engine.dispose()
    check(not external, "no external browser requests")
    check(not mutations, "browsing never submits an account mutation")
    check(not errors, "no browser errors: " + str(errors))
    result = {"checks": len(checks), "failures": 0, "details": checks, "screenshots": screenshots,
              "external_requests": external, "mutation_requests": mutations,
              "real_account_changes": False, "disposable_database": True}
    (OUT / "browser-results.json").write_text(json.dumps(result, indent=2)+"\n", encoding="utf-8")
    print(json.dumps({key: value for key, value in result.items() if key != "details"}))


if __name__ == "__main__":
    sys.exit(main())
