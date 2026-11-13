# Race loading evaluation — 2 November 2026

There is further scope to reduce race-entry time without reducing visual detail. The first implementation candidates are **bounded reuse/batching of effect preparation** and **a cache policy that retains useful scenery instead of repeatedly admitting and evicting it**. Preparing more exact CPU work during track selection is the next scheduling improvement. These are recommendations, not implemented speedups. The existing first-use Compatibility graphics problem remains relevant.

This task changes no shipping loader, renderer, art, simulation or backend. RLR01 evaluates the current path; RLR02 measures current first/repeated entry and retry; RLR03 ranks alternative approaches with appearance gates; Q01 records reproducible evidence and a scoped checkpoint.

## Fresh observations

Two sequential offline actual-App runs used Godot `4.7.2.stable.official.ed1daf0bf`, Windows, RTX 3090, 1280×720 and Dummy audio. Each process used a new private APPDATA, records, library, cloud folder and road disk cache. The fixture is the same Star spline document, with Pine, Desert and Winter themes, each entered three times. Compilation happens before the timed entry; selection prefetch, network, ticket requests and Daily lap-limit retrieval are excluded. The selected car is the default detailed Compact. These are **fresh application/cache profiles, not controlled cold-driver tests**. Driver/OS caches were not cleared, the host was shared and themes share earlier program/car work in each process. Renderer runs are not an A/B comparison.

| Renderer / theme | First entry | Subsequent entries | Subsequent effects/final preparation |
| --- | ---: | ---: | ---: |
| Compatibility / Pine | 23.36 s | 6.92–7.20 s | 4.85–4.96 s |
| Compatibility / Desert | 27.62 s | 10.91–12.66 s | 7.08–8.44 s |
| Compatibility / Winter | 23.14 s | 15.11–17.74 s | 12.89–15.42 s |
| Desktop Mobile / Pine | 27.89 s | 1.83–2.16 s | 0.338–0.339 s |
| Desktop Mobile / Desert | 19.97 s | 3.86–4.49 s | 0.337–0.340 s |
| Desktop Mobile / Winter | 11.43 s | 1.88–1.93 s | 0.545–0.547 s |

The effects column includes covered frames of the world/car and other prepared effects, plus final drawing and cleanup. It is not isolated particle CPU/GPU time. The high Compatibility waits cannot be assigned to driver compilation, GPU saturation or a specific material from these timestamps. The timing difference between renderers is not a measured benefit of switching renderer.

The primary Compatibility run passed **59 checks / 0 failures**; Mobile passed **77 / 0**. Eighteen entries preserve readiness, canonical tick zero, the complete 360-tick countdown and five laps. Mobile also verifies nine actual `App._retry_race(true)` calls reuse the same Game and restore the exact start; they take **15.706–21.551 ms**, excluding online authorization. These checks do not exercise driving through a full lap or establish visual equivalence for a proposed optimization.

The separate short Compatibility follow-up passed **19 / 0** over two Pine entries and two retries. Its observed totals were 32.83/12.11 s and retry 14.840/16.538 ms. Concurrent work changed `game/core/app.gd` during this follow-up; retain it as supporting behavior evidence, not a stable-source timing comparison. The two primary runs have unchanged hashes for all eight recorded sources across each run. The report's `app_sha256` is read from disk at report time, not a hash of the in-memory instrumented App. There is no whole-tree source freeze claim.

All runs combined: **155 checks, zero failures; 20 entries; 11 retries**. Raw JSON, logs, source receipts and derived stage tables are in [the evidence folder](evidence/race-loading-review-2026-11-02/). The earlier severe cold measurements are preserved in [the October stage analysis](TRACK_LOAD_STAGE_ANALYSIS_2026_10_31.md) and [cold follow-up](COLD_LOADING_FOLLOWUP_2026_10_31.md); these newer cache-sensitive runs do not supersede or resolve them.

## What already works

- `App._retry_race` and `_retry_daily_race` reuse the live Game. Ordinary online retries still obtain replacement authorization as required; Daily retries retrieve the applicable limits. Recommending a generic “keep the level for retry” would duplicate existing behavior. The slower repeated-entry rows above deliberately leave and reopen the race.
- Free Race selection already waits 650 ms, compiles/downloads the exact selected revision if necessary, and prepares roads plus Winter cover. Cancellation is fenced by selection, car, account, navigation and revision.
- Ordinary ticket requests already overlap a needed road job. This does not cover every mode or Daily limit retrieval, and issuance semantics must remain intact.
- Native CPU road, Desert relief, Winter and raster helpers, bounded local numeric road artifacts, numeric support reuse, modular/rest-pose car caches, world templates, shared particle shaders and proxy pooling already exist.
- The first primary entry submitted 34 world graphics groups; later themes needed 9/11 on Compatibility and 10/11 on Mobile. Every subsequent entry for a theme submitted **zero** world groups. Adding another blanket world warm-up pass would be counterproductive.
- Warm Compact construction measured roughly **16–29 ms**, whereas first Pine construction measured 2.41 s Compatibility and 13.73 s Mobile. The latter includes cooperative yields and rendering/resource work; it is not pure geometry CPU time. Extend cache eligibility/earlier preparation only after measuring misses, rather than replacing an already cached warm path.

