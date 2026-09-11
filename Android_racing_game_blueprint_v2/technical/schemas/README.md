# Schema status
These are proposed starter JSON Schema 2020-12 contracts, not generated bindings or production validators. All shapes use bounded integer/enumerated values and reject unknown fields. Track geometry is separate from mutable title/description. Hashes use canonical sorted compact UTF-8 JSON; define a single published canonicalization before independent implementations.

A schema validates shape, not a drivable circuit, authentic ticket, paid entitlement, physical run, safe decompression or ownership. The service must enforce those separately. Run caps are provisional anti-abuse bounds (2 MiB replay, 600-second run at 120 Hz), not a daily racing cap. Award policy for exceptionally slow/aborted runs requires playtest review. Keep completed eligible driving rewards; do not punish beginners with an unexplained cutoff.

`tests/test_contracts.py` checks starter schemas plus basic ranking, idempotency and comparison-key examples. It does not test Godot physics, an Android game, the real API or billing.
