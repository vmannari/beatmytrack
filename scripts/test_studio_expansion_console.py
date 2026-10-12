"""Headless browser acceptance against a newly owned, seeded loopback database."""
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
    from test_backend_studio_console import serve as base_serve
    original = uvicorn.run

    def seeded(app, **kwargs):
        from dataclasses import replace

        from bmt_backend.challenge_models import Challenge, ChallengeMember
        from bmt_backend.quality_models import QualityFact
        from bmt_backend.track_models import Run, TrackVersion, digest, now
        app.state.settings = replace(app.state.settings,telemetry_enabled=True,client_quality_enabled=True)
        fixture = json.loads((folder / "fixture.json").read_text())
        with app.state.session_factory() as session:
            run = session.get(Run,fixture['run_id'])
            challenge = Challenge(code='LOCALUI1',creator_id=run.player_id,board_id=run.board_id,mode='beat',
                target_run_id=run.id,target_ticks=run.time_ticks,ends_at=now()+86400)
            session.add(challenge);session.flush()
            session.add(ChallengeMember(challenge_id=challenge.id,player_id=run.player_id,run_id=run.id,time_ticks=run.time_ticks))
            for kind,context,values in (
                ('quality_summary',{'build_id':'browser-fixture','platform':'android','device_class':'android_arm64','scene':'race'}, {'reports':1,'samples':100,'slow':10,'b2':90,'b5':10}),
                ('segment_summary',{'build_id':'browser-fixture','platform':'android','track_version_id':fixture['version_id'],'segment':3,'cell_x':2,'cell_y':4},{'reports':1,'samples':12,'slow':2}),
                ('segment_summary',{'build_id':'browser-fixture','platform':'android','track_version_id':fixture['version_id'],'segment':4,'cell_x':3,'cell_y':3},{'reports':1,'samples':5,'slow':1})):
                session.add(QualityFact(day=now()//86400,kind=kind,dimension=digest(context),context=context,**values))
            session.commit()
            fixture.update(challenge_id=challenge.id,track_id=session.get(TrackVersion,fixture['version_id']).track_id)
        (folder / "fixture.json").write_text(json.dumps(fixture))
        original(app,**kwargs)
    uvicorn.run = seeded
    base_serve(folder,port)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--serve',type=Path);parser.add_argument('--port',type=int)
    args = parser.parse_args()
    if args.serve: serve(args.serve,args.port);return
    import httpx
    from playwright.sync_api import expect, sync_playwright
    folder = ROOT / 'build' / ('studio-expansion-browser-'+uuid4().hex[:8]);folder.mkdir(parents=True)
    evidence = ROOT / 'docs/evidence/studio-expansion-2026-10-11';evidence.mkdir(parents=True,exist_ok=True)
    config = {name:secrets.token_urlsafe(32) for name in ('owner','analyst','development')}
    (folder/'config.private.json').write_text(json.dumps(config))
    with socket.socket() as reservation: reservation.bind(('127.0.0.1',0));port=reservation.getsockname()[1]
    base = f'http://127.0.0.1:{port}';checks=[]
    with (folder/'server.log').open('w',encoding='utf-8') as log:
        process = subprocess.Popen([sys.executable,str(Path(__file__)), '--serve',str(folder),'--port',str(port)],
            stdout=log,stderr=log,creationflags=subprocess.CREATE_NO_WINDOW)
        try:
            with httpx.Client(base_url=base,timeout=10) as http:
                for _ in range(100):
                    if process.poll() is not None:raise RuntimeError('Owned browser fixture failed; inspect private server.log')
                    try:
                        if http.get('/health').status_code==200:break
                    except httpx.ConnectError:pass
                    time.sleep(.2)
                else:raise RuntimeError('Owned fixture not ready')
            fixture=json.loads((folder/'fixture.json').read_text())
            with sync_playwright() as driver:
                browser=driver.chromium.launch(headless=True,executable_path='C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe')
                page=browser.new_page(viewport={'width':1440,'height':1000});errors=[]
                page.on('pageerror',lambda error:errors.append(str(error)))
                page.goto(base+'/admin#cases');page.fill('#key',config['owner']);page.locator('#login button').click()
                expect(page.locator('[data-case-action="create"]')).to_be_visible()
                page.locator('[data-case-action="create"]').click();page.locator('#dialog textarea').fill('UI <script> case')
                page.locator('#dialog input[name="track_id"]').fill(fixture['track_id'])
                page.locator('#dialog button').filter(has_text='Save').click()
                expect(page.locator('h1')).to_have_text('UI <script> case');checks.append('owner creates linked case and escaped title')
                page.locator('[data-case-action="note"]').click();page.locator('#dialog textarea').fill('Evidence note from browser')
                page.locator('#dialog button').filter(has_text='Save').click();expect(page.locator('#main')).to_contain_text('Evidence note from browser')
                checks.append('owner note commits with case revision');page.screenshot(path=str(evidence/'cases-desktop.png'),full_page=True)
                page.locator('[data-case-action="quarantine"]').click();page.locator('#dialog textarea').fill('Reported geometry review')
                page.locator('#dialog button').filter(has_text='Save').click();expect(page.locator('#main')).to_contain_text('"hidden": true')
                checks.append('case-linked quarantine is audited')
                page.evaluate("location.hash='quality'");expect(page.locator('h1')).to_have_text('Client quality & track diagnostics')
                expect(page.get_by_role('img',name='Frame-time bucket counts')).to_be_visible();checks.append('prepared frame histogram')
                page.screenshot(path=str(evidence/'quality-desktop.png'),full_page=True)
                page.evaluate("location.hash='quality?kind=segment_summary'");expect(page.get_by_role('img',name='Sampled track cell heatmap')).to_be_visible()
                page.screenshot(path=str(evidence/'heatmap-desktop.png'),full_page=True);checks.append('bounded sampled heatmap')
                page.evaluate("identity => location.hash='competitions/'+identity+'?kind=challenge'",fixture['challenge_id'])
                expect(page.locator('h1')).to_have_text('Challenge inspection');expect(page.locator('#main')).to_contain_text('Verified source')
                page.screenshot(path=str(evidence/'competition-desktop.png'),full_page=True);checks.append('exact target and best provenance')
                page.set_viewport_size({'width':390,'height':844});page.screenshot(path=str(evidence/'competition-mobile.png'),full_page=True)
                checks.append('390px responsive capture')
                page.locator('#logout').click();expect(page.locator('#login')).to_be_visible()
                page.fill('#key',config['analyst']);page.locator('#login button').click()
                page.evaluate("location.hash='cases'");expect(page.locator('h1')).to_have_text('Support cases')
                assert page.locator('[data-case-action]').count()==0;checks.append('analyst has read-only case UI')
                assert not errors,errors;checks.append('zero browser JavaScript errors')
                browser.close()
            (evidence/'browser.json').write_text(json.dumps({'checks':checks,'seeded_loopback_only':True,'remote_writes':0},indent=2))
            print(f'Studio expansion browser: {len(checks)} checks passed; seeded loopback only')
        finally:
            if process.poll() is None:process.terminate();process.wait(timeout=10)


if __name__=='__main__':main()
