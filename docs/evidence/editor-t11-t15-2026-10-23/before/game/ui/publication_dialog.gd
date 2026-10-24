extends "res://ui/fault_dialog.gd"
## One owned window from explicit confirmation through the publication outcome.
signal publish_confirmed
const WAIT_MSEC: int = 5000
var phase: String = "confirm"
var activity: ProgressBar
var cancel_button: Button
var context_current: Callable
var deadline: int = 0
var timed_out: bool = false
var request_error: String = ""

func configure_publication(flow: TrackLifecycle, document: Dictionary, guard: Callable) -> void:
	context_current = guard
	_publication_value = {"category":"","title":"Publish track?","message":"After publishing, you cannot change this track. Make sure you’re happy with it before continuing.","support_title":"","support":"","symbol":"publish"}
	super.follow_publication(flow,document)

func _ready() -> void:
	super._ready()
	name = "PublicationDialog"
	dialog_close_on_escape = false
	dialog_hide_on_ok = false
	cancel_button = MenuStyle.button("Cancel",_cancel)
	cancel_button.name = "PublicationCancel"
	surface.add_child(cancel_button)
	activity = ProgressBar.new()
	activity.name = "PublicationActivity"
	activity.custom_minimum_size.y = 5
	activity.indeterminate = true
	activity.show_percentage = false
	details.add_child(activity)
	details.move_child(activity,message_label.get_index()+1)
	_render()

func _process(_delta: float) -> void:
	if not is_instance_valid(_publication_flow) or _publication_flow.scope() != _publication_scope or (context_current.is_valid() and not context_current.call()):
		super._cancel()
		return
	if phase == "waiting" and Time.get_ticks_msec() >= deadline:
		timed_out = true
		phase = "outcome"
		_refresh_publication()

func _confirm() -> void:
	if phase == "waiting": return
	if phase != "confirm":
		super._confirm()
		return
	phase = "waiting"
	deadline = Time.get_ticks_msec()+WAIT_MSEC
	_refresh_publication()
	publish_confirmed.emit()

func _cancel() -> void:
	if phase != "waiting": super._cancel()

func submission_finished(requested: bool, error: String = "") -> void:
	if not requested:
		request_error = error if not error.is_empty() else "Publication could not be started. Your draft and test lap remain saved."
		phase = "outcome"
	_refresh_publication()

func _refresh_publication() -> void:
	if not is_instance_valid(_publication_flow): return
	if _publication_flow.scope() != _publication_scope:
		super._cancel()
		return
	if phase == "confirm": return
	var job: Dictionary = _publication_flow.status_for(_publication_document)
	var accepted: bool = job.get("state") in ["finishing","published"] and job.get("receipt") is Dictionary
	if accepted or job.has("failure") or job.get("state") == "failed" or job.has("_read_error"):
		phase = "outcome"
		_publication_value = publication_presentation(job)
	elif not request_error.is_empty():
		_publication_value = {"category":"","title":"Track not published","message":request_error,"symbol":"warning"}
	elif timed_out:
		_publication_value = {"category":"","title":"Publication not confirmed","message":"Publishing is taking longer than expected. Keep the game open and online while we finish checking. Your draft and test lap are safe.","symbol":"clock"}
	else:
		_publication_value = {"category":"","title":"Publishing track…","message":"Please wait while we publish your track.","symbol":"publish"}
	_render()

func _render() -> void:
	if not is_instance_valid(activity): return
	heading.text = str(_publication_value.title)
	message_label.text = str(_publication_value.message)
	message_label.show()
	warning.texture = MenuIcon.texture(str(_publication_value.symbol),true)
	activity.visible = phase == "waiting"
	confirm_button.disabled = phase == "waiting"
	confirm_button.text = "Publish" if phase == "confirm" else "Publishing…" if phase == "waiting" else "OK"
	close_button.disabled = phase == "waiting"
	cancel_button.visible = phase == "confirm"
	_layout()

func _layout() -> void:
	super._layout()
	if not is_instance_valid(cancel_button): return
	if phase == "confirm":
		var width: float = minf(220,(surface.size.x-72)*0.5)
		var left: float = (surface.size.x-width*2-16)*0.5
		cancel_button.position = Vector2(left,surface.size.y-80)
		cancel_button.size = Vector2(width,56)
		confirm_button.position = Vector2(left+width+16,surface.size.y-80)
		confirm_button.size = Vector2(width,56)
