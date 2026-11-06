"""Offline configuration/artifact and missing-toolchain rejection checks."""
import contextlib
import importlib.util
import io
from pathlib import Path
import tempfile
import unittest
from unittest import mock
import zipfile

import check_android_delivery as delivery

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("build_android", ROOT / "native/biome_shader_profiles/build_android.py")
build = importlib.util.module_from_spec(spec)
spec.loader.exec_module(build)


class AndroidDeliveryTests(unittest.TestCase):
    def setUp(self):
        parent = ROOT / "build/android-delivery-tests"
        parent.mkdir(parents=True, exist_ok=True)
        self.temporary = tempfile.TemporaryDirectory(dir=parent)
        self.addCleanup(self.temporary.cleanup)
        self.folder = Path(self.temporary.name)
        self.assertTrue(self.folder.resolve().is_relative_to(parent.resolve()))

    def apk(self, abis):
        path = self.folder / "fixture.apk"
        with zipfile.ZipFile(path, "w") as archive:
            archive.writestr("AndroidManifest.xml", b"fixture")
            archive.writestr("assets/track.bin", b"shared assets")
            for abi in abis:
                archive.writestr(f"lib/{abi}/libgodot_android.so", b"fixture engine")
        return path

    def engine(self):
        engine = self.folder / "engine"
        detect = engine / "platform/android/detect.py"
        detect.parent.mkdir(parents=True)
        detect.write_text('def get_ndk_version(): return "29.0.14206865"\ndef get_min_target_api(): return 24\n')
        return engine

    def test_presets_only_change_delivery(self):
        for name, (_, abis) in delivery.PRESETS.items():
            row = delivery.inspect_presets(ROOT / "game/export_presets.cfg", name)
            self.assertEqual(set(row["abis"]), abis)

    def test_visual_or_resource_filter_drift_is_rejected(self):
        text = (ROOT / "game/export_presets.cfg").read_text()
        start, arm64 = text.split("[preset.1]", 1)
        for old, new in [('export_filter="all_resources"', 'export_filter="selected_resources"'),
                         ('screen/immersive_mode=true', 'screen/immersive_mode=false')]:
            with self.subTest(old=old):
                path = self.folder / "presets.cfg"
                path.write_text(start + "[preset.1]" + arm64.replace(old, new))
                with self.assertRaises(ValueError):
                    delivery.inspect_presets(path, "Android ARM64")

    def test_each_matching_apk_is_accepted(self):
        for _, abis in delivery.PRESETS.values():
            row = delivery.inspect_apk(self.apk(abis), abis)
            self.assertEqual(set(row["verified_abis"]), abis)

    def test_wrong_or_extra_abi_is_rejected(self):
        with self.assertRaises(ValueError):
            delivery.inspect_apk(self.apk({"arm64-v8a", "x86_64"}), {"arm64-v8a"})
        with self.assertRaises(ValueError):
            delivery.inspect_apk(self.apk({"arm64-v8a"}), {"arm64-v8a", "x86_64"})

    def test_truncated_artifact_is_rejected(self):
        path = self.apk({"arm64-v8a"})
        path.write_bytes(path.read_bytes()[:-24])
        with self.assertRaises(zipfile.BadZipFile):
            delivery.inspect_apk(path, {"arm64-v8a"})

    def test_missing_toolchain_prevents_build_or_download(self):
        engine = self.engine()
        with mock.patch.object(build, "verify_engine", return_value="fixture"), \
                mock.patch.object(build.subprocess, "run") as run, \
                mock.patch("sys.argv", ["build_android.py", "--engine", str(engine), "--sdk", str(self.folder / "missing-sdk"), "--build"]), \
                contextlib.redirect_stdout(io.StringIO()):
            self.assertEqual(build.main(), 2)
            run.assert_not_called()

    def test_native_plan_keeps_both_renderers_and_does_not_package(self):
        engine = self.engine()
        with mock.patch.object(build, "verify_engine", return_value="fixture"):
            row = build.preflight(engine, self.folder / "missing-sdk", "arm64", "template_release", 4)
        self.assertFalse(row["ready"])
        self.assertEqual(row["required_ndk"], "29.0.14206865")
        for argument in ("arch=arm64", "target=template_release", "generate_android_binaries=no", "opengl3=yes", "vulkan=yes"):
            self.assertIn(argument, row["command"])
        self.assertFalse(row["android_profile_qualified"])


if __name__ == "__main__":
    unittest.main(verbosity=2)
