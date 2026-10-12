"""A replay-compatible server must also expose the results API used by clients."""
import pytest
from fastapi import FastAPI

from bmt_backend.cloud_smoke import check_comparison_route


def test_current_app_exposes_comparison_contract(auth_app):
    check_comparison_route(auth_app)


def test_missing_comparison_route_fails_deployment_check():
    with pytest.raises(RuntimeError, match="Results comparison API"):
        check_comparison_route(FastAPI())


def test_old_comparison_contract_fails_deployment_check():
    app = FastAPI()

    @app.get("/v1/track-versions/{version_id}/results-comparison")
    def old_comparison(version_id: str):
        return {}

    with pytest.raises(RuntimeError, match="Results comparison API"):
        check_comparison_route(app)
