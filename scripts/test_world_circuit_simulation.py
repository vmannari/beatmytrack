import unittest
from math import isqrt

import numpy as np
from simulate_world_circuit import (
    Candidate,
    Scenario,
    award_points,
    counting_records,
    midranks2,
    rank_world,
    simulate,
    weekly_classification,
)


class CircuitTests(unittest.TestCase):
    def test_tied_track_times_share_average_occupied_places(self):
        np.testing.assert_array_equal(midranks2(np.array([10, 10, 20, 30])), [3, 3, 6, 8])

    def test_track_duration_and_slower_entrants_do_not_change_existing_order(self):
        ticks = np.array([[10, 30, 40, 30, 20], [20, 10, 20, 20, 40], [30, 20, 30, 10, 30]])
        _, ranks, _, _ = weekly_classification(ticks, "places")
        scaled = ticks * np.array([4, 1, 1, 1, 1])
        _, after, _, _ = weekly_classification(scaled, "places")
        np.testing.assert_array_equal(ranks, after)
        padded = np.vstack([ticks, np.full((10, 5), 1000)])
        _, extra, _, _ = weekly_classification(padded, "places")
        np.testing.assert_array_equal(ranks, extra[:3])

    def test_improving_a_time_cannot_worsen_own_classification(self):
        rng = np.random.default_rng(42)
        ticks = rng.integers(1000, 2000, (200, 5))
        _, before, _, _ = weekly_classification(ticks, "places")
        improved = ticks.copy()
        improved[27, 3] //= 2
        _, after, _, _ = weekly_classification(improved, "places")
        self.assertLessEqual(after[27], before[27])

    def test_incomplete_week_is_ineligible_in_five_track_contract(self):
        ticks = np.array([[10, 10, 10, 10, 0], [20, 20, 20, 20, 20]])
        ids, _, _, _ = weekly_classification(ticks, "places")
        np.testing.assert_array_equal(ids, [1])

    def test_four_track_contract_rewards_fifth_finish_monotonically(self):
        ticks = np.array([[10, 10, 10, 10, 0], [20, 20, 20, 20, 20], [30, 30, 30, 30, 30]])
        _, before, _, _ = weekly_classification(ticks, "places", 4)
        ticks[0, 4] = 1000
        _, after, _, _ = weekly_classification(ticks, "places", 4)
        self.assertLessEqual(after[0], before[0])

    def test_complete_track_sporting_positions_are_invariant_to_input_order(self):
        ticks = np.array([[10, 30, 40, 30, 20], [20, 10, 20, 20, 40], [30, 20, 30, 10, 30],
                          [10, 30, 40, 30, 20]])
        _, ranks, _, _ = weekly_classification(ticks, "places")
        permutation = np.array([3, 1, 0, 2])
        _, other, _, _ = weekly_classification(ticks[permutation], "places")
        np.testing.assert_array_equal(other, ranks[permutation])

    def test_alternating_world_champions_can_legitimately_share_no1(self):
        points = np.array([[1000, 850] * 13, [850, 1000] * 13], dtype=np.uint16)
        places = np.array([[1, 2] * 13, [2, 1] * 13], dtype=np.int32)
        totals, best, counted = counting_records(points, places, 12)
        ranks, _ = rank_world(totals, best, counted)
        np.testing.assert_array_equal(totals, [12000, 12000])
        np.testing.assert_array_equal(ranks, [1, 1])

    def test_best_six_season_and_best_twelve_world_have_distinct_counting_sets(self):
        points = np.array([[1000, 850, 775, 750, 728, 620, 535, 307, 226, 105, 74, 23, 7]], dtype=np.uint16)
        places = np.array([[1, 2, 3, 4, 10, 50, 100, 500, 1000, 5000, 10000, 100000, 1000000]], dtype=np.int32)
        season, _, _ = counting_records(points, places, 6)
        world, _, _ = counting_records(points, places, 12)
        self.assertEqual(season[0], 4723)
        self.assertEqual(world[0], points.sum() - 7)

    def test_absolute_awards_are_monotonic_and_ignore_slower_field_padding(self):
        ranks = np.arange(1, 10001)
        points = award_points(ranks, 10000, "absolute")
        np.testing.assert_array_equal(points, award_points(ranks, 100000, "absolute"))
        self.assertTrue(np.all(points[:-1] >= points[1:]))
        self.assertEqual(points[0], 1000)
        self.assertLess(points[1], 1000)

    def test_solo_and_small_fields_cannot_award_full_championship_points(self):
        self.assertEqual(award_points(np.array([1]), 1, "absolute")[0], 0)
        self.assertLess(award_points(np.array([1]), 127, "absolute")[0], 1000)
        self.assertEqual(award_points(np.array([1]), 128, "absolute")[0], 1000)

    def test_awards_match_an_exact_integer_contract(self):
        for n in [2, 16, 64, 127, 128, 10000, 1000000]:
            positions = np.unique(np.r_[np.arange(1, min(n, 1000) + 1), np.linspace(1, n, 500, dtype=int)])
            actual = award_points(positions, n, "absolute")
            factor = min(n - 1, 127)
            expected = [max(1, isqrt((100000000 * factor * factor) // ((int(r) + 99) * 127 * 127)))
                        for r in positions]
            np.testing.assert_array_equal(actual, expected)

    def test_fourth_root_awards_have_an_exact_integer_contract_and_clear_podium(self):
        for n in [2, 16, 127, 128, 10000, 1000000]:
            positions = np.unique(np.r_[np.arange(1, min(n, 1000) + 1), np.linspace(1, n, 500, dtype=int)])
            actual = award_points(positions, n, "fourth_root")
            factor = min(n - 1, 127)
            expected = [max(1, isqrt(isqrt((1000 ** 4 * factor ** 4) // (int(r) * 127 ** 4))))
                        for r in positions]
            np.testing.assert_array_equal(actual, expected)
        np.testing.assert_array_equal(award_points(np.array([1, 2, 3, 10, 100, 1000]), 10000, "fourth_root"),
                                      [1000, 840, 759, 562, 316, 177])

    def test_podium_schedule_is_exact_monotonic_and_padding_independent(self):
        for n in [2, 16, 127, 128, 10000, 1000000]:
            positions = np.unique(np.r_[np.arange(1, min(n, 1000) + 1), np.linspace(1, n, 500, dtype=int)])
            actual = award_points(positions, n, "podium")
            factor = min(n - 1, 127)
            expected = [max(1, ([1000, 850, 775][int(r) - 1] * factor) // 127) if r <= 3
                        else max(1, isqrt((56250000 * factor * factor) // ((int(r) + 96) * 127 * 127)))
                        for r in positions]
            np.testing.assert_array_equal(actual, expected)
            self.assertTrue(np.all(actual[:-1] >= actual[1:]))
        np.testing.assert_array_equal(award_points(np.array([1, 2, 3, 4, 10, 100, 1000]), 10000, "podium"),
                                      [1000, 850, 775, 750, 728, 535, 226])
        np.testing.assert_array_equal(award_points(np.arange(1, 10001), 10000, "podium"),
                                      award_points(np.arange(1, 10001), 100000, "podium"))

    def test_countback_selects_best_place_for_equal_awards(self):
        points = np.array([[100, 100, 100]], dtype=np.uint16)
        places = np.array([[20, 10, 30]], dtype=np.int32)
        total, _, counted = counting_records(points, places, 2)
        self.assertEqual(total[0], 200)
        np.testing.assert_array_equal(counted, [[10, 20]])

    def test_earned_total_precedes_best_finish_and_true_ties_share_rank(self):
        totals = np.array([200, 200, 200, 199, 0], dtype=np.int32)
        best = np.array([[100, 100], [100, 100], [100, 100], [99, 100], [0, 0]], dtype=np.uint16)
        places = np.array([[10, 20], [5, 30], [5, 30], [1, 1], [999, 999]], dtype=np.int32)
        ranks, _ = rank_world(totals, best, places)
        np.testing.assert_array_equal(ranks, [3, 1, 1, 4, 0])

    def test_small_seeded_experiment_is_reproducible(self):
        config = Scenario(population=120, weeks=3, seed=7,
                          candidates=(Candidate(count=12), Candidate(count=16)))
        first, second = simulate(config), simulate(config)
        self.assertEqual(first["weekly"], second["weekly"])
        self.assertEqual(first["traces"], second["traces"])


if __name__ == "__main__":
    unittest.main()
