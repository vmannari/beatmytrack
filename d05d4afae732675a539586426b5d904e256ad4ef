"""Release gates on the deployed schema and actual HTTP authority checks."""
import base64
import gzip
import struct

import pytest
from sqlalchemy import select
from test_challenges import create, normal_run, setup
from test_domains import domain as _domain_fixture, headers, submit
from test_rivalry import seed, join, rivalry_ticket

from bmt_backend.challenge_models import Challenge
from bmt_backend.community_models import PlayerBlock
from bmt_backend.identity_models import Player
from bmt_backend.rivalry_models import RivalryGroup, RivalryMember
from bmt_backend.track_models import Run, Track, TrackVersion
from bmt_backend.worker import process_one

ghost_domain=_domain_fixture

def challenge_fixture(d):
 version=setup(d);run=normal_run(d,version);challenge=create(d,version,run_id=run)
 return '/v1/challenges/'+challenge['code']+'/ghost',run,version,challenge

def test_bootstrap_negotiates_only_ghost_additions(ghost_domain):
 value=ghost_domain.client.get('/v1/bootstrap').json()
 assert value['ghost_identity_version']==value['ghost_wire_version']==1
 assert 'track_of_day_version' not in value and 'discovery_preview_version' not in value

def test_metadata_conditional_and_packed_reads(ghost_domain,monkeypatch):
 d=ghost_domain;path,run,_,_=challenge_fixture(d)
 calls=[];original=d.app.state.blobs.get_json
 def read(key):calls.append(key);return original(key)
 monkeypatch.setattr(d.app.state.blobs,'get_json',read)
 metadata=d.client.get(path+'?metadata=true')
 assert metadata.status_code==200 and 'recording' not in metadata.json() and calls==[]
 assert metadata.json()['run_id']==run and len(metadata.json()['content_hash'])==64
 assert d.client.get(path+'?metadata=true',headers={'If-None-Match':metadata.headers['etag']}).status_code==304
 assert calls==[]
 full=d.client.get(path);assert full.status_code==200 and len(calls)==1
 assert full.headers['cache-control']=='private, no-cache, must-revalidate'
 assert 'Authorization' in full.headers['vary']
 assert d.client.get(path).json()==full.json() and len(calls)==1
 assert d.client.get(path,headers={'If-None-Match':full.headers['etag']}).status_code==304
 assert len(calls)==1
 assert d.client.get(path+'?expected_run_id=wrong').status_code==409 and len(calls)==1
 assert d.client.get(path+'?encoding=unknown').status_code==422
 packed=d.client.get(path+'?encoding=packed&expected_run_id='+run)
 assert packed.status_code==200 and packed.json()['recording']==full.json()['recording']

@pytest.mark.parametrize('withdrawal',['hidden','disabled','cancelled'])
def test_cached_challenge_never_bypasses_current_authority(ghost_domain,withdrawal):
 d=ghost_domain;path,_,version,challenge=challenge_fixture(d)
 first=d.client.get(path);assert first.status_code==200
 with d.factory() as session:
  if withdrawal=='hidden':session.get(Track,session.get(TrackVersion,version).track_id).hidden=True
  elif withdrawal=='disabled':session.get(Player,d.players['Alice']).disabled=True
  else:session.get(Challenge,challenge['id']).cancelled=True
  session.commit()
 for query in ('','?metadata=true','?encoding=packed'):
  response=d.client.get(path+query,headers={'If-None-Match':first.headers['etag']})
  assert response.status_code>=400 and response.status_code!=304

def test_rivalry_metadata_rechecks_membership_blocks_and_archive(ghost_domain,monkeypatch):
 d=ghost_domain;setup(d);seed(d,6)
 group=join(d,'Alice')['group_id'];join(d,'Bob')
 ticket=rivalry_ticket(d,group,'Alice');submit(d,ticket,'Alice',30);assert process_one(d.app)
 path=f'/v1/rivalry/{group}/tracks/0/ghosts/'+d.players['Alice']
 calls=[];original=d.app.state.blobs.get_json
 def read(key):calls.append(key);return original(key)
 monkeypatch.setattr(d.app.state.blobs,'get_json',read)
 auth=headers(d,'Bob')
 meta=d.client.get(path+'?metadata=true',headers=auth)
 assert meta.status_code==200 and calls==[]
 full=d.client.get(path,headers=auth);assert full.status_code==200 and len(calls)==1
 assert d.client.get(path,headers={**auth,'If-None-Match':full.headers['etag']}).status_code==304
 assert d.client.get(path+'?metadata=true',headers=headers(d,'Carol')).status_code>=400
 with d.factory() as session:
  session.add(PlayerBlock(player_id=d.players['Bob'],blocked_id=d.players['Alice']));session.commit()
 assert d.client.get(path,headers={**auth,'If-None-Match':full.headers['etag']}).status_code>=400
 with d.factory() as session:
  session.delete(session.get(PlayerBlock,(d.players['Bob'],d.players['Alice'])))
  session.get(RivalryGroup,group).archived=True;session.commit()
 assert d.client.get(path+'?metadata=true',headers=auth).status_code==410

def test_exact_lossless_encoding_on_large_recording():
 from bmt_backend.ghost_wire import compact
 poses=[[i*6,i*.125,-.5*i,0,1.25,0,0] for i in range(2000)]
 original={'ticks':poses[-1][0],'poses':poses};result=compact(original)
 if 'data' in result:
  body=gzip.decompress(base64.b64decode(result['data']))
  assert [list(struct.unpack_from('<7d',body,i*56)) for i in range(len(poses))]==poses
 else:assert result==original
