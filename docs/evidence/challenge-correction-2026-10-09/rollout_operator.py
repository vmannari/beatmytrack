"""Narrow challenge overlay for the existing owned development backend."""
import hashlib
import importlib.util
import json
import os
import shutil
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PRIVATE = ROOT / ".tools/gcp-staging"
EVIDENCE = ROOT / "docs/evidence/challenge-correction-2026-10-09"
CONTEXT = ROOT / ".tools/challenge-image-20261009"
os.environ["CLOUDSDK_CORE_CUSTOM_CA_CERTS_FILE"] = str(PRIVATE / "windows-trust.pem")
os.environ["REQUESTS_CA_BUNDLE"] = str(PRIVATE / "windows-trust.pem")
spec = importlib.util.spec_from_file_location("challenge_stage", ROOT / "backend/deploy/gcp/staging.py")
stage = importlib.util.module_from_spec(spec)
spec.loader.exec_module(stage)
config = json.loads((PRIVATE / "config.json").read_text())
assert config["retain_data"] and config["project"] == "beat-my-track"
DIRECTORY = PRIVATE / ("rendered-" + config["owner"])
service = stage.Staging(config, DIRECTORY)
RECEIPT = EVIDENCE / "development-rollout.json"
receipt = json.loads(RECEIPT.read_text()) if RECEIPT.exists() else {}


def save():
    RECEIPT.write_text(json.dumps(receipt, indent=2)+"\n", encoding="utf-8")


def environment(resource):
    node = resource
    for _ in range(8):
        if "containers" in node:
            return {item["name"]: item for item in node["containers"][0].get("env", [])}
        node = node.get("template") or node.get("spec")
    raise RuntimeError("Missing runtime environment")


def guard(allow_updated=False):
    for kind, key in (("api", "api"), ("worker", "worker"), ("job", "migrate"), ("job", "smoke")):
        resource = service.describe(kind, service.n[key])
        expected = receipt["image"] if allow_updated and receipt.get(key+"_updated") else receipt["parent"]
        assert stage.resource_image(resource) == expected, "Live image changed; stop this rollout"
        if kind in ("api", "worker"):
            env = environment(resource)
            assert env["BMT_ENVIRONMENT"]["value"] == "development"
            assert env["BMT_DEV_AUTH_ENABLED"]["value"] == "true"
    assert service.describe("sql", service.n["sql"])["settings"]["deletionProtectionEnabled"]


def builder():
    settings = dict(config)
    settings["docker"] = list(settings["docker"])
    if "--cd" in settings["docker"]:
        settings["docker"][settings["docker"].index("--cd")+1] = "/mnt/"+CONTEXT.drive[0].lower()+CONTEXT.as_posix()[2:]
    class Runner(stage.Runner):
        def run(self, argv, *, input_data=None, allow_missing=False, cwd=None):
            result = subprocess.run(argv, input=input_data, capture_output=True, text=True, cwd=cwd, check=False)
            if result.returncode:
                (CONTEXT / "last-error.private.log").write_text(result.stdout+result.stderr, encoding="utf-8")
                raise RuntimeError("Overlay command failed; private diagnostics retained")
            return result.stdout.strip()
    return stage.Staging(settings, DIRECTORY, Runner())


