# Beat My Track: mobile code and quality re-audit

Audit date: **27 October 2026**, Europe/Helsinki. This updates the [26 October audit](COMPREHENSIVE_MOBILE_AUDIT_2026_10_26.md) after the runtime, persistence, diagnostics and native-memory changes. Runtime, memory and correctness receive priority. There are **no effort estimates** and no proposed visual downgrades.

The [verification ledger](evidence/mobile-reaudit-2026-10-27/report.json), [command record](evidence/mobile-reaudit-2026-10-27/commands.md), [source inventories and changes](evidence/mobile-reaudit-2026-10-27/source-changes-during-audit.json), raw logs, test harnesses and native captures accompany this report. Findings distinguish measured defects, accepted design risks and missing acceptance evidence. Historical evidence is labelled explicitly.

Requirements: **AUD01** architecture/inventory; **AUD02** performance/memory; **AUD03** UI; **AUD04** correctness; **AUD05** debt; **AUD06** security/privacy; **AUD07** Android release; **AUD08** testing; **AUD09** observability; **AUD10** evidence, prioritized actions and report. Findings RA01–RA08 below implement that audit scope; they do not authorize implementation or deployment.

This is an audit, not a production implementation change. Tests ran during concurrent owner work, including changes to the Garage preloader. It is therefore **not an immutable release certification**. The original backend wire fixture invoked the development wrapper, which regenerated `project.godot` and `build_identity.gd`; those incidental generated changes are excluded from the audit deliverables. No rollback of concurrent work was attempted.

## A. Executive assessment

**Memory ownership and correctness have improved materially. Loading and final Android acceptance remain the largest runtime concerns.** The earlier nested recording allocation, native blend dictionary leak, freed pause callback, redundant car-reflection rendering and recovery failures are no longer reproduced by their focused checks. They should not remain on a list of unfixed bugs.

The fresh graphical, full-App soak completed **50 cycles / 211 checks / zero failures** through Garage, racing, results, editor, practice and Settings, with periodic memory pressure and account replacement. In 31 matched warm samples, objects/nodes/resources stayed at **4,608 / 740 / 902**. Godot static memory ranged from **277,919,059 to 278,098,687 bytes**, a **179,628-byte range**, and ended **36,016 bytes below** its first matched sample. This supports a bounded plateau in this scenario. It does not establish Android PSS, driver memory or 200-cycle acceptance.

The five leading concerns are:

1. **RA01 — Native load stalls remain.** A fresh-process Star load took **43.147 s**, including a **5.877 s frame**. The first Freight load took **16.553 s**, including a **1.822 s frame**. Repeated loads were much faster overall but still contained **208–246 ms peak frames**. Direct Garage entry without a ready preload took about **23 s**. The latest ready preload opens Garage in **660 ms**, but preparation still contains a **2.659 s draw interval**. These are workstation Compatibility measurements, not phone timings.
2. **RA02 — Competitive trust remains a deliberate limitation.** A locally fabricated path through fresh, actual Ellipse geometry still passes the trajectory acceptance function in **23.108 s for five laps**, without canonical driving inputs. Adding the permitted client clean-race declaration changes `incident_free` to true. This is a residual risk of the accepted lightweight policy, not a newly introduced regression or a live-service exploit test.
3. **RA03 — There is still no dependable single release regression result.** Focused correctness suites pass, but the standard validation function explicitly selects 76 of 574 top-level client tests; prerequisites and result classification remain fragmented. The full selected backend invocation has native-environment failures, two native UI fixtures retain shutdown resources, localization fails 176 completeness checks, and Ruff reports 18 findings. Exit code zero alone is insufficient.
4. **RA04 — Production monetization is incomplete.** Store checkout still uses the guarded development simulator; backend availability is false. AdMob is intentionally debug-only. This is a commercial release integration gap, not an accidental ability to charge players.
5. **RA05 — Final Android acceptance is outstanding.** No release AAB or physical-device frame/memory/thermal run was performed. The newer **27 October compatibility rollout** records physics **0.75 / electric-18**, 30 current published heads and 210 accepted public track/car combinations. Its manifest matches this audit's fresh local geometry. That service work is credited; final installed-client/artifact acceptance remains.

No P0 issue is established. The appropriate next step is targeted loading work and a reproducible acceptance gate, while preserving the improvements already verified.

### Architecture and current scope

The source/configuration inventory covered **2,409 files** at the start across `game`, `backend`, `native` and `scripts`. It included 470 production-client GDScripts outside tests, 574 top-level client test entrypoints, 184 top-level backend test modules and 268 backend production Python modules including migrations. Counts include fixtures/configuration where specified; they do not imply that every file received an independent line-by-line review. See section I for actual coverage.

