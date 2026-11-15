"""Run isolated offline checks for the simplified Garage."""
import run_garage_first_entry as runner

runner.OUT = runner.ROOT / "build/garage-simplified-apply-2026-11-15"
runner.DEFAULT_SCRIPT = "res://tests/test_garage_environment_budget.gd"

if __name__ == "__main__":
    raise SystemExit(runner.main())
