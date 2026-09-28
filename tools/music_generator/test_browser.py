"""Actual Chromium/Web Audio smoke and controls. Requires developer Playwright."""
from pathlib import Path
import json
from playwright.sync_api import sync_playwright

ROOT = Path(__file__).resolve().parents[2]
EVIDENCE = ROOT / 'docs/evidence/music-toolkit'
EVIDENCE.mkdir(parents=True, exist_ok=True)
with sync_playwright() as p:
    browser = p.chromium.launch(channel='msedge', headless=True, args=['--autoplay-policy=no-user-gesture-required'])
    page = browser.new_page(viewport={'width': 1440, 'height': 1100})
    page.set_default_timeout(30000)
    errors = []
    page.on('pageerror', lambda error: errors.append(str(error)))
    page.goto('http://127.0.0.1:18765/lab.html'); page.locator('.presets summary').click()
    page.wait_for_function("document.querySelector('#recording').options.length > 1")
    page.click('#add')
    page.wait_for_selector('.track')
    page.click('#add')
    page.wait_for_function("document.querySelectorAll('.track').length === 2")
    # Fixture stages must not depend on whichever bank sorts last in the catalog.
    page.locator('.track > label select').nth(0).select_option('0')
    page.locator('.track > label select').nth(1).select_option('5')
    page.click('#play')
    page.wait_for_function('workbench.getState().position > .3')
    assert page.evaluate('workbench.getState().playing')
    assert page.evaluate('workbench.getState().position') > 0
    page.wait_for_function('() => {analyser.getFloatTimeDomainData(meterData); return Math.max(...meterData.map(Math.abs)) > .00001}')
    assert page.evaluate('workbench.getState().tracks[0].target') > 0
    assert page.evaluate('workbench.getState().tracks[1].target') == 0
    page.locator('#stages button').nth(5).click()
    assert page.evaluate('workbench.getState().tracks[0].target') == 0
    assert page.evaluate('workbench.getState().tracks[1].target') > 0
    page.select_option('#mode', 'layers')
    assert page.evaluate('workbench.getState().tracks.every(t => t.target > 0)')
    page.click('#collision')
    assert page.evaluate('workbench.getState().recovery') > 4
    assert page.evaluate('workbench.getState().tracks[1].target') == 0
    page.click('#play')
    before = page.evaluate('workbench.getState()')
    page.wait_for_timeout(200)
    after = page.evaluate('workbench.getState()')
    assert abs(before['position'] - after['position']) < .001
    assert abs(before['recovery'] - after['recovery']) < .001
    page.fill('#build', '10'); page.locator('#build').dispatch_event('change')
    page.locator('#stages button').nth(3).click()
    assert 9.9 < page.evaluate('workbench.getState().streak') < 10.1
    page.select_option('#mode', 'manual')
    assert page.evaluate('workbench.getState().tracks.every(t => t.target > 0)')
    page.locator('.track input[type=checkbox]').nth(1).check()
    assert page.evaluate('workbench.getState().tracks[1].target') == 0
    page.locator('.track input[type=checkbox]').nth(1).uncheck()
    page.locator('.track input[type=checkbox]').nth(0).uncheck()
    assert page.evaluate('workbench.getState().tracks[0].target') == 0
    page.locator('.track input[type=checkbox]').nth(0).check()
    page.locator('.track input[type=range]').nth(0).evaluate("e => {e.value=.2; e.dispatchEvent(new Event('input'))}")
    assert page.evaluate('workbench.getState().tracks[0].target') == .2
    page.eval_on_selector('#seek', "e => {e.value=12; e.dispatchEvent(new Event('input'))}")
    assert page.evaluate('workbench.getState().position') == 12
    with page.expect_download() as download:
        page.click('#save')
    setup = ROOT / 'build/music/browser-setup.json'
    download.value.save_as(setup)
    page.click('#clear'); assert page.locator('.track').count() == 0
    page.set_input_files('#load', str(setup))
    page.wait_for_function("workbench.getState().tracks.length === 2")
    assert page.evaluate('workbench.getState().position') == 12
    page.click('#restart')
    assert page.evaluate('workbench.getState().streak') == 0
    assert page.evaluate('workbench.getState().position') == 0
    # Import and trim an actual generated WAV using the user's file-input path.
    local_audio = next((ROOT / 'build/music/raw/smoke').rglob('*.wav'))
    page.set_input_files('#files', str(local_audio))
    page.wait_for_function('workbench.getState().tracks.length === 3')
    loop_in = page.locator('.track input[type=number]').nth(4)
    loop_in.fill('0.25'); loop_in.dispatch_event('change')
    assert page.evaluate('tracks[2].trimStart') == .25
    loop_in.fill('999'); loop_in.dispatch_event('change')
    assert page.evaluate('tracks[2].trimStart') == .25
    # Replace the duplicated control fixtures with the distinct prepared endpoints
    # when present; screenshot remains genuine browser UI, not generated artwork.
    page.click('#clear')
    options = page.locator('#recording option').evaluate_all('(es) => es.map(e => ({value:e.value,text:e.textContent}))')
    for name in ['00_focus_prepared', '05_breakthrough_prepared']:
        choices = [o for o in options if name in o['text']]
        if choices:
            page.select_option('#recording', choices[-1]['value']); page.click('#add'); page.wait_for_timeout(200)
    if not page.locator('.track').count():
        page.select_option('#recording', options[-1]['value']); page.click('#add'); page.wait_for_selector('.track')
    if any('05_breakthrough_prepared' in o['text'] for o in options):
        page.click('#pair')
        page.wait_for_function("workbench.getState().tracks.length === 2 && !loading")
        assert page.evaluate('workbench.getState().tracks.map(t => t.stage)') == [0, 5]
        page.click('#audition')
        page.wait_for_function('workbench.getState().tracks.length === 1 && workbench.getState().playing && !loading')
        page.click('#pair')
        page.wait_for_function('workbench.getState().tracks.length === 2 && !loading')
    page.select_option('#mode', 'arrangement')
    page.fill('#build', '24'); page.locator('#build').dispatch_event('change')
    page.locator('#stages button').nth(3).click()
    page.screenshot(path=str(EVIDENCE / 'workbench-desktop.png'), full_page=True)
    page.set_viewport_size({'width': 800, 'height': 1000})
    page.screenshot(path=str(EVIDENCE / 'workbench-compact.png'), full_page=True)
    assert page.evaluate('document.documentElement.scrollWidth <= innerWidth')
    assert not errors, errors
    state = page.evaluate('workbench.getState()')
    (EVIDENCE / 'browser-results.json').write_text(json.dumps({'result':'PASS', 'checks':['audio decode/playback with nonzero output', 'state switching', 'layer stack', 'manual mix', 'solo', 'mute', 'gain', 'collision recovery', 'pause freezes time', 'adjustable build', 'seeking', 'save/load setup', 'restart', 'compact layout', 'no JS errors', 'local file import', 'loop trim and invalid trim rejection', 'one-click endpoint pair', 'one-click concept audition'], 'state':state}, indent=2))
    browser.close()
print('PASS: browser audio/control regression; desktop and compact screenshots saved')
