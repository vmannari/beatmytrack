"""Build bounded local evidence and an isolated, Git-checked task checkpoint."""
from __future__ import annotations

import difflib
import hashlib
import html
import json
import os
import re
import shutil
import subprocess
import uuid
from pathlib import Path

EVIDENCE = Path(__file__).resolve().parent
ROOT = EVIDENCE.parents[2]
SHARED = [
    "game/core/app.gd", "game/core/game.gd", "game/ui/settings_page.gd",
    "game/ui/menu_page_swipe.gd", "game/ui/track_carousel.gd",
]
ADDED = [
    "game/tutorial/tutorial_controller.gd", "game/tutorial/tutorial_overlay.gd",
    "game/tutorial/tutorial_progress.gd", "game/tests/test_first_play_tutorial.gd",
    "game/tests/test_tutorial_swipe_control.gd",
]
DOCS = ["AGENTS.md", "DEVELOPMENT_STATUS.md", "docs/PHASE_0_PLAN.md", "docs/README.md"]
FILES = SHARED + ADDED + [p+".uid" for p in ADDED] + DOCS + [
    "docs/FIRST_PLAY_TUTORIAL_2026_10_24.md",
    "docs/evidence/first-play-tutorial-2026-10-24/finalize.py",
]


def sha(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def normalized(data: bytes) -> str:
    return data.decode("utf-8").replace("\r\n", "\n")


def update_trackers(focused: dict) -> None:
    counts = "/".join(str(focused[m]["checks"]) for m in ("headless","gl_compatibility","mobile"))
    summary = (
        f"2026-10-24 FPT01-FPT05/R01/G01/Q01: Skippable first-play tutorial follows account/Guest setup, "
        "with actual parking-hall acceleration/steering/braking, saved control-aware prompts, an offline five-lap "
        "Starter Circuit race, PB guidance, contextual feature tips and Settings Help replay. Existing saves keep "
        "normal startup. Atomic installation-local progress, account/invitation fences, native card/carousel input "
        "priority, safe-area/control/banner avoidance and short-result scrolling retain canonical driving and "
        f"online/resource authority. Focused{counts} headless/Compatibility/desktopMobile, records54/controls407/"
        "App141/rewind61/ads63/results515/parser1119 and pinned import pass. Two broader legacy UI suites remain "
        "failing; task-start controls also fail (Garage fit labels differ). Initial corrections and every failing "
        "assertion remain recorded. Native gallery, commands, source hashes and isolated Git-checked task checkpoint: "
        "docs/FIRST_PLAY_TUTORIAL_2026_10_24.md and docs/evidence/first-play-tutorial-2026-10-24/report.json. "
        "Client reload and owner/device pacing, touch and cost acceptance remain. No attachment/device test, APK, "
        "live mutation, purchase, social send, deployment or owner-process restart by this task; concurrent work preserved."
    )
    for relative in DOCS:
        path = ROOT/relative
        raw = path.read_bytes()
        if relative == "docs/README.md":
            body = b"".join(line for line in raw.splitlines(keepends=True)
                            if not line.startswith(b"| First-play tutorial |"))
            lines = body.splitlines(keepends=True)
            index = next(i for i,line in enumerate(lines) if line.startswith(b"| Topic |"))+2
            lines.insert(index,b"| First-play tutorial | [Driving lesson and help](FIRST_PLAY_TUTORIAL_2026_10_24.md) | [Tutorial controller](../game/tutorial/tutorial_controller.gd), [Settings Help](../game/ui/settings_page.gd) |\n")
            updated = b"".join(lines)
        else:
            start = b"<!-- FIRST-PLAY-TUTORIAL-20261024 -->"
            end = b"<!-- /FIRST-PLAY-TUTORIAL-20261024 -->"
            body = raw
            if start in body:
                a = body.index(start)
                b = body.index(end,a)+len(end)
                body = body[:a]+body[b:].lstrip(b"\r\n")
            heading = "## First-play driving tutorial override (2026-10-24)\n" if relative == "AGENTS.md" else ""
            prefix = start.decode()+"\n"+heading+summary+"\n"+end.decode()+"\n\n"
            updated = prefix.encode("utf-8")+body
        before = EVIDENCE/"checkpoint-base"/relative
        before.parent.mkdir(parents=True,exist_ok=True)
        before.write_bytes(body)
        # Refuse to overwrite a concurrent editor's intervening write.
        assert path.read_bytes() == raw, "Concurrent documentation change: "+relative
        temporary = path.with_name(path.name+".tutorial-update")
        temporary.write_bytes(updated)
        os.replace(temporary,path)
    guide = ROOT/"docs/FIRST_PLAY_TUTORIAL_2026_10_24.md"
    text = guide.read_text(encoding="utf-8")
    for label,mode in (("headless","headless"),("native Compatibility","gl_compatibility"),("desktop Mobile/Vulkan","mobile")):
        pattern = r"(\| Focused tutorial, "+re.escape(label)+r" \| )\d+ checks"
        text = re.sub(pattern,lambda match:match[1]+str(focused[mode]["checks"])+" checks",text)
    guide.write_text(text,encoding="utf-8",newline="\n")


def main() -> None:
    focused = {}
    for mode in ("headless", "gl_compatibility", "mobile"):
        path = EVIDENCE / ("visible-"+mode) / "test-report.json"
        focused[mode] = json.loads(path.read_text(encoding="utf-8"))
        assert focused[mode]["failures"] == 0, path

    metadata = json.loads((EVIDENCE/"verification.json").read_text(encoding="utf-8"))
    update_trackers(focused)
    logs = []
    selected = set(metadata["log_paths"])
    for path in (ROOT/"build/logs").glob("TestScript-*/test-script.log"):
        text = path.read_text(encoding="utf-8", errors="replace")
        if "TUTORIAL:" in text or "First-play tutorial:" in text:
            selected.add(path.relative_to(ROOT).as_posix())
    for relative in sorted(selected):
        source = ROOT / relative
        assert source.is_file(), source
        target = EVIDENCE / "logs" / source.parent.name / source.name
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(source, target)
        logs.append({"original":relative,"retained":target.relative_to(EVIDENCE).as_posix(),
                     "sha256":sha(target.read_bytes())})

    # No main-worktree index, commit, stash, deletion or reset enters this check.
    check_root = ROOT / ("build/tutorial-checkpoint-"+uuid.uuid4().hex[:8])
    check_root.mkdir(parents=True, exist_ok=True)
    patch_parts = []
    manifest = []
    for relative in FILES:
        current = ROOT / relative
        after_raw = current.read_bytes()
        after = normalized(after_raw)
        baseline = EVIDENCE / ("checkpoint-base" if relative in DOCS else "before") / relative
        before_raw = baseline.read_bytes() if baseline.is_file() else b""
        before = normalized(before_raw)
        target = check_root / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        if baseline.is_file():
            target.write_bytes(before.encode("utf-8"))
        else:
            assert not target.exists(), "Use a fresh checkpoint directory: "+str(target)
        if before != after:
            patch_parts.append(f"diff --git a/{relative} b/{relative}\n")
            if not baseline.is_file(): patch_parts.append("new file mode 100644\n")
            patch_parts.extend(difflib.unified_diff(
                before.splitlines(keepends=True), after.splitlines(keepends=True),
                fromfile="a/"+relative if baseline.is_file() else "/dev/null",
                tofile="b/"+relative,
            ))
        manifest.append({"path":relative,"sha256":sha(after_raw),
                         "lf_sha256":sha(after.encode("utf-8")),
                         "before_sha256":sha(before_raw) if baseline.is_file() else None})
    patch = EVIDENCE/"task-only.patch"
    patch.write_text("".join(patch_parts),encoding="utf-8",newline="\n")
    receipts = []
    assert check_root.resolve().is_relative_to((ROOT/"build").resolve())
    for arguments in (["git","init","--quiet"], ["git","config","core.autocrlf","false"],
                      ["git","apply","--check",str(patch)], ["git","apply",str(patch)]):
        result = subprocess.run(arguments,cwd=check_root,capture_output=True,text=True,check=False)
        receipts.append({"argv":arguments,"cwd":str(check_root),"exit_code":result.returncode,
                         "stdout":result.stdout,"stderr":result.stderr})
        assert result.returncode == 0, receipts[-1]
    for item in manifest:
        assert sha((check_root/item["path"]).read_bytes()) == item["lf_sha256"], item["path"]

    report = {
        "task":"First-play tutorial", "date":"2026-10-24",
        "requirements":["FPT01","FPT02","FPT03","FPT04","FPT05","R01","G01","Q01"],
        "engine":(ROOT/"godot-version.txt").read_text().strip(),
        "focused":focused, "verification":metadata, "logs":logs, "files":manifest,
        "checkpoint":{"patch":"task-only.patch","sha256":sha(patch.read_bytes()),
                      "normalization":"LF, like Git text objects","receipts":receipts,
                      "reconstructed_file_count":len(manifest),"all_reconstructed_hashes_match":True},
        "limits":["Client reload and owner acceptance remain.",
                  "No phone/tablet attachment check or physical-device test was performed.",
                  "Desktop checks do not establish Android FPS, thermal cost or touch feel.",
                  "No owner-process restart, APK build/install, purchase, social send, live mutation or deployment by this task."],
    }
    (EVIDENCE/"report.json").write_text(json.dumps(report,indent=2)+"\n",encoding="utf-8")
    shots = ["welcome-960x540","garage-first-entry-tip","touch-buttons","touch-horizontal",
             "touch-joystick","hall-steer","hall-brake","hall-practise-more",
             "first-race-driving","first-race-results","results-footer-960x540",
             "settings-help","rewind-first-opening","help-creator"]
    figures = []
    for mode in ("gl_compatibility","mobile"):
        figures.append("<h2>"+html.escape(mode)+"</h2>")
        for shot in shots:
            src = f"visible-{mode}/{shot}.png"
            if (EVIDENCE/src).is_file():
                figures.append(f'<figure><a href="{src}"><img loading="lazy" src="{src}" alt="{html.escape(shot)}"></a><figcaption>{html.escape(shot)}</figcaption></figure>')
    (EVIDENCE/"report.html").write_text(
        '<!doctype html><html lang="en"><meta charset="utf-8"><title>First-play tutorial review</title>'
        '<style>body{margin:24px;background:#101c23;color:#edf1f3;font:16px system-ui}a{color:#ffd15c}figure{display:inline-block;width:min(100%,620px);margin:12px}img{width:100%;border:1px solid #52616b}figcaption{padding:8px}h2{clear:both}</style>'
        f'<h1>First-play tutorial</h1><p>{focused["headless"]["checks"]} headless checks; {focused["mobile"]["checks"]} per native renderer. All pass. '
        'See <a href="report.json">report.json</a> for commands, retained failures, limits and the checked checkpoint.</p>'
        +"\n".join(figures)+"</html>\n",encoding="utf-8")
    print(json.dumps({"focused":{k:v["checks"] for k,v in focused.items()},
                      "retained_logs":len(logs),"checkpoint_files":len(manifest),"git_apply":"pass"}))


if __name__ == "__main__":
    main()
