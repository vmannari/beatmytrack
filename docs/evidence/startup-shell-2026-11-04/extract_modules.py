"""One-time, auditable extraction from the recorded task-start App.

Runtime modules are ordinary GDScript; this is not a build-time generator.
Only unqualified App state/callbacks and Node ownership operations are qualified.
Strings, comments, domain types and local names retain their meaning.
"""
import json
from pathlib import Path
import re

evidence = Path(__file__).resolve().parent
root = evidence.parents[2]
source = (evidence/'before/game/core/app.gd').read_text(encoding='utf-8').replace('\r\n','\n')
starts = list(re.finditer(r'^(?:static )?func (\w+)\(',source,re.M))
functions = {}
for i, match in enumerate(starts):
    end = starts[i+1].start() if i+1 < len(starts) else len(source)
    declaration = re.search(r'^(?:var|const) \w+',source[match.end():end],re.M)
    if declaration: end = match.end()+declaration.start()
    block = source[match.start():end]
    functions[match[1]] = (source[:match.start()].count('\n')+1,block)
fields = set(re.findall(r'^(?:var|const) (\w+)',source,re.M))
methods = set(functions)
native = set('add_child remove_child get_tree get_viewport get_window get_node get_node_or_null get_parent get_script get_instance_id is_inside_tree is_queued_for_deletion create_tween call_deferred set_process set_process_input set_process_unhandled_key_input queue_free get_children find_child find_children has_meta get_meta set_meta'.split())
tokens = re.compile(r'(?P<string>"""[\s\S]*?"""|\'\'\'[\s\S]*?\'\'\'|"(?:\\.|[^"\\])*"|\'(?:\\.|[^\'\\])*\')|(?P<comment>\#[^\n]*)|(?P<name>\b[A-Za-z_]\w*\b)|(?P<other>[^A-Za-z_\'"#]+)',re.M)

def module_for(name,line):
    if name == '_ad_play_active': return None
    if name in ('_queue_editor_preview','_objects_only_edit','_unhandled_key_input') or 3120 <= line < 4470 or 5488 <= line < 5545 or 5606 <= line < 6508 or line >= 6600:
        return 'editor'
    if name in ('_load_daily_limits','_daily_results','_retry_daily_race') or 4511 <= line < 5468:
        return 'race'
    if 2875 <= line < 3048:
        return 'garage'
    if 1088 <= line < 1113 or 1709 <= line < 1760 or 1772 <= line < 1867 or 1906 <= line < 1986 or 2096 <= line < 2288 or 2383 <= line < 2478 or 2647 <= line < 2769 or name in ('_settings','_customize_controls'):
        return 'menu'
    return None

mapping = {name:module_for(name,line) for name,(line,_) in functions.items()}
mapping = {name:module for name,module in mapping.items() if module}
shadow_report = {}

def qualify(name,block):
    header,body = block.split('\n',1)
    params = set(re.findall(r'\b(\w+)\s*:',header.split('(',1)[1]))
    local = params | set(re.findall(r'\bvar\s+(\w+)|\bfor\s+(\w+)\s*(?::|in\b)',body))
    local = params | {value for item in local for value in (item if isinstance(item,tuple) else (item,)) if value}
    # Lambda arguments have their own scope. Existing App names are not
    # shadowed by any such argument (checked in the extraction receipt).
    lambda_params = set()
    for signature in re.findall(r'func\s*\(([^)]*)\)',body):
        lambda_params.update(re.findall(r'\b(\w+)\s*:',signature))
    shadow_report[name] = {'locals_shadowing_app':sorted((local|lambda_params)&(fields|methods)),
                         'lambda_shadowing_app':sorted(lambda_params&(fields|methods))}
    names = (fields|methods|native)-local
    result = []
    previous = ''
    for token in tokens.finditer(body):
        text = token.group()
        if token.lastgroup == 'name':
            if text == 'self': text = 'app'
            elif text in names and not previous.rstrip().endswith('.'):
                type_context = previous.rstrip().endswith((':','->')) or previous.strip() in ('as','is')
                if text not in ('RaceLoading','ObjectControls','PublicationPrompt') or not type_context: text = 'app.'+text
        result.append(text)
        if token.lastgroup not in ('comment',) and text.strip(): previous = text
    body = ''.join(result)
    # App is a Node boundary; explicitly typed locals remain typed. Constructor
    # inference remains useful, while calls across that boundary return Variant.
    body = re.sub(r'(\bvar\s+\w+)\s*:=',r'\1 =',body)
    args = header[header.index('(')+1:header.rindex(')')]
    return 'static func '+name+'(app: Node'+(', '+args if args.strip() else '')+')'+header[header.rindex(')')+1:]+'\n'+body

# Lazy feature resources are deliberately stored as strings in the shell.
prefix = source[:starts[0].start()]
constants = {}
for match in re.finditer(r'^const (\w+)(?:\s*:[^=\n]+)?\s*=\s*preload\("([^"]+)"\)\s*$',prefix,re.M):
    name,path = match.groups()
    if name not in ('AccountController','ProductTelemetry','LoadingFacts'):
        constants[name] = path
        replacement = f'var {name}: Script:\n\tget: return _feature_resource("{path}")'
        if path.endswith('.tscn'): replacement = f'var {name}: PackedScene:\n\tget: return _feature_resource("{path}")'
        prefix = prefix.replace(match.group(),replacement)

