"""Offline Garage second reduction: bounded native/headless probes."""
import run_garage_first_entry as runner

runner.OUT = runner.ROOT / "build/garage-25-2026-11-15"
runner.DEFAULT_SCRIPT = "res://tests/test_garage_environment_budget.gd"

if __name__ == "__main__":
    raise SystemExit(runner.main())
