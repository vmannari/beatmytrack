"""Read-only candidate inventory; lexical results require caller/lifecycle review."""
from pathlib import Path
from collections import defaultdict
import ast
import hashlib
import json
import re

ROOT = next(p for p in Path(__file__).resolve().parents if (p / 'game/project.godot').is_file())
OUT = ROOT / 'build/obsolete-code-review-2026-11-12'
OUT.mkdir(parents=True, exist_ok=True)
EXCLUDE = {'.godot', 'build', 'tmp', 'android', 'assets', 'docs', 'recordings-track_24a7b3eff3f1171709e95583e27a6d47', 'recordings-track_64dd8cd984edad8101677bd0ad3414a0', 'recordings-track_93193b9743774498cff3098a9749be3b'}
EXTENSIONS = {'.gd', '.tscn', '.tres', '.godot', '.cfg', '.gdextension', '.py', '.ps1', '.js', '.json', '.sh', '.cpp', '.h', '.kt', '.java'}
files = {}
for base in ['game', 'backend/bmt_backend', 'backend/tests', 'scripts', 'native']:
    for p in (ROOT / base).rglob('*'):
        if not p.is_file() or p.suffix not in EXTENSIONS:
            continue
        parts = p.relative_to(ROOT).parts
        if any(x in EXCLUDE or x in {'__pycache__', '.venv', 'node_modules'} for x in parts):
            continue
        files[p.relative_to(ROOT).as_posix()] = p.read_text(encoding='utf-8-sig', errors='replace')

def production(path):
    return path.startswith('game/') and not any(x in path.split('/') for x in ['tests', 'diagnostics'])

tokens = defaultdict(list)
resources = defaultdict(list)
for path, source in files.items():
    for n, line in enumerate(source.splitlines(), 1):
        for token in set(re.findall(r'\b[A-Za-z_]\w*\b', line)):
            tokens[token].append((path, n, line.strip()))
        for resource in set(re.findall(r'res://[^\s\"\'\)\],;]+', line)):
            resources[resource].append((path, n, line.strip()))

single = []
test_only = []
orphans = []
functions = []
for path, source in files.items():
    if not production(path) or not path.endswith('.gd'):
        continue
    for m in re.finditer(r'^(?:static )?func (\w+)\(', source, re.M):
        name = m[1]
        n = source.count('\n', 0, m.start()) + 1
        definitions = re.compile(r'^(?:static )?func ' + name + r'\(')
        refs = [r for r in tokens[name] if not definitions.match(r[2])]
        row = {'path': path, 'line': n, 'name': name, 'refs': refs}
        functions.append(row)
        if not refs:
            single.append(row)
        elif not any(production(r[0]) for r in refs):
            test_only.append(row)
    cls = re.search(r'^class_name (\w+)', source, re.M)
    resource = 'res://' + path[len('game/'):]
    refs = [r for r in resources[resource] if r[0] != path]
    if cls:
        refs += [r for r in tokens[cls[1]] if r[0] != path]
    if not refs:
        orphans.append({'path': path, 'class': cls[1] if cls else None})

backend_single = []
for path, source in files.items():
    if not path.startswith('backend/bmt_backend/') or not path.endswith('.py') or '/migrations/' in path:
        continue
    try:
        tree = ast.parse(source)
    except SyntaxError:
        continue
    for node in ast.walk(tree):
        if not isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef)) or node.decorator_list or node.name.startswith('__'):
            continue
        refs = [r for r in tokens[node.name] if not re.match(r'(?:async )?def ' + node.name + r'\(', r[2])]
        if not refs:
            backend_single.append({'path': path, 'line': node.lineno, 'name': node.name})

unused_members = []
for path, source in files.items():
    if not production(path) or not path.endswith('.gd'):
        continue
    for m in re.finditer(r'^(?:(?:static )?var|const|signal) (\w+)\b', source, re.M):
        if len(tokens[m[1]]) == 1:
            unused_members.append({'path': path, 'line': source.count('\n', 0, m.start()) + 1, 'name': m[1]})

result = {'method': 'Lexical candidates only: callbacks, dynamic paths and external callers need manual review.',
          'files': len(files), 'production_gd': sum(production(p) and p.endswith('.gd') for p in files),
          'function_definitions': len(functions), 'unreferenced_functions': single,
          'functions_referenced_only_outside_runtime': test_only, 'unreferenced_scripts': orphans,
          'backend_unreferenced_functions': backend_single,
          'unreferenced_members': unused_members,
          'sha256': {p: hashlib.sha256((ROOT / p).read_bytes()).hexdigest() for p in files if production(p) or p.startswith('backend/bmt_backend/')}}
(OUT / 'inventory.json').write_text(json.dumps(result, indent=2), encoding='utf-8')
for key in ['files', 'production_gd', 'function_definitions', 'unreferenced_scripts', 'backend_unreferenced_functions']:
    print(key, json.dumps(result[key]))
print('non_callback_unreferenced_functions')
for row in single:
    if row['name'] not in {'_ready', '_init', '_process', '_physics_process', '_draw', '_input', '_unhandled_input', '_gui_input', '_notification', '_exit_tree', '_enter_tree', '_get_minimum_size', '_shortcut_input', '_unhandled_key_input', '_to_string', '_get', '_set', '_get_property_list'}:
        print(row['path'], row['line'], row['name'])
print('test_only_count', len(test_only))
print('unreferenced_members', json.dumps(unused_members))
