# Canonical server engine provenance

Repository pin: `4.7.2.stable.official.ed1daf0bf`.

On 2026-09-28 the matching standard Linux x86_64 archive was obtained from the
[official Godot 4.7.2 archive](https://godotengine.org/download/archive/4.7.2-stable/)
using the [godotengine/godot-builds release metadata](https://api.github.com/repos/godotengine/godot-builds/releases/tags/4.7.2-stable).
The archive was checked against both the official release asset SHA256 and the
release's `SHA512-SUMS.txt`. The extracted binary's `--version` matched the repository
pin exactly in Ubuntu WSL. No substitute engine or third-party build was used.

| Artifact | SHA256 |
|---|---|
| `Godot_v4.7.2-stable_linux.x86_64.zip` | `cadd3204e728a35d3f13adb7fd0d7902636b79f6b95c40c265eb73b6c35329e4` |
| Extracted Linux executable | `8d106cbe6144c2dc7e881d61d2429c1a8a76e6b22ef48bd5e48dcf934953f71e` |

The executable is staged at ignored `backend/deploy/vendor/godot`. Original metadata,
archive and checksum file are retained locally in ignored `.tools/backend-linux/`;
neither executable nor downloaded archive is committed as a project source asset.
Godot is distributed under the [MIT license](https://godotengine.org/license/), with
its third-party notices. Preserve those notices when redistributing the engine image.
Python package wheels retain their own license metadata; `requirements.lock` pins
the dependency versions used by the image.

The Dockerfile verifies the executable SHA256 and full version, imports only the
curated canonical project, then replays a Windows-recorded five-lap fixture and checks
the complete expected manifest, finish ticks and per-lap ticks. This is a representative
cross-platform regression, not proof of equivalence for every track/hazard/vehicle.
