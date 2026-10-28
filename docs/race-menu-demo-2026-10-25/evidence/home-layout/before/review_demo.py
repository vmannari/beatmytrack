"""Exercise the offline demo in a real browser using disposable browser state."""
import json
from pathlib import Path

from playwright.sync_api import sync_playwright

HERE = Path(__file__).resolve().parent
OUT = HERE / "evidence"


def main():
    OUT.mkdir(exist_ok=True)
    checks, errors, network = [], [], []

    def check(ok, description):
        checks.append({"description": description, "passed": bool(ok)})
        if not ok:
            raise AssertionError(description)

    try:
        with sync_playwright() as driver:
            browser = driver.chromium.launch(
                headless=True,
                executable_path="C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe",
            )
            context = browser.new_context(viewport={"width": 1440, "height": 1000}, reduced_motion="reduce")
            page = context.new_page()
            page.on("pageerror", lambda error: errors.append(str(error)))
            page.on("request", lambda request: network.append(request.url) if request.url.startswith(("http:", "https:")) else None)
            page.goto((HERE / "index.html").as_uri())
            page.evaluate("document.fonts.ready")
            check(page.locator('[role="tab"]').count() == 4, "Four visible, named mode tabs")
            check(page.locator("#page-daily").is_visible(), "First opening selects Track of the Day")
            check(page.locator("#daily-route .route").count() == 1, "Daily scenic route preview is rendered")
            check(page.locator(".daily-scene").evaluate("e=>getComputedStyle(e).backgroundImage.startsWith('url(')"), "Embedded scenic artwork is applied by the browser")
            page.screenshot(path=str(OUT / "01-daily-desktop.png"), full_page=True)

            page.locator('#page-daily [data-action="cars"]').click()
            check(page.locator("#modal").is_visible(), "Car selector opens as a modal")
            check(page.locator("[data-car]").count() == 7, "All seven cars available in the selector")
            page.locator('[data-car="electric"]').click()
            check(page.locator("#page-daily .car-caption .current-car-name").inner_text() == "Electric", "Selected car updates daily view")
            check(page.locator(".best-time").inner_text() == "01:08.270", "Daily best and record are scoped to selected car")

            page.locator('#page-daily [data-race="pine"]').click()
            check("Electric" in page.locator("#dialog-body").inner_text(), "Race preview carries selected car")
            page.locator("#preview-start").click()
            page.wait_for_function("document.querySelectorAll('.light.on').length === 5")
            check(page.locator(".light.on").count() == 5, "All five red lights illuminate before release")
            page.wait_for_function("document.querySelector('#race-status').textContent.startsWith('Lights out')")
            check(page.locator(".light.on").count() == 0, "Five red lights extinguish at the start")
            check(page.locator("#preview-start").is_enabled(), "Race-start preview returns to an actionable menu button")
            page.locator("#preview-start").click()
            check(not page.locator("#modal").is_visible(), "Preview returns to originating race page")

            page.locator("#tab-weekly").click()
            page.locator('[data-weekly="frost"]').click()
            check(page.locator("#weekly-race").get_attribute("data-race") == "frost", "Weekly track selection changes Race destination")
            page.locator("#weekly-race").click()
            check("Frostline" in page.locator("#dialog-body").inner_text(), "Weekly Race opens selected track")
            page.keyboard.press("Escape")
            page.screenshot(path=str(OUT / "02-weekly-desktop.png"), full_page=True)

            page.locator("#tab-free").click()
            page.locator("#track-search").fill("Mika")
            check(page.locator(".track-card").count() == 2, "Track search matches creator names")
            page.locator('[data-biome="winter"]').click()
            check(page.locator(".track-card").count() == 1, "Biome filtering combines with search")
            page.locator("#tab-weekly").click()
            check(page.locator('[data-weekly="frost"]').get_attribute("aria-pressed") == "true", "Weekly track selection is retained across modes")
            page.locator("#tab-free").click()
            check(page.locator("#track-search").input_value() == "Mika", "Search is retained across modes")
            page.locator('[data-favorite="snow"]').click()
            page.locator("#favorites-filter").click()
            check(page.locator(".track-card").count() == 1, "Favorites combine with active search and biome filter")
            page.locator('[data-favorite="snow"]').click()
            check(page.locator(".empty").is_visible(), "Removing the last favorite gives a recoverable empty state")
            page.locator('[data-action="clear-filters"]').click()
            check(page.locator(".track-card").count() == 8, "Clear filters restores the full demo catalogue")
            page.locator('[data-action="random"]').click()
            check(page.locator("#dialog-title").inner_text() == "Ready to race", "Random opens a track preview")
            page.keyboard.press("Escape")
            page.screenshot(path=str(OUT / "03-free-race-desktop.png"), full_page=True)

            page.locator("#tab-challenges").click()
            check(page.locator(".challenge-card").count() == 3, "Discover shows the three challenge formats")
            page.locator('[data-challenge="duel"]').click()
            page.locator('[data-join="duel"]').click()
            page.locator('#dialog-body [data-race="pine"]').click()
            check("Compact" in page.locator("#dialog-body .race-info").first.inner_text(), "Challenge retains its pinned car despite a different general car selection")
            page.keyboard.press("Escape")
            page.locator('[data-folder="joined"]').click()
            check(page.locator(".challenge-card").count() == 1, "Joining a challenge adds it to Joined")
            page.locator('#page-challenges [data-action="create"]').click()
            page.locator('[name="name"]').fill('Weekend <race> & "friends"')
            page.locator('[name="format"]').select_option("3×3 series")
            check(not page.locator("#create-track-label").is_visible(), "3×3 creation uses the three fixed demo tracks")
            check(page.locator('[name="tries"]').is_disabled(), "3×3 creation fixes three tries per track")
            page.locator('#create-form [type="submit"]').click()
            check(page.locator('[data-folder="created"]').get_attribute("aria-pressed") == "true", "Creation opens the Created folder")
            check('Weekend <race> & "friends"' in page.locator(".challenge-card").inner_text(), "Created title is rendered as text, including markup characters")
            page.locator('[data-folder="discover"]').click()
            page.wait_for_timeout(2900)
            page.screenshot(path=str(OUT / "04-challenges-desktop.png"), full_page=True)

            page.locator("#tab-daily").focus()
            page.keyboard.press("ArrowRight")
            check(page.locator("#tab-weekly").get_attribute("aria-selected") == "true", "Arrow keys navigate and activate focused mode tabs")
            page.keyboard.press("End")
            check(page.locator("#tab-challenges").get_attribute("aria-selected") == "true", "End key selects the final tab")
            page.reload()
            check(page.locator("#page-challenges").is_visible(), "Last mode is remembered for the browser session")

            for width, height in [(1280, 800), (960, 540), (844, 390), (390, 844), (320, 568)]:
                page.set_viewport_size({"width": width, "height": height})
                for mode in ["daily", "weekly", "free", "challenges"]:
                    page.locator("#tab-" + mode).click()
                    page.wait_for_timeout(40)
                    dimensions = page.evaluate("({viewport:innerWidth, document:document.documentElement.scrollWidth})")
                    check(dimensions["document"] <= dimensions["viewport"], f"{mode}: no horizontal overflow at {width}×{height}")
                    tabs = page.locator('[role="tab"]').evaluate_all("nodes=>nodes.map(n=>{const r=n.getBoundingClientRect();return {left:r.left,right:r.right,height:r.height}})")
                    check(all(t["left"] >= 0 and t["right"] <= width and t["height"] >= 52 for t in tabs), f"{mode}: all four mode targets visible and ≥52px at {width}×{height}")
                    if (width, mode) in [(960, "daily"), (960, "weekly"), (844, "daily"), (390, "daily"), (390, "free"), (390, "challenges")]:
                        page.evaluate("scrollTo(0,0)")
                        page.wait_for_timeout(60)
                        page.screenshot(path=str(OUT / f"{mode}-{width}x{height}.png"), full_page=width < 600)
                    page.evaluate("scrollTo(0,document.documentElement.scrollHeight)")
                    pinned = page.locator('[role="tab"]').evaluate_all("nodes=>nodes.every(n=>{const r=n.getBoundingClientRect();return r.top>=0 && r.bottom<=innerHeight})")
                    check(pinned, f"{mode}: four-mode selection stays visible after scrolling at {width}×{height}")
                    if width == 844 and mode == "daily":
                        page.evaluate("scrollTo(0,0)")
                        bottom = page.locator('#page-daily > .daily-layout .cta').bounding_box()
                        check(bottom["y"] + bottom["height"] <= height, "Landscape phone can reach Daily Race without scrolling")

            check(not errors, "No browser JavaScript errors")
            check(not network, "Self-contained demo makes no HTTP requests")
            browser.close()
    finally:
        report = {"checks": checks, "passed": sum(c["passed"] for c in checks), "failed": sum(not c["passed"] for c in checks), "errors": errors, "external_requests": network, "physical_device_test": False}
        (OUT / "browser-report.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
        print(f"Browser checks: {report['passed']} passed, {report['failed']} failed")


if __name__ == "__main__":
    main()
