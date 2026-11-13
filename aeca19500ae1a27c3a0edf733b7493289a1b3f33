# Race-time work re-audit — 2026-10-27

The earlier improvements still hold. In both headless and native desktop runs, an additional **35-second active-driving window** produced **zero HTTP requests, zero old-upload flushes, zero header captures/reads and zero menu-snapshot writes**, despite seeded pending operations. The retained Garage stayed disabled and ordinary editor memory sampling stayed stopped.

The remaining findings are two conditional late-completion paths and two small per-frame jobs. They are narrower than the original polling problems. None is established as a cause of race stutters, and this audit does not estimate production bills or Android frame rates.

This is an audit, not another runtime optimization. Only the audit fixture, report and evidence are added. Production code, owner data/processes, backend services, deployments, devices and APKs are untouched by this task.

## Remaining findings

| ID / priority | Finding | Evidence and limit | Suggested change |
| --- | --- | --- | --- |
| R01 / medium | A late menu response can dispatch an optional cache write during racing. | `backend/menu_snapshot_writer.gd:40` runs independently of the App race guard. Injecting one late cache snapshot wrote a 16,432-byte private file with the race active and policy closed. Native completion wall time was 48.306 ms across async/frame waits; **this is not a 48 ms main-thread stall**. No snapshot write occurred in the natural window. | Keep RAM cache freshness and coalescing, but defer dispatch of new optional disk snapshots until results/menu. Let an already active atomic write finish safely. |
| R02 / medium | A completed header PNG is published before checking whether its consumer is allowed. | `ui/header_car_appearance_cache.gd:82` handles completed I/O before its `allowed` check. A ready in-memory PNG result caused mipmap generation, `ImageTexture` creation and a changed notification while capture permission was false. Native callback time was 836 µs; headless was 350 µs. The image has 78,848 base RGBA bytes, before mipmaps/driver overhead. No studio was created, and this did not occur in the natural window. | Hold the ready image until its header/menu consumer is allowed. Revalidate account epoch and appearance key before publication. |
| R03 / low | Pause-only presentation state is assembled during every unpaused race frame. | Source inspection of `core/game.gd:601` shows a 16-value `pause_key` array constructed unconditionally, compared only when paused, then discarded on the active branch. No isolated timing or FPS effect is claimed. | Construct the key inside the paused branch while retaining camera, locale, rewind and other pause invalidations. |
| R04 / very low | The empty Garage preloader still receives frame callbacks and resets empty state during races. | Runtime inventory confirms it can process while `has_work()` is false, with no pending loads or studio. Its source calls `_poll_loads()` and `_reset()` on this branch. A 120-call empty-callback probe measured a median of 1 µs and maximum 6 µs on native desktop—near the timer's resolution. It started no studio, capture or download. | After required cleanup/load reaping, suspend its callback until a navigation, account/selection or race-end event can make preloading useful. This is cleanup, not a demonstrated bottleneck. |

R01 and R02 are **eligibility counterexamples**, not observations that every race performs these jobs. The probes deliberately model a menu reply or PNG read completing after the race begins. The normal race window was quiet. The snapshot probe used private synthetic data; the header probe used an in-memory test image and restored the shared icon-cache entry afterward.

There is also a source-only Android opportunity: `platform/challenge_links.gd:23` polls the native intent bridge every 0.5 seconds. `BmtChallenges.java:60` posts `readIntent()` to the Android UI thread on every call. The consumed-intent identity guard prevents repeated parsing of the same intent, but the bridge/UI-thread round trip remains. An intent/lifecycle notification could replace this polling. Preserve cold-start and foreground link delivery; no Android runtime cost or device behavior was measured here, and the existing poll must not simply be removed without a replacement.

## What remained quiet and correct

