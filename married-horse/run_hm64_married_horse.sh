#!/usr/bin/env bash
# HM64 Power Nut lab - MARRIED + HORSE files (campaign married-horse, 2026-11-27): dog lines and every cast to 120 s
# for Thomas's two saves of married-hashorse.zip, one after the other in one command:
#   1. sunny  "Harvest Moon 64 (USA).beach-lineup2-horse-sunny-married.SaveRAM"  sha256 0f33f322...  (spring 13)
#   2. rainy  "Harvest Moon 64 (USA).beach-lineup2-horse-rainy-married.SaveRAM"  sha256 8cbe43a5...  (spring 12)
# Found by sha256 in ~/Documents/hm64/sourcefiles (any subfolder), ~/Downloads, or inside a *married*.zip there.
# This is the runner of the married no-horse tables (run_hm64_married_shared.sh, 2026-11-26d) with other saves:
#   A. dog-watch phases 1 + 3 (the main Mac only): route recipe, dog lines, cast tables 0.1-40 s
#   B. dog after the cast: marhorse-<save>-d90 (casts 0.1-40 s, to 90 s), -d140c90 (40-90 s, to 140 s),
#      -d170c120 (90-120 s, to 170 s); the cast blocks are shared between Macs (claims on branch lab-coord)
# Native ARM image only (hm64-lab:arm64): Macs. Labels married-horse-lineup2-sunny-0f33f322 /
# married-horse-lineup2-rainy-8cbe43a5; results/dogwatch/<label>, states/dogwatch/<label>, results/fullday/marhorse-*.
# Nothing of the other runs is touched.
#   bash run_hm64_married_horse.sh topdown [workers]      (the main Mac; bottomup / middleout = a helper Mac that
#                                                          already has the finished dog-watch folders)
# Before anything long runs, for BOTH saves: found, checked by what they are (weather, married to Karen, horse, no
# baby, the day, dog on the lineup2 tile, rod in hand, checksum), the lab health test, and the reference route from
# power-on twice on each save (tools/married_z0_check.py, equal to Claude's sandbox record of 2026-11-27).
# Queues behind another lab run. Env as in the married runner: HM64_RUN_ROOT, HM64_MARRIED_ONLY=sunny|rainy,
# HM64_MARRIED_WAIT=0, HM64_MARRIED_SKIP_SMOKE=1, M64H_RECYCLE.
set -euo pipefail
say() { printf '\n==> %s\n' "$*"; }
die() { printf '\nSTOP: %s\n' "$*" >&2; exit 1; }

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ORDER=${1:-}
WORKERS=${2:-}
PATH="$PATH:/Applications/Docker.app/Contents/Resources/bin:/usr/local/bin:/opt/homebrew/bin"
export PATH
case "$ORDER" in topdown|up) ORDER=up ;; bottomup|down) ORDER=down ;; middleout|middle) ORDER=middle ;; esac
case "$ORDER" in up|down|middle) ;; *) printf '\nSTOP: say which way this Mac works through the table: bash run_hm64_married_horse.sh topdown|bottomup|middleout [workers]\n  up = the main Mac (does the dog-watch phases and works the cast blocks from the top), down / middle = a helper Mac\n' >&2; exit 1 ;; esac
MACHINE=${HM64_MACHINE:-$(scutil --get LocalHostName 2>/dev/null || hostname -s 2>/dev/null || echo mac)}
MACHINE=$(printf '%s' "$MACHINE" | tr 'A-Z' 'a-z' | tr -c 'a-z0-9-' '-' | sed 's/--*/-/g; s/^-//; s/-$//')
rev_words() { local o="" w; for w in "$@"; do o="$w $o"; done; printf '%s' "$o"; }
ROM_SHA=15c570120bfaa97b4580762f5ee5939a56ba054e696925ea81ccfa55a022d2a6
SPRING9_SHA=db2c29ace807ab980ebbc7eccad11e30e37ea3dad53113c3fb1bdc073b759d63
SUNNY_SHA=0f33f322f65546b2c00e023df6538d35c149b32731b92a57cd5a8cbb9ccd5f44
SUNNY_ORIG_SHA=$SUNNY_SHA
RAINY_SHA=8cbe43a540e30d5bf8abfcf54356779e823921337e1c0349f5fbe681cba98716
EXP_SUNNY="weather=sunny,horse=yes,married=yes,wife=karen,baby=no,dog=beach,tile=18:23,rod=yes,season=spring,day=13"
EXP_RAINY="weather=rain,horse=yes,married=yes,wife=karen,baby=no,dog=beach,tile=18:23,rod=yes,season=spring,day=12"
ONLY=${HM64_MARRIED_ONLY:-both}
PRESET=${HM64_DOGSPOTS_PRESET:-dogwatch}
KIT="$HERE/hm64-fullday2-kit.tar.gz"
HM64_DIR="$HOME/Documents/hm64"
RUN_ROOT=${HM64_RUN_ROOT:-$HM64_DIR/runs}
WORK="$RUN_ROOT/dogspots"
LAB="$WORK/hm64-lab"
SRC="$HM64_DIR/sourcefiles/married"
# window  hold-to (s after READY)  last cast (s)  blocks of 40 s of cast frames  (the tag is married-<save>-<window>)
WINDOWS=${HM64_MARRIED_WINDOWS:-"d90:90:40:0-1 d140c90:140:90:2-5 d170c120:170:120:4-5"}

