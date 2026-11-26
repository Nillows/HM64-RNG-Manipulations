#!/usr/bin/env bash
# HM64 Power Nut lab - CAMERA ZONES OF THE DOCK END ON THE RAINY FILES (2026-11-25).
# The pier-spot run showed: the dock end has three camera zones (visibility grids): north (Jack's z 154.8-158.4, where
# all cast data was recorded), middle (164-188.4) and south (194-196.1). A recorded cast can only come out differently
# in another zone if the dog comes near a tile the two grids treat differently.
# This run casts, from the middle and from the south zone, exactly those recorded casts (plan made by Claude from the
# recorded dog paths: 99.3% of the real differences and every new Nut on the spot run's data), minus the ones the spot
# run already made, plus every 100th of the others as a check of the casts that are simply copied.
# For each rainy save (no horse 8e972d75 first, then horse 287c11a6), on the folders of its dog-watch run and of the
# pier-spot run (results/spots/<label>, whose gate must have passed). Nothing of those runs is changed.
# Native ARM image only. The Mac is kept awake (caffeinate -dims). Queues behind another lab run.
# At the end it brings the lab-data branch on GitHub up to date (tools/hm64_labdata.sh).
#
# SHARED VERSION (2026-11-25): several Macs fill ONE table. Each Mac is started with a direction:
#
#   bash run_hm64_zones_shared.sh topdown|bottomup|middleout [workers]
#
# up = from the top of the job list down, down = from the bottom up, middle = from the middle out, alternating sides.
# The Macs tell each other through the lab-coord branch on GitHub which blocks they hold (tools/hm64_coord_sync.sh)
# and each stops when every block is done by somebody. Each Mac uploads its own part:
# runs/hm64-zones-<label>@<machine>.zip. The report is made after the parts are merged (Claude).
# Env also: HM64_MACHINE (name of this Mac in the table; default its local host name), HM64_COORD_BLOCKS (50).
#
# Ctrl-C any time; the same command continues where it stopped.
# Env: HM64_RUN_ROOT, HM64_SPOTS_ONLY=nohorse|horse, HM64_SPOTS_WAIT=0, HM64_SPOTS_NO_UPLOAD=1, M64H_RECYCLE;
# test knobs (sandbox only): HM64_SPOTS_PRESET, HM64_SP_MAX_LINES, HM64_SP_MAX_CASTS, HM64_SPOTS_MIN_GB.
set -euo pipefail
say() { printf '\n==> %s\n' "$*"; }
die() { printf '\nSTOP: %s\n' "$*" >&2; exit 1; }

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ORDER=${1:-}
WORKERS=${2:-}
PATH="$PATH:/Applications/Docker.app/Contents/Resources/bin:/usr/local/bin:/opt/homebrew/bin"
export PATH
ROM_SHA=15c570120bfaa97b4580762f5ee5939a56ba054e696925ea81ccfa55a022d2a6
SHA_nohorse=8e972d756d3ef52f31e73925368a8d1ebdd06de8a631781a8ab3cce02ceda091
SHA_horse=287c11a65fa9745eb6529affac9b7b0243c7dc87e98655f4a16aa5d6cc1bf989
LABEL_nohorse=rain-lineup2-nohorse-8e972d75
LABEL_horse=rain-lineup2-horse-287c11a6
ONLY=${HM64_SPOTS_ONLY:-both}
PRESET=${HM64_SPOTS_PRESET:-dogwatch}
HM64_DIR="$HOME/Documents/hm64"
RUN_ROOT=${HM64_RUN_ROOT:-$HM64_DIR/runs}
WORK="$RUN_ROOT/dogspots"
LAB="$WORK/hm64-lab"
case "$ORDER" in topdown|up) ORDER=up ;; bottomup|down) ORDER=down ;; middleout|middle) ORDER=middle ;; esac
case "$ORDER" in up|down|middle) ;; *) die "say which way this Mac works through the table: bash run_hm64_zones_shared.sh topdown|bottomup|middleout [workers]" ;; esac
MACHINE=${HM64_MACHINE:-$(scutil --get LocalHostName 2>/dev/null || hostname -s 2>/dev/null || echo mac)}
MACHINE=$(printf '%s' "$MACHINE" | tr 'A-Z' 'a-z' | tr -c 'a-z0-9-' '-' | sed 's/--*/-/g; s/^-//; s/-$//')
[ -n "$MACHINE" ] || die "no machine name (set HM64_MACHINE)"
case "$ONLY" in both) NAMES="nohorse horse" ;; nohorse|horse) NAMES=$ONLY ;; *) die "HM64_SPOTS_ONLY must be nohorse, horse or both (got $ONLY)" ;; esac
sha() { shasum -a 256 "$1" | cut -d' ' -f1; }
get() { eval "printf '%s' \"\${$1_$2:-}\""; }
for f in lab/experiments/spot_jobs.py lab/tools/spot_campaign.py lab/tools/coord.py lab/tools/pool_bench.py tools/hm64_coord_sync.sh tools/hm64_parts_sync.sh lab/experiments/fullday_jobs.py; do [ -f "$HERE/$f" ] || die "$f is not next to this script ($HERE)"; done
for n in $NAMES; do [ -f "$HERE/plans/zone_plan_$(get LABEL $n).json.gz" ] || die "plans/zone_plan_$(get LABEL $n).json.gz is not next to this script"; done

