"""GET-only acceptance of the owner-authorized live backend and Studio."""
import importlib.util
import json
from pathlib import Path

from playwright.sync_api import expect, sync_playwright

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("latest_rollout", ROOT / ".tools/backend_latest_rollout_20261016.py")
deployment = importlib.util.module_from_spec(spec)
spec.loader.exec_module(deployment)
assert deployment.r.get("verify_live")
base = deployment.r["url"]
resource = deployment.service.describe("api", deployment.service.n["api"])
key = deployment.u.staff_key(resource)
checks, errors, writes, failures = [], [], [], []
with sync_playwright() as driver:
    browser = driver.chromium.launch(headless=True,
        executable_path="C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe")
    page = browser.new_page(viewport={"width": 1440, "height": 1050})
    page.on("pageerror", lambda error: errors.append(str(error)))
    page.on("request", lambda request: writes.append(request.method) if
        request.url.startswith(base) and request.method not in ("GET", "HEAD", "OPTIONS") else None)
    page.on("response", lambda response: failures.append(response.status) if
        response.url.startswith(base + "/v1/admin/") and response.status >= 400 else None)
    page.goto(base + "/admin#overview")
    page.fill("#key", key); page.locator("#login button").click()
    expect(page.locator("h1")).to_have_text("Overview", timeout=60000)
    expect(page.locator(".insight-pulse")).to_be_visible()
    expect(page.locator("#main")).to_contain_text("Where do you want to go?")
    assert page.evaluate("document.documentElement.scrollWidth<=innerWidth")
    page.screenshot(path=str(deployment.OUTPUT / "live-overview-1440.png"), full_page=True)
    checks.append("live overview renders current operational priorities, findings and task links")
    page.locator('a.console-nav[data-route="alarms"]').click()
    expect(page.locator("h1")).to_have_text("Alarms", timeout=60000)
    expect(page.locator(".alarm-snapshot")).to_contain_text("8 checks available")
    expect(page.locator("#alarm-filters")).to_be_visible()
    if page.locator(".alarm-row").count():
        page.locator(".alarm-row").first.click()
        expect(page.locator("#alarm-title")).to_be_visible()
        expect(page.locator(".alarm-guide")).to_contain_text("Check the evidence")
    page.screenshot(path=str(deployment.OUTPUT / "live-alarms-1440.png"), full_page=True)
    checks.append("live alarm desk loads eight check definitions with state filters and actual issue evidence")
    page.set_viewport_size({"width": 390, "height": 844})
    assert page.evaluate("document.documentElement.scrollWidth<=innerWidth")
    page.screenshot(path=str(deployment.OUTPUT / "live-alarms-390.png"), full_page=True)
    page.evaluate("location.hash='overview'")
    expect(page.locator("h1")).to_have_text("Overview", timeout=60000)
    assert page.evaluate("document.documentElement.scrollWidth<=innerWidth")
    page.screenshot(path=str(deployment.OUTPUT / "live-overview-390.png"), full_page=True)
    checks.append("live overview and alarm desk contain at 390px")
    page.set_viewport_size({"width": 1440, "height": 1000})
    page.evaluate("location.hash='studio'")
    expect(page.locator("h1")).to_have_text("Data coverage", timeout=60000)
    checks.append("source coverage navigation loads from the deployed backend")
    page.locator("#logout").click()
    expect(page.locator("#login")).to_be_visible()
    assert page.evaluate("key===''&&role===''&&reporting===null&&localStorage.length===0&&sessionStorage.length===0")
    checks.append("Lock clears administrative credentials, reporting and browser storage")
    assert not errors and not writes and not failures, (errors, writes, failures)
    checks.append("no JavaScript errors, failed admin reads or live mutation requests")
    browser.close()
receipt = {"checks": checks, "javascript_errors": errors, "live_mutation_requests": writes,
    "failed_admin_reads": failures, "read_only": True, "origin": base,
    "screenshots": [p.name for p in deployment.OUTPUT.glob("live-*.png")]}
(deployment.OUTPUT / "live-browser.json").write_text(json.dumps(receipt, indent=2) + "\n", encoding="utf-8")
deployment.r["live_browser"] = True
deployment.save()
print(json.dumps({"live_browser_checks": len(checks), "javascript_errors": len(errors), "live_mutation_requests": len(writes)}))