| Boundary | Current implementation and assessment |
|---|---|
| Engine and languages | Pinned Godot `4.7.2.stable.official.ed1daf0bf`; typed GDScript, Python/FastAPI/SQLAlchemy, C++ GDExtensions, Java Android bridges, shaders, PowerShell/Python tooling. |
| Entry and UI | `core/app.tscn` / `app.gd` compose native controls, navigation, editor, race lifecycle, persistence and online completion. App is roughly **6.2k lines / 276 functions**, versus 5,859 / 259 in the prior audit. Most screens are constructed in code. |
| Shared services | `Language` and `AudioWorld` are the two autoloads. Account/domain adapters, passed ownership and explicit bounded caches handle most other shared state. Singleton count is not the primary problem. |
| Simulation | Fixed 120 Hz canonical input/simulation and ordered swept gates remain separate from presentation. Fresh manifest: `arcade-planar-0.75`, `standing-5-road-gates-v23`, `creator-compiler-27`, electric-18, seven vehicles. |
| Presentation | Native prepared geometry, model/world caches, cooperative construction, staged first draws, bounded preview caches, idle showroom rendering and an optional account-bound Garage preloader. Individual native/driver operations can exceed cooperative slice targets. |
| Result ownership | Packed controls, sealed completed evidence, bounded save/encoding queues, ghost ownership and durable pending-result journals replace the earlier repeated nested-array handoff. |
| Authoring | Versioned documents/compiler, road/object validation, undo/history, cancellable preparation and asynchronous writes. The native blend dictionary ownership fix is present in the loaded Windows library. |
| Backend | API, PostgreSQL contracts/ledgers, immutable blobs, leased verification/publication workers, discovery/rank projections, economy, privacy and separate administrative workloads. SQLite tests do not establish PostgreSQL concurrency. |
| Transport and identity | Bounded HTTP, TLS except explicit loopback development, scoped cancellation/response validation, session renewal, protected Android Keystore / Windows DPAPI storage, server-owned entitlements and idempotency. |
| Android | Google identity bridge, secure storage, intents/sharing, vibration, native geometry and debug AdMob. Current checked-in export preset is Android Debug, ARM64/x86-64, minimum API 24. A final shipping manifest was not inspected. |
| Dependencies | Existing pinned Godot, godot-cpp/NDK, hash-locked Python requirements, container digest and Gradle dependencies remain. No new dependency advisory scan was performed. A pin is reproducibility evidence, not a vulnerability-free claim. |

The architecture has useful boundaries. The principal structural problem is that App still coordinates several independently evolving lifecycles, making ownership changes and regression selection harder. A broad rewrite is not justified by these results.

### What changed since the previous findings

| Earlier concern | Current disposition |
|---|---|
| Mandatory Garage before initial Account UI, MA13 | **Resolved for startup.** Fresh native startup is **153.677 ms**; Garage creation is deferred. Direct first Garage entry is still expensive. The optional preloader is assessed separately below. |
| Music invalidates unchanged car reflections, MA04 | **Resolved in focused native check.** Animated room / unchanged car reflection draw deltas are **[24, 0]**. Original visual behavior remains. |
| Nested full control arrays, MA05 | **Resolved in measured result path.** Packed input is **1,728,000 bytes** at the long-recording fixture; completed evidence/queued evidence is **38,627,792 bytes** under the **167,772,160-byte** allowance. These are different ownership measurements, not a claim that all evidence is 1.7 MB. |
| Freed deferred pause callback, MA06 | **Not reproduced after fix.** Focused lifetime checks and native pause assertions pass. Shutdown-only audio retention is a separate unresolved test result. |
| Store layout, MA07 | Earlier native fix evidence is retained; source still has the corrected layout. The service-dependent Store UI suite was **not freshly rerun** because it needs its own development backend fixture. Production checkout remains a separate gap. |
| Stale source translation template, MA08 | **Resolved:** POT matches 2,659 current messages. **Newer untranslated messages remain:** 16 in each of 11 non-English catalogues. |
| Guest diagnosis, MA10 | **Improved:** bounded local support export, redaction, first-party failure locations and Android exit capture exist. Operational crash/ANR coverage remains partial. |
| Native editor drift | **Application leak fixed:** blend-memory regression passes 9 checks. The 50-cycle graphical App soak is bounded. The pinned engine's headless accessibility queue remains a tooling limitation, not evidence of the same player leak. |
| Shared resume / pending / practice recovery | Fresh suites pass **21 / 44 / 43 checks**. The old practice-recovery failures should not be carried forward as current failures. |
| Backend/published-track compatibility | **Resolved in retained 27 October rollout evidence:** all ten targets updated, 30 new compatible heads, **210 public track/car combinations** accepted by the actual game validator. Manifest matches fresh local geometry; no independent new live query succeeded in this audit. |
| Result budgets, pause presentation and staged race cancellation | Fresh result safety **254**, cap **12**, load-state **60** and native cancellation **16** assertions pass. Android interruption/kill acceptance remains open. |

## B. Updated quality scorecard

Scores reflect inspected implementation and available evidence. They are provisional engineering judgments, not mobile performance certification. A higher memory score reflects fixed ownership and bounded native-soak evidence; it does not certify a phone memory budget.

