# Persistent Windows contact-sound timing — 2026-10-23

Follow-up: the owner's Compact/bridge case exposed incomplete detailed-body
coverage at narrow rail ends. The [Compact bridge correction](COMPACT_BRIDGE_AUDIO_2026_10_23.md)
reproduces and removes that detection delay. The measurements below remain the
earlier flat-wall/kerb investigation; its remaining output latency is unchanged.

WCT01-WCT03/R01/Q01 investigate the owner's confirmation that collision and kerb
sounds have always felt delayed on Windows, through speakers as well as Bluetooth,
and persist after restarting. **The reported problem remains unresolved.** Neither
Bluetooth nor a stale running process is established as its explanation. This task
adds reproducible diagnostics; it does not claim a runtime fix or a before/after
improvement.

The earlier 54-check inspection established immediate dispatch and measured gain
changes in the continuous output. It did not establish perceptual synchronization
in the owner's actual driving case. The new diagnostics run the actual Game with
normal rendering and real fixed-rate callbacks, after asynchronous preparation is
complete. They use neutral input, local synthetic geometry, isolated application
data and capture only their own process tree. No owner game is controlled or
recorded, and no microphone or unrelated application is captured.

## Actual measurements

All times below are milliseconds from the request to **software process output**,
without subtracting a capture offset. They exclude acoustic speaker/headphone
timing. A completed rendered frame is not monitor scanout.

| Contact / selected path | 5 m/s | 15 m/s | 30 m/s |
| --- | ---: | ---: | ---: |
| Normal wall hit / Windows RAW event | 41.48 | 36.48 | 42.48 |
| Kerb entry thud / Windows RAW event | 35.38 | 38.26 | 34.22 |
| Kerb rolling / Windows mixed output | 52.82 | 52.53 | 58.76 |

The normal wall request and rendered footprint first touch share ticks 74/25/13.
Rendered-footprint-to-output timing is 33.48/27.48/34.48 ms. The physical circle
responds later on ticks 88/29/15. A diagnostic control disabling the early outline
still requests the sound on the physical-response tick exactly; its rendered
footprint-to-output timing is 149.48/62.48/49.48 ms. This control demonstrates a
possible geometry gap; it does **not** establish that the owner's game misses the
outline check.

For all six kerb trials, first qualifying wheel contact and playback request share
ticks 46/16/8. Time from the beginning of that physics callback to the request is
0–1 ms. Exactly one entry is registered in each trial, and there is no wall
collision. The entry and rolling paths are isolated from one another and from
engine, gear, music and nature sounds, using the same production contact and
playback methods. The car keeps rendering and stepping until its actual rendered
wheel centre reaches the raised surface. Wheel-centre-to-output timing is
18.22–30.26 ms for entry and 35.82–44.53 ms for rolling. This is not exact contact
between the tyre's curved 3D surface and the kerb.

The current source crash WAVs cross amplitude .01 at frame zero; chassis crosses
it at 0.091 ms. The preceding inspection retained those source hashes and first
10 ms RMS measurements under
`build/windows-contact-followup-2026-10-23/report.json`. Source onset does not
establish acoustic latency or exclude masking in the complete driving mix.

## Reproduction and changes

Use the pinned `4.7.2.stable.official.ed1daf0bf` through the normal entry point:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/probe_windows_contact_timing.ps1 -Kind direct -Label baseline-r2
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/probe_windows_contact_timing.ps1 -Kind kerbs -Label baseline-r2
python scripts/review_direct_collision_output.py build/windows-contact-timing-2026-10-23/baseline-r2/direct
python scripts/review_kerb_contact_output.py build/windows-contact-timing-2026-10-23/baseline-r2/kerbs
```

Labels must be new; the launcher refuses to overwrite a capture. It starts a
separate hidden helper, waits for the diagnostic's own PID, records that process
tree for 30 seconds and reviews valid packet timestamps. `-Kind events` and
`-Kind surfaces` expose the existing isolated event/gain-change probes through the
same launcher. Actual task receipts and hashes are in
[the evidence report](evidence/windows-contact-timing-2026-10-23/report.json).

- `probe_direct_collision_output.gd` now accepts a capture directory and waits
  for real preparation, then disables automatic physics again after installation
  restores processing. Its existing one-cue and canonical-tick assertions remain.
- `probe_kerb_contact_output.gd` observes the real Game callback, isolates the
  entry and rolling paths, and timestamps the actual rendered wheel centres.
- The two reviewers accept explicit output directories and retain dispatch,
  route, single-entry and source/render/output timing checks. Direct review
  passes **30** checks; kerb review passes **39** checks. The kerb script check
  and both Python compilations pass. Earlier surface/impact suites passed
  **36/18** checks; they are not a reproduction of the owner's perceptual report.
- Nine relevant gameplay/audio runtime sources and the selected extension
  manifest remain byte-identical to task start. No native library, bank asset,
  physics, camera, gain or output configuration was changed. The normal launcher
  still refreshes its generated client build identity.

Initial diagnostic failures are retained. The first wall run allowed installation
to restore automatic physics, contaminating its supposedly manual trials; the
final fixture reapplies its processing fence after readiness. The first kerb run
froze physics on the first qualifying point, before the transformed rendered
wheel reached the surface; the final fixture continues normal stepping and
retains the first-contact/request tick assertion. No production timing change or
weakened assertion is used to obtain the final results. Cold preparation/render
hitch messages remain in the raw diagnostic logs.

Upstream references consulted while inspecting output buffering:
[Microsoft shared-stream initialization](https://learn.microsoft.com/en-us/windows/win32/api/audioclient/nf-audioclient-iaudioclient3-initializesharedaudiostream)
and [Godot hard-limiter source](https://github.com/godotengine/godot/blob/master/servers/audio/effects/audio_effect_hard_limiter.cpp).
Upstream source is background context, not proof of the pinned engine's exact
acoustic timing or justification for changing its DSP.

## Remaining investigation

The exact owner car, track and collision object have been requested so that walls,
tyres and other prop paths are not treated as interchangeable. No actual owner
case or acoustic measurement has yet established why the persistent perceived
delay remains. Different capture fixtures and mixer phases are not a before/after
improvement. No verified runtime fix, zero-latency claim, Bluetooth attribution or
restart-based resolution is claimed. No phone/tablet test, APK/export/install,
account/backend mutation or deployment was performed. Concurrent work remains.
