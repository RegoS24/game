#!/usr/bin/env bash
set -euo pipefail
PKG=com.blacksignal.hd2d
adb wait-for-device
adb shell input keyevent 82 || true
# System overlays are not part of the game. Confirm immersive mode before launch.
adb shell settings put secure immersive_mode_confirmations confirmed
adb shell settings put global show_first_crash_dialog 0
adb shell settings put secure screensaver_enabled 0
adb logcat -G 8M || true
adb install --no-incremental -r dist/BLACK-SIGNAL-HD2D.apk
adb shell am force-stop "$PKG"
adb logcat -c
adb shell am start -W -n "$PKG/com.godot.game.GodotApp"
adb logcat -v threadtime > dist/android.log &
LOGGER=$!
trap 'kill "$LOGGER" 2>/dev/null || true' EXIT
wait_marker() {
 for i in $(seq 1 "$2"); do
  if grep -q "$1" dist/android.log; then echo "FOUND $1"; return 0; fi
  sleep 2
 done
 echo "Missing $1"
 grep -Ei 'blacksignal|godot|fatal exception|ANR in' dist/android.log | tail -120 || true
 adb shell dumpsys window | grep -E 'mCurrentFocus|mFocusedApp' || true
 adb exec-out screencap -p > dist/failure.png
 return 1
}
wait_marker BLACK_SIGNAL_LOBBY_READY 90
sleep 4
# Use the actual application viewport, after landscape/immersive configuration.
adb exec-out screencap -p > dist/lobby.png
read -r x y < <(python3 -c 'from PIL import Image; w,h=Image.open("dist/lobby.png").size; assert w>h,(w,h);s=min(w/1280,h/720);print(round((w-1280*s)/2+1100*s),round((h-720*s)/2+586*s))')
echo "Touch START at $x $y"
adb shell dumpsys window | grep -E 'mCurrentFocus|mFocusedApp' || true
for attempt in $(seq 1 5); do
 if grep -q BLACK_SIGNAL_CITY_READY dist/android.log; then break; fi
 adb shell input tap "$x" "$y"
 sleep 4
done
wait_marker BLACK_SIGNAL_CITY_READY 45
adb shell pidof "$PKG"
sleep 3
adb exec-out screencap -p > dist/city.png
# Verify that the screenshots are not a blank framebuffer.
python3 - <<'PY'
from PIL import Image
import numpy as np
for name in ("lobby","city"):
 a=np.asarray(Image.open("dist/"+name+".png").convert("RGB"))
 v=a[a.shape[0]//8:7*a.shape[0]//8,a.shape[1]//8:7*a.shape[1]//8]
 assert v.std()>10 and (v.max(2)>32).mean()>.25, (name,"blank image")
 print(name,"image variance",float(v.std()))
PY
if grep -E 'SCRIPT ERROR|FATAL EXCEPTION' dist/android.log; then exit 1; fi
echo "PASS native Godot HD2D lobby and city"
