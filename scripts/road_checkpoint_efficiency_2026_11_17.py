"""Private profiling and qualification of equivalent road/checkpoint algorithms."""
import sys
import loading_half_review_2026_11_17 as base

base.WORK = base.ROOT / "build/road-checkpoint-efficiency-2026-11-17"
base.PROJECT = base.WORK / "snapshot/game"
base.OUT = base.ROOT / "docs/evidence/road-checkpoint-efficiency-2026-11-17"
base.runner.PROJECT = base.PROJECT
base.runner.OUT = base.OUT

if __name__ == "__main__":
    if "--live" in sys.argv:
        sys.argv.remove("--live")
        base.PROJECT = base.ROOT / "game"
        base.runner.PROJECT = base.PROJECT
    if sys.argv[1:] == ["prepare"]:
        base.prepare()
    else:
        assert base.PROJECT.is_dir()
        raise SystemExit(base.runner.main())
