# Camera settings save failure — 2026-11-09

CSF01: Camera Apply must save and change the paused race view. CSF02: Preserve all supported cars' condition masks, PBs, unrelated preferences, atomic failure handling and the bounded file reader.

The PC game log reports `Local car condition save failed: Out of memory`. This is the condition sidecar's fixed 131,072-byte admission limit, rather than evidence of exhausted system memory. Current snapshots contain three 4,096-byte masks, encoded as base64. Nine accepted car IDs (including retained older cars) produce a valid 149,450-byte packet. `LocalRecords.save_records()` first flushes that packet; its size rejection aborts Settings Apply, so the camera also stays unchanged.

Changed `game/persistence/condition_store.gd`: raise its read/write limit to 262,144 bytes and correct the obsolete five-car comment. Collection validation, per-mask validation, atomic replacement, backup recovery and failure rollback remain intact. No save migration is necessary.

Added `game/tests/test_camera_condition_capacity.gd` and its UID. The regression queues real condition snapshots for every accepted car, opens the actual paused Game Settings, chooses Follow car and applies. It checks persistence, exact serialized masks, fresh sidecar loading, retry, unchanged starting simulation state, PB/favorites preservation and rejection above the new file limit.

Executed with the official pinned Godot 4.7.2 through `scripts/dev.ps1`. Each command used a disposable APPDATA directory under `build/camera-save-fix-2026-11-09` and an empty `BMT_API_URL`:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_camera_condition_capacity.gd -Graphical -RenderingMethod gl_compatibility -CommandTimeoutSeconds 180
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_camera_modes.gd -CommandTimeoutSeconds 180
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_condition_store.gd -CommandTimeoutSeconds 180
```

Results: final native capacity regression **15 checks, 0 failures**; original camera suite **1,502 checks, 0 failures**; condition store **31 checks, 0 failures**, including its deliberate blocked-write recovery. The applied camera menu is captured at `build/camera-save-fix-2026-11-09/pause-camera.png`.

Final command logs: `build/logs/TestScript-29880/test-script.log` (capacity/native), `build/logs/TestScript-16416/test-script.log` (camera) and `build/logs/TestScript-11928/test-script.log` (condition store). Task-only patch: `build/camera-save-fix-2026-11-09/source.patch`; reverse application was checked without touching the main index.

Retained unsuccessful attempts: sandbox engine startup was denied; the same isolated tests ran with escalation. Original source reproduces the out-of-memory warning and failed camera Apply (`build/logs/TestScript-16848/test-script.log`); the first reproduction harness then tried parsing a nonexistent rejected packet. A draft catalogue-sized constant was rejected as a nonconstant GDScript expression (`TestScript-18052`); the final fixed 256 KiB constant parses. The initial fresh-reader assertion compared original binary floats against JSON-parsed numbers (`TestScript-2708`, 13/1); it now compares the exact committed JSON packet. The masks and every supported car remain checked.

The owner game process and owner save files were not changed. Read-only inspection of PC logs identified the matching failure. No device query/test, APK build/install, backend request or deployment was performed. The game must reload the corrected source; owner confirmation remains. Routine build identity updates from the development entry point and concurrent work are outside this task's source patch. No main-index staging or commit was performed.
