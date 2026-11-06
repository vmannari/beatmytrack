"""Summarize completed checks and preserve concurrent tracker content."""
import hashlib
import json
import subprocess
import sys
from pathlib import Path

evidence = Path(__file__).resolve().parent
root = evidence.parents[2]
summary = {}
for label, checks in [('final-headless',148),('final-compatibility',196),('final-mobile',196),('final-roof-pixels',8),('final-mobile-roof-pixels',8)]:
    report = json.loads((evidence/label/'report.json').read_text())
    receipt = json.loads((evidence/(label+'-receipt.json')).read_text())
    assert (report['checks'],report['failures'],receipt['exit_code']) == (checks,0,0)
    assert receipt['sources_unchanged'] and not receipt['script_errors']
    summary[label] = {'checks':checks,'failures':0,'exit_code':0}
    if label in ['final-compatibility','final-mobile']:
        assert all(m['changed'] == 0 for m in report['metrics'] if m['part']=='sides')
        canopy = [m for m in report['metrics'] if m['part']=='canopy']
        summary[label]['canopy_mean_ranges_255'] = {key:[min(m[key] for m in canopy),max(m[key] for m in canopy)] for key in ['before_mean_255','after_mean_255']}
        summary[label]['side_pixels_exact'] = True
        summary[label]['native_captures'] = len(list((evidence/label).glob('*.png')))
for car in ['electric','hovercraft']:
    for stage in ['bases','kits','garage']:
        r=json.loads((evidence/('bake-'+car+'-'+stage+'-receipt.json')).read_text())
        assert r['exit_code']==0 and r['sources_unchanged'] and not r['script_errors']
        assert r['after']['game/vehicle/electric_glass.gdshader']==hashlib.sha256((root/'game/vehicle/electric_glass.gdshader').read_bytes()).hexdigest()
