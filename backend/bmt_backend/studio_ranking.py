"""Bounded ranking operations metadata; GETs never run settlement or repairs."""

from uuid import UUID

from fastapi import APIRouter, HTTPException, Request
from sqlalchemy import select

from .admin import Access
from .admin_models import AdminAudit
from .middleware import ParsedJSONRoute
from .studio_queries import read_snapshot
from .track_models import OperationState, now
from .world_ranking import WEEK, Correct, correction_car
from .world_ranking_car_models import CarCircuit
from .world_ranking_models import (
    Circuit,
    RankingBranch,
    RankingControl,
    RankingCorrection,
    RankingPlayer,
    RankingSnapshot,
)

router = APIRouter(route_class=ParsedJSONRoute, tags=['Studio ranking operations'])
HEARTBEAT_ID = 'studio-ranking-worker'


def ranking_status(db, settings):
    at = now()
    control = db.get(RankingControl, 1)
    launch = control.launch_week if control else settings.world_ranking_launch_week
    result = {'as_of': at, 'launch_week': launch, 'enabled': bool(launch), 'pending': False,
              'state': 'disabled' if not launch else 'scheduled' if launch > at else 'awaiting_first_settlement',
              'worker_last_seen_at': None, 'progress_at': None, 'retrying': False, 'oldest_at': None}
    heartbeat = db.get(OperationState, HEARTBEAT_ID)
    if heartbeat:
        result.update(worker_last_seen_at=heartbeat.updated_at, progress_at=heartbeat.details.get('progress_at'),
                      worker_error_kind=heartbeat.details.get('error_kind', ''))
    if not control:
        result.update(pending=bool(launch and at >= launch + WEEK),
                      oldest_at=launch + WEEK if launch else None)
        return result
    branch = db.get(RankingBranch, control.running_branch)
    published = db.get(RankingSnapshot, control.published_id) if control.published_id else None
    if not branch:
        result.update(state='branch_unavailable', pending=True)
        return result
    pending = branch.phase != 'idle' or branch.mode == 'rebuild' or at >= branch.next_week + WEEK
    result.update(state='scheduled' if launch > at else 'retrying' if branch.failure else 'settling' if pending else 'ready',
                  pending=pending, oldest_at=None if branch.mode == 'rebuild' else branch.next_week + WEEK,
                  branch_id=branch.id, published_snapshot=control.published_id,
                  published_at=published.published_at if published else None,
                  published_week=published.week_start if published else None,
                  published_field=published.field_size if published else None,
                  published_ranked=published.ranked_count if published else None,
                  phase=branch.phase, mode=branch.mode, week_start=branch.next_week,
                  processed_through=branch.cursor, part=branch.part, working_snapshot=branch.snapshot_id,
                  retrying=bool(branch.failure), error_kind=branch.failure.split(':', 1)[0] if branch.failure else '')
    return result


def record_worker_heartbeat(factory, *, worked=False, error_kind=''):
    """Called at most once per 15s between batches on the existing one-connection worker."""
    with factory() as db:
        at = now()
        row = db.get(OperationState, HEARTBEAT_ID)
        control = db.get(RankingControl, 1)
        branch = db.get(RankingBranch, control.running_branch) if control else None
        progress = [branch.id, branch.phase, branch.cursor, branch.part, branch.snapshot_id] if branch else None
        prior = row.details if row else {}
        details = {'progress': progress, 'progress_at': at if progress != prior.get('progress') else prior.get('progress_at'),
                   'worked': bool(worked), 'error_kind': error_kind[:80]}
        if row:
            row.updated_at, row.details = at, details
        else:
            db.add(OperationState(id=HEARTBEAT_ID, updated_at=at, details=details))
        db.commit()


