"""Prepare an isolated ARM64 debug AAR/source ZIP; never export or install an APK.

Default: preflight (paths, receipt, source/build/dependency identity, ELF headers).
--package: verify the pinned source archive and built library hashes, then write
new task-owned archives and check every output entry's bytes and CRC. No Gradle,
SDK modification, signing, installed-template write, network or device access.
"""
import argparse
import hashlib
import importlib.util
import json
import stat
import struct
import sys
from copy import copy
from pathlib import Path, PurePosixPath
from zipfile import BadZipFile, ZipFile

ROOT = Path(__file__).resolve().parents[4]
EVIDENCE = Path(__file__).resolve().parent
OWNED = ROOT / "build/loading-half-20261106"
ENGINE = ROOT / "build/biome-shader-profiles-20261106/godot-4.7.2-stable"
OFFICIAL_SOURCE = ROOT / ".tools/admob/android_source.zip"
OFFICIAL_SHA256 = "a15416b528efb0a19a7d187e4d9f4e5336d0689144b111329fb4bd12c4447ad3"
AAR_MEMBER = "libs/debug/godot-lib.template_debug.aar"
LIBRARIES = ("libgodot_android.so", "libc++_shared.so")
ABI = "arm64-v8a"
NDK = "29.0.14206865"
CHUNK = 1024 * 1024


def digest_file(path):
    digest = hashlib.sha256()
    with path.open("rb") as source:
        while block := source.read(CHUNK):
            digest.update(block)
    return digest.hexdigest()


def owned_output(path, roots):
    resolved = path.resolve()
    if not any(resolved != root.resolve() and resolved.is_relative_to(root.resolve()) for root in roots):
        raise ValueError(f"Output must stay inside a task-owned directory: {path}")
    return resolved


def elf_header(path):
    with path.open("rb") as source:
        header = source.read(64)
    if (len(header) != 64 or header[:6] != b"\x7fELF\x02\x01"
            or struct.unpack_from("<HH", header, 16) != (3, 183)):
        raise ValueError(f"Expected a 64-bit little-endian AArch64 shared library: {path}")
    return {"class": "ELF64", "endianness": "little", "type": "ET_DYN", "machine": "AArch64"}


def engine_verifier():
    path = ROOT / "native/biome_shader_profiles/build_android.py"
    spec = importlib.util.spec_from_file_location("bmt_android_packaging_preflight", path)
    module = importlib.util.module_from_spec(spec)
    previous = sys.dont_write_bytecode
    try:
        sys.dont_write_bytecode = True
        spec.loader.exec_module(module)
    finally:
        sys.dont_write_bytecode = previous
    return module


