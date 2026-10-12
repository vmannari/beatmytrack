"""Cloud staging plans/ownership/credentials/order, without creating billed resources."""
import importlib.util
import json
from copy import deepcopy
from datetime import timedelta
from pathlib import Path
from types import SimpleNamespace

import pytest

path = Path(__file__).parents[1] / "deploy/gcp/staging.py"
spec = importlib.util.spec_from_file_location("bmt_gcp_staging_tests", path)
staging = importlib.util.module_from_spec(spec)
spec.loader.exec_module(staging)


def config():
    return {"format": "bmt-gcp-staging-v1", "project": "bmt-staging-fixture", "region": "europe-west1",
        "owner": "a" * 32, "disposable": True, "example": False,
        "expires_at": (staging.utc() + timedelta(hours=4)).isoformat(), "budget_eur": 40,
        "cost_reviewed": True, "estimated_hourly_eur": 0.5, "pricing_checked_at": staging.utc().isoformat(),
        "api_max": 2, "worker_instances": 1, "public_api": False, "google_client_ids": [], "google_web_client_id": "",
        "godot_sha256": staging.PIN, "gcloud": ["fixture-gcloud"], "docker": ["fixture-docker"]}


def test_retained_test_population_has_separate_runtime_secret(tmp_path):
    c = config()
    c.update(retain_data=True, test_drivers_enabled=True, test_drivers_secret="fixture-test-key")
    assert staging.environment(c, "api")["BMT_TEST_DRIVERS_ENABLED"] == "true"
    assert staging.environment(c, "worker")["BMT_ENVIRONMENT"] == "development"
    assert staging.environment(c, "migrate")["BMT_DEV_AUTH_ENABLED"] == "false"
    assert staging.environment(c, "smoke")["BMT_TEST_DRIVERS_ENABLED"] == "false"
    commands = staging.deployment_commands(c, "fixture-image", tmp_path)
    assert any("BMT_DEV_AUTH_KEY=fixture-test-key:1" in arg for arg in commands["api"])
    assert any("BMT_DEV_AUTH_KEY=fixture-test-key:1" in arg for arg in commands["worker"])
    assert not any("BMT_DEV_AUTH_KEY" in arg for arg in commands["migrate"])
    c["retain_data"] = False
    with pytest.raises(ValueError, match="retained staging"):
        staging.environment(c, "api")


class Runner:
    def __init__(self, c):
        self.c, self.n = c, staging.names(c)
        self.resources, self.versions, self.calls, self.users = {}, {}, [], {}
        self.fail = None

    def run(self, argv, *, input_data=None, allow_missing=False, cwd=None):
        self.calls.append(list(argv))
        if self.fail and self.fail in argv:
            raise RuntimeError("Injected cloud command failure")
        assert "--project=" + self.c["project"] in argv
        args = argv[2:-1]
        if "--help" in args:
            return "Fixture CLI interface available"
        if args[:2] == ["auth", "print-access-token"]:
            return "sensitive-fixture-access"
        if args[:2] == ["auth", "print-identity-token"]:
            return "sensitive-fixture-identity"
        if "describe" in args:
            if args[:3] == ["secrets", "versions", "describe"]:
                name = next(x.split("=", 1)[1] for x in args if x.startswith("--secret="))
                return "{}" if name in self.versions else None
            index = args.index("describe")
            name = args[index + 1].removeprefix("gs://")
            resource = self.resources.get(name)
            if resource is None:
                assert allow_missing
                return None
            return json.dumps(resource)
        if args[:3] == ["secrets", "versions", "access"]:
            name = next(x.split("=", 1)[1] for x in args if x.startswith("--secret="))
            return self.versions[name]
        if args[:3] == ["secrets", "versions", "add"]:
            self.versions[args[3]] = input_data
            return "{}"
        if args[:3] == ["sql", "databases", "list"]:
            return '[{"name":"bmt"}]'
        if "create" in args:
            name = args[args.index("create") + 1]
            if args[:3] == ["iam", "service-accounts", "create"]:
                email = name + "@" + self.c["project"] + ".iam.gserviceaccount.com"
                self.resources[email] = {"description": "Beat my track staging " + self.c["owner"]}
            elif args[:2] == ["secrets", "create"] or args[:3] == ["artifacts", "repositories", "create"]:
                self.resources[name] = {"labels": staging.labels(self.c)}
        if "deploy" in args:
            name = args[args.index("deploy") + 1]
            image = next(x.split("=", 1)[1] for x in args if x.startswith("--image="))
            self.resources[name] = {"metadata": {"labels": staging.labels(self.c)},
                "spec": {"template": {"spec": {"containers": [{"image": image}]}}},
                "status": {"url": "https://bmt-fixture.run.app"}}
        return "{}"

    def request(self, method, url, *, headers=None, body=None):
        # Keep HTTP passwords/tokens out of the recorded argument plan.
        self.calls.append(["HTTP", method, url])
        if "storage.googleapis.com/storage/v1/b?" in url:
            self.resources[body["name"]] = {"labels": body["labels"]}
            assert body["iamConfiguration"]["publicAccessPrevention"] == "enforced"
            assert body["softDeletePolicy"] == {"retentionDurationSeconds": "0"}
            return {}
        if url.endswith("/instances"):
            self.resources[body["name"]] = {"settings": body["settings"]}
            assert body["settings"]["userLabels"] == staging.labels(self.c)
            assert body["settings"]["connectorEnforcement"] == "REQUIRED"
            return {"name": "creation-operation"}
        if "/users" in url:
            if method == "GET":
                return {"items": [{"name": n} for n in self.users]}
            self.users[body["name"]] = body["password"]
            return {"name": "password-operation"}
        if url.endswith("/healthz"):
            raise RuntimeError("Cloud frontend reserved URL")
        if url.endswith("/ready"):
            return {"status": "ready", "schema": "fixture"}
        if url.endswith("/v1/bootstrap"):
            return {"development_auth": False, "test_drivers": False}
        return {"status": "ok"}


