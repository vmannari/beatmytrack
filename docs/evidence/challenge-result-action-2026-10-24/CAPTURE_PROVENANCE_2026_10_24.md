# Desktop capture provenance correction

During the later challenge race-flow fix, `test_challenge_result_action.gd` ignored
the supplied `--evidence` argument because it had no argument parser. Its graphical
run overwrote the six `ui/Windows-gl_compatibility-*.png` files in this directory.
Those current files show the **later fix**, with the extra Continue challenge
button removed; they do not reproduce the original screenshots identified by this
directory's unchanged `report.json` capture hashes. The original six desktop PNGs
were not backed up and their exact original bytes could not be recovered.

The later captures are copied to
`../challenge-race-flows-2026-10-24/ui/actions/`, and the test now defaults to that
destination. Original Mobile screenshots, recorded hashes, source snapshots and
test logs in this directory were retained. No player data or runtime source was
overwritten by this evidence-output mistake.
