from pathlib import Path

ROOT=Path(__file__).resolve().parents[3]
note='''<!-- FORKLIFT-COVER-GUARD-VARIATION-20261103 -->
## Forklift covers and rear guards have distinct industrial designs (2026-11-03)
FGV01-FGV04/R01: All26 alternatives now use butterfly/two-piece/cast-fin/filter/folded covers and wraparound/twin-tube/step/roller/shield/box/buffer/clevis guards. Fitted hardware and chassis supports remain within unchanged envelopes/budgets;14 choices/category and all IDs remain. Accepted cabin/wheel builders, factory model and server catalogue exact; default cabin roof buffers18/0. Construction9170/0, raw741/0, exact Original12/0, prepared1580/0 and actual Garage187/0 each desktop renderer;252 final/control native captures and before/after gallery. Four bases/104 modules/Garage template refresh. First pad-projection failures and fin/flute visual polish retained, no gate relaxed. Commands, hashes, task-only checkpoint and limits: [docs/FORKLIFT_COVER_GUARD_VARIATION_2026_11_03.md](docs/FORKLIFT_COVER_GUARD_VARIATION_2026_11_03.md). Reload/owner appearance and device acceptance remain. No device query/test, APK, real purchase, owner-save/process change, live/backend mutation, deployment or main-index write; concurrent work preserved.
<!-- /FORKLIFT-COVER-GUARD-VARIATION-20261103 -->

'''
for name in ['AGENTS.md','DEVELOPMENT_STATUS.md']:
    path=ROOT/name
    data=path.read_bytes()
    assert b'<!-- FORKLIFT-COVER-GUARD-VARIATION-20261103 -->' not in data
    path.write_bytes(note.encode('utf-8')+data)
print('Prepended task notes with all previous bytes preserved')
