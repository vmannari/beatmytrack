from pathlib import Path
import hashlib,json,difflib,subprocess,shutil,re

R=next(p for p in Path(__file__).resolve().parents if (p/'godot-version.txt').exists())
E=Path(__file__).resolve().parent
read=lambda p:p.read_text(encoding='utf-8')
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
TAG='GARAGE-FIRST-ENTRY-20261027'
summary='''<!-- GARAGE-FIRST-ENTRY-20261027 -->
## Reduce first-entry Garage preparation and capture hitches (2026-10-27)
GFE01-GFE05/R01/Q01: Owner reports immediate-entry stutter and keeps the menu available with idle preparation. First menu draw/150ms CPU idle and250ms GPU idle replace the old2s wait; original input/focus/navigation/identity/race/pressure fences remain. Program-feature keys and round-robin floor/car-first batches retain8-object bounds, reducing the same-asset old-key114 draws to70headless/69native. Career wall and an exact selected picture prepare in the same world; capture-only4x/key-shadow settings match live, with gated draws and synchronized original reflections. Main saved livery/orbit/glass/lighting/shadows/camera remain; no cover or shader replacement. Seven templates regenerate with strict source guards/current native authors, including concurrent Compact context. Focused24headless/31Compatibility/31desktopMobile, retained preload399/App141/models28/reflections26/parser1353 and preferred check pass. Normal driver-cache early-entry observations0.64-1.08s, ready transition0.325s; immediate hitches and fully cold OpenGL compilation remain. The28s isolated restricted-cache result is not normal launch timing or a solved worst case; no zero-hitch/phone claim. Rejected shader/lazy/cache prototypes, transient concurrent/cache/fixture failures and corrected reflection synchronization remain in evidence. Commands, native views, hashes and binary-inclusive scoped checkpoint: docs/GARAGE_FIRST_ENTRY_2026_10_27.md and docs/evidence/garage-first-entry-2026-10-27/report.json. Reload and owner/device latency/input/appearance/memory acceptance remain. No device attachment query/test, APK, auth/purchase, owner-save/live backend mutation, deployment, main-index staging/commit/merge or owner-process restart. Concurrent work preserved.
<!-- /GARAGE-FIRST-ENTRY-20261027 -->

'''
for name in ['AGENTS.md','DEVELOPMENT_STATUS.md']:
 p=R/name;data=p.read_bytes();begin=('<!-- '+TAG+' -->').encode();end=('<!-- /'+TAG+' -->').encode()
 if begin in data:
  a=data.index(begin);b=data.index(end,a)+len(end)
  if data[b:b+2]==b'\n\n':b+=2
  data=data[:a]+data[b:]
 p.write_bytes(summary.encode()+data)

runtime=['game/core/app.gd','game/ui/garage_page.gd','game/ui/garage_preloader.gd','game/ui/garage_preloaded_studio.gd','game/ui/garage_preview_cache.gd','game/ui/car_showroom.gd','game/ui/garage_preview_renderer.gd']
new=['game/ui/garage_preview_renderer.gd','game/tests/test_garage_first_entry.gd','docs/GARAGE_FIRST_ENTRY_2026_10_27.md']
new += ['docs/evidence/garage-first-entry-2026-10-27/'+f for f in ['run_checks.py','run_preferred.py','trace_entry.gd','key_control.gd','refresh_templates.gd','audit_assets.gd','compile_report.py']]
for f in list(new):
 if f.endswith('.gd') and (R/(f+'.uid')).exists():new.append(f+'.uid')
docs=['AGENTS.md','DEVELOPMENT_STATUS.md']
binaries=['game/assets/garage/cars_v1/'+f+'.scn' for f in ['compact','pickup','classic','formula','kart','forklift','electric']]

def replace(s,a,b=''):
 assert s.count(a)==1,a[:150]
 return s.replace(a,b,1)
