"""Prepare isolated diagnostics; retain original assertions and redirect outputs."""
import hashlib
import json
from pathlib import Path

evidence = Path(__file__).resolve().parent
root = evidence.parents[2]
manifest = json.loads((evidence/'frozen-project.json').read_text())
game = Path(manifest['project'])
assert game.resolve().is_relative_to((root/'build/checkpoint-preparation-20261105').resolve())
receipts = []

def write(name, text, source):
    target = game/'tests'/name
    target.write_text(text, encoding='utf-8')
    receipts.append(dict(path=str(target), source=source, sha256=hashlib.sha256(target.read_bytes()).hexdigest()))

write('test_checkpoint_preparation.gd',(root/'game/tests/test_checkpoint_preparation.gd').read_text(), 'current focused test')
write('test_checkpoint_lane_reuse.gd',(root/'game/tests/test_checkpoint_lane_reuse.gd').read_text(), 'current focused test')
for name in ('spline_gate_corridor','track_session'):
    text = (evidence/'before/game/race'/f'{name}.gd').read_text()
    text = text.replace('class_name SplineGateCorridor','').replace('class_name TrackSession','')
    if name == 'track_session':
        text = text.replace('SplineGateCorridor.', 'preload("res://tests/checkpoint_before_spline_gate_corridor.gd").')
    write(f'checkpoint_before_{name}.gd',text,'archived original '+name)

output = 'res://../build/checkpoint-preparation-output/'
(game.parent/'build/checkpoint-preparation-output').mkdir(parents=True,exist_ok=True)
for name in ('test_checkpoint_road_coverage','test_hairpin_checkpoints','test_star_checkpoint_shortcuts'):
    source = (game/'tests'/f'{name}.gd').read_text()
    text = source.replace('res://../build/checkpoint-road-coverage-2026-11-03/',output).replace('res://../docs/evidence/hairpin-checkpoints-2026-10-18/',output)
    write(name+'_prepared.gd',text,'frozen original; output path only')

text = (game/'tests/capture_checkpoint_road_coverage.gd').read_text()
text = text.replace('res://../build/checkpoint-road-coverage-2026-11-03/',output)
text = text.replace('load(OUTPUT+"control_session.gd")','load("res://tests/checkpoint_before_track_session.gd")')
text = text.replace('for stage: String in ["before","after"]:', 'var pixels := PackedByteArray()\n\tfor stage: String in ["before","after"]:')
text = text.replace('var widths: Vector2 = displayed.checkpoint_road_spans(track)', '''var image: Image = root.get_texture().get_image()
		if stage == "before": pixels = image.get_data()
		else: check(pixels == image.get_data(),"complete native checkpoint view is pixel-exact")
		var widths: Vector2 = displayed.checkpoint_road_spans(track)''')
write('capture_checkpoint_preparation.gd',text,'frozen native coverage capture; current task original control, output paths, pixel equality assertion')
settled = text.replace('range(8): await process_frame','range(24): await process_frame').replace('res://../build/checkpoint-preparation-output/','res://../build/checkpoint-preparation-settled/')
write('capture_checkpoint_settled.gd',settled,'same exact pixel assertion; allow 24 frames to settle each unchanged view')
(evidence/'probe-receipts.json').write_text(json.dumps(receipts,indent=2)+'\n')
print(f'Prepared {len(receipts)} isolated diagnostic scripts.')
