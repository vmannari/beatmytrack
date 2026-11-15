"""Retain unchanged native files after proving only their random local ID differs."""
from pathlib import Path
import hashlib,json,re
ROOT=Path(__file__).resolve().parents[3];OUT=Path(__file__).resolve().parent;BUILD=ROOT/'build'/OUT.name
pattern=re.compile(rb'local://ArrayMesh_([A-Za-z0-9]+)')
sha=lambda b:hashlib.sha256(b).hexdigest()
receipt=[]
prior={row['file']:row for row in json.loads((OUT/'exact-native-reuse.json').read_text())} if (OUT/'exact-native-reuse.json').exists() else {}
for p in sorted((BUILD/'native').glob('*.res')):
    if p.name.split('_',1)[1] in ['body_chrome.res','body_rubber.res']:continue
    original=(BUILD/'before/game/assets/vehicles/challenger_hellcat_v1'/p.name).read_bytes();generated=p.read_bytes()
    a=list(pattern.finditer(original));b=list(pattern.finditer(generated))
    assert len(a)==len(b)==1 and len(a[0][1])==len(b[0][1]),p.name
    def normalise(value,m):return value[:m.start(1)]+b'0'*len(m[1])+value[m.end(1):]
    assert normalise(original,a[0])==normalise(generated,b[0]),'Native data changed outside the local resource ID: '+p.name
    proof={'file':p.name,'generated_sha256':sha(generated),'retained_sha256':sha(original),'all_bytes_except_local_resource_id_exact':True,'prior_local_id':a[0][1].decode(),'generated_local_id':b[0][1].decode()}
    if original==generated and p.name in prior:
        assert prior[p.name]['retained_sha256']==sha(original)
        proof=prior[p.name]
    receipt.append(proof)
    p.write_bytes(original)
assert len(receipt)==40
outline_path=BUILD/'native/bonnet_contour.json'
old_outline_path=BUILD/'before/game/assets/vehicles/challenger_hellcat_v1/bonnet_contour.json'
old_outline=json.loads(old_outline_path.read_text());outline=json.loads(outline_path.read_text())
old_digest=old_outline.pop('source_sha256');digest=outline.pop('source_sha256')
assert old_outline==outline, 'The immutable bonnet outline must remain semantically exact'
hood=next(row for row in receipt if row['file']==outline['source_mesh'])
assert old_digest==hood['retained_sha256'] and digest in [hood['generated_sha256'],hood['retained_sha256']]
outline_path.write_bytes(old_outline_path.read_bytes())
(OUT/'exact-outline-reuse.json').write_text(json.dumps({'all_outline_fields_exact':True,'retained_hood_sha256':old_digest,'original_outline_and_matching_immutable_hood_retained':True},indent=2))
(OUT/'exact-native-reuse.json').write_text(json.dumps(receipt,indent=2))
print('EXACT_NATIVE_REUSE 40 resources; only exporter local resource identifiers differed; original bytes retained.')
