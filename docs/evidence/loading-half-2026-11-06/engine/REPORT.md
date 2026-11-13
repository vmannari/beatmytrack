# Isolated custom Android engine build and packaging, 2026-11-06 to 07

ARM64 debug native compilation, final-input verification and isolated AAR/source ZIP packaging are complete. Build 03 succeeded in 553.344 seconds; final-helper build 04 succeeded in 28.391 seconds, reusing compiled objects and relinking the library. The relinked binary is byte-identical to the packaged source. All 53 AAR and 159 source ZIP entries pass CRC and SHA-256 checks. No APK export, signing, installed-template replacement or device action occurred.

| Artifact | Bytes | SHA-256 |
| --- | ---: | --- |
| `libgodot_android.so` | 79,694,736 | `01737d55f8e96836823cb9cc5c111c9d8183455a19288ae84fa3591ea44efb83` |
| `libc++_shared.so` | 9,290,184 | `0c52cfab2df0d957d8b346a2bdc5ae8d71feca2591924d77e1cd724d5bf74352` |
| `godot-lib.template_debug.aar` | 29,358,739 | `111716a9ce401aa5cd3684b1437276a5058d13ba026b1a26825f05e01922d637` |
| `android_source.arm64_debug.zip` | 29,241,543 | `e88092d03aa50229f2ddb8dcfa5ba0bf8eb4ffe6919ffeeee60c30929ef9a45d` |

The AAR/source ZIP are under `build/loading-half-20261106/android-custom-debug`. `packaging-result-01.json` records every retained entry hash, input/source/dependency identities and exact Java/resource preservation; its internal copy is `build/loading-half-20261106/android-custom-debug/packaging-receipt.json`. `build04-relink-identity.json` verifies the freshly relinked output against the packaged native source. The original debug AAR is retained with SHA-256 `9cfb115e508ce98e8cf9b655927ef894cdfc2fede18a82f995842388f7754102`.

## Build inputs and preservation

The engine remains the prepared Godot `4.7.2.stable` source at `build/biome-shader-profiles-20261106/godot-4.7.2-stable`. Runtime/profile source fingerprint remains `78661746f7673e61fe81ac52e9189019f2992679e36dff3bf6496c9e85672c49`. Android NDK `29.0.14206865` lives only under the task-owned `build/loading-half-20261106/android-sdk`. Direct compiler inspection reports Android Clang 21.0.0, build 13989888 (`ndk-compiler-version.log`).

The official Android source ZIP remains unchanged at `.tools/admob/android_source.zip`; packaging requires SHA-256 `a15416b528efb0a19a7d187e4d9f4e5336d0689144b111329fb4bd12c4447ad3`. Ordinary export/template checks remain unchanged. The new output keeps every non-JNI Java/resource AAR entry and every retained source ZIP entry byte-exact. Only the two ARM64 JNI libraries are replaced; other JNI ABIs and the official release AAR are explicitly omitted.

Pinned Swappy tag `from-source-2025-01-31` comes from the engine's own installer. The downloaded archive is retained under `build/loading-half-20261106/android-dependencies`, SHA-256 `2dd05484de29a3040106658d6f95915778fd71abc3261130eada6090ed1c153d`. `swappy-install.json` records its 15-entry CRC check, pinned installer hash, upstream source commit and exact installed hashes for all four static libraries. The installer helper writes only those four fixed members under the owned engine and refuses differing existing libraries. The engine requires all four files even when compiling only ARM64.

`swappy=yes` preserves the engine's Swappy capability and makes missing support fatal. `profiler=none` explicitly selects the default external tracing backend. The pinned Android template CI downloads Swappy and does not download Perfetto. The optional Perfetto installer requests an unpinned latest release; it was not run. This preserves normal engine/game profiling APIs but does not add the optional Perfetto backend.

## Build commands and recovered failures

```powershell
python -u native/biome_shader_profiles/build_android.py --sdk build/loading-half-20261106/android-sdk --arch arm64 --target template_debug --jobs 8 --build --receipt docs/evidence/loading-half-2026-11-06/engine/android-build-03.json
python -u native/biome_shader_profiles/build_android.py --sdk build/loading-half-20261106/android-sdk --arch arm64 --target template_debug --jobs 8 --build --receipt docs/evidence/loading-half-2026-11-06/engine/android-build-04.json
python -B docs/evidence/loading-half-2026-11-06/engine/package_android_debug.py --package --build-receipt docs/evidence/loading-half-2026-11-06/engine/android-build-04.json --output build/loading-half-20261106/android-custom-debug --receipt docs/evidence/loading-half-2026-11-06/engine/packaging-result-01.json
```

