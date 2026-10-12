# Native Google sign-in

Original Beat my track Android/Godot bridge. Owner requested phone login without opening a browser on 2026-10-09, authorizing the native identity integration. No third-party Godot plugin is vendored.

Pinned Android dependencies: AndroidX Credential Manager and its Play Services provider 1.5.0 (Apache-2.0), Google Identity googleid 1.1.1 (Google SDK terms apply). Resolved by Gradle from existing Maven repositories; generated binaries and caches stay outside Git. No runtime AI or additional identity provider.

Implementation reference: https://developer.android.com/identity/sign-in/credential-manager-siwg-implementation (checked 2026-10-09). Button flow uses GetSignInWithGoogleOption with the configured Web client ID and server-issued nonce. Tokens are consumed from memory once, never logged or persisted by the plugin. Session persistence remains in the existing client adapter. Cancellation invalidates callbacks from earlier requests; sign-out clears provider credential state. Android never opens a browser as fallback.

## Optional process exit metadata (2026-10-11)

`BmtProcessExits.java` is first-party source using Android ApplicationExitInfo (API30+), with no added dependency. At most four OS exit records yield reason/time only, outside racing; trace streams, PIDs and device IDs are never read. Backend counters do not prove current-account crash attribution. JDK17/Android36 compile check passed; full Android export stopped at the creator geometry golden check, and device acceptance remains outstanding. See `docs/STUDIO_EXPANSION_2026_10_11.md`.
