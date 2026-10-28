"""Recovery preconditions and managed-identity provisioning without cloud mutations."""

import importlib.util
import json
from pathlib import Path

import pytest

path = Path(__file__).parents[1] / "deploy/gcp/studio_recovery.py"
spec = importlib.util.spec_from_file_location("studio_recovery_test", path)
recovery = importlib.util.module_from_spec(spec)
spec.loader.exec_module(recovery)


class FakeCloud(recovery.Cloud):
    def __init__(self):
        super().__init__({"project": "fixture-project", "region": "europe-west1", "owner": "a" * 32})
        self.calls = []
        self.existing_provider = None

    def inspect(self):
        return {"api_public_config": {"BMT_GOOGLE_WEB_CLIENT_ID": "game-client"}}

    def gcloud(self, *args):
        self.calls.append(args)
        return ""

    def request(self, method, url, body=None, **kwargs):
        self.calls.append((method, url, body))
        if method == "GET" and url.endswith("/config"):
            return {"authorizedDomains": ["retained.example"]}
        if method == "GET" and "/tenants?" in url:
            return {"tenants": []}
        if method == "POST" and url.endswith("/tenants"):
            return {"name": "projects/fixture-project/tenants/studio-tenant"}
        if method == "GET" and url.endswith("/google.com"):
            return self.existing_provider
        return {}


def credentials(tmp_path, **updates):
    web = {"project_id": "fixture-project", "client_id": "staff-client", "client_secret": "fixture-not-a-real-secret",
        "redirect_uris": ["https://fixture-project.firebaseapp.com/__/auth/handler"], **updates}
    output = tmp_path / "web.json"
    output.write_text(json.dumps({"web": web}))
    return output


@pytest.mark.parametrize("update", [{"client_secret": ""}, {"client_id": "game-client"},
    {"project_id": "another-project"}, {"redirect_uris": []}])
def test_invalid_oauth_input_causes_no_cloud_mutation(tmp_path, update):
    cloud = FakeCloud()
    with pytest.raises(ValueError):
        cloud.prepare_identity(credentials(tmp_path, **update))
    assert cloud.calls == []


def test_isolated_google_tenant_enables_only_totp_and_retains_existing_domains(tmp_path):
    cloud = FakeCloud()
    result = cloud.prepare_identity(credentials(tmp_path))
    assert result["tenant_id"] == "studio-tenant"
    assert "fixture-not-a-real-secret" not in json.dumps(result)
    changes = [call for call in cloud.calls if call[0] in ("POST", "PATCH")]
    config = next(call for call in changes if "/config?" in call[1])
    assert config[2]["multiTenant"] == {"allowTenants": True}
    assert "retained.example" in config[2]["authorizedDomains"]
    tenant = next(call for call in changes if call[1].endswith("/tenants"))
    assert tenant[2]["allowPasswordSignup"] is False
    assert tenant[2]["enableAnonymousUser"] is False
    assert tenant[2]["mfaConfig"]["providerConfigs"] == [
        {"state": "ENABLED", "totpProviderConfig": {"adjacentIntervals": 1}}]
    assert not any("PHONE_SMS" in str(call) for call in changes)
    assert not any(call[0] in ("run", "sql", "iam") for call in cloud.calls)


def test_does_not_replace_an_existing_different_studio_provider(tmp_path):
    cloud = FakeCloud()
    cloud.existing_provider = {"clientId": "different-staff-client"}
    with pytest.raises(RuntimeError, match="different OAuth client"):
        cloud.prepare_identity(credentials(tmp_path))
    assert not any(call[0] == "PATCH" and "/google.com?" in call[1] for call in cloud.calls)


def test_existing_identity_output_is_never_overwritten(tmp_path):
    output = tmp_path / "identity.json"
    output.write_text("preserve")
    cloud = FakeCloud()
    with pytest.raises(ValueError, match="already exists"):
        cloud.save_identity(tmp_path / "missing.json", "fixture@example.com", output)
    assert output.read_text() == "preserve" and cloud.calls == []


def test_userinfo_does_not_send_a_cloud_quota_project_header():
    cloud = FakeCloud()
    calls = []
    cloud.gcloud = lambda *args: "owner@example.com"
    def userinfo(method, url, body=None, **kwargs):
        calls.append((method, url, kwargs))
        return {"email": "owner@example.com", "email_verified": True, "sub": "stable-owner-subject"}
    cloud.request = userinfo
    assert cloud.owner_identity("owner@example.com")["sub"] == "stable-owner-subject"
    assert calls == [("GET", "https://openidconnect.googleapis.com/v1/userinfo", {"quota_project": False})]


def test_missing_staff_runtime_gets_only_its_separate_documented_authority():
    cloud = FakeCloud()
    calls = []
    def gcloud(*args):
        calls.append(args)
        if args[:3] == ("iam", "service-accounts", "describe"):
            raise RuntimeError("NOT_FOUND: fixture staff account")
        return ""
    cloud.gcloud = gcloud
    staff = cloud.ensure_staff_authority()
    assert staff == "bmt-stg-aaaaaaaa-staff@fixture-project.iam.gserviceaccount.com"
    assert ("iam", "service-accounts", "create", "bmt-stg-aaaaaaaa-staff", "--display-name=BMT Studio staff") in calls
    grants = [call for call in calls if "add-iam-policy-binding" in call]
    assert len(grants) == 4
    assert {arg for call in grants for arg in call if arg.startswith("--role=")} == {
        "--role=roles/cloudsql.client", "--role=roles/secretmanager.secretAccessor",
        "--role=roles/storage.objectCreator", "--role=roles/storage.objectViewer"}
    assert all("--member=serviceAccount:" + staff in call for call in grants)
    assert any(call[:3] == ("secrets", "add-iam-policy-binding", "bmt-stg-aaaaaaaa-studio-db") for call in grants)
    assert not any("api-db" in str(call) or "admin-db" in str(call) or "worker-db" in str(call) for call in grants)
