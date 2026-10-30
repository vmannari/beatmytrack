from pathlib import Path
import hashlib
import json
import re
import sys

root = Path.cwd()
out = root / 'docs/evidence/track-editor-fixes-2026-10-28'
sys.path.insert(0,str(root/'scripts'))
import localization

def read(path): return json.loads(path.read_text(encoding='utf-8-sig'))
def sha(path): return hashlib.sha256(path.read_bytes()).hexdigest()
def receipt(name, count, marker):
    path = out/('direct-'+name+'.json')
    data = read(path)
    log = path.with_suffix('.log').read_text(encoding='utf-8',errors='replace')
    assert data['exit'] == 0, (name,data['exit'])
    assert marker in log, (name,marker)
    return dict(name=name,count=count,receipt=path.name,log=path.with_suffix('.log').name,**data)

checks=[]
for mode in ['headless','gl_compatibility','mobile']:
    checks.append(receipt('test_editor_review_items-'+mode+'-final',78,'78 checks, 0 failures'))
checks.append(receipt('test_editor_admission_bytes-headless-final',10,'10 checks, 0 failures'))
checks.append(receipt('test_editor_graphics_preparation-gl_compatibility-checked',91,'91 checks, 0 failures'))
checks.append(receipt('test_editor_graphics_preparation-mobile-verification',91,'91 checks, 0 failures'))
for name,count,marker in [('test_native_road_geometry',115,'115 checks, 0 failures'),('test_editor_streams',41,'41 checks, 0 failures'),('test_app',141,'141 checks, 0 failures')]:
    checks.append(receipt(name+'-headless-final',count,marker))
for name,count,marker in [('test_editor_workflow',254,'254 checks, 0 failures'),('test_editor_t05_t11',321,'321 checks, 0 failures'),('test_editor_t11_t15',305,'305 checks, 0 failures'),('test_editor_review_fixes',69,'69 checks, 0 failures'),('test_editor_preparation',269,'269 checks, 0 failures'),('test_creator_capacity',2730,'checks=2730 failures=0'),('test_compiler_raster',8,'checks=8 failures=0'),('test_tyre_equivalence',13200,'13200 exact whole-state comparisons passed')]:
    checks.append(receipt(name+'-headless-verification',count,marker))
checks.append(receipt('profile_editor_fixed_preparation-gl_compatibility-final',60,'60 checks, 0 failures'))
checks.append(receipt('test_editor_shipping_parse-headless-final',486,'486 scripts, 0 failures'))
checks.append(receipt('profile_editor_fixed_history-headless-primed-final',None,'TRACK_EDITOR_HISTORY'))

views=[]
for mode in ['gl_compatibility','mobile']:
    data=read(out/'native'/mode/'results.json')
    assert data['failures']==0 and len(data['observations'])==6
    paths=sorted((out/'native'/mode).glob('*.png'))
    assert len(paths)==6
    views.append(dict(renderer=mode,captures=6,source_stable=data['source_stable'],source_before=data['source_before'],source_after=data['source_after'],images={str(p.relative_to(out)):sha(p) for p in paths}))
translations=[]
for language in ['de','en','es','fi','fr','it','ja','ko','nb','nl','pt_BR','sv']:
    entries=localization.parse_po((root/f'game/localization/{language}.po').read_text(encoding='utf-8'))
    for message in ['Race lighting','Confirm or discard the pending previews before sharing this circuit.']:
        entry=entries[('',message)]
        assert entry['msgstr'] and not entry['fuzzy']
        assert localization.placeholders(entry['msgstr'])==localization.placeholders(message)
        translations.append(dict(language=language,msgid=message,msgstr=entry['msgstr']))

profilelog=(out/'direct-profile_editor_fixed_preparation-gl_compatibility-final.log').read_text(encoding='utf-8')
performance=[json.loads(line.split('EDITOR_T01_T04 ',1)[1]) for line in profilelog.splitlines() if line.startswith('EDITOR_T01_T04 ')]
descriptor=root/'game/platform/track_geometry/track_geometry.gdextension'
windows=re.search(r'windows.x86_64 = "res://([^"]+)"',descriptor.read_text()).group(1)
libraries=[root/'game'/windows,root/'game/platform/track_geometry/libbmt_track_geometry.android.arm64.so',root/'game/platform/track_geometry/libbmt_track_geometry.android.x86_64.so']
for arch in ['arm64','x86_64']:
    raw=(out/f'android-{arch}-elf.log').read_bytes()
    lines=raw.decode('utf-16' if raw.startswith(b'\xff\xfe') else 'utf-8-sig').splitlines()
    loads=[line for line in lines if line.strip().startswith('LOAD')]
    assert loads and all(line.strip().endswith('0x4000') for line in loads)

