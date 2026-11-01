extends SceneTree

func _initialize() -> void:
    call_deferred("run")

func run() -> void:
    var folder: String = OS.get_environment("BMT_BIOME_CAPTURE_DIR")
    var userdata: String = OS.get_user_data_dir().replace("\\", "/")
    var isolated: String = OS.get_environment("BMT_ISOLATED_APPDATA").replace("\\", "/")
    print("USERDATA=", userdata)
    if folder.is_empty() or isolated.is_empty() or not userdata.begins_with(isolated):
        push_error("The Godot user data directory is not isolated")
        quit(2)
        return
    root.size = Vector2i(1280, 720)
    var state_dir: String = folder.path_join("state")
    DirAccess.make_dir_recursive_absolute(state_dir)
    var app: Node = load("res://core/app.tscn").instantiate()
    app.set("library", TrackLibrary.new(state_dir.path_join("tracks")))
    app.set("records", LocalRecords.new(state_dir.path_join("records.json")))
    app.set("cloud_root_override", state_dir.path_join("cloud"))
    root.add_child(app)
    var deadline: int = Time.get_ticks_msec() + 90000
    while not bool(app.get("startup_complete")) and Time.get_ticks_msec() < deadline:
        await process_frame
    if not bool(app.get("startup_complete")):
        push_error("Startup did not complete")
        quit(3)
        return
    if app.get("online").configured:
        push_error("Capture unexpectedly has a configured online client")
        quit(4)
        return
    app.call("_new_document")
    deadline = Time.get_ticks_msec() + 20000
    while str(app.get("screen")) != "biome" and Time.get_ticks_msec() < deadline:
        await process_frame
    if str(app.get("screen")) != "biome":
        push_error("Create biome screen did not open")
        quit(5)
        return
    for i in range(8):
        await RenderingServer.frame_post_draw
    var picker: Control = app.get("root_ui").find_child("BiomePicker", true, false)
    if picker == null or picker.get_child_count() != 5:
        push_error("Expected five actual biome picker cards")
        quit(6)
        return
    var ids: Array[String] = []
    for card: Node in picker.get_children():
        ids.append(card.name)
    print("BIOME_CARDS=", ids)
    var capture_path: String = folder.path_join("biome-picker-1280.png")
    var result: Error = root.get_texture().get_image().save_png(capture_path)
    print("CAPTURE=", capture_path, " SAVE=", result)
    if result != OK:
        quit(7)
        return
    app.queue_free()
    await process_frame
    quit(0)