def preflight(engine, source, build_receipt, destination):
    engine, source, build_receipt = engine.resolve(), source.resolve(), build_receipt.resolve()
    if not engine.is_relative_to((ROOT / "build").resolve()):
        raise ValueError("The engine must be in the repository's build directory")
    destination = owned_output(destination, [OWNED])
    if destination.exists():
        raise ValueError(f"Use a new output directory; existing artifacts are preserved: {destination}")
    verifier = engine_verifier()
    fingerprint = verifier.verify_engine(engine)
    library_dir = engine / "platform/android/java/lib/libs/debug" / ABI
    libraries = {name: library_dir / name for name in LIBRARIES}
    missing = [str(path) for path in [source, build_receipt, *libraries.values()] if not path.is_file()]
    result = {"ready": not missing, "missing": missing, "engine": str(engine),
              "source": str(source), "source_sha256_expected": OFFICIAL_SHA256,
              "source_hash_verified": False, "build_receipt": str(build_receipt),
              "source_fingerprint": fingerprint, "output_directory": str(destination),
              "libraries": {name: {"path": str(path), "elf": elf_header(path)}
                            for name, path in libraries.items() if path.is_file()},
              "scope": "ARM64 debug AAR and Android source ZIP only",
              "android_profile_qualified": False}
    if missing:
        return result
    receipt = json.loads(build_receipt.read_text(encoding="utf-8"))
    if not isinstance(receipt, dict):
        raise TypeError("Build receipt must be a JSON object")
    required = {"platform=android", "target=template_debug", "arch=arm64",
                "generate_android_binaries=no", "opengl3=yes", "vulkan=yes", "swappy=yes", "profiler=none",
                "ndk_platform=android-24", "debug_symbols=no", "optimize=speed", "lto=none",
                f"ANDROID_HOME={Path(receipt.get('sdk', '')).resolve()}"}
    command = receipt.get("command", [])
    command_valid = isinstance(command, list) and all(isinstance(value, str) for value in command)
    if command_valid:
        # SCons applies later assignments: a subset check would accept a
        # contradictory trailing arch=, swappy=, renderer= or SDK argument.
        command_valid = all([value for value in command if value.partition("=")[0] == flag.partition("=")[0]]
                            == [flag] for flag in required)
    if (receipt.get("exit_code") != 0 or receipt.get("ready") is not True
            or receipt.get("source_fingerprint") != fingerprint
            or receipt.get("required_ndk") != NDK
            or Path(receipt.get("engine", "")).resolve() != engine
            or not command_valid):
        raise ValueError("A successful matching ARM64 template_debug native build receipt is required")
    inputs = verifier.native_build_inputs(engine)
    if receipt.get("native_build_inputs") != inputs:
        raise ValueError("Native build inputs differ from the successful build receipt")
    result["native_build_inputs"] = inputs
    result["swappy"] = receipt.get("swappy", {})
    verify_swappy(verifier, engine, result["swappy"])
    for name in ("input_snapshot_phase", "input_snapshot_time_utc", "input_snapshot_limitation",
                 "build_helper_sha256", "build_helper_snapshot_sha256",
                 "original_build_receipt", "original_build_receipt_sha256"):
        if name in receipt:
            result[name] = receipt[name]
    hashes = {str(Path(path).resolve()): value for path, value in receipt.get("libraries", {}).items()}
    for name, path in libraries.items():
        expected = hashes.get(str(path.resolve()), "")
        if len(expected) != 64 or any(c not in "0123456789abcdef" for c in expected):
            raise ValueError(f"Build receipt has no valid hash for {name}")
        result["libraries"][name]["sha256_expected"] = expected
    sdk = Path(receipt.get("sdk", "")).resolve()
    runtime = sdk / "ndk" / NDK / "toolchains/llvm/prebuilt/windows-x86_64/sysroot/usr/lib/aarch64-linux-android/libc++_shared.so"
    if not runtime.is_file():
        result["ready"] = False
        result["missing"].append(str(runtime))
    result["ndk_runtime"] = str(runtime)
    result["build_receipt_sha256"] = digest_file(build_receipt)
    return result


def verify_swappy(verifier, engine, recorded):
    for abi, expected in verifier.SWAPPY_LIBRARY_SHA256.items():
        path = engine / "thirdparty/swappy-frame-pacing" / abi / "libswappy_static.a"
        row = recorded.get(abi, {})
        if (row.get("sha256") != expected or Path(row.get("path", "")).resolve() != path.resolve()
                or not path.is_file() or digest_file(path) != expected):
            raise ValueError(f"Pinned Swappy dependency differs from the build receipt: {abi}")


def verify_current_build_identity(result):
    verifier = engine_verifier()
    engine = Path(result["engine"])
    if (verifier.verify_engine(engine) != result["source_fingerprint"]
            or verifier.native_build_inputs(engine) != result["native_build_inputs"]):
        raise ValueError("Native build identity changed during packaging")
    verify_swappy(verifier, engine, result["swappy"])


