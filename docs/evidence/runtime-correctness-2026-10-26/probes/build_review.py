from pathlib import Path
import difflib, hashlib, json, re, shutil, subprocess

ROOT = Path.cwd() if (Path.cwd()/'game/core/app.gd').exists() else Path(__file__).resolve().parents[2]
WORK = ROOT / 'build/runtime-correctness-2026-10-26'
OUT = ROOT / 'docs/evidence/runtime-correctness-2026-10-26'
BEFORE = WORK / 'before' if (WORK/'before').exists() else OUT/'before'
REVIEW = WORK / ('review-tree-'+str(len(list(WORK.glob('review-tree-*')))+1))

def read(path):
    return path.read_text(encoding='utf-8').replace('\r\n','\n')

def function(source, name):
    match = re.search(r'(?m)^(?:static )?func '+re.escape(name)+r'\(', source)
    assert match, name
    end = re.search(r'(?m)^(?:static )?func ', source[match.end():])
    stop = match.end()+end.start() if end else len(source)
    return source[match.start():stop]

def replace_once(source, old, new=''):
    assert source.count(old)==1, (old[:100],source.count(old))
    return source.replace(old,new,1)

def remove_function(source,name):
    return replace_once(source,function(source,name))

existing = ['game/core/app.gd','game/core/game.gd','game/backend/backend_client.gd',
 'game/backend/cloud_tracks.gd','game/backend/result_save_queue.gd','game/race/input_record.gd',
 'game/race/attempt_evidence.gd','game/race/personal_ghost_run.gd','game/editor/editor_memory.gd',
 'game/ui/garage_preview_cache.gd','game/ui/race_results.gd','game/track/native_track_visual.gd','game/track/prepared_world_cache.gd',
 'game/track/winter_road_snow_sources.gd','game/race/race_ground_preparation.gd',
 'game/vehicle/car_visual.gd','game/vehicle/visual_geometry.gd','game/vehicle/compact_detail.gd','game/vehicle/compact_front_lamps.gd',
 'game/tests/test_mobile_audit_fixes.gd','game/tests/test_editor_practice.gd',
 'game/tests/test_gameplay_f13_f16_f19_f24.gd','game/tests/test_track_rating_prompt.gd',
 'game/tests/test_challenge_race_flows.gd','game/tests/test_challenge_result_action.gd',
 'game/tests/test_rivalry_start_failure.gd','game/tests/review_backend_exceptions.gd',
 'game/tests/test_storm_editor_workflow.gd','docs/RUNTIME_MEMORY_CORRECTNESS_TASKS_2026_10_26.md',
 'AGENTS.md','DEVELOPMENT_STATUS.md']
new = ['game/backend/completed_evidence.gd','game/race/world_render_preparation.gd',
 'game/tests/test_runtime_result_safety.gd',
 'game/tests/profile_runtime_correctness.gd','game/tests/soak_runtime_correctness.gd',
 'game/tests/test_result_crash_process.gd','game/tests/test_runtime_render_lifecycle.gd',
 'game/tests/test_cooperative_car_model.gd','game/tests/test_result_recording_limit.gd','game/assets/news/vehicles/forklift.png',
 'docs/RUNTIME_MEMORY_CORRECTNESS_FIXES_2026_10_26.md',
 'docs/evidence/runtime-correctness-2026-10-26/commands.txt']

