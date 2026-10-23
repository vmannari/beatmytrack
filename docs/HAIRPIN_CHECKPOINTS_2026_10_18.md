# Hairpin bypasses — 2026-10-18

The owner reports that some hairpins still allow shortcuts. Rules23 keeps the
ordinary 2 m recovery policy and 8 m spline candidates, but prevents an adjoining
road arm or its width transition from erasing a required hairpin. Star now uses
38 ordered gates in each direction, versus rules22's 34/35. Physics remains0.66.
This is a local implementation; matching client/API/worker rollout remains.

## Reproduction and policy

The owner's retained Star fixture reproduces nine accepted chords saving
15.38–36.68 m. They can remain close to some road surface throughout while
skipping the intended bend. A global road-neighbourhood test therefore cannot
distinguish these from ordinary recovery. The frozen task-start sources and
original accepted gate geometry are retained under the evidence directory.

Corner joins now expose their authored road half-width. The spline selector
identifies tight reversals from the join miter, prioritizes their corner complex,
and fits the inside span to interior road/kerb references with 0.5 m additional
slack. Expanding those references with an adjacent wider road would remove the
very turn being protected, so it no longer determines the required order or
inside span. Ordinary and outside spans retain their original recovery bounds.
Approach gates remain necessary even when a nearby apex is also selected.

This deliberately supersedes the old whole-circuit ±6–7 m and large
variable-width inner-profile acceptance assertions. Those constructed paths can
erase a nose between neighbouring road arms. The new controls cover thirteen
constant paved/kerb offsets through ±5.5 m in both directions, modest variable
width profiles, and two-metre recovery on ordinary road in both directions.
Large variable profiles must now warn and require a return. This is a tighter
inside-hairpin policy, not a promise that every former edge-offset path survives.

The local spatial notice projection, layer preference, prepared approach cells,
return-to-missed-gate behavior and absence of automatic time penalties remain.
Core references also contribute approach cells so valid drifting lines remain
quiet. Gate markers use the resulting accepted spans.

The trajectory verifier previously added 15 cm beyond every exported gate. That
could reopen a blocked inside join. Rules23 uses the complete client spans plus
0.1 mm numerical slack; older rules retain their previous tolerance. Historical
documents/replays and board identities are preserved. Contract upgrading and
Rivalry eligibility recognize rules23, and prepared caches are fenced by its key.

## Validation

Results and original command log paths are in
[`validation-logs.json`](evidence/hairpin-checkpoints-2026-10-18/validation-logs.json).
Final artifacts include
[`final-cuts.json`](evidence/hairpin-checkpoints-2026-10-18/final-cuts.json),
[`shortcut-sweep.json`](evidence/hairpin-checkpoints-2026-10-18/shortcut-sweep.json),
[`native-verifier.json`](evidence/hairpin-checkpoints-2026-10-18/native-verifier.json)
and both native renderer captures. Geometric lane/sweep checks are distinct from
the physical driving replay.

- Hairpin regression:65 assertions, nine blocked cuts, correct return and cache
  recovery, ordinary two-metre controls and paved/kerb paths in both directions.
- Physical Compact driving:five laps,47,712 ticks,zero collisions and zero
  checkpoint warnings. Quantized input replay reproduces exact state/lap results.
  The real sparse trajectory and canonical server diagnostic both accept it.
- Whole-circuit lane consistency62, forgiveness32 and five-lap edge202 pass;
  broad chord sweep across5,144 candidates in both directions. The sweep also
  retains3,005 beyond-recovery rejection controls. With more than1 m of sampled
  off-road travel, the largest accepted saving is3.493 m. Paved cornering remains:
  three chords per direction save22.88–29.25 m while staying entirely on sampled
  road/kerb cells. These are recorded in `paved_corners`, rather than described
  as rejected shortcuts. Requiring narrower paths through those overlapping
  paved bends would also reject the retained edge-driving controls. The old
  goal of rejecting every one-metre cut remains superseded.
- Ordered gates266, notices537, bridge exits2,527, rewind61 and all27 retained
  catalog centrelines pass. Catalog notice timing checks preserve quiet legal
  approaches and prompt blocked-cut notices; worst correct-layer delay remains
  6.277 m on Dust cloud, with Star at0 m in both directions;2,171 assertions pass.
- Backend contracts/native staging44, exact-span contract1 and existing
  lightweight proof/malformed transport7 tests pass. A first parameterized run
  was interrupted after its PostgreSQL cases repeatedly timed out. A bounded
  retry confirms the historical disposable fixture endpoint localhost:55439 is
  unavailable; SQLite contract cases and native checks pass. No PostgreSQL pass
  is claimed for this task.
- Native Compatibility and desktop Mobile captures drive the actual cut before
  displaying its return marker. Project import uses recovery mode to preserve
  the owner's running editor; the complete876-script parser passes.

Desktop headless gate preparation is roughly2.6–2.8 s in the recorded concurrent
test runs; retained preparation reuses the layout in tens/hundreds of microseconds.
These are local CPU measurements, not phone, GPU, full-load or FPS claims.

## Commands and retained attempts

Use pinned Godot4.7.2 through:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 TestScript -ScriptPath res://tests/test_hairpin_checkpoints.gd -CommandTimeoutSeconds 240
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 TestScript -ScriptPath res://tests/test_star_checkpoint_consistency.gd
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 TestScript -ScriptPath res://tests/test_star_checkpoint_shortcuts.gd -CommandTimeoutSeconds 240
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 TestScript -ScriptPath res://tests/test_checkpoint_notice_latency.gd -TestArgument --catalog -CommandTimeoutSeconds 240
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 TestScript -ScriptPath res://tests/export_hairpin_trajectories.gd -CommandTimeoutSeconds 240
$env:PYTHONPATH='backend'
& .tools/backend-secure-venv/Scripts/python.exe docs/evidence/hairpin-checkpoints-2026-10-18/verify_hairpins.py
```

The evidence export reruns actual rules22 and checks that it accepted five laps
of each reproduced shortcut. The Python check obtains current native geometry,
rejects each old shortcut proof and accepts current legal and real driving proofs.
Native capture adds `-Graphical -RenderingMethod gl_compatibility` or `mobile`;
the parser runs `res://tests/test_script_parse.gd`.

Initial attempts are not shipping results:corner priority alone left bypasses;
fitting all broad recovery references preserved them; overly tight apex slack
blocked real driving; removing neighbouring approach gates opened larger cuts.
The broad sweep caught that candidate, so those gates were restored. Keeping
width-expanded inside references still admitted21–24 m nearby-arm cuts; interior
references close them with the shared half-metre apex slack. An initial native
comparison also exposed the verifier-only15 cm allowance and led to the versioned
exact-span contract. Earlier passing22/37-gate candidate logs are not evidence
for the final38-gate geometry.

Early exploratory invocations of the old forgiveness test overwrote its historical
report location. The original38 lanes were actually rerun against frozen rules22
and the historical report restored from those results; the overwritten attempt
and regenerated report are retained here. All new diagnostics write this task's
evidence directory. The source-only task patch excludes concurrent native-track,
Garage, publication, Rivalry and other work; no commit/index operation is made.

Owner driving acceptance and matching rollout remain. This task performs no phone
attachment check/test, APK, live backend mutation, migration or deployment.
