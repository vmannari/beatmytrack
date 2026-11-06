"""Check this task's patch in an owned directory without writing the main index."""
import difflib
import hashlib
import json
from pathlib import Path
import subprocess
import time

evidence = Path(__file__).resolve().parent
root = evidence.parents[2]
runtime_changed = [
    'game/race/world_render_preparation.gd',
    'game/ui/garage_first_draw.gd',
    'game/ui/garage_preloaded_studio.gd',
    'game/ui/garage_opening_showroom.gd',
    'game/ui/header_car_appearance_cache.gd',
    'game/ui/garage_preview_cache.gd',
    'game/tests/test_world_render_buckets.gd',
]
trackers = ['AGENTS.md','DEVELOPMENT_STATUS.md']
added = ['game/rendering/graphics_preparation.gd','docs/SHARED_GRAPHICS_PREPARATION_2026_11_04.md']
added += ['game/tests/'+name+'.gd' for name in (
    'graphics_control_scene','profile_shared_graphics_preparation',
    'test_shared_graphics_before_lap','test_shared_graphics_first_laps',
    'test_shared_graphics_garage','test_shared_graphics_header',
    'test_shared_graphics_lifecycle','test_shared_graphics_preparation',
    'test_shared_graphics_race_pixels','test_shared_graphics_thumbnails')]
added += [path.relative_to(root).as_posix() for path in sorted((evidence/'before').rglob('*')) if path.is_file()]
added += [(evidence/name).relative_to(root).as_posix() for name in (
    'run_check.py','run_final_checks.py','summarize.py','compare_pngs.py','checkpoint.py')]
marker = '<!-- SHARED-GRAPHICS-PREPARATION-20261104 -->'
end_marker = '<!-- /SHARED-GRAPHICS-PREPARATION-20261104 -->'
before, after, parts = {}, {}, []
for path in runtime_changed+trackers+added:
    new = (root/path).read_bytes().replace(b'\r\n',b'\n')
    old = b''
    if path in runtime_changed:
        old = (evidence/'before'/path).read_bytes().replace(b'\r\n',b'\n')
    elif path in trackers:
        # Preserve concurrent tracker updates identically on both patch sides.
        text = new.decode('utf-8')
        assert text.count(marker)==1 and text.count(end_marker)==1
        start = text.index(marker)
        end = text.index(end_marker)+len(end_marker)
        if text[end:end+2]=='\n\n': end += 2
        elif text[end:end+1]=='\n': end += 1
        old = (text[:start]+text[end:]).encode('utf-8')
    before[path], after[path] = old, new
    parts.append(f'diff --git a/{path} b/{path}\n')
    if path in added: parts.append('new file mode 100644\n')
    parts.extend(difflib.unified_diff(old.decode().splitlines(keepends=True),new.decode().splitlines(keepends=True),
        fromfile='/dev/null' if path in added else 'a/'+path,tofile='b/'+path))
patch = evidence/'task.patch'
patch.write_bytes(''.join(parts).encode())
owned = root/'build/graphics-preparation-20261104'/('checkpoint-'+str(time.time_ns()))
owned.mkdir(parents=True)
assert owned.resolve().is_relative_to((root/'build/graphics-preparation-20261104').resolve())
for path in runtime_changed+trackers:
    target = owned/path
    target.parent.mkdir(parents=True,exist_ok=True)
    target.write_bytes(before[path])
commands = []
for arguments in (('--check',),(),('--reverse','--check'),('--reverse',)):
    command = ['git','apply','--directory='+owned.relative_to(root).as_posix(),*arguments,str(patch)]
    result = subprocess.run(command,cwd=root,capture_output=True,text=True)
    commands.append(dict(command=command,exit_code=result.returncode,output=result.stdout+result.stderr))
    assert result.returncode==0,result.stderr
    if arguments==():
        assert all((owned/path).read_bytes().replace(b'\r\n',b'\n')==after[path] for path in after)
assert all((owned/path).read_bytes().replace(b'\r\n',b'\n')==before[path] for path in runtime_changed+trackers)
assert all(not (owned/path).exists() for path in added)
report = dict(files=list(after),forward_content_exact=True,reverse_content_exact=True,main_index_written=False,
    patch_sha256=hashlib.sha256(patch.read_bytes()).hexdigest(),commands=commands,
    source_sha256={path:hashlib.sha256(after[path]).hexdigest() for path in after})
(evidence/'checkpoint.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
print('Task-only patch forward/reverse/content checks pass; main index unchanged.')
