from pathlib import Path

def edit(path, replacements):
    p=Path(path); s=p.read_text(encoding='utf-8')
    for old,new in replacements:
        assert old in s, (path,old[:100])
        s=s.replace(old,new,1)
    p.write_text(s,encoding='utf-8',newline='\n')

edit('game/editor/commit_queue.gd',[
 ('workflow: String) -> void:', 'workflow: String, revision: int = 0) -> void:'),
 ('"workflow":workflow})','"workflow":workflow,"revision":revision})'),
 ('return {"storage":entry.storage,','return {"revision":entry.revision,"storage":entry.storage,'),
 ('completed.append({"storage":active.storage,','completed.append({"revision":active.revision,"storage":active.storage,')])

p=Path('game/core/app.gd'); s=p.read_text(encoding='utf-8')
s=s.replace('var history: Array[Dictionary] = []','var editor_session = preload("res://editor/editor_session.gd").new()\nvar history: Array[Dictionary]:\n\tget: return editor_session.undo\n\tset(value): editor_session.undo = value',1)
s=s.replace('var redo_history: Array[Dictionary] = []','var redo_history: Array[Dictionary]:\n\tget: return editor_session.redo\n\tset(value): editor_session.redo = value',1)
for name,field,typ,initial in [
 ('editor_commits','commits','','preload("res://editor/commit_queue.gd").new()'),
 ('editor_validation_document','validated','Dictionary','{}'),
 ('editor_validation_errors','errors','Array[String]','[]'),
 ('editor_workflow_presentation','workflow','Dictionary','{}'),
 ('editor_gesture_history','gesture_undo','Array[Dictionary]','[]'),
 ('editor_gesture_redo','gesture_redo','Array[Dictionary]','[]')]:
    old=f'var {name}'+(f': {typ}' if typ else '')+f' = {initial}'
    assert old in s,old
    s=s.replace(old,f'var {name}'+(f': {typ}' if typ else '')+f':\n\tget: return editor_session.{field}\n\tset(value): editor_session.{field} = value',1)
s=s.replace('editor_gesture_history = history.duplicate()\n\t\teditor_gesture_redo = redo_history.duplicate()\n\t\t_remember()', 'editor_session.begin_gesture(document)',1)
s=s.replace('editor_gesture_history.clear()\n\t\teditor_gesture_redo.clear()', 'editor_session.finish_gesture()',1)
s=s.replace('history = editor_gesture_history.duplicate()\n\t\tredo_history = editor_gesture_redo.duplicate()\n\t\teditor_gesture_history.clear()\n\t\teditor_gesture_redo.clear()', 'editor_session.cancel_gesture()',1)
s=s.replace('history.append(EDITOR_HISTORY.capture(document,history.back() if not history.is_empty() else {}))\n\tredo_history.clear()\n\tEDITOR_HISTORY.trim(history,redo_history)', 'editor_session.remember(document)',1)
for src,body,back in [('history','redo_history.append(EDITOR_HISTORY.capture(document,history.back()))\n\tdocument = EDITOR_HISTORY.restore(history.pop_back())','true'),('redo_history','history.append(EDITOR_HISTORY.capture(document,redo_history.back()))\n\tdocument = EDITOR_HISTORY.restore(redo_history.pop_back())','false')]:
    assert body in s
    s=s.replace(body+'\n\tEDITOR_HISTORY.trim(history,redo_history)',f'document = editor_session.restore(document,{back})',1)
s=s.replace('if receipt.storage != library or receipt.source != document: continue','if not editor_session.accept(receipt,library,document): continue',1)
s=s.replace('\t\teditor_validation_document = receipt.document.duplicate(true)\n\t\teditor_validation_errors.assign(receipt.errors)\n\t\teditor_workflow_presentation = receipt.workflow\n','',1)
s=s.replace('editor_commits.enqueue(library,document,','editor_session.enqueue(library,document,',1)
s=s.replace('for pair: Array in [["straight","Straight"],["taper","Taper"],["curve","Curve"],["s_bend","S-bend"],["hairpin","Hairpin"],["bridge","Bridge"],["spline","Spline"]]:\n\t\t\t\t_context_button(pair[1],pair[0],canvas.choose_piece.bind(pair[0]))', 'for kind: String in RoadPieces.KINDS:\n\t\t\t\t_context_button(preload("res://editor/road_piece_catalog.gd").title(kind),kind,canvas.choose_piece.bind(kind))',1)
p.write_text(s,encoding='utf-8',newline='\n')

p=Path('game/editor/editor_canvas.gd'); s=p.read_text(encoding='utf-8')
start=s.index('var _gesture_document:'); end=s.index('var _run_edge_hint:',start)
s=s[:start]+'''var gesture = preload("res://editor/editor_gesture.gd").new()
var _gesture_document: Dictionary:
\tget: return gesture.before
var _gesture_absent: Array[String]:
\tget: return gesture.absent
var _gesture_ghost: Dictionary:
\tget: return gesture.ghost
var _navigation_only: bool:
\tget: return gesture.phase == gesture.Phase.NAVIGATION
\tset(value): gesture.phase = gesture.Phase.NAVIGATION if value else gesture.Phase.IDLE
'''+s[end:]
s=s.replace('_gesture_document.clear(); _gesture_absent.clear(); _gesture_ghost.clear()','gesture.clear()')
start=s.index('\tif not _gesture_document.is_empty()',s.index('func _rollback_navigation_edit'))
end=s.index('\tghost = _gesture_ghost',start)
s=s[:start]+'''\tif gesture.rollback(document):
\t\tdocument_changed.emit()
\t\tedit_cancelled.emit()
'''+s[end:]
start=s.index('\t# Selection/navigation do not snapshot',s.index('func _start_edit'))
end=s.index('\tedit_started.emit()',start)
s=s[:start]+'\tgesture.capture(document,mode)\n'+s[end:]
s=s.replace('_gesture_document = {}\n\t_gesture_absent.clear()\n\t_gesture_ghost = ghost.duplicate(true)\n\t_navigation_only = preparing','gesture.begin(ghost,preparing)',1)
s=s.replace('_rollback_navigation_edit()\n\t\t\t\tpending_road_tap','_rollback_navigation_edit()\n\t\t\t\t_navigation_only = true\n\t\t\t\tpending_road_tap',1)
start=s.index('\tif piece.kind == "spline": return []',s.index('func geometry_keys'))
end=s.index('\nfunc geometry_caption',start)
s=s[:start]+'\treturn preload("res://editor/road_piece_catalog.gd").handles(str(piece.kind))\n\n'+s[end:]
p.write_text(s,encoding='utf-8',newline='\n')

edit('game/editor/road_pieces.gd',[
 ('const KINDS: Array[String] = ["straight", "taper", "curve", "s_bend", "hairpin", "bridge", "spline"]','const CATALOG = preload("res://editor/road_piece_catalog.gd")\nconst KINDS: Array[String] = CATALOG.KINDS'),
 ('"length":48.0 if kind == "bridge" else 28.0 if kind == "straight" else 0.0 if kind in ["hairpin","curve"] else S_END_LENGTH, "radius":12.0 if kind == "hairpin" else 16.0,','"length":CATALOG.DESCRIPTORS[kind].length, "radius":CATALOG.DESCRIPTORS[kind].radius,')])
