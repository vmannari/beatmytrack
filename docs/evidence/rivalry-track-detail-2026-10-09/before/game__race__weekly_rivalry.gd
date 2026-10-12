class_name WeeklyRivalry
extends RefCounted
## Menu projection of server standings. Sample data is opt-in for UI evidence only.
const SELF: String = "you"
const POINTS: Array[int] = [30,26,23,20,18,16,14,12,10,8,6,4,2,1]
var points_policy: Array[int] = [30,26,23,20,18,16,14,12,10,8,6,4,2,1,1,1,1,1,1,1]
const NAMES: Array[String] = ["Mika","Alex","You","Janne","Sophie","Elias","Nora","Leo","Aino","Oscar","Emil","Sara","Luca","Iris"]
var week: int = 27
var completed: bool = false
var scope: String = ""
var tracks: Array[Dictionary] = []
var recordings: Dictionary = {}
var recorded_times: Dictionary = {}
var pb_count: int = 0
var last_result: Dictionary = {}
var native_cache: Dictionary = {}
var sample: bool = false
var test_population: bool = false
var server_standings: Array[Dictionary] = []
var group_id: String = ""
var status: String = "not_joined"
var remaining_seconds: int = 0
var received_msec: int = 0
var placement: bool = false
var forming: bool = false
var vehicle_id: String = "compact"
var source_self: String = ""

func _init(use_sample: bool = false) -> void:
	sample = use_sample
	if sample:
		_seed()
		status = "active"
		remaining_seconds = 4*86400+12*3600
		received_msec = Time.get_ticks_msec()

func apply_snapshot(value: Dictionary) -> void:
	sample = false
	test_population = bool(value.get("test_population",false))
	status = str(value.get("state","not_joined"))
	week = int(value.get("week",0))
	group_id = str(value.get("group_id",""))
	completed = status == "complete"
	remaining_seconds = int(value.get("remaining_seconds",maxi(0,int(value.get("ends_at",0))-int(value.get("server_now",0)))))
	received_msec = Time.get_ticks_msec()
	placement = bool(value.get("placement",false))
	forming = bool(value.get("group_forming",false))
	vehicle_id = str(value.get("vehicle_id",VehicleCatalog.selected))
	source_self = str(value.get("self_id",""))
	if value.get("points_policy") is Array: points_policy.assign(value.points_policy)
	tracks.clear()
	server_standings.clear()
	for row: Dictionary in value.get("standings",[]): server_standings.append(_map_row(row))
	for track: Dictionary in value.get("tracks",[]):
		var entry: Dictionary = track.entry.duplicate(true)
		var rows: Array[Dictionary] = []
		for row: Dictionary in track.entries: rows.append(_map_row(row))
		tracks.append({"id":str(entry.version_id),"name":str(entry.name),"theme":str(entry.get("theme","pine")),"document":{"points":entry.get("points",[])},"entry":entry,"entries":rows,"board_id":str(track.board_id),"available":bool(track.get("available",true))})

func _map_row(row: Dictionary) -> Dictionary:
	var mapped: Dictionary = row.duplicate(true)
	mapped.driver_id = str(row.get("id",""))
	mapped.points = int(row.get("points",0))
	if row.has("completed"): mapped.completed = int(row.completed)
	if row.get("rank") != null: mapped.rank = int(row.rank)
	if bool(mapped.get("is_test_driver",false)) and str(mapped.get("name","")).contains(" #"):
		mapped.name = str(mapped.name).get_slice(" #",0)
	if mapped.driver_id == source_self:
		mapped.id = SELF
		mapped.name = "You"
	return mapped

func apply_outcome(value: Dictionary, index: int) -> void:
	last_result = value.duplicate(true)
	last_result.index = index
	last_result.valid = true
	for key: String in ["before","after","overall_before","overall_after"]: last_result[key] = _map_row(value[key])
	last_result.beaten = []
	for row: Dictionary in value.get("beaten",[]): last_result.beaten.append(_map_row(row))

