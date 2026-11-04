"""Authorised publication fix; retain data, credentials, routes and game manifest."""
import argparse
import hashlib
import importlib.util
import json
from pathlib import Path
import secrets
import shutil
import subprocess
import time

ROOT = Path(__file__).resolve().parents[2]
WORK = Path(__file__).resolve().parent
OUT = ROOT / "docs/evidence/publication-backend-fix-2026-11-03"
OUT.mkdir(parents=True, exist_ok=True)
spec = importlib.util.spec_from_file_location("release_util", ROOT / "build/full-backend-deploy-2026-10-26/deploy.py")
d = importlib.util.module_from_spec(spec)
spec.loader.exec_module(d)
d.WORK, d.OUT, d.STATE = WORK, OUT, WORK / "state.private.json"
d.state = json.loads(d.STATE.read_text()) if d.STATE.exists() else {}
d.HEAD = "0073_publication_publisher_check"


class PrivateRunner(d.staging.Runner):
    def run(self, argv, *, input_data=None, allow_missing=False, cwd=None):
        assert cwd is None
        if "print-access-token" in argv or "print-identity-token" in argv:
            value = subprocess.run(argv, input=input_data, capture_output=True, text=True, timeout=60)
            assert value.returncode == 0, "Credential refresh failed; no token output logged"
            return value.stdout.strip()
        return d.command(argv, "cloud-command", input_data=input_data, allow_missing=allow_missing)


d.service = d.staging.Staging(d.config, WORK, PrivateRunner())
s, service = d.state, d.service
REGION = "--region=" + d.config["region"]
DOCKER = ["wsl.exe", "-d", "Ubuntu", "--", "docker"]
PUBLICATION = "e1045945-cad2-46c8-8b29-d296f39b81ab"
SOURCES = ["backend/bmt_backend/publications.py", "backend/bmt_backend/database_privileges.py", "backend/bmt_backend/commerce.py",
           "backend/bmt_backend/migrations/versions/0073_publication_publisher_check.py"]


def inspect():
    assert not s.get("rollout_started")
    jobs = json.loads(service.call("run", "jobs", "list", REGION, "--format=json"))
    targets = [("api", service.n["api"]), ("api", service.n["admin"]), ("worker", service.n["worker"])]
    targets += [("job", row["metadata"]["name"]) for row in jobs
                if row["metadata"].get("labels", {}).get("bmt-owner") == d.config["owner"]]
    s["targets"], s["parents"] = {}, {}
    for kind, name in targets:
        value = service.describe(kind, name)
        d.write(WORK / ("before-" + name + ".private.json"), value)
        s["targets"][name], s["parents"][name] = kind, d.staging.resource_image(value)
    api = service.describe("api", service.n["api"])
    s["url"] = api["status"]["url"]
    response = d.http(s["url"], "/v1/manifest")
    response.raise_for_status()
    s["manifest_before"] = response.json()
    s["base"] = s["parents"][service.n["api"]]
    assert set(s["parents"].values()) == {s["base"]}, "Existing images differ; inspect before proceeding"
    assert s["base"].endswith("sha256:6d5d253d9173d15b1f61becebfba19514ef05a741b911cd36d59f20d87d802cb")
    s["original_traffic"] = api["status"]["traffic"]
    preview = next(row for row in api["status"]["traffic"] if row.get("tag") == "website-preview")
    revision = json.loads(service.call("run", "revisions", "describe", preview["revisionName"], REGION, "--format=json"))
    s["preview_parent"] = revision["spec"]["containers"][0]["image"]
    s["schema_before"] = d.http(s["url"], "/ready").json()["schema"]
    assert s["schema_before"] == "0072_fixed_daily_lap_limits"
    worker = json.loads((WORK / ("before-" + service.n["worker"] + ".private.json")).read_text())
    flags = d.envmap(worker)
    s["purchase_simulation"] = flags.get("BMT_PURCHASE_SIMULATION_ENABLED", {}).get("value", "false").lower() == "true"
    d.save()
    print(json.dumps({"targets": len(s["targets"]), "base": s["base"], "preview": s["preview_parent"],
                      "schema": s["schema_before"], "worker_purchase_simulation": s["purchase_simulation"]}), flush=True)


