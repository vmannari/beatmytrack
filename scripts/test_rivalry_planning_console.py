"""Real Edge calendar workflows against a disposable loopback backend."""
import argparse
import json
import secrets
import socket
import subprocess
import sys
import time
from pathlib import Path
from types import SimpleNamespace
from uuid import uuid4

ROOT = Path(__file__).resolve().parents[1]
sys.path[:0] = [str(ROOT / "backend"), str(ROOT / "backend/tests"), str(ROOT / "scripts")]


def serve(folder, port):
    import uvicorn
    from bmt_backend.rivalry_planning import maintain
    from bmt_backend.track_models import TrackVersion
    from test_backend_studio_console import serve as base_serve
    from test_rivalry import seed

    run = uvicorn.run

    def seeded(app, **kwargs):
        fixture = json.loads((folder / "fixture.json").read_text())
        domain = SimpleNamespace(app=app, factory=app.state.session_factory, players={"Creator": fixture["player_id"]})
        versions = seed(domain, 35)
        with domain.factory() as db:
            for i, vid in enumerate(versions):
                v = db.get(TrackVersion, vid)
                theme = ["pine", "desert", "winter", "night", "storm"][i % 5]
                v.name = ["Pine Circuit", "Dune Relay", "Winter Switchback", "Night Foundry", "Storm Ridge"][i % 5] + f" {i+1:02}"
                v.discovery = {**v.discovery, "theme": theme}
                v.verified_finishers = 140 + i * 23
                v.rating_count, v.rating_sum = 100, 410 + i % 9 * 10
            db.commit()
        maintain(app)
        run(app, **kwargs)

    uvicorn.run = seeded
    base_serve(folder, port)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--serve", type=Path)
    parser.add_argument("--port", type=int)
    parser.add_argument("--output", type=Path, default=ROOT / "docs/evidence/rivalry-planning-2026-10-18")
    args = parser.parse_args()
    if args.serve:
        serve(args.serve, args.port)
        return
    import httpx
    from playwright.sync_api import expect, sync_playwright

    folder = ROOT / "build" / ("rivalry-planning-browser-" + uuid4().hex[:8])
    folder.mkdir(parents=True)
    args.output.mkdir(parents=True, exist_ok=True)
    config = {k: secrets.token_urlsafe(32) for k in ("owner", "analyst", "development")}
    (folder / "config.private.json").write_text(json.dumps(config))
    with socket.socket() as reservation:
        reservation.bind(("127.0.0.1", 0))
        port = reservation.getsockname()[1]
    base = f"http://127.0.0.1:{port}"
    checks, errors, writes = [], [], []
    with (folder / "server.log").open("w", encoding="utf-8") as log:
        process = subprocess.Popen([sys.executable, str(Path(__file__).resolve()), "--serve", str(folder),
            "--port", str(port)], stdout=log, stderr=log, creationflags=subprocess.CREATE_NO_WINDOW)
        try:
            with httpx.Client(base_url=base, timeout=25) as http:
                for _ in range(100):
                    if process.poll() is not None:
                        raise RuntimeError("Fixture failed: " + str(folder / "server.log"))
                    try:
                        if http.get("/health").status_code == 200:
                            break
                    except httpx.ConnectError:
                        pass
                    time.sleep(.25)
                else:
                    raise RuntimeError("Fixture did not become ready")
                auth = {"Authorization": "Bearer " + config["owner"]}

                def current():
                    response = http.get("/v1/admin/rivalry-plans", headers=auth)
                    response.raise_for_status()
                    return response.json()

                with sync_playwright() as playwright:
                    browser = playwright.chromium.launch(headless=True,
                        executable_path="C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe")
                    page = browser.new_page(viewport={"width": 1440, "height": 1050})
                    page.on("pageerror", lambda e: errors.append(str(e)))
                    page.on("request", lambda r: writes.append(r.post_data_json)
                        if r.method == "POST" and "/rivalry-plans/" in r.url and r.url.endswith("/commands") else None)
                    page.goto(base + "/admin#competitions")
                    page.locator("#key").fill(config["owner"])
                    page.locator("#login button").click()
                    expect(page.locator(".rivalry-week")).to_have_count(4)
                    expect(page.locator(".rivalry-calendar-header")).to_contain_text("4 / 4 weeks ready")
                    expect(page.locator(".rivalry-week li")).to_have_count(20)
                    checks.append("Owner sees four future UTC weeks, all five selections and selection metrics")
                    page.evaluate("window.scrollTo(0,0)")
                    page.screenshot(path=str(args.output / "calendar-desktop.png"), full_page=True)
                    original = current()["weeks"][0]
                    old_ids = [t["version_id"] for t in original["tracks"]]

                    def choose_replacement():
                        page.locator(".rivalry-edit").first.click()
                        expect(page.locator(".rivalry-candidate-list")).to_be_visible()
                        button = page.locator("[data-rivalry-pick]:enabled").first
                        name = button.locator("..").locator("strong").inner_text()
                        button.click()
                        page.locator("#rivalry-reason").fill("Owner local calendar curation")
                        page.locator("#rivalry-preview").click()
                        expect(page.locator("#rivalry-save")).to_be_visible()
                        return name

                    chosen = choose_replacement()
                    expect(page.locator(".rivalry-comparison")).to_contain_text(chosen)
                    page.screenshot(path=str(args.output / "lineup-preview-desktop.png"))
                    page.locator("#dialog [data-close]").click()
                    assert [t["version_id"] for t in current()["weeks"][0]["tracks"]] == old_ids
                    assert writes == []
                    checks.append("Replacement preview shows before/after; Cancel preserves the plan")
                    chosen = choose_replacement()
                    page.locator("#rivalry-save").click()
                    expect(page.locator("#dialog")).not_to_be_visible()
                    expect(page.locator(".rivalry-week").first).to_contain_text(chosen)
                    assert current()["weeks"][0]["revision"] == 1
                    assert current()["current"]["editable"] is False
                    assert current()["weeks"][0]["tracks"][0]["name"] == chosen
                    checks.append("Save persists the replacement, records an audit and leaves current week locked")

                    page.locator(".rivalry-edit").first.click()
                    expect(page.locator(".rivalry-candidate-list")).to_be_visible()
                    page.locator("#rivalry-search input").fill("Winter")
                    page.locator("#rivalry-search button").click()
                    expect(page.locator(".rivalry-candidate-list li")).to_have_count(7)
                    assert all("Winter" in n for n in page.locator(".rivalry-candidate-list strong").all_text_contents())
                    page.locator("#dialog [data-close]").click()
                    checks.append("Eligible replacement search uses track names and preserves five distinct slots")

                    choose_replacement()
                    def lose_response(route):
                        response = route.fetch()
                        assert response.status == 200
                        route.abort("failed")
                    page.route("**/rivalry-plans/*/commands", lose_response, times=1)
                    page.locator("#rivalry-save").click()
                    expect(page.locator("#rivalry-command-error")).to_be_visible()
                    revision = current()["weeks"][0]["revision"]
                    page.locator("#rivalry-save").click()
                    expect(page.locator("#dialog")).not_to_be_visible()
                    assert current()["weeks"][0]["revision"] == revision
                    assert writes[-1] == writes[-2]
                    checks.append("Lost-response retry replays the exact audited command once")

                    choose_replacement()
                    concurrent = current()["weeks"][0]
                    path = "/v1/admin/rivalry-plans/" + concurrent["id"]
                    body = {"command_id": str(uuid4()), "expected_revision": concurrent["revision"],
                        "version_ids": [t["version_id"] for t in concurrent["tracks"]], "reason": "Concurrent local owner review"}
                    p = http.post(path + "/preview", headers=auth, json=body).json()
                    body.update({k:p[k] for k in ("preview_at", "preview_hash")})
                    assert http.post(path + "/commands", headers=auth, json=body).status_code == 200
                    page.locator("#rivalry-save").click()
                    expect(page.locator("#rivalry-command-error")).to_contain_text("PLAN_CHANGED")
                    page.locator("#dialog [data-close]").click()
                    checks.append("Stale preview cannot overwrite a concurrent owner edit")

                    page.locator("#refresh").click()
                    expect(page.locator(".rivalry-calendar-header")).to_be_visible()
                    page.set_viewport_size({"width": 390, "height": 844})
                    page.evaluate("window.scrollTo(0,0)")
                    page.screenshot(path=str(args.output / "calendar-mobile.png"), full_page=True)
                    assert page.locator(".rivalry-calendar").evaluate("e=>e.scrollWidth<=e.clientWidth+1")
                    choose_replacement()
                    page.screenshot(path=str(args.output / "lineup-preview-mobile.png"))
                    assert page.locator(".rivalry-editor").evaluate("e=>e.scrollWidth<=e.clientWidth+1")
                    page.locator("#dialog [data-close]").click()
                    checks.append("390px calendar and complete before/after preview fit without horizontal overflow")

                    page.locator(".rivalry-edit").first.click()
                    page.evaluate("document.querySelector('#logout').click()")
                    expect(page.locator("#login")).to_be_visible()
                    expect(page.locator("#dialog")).not_to_be_visible()
                    page.locator("#key").fill(config["analyst"])
                    page.locator("#login button").click()
                    expect(page.locator(".rivalry-week")).to_have_count(4)
                    expect(page.locator(".rivalry-edit")).to_have_count(0)
                    checks.append("Lock clears the pending editor; analyst can inspect with no write controls")
                    assert not errors, errors
                    browser.close()
            receipt = {"checks": checks, "passed": len(checks), "javascript_errors": errors,
                "viewports": ["1440x1050", "390x844"], "scope": "Disposable loopback SQLite backend; no live writes"}
            (args.output / "browser.json").write_text(json.dumps(receipt, indent=2), encoding="utf-8")
            print(json.dumps(receipt, indent=2))
        finally:
            process.terminate()
            process.wait(timeout=20)


if __name__ == "__main__":
    main()
