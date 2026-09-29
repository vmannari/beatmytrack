"""Browser smoke against the local PC service; reads only, no player mutations."""

from pathlib import Path

from playwright.sync_api import sync_playwright

ROOT = Path(__file__).resolve().parents[2]
config = dict(
    line.split("=", 1)
    for line in (ROOT / ".tools/bmt-pc.env").read_text().splitlines()
    if "=" in line and not line.startswith("#")
)
output = ROOT / "docs/evidence/backend_ui"
output.mkdir(parents=True, exist_ok=True)
with sync_playwright() as p:
    browser = p.chromium.launch(
        executable_path="C:/Program Files/Google/Chrome/Application/chrome.exe", headless=True
    )
    page = browser.new_page(viewport={"width": 1600, "height": 1100}, device_scale_factor=1)
    errors = []
    page.on("pageerror", lambda error: errors.append(str(error)))
    page.goto("http://127.0.0.1:18181/admin")
    page.locator("#key").fill(config["BMT_ADMIN_OWNER_KEY"])
    page.get_by_role("button", name="Connect", exact=True).click()
    page.get_by_role("heading", name="The game, at a glance.").wait_for()
    page.screenshot(path=str(output / "overview.png"), full_page=True)
    for route in (
        "players",
        "tracks",
        "races",
        "economy",
        "live",
        "analytics",
        "system",
        "system/jobs",
        "system/audit",
        "system/access",
    ):
        page.evaluate("(route)=>location.hash=route", route)
        page.locator("#main .card").first.wait_for()
        assert not page.locator("#main .console-error").count(), route
    page.evaluate("location.hash='tracks'")
    page.locator("#filters").wait_for()
    page.screenshot(path=str(output / "tracks.png"), full_page=True)
    links = page.locator('tbody a[href^="#tracks/"]')
    if links.count():
        links.first.click()
        page.get_by_role("heading", name="Record", exact=True).wait_for()
        page.screenshot(path=str(output / "track_inspector.png"), full_page=True)
        page.locator("#command").click()
        page.get_by_role("heading", name="Track visibility preview").wait_for()
        page.screenshot(path=str(output / "confirmation.png"), full_page=True)
        page.keyboard.press("Escape")
        assert not page.locator("dialog").is_visible()
    page.keyboard.press("Control+k")
    page.locator("#global-query").fill("a")
    page.locator("#global-search button[type=button]").count()
    page.locator("#global-search button").first.click()
    page.locator("#search-results a, #search-results .console-empty").first.wait_for()
    page.keyboard.press("Escape")
    page.evaluate("location.hash='overview'")
    page.get_by_role("heading", name="The game, at a glance.").wait_for()
    page.emulate_media(reduced_motion="reduce")
    page.set_viewport_size({"width": 390, "height": 844})
    page.screenshot(path=str(output / "mobile.png"), full_page=True)
    assert page.evaluate("document.documentElement.scrollWidth <= innerWidth"), (
        "Page overflows mobile viewport"
    )
    page.locator("#menu").click()
    assert page.locator("#sidebar").evaluate("el=>el.getBoundingClientRect().left") >= 0
    page.locator("#close-nav").click()
    page.locator("#logout").click()
    page.locator("#key").fill(config["BMT_ADMIN_ANALYST_KEY"])
    page.get_by_role("button", name="Connect", exact=True).click()
    page.get_by_role("heading", name="The game, at a glance.").wait_for()
    assert page.locator("#role").inner_text() == "analyst access"
    page.reload()
    page.locator("#key").wait_for()
    assert page.locator("#key").input_value() == ""
    assert not errors, errors
    browser.close()
print(
    "Browser smoke passed: 11 routes, owner/analyst authentication, search, inspector, confirmation, mobile, lock/reload; no writes."
)
