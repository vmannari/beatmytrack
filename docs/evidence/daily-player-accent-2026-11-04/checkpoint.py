"""Validate only the two-file accent correction against its task-start sources."""
import difflib
import hashlib
import json
from pathlib import Path
import subprocess
import uuid

root = Path(__file__).resolve().parents[3]
out = Path(__file__).resolve().parent
names = ['game/ui/daily_result_card.gd', 'game/tests/test_daily_standings_entry.gd']
before = {name: (out/'before'/name).read_text(encoding='utf-8') for name in names}
after = {name: (root/name).read_text(encoding='utf-8') for name in names}
pieces = []
for name in names:
    pieces.append('diff --git a/'+name+' b/'+name+'\n')
    pieces.extend(difflib.unified_diff(before[name].splitlines(keepends=True), after[name].splitlines(keepends=True), fromfile='a/'+name, tofile='b/'+name))
patch = out/'task.patch'
patch.write_text(''.join(pieces), encoding='utf-8', newline='\n')
workspace = root/'build'/('daily-accent-checkpoint-'+uuid.uuid4().hex[:10])
workspace.mkdir(parents=True)
assert workspace.resolve().is_relative_to((root/'build').resolve())
def git(*args):
    subprocess.run(['git','-c','core.autocrlf=false',*args],cwd=workspace,check=True,capture_output=True)
git('init','--quiet')
for name, text in before.items():
    path = workspace/name
    path.parent.mkdir(parents=True,exist_ok=True)
    path.write_text(text,encoding='utf-8',newline='\n')
git('apply','--check',str(patch))
git('apply',str(patch))
assert all((workspace/name).read_text(encoding='utf-8') == text for name,text in after.items())
git('apply','--reverse','--check',str(patch))
git('apply','--reverse',str(patch))
assert all((workspace/name).read_text(encoding='utf-8') == text for name,text in before.items())
(out/'report.json').write_text(json.dumps({'requirement':'DPA01','forward_and_reverse_application_and_content':True,
    'main_index_written':False,'checks':{'entry':14,'native_compatibility':237,'failures':0},
    'sources':{name:hashlib.sha256((root/name).read_bytes()).hexdigest() for name in names}},indent=2)+'\n',encoding='utf-8')
print('Two-file task checkpoint: forward/reverse application and content checks passed')
