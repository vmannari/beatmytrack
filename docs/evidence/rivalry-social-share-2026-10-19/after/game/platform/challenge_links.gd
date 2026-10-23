extends Node
## Platform sharing and invitation intents; no SDK or external runtime service.
signal invitation_received(value: String)
signal track_received(value: String)
signal results_share_failed(request_id: String, message: String)
var _native: Object

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if OS.get_name() == "Android" and Engine.has_singleton("BmtChallenges"):
		_native = Engine.get_singleton("BmtChallenges")
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
	if _native != null and _native.has_method("shareTrack"):
		_native.call("shareTrack",value)
		return true
	DisplayServer.clipboard_set(value)
	return false

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

