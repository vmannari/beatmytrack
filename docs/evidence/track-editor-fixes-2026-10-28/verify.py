from pathlib import Path
import subprocess
import sys

root = Path.cwd()
out = root / 'docs/evidence/track-editor-fixes-2026-10-28'
jobs = [
    ('test_editor_review_items.gd', 'gl_compatibility', []),
    ('test_editor_review_items.gd', 'mobile', []),
    ('test_editor_graphics_preparation.gd', 'mobile', []),
    ('review_editor_fixed_items.gd', 'gl_compatibility', []),
    ('review_editor_fixed_items.gd', 'mobile', []),
    ('test_editor_workflow.gd', 'headless', []),
    ('test_editor_t05_t11.gd', 'headless', ['--editor-evidence=' + str(out / 'retained/t05')]),
    ('test_editor_t11_t15.gd', 'headless', ['--editor-evidence=' + str(out / 'retained/t11')]),
    ('test_editor_review_fixes.gd', 'headless', []),
    ('test_editor_preparation.gd', 'headless', []),
    ('test_creator_capacity.gd', 'headless', ['--capacity-evidence=' + str(out / 'capacity')]),
    ('test_compiler_raster.gd', 'headless', []),
    ('test_tyre_equivalence.gd', 'headless', []),
    ('test_script_parse.gd', 'headless', []),
]
for script, mode, args in jobs:
    subprocess.run([sys.executable, str(out / 'run_probe.py'), 'res://tests/' + script, mode, '--run-label=verification', *args], check=True)