CAF=""
if command -v caffeinate >/dev/null 2>&1; then
  caffeinate -dims -w $$ &
  CAF=$!
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
[ -d "$LAB" ] || die "no lab folder $LAB - this run uses the work folder of the lineup2 runs"
[ -f "$LAB/tools/zigzag_campaign.py" ] && [ -f "$LAB/experiments/zigzag_jobs.py" ] || die "$LAB has no dog-watch lab code"
grep -q '^ZZ_CODE = "zigzag-4f' "$LAB/tools/zigzag_campaign.py" || die "the lab code in $LAB is not zigzag-4f (the code of the rainy dog-watch runs)"
docker image inspect hm64-lab:arm64 >/dev/null 2>&1 || die "the image hm64-lab:arm64 is not on this Mac"
[ -f "$LAB/data/rom/Harvest_Moon_64_USA.z64" ] || die "no ROM in $LAB/data/rom"
[ "$(sha "$LAB/data/rom/Harvest_Moon_64_USA.z64")" = "$ROM_SHA" ] || die "$LAB/data/rom/Harvest_Moon_64_USA.z64 is not the NYWE rev00 ROM (sha256)"

LOCK="$WORK/.running"
WAITED=0
while :; do
  busy=""
  for d in zigzag uicheck uilearn uiwhole uidog; do
    if [ -d "$RUN_ROOT/$d/.running" ]; then busy="another lab ($RUN_ROOT/$d/.running)"; fi
  done
  if [ -z "$busy" ]; then
    if mkdir "$LOCK" 2>/dev/null; then break; fi
    busy="the lab run now going ($LOCK)"
  fi
  [ "${HM64_SPOTS_WAIT:-1}" = 1 ] || die "$busy - start this one after it finishes (if none is running, delete that folder)"
  [ $((WAITED % 15)) -ne 0 ] || echo "  $(date +%H:%M) waiting for $busy to finish; this run starts by itself right after it (Ctrl-C cancels; if nothing is running, delete that folder)"
  WAITED=$((WAITED + 1)); sleep 60
done
SYNC=""
trap 'rmdir "$LOCK" 2>/dev/null || true; [ -z "$SYNC" ] || kill "$SYNC" 2>/dev/null || true; [ -z "$CAF" ] || kill "$CAF" 2>/dev/null || true' EXIT
STAMP=$(date +%Y%m%d-%H%M%S)
LOG="$WORK/run-zones-$STAMP.log"
exec > >(tee -a "$LOG") 2>&1
T_ALL=$(date +%s)
say "camera zones of the dock end on the rainy files, SHARED: this Mac = $MACHINE, direction $ORDER; saves [$NAMES], work folder $LAB (native ARM image)  $(date '+%a %H:%M')"
if [ -n "$CAF" ]; then echo "  keeping the Mac awake: caffeinate -dims (pid $CAF) until this script ends"; else echo "  (no caffeinate on this machine: nothing keeps it awake)"; fi
FREE_GB=$(df -Pk "$WORK" | awk 'NR==2 {print int($4 / 1048576)}')
echo "  free disk: ${FREE_GB} GB"
[ "${FREE_GB:-0}" -ge "${HM64_SPOTS_MIN_GB:-5}" ] || die "less than ${HM64_SPOTS_MIN_GB:-5} GB free on the disk of $WORK"

