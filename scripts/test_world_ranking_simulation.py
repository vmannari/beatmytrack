"""Behavioral edge cases for the offline ranking experiment; standard unittest."""
import unittest

import numpy as np
from simulate_world_ranking import (
    Config,
    Rolling,
    local_awards,
    make_groups,
    payout_curve,
    rank_rows,
    simulate,
    world_ranks,
)


class RankingSimulationTests(unittest.TestCase):
    def test_original_sixteen_player_pro_schedule(self):
        actual = payout_curve(np.arange(1, 17), np.full(16, 16), False) * 300
        np.testing.assert_allclose(actual, [300, 195, 120, 120, 60, 60, 60, 60,
                                             15, 15, 15, 15, 15, 15, 15, 15])

    def test_exact_race_ties_and_missing_results(self):
        values = np.array([[10, 10, 20, 0]])
        ranks = rank_rows(values, np.array([[True, True, True, False]]))
        np.testing.assert_array_equal(ranks, [[1, 1, 3, 0]])

    def test_tied_winners_share_first_and_second_payout(self):
        scores = np.array([[100, 100, 80, 70, 60, 50, 40, 30, 20, 10]])
        awards, ranks = local_awards(scores, np.ones(scores.shape, bool), np.array([300.]), smooth=False)
        expected = np.mean(payout_curve(np.array([1, 2]), np.array([10, 10]), False)) * 3000
        self.assertEqual(awards[0, 0], np.floor(expected + .5))
        self.assertEqual(awards[0, 0], awards[0, 1])
        self.assertEqual(ranks[0, 2], 3)

    def test_incomplete_and_solo_fields_cannot_mint_points(self):
        scores = np.array([[100, 90, 80, 70, 60, 50]])
        qualified = np.array([[True, False, False, False, False, False]])
        awards, _ = local_awards(scores, qualified, np.array([500.]), smooth=False)
        self.assertFalse(awards.any())
        qualified[0, :5] = True
        awards, _ = local_awards(scores, qualified, np.array([500.]), smooth=False)
        self.assertEqual(awards[0, 0], 2500)
        self.assertEqual(awards[0, -1], 0)

    def test_rolling_expiry_replaces_from_reserves_and_stops_at_26(self):
        rolling = Rolling(1)
        rolling.add(0, np.array([800], dtype=np.uint16))
        for week in range(1, 17):
            totals, _ = rolling.add(week, np.array([600], dtype=np.uint16))
        self.assertEqual(totals[0], 9800)
        for week in range(17, 27):
            totals, _ = rolling.add(week, np.array([0], dtype=np.uint16))
        self.assertEqual(totals[0], 9600)  # 80 expires; a 60 reserve enters: net loss 20.
        for week in range(27, 43):
            totals, _ = rolling.add(week, np.array([0], dtype=np.uint16))
        self.assertEqual(totals[0], 0)

    def test_new_result_replaces_sixteenth_and_season_does_not_reset_world(self):
        rolling = Rolling(1)
        for week in range(16):
            before, _ = rolling.add(week, np.array([600], dtype=np.uint16))
        after, _ = rolling.add(16, np.array([1950], dtype=np.uint16))
        self.assertEqual(after[0] - before[0], 1350)
        self.assertEqual(rolling.season(16)[0], 3750)
        self.assertGreater(after[0], rolling.season(16)[0])

    def test_countback_resolves_equal_totals_but_never_exact_records(self):
        totals = np.array([100, 100, 100, 0])
        best = np.array([[40, 60], [30, 70], [30, 70], [0, 0]])
        ranks, _ = world_ranks(totals, best)
        np.testing.assert_array_equal(ranks, [3, 1, 1, 0])
        permutation = np.array([2, 0, 3, 1])
        permuted, _ = world_ranks(totals[permutation], best[permutation])
        np.testing.assert_array_equal(permuted, ranks[permutation])

    def test_matching_covers_every_entrant_once_and_caps_groups(self):
        ids = np.arange(1003)
        skill = np.linspace(-3, 3, len(ids))
        groups = make_groups(ids, skill, np.random.default_rng(42), .25)
        np.testing.assert_array_equal(np.sort(groups[groups >= 0]), ids)
        self.assertLessEqual((groups >= 0).sum(axis=1).max(), 20)
        for row in groups:
            members = row[row >= 0]
            self.assertEqual(len(set(np.floor(skill[members] / .25))), 1)

    def test_circuit_tiebreak_preserves_points_and_compares_only_equal_records(self):
        original, with_quality = Rolling(3), Rolling(3)
        for week in range(27):
            award = np.array([5000, 5000, 4900], dtype=np.uint16)
            normal_totals, normal_best = original.add(week, award)
            totals, best = with_quality.add(week, award, np.array([.999, .995, 1.0]))
            np.testing.assert_array_equal(totals, normal_totals)
            np.testing.assert_array_equal(best, normal_best)
        ranks, _ = world_ranks(totals, best, with_quality.counting_quality)
        np.testing.assert_array_equal(ranks, [1, 2, 3])

    def test_existing_track_points_are_used_without_backend_import(self):
        import ast
        from pathlib import Path

        from simulate_world_ranking import TRACK_POINTS

        source = Path(__file__).resolve().parents[1] / "backend/bmt_backend/rivalry.py"
        tree = ast.parse(source.read_text(encoding="utf-8"))
        assignment = next(node for node in tree.body if isinstance(node, ast.Assign)
                          and any(isinstance(target, ast.Name) and target.id == "POINTS" for target in node.targets))
        np.testing.assert_array_equal(TRACK_POINTS, ast.literal_eval(assignment.value))

    def test_seeded_simulation_is_reproducible_and_keeps_newcomer_unranked(self):
        config = Config(population=120, weeks=3, seed=7)
        first, second = simulate(config), simulate(config)
        self.assertEqual(first["weekly"], second["weekly"])
        self.assertEqual(first["traces"], second["traces"])
        newcomers = [r for r in first["traces"] if r["player"] == "new_expert_week_53"]
        self.assertTrue(all(r["rank"] == 0 and r["points"] == 0 for r in newcomers))
        self.assertEqual(first["checks"]["awards_to_incomplete_players"], 0)
        self.assertLessEqual(first["checks"]["maximum_weekly_award"], 5000)
        self.assertLessEqual(first["checks"]["maximum_rolling_points"], 80000)


if __name__ == "__main__":
    unittest.main()
