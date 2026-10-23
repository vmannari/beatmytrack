extends SceneTree
## Retained recovery bytes must not resurrect a transferred draft.
var library_script: Script = preload("res://persistence/track_library.gd")
var checks: int = 0
var failures: int = 0
var folder: String
var original: Dictionary

func _initialize() -> void: run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: "+label)

func fixture(label: String) -> Dictionary:
	var library = library_script.new(folder.path_join(label))
	var doc: Dictionary = original.duplicate(true)
	doc.id = "published_backup_"+label
	doc.name = "Ancient"
	var earlier: Dictionary = doc.duplicate(true)
	earlier.name = "Ancient before edits"
	check(library.save_document(earlier) == OK and library.save_document(doc) == OK,"create older saved recovery: "+label)
	check(library.save_wip(earlier) == OK and library.save_wip(doc) == OK,"create older autosave recovery: "+label)
	var receipt: Dictionary = {"track_id":"00000000-0000-4000-8000-000000000001","version_id":"00000000-0000-4000-8000-000000000002","content_hash":"a".repeat(64)}
	check(library.commit_backend_binding(doc,receipt,"https://fixture.invalid"),"durable server publication binding: "+label)
	return {"library":library,"document":doc,"earlier":earlier}

func write(path: String, content: String) -> void:
	var file := FileAccess.open(path,FileAccess.WRITE)
	file.store_string(content)
	file.close()

func wait_browser(browser: Node) -> void:
	for tick: int in range(240):
		await process_frame
		if not browser.scanning and browser.scan == null: return
	check(false,"draft scan completes")

func capture(label: String) -> void:
	if "--capture" not in OS.get_cmdline_user_args(): return
	for tick: int in range(3): await RenderingServer.frame_post_draw
	var renderer: String = OS.get_environment("BMT_BACKUP_CAPTURE_RENDERER")
	if renderer not in ["gl_compatibility","mobile"]: renderer = "gl_compatibility"
	var destination: String = ProjectSettings.globalize_path("res://../docs/evidence/published-draft-backup-2026-10-19/"+renderer)
	DirAccess.make_dir_recursive_absolute(destination)
	check(root.get_texture().get_image().save_png(destination.path_join(label+".png")) == OK,"capture "+label)

func inspect_owner() -> void:
	var diagnosis: String = OS.get_environment("BMT_ANCIENT_DIAGNOSIS")
	if diagnosis.is_empty(): return
	var info: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(diagnosis))
	var hashes: Dictionary = {}
	for path: String in info.candidates: hashes[path] = FileAccess.get_sha256(path)
	var library = library_script.new(str(info.candidates[0]).get_base_dir())
	var remaining: int = 0
	for item: Dictionary in library.editable_entries(true):
		if item.id == info.job.authoring_id: remaining += 1
	check(remaining == 0,"owner's already-published Ancient is absent from read-only draft scan")
	for path: String in hashes: check(FileAccess.get_sha256(path) == hashes[path],"owner recovery bytes remain untouched")
	print("OWNER_ANCIENT_DRAFTS: "+str(remaining)+"; recovery bytes unchanged")

