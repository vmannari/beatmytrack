"""Exercise the real Usage & costs page in Edge against an owned synthetic server."""
import argparse
import json
import secrets
import socket
import subprocess
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path[:0] = [str(ROOT / "backend"), str(ROOT / "backend/tests")]


def serve(folder, port):
    from types import SimpleNamespace

    import uvicorn
    from bmt_backend.app import create_app
    from bmt_backend.config import Settings
    from bmt_backend.identity_models import Player
    from bmt_backend.migrate import upgrade
    from bmt_backend.studio_platform_models import AnalysisDay, AnalysisState
    from bmt_backend.studio_reporting import StudioReporting
    from bmt_backend.track_models import now
    from sqlalchemy import select
    from test_domains import FakeVerifier
    from test_studio_usage import cloud_fixture

    config = json.loads((folder / "config.private.json").read_text())
    settings = Settings(environment="test", workload_role="admin", studio_legacy_keys_enabled=True,
        admin_owner_key=config["owner"], admin_analyst_key=config["analyst"],
        database_url="sqlite:///" + (folder / "database.sqlite").as_posix(), object_dir=str(folder / "objects"),
        studio_usage_project="fixture-project", studio_usage_resources='{"services":["fixture-api"]}')
    app = create_app(settings, verifier=FakeVerifier())
    upgrade(app.state.engine)
    app.state.studio_reporting.close()
    app.state.studio_reporting = StudioReporting(settings, engine=app.state.engine)
    mode = {"value":"observed"}
    def observed(*args):
        if mode["value"] == "missing":
            return {"status":"not_configured","resources":[],"metrics":{},"sources":[],
                "billing":{"status":"not_configured","rows":[]}}
        if mode["value"] == "pending":
            data = cloud_fixture()
            data["billing"] = {"status":"export_pending","rows":[]}
            return data
        if mode["value"] == "credits":
            data = cloud_fixture()
            data["billing"]["rows"][0].update(net=-20, credits=-30)
            return data
        return cloud_fixture(now()-901 if mode["value"] == "stale" else None)
    app.state.studio_usage_cloud = SimpleNamespace(collect=observed)
    @app.post("/fixture/usage-mode")
    def fixture_mode(value: str):
        assert value in ("observed","missing","stale","pending","credits")
        mode["value"] = value
        return {"fixture_mode":value}
    with app.state.session_factory() as db:
        ville, other = Player(display_name="Ville"), Player(display_name="Other")
        db.add_all((ville, other))
        db.flush()
        for p, count in ((ville, 20), (other, 80)):
            db.add(AnalysisDay(day=now() // 86400, player_id=p.id, dimension="a" * 64,
                first_at=now()-300, last_at=now(), counters={"active":1,"network_attempts":count}))
        db.get(AnalysisState, 1).processed_through = now()
        db.get(AnalysisState, 1).started_at = (now() // 86400 - 14) * 86400
        db.commit()
        assert db.scalar(select(Player.id).where(Player.display_name == "Ville"))
    uvicorn.run(app, host="127.0.0.1", port=port, log_level="warning")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--serve", type=Path)
    parser.add_argument("--port", type=int)
    parser.add_argument("--output", type=Path, default=ROOT / "docs/evidence/studio-usage-costs-2026-10-27")
    args = parser.parse_args()
    if args.serve:
        return serve(args.serve, args.port)
    import httpx
    from playwright.sync_api import expect, sync_playwright

    folder = ROOT / "build/studio-usage-costs-2026-10-27" / ("browser-" + secrets.token_hex(4))
    folder.mkdir(parents=True, exist_ok=True)
    args.output.mkdir(parents=True, exist_ok=True)
    config = {k:secrets.token_urlsafe(32) for k in ("owner", "analyst")}
    (folder / "config.private.json").write_text(json.dumps(config))
    with socket.socket() as sock:
        sock.bind(("127.0.0.1", 0))
        port = sock.getsockname()[1]
    errors, checks = [], []
    with (folder / "server.log").open("w", encoding="utf-8") as log:
        process = subprocess.Popen([sys.executable, str(Path(__file__).resolve()), "--serve", str(folder), "--port", str(port)],
            stdout=log, stderr=log, creationflags=subprocess.CREATE_NO_WINDOW)
        try:
            with httpx.Client(base_url=f"http://127.0.0.1:{port}",timeout=10) as client:
                for _ in range(100):
                    if process.poll() is not None:
                        raise RuntimeError("Owned fixture stopped; inspect browser/server.log")
                    try:
                        if client.get("/health").status_code == 200:
                            break
                    except httpx.ConnectError:
                        pass
                    time.sleep(.2)
                else:
                    raise RuntimeError("Fixture startup timeout")
                with sync_playwright() as driver:
                    browser = driver.chromium.launch(headless=True,
                        executable_path="C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe")
                    page = browser.new_page(viewport={"width":1440,"height":1100})
                    page.on("pageerror",lambda e:errors.append(str(e)))
                    page.goto(f"http://127.0.0.1:{port}/admin#usage")
                    page.locator("#key").fill(config["owner"])
                    page.locator("#login button").click()
                    expect(page.get_by_role("heading",name="Usage & costs",exact=True)).to_be_visible()
                    expect(page.locator('.console-nav[data-route="usage"]')).to_have_attribute("aria-current","page")
                    checks.append("real authenticated route and selected navigation")
                    expect(page.locator(".usage-summary")).to_contain_text("high resource reading")
                    expect(page.locator(".usage-resource.critical")).to_have_count(1)
                    expect(page.locator(".usage-resource.warning")).to_have_count(1)
                    expect(page.locator(".usage-stats")).to_contain_text("Ville only")
                    expect(page.locator("#main")).to_contain_text("1 active player in this scope")
                    checks.append("critical CPU, warning memory, Ville denominator and cost rendered")
                    expect(page.locator("#main")).to_contain_text("Planning scenario · Low confidence")
                    page.screenshot(path=str(args.output/"usage-desktop.png"))
                    page.locator('[data-usage-filter="attention"]').click()
                    expect(page.locator('.usage-resource:visible')).to_have_count(2)
                    expect(page.locator('.usage-filter-count')).to_contain_text("Showing 2")
                    page.locator('[data-usage-group-select]').select_option("application")
                    expect(page.locator('.usage-filter-empty')).to_be_visible()
                    page.locator('[data-usage-group-select]').select_option("all")
                    page.locator('[data-usage-filter="unknown"]').click()
                    assert page.locator('.usage-resource:visible').count()>=2
                    expect(page.locator('.usage-resource.critical')).not_to_be_visible()
                    page.locator('[data-usage-filter="observed"]').click()
                    checks.append("capacity filters combine status and resource group; unknowns remain inspectable")
                    page.locator('[data-usage-chart="EUR"] .usage-column.missing').first.focus()
                    page.keyboard.press("Enter")
                    expect(page.locator('[data-usage-chart="EUR"] .usage-day-details')).to_contain_text("No exported rows")
                    page.locator('[data-usage-chart="EUR"] .usage-column:not(.missing)').first.click()
                    expect(page.locator('[data-usage-chart="EUR"] .usage-day-details')).to_contain_text("Credits")
                    page.locator('[data-usage-currency]').select_option("USD")
                    expect(page.locator('[data-usage-chart="USD"]')).to_be_visible()
                    expect(page.locator('[data-usage-chart="EUR"]')).not_to_be_visible()
                    checks.append("keyboard day inspection, missing-day coverage, charges/credits and separate currencies")
                    page.locator(".usage-resource details summary").first.click()
                    expect(page.locator(".usage-resource details[open]")).to_have_count(1)
                    checks.append("resource measurement disclosure works")
                    page.locator("#refresh").click()
                    expect(page.get_by_role("heading",name="Usage & costs",exact=True)).to_be_visible()
                    checks.append("manual refresh retains route")
                    client.post("/fixture/usage-mode?value=credits").raise_for_status()
                    page.locator("#refresh").click()
                    negative=page.locator('[data-usage-chart="EUR"] .diverging i.credit')
                    expect(negative).to_have_count(1)
                    assert negative.evaluate("e => e.getBoundingClientRect().top >= e.parentElement.getBoundingClientRect().top + e.parentElement.clientHeight/2 - 1")
                    checks.append("negative net credits plot below zero rather than as positive spend")
                    client.post("/fixture/usage-mode?value=pending").raise_for_status()
                    page.locator("#refresh").click()
                    expect(page.locator('.usage-billing-pending')).to_contain_text("Waiting for the first billing export")
                    expect(page.locator('.usage-stat').first).to_contain_text("Pending")
                    page.evaluate("scrollTo(0,0)")
                    page.screenshot(path=str(args.output/"usage-billing-pending.png"))
                    checks.append("connected empty export is pending, not a zero bill or a repeated setup request")
                    client.post("/fixture/usage-mode?value=missing").raise_for_status()
                    page.locator("#refresh").click()
                    expect(page.locator(".usage-stat").nth(3)).to_contain_text("Unavailable")
                    expect(page.locator('[data-usage-filter="unknown"]')).to_contain_text("Coverage gaps")
                    page.screenshot(path=str(args.output/"usage-unavailable.png"),full_page=True)
                    checks.append("missing billing and metrics show unavailable and unknown, not zero")
                    client.post("/fixture/usage-mode?value=stale").raise_for_status()
                    page.locator("#refresh").click()
                    page.locator('[data-usage-filter="all"]').click()
                    expect(page.locator(".usage-table")).to_contain_text("Stale")
                    expect(page.locator(".usage-resource.critical")).to_have_count(0)
                    checks.append("stale cloud readings lose current headroom assessments")
                    client.post("/fixture/usage-mode?value=observed").raise_for_status()
                    page.locator("#refresh").click()
                    expect(page.locator(".usage-resource.critical")).to_have_count(1)
                    page.evaluate("scrollTo(0,0)")
                    page.screenshot(path=str(args.output/"usage-overview-final.png"))
                    page.locator('[data-usage-filter="attention"]').click()
                    page.locator('#usage-capacity').scroll_into_view_if_needed()
                    page.screenshot(path=str(args.output/"usage-capacity.png"))
                    page.locator('[data-usage-jump]').click()
                    assert page.url.endswith("#usage")
                    checks.append("capacity jump preserves the authenticated route")
                    page.set_viewport_size({"width":390,"height":844})
                    page.evaluate("scrollTo(0,0)")
                    page.screenshot(path=str(args.output/"usage-narrow.png"))
                    assert page.evaluate("document.documentElement.scrollWidth <= innerWidth + 1")
                    checks.append("390px page fits; data tables scroll within cards")
                    page.locator("#menu").click()
                    page.locator('.console-nav[data-route="studio"]').click()
                    expect(page.get_by_role("heading",name="Administration",exact=True)).to_be_visible()
                    page.locator("#menu").click()
                    page.locator('.console-nav[data-route="usage"]').click()
                    expect(page.get_by_role("heading",name="Usage & costs",exact=True)).to_be_visible()
                    checks.append("navigation away and back")
                    page.locator("#logout").click()
                    expect(page.locator("#login")).to_be_visible()
                    assert "Cost per active player" not in page.locator("#main").inner_text()
                    checks.append("locking removes usage and player data")
                    browser.close()
            assert not errors, errors
        finally:
            process.terminate()
            process.wait(timeout=15)
            (args.output/"browser.json").write_text(json.dumps({"checks":checks,"page_errors":errors,
                "scope":"Synthetic local fixture; Edge desktop/narrow width, no physical device or cloud writes"},indent=2))
    print(json.dumps({"checks":len(checks),"page_errors":errors}))


if __name__ == "__main__":
    main()
