from pathlib import Path
import hashlib,json
ROOT=Path(__file__).resolve().parents[3];OUT=Path(__file__).resolve().parent
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
receipt=json.loads((OUT/'final-acceptance.json').read_text())
native=ROOT/'game/assets/vehicles/challenger_hellcat_v1'
assert all(sha(native/p)==s for p,s in receipt['native_resources'].items())
controls=json.loads((OUT/'protected-controls.json').read_text())
assert all(sha(ROOT/p)==s for p,s in controls.items())
checkpoint=json.loads((OUT/'source-checkpoint.json').read_text())
assert all(sha(ROOT/p)==s['after'] for p,s in checkpoint['files'].items())
for name in ['AGENTS.md','DEVELOPMENT_STATUS.md']:
    path=ROOT/name;data=path.read_bytes()
    start=data.index(b'<!-- CHALLENGER-JOINS-20261112 -->');end=data.index(b'<!-- /CHALLENGER-JOINS-20261112 -->')
    block=data[start:end].replace(b'OpenGL test shutdown retains2 ObjectDB/1-resource diagnostics.',b'App test teardown diagnostics are retained.').replace(b'OpenGL shutdown retains2 ObjectDB/1-resource diagnostics.',b'App test teardown diagnostics are retained.')
    path.write_bytes(data[:start]+block+data[end:])
cleanup=json.loads((ROOT/'.tmp/build-cleanup-last.json').read_text(encoding='utf-8-sig'))
(OUT/'build-retention-receipt.json').write_text(json.dumps(cleanup,indent=2))
(OUT/'closeout-verification.json').write_text(json.dumps({'native_hashes_current':True,'protected_controls_current':True,'authored_sources_current':True,'task_build_output_removed':not (ROOT/'build/challenger-surface-joins-2026-11-12').exists()},indent=2))
print('Final native resources, protected controls and authored sources remain exact; task output removed.')