case "$ONLY" in both) NAMES="sunny rainy" ;; sunny|rainy) NAMES=$ONLY ;; *) die "HM64_MARRIED_ONLY must be sunny, rainy or both (got $ONLY)" ;; esac
sha() { shasum -a 256 "$1" | cut -d' ' -f1; }
for f in "$KIT" "$HERE/save_check.py" "$HERE/married_z0_check.py" "$HERE/save_redate.py"; do [ -f "$f" ] || die "$(basename "$f") is not next to this script ($HERE)"; done

# ---- keep the Mac awake and at full speed for as long as this script runs ----------------------------------------------
CAF=""
if command -v caffeinate >/dev/null 2>&1; then
  caffeinate -dims -w $$ &
  CAF=$!
fi
POWER_NOTE=""
if command -v pmset >/dev/null 2>&1; then
  PM=$(pmset -g 2>/dev/null || true)
  LPM=$(printf '%s\n' "$PM" | awk '$1 == "lowpowermode" {print $2; exit}')
  PWM=$(printf '%s\n' "$PM" | awk '$1 == "powermode" {print $2; exit}')
  if [ "${LPM:-0}" = 1 ] || [ "${PWM:-}" = 1 ]; then
    POWER_NOTE="WARNING: Low Power Mode is ON - the lab runs slower. Turn it off: System Settings > Energy > Energy Mode (or Low Power Mode) > Automatic or High Power. The run goes on."
  elif [ -n "${PWM:-}" ] && [ "$PWM" != 2 ]; then
    POWER_NOTE="note: Energy Mode is Automatic. High Power (System Settings > Energy > Energy Mode) keeps the M4 Pro at full clock with the fans up; optional."
  fi
fi

command -v docker >/dev/null || die "docker not found"
if ! docker info >/dev/null 2>&1; then
  open -a Docker >/dev/null 2>&1 || true
  n=0
  until docker info >/dev/null 2>&1; do
    n=$((n + 1)); [ "$n" -lt 36 ] || die "Docker is not running and did not start in 3 minutes (start Docker Desktop on this Mac's own screen)"
    sleep 5
  done
fi
for f in "$HERE/lab/tools/coord.py" "$HERE/lab/tools/pool_bench.py" "$HERE/tools/hm64_coord_sync.sh" "$HERE/tools/hm64_parts_sync.sh"; do [ -f "$f" ] || die "$(basename "$f") is not in this package ($HERE)"; done
[ -d "$LAB" ] || die "no lab folder $LAB - this run uses the work folder of the lineup2 runs (dog-watch / cast runs)"
[ -f "$LAB/tools/zigzag_campaign.py" ] && [ -f "$LAB/experiments/zigzag_jobs.py" ] || die "$LAB has no dog-watch lab code"
grep -q '^ZZ_CODE = "zigzag-4f' "$LAB/tools/zigzag_campaign.py" || die "the lab code in $LAB is not zigzag-4f (the code of the lineup2 dog-watch run): $(grep -m1 '^ZZ_CODE' "$LAB/tools/zigzag_campaign.py" | cut -c1-60)"
grep -q "\"$PRESET\": dict(" "$LAB/tools/zigzag_campaign.py" || die "preset $PRESET is not in $LAB/tools/zigzag_campaign.py"
docker image inspect hm64-lab:arm64 >/dev/null 2>&1 || die "the image hm64-lab:arm64 is not on this Mac (HM64_ARM=1 bash run_hm64_dogwatch06c.sh builds it)"
[ -f "$LAB/data/rom/Harvest_Moon_64_USA.z64" ] || die "no ROM in $LAB/data/rom"
[ "$(sha "$LAB/data/rom/Harvest_Moon_64_USA.z64")" = "$ROM_SHA" ] || die "$LAB/data/rom/Harvest_Moon_64_USA.z64 is not the NYWE rev00 ROM (sha256)"

