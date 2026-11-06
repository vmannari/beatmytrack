"""Run only offline, task-owned probes against the frozen review project."""
import json
from pathlib import Path
import subprocess
import sys

OUT = Path(__file__).resolve().parent
PROJECT = Path(json.loads((OUT / 'frozen-project.json').read_text())['project'])

# Redirect this existing CPU microbenchmark's output without changing its work.
history = PROJECT / 'tests/profile_editor_fixed_history.gd'
original = history.read_text(encoding='utf-8')
history.write_text(original.replace(
    '"res://../docs/evidence/track-editor-fixes-2026-10-28/history-profile.json"',
    'OS.get_environment("BMT_LOADING_OUTPUT")'), encoding='utf-8')

cases = [
    ('graphics', 'test_graphics_settings.gd', []),
    ('budget', 'test_tablet_render_budget.gd', []),
    ('blend-memory', 'test_native_blend_memory.gd', []),
    ('editor-history', 'profile_editor_fixed_history.gd', []),
    ('startup-stock', 'profile_startup_shell.gd', ['--native']),
    ('startup-custom', 'profile_startup_shell.gd', ['--native', '--args', '--custom']),
    ('race-five-biomes', 'profile_first_use_graphics.gd', ['--native', '--timeout', '600']),
    ('garage-render', 'profile_garage_render_cost.gd', ['--native', '--timeout', '300', '--args', '--output=' + str(OUT / 'garage-render')]),
]
for name, script, extra in cases:
    command = [sys.executable, str(OUT / 'run_case.py'), name, script, '--project', str(PROJECT)] + extra
    result = subprocess.run(command, check=False)
    if result.returncode:
        print('RUNNER_FAILURE', name, result.returncode, flush=True)
        break
