"""Exercise the export validator with isolated valid and invalid receipts."""

import json
import tempfile
import unittest
from pathlib import Path

import check_garage_workshop as checker


class WorkshopGateTests(unittest.TestCase):
    def setUp(self):
        build = checker.ROOT / "build"
        build.mkdir(exist_ok=True)
        self.temp = tempfile.TemporaryDirectory(prefix="workshop-gate-", dir=build)
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.game = self.root / "game"
        self.write(checker.GENERATOR, 'const SOURCES: Array[String]=["tests/bake_garage_architecture.gd", "vehicle/car_mesh_lods.gd"]')
        self.write("vehicle/car_mesh_lods.gd", "original LOD source")
        self.write(checker.SCENE, "accepted scene")
        self.receipt = {
            "generator": "res://" + checker.GENERATOR,
            "engine": "pinned-test-engine",
            "sources": {p: checker.digest(self.game / p) for p in [checker.GENERATOR, "vehicle/car_mesh_lods.gd"]},
            "scene_sha256": checker.digest(self.game / checker.SCENE),
        }
        self.plan = {"schema": checker.SCHEMA, "engine": self.receipt["engine"],
                     "sources": self.receipt["sources"].copy(), "meshes": {"test": {"keep": True}}}
        self.save_plan()
        self.save_receipt()

    def write(self, path, text):
        target = self.game / path
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(text, encoding="utf-8")

    def save_receipt(self):
        self.write("assets/garage/workshop_v1.provenance.json", json.dumps(self.receipt))

    def save_plan(self):
        self.write(checker.RECIPE, json.dumps(self.plan))
        self.receipt["reduction"] = {"path": checker.RECIPE, "schema": checker.SCHEMA,
                                     "sha256": checker.digest(self.game / checker.RECIPE)}

    def test_changed_plan(self):
        self.write(checker.RECIPE, "changed plan")
        with self.assertRaisesRegex(ValueError, "Changed or missing workshop reduction"):
            checker.check(self.root)

    def test_plan_source_binding(self):
        self.plan["sources"]["vehicle/car_mesh_lods.gd"] = "wrong"
        self.save_plan(); self.save_receipt()
        with self.assertRaisesRegex(ValueError, "Stale workshop reduction"):
            checker.check(self.root)

    def test_plan_engine_binding(self):
        self.plan["engine"] = "other engine"
        self.save_plan(); self.save_receipt()
        with self.assertRaisesRegex(ValueError, "Stale workshop reduction"):
            checker.check(self.root)

    def test_missing_plan(self):
        (self.game / checker.RECIPE).unlink()
        with self.assertRaises(OSError):
            checker.check(self.root)

    def test_plan_fixed_path(self):
        self.receipt["reduction"]["path"] = "../another.json"
        self.save_receipt()
        with self.assertRaisesRegex(ValueError, "Changed or missing workshop reduction"):
            checker.check(self.root)

    def test_accepted_is_read_only(self):
        before = {p: p.read_bytes() for p in self.root.rglob("*") if p.is_file()}
        checker.check(self.root)
        self.assertEqual(before, {p: p.read_bytes() for p in self.root.rglob("*") if p.is_file()})

    def test_changed_lod(self):
        self.write("vehicle/car_mesh_lods.gd", "new policy")
        with self.assertRaisesRegex(ValueError, "Stale workshop source"):
            checker.check(self.root)

    def test_changed_scene(self):
        self.write(checker.SCENE, "unaccepted scene")
        with self.assertRaisesRegex(ValueError, "Changed workshop scene"):
            checker.check(self.root)

    def test_omitted_dependency(self):
        del self.receipt["sources"]["vehicle/car_mesh_lods.gd"]
        self.save_receipt()
        with self.assertRaisesRegex(ValueError, "every declared input"):
            checker.check(self.root)

    def test_added_dependency(self):
        self.write(checker.GENERATOR, 'const SOURCES: Array[String]=["new.gd"]')
        with self.assertRaisesRegex(ValueError, "every declared input"):
            checker.check(self.root)

    def test_missing_scene(self):
        (self.game / checker.SCENE).unlink()
        with self.assertRaises(OSError):
            checker.check(self.root)

    def test_unknown_generator(self):
        self.receipt["generator"] = "other"
        self.save_receipt()
        with self.assertRaisesRegex(ValueError, "Unknown workshop generator"):
            checker.check(self.root)


if __name__ == "__main__":
    unittest.main()
