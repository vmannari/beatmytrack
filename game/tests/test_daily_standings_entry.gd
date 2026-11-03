extends SceneTree
const Card = preload("res://ui/daily_result_card.gd")
var failures: int = 0
class Feed extends Node:
 signal identity_changed
 signal race_verified
 signal released
 var player: Dictionary = {"id":"self","display_name":"Ville"}
 var pending: bool = true
 var failed: bool = false
 var calls: int = 0
 func signed_in() -> bool: return true
 func base_url() -> String: return "http://fixture.invalid"
 func cancel_public_reads(_id: int) -> void: pass
 func request_api(_path: String, _method: int, _body: Dictionary, _key: String, _auth: bool) -> Dictionary:
  calls += 1
  if pending: await released
  if failed: return {"ok":false}
  var limits: Array = []
  for percentile: int in [75,60,50,40,30,20,10,5,1]: limits.append({"percentile":percentile,"lap_ticks":1800})
  return {"ok":true,"data":{"day":20759,"version_id":"fixture","vehicle_id":"compact","ends_at":20760*86400,"server_now":20759*86400+1,"population":1,"items":[{"player_id":"self","display_name":"Ville","rank":1,"time_ticks":1800}],"cutoffs":limits}}
func _initialize() -> void: run.call_deferred()
func check(value: bool, message: String) -> void:
 if not value:
  failures += 1
  push_error(message)
func run() -> void:
 OS.set_environment("BMT_API_URL","")
 var feed := Feed.new()
 root.add_child(feed)
 var card := Card.new()
 card.client = feed
 card.cloud = feed
 card.records = LocalRecords.new("user://daily-entry-"+TrackLibrary.unique_id()+".json")
 root.add_child(card)
 card.configure(20759,"fixture",20760*86400)
 check(card._rows.get_child(0).text.begins_with("Loading standings"),"initial request shows loading")
 feed.pending = false
 feed.released.emit()
 check(card._rows.get_child_count() == 1 and card._rows.get_child(0).name == "DailyNearbySelf","first entry shows server own row without a local result")
 var style: StyleBoxFlat = card._rows.get_child(0).get_theme_stylebox("panel")
 check(style.bg_color == Color("ffd34820") and style.border_width_left == 1 and style.border_width_right == 1,"player uses Rivalry tint and outline")
 feed.failed = true
 card.refresh()
 check(card._retry.visible and card._rows.get_child(0).name == "DailyNearbySelf","failed background refresh retains cached rows and offers retry")
 feed.failed = false
 card._retry.pressed.emit()
 check(not card.summary.is_empty() and not card._retry.visible,"retry restores standings")
 var calls: int = feed.calls
 feed.race_verified.emit()
 check(feed.calls == calls+1 and not card.summary.is_empty(),"verification refreshes standings")
 calls = feed.calls
 feed.identity_changed.emit()
 check(feed.calls == calls+1,"identity refreshes standings")
 var records: LocalRecords = card.records
 card.queue_free()
 await process_frame
 feed.pending = true
 card = Card.new()
 card.client = feed
 card.cloud = feed
 card.records = records
 root.add_child(card)
 card.configure(20759,"fixture",20760*86400)
 check(card._rows.get_child(0).name == "DailyNearbySelf" and not card.summary.is_empty(),"recreated page renders cache before delayed response")
 card.refresh()
 check(card._rows.get_child(0).name == "DailyNearbySelf","repeated activation retains visible standings")
 card.vehicle = "kart"
 card.refresh()
 check(card.summary.is_empty(),"another car cannot reuse cached standings")
 card.vehicle = "compact"
 card.refresh()
 check(not card.summary.is_empty(),"switching back restores the matching car cache")
 feed.player = {"id":"other","display_name":"Other"}
 card.refresh()
 check(card.summary.is_empty() and card._rows.get_child(0).text.begins_with("Loading standings"),"other account cannot reuse cached standings")
 feed.pending = false
 feed.failed = true
 feed.released.emit()
 check(card._retry.visible and card._rows.get_child(0).text.contains("Try again"),"cold request failure still offers retry")
 feed.pending = true
 feed.player = {"id":"self","display_name":"Ville"}
 var cached: Dictionary = feed.get_meta("daily_card_standings")
 for key: String in cached: cached[key].sample_msec = Time.get_ticks_msec()-86400000
 card.refresh()
 check(card.summary.is_empty(),"cache cannot cross the event expiry")
 feed.pending = false
 feed.released.emit()
 card.queue_free()
 feed.queue_free()
 await process_frame
 print("DAILY_STANDINGS_ENTRY: 14 checks, %d failures" % failures)
 quit(1 if failures else 0)
