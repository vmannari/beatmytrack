extends SceneTree
var output: String
var checks: int=0
func _initialize() -> void: run.call_deferred()
func run() -> void:
 for arg: String in OS.get_cmdline_user_args():
  if arg.begins_with("--output="): output=arg.trim_prefix("--output=")
 FileAccess.open("res://tests/test_garage_speakers.gd.uid",FileAccess.WRITE).store_string(ResourceUID.id_to_text(ResourceUID.create_id())+"\n") if not FileAccess.file_exists("res://tests/test_garage_speakers.gd.uid") else null
 root.size=Vector2i(1280,720);Engine.time_scale=0
 GarageEnvironment.architecture_scene=load("res://assets/garage/workshop_v1.scn")
 var view:=CarShowroom.new();view.garage_mode=true;root.add_child(view);MenuStyle.fill(view)
 while not view.showroom_ready: await process_frame
 view.set_process(false)
 var room: Node3D=view.camera.get_parent().get_node("GarageArchitecture")
 var old: Node3D=load("res://../build/garage-speakers-fix-2026-11-15/before/workshop_v1.scn").instantiate()
 view.camera.get_parent().add_child(old);view.reflections._mark_room(old);old.hide()
 for pose: Array in [["pair",Vector3(7.32,1.82,3.89),Vector3(9.80,0.96,4.70)],["left",Vector3(8.3,1.45,5.56),Vector3(9.8,1.09,5.56)],["right",Vector3(8.3,1.45,3.84),Vector3(9.8,1.09,3.84)],["distant",Vector3(5.5,2.1,3.3),Vector3(9.80,0.96,4.70)]]:
  view.camera.position=pose[1];view.camera.look_at(pose[2])
  for before: bool in [true,false]:
   room.visible=not before;old.visible=before
   for i: int in range(5):
    view.invalidate_render();view.reflections.request_draw()
    await RenderingServer.frame_post_draw
    await process_frame
   var folder: String=output.path_join("before" if before else "after");DirAccess.make_dir_recursive_absolute(folder)
   if view.showroom_viewport.get_texture().get_image().save_png(folder.path_join(pose[0]+".png"))!=OK: quit(1);return
   checks+=1
 print("GARAGE_SPEAKERS_NATIVE ",checks," captures, 0 failures")
 view.queue_free();Engine.time_scale=1
 for i: int in range(8): await process_frame
 quit()
