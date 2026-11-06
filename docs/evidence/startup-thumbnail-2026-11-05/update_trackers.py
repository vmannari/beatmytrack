"""Prepend this task only, preserving every existing tracker byte."""
from pathlib import Path

OUT = Path(__file__).resolve().parent
ROOT = OUT.parents[2]
MARKER = '<!-- STARTUP-THUMBNAIL-20261105 -->'
for relative in ['AGENTS.md','DEVELOPMENT_STATUS.md','docs/PHASE_0_PLAN.md']:
    path = ROOT/relative
    before = path.read_bytes()
    if MARKER.encode() in before:
        continue
    snapshot = OUT/'before'/relative
    snapshot.parent.mkdir(parents=True,exist_ok=True)
    assert not snapshot.exists()
    snapshot.write_bytes(before)
    link = 'STARTUP_THUMBNAIL_2026_11_05.md' if relative.startswith('docs/') else 'docs/STARTUP_THUMBNAIL_2026_11_05.md'
    block = (MARKER+'\n## Missing custom car pictures no longer hold the first menu (2026-11-05)\n'
             'STH01-STH03/STHQ01: Account restoration opens the menu before optional header pictures; exact PNG reads continue, misses show an existing model silhouette. '
             'One scoped native capture requires the same visible ready Garage/car and an actually drawn cover; saves remove obsolete paint, gates cancel, deferred reads do not starve and eligibility retries sleep for250ms. '
             'Frozen desktop Compatibility custom-miss medians25.454to8.635s from two samples/version; no phone/cold-driver/first-race claim. '
             'Primary198/0 includes actual-App43/0 each desktop renderer, all-five native references26/0 each and19/0 lifecycle fences;17 accepted stable-source runs. '
             'Initial missing-directory fixture, source-changing image run, independent-render variance and MP3 shutdown warning retained; two original shell controls do not reproduce the latter in this task. '
             'No shader prototype enabled: the separate weathering study found no dependable loading gain. '
             '[Sources, commands, images, limits and checked task-only patch]('+link+'). '
             'Reload/owner/device acceptance remain; no device query/test, APK, owner-save/process change, backend/live request, deployment or main-index write; concurrent work preserved.\n'
             '<!-- /STARTUP-THUMBNAIL-20261105 -->\n\n')
    path.write_bytes(block.encode('utf-8')+before)
    after = OUT/'after'/relative
    after.parent.mkdir(parents=True,exist_ok=True)
    after.write_bytes(path.read_bytes())
