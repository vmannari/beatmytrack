"""Validate equivalent Android presets and a finished APK's actual ABIs.

Read-only: no export, signing, SDK installation or device access.

scripts/dev.ps1 -Action ExportAndroid -AndroidPreset "Android ARM64" selects
the separate ARM64 APK. Default Android Debug retains ARM64 and x86_64.
Both use the existing debug build/signing mode; neither is a store release.
"""
import argparse
import configparser
import json
from pathlib import Path
import sys
import zipfile

ROOT = Path(__file__).resolve().parents[1]
PRESETS = {
    "Android Debug": ("circuit01-debug.apk", {"arm64-v8a", "x86_64"}),
    "Android ARM64": ("circuit01-arm64.apk", {"arm64-v8a"}),
}


def inspect_presets(path: Path, selected: str) -> dict:
    config = configparser.ConfigParser(interpolation=None, strict=True)
    config.optionxform = str
    config.read_string(path.read_text(encoding="utf-8"))
    found = {}
    for section in config.sections():
        if section.startswith("preset.") and not section.endswith(".options"):
            name = config[section].get("name", "").strip('"')
            if name in found:
                raise ValueError(f"Duplicate preset name: {name}")
            found[name] = section
    base = found["Android Debug"]
    for name, (filename, expected_abis) in PRESETS.items():
        section = found[name]
        values, options = config[section], config[section + ".options"]
        if values.get("platform") != '"Android"' or values.get("export_path") != f'"../build/android/{filename}"':
            raise ValueError(f"Unexpected platform/output for {name}")
        actual_abis = {key.removeprefix("architectures/") for key, value in options.items()
                       if key.startswith("architectures/") and value == "true"}
        if actual_abis != expected_abis:
            raise ValueError(f"Unexpected architectures for {name}: {sorted(actual_abis)}")
        for key in set(values) | set(config[base]):
            if key not in {"name", "export_path", "runnable"} and values.get(key) != config[base].get(key):
                raise ValueError(f"Delivery presets differ in {key}")
        for key in set(options) | set(config[base + ".options"]):
            if key != "architectures/x86_64" and options.get(key) != config[base + ".options"].get(key):
                raise ValueError(f"Delivery presets differ in {key}")
    return {"preset": selected, "filename": PRESETS[selected][0], "abis": sorted(PRESETS[selected][1])}


def inspect_apk(path: Path, expected_abis: set[str]) -> dict:
    with zipfile.ZipFile(path) as archive:
        names = archive.namelist()
        if len(names) != len(set(names)):
            raise ValueError("APK contains duplicate ZIP entries")
        bad = archive.testzip()
        if bad is not None:
            raise ValueError(f"APK checksum failure: {bad}")
        if "AndroidManifest.xml" not in names:
            raise ValueError("APK has no Android manifest")
        libraries = [name for name in names if name.startswith("lib/") and name.endswith(".so")]
        actual_abis = {name.split("/")[1] for name in libraries}
        if actual_abis != expected_abis:
            raise ValueError(f"APK architectures {sorted(actual_abis)} do not match {sorted(expected_abis)}")
        for abi in expected_abis:
            if f"lib/{abi}/libgodot_android.so" not in names:
                raise ValueError(f"APK is missing the Godot engine for {abi}")
        return {"artifact": str(path), "bytes": path.stat().st_size, "zip_entries": len(names),
                "native_libraries": libraries, "verified_abis": sorted(actual_abis)}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--presets", type=Path, default=ROOT / "game/export_presets.cfg")
    parser.add_argument("--preset", choices=PRESETS, required=True)
    parser.add_argument("--artifact", type=Path)
    args = parser.parse_args()
    try:
        result = inspect_presets(args.presets, args.preset)
        if args.artifact:
            result.update(inspect_apk(args.artifact, set(result["abis"])))
    except (OSError, ValueError, KeyError, configparser.Error, zipfile.BadZipFile) as error:
        print(f"Android delivery validation failed: {error}", file=sys.stderr)
        return 1
    print(json.dumps(result, indent=2))
    return 0


if __name__ == "__main__":
    sys.exit(main())
