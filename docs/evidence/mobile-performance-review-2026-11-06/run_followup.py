"""Additional current-source observations; run after run_suite.py finishes."""
import json
from pathlib import Path
import subprocess
import sys

OUT = Path(__file__).resolve().parent
PROJECT = Path(json.loads((OUT / 'frozen-project.json').read_text())['project'])
ROOT = OUT.parents[2]

# Record probe adaptations explicitly; production files are unchanged.
source = (PROJECT / 'tests/profile_header_garage_regression.gd').read_text()
source = source.replace('var result: Dictionary = {}', 'var result: Dictionary = {}\nvar phase: String = "startup"\nvar phase_max: Dictionary = {}')
source = source.replace('func frame() -> void:\n', 'func frame() -> void:\n\tvar frame_began: int = Time.get_ticks_usec()\n')
source = source.replace('\tawait process_frame\nfunc run()', '\tawait process_frame\n\tphase_max[phase] = maxf(float(phase_max.get(phase,0.0)),(Time.get_ticks_usec()-frame_began)/1000.0)\nfunc run()')
source = source.replace('var idle_began: int', 'phase = "idle"\n\tvar idle_began: int')
source = source.replace('var entering: int', 'phase = "garage"\n\tvar entering: int')
source = source.replace('result.checks = checks', 'result.max_frame_ms = phase_max\n\tresult.checks = checks')
(OUT / 'review_header_idle.gd').write_text(source,encoding='utf-8',newline='\n')

soak = (PROJECT / 'tests/soak_runtime_correctness.gd').read_text()
soak = soak.replace('app._retained_garage.thumbnails.size()==7','app._retained_garage.thumbnails.size()==VehicleCatalog.IDS.size()')
soak = soak.replace('all seven images','all current vehicle images')
soak = soak.replace('ProjectSettings.globalize_path("res://../build")','OS.get_environment("BMT_REVIEW_BUILD")')
# This process has explicit task-owned appdata. Preserve the original containment assertion.
(OUT / 'review_soak.gd').write_text(soak,encoding='utf-8',newline='\n')
for name in ['review_header_idle.gd','review_driving.gd','review_soak.gd','review_profile_rows.gd']:
    (PROJECT / 'tests' / name).write_bytes((OUT/name).read_bytes())

import os
os.environ['BMT_REVIEW_BUILD'] = str(ROOT / 'build')
cases = [
    ('profile-rows', 'review_profile_rows.gd', []),
    ('header-idle', 'review_header_idle.gd', ['--native','--timeout','240','--args','--settled','--expect-ready']),
    ('driving-five-biomes', 'review_driving.gd', ['--native','--timeout','600','--args','--first-emission']),
    ('lifecycle-12', 'review_soak.gd', ['--native','--timeout','600','--args','--cycles=12','--report-dir='+str(OUT/'lifecycle-12')]),
]
for name, script, extra in cases:
    subprocess.run([sys.executable,str(OUT/'run_case.py'),name,script,'--project',str(PROJECT)]+extra,check=True)
