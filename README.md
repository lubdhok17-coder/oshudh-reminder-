# ওষুধের সাথী

A medicine reminder app with a home-screen widget (Android).

## Folders
- `app_src/main.dart`: the whole Flutter app (change this to change the app)
- `android_overlay/`: the Android widget (Kotlin + XML layouts)
- `tools/patch_manifest.py`: registers the widget in the Android manifest
- `tools/debug.keystore`: fixed signing key, so updates install over old versions
- `.github/workflows/build.yml`: the robot that builds the APK for free

## Build
Push to GitHub, open the Actions tab, wait for the green tick, download `oushudh-apk`.
