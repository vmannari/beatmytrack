# Forklift 80 km/h checkpoint

The scoped source patch contains this follow-up and the minimal font fallback type correction that unblocked Garage startup. Original task-start files are in `before/`. Where concurrent backend/status context changed, `checkpoint__` files reconstruct that current context with only this task's changes reversed. Only the two Forklift fields in the backend fixture enter the patch; concurrent Electric/localization work is preserved.

Check with `git -c core.safecrlf=false -c core.whitespace=trailing-space,space-before-tab,cr-at-eol apply --check --whitespace=error-all --directory=build/forklift-80-kph/checkpoint-base docs/evidence/forklift-80-kph-2026-10-25/checkpoint.patch`.

The asset ZIP contains the 49 current Forklift native appearance PNGs, catalogue PNG and their import metadata at repository-relative paths. Apply source changes to the matching baseline, extract assets at the root and run pinned Import. SHA-256 inventories cover source files, assets and native screenshots. No index, HEAD, owner save or live backend was changed by checkpointing.
