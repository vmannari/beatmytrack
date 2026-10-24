"""Exercise three isolated challenge-creation proposals with a real local browser."""
from pathlib import Path
import json
import re
from playwright.sync_api import sync_playwright, expect

HERE = Path(__file__).resolve().parent
OUT = HERE / 'evidence' / 'challenge-concepts-2026-10-23'
OUT.mkdir(parents=True, exist_ok=True)
checks = []
errors = []
requests = []


def act(page, action, value=None):
    query = f'[data-action="{action}"]'
    if value is not None:
        query += f'[data-value="{value}"]'
    page.locator(query).click()


def finish_sample(page):
    if page.get_by_role('dialog').is_visible():
        act(page, 'begin-race')
    expect(page.locator('#race-time')).to_be_visible()
    act(page, 'finish-race')
    expect(page.locator('.result-time')).to_have_text('01:23.407')
    expect(page.locator('.results-bottom .primary')).to_contain_text('Race again')


def main():
    with sync_playwright() as p:
        browser = p.chromium.launch(headless=True, executable_path='C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe')
        page = browser.new_page(viewport={'width':1440,'height':1080})
        page.on('pageerror', lambda error: errors.append(str(error)))
        page.on('request', lambda req: requests.append(req.url) if req.url.startswith(('http:', 'https:')) else None)
        page.goto((HERE / 'challenge-concepts.html').as_uri(), wait_until='load')
        expect(page.locator('.creation-page')).to_be_visible()
        expect(page.locator('#challenge-review')).to_be_visible()
        for variant in ['invitation','showdown','drive']:
            act(page, 'cc-variant', variant)
            expect(page.locator('.creation-page')).to_have_attribute('data-concept',variant)
            expect(page.locator('#game input, #game select, #game textarea')).to_have_count(0)
            expect(page.locator('.creation-page')).to_contain_text('01:23.407')
            page.wait_for_timeout(220)
            page.screenshot(path=str(OUT / f'{variant}-result-1440.png'),full_page=True)
        checks.append('Three distinct entry views open directly and require no text field or dropdown')

        act(page, 'cc-variant', 'invitation')
        act(page, 'cc-context', 'menu')
        act(page, 'cc-track')
        act(page, 'cc-pick-track', '1')
        act(page, 'cc-car')
        act(page, 'cc-pick-car', '2')
        act(page, 'cc-kind', 'Group challenge')
        act(page, 'cc-rules')
        act(page, 'cc-duration', '3 days')
        act(page, 'cc-tries', '3')
        for _ in range(15):
            page.keyboard.press('Tab')
            assert page.get_by_role('dialog').evaluate('(dialog)=>dialog.contains(document.activeElement)')
        act(page, 'cc-rules-save')
        act(page, 'cc-rename')
        page.locator('#cc-name').fill('Friday dare')
        page.keyboard.press('Enter')
        expect(page.locator('.creation-page')).to_contain_text('Friday dare')
        expect(page.locator('.poster-track')).to_contain_text('DUST CLOUD')
        expect(page.locator('.poster-track')).to_contain_text('REARSPORT / 03')
        assert page.evaluate('challengeLab.result') is None
        act(page, 'cc-primary')
        finish_sample(page)
        act(page, 'cc-after-race')
        expect(page.get_by_role('dialog')).to_contain_text('Friday dare')
        expect(page.locator('.ready-invite')).to_contain_text('3 days · 3 tries per driver')
        expect(page.locator('.ready-invite')).to_contain_text('REARSPORT / 03')
        expect(page.locator('.ready-invite')).to_contain_text('01:23.407')
        created=page.evaluate('challengeLab.lastCreated')
        assert (created['track'],created['car'],created['kind']) == (1,2,'Group challenge')
        act(page, 'created-challenges')
        expect(page.locator('.challenge-detail')).to_contain_text('Friday dare')
        checks.append('Invitation path: choose circuit and car, audience, optional rules and name, then race and create')
        checks.append('Rules keep keyboard focus inside the dialog and preserve chosen limits')

        act(page, 'challenge-create')
        act(page, 'cc-context', 'result')
        act(page, 'cc-variant', 'showdown')
        act(page, 'rc-revision', 'earlier')
        pinned=page.evaluate('JSON.stringify(challengeLab.result)')
        for key,kind,duration,tries in [
            ('duel','Beat my time','7 days','Unlimited'),
            ('weekend','Group challenge','3 days','Unlimited'),
            ('shots','Group challenge','24 hours','3'),
        ]:
            act(page,'cc-preset',key)
            draft=page.evaluate('challengeLab.draft')
            assert (draft['kind'],draft['duration'],draft['tries']) == (kind,duration,tries)
            assert page.evaluate('JSON.stringify(challengeLab.result)') == pinned
        before_rules=page.evaluate('JSON.stringify(challengeLab.draft)')
        act(page,'cc-rules')
        act(page,'cc-duration','7 days')
        page.keyboard.press('Escape')
        assert page.evaluate('JSON.stringify(challengeLab.draft)') == before_rules
        act(page,'cc-primary')
        expect(page.locator('.ready-invite')).to_contain_text('24 hours · 3 tries per driver')
        act(page,'close')
        checks.append('Earlier card comparison retains its original presets; cancelled rule changes stay uncommitted')
        act(page,'rc-revision','refined')

        act(page,'cc-variant','drive')
        act(page,'cc-context','menu')
        expect(page.locator('.creation-page')).not_to_contain_text('01:23.407')
        expect(page.locator('[data-action="cc-rules"]')).to_have_count(0)
        act(page,'cc-setup')
        act(page,'cc-track')
        act(page,'cc-pick-track','3')
        act(page,'cc-setup')
        act(page,'cc-car')
        act(page,'cc-pick-car','1')
        act(page,'cc-primary')
        finish_sample(page)
        act(page,'cc-after-race')
        expect(page.locator('.creation-page')).to_have_attribute('data-concept','drive')
        expect(page.locator('.drive-first-result')).to_contain_text('01:23.407')
        expect(page.locator('.drive-first-details')).to_contain_text('Night Shift')
        expect(page.locator('.drive-first-details')).to_contain_text('HAULER / 02')
        act(page,'cc-kind','Group challenge')
        act(page,'cc-rules')
        act(page,'cc-duration','24 hours')
        act(page,'cc-tries','1')
        act(page,'cc-rules-save')
        act(page,'cc-primary')
        expect(page.locator('.ready-invite')).to_contain_text('24 hours · 1 try per driver')
        act(page,'close')
        checks.append('Drive-first path delays invitation rules until after racing and retains the normal result summary')

        page.evaluate("state.completedSampleResult={track:4,car:3,time:'01:28.900',raceId:'slower-completed-ticket'}")
        act(page,'cc-context','result')
        page.evaluate('state.track=0; state.selectedCar=0')
        for variant in ['invitation','showdown','drive']:
            act(page,'cc-variant',variant)
            expect(page.locator('.creation-page')).to_contain_text('01:28.900')
            expect(page.locator('.creation-page')).to_contain_text(re.compile('Riverside',re.I))
            expect(page.locator('.creation-page')).to_contain_text('FORMULA / 04')
            expect(page.locator('#game [data-action="cc-track"], #game [data-action="cc-car"], #game [data-action="cc-setup"]')).to_have_count(0)
            page.evaluate("actions['cc-pick-track']('2'); actions['cc-pick-car']('2')")
            result=page.evaluate('challengeLab.result')
            assert (result['track'],result['car'],result['time'],result['raceId']) == (4,3,'01:28.900','slower-completed-ticket')
        act(page,'cc-primary')
        expect(page.locator('.ready-invite')).to_contain_text('01:28.900')
        page.evaluate("Object.defineProperty(navigator,'clipboard',{configurable:true,value:{writeText:()=>Promise.reject(new Error('Isolated clipboard fallback check'))}})")
        act(page,'cc-copy')
        expect(page.locator('.challenge-share-text')).to_contain_text('01:28.900')
        expect(page.locator('.challenge-share-text')).to_contain_text('Local design prototype invitation')
        act(page,'cc-ready')
        expect(page.locator('.ready-invite')).to_contain_text('01:28.900')
        checks.append('Copy fallback exposes clearly marked invitation text without changing the system clipboard')
        act(page,'created-challenges')
        expect(page.locator('.challenge-detail')).to_contain_text('01:28.900')
        checks.append('All three concepts pin the exact completed track, car and slower-than-PB time, including the created folder')

        act(page,'challenge-create')
        act(page,'cc-context','menu')
        assert page.evaluate('state.hasRaced') is True
        assert page.evaluate('challengeLab.result') is None
        expect(page.locator('[data-action="cc-primary"]')).to_contain_text('Set my time')
        checks.append('Menu creation never silently borrows an old finish or personal best')

        geometry=[]
        for width,height in [(1440,1080),(1280,900),(960,720),(390,844),(844,390)]:
            page.set_viewport_size({'width':width,'height':height})
            for context in ['menu','result']:
                act(page,'cc-context',context)
                for variant in ['invitation','showdown','drive']:
                    act(page,'cc-variant',variant)
                    bounds=page.evaluate('''()=>({doc:document.documentElement.scrollWidth,viewport:innerWidth,main:document.querySelector('.creation-page').getBoundingClientRect().toJSON(),button:document.querySelector('[data-action="cc-primary"]').getBoundingClientRect().toJSON()})''')
                    if bounds['doc']>width+1 or bounds['button']['width']<=0:
                        geometry.append({'width':width,'height':height,'context':context,'variant':variant,**bounds})
                    if width in [960,390] and context=='result':
                        page.wait_for_timeout(220)
                        page.screenshot(path=str(OUT / f'{variant}-result-{width}.png'),full_page=True)
        assert not geometry,json.dumps(geometry)
        checks.append('Thirty concept/context/viewport combinations fit document width with reachable primary actions')

        act(page,'cc-variant','invitation')
        act(page,'cc-rules')
        page.screenshot(path=str(OUT / 'optional-rules-844.png'),full_page=True)
        page.keyboard.press('Escape')
        act(page,'before')
        expect(page.locator('#challenge-name')).to_be_visible()
        page.keyboard.press('Escape')
        checks.append('The original form remains accessible only as a review comparison')
        assert not errors,errors
        assert not requests,requests
        checks.append('No JavaScript errors, external HTTP(S) requests, live account actions or game edits')
        browser.close()
    report={'date':'2026-10-23','status':'passed','check_count':len(checks),'checks':checks,'browser_errors':errors,'external_requests':requests,'physical_device_test':False}
    (OUT / 'browser-checks.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
    print(json.dumps(report,indent=2))


if __name__=='__main__':
    main()
