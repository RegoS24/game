#!/usr/bin/env bash
set -euo pipefail
adb wait-for-device
adb shell input keyevent 82 || true
adb logcat -c
adb install -r out/BLACK-SIGNAL-RIN.apk
adb shell am start -W -n com.blacksignal.rin/.MainActivity --es smoke 1
for i in $(seq 1 45); do
  adb logcat -d -s BlackSignal:I AndroidRuntime:E > out/android-smoke.log
  if grep -q 'BS_SMOKE_OK' out/android-smoke.log; then
    adb shell pidof com.blacksignal.rin
    adb shell wm size
    adb exec-out screencap -p > out/android-gameplay.png
    echo "PASS Android installation, launch, actual WebView game and rendered frame"
    exit 0
  fi
  if grep -Eq 'FATAL EXCEPTION|NATIVE_START_ERROR|JS_START_ERROR|BS_SMOKE_(INIT|RENDER|STATE_FAIL)|WEB_RENDER_GONE' out/android-smoke.log; then cat out/android-smoke.log; exit 1; fi
  sleep 2
done
cat out/android-smoke.log
exit 1