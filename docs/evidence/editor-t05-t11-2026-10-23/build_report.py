"""Retain actual suite outcomes, measurements and native evidence."""
from pathlib import Path
import hashlib
import json
import re
import shutil
from datetime import datetime, timezone

OUT = Path(__file__).resolve().parent
ROOT = OUT.parents[2]


def read(path):
    data = path.read_bytes()
    return data.decode('utf-16' if data[:2] in (b'\xff\xfe', b'\xfe\xff') else 'utf-8-sig', errors='replace')


tests = {}
for path in sorted(OUT.glob('test_*.log')):
    content = read(path)
    matches = re.findall(r':\s*(\d+)\s+(checks|scripts),\s*(\d+)\s+failures', content)
    if matches:
        count, unit, failures = matches[-1]
    else:
        local = re.search(r'LOCAL_DRAFT_PUBLICATION_TEST (\{[^\n]+\})', content)
        if not local: continue
        result = json.loads(local.group(1))
        count, unit, failures = result['checks'], 'checks', result['failures']
    errors = [line.strip() for line in content.splitlines()
              if re.search(r'(^| : )(SCRIPT ERROR:|ERROR:)|Parse Error:', line)
              and 'Failed to read the root certificate store' not in line
              and line.strip() != 'ERROR: Access denied']
    audio = bool(errors) and all('resources still in use at exit' in line for line in errors)
    tests[path.name] = {'count':int(count), 'unit':unit, 'assertion_failures':int(failures),
                        'runtime_errors':errors,
                        'status':'inherited_menu_audio_shutdown' if audio and int(failures) == 0
                        else 'pass' if not errors and int(failures) == 0 else 'fail',
                        'log_sha256':hashlib.sha256(path.read_bytes()).hexdigest()}

measurements = {}
for path in sorted(OUT.glob('results-*.json')):
    measurements[path.stem.removeprefix('results-')] = json.loads(path.read_text())

# Retain exact successful original/grouped pixels beside the report.
renders = {}
for mode in ['gl_compatibility', 'mobile']:
    log = OUT/('test_editor_incremental_objects-'+mode+'.log')
    if not log.exists(): continue
    content = read(log)
    match = re.search(r'evidence=([^\r\n]+)', content)
    assert match, log
    source = Path(match.group(1).strip()).resolve()
    assert source.is_relative_to(ROOT), source
    target = OUT/'renders'/mode
    target.mkdir(parents=True, exist_ok=True)
    for path in source.glob('*.png'):
        shutil.copyfile(path, target/path.name)
    renders[mode] = {'source_directory':str(source),
                     'pixels':re.findall(r'EDITOR_INCREMENTAL_PIXELS (\w+) changed_channels=(\d+) maximum=(\d+)', content)}

scope = {
    'T05':{'status':'implemented','files':['game/editor/editor_history.gd','game/core/app.gd'],
           'mechanism':'Shared immutable binary fields; one 8 MiB / forty-state allowance across ordinary undo and redo.'},
    'T06':{'status':'implemented','files':['game/editor/editor_canvas.gd'],
           'mechanism':'Lazy touched-domain rollback, no navigation snapshot, exact pinch/history restoration.'},
    'T07':{'status':'implemented','files':['game/editor/commit_queue.gd','game/core/app.gd'],
           'mechanism':'Ordered coalesced analysis and durable writing, exact stale/current fences and explicit flush boundaries.'},
    'T08':{'status':'mitigated_with_remaining_driver_limit','files':['game/editor/editor_world.gd','game/editor/material_preparation.gd','game/track/native_track_visual.gd'],
           'mechanism':'Remove synthetic build and unused light; small actual-material batches, stricter editor uploads and navigation during preparation.',
           'remaining':'A cold GPU driver call is not bounded by cooperative script yields. Final-source cold Android acceptance is unmeasured.'},
    'T09':{'status':'implemented','files':['game/editor/spatial_bounds.gd','game/editor/road_piece_work.gd','game/editor/placed_object_batches.gd','game/editor/spline_borders.gd'],
           'mechanism':'Ordered spatial broad phases, disjoint-set clustering and local perimeter queries; original exact endpoint buckets retained.'},
    'T10':{'status':'implemented_with_device_acceptance_pending','files':['game/editor/editor_memory.gd','game/editor/cache_bytes.gd','game/editor/editor_world.gd'],
           'mechanism':'Coordinated 64 MiB retained estimate, staged reclamation, OS pressure handling and unique active/transient/idle scene ownership.',
           'remaining':'Policy estimates are not Android PSS, an active/intermediate hard cap or a long-session leak certification.'},
    'T11':{'status':'implemented','files':['game/editor/placed_object_batches.gd'],
           'mechanism':'Preserve actual material families and remove duplicate individual contact shadows.'},
}

