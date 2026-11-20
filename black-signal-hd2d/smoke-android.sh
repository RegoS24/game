#!/usr/bin/env bash
set -euo pipefail
adb wait-for-device
adb shell input keyevent 82 || true
adb install -r dist/BLACK-SIGNAL-HD2D.apk
adb logcat -c
adb shell monkey -p com.blacksignal.hd2d -c android.intent.category.LAUNCHER 1
for i in $(seq 1 50); do
 adb logcat -d > dist/android.log
 if grep -q BLACK_SIGNAL_LOBBY_READY dist/android.log; then break; fi
 sleep 2
done
grep -q BLACK_SIGNAL_LOBBY_READY dist/android.log
adb exec-out screencap -p > dist/lobby.png
read -r x y < <(python3 -c 'import struct; f=open("dist/lobby.png","rb");f.seek(16);w,h=struct.unpack(">II",f.read(8));scale=min(w/1280,h/720);print(int((w-1280*scale)/2+1100*scale),int((h-720*scale)/2+586*scale))')
adb shell input tap "$x" "$y"
for i in $(seq 1 30); do
 adb logcat -d > dist/android.log
 if grep -q BLACK_SIGNAL_CITY_READY dist/android.log; then
  adb shell pidof com.blacksignal.hd2d
  adb exec-out screencap -p > dist/city.png
  if grep -E 'SCRIPT ERROR|FATAL EXCEPTION' dist/android.log; then exit 1; fi
  echo "PASS native Godot HD2D lobby and city"
  exit 0
 fi
 sleep 2
done
tail -100 dist/android.log
exit 1