func result_board(index: int) -> Array[Dictionary]:
	# Project the confirmed/provisional PB over the latest board while its refresh
	# is in flight. This never writes the verified entries or weekly standings.
	var rows: Array[Dictionary] = board(index)
	if int(last_result.get("index",-1)) != index or not last_result.get("after") is Dictionary: return rows
	var after: Dictionary = last_result.after
	if after.get("ms") == null: return rows
	for row: Dictionary in rows:
		if row.id == SELF and (row.get("ms") == null or int(after.ms) < int(row.ms)):
			row.merge(after,true)
	rows.sort_custom(func(a: Dictionary,b: Dictionary) -> bool:
		if a.get("ms") == null: return false
		if b.get("ms") == null: return true
		return _result_order(a) < _result_order(b))
	var rank: int = 0
	var previous: int = -1
	for position: int in range(rows.size()):
		var row: Dictionary = rows[position]
		if row.get("ms") == null: continue
		var order: int = _result_order(row)
		if order != previous: rank = position+1
		previous = order
		row.rank = rank
	return rows

static func _result_order(row: Dictionary) -> int:
	return int(row.ticks)*1000 if row.get("ticks") != null else int(row.ms)*120

func preview_result(index: int, ticks: int, seconds: float) -> Dictionary:
	# Presentation only: the verified boards/PBs remain untouched. Use canonical
	# ticks for ties, and update every affected driver's points in the projection.
	last_result = {}
	if not is_finite(seconds) or seconds <= 0.0: return last_result
	last_result = {"ms":roundi(seconds*1000.0)}
	if sample or index < 0 or index >= tracks.size() or ticks <= 0: return last_result
	var before: Dictionary = self_row(board(index))
	var overall_before: Dictionary = self_row(standing())
	if before.is_empty() or overall_before.is_empty() or not before.has("ticks"): return last_result
	var improved: bool = before.ticks == null or ticks < int(before.ticks)
	var totals: Dictionary = {}
	for driver: Dictionary in standing():
		totals[driver.id] = driver.duplicate(true)
		totals[driver.id].points = 0
		totals[driver.id].completed = 0
	var projected: Array[Dictionary] = []
	var beaten: Array[Dictionary] = []
	for slot: int in range(tracks.size()):
		var rows: Array[Dictionary] = board(slot)
		for row: Dictionary in rows:
			if not row.has("ticks") or not totals.has(row.id): return last_result
			if slot == index and improved:
				if row.id == SELF:
					row.ticks = ticks
					row.ms = last_result.ms
				elif row.ticks != null and ticks < int(row.ticks) and (before.ticks == null or int(row.ticks) < int(before.ticks)):
					beaten.append(row.duplicate(true))
		rows.sort_custom(func(a: Dictionary,b: Dictionary) -> bool:
			if a.ticks == null: return false
			return b.ticks == null or int(a.ticks) < int(b.ticks))
		var rank: int = 0
		var previous: int = -1
		for position: int in range(rows.size()):
			var row: Dictionary = rows[position]
			if row.ticks == null:
				row.rank = null
				row.points = 0
			else:
				if int(row.ticks) != previous: rank = position+1
				previous = int(row.ticks)
				if rank > points_policy.size(): return last_result
				row.rank = rank
				row.points = points_policy[rank-1]
				totals[row.id].completed += 1
			totals[row.id].points += int(row.points)
		if slot == index: projected = rows
	var overall: Array[Dictionary] = []
	for row: Dictionary in totals.values(): overall.append(row)
	overall.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return int(a.points) > int(b.points))
	var overall_rank: int = 0
	var previous_points: int = -1
	for position: int in range(overall.size()):
		if int(overall[position].points) != previous_points: overall_rank = position+1
		previous_points = int(overall[position].points)
		overall[position].rank = overall_rank if int(overall[position].completed) > 0 else null
	var after: Dictionary = self_row(projected)
	last_result = {"index":index,"ms":roundi(seconds*1000.0),"valid":false,"provisional":true,"improved":improved,
		"before":before,"after":after,"points_delta":int(after.points)-int(before.points),
		"overall_before":overall_before,"overall_after":self_row(overall),"beaten":beaten}
	return last_result.duplicate(true)

