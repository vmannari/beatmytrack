extends Resource
## Private, locally produced presentation snapshot; never a track download.
@export var cache_id: String = ""
@export var scene: PackedScene
@export var world_metadata: Dictionary = {}
@export var prop_indices: PackedInt32Array = PackedInt32Array()
@export var tyre_index: int = -1
@export var scenic_count: int = 0
@export var estimated_bytes: int = 0
