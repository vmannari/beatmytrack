"""Preflight or build isolated Android engine libraries, without exporting a game.

The default only validates and prints commands. --build runs SCons after all
checks pass. No SDK/NDK downloads, Gradle packaging, template installation,
signing, profile promotion or device access are performed.
"""
import argparse
import ast
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[2]
ENGINE = ROOT / "build/biome-shader-profiles-20261106/godot-4.7.2-stable"
EVIDENCE = ROOT / "docs/evidence/biome-shader-profiles-2026-11-06"
SCONS = ROOT / ".tools/scons-music/scripts/scons.py"
MODULE_FILES = ("config.py", "SCsub", "register_types.h", "register_types.cpp",
                "biome_shader_profiles.h", "biome_shader_profiles.cpp", "draw_calls.h")


def literal_return(path: Path, function: str):
    tree = ast.parse(path.read_text(encoding="utf-8"))
    found = next(node for node in tree.body if isinstance(node, ast.FunctionDef) and node.name == function)
    return ast.literal_eval(next(node.value for node in found.body if isinstance(node, ast.Return)))


def configured_sdk() -> Path:
    value = os.environ.get("ANDROID_HOME") or os.environ.get("ANDROID_SDK_ROOT")
    if value:
        return Path(value)
    settings = Path(os.environ.get("APPDATA", str(Path.home() / "AppData/Roaming"))) / "Godot/editor_settings-4.7.tres"
    if settings.is_file():
        match = re.search(r'^export/android/android_sdk_path\s*=\s*"([^"]+)"', settings.read_text(encoding="utf-8"), re.M)
        if match:
            return Path(match[1].replace("\\\\", "\\"))
    return Path.home() / "AppData/Local/Android/Sdk"


def verify_engine(engine: Path, evidence: Path = EVIDENCE) -> str:
    # The prepared tree, original source receipt and changed engine files remain
    # in the previous task's owned directory; none is rewritten by this tool.
    values = {node.targets[0].id: ast.literal_eval(node.value)
              for node in ast.parse((engine / "version.py").read_text()).body
              if isinstance(node, ast.Assign) and isinstance(node.targets[0], ast.Name)}
    version = f'{values["major"]}.{values["minor"]}.{values["patch"]}.{values["status"]}'
    pinned = (ROOT / "godot-version.txt").read_text().strip().split(".official.")[0]
    if version != pinned:
        raise ValueError(f"Engine source version {version} differs from pinned {pinned}")
    for row in json.loads((evidence / "engine-patch.json").read_text()):
        current = hashlib.sha256((engine / row["path"]).read_text().encode()).hexdigest()
        if current != row["after"]:
            raise ValueError(f'Prepared engine source changed: {row["path"]}')
    module = engine / "modules/biome_shader_profiles"
    for name in MODULE_FILES:
        if (module / name).read_bytes() != (Path(__file__).parent / name).read_bytes():
            raise ValueError(f"Prepared shader module is stale: {name}; prepare and requalify it first")
    fingerprint = hashlib.sha256((evidence / "engine.patch").read_text().encode())
    for path in sorted(Path(__file__).parent.iterdir()):
        if path.suffix in (".cpp", ".h"):
            fingerprint.update(path.name.encode() + path.read_bytes())
    expected = fingerprint.hexdigest()
    if (module / "build_fingerprint.gen.h").read_text().strip() != f'#define BMT_SHADER_PROFILE_SOURCE "{expected}"':
        raise ValueError("Prepared shader module fingerprint does not match current source")
    return expected


def preflight(engine: Path, sdk: Path, arch: str, target: str, jobs: int) -> dict:
    if not engine.resolve().is_relative_to((ROOT / "build").resolve()):
        raise ValueError("Engine output must stay in the repository's owned build directory")
    fingerprint = verify_engine(engine)
    detect = engine / "platform/android/detect.py"
    ndk_version = str(literal_return(detect, "get_ndk_version"))
    api = int(literal_return(detect, "get_min_target_api"))
    ndk = sdk / "ndk" / ndk_version
    host = "windows-x86_64" if os.name == "nt" else "darwin-x86_64" if sys.platform == "darwin" else "linux-x86_64"
    compiler = ndk / "toolchains/llvm/prebuilt" / host / "bin" / ("clang++.exe" if os.name == "nt" else "clang++")
    missing = []
    properties = ndk / "source.properties"
    if not properties.is_file() or not re.search(r"^Pkg.Revision\s*=\s*" + re.escape(ndk_version) + r"\s*$", properties.read_text(), re.M):
        missing.append(f"Pinned Android NDK {ndk_version} at {ndk}")
    if not compiler.is_file():
        missing.append(f"NDK compiler: {compiler}")
    if not SCONS.is_file():
        missing.append(f"SCons: {SCONS}")
    command = [sys.executable, str(SCONS), "-C", str(engine), "platform=android",
               f"target={target}", f"arch={arch}", f"ANDROID_HOME={sdk}", f"ndk_platform=android-{api}",
               "generate_android_binaries=no", "opengl3=yes", "vulkan=yes", "debug_symbols=no",
               "optimize=speed", "lto=none", f"-j{jobs}"]
    return {"ready": not missing, "missing": missing, "engine": str(engine), "sdk": str(sdk),
            "required_ndk": ndk_version, "minimum_api": api, "source_fingerprint": fingerprint,
            "command": command, "scope": "native engine library only; no Gradle/game export",
            "android_profile_qualified": False}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--engine", type=Path, default=ENGINE)
    parser.add_argument("--sdk", type=Path, default=configured_sdk())
    parser.add_argument("--arch", choices=("arm64", "x86_64"), default="arm64")
    parser.add_argument("--target", choices=("template_debug", "template_release"), default="template_debug")
    parser.add_argument("--jobs", type=int, choices=range(1, 65), default=8)
    parser.add_argument("--build", action="store_true")
    parser.add_argument("--receipt", type=Path)
    args = parser.parse_args()
    try:
        result = preflight(args.engine, args.sdk, args.arch, args.target, args.jobs)
        code = 0 if result["ready"] else 2
        if args.build and result["ready"]:
            started = time.monotonic()
            # Passing an already validated SDK avoids SCons' automatic NDK install.
            completed = subprocess.run(result["command"], cwd=ROOT, check=False)
            code = completed.returncode
            result.update(exit_code=code, elapsed_seconds=time.monotonic() - started)
            variant = "debug" if args.target == "template_debug" else "release"
            abi = "arm64-v8a" if args.arch == "arm64" else "x86_64"
            outputs = args.engine / "platform/android/java/lib/libs" / variant / abi
            result["libraries"] = {str(path): hashlib.sha256(path.read_bytes()).hexdigest()
                                   for path in outputs.glob("*.so")}
            if code == 0 and not (outputs / "libgodot_android.so").is_file():
                raise ValueError("SCons completed without the expected Android engine library")
    except (OSError, ValueError, KeyError, StopIteration, SyntaxError) as error:
        result, code = {"ready": False, "error": str(error)}, 2
    if args.receipt:
        args.receipt.parent.mkdir(parents=True, exist_ok=True)
        args.receipt.write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(result, indent=2))
    return code


if __name__ == "__main__":
    sys.exit(main())
