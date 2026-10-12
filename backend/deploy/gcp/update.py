"""Review/update the owned retained staging backend, without recreating resources."""
import argparse
import hashlib
import json
import os
import re
from datetime import datetime, timezone, timedelta
from pathlib import Path

import staging

ROOT = staging.ROOT


def require(condition, message):
    if not condition:
        raise RuntimeError(message)


def load_config(path):
    config = json.loads(path.read_text(encoding="utf-8-sig"))
    # A retained environment has no disposable lease; retain structural checks.
    staging.validate(config, now=staging.stamp(config["expires_at"]) - timedelta(seconds=1))
    require(config.get("retain_data") is True and not config.get("example"),
            "This updater requires a real retained staging configuration")
    return config


def source_hash():
    digest = hashlib.sha256()
    for directory in (ROOT / "backend", ROOT / "game"):
        for path in sorted(directory.rglob("*")):
            if path.is_file() and not any(part in (".godot", "__pycache__", "build", "vendor") for part in path.parts):
                digest.update(path.relative_to(ROOT).as_posix().encode())
                digest.update(path.read_bytes())
    digest.update((ROOT / "godot-version.txt").read_bytes())
    return digest.hexdigest()


class Updater:
    def __init__(self, config, directory, runner=None):
        self.config = config
        self.directory = directory
        self.service = staging.Staging(config, directory, runner)
        self.receipt = {}

    def save(self):
        staging.write_json(self.directory / "update-receipt.json", self.receipt)

    def job_code(self, code, timeout=900):
        self.service.call("run", "jobs", "execute", self.service.n["smoke"],
                          "--region=" + self.config["region"], "--wait",
                          "--task-timeout=" + str(timeout) + "s", "--args=^|^-c|" + code)

    def check_source(self):
        require(source_hash() == self.receipt["source_hash"],
                "Source changed during deployment; stop and review the partial rollout receipt")

    def run(self):
        s = self.service
        s.preflight()
        old = json.loads((self.directory / "deployment.json").read_text())
        self.receipt = {"started_utc": datetime.now(timezone.utc).isoformat(),
                        "owner": self.config["owner"], "old_image": old["image"],
                        "source_hash": source_hash(), "completed": False}
        # All targets must exist and pass the existing remote ownership checks.
        for kind, name in (("api", s.n["api"]), ("worker", s.n["worker"]),
                           ("job", s.n["migrate"]), ("job", s.n["smoke"]), ("sql", s.n["sql"]),
                           ("bucket", s.n["bucket"]), ("repo", s.n["repo"])):
            resource = s.describe(kind, name)
            require(resource is not None, "Missing owned resource: " + name)
            if kind in ("api", "worker", "job"):
                require(staging.resource_image(resource) == old["image"],
                        "Existing image mismatch; reconcile the partial rollout before retrying: " + name)
            if kind == "sql":
                require(resource.get("settings", {}).get("deletionProtectionEnabled") is True,
                        "Retained SQL deletion protection must be enabled")
        catalog = "bmt-stg-" + self.config["owner"][:8] + "-catalog"
        catalog_exists = s.describe("job", catalog) is not None
        self.save()
        print("Building and pushing the pinned backend image", flush=True)
        self.receipt["image"] = s.build()
        self.check_source()
        self.save()
        print("Creating a fresh database backup", flush=True)
        description = "Before backend update " + self.receipt["started_utc"]
        s.call("sql", "backups", "create", "--instance=" + s.n["sql"],
               "--description=" + description, "--format=json")
        backups = json.loads(s.call("sql", "backups", "list", "--instance=" + s.n["sql"], "--format=json"))
        matches = [item for item in backups if item.get("description") == description and item.get("status") == "SUCCESSFUL"]
        require(bool(matches), "Fresh successful backup required before migration")
        self.receipt["backup_id"] = matches[0]["id"]
        self.save()
        print("Checking that the old verification queue is drained", flush=True)
        self.job_code("from bmt_backend.app import create_app;from bmt_backend.operations import competition_health;"
                      "a=create_app();h=competition_health(a);assert h['queue_depth']==0,h['queue_depth'];"
                      "a.state.engine.dispose();a.state.verifier.close()")
        self.check_source()
        image = self.receipt["image"]
        print("Migrating the backed-up database", flush=True)
        s.call("run", "jobs", "update", s.n["migrate"], "--region=" + self.config["region"], "--image=" + image)
        s.call("run", "jobs", "execute", s.n["migrate"], "--region=" + self.config["region"], "--wait")
        self.receipt["migration_complete"] = True
        self.save()
        for kind, command in (("worker", "worker-pools"), ("api", "services")):
            self.check_source()
            print("Updating " + kind, flush=True)
            s.call("run", command, "update", s.n[kind], "--region=" + self.config["region"], "--image=" + image)
            self.receipt[kind + "_updated"] = True
            self.save()
        for job in ([s.n["smoke"], catalog] if catalog_exists else [s.n["smoke"]]):
            s.call("run", "jobs", "update", job, "--region=" + self.config["region"], "--image=" + image)
        # Keep the original deployment receipt until smoke and catalog acceptance finish.
        print("Checking native replay, storage and schema", flush=True)
        s.call("run", "jobs", "execute", s.n["smoke"], "--region=" + self.config["region"], "--wait")
        compiler = re.search(r'const VERSION: String = "([^"]+)"',
                             (ROOT / "game/editor/track_compiler.gd").read_text()).group(1)
        self.job_code("from bmt_backend.app import create_app;from bmt_backend.operations import competition_health;"
                      "a=create_app();h=competition_health(a);assert h['status']=='ready' and h['available_workers']>=1;"
                      "assert h['expected_build']['compiler_version']==" + repr(compiler) + ";"
                      "a.state.engine.dispose();a.state.verifier.close()")
        print("Validating and adding immutable official-track revisions", flush=True)
        for apply in (False, True):
            self.job_code(catalog_code(apply))
        self.check_source()
        staging.write_json(self.directory / ("deployment-before-update-" + str(matches[0]["id"]) + ".json"), old)
        staging.write_json(self.directory / "deployment.json", {**old, "image": image})
        population = self.directory / "test-population.json"
        if population.exists():
            value = json.loads(population.read_text())
            staging.write_json(population, {**value, "image": image})
        s.smoke()
        self.receipt["completed"] = True
        self.save()
        print("Backend updated: " + old["url"], flush=True)


