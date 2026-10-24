"""Browser acceptance for the chosen challenge-card direction; no live services."""
from pathlib import Path
import json
from playwright.sync_api import sync_playwright, expect

HERE = Path(__file__).resolve().parent
OUT = HERE / 'evidence' / 'challenge-cards-refinement-2026-10-23'
OUT.mkdir(parents=True, exist_ok=True)


def act(page, action, value=None):
    selector = f'[data-action="{action}"]'
    if value is not None:
        selector += f'[data-value="{value}"]'
    page.locator(selector).click()


def capture(page, name):
    page.wait_for_timeout(230)
    page.screenshot(path=str(OUT / name), full_page=True)


def main():
    checks, errors, requests, geometry = [], [], [], []
    with sync_playwright() as p:
        browser = p.chromium.launch(headless=True, executable_path='C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe')
        page = browser.new_page(viewport={'width':1440,'height':1080})
        page.on('pageerror', lambda e: errors.append(str(e)))
        page.on('request', lambda r: requests.append(r.url) if r.url.startswith(('http:', 'https:')) else None)
        page.goto((HERE / 'challenge-cards.html').as_uri(), wait_until='load')
        expect(page.locator('.rc-heading h1')).to_have_text('CHOOSE YOUR CHALLENGE.')
        expect(page.locator('.rc-card-copy h2')).to_have_text(['Head to head','Group race','Three tries'])
        expect(page.locator('#game input, #game select, #game textarea')).to_have_count(0)
        expect(page.locator('.rc-ticket-target strong')).to_have_text('01:23.407')
        expect(page.locator('[data-action="cc-primary"]')).to_contain_text('Create & share')
        capture(page, '01-head-to-head-1440.png')
        checks.append('Direct entry defaults to renamed, refined cards with exact race and no mandatory form fields')

        act(page,'cc-rules')
        act(page,'cc-duration','3 days')
        page.locator('.rc-optional-name summary').click()
        page.locator('#rc-name').fill('Friday night grid')
        act(page,'cc-rules-save')
        identity=page.evaluate('JSON.stringify(challengeLab.result)')
        for key,kind,tries in [('weekend','Group challenge','Unlimited'),('shots','Group challenge','3'),('duel','Beat my time','Unlimited')]:
            act(page,'cc-preset',key)
            draft=page.evaluate('challengeLab.draft')
            assert (draft['kind'],draft['duration'],draft['tries'],draft['name']) == (kind,'3 days',tries,'Friday night grid')
            assert page.evaluate('JSON.stringify(challengeLab.result)') == identity
            expect(page.locator('.rc-card.active')).to_have_attribute('data-value',key)
        checks.append('Switching formats preserves chosen duration, personal title and completed race identity')

        act(page,'cc-preset','shots')
        expect(page.locator('.rc-tweak-row')).to_contain_text('Each start uses a try, including restarts.')
        capture(page,'02-three-tries-1440.png')
        before=page.evaluate('JSON.stringify(challengeLab.draft)')
        act(page,'cc-rules')
        act(page,'cc-duration','24 hours')
        act(page,'cc-tries','5')
        page.locator('.rc-optional-name summary').click()
        page.locator('#rc-name').fill('Cancelled name')
        for _ in range(20):
            page.keyboard.press('Tab')
            assert page.get_by_role('dialog').evaluate('(d)=>d.contains(document.activeElement)')
        page.keyboard.press('Escape')
        assert page.evaluate('JSON.stringify(challengeLab.draft)') == before
        checks.append('Optional rule/title changes cancel together and keyboard focus remains in the dialog')

        act(page,'cc-rules')
        act(page,'cc-tries','5')
        act(page,'cc-rules-save')
        expect(page.locator('.rc-card.active')).to_have_attribute('data-value','weekend')
        expect(page.locator('.rc-card.active')).to_contain_text('5 tries each')
        act(page,'cc-preset','duel')
        act(page,'cc-rules')
        act(page,'cc-tries','1')
        expect(page.locator('#cc-rule-summary')).to_contain_text('including restarts')
        capture(page,'03-optional-rules-1440.png')
        act(page,'cc-rules-save')
        expect(page.locator('.rc-card.active')).to_have_attribute('data-value','duel')
        expect(page.locator('.rc-card.active')).to_contain_text('1 try each')
        checks.append('Custom group and duel try limits retain an accurate selected card and visible restart rule')

        page.evaluate("state.completedSampleResult={track:4,car:3,time:'01:28.900',raceId:'exact-slower-finish'}; state.track=0; state.selectedCar=0")
        act(page,'cc-context','result')
        expect(page.locator('.rc-ticket-target strong')).to_have_text('01:28.900')
        expect(page.locator('.rc-ticket-details')).to_contain_text('Riverside')
        expect(page.locator('.rc-ticket-details')).to_contain_text('FORMULA / 04')
        expect(page.locator('#game [data-action="cc-track"], #game [data-action="cc-car"]')).to_have_count(0)
        page.evaluate("actions['cc-pick-track']('1'); actions['cc-pick-car']('1')")
        act(page,'cc-primary')
        expect(page.get_by_role('dialog')).to_contain_text('Your challenge is ready.')
        expect(page.locator('.ready-time')).to_have_text('01:28.900')
        expect(page.locator('.dialog-actions .primary')).to_have_attribute('data-action','cc-copy')
        created=page.evaluate('challengeLab.lastCreated')
        assert (created['track'],created['car'],created['time'],created['raceId']) == (4,3,'01:28.900','exact-slower-finish')
        capture(page,'04-ready-to-share-1440.png')
        page.evaluate("Object.defineProperty(navigator,'clipboard',{configurable:true,value:{writeText:()=>Promise.reject(new Error('Isolated fallback test'))}})")
        act(page,'cc-copy')
        expect(page.locator('.challenge-share-text')).to_contain_text('01:28.900')
        expect(page.locator('.challenge-share-text')).to_contain_text('including restarts')
        expect(page.locator('.challenge-share-text')).to_contain_text('Local design prototype invitation')
        act(page,'cc-ready')
        act(page,'created-challenges')
        expect(page.locator('.challenge-detail')).to_contain_text('01:28.900')
        checks.append('Exact slower finish reaches sharing and created challenges; copy fallback stays clearly marked and uses no system clipboard')

        act(page,'challenge-create')
        act(page,'cc-context','menu')
        assert page.evaluate('challengeLab.result') is None
        expect(page.locator('.rc-ticket-target')).not_to_contain_text('01:28.900')
        act(page,'cc-track')
        expect(page.get_by_role('dialog')).to_contain_text('Choose your circuit.')
        act(page,'cc-pick-track','1')
        act(page,'cc-car')
        act(page,'cc-pick-car','2')
        act(page,'cc-preset','shots')
        act(page,'cc-rules')
        act(page,'cc-duration','24 hours')
        act(page,'cc-rules-save')
        expect(page.locator('.rc-ticket-details')).to_contain_text('Dust Cloud')
        expect(page.locator('.rc-ticket-details')).to_contain_text('REARSPORT / 03')
        # Every card's backdrop uses the selected circuit theme, not a different track.
        art=page.locator('.rc-card-art .scene-art').evaluate_all('(els)=>els.map(e=>e.outerHTML)')
        assert len(art)==3 and len(set(art))==1,art
        capture(page,'05-menu-entry-1440.png')
        act(page,'cc-primary')
        if page.get_by_role('dialog').is_visible():
            act(page,'begin-race')
        expect(page.locator('#race-time')).to_be_visible()
        act(page,'finish-race')
        expect(page.locator('.result-time')).to_have_text('01:23.407')
        expect(page.locator('.results-bottom .primary')).to_contain_text('Race again')
        act(page,'cc-after-race')
        expect(page.locator('.ready-invite')).to_contain_text('24 hours · 3 tries per driver')
        assert page.evaluate('challengeLab.lastCreated.track')==1
        assert page.evaluate('challengeLab.lastCreated.car')==2
        act(page,'close')
        checks.append('Menu flow chooses circuit/car directly, retains format through racing, and shows normal results before sharing')

        page.evaluate("navigate('challenge-create')")
        for width,height in [(1440,1080),(1280,900),(960,720),(744,480),(390,844),(844,390)]:
            page.set_viewport_size({'width':width,'height':height})
            for context in ['menu','result']:
                act(page,'cc-context',context)
                for key in ['duel','weekend','shots']:
                    act(page,'cc-preset',key)
                    bounds=page.evaluate('''()=>({doc:document.documentElement.scrollWidth,viewport:innerWidth,cards:[...document.querySelectorAll('.rc-card')].map(e=>e.getBoundingClientRect().toJSON())})''')
                    assert bounds['doc']<=width+1, bounds
                    assert all(c['width']>90 and c['left']>=0 and c['right']<=width+1 for c in bounds['cards']), bounds
                    page.locator('[data-action="cc-primary"]').scroll_into_view_if_needed()
                    expect(page.locator('[data-action="cc-primary"]')).to_be_in_viewport()
                    geometry.append({'width':width,'height':height,'context':context,'format':key,'overflow':False})
                if context=='result' and width in [1280,960,390,844]:
                    capture(page,f'06-refined-result-{width}.png')
        checks.append('36 format/context/viewport combinations fit width; primary action remains reachable')

        page.set_viewport_size({'width':1440,'height':1080})
        act(page,'rc-revision','earlier')
        expect(page.locator('.showdown-intro')).to_contain_text('SHOWDOWN.')
        act(page,'rc-revision','refined')
        expect(page.locator('.rc-heading h1')).to_have_text('CHOOSE YOUR CHALLENGE.')
        act(page,'rc-compare')
        act(page,'cc-variant','drive')
        expect(page.locator('.creation-page')).to_have_attribute('data-concept','drive')
        act(page,'cc-variant','showdown')
        expect(page.locator('.rc-heading h1')).to_have_text('CHOOSE YOUR CHALLENGE.')
        checks.append('Earlier cards and the original A/B/C comparison remain accessible')
        assert not errors, errors
        assert not requests, requests
        checks.append('No browser errors or external network requests')
        browser.close()
    report={'date':'2026-10-23','status':'passed','check_count':len(checks),'checks':checks,'geometry':geometry,'browser_errors':errors,'external_requests':requests,'physical_device_test':False}
    (OUT / 'browser-checks.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
    print(json.dumps({k:v for k,v in report.items() if k!='geometry'},indent=2))


if __name__=='__main__':
    main()
