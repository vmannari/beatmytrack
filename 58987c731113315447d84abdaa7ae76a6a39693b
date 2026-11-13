# Runtime, memory and correctness: concrete work list

Implementation follow-up: [26 October fixes and actual validation](RUNTIME_MEMORY_CORRECTNESS_FIXES_2026_10_26.md). The original investigation list below is retained; the follow-up distinguishes completed code/checks from remaining cold-load and physical-device acceptance.

26 October 2026. This narrows the earlier roadmap to changes and checks in the current source. No implementation or new runtime/device test was performed while writing this list. There are no effort estimates.

Several original audit recommendations already have implementations in the working tree: deferred Garage creation, cached carousel images, independent car-reflection updates, one integer per recorded input, trajectory-native local journals, and node-owned pause-button fitting. Preserve those changes and verify them; do not repeat the old fixes. Source inspection alone does not establish that they pass on the target device.

## Runtime

### R1. Verify the new startup and Garage rendering paths

**Where:** `game/core/app.gd` startup and `_prepare_garage_covered`; `game/ui/garage_page.gd::_build_carousel`; `game/ui/car_showroom.gd::_submit_render`.

- Run fresh Account/Race startup without entering Garage. Count native Garage showrooms and record time until the screen accepts input. The initial screens should create none of those Garage worlds.
- Enter Garage with empty and warm image caches. Confirm seven image cards, one interactive native showroom, and at most one temporary native renderer for a missing image. Inspect actual first-entry responsiveness rather than only startup time.
- Play menu music without moving the camera or changing the car. Confirm the car-only reflection is not resubmitted for vinyl rotation. Orbit, wash, snow melt, resize and car changes must still update the required captures.
- Leave Garage for racing or another screen. Confirm its hidden main/reflection views stop submitting draws and no delayed preview callback brings them back.

**Finished when:** current cold/warm timings, viewport counts and submission counters demonstrate those behaviors, with matched visible images. The old 25-second/24-viewport measurement remains historical evidence until replaced by this run.

### R2. Move Garage preview file work off the main thread

**Where:** `game/ui/garage_preview_cache.gd::_cached`, `_capture`, `_trim`.

The current cache reads/decodes PNGs, encodes/writes PNGs and scans file metadata synchronously from UI/capture callbacks.

- Have a bounded worker read/decode cached PNG data and encode/write completed captures. Keep required rendering/readback and texture publication on the appropriate engine thread; measure readback separately because moving file work does not remove that stall.
- Keep one temporary native renderer and a bounded number of IO jobs. Do not start one worker per card or paint change.
- Carry the preview key through every job. If paint, parts, condition, account or screen ownership changes, discard the stale publication and retire its renderer/job safely.
- Pause or cancel unnecessary preview generation when Garage becomes hidden or racing starts. Ensure a corrupt/missing cache image falls back without a blank permanent card.

**Finished when:** browsing and swiping Garage during a cold customized-preview fill do not inherit PNG encoding/disk stalls, and cards never publish an image for the wrong current state.

### R3. Find and remove the remaining indivisible race-loading work

**Where:** `game/track/prepared_world_cache.gd::remember_cooperative` / `restore_cooperative`, `game/track/native_track_visual.gd`, and ordinary App race entry.

- Time `PackedScene.pack`, scene instantiation, individual mesh construction/upload and first shader draws separately. The current cooperative cache still performs one indivisible `scene.pack(holder)`.
- Run cold and repeated loading of the Star spline fixture plus current normal-part Storm tracks through actual App race entry. The old profiler's direct scene construction is insufficient to characterize the real loading cover.
- If a single world pack/instantiate causes the measured hitch, cache and install bounded existing spatial sections rather than one whole-world scene. If mesh uploads or shader first use dominate, stage those under the cover instead. Change the measured blocker, preserving the existing appearance and cache identity.
- Cancel during each stage and immediately choose another track. Work from the abandoned track must not attach to the new race.

**Finished when:** a stage trace identifies and removes the actual long input/render-blocking operation; repeated loads reuse completed work and cancellation remains correct. This is a specific investigation, not a claim that packing is already proven to be the slowest stage.

### R4. Stop recomputing the unchanged paused race

**Where:** `game/core/game.gd::_present_frame_scoped` and `toggle_pause`.