PATCH = '''import hashlib,json,shutil
from pathlib import Path
def hashes(folder):
 return {str(p.relative_to(folder)):hashlib.sha256(p.read_bytes()).hexdigest() for p in folder.rglob('*') if p.is_file() and '__pycache__' not in p.parts and '.godot' not in p.parts}
game=Path('/opt/bmt'); backend=Path('/app/bmt_backend'); source=Path('/tmp/challenge-source')
original=hashes(game)
assert not (backend/'migrations/versions/0020_challenges.py').exists()
assert (backend/'migrations/versions/0019_discovery_snapshots.py').exists()
for path in source.rglob('*'):
 if path.is_file():
  target=backend/path.relative_to(source);target.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(path,target)
p=backend/'app.py';s=p.read_text();assert 'challenges.router' not in s
needle='    from .verifier import GodotVerifier\\n';assert s.count(needle)==1
s=s.replace(needle,needle+'    from . import challenges\\n')
needle='    app.include_router(rivalry.router, prefix="/v1")\\n';assert s.count(needle)==1
s=s.replace(needle,needle+'    app.include_router(challenges.router, prefix="/v1")\\n    app.include_router(challenges.preview_router)\\n');p.write_text(s)
p=backend/'migrations/env.py';s=p.read_text();needle='    rivalry_models,\\n';assert s.count(needle)==1
s=s.replace(needle,'    challenge_models,\\n'+needle);p.write_text(s)
p=backend/'config.py';s=p.read_text();needle='    public_base_url: str = "http://localhost:8080"\\n';assert s.count(needle)==1
s=s.replace(needle,needle+'    android_app_link_package: str = "org.circuit01.handlinglab"\\n    android_app_link_certificates: tuple[str, ...] = field(default_factory=tuple)\\n')
needle='if name == "google_client_ids":';assert s.count(needle)==1
s=s.replace(needle,'if name in ("google_client_ids", "android_app_link_certificates"):');p.write_text(s)
p=backend/'worker.py';s=p.read_text()
needle='        needs_ghost = not creator_test and session.get(RivalryTicket, run.ticket_id) is not None\\n';assert s.count(needle)==1
s=s.replace(needle,'        needs_ghost = not creator_test and (not session.get(Player, run.player_id).is_test_driver or session.get(RivalryTicket, run.ticket_id) is not None)\\n')
needle='            accept_verified(session, run)\\n';assert s.count(needle)==1
s=s.replace(needle,needle+'            from .challenges import accept_verified as accept_challenge\\n            accept_challenge(session, run)\\n');p.write_text(s)
p=backend/'maintenance.py';s=p.read_text();needle='from .config import Settings\\n';assert s.count(needle)==1
s=s.replace(needle,needle+'from .challenge_models import Challenge, ChallengeMember, ChallengeTicket\\n')
needle='            ~Run.id.in_(select(RivalryBest.run_id)),\\n';assert s.count(needle)==1
s=s.replace(needle,needle+'            ~Run.id.in_(select(Challenge.target_run_id).where(Challenge.target_run_id.is_not(None))),\\n            ~Run.id.in_(select(ChallengeMember.run_id).where(ChallengeMember.run_id.is_not(None))),\\n')
needle='            ~RunTicket.id.in_(select(RivalryTicket.ticket_id)),\\n';assert s.count(needle)==1
s=s.replace(needle,needle+'            ~RunTicket.id.in_(select(ChallengeTicket.ticket_id)),\\n');p.write_text(s)
for name in ('app.py','config.py','worker.py','maintenance.py','challenges.py','challenge_models.py','migrations/env.py','migrations/versions/0020_challenges.py'):compile((backend/name).read_text(),name,'exec')
import sys;sys.path.insert(0,'/app')
import bmt_backend.app,bmt_backend.challenges
from bmt_backend.migrate import SCHEMA_HEAD
assert SCHEMA_HEAD=='0020_challenges'
assert original==hashes(game)
Path('/app/challenge-overlay-proof.json').write_text(json.dumps({'canonical_unchanged':True,'canonical_files':len(original),'game_hashes':original,'schema_head':SCHEMA_HEAD}))
print('CHALLENGE_OVERLAY_VALID')
'''


