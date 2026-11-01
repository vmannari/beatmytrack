"""Round-trip the task-only patch in an owned build folder; never use the index."""
import difflib
import hashlib
import json
from pathlib import Path
import subprocess
import time

root = Path(__file__).resolve().parents[3]
evidence = Path(__file__).resolve().parent
existing = {
    'game/track/surface_shader_variants.gd': 'game/track/surface_shader_variants.gd',
    'game/track/creator_bridge_visual.gd': 'game/track/creator_bridge_visual.gd',
    'game/track/bridge_presentation.gd': 'game/track/bridge_presentation.gd',
    'game/tests/test_shader_variant_consolidation.gd': 'game/tests/test_shader_variant_consolidation.gd',
    'DEVELOPMENT_STATUS.md': 'DEVELOPMENT_STATUS.md',
    'docs/PHASE_0_PLAN.md': 'PHASE_0_PLAN.md',
}
added = [
    'game/tests/fixtures/sampler_budget_before.gd.txt',
    'game/tests/fixtures/sampler_budget_gl_candidate.gd.txt',
    'docs/SAMPLER_BUDGET_FIX_2026_10_31.md',
    'docs/evidence/sampler-budget-fix-2026-10-31/run.ps1',
    'docs/evidence/sampler-budget-fix-2026-10-31/checkpoint.py',
]
for stem in ['test_sampler_pruning','review_sampler_pruning','profile_sampler_first_draw','run_sampler_validation']:
    added.append('game/tests/'+stem+'.gd')
    if (root/('game/tests/'+stem+'.gd.uid')).exists(): added.append('game/tests/'+stem+'.gd.uid')
verification = root / 'build/sampler-budget-fix-20261031' / ('patch-'+str(time.time_ns()))
assert verification.resolve().is_relative_to((root / 'build').resolve())
verification.mkdir(parents=True)
patch, after = [], {}
for name in list(existing) + added:
    prior = (evidence/'before'/existing[name]).read_text(encoding='utf-8') if name in existing else ''
    current = (root/name).read_text(encoding='utf-8')
    destination = verification/name
    destination.parent.mkdir(parents=True, exist_ok=True)
    if name in existing:
        destination.write_text(prior, encoding='utf-8', newline='\n')
    patch.extend(difflib.unified_diff(prior.splitlines(True), current.splitlines(True),
                                    fromfile='a/'+name if name in existing else '/dev/null', tofile='b/'+name))
    after[name] = current
    snapshot = evidence/'after'/name
    snapshot.parent.mkdir(parents=True, exist_ok=True)
    snapshot.write_bytes((root/name).read_bytes())
patch_path = evidence/'task.patch'
patch_path.write_text(''.join(patch), encoding='utf-8', newline='\n')
commands = []
for flags in [['--check'], [], ['--reverse','--check'], ['--reverse']]:
    command = ['git','apply','--whitespace=error','--directory='+verification.relative_to(root).as_posix(),
               *flags,str(patch_path.relative_to(root))]
    result = subprocess.run(command, cwd=root, text=True, capture_output=True)
    commands.append({'command':command, 'code':result.returncode, 'output':result.stdout+result.stderr})
    assert result.returncode == 0, commands[-1]
    if not flags:
        for name, current in after.items():
            assert (verification/name).read_text(encoding='utf-8') == current
for name, saved in existing.items():
    assert (verification/name).read_text(encoding='utf-8') == (evidence/'before'/saved).read_text(encoding='utf-8')
for name in added:
    assert not (verification/name).exists()
record = {'commands':commands, 'round_trip_exact':True,
          'source_sha256':{name:hashlib.sha256((root/name).read_bytes()).hexdigest() for name in after}}
(evidence/'checkpoint.json').write_text(json.dumps(record,indent=2),encoding='utf-8')
print('Verified forward/reverse content for',len(after),'task files.')
