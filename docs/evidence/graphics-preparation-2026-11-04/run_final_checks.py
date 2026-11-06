"""Run the final retained/native matrix serially, preserving each child receipt."""
from pathlib import Path
import subprocess
import sys

root = Path(__file__).resolve().parents[3]
runner = root/'docs/evidence/graphics-preparation-2026-11-04/run_check.py'
cases = [
    ('final-components-compat','res://tests/test_shared_graphics_preparation.gd',[]),
    ('final-buckets','res://tests/test_world_render_buckets.gd',['--headless','--timeout','45']),
    ('final-editor','res://tests/test_editor_graphics_preparation.gd',['--timeout','80']),
    ('final-warm','res://tests/test_garage_warm_scheduling.gd',['--timeout','180','--output=res://../docs/evidence/graphics-preparation-2026-11-04/final-warm']),
    ('final-garage','res://tests/test_shared_graphics_garage.gd',['--timeout','200']),
    ('final-header','res://tests/test_shared_graphics_header.gd',['--timeout','150']),
    ('final-thumbnails','res://tests/test_shared_graphics_thumbnails.gd',['--timeout','180']),
    ('final-entry','res://tests/test_garage_deferred_views.gd',['--timeout','300']),
    ('final-compat-laps','res://tests/test_shared_graphics_first_laps.gd',['--timeout','600','--first-emission']),
]
failed = []
for label,script,extra in cases:
    print('FINAL_CHECK_START',label,flush=True)
    result = subprocess.run([sys.executable,str(runner),label,script,*extra],cwd=root,check=False)
    print('FINAL_CHECK_END',label,result.returncode,flush=True)
    if result.returncode: failed.append(label)
print('FINAL_CHECK_FAILURES',failed,flush=True)
sys.exit(1 if failed else 0)