- After the pause capture/state settles, stop repeating unchanged wheel/surface/bridge/water/contact queries, car pose uploads, prop transforms and race HUD reconstruction on every display frame.
- Keep pause-menu interaction, audio state changes and any deliberately visible settling/fade behavior running. Invalidate the frozen presentation on resize, relevant settings changes or another actual visual change.
- On resume, clear held controls as the current code already does, refresh presentation once and continue the same canonical tick/state.

**Finished when:** counters show no repeated unchanged world work during an idle pause; the picture/menu remains correct and resume produces no input burst, pose jump or time advancement.

## Memory

### M1. Replace the generic integer Array with a packed recording buffer

**Where:** `game/core/game.gd::online_frames`, `game/race/attempt_evidence.gd`, `game/race/input_record.gd`, `game/backend/result_save_queue.gd`, CloudTracks signatures and rewind consumers.

The current integer encoding removes nested per-frame arrays, but `online_frames` remains a generic `Array` of Variants.

- Store the live canonical records in `PackedInt64Array` or an equivalently compact buffer. Change append, handoff, duplication, count and rewind callers together.
- Keep legacy Array-of-frames decoding at the persistence/diagnostic boundary rather than rebuilding nested arrays during ordinary racing.
- Preserve signed steering, throttle, brake, handbrake, first-frame launch markers and monotonic input offsets through rewinds.

**Finished when:** measure the actual maximum-length recording buffer; it has no per-frame Variant/container allocation, and old/new formats reproduce exactly the same canonical inputs and rewind offsets.

### M2. Stop deep-copying full proof and ghost data inside result tickets

**Where:** `game/core/app.gd::_save_result_upload`, `game/backend/cloud_tracks.gd::enqueue_completed`, `game/backend/result_save_queue.gd::enqueue`.

Completed tickets carry `_race_proof` and `_race_ghost`. Both CloudTracks and the result queue deep-copy tickets, so their contents are copied along with the small ticket metadata.

- Separate small ticket/account/origin/submission metadata from the large immutable input/proof/ghost packet.
- Transfer ownership of the completed packet to the save service. Copy mutable metadata where needed, while retaining one owned immutable copy of the evidence.
- Let Game destruction release its reference without dropping the save. Restart/rewind must never mutate a packet already handed off.

**Finished when:** a maximum-length finish does not create multiple deep copies of all evidence on the UI frame; navigation remains immediate, saved hashes remain consistent and the queued result survives freeing Game.

### M3. Limit pending saves by their complete byte footprint

**Where:** `game/backend/result_save_queue.gd`.

The current queue limits 16 jobs and 432,000 frames; that does not describe the memory held by ticket/proof/ghost data and the encoder's active buffers.

- Account for inputs, proof, ghost, metadata and the active serialization packet together. Define a byte ceiling and reserve headroom before accepting another online attempt.
- Persist finished work promptly and release its memory only after the durable write succeeds. Keep one encoder active rather than spawning competing large serialization jobs.
- When storage fails or the allowance is full, keep recovery visible, preserve existing work and keep ordinary offline driving available.

**Finished when:** several long completions with a deliberately blocked disk stay within the declared memory ceiling, do not silently lose a result, and do not become an unlimited allocation queue.

### M4. Include retained Garage/image resources in memory-pressure cleanup

**Where:** `game/core/app.gd::_notification`, `game/editor/editor_memory.gd`, retained Garage and preview caches.

App routes OS memory warnings to the editor retention helper. Its accounting includes several race/editor caches but does not represent the full retained Garage and preview-image working set.

- Add explicit accounting and pressure-release hooks for hidden Garage resources and decoded preview textures, alongside existing road/world/editor caches. Count GPU/texture working sets separately from source-file sizes.
- Discard optional retained views/images when needed, preserving saves, equipped cosmetics and in-flight result ownership. Rebuild them safely when revisited.
- Run the actual Garage → race → results → Garage → editor → practice → Settings loop at least 50 times, extending to 200 in automation. Compare the same states after cache warm-up; include account changes and memory-pressure events.

**Finished when:** memory reaches an explained plateau, hidden optional resources release under pressure and revisiting a screen does not show stale content or lose work. Use Android PSS/graphics measurements for final acceptance; Godot static memory alone cannot establish this.

## Correctness

### C1. Restore the missing Forklift news asset

**Where:** `game/assets/news/vehicles/forklift.png` and its news/catalogue references.

