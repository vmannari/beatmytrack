from pathlib import Path
import hashlib
import json
import math
import re

EVIDENCE = Path(__file__).resolve().parent
ROOT = EVIDENCE.parents[2]


def read_log(path):
    data = path.read_bytes()
    return data.decode('utf-16') if data[:2] in (b'\xff\xfe',b'\xfe\xff') else data.decode('utf-8-sig',errors='replace')


matrix = []
for path in sorted(EVIDENCE.glob('test_*.log')):
    log = read_log(path)
    counts = re.findall(r'(\d+) (?:checks|scripts), (\d+) failures',log)
    errors = [line.strip() for line in log.splitlines()
              if re.search(r'(^| : )(SCRIPT ERROR:|ERROR:)|Parse Error:',line)
              and 'Failed to read the root certificate store' not in line and line.strip() != 'ERROR: Access denied']
    checks,failures = (map(int,counts[-1]) if counts else (None,None))
    if checks is None:
        for line in log.splitlines():
            if '{' not in line: continue
            try: packet = json.loads(line[line.index('{'):])
            except ValueError: continue
            if isinstance(packet,dict) and 'checks' in packet and 'failures' in packet:
                checks,failures = int(packet['checks']),int(packet['failures'])
    matrix.append({'log':path.name,'checks':checks,'failures':failures,'unexpected_errors':errors,
                   'pass':checks is not None and failures == 0 and not errors})

