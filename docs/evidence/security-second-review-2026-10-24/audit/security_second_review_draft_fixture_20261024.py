"""Retain owner assertions and await actual asynchronous draft enumeration."""
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
source=(ROOT/'game/tests/test_draft_privacy.gd').read_text(encoding='utf-8')
needle='\tshell.add_child(browser)\n\tcheck(browser.entries'
replacement=('\tshell.add_child(browser)\n'
             '\tvar deadline: int = Time.get_ticks_msec()+5000\n'
             '\twhile browser.scanning and Time.get_ticks_msec() < deadline: await process_frame\n'
             '\tcheck(not browser.scanning,"bounded draft enumeration completed")\n'
             '\tcheck(browser.entries')
assert source.count(needle)==1
source=source.replace(needle,replacement)
(ROOT/'docs/evidence/security-second-review-2026-10-24/test_draft_privacy_after_scan.gd').write_text(source,encoding='utf-8')
