"""Bind suspended feature callbacks to nonvisual children of their App owner."""
from pathlib import Path
import re
root = Path(__file__).resolve().parents[3]
for path in (root/'game/core/features').glob('*.gd'):
    source = path.read_text(encoding='utf-8')
    source = source.replace('extends RefCounted','extends Node',1)
    source = re.sub(r'^static func _(\w+)\(',r'func run_\1(',source,flags=re.M)
    path.write_text(source,encoding='utf-8',newline='\n')
path = root/'game/core/app.gd'
source = path.read_text(encoding='utf-8')
source = re.sub(r'(_feature_resource\("res://core/features/[^\"]+"\)\.)_(\w+)\(',r'\1run_\2(',source)
source = re.sub(r'(_feature_resources\["res://core/features/[^\"]+"\]\.)_(\w+)\(',r'\1run_\2(',source)
source = re.sub(r'(_editor_module\.)_(\w+)\(',r'\1run_\2(',source)
source = source.replace('var _editor_module: Script','var _editor_module: Node')
source = source.replace('func _feature_resource(path: String) -> Resource:','func _feature_resource(path: String) -> Object:')
source = source.replace('\t\t_feature_resources[path] = load(path)', '''\t\tvar resource: Resource = load(path)
\t\tif path.begins_with("res://core/features/"):
\t\t\tvar controller: Node = resource.new()
\t\t\tcontroller.name = "AppFeature_"+path.get_file().get_basename()
\t\t\t_feature_resources[path] = controller
\t\t\tadd_child(controller)
\t\telse:
\t\t\t_feature_resources[path] = resource''')
path.write_text(source,encoding='utf-8',newline='\n')
