"""Reviewable, explicitly applied and ownership-fenced Google Cloud staging."""
from __future__ import annotations

import argparse
import hashlib
import ipaddress
import json
import math
import os
import re
import secrets
import shutil
import subprocess
import time
import uuid
from datetime import datetime, timedelta, timezone
from pathlib import Path

import requests
from sqlalchemy.engine import URL, make_url

ROOT = Path(__file__).resolve().parents[3]
PIN = "8d106cbe6144c2dc7e881d61d2429c1a8a76e6b22ef48bd5e48dcf934953f71e"
SERVICES = ["run.googleapis.com", "sqladmin.googleapis.com", "secretmanager.googleapis.com",
            "artifactregistry.googleapis.com", "storage.googleapis.com"]


def utc():
    return datetime.now(timezone.utc)


def stamp(value):
    return datetime.fromisoformat(value.replace("Z", "+00:00"))


def write_json(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_suffix(path.suffix + ".pending")
    temporary.write_text(json.dumps(value, indent=2) + "\n", encoding="utf-8")
    temporary.replace(path)


def validate(config, *, apply=False, now=None):
    now = now or utc()
    if config.get("format") != "bmt-gcp-staging-v1" or config.get("disposable") is not True:
        raise ValueError("Use an explicitly disposable staging configuration")
    if not re.fullmatch(r"[a-z][a-z0-9-]{4,28}[a-z0-9]", config.get("project", "")):
        raise ValueError("Supply an explicit Google Cloud project ID")
    if not re.fullmatch(r"[0-9a-f]{32}", config.get("owner", "")):
        raise ValueError("Invalid staging ownership ID")
    if not re.fullmatch(r"[a-z]+-[a-z]+[0-9]", config.get("region", "")):
        raise ValueError("Invalid region")
    expiry = stamp(config["expires_at"])
    if expiry.tzinfo is None or not now < expiry <= now + timedelta(hours=72):
        raise ValueError("Staging expiry must be within the next 72 hours")
    if type(config.get("public_api")) is not bool:
        raise ValueError("Choose public_api explicitly; private IAM ingress is the default")
    if type(config.get("api_max")) is not int or not 1 <= config["api_max"] <= 2:
        raise ValueError("Initial staging allows at most two API replicas")
    if type(config.get("api_min", 0)) is not int or not 0 <= config.get("api_min", 0) <= min(1, config["api_max"]):
        raise ValueError("Staging permits zero or one warm API instance within the replica cap")
    if type(config.get("worker_instances")) is not int or not 1 <= config["worker_instances"] <= 2:
        raise ValueError("Initial staging allows one or two workers")
    # Zero overflow, full revision overlap plus operations and spare DB connections.
    budget = 2 * (config["api_max"] * 4 + config["worker_instances"] * 2) + 6 + 10
    if budget > 40:
        raise ValueError("Replica/rollout pools exceed the 40-connection staging budget")
    clients = config.get("google_client_ids", [])
    if type(clients) is not list or any(not re.fullmatch(r"[0-9A-Za-z_-]+\.apps\.googleusercontent\.com", c) for c in clients):
        raise ValueError("Invalid Google client ID list")
    if config.get("google_web_client_id") and config["google_web_client_id"] not in clients:
        raise ValueError("Web client ID must be in the accepted audience list")
    if config["public_api"] and not clients:
        raise ValueError("Public staging requires configured real Google sign-in audiences")
    for name in ("gcloud", "docker"):
        command = config.get(name)
        if type(command) is not list or not command or any(type(part) is not str or not part or "\x00" in part for part in command):
            raise ValueError("Tool commands must be explicit argument arrays")
    if config.get("godot_sha256") != PIN:
        raise ValueError("Use the independently verified engine hash from GODOT_PROVENANCE.md")
    amount = config.get("budget_eur")
    if type(amount) not in (int, float) or not 0 < amount <= 50:
        raise ValueError("Initial staging budget must be positive and at most EUR 50")
    if apply:
        if config.get("example") or config.get("cost_reviewed") is not True:
            raise ValueError("Apply requires a real project and a reviewed cost estimate")
        rate = config.get("estimated_hourly_eur")
        if type(rate) not in (int, float) or not 0 < rate < 100 or not math.isfinite(rate):
            raise ValueError("Supply a current all-services hourly estimate")
        checked = stamp(config.get("pricing_checked_at", ""))
        if checked.tzinfo is None or not now - timedelta(days=7) <= checked <= now:
            raise ValueError("Recheck provider pricing within seven days of apply")
        if rate * (expiry - now).total_seconds() / 3600 > amount:
            raise ValueError("Estimated remaining run exceeds the reviewed budget")
    return config


def names(config):
    base = "bmt-stg-" + config["owner"][:8]
    return {"api": base + "-api", "worker": base + "-worker", "migrate": base + "-migrate",
        "smoke": base + "-smoke", "sql": base + "-db", "repo": base + "-images",
        "bucket": "bmt-stg-" + config["project"][:23] + "-" + config["owner"][:8],
        "app_secret": base + "-app-db", "admin_secret": base + "-admin-db",
        "runtime": base + "-runtime", "migrator": base + "-migrator", "operator": base + "-operator"}


def labels(config):
    return {"bmt-environment": "staging", "bmt-owner": config["owner"],
        "bmt-expires": str(int(stamp(config["expires_at"]).timestamp()))}


def environment(config, role, public_url="https://staging.invalid"):
    result = {"BMT_ENVIRONMENT": "production", "BMT_DEV_AUTH_ENABLED": "false", "BMT_TEST_DRIVERS_ENABLED": "false",
        "BMT_OBJECT_BACKEND": "gcs", "BMT_GCS_BUCKET": names(config)["bucket"], "BMT_GCS_PREFIX": "bmt/v1",
        "BMT_PUBLIC_BASE_URL": public_url, "BMT_GOOGLE_CLIENT_IDS": ",".join(config.get("google_client_ids", [])),
        "BMT_GOOGLE_WEB_CLIENT_ID": config.get("google_web_client_id", ""), "BMT_DATABASE_POOL_SIZE": "4" if role == "api" else "2",
        "BMT_DATABASE_POOL_OVERFLOW": "0", "BMT_DATABASE_POOL_TIMEOUT_SECONDS": "3",
        "BMT_READINESS_CACHE_SECONDS": "2", "BMT_READINESS_STORAGE_CACHE_SECONDS": "30", "BMT_READINESS_TIMEOUT_SECONDS": "2",
        "BMT_UPLOAD_CONCURRENCY": "2", "BMT_MAX_QUEUED_RUNS": "128", "BMT_PERSISTENT_VERIFIER": "true",
        "BMT_WORKER_SHUTDOWN_GRACE_SECONDS": "5", "BMT_STAGING_OWNER": config["owner"]}
    if role == "api":
        # The direct Cloud Run frontend reaches the container on loopback/link
        # local addresses. External LB chains must pin their additional hops.
        values = config.get("trusted_proxy_networks", ["127.0.0.1/32", "169.254.0.0/16"])
        if not isinstance(values, list) or not all(isinstance(value, str) for value in values):
            raise ValueError("Trusted proxy networks require an explicit CIDR list")
        networks = tuple(ipaddress.ip_network(value, strict=False) for value in values)
        for version in (4, 6):
            if any(network.prefixlen == 0 for network in ipaddress.collapse_addresses(
                    network for network in networks if network.version == version)):
                raise ValueError("Trusted proxies must not include the whole internet")
        result["BMT_TRUSTED_PROXY_NETWORKS"] = ",".join(map(str, networks))
    if config.get("test_drivers_enabled") is True and role in ("api", "worker"):
        if config.get("retain_data") is not True or not config.get("test_drivers_secret"):
            raise ValueError("Cloud test drivers require retained staging and a separate key secret")
        result.update(BMT_ENVIRONMENT="development", BMT_DEV_AUTH_ENABLED="true", BMT_TEST_DRIVERS_ENABLED="true")
    return result


def command(config, *args):
    return [*config["gcloud"], "--project=" + config["project"], *args, "--quiet"]


def deployment_commands(config, image, directory):
    n = names(config)
    region, project = config["region"], config["project"]
    sql = f"{project}:{region}:{n['sql']}"
    label = ",".join(f"{k}={v}" for k, v in labels(config).items())
    def account(role):
        return n[role] + "@" + project + ".iam.gserviceaccount.com"
    def common(role, identity, secret):
        bindings = "BMT_DATABASE_URL=" + n[secret] + ":1"
        if config.get("test_drivers_enabled") is True and role in ("api", "worker"):
            bindings += ",BMT_DEV_AUTH_KEY=" + config["test_drivers_secret"] + ":1"
        return ["--image=" + image, "--region=" + region, "--service-account=" + account(identity),
            "--set-cloudsql-instances=" + sql, "--set-secrets=" + bindings,
            "--env-vars-file=" + str(directory / (role + "-env.json")), "--labels=" + label,
            "--cpu=1", "--memory=" + ("1024Mi" if role == "api" else "768Mi")]
    job = ["--command=python", "--tasks=1", "--parallelism=1", "--max-retries=0", "--task-timeout=300s"]
    return {
        "migrate": command(config, "run", "jobs", "deploy", n["migrate"], *common("migrate", "migrator", "admin_secret"),
            *job, "--args=-m,bmt_backend.cloud_setup"),
        "migrate_execute": command(config, "run", "jobs", "execute", n["migrate"], "--region=" + region, "--wait"),
        "api": command(config, "run", "deploy", n["api"], *common("api", "runtime", "app_secret"),
            "--port=8080", "--concurrency=16", "--min=" + str(config.get("api_min", 0)), "--max=" + str(config["api_max"]),
            "--timeout=60s", "--ingress=all", "--allow-unauthenticated" if config["public_api"] else "--no-allow-unauthenticated",
            "--startup-probe=httpGet.path=/ready,timeoutSeconds=4,periodSeconds=5,failureThreshold=12",
            "--liveness-probe=httpGet.path=/health,timeoutSeconds=2,periodSeconds=15,failureThreshold=3"),
        "worker": command(config, "run", "worker-pools", "deploy", n["worker"], *common("worker", "runtime", "app_secret"),
            "--instances=" + str(config["worker_instances"]), "--command=python", "--args=-m,bmt_backend.worker"),
        "smoke": command(config, "run", "jobs", "deploy", n["smoke"], *common("smoke", "operator", "app_secret"),
            *job, "--args=-m,bmt_backend.cloud_smoke"),
        "smoke_execute": command(config, "run", "jobs", "execute", n["smoke"], "--region=" + region, "--wait"),
    }


def plan(config, directory):
    validate(config)
    n = names(config)
    image = f"{config['region']}-docker.pkg.dev/{config['project']}/{n['repo']}/backend@sha256:<built-digest>"
    result = {"format": config["format"], "project": config["project"], "owner": config["owner"],
        "expires_at": config["expires_at"], "budget_eur": config["budget_eur"], "cost_reviewed": config.get("cost_reviewed", False),
        "resources": n, "labels": labels(config), "database": {"version": "POSTGRES_17", "tier": "db-custom-1-3840",
            "zonal": True, "max_connections": 40, "disk_gib": 10, "disk_autogrowth": False, "backups": False},
        "visibility": "public with application auth" if config["public_api"] else "private Cloud Run IAM",
        "commands": deployment_commands(config, image, directory),
        "iam": {"runtime": ["project:cloudsql.client", "bucket:storage.objectCreator", "bucket:storage.objectViewer", "app-secret:secretAccessor"],
            "migrator": ["project:cloudsql.client", "admin-secret:secretAccessor"],
            "operator": ["project:cloudsql.client", "bucket:storage.objectUser", "app-secret:secretAccessor"]},
        "notes": ["No resources created by plan/render", "Budget is a reviewed estimate, not a provider spend cap",
            "Run cleanup/watch explicitly; a local watcher requires this computer to remain running",
            "No live player data is imported", "Default HTTP server does not trust arbitrary forwarded headers"]}
    for role in ("api", "worker", "migrate", "smoke"):
        write_json(directory / (role + "-env.json"), environment(config, role))
    write_json(directory / "plan.json", result)
    return result


def removal_commands(config):
    n = names(config)
    region = "--region=" + config["region"]
    resources = [("worker", n["worker"]), ("api", n["api"]), ("job", n["smoke"]), ("job", n["migrate"]),
        ("sql", n["sql"]), ("bucket", n["bucket"]), ("repo", n["repo"]),
        ("secret", n["app_secret"]), ("secret", n["admin_secret"])]
    resources += [("account", n[role] + "@" + config["project"] + ".iam.gserviceaccount.com")
        for role in ("runtime", "migrator", "operator")]
    result = []
    for kind, name in resources:
        args = {"worker": ["run", "worker-pools", "delete", name, region], "api": ["run", "services", "delete", name, region],
            "job": ["run", "jobs", "delete", name, region], "sql": ["sql", "instances", "delete", name],
            "bucket": ["storage", "rm", "--recursive", "gs://" + name],
            "repo": ["artifacts", "repositories", "delete", name, "--location=" + config["region"]],
            "secret": ["secrets", "delete", name], "account": ["iam", "service-accounts", "delete", name]}
        result.append({"kind": kind, "name": name, "command": command(config, *args[kind])})
    return result


def resource_image(resource):
    # Services/worker pools have one template; jobs also nest an execution/task template.
    node = resource
    for _ in range(8):
        containers = node.get("containers")
        if type(containers) is list:
            return containers[0].get("image") if len(containers) == 1 else None
        node = node.get("template") or node.get("spec")
        if type(node) is not dict:
            return None
    return None


class Runner:
    def run(self, argv, *, input_data=None, allow_missing=False, cwd=None):
        try:
            result = subprocess.run(argv, input=input_data, capture_output=True, text=True, cwd=cwd,
                timeout=1800, check=False)
        except (OSError, subprocess.SubprocessError):
            raise RuntimeError("Cloud/Docker command unavailable or timed out") from None
        if result.returncode:
            if allow_missing and re.search(r"NOT_FOUND|not found|does not exist|\b404\b|Cannot find (?:worker pool|service|job)\b", result.stderr, re.IGNORECASE):
                return None
            # Output can contain authentication or secret content; keep it private.
            raise RuntimeError("Cloud/Docker command failed; inspect the named resource with the CLI")
        return result.stdout.strip()

    def request(self, method, url, *, headers=None, body=None):
        try:
            response = requests.request(method, url, headers=headers, json=body, timeout=(3, 30), allow_redirects=False)
            if response.status_code not in (200, 201):
                raise RuntimeError("Cloud API request failed")
            return response.json()
        except (requests.RequestException, ValueError):
            raise RuntimeError("Cloud API request unavailable") from None


class Staging:
    def __init__(self, config, directory, runner=None):
        self.c, self.directory, self.runner = config, directory.resolve(), runner or Runner()
        self.n = names(config)

    def call(self, *args, **kwargs):
        return self.runner.run(command(self.c, *args), **kwargs)

    def account(self, role):
        return self.n[role] + "@" + self.c["project"] + ".iam.gserviceaccount.com"

    def describe(self, kind, name):
        region = "--region=" + self.c["region"]
        args = {"sql": ["sql", "instances", "describe", name],
            "bucket": ["storage", "buckets", "describe", "gs://" + name],
            "repo": ["artifacts", "repositories", "describe", name, "--location=" + self.c["region"]],
            "secret": ["secrets", "describe", name], "api": ["run", "services", "describe", name, region],
            "worker": ["run", "worker-pools", "describe", name, region], "job": ["run", "jobs", "describe", name, region],
            "account": ["iam", "service-accounts", "describe", name]}
        value = self.call(*args[kind], "--format=json", allow_missing=True)
        if value is None:
            return None
        resource = json.loads(value)
        actual = resource.get("labels") or resource.get("metadata", {}).get("labels", {})
        if kind == "sql":
            actual = resource.get("settings", {}).get("userLabels", {})
        if kind == "account":
            owned = resource.get("description") == "Beat my track staging " + self.c["owner"]
        else:
            owned = actual.get("bmt-owner") == self.c["owner"] and actual.get("bmt-environment") == "staging"
        if not owned:
            raise RuntimeError("Refusing to adopt or delete an unowned cloud resource")
        return resource

    def ensure(self, kind, name, *args):
        if self.describe(kind, name) is None:
            self.call(*args)

    def secret(self, name, payload):
        self.ensure("secret", name, "secrets", "create", name, "--replication-policy=automatic",
            "--labels=" + self.label_string())
        existing = self.call("secrets", "versions", "describe", "1", "--secret=" + name, "--format=json", allow_missing=True)
        if existing is None:
            self.call("secrets", "versions", "add", name, "--data-file=-", input_data=payload)
        value = self.call("secrets", "versions", "access", "1", "--secret=" + name)
        expected = make_url(payload)
        actual = make_url(value)
        if actual.username != expected.username or actual.database != "bmt" or actual.query != expected.query or actual.host:
            raise RuntimeError("Owned secret points outside the staging database")
        return value

    def label_string(self):
        return ",".join(f"{k}={v}" for k, v in labels(self.c).items())

    def preflight(self):
        active = json.loads(self.call("auth", "list", "--filter=status:ACTIVE", "--format=json"))
        if not active:
            raise RuntimeError("Authenticate the Google Cloud CLI before applying staging")
        project = json.loads(self.call("projects", "describe", self.c["project"], "--format=json"))
        if project.get("projectId") != self.c["project"] or project.get("lifecycleState") != "ACTIVE":
            raise RuntimeError("Explicit staging project is unavailable")
        billing = json.loads(self.call("billing", "projects", "describe", self.c["project"], "--format=json"))
        if billing.get("projectId") != self.c["project"] or billing.get("billingEnabled") is not True:
            raise RuntimeError("Staging project billing/credits must be configured first")
        self.call("run", "worker-pools", "deploy", "--help")  # Require the installed GA worker-pool interface.

    def sql_user(self, name, password):
        token = self.call("auth", "print-access-token")
        base = f"https://sqladmin.googleapis.com/sql/v1beta4/projects/{self.c['project']}/instances/{self.n['sql']}"
        response = self.runner.request("GET", base + "/users", headers={"Authorization": "Bearer " + token})
        method = "PUT" if any(u.get("name") == name for u in response.get("items", [])) else "POST"
        url = base + "/users" + ("?name=" + name if method == "PUT" else "")
        operation = self.runner.request(method, url, headers={"Authorization": "Bearer " + token}, body={"name": name, "password": password})
        if not re.fullmatch(r"[A-Za-z0-9_-]+", operation.get("name", "")):
            raise RuntimeError("Cloud SQL returned no bounded operation ID")
        self.call("sql", "operations", "wait", operation["name"], "--timeout=300")

    def create_bucket(self):
        if self.describe("bucket", self.n["bucket"]) is not None:
            return
        token = self.call("auth", "print-access-token")
        # Labels are atomic in the API request; CLI bucket creation has no labels flag.
        self.runner.request("POST", "https://storage.googleapis.com/storage/v1/b?project=" + self.c["project"],
            headers={"Authorization": "Bearer " + token}, body={"name": self.n["bucket"], "location": self.c["region"],
                "labels": labels(self.c), "iamConfiguration": {"uniformBucketLevelAccess": {"enabled": True},
                    "publicAccessPrevention": "enforced"}, "softDeletePolicy": {"retentionDurationSeconds": "0"}})

    def create_sql(self):
        if self.describe("sql", self.n["sql"]) is not None:
            return
        token = self.call("auth", "print-access-token")
        operation = self.runner.request("POST", f"https://sqladmin.googleapis.com/sql/v1beta4/projects/{self.c['project']}/instances",
            headers={"Authorization": "Bearer " + token}, body={"name": self.n["sql"], "region": self.c["region"],
                "databaseVersion": "POSTGRES_17", "settings": {"tier": "db-custom-1-3840", "edition": "ENTERPRISE",
                    "availabilityType": "ZONAL", "dataDiskSizeGb": "10", "dataDiskType": "PD_SSD", "storageAutoResize": False,
                    "databaseFlags": [{"name": "max_connections", "value": "40"}], "userLabels": labels(self.c),
                    "connectorEnforcement": "REQUIRED", "ipConfiguration": {"ipv4Enabled": True, "authorizedNetworks": []},
                    "backupConfiguration": {"enabled": False, "pointInTimeRecoveryEnabled": False},
                    "finalBackupConfig": {"enabled": False}, "retainBackupsOnDelete": False, "deletionProtectionEnabled": False}})
        if not re.fullmatch(r"[A-Za-z0-9_-]+", operation.get("name", "")):
            raise RuntimeError("Cloud SQL returned no bounded creation operation ID")
        self.call("sql", "operations", "wait", operation["name"], "--timeout=1800")

    def provision(self):
        self.call("services", "enable", *SERVICES)
        for item in removal_commands(self.c):
            self.describe(item["kind"], item["name"])  # Detect collisions before creating billed resources.
        for role in ("runtime", "migrator", "operator"):
            self.ensure("account", self.account(role), "iam", "service-accounts", "create", self.n[role],
                "--description=Beat my track staging " + self.c["owner"])
            self.call("projects", "add-iam-policy-binding", self.c["project"],
                "--member=serviceAccount:" + self.account(role), "--role=roles/cloudsql.client", "--condition=None")
        self.create_bucket()
        for role, grants in (("runtime", ["roles/storage.objectCreator", "roles/storage.objectViewer"]),
                             ("operator", ["roles/storage.objectUser"])):
            for grant in grants:
                self.call("storage", "buckets", "add-iam-policy-binding", "gs://" + self.n["bucket"],
                    "--member=serviceAccount:" + self.account(role), "--role=" + grant)
        self.ensure("repo", self.n["repo"], "artifacts", "repositories", "create", self.n["repo"],
            "--repository-format=docker", "--location=" + self.c["region"], "--labels=" + self.label_string())
        self.create_sql()
        databases = json.loads(self.call("sql", "databases", "list", "--instance=" + self.n["sql"], "--format=json"))
        if not any(d.get("name") == "bmt" for d in databases):
            self.call("sql", "databases", "create", "bmt", "--instance=" + self.n["sql"])
        host = f"/cloudsql/{self.c['project']}:{self.c['region']}:{self.n['sql']}"
        for role, user in (("admin_secret", "postgres"), ("app_secret", "bmt")):
            proposed = URL.create("postgresql+psycopg", username=user, password=secrets.token_hex(32),
                database="bmt", query={"host": host}).render_as_string(hide_password=False)
            uri = self.secret(self.n[role], proposed)
            self.sql_user(user, make_url(uri).password)
        for role, secret in (("runtime", "app_secret"), ("operator", "app_secret"), ("migrator", "admin_secret")):
            self.call("secrets", "add-iam-policy-binding", self.n[secret],
                "--member=serviceAccount:" + self.account(role), "--role=roles/secretmanager.secretAccessor")

    def build(self):
        executable = ROOT / "backend/deploy/vendor/godot"
        if hashlib.sha256(executable.read_bytes()).hexdigest() != self.c["godot_sha256"]:
            raise RuntimeError("Staged Linux engine differs from the independently verified pin")
        if self.describe("repo", self.n["repo"]) is None:
            raise RuntimeError("Owned staging registry is missing; complete provisioning before building")
        source = hashlib.sha256()
        for directory in (ROOT / "backend/bmt_backend", ROOT / "game"):
            for path in sorted(directory.rglob("*")):
                if path.is_file() and not any(p in (".godot", "__pycache__", "build") for p in path.parts):
                    source.update(path.relative_to(ROOT).as_posix().encode())
                    source.update(path.read_bytes())
        for name in ("backend/Dockerfile", "backend/Dockerfile.dockerignore", "backend/README.md", "backend/requirements.lock",
                     "backend/pyproject.toml", "godot-version.txt", "backend/deploy/object_archive.py",
                     "backend/deploy/check_godot.py", "backend/deploy/stage_verifier.py", "backend/tests/fixtures/verified_oval.json"):
            source.update(name.encode())
            source.update((ROOT / name).read_bytes())
        receipt = self.directory / "image.json"
        if receipt.exists():
            prior = json.loads(receipt.read_text())
            if prior.get("source_hash") == source.hexdigest():
                return prior["image"]  # Deploy validates owned registry and immutable digest again.
        registry = self.c["region"] + "-docker.pkg.dev"
        image = f"{registry}/{self.c['project']}/{self.n['repo']}/backend:{source.hexdigest()[:24]}"
        # Relative context/config paths work with native Docker and explicit WSL --cd commands.
        self.runner.run([*self.c["docker"], "build", "--platform=linux/amd64", "--file=backend/Dockerfile",
            "--build-arg=GODOT_SHA256=" + self.c["godot_sha256"], "--tag=" + image, "."], cwd=ROOT)
        private = self.directory / "docker-private"
        private.mkdir(exist_ok=False)
        try:
            token = self.call("auth", "print-access-token")
            relative = os.path.relpath(private, ROOT).replace("\\", "/")
            self.runner.run([*self.c["docker"], "--config=" + relative, "login", registry,
                "--username=oauth2accesstoken", "--password-stdin"], input_data=token, cwd=ROOT)
            self.runner.run([*self.c["docker"], "--config=" + relative, "push", image], cwd=ROOT)
        finally:
            # Only this freshly created credentials directory may be removed.
            if private.resolve().parent != self.directory or private.is_symlink():
                raise RuntimeError("Refusing unsafe temporary credentials cleanup")
            shutil.rmtree(private)
        result = json.loads(self.call("artifacts", "docker", "images", "describe", image, "--format=json"))
        digest = result.get("image_summary", {}).get("digest", "")
        if not re.fullmatch(r"sha256:[0-9a-f]{64}", digest):
            raise RuntimeError("Registry returned no immutable image digest")
        pinned = image.rsplit(":", 1)[0] + "@" + digest
        write_json(receipt, {"source_hash": source.hexdigest(), "image": pinned})
        return pinned

    def deploy(self, image):
        if not re.fullmatch(re.escape(self.c["region"] + "-docker.pkg.dev/" + self.c["project"] + "/" + self.n["repo"] + "/backend@sha256:") + r"[0-9a-f]{64}", image):
            raise ValueError("Deploy requires the owned registry's immutable digest")
        plan(self.c, self.directory)
        commands = deployment_commands(self.c, image, self.directory)
        for kind, resource in (("job", "migrate"), ("api", "api"), ("worker", "worker"), ("job", "smoke")):
            existing = self.describe(kind, self.n[resource])  # Never overwrite an unrelated name.
            if existing and resource_image(existing) != image:
                raise RuntimeError("A changed staging image needs a fresh owner/environment; mixed-build rollout is refused")
        for key in ("migrate", "migrate_execute", "api"):
            self.runner.run(commands[key])
        api = self.describe("api", self.n["api"])
        uri = api.get("status", {}).get("url") or api.get("uri", "")
        if not re.fullmatch(r"https://[a-z0-9.-]+\.run\.app", uri):
            raise RuntimeError("Cloud Run returned an unexpected service URL")
        for role in ("api", "worker", "smoke"):
            write_json(self.directory / (role + "-env.json"), environment(self.c, role, uri))
        self.runner.run(commands["api"])  # Same digest, now the real browser origin; no mixed protocol versions.
        for key in ("worker", "smoke", "smoke_execute"):
            self.runner.run(commands[key])
        write_json(self.directory / "deployment.json", {"image": image, "url": uri, "owner": self.c["owner"]})
        return uri

    def smoke(self):
        deployment = json.loads((self.directory / "deployment.json").read_text())
        api = self.describe("api", self.n["api"])
        if api is None or deployment["owner"] != self.c["owner"]:
            raise RuntimeError("Staging service or local receipt is missing")
        actual_url = api.get("status", {}).get("url") or api.get("uri", "")
        if (deployment["url"] != actual_url or not re.fullmatch(r"https://[a-z0-9.-]+\.run\.app", actual_url)
                or resource_image(api) != deployment["image"]):
            raise RuntimeError("Local staging receipt differs from the owned service; token forwarding refused")
        token = self.call("auth", "print-identity-token")
        results = {}
        for path in ("/health", "/ready", "/v1/bootstrap"):
            # X-Serverless-Authorization leaves application Authorization available for later real-account tests.
            value = self.runner.request("GET", deployment["url"] + path,
                headers={"X-Serverless-Authorization": "Bearer " + token})
            results[path] = value
        if (results["/health"].get("status") != "ok" or results["/ready"].get("status") != "ready"
                or results["/v1/bootstrap"].get("development_auth") is not bool(self.c.get("test_drivers_enabled"))
                or results["/v1/bootstrap"].get("test_drivers") is not bool(self.c.get("test_drivers_enabled"))):
            raise RuntimeError("Staging health/auth separation failed")
        write_json(self.directory / "smoke.json", results)
        return results

    def cleanup(self):
        if self.c.get("retain_data") is True:
            raise RuntimeError("Owner requested data retention; disposable cleanup is disabled")
        # Check ALL ownership first; a mismatch must cause no partial deletion.
        present = []
        for item in removal_commands(self.c):
            resource = self.describe(item["kind"], item["name"])
            if resource is None:
                continue
            resource_labels = resource.get("labels") or resource.get("metadata", {}).get("labels", {})
            if item["kind"] == "sql":
                resource_labels = resource.get("settings", {}).get("userLabels", {})
            if resource_labels.get("bmt-retain-data") == "true":
                raise RuntimeError("Remote owner data-retention guard forbids disposable cleanup")
            present.append(item)
        deleted = []
        for item in present:
            kind, name = item["kind"], item["name"]
            # Recheck immediately before mutation as well as the all-resource preflight.
            if self.describe(kind, name) is None:
                continue
            if kind == "account":
                self.call("projects", "remove-iam-policy-binding", self.c["project"],
                    "--member=serviceAccount:" + name, "--role=roles/cloudsql.client", "--condition=None")
            self.runner.run(item["command"])
            deleted.append({"kind": kind, "name": name})
        write_json(self.directory / "cleanup.json", {"owner": self.c["owner"], "deleted": deleted})
        return deleted


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("action", choices=("init", "plan", "deploy", "smoke", "cleanup", "watch"))
    parser.add_argument("--config", type=Path, default=ROOT / ".tools/gcp-staging/config.json")
    parser.add_argument("--project")
    parser.add_argument("--region", default="europe-west1")
    parser.add_argument("--hours", type=int, default=4)
    parser.add_argument("--apply", action="store_true")
    parser.add_argument("--confirm-owner", default="")
    args = parser.parse_args()
    if args.action == "init":
        if args.config.exists():
            raise ValueError("Existing staging config was not overwritten")
        if not 1 <= args.hours <= 72:
            raise ValueError("Choose a one-to-72-hour staging lease")
        config = {"format": "bmt-gcp-staging-v1", "project": args.project or "bmt-staging-example", "region": args.region,
            "owner": uuid.uuid4().hex, "disposable": True, "example": args.project is None,
            "expires_at": (utc() + timedelta(hours=args.hours)).isoformat(), "budget_eur": 40,
            "cost_reviewed": False, "estimated_hourly_eur": None, "pricing_checked_at": None,
            "api_max": 2, "worker_instances": 1, "public_api": False, "google_client_ids": [], "google_web_client_id": "",
            "godot_sha256": PIN, "gcloud": ["gcloud"], "docker": ["docker"]}
        validate(config)
        write_json(args.config, config)
        print("Staging configuration created; review project, tools, pricing, expiry and visibility before apply")
        return
    config = json.loads(args.config.read_text())
    if args.action in ("plan", "deploy"):
        validate(config, apply=args.apply)
    elif args.action in ("smoke", "cleanup", "watch"):
        # Expired staging must remain inspectable/removable. Retain all other structural validation.
        validate(config, now=stamp(config["expires_at"]) - timedelta(seconds=1))
    directory = args.config.parent / ("rendered-" + config["owner"])
    if args.action in ("cleanup", "watch") and not args.apply:
        preview = {"action": args.action, "project": config["project"], "owner": config["owner"],
            "required_labels": labels(config), "expires_at": config["expires_at"], "removals": removal_commands(config)}
        write_json(directory / "cleanup-plan.json", preview)
        print(json.dumps(preview, indent=2))
        return
    if args.action == "plan" or not args.apply:
        print(json.dumps(plan(config, directory), indent=2))
        return
    if args.confirm_owner != config["owner"]:
        raise ValueError("Apply must confirm this exact reviewed staging owner ID")
    if config.get("example"):
        raise ValueError("Example configurations never apply cloud mutations")
    staging = Staging(config, directory)
    directory.mkdir(parents=True, exist_ok=True)
    if args.action == "deploy":
        staging.preflight()
        staging.provision()
        image = staging.build()
        print(staging.deploy(image))
        staging.smoke()
    elif args.action == "smoke":
        print(json.dumps(staging.smoke()))
    elif args.action == "cleanup":
        print(json.dumps(staging.cleanup()))
    elif args.action == "watch":
        while utc() < stamp(config["expires_at"]):
            time.sleep(max(0, min(60, (stamp(config["expires_at"]) - utc()).total_seconds())))
        print(json.dumps(staging.cleanup()))


if __name__ == "__main__":
    main()
