from pathlib import Path
import difflib

ROOT = next(p for p in Path(__file__).resolve().parents if (p / 'godot-version.txt').exists())
OUT = Path(__file__).resolve().parent
note = '''<!-- CAROUSEL-LABEL-OVERLAY-20261028 -->
## Car labels show the miniature garage underneath (2026-10-28)
CL05: Owner clarifies the translucent label must reveal its own garage picture. The image fills the card; a 36px caption overlays its bottom, with 58/72/82% normal/hover/pressed opacity and a 2px inset preserving selection borders. Centered unnumbered names and native input remain. One runtime layout file; unchanged existing capture helper saves 12 native Compatibility views across six cars, four sizes, workshop return, hover and focus with clean exit. Source patch passes forward/reverse/whitespace checks. Commands, hashes, pictures and scoped checkpoint: docs/CAROUSEL_LABEL_OVERLAY_2026_10_28.md and docs/evidence/carousel-label-overlay-2026-10-28/report.json. Earlier Garage preparation and concurrent changes preserved; generated metadata archived/excluded. Reload/rebuild and owner/device appearance acceptance remain. No device query/test, APK, real auth/purchase, owner-save/live mutation, deployment, owner-process restart or main-index staging/commit/merge.
<!-- /CAROUSEL-LABEL-OVERLAY-20261028 -->

'''
patch = ''
for rel in ['AGENTS.md', 'DEVELOPMENT_STATUS.md', 'docs/PHASE_0_PLAN.md']:
    target = ROOT / rel
    before = target.read_bytes()
    assert b'<!-- CAROUSEL-LABEL-OVERLAY-20261028 -->' not in before
    for name, content in [('doc-before', before), ('doc-after', note.encode('utf-8') + before)]:
        archive = OUT / name / rel
        archive.parent.mkdir(parents=True, exist_ok=True)
        archive.write_bytes(content)
    after = note.encode('utf-8') + before
    target.write_bytes(after)
    patch += ''.join(difflib.unified_diff(before.decode('utf-8-sig').splitlines(keepends=True),
                                        after.decode('utf-8-sig').splitlines(keepends=True),
                                        fromfile='a/' + rel, tofile='b/' + rel))
(OUT / 'status.patch').write_text(patch, encoding='utf-8', newline='\n')
print('Updated AGENTS.md, DEVELOPMENT_STATUS.md and docs/PHASE_0_PLAN.md.')