commands = [
    'powershell -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_editor_t05_t11.gd',
    "powershell -ExecutionPolicy Bypass -Command \"& 'docs/evidence/editor-t05-t11-2026-10-23/run.ps1' -TestName @('test_editor_t05_t11','test_editor_workflow','test_editor_review_fixes','test_editor_remaining','test_editor_t01_t04','test_local_draft_publication','test_start_line','test_spline_barriers','test_app','test_script_parse')\"",
    "powershell -ExecutionPolicy Bypass -Command \"& 'docs/evidence/editor-t05-t11-2026-10-23/run.ps1' -TestName @('test_start_line','test_app','test_editor_placement_latency')\"",
    "powershell -ExecutionPolicy Bypass -Command \"& 'docs/evidence/editor-t05-t11-2026-10-23/run.ps1' -Graphical -Renderer gl_compatibility -TestName @('test_editor_t05_t11','test_editor_incremental_objects','test_editor_workflow')\"",
    "powershell -ExecutionPolicy Bypass -Command \"& 'docs/evidence/editor-t05-t11-2026-10-23/run.ps1' -Graphical -Renderer mobile -TestName @('test_editor_t05_t11','test_editor_incremental_objects','test_editor_preparation')\"",
    'powershell -ExecutionPolicy Bypass -File docs/evidence/editor-t05-t11-2026-10-23/run.ps1 -Graphical -Renderer gl_compatibility -TestName test_editor_t05_t11 -EngineVerbose',
    'powershell -ExecutionPolicy Bypass -File docs/evidence/editor-t05-t11-2026-10-23/run.ps1 -Graphical -Renderer mobile -TestName test_editor_t05_t11',
    'Godot_v4.7.2-stable_win64_console.exe --headless --path game --editor --import --quit (isolated APPDATA; import-final.log)',
    'Godot_v4.7.2-stable_win64_console.exe --path game --audio-driver Dummy --rendering-method mobile --script ../docs/evidence/editor-t05-t11-2026-10-23/pixel_probe.gd -- --same-source',
    'python docs/evidence/editor-t05-t11-2026-10-23/build_checkpoint.py',
    'python docs/evidence/editor-t05-t11-2026-10-23/build_report.py',
]

report = {'requirements':['T05','T06','T07','T08','T09','T10','T11','R01','Q01'],
          'engine':(ROOT/'godot-version.txt').read_text().strip(),
          'render_device':'Desktop NVIDIA GeForce RTX 3090; Compatibility OpenGL 3.3 and Mobile Vulkan',
          'environment':{'isolated_appdata':'build/editor-t05-t11/appdata','BMT_API_URL':'audit-disabled','audio_driver':'Dummy'},
          'scope':scope,'tests':tests,'measurements':measurements,'renders':renders,
          'commands':commands,'checkpoint':json.loads((OUT/'checkpoint.json').read_text()),
          'concurrency':{'snapshot_utc':datetime.now(timezone.utc).isoformat(),'scope':'Renderer/test receipts describe their executed sessions. The scoped foundation preserves independently changing App and race-builder code; this editor task does not claim validation of those independent changes.'},
          'source_manifest':'source-manifest.json','initial_corrections':'initial/corrections.json',
          'test_teardown':{'audio_retirement_seconds':0.25,'earlier_verbose_diagnostic':'initial/audio-verbose-identification.txt','production_audio_changed':False},
          'fixture_controls':{'same_originals':'mobile-identical-originals.log','shadow_isolation':'mobile-no-shadows.log',
                              'bounds_experiment':'mobile-lighting-bounds.log','rejected_mesh_consolidation':'mobile-single-craft-corrected.log',
                              'final_pixel_assertion':'zero channels, maximum zero, with exact lamp properties and common clock/rig'},
          'import':{'completed':all(token in read(OUT/'import-final.log') for token in ['first_scan_filesystem','loading_editor_layout']),
                    'exit_code':1,'bootstrap_diagnostic':'Windows root certificate store; no other import errors'},
          'limitations':['No phone attachment check, device test, APK, live backend/account mutation or deployment.',
                         'Cold shader driver calls and complex final-quality detail still exceed interactive frame targets.',
                         'No 20-30 minute physical-device thermal/PSS or input-hardware latency measurements.',
                         'Earlier graphical teardown retained existing menu Ogg playback/packet resources. The final harness waits 0.25 s for decoder retirement; production audio is unchanged.',
                         'Retained estimates exclude active/intermediate/driver/immutable-asset memory; current gesture backup references remain reserved until release.']}

artifacts = {}
for path in sorted(OUT.rglob('*')):
    if not path.is_file() or path.name in ['report.json','artifact-manifest.json']: continue
    artifacts[path.relative_to(OUT).as_posix()] = {'bytes':path.stat().st_size,'sha256':hashlib.sha256(path.read_bytes()).hexdigest()}
(OUT/'artifact-manifest.json').write_text(json.dumps(artifacts, indent=2))
(OUT/'report.json').write_text(json.dumps(report, indent=2))
for name, result in tests.items(): print(name, result['count'], result['unit'], result['assertion_failures'], 'failures', result['status'])
