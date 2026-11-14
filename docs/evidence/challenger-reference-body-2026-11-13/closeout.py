"""Collect completed verification and the prescribed retention receipt."""
from pathlib import Path
import hashlib
import json
import shutil

ROOT = Path(__file__).resolve().parents[3]
OUT = Path(__file__).resolve().parent
labels = [
    'reference-final', 'hood-final', 'shading-final', 'fitted-final',
    'modules', 'physics', 'wash-final', 'driving-final', 'parser-final',
    'opaque-gl_compatibility', 'opaque-mobile',
    'app-gl_compatibility', 'app-mobile',
    'garage-gl_compatibility', 'garage-mobile',
    'garage-before-gl_compatibility', 'garage-before-mobile',
    'native-final', 'nose-contract', 'legacy-budget-control',
]
commands = {label: json.loads((OUT / (label + '-command.json')).read_text()) for label in labels}
assert all(receipt['exit_code'] == 0 for receipt in commands.values())
legacy = json.loads((OUT / 'geometry-final-command.json').read_text())
assert legacy['exit_code'] == 1
images = {str(p.relative_to(OUT)): hashlib.sha256(p.read_bytes()).hexdigest()
          for folder in ['garage-before', 'garage-final']
          for p in sorted((OUT / folder).rglob('*.png'))}
assert len(images) == 40
(OUT / 'comparison-images.json').write_text(json.dumps(images, indent=2))
(OUT / 'validation-summary.json').write_text(json.dumps({
    'qualified_commands': commands,
    'retained_legacy_relative_budget_failure': legacy,
    'reference_rejects_task_start': json.loads((OUT / 'before-reference.json').read_text())['failures'],
    'native_comparison_images': len(images),
}, indent=2))
shutil.copy2(ROOT / '.tmp/build-cleanup-last.json', OUT / 'build-cleanup.json')
task_build = ROOT / 'build/challenger-reference-body-2026-11-13'
(OUT / 'retention-limits.json').write_text(json.dumps({
    'prescribed_cleanup_completed': True,
    'direct_deletion_rejected': True,
    'stated_reason': 'blocked by policy',
    'rejected_actions': ['remove task build and duplicate draft directories', 'remove task .keep marker'],
    'task_build_remaining': task_build.exists(),
    'task_pin_remaining': (task_build / '.keep').exists(),
    'task_build_bytes': sum(p.stat().st_size for p in task_build.rglob('*') if p.is_file()),
    'duplicate_draft_images_remaining': True,
    'no_alternative_deletion_mechanism_used': True,
}, indent=2))
print('20 qualified commands, documented legacy failure, 40 native comparison images; retention receipt saved')
