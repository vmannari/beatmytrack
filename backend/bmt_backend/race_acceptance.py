"""One bounded read of the facts shared by a single race's acceptance writers."""
from dataclasses import dataclass

from sqlalchemy import and_, select

from .challenge_models import ChallengeTicket
from .economy_models import CoinReward, CoinWallet
from .rivalry_models import RivalryTicket
from .track_models import Board, LapPersonalBest, PersonalBest, Track, TrackVersion


@dataclass
class Acceptance:
    """Transaction-local references, loaded after the worker's Player/Run locks.

    Competition rows are still locked and checked by their existing writers.
    Previous PB ticks are scalars: trigger-updated ORM PBs must not be cached.
    Missing ticket/receipt rows are retained explicitly, unlike Session.get().
    """
    board: Board
    version: TrackVersion
    track: Track
    rivalry: RivalryTicket | None
    challenge: ChallengeTicket | None
    reward: CoinReward | None
    wallet: CoinWallet | None
    previous: tuple[int, int]

    @classmethod
    def load(cls, session, run):
        row = session.execute(select(Board, TrackVersion, Track, RivalryTicket, ChallengeTicket,
            CoinReward, CoinWallet, PersonalBest.time_ticks, LapPersonalBest.time_ticks)
            .select_from(Board)
            .join(TrackVersion, TrackVersion.id == Board.version_id)
            .join(Track, Track.id == TrackVersion.track_id)
            .outerjoin(RivalryTicket, RivalryTicket.ticket_id == run.ticket_id)
            .outerjoin(ChallengeTicket, ChallengeTicket.ticket_id == run.ticket_id)
            .outerjoin(CoinReward, CoinReward.run_id == run.id)
            .outerjoin(CoinWallet, CoinWallet.player_id == run.player_id)
            .outerjoin(PersonalBest, and_(PersonalBest.board_id == Board.id, PersonalBest.player_id == run.player_id))
            .outerjoin(LapPersonalBest, and_(LapPersonalBest.board_id == Board.id, LapPersonalBest.player_id == run.player_id))
            .where(Board.id == run.board_id)).one()
        return cls(*row[:7], (row[7] or 0, row[8] or 0))
