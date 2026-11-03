from pathlib import Path

ROOT=Path(__file__).resolve().parents[3]
note='''<!-- FORKLIFT-CABIN-VARIATION-20261103 -->
## Forklift cabin frames have distinct architectures (2026-11-03)
FCV01-FCV03/R01: All thirteen alternatives replace the former shared rectangular profile with round transverse hoops, tapered pressed pillars, rear-only cantilever columns, swept/wedge roofs, longitudinal barrel/transverse vault arches, roof X/diamond/screen structures, weather/sun canopies and heavy haunches. Fourteen choices and every item ID remain; other kit builders/server catalogue exact. Construction8606/0, raw741/0, exact Original12/0, prepared1580/0 and actual Garage187/0 each desktop renderer;154 final native captures and before/after gallery. Four bases/104 modules/Garage template refresh. First tight heavy-frame bend failures retained and corrected without relaxing gates. Sources, commands, hashes, task-only checkpoint and limits: [docs/FORKLIFT_CABIN_VARIATION_2026_11_03.md](docs/FORKLIFT_CABIN_VARIATION_2026_11_03.md). Reload/owner appearance and device acceptance remain. No device query/test, APK, real purchase, owner-save/process change, live/backend mutation, deployment or main-index write; concurrent work preserved.
<!-- /FORKLIFT-CABIN-VARIATION-20261103 -->

'''
for name in ['AGENTS.md','DEVELOPMENT_STATUS.md']:
    path=ROOT/name
    data=path.read_bytes()
    assert b'<!-- FORKLIFT-CABIN-VARIATION-20261103 -->' not in data
    path.write_bytes(note.encode('utf-8')+data)
print('Prepended scoped task notes; all existing bytes retained')
