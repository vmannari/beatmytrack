"""Keep relevant comparisons and receipts; remove this task's redundant drafts."""
from pathlib import Path
import hashlib,json
OUT=Path(__file__).resolve().parent
ROOT=OUT.parents[2]
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
assert json.loads((OUT/'final-acceptance.json').read_text())['status']=='passed'
drafts={'detail-draft','detail-draft-now','detail-draft2','detail-final','detail-latest','detail-stock',
 'garage-clean','garage-fair','garage-finished','garage-fitted','garage-marked-before','garage-no-shadows',
 'garage-normals','garage-qualified','garage-refined','garage-retopology','garage-shared','garage-smooth',
 'garage-sewn','garage-balanced','garage-final-shape'}
keep={'detail-draft':{'front.png'},'detail-stock':{'front.png'},'garage-shared':{'red-front.png'},
      'garage-sewn':{'red-front.png'},'garage-normals':{'red-front.png'},
      'garage-marked-before':{'red-rear.png','white-rear-flat.png'}}
owned_frames={'front.png','rear.png','side.png','right.png','overhead.png'}
owned_frames|={paint+'-'+view+'.png' for paint in ['red','white'] for view in ['front','rear','rear-flat','side']}
removed=[]
def remove(path,reason):
    resolved=path.resolve();assert resolved.is_relative_to(OUT) and not path.is_symlink()
    removed.append({'path':path.relative_to(OUT).as_posix(),'bytes':path.stat().st_size,'sha256':sha(path),'reason':reason})
    path.unlink()
for folder in drafts:
    for path in (OUT/folder).rglob('*.png'):
        if path.name in owned_frames and path.name not in keep.get(folder,set()):remove(path,'redundant task draft; selected comparison and logs retained')
for path in (OUT/'before-pictures').rglob('*.png'):remove(path,'superseded by the separately retained immediate pre-refresh controls')
for path in (OUT/'opaque').rglob('*-probe.png'):
    baseline=path.with_name(path.name.replace('-probe.png','.png'))
    assert baseline.is_file() and sha(path)==sha(baseline),'Retain any probe that differs'
    remove(path,'byte-identical bright-probe duplicate; baseline and successful probe receipts retained')
(OUT/'evidence-pruning.json').write_text(json.dumps({'files':removed,'removed_bytes':sum(v['bytes'] for v in removed)},indent=2),encoding='utf-8')
print('CHALLENGER_EVIDENCE_RETENTION:',len(removed),'redundant PNGs removed;',sum(v['bytes'] for v in removed),'bytes; source data, selected comparisons and receipts retained')
