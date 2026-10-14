"""A reviewable awards-only patch preserving concurrent creator/status changes."""
import difflib
import hashlib
import json
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
EVIDENCE = Path(__file__).resolve().parent
EXISTING = ["game/ui/weekly_rivalry_page.gd", "game/race/weekly_rivalry.gd", "game/core/app.gd",
    "game/backend/weekly_rivalry_client.gd", "backend/bmt_backend/rivalry.py",
    "docs/schemas/weekly-rivalry-v1.schema.json", "game/tests/test_weekly_rivalry.gd",
    "DEVELOPMENT_STATUS.md", "docs/PHASE_0_PLAN.md", "AGENTS.md"]
ADDED = ["game/ui/weekly_rivalry_finale.gd", "game/ui/weekly_rivalry_finale.gd.uid",
    "game/ui/rivalry_award_art.gd", "game/ui/rivalry_award_art.gd.uid",
    "game/ui/rivalry_victory_car.gd", "game/ui/rivalry_victory_car.gd.uid",
    "game/tests/test_rivalry_awards.gd", "game/tests/test_rivalry_awards.gd.uid",
    "backend/tests/test_rivalry_awards.py", "scripts/test_rivalry_awards_postgres.py", "docs/RIVALRY_AWARDS.md"]


def without_once(value, addition):
    if value.count(addition) != 1:
        raise RuntimeError("Expected one task addition; refusing to capture mixed work")
    return value.replace(addition, "", 1)


def main():
    chunks = []
    manifest = {"head": subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip(), "files": {}}
    for filename in EXISTING + ADDED:
        after = (ROOT / filename).read_text(encoding="utf-8")
        before = (EVIDENCE / "before" / filename.replace("/", "__")).read_text(encoding="utf-8") if filename in EXISTING else ""
        base = "saved pre-task version"
        if filename in ["DEVELOPMENT_STATUS.md", "docs/PHASE_0_PLAN.md"]:
            before = without_once(after, (EVIDENCE / "status-entry.txt").read_text(encoding="utf-8"))
            base = "current content minus the task status entry; concurrent entries preserved"
        elif filename == "AGENTS.md":
            before = without_once(after, (EVIDENCE / "agents-entry.txt").read_text(encoding="utf-8"))
            base = "current content minus the task override; concurrent instructions preserved"
        elif filename == "game/core/app.gd":
            before = without_once(after, "\tpage.finale_livery = VehicleLivery.for_car(records.settings,rivalry.model.vehicle_id)\n\tpage.finale_condition = VehicleCondition.read(records,rivalry.model.vehicle_id)\n")
            before = without_once(before, "\tpage.share_requested.connect(_share_rivalry_results)\n")
            start = before.index("\nfunc _share_rivalry_results() -> void:")
            end = before.index("\nfunc _remember_rivalry_standings", start)
            before = before[:start] + before[end:]
            base = "current content minus the three owned integration additions; concurrent creator changes preserved"
        if before == after:
            continue
        header = f"diff --git a/{filename} b/{filename}\n"
        if filename in ADDED:
            header += "new file mode 100644\n"
        chunks.append(header + "".join(difflib.unified_diff(before.splitlines(True), after.splitlines(True),
            fromfile="a/" + filename if before else "/dev/null", tofile="b/" + filename)))
        manifest["files"][filename] = {"base": base, "before_sha256_lf": hashlib.sha256(before.encode()).hexdigest(),
            "after_sha256_lf": hashlib.sha256(after.encode()).hexdigest()}
    (EVIDENCE / "scoped-change.patch").write_text("".join(chunks), encoding="utf-8", newline="\n")
    (EVIDENCE / "checkpoint.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    print(f"Awards-only checkpoint: {len(manifest['files'])} files")


if __name__ == "__main__":
    main()
