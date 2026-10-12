# Collision sample onset recheck — 2026-10-09

The owner still perceives some delay and asks whether the effect itself contains
a delayed audible start. SND18 verifies sustained impact energy as well as the
first nonzero/peak sample, and checks the exact samples Godot loads. SND14–SND17,
SND05/G01/R01/Q01/V06 remain in force. This audit changes diagnostics and
documentation only; no audio master, runtime route, gain or canonical code was
changed.

**All three collision clips begin immediately.** There are zero leading silent
frames. The first PCM sample is the full peak (-27524), and, more significantly,
the first **10 ms is the loudest sustained 10 ms section of each entire clip**.
This rules out an isolated initial spike followed by a quiet 100 ms lead-in.

| Clip | First 1 ms RMS | First 10 ms RMS | Loudest 10 ms starts |
| --- | ---: | ---: | ---: |
| Light `impact_0.wav` | 0.436 | 0.247 | **0 ms** |
| Medium `impact_1.wav` | 0.295 | 0.221 | **0 ms** |
| Hard `impact_2.wav` | 0.289 | 0.229 | **0 ms** |

RMS is relative to full-scale PCM, not a measured speaker loudness. Ten percent
of each clip's energy has already arrived by 1.16/3.42/4.83 ms respectively.
Godot's imported mono 16-bit/44.1 kHz samples match the WAV data **byte for byte**;
the import does not add silence, compression warm-up or a different attack.

A read-only check also finds the current visible workspace Godot process
(PID4968, started **20:59:18 +03:00**) has `bmt_windows_audio_v2.dll` loaded. The
first command-line path check used Windows separators and missed this process;
normalizing separators confirms that it belongs to this workspace. No process
was stopped, audio from the user's game was recorded, or full command line,
memory, account data or other application's audio was inspected.

This confirms the **clip onset**, not zero acoustic latency. The earlier final
Windows process-output test still measured **39–46 ms** from the game callback
before speaker/Bluetooth hardware. The owner's remaining perception is not
resolved by this audit. Playback/hardware timing and possible masking by the
engine still need listening evidence; the WAVs do not have a 100 ms quiet start.
See [Windows playback measurements](WINDOWS_COLLISION_LATENCY.md).

Actual commands:

```powershell
python scripts/review_collision_onset.py
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 TestScript -ScriptPath res://tests/test_collision_source_onset.gd
```

The Python audit passes **9 sustained-source checks** and records rolling RMS,
energy arrival and hashes. The pinned
`4.7.2.stable.official.ed1daf0bf` Godot test passes **18 checks** for three
lossless/import-identical samples, full first-sample attack, strongest sustained
first 10 ms and substantial first-millisecond energy. It exits without a
shutdown warning. The separate PowerShell read-only process/module inspection
confirms the library/path metadata above.

Changed files: `scripts/review_collision_onset.py`,
`game/tests/test_collision_source_onset.gd` and UID, this document,
`DEVELOPMENT_STATUS.md`, `docs/PHASE_0_PLAN.md`, plus retained audit evidence and
a scoped Git review patch. Source report and actual logs are under
`docs/evidence/collision-onset-audit-2026-10-09/`.

No phone attachment check, physical Android test, new acoustic latency
measurement, export/install, full Validate, physics change, backend action or
deployment was performed. No product UI changed. The remaining acceptance is
the owner's Windows listening/timing observation; this audit does not claim
that the overall perceived delay has disappeared.
