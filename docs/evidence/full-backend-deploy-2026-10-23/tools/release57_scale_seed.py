"""Synthetic migration input matching aggregate cloud cardinalities; local restore only."""
import json
import time
import uuid
from sqlalchemy import MetaData, select, text
from bmt_backend.config import Settings
from bmt_backend.db import make_engine

e = make_engine(Settings.from_env().database_url)
e.hide_parameters = True
m = MetaData()
m.reflect(e)
targets = __TARGETS__
stamp = int(time.time())
with e.begin() as c:
    def count(name):
        return c.scalar(text('SELECT count(*) FROM ' + name))
    def insert(name, values):
        for start in range(0,len(values),1000):
            c.execute(m.tables[name].insert(), values[start:start+1000])
    actor = dict(c.execute(select(m.tables['players'])).mappings().first())
    actors = [str(uuid.uuid4()) for _ in range(max(0,targets['players']-count('players')))]
    insert('players',[{**actor,'id':identity,'display_name':'Release probe '+str(i),'username_key':'release probe '+str(i),
                      'disabled':False,'deleted_at':None,'is_test_driver':False} for i,identity in enumerate(actors)])
    template = dict(c.execute(select(m.tables['track_versions'])).mappings().first())
    last = c.scalar(text('SELECT max(number) FROM track_versions WHERE track_id=:id'), {'id':template['track_id']})
    insert('track_versions',[{**template,'id':str(uuid.uuid4()),'number':last+i+1,'revision_key':uuid.uuid4().hex} for i in range(max(0,targets['track_versions']-count('track_versions')))])
    boards = list(c.scalars(text('SELECT id FROM boards ORDER BY id LIMIT 20')))
    template = dict(c.execute(select(m.tables['runs'])).mappings().first())
    tickets, runs, bests = [], [], []
    required = max(0,targets['personal_bests']-count('personal_bests'))
    for i in range(max(0,targets['runs']-count('runs'))):
        owner, board = actors[i%len(actors)], boards[(i//len(actors))%len(boards)]
        tid, rid = str(uuid.uuid4()), str(uuid.uuid4())
        ticks = 13000+i%17
        tickets.append({'id':tid,'player_id':owner,'board_id':board,'created_at':stamp,'expires_at':stamp+3600})
        runs.append({**template,'id':rid,'ticket_id':tid,'player_id':owner,'board_id':board,'status':'verified','created_at':stamp,'finished_at':stamp,
                     'time_ticks':ticks,'attempts':0,'lease_until':0,'lease_token':None})
        if i<required:
            bests.append({'board_id':board,'player_id':owner,'run_id':rid,'time_ticks':ticks,'achieved_at':stamp})
    insert('run_tickets',tickets)
    insert('runs',runs)
    insert('personal_bests',bests)
    template = c.execute(select(m.tables['product_events'])).mappings().first()
    template = dict(template) if template else {'id':'','client_id':None,'entity_id':None,'player_id':actors[0],'is_test_driver':False,'source':'client',
        'name':'menu_ready','occurred_at':stamp,'received_at':stamp,'session_id':None,'install_id':None,'seq':None,'monotonic_ms':None,
        'build_id':'release-probe','platform':'windows','clock_quality':'unknown','payload_hash':'0'*64,'properties':{},'processed_at':stamp,'compacted':False}
    insert('product_events',[{**template,'id':str(uuid.uuid4()),'player_id':actors[i%len(actors)]} for i in range(max(0,targets['product_events']-count('product_events')))])
    print(json.dumps({'synthetic_counts':{name:count(name) for name in targets if name!='rivalry_groups'},'original_data_local_only':True}))
e.dispose()