# ---- one lab run at a time ------------------------------------------------------------------------------------------
LOCK="$WORK/.running"
WAITED=0
while :; do
  if [ -d "$RUN_ROOT/zigzag/.running" ]; then busy="a zigzag run ($RUN_ROOT/zigzag/.running)"
  elif [ -d "$RUN_ROOT/uicheck/.running" ]; then busy="the UI consistency lab ($RUN_ROOT/uicheck/.running)"
  elif [ -d "$RUN_ROOT/uilearn/.running" ]; then busy="a learning test ($RUN_ROOT/uilearn/.running)"
  elif [ -d "$RUN_ROOT/uiwhole/.running" ]; then busy="a whole-tool test ($RUN_ROOT/uiwhole/.running)"
  elif [ -d "$RUN_ROOT/uidog/.running" ]; then busy="a dog-line UI test ($RUN_ROOT/uidog/.running)"
  elif mkdir "$LOCK" 2>/dev/null; then break
  else busy="the lab run now going ($LOCK)"
  fi
  [ "${HM64_MARRIED_WAIT:-1}" = 1 ] || die "$busy - start this one after it finishes (if none is running, delete that folder)"
  [ $((WAITED % 15)) -ne 0 ] || echo "  $(date +%H:%M) waiting for $busy to finish; this run starts by itself right after it (Ctrl-C cancels; if nothing is running, delete that folder)"
  WAITED=$((WAITED + 1)); sleep 60
done
SYNC=""
trap 'rmdir "$LOCK" 2>/dev/null || true; [ -z "${SYNC:-}" ] || kill "$SYNC" 2>/dev/null || true; [ -z "$CAF" ] || kill "$CAF" 2>/dev/null || true' EXIT
STAMP=$(date +%Y%m%d-%H%M%S)
LOG="$WORK/run-marhorse120-$STAMP.log"
exec > >(tee -a "$LOG") 2>&1
T_ALL=$(date +%s)
say "SHARED run: this Mac = $MACHINE, direction $ORDER ($( [ "$ORDER" = up ] && echo 'main Mac' || echo 'helper: cast blocks only, of the saves whose dog-watch is already here'))"
say "MARRIED + HORSE tables to 120 s: saves [$NAMES], preset $PRESET, work folder $LAB (native ARM image)  $(date '+%a %H:%M')"
echo "  lab code: $(grep -m1 '^ZZ_CODE' "$LAB/tools/zigzag_campaign.py" | cut -c1-80)..."
if [ -n "$CAF" ]; then echo "  keeping the Mac awake: caffeinate -dims (pid $CAF) until this script ends - display, idle, disk and system sleep held off"
else echo "  (no caffeinate on this machine: nothing keeps it awake)"; fi
[ -z "$POWER_NOTE" ] || echo "  $POWER_NOTE"
FREE_GB=$(df -Pk "$WORK" | awk 'NR==2 {print int($4 / 1048576)}')
echo "  free disk: ${FREE_GB} GB"
[ "${FREE_GB:-0}" -ge "${HM64_MARRIED_MIN_GB:-25}" ] || die "less than ${HM64_MARRIED_MIN_GB:-25} GB free on the disk of $WORK (two dog-watch state stores need a few GB each)"

say "1/7 lab files"
KX="$WORK/.marriedkit-$STAMP"; mkdir -p "$KX"
tar -xzf "$KIT" -C "$KX"
K="$KX/hm64-fullday2-kit"
[ -f "$K/experiments/fullday_jobs.py" ] && [ -f "$K/tools/fullday_campaign.py" ] && [ -f "$K/tools/fullday_report.py" ] || die "hm64-fullday2-kit.tar.gz is not complete"
for f in experiments/fullday_jobs.py tools/fullday_campaign.py tools/fullday_report.py; do
  if [ -f "$LAB/$f" ] && ! cmp -s "$K/$f" "$LAB/$f"; then echo "  note: $f in the lab differs from the kit's copy (fullday-2); the kit's copy is used"; fi
  cp "$K/$f" "$LAB/$f"
