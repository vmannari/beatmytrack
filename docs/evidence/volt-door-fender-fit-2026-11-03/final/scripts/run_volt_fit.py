"""Use the isolated Volt runner while retaining this correction's own evidence."""
import sys
import run_volt_body_refinement as runner

runner.EVIDENCE = runner.ROOT / "docs/evidence/volt-door-fender-fit-2026-11-03"
runner.PROFILE_ROOT = runner.ROOT / "build/volt-door-fender-fit"

if __name__ == "__main__":
    if len(sys.argv)>2 and sys.argv[2].endswith("test_volt_body_construction.gd"):
        if "--" not in sys.argv[3:]: sys.argv.append("--")
        sys.argv.append("--report=res://../docs/evidence/volt-door-fender-fit-2026-11-03/"+sys.argv[1]+".json")
    sys.exit(runner.main())
