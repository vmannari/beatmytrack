extends RefCounted
## Live editor ownership. App exposes entry points used by navigation and racing.

var document: Dictionary = {}
var canvas: Control
var status: Label
var guidance: String = ""
var test_button: Button
var publish_button: Button
var share_button: Button
var view: Dictionary = {}
var return_screen: String = "biome"
var return_draft_view: Dictionary = {}
var mode_buttons: Dictionary = {}
var tools_open: bool = false
var tools_panel: PanelContainer
var map_panel: PanelContainer
var undo: Button
var redo: Button
var world: Control
var object_browser_state: Dictionary = {}
var object_browser: Control
var object_population_panel: Control
var palette: Control
var context: HBoxContainer
var surface_toolbar: PanelContainer
var surface_actions: HBoxContainer
var issue_button: Button
var issues: Array[Dictionary] = []
var geometry: String = ""
var object_controls_panel: PanelContainer
var object_controls: Control
var object_property: String = ""
var _object_controls_target: String = ""
var inspector: VBoxContainer
var preview_cancel: RefCounted
var preview_thread: Thread
var preview_document: Dictionary = {}
var raster_cache: Dictionary = {"enabled":true}
var compiled_cache: Array[Dictionary] = []
var writes = preload("res://editor/write_queue.gd").new()
var saved_snapshot: Dictionary = {}
var route_pieces: Array = []
var route_fields: Dictionary = {}
var loading: PanelContainer
var pending_road_bake: Dictionary = {}
var save_button: Button
var save_error: Error = OK
var save_message: String = ""
var pending_tools: Dictionary = {}
var pending_id: String = ""
var issue_cursor: int = -1
var hint_generation: int = 0
var hint_active: bool = false
var wip_saved: String = ""
var wip_snapshot: Dictionary = {}
var wip_store: TrackLibrary
var saved_store: TrackLibrary
var wip_disk_hash: String = ""
var saved_disk_hash: String = ""
var retry_original: bool = false

var session = preload("res://editor/editor_session.gd").new()
