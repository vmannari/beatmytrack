from pathlib import Path
p=Path(__file__).resolve().parent;root=p.parents[2]
block='''<!-- BIOME-SHADER-PROFILES-20261106 -->
## Biome-specific native shader profiles and missing-preparation telemetry (2026-11-06)
BSP01-BSP04/Q01: Pinned source-integrated Compatibility module prepares exact known variants; unknown sources and absent variants retain original compilation. Nine driver/engine/car/biome/settings contexts contain 604 entries/119238 bytes. Bounded first-draw telemetry distinguishes unlisted and late known variants, preserves opt-in/account/capability fences and exposes an indexed admin receipt report. Fresh-private-profile desktop Compact/Pine verified-oval pair35.872to8.633s; native185to61 compilations/30.805to3.877s. One pair, no cold-driver/phone claim. Actual-App133/0 and143/0 each include five zero-contact opening laps; omission/late controls17/0, final13/14, contracts39/0 and backend22pass. Five biome views and final Pine/omission controls pixel-exact. Initial build/path/API/identity/JSON/migration/helper findings and warm-cache timing exclusion retained. [Implementation, engine build, sources, captures, limits and task-only checkpoint](docs/BIOME_SHADER_PROFILES_2026_11_06.md). Stock engine/tablet remain unchanged; matching custom-engine clients, Android profiles and authorized backend migration/rollout remain. No device query/test, APK/game package, owner-save/process change, live/backend request, deployment or main-index write; concurrent work preserved.
<!-- /BIOME-SHADER-PROFILES-20261106 -->

'''
for name in ['AGENTS.md','DEVELOPMENT_STATUS.md']:
    path=root/name
    content=path.read_bytes()
    assert b'<!-- BIOME-SHADER-PROFILES-20261106 -->' not in content
    newline=b'\r\n' if b'\r\n' in content[:1000] else b'\n'
    path.write_bytes(block.encode().replace(b'\n',newline)+content)
print('Prepended scoped records; existing bytes preserved.')