sources=read(out/'checkpoint-sources.json')
initial=read(out/'before-hashes.json')
all_current={p:sha(root/p) for p in initial if (root/p).exists()}
findings=[
 dict(id='TER-C01',status='resolved',scope='aggregate admission, retained previews, released/property edits, exact durable bytes including derived lap'),
 dict(id='TER-C02',status='resolved',scope='platform/Esc/explicit rollback and cancelled transaction'),
 dict(id='TER-C03',status='resolved',scope='disjoint accept and start-arrow hit targets'),
 dict(id='TER-U01',status='resolved',scope='readable Night authoring and exact race-lighting toggle'),
 dict(id='TER-P01',status='partial',scope='exact native streams, outline decoding, fewer duplicate program draws',remaining='Long final width update and cold practice latency; no reliable end-to-end improvement established'),
 dict(id='TER-P02',status='resolved',scope='immutable block sharing, allocation accounting and primed initial checkpoint'),
 dict(id='TER-U02',status='resolved',scope='visible parameter/geometry rejection'),
 dict(id='TER-C04',status='resolved',scope='active/hidden preview resolution before Share'),
]
report=dict(
 status='seven_resolved_one_partial',date='2026-10-28',engine='4.7.2.stable.official.ed1daf0bf',findings=findings,
 checks=checks,native_views=views,translations=translations,
 performance=dict(final_app=performance,history=read(out/'history-profile.json'),unprimed_history=read(out/'history-unprimed-final.json'),baseline_review=dict(width_ms=4332.945,first_practice_ms=26865.449,history_median_ms=11.647,history_p95_ms=18.249,history_max_ms=20.451),reliable_cold_latency_improvement_claim=False),
 preferred_check=read(out/'preferred-check/receipt.json'),
 native_build=dict(command='powershell -NoProfile -ExecutionPolicy Bypass -File scripts/build_track_geometry.ps1 -Platform all',exit=0,final_log='native-build-outline.log',descriptor_sha256=sha(descriptor),active_libraries={str(p.relative_to(root)):dict(bytes=p.stat().st_size,sha256=sha(p)) for p in libraries},android_load_alignment=16384,phone_executed=False),
 checkpoint=dict(patch='task.patch',patch_sha256=sha(out/'task.patch'),files_checked=34,log='patch-check.log',sources=sources,source_only=True,shared_app_canvas_hunks_reconstructed=True,source_inventories_collected_by_concurrent_work=True),
 task_start_source_hashes=initial,current_task_start_paths=all_current,concurrent_paths_changed=[p for p,v in initial.items() if all_current.get(p)!=v],
 known_limitations=[
 'TER-P01 remains open: final width 4948.597 ms, first practice 26967.598 ms; smaller work counts do not establish a reliable latency fix.',
 'Unmodified full script parse: 1411 scripts, one failed frozen parking_hall_before Garage fixture, missing _build_wash_requirement; dependent fixture App diagnostics retained. Exportable 486-script check passes.',
 'Full localization audit reports 1045 other catalogue issues. The two new messages pass 24 language/message checks.',
 'Original review ellipse practice witness failures remain recorded; this pass does not classify them as fixed.',
 'Direct engine logs retain the sandbox root-certificate-store diagnostic.',
 'Initial profiler indentation/byte-fixture/exclusive-modal/incorrect-test-path attempts remain in raw logs. Final corrected receipts are listed explicitly.',
 'History keeps a second immutable value representation and uses conservative higher residency accounting; original shared 8 MiB and 40-state limits remain.',
 'Native program keys are transient process-local warm hints. Final exact world/effect draws and original appearance are retained.',
 'Concurrent owner work is preserved; there is no whole-tree freeze or release-certification claim.',
 ],
 remaining_acceptance=['Cold width/practice latency correction','Reload/rebuild','Owner appearance/interaction approval','Physical-device touch, latency and long-session memory'],
 boundaries=dict(device_query=False,device_test=False,apk=False,owner_save_mutation=False,backend_mutation=False,deployment=False,owner_process_restart=False,main_index_staging=False,commit=False,merge=False))
(out/'report.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps(dict(findings=len(findings),resolved=7,partial=1,successful_checks=len(checks),captures=12,translations=len(translations),files_checked=34)))
