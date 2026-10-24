from pathlib import Path
import json
import re
import statistics

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]

def load(mode):
    value = json.loads((HERE/f'results-{mode}.json').read_text(encoding='utf-8-sig'))
    assert value['failures'] == 0
    assert value['rows'][-1]['operation'] == 'complete'
    return {row['operation']:row for row in value['rows']}

def number(value): return f'{value:,.2f}'
rows = {mode:load(mode) for mode in ['headless','gl_compatibility','mobile']}
metrics = []
for mode in ['gl_compatibility','mobile']:
    data = rows[mode]
    metrics.append(f'| {mode} | {number(data["96_width_settle"]["ms"])} ms | '
                   f'{data["96_width_settle"]["retained_nodes"]}/{data["96_width_settle"]["previous_road_nodes"]} | '
                   f'{number(data["practice_enter_1"]["ms"])} ms | '
                   f'{number(data["practice_return_1"]["ms"])} ms |')
render = []
for mode in ['gl_compatibility','mobile']:
    data = rows[mode]
    full, reduced = data['dense_full'], data['dense_overview']
    render.append(f'| {mode} | {full["draws"][-1]}  to  {reduced["draws"][-1]} | '
                  f'{full["primitives"][-1]:,}  to  {reduced["primitives"][-1]:,} | '
                  f'{number(statistics.mean(full["cpu_ms"]))}  to  {number(statistics.mean(reduced["cpu_ms"]))} ms | '
                  f'{number(statistics.mean(full["gpu_ms"]))}  to  {number(statistics.mean(reduced["gpu_ms"]))} ms |')

tests = []
for log in sorted(HERE.glob('test_*-*.log')):
    data = log.read_bytes()
    text = data.decode('utf-16' if data.startswith((b'\xff\xfe',b'\xfe\xff')) else 'utf-8-sig',errors='replace')
    matches = re.findall(r'(\d+) checks, (\d+) failures',text)
    if not matches:
        match = re.search(r'SCRIPT_PARSE: (\d+) scripts, (\d+) failures',text)
        if match: matches = [match.groups()]
    if not matches:
        match = re.search(r'LOCAL_DRAFT_PUBLICATION_TEST (\{.*\})',text)
        if match:
            entry=json.loads(match.group(1)); matches=[(entry['checks'],entry['failures'])]
    if not matches: continue
    count, failed = map(int,matches[-1])
    errors = [line for line in text.splitlines() if re.search(r'(^| : )(SCRIPT ERROR:|ERROR:)|Parse Error:',line)
              and 'Failed to read the root certificate store' not in line and 'ERROR: Access denied' not in line]
    status = 'pass' if not failed and not errors else 'failed'
    if 'incremental_objects' in log.name and failed == 1:
        status = 'existing Winter grouped-prop parity failure; assertion retained'
    if any(name in log.name for name in ['publication_confirmation-mobile','editor_practice-mobile']) and not failed and errors and all(re.match(r'ERROR: 1 resources still in use at exit',line) for line in errors) and '4 ObjectDB instances were leaked' in text:
        status = 'assertions pass; existing Dummy/menu-audio shutdown resource error reproduced without app/editor'
    tests.append({'log':log.name,'checks':count,'failures':failed,'engine_errors':errors,'status':status})

