"""Publish completed evidence and scoped local handoff notes."""
import hashlib
import json
from pathlib import Path
import re

OUT=Path(__file__).resolve().parent
ROOT=OUT.parents[2]
read=lambda name: json.loads((OUT/name).read_text(encoding='utf-8'))
source=hashlib.sha256((ROOT/'game/vehicle/electric_coachwork.gd').read_bytes()).hexdigest()
latest={entry['job']:entry for entry in read('commands.json')}
required=['bake','cabin','construction','shape','flow','bonnet','shadows','garage','pictures','liveries','news','import','before','windscreen-before','preview','preview-mobile','model','app','racing','parse-own']
assert all(latest[name]['exit_code']==0 and latest[name]['source_sha256']==source for name in required)
summaries={}
for name in required:
    log=(OUT/(name+'.log')).read_text(encoding='utf-8',errors='replace')
    summaries[name]=[line for line in log.splitlines() if re.match(r'^(VOLT_|ELECTRIC_|RACING_MODEL_|LIVERY_PREVIEWS:|NEWS PHOTO FRAMING:|GARAGE_CAR_BAKE)',line)]
checkpoint=read('checkpoint.json')
report=dict(date='2026-10-28',requirements=dict(VSC01='Straight rear shoulder and side-window waist',VSC02='Paint the X-marked upper region and extend rear glass to the arrow',VSC03='Complete door outlines enclosing windows with matching pillars',VSC04='Remove the fixed rear quarter windows',VSC05='Smooth front pillar and mirror junction',VSC06='Advance the whole windshield 20 cm and adapt bonnet, cabin, mirrors and doors',VA01='Lower nose, flatter roof, longer windscreen rake and tapered bumpers',R01='Preserve canonical configuration, wheels, materials and existing budgets',Q01='Native comparison, actual-mesh checks, current derived assets and scoped checkpoint'),
            runtime_source='game/vehicle/electric_coachwork.gd',source_sha256=source,
            cabin=read('cabin/cabin.json'),construction=read('construction/construction.json'),
            test_summaries=summaries,command_receipts='commands.json',
            captures={name:read(name+'/captures.json') for name in ['before','windscreen-before','preview','preview-mobile']},
            checkpoint={k:v for k,v in checkpoint.items() if k!='hashes'},
            initial_findings=['Concurrent hovercraft source was briefly absent; repeated native command passes after it returns.', 'New audit initially used unsanitized Godot node names; corrected helper retains the original assertions.', 'An intermediate wrapper fails on a concurrent project.godot metadata lock; original log and receipt retained.', 'Owner subsequently requests aerodynamic styling, quarter-window removal, front-pillar refinement and a 20 cm windshield advance; intermediate v18/v19 sources and measurements are archived.', 'Original fixed-coordinate bonnet fixture samples beyond the requested shortened hood and reports 32 failures; unchanged fixture/log retained. The owned bounds-aware copy keeps all five original slope/convexity limits and passes 40 checks.'],
            limitations=['Cosmetic shape change; no measured drag coefficient or handling/performance change is claimed','Reload/rebuild and owner appearance acceptance remain','No physical-device query/test, APK, owner-save/live/backend mutation, deployment or owner-process restart','Full project parser was not repeated; preferred owned-source check and native integration are used','No shared-index staging/commit/merge; concurrent configuration and source changes are preserved'])
