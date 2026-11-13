"""Same synthetic account: original and fixed handlers, exact JSON and SQL counts."""
import ast
import json
from pathlib import Path
import sys
from types import SimpleNamespace

WORK=Path(__file__).resolve().parent
ROOT=WORK.parents[1]
OUT=ROOT/'docs/evidence/backend-reuse-fixes-2026-10-26'
sys.path[:0]=[str(WORK/'release'),str(WORK/'test-work/backend/tests')]
from fastapi import Request
from sqlalchemy import event
from test_domains import domain,headers
from test_rivalry import seed,join
from bmt_backend import rivalry,economy
from bmt_backend.runs import BoardDB
from bmt_backend.tracks import DB,Auth

def original_functions(filename,module,names):
 namespace=dict(module.__dict__)
 source=(WORK/'baseline/bmt_backend'/filename).read_text(encoding='utf-8')
 nodes=[node for node in ast.parse(source).body if isinstance(node,ast.FunctionDef) and node.name in names]
 for node in nodes:node.decorator_list=[]
 exec(compile(ast.Module(body=nodes,type_ignores=[]),str(WORK/'baseline/bmt_backend'/filename),'exec'),namespace)
 return namespace

old=original_functions('rivalry.py',rivalry,{'standings_data','snapshot','current'})
old_wallet=original_functions('economy.py',economy,{'balance'})['balance']
fixture=WORK/'measurement-fixture';assert not fixture.exists();fixture.mkdir()
generator=domain.__wrapped__(fixture,SimpleNamespace(param='sqlite'));d=next(generator)
statements=[]
def record(*args):statements.append(args[2])
try:
 seed(d,6);join(d,'Alice')
 stamp=rivalry.now();old['now']=lambda:stamp;rivalry.now=lambda:stamp
 @d.app.get('/v1/review-previous-rivalry')
 def original(request:Request,session:BoardDB,player:Auth):
  return old['current'](request,session,player,'compact',False)
 @d.app.get('/v1/review-previous-wallet')
 def original_wallet(session:DB,player:Auth):return old_wallet(session,player)
 event.listen(d.app.state.engine,'before_cursor_execute',record)
 def get(path,tag=None):
  statements.clear();response=d.client.get(path,headers={**headers(d,'Alice'),**({'If-None-Match':tag} if tag else {})})
  assert response.status_code in (200,304),response.text
  return response,{'status':response.status_code,'statements':len(statements),
   'selects':sum(x.lstrip().upper().startswith('SELECT') for x in statements),
   'compressed_content_length':response.headers.get('content-length')}
 first,before=get('/v1/review-previous-rivalry')
 second,after=get('/v1/rivalry/current?vehicle_id=compact')
 assert first.json()==second.json()
 _,warm=get('/v1/rivalry/current?vehicle_id=compact',second.headers['etag'])
 get('/v1/economy')
 first,wallet_before=get('/v1/review-previous-wallet')
 second,wallet_after=get('/v1/economy')
 assert first.json()==second.json()
 proof={'fixture':'Same synthetic SQLite account, six tracks, fake authentication, exact frozen API overlay',
  'rivalry':{'before':before,'after':after,'unchanged':warm,'payload_exact':True},
  'wallet':{'before':wallet_before,'after':wallet_after,'payload_exact':True},
  'postgresql_performance_claim':False}
 (OUT/'read-measurements.json').write_text(json.dumps(proof,indent=2)+'\n',encoding='utf-8')
 print(json.dumps(proof,indent=2))
finally:
 event.remove(d.app.state.engine,'before_cursor_execute',record)
 try:next(generator)
 except StopIteration:pass