baseline = {}
for path in existing:
    now = read(ROOT/path)
    old = read(BEFORE/path) if (BEFORE/path).exists() else now
    base = old
    if path in ['AGENTS.md','DEVELOPMENT_STATUS.md']:
        base=re.sub(r'<!-- RUNTIME-CORRECTNESS-FIXES-20261026 -->.*?<!-- /RUNTIME-CORRECTNESS-FIXES-20261026 -->\n\n','',now,flags=re.S)
        assert base != now, path
    elif path.endswith('/app.gd'):
        base=now
        for name in ['_garage_residency','_trim_hidden_garage','_result_capacity_available']:
            base=remove_function(base,name)
        for line in ['var race_profile_enabled: bool = false\n',
            '\tif online.client.signed_in() and not _result_capacity_available(): return\n',
            '\t\tif not _result_capacity_available(): return\n',
            '\tif not _result_capacity_available(): return\n',
            '\tif is_instance_valid(_retained_garage.get("_preview_service")): _retained_garage._preview_service.suspend_previews()\n',
            '\tgame.profile_enabled = race_profile_enabled\n']:
            base=replace_once(base,line)
        base=replace_once(base,'screen == "create" or is_instance_valid(_retained_garage) or editor_memory.pressure_requested','screen == "create" or editor_memory.pressure_requested')
        # A concurrent Garage free-drive entry now uses the same staging helper.
        # Reverse only this task's ordinary-race block, inside its exact function.
        race=function(base,'_start_race')
        start=race.index('\tif is_instance_valid(prepared_game.world_render_preparation):')
        end=race.index('\tif rivalry_racing:',start)
        base=replace_once(base,race,race[:start]+race[end:])
        current='\tvar night_preparation: Dictionary = {"drawn":false,"items":0,"contexts":0,"sets":0,"elapsed_ms":0.0,"truncated":0,"light_limit":false}\n\tif is_instance_valid(prepared_game) and game == prepared_game:\n\t\tnight_preparation = await _prepare_night_lighting(loading_id, prepared_game)'
        base=replace_once(base,current,'\tvar night_preparation: Dictionary = await _prepare_night_lighting(loading_id, prepared_game)')
        save=function(base,'_save_result_upload')
        previous=save.replace('frames: Variant','frames: Array').replace('\tticket_data = ticket_data.duplicate()\n','').replace('ticket_data["_race_ghost_source"] = completed_game.ghost_run.snapshot_for_save()','ticket_data["_race_ghost"] = completed_game.ghost_run.recording("race")')
        base=replace_once(base,save,previous)
        start=base.index('\tvar local_result_notice: String = ""')
        end=base.index('\tvar online_queued:',start)
        base=base[:start]+base[end:]
        base=replace_once(base,'\tpanel.verification_notice = local_result_notice\n')
        changed={'_process','_start_challenge_race','_start_rivalry_race','_park_garage',
                 '_garage_residency','_trim_hidden_garage','_start_race',
                 '_save_result_upload','_results','_result_capacity_available','_retry_race'}
        for name in re.findall(r'(?m)^func (\w+)\(',base):
            if name not in changed:
                assert function(base,name).strip()==function(now,name).strip(),('Unexpected concurrent App change',name)
    elif path.endswith('/game.gd'):
        # Preserve the concurrently added practice-route admission guard.
        external='\tvar authored: Dictionary = native_track.metadata.get("creator_document",{}) if native_track!=null else {}\n\tpractice_validation_eligible = authored.has("start_line") and RoadPieces.route_from_pieces(authored).ok'
        assert external in now
        base=replace_once(old,'\tpractice_validation_eligible = true',external)
    elif path.endswith('/cloud_tracks.gd'):
        base=now
        for name in ['enqueue_completed','_discover_pending','_write_file','_submission_ticket']:
            base=replace_once(base,function(base,name),function(old,name))
        base=remove_function(base,'_recover_staged')
        previous=function(old,'_queue_run_io')
        # The non-improving-result task added claims while this task was active.
        claims='\tif int(ticket_data.get("_wire_options",{}).get("result",0)) == 1 and ticket_data.get("_claimed_lap_ticks") is Array:\n\t\trecording.claimed_lap_ticks = ticket_data._claimed_lap_ticks\n'
        assert claims in now
        previous=replace_once(previous,'\tvar replay_hash:',claims+'\tvar replay_hash:')
        base=replace_once(base,function(base,'_queue_run_io'),previous)
        for name in ['queue_run','queue_run_async']:
            current=function(base,name)
            base=replace_once(base,current,current.replace('frames: Variant','frames: Array',1))
        release='\tif not packet.is_empty():\n\t\t# The normalized wire packet owns what remains necessary. Release the\n\t\t# larger decoded proof before serialization/network waits overlap a save.\n\t\tloaded = {}\n\t\tresponse = await client.request_api("/runs",HTTPClient.METHOD_POST,{"ticket_id":str(job.ticket),"replay":packet},str(job.key),true)'
        base=replace_once(base,release,'\tif not packet.is_empty(): response = await client.request_api("/runs",HTTPClient.METHOD_POST,{"ticket_id":str(job.ticket),"replay":packet},str(job.key),true)')
    elif path.endswith('/backend_client.gd'):
        base=replace_once(now,'var _background_busy: bool = false\n')
        base=replace_once(base,function(base,'_background'),function(old,'_background'))
    elif path.endswith('/personal_ghost_run.gd'):
        base=remove_function(now,'snapshot_for_save')
    elif path.endswith('/race_ground_preparation.gd'):
        start=now.index('\t# Canonical gate construction')
        end=now.index('\tvar cover:',start)
        base=now[:start]+now[end:]
    elif path.endswith('/winter_road_snow_sources.gd'):
        base=now
        for line in ['const MAX_CACHE_BYTES: int = 8 * 1024 * 1024\n','static var entries: Array[Dictionary] = []\n','static var cache_bytes: int = 0\n']:
            base=replace_once(base,line)
        start=base.index('\tvar key: Array = [track.content_hash,')
        end=base.index('\tvar pieces:',start)
        base=base[:start]+base[end:]
        start=base.index('\t# CPU pixels plus decoded GPU texture')
        end=base.index('func bind(',start)
        base=base[:start]+'\n'+base[end:]
    elif path.endswith('/test_mobile_audit_fixes.gd'):
        base=now.replace('var compact := PackedInt64Array()','var compact: Array = []').replace('compact.resize(compact.size()-1)','compact.pop_back()')
        base=replace_once(base,'\t\twhile page._preview_service.worker != null or not page._preview_service.queued.is_empty(): await frames(1)\n')
        start=base.index('\t\tmetrics.preview_readback_us')
        end=base.index('\tvar retained:',start)
        base=base[:start]+base[end:]
    elif path.endswith('/test_editor_practice.gd'):
        base=replace_once(now,'var frames: PackedInt64Array = game.get("online_frames").duplicate()','var frames: Array = game.get("online_frames").duplicate(true)')
    elif path.endswith('/test_gameplay_f13_f16_f19_f24.gd'):
        base=now.replace('_frames: Variant','_frames: Array').replace('game.online_frames.fill(preload("res://race/input_record.gd").pack(DriveFrame.new()))','game.online_frames.fill(DriveFrame.new().packed())')
    elif path.endswith('/test_track_rating_prompt.gd'):
        base=now.replace('_frames: Variant','_frames: Array').replace('game.online_frames.append(preload("res://race/input_record.gd").pack(frame))','game.online_frames.append([frame.steer,frame.throttle,frame.brake])')
    elif path.endswith('/test_challenge_race_flows.gd'):
        base=now.replace('_frames: Variant','_frames: Array')
        guard='\tif app.game == null:\n\t\tprint("START_FAILURE cloud=",app.cloud.last_error," challenge=",app.challenges.error)\n\t\tquit(1)\n\t\treturn\n'
        base=replace_once(base,guard)
        start=base.index('\t# Storage reservations must precede')
        end=base.index('\tapp.queue_free()',start)
        base=base[:start]+base[end:]
    elif path.endswith('/test_challenge_result_action.gd') or path.endswith('/review_backend_exceptions.gd'):
        base=now.replace('_frames: Variant','_frames: Array')
    elif path.endswith('/test_rivalry_start_failure.gd'):
        previous='\tvar values: Dictionary = {}\n\tfor property: Dictionary in config.get_property_list():\n\t\tif int(property.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE: values[str(property.name)] = config.get(str(property.name))'
        base=replace_once(now,'\tvar values: Dictionary = config.snapshot()',previous)
    elif path.endswith('/test_storm_editor_workflow.gd'):
        base=now.replace('var OUTPUT: String =','const OUTPUT: String =',1)
        base=replace_once(base,'\tfor argument: String in OS.get_cmdline_user_args():\n\t\tif argument.begins_with("--output="): OUTPUT = argument.trim_prefix("--output=")\n')
    elif path.endswith('/RUNTIME_MEMORY_CORRECTNESS_TASKS_2026_10_26.md'):
        base=replace_once(now,'\nImplementation follow-up: [26 October fixes and actual validation](RUNTIME_MEMORY_CORRECTNESS_FIXES_2026_10_26.md). The original investigation list below is retained; the follow-up distinguishes completed code/checks from remaining cold-load and physical-device acceptance.\n')
    raw=(ROOT/path).read_bytes()
    raw_lines=raw.splitlines(keepends=True)
    base_lines=base.splitlines()
    current_lines=now.splitlines()
    ending=b'\r\n' if raw.count(b'\r\n')>raw.count(b'\n')/2 else b'\n'
    encoded=[line.encode('utf-8')+ending for line in base_lines]
    for tag,a,b,c,d in difflib.SequenceMatcher(None,base_lines,current_lines,autojunk=False).get_opcodes():
        if tag=='equal': encoded[a:b]=raw_lines[c:d]
    baseline[path]=b''.join(encoded)

