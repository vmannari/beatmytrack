"""Keep only final native comparisons as permanent picture evidence."""
import shutil
from run_rally_lamp_style import OUT,WORK
source=(OUT/'source-gl_compatibility').resolve()
target=(WORK/'draft-previews/source-gl_compatibility').resolve()
assert source.is_relative_to(OUT.resolve()) and target.is_relative_to(WORK.resolve()) and not target.exists()
target.parent.mkdir(parents=True,exist_ok=True)
shutil.move(str(source),str(target))
print('RALLY_LAMP_STYLE_PREVIEW archived to disposable build output')
