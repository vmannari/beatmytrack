"""Verify core deployed Studio views and the explicit unconfigured-replica response."""
import importlib.util
import json
import time
from pathlib import Path
import requests
from playwright.sync_api import expect,sync_playwright

ROOT=Path(__file__).resolve().parents[1]
spec=importlib.util.spec_from_file_location('cut57',ROOT/'.tools/release57_cutover.py')
module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)
d=module.d;base=d.r['url'];key=d.u.staff_key(d.service.describe('api',d.service.n['api']))
paths=['overview','alarms','tracks','players','economy','studio?tab=access','system/jobs','system/network']
errors=[];writes=[];failures=[];checks=[]
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
        for route in paths:
            started=time.perf_counter();page.evaluate('(r)=>location.hash=r',route)
            page.wait_for_function('(r)=>lastRenderedRoute===r',arg=route,timeout=60000)
            expect(page.locator('h1').first).to_be_visible()
            assert page.evaluate('document.documentElement.scrollWidth<=innerWidth'),(width,route,'overflow')
            assert not page.locator('#main .console-error:visible').count(),(width,route,'render error')
            checks.append({'width':width,'route':route,'seconds':round(time.perf_counter()-started,3)})
        page.evaluate("location.hash='overview'")
        page.wait_for_function("()=>lastRenderedRoute==='overview'")
        page.screenshot(path=str(d.OUTPUT/('core-studio-'+str(width)+'.png')),full_page=True)
    page.locator('#logout').click();expect(page.locator('#login')).to_be_visible()
    assert page.evaluate("key===''&&role===''&&reporting===null&&localStorage.length===0&&sessionStorage.length===0")
    browser.close()
assert not errors and not writes and not failures,(errors,writes,failures)
response=requests.get(base+'/v1/admin/analysis/behaviour',headers={'Authorization':'Bearer '+key},timeout=(5,30))
assert response.status_code==503 and 'STUDIO_ANALYSIS_REPLICA_NOT_CONFIGURED' in response.json()['detail']
result={'core_view_checks':checks,'javascript_errors':errors,'write_requests':writes,'failed_core_admin_reads':failures,
        'broad_analytics':'explicit503; dedicated reporting replica approval pending','read_only':True}
(d.OUTPUT/'core-browser.json').write_text(json.dumps(result,indent=2)+'\n')
d.r.update(live_browser=True,live_browser_scope='16 core operations views; broad analytics explicitly503 pending dedicated replica')
d.save()
print(json.dumps({'core_view_checks':len(checks),'javascript_errors':len(errors),'write_requests':len(writes),'failed_core_admin_reads':len(failures),'broad_analytics_requires_replica':True}))
