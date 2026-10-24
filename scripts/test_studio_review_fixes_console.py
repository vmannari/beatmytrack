"""Studio items 1–4 acceptance against a newly owned loopback fixture only."""

import argparse
import csv
import io
import json
import secrets
import socket
import sqlite3
import subprocess
import sys
import time
from dataclasses import replace
from pathlib import Path
from uuid import uuid4

ROOT = Path(__file__).resolve().parents[1]
sys.path[:0] = [str(ROOT/'backend'), str(ROOT/'backend/tests'), str(ROOT/'scripts')]
OUTPUT = ROOT/'docs/evidence/studio-items-1-4-2026-10-24/browser'


def serve(folder, port):
    import uvicorn
    from bmt_backend.db import make_engine
    from bmt_backend.studio_ranking import record_worker_heartbeat
    from bmt_backend.studio_reporting import StudioReporting
    from bmt_backend.track_models import now
    from studio_catalogue_browser_checks import seed_catalogue
    from test_studio_platform_console import serve as platform_serve
    from test_studio_review_fixes import seed_ranking

    run = uvicorn.run

    def seeded(app, **kwargs):
        fixture = json.loads((folder/'fixture.json').read_text())
        with app.state.session_factory() as db:
            fixture.update(seed_catalogue(db, fixture['player_id'], now()))
            db.commit()
        circuit, snapshot = seed_ranking(app, fixture['player_id'])
        fixture.update(circuit_id=circuit, snapshot_id=snapshot)
        record_worker_heartbeat(app.state.session_factory)
        (folder/'fixture.json').write_text(json.dumps(fixture))
        with sqlite3.connect(folder/'database.sqlite') as source, sqlite3.connect(folder/'reporting.sqlite') as target:
            source.backup(target)
        app.state.settings = replace(app.state.settings, environment='test', studio_legacy_keys_enabled=True,
                                     dev_auth_enabled=False, purchase_simulation_enabled=False)
        app.state.studio_reporting.close()
        app.state.studio_reporting = StudioReporting(app.state.settings,
            engine=make_engine('sqlite:///'+(folder/'reporting.sqlite').as_posix()))
        run(app, **kwargs)

    uvicorn.run = seeded
    platform_serve(folder, port)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--serve', type=Path)
    parser.add_argument('--port', type=int)
    parser.add_argument('--output', type=Path, default=OUTPUT)
    args = parser.parse_args()
    if args.serve:
        return serve(args.serve, args.port)
    import httpx
    from playwright.sync_api import expect, sync_playwright

    folder = ROOT/'build'/('studio-items-owned-'+uuid4().hex[:8])
    folder.mkdir(parents=True)
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    config = {key: secrets.token_urlsafe(32) for key in ('owner','analyst','development','monitor')}
    (folder/'config.private.json').write_text(json.dumps(config))
    with socket.socket() as sock:
        sock.bind(('127.0.0.1',0))
        port = sock.getsockname()[1]
    base = f'http://127.0.0.1:{port}'
    result = {'scope':'Synthetic owned loopback fixtures; no production or physical-device activity.',
              'checks':[], 'pages':[], 'javascript_errors':[], 'downloads':[]}
    with (folder/'server.log').open('w',encoding='utf-8') as log:
        process = subprocess.Popen([sys.executable,str(Path(__file__).resolve()),'--serve',str(folder),'--port',str(port)],
                                   stdout=log,stderr=log,creationflags=subprocess.CREATE_NO_WINDOW)
        try:
            with httpx.Client(base_url=base,timeout=20) as http:
                for _ in range(100):
                    if process.poll() is not None:
                        raise RuntimeError('Owned fixture startup failed; inspect '+str(folder/'server.log'))
                    try:
                        if http.get('/health').status_code == 200:
                            break
                    except httpx.ConnectError:
                        pass
                    time.sleep(.2)
                fixture = json.loads((folder/'fixture.json').read_text())
                with sync_playwright() as driver:
                    browser = driver.chromium.launch(headless=True,executable_path='C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe')
                    page = browser.new_page(viewport={'width':1440,'height':1000},accept_downloads=True)
                    page.on('pageerror',lambda error:result['javascript_errors'].append(str(error)))
                    page.goto(base+'/admin')
                    page.locator('#key').fill(config['owner'])
                    page.locator('#login button').click()
                    page.wait_for_function("()=>lastRenderedRoute==='overview' && document.querySelector('#main').getAttribute('aria-busy')!=='true'")

                    def settled():
                        page.wait_for_function("()=>document.querySelector('#main').getAttribute('aria-busy')!=='true' && (lastRenderedRoute===(location.hash.slice(1)||'overview') || document.querySelector('#main').innerText.includes('Unable to load records'))",timeout=20000)
                        assert 'Unable to load records' not in page.locator('#main').inner_text(), page.locator('#main').inner_text()

                    def visit(route, width=1440, height=1000, shot=None):
                        page.set_viewport_size({'width':width,'height':height})
                        if page.url.split('#')[-1] == route:
                            page.locator('#refresh').evaluate('(x)=>x.click()')
                        else:
                            page.evaluate('route=>location.hash=route',route)
                        page.wait_for_timeout(60)
                        settled()
                        expect(page.locator('#main')).not_to_contain_text('Unable to load records')
                        overflow=page.evaluate('document.documentElement.scrollWidth>innerWidth+1')
                        assert not overflow,(route,width,'global overflow')
                        result['pages'].append({'route':route,'width':width,'height':height,'global_overflow':overflow})
                        if shot:
                            page.screenshot(path=str(output/shot),full_page=True)

                    def check(label):
                        result['checks'].append(label)

                    scope='build_id=release-a&platform=android&mode=free_race&population=real'
                    visit('product?'+scope)
                    page.get_by_role('link',name='Are players returning?',exact=True).click()
                    settled()
                    assert all(pair in page.url for pair in scope.split('&'))
                    page.get_by_role('link',name='Activity',exact=True).click()
                    settled()
                    page.get_by_role('link',name='Does release quality explain a drop?',exact=True).click()
                    settled()
                    assert all(pair in page.url for pair in scope.split('&'))
                    expect(page.locator('#main')).to_contain_text('This report does not apply mode, population')
                    check('Guided report links preserve supported filters and explicitly disclose unsupported scope')

                    visit('overview')
                    href=page.locator('.platform-stat').filter(has_text='Verified results').get_attribute('href')
                    assert 'time_field=finished_at' in href
                    from urllib.parse import parse_qs
                    times=parse_qs(href.split('?',1)[1])
                    assert int(times['until'][0])-int(times['since'][0]) == 301
                    page.locator('.platform-stat').filter(has_text='Verified results').click()
                    settled()
                    expect(page.locator('#main')).to_contain_text('verification terminal time')
                    check('Five-minute KPI drilldown uses its exact interval and terminal-time semantics')

                    page.route('**/v1/admin/metrics',lambda r:r.fulfill(status=503,content_type='application/json',body='{"detail":"owned source fault"}'))
                    visit('overview',shot='overview-partial-metrics.png')
                    expect(page.locator('#main')).to_contain_text('Metric coverage is unavailable')
                    expect(page.locator('#main')).to_contain_text('Results are waiting for a worker')
                    expect(page.locator('#main')).to_contain_text('Verification jobs')
                    page.unroute('**/v1/admin/metrics')
                    page.route('**/v1/admin/incidents?*',lambda r:r.fulfill(status=503,content_type='application/json',body='{"detail":"owned incident fault"}'))
                    visit('overview',shot='overview-partial-incidents.png')
                    expect(page.locator('#main')).to_contain_text('Incident evidence is unavailable')
                    expect(page.locator('#main')).to_contain_text('Can these numbers be trusted?')
                    page.unroute('**/v1/admin/incidents?*')
                    check('Metrics-only and incidents-only outages retain other successful overview cards')

                    def stale(route):
                        data=route.fetch().json()
                        data['coverage']['latest_client_at']=int(time.time())-3*86400
                        data['coverage']['processed_through']=int(time.time())-2*86400
                        route.fulfill(json=data)
                    page.route('**/v1/admin/analysis/behaviour?*',stale)
                    visit('product',shot='activity-stale-source.png')
                    expect(page.get_by_text('Source observations are older than 15 minutes',exact=True)).to_be_visible()
                    assert not page.locator('details.platform-method').evaluate('(x)=>x.open')
                    page.unroute('**/v1/admin/analysis/behaviour?*')
                    visit('product')
                    expect(page.locator('#main')).to_contain_text('In progress')
                    check('Source age is visible with collapsed details; current-day coverage is marked incomplete')

                    for view in ('activity','retention','journey','engagement'):
                        visit('product?tab='+view+'&build_id=release-a')
                        with page.expect_download() as download:
                            page.locator('#platform-export').click()
                        destination=output/('export-'+view+'.csv')
                        download.value.save_as(destination)
                        rows=list(csv.DictReader(io.StringIO(destination.read_text(encoding='utf-8'))))
                        assert rows[0]['report']==view and json.loads(rows[0]['scope'])['build_id']=='release-a'
                        assert rows[0]['processed_through'] and rows[0]['query_semantics']=='new_query_at_download'
                        result['downloads'].append({'view':view,'rows':len(rows),'file':destination.name})
                    check('Every behaviour tab downloads its own report with scope, source time and query provenance')

                    def save_location(route,name):
                        visit(route)
                        page.locator('#platform-save').click()
                        page.locator('#dialog [name=name]').fill(name)
                        page.locator('#platform-command [type=submit]').click()
                        expect(page.locator('#dialog')).not_to_be_visible()
                        settled()
                        visit('studio?tab=saved')
                        row=page.locator('tbody tr').filter(has_text=name)
                        row.get_by_role('link',name='Open view',exact=True).click()
                        settled()
                        assert page.url.split('#',1)[1].split('?')[0]==route.split('?')[0]
                        for key,value in parse_qs(route.split('?',1)[1] if '?' in route else '').items():
                            assert parse_qs(page.url.split('?',1)[1])[key]==value

                    save_location('players/'+fixture['player_id']+'?all=1','Owned exact player')
                    save_location('races/'+fixture['run_id'],'Owned exact race')
                    save_location('system/jobs?kind=ranking&state=pending','Owned ranking queue')
                    save_location('cases?status=open','Owned open cases')
                    visit('studio?tab=saved')
                    row=page.locator('tbody tr').filter(has_text='Owned exact player')
                    row.get_by_role('button',name='Rename',exact=True).click()
                    page.locator('#dialog [name=name]').fill('Owned renamed player')
                    page.locator('#platform-command [type=submit]').click()
                    expect(page.locator('#dialog')).not_to_be_visible()
                    settled()
                    row=page.locator('tbody tr').filter(has_text='Owned renamed player')
                    row.get_by_role('button',name='Delete',exact=True).click()
                    page.locator('#platform-command [type=submit]').click()
                    expect(page.locator('#dialog')).not_to_be_visible()
                    settled()
                    expect(page.locator('#main')).not_to_contain_text('Owned renamed player')
                    check('Player/race/queue/case saved locations round-trip; rename and deletion are usable')

                    quality='quality?build_id=release-a&baseline=release-b&device_model=Fixture+phone&os_version=14'
                    visit(quality,shot='quality-comparison-desktop.png')
                    expect(page.locator('#main')).to_contain_text('Small exploratory sample')
                    expect(page.locator('#main')).to_contain_text('Frames over 34 ms')
                    expect(page.locator('#main')).to_contain_text('Player coverage is unavailable')
                    with page.expect_download() as download:
                        page.locator('#platform-export').click()
                    destination=output/'export-releases.csv'
                    download.value.save_as(destination)
                    rows=list(csv.DictReader(io.StringIO(destination.read_text(encoding='utf-8'))))
                    assert [r['comparison_role'] for r in rows]==['candidate','baseline']
                    page.locator('tbody tr').first.get_by_role('link',name='Frame times',exact=True).click()
                    settled()
                    assert 'build_id=release-a' in page.url and 'device_model=Fixture+phone' in page.url and 'os_version=14' in page.url
                    page.get_by_role('link',name='Release comparison',exact=True).click()
                    settled()
                    assert 'baseline=release-b' in page.url
                    visit('quality?build_id=release-a&baseline=missing',shot='quality-missing-baseline.png')
                    expect(page.locator('#main')).to_contain_text('No package coverage')
                    check('Release comparison exposes sample/coverage warnings, scoped diagnostics and its own CSV')

                    visit('competitions?kind=ranking',shot='ranking-operations-desktop.png')
                    expect(page.locator('#main')).to_contain_text('Published generation')
                    expect(page.locator('#main')).to_contain_text('Worker last seen')
                    page.locator('#ranking-correction').click()
                    page.locator('#ranking-preview [name=player_id]').fill(fixture['player_id'])
                    page.locator('#ranking-preview [name=reason]').fill('Owned browser preview only')
                    page.locator('#ranking-preview [type=submit]').click()
                    expect(page.get_by_role('heading',name='Confirm ranking correction')).to_be_visible()
                    assert not page.locator('#ranking-confirm input[type=checkbox]').is_checked()
                    page.screenshot(path=str(output/'ranking-correction-preview.png'))
                    page.locator('#dialog [data-close]').click()
                    with sqlite3.connect(folder/'database.sqlite') as db:
                        assert db.execute('SELECT count(*) FROM world_ranking_corrections').fetchone()[0]==0
                    check('Ranking progress/history are inspectable; correction preview requires separate explicit confirmation and cancellation writes nothing')

                    for width,height in ((1440,1000),(1280,800),(390,844)):
                        for route,label in [('overview','overview'),('product','activity'),('product?tab=retention','retention'),(quality,'quality'),('competitions?kind=ranking','ranking'),('system/jobs','queues'),('studio?tab=saved','saved')]:
                            visit(route,width,height,label+'-'+str(width)+'.png')
                    check('Changed workflows remain contained at desktop, compact and phone-width viewports')

                    page.locator('#logout').click()
                    page.locator('#key').fill(config['analyst'])
                    page.locator('#login button').click()
                    page.wait_for_timeout(80)
                    settled()
                    visit('competitions?kind=ranking')
                    assert page.locator('#ranking-correction').count()==0
                    visit('product?tab=retention')
                    assert page.locator('#platform-export').count()==1
                    check('Analysts can inspect ranking and download reports while correction controls remain owner-only')
                    assert not result['javascript_errors'],result['javascript_errors']
                    browser.close()
        finally:
            process.terminate()
            process.wait(timeout=15)
            (output/'browser.json').write_text(json.dumps(result,indent=2),encoding='utf-8')
    print(json.dumps({'checks':len(result['checks']),'pages':len(result['pages']),
                      'javascript_errors':result['javascript_errors'],'output':str(output)}))


if __name__ == '__main__':
    main()
