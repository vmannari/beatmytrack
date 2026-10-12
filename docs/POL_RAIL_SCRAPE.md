# Owner-selected Pól rail scrape — 2026-10-11

Owner request: use [Pól's S023_Metal_Rail_Scrape_Mono.wav](https://freesound.org/people/P%C3%B3l/sounds/385939/)
instead of the prior scraping sound. **SND46**, refining SND40-SND45/SND08/SND05
and supporting G01/R01/Q01/V06. This replaces the derivative in
[Continuous body scrape](CONTINUOUS_BODY_SCRAPE.md).

The author's page describes a rally car scraping a metal rail barrier and
licenses it **CC0 1.0**. The public HQ MP3 preview is decoded locally by pinned
Godot: **187,424 mono float frames/4.25s at 44.1kHz**. The 0.35–3.65s continuous
middle excludes initial contact and final settling. A 0.5s power-corrected cyclic
crossfade makes a **2.8s** loop. Common DC removal, loudness/headroom and dither
remain; this selected source bypasses the bank's default equalization.
Its original pitch and spectrum are retained, with no other audio layered in.

The unjoined loop interior correlates **over 0.99999999** with the original decoded
source at matching sample rate, checking actual recording identity and pitch
independently of advertised metadata. Only **scrape.wav** changes; **47 other
WAV hashes**, including the attached crash, are exact. Repeat mastering produces
all 48 identical hashes. The loop occupies **247,004 bytes**, reducing its prior
size by **767,340 bytes**. Runtime contact, gain/pitch response, 60ms hold,
22-player budget, pause/countdown/air/rollover/rewind/retry and below-deck guards
remain unchanged. No physics/rules/camera/backend or player-data changes.

Changed files: `scripts/continuous_scrape_mastering.py`,
`scripts/fetch_continuous_scrape.py`, `scripts/build_vehicle_audio.py`,
`game/tests/decode_continuous_scrape.gd`, `scripts/review_pol_rail_scrape.py`,
`game/assets/audio/vehicles/scrape.wav`, `manifest.json`, `NOTICE.txt`, this
document, `docs/CONTINUOUS_BODY_SCRAPE.md`, `DEVELOPMENT_STATUS.md` and
`docs/PHASE_0_PLAN.md`.

License page, untouched encoded preview, float decode and registered WAV remain
in export-excluded `build/vehicle_audio_sources/`. Shipping credits and manifest
retain author, CC0, original URL, preview quality and source/derivative hashes.
The source preview is compressed MP3, not the site's lossless 24-bit master.
No account, purchase, runtime API/source download or dependency was introduced.

Actual commands use pinned **4.7.2.stable.official.ed1daf0bf** through
`powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1`:

| Actual command / suffix | Outcome |
| --- | --- |
| Browser source page / Windows `Invoke-WebRequest -UseBasicParsing` | CC0/source description verified; license saved and **96,864-byte** HQ preview staged. |
| `python scripts/fetch_continuous_scrape.py` | Cached page/media verified, pinned preview URL registered. |
| `-Action TestScript -ScriptPath res://tests/decode_continuous_scrape.gd` | **187,424 frames**, exit 0. |
| `python scripts/fetch_continuous_scrape.py --finalize` | Float WAV and encoded/decoded/source manifest registered. |
| `python scripts/build_vehicle_audio.py --collisions-only` | Four scoped derivatives **466,384 bytes**, only scrape changes. Final repeated all 48 hashes exact. |
| `-Action Import` | Final **exit 0**, new derivative imported. |
| `-Action TestScript -ScriptPath res://tests/test_bridge_scrape_audio.gd -Graphical -TestArgument '--evidence-dir=res://../docs/evidence/pol-rail-scrape-2026-10-11'` | Final **611 checks/zero failures**, all five cars/both sides/directions/three speeds, actual Game integration and nine native recordings. |
| `-Action TestScript -ScriptPath res://tests/test_vehicle_audio.gd` | Final **1,450 checks/zero failures**, bank/lifecycle and simulation separation. |
| `python scripts/test_vehicle_audio_continuity.py --report docs/evidence/pol-rail-scrape-2026-10-11/loop-continuity.json` | **41 loops/zero failures**, three repetitions/joins/no embedded gaps. |
| `python scripts/review_pol_rail_scrape.py` | Correct source/license/hashes, unchanged pitch/interior correlation, output headroom, native mute tails and 47 other WAVs pass. Friction **2.23/2.50/2.45dB below engine** at 4/12/24m/s. |
| `python -m py_compile scripts/continuous_scrape_mastering.py scripts/fetch_continuous_scrape.py scripts/build_vehicle_audio.py scripts/review_pol_rail_scrape.py` | Exit 0. |
| Configured SDK `adb devices -l` | **DN2103 phone attached**; device listening/install not performed. |

The actual compact Game bridge check remains **46 audible ticks out of 48**,
peak gain **0.402**, staying above the bridge. Native captures have no clipping,
with last 200ms exactly silent on pause. They hold real contact movement to
assess the vehicle mix, not claim a completed race or subjective listening approval.

An initial inline edit failed shell quoting; the first rebuild still referenced
the old source and failed lookup, leaving WAVs unchanged. A duplicate-path patch
was rejected without mutation; the subsequent normal patch corrected it. The
first working derivative used common bank EQ (source correlation0.981); a scoped
`preserve_spectrum` option retains the chosen recording exactly in the unjoined
region, and final stricter0.9999 correlation checks pass. No existing check was
weakened. Failed attempts/outcomes and completed native logs remain documented.

Evidence: `docs/evidence/pol-rail-scrape-2026-10-11/` holds prior WAV/source hashes,
source manifest, actual logs, contact matrix, loop/PCM review, nine native WAVs
and a task-only Git-format binary/source patch plus SHA-256 checkpoint. Listen
to the [vehicle mix](evidence/pol-rail-scrape-2026-10-11/after-12-mix.wav) or
[scrape alone](evidence/pol-rail-scrape-2026-10-11/after-12-scrape.wav).

No visible UI change, phone listening, Android export/install, full Validate,
physics/rules/camera change, backend work, deployment or score write was
performed. Restart the local game to load the replacement; installed Android
remains unchanged. Owner/device acoustic acceptance remains.
