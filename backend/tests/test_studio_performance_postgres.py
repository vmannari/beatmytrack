"""The Studio paging and report budgets on an isolated real PostgreSQL schema."""
# ruff: noqa: F401, F811
from uuid import uuid4

import pytest
from test_auth_postgres import postgres_auth
from test_studio_performance import (
    catalogue,
    evidence,
    observations,
    platform,
    test_behaviour_tabs_match_combined_exact_report_without_other_analyses,
    test_catalogue_uses_lookahead_and_never_counts_population_or_player_history,
    test_exact_player_identifier_uses_equality_not_text_scan,
    test_finance_keeps_period_flows_without_global_wallet_or_unused_purchase_counts,
    test_full_length_unicode_names_have_valid_bounded_cursors,
    test_overview_has_no_lifetime_account_content_or_history_scan,
    test_player_cursor_forward_backward_ties_filter_fence_and_later_inserts,
    test_track_cursor_matches_full_sort_including_unrated_and_backwards,
)

pytestmark = pytest.mark.postgres


@pytest.fixture
def auth_app(postgres_auth):
    return postgres_auth[0]


@pytest.fixture
def auth_client(postgres_auth):
    return postgres_auth[1]


@pytest.fixture
def catalogue(auth_app, auth_client, monkeypatch):
    """Read-only catalogue data needs no fabricated accepted race/PB writes.

    Seed projections at insert time. The separate legacy PB fixture currently
    fails inside concurrent migration 0050's JSON comparison before a Studio
    read executes; retain its failure rather than changing its trigger here.
    """
    from dataclasses import replace

    from bmt_backend.identity_models import Identity, Player
    from bmt_backend.track_models import Track, TrackVersion
    auth_app.state.settings = replace(auth_app.state.settings, admin_owner_key="o" * 40, admin_analyst_key="a" * 40)
    monkeypatch.setattr("bmt_backend.studio_catalogue.now", lambda: 2000000000)
    with auth_app.state.session_factory() as db:
        owner = Player(display_name="Catalogue owner")
        other = Player(display_name="Catalogue artificial", is_test_driver=True)
        db.add_all([owner, other])
        db.flush()
        db.add(Identity(player_id=owner.id, provider="google", subject=str(uuid4())))
        for i in range(3):
            track = Track(owner_id=owner.id, official=i == 1)
            db.add(track)
            db.flush()
            db.add(TrackVersion(track_id=track.id, number=1, name=f"Read-only course {i}", content_hash=str(i) * 64,
                manifest={}, state="published", created_at=100 + i, published_at=None if i == 2 else 100 + i,
                rating_count=0 if i == 2 else 2, rating_sum=0 if i == 2 else 8 + i,
                verified_finishers=10 + i, discovery={"theme": "pine", "points": [[0, 0], [1, 1]]}))
        db.commit()
    return auth_client, auth_app, {}
