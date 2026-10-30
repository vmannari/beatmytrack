from pathlib import Path
import json, shutil, subprocess, hashlib, os, tempfile

root = Path.cwd()
lab = root / 'build/memory-drift-2026-10-26'
evidence = root / 'docs/evidence/memory-drift-2026-10-26'
review = lab / 'scoped-review'
base, final = [review / name for name in ['baseline', 'final']]
review.mkdir(parents=True, exist_ok=True)
verify = Path(tempfile.mkdtemp(prefix='verify-', dir=review))
for folder in [base, final, verify]:
    folder.mkdir(parents=True, exist_ok=True)
old = {
    'native/track_geometry/road_geometry.hpp': lab / 'task-baseline/road_geometry.hpp',
    'game/platform/track_geometry/track_geometry.gdextension': lab / 'task-baseline/track_geometry.gdextension',
    'game/platform/track_geometry/libbmt_track_geometry.android.arm64.so': lab / 'task-baseline/libbmt_track_geometry.android.arm64.so',
    'game/platform/track_geometry/libbmt_track_geometry.android.x86_64.so': lab / 'task-baseline/libbmt_track_geometry.android.x86_64.so',
    'game/tests/soak_runtime_correctness.gd': lab / 'task-baseline/soak_runtime_correctness.gd',
    'AGENTS.md': lab / 'task-baseline/AGENTS.md',
    'DEVELOPMENT_STATUS.md': lab / 'task-baseline/DEVELOPMENT_STATUS.md',
    'docs/RUNTIME_MEMORY_CORRECTNESS_FIXES_2026_10_26.md': lab / 'task-baseline/docs/RUNTIME_MEMORY_CORRECTNESS_FIXES_2026_10_26.md',
    'docs/evidence/runtime-correctness-2026-10-26/report.json': lab / 'task-baseline/docs/evidence/runtime-correctness-2026-10-26/report.json',
}
new = [
    'game/platform/track_geometry/bmt_track_geometry.windows.x86_64.3ac2a06f796a.dll',
    'game/tests/test_native_blend_memory.gd',
    'game/tests/test_native_blend_memory.gd.uid',
    'docs/MEMORY_DRIFT_INVESTIGATION_2026_10_26.md',
]
for name, src in old.items():
    target = base / name
    target.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(src, target)
    target = final / name
    target.parent.mkdir(parents=True, exist_ok=True)
    if name in ['AGENTS.md', 'DEVELOPMENT_STATUS.md']:
        marker = (lab / 'task-marker.txt').read_bytes()
        target.write_bytes(src.read_bytes() + b'\r\n\r\n' + marker)
        assert (root / name).read_bytes().endswith(marker)
    else:
        shutil.copyfile(root / name, target)
for name in new:
    target = final / name
    target.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(root / name, target)
report_path = evidence / 'report.json'
report = json.loads(report_path.read_text(encoding='utf-8'))
report['checkpoint'] = {
    'path': 'docs/evidence/memory-drift-2026-10-26/checkpoint.patch',
    'scope': 'Explicit task baseline/final trees; shared status files include only the appended investigation marker. Concurrent prepends and all unrelated runtime work excluded.',
    'verification': 'git apply --check, forward application, exact SHA256 tree comparison, reverse --check, reverse application and exact baseline comparison',
    'main_git_index_changed': False,
    'staging_or_commit': False,
    'soak_baseline': 'Reconstructed from the retained previous runtime-correctness checkpoint; normalized to its LF patch text. Other changed runtime/native files use direct task-baseline copies.',
}
report_path.write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
for src in evidence.rglob('*'):
    if src.is_file() and src.name != 'checkpoint.patch':
        target = final / src.relative_to(root)
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(src, target)
run = subprocess.run(['git', '-c', 'core.autocrlf=false', 'diff', '--no-index', '--binary', '--src-prefix=a/', '--dst-prefix=b/', 'baseline', 'final'], cwd=review, capture_output=True)
assert run.returncode == 1, run.stderr.decode(errors='replace')
lines = []
for line in run.stdout.splitlines(keepends=True):
    # Restrict path rewriting to headers; added source can contain these exact
    # literals, and binary payloads must remain untouched.
    if line.startswith((b'diff --git ', b'--- ', b'+++ ')):
        line = line.replace(b'a/baseline/', b'a/').replace(b'b/final/', b'b/').replace(b'a/final/', b'a/').replace(b'b/baseline/', b'b/')
    lines.append(line)
patch = b''.join(lines)
patch_path = evidence / 'checkpoint.patch'
patch_path.write_bytes(patch)
shutil.copytree(base, verify, dirs_exist_ok=True)

def apply(*args):
    environment = dict(os.environ, GIT_CEILING_DIRECTORIES=str(review))
    result = subprocess.run(['git', '-c', 'core.autocrlf=false', 'apply', *args, str(patch_path)], cwd=verify, env=environment, capture_output=True, text=True)
    assert result.returncode == 0, (args, result.stdout, result.stderr)

def tree(path):
    return {str(f.relative_to(path)): hashlib.sha256(f.read_bytes()).hexdigest() for f in path.rglob('*') if f.is_file()}

apply('--check')
apply()
assert tree(verify) == tree(final), 'forward tree differs'
apply('--reverse', '--check')
apply('--reverse')
assert tree(verify) == tree(base), 'reverse tree differs'
receipt = {'files': len(tree(final)), 'patch_bytes': len(patch), 'patch_sha256': hashlib.sha256(patch).hexdigest(), 'forward': 'exact', 'reverse': 'exact', 'root_index': 'untouched; no staging or commit'}
(lab / 'checkpoint-verification.json').write_text(json.dumps(receipt, indent=2) + '\n', encoding='utf-8')
print(json.dumps(receipt))
