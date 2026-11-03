"""Build native evidence and verify the task-only patch without touching the index."""
from pathlib import Path
import base64
import difflib
import hashlib
import json
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[3]
HERE = Path(__file__).resolve().parent
paths = [
    "DEVELOPMENT_STATUS.md",
    "game/track/native_track.gd",
    "game/tests/test_offtrack_roughness.gd",
    "docs/OFFTRACK_ROUGHNESS_2026_11_03.md",
]


def main():
    frames = ["data:image/png;base64," + base64.b64encode(path.read_bytes()).decode("ascii")
              for path in sorted((HERE / "frames-gl_compatibility").glob("*.png"))]
    viewer = '''<!doctype html><meta charset="utf-8"><title>Off-track suspension comparison</title>
<style>body{background:#172018;color:#eee;font:16px system-ui;max-width:1000px;margin:24px auto;padding:12px}img{width:100%}button,input{vertical-align:middle}input{width:65%}</style>
<p>Native Compact suspension: before (left) / more uneven (right). Identical 12 m/s distance samples.</p>
<img id="frame" alt="Native suspension comparison"><p><button id="play">Pause</button> <input id="time" type="range" min="0" max="60" value="0"> <span id="stamp"></span></p>
<p>Staged comparison with the actual car models and suspension springs. The shipping camera and terrain mesh are unchanged.</p>
<script>const frames=FRAMES;let i=0,running=true;const image=document.querySelector('#frame'),slider=document.querySelector('#time'),stamp=document.querySelector('#stamp'),play=document.querySelector('#play');function show(){image.src=frames[i];slider.value=i;stamp.textContent=(i/12).toFixed(2)+' s';}slider.oninput=()=>{i=+slider.value;show()};play.onclick=()=>{running=!running;play.textContent=running?'Pause':'Play'};show();setInterval(()=>{if(running){i=(i+1)%frames.length;show()}},1000/12);</script>
'''.replace("FRAMES", json.dumps(frames))
    (HERE / "comparison.html").write_text(viewer, encoding="utf-8")
    patch = []
    baselines = {}
    finals = {}
    for name in paths:
        original = HERE / "before" / name
        baselines[name] = original.read_bytes() if original.exists() else None
        finals[name] = (ROOT / name).read_bytes()
        before = baselines[name].decode("utf-8").splitlines(keepends=True) if baselines[name] is not None else []
        after = finals[name].decode("utf-8").splitlines(keepends=True)
        # Patch lines use LF regardless of Windows working-tree line endings.
        before = [line.rstrip("\r\n") + "\n" for line in before]
        after = [line.rstrip("\r\n") + "\n" for line in after]
        finals[name] = "".join(after).encode("utf-8")
        if baselines[name] is not None:
            baselines[name] = "".join(before).encode("utf-8")
        patch.extend(difflib.unified_diff(before, after, fromfile="a/" + name if original.exists() else "/dev/null", tofile="b/" + name))
    patch_path = HERE / "task.patch"
    patch_path.write_bytes("".join(patch).encode("utf-8"))
    with tempfile.TemporaryDirectory(prefix="offtrack-roughness-checkpoint-") as directory:
        work = Path(directory)
        for name, data in baselines.items():
            if data is not None:
                (work / name).parent.mkdir(parents=True, exist_ok=True)
                (work / name).write_bytes(data)
        for args in [("--check",), ()]:
            subprocess.run(["git", "-c", "core.autocrlf=false", "apply", *args, str(patch_path)], cwd=work, check=True)
        for name, data in finals.items():
            assert (work / name).read_bytes() == data, name
        for args in [("--reverse", "--check"), ("--reverse",)]:
            subprocess.run(["git", "-c", "core.autocrlf=false", "apply", *args, str(patch_path)], cwd=work, check=True)
        for name, data in baselines.items():
            if data is None:
                assert not (work / name).exists(), name
            else:
                assert (work / name).read_bytes() == data, name
    report = {
        "requirement_ids": ["OTR01", "OTR02", "R01", "Q01"],
        "source_sha256": {name: hashlib.sha256((ROOT / name).read_bytes()).hexdigest() for name in paths},
        "checkpoint": {"forward": True, "reverse": True, "exact_content": True, "main_index_written": False},
        "native_frames": {"gl_compatibility": len(frames), "mobile": len(list((HERE / "frames-mobile").glob("*.png")))},
        "phone_test": False,
    }
    (HERE / "report.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(report, indent=2))


if __name__ == "__main__":
    main()
