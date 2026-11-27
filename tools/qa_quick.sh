#!/bin/bash
# Short check for slow old emulators: first run, download by code, home, showroom, reboot.
PKG=com.el7ajb.carlauncher; OUT=qa-out; mkdir -p $OUT; R=$OUT/report.txt
APK=$(python3 -c "import json;print(json.load(open('app.json'))['apk'])")
log(){ echo "$*" | tee -a $R; }
sh(){ adb shell "$@" 2>/dev/null | tr -d '\r'; }
shot(){ adb exec-out screencap -p > $OUT/$1.png; echo "$1 1024 600" >> $OUT/sizes.txt; log "  [shot] $1"; }
top(){ sh dumpsys activity activities | grep -m1 -E "mResumedActivity|topResumedActivity" | sed 's/.*{//;s/}.*//'; }
log "Drive $(python3 -c "import json;print(json.load(open('app.json'))['versionName'])")  API $1  (quick)"
adb root >/dev/null; sleep 4; adb wait-for-device
sh svc power stayon true; sh wm size 1024x600; sh wm density 160
log "device date: $(sh date)"
adb install -r -g $APK >/dev/null 2>&1; sh cmd package set-home-activity $PKG/.MainActivity >/dev/null
sh input keyevent KEYCODE_HOME; sleep 10; shot q1_first_run
sh input text Y96YN; sleep 1; sh input keyevent 66
t0=$(date +%s); while [ -z "$(sh ls /data/data/$PKG/files/cars 2>/dev/null | grep -v '^\.')" ] && [ $(( $(date +%s) - t0 )) -lt 150 ]; do sleep 3; done
log "  car folder: $(sh ls /data/data/$PKG/files/cars | tr '\n' ' ') after $(( $(date +%s) - t0 ))s, frames: $(sh ls /data/data/$PKG/files/cars/*/spin 2>/dev/null | wc -l)"
sleep 4; shot q2_after_download
sh input keyevent KEYCODE_HOME; sleep 8; shot q3_home
sh input tap 512 282; sleep 4; shot q4_showroom
sh input keyevent KEYCODE_BACK; sleep 3
c=$(sh logcat -d -b crash | grep -A15 FATAL | head -40); [ -n "$c" ] && { log "  CRASH:"; echo "$c" >> $R; } || log "  no crashes"