## Findings and ranked options

### 1. Reduce repeated covered effect draws

`effect_render_preparation.gd::prepare` still awaits one covered draw for **each live emitter**, even after `Pool.take` reuses its proxy: 20 for Pine/Desert and 32 for Winter. Warm entries reused all 20/32 but retained those waits. This creates a latency floor proportional to the cost/pacing of each complete covered frame.

Implement bounded, explicit preparation families and receipts for equivalent renderer contexts. Prepare cold/unrecognized combinations conservatively; batch validated warm equivalents and retain the final full covered frame. Keys must include the relevant process configuration, draw shader and mesh format, instancing, render state and lighting context. Do not group by emitter name, shared shader object alone, or recursively serialize arbitrary resource graphs. Keep independent live uniforms/materials and invalidate receipts on resource/settings/context changes and pressure.

The older [repeat batching experiment](evidence/track-load-effects-2026-10-31/README.md#exploratory-repeat-batching) already showed feasibility, but its unbounded serialization key was rejected for production. Its savings cannot be applied to today's timings. This recommendation is to build the missing bounded design and validate it, not to ship that prototype.

Acceptance: both renderers, all five themes/current cars, first real emissions and a complete first lap, exact restored appearance, different cosmetics, navigation/account cancellation, pressure, resource changes and graphics-context recovery. The measured phase is an opportunity ceiling; it is not a forecast of recoverable seconds.

### 2. Stop scenery cache churn within the existing memory allowance

The Mobile process-frame trace records an admission followed by eviction at the next memory trim for **every one of the nine entries**. Cache state alternates between one prepared world and zero. Pine's world estimate is 57,270,264 bytes, Desert's 53,867,072 and Winter's 40,815,820 (**54.62/51.37/38.93 MiB**). Retained telemetry after eviction is around 41–46 MiB before adding the world again. `EditorMemory` applies a combined **64 MiB** allowance, despite `PreparedWorldCache` separately allowing up to 64 MiB. Repeated builds report new partition/cache work, consistent with the recorded evictions.

Account shared immutable resources across road/world owners before choosing retention. Current accounting totals the caches separately; the estimates are not measurements of unique resident GPU memory. Give useful current-track scenery an explicit place in that shared allowance, consider retaining only the costly scenery portions, and avoid packing a complete optional world that the admission policy will immediately discard. Keep pressure cleanup and all existing hard bounds. Do not simply raise phone memory limits.

Full Game construction on warm Mobile entries still took 1.03–3.69 s, including work beyond scenery. Cache packing itself took only about 4–12 ms in these runs; optimizing serialization alone is unlikely to recover the larger span. Actual savings need a paired retention-policy experiment, resource-identity accounting and pressure tests.

### 3. Prepare an exact CPU packet while the selected event is visible

Extend existing selected-track preparation rather than adding another speculative builder. It currently returns roads/cover; ground query, bridge/support and checkpoint-layout preparation are still launched later by `Game._build_ground`. The first road wait here was 3.49–9.41 s across the primary runs. More finished scenery data could be prepared device-side during selection, with incremental cancellation and bounded admission. Daily/Rivalry detail pages could use the same exact-revision ownership path where they currently do not receive Free Race's selection preparation.

This reduces the wait after pressing Race only to the extent that selection dwell overlaps useful work; it does not remove that work or justify delaying startup or freezing an interactive menu. Keep one owner for mutable track preparation. Do not run simultaneous jobs that mutate the same track. Publish only complete matching results; never issue competitive attempts speculatively.

### 4. Use a small representative graphics preparation scene

The current world pass progressively reveals already prepared geometry; the effects pass draws against the assembled world and keeps earlier proxies alive. A different design could draw bounded representative mesh/material/instancing combinations in a small staging viewport, then perform the actual full world draw before uncovering the race. Another variant keeps earlier prepared groups hidden until the representative passes finish. Final car/terrain textures, geometry, effects and resolution remain unchanged.

The potential benefit is less repeated rendering while warming. It does **not** remove an indivisible driver compile/link. Match MSAA, shader features, shadow/light variants, render formats and depth/screen dependencies; Night and soft particles need particular care. A tiny unrelated shader quad is not proof the real race pipeline is ready. Measure total entry, largest frame, peak memory and the first full driving lap. Reject any path that merely moves a stall after loading.

### 5. Cache more finished device-generated scenery on disk

Keep the current trust boundary: published documents are data and geometry is prepared on the player's device. Locally generated, versioned final scenery packets could extend today's road-only disk cache and preserve some work across process restarts and RAM eviction. Use atomic writes, corruption/size validation, bounded decoding, content/art/algorithm identities and safe fallback.

This is consistent with the owner's earlier rejection of server-side visual packs. The [older local finished-world experiment](NEW_TRACK_LOADING_REVIEW_2026_10_18.md) is CPU feasibility evidence, not a current end-to-end speedup or a reason to accept downloaded engine scenes. Disk I/O, storage, shader readiness and mutable prop isolation still need evaluation; RAM accounting remains necessary.

### 6. Treat graphics variant reduction and another renderer as separate experiments

Further sharing of truly equivalent shader/mesh/render configurations may reduce first-use work without changing output. Recent [surface consolidation](SHADER_VARIANT_CONSOLIDATION_2026_10_31.md) and [sampler fixes](SAMPLER_BUDGET_FIX_2026_10_31.md) already did some of this; some Mobile candidates failed appearance comparisons and were correctly guarded out. Continue only with exact/unchanged-threshold image controls and first-lap measurements. Do not merge variants merely because shader text matches.

Godot's [pipeline documentation](https://docs.godotengine.org/en/stable/tutorials/performance/pipeline_compilations.html) distinguishes Compatibility's covered visible draws from Mobile/Forward+ pipeline precompilation and ubershaders. It also states that export shader baking does not help Compatibility and cannot bake hardware-specific final pipelines. The current project selects Compatibility on desktop and Android. A Mobile/Vulkan trial is an architectural option, with shader baking/precompilation as supporting features, not an already validated switch. Runtime-generated specialized shaders also need investigation because export-time scanning may not see every generated form.

An Android renderer decision requires matched final appearance, device support, depth/soft-particle/reflection behavior, memory, battery/thermal and cold/first-lap results. Today's sequential RTX observations cannot decide it. The earlier custom background GL compiler exceeded its memory and first-draw gates; retain those findings and do not ship unsupported hooks on this evidence.

## Validation, reproduction and limits

Changed task files: the diagnostic `game/tests/review_race_loading_2026_11_02.gd`, this report, task-only evidence/reproduction helpers, and short AGENTS/DEVELOPMENT_STATUS entries. The diagnostic instruments a GDScript copy in memory, never the shipping App. It runs the shipping loading sequence, redirects all player-facing persistence to its own profile, and disables the API. There is no visible UI change, so no new appearance acceptance is claimed or required for the evaluation itself.

Actual commands from the workspace root:

```powershell
python docs/evidence/race-loading-review-2026-11-02/run_review.py gl_compatibility
python docs/evidence/race-loading-review-2026-11-02/run_review.py mobile
python docs/evidence/race-loading-review-2026-11-02/run_review.py gl_compatibility -- --themes=pine --cycles=2
python docs/evidence/race-loading-review-2026-11-02/summarize_review.py
```

The runner uses `scripts/run_no_crash_dialog.py`, the pinned executable and a 360-second process-tree timeout. The primary Compatibility artifacts were renamed `compat-three-themes.*` before the follow-up. The initial diagnostic stopped correctly at an obsolete pre-Daily anchor; its next attempt exposed CRLF-sensitive multiline matching. Both logs are retained; the evaluation probe normalizes line endings and uses the current Daily anchor. The initial restricted runs emitted the Windows certificate-store error. The final three graphical runs used normal-access isolated offline processes and returned zero without detected engine/script/shader errors. A report-generation assertion detected concurrent App changes in the follow-up; it now records those changes explicitly while requiring stable recorded sources in both primary runs.

`python docs/evidence/race-loading-review-2026-11-02/checkpoint.py` produced the [task-only patch](evidence/race-loading-review-2026-11-02/task.patch). Forward application, reverse application and normalized file-content round trips passed in an owned workspace directory; the [checkpoint receipt](evidence/race-loading-review-2026-11-02/checkpoint.json) records the exact commands and hashes. No main Git index was written.

Remaining acceptance is attached to the proposed implementations above. No Android device query/test, APK/export, live/backend access or mutation, owner-save change, owner-process restart, deployment or main-index staging/commit/merge was performed. No release-build speedup, genuine cold-driver improvement, phone performance, complete-first-lap validation or new visual-equivalence result is claimed.
