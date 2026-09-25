extends RefCounted
## Presentation-only handheld feedback; never called from the simulation step.

const DURATION_MS: int = 12
const AMPLITUDE: float = 0.2
static var pending_task: int = -1
# Explicit debug probe only; production always uses the bounded worker.
static var diagnostic_synchronous: bool = false

static func press(strength: float = AMPLITUDE) -> void:
	if strength > 0.0 and (OS.has_feature("android") or OS.has_feature("ios")):
		var amplitude: float = clampf(strength, 0.0, 1.0)
		if OS.has_feature("android") and not (OS.is_debug_build() and diagnostic_synchronous):
			_submit(func() -> void: Input.vibrate_handheld(DURATION_MS, amplitude))
		else:
			Input.vibrate_handheld(DURATION_MS, amplitude)

static func _submit(feedback: Callable) -> void:
	# Called only on the main thread. Never wait for a running Android Binder
	# call, and never queue stale pulses when the vibrator service is slow.
	if pending_task >= 0:
		if not WorkerThreadPool.is_task_completed(pending_task): return
		WorkerThreadPool.wait_for_task_completion(pending_task)
	pending_task = WorkerThreadPool.add_task(feedback)
