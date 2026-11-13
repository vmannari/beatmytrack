"""Offline Chromium review of the actual ranking JS and shared CSS; every API is mocked."""
import json
from pathlib import Path

from playwright.sync_api import sync_playwright

ROOT = Path(__file__).resolve().parents[3]
HERE = Path(__file__).resolve().parent
UI = ROOT / "backend/bmt_backend/admin_ui"
app = (UI / "app.js").read_text(encoding="utf-8")
helpers = [line for line in app.splitlines() if line.startswith(("const $=", "const date=", "function intro(", "function card(", "function kv(", "function link("))]
helpers.append(app[app.index("function scopedHref("):app.index("\nfunction link(")])
helpers.append("\n".join((UI / "platform.js").read_text(encoding="utf-8").splitlines()[:11]))
data = {
    "enabled": True, "state": "ready", "launch_week": 1792972800, "published_week": 1792972800,
    "published_snapshot": 12, "published_at": 1793577600, "published_ranked": 12000, "phase": "idle",
    "pending": False, "as_of": 1793577600, "worker_last_seen_at": 1793577599,
    "history": [], "history_scope": "Latest corrections.", "circuits_truncated": False,
    "circuits": [{"id": 7, "week_start": 1792972800, "closed": True, "original_snapshot": 12,
        "policy": "multi-car-circuit-v2", "tracks": [], "cars": [
            {"vehicle_id": car, "participation_bps": bonus, "weights_locked": True,
             "tracks": [{"version_id": f"{car}-track-{slot}", "name": f"Official track {slot+1}"} for slot in range(5)]}
            for car, bonus in (("compact", 12000), ("electric", 11500), ("kart", 10800), ("forklift", 10000), ("hovercraft", 10000))]}],
}
fixture = r"""
let role='owner',reporting=null,reviewToken=0;
window.previewBodies=[];
if(!crypto.randomUUID)crypto.randomUUID=()=> '00000000-0000-4000-8000-000000000001';
async function api(path,body){
 if(path==='studio/ranking')return window.reviewData;
 if(path==='studio/ranking/correction-preview'){
  window.previewBodies.push(body);
  return {kind:'exclude_player',reason:body.reason,effect:'Rebuild the selected car result; the previous publication stays visible.'};
 }
 throw new Error('Unexpected offline request: '+path);
}
function modal(html){const dialog=document.querySelector('#dialog');if(dialog.open)dialog.close();dialog.innerHTML=html;reviewToken++;dialog.showModal();for(const b of dialog.querySelectorAll('[data-close]'))b.onclick=()=>dialog.close();}
function dialogToken(){return reviewToken;}
function dialogIsCurrent(token){return token===reviewToken&&document.querySelector('#dialog').open;}
function render(){}
"""

with sync_playwright() as playwright:
    candidates = [Path(playwright.chromium.executable_path),
        Path("C:/Program Files/Google/Chrome/Application/chrome.exe"),
        Path("C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe")]
    candidates += list(Path("C:/Users/ville/AppData/Local/ms-playwright").glob("chromium*/chrome-win*/chrome.exe"))
    executable = next((candidate for candidate in candidates if candidate.is_file()), None)
    assert executable is not None, "An installed Chromium browser is required; do not download one for this review"
    browser = playwright.chromium.launch(headless=True, executable_path=str(executable))
    page = browser.new_page(viewport={"width": 1440, "height": 1000}, device_scale_factor=1)
    page.route("**/*", lambda route: route.abort())
    errors = []
    page.on("pageerror", lambda error: errors.append(str(error)))
    css = "\n".join((UI / name).read_text(encoding="utf-8") for name in ("style.css", "platform.css"))
    page.set_content("<html lang='en'><head><style>"+css+"</style></head><body><main id='review' style='max-width:1200px;margin:32px auto'></main><dialog id='dialog'></dialog></body></html>")
    page.evaluate("data => window.reviewData=data", data)
    page.add_script_tag(content=fixture+"\n"+"\n".join(helpers)+"\n"+(UI / "ranking.js").read_text(encoding="utf-8"))
    page.evaluate("async () => {document.querySelector('#review').innerHTML=await rankingWorkspace(new URLSearchParams());wireRanking();}")
    assert page.get_by_role("heading", name="Recent Circuits", exact=True).count() == 1
    assert page.get_by_role("columnheader", name="Cars and participation", exact=True).count() == 1
    assert "electric · +15.0%" in page.locator("body").inner_text()
    assert page.evaluate("document.body.scrollWidth<=innerWidth")
    page.screenshot(path=str(HERE / "admin-overview.png"), full_page=True)
    page.locator("#ranking-correction").click()
    page.locator("[name=vehicle_id]").select_option("electric")
    page.locator("[name=player_id]").fill("00000000-0000-4000-8000-000000000002")
    page.locator("[name=reason]").fill("Review the Volt result only")
    page.screenshot(path=str(HERE / "admin-car-scope.png"), full_page=True)
    page.locator("#ranking-preview [type=submit]").click()
    page.locator("#ranking-confirm").wait_for()
    assert page.evaluate("window.previewBodies[0].vehicle_id") == "electric"
    assert "electric" in page.locator("#dialog").inner_text()
    page.screenshot(path=str(HERE / "admin-confirmation-electric.png"), full_page=True)
    assert errors == [], errors
    (HERE / "admin-review.json").write_text(json.dumps({"checks": 7, "errors": errors, "api": "offline mocked only"}, indent=2), encoding="utf-8")
    browser.close()
print("RANKING_ADMIN_BROWSER checks=7 failures=0; all requests mocked")