done
rm -rf "${KX:?}"
for f in save_check.py married_z0_check.py save_redate.py; do cp "$HERE/$f" "$LAB/tools/$f"; done
cp "$HERE/lab/tools/coord.py" "$LAB/tools/coord.py"
mkdir -p "$LAB/results/fullday"
COORD="$LAB/results/fullday/coord"
mkdir -p "$COORD"; rm -f "$COORD/.stop" "$COORD/.sync_ok"
HM64_COORD_ONCE=1 bash "$HERE/tools/hm64_coord_sync.sh" "$COORD" "$MACHINE" </dev/null || die "cannot reach the lab-coord branch on GitHub (network, or this Mac's key ~/.ssh/hm64_github_ed25519). Without it the Macs cannot share the table. Nothing was run."
bash "$HERE/tools/hm64_coord_sync.sh" "$COORD" "$MACHINE" $$ </dev/null &
SYNC=$!
echo "  table sync with GitHub (branch lab-coord): running (pid $SYNC)"
cp "$HERE/lab/tools/pool_bench.py" "$LAB/tools/pool_bench.py"
PARTS=""
if [ "${HM64_PARTS_EVERY_MIN:-30}" != 0 ]; then
  bash "$HERE/tools/hm64_parts_sync.sh" "$MACHINE" "$LAB" $$ "${HM64_PARTS_EVERY_MIN:-30}" "results/fullday/marhorse-*/FD_casts_b*.jsonl" "results/fullday/marhorse-*/FD1_lines.jsonl" </dev/null &
  PARTS=$!
  echo "  this Mac's result parts go to GitHub every ${HM64_PARTS_EVERY_MIN:-30} min (branch lab-parts-$MACHINE; pid $PARTS)"
fi
chmod -R u+w "$LAB/data" 2>/dev/null || true
mkdir -p "$LAB/data/saves_dogspots" "$SRC"
chmod -R a+rwX "$LAB/states" "$LAB/results" 2>/dev/null || true
S9=0
[ -f "$LAB/data/saves/Harvest_Moon_64_USA3.SaveRAM" ] && [ "$(sha "$LAB/data/saves/Harvest_Moon_64_USA3.SaveRAM")" = "$SPRING9_SHA" ] && S9=1
echo "  fullday-2 kit, save_check.py, married_z0_check.py, save_redate.py -> $LAB"

cd "$LAB"
CUR=""          # the label of the save the lab commands run on (HM64_SRAM)
lab_run() {     # lab_run [-e K=V ...] -- command: one command in the native ARM lab image, the current save as HM64_SRAM
  local envs=()
  while [ "$#" -gt 0 ] && [ "$1" != "--" ]; do envs+=("$1"); shift; done
  shift
  docker run --rm --platform linux/arm64 --shm-size 4g -v "$LAB:/work" -v "$LAB/data:/work/data:ro" -w /work \
    -e HM64_SRAM="/work/data/saves_dogspots/$CUR.SaveRAM" -e M64H_CPU=dynarec -e M64H_RECYCLE="${M64H_RECYCLE:-6}" \
    -e HM64_COORD_DIR=/work/results/fullday/coord -e HM64_COORD_MACHINE="$MACHINE" -e HM64_COORD_ORDER="$ORDER" \
    -e HM64_COORD_CAMPAIGN="$CUR" -e HM64_COORD_BLOCKS="${HM64_COORD_BLOCKS:-50}" -e HM64_COORD_LISTS="${HM64_COORD_LISTS:-8}" \
    ${envs[@]+"${envs[@]}"} hm64-lab:arm64 "$@" </dev/null
}
AUTOW=0
if [ -z "$WORKERS" ]; then
  AUTOW=1
  NCPU=$(lab_run -- nproc 2>/dev/null || echo 2)
  WORKERS=$(( NCPU > 1 ? NCPU - 1 : 1 ))
fi
echo "  workers  $WORKERS"

