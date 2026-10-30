"""Reproduce selected regressions with exact task-start modules in memory."""
import importlib.abc
import importlib.machinery
import importlib.util
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
BEFORE = Path(__file__).resolve().parent / "before"


class Source(importlib.machinery.SourceFileLoader):
    def exec_module(self, module):
        module.__file__ = str(ROOT / "backend" / Path(*module.__name__.split(".")).with_suffix(".py"))
        super().exec_module(module)


class Original(importlib.abc.MetaPathFinder):
    def find_spec(self, fullname, path=None, target=None):
        if not fullname.startswith("bmt_backend."):
            return None
        source = BEFORE / ("backend__" + fullname.replace(".", "__") + ".py.txt")
        if not source.is_file():
            return None
        loader = Source(fullname, str(source))
        return importlib.util.spec_from_loader(fullname, loader)


sys.path.insert(0, str(ROOT/"backend"))
sys.meta_path.insert(0, Original())
import pytest

raise SystemExit(pytest.main(sys.argv[1:]))
