from pathlib import Path
import difflib
import hashlib
import json

ROOT = next(p for p in Path(__file__).resolve().parents if (p / 'godot-version.txt').exists())
OUT = Path(__file__).resolve().parent
marker = 'GARAGE-READY-PICTURES-20261028'
note = '''<!-- GARAGE-READY-PICTURES-20261028 -->
## Garage carousel receives ready pictures (2026-10-28)
GRP01-GRP05/R01/Q01: Owner still sees pictures loading. Exact owner/appearance images prepare ahead of entry and share a bounded texture pool; menu/swipe/Cars entry cannot expose incomplete pictures. Startup reads saved PNGs or captures missing appearances under its existing screen, with a 45s bound; explicit navigation retains the current menu and remains cancellable until ready. Appearance commits, cancellation, owner fencing and pressure recovery retain exact identities; suspended freed Garage shells are invalidated. Final Compatibility68/157 and desktopMobile68/155 menu/swipe/recovery assertions pass. Stable-revision Compatibility restart has zero captures/exact pixels and278.070ms startup. Six images24MiB count once. Cold Mobile40.982/37.759s startup remains; an earlier cold run exceeds45s and fails readiness, retained alongside the transient missing Hovercraft model and fixture findings. No instant-startup/main-Garage/device claim. Retained App141/1 editor cancellation failure and earlier preferred parse pass remain. Five runtime files/one regression with UID; forward/reverse-checked source-only checkpoint excludes concurrent editor/Rivalry/workshop/model/handling/assets and generated identity churn. Commands, hashes, images and limits: docs/GARAGE_READY_PICTURES_2026_10_28.md and docs/evidence/garage-ready-pictures-2026-10-28/report.json. Reload/rebuild and owner/device acceptance remain. No device query/test, APK, real auth/purchase, owner-save/live mutation, deployment, owner-process restart or main-index staging/commit/merge.
<!-- /GARAGE-READY-PICTURES-20261028 -->

'''
patch = ''
hashes = {}
for rel in ['AGENTS.md', 'DEVELOPMENT_STATUS.md', 'docs/PHASE_0_PLAN.md']:
    path = ROOT / rel
    original = path.read_bytes()
    if marker.encode() in original:
        start = original.index(('<!-- ' + marker + ' -->').encode())
        end = original.index(('<!-- /' + marker + ' -->').encode(), start) + len(('<!-- /' + marker + ' -->').encode())
        if original[end:end+2] == b'\n\n': end += 2
        original = original[:start] + original[end:]
    base = OUT / 'doc-base' / rel
    base.parent.mkdir(parents=True, exist_ok=True)
    base.write_bytes(original)
    updated = note.encode('utf-8') + original
    path.write_bytes(updated)
    after = OUT / 'doc-after' / rel
    after.parent.mkdir(parents=True, exist_ok=True)
    after.write_bytes(updated)
    patch += ''.join(difflib.unified_diff(original.decode('utf-8-sig').splitlines(keepends=True),
                                        updated.decode('utf-8-sig').splitlines(keepends=True),
                                        fromfile='a/' + rel, tofile='b/' + rel))
    hashes[rel] = hashlib.sha256(updated).hexdigest()
(OUT / 'documentation.patch').write_text(patch, encoding='utf-8', newline='\n')
(OUT / 'documentation-hashes.json').write_text(json.dumps(hashes, indent=2))
print(json.dumps(hashes))
