"""Publish only completed final measurements/deployment; update owned journal blocks."""
import json
from pathlib import Path

E = Path(__file__).resolve().parent
ROOT = E.parents[2]
normal = json.loads((E/'qualified-export.json').read_text())
profile = json.loads((E/'profiled-qualified-export.json').read_text())
stock = json.loads((E/'final-comparison.json').read_text())
fit = json.loads((E/'fixed-fit-comparison.json').read_text())
deployment = json.loads((E/'tablet-qualified/normal-deployment.json').read_text())
smoke = json.loads((E/'tablet-qualified/normal-ui.json').read_text())
assert deployment['normal_startup_verified'] and deployment['authored_tracks_unchanged'] and deployment['pb_dictionaries_unchanged']
assert deployment['selected_car_and_simple_preference_unchanged'] and smoke['garage_verified']

def sec(value): return f'{value/1000:.3f}'

lines = ['## Final device results and delivery','',
    f"The final saved-Kart matrix passes **{stock['checks']}/0** and the four fixed-fit runs **{fit['checks']}/0**: **{stock['checks']+fit['checks']} checks / zero failures**. Android thermal status is zero throughout. Final stock-run battery temperatures are {min(stock['after_temperatures_c']):.1f}–{max(stock['after_temperatures_c']):.1f}°C; fixed-fit temperatures are {min(fit['temperatures_c']):.1f}–{max(fit['temperatures_c']):.1f}°C. Existing driver caches are retained. These are two samples per mode/arm and fixed fixture order, not broad population statistics.",
    '', 'The stock-Kart comparison below uses the reinstalled previous APK in the same session. First entry A starts with empty task road/layout storage; first entry B retains that storage but starts a new process. The values are kept separate because these are different cache states.',
    '', '| Stock Kart fixture | Old A / B first entry, s | Final A / B first entry, s | Old → final repeat median, s |', '|---|---:|---:|---:|']
for key,values in stock['races'].items():
    first,warm = values['0'],values['1']
    lines.append(f"| {key} | {' / '.join(sec(v) for v in first['before_samples_ms'])} | {' / '.join(sec(v) for v in first['after_samples_ms'])} | {sec(warm['before_ms'])} → {sec(warm['after_ms'])} |")
startup = stock['startup']['launch_to_content_ms']
lines += ['',f"Actual initial menu readiness is **{sec(startup['before_ms'])}→{sec(startup['after_ms'])} s** median; the sample ranges overlap. There is no established startup improvement. First Garage is {sec(stock['menus']['garage']['0']['before_ms'])}→{sec(stock['menus']['garage']['0']['after_ms'])} s, preserving the direct entry. Most menus are similar; first Editor is {sec(stock['menus']['create']['0']['before_ms'])}→{sec(stock['menus']['create']['0']['after_ms'])} s and remains unresolved. The repaired writer is inside the tree and completes snapshots in every final run.",
    '', '| Menu | Old → final first median, s | Old → final repeat median, s |', '|---|---:|---:|']
for name,v in stock['menus'].items():
    lines.append(f"| {'Editor' if name=='create' else name.capitalize()} | {sec(v['0']['before_ms'])} → {sec(v['0']['after_ms'])} | {sec(v['1']['before_ms'])} → {sec(v['1']['after_ms'])} |")
car = fit['repeat_car']
lines += ['',f"For the **explicitly pinned fitted Simple Compact**, repeated model preparation is **{car['construction_ms']:.3f}→{car['reuse_ms']:.3f} ms** median. The following full repeat loads compare forced original construction with template reuse in the final APK, with identical private car configuration and a verified hit/miss counter. They are not measurements of the saved stock Kart.",
    '', '| Fitted Compact fixture | Construction → reuse repeat median, s | Reduction |', '|---|---:|---:|']
for name,v in fit['races'].items():
    w=v['1']
    lines.append(f"| {name} | {sec(w['construction_ms'])} → {sec(w['reuse_ms'])} | {w['reduction_percent']:.1f}% |")
