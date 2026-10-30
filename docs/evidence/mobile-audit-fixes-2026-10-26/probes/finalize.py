from pathlib import Path
import difflib,hashlib,json,re,shutil,subprocess
ROOT=Path(__file__).resolve().parents[2]; OUT=Path(__file__).resolve().parent
DEST=ROOT/'docs/evidence/mobile-audit-fixes-2026-10-26'
DEST.mkdir(parents=True,exist_ok=True)
def digest(data): return hashlib.sha256(data).hexdigest()
def copy(source,target):
    target.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(source,target)

# Existing tracked historical evidence was clean at task start. Preserve the
# accidentally defaulted current report separately, then restore those exact HEAD
# bytes. No original runtime source or concurrent documentation is checked out.
historical=ROOT/'docs/evidence/menu-high-priority-fixes-2026-10-14/headless/report.json'
initial_status=(OUT/'git-status-before.txt').read_text(encoding='utf-8')
assert historical.relative_to(ROOT).as_posix() not in initial_status
head=subprocess.check_output(['git','show','HEAD:'+historical.relative_to(ROOT).as_posix()],cwd=ROOT)
if historical.read_bytes()!=head:
    copy(historical,OUT/'historical-output-restored.json');historical.write_bytes(head)

block='''<!-- MOBILE-AUDIT-FIXES-20261026 -->
## Selected mobile audit fixes (2026-10-26)
MA13/MA04/MA05/MA06/MA07/MA08/MA10: Guest/Race startup no longer awaits Garage; seven native-rendered carousel photos replace seven retained workshop worlds (24 to 3 viewports). Exact appearance/build caches use one temporary renderer and an owned 14-image bound. Native startup is about160ms; cold live Garage still takes8.3s desktop Mobile /12.6–14.3s Compatibility. Vinyl redraws room reflection only (24/0 room/car requests); movement/appearance/visibility guards remain. Scalar exact controls reduce216000-input memory43.75to7.47MB; versioned count/proof/ghost/rewind journals retain old bytes, retry keys, migration and pinned transport. Node-owned row fitting removes freed captures. Store131headless/144Compatibility/144desktopMobile fit checks pass. All12 catalogues are current with authored copy and preserved existing translations. Explicit guest Help diagnostic copy is bounded/redacted and does not change consent; safe backend failure sites and future native symbol retention/mapping are included. Focused263Compatibility/263desktopMobile, native retention72 with unchanged pixel tolerances, App141/tutorial168/upload44/launch18656/driving72/rewind61 and retained Garage checks pass; broader pre-existing failures and initial fixture/proposal failures remain in evidence. Sources, commands, source hashes, captures, task-only review patch and limits: docs/MOBILE_AUDIT_FIXES_2026_10_26.md and docs/evidence/mobile-audit-fixes-2026-10-26/report.json. Reload/rebuild, backend logging rollout, matching production symbols and owner/device startup/Garage/diagnostic acceptance remain. No device attachment check/test, APK/AAB, real authentication/purchase, live mutation, deployment, merge, commit or owner-process restart; concurrent header/Garage/electric/handling/track/Rivalry changes preserved and excluded.
<!-- /MOBILE-AUDIT-FIXES-20261026 -->

'''
for relative in ['AGENTS.md','DEVELOPMENT_STATUS.md']:
    path=ROOT/relative;data=path.read_bytes()
    if b'<!-- MOBILE-AUDIT-FIXES-20261026 -->' not in data:
        bom=b'\xef\xbb\xbf' if data.startswith(b'\xef\xbb\xbf') else b''
        path.write_bytes(bom+block.encode('utf-8')+data[len(bom):])
audit=ROOT/'docs/COMPREHENSIVE_MOBILE_AUDIT_2026_10_26.md'
note='\n\nFollow-up: the owner-requested MA13, MA04, MA05, MA06, MA07, MA08 and MA10 changes are documented in [Selected mobile audit fixes](MOBILE_AUDIT_FIXES_2026_10_26.md). Measurements and findings below describe the original audit checkpoint; its evidence is retained.\n'
audit_text=audit.read_text(encoding='utf-8-sig')
if note.strip() not in audit_text:
    first,remaining=audit_text.split('\n',1);audit.write_text(first+note+'\n'+remaining,encoding='utf-8')

