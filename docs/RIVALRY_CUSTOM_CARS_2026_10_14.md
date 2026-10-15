# Customised Weekly Rivalry podium — 14 October 2026

The top three Weekly Rivalry cards now display native renders of the cars their drivers customise in Garage. This supersedes the previous compact-hub instruction to omit vehicle pictures.

Requirements: **RPC01** each leader's actual car and appearance; **RPC02** bounded authenticated sharing; **RPC03** compact, scrollable hub and static render cost; **RPC04** safe legacy, account and condition handling. Existing **WR01–WR03 / R01 / V03–V05 / Q01** navigation, scoring, presentation and evidence requirements remain.

Each card uses the championship's pinned vehicle with that driver's three paint pigments, wrap, independent hood/roof sticker placement, scale/rotation and four Compact part IDs. Your own card immediately reads your current local Garage selections. Other drivers use their latest shared appearance for that vehicle. This is current cosmetic presentation, not a race-result or handling pin. Players without shared data use the native factory finish; mismatched or malformed cosmetic fields cannot load arbitrary assets. Artificial drivers retain their actual factory appearance unless they have saved cosmetics.

The three pictures reuse `rivalry_victory_car.gd`, the same production `CarVisual` used by awards, with transparent one-shot SubViewports. Existing finale presentation and its local condition remain. Podium cars are clean; **dirt, snow, washing history and accumulated condition are never uploaded**. There are at most three extra native viewports and no continuously rendered car pictures after they settle. The gold winner stays slightly taller. Cards are 184/172 layout units high; full-app standings retain 216 units of vertical scroll space at the tested widths, with all five tracks and existing detail-based Race actions intact.

`PUT /v1/rivalry/appearance` stores only the authenticated player's appearance for one of five fixed vehicles. Strict bounded fields reject arbitrary asset names, colours outside six-digit RGB, out-of-range sticker placement, nonfinite numbers, extra fields (including condition/player IDs), incorrect versions and Compact parts on other chassis. The packaged allowlist contains 49 paint/wrap choices, 25 sticker choices including None, and the existing 10/13/10/10 kit IDs. A regression check compares it with the actual native catalogs. One bounded JSON column on `players`, introduced by additive migration **0035_rivalry_car_appearance**, holds at most those five appearances. Updates acquire the player lock and retain the existing erasure fence. Account deletion clears the shared values; snapshot redaction also removes an affected driver's appearance. The privacy policy describes this online copy of Garage choices.

Snapshots add optional `appearance` data to overall standings in one batch query. Track rows, scoring, tickets, physics/rules/handling/compiler pins, PB eligibility and verification do not use cosmetics. The client syncs changed appearance before membership refresh/join, reuses successful values within the authenticated service/player/car scope, and retries failures. Reset and account changes reject stale callbacks. A race start launches cosmetic sync without awaiting it, preserving independent fresh ticket authorization. Older servers and legacy snapshots remain usable, with factory remote cars until the matching backend is available.

Changed files:

- `game/ui/weekly_rivalry_page.gd`: native leader pictures and compact loading geometry.
- `game/backend/weekly_rivalry_client.gd`, `game/core/app.gd`: scoped appearance provider/sync.
- `backend/bmt_backend/rivalry.py`, `identity_models.py`, `vehicle_appearance.py`, `vehicle_appearance_catalog.json`, `migrations/versions/0035_rivalry_car_appearance.py`: storage, authenticated validation and snapshot projection.
- `backend/bmt_backend/privacy.py`, `privacy_pages.py`, `backend/pyproject.toml`: erasure, disclosure and packaged allowlist.
- `docs/schemas/vehicle-appearance-v1.schema.json`, `weekly-rivalry-v1.schema.json`: optional presentation contract.
- `game/tests/test_rivalry_custom_cars.gd`, its UID, `test_weekly_rivalry.gd`, `backend/tests/test_rivalry_appearance.py`: focused checks and updated owner-requested podium assertions.
- This report and the owner override/status entries in `AGENTS.md`, `DEVELOPMENT_STATUS.md`, `docs/PHASE_0_PLAN.md`.

Actual checks used pinned Godot **4.7.2.stable.official.ed1daf0bf**, through `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1`, with APPDATA directed into task-specific `.tools/rivalry-custom-cars*-user` directories. No existing player saves were used.

