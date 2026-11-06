"""Record actual evidence and prepend a scoped status block, preserving other work."""
import json
from pathlib import Path

evidence = Path(__file__).resolve().parent
root = evidence.parents[2]
summary = {}
for label, checks, failures, code in [
    ('headless',148,0,0), ('final-headless',148,0,0), ('final-compatibility',398,0,0), ('final-mobile',398,2,1),
    ('mobile-before-control',398,10,1), ('matched-mobile-controls',16,0,0), ('retained-roof',290,0,0),
]:
    report = json.loads((evidence/label/'report.json').read_text())
    receipt = json.loads((evidence/(label+'-receipt.json')).read_text())
    assert (report['checks'],report['failures'],receipt['exit_code']) == (checks,failures,code)
    assert receipt['sources_unchanged'] and not receipt['script_errors']
    summary[label] = {'checks':checks,'failures':failures,'exit_code':code,'source_stable':True}
    if label in ['final-compatibility', 'final-mobile']:
        windows = [m for m in report['metrics'] if m['part']=='windows']
        assert all(m['after_mean_255'] < 0.8*m['before_mean_255'] for m in windows)
        assert all(m['changed_pixels']==0 for m in report['metrics'] if m['part']=='roof')
        assert all(m['restore_pane_changed']==0 for m in report['metrics'])
        summary[label]['window_mean_ranges_255'] = {key:[min(m[key] for m in windows),max(m[key] for m in windows)] for key in ['before_mean_255','after_mean_255']}
        summary[label]['native_captures'] = len(list((evidence/label).glob('*.png')))
assert '1925 checks, 0 failures' in (evidence/'preflight/prepared-preflight.log').read_text()
assert '5 exact native images, 156 current source hashes' in (evidence/'preflight/pictures-preflight.log').read_text()
summary['assets'] = {'resources':468,'checks':1925,'failures':0,'pictures':5,'picture_source_hashes':156,'rebaked':False}
summary['mobile_restoration'] = {'frames':2,'pixels_each':113,'inside_glass':0,'all_before_after_coordinates_and_colours_match_control':True}
(evidence/'summary.json').write_text(json.dumps(summary,indent=2),encoding='utf-8')

marker = 'VOLT-NIGHT-WINDOWS-20261106'
title = 'Volt Night windows use the roof’s dark pigment (2026-11-06)'
body = ('VNW01-VNW02/VNWQ01: Owner finds the windows too light after the roof correction. '
        'Race-owned Night tint caps windscreen/rear/side/mirror pigments at the existing roof level; shader and prepared assets stay exact. '
        'Final Compatibility398/0, headless148/0, retained roof290/0; Mobile398/2 retains two frame-restoration failures. '
        'All16 glass views, unchanged roofs, exact pane restoration/day/studio/state checks pass;152 final native captures. '
        'Previous-tint control398/10 and independent16/0 pixel comparison match all113 non-glass changes in each failed frame; '
        'audio teardown warnings and dev-wrapper Access denied retained. Asset preflight468resources/1925checks/0failures and five-picture provenance pass without rebaking. '
        '[Changes, pictures, commands, limits and task-only checkpoint]({link}). '
        'Reload/rebuild and owner/device acceptance remain. No device query/test, APK, owner-save/process change, backend request, deployment or main-index write; concurrent work preserved.')
for name in ['AGENTS.md','DEVELOPMENT_STATUS.md','docs/PHASE_0_PLAN.md']:
    path = root/name
    data = path.read_bytes()
    opening,closing = ('<!-- '+marker+' -->').encode(), ('<!-- /'+marker+' -->').encode()
    if opening in data:
        start = data.index(opening)
        end = data.index(closing,start)+len(closing)
        if data[end:end+2] == b'\n\n': end += 2
        data = data[:start]+data[end:]
    link = ('VOLT_NIGHT_WINDOWS_2026_11_06.md' if name.startswith('docs/') else 'docs/VOLT_NIGHT_WINDOWS_2026_11_06.md')
    block = opening.decode()+'\n## '+title+'\n'+body.format(link=link)+'\n'+closing.decode()+'\n\n'
    path.write_bytes(block.encode('utf-8')+data)
print(json.dumps(summary,indent=2))
