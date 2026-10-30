"""Deployment-only read-only probe; never mounted as a route or given player write authority."""
import json
from types import SimpleNamespace
from uuid import uuid4

from bmt_backend.app import create_admin_app
from bmt_backend.studio_usage import usage_costs
from bmt_backend.track_models import now

app=create_admin_app()
request=SimpleNamespace(app=app,state=SimpleNamespace(request_id=str(uuid4())))
try:
    result=usage_costs(request,'owner',None,days=1)
    # No player IDs, names other than the requested Ville label, private rows or
    # credentials leave this operator job. The ordinary HTTP gates are untouched.
    a=result['activity']
    payload={'event':'usage_deployment_probe','schema':result['schema'],'as_of':result['as_of'],
        'read_only':result['read_only'],'project':result['project'],'summary':result['summary'],
        'sources':result['sources'],'resources':result['resources'],'traffic':result['traffic'],
        'activity':{k:a.get(k) for k in ('status','active_players','active_days','requests','all_observed_requests',
            'processed_through','fresh','binding','full_window_observed')},
        'ville_account_found':bool(a.get('player_id')),'costs':result['costs'],
        'endpoint_rows':len(result.get('endpoints',{}).get('rows',[])),
        'sql_source':'existing Studio and limited reporting credentials','http_authentication_bypassed':False,
        'scope':'operator invokes read-only report functions directly; no owner HTTP credential minted; no authenticated browser claim'}
    print(json.dumps(payload,separators=(',',':')),flush=True)
except Exception as error:
    print(json.dumps({'event':'usage_deployment_probe_failed','error_class':type(error).__name__}),flush=True)
    raise SystemExit(1) from None
finally:
    app.state.studio_reporting.close();app.state.engine.dispose();app.state.verifier.close()
