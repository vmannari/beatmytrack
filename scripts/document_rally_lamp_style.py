"""Record the owner's requested lamp-style return without replacing other work."""
from run_rally_lamp_style import ROOT
marker='RALLY-LAMP-STYLE-20261115'
body='''<!-- RALLY-LAMP-STYLE-20261115 -->
## Rally lamps return to the preferred reflector style (2026-11-15)
RLS01-RLS04: owner prefers the earlier lamps. Unchanged clear fluted-glass shader, recessed silver dish, bright bulb cap and round dark shade restore that character while retaining smooth rims and the refined grille. Lamps1312tri versus earlier1384/opaque960; whole Rally16213 (+352 versus opaque15861, -15.00% restored19074), fitted24010/full100356. Two exact non-lamp frame migrations preserve grille/body reductions; ten other stock/full GPU controls exact. Source6/0, prepared30/0, retained grille274/0, Rally modules1441/0/shared Challenger consumer1436/0, daylight24pairs101/0/night8pairs37/0, App8/0/icons496/0 each desktop renderer, driving72/0/parser577/0 and full551-resource2267/0 pass. Transparent optics/two surfaces and9672 stock buffer bytes return as the appearance tradeoff. Two Garage/one header images,3 imports,6-photo174-source catalogue and18700-input fence pass; seven other keys exact. Challenger geometry unmodified; shared conservative source rule requires cache-only refresh. Three-way comparison and source-only exact checkpoint retained; standard retention applied, concurrent work/index preserved. Reload/owner visual acceptance remains; no device/FPS/export/backend/deployment/owner-save/process or main-index action. [Style, views, commands and limits](REPORT_LINK).
<!-- /RALLY-LAMP-STYLE-20261115 -->

'''
for name in ('AGENTS.md','DEVELOPMENT_STATUS.md','docs/PHASE_0_PLAN.md'):
    path=ROOT/name;data=path.read_bytes();assert ('<!-- '+marker+' -->').encode() not in data
    link=('' if name.startswith('docs/') else 'docs/')+'RALLY_LAMP_STYLE_2026_11_15.md'
    newline='\r\n' if b'\r\n' in data else '\n'
    path.write_bytes(body.replace('REPORT_LINK',link).replace('\n',newline).encode()+data)
print('RALLY_LAMP_STYLE_TRACKERS three current tracker files updated')
