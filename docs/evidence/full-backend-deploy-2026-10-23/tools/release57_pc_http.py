import json
from pathlib import Path
import requests

ROOT=Path(__file__).resolve().parents[1]
base='http://127.0.0.1:18181'
bootstrap=requests.get(base+'/v1/bootstrap',timeout=15).json()
assert bootstrap['discovery_paging_version']==3
response=requests.post(base+'/v1/discovery/v3/tracks',json={'query':{'sort':'name'}},timeout=15)
assert response.status_code==200,response.text
value=response.json();seen=set();pages=0
while True:
    pages+=1;ids={row['track_id'] for row in value['items']}
    assert not (ids&seen) and len(ids)<=20
    seen.update(ids)
    if not value['next_cursor']:break
    assert pages<10
    response=requests.post(base+'/v1/discovery/v3/tracks',json={'cursor':value['next_cursor']},timeout=15)
    assert response.status_code==200,response.text
    value=response.json()
assert len(seen)==27 and pages==2
result={'ready':True,'discovery_paging_version':3,'public_tracks_seen':len(seen),'cursor_pages':pages,'player_account_mutations':0}
(ROOT/'docs/evidence/full-backend-deploy-2026-10-23/pc-live-http.json').write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps(result))
