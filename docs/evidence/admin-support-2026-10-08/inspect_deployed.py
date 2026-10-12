"""Read-only acceptance of the owner-linked admin rollout; no commands execute."""
import json
import os
import subprocess
import urllib.error
import urllib.request
from datetime import datetime, timezone
from pathlib import Path
from uuid import uuid4

from playwright.sync_api import sync_playwright

ROOT = Path(__file__).resolve().parents[3]
OUTPUT = Path(__file__).resolve().parent
PRIVATE = ROOT / '.tools/gcp-staging'
URL = 'https://bmt-stg-e7a444ab-api-tzgxkrwzva-ew.a.run.app'


def main():
    config = json.loads((PRIVATE/'config.json').read_text())
    os.environ['CLOUDSDK_CORE_CUSTOM_CA_CERTS_FILE'] = str(PRIVATE/'windows-trust.pem')
    def cloud(*args):
        result = subprocess.run([*config['gcloud'],'--project='+config['project'],*args],
            capture_output=True,text=True,check=False)
        if result.returncode: raise RuntimeError('Read-only cloud lookup failed')
        return result.stdout
    service = json.loads(cloud('run','services','describe','bmt-stg-'+config['owner'][:8]+'-api',
        '--region='+config['region'],'--format=json'))
    assert service['status']['url']==URL
    env={value['name']:value for value in service['spec']['template']['spec']['containers'][0]['env']}
    binding=env['BMT_ADMIN_OWNER_KEY']['valueFrom']['secretKeyRef']
    key=cloud('secrets','versions','access',binding['key'],'--secret='+binding['name']).strip()
    def api(path,body=None):
        request=urllib.request.Request(URL+'/v1/admin/'+path,headers={
            'Authorization':'Bearer '+key,**({'Content-Type':'application/json'} if body else {})},
            method='POST' if body else 'GET',data=json.dumps(body).encode() if body else None)
        with urllib.request.urlopen(request,timeout=30) as response:return json.loads(response.read())
    overview=api('overview?days=90')
    candidates=api('entities/players?q=developer&limit=1')['items']
    if not candidates:candidates=api('entities/players?limit=1')['items']
    assert candidates
    player=candidates[0]['id']
    support=api('players/'+player+'/support')
    history=api('players/'+player+'/history?limit=25')
    report={'observed_at':datetime.now(timezone.utc).isoformat(),'url':URL,'read_only':True,
        'schema':overview['schema'],'accounts_include_all_players':overview['players'],
        'reporting_range':{'since':overview['since'],'until':overview['until']},
        'support':{'loaded':True,'history_page_size':len(history['items']),
            'configured':support['development_controls']['configured'],
            'editable':support['development_controls']['editable']},'assets':{}}
    assert support['development_controls']['configured']
    if support['development_controls']['editable']:
        original=api('players/'+player+'/history?kind=purchase&limit=25')
        preview=api('players/'+player+'/development/preview',{'command_id':str(uuid4()),
            'action':'simulate_purchase','product_id':'creator_slot_1','outcome':'pending'})
        after=api('players/'+player+'/history?kind=purchase&limit=25')
        assert original['items']==after['items'] and preview['before']['access']==preview['after']['access']
        report['support']['pending_preview_no_grant']=True
    for name in ('index.html','app.js','commerce.js','support.js','style.css'):
        path='/admin' if name=='index.html' else '/admin/assets/'+name
        with urllib.request.urlopen(URL+path,timeout=30) as response:raw=response.read()
        report['assets'][name]=raw==(ROOT/'backend/bmt_backend/admin_ui'/name).read_bytes()
    assert all(report['assets'].values())
    with sync_playwright() as playwright:
        browser=playwright.chromium.launch(headless=True,
            executable_path='C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe')
        page=browser.new_page(viewport={'width':1440,'height':1000})
        errors=[];page.on('pageerror',lambda error:errors.append(str(error)))
        page.goto(URL+'/admin#overview');page.fill('#key',key);page.locator('#login button').click()
        page.get_by_role('heading',name='The game, at a glance.',exact=True).wait_for()
        page.screenshot(path=str(OUTPUT/'live-overview.png'),full_page=True,animations='disabled')
        page.evaluate('route=>location.hash=route','players/'+player+'?all=1')
        page.get_by_role('heading',name='Activity & evidence',exact=True).wait_for()
        page.screenshot(path=str(OUTPUT/'live-player.png'),full_page=True,animations='disabled')
        page.evaluate("location.hash='analytics'")
        page.get_by_role('heading',name='Driving analytics',exact=True).wait_for()
        with page.expect_response(lambda response:'/overview?days=90' in response.url):page.select_option('#days','90')
        page.get_by_role('heading',name='Driving analytics',exact=True).wait_for();page.wait_for_load_state('networkidle')
        report['chart_bars']=page.locator('.console-bar').count();assert report['chart_bars']==90
        page.screenshot(path=str(OUTPUT/'live-analytics.png'),full_page=True,animations='disabled')
        page.evaluate("location.hash='system'")
        page.get_by_role('heading',name='Verified competition',exact=True).wait_for()
        capacity=page.locator('.console-kv').filter(has_text='storage free gib').inner_text()
        assert capacity.endswith('Unavailable');report['gcs_capacity']='Unavailable'
        page.screenshot(path=str(OUTPUT/'live-system.png'),full_page=True,animations='disabled')
        assert not errors;report['javascript_errors']=errors
        page.locator('#logout').click();assert page.locator('#key').input_value()==''
        browser.close()
    (OUTPUT/'live-checks.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
    print(json.dumps(report,indent=2))


if __name__=='__main__':main()