The generated SCons command uses `platform=android target=template_debug arch=arm64 ndk_platform=android-24 generate_android_binaries=no opengl3=yes vulkan=yes swappy=yes profiler=none debug_symbols=no optimize=speed lto=none -j8`. The validated absolute SDK path is present both in the command and in child-only `ANDROID_HOME`/`ANDROID_SDK_ROOT`; child-only `GIT_OPTIONAL_LOCKS=0` is also recorded. No Gradle/native binary auto-packaging is enabled.

The first build (`android-build.json`, `android-build.log`) failed before compilation because `detect.can_build()` reads the environment during platform discovery, before SCons applies command-line variables. The helper now passes the same validated SDK through the child environment. Build 02 entered actual compilation but warned about missing Swappy. It was cancelled through its owned exec session before producing a library; `android-build-02.log` and `android-build-02-cancelled.json` are retained. The attempted CIM process inventory was denied; the subsequent owned-session interrupt succeeded, and no NDK compiler processes remained in the follow-up observation.

The first sandboxed Swappy download could not connect. The reviewed network escalation downloaded the exact pinned public release into task storage; a PowerShell profile execution-policy warning did not prevent the download. There was no automatic approval rejection. No user SDK or installed template was written.

The pinned engine's compiler-version shell probe mishandles spaces in the validated SDK path. Actual SCons compiler invocations work. The direct compiler-version command in `ndk-compiler-version.log` confirms the intended pinned compiler; the original warning remains in the build logs. No engine patch or qualified fingerprint was changed to hide it.

## Independent review and verification

Review identified build-configuration files omitted by the established runtime/profile fingerprint. Separate `native_build_inputs` now bind the seven module files, `SConstruct`, `methods.py`, `platform_methods.py`, Android `detect.py` and `SCsub`; future helper builds check them before and after compilation. Packaging verifies those inputs and Swappy again before and after archive work. The qualified runtime fingerprint remains unchanged.

Build 03 was already running when this additional guard was introduced. `android-build-03-input-snapshot.json` explicitly records a **during-compilation** snapshot at `2026-11-06T22:27:42.985611+00:00`, rather than claiming a prior capture. The earlier `docs/evidence/biome-shader-profiles-2026-11-06/checkpoint.json` independently records identical hashes for all seven module files, including `config.py` and `SCsub`; `android-build-03-attested.json` retains this corroboration and the timing limitation without overwriting the original receipt. Final verification build 04 then captured strict before/after inputs with unchanged flags. SCons reused compiled objects and relinked the same library; it was an incremental verification, not a second clean rebuild. Packaging consumed only the successful 04 receipt, which includes the final build-helper hash.

The build helper now confines new receipt paths to owned build/evidence roots and uses exclusive creation. `build-receipt-guards.json` records four passing checks, including unchanged original failure-receipt bytes and rejection of an output outside those roots. The packager similarly refuses existing outputs/receipts, checks exact required SCons assignments, validates AArch64 ELF headers and both native hashes, pins the C++ runtime to the NDK copy, streams archive members, and rereads every output member for CRC/SHA-256 verification. Successful receipts include source/build/dependency identities and every retained archive entry hash.

Small synthetic archive tests are kept separate from the real large artifacts. **All 21 final tests pass** in 0.562 seconds (`package-fixture-identity-tests-02.log`), including stale/missing/extra native input maps, all four Swappy ABI paths/hashes/files, identity changes during packaging, missing/wrong required flags, and duplicate/conflicting arch/Swappy/SDK assignments in either position. No success receipt is created after an identity failure. Earlier 14- and 19-test passing logs are retained. Initial ZIP fixture normalization and lint findings remain documented in `PACKAGING.md`; no assertion was relaxed. Ruff passes for the implementation, fixtures and task helpers.

```powershell
python -B docs/evidence/loading-half-2026-11-06/engine/test_package_android_debug.py
.tools/backend-venv/Scripts/ruff.exe check native/biome_shader_profiles/build_android.py docs/evidence/loading-half-2026-11-06/engine/package_android_debug.py docs/evidence/loading-half-2026-11-06/engine/test_package_android_debug.py docs/evidence/loading-half-2026-11-06/engine/install_pinned_swappy.py docs/evidence/loading-half-2026-11-06/engine/attest_android_build_03.py
```

## Remaining qualification

The result is a source ZIP/AAR for **ARM64 debug only**. Official pinned Java bytecode/resources are reused for the native-only patch; they are not rebuilt. Full engine Java/source Gradle packaging has an uncached Nexus publish-plugin 1.3.0 dependency, and complete offline client dependency resolution has not been tested. Existing JDK/SDK/Gradle/keystore availability and the isolated follow-up path are documented in `PACKAGING.md`; no keystore secret was read.

An APK/client export, signature/alignment and full asset checks remain separate. Android execution, JNI/runtime compatibility, matching device/driver shader profile capture, fallback controls, visual and driving checks, lifecycle behavior and frame timing remain unqualified. Desktop NVIDIA profile contexts do not imply Android profiles. These build/package artifacts establish no device speedup and no 50% loading result.
