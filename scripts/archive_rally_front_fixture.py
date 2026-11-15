"""Preserve rejected comparison receipts; keep their draft images disposable."""
import hashlib
import json
import shutil
from run_rally_front import ROOT,WORK,OUT
archive=(WORK/'rejected-scale-fixture').resolve();archive.mkdir(parents=True,exist_ok=True)
names=['source-gl_compatibility','prepared-gl_compatibility','prepared-mobile',
       'prepared-gl_compatibility-night','prepared-mobile-night','front-comparison.png']
names += [label+suffix for label in ('native-source-draft','native-gl','native-mobile','night-gl_compatibility','night-mobile') for suffix in ('.log','-receipt.json')]
rows={}
for name in names:
    source=(OUT/name).resolve();target=(archive/name).resolve()
    assert source.is_relative_to(OUT.resolve()) and target.is_relative_to(WORK.resolve()) and not target.exists()
    if not source.exists():continue
    if source.is_file():rows[name]={'sha256':hashlib.sha256(source.read_bytes()).hexdigest(),'receipt':json.loads(source.read_text()) if name.endswith('-receipt.json') else None}
    else:rows[name]={'files':len(list(source.rglob('*')))}
    shutil.move(str(source),str(target))
(OUT/'comparison-fixture-rejection.json').write_text(json.dumps(dict(accepted=False,
    reason='Original detached before scene omitted CarVisual root BODY_SCALE. Geometry signatures remain exact; mismatched comparison images are rejected and moved to disposable output. Initial Mobile night restoration also retained one exact-pixel control failure.',
    corrected_by='snapshot-fixture-repair.json; capture now asserts root-transform equality before every comparison.',drafts=rows),indent=2)+'\n')
print('RALLY_FRONT_FIXTURE_ARCHIVE',len(rows),'draft outputs retained under build policy')
