extends SceneTree
const Existing=preload("res://tests/test_race_loading_optimisation.gd")
const Worlds=preload("res://track/prepared_world_cache.gd")
const Roads=preload("res://editor/road_preparation.gd")
const Memory=preload("res://editor/editor_memory.gd")
var checks: int=0
var failures: int=0
func _initialize() -> void: run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error(label)
func mesh(vertices: int) -> ArrayMesh:
	var points:=PackedVector3Array(); points.resize(vertices)
	for i: int in range(vertices): points[i]=Vector3(i%3,0,(i/3)%3)
	var arrays: Array=[]; arrays.resize(Mesh.ARRAY_MAX); arrays[Mesh.ARRAY_VERTEX]=points
	var result:=ArrayMesh.new(); result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	return result
func run() -> void:
	Worlds.trim_cache(); NativeTrackVisual.trim_editor_cache()
	var owner:=Existing.MemoryOwner.new(); root.add_child(owner)
	var visual:=NativeTrackVisual.new(); root.add_child(visual)
	var shared: ArrayMesh=mesh(3)
	var part:=MeshInstance3D.new(); part.mesh=shared; visual.add_child(part)
	var track:=NativeTrack.new(); track.metadata={"theme":"winter"}
	Worlds.remember(["selected-winter","visual","contact","props","winter",[],true],visual,track)
	var environment:=Environment.new(); var sun:=DirectionalLight3D.new()
	TrackTheme.apply_lighting("winter",environment,sun)
	var sky: Sky=environment.sky
	var independent: ArrayMesh=mesh(3000)
	NativeTrackVisual._road_mesh_cache.assign([
		{"key":["shared"],"meshes":[{"mesh":shared}],"bytes":288,"geometry_key":"shared"},
		{"key":["independent"],"meshes":[{"mesh":independent}],"bytes":288000,"geometry_key":"independent"}])
	Roads.account_gpu(NativeTrackVisual._road_mesh_cache)
	var data:=PackedByteArray(); data.resize(512*1024)
	Roads.section_write("clip/old",data); Roads.section_write("piece/new",data)
	var before: Dictionary=Memory.retained(owner)
	# Synthetic reservation, as in the retained arbitration fixture: only the
	# pressure estimate is inflated, never claimed as an actual RAM measurement.
	Worlds.entries[0].bytes+=Memory.RETAINED_BUDGET-int(before.retained_bytes)+int(before.road_section_bytes)+100000
	check(Memory.retained(owner).retained_bytes>Memory.RETAINED_BUDGET,"fixture exceeds the real unchanged retention allowance")
	var manager:=Memory.new(); manager.tick(owner)
	check(Worlds.entries.size()==1,"ordinary trim retains the expensive completed scene")
	check(TrackTheme.winter_reflection_sky==sky and environment.sky==sky,"ordinary retention keeps the exact Winter reflection sky")
	check(Roads.residency().sections==0,"cheap CPU intermediates retire first")
	check(NativeTrackVisual._road_mesh_cache.size()==1 and NativeTrackVisual._road_mesh_cache[0].geometry_key=="shared","private road buffers retire while exact shared aliases remain")
	check(Worlds.shared_road_bytes(NativeTrackVisual._road_mesh_cache)==288,"shared accounting has no phantom freed buffers")
	check(part.mesh==shared and part.visible,"active world ownership and visibility remain intact")
	check(Memory.retained(owner).retained_bytes<=Memory.RETAINED_BUDGET,"selective trim meets the unchanged total budget")
	manager.pressure_requested=true; manager.next_sample=0; manager.tick(owner)
	check(Worlds.entries.is_empty(),"real pressure still evicts optional completed scenes")
	check(TrackTheme.winter_reflection_sky==null and environment.sky==sky,"pressure drops the sky cache while an active environment keeps its own reference")
	check(part.mesh==shared and part.visible,"pressure leaves the active scene intact")
	check(Memory.RETAINED_BUDGET==64*1024*1024 and Roads.BUDGET==32*1024*1024 and Worlds.MAX_BYTES==64*1024*1024,"no retention limits increase")
	owner.free(); visual.free(); sun.free(); environment.sky=null; NativeTrackVisual.trim_editor_cache()
	print("SELECTIVE_BUDGET ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
