"""Real Edge checks on an owned populated loopback Studio fixture."""
import argparse
import json
import secrets
import socket
import subprocess
import sys
import time
from pathlib import Path
from uuid import uuid4

ROOT = Path(__file__).resolve().parents[3]
OUTPUT = Path(__file__).resolve().parent
sys.path[:0] = [str(ROOT / "backend"), str(ROOT / "backend/tests"), str(ROOT / "scripts")]


def serve(folder, port):
    import uvicorn
    from sqlalchemy import select
    from bmt_backend.identity_models import Player
    from bmt_backend.track_models import Track, TrackVersion, now
    from test_studio_platform_console import serve as platform_serve
    original = uvicorn.run

    def seeded(app, **kwargs):
        with app.state.session_factory() as db:
            owner = db.scalar(select(Player.id).limit(1))
            db.add_all([Player(display_name=f"Pagination person {i:03}", created_at=now() - 50,
                               is_test_driver=i % 2 == 0) for i in range(60)])
            for i in range(35):
                track = Track(owner_id=owner)
                db.add(track)
                db.flush()
                db.add(TrackVersion(track_id=track.id, number=1, name=f"Pagination course {i:03}",
                    content_hash="0" * 64, manifest={}, state="published", created_at=now() - 50,
                    published_at=now() - 50, discovery={"theme": "pine", "points": [[0, 0], [40, 0], [40, 40], [0, 0]]}))
            db.commit()
        original(app, **kwargs)

    uvicorn.run = seeded
    platform_serve(folder, port)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--serve", type=Path)
    parser.add_argument("--port", type=int)
    args = parser.parse_args()
    if args.serve:
        return serve(args.serve, args.port)
    import httpx
    from playwright.sync_api import expect, sync_playwright
    folder = ROOT / "build" / ("studio-performance-browser-" + uuid4().hex[:8])
    folder.mkdir(parents=True)
    config = {name: secrets.token_urlsafe(32) for name in ("owner", "analyst", "development", "monitor")}
    (folder / "config.private.json").write_text(json.dumps(config))
    with socket.socket() as reservation:
        reservation.bind(("127.0.0.1", 0))
        port = reservation.getsockname()[1]
    base = f"http://127.0.0.1:{port}"
    checks, errors, failures, requests = [], [], [], []
    with (folder / "server.log").open("w", encoding="utf-8") as log:
        process = subprocess.Popen([sys.executable, str(Path(__file__).resolve()), "--serve", str(folder), "--port", str(port)],
            cwd=ROOT, stdout=log, stderr=log, creationflags=getattr(subprocess, "CREATE_NO_WINDOW", 0))
        try:
            for _ in range(80):
                if process.poll() is not None:
                    raise RuntimeError("Owned browser fixture exited; inspect its private build log")
                try:
                    if httpx.get(base + "/healthz", timeout=1).status_code == 200:
                        break
                except httpx.HTTPError:
                    pass
                time.sleep(.25)
            with sync_playwright() as playwright:
                browser = playwright.chromium.launch(headless=True,
                    executable_path="C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe")
                page = browser.new_page(viewport={"width": 1440, "height": 1000})
                page.on("pageerror", lambda error: errors.append(str(error)))
                page.on("request", lambda request: requests.append(request.url.split("/v1/admin/")[-1]) if "/v1/admin/" in request.url else None)
                page.on("response", lambda response: failures.append(response.status) if "/v1/admin/" in response.url and response.status >= 500 else None)
                page.goto(base + "/admin")
                page.locator("#key").fill(config["owner"])
                page.locator("#login button").click()
                expect(page.locator("#main")).to_contain_text("Know what needs attention.", timeout=20000)

                def ready():
                    page.wait_for_function("""()=>{
                        const normalized=route=>{const [path,qs]=route.split('?'),q=new URLSearchParams(qs);
                            for(const key of ['anchor','offset','since','until'])q.delete(key);
                            q.sort();return (path||'overview')+'?'+q;};
                        return normalized(lastRenderedRoute)===normalized(location.hash.slice(1))
                            && !document.querySelector('#main').hasAttribute('aria-busy');
                    }""", timeout=20000)
                    expect(page.locator("#main")).not_to_contain_text("Unable to load records")

                def visit(route):
                    page.evaluate("route=>location.hash=route", route)
                    ready()

                for width in (1440, 390):
                    page.set_viewport_size({"width": width, "height": 1000})
                    visit("players?q=Pagination+person&sort=name&direction=asc")
                    first = page.evaluate("cataloguePage.data.items.map(p=>p.id)")
                    assert len(first) == 25
                    expect(page.locator("#main")).not_to_contain_text("Matching accounts")
                    page.get_by_role("link", name="Next", exact=True).click()
                    ready()
                    second = page.evaluate("cataloguePage.data.items.map(p=>p.id)")
                    assert len(second) == 25 and not set(first) & set(second)
                    page.get_by_role("link", name="Previous", exact=True).click()
                    ready()
                    assert page.evaluate("cataloguePage.data.items.map(p=>p.id)") == first
                    checks.append(f"{width}: player Next/Previous preserves sorted pages without totals")
                    page.get_by_role("link", name="Next", exact=True).click()
                    ready()
                    page.get_by_role("link", name="Open support evidence", exact=True).first.click()
                    ready()
                    expect(page.locator("#main")).to_contain_text("Timeline & evidence")
                    for label in ("Entitlements & resumes", "Purchases & grants", "Identity & coverage"):
                        requests.clear()
                        page.get_by_role("link", name=label, exact=True).first.click()
                        ready()
                        assert not any("/history?" in request for request in requests)
                    checks.append(f"{width}: support access, grants and identity tabs skip unused history reads")
                    page.get_by_role("link", name="Find another player").click()
                    ready()
                    assert page.evaluate("cataloguePage.data.items.map(p=>p.id)") == second
                    checks.append(f"{width}: selected-player support and return preserve the cursor page")
                    page.locator('#catalogue-filters input[name=q]').fill("Pagination person 04")
                    page.locator('#catalogue-filters button[type=submit],#catalogue-filters button').first.click()
                    ready()
                    assert "cursor=" not in page.url and page.evaluate("cataloguePage.data.items.length") == 10
                    checks.append(f"{width}: changing filters clears the old cursor")
                    page.screenshot(path=str(OUTPUT / f"players-{width}.png"), full_page=True)
                    visit("tracks?q=Pagination+course&sort=name&direction=asc")
                    first = page.evaluate("cataloguePage.data.items.map(p=>p.id)")
                    page.get_by_role("link", name="Next", exact=True).click()
                    ready()
                    assert page.evaluate("cataloguePage.data.items.length") == 10
                    page.get_by_role("link", name="Previous", exact=True).click()
                    ready()
                    assert page.evaluate("cataloguePage.data.items.map(p=>p.id)") == first
                    checks.append(f"{width}: track Next/Previous and prepared route shapes remain usable")
                    page.screenshot(path=str(OUTPUT / f"tracks-{width}.png"), full_page=True)
                    visit("economy")
                    expect(page.locator("#main")).to_contain_text("Coin sources and sinks")
                    expect(page.locator("#main")).not_to_contain_text("Current wallets")
                    page.screenshot(path=str(OUTPUT / f"finance-{width}.png"), full_page=True)
                    checks.append(f"{width}: finance retains period flows without wallet totals")
                    assert not page.evaluate("document.documentElement.scrollWidth>innerWidth+1")
                    visit("product")
                    for tab in ("activity", "retention", "journey", "engagement"):
                        requests.clear()
                        visit("product?tab=" + tab)
                        assert len([r for r in requests if r.startswith("analysis/behaviour?") and "view=" + tab in r]) == 1
                        assert not any(r.startswith("product-analytics?") for r in requests)
                    expect(page.locator("#main")).not_to_contain_text("Historical totals")
                    checks.append(f"{width}: each behaviour tab requests only its own report; duplicate history tab retired")
                assert not errors and not failures, (errors, failures)
                browser.close()
        finally:
            process.terminate()
            try:
                process.wait(timeout=5)
            except subprocess.TimeoutExpired:
                process.kill()
                process.wait(timeout=5)
    result = {"checks": checks, "javascript_errors": errors, "failed_reads": failures,
              "scope": "Real desktop Edge at 1440px and 390px against an owned synthetic fixture; not a device test"}
    (OUTPUT / "browser-focused.json").write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"checks": len(checks), "javascript_errors": errors, "failed_reads": failures}))


if __name__ == "__main__":
    main()
