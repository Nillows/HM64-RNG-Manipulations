#!/bin/bash
# HM64 lab: while a run is going, put this Mac's result parts on GitHub every so often (2026-11-25).
#   bash hm64_parts_sync.sh <machine> <lab folder> <pid to follow> <minutes> <pattern> [pattern ...]
# Patterns are paths inside the lab folder, wildcards allowed (quote them): "results/fullday/married-*/FD_casts_b*.jsonl".
# Each matching file is copied, gzipped and pushed to the branch lab-parts-<machine> as ONE commit that replaces the
# last (no history, no clash with other Macs). A file being written is fine: a half-written last line is skipped by
# every reader. Files over 90 MB compressed are left out (said in the log). Never ROM / saves / savestates: only the
# named result files. Ends when <lab>/.parts_stop exists or the followed process is gone (after one last round).
PARTS_REV="2026-11-25a"
set -u
ME=${1:-}; LAB=${2:-}; FOLLOW=${3:-}; EVERY=${4:-30}
[ -n "$ME" ] && [ -d "$LAB" ] && [ $# -ge 5 ] || { echo "usage: hm64_parts_sync.sh <machine> <lab folder> <pid> <minutes> <pattern>..." >&2; exit 2; }
shift 4
REMOTE=${HM64_COORD_REMOTE:-git@github.com:Nillows/HM64-RNG-Manipulations.git}
BRANCH="lab-parts-$ME"
W=${HM64_PARTS_DIR:-$HOME/Documents/hm64/lab-parts}
KEY="$HOME/.ssh/hm64_github_ed25519"
if [ -f "$KEY" ]; then GIT_SSH_COMMAND="ssh -i '$KEY' -o IdentitiesOnly=yes -o BatchMode=yes -o ConnectTimeout=20"; export GIT_SSH_COMMAND; fi
note() { echo "  [parts $(date +%H:%M:%S)] $*"; }
round() {
  local pat f rel n=0 skipped="" sum
  rm -rf "$W.new"; mkdir -p "$W.new"
  for pat in "$@"; do
    for f in "$LAB"/$pat; do
      [ -f "$f" ] || continue
      rel=${f#"$LAB"/}
      mkdir -p "$W.new/$(dirname "$rel")"
      cp "$f" "$W.new/$rel" && gzip -n -6 -f "$W.new/$rel" || continue
      if [ "$(wc -c < "$W.new/$rel.gz")" -gt 94000000 ]; then rm -f "$W.new/$rel.gz"; skipped="$skipped $rel"; continue; fi
      n=$((n + 1))
    done
  done
  [ "$n" -gt 0 ] || { rm -rf "$W.new"; return 0; }
  sum=$(cd "$W.new" && find . -type f -name '*.gz' | sort | xargs shasum -a 256 | shasum -a 256 | cut -d' ' -f1)
  if [ -f "$W.sum" ] && [ "$(cat "$W.sum")" = "$sum" ]; then rm -rf "$W.new"; return 0; fi
  printf '%s\n' "Result parts of the lab run on $ME, as of $(date '+%Y-%m-%d %H:%M'). Each file: gunzip, one JSON row per line; merge parts of several Macs with tools/pool_merge.py." > "$W.new/README.md"
  ( cd "$W.new" && git init -q && git checkout -q --orphan "$BRANCH" && git remote add origin "$REMOTE" && git add -A . && \
    git -c user.name="hm64-lab ($ME)" -c user.email="hm64-lab@users.noreply.github.com" commit -q -m "$ME: $n result files, $(date '+%Y-%m-%d %H:%M')" && \
    git push -q -f origin "HEAD:$BRANCH" </dev/null ) >/dev/null 2>&1 || { rm -rf "$W.new"; return 1; }
  echo "$sum" > "$W.sum"; rm -rf "$W.new"
  note "$n result files on GitHub (branch $BRANCH)$( [ -z "$skipped" ] || echo "; over 90 MB, left out:$skipped" )"
  return 0
}
rm -f "$LAB/.parts_stop" "$W.sum"
note "machine $ME, every $EVERY min (rev $PARTS_REV)"
T=0
while :; do
  if [ "${HM64_PARTS_ONCE:-0}" = 1 ]; then round "$@"; exit $?; fi
  sleep 20; T=$((T + 20))
  STOP=0
  [ ! -f "$LAB/.parts_stop" ] || STOP=1
  if [ -n "$FOLLOW" ] && ! kill -0 "$FOLLOW" 2>/dev/null; then STOP=1; fi
  if [ "$STOP" = 1 ] || [ "$T" -ge $((EVERY * 60)) ]; then
    T=0
    round "$@" || note "could not reach GitHub this time (the run goes on)"
  fi
  [ "$STOP" = 0 ] || break
done
note "ended"
