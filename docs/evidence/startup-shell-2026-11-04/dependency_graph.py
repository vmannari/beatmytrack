"""Conservative source graph for eager class references and explicit preloads."""
from collections import deque
import json
from pathlib import Path
import re

root = Path(__file__).resolve().parents[3]
sources = {p.relative_to(root/'game').as_posix():p.read_text(encoding='utf-8-sig') for p in (root/'game').rglob('*.gd') if '.godot' not in p.parts}
classes = {}
for path,source in sources.items():
    match = re.search(r'^class_name (\w+)',source,re.M)
    if match and '/tests/' not in '/'+path: classes[match[1]] = path
graph = {}
for path,source in sources.items():
    # Quoted resource paths in preload/extends are parse dependencies. load()
    # paths are intentionally excluded from this static approximation.
    dependencies = set(re.findall(r'(?:preload\(|extends\s+)"res://([^"]+\.gd)"',source))
    for scene in re.findall(r'preload\("res://([^"]+\.tscn)"',source):
        text = (root/'game'/scene).read_text(encoding='utf-8')
        dependencies.update(re.findall(r'path="res://([^"]+\.gd)"',text))
    bare = re.sub(r'"(?:\\.|[^"\\])*"|\'(?:\\.|[^\'\\])*\'|#[^\n]*','',source)
    dependencies.update(classes[name] for name in re.findall(r'\b[A-Z]\w*\b',bare) if name in classes and classes[name]!=path)
    graph[path] = sorted(dependencies)

def route(start,target):
    pending = deque([[start]])
    seen = {start}
    while pending:
        path = pending.popleft()
        if path[-1]==target: return path
        for dependency in graph.get(path[-1],[]):
            if dependency not in seen:
                seen.add(dependency)
                pending.append(path+[dependency])
    return None

targets = ['core/game.gd','editor/editor_world.gd','editor/editor_canvas.gd','ui/garage_page.gd','ui/car_showroom.gd','vehicle/car_visual.gd']
print(json.dumps({start:{target:route(start,target) for target in targets} for start in ('core/app.gd','soundtrack/audio_world.gd')},indent=2))
