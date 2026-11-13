import hashlib
import json
from pathlib import Path
import struct

ROOT=Path(__file__).resolve().parents[2]
WORK=Path(__file__).resolve().parent
EV=ROOT/'docs/evidence/asset-review-2026-11-08'
corrected=[]
for rel in ['cars/cars.json','catalogue/catalogue.json','worlds-gl/worlds.json','worlds-mobile/worlds.json']:
    p=EV/rel
    if not p.is_file():continue
    data=json.loads(p.read_text())
    for row in data['rows']:
        values=row['rows']
        expected=sum(part['geometry']['indexed_probe_vertices']*part['instances'] for part in values)
        legacy_unweighted=sum(part['geometry']['indexed_probe_vertices'] for part in values)
        if legacy_unweighted!=expected:
            corrected.append({'file':rel,'case':row.get('theme',row.get('vehicle')),'kind':row.get('kind'),'legacy_unweighted':legacy_unweighted,'corrected_instance_weighted':expected})
        row['indexed_probe_vertices']=expected
        row['unindexed_vertices']=sum(part['geometry']['unindexed_vertices']*part['instances'] for part in values)
        assert row['base_vertices']==sum(part['geometry']['vertices']*part['instances'] for part in values)
    data['index_metric_normalized_from_recorded_per_mesh_rows']=True
    p.write_text(json.dumps(data,indent=2)+'\n',encoding='utf-8')
(EV/'index-metric-correction.json').write_text(json.dumps({'reason':'Initial helper summed prospective vertices once per MultiMesh but compared against instance-weighted original vertices. Recompute both using the retained per-mesh instance counts. Geometry, images, raw resource bytes and engine counts are unchanged.','corrected':corrected},indent=2)+'\n',encoding='utf-8')
textures=[]
for p in (ROOT/'game/assets/textures').rglob('*.png'):
    with p.open('rb') as f:header=f.read(24)
    if header[:8]!=b'\x89PNG\r\n\x1a\n':continue
    width,height=struct.unpack('>II',header[16:24])
    textures.append({'path':p.relative_to(ROOT).as_posix(),'width':width,'height':height,'png_bytes':p.stat().st_size,'rgba8_with_mips_upper_bound':round(width*height*4*4/3)})
textures.sort(key=lambda x:x['rgba8_with_mips_upper_bound'],reverse=True)
(EV/'track-texture-inventory.json').write_text(json.dumps({'rows':textures,'scope':'On-disk track texture catalogue. Uncompressed RGBA8+mipmap upper bound only; not a measurement of resident GPU/process memory, compression, actual material bindings or live race usage.'},indent=2)+'\n',encoding='utf-8')
start=json.loads((EV/'source-start.json').read_text())
end={rel:hashlib.sha256((ROOT/rel).read_bytes()).hexdigest() for rel in start if (ROOT/rel).is_file()}
(EV/'source-end.json').write_text(json.dumps(end,indent=2)+'\n',encoding='utf-8')
(EV/'source-changes.json').write_text(json.dumps({'changed':[rel for rel in start if start[rel]!=end.get(rel)],'production_writes_by_review':False,'main_index_unchanged':hashlib.sha256((ROOT/'.git/index').read_bytes()).hexdigest()==json.loads((EV/'initial-index.json').read_text())['sha256']},indent=2)+'\n',encoding='utf-8')
print(json.dumps({'index_metric_corrections':len(corrected),'track_texture_files':len(textures)}))
