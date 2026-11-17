"""Timestamp observers in the independent review snapshot only."""
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PROJECT = ROOT/"build/loading-review-2026-11-17/snapshot/game"
OUT = ROOT/"docs/evidence/loading-review-2026-11-17"
HELPER = '''
static func _review_mark(label: String) -> void:
	var events: Array = Engine.get_meta("loading_review_events",[])
	events.append({"label":label,"us":Time.get_ticks_usec()})
	Engine.set_meta("loading_review_events",events)
'''

def unique(source, old, new):
    assert source.count(old) == 1, (source.count(old), old)
    return source.replace(old, new)

def hooks(source, start, end, anchors):
    first = source.index(start)
    last = source.index(end, first+len(start))
    body = source[first:last]
    for anchor, label in anchors:
        indent = anchor[:len(anchor)-len(anchor.lstrip("\t"))]
        body = unique(body,anchor,indent+'_review_mark("'+label+'")\n'+anchor)
    return source[:first]+body+source[last:]

changes = {}
source = (PROJECT/"core/app.gd").read_text(encoding="utf-8")
anchor = '\t\t_install_feature_resource(path,load(path))'
source = unique(source,anchor,'\t\t_review_mark("feature_begin:"+path)\n'+anchor+'\n\t\t_review_mark("feature_end:"+path)')
changes["core/app.gd"] = source+HELPER

source = (PROJECT/"core/features/race.gd").read_text(encoding="utf-8")
source = hooks(source,"func run_start_race(app:","\nfunc run_race_installation_current(",[
    ('\tif not await app._await_selected_preparation(track,','selected_wait_begin'),
    ('\tvar daily_rules: RefCounted','selected_wait_end'),
    ('\tvar prepared_roads: Dictionary = {}','roads_begin'),
    ('\tapp.returning_to_editor = from_editor','roads_end'),
    ('\tapp.game = app.GAME_SCENE.instantiate()','game_instantiate'),
    ('\tapp.add_child(app.game)\n\tvar prepared_game: Node = app.game','game_ready_begin'),
    ('\tif is_instance_valid(prepared_game.world_render_preparation):','game_ready_end'),
    ('\t\tif not await prepared_game.world_render_preparation.prepare(','graphics_begin'),
    ('\tapp.game.opponent_ghost =','graphics_end'),
    ('\tvar prepared_finish: VehicleWeathering','finish_setup_begin'),
    ('\tvar preparation_started: int = Time.get_ticks_usec()','effects_begin'),
    ('\tvar effects_drawn: bool =','effects_end'),
    ('\tvar night_preparation: Dictionary =','finish_draw_end'),
    ('\tapp.game.set("weathering_prepared", finish_drawn)','clean_draw_end'),
])
changes["core/features/race.gd"] = source+HELPER

source = (PROJECT/"core/game.gd").read_text(encoding="utf-8")
source = hooks(source,"func _build_ground(world:","\nfunc ",[
    ('\t\tif cooperative_preparation:','ground_worker_begin'),
    ('\t\tif bridge_presentation == null:','ground_worker_end'),
    ('\t\tsim.prepare_ground(native_track,bridge_presentation)','simulation_ground_begin'),
    ('\t\tvisual.build_current = _preparation_is_current','simulation_ground_end'),
    ('\t\tvar restored: bool = await visual.restore(','world_restore_begin'),
    ('\t\tif not restored:','world_restore_end'),
    ('\t\t\tawait visual.build(','world_build_begin'),
    ('\t\tif not _preparation_is_current() or not visual.world_built: return','world_finished'),
])
changes["core/game.gd"] = source+HELPER

source = (PROJECT/"race/world_render_preparation.gd").read_text(encoding="utf-8")
anchor = '\t\tvar drawn: bool = await draw.call()'
source = unique(source,anchor,'\t\t_review_mark("world_draw_begin")\n'+anchor+'\n\t\t_review_mark("world_draw_end")')
changes["race/world_render_preparation.gd"] = source+HELPER

source = (PROJECT/"tests/profile_loading_fixes.gd").read_text(encoding="utf-8")
source = unique(source,'\t\tbegan = Time.get_ticks_usec()\n\t\tawait app._start_race', '\t\tEngine.set_meta("loading_review_events",[])\n\t\tbegan = Time.get_ticks_usec()\n\t\tawait app._start_race')
source = unique(source,'\t\tcheck(is_instance_valid(app.game),"actual race installed")','\t\tvar review_events: Array = Engine.get_meta("loading_review_events",[]).duplicate(true)\n\t\tcheck(is_instance_valid(app.game),"actual race installed")')
source = unique(source,'"cycle":cycle,"ready_ms":elapsed,','"cycle":cycle,"ready_ms":elapsed,"events":review_events,\n\t\t\t"render_draw_max_us":game.world_render_preparation.draw_us_max,')
changes["tests/profile_loading_fixes.gd"] = source

manifest = {}
for relative, source in changes.items():
    path = PROJECT/relative
    original = path.read_bytes()
    backup = OUT/"instrumentation-originals"/relative
    backup.parent.mkdir(parents=True,exist_ok=True)
    assert not backup.exists(), relative
    backup.write_bytes(original)
    manifest[relative] = {"original":hashlib.sha256(original).hexdigest(),"instrumented":hashlib.sha256(source.encode()).hexdigest()}
    path.write_text(source,encoding="utf-8",newline="\n")
(OUT/"instrumentation.json").write_text(json.dumps(manifest,indent=2))
print(json.dumps(dict(instrumented=list(changes))))
