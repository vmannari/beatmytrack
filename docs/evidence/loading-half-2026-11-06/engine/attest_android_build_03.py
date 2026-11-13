"""Retain the explicitly late input snapshot for the already-running build 03."""
import argparse
import hashlib
import importlib.util
import json
from datetime import datetime, timezone
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
SCRIPT = ROOT / "native/biome_shader_profiles/build_android.py"
SPEC = importlib.util.spec_from_file_location("android_build_identity", SCRIPT)
build = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(build)
SNAPSHOT = HERE / "android-build-03-input-snapshot.json"
RECEIPT = HERE / "android-build-03.json"
ATTESTED = HERE / "android-build-03-attested.json"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--finalize", action="store_true")
    args = parser.parse_args()
    if not args.finalize:
        result = {"time_utc": datetime.now(timezone.utc).isoformat(),
                  "phase": "during compilation, not before compilation",
                  "native_build_inputs": build.native_build_inputs(build.ENGINE),
                  "build_helper_snapshot_sha256": hashlib.sha256(SCRIPT.read_bytes()).hexdigest(),
                  "source_fingerprint": build.verify_engine(build.ENGINE),
                  "limitation": "Build 03 began before this additional input guard existed. These inputs were captured while it was compiling; only stability from this snapshot through completion is attested."}
        with SNAPSHOT.open("x", encoding="utf-8") as output:
            output.write(json.dumps(result, indent=2) + "\n")
    else:
        snapshot = json.loads(SNAPSHOT.read_text(encoding="utf-8"))
        result = json.loads(RECEIPT.read_text(encoding="utf-8"))
        if result.get("exit_code") != 0 or not result.get("ready"):
            raise ValueError("Build 03 did not succeed")
        if (build.native_build_inputs(build.ENGINE) != snapshot["native_build_inputs"]
                or build.verify_engine(build.ENGINE) != snapshot["source_fingerprint"]
                or result["source_fingerprint"] != snapshot["source_fingerprint"]):
            raise ValueError("Native build inputs changed after the in-progress snapshot")
        for abi, expected in build.SWAPPY_LIBRARY_SHA256.items():
            dependency = result["swappy"][abi]
            if (dependency["sha256"] != expected
                    or hashlib.sha256(Path(dependency["path"]).read_bytes()).hexdigest() != expected):
                raise ValueError("Swappy dependency changed after native preflight")
        checkpoint = ROOT / "docs/evidence/biome-shader-profiles-2026-11-06/checkpoint.json"
        historical_hashes = json.loads(checkpoint.read_text(encoding="utf-8"))["source_sha256"]
        historical_inputs = {}
        for name in build.MODULE_FILES:
            historical = historical_hashes[f"native/biome_shader_profiles/{name}"]
            if snapshot["native_build_inputs"][f"modules/biome_shader_profiles/{name}"] != historical:
                raise ValueError(f"Module input differs from the earlier qualified checkpoint: {name}")
            historical_inputs[name] = historical
        result.update(native_build_inputs=snapshot["native_build_inputs"],
                      input_snapshot_phase=snapshot["phase"], input_snapshot_time_utc=snapshot["time_utc"],
                      input_snapshot_limitation=snapshot["limitation"],
                      build_helper_snapshot_sha256=snapshot["build_helper_snapshot_sha256"],
                      historical_module_checkpoint=str(checkpoint), historical_module_inputs=historical_inputs,
                      original_build_receipt=str(RECEIPT),
                      original_build_receipt_sha256=hashlib.sha256(RECEIPT.read_bytes()).hexdigest())
        with ATTESTED.open("x", encoding="utf-8") as output:
            output.write(json.dumps(result, indent=2) + "\n")
    print(json.dumps(result, indent=2))


if __name__ == "__main__":
    main()
