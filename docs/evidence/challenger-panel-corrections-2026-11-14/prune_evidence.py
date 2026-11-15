"""Keep final receipts/comparisons; leave untracked drafts under bounded build/."""
from pathlib import Path
import hashlib,json,shutil,subprocess
ROOT=Path(__file__).resolve().parents[3];OUT=Path(__file__).resolve().parent
WORK=ROOT/'build/challenger-panel-corrections-2026-11-14/diagnostics/evidence-drafts'
assert WORK.resolve().is_relative_to((ROOT/'build').resolve())
tracked=set(subprocess.check_output(['git','ls-files','-z','--',OUT.relative_to(ROOT).as_posix()],cwd=ROOT).decode().split('\0'))
labels=set('native-final native-allocation native-allocation-final panels-final panels-live panels-baseline-final contours-final contours-seam-probe hood-ray-diagnostic fitted modules physics wash driving parser-final coarse-bake coarse-verification livery-pictures model-art workshop-refresh prepared-view-gl prepared-full-gl prepared-mobile prepared-full-mobile opaque-gl_compatibility opaque-mobile app-gl_compatibility app-mobile prepared-live-final metrics before-gl before-mobile native-cowl-probe'.split())
move=[]
for p in OUT.iterdir():
    if not p.is_file():continue
    if p.name.endswith('-running.json') or p.name=='prototype.py' or p.name.startswith('prototype') and p.suffix=='.log':move.append(p);continue
    if p.suffix=='.log' and p.stem not in labels and p.name not in ['preparation-qualified.log','image-import.log']:move.append(p);continue
    if p.name.endswith('-command.json') and p.name[:-len('-command.json')] not in labels and p.name!='preparation-command.json':move.append(p);continue
    if p.name.startswith('panels-') and p.suffix=='.json' and not p.name.endswith('-command.json') and p.stem not in ['panels-final','panels-live','panels-baseline']:move.append(p)
for stage in ['before','prepared']:
    for method in ['gl_compatibility','mobile']:
        for tier in ['simple','full']:
            folder=OUT/stage/method/tier
            if not folder.exists():continue
            keep={'white-rear.png','white-front.png','white-door-corner.png','white-overhead.png'}
            if stage=='prepared':keep|={'red-front-quarter.png','red-rear-quarter.png'}
            move += [p for p in folder.glob('*.png') if p.name not in keep]
receipts=[]
for p in dict.fromkeys(move):
    if p.relative_to(ROOT).as_posix() in tracked:continue
    assert not p.is_symlink() and p.resolve().is_relative_to(OUT.resolve())
    target=WORK/p.relative_to(OUT);target.parent.mkdir(parents=True,exist_ok=True)
    digest=hashlib.sha256(p.read_bytes()).hexdigest()
    if target.exists():target=target.with_name(target.stem+'-'+digest[:12]+target.suffix)
    shutil.move(str(p),str(target));receipts.append({'path':p.relative_to(ROOT).as_posix(),'sha256':digest})
(OUT/'evidence-retention.json').write_text(json.dumps({'untracked_drafts_moved_under_build':receipts,'tracked_files_moved':False,'render_selection':'Four marked white views, two reflection quarters per final tier/renderer; actual App views.'},indent=2))
print('EVIDENCE_RETENTION',len(receipts),'untracked draft files moved under bounded build output')
