from pathlib import Path
import difflib
import hashlib
import json
import subprocess

root = next(p for p in Path(__file__).resolve().parents if (p / 'godot-version.txt').exists())
e = Path(__file__).resolve().parent
read = lambda p: p.read_text(encoding='utf-8')
sha = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()
runtime = ['game/core/app.gd', 'game/ui/garage_page.gd', 'game/ui/car_showroom.gd', 'game/ui/garage_preview_cache.gd', 'game/vehicle/car_visual.gd']
helpers = ['garage_car_cache', 'garage_opening_showroom', 'garage_first_draw', 'garage_opening_facade']
tests = ['bake_garage_cars', 'test_garage_prepared_cars', 'test_garage_cold_opening', 'test_garage_opening_tools', 'profile_garage_cold_open', 'profile_garage_entry_cpu', 'probe_shader_cache_settings', 'probe_garage_app_lifetime']
new = [f'game/ui/{s}.gd' for s in helpers] + [f'game/tests/{s}.gd' for s in tests]
new += [f + '.uid' for f in list(new) if (root / (f + '.uid')).exists()]
new += ['game/assets/garage/cars_v1/provenance.json', 'docs/GARAGE_COLD_OPENING_2026_10_26.md', 'docs/evidence/garage-cold-opening-2026-10-26/run_checks.py', 'docs/evidence/garage-cold-opening-2026-10-26/compile_report.py']
adapted = ['game/tests/test_garage_entry_carousel.gd', 'game/tests/test_mobile_audit_fixes.gd']
cars = ['compact', 'pickup', 'classic', 'formula', 'kart', 'forklift', 'electric']
binaries = [f'game/assets/garage/cars_v1/{s}.scn' for s in cars]
geometry = {str(p.relative_to(root)).replace('\\', '/'): sha(p) for p in sorted((root / 'game/vehicle').glob('*.gd')) if p.name in ['car_visual.gd', 'vehicle_models.gd', 'visual_geometry.gd'] or p.name.startswith(('compact_', 'electric_', 'kart_', 'forklift_'))}
provenance = {'schema': 'garage-rest-v1', 'engine': read(root / 'godot-version.txt').strip(), 'origin': 'Serialized rest poses of the original project-authored native car builders. No external model, artwork, AI generation or new dependency.', 'command': 'python docs/evidence/garage-cold-opening-2026-10-26/run_checks.py final-model-bake bake_garage_cars.gd headless', 'sources_sha256': geometry, 'artifacts': {f: {'bytes': (root / f).stat().st_size, 'sha256': sha(root / f)} for f in binaries}, 'validation': 'test_garage_prepared_cars.gd compares exact node matrices, surface arrays, material values and texture bytes plus independent paint ownership for all seven vehicles. Re-bake and validate before exporting changed model sources.'}
(root / 'game/assets/garage/cars_v1/provenance.json').write_text(json.dumps(provenance, indent=2) + '\n', encoding='utf-8')