# ---- 2/7 the saves -----------------------------------------------------------------------------------------------
say "2/7 the saves"
by_sha() {      # by_sha SHA: the first save file with this sha256 in sourcefiles(/married) or ~/Downloads
  local want=$1 d f
  for d in "$SRC" "$HM64_DIR/sourcefiles" "$HOME/Downloads"; do
    [ -d "$d" ] || continue
    while IFS= read -r f; do
      case "$f" in */__MACOSX/*|*/._*) continue ;; esac
      if [ "$(sha "$f")" = "$want" ]; then printf '%s\n' "$f"; return 0; fi
    done < <(find -L "$d" -maxdepth 3 -type f \( -iname '*.SaveRAM' -o -iname '*.sra' -o -iname '*.srm' -o -iname '*.sav' \) ! -path "*/runs/*" 2>/dev/null | sort)
  done
  return 1
}
from_zip() {    # the saves inside married-nohorse*.zip (Downloads / sourcefiles) -> sourcefiles/married
  local z t f n=0
  while IFS= read -r z; do
    t="$WORK/.marriedzip-$STAMP"; rm -rf "$t"; mkdir -p "$t"
    unzip -q -o "$z" -d "$t" 2>/dev/null || { rm -rf "$t"; continue; }
    while IFS= read -r f; do
      case "$(sha "$f")" in
        "$SUNNY_ORIG_SHA"|"$RAINY_SHA") cp -n "$f" "$SRC/" 2>/dev/null || true; n=$((n + 1)) ;;
      esac
    done < <(find "$t" -type f -iname '*.SaveRAM' ! -path '*/__MACOSX/*' 2>/dev/null)
    rm -rf "$t"
    [ "$n" -eq 0 ] || echo "  took the saves out of $z -> ~/Documents/hm64/sourcefiles/married/"
  done < <(find "$HOME/Downloads" "$HM64_DIR/sourcefiles" -maxdepth 2 -type f -iname '*married*.zip' 2>/dev/null | sort)
}
# (macOS /bin/bash is 3.2: no associative arrays; one variable per save: SAVE_sunny, LABEL_rainy, ...)
put() { eval "$1_$2=\$3"; }
get() { eval "printf '%s' \"\${$1_$2:-}\""; }
ZIPDONE=0
find_save() {   # find_save SHA
  local f
  f=$(by_sha "$1") && { printf '%s\n' "$f"; return 0; }
  if [ "$ZIPDONE" = 0 ]; then ZIPDONE=1; from_zip >&2; f=$(by_sha "$1") && { printf '%s\n' "$f"; return 0; }; fi
  return 1
}
for n in $NAMES; do
  if [ "$n" = sunny ]; then
    put EXPECT $n "$EXP_SUNNY"; put WEATHER $n 1; want=$SUNNY_SHA
    f=$(find_save "$SUNNY_SHA" || true)
    if [ -z "$f" ]; then
      die "the sunny married + horse save (sha256 ${SUNNY_SHA:0:8}..., \"Harvest Moon 64 (USA).beach-lineup2-horse-sunny-married.SaveRAM\") is not in ~/Documents/hm64/sourcefiles, ~/Downloads or a married-hashorse.zip there - put it into ~/Documents/hm64/sourcefiles/married/"
    fi
  else
    put EXPECT $n "$EXP_RAINY"; put WEATHER $n 2; want=$RAINY_SHA
    f=$(find_save "$RAINY_SHA") || die "the rainy married + horse save (sha256 ${RAINY_SHA:0:8}..., \"Harvest Moon 64 (USA).beach-lineup2-horse-rainy-married.SaveRAM\") is not in ~/Documents/hm64/sourcefiles, ~/Downloads or a married-hashorse.zip there - put it into ~/Documents/hm64/sourcefiles/married/"
  fi
  s=$(sha "$f")
  [ "$s" = "$want" ] || die "internal: $f is not sha256 $want"
  put LABEL $n "married-horse-lineup2-$n-${s:0:8}"
  put SAVE $n "$f"
  put SHA $n "$s"
  CUR=$(get LABEL $n)
  case "$f" in
    "$HM64_DIR/sourcefiles/"*) ;;
    *) cp -n "$f" "$SRC/" 2>/dev/null || true
       echo "  copied to ~/Documents/hm64/sourcefiles/married/ (kept there for later runs)" ;;
  esac
  rm -f "$LAB/data/saves_dogspots/$CUR.SaveRAM"
  cp "$f" "$LAB/data/saves_dogspots/$CUR.SaveRAM"
  echo "  save     $CUR   <- $f"
  lab_run -- python3 -I tools/save_check.py "/work/data/saves_dogspots/$CUR.SaveRAM" --expect "$(get EXPECT $n)" | sed 's/^/    /' \
    || die "the save $CUR is not what this run is for (FAIL above) - nothing was run"
done

# ---- 3/7 lab health + the reference route on every save ---------------------------------------------------------------
if [ "$AUTOW" = 1 ] && [ "${HM64_POOL_BENCH:-1}" = 1 ]; then
  CUR=$(get LABEL ${NAMES%% *})
  IMG=$(docker image inspect hm64-lab:arm64 --format '{{.Id}}' 2>/dev/null | cut -c8-19)
  mkdir -p "$HM64_DIR/pool"
  BF="$HM64_DIR/pool/bench_${IMG:-image}_${NCPU}.json"
  if [ ! -f "$BF" ]; then
    FAST=$(sysctl -n hw.perflevel0.physicalcpu 2>/dev/null || echo "$NCPU")
    say "worker benchmark: which worker count is fastest on this Mac (once per Mac and container; some minutes)"
    rm -f "$LAB/results/.pool_bench.json"
    lab_run -- python3 tools/pool_bench.py --workers-list "$FAST,$((NCPU - 1)),$NCPU,$((NCPU + NCPU / 3))" --out /work/results/.pool_bench.json || echo "  (benchmark failed: the usual worker count is used)"
    [ ! -f "$LAB/results/.pool_bench.json" ] || mv "$LAB/results/.pool_bench.json" "$BF"
  fi
  if [ -f "$BF" ]; then
    BW=$(python3 -I -c 'import json,sys; print(json.load(open(sys.argv[1]))["best"])' "$BF" 2>/dev/null || true)
    case "$BW" in ''|*[!0-9]*) ;; *) WORKERS=$BW; echo "  workers  $WORKERS  (this Mac's benchmark: $BF; delete that file to measure again)" ;; esac
  fi
