"""Authorised patch rollout: stable competitive manifest, no data/schema migration."""
import argparse
import hashlib
import importlib.util
import json
from pathlib import Path
import shutil
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[2]
WORK = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location("release_util", ROOT / "build/full-backend-deploy-2026-10-26/deploy.py")
d = importlib.util.module_from_spec(spec)
spec.loader.exec_module(d)
d.WORK, d.OUT, d.STATE = WORK, WORK / "receipts", WORK / "state.private.json"
d.OUT.mkdir(exist_ok=True)
d.state = json.loads(d.STATE.read_text()) if d.STATE.exists() else {}
d.HEAD = "0072_fixed_daily_lap_limits"
class PrivateRunner(d.staging.Runner):
    def run(self, argv, *, input_data=None, allow_missing=False, cwd=None):
        assert cwd is None
        if "print-access-token" in argv or "print-identity-token" in argv:
            result=subprocess.run(argv,input=input_data,capture_output=True,text=True,timeout=60)
            assert result.returncode==0, "Credential refresh failed; token output was not logged"
            return result.stdout.strip()
        return d.command(argv,"cloud-command",input_data=input_data,allow_missing=allow_missing)

d.service = d.staging.Staging(d.config, WORK, PrivateRunner())
s, service = d.state, d.service
REGION = "--region=" + d.config["region"]
DOCKER = ["wsl.exe", "-d", "Ubuntu", "--", "docker"]
SOURCES = ["game/race/race_rules.gd", "game/race/track_session.gd", "game/race/spline_gate_corridor.gd",
           "game/race/road_gate_coverage.gd", "game/backend/runner.gd", "backend/bmt_backend/trajectory_verifier.py"]


def inspect():
    assert not s.get("rollout_started")
    service.preflight()
    jobs = json.loads(service.call("run", "jobs", "list", REGION, "--format=json"))
    targets = [("api", service.n["api"]), ("api", service.n["admin"]), ("worker", service.n["worker"])]
    targets += [("job", row["metadata"]["name"]) for row in jobs if row["metadata"].get("labels", {}).get("bmt-owner") == d.config["owner"]]
    s["targets"], s["parents"] = {}, {}
    for kind, name in targets:
        resource = service.describe(kind, name)
        assert resource
        d.write(WORK / ("before-" + name + ".private.json"), resource)
        s["targets"][name] = kind
        s["parents"][name] = d.staging.resource_image(resource)
    api = service.describe("api", service.n["api"])
    sql = service.describe("sql", service.n["sql"])
    assert sql["settings"]["deletionProtectionEnabled"] is True
    s["url"] = api["status"]["url"]
    response = d.http(s["url"], "/v1/manifest"); response.raise_for_status()
    s["manifest_before"] = response.json()
    assert s["manifest_before"]["rules_key"] == "standing-5-road-gates-v23"
    assert s["manifest_before"]["physics_version"] == "arcade-planar-0.77"
    assert d.verify_api(s["url"])
    s["original_traffic"] = {}
    for name in (service.n["api"], service.n["admin"]):
        resource = service.describe("api", name)
        s["original_traffic"][name] = resource["status"]["traffic"]
    preview = next(row for row in api["status"]["traffic"] if row.get("tag") == "website-preview")
    revision = json.loads(service.call("run", "revisions", "describe", preview["revisionName"], REGION, "--format=json"))
    s["preview_parent"] = revision["spec"]["containers"][0]["image"]
    assert set(s["parents"].values()) == {s["parents"][service.n["api"]]}
    s["base"] = s["parents"][service.n["api"]]
    s["schema_before"] = d.HEAD
    d.save()
    print(json.dumps({"targets": len(s["targets"]), "base": s["base"], "preview_parent": s["preview_parent"],
                      "rules": s["manifest_before"]["rules_key"], "schema": d.HEAD}), flush=True)


