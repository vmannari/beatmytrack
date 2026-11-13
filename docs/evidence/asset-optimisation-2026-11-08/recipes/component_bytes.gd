extends SceneTree
const Packing=preload("res://rendering/mesh_vertex_packing.gd")
const Metrics=preload("res://../build/asset-review-2026-11-08/metrics.gd")
var rows: Array=[]
func _initialize()->void:run.call_deferred()
func record(label: String,a: ArrayMesh,b: ArrayMesh)->void:
	var old: Dictionary=Metrics.mesh_info(a);var now: Dictionary=Metrics.mesh_info(b)
	var row: Dictionary={"asset":label,"before":old,"after":now};rows.append(row)
	print("COMPONENT_BYTES ",label," ",old.raw_gpu_buffer_bytes," -> ",now.raw_gpu_buffer_bytes)
func run()->void:
	for kind: String in ["tree","fence","rock","bush"]:
		WinterScenery.meshes.clear();Packing.enabled=false;var a: ArrayMesh=WinterScenery.mesh_for(kind,-1,false)
		WinterScenery.meshes.clear();Packing.enabled=true;record("winter-"+kind,a,WinterScenery.mesh_for(kind,-1,false))
	for theme: String in ["pine","winter"]:
		var fixture:=NativeTrack.new();fixture.metadata={"creator_document":{"objects":[{"kind":"tyre_wall","position":[0,0],"rotation":0}]}};fixture.tyre_origins=LooseTyres.positions(fixture.metadata.creator_document)
		var a:=NativeTrackVisual.new();a.theme_id=theme;a.scenery_lods=false;await a._build_placed_objects(fixture)
		var b:=NativeTrackVisual.new();b.theme_id=theme;b.scenery_lods=true;await b._build_placed_objects(fixture)
		record(theme+"-tyre-wall-including-distance-level",a.tyre_instances.multimesh.mesh,b.tyre_instances.multimesh.mesh);a.free();b.free()
	FileAccess.open("res://../docs/evidence/asset-optimisation-2026-11-08/component-bytes.json",FileAccess.WRITE).store_string(JSON.stringify(rows,"\t"))
	quit()
