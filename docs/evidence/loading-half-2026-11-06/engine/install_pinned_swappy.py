"""Install only four checked Swappy libraries into the task-owned engine tree."""
import ast
import hashlib
import json
from pathlib import Path
from zipfile import ZipFile

ROOT = Path(__file__).resolve().parents[4]
ENGINE = ROOT / "build/biome-shader-profiles-20261106/godot-4.7.2-stable"
ARCHIVE = ROOT / "build/loading-half-20261106/android-dependencies/godot-swappy-from-source-2025-01-31.zip"
TAG = "from-source-2025-01-31"
SHA256 = "2dd05484de29a3040106658d6f95915778fd71abc3261130eada6090ed1c153d"
ARCHES = ("arm64-v8a", "armeabi-v7a", "x86", "x86_64")


def main():
    script = ENGINE / "misc/scripts/install_swappy_android.py"
    tree = ast.parse(script.read_text(encoding="utf-8"))
    tag = next(ast.literal_eval(node.value) for node in tree.body if isinstance(node, ast.Assign)
               and any(isinstance(target, ast.Name) and target.id == "swappy_tag" for target in node.targets))
    if tag != TAG or hashlib.sha256(ARCHIVE.read_bytes()).hexdigest() != SHA256:
        raise ValueError("Swappy archive does not match the pinned engine dependency")
    installed = []
    with ZipFile(ARCHIVE) as archive:
        if archive.testzip() is not None:
            raise ValueError("Swappy archive CRC failure")
        if len(archive.namelist()) != len(set(archive.namelist())):
            raise ValueError("Swappy archive contains duplicate entries")
        for arch in ARCHES:
            member = f"{arch}/libswappy_static.a"
            content = archive.read(member)
            if not content.startswith(b"!<arch>\n"):
                raise ValueError(f"Expected static library: {member}")
            destination = (ENGINE / "thirdparty/swappy-frame-pacing" / member).resolve()
            if not destination.is_relative_to(ENGINE.resolve()):
                raise ValueError("Dependency output escapes owned engine")
            if destination.exists() and destination.read_bytes() != content:
                raise ValueError(f"Existing different dependency must be preserved: {destination}")
            destination.parent.mkdir(parents=True, exist_ok=True)
            if not destination.exists():
                with destination.open("xb") as output:
                    output.write(content)
            installed.append({"path": str(destination), "bytes": len(content),
                              "sha256": hashlib.sha256(content).hexdigest()})
        receipt = {"tag": TAG, "url": f"https://github.com/godotengine/godot-swappy/releases/download/{TAG}/godot-swappy.zip",
                   "archive": str(ARCHIVE), "archive_sha256": SHA256, "crc_checked_entries": len(archive.infolist()),
                   "pinned_installer_sha256": hashlib.sha256(script.read_bytes()).hexdigest(),
                   "version": archive.read("VERSION").decode(), "libraries": installed,
                   "scope": "Task-owned native engine dependency only; no SDK/template/device writes"}
    receipt_path = Path(__file__).with_name("swappy-install.json")
    with receipt_path.open("x", encoding="utf-8") as output:
        output.write(json.dumps(receipt, indent=2) + "\n")
    print(json.dumps(receipt, indent=2))


if __name__ == "__main__":
    main()
