"""Prepare a minimal project for the pinned engine's SVG import and inspection."""
from pathlib import Path
import shutil
import xml.etree.ElementTree as ET

REPO = Path(__file__).resolve().parents[3]
PROJECT = REPO / "build/menu-logo-svg-review/import"
ET.register_namespace("", "http://www.w3.org/2000/svg")
(PROJECT / "assets/menu").mkdir(parents=True, exist_ok=True)
(PROJECT / "project.godot").write_text(
    'config_version=5\n[application]\nconfig/name="Menu SVG import"\n'
    '[rendering]\nrenderer/rendering_method="gl_compatibility"\n'
)
for suffix in ("svg", "svg.import"):
    shutil.copy2(REPO / f"game/assets/menu/logo.{suffix}", PROJECT / f"assets/menu/logo.{suffix}")
for kind, keep in (("mark", "b-mark"), ("text", "wordmark")):
    layer = ET.parse(REPO / "game/assets/menu/logo.svg").getroot()
    for item in list(layer):
        if item.tag.endswith("g") and item.attrib.get("id") != keep:
            layer.remove(item)
    (PROJECT / f"{kind}.svg").write_text(ET.tostring(layer, encoding="unicode"))
(PROJECT / "audit.gd").write_text('''extends SceneTree
func _initialize() -> void:
    var result: Dictionary = {}
    for kind: String in ["mark", "text"]:
        var picture := Image.new()
        var error := picture.load_svg_from_string(FileAccess.get_file_as_string("res://" + kind + ".svg"))
        if error != OK:
            quit(1)
            return
        var bounds := picture.get_used_rect()
        result[kind] = {"x":bounds.position.x,"y":bounds.position.y,"width":bounds.size.x,"height":bounds.size.y,"bottom":bounds.end.y}
    print("LOGO_ALIGNMENT: " + JSON.stringify(result))
    var file := FileAccess.open("res://../../../docs/evidence/menu-logo-svg-2026-10-29/alignment.json",FileAccess.WRITE)
    file.store_string(JSON.stringify(result,"  "))
    quit(0 if result.mark.y == result.text.y and result.mark.bottom == result.text.bottom else 1)
''')
print(f"Prepared SVG-only project at {PROJECT}")
