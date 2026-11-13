"""Observation-only source overlays for a task-owned frozen project, never shipping."""
from pathlib import Path
import hashlib
import json

OUT = Path(__file__).resolve().parent
ROOT = OUT.parents[3]


def replace_once(text, old, new):
    if text.count(old) != 1:
        raise ValueError(f'Expected one instrumentation anchor ({text.count(old)}): {old!r}')
    return text.replace(old,new,1)


def instrument(project):
    """Return changed text without writing; this also validates every source anchor."""
    changes = {}
    path = 'ui/garage_opening_showroom.gd'
    text = (project/path).read_text(encoding='utf-8')
    text = replace_once(text,'var _first: Node\n','var _first: Node\nvar _evidence_previous_us: int = 0\n')
    for old,new in [
        ('\topening_started=Time.get_ticks_usec()','\topening_started=Time.get_ticks_usec()\n\t_evidence_phase("opening")'),
        ('func _begin_studio() -> void:\n','func _begin_studio() -> void:\n\t_evidence_phase("entry_wait_begin")\n'),
        ('\tfor path: String in _loads:\n','\t_evidence_phase("entry_drawn")\n\tfor path: String in _loads:\n'),
        ('\t_loads.clear()\n\tcooperative_build=true','\t_loads.clear()\n\t_evidence_phase("resources_ready")\n\tcooperative_build=true'),
        ('\tawait super._ready()\n\tif not is_inside_tree() or is_queued_for_deletion(): return','\tawait super._ready()\n\tif not is_inside_tree() or is_queued_for_deletion(): return\n\t_evidence_phase("showroom_built")'),
        ('\t\tvar first: Node=FirstDraw.new()','\t\t_evidence_phase("warm_setup_ready")\n\t\tvar first: Node=FirstDraw.new()'),
        ('\t\tfirst.hold(camera.get_parent())','\t\tfirst.hold(camera.get_parent())\n\t\t_evidence_phase("native_queue_ready",{"pending":first.pending.size()})'),
        ('\t\tfirst.release()','\t\t_evidence_phase("native_warm_complete",{"groups":first.frame_groups})\n\t\tfirst.release()'),
        ('\t\tfor _settle: int in range(4):','\t\t_evidence_phase("full_settle_begin")\n\t\tfor _settle: int in range(4):'),
        ('\t\t\tawait get_tree().process_frame\n\t\tif not _current_studio(): return','\t\t\tawait get_tree().process_frame\n\t\t\t_evidence_phase("full_settle_"+str(_settle))\n\t\tif not _current_studio(): return'),
        ('\t\t\tgraphics.finish_capture(capture,camera.get_parent(),showroom_viewport,camera)','\t\t\tgraphics.finish_capture(capture,camera.get_parent(),showroom_viewport,camera)\n\t\t\t_evidence_phase("receipts_published")'),
        ('\tprint("GARAGE_LIVE_READY_MS ",live_ready_ms)','\t_evidence_phase("live_ready")\n\tprint("GARAGE_LIVE_READY_MS ",live_ready_ms)'),
    ]: text = replace_once(text,old,new)
    text += '''
func _evidence_phase(phase: String, extra: Dictionary = {}) -> void:
\tvar stamp: int = Time.get_ticks_usec()
\tvar graphics: Script = preload("res://rendering/graphics_preparation.gd")
\tvar row: Dictionary = {"phase":phase,"engine_ms":stamp/1000.0,"opening_ms":(stamp-opening_started)/1000.0,"phase_ms":(stamp-_evidence_previous_us)/1000.0 if _evidence_previous_us else 0.0,"sky_exists":ShowroomStudio.cached_sky != null,"sky_id":ShowroomStudio.cached_sky.get_instance_id() if ShowroomStudio.cached_sky != null else 0,"receipts":graphics.warmed.size(),"receipt_hits":graphics.hits,"receipt_submissions":graphics.submissions,"receipt_generation":graphics.generation}
\trow.merge(extra)
\tprint("GARAGE_TRADEOFF_PHASE ",JSON.stringify(row))
\t_evidence_previous_us = Time.get_ticks_usec()
'''
    changes[path] = text

    path = 'ui/car_showroom.gd'
    text = (project/path).read_text(encoding='utf-8')
    for old,new in [
        ('\tif cooperative_build: viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED\n\tworld.add_child(car)\n','\tif cooperative_build: viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED\n\tif has_method("_evidence_phase"): call("_evidence_phase","car_build_begin")\n\tworld.add_child(car)\n'),
        ('\tif garage_mode: turntable = GarageEnvironment.build(world, car, read_only and not preview_live_lighting)','\tif has_method("_evidence_phase"): call("_evidence_phase","car_model_ready")\n\tif garage_mode: turntable = GarageEnvironment.build(world, car, read_only and not preview_live_lighting)'),
        ('\telse: ShowroomStudio.build(world,car)\n','\telse: ShowroomStudio.build(world,car)\n\tif has_method("_evidence_phase"): call("_evidence_phase","studio_geometry_ready")\n'),
        ('\t\treflections.build(self,world,turntable)\n','\t\treflections.build(self,world,turntable)\n\tif has_method("_evidence_phase"): call("_evidence_phase","reflections_ready")\n'),
    ]: text = replace_once(text,old,new)
    changes[path] = text

    path = 'ui/garage_first_draw.gd'
    text = (project/path).read_text(encoding='utf-8')
    text = replace_once(text,'\t\tif not is_instance_valid(instance.get_ref()): return false\n\t\t_clear_copies()',
        '\t\tif not is_instance_valid(instance.get_ref()): return false\n\t\tprint("GARAGE_TRADEOFF_NATIVE ",JSON.stringify({"engine_ms":Time.get_ticks_usec()/1000.0,"draw_ms":(Time.get_ticks_usec()-began)/1000.0,"programs":groups.size(),"objects":submitted.size(),"pending":pending.size(),"batch_limit":_batch_programs,"receipt_hits":Key.hits,"receipt_submissions":Key.submissions,"drawn":drawn}))\n\t\t_clear_copies()')
    changes[path] = text

    path = 'ui/garage_preloader.gd'
    text = (project/path).read_text(encoding='utf-8')
    text = replace_once(text,'\t\tstudio=Studio.new()','\t\t_evidence_preload("studio_create")\n\t\tstudio=Studio.new()')
    text = replace_once(text,'func take() -> Control:\n','func take() -> Control:\n\t_evidence_preload("take")\n')
    text = replace_once(text,'func evict() -> void:\n','func evict() -> void:\n\t_evidence_preload("evict",{"stack":get_stack()})\n')
    for old,new in [
        ('\t\t_reset()\n\t\treturn\n\tif app.get("_initial_menu_presented")','\t\t_reset(false,"header_priority")\n\t\treturn\n\tif app.get("_initial_menu_presented")'),
        ('\t\t_reset()\n\t\t# Consume outstanding threaded reads','\t\t_reset(false,"active_game_or_garage")\n\t\t# Consume outstanding threaded reads'),
        ('\t\t\t_reset()\n\t\t\t_pin=current','\t\t\t_reset(false,"appearance_pin_changed")\n\t\t\t_pin=current'),
        ('\t\t_reset(true)\n','\t\t_reset(true,"incomplete_or_stale_take")\n'),
        ('\t_reset()\n\tset_process(not _pending.is_empty())','\t_reset(false,"eviction")\n\tset_process(not _pending.is_empty())'),
    ]: text = replace_once(text,old,new)
    text = replace_once(text,'func _reset(retain_assets_for_entry: bool=false) -> void:\n','func _reset(retain_assets_for_entry: bool=false, evidence_reason: String="unclassified") -> void:\n\tif is_instance_valid(studio) or not _resources.is_empty(): _evidence_preload("reset",{"retain_assets":retain_assets_for_entry,"reason":evidence_reason})\n')
    # Both explicit and idle picture-script loads are independently visible.
    text = replace_once(text,'\n\t\tPictures = load(PICTURE_SCRIPT)\n','\n\t\t_evidence_preload("explicit_picture_script_begin")\n\t\tPictures = load(PICTURE_SCRIPT)\n\t\t_evidence_preload("explicit_picture_script_ready")\n')
    text = replace_once(text,'\n\tPictures = load(PICTURE_SCRIPT)\n','\n\t_evidence_preload("idle_picture_script_begin")\n\tPictures = load(PICTURE_SCRIPT)\n\t_evidence_preload("idle_picture_script_ready")\n')
    text += '''
func _evidence_preload(event: String, extra: Dictionary = {}) -> void:
\tvar row: Dictionary = {"event":event,"engine_ms":Time.get_ticks_usec()/1000.0,"screen":app.screen if is_instance_valid(app) else "gone","has_studio":is_instance_valid(studio),"prepared":studio.prepared if is_instance_valid(studio) else false,"warming":studio.warming if is_instance_valid(studio) else false,"warm_draws":studio.warm_draws if is_instance_valid(studio) else 0,"resources":_resources.size(),"pending":_pending.size(),"foreground":foreground,"idle_ms":Time.get_ticks_msec()-last_input}
\tif is_instance_valid(app):
\t\trow.pressure_requested = app.editor_memory.pressure_requested
\t\trow.retained_bytes = app.editor_memory.telemetry.get("retained_bytes",0)
\t\trow.optional_garage_bytes = app.editor_memory.telemetry.get("optional_garage_bytes",0)
\trow.merge(extra)
\tprint("GARAGE_TRADEOFF_PRELOADER ",JSON.stringify(row))
'''
    changes[path] = text

    path = 'ui/garage_preloaded_studio.gd'
    text = (project/path).read_text(encoding='utf-8')
    text = replace_once(text,'\twarming=true\n','\twarming=true\n\tprint("GARAGE_TRADEOFF_PRELOAD_WARM ",JSON.stringify({"event":"begin","engine_ms":Time.get_ticks_usec()/1000.0,"pending":_pending.size(),"warm_draws":warm_draws}))\n')
    text = replace_once(text,'\twarming=false\n\tif not adopted: _stop_draws()','\tprint("GARAGE_TRADEOFF_PRELOAD_WARM ",JSON.stringify({"event":"end","engine_ms":Time.get_ticks_usec()/1000.0,"pending":_pending.size(),"warm_draws":warm_draws,"prepared":prepared,"max_draw_ms":max_draw_ms}))\n\twarming=false\n\tif not adopted: _stop_draws()')
    changes[path] = text

    path = 'tests/profile_loading_half.gd'
    text = (project/path).read_text(encoding='utf-8')
    text = replace_once(text,'"ready_ms":(ready-began)/1000.0,"max_frame_ms":max_frame_ms}',
        '"ready_ms":(ready-began)/1000.0,"engine_to_ready_ms":ready/1000.0,"max_frame_ms":max_frame_ms}')
    changes[path] = text

    # A disabled-cache control must not issue an unused raw-image readback.
    # Both arms use this same source; the true path is byte-for-byte unchanged.
    path = 'ui/rivalry_cached_podium.gd'
    text = (project/path).read_text(encoding='utf-8')
    text = replace_once(text,'\t_live.reuse_picture = true','\t_live.reuse_picture = Pictures.enabled')
    changes[path] = text
    return changes


def install(project):
    project = project.resolve()
    assert project.is_relative_to((ROOT/'build/loading-half-20261106').resolve())
    assert project != (ROOT/'game').resolve()
    changes = instrument(project)
    manifest = {}
    for relative,text in changes.items():
        path = project/relative
        before = path.read_bytes()
        path.write_text(text,encoding='utf-8',newline='\n')
        manifest[relative] = {'before':hashlib.sha256(before).hexdigest(),'instrumented':hashlib.sha256(path.read_bytes()).hexdigest()}
    (project/'tests/profile_garage_tradeoff.gd').write_text((OUT/'profile_garage_tradeoff.gd').read_text(),encoding='utf-8')
    return manifest