| Area | Previous → now | Basis and remaining limit |
|---|---:|---|
| Runtime performance | 6 → **6/10** | Startup and redundant rendering improved. Cold loading and repeat 200+ ms frames remain. Active Android CPU/GPU frame time, battery and thermal behavior are unmeasured. |
| Memory efficiency | 7 → **8/10** | Native leak fixed, packed controls, bounded evidence and stable 50-cycle App sample. Android PSS/graphics/low-memory acceptance remains. |
| UI/UX implementation | 7 → **7/10** | More stable header/Garage/pause ownership and improved startup. Loading interrupts responsiveness; translations and physical-touch acceptance remain. This is not owner visual approval. |
| Correctness / reliability | 7 → **8/10** | Fresh App, recovery, result cap, launch, gates, handling, electric, creator and cancellation checks pass. Release contract and device interruption acceptance are incomplete. |
| Architecture | 6 → **6/10** | Sound simulation/service/platform separation; App orchestration continues to grow. |
| Maintainability | 6 → **6/10** | Contracts, typed code and retained evidence help. Test selection, fixture prerequisites and shared coordinator ownership remain costly. |
| Security | 6 → **6/10** | Auth/privacy/commerce unit checks pass and boundaries are strong. Accepted path-only competitive trust remains limited. No live penetration or advisory audit. |
| Testing | 6 → **7/10** | Stronger focused recovery and native lifetime evidence. Full release gate is still not reproducible/green. |
| Observability | 6 → **7/10** | Local guest export, redaction, native exit records and failure-site diagnostics improve support. Automatic guest crash/ANR and operational drill coverage remain partial. |
| Android production readiness | 4 → **4/10** | Shipping monetization, final artifact/configuration and current physical-device acceptance remain open. |

## C. Prioritized findings

### RA01 — Native loading still causes long waits and blocking frames

**P1 · measured runtime problem · high confidence for desktop observations; Android magnitude unknown.**

**Locations:** `game/core/app.gd::_start_race`, `game/core/app.gd::_garage`, `game/vehicle/effect_render_preparation.gd:7`, `game/vehicle/skid_trails.gd:73`, `game/vehicle/compact_detail.gd::_front` / `_nose_band` / `_nose_tile`, `game/ui/garage_preloader.gd`, `game/ui/garage_preloaded_studio.gd`.

Fresh native Compatibility measurements used the actual App loader, isolated offline records and six tracks twice. Checks preserve pause state, camera invalidation and held-input behavior. The process was fresh, but disk/driver caches were not erased. These are not clean-install Android measurements.

| Track | First total | First peak frame | Repeat total | Repeat peak frame |
|---|---:|---:|---:|---:|
| Star | 43,147 ms | 5,877 ms | 1,473 ms | 208 ms |
| Freight | 16,553 ms | 1,822 ms | 704 ms | 216 ms |
| Switchyard | 4,513 ms | 214 ms | 738 ms | 246 ms |
| Timber | 4,382 ms | 225 ms | 704 ms | 222 ms |
| Quarry | 5,488 ms | 258 ms | 786 ms | 229 ms |
| Floodgate | 4,834 ms | 224 ms | 773 ms | 229 ms |

World packing is about **5–7 ms**, and cached instantiation about **1–2.4 ms** here. Those are not the dominant measured delays. Star's largest measured render wait is **2.181 s**; Freight's is **1.791 s**. Longest-frame time and render-wait time are different measurements and must not be added as independent costs.

The late, current Garage preloader passes **381 headless / 382 native checks**. In its native run startup is **161 ms**, ready-studio adoption dispatch is **64 ms**, and first live page after adoption is **660 ms**. The earlier preparation takes **29.633 s after the fixture begins waiting**, with **101 warm draws** and a **2.659 s maximum draw interval**. This moves substantial work before Garage entry; it does not remove the work or guarantee responsiveness during it. The interval measures `_submit_render()` through `frame_post_draw`, not isolated CPU time or GPU timestamp duration. Existing input/foreground gates prevent starting another batch while busy, but cannot interrupt an already blocking driver interval. These results must not be presented as instant or hitch-free preparation.

Earlier [stall attribution](RUNTIME_STALL_INVESTIGATION_2026_10_26.md) already demonstrated that simultaneous particle preparation causes repeat Compatibility render stalls, identical fresh tyre shaders add work, and front-fitting grid samples repeat expensive calculations. This re-audit confirms that the implicated production paths remain: effect proxies are still prepared as one group and `_trail_material()` still constructs `Shader.new()` for identical source. It does **not** identify a new native driver call from these broad timings alone. Prior staging/shared-shader/grid prototypes remain diagnostic evidence, not shipping changes.

**Player impact:** loading covers may remain visible for seconds, input cannot be serviced during a blocking native interval, and repeated loads still exceed a normal interactive frame budget. Idle preparation can move some work earlier, but does not bound an indivisible graphics operation.

**Required work:**

1. Integrate immutable tyre-trail shader reuse, keeping separate materials, parameters and all trail capacity/clear semantics.
2. Integrate cancellable particle preparation across rendered batches, preserving all emitters, settings, glass/finishes, simulation tick zero, countdown and first-emission behavior.
3. Reuse the exact front-fitting grid samples demonstrated by the existing prototype. Preserve full/simple geometry signatures and current vehicle limits.
4. Verify the new Garage preloader's ready, partial, resource-only and direct-entry paths. Keep original live geometry, paint, wear, reflections and input. Test all cars, appearance changes, focus loss, memory pressure, account replacement and race cancellation.
5. Repeat the same load matrix after each accepted change with update/draw/native intervals separated. Record cold and warm distributions, not only total time or a single favourable peak. Then profile Android to establish the device budget and remaining native/driver cost.

