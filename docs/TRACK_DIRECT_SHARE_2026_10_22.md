# Direct track-link sharing — 2026-10-22

TDS01: The observed “Track link copied” notice is the non-Android fallback in
`ChallengeLinks.share_track`. Android already had an `ACTION_SEND` chooser; the
Windows client had no native track sharing. Track links now also use Windows'
system share UI, attached to the actual game HWND. The receiving app gets the
exact track title/text and immutable link; HTTP(S) links additionally have the
Windows web-link format. The player chooses the receiving app/person and confirms
delivery there. Starting or cancelling sharing never claims a message was sent.

TDS02: Retain the clipboard fallback when native sharing is unavailable or
immediately refused. Android now reports immediate refusal and asynchronous
launch failure instead of silently returning. The adapter accepts existing
void-returning Android bridges, ignores failure for a different pending payload
and copies the failed payload once with a clear fallback notice. Free Race,
publication banners and Trackside all retain their existing shared action and
exact track-version identities. Challenge and Rivalry image flows remain intact.

TDS03: The original Windows adapter reuses the existing Godot C++ bindings and
installed Windows SDK/toolchains. A small C ABI separates the existing MinGW Godot
wrapper from Microsoft's WinRT implementation. Its content-addressed runtime is
loaded only beside the wrapper, remains mapped for safe late COM releases, and
has only Windows system imports. Each adapter owns one revocable data callback.
The native boundary bounds the strings and checks that the HWND belongs to the
calling process/thread. The descriptor records the runtime DLL dependency for a
future Windows export; the existing Android export excludes the Windows folder.

Changed files: `game/platform/challenge_links.gd`, the sharing-failure connection
in `game/core/app.gd`, `native/challenges/src/org/beatmytrack/challenges/BmtChallenges.java`,
`native/challenges/PROVENANCE.md`, new `native/windows_share/share_extension.cpp`,
`share_runtime.cpp` and `PROVENANCE.md`, new `scripts/build_windows_share.ps1`, the
`BuildWindowsShare` action in `scripts/dev.ps1`, new
`game/platform/windows/share.gdextension`/UID, two referenced DLLs and
`SHARE-NOTICE.txt`, the Windows temporary-DLL ignore rule, new
`game/tests/test_track_direct_share.gd`/UID, `scripts/test_track_link_bridge.py`,
this receipt and the project status/instruction notes. The [task-only source
patch](evidence/track-direct-share-2026-10-22/task-only.patch) uses task-start
working files plus preserved concurrent changes as its base. Concurrent account,
advertising, histogram and achievement-header work is excluded from this patch.
[Source and binary fingerprints](evidence/track-direct-share-2026-10-22/source-hashes.json)
identify the accompanying native artifacts.

R01 commands use pinned Godot `4.7.2.stable.official.ed1daf0bf` through
`powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1`, isolated
`APPDATA` folders below `build/track-direct-share`, and fixture backend data:

- `-Action BuildWindowsShare`: both native DLLs build successfully; the runtime
  uses Visual C++ 14.43 / Windows SDK 10.0.22621, the wrapper the existing MinGW
  compiler and Godot bindings revision `e83fd0904c13356ed1d4c3d09f8bb9132bdc6b77`.
- `python scripts/test_track_link_bridge.py --android-compile`: 32 Java
  link/text-sharing checks and 34 existing Rivalry/provider checks pass. All
  production Java classes compile against Android 36 and the pinned Godot AAR,
  release 17, without exporting an APK.
- `-Action TestScript -ScriptPath res://tests/test_track_direct_share.gd`:
  10 headless checks pass; with `-Graphical -RenderingMethod gl_compatibility`,
  16 pass. Covers native priority, exact HWND/title/text/link, legacy Android,
  refusal, clipboard handoff and stale/duplicate asynchronous failures.
- The focused native fixture with `--native-share-click`, launched by the
  retained capture harness: an actual OS mouse click on only its Share button
  produces `WINDOWS_NATIVE_DATA_REQUESTS: 1`; all 3 native checks pass. No receiving
  app/person is selected. This proves Windows accepted and requested the data;
  it does not prove delivery through WhatsApp.
- Existing `test_publication_share.gd`: 45 headless and 45 Compatibility checks
  pass, including banner, newspaper and Free Race share actions, incoming exact
  versions, navigation and account fences. `test_app.gd`: 141 pass.
  `test_rivalry_share.gd`: 338 headless checks pass.
- `-Action Import` and final `test_script_parse.gd` pass; the final parser count is
  927 scripts, zero failures (see the retained parser log). `git diff --check` passes for task sources.
- `dumpbin /DEPENDENTS` confirms the Windows runtime imports Windows system DLLs.

Initial corrections are retained candidly: the first native compile needed an
explicit `winrt::Windows` namespace and a generated header for the DLL filename
instead of shell-escaped quotes. The first sandboxed import could not read the
Windows certificate store; normal host-access import passed. Programmatic native
trials lost foreground focus, and two failed the unchanged two-second data-request
assertion. The actual-click fixture passes that assertion. A captured freed Button
caused one fixture deadline error; a `WeakRef` corrects it. Desktop clipboard
contention interrupted later direct-clipboard trials; final adapter checks inject
only the clipboard handoff and keep all exact-payload assertions. Earlier actual
clipboard integration runs also passed 16 checks. No runtime or test invariant was
removed to hide a failure.

G01: inspected [Free Race share action](evidence/track-direct-share-2026-10-22/gl_compatibility/shared-free-race-detail.png),
[publication banner](evidence/track-direct-share-2026-10-22/gl_compatibility/publication-banner-share.png)
and [Trackside](evidence/track-direct-share-2026-10-22/gl_compatibility/publication-news.png).
External chooser capture attempts did not retain the chooser in the foreground;
unrelated/blank captures were discarded and are not presented as native UI proof.

Q01: restart the desktop game to load the new extension. The Android error-reporting
change requires a matching future client build. Owner acceptance of the system
chooser and actual WhatsApp/other-app recipient workflow remains. No phone
attachment check or physical-device/WhatsApp test, APK export/install, social
message, live backend/account mutation or deployment was performed.

Platform references: [Microsoft desktop share interop](https://learn.microsoft.com/en-us/windows/apps/develop/ui/display-ui-objects#for-classes-that-implement-idatatransfermanagerinterop),
[Godot HWND access](https://docs.godotengine.org/en/4.6/classes/class_displayserver.html#class-displayserver-method-window-get-native-handle)
and [Android sharing](https://developer.android.com/training/sharing/send).
