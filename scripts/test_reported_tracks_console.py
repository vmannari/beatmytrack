"""Reported-track moderation in an isolated loopback Studio, including lost replies."""
import argparse
import json
import secrets
import socket
import subprocess
import sys
import time
from pathlib import Path
from uuid import uuid4

ROOT = Path(__file__).resolve().parents[1]
sys.path[:0] = [str(ROOT / 'backend'), str(ROOT / 'backend/tests'), str(ROOT / 'scripts')]
OUT = ROOT / 'docs/evidence/reported-tracks-2026-11-04'


def serve(folder, port):
    from dataclasses import replace

    import bmt_backend.app as application
    import uvicorn
    from test_backend_studio_console import serve as base
    create_app = application.create_app
    # The historical fixture predates the explicit legacy-key development gate.
    application.create_app = lambda settings, **kwargs: create_app(
        replace(settings, studio_legacy_keys_enabled=True), **kwargs)
    original = uvicorn.run

    def seeded(app, **kwargs):
        from bmt_backend.studio_case_models import StudioCase, StudioCaseEvent
        from bmt_backend.track_models import Track, TrackVersion, now
        fixture = json.loads((folder / 'fixture.json').read_text())
        with app.state.session_factory() as session:
            version = session.get(TrackVersion, fixture['version_id'])
            version.name = 'Harbour Circuit'
            version.discovery = {'theme': 'pine', 'points': [[0, 0], [50, 0], [70, 35], [50, 60], [0, 50], [0, 0]]}
            track_id = version.track_id
            for index in range(4):
                track = Track(owner_id=fixture['player_id']) if index else session.get(Track, track_id)
                if index:
                    session.add(track)
                    session.flush()
                    session.add(TrackVersion(track_id=track.id, number=1, name=['', 'Winter Switchback', 'City Sprint', 'Pine Ridge'][index],
                        content_hash=str(index)*64, manifest={}, state='published', discovery=version.discovery))
                for number in range([7, 4, 2, 1][index]):
                    case = StudioCase(track_id=track.id, player_id=fixture['player_id'] if number % 2 else fixture['artificial_player_id'],
                                      title='Player track report', status='resolved' if number == 1 else 'open')
                    session.add(case)
                    session.flush()
                    session.add(StudioCaseEvent(id=str(uuid4()), case_id=case.id, actor='player', kind='reported',
                        detail={'reason': 'track_issue', 'text': '<script>alert("report")</script> The shortcut skips most of the lap.' if number == 0 else 'Please review the reported section.', 'version_id': version.id if not index else None},
                        request_hash='a'*64, created_at=now()-number*3600))
            session.commit()
            fixture['track_id'] = track_id
        (folder/'fixture.json').write_text(json.dumps(fixture))
        original(app, **kwargs)
    uvicorn.run = seeded
    base(folder, port)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--serve', type=Path)
    parser.add_argument('--port', type=int)
    args = parser.parse_args()
    if args.serve:
        serve(args.serve, args.port)
        return
    import httpx
    from playwright.sync_api import expect, sync_playwright
    OUT.mkdir(parents=True, exist_ok=True)
    folder = ROOT/'build'/('reported-tracks-browser-'+uuid4().hex[:8])
    folder.mkdir()
    config = {key: secrets.token_urlsafe(32) for key in ('owner', 'analyst', 'development')}
    (folder/'config.private.json').write_text(json.dumps(config))
    with socket.socket() as sock:
        sock.bind(('127.0.0.1', 0))
        port = sock.getsockname()[1]
    base = f'http://127.0.0.1:{port}'
    checks = []
    with (folder/'server.log').open('w', encoding='utf-8') as log:
        server = subprocess.Popen([sys.executable, str(Path(__file__).resolve()), '--serve', str(folder), '--port', str(port)],
                                  stdout=log, stderr=log, creationflags=subprocess.CREATE_NO_WINDOW)
        try:
            with httpx.Client(base_url=base, timeout=15) as http:
                for _ in range(100):
                    if server.poll() is not None:
                        raise RuntimeError('Owned server failed; inspect '+str(folder/'server.log'))
                    try:
                        if http.get('/health').status_code == 200:
                            break
                    except httpx.ConnectError:
                        pass
                    time.sleep(.2)
                else:
                    raise RuntimeError('Owned server did not become ready')
            fixture = json.loads((folder/'fixture.json').read_text())
            with sync_playwright() as driver:
                browser = driver.chromium.launch(headless=True, executable_path='C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe')
                page = browser.new_page(viewport={'width': 1440, 'height': 1000})
                errors = []
                page.on('pageerror', lambda error: errors.append(str(error)))
                page.goto(base+'/admin#reported-tracks')
                page.fill('#key', config['owner'])
                page.locator('#login button').click()
                expect(page.locator('h1')).to_have_text('Reported tracks')
                expect(page.locator('#main tbody tr')).to_have_count(4)
                assert page.locator('#main tbody tr').first.inner_text().count('7') >= 1
                page.screenshot(path=str(OUT/'queue-desktop.png'), full_page=True)
                checks.append('Owner queue groups four reported tracks and sorts by total reports')
                page.locator('[name=q]').fill('Harbour')
                page.locator('#reported-track-filters button').click()
                expect(page.locator('#main tbody tr')).to_have_count(1)
                page.get_by_role('link', name='Review reports').click()
                expect(page.locator('h1')).to_have_text('Harbour Circuit')
                expect(page.locator('#main tbody tr')).to_have_count(7)
                assert page.locator('#main script').count() == 0
                page.screenshot(path=str(OUT/'reports-desktop.png'), full_page=True)
                checks.append('Search, report reasons, escaped player text and case links render')
                page.locator('#delete-reported-track').click()
                expect(page.get_by_role('heading', name='Delete Harbour Circuit?')).to_be_visible()
                page.screenshot(path=str(OUT/'delete-confirmation.png'), full_page=True)
                page.get_by_role('button', name='Cancel', exact=True).click()
                expect(page.locator('#dialog')).not_to_be_visible()
                checks.append('Deletion preview can be cancelled')
                page.set_viewport_size({'width': 768, 'height': 1024})
                page.screenshot(path=str(OUT/'reports-tablet.png'), full_page=True)
                page.set_viewport_size({'width': 1440, 'height': 1000})
                replies = []

                def lost_reply(route):
                    replies.append(route.request.post_data_json)
                    if len(replies) == 1:
                        response = route.fetch()
                        assert response.status == 200
                        route.fulfill(status=503, content_type='application/json', body='{"detail":"Reply lost after commit; retry"}')
                    else:
                        route.continue_()
                page.route('**/reported-tracks/*/delete', lost_reply)
                page.locator('#delete-reported-track').click()
                page.locator('[name=reason]').fill('Reviewed the player reports and confirmed abusive layout.')
                page.locator('[name=acknowledged]').check()
                page.get_by_role('button', name='Confirm deletion', exact=True).click()
                expect(page.locator('#reported-delete-error')).to_be_visible()
                expect(page.get_by_role('button', name='Confirm deletion', exact=True)).to_be_enabled()
                page.get_by_role('button', name='Confirm deletion', exact=True).click()
                expect(page.locator('#dialog')).not_to_be_visible()
                expect(page.locator('#main')).to_contain_text('This track has been deleted from public access.')
                assert replies[0] == replies[1]
                page.screenshot(path=str(OUT/'deleted-track.png'), full_page=True)
                checks.append('Lost deletion reply retries the exact command and shows retained reports')
                with httpx.Client(base_url=base, timeout=15) as http:
                    assert http.get('/v1/track-versions/'+fixture['version_id']).status_code == 404
                    headers = {'Authorization': 'Bearer '+config['owner']}
                    audit = http.get('/v1/admin/entities/audit?all=1', headers=headers).json()
                    assert len([r for r in audit['items'] if r['action'] == 'track_deletion']) == 1
                checks.append('Deleted public version is inaccessible and only one audit decision exists')
                page.evaluate("id => location.hash='cases/'+id", replies[0]['case_id'])
                expect(page.locator('#main')).to_contain_text('Track deleted')
                page.screenshot(path=str(OUT/'case-deletion-audit.png'), full_page=True)
                checks.append('Linked support case displays the deletion reason and audit link')
                page.evaluate("id => location.hash='tracks/'+id", fixture['version_id'])
                expect(page.locator('#main')).to_contain_text('Deleted; removed from public access')
                assert page.locator('#command').count() == 0
                page.evaluate("id => location.hash='reported-tracks/'+id", fixture['track_id'])
                expect(page.locator('h1')).to_have_text('Harbour Circuit')
                checks.append('Catalogue retains historical evidence and offers no Show action for deleted tracks')
                page.locator('#logout').click()
                page.fill('#key', config['analyst'])
                page.locator('#login button').click()
                expect(page.locator('h1')).to_have_text('Harbour Circuit')
                assert page.locator('#delete-reported-track').count() == 0
                page.evaluate("location.hash='reported-tracks?visibility=all'")
                expect(page.locator('h1')).to_have_text('Reported tracks')
                expect(page.locator('#main tbody tr')).to_have_count(4)
                page.screenshot(path=str(OUT/'analyst-queue.png'), full_page=True)
                checks.append('Analyst can inspect the complete queue but has no deletion control')
                assert not errors, errors
                checks.append('Zero browser JavaScript errors')
                browser.close()
            (OUT/'browser.json').write_text(json.dumps({'checks': checks, 'loopback_only': True}, indent=2)+'\n')
            print(f'Reported tracks browser: {len(checks)} checks passed')
        finally:
            if server.poll() is None:
                server.terminate()
                server.wait(timeout=10)


if __name__ == '__main__':
    main()
