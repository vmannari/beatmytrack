"""Reproduce review findings in an owned local SQLite fixture, never live data."""
import json
import sys
from pathlib import Path
from uuid import uuid4

ROOT=Path(__file__).resolve().parents[1]
FROZEN=ROOT/'build/backend-latest-deploy-2026-10-16/frozen/backend'
sys.path.insert(0,str(FROZEN))
sys.path.insert(1,str(FROZEN/'tests'))
from fastapi.testclient import TestClient
from test_domains import FakeVerifier
from bmt_backend.app import create_app
from bmt_backend.config import Settings
from bmt_backend.identity_models import Player
from bmt_backend.migrate import upgrade
from bmt_backend.telemetry_models import ProductMetric,ProductPlayerDay,ProductState
from bmt_backend.track_models import Board,Run,RunTicket,Track,TrackVersion,now

out=ROOT/'docs/evidence/backend-product-review-2026-10-16'
private=ROOT/'build/backend-product-review-2026-10-16'/('correctness-'+uuid4().hex)
private.mkdir(parents=True)
app=create_app(Settings(environment='test',database_url='sqlite:///'+(private/'fixture.sqlite').as_posix(),
    object_dir=str(private/'objects'),admin_analyst_key='review-analyst-'+'a'*32,
    telemetry_enabled=True,client_quality_enabled=True),verifier=FakeVerifier())
upgrade(app.state.engine)
at=now();day=at//86400-2
with app.state.session_factory() as db:
    p=Player(display_name='Review fixture',analytics_enabled=True);db.add(p);db.flush()
    track=Track(owner_id=p.id);db.add(track);db.flush()
    version=TrackVersion(track_id=track.id,number=1,name='Owned review fixture',content_hash='a'*64,
        manifest=FakeVerifier().manifest(),state='published',published_at=at)
    db.add(version);db.flush()
    board=Board(id='b'*64,version_id=version.id,vehicle_id='compact',manifest=FakeVerifier().manifest())
    db.add(board);db.flush()
    for status,code in [('failed','REVIEW_PROVIDER_TIMEOUT'),('rejected','REVIEW_INVALID_PROOF')]:
        ticket=RunTicket(player_id=p.id,board_id=board.id,expires_at=at+120);db.add(ticket);db.flush()
        db.add(Run(ticket_id=ticket.id,player_id=p.id,board_id=board.id,replay_hash='c'*64,
            status=status,failure_code=code,created_at=at-10,finished_at=at-1))
    state=db.get(ProductState,1)
    state.collection_started_at=(day-1)*86400
    state.processed_through=at;state.observed_at=at;state.pending_events=0
    db.add(ProductMetric(day=day,key='active_players',dimension='',value=17))
    db.add(ProductPlayerDay(day=day,player_id=p.id))
    for index in range(16):
        another=Player(display_name='Review fixture '+str(index));db.add(another);db.flush()
        db.add(ProductPlayerDay(day=day,player_id=another.id))
    db.commit()

headers={'Authorization':'Bearer '+app.state.settings.admin_analyst_key}
with TestClient(app) as client:
    all_failed=client.get('/v1/admin/entities/races?state=failed',headers=headers).json()
    linked=client.get('/v1/admin/entities/races?state=failed&q=REVIEW_PROVIDER_TIMEOUT',headers=headers).json()
    assert all_failed['total']==1 and linked['total']==0
    health=client.get('/v1/admin/competition-health',headers=headers).json()
    assert health['failed_last_5_minutes']==1 and health['rejected_last_5_minutes']==1
    assert set(health['failures_last_5_minutes'])=={'REVIEW_PROVIDER_TIMEOUT','REVIEW_INVALID_PROOF'}
    context=client.get('/v1/admin/studio/context',headers=headers).json()
    assert 'schema' not in context
    since,until=day*86400+43200,day*86400+46800
    intraday=client.get('/v1/admin/product-analytics',params={'since':since,'until':until},headers=headers).json()
    assert intraday['daily'][0]['active_players']==17 and intraday['period_active_players']==17
    result={'scope':'Exact frozen deployed backend in owned SQLite; injected records are synthetic; no live writes',
        'failure_link_search':{'failed_rows_without_q':1,'failed_rows_with_matching_failure_code_q':0,
            'finding':'Reliability emits failure-code q links, but generic entity search excludes failure_code'},
        'failure_category_scope':{'infrastructure_failures':1,'rejections':1,
            'category_table_codes':list(health['failures_last_5_minutes']),
            'finding':'Table labeled server failure categories includes rejected-evidence codes'},
        'reliability_schema':{'context_has_schema':False,'finding':'Reliability renderer reads d.schema from context, which does not return schema'},
        'intraday_product_scope':{'requested_seconds':3600,'returned_day_active_counter':17,
            'finding':'Product report accepts exact since/until but reads full calendar-day facts; operational lists use exact timestamps'},
        'consistency_note':'Synthetic day counters and distinct-player facts both represent17 players; the intraday endpoint returns their full-day counts'}
(out/'correctness-reproductions.json').write_text(json.dumps(result,indent=2)+'\n')
app.state.engine.dispose()
print(json.dumps(result))
