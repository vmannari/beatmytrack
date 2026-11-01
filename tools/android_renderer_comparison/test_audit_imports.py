"""Validate checksum audit on one single and one multi-output import."""
import contextlib
import hashlib
import io
import json
import sys
import tempfile
from pathlib import Path
from unittest.mock import patch

import audit_imports


def md5(data):
    return hashlib.md5(data).hexdigest()


def main():
    folder = Path("build/android-renderer-comparison-tests")
    folder.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(dir=folder) as temp:
        root = Path(temp) / "project"
        imports = root / ".godot/imported"
        imports.mkdir(parents=True)
        (root / "single.png").write_bytes(b"single-source")
        (imports / "single.ctex").write_bytes(b"single-output")
        (imports / "single.md5").write_text(f'source_md5="{md5(b"single-source")}"\ndest_md5="{md5(b"single-output")}"\n')
        (root / "single.png.import").write_text('[remap]\npath="res://.godot/imported/single.ctex"\n[deps]\nsource_file="res://single.png"\n')
        (root / "multi.png").write_bytes(b"multi-source")
        (imports / "multi.s3tc.ctex").write_bytes(b"first")
        (imports / "multi.etc2.ctex").write_bytes(b"second")
        (imports / "multi.md5").write_text(f'source_md5="{md5(b"multi-source")}"\ndest_md5="{md5(b"firstsecond")}"\n')
        (root / "multi.png.import").write_text('[remap]\npath.s3tc="res://.godot/imported/multi.s3tc.ctex"\npath.etc2="res://.godot/imported/multi.etc2.ctex"\n[deps]\nsource_file="res://multi.png"\n')
        out = Path(temp) / "report.json"
        args = ["audit_imports.py", str(root), "--out", str(out)]
        with patch.object(sys, "argv", args), contextlib.redirect_stdout(io.StringIO()):
            audit_imports.main()
        assert json.loads(out.read_text())["counts"] == {"checksums_match": 2}
        (root / "single.png").write_bytes(b"changed")
        with patch.object(sys, "argv", args), contextlib.redirect_stdout(io.StringIO()):
            try:
                audit_imports.main()
            except SystemExit as error:
                assert error.code == 1
            else:
                raise AssertionError("stale source was accepted")
        assert json.loads(out.read_text())["counts"]["source_checksum_mismatch"] == 1
    print("ANDROID_RENDERER_IMPORT_AUDIT_TEST: pass")


if __name__ == "__main__":
    main()
