# Compact bridge-impact audio correction — 2026-10-23

CBT01-CBT03/R01/Q01 follow the owner's specific case: Compact, head-on against a
bridge, with a persistent delay on Windows but no noticeable delay on the tablet.
The earlier flat-wall diagnostics did not cover a narrow bridge rail end.

**A detailed-Compact contact-detection defect is reproduced and corrected.**
This fixes the reproduced bridge-end delay; it does not claim to fix the separate
Windows output-buffer delay or kerb playback latency. Owner listening remains.

## Cause and correction

The actual detailed Compact has an 88-point closed convex outline. The observer
checked both endpoints of every edge, asking for 203 probe calls, then stopped at
the existing 128-call ceiling. Duplicate shared endpoints consumed the allowance
before the complete perimeter was checked. A rail end touching the omitted nose
corner could therefore wait for the smaller physical collision circle, or miss
the eligible body-contact sound entirely.

`VisibleContactAudio.sample()` now leaves each edge's endpoint to the following
edge. The same outline needs **116** unique probes and fits the existing bound.
The closed polygon's first point also owns the final closing endpoint. The
normal/angle/strength gates, bridge-layer exclusions, current-contact requirement,
cooldown, duplicate-cue latch and original samples/output routes are unchanged.
No prediction of future contacts is introduced. Handling, collision physics,
damage, visual models, camera and track geometry are unchanged.

The independent coverage test visits every actual hull vertex on all five real
cars, both detailed and simplified models, at four headings, while asserting the
same 128-probe bound, clear-track silence and exact unchanged simulation state.
The exact original `sample()` method fails four of 160 checks, all for the
detailed Compact. The correction passes all 160 in headless, Compatibility and
desktop Mobile rendering. The simplified Compact's original coverage passes;
this is consistent with a model-detail difference, but **the tablet's actual
model setting was not inspected**, and no device-level cause is claimed.

## Reproduction on the cached bridge

A read-only check of the saved local selection found Compact / **Knot**. Its
current-format local cached document has source SHA-256
`c237960ed63d03361858789517d02a3bb742740fe3795753bed3a12e6de53b13` and two bridge
spans. This was a local reproduction starting point, not confirmation from the
owner of the exact track or impact position. No account/session file contents were
copied or printed, and no backend request was made.

The 168-case matrix covers both spans, both sides/ends, low sides, undersides,
upper rails and head-on rail-end offsets at initial 5/15/30 m/s. Every physics
step is compared with an observer-free simulation using identical inputs. All
canonical states and physical-contact ticks remain exact. The original method
misses six eligible sounds and has 47 rail-end cases more than one tick late or
missing. The correction removes all six misses and improves 57 cases overall.

In the strongest matched case, the original waits until physical-contact tick
39; the correction sounds on eligible body-contact tick 22, with physical
contact still at tick 39. This removes **17 nominal physics ticks / 141.67 ms**
of detection delay. At 15/30 m/s the matched cue advances 13→8 and 7→4 ticks.

The matrix's dense independent reference uses 5 cm perimeter samples; production
retains its previous 25 cm target at this grid size. Two narrow-edge cases still
trail that denser reference by 2/4 ticks. No universal exact-3D-contact claim is
made, and those differences are retained in the review.

## Actual rendered Windows output

One native Compatibility session interleaves the exact original and corrected
observer methods on the actual Game, Compact and cached bridge. It waits for
real asynchronous preparation, uses neutral input and normal rendering, and
captures only its own process tree. The same native Windows RAW event path is
confirmed in all six trials, with one cue per trial and identical physical-hit
ticks. Other buses are muted to isolate the impact.

| Initial speed | Original rendered footprint → output | Corrected | Original / corrected request → output |
| --- | ---: | ---: | ---: |
| 5 m/s | 155.98 ms | **19.98 ms** | 31.98 / 35.98 ms |
| 15 m/s | 62.98 ms | **32.98 ms** | 37.98 / 41.98 ms |
| 30 m/s | 57.98 ms | **32.98 ms** | 41.98 / 40.98 ms |

These are software process-output measurements, with no fixed capture offset
subtracted. Rendered contact is a sampled footprint against the current solid
grid at `frame_post_draw`, not exact tyre/body-triangle intersection, monitor
scanout or acoustic speaker/Bluetooth timing. The Windows request-to-output
delay remains; the improvement is earlier, correctly covered contact detection.
The screenshot is captured after timing is complete so image readback cannot
stall the measured contact interval.

