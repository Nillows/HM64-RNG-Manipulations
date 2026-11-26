#!/usr/bin/env bash
# HM64 Power Nut lab - GAP CAMPAIGN ON THE RAINY FILES (2026-11-26, Thomas: "until we know they are reliable, unreliable,
# and why"). v32.23 gave every camera zone of the dock end its own table; this run measures what those tables still
# mark "not proven", and why casts differ between zones. Plan made by Claude (plans/gap_plan_<label>.json.gz, every job
# spelled out). For each rainy save (no horse 8e972d75, horse 287c11a6), on the folders of its dog-watch run:
#   gate  every Mac for itself: the chosen members of the part-A lines show the recorded dog for 8 s, and casts at the
#         recorded spot give the recorded bites. If it fails, part A is skipped on that Mac and the run says so.
#   A     the lines never cast away from the north zone (3 + 1), from a member standing in each zone
#   B1    recorded Nuts after the measured part of a cast, held to the Nut's bite + margin
#   C     a per-frame trace of a sample of casts that differ, from the north spot and from the zone
#   B2    every cast a zone measured with other bites, held on to 170 s after READY (the long part: last)
# The small parts of BOTH saves come first, B2 last. Nothing of the earlier runs is changed.
# Native ARM image only. The Mac is kept awake (caffeinate -dims). Queues behind another lab run.
#
# SHARED: several Macs fill ONE table per part and save (lists gaps-<label>.<part> on branch lab-coord):
#
#   bash run_hm64_gaps.sh topdown|bottomup|middleout [workers]
#
# Each Mac uploads its own part: runs/hm64-gaps-<label>@<machine>.zip (and, every 30 min while running, its result
# files to branch lab-parts-<machine>). The tables are rebuilt after the parts are merged (Claude).
# Ctrl-C any time; the same command continues where it stopped.
# Env: HM64_RUN_ROOT, HM64_SPOTS_ONLY=nohorse|horse, HM64_SPOTS_WAIT=0, HM64_SPOTS_NO_UPLOAD=1, HM64_GAP_PARTS="A B1 C B2",
# M64H_RECYCLE; test knobs (sandbox only): HM64_SPOTS_PRESET, HM64_GAP_MAX_JOBS, HM64_SPOTS_MIN_GB.
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
case "$ORDER" in up|down|middle) ;; *) die "say which way this Mac works through the table: bash run_hm64_gaps.sh topdown|bottomup|middleout [workers]" ;; esac
MACHINE=${HM64_MACHINE:-$(scutil --get LocalHostName 2>/dev/null || hostname -s 2>/dev/null || echo mac)}
MACHINE=$(printf '%s' "$MACHINE" | tr 'A-Z' 'a-z' | tr -c 'a-z0-9-' '-' | sed 's/--*/-/g; s/^-//; s/-$//')
[ -n "$MACHINE" ] || die "no machine name (set HM64_MACHINE)"
case "$ONLY" in both) NAMES="nohorse horse" ;; nohorse|horse) NAMES=$ONLY ;; *) die "HM64_SPOTS_ONLY must be nohorse, horse or both (got $ONLY)" ;; esac
sha() { shasum -a 256 "$1" | cut -d' ' -f1; }
get() { eval "printf '%s' \"\${$1_$2:-}\""; }
for f in lab/experiments/spot_jobs.py lab/experiments/gap_jobs.py lab/tools/spot_campaign.py lab/tools/gap_campaign.py lab/tools/coord.py lab/tools/pool_bench.py tools/hm64_coord_sync.sh tools/hm64_parts_sync.sh lab/experiments/fullday_jobs.py; do [ -f "$HERE/$f" ] || die "$f is not next to this script ($HERE)"; done
for n in $NAMES; do [ -f "$HERE/plans/gap_plan_$(get LABEL $n).json.gz" ] || die "plans/gap_plan_$(get LABEL $n).json.gz is not next to this script"; done

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
LOG="$WORK/run-gaps-$STAMP.log"
exec > >(tee -a "$LOG") 2>&1
T_ALL=$(date +%s)
say "gap campaign on the rainy files (parts A, B1, C, B2), SHARED: this Mac = $MACHINE, direction $ORDER; saves [$NAMES], work folder $LAB (native ARM image)  $(date '+%a %H:%M')"
if [ -n "$CAF" ]; then echo "  keeping the Mac awake: caffeinate -dims (pid $CAF) until this script ends"; else echo "  (no caffeinate on this machine: nothing keeps it awake)"; fi
FREE_GB=$(df -Pk "$WORK" | awk 'NR==2 {print int($4 / 1048576)}')
echo "  free disk: ${FREE_GB} GB"
[ "${FREE_GB:-0}" -ge "${HM64_SPOTS_MIN_GB:-5}" ] || die "less than ${HM64_SPOTS_MIN_GB:-5} GB free on the disk of $WORK"

