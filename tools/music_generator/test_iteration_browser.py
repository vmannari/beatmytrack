"""R2 bank selection and stable per-drive variation, with actual Web Audio."""
from pathlib import Path
import json
from playwright.sync_api import sync_playwright

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'docs/evidence/music-r2'
OUT.mkdir(parents=True, exist_ok=True)
with sync_playwright() as p:
    browser = p.chromium.launch(channel='msedge', headless=True, args=['--autoplay-policy=no-user-gesture-required'])
    page = browser.new_page(viewport={'width':1440, 'height':1000})
    errors=[]
    page.on('pageerror', lambda e: errors.append(str(e)))
    page.goto('http://127.0.0.1:18765')
    page.locator('[data-r2="1"]').click()
    page.wait_for_function('workbench.getState().tracks.length === 6 && !loading')
    assert page.evaluate('tracks.every(t => t.asset.endsWith("01.wav"))')
    assert page.evaluate('tracks.map(t => t.stage)') == list(range(6))
    page.locator('[data-r2="2"]').click()
    page.wait_for_function('tracks.length === 6 && tracks.every(t => t.asset.endsWith("02.wav")) && !loading')
    page.locator('[data-r2="0"]').click()
    page.wait_for_function('!loading && tracks.length === 6')
    selected=page.evaluate('tracks.map(t => t.asset)')
    assert len(set(selected)) == 6
    assert page.evaluate('tracks.every(t => t.asset.includes("reference-arc-r2-"))')
    page.click('#play')
    page.wait_for_function('workbench.getState().position > .3')
    page.wait_for_function('() => {analyser.getFloatTimeDomainData(meterData); return Math.max(...meterData.map(Math.abs)) > .00001}')
    for stage in range(6):
        page.locator('#stages button').nth(stage).click()
        assert page.evaluate('tracks.filter(t => t.target > 0).map(t => t.stage)') == [stage]
    page.click('#collision')
    assert page.evaluate('tracks.map(t => t.asset)') == selected
    assert page.evaluate('tracks.filter(t => t.target > 0).map(t => t.stage)') == [0]
    page.click('#play')
    # Force the random source to repeat the previous choice to verify fallback.
    page.evaluate('''() => {
      const prior=previousR2.slice();
      crypto.getRandomValues = values => { prior.forEach((v,i) => values[i]=v-1); return values; };
    }''')
    page.locator('[data-r2="0"]').click()
    page.wait_for_function('!loading && tracks.length === 6')
    assert page.evaluate('tracks.map(t => t.asset)') != selected
    page.locator('#stages button').nth(4).click()
    page.screenshot(path=str(OUT/'workbench-r2.png'), full_page=True)
    assert not errors, errors
    (OUT/'browser-results.json').write_text(json.dumps({'result':'PASS',
        'checks':['six-stage A selection','six-stage B selection','one choice per stage',
        'actual nonzero playback','all six stage switches','choices survive collision',
        'collision returns to Focus','forced identical draw changes one choice','no JS errors'],
        'selection':page.evaluate('tracks.map(t => t.asset)')},indent=2))
    browser.close()
print('PASS: R2 selection/playback regression (9 checks)')
