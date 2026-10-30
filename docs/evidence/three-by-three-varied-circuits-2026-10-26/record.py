from pathlib import Path
import difflib
import hashlib
import json
import struct
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
assert current == before.replace(b'three-by-three-v8.png', b'three-by-three-v9.png')
for name in initial:
    if name != runtime:
        assert digest(root / name) == initial[name], name

production = [runtime, 'game/assets/menu/challenges/three-by-three-v9.png', 'game/assets/menu/challenges/three-by-three-v9.png.import', 'game/assets/menu/challenges/three-by-three-varied-circuits-v9.json']
asset = root / production[1]
metadata = root / production[3]
provenance = json.loads(read(metadata))
provenance.update({'source_dimensions': list(struct.unpack('>II', asset.read_bytes()[16:24])), 'source_sha256': digest(asset), 'source_bytes': asset.stat().st_size})
metadata.write_text(json.dumps(provenance, indent=2) + '\n', encoding='utf-8')

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
    record = json.loads(read(out / label / 'command.json'))
    assert record['exit_code'] == 0, label
    if label != 'import':
        assert 'CHALLENGE_POSTER: 39 existing format checks, 0 failures' in read(out / label / 'console.log')
        record.update({'checks': 39, 'failures': 0})
    runs[label] = record

report = {
    'date': '2026-10-26', 'request': 'now the tracks look too plain',
    'requirements': {'VT01': 'Forest circuit with hairpin, S-bends and varied radii', 'VT02': 'Distinct winding winter circuit with offset chicane', 'VT03': 'Keep continuous visible loops, three biomes and three tickets'},
    'production_files': {name: {'sha256': digest(root / name), 'bytes': (root / name).stat().st_size} for name in production},
    'preserved_task_start_hashes': {name: value for name, value in initial.items() if name != runtime},
    'runtime_delta': 'One POSTERS path changes v8 to v9. Existing card drawing/layout and challenge behavior remain exact task-start bytes.',
    'prompts_and_provenance': production[3],
    'visual_review': ['Forest has an asymmetric hairpin, tight S section and broad sweep instead of the plain oval.', 'Winter has a winding upper stretch and offset lower chicane with a different silhouette.', 'The forest connector is exposed after a targeted vegetation cleanup.', 'Three separate continuous circuit rings, the desert biome and all three tickets remain visible.', 'Visual review assesses route continuity/variety; UI checks assess integration and layout.'],
    'first_draft': {'path': 'first-draft-forest-connector.png', 'reason_for_refinement': 'Trees crowded the forest hairpin-to-S connector. The final edit clears the road while retaining the more varied route.'},
    'asset': {'dimensions': provenance['source_dimensions'], 'runtime_size_limit': 1024, 'mipmaps': True, 'compression': 'lossless'},
    'actual_commands': runs,
    'sizes': [[1280, 720], [1440, 900], [960, 540], [390, 844], [844, 390]],
    'capture_scope': 'Original format-page assertions reused unchanged; selected and fully scrolled portrait captures included. Ends before unrelated track/car steps.',
    'captures': {'compatibility': 'poster-gl_compatibility/captures/Windows-gl_compatibility', 'desktop_mobile': 'poster-mobile/captures/Windows-mobile'},
    'checkpoint': {'path': 'task-only.patch', 'includes_binary_asset': True, 'reverse_check_exit': reverse.returncode, 'staged': False, 'committed': False},
    'limitations': ['Owner appearance acceptance remains.', 'No device attachment check or device test; desktop Mobile is not a phone result.', 'Illustration only: no playable track geometry, physics, economy, account/save or native library edits.', 'No APK, real authentication/purchase, live mutation, deployment, staging/commit/merge or owner-process restart.', 'Earlier broader carousel failures remain in prior evidence; that unrelated suite was not rerun for an image-only correction.'],
}
(out / 'report.json').write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
print(json.dumps({'checks': {name: record.get('checks') for name, record in runs.items()}, 'failures': 0, 'patch_reverse_check': reverse.returncode}))
