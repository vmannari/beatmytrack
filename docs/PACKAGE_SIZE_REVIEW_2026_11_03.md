# Game package size review — 2026-11-03

The existing Android debug APK is **514,295,809 bytes / 490.47 MiB**. The strongest first optimization is excluding superseded assets from exports: **108.55 MiB of existing APK payload** has no references in the inspected current runtime text or binary-resource dependencies. Separating the phone build from the x86 emulator build adds **79.79 MiB** of potential savings. These are measured removal candidates, not a rebuilt or gameplay-validated package.

## Scope and requirements

- PKS01: Measure the existing binary package, independently of repository/source sizes.
- PKS02: Identify its largest costs and check current resource references.
- PKS03: Rank and quantify optimization candidates without changing shipping behavior.

Inspected `build/android/circuit01-debug.apk`, modified **2026-11-02 18:43:52 Helsinki time**, SHA-256 `0691f1d99dce1a48f738cb8fbd3544ce4493263b5e4d77ea9223b4a0ecd1fbc8`. Its embedded version marker is `0.3.0-creator.94c7115c80cc776f0f94aa04b32e8033`; today's workspace has a newer identity. There is only an Android Debug export preset. This review concerns that actual Android artifact; it does not claim a Windows/release/AAB size.

The archive has 24,272 entries: 485.22 MiB compressed entry payload, 5.26 MiB container overhead, and 566.20 MiB summed uncompressed entry sizes. The last figure is **not** a measured installed size. ZIP sizes also differ from Play's compressed delivery sizes.

## What occupies the package

Imported textures, audio and fonts were mapped back to source asset families using `.import` remaps. These are actual APK entry payload sizes, not the larger master PNG/WAV/TTF sizes. Fourteen unmatched old imports account for 2.73 MiB and are conservatively left out of cleanup estimates.

| Category | APK payload MiB | Observation |
| --- | ---: | --- |
| ARM64 native libraries | 75.06 | Includes 72.65 MiB Godot engine; libraries stored uncompressed |
| x86_64 native libraries | 79.79 | Second architecture for emulator/Intel devices |
| All vehicle mesh banks | 138.86 | Includes 82.06 MiB candidate obsolete banks; excludes imported previews |
| Challenge artwork | 33.39 | Only 6.90 MiB belongs to the five current poster images and associated entries |
| Livery preview photographs | 22.34 | Real current-model previews; retain their fast menu behavior |
| Vehicle audio | 22.09 | Forklift deliberately uses the `pickup` engine bank; names alone cannot establish obsolescence |
| Multilingual fonts | 15.68 | Current Japanese/Korean and other language coverage |
| Shared textures | 14.40 | Imported GPU/image resources, not raw image source totals |
| Fourteen supplied music records | 12.78 | Already compressed MP3s |
| Main menu assets outside subfolders | 10.52 | Further artwork audit possible |
| Android Java/Kotlin DEX | 7.69 | Six DEX files; requires a release shrinker experiment to establish savings |

Other sizable current assets include modular kit scenes (25.02 MiB, included in the vehicle-bank total), modular bases (13.61 MiB, also included), Garage car templates (6.93 MiB), the old exploration menu audio family (5.31 MiB), and ambience (4.62 MiB). Do not add the modular subtotals to the vehicle-bank total again.

## Ranked optimization options

### 1. Exclude superseded banks and artwork: 108.55 MiB candidate saving

