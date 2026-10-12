"""Enable and operate explicitly isolated test drivers on retained GCP staging.

Uses the existing immutable image, a separate Secret Manager development key,
ownership checks and a completed Cloud SQL backup. Google accounts stay intact.
"""
from __future__ import annotations

import argparse
import json
import os
import secrets
import sys
from pathlib import Path

import staging


def enable(config, directory, *, apply=False):
    if config.get("retain_data") is not True:
        raise ValueError("Test population requires retained staging; deletion must be disabled")
    service = staging.Staging(config, directory)
    receipt = json.loads((directory / "deployment.json").read_text())
    for kind in ("api", "worker"):
        if staging.resource_image(service.describe(kind, service.n[kind])) != receipt["image"]:
            raise RuntimeError("Existing API and worker must match the retained image receipt")
    secret = "bmt-stg-" + config["owner"][:8] + "-test-driver-key"
    plan = {"owner": config["owner"], "image": receipt["image"], "url": receipt["url"],
            "development_only": True, "isolated_boards": True, "key_secret": secret,
            "backup_before_enable": True}
    if not apply:
        return plan
    service.call("sql", "backups", "create", "--instance=" + service.n["sql"],
                 "--description=Before isolated test-driver population", "--format=json")
    backups = json.loads(service.call("sql", "backups", "list", "--instance=" + service.n["sql"],
                                    "--filter=description:isolated", "--format=json"))
    if not any(b.get("status") == "SUCCESSFUL" for b in backups):
        raise RuntimeError("Completed prepopulation database backup required")
    service.ensure("secret", secret, "secrets", "create", secret, "--replication-policy=automatic",
                   "--labels=" + service.label_string() + ",bmt-retain-data=true")
    if service.call("secrets", "versions", "describe", "1", "--secret=" + secret,
                    "--format=json", allow_missing=True) is None:
        service.call("secrets", "versions", "add", secret, "--data-file=-",
                     input_data=secrets.token_urlsafe(48))
    service.call("secrets", "add-iam-policy-binding", secret,
                 "--member=serviceAccount:" + service.account("runtime"), "--role=roles/secretmanager.secretAccessor")
    for kind, command in (("worker", ["run", "worker-pools", "update"]), ("api", ["run", "services", "update"])):
        service.call(*command, service.n[kind], "--region=" + config["region"],
                     "--update-env-vars=BMT_ENVIRONMENT=development,BMT_DEV_AUTH_ENABLED=true,BMT_TEST_DRIVERS_ENABLED=true",
                     "--update-secrets=BMT_DEV_AUTH_KEY=" + secret + ":1", "--format=json")
    plan["backup_ids"] = [b["id"] for b in backups if b.get("status") == "SUCCESSFUL"]
    staging.write_json(directory / "test-population.json", plan)
    return plan


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=("enable", "fill", "fleet", "tick", "watch", "report"))
    parser.add_argument("--config", type=Path, default=staging.ROOT / ".tools/gcp-staging/config.json")
    parser.add_argument("--apply", action="store_true")
    parser.add_argument("--confirm-owner")
    args, population_args = parser.parse_known_args()
    config = json.loads(args.config.read_text())
    directory = args.config.parent / ("rendered-" + config["owner"])
    if args.command == "enable":
        if args.apply and args.confirm_owner != config["owner"]:
            parser.error("Apply requires the retained staging owner ID")
        result = enable(config, directory, apply=args.apply)
        if args.apply:
            config["test_drivers_enabled"] = True
            config["test_drivers_secret"] = result["key_secret"]
            staging.write_json(args.config, config)
        print(json.dumps(result, indent=2))
        return
    receipt = json.loads((directory / "test-population.json").read_text())
    service = staging.Staging(config, directory)
    if receipt["owner"] != config["owner"]:
        raise RuntimeError("Population ownership receipt differs")
    service.describe("secret", receipt["key_secret"])
    os.environ["BMT_DEV_AUTH_KEY"] = service.call("secrets", "versions", "access", "1", "--secret=" + receipt["key_secret"])
    os.environ["BMT_API_URL"] = receipt["url"]
    if args.command == "report":
        from bmt_backend.test_population_tool import API, load_plan
        report_parser = argparse.ArgumentParser()
        report_parser.add_argument("--state", type=Path, required=True)
        report_parser.add_argument("--output", type=Path)
        report_args = report_parser.parse_args(population_args)
        api = API(receipt["url"], os.environ["BMT_DEV_AUTH_KEY"])
        plan = load_plan(report_args.state, api)
        catalog = api.call("GET", "/dev/test-drivers/tracks?vehicle_id=" + plan["vehicle_id"], operator=True)
        names = {track["version_id"]: track["name"] for track in catalog["tracks"]}
        versions = sorted({job["version_id"] for job in plan["jobs"] if job["group_id"] is None})
        tracks = []
        for version in versions:
            histogram = api.call("GET", "/dev/test-drivers/track-versions/" + version +
                                 "/histogram?vehicle_id=" + plan["vehicle_id"], subject=plan["profiles"][0]["subject"])
            tracks.append({"version_id": version, "name": names.get(version, version),
                           "verified_test_pbs": histogram["population"], "target": len(plan["profiles"])})
        result = {"vehicle_id": plan["vehicle_id"], "test_population": True,
                  "complete": bool(tracks) and all(t["verified_test_pbs"] >= t["target"] for t in tracks),
                  "tracks": tracks,
                  "jobs": {status: sum(j["status"] == status for j in plan["jobs"])
                           for status in sorted({j["status"] for j in plan["jobs"]})}}
        if report_args.output:
            staging.write_json(report_args.output, result)
        print(json.dumps(result, indent=2))
        os.environ.pop("BMT_DEV_AUTH_KEY", None)
        return
    from bmt_backend.test_population_tool import main as population_main
    sys.argv = [sys.argv[0], args.command, *population_args]
    try:
        population_main()
    finally:
        os.environ.pop("BMT_DEV_AUTH_KEY", None)


if __name__ == "__main__":
    main()
