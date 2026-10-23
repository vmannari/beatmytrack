"""GET-only inspection of populated Studio, using the retained owner credential."""
import importlib.util
import json
import time
import urllib.request
from pathlib import Path

from playwright.sync_api import expect, sync_playwright

ROOT=Path(__file__).resolve().parents[1]
spec=importlib.util.spec_from_file_location('sim_cloud',ROOT/'.tools/full_backend_deploy_20261018.py')
cloud=importlib.util.module_from_spec(spec);spec.loader.exec_module(cloud)
d=cloud.d
base=d.r['url']
key=d.u.staff_key(d.service.describe('api',d.service.n['api']))
until=int(time.time())+1;since=(until//86400-60)*86400
scope='since='+str(since)+'&until='+str(until)
reads=[]
def get(path):
    started=time.perf_counter()
    request=urllib.request.Request(base+'/v1/admin/'+path,headers={'Authorization':'Bearer '+key})
    with urllib.request.urlopen(request,timeout=60) as response:result=json.load(response)
    reads.append({'path':path,'seconds':round(time.perf_counter()-started,3)})
    return result

behaviour=get('analysis/behaviour?'+scope)
recent=get('analysis/behaviour')
quality=get('analysis/releases?build_id=0.59.1&baseline=0.59.0&'+scope)
recovery=get('analysis/releases?build_id=0.59.2&baseline=0.59.1&'+scope)
finance=get('finance?'+scope)
incidents=get('incidents?state=all')
cases=get('cases?limit=30')
experiments=get('experiments')
scorecard=get('experiments/'+experiments['items'][0]['id']+'/scorecard') if experiments['items'] else None
report={'complete_population':bool(d.r.get('population_complete')),'scope':{'since':since,'until':until},
    'behaviour':behaviour,'recent_behaviour':recent,'quality':quality,'recovery':recovery,
    'finance':finance,'incident_states':incidents['counts'],'case_count':len(cases['items']),
    'experiment_scorecard':scorecard,'api_reads':reads}
(d.WORK/'browser-api-current.private.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
assert behaviour['coverage']['available'] and behaviour['active_players']>0
if d.r.get('population_complete'):
    assert behaviour['active_players']==600,behaviour['active_players']
    assert recent['active_players']>0
    assert quality['candidate'] and quality['baseline'] and quality['comparison']['completion_change']<0
    assert quality['candidate']['slow_frames']/quality['candidate']['frames']>quality['baseline']['slow_frames']/quality['baseline']['frames']
    assert finance['money'] and finance['coins'] and len(cases['items'])>=24
    assert all(incidents['counts'].get(s,0)>0 for s in ['open','acknowledged','recovered','closed'])
    assert any(r['d30']['mature'] for r in behaviour['retention'])

routes=['overview','alarms','alarms?state=all','alarms?tab=checks','alarms?tab=history','alarms?tab=notifications',
    'product','product?tab=retention','product?tab=journey','product?tab=engagement','product?tab=history',
    'quality?build_id=0.59.1&baseline=0.59.0','quality?build_id=0.59.2&baseline=0.59.1','quality?tab=diagnostics',
    'economy','economy?tab=delivery','tracks','cases','studio','studio?tab=releases','studio?tab=experiments',
    'studio?tab=access','system/jobs','system/network']
if cases['items']:routes.append('cases/'+cases['items'][0]['id'])
for state in ['open','acknowledged','recovered','closed']:
    row=next((r for r in incidents['items'] if r['state']==state),None)
    if row:routes.append('alarms/'+row['id'])
selected=get('catalogue/players?population=artificial&state=active&limit=1')['items'] or get('catalogue/players?state=active&limit=1')['items']
player_id=selected[0]['id']
selected_grants=get('players/'+player_id+'/support')['grants']
expected_compact=sum(p['group']=='Customisation kits' and p['id'] not in selected_grants['owned'] for p in selected_grants['products'])
routes += ['players','players/'+player_id,'players/'+player_id+'?tab=purchases','players/'+player_id+'?tab=identity']
errors=[];writes=[];failures=[];checks=[];screens=[]
with sync_playwright() as driver:
    browser=driver.chromium.launch(headless=True,executable_path='C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe')
    page=browser.new_page(viewport={'width':1440,'height':1050})
    page.on('pageerror',lambda error:errors.append(str(error)))
    page.on('request',lambda req:writes.append({'method':req.method,'path':req.url.split(base)[-1]}) if req.url.startswith(base) and req.method not in ('GET','HEAD','OPTIONS') else None)
    page.on('response',lambda res:failures.append({'status':res.status,'path':res.url.split(base)[-1]}) if res.url.startswith(base+'/v1/admin/') and res.status>=400 else None)
    page.goto(base+'/admin#overview');page.fill('#key',key);page.locator('#login button').click()
    expect(page.locator('h1')).to_have_text('Know what needs attention.',timeout=60000)
    for width,height in [(1440,1050),(390,844)]:
        page.set_viewport_size({'width':width,'height':height})
        for index,route in enumerate(routes):
            raw=route+('&' if '?' in route else '?')+scope
            started=time.perf_counter();page.evaluate('(r)=>location.hash=r',raw)
            page.wait_for_function('(r)=>lastRenderedRoute===r',arg=raw,timeout=60000)
            expect(page.locator('h1').first).to_be_visible()
            assert page.evaluate('document.documentElement.scrollWidth<=innerWidth'),(width,route,'page overflow')
            assert not page.locator('#main .console-error:visible').count(),(width,route,'render error')
            if route.startswith('alarms/'):
                state=next(r['state'] for r in incidents['items'] if route.endswith(r['id']))
                if state=='recovered':expect(page.locator('[data-incident="clear"]')).to_be_visible()
                if state=='open':expect(page.locator('[data-incident="acknowledge"]')).to_be_visible()
            if 'tab=purchases' in route:
                expect(page.locator('#player-grant')).to_be_visible()
                page.locator('#player-grant').click()
                page.locator('#grant-search').fill('compact')
                assert page.locator('#grant-product option').count()==expected_compact
                page.screenshot(path=str(d.OUTPUT/f'grant-picker-{width}.png'))
                page.locator('#dialog [data-close]').click()
            checks.append({'width':width,'route':route,'title':page.locator('h1').first.inner_text(),'seconds':round(time.perf_counter()-started,3)})
            if route in ['overview','alarms','product?tab=journey','product?tab=retention','quality?build_id=0.59.1&baseline=0.59.0','economy','cases'] or route.startswith('alarms/') or 'tab=purchases' in route:
                filename=f'populated-{width}-{index:02d}.png';page.screenshot(path=str(d.OUTPUT/filename),full_page=True);screens.append(filename)
        if width==1440 and scorecard:
            page.evaluate('(r)=>location.hash=r','studio?tab=experiments&'+scope)
            page.wait_for_function('(r)=>lastRenderedRoute===r',arg='studio?tab=experiments&'+scope)
            page.locator('[data-scorecard]').first.click();expect(page.locator('#dialog')).to_be_visible()
            expect(page.locator('#dialog')).to_contain_text('Decision: hold')
            page.keyboard.press('Escape')
    page.locator('#logout').click();expect(page.locator('#login')).to_be_visible()
    assert page.evaluate("key===''&&role===''&&reporting===null&&localStorage.length===0&&sessionStorage.length===0")
    browser.close()
assert not errors and not writes and not failures,(errors,writes,failures)
report.update(browser_checks=checks,javascript_errors=errors,live_mutations=writes,failed_admin_reads=failures,screenshots=screens,read_only=True)
(d.OUTPUT/'populated-browser.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
if d.r.get('population_complete'):
    d.r['live_browser']=True;d.save()
print(json.dumps({'view_checks':len(checks),'players':behaviour['active_players'],'recent_active':recent['active_players'],'errors':len(errors),'mutations':len(writes),'slowest_api_seconds':max(r['seconds'] for r in reads)}))
