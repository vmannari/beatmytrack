# Build output retention

`build/` is disposable working output, not an archive. The owner requested cleanup and bounded retention on 2026-11-12.

Run `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/clean_build.ps1` to preview, or add `-Apply` to delete. Defaults: remove entries untouched for seven days, then remove oldest eligible entries until the directory reaches a 20 GiB target. Entries modified within 24 hours are exempt to avoid disrupting current work. An entry's age includes its real descendants, but never linked targets.

The cleaner runs before `scripts/dev.ps1` actions. `scripts/install_build_retention.ps1` installs an idempotent per-workspace Windows task at logon and daily at noon, under the current user's limited interactive account; missed runs resume when available. This also catches direct script output. Its last receipt replaces `.tmp/build-cleanup-last.json`; logs do not accumulate.

Tracked files, `.keep` markers anywhere inside an entry, signing material, unreadable entries, owner backup directories, `track-sync`, tools and named source-input directories are protected. Nested junctions/symlinks are unlinked without traversing or deleting their targets. All deletions are confined to the resolved workspace `build` directory. Concurrent cleanup runs use an exclusive lock.

The 20 GiB value is a retention target, not a filesystem quota: active, protected or locked output can exceed it. Cleanup warns when this happens. Long tasks should refresh a `.keep` marker at the top of their build entry and remove it when finished. Pins are explicit exceptions, so keep them small and review them. Avoid leaving an entire shared output directory pinned indefinitely.

Keep durable source changes in source control and concise receipts/comparison captures in `docs/evidence`; do not retain complete project copies, test profiles, shader caches, duplicate APKs or giant source checkpoints there. Avoid shifting disposable data into `tmp`, `archive` or another directory to bypass retention. Delete per-run disposable data when finished, and run cleanup at task completion.

The initial cleanup reduced roughly 168 GiB to about 22 GiB (47 remaining entries); C: had about 150 GiB free at final verification. Active output can change those measurements. The remaining total exceeds the 20 GiB target because of recent work and protected inputs. The scheduled run completed with result 0, no cleanup failures, and its next daily run set to 2026-11-13 at 12:00 local time.

Recovery preserves 27 root-level source patches/archive/signing candidates plus two hash-verified test/debug keystores in `archive/build-recovery-2026-11-12/` (29 files, 13,446,303 bytes). The keys came from obsolete renderer-test and Godot-source copies; their surrounding generated output was deleted. Authored `build/music` has a `.keep` marker for separate review; backup/source/tool exclusions remain in place. Other historical disposable build entries may no longer exist at paths cited by old reports.

Isolated fixtures verified dry-run behavior, seven-day expiry, oldest-first size pruning, active-work grace, tracked files, nested pins, signing material, readonly output, owner backups, junction-target preservation and refusal of a linked build root. Final PowerShell parsing and Python compilation passed. Sandbox-denied generated files required a scoped cleanup retry; no ACL changes or owner-process changes were made. Future daily tasks run outside the development sandbox under the owner's limited account.
