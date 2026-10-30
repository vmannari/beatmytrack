"""Actual pinned Godot client against an owned loopback API and fake identities."""
import json
import os
import sys
from pathlib import Path

ROOT=Path(__file__).resolve().parents[3]
OUT=Path(__file__).resolve().parent
BUILD=ROOT/"build/backend-local-cost-simulation-2026-10-26"
sys.path.insert(0,str(ROOT/"backend"))
sys.path.insert(0,str(ROOT/"backend/tests"))
from test_cloud_client import run_client
from test_cost_http import FIXTURE,seed


def main():
    for key,folder in (("APPDATA","appdata"),("LOCALAPPDATA","localappdata")):
        target=BUILD/"native-profile"/folder;target.mkdir(parents=True,exist_ok=True)
        os.environ[key]=str(target)
    trial="native-http-final" if "--final-trial" in sys.argv else "native-http"
    temporary=BUILD/trial;temporary.mkdir(parents=True,exist_ok=True)
    observations=[]
    def prepare(app):
        seed(app)
        observe=app.state.http_costs.observe
        def record(value):
            observations.append({k:value[k] for k in ("route","method","status","response_wire_bytes","duration_ms")})
            observe(value)
        app.state.http_costs.observe=record
    run_client(temporary,str(OUT/"native_cache_probe.gd"),prepare=prepare,
        settings_overrides={"object_packing_enabled":True},
        extra_env={"BMT_GHOST_WIRE_FIXTURE":str(FIXTURE),"BMT_NATIVE_COST_CACHE":str(temporary/"recording-cache")})
    ghosts=[row for row in observations if row["route"].endswith("/ghost")]
    large=[row for row in ghosts if row["status"]==200 and row["response_wire_bytes"]>10000]
    assert len(large)==1
    assert any(row["status"]>=400 for row in ghosts)
    result={"client":"Pinned Godot4.7.2, actual client code","successful_recording_accesses":11,
        "full_recording_downloads":1,"persistent_cache_hits":10,"fresh_client_reuses_disk_cache":True,
        "withdrawn_source_rejected":True,"ghost_route_observations":ghosts,
        "compressed_ghost_response_bytes_total":sum(r["response_wire_bytes"] for r in ghosts),
        "first_recording_body_wire_bytes":large[0]["response_wire_bytes"],
        "qualifications":["Loopback, SQLite HTTP fixture and synthetic accounts; real client cache/decoder and compression",
            "Headers/TLS excluded; actual public egress and player-day reuse distribution are unmeasured",
            "Native canonical work prepares diagnostic fixture only; no ordinary full-replay fallback introduced"]}
    (OUT/"native-cache.json").write_text(json.dumps(result,indent=2)+"\n",encoding="utf-8")
    print(json.dumps({k:v for k,v in result.items() if k!="ghost_route_observations"}),flush=True)


if __name__=="__main__":
    main()
