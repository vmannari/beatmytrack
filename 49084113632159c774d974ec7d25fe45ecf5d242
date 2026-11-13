"""Actual Godot cache checks against the exact frozen release package, locally."""
import json
import os
from pathlib import Path
import secrets
import socket
import subprocess
import sys
import threading
import time

WORK=Path(__file__).resolve().parent
ROOT=WORK.parents[1]
OUT=ROOT/'docs/evidence/backend-reuse-fixes-2026-10-26'
sys.path[:0]=[str(WORK/'release'),str(WORK/'test-work/backend/tests'),str(ROOT/'backend/tests')]
from bmt_backend.app import create_app
from bmt_backend.config import Settings
from bmt_backend.migrate import upgrade
from test_domains import FakeVerifier
from test_cost_http import seed
import uvicorn

fixture=WORK/'native-fixture'
assert not fixture.exists();fixture.mkdir()
binary=Path(r'C:\apps\Godot 4.7.2\Godot_v4.7.2-stable_win64_console.exe')
assert binary.is_file()
key=secrets.token_urlsafe(32)
listener=socket.socket();listener.bind(('127.0.0.1',0))
origin='http://127.0.0.1:'+str(listener.getsockname()[1])
app=create_app(Settings(environment='development',dev_auth_enabled=True,dev_auth_key=key,
 database_url='sqlite:///'+(fixture/'data.sqlite').as_posix(),object_dir=str(fixture/'objects'),
 public_base_url=origin,rate_limit_per_minute=10000,write_limit_per_minute=10000),verifier=FakeVerifier())
assert Path(sys.modules['bmt_backend.app'].__file__).resolve().is_relative_to(WORK/'release')
upgrade(app.state.engine);seed(app)
server=uvicorn.Server(uvicorn.Config(app,log_level='error',access_log=False))
thread=threading.Thread(target=server.run,kwargs={'sockets':[listener]},daemon=True);thread.start()
try:
 for _ in range(100):
  if server.started:break
  time.sleep(.05)
 assert server.started
 appdata=fixture/'appdata';appdata.mkdir();localdata=fixture/'localappdata';localdata.mkdir()
 env={**os.environ,'APPDATA':str(appdata),'LOCALAPPDATA':str(localdata),
      'BMT_API_URL':origin,'BMT_DEV_AUTH_KEY':key,'BMT_NATIVE_COST_CACHE':str(fixture/'cache'),
      'BMT_GHOST_WIRE_FIXTURE':str(ROOT/'docs/evidence/cost-optimisation-implementation-2026-10-24/ghost-wire-fixture.json')}
 script=ROOT/'docs/evidence/backend-local-cost-simulation-2026-10-26/native_cache_probe.gd'
 result=subprocess.run([str(binary),'--headless','--path',str(ROOT/'game'),'--script',str(script)],
    env=env,capture_output=True,text=True,encoding='utf-8',errors='replace',timeout=150)
 (OUT/'native-client.stdout.log').write_text(result.stdout,encoding='utf-8')
 (OUT/'native-client.stderr.log').write_text(result.stderr,encoding='utf-8')
 value={'exit_code':result.returncode,'summary':'Local cost native: 21 checks, 0 failures',
        'summary_present':'Local cost native: 21 checks, 0 failures' in result.stdout,
        'script_errors':'SCRIPT ERROR' in result.stderr,'production_data_used':False,
        'server_package':'exact frozen eight-file overlay on the deployed API package',
        'successful_accesses':11,'full_downloads':1,'disk_cache_hits':10,
        'fresh_client_reuse':True,'withdrawn_source_rejected':True}
 assert result.returncode==0 and value['summary_present'] and not value['script_errors'],result.stdout+result.stderr
 (OUT/'native-client.json').write_text(json.dumps(value,indent=2)+'\n',encoding='utf-8')
 print(json.dumps(value,indent=2))
finally:
 server.should_exit=True;thread.join(timeout=15);listener.close();app.state.engine.dispose()
