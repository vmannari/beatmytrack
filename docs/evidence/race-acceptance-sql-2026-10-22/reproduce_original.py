"""Retain the same assertions against archived sources in an isolated process."""
from pathlib import Path

import pytest
from measure_acceptance import original_functions

original_functions()
raise SystemExit(pytest.main([
    'backend/tests/test_race_acceptance_sql.py::test_repeat_acceptance_reuses_bounded_facts_without_history_or_ledger_reads[sqlite]',
    'backend/tests/test_reward_ranks.py::test_migration_backfills_existing_field_and_downgrades_without_changing_receipts[sqlite]',
    'backend/tests/test_challenges.py::test_additive_attempt_migration_preserves_existing_challenges[sqlite]',
    'backend/tests/test_lap_bests.py::test_migration_bounded_backfill_matches_legacy_and_survives_restart[sqlite]',
    '-q', '--tb=short', '--junitxml=' + str(Path(__file__).with_name('original-reproduction.xml')),
]))