for path in list(new):
    uid=path+'.uid'
    if (ROOT/uid).is_file(): new.append(uid)

REVIEW.mkdir(parents=True,exist_ok=True)
assert not (REVIEW/'.git').exists(), 'Use a fresh review directory when regenerating.'
subprocess.run(['git','init','--quiet',str(REVIEW)],check=True)
subprocess.run(['git','-C',str(REVIEW),'config','core.autocrlf','false'],check=True)
subprocess.run(['git','-C',str(REVIEW),'config','core.whitespace','cr-at-eol'],check=True)
for path,data in baseline.items():
    dest=REVIEW/path; dest.parent.mkdir(parents=True,exist_ok=True); dest.write_bytes(data)
subprocess.run(['git','-C',str(REVIEW),'add','.'],check=True)
for path in existing+new:
    dest=REVIEW/path; dest.parent.mkdir(parents=True,exist_ok=True); shutil.copyfile(ROOT/path,dest)
subprocess.run(['git','-C',str(REVIEW),'add','-N','--',*new],check=True)
patch=subprocess.check_output(['git','-C',str(REVIEW),'diff','--binary','--no-ext-diff','--no-color'])
subprocess.run(['git','-C',str(REVIEW),'diff','--check'],check=True)
OUT.mkdir(parents=True,exist_ok=True); (OUT/'checkpoint.patch').write_bytes(patch)
subprocess.run(['git','-C',str(REVIEW),'apply','--reverse','--check',str(OUT/'checkpoint.patch')],check=True)
subprocess.run(['git','-C',str(REVIEW),'apply','--reverse',str(OUT/'checkpoint.patch')],check=True)
for path,data in baseline.items(): assert (REVIEW/path).read_bytes()==data,path
subprocess.run(['git','-C',str(REVIEW),'apply','--check',str(OUT/'checkpoint.patch')],check=True)
subprocess.run(['git','-C',str(REVIEW),'apply',str(OUT/'checkpoint.patch')],check=True)
rows=[]
for path in existing+new:
    data=(ROOT/path).read_bytes(); assert (REVIEW/path).read_bytes()==data,path
    rows.append({'path':path,'sha256':hashlib.sha256(data).hexdigest(),'bytes':len(data)})
(OUT/'source-manifest.json').write_text(json.dumps(rows,indent=2),encoding='utf-8')
print('Verified scoped patch:',len(rows),'files,',len(patch),'bytes. Concurrent App/Cloud/Game changes preserved.')