def prepare():
    context = WORK / "context"
    context.mkdir(exist_ok=True)
    for relative in SOURCES:
        target = context / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(ROOT / relative, target)
    tests = WORK / "tests"
    tests.mkdir(exist_ok=True)
    for name in ("test_publication_worker_privileges.py", "test_publication_intents.py", "test_domains.py",
                 "test_cloud_setup.py", "test_runtime_privileges.py", "test_publication_background_priority.py",
                 "test_publication_latency.py", "test_track_links.py", "conftest.py", "legacy_authoring_fixture.py"):
        shutil.copyfile(ROOT / "backend/tests" / name, tests / name)
    (context / "Dockerfile").write_text('''ARG BASE
FROM ${BASE}
USER root
COPY backend/bmt_backend/publications.py /app/bmt_backend/publications.py
COPY backend/bmt_backend/database_privileges.py /app/bmt_backend/database_privileges.py
COPY backend/bmt_backend/commerce.py /app/bmt_backend/commerce.py
COPY backend/bmt_backend/migrations/versions/0073_publication_publisher_check.py /app/bmt_backend/migrations/versions/0073_publication_publisher_check.py
USER 10001:10001
''', encoding="utf-8")
    s["source_hashes"] = {rel: hashlib.sha256((context / rel).read_bytes()).hexdigest() for rel in SOURCES}
    s["source_hash"] = hashlib.sha256(json.dumps(s["source_hashes"], sort_keys=True).encode()).hexdigest()
    d.write(OUT / "sources.json", s["source_hashes"])
    d.save()
    print("Frozen four runtime files and focused regression tests", flush=True)


def sources_match():
    assert all(hashlib.sha256((ROOT / rel).read_bytes()).hexdigest() == digest
               for rel, digest in s["source_hashes"].items())


def build():
    sources_match()
    for role, parent in (("main", s["base"]), ("preview", s["preview_parent"])):
        tag = "bmt-publication-20261103-" + role + ":" + s["source_hash"][:16]
        d.command(DOCKER + ["build", "--network=none", "--pull=false", "--build-arg", "BASE=" + parent,
                           "-t", tag, d.unix(WORK / "context")], "build-" + role, timeout=600)
        s["local_" + role] = tag
        d.save()
        print("Built " + role, flush=True)


