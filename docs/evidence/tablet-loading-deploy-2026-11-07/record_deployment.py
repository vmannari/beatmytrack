"""Publish deployment receipts without private saved-file manifests."""
import argparse
import json
from pathlib import Path
import shutil

OUT = Path(__file__).resolve().parent
ROOT = OUT.parents[1]
EVIDENCE = ROOT/'docs/evidence/tablet-loading-deploy-2026-11-07'
parser = argparse.ArgumentParser()
parser.add_argument('--garage-verified', action='store_true')
args = parser.parse_args()
export = json.loads((OUT/'export-result.json').read_text())
deployment = json.loads((OUT/'deployment.json').read_text())
assert export['exit_code'] == 0
assert set(export['source_changes']) <= {'game/core/build_identity.gd', 'game/project.godot'}
assert deployment['prelaunch_manifest_exact'] and deployment['first_install_time_preserved']
deployment['garage_first_entry_inspected'] = args.garage_verified
deployment['garage_revisit_inspected'] = args.garage_verified
deployment['garage_loading_window_removed'] = True if args.garage_verified else None
(OUT/'deployment.json').write_text(json.dumps(deployment, indent=2)+'\n')
for name in ['export-result.json', 'deployment.json', 'concurrent-source-export-result.json',
             'startup-filtered.log', 'garage-filtered.log', 'garage-warm-errors.json',
             'tablet.png', 'tablet-garage-entry.png', 'tablet-garage.png', 'tablet-garage-warm.png',
             'prepare_isolated.py', 'run_export.py', 'install_verify.py', 'record_deployment.py']:
    if (OUT/name).exists():
        shutil.copyfile(OUT/name, EVIDENCE/name)
ready = deployment['app_ready'] and deployment['foreground'] and not deployment['startup_errors']
status = 'Startup and direct Garage entry verified.' if ready and args.garage_verified else 'Installed; owner unlock/startup/Garage verification remains pending.'
text = f'''# Loading update deployed to OnePlus Pad 2, 2026-11-07

**TLD01/TLD02/TLDQ01:** {status}

The owner explicitly requested tablet deployment. The accepted loading-pass snapshot `{deployment['installed_version']}` replaces `{deployment['previous_version']}` on OPD2403, serial `{deployment['serial']}`. This package uses the pinned official Godot 4.7.2 engine and verified game improvements. The separate custom-engine prototype remains local and is not part of this APK.

Installation uses `adb install -r` through `scripts/dev.ps1 -Action InstallAndroid -AndroidPreset "Android ARM64"`, followed by `LaunchAndroid`. All **{deployment['prelaunch_files_preserved']} existing app-file hashes** and the original first-install timestamp remain exact immediately before/after replacement, before launch. The installed/exported APK hashes match. No uninstall, clear-data or track synchronization occurred. A copy of the previous installed APK is retained privately in `build/tablet-loading-deploy-20261107/previous-installed.apk` for rollback.

APK: **{export['apk']['bytes']} bytes**, SHA-256 **`{export['apk']['sha256']}`**, ARM64 only; all **{deployment['zip_entries']} ZIP entries** pass CRC validation. Export used the standard pinned `scripts/dev.ps1 -Action ExportAndroid -AndroidPreset "Android ARM64" -QuickValidation -CommandTimeoutSeconds 600`, private offline PC test storage and the existing debug signing setup. It completed in {export['elapsed_seconds']:.3f} seconds. Prepared assets468/1925checks/0failures, five exact native photographs/156 source hashes, import/startup, driving72/0, catalogue21/0 and menus41/0 pass.

The initial main-workspace export completed but was rejected by the source audit: three concurrently edited files changed during the build (`appearance_sync.gd`, `backend_client.gd`, `appearance_state.gd`). It was never installed. A new isolated root copies the accepted immutable snapshot and reproduces its exact `7aac39deacf24f1291b735bf98f40145` identity. The successful export source audit permits only generated metadata changes; concurrent edits remain intact. The first isolation helper encountered its existing native junction and stopped before changing it; a fresh isolated directory uses copied native inputs. All attempts remain in the task build directory. Existing catalogue-anchor and embedded text-data warnings remain recorded.

`APP_READY`: **{deployment['app_ready']}**; actual app-window focus: **{deployment['foreground']}**; matched startup errors: **{len(deployment['startup_errors'])}**. First/repeat Garage appearance inspected: **{args.garage_verified}**. This is a deployment/startup/UI smoke check, not proof of tablet loading gains, thermal behavior or full driving acceptance. The half-loading target remains unverified on the tablet.

[Deployment receipt](evidence/tablet-loading-deploy-2026-11-07/deployment.json), [export receipt](evidence/tablet-loading-deploy-2026-11-07/export-result.json), [snapshot manifest](evidence/tablet-loading-deploy-2026-11-07/frozen-project.json), and [loading implementation/results](LOADING_HALF_2026_11_06.md). Private account file manifests remain only under the build directory. No PC save or direct backend/admin operation, backend deployment, purchase or authentication action was performed. Normal app startup retains its existing online behavior.

[Task-only review patch and byte-exact forward/reverse check](evidence/tablet-loading-deploy-2026-11-07/checkpoint.json). The patch contains documentation, receipts and helper sources; raw captures/logs are hashed separately in the evidence inventory. Initial patch formatting needed terminal-newline handling; empty raw log evidence remains outside the text patch. Main repository staging/commits are not performed by this task.
'''
(ROOT/'docs/TABLET_LOADING_DEPLOYMENT_2026_11_07.md').write_text(text, encoding='utf-8')
marker = 'TABLET-LOADING-DEPLOY-20261107'
summary = f'''## Loading update installed on OnePlus Pad 2 (2026-11-07)
TLD01/TLD02/TLDQ01: Explicit deployment installs accepted7aac39deacf24f1291b735bf98f40145 over29b1076458152408e5486a7b4eec2d4b using pinned standard engine. All{deployment['prelaunch_files_preserved']} app files/first-install timestamp preserved before launch; installed/exported APK hashes match. ARM64 ZIP{deployment['zip_entries']} checks, prepared1925/0, photographs156-source, startup/driving72/catalogue21/menus41 pass. {status} Initial concurrent-source export rejected; isolated accepted snapshot reproduces identity and passes stable-source export. Prior APK retained; catalogue/text-data and initial isolation findings recorded. [Commands, receipts, captures and limits](REPORT_LINK). No data clear/track sync, PC-save or direct backend/admin operation/deployment. No tablet performance or half-loading claim; concurrent changes preserved.
'''
for relative in ['AGENTS.md', 'DEVELOPMENT_STATUS.md', 'docs/PHASE_0_PLAN.md']:
    path = ROOT/relative
    data = path.read_bytes()
    start_marker = ('<!-- '+marker+' -->').encode()
    if start_marker in data:
        start = data.index(start_marker)
        end = data.index(('<!-- /'+marker+' -->').encode(), start)+len('<!-- /'+marker+' -->')
        while data[end:end+1] in [b'\r', b'\n']:
            end += 1
        data = data[:start]+data[end:]
    link = 'TABLET_LOADING_DEPLOYMENT_2026_11_07.md' if relative.startswith('docs/') else 'docs/TABLET_LOADING_DEPLOYMENT_2026_11_07.md'
    block = '<!-- '+marker+' -->\n'+summary.replace('REPORT_LINK', link)+'<!-- /'+marker+' -->\n\n'
    path.write_bytes(block.encode()+data)
print(status)