func run() -> void:
	create_timer(50).timeout.connect(func() -> void: print("FAIL: publication backup deadline"); quit(1))
	var baseline: String = OS.get_environment("BMT_PUBLICATION_BACKUP_BASELINE")
	if not baseline.is_empty(): library_script = load(baseline)
	folder = ProjectSettings.globalize_path("res://../build/published-draft-backup-2026-10-19/fixtures-"+str(Time.get_ticks_usec()))
	original = JSON.parse_string(FileAccess.get_file_as_string("res://../backend/tests/fixtures/verified_oval.json")).document
	var item: Dictionary = fixture("retired")
	var library = item.library
	var doc: Dictionary = item.document
	check(library.cleanup_backend_publication(doc,doc) == OK,"normal acknowledged handoff completes")
	check(not FileAccess.file_exists(library.directory.path_join(str(doc.id)+".json")),"transferred current source is retired")
	check(FileAccess.file_exists(library.directory.path_join(str(doc.id)+".json.bak")),"older different recovery bytes remain available")
	check(not library.load_document(str(doc.id)).is_empty(),"explicit recovery reads still work")
	check(library.editable_entries().is_empty(),"older original/autosave backups do not become fresh drafts")
	check(library.editable_entries(true).is_empty(),"summary scan excludes the same retired backups")
	if not baseline.is_empty():
		inspect_owner()
		print("PUBLISHED_DRAFT_BACKUP_BASELINE: %d checks, %d failures" % [checks,failures])
		quit(1 if failures else 0)
		return
	var host := MarginContainer.new(); root.add_child(host)
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left","right","top","bottom"]: host.add_theme_constant_override("margin_"+side,24)
	var browser := preload("res://ui/draft_browser.gd").new(); browser.library = library; host.add_child(browser)
	await wait_browser(browser)
	check(browser.entries.is_empty() and browser.selection.is_empty() and not browser.detail.visible,"actual Load track view has no stale published card or actions")
	await capture("published-removed")
	var newer: Dictionary = doc.duplicate(true); newer.name = "Ancient — newer local edit"
	check(library.save_wip(newer) == OK,"new unpublished edit remains writable")
	await wait_browser(browser)
	# Let the browser observe the changed library revision before awaiting its scan.
	await process_frame; await wait_browser(browser)
	check(browser.entries.size() == 1 and browser.selection.document.name == newer.name,"actual Load track view retains the newer unpublished edit")
	await capture("newer-edit-preserved")
	host.free()
	var plain: Dictionary = fixture("unpublished")
	DirAccess.remove_absolute(plain.library.directory.path_join(".backend/"+str(plain.document.id)+".json"))
	DirAccess.remove_absolute(plain.library.directory.path_join(str(plain.document.id)+".json"))
	DirAccess.remove_absolute(plain.library.directory.path_join("wip/"+str(plain.document.id)+".json"))
	check(plain.library.editable_entries().size() == 1,"unpublished crash recovery remains a draft")
	var corrupt: Dictionary = fixture("corrupt_primary")
	write(corrupt.library.directory.path_join(str(corrupt.document.id)+".json"),"invalid JSON")
	DirAccess.remove_absolute(corrupt.library.directory.path_join("wip/"+str(corrupt.document.id)+".json"))
	check(corrupt.library.editable_entries().size() == 1,"an unreadable primary retains its recovery draft")
	var pending: Dictionary = fixture("pending_save")
	check(pending.library.cleanup_backend_publication(pending.document,pending.document) == OK,"retire pending-save original")
	write(pending.library.directory.path_join(str(pending.document.id)+".json.tmp"),JSON.stringify(pending.earlier))
	check(pending.library.editable_entries().size() == 1,"an interrupted temporary save retains recovery")
	var bad_binding: Dictionary = fixture("incomplete_binding")
	check(bad_binding.library.cleanup_backend_publication(bad_binding.document,bad_binding.document) == OK,"retire incomplete-binding fixture")
	write(bad_binding.library.directory.path_join(".backend/"+str(bad_binding.document.id)+".json"),"{}")
	check(bad_binding.library.editable_entries().size() == 1,"incomplete binding cannot suppress a recovered draft")
	var later: Dictionary = fixture("later_recovery")
	check(later.library.cleanup_backend_publication(later.document,later.document) == OK,"retire later-recovery fixture")
	await create_timer(1.1).timeout
	write(later.library.directory.path_join(str(later.document.id)+".json.bak"),JSON.stringify(later.earlier))
	check(later.library.editable_entries().size() == 1,"recovery written after publication remains editable")
	inspect_owner()
	print("PUBLISHED_DRAFT_BACKUP: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
