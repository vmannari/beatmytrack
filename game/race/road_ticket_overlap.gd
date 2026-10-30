extends RefCounted
## Own one speculative road job until race loading claims it or closes.
const SelectedPreparation = preload("res://race/selected_track_preparation.gd")
var job: RefCounted
var tree: SceneTree
var loading: WeakRef

func attach(value: RefCounted, owner_tree: SceneTree, overlay: Node) -> void:
	job = value
	tree = owner_tree
	loading = weakref(overlay)
	overlay.tree_exiting.connect(cancel,CONNECT_ONE_SHOT)

func take() -> RefCounted:
	var overlay: Object = loading.get_ref() if loading != null else null
	if is_instance_valid(overlay) and overlay.tree_exiting.is_connected(cancel): overlay.tree_exiting.disconnect(cancel)
	var result: RefCounted = job
	job = null
	return result

func cancel() -> void:
	if job == null: return
	SelectedPreparation.cancel(job,tree)
	job = null
