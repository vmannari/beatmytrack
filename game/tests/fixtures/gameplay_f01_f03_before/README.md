# Gameplay F01-F03 independent references

These are byte-for-byte copies of the task-start implementations from 23 October 2026, before the authorized F01-F03 fixes. `.gd.txt` prevents automatic class registration. Tests load the text and remove only its `class_name` declaration to run both versions in one process. Runtime exports already exclude `tests/*`.

The source SHA-256 values are retained in `docs/evidence/gameplay-f01-f03-2026-10-23/before.json`; full task-start files also remain in that evidence directory's `before/` folder. `test_dynamic_prop_work.gd`, `test_paint_preparation.gd` and `profile_gameplay_f01_f03.gd` use these references. Keep their calculations independent of production optimizations.
