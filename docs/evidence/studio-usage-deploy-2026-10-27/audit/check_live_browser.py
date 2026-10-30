"""Real private Studio shell/sign-in checks; no staff credential or owner session is used."""
import importlib.util
import json
from pathlib import Path

from playwright.sync_api import expect, sync_playwright

WORK=Path(__file__).resolve().parent
spec=importlib.util.spec_from_file_location('usage_rollout',WORK/'deploy.py')
d=importlib.util.module_from_spec(spec);spec.loader.exec_module(d)
live=d.describe(d.BASE+'-studio')
origin=live['uri']
token=d.gc('auth','print-identity-token',label='browser-identity-token')
errors=[]
with sync_playwright() as p:
    browser=p.chromium.launch(headless=True,executable_path='C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe')
    context=browser.new_context(viewport={'width':1440,'height':1000})
    # Forward the invoker token only to the exact owned service origin. The
    # identity-provider/CDN requests never receive this header.
    def invoke(route):
        route.continue_(headers={**route.request.headers,'X-Serverless-Authorization':'Bearer '+token})
    context.route(origin+'/**',invoke)
    page=context.new_page();page.on('pageerror',lambda e:errors.append(str(e)))
    page.goto(origin+'/admin#usage',wait_until='networkidle',timeout=60000)
    expect(page.get_by_role('button',name='Sign in with Google',exact=True)).to_be_visible(timeout=30000)
    expect(page.locator('.console-nav[data-route="usage"]')).to_contain_text('Usage & costs')
    expect(page.locator('#key')).to_have_count(0)
    expect(page.locator('#role')).to_contain_text('Authentication required')
    masks=page.locator('#main p').filter(has_text='@')
    page.screenshot(path=str(d.OUT/'live-shell-desktop.png'),full_page=True,mask=[masks])
    page.set_viewport_size({'width':390,'height':844})
    expect(page.get_by_role('button',name='Sign in with Google',exact=True)).to_be_visible()
    assert page.evaluate('document.documentElement.scrollWidth <= innerWidth+1')
    page.screenshot(path=str(d.OUT/'live-shell-narrow.png'),full_page=True,mask=[masks])
    assert not errors,errors
    browser.close()
result={'live_origin':origin,'usage_navigation_present':True,'google_signin_present':True,'legacy_key_absent':True,
    'staff_authentication_required':True,'widths':[1440,390],'page_errors':errors,'owner_credentials_entered':False,
    'physical_device_test':False,'scope':'Actual live private shell/sign-in; no authenticated Usage data-page/browser-session claim'}
d.write(d.OUT/'live-browser.json',result)
print(json.dumps(result))
