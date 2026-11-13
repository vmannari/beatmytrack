import json
import deploy as r

target=r.s['daily_passed']
response=r.d.http(r.s['url'],'/v1/track-of-the-day')
assert response.status_code==200
today=response.json()
assert today['status']=='ready' and today['track']['version_id']==target['displayed_version']
results={}
for car,expected in r.s['manifest']['vehicles'].items():
    path='/v1/track-of-the-day/limits?day='+str(target['day'])+'&version_id='+target['displayed_version']+'&vehicle_id='+car
    response=r.d.http(r.s['url'],path)
    assert response.status_code==200,(car,response.status_code)
    value=response.json()
    assert value['cutoffs'] and value['population']>=1 and value['manifest']['config_hash']==expected['config_hash']
    assert value['manifest']['handling_version']==expected['handling_version']
    results[car]={'status':200,'population':value['population'],'handling_version':value['manifest']['handling_version'],'cutoffs':len(value['cutoffs'])}
result={'today_status':200,'displayed_version':target['displayed_version'],'day':target['day'],'cars':results}
r.d.write(r.OUT/'daily-http.json',result)
print(json.dumps(result),flush=True)
