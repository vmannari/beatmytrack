"""Sequential native validation: no concurrent GPU timing runs."""
import json,subprocess,sys
from pathlib import Path
p=Path(__file__).resolve().parent
checks=[
 ('contract-gl','test_surface_shader_pruning.gd','gl_compatibility',90,[]),
 ('consolidation-gl','test_shader_variant_consolidation.gd','gl_compatibility',180,[]),
 ('final-pixels','review_first_use_comparison.gd','gl_compatibility',400,['--themes','pine,winter,desert,storm,night_city']),
 ('final-native','profile_first_use_graphics.gd','gl_compatibility',240,['--native']),
 ('first-laps-gl','test_shared_graphics_first_laps.gd','gl_compatibility',420,['--first-emission']),
 ('contract-mobile','test_surface_shader_pruning.gd','mobile',90,[]),
 ('consolidation-mobile','test_shader_variant_consolidation.gd','mobile',180,[]),
 ('first-laps-mobile','test_shared_graphics_first_laps.gd','mobile',420,['--first-emission']),
]
rows=[]
for label,script,renderer,timeout,extra in checks:
    command=[sys.executable,str(p/'run_check.py'),label,'res://tests/'+script,'--frozen','--renderer',renderer,'--timeout',str(timeout),*extra]
    print('RUN',label,flush=True)
    code=subprocess.run(command).returncode
    rows.append(dict(label=label,exit_code=code,command=command))
    (p/'final-suite.json').write_text(json.dumps(rows,indent=2)+'\n')
    if code: sys.exit(code)
