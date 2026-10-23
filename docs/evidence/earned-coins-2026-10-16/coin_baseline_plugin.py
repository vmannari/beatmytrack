"""Diagnostic only: remove the new worker reward hooks for baseline comparison."""
def pytest_configure(config):
    import bmt_backend.economy as economy
    economy.previous_bests = lambda session, run: (0, 0)
    economy.accept_verified = lambda session, run, previous: None
