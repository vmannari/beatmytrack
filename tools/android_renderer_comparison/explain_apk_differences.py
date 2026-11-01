"""Explain narrowly scoped APK binary differences without hiding raw parity.

Requires the strict compare_apks result as a separate artifact. This checks
the exact locations, scene node-id arrays, sparse index, dex checksums and
baseline-profile checksums. It does not certify runtime rendering equivalence.
"""
import argparse
import hashlib
import json
import re
import struct
import zipfile
import zlib
from pathlib import Path

import compare_apks


SCENES = ("-game.scn", "-parking_hall_drive.scn", "-device_performance_probe.scn", "-app.scn")


def one(names, suffix):
    matches = [name for name in names if name.endswith(suffix)]
    if len(matches) != 1:
        raise ValueError(f"expected one {suffix}: {matches}")
    return matches[0]


def scene_node_ids(blob):
    token = b"node_ids\x00"
    if blob.count(token) != 1:
        raise ValueError("scene does not contain one node_ids field")
    pos = blob.index(token) + len(token)
    kind, count = struct.unpack_from("<II", blob, pos)
    if kind != 32 or count > 10000:
        raise ValueError("unexpected node_ids encoding")
    return pos + 8, pos + 8 + count * 4, count


def entry_range(blob, path):
    encoded = path.encode("utf-8")
    if blob.count(encoded) != 1:
        raise ValueError("sparse-pack path is ambiguous: " + path)
    pos = blob.index(encoded)
    length = struct.unpack_from("<I", blob, pos - 4)[0]
    if length < len(encoded) or length > len(encoded) + 4:
        raise ValueError("unexpected sparse-pack path padding: " + path)
    entry = pos + length
    return entry + 8, entry + 16, entry + 32


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("compatibility", type=Path)
    parser.add_argument("mobile", type=Path)
    parser.add_argument("--out", type=Path, required=True)
    args = parser.parse_args()
    result = {"scenes": {}, "sparse_pack": {}, "dex": {}, "baseline_profile": {}}
    with zipfile.ZipFile(args.compatibility) as a, zipfile.ZipFile(args.mobile) as b:
        aa, bb = compare_apks.inventory(args.compatibility), compare_apks.inventory(args.mobile)
        changed = sorted(name for name in set(aa) | set(bb) if aa.get(name) != bb.get(name))
        scene_asset_names = []
        for suffix in SCENES:
            left_name, right_name = one(a.namelist(), suffix), one(b.namelist(), suffix)
            left, right = a.read(left_name), b.read(right_name)
            lo, hi, count = scene_node_ids(left)
            other_lo, other_hi, other_count = scene_node_ids(right)
            if (lo, hi, count) != (other_lo, other_hi, other_count) or len(left) != len(right):
                raise ValueError("scene node-id field layout differs: " + suffix)
            if left[:lo] + left[hi:] != right[:lo] + right[hi:]:
                raise ValueError("scene changed outside node_ids: " + suffix)
            result["scenes"][suffix] = {"node_id_count": count, "only_node_id_bytes_differ": True}
            scene_asset_names.append((left_name, right_name))
        expected_assets = {"assets/assets.sparsepck", "assets/dexopt/baseline.prof", *compare_apks.ALLOWED}
        expected_assets.update(re.sub(r"^assets/\.godot/exported/\d+/", "assets/.godot/exported/<variant>/", x) for x, _ in scene_asset_names)
        if set(changed) != expected_assets:
            raise ValueError("unexpected strict asset differences: " + repr(sorted(set(changed) ^ expected_assets)))
        pack_a, pack_b = a.read("assets/assets.sparsepck"), b.read("assets/assets.sparsepck")
        if len(pack_a) != len(pack_b):
            raise ValueError("sparse pack lengths differ")
        allowed_offsets = set()
        for left_name, right_name in scene_asset_names + [("assets/core/build_identity.gdc", "assets/core/build_identity.gdc"), ("assets/project.binary", "assets/project.binary")]:
            left_path, right_path = left_name.removeprefix("assets/"), right_name.removeprefix("assets/")
            left_size, left_md5, left_end = entry_range(pack_a, left_path)
            right_size, right_md5, right_end = entry_range(pack_b, right_path)
            if (left_size, left_md5, left_end) != (right_size, right_md5, right_end):
                raise ValueError("sparse pack table layout differs")
            for archive, blob, name, size_pos, md5_pos in [(a, pack_a, left_name, left_size, left_md5), (b, pack_b, right_name, right_size, right_md5)]:
                payload = archive.read(name)
                if struct.unpack_from("<Q", blob, size_pos)[0] != len(payload) or blob[md5_pos:md5_pos + 16] != hashlib.md5(payload).digest():
                    raise ValueError("sparse pack entry size/hash mismatch: " + name)
            allowed_offsets.update(range(left_size, left_end))
        pack_diffs = [i for i, (x, y) in enumerate(zip(pack_a, pack_b)) if x != y]
        if not set(pack_diffs) <= allowed_offsets:
            raise ValueError("sparse pack changed outside identified sizes and checksums")
        result["sparse_pack"] = {"different_bytes": len(pack_diffs), "only_identified_sizes_and_md5_changed": True}
        dex_a, dex_b = a.read("classes.dex"), b.read("classes.dex")
        for dex in (dex_a, dex_b):
            if dex[12:32] != hashlib.sha1(dex[32:]).digest() or struct.unpack_from("<I", dex, 8)[0] != zlib.adler32(dex[12:]) & 0xffffffff:
                raise ValueError("classes.dex header checksum invalid")
        # Build IDs are captured by Godot's generated version; the private
        # package IDs have equal length so all other bytes can be compared.
        packages = [b"org.beatmytrack.rendererprobe.gl20261031", b"org.beatmytrack.rendererprobe.vk20261031"]
        versions = [re.search(rb"0\.3\.0-creator\.[0-9a-f]{32}", dex).group(0) for dex in (dex_a, dex_b)]
        def canonical(dex, package, version):
            if dex.count(package) != 1 or dex.count(version) != 1:
                raise ValueError("DEX package/version occurrence is unexpected")
            data = dex.replace(package, b"P" * len(package)).replace(version, b"V" * len(version))
            return data[:8] + bytes(24) + data[32:]
        if len(packages[0]) != len(packages[1]) or len(versions[0]) != len(versions[1]) or canonical(dex_a, packages[0], versions[0]) != canonical(dex_b, packages[1], versions[1]):
            raise ValueError("classes.dex differs beyond package/version/checksum")
        result["dex"] = {"only_package_version_and_header_checksums_differ": True, "versions": [x.decode() for x in versions]}
        profile_a, profile_b = (archive.read("assets/dexopt/baseline.prof") for archive in (a, b))
        if profile_a[:9] != profile_b[:9] or profile_a[:8] != b"pro\x00010\x00":
            raise ValueError("unsupported baseline profile format")
        raw_a, raw_b = zlib.decompress(profile_a[17:]), zlib.decompress(profile_b[17:])
        if len(raw_a) != len(raw_b) or raw_a[:8] + raw_a[12:] != raw_b[:8] + raw_b[12:]:
            raise ValueError("baseline profile differs beyond dex checksum")
        if struct.unpack_from("<I", raw_a, 8)[0] != a.getinfo("classes.dex").CRC or struct.unpack_from("<I", raw_b, 8)[0] != b.getinfo("classes.dex").CRC:
            raise ValueError("baseline profile dex CRC is not the corresponding APK dex CRC")
        result["baseline_profile"] = {"only_corresponding_dex_crc_differs": True}
    result["limitations"] = ["SceneState node/property/connection equality and absence of scene-ID use require separate checks.",
                             "Manifest/signature differences, actual renderer, GPU output and device behavior remain separate."]
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(result, indent=2), encoding="utf-8")
    print(json.dumps(result, indent=2))


if __name__ == "__main__":
    main()
