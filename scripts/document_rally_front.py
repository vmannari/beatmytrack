"""Prepend the scoped task receipt while preserving current tracker content."""
from run_rally_front import ROOT
marker='RALLY-FRONT-20261115'
body='''<!-- RALLY-FRONT-20261115 -->
## Rally grille and lamps refined with fewer triangles (2026-11-15)
RFL01-RFL04: six satin slats, quieter dark lattice, smooth bowed surround and opaque prismatic round optics replace dense repeated hardware and the faceted central bulb/shade stack. Racing front2638to1846(-30.02%), full front4726to2086(-55.86%); whole Rally16653to15861(-4.76%), fitted24450to23658/full102556to99916. Two exact non-front frame migrations retain prior savings, fit and handling. Stock buffers-7.08%/two fewer surfaces; front studio20695to19903 primitives,64to62 Compatibility/58to56 Mobile draws. Existing176px icon+46primitives(+0.24%) retained as a local tradeoff; no FPS/device claim. Source6/0, prepared30/0 with ten other stock/full masters exact, retained grille270/0, Rally modules1441/0 and shared Challenger consumer1436/0, corrected daylight24pairs101/0/night8pairs37/0, App8/0/icons496/0 each desktop renderer, driving72/0/parser577/0 and full551-resource2267/0 pass. Two Garage/one header pictures,3 imports,6-photo174-source catalogue and18698-input fence pass; seven unrelated keys exact. Root-scale fixture error and initial legacy/parser/night findings retained; exact GPU, root-transform and glazing controls qualify final comparisons without relaxed assertions. Challenger geometry sources unmodified; conservative shared dependency requires cache-only refresh. Source-only checkpoint and standard retention recorded; concurrent Garage/index preserved. Reload/owner appearance remains; no device/export/backend/deployment/owner-save/process or main-index action. [Changes, comparisons, commands and limits](REPORT_LINK).
<!-- /RALLY-FRONT-20261115 -->

'''
for name in ('AGENTS.md','DEVELOPMENT_STATUS.md','docs/PHASE_0_PLAN.md'):
    path=ROOT/name;data=path.read_bytes();assert ('<!-- '+marker+' -->').encode() not in data
    link=('' if name.startswith('docs/') else 'docs/')+'RALLY_FRONT_REFINEMENT_2026_11_15.md'
    newline='\r\n' if b'\r\n' in data else '\n'
    path.write_bytes(body.replace('REPORT_LINK',link).replace('\n',newline).encode()+data)
print('RALLY_FRONT_TRACKERS three current files updated without replacing concurrent blocks')
