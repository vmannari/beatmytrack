"""Validate bounded prefix reuse, including the cases that prohibit activation."""
import importlib.util
from pathlib import Path

from sqlalchemy import delete, event, select
from test_domains import domain as domain_fixture
from test_domains import public_course, race

from bmt_backend.histogram_population import HistogramPopulation
from bmt_backend.runs import comparison_populations
from bmt_backend.track_models import LapPersonalBest, PersonalBest

domain = domain_fixture
root = next(parent for parent in Path(__file__).resolve().parents if (parent / "docs/evidence").is_dir())
spec = importlib.util.spec_from_file_location("histogram_prefix_prototype",
    root / "docs/evidence/histogram-followup-2026-10-22/prefix_prototype.py")
prototype = importlib.util.module_from_spec(spec)
spec.loader.exec_module(prototype)


def test_prefix_histogram_matches_public_boundaries_in_one_query(domain):
    version, board = public_course(domain)
    race(domain, version, "Alice", frames=20)
    race(domain, version, "Bob", frames=30)
    with domain.factory() as session:
        fields = comparison_populations(session, [board], board, "absent", False)
        for metric, field in zip(("race", "lap"), fields):
            grid = field.histogram(board, metric, 30, *field.frame(None, None, None))
            boundaries = [row["from_ticks"] for row in grid["bins"]] + [grid["bins"][-1]["to_ticks_exclusive"]]
            statements = []
            def record(_conn, _cursor, sql, *_args, _statements=statements):
                _statements.append(sql)
            event.listen(domain.app.state.engine, "before_cursor_execute", record)
            try:
                counts = prototype.histogram_counts(session, board, metric, boundaries)
            finally:
                event.remove(domain.app.state.engine, "before_cursor_execute", record)
            assert counts == [row["count"] for row in grid["bins"]]
            assert len(statements) == 1 and "reward_rank_counts" in statements[0]
            assert "personal_bests" not in statements[0] and "players" not in statements[0]


def test_retained_lap_without_race_pb_prohibits_raw_prefix_reuse(domain):
    version, board = public_course(domain)
    race(domain, version, "Alice", frames=20)
    with domain.factory() as session:
        session.execute(delete(PersonalBest).where(PersonalBest.board_id == board,
            PersonalBest.player_id == domain.players["Alice"]))
        session.flush()
        assert session.scalar(select(LapPersonalBest.time_ticks).where(LapPersonalBest.board_id == board,
            LapPersonalBest.player_id == domain.players["Alice"])) == 20
        _, laps = comparison_populations(session, [board], board, "absent", False)
        assert sum(prototype.histogram_counts(session, board, "lap", [1, 216001])) == laps.cumulative[-1]+1


def test_combined_populations_cannot_add_public_and_private_prefixes():
    public = HistogramPopulation.from_rows([("same-player", 100), ("public-player", 200)])
    private = HistogramPopulation.from_rows([("same-player", 90), ("private-player", 300)])
    combined = HistogramPopulation.from_rows([("same-player", 90), ("public-player", 200), ("private-player", 300)])
    assert public.cumulative[-1]+private.cumulative[-1] == combined.cumulative[-1]+1