def baseline(name,after):
 if name in new:return ''
 if name in docs:
  a=after.index('<!-- '+TAG+' -->');b=after.index('<!-- /'+TAG+' -->',a)+len('<!-- /'+TAG+' -->')
  if after[b:b+2]=='\n\n':b+=2
  return after[:a]+after[b:]
 if name=='game/core/app.gd':
  return replace(after,'\tpage.preview_can_render=func() -> bool: return _publishing_slots_foreground and _background_work_allowed() and (menu_page_motion==null or not menu_page_motion.is_running())\n')
 if name=='game/ui/garage_page.gd':
  after=replace(after,'var preview_can_render: Callable\n')
  after=replace(after,'\t\t_preview_service.can_render=func() -> bool: return (not progressive_entry or not showroom.preparing) and (_menu_motion==null or not _menu_motion.is_running()) and (not preview_can_render.is_valid() or bool(preview_can_render.call()))\n','\t\t_preview_service.can_render=func() -> bool: return not progressive_entry or not showroom.preparing\n')
  return replace(after,'\t\tif showroom.has_method("take_carousel_picture"): _preview_service.prepared_picture=showroom.take_carousel_picture()\n')
 if name=='game/ui/car_showroom.gd':
  after=replace(after,'var preview_live_lighting: bool = false\n')
  after=replace(after,'Viewport.MSAA_2X if read_only and not preview_live_lighting else Viewport.MSAA_4X','Viewport.MSAA_2X if read_only else Viewport.MSAA_4X')
  return replace(after,'GarageEnvironment.build(world, car, read_only and not preview_live_lighting)','GarageEnvironment.build(world, car, read_only)')
 return read(E/'before'/name)

patch=[]
files=list(dict.fromkeys(runtime+docs+new))
for name in files:
 after=read(R/name);before=baseline(name,after)
 for folder,text in [('checkpoint-base',before),('task-final',after)]:
  p=E/folder/name;p.parent.mkdir(parents=True,exist_ok=True);p.write_text(text,encoding='utf-8',newline='\n')
 patch.append('diff --git a/'+name+' b/'+name+'\n')
 if name in new:patch.append('new file mode 100644\n')
 patch.extend(difflib.unified_diff(before.splitlines(True),after.splitlines(True),fromfile='/dev/null' if name in new else 'a/'+name,tofile='b/'+name))
for name in binaries:
 before=E/'before'/name;after=R/name
 p=E/'task-final'/name;p.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(after,p)
 result=subprocess.run(['git','diff','--no-index','--binary',str(before),str(after)],cwd=R,capture_output=True,text=True)
 assert result.returncode in [0,1],result.stderr
 if result.returncode:
  lines=result.stdout.splitlines(True);start=next(i for i,line in enumerate(lines) if line.startswith('index '))
  patch.append('diff --git a/'+name+' b/'+name+'\n');patch.extend(lines[start:])
(E/'checkpoint.patch').write_text(''.join(patch),encoding='utf-8',newline='\n')
check=subprocess.run(['git','apply','--reverse','--check',str(E/'checkpoint.patch')],cwd=R,capture_output=True,text=True)
(E/'checkpoint-check.json').write_text(json.dumps({'exit_code':check.returncode,'stdout':check.stdout,'stderr':check.stderr},indent=2))
assert check.returncode==0,check.stderr

commands={p.parent.name:json.loads(read(p)) for p in sorted(E.glob('*/command.json'))}
passing=['final-native-sync','final-mobile-quality','final-focused-headless','final-preload-clean','old-key-control','final-app-clean','final-models','final-reflections','final-parser','preferred-final','final-ready-real']
for label in passing:assert commands[label]['exit_code']==0,label
metrics={label:json.loads(read(E/label/'report.json')) for label in ['real-driver-control','initial-idle-real','broad-first-real','shared-lighting-real','final-ready-real','final-native-sync','final-mobile-quality','final-preload-clean','old-key-control']}
for label in ['real-driver-control','initial-idle-real','broad-first-real','shared-lighting-real','final-ready-real']:
 samples=metrics[label].pop('samples')
 metrics[label]['frame_phase_max_ms']={phase:max((row['frame_ms'] for row in samples if row['phase']==phase),default=0) for phase in ['preload','entry','live','orbit']}
 if label=='final-ready-real':
  rows=[row for row in samples if row['phase']=='preload']
  metrics[label]['preload_trace_span_ms']=rows[-1]['time_ms']-rows[0]['time_ms'] if rows else None
