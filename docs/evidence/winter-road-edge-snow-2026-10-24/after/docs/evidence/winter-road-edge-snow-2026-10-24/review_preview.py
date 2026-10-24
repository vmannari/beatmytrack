from pathlib import Path
import json
from playwright.sync_api import sync_playwright

E = Path(__file__).resolve().parent
errors, checks = [], []
with sync_playwright() as playwright:
    browser = playwright.chromium.launch(channel="msedge", headless=True)
    page = browser.new_page()
    page.on("pageerror",lambda error:errors.append(str(error)))
    page.goto((E/"preview.html").as_uri())
    page.locator("#toggle").click()
    for renderer in ["mobile","gl_compatibility"]:
        page.locator("#renderer").select_option(renderer)
        for button,filename in [("original","before.png"),("edges","after.png"),("clear","without-snow.png")]:
            page.locator("#"+button).click()
            page.wait_for_function("comparison.complete && comparison.naturalWidth===1280 && comparison.src.endsWith('"+renderer+"/"+filename+"')")
        page.locator("#seek").fill("60")
        page.wait_for_function("motion.complete && motion.naturalWidth===1280 && motion.src.endsWith('"+renderer+"/frame-060.jpg')")
        checks.append(renderer)
    browser.close()
assert not errors,errors
(E/"preview-review.json").write_bytes((json.dumps(dict(renderers=checks,page_errors=errors),indent=2)+"\n").encode())
print("WINTER_EDGE_PREVIEW: both renderers, all comparison states and seeking pass")
