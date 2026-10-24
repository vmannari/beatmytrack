# Archived native libraries

These DLL generations are retained for rollback outside the Godot resource root.
Each directory is the complete SHA256 of the unchanged file it contains. Current
extension descriptors continue to select the libraries under `game/platform/`.

Use `scripts/archive_native_libraries.ps1` for a dry run or pass `-Archive` to
quarantine unused names. Descriptor dependencies and libraries loaded by running
Godot processes remain in place. Incomplete process inspection prevents moves.
Native build scripts invoke the same retention policy after successful builds.

Restore a generation only with the matching extension descriptor, source/build
contract and license notices. Keep the existing notices in
`game/platform/windows/NOTICE.txt`, `game/platform/track_geometry/NOTICE.txt` and
their adjacent Godot, GCC, MinGW and threading license files with any distributed
copy. The archive is not an independently licensed application distribution.

The cleanup inventory and hashes are in
`docs/evidence/legacy-cleanup-2026-10-24/native-after.json`.
