"""Passing finding probes confirm retained risks; not a clean-security gate."""
import importlib.util
from pathlib import Path
import sys
from types import SimpleNamespace

import pytest

ROOT=Path(__file__).resolve().parents[3]
sys.path.insert(0,str(ROOT/'backend'))
sys.path.insert(0,str(ROOT/'backend/tests'))
from conftest import auth_app, auth_client, sign_in  # noqa: E402,F401
from bmt_backend.config import Settings  # noqa: E402
from bmt_backend.verifier import GodotVerifier  # noqa: E402

spec=importlib.util.spec_from_file_location('prior_review',ROOT/'docs/evidence/security-review-2026-10-24/test_review_probes.py')
prior=importlib.util.module_from_spec(spec)
spec.loader.exec_module(prior)

def test_sec01_nonphysical_current_trajectory_is_still_accepted():
    geometry,proof,ticks=prior.square()
    settings=SimpleNamespace(godot_bin='',game_project=str(ROOT/'game'),verifier_timeout_seconds=90,persistent_verifier=False)
    verifier=GodotVerifier(settings)
    try:
        result=verifier.verify_run(None,{'schema':'bmt-trajectory-v1','input_count':ticks,'race_proof':proof},'compact',geometry=geometry)
        assert result['verification_method']=='trajectory-v1'
        assert result['time_ticks']==879 and len(result['lap_ticks'])==5
    finally:verifier.close()

def test_sec02_incident_claim_still_controls_clean_result():
    prior.test_finding_s02_incident_free_is_controlled_by_the_submitter()

def test_sec05_deletion_still_accepts_normal_bearer(auth_client,sign_in):
    prior.test_finding_s05_normal_bearer_can_permanently_delete_without_recent_google_proof(auth_client,sign_in)

@pytest.mark.parametrize('environment',['prod','Production','staging'])
def test_rejected_candidate_invalid_environment_cannot_bypass_guards(environment):
    with pytest.raises(ValueError,match='Invalid BMT_ENVIRONMENT'):
        Settings(environment=environment,studio_legacy_keys_enabled=True,admin_owner_key='fixture-'*8)
