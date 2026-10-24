# AdMob development bridge

`src/org/beatmytrack/admob/BmtAdMob.java` and `android.gradle` are original project code. The bridge implements the documented Godot Android plugin interface directly in the matching generated Gradle template. No external Godot AdMob plugin is vendored.

Google Mobile Ads Android SDK is an owner-authorized dependency, pinned to `com.google.android.gms:play-services-ads:25.5.0` and resolved from Google's Maven repository. It is compiled only for Android debug. Google's SDK terms and transitive dependency notices apply; generated Gradle binaries/caches remain outside version control. No real app/ad placement, credentials or player identity is supplied to this bridge.

Only Google's documented sample application ID (`ca-app-pub-3940256099942544~3347511713`), rewarded demo ad unit (`ca-app-pub-3940256099942544/5224354917`) and interstitial demo unit (`ca-app-pub-3940256099942544/1033173712`) are used. Demo completion is not provider proof for server-authoritative banked rewards. The interstitial uses one preloaded ad, separate load/show operations and the same fullscreen ownership lock as rewarded ads. It grants no reward. Its 2026-10-22 references are [interstitial integration](https://developers.google.com/admob/android/interstitial) and [Google's demo units](https://developers.google.com/admob/android/test-ads).

The 2026-10-24 configuration integration emits `rewarded_presented` from the existing full-screen presentation callback. The client uses that presentation observation to start the configured active-time cooldown; earning a reward remains a separate callback. The debug Java source passed `compileStandardDebugJavaWithJavac` against the existing pinned dependencies. No APK was exported or installed by this change. Local evidence and rollout limits are in `docs/GAME_CONFIGURATION_IMPLEMENTATION_2026_10_24.md`.

An explicit `BMT_ADMOB_DEBUG_CA_DIR` can attach a local diagnostic manifest/resource directory to debug only. The owner approved the existing Windows-trusted Avast public root for local emulator ads after Android rejected Avast's HTTPS scanning certificate chain. No CA/private key or generated trust configuration is vendored; release source sets do not include it. Actual commands, domain limits and evidence are in `docs/ADMOB_DEVELOPMENT.md`.

Primary implementation references checked 2026-10-04:

- [Godot Android plugins](https://docs.godotengine.org/en/4.7/tutorials/platform/android/android_plugin.html)
- [Google Mobile Ads setup](https://developers.google.com/admob/android/quick-start)
- [Rewarded ads](https://developers.google.com/admob/android/rewarded)
- [Test ads](https://developers.google.com/admob/android/test-ads)