`game/export_presets.cfg` uses `export_filter="all_resources"`. Its exclusions already remove tests, music working files, Windows libraries, several source WAVs and the old adaptive music stems. The remaining old resource versions still enter the APK. Godot documents that this mode exports every resource; an explicit exclusion list is the natural first intervention. [Godot export resource options](https://docs.godotengine.org/en/latest/tutorials/export/exporting_projects.html#resource-options).

**46 vehicle directories contribute 82.0556 MiB across 15,534 entries** with no bank-name references in inspected current runtime source/configuration and no vehicle-bank references in the dependencies of any of the 20,271 current binary `.scn`/`.res` assets. Examples include Electric coachwork v10–v23, previous Electric reference/seam/fender studies, Compact coachwork v1/v2 and Hovercraft sport v3. Full candidates and retained directories are in the evidence JSON.

Retain all 11 currently referenced banks: `compact_coachwork_v3`, `compact_kits_v1`, `electric_coachwork_v24`, `electric_hoods_v5`, `electric_rear_lamp_gaps_v1`, `hovercraft_body_v2`, `hovercraft_sport_v4`, `kart_refined_v1`, `modular_car_bases_v1`, `modular_kits_v1`, and `racing_simple_v1`. Hash-derived paths load meshes dynamically; switching blindly to scene dependency export could omit them. Keeping a whole active bank is deliberately conservative.

**16 superseded challenge poster images and their imported/remap entries contribute 26.4919 MiB across 32 entries.** Current `challenge_create.gd` chooses `one-to-one-v3`, `group-race-v3` and `three-by-three-v9`; `challenges_page.gd` dynamically chooses `entry-find-play-v3` and `entry-create-v3`. Preserve those five images. Candidate exclusions cover v1/v2 of the first four poster families and three-by-three v1–v8.

Use export exclusions, retaining source/history and tests in the repository. Before accepting the change, create a fresh content export; assert every expected dynamic resource and legal notice exists and every excluded path is absent. Exercise Garage stock/simple models, every supported kit category, photo fallback, races, and all five challenge poster states. No such optimized export or runtime acceptance is claimed here.

### 2. Separate ARM phones and x86 emulators: another 79.79 MiB

The preset enables both `architectures/arm64-v8a=true` and `architectures/x86_64=true`. Three x86_64 libraries contribute exactly 83,665,728 payload bytes. A separate ARM64 phone preset can omit those while retaining the existing emulator preset. This reduces architecture support in that artifact; it is not an asset-quality change.

For store distribution, Android App Bundles let Play generate device-specific APKs, so users download the native code their device needs. The universal upload's size is not the delivered phone size. [Android App Bundle documentation](https://developer.android.com/guide/app-bundle).

### 3. Use the pinned release template: modest additional engine saving

The installed official 4.7.2 template's ARM64 engine is 71,114,944 bytes versus 76,181,608 in debug: **4.83 MiB smaller** before any native ZIP compression. Both enabled ABIs together differ by 11.63 MiB. This is a comparison of matching local engine libraries, not a release APK measurement. Release plugins/dependencies and signing must be configured and checked separately; the current build entry point only performs a debug export. Existing Gradle `buildTypes.release` does not explicitly enable code/resource shrinking, so Java/Kotlin shrinker benefits remain unmeasured.

### 4. Further work after those savings

- Audit the old exploration loop: another 5.31 MiB family is packaged and current runtime GDScript no longer names it, while manifests/tests retain provenance. Confirm no indirect use before excluding only the unused stream, preserving required notices/manifests.
- Review fonts (15.68 MiB) for compact static/subset variants that preserve all twelve locales, country/player names, and fallback coverage. A translation-only subset would lose arbitrary player names. No numeric saving is claimed without a coverage test.
- Review current menu/preview texture dimensions and lossy import variants only with native before/after comparisons. Existing music-cover imports already cap at 256px; original multi-megabyte PNG sizes exaggerate their package cost. Do not remove current prepared meshes or preview photographs solely to reduce disk size: they underpin accepted loading/performance behavior.
- Custom size-optimized Godot templates can remove unused engine features, but bring build maintenance and full rendering/audio/network/text regression work. Preserve 3D and multilingual shaping. No saving measured. [Godot size optimization guidance](https://docs.godotengine.org/en/4.6/engine_details/development/compiling/optimizing_for_size.html).
- Native-library compression can make a standalone APK smaller, but Godot warns that extracting libraries may slow startup. Treat it as a download/startup/installed-storage tradeoff, not a free optimization. [Godot native compression option](https://docs.godotengine.org/en/stable/classes/class_editorexportplatformandroid.html#class-editorexportplatformandroid-property-gradle-build-compress-native-libraries).

Byte-identical vehicle-resource duplication is only **0.24 MiB** of redundant ZIP payload. Most historical banks represent separate serialized versions; a generic duplicate-file pass is not the main win. It also overlaps the obsolete-bank total and must not be added to it.

## Combined size arithmetic

| Scenario | Candidate payload removed | Baseline APK less that payload | Reduction |
| --- | ---: | ---: | ---: |
| Old banks + old challenge posters | 108.55 MiB | 381.92 MiB | 22.13% |
| Same cleanup + ARM64-only phone package | 188.34 MiB | 302.13 MiB | 38.40% |

These sets do not overlap. Figures subtract existing ZIP payload bytes only. Rebuilt headers, alignment, signatures and the sparse-pack index will differ. Today's workspace includes newer Forklift modules and the 2.24 MiB source hood bank absent from this older APK, so **302 MiB is an indicative baseline scenario, not a promised current-build size**. Release/template, optional audio, fonts and engine-size opportunities are not added to these totals.

## Evidence, commands and outcomes

- [Compact evidence report](evidence/package-size-review-2026-11-03/report.json): artifact hash, family sizes, candidate/retained lists, template measurements, runtime source hashes and limits.
- Full 5.3 MB entry inventory: `build/package-size-review-2026-11-03/report.json` (local build artifact).
- `scripts/analyze_package_size.py`: repeatable read-only ZIP payload/import/reference audit.
- `scripts/inspect_package_dependencies.gd`: header-only Godot dependency inspection in an isolated empty project; never instantiates the game or accesses owner saves.

Actual final commands, from the repository root:

```powershell
python scripts/run_no_crash_dialog.py -- 'C:/apps/Godot 4.7.2/Godot_v4.7.2-stable_win64_console.exe' --headless --log-file 'C:/Codes/Godot/Beat my track/build/package-size-review-2026-11-03/dependency-inspection.log' --path build/package-size-review-2026-11-03/inspector --script 'C:/Codes/Godot/Beat my track/scripts/inspect_package_dependencies.gd' -- 'C:/Codes/Godot/Beat my track/game' 'C:/Codes/Godot/Beat my track/build/package-size-review-2026-11-03/binary-inputs.json' 'C:/Codes/Godot/Beat my track/build/package-size-review-2026-11-03/binary-dependencies.json'
python scripts/analyze_package_size.py --dependencies build/package-size-review-2026-11-03/binary-dependencies.json --templates "$env:APPDATA/Godot/export_templates/4.7.2.stable" --output build/package-size-review-2026-11-03/report.json
```

The input JSON lists all current `game/assets/**/*.scn` and `*.res` paths relative to `game/`. The isolated project contains only `config_version=5`, a task name and Compatibility renderer. Initial inspection used an equivalent task-local script; the final invocation above uses the retained utility. Both inspected **20,271 resources**; 112 contain external dependencies. The first invocation had inaccessible default user-log and certificate-store errors; setting a task-local log path fixed the log error. The final invocation still reports the environment certificate-store error, completes inspection and exits 0; there are no resource/dependency errors and no network calls. This is not a clean engine-environment claim.

Initial Python audit failed because the installed interpreter lacks `hashlib.file_digest`; replaced it with streaming SHA-256. Final audit exits 0; category sums reconcile to all 24,272 entries, candidate/retained bank sets are disjoint, and `ZipFile.testzip()` validates CRCs for every APK entry. No gameplay tests were needed for this analysis because runtime/export settings/assets were unchanged. No device attachment query/test, APK/AAB export, owner save/process change, backend/live access, deployment, or main-index write was performed. Concurrent work is preserved. A task-only review patch and checks are recorded under `build/package-size-review-2026-11-03/`.