def job_code(code, timeout=300):
    node = service.describe("job",service.n["smoke"])
    for _ in range(8):
        if "containers" in node:
            assert node["containers"][0].get("command") == ["python"], "Expected existing Python smoke command"
            break
        node = node.get("template") or node.get("spec")
    else:
        raise RuntimeError("Smoke command could not be verified")
    argv = stage.command(config,"run", "jobs", "execute", service.n["smoke"], "--region="+config["region"],
        "--wait", "--task-timeout="+str(timeout)+"s", "--args=^|^-c|"+code)
    result = subprocess.run(argv,capture_output=True,text=True,check=False)
    if result.returncode:
        (EVIDENCE / "preflight-job-error.log").write_text(result.stdout+result.stderr,encoding="utf-8")
        raise RuntimeError("Read-only preflight job failed; diagnostic retained")
    return result.stdout


action = sys.argv[1]
if action == "prepare":
    old = json.loads((DIRECTORY / "deployment.json").read_text())
    receipt.update(parent=old["image"], owner=config["owner"], url=old["url"], started_utc=datetime.now(timezone.utc).isoformat())
    guard()
    import requests
    response = requests.get(receipt["url"]+"/openapi.json", timeout=20)
    response.raise_for_status()
    receipt["challenge_endpoint_present_before"] = "/v1/challenges" in response.json()["paths"]
    assert not receipt["challenge_endpoint_present_before"], "Challenge API already deployed; review its version first"
    CONTEXT.mkdir(exist_ok=False)
    files = ("challenges.py", "challenge_models.py", "migrations/versions/0020_challenges.py")
    for name in files:
        target = CONTEXT / "source" / name
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(ROOT / "backend/bmt_backend" / name, target)
    (CONTEXT / "patch.py").write_text(PATCH, encoding="utf-8")
    (CONTEXT / "Dockerfile").write_text("FROM "+receipt["parent"]+"\nUSER root\nCOPY source /tmp/challenge-source\nCOPY patch.py /tmp/challenge-patch.py\nRUN python /tmp/challenge-patch.py\nUSER 10001:10001\n", encoding="utf-8")
    receipt["source_hash"] = hashlib.sha256(b"".join(p.read_bytes() for p in sorted(CONTEXT.rglob("*")) if p.is_file())).hexdigest()
    save()
    print(json.dumps({"prepared": True, "development_only": True, "challenge_endpoint_present": False, "schema_change": "0019 to additive 0020", "game_changed": False}))
elif action == "build":
    guard()
    build = builder()
    registry = config["region"]+"-docker.pkg.dev"
    tag = registry+"/"+config["project"]+"/"+service.n["repo"]+"/backend:challenges-"+receipt["source_hash"][:24]
    auth = CONTEXT / "docker-private"
    auth.mkdir(exist_ok=False)
    try:
        token = service.call("auth", "print-access-token")
        build.runner.run([*build.c["docker"], "--config=docker-private", "login", registry, "--username=oauth2accesstoken", "--password-stdin"], input_data=token, cwd=CONTEXT)
        output = build.runner.run([*build.c["docker"], "--config=docker-private", "build", "--platform=linux/amd64", "--file=Dockerfile", "--tag="+tag, "."], cwd=CONTEXT)
        (CONTEXT / "build.private.log").write_text(output, encoding="utf-8")
        proof = json.loads(build.runner.run([*build.c["docker"], "run", "--rm", "--entrypoint=cat", tag, "/app/challenge-overlay-proof.json"], cwd=CONTEXT))
        assert proof["canonical_unchanged"]
        (EVIDENCE / "packaged-game-proof.json").write_text(json.dumps(proof, indent=2)+"\n", encoding="utf-8")
        build.runner.run([*build.c["docker"], "--config=docker-private", "push", tag], cwd=CONTEXT)
        images = json.loads(build.runner.run([*build.c["docker"], "image", "inspect", tag, "--format={{json .RepoDigests}}"], cwd=CONTEXT))
        receipt["image"] = next(value for value in images if value.startswith(registry+"/"))
        save()
    finally:
        assert auth.resolve().parent == CONTEXT.resolve() and CONTEXT.resolve().is_relative_to(ROOT.resolve())
        assert not auth.is_symlink() and all(not path.is_symlink() for path in auth.rglob("*"))
        shutil.rmtree(auth)
    print(json.dumps({"built": True, "canonical_unchanged": True, "image": receipt["image"]}))
