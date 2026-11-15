"""Second Garage loading pass; reuse isolated storage and crash-safe probes."""
import run_garage_first_entry as runner

runner.OUT = runner.ROOT / "build/garage-fast-entry-2026-11-14"
runner.DEFAULT_SCRIPT = "res://tests/profile_garage_fast_entry.gd"

if __name__ == "__main__":
    raise SystemExit(runner.main())