say "1/4 lab files"
for f in experiments/spot_jobs.py tools/spot_campaign.py tools/coord.py; do cp "$HERE/lab/$f" "$LAB/$f"; done
COORD="$LAB/results/spots/coord"
mkdir -p "$COORD"; rm -f "$COORD/.stop" "$COORD/.sync_ok"
HM64_COORD_ONCE=1 bash "$HERE/tools/hm64_coord_sync.sh" "$COORD" "$MACHINE" </dev/null || die "cannot reach the lab-coord branch on GitHub (network, or this Mac's key ~/.ssh/hm64_github_ed25519). Without it the Macs cannot share the table. Nothing was run."
bash "$HERE/tools/hm64_coord_sync.sh" "$COORD" "$MACHINE" $$ </dev/null &
SYNC=$!
echo "  table sync with GitHub (branch lab-coord): running (pid $SYNC)"
cp "$HERE/lab/tools/pool_bench.py" "$LAB/tools/pool_bench.py"
PARTS=""
if [ "${HM64_PARTS_EVERY_MIN:-30}" != 0 ]; then
  bash "$HERE/tools/hm64_parts_sync.sh" "$MACHINE" "$LAB" $$ "${HM64_PARTS_EVERY_MIN:-30}" "results/spots/*/SP3_zones.jsonl" </dev/null &
  PARTS=$!
  echo "  this Mac's result parts go to GitHub every ${HM64_PARTS_EVERY_MIN:-30} min (branch lab-parts-$MACHINE; pid $PARTS)"
fi
if ! cmp -s "$HERE/lab/experiments/fullday_jobs.py" "$LAB/experiments/fullday_jobs.py"; then
  echo "  note: experiments/fullday_jobs.py in the lab differs from the fullday-2 copy the rainy casts were made with; the fullday-2 copy is used"
  cp "$HERE/lab/experiments/fullday_jobs.py" "$LAB/experiments/fullday_jobs.py"
fi
mkdir -p "$LAB/results/spots/plans" "$LAB/data/saves_dogspots" 2>/dev/null || true
chmod -R u+w "$LAB/data" 2>/dev/null || true
mkdir -p "$LAB/data/saves_dogspots"
for n in $NAMES; do cp "$HERE/plans/zone_plan_$(get LABEL $n).json.gz" "$LAB/results/spots/plans/"; done
chmod -R a+rwX "$LAB/states" "$LAB/results" 2>/dev/null || true
echo "  spot_jobs.py, spot_campaign.py, the plans -> $LAB"

cd "$LAB"
CUR=""
lab_run() {
  local envs=()
  while [ "$#" -gt 0 ] && [ "$1" != "--" ]; do envs+=("$1"); shift; done
  shift
  docker run --rm --platform linux/arm64 --shm-size 4g -v "$LAB:/work" -v "$LAB/data:/work/data:ro" -w /work \
    -e HM64_SRAM="/work/data/saves_dogspots/$CUR.SaveRAM" -e M64H_CPU=dynarec -e M64H_RECYCLE="${M64H_RECYCLE:-6}" \
    -e HM64_COORD_DIR=/work/results/spots/coord -e HM64_COORD_MACHINE="$MACHINE" -e HM64_COORD_ORDER="$ORDER" \
    -e HM64_COORD_CAMPAIGN="zones-$CUR" -e HM64_COORD_BLOCKS="${HM64_COORD_BLOCKS:-50}" -e HM64_COORD_LISTS="${HM64_COORD_LISTS:-1}" \
    ${envs[@]+"${envs[@]}"} hm64-lab:arm64 "$@" </dev/null
}
AUTOW=0
if [ -z "$WORKERS" ]; then
  AUTOW=1
  NCPU=$(lab_run -- nproc 2>/dev/null || echo 2)
  WORKERS=$(( NCPU > 1 ? NCPU - 1 : 1 ))
