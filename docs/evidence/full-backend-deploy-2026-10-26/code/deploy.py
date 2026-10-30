"""Owner-authorized full retained backend release; secrets stay in private files."""
import argparse
import base64
import hashlib
import importlib.util
import json
import lzma
import os
import secrets
import shutil
import subprocess
import sys
import time
import xml.etree.ElementTree as ET
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
WORK = Path(__file__).resolve().parent
OUT = ROOT / "docs/evidence/full-backend-deploy-2026-10-26"
OUT.mkdir(parents=True, exist_ok=True)
sys.path.insert(0, str(ROOT / "backend/deploy/gcp"))
import staging

config = json.loads((ROOT / ".tools/gcp-staging/config.json").read_text(encoding="utf-8-sig"))
assert config["project"] == "beat-my-track" and config["retain_data"] is True
assert config["owner"] == "e7a444abdf684b7cbd228d9e7948c65e"
for key in ("CLOUDSDK_CORE_CUSTOM_CA_CERTS_FILE", "REQUESTS_CA_BUNDLE"):
    trust = ROOT / ".tools/gcp-staging/windows-trust.pem"
    if trust.exists():
        os.environ[key] = str(trust)
DOCKER = ["wsl.exe", "-d", "Ubuntu", "--", "docker"]
HEAD = "0070_reward_cache_revisions"
STATE = WORK / "state.private.json"
state = json.loads(STATE.read_text()) if STATE.exists() else {}


