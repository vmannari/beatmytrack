"""Create a task-owned profiling client from the exact installed source snapshot."""
import hashlib
import json
from pathlib import Path
import shutil
import subprocess

ROOT = Path(__file__).resolve().parents[3]
OUT = ROOT/'build/tablet-phase-profile-20261107'
EVIDENCE = Path(__file__).resolve().parent
BASE_ROOT = ROOT/'build/race-verification-speed-20261107/frozen'
BASE = BASE_ROOT/'game'
owned = OUT/'isolated-current'
game = owned/'game'
if (EVIDENCE/'instrumentation.json').exists():
    old = json.loads((EVIDENCE/'instrumentation.json').read_text())
    for path,row in old['changed'].items():
        assert hashlib.sha256((game/path).read_bytes()).hexdigest()==row['after'],path
    shutil.copyfile(EVIDENCE/'instrumentation.json',EVIDENCE/'instrumentation-initial.json')
    for path in old['changed']:
        shutil.copyfile(BASE/path,game/path)
if not owned.exists():
    source = (ROOT/'docs/evidence/loading-half-2026-11-06/freeze_project.py').read_text()
    source = source.replace('evidence = Path(__file__).resolve().parent','evidence = EVIDENCE')
    source = source.replace("owned = root/'build/loading-half-20261106'/('frozen-'+str(time.time_ns()))","owned = OUT/'isolated-current'")
    source = source.replace("for name in ('docs','native'):","for name in ('docs',):")
    for old,new in [("root/'game/.godot/imported'","BASE/'.godot/imported'"),
                    ("root/'game/.godot'","BASE/'.godot'"),("root/'game/assets'","BASE/'assets'"),("root/'game'",'BASE')]:
        source = source.replace(old,new)
    exec(compile(source,'freeze_project.py','exec'),globals())
    for name in ['scripts','native','backend']:
        shutil.copytree(BASE_ROOT/name,owned/name,dirs_exist_ok=True,
                        ignore=shutil.ignore_patterns('var','build','__pycache__','.pytest_cache','.ruff_cache'))
    for name in ['.gitignore','.gitattributes','godot-version.txt']:
        if (BASE_ROOT/name).exists(): shutil.copyfile(BASE_ROOT/name,owned/name)
    destination = owned/'.tools/admob/android_source.zip'
    destination.parent.mkdir(parents=True)
    shutil.copyfile(BASE_ROOT/'.tools/admob/android_source.zip',destination)
    subprocess.run(['git','init','--quiet',str(owned)],check=True)
before = {}
changes = {}


def edit(path):
    before[path] = (BASE/path).read_bytes()
    return before[path].decode().replace('\r\n','\n')


def once(text,old,new):
    assert text.count(old)==1,(old,text.count(old))
    return text.replace(old,new,1)


trace = 'const TabletTrace = preload("res://diagnostics/tablet_phase_trace.gd")\n'
path = 'core/app.gd'
text = edit(path)
text = once(text,'extends Node\n','extends Node\n'+trace)
text = once(text,'func _ready() -> void:\n','func _ready() -> void:\n\tTabletTrace.mark("app_ready_begin")\n\tif TabletTrace.active():\n\t\tvar profiler: Node = load("res://diagnostics/tablet_phase_probe.gd").new()\n\t\tprofiler.app = self\n\t\tadd_child(profiler)\n')
ready_end = text.index('\nfunc _show_screen(')
startup = text[:ready_end]
for old,label in [('\t_show_screen("restoring")','app_local_setup_end'),
                  ('\tif capture_path.is_empty(): await online.start_session()','account_wait_begin'),
                  ('\tif active_profile.is_empty(): _restore_selected_track(startup_fallback)','account_wait_end'),
                  ('\tGameSoundtrack.instance().show_menu()\n\t_garage_preloader=','menu_audio_begin')]:
    startup = once(startup,old,'\tTabletTrace.mark("'+label+'")\n'+old)