def checked_members(archive):
    entries = archive.infolist()
    names = [entry.filename for entry in entries]
    if len(entries) > 4096 or len(names) != len(set(names)):
        raise ValueError("Archive contains duplicate/excessive entries")
    for entry in entries:
        path = PurePosixPath(entry.filename)
        if (not entry.filename or path.is_absolute() or ".." in path.parts or "\\" in entry.filename
                or ":" in entry.filename or entry.flag_bits & 1
                or stat.S_ISLNK(entry.external_attr >> 16) or entry.file_size > 512 * 1024 * 1024):
            raise ValueError(f"Unsupported archive member: {entry.filename}")
    return entries


def write_archive(source, destination, replacements, omitted):
    """Stream original member bytes, changing only explicitly named members."""
    hashes = {}
    with ZipFile(source) as original, ZipFile(destination, "w") as output:
        entries = checked_members(original)
        names = {entry.filename for entry in entries}
        if not set(replacements).issubset(names) or not omitted.issubset(names):
            raise ValueError("Archive replacement/omission does not match the original member set")
        if set(replacements) & omitted:
            raise ValueError("A member cannot be both replaced and omitted")
        output.comment = original.comment
        for entry in entries:
            name = entry.filename
            if name in omitted:
                continue
            incoming = replacements[name].open("rb") if name in replacements else original.open(entry)
            digest = hashlib.sha256()
            with incoming, output.open(copy(entry), "w", force_zip64=True) as outgoing:
                while block := incoming.read(CHUNK):
                    outgoing.write(block)
                    digest.update(block)
            hashes[name] = digest.hexdigest()
    # Reading every complete output member checks zipfile's CRC and also proves
    # exact Java/resource/source bytes against the streamed original members.
    verify_archive(destination, hashes)
    return hashes


def verify_archive(path, expected):
    with ZipFile(path) as archive:
        entries = checked_members(archive)
        if {entry.filename for entry in entries} != set(expected):
            raise ValueError("Output archive member inventory changed unexpectedly")
        for entry in entries:
            digest = hashlib.sha256()
            with archive.open(entry) as source:
                while block := source.read(CHUNK):
                    digest.update(block)
            if digest.hexdigest() != expected[entry.filename]:
                raise ValueError(f"Output member changed: {entry.filename}")