def prepare():
    context = WORK / "context"
    context.mkdir(exist_ok=False)
    for relative in SOURCES:
        target = context / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(ROOT / relative, target)
    (context / "manifest-before.json").write_text(json.dumps(s["manifest_before"]))
    (context / "Dockerfile").write_text('''ARG BASE
FROM ${BASE}
USER root
COPY game/ /opt/bmt/game/
COPY backend/bmt_backend/trajectory_verifier.py /app/bmt_backend/trajectory_verifier.py
RUN chmod -R u+w /opt/bmt && python /app/deploy/check_godot.py --import-project /opt/bmt/game --fixture /opt/bmt/acceptance/verified_oval.json && chmod -R a-w /opt/bmt
USER 10001:10001
''')
    s["source_hashes"] = {rel: hashlib.sha256((context / rel).read_bytes()).hexdigest() for rel in SOURCES}
    s["source_hash"] = hashlib.sha256(json.dumps(s["source_hashes"], sort_keys=True).encode()).hexdigest()
    d.save()
    print("Frozen six-file checkpoint patch; all other deployed files inherited unchanged.", flush=True)


def sources_match():
    assert all(hashlib.sha256((ROOT / rel).read_bytes()).hexdigest() == value for rel, value in s["source_hashes"].items())


def build():
    sources_match()
    for role, parent in (("main", s["base"]), ("preview", s["preview_parent"])):
        tag = "bmt-checkpoints-20261103-" + role + ":" + s["source_hash"][:16]
        d.command(DOCKER + ["build", "--platform=linux/amd64", "--build-arg", "BASE="+parent,
                           "-t", tag, d.unix(WORK / "context")], "build-"+role, timeout=600)
        s["local_"+role] = tag; d.save()
        print("Built exact patch image " + role, flush=True)


def test():
    sources_match()
    for role in ("main", "preview"):
        output = d.command(DOCKER + ["run", "--rm", "--network=none", "--mount",
                            "type=bind,src="+d.unix(WORK / "tests")+",dst=/tests,readonly",
                            "--entrypoint", "python", s["local_"+role], "/tests/accept.py"], "accept-"+role, timeout=240)
        value = json.loads(next(row.split("=",1)[1] for row in output.splitlines() if row.startswith("PATCH_ACCEPTANCE=")))
        assert value["manifest"] == s["manifest_before"] and value["layout"] == 24 and value["cuts_rejected"] == 9
        d.write(d.OUT / ("accept-"+role+".json"), value)
        print("Exact Linux acceptance passed: " + role + "; manifest unchanged; nine cuts rejected", flush=True)
    s["tests_passed"] = True; d.save()


def push():
    assert s.get("tests_passed")
    sources_match()
    auth = WORK / "docker-auth"; auth.mkdir(exist_ok=False)
    try:
        token = service.call("auth", "print-access-token")
        d.command(DOCKER + ["--config", d.unix(auth), "login", "europe-west1-docker.pkg.dev",
                           "--username=oauth2accesstoken", "--password-stdin"], "docker-login", input_data=token)
        del token
        for role in ("main", "preview"):
            remote = s["base"].split("@")[0] + ":checkpoints-20261103-"+role+"-"+s["source_hash"][:16]
            d.command(DOCKER + ["tag", s["local_"+role], remote], "tag-"+role)
            d.command(DOCKER + ["--config",d.unix(auth),"push","--quiet",remote], "push-"+role, timeout=600)
            meta = json.loads(service.call("artifacts","docker","images","describe",remote,"--format=json"))
            digest = meta["image_summary"]["digest"]
            assert digest.startswith("sha256:")
            s["image_"+role] = remote.split(":")[0]+"@"+digest; d.save()
    finally:
        assert auth.resolve().parent == WORK.resolve() and not auth.is_symlink()
        shutil.rmtree(auth)
    print("Both immutable patch images pushed.", flush=True)


