"""Local evidence only: never submit a score or write a service database."""
from pathlib import Path
from types import SimpleNamespace
import json, math, sys

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'backend'))
from bmt_backend.verifier import GodotVerifier
from bmt_backend.trajectory_verifier import check

folder = Path(__file__).parent
document = json.loads((ROOT/'game/resources/tracks/ellipse.json').read_text())['creator_document']
verifier = GodotVerifier(SimpleNamespace(godot_bin=r'C:\apps\Godot 4.7.2\Godot_v4.7.2-stable_win64_console.exe',game_project=ROOT/'game',verifier_timeout_seconds=90))
try:
    existing = folder/'geometry-response.json'
    geometry = json.loads(existing.read_text())['result'] if existing.exists() else verifier.race_geometry(document)
    (folder/'ellipse-geometry.json').write_text(json.dumps(geometry,indent=2))
    px,py,layer = geometry['start']
    samples = [[0,px,py,layer]]
    tick = 0
    distance_per_tick = geometry['maximum_speed']['compact']/120
    for lap in range(5):
        for gate in geometry['gates']:
            nx,ny,origin,sx,sy,side_origin,low,high,expected_layer = gate
            # Cross every ordered gate through its center. No throttle, grip,
            # braking, steering, collision or road queries participate.
            side = (low+high)/2-side_origin
            determinant = nx*sy-ny*sx
            gx = ((-origin)*sy-ny*side)/determinant + nx*0.02
            gy = (nx*side-(-origin)*sx)/determinant + ny*0.02
            steps = max(1,math.ceil(math.hypot(gx-px,gy-py)/distance_per_tick))
            ax,ay = px,py
            for i in range(1,steps+1):
                tick += 1
                samples.append([tick,ax+(gx-ax)*i/steps,ay+(gy-ay)*i/steps,expected_layer])
            px,py,layer = gx,gy,expected_layer
    proof = {'schema':'bmt-race-path-v1','samples':samples}
    accepted = check(geometry,proof,tick,'compact')
    proof['incidents'] = {'schema':'bmt-race-incidents-v1','ticks':tick,'collision_count':0,'off_track':False}
    with_claim = check(geometry,proof,tick,'compact')
    result = {'accepted':accepted,'accepted_with_claim':with_claim,'sample_count':len(samples),'generated_without_canonical_inputs':True,'first_step_speed_mps':math.dist(samples[0][1:3],samples[1][1:3])*120}
    (folder/'synthetic-trajectory-result.json').write_text(json.dumps(result,indent=2))
    print(json.dumps(result))
finally:
    verifier.close()
