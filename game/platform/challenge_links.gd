extends Node
## Platform sharing and invitation intents; no SDK or external runtime service.
signal invitation_received(value: String)
signal track_received(value: String)
signal results_share_failed(request_id: String, message: String)
signal track_share_failed(value: String)
var _native: Object
var _windows_share: RefCounted
var _pending_track_share: String = ""

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if OS.get_name() == "Windows" and DisplayServer.get_name() != "headless" and ClassDB.class_exists("BmtWindowsShare"):
		_windows_share = ClassDB.instantiate("BmtWindowsShare")
	if OS.get_name() == "Android" and Engine.has_singleton("BmtChallenges"):
		_native = Engine.get_singleton("BmtChallenges")
		if _native.has_signal("track_share_failed"):
			_native.connect("track_share_failed",func(value: String) -> void: _track_share_failed.call_deferred(value))
		if _native.has_signal("results_share_failed"):
			_native.connect("results_share_failed",func(request_id: String, message: String) -> void: results_share_failed.emit(request_id,message))
		var pending: String = str(_native.call("takePendingLink"))
		if not pending.is_empty(): _received.call_deferred(pending)
		var poll := Timer.new()
		poll.wait_time = 0.5
		poll.autostart = true
		poll.timeout.connect(func() -> void:
			var value: String = str(_native.call("takePendingLink"))
			if not value.is_empty(): _received(value))
		add_child(poll)
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--challenge="): _received.call_deferred(argument.trim_prefix("--challenge="))
		elif argument.begins_with("--track-link="): _received.call_deferred(argument.trim_prefix("--track-link="))

func _received(value: String) -> void:
	if not preload("res://platform/track_links.gd").version_from(value).is_empty(): track_received.emit(value)
	elif not ChallengesClient.code_from(value).is_empty(): invitation_received.emit(value)

func share_track(value: String) -> bool:
	_pending_track_share = value
	if _native != null and _native.has_method("shareTrack"):
		var opened: Variant = _native.call("shareTrack",value)
		# Older installed bridges return void after launching the same chooser.
		if opened == null or bool(opened): return true
	if _windows_share != null:
		var lines: PackedStringArray = value.split("\n")
		var title: String = lines[0].left(256)
		var link: String = lines[lines.size()-1]
		var window: int = DisplayServer.window_get_native_handle(DisplayServer.WINDOW_HANDLE,get_window().get_window_id())
		if _windows_share.call("share_text",window,value,title,link): return true
	_copy_track_text(value)
	return false

func _track_share_failed(value: String) -> void:
	if value != _pending_track_share: return
	_pending_track_share = ""
	_copy_track_text(value)
	track_share_failed.emit(value)

func _copy_track_text(value: String) -> void:
	DisplayServer.clipboard_set(value)

func share(value: String) -> bool:
	if _native != null:
		_native.call("shareChallenge",value)
		return true
	DisplayServer.clipboard_set(value)
	return false

func can_share_results() -> bool:
	return _native != null and _native.has_method("shareResults")

func share_results(request_id: String, png: PackedByteArray, text: String) -> bool:
	if not can_share_results() or png.is_empty() or png.size() > 4*1024*1024 or text.is_empty() or text.length() > 4096: return false
	return bool(_native.call("shareResults",request_id,png,text))