- The file is currently absent. Restore/regenerate the intended cleared asset through the established vehicle-photo path, or correct a genuinely obsolete reference.
- Verify all seven vehicle images resolve in a fresh import and packaged resource inventory. Do not hide the missing file by disabling the feature or suppressing errors.

**Finished when:** a clean App run and the affected news/catalogue screens open without missing-resource errors. This read-only file observation is not a new completed App test.

### C2. Make the multi-file finished-result save recoverable across process death

**Where:** `game/backend/cloud_tracks.gd::_queue_run_io`, `_save_pending_job_files`, `_discover_pending`; result queue acknowledgments.

The replay payload is currently written before the job metadata/marker. A process death between those writes can leave payload data without the ticket/submission metadata needed to recover it.

- Stage a recoverable manifest containing the original account, origin, ticket, submission key, wire options and expected payload identity. Atomically publish completed payload/job state and have startup recovery understand every partial phase.
- Do not present in-memory queue ownership as a completed durable save. Keep saving, saved and upload-pending states distinct; successful online retries retain the same operation key.
- Inject a kill after payload creation, between marker/job commits, after server acceptance and before the reply is saved. Also inject ENOSPC and failed renames.

**Finished when:** every fully committed result recovers once; partial writes are classified safely; an acknowledged save is never lost; repeated recovery cannot duplicate a score/reward or assign the result to a different account.

### C3. Verify old and new recording formats with real recovery cases

**Where:** `game/race/input_record.gd`, CloudTracks outbox loading/submission, and rewind recording.

- Start with an old input-only journal, an old frames-plus-proof journal and the new `bmt-local-trajectory-v1` journal. Restart and retry each through an owned service fixture.
- Cover steering −127/127, a nonzero handbrake, early/valid launch markers, three rewinds and the 216,000-frame boundary.
- Switch accounts during saving/upload, then return to the original account. Verify its result still has the original ticket/key/manifest and never appears in the other account.

**Finished when:** all three formats recover correctly and do not change their original request identity, input semantics, timing or reward count. Add only missing cases to the existing regression corpus.

### C4. Test late replies against real restart and navigation flows

**Where:** App race preparation/restart; BackendClient; discovery, challenge and Rivalry adapters.

- Hold the first race-start response, select another car/track or leave the screen, then release it. It must not launch or mutate the new selection.
- Fail a restart ticket request. The current race and its original ticket must remain usable; retrying must not consume another operation/try accidentally.
- Return a response after logout/account change or after its view was freed. No old callback may update current caches, controls or Game.
- Replace incomplete test doubles where they no longer represent the real Game properties; preserve the actual restart/offline assertions.

**Finished when:** these sequences pass through actual App entry/return paths with no stale attachment, lost active ticket, duplicate start or freed-node error. These are required checks, not claims that every current fence is broken.

### C5. Protect lap, rewind, pause and editor results during optimization

- Retain existing canonical recordings and run them after each runtime/memory slice: finish-line jitter/wrong-way crossing, ordered checkpoints, bridge upper/lower paths, rewinding before a checkpoint/finish and repeating a completion callback.
- Background during countdown, live driving, rewind selection and results. Return with no held accelerator/steering and no elapsed race ticks while paused.
- Round-trip each corrected Storm draft through Edit → save → reload → Test drive → return. Preserve ordinary road parts, generated route, start line and all 207 intentional objects; exercise undo/redo and interrupted autosave.
- Re-run the current node-owned pause-button implementation under immediate/queued destruction, rapid submenu changes, resize and translation changes. It is already implemented, so verify it rather than restoring the old lambda.

**Finished when:** timing, lap count, PB selection, rewind offsets, local records and editor geometry are unchanged by the performance/memory work; current controls/cameras/physics contracts remain; no script/runtime errors are hidden behind a zero process exit code.

## Recommended first changes

1. C1: resolve the active missing asset so normal App checks can run.
2. C2: close the result-save recovery window.
3. M2 then M1: remove full-evidence deep copies and finish the compact live buffer.
4. R2: take PNG/disk work out of Garage input frames.
5. M3–M4: bound pending/retained memory and exercise pressure cleanup.
6. R3–R4: attribute the remaining load hitch and remove unchanged paused work.
7. R1 and C3–C5: verify the new code paths and protected behavior on the current build, followed by actual target-device frame/memory/soak measurements.

This list distinguishes inspected code changes from verification tasks. It does not prescribe another broad refactor or make the original audit's measurements current again.
