"""Assemble retained receipts after delivery checks; never infer test success."""
import hashlib
import json
import subprocess
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
receipts = {}
for path in sorted(HERE.glob("*.xml")):
    suite = ET.parse(path).getroot().find("testsuite")
    counts = {key: int(suite.get(key, 0)) for key in ("tests", "errors", "failures", "skipped")}
    counts["passed"] = counts["tests"] - counts["errors"] - counts["failures"] - counts["skipped"]
    counts["seconds"] = float(suite.get("time"))
    counts["started"] = suite.get("timestamp")
    receipts[path.name] = counts
for name in ("sqlite-delivery.xml", "postgres-delivery.xml"):
    assert receipts[name]["errors"] == receipts[name]["failures"] == 0, receipts[name]
assert receipts["original-rollback.xml"]["failures"] == 4
subprocess.run([sys.executable, str(HERE / "checkpoint.py"), "finalize"], cwd=ROOT, check=True)
patch_check = ["git", "apply", "--check", "--directory=build/backend-priority-fixes-2026-10-23/original-rollback",
               "docs/evidence/backend-priority-fixes-2026-10-23/task-only.patch"]
subprocess.run(patch_check, cwd=ROOT, check=True)
manifest = json.loads((HERE / "original.json").read_text())
lint = ["backend/bmt_backend/rivalry.py", "backend/bmt_backend/rivalry_models.py",
        "backend/bmt_backend/achievement_models.py", "backend/bmt_backend/achievements.py",
        "backend/bmt_backend/creator_achievements.py", "backend/bmt_backend/news.py",
        "backend/bmt_backend/privacy.py", "backend/bmt_backend/worker.py",
        "backend/bmt_backend/migrations/versions/0054_priority_scaling.py",
        "backend/tests/test_achievements.py", "backend/tests/test_priority_scaling.py"]
