from pathlib import Path
import hashlib,json,subprocess,time
ROOT=Path(__file__).resolve().parents[3];OUT=Path(__file__).resolve().parent
target=(ROOT/'build').resolve()
assert target==Path(r'C:\Codes\Godot\Beat my track\build').resolve()
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
index=sha(ROOT/'.git/index');started=time.monotonic()
command=['powershell','-NoProfile','-ExecutionPolicy','Bypass','-File','scripts/clean_build.ps1','-Apply']
with (OUT/'retention.log').open('w',encoding='utf-8') as log:
    result=subprocess.run(command,cwd=ROOT,stdout=log,stderr=subprocess.STDOUT,timeout=180)
(OUT/'retention-command.json').write_text(json.dumps({'command':command,'exit_code':result.returncode,
    'verified_absolute_build_root':str(target),'elapsed_seconds':time.monotonic()-started,
    'main_index_unchanged':index==sha(ROOT/'.git/index'),'task_active_pin_created':False},indent=2))
assert result.returncode==0
print((OUT/'retention.log').read_text()[-1800:])
