"""Build a task-only patch without staging the shared working tree."""
from pathlib import Path
import difflib
import hashlib
import json

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]

def swap(text, old, new):
    assert text.count(old) == 1, old
    return text.replace(old, new)

files = [
    "game/core/app.gd", "game/backend/weekly_rivalry_client.gd",
    "game/ui/weekly_rivalry_page.gd", "game/tests/test_weekly_rivalry.gd",
    "game/tests/test_rivalry_track_detail.gd", "game/tests/test_weekly_rivalry_http.gd",
    "game/tests/test_rivalry_ghost_retry.gd", "game/tests/test_rivalry_ghost_retry.gd.uid",
    "AGENTS.md", "docs/WEEKLY_RIVALRY.md", "docs/RIVALRY_GHOST_RETRY_2026_10_18.md",
]
patch = []
report = {"requirements": ["WR06", "WR07", "WR08", "GH01", "R01", "Q01"], "files": {}}
for relative in files:
    after = (ROOT / relative).read_text(encoding="utf-8")
    saved = HERE / "before" / relative
    before = saved.read_text(encoding="utf-8") if saved.exists() else ""
    if relative == "game/core/app.gd":
        # Keep changes made by concurrent tasks after our initial snapshot.
        before = swap(after,
            'func _rivalry_ghost(index: int, choice: int, wait_for_recording: bool = false) -> Dictionary:',
            'func _rivalry_ghost(index: int, choice: int) -> Dictionary:')
        before = swap(before, '\tif wait_for_recording: return await rivalry.ghost(index,driver)\n', '')
        before = swap(before, 'await _rivalry_ghost(index,choice,true)', 'await _rivalry_ghost(index,choice)')
        before = swap(before, 'await _rivalry_ghost(rivalry_track,rivalry_ghost_choice,true)',
                      'await _rivalry_ghost(rivalry_track,rivalry_ghost_choice)')
        before = swap(before, '\tgame.call("_prepare_personal_ghost")\n\nfunc _prepare_race_rating',
                      '\nfunc _prepare_race_rating')
        before = swap(before,
            '\tif is_instance_valid(publication_notification):\n\t\tvar empty_publications: Array[Dictionary] = []\n\t\tpublication_notification.set_entries(empty_publications)',
            '\tif is_instance_valid(publication_notification): publication_notification.set_entries([])')
    elif relative == "game/ui/weekly_rivalry_page.gd":
        before = swap(after,
            '\t# Keep the chosen policy when a field has no recording yet. A later race\n\t# resolves it again against the current verified standings.',
            '\t# The removed rival/ghost column keeps its existing target choice internally.\n\tif model.ghost_target(selected,ghost_choice).is_empty(): ghost_choice = 3')
        for method in ["_reveal_player", "_reveal_after_sort", "_ensure_player_visible"]:
            before = swap(before, f'func {method}(scroll: Variant, player: Variant)',
                          f'func {method}(scroll: ScrollContainer, player: Control)')
    base = HERE / "task-base" / relative
    if before:
        base.parent.mkdir(parents=True, exist_ok=True)
        base.write_text(before, encoding="utf-8", newline="\n")
    final = HERE / "task-after" / relative
    final.parent.mkdir(parents=True, exist_ok=True)
    final.write_text(after, encoding="utf-8", newline="\n")
    patch.append(f"diff --git a/{relative} b/{relative}\n")
    patch.extend(difflib.unified_diff(before.splitlines(True), after.splitlines(True),
        fromfile=f"a/{relative}" if before else "/dev/null", tofile=f"b/{relative}"))
    digest = lambda text: hashlib.sha256(text.encode()).hexdigest()
    report["files"][relative] = {"base_sha256": digest(before) if before else None,
                                  "after_sha256": digest(after)}
(HERE / "task-only.patch").write_text("".join(patch), encoding="utf-8", newline="\n")
report["validation"] = {
    "focused_headless": 17, "focused_compatibility": 17, "focused_desktop_mobile": 17,
    "real_http_app_checks": 44, "http_pytest_passed": 1, "sqlite_scoring_passed": 1,
    "weekly_rivalry": 1115, "track_detail": 321, "results_continue": 60,
    "personal_ghosts": 38, "scalability": 17, "free_race_restart": 17,
    "app": 140, "parser_scripts": 865, "final_failures": 0,
}
report["limits"] = ["No phone attachment check or device test", "No APK or deployment",
                    "No live backend mutation", "Owner/device acceptance remains",
                    "Configured PostgreSQL attempt failed; SQLite scoring passed"]
(HERE / "report.json").write_text(json.dumps(report, indent=2)+"\n", encoding="utf-8")
print(f"Checkpoint: {len(files)} files")
