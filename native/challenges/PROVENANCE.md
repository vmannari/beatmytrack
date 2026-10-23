# Challenge platform bridge

Original Beat my track Java/GDScript, created 2026-10-08. Uses the already pinned Godot 4.7.2 Android plugin API and Android SDK intents. No additional SDK, service, runtime dependency, generated media or third-party source was added.

The pinned `godot-lib.template_debug.aar` was inspected with the configured JDK's `javap`: `GodotPlugin` has no `onNewIntent` callback, while `GodotActivity.onNewIntent` updates its activity intent. The bridge consumes new intent objects on a 0.5-second presentation timer. This supports cold and resumed invitation entry without changing the generated activity or the simulation. Device behavior remains an acceptance check.

Android share behavior uses `ACTION_SEND`, `text/plain` and `Intent.createChooser`. Custom invitations use `beatmytrack://challenge/{code}`. Optional HTTPS filters come from the explicitly configured export host; production App Links require that host's association file and actual signing fingerprint.

2026-10-19 Rivalry results add `shareResults(requestId, png, text)`: `ACTION_SEND` with `image/png`, `EXTRA_STREAM`, `EXTRA_TEXT`, matching `ClipData` and temporary read permission. `RivalryShareProvider` is an original, private, read-only Android `ContentProvider` restricted to generated receipt names in the app cache. Its authority uses `${applicationId}.rivalry-share`; no public storage permission, AndroidX dependency or social-media SDK is added. `RivalryShareFiles` validates PNG bounds, writes unique staged files and retains at most six images of at most 4 MiB each, expiring older entries after 24 hours on the next share. The chooser lets the player select the receiving app/person and confirm delivery there; starting it never claims a message was sent. Legacy track/challenge text sharing remains unchanged. Actual compilation, host tests and device acceptance limits: [Rivalry social sharing](../../docs/RIVALRY_SOCIAL_SHARE_2026_10_19.md).

References checked during implementation:

- [Godot Android manifest export hooks](https://docs.godotengine.org/en/stable/classes/class_editorexportplugin.html)
- [Android App Links and website associations](https://developer.android.com/training/app-links/about)
- [Android sharing](https://developer.android.com/training/sharing/send)
- [Android ContentProvider API](https://developer.android.com/reference/android/content/ContentProvider)
- [Android manifest application-ID placeholders](https://developer.android.com/build/manage-manifests#inject_build_variables_into_the_manifest)

Menu previews reuse `TrackTile.scenery_texture`, the established original scenic art and actual route metadata. Their existing provenance remains in the project's illustrated/discovery menu documentation. No pasted reference image became a shipping asset.

2026-10-22: Track-link sharing now returns an immediate accepted/refused status and emits `track_share_failed(text)` if Android cannot launch the chooser after dispatch. The GDScript adapter accepts older void-returning bridges, copies the exact public link on refusal and ignores failures for a different pending payload. Windows track links additionally use the original local system-share bridge in `native/windows_share`; receiving apps retain all recipient/send confirmation. Actual verification and limits: [Track direct sharing](../../docs/TRACK_DIRECT_SHARE_2026_10_22.md).