def test():
    sources_match()
    network = "bmt-publication-fix-20261103"
    pg = network + "-pg"
    label = "bmt.publication-fix=20261103"
    password = secrets.token_hex(24)
    pg_env, test_env = WORK / "pg.private.env", WORK / "test.private.env"
    pg_env.write_text("POSTGRES_PASSWORD=" + password + "\nPOSTGRES_DB=bmt_publication\n")
    url = "postgresql+psycopg://postgres:" + password + "@" + pg + "/bmt_publication"
    test_env.write_text("BMT_TEST_DATABASE_URL=" + url + "\nBMT_GCP_SETUP_TEST_DATABASE_URL=" + url +
                        "\nPYTHONPATH=/app:/test-work/backend/tests\n")
    d.command(DOCKER + ["network", "create", "--internal", "--label", label, network], "test-network")
    try:
        d.command(DOCKER + ["run", "-d", "--rm", "--name", pg, "--network", network, "--label", label,
                            "--pull=never", "--env-file", d.unix(pg_env), "--tmpfs", "/var/lib/postgresql/data:rw",
                            "postgres:17-bookworm", "-c", "max_connections=60"], "test-postgres")
        for _ in range(40):
            ready = subprocess.run(DOCKER + ["exec", pg, "pg_isready", "-U", "postgres"], capture_output=True)
            if ready.returncode == 0:
                break
            time.sleep(.25)
        else:
            raise RuntimeError("Owned test database unavailable")
        common = DOCKER + ["run", "--rm", "--network", network, "--label", label, "--env-file", d.unix(test_env),
                           "--mount", "type=bind,src=" + d.unix(WORK / "tests") + ",dst=/test-work/backend/tests,readonly",
                           "--mount", "type=bind,src=" + d.unix(OUT) + ",dst=/results", "--workdir", "/test-work/backend/tests",
                           "--entrypoint", "python"]
        for role in ("main", "preview"):
            output = d.command(common + [s["local_" + role], "-m", "pytest", "test_publication_worker_privileges.py",
                "test_publication_intents.py", "test_runtime_privileges.py", "test_publication_background_priority.py",
                "test_track_links.py", "-q", "--tb=short", "--show-capture=no", "-p", "no:cacheprovider",
                "--junitxml=/results/tests-" + role + ".xml"], "tests-" + role, timeout=480)
            (OUT / ("tests-" + role + ".log")).write_text(output, encoding="utf-8")
            print(role + ": " + output.splitlines()[-1], flush=True)
        # Run the same new worker test with the task-start publication source.
        original = subprocess.run(common[:-2] + ["--mount", "type=bind,src=" + d.unix(WORK / "before/publications.py") +
                 ",dst=/app/bmt_backend/publications.py,readonly", "--entrypoint", "python", s["local_main"],
                 "-m", "pytest", "test_publication_worker_privileges.py", "-q", "--tb=short", "--show-capture=no",
                 "-p", "no:cacheprovider"], capture_output=True, text=True, timeout=180)
        control = (original.stdout + original.stderr).replace(password, "[REDACTED]")
        (OUT / "original-control.log").write_text(control, encoding="utf-8")
        assert original.returncode == 1 and "6 failed" in control and "permission denied for table identities" in control
        print("Original-source control: six permission failures reproduced", flush=True)
        for role in ("main", "preview"):
            output = d.command(DOCKER + ["run", "--rm", "--network=none", "--entrypoint", "python", s["local_" + role],
                "-c", "import json;from types import SimpleNamespace;from bmt_backend.verifier import GodotVerifier;v=GodotVerifier(SimpleNamespace(godot_bin='/usr/local/bin/godot',game_project='/opt/bmt/game',verifier_timeout_seconds=90));print(json.dumps(v.manifest()));v.close()"],
                "manifest-" + role, timeout=90)
            assert json.loads(output.splitlines()[-1]) == s["manifest_before"]
        s["tests_passed"] = True
        d.save()
    finally:
        meta = json.loads(d.command(DOCKER + ["inspect", pg], "test-owner"))[0]
        assert meta["Config"]["Labels"]["bmt.publication-fix"] == "20261103"
        d.command(DOCKER + ["stop", pg], "test-cleanup")
        meta = json.loads(d.command(DOCKER + ["network", "inspect", network], "network-owner"))[0]
        assert meta["Labels"]["bmt.publication-fix"] == "20261103"
        d.command(DOCKER + ["network", "rm", network], "network-cleanup")
        for path in (pg_env, test_env):
            path.unlink(missing_ok=True)


def push():
    assert s.get("tests_passed")
    sources_match()
    auth = WORK / "docker-auth"
    auth.mkdir(exist_ok=False)
    try:
        token = service.call("auth", "print-access-token")
        d.command(DOCKER + ["--config", d.unix(auth), "login", "europe-west1-docker.pkg.dev",
                           "--username=oauth2accesstoken", "--password-stdin"], "docker-login", input_data=token)
        del token
        for role in ("main", "preview"):
            remote = s["base"].split("@")[0] + ":publication-20261103-" + role + "-" + s["source_hash"][:16]
            d.command(DOCKER + ["tag", s["local_" + role], remote], "tag-" + role)
            d.command(DOCKER + ["--config", d.unix(auth), "push", "--quiet", remote], "push-" + role, timeout=600)
            meta = json.loads(service.call("artifacts", "docker", "images", "describe", remote, "--format=json"))
            s["image_" + role] = remote.split(":")[0] + "@" + meta["image_summary"]["digest"]
            d.save()
    finally:
        assert auth.resolve().parent == WORK.resolve() and not auth.is_symlink()
        shutil.rmtree(auth)
    print("Both immutable patch images pushed", flush=True)


