# One sticker collection and refined artwork

2026-10-28. Requirements SC01â€“SC03 / R01 / Q01.

SC01 removes the twelve sponsor stickers and the Emblems/Sponsors category row.
The existing twelve emblems form one gallery per physical panel. Hood/Roof and
Forklift Rear choices, scrolling, placement tools, independent selections and
removal remain. Two cached panel galleries replace four category/panel galleries.

SC02 redraws all twelve original vector emblems. The crest now has complete BMT
letterforms; the roundel has an open zero; compass, mountain, bird, skull, planet,
laurel, piston and sun use cleaner silhouettes, spacing and consistent keylines.
Every check follows the waving flag's outline. Individual previews increase from
128Ã—128 to 256Ã—256. The existing 256-pixel atlas cells, gutters and anisotropic
mipmap filtering remain; removing the sponsor rows halves atlas area from
1024Ã—1536 to 1024Ã—768. No extra geometry, material passes, dependencies, downloaded
art, fonts or brands are introduced. `scripts/build_livery_art.py` is the editable
original source. All 96 existing pattern/preview SVGs remain byte-exact, and an
independent output directory reproduces all 111 generated files.

SC03 fixes a live-preview issue discovered during native review. The showroom's
initial livery can share the mutable Garage draft, while the actual car owns a
separate normalized copy. The unchanged-value shortcut now checks that copy too.
Before this correction, all twelve actual-car captures were identical and the
car still had no stickers; the strengthened review failed eleven image-change
checks. The final review checks the actual car's selected design and distinct
rendered pictures. Newly placed marks face the front of ordinary cars and the
rear of Forklift. Replacing a design retains its custom rotation.

R01 preserves version-2 local/server appearance compatibility. The twelve
retired IDs remain accepted as input so old saves and acknowledged sync baselines
are readable. Normalization clears only a retired sticker's ID, preserving its
placement, paint, pattern and other panel. Retired art is removed from the export
tree and new choices/generation use only the active collection. The existing
appearance wire schema and backend remain unchanged. No owner files are migrated
or edited by this task.

The runtime scripts changed are `garage_livery_menu.gd`, `garage_page.gd`,
`car_showroom.gd` and `vehicle_livery.gd`. The generator, twelve individual SVGs,
atlas and sticker catalogue change; twelve sponsor SVG/import pairs are removed.
The owned production-App review is `game/tests/test_sticker_collection.gd`.
Existing livery, scrolling, Forklift, Rivalry and Garage-cache tests receive the
requested catalogue changes; the Garage-cache fixture names Kart instead of
assuming its historical array index. A separate current-car appearance-sync
fixture preserves the original assertions while replacing retired Formula/classic
test identities with Hover/Electric; the original appearance fixture is untouched.

Q01: final focused tests pass **90/0 headless** and **126/0 each Compatibility and
desktop Mobile**. Twelve final captures per renderer include three viewport
sizes, placement, all six cars, the artwork sheet and twelve real roof renders.
The review dispatches actual touch placement through the App. Broader results and
all initial findings are recorded in `evidence/sticker-simplification-2026-10-28/report.json`.

Actual commands use the pinned Godot 4.7.2 engine through `scripts/dev.ps1`:

```powershell
python scripts/build_livery_art.py
powershell -NoProfile -ExecutionPolicy Bypass -File docs/evidence/sticker-simplification-2026-10-28/run.ps1 -Action Import
powershell -NoProfile -ExecutionPolicy Bypass -File docs/evidence/sticker-simplification-2026-10-28/run.ps1 -Phase after
powershell -NoProfile -ExecutionPolicy Bypass -File docs/evidence/sticker-simplification-2026-10-28/run.ps1 -Phase after -Renderer mobile
powershell -NoProfile -ExecutionPolicy Bypass -File docs/evidence/sticker-simplification-2026-10-28/run-checks.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File docs/evidence/sticker-simplification-2026-10-28/run.ps1 -Phase input -ScriptPath res://tests/test_garage_swipe_scroll.gd -TestArgument --evidence-root=res://../docs/evidence/sticker-simplification-2026-10-28/input
```

The runner isolates APPDATA/LOCALAPPDATA under the workspace, disables the API,
and conditionally restores only its generated build metadata. Source hashes,
task-start files, logs, native captures and a scoped review patch are supplied.
The patch is checked forward and backward in a separate directory, without main
index writes. Concurrent editor, car-model/handling, catalogue photos and backend
work remain outside this change.

The final current-car appearance-sync control passes **54/0**, Rivalry custom-car
checks **141/0**, Garage reuse **1446/0** and local records **54/0**. The sequential
runner exits 0. Its logs name each test separately.

The broader livery suite has **821 checks / 32 failures**: sixteen Electric and
sixteen Hover pattern previews lack mipmaps in their existing import metadata.
Those PNGs/import settings are unchanged. The broader swipe suite has **93 checks /
3 failures** in kit touch selection, emulated-mouse selection and exact camera
retention; sticker scrolling, selection and placement assertions pass. These
broader findings are retained rather than changing their assertions to green.

Initial restricted certificate-store access, helper RGB/RGBA blit and float
round-trip comparisons, stale imported sticker textures, a helper indentation
error, shell execution-policy rejection, retired-car fixtures and one host WASAPI
buffer error are recorded. The final Mobile retry passes. No Android appearance,
performance or certification claim is made.

[Artwork preview](evidence/sticker-simplification-2026-10-28/after/mobile/artwork.png)
and [actual-car sheet](evidence/sticker-simplification-2026-10-28/after/mobile/all-stickers-on-car.png).

Reload/rebuild and owner/device appearance and input acceptance remain. No device
attachment query or physical-device test, APK export/install, live/backend write,
deployment, authentication/purchase, owner-save change, owner-process restart or
main-index staging/commit/merge was performed.
