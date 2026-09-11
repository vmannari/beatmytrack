"""Executable contract examples, not game-engine or backend integration tests.
Run: python -m unittest discover -s technical/tests -v (from package root).
Requires jsonschema: python -m pip install jsonschema
"""
import copy, hashlib, json, unittest
from pathlib import Path
from jsonschema import Draft202012Validator
ROOT=Path(__file__).resolve().parents[1]
MANIFEST={"schema_version":1,"track_hash":"a"*64,"physics_version":"p0.1","rules_version":"r1","laps":4,"direction":"forward","start_mode":"standing","competition":"class","constraint_id":"C-150","assist_policy":"manual"}
def digest(value):
    return hashlib.sha256(json.dumps(value,sort_keys=True,separators=(",",":"),ensure_ascii=False).encode()).hexdigest()
def rank(time_ms,times):
    return 1+sum(t<time_ms for t in times)
def event_points(rank_value,population):
    return None if population<=1 else 1000*(population-rank_value)/(population-1)
class Contracts(unittest.TestCase):
    def setUp(self):
        self.v=Draft202012Validator(json.loads((ROOT/"schemas/race_manifest.schema.json").read_text()))
    def test_schemas_well_formed(self):
        for p in (ROOT/"schemas").glob("*.schema.json"):
            Draft202012Validator.check_schema(json.loads(p.read_text()))
    def test_manifest_valid(self): self.v.validate(MANIFEST)
    def test_lap_bounds(self):
        for n in (2,6):
            x={**MANIFEST,"laps":n};self.assertFalse(self.v.is_valid(x))
    def test_no_unknown_fields(self): self.assertFalse(self.v.is_valid({**MANIFEST,"extra":True}))
    def test_required_physics(self):
        x=MANIFEST.copy();del x["physics_version"];self.assertFalse(self.v.is_valid(x))
    def test_key_stable_order(self): self.assertEqual(digest(MANIFEST),digest(dict(reversed(list(MANIFEST.items())))))
    def test_laps_split_boards(self): self.assertNotEqual(digest(MANIFEST),digest({**MANIFEST,"laps":3}))
    def test_physics_split_boards(self): self.assertNotEqual(digest(MANIFEST),digest({**MANIFEST,"physics_version":"p0.2"}))
    def test_assists_split_boards(self): self.assertNotEqual(digest(MANIFEST),digest({**MANIFEST,"assist_policy":"auto"}))
    def test_ties_share_rank(self):
        ts=[71000,72050,72050,74000];self.assertEqual(rank(72050,ts),2)
    def test_top_percentage(self): self.assertAlmostEqual(100*104/1248,8.3333333333)
    def test_points_best_worst(self):
        self.assertEqual(event_points(1,50),1000);self.assertEqual(event_points(50,50),0)
    def test_single_entrant_provisional(self): self.assertIsNone(event_points(1,1))
    def test_pb_population_not_attempts(self):
        attempts=[("a",73000),("a",72050),("b",73010)];pbs={}
        for player,t in attempts: pbs[player]=min(pbs.get(player,t),t)
        self.assertEqual(len(pbs),2);self.assertEqual(pbs["a"],72050)
    def test_idempotent_grant_example(self):
        seen=set();balance=0
        for key,amount in [("run-1:credits",317),("run-1:credits",317)]:
            if key not in seen: seen.add(key);balance+=amount
        self.assertEqual(balance,317)
    def test_race_sum(self): self.assertEqual(sum([18210,17940,18030,17870]),72050)
if __name__=="__main__":unittest.main()