func countdown() -> String:
	if sample and completed: return "Week complete"
	if status == "settling": return "Final results being verified"
	if completed: return "Week complete"
	var left: int = maxi(0,remaining_seconds-(Time.get_ticks_msec()-received_msec)/1000)
	return "%dd %dh remaining" % [left/86400,(left%86400)/3600] if left > 0 else "Week closing"

func _seed() -> void:
	tracks.clear()
	recordings.clear()
	recorded_times.clear()
	native_cache.clear()
	pb_count = 0
	last_result = {}
	var titles: Array[String] = ["Frostbite","Dust Cloud","Knot","Night Shift","Riverside"]
	var themes: Array[String] = ["winter","desert","pine","night_city","storm"]
	var routes: Array = [
		[[-42,-24],[-48,12],[-18,36],[15,27],[44,8],[38,-28],[0,-37]],
		[[-48,-20],[-43,22],[-12,39],[40,31],[50,-6],[20,-33],[-13,-27]],
		[[-45,-30],[-48,21],[-18,35],[2,12],[25,34],[48,12],[43,-29],[0,-39]],
		[[-50,-27],[-50,27],[-18,38],[18,28],[50,30],[50,-28],[15,-39],[-20,-25]],
		[[-45,-23],[-38,23],[-12,39],[8,24],[36,36],[48,3],[29,-30],[-8,-35]],
	]
	var orders: Array = [[0,1,2,3,4,5,6,7,8,9,10,11,12,13],[2,0,1,3,5,4,7,6,9,8,11,10,13,12],[0,1,3,2,4,6,5,8,7,10,9,12,11,13],[0,2,1,3,6,4,5,9,7,8,12,10,11,13],[0,1,3,4,5,6,2,7,8,9,10,11,12,13]]
	var base_ms: Array[int] = [91521,78500,83981,88310,94500]
	for index: int in range(titles.size()):
		var doc: Dictionary = TrackDocument.create_default()
		doc.id = "rivalry_" + str(index)
		doc.name = titles[index]
		doc.creator = "Beat my track · concept"
		doc.theme = themes[index]
		doc.points = routes[index].duplicate(true)
		doc.widths = []
		doc.corners = []
		for _point: Array in doc.points:
			doc.widths.append(10.0)
			doc.corners.append("smooth")
		doc.layout = TrackDocument.road_layout(doc)
		var entries: Array[Dictionary] = []
		var elapsed: int = base_ms[index]
		for place: int in range(NAMES.size()):
			var player: int = orders[index][place]
			if place > 0: elapsed += [80,60,150,210,320,180,410,290,520,440,600,730,880][place-1]
			entries.append({"id":SELF if player == 2 else "driver_"+str(player),"name":NAMES[player],"ms":elapsed})
		tracks.append({"id":str(doc.id),"name":titles[index],"theme":themes[index],"document":doc,"entries":entries})

func next_week() -> void:
	week += 1
	completed = false
	_seed()

func board(index: int) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	rows.assign(tracks[index].entries.duplicate(true))
	if not sample: return rows
	rows.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return int(a.ms) < int(b.ms) if a.ms != b.ms else str(a.id) < str(b.id))
	var rank: int = 1
	for i: int in range(rows.size()):
		if i == 0 or rows[i].ms != rows[i-1].ms: rank = i+1
		rows[i].rank = rank
		rows[i].points = POINTS[rank-1]
	return rows

func standing() -> Array[Dictionary]:
	if not sample: return server_standings.duplicate(true)
	var totals: Dictionary = {}
	for index: int in range(tracks.size()):
		for row: Dictionary in board(index):
			if not totals.has(row.id): totals[row.id] = {"id":row.id,"name":row.name,"country_code":str(row.get("country_code","")),"points":0}
			totals[row.id].points += int(row.points)
	var rows: Array[Dictionary] = []
	for row: Dictionary in totals.values(): rows.append(row.duplicate())
	rows.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return int(a.points) > int(b.points) if a.points != b.points else str(a.id) < str(b.id))
	var rank: int = 1
	for i: int in range(rows.size()):
		if i == 0 or rows[i].points != rows[i-1].points: rank = i+1
		rows[i].rank = rank
	return rows