(OUT/'report.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
document='''# Volt body, glazing and door correction — 2026-10-28

The owner marks a wavy rear shoulder, unwanted upper rear glazing, the desired lower glass edge and door outlines that omit the windows, then requests a more aerodynamic appearance, no fixed rear quarter windows, a smoother front pillar and a 20 cm windshield advance. V20 gives the car a lower tapered nose, flatter roof and tucked bumpers. Both windshield edges move 20 cm forwards, with a shorter bonnet, an extended front cabin, matching door frames and relocated mirrors. The front pillar uses a smooth transverse join. The rear waist remains straight, the upper X-marked rear area is painted, and the rear glass reaches the marked deck position. Four complete visual door perimeters include their windows, with handles near their trailing edges. The fixed quarter-glass triangles are replaced by painted bodywork on both sides.

[Compare matched native Garage views](evidence/volt-straight-shoulder-2026-10-28/before-after.html).

Requirements: VSC01 straight shoulder/window waist; VSC02 corrected rear aperture; VSC03 complete door/window outlines; VSC04 no quarter glass; VSC05 smooth front pillar; VSC06 whole-windshield advance and surrounding adaptation; VA01 sleeker silhouette; R01 retained physical configuration, wheels, finishes and budgets; Q01 actual geometry checks, native evidence, current derived assets and isolated checkpoint. Runtime scope is one source, `game/vehicle/electric_coachwork.gd`. Three owned test/review helpers support it. Existing fixtures are unchanged.

The actual-buffer regression passes 46 checks across full/simple cars: straight waist boundaries, joined door/pillar/roof seams, rear-glass placement, quarter-glass removal and measured 20 cm movement of both windshield edges against v19 prepared resources. Retained construction33, rear shape24 and continuity58 pass. The original bonnet fixture samples its former fixed length and reports 32 failures outside the shortened panel; its log and unchanged source remain. An owned copy samples the actual prepared hood extent with the same five slope/convexity limits and passes 40 checks. Full/simple visible geometry remains 119238/38224 triangles inside 120000/45000. Native model/lighting34, actual App Garage/race58, focused racing23 and preferred owned-source parsing pass. Ten final clean/synthetic-wear Garage views save on each renderer, including front-pillar close-ups. Two matched before sets use v17 and pre-windshield-move v19. These are engine renders, not image edits or owner-save data.

Current v20 meshes, five shadow frames, the Volt Garage template and 52 native Garage/header/news/livery pictures are rebuilt and imported. Historical v17 files remain exact. Shared manifest checkpoints retain current concurrent context while reverting only owned entries. Configuration/source changes from other tasks are excluded. Intermediate v18/v19 sources/resources and measurements, transient missing-Hovercraft failure, audit node-name correction, metadata-sharing collision and original bonnet-domain failure remain recorded. No full-project parse pass is claimed here; the previous unrelated fixture issue is outside this task.

[Commands and actual outcomes](evidence/volt-straight-shoulder-2026-10-28/commands.json), [report and measurements](evidence/volt-straight-shoulder-2026-10-28/report.json), [checked scoped patch](evidence/volt-straight-shoulder-2026-10-28/task.patch) and [round-trip proof/hashes](evidence/volt-straight-shoulder-2026-10-28/checkpoint.json). Engine commands run through `scripts/dev.ps1`, pinned to `godot-version.txt`, with an isolated local profile. `run_checks.py` records their exact arguments and exits.

Reload/rebuild to see the result. Owner appearance and physical-device acceptance remain. The shape is styled for an aerodynamic appearance; no drag coefficient, phone frame-rate or handling improvement is claimed. No device attachment query/test, APK, owner-save/live/backend mutation, deployment, owner-process restart or main-index staging/commit/merge was performed.
'''
(ROOT/'docs/VOLT_CABIN_AERO_CORRECTION_2026_10_28.md').write_text(document,encoding='utf-8')
block='''<!-- VOLT-CABIN-AERO-CORRECTION-20261028 -->
## Volt straight waist, fitted doors and sleeker silhouette (2026-10-28)
VSC01-VSC06/VA01/R01/Q01: V20 straightens waist, lowers rear glass, paints upper rear area, encloses door windows, removes fixed quarter glass and smooths front pillar. Whole windshield advances20cm with shorter bonnet, longer front cabin and matching mirrors/doors; low nose/flatter roof/tucked bumpers retain sleeker silhouette. New actual-buffer46, retained construction33/shape24/flow58, owned bounds-aware bonnet40, native model34/App58/racing23 and preferred parse pass. Original bonnet fixture samples beyond shortened hood and retains32 failures; same shape limits pass on actual panel. Full119238/simple38224 stay within120000/45000. Ten final views each renderer/two matched before sets; meshes/shadows/Volt template/52 pictures refresh/import. One runtime source/three owned helpers; old fixtures/v17 resources/concurrent work preserved. Intermediate v18/v19, transient Hovercraft, node-name and metadata-lock findings retained. Scoped patch round-trips; no drag/phone-performance or full-project parser claim. Commands/hashes/limits: docs/VOLT_CABIN_AERO_CORRECTION_2026_10_28.md and docs/evidence/volt-straight-shoulder-2026-10-28/report.json. Reload and owner/device acceptance remain. No device query/test, APK, owner-save/live/backend mutation, deployment, owner-process restart or main-index staging/commit/merge.
<!-- /VOLT-CABIN-AERO-CORRECTION-20261028 -->

'''
for relative in ['AGENTS.md','DEVELOPMENT_STATUS.md','docs/PHASE_0_PLAN.md']:
    path=ROOT/relative
    original=path.read_bytes()
    if b'<!-- VOLT-CABIN-AERO-CORRECTION-20261028 -->' not in original:
        backup=OUT/'task-base'/relative
        backup.parent.mkdir(parents=True,exist_ok=True)
        backup.write_bytes(original)
        path.write_bytes(block.encode('utf-8')+original)
print(json.dumps(dict(source_sha256=source,verified_jobs=len(required),patch_sha256=checkpoint['patch_sha256'])))
