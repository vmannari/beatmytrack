"""Owned loopback browser acceptance; never connects to or mutates staging."""

import argparse
import json
import secrets
import socket
import subprocess
import sys
import time
from pathlib import Path
from uuid import uuid4

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "backend"))
sys.path.insert(0, str(ROOT / "backend/tests"))


def serve(folder, port):
    import uvicorn
    from test_domains import FakeVerifier

    from bmt_backend.app import create_app
    from bmt_backend.commerce_models import Entitlements
    from bmt_backend.config import Settings
    from bmt_backend.identity_models import Identity, Player
    from bmt_backend.migrate import upgrade
    from bmt_backend.resume_models import (
        ResumeGrant,
        ResumeRace,
        ResumeReceipt,
        ResumeWallet,
    )
    from bmt_backend.track_models import Board, Run, RunTicket, Track, TrackVersion, now

    config = json.loads((folder / "config.private.json").read_text())
    settings = Settings(environment="development", dev_auth_enabled=True,
        purchase_simulation_enabled=True, dev_auth_key=config["development"],
        admin_owner_key=config["owner"], admin_analyst_key=config["analyst"],
        database_url="sqlite:///" + (folder / "database.sqlite").as_posix(),
        object_dir=str(folder / "objects"), rate_limit_per_minute=10000, write_limit_per_minute=10000)
    app = create_app(settings, verifier=FakeVerifier())
    upgrade(app.state.engine)
    with app.state.session_factory() as session:
        player = Player(display_name="Support console driver", country_code="FI", is_test_driver=True)
        other = Player(display_name="Another driver")
        session.add_all([player, other]); session.flush()
        session.add(Identity(player_id=player.id, provider="development", subject="private-fixture-subject"))
        session.add(Entitlements(player_id=player.id, slots=1, simulated_slots=0,
            ad_free_until=now()+7*86400, simulated_ad_free_until=0, forever=False, simulated_forever=False))
        track = Track(owner_id=player.id); session.add(track); session.flush()
        version = TrackVersion(track_id=track.id, number=1, name="Support circuit", content_hash="a"*64,
            manifest=FakeVerifier().manifest(), state="published", published_at=now())
        session.add(version); session.flush()
        board = Board(id="b"*64, version_id=version.id, vehicle_id="compact", manifest=FakeVerifier().manifest())
        session.add(board); session.flush()
        for index in range(54):
            issued = RunTicket(player_id=player.id, board_id=board.id, created_at=now()-index*86400,
                expires_at=now()+3600)
            session.add(issued); session.flush()
            session.add(Run(player_id=player.id, board_id=board.id, ticket_id=issued.id,
                replay_hash="c"*64, status="failed", failure_code="verifier_unavailable",
                created_at=issued.created_at, finished_at=issued.created_at+5, attempts=3))
        wallet = ResumeWallet(player_id=player.id, balance=1, free_day=-1)
        session.add(wallet)
        session.add(ResumeGrant(id="award:fixture-grant", player_id=player.id, source="award", quantity=2))
        resume = ResumeRace(player_id=player.id, ticket_id=issued.id, used=1, expires_at=now()+3600)
        session.add(resume); session.flush()
        session.add(ResumeReceipt(race_id=resume.id, ordinal=1, source="banked", input_offset=10,
            from_tick=1000, to_tick=900, settled=True, refunded=False))
        session.commit()
        (folder / "fixture.json").write_text(json.dumps({"player_id": player.id}))
    uvicorn.run(app, host="127.0.0.1", port=port, log_level="warning")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--serve", type=Path)
    parser.add_argument("--port", type=int)
    parser.add_argument("--output", type=Path, default=ROOT / "docs/evidence/admin-support-2026-10-08")
    args = parser.parse_args()
    if args.serve:
        serve(args.serve, args.port)
        return
    import httpx
    from playwright.sync_api import sync_playwright

    folder = ROOT / "build" / ("admin-support-browser-" + uuid4().hex[:8])
    folder.mkdir(parents=True)
    output = args.output
    output.mkdir(parents=True, exist_ok=True)
    config = {name: secrets.token_urlsafe(32) for name in ("owner", "analyst", "development")}
    (folder / "config.private.json").write_text(json.dumps(config))
    with socket.socket() as reservation:
        reservation.bind(("127.0.0.1", 0)); port = reservation.getsockname()[1]
    base = f"http://127.0.0.1:{port}"
    log = (folder / "server.log").open("w", encoding="utf-8")
    server = subprocess.Popen([sys.executable, str(Path(__file__).resolve()), "--serve", str(folder),
        "--port", str(port)], stdout=log, stderr=log, creationflags=subprocess.CREATE_NO_WINDOW)
    checks = []
    try:
        with httpx.Client(base_url=base, timeout=20) as http:
            for _attempt in range(80):
                if server.poll() is not None:
                    raise RuntimeError("Owned browser fixture failed; inspect its private server.log")
                try:
                    if http.get("/health").status_code == 200: break
                except httpx.ConnectError:
                    pass
                time.sleep(0.25)
            else: raise RuntimeError("Owned fixture did not become ready")
            player = json.loads((folder / "fixture.json").read_text())["player_id"]
            auth = {"Authorization": "Bearer " + config["owner"]}
            def current():
                response = http.get(f"/v1/admin/players/{player}/support", headers=auth)
                response.raise_for_status(); return response.json()
            commands = []
            with sync_playwright() as playwright:
                browser = playwright.chromium.launch(headless=True,
                    executable_path="C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe")
                page = browser.new_page(viewport={"width":1440,"height":1000}, accept_downloads=True)
                errors = []
                page.on("pageerror", lambda error: errors.append(str(error)))
                page.on("request", lambda request: commands.append(request.post_data_json)
                    if request.method=="POST" and request.url.endswith('/development/commands') else None)
                page.goto(base+"/admin#players/"+player)
                page.fill("#key", config["owner"]); page.locator("#login button").click()
                page.get_by_role("heading",name="Activity & evidence",exact=True).wait_for()
                assert not page.locator('#main').get_by_text('TEST',exact=True).count()
                assert current()["consumed_publication_slots"]==0
                checks.append("support read, ordinary artificial account and linked activity")

                def command(action, product=None, outcome=None, delta=None):
                    if action=='resolve_purchase': page.locator('[data-resolve-purchase]').first.click()
                    else: page.locator(f'[data-support-action="{action}"]').click()
                    if product: page.select_option('#dev-product', product)
                    if outcome: page.select_option('#dev-outcome', outcome)
                    if delta is not None: page.fill('#dev-slots',str(delta))
                    page.locator('#dev-preview').click(); page.wait_for_selector('#dev-confirm')
                    if action=='simulate_purchase' and outcome=='pending':
                        page.screenshot(path=str(output/'pending-preview.png'),full_page=True)
                    page.fill('#dev-reason','Owned browser acceptance test command')
                    page.locator('#dev-confirm input[type=checkbox]').check()
                    with page.expect_response(lambda response:response.url.endswith('/support')):
                        page.locator('#dev-submit').click()
                    page.get_by_role('heading',name='Activity & evidence',exact=True).wait_for()
                    page.wait_for_load_state('networkidle')

                command('simulate_purchase','creator_slot_1','pending')
                assert current()['access']['simulated_slots']==0
                checks.append('pending grants no access')
                command('resolve_purchase',outcome='approved')
                first = http.post(f'/v1/admin/players/{player}/development/commands',headers=auth,json=commands[-1])
                second = http.post(f'/v1/admin/players/{player}/development/commands',headers=auth,json=commands[-1])
                assert first.status_code==second.status_code==200 and first.json()==second.json()
                assert current()['access']['simulated_slots']==1
                checks.append('pending approval and repeated delivery grant once')
                command('adjust_slots',delta=-1)
                assert current()['access']['simulated_slots']==0 and current()['access']['slots']==1
                command('simulate_purchase','ad_free_month','approved')
                assert current()['access']['simulated_ad_free_until']>time.time()
                command('expire_month')
                assert current()['access']['simulated_ad_free_until']<=time.time()
                command('simulate_purchase','ad_free_forever','approved')
                command('reset_ad_free')
                assert not current()['access']['simulated_forever'] and current()['effective']['ad_free']
                checks.append('remaining slots, monthly expiry and permanent reset preserve real access')
                with page.expect_download() as download:
                    page.locator('#support-export').click()
                export_file=output/'player-history.json'
                download.value.save_as(str(export_file))
                exported=export_file.read_text()
                assert 'private-fixture-subject' not in exported and config['owner'] not in exported
                checks.append('bounded redacted export')
                page.evaluate('scrollTo(0,0)')
                page.screenshot(path=str(output/'player-1440.png'),full_page=True,animations='disabled')
                def history_change(action):
                    with page.expect_response(lambda response:'/history?' in response.url):
                        action()
                    page.get_by_role('heading',name='Activity & evidence',exact=True).wait_for()
                    page.wait_for_load_state('networkidle')
                page.select_option('#support-filters select[name=kind]','race')
                history_change(lambda:page.locator('#support-clear').click())
                page.select_option('#support-filters select[name=kind]','race')
                history_change(lambda:page.locator('#support-filters button[type=submit], #support-filters button:not([type])').first.click())
                first_ids=page.locator('tbody a[href^="#races/"]').all_text_contents()
                history_change(lambda:page.locator('#support-next').click())
                next_ids=page.locator('tbody a[href^="#races/"]').all_text_contents()
                assert len(first_ids)==len(next_ids)==25 and not set(first_ids)&set(next_ids), (len(first_ids),len(next_ids),len(set(first_ids)&set(next_ids)))
                history_change(lambda:page.locator('#support-previous').click())
                assert page.locator('tbody a[href^="#races/"]').all_text_contents()==first_ids
                checks.append('keyset pagination and return to previous page')
                page.evaluate("location.hash='analytics'")
                page.get_by_role('heading',name='Driving analytics',exact=True).wait_for()
                with page.expect_response(lambda response:'/overview?days=90' in response.url):
                    page.select_option('#days','90')
                page.get_by_role('heading',name='Driving analytics',exact=True).wait_for()
                page.wait_for_load_state('networkidle')
                assert page.locator('.console-bar').count()==90
                page.screenshot(path=str(output/'analytics-90-days.png'),full_page=True)
                page.locator('.console-bar').last.click();page.wait_for_load_state('networkidle')
                assert 'since=' in page.url and 'until=' in page.url
                assert page.locator('tbody tr').count()==1
                checks.append('all 90 days and exact chart-day drilldown')
                def missing_capacity(route):
                    response=route.fetch();value=response.json();value['storage_free_bytes']=None;value['storage_backend']='gcs'
                    route.fulfill(response=response,json=value)
                page.route('**/v1/admin/competition-health',missing_capacity)
                page.evaluate("location.hash='system'")
                page.get_by_role('heading',name='Verified competition',exact=True).wait_for()
                assert page.locator('.console-kv').filter(has_text='storage free gib').inner_text().endswith('Unavailable')
                page.screenshot(path=str(output/'system-null-capacity.png'),full_page=True)
                checks.append('null capacity remains unavailable, expanded worker health')
                page.evaluate("route=>location.hash=route",'players/'+player+'?all=1')
                page.get_by_role('heading',name='Activity & evidence',exact=True).wait_for()
                for width,height in [(960,720),(390,844)]:
                    page.set_viewport_size({'width':width,'height':height})
                    page.evaluate('scrollTo(0,0)')
                    assert page.evaluate('document.documentElement.scrollWidth<=innerWidth')
                    page.screenshot(path=str(output/f'player-{width}.png'),full_page=True,animations='disabled')
                checks.append('compact and narrow viewport containment')
                page.locator('#logout').click();page.fill('#key',config['analyst']);page.locator('#login button').click()
                page.get_by_role('heading',name='Activity & evidence',exact=True).wait_for()
                assert not page.locator('[data-support-action], [data-resolve-purchase]').count()
                checks.append('read-only role offers no mutation controls')
                assert not errors, errors
                browser.close()
        (output/'browser-checks.json').write_text(json.dumps({'checks':checks,'javascript_errors':errors,
            'fixture':'Owned loopback SQLite service; FakeVerifier; missing-capacity response injection'},indent=2)+'\n')
        print(f'ADMIN_SUPPORT_BROWSER: {len(checks)} checks, zero failures')
    finally:
        server.terminate(); server.wait(timeout=15); log.close()
        print('Owned loopback browser server stopped; private fixture retained under build/.')


if __name__=='__main__':
    main()