modified=['game/core/app.gd','game/ui/garage_page.gd','game/ui/car_showroom.gd','game/ui/garage_reflections.gd','game/ui/race_pause_menu.gd','game/ui/settings_page.gd','game/ui/store_page.gd','game/race/attempt_evidence.gd','game/backend/cloud_tracks.gd','game/editor/track_document.gd','backend/bmt_backend/observability.py','backend/bmt_backend/middleware.py','backend/bmt_backend/quality.py','scripts/build_track_geometry.ps1','scripts/dev.ps1','scripts/localization.py','scripts/test_localization.py','game/tests/test_app.gd','game/tests/test_launch_start.gd','game/tests/test_editor_practice.gd','game/tests/test_backend_scalability.gd','game/tests/test_pending_input_recovery.gd','game/tests/test_menu_high_priority.gd']
modified += ['game/localization/messages.pot']+[p.relative_to(ROOT).as_posix() for p in sorted((ROOT/'game/localization').glob('*.po'))]
created=['game/ui/content_fit_button.gd','game/ui/garage_cached_thumbnail.gd','game/ui/garage_preview_cache.gd','game/race/input_record.gd','game/diagnostics/support_report.gd','game/tests/test_mobile_audit_fixes.gd','scripts/bake_garage_previews.gd','scripts/check_garage_previews.py','scripts/retain_native_symbols.ps1','scripts/translations/mobile_audit_fixes_2026_10_26.tsv','backend/tests/test_failure_sites.py','native/google_sign_in/src/org/beatmytrack/signin/BmtDiagnosticTrace.java','native/google_sign_in/tests/DiagnosticTraceTest.java','docs/MOBILE_AUDIT_FIXES_2026_10_26.md']
created += [name+'.uid' for name in created if name.endswith('.gd') and (ROOT/(name+'.uid')).exists()]
created += [p.relative_to(ROOT).as_posix() for p in (ROOT/'game/assets/garage/previews_v1').glob('*') if p.suffix!='.png']
binary=[p.relative_to(ROOT).as_posix() for p in sorted((ROOT/'game/assets/garage/previews_v1').glob('*.png'))]

# Native files were read before editing but outside the original generic snapshot.
# Recover the review base by reversing only these explicitly recorded additions.
native_bases={}
name='native/google_sign_in/src/org/beatmytrack/signin/BmtGoogleSignIn.java'
current=(ROOT/name).read_text(encoding='utf-8-sig')
addition='\n    /** Explicit support action only; bounded first-party frames, no raw traces. */\n    @UsedByGodot public String getSupportExits() {\n        return BmtProcessExits.readSupport(getActivity());\n    }\n'
assert addition in current
native_bases[name]=current.replace(addition,'')
name='native/google_sign_in/src/org/beatmytrack/signin/BmtProcessExits.java'
current=(ROOT/name).read_text(encoding='utf-8-sig')
current=current.replace('/** Coarse consented telemetry, plus explicit local support frames; never raw traces. */','/** Bounded OS process metadata; never stack traces, PIDs, identifiers or tokens. */')
current=current.replace('        return read(activity, false);\n    }\n    public static String readSupport(Activity activity) {\n        return read(activity, true);\n    }\n    private static String read(Activity activity, boolean support) {\n','')
current=current.replace('if (!support) Collections.reverse(exits);','Collections.reverse(exits);')
begin=current.index('                record.put("at", exit.getTimestamp()); record.put("reason", reason);')
end=current.index('                result.put(record);',begin)+len('                result.put(record);')
current=current[:begin]+'                record.put("at", exit.getTimestamp()); record.put("reason", reason); result.put(record);'+current[end:]
native_bases[name]=current

def concurrent_base(relative,before,current):
    if relative not in ['game/core/app.gd','game/ui/garage_page.gd']:return before
    a=before.splitlines(True);b=current.splitlines(True);result=[]
    for tag,a0,a1,b0,b1 in difflib.SequenceMatcher(None,a,b,autojunk=False).get_opcodes():
        text=''.join(b[b0:b1])
        if tag=='equal':result.extend(b[b0:b1]);continue
        if relative=='game/core/app.gd':
            ours=not ('header_car_picker.gd' in text or 'func _select_header_vehicle' in text)
        else:
            ours=any(marker in text for marker in ['var cached_carousel','var _preview_service','if cached_carousel','garage_cached_thumbnail.gd'])
        result.extend(a[a0:a1] if ours else b[b0:b1])
    return ''.join(result)