def snapshot(label):
    code = '''import json
from sqlalchemy import text
from bmt_backend.config import Settings
from bmt_backend.db import make_engine
e=make_engine(Settings.from_env().database_url)
with e.connect() as c:
 c.execute(text('SET TRANSACTION ISOLATION LEVEL REPEATABLE READ READ ONLY'))
 names=['boards','personal_bests','lap_personal_bests','runs','rivalry_groups','rivalry_members','rivalry_bests','track_versions','publication_slots']
 p=c.execute(text("SELECT status,attempts,failure_code,content_hash,replay_hash,player_id,receipt FROM publication_intents WHERE id=:id"),{'id':''' + repr(PUBLICATION) + '''}).mappings().one()
 v={'schema':c.scalar(text('SELECT version_num FROM alembic_version')),'tables':{n:c.scalar(text('SELECT count(*) FROM "'+n+'"')) for n in names},'publication':{k:p[k] for k in ['status','attempts','failure_code','content_hash','replay_hash']},'new_track_count':c.scalar(text("SELECT count(*) FROM tracks WHERE owner_id=:owner AND authoring_id='track_8c32864740d603a8011f7433e92fc72e'"),{'owner':p['player_id']}),'slots':c.scalar(text('SELECT slots FROM entitlements WHERE player_id=:owner'),{'owner':p['player_id']})}
 receipt=p['receipt'] or {}
 if receipt.get('version_id'):
  v['published_version']=receipt['version_id']
  v['publication_slot_count']=c.scalar(text('SELECT count(*) FROM publication_slots WHERE version_id=:id'),{'id':receipt['version_id']})
  v['publication_slot_source']=c.scalar(text('SELECT source FROM publication_slots WHERE version_id=:id'),{'id':receipt['version_id']})
  v['creator_proof_count']=c.scalar(text("SELECT count(*) FROM track_versions v JOIN runs r ON r.id=v.creator_test_run_id WHERE v.id=:id AND r.replay_hash=:proof AND r.status='verified'"),{'id':receipt['version_id'],'proof':p['replay_hash']})
print('RELEASE_RESULT='+json.dumps(v));e.dispose()
'''
    return d.execute(label, code, job=service.n["migrate"], timeout=180)


def backup():
    assert s.get("tests_passed") and s.get("image_main")
    for name in s["targets"]:
        d.guarded(name)
    current = service.describe("api", service.n["api"])["status"]["traffic"]
    assert current == s["original_traffic"], "Traffic/website preview changed during preparation"
    s["data_before"] = snapshot("data-before")
    description = "publication-fix-20261103-" + s["source_hash"][:12]
    service.call("sql", "backups", "create", "--instance=" + service.n["sql"], "--description=" + description, "--format=json")
    rows = json.loads(service.call("sql", "backups", "list", "--instance=" + service.n["sql"], "--format=json"))
    found = [r for r in rows if r.get("description") == description and r.get("status") == "SUCCESSFUL"]
    assert found
    s["backup_id"] = found[0]["id"]
    d.save()
    print(json.dumps({"backup": s["backup_id"], "publication": s["data_before"]["publication"]["status"]}), flush=True)


