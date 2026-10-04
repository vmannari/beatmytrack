extends Node
## Android development-only SDK adapter. Demo ads never grant banked credits.
signal finished(result: Dictionary)
const SINGLETON: String = "BmtAdMob"
var _native: Object
var _request: String = ""

static func supported() -> bool:
	return OS.is_debug_build() and OS.get_name() == "Android" and Engine.has_singleton(SINGLETON)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if supported():
		_native = Engine.get_singleton(SINGLETON)
		_native.connect("rewarded_result", _completed)

func show_rewarded() -> Dictionary:
	if not supported(): return {"ok":false,"error":"Test ads are available in the Android development build."}
	if not _request.is_empty(): return {"ok":false,"error":"An ad is already open."}
	_request = str(get_instance_id()) + "-" + str(Time.get_ticks_usec())
	_native.call("showRewarded", _request)
	return await finished

func _completed(request: String, earned: bool, message: String) -> void:
	if request != _request or _request.is_empty(): return
	_request = ""
	finished.emit({"ok":earned,"error":message,"test_ad":true})

func cancel() -> void:
	if _native != null and not _request.is_empty(): _native.call("cancelRequest", _request)

func _exit_tree() -> void:
	if _native != null and _native.is_connected("rewarded_result", _completed):
		_native.disconnect("rewarded_result", _completed)
		cancel()
