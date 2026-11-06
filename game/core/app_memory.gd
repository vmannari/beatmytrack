extends RefCounted
## Lazy budget boundary. Startup owns no native editor/race/garage presenter.
## Delegate the unchanged accounting policy once optional native resources exist.
const RETAINED_BUDGET: int = 64 * 1024 * 1024
const GARAGE_BUDGET: int = 96 * 1024 * 1024
const PRESSURE_HISTORY: int = 2 * 1024 * 1024
var _policy: RefCounted
var _pressure_requested: bool = false
var _next_sample: int = 0
var pressure_requested: bool:
	get: return _policy.pressure_requested if _policy != null else _pressure_requested
	set(value):
		_pressure_requested = value
		if _policy != null: _policy.pressure_requested = value
var next_sample: int:
	get: return _policy.next_sample if _policy != null else _next_sample
	set(value):
		_next_sample = value
		if _policy != null: _policy.next_sample = value
var telemetry: Dictionary:
	get: return _policy.telemetry if _policy != null else {}
var trims: int:
	get: return _policy.trims if _policy != null else 0

func tick(app: Node) -> void:
	if _policy == null:
		var loader: Node = app._garage_preloader
		var native_garage: bool = is_instance_valid(app._retained_garage) or (is_instance_valid(loader) and loader.studio != null)
		if not native_garage and not is_instance_valid(app.canvas) and not is_instance_valid(app.game):
			# Cold shell has only bounded pictures/public asset reads. There is no
			# optional native cache to evict and no reason to load one to trim it.
			_pressure_requested = false
			return
		activate()
	_policy.tick(app)

func activate() -> void:
	if _policy != null: return
	_policy = load("res://editor/editor_memory.gd").new()
	_policy.pressure_requested = _pressure_requested
	_policy.next_sample = _next_sample

static func retained(app: Node) -> Dictionary:
	return load("res://editor/editor_memory.gd").retained(app)