fi
say "3/7 lab health + each save's reference route from power-on (twice)"
if [ "${HM64_MARRIED_SKIP_SMOKE:-0}" != 1 ] && [ "$S9" = 1 ]; then
  docker run --rm --platform linux/arm64 --shm-size 4g -v "$LAB:/work" -v "$LAB/data:/work/data:ro" -w /work \
    hm64-lab:arm64 bash -lc 'python3 tools/smoke_test.py' </dev/null || die "lab health test failed - see $LOG (results would not be trustworthy)"
else
  echo "  lab health test skipped$( [ "$S9" = 1 ] || echo " (no Spring 9 save in $LAB/data/saves)")"
fi
for n in $NAMES; do
  CUR=$(get LABEL $n)
  echo "  $CUR:"
  lab_run -- python3 tools/married_z0_check.py --weather "$(get WEATHER $n)" || die "the pre-flight check of $CUR stopped the run (see above) - nothing was run"
done

# ---- per save: dog-watch phases 1 and 3, then the dog after the cast -------------------------------------------------
zz() {          # zz <stop-after or ''>: the dog-watch campaign on the current save
  lab_run -e HM64_ZZ_STORE="/work/$STORE" -e HM64_CORE_FILE=/work/results/core.json \
    -e HM64_ZZ_STOP_AFTER="$1" -e HM64_ZZ_MAX_LINES="${HM64_ZZ_MAX_LINES:-0}" -e HM64_ZZ_BITE_UNTIL= -- \
    python3 tools/zigzag_campaign.py --preset "$PRESET" --workers "$WORKERS" --out "$RES_L"
}
dwreport() { lab_run -- python3 tools/dogwatch_report.py "$RES_L" || echo "  (dog-watch report failed - see $LOG)"; }
pack_dw() { ( cd "$LAB/results/$PRESET" && rm -f "$1" && zip -q -r "$1" "$CUR" -x "*.SaveRAM" "*.st" "*.state" ) && echo "  zip      $1"; }
fd_window() {   # fd_window TAG UNTIL CUNTIL BLOCKS
  local TAG=$1 UNTIL=$2 CUNTIL=$3 BLOCKS=$4 RES="results/fullday/$1" NB LIST B BB T0
  local CAMP="python3 tools/fullday_campaign.py --src $RES_L --out $RES --workers $WORKERS"
  fdrun() {
    lab_run -e HM64_ZZ_STORE="/work/$STORE" -e HM64_FD_COVER=0.90 -e HM64_FD_TAIL=240 \
      -e HM64_FD_MAX_LINES="${HM64_FD_MAX_LINES:-0}" -e HM64_FD_MAX_CASTS="${HM64_FD_MAX_CASTS:-0}" \
      -e HM64_FD_UNTIL="$UNTIL" -e HM64_FD_CAST_UNTIL="$CUNTIL" -e HM64_FD_ANY_DOG=0 -e HM64_ZZ_TEST_DOG= -- "$@"
  }
  fdreport() {
    fdrun python3 tools/fullday_report.py --src "$RES_L" --out "$RES" > "$LAB/$RES/report.log" 2>&1 || echo "  (report failed - see $LAB/$RES/report.log)"
    cp "$LOG" "$LAB/$RES/run-marhorse120-$STAMP.log" 2>/dev/null || true
    ( cd "$LAB/results/fullday" && rm -f "$RUN_ROOT/hm64-fullday-$TAG-summary.zip" && \
      zip -q -r "$RUN_ROOT/hm64-fullday-$TAG-summary.zip" "$TAG" -x "*/FD_casts_b*.jsonl" "*.SaveRAM" "*.st" "*.state" ) || echo "  (summary zip failed)"
  }
  say "$TAG: casts to $CUNTIL s, everything to $UNTIL s after READY, blocks $BLOCKS  ($(date '+%a %H:%M'))"
  mkdir -p "$LAB/$RES"
  if [ -f "$LAB/$RES/.limits" ] && [ "$(cat "$LAB/$RES/.limits")" != "$UNTIL $CUNTIL" ]; then die "results/fullday/$TAG was made with other limits ($(cat "$LAB/$RES/.limits"))"; fi
  if [ -f "$LAB/$RES/.save" ] && [ "$(cat "$LAB/$RES/.save")" != "$CUR" ]; then die "results/fullday/$TAG was made on another save ($(cat "$LAB/$RES/.save"))"; fi
  echo "$UNTIL $CUNTIL" > "$LAB/$RES/.limits"
  echo "$CUR" > "$LAB/$RES/.save"
  chmod -R a+rwX "$LAB/results/fullday" 2>/dev/null || true
  if [ -f "$LAB/$RES/.done_lines" ]; then echo "  lines: done before"
  else
    fdrun $CAMP lines || die "$TAG: the lines stage stopped - see above and $LOG. Nothing was cast."
    touch "$LAB/$RES/.done_lines"
  fi
  fdrun $CAMP plan || die "$TAG: no plan - see $LOG"
  NB=$(fdrun $CAMP nblocks | tail -1)
  case "$NB" in ''|*[!0-9]*) die "$TAG: could not read the number of blocks ($NB)";; esac
  case "$BLOCKS" in *-*) LIST=$(seq "${BLOCKS%-*}" "${BLOCKS#*-}");; *) LIST=$BLOCKS;; esac
  [ "$ORDER" = up ] || LIST=$(rev_words $LIST)
  for B in $LIST; do
    [ "$B" -lt "$NB" ] || { echo "  block $B: there are only $NB blocks"; continue; }
    BB=$(printf '%02d' "$B")
    say "$TAG block $B of $((NB - 1))$( [ -f "$LAB/$RES/.done_b$BB" ] && echo '  (done before: only telling the other Macs)' )  ($(date '+%a %H:%M'))"
    T0=$(date +%s)
    fdrun $CAMP block "$B" || die "$TAG block $B stopped with job errors - see $LOG (the same command runs the failed jobs again)"
    touch "$LAB/$RES/.done_b$BB"
    echo "  block $B done in $(( ($(date +%s) - T0) / 60 )) min"
    fdreport
    sed -n '/^| block | cast frames/,/^$/p' "$LAB/$RES/FULLDAY.md" 2>/dev/null || true
    if [ -s "$LAB/$RES/FD_casts_b$BB.jsonl" ]; then
      ( cd "$LAB/results/fullday" && rm -f "$RUN_ROOT/hm64-fullday-$TAG-b$BB@$MACHINE.zip" && \
        zip -q -9 "$RUN_ROOT/hm64-fullday-$TAG-b$BB@$MACHINE.zip" "$TAG/FD_casts_b$BB.jsonl" ) || echo "  (zip of block $B failed)"
      echo "  this Mac's part of block $B: $RUN_ROOT/hm64-fullday-$TAG-b$BB@$MACHINE.zip"
    fi
  done
  fdreport
}

