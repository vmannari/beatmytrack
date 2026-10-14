# Irregular blowing powder — 2026-10-12

The owner requests less synchronized movement and direction in the powder. Winter-wind-8 retains a shared prevailing wind, with locally different speed, sideways motion, plume shape and gust phase. It preserves the existing thin drifting-snow appearance and fixed mobile geometry budget.

| Requirement | Implemented behavior |
| --- | --- |
| WE33 / V04 | Slow, spatially varying shear deforms the advected field. Bank plumes meander from pinned crest sources with separate layer phases. Local pulses break synchronized density changes; sparse airborne grains share the flow variation. |
| WE34 / V05 / G01 / R01 / Q01 | World-space motion, exact pause/background/retry lifecycle and opaque car protection remain. Keep three batches, 49 ground sheets, 36 bank layers and 24 airborne grains; no added texture samples or per-frame CPU particle work. Actual GPU/render checks and desktop measurements. |

## Changed files

- `game/track/winter_wind_variation.gdshaderinc`: new shared world-coordinate/visual-clock helper. Bounded low-frequency phases vary offset and local density. Evaluate this at vertices, then interpolate; no new per-pixel sine/noise computation or texture lookup is introduced.
- `game/track/winter_snow_wind.gdshader`: apply local offsets to the existing world-space density field, preserving its frayed finger texture and depth/solid-height guards. Bank ribbons sway laterally after the anchored source, with independent layer phases. Local gust modulation never exceeds the prior opacity ceiling.
- `game/track/winter_air_snow.gdshader`: sparse grains receive a smaller version of the same variation. Camera orientation does not change the prevailing physical direction.
- `game/track/winter_snow_wind.gd`: visual version8 only. Existing CPU placement, refresh rates, AABBs, amount limits, audio envelope, calm floor and shared 24 m/s strong-gust advection remain.
- `game/tests/test_winter_snow_wind.gd`: clarify the gust assertion's description as shared advection; its value and tolerance remain unchanged.
- `game/tests/test_winter_local_flow.gd`: inherit all prior wind/depth/car tests. A diagnostic replaces only the production shader's fragment with false-colour offset encoding, retaining its actual vertex stage. This checks spatially different motion in both axes, actual pixel-exact pause freezing and unchanged canonical snapshots. It restores material/camera/visibility afterward and adds no shipping debug branch.
- `game/tests/profile_winter_desktop.gd`: the explicit unscored diagnostic now resumes focus-suspended wind alongside the game. Record and require its visual clock to advance for at least95% of a visible-wind sample; ordinary game/background pause behavior remains unchanged.
- `DEVELOPMENT_STATUS.md`, `docs/PHASE_0_PLAN.md` and this report record actual scope and acceptance.

No terrain, bank geometry, road material, camera, simulation/rules, compiler/backend contract, asset bitmap, audio loop or particle count changes. The flow is a lightweight visual approximation, not a fluid/terrain-airflow simulation.

## Actual verification

Commands used `scripts/dev.ps1`, process-local execution-policy bypass and pinned Godot `4.7.2.stable.official.ed1daf0bf`. [Actual logs](evidence/winter-local-flow-2026-10-12/logs/).

| Arguments to `scripts/dev.ps1` | Result |
| --- | --- |
| `-Action TestScript -ScriptPath res://tests/test_winter_snow_wind.gd -Graphical -TestArgument @('--capture','--video','--output-dir=res://../docs/evidence/winter-local-flow-2026-10-12/native')` | Initial existing suite: 47 checks, zero failures. |
| `-Action TestScript -ScriptPath res://tests/test_winter_local_flow.gd -Graphical -TestArgument @('--capture','--video','--output-dir=res://../docs/evidence/winter-local-flow-2026-10-12/native')` | Final Compatibility: 51 checks, zero failures. GPU probe2988 samples; approximate encoded offset-velocity spread8.387 / 9.179 m/s across regions. Exact paused image and canonical snapshot preserved. CPU presentation benchmark11.278 µs/call. |
| Same local-flow script with `-RenderingMethod mobile -RenderingDriver vulkan`, output `.../mobile` | 51 checks, zero failures. GPU probe3169 samples; offset-velocity spread7.028 / 7.604 m/s. Exact paused image and snapshot preserved. CPU presentation benchmark12.685 µs/call. Desktop Mobile Vulkan is not a phone test. |
| `-Action Doctor` | Correct engine/templates/tools found; ADB device list empty. |