def rollout():
    assert s.get("backup_id") and s.get("tests_passed")
    sources_match()
    lock = ROOT / ".tools/gcp-staging" / ("rendered-" + d.config["owner"]) / "update.lock"
    if lock.exists():
        assert json.loads(lock.read_text())["source_hash"] == s["source_hash"]
    else:
        with lock.open("x") as stream:
            json.dump({"task": "publication-fix-20261103", "source_hash": s["source_hash"]}, stream)
    current = service.describe("api", service.n["api"])["status"]["traffic"]
    current = [r for r in current if r.get("tag") not in ("publication-new", "publication-preview")]
    if current != s["original_traffic"]:
        lock.unlink()
        raise RuntimeError("Traffic/website preview changed before rollout; refresh the inventory")
    s["rollout_started"] = True
    d.save()
    # The additive function migration changes no player/result rows. Its grants
    # are applied by the new policy before the new worker starts.
    name = service.n["migrate"]
    d.guarded(name, [s["base"], s["image_main"]])
    service.call("run", "jobs", "update", name, REGION, "--image=" + s["image_main"], "--format=json")
    code = '''import json,os
from bmt_backend.config import Settings
from bmt_backend.db import make_engine
from bmt_backend.cloud_setup import setup
from sqlalchemy import text
e=make_engine(Settings.from_env().database_url)
setup(e,os.environ['BMT_STAGING_OWNER'])
with e.connect() as c:
 v={'schema':c.scalar(text('SELECT version_num FROM alembic_version')),'worker_identity_read':c.scalar(text("SELECT has_any_column_privilege('bmt_worker','identities','SELECT')")),'worker_helper':c.scalar(text("SELECT has_function_privilege('bmt_worker','bmt_is_official_publisher(text)','EXECUTE')"))}
assert not v['worker_identity_read'] and v['worker_helper']
print('RELEASE_RESULT='+json.dumps(v));e.dispose()
'''
    result = d.execute("migration", code, job=name, timeout=180)
    assert result["schema"] == d.HEAD
    s["migration_complete"] = True
    d.save()
    # The API's retained /ready startup probe requires the new schema first.
    # Replace the worker promptly so no old child restarts with the new grants.
    name = service.n["worker"]
    d.guarded(name, [s["base"], s["image_main"]])
    service.call("run", "worker-pools", "update", name, REGION, "--image=" + s["image_main"], "--format=json")
    print("Migrated schema and replaced worker", flush=True)
    canaries = {}
    for name in (service.n["api"], service.n["admin"]):
        d.guarded(name, [s["base"], s["image_main"], s["image_preview"]])
        service.call("run", "services", "update", name, REGION, "--image=" + s["image_main"],
                     "--no-traffic", "--tag=publication-new", "--revision-suffix=pubfix-" + str(int(time.time())), "--format=json")
        value = service.describe("api", name)
        row = next(r for r in value["status"]["traffic"] if r.get("tag") == "publication-new")
        assert d.http(row["url"], "/health", private=name == service.n["admin"]).status_code == 200
        canaries[name] = {"revision": row["revisionName"], "url": row["url"]}
    service.call("run", "services", "update", service.n["api"], REGION, "--image=" + s["image_preview"],
                 "--no-traffic", "--tag=publication-preview", "--format=json")
    value = service.describe("api", service.n["api"])
    preview = next(r for r in value["status"]["traffic"] if r.get("tag") == "publication-preview")
    s["canaries"], s["preview_revision"] = canaries, preview["revisionName"]
    d.save()
    for name, row in canaries.items():
        if name == service.n["api"]:
            d.verify_api(row["url"])
            assert d.http(row["url"], "/v1/manifest").json() == s["manifest_before"]
        else:
            d.verify_admin(row["url"])
        service.call("run", "services", "update-traffic", name, REGION,
                     "--to-revisions=" + row["revision"] + "=100", "--format=json")
    for name, kind in s["targets"].items():
        if kind in ("api", "worker") or name == service.n["migrate"]:
            continue
        d.guarded(name)
        interface = "worker-pools" if kind == "worker" else "jobs"
        service.call("run", interface, "update", name, REGION, "--image=" + s["image_main"], "--format=json")
        print("Updated " + name, flush=True)
    service.call("run", "services", "update-traffic", service.n["api"], REGION,
                 "--update-tags=website-preview=" + s["preview_revision"], "--format=json")
    s["promoted"] = True
    d.save()
    print("Matching API/Studio/worker/jobs promoted; schema73 installed", flush=True)


def recover():
    assert s.get("promoted")
    # Requeue only the owner's original request after the old worker exhausted
    # its infrastructure retries; retain the immutable evidence and operation.
    code = '''import json
from sqlalchemy import select
from sqlalchemy.orm import Session
from bmt_backend.config import Settings
from bmt_backend.db import make_engine
from bmt_backend.commerce import lock_entitlements
from bmt_backend.publication_models import PublicationIntent
from bmt_backend.queueing import admit
from bmt_backend.track_models import QueueLimit
settings=Settings.from_env();e=make_engine(settings.database_url)
with Session(e) as c:
 p=c.get(PublicationIntent,''' + repr(PUBLICATION) + ''')
 lock_entitlements(c,p.player_id)
 p=c.scalar(select(PublicationIntent).where(PublicationIntent.id==p.id).with_for_update().execution_options(populate_existing=True))
 assert (p.content_hash,p.replay_hash)==''' + repr((s["data_before"]["publication"]["content_hash"], s["data_before"]["publication"]["replay_hash"])) + '''
 previous=p.status
 changed=False
 if p.status=='failed':
  assert p.failure_code=='validator_unavailable'
  admit(c,p.player_id,c.get(QueueLimit,1).capacity)
  p.status,p.attempts,p.lease_until,p.lease_token='queued',0,0,None
  p.failure_code,p.detail,p.finished_at=None,None,None
  changed=True
 c.commit()
 print('RELEASE_RESULT='+json.dumps({'previous':previous,'requeued':changed,'same_evidence':True}))
e.dispose()
'''
    s["recovery"] = d.execute("recover-original", code, job=service.n["migrate"], timeout=180)
    d.save()
    print(json.dumps(s["recovery"]), flush=True)


