"""Run the scoped acceptance matrix serially; preserve every attempt's receipt."""
from pathlib import Path
import subprocess
import sys

runner = Path(__file__).with_name('run_check.py')
cases = [
    ['final-focused-headless-v3', 'res://tests/test_daily_loading_overlap.gd', '--headless', '--timeout', '180'],
    ['final-focused-native-v2', 'res://tests/test_daily_loading_overlap.gd', '--timeout', '300'],
    ['before-focused-control-v2', 'res://tests/test_daily_loading_overlap.gd', '--headless', '--control'],
    ['final-timing-v3', 'res://tests/test_daily_loading_overlap.gd', '--headless', '--timing', '--timeout', '180'],
    ['final-worker-v2', 'res://tests/test_daily_loading_worker.gd', '--headless', '--timeout', '120'],
    ['final-daily-app', 'res://tests/test_daily_elimination_app.gd', '--headless', '--timeout', '120'],
    ['final-daily-metadata', 'res://tests/test_daily_metadata_catalog.gd', '--headless', '--timeout', '120'],
    ['final-daily-event', 'res://tests/test_daily_event_install.gd', '--headless', '--timeout', '120'],
    ['final-selected-events-v2', 'res://tests/test_selected_events.gd', '--headless', '--timeout', '180'],
]
results = []
for case in cases:
    completed = subprocess.run([sys.executable, str(runner), *case], check=False)
    results.append((case[0], completed.returncode))
print(results)
sys.exit(1 if any(code != (1 if label.startswith('before-focused-control') else 0) for label, code in results) else 0)
