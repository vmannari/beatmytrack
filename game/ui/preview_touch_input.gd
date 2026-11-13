extends Node
## Observe releases before menu gestures or popups consume their input.
const TRACKERS: StringName=&"preview_touch_trackers"
const RELAY_META: StringName=&"preview_touch_relay"
const WINDOW_META: StringName=&"preview_touch_observer"
var popup_observer: bool=false

static func bind(tracker: Node) -> void:
	tracker.add_to_group(TRACKERS)
	var tree: SceneTree=tracker.get_tree()
	if tree.root.has_meta(RELAY_META): return
	var relay: Node=load("res://ui/preview_touch_input.gd").new()
	relay.name="PreviewTouchRelay"
	tree.root.set_meta(RELAY_META,true)
	# A tracker may be binding during the root's child-ready notification.
	tree.root.add_child.call_deferred(relay)

func _ready() -> void:
	if popup_observer: return
	# The root relay runs before the App's children. Page swipes can pass DOWN
	# through to a worker and handle UP, so releases need the same forwarding
	# here as in a popup's separate viewport. Keep each other finger intact.
	get_tree().node_added.connect(_node_added)
	_watch_existing(get_tree().root)

func _watch_existing(node: Node) -> void:
	_node_added(node)
	# MenuButton and ColorPickerButton own internal popup children.
	for child: Node in node.get_children(true): _watch_existing(child)

func _node_added(node: Node) -> void:
	if node is Window and node!=get_tree().root:
		_watch_window.call_deferred(weakref(node))

func _watch_window(reference: WeakRef) -> void:
	var window: Window=reference.get_ref() as Window
	if not is_instance_valid(window) or not window.is_inside_tree() or window.has_meta(WINDOW_META): return
	window.set_meta(WINDOW_META,true)
	var observer: Node=load("res://ui/preview_touch_input.gd").new()
	observer.name="PreviewTouchRelease"
	observer.popup_observer=true
	window.add_child(observer)

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and (not event.pressed or event.canceled):
		get_tree().call_group(TRACKERS,"_release_preview_touch",event.index)
