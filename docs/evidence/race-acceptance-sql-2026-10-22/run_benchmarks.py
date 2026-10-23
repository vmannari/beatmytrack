"""Alternate original/current runs in separate processes with owned DB schemas."""
import subprocess
import sys
from pathlib import Path

runner = str(Path(__file__).with_name('measure_acceptance.py'))
for pair in range(1, 3):
    for original in (True, False):
        label = ('original' if original else 'final') + '-pg-pair' + str(pair)
        command = [sys.executable, runner, '--postgres', '--iterations', '40', '--label', label]
        if original:
            command.append('--original')
        print(label, flush=True)
        subprocess.run(command, check=True)
