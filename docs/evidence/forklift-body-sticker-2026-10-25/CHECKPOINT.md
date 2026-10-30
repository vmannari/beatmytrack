# Forklift body and sticker checkpoint

`checkpoint.patch` contains only the solid-panel/rear-sticker follow-up, its native regression, the saved original model needed by that regression, documentation and status entries. The base is built from `before/`, using `checkpoint__` snapshots when concurrent document context changed after task start. The original task-start copies remain intact.

Check with `git -c core.safecrlf=false -c core.whitespace=trailing-space,space-before-tab,cr-at-eol apply --check --whitespace=error-all --directory=build/forklift-body-sticker/checkpoint-base docs/evidence/forklift-body-sticker-2026-10-25/checkpoint.patch`.

`checkpoint-assets.zip` has repository-relative paths for the 49 current Forklift appearance PNGs, native catalogue PNG and import metadata. After applying the source patch to the matching baseline, extract the assets at the repository root and use the pinned Import command. Source, asset and native-image SHA-256 inventories accompany the payload. The checkpoint changes no index, branch, HEAD, live backend or owner save.
