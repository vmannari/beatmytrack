"""Reproduce existing failures with task-start Python sources, without file swaps."""
import importlib.abc
import importlib.machinery
import importlib.util
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
BEFORE = Path(__file__).with_name("before")
sys.path[:0] = [str(ROOT / "backend"), str(ROOT / "backend/tests")]


class BeforeLoader(importlib.machinery.SourceFileLoader):
    def get_code(self, fullname):
        source = BEFORE / "backend" / Path(*fullname.split(".")).with_suffix(".py")
        return compile(source.read_text(encoding="utf-8-sig"), self.path, "exec")


class BeforeFinder(importlib.abc.MetaPathFinder):
    def find_spec(self, fullname, path=None, target=None):
        source = BEFORE / "backend" / Path(*fullname.split(".")).with_suffix(".py")
        if fullname.startswith("bmt_backend.") and source.is_file():
            original = ROOT / "backend" / Path(*fullname.split(".")).with_suffix(".py")
            return importlib.util.spec_from_file_location(fullname, original, loader=BeforeLoader(fullname, str(original)))
        return None


sys.meta_path.insert(0, BeforeFinder())
import pytest

if __name__ == "__main__":
    raise SystemExit(pytest.main(sys.argv[1:]))
