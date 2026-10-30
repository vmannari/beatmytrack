from pathlib import Path
import hashlib
import json
import shutil

ROOT = next(p for p in Path(__file__).resolve().parents if (p / 'godot-version.txt').exists())
OUT = Path(__file__).resolve().parent
tests = {}
for folder in sorted(OUT.iterdir()):
    command = folder / 'command.json'
    if not command.exists():
        continue
    entry = json.loads(command.read_text())
    entry['sources_changed_during_run'] = [path for path, digest in entry.get('before_hashes', {}).items()
                                           if entry.get('after_hashes', {}).get(path) != digest]
    entry['launch_script'] = str((folder / 'launch.ps1').relative_to(ROOT))
    entry['log'] = str((folder / 'run.log').relative_to(ROOT))
    entry['metrics'] = {}
    for phase in ['seed', 'reuse']:
        metric = folder / (phase + '.json')
        if metric.exists():
            entry['metrics'][phase] = json.loads(metric.read_text())
    tests[folder.name] = entry

generated = OUT / 'generated'
generated.mkdir(exist_ok=True)
for rel in ['game/core/build_identity.gd', 'game/project.godot']:
    source = ROOT / rel
    if source.exists():
        shutil.copyfile(source, generated / source.name)

report = dict(
    task='Garage pictures ready before entry', date='2026-10-28',
    requirements={
        'GRP01': 'Prepare exact current-owner images before startup menu and ahead of Garage entry.',
        'GRP02': 'Share ready textures; first carousel frame starts no image reads or captures.',
        'GRP03': 'Fence menu/swipe/section navigation by readiness, navigation generation and records owner.',
        'GRP04': 'Respect background/race/input/pressure gates and deduplicate residency; invalidate freed suspended Garage shells.',
        'GRP05': 'Actual native App checks with isolated saves, restarts, changed paint, cancellation, pressure and another owner.',
    },
    checkpoint=json.loads((OUT / 'checkpoint.json').read_text()),
    tests=tests,
    limitations=[
        'Missing custom appearances still require native capture, moved to startup or preparation ahead of entry.',
        'Cold desktop Mobile capture/shader startup can take tens of seconds; this is not zero total loading time.',
        'Main live Garage construction and shader hitches remain.',
        'Headless native-picture preparation is bypassed; picture appearance claims use native renderers.',
        'Visual source revisions changed concurrently between several process pairs. Only unchanged-revision pairs prove reuse.',
        'Retained App141 has one editor touch-cancellation failure; no broad App pass is claimed.',
        'No phone latency/FPS/memory acceptance, device query, APK, owner-save/live mutation, deployment, owner-process restart or main-index staging/commit/merge.',
    ],
    initial_findings=[
        'seed-gl: isolated parent folder absent; fixed fixture creates it before seeding.',
        'reuse-gl and gl-v3: cumulative IO assertion compared against zero; corrected to compare the entry delta.',
        'Pressure recovery resumed a freed suspended Garage shell; fixed actual App shell invalidation.',
        'gl-v3: concurrent art revision invalidated PNGs; record exact visual revision before asserting restart pixel reuse.',
        'final-gl-reuse: concurrently missing hovercraft_model.gd prevented parsing; model was not restored or edited by this task.',
        'final-mobile-seed: custom cold captures exceeded the unchanged 45-second startup preparation budget; readiness assertions fail and the original fixture dereferences a null Garage page. Later fixture retains the assertion and exits cleanly with diagnostics.',
    ],
    exclusions='Concurrent editor/Rivalry/workshop/model/handling/prepared assets and generated metadata remain outside task.patch.',
)
(OUT / 'report.json').write_text(json.dumps(report, indent=2) + '\n')
print(json.dumps(dict(tests=len(tests), failed=[key for key, value in tests.items() if value['exit_code']],
                      checkpoint_checks=report['checkpoint']['checks'])))