elif action == "backup":
    guard()
    assert receipt.get("image")
    description = "Before challenge API update "+datetime.now(timezone.utc).isoformat()
    service.call("sql", "backups", "create", "--instance="+service.n["sql"], "--description="+description, "--format=json")
    backups = json.loads(service.call("sql", "backups", "list", "--instance="+service.n["sql"], "--format=json"))
    matches = [value for value in backups if value.get("description") == description and value.get("status") == "SUCCESSFUL"]
    assert matches
    receipt["backup_id"] = matches[0]["id"]
    save()
    print(json.dumps({"successful_backup": receipt["backup_id"]}))
elif action == "deploy":
    guard(allow_updated=True)
    assert receipt.get("backup_id") and receipt.get("image")
    if not receipt.get("migration_complete"):
        job_code("from bmt_backend.app import create_app;from bmt_backend.operations import competition_health; a=create_app();h=competition_health(a);assert h['queue_depth']==0; a.state.engine.dispose();a.state.verifier.close()")
        service.call("run", "jobs", "update", service.n["migrate"], "--region="+config["region"], "--image="+receipt["image"], "--format=json")
        receipt["migrate_updated"] = True
        save()
        service.call("run", "jobs", "execute", service.n["migrate"], "--region="+config["region"], "--wait")
        receipt["migration_complete"] = True
        save()
    for key, command in (("worker", "worker-pools"), ("api", "services")):
        if receipt.get(key+"_updated"):
            continue
        service.call("run", command, "update", service.n[key], "--region="+config["region"], "--image="+receipt["image"], "--format=json")
        receipt[key+"_updated"] = True
        save()
        print("Updated development "+key, flush=True)
    if not receipt.get("smoke_updated"):
        service.call("run", "jobs", "update", service.n["smoke"], "--region="+config["region"], "--image="+receipt["image"], "--format=json")
        receipt["smoke_updated"] = True
        save()
    catalog = "bmt-stg-"+config["owner"][:8]+"-catalog"
    data = service.describe("job", catalog)
    if data and not receipt.get("catalog_updated"):
        assert stage.resource_image(data) == receipt["parent"]
        service.call("run", "jobs", "update", catalog, "--region="+config["region"], "--image="+receipt["image"], "--format=json")
        receipt["catalog_updated"] = True
        save()
    old = json.loads((DIRECTORY / "deployment.json").read_text())
    assert old["image"] == receipt["parent"]
    stage.write_json(DIRECTORY / ("deployment-before-challenges-"+str(receipt["backup_id"])+".json"), old)
    stage.write_json(DIRECTORY / "deployment.json", {**old, "image": receipt["image"]})
    population = DIRECTORY / "test-population.json"
    if population.exists():
        stage.write_json(population, {**json.loads(population.read_text()), "image": receipt["image"]})
    receipt["deployed"] = True
    save()
    print("Development challenge API deployed; player records retained")
elif action == "smoke":
    assert receipt.get("deployed")
    guard(allow_updated=True)
    service.call("run", "jobs", "execute", service.n["smoke"], "--region="+config["region"], "--wait")
    import requests
    paths = requests.get(receipt["url"]+"/openapi.json", timeout=20).json()["paths"]
    assert "/v1/challenges" in paths
    job_code("from bmt_backend.app import create_app;from bmt_backend.migrate import SCHEMA_HEAD;from bmt_backend.operations import competition_health; a=create_app();assert SCHEMA_HEAD=='0020_challenges';h=competition_health(a);assert h['status']=='ready' and h['available_workers']>=1;a.state.engine.dispose();a.state.verifier.close()")
    receipt["native_smoke_passed"] = True
    save()
    print("Challenge endpoint, native replay/storage/schema and worker readiness passed")
else:
    raise RuntimeError("Unknown action")
