"""Run only against the task-start source snapshot in an owned test schema."""
import sys
from concurrent.futures import ThreadPoolExecutor, TimeoutError
from dataclasses import replace

import pytest
from sqlalchemy import select

sys.path.insert(0, "/task/backend/tests")
from bmt_backend.telemetry_models import ProductState
from test_auth_postgres import google_request, postgres_auth  # noqa: F401
from test_product_analytics import body, observed


@pytest.mark.postgres
def test_original_global_summary_lock_blocks_ingestion(postgres_auth):  # noqa: F811
    app, client = postgres_auth
    app.state.settings = replace(app.state.settings, telemetry_enabled=True)
    signed = client.post("/v1/auth/google", json=google_request(app, client, "original-global-lock")).json()
    headers = {"Authorization": "Bearer " + signed["access_token"]}
    assert client.post("/v1/privacy/preferences", headers=headers, json={"analytics_enabled": True}).status_code == 200
    with ThreadPoolExecutor(max_workers=1) as pool, app.state.session_factory() as locked:
        locked.scalar(select(ProductState).where(ProductState.id == 1).with_for_update())
        future = pool.submit(client.post, "/v1/telemetry/batches", headers=headers, json=body([observed("menu_ready")]))
        try:
            with pytest.raises(TimeoutError):
                future.result(timeout=0.3)
        finally:
            locked.rollback()
        assert future.result(timeout=5).status_code == 200
