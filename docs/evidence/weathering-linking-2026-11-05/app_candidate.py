"""Apply the measured policy only to the owned App fixture, before covered draws."""
import json,shutil,sys
from pathlib import Path
p=Path(__file__).resolve().parent;g=Path(json.loads((p/'frozen-project.json').read_text())['project'])
archive=p/'before/game/core/game.gd';archive.parent.mkdir(parents=True,exist_ok=True)
if not archive.exists():shutil.copyfile(g/'core/game.gd',archive)
if sys.argv[1]=='before':
    shutil.copyfile(archive,g/'core/game.gd')
    sys.exit(0)
source=archive.read_text()
if sys.argv[1]=='candidate':
    anchor='\tcar_weathering.configure(car, str(native_track.metadata.get("theme", "pine")) if native_track != null else "pine", handling)'
    assert source.count(anchor)==1
    source=source.replace(anchor,anchor+'\n\tpreload("res://tests/weathering_candidate.gd").apply(car_weathering)')
(g/'core/game.gd').write_bytes(source.encode())
