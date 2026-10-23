extends RefCounted
## Only immutable version identifiers cross from a link into the configured API.
const UUID_PATTERN: String = "[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}"

static func version_from(value: String) -> String:
	if value.length() > 2048 or value != value.strip_edges(): return ""
	for character: String in ["\n","\r","\t"," "]:
		if character in value: return ""
	var pattern := RegEx.new()
	pattern.compile("^(?:beatmytrack://track/|https?://[a-zA-Z0-9.\\-]+(?::[0-9]{1,5})?/(?:t/|v1/track-versions/))("+UUID_PATTERN+")/?(?:[?#][^\\s]*)?$")
	var found: RegExMatch = pattern.search(value)
	return found.get_string(1).to_lower() if found != null else ""

static func share_url(metadata: Dictionary, base_url: String) -> String:
	var version: String = str(metadata.get("version_id",""))
	if version_from("beatmytrack://track/"+version).is_empty(): return ""
	var provided: String = str(metadata.get("share_url",""))
	if version_from(provided) == version.to_lower(): return provided.replace("/v1/track-versions/","/t/")
	var link: String = base_url.trim_suffix("/")+"/t/"+version
	return link if version_from(link) == version.to_lower() else "beatmytrack://track/"+version
