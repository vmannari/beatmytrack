"""CP303: isolated actual App receiving runs after native image imports."""
from qualify_car_pass10 import checked
for renderer in ('gl_compatibility','mobile'):
    checked('app-'+renderer,'res://tests/test_car_pass10_app.gd','--rendering-method',renderer)
print('CP3_APP_PASS both desktop renderers')
