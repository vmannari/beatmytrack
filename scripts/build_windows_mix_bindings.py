"""Generate two extra wrappers from the existing pinned Godot binding source."""
import json
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]
BINDINGS = ROOT / ".tools/godot-cpp-music"
OUTPUT = ROOT / "build/windows_audio/mix_bindings"


def main():
    # The existing generator recursively replaces only OUTPUT/gen. Validate
    # that exact target before invoking it; shared .tools generation is untouched.
    generated = (OUTPUT / "gen").resolve()
    if not generated.is_relative_to((ROOT / "build/windows_audio").resolve()):
        raise ValueError("Generated binding target escaped task build storage")
    OUTPUT.mkdir(parents=True, exist_ok=True)
    sys.path.insert(0, str(BINDINGS))
    from build_profile import generate_trimmed_api
    from binding_generator import generate_bindings
    api = generate_trimmed_api(str(BINDINGS / "gdextension/extension_api.json"), str(ROOT / "native/windows_audio/mix_bindings_profile.json"))
    original = json.loads((BINDINGS / "gdextension/extension_api.json").read_text(encoding="utf-8"))
    # The minimal-profile filter treats native AudioFrame pointers as excluded
    # engine classes. Retain the exact required virtual from the pinned API.
    process = next(method for cls in original["classes"] if cls["name"] == "AudioEffectInstance" for method in cls["methods"] if method["name"] == "_process")
    instance = next(cls for cls in api["classes"] if cls["name"] == "AudioEffectInstance")
    if not any(method["name"] == "_process" for method in instance["methods"]): instance["methods"].insert(0, process)
    target = OUTPUT / "extension_api.json"
    target.write_text(json.dumps(api), encoding="utf-8")
    generate_bindings(str(target), False, output_dir=str(OUTPUT))


if __name__ == "__main__": main()
