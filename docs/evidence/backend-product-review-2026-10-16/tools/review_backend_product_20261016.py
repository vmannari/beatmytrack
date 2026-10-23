"""Read-only deployed Studio inventory and browser/HTTP measurements."""
import argparse
import hashlib
import importlib.util
import json
import re
import statistics
import time
import ctypes
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'docs/evidence/backend-product-review-2026-10-16'
PRIVATE = ROOT / 'build/backend-product-review-2026-10-16'
OUT.mkdir(parents=True, exist_ok=True)
PRIVATE.mkdir(parents=True, exist_ok=True)
spec = importlib.util.spec_from_file_location('read_only_deployment', ROOT / '.tools/backend_latest_rollout_20261016.py')
d = importlib.util.module_from_spec(spec)
spec.loader.exec_module(d)
# Cloud SDK on this Windows host emits the native code page even when this
# review process uses UTF-8 for its own public report output.
_cloud_encoding = 'cp' + str(ctypes.windll.kernel32.GetACP())
d.locale.getpreferredencoding = lambda *_args: _cloud_encoding

def write(name, value):
    (OUT / name).write_text(json.dumps(value, indent=2) + '\n', encoding='utf-8')

def setup():
    api = d.service.describe('api', d.service.n['api'])
    key = d.u.staff_key(api)
    return api['status']['url'], key, api

def redact(path):
    return re.sub(r'[0-9a-f]{8}-[0-9a-f-]{27,}', '{id}', path)

def inspect():
    base, key, resource = setup()
    paths = ['overview', 'competition-health', 'studio/capabilities', 'product-analytics',
        'alarms', 'quality', 'network-health', 'race-statistics', 'purchases', 'products',
        'catalogue/tracks?limit=1', 'catalogue/players?limit=1',
        'competitions?kind=rivalry', 'cases?limit=1', 'publications?limit=1']
    results, raw = [], {}
    for path in paths:
        start = time.perf_counter()
        try:
            response = d.u.fetch(base, '/v1/admin/' + path, key)
            value = response.json()
            raw[path] = value
            results.append({'path': path, 'status': response.status_code,
                'milliseconds': round((time.perf_counter()-start)*1000, 2),
                'bytes': len(response.content), 'keys': list(value) if isinstance(value, dict) else []})
        except Exception as error:
            results.append({'path': path, 'error': str(error)})
    (PRIVATE / 'live-responses.private.json').write_text(json.dumps(raw, indent=2), encoding='utf-8')
    (PRIVATE / 'api-resource.private.json').write_text(json.dumps(resource), encoding='utf-8')
    hashes = {}
    previous = json.loads((ROOT / 'docs/evidence/backend-approved-followup-2026-10-16/verify-live.json').read_text())
    for name in previous['assets']:
        path = '/admin' if name == 'index.html' else '/admin/assets/' + name
        content = d.u.fetch(base, path).content
        hashes[name] = hashlib.sha256(content).hexdigest()
    result = {'origin': base, 'image': d.stage.resource_image(resource),
        'traffic': [{'revision': t.get('revisionName'), 'percent': t.get('percent', 0)} for t in resource['status']['traffic']],
        'schema': raw.get('overview', {}).get('schema'), 'endpoints': results,
        'asset_hashes': hashes, 'matches_approved_deployment_assets': hashes == previous['assets'],
        'health': raw.get('competition-health', {}).get('status'),
        'available_workers': raw.get('competition-health', {}).get('available_workers'),
        'mutations': 0}
    write('live-inventory.json', result)
    print(json.dumps({k:v for k,v in result.items() if k not in ('asset_hashes','endpoints') }))
    print(json.dumps({'endpoints': results}))

ROUTES = ['overview', 'alarms', 'product', 'quality', 'analytics', 'tracks', 'publications',
    'players', 'races', 'competitions', 'cases', 'economy', 'system', 'live', 'studio',
    'quality?tab=network', 'quality?tab=exits', 'quality?tab=collection',
    'system/jobs', 'system/audit', 'system/access']

