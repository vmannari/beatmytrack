"""Pin the historical fit only in private practice preferences and record it."""
import json
from pathlib import Path
E = Path(__file__).resolve().parent
ROOT = E.parents[2]
project = ROOT/'build/tablet-loading-fixes-20261107/profiled-qualified/game'
probe = project/'diagnostics/tablet_phase_probe.gd'
data = probe.read_text()
old = '\trecords.records = app.records.records.duplicate(true)\n'
assert data.count(old)==1
data = data.replace(old,old+'''\tif Trace.options.get("fitted_compact",false):
\t\trecords.settings.selected_car = "compact"
\t\trecords.settings.simple_car_models = true
\t\trecords.settings.vehicle_customisation = records.settings.get("vehicle_customisation",{}).duplicate(true)
\t\trecords.settings.vehicle_customisation["compact"] = {"version":1,"aero":"biwing","body":"wide","hood":"scoop","rims":"turbine"}
\tvar saved_settings: Dictionary = app.records.settings.duplicate(true)
\tvar car_cache = load("res://vehicle/prepared_car_cache.gd")
\tif Trace.options.get("force_car_cache_miss",false): car_cache.entries.clear()
\tvar hits_before: int = car_cache.hits
''')
old = '\tvar viewport: Viewport = game.get("_render_viewport")\n'
assert data.count(old)==1
data = data.replace(old,'''\trow.configuration = {"vehicle":game.vehicle_id,"simple":game.car.simple_model,"parts":game.car.customisation.duplicate(true),"car_cache_hits":car_cache.hits-hits_before,"forced_car_miss":Trace.options.get("force_car_cache_miss",false)}
\tcheck(app.records.settings==saved_settings,"owner settings unchanged by private fit")
\tif Trace.options.get("fitted_compact",false):
\t\tcheck(game.vehicle_id=="compact" and game.car.simple_model and game.car.customisation==records.settings.vehicle_customisation.compact,"exact private fitted Compact configuration")
'''+old)
for kind in ['checkpoints','roads']:
    old = '"user://tablet-loading-fixes-20261107/cache/'+kind+'"'
    assert data.count(old)==1
    data = data.replace(old,'("user://tablet-loading-fixes-20261107/cache/"+str(Trace.options.get("cache_label","default"))+"/'+kind+'")')
probe.write_text(data,newline='\n')
race = project/'core/features/race.gd'
data = race.read_text()
old = '\tvar attempt_vehicle: String = app.rivalry.model.vehicle_id if not rivalry_issued.is_empty() and not rivalry_issued.has("challenge_code") else selected_vehicle\n'
assert data.count(old)==1
data = data.replace(old,old+'\tif TabletTrace.practice and TabletTrace.practice_records != null: attempt_vehicle = str(TabletTrace.practice_records.settings.selected_car)\n')
race.write_text(data,newline='\n')
(E/'configuration-correction.json').write_text(json.dumps({'initial_saved_vehicle':'kart','initial_saved_simple':True,'initial_saved_fit':'stock',
    'historical_vehicle':'compact','historical_fit':{'aero':'biwing','body':'wide','hood':'scoop','rims':'turbine'},
    'historical_whole_race_comparison_rejected':True,
    'correction':'Observer records actual car/fit/cache hits. Historical fitted Compact is pinned only in private practice records; selected global car and owner settings remain unchanged. Forced cold-car controls clear only the in-process rest-template cache before each test entry.'},indent=2)+'\n')
print('PRIVATE_FIT_PROBE_PREPARED')
