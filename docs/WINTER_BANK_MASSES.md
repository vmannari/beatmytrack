# Winter ploughed banks and whiter snow — 2026-10-12

The owner rejects the regularly rounded banks and supplies a close-up of irregular ploughed snow. The owner also requests whiter blue areas in the existing terrain texture. This is a cosmetic revision; reference-level quality still requires owner review.

| Requirement | Implemented behavior |
| --- | --- |
| WE25 / V04 | Steeper ploughed face, broken broad upper shelf, uneven packed fragments and a buried outer apron; replace the repeated rounded triplets and symmetric hill profile. |
| WE26 / V04 | Selectively lift the original terrain artwork's blue pigment toward white while retaining its detail and actual lighting shadows. |
| WE21–WE24 / V05 / G01 / R01 / Q01 | Retain Grass-style frost coverage, directional ice, sparse slim stakes, indexed/cached geometry, camera framing and canonical data; check both renderers and desktop driving cost. |

## Changes

- `game/track/native_track_visual.gd`: visual cache version advances from the captured concurrent baseline 133 to 142. A seeded, build-time packed-cell field varies across and along the bank. A steep inner face leads into an irregular upper shelf, rather than a symmetric rounded ridge. Small fragments have varying footprints, orientations, heights and flattened uneven caps; their feet follow the actual bank slope. Two or three independently placed fragments per patch retain the maximum 80 patches / 240 fragments. Normals sample the mesh's actual footprint instead of unresolved infinitesimal noise derivatives. Twelve cross-section points concentrate resolution on the bank face; 0.28 m longitudinal sections replace Winter's 0.20 m sampling. Other biomes keep their prior spacing. Existing row/UV caches, indexed buffers, masks, snow-only shader path and buried terrain join remain.
- `game/track/surface_detail.gdshaderinc`: the original two snow texture samples are unchanged. Blue pigment receives up to 42% blending toward a neutral white derived from that sample. Ground and bank use the same function. No extra texture lookup or per-frame procedural noise is introduced.
- `game/tests/test_winter_environment.gd`: current evidence destination and optional `--bank-detail` close-up. The close-up hides the HUD and temporarily changes only the diagnostic camera; ordinary gameplay captures and production camera remain unchanged.
- `game/tests/profile_winter_desktop.gd`: selectable evidence directory, diagnostic-only resumption after focus pauses, and rejection of samples advancing fewer than 95% of expected simulation ticks. This explicitly unscored diagnostic does not alter ordinary race pause behavior.
- `game/tests/profile_winter_road_build.gd`: selectable baseline/output paths retain the existing exact mesh-buffer parity requirement. Per-row shape reuse uses 64-bit values to avoid changing geometry.

No new art asset, collision object, compiler contract, simulation rule, particle system, draw call or backend change is introduced. The original road artwork, material treatment, terrain texture, scenery, stakes and lighting are retained. Early spiky and oversized-fragment prototypes are archived under `evidence/winter-bank-masses-2026-10-12/rejected-spiky`; they are not the final captures.

## Actual checks and commands

All engine commands used `scripts/dev.ps1`, pinned Godot `4.7.2.stable.official.ed1daf0bf`, after process-local execution-policy bypass. Saved command output is under [logs](evidence/winter-bank-masses-2026-10-12/logs/).

| Command arguments to `scripts/dev.ps1` | Result |
| --- | --- |
| `-Action TestScript -ScriptPath res://tests/test_winter_environment.gd -Graphical -TestArgument @('--capture','--fresh-roads','--bank-detail','--video')` | Final kit142 Compatibility: 101 checks, zero failures. Fresh construction exercises the real taper width attributes, bridge widths, sparse poles, terrain join, editable scenery and canonical separation. |
| Same environment script with `-Graphical -RenderingMethod mobile -RenderingDriver vulkan -TestArgument @('--capture','--fresh-roads','--bank-detail')` | Final kit142 Mobile Vulkan: 100 checks, zero failures. |
| `-Action TestScript -ScriptPath res://tests/test_winter_snow_wind.gd -Graphical -TestArgument @('--capture','--video','--output-dir=res://../docs/evidence/winter-bank-masses-2026-10-12/wind-validation')` | Kit141: 47 checks, zero failures. Opaque static roof 723 samples / moving roofs 761, 751, 750 unchanged; interior AA samples unchanged; dark-light delta zero. Final kit142 produces byte-identical road/bank buffers. Short concurrent wind GPU timings are not used as performance evidence. |
| `-Action Doctor` | Correct engine/templates and tool prerequisites found; ADB device list empty. |

