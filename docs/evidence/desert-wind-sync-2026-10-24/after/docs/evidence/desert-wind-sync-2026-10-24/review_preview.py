"""Check local preview playback, seeking and both native renderer selections."""
from pathlib import Path
import json
from playwright.sync_api import sync_playwright

E = Path(__file__).resolve().parent
errors = []
checks = []
with sync_playwright() as playwright:
    browser = playwright.chromium.launch(channel="msedge", headless=True, args=["--autoplay-policy=no-user-gesture-required"])
    page = browser.new_page(viewport={"width":1366,"height":1100})
    page.on("pageerror", lambda error: errors.append(str(error)))
    page.goto((E / "preview.html").as_uri())
    for renderer in ["mobile", "gl_compatibility"]:
        page.locator("#renderer").select_option(renderer)
        page.wait_for_function("sound.readyState >= 2 && sound.currentSrc.includes(document.getElementById('renderer').value)")
        page.evaluate("sound.currentTime=8")
        page.wait_for_function("view.complete && view.naturalWidth===1280 && view.src.includes(document.getElementById('renderer').value) && document.getElementById('status').textContent.startsWith('8.0')")
        page.evaluate("sound.play()")
        page.wait_for_function("sound.currentTime > 8.2")
        page.evaluate("sound.pause()")
        checks.append({"renderer":renderer,"frame":page.locator("#view").get_attribute("src"),"audio_time":page.evaluate("sound.currentTime")})
    browser.close()
assert not errors, errors
(E / "preview-review.json").write_text(json.dumps({"checks":checks,"page_errors":errors},indent=2)+"\n")
print("WIND_SYNC_PREVIEW: both renderers play and seek; zero page errors")
