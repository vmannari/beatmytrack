"""Creator landing pages do not require the native authoring canvas."""
from pathlib import Path
import re
root = Path(__file__).resolve().parents[3]
editor_path = root/'game/core/features/editor.gd'
editor = editor_path.read_text(encoding='utf-8')
shell_path = root/'game/core/app.gd'
shell = shell_path.read_text(encoding='utf-8')
blocks = []
names = ['_new_document','_start_new_document','_choose_biome','_size_creation_biome_description',
         '_preview_creation_biome','_update_creation_biome','_select_creation_biome','_notify_creation_slots']
for name in names:
    pattern = r'^static func '+name+r'\([\s\S]*?(?=^static func |\Z)'
    match = re.search(pattern,editor,re.M)
    assert match,name
    blocks.append(match.group())
    editor = editor[:match.start()]+editor[match.end():]
    wrapper = re.search(r'^func '+name+r'\([\s\S]*?(?=^func |^var |^const |\Z)',shell,re.M)
    assert wrapper,name
    text = wrapper.group().replace('res://core/features/editor.gd','res://core/features/creator.gd')
    shell = shell[:wrapper.start()]+text+shell[wrapper.end():]
editor_path.write_text(editor,encoding='utf-8',newline='\n')
shell_path.write_text(shell,encoding='utf-8',newline='\n')
(root/'game/core/features/creator.gd').write_text('extends RefCounted\n## Creator landing UI; the native editor loads only when a document opens.\n\n'+''.join(blocks),encoding='utf-8',newline='\n')