say "1/5 lab files"
for f in experiments/spot_jobs.py experiments/gap_jobs.py tools/spot_campaign.py tools/gap_campaign.py tools/coord.py; do cp "$HERE/lab/$f" "$LAB/$f"; done
mkdir -p "$LAB/results/gaps"
COORD="$LAB/results/gaps/coord"
mkdir -p "$COORD"; rm -f "$COORD/.stop" "$COORD/.sync_ok"
HM64_COORD_ONCE=1 bash "$HERE/tools/hm64_coord_sync.sh" "$COORD" "$MACHINE" </dev/null || die "cannot reach the lab-coord branch on GitHub (network, or this Mac's key ~/.ssh/hm64_github_ed25519). Without it the Macs cannot share the table. Nothing was run."
bash "$HERE/tools/hm64_coord_sync.sh" "$COORD" "$MACHINE" $$ </dev/null &
SYNC=$!
echo "  table sync with GitHub (branch lab-coord): running (pid $SYNC)"
cp "$HERE/lab/tools/pool_bench.py" "$LAB/tools/pool_bench.py"
PARTS=""
if [ "${HM64_PARTS_EVERY_MIN:-30}" != 0 ]; then
  bash "$HERE/tools/hm64_parts_sync.sh" "$MACHINE" "$LAB" $$ "${HM64_PARTS_EVERY_MIN:-30}" "results/gaps/*/G*.jsonl" "results/gaps/*/GA_gate.json" </dev/null &
  PARTS=$!
  echo "  this Mac's result parts go to GitHub every ${HM64_PARTS_EVERY_MIN:-30} min (branch lab-parts-$MACHINE; pid $PARTS)"
fi
if ! cmp -s "$HERE/lab/experiments/fullday_jobs.py" "$LAB/experiments/fullday_jobs.py"; then
  echo "  note: experiments/fullday_jobs.py in the lab differs from the fullday-2 copy the rainy casts were made with; the fullday-2 copy is used"
  cp "$HERE/lab/experiments/fullday_jobs.py" "$LAB/experiments/fullday_jobs.py"
fi
mkdir -p "$LAB/results/gaps/plans" "$LAB/data/saves_dogspots" 2>/dev/null || true
chmod -R u+w "$LAB/data" 2>/dev/null || true
mkdir -p "$LAB/data/saves_dogspots"
for n in $NAMES; do cp "$HERE/plans/gap_plan_$(get LABEL $n).json.gz" "$LAB/results/gaps/plans/"; done
chmod -R a+rwX "$LAB/states" "$LAB/results" 2>/dev/null || true
echo "  spot_jobs.py, gap_jobs.py, spot_campaign.py, gap_campaign.py, the plans -> $LAB"

cd "$LAB"
CUR=""
lab_run() {
  local envs=()
  while [ "$#" -gt 0 ] && [ "$1" != "--" ]; do envs+=("$1"); shift; done
  shift
  docker run --rm --platform linux/arm64 --shm-size 4g -v "$LAB:/work" -v "$LAB/data:/work/data:ro" -w /work \
    -e HM64_SRAM="/work/data/saves_dogspots/$CUR.SaveRAM" -e M64H_CPU=dynarec -e M64H_RECYCLE="${M64H_RECYCLE:-6}" \
    -e HM64_COORD_DIR=/work/results/gaps/coord -e HM64_COORD_MACHINE="$MACHINE" -e HM64_COORD_ORDER="$ORDER" \
    -e HM64_COORD_CAMPAIGN="gaps-$CUR" -e HM64_COORD_BLOCKS="${HM64_COORD_BLOCKS:-50}" -e HM64_COORD_LISTS="${HM64_COORD_LISTS:-1}" \
    ${envs[@]+"${envs[@]}"} hm64-lab:arm64 "$@" </dev/null
}
AUTOW=0
if [ -z "$WORKERS" ]; then
  AUTOW=1
  NCPU=$(lab_run -- nproc 2>/dev/null || echo 2)
  WORKERS=$(( NCPU > 1 ? NCPU - 1 : 1 ))
