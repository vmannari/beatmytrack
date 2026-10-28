extends RefCounted
## Read-only disclosure. These values never authorize purchases, rewards or deletion.
const Text = preload("res://localization/game_text.gd")
const Client = preload("res://backend/backend_client.gd")

static func valid(data: Variant) -> bool:
	return Client.valid_deletion_preview(data)

static func describe(data: Dictionary) -> String:
	if not valid(data): return ""
	var lines: PackedStringArray = []
	for pair: Array in [["Publishing slots: {count}","publishing_slots"],["Coins: {count}","coins"],["Banked resumes: {count}","banked_resumes"],["Online cosmetic unlocks: {count}","cosmetic_unlocks"]]:
		lines.append(Text.message(pair[0],{"count":int(data[pair[1]])}))
	if data.ad_free_forever:
		lines.append(Text.message("Ad-free access: active, with no scheduled expiry"))
	elif data.ad_free:
		var hours: int = ceili(float(data.ad_free_until-data.server_now)/3600.0)
		var expiry: String = Time.get_datetime_string_from_unix_time(int(data.ad_free_until)).replace("T"," ")+" UTC"
		lines.append(Text.message("Ad-free access: {days} days, {hours} hours remaining (rounded up)\nExpires: {expiry}",{"days":hours/24,"hours":hours%24,"expiry":expiry}))
	else:
		lines.append(Text.message("Ad-free access: none active"))
	if data.pending_purchases > 0:
		lines.append(Text.message("Pending purchases: {count}. Deletion does not cancel a store payment. Contact support about outstanding purchases.",{"count":int(data.pending_purchases)}))
	return "\n".join(lines)
