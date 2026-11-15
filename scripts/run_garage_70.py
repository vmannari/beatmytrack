"""Offline Garage geometry budget and native comparison runner."""
import run_garage_first_entry as runner

runner.OUT = runner.ROOT / "build/garage-70-2026-11-14"
runner.DEFAULT_SCRIPT = "res://tests/test_garage_environment_budget.gd"

if __name__ == "__main__":
    raise SystemExit(runner.main())
