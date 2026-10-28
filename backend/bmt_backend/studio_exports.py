"""Small, synchronous exports of the same bounded reporting queries as Studio."""

import csv
import io
import json
from datetime import datetime, timezone

from fastapi import HTTPException
from fastapi.responses import Response
from sqlalchemy import case, func, select

from .studio_analysis import DAY, behaviour, interval, population_conditions
from .studio_platform_models import AnalysisDay, AnalysisState
from .track_models import now


def utc_day(day):
    return datetime.fromtimestamp(day * DAY, timezone.utc).date().isoformat()


def dimensions(request, role, window, filters):
    """Preserve the original dimension CSV contract on the isolated reader."""
    _requested, (first, until) = interval(window)
    conditions = [AnalysisDay.day >= first // DAY, AnalysisDay.day < until // DAY,
                  *population_conditions(request.app.state.settings, AnalysisDay, filters['population'])]
    for field in ('build_id', 'platform', 'mode'):
        if filters[field]:
            conditions.append(getattr(AnalysisDay, field) == filters[field])
    with request.app.state.studio_reporting.snapshot(
        request.app.state.session_factory, request_id=request.state.request_id, window=(first, until)
    ) as (db, storage):
        state = db.get(AnalysisState, 1)
        fields = (AnalysisDay.day, AnalysisDay.build_id, AnalysisDay.platform)
        rows = db.execute(select(*fields,
            func.count(func.distinct(case((AnalysisDay.counters['active'].as_integer() > 0, AnalysisDay.player_id)))),
            func.coalesce(func.sum(AnalysisDay.counters['race_started'].as_integer()), 0))
            .where(*conditions).group_by(*fields).order_by(*fields).limit(1001)).all()
        if len(rows) > 1000:
            raise HTTPException(422, 'EXPORT_TOO_LARGE_NARROW_DATES')
        return {'as_of': now(), 'since': first, 'until': until, 'filters': filters,
                'coverage': {'processed_through': state.processed_through if state else None,
                             'reporting_storage': storage, 'collection_enabled': request.app.state.settings.telemetry_enabled},
                'rows': [dict(zip(('utc_day', 'build_id', 'platform', 'active_players', 'race_starts'),
                                 (utc_day(row[0]), *row[1:]))) for row in rows]}


def csv_report(data, kind, rows, fields, safe):
    """Repeat provenance per row so CSV sorting never separates it from facts."""
    metadata = {'report': kind, 'definition_version': 1, 'queried_at': data['as_of'],
                'since': data['since'], 'until_exclusive': data['until'], 'timezone': 'UTC',
                'processed_through': data.get('coverage', {}).get('processed_through'),
                'collection_enabled': data.get('coverage', {}).get('collection_enabled'),
                'projection_available': data.get('coverage', {}).get('available'),
                'scope': json.dumps(data.get('filters', {}), sort_keys=True, separators=(',', ':')),
                'query_semantics': 'new_query_at_download'}
    stream = io.StringIO(newline='')
    writer = csv.writer(stream)
    writer.writerow([*fields, *metadata])
    # Metadata-only reports still carry provenance when there are no eligible rows.
    for row in rows or [{}]:
        writer.writerow([safe('' if row.get(k) is None else row[k]) for k in fields]
                        + [safe('' if v is None else v) for v in metadata.values()])
    return Response(stream.getvalue(), media_type='text/csv', headers={
        'Content-Disposition': f'attachment; filename="observed-{kind}.csv"',
        'Cache-Control': 'no-store', 'X-BMT-Report-As-Of': str(data['as_of']),
        'X-BMT-Report-Watermark': str(metadata['processed_through'] or ''),
    })


def behaviour_export(request, role, window, filters, view, safe):
    if view == 'dimensions':
        data = dimensions(request, role, window, filters)
        return csv_report(data, view, data['rows'],
                          ['utc_day', 'build_id', 'platform', 'active_players', 'race_starts'], safe)
    data = behaviour(request=request, role=role, window=window, **filters, view=view)
    if view == 'activity':
        fields = ['utc_day', 'coverage_state', 'players', 'starts', 'finishes', 'accepted', 'foreground_ms']
        rows = [{**r, 'utc_day': utc_day(r['day'])} for r in data['daily']]
    elif view == 'retention':
        fields = ['cohort_day', 'cohort_players', 'followup_days', 'eligible', 'returned', 'mature', 'finalised']
        rows = [{'cohort_day': r['day'], 'cohort_players': r['players'], 'followup_days': day, **r['d'+str(day)]}
                for r in data['retention'] for day in (1, 7, 30)]
    elif view == 'journey':
        fields = ['step', 'players', 'eligible', 'truncated_profiles']
        rows = [{'step': r['name'], 'players': r['players'], 'eligible': data['first_race']['eligible'],
                 'truncated_profiles': data['first_race']['truncated_profiles']} for r in data['first_race']['steps']]
    else:
        fields = ['sessions', 'sessions_with_duration', 'foreground_ms']
        rows = [data['engagement']]
    return csv_report(data, view, rows, fields, safe)