def catalog_code(apply):
    program = (ROOT / "backend/deploy/gcp/catalog_transfer.py").read_text(encoding="utf-8")
    return """import time
from sqlalchemy import select
from bmt_backend.config import Settings
from bmt_backend.db import make_engine,make_session_factory
from bmt_backend.identity_models import Player
from bmt_backend.track_models import Track,TrackVersion
from bmt_backend.storage import make_blob_store
from bmt_backend.verifier import GodotVerifier
scope={'__name__':'retained_catalog_update'}
exec(__PROGRAM__,scope)
settings=Settings.from_env();engine=make_engine(settings.database_url,settings);factory=make_session_factory(engine);store=make_blob_store(settings,factory);verifier=GodotVerifier(settings)
try:
 with factory() as db:
  tracks=db.scalars(select(Track).where(Track.official.is_(True),Track.hidden.is_(False),Track.archived.is_(False))).all()
  versions=db.scalars(select(TrackVersion).where(TrackVersion.track_id.in_([x.id for x in tracks]),TrackVersion.state=='published')).all()
  owners=db.scalars(select(Player).where(Player.id.in_([x.owner_id for x in tracks]))).all()
  def fields(row,names):return {key:getattr(row,key) for key in names}
  payload={'format':'bmt-catalog-transfer-v1','source_origin':'retained-staging-update','transfer_created_at':int(time.time()),'owners':[fields(x,['id','display_name','created_at']) for x in owners],'tracks':[fields(x,scope['TRACK_FIELDS']) for x in tracks],'versions':[fields(x,scope['VERSION_FIELDS']) for x in versions]}
 payload['objects']={x['content_hash']:store.get_json(x['content_hash']) for x in payload['versions']}
 scope['import_catalog'](payload,factory,store,verifier,confirm_source='retained-staging-update',apply=__APPLY__)
finally:verifier.close();engine.dispose()
""".replace("__PROGRAM__", repr(program)).replace("__APPLY__", str(apply))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--config", type=Path, default=ROOT / ".tools/gcp-staging/config.json")
    parser.add_argument("--apply", action="store_true")
    args = parser.parse_args()
    config = load_config(args.config)
    directory = args.config.resolve().parent / ("rendered-" + config["owner"])
    if not args.apply:
        print(json.dumps({"project": config["project"], "region": config["region"],
                          "resources": staging.names(config), "mode": "retained staging update",
                          "steps": ["ownership/preflight", "build/push", "fresh backup", "empty queue",
                                    "migration", "worker/API/jobs", "native/worker acceptance",
                                    "immutable catalog revisions", "HTTP smoke"],
                          "apply": "scripts/deploy-backend.ps1 -Apply"}, indent=2))
        return
    # Use the existing local CA bundle only when configured by the operator.
    trust = args.config.resolve().parent / "windows-trust.pem"
    if trust.exists():
        os.environ.setdefault("CLOUDSDK_CORE_CUSTOM_CA_CERTS_FILE", str(trust))
        os.environ.setdefault("REQUESTS_CA_BUNDLE", str(trust))
    require(directory.is_dir(), "Existing retained deployment receipts are missing")
    lock = directory / "update.lock"
    with lock.open("x") as handle:
        handle.write(str(os.getpid()))
    try:
        Updater(config, directory).run()
    finally:
        lock.unlink()


if __name__ == "__main__":
    main()