def aggregate(label):
    code = '''import json
from sqlalchemy import text
from bmt_backend.config import Settings
from bmt_backend.db import make_engine
e=make_engine(Settings.from_env().database_url)
with e.connect() as c:
 c.execute(text('SET TRANSACTION ISOLATION LEVEL REPEATABLE READ READ ONLY'))
 names=['boards','personal_bests','lap_personal_bests','runs','rivalry_groups','rivalry_members','rivalry_bests','rivalry_archived_bests','rivalry_week_plans','track_versions','track_of_day_bests','world_ranking_standings','world_ranking_careers']
 existing=set(c.execute(text("SELECT tablename FROM pg_tables WHERE schemaname='public'")).scalars())
 value={'schema':c.scalar(text('SELECT version_num FROM alembic_version')),'tables':{name:c.scalar(text('SELECT count(*) FROM "'+name+'"')) for name in names if name in existing},'pending':c.scalar(text("SELECT count(*) FROM runs WHERE status IN ('queued','verifying')")),'private_rows_exported':False}
print('RELEASE_RESULT='+json.dumps(value));e.dispose()
'''
    return d.execute(label, code, job=service.n["migrate"], timeout=180)


def backup():
    assert s.get("image_main") and s.get("tests_passed")
    for name in s["targets"]: d.guarded(name)
    s["data_before"] = aggregate("results-before")
    assert s["data_before"]["schema"] == d.HEAD
    description = "Before result-preserving checkpoint patch " + s["source_hash"][:16]
    service.call("sql","backups","create","--instance="+service.n["sql"],"--description="+description,"--format=json")
    rows=json.loads(service.call("sql","backups","list","--instance="+service.n["sql"],"--format=json"))
    found=[row for row in rows if row.get("description")==description and row.get("status")=="SUCCESSFUL"]
    assert found
    s["backup_id"]=found[0]["id"];d.save()
    print(json.dumps({"backup_id":s["backup_id"],"result_counts":s["data_before"]["tables"]}),flush=True)


def rollout():
    assert s.get("backup_id") and s.get("tests_passed")
    sources_match()
    lock=ROOT / ".tools/gcp-staging" / ("rendered-"+d.config["owner"]) / "update.lock"
    lock.parent.mkdir(exist_ok=True)
    with lock.open("x") as stream: json.dump({"task":"checkpoint-results-20261103","source_hash":s["source_hash"]},stream)
    s["rollout_started"]=True;d.save()
    # Competitive identity, schema and API protocol are unchanged; rolling
    # replacement keeps normal requests/races available without maintenance.
    canaries={}
    for name in (service.n["api"],service.n["admin"]):
        d.guarded(name)
        service.call("run","services","update",name,REGION,"--image="+s["image_main"],"--no-traffic","--tag=checkpoint-new","--format=json")
        resource=service.describe("api",name)
        row=next(row for row in resource["status"]["traffic"] if row.get("tag")=="checkpoint-new")
        if name==service.n["api"]:
            d.verify_api(row["url"])
            assert d.http(row["url"],"/v1/manifest").json()==s["manifest_before"]
        else:d.verify_admin(row["url"])
        canaries[name]={"revision":row["revisionName"],"url":row["url"]}
    s["canaries"]=canaries;d.save()
    # Website preview retains its own inherited website files.
    service.call("run","services","update",service.n["api"],REGION,"--image="+s["image_preview"],"--no-traffic","--tag=checkpoint-preview","--format=json")
    resource=service.describe("api",service.n["api"])
    preview=next(row for row in resource["status"]["traffic"] if row.get("tag")=="checkpoint-preview")
    assert d.http(preview["url"],"/v1/manifest").json()==s["manifest_before"]
    s["preview_revision"]=preview["revisionName"];d.save()
    for name,kind in s["targets"].items():
        if kind=="api":continue
        d.guarded(name)
        interface="worker-pools" if kind=="worker" else "jobs"
        service.call("run",interface,"update",name,REGION,"--image="+s["image_main"],"--format=json")
        print("Updated "+name,flush=True)
    for name,row in canaries.items():
        service.call("run","services","update-traffic",name,REGION,"--to-revisions="+row["revision"]+"=100","--format=json")
    service.call("run","services","update-traffic",service.n["api"],REGION,"--update-tags=website-preview="+s["preview_revision"],"--format=json")
    s["promoted"]=True;d.save()
    print("Promoted API and Studio; worker/jobs patched; manifest unchanged.",flush=True)


