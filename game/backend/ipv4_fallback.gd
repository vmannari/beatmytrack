extends RefCounted
## Probe only TCP before sending HTTP. Never replay a possibly delivered write.
const CACHE_MS: int = 60000
const CONNECT_MS: int = 350
var _routes: Dictionary = {}

func route(origin: String, tree: SceneTree) -> Dictionary:
	if not origin.begins_with("https://"): return {}
	var authority: String = origin.trim_prefix("https://").get_slice("/", 0)
	# Literal addresses already select their family; keep their normal TLS rules.
	if authority.begins_with("["): return {}
	var host: String = authority.get_slice(":", 0)
	if host.is_valid_ip_address(): return {}
	var port: int = int(authority.get_slice(":", 1)) if ":" in authority else 443
	if _routes.has(origin) and Time.get_ticks_msec() < int(_routes[origin].expires):
		return _routes[origin].value.duplicate()
	var addresses: PackedStringArray = await _addresses(host, tree)
	var ipv4: String = ""
	var ipv6: String = ""
	for address: String in addresses:
		if ":" in address and ipv6.is_empty(): ipv6 = address
		elif not ":" in address and ipv4.is_empty(): ipv4 = address
	var value: Dictionary = {}
	if not ipv4.is_empty() and not ipv6.is_empty() and not await _ipv6_reachable(ipv6, port, tree):
		value = {"url": "https://" + ipv4 + (":" + str(port) if port != 443 else "") + origin.trim_prefix("https://" + authority), "host": host, "authority": authority}
	if _routes.size() >= 8: _routes.clear()
	_routes[origin] = {"expires": Time.get_ticks_msec() + CACHE_MS, "value": value}
	return value.duplicate()

func _addresses(host: String, tree: SceneTree) -> PackedStringArray:
	var query: int = IP.resolve_hostname_queue_item(host, IP.TYPE_ANY)
	if query == IP.RESOLVER_INVALID_ID: return PackedStringArray()
	var deadline: int = Time.get_ticks_msec() + 2000
	while IP.get_resolve_item_status(query) == IP.RESOLVER_STATUS_WAITING and Time.get_ticks_msec() < deadline:
		await tree.process_frame
	var result: PackedStringArray = IP.get_resolve_item_addresses(query) if IP.get_resolve_item_status(query) == IP.RESOLVER_STATUS_DONE else PackedStringArray()
	IP.erase_resolve_item(query)
	return result

func _ipv6_reachable(address: String, port: int, tree: SceneTree) -> bool:
	var socket := StreamPeerTCP.new()
	if socket.connect_to_host(address, port) != OK: return false
	var deadline: int = Time.get_ticks_msec() + CONNECT_MS
	while Time.get_ticks_msec() < deadline:
		socket.poll()
		if socket.get_status() != StreamPeerTCP.STATUS_CONNECTING: break
		await tree.process_frame
	var connected: bool = socket.get_status() == StreamPeerTCP.STATUS_CONNECTED
	socket.disconnect_from_host()
	return connected
