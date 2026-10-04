"""Explicit development scope. Defaults always select the real population."""

from fastapi import HTTPException

from .track_models import digest


def require_enabled(request):
    settings = request.app.state.settings
    if not (
        settings.test_drivers_enabled and settings.environment == "development" and settings.dev_auth_enabled
    ):
        raise HTTPException(404, "TEST_DRIVERS_DISABLED")


def check_scope(request, enabled, player=None):
    if enabled:
        require_enabled(request)
    elif player is not None and player.is_test_driver:
        raise HTTPException(403, "TEST_DRIVER_REQUIRES_TEST_POPULATION")


def contract_scope(contract, enabled):
    return digest({"contract": contract, "test_population": True}) if enabled else contract
