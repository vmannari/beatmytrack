extends Node
## Platform sharing and invitation intents; no SDK or external runtime service.
signal invitation_received(value: String)
var _native: Object

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if OS.get_name() == "Android" and Engine.has_singleton("BmtChallenges"):
		_native = Engine.get_singleton("BmtChallenges")
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

func _received(value: String) -> void:
	if not ChallengesClient.code_from(value).is_empty(): invitation_received.emit(value)

func share(value: String) -> bool:
	if _native != null:
		_native.call("shareChallenge",value)
		return true
	DisplayServer.clipboard_set(value)
	return false

