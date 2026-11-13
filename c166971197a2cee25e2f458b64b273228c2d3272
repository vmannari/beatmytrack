# Dedicated thumbnail studio experiment — 2026-11-03

Follow-up: the owner subsequently chose to keep the studio for the project's selected Compatibility renderer. See [the enabled integration and validation](THUMBNAIL_STUDIO_ENABLED_2026_11_03.md). The decision and source-restoration checks below describe the earlier experiment; its historical summarizer assumes that restored source state.

Decision: **do not ship this candidate**. The first Compatibility batch improved substantially, but the benefit did not persist across renderers and later batches. Production sources were restored byte for byte to the task-start snapshots. The prototype remains only in test fixtures, with raw captures and measurements retained.

## Measured result

Time to publish all five uncached customized car pictures through the real asynchronous preview service:

| Desktop renderer / batch | Existing workshop | Dedicated studio | Change |
| --- | ---: | ---: | ---: |
| Compatibility, first batch in process | 35.143 s | 19.174 s | 45.4% faster |
| Compatibility, median of next two uncached batches | 1.384 s | 1.290 s | 6.8% faster |
| Mobile, first batch in process | 38.855 s | 35.581 s | 8.4% faster |
| Mobile, median of next two uncached batches | 26.192 s | 26.304 s | 0.4% slower |

Including completion of all PNG writes, later Compatibility batches went from 1.641 to 1.687 s (2.8% slower); later Mobile batches went from 26.361 to 26.624 s (1.0% slower). The data does not establish a repeatable general loading improvement sufficient to replace the workshop pictures. The full car and saved appearance still have to be prepared; this experiment does not attribute the remaining time to a specific internal phase.

The candidate uses one viewport instead of three, with 1,048,576 total viewport pixels instead of 1,343,488. The conservative scene resource estimates fall from 33.73–41.14 MB to 4.96–12.37 MB across the five cars (approximately 70–85% less). These are referenced scene resources, **not incremental RAM, GPU allocation, process RSS or phone PSS**; the main Garage may already share resources.

The visual cost is losing the workshop, planar reflections and real contact shadows in favor of a curved plain background, simple platform and soft static contact shadow. The final prototype retains the exact car, livery, fitted parts and condition; its lighting is visibly simpler. See the matched native [workshop capture](evidence/thumbnail-studio-2026-11-03/measure-compat-original/original-compact.png) and [candidate capture](evidence/thumbnail-studio-2026-11-03/measure-compat-studio/studio-compact.png). All five cars were captured under both desktop renderers: twenty final comparison PNGs.

## Method and limits

The experiment used the actual `GaragePreviewCache` scheduling, async disk-read/PNG-write paths and bounded overlap. Each measured batch requests all five current cars with private fresh disk-cache directories, body color `32b5d7`, `offset_gt` livery, an alternate aero part where available, and dirt 0.12. Both renderers retain the original 2048×512 main capture, 4× MSAA, camera/framing and capture settling. Only the studio scene changes. Candidate lighting uses the existing showroom glass treatment and Garage lights with adjusted ambient/key intensity; no workshop or planar reflection views are built.

Four separate native processes supplied the final comparison, one strategy per process, three batches per process. Order was original then studio for Compatibility, studio then original for desktop Mobile. One first-use sample and two later samples per strategy are insufficient for a statistical or cold-driver claim. OS/driver caches were not cleared. These are shared Windows desktop results, **not phone results or measured game-startup savings**. Garage work was already deferred from startup in the earlier change.

The four final runs passed **296 checks, zero failures**, including exact saved livery/kit metadata, actual body material color, condition, bounded viewport counts, five delivered pictures and completed writes. Receipt hashes record stable capture/car sources during each run; concurrent `game/core/build_identity.gd` changed during the last Mobile control. The whole repository was not frozen. Logs retain the Windows certificate-store environment error; there are no script/shader failures in these four runs.

Exploratory captures and timings remain separate. Early candidates had a reversed floor winding, banded cove normals and an unsuitable shadow falloff; these were corrected before the four final measurements. `batch-compat-studio.log` retains an initial mixed-indentation parse failure, corrected in subsequent runs. None of those measurements enter the table above.

## Retained artifacts and reproduction

Final raw runs are under `docs/evidence/thumbnail-studio-2026-11-03/measure-{compat,mobile}-{original,studio}/`, with adjacent logs and receipts. [summary.json](evidence/thumbnail-studio-2026-11-03/summary.json) is derived by `summarize.py`. `as-measured/` preserves the exact temporary service hook, candidate, shader and benchmark used for those four runs.

After rejecting the change, the candidate and experimental service snapshot were moved into `game/tests/fixtures/thumbnail_studio_*`; the profiler now references those fixtures. Existing export settings exclude `tests/*`. An additional `archived-repro --batch --quick` native run validates both archived strategies after this move: **56 checks, zero failures**. It is a reproduction check, excluded from the final timing comparison.

From the workspace root:

```powershell
python docs/evidence/thumbnail-studio-2026-11-03/run_check.py repeat-compat-original --batch --only-original
python docs/evidence/thumbnail-studio-2026-11-03/run_check.py repeat-compat-studio --batch --only-studio
python docs/evidence/thumbnail-studio-2026-11-03/run_check.py repeat-mobile-studio --renderer mobile --batch --only-studio
python docs/evidence/thumbnail-studio-2026-11-03/run_check.py repeat-mobile-original --renderer mobile --batch --only-original
python docs/evidence/thumbnail-studio-2026-11-03/summarize.py
python docs/evidence/thumbnail-studio-2026-11-03/checkpoint.py
```

The runner uses the pinned Godot 4.7.2 console executable through `scripts/run_no_crash_dialog.py`, isolated APPDATA, disabled API URL and a bounded process wait. Production preview cache/renderer, Garage page/preloader, preview bake/check and build-identity scripts match their task-start snapshots exactly. Cache identities, existing images, full Garage and approved loading ghosts remain unchanged. The task-only patch contains diagnostics and documentation only, with forward/reverse/content verification in an isolated build directory and no main-index write.

No device query/test, APK/export, backend/live mutation, owner save/process change or deployment occurred. Concurrent work was preserved.
