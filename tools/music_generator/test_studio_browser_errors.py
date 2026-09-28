"""Browser failure/reconnect checks; API failures are simulated, no GPU work."""
import json
from pathlib import Path
from playwright.sync_api import sync_playwright

OUT = Path(__file__).resolve().parents[2] / 'docs/evidence/music-studio'
with sync_playwright() as p:
    browser = p.chromium.launch(channel='msedge', headless=True)
    page = browser.new_page(viewport={'width': 1440, 'height': 1000})
    errors = []; page.on('pageerror', lambda error: errors.append(str(error)))
    offline = False
    snapshot = {'token': 'fixture', 'tracks': [], 'jobs': []}
    def respond(route):
        if offline: route.abort()
        else: route.fulfill(json=snapshot)
    page.route('**/api/workbench', respond)
    page.route('**/api/generate', lambda route: route.fulfill(status=409, json={'error': 'Another Magenta job is using the GPU. Wait for it to finish and retry.'}))
    page.goto('http://127.0.0.1:18765')
    page.wait_for_function('connected')
    page.click('[data-preset="calm"]'); page.click('#generate')
    page.wait_for_selector('#formError:not([hidden])')
    assert 'using the GPU' in page.locator('#formError').inner_text()
    assert not page.locator('#generate').is_disabled()
    assert 'Low sustained cello' in page.locator('#prompt').input_value()
    snapshot['jobs'] = [{'id': 'simulated-failure', 'title': '<img src=x onerror=alert(1)>', 'prompt': 'Quiet piano', 'duration': 16,
        'state_index': 1, 'status': 'failed', 'error': 'Simulated renderer failure: CUDA unavailable', 'created': 0}]
    page.wait_for_selector('#failurePanel:not([hidden])')
    assert page.locator('#inboxList img').count() == 0
    page.get_by_role('button', name='Use this prompt').click()
    assert page.locator('#prompt').input_value() == 'Quiet piano'
    assert page.locator('#duration').input_value() == '16'
    assert page.locator('#targetState').input_value() == '1'
    page.locator('#failurePanel summary').click()
    page.screenshot(path=str(OUT / 'simulated-generation-failure.png'), full_page=True)
    offline = True
    page.wait_for_selector('#connectionError:not([hidden])')
    assert page.locator('#generate').is_disabled()
    offline = False
    page.wait_for_function('connected && document.getElementById("connectionError").hidden')
    assert not page.locator('#generate').is_disabled()
    assert not errors, errors
    results = ['Actionable generation error; prompt retained; retry enabled', 'Failed job exposes details and refills prompt/settings',
               'HTML-like track titles are inert text', 'Connection loss disables generation; reconnect restores it', 'No JS errors']
    (OUT / 'browser-failure-results.json').write_text(json.dumps(results, indent=2))
    print('PASS: five browser failure/reconnection checks (simulated API failures)')
    browser.close()
