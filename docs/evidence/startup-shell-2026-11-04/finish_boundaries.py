"""Record the second extraction: lightweight widgets and optional accounting."""
from pathlib import Path
import re

root = Path(__file__).resolve().parents[3]
app_path = root/'game/core/app.gd'
app = app_path.read_text(encoding='utf-8')
app = app.replace('var editor_memory = preload("res://editor/editor_memory.gd").new()',
                  'var editor_memory = preload("res://core/app_memory.gd").new()')
app = app.replace('preload("res://vehicle/effect_render_preparation.gd").trim_cache(self)',
    'if ResourceLoader.has_cached("res://vehicle/effect_render_preparation.gd"): load("res://vehicle/effect_render_preparation.gd").trim_cache(self)')
app = app.replace('CompactDetail.trim_front_cache()',
    'if ResourceLoader.has_cached("res://vehicle/compact_detail.gd"): load("res://vehicle/compact_detail.gd").trim_front_cache()')
# Type tests on optional controls must not cause their parser graph to load.
app = app.replace('if child is TrackBrowser:', 'if child is Control and child.get_script() != null and child.get_script().resource_path == "res://ui/track_browser.gd":')
app = app.replace('\tpreload("res://ui/garage_preview_cache.gd").prefetch_catalogue(get_tree())\n','')
app = app.replace('\tstartup_complete = true\n','\tstartup_complete = true\n\tif DisplayServer.get_name() == "headless": _initial_menu_presented = true\n\telse: RenderingServer.frame_post_draw.connect(_initial_menu_drawn,CONNECT_ONE_SHOT)\n')
app += '\nvar _initial_menu_presented: bool = false\nfunc _initial_menu_drawn() -> void:\n\t_initial_menu_presented = true\n'
# These branches belong to optional destinations, not account restoration.
for path in ('ui/store_page.gd','ui/own_profile_page.gd','ui/rivalry_summary_dialog.gd','ui/rivalry_share_dialog.gd'):
    app = app.replace(f'preload("res://{path}")',f'load("res://{path}")')
app = re.sub(r'(\bvar\s+\w+)\s*:=\s*(load\()',r'\1 = \2',app)
app_path.write_text(app,encoding='utf-8',newline='\n')

path = root/'game/ui/profile_car.gd'
source = path.read_text(encoding='utf-8')
start = source.index('class ProfilePreview extends')
end = source.index('\nfunc _ready()',start)
factory = source.index('\nstatic func make_preview(')
renderer = 'extends RefCounted\n## Native renderer factory, loaded only for a missing authored picture.\n\n'+source[start:end]+source[factory:]
(root/'game/ui/profile_car_renderer.gd').write_text(renderer,encoding='utf-8',newline='\n')
source = source[:start]+source[end:factory]+'''
static func make_preview(vehicle: String, paint: Dictionary, parts: Dictionary) -> Control:
\treturn load("res://ui/profile_car_renderer.gd").make_preview(vehicle,paint,parts)

static func apply_presentation(view: Control) -> void:
\tload("res://ui/profile_car_renderer.gd").apply_presentation(view)

static func repaint_preview(view: Control, paint: Dictionary) -> void:
\tload("res://ui/profile_car_renderer.gd").repaint_preview(view,paint)
'''
path.write_text(source,encoding='utf-8',newline='\n')

path = root/'game/ui/garage_preloader.gd'
source = path.read_text(encoding='utf-8')
source = source.replace('const Studio=preload("res://ui/garage_preloaded_studio.gd")',
    'var Studio: Script:\n\tget: return load("res://ui/garage_preloaded_studio.gd")')
source = source.replace('const Pictures=preload("res://ui/garage_preview_cache.gd")',
    'var Pictures: Script\nconst PICTURE_SCRIPT: String = "res://ui/garage_preview_cache.gd"\nconst ARCHITECTURE: String = "res://assets/garage/workshop_v1.scn"\nvar _picture_load_pending: bool = false')
source = source.replace(': CarShowroom',': Control').replace(':CarShowroom',':Control').replace('-> CarShowroom','-> Control').replace(': GaragePage',': Control').replace(':GaragePage',':Control')
source = source.replace('GarageEnvironment.PREPARED_ARCHITECTURE','ARCHITECTURE')
source = source.replace('preload("res://track/prepared_world_cache.gd")','load("res://track/prepared_world_cache.gd")')
source = source.replace('func _sync_pictures() -> void:\n',
    'func _sync_pictures() -> void:\n\tif Pictures == null: Pictures = load(PICTURE_SCRIPT)\n')
source = source.replace('if not is_instance_valid(app) or not app.startup_complete: return\n',
    'if not is_instance_valid(app) or not app.startup_complete: return\n\tif app.get("_initial_menu_presented") == false or not _picture_script_ready(): return\n')
source = source.replace('if what==NOTIFICATION_PREDELETE and not _pending.is_empty():',
    'if what==NOTIFICATION_PREDELETE and _picture_load_pending:\n\t\t_retire([PICTURE_SCRIPT],_tree_ref)\n\t\t_picture_load_pending=false\n\tif what==NOTIFICATION_PREDELETE and not _pending.is_empty():')
source += '''
func _picture_script_ready() -> bool:
\tif Pictures != null: return true
\tif not _picture_load_pending:
\t\tif ResourceLoader.load_threaded_request(PICTURE_SCRIPT) != OK: return false
\t\t_picture_load_pending = true
\tvar status: int = ResourceLoader.load_threaded_get_status(PICTURE_SCRIPT)
\tif status == ResourceLoader.THREAD_LOAD_IN_PROGRESS: return false
\t_picture_load_pending = false
\tif status != ResourceLoader.THREAD_LOAD_LOADED: return false
\tPictures = ResourceLoader.load_threaded_get(PICTURE_SCRIPT)
\tPictures.prefetch_catalogue(get_tree())
\treturn true
'''
path.write_text(source,encoding='utf-8',newline='\n')
