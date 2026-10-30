"""Pinned offline Godot checks with task-owned logs and evidence destinations."""
from pathlib import Path
import json
import re
import subprocess
import sys

PHASE = next((arg.split('=', 1)[1] for arg in sys.argv[1:] if arg.startswith('--phase=')), '')

ROOT = Path(__file__).resolve().parents[3]
OUT = Path(__file__).resolve().parent
GODOT = Path('C:/apps/Godot 4.7.2/Godot_v4.7.2-stable_win64_console.exe')
DEFAULTS = ['electric_power_increment', 'electric_slide_access', 'electric_powered_drift',
            'electric_launch_drift', 'electric_character', 'electric_regen', 'electric_one_pedal',
            'electric_190', 'electric_car', 'electric_consistent_handling',
            'electric_steering_response', 'electric_turning', 'electric_corner_authority',
            'electric_normal_tracks', 'electric_over_under', 'handling', 'script_parse']


def run(name):
    destination = (OUT / PHASE / name) if PHASE else (OUT / name)
    destination.mkdir(parents=True, exist_ok=True)
    command = [str(GODOT), '--headless', '--path', str(ROOT / 'game'),
               '--log-file', str(destination / 'engine.log'), '--script',
               f'res://tests/test_{name}.gd', '--', f'--evidence-root={destination.as_posix()}']
    try:
        result = subprocess.run(command, cwd=ROOT, capture_output=True, text=True, timeout=240)
        log = result.stdout + result.stderr
        (destination / 'console.log').write_text(log, encoding='utf-8')
        summaries = [line for line in log.splitlines() if re.search(r'checks|assertions|failures|SCRIPT ERROR|FAIL:|Parse Error', line)]
        errors = [line for line in log.splitlines() if 'ERROR:' in line or 'WARNING:' in line]
        receipt = {'name': name, 'command': command, 'exit_code': result.returncode,
                   'summaries': summaries, 'diagnostics': errors,
                   'script_errors': len(re.findall(r'SCRIPT ERROR:|Parse Error:', log))}
    except subprocess.TimeoutExpired:
        receipt = {'name': name, 'command': command, 'timeout_seconds': 240, 'exit_code': -1}
    (destination / 'command.json').write_text(json.dumps(receipt, indent=2) + '\n')
    # Long measurement rows remain in the log and per-suite JSON.
    print(name, receipt['exit_code'], *(line[:240] for line in receipt.get('summaries', [])[-4:]), flush=True)
    return receipt


if __name__ == '__main__':
    names = [arg for arg in sys.argv[1:] if not arg.startswith('--phase=')]
    results = [run(name) for name in (names or DEFAULTS)]
    (OUT / f'checks-{PHASE or "latest"}.json').write_text(json.dumps(results, indent=2) + '\n')
    sys.exit(1 if any(r['exit_code'] or r.get('script_errors') for r in results) else 0)
