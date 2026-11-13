"""Build a task-only patch against reconstructed task-start source copies.

Existing workspace changes are retained in both sides. The header inverse was
prepared by the header author, and the two other agent-owned before copies by
their respective authors. No index operation or workspace source rewrite.
"""
from __future__ import annotations
import difflib
import hashlib
import json
from pathlib import Path
import shutil
import subprocess

ROOT = Path(__file__).resolve().parents[3]
OUT = Path(__file__).resolve().parent
WORK = ROOT / "tmp/editor-usability-checkpoint-20261029"
BEFORE = WORK / "before"
AFTER = WORK / "after"
existing = ["game/core/app.gd", "game/editor/editor_canvas.gd", "game/editor/object_browser.gd", "game/track/desert_road_relief.gd"]
existing += [f"game/localization/{code}.po" for code in ["en","fr","es","de","pt_BR","ja","ko","nl","it","fi","sv","nb"]]
existing += ["game/localization/messages.pot"]
created = ["game/tests/test_editor_fit_and_labels_2026_10_29.gd", "game/tests/test_editor_fit_and_labels_2026_10_29.gd.uid", "game/tests/fixtures/editor_review_user_track.json", "game/tests/test_editor_header_responsive.gd", "game/tests/test_editor_header_responsive.gd.uid", "game/tests/test_object_palette_activation.gd", "game/tests/test_object_palette_activation.gd.uid", "game/tests/test_desert_relief_retirement.gd", "game/tests/test_desert_relief_retirement.gd.uid", "game/tests/profile_editor_practice_return_review.gd", "game/tests/profile_editor_practice_return_review.gd.uid", "scripts/translations/editor_fit_view.tsv"]


def replace_once(text: str, old: str, new: str) -> str:
    if text.count(old) != 1:
        raise ValueError(f"Expected one exact task hunk, found {text.count(old)}: {old[:100]!r}")
    return text.replace(old, new, 1)


def remove_block(text: str, start: str, stop: str) -> str:
    if text.count(start) != 1:
        raise ValueError(f"Expected one start: {start!r}")
    pos = text.index(start)
    return text[:pos] + text[text.index(stop, pos):]


for rel in existing + created:
    target = AFTER / rel
    target.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(ROOT / rel, target)
for rel in existing:
    target = BEFORE / rel
    target.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(ROOT / rel, target)

inverse = ROOT / "docs/evidence/editor-header-responsive-2026-10-29/header-inverse.patch"
subprocess.run(["git","apply","--directory=tmp/editor-usability-checkpoint-20261029/before",str(inverse)],cwd=ROOT,check=True)

app_path = BEFORE / "game/core/app.gd"
app = app_path.read_text(encoding="utf-8")
app = replace_once(app, '\tsurface_toolbar.resized.connect(_layout_editor_surface_toolbar)\n', '\tsurface_toolbar.resized.connect(func() -> void:\n\t\tsurface_toolbar.offset_left = -surface_toolbar.size.x*0.5\n\t\tsurface_toolbar.offset_right = surface_toolbar.size.x*0.5)\n')
app = replace_once(app, '\t# Keep the strip\'s height stable when its controls exceed the available\n\t# width; the row still supports horizontal dragging just like the palette.\n\tproperty_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER\n', '\tproperty_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO\n')
app = remove_block(app, '\tvar fit_view: Button = EditorStyle.button("Fit view",func() -> void:\n', '\tshare_button=EditorStyle.button("Share",_share_dialog)')
for line in ['\tcanvas.fit_area = _editor_fit_area\n', '\tsurface_toolbar.resized.connect(_layout_editor_feedback)\n', '\troot_ui.resized.connect(_layout_editor_feedback)\n', '\troot_ui.resized.connect(_layout_editor_surface_toolbar)\n', '\t_layout_editor_feedback()\n']:
    app = replace_once(app,line,'')
app = remove_block(app, 'func _layout_editor_surface_toolbar() -> void:\n', 'func _editor_panel(parent: Control, node_name: String) -> PanelContainer:\n')
app_path.write_text(app,encoding="utf-8",newline="\n")

