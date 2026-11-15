# Garage triangle inventory — 2026-11-14

GTI01: read-only count of the current prepared workshop, native stock Garage cars and source objects before material batching. No production geometry, quality, appearance, cache or handling source is changed.

| Workshop component | Master triangles |
| --- | ---: |
| Spare-wheel rack, including wheels | 28,840 |
| Workbench and tools | 22,431 |
| Plant, planter and soil | 14,739 |
| Trophy display wall | 11,800 |
| Tool storage | 10,964 |
| Compressor | 9,827 |
| Record station, speakers, vinyl and 14 sleeves | 8,202 |
| Architecture, roof and shared fixtures | 9,728 |
| Drain | 3,904 |
| Other props | 8,360 |
| **Prepared workshop total** | **128,795** |

The total covers 108 mesh instances. The rack and workbench contribute 51,271 triangles, 39.81% of the room. The previously recorded original workshop was 254,927 triangles; the current total is 49.48% lower.

The five-batch physical platform contains **5,280 triangles**. Its six contact-shadow quads add 12, reconciling the earlier 5,292 count that included those quads. The main floor adds two. This gives about **134,089 environment triangles** before the car, for a four-wheel vehicle with the default empty award wall and record collection. Record/achievement contents can vary with local settings.

| Current stock editable Garage car | Master triangles |
| --- | ---: |
| Rally | 19,074 |
| Volt | 19,826 |
| Hover | 22,068 |
| Kart | 24,223 |
| Forklift | 26,472 |
| Challenger | 38,612 |

These are stored mesh counts, not measured GPU frame totals. LOD selection, cutaway/visibility and culling reduce rendered geometry; the two reflection views submit additional room/car work. Equipped kits and earned awards change totals. Triangle counts alone do not attribute the remaining first-load delay.

The audit counts source parts **after the existing cleanup**, before shared-material batching, in an owned native Compatibility process. A memory-only hook observes `_batch`; the source files on disk are unchanged. The rebuilt source workshop equals the published workshop at 128,795 triangles, and all grouped parts plus the independently animated vinyl/sleeves sum exactly to that value. An initial CRLF signature assertion was corrected; two intermediate probes counted the cached room but did not reach source batching, so they are excluded from the object breakdown. The final probe explicitly clears only its process-local prepared scene reference. No existing assertion was relaxed.

Actual command:

```powershell
python scripts/run_garage_fast_entry.py triangle-inventory-final --script res://../build/garage-triangle-audit-2026-11-14/inventory.gd
```

The pinned Godot 4.7.2 launch is wrapped by `run_no_crash_dialog.py`, with disposable offline storage. It exits 0 with no script/native errors and no changes to the runner's watched production inputs. [Counts and verification](evidence/garage-triangles-2026-11-14/report.json), [exact command](evidence/garage-triangles-2026-11-14/run.json), and the two small probe source transcripts are retained in that evidence directory.

No physical-device query/test, export, backend operation, owner-save/process action or index staging/commit. Build retention cleanup is applied; no task pin is created.
