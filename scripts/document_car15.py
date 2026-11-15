"""Add the current task receipt while preserving concurrent tracker entries."""
from run_car15 import ROOT

marker='CAR-GRADUAL-15-20261115'
body='''<!-- CAR-GRADUAL-15-20261115 -->
## Five-car gradual optimisation reaches approximately 15% (2026-11-15)
C1501-C1504: owner accepts the Forklift review point and requests about15% cumulatively from restored baselines, excluding unfinished Challenger. Rally19074to16653(-12.69%)/Kart24223to20590(-15%)/Forklift26472to22502(-15%)/Volt19826to17015(-14.18%)/Hover22068to18758(-15%); total95518(-14.46%). Rally/Volt stop conservatively. Offline original-corner/projected fitting reduction retains contact anchors, fields, topology, frame guards and protected helmet/glazing/roof/steering; maximum sampled1.830mm within unchanged2mm gate. Runtime construction and five full GPU masters exact. Source5/0, prepared30/0, recipe789/0, all-kit7545/0, native82pairs343/0 and App48/0, steering170/0/icons496/0 each desktop renderer, driving72/0, parser576/0 and scoped468-resource1925/0 pass. Stock buffers-13.44% this step; matched viewport primitives fall, draws unchanged, no FPS/device claim. Five Garage/five header pictures,10 imports,173-source catalogue and25539-input/384-source fence pass; four unrelated keys exact. Rejected geometry/steering and icon output/cache fixture controls retained; no assertion weakened. Scoped source/resource checkpoint and standard retention receipt; concurrent Challenger/Garage/index preserved. Next reduction awaits owner appearance review; no device/export/backend/deployment/owner-save/process or main-index action. [Changes, comparisons, commands and limits](REPORT_LINK).
<!-- /CAR-GRADUAL-15-20261115 -->

'''
for name in ('AGENTS.md','DEVELOPMENT_STATUS.md','docs/PHASE_0_PLAN.md'):
    path=ROOT/name;data=path.read_bytes()
    assert ('<!-- '+marker+' -->').encode() not in data
    link='CAR_GRADUAL_15_PERCENT_2026_11_15.md' if name.startswith('docs/') else 'docs/CAR_GRADUAL_15_PERCENT_2026_11_15.md'
    newline='\r\n' if b'\r\n' in data else '\n'
    prefix=body.replace('REPORT_LINK',link).replace('\n',newline).encode()
    path.write_bytes(prefix+data)
print('CAR15_TRACKERS updated three current files without replacing concurrent blocks')
