extends SceneTree
const Client = preload("res://backend/backend_client.gd")
var checks: int = 0
var failures: int = 0
func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures += 1; print("FAIL: "+label)
func _initialize() -> void:
	var at: int = Time.get_unix_time_from_datetime_string("2026-10-13T12:00:00")
	for date: String in ["Tue, 13 Oct 2026 12:01:00 GMT","Tuesday, 13-Oct-26 12:01:00 GMT","Tue Oct 13 12:01:00 2026"]:
		check(Client._retry_after(PackedStringArray(["Retry-After: "+date]),at) == 60,"all HTTP date forms honor the server's future cooldown")
	check(Client._retry_after(PackedStringArray(["Date: Tue, 13 Oct 2026 12:00:00 GMT","Retry-After: Tue, 13 Oct 2026 12:01:00 GMT"])) == 60,"response Date avoids dependence on the device wall clock")
	check(Client._retry_after(PackedStringArray(["Retry-After: Tue, 13 Oct 2026 11:59:00 GMT"]),at) == 0,"past HTTP date does not create a future cooldown")
	for value: String in ["-1","+60","1.5","nonsense","Tue, 31 Feb 2026 12:01:00 GMT","Tue, 13 Oct 2026 25:00:00 GMT","x".repeat(100)]:
		check(Client._retry_after(PackedStringArray(["Retry-After: "+value]),at) == 0,"invalid Retry-After fails safely: "+value.left(30))
	check(Client._retry_after(PackedStringArray(["retry-after: 120"]),at) == 120,"integer and case-insensitive header remain supported")
	check(Client._retry_after(PackedStringArray(["Retry-After: 9999999999"]),at) == 3600,"untrusted cooldown retains the existing one-hour bound")
	check(Client._retry_after(PackedStringArray(["Retry-After: 0"]),at) == 0,"zero seconds is an immediately eligible retry")
	var future: int = Time.get_unix_time_from_datetime_string("2076-10-13T12:00:00")
	check(Client._http_date("Sunday, 06-Nov-94 08:49:37 GMT",future) == Time.get_unix_time_from_datetime_string("2094-11-06T08:49:37"),"obsolete two-digit year is interpreted relative to the reference century")
	check(Client._http_date("Sunday, 06-Nov-94 08:49:37 GMT",at) == Time.get_unix_time_from_datetime_string("1994-11-06T08:49:37"),"obsolete two-digit year over fifty years ahead resolves into the previous century")
	var century: int = Time.get_unix_time_from_datetime_string("2095-01-01T00:00:00")
	check(Client._http_date("Saturday, 01-Jan-01 00:00:00 GMT",century) == Time.get_unix_time_from_datetime_string("2101-01-01T00:00:00"),"fifty-year interpretation handles an upcoming century")
	check(Client._http_date("Tuesday, 13-Oct-76 12:00:00 GMT",at) == Time.get_unix_time_from_datetime_string("2076-10-13T12:00:00"),"exact fifty-year boundary retains the future century")
	check(Client._http_date("Tuesday, 13-Oct-76 12:00:01 GMT",at) == Time.get_unix_time_from_datetime_string("1976-10-13T12:00:01"),"one second beyond fifty years resolves to the most recent past year")
	print("HTTP_RETRY: ",checks," checks, ",failures," failures")
	quit(1 if failures > 0 else 0)