def verify():
    assert s.get("promoted")
    assert d.http(s["url"],"/v1/manifest").json()==s["manifest_before"]
    d.verify_api(s["url"])
    s["data_after"]=aggregate("results-after")
    assert s["data_after"]["schema"]==d.HEAD
    assert all(s["data_after"]["tables"][name]>=count for name,count in s["data_before"]["tables"].items())
    code='''import json,os,time
from bmt_backend.app import create_app
from bmt_backend.operations import competition_health
from bmt_backend.cloud_smoke import check
from bmt_backend.config import Settings
a=create_app()
for i in range(90):
 h=competition_health(a)
 if h['status']=='ready' and h['available_workers']>=1:break
 time.sleep(2)
else:raise RuntimeError('Worker not ready')
v=a.state.verifier;g=v.race_geometry(__import__('json').load(open('/opt/bmt/acceptance/verified_oval.json'))['document'])
assert g['checkpoint_layout_version']==24
r=check(Settings.from_env(),os.environ['BMT_STAGING_OWNER'])
print('RELEASE_RESULT='+json.dumps({'worker_status':h['status'],'available_workers':h['available_workers'],'queue_depth':h['queue_depth'],'manifest':v.manifest(),'checkpoint_layout_version':g['checkpoint_layout_version'],'smoke':r}))
v.close();a.state.engine.dispose()
'''
    value=d.execute("live-acceptance",code,timeout=420)
    assert value["manifest"]==s["manifest_before"] and value["smoke"]["status"]=="passed"
    for name in s["targets"]:
        d.guarded(name,[s["image_main"],s["image_preview"]])
    for name in (service.n["api"],service.n["admin"]):
        tags="checkpoint-new,checkpoint-preview" if name==service.n["api"] else "checkpoint-new"
        service.call("run","services","update-traffic",name,REGION,"--remove-tags="+tags,"--format=json")
    lock=ROOT / ".tools/gcp-staging" / ("rendered-"+d.config["owner"]) / "update.lock"
    assert json.loads(lock.read_text())["source_hash"]==s["source_hash"]
    lock.unlink()
    s["completed"]=True;d.save()
    print(json.dumps({"deployed":True,"manifest_unchanged":True,"checkpoint_layout_version":24,"backup_id":s["backup_id"],"result_counts_before":s["data_before"]["tables"],"result_counts_after":s["data_after"]["tables"]}),flush=True)


def receipts():
    assert s.get("completed")
    api=service.describe("api",service.n["api"])
    before=api["status"]["traffic"]
    if d.staging.resource_image(api)!=s["image_main"]:
        # Keep the default service template aligned with its production image;
        # the separately tagged website preview retains its own tested image.
        service.call("run","services","update",service.n["api"],REGION,"--image="+s["image_main"],"--no-traffic","--format=json")
        after=service.describe("api",service.n["api"])["status"]["traffic"]
        assert {(r.get("revisionName"),r.get("percent"),r.get("tag")) for r in before}=={(r.get("revisionName"),r.get("percent"),r.get("tag")) for r in after}
    for name in s["targets"]:d.guarded(name,[s["image_main"]])
    folder=ROOT/".tools/gcp-staging"/("rendered-"+d.config["owner"])
    for name in ("deployment.json","image.json","test-population.json"):
        path=folder/name
        if path.exists():
            old=json.loads(path.read_text())
            assert old["image"] in (s["base"],s["image_main"])
            shutil.copyfile(path,WORK/(name+".before.private.json"))
            old["image"]=s["image_main"]
            if name in ("deployment.json","image.json"):
                old["source_hash"]=s["source_hash"]
                old["patch_base_image"]=s["base"]
            if name=="deployment.json":old["schema"]=d.HEAD
            d.write(path,old)
    s["release_receipts_saved"]=True;d.save()
    print("All ten default images aligned; original traffic/preview routes unchanged; retained release receipts saved.",flush=True)


if __name__=="__main__":
    parser=argparse.ArgumentParser();parser.add_argument("stage",choices=["inspect","prepare","build","test","push","backup","rollout","verify","receipts"])
    globals()[parser.parse_args().stage]()
