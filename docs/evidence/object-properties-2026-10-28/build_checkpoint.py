"""Reconstruct a narrow review base while retaining concurrent surrounding work.

This is an inverse of owned UI changes, not a claim about the original checkout.
Never writes the repository's source files or main index.
"""
from pathlib import Path
import difflib
import hashlib
import json
import subprocess
import sys

OUT = Path(__file__).resolve().parent
ROOT = OUT.parents[2]
sys.path.insert(0, str(ROOT / 'scripts'))
import localization as loc

read = lambda name: (ROOT / name).read_text(encoding='utf-8')
base = {}
final = {}

name = 'game/core/app.gd'
current = read(name)
prior = current.replace('\tobject_browser.rotation_chosen.connect(_set_object_rotation)\n', '')
start = prior.index('func _selected_object_properties() -> void:')
end = prior.index('func _object_rotation() -> float:', start)
prior = prior[:start] + prior[end:]
old_app = (OUT / 'before/game/core/app.gd').read_text(encoding='utf-8')
start = old_app.index('\t\t\t_context_button("Rotate","rotate",_rotate_object)')
end = old_app.index('\t\t\tif canvas.issue_marker', start)
controls = old_app[start:end]
controls = '\n'.join(line for line in controls.splitlines()
                     if '_context_button("Copy"' not in line and '_context_button("Delete"' not in line
                     and 'jump_style_picker.gd' not in line) + '\n'
controls = ''.join('\t' + line if line.strip() else line for line in controls.splitlines(True))
start = prior.index('\t\t\t\tvar properties: Button = _context_button(')
end = prior.index('\t\t\telse:', start)
prior = prior[:start] + controls + prior[end:]
start = prior.index('func _choose_object(kind: String) -> void:')
end = prior.index('\nfunc ', start + 6)
chooser = prior[start:end]
begin = chooser.index('\n\tvar family:')
finish = chooser.index('\n\tcanvas.cancel_gesture()', begin)
chooser = chooser[:begin] + chooser[finish:]
chooser = chooser.replace('if not same_family: canvas.stamp_scale=', 'canvas.stamp_scale=')
chooser = chooser.replace('_object_placement(placement)', '_object_placement("single")')
prior = prior[:start] + chooser + prior[end:]
base[name], final[name] = prior, current

name = 'game/editor/object_browser.gd'
current = read(name)
prior = current.replace('const Properties = preload("res://editor/object_properties.gd")\n', '')
prior = prior.replace('signal rotation_chosen(angle: float)\n', '')
prior = prior.replace('var options: Properties', 'var options: PopupPanel')
prior = prior.replace('var properties_button: Button\n', '')
start = prior.index('\tproperties_button = _button(')
end = prior.index('\ttop.add_child(rotation_button)', start)
prior = prior[:start] + prior[end:]
original = (OUT / 'before/game/editor/object_browser.gd').read_text(encoding='utf-8')
start = original.index('\toptions=PopupPanel.new()')
end = original.index('\nfunc _scroll_row', start)
prior = prior.replace('\t_make_options()\n\trefresh()\n', original[start:end], 1)
start = original.index('func refresh() -> void:')
refresh = original[start:]
refresh = refresh.replace(',stamp_jump_profile', '')
start = refresh.find('\tif current == "jump":')
if start >= 0:
    end = refresh.index('\tvar family:', start)
    refresh = refresh[:start] + refresh[end:]
refresh = refresh.replace('if already_selected:', 'if already_selected and not CreatorCatalog.JUMP_ASSETS.has(kind):')
prior = prior[:prior.index('func refresh() -> void:')] + refresh
base[name], final[name] = prior, current

name = 'game/editor/object_thumbnail.gd'
final[name] = read(name)
base[name] = final[name].replace('Select, then open Properties', 'Tap selected asset for variants and placement')

for name in ['game/editor/object_properties.gd', 'game/tests/test_object_properties.gd',
             'scripts/translations/object_properties.tsv', 'docs/OBJECT_PROPERTIES_2026_10_28.md']:
    base[name], final[name] = '', read(name)

name = 'AGENTS.md'
final[name] = read(name)
start = final[name].index('<!-- OBJECT-PROPERTIES-20261028 -->')
end = final[name].index('<!-- /OBJECT-PROPERTIES-20261028 -->', start) + len('<!-- /OBJECT-PROPERTIES-20261028 -->\n\n')
base[name] = final[name][:start] + final[name][end:]

# Restore only the 23 owned translation entries in the virtual base.
owned = {row.split('|')[0] for row in read('scripts/translations/object_properties.tsv').splitlines() if row}
for language in ['fr','es','de','pt_BR','ja','ko','nl','it','fi','sv','nb']:
    name = 'game/localization/' + language + '.po'
    current = read(name)
    original = (OUT / 'before' / name).read_text(encoding='utf-8')
    original_blocks = {}
    for block in original.strip().split('\n\n'):
        original_blocks.update({key: block for key in loc.parse_po(block)})
    blocks = []
    for block in current.strip().split('\n\n'):
        entries = loc.parse_po(block)
        key = next(iter(entries))
        if key[0] == '' and key[1] in owned:
            if key in original_blocks:
                blocks.append(original_blocks[key])
        else:
            blocks.append(block)
    base[name], final[name] = '\n\n'.join(blocks) + '\n', current

patch = []
for name in final:
    patch.append('diff --git a/' + name + ' b/' + name + '\n')
    if not base[name]: patch.append('new file mode 100644\n')
    patch.extend(difflib.unified_diff(base[name].splitlines(True), final[name].splitlines(True),
                                     fromfile='a/' + name if base[name] else '/dev/null', tofile='b/' + name))
patch_path = OUT / 'task-source.patch'
patch_path.write_text(''.join(patch), encoding='utf-8', newline='\n')
workspace = OUT / 'checkpoint'
workspace.mkdir(exist_ok=True)
subprocess.run(['git', 'init', '--quiet', str(workspace)], check=True)
for name, content in base.items():
    path = workspace / name
    if content:
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(content, encoding='utf-8', newline='\n')
    elif path.exists():
        assert path.resolve().is_relative_to(workspace.resolve())
        path.unlink()
commands = []
for flags in [['--check'], [], ['--reverse', '--check']]:
    command = ['git', '-C', str(workspace), 'apply'] + flags + [str(patch_path)]
    subprocess.run(command, check=True, capture_output=True)
    commands.append(command)
for name, content in final.items():
    assert (workspace / name).read_text(encoding='utf-8') == content, name
result = dict(files=list(final), forward_check=True, applied_text_matches=True, reverse_check=True,
              commands=commands, patch_sha256=hashlib.sha256(patch_path.read_bytes()).hexdigest(),
              excluded=['concurrent surrounding changes', 'generated messages.pot/en.po', 'evidence images', 'build metadata'],
              base='reconstructed task-only inverse on final surrounding sources; not a historical checkout')
(OUT / 'checkpoint.json').write_text(json.dumps(result, indent=2), encoding='utf-8')
print(json.dumps(result))
