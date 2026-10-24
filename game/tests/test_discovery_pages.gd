extends "res://tests/test_discovery_windows.gd"
## Shared current-protocol fixture. The suite inherits the cursor regressions.
var folder: String
func settle(pages: Node) -> void:
	for _frame: int in range(60):
		await process_frame
		if not pages.loading: break
	for _frame: int in range(3): await process_frame

class PagedClient extends CursorClient:
	var invalid_once: bool = false
	func request_discovery(body: Dictionary, owner: int, random_choice: bool = false) -> Dictionary:
		var result: Dictionary = await super.request_discovery(body,owner,random_choice)
		if invalid_once:
			invalid_once = false
			result.data.items = [{"wrong":"response"}]
		return result
