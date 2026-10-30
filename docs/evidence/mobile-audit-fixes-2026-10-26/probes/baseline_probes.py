from pathlib import Path
out=Path('build/mobile-audit-fixes-2026-10-26')
paths=['ui/car_showroom.gd','ui/garage_reflections.gd','ui/garage_page.gd','ui/race_pause_menu.gd','ui/settings_page.gd','editor/track_document.gd','race/attempt_evidence.gd','backend/cloud_tracks.gd','core/app.gd']
restore='\nfunc restore_task_start() -> void:\n'
for i,path in enumerate(paths):
    restore+=f'\tvar before_{i}: GDScript = load("res://{path}")\n\tbefore_{i}.source_code = FileAccess.get_file_as_string("res://../build/mobile-audit-fixes-2026-10-26/before/game/{path}")\n\tassert(before_{i}.reload(true)==OK)\n'
restore+='\tprint("ISOLATED_TASK_START_SOURCES: 9 exact scripts restored only in this process memory")\n'
for test in ['test_first_play_tutorial','test_editor_practice','test_backend_exception_recovery','test_resume_recovery_budget','test_gameplay_f13_f16_f19_f24']:
    source=Path('game/tests/'+test+'.gd').read_text(encoding='utf-8-sig')
    deadline = '\n\tcreate_timer(25).timeout.connect(func() -> void: print("BASELINE_FAILURE_DEADLINE");quit(1))' if test in ['test_backend_exception_recovery','test_resume_recovery_budget'] else ''
    source=source.replace('func run() -> void:', 'func run() -> void:\n\trestore_task_start()'+deadline,1)+restore
    if test=='test_resume_recovery_budget':
        start=source.index('\nfunc restore_task_start() -> void:')
        source=source[:start]+'\nfunc restore_task_start() -> void:\n\tvar before: GDScript = load("res://backend/cloud_tracks.gd")\n\tbefore.source_code = FileAccess.get_file_as_string("res://../build/mobile-audit-fixes-2026-10-26/before/game/backend/cloud_tracks.gd")\n\tassert(before.reload(true)==OK)\n\tprint("ISOLATED_TASK_START_SOURCE: exact Cloud script only; no App/UI dependencies")\n'
    (out/(test+'_baseline.gd')).write_text(source,encoding='utf-8')
# The historical folder test expects pre-landing-page tabs. Reproduce its actual
# scene mismatch independently with both exact baseline and current UI scripts.
base='''extends SceneTree
func _initialize() -> void: run.call_deferred()
func run() -> void:
    RESTORE
    var app: Node = load("res://core/app.tscn").instantiate()
    var folder: String = "user://folder-baseline-"+TrackLibrary.unique_id()
    app.records = LocalRecords.new(folder.path_join("records.json"))
    app.library = TrackLibrary.new(folder.path_join("tracks"))
    app.cloud_root_override = folder.path_join("cloud")
    root.add_child(app)
    while not app.startup_complete: await process_frame
    app.challenges.folder = "received"
    app._show_screen("challenges")
    app._stop_menu_page_motion()
    var page: Control = app.content.find_child("ChallengesPage",true,false)
    print("FOLDER_FIXTURE landing=",page.landing_view," tab_sent=",page.find_child("ChallengeTab_sent",true,false)!=null)
    app.queue_free()
    await process_frame
    quit()
'''
for before in (False,True):
    source=base.replace('    RESTORE','    restore_task_start()' if before else '    pass').replace('    ','\t')+(restore if before else '')
    (out/('folder-before.gd' if before else 'folder-current.gd')).write_text(source,encoding='utf-8')
