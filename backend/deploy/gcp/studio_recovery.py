"""Inspect or explicitly provision the isolated Studio identity tenant.

OAuth client secrets are read only from a local downloaded credentials JSON, never
from command arguments or stdout. Explicit deployment creates only private Studio;
the existing game API, worker and database schema are never updated.
"""

import argparse
import difflib
import hashlib
import io
import json
import os
import subprocess
import tarfile
import tempfile
import time
from pathlib import Path

import requests

ROOT = Path(__file__).resolve().parents[3]
IDENTITY = "https://identitytoolkit.googleapis.com"
RUNTIME_FILES = ("admin.py", "admin_ui/app.js", "admin_ui/index.html", "app.py", "config.py",
    "studio_access.py", "studio_settings.py", "studio_identity.py", "admin_ui/signin.js", "http_server.py",
    "studio_reporting.py", "studio_reporting_admin.py", "studio_analysis.py", "studio_exports.py",
    "studio_release_reports.py")


class Cloud:
    def __init__(self, config):
        self.config = config
        self.project = config["project"]
        self.region = config["region"]
        self.base = "bmt-stg-" + config["owner"][:8]
        self.ca = ROOT / ".tools/gcp-staging/windows-trust.pem"

    def gcloud(self, *args):
        env = dict(os.environ, CLOUDSDK_CORE_CUSTOM_CA_CERTS_FILE=str(self.ca))
        result = subprocess.run(["gcloud.cmd", *args, "--project=" + self.project, "--quiet"],
            env=env, capture_output=True, text=True, check=False)
        if result.returncode:
            # Commands here contain resource identifiers, never credential values.
            raise RuntimeError(result.stderr.strip())
        return result.stdout.strip()

    def request(self, method, url, body=None, *, missing=False, quota_project=True):
        token = self.gcloud("auth", "print-access-token")
        response = requests.request(method, url, json=body, timeout=40, verify=str(self.ca),
            headers={"Authorization": "Bearer " + token,
                     **({"X-Goog-User-Project": self.project} if quota_project else {})})
        if missing and response.status_code == 404:
            return None
        if not response.ok:
            # Do not echo provider bodies: a provider can include input credentials.
            try:
                error = response.json().get("error", {})
                code = error.get("status", "UNKNOWN")
                reasons = [detail.get("reason", "") for detail in error.get("details", [])
                    if detail.get("@type", "").endswith("google.rpc.ErrorInfo")]
                if url.split("?")[0].endswith("/tenants"):
                    # This endpoint receives only the fixed tenant/MFA settings,
                    # never an OAuth secret, token body or user identifier.
                    reasons.append(error.get("message", "")[:600])
            except ValueError:
                code = "UNREADABLE"
                reasons = []
            raise RuntimeError(f"Cloud request failed: {method} {url.split('?')[0]} HTTP{response.status_code} {code} {','.join(reasons)}")
        return response.json() if response.content else {}

    def inspect(self):
        api = json.loads(self.gcloud("run", "services", "describe", self.base + "-api",
            "--region=" + self.region, "--format=json"))
        template = api.get("template") or api.get("spec", {}).get("template", {}).get("spec", {})
        containers = template.get("containers", [])
        if len(containers) != 1:
            raise RuntimeError("Expected exactly one API container")
        container = containers[0]
        env = {item["name"]: item.get("value", "<secret binding>") for item in container.get("env", [])}
        services = json.loads(self.gcloud("run", "services", "list", "--region=" + self.region, "--format=json"))
        public = {key: value for key, value in env.items() if key in (
            "BMT_ENVIRONMENT", "BMT_WORKLOAD_ROLE", "BMT_PUBLIC_BASE_URL", "BMT_GOOGLE_WEB_CLIENT_ID")}
        return {"api_image": container.get("image"), "api_revision": api.get("status", {}).get("latestReadyRevisionName"),
            "services": [service.get("name") or service.get("metadata", {}).get("name") for service in services],
            "api_public_config": public, "api_environment_names": sorted(env)}

    def build_image(self, destination):
        """Apply only this task's auth diff to the live image; preserve its schema and assets."""
        if destination.exists():
            raise ValueError("Use a new build directory; existing task artifacts are never overwritten")
        live = self.inspect()
        image = live["api_image"]
        registry = f"{self.region}-docker.pkg.dev/{self.project}/{self.base}-images/"
        if not image.startswith(registry) or "@sha256:" not in image:
            raise RuntimeError("Live API must use an immutable image in the owned registry")
        destination.mkdir(parents=True)
        baseline = destination / "baseline"
        baseline.mkdir()
        docker = self.config["docker"]
        source = subprocess.run([*docker, "run", "--rm", "--network=none", "--entrypoint=python", image,
            "-c", ("import sys,tarfile; t=tarfile.open(fileobj=sys.stdout.buffer,mode='w|');"
                   "t.add('/app/bmt_backend',arcname='bmt_backend');t.close()")], capture_output=True, check=True)
        with tarfile.open(fileobj=io.BytesIO(source.stdout)) as archive:
            members = archive.getmembers()
            for member in members:
                path = (baseline / member.name).resolve()
                if not path.is_relative_to(baseline.resolve()) or not (member.isfile() or member.isdir()):
                    raise RuntimeError("Unexpected path/type in image source archive")
            # Python 3.10 has no extraction filters; paths and member types above
            # are checked explicitly, and links/devices are never extracted.
            archive.extractall(baseline, members=members)
        changes = []
        for name in RUNTIME_FILES:
            relative = "backend/bmt_backend/" + name
            original = subprocess.run(["git", "show", "HEAD:" + relative], cwd=ROOT,
                capture_output=True, check=False)
            before = (original.stdout.decode("utf-8").splitlines(keepends=True)
                if original.returncode == 0 and (baseline / "bmt_backend" / name).exists() else [])
            after = (ROOT / relative).read_text(encoding="utf-8").splitlines(keepends=True)
            changes.extend(difflib.unified_diff(before, after, fromfile="a/bmt_backend/" + name,
                tofile="b/bmt_backend/" + name, n=2))
        patch = destination / "signin.patch"
        patch.write_text("".join(changes), encoding="utf-8", newline="\n")
        directory = baseline.relative_to(ROOT).as_posix()
        for check in (True, False):
            subprocess.run(["git", "apply", *(["--check"] if check else []),
                "--directory=" + directory, str(patch)], cwd=ROOT, check=True)
        overlay = destination / "overlay/bmt_backend"
        import shutil
        for name in RUNTIME_FILES:
            target = overlay / name
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(baseline / "bmt_backend" / name, target)
        fingerprint = hashlib.sha256(image.encode())
        hashes = {}
        for name in RUNTIME_FILES:
            value = (overlay / name).read_bytes()
            fingerprint.update(name.encode() + b"\0" + value)
            hashes[name] = hashlib.sha256(value).hexdigest()
        tag = registry + "studio:signin-" + fingerprint.hexdigest()[:20]
        (destination / "Dockerfile").write_text("FROM " + image
            + "\nCOPY overlay/bmt_backend/ /app/bmt_backend/\n"
            + "RUN python -c \"from bmt_backend.studio_identity import StudioIdentityVerifier;"
            + "from bmt_backend.http_server import BoundedH11Protocol\"\n", encoding="utf-8")
        subprocess.run([*docker, "build", "--platform=linux/amd64", "--tag=" + tag,
            destination.relative_to(ROOT).as_posix()], cwd=ROOT, check=True)
        receipt = {"base_image": image, "base_api_revision": live["api_revision"],
            "image_tag": tag, "source_sha256": hashes, "database_migration": False,
            "api_updated": False, "worker_updated": False}
        (destination / "image.json").write_text(json.dumps(receipt, indent=2), encoding="utf-8")
        return receipt

    def prepare_identity(self, credentials):
        raw = json.loads(credentials.read_text(encoding="utf-8-sig"))
        web = raw.get("web", {})
        if not web.get("client_id") or not web.get("client_secret") or web.get("project_id") != self.project:
            raise ValueError("Expected a downloaded Google Web OAuth client for the staging project")
        handler = f"https://{self.project}.firebaseapp.com/__/auth/handler"
        if handler not in web.get("redirect_uris", []):
            raise ValueError("OAuth client needs redirect URI " + handler)
        live = self.inspect()
        if live["api_public_config"].get("BMT_GOOGLE_WEB_CLIENT_ID") == web["client_id"]:
            raise ValueError("Studio needs a dedicated OAuth client; the game client must remain unchanged")
        self.gcloud("services", "enable", "identitytoolkit.googleapis.com", "securetoken.googleapis.com")
        config_url = f"{IDENTITY}/admin/v2/projects/{self.project}/config"
        project_config = self.request("GET", config_url, missing=True)
        if project_config is None:
            self.request("POST", f"{IDENTITY}/v2/projects/{self.project}/identityPlatform:initializeAuth", {})
            project_config = self.request("GET", config_url)
        domains = sorted(set(project_config.get("authorizedDomains", [])) |
            {"localhost", "127.0.0.1", self.project + ".firebaseapp.com"})
        self.request("PATCH", config_url + "?updateMask=multiTenant.allowTenants,authorizedDomains", {
            "multiTenant": {"allowTenants": True}, "authorizedDomains": domains})
        tenants_url = f"{IDENTITY}/v2/projects/{self.project}/tenants"
        tenants = self.request("GET", tenants_url + "?pageSize=1000").get("tenants", [])
        matches = [tenant for tenant in tenants if tenant.get("displayName") == "BMT-Studio"]
        if len(matches) > 1:
            raise RuntimeError("Ambiguous Studio tenants; no changes made to existing tenants")
        tenant = matches[0] if matches else self.request("POST", tenants_url, {
            "displayName": "BMT-Studio", "allowPasswordSignup": False,
            "enableAnonymousUser": False,
            "mfaConfig": {"state": "ENABLED", "providerConfigs": [{"state": "ENABLED",
                "totpProviderConfig": {"adjacentIntervals": 1}}]}})
        tenant_id = tenant["name"].rsplit("/", 1)[-1]
        tenant_url = f"{tenants_url}/{tenant_id}"
        self.request("PATCH", tenant_url + "?updateMask=mfaConfig,allowPasswordSignup,enableAnonymousUser", {
            "allowPasswordSignup": False, "enableAnonymousUser": False,
            "mfaConfig": {"state": "ENABLED", "providerConfigs": [{"state": "ENABLED",
                "totpProviderConfig": {"adjacentIntervals": 1}}]}})
        provider_url = tenant_url + "/defaultSupportedIdpConfigs/google.com"
        provider = self.request("GET", provider_url, missing=True)
        payload = {"enabled": True, "clientId": web["client_id"], "clientSecret": web["client_secret"]}
        if provider:
            if provider.get("clientId") != web["client_id"]:
                raise RuntimeError("Existing Studio provider uses a different OAuth client; refusing replacement")
            self.request("PATCH", provider_url + "?updateMask=enabled,clientId,clientSecret", payload)
        else:
            self.request("POST", tenant_url + "/defaultSupportedIdpConfigs?idpId=google.com", payload)
        return {"project": self.project, "tenant_id": tenant_id, "auth_domain": self.project + ".firebaseapp.com",
            "mfa": "totp", "provider": "google.com", "oauth_client_id": web["client_id"]}

    def owner_identity(self, expected_email):
        account = self.gcloud("auth", "list", "--filter=status:ACTIVE", "--format=value(account)")
        if account.casefold() != expected_email.casefold():
            raise ValueError("Active Google Cloud account differs from the requested Studio owner")
        owner = self.request("GET", "https://openidconnect.googleapis.com/v1/userinfo", quota_project=False)
        if (owner.get("email", "").casefold() != expected_email.casefold()
                or owner.get("email_verified") is not True or not owner.get("sub")):
            raise ValueError("Google did not verify the requested owner identity")
        return owner

    def browser_key(self):
        self.gcloud("services", "enable", "apikeys.googleapis.com")
        number = self.gcloud("projects", "describe", self.project, "--format=value(projectNumber)")
        url = f"https://apikeys.googleapis.com/v2/projects/{number}/locations/global/keys/bmt-studio-browser"
        restrictions = {"browserKeyRestrictions": {"allowedReferrers": [
            "http://localhost:8182/*", "http://127.0.0.1:8182/*", f"https://{self.project}.firebaseapp.com/*"]},
            "apiTargets": [{"service": "identitytoolkit.googleapis.com"}, {"service": "securetoken.googleapis.com"}]}
        key = self.request("GET", url, missing=True)
        if key is None:
            operation = self.request("POST", url.rsplit("/", 1)[0] + "?keyId=bmt-studio-browser", {
                "displayName": "BMT Studio browser", "restrictions": restrictions})
            for _ in range(30):
                if operation.get("done"):
                    break
                time.sleep(1)
                operation = self.request("GET", "https://apikeys.googleapis.com/v2/" + operation["name"])
            if not operation.get("done") or operation.get("error"):
                raise RuntimeError("Studio browser key creation has not completed successfully")
        elif key.get("restrictions") != restrictions:
            raise RuntimeError("Existing Studio browser key restrictions differ; refusing to replace them")
        return self.request("GET", url + "/keyString")["keyString"]

    def save_identity(self, credentials, expected_email, destination):
        if destination.exists():
            raise ValueError("Identity output already exists; review it before reusing the provisioning step")
        owner = self.owner_identity(expected_email)
        identity = self.prepare_identity(credentials)
        key = self.browser_key()
        config = dict(self.config, admin_enabled=True, studio_identity_project=self.project,
            studio_identity_tenant=identity["tenant_id"], studio_identity_api_key=key,
            studio_identity_auth_domain=identity["auth_domain"], studio_identity_login_hint=owner["email"],
            studio_staff_audiences=[self.project],
            studio_staff_subjects={owner["sub"]: {"name": "Studio owner", "role": "owner"}})
        destination.parent.mkdir(parents=True, exist_ok=True)
        destination.write_text(json.dumps(config, indent=2), encoding="utf-8")
        return {**identity, "owner_email": owner["email"], "config_saved": str(destination)}

    def ensure_staff_authority(self):
        """Create only Studio's missing runtime identity and its documented grants."""
        name = self.base + "-staff"
        staff = name + "@" + self.project + ".iam.gserviceaccount.com"
        try:
            self.gcloud("iam", "service-accounts", "describe", staff, "--format=value(email)")
        except RuntimeError as exc:
            if "NOT_FOUND" not in str(exc):
                raise
            self.gcloud("iam", "service-accounts", "create", name, "--display-name=BMT Studio staff")
        member = "--member=serviceAccount:" + staff
        self.gcloud("projects", "add-iam-policy-binding", self.project, member,
            "--role=roles/cloudsql.client", "--condition=None")
        self.gcloud("secrets", "add-iam-policy-binding", self.base + "-studio-db", member,
            "--role=roles/secretmanager.secretAccessor", "--condition=None")
        bucket = "gs://bmt-stg-" + self.project[:23] + "-" + self.config["owner"][:8]
        for role in ("roles/storage.objectCreator", "roles/storage.objectViewer"):
            self.gcloud("storage", "buckets", "add-iam-policy-binding", bucket, member,
                "--role=" + role, "--condition=None")
        return staff

    def publish_image(self, image_receipt):
        receipt = json.loads(image_receipt.read_text())
        if self.inspect()["api_image"] != receipt["base_image"]:
            raise RuntimeError("API image changed since this Studio image was built")
        tag = receipt["image_tag"]
        prefix = f"{self.region}-docker.pkg.dev/{self.project}/{self.base}-images/studio:signin-"
        if not tag.startswith(prefix):
            raise ValueError("Studio image is outside the reviewed owned registry")
        private = Path(tempfile.mkdtemp(prefix="studio-docker-", dir=image_receipt.parent))
        try:
            docker = [*self.config["docker"], "--config=" + private.relative_to(ROOT).as_posix()]
            subprocess.run([*docker, "login", self.region + "-docker.pkg.dev", "--username=oauth2accesstoken",
                "--password-stdin"], cwd=ROOT, input=self.gcloud("auth", "print-access-token").encode(), check=True)
            subprocess.run([*docker, "push", "--quiet", tag], cwd=ROOT, check=True)
        finally:
            credential = private / "config.json"
            if credential.is_file():
                credential.unlink()
            private.rmdir()
        digest = self.gcloud("artifacts", "docker", "images", "describe", tag,
            "--format=value(image_summary.digest)")
        import re
        if not re.fullmatch(r"sha256:[0-9a-f]{64}", digest):
            raise RuntimeError("Registry did not return an immutable Studio digest")
        return tag.rsplit(":", 1)[0] + "@" + digest

    def prepare_reporting(self, image_receipt, identity_config):
        """One operator job; no primary/schema/API changes except the named reader grants."""
        identity = json.loads(identity_config.read_text())
        if identity.get("owner") != self.config["owner"] or identity.get("project") != self.project:
            raise ValueError("Reporting configuration ownership mismatch")
        secret = self.base + "-analysis-db"
        try:
            value = json.loads(self.gcloud("secrets", "describe", secret, "--format=json"))
            if value.get("labels", {}).get("bmt-owner") != self.config["owner"]:
                raise RuntimeError("Refusing an unowned reporting secret")
        except RuntimeError as exc:
            if "NOT_FOUND" not in str(exc):
                raise
            self.gcloud("secrets", "create", secret, "--replication-policy=automatic",
                "--labels=bmt-owner=" + self.config["owner"] + ",bmt-environment=staging")
        migrator = self.base + "-migrator@" + self.project + ".iam.gserviceaccount.com"
        staff = self.base + "-staff@" + self.project + ".iam.gserviceaccount.com"
        self.gcloud("secrets", "add-iam-policy-binding", secret, "--member=serviceAccount:" + migrator,
            "--role=roles/secretmanager.secretVersionAdder", "--condition=None")
        self.gcloud("secrets", "add-iam-policy-binding", secret, "--member=serviceAccount:" + staff,
            "--role=roles/secretmanager.secretAccessor", "--condition=None")
        image = self.publish_image(image_receipt)
        job = self.base + "-reporting-setup"
        self.gcloud("run", "jobs", "deploy", job, "--region=" + self.region, "--image=" + image,
            "--service-account=" + migrator,
            "--set-cloudsql-instances=" + self.project + ":" + self.region + ":" + self.base + "-db",
            "--set-secrets=BMT_DATABASE_URL=" + self.base + "-admin-db:1",
            "--set-env-vars=BMT_STAGING_OWNER=" + self.config["owner"]
                + ",BMT_REPORTING_SECRET=projects/" + self.project + "/secrets/" + secret,
            "--command=python", "--args=-m,bmt_backend.studio_reporting_admin",
            "--tasks=1", "--parallelism=1", "--max-retries=0", "--task-timeout=120s",
            "--cpu=1", "--memory=512Mi", "--labels=bmt-owner=" + self.config["owner"] + ",bmt-environment=staging")
        self.gcloud("run", "jobs", "execute", job, "--region=" + self.region, "--wait")
        version = self.gcloud("secrets", "versions", "list", secret, "--filter=state:ENABLED",
            "--sort-by=~createTime", "--limit=1", "--format=value(name)").rsplit("/", 1)[-1]
        if not version.isdigit():
            raise RuntimeError("Reporting job did not publish an enabled credential version")
        self.gcloud("secrets", "remove-iam-policy-binding", secret, "--member=serviceAccount:" + migrator,
            "--role=roles/secretmanager.secretVersionAdder", "--condition=None")
        backup = identity_config.with_name(identity_config.stem + ".before-shared.json")
        if not backup.exists():
            backup.write_bytes(identity_config.read_bytes())
        identity.update(studio_analysis_mode="shared_limited", studio_analysis_statement_timeout_ms=1500,
            studio_analysis_secret_version=version)
        temporary = identity_config.with_suffix(".tmp")
        temporary.write_text(json.dumps(identity, indent=2), encoding="utf-8")
        temporary.replace(identity_config)
        return {"mode": "shared_limited", "role": "bmt_studio_report", "max_days": 7,
            "sql_budget_ms": 1500, "concurrent_reports": 1, "secret_version": version,
            "new_database_instance": False, "schema_migration": False, "operator_job": job}

    def deploy(self, image_receipt, identity_config):
        """Deploy only the new private Studio service, using existing staff authority."""
        receipt = json.loads(image_receipt.read_text())
        identity = json.loads(identity_config.read_text())
        live = self.inspect()
        if live["api_image"] != receipt["base_image"]:
            raise RuntimeError("API image changed since this Studio image was built; rebuild against the current image")
        required = ("studio_identity_project", "studio_identity_tenant", "studio_identity_api_key",
            "studio_identity_auth_domain", "studio_identity_login_hint", "studio_staff_subjects")
        if (not all(identity.get(field) for field in required) or identity.get("project") != self.project
                or identity.get("owner") != self.config["owner"]
                or identity.get("studio_staff_audiences") != [self.project]):
            raise ValueError("Missing or mismatched private Studio identity configuration")
        if len(identity["studio_staff_subjects"]) != 1:
            raise ValueError("This restoration authorizes exactly one Studio owner")
        import staging
        # Never provision a shared authority fallback or read a database credential
        # into this tool. Staff gets only its dedicated secret and documented roles.
        self.gcloud("secrets", "describe", self.base + "-studio-db", "--format=value(name)")
        staff = self.ensure_staff_authority()
        image = self.publish_image(image_receipt)
        env = staging.environment(identity, "admin", live["api_public_config"]["BMT_PUBLIC_BASE_URL"])
        bindings = "BMT_DATABASE_URL=" + self.base + "-studio-db:1"
        if identity.get("studio_analysis_mode") == "shared_limited":
            version = identity.get("studio_analysis_secret_version", "")
            if not isinstance(version, str) or not version.isdigit():
                raise ValueError("Limited reporting requires a pinned dedicated credential version")
            bindings += ",BMT_STUDIO_ANALYSIS_DATABASE_URL=" + self.base + "-analysis-db:" + version
        env_file = image_receipt.parent / "studio-env.private.json"
        env_file.write_text(json.dumps(env, indent=2), encoding="utf-8")
        try:
            self.gcloud("run", "deploy", self.base + "-studio", "--region=" + self.region,
                "--image=" + image, "--service-account=" + staff,
                "--set-cloudsql-instances=" + self.project + ":" + self.region + ":" + self.base + "-db",
                "--set-secrets=" + bindings,
                "--env-vars-file=" + str(env_file), *staging.http_command("create_admin_app"),
                "--port=8080", "--concurrency=8", "--min=0", "--max=1", "--timeout=60s",
                "--cpu=1", "--memory=768Mi", "--ingress=all", "--no-allow-unauthenticated",
                "--labels=bmt-environment=staging,bmt-owner=" + self.config["owner"])
        finally:
            env_file.unlink()
        self.gcloud("run", "services", "add-iam-policy-binding", self.base + "-studio",
            "--region=" + self.region, "--member=user:" + identity["studio_identity_login_hint"],
            "--role=roles/run.invoker", "--condition=None")
        policy = json.loads(self.gcloud("run", "services", "get-iam-policy", self.base + "-studio",
            "--region=" + self.region, "--format=json"))
        if any(member in ("allUsers", "allAuthenticatedUsers") for binding in policy.get("bindings", [])
               for member in binding.get("members", [])):
            raise RuntimeError("Studio IAM unexpectedly includes a public principal; do not use the service")
        final = self.inspect()
        if final["api_image"] != live["api_image"] or final["api_revision"] != live["api_revision"]:
            raise RuntimeError("Concurrent API deployment detected; reconcile before Studio acceptance")
        result = {"service": self.base + "-studio", "image": image, "private_iam": True,
            "api_revision_unchanged": live["api_revision"], "database_migration": False}
        (image_receipt.parent / "deployment.json").write_text(json.dumps(result, indent=2), encoding="utf-8")
        return result

    def verify_studio(self, identity_config):
        identity = json.loads(identity_config.read_text())
        service = json.loads(self.gcloud("run", "services", "describe", self.base + "-studio",
            "--region=" + self.region, "--format=json"))
        url = service.get("uri") or service.get("status", {}).get("url", "")
        from urllib.parse import urlsplit
        parsed = urlsplit(url)
        if parsed.scheme != "https" or not parsed.hostname or not parsed.hostname.endswith(".run.app"):
            raise RuntimeError("Unexpected Studio service URL; credential forwarding refused")
        policy = json.loads(self.gcloud("run", "services", "get-iam-policy", self.base + "-studio",
            "--region=" + self.region, "--format=json"))
        if any(member in ("allUsers", "allAuthenticatedUsers") for binding in policy.get("bindings", [])
               for member in binding.get("members", [])):
            raise RuntimeError("Studio IAM includes a public principal")
        token = self.gcloud("auth", "print-identity-token")
        headers = {"X-Serverless-Authorization": "Bearer " + token}
        results = {}
        checks = (("/health", 200), ("/ready", 200), ("/admin", 200),
            ("/admin/assets/signin.js", 200), ("/v1/admin/auth/config", 200),
            ("/v1/admin/staff", 401), ("/v1/auth/google/challenge", 404))
        for path, expected in checks:
            response = requests.get(url + path, headers=headers, timeout=45, verify=str(self.ca))
            if response.status_code != expected:
                code = ""
                if response.headers.get("content-type", "").startswith("application/json"):
                    code = str(response.json().get("detail", ""))
                raise RuntimeError(f"Studio check {path} returned HTTP{response.status_code}, expected {expected}: {code}")
            if path == "/v1/admin/auth/config":
                config = response.json()
                if (not config.get("configured") or config.get("legacy_enabled")
                        or config.get("tenantId") != identity["studio_identity_tenant"]):
                    raise RuntimeError("Studio browser identity differs from the private deployment configuration")
                if identity.get("studio_analysis_mode") == "shared_limited":
                    policy = config.get("reporting", {})
                    if policy.get("mode") != "shared_limited" or policy.get("max_days") != 7 or policy.get("sql_budget_ms") != 1500:
                        raise RuntimeError("Studio limited reporting policy differs from the reviewed deployment")
            results[path] = response.status_code
        unauthenticated = requests.get(url + "/admin", timeout=30, verify=str(self.ca))
        if unauthenticated.status_code not in (401, 403):
            raise RuntimeError("Unauthenticated Cloud Run invocation was not denied")
        results["unauthenticated_cloud_invocation"] = unauthenticated.status_code
        invalid = requests.get(url + "/v1/admin/staff", timeout=30, verify=str(self.ca),
            headers={**headers, "Authorization": "Bearer invalid-staff-token-smoke-test"})
        if invalid.status_code != 401:
            raise RuntimeError("Unsigned application credential was not denied")
        results["invalid_application_credential"] = invalid.status_code
        return {"service": self.base + "-studio", "url": url, "checks": results,
            "real_owner_mfa_signin": "pending owner interaction", "api": self.inspect()["api_revision"]}

    def validate_reporting(self, image_receipt, identity_config):
        identity = json.loads(identity_config.read_text())
        deployed = json.loads((image_receipt.parent / "deployment.json").read_text())
        if deployed.get("service") != self.base + "-studio" or identity.get("studio_analysis_mode") != "shared_limited":
            raise ValueError("Limited reporting must be deployed before its live read check")
        version = identity.get("studio_analysis_secret_version", "")
        if not isinstance(version, str) or not version.isdigit():
            raise ValueError("A pinned reader credential is required")
        import staging
        env = staging.environment(identity, "admin", self.inspect()["api_public_config"]["BMT_PUBLIC_BASE_URL"])
        env_file = image_receipt.parent / "reporting-check.private.json"
        env_file.write_text(json.dumps(env, indent=2), encoding="utf-8")
        job = self.base + "-reporting-check"
        try:
            self.gcloud("run", "jobs", "deploy", job, "--region=" + self.region,
                "--image=" + deployed["image"],
                "--service-account=" + self.base + "-staff@" + self.project + ".iam.gserviceaccount.com",
                "--set-cloudsql-instances=" + self.project + ":" + self.region + ":" + self.base + "-db",
                "--set-secrets=BMT_DATABASE_URL=" + self.base + "-studio-db:1,BMT_STUDIO_ANALYSIS_DATABASE_URL="
                    + self.base + "-analysis-db:" + version,
                "--env-vars-file=" + str(env_file), "--command=python",
                "--args=-m,bmt_backend.studio_reporting_admin,--validate",
                "--tasks=1", "--parallelism=1", "--max-retries=0", "--task-timeout=120s",
                "--cpu=1", "--memory=512Mi", "--labels=bmt-owner=" + self.config["owner"] + ",bmt-environment=staging")
        finally:
            env_file.unlink()
        self.gcloud("run", "jobs", "execute", job, "--region=" + self.region, "--wait")
        return {"operator_job": job, "status": "succeeded", "http_authentication_modified": False,
                "database_instance_created": False, "schema_migration": False}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--config", type=Path, default=ROOT / ".tools/gcp-staging/config.json")
    parser.add_argument("--oauth-client", type=Path)
    parser.add_argument("--prepare-identity", action="store_true")
    parser.add_argument("--build-image", type=Path)
    parser.add_argument("--owner-email")
    parser.add_argument("--identity-config", type=Path)
    parser.add_argument("--deploy-image", type=Path)
    parser.add_argument("--verify", action="store_true")
    parser.add_argument("--prepare-reporting", type=Path, metavar="IMAGE_RECEIPT")
    parser.add_argument("--validate-reporting", type=Path, metavar="IMAGE_RECEIPT")
    parser.add_argument("--report", type=Path)
    args = parser.parse_args()
    cloud = Cloud(json.loads(args.config.read_text(encoding="utf-8-sig")))
    if sum(bool(value) for value in (args.build_image, args.prepare_identity, args.deploy_image,
                                     args.verify, args.prepare_reporting, args.validate_reporting)) > 1:
        parser.error("Build, identity provisioning and deployment are separate explicit steps")
    if args.build_image:
        if args.prepare_identity:
            parser.error("Build and identity provisioning are separate explicit steps")
        result = cloud.build_image(args.build_image.resolve())
    elif args.validate_reporting:
        if args.identity_config is None:
            parser.error("--validate-reporting requires --identity-config")
        result = cloud.validate_reporting(args.validate_reporting.resolve(), args.identity_config)
    elif args.prepare_reporting:
        if args.identity_config is None:
            parser.error("--prepare-reporting requires --identity-config")
        result = cloud.prepare_reporting(args.prepare_reporting.resolve(), args.identity_config)
    elif args.prepare_identity:
        if args.oauth_client is None or not args.owner_email or args.identity_config is None:
            parser.error("--prepare-identity requires --oauth-client, --owner-email and --identity-config output")
        result = cloud.save_identity(args.oauth_client, args.owner_email, args.identity_config)
    elif args.deploy_image:
        if args.identity_config is None:
            parser.error("--deploy-image requires --identity-config")
        result = cloud.deploy(args.deploy_image.resolve(), args.identity_config)
    elif args.verify:
        if args.identity_config is None:
            parser.error("--verify requires --identity-config")
        result = cloud.verify_studio(args.identity_config)
    else:
        result = cloud.inspect()
    rendered = json.dumps(result, indent=2)
    if args.report:
        args.report.parent.mkdir(parents=True, exist_ok=True)
        args.report.write_text(rendered, encoding="utf-8")
    print(rendered)


if __name__ == "__main__":
    main()
