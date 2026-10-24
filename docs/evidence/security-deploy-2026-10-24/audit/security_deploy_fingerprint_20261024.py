"""Remote/local read-only deployment fingerprints; never returns row contents."""
import hashlib
import json
import time
from sqlalchemy import inspect, text
from bmt_backend.config import Settings
from bmt_backend.db import make_engine

baseline=__BASELINE__
settings=Settings.from_env();engine=make_engine(settings.database_url,settings)
with engine.connect() as db:
    db.execute(text('SET TRANSACTION ISOLATION LEVEL REPEATABLE READ READ ONLY'))
    inspector=inspect(db)
    cutoff=baseline['cosmetic_cutoff'] if baseline else int(time.time())
    retired={'alembic_version','discovery_budget','discovery_snapshots'}
    names=sorted(baseline['tables']) if baseline else sorted(set(inspector.get_table_names())-retired)
    tables={}
    for name in names:
        columns=baseline['tables'][name]['columns'] if baseline else [v['name'] for v in inspector.get_columns(name)]
        pk=baseline['tables'][name]['pk'] if baseline else inspector.get_pk_constraint(name)['constrained_columns']
        assert pk
        where=' WHERE created_at <= '+str(cutoff) if name=='cosmetic_unlocks' else ''
        sql='SELECT '+','.join('"'+v+'"' for v in columns)+' FROM "'+name+'"'+where+' ORDER BY '+','.join('"'+v+'"' for v in pk)
        digest=hashlib.sha256();count=0
        for row in db.execute(text(sql)):
            digest.update(json.dumps(list(row),sort_keys=True,separators=(',',':'),default=str).encode()+b'\n');count+=1
        tables[name]={'columns':columns,'pk':pk,'rows':count,'sha256':digest.hexdigest()}
    result={'schema':db.scalar(text('SELECT version_num FROM alembic_version')),'tables':tables,'cosmetic_cutoff':cutoff,
        'pending':{name:db.scalar(text("SELECT count(*) FROM "+name+" WHERE status IN ('queued','verifying','validating')")) for name in ['runs','publication_intents','track_validations']},
        'invalid_indexes':db.scalar(text('SELECT count(*) FROM pg_index WHERE NOT indisvalid'))}
    if baseline:assert tables==baseline['tables'],[name for name in tables if tables[name]!=baseline['tables'][name]]
print('SECURITY_RESULT='+json.dumps(result));engine.dispose()