marker = 'GARAGE-COLD-OPENING-20261026'
summary = '''<!-- GARAGE-COLD-OPENING-20261026 -->
## Responsive Garage opening with live 3D (2026-10-26)
GCO01-GCO04/R01/Q01: Owner prefers live 3D but prioritizes responsiveness. Normal Garage opens before studio construction, with seven nonblank stock cards and a brief picture before live actual geometry uses temporary light finishes. Original finishes/reflections prepare after 750ms without input; orbit and tools remain usable, latest selection/deferred intent/account fences remain, and ready studio is retained. Seven exact native rest-pose resources share meshes and isolate paint; local stale/unsupported cases use the original builder. Fresh desktop Compatibility callback68ms/page482ms/live2.45s/orbit16.7ms; desktop Mobile68ms/866ms/6.07s/9.7ms. Native construction waits for the incoming picture draw. Cold idle compilation still spikes1.78/0.61s: no instant/hitch-free or phone claim. Exact models28, early tools2504headless/2505Compatibility/2505desktopMobile, App141, retained audit253headless/266Compatibility and carousel38headless/47Compatibility pass; final focused/parser counts are in the report. Initial shader/serialization/lifetime/pose/fixture failures remain. Room copies are world-owned; exact pose/uniform/resource guards pass. Commands, native views, provenance, hashes and scoped binary-inclusive checkpoint: docs/GARAGE_COLD_OPENING_2026_10_26.md and docs/evidence/garage-cold-opening-2026-10-26/report.json. Reload and owner/device latency/appearance/input acceptance remain. No attachment/device test, APK, purchase/authentication, owner-save/live mutation, deployment, staging/commit or owner-process restart. Concurrent work preserved.
<!-- /GARAGE-COLD-OPENING-20261026 -->

'''
license_note = '''<!-- GARAGE-COLD-OPENING-20261026 -->
Garage rest-pose resources (2026-10-26, GCO03): the seven compressed PackedScenes under game/assets/garage/cars_v1 serialize the project's existing original native vehicle builders and material roles for Garage opening. ImmediateMesh surfaces are stored as equivalent ArrayMesh arrays. No external model, generated-provider image, logo, new licence or runtime dependency is added. Exact source/artifact hashes and rebuild instructions: game/assets/garage/cars_v1/provenance.json. Native equivalence/ownership checks and review captures: docs/GARAGE_COLD_OPENING_2026_10_26.md.
<!-- /GARAGE-COLD-OPENING-20261026 -->

'''
docs = ['AGENTS.md', 'DEVELOPMENT_STATUS.md', 'licenses/ASSETS.md']
for f in docs:
    path = root / f
    data = path.read_bytes()
    begin = ('<!-- ' + marker + ' -->').encode()
    end_marker = ('<!-- /' + marker + ' -->').encode()
    if begin in data:
        a = data.index(begin); b = data.index(end_marker, a) + len(end_marker)
        if data[b:b+2] == b'\n\n': b += 2
        data = data[:a] + data[b:]
    prefix = license_note if f.startswith('licenses/') else summary
    path.write_bytes(prefix.encode('utf-8') + data)

def remove_once(text, part, replacement=''):
    assert text.count(part) == 1, part[:150]
    return text.replace(part, replacement, 1)

