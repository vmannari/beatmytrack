"""Compare aapt XML trees after explicit package/renderer/version normalization.

Only the two known optional Vulkan feature declarations may be removed from
the Mobile manifest for the equality comparison; they are reported verbatim.
Sibling ordering and aapt source line numbers are ignored.
"""
import argparse
import json
import re
from pathlib import Path

PACKAGES = ("org.beatmytrack.rendererprobe.gl20261031", "org.beatmytrack.rendererprobe.vk20261031")
VULKAN = ("android.hardware.vulkan.level", "android.hardware.vulkan.version")


def parse(path):
    stack = []
    root = None
    for line in path.read_text(encoding="utf-8").splitlines():
        stripped = line.strip()
        indent = len(line) - len(line.lstrip())
        if stripped.startswith("E: "):
            name = re.sub(r"\s*\(line=\d+\)$", "", stripped[3:])
            while stack and stack[-1][0] >= indent:
                stack.pop()
            node = {"name": name, "attributes": [], "children": []}
            if stack:
                stack[-1][1]["children"].append(node)
            else:
                root = node
            stack.append((indent, node))
        elif stripped.startswith("A: ") and stack:
            value = stripped[3:]
            for package in PACKAGES:
                value = value.replace(package, "<PACKAGE>")
            value = re.sub(r"0\.3\.0-creator\.[0-9a-f]{32}", "<VERSION>", value)
            value = value.replace('"gl_compatibility"', '"<RENDERER>"').replace('"mobile"', '"<RENDERER>"')
            stack[-1][1]["attributes"].append(value)
    if root is None:
        raise ValueError("no root element in " + str(path))
    return root


def canonical(node, removed):
    children = []
    for child in node["children"]:
        if child["name"] == "uses-feature" and any(any(name in attr for name in VULKAN) for attr in child["attributes"]):
            removed.append(child)
            continue
        children.append(canonical(child, removed))
    return {"name": node["name"], "attributes": sorted(node["attributes"]),
            "children": sorted(children, key=lambda item: json.dumps(item, sort_keys=True))}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("compatibility", type=Path)
    parser.add_argument("mobile", type=Path)
    parser.add_argument("--out", required=True, type=Path)
    args = parser.parse_args()
    removed_a, removed_b = [], []
    a, b = canonical(parse(args.compatibility), removed_a), canonical(parse(args.mobile), removed_b)
    names = [name for node in removed_b for name in VULKAN if any(name in attr for attr in node["attributes"])]
    optional = all(any("android:required" in attr and "0x0" in attr for attr in node["attributes"]) for node in removed_b)
    result = {"equal_after_normalization": a == b, "compatibility_vulkan_features": removed_a,
              "mobile_vulkan_features": removed_b, "mobile_features_optional": optional,
              "limitations": "Sibling order and aapt line numbers ignored; this does not prove runtime feature selection."}
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(result, indent=2), encoding="utf-8")
    print(json.dumps(result, indent=2))
    if a != b or removed_a or sorted(names) != sorted(VULKAN) or not optional:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
