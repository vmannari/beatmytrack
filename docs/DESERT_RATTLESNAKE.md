# Desert rattlesnake ambience — 2026-10-11

SND49 follow-up: each call now selects a randomized excerpt and duration within
these recordings, with its own smooth uneven pulse pattern. The original SND48
implementation/results below are historical; current behavior and checks are
documented in [Desert rattle variation](DESERT_RATTLE_VARIATION.md).

SND48 implements the owner's request for rattlesnake sounds in Desert.
G01/R01 keep sounds outside canonical driving; Q01 covers actual verification
and asset provenance.

`DesertRattlesnake` adds one race-owned Vehicle-bus voice only for Desert. Two
recorded3.0/3.8-second rattles alternate without immediate repeats. Each attempt
starts after4–10 seconds, then leaves12–24 seconds of silence after every complete
call, with gain0.28–0.38 and subtle pitch0.97–1.03 variation. Runtime randomness
is independent of wind and simulation. Calls never overlap or catch up in a
burst after a stalled frame. The existing continuous Desert wind remains active.

Pause/rewind/background freeze both the current sound and its schedule; finish
fades within0.3 seconds and schedules no more calls. Retry clears tails and picks
a fresh initial wait, biome change stops the voice and exit frees it. Existing
sound-volume/mute settings apply. This is ambient audio only; no snake objects,
bites, collision/hazard changes, UI labels, scores/rules or backend work.

Source is the U.S. Fish and Wildlife Service rattlesnake recording published as
[Rattlesnake.ogg on Wikimedia Commons](https://commons.wikimedia.org/wiki/File:Rattlesnake.ogg),
with recording-specific PD-USGov-FWS designation and Ogg conversion uploaded by
Borisblue. Source/license page is retained outside exports, and SHA256145f9283…
pins the downloaded file. Pinned Godot decodes667,851mono frames/15.144seconds.
Regions1.5–4.5s and7.0–10.8s are downmixed to44.1kHz16-bit PCM, DC corrected,
given50ms edge fades and level matched at−21dBFS. Original sound/pitch retained;
no synthesis or extra rattle layers. Source/decoded/derivative hashes are in
`desert_rattlesnake_manifest.json`, shipping notice and asset ledger. No runtime
downloads/services or new dependencies; NumPy is an existing offline build tool.

The two WAVs total599,848bytes (~0.57MiB), hashesf0ec3962…/6144c766….
Repeated decode/mastering reproduces both exactly. Desert adds one active voice
alongside its two existing wind/sand voices; no device-performance claim.

Changed files:

- `game/track/desert_rattlesnake.gd` and `.uid`: recorded calls and lifecycle.
- `game/core/game.gd`: seven added setup/presentation/Retry lines.
- `game/assets/audio/ambience/desert_rattle_a.wav`, `desert_rattle_b.wav`, their `.wav.import` files, `desert_rattlesnake_manifest.json`, `NOTICE.txt`.
- `scripts/build_desert_rattlesnake.py`, `scripts/review_desert_rattlesnake.py`.
- `game/tests/decode_rattlesnake_source.gd`, `test_desert_rattlesnake.gd` and `.uid` files.
- This document, `licenses/ASSETS.md`, `DEVELOPMENT_STATUS.md`, `docs/PHASE_0_PLAN.md`.

Actual commands:

```powershell
python scripts/build_desert_rattlesnake.py --fetch --decode
python scripts/build_desert_rattlesnake.py --decode
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action Import
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_desert_rattlesnake.gd
powershell -NoProfile -ExecutionPolicy Bypass -Command "& './scripts/dev.ps1' -Action TestScript -ScriptPath res://tests/test_desert_rattlesnake.gd -Graphical -TestArgument @('--capture')"
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_desert_ambience.gd
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestApp
python scripts/review_desert_rattlesnake.py
& 'C:/Users/ville/AppData/Local/Android/Sdk/platform-tools/adb.exe' devices -l
```

Import/headless117/native129/Desert111/App99/final PCM review pass. Six90-second
schedules cover sparse varying timing, no repeats, bounded gain/pitch, pause/
background/finish/mute/retry/biome/exit, actual Desert-race ownership and unchanged
canonical snapshot. Native timing confirms complete recorded calls followed by
the requested silence, with no overlap. Two40-second wind+rattle samples include
calls at8.308/33.359s versus7.725/28.258s; settled500ms RMS never drops below
0.01706/0.02575. Peaks0.2527/0.2450, unclipped. A controlled15-second Compact
engine mixer at25m/s (90km/h) includes a call and peaks0.3219, unclipped.
Pause/mute/finish~0.4-second samples are exactly silent. Recorded-waveform
correlation with the original interiors is>0.999999995. These are mixer
diagnostics, not completed race/phone performance or subjective listening claims.

Initial fixture parse failed because a rattle-typed helper received the wind
object; wind's own `present()` fade fixed it without changing assertions.
An audit-method spelling error was corrected before that script ran. An unrelated
concurrent contact-observer argument update in `game.gd` is preserved in the
workspace and excluded from this task's patch; no vehicle/physics change belongs
to this task. Existing player files, Wind assets and other unowned work remain.

Evidence: [Desert wind and rattles](evidence/desert-rattlesnake-2026-10-11/desert0.wav),
[another race](evidence/desert-rattlesnake-2026-10-11/desert1.wav),
[with engine](evidence/desert-rattlesnake-2026-10-11/driving.wav),
[measured review](evidence/desert-rattlesnake-2026-10-11/review.json), isolated/
silence clips, event JSONs, focused logs and task-only Git checkpoint/patch.
The main index/branch is untouched by the isolated checkpoint.

DN2103 phone attached. No phone listening, Android export/install, device
performance, full Validate or deployment performed. Remaining acceptance:
restart/rebuild, listen across Desert retries on the phone and judge call
frequency/level against wind and engine; confirm pause/rewind/finish. No visible
UI change, so screenshots are unnecessary.
