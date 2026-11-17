from pathlib import Path
import json
root=Path(__file__).resolve().parents[1]
path=root/'scripts/check_car_mechanics.py'
context={'__file__':str(path)}
exec(path.read_text().split('proof=json.loads')[0],context)
d=json.loads((root/'build/car-mechanics-2026-11-17/rim-proof.json').read_text())
t=context['tree'];bound=context['upper_bound'];top=context['topology']
a=t(d['vertices'],d['before']);b=t(d['vertices'],d['after'])
maximum=max(bound(d['vertices'],d['before'],b,.0002),bound(d['vertices'],d['after'],a,.0002))
before=top(d['vertices'],d['before']);after=top(d['vertices'],d['after'])
assert before==after,(before,after)
assert maximum<.012,maximum
result=dict(surface_upper_bound_m=maximum,topology=after,before=len(d['before'])//3,after=len(d['after'])//3)
(root/'docs/evidence/car-mechanics-2026-11-17/rim-review.json').write_text(json.dumps(result,indent=2))
print('RIM_REVIEW',result)
