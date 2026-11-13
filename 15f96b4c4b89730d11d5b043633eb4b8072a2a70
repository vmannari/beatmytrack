"""Reconstruct the pre-header-change version while preserving adjacent work."""
from pathlib import Path
import difflib

root = Path(__file__).resolve().parents[3]
source = root / "game/core/app.gd"
current = source.read_text(encoding="utf-8")
before = current


def replace_once(old, new):
    global before
    assert before.count(old) == 1, old
    before = before.replace(old, new, 1)


replace_once('\ttop.name = "EditorHeaderActions"\n', '')
replace_once('''\t# The right-aligned container is wider than its visible buttons. Empty
\t# space must not intercept the history controls when Issues is hidden.
\ttop.mouse_filter = Control.MOUSE_FILTER_IGNORE
''', '')
replace_once('''\t# Fit the identity/history group into the space left by the right-hand
\t# actions, including the issue button when it appears or disappears.
\tvar fit_header: Callable = _fit_editor_header.bind(overlay,header_left,track_name,creator_label,top)
\toverlay.resized.connect(fit_header)
\ttop.minimum_size_changed.connect(fit_header)
\teditor_issue_button.visibility_changed.connect(fit_header)
\tfit_header.call_deferred()
''', '')
replace_once('''func _fit_editor_header(overlay: Control, header: HBoxContainer, track_title: Label, creator: Label, actions: HBoxContainer) -> void:
\tif not is_instance_valid(overlay) or not is_instance_valid(header) or not is_instance_valid(actions): return
\t# The actions are right anchored, ending 80 px from the right edge. Leave a
\t# small gap before them, shrinking the title only after hiding the creator.
\tvar available: float = maxf(0.0,overlay.size.x-80.0-actions.get_combined_minimum_size().x-header.position.x-8.0)
\ttrack_title.custom_minimum_size.x = 220.0
\tcreator.show()
\tif header.get_combined_minimum_size().x > available:
\t\tcreator.hide()
\t\tvar deficit: float = header.get_combined_minimum_size().x-available
\t\ttrack_title.custom_minimum_size.x = maxf(40.0,220.0-deficit)
\t# A free-standing container otherwise keeps its old, wider size on resize.
\theader.size = header.get_combined_minimum_size()

''', '')
replace_once('''\tsurface_toolbar.visible = category == "paint"
\tif category == "paint":
''', '''\tsurface_toolbar.visible = category == "paint"
\tvar track_title: Label = root_ui.find_child("TrackName",true,false)
\tif track_title != null: track_title.custom_minimum_size.x = 220
\tif category == "paint":
''')

path = root / "docs/evidence/editor-header-responsive-2026-10-29/header-inverse.patch"
patch = ''.join(difflib.unified_diff(current.splitlines(keepends=True), before.splitlines(keepends=True),
                                    fromfile='a/game/core/app.gd', tofile='b/game/core/app.gd'))
path.write_text(patch, encoding='utf-8', newline='\n')
print(path)
