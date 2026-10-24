"""Review the one-poster redesign against its captured working-tree baseline."""
import hashlib
import json
import re
import shutil
import subprocess
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
for path, old, new in [
    ('game/ui/challenge_create.gd', b'three-by-three-v3.png', b'three-by-three-v4.png'),
    ('game/ui/challenge_format_card.gd', b'The series needs all three circuits and their starts visible together.',
     b'Keep all three scenic stages and their starts visible together.')]:
    assert (R/path).read_bytes() == (E/'task-base'/path).read_bytes().replace(old,new), path
m = json.loads((R/'game/assets/menu/challenges/three-by-three-redesign-v4.json').read_text())
assert sha(R/m['path']) == m['sha256'] == sha(Path(m['provider_output']))
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
        'command':f'powershell.exe -NoProfile -ExecutionPolicy Bypass -File docs/evidence/three-by-three-redesign-2026-10-24/run_validation.ps1 -Test test_challenge_cards -Mode {mode}'})
files = ['game/ui/challenge_create.gd','game/ui/challenge_format_card.gd','docs/CHALLENGE_PAGE.md',
         'licenses/ASSETS.md',m['path'],m['path']+'.import','game/assets/menu/challenges/three-by-three-redesign-v4.json']
for path in files:
    target = E/'task-final'/path
    target.parent.mkdir(parents=True,exist_ok=True)
    shutil.copyfile(R/path,target)
patch = command('git','-c','core.autocrlf=false','diff','--no-index','--binary',
                '--src-prefix=a/','--dst-prefix=b/','task-base','task-final',cwd=E,codes=(1,))
for prefix in (b'a/task-base/',b'a/task-final/',b'b/task-base/',b'b/task-final/'):
    patch=patch.replace(prefix,prefix[:2])
(E/'checkpoint.patch').write_bytes(patch)
verify=R/'build/three-by-three-redesign-2026-10-24/checkpoint-verify'
assert not verify.exists(), 'Use a fresh verification destination.'
shutil.copytree(E/'task-base',verify)
command('git','init','-q',cwd=verify)
command('git','config','core.autocrlf','false',cwd=verify)
command('git','apply','--check',str(E/'checkpoint.patch'),cwd=verify)
command('git','apply',str(E/'checkpoint.patch'),cwd=verify)
for path in files: assert sha(verify/path)==sha(R/path),path
report = {
 'date':'2026-10-24',
 'requirements':{'TTR01':'Redesign the confusing 3x3 picture as three coherent grounded race scenes.',
  'TTR02':'Match the mature cel-shaded 3D style and fictional car across forest/desert/winter stages.',
  'TTR03':'Fit all three scenes above the native caption with bounded lossless mipmapped imports.',
  'R01':'Preserve all other pictures, layout, challenge rules, actual Garage models and result/account behavior.',
  'G01':'Inspect native desktop and compact card captures on both desktop renderers.',
  'Q01':'Retain exact prompt/provenance, commands, results, hashes, baseline and scoped binary Git checkpoint.'},
 'engine':(R/'godot-version.txt').read_text().strip(),
 'artwork':m,
 'runtime_scope':'One poster path replacement and one explanatory comment; all other bytes of those runtime files match task baseline.',
 'changed_files':[{'path':p,'sha256':sha(R/p),'bytes':(R/p).stat().st_size} for p in files],
 'preserved_files':preserved,
 'import':{'exit_code':0,'log':'import-headless.log','command':'powershell.exe -NoProfile -ExecutionPolicy Bypass -File docs/evidence/three-by-three-redesign-2026-10-24/run_validation.ps1 -Test import'},
 'validation':results,
 'captures':{str(p.relative_to(E)).replace('\\','/'):sha(p) for p in sorted(E.glob('Windows-*/*.png'))},
 'checkpoint':{'path':'checkpoint.patch','sha256':sha(E/'checkpoint.patch'),'git_apply_check':'pass','applied_bytes':'all seven files exactly match final workspace'},
 'diagnostics':['Use the retained pinned-engine runner because the earlier session demonstrated that strict dev.ps1 aborts on the sandbox root-certificate-store diagnostic. Engine version is checked against godot-version.txt; no TLS validation is disabled.',
                'Native logs retain that root-certificate-store diagnostic. No assertion, resource or shader error is suppressed.'],
 'limitations':['The starter boards are decorative art; native copy explains three tries per track. There is no new gameplay or attempt indicator.',
  'The poster is illustrative raster art, not a live track preview or a requirement that a series contain these biomes.',
  'Native checks use desktop Compatibility and desktop Vulkan Mobile on RTX 3090. No phone/tablet attachment check or physical-device test was performed.',
  'No APK, install, live account/backend write, social send or deployment. Existing owner processes and concurrent work are preserved.',
  'Client reload and owner/device appearance acceptance remain. No repository-wide regression pass is claimed.']
}
(E/'report.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
print(json.dumps({'checks':results,'preserved_files':len(preserved),'checkpoint_files':len(files),'checkpoint_verified':True},indent=2))
