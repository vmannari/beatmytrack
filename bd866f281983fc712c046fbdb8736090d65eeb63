"""Read-only optimisation review: public bootstrap and synthetic local API reads."""
from copy import deepcopy
from datetime import datetime,timezone
import gzip
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import sys
from types import SimpleNamespace

ROOT=Path(__file__).resolve().parents[2]
WORK=Path(__file__).resolve().parent
OUT=ROOT/'docs/evidence/backend-reuse-review-2026-10-26'
OUT.mkdir(parents=True,exist_ok=True)
frozen=ROOT/'build/backend-ghost-cache-deploy-2026-10-26'
sys.path[:0]=[str(frozen/'release'),str(frozen/'test-work/backend/tests')]
from bmt_backend.storage import canonical_json
from sqlalchemy import event
from test_domains import domain,headers
from test_rivalry import seed,join

def write(name,value):(OUT/name).write_text(json.dumps(value,indent=2)+'\n',encoding='utf-8')

# Only an unauthenticated, read-only public bootstrap is requested remotely.
import requests
trust=ROOT/'.tools/gcp-staging/windows-trust.pem'
if trust.exists():os.environ['REQUESTS_CA_BUNDLE']=str(trust)
origin=json.loads((frozen/'release.json').read_text())['url']
response=requests.get(origin+'/v1/bootstrap',timeout=30);response.raise_for_status()
bootstrap=response.json()
keys=('ghost_identity_version','ghost_wire_version','discovery_preview_version',
      'run_completion_version','race_path_wire_version','non_improving_runs_version',
      'batch_run_status','trajectory_verification')
write('live-capabilities.json',{'checked_utc':datetime.now(timezone.utc).isoformat(),
 'origin':origin,'capabilities':{k:bootstrap.get(k) for k in keys}})

# Exercise the existing helper with actual bundled official route geometry.
spec=importlib.util.spec_from_file_location('bmt_backend.review_preview_wire',ROOT/'backend/bmt_backend/preview_wire.py')
preview=importlib.util.module_from_spec(spec);spec.loader.exec_module(preview)
index=json.loads((ROOT/'game/resources/cloud_tracks/index.json').read_text())['documents']
documents=[json.loads((ROOT/'game/resources/cloud_tracks'/name).read_text()) for name in index.values()]
cards=[{'version_id':f'00000000-0000-0000-0000-{i:012d}','content_hash':digest,
        'name':document['name'],'creator':'Synthetic official fixture',
        'rating_count':10,'rating_sum':45,'points':document['points']}
       for i,(digest,document) in enumerate(zip(index,documents))][:20]
page={'items':cards,'next_cursor':'synthetic-cursor','page_cursor':'synthetic-first-page'}
cold=preview.compact_previews(deepcopy(page),[])
known=[row['preview_hash'] for row in cold['items']]
updated=deepcopy(page);updated['items'][0]['rating_count']=11
warm=preview.compact_previews(deepcopy(updated),known)
assert all('points' not in row for row in warm['items'])
assert warm['items'][0]['rating_count']==11
saved={row['preview_hash']:row['points'] for row in cold['items']}
restored=deepcopy(warm)
for row in restored['items']:row['points']=saved[row['preview_hash']];row.pop('preview_hash')
assert restored==updated
query={'query':{'sort':'name','feed':'recommended'}}
def wire(value):
 raw=canonical_json(value)
 return len(gzip.compress(raw,compresslevel=3,mtime=0)) if len(raw)>=1024 else len(raw)
legacy=wire(query)+wire(updated)
reuse=wire({**query,'preview_cache':True,'known_previews':known})+wire(warm)
write('preview-payload.json',{'type':'Controlled payload experiment, not a provider bill or real discovery response',
 'geometry':'Actual points from the first twenty bundled official documents; synthetic card metadata',
 'cards':len(cards),'points_per_card':[len(x['points']) for x in cards],
 'gzip_level':3,'compression_threshold_bytes':1024,'headers_tls_excluded':True,
 'legacy_response_wire_model':wire(updated),'cold_reuse_response_wire_model':wire(cold),
 'warm_reuse_response_wire_model':wire(warm),'legacy_request_and_response_wire_model':legacy,
 'warm_request_and_response_wire_model':reuse,'warm_total_reduction_percent':100*(1-reuse/legacy),
 'fresh_rating_count_retained':True,'exact_geometry_reconstruction':True,
 'bundle_documents':len(index),'bundle_raw_bytes':sum((ROOT/'game/resources/cloud_tracks'/name).stat().st_size for name in index.values())})

# All following database reads/writes are inside a new synthetic SQLite fixture.
fixture=WORK/'synthetic-api';assert not fixture.exists();fixture.mkdir()
generator=domain.__wrapped__(fixture,SimpleNamespace(param='sqlite'))
d=next(generator)
counter=[]
def observe(connection,cursor,statement,parameters,context,executemany):
 counter.append(statement.lstrip().split(None,1)[0].upper())
event.listen(d.app.state.engine,'before_cursor_execute',observe)
try:
 def get(path,extra=None):
  counter.clear();result=d.client.get(path,headers={**headers(d,'Alice'),**(extra or {})})
  assert result.status_code in (200,304),(path,result.status_code,result.text)
  return result,{'status':result.status_code,'sql_statements':len(counter),
    'statement_kinds':{key:counter.count(key) for key in sorted(set(counter))},
    'decoded_body_bytes':len(result.content),'etag':bool(result.headers.get('etag')),
    'content_encoding':result.headers.get('content-encoding'),
    'content_length_header':result.headers.get('content-length')}
 endpoints={}
 for path in ('/v1/economy','/v1/achievements','/v1/news'):
  first,one=get(path);second,two=get(path,{'If-None-Match':first.headers.get('etag','"synthetic-unchanged"')})
  endpoints[path]={'first':one,'unchanged_revalidation':two,'logical_payload_equal':first.json()==second.json()}
  if path=='/v1/economy':
   wallet=second.json();without={k:v for k,v in wallet.items() if k!='prices'}
   endpoints[path]['price_entries']=len(wallet['prices'])
   endpoints[path]['full_response_compressed_model']=wire(wallet)
   endpoints[path]['without_static_prices_compressed_model']=wire(without)
 seed(d,6);join(d,'Alice')
 first,one=get('/v1/rivalry/current?vehicle_id=compact')
 assert first.headers.get('etag')
 second,two=get('/v1/rivalry/current?vehicle_id=compact',{'If-None-Match':first.headers['etag']})
 assert second.status_code==304
 endpoints['/v1/rivalry/current']={'first':one,'unchanged_revalidation':two,
  'qualification':'Six synthetic tracks and an enrolled account; SQLite statement counts exclude real authentication, cloud storage and PostgreSQL triggers.'}
 write('synthetic-api-reads.json',{'package':'Exact frozen deployed ghost-cache release package',
  'fixture':'New synthetic SQLite database; no live player data or credentials',
  'endpoints':endpoints})
finally:
 event.remove(d.app.state.engine,'before_cursor_execute',observe)
 try:next(generator)
 except StopIteration:pass
print(json.dumps({'preview':json.loads((OUT/'preview-payload.json').read_text()),
                  'api_reads':endpoints},indent=2))
