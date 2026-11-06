from pathlib import Path
import hashlib,json
p=Path(__file__).resolve().parent;root=p.parents[2]
project=Path(json.loads((p/'frozen-project.json').read_text())['project'])
labels=['contracts-final-engine','coverage-observe','coverage-selective','missing-controls','pine-full-final','pine-selective-final','pause-final']
runs={}
for label in labels:
    receipt=json.loads((p/(label+'-receipt.json')).read_text())
    assert receipt['exit_code']==0 and not receipt['changed_sources'] and not receipt['script_errors'],label
    runs[label]={'exit_code':0,'source_stable':True,'seconds':receipt['elapsed_seconds']}
    if (p/(label+'.json')).exists():
        result=json.loads((p/(label+'.json')).read_text())
        assert result['failures']==0,label
        runs[label]['checks']=result['checks']
        runs[label]['first_load_ms']=result['cases'][0]['wall_ms']
        assert all(r['contacts']==0 and r['completed_laps']>=1 for r in result['first_laps'])
        runs[label]['opening_laps']=len(result['first_laps'])
for label in ['coverage-selective','pine-selective-final','pause-final']:
    for row in json.loads((p/label/'profiles.json').read_text()):
        assert row['summary']['status']=='matched' and row['summary']['missing']==0
        assert row['summary']['late_compile_us']==0 and row['summary']['dropped']==0
        assert all(len(event['shader'])==64 for event in row['final']['observations'])
for label in ['pine-full-final','pine-selective-final','pause-final']:
    data=json.loads((p/label/'profiles.json').read_text())[0]['final']
    runs[label].update({k:data[k] for k in ['compilation_count','compilation_us','late_compilation_us']})
    assert not json.loads((p/(label+'-receipt.json')).read_text())['changed_sources']
controls=json.loads((p/'missing-controls/profiles.json').read_text())[0]['summary']
assert controls['missing']==2 and any(x['compile_phase']=='driving' and x['compile_us']>0 for x in controls['misses'])
images={}
for name in ['coverage-observe-vs-coverage-selective-images.json','pine-full-final-vs-pine-selective-final-images.json','pine-full-final-vs-missing-controls-images.json','pine-full-final-vs-pause-final-images.json']:
    values=json.loads((p/name).read_text());assert all(v['changed_pixels']==0 for v in values)
    images[name]=values
manifest=json.loads((root/'game/rendering/biome_shader_profiles.json').read_text())
assert (root/'game/rendering/biome_shader_profiles.json').read_bytes()==(p/'measured-profiles.json').read_bytes()
assert len(manifest['profiles'])==9
for name in ['core/game.gd','core/features/race.gd','backend/product_telemetry.gd','backend/backend_client.gd','backend/shader_profile_telemetry.gd','rendering/biome_shader_profile.gd','tests/test_biome_shader_profiles.gd','tests/profile_biome_shader_profiles.gd']:
    assert (root/'game'/name).read_bytes()==(project/name).read_bytes(),name
engine=json.loads((p/'engine-build.json').read_text())
assert engine['exit_code']==0
for name,digest in engine['binaries'].items():assert hashlib.sha256(Path(name).read_bytes()).hexdigest()==digest
result={'requirements':['BSP01','BSP02','BSP03','BSP04','BSPQ01'],'runs':runs,'images':images,
        'profiles':len(manifest['profiles']),'entries':sum(len(v['entries']) for v in manifest['profiles'].values()),
        'controls':controls,'backend_tests':22,'stock_engine_unchanged':True,'device_tested':False,
        'backend_deployed':False,'shader_sources_changed':False}
(p/'summary.json').write_text(json.dumps(result,indent=2)+'\n')
print({k:v for k,v in result.items() if k not in ['runs','images','controls']})
