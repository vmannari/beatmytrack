# Live PC recurrence, 2026-10-14

Matched the current project game PID 28388 (started 07:37:02 Helsinki) to `race-1791952908-28388-3977072610898.json`, written at 07:41:58. The capture is Pine/Compact, Compatibility, RTX 3090, track kit 191.

At tick 732 / 6.100 seconds of driving, the measured frame interval was **330.171 ms**, including **305.045 ms between render signals**. This is a wall-clock render boundary, not a GPU execution measurement. The preceding 64 frames cover 526.885 ms and have median interval 8.3665 ms; the subsequent 16 frames have maximum 10.742 ms. This was a single isolated stall.

Car finish preparation and installation are both true throughout the retained history. All recorded emitter masks remain unchanged. Condition saving contributes zero milliseconds; its count remains two across the event. Recorded cloud IO and recovery callbacks are zero; no editor worker, cloud operation or telemetry writer is active. Physics totals 22.378 ms and presentation 0.823 ms in the event; nested stage times overlap and must not be added together. These measurements place most of this stall inside the render boundary rather than the recorded game/save callbacks.

The last pre-stall render-context sample is at wall 9030.858 ms. The next sample at 9480.336 ms, after the stalled interval ending at 9478.332 ms, reports three first camera-frustum candidates: IDs 31 `BridgeUnderShadow` (bridge_shadow.gdshader), 32 `BridgeAsphalt` (bridge_road.gdshader), and 82 `BridgeSteelAndFascia` (StandardMaterial3D). This gives a concrete bridge-rendering/first-use lead. It **does not prove** those resources caused the stall: sampling occurs at 5 Hz, reports conservative candidates rather than actual GPU draws, and this inventory omits 20 meshes at its existing 128-item cap. The event itself references the older context with no new candidates. Compatibility pipeline counters are zero and cannot establish or exclude shader compilation. No native stack or GPU trace was recorded for this event.

Conclusion: the latest shorter freeze was captured and is predominantly a render-boundary stall. The previous finish-material preparation ran, so first car-finish activation does not explain this capture. First bridge material use is a candidate for controlled reproduction; the exact native/driver cause remains unconfirmed. No game process was restarted or terminated and no speculative rendering change was made.

The same PID has a separate Winter countdown capture `race-1791952650-28388-858657917712.json`: 133.319 ms interval, only 7.134 ms between render signals. It is a different timing pattern and should not be attributed to this Pine render stall.

Eight available rotating diagnostic files were copied here to preserve the live evidence; the other six belong to earlier processes and are not attributed to the current report.