patch=[];files=[]
all_text=modified+created+list(native_bases)+['AGENTS.md','DEVELOPMENT_STATUS.md','docs/COMPREHENSIVE_MOBILE_AUDIT_2026_10_26.md']
for relative in dict.fromkeys(all_text):
    path=ROOT/relative;data=path.read_bytes();current=data.decode('utf-8-sig').replace('\r\n','\n');old=None
    if relative in modified:
        old=(OUT/'before'/relative).read_text(encoding='utf-8-sig')
        old=concurrent_base(relative,old,current)
    elif relative in native_bases:old=native_bases[relative]
    elif relative in ['AGENTS.md','DEVELOPMENT_STATUS.md']:old=current.replace(block,'',1)
    elif relative==audit.relative_to(ROOT).as_posix():old=current.replace(note+'\n','\n',1)
    if old is not None and old==current:continue
    diff=''.join(difflib.unified_diff((old or '').splitlines(True),current.splitlines(True),fromfile='a/'+relative if old is not None else '/dev/null',tofile='b/'+relative))
    patch.append('diff --git a/'+relative+' b/'+relative+'\n'+('new file mode 100644\n' if old is None else '')+diff)
    if old is not None:
        base=DEST/'scope-base'/relative;base.parent.mkdir(parents=True,exist_ok=True);base.write_text(old,encoding='utf-8',newline='\n')
    copy(path,DEST/'checkpoint'/relative)
    files.append({'path':relative,'sha256':digest(data),'review_base_sha256':digest(old.encode('utf-8')) if old is not None else None,'native_base_reconstructed_by_reversing_task_additions':relative in native_bases})
for relative in binary:
    path=ROOT/relative;copy(path,DEST/'checkpoint'/relative);files.append({'path':relative,'sha256':digest(path.read_bytes()),'binary_asset':True})
review=DEST/'review.patch';review.write_text(''.join(patch),encoding='utf-8',newline='\n')
validation=subprocess.run(['git','apply','--reverse','--check','--ignore-space-change',str(review)],cwd=ROOT,capture_output=True,text=True)
(DEST/'patch-validation.json').write_text(json.dumps({'command':['git','apply','--reverse','--check','--ignore-space-change',str(review)],'exit_code':validation.returncode,'stdout':validation.stdout,'stderr':validation.stderr},indent=2),encoding='utf-8')

for pattern in ['*.log','*.json']:
    for path in OUT.glob(pattern):copy(path,DEST/('commands' if path.suffix=='.json' else 'logs')/path.name)
for path in OUT.glob('*.gd'):copy(path,DEST/'probes'/path.name)
for path in OUT.glob('*.py'):copy(path,DEST/'probes'/path.name)
captures=[]
for relative in ['garage-cached.png','settings-help-diagnostics.png','focused-mobile/garage-cached.png','focused-mobile/settings-help-diagnostics.png']:
    source=OUT/relative
    if source.exists():
        name=relative.replace('/','-');copy(source,DEST/'captures'/name);captures.append(name)
for method in ['gl_compatibility','mobile']:
    for name in ['store-1280x720.png','store-960x540.png','narrow-600x360-top.png','narrow-600x360-bottom.png']:
        source=OUT/'store-captures'/method/name
        if source.exists():copy(source,DEST/'captures'/(method+'-'+name));captures.append(method+'-'+name)
retained=OUT/'retention/menu-native-matched'
for source in retained.glob('*.png'):
    copy(source,DEST/'captures'/('retention-'+source.name));captures.append('retention-'+source.name)
for source in (OUT/'focused-mobile').glob('*.json'):copy(source,DEST/'commands'/('mobile-'+source.name))
results=[]
for path in sorted(OUT.glob('*.json')):
    try:value=json.loads(path.read_text(encoding='utf-8-sig'))
    except ValueError:continue
    if isinstance(value,dict) and isinstance(value.get('command'),list):
        log=OUT/(path.stem+'.log');text=log.read_text(encoding='utf-8-sig',errors='replace') if log.exists() else ''
        results.append({'name':path.stem,**value,'log':'logs/'+log.name,'failure_lines':[line for line in text.splitlines() if 'FAIL:' in line or 'SCRIPT ERROR:' in line],'certificate_store_environment_error':'Failed to read the root certificate store' in text,'resource_exit_warning':'objects were leaked' in text.lower() or 'resources still in use' in text.lower()})