canvas_path = BEFORE / "game/editor/editor_canvas.gd"
canvas = canvas_path.read_text(encoding="utf-8")
canvas = replace_once(canvas, '## Optional available area in canvas coordinates, supplied by the editor UI.\nvar fit_area: Callable\n', '')
start = '\t\tvar base: float = scale_factor()\n\t\tif fit_area.is_valid():\n'
end = '\tqueue_redraw()\n\nfunc zoom_by('
pos = canvas.index(start)
old_finish = canvas.index(end,pos)
canvas = canvas[:pos] + '\t\tvar base: float = scale_factor()\n\t\tzoom = clampf(minf((size.x-24) / (bounds.size.x + 24), (size.y-156) / (bounds.size.y + 24)) / base, 0.25, 16.0)\n\t\tpan += size*0.5-to_screen(bounds.get_center())\n' + canvas[old_finish:]
canvas = replace_once(canvas, 'zoom = clampf(zoom * factor, 0.05 if fit_area.is_valid() else 0.25, 16.0)', 'zoom = clampf(zoom * factor, 0.25, 16.0)')
start = '\tvar captions: Dictionary = geometry_caption_rects(piece)\n'
end = '\n\n\tvar accept_rect: Rect2 = piece_accept_rect(piece)'
pos = canvas.index(start); finish = canvas.index(end,pos)
old_caption = '\t\tvar caption: String = geometry_caption(piece,key)\n\t\tvar label_size := Vector2(ThemeDB.fallback_font.get_string_size(caption,HORIZONTAL_ALIGNMENT_LEFT,-1,14).x+12,24)\n\t\tvar label_pos: Vector2 = handle+Vector2(-label_size.x*0.5,24)\n\t\tdraw_style_box(MenuStyle.box(Color("142331"),5),Rect2(label_pos,label_size))\n\t\tdraw_string(ThemeDB.fallback_font,label_pos+Vector2(6,17),caption,HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color.WHITE)\n'
canvas = canvas[:pos]+old_caption+canvas[finish:]
canvas = remove_block(canvas, '## Caption boxes avoid every control and one another while remaining near their\n', 'func _geometry_handle(piece: Dictionary, key: String) -> Vector2:\n')
canvas = replace_once(canvas, '[piece,geometry,size,pan,scale_factor(),document.get("start_line",{})],_layout_geometry_controls.bind(piece,geometry)', '[piece,geometry,size,pan,scale_factor()],_layout_geometry_controls.bind(piece,geometry)')
canvas_path.write_text(canvas,encoding="utf-8",newline="\n")
shutil.copyfile(ROOT / "docs/evidence/editor-review-fixes-2026-10-29/object-placement/before/object_browser.gd.txt",BEFORE / "game/editor/object_browser.gd")
shutil.copyfile(ROOT / "docs/evidence/editor-review-fixes-2026-10-29/performance/desert_road_relief-before.gd.txt",BEFORE / "game/track/desert_road_relief.gd")
for rel in existing:
    if not rel.startswith("game/localization/"): continue
    path = BEFORE / rel
    raw = path.read_bytes()
    marker = b'\r\n#: game/core/app.gd\r\nmsgid "Fit view"\r\nmsgstr ' if b'\r\n' in raw else b'\n#: game/core/app.gd\nmsgid "Fit view"\nmsgstr '
    position = raw.rfind(marker)
    if position < 0: raise ValueError(f"Missing own catalogue block: {rel}")
    path.write_bytes(raw[:position])

patch: list[str] = []
hashes: dict = {}
for rel in existing + created:
    before = (BEFORE / rel).read_bytes() if rel in existing else b""
    after = (AFTER / rel).read_bytes()
    before_lines = before.decode("utf-8").splitlines(keepends=True)
    after_lines = after.decode("utf-8").splitlines(keepends=True)
    for line in difflib.unified_diff(before_lines,after_lines,fromfile="a/"+rel if rel in existing else "/dev/null",tofile="b/"+rel,n=3):
        patch.append(line if line.endswith("\n") else line+"\n\\ No newline at end of file\n")
    hashes[rel] = {"before":hashlib.sha256(before).hexdigest() if rel in existing else None,"after":hashlib.sha256(after).hexdigest()}
(OUT / "task.patch").write_bytes("".join(patch).encode("utf-8"))
(OUT / "checkpoint-hashes.json").write_text(json.dumps(hashes,indent=2)+"\n",encoding="utf-8")
print(f"Wrote task-only patch for {len(existing)} reconstructed source/catalogue files and {len(created)} new files")
