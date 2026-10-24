"""Read-only Studio review against a newly owned seeded local service."""
import argparse
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

ROOT = next(p for p in Path(__file__).resolve().parents if (p / 'backend/pyproject.toml').is_file())
sys.path[:0] = [str(ROOT / 'backend'), str(ROOT / 'backend/tests'), str(ROOT / 'scripts')]
OUTPUT = ROOT / 'docs/evidence/studio-review-2026-10-24'


def serve(folder, port):
    import uvicorn
    from bmt_backend.db import make_engine
    from bmt_backend.studio_reporting import StudioReporting
    from bmt_backend.track_models import now
    from studio_catalogue_browser_checks import seed_catalogue
    from test_studio_platform_console import serve as platform_serve

    original = uvicorn.run

    def isolated(app, **kwargs):
        fixture = json.loads((folder / 'fixture.json').read_text())
        with app.state.session_factory() as db:
            fixture.update(seed_catalogue(db, fixture['player_id'], now()))
            db.commit()
        (folder / 'fixture.json').write_text(json.dumps(fixture))
        with sqlite3.connect(folder / 'database.sqlite') as source:
            with sqlite3.connect(folder / 'reporting.sqlite') as target:
                source.backup(target)
        app.state.settings = replace(app.state.settings, environment='test', dev_auth_enabled=False, purchase_simulation_enabled=False)
        app.state.studio_reporting.close()
        app.state.studio_reporting = StudioReporting(
            app.state.settings,
            engine=make_engine('sqlite:///' + (folder / 'reporting.sqlite').as_posix()),
        )
        original(app, **kwargs)

    uvicorn.run = isolated
    platform_serve(folder, port)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--serve', type=Path)
    parser.add_argument('--port', type=int)
    args = parser.parse_args()
    if args.serve:
        return serve(args.serve, args.port)
    import httpx
    from playwright.sync_api import sync_playwright

    folder = ROOT / 'build' / ('studio-review-owned-' + uuid4().hex[:8])
    folder.mkdir(parents=True)
    OUTPUT.mkdir(parents=True, exist_ok=True)
    config = {name: secrets.token_urlsafe(32) for name in ('owner', 'analyst', 'development', 'monitor')}
    (folder / 'config.private.json').write_text(json.dumps(config))
    with socket.socket() as sock:
        sock.bind(('127.0.0.1', 0))
        port = sock.getsockname()[1]
    base = f'http://127.0.0.1:{port}'
    result = {'scope': 'Local source, isolated synthetic SQLite data, headless Edge. No live service or physical device accessed.',
              'pages': [], 'errors': [], 'reproductions': [], 'api': {}}
    with (folder / 'server.log').open('w', encoding='utf-8') as log:
        process = subprocess.Popen([sys.executable, str(Path(__file__).resolve()), '--serve', str(folder), '--port', str(port)],
                                   stdout=log, stderr=log, creationflags=subprocess.CREATE_NO_WINDOW)
        try:
            with httpx.Client(base_url=base, timeout=20) as http:
                for _ in range(100):
                    if process.poll() is not None:
                        raise RuntimeError('Owned fixture failed: ' + str(folder / 'server.log'))
                    try:
                        if http.get('/health').status_code == 200:
                            break
                    except httpx.ConnectError:
                        pass
                    time.sleep(.2)
                fixture = json.loads((folder / 'fixture.json').read_text())
                headers = {'Authorization': 'Bearer ' + config['owner']}
                endpoints = ['metrics', 'analysis/behaviour', 'analysis/behaviour?view=retention',
                             'analysis/behaviour?view=journey', 'analysis/behaviour?view=engagement',
                             'analysis/releases?build_id=release-a&baseline=release-b', 'finance', 'jobs',
                            'studio/capabilities', 'staff', 'incidents', 'competition-health', 'ranking/status']
                for endpoint in endpoints:
                    response = http.get('/v1/admin/' + endpoint, headers=headers)
                    result['api'][endpoint] = {'status': response.status_code, 'data': response.json()}
                with sync_playwright() as driver:
                    browser = driver.chromium.launch(headless=True, executable_path='C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe')
                    page = browser.new_page(viewport={'width': 1440, 'height': 1000}, accept_downloads=True)
                    page.on('pageerror', lambda error: result['errors'].append(str(error)))
                    page.goto(base + '/admin')
                    page.locator('#key').fill(config['owner'])
                    page.locator('#login button').click()
                    page.wait_for_function("() => !!document.querySelector('#main h1') && !document.querySelector('#login') && document.querySelector('#main').getAttribute('aria-busy')!=='true'")

                    def visit(route, width=1440, height=1000, capture=None):
                        page.set_viewport_size({'width': width, 'height': height})
                        page.evaluate("route => { location.hash=route; }", route)
                        page.wait_for_timeout(80)
                        page.wait_for_function("() => document.querySelector('#main').getAttribute('aria-busy')!=='true'", timeout=30000)
                        record = page.evaluate("""() => ({title:document.querySelector('#main h1')?.innerText,
                            text:document.querySelector('#main').innerText,
                            overflow:document.documentElement.scrollWidth-innerWidth,
                            height:document.querySelector('#main').scrollHeight,
                            tableTop:document.querySelector('#main table')?.getBoundingClientRect().top,
                            headings:[...document.querySelectorAll('#main h1,#main h2,#main h3')].map(x=>x.innerText),
                            links:[...document.querySelectorAll('#main a')].map(x=>({text:x.innerText,href:x.getAttribute('href')})),
                            unnamedControls:[...document.querySelectorAll('button,input,select,textarea')].filter(x=>x.getBoundingClientRect().width && !x.labels?.length && !x.getAttribute('aria-label') && !x.innerText && !x.getAttribute('aria-labelledby')).map(x=>({tag:x.tagName,id:x.id}))})""")
                        record.update(route=route, width=width, viewport_height=height)
                        result['pages'].append(record)
                        if capture:
                            page.screenshot(path=str(OUTPUT / capture), full_page=True)
                        return record

                    routes = ['overview', 'alarms', 'alarms?tab=history', 'alarms?tab=notifications', 'alarms?tab=checks',
                              'product', 'product?tab=retention', 'product?tab=journey', 'product?tab=engagement',
                              'quality?build_id=release-a&baseline=release-b', 'quality?tab=diagnostics',
                              'quality?tab=frames', 'quality?tab=network', 'economy', 'economy?tab=delivery',
                              'tracks', 'publications', 'competitions', 'cases', 'players', 'races',
                              'players/' + fixture['player_id'], 'races/' + fixture['run_id'],
                              'studio', 'studio?tab=saved', 'studio?tab=releases', 'studio?tab=experiments',
                              'studio?tab=access', 'system/jobs', 'system', 'system/audit']
                    for index, route in enumerate(routes):
                        shot = f'{index:02}-{route.split("?")[0].replace("/", "-")}-desktop.png' if route in ['overview','product','quality?build_id=release-a&baseline=release-b','economy','system/jobs','studio?tab=access'] else None
                        visit(route, capture=shot)
                    for width, height in [(1280,800),(390,844)]:
                        for index, route in enumerate(['overview','product','quality?build_id=release-a&baseline=release-b','economy','alarms','tracks']):
                            visit(route,width,height,f'{index:02}-{route.split("?")[0]}-{width}.png')

                    # Ordinary navigation must preserve the selected analytical scope.
                    visit('product?build_id=release-a&platform=android&mode=free_race&population=real')
                    scope_links = page.locator('#main a').evaluate_all("nodes=>nodes.filter(x=>['Are players returning?','Where do first races stop?','Does release quality explain a drop?'].includes(x.innerText)).map(x=>({text:x.innerText,href:x.getAttribute('href')}))")
                    result['reproductions'].append({'id':'scope-links','links':scope_links})
                    visit('overview')
                    result['reproductions'].append({'id':'pulse-drilldown','pulse':result['api']['competition-health']['data'].get('verified_last_5_minutes'),'links':page.locator('.platform-stat').evaluate_all("xs=>xs.map(x=>({text:x.innerText,href:x.getAttribute('href')}))")})

                    # A successful read can contain days-old observations.
                    def stale_projection(route):
                        data = route.fetch().json()
                        data['coverage']['latest_client_at'] = int(time.time()) - 3 * 86400
                        data['coverage']['processed_through'] = int(time.time()) - 2 * 86400
                        route.fulfill(json=data)
                    page.route('**/v1/admin/analysis/behaviour?*', stale_projection)
                    visit('product',capture='product-stale-projection.png')
                    result['reproductions'].append({'id':'stale-projection','visible_text':page.locator('#main').inner_text(),'notices':page.locator('#main .platform-notice').all_inner_texts()})
                    page.unroute('**/v1/admin/analysis/behaviour?*')

                    # A missing comparison baseline must have an honest empty state.
                    visit('quality?build_id=release-a&baseline=missing-build',capture='quality-missing-baseline.png')
                    # A single unavailable optional feed should not hide healthy operational cards.
                    page.route('**/v1/admin/metrics', lambda route: route.fulfill(status=503,content_type='application/json',body='{"detail":"REVIEW_OPTIONAL_SOURCE_UNAVAILABLE"}'))
                    visit('overview',capture='overview-optional-feed-failure.png')
                    result['reproductions'].append({'id':'optional-feed-failure','text':page.locator('#main').inner_text()})
                    page.unroute('**/v1/admin/metrics')

                    # Save view from a detail page, then inspect the actual saved location.
                    visit('players/' + fixture['player_id'])
                    page.locator('#platform-save').click()
                    page.locator('#dialog input[name=name]').fill('Review exact player')
                    page.locator('#dialog form button[type=submit],#dialog form button.btn-primary').last.click()
                    page.wait_for_timeout(300)
                    saved = http.get('/v1/admin/saved-views',headers=headers).json()
                    result['reproductions'].append({'id':'saved-detail','original_route':'players/'+fixture['player_id'],'saved':saved})
                    if page.locator('#dialog').evaluate('(x)=>x.open'):
                        page.locator('#dialog').evaluate('(x)=>x.close()')
                    visit('studio?tab=saved',capture='saved-detail.png')

                    # Check whether the CSV still borrows the gameplay database.
                    from bmt_backend.studio_platform_models import AnalysisDay
                    with sqlite3.connect(folder / 'reporting.sqlite') as db:
                        table = AnalysisDay.__tablename__
                        db.execute(f'UPDATE "{table}" SET counters=json_set(counters,\'$.race_started\',91)')
                    report = http.get('/v1/admin/analysis/behaviour',headers=headers).json()
                    csv = http.get('/v1/admin/exports/activity.csv',headers=headers)
                    result['reproductions'].append({'id':'export-source-parity','reported_starts':report.get('counters',{}).get('race_started'),'csv_status':csv.status_code,'csv':csv.text})
                    # Analyst visibility: useful workflows should stay accessible without owner writes.
                    page.locator('#logout').click()
                    page.locator('#key').fill(config['analyst'])
                    page.locator('#login button').click()
                    page.wait_for_timeout(300)
                    for route in ['overview','product','economy','cases','studio?tab=access']:
                        visit(route)
                    browser.close()
        finally:
            process.terminate()
            process.wait(timeout=15)
            (OUTPUT / 'browser-review.json').write_text(json.dumps(result,indent=2),encoding='utf-8')
    print(json.dumps({'pages':len(result['pages']),'errors':result['errors'],'failed_pages':[{'route':p['route'],'width':p['width'],'title':p['title']} for p in result['pages'] if p['title'] in ['Unable to load records','Access restricted']],'output':str(OUTPUT)}))


if __name__ == '__main__':
    main()
