"""Website publication must preserve the deployed backend and account erasure."""
import importlib.util
import json
import sys
from pathlib import Path

import pytest

DIRECTORY = Path(__file__).parents[1] / "deploy/gcp"
sys.path.insert(0, str(DIRECTORY))
spec = importlib.util.spec_from_file_location("website_publisher", DIRECTORY / "public_website.py")
publisher = importlib.util.module_from_spec(spec)
spec.loader.exec_module(publisher)
sys.path.remove(str(DIRECTORY))


def test_home_registration_keeps_other_routes_and_application_code():
    original = ('from . import (\n        privacy_pages,\n        tracks,\n)\n'
                'if public:\n        app.include_router(privacy_pages.router)\n'
                '        app.include_router(tracks.router)\n')
    result = publisher.add_home_router(original)
    assert result.replace("        public_pages,\n", "").replace(
        "        app.include_router(public_pages.router)\n", "") == original
    with pytest.raises(RuntimeError, match="anchor"):
        publisher.add_home_router(result)


def test_disclosure_patch_preserves_the_erasure_implementation():
    erasure = ('def finish_cleanup(app, session, job):\n'
               '    # Deliberately differs from the workspace; retain live behaviour.\n'
               '    return deployed_erasure(app, session, job)\n')
    original = ('def receipt(job):\n    return job\n\n'
                'def web_session(body: WebToken, session=Depends(get_session)):\n'
                '    player = lookup(body)\n'
                '    return {"status": "ready", "display_name": player.display_name}\n\n' + erasure)
    result = publisher.add_deletion_preview(original)
    assert erasure in result
    assert 'request.app.state.settings, player_id' in result
    assert '@router.get("/v1/privacy/deletion-preview")' in result
    assert 'def receipt(job):\n    return job\n' in result
    with pytest.raises(RuntimeError, match="anchor"):
        publisher.add_deletion_preview(result)


def test_runtime_invariant_ignores_image_but_detects_environment_changes():
    original = {"spec": {"template": {"metadata": {"name": "old", "annotations": {"minScale": "1"}},
        "spec": {"serviceAccountName": "runtime", "containers": [{"image": "old", "env": [
            {"name": "BMT_PUBLIC_BASE_URL", "value": "https://game.example"}]}]}}}}
    newer = json.loads(json.dumps(original))
    newer["spec"]["template"]["metadata"]["name"] = "new"
    newer["spec"]["template"]["spec"]["containers"][0]["image"] = "new"
    assert publisher.WebsitePublisher.invariant_settings(original) == publisher.WebsitePublisher.invariant_settings(newer)
    newer["spec"]["template"]["spec"]["containers"][0]["env"][0]["value"] = "https://wrong.example"
    assert publisher.WebsitePublisher.invariant_settings(original) != publisher.WebsitePublisher.invariant_settings(newer)


def test_changed_frozen_overlay_cannot_be_published(tmp_path):
    config = {"retain_data": True, "project": "fixture-project", "region": "europe-west1", "owner": "a" * 32}
    deployment = publisher.WebsitePublisher(config)
    (tmp_path / "overlay/bmt_backend").mkdir(parents=True)
    (tmp_path / "baseline/bmt_backend").mkdir(parents=True)
    write = publisher.write
    expected = publisher.hashlib.sha256(b"approved").hexdigest()
    receipt = {"service": deployment.service, "image_tag": deployment.registry + "website:page-fixture",
               "overlay_sha256": {"public_pages.py": expected}}
    write(tmp_path / "image.json", receipt)
    for directory in ("overlay", "baseline"):
        (tmp_path / directory / "bmt_backend/public_pages.py").write_bytes(b"approved")
    assert deployment.validate_frozen(tmp_path) == receipt
    (tmp_path / "overlay/bmt_backend/public_pages.py").write_bytes(b"changed")
    with pytest.raises(RuntimeError, match="Frozen release source changed"):
        deployment.validate_frozen(tmp_path)
