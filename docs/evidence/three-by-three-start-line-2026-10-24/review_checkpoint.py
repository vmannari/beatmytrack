"""Record the poster correction against the captured working-tree baseline."""
import hashlib, json, re, shutil, subprocess
from pathlib import Path
E = Path(__file__).resolve().parent
R = E.parents[2]
def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest()
def command(*args, cwd=None, codes=(0,)):
    p = subprocess.run(args, cwd=cwd, capture_output=True)
    assert p.returncode in codes, p.stderr.decode(errors='replace')
    return p.stdout

preserved = json.loads((E/'preserved-hashes.json').read_text())
for path, digest in preserved.items(): assert sha(R/path) == digest, path
source = 'game/ui/challenge_create.gd'
assert (R/source).read_bytes() == (E/'task-base'/source).read_bytes().replace(b'three-by-three-v5.png',b'three-by-three-v6.png')
m = json.loads((R/'game/assets/menu/challenges/three-by-three-start-line-v6.json').read_text())
assert sha(R/m['path']) == m['sha256'] == sha(Path(m['provider_output']))
assert sha(E/'attempts/checker-near-draft.png') == m['edits'][0]['sha256']
settings = (R/(m['path']+'.import')).read_text()
assert all(s in settings for s in ('compress/mode=0','mipmaps/generate=true','process/size_limit=1024'))
results = []
for mode in ('headless','gl_compatibility','mobile'):
    name = f'test_challenge_cards-{mode}.log'
    text = (E/name).read_text(encoding='utf-8',errors='replace')
    matches = re.findall(r'CHALLENGE_CARDS: (\d+) checks, (\d+) failures',text)
    assert len(matches)==1 and int(matches[0][1])==0, name
    errors = [s for s in text.splitlines() if re.search(r'ERROR:|FAIL:',s)]
    assert all('Failed to read the root certificate store.' in s for s in errors), errors
    results.append({'mode':mode,'checks':int(matches[0][0]),'failures':0,'exit_code':0,'log':name,
        'command':f'powershell.exe -NoProfile -ExecutionPolicy Bypass -File docs/evidence/three-by-three-start-line-2026-10-24/run_validation.ps1 -Test test_challenge_cards -Mode {mode}'})
files = [source,'docs/CHALLENGE_PAGE.md','licenses/ASSETS.md',m['path'],m['path']+'.import',
         'game/assets/menu/challenges/three-by-three-start-line-v6.json']
for path in files:
    target = E/'task-final'/path
    target.parent.mkdir(parents=True,exist_ok=True)
    shutil.copyfile(R/path,target)
patch = command('git','-c','core.autocrlf=false','diff','--no-index','--binary',
                '--src-prefix=a/','--dst-prefix=b/','task-base','task-final',cwd=E,codes=(1,))
for prefix in (b'a/task-base/',b'a/task-final/',b'b/task-base/',b'b/task-final/'):
    patch=patch.replace(prefix,prefix[:2])
(E/'checkpoint.patch').write_bytes(patch)
verify=R/'build/three-by-three-start-line-2026-10-24/checkpoint-verify'
assert not verify.exists(), 'Use a fresh verification destination.'
shutil.copytree(E/'task-base',verify)
command('git','init','-q',cwd=verify)
command('git','config','core.autocrlf','false',cwd=verify)
command('git','apply','--check',str(E/'checkpoint.patch'),cwd=verify)
command('git','apply',str(E/'checkpoint.patch'),cwd=verify)
for path in files: assert sha(verify/path)==sha(R/path),path
report = {
 'date':'2026-10-24',
 'requirements':{'TSL01':'All three cars wait fully before the starting band, with a visible gap ahead of their front bumpers.',
  'TSL02':'Use multirow black/white checkerboards with alternating neighbors in both directions and consistent road perspective.',
  'TSL03':'Retain the scenic triptych, sandy Desert road, rear-quarter poses, mature cel shading and bounded imports.',
  'R01':'Preserve all other pictures, layout, actual Garage models and challenge/result/account behavior.',
  'G01':'Review the art and native card at normal/compact sizes on both desktop renderers.',
  'Q01':'Retain exact prompts, draft correction, commands, results, hashes, baseline and scoped binary Git checkpoint.'},
 'engine':(R/'godot-version.txt').read_text().strip(),
 'artwork':m,
 'runtime_scope':'Only one poster path changes. All other source bytes match task baseline; eleven prior artwork/UI files retain their captured hashes.',
 'changed_files':[{'path':p,'sha256':sha(R/p),'bytes':(R/p).stat().st_size} for p in files],
 'preserved_files':preserved,
 'visual_review':{'method':'Qualitative inspection of generated art and native menu captures; automated UI checks do not certify car-to-line geometry or checkerboard construction.',
  'observations':m['visual_review'],'remaining':'Owner acceptance of starting-line placement/checkerboard and physical-device appearance.'},
 'import':{'exit_code':0,'log':'import-headless.log','command':'powershell.exe -NoProfile -ExecutionPolicy Bypass -File docs/evidence/three-by-three-start-line-2026-10-24/run_validation.ps1 -Test import'},
 'validation':results,
 'captures':{str(p.relative_to(E)).replace('\\','/'):sha(p) for p in sorted(E.glob('Windows-*/*.png'))},
 'checkpoint':{'path':'checkpoint.patch','sha256':sha(E/'checkpoint.patch'),'git_apply_check':'pass','applied_bytes':'all six files exactly match final workspace'},
 'attempts_and_diagnostics':['The first edit removed the behind-car stripes and drew checkerboards ahead, but the bands were too near the car silhouettes. The retained final edit moves the bands farther up the road with clear visible approach gaps.',
  'Use the retained pinned-engine runner because earlier session evidence shows strict dev.ps1 aborts on the sandbox root-certificate-store diagnostic. Engine version is verified; no TLS validation is disabled.',
  'The initial Mobile run coincided with a concurrent recording_cache.gd edit using unavailable PackedByteArray.sha256_text and a second bytes_to_var argument. Its log, including 270 passing assertions plus compiler errors, is retained in attempts/mobile-concurrent-parser.log. That concurrent source was corrected independently; this task did not edit it. The final Mobile run is repeated and required to have no compiler errors.',
  'Logs retain that certificate diagnostic. No assertion, resource or shader error is suppressed.'],
 'limitations':['This is illustrative raster art, not a live track preview or a change to vehicle handling/camera.',
  'Earlier images and the first checker-placement draft remain. No exact pixel identity between image edits is claimed.',
  'Mobile is the desktop Vulkan renderer on RTX 3090. No phone/tablet attachment check or physical-device test was performed.',
  'No APK, install, live account/backend write, social send or deployment. Existing owner processes and concurrent work are preserved.',
  'Client reload and owner/device acceptance remain. No repository-wide regression pass is claimed.']}
(E/'report.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
print(json.dumps({'checks':results,'preserved_files':len(preserved),'checkpoint_files':len(files),'checkpoint_verified':True},indent=2))