**Regression risk:** high for first-frame visibility, resource lifetime and stale publication; medium for immutable shader/sample reuse. **Acceptance:** existing functional assertions stay unchanged, appearance is preserved, cancellation/pressure is clean, and measured blocking intervals decrease. Do not optimize the 1–7 ms pack path in place of the measured multi-second bottleneck.

### RA02 — Accepted trajectory policy cannot establish a physically legitimate drive or clean race

**P1 for protected competition/rewards · confirmed accepted design limitation · high confidence locally; live deployment unverified.**

**Locations:** `backend/bmt_backend/trajectory_verifier.py:13` and `:109`, `backend/bmt_backend/worker.py:320`, `backend/bmt_backend/economy.py:258`.

The current path verifier has useful bounded movement, timing, first-start, ordered-gate and contract checks. The earlier interval-dependent speed allowance has been corrected. It still does not reconstruct canonical acceleration, steering, grip, collision or road-contact state. Incident-free status can still come from a well-formed client declaration.

This audit obtained fresh Ellipse geometry/manifest from the unchanged native runner, then called the actual Python acceptance function. A synthetic 2,774-sample path, generated without canonical inputs, was accepted at **2,773 ticks / 23,108 ms / five laps**. Its first step is **45.2325 m/s**. Adding the zero-collision/off-track declaration switches incident-free status from false to true. The worker forwards that flag; the economy path grants a **200-Coin clean-race bonus**.

The strict native verifier wrapper fails closed here because Godot reports a sandbox root-certificate error. That failed invocation is retained. The successful reproduction uses the unchanged raw runner's fresh geometry and actual acceptance function; it is **not** a successful end-to-end native-verifier or public-service test. No result was submitted and no currency was minted.

**Required work:** record an explicit launch decision about what trajectory-verified rankings and clean rewards promise. If this trust level is accepted, document it and keep the reproduction as a known-risk fixture. If stronger protected rewards are required, define server-computable incident authority and evaluate selective canonical verification or additional adversarial checks against legitimate recordings and service cost. Do not silently replace the approved lightweight policy, rewrite physics or invalidate boards as an audit fix.

**Regression risk:** high for accepted-run populations, economy, board contracts and verifier capacity. **Acceptance:** an explicit policy and adversarial suite covering synthetic acceleration/turn/layer/incident cases, plus legitimate-run compatibility and disposable PostgreSQL concurrency tests. Bounds alone do not prove canonical legitimacy.

### RA03 — The release regression gate does not yet provide a trustworthy aggregate result

**P1 · confirmed verification gap · high confidence.**

**Locations:** `scripts/dev.ps1::Invoke-Validation`, `backend/tests/test_resume_recovery_wire.py`, `game/tests/test_pause_menu.gd`, `game/tests/test_runtime_render_lifecycle.gd`, localization tooling and backend Ruff output.

The standard validation function explicitly references **76 distinct client tests**, while 574 top-level client test scripts now exist. The whole development wrapper contains 96 distinct references; that larger number must not be mistaken for the Validate selection. Some omitted scripts are historical capture/probe tools. The goal is a maintained selection, not blindly running every archived probe on each edit.

The first selected backend run produced **160 passes / 2 failures / 5 fixture errors / 2 skips**. The two failures come from the strict native verifier rejecting Godot's sandbox certificate error; the five wire fixture errors involve the development wrapper/certificate/access prerequisites. A pure-backend selection then passes **160 / 2 skipped**, and the same wire assertions pass **5 tests** when only the wrapper launch is replaced by direct pinned Godot execution. These controls isolate environment/fixture problems; they do not turn the original full run green or establish live PostgreSQL behavior.

Native pause functionality passes 17 assertions, but immediate fixture exit reports **60 ObjectDB instances / 11 resources**. A control changing only teardown settling and fixture-local references reduces this to **four Ogg audio objects / one resource**. The cancellation fixture has the same four/one warning. The full 50-cycle App soak exits without those leak warnings. Therefore this is an unresolved shutdown/test-harness result, **not proof of a continuing per-race player leak**. The audio references still need a precise cleanup/engine-output attribution.

The native mobile-fix fixture passes 266 assertions, but the OS rejects restoring the previous clipboard during cleanup. Support export itself passed. Record that cleanup failure; do not count it as a clean diagnostic run or infer a production clipboard bug. No clipboard history was inspected.

**Required work:** maintain a test manifest with headless/native/backend prerequisites and required runtime errors; make CI report assertion status, script errors, retained resources and environment blocks separately. Use isolated test profiles and invoke the pinned engine without regenerating product metadata for a read-only verification. Resolve teardown warnings with a control that preserves production lifetimes, fix the 18 lint findings, and run translation completeness in the gate. Keep strict production verifier error handling.

**Regression risk:** low for manifest/lint, medium for fixture ownership and process orchestration. **Acceptance:** one documented command produces an unambiguous result from a frozen checkout; required tests cannot be silently omitted and an exit-zero resource/script failure cannot be labelled clean.

### RA04 — Production Billing and advertising remain unintegrated

**P1 conditional on a monetized launch · confirmed integration gap · high confidence.**

**Locations:** `game/ui/store_page.gd:63`, `game/platform/purchase_simulator.gd::_guard`, `backend/bmt_backend/commerce.py:40` and `:109`, `native/admob/android.gradle:39`, `game/addons/bmt_admob/export_plugin.gd`.

