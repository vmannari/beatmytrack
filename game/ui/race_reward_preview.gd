class_name RaceRewardPreview
extends RefCounted
## Provisional presentation only. Never writes currency or entitlements.
const TIERS: Array[Dictionary] = [{"percent":1,"amount":500},{"percent":10,"amount":200},{"percent":25,"amount":100},{"percent":50,"amount":50}]

static func tier(percent: float) -> int:
	if percent <= 0 or percent > 100: return 0
	for item: Dictionary in TIERS:
		if percent <= float(item.percent): return int(item.amount)
	return 0

static func improved_tier(percent: float, best_rewarded_amount: int) -> int:
	var amount: int = tier(percent)
	return amount if amount > best_rewarded_amount else 0

static func build(facts: Dictionary) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	var complete: bool = facts.get("complete",false)
	rows.append(row("Race completed",50,"Eligible" if complete else "Not completed",complete,"flag"))
	rows.append(row("First time on track",50,"Track history unavailable",false,"flag"))
	var race_pb: bool = complete and facts.get("previous",0.0) > 0 and roundi(float(facts.total)*1000) < roundi(float(facts.previous)*1000)
	rows.append(row("New race PB",100,"Eligible" if race_pb else "No new PB",race_pb,"timer"))
	var lap_pb: bool = complete and facts.get("previous_lap",0.0) > 0 and facts.get("flying",0.0) > 0 and roundi(float(facts.flying)*1000) < roundi(float(facts.previous_lap)*1000)
	rows.append(row("New lap PB",100,"Eligible" if lap_pb else "No new flying-lap PB",lap_pb,"timer"))
	for metric: String in ["race","lap"]:
		var percent: float = float(facts.get(metric+"_percentile",-1.0))
		var amount: int = improved_tier(percent,int(facts.get(metric+"_rewarded_tier",0))) if complete else 0
		var status: String = "New tiers only: 50% +50 / 25% +100 / 10% +200 / 1% +500"
		if percent > 0: status = "New percentile tier" if amount > 0 else "No new reward tier"
		rows.append(row("Race percentile tier" if metric == "race" else "Best-lap percentile tier",amount,status,amount > 0,"bars"))
	var clean: bool = complete and facts.get("incident_free",false)
	rows.append(row("Clean race",200,"Eligible" if clean else "No collisions or off-track excursions",clean,"trophy"))
	rows.append(row("Challenge attempted",50,"No active challenge",false,"flag"))
	rows.append(row("Challenge beaten",100,"No active challenge",false,"trophy"))
	return rows

static func row(title: String, amount: int, status: String, eligible: bool, icon: String) -> Dictionary:
	return {"title":title,"amount":amount,"status":status,"eligible":eligible,"icon":icon}

static func total(rows: Array[Dictionary]) -> int:
	var value: int = 0
	for item: Dictionary in rows:
		if item.eligible: value += int(item.amount)
	return value
