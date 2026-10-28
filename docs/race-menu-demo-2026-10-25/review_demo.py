"""Review the combined Race overview and retained detail flows in a real browser."""
import json
from pathlib import Path

from playwright.sync_api import sync_playwright

HERE = Path(__file__).resolve().parent
OUT = HERE / "evidence" / "home-layout"


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    checks, errors, network = [], [], []

    def check(ok, description):
        checks.append({"description": description, "passed": bool(ok)})
        if not ok:
            raise AssertionError(description)

    try:
        with sync_playwright() as driver:
            browser = driver.chromium.launch(headless=True, executable_path="C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe")
            context = browser.new_context(viewport={"width": 1440, "height": 1000}, reduced_motion="reduce")
            page = context.new_page()
            page.on("pageerror", lambda error: errors.append(str(error)))
            page.on("request", lambda request: network.append(request.url) if request.url.startswith(("http:", "https:")) else None)
            page.goto((HERE / "index.html").as_uri())
            page.evaluate("document.fonts.ready")

            def visit(mode):
                page.locator('.primary-nav [data-mode="home"]').click()
                if mode != "home":
                    page.locator(f'#page-home [data-mode="{mode}"]').first.click()

            def capture(name, full=True):
                page.evaluate("scrollTo(0,0)")
                page.screenshot(path=str(OUT / name), full_page=full)

            check(page.locator("#page-home").is_visible(), "Race opens on the combined overview")
            check(page.locator("nav").count() == 1, "Only the original main navigation bar is present")
            check(page.locator('[role="tablist"]').count() == 0, "No parallel mode tab bar")
            check(page.locator("#home-daily").is_visible() and page.locator("#home-weekly").is_visible(), "Both featured events are present")
            check(page.locator("#home-weekly-tracks button").count() == 5, "Overview shows all five weekly track choices")
            capture("home-1440x1000.png")
            page.locator('#page-home [data-action="cars"]').click()
            check(page.locator("[data-car]").count() == 7, "Shared car picker contains all seven cars")
            page.locator('[data-car="electric"]').click()
            check(page.locator("#home-best").inner_text() == "01:08.270", "Overview best updates for the chosen car")
            page.locator('#home-daily [data-race="pine"]').click()
            check("Electric" in page.locator("#dialog-body").inner_text(), "Direct daily Race uses the selected car")
            page.locator("#preview-start").click()
            page.wait_for_function("document.querySelectorAll('.light.on').length === 5")
            check(page.locator(".light.on").count() == 5, "Five red lights illuminate")
            page.wait_for_function("document.querySelector('#race-status').textContent.startsWith('Lights out')")
            page.locator("#preview-start").click()
            check(page.locator("#page-home").is_visible() and not page.locator("#modal").is_visible(), "Direct Race returns to the combined overview")
            visit("daily")
            check(page.locator(".best-time").inner_text() == "01:08.270", "Daily detail retains the selected car")
            page.locator('#page-daily [aria-label="Back to Race"]').click()
            check(page.locator("#page-home").is_visible(), "Detail Back returns to Race overview")
            page.locator('[data-home-track="frost"]').click()
            check(page.locator("#page-weekly").is_visible() and page.locator("#weekly-race").get_attribute("data-race") == "frost", "Overview thumbnail opens the correct weekly track")
            page.locator("#weekly-race").click()
            check("Frostline" in page.locator("#dialog-body").inner_text(), "Weekly Race opens the selected track")
            page.keyboard.press("Escape")
            capture("weekly-detail-1440x1000.png")
            visit("weekly")
            check(page.locator('[data-weekly="frost"]').get_attribute("aria-pressed") == "true", "Continue Rivalry retains the weekly selection")
            visit("free")
            page.locator("#track-search").fill("Mika")
            check(page.locator(".track-card").count() == 2, "Search matches track creators")
            page.locator('[data-biome="winter"]').click()
            check(page.locator(".track-card").count() == 1, "Search combines with biome filters")
            visit("free")
            check(page.locator("#track-search").input_value() == "Mika", "Search survives overview navigation")
            page.locator('[data-favorite="snow"]').click()
            page.locator("#favorites-filter").click()
            check(page.locator(".track-card").count() == 1, "Favorites combine with existing filters")
            page.locator('[data-favorite="snow"]').click()
            check(page.locator(".empty").is_visible(), "Removing last favorite presents a recoverable empty state")
            page.locator('[data-action="clear-filters"]').click()
            check(page.locator(".track-card").count() == 8, "Clear filters restores all tracks")
            page.locator('[data-action="random"]').click()
            check(page.locator("#dialog-title").inner_text() == "Ready to race", "Random opens a race preview")
            page.keyboard.press("Escape")
            capture("free-detail-1440x1000.png")
            visit("challenges")
            check(page.locator(".challenge-card").count() == 3, "Challenges retain all three formats")
            page.locator('[data-challenge="duel"]').click()
            page.locator('[data-join="duel"]').click()
            page.locator('#dialog-body [data-race="pine"]').click()
            check("Compact" in page.locator("#dialog-body .race-info").first.inner_text(), "Challenge keeps its pinned car")
            page.keyboard.press("Escape")
            page.locator('[data-folder="joined"]').click()
            check(page.locator(".challenge-card").count() == 1, "Joined challenges remain accessible")
            page.locator('#page-challenges [data-action="create"]').click()
            page.locator('[name="name"]').fill('Weekend <race> & "friends"')
            page.locator('[name="format"]').select_option("3×3 series")
            check(not page.locator("#create-track-label").is_visible() and page.locator('[name="tries"]').is_disabled(), "3×3 creation retains fixed tracks and tries")
            page.locator('#create-form [type="submit"]').click()
            check('Weekend <race> & "friends"' in page.locator(".challenge-card").inner_text(), "Created titles are safe text")
            visit("challenges")
            check(page.locator('[data-folder="created"]').get_attribute("aria-pressed") == "true", "Challenge folder survives overview navigation")
            page.locator('[data-folder="discover"]').click()
            page.wait_for_timeout(2900)
            capture("challenges-detail-1440x1000.png")

            for width, height in [(1280, 800), (960, 540), (844, 390), (390, 844), (320, 568)]:
                page.set_viewport_size({"width": width, "height": height})
                for mode in ["home", "daily", "weekly", "free", "challenges"]:
                    visit(mode)
                    page.evaluate("scrollTo(0,0)")
                    dimensions = page.evaluate("({viewport:innerWidth, document:document.documentElement.scrollWidth})")
                    check(dimensions["document"] <= dimensions["viewport"], f"{mode}: no horizontal overflow at {width}×{height}")
                    if mode == "home":
                        check(page.locator('.home-panel-header').evaluate_all("nodes=>nodes.every(n=>[...n.children].every(c=>{const a=n.getBoundingClientRect(),b=c.getBoundingClientRect();return b.left>=a.left && b.right<=a.right}))"), f"Event headings and countdowns fit their cards at {width}px")
                        daily = page.locator("#home-daily").bounding_box()
                        weekly = page.locator("#home-weekly").bounding_box()
                        if width >= 700:
                            check(abs(daily["y"]-weekly["y"]) < 1 and daily["x"]+daily["width"] < weekly["x"], f"Featured events sit side by side at {width}×{height}")
                            check(abs(daily["height"]-weekly["height"]) < 1, f"Featured panels have equal heights at {width}×{height}")
                            if width >= 700:
                                quick = page.locator('.home-other-modes').bounding_box()
                                check(quick["y"]+quick["height"] <= height, f"Overview shows all four choices without scrolling at {width}×{height}")
                        else:
                            check(weekly["y"] >= daily["y"]+daily["height"], f"Panels stack without clipping at {width}px")
                        capture(f"home-{width}x{height}.png", full=width < 600)
                    if mode in ["free", "challenges"] and width == 390:
                        capture(f"{mode}-{width}x{height}.png")
                    page.evaluate("scrollTo(0,document.documentElement.scrollHeight)")
                    header = page.locator(".topbar").bounding_box()
                    check(header["y"] >= 0 and header["y"]+header["height"] <= height, f"{mode}: main Race navigation remains visible after scrolling at {width}×{height}")
            page.reload()
            check(page.locator("#page-home").is_visible(), "Fresh opening returns to the combined overview")
            check(not errors, "No browser JavaScript errors")
            check(not network, "Self-contained demo makes no HTTP requests")
            browser.close()
    finally:
        report = {"layout": "side-by-side Race overview; no secondary top navigation", "checks": checks, "passed": sum(c["passed"] for c in checks), "failed": sum(not c["passed"] for c in checks), "errors": errors, "external_requests": network, "physical_device_test": False}
        (OUT / "browser-report.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
        print(f"Browser checks: {report['passed']} passed, {report['failed']} failed")


if __name__ == "__main__":
    main()
