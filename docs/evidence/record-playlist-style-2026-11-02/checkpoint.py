"""Round-trip this style revision alone, preserving the rest of the working tree."""
from pathlib import Path
import hashlib
import json
import subprocess
import tempfile

root = Path(__file__).resolve().parents[3]
out = Path(__file__).resolve().parent
before = root / 'build/record-playlist-style-2026-11-02/before'
files = ['game/ui/garage_records_menu.gd', 'game/ui/garage_playlist_toggle.gd',
         'game/tests/test_record_playlist.gd', 'docs/RECORD_PLAYLIST_STYLE_2026_11_02.md',
         'AGENTS.md', 'docs/evidence/record-playlist-style-2026-11-02/run_native.py',
         'docs/evidence/record-playlist-style-2026-11-02/checkpoint.py']

def normalized(path):
    return path.read_text(encoding='utf-8').encode('utf-8')

old = {name: normalized(before / name) for name in files if (before / name).exists()}
new = {name: normalized(root / name) for name in files}
with tempfile.TemporaryDirectory(prefix='checkpoint-', dir=root / 'build/record-playlist-style-2026-11-02') as temporary:
    repo = Path(temporary)
    def git(*args):
        return subprocess.run(['git', '-c', 'core.autocrlf=false', *args], cwd=repo, check=True, capture_output=True).stdout
    def write(values):
        for name, data in values.items():
            target = repo / name
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(data)
    git('init', '-q')
    write(old)
    git('add', '--all')
    git('-c', 'user.name=Task checkpoint', '-c', 'user.email=checkpoint@localhost', 'commit', '-qm', 'Task-start sources')
    write(new)
    git('add', '--all')
    patch = git('diff', '--cached', '--binary', '--no-ext-diff')
    patch_path = out / 'task-only.patch'
    patch_path.write_bytes(patch)
    git('apply', '--reverse', '--check', str(patch_path))
    git('apply', '--reverse', str(patch_path))
    for name in files:
        target = repo / name
        assert (target.read_bytes() if target.exists() else None) == old.get(name), name
    git('apply', '--check', str(patch_path))
    git('apply', str(patch_path))
    assert all((repo / name).read_bytes() == data for name, data in new.items())
report = {'files': len(files), 'patch_sha256': hashlib.sha256(patch).hexdigest(),
          'forward_reverse_equal': True,
          'sources': {name: hashlib.sha256(data).hexdigest() for name, data in new.items()}}
(out / 'checkpoint.json').write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
print(f'Style checkpoint: {len(files)} files, forward/reverse normalized-text equality passed')
