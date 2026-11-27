#!/bin/bash
# Drive QA on one Android emulator. Usage: qa.sh API_LEVEL
# Tests the exact APK that app.json points to. Writes screenshots + report.txt to qa-out/.
API=$1
PKG=com.el7ajb.carlauncher
OUT=qa-out; mkdir -p $OUT
R=$OUT/report.txt
APK=$(python3 -c "import json;print(json.load(open('app.json'))['apk'])")
VER=$(python3 -c "import json;print(json.load(open('app.json'))['versionName'])")
log(){ echo "$*" | tee -a $R; }
sh(){ adb shell "$@" 2>/dev/null | tr -d '\r'; }
n=0
shot(){ n=$((n+1)); f=$(printf "%02d_%s" $n "$1"); adb exec-out screencap -p > $OUT/$f.png; size; echo "$f $W $H" >> $OUT/sizes.txt; log "  [shot] $f ($W x $H)"; }
top(){ sh dumpsys activity activities | grep -m1 -E "mResumedActivity|topResumedActivity" | sed 's/.*{//;s/}.*//' ; }
ui(){ sh uiautomator dump /sdcard/ui.xml >/dev/null; adb pull /sdcard/ui.xml $OUT/ui.xml >/dev/null 2>&1; }
tap_text(){ ui; xy=$(python3 tools/qa_tap.py $OUT/ui.xml "$@") && { sh input tap $xy; log "  tap '$1' at $xy"; return 0; }; log "  !! could not find '$1'"; return 1; }
size(){ W=$(sh wm size | grep -o '[0-9]*x[0-9]*' | tail -1 | cut -dx -f1); H=$(sh wm size | grep -o '[0-9]*x[0-9]*' | tail -1 | cut -dx -f2); }
pid(){ sh pidof $PKG; }
cpu(){ # % of one core used by the app over $1 seconds
  p=$(pid); [ -z "$p" ] && { echo "n/a"; return; }
  a=$(sh cat /proc/$p/stat | awk '{print $14+$15}'); sleep $1; b=$(sh cat /proc/$p/stat | awk '{print $14+$15}')
  echo "$(( (b-a) * 100 / ($1 * 100) ))%"; }
mem(){ sh dumpsys meminfo $PKG | grep -m1 -E "TOTAL( PSS)?:? " | awk '{print $2" KB"}'; }
gfx(){ sh dumpsys gfxinfo $PKG | grep -E "Total frames rendered|Janky frames|90th percentile|99th percentile" | sed 's/^ *//' | tr '\n' ';'; }
crashes(){ sh logcat -d -b crash | grep -c -E "FATAL|$PKG"; }
car_tap(){ size; local bh=$H by=0; [ $((W*100/H)) -lt 145 ] && { bh=$((W*10/17)); by=$(( (H-bh)/2 )); }; sh input tap $((W/2)) $((by + bh*47/100)); }

log "Drive $VER  API $API  RAM $(sh cat /proc/meminfo | head -1 | awk '{print int($2/1024)" MB"}')"
adb root >/dev/null; sleep 4; adb wait-for-device
sh svc power stayon true; sh settings put system screen_off_timeout 1800000
sh locksettings set-disabled true; sh settings put secure lockscreen.disabled 1
sh wm size 1024x600; sh wm density 160; sleep 2
log "display: $(sh wm size | tr '\n' ' ') $(sh wm density | tr '\n' ' ')"
adb logcat -c; adb logcat -b crash -c
adb install -r -g $APK > $OUT/install.txt 2>&1; log "install: $(tail -1 $OUT/install.txt)"
log "apk size: $(stat -c %s $APK) bytes"
sh cmd role add-role-holder android.app.role.HOME $PKG >/dev/null; sh cmd package set-home-activity $PKG/.MainActivity >/dev/null
sh appops set $PKG SYSTEM_ALERT_WINDOW allow

log ""; log "== 1. first run: code box"
sh input keyevent KEYCODE_HOME; sleep 6
log "  top: $(top)"; shot first_run
sh input text Y96YN; sleep 1; shot code_typed
sh input keyevent 66; sleep 3
if [ -z "$(sh ls /data/data/$PKG/files/cars 2>/dev/null | grep -v '^\.')" ] && ! sh ls /data/data/$PKG/cache/pack.tmp >/dev/null 2>&1; then
  log "  enter did not start the download, using the button"
  sh dumpsys input_method | grep -q "mInputShown=true" && sh input keyevent 111
  sleep 1; tap_text "Download"