result = {'requirements':['T01','T02','T03','T04'], 'measurements':rows,
          'tests':tests, 'source_manifest':'source-manifest.json','checkpoint':'task-only.patch',
          'commands':[
              'powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_editor_workflow.gd -CommandTimeoutSeconds 180 (attempted; certificate-store gate)',
              'pinned Godot --headless --editor --path game --audio-driver Dummy --import --quit',
              'powershell -NoProfile -ExecutionPolicy Bypass -File docs/evidence/editor-t01-t04-2026-10-23/run.ps1',
              'powershell -NoProfile -ExecutionPolicy Bypass -File docs/evidence/editor-t01-t04-2026-10-23/run.ps1 -Graphical -Renderer gl_compatibility',
              'powershell -NoProfile -ExecutionPolicy Bypass -File docs/evidence/editor-t01-t04-2026-10-23/run.ps1 -Graphical -Renderer mobile',
              "& './docs/evidence/editor-t01-t04-2026-10-23/run.ps1' -TestName @('test_editor_t01_t04','test_editor_workflow','test_editor_preparation','test_editor_practice','test_editor_review_fixes','test_editor_remaining','test_editor_incremental_objects','test_start_line','test_local_draft_publication','test_bridge_contacts','test_app','test_script_parse')",
              "& './docs/evidence/editor-t01-t04-2026-10-23/run.ps1' -Graphical -Renderer gl_compatibility -TestName @('test_editor_t01_t04','test_editor_workflow','test_editor_preparation','test_editor_practice','test_local_draft_publication','test_publication_confirmation')",
              "& './docs/evidence/editor-t01-t04-2026-10-23/run.ps1' -Graphical -Renderer mobile -TestName @('test_editor_t01_t04','test_editor_workflow','test_editor_preparation','test_editor_practice','test_publication_confirmation')",
              "& 'C:/apps/Godot 4.7.2/Godot_v4.7.2-stable_win64_console.exe' --path game --audio-driver Dummy --rendering-method mobile --verbose --script 'C:/Codes/Godot/Beat my track/docs/evidence/editor-t01-t04-2026-10-23/menu-audio-shutdown.gd'",
              'python docs/evidence/editor-t01-t04-2026-10-23/build_evidence.py',
              'python docs/evidence/editor-t01-t04-2026-10-23/build_report.py',
              'git diff --check -- affected implementation files (whitespace.log)'],
          'corrections':['StringName key in first synthetic fixture corrected to String',
                         'Tile centroid and whole joined-neighbour dirty bounds corrected against independent full output',
                         'Small editor upload explicitly yields between texture preparation and mesh installation',
                         'One provisional Mobile run mixed concurrent cached/new scripts; app scene now preloaded',
                         'Runner now rejects script/engine errors even for exit code zero; certificate metadata is separately excluded'],
          'known_limits':['96-piece final detail still takes seconds; no 150 ms claim',
                          'Warm practice entry remains above the proposed 500 ms budget',
                          'Desert world deformation and globally dependent Winter/small-Grass/bridge/spline roads retain full preparation fallbacks',
                          'Canonical raster compilation, topology/outlines and terrain preparation are still global',
                          'No physical device, sustained thermal/30-minute soak or actual human UX study',
                          'Existing Winter prop parity and standalone menu-audio shutdown issues remain outside T01-T04']}
(HERE/'report.json').write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8')

