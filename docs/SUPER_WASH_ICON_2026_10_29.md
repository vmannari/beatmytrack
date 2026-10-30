# Super Wash tool photography — 2026-10-29

**SWI01:** The Super Wash tile now uses a realistic foam-sprayer cutout that matches the mitt and hose's product-photography style: soft studio lighting, brushed metal, black rubber and restrained brass/ivory materials. The flat yellow droplet and its gold tint are removed. The three tiles retain their shared placement, dimensions, sampling and hover treatment.

One runtime source changes: `game/ui/garage_wash_tool.gd` loads `super-v1.png` through the same image path as mitt/hose. The new PNG, import settings and generation provenance are under `game/assets/menu/garage/`; `licenses/ASSETS.md` records the generated artwork. No cleaning logic, layout, translation, manual-tool selection, ad flow or other source is changed.

The built-in OpenAI image_gen tool generated the transparent cutout. Exact prompt/provider path: [super-v1.provenance.json](../game/assets/menu/garage/super-v1.provenance.json) and [prompt.txt](evidence/super-wash-icon-2026-10-29/prompt.txt). Provider PNG bytes and alpha are preserved. All three source images are 1254×1254; all three import as lossless 512×512 textures with mipmaps and alpha-border correction. All three render with natural white modulation.

Actual validation:

| Check | Result |
| --- | --- |
| Pinned-engine isolated PNG import | Exit 0; only the new picture imported |
| Three-image native inspection | 16 checks, 0 failures; transparency/mipmaps/bounds/tint recorded in `images.json` |
| Unchanged Super Wash native Compatibility regression | 300 checks, 0 failures; 14 captures across six cars and three viewport sizes |
| Visual inspection | Compact 1280×720 and narrow 960×540 captures show all three photographic tools aligned beneath the status panel |

Commands from the repository root:

```powershell
python docs/evidence/super-wash-icon-2026-10-29/prepare_import.py
python docs/evidence/super-wash-icon-2026-10-29/run_validation.py --mode gl_compatibility
python docs/evidence/super-wash-icon-2026-10-29/run_validation.py --inspect
git diff --check -- game/ui/garage_wash_tool.gd licenses/ASSETS.md
```

Runtime logs retain the sandbox certificate-store error. The evidence-only image reader warns about reading source PNGs directly; runtime code loads imported textures normally. An initial inspection incorrectly required the existing hose's corner alpha to be exactly zero; it is 1/255. The corrected inspection reports existing corner values and separately verifies the new Super Wash corner is transparent (actual 0). The failed inspection log is retained. A preliminary Python metadata probe found Pillow unavailable; verification uses Godot without installing dependencies. Its owned inspection was cancelled after that assertion; a process-metadata query was denied, and no owner process was changed.

The binary-inclusive scoped review patch and SHA-256 report are in `docs/evidence/super-wash-icon-2026-10-29/`. No main-index staging or commit is involved. Reload/rebuild and owner/device visual acceptance remain. No device attachment query/test, APK, real auth/purchase, live/backend/owner-save mutation, deployment or owner-process restart was performed. Concurrent work is preserved.
