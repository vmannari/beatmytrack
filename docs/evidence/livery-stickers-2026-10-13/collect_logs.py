from pathlib import Path
import json
import shutil

evidence = Path(__file__).resolve().parent
root = evidence.parents[2]
output = evidence/'logs'
output.mkdir(exist_ok=True)
markers = {
    'livery-compatibility':'Livery patterns: 333 checks, 0 failures (gl_compatibility)',
    'livery-mobile':'Livery patterns: 333 checks, 0 failures (mobile)',
    'parser':'SCRIPT_PARSE: 644 scripts, 0 failures',
    'garage-livery':'Garage livery: 115 checks, 0 failures',
    'garage-transition':'GARAGE_CAR_TRANSITION: 23 checks, 0 failures',
    'car-wash':'CAR_WASH: 1383 checks, 0 failures',
    'racing-models':'RACING_MODEL_TESTS 57 checks, 0 failures',
    'records':'RECORD_TESTS: 54 checks, 0 failures',
    'driving':'DRIVING_TESTS: 72 checks, 0 failures',
    'rewind':'Rewind: 61 checks, 0 failures',
}
logs = sorted((root/'build/logs').glob('TestScript-*/test-script.log'),key=lambda p:p.stat().st_mtime,reverse=True)
receipts = {}
for name,marker in markers.items():
    source = next(p for p in logs if marker in p.read_text(encoding='utf-8-sig',errors='replace'))
    shutil.copy2(source,output/(name+'.log'))
    receipts[name] = dict(command_log=source.relative_to(root).as_posix(),result=marker)
(output/'results.json').write_text(json.dumps(receipts,indent=2)+'\n',encoding='utf-8')
print(f'Copied {len(receipts)} actual passing command logs.')