def browser():
    from playwright.sync_api import sync_playwright
    base, key, _ = setup()
    errors, writes, failed, measurements, layout = [], [], [], [], []
    with sync_playwright() as driver:
        browser = driver.chromium.launch(headless=True, executable_path='C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe')
        context = browser.new_context(viewport={'width': 1440, 'height': 1000})
        context.add_init_script('''window.__reviewLongTasks=[];
try{new PerformanceObserver(list=>{window.__reviewLongTasks.push(...list.getEntries().map(e=>({start:e.startTime,duration:e.duration})));}).observe({type:'longtask',buffered:true});}catch{}
''')
        page = context.new_page()
        page.on('pageerror', lambda error: errors.append(str(error)))
        page.on('request', lambda request: writes.append({'method': request.method, 'path': redact(request.url.split(base)[-1])})
            if request.url.startswith(base) and request.method not in ('GET','HEAD','OPTIONS') else None)
        page.on('response', lambda response: failed.append({'status': response.status, 'path': redact(response.url.split(base)[-1])})
            if response.url.startswith(base+'/v1/admin/') and response.status >= 400 else None)
        page.goto(base+'/admin#overview')
        page.fill('#key', key)
        page.locator('#login button').click()
        def wait_ready(route=None, heading=None):
            deadline=time.monotonic()+90
            while time.monotonic()<deadline:
                if page.evaluate('''(scope)=>!document.querySelector('#main').hasAttribute('aria-busy')
                    && !!document.querySelector('#main h1')
                    && (!scope.route || lastRenderedRoute===scope.route)
                    && (!scope.heading || document.querySelector('#main h1').textContent===scope.heading)''', {'route':route,'heading':heading}):
                    return
                page.wait_for_timeout(20)
            raise RuntimeError('Review route did not finish: '+str(route or heading))
        wait_ready(heading='Overview')
        def visit(route, width, repeat):
            page.set_viewport_size({'width': width, 'height': 1000 if width>500 else 844})
            mark = page.evaluate('performance.now()')
            start = time.perf_counter()
            if page.evaluate('location.hash') == '#'+route:
                page.evaluate('render()')
            else:
                page.evaluate('(hash)=>location.hash=hash', route)
            wait_ready(route=route)
            page.wait_for_timeout(80)
            measured = page.evaluate('''(mark)=>({
heading:document.querySelector('#main h1')?.textContent,
error:!!document.querySelector('#retry'),
overflow:document.documentElement.scrollWidth>innerWidth,
documentWidth:document.documentElement.scrollWidth,
domNodes:document.querySelectorAll('*').length,
tableCount:document.querySelectorAll('#main table').length,
tableRows:document.querySelectorAll('#main tbody tr').length,
longTasks:window.__reviewLongTasks.filter(e=>e.start>=mark),
requests:performance.getEntriesByType('resource').filter(e=>e.startTime>=mark&&e.name.includes('/v1/admin/')).map(e=>({path:new URL(e.name).pathname,duration:e.duration,transfer:e.transferSize,bytes:e.decodedBodySize})),
smallTargets:[...document.querySelectorAll('#main button,#main .btn,#nav a')].filter(e=>{const r=e.getBoundingClientRect();return r.width>0&&r.height>0&&(r.height<24||r.width<24)}).length
})''', mark)
            measured.update(route=route, width=width, repeat=repeat,
                display_ms=round((time.perf_counter()-start)*1000-80, 2))
            for request in measured['requests']:
                request['path'] = redact(request['path'])
                request['duration'] = round(request['duration'], 2)
            measurements.append(measured)
            return measured
        for repeat in range(3):
            for route in ROUTES:
                visit(route, 1440, repeat)
        for width in (1024,768,390):
            for route in ('overview','alarms','product','quality','tracks','players','economy','system','studio'):
                result = visit(route,width,0)
                layout.append({'route':route,'width':width,'overflow':result['overflow'],'heading':result['heading'],'error':result['error']})
                page.screenshot(path=str(PRIVATE/(route.replace('/','-')+'-'+str(width)+'.private.png')),full_page=True)
        # Rapid navigation, history and locking are local browser actions only.
        page.evaluate("location.hash='product';setTimeout(()=>location.hash='quality',10);setTimeout(()=>location.hash='alarms',20)")
        wait_ready(heading='Alarms')
        rapid_ok = True
        page.evaluate('clearAccess();login()')
        lock_ok = page.locator('#key').is_visible() and page.evaluate("key===''&&role===''&&reporting===null&&localStorage.length===0&&sessionStorage.length===0")
        browser.close()
    result = {'origin':base,'read_only':True,'sample_scope':'One desktop browser from operator PC; three repeated visits, no production load generation or field INP claim',
        'measurements':measurements,'layouts':layout,'javascript_errors':errors,'failed_admin_reads':failed,
        'mutations':writes,'rapid_navigation_final_route_correct':rapid_ok,'lock_clears_access':lock_ok}
    write('live-browser-review.json',result)
    summary=[]
    for route in ROUTES:
        rows=[m for m in measurements if m['route']==route and m['width']==1440]
        summary.append({'route':route,'display_ms':round(statistics.median(m['display_ms'] for m in rows),1),
            'max_ms':max(m['display_ms'] for m in rows),'requests':len(rows[0]['requests']),
            'request_bytes':sum(r['bytes'] for r in rows[0]['requests']),
            'long_tasks':sum(len(m['longTasks']) for m in rows),'error':any(m['error'] for m in rows)})
    write('browser-summary.json',{'routes':summary,'layout_overflows':[x for x in layout if x['overflow']],
        'javascript_errors':errors,'failed_admin_reads':failed,'mutations':writes})
    print(json.dumps({'routes':summary,'layout_overflows':[x for x in layout if x['overflow']],
        'javascript_errors':errors,'failed_admin_reads':failed,'mutations':writes}))

