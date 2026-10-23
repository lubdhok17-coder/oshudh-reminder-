"""Adds the widget to the Android manifest that `flutter create` generated.

Run from the project root:  python3 tools/patch_manifest.py
"""
import pathlib
import re

path = pathlib.Path("android/app/src/main/AndroidManifest.xml")
text = path.read_text(encoding="utf-8")

# 1) App name on the phone
text = re.sub(r'android:label="[^"]*"', 'android:label="ওষুধের সাথী"', text, count=1)

# 2) The widget itself + the two pieces home_widget needs for the tick button
snippet = """
        <receiver
            android:name=".OushudhWidgetProvider"
            android:exported="true"
            android:label="ওষুধের সাথী">
            <intent-filter>
                <action android:name="android.appwidget.action.APPWIDGET_UPDATE" />
            </intent-filter>
            <meta-data
                android:name="android.appwidget.provider"
                android:resource="@xml/oushudh_widget_info" />
        </receiver>
        <receiver
            android:name="es.antonborri.home_widget.HomeWidgetBackgroundReceiver"
            android:exported="true">
            <intent-filter>
                <action android:name="es.antonborri.home_widget.action.BACKGROUND" />
            </intent-filter>
        </receiver>
        <service
            android:name="es.antonborri.home_widget.HomeWidgetBackgroundService"
            android:exported="true"
            android:permission="android.permission.BIND_JOB_SERVICE" />
    """

if "</application>" not in text:
    raise SystemExit("ERROR: </application> not found in AndroidManifest.xml")
if "OushudhWidgetProvider" in text:
    raise SystemExit("Manifest already patched, nothing to do")

text = text.replace("</application>", snippet + "</application>", 1)
path.write_text(text, encoding="utf-8")
print("AndroidManifest.xml patched OK")