fi
echo "  workers  $WORKERS"

say "2/4 the saves, their dog-watch runs, beach savestates and pier-spot runs"
by_sha() {
  local want=$1 d f
  for d in "$HM64_DIR/sourcefiles" "$HOME/Downloads"; do
    [ -d "$d" ] || continue
    while IFS= read -r f; do
      case "$f" in */__MACOSX/*|*/._*) continue ;; esac
      if [ "$(sha "$f")" = "$want" ]; then printf '%s\n' "$f"; return 0; fi
    done < <(find -L "$d" -maxdepth 3 -type f \( -iname '*.SaveRAM' -o -iname '*.sra' -o -iname '*.srm' -o -iname '*.sav' \) 2>/dev/null | sort)
  done
  return 1
}
for n in $NAMES; do
  CUR=$(get LABEL $n); want=$(get SHA $n)
  S="$LAB/data/saves_dogspots/$CUR.SaveRAM"
  if [ ! -f "$S" ] || [ "$(sha "$S")" != "$want" ]; then
    f=$(by_sha "$want") || die "the save of $CUR (sha256 ${want:0:8}...) is neither in the lab ($S) nor in ~/Documents/hm64/sourcefiles or ~/Downloads - put it into ~/Documents/hm64/sourcefiles and run this again"
    rm -f "$S"; cp "$f" "$S"
    echo "  save     $CUR   <- $f"
  else
    echo "  save     $CUR   (in the lab, sha256 ok)"
  fi
  RES_L="results/$PRESET/$CUR"; STORE="states/$PRESET/$CUR"
  [ -f "$LAB/$RES_L/zz_lines.json" ] || die "the dog-watch results of $CUR are not in $LAB/$RES_L (zz_lines.json) - this run needs the rain120 run's folder. Tell Claude."
  NST=$(ls "$LAB/$STORE/b" 2>/dev/null | grep -c '\.st$' || true)
  [ "${NST:-0}" -gt 0 ] || die "the beach savestates of $CUR are not in $LAB/$STORE/b - the lines cannot be replayed. Tell Claude (the dog-watch run would have to be made again)."
  G="$LAB/results/spots/$CUR/sp_lines_summary.json"
  [ -f "$G" ] || die "the pier-spot run of $CUR is not in $LAB/results/spots/$CUR (sp_lines_summary.json) - run the pier-spots package first"
  if ! grep -q '"rep_differ": \[\]' "$G" || ! grep -q '"rep_no_row": 0' "$G" || ! grep -q '"job_errors": 0' "$G"; then die "the pier-spot run of $CUR did not pass its gate ($G). Tell Claude."; fi
  echo "           $NST beach savestates, the pier-spot run's gate passed, lines: $RES_L/zz_lines.json$( [ -f "$LAB/$RES_L/zz_lines.prefold.json" ] && echo ' (folded; the original zz_lines.prefold.json is used)')"