groups = {key:[] for key in ('race','editor','garage','menu')}
shell = [prefix]
for index,(name,(line,block)) in enumerate(functions.items()):
    module = mapping.get(name)
    if not module:
        next_start = starts[index+1].start() if index+1 < len(starts) else len(source)
        shell.append(block+source[starts[index].start()+len(block):next_start])
        continue
    groups[module].append(qualify(name,block))
    header = block.split('\n',1)[0]
    args = header[header.index('(')+1:header.rindex(')')]
    # Top-level commas occur only between arguments in these declarations.
    names = re.findall(r'(?:^|,\s*)(\w+)\s*:',args)
    call = f'_feature_resource("res://core/features/{module}.gd").{name}(self'+(' ,'+', '.join(names) if names else '')+')'
    is_async = bool(re.search(r'\bawait\b',block))
    # Calling async functions without awaiting is valid for fire-and-forget
    # void callbacks; yielding wrappers preserve the original await contract.
    command = ('await ' if is_async else '')+call
    returns_void = header.endswith('-> void:')
    guard = ''
    if name == '_close_race_loading': guard = '\tif not is_instance_valid(race_loading): return\n'
    if name == '_cancel_selected_preparation': guard = '\tif not _selected_preparation_pending and _selected_preparation_job == null: return\n'
    if name == '_poll_selected_preparation': guard = '\tif not _selected_preparation_pending: return\n'
    if name == '_flush_editor_writes': guard = '\tif not _feature_resources.has("res://core/features/editor.gd"): return\n'
    if name == '_apply_editor_writes' or name == '_apply_editor_commits': guard = '\tif not _feature_resources.has("res://core/features/editor.gd"): return\n'
    if name == '_park_garage': guard = '\tif not is_instance_valid(_retained_garage): return\n'
    if name == '_garage_residency': guard = '\tif not is_instance_valid(_retained_garage): return {}\n'
    if name == '_trim_hidden_garage': guard = '\tif not is_instance_valid(_retained_garage): return\n'
    shell.append(header+'\n'+guard+'\t'+('' if returns_void else 'return ')+command+'\n\n')
    next_start = starts[index+1].start() if index+1 < len(starts) else len(source)
    shell.append(source[starts[index].start()+len(block):next_start])

shell = ''.join(shell)
# Polling authoring transactions is only necessary after that feature has
# entered; startup must not compile native editor-world presenters for it.
old_process = functions['_process'][1]
tail_start = old_process.index('\teditor_commits.poll()')
tail = old_process[tail_start:]
memory_line = '\tif screen == "create" or is_instance_valid(_retained_garage) or (is_instance_valid(_garage_preloader) and _garage_preloader.has_work()) or editor_memory.pressure_requested: editor_memory.tick(self)\n'
tail = tail.replace(memory_line,'')
groups['editor'].append(qualify('_poll_editor_frame','func _poll_editor_frame() -> void:\n'+tail))
new_process = old_process[:tail_start]+memory_line+'\tif _feature_resources.has("res://core/features/editor.gd"):\n\t\t_feature_resources["res://core/features/editor.gd"]._poll_editor_frame(self)\n\n'
shell = shell.replace(old_process,new_process)
# Optional presentation types must not reintroduce their scripts into shell parse.
optional_types = {'GaragePage':'Control','WeeklyRivalryPage':'Control','EditorCanvas':'Control','EditorWorld':'Node3D',
    'ObjectBrowser':'Control','ObjectPopulationPanel':'Control','ObjectControls':'Control','RaceLoading':'Control',
    'PublicationPrompt':'ConfirmationDialog','TrackBrowser':'Control','RaceResults':'Control','PlaygroundHUD':'Control'}
for old,new in optional_types.items():
    shell = re.sub(r'(?<=: )'+old+r'\b',new,shell)
    shell = re.sub(r'(?<=-> )'+old+r'\b',new,shell)
    shell = re.sub(r'(?<=as )'+old+r'\b',new,shell)
shell += '''\n# Feature scripts are loaded on first use, never during shell parsing.
var _feature_resources: Dictionary = {}
func _feature_resource(path: String) -> Resource:
\tif not _feature_resources.has(path):
\t\t_feature_resources[path] = load(path)
\treturn _feature_resources[path]
'''
(root/'game/core/app.gd').write_text(shell,encoding='utf-8',newline='\n')
for group,blocks in groups.items():
    path = root/'game/core/features'/f'{group}.gd'
    path.parent.mkdir(parents=True,exist_ok=True)
    body = ''.join(blocks)
    aliases = ''.join(f'const {name} = preload("{constants[name]}")\n' for name in ('RaceLoading','PublicationPrompt','ObjectControls')
                      if re.search(r':\s*'+name+r'\b|->\s*'+name+r'\b',body))
    path.write_text('extends RefCounted\n## '+group.title()+' composition. State and scene ownership stay with App.\n'+aliases+'\n'+body,encoding='utf-8',newline='\n')
(evidence/'extraction.json').write_text(json.dumps({'methods':mapping,'shadows':shadow_report},indent=2),encoding='utf-8')
print({group:len(blocks) for group,blocks in groups.items()})