def pinned(c):
    n = staging.names(c)
    return f"{c['region']}-docker.pkg.dev/{c['project']}/{n['repo']}/backend@sha256:" + "b" * 64


def test_plan_is_concrete_private_bounded_and_has_no_credentials(tmp_path):
    c = config()
    result = staging.plan(c, tmp_path)
    assert result["visibility"] == "private Cloud Run IAM" and result["database"]["max_connections"] == 40
    for role in ("api", "worker", "migrate", "smoke"):
        env = json.loads((tmp_path / (role + "-env.json")).read_text())
        assert env["BMT_DEV_AUTH_ENABLED"] == env["BMT_TEST_DRIVERS_ENABLED"] == "false"
        assert env["BMT_OBJECT_BACKEND"] == "gcs" and "BMT_DATABASE_URL" not in env
    commands = result["commands"]
    assert "--max=2" in commands["api"] and "--min=0" in commands["api"]
    assert "--instances=1" in commands["worker"]
    assert all("--project=" + c["project"] in argv for argv in commands.values())
    assert all("@sha256:" in " ".join(commands[r]) for r in ("api", "worker", "migrate", "smoke"))
    assert "latest" not in json.dumps(result)


@pytest.mark.parametrize("field,value", [("api_max", 3), ("worker_instances", 3), ("budget_eur", 0),
    ("disposable", False), ("public_api", True), ("cost_reviewed", False), ("example", True),
    ("estimated_hourly_eur", 100), ("estimated_hourly_eur", float("nan"))])
def test_apply_requires_safe_caps_and_reviewed_real_configuration(field, value):
    c = config()
    c[field] = value
    with pytest.raises(ValueError):
        staging.validate(c, apply=True)


def test_expiry_and_pricing_are_checked_before_apply():
    c = config()
    assert staging.validate(c, apply=True) is c
    c["expires_at"] = (staging.utc() + timedelta(hours=73)).isoformat()
    with pytest.raises(ValueError):
        staging.validate(c)
    c = config()
    c["pricing_checked_at"] = (staging.utc() - timedelta(days=8)).isoformat()
    with pytest.raises(ValueError):
        staging.validate(c, apply=True)


def test_provision_is_idempotent_and_secret_values_never_enter_arguments(tmp_path):
    c = config()
    runner = Runner(c)
    service = staging.Staging(c, tmp_path, runner)
    service.provision()
    passwords = deepcopy(runner.users)
    service.provision()
    assert runner.users == passwords and len(runner.versions) == 2
    serialized = json.dumps(runner.calls)
    assert all(value not in serialized for value in passwords.values())
    assert "sensitive-fixture-access" not in serialized
    assert "--password=" not in serialized
    assert runner.resources[service.n["bucket"]]["labels"]["bmt-owner"] == c["owner"]


def test_unowned_name_blocks_all_billed_creation_before_provision(tmp_path):
    c = config()
    runner = Runner(c)
    runner.resources[staging.names(c)["bucket"]] = {"labels": {"bmt-owner": "someone-else"}}
    with pytest.raises(RuntimeError, match="unowned"):
        staging.Staging(c, tmp_path, runner).provision()
    assert not any("create" in call or call[0] == "HTTP" for call in runner.calls)