def base_for(f, after):
    if f in new:
        return ''
    if f in docs:
        start = after.index('<!-- ' + marker + ' -->')
        end = after.index('<!-- /' + marker + ' -->', start) + len('<!-- /' + marker + ' -->')
        if after[end:end + 2] == '\n\n': end += 2
        return after[:start] + after[end:]
    if f == 'game/core/app.gd':
        after = remove_once(after, '\tpage.progressive_entry = true\n')
        after = remove_once(after, '\tpage.opening_can_begin = func() -> bool: return menu_page_motion==null or not menu_page_motion.is_running()\n')
        return remove_once(after, '\tpreload("res://ui/garage_preview_cache.gd").prefetch_catalogue(get_tree())\n')
    if f == 'game/vehicle/car_visual.gd':
        after = remove_once(after, 'var garage_template: bool = false\n')
        start = after.index('\tif garage_template and preload("res://ui/garage_car_cache.gd").restore(self):')
        end = after.index('\tif preload("res://vehicle/prepared_car_cache.gd").restore(self):', start)
        return after[:start] + after[end:]
    if f == 'game/ui/garage_page.gd':
        after = remove_once(after, 'var progressive_entry: bool=false\nvar opening_can_begin: Callable\nvar _opening_section: String=""\n')
        after = remove_once(after, '\tif progressive_entry: showroom.can_begin_studio=opening_can_begin\n')
        after = remove_once(after, '\tshowroom = preload("res://ui/garage_opening_showroom.gd").new() if progressive_entry else CarShowroom.new()\n\tif progressive_entry: showroom.studio_prepared.connect(_studio_prepared)\n\tif progressive_entry: showroom.studio_interactive.connect(_studio_prepared)\n', '\tshowroom = CarShowroom.new()\n')
        after = remove_once(after, '\t\t_preview_service.can_render=func() -> bool: return not progressive_entry or not showroom.preparing\n')
        start = after.index('func _studio_prepared() -> void:')
        end = after.index('func _show_section(next: String) -> void:', start)
        after = after[:start] + after[end:]
        return remove_once(after, '\tif progressive_entry and is_instance_valid(showroom) and showroom.preparing and not showroom.interaction_ready and next not in ["cars","news","achievements"]:\n\t\t_opening_section=next\n\t\treturn\n\t_opening_section=""\n')
    if f == 'game/ui/garage_preview_cache.gd':
        return read(root / 'docs/evidence/menu-responsiveness-2026-10-26/task-final' / f)
    if f in adapted:
        # Exact fixture start retained separately from readiness/output changes.
        if f.endswith('test_garage_entry_carousel.gd'):
            after = remove_once(after, '\tvar music: GameSoundtrack=GameSoundtrack.instance()\n\tmusic.music_enabled=false\n\tmusic.menu_player.stop()\n\tmusic.menu_player.stream=null\n')
            after = remove_once(after, '\tfor arg: String in OS.get_cmdline_user_args():\n\t\tif arg.begins_with("--output="): output=arg.trim_prefix("--output=")\n')
            after = remove_once(after, '\tif page.progressive_entry:\n\t\twhile page.showroom.preparing: await process_frame\n\t\tawait frames(2)\n')
            after = remove_once(after, '\tcheck(page.showroom.find_children("*","SubViewport",true,false).size()==3,"main live studio owns exactly three viewports after preparation")\n\tif DisplayServer.get_name()=="headless":\n\t\tcheck(page.find_children("*","SubViewport",true,false).size()==3,"one live Garage retains exactly three viewports")\n')
            after = remove_once(after, '\t\tcheck(page.find_children("*","SubViewport",true,false).size()==3,"one live Garage retains exactly three viewports")\n')
            return remove_once(after, '\tawait frames(2)\n\tmetrics.first_garage_draw_ms', '\tcheck(page.find_children("*","SubViewport",true,false).size()==3,"one live Garage retains exactly three viewports")\n\tawait frames(2)\n\tmetrics.first_garage_draw_ms')
        return remove_once(after, '\tif page.progressive_entry:\n\t\twhile view.preparing: await process_frame\n\t\tawait frames(2)\n')
    return read(e / 'before' / f)

patch = []
for f in runtime + adapted + docs + new:
    after = read(root / f)
    before = base_for(f, after)
    target = e / 'checkpoint-base' / f
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(before, encoding='utf-8', newline='\n')
    target = e / 'task-final' / f
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_bytes((root / f).read_bytes())
    patch.append(f'diff --git a/{f} b/{f}\n')
    if f in new: patch.append('new file mode 100644\n')
    patch.extend(difflib.unified_diff(before.splitlines(True), after.splitlines(True), fromfile='/dev/null' if f in new else 'a/' + f, tofile='b/' + f))
for f in binaries:
    result = subprocess.run(['git', 'diff', '--no-index', '--binary', '--', 'NUL', f], cwd=root, capture_output=True)
    assert result.returncode == 1, result.stderr.decode(errors='replace')
    data = result.stdout.decode('utf-8').replace('a/NUL', 'a/' + f)
    patch.append(data)
(e / 'checkpoint.patch').write_text(''.join(patch), encoding='utf-8', newline='\n')
validation = subprocess.run(['git', 'apply', '--reverse', '--check', str(e / 'checkpoint.patch')], cwd=root, capture_output=True, text=True)
(e / 'checkpoint-check.json').write_text(json.dumps({'command': ['git', 'apply', '--reverse', '--check', str(e / 'checkpoint.patch')], 'exit_code': validation.returncode, 'stdout': validation.stdout, 'stderr': validation.stderr}, indent=2), encoding='utf-8')
assert validation.returncode == 0, validation.stderr
commands = []
for p in sorted(e.glob('*/command.json')):
    item = json.loads(read(p)); item['label'] = p.parent.name; commands.append(item)
