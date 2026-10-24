"""Reproduce migration guards with task-start runtime sources, without editing them."""
import contextlib
import importlib.abc
import importlib.util
import io
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
OUT = Path(__file__).resolve().parent
sys.path.insert(0, str(ROOT / "backend"))
MODULES = {"bmt_backend." + name: "backend/bmt_backend/" + name + ".py"
           for name in ("app", "runs", "challenges", "news", "worker")}


class SavedLoader(importlib.abc.Loader):
    def __init__(self, relative):
        self.relative = relative

    def create_module(self, _spec):
        return None

    def exec_module(self, module):
        original = ROOT / self.relative
        module.__file__ = str(original)
        exec(compile((OUT / "before" / self.relative).read_bytes(), str(original), "exec"), module.__dict__)  # noqa: S102 - trusted exact task-start repository sources, never external input.


class SavedSources(importlib.abc.MetaPathFinder):
    def find_spec(self, fullname, _path=None, _target=None):
        if fullname in MODULES:
            return importlib.util.spec_from_loader(fullname, SavedLoader(MODULES[fullname]),
                                                  origin=str(ROOT / MODULES[fullname]))
        return None


sys.meta_path.insert(0, SavedSources())
import pytest

capture = io.StringIO()
with contextlib.redirect_stdout(capture), contextlib.redirect_stderr(capture):
    result = pytest.main([
        str(ROOT / "backend/tests/test_challenges.py") + "::test_additive_attempt_migration_preserves_existing_challenges[sqlite]",
        str(ROOT / "backend/tests/test_news.py") + "::test_migration_seeds_existing_racers_without_old_news[sqlite]",
        "-q", "--disable-warnings",
    ])
output = capture.getvalue()
(OUT / "original-migration-guards.log").write_text(output, encoding="utf-8")
assert result == 1 and "2 failed" in output and "Drain creator achievement events before downgrading 0054" in output, output
print("Both migration failures reproduce with task-start runtime modules; original assertions and guard remain intact.")