def inspectors():
    from playwright.sync_api import sync_playwright, expect
    base,key,_=setup()
    raw=json.loads((PRIVATE/'live-responses.private.json').read_text())
    routes=[]
    for section,path in [('players','catalogue/players?limit=1'),('tracks','catalogue/tracks?limit=1')]:
        items=raw[path]['items']
        if items:routes.append(section+'/'+items[0]['id'])
    races=d.u.fetch(base,'/v1/admin/entities/races?limit=1',key).json()['items']
    if races:routes.append('races/'+races[0]['id'])
    groups=raw['competitions?kind=rivalry']['items']
    if groups:routes.append('competitions/'+groups[0]['id']+'?kind=rivalry')
    result=[]
    with sync_playwright() as driver:
        browser=driver.chromium.launch(headless=True,executable_path='C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe')
        page=browser.new_page(viewport={'width':1440,'height':1000})
        page.goto(base+'/admin#overview');page.fill('#key',key);page.locator('#login button').click()
        expect(page.locator('#main h1')).to_have_text('Overview',timeout=60000)
        for width in (1440,390):
            page.set_viewport_size({'width':width,'height':1000})
            for route in routes:
                start=time.perf_counter();page.evaluate('(r)=>location.hash=r',route)
                deadline=time.monotonic()+60
                while time.monotonic()<deadline:
                    if page.evaluate('(r)=>lastRenderedRoute===r&&!document.querySelector("#main").hasAttribute("aria-busy")',route):break
                    page.wait_for_timeout(20)
                else:raise RuntimeError('Inspector did not finish: '+redact(route))
                detail=page.evaluate('''()=>({error:!!document.querySelector('#retry'),overflow:document.documentElement.scrollWidth>innerWidth,
                    tables:document.querySelectorAll('#main table').length,nodes:document.querySelectorAll('*').length})''')
                result.append({'route':redact(route),'width':width,'display_ms':round((time.perf_counter()-start)*1000,2),**detail})
        browser.close()
    write('live-inspectors.json',{'read_only':True,'inspectors':result,'case_publication_details':'No live records available; source-reviewed only'})
    print(json.dumps(result))

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('action', choices=['inspect','browser','inspectors'])
    action=parser.parse_args().action
    globals()[action]()
