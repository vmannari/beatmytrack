"""Restore synthetic objects and verify real PostgreSQL pack/archive pointers."""
import json
import os
import subprocess
import sys
from pathlib import Path

ROOT=Path(__file__).resolve().parents[3]
OUT=Path(__file__).resolve().parent
BUILD=ROOT/"build/backend-local-cost-simulation-2026-10-26"
sys.path.insert(0,str(ROOT/"backend"))
from sqlalchemy.engine import make_url
from database_probe import fixture_url
from bmt_backend.app import create_app
from bmt_backend.config import Settings
from bmt_backend.db import make_engine,make_session_factory
from bmt_backend.packed_storage import PackedBlobStore
from bmt_backend.storage import LocalBlobStore,PinnedBlobStore
from bmt_backend.track_models import replay_response


def main():
    helper=ROOT/"backend/deploy/object_archive.py"
    sizes={}
    for name in ("packed","archive"):
        source=BUILD/("packed-objects" if name=="packed" else "archive-objects")
        destination=BUILD/("restored-"+name)
        if destination.exists():
            raise RuntimeError("Restore destination already exists; refuse overwrite")
        archived=subprocess.run([sys.executable,str(helper),"archive","--root",str(source)],
            env=os.environ|{"BMT_OBJECT_BACKEND":"local"},capture_output=True,timeout=60)
        if archived.returncode:
            raise RuntimeError("Synthetic object archive failed")
        restored=subprocess.run([sys.executable,str(helper),"restore","--root",str(destination)],
            input=archived.stdout,env=os.environ|{"BMT_OBJECT_BACKEND":"local"},capture_output=True,timeout=60)
        if restored.returncode:
            raise RuntimeError("Synthetic object restore failed")
        sizes[name]=len(archived.stdout)
    # create_app initializes the complete model registry; no database IO occurs here.
    registry=create_app(Settings(environment="test",database_url="sqlite://",object_dir=str(BUILD/"restore-registry")))
    registry.state.engine.dispose()
    url=make_url(fixture_url()).set(database="bmt_cost_restored")
    settings=Settings(environment="test",object_packing_enabled=True)
    engine=make_engine(url.render_as_string(hide_password=False),settings)
    factory=make_session_factory(engine)
    try:
        packed=PackedBlobStore(LocalBlobStore(str(BUILD/"restored-packed")),factory,settings)
        manifest=json.loads((BUILD/"restore-validation.json").read_text())
        recording=json.loads((ROOT/"docs/evidence/cost-optimisation-implementation-2026-10-24/ghost-wire-fixture.json").read_text())["original"]
        for key,index in zip(manifest["packed_keys"],manifest["packed_indexes"],strict=True):
            assert packed.get_json(key)=={"fixture":"synthetic cost record","index":index,"recording":recording}
        assert packed.get_json(manifest["pending_key"])==manifest["pending_value"]
        archives=PinnedBlobStore(LocalBlobStore(str(BUILD/"restored-archive")),factory)
        factory.configure(info={"cost_archive_blobs":archives,"cost_archive_days":7})
        probes=json.loads((BUILD/"archive-restore-probes.json").read_text())
        for row in probes:
            with factory() as db:
                result=replay_response(db,row["player_id"],row["scope"],row["key"],{"operation":row["response"]["accepted_operation"]})
                assert result==row["response"]
        result={"restored_pack_records_checked":len(manifest["packed_keys"]),"restored_pending_record_checked":True,
            "restored_private_archive_replies_checked":len(probes),"all_values_exact":True,"object_archive_bytes":sizes,
            "scope":"Real pg_dump/pg_restore of synthetic database plus source object archive/restore into fresh local directories",
            "limitations":["Not Cloud SQL failover/PITR or full production disaster recovery","No real erased-player ledger replay tested in this experiment"]}
        (OUT/"restore-validation.json").write_text(json.dumps(result,indent=2)+"\n",encoding="utf-8")
        print(json.dumps(result))
    finally:
        engine.dispose()


if __name__=="__main__":
    main()
