"""Full package UI/playback checks with isolated synthetic audio, no owner data writes."""
import json
import math
from pathlib import Path
import secrets
import struct
import tempfile
import threading
import wave
from http.server import ThreadingHTTPServer
from playwright.sync_api import sync_playwright
import serve
from workbench import Workbench

OUT = Path(__file__).resolve().parents[2] / 'docs/evidence/music-packages'
OUT.mkdir(parents=True, exist_ok=True)
checks = []

class QuietHandler(serve.Handler):
    def log_message(self, *_): pass

with tempfile.TemporaryDirectory() as folder:
    root = Path(folder); assets = root / 'build/music'; assets.mkdir(parents=True)
    jobs = []
    names = ['Low strings A', 'Low strings B', 'Rounded bass', 'Soft drums', 'Evening road A', 'Evening road B']
    for i, name in enumerate(names):
        path = assets / f'fixture-{i}.wav'
        with wave.open(str(path), 'wb') as audio:
            audio.setparams((1, 2, 24000, 24000, 'NONE', 'not compressed'))
            audio.writeframes(b''.join(struct.pack('<h', round(1200 * math.sin(2 * math.pi * (110 + i * 55) * s / 24000))) for s in range(24000)))
        jobs.append({'name': name, 'file': path.name, 'status': 'complete', 'state_index': min(i, 5), 'kind': 'synthetic test audio', 'metrics': {'duration': 1, 'sample_rate': 24000}})
    (assets / 'manifest.json').write_text(json.dumps({'jobs': jobs}))
    serve.ASSETS = assets
    service = Workbench(root, assets, serve.catalog)
    for i, name in enumerate(names): service.save({'id': f'fixture-{i}.wav', 'title': name, 'state_index': min(i, 5)})
    server = ThreadingHTTPServer(('127.0.0.1', 0), QuietHandler); server.token = secrets.token_urlsafe(32); server.workbench = service
    worker = threading.Thread(target=server.serve_forever, daemon=True); worker.start()
    url = f'http://127.0.0.1:{server.server_port}'
    try:
        with sync_playwright() as p:
            browser = p.chromium.launch(channel='msedge', headless=True, args=['--autoplay-policy=no-user-gesture-required'])
            page = browser.new_page(viewport={'width':1440, 'height':1080}); page.set_default_timeout(15000)
            errors = []; page.on('pageerror', lambda e: errors.append(str(e)))
            page.on('response', lambda r: print('HTTP ERROR', r.status, r.url, r.text(), flush=True) if r.status >= 400 and '/api/' in r.url else None)
            page.goto(url + '/states.html'); page.wait_for_selector('[data-state="5"]')
            page.fill('#stateCount', '8'); page.locator('#stateCount').dispatch_event('change')
            page.fill('[data-state="7"]', 'Finale'); page.click('#saveStates')
            page.wait_for_function('!document.getElementById("pageNotice").hidden')
            assert 'saved' in page.locator('#pageNotice').inner_text(), page.locator('#pageNotice').inner_text()
            assert len(service.snapshot()['states']) == 8
            page.goto(url + '/packages.html'); page.wait_for_function('library.states.length === 8')
            page.click('#newPackage'); page.fill('#packageName', 'Warm road ensemble')
            page.fill('#packageStateCount', '3'); page.locator('#packageStateCount').dispatch_event('change')
            for i, (name, pool) in enumerate([('Opening', [0, 1]), ('Momentum', [2]), ('Full band', [3])]):
                page.click(f'.pool-state[data-index="{i}"]'); page.fill('#poolName', name)
                for track in pool: page.check(f'#poolTracks input[value="fixture-{track}.wav"]')
            page.click('#savePackage'); page.wait_for_function('draft.id && !dirty')
            ensemble = page.evaluate('draft.id'); assert service.snapshot()['packages'][0]['ready']
            page.evaluate("scrollTo(0, 0)"); page.screenshot(path=str(OUT / 'package-editor-desktop.png'), full_page=True)
            checks.append('Eight configurable library states; independent named three-state package with saved pools')
            page.reload(); page.wait_for_function('library.packages.length === 1'); page.click(f'[data-package="{ensemble}"]')
            assert page.locator('#packageStateCount').input_value() == '3'
            assert page.evaluate('draft.states[0].pool.length') == 2
            page.click('#previewPackage'); page.wait_for_function('packageSnapshot !== undefined')
            assert page.locator('.sidebar').is_visible(); assert page.locator('.sidebar [aria-current="page"]').inner_text() == '≋Mix lab' or 'Mix lab' in page.locator('.sidebar [aria-current="page"]').inner_text()
            page.click('#packageDraw'); page.wait_for_function('currentPackageDraw !== null && !loading')
            assert page.evaluate('names') == ['Opening', 'Momentum', 'Full band']
            first = page.evaluate('currentPackageDraw.assets')
            assert page.locator('#add').is_disabled() and page.locator('#mode').is_disabled()
            assert page.locator('#tracks select').first.is_disabled()
            assert first[0] in ['fixture-0.wav', 'fixture-1.wav'] and first[1:] == ['fixture-2.wav', 'fixture-3.wav']
            page.uncheck('#advance'); page.click('#play')
            page.wait_for_function('workbench.getState().position > .2')
            page.wait_for_function('() => {analyser.getFloatTimeDomainData(meterData); return Math.max(...meterData.map(Math.abs)) > .0001}')
            page.locator('#stages button').nth(2).click(); assert page.evaluate('tracks.filter(t => t.target > 0).length') == 3
            page.click('#collision'); assert page.evaluate('tracks.filter(t => t.target > 0).length') == 1
            page.click('#restart'); assert page.evaluate('currentPackageDraw.assets') == first
            page.click('#play'); page.click('#packageDraw'); page.wait_for_function('!loading')
            assert page.evaluate('currentPackageDraw.assets') != first
            page.evaluate("scrollTo(0, 0)"); page.screenshot(path=str(OUT / 'mix-lab-sidebar.png'), full_page=True)
            checks.append('Layer package: nonzero audio, cumulative states, collision/restart preserve draw, New drive varies within pools')
            page.click('#editPackage'); page.wait_for_function('draft !== null')
            page.check('[name=packageMode][value=arrangement]'); page.click('#savePackage'); page.wait_for_function('!dirty')
            page.click('#previewPackage'); page.wait_for_function('packageSnapshot !== undefined'); page.click('#packageDraw'); page.wait_for_function('currentPackageDraw && !loading')
            for stage in range(3):
                page.locator('#stages button').nth(stage).click()
                assert page.evaluate('tracks.filter(t => t.target > 0).map(t => t.stage)') == [stage]
            checks.append('Switch-tracks mode activates exactly the selected state')
            page.click('#leavePackage'); assert not page.locator('#add').is_disabled()
            page.fill('#labStateCount', '1'); page.locator('#labStateCount').dispatch_event('change')
            assert page.evaluate('stageAt(999)') == 0
            page.fill('#labStateCount', '9'); page.locator('#labStateCount').dispatch_event('change')
            page.locator('#stages button').nth(8).click(); assert page.evaluate('stageAt(streak)') == 8
            with page.expect_download() as event: page.click('#save')
            setup = OUT / 'nine-state-setup.json'; event.value.save_as(str(setup))
            assert len(json.loads(setup.read_text())['states']) == 9
            page.set_input_files('#load', str(setup)); page.wait_for_function('names.length === 9 && tracks.length === 3')
            checks.append('One and nine state auditions; exported setup restores custom states')
            page.goto(url + '/packages.html'); page.wait_for_function('library.packages.length === 1'); page.click('#newPackage')
            page.fill('#packageName', 'Evening road'); page.fill('#packageStateCount', '1'); page.locator('#packageStateCount').dispatch_event('change')
            page.check('[name=packageMode][value=arrangement]'); page.check('#poolTracks input[value="fixture-4.wav"]'); page.check('#poolTracks input[value="fixture-5.wav"]')
            page.click('#savePackage'); page.wait_for_function('draft.id && !dirty'); evening = page.evaluate('draft.id')
            page.click('#previewPackage'); page.wait_for_function('packageSnapshot !== undefined'); page.select_option('#packageSelect', '*')
            page.evaluate('() => { crypto.getRandomValues = values => values.fill(1); }')
            page.click('#packageDraw'); page.wait_for_function('currentPackageDraw && !loading')
            assert page.evaluate('currentPackageDraw.package') == evening
            assert page.evaluate('currentPackageDraw.assets.every(a => ["fixture-4.wav", "fixture-5.wav"].includes(a))')
            checks.append('Random selection chooses a package first and never draws from another package')
            page.goto(url + '/#library'); page.wait_for_function('connected'); page.locator('#libraryList').get_by_role('button', name='Rounded bass').click()
            page.click('#deleteTrack'); assert page.locator('#deleteDialog').is_visible(); assert '1 soundtrack package' in page.locator('#deleteImpact').inner_text()
            page.click('#confirmDelete'); page.wait_for_function('data.trash.length === 1')
            assert not service.snapshot()['packages'][0]['ready']
            page.click('#trashSource'); page.locator('#libraryList').get_by_role('button', name='Rounded bass').click()
            page.evaluate("scrollTo(0, 0)"); page.screenshot(path=str(OUT / 'library-trash.png'), full_page=True)
            page.click('#restoreTrack'); page.wait_for_function('data.trash.length === 0')
            assert not service.snapshot()['packages'][0]['ready']
            checks.append('Saved-track delete confirms pool impact, removes references, and restores from Trash without reintroducing pools')
            page.goto(url + f'/lab.html?package={ensemble}'); page.wait_for_function('packageSnapshot !== undefined'); page.click('#packageDraw')
            page.wait_for_selector('#packageError:not([hidden])'); assert 'Momentum' in page.locator('#packageError').inner_text()
            assert page.evaluate('tracks.length') == 0
            page.goto(url + f'/packages.html?package={ensemble}'); page.wait_for_function('draft !== null')
            page.click('.pool-state[data-index="1"]'); page.check('#poolTracks input[value="fixture-2.wav"]'); page.click('#savePackage'); page.wait_for_function('!dirty')
            checks.append('An empty pool blocks playback until repaired in package editor')
            page.set_viewport_size({'width':390, 'height':844}); page.screenshot(path=str(OUT / 'package-editor-mobile.png'), full_page=True)
            assert page.evaluate('document.documentElement.scrollWidth <= innerWidth')
            page.click('#previewPackage'); page.wait_for_function('packageSnapshot !== undefined'); page.click('#packageDraw'); page.wait_for_function('currentPackageDraw && !loading')
            page.evaluate("scrollTo(0, 0)"); page.screenshot(path=str(OUT / 'mix-lab-mobile.png'), full_page=True)
            assert page.evaluate('document.documentElement.scrollWidth <= innerWidth')
            checks.append('390px package editor and Mix lab: shared navigation and no horizontal overflow')
            page.goto(url + '/states.html'); page.wait_for_selector('[data-state="7"]'); page.fill('#stateCount', '2'); page.locator('#stateCount').dispatch_event('change'); page.click('#saveStates')
            page.wait_for_function('document.getElementById("pageNotice").textContent.includes("saved")')
            assert len(service.snapshot()['packages'][0]['states']) == 3
            assert next(t for t in service.snapshot()['tracks'] if t['id'] == 'fixture-5.wav')['state_index'] is None
            checks.append('Reducing library states unassigns affected tracks without changing package states')
            page.goto(url + f'/packages.html?package={evening}'); page.wait_for_function('draft !== null'); page.click('#deletePackage'); page.click('#confirmPackageDelete'); page.wait_for_function('library.packages.length === 1')
            assert len(service.snapshot()['tracks']) == 6
            checks.append('Deleting a package preserves saved recordings')
            assert not errors, errors; checks.append('No browser JavaScript errors')
            (OUT / 'browser-results.json').write_text(json.dumps({'checks': checks, 'audio': 'isolated synthetic sine fixtures', 'errors': errors}, indent=2))
            print(f'PASS: {len(checks)} package browser groups', flush=True)
            browser.close()
    finally:
        server.shutdown(); server.server_close(); worker.join(); service.file_lock.close()
