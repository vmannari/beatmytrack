import json
import deploy as r

code = '''import json
from sqlalchemy import select
from bmt_backend.app import create_app
from bmt_backend.discovery_models import TrackOfDay
from bmt_backend.track_models import TrackVersion,now,digest
a=create_app()
with a.state.session_factory() as session:
 day=session.get(TrackOfDay,now()//86400)
 result={'day':now()//86400,'present':day is not None,'test_drivers_enabled':a.state.settings.test_drivers_enabled}
 if day:
  version=session.get(TrackVersion,day.version_id)
  head=session.scalar(select(TrackVersion).where(TrackVersion.track_id==day.track_id,TrackVersion.state=='published').order_by(TrackVersion.number.desc()).limit(1))
  result.update(version_id=version.id,head_version_id=head.id,content_hash=head.content_hash,limits_digest=digest(day.lap_limits),include_artificial=bool(day.lap_limits.get('include_artificial')),variant=day.lap_limits.get('build_variant'),limits_present=bool(day.lap_limits),vehicles=list(version.manifest.get('vehicles',{})))
print('RELEASE_RESULT='+json.dumps(result))
a.state.verifier.close();a.state.engine.dispose()
'''
result = r.d.execute('daily-inspection-' + ('after' if r.s.get('catalog_passed') else 'before'), code, job=r.service.n['migrate'])
print(json.dumps(result), flush=True)