generated=['game/core/build_identity.gd','game/project.godot']
for name in generated:
 p=E/'generated-metadata'/name;p.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(R/name,p)
preserved=['game/ui/garage_reflections.gd','game/vehicle/car_visual.gd','game/vehicle/vehicle_simulation.gd','game/vehicle/livery_graphics.gd','game/vehicle/vehicle_weathering.gd']
native_sources={}
for p in sorted((R/'game/vehicle').glob('*.gd')):
 if p.name in ['car_visual.gd','vehicle_models.gd','visual_geometry.gd'] or p.name.startswith(('compact_','electric_','kart_','forklift_')):native_sources[p.relative_to(R).as_posix()]=sha(p)
(E/'native-source-hashes.json').write_text(json.dumps(native_sources,indent=2))
report={'requirements':['GFE01','GFE02','GFE03','GFE04','GFE05','R01','Q01'],'engine':read(R/'godot-version.txt').strip(),'runtime_scope':runtime,'derived_assets':binaries,'source_sha256':{name:sha(R/name) for name in files+binaries},'preserved_sources':{name:{'sha256':sha(R/name),'matches_task_start':sha(R/name)==sha(E/'before'/name)} for name in preserved},'generated_metadata':{name:sha(R/name) for name in generated},'native_context':'Templates were regenerated from current native authors; concurrent Compact geometry is preserved, not an authored delta of this task. Strict native-builder checks pass. Source hashes are in native-source-hashes.json.','passing_runs':passing,'commands':commands,'metrics':metrics,'results':{'focused_headless':24,'focused_compatibility':31,'focused_desktop_mobile':31,'preload_headless':399,'app':141,'native_models':28,'reflections':26,'parser':1353},'checkpoint':{'path':'checkpoint.patch','sha256':sha(E/'checkpoint.patch'),'bytes':(E/'checkpoint.patch').stat().st_size,'reverse_check_exit_code':check.returncode},'limits':['Normal driver-cache timings are separate from restricted fresh-cache stress tests. Driver caches were not cleared.','Immediate entry can still hitch; fully cold OpenGL compilation is unresolved.','Active desktop/GPU load and concurrent source changes prevent a calibrated overall speedup claim.','No phone, zero-hitch, instant-launch or device-memory guarantee.','Original game renderer and original shader sources remain selected; rejected prototype programs are not shipped.'],'initial_findings':['Six templates initially rejected changed Electric source hashes; concurrent Compact edits later invalidated all seven. Source guard remains strict.','A canonical repeat reused its disk PNG; fixture now forces both native controls.','First gated capture omitted camera/reflection sync and failed the unchanged 0.01-byte allowance. Original submit rendering fixes the receiving pose.','Concurrent JumpProfiles class-cache and detached account-panel errors occurred; their guards/current sources arrived independently and are preserved.','Shared shader/PBR/cache-disable and lazy-allocation prototypes did not prove sufficient improvement. Lazy changes were restored exactly before the final optional preview-lighting change.','A virtual shader RID API probe was not callable; it is not used in runtime.','An initial dev check omitted ScriptPath and was not a valid check. The final preferred wrapper check specifies the App script.','Process cleanup required correcting a PowerShell predicate and using .NET process termination after Stop-Process itself failed. Only exact failed task helpers were selected.'],'not_performed':['physical-device attachment query/test','APK/AAB','real authentication/purchase','owner-save/live backend mutation','deployment','main-index staging/commit/merge','owner-process restart'],'primary_sources':['https://docs.godotengine.org/en/stable/tutorials/rendering/jitter_stutter.html','https://docs.godotengine.org/en/stable/tutorials/performance/pipeline_compilations.html','https://raw.githubusercontent.com/godotengine/godot/ed1daf0bf/drivers/gles3/shader_gles3.cpp']}
(E/'report.json').write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps({'commands':len(commands),'passing_runs':len(passing),'checkpoint_bytes':report['checkpoint']['bytes'],'reverse_check_exit':check.returncode}))