SEND="$RUN_ROOT/hm64-marhorse120-$STAMP"
i=0
[ "$ORDER" = up ] || { NAMES=$(rev_words $NAMES); WINDOWS=$(rev_words $WINDOWS); }
for n in $NAMES; do
  i=$((i + 1))
  CUR=$(get LABEL $n)
  RES_L="results/$PRESET/$CUR"
  STORE="states/$PRESET/$CUR"
  mkdir -p "$LAB/$RES_L"
  if [ "$ORDER" != up ] && { [ ! -f "$LAB/$RES_L/.done_phase1" ] || [ ! -f "$LAB/$RES_L/.done_phase3" ]; }; then
    say "[$i: $CUR] SKIPPED on this helper Mac: its dog-watch run is not here (it is made on the main Mac). When the main Mac has finished it, run hm64_cloud_setup.sh there again and start this again."
    continue
  fi
  say "4/7 [$i: $CUR] dog-watch phase 1: route recipe + dog lines + what the dog shows after READY ($(date '+%a %H:%M'))"
  T0=$(date +%s)
  if [ -f "$LAB/$RES_L/.done_phase1" ]; then echo "  done before"
  else
    zz Z6 || die "phase 1 of $CUR stopped - see $LAB/$RES_L/ZIGZAG.md and $LOG (run the same command again to continue)"
    touch "$LAB/$RES_L/.done_phase1"
    dwreport
    sed -n '1,30p' "$LAB/$RES_L/DOGWATCH.md" 2>/dev/null || true
    pack_dw "$RUN_ROOT/hm64-dogwatch-early-$CUR-$STAMP.zip" || true
    echo "  phase 1: $(( ($(date +%s) - T0) / 60 )) min"
  fi

  say "5/7 [$i: $CUR] dog-watch phase 3: Lucky Timer cast tables (every game frame 0.1-40 s, every bite to 90 s) ($(date '+%a %H:%M'))"
  T0=$(date +%s)
  if [ -f "$LAB/$RES_L/.done_phase3" ]; then echo "  done before"
  else
    zz "" || die "phase 3 of $CUR stopped - see $LAB/$RES_L/ZIGZAG.md and $LOG (run the same command again to continue)"
    touch "$LAB/$RES_L/.done_phase3"
    dwreport
    cp "$LOG" "$LAB/$RES_L/run-marhorse120-$STAMP.log" 2>/dev/null || true
    sed -n '1,30p' "$LAB/$RES_L/DOGWATCH.md" 2>/dev/null || true
    echo "  phase 3: $(( ($(date +%s) - T0) / 60 )) min"
  fi
  DWZIP="$RUN_ROOT/hm64-dogwatch-$CUR.zip"
  pack_dw "$DWZIP" || die "zip of the dog-watch results of $CUR failed"

  say "6/7 [$i: $CUR] dog after the cast: $(echo "$WINDOWS" | wc -w | tr -d ' ') windows ($(date '+%a %H:%M'))"
  NST=$(ls "$LAB/$STORE/b" 2>/dev/null | grep -c '\.st$' || true)
  [ "${NST:-0}" -gt 0 ] || die "the dog-watch run of $CUR left no beach savestates in $LAB/$STORE/b - the lines cannot be replayed"
  for spec in $WINDOWS; do
    IFS=: read -r wn un cu bl <<< "$spec"
    fd_window "marhorse-$n-$wn" "$un" "$cu" "$bl"
  done

  say "7/7 [$i: $CUR] the zips to send"
  mkdir -p "$SEND"
  [ "$ORDER" != up ] || cp "$DWZIP" "$SEND/"
  for spec in $WINDOWS; do
    tg="marhorse-$n-${spec%%:*}"
    ( cd "$LAB/results/fullday" && rm -f "$SEND/hm64-fullday-$tg@$MACHINE.zip" && zip -q -9 -r "$SEND/hm64-fullday-$tg@$MACHINE.zip" "$tg" -x "*.SaveRAM" "*.st" "*.state" ) || echo "  (zip of $tg failed)"
  done
  cp "$LOG" "$SEND/" 2>/dev/null || true
  echo "  $CUR done: its zips are in $SEND"
