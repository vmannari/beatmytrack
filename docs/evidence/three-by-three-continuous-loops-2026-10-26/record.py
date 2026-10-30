from pathlib import Path
import difflib
import hashlib
import json
import re
import subprocess

out = Path(__file__).resolve().parent
root = out.parents[2]


def read(path):
    data = path.read_bytes()
    return data.decode('utf-16' if data.startswith(b'\xff\xfe') else 'utf-8-sig', errors='replace')


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


initial = json.loads(read(out / 'task-start-hashes.json'))
runtime = 'game/ui/challenge_create.gd'
before = (out / 'task-start' / runtime).read_bytes()
current = (root / runtime).read_bytes()
assert current == before.replace(b'three-by-three-v7.png', b'three-by-three-v8.png')
unchanged = [name for name in initial if name != runtime]
for name in unchanged:
    assert digest(root / name) == initial[name], name

production = [runtime, 'game/assets/menu/challenges/three-by-three-v8.png', 'game/assets/menu/challenges/three-by-three-v8.png.import', 'game/assets/menu/challenges/three-by-three-continuous-loops-v8.json']
patch = ''.join(difflib.unified_diff(before.decode().splitlines(keepends=True), current.decode().splitlines(keepends=True), fromfile='a/' + runtime, tofile='b/' + runtime)).encode()
for name in production[1:]:
    result = subprocess.run(['git', 'diff', '--no-index', '--binary', '--', '/dev/null', name], cwd=root, capture_output=True)
    assert result.returncode == 1
    patch += result.stdout
(out / 'task-only.patch').write_bytes(patch)
reverse = subprocess.run(['git', 'apply', '--reverse', '--check', str(out / 'task-only.patch')], cwd=root, capture_output=True)
assert reverse.returncode == 0, reverse.stderr.decode()

runs = {}
for label in ['import', 'poster-gl_compatibility', 'poster-mobile']:
    folder = out / label
    record = json.loads(read(folder / 'command.json'))
    assert record['exit_code'] == 0, label
    if label != 'import':
        text = read(folder / 'console.log')
        match = re.search(r'CHALLENGE_POSTER: (\d+) existing format checks, (\d+) failures', text)
        assert match and match.groups() == ('39', '0')
        record.update({'checks': 39, 'failures': 0})
    runs[label] = record

report = {
    'date': '2026-10-26',
    'request': 'Fix the grass and winter biome tracks, they are not continuous loops',
    'requirements': {'CL01': 'Grass circuit visibly forms one uninterrupted loop', 'CL02': 'Winter circuit visibly forms one uninterrupted loop', 'CL03': 'Retain three tracks, three tickets and existing poster integration'},
    'production_files': {name: {'sha256': digest(root / name), 'bytes': (root / name).stat().st_size} for name in production},
    'preserved_task_start_hashes': {name: initial[name] for name in unchanged},
    'runtime_delta': 'Only one POSTERS path changes v7 to v8. Existing card drawing/layout and challenge behavior remain exact task-start bytes.',
    'asset': {'source_dimensions': [1254, 1254], 'lossless_runtime_size_limit': 1024, 'mipmaps': True, 'exact_prompts_and_provenance': production[3]},
    'visual_review': ['Grass asphalt follows one visible closed ring with a continuous back straight and joined end curves.', 'Winter asphalt follows one visible closed ring; the central mountain is replaced by a low snowy infield to expose the back straight.', 'No road junctions, stubs or gaps are visible in the corrected rings.', 'Three circuit islands, the desert circuit and three foreground tickets remain.', 'This is visual review of an illustration; native checks verify integration/layout, not road topology.'],
    'rejected_draft': {'path': 'first-edit-winter-obscured.png', 'reason': 'Grass was corrected but the central mountain still obscured the winter back straight. A second targeted edit removed the obstruction.'},
    'sizes': [[1280, 720], [1440, 900], [960, 540], [390, 844], [844, 390]],
    'actual_commands': runs,
    'capture_scope': 'Original format-page assertions reused unchanged, stopping before track/car steps; selected and fully scrolled portrait captures retained.',
    'captures': {'compatibility': 'poster-gl_compatibility/captures/Windows-gl_compatibility', 'desktop_mobile': 'poster-mobile/captures/Windows-mobile'},
    'initial_failure': {'log': 'initial-native-copy-error.log', 'reason': 'Pinned import failed copying the native track-geometry hot-reload library. Retry succeeded; no library changes or existing-process restart.'},
    'checkpoint': {'path': 'task-only.patch', 'includes_binary_asset': True, 'reverse_check_exit': reverse.returncode, 'staged': False, 'committed': False},
    'limitations': ['Owner visual acceptance remains.', 'No physical-device attachment check or device test. Desktop Mobile is not a phone result.', 'No playable track geometry, physics, economy, account/save, live service or native library changes by this task.', 'No APK, real authentication/purchase, deployment, staging/commit/merge or owner-process restart.', 'The preceding artwork task retains its broader car-carousel failures; that unrelated suite was not rerun for this image-only correction.'],
}
(out / 'report.json').write_text(json.dumps(report, indent=2) + '\n')
print(json.dumps({'checks': {name: value.get('checks') for name, value in runs.items()}, 'failures': 0, 'patch_reverse_check': reverse.returncode}))