def test_bootstrap_precedes_api_and_same_digest_is_used_everywhere(tmp_path):
    c = config()
    runner = Runner(c)
    service = staging.Staging(c, tmp_path, runner)
    image = pinned(c)
    assert service.deploy(image) == "https://bmt-fixture.run.app"
    calls = [call for call in runner.calls if "deploy" in call or "execute" in call]
    assert calls[0][4:6] == ["deploy", service.n["migrate"]]
    assert calls[1][4:6] == ["execute", service.n["migrate"]]
    assert calls[2][3:5] == ["deploy", service.n["api"]]
    for call in calls:
        if "deploy" in call:
            assert "--image=" + image in call
    assert json.loads((tmp_path / "deployment.json").read_text())["image"] == image
    assert json.loads((tmp_path / "api-env.json").read_text())["BMT_PUBLIC_BASE_URL"] == "https://bmt-fixture.run.app"


def test_changed_image_and_unowned_service_are_rejected_before_deploy(tmp_path):
    c = config()
    runner = Runner(c)
    service = staging.Staging(c, tmp_path, runner)
    runner.resources[service.n["worker"]] = {"labels": staging.labels(c),
        "template": {"containers": [{"image": pinned(c).replace("b" * 64, "c" * 64)}]}}
    with pytest.raises(RuntimeError, match="fresh owner"):
        service.deploy(pinned(c))
    assert not any("deploy" in call for call in runner.calls)


def test_cleanup_preflights_every_resource_and_refuses_partial_deletion(tmp_path):
    c = config()
    runner = Runner(c)
    service = staging.Staging(c, tmp_path, runner)
    runner.resources[service.n["api"]] = {"labels": staging.labels(c)}
    runner.resources[service.n["sql"]] = {"settings": {"userLabels": {"bmt-owner": "different-owner"}}}
    with pytest.raises(RuntimeError, match="unowned"):
        service.cleanup()
    assert not any("delete" in call or "rm" in call for call in runner.calls)


def test_cleanup_is_exact_owned_and_repeatable(tmp_path):
    c = config()
    runner = Runner(c)
    service = staging.Staging(c, tmp_path, runner)
    for item in staging.removal_commands(c):
        kind, name = item["kind"], item["name"]
        runner.resources[name] = ({"description": "Beat my track staging " + c["owner"]} if kind == "account" else
            {"settings": {"userLabels": staging.labels(c)}} if kind == "sql" else {"labels": staging.labels(c)})
    original = runner.run
    def run(argv, **kwargs):
        result = original(argv, **kwargs)
        if "delete" in argv or "rm" in argv:
            marker = "delete" if "delete" in argv else "rm"
            name = argv[argv.index(marker) + 1]
            if name == "--recursive":
                name = argv[argv.index(marker) + 2].removeprefix("gs://")
            runner.resources.pop(name, None)
        return result
    runner.run = run
    deleted = service.cleanup()
    assert len(deleted) == 12 and service.cleanup() == []
    assert not any(call[2:4] == ["projects", "delete"] for call in runner.calls)
    assert len([call for call in runner.calls if "remove-iam-policy-binding" in call]) == 3


def test_smoke_never_forwards_token_to_tampered_receipt(tmp_path):
    c = config()
    runner = Runner(c)
    service = staging.Staging(c, tmp_path, runner)
    service.deploy(pinned(c))
    receipt = json.loads((tmp_path / "deployment.json").read_text())
    receipt["url"] = "https://attacker.example"
    staging.write_json(tmp_path / "deployment.json", receipt)
    count = len(runner.calls)
    with pytest.raises(RuntimeError, match="token forwarding refused"):
        service.smoke()
    assert not any("print-identity-token" in call or call[0] == "HTTP" for call in runner.calls[count:])


def test_smoke_uses_cloud_routable_paths_and_rejects_auth_bypasses(tmp_path):
    c = config()
    runner = Runner(c)
    service = staging.Staging(c, tmp_path, runner)
    service.deploy(pinned(c))
    result = service.smoke()
    assert result["/health"] == {"status": "ok"}
    assert "--liveness-probe=httpGet.path=/health,timeoutSeconds=2,periodSeconds=15,failureThreshold=3" in staging.deployment_commands(c, pinned(c), tmp_path)["api"]
    original = runner.request
    def request(method, url, **kwargs):
        if url.endswith("/v1/bootstrap"):
            return {"development_auth": False, "test_drivers": True}
        return original(method, url, **kwargs)
    runner.request = request
    with pytest.raises(RuntimeError, match="health/auth separation"):
        service.smoke()


