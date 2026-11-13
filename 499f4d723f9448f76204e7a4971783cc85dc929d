# Loading improvements — 30 October 2026

This pass reduces avoidable picture regeneration and overlaps some race preparation with an ordinary ticket request. It does not resolve the cold editor-practice shader and first-draw wait, and no physical-device performance claim is made.

## Changes

- Equipped header images use a conservative visual-source revision instead of the whole-client build ID. Backend, soundtrack, diagnostics and App navigation changes no longer force a recapture. Older generated identities fall back to the full build ID. A new revision requires a one-time cache refresh.
- A source- and engine-guarded, prepared simple Compact template accelerates a missing header image for stock parts and equipped paint or patterns. Other cars, fitted kits and missing or stale template identity use the existing procedural path. The estimate is 5,036,528 bytes, not measured peak process or GPU memory.
- Garage pictures have per-vehicle revisions for the car-specific prepared scene, stock picture and car configuration. Model builders and uncertain visual dependencies remain shared, because template provenance can affect more than one car. Legacy generated identities fall back to the shared fingerprint. Transitioning to the new revisions causes a one-time picture-cache refresh.
- For an ordinary online race, a required road-preparation worker can run while the ticket request is pending. Ticket issuance is not moved. Closing loading cancels the work; retries wait for retiring cancelled work. A save-time bake is shared only for the exact matching road disk key; unrelated bakes do not block the race.

Regenerate the normal client build identity when building: the existing generated identity is intentionally preserved, and the new visual revisions and guarded template fail closed until matching metadata is generated. The template's recorded fingerprint must match that integrated build; rebuilding it after relevant source changes remains necessary.

## Checks and limits

Headless checks: header revision key 14/0, Garage runtime key 4/0, focused ticket/road overlap 23/0, challenge flows 38/0, and App 141/0. Build-identity checks passed 18; Garage dependency-isolation checks passed 80. A six-car-adapted copy of the existing header native fixture passed 45/0 Compatibility; the unchanged older fixture reported two dropdown failures because it assumes seven cars. The native Garage preview pipeline passed 3/0 Compatibility. The retained race preparation test passed 1,076/0 before the final matching-save guard.

The template's structural and lifecycle comparison passed 12/0, and native appearance checks passed 9/0 in each of Compatibility and desktop Mobile. The images were within the unchanged appearance threshold but were not byte identical: Compatibility differed in 15 and 18 bytes, desktop Mobile in 88 and 7 bytes. Same-renderer procedural controls also varied. The actual App desktop Mobile startup check passed 25/0 with the template hit and zero wrong visible frames; its 21.39-second total shows that other startup and shader work remains. That diagnostic emitted an ObjectDB shutdown warning. An initial attempt stopped after a missing output-directory error; the corrected run used a fresh isolated profile. Windows sandbox runs also emitted a root-certificate-store diagnostic.

Sequential template prototype samples showed faster Compact preview readiness, but caches and driver state make them unsuitable as a controlled end-to-end speedup claim. No physical Android run, thermal or peak-memory assessment was performed.

## Rejected editor prototype and remaining work

An idle exact-road preparation prototype was removed. It evicted useful section caches in its first form; a disk-only revision preserved those caches, but the builder still had unbounded transient allocations and a width-update slowdown remained unresolved. Its investigation is retained in `tmp/editor-idle-investigation-20261030/`. Safe idle preparation needs a bounded builder and proof that editing remains responsive.

The older editor-loading test reports eight raw mesh-digest parity failures among 682 checks across four biomes. An isolated project and cache control reproduced the same failures in the same order; directly involved road/compiler/fixture sources match the restored files, but this is not a complete immutable snapshot of every task-start project file. These failures are not claimed as fixed. No live account, owner save, deployment, owner process or main Git index was modified.