[Actual bridge view](evidence/compact-bridge-impact-2026-10-23/bridge-contact.png) ·
[Evidence report](evidence/compact-bridge-impact-2026-10-23/report.json).

## Commands and checks

All engine checks use pinned `4.7.2.stable.official.ed1daf0bf` through
`scripts/dev.ps1`. Isolated application data is used for the final checks and
capture. Actual wrappers/receipts are retained in the report.

```powershell
# Matrix controls used --baseline and separate baseline/fixed output folders.
# The probe also accepts --document=<local current-format document>.
powershell -NoProfile -ExecutionPolicy Bypass -Command "& './scripts/dev.ps1' -Action TestScript -ScriptPath res://tests/probe_compact_bridge_contacts.gd -TestArgument @('--baseline','--output-dir=res://../build/compact-bridge-impact-2026-10-23/baseline')"
powershell -NoProfile -ExecutionPolicy Bypass -Command "& './scripts/dev.ps1' -Action TestScript -ScriptPath res://tests/probe_compact_bridge_contacts.gd -TestArgument @('--output-dir=res://../build/compact-bridge-impact-2026-10-23/fixed')"
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/probe_windows_contact_timing.ps1 -Kind bridge -Label bridge-original-fixed-r1
python scripts/review_compact_bridge_impact.py
powershell -NoProfile -ExecutionPolicy Bypass -File build/compact-bridge-impact-2026-10-23/run_checks.ps1 -Baseline
powershell -NoProfile -ExecutionPolicy Bypass -File build/compact-bridge-impact-2026-10-23/run_checks.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File build/compact-bridge-impact-2026-10-23/run_checks.ps1 -Graphical
powershell -NoProfile -ExecutionPolicy Bypass -File build/compact-bridge-impact-2026-10-23/run_checks.ps1 -Graphical -RenderingMethod mobile
```

| Actual check | Outcome |
| --- | --- |
| Exact-original coverage control | 160 checks / 4 expected reproduced coverage failures. |
| Corrected coverage, headless / Compatibility / desktop Mobile | 160 / 160 / 160, zero failures. |
| Original/corrected bridge matrix plus native paired review | 168 cases each; 2034 review checks, zero failures. |
| Existing visible-wall audio | 167 checks, zero failures, all five cars. |
| Existing bridge-contact audio | 42184 checks, zero failures; 180 clear sweeps, zero false crashes. |
| Existing contact escalation / bridge physics | 65 / 16 checks, zero failures. |
| Collision trace / kerb physics response | 9 / 26 checks, zero failures. |
| Full script parser | 1039 scripts, zero failures. |
| Python reviewer compilation / scoped whitespace / patch check | Actual receipts retained in the checkpoint. |

The initial bridge matrix remained an investigation and asserted canonical
equivalence; it did not call late/missing audio a pass. Original and corrected
sources/JSONs are retained separately. One first wrapper invocation was blocked
by shell execution policy; another incorrectly expanded the child APPDATA
assignment and used the usual Godot log location. That headless matrix does not
load or save owner records; subsequent checks and the paired native capture use
isolated storage. A broader pre-existing trace fixture also expected playback
while production headless output was deliberately disabled. Its setup now
explicitly enables the Godot fallback it tests, retaining all nine assertions.
No production headless output gate was changed, and the initial failure is kept.

## Scope and remaining acceptance

The production change is three added lines and one removed line in
`game/vehicle/visible_contact_audio.gd`. Diagnostics add the complete-coverage
test, bridge matrix, paired actual-Game capture, reviewer and bridge launcher
option; the trace fixture has explicit deterministic playback setup. A task-only
Git-checkable patch preserves the shared index and concurrent work.

Restart/reload the Windows client to load the changed script, then owner-listen
to the reported bridge hit. This is application of a new correction, not an
attribution of the longstanding issue to stale processes. Kerb sound timing and
the remaining Windows output delay are unchanged by this correction. No tablet
attachment check or physical-device test, microphone/owner-process capture,
APK/export/install, native rebuild, account/backend mutation or deployment was
performed. Existing owner processes and concurrent work remain intact.