assert '1925 checks, 0 failures' in (evidence/'preflight/prepared-preflight.log').read_text()
assert '5 exact native images, 156 current source hashes' in (evidence/'preflight/pictures-preflight.log').read_text()
before=json.loads((evidence/'assets-before.json').read_text())
after=json.loads((evidence/'assets-after.json').read_text())
assert all(before[name]==after[name] for name in before if name.endswith('.png'))
picture_check=subprocess.run([sys.executable,str(root/'scripts/check_garage_previews.py')],cwd=root,capture_output=True,text=True)
(evidence/'pictures-repeat-preflight.log').write_text(picture_check.stdout+picture_check.stderr,encoding='utf-8')
assert picture_check.returncode == 0, picture_check.stderr
summary['compact_capture_variance']=json.loads((evidence/'picture-pixels/report.json').read_text())
summary['assets']={'resources':468,'checks':1925,'failures':0,'changed_files':sum(before[n]!=after[n] for n in before),'all_archived_pngs_exact':True}
(evidence/'summary.json').write_text(json.dumps(summary,indent=2),encoding='utf-8')
report_text = '''# Volt Night glass curvature — 2026-11-06

The owner found the darkened upper glass unnatural and preferred the side windows. This revision changes the Night canopy reflection, keeping that preferred side treatment exact.

## Requirements and changes

- **VGS01 — upper glass should read as curved glass.** The only production source change is `game/vehicle/electric_glass.gdshader`. Its Night canopy branch reduces the constant reflection contribution, varies the sky response with the reflected elevation, adds a broad restrained sheen aligned with the existing Night directional light, and softens the pane perimeter. It uses the actual curved mesh normals. This remains a stylized analytic reflection, not a scene capture or ray-traced reflection.
- **VGS02 — preserve the preferred side glass and other contexts.** The branch requires Night, no studio override, no existing frit and no mirror flag. Those conditions select the existing windscreen/roof/rear-glass materials. Side/mirror code, daylight, studio, shared Hover defaults, geometry, paint, physics, camera and race rules remain unchanged. The existing race-owned context helper is unchanged. The existing shader handles all panes, without an additional shader file, transparency pass, texture capture or per-frame script update.
- **VGS03 — prepared assets and native evidence.** The focused fixture compares the previous and revised shader on the same shader/material identities in actual production Game scenes. Full/simple stock Volt, four headings, ordinary race framing, isolated canopy/side masks, day/studio and canonical state are covered. Separate headless tests retain the preceding ownership/transition/replacement/teardown checks. Roof-only diagnostics reuse the retained identical-camera masks, verify every sampled roof pixel lies inside the current canopy mask, and measure increased tonal variation.

Supporting files are `game/tests/test_volt_night_glass_shape.gd`, `probe_volt_glass_shape_pixels.gd`, `probe_volt_canopy_normals.gd` and the archived-candidate review fixture; evidence helpers retain source hashes, process exits, asset archives and a scoped checkpoint. Earlier tests and their assertions are not edited or weakened.

## Accepted validation

Final native Compatibility **196/0**, desktop Mobile **196/0**, headless ownership/model checks **148/0**, and roof-only diagnostics **8/0 per renderer** pass. Each native run uses the actual refreshed prepared car and captures 60 images, 120 total. All sixteen side/mirror views are pixel-exact to the preceding shader. Day and studio whole-frame comparisons and track/simulation state are exact. Dark, visible canopy variation passes in all sixteen views; darkness alone is not the acceptance condition.

- [Before](evidence/volt-night-glass-shape-2026-11-06/final-compatibility/full-heading-270-before.png)
- [Revised upper glass](evidence/volt-night-glass-shape-2026-11-06/final-compatibility/full-heading-270-after.png)
- [Another heading](evidence/volt-night-glass-shape-2026-11-06/final-compatibility/full-heading-180-after.png)
- [Ordinary race view](evidence/volt-night-glass-shape-2026-11-06/final-compatibility/full-race-after.png)
- [Desktop Mobile](evidence/volt-night-glass-shape-2026-11-06/final-mobile/full-heading-270-after.png)

The [summary](evidence/volt-night-glass-shape-2026-11-06/summary.json) contains exact image measurements and counts. These are rendered RGB values, not physical light measurements. The normal probe confirms that the roof mesh has curved normals; its geometry was not altered.

The final asset refresh regenerates eight bases, 200 kit modules and two Garage templates for the shader's two declared consumers. Complete preflight passes **468 resources / 1,925 checks / 0 failures**. Five-picture provenance passes with **156 current source hashes**; all archived PNGs are byte-exact to task start. The shared Hover shader keeps its default appearance. Dependency guards are retained.

## Retained attempts and limits

The first test fixture inserted a new dictionary key with dot syntax, producing a StringName rejected by the strict document validator. The initial run logged a nil-track script error, and an added explicit validation check exposed the unsupported-key failure. Using the schema's String key fixed the fixture. Neither failed run is counted as a pass.

The first reflection candidate became almost black and failed six variation checks (188/6). A lifted candidate passed Compatibility (196/0), but Mobile retained only seven colour steps in two headings per model (196/4). A stronger elevation gradient alone also retained those four failures. The final palette gives the darker renderer enough variation and passes the original thresholds (196/0 in the candidate run). Rejected sources, reports and captures remain archived.

One Mobile candidate launch stalled before producing captures. After a sandbox-denied process query, an escalated read identified only the task-owned test command. Only its identified Godot process was stopped; the receipt retains exit 4294967295 and the retry is separate. Native-only final runs verify prepared Game hits; the 148 model/lifetime checks run separately headless. This does not omit those checks or relax their assertions.

The standard `scripts/dev.ps1` invocation refreshed generated build identity but its wrapper returned Access denied. Its child and the direct headless run both exposed two stale prepared-key failures. The shader source hashes were current, but baking before refreshing the generated revision had produced old scene keys. The initial completed bake and the interrupted subsequent bake are archived separately. Only the identified task-owned outdated bake tree was stopped. The helper now freezes generated identity before any baker starts, and every final stage completes with stable sources and matching current keys. Final native and headless checks were rerun after this repair. No stale assertion was bypassed.

The first final thumbnail pass changed one unrelated Compact pixel at (939,272) by 1/255 in red. A single repeated native five-picture capture returned every PNG byte-exact to task start, and the independent pixel diagnostic retains both outcomes. The initial Compact image and provenance are archived in `picture-variance`; final provenance is checked again after the repeat. This is not a claim that separate native captures always produce identical bytes.

The environment's certificate-store messages and any shutdown diagnostics remain in the individual logs. Earlier tasks' Mobile mask-restoration limitation is not claimed fixed: this fixture prepares masks before its source comparison, and the earlier fixtures are unchanged. Native shader profiles for the previous source were not regenerated; the existing unknown-source compilation fallback remains available. No frame-rate, loading-time or device-performance gain is claimed.

## Commands and delivery

```powershell
python docs/evidence/volt-night-glass-shape-2026-11-06/run_check.py prototype-valid res://tests/test_volt_night_glass_shape.gd --native --procedural
python docs/evidence/volt-night-glass-shape-2026-11-06/run_check.py prototype-reflection res://tests/test_volt_night_glass_shape.gd --native --procedural
python docs/evidence/volt-night-glass-shape-2026-11-06/run_check.py prototype-mobile res://tests/test_volt_night_glass_shape.gd --native --procedural --renderer mobile
python docs/evidence/volt-night-glass-shape-2026-11-06/run_check.py elevation-mobile res://tests/review_volt_canopy_candidate.gd --native --procedural --renderer mobile
python docs/evidence/volt-night-glass-shape-2026-11-06/run_check.py reflection-palette-mobile-retry res://tests/review_volt_canopy_candidate.gd --native --procedural --renderer mobile --timeout 300
python docs/evidence/volt-night-glass-shape-2026-11-06/run_check.py final-headless-dev res://tests/test_volt_night_glass_shape.gd --dev
python docs/evidence/volt-night-glass-shape-2026-11-06/prepare_assets.py
python docs/evidence/volt-night-glass-shape-2026-11-06/run_check.py final-headless res://tests/test_volt_night_glass_shape.gd
python docs/evidence/volt-night-glass-shape-2026-11-06/run_check.py final-compatibility res://tests/test_volt_night_glass_shape.gd --native --native-only --timeout 400
python docs/evidence/volt-night-glass-shape-2026-11-06/run_check.py final-mobile res://tests/test_volt_night_glass_shape.gd --native --native-only --renderer mobile --timeout 400
python docs/evidence/volt-night-glass-shape-2026-11-06/run_check.py final-roof-pixels res://tests/probe_volt_glass_shape_pixels.gd --source=res://../docs/evidence/volt-night-glass-shape-2026-11-06/final-compatibility
python docs/evidence/volt-night-glass-shape-2026-11-06/run_check.py final-mobile-roof-pixels res://tests/probe_volt_glass_shape_pixels.gd --source=res://../docs/evidence/volt-night-glass-shape-2026-11-06/final-mobile
python docs/evidence/volt-night-glass-shape-2026-11-06/run_check.py bake-pictures-repeat res://../scripts/bake_garage_previews.gd --native
python docs/evidence/volt-night-glass-shape-2026-11-06/run_check.py picture-pixels res://tests/probe_volt_glass_shape_pictures.gd
python docs/evidence/volt-night-glass-shape-2026-11-06/finalize.py
python docs/evidence/volt-night-glass-shape-2026-11-06/checkpoint.py
```

Runs use pinned Godot 4.7.2, the crash-dialog wrapper, private profiles, Dummy audio and an empty backend URL. Receipts retain the full commands and actual outcomes. Independent vehicle bake workers write distinct car resources; pictures and full preflight follow their completion. The [task-only source/binary patch](evidence/volt-night-glass-shape-2026-11-06/task.patch) is forward/reverse checked with exact bytes in private Git repositories; the [checkpoint receipt](evidence/volt-night-glass-shape-2026-11-06/checkpoint.json) lists its files.

This refinement is local. A fresh PC game loads it; the already installed tablet build has not been updated by this task. **No physical-device test or query, APK, owner-save/process change, backend request or deployment was performed.** Owner appearance acceptance remains open. Concurrent changes, generated shared build metadata and the workspace Git index are preserved.
'''
(root/'docs/VOLT_NIGHT_GLASS_SHAPE_2026_11_06.md').write_text(report_text,encoding='utf-8')
marker='VOLT-NIGHT-GLASS-SHAPE-20261106'
description=('VGS01-VGS03: Owner rejects the flat upper glass and prefers the side windows. '
 'Night-only canopy shading uses a darker curved sky reflection, a broad sheen aligned with the Night light, and soft perimeter absorption. '
 'Side/mirror pixels, day/studio views and canonical state remain exact. Native Compatibility196/0 and desktop Mobile196/0, headless148/0 and roof-only16/0 pass;120 final captures. '
 'Eight bases/200 modules/two Garage templates refresh;468-resource1925/0 and five-picture156-source provenance pass, PNGs byte-exact. '
 'Rejected dark/quantized candidates, invalid fixture key, owned-renderer stall recovery and initial bakes retained without relaxed assertions. '
 '[Shader, comparisons, commands, limits and task-only checkpoint]({link}). '
 'Owner/device appearance acceptance and a rebuilt tablet update remain; no device query/test, APK, owner-save/process change, backend request, deployment or main-index write. Concurrent work preserved.')
for name in ['AGENTS.md','DEVELOPMENT_STATUS.md','docs/PHASE_0_PLAN.md']:
    path=root/name
    data=path.read_bytes()
    opening=('<!-- '+marker+' -->').encode()
    closing=('<!-- /'+marker+' -->').encode()
    if opening in data:
        start=data.index(opening); end=data.index(closing,start)+len(closing)
        if data[end:end+2]==b'\n\n':end+=2
        data=data[:start]+data[end:]
    link=('VOLT_NIGHT_GLASS_SHAPE_2026_11_06.md' if name.startswith('docs/') else 'docs/VOLT_NIGHT_GLASS_SHAPE_2026_11_06.md')
    block=opening.decode()+'\n## Volt Night upper glass follows the canopy curvature (2026-11-06)\n'+description.format(link=link)+'\n'+closing.decode()+'\n\n'
    path.write_bytes(block.encode('utf-8')+data)
print(json.dumps(summary,indent=2))
