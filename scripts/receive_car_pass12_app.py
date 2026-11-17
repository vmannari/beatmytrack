"""CP203: isolated actual App receiving runs after native image imports."""
from qualify_car_pass12 import checked
for renderer in ('gl_compatibility','mobile'):
    checked('app-'+renderer,'res://tests/test_car_pass12_app.gd','--rendering-method',renderer)
print('CP2_APP_PASS both desktop renderers')