Store still selects the debug purchase simulator, which rejects release use. The backend returns `store_available=false`. AdMob code and SDK dependencies are debug-only and use development configuration. Existing server proof, entitlement and idempotency components do not complete the shipping player-facing flow. This respects the earlier development-only authorization.

**Required work before offering paid/rewarded production actions:** connect production Billing purchase/acknowledgement/restore/refund/retry behavior to authoritative server fulfillment; configure production ads, consent and signed idempotent server-side reward fulfillment; verify interrupted/duplicate/pending/account-switch cases in provider test tracks. Keep simulator/development grants excluded from release and unavailable actions truthful until integration is accepted.

**Regression risk:** high for entitlement/reward/account correctness. **Acceptance:** provider test-track receipts and final release dependency/manifest inspection. No real purchase or ad/provider test was performed in this audit.

### RA05 — Final Android artifact and device memory/frame envelope lack current acceptance

**P1 release gate · missing evidence, not a confirmed live defect · high confidence about the gap.**

**Locations:** `game/export_presets.cfg`, `game/backend/account_controller.gd::_load_configuration`, `game/core/build_identity.gd`, native library descriptor, build/export/deployment tooling.

The only checked-in export preset is Android Debug with the development package/path. A blank target SDK delegates to the template; this report does **not** infer an invalid target from that field. No final release AAB, merged manifest, bundled resources, production origin, signing configuration, ABI/page alignment or symbols were newly built/inspected. Release's default backend fallback is empty unless configured; the shipping artifact's actual configuration is unverified.

Godot static memory plateaued near **278 MB** in this desktop soak. The same owned process peaked at **1,709,654,016 private bytes** and **1,243,119,616 working-set bytes**. Those Windows totals include renderer/compiler/driver allocations and are not Android PSS or a direct measure of the explicit cache budget. They are a reason to measure the actual device envelope, not proof that the game leaks 1.7 GB or exceeds a phone budget.

The newer [27 October compatibility rollout](BACKEND_COMPATIBILITY_DEPLOY_2026_10_27.md) updates all ten executables and 30 published track heads to physics0.75/electric18. Its retained receipt records 71 exact-image tests, 210 accepted public track/car combinations, live authority and 30-track traversal. The complete receipt manifest matches fresh local geometry in this audit. This is inspected retained rollout evidence, not a newly performed live test: the public bootstrap was inaccessible here. Do not carry the older deployment/version mismatch forward as an unfixed finding.

**Required work:** freeze the client inputs; produce and inspect the signed release artifact; verify exact runtime asset/native/configuration/symbol identities; bind that installed artifact to the already documented service contract, rechecking authority at release; then run the device matrix in section F. Establish Android PSS, graphics, transition peak and low-memory behavior with the optional preload enabled/disabled. Keep caches within measured device limits and evict optional content before required race/save work.

**Regression risk:** medium/high for export and contract rollout. **Acceptance:** artifact hashes plus installation/device results and a matching live authority receipt. No new backend deployment or release export is authorized by this audit alone.

### RA06 — Sixteen newer messages remain untranslated in eleven languages

**P2 · confirmed localization incompleteness · high confidence.**

**Locations:** `game/localization/*.po`, current Rivalry summary and result/practice recovery messages; `scripts/localization.py check`.

The source template is current for **2,659 messages**. English passes completeness. Each of **fr, es, de, pt_BR, ja, ko, nl, it, fi, sv, nb** has **16 missing translations**, producing **176 validation errors**. Examples include No races completed, PERSONAL BESTS, RUNNER-UP, VIEW RESULTS and new recovery messages. English fallback keeps the interface usable; it is still visibly incomplete for those players. The 62-check runtime localization suite does not cover catalogue completeness.

**Required work:** translate the 16 messages in all 11 catalogues, preserving placeholders/plurals; rebuild catalogue imports; run source completeness and representative narrow/wide native layouts for the new copy. Do not mark untranslated English fallback as finished localization.

**Regression risk:** low/medium for placeholders and text fit. **Acceptance:** zero completeness/format errors and reviewed target-language layouts. No unrequested auto-translation was performed.

### RA07 — App lifecycle coupling continues to increase change risk

**P2 · static architecture/maintainability risk · medium/high confidence.**

**Locations:** `game/core/app.gd` navigation, Garage residency/preload, `_start_race`, result completion and editor/practice coordination.

App has grown from 5,859 lines / 259 functions to roughly 6.2k / 276. Line count alone is not a defect. The practical problem is that route changes, account identity, optional resource retention, race cancellation, result persistence and editor return all manipulate the same coordinator state. Recent fixes repeatedly needed account/navigation/teardown fences across these paths.

**Required work:** preserve the passing App/recovery/cancellation tests and extract one cohesive ownership boundary at a time when touching it: navigation scope, race-loading cancellation, or completed-result handoff. Give that component explicit inputs, owner identity and teardown. Remove duplicated guards only when equivalent behavior is demonstrated. Keep simulation independent. Do not introduce a general event bus or rewrite every screen merely to reduce file size.

**Regression risk:** medium/high for navigation and account/save ownership. **Acceptance:** fewer shared mutable fields and independent boundary tests, with existing App/soak/recovery tests and visible flows unchanged.

