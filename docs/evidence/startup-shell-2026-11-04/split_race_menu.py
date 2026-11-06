"""Keep Free Race independent of Rivalry's native podium presenters."""
from pathlib import Path
import re
root = Path(__file__).resolve().parents[3]
module_path = root/'game/core/features/menu.gd'
source = module_path.read_text(encoding='utf-8')
shell_path = root/'game/core/app.gd'
shell = shell_path.read_text(encoding='utf-8')
groups = {}
for match in re.finditer(r'^static func (\w+)\([\s\S]*?(?=^static func |\Z)',source,re.M):
    name = match[1]
    if name == '_track_of_day': group = 'daily'
    elif name in ('_tracks','_ensure_track_catalog'): group = 'tracks'
    elif name in ('_settings','_customize_controls'): group = 'settings'
    elif 'selected_preparation' in name or name in ('_prepare_selected_track','_begin_selected_geometry'): group = 'selected_track'
    elif name in ('_rivalry','_prepare_rivalry_track_preview','_rivalry_ghost','_start_rivalry_race'): group = 'rivalry'
    else: group = 'challenges'
    groups.setdefault(group,[]).append(match.group())
    wrapper = re.search(r'^func '+name+r'\([\s\S]*?(?=^func |^var |^const |\Z)',shell,re.M)
    assert wrapper,name
    text = wrapper.group().replace('res://core/features/menu.gd',f'res://core/features/{group}.gd')
    shell = shell[:wrapper.start()]+text+shell[wrapper.end():]
for group,blocks in groups.items():
    text = ''.join(blocks)
    alias = 'const RaceLoading = preload("res://ui/race_loading.gd")\n' if 'RaceLoading' in text else ''
    (module_path.parent/(group+'.gd')).write_text('extends RefCounted\n## '+group.replace('_',' ').title()+' composition; state and callbacks remain owned by App.\n'+alias+'\n'+text,encoding='utf-8',newline='\n')
shell_path.write_text(shell,encoding='utf-8',newline='\n')
print({key:len(value) for key,value in groups.items()})
