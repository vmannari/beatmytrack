"""Read-only live Studio browser acceptance; screenshot identities are masked."""
import importlib.util
import json
from datetime import datetime, timezone
from pathlib import Path

from playwright.sync_api import expect, sync_playwright

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('studio_rollout', ROOT / '.tools/backend_studio_rollout_20261011.py')
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
origin = module.receipt['url']
resource = module.service.describe('api', module.service.n['api'])
assert module.stage.resource_image(resource) == module.receipt['image']
role, key = module.read_staff(resource)
checks = []
with sync_playwright() as playwright:
    browser = playwright.chromium.launch(headless=True,
        executable_path='C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe')
    page = browser.new_page(viewport={'width': 1440, 'height': 900})
    errors = []
    writes = []
    page.on('pageerror', lambda error: errors.append(str(error)))
    page.on('request', lambda request: writes.append(request.url)
            if request.method != 'GET' and '/v1/admin/' in request.url else None)
    page.goto(origin + '/admin#studio')
    page.fill('#key', key)
    page.locator('#login button').click()
    expect(page.get_by_role('heading', name='Data coverage', exact=True)).to_be_visible()
    expect(page.locator('#main')).to_contain_text('Unavailable')
    page.screenshot(path=str(module.OUTPUT / 'live-coverage.png'), full_page=True, animations='disabled')
    checks.append('Configured staff role loads deployed coverage and explicit missing sources')
    page.evaluate("location.hash='players?all=1'")
    expect(page.locator('#filters')).to_be_visible()
    expect(page.get_by_role('columnheader', name='Player type', exact=True)).to_be_visible()
    types = page.locator('#main tbody tr td:nth-child(3)').all_text_contents()
    assert types and all(value in ('Real', 'Artificial') for value in types)
    assert not page.locator('#command').count()
    mask = page.add_style_tag(content='''#main tbody td:nth-child(1),#main tbody td:nth-child(2){font-size:0!important;color:transparent!important}#main tbody td:nth-child(1)::after{content:"Player identity withheld";font-size:11px;color:#657986}#main tbody td:nth-child(2)::after{content:"Withheld";font-size:11px;color:#657986}''')
    page.screenshot(path=str(module.OUTPUT / 'live-players-redacted.png'), full_page=True, animations='disabled')
    mask.evaluate('(node)=>node.remove()')
    checks.append('Live player rows show stored class with identities masked in evidence')
    page.evaluate("location.hash='races?state=verified&all=1'")
    expect(page.locator('#filters')).to_be_visible()
    row = page.locator('#main tbody tr a[href^="#races/"]').first
    if row.count():
        row.click()
        expect(page.locator('#studio-export')).to_be_visible()
        expect(page.locator('#studio-time')).not_to_have_text('Unavailable')
        assert page.locator('#studio-lap-times tbody tr').count() == 5
        checks.append('Live verified race resolves accepted pinned timing and five stored laps')
    page.locator('#logout').click()
    expect(page.locator('#login')).to_be_visible()
    assert page.locator('#key').input_value() == ''
    assert not page.evaluate('Object.keys(localStorage).length + Object.keys(sessionStorage).length')
    assert not errors and not writes
    checks.append('Lock clears access; no admin writes, browser exceptions or stored credentials')
    browser.close()
report = {'observed_at': datetime.now(timezone.utc).isoformat(), 'url': origin,
          'read_only': True, 'role': role, 'checks': checks,
          'failures': 0, 'javascript_errors': 0, 'admin_writes': 0,
          'published_player_identities': False}
(module.OUTPUT / 'live-browser.json').write_text(json.dumps(report, indent=2) + '\n')
print(json.dumps(report, indent=2))