lines += ['', '**The universal half-loading target is not achieved.** The fitted-car repeat bottleneck is addressed; startup, menus, the large Star first load and remaining native/render preparation still need work. No lower quality, alternate physics, new Garage modal or custom engine is used.',
    '', f"Normal build **`{normal['build_id']}`** is installed and foreground startup/direct Garage are verified. APK SHA-256: `{normal['apk']['sha256']}`; {normal['apk']['bytes']:,} bytes; {deployment['package']['entries']} ZIP entries with valid CRCs; ARM64 native libraries match the original APK byte-for-byte. The final profiler is `{profile['build_id']}`, SHA-256 `{profile['apk']['sha256']}`. Standard export checks and source audits pass; only generated identity/project metadata changes during the final exports.",
    '', f"The original first-install timestamp, all **{deployment['authored_tracks_checked']} checked authored-track JSON files**, both PB dictionaries, selected stock Kart and Simple preference are preserved. Initial app-file count is {deployment['initial_files']}; after final launch/normal cache updates it is {deployment['final_files']}. The first profiling installation preserved all 839 files before launch. The final replacement launches before the slow full manifest to avoid the secure screen timeout, so it does **not** claim every app file was compared before that launch. Final authored data/PBs/settings and installed APK hashes are audited afterward. Task diagnostic folders/marker/APK transfers are removed after private archival. The normal app remains open; stay-awake setting remains {deployment['screen_awake_setting']}.",
    '', '**Retained save-audit exception.** Strict comparison of every initial appearance preference fails: the unselected Compact body is now Rally rather than Wide arch, and its body/accent/detail colors and pattern also differ. Both the initial and final appearances match their respective acknowledged sync baselines. The cause of that remote-state difference is not attributed to this task. The diagnostic only pins a private Wide-arch fixture and checks that owner settings remain unchanged during those cases. Current acknowledged appearance was left intact and the original backup retained. On 2026-11-07 the owner explicitly confirmed keeping the current synced Rally body. No all-preferences-unchanged claim is made; the original strict deployment assertion and subsequent livery-audit failure remain recorded.',
    '', 'Private native startup and Garage captures are retained under ignored build storage. Public receipts: [final stock comparison](evidence/tablet-loading-fixes-2026-11-07/final-comparison.json), [fixed-fit ABBA](evidence/tablet-loading-fixes-2026-11-07/fixed-fit-comparison.json), [deployment](evidence/tablet-loading-fixes-2026-11-07/tablet-qualified/normal-deployment.json), and [reversible source/evidence checkpoint](evidence/tablet-loading-fixes-2026-11-07/checkpoint.json). The checkpoint excludes mixed-author prepared binaries and inventories image hashes separately. Concurrent work and the main index are preserved.']
report = ROOT/'docs/TABLET_LOADING_FIXES_2026_11_07.md'
text = report.read_text(encoding='utf-8').split('\n## Final device results and delivery')[0].rstrip()
report.write_text(text+'\n\n'+'\n'.join(lines)+'\n',encoding='utf-8',newline='\n')
marker = 'TABLET-LOADING-FIXES-20261107'
body = f'''## Tablet loading fixes delivered; fitted-car gains qualified (2026-11-07)
TLF01–TLF03/TLFQ01: Exact bounded fitted-Simple restoration, deferred-root snapshot writer and numeric scenery worker ship in {normal['build_id'].split('.')[-1]}. Final stock-Kart matrix {stock['checks']}/0 and pinned-fit ABBA {fit['checks']}/0; repeat fitted-car preparation {car['construction_ms']:.1f} to {car['reuse_ms']:.1f} ms. Startup/most menus unchanged; universal half-time target remains. TLF04 startup deferral rejected after fresh control; original App/direct Garage scheduling retained. Historical Compact-versus-current-Kart timing attribution withdrawn and corrected with explicit private configuration/hit checks. Native first-lap 123/0 and 133/0 each cover five zero-contact laps; writer 12/0, motion 138/0, geometry/pixel controls and assets 1925/0 pass with one retained Compatibility pixel mismatch exactly reproduced within original-repeat variation. Normal APK/first-install,22 authored files/two PB dictionaries and selected Kart/Simple preference verified; diagnostic files removed. Strict all-appearance comparison fails: Compact body/colors/pattern differ and match the current acknowledged sync baseline; current appearance preserved and owner confirmed keeping the synced Rally body. No lower quality/physics/backend change or main-index write; concurrent work preserved. [Commands, full timings, retained failures, limits and checkpoint](LINK).
'''
for name in ['AGENTS.md','DEVELOPMENT_STATUS.md','docs/PHASE_0_PLAN.md']:
    path=ROOT/name
    data=path.read_bytes()
    opening=('<!-- '+marker+' -->').encode()
    closing=('<!-- /'+marker+' -->').encode()
    if opening in data:
        start=data.index(opening);end=data.index(closing,start)+len(closing)
        while data[end:end+1] in (b'\r',b'\n'):end+=1
        data=data[:start]+data[end:]
    link='TABLET_LOADING_FIXES_2026_11_07.md' if name.startswith('docs/') else 'docs/TABLET_LOADING_FIXES_2026_11_07.md'
    path.write_bytes((opening.decode()+'\n'+body.replace('LINK',link)+closing.decode()+'\n\n').encode()+data)
print('FINAL_REPORT_AND_JOURNALS_WRITTEN')
