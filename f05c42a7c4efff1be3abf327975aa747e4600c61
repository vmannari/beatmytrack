"""Real Godot completion consumer against the exact frozen API read overlay."""
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
from bmt_backend.economy_models import CoinReward,CoinWallet
from bmt_backend.track_models import Run
from sqlalchemy import select
from test_domains import FakeVerifier
from test_cost_http import seed
import uvicorn

fixture=WORK/'native-completion-fixture';assert not fixture.exists();fixture.mkdir()
binary=Path(r'C:\apps\Godot 4.7.2\Godot_v4.7.2-stable_win64_console.exe')
key=secrets.token_urlsafe(32)
listener=socket.socket();listener.bind(('127.0.0.1',0))
origin='http://127.0.0.1:'+str(listener.getsockname()[1])
app=create_app(Settings(environment='development',dev_auth_enabled=True,dev_auth_key=key,
 database_url='sqlite:///'+(fixture/'data.sqlite').as_posix(),object_dir=str(fixture/'objects'),
 public_base_url=origin,rate_limit_per_minute=10000,write_limit_per_minute=10000),verifier=FakeVerifier())
upgrade(app.state.engine);seed(app)
with app.state.session_factory() as session:
 run=session.scalar(select(Run));run_id,ticket=run.id,run.ticket_id
 session.add(CoinWallet(player_id=run.player_id,balance=1234,revision=1))
 session.add(CoinReward(run_id=run.id,player_id=run.player_id,amount=50,
  rows=[{'title':'Finish','icon':'coin','amount':50,'eligible':True,'status':'Credited'}]))
 session.commit()
paths=[]
@app.middleware('http')
async def observe(request,call_next):
 paths.append(request.url.path);return await call_next(request)
server=uvicorn.Server(uvicorn.Config(app,log_level='error',access_log=False))
thread=threading.Thread(target=server.run,kwargs={'sockets':[listener]},daemon=True);thread.start()
try:
 for _ in range(100):
  if server.started:break
  time.sleep(.05)
 assert server.started
 profile=fixture/'profile';profile.mkdir()
 env={**os.environ,'APPDATA':str(profile),'LOCALAPPDATA':str(profile),
   'BMT_API_URL':origin,'BMT_DEV_AUTH_KEY':key,'BMT_COMPLETION_RUN':run_id,'BMT_COMPLETION_TICKET':ticket}
 result=subprocess.run([str(binary),'--headless','--path',str(ROOT/'game'),'--script','res://tests/test_completion_receipts_http.gd'],
  env=env,capture_output=True,text=True,encoding='utf-8',errors='replace',timeout=120)
 (OUT/'native-completion.stdout.log').write_text(result.stdout,encoding='utf-8')
 (OUT/'native-completion.stderr.log').write_text(result.stderr,encoding='utf-8')
 no_extra=not any(path=='/v1/economy' or path.startswith('/v1/economy/rewards/') for path in paths)
 proof={'exit':result.returncode,'checks':10,'summary_present':'COMPLETION_HTTP checks=10 failures=0' in result.stdout,
   'no_reward_or_wallet_followup_requests':no_extra,'single_status':paths.count('/v1/runs/'+run_id),
   'batch_status':paths.count('/v1/runs/status'),'wait_status':paths.count('/v1/runs/'+run_id+'/wait'),
   'real_player_data_used':False,'server':'Exact frozen API optimization release package'}
 assert result.returncode==0 and proof['summary_present'] and no_extra,result.stdout+result.stderr
 (OUT/'native-completion.json').write_text(json.dumps(proof,indent=2)+'\n',encoding='utf-8')
 print(json.dumps(proof,indent=2))
finally:
 server.should_exit=True;thread.join(timeout=15);listener.close();app.state.engine.dispose()