### RA08 — Support diagnostics improved, but release operations and privacy configuration need proof

**P2 release operations · partial implementation / unverified configuration · medium/high confidence.**

**Locations:** `game/diagnostics/support_report.gd`, Android `BmtProcessExits.java`, `backend/bmt_backend/observability.py`, `backend/bmt_backend/quality.py`, `backend/bmt_backend/config.py:45`, `backend/bmt_backend/privacy_pages.py:32`.

Local guest/opt-out support export is now bounded and redacted, first-party failure locations exist, Android historical-exit handling is guarded, and native symbols have retained provenance. These are real improvements. Manual export is not automatic guest crash delivery; quality reporting still identifies unavailable crash-stack/Play-vitals coverage. No release crash/ANR-to-symbolication drill or support response was demonstrated here.

Privacy configuration still has placeholder developer/contact defaults and the page can expose a configuration notice when unset. The actual deployed settings were not read; this is **not a finding that the live policy contains placeholders** and is not a legal compliance verdict.

**Required work:** reject incomplete public privacy/contact configuration in release deployment validation; inspect the public release pages without exporting player data; document the consent-respecting guest support path; retain build-to-symbol mapping; exercise one deliberate native crash and one ANR in a disposable device/test build and prove diagnosis of the exact build. Configure Play operational alerts and ownership where applicable. Do not start collecting new personal data as an incidental audit fix.

**Regression risk:** low for configuration checks, medium for diagnostics/consent handling. **Acceptance:** final public configuration receipt, redaction tests and a completed support/symbolication drill.

## D. Runtime and memory work to do

| Priority | Concrete action | Evidence / purpose | Completion criterion |
|---|---|---|---|
| 1 | Reuse immutable trail Shader while isolating materials | Current code constructs identical shaders; prior controlled prototype removes repeat work | Same trails/parameters, clean clear/free, reduced measured load interval |
| 2 | Stage all particle proxies across rendered batches | Current repeat load peaks remain 208–246 ms; existing attribution identifies grouped preparation | Same emitters/settings/first emission; cancellation/pressure safe; measured update/draw peak reduction |
| 3 | Integrate exact front-surface grid reuse | Prior measured fitting/nose costs; current duplicate sampling remains | Identical full/simple geometry signatures and model/fit checks |
| 4 | Accept the optional Garage preloader across identities and direct/partial/ready entry | New feature moves original live studio preparation earlier; single-car/headless success is insufficient | All seven cars, paint/parts/wear, input, pressure, focus, account, race and device frame checks |
| 5 | Measure the Android memory envelope for the actual release build | Desktop static plateau is good; process peak is a different, larger metric | Android PSS/graphics/transition/pressure results and enforced measured budgets |
| 6 | Extend full native acceptance to 200 cycles and realistic longer races | Fresh 50-cycle plateau replaces the earlier ambiguous drift observation | No steady-state object/resource rise; bounded post-trim baseline; no lost save or shutdown finding |
| 7 | Keep evidence construction and save admission bounded at transition peaks | Current 1.728 MB input / 38.628 MB evidence test passes | Same admission/cap/identity/recovery tests on release/device; no second unbounded ownership path |
| 8 | Preserve the now-idle car reflection path | Fresh room/car deltas [24,0] | Playback/paint/orbit still render when required; unchanged car remains idle |
| 9 | Trace residual native/driver stalls after targeted changes | Packing is only 5–7 ms; broad loader labels cannot identify every GPU interval | Separated main/update/draw/native traces, comparable cache state and first-emission tests |

There is no new demonstrated unbounded player-memory drift in the tested native scenario. The remaining memory work is pressure/peak/device acceptance and upstream/tooling attribution, rather than another speculative cache purge.

## E. Technical debt and safe cleanup boundaries

| Debt | Required change | Guard against unnecessary work |
|---|---|---|
| Test selection and fixture prerequisites are scattered | Maintain a manifest of shipping contract tests, visual/native captures and historical probes | Do not delete old evidence or force every archived capture into every edit |
| Read-only verification regenerates build identity | Separate testing from explicit build-identity generation | Keep release identity deterministic and checked; do not revert concurrent owner metadata |
| Oversized App orchestrates several owners | Extract one owned lifecycle at a time under existing tests | No broad rewrite or generic indirection justified by file size alone |
| Ruff reports 18 findings, five production | Resolve imports/unused variables/duplicate fixture names; retain intentional test execution fixtures explicitly | The flagged `exec` is a test failure-site fixture, not evidence of production remote execution |
| Pinned native SDK has unsafe Dictionary move assignment | Retain the const-local/copy guard and native regression; track upstream correction | Application path is fixed. Do not revert it because a generic SDK header still contains the old move implementation |
| Headless engine accessibility retains dead IDs | Keep headless and native memory results separate; validate an upstream engine correction if adopted | Proposed engine patch is unapplied; do not call engine queue growth a new player leak |
| Old fixtures target earlier cars/contracts | Declare expected contract/version and preserve historical fixtures separately | Do not rewrite old evidence or relax handling/gate assertions to force green |

No unused subsystem or dependency is recommended for removal without a confirmed reference/packaging analysis. No material circular-load startup failure was reproduced; parsing passes.

## F. Verification strategy and device matrix

