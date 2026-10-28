"""Publish only the approved public website on the exact retained API image.

No full-workspace backend release, migration, IAM change, worker update or secret
change. Build/test a frozen overlay before --deploy. Existing runtime settings
and the previous revision remain available for rollback.
"""
import argparse
import hashlib
import io
import json
import re
import shutil
import subprocess
import tarfile
import tempfile
from pathlib import Path

import requests

from studio_recovery import Cloud, ROOT

COPY_EXISTING = ("privacy_pages.py", "privacy_ui/deletion.js", "privacy_ui/style.css")
COPY_NEW = ("public_pages.py", "privacy_deletion_preview.py")


def require(condition, description):
    if not condition:
        raise RuntimeError(description)


def write(path, value):
    path.write_text(json.dumps(value, indent=2) + "\n", encoding="utf-8")


def normalized(value):
    return value.replace(b"\r\n", b"\n")


def add_home_router(source):
    """Two additive registrations; retain every existing application behaviour."""
    require("        public_pages,\n" not in source, "Website registration anchor already patched")
    for before, after in (
        ("        privacy_pages,\n", "        privacy_pages,\n        public_pages,\n"),
        ("        app.include_router(privacy_pages.router)\n",
         "        app.include_router(privacy_pages.router)\n        app.include_router(public_pages.router)\n"),
    ):
        require(source.count(before) == 1, "Live app lacks an unambiguous website registration anchor")
        source = source.replace(before, after, 1)
    return source


def add_deletion_preview(source):
    """Add the read-only disclosure without replacing deployed erasure code."""
    replacements = (
        ("def receipt(job):\n",
         '@router.get("/v1/privacy/deletion-preview")\n'
         'def preview_deletion(request: Request, player=Depends(current_player), session=Depends(get_session)):\n'
         '    from .privacy_deletion_preview import deletion_preview\n'
         '    return deletion_preview(session, request.app.state.settings, player.id)\n\n\n'
         'def receipt(job):\n'),
        ('def web_session(body: WebToken, session=Depends(get_session)):\n',
         'def web_session(body: WebToken, request: Request, session=Depends(get_session)):\n'),
        ('    return {"status": "ready", "display_name": player.display_name}\n',
         '    from .privacy_deletion_preview import deletion_preview\n'
         '    return {"status": "ready", "display_name": player.display_name,\n'
         '            "deletion_preview": deletion_preview(session, request.app.state.settings, player_id)}\n'),
    )
    for before, after in replacements:
        require(source.count(before) == 1, "Live privacy source lacks an unambiguous disclosure anchor")
        source = source.replace(before, after, 1)
    return source


