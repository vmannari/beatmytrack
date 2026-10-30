from pathlib import Path
import difflib
import hashlib
import json
import shutil
import subprocess

root = next(p for p in Path(__file__).resolve().parents if (p / 'godot-version.txt').exists())
e = Path(__file__).resolve().parent
read = lambda p: p.read_text(encoding='utf-8')
sha = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()
tag = 'GARAGE-PRELOAD-20261027'
summary = '''<!-- GARAGE-PRELOAD-20261027 -->
## Preload the original live Garage before entry (2026-10-27)
GP01-GP04/R01/Q01: Owner requests preloading. After startup, selected-car/workshop/livery assets load with four-request bound; one original studio warms offscreen after2s idle in groups of at most8 matching geometry objects. Deliberate input/held touches/text focus/transitions/backgrounding pause between batches; race/loading and pressure retire optional work. Matching records/profile/car/paint/parts/wear transfer the same live world; unfinished/stale cases use normal live entry with decoded assets retained through construction. All held visibility/culling restores before handoff. No stock cover, substitute finishes, preload saves or canonical changes. Focused381headless/382Compatibility/382desktopMobile, App141/live-entry46/preloaded-reflections28/parser1330 pass; task-start2/1 expected failure. Fresh prepared entry callback68/78ms, live page610/481ms, startup167/153ms; cold warm-draw intervals2.64/3.72s remain, including other App rendering. Ready footprint estimated49.8MiB within existing96MiB budget; no phone/zero-stall claim. Initial fixture/parse/dummy-RID failures remain; headless assets serialize for its non-thread-safe allocator, native reads stay threaded. Four runtime sources; original renderer/material/model/physics and concurrent work preserved. Commands, native views, hashes and scoped patch: docs/GARAGE_PRELOAD_2026_10_27.md and docs/evidence/garage-preload-2026-10-27/report.json. Reload and owner/device latency/input/memory/appearance acceptance remain. No attachment/device test, APK, auth/purchase, owner-save/live mutation, deployment, main-index staging/commit/merge or owner-process restart.
<!-- /GARAGE-PRELOAD-20261027 -->

'''
for name in ['AGENTS.md', 'DEVELOPMENT_STATUS.md']:
    p = root / name
    content = p.read_bytes()
    begin, end = ('<!-- ' + tag + ' -->').encode(), ('<!-- /' + tag + ' -->').encode()
    if begin in content:
        a = content.index(begin); b = content.index(end, a) + len(end)
        if content[b:b+2] == b'\n\n': b += 2
        content = content[:a] + content[b:]
    p.write_bytes(summary.encode('utf-8') + content)

runtime = ['game/core/app.gd', 'game/ui/garage_page.gd', 'game/ui/garage_preloader.gd', 'game/ui/garage_preloaded_studio.gd']
new = runtime[2:] + ['game/tests/test_garage_preload.gd', 'docs/GARAGE_PRELOAD_2026_10_27.md', 'docs/evidence/garage-preload-2026-10-27/run_checks.py', 'docs/evidence/garage-preload-2026-10-27/compile_report.py', 'docs/evidence/garage-preload-2026-10-27/preloaded_reflections.gd']
for f in list(new):
    if f.endswith('.gd') and (root / (f + '.uid')).exists(): new.append(f + '.uid')
docs = ['AGENTS.md', 'DEVELOPMENT_STATUS.md']
def replace(text, part, value=''):
    assert text.count(part) == 1, part[:160]
    return text.replace(part, value, 1)
def baseline(name, after):
    if name in new: return ''
    if name in docs:
        a = after.index('<!-- ' + tag + ' -->'); b = after.index('<!-- /' + tag + ' -->', a) + len('<!-- /' + tag + ' -->')
        if after[b:b+2] == '\n\n': b += 2
        return after[:a] + after[b:]
    if name == 'game/core/app.gd':
        after = replace(after, 'var _garage_preloader: Node\n')
        after = replace(after, '\t\tif is_instance_valid(_garage_preloader): _garage_preloader.evict()\n')
        after = replace(after, ' or (is_instance_valid(_garage_preloader) and _garage_preloader.has_work())')
        after = replace(after, '\t_garage_preloader=preload("res://ui/garage_preloader.gd").new()\n\t_garage_preloader.app=self\n\tadd_child(_garage_preloader)\n')
        after = replace(after, '\tif is_instance_valid(_garage_preloader): result.merge(_garage_preloader.residency())\n')
        after = replace(after, '\tif is_instance_valid(_garage_preloader): _garage_preloader.evict()\n')
        after = replace(after, '\tif is_instance_valid(_garage_preloader): _garage_preloader.invalidate()\n')
        return replace(after, '\tif is_instance_valid(_garage_preloader): page.preloaded_showroom=_garage_preloader.take()\n')
    after = replace(after, 'var preloaded_showroom: CarShowroom\n')
    return replace(after, '\tif is_instance_valid(preloaded_showroom):\n\t\tshowroom=preloaded_showroom\n\telif progressive_entry:\n\t\tshowroom=preload("res://ui/garage_opening_showroom.gd").new()\n\telse:\n\t\tshowroom=CarShowroom.new()\n\tpreloaded_showroom=null\n', '\tshowroom = preload("res://ui/garage_opening_showroom.gd").new() if progressive_entry else CarShowroom.new()\n')