### Fresh checks and their actual status

| Group | Result |
|---|---|
| Final parser | **1,330 scripts / zero parse failures**. Count includes new tests/probes and is not the production script count. Sandbox certificate error remains. |
| App / rewind / launch | **141 / 61 / 18,656 checks**, zero assertion failures |
| Handling / current electric / checkpoints / creator | **88 / 518 / 266 / 113 checks**, zero assertion failures |
| Shared recovery / pending input / practice save | **21 / 44 / 43**, zero assertion failures |
| Result safety / recording cap / native blend memory | **254 / 12 / 9**, zero assertion failures |
| Free-race restart | **17**, zero assertion failures |
| Client quality / graphics / localization runtime / statistics reuse | **57 / 146 / 62 / 42**, zero assertion failures |
| Native Garage live entry | **50**, zero assertion failures; direct first-live page **23,250 ms** |
| Native mobile-audit fixes | **266**, zero assertion failures; startup **154 ms**, first Garage **22,994 ms**, three viewports. Clipboard restore error during cleanup. |
| Native pause / staged race lifecycle | **17 / 16**, zero assertion failures, with shutdown resource findings described under RA03 |
| Actual load profile | **12 loads / 60 checks**, zero assertion failures; timings in RA01; no script/leak shutdown findings |
| Full graphical soak | **50 cycles / 211 checks**, zero assertion failures; no script/leak shutdown findings |
| Latest Garage preloader | **381 headless / 382 native checks**, zero assertion failures; native ready entry **660 ms**, maximum warm draw interval **2,659 ms**. Headless draw timings are not graphical performance. |
| Backend pure selection | **160 passed / two skipped / 37 deselected**, eight named modules; no PostgreSQL fixture selected |
| Backend recovery wire direct-engine control | **Five passed / five deselected**, original backend/wire assertions; wrapper launch only replaced |
| Original selected backend invocation | **160 passed / two failed / five fixture errors / two skipped / 30 deselected**; environment/native failures retained |
| Translation completeness | **Fails: 176**, current POT, 16 missing messages × 11 languages |
| Ruff | **Fails: 18 findings**, five production, 13 tests |

Do not add these counts into a headline claiming that many independent product behaviors: assertions overlap, and parameterized checks repeat cases. The full client suite, full backend suite and service-dependent Store/Rivalry provider flows were not rerun.

All Godot runs emitted a sandbox root-certificate-store error. Client assertions can still exercise offline logic, but those runs are not error-free engine acceptance. The strict backend verifier correctly treats that error as failure; production validation was not weakened. An initial wrong-import-root pytest invocation and a headless invocation of the graphical pause test were corrected and retained as invocation errors, not manufactured product defects.

### Android matrix required before release

No device attachment check or test was performed. The OnePlus Nord 2 5G remains a required target, not a device measured in this audit.

| Device / configuration | Scenarios | Record and pass criteria |
|---|---|---|
| OnePlus Nord 2 5G, shipping renderer | Fresh install, first Account, direct Garage, ready/partial preload, every car, six profile tracks twice | Input callback/page/live latency; CPU/GPU/frame timeline and blocking intervals; same visual quality and controls |
| Lower-memory Android device within supported API range | Garage→race→results→editor→practice→Settings, 200 cycles; preload on/off; explicit pressure | PSS/RSS/graphics and transition peaks; matched post-trim baseline; no lost saves or unbounded count growth |
| Representative recent Android device | Long races, dense/complex tracks, rain/winter, effects first emission, all quality modes | Active frame distribution, memory, temperature, throttling and battery over an extended session |
| Different landscape aspect ratios / cutouts / density | All major menus, native keyboard, narrow/wide translations, Store, Rivalry, editor gestures | Safe-area bounds, readable text, reachable actions, touch ownership and correct Android Back behavior |
| Supported API boundary and current API, release build | Foreground/background, lock, audio focus, phone/notification interruption, process kill during save/upload | Durable recovery, correct pause/clock/input clearing, no duplicate reward, no stale account publication |
| Offline / unreliable connection | Timeout, duplicate/out-of-order reply, token expiry, sign-out/switch mid-request, resume from journal | Account fencing, idempotency, actionable error/retry, exact pending result retained |
| Provider test-track build | Sign-in, Billing purchase/pending/restore/refund, rewarded completion/SSV retry | Server-owned fulfillment, no double grant, consent/configuration verified, debug features absent |
| Final release artifact + service | Installed AAB splits, all vehicle assets/native ABI, privacy/contact, symbols, live authority | Matching client/API/worker contract hashes, complete resources, symbolication receipt and artifact hash |

### Release regression composition

1. Parse/build identity/resource/export checks on a frozen checkout.
2. Headless canonical rules, handling, creator, persistence, cap, account/cancellation and HTTP-boundary checks.
3. Required native UI/render lifetime and loader/first-emission checks, with resource/script warnings treated explicitly.
4. Backend auth/privacy/economy/ingress/trajectory/recovery plus disposable PostgreSQL concurrency/idempotency/rollover checks.
5. Localization completeness and lint; required language/layout fixtures.
6. Release artifact and physical-device acceptance, followed by a live read-only contract comparison. Keep provider operations in their disposable/test-track scope.

## G. Roadmap without effort estimates

