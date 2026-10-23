extends Node
## Preloaded Android demo placement. A late load never opens an ad by itself.
signal finished(result: Dictionary)
const SINGLETON: String = "BmtAdMob"
var _native: Object
var _request: String = ""

func supported() -> bool:
	return _native != null and _native.has_signal("interstitial_result") and _native.has_method("prepareInterstitial") and _native.has_method("tryShowInterstitial") and _native.has_method("discardInterstitial")

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if OS.is_debug_build() and OS.get_name() == "Android" and Engine.has_singleton(SINGLETON):
		_native = Engine.get_singleton(SINGLETON)
		if _native.has_signal("interstitial_result"): _native.connect("interstitial_result", _completed)

func prepare() -> void:
	if supported(): _native.call("prepareInterstitial")

func discard() -> void:
	if supported(): _native.call("discardInterstitial")

func show_interstitial() -> Dictionary:
	if not supported() or not _request.is_empty(): return {"shown":false}
	_request = str(get_instance_id()) + "-" + str(Time.get_ticks_usec())
	_native.call("tryShowInterstitial", _request)
	return await finished

func _completed(request: String, shown: bool, _message: String) -> void:
	if request != _request or _request.is_empty(): return
	_request = ""
	finished.emit({"shown":shown})

func _exit_tree() -> void:
	if _native == null: return
	if _native.is_connected("interstitial_result", _completed): _native.disconnect("interstitial_result", _completed)
	if not _request.is_empty(): _native.call("cancelRequest", _request)
	discard()
