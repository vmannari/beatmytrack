import json
import deploy as r
target=json.loads((r.OUT/'daily-inspection-before.json').read_text())
assert target['include_artificial']
document=r.d.http(r.s['url'],'/v1/track-versions/'+target['version_id']+'/document')
assert document.status_code==200
r.d.write(r.WORK/'daily-document.json',document.json())
command=r.DOCKER+['run','--rm','--pull=never','--cpus=2','--memory=1g','--pids-limit=128','--label',r.LABEL,
 '--mount','type=bind,src='+r.d.unix(r.WORK)+',dst=/release','--entrypoint','python',r.s['local_main'],'/release/pregenerate.py']
output=r.d.command(command,'daily-pregenerate',timeout=3600)
print(output,flush=True)
