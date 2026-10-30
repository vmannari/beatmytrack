"""Record completed checks and delivery scope after local verification."""
import hashlib
import json
from pathlib import Path
import re

OUT = Path(__file__).resolve().parent
ROOT = OUT.parents[2]
read = lambda name: json.loads((OUT/name).read_text(encoding='utf-8'))
source_hash = hashlib.sha256((ROOT/'game/vehicle/electric_coachwork.gd').read_bytes()).hexdigest()
latest = {entry['job']: entry for entry in read('commands.json')}
required = ['flow','shape','construction','arrays','bonnet','shadows','garage','pictures','liveries','news','after-compatibility','review-mobile','model','app','racing','parse-own','import']
assert all(latest[name]['exit_code'] == 0 and latest[name]['source_sha256'] == source_hash for name in required)
summary = {}
for name in required:
    log = (OUT/(name+'.log')).read_text(encoding='utf-8', errors='replace')
    summary[name] = [line for line in log.splitlines() if re.match(r'^(ELECTRIC_|RACING_MODEL_|SCRIPT_PARSE:|LIVERY_PREVIEWS:|NEWS PHOTO FRAMING:|GARAGE_CAR_BAKE|VOLT_WINDOW_AUDIT:)', line)]
audit = read('array-audit.json')
native = {name: read(name+'/capture-report.json') for name in ['after-compatibility','review-mobile']}
checkpoint = read('checkpoint.json')
report = dict(date='2026-10-28', request='Move the Volt rear window farther backwards',
              requirements=dict(VRW01='Move actual glass and its frame backwards', VRW02='Fit the roof, rear pillars and shorter apron', R01='Retain body, wheels, materials, handling and existing budgets', Q01='Native views, existing regression checks, current derived assets and scoped checkpoint'),
              runtime_source='game/vehicle/electric_coachwork.gd', source_sha256=source_hash,
              windows=audit['windows'], exact_prepared_surface_arrays=audit['exact_surface_arrays'],
              changed_arrays=audit['changed_arrays'], unexpected_array_changes=audit['unexpected_changes'],
              native_geometry=native['after-compatibility']['geometry'], test_summaries=summary,
              native_captures={name:len(value['captures']) for name,value in native.items()},
              scoped_checkpoint={k:v for k,v in checkpoint.items() if k not in ('commands','hashes')},
              initial_findings=['PowerShell entry point initially required process-scoped execution-policy bypass.', 'Sandbox profile/log access and Windows certificate-store failures; final commands use an isolated test profile and locally approved engine execution.', 'Initial rear-pillar sampling failed retained continuity assertions; refined full/simple sampling passes without editing the fixture.', 'An obsolete clean-bonnet fixture expects removed HoodSurround1; it is unchanged and its failure is retained. The current convex-bonnet regression passes 40 checks.', 'The broader racing suite reports two unrelated forklift shadow/frame failures; broad-racing.log retains the result. The focused Volt run uses the existing vehicle filter.'],
              limitations=['Full project parser fails in the concurrent parking_hall_before fixture: _build_wash_requirement is missing. The preferred check of the owned runtime source passes; the unrelated fixture is unchanged.', 'Reload/rebuild required', 'Owner appearance acceptance remains', 'No physical-device query/test or APK', 'No owner-save/live/backend mutation, deployment or owner-process restart', 'No main-index staging/commit/merge', 'Desktop observations do not establish phone performance'])