fi
echo "  workers  $WORKERS"

say "2/5 the saves, their dog-watch runs, beach savestates and pier-spot runs"
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
SEND="$RUN_ROOT/hm64-gaps-$STAMP"
PARTLIST=${HM64_GAP_PARTS:-A B1 C B2}
camp() {   # camp LABEL STAGE: one stage of tools/gap_campaign.py for one save
  CUR=$1
  local RES_L="results/$PRESET/$CUR" STORE="states/$PRESET/$CUR" ZZ=zz_lines.json
  [ ! -f "$LAB/$RES_L/zz_lines.prefold.json" ] || ZZ=zz_lines.prefold.json
  mkdir -p "$LAB/results/gaps/$CUR"; chmod -R a+rwX "$LAB/results/gaps" 2>/dev/null || true
  lab_run -e HM64_ZZ_STORE="/work/$STORE" -e HM64_GAP_MAX_JOBS="${HM64_GAP_MAX_JOBS:-0}" -e HM64_ZZ_TEST_DOG= -- \
    python3 tools/gap_campaign.py --src "$RES_L" --zz "$ZZ" --plan "results/gaps/plans/gap_plan_$CUR.json.gz" --out "results/gaps/$CUR" --workers "$WORKERS" "$2"
}
say "3/5 the gate: this Mac on the recorded lines ($(date '+%a %H:%M'))"
GATE_BAD=""
for n in $NAMES; do
  CUR=$(get LABEL $n); rc=0
  camp "$CUR" gate || rc=$?
  if [ "$rc" = 3 ]; then GATE_BAD="$GATE_BAD $n"; echo "  GATE FAILED for $CUR: part A is skipped on this Mac. Tell Claude (results/gaps/$CUR/GA_gate.json)."
  elif [ "$rc" != 0 ]; then die "$CUR: the gate stopped (exit $rc) - see $LOG"; fi
done
say "4/5 the parts, small ones first: $PARTLIST"
for part in $PARTLIST; do
  for n in $NAMES; do
    CUR=$(get LABEL $n)
    if [ "$part" = A ]; then
      skip=no
      for b in $GATE_BAD; do [ "$b" != "$n" ] || skip=yes; done
      if [ "$skip" = yes ]; then echo "  [$part: $CUR] skipped: the gate failed on this Mac"; continue; fi
    fi
    if [ -f "$LAB/results/gaps/$CUR/.done_$part" ]; then echo "  [$part: $CUR] done before"; continue; fi
    echo; echo "  --- part $part, $CUR ($(date '+%a %H:%M'))"
    T0=$(date +%s)
    if [ "$part" = C ]; then
      camp "$CUR" "$part" || { echo "  WARNING: part C (the traces) of $CUR stopped with job errors - the run goes on with the next part; tell Claude ($LOG)"; continue; }
    else
      camp "$CUR" "$part" || die "$CUR: part $part stopped with job errors - see $LOG (the same command runs the failed jobs again)"
    fi
    touch "$LAB/results/gaps/$CUR/.done_$part"
    echo "  part $part, $CUR: $(( ($(date +%s) - T0) / 60 )) min"
  done
done
say "5/5 zips of this Mac's part"
mkdir -p "$SEND"
for n in $NAMES; do
  CUR=$(get LABEL $n)
  cp "$LOG" "$LAB/results/gaps/$CUR/run-gaps-$STAMP.log" 2>/dev/null || true
  ( cd "$LAB/results/gaps" && rm -f "$RUN_ROOT/hm64-gaps-$CUR@$MACHINE.zip" && zip -q -9 "$RUN_ROOT/hm64-gaps-$CUR@$MACHINE.zip" "$CUR"/G*.jsonl "$CUR"/GA_gate.json "$CUR/run-gaps-$STAMP.log" ) || die "zip of $CUR failed"
  cp "$RUN_ROOT/hm64-gaps-$CUR@$MACHINE.zip" "$SEND/"
  echo "  zip      $RUN_ROOT/hm64-gaps-$CUR@$MACHINE.zip"
done
cp "$LOG" "$SEND/" 2>/dev/null || true

echo
echo "------------------------------------------------------------------------------------------------"
echo " GAP CAMPAIGN DONE ON THIS MAC   [$NAMES]   ($(( ($(date +%s) - T_ALL) / 60 )) min in all)$( [ -z "$GATE_BAD" ] || echo "   GATE FAILED:$GATE_BAD" )"
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
