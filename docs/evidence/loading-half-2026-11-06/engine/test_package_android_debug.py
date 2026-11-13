"""Small offline fixtures; never read or repackage the real engine libraries."""
import hashlib
import importlib.util
import io
import json
import stat
import struct
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import Mock, patch
from zipfile import ZIP_DEFLATED, ZipFile, ZipInfo

SPEC = importlib.util.spec_from_file_location(
    "package_android_debug", Path(__file__).with_name("package_android_debug.py"))
packaging = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(packaging)


def archive_bytes(entries):
    output = io.BytesIO()
    with ZipFile(output, "w", ZIP_DEFLATED) as archive:
        archive.comment = b"preserved archive comment"
        for name, content in entries.items():
            archive.writestr(name, content)
    return output.getvalue()


def elf_bytes(machine=183, elf_class=2):
    result = bytearray(64)
    result[:6] = b"\x7fELF" + bytes([elf_class, 1])
    struct.pack_into("<HH", result, 16, 3, machine)
    return bytes(result)


class PackagingTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="bmt-android-packaging-")
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.native_inputs = {"modules/biome_shader_profiles/SCsub":
                              hashlib.sha256(b"synthetic native build input").hexdigest()}
        self.swappy_pins = {}

    def verifier(self):
        return Mock(verify_engine=Mock(return_value="test fingerprint"),
                    native_build_inputs=Mock(return_value=self.native_inputs),
                    SWAPPY_LIBRARY_SHA256=self.swappy_pins)

    def package_fixture(self, result):
        # Archive fixtures deliberately have no prepared engine. Identity is
        # exercised separately with the real preflight/current-identity guards.
        with patch.object(packaging, "verify_current_build_identity"):
            return packaging.package(result)

    def fixture(self):
        old_jni = {f"jni/{abi}/{name}": b"old " + name.encode()
                   for abi in ("arm64-v8a", "x86_64") for name in packaging.LIBRARIES}
        non_native = {"classes.jar": b"exact Java bytecode\x00\xff",
                      "AndroidManifest.xml": b"exact manifest",
                      "res/values/values.xml": b"exact resources"}
        aar = archive_bytes({**non_native, **old_jni})
        source_entries = {"build.gradle": b"exact build script",
                          "gradlew.bat": b"exact wrapper\r\n",
                          packaging.AAR_MEMBER: aar,
                          "libs/release/": b"",
                          "libs/release/godot-lib.template_release.aar": b"official release"}
        source = self.root / "official.zip"
        source.write_bytes(archive_bytes(source_entries))
        libraries = {}
        for name in packaging.LIBRARIES:
            path = self.root / name
            path.write_bytes(elf_bytes() + name.encode())
            libraries[name] = {"path": str(path), "sha256_expected": packaging.digest_file(path),
                               "elf": packaging.elf_header(path)}
        runtime = self.root / "ndk-libc++.so"
        runtime.write_bytes(Path(libraries["libc++_shared.so"]["path"]).read_bytes())
        receipt = self.root / "build.json"
        receipt.write_text('{"exit_code": 0}', encoding="utf-8")
        result = {"ready": True, "source": str(source), "libraries": libraries,
                  "ndk_runtime": str(runtime), "output_directory": str(self.root / "output"),
                  "build_receipt": str(receipt), "build_receipt_sha256": packaging.digest_file(receipt),
                  "android_profile_qualified": False}
        return result, source_entries, non_native

    def test_complete_package_preserves_java_resources_and_source_bytes(self):
        result, source_entries, non_native = self.fixture()
        with patch.object(packaging, "OFFICIAL_SHA256", packaging.digest_file(Path(result["source"]))):
            completed = self.package_fixture(result)
        aar = completed["artifacts"]["debug_aar"]
        source = completed["artifacts"]["android_source"]
        with ZipFile(aar["path"]) as archive:
            self.assertIsNone(archive.testzip())
            self.assertEqual(archive.comment, b"preserved archive comment")
            self.assertEqual(set(archive.namelist()), set(non_native) | {
                f"jni/arm64-v8a/{name}" for name in packaging.LIBRARIES})
            for name, content in non_native.items():
                self.assertEqual(archive.read(name), content)
            for name, row in result["libraries"].items():
                content = archive.read(f"jni/arm64-v8a/{name}")
                self.assertEqual(hashlib.sha256(content).hexdigest(), row["sha256_expected"])
        with ZipFile(source["path"]) as archive:
            self.assertIsNone(archive.testzip())
            self.assertEqual(archive.comment, b"preserved archive comment")
            self.assertFalse(any(name.startswith("libs/release/") for name in archive.namelist()))
            self.assertEqual(archive.read(packaging.AAR_MEMBER), Path(aar["path"]).read_bytes())
            for name in ("build.gradle", "gradlew.bat"):
                self.assertEqual(archive.read(name), source_entries[name])
        receipt = json.loads((self.root / "output/packaging-receipt.json").read_text())
        self.assertTrue(receipt["packaged"])
        self.assertFalse(receipt["android_profile_qualified"])
        self.assertEqual(aar["crc_checked_entries"], len(non_native) + 2)
        self.assertEqual(aar["sha256"], packaging.digest_file(Path(aar["path"])))
        self.assertEqual(source["sha256"], packaging.digest_file(Path(source["path"])))

    def test_wrong_official_hash_rejects_before_output(self):
        result, _, _ = self.fixture()
        with self.assertRaisesRegex(ValueError, "pinned 4.7.2"):
            self.package_fixture(result)
        self.assertFalse(Path(result["output_directory"]).exists())

    def test_changed_built_library_rejects_before_output(self):
        result, _, _ = self.fixture()
        Path(result["libraries"]["libgodot_android.so"]["path"]).write_bytes(elf_bytes() + b"changed")
        with (patch.object(packaging, "OFFICIAL_SHA256", packaging.digest_file(Path(result["source"]))),
              self.assertRaisesRegex(ValueError, "after its successful build receipt")):
            self.package_fixture(result)
        self.assertFalse(Path(result["output_directory"]).exists())

    def test_wrong_ndk_runtime_rejects_before_output(self):
        result, _, _ = self.fixture()
        Path(result["ndk_runtime"]).write_bytes(b"different runtime")
        with (patch.object(packaging, "OFFICIAL_SHA256", packaging.digest_file(Path(result["source"]))),
              self.assertRaisesRegex(ValueError, "pinned NDK runtime")):
            self.package_fixture(result)
        self.assertFalse(Path(result["output_directory"]).exists())

    def test_invalid_abi_and_truncated_elf_rejected(self):
        path = self.root / "lib.so"
        for content in (elf_bytes(machine=62), elf_bytes(elf_class=1), b"short"):
            with self.subTest(content=content):
                path.write_bytes(content)
                with self.assertRaisesRegex(ValueError, "AArch64"):
                    packaging.elf_header(path)

    def test_output_cannot_escape_owned_tree_or_reuse_root(self):
        for destination in (self.root, self.root / "../outside"):
            with self.subTest(destination=destination), self.assertRaisesRegex(ValueError, "task-owned"):
                packaging.owned_output(destination, [self.root])
        self.assertEqual(packaging.owned_output(self.root / "new", [self.root]), self.root / "new")

    def test_unsafe_archive_members_rejected(self):
        for name in ("../outside", "/absolute", "C:/absolute", "dir\\outside"):
            with self.subTest(name=name), ZipFile(io.BytesIO(archive_bytes({"entry": b"unsafe"}))) as archive:
                # zipfile normalizes Windows separators while *writing*;
                # exercise the reader guard with the original unsafe name.
                archive.filelist[0].filename = name
                with self.assertRaisesRegex(ValueError, "Unsupported"):
                    packaging.checked_members(archive)

    def test_duplicate_and_symlink_members_rejected(self):
        output = io.BytesIO()
        with ZipFile(output, "w") as archive:
            info = ZipInfo("link")
            info.create_system = 3
            info.external_attr = (stat.S_IFLNK | 0o777) << 16
            archive.writestr(info, "elsewhere")
        with ZipFile(output) as archive, self.assertRaisesRegex(ValueError, "Unsupported"):
            packaging.checked_members(archive)
        with ZipFile(io.BytesIO(archive_bytes({"entry": b"content"}))) as archive:
            archive.filelist.append(archive.filelist[0])
            with self.assertRaisesRegex(ValueError, "duplicate"):
                packaging.checked_members(archive)

    def test_unknown_or_conflicting_replacements_rejected(self):
        original = self.root / "original.zip"
        original.write_bytes(archive_bytes({"entry": b"content"}))
        replacement = self.root / "replacement"
        replacement.write_bytes(b"new")
        for replacements, omitted in (({"unknown": replacement}, set()),
                                       ({}, {"unknown"}), ({"entry": replacement}, {"entry"})):
            with self.subTest(replacements=replacements, omitted=omitted), self.assertRaises(ValueError):
                packaging.write_archive(original, self.root / "out.zip", replacements, omitted)

    def test_output_hash_mismatch_rejected(self):
        path = self.root / "changed.zip"
        path.write_bytes(archive_bytes({"entry": b"changed"}))
        with self.assertRaisesRegex(ValueError, "Output member changed"):
            packaging.verify_archive(path, {"entry": hashlib.sha256(b"expected").hexdigest()})

    def test_build_receipt_change_rejected_before_output(self):
        result, _, _ = self.fixture()
        Path(result["build_receipt"]).write_text('{"exit_code": 1}', encoding="utf-8")
        with (patch.object(packaging, "OFFICIAL_SHA256", packaging.digest_file(Path(result["source"]))),
              self.assertRaisesRegex(ValueError, "Build receipt changed")):
            self.package_fixture(result)
        self.assertFalse(Path(result["output_directory"]).exists())

    def preflight_fixture(self):
        engine = self.root / "build/engine"
        sdk = self.root / "build/sdk"
        library_dir = engine / "platform/android/java/lib/libs/debug/arm64-v8a"
        library_dir.mkdir(parents=True)
        libraries = {}
        for name in packaging.LIBRARIES:
            path = library_dir / name
            path.write_bytes(elf_bytes() + name.encode())
            libraries[str(path)] = packaging.digest_file(path)
        runtime = sdk / "ndk" / packaging.NDK / "toolchains/llvm/prebuilt/windows-x86_64/sysroot/usr/lib/aarch64-linux-android/libc++_shared.so"
        runtime.parent.mkdir(parents=True)
        runtime.write_bytes((library_dir / "libc++_shared.so").read_bytes())
        swappy = {}
        for abi in ("arm64-v8a", "armeabi-v7a", "x86", "x86_64"):
            path = engine / "thirdparty/swappy-frame-pacing" / abi / "libswappy_static.a"
            path.parent.mkdir(parents=True)
            path.write_bytes(b"synthetic Swappy archive " + abi.encode())
            self.swappy_pins[abi] = packaging.digest_file(path)
            swappy[abi] = {"path": str(path), "sha256": self.swappy_pins[abi]}
        receipt = {"exit_code": 0, "ready": True, "source_fingerprint": "test fingerprint",
                   "required_ndk": packaging.NDK, "engine": str(engine), "sdk": str(sdk),
                   "command": ["platform=android", "target=template_debug", "arch=arm64",
                               "generate_android_binaries=no", "opengl3=yes", "vulkan=yes",
                               "swappy=yes", "profiler=none", "ndk_platform=android-24",
                               "debug_symbols=no", "optimize=speed", "lto=none",
                               f"ANDROID_HOME={sdk.resolve()}"],
                   "libraries": libraries, "native_build_inputs": self.native_inputs.copy(),
                   "swappy": swappy}
        receipt_path = self.root / "build.json"
        receipt_path.write_text(json.dumps(receipt), encoding="utf-8")
        source = self.root / "source.zip"
        source.write_bytes(b"large source ZIP deliberately not read in cheap preflight")
        return (engine, source, receipt_path, self.root / "build/owned/output"), receipt

    def run_preflight(self, args):
        with patch.object(packaging, "ROOT", self.root), \
                patch.object(packaging, "OWNED", self.root / "build/owned"), \
                patch.object(packaging, "engine_verifier", return_value=self.verifier()):
            return packaging.preflight(*args)

    def test_preflight_validates_receipt_without_hashing_source_archive(self):
        args, _ = self.preflight_fixture()
        result = self.run_preflight(args)
        self.assertTrue(result["ready"])
        self.assertFalse(result["source_hash_verified"])
        self.assertEqual(set(result["libraries"]), set(packaging.LIBRARIES))
        self.assertEqual(result["native_build_inputs"], self.native_inputs)
        self.assertEqual(set(result["swappy"]), set(self.swappy_pins))

    def test_preflight_missing_library_is_clean_not_ready(self):
        args, _ = self.preflight_fixture()
        missing = args[0] / "platform/android/java/lib/libs/debug/arm64-v8a/libc++_shared.so"
        missing.unlink()
        result = self.run_preflight(args)
        self.assertFalse(result["ready"])
        self.assertIn(str(missing), result["missing"])

    def test_preflight_rejects_failed_stale_or_wrong_variant_receipts(self):
        args, receipt = self.preflight_fixture()
        variants = [{**receipt, "exit_code": 1}, {**receipt, "ready": False},
                    {**receipt, "source_fingerprint": "stale"},
                    {**receipt, "required_ndk": "old"},
                    {**receipt, "command": [value for value in receipt["command"] if value != "swappy=yes"]},
                    {**receipt, "command": [value for value in receipt["command"] if value != "profiler=none"]},
                    {**receipt, "command": [value.replace("arch=arm64", "arch=x86_64")
                                             for value in receipt["command"]]},
                    {**receipt, "command": [value.replace("target=template_debug", "target=template_release")
                                             for value in receipt["command"]]}]
        for variant in variants:
            with self.subTest(variant=variant):
                args[2].write_text(json.dumps(variant), encoding="utf-8")
                with self.assertRaisesRegex(ValueError, "successful matching ARM64"):
                    self.run_preflight(args)

    def test_preflight_rejects_duplicate_or_conflicting_build_flags(self):
        args, receipt = self.preflight_fixture()
        assignments = ["arch=arm64", "arch=x86_64", "swappy=yes", "swappy=no",
                       f"ANDROID_HOME={Path(receipt['sdk']).resolve()}",
                       f"ANDROID_HOME={self.root / 'different-sdk'}"]
        for assignment in assignments:
            for location in ("first", "last"):
                with self.subTest(assignment=assignment, location=location):
                    command = ([assignment, *receipt["command"]] if location == "first"
                               else [*receipt["command"], assignment])
                    args[2].write_text(json.dumps({**receipt, "command": command}), encoding="utf-8")
                    with self.assertRaisesRegex(ValueError, "successful matching ARM64"):
                        self.run_preflight(args)

    def test_preflight_rejects_missing_or_wrong_required_build_options(self):
        args, receipt = self.preflight_fixture()
        replacements = {"ndk_platform=android-24": "ndk_platform=android-23",
                        "debug_symbols=no": "debug_symbols=yes", "optimize=speed": "optimize=none",
                        "lto=none": "lto=full", "profiler=none": "profiler=tracy",
                        f"ANDROID_HOME={Path(receipt['sdk']).resolve()}":
                        f"ANDROID_HOME={self.root / 'different-sdk'}"}
        for required, wrong in replacements.items():
            for replacement in (None, wrong):
                with self.subTest(required=required, replacement=replacement):
                    command = [value if value != required else replacement for value in receipt["command"]]
                    command = [value for value in command if value is not None]
                    args[2].write_text(json.dumps({**receipt, "command": command}), encoding="utf-8")
                    with self.assertRaisesRegex(ValueError, "successful matching ARM64"):
                        self.run_preflight(args)

    def test_preflight_rejects_missing_stale_or_extra_native_inputs(self):
        args, receipt = self.preflight_fixture()
        variants = [None, {}, {key: "0" * 64 for key in self.native_inputs},
                    {**self.native_inputs, "unexpected-input": "1" * 64}]
        for inputs in variants:
            with self.subTest(inputs=inputs):
                variant = {**receipt, "native_build_inputs": inputs}
                if inputs is None:
                    del variant["native_build_inputs"]
                args[2].write_text(json.dumps(variant), encoding="utf-8")
                with self.assertRaisesRegex(ValueError, "Native build inputs differ"):
                    self.run_preflight(args)

    def test_preflight_rejects_missing_or_mismatched_swappy_receipts(self):
        args, receipt = self.preflight_fixture()
        abi = "arm64-v8a"
        row = receipt["swappy"][abi]
        variants = [None, {},
                    {key: value for key, value in receipt["swappy"].items() if key != abi},
                    {**receipt["swappy"], abi: {**row, "sha256": "0" * 64}},
                    {**receipt["swappy"], abi: {**row, "path": str(self.root / "wrong.a")}}]
        for swappy in variants:
            with self.subTest(swappy=swappy):
                variant = {**receipt, "swappy": swappy}
                if swappy is None:
                    del variant["swappy"]
                args[2].write_text(json.dumps(variant), encoding="utf-8")
                with self.assertRaisesRegex(ValueError, "Pinned Swappy dependency differs"):
                    self.run_preflight(args)

    def test_preflight_rejects_changed_or_missing_swappy_bytes(self):
        args, receipt = self.preflight_fixture()
        for abi, row in receipt["swappy"].items():
            path = Path(row["path"])
            original = path.read_bytes()
            for changed in (b"stale dependency", None):
                with self.subTest(abi=abi, changed=changed):
                    if changed is None:
                        path.unlink()
                    else:
                        path.write_bytes(changed)
                    with self.assertRaisesRegex(ValueError, "Pinned Swappy dependency differs"):
                        self.run_preflight(args)
                    path.write_bytes(original)

    def test_current_identity_rechecks_source_inputs_and_swappy(self):
        args, _ = self.preflight_fixture()
        result = self.run_preflight(args)
        verifier = self.verifier()
        with patch.object(packaging, "engine_verifier", return_value=verifier):
            packaging.verify_current_build_identity(result)
            verifier.verify_engine.return_value = "changed source fingerprint"
            with self.assertRaisesRegex(ValueError, "Native build identity changed"):
                packaging.verify_current_build_identity(result)
            verifier.verify_engine.return_value = "test fingerprint"
            verifier.native_build_inputs.return_value = {"changed": "0" * 64}
            with self.assertRaisesRegex(ValueError, "Native build identity changed"):
                packaging.verify_current_build_identity(result)
            verifier.native_build_inputs.return_value = self.native_inputs
            Path(result["swappy"]["arm64-v8a"]["path"]).write_bytes(b"changed after preflight")
            with self.assertRaisesRegex(ValueError, "Pinned Swappy dependency differs"):
                packaging.verify_current_build_identity(result)

    def test_package_checks_identity_before_output_and_before_success_receipt(self):
        for check in ("before", "after"):
            with self.subTest(check=check):
                result, _, _ = self.fixture()
                result["output_directory"] = str(self.root / f"output-{check}")
                effects = [ValueError("identity rejected")] if check == "before" else [None, ValueError("identity rejected")]
                with (patch.object(packaging, "OFFICIAL_SHA256", packaging.digest_file(Path(result["source"]))),
                      patch.object(packaging, "verify_current_build_identity", side_effect=effects) as identity,
                      self.assertRaisesRegex(ValueError, "identity rejected")):
                    packaging.package(result)
                destination = Path(result["output_directory"])
                self.assertEqual(identity.call_count, 1 if check == "before" else 2)
                self.assertEqual(destination.exists(), check == "after")
                self.assertFalse((destination / "packaging-receipt.json").exists())


if __name__ == "__main__":
    unittest.main(testRunner=unittest.TextTestRunner(stream=sys.stdout, verbosity=2))