- The original demand-work regression passed **40 checks on headless and 40 on native Compatibility**. It still verifies direct callback guards, pending purchase/upload identities, deferred achievement invalidation, empty-queue sleeping, relevant visible result polling, real memory-pressure handling and menu return.
- The expanded audit passed **50 checks on each renderer**, including the original 40 and ten additional observations/counterexample checks. These counts overlap; they are not 180 independent scenarios or a finding-free certificate.
- The longer windows advanced 4,200 headless and 4,202 native simulation ticks while remaining unpaused. Each crossed both the 15-second purchase timer and the 30-second appearance timer with pending state present.
- Telemetry and game-configuration transport remained disabled, old-upload flush counters stayed zero, and the editor-memory sampling deadline did not advance.
- Header capture count, header disk-hit count and active header-world count stayed zero. The three parked Garage SubViewports remained `UPDATE_DISABLED` and could not process.
- Vehicle-condition save attempts increased by seven in each 35-second window. This is current-race state protection, not evidence of seven disk writes: the condition store deduplicates unchanged state and uses its bounded writer.
- Audio, consent-based quality counters, result-save durability, tutorial/rewind guidance and ownership cleanup still appear in the processing inventory. A callback being present is not evidence of unnecessary work; the audit distinguishes their purpose from optional menu work.
- None of the four completed processes emitted the earlier two-instance ObjectDB shutdown warning. This is a non-reproduction in these runs, not a proof of leak-free long sessions. The engine's root-certificate-store initialization error remains in stderr; there were no script errors in these runs and no real HTTP transport was used.

## Reproduction and source identity

Fixture: `game/tests/audit_race_work_recheck.gd`, derived from the retained demand-work fixture without changing its original assertions. The extra probes run before memory-pressure teardown, while the real parked Garage and production race still exist. Requests are intercepted at both the API and lower transport boundary; the synthetic account is installed only after offline race entry.

The pinned engine is Godot `4.7.2.stable.official.ed1daf0bf`. Both runs use a 60-fps cap and private APPDATA/LOCALAPPDATA, records, journals and derived cache files. Native testing used Windows OpenGL Compatibility on an NVIDIA GeForce RTX 3090, in a separate offscreen window with engine-local accelerator injection. No owner-window input or owner-process restart was used.

The fresh-profile driving fixture uses the default Compact and first installed circuit, Ellipse. It does not load an owner's ghost library or account history. The same artificial pending upload, purchase, appearance and result contexts are seeded in both renderers.

The retained runs record 17 audited source hashes; the expanded runs record 25, including the newer header/preloader/snapshot helpers. **All hashes matched between the start and end of every run**, and the archived production-source hashes match the expanded runs. Concurrent work was preserved. Exact commands, durations, stdout/stderr, JSON observations and source archives are indexed in `docs/evidence/race-background-work-audit-2026-10-27/report.json`.

After the runs, concurrent work added a `max_draw_ms` timing counter to `garage_preloaded_studio.gd` and a headless-only asset-loading fallback to `garage_preloader.gd`. Those differences are archived separately from the audited version. Source review confirms that neither changes the four finding paths; the headless loading branch comes after the race branch's early return. These later edits were not executed in the recorded runs. No source was rolled back to make the hash checks pass.

The 35-second interval is a bounded timer/transport check, not a five-lap endurance or capacity result. Both processes ran functional probes concurrently, so these observations are not a controlled CPU/GPU benchmark. The late snapshot's completion time includes scheduling and frame waits; the header/preloader timings are local callback measurements. Successful large HTTP replies, active real purchases, every car/theme/mode, Android lifecycle delivery and sustained low-memory/long-session operation are outside this audit.

The separate older AI-driving replay failure from the prior report was not rerun or changed. This audit makes no claim that it has been fixed. Cold shader/model-construction stalls also require their own attribution; quiet background transport does not establish that those stalls are gone.

The next useful pass is small: close the two completion-order gaps, then remove the pause-only allocation and idle preloader callbacks. There is no evidence here that another broad backend or race architecture rewrite is needed.
