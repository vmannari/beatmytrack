"""Capture only this task's edits from the shared, already dirty workspace."""
from pathlib import Path
import difflib
import hashlib
import json
import re

ROOT = Path(__file__).resolve().parents[3]
OUT = Path(__file__).resolve().parent
BEFORE = OUT / 'before'


def read(path):
    return Path(path).read_text(encoding='utf-8-sig')


def substitute(text, old, new):
    assert text.count(old) == 1, old
    return text.replace(old, new, 1)


sources = [
    'game/core/app.gd', 'game/backend/challenges_client.gd',
    'game/ui/garage_page.gd',
    'game/ui/garage_reflections.gd', 'game/tests/test_app.gd',
    'game/tests/test_menu_high_priority.gd',
    'game/tests/test_menu_high_priority.gd.uid',
    'AGENTS.md', 'DEVELOPMENT_STATUS.md', 'docs/PHASE_0_PLAN.md',
]
patches = []
hashes = {}
for rel in sources:
    path = ROOT / rel
    current = read(path)
    hashes[rel] = hashlib.sha256(path.read_bytes()).hexdigest()
    if rel == 'AGENTS.md':
        baseline = re.sub(r'## High-priority menu performance and folder reliability override \(2026-10-14\)\n.*?\n\n', '', current, count=1, flags=re.S)
        assert baseline != current
    elif rel in ['DEVELOPMENT_STATUS.md', 'docs/PHASE_0_PLAN.md']:
        baseline = re.sub(r'^2026-10-14 MREV01-MREV02/[^\n]*\n\n', '', current, count=1)
        assert baseline != current
    elif 'test_menu_high_priority' in rel:
        baseline = ''
    elif rel.endswith('garage_reflections.gd'):
        baseline = substitute(current,
            '\t\t# Native viewport entry restores its inferred parent. A retained Garage\n'
            '\t\t# can move between menu slots, so reinstate the same explicit draw order.\n'
            '\t\tview.tree_entered.connect(_restore_parent.bind(view))\n', '')
        baseline = substitute(baseline,
            'func _restore_parent(view: SubViewport) -> void:\n'
            '\tif is_instance_valid(owner) and is_instance_valid(owner.showroom_viewport):\n'
            '\t\tRenderingServer.viewport_set_parent_viewport(view.get_viewport_rid(),owner.showroom_viewport.get_viewport_rid())\n\n', '')
    elif rel.endswith('garage_page.gd'):
        baseline = substitute(current,
            '\tif _selected_vehicle_id == VehicleCatalog.selected:\n'
            '\t\t# A retained page can outlive a race. Refresh changed thumbnail cosmetics\n'
            '\t\t# even when the confirmed car did not change; meshes/worlds stay intact.\n'
            '\t\t_refresh_thumbnails()\n\t\treturn\n',
            '\tif _selected_vehicle_id == VehicleCatalog.selected: return\n')
    else:
        baseline = read(BEFORE / (path.name + '.txt'))
    diff = list(difflib.unified_diff(baseline.splitlines(True), current.splitlines(True),
        fromfile='/dev/null' if not baseline else 'a/' + rel, tofile='b/' + rel))
    if rel == 'game/core/app.gd':
        # These two independent tasks edited app.gd during the same session.
        head = diff[:2]
        hunks = re.split(r'(?=^@@ )', ''.join(diff[2:]), flags=re.M)
        diff = head + [h for h in hunks if h and not any(
            token in h for token in ['appearance_provider', '_prepare_night_lighting', 'night_preparation'])]
    patches.append(''.join(diff))

(OUT / 'task-only.patch').write_text(''.join(patches), encoding='utf-8', newline='\n')
(OUT / 'source-hashes.json').write_text(json.dumps(hashes, indent=2) + '\n', encoding='utf-8')
print(json.dumps({'files': len(sources), 'patch_bytes': (OUT / 'task-only.patch').stat().st_size}))
