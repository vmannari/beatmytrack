"""Invented-only PostgreSQL 62-to-70 migration rehearsal, without player exports."""
import hashlib
import json
import time
import uuid

from alembic import command
from sqlalchemy import MetaData, Table, inspect, select, text

from bmt_backend.challenge_models import Challenge
from bmt_backend.config import Settings
from bmt_backend.database_privileges import configure
from bmt_backend.db import make_engine
from bmt_backend.economy_models import CoinMilestone, CoinReward, CoinWallet
from bmt_backend.identity_models import Identity, Player
from bmt_backend.migrate import configuration, upgrade
from bmt_backend.track_models import Board, PersonalBest, Run, RunTicket, Track, TrackVersion

engine = make_engine(Settings.from_env().database_url)
command.upgrade(configuration(engine), "0062_retire_discovery_cache")
metadata, stamp = MetaData(), int(time.time())


def uid():
    return str(uuid.uuid4())


def insert(db, model, **provided):
    target = Table(model.__tablename__, metadata, autoload_with=db, extend_existing=True)
    values = dict(provided)
    for column in model.__table__.columns:
        if column.name not in target.c or column.name in values or column.default is None:
            continue
        values[column.name] = column.default.arg(None) if column.default.is_callable else column.default.arg
    db.execute(target.insert().values(**{key:value for key,value in values.items() if key in target.c}))


def snapshot(db, baseline=None):
    inspector, result = inspect(db), {}
    for name in sorted(baseline) if baseline else sorted(set(inspector.get_table_names())-{"alembic_version"}):
        columns = baseline[name]["columns"] if baseline else [item["name"] for item in inspector.get_columns(name)]
        if name == "discovery_partitions":
            columns = [column for column in columns if column not in ("ready","cursor")]
        pk = inspector.get_pk_constraint(name)["constrained_columns"]
        sql = "SELECT "+",".join('"'+column+'"' for column in columns)+' FROM "'+name+'" ORDER BY '+",".join('"'+column+'"' for column in pk)
        digest, count = hashlib.sha256(), 0
        for row in db.execute(text(sql)):
            digest.update(json.dumps(list(row),sort_keys=True,separators=(",",":"),default=str).encode()+b"\n");count+=1
        result[name] = {"columns":columns,"rows":count,"sha256":digest.hexdigest()}
    return result


with engine.begin() as db:
    owner = uid()
    people = [owner, *[uid() for _ in range(11)]]
    for index, player in enumerate(people):
        insert(db,Player,id=player,display_name="Invented release driver "+str(index),username_key="invented_release_"+str(index))
        insert(db,Identity,player_id=player,provider="development",subject="invented-"+player)
        insert(db,CoinWallet,player_id=player,balance=500,revision=1)
        insert(db,CoinMilestone,player_id=player,scope="synthetic",value=1)
    track, version = uid(), uid()
    insert(db,Track,id=track,owner_id=owner,official=True)
    insert(db,TrackVersion,id=version,track_id=track,number=1,name="Invented migration track",content_hash="a"*64,
           state="published",manifest={"laps":5,"tick_rate":120})
    board = "b"*64
    insert(db,Board,id=board,version_id=version,vehicle_id="compact",manifest={})
    for player in people:
        ticket, run = uid(), uid()
        insert(db,RunTicket,id=ticket,player_id=player,board_id=board,expires_at=stamp+7200)
        insert(db,Run,id=run,ticket_id=ticket,player_id=player,board_id=board,replay_hash="c"*64,
               status="verified",time_ticks=1000,lap_ticks=[200]*5,finished_at=stamp)
        insert(db,PersonalBest,board_id=board,player_id=player,run_id=run,time_ticks=1000)
        insert(db,CoinReward,run_id=run,player_id=player,amount=50,rows=[{"amount":50}])
    challenge = uid()
    insert(db,Challenge,id=challenge,code="INVENTED12345678",creator_id=owner,board_id=board,mode="3x3",ends_at=stamp+7200)
with engine.connect() as db:
    before = snapshot(db)
started = time.monotonic()
upgrade(engine)
with engine.connect() as db:
    after = snapshot(db,before)
    assert before == after
    assert db.scalar(text("SELECT track_count FROM challenges WHERE id=:id"),{"id":challenge}) == 3
    assert db.scalar(text("SELECT count(*) FROM pg_index WHERE NOT indisvalid")) == 0
    schema = db.scalar(text("SELECT version_num FROM alembic_version"))
assert schema == "0070_reward_cache_revisions"
print(json.dumps({"synthetic_only":True,"schema_before":"0062_retire_discovery_cache","schema_after":schema,
                  "compared_tables":len(before),"original_rows_exact":sum(row["rows"] for row in before.values()),
                  "elapsed_seconds":round(time.monotonic()-started,3),"legacy_series_track_count":3}))
engine.dispose()
