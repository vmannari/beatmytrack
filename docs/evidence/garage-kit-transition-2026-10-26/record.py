"""Record the task's native frames, exact commands and scoped source checkpoint."""
from pathlib import Path
import difflib
import hashlib
import json
import math
import re
import struct
import subprocess
import zlib

HERE = Path(__file__).resolve().parent
REPO = HERE.parents[2]
RUNTIME = ["game/ui/car_showroom.gd", "game/ui/garage_page.gd", "game/ui/garage_kit_transition.gd", "game/ui/garage_cached_thumbnail.gd"]
SCOPE = RUNTIME + ["game/ui/garage_kit_transition.gd.uid", "game/tests/test_garage_kit_transition.gd", "game/tests/test_garage_kit_transition.gd.uid"]


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


patch = []
for name in SCOPE:
    before = HERE / "before" / name
    after = REPO / name
    patch.extend(difflib.unified_diff(
        before.read_text(encoding="utf-8").splitlines(keepends=True) if before.exists() else [],
        after.read_text(encoding="utf-8").splitlines(keepends=True),
        fromfile="a/" + name if before.exists() else "/dev/null",
        tofile="b/" + name,
    ))
(HERE / "task-only.patch").write_text("".join(patch), encoding="utf-8", newline="\n")
reverse = subprocess.run(["git", "apply", "--reverse", "--check", str(HERE / "task-only.patch")], cwd=REPO, capture_output=True, text=True)
if reverse.returncode:
    raise RuntimeError(reverse.stderr)

native = HERE / "test_garage_kit_transition-gl_compatibility"
# Snapshots are evenly spaced in shader progress. Replay their actual sine easing.
times = [math.acos(1 - 2 * index / 18) / math.pi * 580 for index in range(19)]
durations = [round(times[index + 1] - times[index]) for index in range(18)] + [1100]
durations[0] += 450


def chunk(kind, content):
    return struct.pack(">I", len(content)) + kind + content + struct.pack(">I", zlib.crc32(kind + content) & 0xffffffff)


def png_chunks(path):
    data = path.read_bytes()
    assert data[:8] == b"\x89PNG\r\n\x1a\n"
    offset = 8
    while offset < len(data):
        size = struct.unpack(">I", data[offset:offset+4])[0]
        yield data[offset+4:offset+8], data[offset+8:offset+8+size]
        offset += size + 12


# Assemble lossless native PNG streams into APNG without decoding or editing pixels.
frames = [list(png_chunks(native / f"motion-{index:02d}.png")) for index in range(19)]
header = frames[0][0][1]
width, height = struct.unpack(">II", header[:8])
animation = bytearray(b"\x89PNG\r\n\x1a\n")
animation += chunk(b"IHDR", header)
animation += chunk(b"acTL", struct.pack(">II", len(frames), 0))
sequence = 0
for index, frame in enumerate(frames):
    assert frame[0] == (b"IHDR", header)
    animation += chunk(b"fcTL", struct.pack(">IIIIIHHBB", sequence, width, height, 0, 0, durations[index], 1000, 0, 0))
    sequence += 1
    for kind, content in frame:
        if kind == b"IDAT":
            animation += chunk(b"IDAT" if index == 0 else b"fdAT", content if index == 0 else struct.pack(">I", sequence) + content)
            if index > 0:
                sequence += 1
animation += chunk(b"IEND", b"")
(HERE / "kit-sweep.png").write_bytes(animation)

commands = []
for path in sorted(HERE.glob("*/command.json")):
    entry = json.loads(path.read_text(encoding="utf-8-sig"))
    log = path.parent / "console.log"
    data = log.read_bytes()
    text = data.decode("utf-16" if data.startswith(b"\xff\xfe") else "utf-8-sig", errors="replace")
    entry["directory"] = str(path.parent.relative_to(HERE)).replace("\\", "/")
    entry["summaries"] = re.findall(r"(?:GARAGE_KIT_TRANSITION|GARAGE_PAINT_TRANSITION|GARAGE_PREVIEW_STABILITY|CUSTOMISATION_CAROUSEL|SCRIPT_PARSE):[^\r\n]*", text)
    commands.append(entry)

report = {
    "requirements": {
        "GKT01": "Changed Garage kit fittings replace the previous fittings through a local bottom-to-top assembly sweep, including previews and direct equipped changes.",
        "GKT02": "0.58-second eased opaque sweep with a narrow highlight preserves finishes, unaffected geometry, camera, condition and reflections.",
        "GKT03": "Preview, equipped comparison, account, navigation, persistence and purchase boundaries remain authoritative; only one outgoing fittings snapshot is retained.",
        "R01": "All 43 kit choices, native endpoints, lifecycle, retained configurator, camera stability and accepted paint animation checks.",
        "Q01": "Native motion evidence, exact commands, scoped review patch and explicit device limits.",
    },
    "runtime_scope": RUNTIME,
    "sources": [{"path": name, "sha256": sha(REPO / name), "before_sha256": sha(HERE / "before" / name) if (HERE / "before" / name).exists() else None} for name in SCOPE],
    "commands": commands,
    "native_results": {mode: json.loads((HERE / f"test_garage_kit_transition-{mode}" / "report.json").read_text()) for mode in ["headless", "gl_compatibility", "mobile"]},
    "initial_review": {
        "native": "initial/broad-highlight-native: 2457 checks, zero failures. Visual review found the fixed-width hood highlight too broad; final code narrows it relative to the fitting height and lowers emission. All original assertions remain.",
    },
    "task_start_hashes": json.loads((HERE / "task-start-hashes.json").read_text(encoding="utf-8-sig")),
    "artifacts": {"animation": "kit-sweep.png", "native_frames": str(native.relative_to(HERE)), "review_patch": "task-only.patch", "reverse_patch_check_exit": reverse.returncode},
    "limits": ["Desktop Compatibility and desktop Mobile/Vulkan only; no physical-device attachment check or test.", "No APK/AAB build, real authentication or purchase, live service mutation, deployment, staging, commit, merge or owner-process restart.", "Owner motion/touch/performance acceptance and reload remain.", "Rapid selections finish the previous visual target before starting the latest sweep; no unbounded history or delayed appearance commits."],
}
(HERE / "report.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
(HERE / "review.html").write_text("""<!doctype html><meta charset="utf-8"><title>Garage kit sweep</title>
<style>body{font:18px system-ui;background:#111b22;color:#e3e9ed;margin:32px auto;max-width:1280px}img{width:100%;border-radius:12px}a{color:#ffda55}p{max-width:900px}</style>
<h1>Garage kit sweep</h1><p>Actual Garage frames. A narrow light sweep assembles the changed fitting from bottom to top over 0.58 seconds. Equipped comparison remains immediate.</p>
<img src="kit-sweep.png" alt="GT wing assembles in the actual Garage">
<p><a href="test_garage_kit_transition-gl_compatibility/hood-halfway.png">Hood halfway</a> · <a href="test_garage_kit_transition-gl_compatibility/rims-halfway.png">Rims halfway</a> · <a href="test_garage_kit_transition-gl_compatibility/body-halfway.png">Body kit halfway</a> · <a href="report.json">Commands and checks</a></p>
<p>Compatibility and desktop Mobile/Vulkan checks; physical-device testing was not performed. The replay uses captured progress frames with the transition's sine easing timing.</p>""", encoding="utf-8")
print(json.dumps({"reverse_patch_check": reverse.returncode, "commands": len(commands), "animation_bytes": (HERE / "kit-sweep.png").stat().st_size}))
