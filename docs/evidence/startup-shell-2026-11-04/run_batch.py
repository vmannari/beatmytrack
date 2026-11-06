"""Sequential isolated native measurements/checks against one frozen project."""
import json
from pathlib import Path
import subprocess
import sys

evidence = Path(__file__).resolve().parent
root = evidence.parents[2]
mode = sys.argv[1]
timings = [
    ('timing-before-1',['--before']),('timing-after-1',[]),
    ('timing-before-2',['--before']),('timing-after-2',[]),
    ('timing-custom-after-seed',['--custom','--profile','timing-custom-after']),
    ('timing-custom-after-reuse',['--custom','--profile','timing-custom-after']),
    ('timing-custom-before-seed',['--before','--custom','--profile','timing-custom-before']),
    ('timing-custom-before-reuse',['--before','--custom','--profile','timing-custom-before'])]
checks = [
    ('cold-final','res://tests/test_startup_shell.gd',[]),
    ('app-final','res://tests/test_app.gd',['--headless']),
    ('music-final','res://tests/test_startup_music.gd',['--headless']),
    ('swipe-final','res://tests/test_menu_page_swipe.gd',['--headless']),
    ('daily-final','res://tests/test_daily_elimination_app.gd',['--headless']),
    ('race-final','res://tests/test_race_loading.gd',['--headless']),
    ('header-rich-seed-final','res://tests/test_profile_car_startup.gd',[
        '--profile','rich-header-final','--','--output='+str(evidence/'header-rich-seed-final-views'),
        '--profile=user://rich-header-final','--phase=seed']),
    ('header-rich-reuse-final','res://tests/test_profile_car_startup.gd',[
        '--profile','rich-header-final','--','--output='+str(evidence/'header-rich-reuse-final-views'),
        '--profile=user://rich-header-final','--phase=reuse']),
    ('flow-control','res://tests/test_startup_shell_flow.gd',['--before']),
    ('flow-candidate','res://tests/test_startup_shell_flow.gd',[]),
    ('flow-mobile','res://tests/test_startup_shell_flow.gd',['--renderer','mobile'])]
rows = [(label,'res://tests/profile_startup_shell.gd',args) for label,args in timings] if mode=='timings' else checks
if mode == 'remaining': rows = checks[4:]
if mode == 'post-header': rows = checks[6:]
if mode == 'owned':
    rows = [
        ('cold-owned','res://tests/test_startup_shell.gd',[]),
        ('app-owned','res://tests/test_app.gd',['--headless']),
        ('music-owned','res://tests/test_startup_music.gd',['--headless']),
        ('daily-owned','res://tests/test_daily_elimination_app.gd',['--headless']),
        ('race-owned','res://tests/test_race_loading.gd',['--headless']),
        ('lifetime-owned-frozen','res://tests/test_startup_feature_lifetime.gd',['--headless']),
        ('flow-candidate-owned','res://tests/test_startup_shell_flow.gd',[]),
        ('flow-mobile-owned','res://tests/test_startup_shell_flow.gd',['--renderer','mobile'])]
receipts = []
for label,script,args in rows:
    if label.startswith('header-rich-'): (evidence/(label+'-views')).mkdir(parents=True,exist_ok=True)
    command = [sys.executable,str(evidence/'run_review.py'),label,script,'--frozen',*args]
    result = subprocess.run(command,cwd=root,check=False)
    receipts.append(dict(command=command,exit_code=result.returncode))
    (evidence/('batch-'+mode+'.json')).write_text(json.dumps(receipts,indent=2)+'\n',encoding='utf-8')
    print(label+' exit='+str(result.returncode),flush=True)
    if result.returncode: sys.exit(result.returncode)