checkpoint_sources={path.relative_to(ROOT).as_posix():digest(path.read_bytes()) for path in [ROOT/'game/core/build_identity.gd',ROOT/'game/project.godot',ROOT/'game/vehicle/vehicle_simulation.gd',ROOT/'game/input/drive_frame.gd'] if path.exists()}
report={'schema':'bmt-mobile-audit-fixes-v1','date':'2026-10-26','requested':['MA13','MA04','MA05','MA06','MA07','MA08','MA10'],'implementation_status':'implemented; rebuild/rollout and owner/device acceptance remain','engine':'4.7.2.stable.official.ed1daf0bf','files':files,'binary_assets_in_checkpoint_not_text_patch':binary,'patch':{'path':'review.patch','sha256':digest(review.read_bytes()),'reverse_check_exit_code':validation.returncode,'scope':'Task changes only, with current concurrent header/Garage changes retained in the review base; no staging or commit.'},'checkpoint_context_sources':checkpoint_sources,'commands':results,'captures':captures,'original_audit':'../mobile-audit-2026-10-26/report.json','metrics':{'retained_garage_viewports':3,'old_retained_garage_viewports':24,'old_startup_attribution_ms':25750,'compatibility_ready_ms':162.558,'mobile_ready_ms':159.67,'cold_live_garage_compatibility_ms':12549.716,'cold_live_garage_mobile_ms':8306.861,'input_memory_216000_before_bytes':43753760,'input_memory_216000_after_bytes':7467032,'vinyl_24_frames_room_car_reflection_requests':[24,0],'locale_message_count':2620,'locales':12},'retained_failures':{'editor_practice':'Same four failures and later Nil state error after affected task-start scripts are reloaded only in isolated process memory.','exception_recovery':'Obsolete direct-input submit fixture: same mixed transport failure and schema error with task-start scripts.','resume_budget':'Same three backlog assertions and missing deadline key with exact task-start Cloud script. First full-UI baseline attempt also caught a transient concurrent Rivalry compile error; corrected Cloud-only reproduction is retained.','gameplay_retention':'Same forklift/1 exact-old-simulation failure in 4303 checks; task-start affected scripts also reproduce the old freed pause-row captures, absent from the corrected run.','native_retention_initial_fixture':'Reference lacked the production achievement provider and trophy wall. Provider parity restores 72/72 without changing pixel tolerances.','native_test_exit':'Some Store/reflection runs log four leaked objects/one retained resource; focused cache/lifetime runs do not.','sandbox':'Pinned engine reports inability to read Windows root certificate store; no trust-policy changes.'},'boundaries':['No physical-device attachment check or device test','No APK/AAB build','No real authentication or purchase','No live data mutation or deployment','No merge, commit or owner-process restart'],'acceptance_remaining':['Reload/rebuild the client','Cold live Garage latency and device appearance/touch acceptance','Android disposable crash/ANR and clipboard validation on a rebuilt app','Matching production symbols and Java mappings for release artifacts','Separately authorized backend logging rollout and operator Play-vitals access'],'historical_test_output':'A tracked historical report verified clean at task start was restored byte-exactly from HEAD after a test default wrote to it. Task reports now use dedicated output paths.'}
(DEST/'report.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
(DEST/'README.md').write_text('# Selected mobile audit fixes evidence\n\nSee [the implementation report](../../MOBILE_AUDIT_FIXES_2026_10_26.md) and [machine-readable results](report.json). `logs/` retains initial, rejected and baseline results as well as passing runs. `checkpoint/` contains the final scoped sources/assets; `scope-base/` preserves concurrent changes for the task-only [review patch](review.patch). Binary PNGs are inventoried separately. No patch was applied or committed.\n',encoding='utf-8')
print(json.dumps({'files':len(files),'commands':len(results),'captures':len(captures),'patch_check':validation.returncode,'patch_error':validation.stderr[-1800:]},indent=2))