def package(result):
    if not result["ready"]:
        raise ValueError("Preflight must pass before packaging")
    verify_current_build_identity(result)
    source = Path(result["source"])
    if digest_file(source) != OFFICIAL_SHA256:
        raise ValueError("Official android_source.zip differs from the pinned 4.7.2 archive")
    build_receipt = Path(result["build_receipt"])
    if digest_file(build_receipt) != result["build_receipt_sha256"]:
        raise ValueError("Build receipt changed after preflight")
    libraries = {name: Path(row["path"]) for name, row in result["libraries"].items()}
    for name, path in libraries.items():
        if digest_file(path) != result["libraries"][name]["sha256_expected"]:
            raise ValueError(f"Built library changed after its successful build receipt: {name}")
    if digest_file(Path(result["ndk_runtime"])) != result["libraries"]["libc++_shared.so"]["sha256_expected"]:
        raise ValueError("Built libc++_shared.so differs from the pinned NDK runtime")
    destination = Path(result["output_directory"])
    destination.mkdir(parents=True, exist_ok=False)
    original_aar = destination / "original-debug.aar"
    with ZipFile(source) as archive:
        entries = checked_members(archive)
        if AAR_MEMBER not in {entry.filename for entry in entries}:
            raise ValueError("Pinned archive has no debug AAR")
        with archive.open(AAR_MEMBER) as incoming, original_aar.open("xb") as outgoing:
            while block := incoming.read(CHUNK):
                outgoing.write(block)
    replacements = {f"jni/{ABI}/{name}": path for name, path in libraries.items()}
    with ZipFile(original_aar) as archive:
        aar_entries = checked_members(archive)
        arm64_files = {entry.filename for entry in aar_entries
                       if entry.filename.startswith(f"jni/{ABI}/") and not entry.is_dir()}
        if arm64_files != set(replacements):
            raise ValueError("Pinned debug AAR has unexpected ARM64 JNI members")
        omitted_jni = {entry.filename for entry in aar_entries if entry.filename.startswith("jni/")
                       and entry.filename not in {"jni/", f"jni/{ABI}/", *replacements}}
    aar_partial = destination / "godot-lib.template_debug.aar.partial"
    aar_hashes = write_archive(original_aar, aar_partial, replacements, omitted_jni)
    for name, path in replacements.items():
        if aar_hashes[name] != result["libraries"][path.name]["sha256_expected"]:
            raise ValueError(f"Native library changed during packaging: {path.name}")
    aar = destination / "godot-lib.template_debug.aar"
    aar_partial.rename(aar)
    with ZipFile(source) as archive:
        omitted_release = {entry.filename for entry in checked_members(archive)
                           if entry.filename.startswith("libs/release/")}
    source_partial = destination / "android_source.arm64_debug.zip.partial"
    source_hashes = write_archive(source, source_partial, {AAR_MEMBER: aar}, omitted_release)
    output_source = destination / "android_source.arm64_debug.zip"
    source_partial.rename(output_source)
    # Reject source/library changes while files were being read without
    # publishing a success receipt. Artifacts remain in the owned directory.
    if digest_file(source) != OFFICIAL_SHA256:
        raise ValueError("Official source archive changed during packaging")
    if digest_file(build_receipt) != result["build_receipt_sha256"]:
        raise ValueError("Build receipt changed during packaging")
    for name, path in libraries.items():
        if digest_file(path) != result["libraries"][name]["sha256_expected"]:
            raise ValueError(f"Built library changed during packaging: {name}")
    verify_current_build_identity(result)
    result.update(source_hash_verified=True, packaged=True,
        packaging_helper_sha256=digest_file(Path(__file__)),
        official_debug_aar_sha256=digest_file(original_aar),
        artifacts={
        "debug_aar": {"path": str(aar), "sha256": digest_file(aar), "bytes": aar.stat().st_size,
                      "crc_checked_entries": len(aar_hashes), "entry_sha256": aar_hashes,
                      "removed_jni_entries": sorted(omitted_jni), "abis": [ABI]},
        "android_source": {"path": str(output_source), "sha256": digest_file(output_source),
                           "bytes": output_source.stat().st_size, "crc_checked_entries": len(source_hashes),
                           "entry_sha256": source_hashes, "removed_release_entries": sorted(omitted_release)}},
        preservation="All non-JNI debug AAR entries and all non-replaced/non-release source ZIP entries are byte-exact",
        limitations=["Debug ARM64 only; no release/emulator template", "Official pinned Java/resources reused; no Java rebuild",
                     "No APK, signing, Gradle dependency resolution, Android runtime or performance qualification"])
    (destination / "packaging-receipt.json").write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--engine", type=Path, default=ENGINE)
    parser.add_argument("--source", type=Path, default=OFFICIAL_SOURCE)
    parser.add_argument("--build-receipt", type=Path, default=EVIDENCE / "android-build.json")
    parser.add_argument("--output", type=Path, default=OWNED / "android-custom-debug")
    parser.add_argument("--receipt", type=Path)
    parser.add_argument("--package", action="store_true")
    args = parser.parse_args()
    report_path = owned_output(args.receipt, [EVIDENCE, OWNED]) if args.receipt else None
    if report_path and report_path.exists():
        parser.error("Use a new receipt path; existing evidence is preserved")
    try:
        result = preflight(args.engine, args.source, args.build_receipt, args.output)
        if args.package and result["ready"]:
            result = package(result)
        code = 0 if result["ready"] else 2
    except (OSError, ValueError, KeyError, TypeError, BadZipFile, StopIteration, SyntaxError) as error:
        result, code = {"ready": False, "packaged": False, "error": str(error), "android_profile_qualified": False}, 2
    if report_path:
        report_path.parent.mkdir(parents=True, exist_ok=True)
        report_path.write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(result, indent=2))
    return code


if __name__ == "__main__":
    raise SystemExit(main())
