"""Reviewable task-only patch over saved/reconstructed pre-task source files.

Never stages the shared Git index or includes private configuration/game assets.
"""
import difflib
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
BEFORE = ROOT / "build/studio-monitor-revision-2026-10-12/before"
CLIENT = ROOT / "build/studio-monitor-2026-10-12/client-before"
PUBLICATION = ROOT / "build/studio-monitor-2026-10-12/local-publication/before"
CATALOGUE = ROOT / "build/studio-revision-2026-10-12/catalogue-before"
OUTPUT = ROOT / "docs/evidence/studio-monitor-revision-2026-10-12"
NEW = [
    "backend/bmt_backend/publication_models.py", "backend/bmt_backend/publications.py",
    "backend/bmt_backend/race_statistics.py", "backend/bmt_backend/race_statistics_models.py",
    "backend/bmt_backend/studio_catalogue.py",
    "backend/bmt_backend/migrations/versions/0028_publication_intents.py",
    "backend/bmt_backend/migrations/versions/0029_race_statistics.py",
    "backend/bmt_backend/migrations/versions/0030_studio_catalogue.py",
    "backend/bmt_backend/admin_ui/catalogue.js", "backend/bmt_backend/admin_ui/catalogue.css",
    "backend/bmt_backend/admin_ui/monitor.js", "backend/bmt_backend/admin_ui/monitor.css",
    "backend/bmt_backend/admin_ui/monitor_views.js", "backend/bmt_backend/admin_ui/monitor_views.css",
    "backend/tests/test_publication_intents.py", "backend/tests/test_race_statistics.py",
    "backend/tests/test_race_statistics_postgres.py", "backend/tests/test_studio_catalogue.py",
    "game/tests/test_local_draft_publication.gd", "game/tests/test_local_draft_publication.gd.uid",
    "game/tests/test_published_only_lifecycle.gd", "game/tests/test_published_only_lifecycle.gd.uid",
    "game/tests/test_race_statistics_app.gd", "game/tests/test_race_statistics_app.gd.uid",
    "scripts/studio_catalogue_browser_checks.py", "scripts/test_studio_monitor_console.py",
    "scripts/test_studio_monitor_views.js", "scripts/test_studio_monitor_postgres.py",
    "scripts/profile_studio_race_statistics.py", "scripts/checkpoint_studio_monitor.py",
    ".tools/studio_monitor_live_read_20261012.py",
    "docs/STUDIO_CATALOGUE_2026_10_12.md", "docs/STUDIO_RACE_STATISTICS_CLIENT_2026_10_12.md",
    "docs/STUDIO_LOCAL_DRAFTS_2026_10_12.md", "docs/STUDIO_MONITOR_REVISION_2026_10_12.md",
    "docs/evidence/studio-monitor-2026-10-12/client-statistics-sample.json",
    "docs/evidence/studio-monitor-2026-10-12/browser.json",
    "docs/evidence/studio-monitor-revision-2026-10-12/diagnostic-compute.json",
    "docs/evidence/studio-monitor-revision-2026-10-12/live-readonly-diagnosis.json",
]


def normalized(value):
    return value.decode("utf-8").replace("\r\n", "\n")


def main():
    sources = {file.name.replace("__", "/"): file for file in BEFORE.iterdir()
        if file.is_file() and "__" in file.name}
    sources["DEVELOPMENT_STATUS.md"] = BEFORE / "DEVELOPMENT_STATUS.md"
    for file in CLIENT.iterdir():
        if file.is_file():
            sources.setdefault(file.name.replace("__", "/"), file)
    for prefix, names in (
        ("backend/bmt_backend/", ["config.py", "tracks.py", "worker.py", "maintenance.py", "track_models.py"]),
        ("backend/tests/", ["test_product_analytics.py", "test_commerce.py", "test_admin_support.py"]),
        ("game/backend/", ["track_lifecycle.gd", "cloud_tracks.gd"]),
        ("game/ui/", ["draft_browser.gd"]),
        ("game/tests/", ["test_cloud_tracks.gd"]),
    ):
        for name in names:
            sources.setdefault(prefix + name, PUBLICATION / name)
    sources.setdefault("backend/bmt_backend/admin_ui/commerce.js", CATALOGUE / "commerce.js")
    # This tiny legacy validator fence had no saved snapshot; its only diff is
    # reconstructed and explicitly checked from the known pre-task line below.
    track_validation = ROOT / "backend/bmt_backend/track_validation.py"
    current = track_validation.read_text(encoding="utf-8")
    if "if stopping(app) or app.state.settings.local_drafts_only:" in current:
        before = current.replace("if stopping(app) or app.state.settings.local_drafts_only:", "if stopping(app):", 1)
        baseline = BEFORE / "backend__bmt_backend__track_validation.py"
        if not baseline.exists():
            baseline.write_text(before, encoding="utf-8")
        sources.setdefault("backend/bmt_backend/track_validation.py", baseline)
    for name in NEW:
        if name in sources:
            raise RuntimeError("Duplicate task path: " + name)
        sources[name] = None

    manifest, patches = [], []
    validation = ROOT / "build/studio-monitor-revision-2026-10-12/checkpoint-validation"
    validation.mkdir(parents=True, exist_ok=True)
    for name, original in sorted(sources.items()):
        before = original.read_bytes() if original else b""
        after = (ROOT / name).read_bytes()
        if before == after:
            continue
        manifest.append({"path": name,
            "before_sha256": hashlib.sha256(before).hexdigest() if original else None,
            "after_sha256": hashlib.sha256(after).hexdigest(), "bytes": len(after),
            "baseline_source": str(original.relative_to(ROOT)).replace("\\", "/") if original else "new task file"})
        for line in difflib.unified_diff(normalized(before).splitlines(keepends=True),
                normalized(after).splitlines(keepends=True),
                fromfile="a/" + name if original else "/dev/null", tofile="b/" + name):
            patches.append(line if line.endswith("\n") else line + "\n")
            if not line.endswith("\n"):
                patches.append("\\ No newline at end of file\n")
        if original:
            target = validation / name
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_text(normalized(before), encoding="utf-8")
    OUTPUT.mkdir(parents=True, exist_ok=True)
    (OUTPUT / "workspace-task-only.patch").write_text("".join(patches), encoding="utf-8")
    (OUTPUT / "checkpoint.json").write_text(json.dumps({
        "schema": "bmt-workspace-checkpoint-v1", "git_commit_created": False, "deployment_performed": False,
        "baseline": "Saved pre-task dirty source; four reviewed tracked-file Git baselines; two checksum-verified prior task sources with the pre-task deployed challenge compatibility correction restored; one exact legacy-gate reconstruction. Newline normalization excludes formatting-only noise.",
        "excluded": "Private configuration, credentials, existing player data and unrelated gameplay/art/assets.",
        "screenshots": [{"path": str(file.relative_to(ROOT)).replace("\\", "/"),
            "sha256": hashlib.sha256(file.read_bytes()).hexdigest(), "bytes": file.stat().st_size}
            for file in sorted((ROOT / "docs/evidence/studio-monitor-2026-10-12").glob("*.png"))],
        "files": manifest,
    }, indent=2) + "\n", encoding="utf-8")
    print(f"Task-only checkpoint: {len(manifest)} source/docs files; shared Git index untouched")


if __name__ == "__main__":
    main()
