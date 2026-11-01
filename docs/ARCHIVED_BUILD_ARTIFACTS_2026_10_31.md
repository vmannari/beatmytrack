# Archived build artifacts — 31 October 2026

The following older, ignored build and test collections were archived to
`\\DS925\homes\vmannari\Beat my track\codex-cleanup-2026-10-31`:

- `desert-hitch-2026-10-13.zip`
- `desert-phone-performance-2026-10-25.zip`
- `device-performance-race-fixes-2026-10-27.zip`
- `mobile-audit-2026-10-26.zip`
- `phone-current-deployment-2026-10-25.zip`
- `tablet-current-deployment-2026-10-25.zip`
- `tablet-latest-deployment-2026-10-25.zip`

Each ZIP contains the original paths under `build/` and an
`_archive_manifest.json` with the source paths, sizes, modification times and
SHA-256 hashes. File contents and the NAS copies were verified before local
files were removed. A few protected files in nested Git checkpoints remain
locally in the desert-hitch and device-performance folders; complete copies
are in their archives.

To recover an artifact, open the appropriate ZIP and extract the needed
`build/...` files into the project root. Check for newer local files first so
that extraction does not overwrite subsequent work. ZIP extraction does not
necessarily restore the original filesystem metadata; the recorded times are
in the manifest.

The separate `build/re-audit-2026-10-27` collection was left in place after
an access-denied error while inspecting its test directory.

## Additional cleanup later on 31 October

The same NAS folder contains the following additional verified ZIP archives.
Each matching `.receipt.json` records its source, SHA-256, removed byte count,
and any protected or changed files retained locally. Extract the needed
`build/...` paths into the project root after checking for newer files.

- `achievement-wall-before-project.zip`
- `analog-phone-deploy-2026-10-16.zip`
- `biome-phone-test-2026-10-13.zip`
- `catalog-road-review-2026-10-16.zip`
- `cloud-histograms-200-2026-10-06-recordings.zip`
- `cold-render-investigation-2026-10-27.zip`
- `compact-kits-quality.zip`
- `exclusive-menu-deploy.zip`
- `free-race-phone-2026-10-14.zip`
- `garage-test-drive-fix.zip`
- `kart-construction-fixes.zip`
- `media-compression.zip`
- `mobile-audit-fixes-2026-10-26.zip`
- `performance-2026-09-21.zip`
- `phone-deploy-tracks-2026-10-14.zip`
- `phone-drive-deploy-2026-10-14.zip`
- `phone-touch-slide-deployment-2026-10-23.zip`
- `rivalry-generation-fix-2026-10-22.zip`
- `runtime-correctness-2026-10-26.zip`
- `short-menu-phone-export.zip`
- `tablet-dust-2026-10-09.zip`
- `tablet-lap-stutter-deployment-2026-10-23.zip`
- `tablet-performance-2026-10-08.zip`
- `tablet-shadow-dust-2026-10-09.zip`
- `tablet-vulkan-2026-10-09.zip`
- `test-drive-speedometer.zip`
- `touch-target-phone-deploy-2026-10-16.zip`
- `tutorial-validation.zip`
- `winter-render-audit-2026-10-14.zip`
- `world-ranking-frozen-1c410cf1d71a12ed.zip`
- `world-ranking-frozen-3299ce1278f9e08c.zip`
- `world-ranking-frozen-3f49ee45b88b9aa0.zip`
- `world-ranking-frozen-471ae3ef41da7087.zip`
- `world-ranking-frozen-ae6b3bfdce133018.zip`
- `world-ranking-frozen-b45988af10ad67b0.zip`
- `world-ranking-frozen-b66d532b3988cec0.zip`
- `world-ranking-frozen-cb156c79045d35a2.zip`
- `world-ranking-frozen-cc1ef56cac65b9a4.zip`
- `world-ranking-frozen-df8b6aa296978451.zip`
- `world-ranking-frozen-eb5afd7175c3af52.zip`

One duplicate `build/exclusive-menu-installed.apk` was removed after its
SHA-256 matched the retained `build/exclusive-menu-phone.apk`.

## Additional October test snapshots

The following verified archives are in the same NAS folder, with matching
`.receipt.json` files recording source paths, archive hashes and file counts:

- `garage-first-entry-user.zip` — 27 October isolated garage test profiles.
- `tablet-garage-liveries-2026-10-28.zip` — 28 October tablet test snapshot.

Both archives retain their original `build/...` paths and per-file SHA-256
manifests. No local files failed removal after verification.