mobile=rows['mobile']; compat=rows['gl_compatibility']
drag=mobile['drag_width_preview_120']
body = f'''# Track editor T01-T04 fixes - 2026-10-23

Implemented the four findings in [the editor audit](TRACK_EDITOR_AUDIT_2026_10_23.md). Modular construction, saved/published formats, compiler/rules/physics versions, racing geometry and publication authority are preserved. No server change, APK, deployment, live account mutation, phone attachment check or physical-device test was performed by this task.

**T01 - retain the scene and dependency-affected geometry.**

`editor_world.gd::_build_track` now updates the current visual in a transaction. `road_update.gd::plan` includes old/new piece bounds, complete affected neighbours, four-half-width joined mitres, taper exit widths and cosmetic reach. Unchanged prefix/suffix pieces survive insertion/deletion. Ordinary Grass, Storm and Night edits prepare dirty spatial tiles; Night retains its 16 m lighting partitions. Untouched nodes and matching meshes stay alive, including when other terrain/features need replacement. A superseded transaction cannot publish, and input keeps the planning overlay immediate.

The road preparation path omits Grass verge stones/blades that are normally sub-pixel in the planning overview on tracks with at least 32 pieces or more than 240 m of sampled road. Small tracks retain their original detailed verge. This presentation recipe has its own cache identity and cannot supply racing meshes or saved final-quality bakes. Full racing preparation remains unchanged. Winter's ordered deposits and Desert's wear/relief retain full preparation; Desert still replaces its deformed world. Bridges, splines and other changed dependencies use complete road preparation. These fallbacks preserve correctness rather than assuming every edit is local.

`road_preparation.gd` now uses available capacity inside the existing combined 32 MiB allowance. Planning packets are not retained alongside their uploaded scene. The idle GPU LRU reserves CPU work space when entering/resuming the editor. Cosmetic kerb segments/runs and normalized streams are reusable. `road_sections.gd` copies contiguous unindexed attributes in bulk. Installation shares role materials and the kerb exclusion texture, charges the upload budget only for new meshes, and retains the 24,576-vertex/4 ms cooperative budget. Empty native bridge decks no longer scan every cell twice.

This fixes unnecessary scene replacement and many unrelated mesh rebuilds. It does **not** make every operation proportional only to the changed piece: canonical raster compilation, topology/outlines, terrain masks, some clipping collectors and globally dependent decoration still involve track-wide work.

**T02 - one exact prepared track and the retained practice return.**

`app.gd::_test_document`, `_save_draft` and `TrackLifecycle.prepare_test` reuse the exact preview after a durable save. Full document equality and the current compiler/base hash fence reuse; a fallback preview cannot become a publication test. Saved-draft testing also compiles once. `prepared_track_cache.gd::copy_track` copies all script/contact fields for practice so its spawn and mutable helpers cannot change the editor snapshot.

The existing root, viewport, camera, tools, selection and undo history are suspended during practice and resumed directly. Document, library, owner scope, vehicle, navigation and root identity must still match. Active canvas gestures must finish before Test starts. Stale contexts follow ordinary navigation. The shared cancellation path restores the suspended root's process mode. Practice remains untimed and creates no public race ticket or leaderboard attempt.

Already owned background preparation can finish while the editor is hidden. Avoiding overlap between that work and race preparation remains a startup optimization; disabling node processing alone does not cancel those workers.

Concurrent F04/F05 cooperative race loading/profiling changes landed in App/Game/NativeTrackVisual during this task and are preserved. Timing below describes the integrated source, not an isolated speedup attributed entirely to T02.

**T03 - shared handle geometry, layout and attachment preparation.**

`editor_canvas.gd` caches world anchors/derivative axes separately from screen placement. Drawing and hit testing share the same layout; camera changes reuse world geometry. Gesture-origin geometry has its own slot. Neighbour topology is retained independently of the moving piece, and attachment results use its revision instead of copying all neighbours for every trial. Non-bridge edits skip bridge validation only when the resulting document has no bridges. Original handle positions are checked against the captured old canvas at four views for six piece types.

On the final Compatibility 96-piece fixture, 100 repeated Curve layouts took {number(compat['handles_curve']['before_100_ms'])} ms on the original canvas and {number(compat['handles_curve']['after_100_ms'])} ms on the new canvas. The changing-pose measurement also includes derivative-axis preparation, so it is reported separately in the raw results rather than presented as the same workload.

**T04 - adaptive detail with the original models retained.**

`editor_detail.gd` activates inexpensive authored-prop silhouettes when at least 24 authored objects are in/near the visible canvas and the view is below 8 planning pixels/metre, or while that dense view is being manipulated. A 140 ms settling interval avoids toggling between input events. The selected group, sufficiently large/readable props, tyres, hazards, surfaces, gantries, direction signs and functional lighting cues retain their exact geometry. Generated trees stay in their existing original batch. Cheap contact shadows remain; directional shadows and tiny cover are suppressed in the dense overview. Close settled inspection restores the original retained meshes and shadows. No permanent UI control or canvas obstruction was added. The policy is provisional pending owner/phone appearance and touch acceptance.

**Measured desktop results.**

Pinned Godot 4.7.2, Windows debug engine, RTX 3090, 1280x720, synthetic tracks, isolated APPDATA and Dummy audio. The stress fixture has 96 road pieces; density has 95 containers. These are single operation samples and twelve warmed viewport samples, not phone FPS certification or statistically established loading percentiles.

| Renderer | 96-piece width edit  to  detailed scene | Retained original road nodes | Warm practice entry | Practice return |
|---|---:|---:|---:|---:|
{chr(10).join(metrics)}

The original audit recorded 8.73-9.65 s for large detailed updates and about 4.24 s for editor return. Those are earlier runs, not a controlled paired speedup measurement. The proposed 150 ms final-detail and 500 ms warm-entry targets remain unmet for this stress fixture. Immediate input feedback and deferred final geometry are separate measurements.

The final Mobile 120-step synthetic width drag measured handler mean/P95/P99 {number(drag['handler']['mean_ms'])}/{number(drag['handler']['p95_ms'])}/{number(drag['handler']['p99_ms'])} ms; dispatched-event-to-rendered-frame mean/P95/P99 {number(drag['synthetic_event_to_frame']['mean_ms'])}/{number(drag['synthetic_event_to_frame']['p95_ms'])}/{number(drag['synthetic_event_to_frame']['p99_ms'])} ms. This measures the planning overlay after script-dispatched events, not physical Android touch-to-photon latency or detailed completion.

| Same dense view | Draw calls: full  to  overview | Primitives: full  to  overview | Mean viewport CPU | Mean viewport GPU |
|---|---:|---:|---:|---:|
{chr(10).join(render)}

**Verification and retained failures.**

The focused test checks dirty/full mesh parity for width/move/add/delete in three biomes, extreme joined widths, distant node retention, cancellation, undo/redo, practice isolation and identity fences, grouped gesture recovery, original handle positions, adaptive selection detail and full-detail restoration. Final per-run counts are in [report.json](evidence/editor-t01-t04-2026-10-23/report.json).

Rendered acceptance has 932 checks per renderer. The final 937-check headless run additionally covers Winter asphalt-to-dirt metadata cleanup and reservation after a real 28.6 MB final CPU packet. Those lifecycle changes preserve road array output; the rendered measurements precede them. All 955 project scripts parse, and the pinned editor import and scoped whitespace checks pass.

Broader checks cover workflow (252), preparation (270 headless/279 rendered, including exact original pixels and upload budgets), practice (54), review/recovery (69), remaining editor checks (120), start line (27), local publication (31), bridge contacts (16), App (141), publication confirmation (72) and parser loading. The existing incremental-object suite retains one failure in 47 checks: Winter grouped-prop triangle multiplicity/pigments/positions/normals. It was already reproduced in the audit; its assertion and batching implementation are unchanged.

Mobile practice and publication confirmation pass their 54/72 assertions but report four Ogg playback objects and one resource at shutdown. The unchanged soundtrack's music-only probe reproduces that resource with no app/editor instantiated; verbose evidence is retained. These runs are not classified as clean engine exits. The focused editor test releases that unrelated autoload before quitting so editor cleanup is evaluated separately. The runner rejects real script/engine errors even for process exit 0; only the exact sandbox Windows certificate-store diagnostic is exempted.

Initial failed fixture/dirty-bound/upload-scheduling trials and a provisional mixed-source Mobile run remain in evidence. They are not counted as clean acceptance. The active app scene is now preloaded before long CPU tests to keep Native/Game script revisions coherent.

**Reproduce and review.**

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File docs/evidence/editor-t01-t04-2026-10-23/run.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File docs/evidence/editor-t01-t04-2026-10-23/run.ps1 -Graphical -Renderer gl_compatibility
powershell -NoProfile -ExecutionPolicy Bypass -File docs/evidence/editor-t01-t04-2026-10-23/run.ps1 -Graphical -Renderer mobile
python docs/evidence/editor-t01-t04-2026-10-23/build_evidence.py
python docs/evidence/editor-t01-t04-2026-10-23/build_report.py
```

`scripts/dev.ps1` was attempted first; its fail-on-ERROR gate terminates on the sandbox's unrelated certificate-store error. The evidence runner verifies the exact engine pin, isolates data and disables the live API. Actual commands, logs, screenshots and corrections are under [the evidence directory](evidence/editor-t01-t04-2026-10-23/). The [scoped checkpoint](evidence/editor-t01-t04-2026-10-23/task-only.patch) was checked/applied with Git in a fresh temporary repository and compared to the actual changed files. Captured preimages, explicitly reconstructed concurrent foundation, source hashes and the separated concurrent delta are retained. The shared repository index was not staged or committed.

Remaining acceptance: reference-phone sustained frame times/input latency/thermal memory, a 20-30 minute editing soak, owner review of overview detail, and further reductions in complex final geometry and practice startup. No physical-device result is implied by the desktop Mobile renderer.
'''
(ROOT/'docs/EDITOR_T01_T04_2026_10_23.md').write_text(body,encoding='utf-8')
print(json.dumps({'test_receipts':len(tests),'report_words':len(body.split())}))
