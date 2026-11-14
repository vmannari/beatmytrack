extends Logger
## Offline producers must reject a generation that emitted engine/script errors.
var mutex := Mutex.new()
var errors: int = 0

func _log_error(_function: String, _file: String, _line: int, _code: String, _rationale: String, _editor_notify: bool, error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
	if error_type == Logger.ERROR_TYPE_WARNING: return
	mutex.lock()
	errors += 1
	mutex.unlock()

func failed() -> bool:
	mutex.lock()
	var result: bool = errors > 0
	mutex.unlock()
	return result
