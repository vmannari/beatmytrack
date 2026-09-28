"""Actual Web Audio integration for the shared-score instrument bank."""
from pathlib import Path
import json
from playwright.sync_api import sync_playwright

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT/'docs/evidence/music-r3'
with sync_playwright() as p:
    browser = p.chromium.launch(channel='msedge',headless=True,args=['--autoplay-policy=no-user-gesture-required'])
    page = browser.new_page(viewport={'width':1440,'height':1000})
    errors=[]
    page.on('pageerror',lambda e:errors.append(str(e)))
    page.goto('http://127.0.0.1:18765/lab.html'); page.locator('.presets summary').click()
    for choice in (1,2,3):
        page.locator(f'[data-r3="{choice}"]').click()
        page.wait_for_function('tracks.length === 6 && !loading')
        assert page.evaluate('tracks.map(t => t.asset)').count('') == 0
        assert page.evaluate(f'tracks.every(t => t.asset.endsWith("-{choice}.wav"))')
    page.locator('[data-r3="0"]').click()
    page.wait_for_function('tracks.length === 6 && !loading')
    selected = page.evaluate('tracks.map(t=>t.asset)')
    assert page.input_value('#mode') == 'layers'
    page.uncheck('#advance')
    page.click('#play')
    page.wait_for_function('workbench.getState().position > .3')
    page.wait_for_function('() => {analyser.getFloatTimeDomainData(meterData); return Math.max(...meterData.map(Math.abs)) > .00001}')
    page.evaluate('window.originalSources = tracks.map(t=>t.source)')
    for stage in range(6):
        page.locator('#stages button').nth(stage).click()
        assert page.evaluate('tracks.filter(t=>t.target>0).map(t=>t.stage)') == list(range(stage+1))
        assert page.evaluate('tracks.every((t,i)=>t.source===originalSources[i])')
    page.click('#collision')
    assert page.evaluate('tracks.map(t=>t.asset)') == selected
    assert page.evaluate('tracks.filter(t=>t.target>0).map(t=>t.stage)') == [0]
    page.click('#restart')
    assert page.evaluate('tracks.map(t=>t.asset)') == selected
    page.locator('#stages button').nth(5).click()
    page.locator('#seek').evaluate('(el)=>{el.value=15.5;el.dispatchEvent(new Event("input"))}')
    page.wait_for_function('workbench.getState().position > 16.2')
    page.wait_for_function('() => {analyser.getFloatTimeDomainData(meterData); return Math.max(...meterData.map(Math.abs)) > .00001}')
    position = page.evaluate('workbench.getState().position')
    select = page.locator('.track-title select').first
    alternatives = select.locator('option').evaluate_all('(es)=>es.map(e=>e.value)')
    chosen = next(v for v in alternatives if v != select.input_value())
    select.select_option(chosen)
    page.wait_for_function('!loading')
    assert page.evaluate('tracks[0].asset') == chosen
    assert page.evaluate('workbench.getState().position') >= position
    assert page.evaluate('tracks.slice(1).map(t=>t.asset)') == selected[1:]
    page.locator('.track .toggles input').nth(1).check()
    assert page.evaluate('tracks.filter(t=>t.target>0).length') == 1
    page.locator('.track .toggles input').nth(1).uncheck()
    page.click('#play')
    with page.expect_download() as download:
        page.click('#save')
    setup = OUT/'audition-setup.json'
    download.value.save_as(str(setup))
    saved = page.evaluate('tracks.map(t=>t.asset)')
    page.click('#clear')
    page.set_input_files('#load',str(setup))
    page.wait_for_function('tracks.length===6 && document.querySelector("#status").textContent.startsWith("Setup loaded")')
    assert page.evaluate('tracks.map(t=>t.asset)') == saved
    assert page.locator('.track-title select').count() == 6
    page.evaluate('''() => {const prior=previousR3.slice();crypto.getRandomValues=values=>{prior.forEach((v,i)=>values[i]=v-1);return values;}}''')
    page.locator('[data-r3="0"]').click()
    page.wait_for_function('tracks.length===6 && !loading')
    assert page.evaluate('tracks.map(t=>t.asset)') != selected
    page.locator('#stages button').nth(4).click()
    page.screenshot(path=str(OUT/'workbench-r3.png'),full_page=True)
    page.set_viewport_size({'width':800,'height':1000})
    assert page.evaluate('document.documentElement.scrollWidth<=innerWidth')
    page.screenshot(path=str(OUT/'workbench-r3-compact.png'),full_page=True)
    assert not errors,errors
    (OUT/'browser-results.json').write_text(json.dumps({'result':'PASS','checks':[
        'All A/B/C banks','random one option per instrument','cumulative mode selected',
        'actual nonzero playback','all six cumulative stages','sources remain running across stage changes',
        'collision returns to motif without reshuffling','restart keeps choices','playback across 16-second loop',
        'manual variation preserves position and other instruments','solo isolation',
        'saved setup restores choices and variation controls','forced repeat random draw changes one option',
        'compact layout without overflow','no JS errors']},indent=2))
    browser.close()
print('PASS: R3 browser regression (15 checks)')
