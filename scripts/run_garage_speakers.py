"""Offline checks for the Garage speaker restoration."""
import run_garage_first_entry as runner

runner.OUT = runner.ROOT / "build/garage-speakers-fix-2026-11-15"
runner.DEFAULT_SCRIPT = "res://tests/test_garage_speakers.gd"

if __name__ == "__main__":
    raise SystemExit(runner.main())