def test_command_errors_do_not_echo_secrets(monkeypatch):
    monkeypatch.setattr(staging.subprocess, "run", lambda *args, **kwargs:
        SimpleNamespace(returncode=1, stderr="sensitive credential details", stdout="sensitive-token"))
    with pytest.raises(RuntimeError) as error:
        staging.Runner().run(["fixture-tool"])
    assert "sensitive" not in str(error.value)


def test_nested_job_templates_and_redeployment_keep_the_same_digest(tmp_path):
    c = config()
    runner = Runner(c)
    service = staging.Staging(c, tmp_path, runner)
    service.deploy(pinned(c))
    job = runner.resources[service.n["migrate"]]
    task = job["spec"]["template"]
    job["spec"]["template"] = {"spec": {"template": task}}
    assert staging.resource_image(job) == pinned(c)
    assert service.deploy(pinned(c)) == "https://bmt-fixture.run.app"


def test_preflight_requires_active_account_explicit_project_and_billing(tmp_path):
    c = config()
    runner = Runner(c)
    original = runner.run
    def run(argv, **kwargs):
        if "list" in argv and "auth" in argv:
            return '[{"status":"ACTIVE"}]'
        if "describe" in argv and "billing" in argv:
            return json.dumps({"projectId": c["project"], "billingEnabled": True})
        if "describe" in argv and "projects" in argv:
            return json.dumps({"projectId": c["project"], "lifecycleState": "ACTIVE"})
        return original(argv, **kwargs)
    runner.run = run
    staging.Staging(c, tmp_path, runner).preflight()
    runner.run = lambda *args, **kwargs: '[]'
    with pytest.raises(RuntimeError, match="Authenticate"):
        staging.Staging(c, tmp_path, runner).preflight()


def test_current_cli_missing_worker_is_distinct_from_permission_failure(monkeypatch):
    monkeypatch.setattr(staging.subprocess, "run", lambda *args, **kwargs:
        SimpleNamespace(returncode=1, stderr="ERROR: Cannot find worker pool [owned-name]", stdout=""))
    assert staging.Runner().run(["fixture"], allow_missing=True) is None
    monkeypatch.setattr(staging.subprocess, "run", lambda *args, **kwargs:
        SimpleNamespace(returncode=1, stderr="PERMISSION_DENIED: account cannot access worker pool", stdout=""))
    with pytest.raises(RuntimeError):
        staging.Runner().run(["fixture"], allow_missing=True)


def test_missing_registry_prevents_build_and_push(tmp_path, monkeypatch):
    c = config()
    engine = b"isolated-engine-fixture"
    c["godot_sha256"] = staging.hashlib.sha256(engine).hexdigest()
    original = Path.read_bytes
    monkeypatch.setattr(Path, "read_bytes", lambda path: engine if path == staging.ROOT / "backend/deploy/vendor/godot" else original(path))
    runner = Runner(c)
    with pytest.raises(RuntimeError, match="complete provisioning"):
        staging.Staging(c, tmp_path, runner).build()
    assert not any("fixture-docker" in argv or "print-access-token" in argv for argv in runner.calls)


def test_owner_retention_disables_cleanup_before_cloud_calls(tmp_path):
    c = config()
    c["retain_data"] = True
    runner = Runner(c)
    with pytest.raises(RuntimeError, match="data retention"):
        staging.Staging(c, tmp_path, runner).cleanup()
    assert runner.calls == []


def test_remote_retention_refuses_all_deletes_with_stale_local_config(tmp_path):
    c = config()
    runner = Runner(c)
    names = staging.names(c)
    runner.resources[names["api"]] = {"labels": staging.labels(c)}
    runner.resources[names["sql"]] = {"settings": {"userLabels": {**staging.labels(c), "bmt-retain-data": "true"}}}
    with pytest.raises(RuntimeError, match="Remote owner data-retention"):
        staging.Staging(c, tmp_path, runner).cleanup()
    assert not any("delete" in argv or "rm" in argv for argv in runner.calls)


def test_warm_api_minimum_keeps_instance_and_connection_caps(tmp_path):
    c = config()
    c["api_min"] = 1
    staging.validate(c, apply=True)
    commands = staging.deployment_commands(c, pinned(c), tmp_path)
    assert "--min=1" in commands["api"] and "--max=2" in commands["api"]
    for value in (2, -1, True, "1"):
        c["api_min"] = value
        with pytest.raises(ValueError, match="warm API"):
            staging.validate(c, apply=True)
