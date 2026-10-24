"""Synthetic-only rehearsal seed. No local/cloud player record is an input."""
import hashlib
import json
import time
import uuid
from alembic import command
from sqlalchemy import select, text
from sqlalchemy.orm import Session
from bmt_backend.config import Settings
from bmt_backend.db import make_engine
from bmt_backend.migrate import configuration

engine=make_engine(Settings.from_env().database_url)
command.upgrade(configuration(engine),'0057_discovery_resource_guards')
from bmt_backend.identity_models import Player,Identity
from bmt_backend.track_models import Track,TrackVersion,Board,RunTicket,Run,PersonalBest
from bmt_backend.economy_models import CosmeticUnlock
counts=__COUNTS__
stamp=int(time.time())
def uid(value):return str(uuid.uuid5(uuid.NAMESPACE_URL,'security-rehearsal:'+str(value)))
appearance={'vehicle_id':'compact','livery':{'version':2,'pattern':'offset_gt'},
    'customisation':{'version':1,'hood':'stock','aero':'stock','rims':'stock','body':'wide'}}
with Session(engine) as db:
    players=[uid('player'+str(i)) for i in range(counts['players'])]
    db.add_all(Player(id=value,display_name='Release synthetic '+str(i),vehicle_appearances={'compact':appearance} if i%2==0 else {}) for i,value in enumerate(players))
    db.flush()
    db.add_all(Identity(player_id=value,provider='development',subject='synthetic-only-'+str(i)) for i,value in enumerate(players))
    db.add_all(CosmeticUnlock(player_id=value,item_id='livery/offset_gt',price=500,created_at=stamp-100) for value in players[:100])
    track=Track(id=uid('track'),owner_id=players[0]);db.add(track);db.flush()
    versions=[uid('version'+str(i)) for i in range(counts['track_versions'])]
    db.add_all(TrackVersion(id=value,track_id=track.id,number=i+1,name='Synthetic '+str(i),content_hash='0'*64,manifest={},state='published') for i,value in enumerate(versions));db.flush()
    boards=[hashlib.sha256(('board'+str(i)).encode()).hexdigest() for i in range(8)]
    db.add_all(Board(id=value,version_id=versions[i],vehicle_id='compact',manifest={}) for i,value in enumerate(boards));db.flush()
    tickets=[];runs=[];bests=[]
    for i in range(counts['runs']):
        player=players[i%len(players)];board=boards[(i//len(players))%len(boards)]
        tid=uid('ticket'+str(i));rid=uid('run'+str(i));ticks=13000+i%17
        tickets.append({'id':tid,'player_id':player,'board_id':board,'expires_at':stamp+3600})
        runs.append({'id':rid,'ticket_id':tid,'player_id':player,'board_id':board,'replay_hash':'0'*64,'status':'verified','finished_at':stamp,'time_ticks':ticks,'lap_ticks':[2600]*5})
        if i<counts['personal_bests']:bests.append({'board_id':board,'player_id':player,'run_id':rid,'time_ticks':ticks})
    for model,rows in [(RunTicket,tickets),(Run,runs),(PersonalBest,bests)]:
        for start in range(0,len(rows),1000):db.bulk_insert_mappings(model,rows[start:start+1000])
    db.commit()
print('SECURITY_RESULT='+json.dumps({'synthetic_only':True,'schema':'0057_discovery_resource_guards','counts':counts}))
engine.dispose()