@router.get('/v1/admin/studio/ranking')
def inspect_ranking(request: Request, role: Access):
    with request.app.state.session_factory() as db:
        read_snapshot(db)
        data = ranking_status(db, request.app.state.settings)
        circuits = list(db.scalars(select(Circuit).order_by(Circuit.week_start.desc()).limit(27)))
        cars = {}
        for event in db.scalars(select(CarCircuit).where(CarCircuit.circuit_id.in_([c.id for c in circuits[:26]]))):
            cars.setdefault(event.circuit_id, []).append({"vehicle_id": event.vehicle_id,
                "participation_bps": event.participation_bps, "weights_locked": event.weights_locked,
                "population_snapshot": event.population_snapshot, "tracks": event.tracks})
        history = list(db.execute(select(RankingCorrection, AdminAudit.actor, RankingPlayer.player_id).select_from(RankingCorrection)
            .outerjoin(AdminAudit, AdminAudit.command_id == RankingCorrection.command_id)
            .outerjoin(RankingPlayer, RankingPlayer.key == RankingCorrection.player_key)
            .where(RankingCorrection.circuit_id.in_([c.id for c in circuits[:26]]))
            .order_by(RankingCorrection.created_at.desc(), RankingCorrection.command_id).limit(26))) if circuits else []
        data.update(circuits=[{'id': c.id, 'week_start': c.week_start, 'original_snapshot': c.original_snapshot,
                               'policy': c.policy, 'cars': cars.get(c.id, []),
                               'closed': c.week_start + WEEK <= data['as_of'], 'tracks': c.tracks} for c in circuits[:26]],
                    history=[{'command_id': r.command_id, 'circuit_id': r.circuit_id, 'kind': 'void_week' if not r.player_key else 'exclude_player',
                              'actor': actor or r.actor, 'player_id': player, 'reason': r.reason, 'vehicle_id': r.vehicle_id,
                              'created_at': r.created_at} for r, actor, player in history[:25]],
                    history_truncated=len(history)>25, circuits_truncated=len(circuits)>26,
                    history_scope='Latest 25 corrections within the 26 latest circuits.', role=role)
        return data


@router.post('/v1/admin/studio/ranking/correction-preview')
def preview_correction(body: Correct, request: Request, role: Access):
    """Advisory only. The existing command rechecks its locked snapshot at commit."""
    if role != 'owner':
        raise HTTPException(403, 'OWNER_REQUIRED')
    try:
        UUID(body.command_id)
        if body.player_id:
            UUID(body.player_id)
    except ValueError:
        raise HTTPException(422, 'INVALID_CORRECTION_IDENTIFIER') from None
    if bool(body.player_id) == body.void_week or len(body.reason.strip()) < 8:
        raise HTTPException(422, 'CHOOSE_PLAYER_OR_VOID_WEEK')
    with request.app.state.session_factory() as db:
        read_snapshot(db)
        control = db.get(RankingControl, 1)
        if not control or (control.published_id or 0) != body.expected_snapshot:
            raise HTTPException(409, 'RANKING_CHANGED_REFRESH_REQUIRED')
        branch = db.get(RankingBranch, control.running_branch)
        if not branch or branch.phase != 'idle' or branch.mode == 'rebuild':
            raise HTTPException(409, 'RANKING_SETTLEMENT_BUSY_RETRY')
        circuit = db.get(Circuit, body.circuit_id)
        current = db.get(RankingSnapshot, control.published_id) if control.published_id else None
        if circuit is None or circuit.week_start + WEEK > now():
            raise HTTPException(422, 'CIRCUIT_NOT_CLOSED')
        correction_car(db, circuit, body.vehicle_id)
        unpublished_void = body.void_week and circuit.original_snapshot is None
        if not unpublished_void and (current is None or circuit.week_start > current.week_start or circuit.original_snapshot is None):
            raise HTTPException(422, 'CIRCUIT_NOT_PUBLISHED')
        if body.player_id and db.scalar(select(RankingPlayer.key).where(RankingPlayer.player_id == body.player_id)) is None:
            raise HTTPException(404, 'PLAYER_NOT_FOUND')
        scope = body.vehicle_id or 'all cars in the week'
        return {'command': body.model_dump(), 'previous_snapshot': control.published_id,
                'effect': f'Queue a void for {scope}.' if unpublished_void else f'Rebuild ranking generations from launch through the published week for the correction to {scope}. The previous publication remains visible until atomic replacement.',
                'kind': 'void_week' if body.void_week else 'exclude_player', 'reason': body.reason.strip()}
