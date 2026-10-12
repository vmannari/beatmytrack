"""Synthetic capacity fixtures. Imported only by disposable load tooling/tests."""
import base64
import copy
import json
import math
import secrets
import uuid
from pathlib import Path

from sqlalchemy import insert

from .contracts import current_manifest
from .identity_models import Player, SessionFamily, SessionToken
from .rivalry import active_contract, week_window
from .rivalry_models import RivalryBest, RivalryGroup, RivalryMember
from .runs import board_manifest
from .security import digest as token_digest
from .track_models import Board, PersonalBest, Run, RunTicket, Track, TrackVersion, digest, now


def golden_fixture():
    return json.loads((Path(__file__).resolve().parents[1]/"tests/fixtures/verified_oval.json").read_text())


class SyntheticVerifier:
    """Deliberately replaces simulation for API/DB load; never production verification."""
    def __init__(self, fixture):
        self.fixture = fixture

    def manifest(self):
        return current_manifest(copy.deepcopy(self.fixture["expected_manifest"]))

    def validate_track(self, _document):
        return self.manifest()

    def verify_run(self, _document, replay, _vehicle, *, creator_test=False):
        ticks = len(replay["frames"])-sum(e["from_tick"]-e["to_tick"] for e in replay.get("rewinds",[]))
        laps = 1 if creator_test else 5
        return {"manifest":self.manifest(),"time_ticks":ticks,"lap_ticks":[ticks//laps]*(laps-1)+[ticks-ticks//laps*(laps-1)],
            "ghost":{"ticks":ticks,"poses":[[0,0,0,0,0,0,0],[ticks,0,0,0,0,0,0]]}}


def pack_replay(replay):
    controls = bytearray()
    for frame in replay["frames"]:
        controls.extend((len(frame),frame[0]+127,frame[1],frame[2],frame[3] if len(frame)>3 else 0,frame[4] if len(frame)>4 else 0))
    value = {"schema":"bmt-packed-input-v1","replay_schema":replay["schema"],
        "frame_count":len(replay["frames"]),"controls":base64.b64encode(controls).decode("ascii")}
    if "rewinds" in replay:
        value["rewinds"] = replay["rewinds"]
    return value


def seed(app, *, players=1000, tracks=100, actors=40, boards=5, tie_every=0, memberships=True):
    """Batch seeding; no credentials or IDs enter reports. All data is isolated."""
    fixture = golden_fixture()
    factory, stamp = app.state.session_factory, now()
    actors = min(actors,players)
    ids = [str(uuid.uuid4()) for _ in range(players)]
    access = [secrets.token_urlsafe(32) for _ in range(actors)]
    with factory() as session:
        for start in range(0,players,500):
            session.execute(insert(Player),[{"id":pid,"display_name":f"Load fixture {i}","username_key":f"load fixture {i}",
                "needs_username":False,"disabled":False,"is_test_driver":False,"created_at":stamp}
                for i,pid in enumerate(ids[start:start+500],start)])
            session.commit()
        for i in range(actors):
            family = SessionFamily(player_id=ids[i],expires_at=stamp+86400)
            session.add(family); session.flush()
            session.add(SessionToken(family_id=family.id,access_hash=token_digest(access[i]),
                refresh_hash=token_digest(secrets.token_urlsafe(32)),access_expires_at=stamp+86400,consumed=False))
        session.commit()
    content = app.state.blobs.put_json(fixture["document"])
    manifest = app.state.verifier.validate_track(fixture["document"])
    replay_hash = app.state.blobs.put_json(fixture["replay"])
    # Representative 20 Hz presentation payload, explicitly synthetic evidence.
    ticks = fixture["time_ticks"]
    poses = [[tick,round(40*math.sin(tick/100),4),0,
        round(40*math.cos(tick/100),4),round(tick/100,4),0,0] for tick in range(0,ticks,6)]
    poses.append([ticks,0,0,0,0,0,0])
    ghost_hash = app.state.blobs.put_json({"ticks":ticks,"poses":poses})
    versions, board_ids = [], []
    with factory() as session:
        for i in range(tracks):
            track = Track(owner_id=ids[0],official=True)
            session.add(track); session.flush()
            version = TrackVersion(track_id=track.id,number=1,name=f"Load circuit {i}",content_hash=content,
                manifest=manifest,state="published",published_at=stamp,
                discovery={"theme":"pine","points":fixture["document"]["points"]})
            session.add(version); session.flush()
            versions.append(version.id)
            if i < boards:
                pinned = board_manifest(version,"compact")
                bid = digest({"version_id":version.id,**pinned})
                session.add(Board(id=bid,version_id=version.id,vehicle_id="compact",manifest=pinned)); session.flush()
                board_ids.append(bid)
        session.commit()
    # A hot public board with the requested population; several comparable
    # boards for the small actor set exercise the expensive matching path.
    runs = {}
    with factory() as session:
        for slot,bid in enumerate(board_ids):
            selected = ids if slot==0 else ids[:actors]
            for start in range(0,len(selected),500):
                tickets, attempts, bests = [], [], []
                for i,pid in enumerate(selected[start:start+500],start):
                    tid,rid = str(uuid.uuid4()),str(uuid.uuid4())
                    ticks = 13000+(i%4000 if not tie_every else (i//tie_every)%4000)
                    tickets.append({"id":tid,"player_id":pid,"board_id":bid,"created_at":stamp,"expires_at":stamp+7200})
                    attempts.append({"id":rid,"ticket_id":tid,"player_id":pid,"board_id":bid,"replay_hash":replay_hash,"ghost_hash":ghost_hash,
                        "status":"verified","created_at":stamp,"finished_at":stamp,"attempts":1,"lease_until":0,
                        "time_ticks":ticks,"lap_ticks":[ticks//5]*4+[ticks-4*(ticks//5)]})
                    bests.append({"board_id":bid,"player_id":pid,"run_id":rid,"time_ticks":ticks,"achieved_at":stamp})
                    if i < actors:
                        runs[(slot,pid)] = (rid,ticks)
                session.execute(insert(RunTicket),tickets)
                session.execute(insert(Run),attempts)
                session.execute(insert(PersonalBest),bests)
                session.commit()
    # Seed only a bounded set of viewing groups. Population size still drives
    # board/eligibility queries, without allocating 100K HTTP clients at once.
    group_ids = []
    if not memberships:
        return {"players":ids,"access":access,"versions":versions,"boards":board_ids,"groups":[],
            "fixture":fixture,"actors":actors}
    with factory() as session:
        from types import SimpleNamespace
        _active,contract = active_contract(SimpleNamespace(app=app),"compact")
        start,end,_,_ = week_window(stamp)
        for first in range(0,actors,20):
            slots = []
            for slot in range(5):
                version = session.get(TrackVersion,versions[slot])
                slots.append({"version_id":version.id,"board_id":board_ids[slot],"tick_rate":120,
                    "entry":{"track_id":version.track_id,"version_id":version.id,"name":version.name,
                        "creator":"Load fixture","content_hash":content,"theme":"pine","points":fixture["document"]["points"]}})
            group = RivalryGroup(week_start=start,ends_at=end,vehicle_id="compact",contract_key=contract,
                skill_band=-1,tracks=slots,member_count=min(20,actors-first))
            session.add(group); session.flush()
            group_ids.append(group.id)
            for pid in ids[first:min(first+20,actors)]:
                session.add(RivalryMember(group_id=group.id,player_id=pid,week_start=start,contract_key=contract))
                for slot in range(5):
                    rid,ticks = runs[(slot,pid)]
                    session.add(RivalryBest(group_id=group.id,player_id=pid,slot=slot,run_id=rid,time_ticks=ticks))
            session.commit()
    return {"players":ids,"access":access,"versions":versions,"boards":board_ids,"groups":group_ids,
        "fixture":fixture,"actors":actors}
