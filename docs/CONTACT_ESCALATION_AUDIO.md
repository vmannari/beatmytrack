# Escalating wall contact audio — 2026-10-09

The owner asks where the remaining collision delay could arise after the WAV
onset was verified. SND20 corrects an additional **game-side dispatch delay**
while preserving SND05/SND14–SND18/G01/R01/Q01/V06: the existing tiny-contact
threshold, single cue per wall episode, immediate live context, cooldown,
pause/reset/rewind fences and unchanged canonical driving.

The observer previously marked the first visible intersection as touching even
when its inward speed was below the audible-impact threshold. A later
accelerating contact was ignored because the cue was allowed only on the
**first touching tick**. The car then waited for its smaller canonical collider;
two vehicle responses were too small to produce any sound at all.

A controlled 0.35 m/s approach followed by full quantized throttle reproduced:

| Car | First audible-contact tick | Old cue tick | Extra dispatch wait | Fixed cue tick |
| --- | ---: | ---: | ---: | ---: |
| Compact | 10 | 34 | **200 ms** | **10** |
| Pickup | 11 | 38 | **225 ms** | **11** |
| Classic | 10 | None | Missing cue | **10** |
| Formula | 10 | 32 | **183.33 ms** | **10** |
| Kart | 8 | None | Missing cue | **8** |

First soft touch is tick2 in these fixtures. The initial small touch still stays
below the existing **1.2** inward-speed threshold; the new cue starts on the
first **currently meaningful** contact, not necessarily on that earlier tiny
touch. The table measures the additional wait **after** the audible threshold
is reached. It does not claim zero time from every faint touch to acoustic output.

`VisibleContactAudio.cue_requested` tracks whether a meaningful cue was attempted
during the current episode. A soft first touch may become meaningful later,
using its already trusted exposed-face normal. Exactly one attempt is made;
cooldown rejection cannot queue a stale later sound. `sounded` still tracks
actual accepted playback and deduplicates the later canonical response. Reset,
separation and airborne/rolled guards clear both fields. Deep/unknown normals,
backing away and shallow incidence retain their existing guards. No future
collision is predicted, and no physics/rules/input/record contract changes.

Other possible delay sources remain:

- **Audio queues and scheduling:** the supported Windows period is still 10 ms;
  queued samples and downstream driver buffers take time to reach output.
- **Windows/device processing:** RAW bypasses optional processing, but not every
  always-on endpoint effect, driver or hardware processing stage.
- **Fallback playback:** unsupported output/format, a custom device selection or
  an unavailable native stream uses ordinary Godot playback. A loaded DLL alone
  does not prove that every live cue used RAW successfully.
- **Visual timing/other geometry:** the mapped-wall and observed footprint cases
  are covered; other objects, projection and frame timing need actual play evidence.

The sound files still have immediate sustained onset. Earlier process-loopback
**39–46 ms** numbers include capture-path timing and are not an exact measurement
of speaker/Bluetooth acoustic latency. No new physical recording was made here.
The available rotating live Godot logs contained no native route marker, so this
turn did not verify the route of the owner's particular audible hit. Startup
route/fallback information is logged by the existing adapter.

Primary references for remaining buffering/processing:
[Microsoft Windows audio latency](https://learn.microsoft.com/en-us/windows-hardware/drivers/audio/low-latency-audio),
[Microsoft RAW processing exceptions](https://learn.microsoft.com/en-us/windows/win32/api/audioclient/ne-audioclient-audclnt_streamoptions),
[Godot audio/graphics timing](https://docs.godotengine.org/en/stable/tutorials/audio/sync_with_audio.html)
(the latter page notes that its text has not yet been updated for Godot4.7;
the actual project tests use the pinned engine).

## Actual checks and scope

All commands use `powershell -NoProfile -ExecutionPolicy Bypass -File
scripts/dev.ps1` and **4.7.2.stable.official.ed1daf0bf**:

```powershell
TestScript -ScriptPath res://tests/probe_slow_wall_audio.gd
TestScript -ScriptPath res://tests/test_contact_escalation_audio.gd
TestScript -ScriptPath res://tests/test_visible_wall_audio.gd
TestScript -ScriptPath res://tests/test_effect_timing.gd
TestScript -ScriptPath res://tests/test_windows_impact_audio.gd -Graphical
TestApp
TestRewind
TestScript -ScriptPath res://tests/test_script_parse.gd
CheckScript -ScriptPath res://vehicle/visible_contact_audio.gd
CheckScript -ScriptPath res://track/night_ambience.gd
```

The new **65 checks pass**: five cars/two initial soft speeds, exact plain versus
audio-observed snapshots on every step, same-tick threshold cue, one cue through
later physical contact, canonical-first deduplication and no stale cooldown retry. Existing wall **167**,
timing **43**, actual Windows native **16**, App **99** and rewind **61** checks
pass. An earlier timing run retains a **31 ObjectDB shutdown-reference warning**;
the final timing run is clean. The final 65-check escalation test retains a
**66-reference shutdown warning**, without evidence here of a runtime leak.
The final probe exits cleanly. Initial full parsing failed because
concurrent `night_ambience.gd` preloaded a missing `night_cicadas.wav`. The asset
then appeared; both focused script checks pass and the repeated full parser
passes **406 scripts, zero failures**.
The initial missing-asset failure is retained without modifying that other task.

Changed runtime file: `game/vehicle/visible_contact_audio.gd`. Diagnostics:
`game/tests/probe_slow_wall_audio.gd`, `test_contact_escalation_audio.gd` and UIDs.
Records: this note, `DEVELOPMENT_STATUS.md`, `docs/PHASE_0_PLAN.md` and scoped
evidence/checkpoint in `docs/evidence/contact-escalation-audio-2026-10-09/`.
No WAV, native DLL, volume, collider, simulation or backend changes were made.

Restart the Windows game to load the changed contact observer and listen while
gently entering a wall, then accelerating. Actual listening on the owner's
speakers/Bluetooth, other obstacle/geometry cases and complete acoustic latency
remain acceptance checks. No phone attachment check, physical Android test,
new microphone/acoustic recording, export/install, full Validate, physics merge
or deployment was performed. There is no product UI change requiring screenshots.
