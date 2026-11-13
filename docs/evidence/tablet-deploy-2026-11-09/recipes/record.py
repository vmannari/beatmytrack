import hashlib,json,re,shutil
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2];OUT=Path(__file__).resolve().parent;EV=ROOT/'docs/evidence/tablet-deploy-2026-11-09'
def load(p):return json.loads(p.read_text(encoding='utf-8-sig'))
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
report=load(OUT/'deployment.json');assert not report['startup_errors']
ready=report['app_ready'] and report['foreground']
export=load(OUT/'export-result.json');identity=load(OUT/'identity-confirm.json');assert identity['equal']
assert report['prelaunch_manifest_exact'] and report['first_install_time_preserved']
assert sha(ROOT/'.git/index')==load(OUT/'initial-index.json')['sha256']
EV.mkdir(exist_ok=True)
for name in ['deployment.json','export-result.json','identity-confirm.json','device-commands.json','startup-filtered.log']:
 shutil.copyfile(OUT/name,EV/name)
snapshot=load(OUT/'snapshot.json')
(EV/'snapshot-summary.json').write_text(json.dumps({'root':snapshot['root'],'copied_files':snapshot['copied_files'],'manifest_sha256':sha(OUT/'snapshot.json'),'source_changes_during_export':export['source_changes'],'main_index_unchanged':True},indent=2)+'\n')
for name in ['freeze_current.py','run_export.py','install_verify.py','check_export_identity.py','record.py']:
 (EV/'recipes').mkdir(exist_ok=True);shutil.copyfile(OUT/name,EV/'recipes'/name)
text=f'''# Current update deployed to OnePlus Pad 2 — 2026-11-09

TDU01–TDU03: The owner requested tablet deployment. Build `{report['installed_version']}`
is installed on OPD2403, serial `{report['serial']}`, replacing
`{report['previous_version']}`. It includes the current optimised assets,
classic Super Rally and corrected Kart cockpit/driver.

The pinned official Godot 4.7.2 ARM64 export is {export['apk']['bytes']:,} bytes,
SHA-256 `{export['apk']['sha256']}`. All {report['zip_entries']:,} archive entries
pass CRC validation, with ARM64 as the only native ABI. Complete prepared assets
(551 resources / 2267 checks), six native pictures / 157 source hashes, import,
startup, driving, catalogue and menu checks pass through `scripts/dev.ps1
-Action ExportAndroid -AndroidPreset "Android ARM64" -QuickValidation
-CommandTimeoutSeconds 1200` using private offline PC test storage and the
existing signing configuration.

The initial live export stopped at its asset gate while another task was
rewriting Electric modules and Garage templates; no failed/stale APK was installed.
After current validation passed, the source and assets were copied into an
isolated snapshot. The final export takes {export['elapsed_seconds']:.3f} seconds
and changes no audited source or asset files. Its build identity reproduces
exactly after snapshot/index preparation completes. Concurrent work and the
main Git index remain unchanged.

Installation uses `scripts/dev.ps1 -Action InstallAndroid` with `adb install -r`.
The original first-install timestamp and all **{report['prelaunch_files_preserved']}
existing app-file hashes** remain exact before first launch. The previous APK
is retained privately for rollback. No uninstall, data clear or track sync occurs.
Installed and exported APK hashes match.

{'Actual startup reaches `APP_READY`, the app owns the foreground window and the filtered startup log contains no matched script/parse/fatal errors. A private tablet screenshot is retained under the task build directory.' if ready else 'Installation is verified. Android secure keyguard blocks startup/foreground verification; owner unlock is required. Startup is not yet qualified.'} This is an
installation/startup smoke check; driving feel, sustained frame time, thermal
behaviour, memory and visual acceptance on the tablet remain owner checks.
Normal app startup retains its existing online behaviour. No PC saves or direct
backend/admin operation or backend deployment were performed.

[Deployment receipt](evidence/tablet-deploy-2026-11-09/deployment.json),
[export](evidence/tablet-deploy-2026-11-09/export-result.json),
[exact identity check](evidence/tablet-deploy-2026-11-09/identity-confirm.json),
[snapshot summary](evidence/tablet-deploy-2026-11-09/snapshot-summary.json).
Private app-file manifests, rollback APK and any account-bearing screenshots remain
under `build/tablet-deploy-2026-11-09`. The reviewable source-only checkpoint is
recorded alongside the public receipts.
'''
(ROOT/'docs/TABLET_DEPLOYMENT_2026_11_09.md').write_text(text,encoding='utf-8')
block=f'''<!-- TABLET-DEPLOYMENT-20261109 -->
## Current update installed on OnePlus Pad 2 (2026-11-09)
TDU01-TDU03: Owner-authorised ARM64 update installs `{report['installed_version']}` over `{report['previous_version']}`. Source-audited isolated export, pinned official engine, 551-resource2267/0 and six-picture157-source preflight plus focused import/startup/driving/catalogue/menu gates pass. APK{export['apk']['bytes']}bytes/{report['zip_entries']}CRC entries, installed/exported hashes match. Original first-install timestamp and all{report['prelaunch_files_preserved']} app-file hashes remain exact before launch; prior APK retained. {'Actual APP_READY/foreground and zero matched startup errors verified.' if ready else 'Secure keyguard requires owner unlock; startup/foreground verification remains pending.'} Initial live export rejects concurrent Electric/Garage asset writes; no rejected APK installed, no data clear/track sync, PC-save/backend change or main-index write. [Receipts, commands, source pins and limits](docs/TABLET_DEPLOYMENT_2026_11_09.md). Owner driving/appearance/thermal/frame-time acceptance remains.
<!-- /TABLET-DEPLOYMENT-20261109 -->

'''
for relative in ['AGENTS.md','DEVELOPMENT_STATUS.md','docs/PHASE_0_PLAN.md']:
 p=ROOT/relative;before=p.read_bytes();target=OUT/'before'/relative;target.parent.mkdir(parents=True,exist_ok=True)
 if not target.exists():target.write_bytes(before)
 content=before.decode('utf-8');local=block.replace('(docs/TABLET_DEPLOYMENT_2026_11_09.md)','(TABLET_DEPLOYMENT_2026_11_09.md)') if relative.startswith('docs/') else block
 content=re.sub(r'<!-- TABLET-DEPLOYMENT-20261109 -->.*?<!-- /TABLET-DEPLOYMENT-20261109 -->\s*','',content,flags=re.S)
 p.write_text(local+content,encoding='utf-8')
print('Deployment report and status receipts recorded.')
