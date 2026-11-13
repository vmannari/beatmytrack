# Isolated Android ARM64 debug packaging

`package_android_debug.py` turns the root task's successful SCons native build into a task-owned debug AAR and Android source ZIP. It does not build/export/sign an APK, run Gradle, contact a device, download dependencies, or change installed templates/SDKs. Run from the repository root with Python 3.10 or newer; the helper uses only Python's standard library.

Preflight intentionally does not hash/decompress the large official archive or built engine library. It validates the prepared engine fingerprint, separate build-input hashes, pinned Swappy static-library hashes, paths, successful build receipt and AArch64 ELF headers when the libraries exist. The first real preflight is retained in `packaging-preflight-01.json`; at that time the build receipt and both native libraries were absent.

```powershell
python -B docs/evidence/loading-half-2026-11-06/engine/package_android_debug.py --build-receipt docs/evidence/loading-half-2026-11-06/engine/android-build-04.json --output build/loading-half-20261106/android-custom-debug-next
```

After SCons succeeds and native timing runs finish, pass the actual successful receipt path and a new output directory:

```powershell
python -B docs/evidence/loading-half-2026-11-06/engine/package_android_debug.py --package --build-receipt docs/evidence/loading-half-2026-11-06/engine/android-build-04.json --output build/loading-half-20261106/android-custom-debug-next --receipt docs/evidence/loading-half-2026-11-06/engine/packaging-result-next.json
```

The helper refuses an existing output directory or explicit receipt. Failures preserve partial artifacts in the task-owned directory and do not publish an internal success receipt. Outputs are `godot-lib.template_debug.aar`, `android_source.arm64_debug.zip`, `original-debug.aar` and `packaging-receipt.json`. Retain the receipt with the archives; `ready` alone means preflight passed, while `packaged: true` and `source_hash_verified: true` identify completed archive checks.

## Exact inputs and preservation

- Prepared engine: `build/biome-shader-profiles-20261106/godot-4.7.2-stable`; the root-owned `build_android.py` verifier checks the pinned version, prepared patch/module and source fingerprint.
- Official source ZIP: `.tools/admob/android_source.zip`; required SHA-256 `a15416b528efb0a19a7d187e4d9f4e5336d0689144b111329fb4bd12c4447ad3`, matching the existing ordinary export pin. There is no alternate-hash option.
- Native build receipt must report successful `platform=android target=template_debug arch=arm64 generate_android_binaries=no opengl3=yes vulkan=yes swappy=yes profiler=none ndk_platform=android-24 debug_symbols=no optimize=speed lto=none`, NDK `29.0.14206865`, the same source fingerprint/engine path and exact SDK argument. Each required flag must appear exactly once; contradictory or duplicate assignments are rejected. Separate native build-input hashes and pinned Swappy receipt/current-library hashes must match. Both `libgodot_android.so` and `libc++_shared.so` must match the successful build's SHA-256 values.
- Both libraries come from `platform/android/java/lib/libs/debug/arm64-v8a/`. Both must be ELF64, little-endian, AArch64 shared libraries. The C++ runtime must also match the receipt's NDK runtime under `toolchains/llvm/prebuilt/windows-x86_64/sysroot/usr/lib/aarch64-linux-android/`.
- All non-JNI debug AAR members retain their exact uncompressed bytes, including Java bytecode, manifest and resources. JNI entries for other ABIs are removed. All source ZIP members retain their exact bytes except the replaced debug AAR and omitted `libs/release/` members. The release omission makes this explicitly debug-only.
- Every output archive entry is read back for CRC and SHA-256 validation; the receipt records its hash, complete entry inventory, removed entries, artifact hashes, source fingerprint, official original-AAR hash and build-receipt hash. The source ZIP and native libraries are rechecked after packaging for concurrent changes.

The native patch/module changes GLES preparation and introduces no Java/JNI API changes. Reusing the pinned official Java/resources therefore avoids a separate Java build, but this is not proof of Android startup or runtime compatibility. Do not use this overlay method for future changes to Java, JNI signatures, Android resources or manifest requirements without reevaluating the source/template pairing.