| Actual command / test | Outcome |
| --- | --- |
| `-Action CheckScript -ScriptPath res://ui/weekly_rivalry_page.gd` | Pass. |
| `-Action TestScript -ScriptPath res://tests/test_rivalry_custom_cars.gd -Graphical -RenderingMethod gl_compatibility -RenderingDriver opengl3` | **110 checks, zero failures**; three widths, every chassis, complete remote/local appearance, fallback/scope/retry/reset/ticket behavior and native captures. |
| Same focused test with `-RenderingMethod mobile -RenderingDriver vulkan` | **110 checks, zero failures**; matching native Mobile views. |
| `-Action TestScript -ScriptPath res://tests/test_weekly_rivalry.gd -Graphical`, Compatibility and Mobile/Vulkan | **1,136 + 1,136 checks, zero failures**; actual full-app navigation, layout, scroll, action gates and existing rivalry behavior. |
| `-Action TestScript -ScriptPath res://tests/test_script_parse.gd` | **752 scripts, zero failures** in the shared workspace. |
| `-Action TestScript -ScriptPath res://tests/test_app.gd` | **99 checks, zero failures**; isolated app/record flows. |
| `.tools/backend-secure-venv/Scripts/python.exe -m pytest tests/test_rivalry_appearance.py tests/test_rivalry.py tests/test_rivalry_awards.py tests/test_rivalry_week_completion.py tests/test_privacy.py -q -k 'not postgres' --tb=short`, from `backend` using `../.tools/...` | **55 passed, 33 deselected**; existing httpx/Starlette deprecation warning. Covers real authenticated HTTP/SQL, both drivers' independent values, every allowed cosmetic ID, per-car retention, unchanged scores, strict bounds and deletion. |
| Ruff on changed backend Python modules/migration/test | Pass. |

Measured settled native menu submissions were **141 draw calls**. Explicitly changing all three car viewports to continuous updates raised that to **331** in the final runs; restoring one-shot updates returned exactly to 141. Earlier Compatibility observation was 325 with concurrent workspace assets. These are desktop engine counts, not phone FPS or timing claims.

Inspected native evidence: [compact, small layout](evidence/rivalry-custom-cars-2026-10-14/gl_compatibility/hub-960x540.png), [compact, Mobile](evidence/rivalry-custom-cars-2026-10-14/mobile/car-compact.png), [pickup](evidence/rivalry-custom-cars-2026-10-14/gl_compatibility/car-pickup.png), [classic](evidence/rivalry-custom-cars-2026-10-14/mobile/car-classic.png), [Formula](evidence/rivalry-custom-cars-2026-10-14/mobile/car-formula.png), [kart](evidence/rivalry-custom-cars-2026-10-14/gl_compatibility/car-kart.png). Both renderer folders contain three width captures and all five chassis, sixteen final screenshots total. These use explicit isolated server-shaped fixtures, never fabricated live standings.

Initial execution encountered the PowerShell script policy, sandbox access to Godot's log/certificate store and a missing Python working directory; corrected execution used the pinned entry point, isolated storage and normal engine access. Development checks caught a duplicated API prefix (405), JSON integer-version comparison differences, fixture import lint and an observer assumption that the SubViewport object's property changes from UPDATE_ONCE to disabled. The final draw-work experiment verifies actual static behavior instead. A terminal-only source-diff print hit Windows encoding; no source was changed by that attempt. All relevant final checks above passed without changing canonical invariants. PostgreSQL fixture attempts could not connect to the configured local service and were stopped; **no PostgreSQL test is claimed passed**.

The [task-only checkpoint patch](evidence/rivalry-custom-cars-2026-10-14/scoped-change.patch) and receipt retain the task-start before files and a separate Git checkpoint under `build/rivalry-custom-cars-checkpoint`. Concurrent retained-menu/night-preparation edits in `app.gd` are preserved in the working file and excluded from this checkpoint. The main Git index is untouched.

Rollout requires the matching client plus backend code/package data and migration 0035, using the established backend migration process. No running service was migrated or deployed. No phone test, Android export/install, production write, full Validate or physics merge regression was performed. Owner appearance review, physical-phone layout/frame pacing and matching client/backend rollout remain acceptance checks.
