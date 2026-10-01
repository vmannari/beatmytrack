# Irregular lightning intensity, 2026-09-30

Requirements: V02/V04/Q01. Owner requests randomized intensity changes within each lightning strike.

The initial revision sampled a short profile once per strike: 2-4 peaks, independently varied rise spacing, peak strengths, dim troughs and a final fade. Strength is bounded to 0.62 and all generated profiles finish within the one-second upper bound (the configured timing ranges permit approximately 0.215-0.84 seconds). Smooth interpolation between timed knots drives the directional light, screen illumination and existing glass highlight together. Rendering never consumes randomness. Pause freezes the current profile age and strength. Each entire strike still schedules one delayed thunder event, and separate strikes retain the existing 9-16-second interval. Canonical simulation and road materials are unchanged.

Changed files: game/track/storm_weather.gd, game/tests/test_storm.gd, this document, status/phase notes and phase screenshots.

Actual command: `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 CaptureStorm -Track track_acf29166cceaaa42` using pinned Godot 4.7.2. Result: 94 checks, zero failures and no engine/shader errors. Added checks exercise 64 seeds for multiple peaks, bounded intensity/duration, random-state stability while sampling, repeatable seeded profiles, variation between seeds and pause freezing. Existing thunder, weather spacing, wet-road reflection and replay checks remain enabled. `git diff --check` passes (line-ending notices only).

Desktop phase captures: [first peak](evidence/storm-lightning-2026-09-30/phase-1.png), [first dip](evidence/storm-lightning-2026-09-30/phase-2.png), [next peak](evidence/storm-lightning-2026-09-30/phase-3.png), [next dip](evidence/storm-lightning-2026-09-30/phase-4.png). The first peak/dip captures were visually inspected. These are timed-knot stills, not a real-time video; owner acceptance of the cadence remains outstanding. No Android export or phone test was performed; device attachment was not checked.

## Slower, softer revision (owner correction)

Owner found the strike and its intensity changes too fast and strong. The current implementation replaces 2-4 sharp peaks with 2-3 broad, shallow swells. Initial rise is 0.16-0.24 seconds; each descent takes 0.18-0.28 seconds, subsequent rises 0.16-0.26 seconds and the last fade 0.30-0.45 seconds. Total configured duration is 0.98-2.05 seconds (2.2-second inactive upper bound). Troughs retain 65-82% of the preceding peak, rather than dropping almost to darkness. Successive peaks vary only by a factor of 0.88-1.10, capped at strength 0.32.

Directional-light gain changes from 8 to 6: maximum added light falls from 4.96 to 1.92 (61% lower). Screen overlay gain changes from 0.65 to 0.40: maximum opacity falls from 0.403 to 0.128 (68% lower). The existing glass highlight follows the lower shared strength. Thunder remains one delayed event; intervals, pause, canonical simulation and reflection materials remain unchanged. There are fewer profile knots, with no new rendering passes or texture work.

Changed files: storm_weather.gd, test_storm.gd, this document, status/phase notes and new captures. Actual command: `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 CaptureStorm -Track track_acf29166cceaaa42`. Result: 95 checks, zero failures and no engine/shader errors. The 64-seed profile check now enforces at least 0.98 seconds, 2-3 peaks and strength <=0.32; an additional sample-rate check limits intensity changes to 0.03 per 1/120 second. Original random variation, seed reproducibility, no random sampling while rendering, pause, thunder and reflection checks remain enabled. `git diff --cached --check` passes.

[First peak](evidence/storm-lightning-soft-2026-09-30/phase-1.png), [shallow dip](evidence/storm-lightning-soft-2026-09-30/phase-2.png), [second peak](evidence/storm-lightning-soft-2026-09-30/phase-3.png), [second dip](evidence/storm-lightning-soft-2026-09-30/phase-4.png). Peak screenshot visually inspected; timing checked through the sampled envelope, not a reviewed real-time video. Owner cadence acceptance remains outstanding. No Android export or physical-phone test; device attachment not checked.


2026-10-01 owner brightness follow-up: directional flash gain increased from 6 to 8.5, retaining the slower envelope, shallow random modulation and 0.40 screen-overlay gain. CaptureStorm passed 95 checks. Evidence and limits: [kit 99](STORM_WET_MATERIAL.md#kit-99-wider-reflection-visibility-and-brighter-lightning-2026-10-01).
