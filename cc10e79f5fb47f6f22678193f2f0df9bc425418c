"""Compare the existing source-only wallet fast read on a synthetic fixture."""
import ast
import json
from pathlib import Path
import sys
from types import SimpleNamespace

ROOT=Path(__file__).resolve().parents[2]
WORK=Path(__file__).resolve().parent
OUT=ROOT/'docs/evidence/backend-reuse-review-2026-10-26'
frozen=ROOT/'build/backend-ghost-cache-deploy-2026-10-26'
sys.path[:0]=[str(frozen/'release'),str(frozen/'test-work/backend/tests')]
from test_domains import domain,headers
from bmt_backend import economy
from bmt_backend.tracks import DB,Auth
from sqlalchemy import event

source=ROOT/'backend/bmt_backend/economy.py'
function=next(x for x in ast.parse(source.read_text(encoding='utf-8')).body
              if isinstance(x,ast.FunctionDef) and x.name=='established_wallet')
namespace=dict(economy.__dict__)
exec(compile(ast.Module(body=[function],type_ignores=[]),str(source),'exec'),namespace)
fast_read=namespace['established_wallet']
fixture=WORK/'synthetic-fast-wallet';assert not fixture.exists();fixture.mkdir()
generator=domain.__wrapped__(fixture,SimpleNamespace(param='sqlite'));d=next(generator)
statements=[]
def observe(connection,cursor,statement,parameters,context,executemany):
 statements.append(statement.lstrip().split(None,1)[0].upper())
event.listen(d.app.state.engine,'before_cursor_execute',observe)
try:
 first=d.client.get('/v1/economy',headers=headers(d,'Alice'));assert first.status_code==200
 @d.app.get('/v1/review-wallet-fast-read')
 def comparison(session:DB,player:Auth):
  result=fast_read(session,player.id);assert result is not None;return result
 values={}
 for path in ('/v1/economy','/v1/review-wallet-fast-read'):
  statements.clear();response=d.client.get(path,headers=headers(d,'Alice'))
  assert response.status_code==200 and response.json()==first.json()
  values[path]={'sql_statements':len(statements),
     'statement_kinds':{kind:statements.count(kind) for kind in sorted(set(statements))}}
 report={'fixture':'New synthetic SQLite account; same fake authentication and middleware for both routes',
   'actual_http_wallet_payload_equal':True,'source_function':'backend/bmt_backend/economy.py:established_wallet',
   'deployed_read':values['/v1/economy'],'existing_source_fast_read':values['/v1/review-wallet-fast-read'],
   'qualification':'SQL statement count, not measured PostgreSQL latency/capacity. The local comparison route is never deployed.'}
 (OUT/'source-fast-wallet.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
 print(json.dumps(report,indent=2))
finally:
 event.remove(d.app.state.engine,'before_cursor_execute',observe)
 try:next(generator)
 except StopIteration:pass
