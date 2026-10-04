# AdMob development bridge

`src/org/beatmytrack/admob/BmtAdMob.java` and `android.gradle` are original project code. The bridge implements the documented Godot Android plugin interface directly in the matching generated Gradle template. No external Godot AdMob plugin is vendored.

Google Mobile Ads Android SDK is an owner-authorized dependency, pinned to `com.google.android.gms:play-services-ads:25.5.0` and resolved from Google's Maven repository. It is compiled only for Android debug. Google's SDK terms and transitive dependency notices apply; generated Gradle binaries/caches remain outside version control. No real app/ad placement, credentials or player identity is supplied to this bridge.

Only Google's documented sample application ID (`ca-app-pub-3940256099942544~3347511713`) and rewarded demo ad unit (`ca-app-pub-3940256099942544/5224354917`) are used. Demo completion is not provider proof for server-authoritative banked rewards.

An explicit `BMT_ADMOB_DEBUG_CA_DIR` can attach a local diagnostic manifest/resource directory to debug only. The owner approved the existing Windows-trusted Avast public root for local emulator ads after Android rejected Avast's HTTPS scanning certificate chain. No CA/private key or generated trust configuration is vendored; release source sets do not include it. Actual commands, domain limits and evidence are in `docs/ADMOB_DEVELOPMENT.md`.

Primary implementation references checked 2026-10-04:

- [Godot Android plugins](https://docs.godotengine.org/en/4.7/tutorials/platform/android/android_plugin.html)
- [Google Mobile Ads setup](https://developers.google.com/admob/android/quick-start)
- [Rewarded ads](https://developers.google.com/admob/android/rewarded)
- [Test ads](https://developers.google.com/admob/android/test-ads)
