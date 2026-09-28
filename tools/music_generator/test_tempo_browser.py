"""Rising-tempo integration: actual audio, phase continuity and original pitch rate."""
import json
from pathlib import Path
from playwright.sync_api import sync_playwright
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'docs/evidence/music-r4'
with sync_playwright() as p:
    browser=p.chromium.launch(channel='msedge',headless=True,args=['--autoplay-policy=no-user-gesture-required'])
    page=browser.new_page(viewport={'width':1440,'height':1000});page.set_default_timeout(60000)
    errors=[];page.on('pageerror',lambda e:errors.append(str(e)))
    page.goto('http://127.0.0.1:18765/lab.html'); page.locator('.presets summary').click();page.click('#evolve')
    page.wait_for_function('!loading && document.querySelector("#mode").value==="tempo"')
    assert page.evaluate('tempoBuffers.size')==36
    selected=page.evaluate('tracks.map(t=>t.asset)')
    page.uncheck('#advance');page.click('#play')
    page.wait_for_function('workbench.getState().position>.2')
    page.wait_for_function('()=>{analyser.getFloatTimeDomainData(meterData);return Math.max(...meterData.map(Math.abs))>.00001}')
    for stage,bpm in enumerate([90,102,114,126,138,150]):
        before=page.evaluate('playhead()')
        page.locator('#stages button').nth(stage).click()
        assert page.evaluate('activeBpm')==bpm
        assert page.evaluate('playhead()')>=before
        assert page.evaluate('tracks.filter(t=>t.target>0).length')==stage+1
        assert page.evaluate('tracks.map(t=>t.asset)')==selected
        assert page.evaluate('tracks.every(t=>t.source.playbackRate.value===1)')
        assert page.evaluate('tracks.every(t=>Math.abs(t.source.buffer.duration-32*60/activeBpm)<.0001)')
        assert page.evaluate('tracks.every(t=>t.startedAt===tracks[0].startedAt && Math.abs(t.startedOffset-tracks[0].startedOffset)<.00001)')
        page.wait_for_timeout(80)
    # Musical clock advances faster at the final state; elapsed streak remains wall time.
    a=page.evaluate('({p:playhead(),t:context.currentTime})');page.wait_for_timeout(400)
    b=page.evaluate('({p:playhead(),t:context.currentTime})')
    assert abs((b['p']-a['p'])/(b['t']-a['t'])-1.25)<.01
    page.click('#collision');assert page.evaluate('activeBpm')==90
    assert page.evaluate('tracks.map(t=>t.asset)')==selected
    page.locator('#stages button').nth(5).click()
    page.locator('#seek').evaluate('(e)=>{e.value=15.8;e.dispatchEvent(new Event("input"))}')
    page.wait_for_function('playhead()>16.3')
    page.wait_for_function('()=>{analyser.getFloatTimeDomainData(meterData);return Math.max(...meterData.map(Math.abs))>.00001}')
    select=page.locator('.track-title select').first
    options=select.locator('option').evaluate_all('(es)=>es.map(e=>e.value)')
    select.select_option(next(v for v in options if v!=select.input_value()))
    page.wait_for_function('!loading');assert page.evaluate('activeBpm')==150
    assert page.evaluate('tempoBuffers.size')==36
    page.click('#play');frozen=page.evaluate('playhead()');page.wait_for_timeout(150)
    assert page.evaluate('playhead()')==frozen
    with page.expect_download() as download:page.click('#save')
    setup=OUT/'tempo-setup.json';download.value.save_as(str(setup))
    page.click('#clear');page.set_input_files('#load',str(setup))
    page.wait_for_function('document.querySelector("#status").textContent.startsWith("Setup loaded")')
    assert page.input_value('#mode')=='tempo';assert page.evaluate('activeBpm')==150
    page.click('#play');page.wait_for_timeout(100)
    page.select_option('#mode','layers');assert page.evaluate('activeBpm')==120
    assert page.evaluate('tracks.every(t=>t.source.buffer===t.buffer)')
    page.click('#evolve');page.wait_for_function('!loading')
    page.click('#restart');assert page.evaluate('activeBpm')==90
    page.fill('#build','1');page.fill('#qualify','0');page.fill('#hold','0.3');page.check('#advance')
    page.wait_for_function('activeBpm===150')
    page.click('#collision');assert page.evaluate('activeBpm')==90
    page.wait_for_function('activeBpm===150 && recovery===0')
    page.uncheck('#advance');page.fill('#build','24');page.fill('#qualify','4');page.fill('#hold','5')
    page.locator('#stages button').nth(3).click();page.screenshot(path=str(OUT/'evolving-tempo.png'),full_page=True)
    page.set_viewport_size({'width':800,'height':1000})
    assert page.evaluate('document.documentElement.scrollWidth<=innerWidth')
    page.screenshot(path=str(OUT/'evolving-tempo-compact.png'),full_page=True)
    assert not errors,errors
    (OUT/'browser-results.json').write_text(json.dumps({'result':'PASS','checks':[
        'one-click random evolving drive','36 selected tempo buffers', 'nonzero actual audio',
        'six BPM states with cumulative layers','stable choices','all sources aligned in time and phrase',
        'playbackRate one at every tempo','musical clock progresses at selected BPM',
        'collision resets tempo without reshuffling','fast loop wrap','manual variation retains tempo',
        'bounded tempo cache','pause freezes clock','save/load tempo setup','switch back to fixed tempo',
        'restart at slow Focus','automatic buildup and collision recovery','compact layout','no JS errors']},indent=2))
    browser.close()
print('PASS: evolving tempo browser (19 grouped checks)')