patch = []
files = runtime[:2] + docs + new
for name in files:
    after = read(root / name); before = baseline(name, after)
    target = e / 'checkpoint-base' / name
    target.parent.mkdir(parents=True, exist_ok=True); target.write_text(before, encoding='utf-8', newline='\n')
    target = e / 'task-final' / name
    target.parent.mkdir(parents=True, exist_ok=True); shutil.copyfile(root / name, target)
    patch.append(f'diff --git a/{name} b/{name}\n')
    if name in new: patch.append('new file mode 100644\n')
    patch.extend(difflib.unified_diff(before.splitlines(True), after.splitlines(True), fromfile='/dev/null' if name in new else 'a/' + name, tofile='b/' + name))
(e / 'checkpoint.patch').write_text(''.join(patch), encoding='utf-8', newline='\n')
result = subprocess.run(['git', 'apply', '--reverse', '--check', str(e / 'checkpoint.patch')], cwd=root, text=True, capture_output=True)
(e / 'checkpoint-check.json').write_text(json.dumps({'exit_code': result.returncode, 'stdout': result.stdout, 'stderr': result.stderr}, indent=2), encoding='utf-8')
assert result.returncode == 0, result.stderr
commands = {p.parent.name: json.loads(read(p)) for p in sorted(e.glob('*/command.json'))}
passing = ['final-headless-input', 'final-compatibility-input', 'final-mobile', 'actual-app', 'live-entry-retained', 'preloaded-reflections', 'final-parse-check', 'preferred-check']
for label in passing: assert commands[label]['exit_code'] == 0, label
generated = ['game/core/build_identity.gd', 'game/project.godot']
for name in generated:
    target = e / 'generated-metadata' / name
    target.parent.mkdir(parents=True, exist_ok=True); shutil.copyfile(root / name, target)
preserved = ['game/ui/car_showroom.gd', 'game/ui/garage_reflections.gd', 'game/vehicle/car_visual.gd', 'game/vehicle/vehicle_simulation.gd']
metrics = {label: json.loads(read(e / label / 'report.json')) for label in ['final-headless-input', 'final-compatibility', 'final-compatibility-input', 'final-mobile']}
report = {'requirements': ['GP01', 'GP02', 'GP03', 'GP04', 'R01', 'Q01'], 'date': '2026-10-27', 'engine': read(root / 'godot-version.txt').strip(), 'runtime_scope': runtime, 'source_sha256': {name: sha(root / name) for name in files}, 'preserved_sources': {name: {'sha256': sha(root / name), 'matches_task_start': sha(root / name) == sha(e / 'before' / name)} for name in preserved}, 'generated_metadata': {name: sha(root / name) for name in generated}, 'generated_note': 'Preferred dev.ps1 CheckScript generates client identity/version. Metadata is recorded separately and excluded from the scoped source patch.', 'metrics': metrics, 'passing_runs': passing, 'results': {'headless': 381, 'compatibility': 382, 'desktop_mobile': 382, 'app': 141, 'live_entry': 46, 'preloaded_reflections': 28, 'parsed_scripts': 1330}, 'commands': commands, 'checkpoint': {'path': 'checkpoint.patch', 'sha256': sha(e / 'checkpoint.patch'), 'reverse_check_exit_code': result.returncode}, 'initial_findings': ['Missing-preloader task-start replay: two checks / one expected failure.', 'Initial misplaced residency assignment caused a parse error; corrected in the helper.', 'Fixture manually removed a Settings-suspended page and tried to restore its retired shell; fixture now uses primary Tracks navigation.', 'One early dummy texture shutdown; fixture lets the existing catalogue request queue retire.', 'One threaded dummy mesh RID failure despite all 377 assertions; pinned allocator is not thread-safe. Headless asset reads now serialize; native paths remain asynchronous. A repeat before the guard also passed, so this is not represented as a deterministic failure.', 'Cold native warm intervals remain multiple seconds; measured as whole-App draw intervals, not solely the preloader GPU contribution.'], 'limits': ['Only the selected car/workshop are prepared, not seven live worlds.', 'Four pending resource requests, one studio and existing optional 96MiB estimated budget; figures are not device RSS/PSS.', 'Cold driver compilation can stall during a batch and cannot be interrupted by later input.', 'Opening before readiness uses the current original live construction; no stock cover or reduced quality.', 'Existing shared engine/catalogue/static caches may persist after owned-world eviction.', 'No phone timing, startup FPS or zero-stall guarantee.'], 'primary_engine_sources': ['https://docs.godotengine.org/en/stable/tutorials/performance/thread_safe_apis.html', 'https://raw.githubusercontent.com/godotengine/godot/ed1daf0bf/servers/rendering/dummy/storage/mesh_storage.h', 'https://raw.githubusercontent.com/godotengine/godot/ed1daf0bf/core/templates/rid_owner.h'], 'not_performed': ['device attachment check/test', 'APK/AAB', 'real authentication/purchase', 'owner-save/live backend mutation', 'deployment', 'main-index staging/commit/merge', 'owner-process restart']}
(e / 'report.json').write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
print(json.dumps({'commands': len(commands), 'passing_runs': len(passing), 'checkpoint_bytes': (e / 'checkpoint.patch').stat().st_size, 'reverse_check_exit': result.returncode}))
