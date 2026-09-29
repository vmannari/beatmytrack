import json
import re
import tempfile
import unittest
from pathlib import Path
import importlib.util

ROOT = Path(__file__).resolve().parents[1]

class SkillPackageTests(unittest.TestCase):
    def test_required_files_exist(self):
        required = [
            "SKILL.md",
            "references/project-direction.md",
            "references/music-craft.md",
            "references/iteration.md",
            "references/mrt2-wsl.md",
            "references/adaptive-delivery.md",
            "references/evidence.md",
            "assets/STATE.template.md",
            "assets/round.template.json",
            "assets/provenance.template.json",
            "scripts/review_pack.py",
            "scripts/validate_skill.py",
            "tests/agent-evals.json",
        ]
        for rel in required:
            self.assertTrue((ROOT / rel).is_file(), rel)

    def test_front_matter(self):
        text = (ROOT / "SKILL.md").read_text(encoding="utf-8")
        self.assertRegex(text, r"(?m)^name:\s*bmt-adaptive-music$")
        self.assertRegex(text, r"(?m)^description:\s*.+")

    def test_all_referenced_support_files_exist(self):
        text = (ROOT / "SKILL.md").read_text(encoding="utf-8")
        refs = sorted(set(re.findall(
            r"(?:references|assets|scripts)/[A-Za-z0-9_.-]+(?:/[A-Za-z0-9_.-]+)*",
            text
        )))
        self.assertGreater(len(refs), 5)
        for rel in refs:
            self.assertTrue((ROOT / rel).exists(), rel)

    def test_json_templates(self):
        for rel in ["assets/round.template.json", "assets/provenance.template.json", "tests/agent-evals.json"]:
            json.loads((ROOT / rel).read_text(encoding="utf-8"))

    def test_state_mentions_preference_not_rule(self):
        state = (ROOT / "assets/STATE.template.md").read_text(encoding="utf-8").lower()
        self.assertIn("preferences, not permanent rules", state)
        self.assertIn("distorted-rock", state)

    def test_skill_preserves_collision_contract(self):
        text = (ROOT / "SKILL.md").read_text(encoding="utf-8").lower()
        self.assertIn("do not silently alter existing collision", text)
        self.assertIn("preserve the project's current collision/reset/recovery", text)

    def test_small_tasks_can_stay_small(self):
        text = (ROOT / "SKILL.md").read_text(encoding="utf-8").lower()
        self.assertIn("one revised candidate is sufficient", text)
        self.assertIn("technical", text)

    def test_tools_music_generator_is_named(self):
        text = (ROOT / "SKILL.md").read_text(encoding="utf-8")
        self.assertIn("tools/music_generator/", text)

    def test_provenance_has_licensing(self):
        data = json.loads((ROOT / "assets/provenance.template.json").read_text(encoding="utf-8"))
        self.assertIn("licensing", data)
        self.assertIn("tool_version", data["generator"])
        self.assertIn("conditioning_sources", data["generation"])

    def test_review_helper_imports_without_third_party_packages(self):
        p = ROOT / "scripts" / "review_pack.py"
        spec = importlib.util.spec_from_file_location("review_pack", p)
        mod = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(mod)
        self.assertTrue(callable(mod.sha256))

    def test_validator_runs_without_yaml(self):
        p = ROOT / "scripts" / "validate_skill.py"
        spec = importlib.util.spec_from_file_location("validate_skill", p)
        mod = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(mod)
        self.assertEqual(mod.main.__name__, "main")

    def test_agent_eval_coverage(self):
        data = json.loads((ROOT / "tests" / "agent-evals.json").read_text(encoding="utf-8"))
        names = " ".join(x["name"] for x in data).lower()
        for keyword in ["focused", "collision", "listening", "layers", "provenance"]:
            self.assertIn(keyword, names)

if __name__ == "__main__":
    unittest.main()