static func self_row(rows: Array[Dictionary]) -> Dictionary:
	for row: Dictionary in rows:
		if row.id == SELF: return row
	return {}

func gaps(index: int) -> Dictionary:
	var rows: Array[Dictionary] = board(index)
	var own: Dictionary = self_row(rows)
	var ahead: Dictionary = {}
	var behind: Dictionary = {}
	for row: Dictionary in rows:
		if own.get("ms") == null or row.get("ms") == null: continue
		if int(row.ms) < int(own.ms): ahead = row
		elif int(row.ms) > int(own.ms) and behind.is_empty(): behind = row
	return {"own":own,"ahead":ahead,"behind":behind,"leader":rows[0] if not rows.is_empty() and rows[0].get("ms") != null else {}}

func overall_gaps() -> Dictionary:
	var rows: Array[Dictionary] = standing()
	var own: Dictionary = self_row(rows)
	var ahead: Dictionary = {}
	var behind: Dictionary = {}
	for row: Dictionary in rows:
		if row.get("rank") == null: continue
		if int(row.points) > int(own.points): ahead = row
		elif int(row.points) < int(own.points) and behind.is_empty(): behind = row
	return {"own":own,"ahead":ahead,"behind":behind}

func opportunity() -> int:
	var selected: int = 0
	var smallest: int = 2147483647
	for index: int in range(tracks.size()):
		if not bool(tracks[index].get("available",true)): continue
		var gap: Dictionary = gaps(index)
		if gap.own.get("ms") == null: return index
		if gap.ahead.is_empty(): continue
		var distance: int = int(gap.own.ms)-int(gap.ahead.ms)
		if distance < smallest:
			smallest = distance
			selected = index
	return selected

func nearby(index: int) -> Array[Dictionary]:
	var rows: Array[Dictionary] = board(index)
	var position: int = 0
	for i: int in range(rows.size()):
		if rows[i].id == SELF: position = i
	var start: int = clampi(position-2,0,maxi(0,rows.size()-4))
	var slice: Array[Dictionary] = []
	slice.assign(rows.slice(start,start+4))
	return slice

func submit(index: int, seconds: float, valid: bool = true) -> Dictionary:
	if not sample or completed or index < 0 or index >= tracks.size() or not is_finite(seconds) or seconds <= 0.0 or seconds > 1800.0: return {}
	var ms: int = roundi(seconds*1000.0)
	if ms < 1: return {}
	var before: Dictionary = gaps(index)
	var overall_before: Dictionary = self_row(standing())
	var improved: bool = valid and ms < int(before.own.ms)
	var beaten: Array[Dictionary] = []
	if improved:
		for row: Dictionary in board(index):
			if row.id != SELF and int(row.ms) < int(before.own.ms) and int(row.ms) > ms: beaten.append(row)
		for row: Dictionary in tracks[index].entries:
			if row.id == SELF: row.ms = ms
		pb_count += 1
	var after: Dictionary = gaps(index)
	last_result = {"index":index,"ms":ms,"valid":valid,"improved":improved,"before":before.own,"after":after.own,"points_delta":int(after.own.points)-int(before.own.points),"overall_before":overall_before,"overall_after":self_row(standing()),"beaten":beaten}
	return last_result.duplicate(true)

func wins() -> int:
	var count: int = 0
	for index: int in range(tracks.size()):
		if gaps(index).own.get("rank") != null and int(gaps(index).own.rank) == 1: count += 1
	return count

func resolve(index: int) -> NativeTrack:
	if index < 0 or index >= tracks.size(): return null
	if not native_cache.has(index):
		var native: NativeTrack = TrackCompiler.compile(tracks[index].document)
		if native == null: return null
		native.metadata["rivalry_concept"] = true
		native_cache[index] = native
	return native_cache[index]

static func gap_text(milliseconds: int) -> String:
	return "%.2f s" % (milliseconds/1000.0)
