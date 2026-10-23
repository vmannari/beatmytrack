# Challenge platform bridge

Original Beat my track Java/GDScript, created 2026-10-08. Uses the already pinned Godot 4.7.2 Android plugin API and Android SDK intents. No additional SDK, service, runtime dependency, generated media or third-party source was added.

The pinned `godot-lib.template_debug.aar` was inspected with the configured JDK's `javap`: `GodotPlugin` has no `onNewIntent` callback, while `GodotActivity.onNewIntent` updates its activity intent. The bridge consumes new intent objects on a 0.5-second presentation timer. This supports cold and resumed invitation entry without changing the generated activity or the simulation. Device behavior remains an acceptance check.

Android share behavior uses `ACTION_SEND`, `text/plain` and `Intent.createChooser`. Custom invitations use `beatmytrack://challenge/{code}`. Optional HTTPS filters come from the explicitly configured export host; production App Links require that host's association file and actual signing fingerprint.

References checked during implementation:

- [Godot Android manifest export hooks](https://docs.godotengine.org/en/stable/classes/class_editorexportplugin.html)
- [Android App Links and website associations](https://developer.android.com/training/app-links/about)
- [Android sharing](https://developer.android.com/training/sharing/send)

Menu previews reuse `TrackTile.scenery_texture`, the established original scenic art and actual route metadata. Their existing provenance remains in the project's illustrated/discovery menu documentation. No pasted reference image became a shipping asset.
