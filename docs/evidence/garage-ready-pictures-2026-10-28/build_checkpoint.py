from pathlib import Path
import difflib
import hashlib
import json
import re
import subprocess

ROOT = next(p for p in Path(__file__).resolve().parents if (p / 'godot-version.txt').exists())
OUT = Path(__file__).resolve().parent

def replace(text, after, before=''):
    assert text.count(after) == 1, (after[:140], text.count(after))
    return text.replace(after, before, 1)

def remove_function(text, name):
    match = re.search(r'^func ' + name + r'\(.*?(?=^func |\Z)', text, re.M | re.S)
    assert match, name
    return text[:match.start()] + text[match.end():]

def without_app_changes(text):
    text = replace(text, 'var _garage_picture_navigation: int=0\n')
    start = text.index('\t_show_screen("restoring")\n', text.index('func _ready()'))
    end = text.index('\ttutorial = preload(', start)
    old = (OUT / 'before/game/core/app.gd').read_text()
    old_start = old.index('\t_show_screen("restoring")\n', old.index('func _ready()'))
    old_end = old.index('\ttutorial = preload(', old_start)
    text = text[:start] + old[old_start:old_end] + text[end:]
    text = replace(text, '''\t_garage_picture_navigation+=1
\tif next=="garage" and DisplayServer.get_name()!="headless" and is_instance_valid(_garage_preloader) and not _garage_preloader.pictures_ready():
\t\tif screen=="garage" and is_instance_valid(_retained_garage) and _retained_garage.records!=records: _show_screen("restoring")
\t\t_open_garage_with_pictures(_garage_picture_navigation,records)
\t\treturn
''')
    text = replace(text, '''\tif menu_neighbors.has(direction) and menu_neighbors[direction].screen=="garage" and not _garage_pictures_ready():
\t\tfor neighbor: Dictionary in menu_neighbors.values(): neighbor.body.hide()
\t\tmenu_body.position.x=signf(distance)*64.0*(1.0-exp(-absf(distance)/160.0))
\t\tmenu_drag_offset=0.0
\t\treturn
''')
    text = replace(text, '''\tif menu_neighbors[direction].screen=="garage" and DisplayServer.get_name()!="headless" and not _garage_preloader.pictures_ready():
\t\t_stop_menu_edge_motion()
\t\t_show_screen("garage")
\t\treturn
''')
    text = replace(text, '''\t_garage_picture_navigation+=1
\tif next=="garage" and not _garage_pictures_ready():
\t\t_show_screen(next)
\t\treturn
''')
    text = replace(text, '''\tvar seen: Dictionary = {}
\tif is_instance_valid(_garage_preloader): result.merge(_garage_preloader.residency(seen))
\tif not is_instance_valid(_retained_garage): return result
''', '''\tif is_instance_valid(_garage_preloader): result.merge(_garage_preloader.residency())
\tif not is_instance_valid(_retained_garage): return result
\tvar seen: Dictionary = {}
''')
    text = replace(text, '''\tif not is_instance_valid(_retained_garage) or _retained_garage.is_visible_in_tree(): return
\t_discard_suspended_menu()
''', '''\tif not is_instance_valid(_retained_garage) or _retained_garage.is_visible_in_tree(): return
''')
    text = replace(text, '''\tfor direction: int in menu_neighbors.keys():
\t\tif menu_neighbors[direction].screen!="garage": continue
\t\tvar body: Control=menu_neighbors[direction].body
\t\tmenu_neighbors.erase(direction)
\t\tbody.get_parent().remove_child(body)
\t\tbody.queue_free()
''')
    for name in ['_open_garage_with_pictures', '_garage_pictures_ready', '_prepare_garage_pictures']:
        text = remove_function(text, name)
    text = replace(text, '''\tpage.prepared_pictures=_garage_preloader.picture_pool() if is_instance_valid(_garage_preloader) else {}
\tpage.car_pictures_ready=_garage_pictures_ready
\tpage.prepare_car_pictures=_prepare_garage_pictures
''')
    return text

def without_page_changes(text):
    text = replace(text, '''var prepared_pictures: Dictionary={}
var car_pictures_ready: Callable
var prepare_car_pictures: Callable
var _picture_section_request: int=0
''')
    text = replace(text, '''\t\t_preview_service.ready_pictures=prepared_pictures
\t\t_preview_service.remember_pictures=true
\t\t_preview_service.immediate_reads=true
''')
    text = replace(text, '\t\tif cached_carousel: model.refresh_thumbnail()\n')
    text = remove_function(text, '_show_ready_cars')
    text = replace(text, '''\t_picture_section_request+=1
\tif next=="cars" and car_pictures_ready.is_valid() and not car_pictures_ready.call():
\t\t_show_ready_cars(_picture_section_request)
\t\treturn
''')
    return text

runtime = ['game/core/app.gd', 'game/ui/garage_page.gd', 'game/ui/garage_preview_cache.gd',
           'game/ui/garage_preloader.gd', 'game/ui/garage_cached_thumbnail.gd']
paths = runtime + ['game/tests/test_garage_ready_pictures.gd', 'game/tests/test_garage_ready_pictures.gd.uid']
patch = ''
hashes = {}
for rel in paths:
    current = (ROOT / rel).read_text()
    if rel == 'game/core/app.gd':
        before = without_app_changes(current)
    elif rel == 'game/ui/garage_page.gd':
        before = without_page_changes(current)
    else:
        before_path = OUT / 'before' / rel
        before = before_path.read_text() if before_path.exists() else ''
    for directory, value in [('scope-baseline', before), ('after', current)]:
        target = OUT / directory / rel
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(value, encoding='utf-8', newline='\n')
    patch += ''.join(difflib.unified_diff(before.splitlines(keepends=True), current.splitlines(keepends=True),
                                        fromfile='a/' + rel if rel in runtime else '/dev/null', tofile='b/' + rel))
    hashes[rel] = hashlib.sha256((ROOT / rel).read_bytes()).hexdigest()
(OUT / 'task.patch').write_text(patch, encoding='utf-8', newline='\n')
commands = []
for command in [['git', 'apply', '--check', '--reverse', str(OUT / 'task.patch')]]:
    result = subprocess.run(command, cwd=ROOT, capture_output=True, text=True)
    commands.append(dict(command=command, exit_code=result.returncode, output=result.stdout + result.stderr))
    assert result.returncode == 0, commands[-1]
check_dir = ROOT / 'build/garage-ready-patch-check'
for rel in runtime:
    target = check_dir / rel
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_bytes((OUT / 'scope-baseline' / rel).read_bytes())
command = ['git', 'apply', '--check', '--directory=build/garage-ready-patch-check', str(OUT / 'task.patch')]
result = subprocess.run(command, cwd=ROOT, capture_output=True, text=True)
commands.append(dict(command=command, exit_code=result.returncode, output=result.stdout + result.stderr))
assert result.returncode == 0, commands[-1]
(OUT / 'checkpoint.json').write_text(json.dumps(dict(source_hashes=hashes, checks=commands,
    excluded='Concurrent App/editor/Rivalry and Garage workshop changes retained in the scope baseline.'), indent=2))
print(json.dumps(dict(files=paths, checks=commands)))
