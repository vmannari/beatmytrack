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
marker = 'GARAGE-LIVE-ENTRY-20261027'
summary = '''<!-- GARAGE-LIVE-ENTRY-20261027 -->
## Original live Garage restored from entry (2026-10-27)
GLE01-GLE03/R01/Q01: Owner rejects wrong liveries and immovable first Garage after optimisation. Remove the production App's photo-first/progressive-entry selection; original CarShowroom now builds the actual saved car and connects drag immediately. Saved colours/pattern/sticker and all seven native previews, viewport-routed touch, actual changed pixels, retained returns and owner/save fences pass. Original lighting/glass/shadows/reflections/camera remain; no alternate finishes. Task-start5checks/4fail becomes46headless/50Compatibility/50desktopMobile; retained App141/reflections26/parser1321 pass. Cached-process first live2.68sCompatibility/1.63sdesktopMobile; fresh27.55/7.36s retains cold driver stalls, with no instant/phone claim. This supersedes the stock-cover/deferred-entry contract, preserving original quality. Runtime behavior scope is two App assignments; original showroom/cache/model sources remain exact, concurrent work and generated build metadata excluded from the scoped patch. Commands, native views, hashes and checkpoint: docs/GARAGE_LIVE_ENTRY_2026_10_27.md and docs/evidence/garage-live-entry-2026-10-27/report.json. Reload and owner/device appearance/input/latency acceptance remain. No attachment/device test, APK, auth/purchase, owner-save/live mutation, deployment, main-index staging/commit/merge or owner-process restart.
<!-- /GARAGE-LIVE-ENTRY-20261027 -->

'''
docs = ['AGENTS.md', 'DEVELOPMENT_STATUS.md']
for f in docs:
    p = root / f
    content = p.read_bytes()
    begin, end = ('<!-- ' + marker + ' -->').encode(), ('<!-- /' + marker + ' -->').encode()
    if begin in content:
        a = content.index(begin); b = content.index(end, a) + len(end)
        if content[b:b+2] == b'\n\n': b += 2
        content = content[:a] + content[b:]
    p.write_bytes(summary.encode('utf-8') + content)

new = ['game/tests/test_garage_live_entry.gd', 'docs/GARAGE_LIVE_ENTRY_2026_10_27.md', 'docs/evidence/garage-live-entry-2026-10-27/run_checks.py', 'docs/evidence/garage-live-entry-2026-10-27/compile_report.py']
if (root / 'game/tests/test_garage_live_entry.gd.uid').exists(): new.append('game/tests/test_garage_live_entry.gd.uid')
patch = []
files = ['game/core/app.gd'] + docs + new
for f in files:
    after = read(root / f)
    if f in new:
        before = ''
    elif f in docs:
        a = after.index('<!-- ' + marker + ' -->'); b = after.index('<!-- /' + marker + ' -->', a) + len('<!-- /' + marker + ' -->')
        if after[b:b+2] == '\n\n': b += 2
        before = after[:a] + after[b:]
    else:
        before = after.replace('\t# Use the original interactive showroom with the saved appearance on entry.\n', '', 1)
        anchor = '\tpage.cached_carousel = true\n'
        assert before.count(anchor) == 1
        before = before.replace(anchor, anchor + '\tpage.progressive_entry = true\n\tpage.opening_can_begin = func() -> bool: return menu_page_motion==null or not menu_page_motion.is_running()\n', 1)
    dest = e / 'checkpoint-base' / f
    dest.parent.mkdir(parents=True, exist_ok=True); dest.write_text(before, encoding='utf-8', newline='\n')
    dest = e / 'task-final' / f
    dest.parent.mkdir(parents=True, exist_ok=True); shutil.copyfile(root / f, dest)
    patch.append(f'diff --git a/{f} b/{f}\n')
    if f in new: patch.append('new file mode 100644\n')
    patch.extend(difflib.unified_diff(before.splitlines(True), after.splitlines(True), fromfile='/dev/null' if f in new else 'a/' + f, tofile='b/' + f))
(e / 'checkpoint.patch').write_text(''.join(patch), encoding='utf-8', newline='\n')
check = subprocess.run(['git', 'apply', '--reverse', '--check', str(e / 'checkpoint.patch')], cwd=root, text=True, capture_output=True)
(e / 'checkpoint-check.json').write_text(json.dumps({'exit_code': check.returncode, 'stdout': check.stdout, 'stderr': check.stderr}, indent=2), encoding='utf-8')
assert check.returncode == 0, check.stderr
commands = {p.parent.name: json.loads(read(p)) for p in sorted(e.glob('*/command.json'))}
passing = ['routed-input-headless', 'routed-input-native', 'routed-input-mobile', 'retained-app', 'retained-reflections', 'parser', 'preferred-check']
for label in passing: assert commands[label]['exit_code'] == 0, label
preserved = [f for f in json.loads(read(e / 'before/hashes.json')) if f != 'game/core/app.gd']
generated = ['game/core/build_identity.gd', 'game/project.godot']
for f in generated:
    p = e / 'generated-metadata' / f
    p.parent.mkdir(parents=True, exist_ok=True); shutil.copyfile(root / f, p)
report = {'requirements': ['GLE01', 'GLE02', 'GLE03', 'R01', 'Q01'], 'engine': read(root / 'godot-version.txt').strip(), 'date': '2026-10-27', 'behavior_scope': ['game/core/app.gd'], 'source_sha256': {f: sha(root / f) for f in files}, 'preserved_sources': {f: {'sha256': sha(root / f), 'matches_task_start': sha(root / f) == sha(e / 'before' / f)} for f in preserved}, 'generated_metadata': {f: sha(root / f) for f in generated}, 'generated_note': 'Preferred dev.ps1 CheckScript runs its deterministic identity/version generation. Resulting metadata and receipt are recorded separately from the source-only rollback. Concurrent simulation work is preserved and excluded.', 'commands': commands, 'passing_runs': passing, 'task_start_regression': {'checks': 5, 'failures': 4}, 'results': {'focused_headless': 46, 'focused_compatibility': 50, 'focused_desktop_mobile': 50, 'app': 141, 'reflections': 26, 'parser': 1321}, 'timings': {label: json.loads(read(e / label / 'report.json'))['timings'] for label in ['fixed-native', 'fixed-mobile', 'routed-input-native', 'routed-input-mobile']}, 'checkpoint': {'path': 'checkpoint.patch', 'sha256': sha(e / 'checkpoint.patch'), 'reverse_check_exit_code': check.returncode}, 'limitations': ['Cold original driver compilation remains: fresh first live page 27.55s Compatibility / 7.36s desktop Mobile in isolated tests; reused shader profiles 2.68s / 1.63s.', 'No instant-entry, 250ms synchronous callback or phone performance claim.', 'Earlier photo-first fixtures describe the optional historical helper; this task explicitly supersedes that production entry contract.', 'Small carousel cards retain catalogue fallbacks while exact saved thumbnails resolve; the main view is native from entry.', 'No native engine/shader workaround or renderer quality reduction is introduced.'], 'not_performed': ['physical-device attachment check/test', 'APK/AAB', 'real authentication/purchase', 'owner-save/live backend mutation', 'deployment', 'Git staging/commit/merge', 'owner-process restart']}
(e / 'report.json').write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
print(json.dumps({'commands': len(commands), 'clean_passing_runs': len(passing), 'patch_check_exit': check.returncode, 'patch_bytes': (e / 'checkpoint.patch').stat().st_size}))
