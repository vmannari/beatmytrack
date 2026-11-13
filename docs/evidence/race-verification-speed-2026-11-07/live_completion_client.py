"""One labelled artificial completion, using normal tickets, upload and wait."""
import json,os,time
from pathlib import Path
from bmt_backend.test_population_tool import API
root=Path('/release')
api=API(os.environ['RELEASE_API'],os.environ['BMT_DEV_AUTH_KEY'])
profile=api.call('GET','/dev/test-drivers/fleets/test-fleet-202611071',operator=True)['profiles'][0]
today=api.call('GET','/track-of-the-day')
record=json.loads((Path('/previous')/'pregenerated-compact.json').read_text())
assert today['track']['content_hash']==record['content_hash']
ticket=api.call('POST','/run-tickets',{'version_id':today['track']['version_id'],'vehicle_id':'compact','test_population':True},profile['subject'],'race-speed-20261107-ticket-v1')
replay=record['result']['replay']
replay.pop('claimed_lap_ticks',None) # Require actual path verification, even for the same previous PB.
started=time.monotonic()
run=api.call('POST','/runs',{'ticket_id':ticket['ticket_id'],'replay':replay},profile['subject'],'race-speed-20261107-upload-v1')
upload=time.monotonic()-started
waits=0
while run['status'] in ('queued','verifying') and waits<5:
    run=api.call('GET','/runs/'+run['run_id']+'/wait?timeout_ms=2000&completion=true',subject=profile['subject'])
    waits+=1
assert run['status']=='verified',run.get('failure_code')
result={'status':run['status'],'post_upload_seconds':upload,'post_to_terminal_seconds':time.monotonic()-started,
        'wait_requests':waits,'verified_ticks':run['time_ticks'],'artificial_driver':True,'real_player_results_modified':False}
(root/'live-completion.json').write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps(result),flush=True)