metrics = {label: json.loads(read(e / label / 'report.json')) for label in ['presented-final-cold-compatibility', 'presented-final-cold-mobile', 'presented-final-warm-compatibility', 'presented-cold-headless']}
passing = ['complete-model-equivalence-final', 'presented-app', 'presented-final-cold-compatibility', 'presented-final-cold-mobile', 'presented-final-warm-compatibility', 'presented-cold-headless', 'complete-tools-headless', 'complete-tools-native', 'complete-tools-mobile', 'final-audit-headless', 'presented-audit', 'final-entry-headless-verified', 'presented-entry-clean', 'complete-parser-final']
indexed = {x['label']: x for x in commands}
for label in passing: assert indexed[label]['exit_code'] == 0, label
report = {'requirements': ['GCO01', 'GCO02', 'GCO03', 'GCO04', 'R01', 'Q01'], 'date': '2026-10-26', 'engine': read(root / 'godot-version.txt').strip(), 'runtime_scope': runtime + [f'game/ui/{s}.gd' for s in helpers], 'adapted_fixtures': adapted, 'new_files': new + binaries, 'source_sha256': {f: sha(root / f) for f in runtime + adapted + docs + new}, 'artifacts': provenance['artifacts'], 'metrics': metrics, 'clean_passing_runs': passing, 'commands': commands, 'checkpoint': {'path': 'checkpoint.patch', 'sha256': sha(e / 'checkpoint.patch'), 'includes_binary_artifacts': True, 'validation': 'checkpoint-check.json', 'scope': 'App/GaragePage/CarVisual bases retain concurrent changes and remove only this task. Prior final preview cache is the exact task-start base. Documentation bodies are preserved. Original snapshots and every diagnostic/failure log remain.'}, 'excluded_concurrent_source_sha256': {f: sha(root / f) for f in ['game/ui/profile_car.gd', 'game/ui/garage_environment.gd', 'game/ui/garage_reflections.gd', 'game/ui/garage_customisation_camera.gd', 'game/vehicle/vehicle_simulation.gd']}, 'limitations': ['Fresh native shader compilation still causes idle stalls (1.78s Compatibility / 0.61s desktop Mobile in final runs). A compilation already running cannot be interrupted by input.', 'The native page-picture draw is measured after the menu slide. Live view/full-finish timings and residual idle stalls are recorded in metrics.', 'Nondefault/stale stock geometry uses the existing procedural builder; export rebuild must re-bake and validate changed model sources.', 'No phone performance or instant/hitch-free opening claim. Existing complete studio is retained for revisits.', 'Earlier broad swipe/hero-title failures are documented in the preceding menu task; not rerun here.'], 'initial_failures': ['Profiling source-injection parse errors and concurrent backend parse state', 'ImmediateMesh serialization and default-livery reference setup', 'Unconsumed threaded resource loads at shutdown', 'Cold full finishes exposed during active input and first native target settling', 'Mobile navigation callback before stock photo prefetch', 'Tween progress copied before its update', 'Temporary room copies inserted into instantiated architecture caused shutdown resource errors; direct world ownership resolves actual App lifecycle', 'Setting a global matrix through the same parent introduced tiny wheel-transform differences; retain exact local matrix instead', 'Three-viewports fixture observed the allowed temporary carousel capture; original assertion retained at capture-idle boundary plus new main studio count', 'Retained carousel fixture music was disabled before startup reloaded settings; stopping its playback after startup resolves the audio-only shutdown warning without a production audio change', 'Visual review caught an outgoing Race screenshot labelled first Garage frame; native preparation now waits for the actual incoming picture draw and revised measurements use presented-* runs'], 'not_performed': ['device attachment check', 'physical-device test', 'APK/AAB', 'real authentication/purchase', 'owner-save/live backend mutation', 'deployment', 'Git staging/commit', 'owner-process restart']}
(e / 'report.json').write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
print(json.dumps({'checkpoint_bytes': (e / 'checkpoint.patch').stat().st_size, 'command_records': len(commands), 'clean_runs': len(passing), 'binary_bytes': sum(x['bytes'] for x in provenance['artifacts'].values()), 'validation_exit': validation.returncode}))
