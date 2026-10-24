extends Node
## Android development-only SDK adapter. Demo ads never grant banked credits.
signal finished(result: Dictionary)
signal presented
const SINGLETON: String = "BmtAdMob"
var _native: Object
var _request: String = ""
var _shown: bool = false

static func supported() -> bool:
	return OS.is_debug_build() and OS.get_name() == "Android" and Engine.has_singleton(SINGLETON)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if supported():
		_native = Engine.get_singleton(SINGLETON)
		_native.connect("rewarded_result", _completed)
		if _native.has_signal("rewarded_presented"): _native.connect("rewarded_presented",_presented)

func show_rewarded() -> Dictionary:
	if not supported(): return {"ok":false,"error":"Test ads are available in the Android development build."}
	if not _request.is_empty(): return {"ok":false,"error":"An ad is already open."}
	_request = str(get_instance_id()) + "-" + str(Time.get_ticks_usec())
	_shown = false
	_native.call("showRewarded", _request)
	return await finished

func _completed(request: String, earned: bool, message: String) -> void:
	if request != _request or _request.is_empty(): return
	# Older installed debug bridges report a successful/early-dismissed show in
	# this existing result contract; the new signal reports the actual show tick.
	if not _shown and (earned or message == "Ad closed before completion. No resume used."): _presented(request)
	_request = ""
	finished.emit({"ok":earned,"error":message,"test_ad":true,"shown":_shown})

func _presented(request: String) -> void:
	if request != _request or _request.is_empty() or _shown: return
	_shown = true
	presented.emit()

func cancel() -> void:
	if _native != null and not _request.is_empty(): _native.call("cancelRequest", _request)

func _exit_tree() -> void:
	if _native != null and _native.is_connected("rewarded_result", _completed):
		_native.disconnect("rewarded_result", _completed)
		if _native.has_signal("rewarded_presented") and _native.is_connected("rewarded_presented",_presented): _native.disconnect("rewarded_presented",_presented)
		cancel()
