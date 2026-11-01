# WSL disk-space investigation — 31 October 2026

## Findings

- Windows initially had approximately 50.2 GiB free during this investigation.
- Ubuntu's `ext4.vhdx` occupied 312,713,674,752 bytes (291.24 GiB) on C:.
- After the targeted cleanup, `df` reported 259,027,189,760 bytes in use in
  Ubuntu. The approximately 50 GiB difference is an upper-bound indication,
  not a guarantee of the space that compaction will recover: virtual-disk and
  filesystem allocation/metadata differ.
- Ubuntu hosts other projects as well as Beat my track. Its Docker environment
  had five running containers, including the Beat my track development API,
  worker and database, and the Money Maker API and frontend. A separate Codex
  process was also running inside Ubuntu. No service was stopped or restarted.
- The large Composer vendor and Money Maker research files checked did not
  have creation/change or modification timestamps in the preceding 48 hours.
  The available measurements do not prove the cause of the owner's reported
  day-over-day decline.

## Completed cleanup

The existing `backend/Dockerfile` identifies its `verifier-project` stage and
its `COPY game /source/game` step. Eleven old, unshared, reclaimable BuildKit
cache chains for that exact step were individually checked and pruned by ID,
including only the stale verifier staging dependencies required to free them.
Docker reported approximately 14 GiB for the removed game-copy records. One
additional 227 MB matching record was shared and retained. Images, containers,
volumes, other projects and the current game sources were not removed.

Before cleanup Ubuntu reported about 256 GiB used; afterwards it reported about
241 GiB used. An online `fstrim /` completed, but the Windows VHDX allocation
and Windows free-space measurement did not shrink. The large number reported
by `fstrim` describes filesystem ranges, not space recovered on Windows.

## Possible next step — not performed

The installed WSL provides `wsl --manage Ubuntu --compact`. Compaction of this
shared virtual disk requires a maintenance window and may interrupt all Ubuntu
processes. In particular the active Beat my track and Money Maker services and
the separate Codex session must be accounted for. With explicit owner approval,
record the then-running services, coordinate a graceful stop, compact the Ubuntu
VHDX using WSL's native command, start the required services again, and verify
both their status and the actual Windows free-space change. Active jobs or
other interactive sessions cannot be assumed to resume. Compaction operates on
the shared VHDX in place and its recovery amount is not guaranteed. No full
VHDX backup was created in this investigation.

## Recent workspace observations

A link-aware file scan found approximately 8.93 GiB created in the past
48 hours under `build/android-renderer-comparison-20261031`, 5.66 GiB under
`tmp`, and 3.91 GiB under `.git/objects`. Creation timestamps identify files
created recently; they do not prove a net increase by the same amount, since
files may have replaced older files. The renderer comparison contains recent
active diagnostic evidence, the temporary folder contains current work, and
Git objects are repository data, so none were removed in this investigation.

## Compaction performed with owner approval

The owner approved a temporary Ubuntu stop, native VHDX compaction and service
restart. The five then-running containers were stopped gracefully; Ubuntu was
terminated; `wsl --manage Ubuntu --compact` completed with exit code 0; and
all five recorded containers were started again. The VHDX decreased from
291.24 to 272.60 GiB, a reduction of 18.64 GiB. Windows free space increased
from 49.64 to 73.66 GiB during the operation; other disk activity means that
the free-space change need not exactly match the VHDX reduction.

Beat my track's database and API returned to healthy; its worker and the Money
Maker frontend returned to running. The Money Maker API had been unhealthy
before maintenance and, after restart, entered a restart loop because the
`timescaledb` host was unavailable. Its database container was already stopped
before maintenance and was not started or modified. Other interactive Ubuntu
processes, including the prior Codex process, were interrupted and are not
assumed to have resumed.

## Additional Docker image inventory

Docker identified 74 Beat my track images created before 25 October with no
running or stopped container reference. Docker reported approximately 27.5 GiB
of unique layers for this selection; its aggregate reclaimable figure was
internally inconsistent, so this is an estimate rather than measured savings.
Two images with digest-form aliases are excluded from the prepared backup set.
The exact inventory is `docs/evidence/wsl-storage-cleanup-2026-10-31/image-inventory.json`.
A further offline compaction would be needed to return newly freed Ubuntu disk
blocks to Windows and would again interrupt Ubuntu workloads.

## Further project-specific cleanup and second compaction

Seventy-two older Beat my track Docker images with no running or stopped
container references were exported to six compressed Docker archives under
`\\DS925\homes\vmannari\Beat my track\codex-cleanup-2026-10-31\docker-image-archives-2026-10-31`.
Two images with digest-form aliases were excluded. Archive read-back hashes,
image configurations, tags, referenced layers and content-addressed blob hashes
were verified before removing the 72 local image identities. No remote registry
images were deleted. The exact image inventory, archive validation, and removal
results are in `docs/evidence/wsl-storage-cleanup-2026-10-31/`.

To restore a batch, copy its `.tar.gz` archive from the NAS to the workspace
`tmp` directory, then run `wsl -d Ubuntu -- docker image load -i` with its
corresponding Linux `/mnt/c/Codes/Godot/Beat my track/tmp/...` path. Loading a
batch restores all image tags in that batch; check for newer tags first.

After image removal, 102 newly unshared, reclaimable Docker build-cache records
were individually pruned. Their commands and dependency history matched this
project's backend build, and they were last used two to four weeks earlier.
The Linux filesystem's measured used bytes declined from 259,027,189,760 after
the first compaction to 236,132,880,384 before the second: 21.32 GiB. Docker's
per-image unique-size estimate was much higher and did not equal the measured
filesystem reduction.

The owner-approved follow-up compaction is recorded in
`docs/evidence/wsl-storage-cleanup-2026-10-31/compaction-results.json`. At the time of the breakdown, other Ubuntu projects and their data
included approximately 58 GiB of Money Maker project files, 44 GiB of a
separate Composer environment, and 34 GiB in two other projects' database
volumes; these figures are approximate and were not removed.

## Final outcome

Both WSL compactions completed successfully. The virtual disk decreased from
291.24 GiB to 251.45 GiB, a reduction of 39.79 GiB. Windows free space rose
from 49.64 GiB before this investigation's maintenance to approximately
96.8 GiB afterward; concurrent disk activity means the free-space change is
not identical to the virtual-disk reduction. Ubuntu reported approximately
220 GiB used after cleanup.

All 72 selected older local Docker images were removed only after six NAS
archives were verified. Independent verification covered 1,108 content-addressed
blobs and the image manifests, configurations and tags; a Docker load was not
performed. The 102 selected unshared backend build-cache records were removed.
The Beat my track API and database returned healthy and its worker was running.
The Money Maker frontend was running; its API was restarting because its
`timescaledb` host was unavailable. The API had been unhealthy before the first
shutdown, although it was then running rather than restarting. Its database
container was already stopped and was not started.

## Final Windows-space measurement

After both compactions and archiving the isolated garage test profiles and the
28 October tablet test snapshot, Windows reported 111,945,191,424 bytes free:
104.26 GiB (111.95 decimal GB). At the start of WSL maintenance it reported
approximately 49.64 GiB free. This is a concurrent-system measurement, not a
claim that every byte of the increase came solely from these actions.

The final check showed the Beat my track API and database healthy and the
worker running. The Money Maker frontend was running; its API was restarting
because its `timescaledb` host was unavailable. The API was unhealthy before
maintenance but had been running rather than restarting; its database container
was already stopped and was not started by this work.