(OUT/'report.json').write_text(json.dumps(report, indent=2)+'\n', encoding='utf-8')
document = '''# Volt rear window moved backwards — 2026-10-28

The rear glass and its frame move back 0.18 model metres, measured as **15.84 cm at the actual car scale** on both prepared detail levels. The rear roof and pillars follow the glass. Its lower edge drops 3.52 cm to fit a shorter painted transition to the existing trunk.

[Compare native before and after views](evidence/volt-rear-window-back-2026-10-28/before-after.html).

VRW01 covers glass relocation; VRW02 covers the fitted roof/pillars/apron; R01 preserves the remaining body, wheels, finishes, handling and budgets; Q01 requires native evidence, existing checks and a task-only checkpoint. Only `game/vehicle/electric_coachwork.gd` changes runtime source. An owned buffer-audit helper measures the actual immutable resources. Existing test fixtures remain unchanged.

The retained rear-shape, continuity, construction and convex-bonnet suites pass 24, 58, 33 and 40 checks. Native model/lighting checks pass 34; the actual-App Garage/race fixture passes 58 and Volt racing-model checks pass 23. The preferred check of the owned runtime source passes. Full project parsing fails in the concurrent `tests/fixtures/parking_hall_before/garage_page.gd`: `_build_wash_requirement` is missing; that fixture is unchanged by this task. Exact command receipts retain the failure. Both desktop renderers save 26 native review captures successfully. Full/simple visible geometry is 119046/38176 triangles, within 120000/45000. Denser rear-pillar sampling fixes the initial continuity failures; the full model has 954 triangles of remaining budget.

Of 409 prepared surfaces, 363 remain exact and 46 change only around the cabin/glass/apron. The front body, windscreen, trunk, fascia and wheels retain their prepared arrays. Historical v16 files and the Volt configuration are hash-exact. Concurrent kart and hovercraft configuration changes are preserved and excluded from the task patch. Current v17 meshes, five racing-shadow frames, the Volt Garage template, 49 livery photos and Garage/header/news photos are regenerated. Images are imported with the pinned engine.

Initial sandbox certificate/profile failures, the rejected sampling attempts and an obsolete clean-bonnet test expecting the removed `HoodSurround1` are retained in the evidence. That original fixture is unchanged; the current convex-bonnet fixture passes. The broader racing fixture reports two unrelated forklift frame/shadow failures, retained in `broad-racing.log`; the focused Volt run uses its existing vehicle filter. Native views were inspected for the rear quarter, side and actual Garage angles. These checks do not certify appearance or phone performance.

Actual commands and outcomes: [commands.json](evidence/volt-rear-window-back-2026-10-28/commands.json), [report.json](evidence/volt-rear-window-back-2026-10-28/report.json). Rebuild command: `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/bake_electric_model.gd`. Subsequent commands use the recorded `run_checks.py` entry-point wrapper and isolated local test profile. The binary-inclusive [task patch](evidence/volt-rear-window-back-2026-10-28/task.patch) applies and reverses exactly in an isolated Git repository, without modifying the shared index; see [checkpoint.json](evidence/volt-rear-window-back-2026-10-28/checkpoint.json).

Reload/rebuild to see the updated model. Owner appearance and device acceptance remain. No physical-device attachment query/test, APK, owner-save/live/backend mutation, deployment, owner-process restart or main-index staging/commit/merge was performed. Concurrent work and current generated build metadata are preserved outside the scoped patch.
'''
(ROOT/'docs/VOLT_REAR_WINDOW_BACK_2026_10_28.md').write_text(document, encoding='utf-8')
block = '''<!-- VOLT-REAR-WINDOW-BACK-20261028 -->
## Volt rear window moved backwards (2026-10-28)
VRW01-VRW02/R01/Q01: Actual glass/frame moves15.84cm back at car scale; fitted rear roof/pillars and shorter apron retain existing trunk. Shape24/continuity58/construction33/bonnet40/native model34/actual App58/racing23 and owned-source parse pass. Broad parser hits concurrent parking_hall_before fixture; broader racing retains two forklift failures.363/409 prepared arrays exact;46 cabin/apron changes, no unexpected buffers. Full119046/simple38176 stay within120000/45000. V17, five shadows, Volt template and52 native pictures refresh/import.26 final views each desktop renderer; initial sampling/sandbox/obsolete-bonnet-fixture findings retained. Historical v16/Volt configuration exact; scoped binary patch round-trips. One runtime source/owned audit helper; existing fixtures and concurrent kart/hovercraft configurations and other work preserved. Commands/hashes/views/limits: docs/VOLT_REAR_WINDOW_BACK_2026_10_28.md and docs/evidence/volt-rear-window-back-2026-10-28/report.json. Reload and owner/device acceptance remain. No device query/test, APK, owner-save/live/backend mutation, deployment, owner-process restart or main-index staging/commit/merge.
<!-- /VOLT-REAR-WINDOW-BACK-20261028 -->

'''
for relative in ['AGENTS.md','DEVELOPMENT_STATUS.md','docs/PHASE_0_PLAN.md']:
    path = ROOT/relative
    original = path.read_bytes()
    if b'<!-- VOLT-REAR-WINDOW-BACK-20261028 -->' not in original:
        backup = OUT/'task-base'/relative
        backup.parent.mkdir(parents=True, exist_ok=True)
        backup.write_bytes(original)
        path.write_bytes(block.encode('utf-8')+original)
print(json.dumps(dict(runtime_source_sha256=source_hash, required_jobs=len(required), report='report.json', checkpoint=checkpoint['patch_sha256'])))
