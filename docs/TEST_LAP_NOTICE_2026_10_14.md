# Saved creator-lap notice correction — 2026-10-14

Requirements: **FM02–FM04, R01, T01–T04, Q01**. The owner reports a dialog
with “Couldn't save your changes” above “Test lap saved on this device. Ready
to publish.”

The contradiction comes from `FaultDialog.presentation()`, which classified any
unrecognised message containing `saved` as a storage problem. The completed-test
success message was absent from its success cases. The exact message reproduces
the supplied screenshot through the real application's owned notice dialog.

`app._complete_draft_test()` emits that success message only after the local
recording/workflow save and `TrackLibrary.mark_tested()` succeed. In the current
local-draft publication workflow, the saved trajectory enables explicit Publish;
sign-in and server acceptance still occur when publishing. The older backend-master
sequence in `TRACK_LIFECYCLE.md` does not describe this current workflow; see
`STUDIO_LOCAL_DRAFTS_2026_10_12.md` and `test_local_draft_publication.gd`.

`game/ui/fault_dialog.gd` now presents this success as a checkmark, **Test lap
saved**, and **Ready to publish.** Storage classification requires a storage hint
or explicit failed-write wording. Mentioning already saved data cannot imply
that a write failed. Existing warning text, modal ownership, input isolation and
dismissal remain covered by the tests.

`game/tests/test_fault_dialog.gd` adds the exact reported success, real save
failures including partially saved results, non-write messages mentioning saved
data, actual rendered success controls and owned dismissal. This task changes
presentation only; it does not alter recording, publication or driving contracts.

Actual commands use `powershell -NoProfile -ExecutionPolicy Bypass -File
scripts/dev.ps1` and pinned **4.7.2.stable.official.ed1daf0bf**, with process-local
APPDATA under `build/test-lap-notice-*-userdata`. Live backend access is disabled
in the UI fixture; publication requests are counted mock responses in the
existing local-publication fixture.

| Arguments / check | Actual outcome |
| --- | --- |
| `-Action TestScript -ScriptPath res://tests/test_fault_dialog.gd -Graphical -TestArgument '--evidence=res://../docs/evidence/test-lap-notice-2026-10-14/before-ui'` before the runtime fix | 95 checks, 6 expected regression failures; exact contradictory dialog captured |
| Same fixture with evidence directory `gl_compatibility`, after the fix | 95 checks, zero failures, Compatibility / RTX3090 |
| Same fixed fixture with `-RenderingMethod mobile -RenderingDriver vulkan` and evidence directory `mobile` | 95 checks, zero failures, desktop Mobile/Vulkan / RTX3090 |
| `-Action TestScript -ScriptPath res://tests/test_local_draft_publication.gd` | 31 checks, zero failures; actual ordered creator lap completes in 2605 ticks, recording has 436 samples; restart retains readiness and only explicit Publish sends content |
| `git diff --check -- game/ui/fault_dialog.gd game/tests/test_fault_dialog.gd` | Pass |

Initial restricted engine startup failed on Windows certificate-store access;
the successful fixtures used approved normal Windows access with disposable
workspace saves. The first baseline shell also reported an unrelated profile
execution-policy warning before running the fixture. Assertions were retained.

Visually inspected [before](evidence/test-lap-notice-2026-10-14/before-ui/test-lap-saved-1280x720.png),
[Compatibility after](evidence/test-lap-notice-2026-10-14/gl_compatibility/test-lap-saved-1280x720.png)
and [Mobile/Vulkan after](evidence/test-lap-notice-2026-10-14/mobile/test-lap-saved-1280x720.png).
The real application notice is rendered over an isolated fixture menu; the
durable completed-lap behavior is checked by the separate publication fixture.
Logs and a task-only review patch/manifest are in the same evidence directory.
The patch uses saved pre-task files and excludes existing unrelated edits.

No physical-device test, APK export/install, live publication or deployment was
performed for this task; phone attachment was not checked. The owner's installed
phone build and saved files were not inspected. The corrected source needs to
be included in a subsequent phone build; owner/device confirmation remains open.
