# Irregular lightning intensity, 2026-09-30

Requirements: V02/V04/Q01. Owner requests randomized intensity changes within each lightning strike.

StormWeather now samples a short profile once per strike: 2-4 peaks, independently varied rise spacing, peak strengths, dim troughs and a final fade. Strength is bounded to 0.62 and all generated profiles finish within the one-second upper bound (the configured timing ranges permit approximately 0.215-0.84 seconds). Smooth interpolation between timed knots drives the directional light, screen illumination and existing glass highlight together. Rendering never consumes randomness. Pause freezes the current profile age and strength. Each entire strike still schedules one delayed thunder event, and separate strikes retain the existing 9-16-second interval. Canonical simulation and road materials are unchanged.

Changed files: game/track/storm_weather.gd, game/tests/test_storm.gd, this document, status/phase notes and phase screenshots.

Actual command: `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 CaptureStorm -Track track_acf29166cceaaa42` using pinned Godot 4.7.2. Result: 94 checks, zero failures and no engine/shader errors. Added checks exercise 64 seeds for multiple peaks, bounded intensity/duration, random-state stability while sampling, repeatable seeded profiles, variation between seeds and pause freezing. Existing thunder, weather spacing, wet-road reflection and replay checks remain enabled. `git diff --check` passes (line-ending notices only).

Desktop phase captures: [first peak](evidence/storm-lightning-2026-09-30/phase-1.png), [first dip](evidence/storm-lightning-2026-09-30/phase-2.png), [next peak](evidence/storm-lightning-2026-09-30/phase-3.png), [next dip](evidence/storm-lightning-2026-09-30/phase-4.png). The first peak/dip captures were visually inspected. These are timed-knot stills, not a real-time video; owner acceptance of the cadence remains outstanding. No Android export or phone test was performed; device attachment was not checked.
