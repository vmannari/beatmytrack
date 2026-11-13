"""Exact release aggregates on isolated reporting storage, with honest coverage."""

from sqlalchemy import BigInteger, Float, case, cast, func, select

from .race_statistics_models import RaceStatisticsDay as Race
from .studio_analysis import DAY, interval
from .studio_platform_models import AnalysisDay, AnalysisState
from .track_models import now


def release_report(request, role, window, build_id, baseline, platform, device_model,
                   os_version, track_version_id, render_context_key):
    from .studio_metrics import quality_totals

    requested, (first, until) = interval(window)
    filters = {'build_id': build_id, 'baseline': baseline, 'platform': platform, 'device_model': device_model,
               'os_version': os_version, 'track_version_id': track_version_id, 'render_context_key': render_context_key}
    conditions = [Race.day >= first // DAY, Race.day < until // DAY]
    for key in ('platform', 'device_model', 'os_version', 'track_version_id', 'render_context_key'):
        if filters[key]:
            conditions.append(getattr(Race, key) == filters[key])
    with request.app.state.studio_reporting.snapshot(
        request.app.state.session_factory, request_id=request.state.request_id, window=(first, until)
    ) as (db, storage):
        state = db.get(AnalysisState, 1)
        builds = list(db.scalars(select(Race.build_id).where(*conditions)
                                .distinct().order_by(Race.build_id).limit(201)))
        option_fields = (Race.device_model, Race.os_version, Race.track_version_id, Race.render_context_key)
        options = db.execute(select(*option_fields).where(Race.day >= first // DAY, Race.day < until // DAY)
                             .distinct().order_by(*option_fields).limit(201)).all()

        def one(build):
            if not build:
                return None
            scope = [*conditions, Race.build_id == build]
            result = quality_totals(db, scope)
            result['build_id'] = build
            result['latest_package_at'] = db.scalar(select(func.max(Race.latest_received_at)).where(*scope))
            affected = [AnalysisDay.day >= first // DAY, AnalysisDay.day < until // DAY,
                        AnalysisDay.build_id == build, AnalysisDay.counters['quality_attempts'].as_integer() > 0]
            for key in ('platform', 'device_model', 'os_version'):
                if filters[key]:
                    affected.append(getattr(AnalysisDay, key) == filters[key])
            # Per-player days have no track or exact rendering-context grain.
            # An unavailable denominator must never be shown as zero users.
            reporting, slow = (None, None)
            if not track_version_id and not render_context_key:
                reporting, slow = db.execute(select(func.count(func.distinct(AnalysisDay.player_id)),
                    func.count(func.distinct(case((AnalysisDay.counters['quality_slow_frames'].as_integer() > 0,
                                                   AnalysisDay.player_id))))).where(*affected)).one()
                if not reporting:
                    reporting, slow = None, None
            result.update(reporting_players=reporting, affected_players=slow,
                          player_coverage='available' if reporting is not None else 'unavailable_for_selected_scope',
                          sample_sufficient=result['attempts'] >= 30 and result['frames'] >= 1000)
            return result

        candidate, control = one(build_id), one(baseline)
        segment_fields = (Race.platform, Race.device_model, Race.os_version, Race.render_context_key)
        frames = sum((cast(Race.frame_buckets[i].as_string(), BigInteger) for i in range(8)), start=0)
        slow_frames = sum((cast(Race.frame_buckets[i].as_string(), BigInteger) for i in range(5, 8)), start=0)
        candidate_frames = func.sum(case((Race.build_id == build_id, frames), else_=0))
        candidate_slow = func.sum(case((Race.build_id == build_id, slow_frames), else_=0))
        baseline_frames = func.sum(case(((Race.build_id == baseline) & bool(baseline), frames), else_=0))
        baseline_slow = func.sum(case(((Race.build_id == baseline) & bool(baseline), slow_frames), else_=0))
        segment_rows = db.execute(select(*segment_fields,
            func.sum(case((Race.build_id == build_id, Race.races), else_=0)),
            candidate_frames, candidate_slow, baseline_frames, baseline_slow)
            .where(*conditions, Race.build_id.in_([build_id, baseline]))
            .group_by(*segment_fields)
            .having(candidate_frames > 0)
            .order_by((cast(candidate_slow, Float) / func.nullif(candidate_frames, 0)).desc(),
                      candidate_frames.desc(), *segment_fields).limit(21)).all() if build_id else []
        segments = []
        for row in segment_rows[:20]:
            item = dict(zip(('platform', 'device_model', 'os_version', 'render_context_key', 'attempts',
                             'frames', 'slow_frames', 'baseline_frames', 'baseline_slow_frames'), row))
            item['slow_fraction'] = item['slow_frames'] / item['frames'] if item['frames'] else None
            item['baseline_slow_fraction'] = item['baseline_slow_frames'] / item['baseline_frames'] if item['baseline_frames'] else None
            item['slow_change'] = item['slow_fraction'] - item['baseline_slow_fraction'] if item['baseline_slow_fraction'] is not None else None
            item['sample_sufficient'] = item['frames'] >= 1000 and item['baseline_frames'] >= 1000
            segments.append(item)
        comparison = None
        if candidate and control and candidate['attempts'] and control['attempts']:
            comparison = {'completion_change': candidate['completion'] - control['completion'],
                          'slow_frame_change': candidate['slow_fraction'] - control['slow_fraction']
                          if candidate['slow_fraction'] is not None and control['slow_fraction'] is not None else None,
                          'sample_sufficient': candidate['sample_sufficient'] and control['sample_sufficient'],
                          'descriptive_only': True}
        return {'schema': 'bmt-studio-releases-v2', 'definition_version': 1, 'role': role, 'as_of': now(),
                'requested_since': requested[0], 'requested_until': requested[1],
                'since': first, 'until': until, 'filters': filters,
                'builds': builds[:200], 'builds_truncated': len(builds) > 200,
                'options': [dict(zip(('device_model', 'os_version', 'track_version_id', 'render_context_key'), r)) for r in options[:200]],
                'options_truncated': len(options) > 200,
                'candidate': candidate, 'baseline': control, 'comparison': comparison,
                'segments': segments, 'segments_truncated': len(segment_rows) > 20,
                'sample_policy': {'minimum_packages': 30, 'minimum_frames': 1000,
                                  'purpose': 'Exploratory sample warning, not a validated rollout or significance threshold.'},
                'source': {'reporting_storage': storage, 'processed_through': state.processed_through if state else None,
                           'collection_enabled': request.app.state.settings.client_quality_enabled},
                'coverage': 'Exact selected package/frame aggregates. Player counts use analysis-v1 build/device/OS days; unavailable at track/render-context grain. Comparisons remain descriptive; unselected device, track and player mix can differ.'}
