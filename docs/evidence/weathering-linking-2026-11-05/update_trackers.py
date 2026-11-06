"""Record the rejected experiment without rewriting concurrent tracker sections."""
import json
from pathlib import Path
p=Path(__file__).resolve().parent; root=p.parents[2]
r=json.loads((p/'delivery-checks.json').read_text())
block=f'''<!-- WEATHERING-LINKING-20261105 -->
## Fixed-role weathering linking tested; current shared shaders retained (2026-11-05)
WLS01-WLS03: Evidence-only prototype. Broad wheel/trim/role splits increase whole-car first-use cost as sources rise2to3/5. Compact toon rear-trim replacement retains two sources; four fresh-source samples/version give toon medians3.205to2.831s and whole-car5.879to5.677s, but plain ABBA regresses4.9%. Four actual-App ABBA runs retain187programs/36checks; toon means2.531to2.477s overlap and unrelated links vary31.741-36.120s. No dependable race-loading gain established; no runtime or prepared-asset change. Final36views/restored controls exact, three positive visibility controls and one zero-contact Pine opening lap pass; final targeted assertions{r['final_targeted_assertions']}/0, earlier109/0 retained. Countdown hitches/132ms driving maximum and initial argument/timeout/owned-cleanup failure retained; no smooth-frame claim. [Prototype, commands, measurements, limits and checked task-only checkpoint](docs/WEATHERING_LINKING_2026_11_05.md). No device query/test, APK, owner-save/process change, backend/live request, deployment or main-index write; concurrent work preserved.
<!-- /WEATHERING-LINKING-20261105 -->

'''.encode()
for name in ('AGENTS.md','DEVELOPMENT_STATUS.md'):
    file=root/name; old=file.read_bytes()
    assert b'<!-- WEATHERING-LINKING-20261105 -->' not in old
    file.write_bytes(block+old)
