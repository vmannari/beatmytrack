from pathlib import Path
import hashlib,json,re
root=Path.cwd(); work=root/'build/runtime-stall-investigation-2026-10-26'
source=(work/'before/game/core/app.gd').read_text(encoding='utf-8')
start=source.index('func _start_race(')
match=re.search(r'(?m)^func ',source[start+1:])
body=source[start:start+1+match.start()]
original=body
effect_source=(work/'before/game/vehicle/effect_render_preparation.gd').read_text(encoding='utf-8')
particle_end='\t\t\tprepared.particles += 1'
assert effect_source.count(particle_end)==1
effect_source=effect_source.replace('impact: TextureRect = null) -> Dictionary:','impact: TextureRect = null, draw: Callable = Callable()) -> Dictionary:')
effect_source=effect_source.replace(particle_end,particle_end+'\n\t\t\t# Diagnostic: finish the actual first-use draw before adding another emitter.\n\t\t\tif draw.is_valid(): await draw.call()')
(work/'staged_effect_preparation.gd').write_text(effect_source,encoding='utf-8')
targets=[
 ('\t\tNativeTrackVisual.ROAD_DISK_CACHE.publish_arrays(prepared_roads.get("receipt",{}))','publish_roads'),
 ('\tgame = GAME_SCENE.instantiate()','instantiate_game'),
 ('\t_prepare_race_rating(track)','prepare_rating'),
 ('\tadd_child(game)','attach_game'),
 ('\tgame.call("_prepare_personal_ghost")','personal_ghost'),
 ('\tgame.call("_process", 0.0)','initial_presentation'),
 ('\tvar finish_warmed: bool = prepared_finish.begin_render_warmup()','finish_begin'),
 ('\tif DisplayServer.get_name() != "headless": prepared_bridges = bridge_preparation.begin(game.get("track_ground"), game.get("camera"))','bridge_begin'),
 ('\tif DisplayServer.get_name() != "headless": prepared_hazards = bridge_preparation.begin_groups(game.get("track_ground"), game.get("camera"), ["race_hazard_rendering"])','hazard_begin'),
 ('\tvar prepared_trail: MultiMeshInstance3D = trail_preparation.begin(game.get("trails"), game.get("camera"), track, game.get("sim").state)','trail_begin'),
 ('\tvar prepared_effects: Dictionary = effect_preparation.begin(game.get_node("World"),game.get("sand_dust"),game.get("camera"),game.get("impact_cracks"))','effects_begin'),
 ('\tbridge_preparation.end(prepared_bridges)','bridge_end'),
 ('\tbridge_preparation.end(prepared_hazards)','hazard_end'),
 ('\tif is_instance_valid(prepared_trail): trail_preparation.end(prepared_trail)','trail_end'),
 ('\teffect_preparation.end(prepared_effects)','effects_end'),
 ('\tprepared_finish.end_render_warmup()','finish_end'),
 ('\t\tgame.call("_process", 0.0)','final_presentation'),
]
for line,name in targets:
    # Exact whole-line match avoids accidentally timing a nested occurrence twice.
    pattern=re.compile(r'(?m)^'+re.escape(line)+r'$')
    assert len(pattern.findall(body))==1,(name,len(pattern.findall(body)))
    indent=line[:len(line)-len(line.lstrip('\t'))]
    replacement=indent+'var trace_at_'+name+': int = Time.get_ticks_usec()\n'+indent+'trace_sink.mark("'+name+':begin")\n'+line+'\n'+indent+'trace_sink.span("'+name+'",trace_at_'+name+')'
    body=pattern.sub(lambda _:replacement,body,1)

body=body.replace('var finish_warmed: bool = prepared_finish.begin_render_warmup()',
                  'var finish_warmed: bool = false if "--skip-finish" in OS.get_cmdline_user_args() else prepared_finish.begin_render_warmup()')
body=body.replace('var prepared_effects: Dictionary = effect_preparation.begin(game.get_node("World"),game.get("sand_dust"),game.get("camera"),game.get("impact_cracks"))',
                  '''var prepared_effects: Dictionary
\tif "--skip-effects" in OS.get_cmdline_user_args():
\t\tprepared_effects = {"nodes":[],"restore":[],"particles":0,"batches":0,"damage_meshes":0,"canvas":0}
\telif "--stage-effects" in OS.get_cmdline_user_args():
\t\tprepared_effects = await preload("res://../build/runtime-stall-investigation-2026-10-26/staged_effect_preparation.gd").begin(game.get_node("World"),game.get("sand_dust"),game.get("camera"),game.get("impact_cracks"),_present_race_loading)
\telse:
\t\tprepared_effects = effect_preparation.begin(game.get_node("World"),game.get("sand_dust"),game.get("camera"),game.get("impact_cracks"))''')
body=body.replace('var prepared_trail: MultiMeshInstance3D = trail_preparation.begin(game.get("trails"), game.get("camera"), track, game.get("sim").state)',
                  'var prepared_trail: MultiMeshInstance3D = null if "--skip-trails" in OS.get_cmdline_user_args() else trail_preparation.begin(game.get("trails"), game.get("camera"), track, game.get("sim").state)')
after_effects='\ttrace_sink.span("effects_begin",trace_at_effects_begin)'
assert body.count(after_effects)==1
body=body.replace(after_effects,after_effects+'''
\tfor effect_index: int in range(prepared_effects.nodes.size()-1,-1,-1):
\t\tvar effect_node: Node = prepared_effects.nodes[effect_index]
\t\tif effect_node is GPUParticles3D and "--zero-preprocess" in OS.get_cmdline_user_args(): effect_node.preprocess = 0.0
\t\tif (effect_node is GPUParticles3D and "--skip-effect-particles" in OS.get_cmdline_user_args()) or (effect_node is CanvasItem and "--skip-effect-canvas" in OS.get_cmdline_user_args()):
\t\t\tprepared_effects.nodes.remove_at(effect_index)
\t\t\tif effect_node is GPUParticles3D: prepared_effects.particles -= 1
\t\t\tif effect_node is CanvasItem: prepared_effects.canvas -= 1
\t\t\teffect_node.free()
''')
body=body.replace('\teffect_preparation.end(prepared_effects)\n',
 '''\tif "--keep-effects" in OS.get_cmdline_user_args():
\t\tvar delayed: Array = prepared_effects.nodes
\t\tprepared_effects.nodes = []
\t\teffect_preparation.end(prepared_effects)
\t\tfor node: Node in delayed:
\t\t\tif node is Node3D or node is CanvasItem: node.hide()
\telse:
\t\teffect_preparation.end(prepared_effects)
''')
body=body.replace('OS.get_cmdline_user_args()','trace_ablation_flags')
wrapper=(work/'trace_app.gd').read_text(encoding='utf-8')
assert 'func _start_race(' not in wrapper
(work/'detailed_app.gd').write_text(wrapper.rstrip()+'\nvar trace_ablation_flags: PackedStringArray = OS.get_cmdline_user_args()\n\n'+body.rstrip()+'\n',encoding='utf-8')
(work/'copied-start-race.json').write_text(json.dumps({'source':'task-start App _start_race function','sha256':hashlib.sha256(original.encode()).hexdigest(),'instrumented_calls':[name for _,name in targets],'ablations':['--skip-effects','--skip-finish','--keep-effects','--zero-preprocess','--skip-effect-particles','--skip-effect-canvas','--skip-trails']},indent=2),encoding='utf-8')
print('Copied exact App method with',len(targets),'timing spans. Only diagnostic subclasses change.')
