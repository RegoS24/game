#!/usr/bin/env bash
set -euo pipefail
adb install -r dist/BLACK-SIGNAL-3D.apk
adb logcat -c
adb shell input keyevent 82 || true
adb shell monkey -p com.blacksignal.nox3d -c android.intent.category.LAUNCHER 1
for i in $(seq 1 45); do
 adb logcat -d > dist/android.log
 if grep -q BS3D_LOBBY_READY dist/android.log; then break; fi
 if grep -q 'FATAL EXCEPTION' dist/android.log; then cat dist/android.log | tail -150; exit 1; fi
 sleep 2
done
grep -q BS3D_LOBBY_READY dist/android.log
adb shell pidof com.blacksignal.nox3d
adb exec-out screencap -p > dist/lobby.png
# Landscape physical display dimensions from screenshot
read W H < <(python -c 'import struct; f=open("dist/lobby.png","rb"); f.seek(16); print(*struct.unpack(">II",f.read(8)))')
test "$W" -gt "$H"
adb shell input tap "$((W*86/100))" "$((H*84/100))"
for i in $(seq 1 20); do
 adb logcat -d > dist/android.log
 if grep -q BS3D_CITY_READY dist/android.log; then break; fi
 sleep 2
done
grep -q BS3D_CITY_READY dist/android.log
sleep 2
adb exec-out screencap -p > dist/city.png
adb shell pidof com.blacksignal.nox3d
! grep -E 'SCRIPT ERROR|FATAL EXCEPTION' dist/android.log
echo "PASS native Android landscape lobby and 3D city"