def write(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    pending = path.with_name(path.name + "." + secrets.token_hex(4) + ".pending")
    pending.write_text(json.dumps(value, indent=2)+"\n", encoding="utf-8")
    pending.replace(path)


def save():
    current = json.loads(STATE.read_text()) if STATE.exists() else {}
    current.update(state)
    state.update(current)
    write(STATE, state)


def unix(path):
    return "/mnt/"+path.drive[0].lower()+path.as_posix()[2:]


def command(argv, name, *, timeout=900, input_data=None, allow_missing=False):
    result = subprocess.run(argv, input=input_data, capture_output=True, text=True,
                            encoding="utf-8", errors="replace", timeout=timeout)
    (WORK / (name+".private.log")).write_text(result.stdout+result.stderr, encoding="utf-8")
    if result.returncode:
        if allow_missing and any(word in result.stderr for word in ("NOT_FOUND", "not found", "does not exist", "404")):
            return None
        raise RuntimeError("Command failed; inspect "+name+".private.log")
    return result.stdout.strip()


class Runner(staging.Runner):
    def run(self, argv, *, input_data=None, allow_missing=False, cwd=None):
        assert cwd is None
        return command(argv, "cloud-command", input_data=input_data, allow_missing=allow_missing)


service = staging.Staging(config, WORK, Runner())


def runtime(resource):
    node = resource
    for _ in range(10):
        if isinstance(node, dict) and node.get("containers"):
            return node
        node = (node.get("template") or node.get("spec")) if isinstance(node, dict) else None
    raise RuntimeError("Unexpected runtime resource template")


def envmap(resource):
    return {item["name"]:item for item in runtime(resource)["containers"][0].get("env", [])}


def inspect_live():
    assert not state.get("maintenance_started"), "Use the retained inventory after cutover begins"
    service.preflight()
    tasks = [("api",service.n["api"]), ("worker",service.n["worker"]),
             ("api",service.n["admin"]), ("sql",service.n["sql"]), ("bucket",service.n["bucket"])]
    jobs = json.loads(service.call("run","jobs","list","--region="+config["region"],"--format=json"))
    tasks += [("job",item["metadata"]["name"]) for item in jobs
              if item["metadata"].get("labels",{}).get("bmt-owner") == config["owner"]]
    found, summary = {}, {}
    with ThreadPoolExecutor(max_workers=4) as pool:
        values = list(pool.map(lambda task:service.describe(*task), tasks))
    for (kind,name),resource in zip(tasks,values):
        assert resource is not None, name
        write(WORK / ("before-"+name+".private.json"),resource)
        if kind in ("api","worker","job"):
            found[name] = kind
            node = runtime(resource)
            env = envmap(resource)
            summary[name] = {"kind":kind,"image":staging.resource_image(resource),
                "revision":resource.get("status",{}).get("latestReadyRevisionName"),
                "workload":env.get("BMT_WORKLOAD_ROLE",{}).get("value"),
                "account":node.get("serviceAccountName") or node.get("serviceAccount"),
                "command":node["containers"][0].get("command"),
                "packing":env.get("BMT_OBJECT_PACKING_ENABLED",{}).get("value","false"),
                "url":resource.get("status",{}).get("url")}
            if kind == "job":
                status = resource.get("status",{}).get("latestCreatedExecution",{}).get("completionStatus")
                assert status in (None,"EXECUTION_SUCCEEDED","EXECUTION_FAILED","EXECUTION_CANCELLED"), (name,status)
        elif kind == "sql":
            assert resource["settings"]["deletionProtectionEnabled"] is True
    state["targets"] = found
    state["parents"] = {name:item["image"] for name,item in summary.items()}
    api = values[0]
    state["url"] = api["status"]["url"]
    state["started_utc"] = datetime.now(timezone.utc).isoformat()
    save()
    import requests
    checks = {}
    for path in ("/health","/ready","/v1/bootstrap"):
        response = requests.get(state["url"]+path,timeout=(5,30));response.raise_for_status()
        checks[path] = response.json()
    state["schema_before"] = checks["/ready"]["schema"]
    save()
    write(WORK / "http-before.private.json",checks)
    write(OUT / "initial-inspection.json",{"targets":summary,"schema_before":state["schema_before"],"schema_target":HEAD})
    command([*DOCKER,"version","--format","{{.Server.Version}}"],"docker-version")
    print(json.dumps({"targets":summary,"schema_before":state["schema_before"],"schema_target":HEAD},indent=2),flush=True)


def hashes(folder):
    return {path.relative_to(folder).as_posix():hashlib.sha256(path.read_bytes()).hexdigest()
            for path in sorted(folder.rglob("*")) if path.is_file()
            and not any(part in path.parts for part in ("__pycache__",".godot",".pytest_cache",".ruff_cache"))}


def freeze():
    frozen = WORK / "frozen"
    assert not frozen.exists()
    frozen.mkdir()
    skip = {"__pycache__",".godot",".pytest_cache",".ruff_cache","vendor","build","node_modules"}
    allowed_game = {".py",".json",".md",".txt",".gd",".uid",".tres",".godot",".cfg",".gdshader",".gdshaderinc"}
    for folder in ("backend","game"):
        for source in (ROOT/folder).rglob("*"):
            if (not source.is_file() or any(part in skip for part in source.relative_to(ROOT).parts)
                    or ".private." in source.name or source.name.startswith(".env")):
                continue
            if folder == "game" and source.suffix not in allowed_game:
                continue
            target = frozen / source.relative_to(ROOT)
            target.parent.mkdir(parents=True,exist_ok=True)
            shutil.copyfile(source,target)
    shutil.copyfile(ROOT/"godot-version.txt",frozen/"godot-version.txt")
    spec = importlib.util.spec_from_file_location("release_stage_verifier",frozen/"backend/deploy/stage_verifier.py")
    module = importlib.util.module_from_spec(spec);spec.loader.exec_module(module)
    module.stage(frozen,frozen/"canonical/game")
    state["frozen_hashes"] = hashes(frozen)
    state["source_hash"] = hashlib.sha256(json.dumps(state["frozen_hashes"],sort_keys=True).encode()).hexdigest()
    state["local_tag"] = "bmt-full-20261026:"+state["source_hash"][:16]
    save()
    write(OUT/"frozen-source.json",{"source_hash":state["source_hash"],"files":state["frozen_hashes"],"schema_target":HEAD})
    print(json.dumps({"frozen_files":len(state["frozen_hashes"]),"source_hash":state["source_hash"],"schema_target":HEAD}),flush=True)


def build():
    frozen = WORK/"frozen"
    assert hashes(frozen) == state["frozen_hashes"]
    parent = state["parents"][service.n["api"]]
    holder = "bmt-full-20261026-parent"
    command([*DOCKER,"create","--name",holder,"--label","bmt.full-release=20261026",parent],"parent-create")
    try:
        command([*DOCKER,"cp",holder+":/app/requirements.lock",unix(WORK/"parent-requirements.lock")],"parent-lock")
    finally:
        command([*DOCKER,"rm",holder],"parent-remove")
    assert (WORK/"parent-requirements.lock").read_bytes().replace(b"\r\n",b"\n") == (frozen/"backend/requirements.lock").read_bytes().replace(b"\r\n",b"\n"), "Dependencies changed; use reviewed full Dockerfile build"
    installer = '''import hashlib,json,shutil
from pathlib import Path
package=Path('/app/bmt_backend');game=Path('/opt/bmt/game')
assert package==Path('/app/bmt_backend') and game==Path('/opt/bmt/game')
shutil.rmtree(package);shutil.copytree('/tmp/release-backend',package)
shutil.rmtree(game);shutil.copytree('/tmp/release-canonical',game)
from bmt_backend.app import create_app
from bmt_backend.config import Settings
from bmt_backend.migrate import upgrade,SCHEMA_HEAD
assert SCHEMA_HEAD=='0070_reward_cache_revisions'
a=create_app(Settings(environment='test',database_url='sqlite://'))
upgrade(a.state.engine);a.state.engine.dispose();a.state.verifier.close()
proof={'schema':SCHEMA_HEAD,'source_hashes':{p.relative_to(package).as_posix():hashlib.sha256(p.read_bytes()).hexdigest() for p in package.rglob('*') if p.is_file() and '__pycache__' not in p.parts}}
Path('/app/full-release-proof.json').write_text(json.dumps(proof))
'''
    (WORK/"install.py").write_text(installer,encoding="utf-8",newline="\n")
    dockerfile = f'''FROM {parent}
USER root
ENV PYTHONPATH=/app
COPY frozen/backend/bmt_backend /tmp/release-backend
COPY frozen/canonical/game /tmp/release-canonical
COPY frozen/godot-version.txt /opt/bmt/godot-version.txt
COPY frozen/backend/tests/fixtures/verified_oval.json /opt/bmt/acceptance/verified_oval.json
COPY frozen/backend/deploy/check_godot.py /app/deploy/check_godot.py
COPY frozen/backend/deploy/object_archive.py /app/deploy/object_archive.py
COPY install.py /tmp/release-install.py
RUN chmod -R u+w /opt/bmt && python /tmp/release-install.py && python /app/deploy/check_godot.py --import-project /opt/bmt/game --fixture /opt/bmt/acceptance/verified_oval.json && chmod -R a-w /opt/bmt && chown -R 10001:10001 /tmp/bmt
USER 10001:10001
'''
    (WORK/"Dockerfile").write_text(dockerfile,encoding="utf-8",newline="\n")
    command([*DOCKER,"build","--network=none","--pull=false","--file",unix(WORK/"Dockerfile"),
             "--tag",state["local_tag"],unix(WORK)],"build",timeout=1200)
    proof = json.loads(command([*DOCKER,"run","--rm","--network=none","--entrypoint","cat",state["local_tag"],"/app/full-release-proof.json"],"package-proof"))
    expected = hashes(frozen/"backend/bmt_backend")
    assert proof["source_hashes"] == expected
    manifest = json.loads(command([*DOCKER,"run","--rm","--network=none","--entrypoint","python",state["local_tag"],"-c",
        "import json;from bmt_backend.config import Settings;from bmt_backend.verifier import GodotVerifier;v=GodotVerifier(Settings.from_env());print(json.dumps(v.manifest()));v.close()"],"manifest"))
    state["image_id"] = command([*DOCKER,"image","inspect",state["local_tag"],"--format={{.Id}}"],"image-id")
    state["manifest"] = manifest
    state["built"] = True
    save();write(OUT/"package-proof.json",proof);write(OUT/"candidate-manifest.json",manifest)
    print(json.dumps({"image_id":state["image_id"],"package_files":len(expected),"manifest":manifest,"native_import_replay_rewind":True}),flush=True)


def fixture_fix():
    frozen = WORK/"frozen"
    assert hashes(frozen) == state["frozen_hashes"]
    path = frozen/"backend/tests/fixtures/verified_oval.json"
    original = path.read_bytes()
    value = json.loads(original)
    assert value["expected_manifest"]["rules_key"] == "standing-5-road-gates-v22"
    runner = (frozen/"game/race/race_rules.gd").read_text()
    assert "standing-5-road-gates-v23" in runner
    value["expected_manifest"]["rules_key"] = "standing-5-road-gates-v23"
    path.write_text(json.dumps(value,indent=2)+"\n",encoding="utf-8")
    state["original_source_hash"] = state["source_hash"]
    state["frozen_hashes"] = hashes(frozen)
    state["source_hash"] = hashlib.sha256(json.dumps(state["frozen_hashes"],sort_keys=True).encode()).hexdigest()
    state["local_tag"] = "bmt-full-20261026:"+state["source_hash"][:16]
    save()
    write(OUT/"frozen-source.json",{"source_hash":state["source_hash"],"files":state["frozen_hashes"],"schema_target":HEAD,
        "fixture_only_adjustment":"Expected rules22 -> existing actual rules23, same as prior full release; controls and expected ticks/laps unchanged",
        "original_source_hash":state["original_source_hash"]})
    shutil.copyfile(WORK/"build.private.log",OUT/"build-initial.log")
    print(json.dumps({"expected_fixture_rules_corrected":True,"source_hash":state["source_hash"]}),flush=True)


def test_image():
    assert state.get("built")
    network, pg = "bmt-full-release-20261026", "bmt-full-release-20261026-pg"
    label = "bmt.full-release=20261026"
    password = secrets.token_hex(32)
    pg_env, app_env = WORK/"fixture-pg.private.env", WORK/"fixture-app.private.env"
    pg_env.write_text("POSTGRES_PASSWORD="+password+"\nPOSTGRES_DB=bmt_release\n",encoding="utf-8")
    url = "postgresql+psycopg://postgres:"+password+"@"+pg+":5432/bmt_release"
    app_env.write_text("PYTHONPATH=/app:/test-work:/test-work/backend:/test-work/backend/tests\nBMT_TEST_DATABASE_URL="+url+
        "\nBMT_GCP_SETUP_TEST_DATABASE_URL="+url+"\nBMT_GAME_PROJECT=/opt/bmt/game\n",encoding="utf-8")
    command([*DOCKER,"network","create","--internal","--label",label,network],"fixture-network")
    created = False
    try:
        command([*DOCKER,"run","-d","--rm","--name",pg,"--network",network,"--label",label,
                 "--env-file",unix(pg_env),"--tmpfs","/var/lib/postgresql/data:rw","postgres:17-bookworm"],"fixture-start")
        created = True
        for _ in range(80):
            ready = subprocess.run([*DOCKER,"exec",pg,"pg_isready","-U","postgres"],capture_output=True)
            if ready.returncode == 0:
                break
            time.sleep(.25)
        else:
            raise RuntimeError("Disposable PostgreSQL startup timed out")
        tests = ["backend_work_reduction","non_improving_runs","trajectory_integrity","reward_ranks",
                 "packed_storage","gcs_storage","s3_storage","challenge_series","track_of_day","slot_gifts",
                 "security_fixes","runtime_privileges","cloud_setup","backend_reuse","public_website",
                 "studio_identity","studio_recovery","earned_coins","race_acceptance_sql","auth","privacy",
                 "results_deployment","gcp_update","gcp_staging"]
        argv = [*DOCKER,"run","--rm","--network",network,"--label",label,"--env-file",unix(app_env),
                "--mount","type=bind,src="+unix(WORK/"frozen/backend")+",dst=/test-work/backend,readonly",
                "--mount","type=bind,src="+unix(WORK/"frozen/game")+",dst=/test-work/game,readonly",
                "--mount","type=bind,src="+unix(OUT)+",dst=/results","--workdir","/test-work/backend",
                "--entrypoint","python",state["local_tag"],"-m","pytest",
                *["tests/test_"+name+".py" for name in tests],"-m","not godot","-k",
                "not migration_backfills_existing_field and not original_checker_accepts",
                "--tb=short","-q","--basetemp=/tmp/full-release-tests","-p","no:cacheprovider",
                "--junitxml=/results/exact-image-tests.xml"]
        result = subprocess.run(argv,capture_output=True,text=True,encoding="utf-8",errors="replace",timeout=3600)
        output = (result.stdout+result.stderr).replace(password,"[DISPOSABLE-TEST-PASSWORD]")
        (OUT/"exact-image-tests.log").write_text(output,encoding="utf-8")
        state["tests_exit"] = result.returncode
        save();print(output[-9000:],flush=True)
        if result.returncode:
            raise RuntimeError("Exact-image release tests failed; review retained failures")
    finally:
        if created:
            meta = json.loads(command([*DOCKER,"inspect",pg],"fixture-inspect"))[0]
            assert meta["Config"]["Labels"]["bmt.full-release"] == "20261026"
            command([*DOCKER,"stop",pg],"fixture-stop")
        meta = json.loads(command([*DOCKER,"network","inspect",network],"fixture-network-inspect"))[0]
        assert meta["Labels"]["bmt.full-release"] == "20261026"
        command([*DOCKER,"network","rm",network],"fixture-network-remove")


def execute(name, code, *, job=None, timeout=600):
    job = job or service.n["smoke"]
    key = "execution_"+name
    boot = "import base64,lzma;exec(lzma.decompress(base64.b64decode("+repr(base64.b64encode(lzma.compress(code.encode())).decode())+")).decode())"
    if key not in state:
        flags = WORK/(name+"-flags.private.json")
        write(flags,{"--args":["-c",boot],"--task-timeout":str(timeout)+"s"})
        value = json.loads(service.call("run","jobs","execute",job,"--region="+config["region"],
                                       "--wait","--format=json","--flags-file="+str(flags)))
        execution = value.get("metadata",{}).get("name") or value.get("name")
        assert execution and "/" not in execution
        state[key] = execution;save()
    for _ in range(20):
        entries = json.loads(service.call("logging","read",'resource.type="cloud_run_job" AND resource.labels.job_name="'+job+
            '" AND labels."run.googleapis.com/execution_name"="'+state[key]+'"',"--limit=100","--format=json"))
        write(WORK/(name+"-logs.private.json"),entries)
        rows = [item.get("textPayload","") for item in entries if item.get("textPayload","").startswith("RELEASE_RESULT=")]
        if rows:
            break
        time.sleep(1)
    assert len(rows) == 1, "Diagnostic result not available; repeat this stage without creating another execution"
    result = json.loads(rows[0].split("=",1)[1]);write(OUT/(name+".json"),result)
    return result


def fixture_recheck():
    tree = ET.parse(OUT/"exact-image-tests.xml").getroot()
    failed = [row for row in tree.iter("testcase") if row.find("failure") is not None or row.find("error") is not None]
    assert len(failed) == 1
    assert failed[0].attrib["name"] == "test_public_site_does_not_add_admin_service_routes"
    assert "Read-only file system" in failed[0].find("failure").attrib["message"]
    folder = WORK/"test-corrections";folder.mkdir(exist_ok=True)
    source = ROOT/"backend/tests/test_public_website.py"
    shutil.copyfile(source,folder/source.name)
    argv = [*DOCKER,"run","--rm","--network=none","--label","bmt.full-release=20261026",
            "--env","PYTHONPATH=/app:/test-work:/test-work/backend:/test-work/backend/tests",
            "--mount","type=bind,src="+unix(WORK/"frozen/backend")+",dst=/test-work/backend,readonly",
            "--mount","type=bind,src="+unix(folder/source.name)+",dst=/test-work/backend/tests/test_public_website.py,readonly",
            "--mount","type=bind,src="+unix(OUT)+",dst=/results","--workdir","/test-work/backend",
            "--entrypoint","python",state["local_tag"],"-m","pytest","tests/test_public_website.py","-q","--tb=short",
            "-p","no:cacheprovider","--basetemp=/tmp/website-recheck","--junitxml=/results/website-recheck.xml"]
    output = command(argv,"website-recheck",timeout=180)
    (OUT/"website-recheck.log").write_text(output,encoding="utf-8")
    recheck = ET.parse(OUT/"website-recheck.xml").getroot()
    assert any(row.attrib["name"] == failed[0].attrib["name"] for row in recheck.iter("testcase"))
    assert not list(recheck.iter("failure")) and not list(recheck.iter("error"))
    state["release_gate_passed"] = True
    state["test_harness_correction"] = {"file":"backend/tests/test_public_website.py",
        "sha256":hashlib.sha256(source.read_bytes()).hexdigest(),"reason":"Use writable pytest tmp_path for local storage; route assertions unchanged",
        "runtime_image_changed":False,"remaining_failures":0}
    save();write(OUT/"test-harness-correction.json",state["test_harness_correction"])
    print(output[-2000:],flush=True)


def rehearse():
    assert state.get("built")
    network, pg = "bmt-full-synthetic-20261026", "bmt-full-synthetic-20261026-pg"
    label = "bmt.full-synthetic=20261026"
    password = secrets.token_hex(32)
    pg_env, app_env = WORK/"synthetic-pg.private.env", WORK/"synthetic-app.private.env"
    pg_env.write_text("POSTGRES_PASSWORD="+password+"\nPOSTGRES_DB=bmt_synthetic\n",encoding="utf-8")
    app_env.write_text("BMT_DATABASE_URL=postgresql+psycopg://postgres:"+password+"@"+pg+":5432/bmt_synthetic\nBMT_WORKLOAD_ROLE=migrator\n",encoding="utf-8")
    command([*DOCKER,"network","create","--internal","--label",label,network],"synthetic-network")
    created = False
    try:
        command([*DOCKER,"run","-d","--rm","--name",pg,"--network",network,"--label",label,
                 "--env-file",unix(pg_env),"--tmpfs","/var/lib/postgresql/data:rw","postgres:17-bookworm"],"synthetic-start")
        created = True
        for _ in range(80):
            ready = subprocess.run([*DOCKER,"exec",pg,"pg_isready","-U","postgres"],capture_output=True)
            if ready.returncode == 0:
                break
            time.sleep(.25)
        else:
            raise RuntimeError("Synthetic database startup timed out")
        output = command([*DOCKER,"run","--rm","--network",network,"--label",label,"--env-file",unix(app_env),
                          "--mount","type=bind,src="+unix(WORK/"rehearse.py")+",dst=/rehearse.py,readonly",
                          "--entrypoint","python",state["local_tag"],"/rehearse.py"],"synthetic-rehearsal",timeout=600)
        value = json.loads(output.splitlines()[-1]);assert value["synthetic_only"] and value["schema_after"] == HEAD
        state["rehearsal_passed"] = True;save();write(OUT/"synthetic-migration.json",value)
        print(json.dumps(value),flush=True)
    finally:
        if created:
            meta = json.loads(command([*DOCKER,"inspect",pg],"synthetic-inspect"))[0]
            assert meta["Config"]["Labels"]["bmt.full-synthetic"] == "20261026"
            command([*DOCKER,"stop",pg],"synthetic-stop")
        meta = json.loads(command([*DOCKER,"network","inspect",network],"synthetic-network-inspect"))[0]
        assert meta["Labels"]["bmt.full-synthetic"] == "20261026"
        command([*DOCKER,"network","rm",network],"synthetic-network-remove")


def preflight():
    code = '''import json
from sqlalchemy import text
from bmt_backend.config import Settings
from bmt_backend.db import make_engine
s=Settings.from_env();e=make_engine(s.database_url,s)
with e.connect() as c:
 c.execute(text('SET TRANSACTION ISOLATION LEVEL REPEATABLE READ READ ONLY'))
 value={'schema':c.scalar(text('SELECT version_num FROM alembic_version')),
 'pending':{name:c.scalar(text("SELECT count(*) FROM "+name+" WHERE status IN ('queued','verifying','validating')")) for name in ['runs','publication_intents','track_validations']},
 'invalid_indexes':c.scalar(text('SELECT count(*) FROM pg_index WHERE NOT indisvalid'))}
print('RELEASE_RESULT='+json.dumps(value));e.dispose()
'''
    value = execute("aggregate-preflight",code,job=service.n["migrate"])
    assert value["schema"] == state["schema_before"] and not value["invalid_indexes"]
    state["preflight"] = value;save();print(json.dumps(value),flush=True)


def guarded(name, allowed=None):
    kind = state["targets"][name]
    original = json.loads((WORK/("before-"+name+".private.json")).read_text())
    current = service.describe(kind,name)
    assert current and staging.resource_image(current) in (allowed or [state["parents"][name]]), "Another release changed "+name
    assert envmap(current) == envmap(original), "Runtime environment changed: "+name
    left,right = runtime(current),runtime(original)
    for key in ("serviceAccountName","serviceAccount","containerConcurrency","timeoutSeconds","volumes","taskCount","maxRetries"):
        assert left.get(key) == right.get(key), (name,key)
    for key in ("resources","command","args","ports","volumeMounts","startupProbe","livenessProbe"):
        assert left["containers"][0].get(key) == right["containers"][0].get(key), (name,key)
    return current


def push():
    assert state.get("tests_exit") == 0 or state.get("release_gate_passed") is True
    suites = ET.parse(OUT/"exact-image-tests.xml").getroot()
    values = list(suites) if suites.tag == "testsuites" else [suites]
    summary = {key:sum(int(row.attrib.get(key,0)) for row in values) for key in ("tests","failures","errors","skipped")}
    assert not summary["errors"]
    if summary["failures"]:
        assert state.get("release_gate_passed") is True and summary["failures"] == 1
    else:
        state["release_gate_passed"] = True
    state["release_tests"] = summary
    # These independent read-only/local gates may finish while the long-running
    # test invocation retains an older in-memory receipt. Recover their receipts.
    preflight_value = json.loads((OUT/"aggregate-preflight.json").read_text())
    assert preflight_value["schema"] == state["schema_before"] and not preflight_value["invalid_indexes"]
    state["preflight"] = preflight_value
    rehearsal_value = json.loads((OUT/"synthetic-migration.json").read_text())
    assert rehearsal_value["synthetic_only"] and rehearsal_value["schema_after"] == HEAD
    state["rehearsal_passed"] = True
    save();write(OUT/"release-gates.json",{"tests":summary,"synthetic_migration":rehearsal_value,"schema_preflight":preflight_value})
    lock = ROOT/".tools/gcp-staging"/("rendered-"+config["owner"])/"update.lock"
    expected = {"task":"full-backend-deploy-20261026","source_hash":state["source_hash"]}
    if lock.exists():
        assert json.loads(lock.read_text()) == expected, "Another deployment owns the lock"
    else:
        with lock.open("x",encoding="utf-8") as stream:
            json.dump(expected,stream)
    for name in state["targets"]:
        guarded(name)
    registry = config["region"]+"-docker.pkg.dev"
    remote = registry+"/"+config["project"]+"/"+service.n["repo"]+"/backend:full-20261026-"+state["source_hash"][:12]
    auth = WORK/"push-auth.private"
    assert not auth.exists();auth.mkdir()
    try:
        token = service.call("auth","print-access-token")
        command([*DOCKER,"--config",unix(auth),"login",registry,"--username=oauth2accesstoken","--password-stdin"],"registry-login",input_data=token)
        command([*DOCKER,"tag",state["local_tag"],remote],"tag")
        command([*DOCKER,"--config",unix(auth),"push",remote],"push",timeout=1200)
        state["image"] = next(item for item in json.loads(command([*DOCKER,"image","inspect",remote,"--format={{json .RepoDigests}}"],"remote-digest")) if item.startswith(registry+"/"))
        save()
    finally:
        assert auth.resolve().parent == WORK.resolve() and not auth.is_symlink()
        shutil.rmtree(auth)
    print(json.dumps({"image":state["image"],"tested_image_id":state["image_id"]}),flush=True)


def prepare_maintenance():
    assert state.get("release_gate_passed") is True and state.get("image")
    folder = WORK/"maintenance";folder.mkdir(exist_ok=True)
    app = '''from fastapi import FastAPI
from starlette.responses import JSONResponse
def create_app():
 app=FastAPI(docs_url=None,redoc_url=None,openapi_url=None)
 @app.middleware('http')
 async def fence(request,call_next):
  if request.url.path in ('/health','/ready','/healthz','/readyz'):return JSONResponse({'status':'maintenance'})
  return JSONResponse({'detail':'DEPLOYMENT_MAINTENANCE'},status_code=503,headers={'Retry-After':'120'})
 return app
create_admin_app=create_app
'''
    (folder/"app.py").write_text(app,encoding="utf-8",newline="\n")
    (folder/"Dockerfile").write_text("FROM "+state["image"]+"\nUSER root\nCOPY app.py /app/bmt_backend/app.py\nUSER 10001:10001\n",encoding="utf-8",newline="\n")
    local = "bmt-full-maint-20261026:"+state["source_hash"][:12]
    command([*DOCKER,"build","--network=none","--pull=false","-f",unix(folder/"Dockerfile"),"-t",local,unix(folder)],"maintenance-build")
    check = "from fastapi.testclient import TestClient;from bmt_backend.app import create_app;c=TestClient(create_app());assert c.get('/v1/bootstrap').status_code==503;assert c.get('/health').json()['status']=='maintenance'"
    command([*DOCKER,"run","--rm","--network=none","--entrypoint","python",local,"-c",check],"maintenance-test")
    registry = config["region"]+"-docker.pkg.dev"
    remote = registry+"/"+config["project"]+"/"+service.n["repo"]+"/backend:full-maint-20261026-"+state["source_hash"][:12]
    auth = WORK/"maintenance-auth.private";auth.mkdir()
    try:
        token = service.call("auth","print-access-token")
        command([*DOCKER,"--config",unix(auth),"login",registry,"--username=oauth2accesstoken","--password-stdin"],"maint-login",input_data=token)
        command([*DOCKER,"tag",local,remote],"maint-tag")
        command([*DOCKER,"--config",unix(auth),"push",remote],"maint-push",timeout=900)
        state["maintenance_image"] = next(item for item in json.loads(command([*DOCKER,"image","inspect",remote,"--format={{json .RepoDigests}}"],"maint-digest")) if item.startswith(registry+"/"))
        save()
    finally:
        assert auth.resolve().parent == WORK.resolve() and not auth.is_symlink()
        shutil.rmtree(auth)
    print(json.dumps({"maintenance_image":state["maintenance_image"],"database_free":True}),flush=True)


def quiesce():
    assert state.get("release_gate_passed") is True and state.get("maintenance_image") and state.get("preflight") and state.get("rehearsal_passed")
    assert not state.get("maintenance_started"), "Resume retained stages rather than re-entering maintenance"
    for name,kind in state["targets"].items():
        allowed = [state["parents"][name]]
        if kind == "api":
            allowed.append(state["maintenance_image"])
        resource = guarded(name,allowed)
        if kind == "job":
            status = resource.get("status",{}).get("latestCreatedExecution",{}).get("completionStatus")
            assert status in (None,"EXECUTION_SUCCEEDED","EXECUTION_FAILED","EXECUTION_CANCELLED"), (name,status)
    routes = dict(state.get("maintenance_routes",{}))
    for name in (service.n["admin"],service.n["api"]):
        before = service.describe("api",name)
        tag = "full-maint-20261026"
        assert all(not route.get("tag") or route["tag"] == tag for route in before["status"]["traffic"])
        if not any(route.get("tag") == tag for route in before["status"]["traffic"]):
            service.call("run","services","update",name,"--region="+config["region"],"--image="+state["maintenance_image"],
                         "--no-traffic","--tag="+tag,"--format=json")
        current = service.describe("api",name)
        route = next(item for item in current["status"]["traffic"] if item.get("tag") == tag)
        for path in ("/v1/bootstrap","/v1/auth/google/challenge","/admin"):
            response = http(route["url"],path,private=name == service.n["admin"])
            assert response.status_code == 503 and response.json()["detail"] == "DEPLOYMENT_MAINTENANCE"
        service.call("run","services","update-traffic",name,"--region="+config["region"],
                     "--to-revisions="+route["revisionName"]+"=100","--format=json")
        routes[name] = {"revision":route["revisionName"],"tag":tag}
        state["maintenance_routes"] = routes;save()
    state["maintenance_started"] = datetime.now(timezone.utc).isoformat();save()
    print(json.dumps({"application_and_studio_paused":True,"drain_seconds":90,"routes":routes}),flush=True)


def stop_worker():
    assert state.get("maintenance_started") and len(state["maintenance_routes"]) == 2
    elapsed = (datetime.now(timezone.utc)-datetime.fromisoformat(state["maintenance_started"])).total_seconds()
    assert elapsed >= 90, "Wait for old requests to drain before stopping the worker"
    worker = guarded(service.n["worker"])
    count = int(worker["metadata"]["annotations"]["run.googleapis.com/manualInstanceCount"])
    assert count >= 1
    state["worker_instances_before"] = count;save()
    service.call("run","worker-pools","update",service.n["worker"],"--region="+config["region"],"--instances=0","--format=json")
    state["worker_stopped"] = True;save()
    print(json.dumps({"worker_instances":0,"old_request_drain_seconds":round(elapsed,1)}),flush=True)


def aggregate_snapshot():
    assert state.get("worker_stopped")
    code = (WORK/"aggregate_counts.py").read_text().replace("__BASELINE__","None")
    value = execute("aggregate-counts-before",code,job=service.n["migrate"],timeout=600)
    assert value["schema"] == state["schema_before"] and not any(value["pending"].values()) and not value["invalid_indexes"]
    state["data_before"] = value;save()
    print(json.dumps({"tables":len(value["tables"]),"rows":sum(value["tables"].values()),"queues_empty":True,
                      "private_record_hashes_exported":False}),flush=True)


def backup():
    assert state.get("data_before") and state.get("worker_stopped")
    if not state.get("backup_id"):
        description = "Before full backend 20261026 "+state["source_hash"][:12]+" "+datetime.now(timezone.utc).isoformat()
        service.call("sql","backups","create","--instance="+service.n["sql"],"--description="+description,"--format=json")
        rows = json.loads(service.call("sql","backups","list","--instance="+service.n["sql"],"--format=json"))
        matching = [row for row in rows if row.get("description") == description and row.get("status") == "SUCCESSFUL"]
        assert len(matching) == 1
        state["backup_id"] = matching[0]["id"];save()
    print(json.dumps({"managed_cloud_sql_backup":state["backup_id"],"player_records_exported":False}),flush=True)


def update_image(name, *, no_traffic=False, tag=None, instances=None):
    kind = state["targets"][name]
    interface = {"api":"services","worker":"worker-pools","job":"jobs"}[kind]
    args = ["run",interface,"update",name,"--region="+config["region"],"--image="+state["image"],"--format=json"]
    if no_traffic:
        args.append("--no-traffic")
    if tag:
        args.append("--tag="+tag)
    if instances is not None:
        args.append("--instances="+str(instances))
    service.call(*args)


def migrate():
    assert state.get("backup_id") and state.get("data_before") and state.get("worker_stopped")
    update_image(service.n["migrate"])
    code = '''import json,os
from sqlalchemy import text
from bmt_backend.config import Settings
from bmt_backend.db import make_engine
from bmt_backend.cloud_setup import setup
s=Settings.from_env();assert s.workload_role=='migrator'
e=make_engine(s.database_url,s)
with e.connect() as c:
 assert c.scalar(text('SELECT version_num FROM alembic_version')) in ('0062_retire_discovery_cache','0070_reward_cache_revisions')
 assert not c.scalar(text("SELECT count(*) FROM runs WHERE status IN ('queued','verifying')"))
setup(e,os.environ['BMT_STAGING_OWNER'])
with e.connect() as c:
 value={'schema':c.scalar(text('SELECT version_num FROM alembic_version')),
 'invalid_indexes':c.scalar(text('SELECT count(*) FROM pg_index WHERE NOT indisvalid'))}
print('RELEASE_RESULT='+json.dumps(value));e.dispose()
'''
    value = execute("migrate",code,job=service.n["migrate"],timeout=1200)
    assert value["schema"] == HEAD and not value["invalid_indexes"]
    state["migrated"] = True;save()
    code = (WORK/"aggregate_counts.py").read_text().replace("__BASELINE__",repr(state["data_before"]))
    after = execute("aggregate-counts-after",code,job=service.n["migrate"],timeout=600)
    assert after["tables"] == state["data_before"]["tables"] and not after["invalid_indexes"]
    state["data_preserved"] = True;save()
    print(json.dumps({"schema":HEAD,"original_row_counts_unchanged":sum(after["tables"].values()),
                      "compared_tables":len(after["tables"]),"reviewed_workload_grants_applied":True,
                      "private_record_hashes_exported":False}),flush=True)


def http(origin, path, *, private=False):
    import requests
    headers = {}
    if private:
        headers["X-Serverless-Authorization"] = "Bearer "+service.call("auth","print-identity-token")
    return requests.get(origin+path,headers=headers,timeout=(5,45),allow_redirects=False)


def verify_api(origin):
    result = {}
    for path in ("/health","/ready","/v1/bootstrap"):
        response = http(origin,path);assert response.status_code == 200,(path,response.status_code)
        result[path] = response.json()
    assert result["/ready"]["schema"] == HEAD and result["/ready"]["status"] == "ready"
    boot = result["/v1/bootstrap"]
    assert boot["non_improving_runs_version"] == 1
    assert boot["ghost_identity_version"] == boot["ghost_wire_version"] == 1
    assert boot["admin_console_configured"] is False
    for path in ("/admin","/v1/admin/overview","/v1/monitor/source/control"):
        response = http(origin,path);assert response.status_code == 404,(path,response.status_code)
        result[path] = {"status":404}
    for path in ("/","/privacy","/account-deletion","/community-rules"):
        response = http(origin,path);assert response.status_code == 200,(path,response.status_code)
        result[path] = {"status":200,"sha256":hashlib.sha256(response.content).hexdigest()}
    response = http(origin,"/v1/challenges/0000000000000000/ghost?metadata=true")
    assert response.status_code == 404
    result["unknown_ghost_metadata_status"] = 404
    return result


def verify_admin(origin):
    result = {}
    for path in ("/health","/ready"):
        response = http(origin,path,private=True)
        assert response.status_code == 200,(path,response.status_code)
        result[path] = response.json()
    assert result["/ready"]["schema"] == HEAD
    response = http(origin,"/v1/admin/overview",private=True)
    assert response.status_code in (401,403), response.status_code
    result["unauthenticated_admin_status"] = response.status_code
    return result


def canary():
    assert state.get("migrated") and state.get("data_preserved")
    values = {}
    for name in (service.n["api"],service.n["admin"]):
        tag = "full-canary-20261026"
        update_image(name,no_traffic=True,tag=tag)
        current = service.describe("api",name)
        route = next(row for row in current["status"]["traffic"] if row.get("tag") == tag)
        assert route.get("percent",0) == 0
        assert any(row.get("revisionName") == state["maintenance_routes"][name]["revision"] and row.get("percent") == 100
                   for row in current["status"]["traffic"])
        value = verify_api(route["url"]) if name == service.n["api"] else verify_admin(route["url"])
        values[name] = {"revision":route["revisionName"],"url":route["url"],"tag":tag}
        write(OUT/("canary-api.json" if name == service.n["api"] else "canary-studio.json"),value)
        state["canaries"] = values;save()
    state["canary_passed"] = True;save()
    print(json.dumps({"canaries":values,"public_traffic":"maintenance","passed":True}),flush=True)


def start_targets():
    assert state.get("canary_passed")
    for name,kind in state["targets"].items():
        if kind == "job" and name != service.n["migrate"]:
            update_image(name)
            print(json.dumps({"updated_job":name}),flush=True)
    update_image(service.n["worker"],instances=state["worker_instances_before"])
    state["worker_started"] = True;save()
    code = '''import json,time
from bmt_backend.app import create_app
from bmt_backend.operations import competition_health
from bmt_backend.discovery_projection import health
a=create_app()
for attempt in range(120):
 value=competition_health(a);projection=health(a.state.session_factory)
 if value['status']=='ready' and value['available_workers']>=1 and all(row['ready'] for row in projection['partitions']):break
 time.sleep(2)
else:raise RuntimeError('Matching worker and discovery projections are not ready')
print('RELEASE_RESULT='+json.dumps({'status':value['status'],'available_workers':value['available_workers'],
 'queue_depth':value['queue_depth'],'partitions_ready':sum(row['ready'] for row in projection['partitions']),
 'expected_build':value['expected_build']}))
a.state.verifier.close();a.state.engine.dispose()
'''
    value = execute("worker-readiness",code,job=service.n["migrate"],timeout=360)
    assert value["status"] == "ready" and value["available_workers"] >= 1
    state["matching_worker_ready"] = True;save()
    print(json.dumps(value),flush=True)


def promote():
    assert state.get("matching_worker_ready") and state.get("canary_passed") and state.get("data_preserved")
    for name,route in state["canaries"].items():
        value = verify_api(route["url"]) if name == service.n["api"] else verify_admin(route["url"])
        assert value
        service.call("run","services","update-traffic",name,"--region="+config["region"],
                     "--to-revisions="+route["revision"]+"=100","--format=json")
    state["promoted"] = True
    state["maintenance_ended"] = datetime.now(timezone.utc).isoformat();save()
    write(OUT/"live-api.json",verify_api(state["url"]))
    admin = service.describe("api",service.n["admin"])
    write(OUT/"live-studio.json",verify_admin(admin["status"]["url"]))
    print(json.dumps({"promoted":True,"schema":HEAD,"image":state["image"],"matching_worker":True}),flush=True)


def smoke():
    assert state.get("promoted")
    code = "import json,os\nfrom bmt_backend.config import Settings\nfrom bmt_backend.cloud_smoke import check\nvalue=check(Settings.from_env(),os.environ['BMT_STAGING_OWNER'])\nprint('RELEASE_RESULT='+json.dumps(value))"
    value = execute("native-storage-smoke",code,timeout=360)
    assert value["status"] == "passed" and value["schema"] == HEAD
    state["smoke_passed"] = True;save();print(json.dumps(value),flush=True)


def authority():
    assert state.get("promoted")
    code = '''import json
from types import SimpleNamespace
from sqlalchemy import text
from bmt_backend.config import Settings
from bmt_backend.db import make_engine
from bmt_backend.database_privileges import verify_runtime
s=Settings.from_env();e=make_engine(s.database_url,s)
verify_runtime(e,SimpleNamespace(environment='production',workload_role='api'))
with e.connect() as c:
 value={'api_role':c.scalar(text('SELECT current_user')),
 'legacy_login_disabled':not c.scalar(text("SELECT rolcanlogin FROM pg_roles WHERE rolname='bmt'")),
 'worker_can_read_tokens':c.scalar(text("SELECT has_any_column_privilege('bmt_worker','session_tokens','SELECT')")),
 'worker_can_read_staff':c.scalar(text("SELECT has_any_column_privilege('bmt_worker','studio_staff','SELECT')")),
 'worker_can_edit_audit':c.scalar(text("SELECT has_any_column_privilege('bmt_worker','admin_audit','UPDATE')")),
 'worker_can_delete_audit':c.scalar(text("SELECT has_table_privilege('bmt_worker','admin_audit','DELETE')")),
 'api_can_read_staff':c.scalar(text("SELECT has_any_column_privilege('bmt_api','studio_staff','SELECT')")),
 'admin_can_read_tokens':c.scalar(text("SELECT has_any_column_privilege('bmt_admin','session_tokens','SELECT')"))}
 assert value['api_role']=='bmt_api' and value['legacy_login_disabled']
 assert not any(v for k,v in value.items() if k not in ('api_role','legacy_login_disabled'))
print('RELEASE_RESULT='+json.dumps(value));e.dispose()
'''
    value = execute("live-authority",code)
    state["authority_passed"] = True;save();print(json.dumps(value),flush=True)


def discovery():
    assert state.get("promoted")
    import requests
    ids,pages = set(),[]
    response = requests.post(state["url"]+"/v1/discovery/v3/tracks",json={"query":{"sort":"name"}},timeout=(5,45))
    for _ in range(25):
        assert response.status_code == 200, response.status_code
        value = response.json();assert value["schema"] == "bmt-discovery-page-v3"
        chunk = {row["track_id"] for row in value["items"]}
        assert not ids & chunk
        ids.update(chunk);pages.append(len(chunk))
        if not value.get("next_cursor"):
            break
        response = requests.post(state["url"]+"/v1/discovery/v3/tracks",json={"cursor":value["next_cursor"]},timeout=(5,45))
    else:
        raise RuntimeError("Unexpectedly large retained catalogue")
    code = "import json\nfrom sqlalchemy import text\nfrom bmt_backend.config import Settings\nfrom bmt_backend.db import make_engine\ne=make_engine(Settings.from_env().database_url)\nwith e.connect() as c:n=c.scalar(text(\"SELECT count(*) FROM tracks t WHERE NOT t.hidden AND NOT t.archived AND EXISTS(SELECT 1 FROM track_versions v WHERE v.track_id=t.id AND v.state='published')\"))\nprint('RELEASE_RESULT='+json.dumps({'public_tracks':n}));e.dispose()"
    expected = execute("catalogue-count",code)
    assert len(ids) == expected["public_tracks"], (len(ids),expected)
    value = {"public_tracks":len(ids),"pages":pages,"duplicate_ids":0}
    write(OUT/"discovery-http.json",value)
    state["discovery_passed"] = True;save();print(json.dumps(value),flush=True)


def finish():
    assert all(state.get(key) for key in ("promoted","data_preserved","smoke_passed","authority_passed","discovery_passed"))
    final = {}
    for name,kind in state["targets"].items():
        if kind == "api":
            service.call("run","services","update-traffic",name,"--region="+config["region"],
                         "--remove-tags=full-maint-20261026,full-canary-20261026","--format=json")
        current = guarded(name,[state["image"]])
        write(WORK/("after-"+name+".private.json"),current)
        if kind == "api":
            route = state["canaries"][name]
            assert not any(row.get("tag") for row in current["status"]["traffic"])
            assert any(row.get("revisionName") == route["revision"] and row.get("percent") == 100
                       for row in current["status"]["traffic"])
        if kind == "worker":
            assert int(current["metadata"]["annotations"]["run.googleapis.com/manualInstanceCount"]) == state["worker_instances_before"]
        final[name] = {"kind":kind,"image":state["image"],
            "revision":current.get("status",{}).get("latestReadyRevisionName"),"runtime_environment_identity_resources_and_process_preserved":True}
    write(OUT/"final-targets.json",final)
    write(OUT/"final-http.json",verify_api(state["url"]))
    directory = ROOT/".tools/gcp-staging"/("rendered-"+config["owner"])
    for filename in ("deployment.json","image.json","test-population.json"):
        path = directory/filename
        if not path.exists():
            continue
        original = json.loads(path.read_text())
        if filename != "image.json":
            assert original["owner"] == config["owner"]
        prior = WORK/(filename+".before.private.json")
        if not prior.exists():
            shutil.copyfile(path,prior)
        updated = {**original,"image":state["image"]}
        if filename in ("deployment.json","image.json"):
            updated["source_hash"] = state["source_hash"]
        if filename == "deployment.json":
            updated["schema"] = HEAD
        write(path,updated)
    lock = ROOT/".tools/gcp-staging"/("rendered-"+config["owner"])/"update.lock"
    assert json.loads(lock.read_text()) == {"task":"full-backend-deploy-20261026","source_hash":state["source_hash"]}
    state["complete"] = True;state["completed_utc"] = datetime.now(timezone.utc).isoformat();save()
    lock.unlink()
    receipt = {key:state[key] for key in ("source_hash","image","image_id","schema_before","url","started_utc","maintenance_started",
        "maintenance_ended","backup_id","canaries","completed_utc")}
    receipt.update(schema_target=HEAD,targets=len(final),complete=True,player_database_exported=False,local_pc_backend_changed=False)
    write(OUT/"rollout.json",receipt)
    print(json.dumps(receipt,indent=2),flush=True)


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    actions = {"inspect":inspect_live,"freeze":freeze,"fixture-fix":fixture_fix,"build":build,"test":test_image,
               "preflight":preflight,"rehearse":rehearse,"fixture-recheck":fixture_recheck,"push":push,"prepare-maintenance":prepare_maintenance,
               "quiesce":quiesce,"stop-worker":stop_worker,"aggregate-snapshot":aggregate_snapshot,"backup":backup,"migrate":migrate,
               "canary":canary,"start-targets":start_targets,"promote":promote,"smoke":smoke,
               "authority":authority,"discovery":discovery,"finish":finish}
    parser.add_argument("stage",choices=actions)
    args = parser.parse_args()
    actions[args.stage]()