Performance commands read the local cached Slippery document only. The exact `--document` argument was `C:/Users/ville/AppData/Roaming/Circuit01Lab/cloud/fe772d2e756f39f351786a6c81dcb401f381848c01d5ea2cfdc05969d0cf0aed/cd0b5ca436fd1dd3e15256ba506fa528792e351bd6df13dbbaa49681d8e75262.json`.

- `-Action TestScript -ScriptPath res://tests/profile_winter_desktop.gd -Graphical -TestArgument @('--document=<path above>','--tag=bank-masses','--profile-dir=res://../docs/evidence/winter-bank-masses-2026-10-12/performance','--4k','--seconds=20','--modes=full,full_repeat')`: kit141 full runs advance 2,400 ticks each. Frame median 2.813 / 2.826 ms, p95 3.823 / 3.883 ms, worst 5.815 / 6.966 ms; no frames over 16.667 ms. RTX3090, 3840×2160, scale 1, 2× MSAA, VSync disabled for diagnostic. 375 draws, about 550,500 submitted primitives. [Raw measurements](evidence/winter-bank-masses-2026-10-12/performance/desktop-bank-masses-gl_compatibility.json).
- Same desktop command with `--tag=bank-masses-final` and `--modes=full`: final kit142 advances 2,399 ticks / 78.918 m in the 20 s sample. Frame median 3.170 ms, p95 4.433 ms, p99 5.544 ms, worst 8.714 ms; no frames over 16.667 ms. GPU median 2.456 ms / p95 2.984 ms. Final measurements are saved separately in [final measurements](evidence/winter-bank-masses-2026-10-12/performance/desktop-bank-masses-final-gl_compatibility.json). These short samples vary with desktop load and do not establish a numerical frame-time improvement.
- `-Action TestScript -ScriptPath res://tests/profile_winter_road_build.gd -Graphical -TestArgument @('--document=<path above>','--baseline=res://../docs/evidence/winter-bank-masses-2026-10-12/before-shape-reuse.gd','--output=res://../docs/evidence/winter-bank-masses-2026-10-12/performance/road-build-shape-reuse.json')`: two alternating samples per implementation, visual mesh caches disabled. Kit141 3221.448 / 3202.972 ms; kit142 3303.182 / 3135.449 ms. Approximately 3.2 s for either, within measurement variation; no claimed speedup. All four complete mesh-buffer hashes match `309d60e5dca3e4cdb2ace73b2ae65f84b33271b6b3130ebc35d9735ea55857c2` (224,409 road vertices / 257,607 indices). This parity proves the shape-parameter reuse only; the earlier kit133 bank morphology intentionally changed. [Cold-build measurements](evidence/winter-bank-masses-2026-10-12/performance/road-build-shape-reuse.json).

The first desktop attempt used an incorrect cache path and failed before measuring. A subsequent sample lost focus and advanced only 765 ticks; it is preserved as `partial-focus-paused.json`, excluded from full-driving claims, and prompted the diagnostic tick fence. Neither failed/incomplete attempt is reported as passed.

Fixture submission is 372,717 primitives and 314 Compatibility / 330 Mobile draws. Slippery's indexed bank is 55,971 vertices / 257,607 indices; compared with the previous Winter performance evidence, bank indices fall about 9.4%. Vertex count rises about 2.5% from the additional across-bank samples and fragment facets. The prior cache and indexing savings are retained.

## Review and limits

[Actual driving](evidence/winter-bank-masses-2026-10-12/driving.png), [driving motion](evidence/winter-bank-masses-2026-10-12/driving-motion.html), [bank close-up](evidence/winter-bank-masses-2026-10-12/bank-detail.png), [material-only bend](evidence/winter-bank-masses-2026-10-12/materials.png), [rotated view](evidence/winter-bank-masses-2026-10-12/rotated.png), [Mobile close-up](evidence/winter-bank-masses-2026-10-12/mobile/bank-detail.png), [prior appearance](evidence/winter-bank-masses-2026-10-12/before-materials.png).

Restart the client to replace already prepared worlds. Owner visual acceptance against the close-up reference remains open, including tight/overlapping user-track shoulders, the selected camera and full racing laps. The RTX3090 results do not establish all-PC or Android performance; cold road construction still takes about 3.2 s on this machine without a visual cache. No phone is attached and no physical-device performance/thermal/touch test, Android export/install, full Validate, physics regression, backend test/deployment or live write was performed.

Task-only checkpoint/patch are under `build/winter_bank_masses`; unrelated workspace work and the main Git index/branch are preserved. Original asset provenance remains unchanged.