class WebsitePublisher:
    def __init__(self, config):
        require(config.get("retain_data") is True, "Expected the owned retained game environment")
        self.config, self.cloud = config, Cloud(config)
        self.service = self.cloud.base + "-api"
        self.registry = f"{self.cloud.region}-docker.pkg.dev/{self.cloud.project}/{self.cloud.base}-images/"

    def describe(self):
        value = json.loads(self.cloud.gcloud("run", "services", "describe", self.service,
            "--region=" + self.cloud.region, "--format=json"))
        require(value.get("metadata", {}).get("labels", {}).get("bmt-owner") == self.config["owner"],
                "Live API ownership mismatch")
        return value

    def identity(self, value):
        spec = value["spec"]["template"]["spec"]
        require(len(spec["containers"]) == 1, "Expected exactly one API container")
        container = spec["containers"][0]
        image = container["image"]
        require(image.startswith(self.registry) and "@sha256:" in image, "Expected an immutable owned image")
        environment = {item["name"]: item.get("value") for item in container.get("env", [])}
        url = value["status"]["url"]
        require(environment.get("BMT_WORKLOAD_ROLE") == "api", "Refusing to publish on a non-API workload")
        require(environment.get("BMT_PUBLIC_BASE_URL") == url, "Public origin does not match the live service")
        require(bool(environment.get("BMT_GOOGLE_WEB_CLIENT_ID")), "Existing Google web verification is missing")
        return {"service": self.service, "revision": value["status"]["latestReadyRevisionName"],
                "image": image, "url": url, "google_web_configured": True}

    def inspect(self):
        value = self.describe()
        identity = self.identity(value)
        policy = json.loads(self.cloud.gcloud("run", "services", "get-iam-policy", self.service,
            "--region=" + self.cloud.region, "--format=json"))
        public = any(item.get("role") == "roles/run.invoker" and "allUsers" in item.get("members", [])
                     for item in policy.get("bindings", []))
        return {**identity, "public_invocation": public}

    def prepare(self, destination):
        require(not destination.exists(), "Use a new frozen build directory; never overwrite a prepared release")
        service = self.describe()
        identity = self.identity(service)
        destination.mkdir(parents=True)
        write(destination / "service-before.private.json", service)
        baseline = destination / "baseline"
        baseline.mkdir()
        program = ("import sys,tarfile;t=tarfile.open(fileobj=sys.stdout.buffer,mode='w|');"
                   "t.add('/app/bmt_backend',arcname='bmt_backend');t.close()")
        archive = subprocess.run([*self.config["docker"], "run", "--rm", "--network=none",
            "--entrypoint=python", identity["image"], "-c", program], capture_output=True, check=True)
        with tarfile.open(fileobj=io.BytesIO(archive.stdout)) as source:
            members = source.getmembers()
            for member in members:
                path = (baseline / member.name).resolve()
                require(path.is_relative_to(baseline.resolve()) and (member.isfile() or member.isdir()),
                        "Unexpected archive member; refusing extraction")
            source.extractall(baseline, members=members)
        package = baseline / "bmt_backend"
        original_hashes = {path.relative_to(package).as_posix(): hashlib.sha256(path.read_bytes()).hexdigest()
            for path in package.rglob("*") if path.is_file() and "__pycache__" not in path.parts}
        app = package / "app.py"
        app.write_text(add_home_router(app.read_text(encoding="utf-8")), encoding="utf-8")
        privacy = package / "privacy.py"
        privacy.write_text(add_deletion_preview(privacy.read_text(encoding="utf-8")), encoding="utf-8")
        for name in COPY_EXISTING:
            # Current working changes in these files are the reviewed disclosure /
            # navigation additions. Require the deployed baseline to match HEAD,
            # so copying cannot silently include a backend compatibility change.
            committed = subprocess.run(["git", "show", "HEAD:backend/bmt_backend/" + name],
                cwd=ROOT, capture_output=True, check=True).stdout
            require(normalized((package / name).read_bytes()) == normalized(committed),
                    "Live source differs from the reviewed disclosure baseline: " + name)
            shutil.copyfile(ROOT / "backend/bmt_backend" / name, package / name)
        names = ["app.py", "privacy.py", *COPY_EXISTING, *COPY_NEW]
        for name in COPY_NEW:
            require(not (package / name).exists(), "New website module already exists in the deployed image")
            shutil.copyfile(ROOT / "backend/bmt_backend" / name, package / name)
        for path in sorted((ROOT / "backend/bmt_backend/public_ui").iterdir()):
            name = "public_ui/" + path.name
            require(path.is_file(), "Unexpected directory in public website assets")
            target = package / name
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(path, target)
            names.append(name)
        hashes = {}
        fingerprint = hashlib.sha256(identity["image"].encode())
        for name in names:
            value = (package / name).read_bytes()
            fingerprint.update(name.encode() + b"\0" + value)
            hashes[name] = hashlib.sha256(value).hexdigest()
            target = destination / "overlay/bmt_backend" / name
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(value)
        for name, old_hash in original_hashes.items():
            if name not in names:
                require(hashlib.sha256((package / name).read_bytes()).hexdigest() == old_hash,
                        "An unrelated deployed file changed: " + name)
        image_tag = self.registry + "website:page-" + fingerprint.hexdigest()[:20]
        (destination / "Dockerfile").write_text("FROM " + identity["image"]
            + "\nCOPY overlay/bmt_backend/ /app/bmt_backend/\n"
            + "RUN python -c \"from bmt_backend.public_pages import ASSETS,ROOT;"
              "from bmt_backend.privacy_deletion_preview import deletion_preview;"
              "assert all((ROOT/name).is_file() for name in ASSETS)\"\n", encoding="utf-8")
        receipt = {**identity, "image_tag": image_tag, "overlay_sha256": hashes,
                   "unchanged_baseline_files": len(original_hashes) - len(COPY_EXISTING) - 2,
                   "database_migration": False, "worker_updated": False, "iam_updated": False}
        write(destination / "image.json", receipt)
        return receipt

    def build(self, destination):
        receipt = self.validate_frozen(destination)
        subprocess.run([*self.config["docker"], "build", "--platform=linux/amd64",
            "--tag=" + receipt["image_tag"], destination.relative_to(ROOT).as_posix()], cwd=ROOT, check=True)
        return {"image_built": receipt["image_tag"], "overlay_files": len(receipt["overlay_sha256"])}

    def validate_frozen(self, destination):
        receipt = json.loads((destination / "image.json").read_text())
        require(receipt.get("service") == self.service, "Release service mismatch")
        require(receipt["image_tag"].startswith(self.registry + "website:page-"), "Release registry mismatch")
        for name, expected in receipt["overlay_sha256"].items():
            for folder in (destination / "overlay/bmt_backend", destination / "baseline/bmt_backend"):
                require(hashlib.sha256((folder / name).read_bytes()).hexdigest() == expected,
                        "Frozen release source changed: " + name)
        return receipt

    @staticmethod
    def invariant_settings(value):
        copy = json.loads(json.dumps(value["spec"]["template"]))
        copy.get("metadata", {}).pop("name", None)
        copy["spec"]["containers"][0].pop("image", None)
        return copy

    def deploy(self, destination):
        receipt = self.validate_frozen(destination)
        current = self.describe()
        identity = self.identity(current)
        require(identity["image"] == receipt["image"] and identity["revision"] == receipt["revision"],
                "Live API changed after this release was prepared")
        active = [item for item in current["status"].get("traffic", []) if item.get("percent", 0)]
        require(len(active) == 1 and active[0]["percent"] == 100
                and active[0].get("revisionName") == identity["revision"],
                "Expected one serving revision; preserve any existing split rollout")
        require(self.inspect()["public_invocation"], "API is not already public; no IAM changes are authorized")
        before = json.loads((destination / "service-before.private.json").read_text())
        require(self.invariant_settings(before) == self.invariant_settings(current),
                "Runtime settings changed since preparation")
        private = Path(tempfile.mkdtemp(prefix="website-docker-", dir=destination))
        try:
            docker = [*self.config["docker"], "--config=" + private.relative_to(ROOT).as_posix()]
            subprocess.run([*docker, "login", self.cloud.region + "-docker.pkg.dev", "--username=oauth2accesstoken",
                "--password-stdin"], cwd=ROOT, input=self.cloud.gcloud("auth", "print-access-token").encode(), check=True)
            subprocess.run([*docker, "push", "--quiet", receipt["image_tag"]], cwd=ROOT, check=True)
        finally:
            credential = private / "config.json"
            if credential.is_file():
                credential.unlink()
            private.rmdir()
        digest = self.cloud.gcloud("artifacts", "docker", "images", "describe", receipt["image_tag"],
                                   "--format=value(image_summary.digest)")
        require(re.fullmatch(r"sha256:[0-9a-f]{64}", digest), "Registry did not return an immutable digest")
        image = receipt["image_tag"].rsplit(":", 1)[0] + "@" + digest
        require(self.identity(self.describe()) == identity, "Live API changed during image publication")
        revision_suffix = "web-" + digest[7:19]
        # Image-only revision; keep traffic on the old revision until its tagged
        # candidate passes real HTTP checks. No SQL or worker rollout is needed.
        self.cloud.gcloud("run", "services", "update", self.service, "--region=" + self.cloud.region,
            "--image=" + image, "--revision-suffix=" + revision_suffix, "--no-traffic", "--tag=website-preview")
        candidate = self.describe()
        require(candidate["status"]["latestReadyRevisionName"] == self.service + "-" + revision_suffix,
                "The website candidate did not become ready")
        require(self.invariant_settings(candidate) == self.invariant_settings(current),
                "Image-only deployment unexpectedly changed runtime settings")
        new_revision = self.service + "-" + revision_suffix
        traffic = candidate["status"].get("traffic", [])
        candidate_url = next((item["url"] for item in traffic if item.get("tag") == "website-preview"), None)
        require(candidate_url, "Candidate URL is missing")
        write(destination / "deployment.json", {"image": image, "old_revision": identity["revision"],
              "new_revision": new_revision, "candidate_url": candidate_url, "url": identity["url"],
              "traffic_promoted": False, "database_migration": False})
        self.verify(candidate_url, destination / "candidate-http.json")
        self.cloud.gcloud("run", "services", "update-traffic", self.service, "--region=" + self.cloud.region,
                          "--to-revisions=" + new_revision + "=100")
        try:
            checks = self.verify(identity["url"], destination / "live-http.json")
        except Exception:
            self.cloud.gcloud("run", "services", "update-traffic", self.service, "--region=" + self.cloud.region,
                              "--to-revisions=" + identity["revision"] + "=100")
            deployed = json.loads((destination / "deployment.json").read_text())
            write(destination / "deployment.json", {**deployed, "rolled_back": True})
            raise
        deployed = json.loads((destination / "deployment.json").read_text())
        write(destination / "deployment.json", {**deployed, "traffic_promoted": True, "checks": checks})
        return {"url": identity["url"], "deletion_url": identity["url"] + "/account-deletion",
                "revision": new_revision, "image": image, "checks": len(checks)}

    def verify(self, origin, output):
        checks = []
        for path in ("/health", "/ready", "/", "/account-deletion", "/privacy", "/community-rules",
                     "/site/style-v1.css", "/site/forest-drive-v1.webp", "/privacy/deletion.js"):
            response = requests.get(origin + path, timeout=40, verify=str(self.cloud.ca))
            require(response.status_code == 200, "Public HTTP check failed: " + path + " " + str(response.status_code))
            if path == "/":
                require("FIND YOUR" in response.text and 'href="/account-deletion"' in response.text,
                        "Homepage content mismatch")
            if path == "/account-deletion":
                require('id="benefits"' in response.text and 'id="signin" disabled' not in response.text,
                        "Verified deletion disclosure is not configured")
            if path == "/privacy/deletion.js":
                require("benefitLines" in response.text, "Deletion script lacks the matching benefits disclosure")
            checks.append({"path": path, "status": response.status_code,
                           "body_sha256": hashlib.sha256(response.content).hexdigest()})
        write(output, checks)
        return checks


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--config", type=Path, default=ROOT / ".tools/gcp-staging/config.json")
    action = parser.add_mutually_exclusive_group()
    action.add_argument("--prepare", type=Path)
    action.add_argument("--build", type=Path)
    action.add_argument("--deploy", type=Path)
    arguments = parser.parse_args()
    publisher = WebsitePublisher(json.loads(arguments.config.read_text(encoding="utf-8-sig")))
    if arguments.prepare:
        result = publisher.prepare(arguments.prepare.resolve())
    elif arguments.build:
        result = publisher.build(arguments.build.resolve())
    elif arguments.deploy:
        result = publisher.deploy(arguments.deploy.resolve())
    else:
        result = publisher.inspect()
    print(json.dumps(result, indent=2))


if __name__ == "__main__":
    main()
