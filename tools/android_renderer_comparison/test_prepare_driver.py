"""Check that the actual archived probe is safely transformed or fails closed."""
import prepare

source = prepare.ORIGINAL_PROBE.read_text(encoding="utf-8")
updated = prepare.update_driver_start(source)
race = updated.split('func race(', 1)[1].split('func garage(', 1)[0]
assert race.index('while is_instance_valid(game) and not DriverStart.ready(') < race.index('game.driver = input')
assert race.index('game.driver = input') < race.index('begin("drive_"+label)')
for field in ('driver_takeover_tick', 'driver_takeover_countdown', 'driver_first_sample_tick',
              'launch_early_before_takeover', 'launch_result', 'launch_delay_until'):
    assert f'driving.{field} =' in race
assert 'if first_sample_tick < 0: first_sample_tick = game.sim.state.tick' in updated
try:
    prepare.update_driver_start(source.replace('\tgame.driver = input\n', '', 1))
except RuntimeError:
    pass
else:
    raise AssertionError('Builder must refuse an unexpected source shape')
print('PREPARE_DRIVER_TEST: pass')