## Remaining local client requirements

The packaging helper itself needs none of these tools. A later authorized isolated Gradle/client build requires them:

| Component | Read-only inventory in this workspace |
| --- | --- |
| Native compiler | Task-owned NDK `29.0.14206865` under `build/loading-half-20261106/android-sdk/ndk/`; root owns SCons build. |
| Java | Configured Temurin JDK `17.0.20.1+1`; `java`, `javac`, `jarsigner` and `keytool` exist. |
| Android platform/build tools | User SDK contains platform `android-36` and build-tools `36.1.0`; the task SDK currently contains only the NDK. Copy required components/licenses into an owned SDK before running tools that might write SDK metadata. Do not create writable junctions to the user SDK. |
| Gradle | Wrapper `8.11.1` is cached. AGP `8.6.1`, Kotlin `2.1.21`, Fragment `1.8.6`, DocumentFile `1.1.0`, SplashScreen `1.0.1` and the current game plugin dependencies have cache entries. Their complete offline resolution has not been executed or established. |
| Full Java/source build alternative | The engine Gradle source uses Nexus publish-plugin `1.3.0`, which was not found in the existing cache. Therefore an offline `generateGodotTemplates` build cannot be promised. It also expects `scons.bat` on PATH even when native regeneration is excluded. |
| Debug signing | Existing configured Godot and default Android debug-keystore paths exist; no keystore contents, passwords or private material were read. No signing has occurred. |

For an isolated client, use a copied project, owned `APPDATA`/`LOCALAPPDATA`/`GRADLE_USER_HOME`, an owned SDK and copied Gradle cache. The Godot Gradle option is `gradle_build/android_source_template`; `custom_template/debug` selects the non-Gradle APK template and does not substitute this source ZIP. Keep the ordinary `scripts/dev.ps1` official template hash gate unchanged. Avoid running it on a source ZIP whose hash was intentionally changed by this helper.

The source ZIP's `debugImplementation` resolves only `libs/debug`, so the omitted release AAR is not needed for the debug dependency set. Select ARM64 only. A later client build can use the existing `doNotStrip` Gradle property if exact engine/runtime bytes must survive into the APK for identity checks. APK ZIP/ABI/native hashes, asset provenance, signature and alignment checks still remain after export.

Android shader profiles remain unqualified. Desktop NVIDIA contexts are not Android contexts; a native library, AAR or APK is not a device speedup result. Matching-device capture, missing-variant fallback controls, visuals, race behavior, frame timing and lifecycle qualification remain separate work.

## Small fixture verification

`test_package_android_debug.py` uses tiny synthetic ZIP/AAR/ELF fixtures in temporary directories. It covers exact retained bytes, both native replacements, removal of unsupported variants, output hashes/CRCs, wrong source/native/runtime hashes, build-receipt changes, stale/failed/wrong-variant receipts, missing libraries, unsafe member names, duplicate/symlink members, invalid ELF ABI and output path confinement. No real large archive is packaged by this test.

```powershell
python -B docs/evidence/loading-half-2026-11-06/engine/test_package_android_debug.py
.tools/backend-venv/Scripts/ruff.exe check docs/evidence/loading-half-2026-11-06/engine/package_android_debug.py docs/evidence/loading-half-2026-11-06/engine/test_package_android_debug.py
```

Initial fixture execution passed nine tests and failed one backslash-path subcase because Python normalizes Windows separators when creating a ZIP. The fixture now injects the original member name into the read-side metadata to exercise the existing rejection guard. The following 14-test run passed; its PowerShell stderr formatting is retained in `packaging-tests-02.log`. The default Python environment lacked Ruff; the existing task backend environment supplies it. Initial lint findings were import order, exception type and nested context formatting; no validation was removed.

Initial final verification: all 14 tests pass in `packaging-tests-03.log`; Ruff passes in `packaging-ruff-03.log`. Later independent identity guards/tests and the real build04 packaging are recorded in `REPORT.md`. Real engine packaging is now complete, with all 53 AAR and 159 source ZIP entries verified in `packaging-result-01.json`. The commands above deliberately select fresh output names to preserve those artifacts.
