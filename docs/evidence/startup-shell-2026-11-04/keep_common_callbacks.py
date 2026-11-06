"""Keep startup service callbacks in the shell, independent of feature code."""
from pathlib import Path
import re
root = Path(__file__).resolve().parents[3]
before = (Path(__file__).resolve().parent/'before/game/core/app.gd').read_text(encoding='utf-8')
path = root/'game/core/app.gd'
shell = path.read_text(encoding='utf-8')
names = ['_remote_config_changed','_remote_menu_notice','_ad_blocking_changed',
         '_lifecycle_changed','_remember_publication_news','_acknowledge_publication_dialog','_dismiss_publication_notification']
for name in names:
    pattern = r'^func '+name+r'\([\s\S]*?(?=^func |^static func |\Z)'
    original = re.search(pattern,before,re.M).group()
    shell,count = re.subn(pattern,lambda _:original,shell,count=1,flags=re.M)
    assert count==1,name
    for module in (root/'game/core/features').glob('*.gd'):
        source = module.read_text(encoding='utf-8')
        source = re.sub(r'^static func '+name+r'\([\s\S]*?(?=^static func |\Z)','',source,flags=re.M)
        module.write_text(source,encoding='utf-8',newline='\n')
path.write_text(shell,encoding='utf-8',newline='\n')
