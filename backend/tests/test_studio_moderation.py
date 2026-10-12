"""Case-linked visibility is atomic; players cannot read notes or appeal another case."""
# ruff: noqa: F811
from uuid import uuid4

from sqlalchemy import select
from test_studio import evidence, headers  # noqa: F401

from bmt_backend.admin_models import AdminAudit
from bmt_backend.studio_case_models import StudioCase
from bmt_backend.track_models import Track, TrackVersion


def test_case_quarantine_restore_retry_and_intervening_moderation(evidence):
    client, app, ids = evidence
    with app.state.session_factory() as session:
        track_id = session.get(TrackVersion, ids['version']).track_id
    case = client.post('/v1/admin/cases', headers=headers('owner'), json={
        'command_id':str(uuid4()),'title':'Track report','track_id':track_id}).json()
    url = '/v1/admin/cases/'+case['id']+'/events'
    command = {'command_id':str(uuid4()),'expected_revision':0,'kind':'quarantine','text':'Check reported track geometry'}
    assert client.post(url, headers=headers(), json=command).status_code == 403
    assert client.post(url, headers=headers('owner'), json=command).json()['revision'] == 1
    assert client.post(url, headers=headers('owner'), json=command).json()['revision'] == 1
    with app.state.session_factory() as session:
        assert session.get(Track, track_id).hidden
        audit = session.scalar(select(AdminAudit).where(AdminAudit.command_id == command['command_id']))
        assert audit.after['case_id'] == case['id']
    restore = {**command,'command_id':str(uuid4()),'kind':'restore','expected_revision':1,'text':'Report investigated and resolved'}
    assert client.post(url, headers=headers('owner'), json=restore).json()['revision'] == 2
    with app.state.session_factory() as session:
        assert not session.get(Track, track_id).hidden
    quarantine = {**command,'command_id':str(uuid4()),'expected_revision':2}
    assert client.post(url, headers=headers('owner'), json=quarantine).json()['revision'] == 3
    # Simulate a subsequent moderation decision by the existing owner command API.
    with app.state.session_factory() as session:
        session.add(AdminAudit(command_id=str(uuid4()),actor='owner',action='track_visibility',entity_id=track_id,
            reason='An additional unresolved report',before={'hidden':False},after={'hidden':True},
            request_hash='a'*64,request_id=str(uuid4()),created_at=2100000000))
        session.commit()
    assert client.post(url, headers=headers('owner'), json={**restore,'command_id':str(uuid4()),'expected_revision':3}).status_code == 409
    with app.state.session_factory() as session:
        assert session.get(Track, track_id).hidden


def test_signed_in_reports_appeals_and_staff_note_isolation(auth_client, auth_app, sign_in):
    from dataclasses import replace
    auth_app.state.settings = replace(auth_app.state.settings,admin_owner_key='o'*40,admin_analyst_key='a'*40)
    alice = {'Authorization':'Bearer '+sign_in('alice-report')['access_token']}
    bob = {'Authorization':'Bearer '+sign_in('bob-report')['access_token']}
    body = {'command_id':str(uuid4()),'reason':'technical_issue','text':'Upload remains pending'}
    assert auth_client.post('/v1/reports',json=body).status_code == 401
    created = auth_client.post('/v1/reports',headers=alice,json=body).json()
    assert auth_client.post('/v1/reports',headers=alice,json=body).json() == created
    identity = created['id']
    note = {'command_id':str(uuid4()),'expected_revision':0,'kind':'note','text':'Private staff analysis'}
    assert auth_client.post('/v1/admin/cases/'+identity+'/events',headers=headers('owner'),json=note).status_code == 200
    transition = {**note,'command_id':str(uuid4()),'expected_revision':1,'kind':'transition','status':'resolved','text':'Resolved with evidence'}
    assert auth_client.post('/v1/admin/cases/'+identity+'/events',headers=headers('owner'),json=transition).status_code == 200
    summary = auth_client.get('/v1/reports',headers=alice)
    assert 'Private staff' not in summary.text and len(summary.json()['items']) == 1
    assert auth_client.get('/v1/reports',headers=bob).json()['items'] == []
    with auth_app.state.session_factory() as session:
        public_case = session.get(StudioCase,identity)
        internal = StudioCase(player_id=public_case.player_id,title='Confidential staff investigation')
        session.add(internal);session.commit();internal_id=internal.id
    assert 'Confidential' not in auth_client.get('/v1/reports',headers=alice).text
    appeal = {'command_id':str(uuid4()),'expected_revision':2,'text':'New reproducible evidence supplied'}
    assert auth_client.post('/v1/reports/'+internal_id+'/appeal',headers=alice,json=appeal).status_code == 404
    assert auth_client.post('/v1/reports/'+identity+'/appeal',headers=bob,json=appeal).status_code == 404
    assert auth_client.post('/v1/reports/'+identity+'/appeal',headers=alice,json=appeal).json()['status'] == 'appealed'
    assert auth_client.post('/v1/reports/'+identity+'/appeal',headers=alice,json=appeal).json()['status'] == 'appealed'
    with auth_app.state.session_factory() as session:
        assert session.get(StudioCase,identity).revision == 3
