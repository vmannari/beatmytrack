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
import re
import subprocess
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
ENGINE = ROOT / "build/biome-shader-profiles-20261106/godot-4.7.2-stable"
EVIDENCE = ROOT / "docs/evidence/biome-shader-profiles-2026-11-06"
SCONS = ROOT / ".tools/scons-music/scripts/scons.py"
MODULE_FILES = ("config.py", "SCsub", "register_types.h", "register_types.cpp",
                "biome_shader_profiles.h", "biome_shader_profiles.cpp", "draw_calls.h")
SWAPPY_LIBRARY_SHA256 = {
    "arm64-v8a": "4e7a74ea57678b30f518537ef2e06bb144a7d15fe93774af18d4ed56c519e68d",
    "armeabi-v7a": "d4c29b80da05b61095e332cdd734ecb71083b122a379a8f6d6b2ec5358d5426d",
    "x86": "a75b413c2c84fa421808ddffc11a00decef76d76123c192f8784ba37fe9fc9b5",
    "x86_64": "36256209a6628c63deeb52a2d0050538f74f70f20ffb173fa9cf3a462b2d706a",
}


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
        match = re.search(r'^export/android/android_sdk_path\s*=\s*"([^"]+)"', settings.read_text(encoding="utf-8"), re.MULTILINE)
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


def native_build_inputs(engine: Path) -> dict:
    # Preserve the qualified runtime/profile fingerprint; build configuration
    # is an additional identity, including Python/SCsub inputs it omits.
    names = [f"modules/biome_shader_profiles/{name}" for name in MODULE_FILES]
    names += ["SConstruct", "methods.py", "platform_methods.py",
              "platform/android/detect.py", "platform/android/SCsub"]
    return {name: hashlib.sha256((engine / name).read_bytes()).hexdigest() for name in names}


def preflight(engine: Path, sdk: Path, arch: str, target: str, jobs: int) -> dict:
    # SCons changes directory to the engine tree before interpreting SDK paths.
    engine, sdk = engine.resolve(), sdk.resolve()
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
    if not properties.is_file() or not re.search(r"^Pkg.Revision\s*=\s*" + re.escape(ndk_version) + r"\s*$", properties.read_text(), re.MULTILINE):
        missing.append(f"Pinned Android NDK {ndk_version} at {ndk}")
    if not compiler.is_file():
        missing.append(f"NDK compiler: {compiler}")
    if not SCONS.is_file():
        missing.append(f"SCons: {SCONS}")
    # Pinned engine installer selects godot-swappy from-source-2025-01-31.
    # All four archives are required by detect_swappy(), even for one ABI.
    swappy = {}
    for abi, expected in SWAPPY_LIBRARY_SHA256.items():
        library = engine / "thirdparty/swappy-frame-pacing" / abi / "libswappy_static.a"
        actual = hashlib.sha256(library.read_bytes()).hexdigest() if library.is_file() else ""
        swappy[abi] = {"path": str(library), "sha256": actual, "sha256_expected": expected}
        if actual != expected:
            missing.append(f"Pinned Swappy from-source-2025-01-31 library: {library}")
    command = [sys.executable, str(SCONS), "-C", str(engine), "platform=android",
               f"target={target}", f"arch={arch}", f"ANDROID_HOME={sdk}", f"ndk_platform=android-{api}",
               "generate_android_binaries=no", "opengl3=yes", "vulkan=yes", "swappy=yes",
               "profiler=none", "debug_symbols=no",
               "optimize=speed", "lto=none", f"-j{jobs}"]
    return {"ready": not missing, "missing": missing, "engine": str(engine), "sdk": str(sdk),
            "required_ndk": ndk_version, "minimum_api": api, "source_fingerprint": fingerprint,
            "native_build_inputs": native_build_inputs(engine), "input_snapshot_phase": "before compilation",
            "build_helper_sha256": hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
            "environment_overrides": {"ANDROID_HOME": str(sdk), "ANDROID_SDK_ROOT": str(sdk),
                                      "GIT_OPTIONAL_LOCKS": "0"},
            "swappy": swappy, "external_profiler": "none",
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
    if args.receipt:
        args.receipt = args.receipt.resolve()
        owned_roots = [(ROOT / "build").resolve(), (ROOT / "docs/evidence").resolve()]
        if (not any(args.receipt != root and args.receipt.is_relative_to(root) for root in owned_roots)
                or args.receipt.exists()):
            parser.error("Use a new receipt file under the repository's owned build/evidence directories")
    try:
        result = preflight(args.engine, args.sdk, args.arch, args.target, args.jobs)
        code = 0 if result["ready"] else 2
        if args.build and result["ready"]:
            started = time.monotonic()
            # Passing an already validated SDK avoids SCons' automatic NDK install.
            # Platform discovery calls detect.can_build() before command-line
            # Variables are applied, so it also needs the SDK in the child env.
            build_environment = os.environ.copy()
            build_environment.update(result["environment_overrides"])
            completed = subprocess.run(result["command"], cwd=ROOT, env=build_environment, check=False)
            code = completed.returncode
            result.update(exit_code=code, elapsed_seconds=time.monotonic() - started)
            if native_build_inputs(Path(result["engine"])) != result["native_build_inputs"]:
                raise ValueError("Native build inputs changed during compilation; build identity is not established")
            for dependency in result["swappy"].values():
                if hashlib.sha256(Path(dependency["path"]).read_bytes()).hexdigest() != dependency["sha256"]:
                    raise ValueError("Swappy dependency changed during compilation")
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
        with args.receipt.open("x", encoding="utf-8") as receipt:
            receipt.write(json.dumps(result, indent=2) + "\n")
    print(json.dumps(result, indent=2))
    return code


if __name__ == "__main__":
    sys.exit(main())
