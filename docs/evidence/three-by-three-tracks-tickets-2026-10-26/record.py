from pathlib import Path
import difflib
import hashlib
import json
import subprocess

out = Path(__file__).resolve().parent
root = out.parents[2]


def read(path):
    data = path.read_bytes()
    return data.decode('utf-16' if data.startswith(b'\xff\xfe') else 'utf-8-sig', errors='replace')


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


initial = json.loads(read(out / 'task-start-hashes.json'))
unchanged = ['game/ui/challenge_format_card.gd', 'game/assets/menu/challenges/three-by-three-v6.png', 'game/assets/menu/challenges/three-by-three-v6.png.import']
for name in unchanged:
    assert digest(root / name) == initial[name], name
runtime = 'game/ui/challenge_create.gd'
before = (out / 'task-start' / runtime).read_bytes()
current = (root / runtime).read_bytes()
assert current == before.replace(b'three-by-three-v6.png', b'three-by-three-v7.png')
full = read(out / 'gl_compatibility/console.log')
previous = read(out / 'previous-full.log')
failures = lambda text: [line for line in text.splitlines() if line.startswith('FAIL:')]
assert len(failures(full)) == 19 and failures(full) == failures(previous)

production = [runtime, 'game/assets/menu/challenges/three-by-three-v7.png', 'game/assets/menu/challenges/three-by-three-v7.png.import', 'game/assets/menu/challenges/three-by-three-tracks-tickets-v7.json']
patch = ''.join(difflib.unified_diff(before.decode().splitlines(keepends=True), current.decode().splitlines(keepends=True), fromfile='a/' + runtime, tofile='b/' + runtime)).encode()
for name in production[1:]:
    result = subprocess.run(['git', 'diff', '--no-index', '--binary', '--', '/dev/null', name], cwd=root, capture_output=True)
    assert result.returncode == 1
    patch += result.stdout
(out / 'task-only.patch').write_bytes(patch)
reverse = subprocess.run(['git', 'apply', '--reverse', '--check', str(out / 'task-only.patch')], cwd=root, capture_output=True)
assert reverse.returncode == 0, reverse.stderr.decode()

poster_runs = []
for path in sorted(out.glob('TestScript-*-poster.log')):
    text = read(path)
    if 'CHALLENGE_POSTER: 39' in text:
        assert '39 existing format checks, 0 failures' in text
        poster_runs.append({'renderer': 'mobile' if 'Forward Mobile' in text else 'gl_compatibility', 'checks': 39, 'failures': 0, 'log': path.name})
assert {run['renderer'] for run in poster_runs} == {'mobile', 'gl_compatibility'}
import_run = json.loads(read(out / 'import/command.json'))
assert import_run['exit_code'] == 0

base_command = 'powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/'
commands = [
    {'command': base_command + 'capture_three_by_three_poster.gd -Graphical -RenderingMethod gl_compatibility -RenderingDriver opengl3 -CommandTimeoutSeconds 60', 'exit_code': 0, 'fixture_appdata': 'build/three-by-three-tracks-tickets-2026-10-26/poster/user'},
    {'command': base_command + 'capture_three_by_three_poster.gd -Graphical -RenderingMethod mobile -RenderingDriver vulkan -CommandTimeoutSeconds 60', 'exit_code': 0, 'fixture_appdata': 'build/three-by-three-tracks-tickets-2026-10-26/poster-mobile/user'},
    {'command': base_command + 'capture_three_by_three_previous.gd -Graphical -RenderingMethod gl_compatibility -RenderingDriver opengl3 -CommandTimeoutSeconds 120', 'exit_code': 1, 'fixture_appdata': 'build/three-by-three-tracks-tickets-2026-10-26/previous/user'},
]
report = {
    'date': '2026-10-26',
    'requirements': {'TT01': 'Exactly three separate readable circuits', 'TT02': 'Exactly three visible physical tickets', 'TT03': 'Integrate in the current 3x3 format card with bounded mipmapped import'},
    'production_files': {name: {'sha256': digest(root / name), 'bytes': (root / name).stat().st_size} for name in production},
    'preserved_task_start_hashes': {name: initial[name] for name in unchanged},
    'runtime_delta': 'One dictionary entry changes three-by-three-v6.png to three-by-three-v7.png. Card layout/drawing and all challenge behavior remain exact task-start bytes.',
    'asset': {'dimensions': [1254, 1254], 'runtime_size_limit': 1024, 'mipmaps': True, 'compression': 'lossless', 'provenance_and_exact_prompt': production[3]},
    'focused_checks': poster_runs,
    'focused_scope': 'Original format-page assertions are reused unchanged and stop before track/car steps; selected/scrolled captures are added. This subset does not replace the full suite.',
    'sizes': [[1280, 720], [1440, 900], [960, 540], [390, 844], [844, 390]],
    'captures': {'current': 'poster/Windows-gl_compatibility', 'mobile': 'poster/Windows-mobile', 'previous': 'previous/Windows-gl_compatibility'},
    'full_suite': {'checks': 302, 'failures': 19, 'failure_messages': failures(full), 'log': 'gl_compatibility/console.log', 'command': json.loads(read(out / 'gl_compatibility/command.json'))},
    'previous_picture_suite': {'checks': 302, 'failures': 19, 'identical_failure_messages': True, 'method': 'Exact same retained full suite; only first fixture page texture substituted to v6 in memory. No assertion or production-source changes.', 'log': 'previous-full.log'},
    'actual_direct_capture_commands': commands,
    'capture_environment': 'BMT_CHALLENGE_CAPTURE_DIR points at the corresponding poster/previous evidence directory. APPDATA is isolated under build. Archived probes are temporarily restored by run.ps1 -Probe poster/previous.',
    'final_import': import_run,
    'initial_interruptions': ['Direct dev.ps1 invocation stopped by PowerShell execution policy.', 'Restricted imports denied Windows certificate-store access.', 'Initial test default user log access failed; only its exact remaining child fixture process was stopped after isolated replacement tests completed.', 'Pillow was unavailable for a source-dimension inspection; Python built-ins read the PNG header instead.'],
    'checkpoint': {'path': 'task-only.patch', 'binary_asset_included': True, 'reverse_check_exit': reverse.returncode, 'staged': False, 'committed': False},
    'limitations': ['Owner appearance/readability acceptance remains.', 'Device attachment not checked; no device test. Desktop Mobile is not a physical-device result.', 'No APK, real authentication/purchase, live service mutation, deployment, Git staging/commit/merge or owner-process restart.', 'Broader carousel/hero failures remain unchanged and outside this artwork task.'],
}
(out / 'report.json').write_text(json.dumps(report, indent=2) + '\n')
print(json.dumps({'poster_checks': poster_runs, 'full_and_previous': [302, 19], 'same_failures': True, 'import_exit': import_run['exit_code'], 'patch_reverse_check': reverse.returncode}))
