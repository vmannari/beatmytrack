"""Build and round-trip a task-only patch without writing the workspace index."""
import hashlib
import json
import subprocess
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
OUT = Path(__file__).resolve().parent
MARKER = b"<!-- DAILY-STANDINGS-LATENCY-20261104 -->"
END = b"<!-- /DAILY-STANDINGS-LATENCY-20261104 -->"
SHARED = ["AGENTS.md", "DEVELOPMENT_STATUS.md", "docs/PHASE_0_PLAN.md"]


def digest(data):
    return hashlib.sha256(data).hexdigest()


def without_summary(data):
    start = data.index(MARKER)
    finish = data.index(END, start) + len(END)
    while data[finish:finish+1] in (b"\r", b"\n"):
        finish += 1
    return data[:start] + data[finish:]


def main():
    files = [ROOT / name for name in SHARED]
    files += [ROOT / "scripts/profile_daily_standings.py", ROOT / "game/tests/profile_daily_standings_latency.gd",
              ROOT / "docs/DAILY_STANDINGS_LATENCY_2026_11_04.md"]
    files += [path for path in OUT.rglob("*") if path.is_file() and path.name not in
              ("task.patch", "checkpoint-result.json") and "__pycache__" not in path.parts]
    after = {path.relative_to(ROOT).as_posix(): path.read_bytes() for path in files}
    before = {name: without_summary(after[name]) for name in SHARED}
    index = ROOT / ".git/index"
    index_before = digest(index.read_bytes())
    with tempfile.TemporaryDirectory(prefix="daily-latency-checkpoint-", dir=ROOT / "build") as folder:
        work = Path(folder).resolve()
        assert work.is_relative_to((ROOT / "build").resolve())

        def git(*args):
            return subprocess.run(["git", "-C", str(work), *args], capture_output=True, check=True).stdout

        def write(mapping):
            for name, data in mapping.items():
                path = work / name
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_bytes(data)

        git("init", "--quiet")
        git("config", "core.autocrlf", "false")
        write(before)
        git("add", "--", *before)
        write(after)
        git("add", "--intent-to-add", "--", *[name for name in after if name not in before])
        patch = git("diff", "--binary", "--no-ext-diff")
        (OUT / "task.patch").write_bytes(patch)
        git("apply", "--reverse", "--check", str(OUT / "task.patch"))
        git("apply", "--reverse", str(OUT / "task.patch"))
        assert all((work / name).read_bytes() == data for name, data in before.items())
        assert all(not (work / name).exists() for name in after if name not in before)
        git("apply", "--check", str(OUT / "task.patch"))
        git("apply", str(OUT / "task.patch"))
        assert all((work / name).read_bytes() == data for name, data in after.items())
    assert digest(index.read_bytes()) == index_before
    result = {"files": len(after), "reverse_exact": True, "forward_exact": True,
              "main_index_unchanged": True, "sha256": {name: digest(data) for name, data in after.items()}}
    (OUT / "checkpoint-result.json").write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({key: value for key, value in result.items() if key != "sha256"}))


if __name__ == "__main__":
    main()