fi
t0=$(date +%s); while [ -z "$(sh ls /data/data/$PKG/files/cars 2>/dev/null | grep -v '^\.')" ] && [ $(( $(date +%s) - t0 )) -lt 120 ]; do sleep 2; done
log "  car folder: $(sh ls /data/data/$PKG/files/cars | tr '\n' ' ')  after $(( $(date +%s) - t0 ))s"
log "  frames on disk: $(sh ls /data/data/$PKG/files/cars/*/spin | wc -l)"
sleep 3; shot after_download
tap_text "Start"; sleep 3; shot onboarding_settings
sh input keyevent KEYCODE_HOME; sleep 7
log "  top: $(top)"; shot home_1024x600

log ""; log "== 2. speed and memory (1024x600 mdpi)"
sh am force-stop $PKG; sleep 1
st=$(sh am start -W -a android.intent.action.MAIN -c android.intent.category.HOME -n $PKG/.MainActivity | grep -E "TotalTime|WaitTime" | tr '\n' ' ')
log "  cold start: $st"
sleep 8
log "  home idle memory: $(mem)"
log "  home idle cpu (10s): $(cpu 10)"
sh dumpsys gfxinfo $PKG reset >/dev/null; sleep 5; log "  home idle frames (5s): $(gfx)"
st=$(sh am start -W -f 0x10008000 -n $PKG/.PanelActivity --es screen settings | grep -E "TotalTime" | tr '\n' ' '); sleep 2
log "  settings panel open: $st"; shot settings
for k in 1 2 3; do sh input swipe $((W/2)) $((H*80/100)) $((W/2)) $((H*20/100)) 300; done; sleep 2; shot settings_bottom
ui; grep -o 'text="[^"]*"' $OUT/ui.xml | grep -iE "date|version|drive" | head -5 | sed 's/^/  ui: /' >> $R
st=$(sh am start -W -f 0x10008000 -n $PKG/.PanelActivity --es screen apps | grep -E "TotalTime" | tr '\n' ' '); sleep 3
log "  apps panel open: $st"; shot apps
sh am start -f 0x10008000 -n $PKG/.PanelActivity --es screen picker >/dev/null; sleep 3; shot picker
tap_text "Car code" && sleep 2 && tap_text "Pick from the list" && { sleep 6; shot pick_list; }
sh input keyevent KEYCODE_BACK; sleep 1; sh input keyevent KEYCODE_HOME; sleep 4
size; sh input swipe $((W*80/100)) $((H/2)) $((W*20/100)) $((H/2)) 300; sleep 2; shot home_page2
sh input swipe $((W*20/100)) $((H/2)) $((W*80/100)) $((H/2)) 300; sleep 2

log ""; log "== 3. showroom"
car_tap; sleep 2.5; shot showroom_open
sh dumpsys gfxinfo $PKG reset >/dev/null
for i in 1 2 3 4 5 6; do sh input swipe $((W*80/100)) $((H/2)) $((W*20/100)) $((H/2)) 500; done
log "  slow drags: $(gfx)"
sh dumpsys gfxinfo $PKG reset >/dev/null
sh input swipe $((W*85/100)) $((H/2)) $((W*15/100)) $((H/2)) 120; sleep 3
log "  fling: $(gfx)"; shot showroom_after_fling
sh input swipe $((W/2)) $((H*30/100)) $((W/2)) $((H*75/100)) 400; sleep 1.5; shot showroom_high
sh input swipe $((W/2)) $((H*75/100)) $((W/2)) $((H*20/100)) 500; sleep 1.5; shot showroom_low
for i in 1 2 3 4 5 6 7 8; do sh input swipe $((W*70/100)) $((H/2)) $((W*30/100)) $((H/2)) 250; done; sleep 2
log "  showroom memory after turning: $(mem)"
sh "input tap $((W/2)) $((H/2)) & (sleep 0.13; input tap $((W/2)) $((H/2)))"; sleep 2.5
shot after_double_tap
car_tap; sleep 2.5; sh input keyevent KEYCODE_BACK; sleep 2; shot after_back_key
sleep 3; log "  home memory after showroom: $(mem)"
car_tap; sleep 2.5
for k in 1 2 3 4 5 6; do g=$(adb emu geo fix 35.30$k 32.70 100 8 20 2>&1 | tr '\n' ' '); sleep 1; done
log "  geo fix answer: $g"
log "  last location: $(sh dumpsys location | grep -m2 -iE 'last.*gps|gps: Location' | tr -s ' ' | cut -c1-160)"
sleep 2; shot after_driving_20kn
for k in 1 2; do adb emu geo fix 35.30 32.70 100 8 0 >/dev/null 2>&1; sleep 1; done

