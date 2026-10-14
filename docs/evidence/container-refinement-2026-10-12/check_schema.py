from pathlib import Path
import json
import jsonschema

root = Path(__file__).resolve().parents[2]
schema = json.loads((root / 'docs/schemas/creator-track-v5.schema.json').read_text())
jsonschema.Draft202012Validator.check_schema(schema)
validator = jsonschema.Draft202012Validator(schema['properties']['objects']['items'])
valid = [dict(kind='container', position=[0, 0], rotation=0),
         dict(kind='container', position=[0, 0], rotation=0, color='#AbC123'),
         dict(kind='container', position=[0, 0], rotation=0, color='#000000')]
invalid = [dict(kind='container', position=[0, 0], rotation=0, color=value)
           for value in ('#abc', '#12345678', 'blue', '#g12345', 42, None)]
invalid.append(dict(kind='crate', position=[0, 0], rotation=0, color='#426878'))
assert all(not list(validator.iter_errors(obj)) for obj in valid)
assert all(list(validator.iter_errors(obj)) for obj in invalid)
message = 'CONTAINER_SCHEMA: whole schema valid; 10 object cases passed\n'
(root / 'docs/evidence/container-refinement-2026-10-12/schema.log').write_text(message, newline='\n')
print(message, end='')
