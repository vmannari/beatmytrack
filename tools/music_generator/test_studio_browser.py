"""Opt-in real GPU/UI acceptance. Creates one four-second take and saves it."""
import json
from pathlib import Path
import time
from playwright.sync_api import sync_playwright

ROOT = Path(__file__).resolve().parents[2]
EVIDENCE = ROOT / 'docs/evidence/music-studio'
EVIDENCE.mkdir(parents=True, exist_ok=True)
checks = []
with sync_playwright() as p:
    browser = p.chromium.launch(channel='msedge', headless=True, args=['--autoplay-policy=no-user-gesture-required'])
    page = browser.new_page(viewport={'width': 1440, 'height': 1080})
    page.set_default_timeout(30000)
    errors = []; page.on('pageerror', lambda error: errors.append(str(error)))
    page.goto('http://127.0.0.1:18765')
    page.wait_for_function('connected')
    page.screenshot(path=str(EVIDENCE / 'create-empty.png'), full_page=True)
    page.click('[data-preset="calm"]')
    page.fill('#trackTitle', 'Studio check · low strings')
    page.select_option('#duration', '4')
    page.click('#generate')
    page.wait_for_selector('#generationProgress:not([hidden])')
    page.screenshot(path=str(EVIDENCE / 'generating.png'), full_page=True)
    checks.append('Prompt submitted from the UI; progress displayed')
    page.reload(); page.wait_for_function('connected && selected !== null')
    assert page.locator('#generate').is_disabled()
    checks.append('Reload resumes the active job; duplicate generation disabled')
    started = time.monotonic()
    while time.monotonic() - started < 900:
        status = page.evaluate('selectedValue().job?.status')
        if status in ('ready', 'failed'): break
        page.wait_for_timeout(2000)
    assert status == 'ready', page.evaluate('selectedValue().job')
    page.wait_for_function('waveform.length > 0')
    page.click('#detailPlay'); page.wait_for_function('audio.currentTime > .4')
    assert page.evaluate('waveform.some(x => x > .001)')
    page.click('#detailPlay'); assert page.evaluate('audio.paused')
    checks.append('Actual Magenta WAV generated, decoded nonzero waveform, played and paused')
    page.locator('#seek').fill('1'); page.locator('#seek').dispatch_event('input')
    assert page.evaluate('Math.abs(audio.currentTime - 1) < .1')
    page.click('#loop'); assert page.evaluate('audio.loop')
    checks.append('Seek and loop work')
    page.screenshot(path=str(EVIDENCE / 'take-ready.png'), full_page=True)
    job_id = page.evaluate('selected.id')
    page.click('#discard'); page.wait_for_function('selected === null')
    page.click('#toggleDiscarded'); page.get_by_role('button', name='Studio check · low strings').click()
    page.click('#discard'); page.wait_for_function('selectedValue().job.status === "ready"')
    checks.append('Discard hides the take; discarded list restores it')
    page.select_option('#saveState', '3'); page.click('#saveTrack')
    page.wait_for_function('selectedValue().job.status === "saved"')
    page.click('[data-view="library"]')
    page.locator('#libraryList').get_by_role('button', name='Studio check · low strings').last.click()
    page.fill('#saveTitle', 'Studio check · saved take'); page.select_option('#saveState', '5'); page.click('#saveTrack')
    page.wait_for_function('data.tracks.some(t => t.title === "Studio check · saved take" && t.state_index === 5)')
    page.reload(); page.wait_for_function('connected')
    page.locator('#libraryList').get_by_role('button', name='Studio check · saved take').last.click()
    assert page.locator('#saveState').input_value() == '5'
    page.select_option('#saveState', ''); page.click('#saveTrack')
    page.wait_for_function('data.tracks.some(t => t.title === "Studio check · saved take" && t.state_index === null)')
    assert page.locator('#saveState').input_value() == ''
    page.select_option('#saveState', '0'); page.click('#saveTrack')
    page.wait_for_function('data.tracks.some(t => t.title === "Studio check · saved take" && t.state_index === 0)')
    checks.append('Save, rename, reassign, clear state, and reload retain disk-backed metadata')
    page.fill('#search', 'does not exist'); assert page.locator('#libraryList .recording-row').count() == 0
    page.fill('#search', 'saved take'); assert page.locator('#libraryList .recording-row').count() == 1
    page.select_option('#stateFilter', '5'); assert page.locator('#libraryList .recording-row').count() == 0
    page.select_option('#stateFilter', '0'); assert page.locator('#libraryList .recording-row').count() == 1
    checks.append('Library search and musical-state filters')
    page.wait_for_function('waveform.length > 0')
    page.screenshot(path=str(EVIDENCE / 'library-desktop.png'), full_page=True)
    page.set_viewport_size({'width': 390, 'height': 844})
    page.screenshot(path=str(EVIDENCE / 'library-mobile.png'), full_page=True)
    assert page.evaluate('document.documentElement.scrollWidth <= innerWidth')
    page.click('[data-view="create"]')
    page.screenshot(path=str(EVIDENCE / 'create-mobile.png'), full_page=True)
    assert page.evaluate('document.documentElement.scrollWidth <= innerWidth')
    checks.append('390px create/library layouts have no horizontal overflow')
    page.set_viewport_size({'width': 1440, 'height': 1080})
    page.goto('http://127.0.0.1:18765/lab.html')
    page.wait_for_function('catalog.some(t => t.title === "Studio check · saved take")')
    asset = page.evaluate('catalog.find(t => t.title === "Studio check · saved take").id')
    page.select_option('#recording', asset); page.click('#add')
    page.wait_for_function('tracks.length === 1')
    assert page.evaluate('tracks[0].stage') == 0
    page.screenshot(path=str(EVIDENCE / 'mix-lab.png'), full_page=True)
    checks.append('Saved title and state available in Mix lab')
    assert not errors, errors
    checks.append('No browser JavaScript errors')
    (EVIDENCE / 'browser-results.json').write_text(json.dumps({'checks': checks, 'job_id': job_id, 'errors': errors}, indent=2))
    print(json.dumps(checks, indent=2), flush=True)
    browser.close()