| Phase | Required work | Dependency / risk | Expected result |
|---|---|---|---|
| 1 — Runtime and correctness acceptance | Integrate targeted trail/particle/grid improvements; accept latest preloader; rerun matching native profiles; finish test selection/prerequisites; eliminate unexplained fixture shutdown errors; correct translation/lint failures | Preserve appearance, canonical tick/countdown, evidence ownership and stale/cancellation fences. Establish frozen source/artifact identity first. | Measured load improvement and a dependable regression result; no invented claim that all stalls are gone |
| 2 — Device and commercial quality | 200-cycle Android PSS/pressure and long-session frame/thermal acceptance; final AAB/resource/config/symbol inspection; matching backend authority; production Billing/ads if required; privacy/support drill | Requires target hardware and provider/test-track configuration; production rollout is a separate authorized action | Evidence that the actual shipping build is correct, supportable and within device budgets |
| 3 — Maintainable ownership and explicit trust | Extract cohesive App lifecycle boundaries under tests; define competitive trust/reward policy; track pinned engine/SDK corrections and residual native graphics work | Avoid broad rewrites, policy changes or new telemetry without explicit product decisions; preserve historical evidence | Lower regression cost and clear guarantees for ranked results, rewards and support |

## H. Ten concrete next actions

These are ordered for current benefit and dependencies; they are not ten newly discovered bugs.

1. Replace per-instance identical tyre `Shader.new()` with immutable shader reuse, leaving material state independent.
2. Move the existing particle-staging prototype into a cancellable production preparation path without removing emitters or changing their first emission.
3. Reuse exact front-surface grid samples and prove full/simple mesh signatures stay identical.
4. Finish native/all-car/device acceptance of Garage preload and its direct, partial, ready and pressure-cancelled entry paths.
5. Run a 200-cycle target-device lifecycle soak with Android PSS/graphics sampling and long-recording transition peaks.
6. Add a maintained required-test/prerequisite manifest and make script/resource failures visible alongside assertion counts.
7. Resolve the four remaining Ogg shutdown references in a minimal control, without declaring them a player leak or hiding the warning.
8. Translate the 16 newer messages in all 11 catalogues and run completeness plus native text-fit checks.
9. Fix the 18 Ruff findings and separate read-only verification from build-identity generation.
10. Freeze a release artifact and compare its complete physics/rules/compiler/car hashes with API and worker authority before any rollout or competitive acceptance.

## I. Coverage, provenance and limits

Reviewed current source boundaries include App/navigation, live and preloaded Garage, preview/cache/reflection ownership, race presentation and preparation, packed controls/completed evidence/result queues, persistence/recovery, editor/native geometry, canonical handling/gates, histogram/request reuse, TLS/session storage, auth/privacy/commerce/trajectory/economy boundaries, diagnostics, export and development tools. Broader discovery, profiles, friends, Rivalry, challenges and Store were checked against source and retained prior tests; they did not all receive a fresh end-to-end graphical/provider run.

Fresh native images confirm a nonblank actual saved-finish Garage and actual race geometry/HUD; they do not constitute owner visual or physical-touch approval. See [saved live Garage](evidence/mobile-reaudit-2026-10-27/native-outputs/test_garage_live_entry/first-saved-live.png) and [Star race](evidence/mobile-reaudit-2026-10-27/load-profile/load-images/star_spline_lap-0.png).

The 50-cycle soak intentionally streams samples rather than retaining a growing sample history. It uses explicit empty backend configuration and isolated profiles, avoiding the earlier debug localhost fallback. Pressure/account samples are retained but excluded from the matched steady-state comparison by a stated filter; all raw samples remain available. Other CPU correctness tests overlapped this soak, so it is memory/lifetime evidence, not a comparative frame benchmark.

The only credential scan was a three-pattern location scan over inventoried source/configuration; it found no matching private-key/live-payment/GitHub-token patterns. Private environment/credential roots were excluded. This is not a complete secret, dependency, cloud IAM or live security audit. Selected backend tests use synthetic identities and isolated databases; no private production player data was exported.

Production code was not intentionally changed to make checks pass. Copied tests preserve assertions and fixture reads, adding only explicit offline setup/output redirects. Separate controls change only teardown settling or the blocked engine-launch wrapper; they are labelled and hashed. Raw failed invocations and UTF-16 logs are retained alongside normalized readable copies.

Concurrent changes mean the start and end inventories differ. Per-test copies/commands, source changes and artifact hashes are recorded; no whole-tree immutable snapshot is claimed. In particular, late preloader tests do not retroactively update an earlier process's timing or memory behavior. Final device/release acceptance must use a frozen source and artifact.

No physical-device query/test, APK/AAB build/install, real authentication/purchase, production save mutation, database migration/restore, deployment, owner-process restart, root staging/commit/merge, full-suite pass, legal compliance certification or complete cheat resistance is claimed.

The [audit-only Git patch](../build/re-audit-2026-10-27/audit-only.patch) contains this document, its evidence and the appended audit status blocks. It excludes all production/concurrent/generated-metadata changes. It is checked and applied in an isolated non-repository directory and compared byte-for-byte; see the [checkpoint receipt](evidence/mobile-reaudit-2026-10-27/checkpoint-verification.json). Nothing is staged or committed in the owner repository.
