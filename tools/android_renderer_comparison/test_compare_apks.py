"""Offline contract for package comparison: expected and unexpected changes."""
import contextlib
import io
import json
import sys
import tempfile
import zipfile
from pathlib import Path
from unittest.mock import patch

import compare_apks


def package(path, asset):
    with zipfile.ZipFile(path, "w") as archive:
        archive.writestr("assets/project.binary", path.name)
        archive.writestr("assets/.godot/exported/123/scene.scn", b"same-scene")
        archive.writestr("assets/payload", asset)
        archive.writestr("lib/arm64-v8a/libgodot_android.so", b"same-engine")


def main():
    folder = Path("build/android-renderer-comparison-tests")
    folder.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(dir=folder) as temp:
        base = Path(temp)
        a, b, report = base/"a.apk", base/"b.apk", base/"report.json"
        package(a, b"same")
        package(b, b"same")
        argv = ["compare_apks.py", str(a), str(b), "--out", str(report)]
        with patch.object(sys, "argv", argv), contextlib.redirect_stdout(io.StringIO()):
            compare_apks.main()
        assert json.loads(report.read_text())["unexpected"] == []
        package(b, b"changed")
        with patch.object(sys, "argv", argv), contextlib.redirect_stdout(io.StringIO()):
            try:
                compare_apks.main()
            except SystemExit as error:
                assert error.code == 1
            else:
                raise AssertionError("changed payload was accepted")
        assert json.loads(report.read_text())["unexpected"] == ["assets/payload"]
    print("ANDROID_RENDERER_APK_COMPARISON_TEST: pass")


if __name__ == "__main__":
    main()
