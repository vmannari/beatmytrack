import json, os, subprocess, sys, uuid
from pathlib import Path
from dataclasses import replace
from sqlalchemy import select, update
from bmt_backend.loadtest import app_for
from bmt_backend.config import Settings
from bmt_backend.migrate import upgrade
from bmt_backend.load_fixtures import seed
from bmt_backend.backup_guard import begin, end
from bmt_backend.maintenance import retain
from bmt_backend.object_models import ObjectPin
from bmt_backend.track_models import Run, RunTicket, PersonalBest, now
from bmt_backend.storage import LocalBlobStore

root=Path("build/backend-scalability/backup-probe").resolve();root.mkdir(parents=True,exist_ok=True)
values=dict(line.split("=",1) for line in Path("build/backend-scalability/private/test.env").read_text().splitlines())
url=values["BMT_TEST_DATABASE_URL"]
schema="bmt_load_"+uuid.uuid4().hex
restore_db="bmt_restore_"+uuid.uuid4().hex
container="bmt-scalability-pg-20261004"

def pg(command,*args,data=None):
    result=subprocess.run(["wsl","-d","Ubuntu","--exec","docker","exec"]+(["-i"] if data is not None else [])+[container,command,*args],input=data,capture_output=True,check=False)
    if result.returncode: raise RuntimeError(result.stderr.decode("utf8",errors="replace"))
    return result.stdout

from sqlalchemy import create_engine
admin=create_engine(url,hide_parameters=True)
with admin.begin() as c:c.exec_driver_sql(f'CREATE SCHEMA "{schema}"')
settings=Settings(environment="test",database_url=url,object_dir=str(root/"source"))
config={"settings":{k:getattr(settings,k) for k in settings.__dataclass_fields__},"schema":schema,"canonical":False}
app=app_for(config);restored=None;restore_created=False;guard=None
try:
    upgrade(app.state.engine)
    data=seed(app,players=50,tracks=5,actors=6,memberships=False)
    old_hash=app.state.blobs.put_json({"schema":"bmt-replay-v1","frames":[[0,254,0]]*20})
    with app.state.session_factory() as s:
        pb=s.get(PersonalBest,(data["boards"][0],data["players"][0]));old_id=pb.run_id;old_ticks=pb.time_ticks
        old=s.get(Run,old_id);old.replay_hash=old_hash;old.finished_at=now()-100*86400;s.commit()
    old=now()-100*86400;os.utime(app.state.blobs._path(old_hash),(old,old))
    guard=begin(app.state.session_factory)
    dump=pg("pg_dump","-U",admin.url.username,"-d",admin.url.database,"-n",schema,"-Fc")
    (root/"database.dump").write_bytes(dump)
    # A real DB mutation after the dump, with writers still active, supersedes evidence.
    new_hash=app.state.blobs.put_json({"current":"fixture"})
    with app.state.session_factory() as s:
        ticket=RunTicket(player_id=data["players"][0],board_id=data["boards"][0],expires_at=now()+3600);s.add(ticket);s.flush()
        run=Run(ticket_id=ticket.id,player_id=ticket.player_id,board_id=ticket.board_id,replay_hash=new_hash,status="verified",time_ticks=old_ticks-10,lap_ticks=[1]*5,finished_at=now())
        s.add(run);s.flush();pb=s.get(PersonalBest,(ticket.board_id,ticket.player_id));pb.run_id=run.id;pb.time_ticks=run.time_ticks;s.flush();s.delete(s.get(Run,old_id));s.commit()
    try:retain(app.state.session_factory,app.state.blobs,apply=True,online=True)
    except RuntimeError:pass
    else:raise AssertionError("backup must pause GC")
    archive=subprocess.run([sys.executable,"backend/deploy/object_archive.py","archive","--root",str(root/"source")],capture_output=True,check=True).stdout
    (root/"objects.tar").write_bytes(archive)
    end(app.state.session_factory,guard);guard=None
    with app.state.session_factory() as s:s.execute(update(ObjectPin).where(ObjectPin.digest==old_hash).values(expires_at=0));s.commit()
    assert retain(app.state.session_factory,app.state.blobs,apply=True,online=True)["orphaned_objects"]==1
    pg("createdb","-U",admin.url.username,restore_db);restore_created=True
    pg("pg_restore","-U",admin.url.username,"-d",restore_db,"--no-owner","--no-privileges",data=dump)
    subprocess.run([sys.executable,"backend/deploy/object_archive.py","restore","--root",str(root/"restored-objects")],input=archive,capture_output=True,check=True)
    restored_config={**config,"settings":{**config["settings"],"database_url":str(admin.url.set(database=restore_db).render_as_string(hide_password=False)),"object_dir":str(root/"restored-objects")}}
    restored=app_for(restored_config)
    with restored.state.session_factory() as s:
        pb=s.get(PersonalBest,(data["boards"][0],data["players"][0]));assert pb.run_id==old_id and pb.time_ticks==old_ticks
        assert restored.state.blobs.get_json(s.get(Run,old_id).replay_hash)["frames"]==[[0,254,0]]*20
    report={"synthetic_data":True,"writers_stopped":False,"restore_verified":True,"backup_pb_ticks":old_ticks,"source_pb_ticks_after_dump":old_ticks-10,"post_backup_gc_pruned_old_object":True,"archive_bytes":len(archive),"dump_bytes":len(dump)}
    (root/"report.json").write_text(json.dumps(report,indent=2));print(json.dumps(report))
finally:
    if guard:end(app.state.session_factory,guard)
    if restored:restored.state.engine.dispose()
    app.state.engine.dispose()
    if restore_created:pg("dropdb","-U",admin.url.username,restore_db)
    with admin.begin() as c:c.exec_driver_sql(f'DROP SCHEMA "{schema}" CASCADE')
    admin.dispose()