publication = {}
for mode in ['headless','gl_compatibility','mobile']:
    path = EVIDENCE/'test_editor_t11_t15'/('results-'+mode+'.json')
    if not path.exists(): continue
    data = json.loads(path.read_text(encoding='utf-8'))
    values = sorted(case['publication_ms'] for case in data['observations'][0]['cases'])
    publication[mode] = {'samples':len(values),'median_ms':(values[(len(values)-1)//2]+values[len(values)//2])/2,
                         'p95_ms':values[math.ceil(len(values)*.95)-1],'maximum_ms':values[-1],
                         'scope':'One publication per distinct cold model in a running desktop process. Not paired speedup, GPU time, input latency, sustained FPS or Android results.'}

files = [
    'game/core/app.gd','game/core/build_identity.gd','game/editor/editor_session.gd',
    'game/editor/editor_gesture.gd','game/editor/road_piece_catalog.gd','game/editor/editor_canvas.gd',
    'game/editor/commit_queue.gd','game/editor/editor_world.gd','game/editor/road_pieces.gd',
    'game/editor/track_document.gd','game/editor/creator_limits.gd','game/editor/creator_prop_costs.gd','game/editor/track_compiler.gd','game/editor/placed_object_batches.gd',
    'game/track/creator_prop_visual.gd','game/track/prop_geometry.gd','game/track/native_track.gd',
    'game/track/native_track_visual.gd','game/track/spatial_mesh_chunks.gd','game/track/winter_prop_finish.gd',
    'game/ui/track_catalog.gd','game/persistence/track_library.gd','game/tests/test_editor_t11_t15.gd',
    'game/tests/test_road_pieces.gd','game/tests/test_editor_incremental_objects.gd',
    'docs/schemas/creator-track-v5.schema.json','godot-version.txt',
]
manifest = {}
for name in files:
    path = ROOT/name
    manifest[name] = {'sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'bytes':path.stat().st_size}
    prior = EVIDENCE/'before'/name
    if prior.exists(): manifest[name]['task_original_sha256'] = hashlib.sha256(prior.read_bytes()).hexdigest()
(EVIDENCE/'source-manifest.json').write_text(json.dumps(manifest,indent=2)+'\n',encoding='utf-8')

checkpoint = json.loads((EVIDENCE/'checkpoint.json').read_text(encoding='utf-8')) if (EVIDENCE/'checkpoint.json').exists() else {}
renders = json.loads((EVIDENCE/'render-comparisons.json').read_text(encoding='utf-8')) if (EVIDENCE/'render-comparisons.json').exists() else []
result = {
    'requirements':['T11','T12','T13','T14','T15','R01','Q01'],
    'engine':'4.7.2.stable.official.ed1daf0bf','gpu':'Windows NVIDIA RTX 3090, driver 616.92',
    'targeted_matrix':matrix,'targeted_logs_all_pass':all(row['pass'] for row in matrix),
    'road_baseline':{'checks':377,'failures':24,'log':'initial/test_road_pieces-headless.log'},
    'publication_desktop_observations':publication,
    'final_render_pairs':[row for row in renders if row['original'].startswith('renders/')],
    'initial_mobile_delta':{'channels':2,'maximum':1,'biome':'pine','source':'initial/mobile-pine-pixels','cause':'unresolved non-repeatable native render delta','assertion_relaxed':False,'controlled_identical_originals':3,'controlled_pairs':3,'winter_exact_in_all_retained_pairs':True},
    'broader_known_failure':{'test':'test_race_results','location':'reward_reveal.pause()','reproduced_with_task_original_app':True,
                              'logs':['initial/test_race_results-headless.log','initial/results-original-app.log'],
                              'fixture_current_biome':'winter replaces retired coast','reward_assertions_unchanged':True,'passing_release_gate':False},
    'corrections':['Malformed schema comparisons need an explicit String guard before !=; 18 negative checks added.',
                   'Kerb test first used the wrong Z sign; fixed coordinate mapping with every-vertex equality retained.',
                   'Graphical workflow harness retires stopped soundtrack decoders before SceneTree exit.',
                   'Concurrent capacity changes require a valid current-limit quota fixture and a guarded creator-query metadata lookup; dense proxy fixtures now stay within the uniform budget.',
                   'A PowerShell -File array argument was first passed as one script name; corrected to -Command with an actual array.',
                   'dev.ps1 uses -Action, not -Task; corrected, then isolated APPDATA fixed the startup log permissions.'],
    'format_policy':{'creator':'creator-track-v5','native':'surface-grid-v2','coast_alias':False,'older_format_conversions':False,'rejected_files_deleted':False,'authoring_bytes':1048576,'placed_objects':4096,'tyre_stacks':4096,'prop_estimate_bytes':134217728,'small_scene_exemption':False},
    'commands':[
        'powershell -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action CheckScript -ScriptPath res://tests/test_road_pieces.gd -GodotPath "C:/apps/Godot 4.7.2/Godot_v4.7.2-stable_win64_console.exe" (isolated APPDATA)',
        "powershell -ExecutionPolicy Bypass -Command \"& './docs/evidence/editor-t11-t15-2026-10-23/run.ps1' -TestName @('test_editor_t11_t15','test_road_pieces','test_app','test_script_parse')\"",
        'powershell -ExecutionPolicy Bypass -File docs/evidence/editor-t11-t15-2026-10-23/run.ps1 -Graphical -Renderer gl_compatibility -TestName test_editor_t11_t15; same command with -Renderer mobile. Other named suite logs record the earlier batched runs.',
        'Pinned engine --path game --rendering-method mobile --audio-driver Dummy --script res://../docs/evidence/editor-t11-t15-2026-10-23/probe_pine.gd [-- --same-source]',
        'Pinned engine --headless --path game --audio-driver Dummy --quit-after 1500 --script res://../docs/evidence/editor-t11-t15-2026-10-23/initial/results-baseline-fixture.gd',
        'python docs/evidence/editor-t11-t15-2026-10-23/check_renders.py',
        'python docs/evidence/editor-t11-t15-2026-10-23/build_checkpoint.py',
        'python docs/evidence/editor-t11-t15-2026-10-23/build_report.py',
    ],
    'checkpoint':{key:checkpoint.get(key) for key in ['task_commit','patch_sha256','patch_bytes','git_apply_check','git_apply_readback_exact_normalized_text','shared_index_unchanged']},
    'limits':['No physical-device or sustained FPS/memory certification. No phone attachment check or device test.',
              'Main-thread atomic prop publication and cold shader work can exceed a 16.67 ms frame.',
              'Burning-car optional worker preparation is skipped because construction reads an encoded wreck mesh.',
              'General Python JSON-schema validator is unavailable; schema enums/syntax and engine import/export paths are checked.',
              'No APK, live backend/account mutation, publication, social send or deployment. Concurrent work is preserved.'],
}
(EVIDENCE/'report.json').write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8')
artifacts = {p.relative_to(EVIDENCE).as_posix():{'bytes':p.stat().st_size,'sha256':hashlib.sha256(p.read_bytes()).hexdigest()}
             for p in sorted(EVIDENCE.rglob('*')) if p.is_file() and p.name != 'artifact-manifest.json'}
(EVIDENCE/'artifact-manifest.json').write_text(json.dumps(artifacts,indent=2)+'\n',encoding='utf-8')
print(json.dumps({'targeted_suites':len(matrix),'all_pass':result['targeted_logs_all_pass'],'publication':publication,
                  'final_pairs':len(result['final_render_pairs']),'checkpoint':result['checkpoint']},indent=2))