text = startup+text[ready_end:]
text = once(text,'\tprint("APP_READY")','\tTabletTrace.mark("app_ready_end")\n\tprint("APP_READY")')
text = once(text,'\t\tvar began: int = Time.get_ticks_usec()\n\t\t_install_feature_resource(path,load(path))',
            '\t\tvar began: int = Time.get_ticks_usec()\n\t\tTabletTrace.mark("feature_begin",{"path":path})\n\t\t_install_feature_resource(path,load(path))\n\t\tTabletTrace.mark("feature_end",{"path":path,"ms":(Time.get_ticks_usec()-began)/1000.0})')
text = once(text,'func _initial_menu_drawn() -> void:\n','func _initial_menu_drawn() -> void:\n\tTabletTrace.mark("initial_menu_drawn")\n')
text = once(text,'func _telemetry_begin_attempt(track: NativeTrack) -> void:\n','func _telemetry_begin_attempt(track: NativeTrack) -> void:\n\tif TabletTrace.practice:\n\t\t_telemetry_race_started = false\n\t\t_telemetry_race_finished = true\n\t\treturn\n')
text = once(text,'func _telemetry_observe(name: String, properties: Dictionary = {}, once_key: String = "") -> void:\n',
            'func _telemetry_observe(name: String, properties: Dictionary = {}, once_key: String = "") -> void:\n\tif TabletTrace.practice: return\n')
changes[path] = text

path = 'backend/account_controller.gd'
text = edit(path).replace('extends Node\n','extends Node\n'+trace,1)
start = text.index('func start_session()')
end = text.index('\nfunc player_name()',start)
body = text[start:end]
body = once(body,'\tvar result: Dictionary = await _check_service()','\tTabletTrace.mark("bootstrap_begin")\n\tvar result: Dictionary = await _check_service()\n\tTabletTrace.mark("bootstrap_end",{"ok":result.get("ok",false)})')
body = once(body,'\t\tresult = await client.restore_session()','\t\tTabletTrace.mark("session_begin")\n\t\tresult = await client.restore_session()\n\t\tTabletTrace.mark("session_end",{"ok":result.get("ok",false)})')
text = text[:start]+body+text[end:]
changes[path] = text

path = 'backend/backend_client.gd'
text = edit(path).replace('extends Node\n','extends Node\n'+trace,1)
text = once(text,'func _profile_request(path: String, phase: String, start: int) -> void:\n',
            'func _profile_request(path: String, phase: String, start: int) -> void:\n\tTabletTrace.network(path,phase,start)\n')
changes[path] = text

path = 'core/features/race.gd'
text = edit(path).replace('extends Node\n','extends Node\n'+trace,1)
start = text.index('func run_start_race(app:')
end = text.index('\nfunc run_race_installation_current(',start)
body = text[start:end]
hooks = [('\tif not await app._await_selected_preparation(track,','selected_wait_begin'),
         ('\tvar daily_rules: RefCounted','selected_wait_end'),
         ('\tvar prepared_roads: Dictionary = {}','roads_begin'),
         ('\tapp.returning_to_editor = from_editor','roads_end'),
         ('\tapp.add_child(app.game)\n\tvar prepared_game: Node = app.game','game_begin'),
         ('\tif is_instance_valid(prepared_game.world_render_preparation):','game_end'),
         ('\t\tif not await prepared_game.world_render_preparation.prepare(','graphics_begin'),
         ('\tapp.game.opponent_ghost =','graphics_end'),
         ('\tvar preparation_started: int = Time.get_ticks_usec()','effects_begin'),
         ('\tvar preparation_ms: float = (Time.get_ticks_usec() - preparation_started)','effects_end'),
         ('\tapp._close_race_loading(loading_id)\n','race_end')]
# The final close is unique only within the final successful tail.
hooks = [hook for hook in hooks if hook[1]!='race_end']
for needle,label in hooks:
    indent = '\t\t' if needle.startswith('\t\t') else '\t'
    body = once(body,needle,indent+'TabletTrace.mark("'+label+'")\n'+needle)
body = once(body,'if not from_editor and not tutorial_lesson and app.records.settings.get("last_track","") != track.identity:',
            'if not TabletTrace.practice and not from_editor and not tutorial_lesson and app.records.settings.get("last_track","") != track.identity:')