def verify():
    assert s.get("promoted")
    assert d.http(s["url"], "/v1/manifest").json() == s["manifest_before"]
    d.verify_api(s["url"])
    s["data_after"] = snapshot("data-after-" + str(int(time.time())))
    assert s["data_after"]["schema"] == d.HEAD
    assert s["data_after"]["publication"]["status"] == "published", s["data_after"]["publication"]["status"]
    assert s["data_after"]["new_track_count"] == 1
    assert s["data_after"]["publication_slot_count"] == s["data_after"]["creator_proof_count"] == 1
    public = d.http(s["url"], "/v1/track-versions/" + s["data_after"]["published_version"])
    assert public.status_code == 200 and public.json()["state"] == "published"
    assert s["data_after"]["publication"]["content_hash"] == s["data_before"]["publication"]["content_hash"]
    assert s["data_after"]["publication"]["replay_hash"] == s["data_before"]["publication"]["replay_hash"]
    assert s["data_after"]["slots"] >= s["data_before"]["slots"] - 1
    assert all(s["data_after"]["tables"][name] >= count for name, count in s["data_before"]["tables"].items())
    code = '''import json
from bmt_backend.app import create_app
from bmt_backend.operations import competition_health
a=create_app();v=competition_health(a)
assert v['status']=='ready' and v['available_workers']==1
print('RELEASE_RESULT='+json.dumps({'status':v['status'],'available_workers':v['available_workers'],'queue_depth':v['queue_depth']}))
a.state.verifier.close();a.state.engine.dispose()
'''
    s["worker_health"] = d.execute("worker-health", code, timeout=180)
    for name in s["targets"]:
        d.guarded(name, [s["image_main"], s["image_preview"]])
    for name in (service.n["api"], service.n["admin"]):
        tags = "publication-new,publication-preview" if name == service.n["api"] else "publication-new"
        service.call("run", "services", "update-traffic", name, REGION, "--remove-tags=" + tags, "--format=json")
    # Keep the default template on the main image, retaining preview traffic.
    service.call("run", "services", "update", service.n["api"], REGION,
                 "--image=" + s["image_main"], "--no-traffic", "--format=json")
    folder = ROOT / ".tools/gcp-staging" / ("rendered-" + d.config["owner"])
    for name in ("deployment.json", "image.json", "test-population.json"):
        path = folder / name
        if path.exists():
            old = json.loads(path.read_text())
            assert old["image"] in (s["base"], s["image_main"])
            shutil.copyfile(path, WORK / (name + ".before.private.json"))
            old["image"] = s["image_main"]
            if name in ("deployment.json", "image.json"):
                old["source_hash"], old["patch_base_image"] = s["source_hash"], s["base"]
            if name == "deployment.json":
                old["schema"] = d.HEAD
            d.write(path, old)
    lock = folder / "update.lock"
    assert json.loads(lock.read_text())["source_hash"] == s["source_hash"]
    lock.unlink()
    s["completed"] = True
    d.save()
    d.write(OUT / "acceptance.json", {"schema": d.HEAD, "image": s["image_main"], "preview": s["image_preview"],
        "manifest_unchanged": True, "backup": s["backup_id"], "publication": PUBLICATION,
        "before": s["data_before"], "after": s["data_after"], "recovery": s.get("recovery"),
        "worker_health": s["worker_health"]})
    print("Track#1 published exactly once; prior result counts retained; manifest unchanged", flush=True)


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("stage", choices=["inspect", "prepare", "build", "test", "push", "backup", "rollout", "recover", "verify"])
    globals()[parser.parse_args().stage]()
