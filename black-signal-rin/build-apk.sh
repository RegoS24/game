#!/usr/bin/env bash
set -euo pipefail
SDK="${ANDROID_SDK_ROOT:-${ANDROID_HOME:-}}"
[[ -n "$SDK" ]] || { echo 'Android SDK required'; exit 1; }
BT="$SDK/build-tools/34.0.0"
JAR="$SDK/platforms/android-34/android.jar"
mkdir -p out/classes out/dex
javac -encoding UTF-8 -source 8 -target 8 -classpath "$JAR" -d out/classes app/src/main/java/com/blacksignal/rin/MainActivity.java
"$BT/d8" --min-api 23 --lib "$JAR" --output out/dex $(find out/classes -name '*.class')
"$BT/aapt2" link -I "$JAR" --manifest app/src/main/AndroidManifest.xml -o out/unsigned.apk -A app/src/main/assets
(cd out/dex && zip -q -u ../unsigned.apk classes.dex)
"$BT/zipalign" -f 4 out/unsigned.apk out/aligned.apk
if [[ ! -f out/debug.keystore ]]; then
 keytool -genkeypair -keystore out/debug.keystore -storepass android -keypass android -alias androiddebugkey -keyalg RSA -keysize 2048 -validity 10000 -dname 'CN=Android Debug,O=Android,C=US'
fi
"$BT/apksigner" sign --ks out/debug.keystore --ks-key-alias androiddebugkey --ks-pass pass:android --key-pass pass:android --out out/BLACK-SIGNAL-RIN.apk out/aligned.apk
"$BT/apksigner" verify --verbose out/BLACK-SIGNAL-RIN.apk