log ""; log "== 4. screen sizes"
for s in 1024x600:240 1280x720:160 1280x720:240 800x480:120 1920x720:240 1280x800:160 2000x1200:320 768x1024:160; do
  sh wm size ${s%:*}; sh wm density ${s#*:}; sleep 5
  shot "home_${s/:/_}"
  car_tap; sleep 2.5; shot "showroom_${s/:/_}"
  sh input keyevent KEYCODE_BACK; sleep 2
done
sh wm size 1024x600; sh wm density 160; sleep 4

log ""; log "== 5. it must always come back"
sh cmd notification allow_listener $PKG/$PKG.NotifService >/dev/null
sh settings put secure enabled_accessibility_services $PKG/$PKG.HomeGuard; sh settings put secure accessibility_enabled 1; sleep 3
OTHER=$(sh cmd package query-activities --brief -a android.intent.action.MAIN -c android.intent.category.HOME | grep "/" | grep -v $PKG | grep -v -i fallback | head -1 | tr -d ' ')
log "  stock launcher: $OTHER"
if [ -n "$OTHER" ]; then sh am start -n $OTHER >/dev/null; sleep 4; log "  after opening the stock launcher, top: $(top)"; shot after_stock_launcher; fi
sh am start -a android.settings.SETTINGS >/dev/null; sleep 3; sh input keyevent KEYCODE_HOME; sleep 3; log "  settings app then HOME, top: $(top)"
sh input keyevent 26; sleep 4; sh input keyevent 224; sleep 1; sh wm dismiss-keyguard; sh input keyevent 82; sleep 4
log "  after screen off/on, top: $(top)"; shot after_screen_on
p=$(pid); sh kill -9 $p; sleep 6; log "  after the app was killed, top: $(top)"
adb reboot; adb wait-for-device; t0=$(date +%s)
while [ "$(sh getprop sys.boot_completed)" != "1" ] && [ $(( $(date +%s) - t0 )) -lt 240 ]; do sleep 3; done
sleep 25; adb root >/dev/null; sleep 4; adb wait-for-device
log "  after reboot ($(( $(date +%s) - t0 ))s), top: $(top)"; shot after_reboot

log ""; log "== 6. languages (changed in Settings like a user would)"
for L in "العربية:ar" "עברית:he" "English:en"; do
  sh am start -f 0x10008000 -n $PKG/.PanelActivity --es screen settings >/dev/null; sleep 3
  tap_text "${L%%:*}"; sleep 2; shot "settings_${L##*:}"
  sh am start -f 0x10008000 -n $PKG/.PanelActivity --es screen picker >/dev/null; sleep 3; shot "picker_${L##*:}"
  sh input keyevent KEYCODE_HOME; sleep 5; shot "home_${L##*:}"
  [ "${L##*:}" != en ] && { car_tap; sleep 2.5; shot "showroom_${L##*:}"; sh input keyevent KEYCODE_BACK; sleep 1; }
done

log ""; log "== 7. crashes"
c=$(sh logcat -d -b crash | grep -A20 "FATAL" | head -60)
if [ -n "$c" ]; then log "  CRASH:"; echo "$c" >> $R; else log "  no crashes"; fi
a=$(sh logcat -d | grep -E "ANR in $PKG|Application Not Responding.*$PKG" | head -5)
[ -n "$a" ] && log "  ANR: $a" || log "  no ANRs"
sh logcat -d | grep -iE "$PKG|AndroidRuntime" | grep -iE "exception|error" | head -30 > $OUT/errors.txt
log "  error lines mentioning the app: $(wc -l < $OUT/errors.txt)"