done

echo
echo "------------------------------------------------------------------------------------------------"
echo " MARRIED TABLES DONE   [$NAMES]   ($(( ($(date +%s) - T_ALL) / 60 )) min in all)"
echo "------------------------------------------------------------------------------------------------"
for n in $NAMES; do
  CUR=$(get LABEL $n)
  echo "  $CUR:"
  sed -n '1,12p' "$LAB/results/$PRESET/$CUR/DOGWATCH.md" 2>/dev/null | sed 's/^/    /' || true
done
echo
echo "  send these (no ROM / saves / savestates inside):"
cp "$LOG" "$SEND/" 2>/dev/null || true
ls -l "$SEND" | awk 'NR > 1 {printf "    %-60s %6.1f MB\n", $9, $5 / 1048576}'
echo "  folder: $SEND"

if [ -n "${PARTS:-}" ]; then touch "$LAB/.parts_stop"; wait "$PARTS" 2>/dev/null || true; PARTS=""; fi
if [ -n "${SYNC:-}" ]; then touch "$COORD/.stop"; wait "$SYNC" 2>/dev/null || true; SYNC=""; fi
rmdir "$LOCK" 2>/dev/null || true
if [ "${HM64_MARRIED_NO_UPLOAD:-0}" != 1 ]; then
  T="$HM64_DIR/tools"; mkdir -p "$T"
  NEW=$(grep -m1 '^LABDATA_REV=' "$HERE/tools/hm64_labdata.sh" 2>/dev/null | cut -d'"' -f2 || true)
  OLD=""; [ ! -f "$T/hm64_labdata.sh" ] || OLD=$(grep -m1 '^LABDATA_REV=' "$T/hm64_labdata.sh" | cut -d'"' -f2 || true)
  if [ -n "$NEW" ] && [[ "$NEW" > "$OLD" ]]; then
    if [ -f "$T/hm64_labdata.sh" ]; then B="$HM64_DIR/backups/$(date +%Y%m%d-%H%M%S)_tools"; mkdir -p "$B"; cp "$T/hm64_labdata.sh" "$B/"; fi
    cp "$HERE/tools/hm64_labdata.sh" "$T/hm64_labdata.sh"
    echo "  lab-data script $NEW installed in $T"
  fi
  bash "$T/hm64_labdata.sh" </dev/null || echo "  warning: the results were NOT uploaded to the lab-data branch (see above). Try: bash $T/hm64_labdata.sh </dev/null"
fi