subprocess.run([sys.executable, "-m", "ruff", "check", *lint], cwd=ROOT, check=True)
subprocess.run(["git", "diff", "--check", "--", *manifest], cwd=ROOT, check=True)
sql_plan = json.loads((HERE / "postgres-matching-plan.json").read_text())
report = {
    "task": "Fix high-priority backend scalability findings BSR2-F01 through BSR2-F03",
    "date": "2026-10-23",
    "base_commit": "dc3e2af6c9e1875db9ffe7e2a8efa321076f19b1",
    "requirements": {
        "BPF01 / BSR2-F01": {
            "status": "implemented and validated",
            "change": "Partial open-group index; <=100 indexed candidates; independent group claims with SKIP LOCKED; creation-only band guard.",
            "preserved": "Exact capacity=20, [1,20] fields for 21 concurrent entrants, unique membership/retries, pinned tracks and existing skill behavior.",
            "tests": ["test_open_group_index_excludes_closed_groups", "test_matching_plan_uses_partial_index_with_many_closed_groups",
                      "test_postgres_rivalry_skips_busy_group_and_old_band_lock", "test_group_capacity_and_repeat_joins", "test_simultaneous_capacity_reservations"],
        },
        "BPF02 / BSR2-F02": {
            "status": "implemented and validated",
            "change": "Transactional run-keyed pending creator effects for both plays and reach; <=100 effects per partition turn, grouped by creator; skip busy states; atomic projection/deletion.",
            "correctness": "Permanent CoinReward prevents replay after projection; rollback retains effects; exact threshold timestamps/revisions; new intake checks eligibility; later suspension/test changes preserve accepted effects; deletion cancels pending work in indexed chunks.",
            "privacy": "No new racer ID column, FK lock or replay document. Pending run IDs can still associate with the retained accepted-run record until projection. Creator erasure excludes intake/reduction through sixteen fixed partition fences.",
            "tests": ["test_postgres_busy_creator_projection_does_not_block_two_race_acceptances",
                      "test_postgres_busy_creator_reducer_skips_and_retains_effects",
                      "test_creator_effects_roll_back_and_permanent_reward_receipt_prevents_replay",
                      "test_creator_batches_preserve_exact_unlock_timestamps_and_bounded_erasure",
                      "test_postgres_parallel_intake_reduction_and_erasure_remain_exact",
                      "test_creator_restriction_preserves_accepted_effects_but_rejects_new_intake"],
        },
        "BPF03 / BSR2-F03": {
            "status": "implemented and validated",
            "change": "Every 16 completed worker jobs reserves privacy, histogram and a rotating achievement/Trackside turn; idle roles and four achievement stages also rotate; reserved failures are isolated and logged.",
            "bound": "With both presentation roles continuously busy, each gets a reserved attempt within 32 job completions. Under continuously busy achievement classes, each class gets an attempt within four achievement turns (128 job completions). This is per running worker, not a wall-clock SLA.",
            "tests": ["test_busy_foreground_reserves_both_presentation_classes",
                      "test_idle_roles_and_achievement_roles_are_fair_even_when_all_busy",
                      "test_failed_cleanup_does_not_consume_other_reserved_turns",
                      "test_continuous_foreground_work_gets_reserved_histogram_turn"],
        },
        "R01": "Objective implementation review and refinements are recorded below; original capacity assertions retained.",
        "Q01": "Actual command receipts, migration checks, source hashes and applicable task-only patch retained; no deployment/device claim.",
    },
    "objective_review_and_refinements": [
        {"finding": "Plays were not the only creator lock; first-time reach also touched creator state inside race acceptance.",
         "refinement": "Both effects share the accepted-run outbox row; reach updates cannot invent another play."},
        {"finding": "Historical Rivalry migration creates current model indexes on fresh installs.",
         "refinement": "Additive migration inspects the index before creation; both fresh and upgrade/rollback installs tested."},
        {"finding": "Concurrent P2 work temporarily introduced two migration heads.",
         "refinement": "Retained this task's 0054 after concurrent work chained its bounded-rank migration as 0055; no concurrent source was overwritten."},
        {"finding": "Initial SKIP LOCKED/create behavior split 21 entrants into [6,15], violating the existing [1,20] test.",
         "refinement": "Wait on a group when all eligible candidates are busy; guard only creation, then recheck. Original assertion passes without modification."},
        {"finding": "A busy creator or a failed housekeeping role could stall or consume other background turns.",
         "refinement": "Skip locked creator states, bound rare first-insert waits to 250ms, advance fair cursors before execution, and log/isolate reserved-role failures."},
        {"finding": "Dropping queued effects on later creator suspension would lose already accepted plays.",
         "refinement": "Intake attests creator eligibility; reducer preserves accepted effects through later restrictions and retains deletion as permanent cancellation."},
        {"finding": "The new PostgreSQL two-track fixture initially exceeded the real publication-slot limit.",
         "refinement": "Seed the second published test course using the existing official fixture and use independent per-replica finalization state; no entitlement/capacity assertions weakened."},
    ],
    "changed_runtime_and_test_files": sorted(manifest),
    "validation_receipts": receipts,
    "matching_probe": {
        "closed_groups": sql_plan["closed_groups"], "open_groups": sql_plan["open_groups"],
        "node": sql_plan["plan"][0]["Plan"]["Plans"][0]["Node Type"],
        "index": sql_plan["plan"][0]["Plan"]["Plans"][0]["Index Name"],
        "shared_hit_blocks": sql_plan["plan"][0]["Plan"]["Shared Hit Blocks"],
        "local_execution_ms": sql_plan["plan"][0]["Execution Time"],
        "limit": "Synthetic local plan evidence only; not a comparable cloud throughput benchmark or DAU certification.",
    },
    "actual_commands": {
        "failure_first": ".tools/backend-secure-venv/Scripts/python.exe docs/evidence/backend-priority-fixes-2026-10-23/run_sqlite.py tests/test_priority_scaling.py --junitxml=../docs/evidence/backend-priority-fixes-2026-10-23/baseline.xml",
        "sqlite_delivery": ".tools/backend-secure-venv/Scripts/python.exe docs/evidence/backend-priority-fixes-2026-10-23/run_sqlite.py --exclude-legacy-rollback-tests tests/test_priority_scaling.py tests/test_achievements.py tests/test_rivalry.py tests/test_rivalry_concurrency.py tests/test_histogram_followup.py tests/test_histogram_snapshots.py tests/test_lap_bests.py tests/test_news.py tests/test_privacy.py tests/test_queue_capacity_slots.py --junitxml=../docs/evidence/backend-priority-fixes-2026-10-23/sqlite-delivery.xml",
        "postgres_delivery": "wsl -d Ubuntu -- docker run --rm --cpus=2 --memory=1024m --pids-limit=128 --network container:bmt-backend-test -v '/mnt/c/Codes/Godot/Beat my track/backend:/task/backend:ro' -v '/mnt/c/Codes/Godot/Beat my track/.tools/backend-postgres.env:/task/db.env:ro' -v '/mnt/c/Codes/Godot/Beat my track/docs/evidence/backend-priority-fixes-2026-10-23:/evidence' -e PYTHONPATH=/task/backend -e PYTHONDONTWRITEBYTECODE=1 -w /task/backend --entrypoint python bmt-full-20261018:86d38519ffb5ac1f /evidence/run_postgres.py --exclude-legacy-rollback-tests tests/test_priority_scaling.py tests/test_achievements.py tests/test_rivalry.py tests/test_histogram_followup.py tests/test_news.py tests/test_privacy_postgres.py::test_concurrent_deletion_receipts_have_one_effect tests/test_privacy_postgres.py::test_upload_that_released_owner_lock_is_fenced_after_removal --junitxml=/evidence/postgres-delivery.xml",
        "original_rollback_reproduction": ".tools/backend-secure-venv/Scripts/python.exe docs/evidence/backend-priority-fixes-2026-10-23/run_original_rollback.py",
        "ruff": [sys.executable, "-m", "ruff", "check", *lint],
        "whitespace": ["git", "diff", "--check", "--", *manifest],
        "patch_application_check": patch_check,
    },
    "historical_rollback_limitation": {
        "tests": ["test_migration_backfills_snapshots_without_rewriting_results",
                  "test_migration_bounded_backfill_matches_legacy_and_survives_restart",
                  "test_migration_seeds_existing_racers_without_old_news",
                  "test_migration_preserves_pending_jobs_and_round_trips"],
        "reproduction": "All four fail on the exact original Git source at irreversible 0051_telemetry_parallel. Current full SQLite suite also retains these four failures: three stop earlier at 0054's intentional pending-effect guard; one reaches 0051. Delivery selection excludes these four named historical rollback cases only. Assertions remain unchanged.",
        "replacement_scope": "This task's own 0054 downgrade refusal, drain, downgrade and re-upgrade are verified on SQLite and PostgreSQL without crossing 0051.",
    },
    "remaining_acceptance_and_limits": [
        "Apply matching migration/API/worker code through the reviewed release process. No live deployment, account, race, publication or queue mutation was performed.",
        "Stop/drain old writers for cutover; measure the partial-index build and migration lock on representative data. Downgrade refuses pending award loss.",
        "Per-group locks and creation-only band guards remain to preserve exact field filling. Sharing a group can still wait; closed groups do not accumulate in its candidate scan.",
        "Fair reserved work prevents starvation; it does not prove arrival/service-rate balance. Creator distribution, pending-effect age, rarity/news backlog, long canonical verifications, database CPU/storage and worker counts need representative sustained and burst load tests.",
        "500 million accounts and one million DAU have not been certified. No phone attachment check, physical-device test, APK build or export was performed.",
        "Concurrent discovery, admission, rank, retention, Studio and client work was preserved. The task-only patch excludes the concurrent skill_score rewrite in the shared Rivalry module; final-source hashes record the shared runtime actually inspected.",
    ],
    "test_fixture": json.loads((HERE / "fixture-check.json").read_text()),
    "fixture_lifecycle": "Dedicated local PostgreSQL fixture started from stopped state for tests, checked for other clients, and restored to stopped state. Unidentified historical test schemas were retained, not deleted.",
    "checkpoint": {
        "kind": "task-only applicable Git patch; no shared staging/commit",
        "path": "task-only.patch",
        "sha256": hashlib.sha256((HERE / "task-only.patch").read_bytes()).hexdigest(),
        "original_manifest": "original.json", "shared_final_hashes": "final-source-hashes.json",
        "apply_check": "passed against isolated original Git source",
    },
}
(HERE / "report.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
print(json.dumps({"sqlite": receipts["sqlite-delivery.xml"], "postgres": receipts["postgres-delivery.xml"],
                  "checkpoint_sha256": report["checkpoint"]["sha256"]}, indent=2))
