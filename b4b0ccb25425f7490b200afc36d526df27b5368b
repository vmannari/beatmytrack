# Automatic Super Wash picture — 2026-10-29

**SWA01:** Super Wash now depicts a powered wash gantry with two side brushes and an overhead roller cleaning a car. This communicates automatic whole-car cleaning while retaining the mitt/hose's realistic studio-photography style, ivory fibres, brushed metal and dark mechanical finishes. It replaces the handheld foam-sprayer picture in the tile.

One runtime source changes: `game/ui/garage_wash_tool.gd` selects `super-v2.png` for Super Wash. The existing layout, titles, manual washing, instant cleaning, local persistence and future ad status remain. Previous v1 artwork and its provenance remain intact. The new image/import/provenance are under `game/assets/menu/garage/`, with an added generated-art entry in `licenses/ASSETS.md`.

The built-in OpenAI image_gen tool generated the transparent picture. Exact prompt and provider path are in [super-v2.provenance.json](../game/assets/menu/garage/super-v2.provenance.json) and [prompt.txt](evidence/super-wash-automatic-2026-10-29/prompt.txt). Original 1254×1254 PNG bytes and alpha are preserved. The image uses the same lossless, maximum-512px, mipmapped, alpha-border-corrected import treatment as mitt and hose.

Actual results:

| Check | Result |
| --- | --- |
| Pinned-engine isolated image import | Exit 0; exact provider PNG retained |
| Three-image metadata/texture inspection | 16 checks, 0 failures; transparent source, mipmaps, 512×512 imported size and natural white modulation |
| Unchanged native Compatibility Super Wash regression | 300 checks, 0 failures; 14 captures covering six cars and three viewport sizes |
| Visual review | In-menu Compact capture inspected: the automatic wash arch, rollers and blue car remain readable in the small tile |

Commands from the repository root:

```powershell
python docs/evidence/super-wash-automatic-2026-10-29/prepare_import.py
python docs/evidence/super-wash-automatic-2026-10-29/run_validation.py --inspect
python docs/evidence/super-wash-automatic-2026-10-29/run_validation.py --mode gl_compatibility
python docs/evidence/super-wash-automatic-2026-10-29/build_review.py
git diff --check -- game/ui/garage_wash_tool.gd licenses/ASSETS.md
```

Logs retain the sandbox certificate-store error and evidence-only warnings for directly inspecting source PNGs. Runtime code uses the normal imported textures. No script error or failing assertion occurred in the final runs. The binary-inclusive task patch, forward/reverse/content checks, source hashes and captures are in `docs/evidence/super-wash-automatic-2026-10-29/`.

Reload/rebuild and owner/device appearance acceptance remain. No device attachment query/test, APK, auth/purchase, owner-save/live/backend mutation, deployment, owner-process restart or main-index staging/commit/merge was performed. Concurrent sources and generated build identities are preserved.