The false-colour probe measures variation produced by the actual vertex stage, not total wind velocity or a precise physical speed bound. Display encoding/quantization varies by renderer. Compatibility opaque roof723 / moving761,751,750 and Mobile opaque743 / moving771,758,759 remain unchanged. All moving interior AA samples are unchanged; dark-light delta is zero. No visibility or pause assertion was weakened. Final cross-renderer suite total: **102 passed, zero failures**.

Both stationary motion previews contain120 distinct frames out of120. These are actual normal-rendering captures, not the diagnostic colours.

## Actual desktop cost

Independent command: `-Action TestScript -ScriptPath res://tests/profile_winter_desktop.gd -Graphical -TestArgument @('--document=C:/Users/ville/AppData/Roaming/Circuit01Lab/cloud/fe772d2e756f39f351786a6c81dcb401f381848c01d5ea2cfdc05969d0cf0aed/cd0b5ca436fd1dd3e15256ba506fa528792e351bd6df13dbbaa49681d8e75262.json','--tag=local-flow','--profile-dir=res://../docs/evidence/winter-local-flow-2026-10-12/performance','--4k','--seconds=20','--modes=full,no_wind,full_repeat')`.

RTX3090, 3840×2160, scale1, 2× MSAA, diagnostic VSync off. Each stage advances2400–2401 simulation ticks and its wind clock about20 s. Visible runs retain36 bank layers; strength at the end0.947 / 0.796.

| Mode | Frame median / p95 | GPU median | Frames >16.667 ms |
| --- | --- | --- | --- |
| Full | 3.266 / 4.827 ms | 2.487 ms | 0 |
| Wind hidden | 2.952 / 4.519 ms | 2.221 ms | 0 |
| Full repeat | 3.318 / 4.986 ms | 2.531 ms | 0 |

Visible375 vs hidden372 draws and578 additional submitted triangles match the original wind ceiling. The roughly0.27–0.31 ms median GPU difference includes the entire wind effect, not solely the new variation. Sequential short samples vary with desktop load; no all-PC/phone performance or exact incremental-cost guarantee is made. [Raw measurements](evidence/winter-local-flow-2026-10-12/performance/desktop-local-flow-gl_compatibility.json).

An earlier diagnostic run did not validate the wind's focus-suspended clock. Its repeat submitted only two wind batches, so it is excluded from active-wind cost claims and retained as `focus-state-unverified.json`. The diagnostic now explicitly resumes and fences the visual clock. Real gameplay still freezes on focus loss.

## Review and limits

[Stationary powder motion](evidence/winter-local-flow-2026-10-12/native/motion.html), [actual driving motion](evidence/winter-local-flow-2026-10-12/native/driving-motion.html), [Mobile motion](evidence/winter-local-flow-2026-10-12/mobile/motion.html), [curve still](evidence/winter-local-flow-2026-10-12/native/bend.png), [GPU motion data](evidence/winter-local-flow-2026-10-12/native/local-motion-probe.json).

Restart the client to load the shader revision. Owner motion/readability review in the selected cameras and on varied creator tracks remains. No phone is attached and no physical-device visual/performance/thermal/touch test, Android export/install, full Validate, physics regression, backend test/deployment or live write was performed. Original art provenance remains.

Task-only checkpoint/source patch are under `build/winter_local_flow`; large motion HTML remains in workspace evidence rather than being duplicated into the checkpoint. The main Git index/branch and unrelated work remain unchanged.
