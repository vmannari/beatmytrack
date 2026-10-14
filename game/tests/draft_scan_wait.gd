extends RefCounted
## Await the actual asynchronous gallery state without hiding failed assertions.
static func ready(tree: SceneTree, browser: Node) -> bool:
	var deadline: int = Time.get_ticks_msec()+15000
	while is_instance_valid(browser) and bool(browser.get("scanning")) and Time.get_ticks_msec()<deadline:
		await tree.process_frame
	return is_instance_valid(browser) and not bool(browser.get("scanning"))