body = once(body,'\tapp.game.set("resume_client",null if tutorial_lesson else app.online.client)',
            '\tapp.game.set("resume_client",null if tutorial_lesson or TabletTrace.practice else app.online.client)')
body = once(body,'\tapp.game.set("shader_telemetry", app.product_telemetry)',
            '\tapp.game.set("shader_telemetry", null if TabletTrace.practice else app.product_telemetry)')
body = once(body,'\tapp.game.profile_enabled = app.race_profile_enabled',
            '\tapp.game.profile_enabled = app.race_profile_enabled\n\tif TabletTrace.practice: app.game.hitch_diagnostics_enabled = false')
body = once(body,'if app.race_ad_breaks != null and not tutorial_lesson and not app.returning_to_editor',
            'if not TabletTrace.practice and app.race_ad_breaks != null and not tutorial_lesson and not app.returning_to_editor')
tail = '\tapp.cloud_starting = false\n\tapp._close_race_loading(loading_id)\n'
body = once(body,tail,tail+'\tTabletTrace.mark("race_end")\n')
text = text[:start]+body+text[end:]
assert text.count('app.game.set("preference_records", app.records)')==1
text = text.replace('app.game.set("preference_records", app.records)',
                    'app.game.set("preference_records", TabletTrace.practice_records if TabletTrace.practice else app.records)')
assert text.count('app.game.set("preference_records",app.records)')==1
text = text.replace('app.game.set("preference_records",app.records)',
                    'app.game.set("preference_records",TabletTrace.practice_records if TabletTrace.practice else app.records)')
text = once(text,'func run_prepare_race_rating(app: Node, track: NativeTrack) -> void:\n',
            'func run_prepare_race_rating(app: Node, track: NativeTrack) -> void:\n\tif TabletTrace.practice: return\n')
changes[path] = text

path = 'ui/garage_preloader.gd'
text = edit(path).replace('extends Node\n','extends Node\n'+trace,1)
text = once(text,'func take() -> Control:\n','func take() -> Control:\n\tTabletTrace.mark("garage_preloader_take",{"has_studio":is_instance_valid(studio),"prepared":studio.prepared if is_instance_valid(studio) else false,"draws":studio.warm_draws if is_instance_valid(studio) else 0})\n')
for old in ['\t\tPictures = load(PICTURE_SCRIPT)','\tPictures = load(PICTURE_SCRIPT)']:
    indent = '\t\t' if old.startswith('\t\t') else '\t'
    text = once(text,'\n'+old+'\n','\n'+indent+'TabletTrace.mark("picture_script_begin")\n'+old+'\n'+indent+'TabletTrace.mark("picture_script_end")\n')
changes[path] = text

for path,text in changes.items():
    destination = EVIDENCE/'before'/path
    destination.parent.mkdir(parents=True,exist_ok=True)
    destination.write_bytes(before[path])
    (game/path).write_text(text,encoding='utf-8',newline='\n')
for name in ['tablet_phase_trace.gd','tablet_phase_probe.gd']:
    shutil.copyfile(EVIDENCE/name,game/'diagnostics'/name)
oval = json.loads((BASE_ROOT/'backend/tests/fixtures/verified_oval.json').read_text())['document']
star = json.loads((BASE/'tests/fixtures/star_spline_lap.json').read_text())
tracks = 'extends RefCounted\nconst OVAL: String = '+json.dumps(json.dumps(oval,separators=(',',':')))+'\nconst STAR: String = '+json.dumps(json.dumps(star,separators=(',',':')))+'\nstatic func document(fixture: String) -> Dictionary:\n\treturn JSON.parse_string(STAR if fixture == "star" else OVAL)\n'
(game/'diagnostics/tablet_phase_tracks.gd').write_text(tracks)
receipt = {'project':str(game),'baseline':str(BASE),'changed':{
    path:{'before':hashlib.sha256(before[path]).hexdigest(),'after':hashlib.sha256((game/path).read_bytes()).hexdigest()} for path in changes}}
(EVIDENCE/'instrumentation.json').write_text(json.dumps(receipt,indent=2)+'\n')
print(json.dumps({'project':str(game),'instrumented_files':len(changes)}),flush=True)