done

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
SEND="$RUN_ROOT/hm64-zones-$STAMP"
i=0
for n in $NAMES; do
  i=$((i + 1))
  CUR=$(get LABEL $n)
  RES_L="results/$PRESET/$CUR"; STORE="states/$PRESET/$CUR"; RES="results/spots/$CUR"
  ZZ=zz_lines.json; [ ! -f "$LAB/$RES_L/zz_lines.prefold.json" ] || ZZ=zz_lines.prefold.json
  CAMP="python3 tools/spot_campaign.py --src $RES_L --zz $ZZ --plan results/spots/plans/zone_plan_$CUR.json.gz --out $RES --workers $WORKERS"
  sprun() {
    lab_run -e HM64_ZZ_STORE="/work/$STORE" -e HM64_SP_MAX_LINES="${HM64_SP_MAX_LINES:-0}" -e HM64_SP_MAX_CASTS="${HM64_SP_MAX_CASTS:-0}" \
      -e HM64_ZZ_TEST_DOG= -- "$@"
  }
  mkdir -p "$LAB/$RES"; chmod -R a+rwX "$LAB/results/spots" 2>/dev/null || true
  say "3/4 [$i: $CUR] the recorded casts whose dog comes near a tile the zone treats differently, from the middle and the south zone ($(date '+%a %H:%M'))"
  T0=$(date +%s)
  if [ -f "$LAB/$RES/.done_zones" ]; then echo "  done before"
  else
    sprun $CAMP zones || die "$CUR: the zone casts stopped with job errors - see $LOG (the same command runs the failed jobs again)"
    touch "$LAB/$RES/.done_zones"
    echo "  zone casts: $(( ($(date +%s) - T0) / 60 )) min"
  fi
  say "4/4 [$i: $CUR] zip of this Mac's part (the report is made from all parts together)"
  cp "$LOG" "$LAB/$RES/run-zones-$STAMP.log" 2>/dev/null || true
  mkdir -p "$SEND"
  ( cd "$LAB/results/spots" && rm -f "$RUN_ROOT/hm64-zones-$CUR@$MACHINE.zip" && zip -q -9 "$RUN_ROOT/hm64-zones-$CUR@$MACHINE.zip" "$CUR/SP3_zones.jsonl" "$CUR/run-zones-$STAMP.log" ) || die "zip of $CUR failed"
  cp "$RUN_ROOT/hm64-zones-$CUR@$MACHINE.zip" "$SEND/"
  echo "  zip      $RUN_ROOT/hm64-zones-$CUR@$MACHINE.zip"
done
cp "$LOG" "$SEND/" 2>/dev/null || true

echo
echo "------------------------------------------------------------------------------------------------"
echo " CAMERA ZONES DONE   [$NAMES]   ($(( ($(date +%s) - T_ALL) / 60 )) min in all)"
echo "------------------------------------------------------------------------------------------------"
ls -l "$SEND" | awk 'NR > 1 {printf "    %-60s %6.1f MB\n", $9, $5 / 1048576}'
echo "  folder: $SEND   (no ROM / saves / savestates inside)"

rmdir "$LOCK" 2>/dev/null || true
if [ -n "${PARTS:-}" ]; then touch "$LAB/.parts_stop"; wait "$PARTS" 2>/dev/null || true; PARTS=""; fi
if [ -n "${SYNC:-}" ]; then touch "$COORD/.stop"; wait "$SYNC" 2>/dev/null || true; SYNC=""; fi
if [ "${HM64_SPOTS_NO_UPLOAD:-0}" != 1 ]; then
  T="$HM64_DIR/tools"; mkdir -p "$T"
  NEW=$(grep -m1 '^LABDATA_REV=' "$HERE/tools/hm64_labdata.sh" 2>/dev/null | cut -d'"' -f2 || true)
  OLD=""; [ ! -f "$T/hm64_labdata.sh" ] || OLD=$(grep -m1 '^LABDATA_REV=' "$T/hm64_labdata.sh" | cut -d'"' -f2 || true)
  if [ -n "$NEW" ] && [[ "$NEW" > "$OLD" ]]; then
    if [ -f "$T/hm64_labdata.sh" ]; then B="$HM64_DIR/backups/$(date +%Y%m%d-%H%M%S)_tools"; mkdir -p "$B"; cp "$T/hm64_labdata.sh" "$B/"; fi
    cp "$HERE/tools/hm64_labdata.sh" "$T/hm64_labdata.sh"
    echo "  lab-data script $NEW installed in $T"
  fi
  if [ -f "$T/hm64_labdata.sh" ]; then
    bash "$T/hm64_labdata.sh" </dev/null || echo "  warning: the results were NOT uploaded to the lab-data branch (see above); they are in $SEND. Try: bash $T/hm64_labdata.sh </dev/null"
  fi
fi
