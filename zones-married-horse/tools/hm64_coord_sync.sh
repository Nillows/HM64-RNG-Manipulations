#!/bin/bash
# HM64 lab: carry the machines' claim files to and from GitHub (branch lab-coord), every few seconds (2026-11-25).
# Each machine writes only <coord dir>/<campaign>/<its name>.claims, so two machines never edit the same file.
#   bash hm64_coord_sync.sh <coord dir> <machine name> [pid to follow]
# Ends when <coord dir>/.stop exists or the followed process is gone. Env: HM64_COORD_REMOTE, HM64_COORD_BRANCH,
# HM64_COORD_EVERY_S (30), HM64_COORD_CLONE, HM64_COORD_ONCE=1 (one round, for tests).
COORD_REV="2026-11-25a"
set -u
DIR=${1:-}; ME=${2:-}; FOLLOW=${3:-}
[ -n "$DIR" ] && [ -n "$ME" ] || { echo "usage: hm64_coord_sync.sh <coord dir> <machine name> [pid]" >&2; exit 2; }
REMOTE=${HM64_COORD_REMOTE:-git@github.com:Nillows/HM64-RNG-Manipulations.git}
BRANCH=${HM64_COORD_BRANCH:-lab-coord}
EVERY=${HM64_COORD_EVERY_S:-30}
CLONE=${HM64_COORD_CLONE:-$HOME/Documents/hm64/lab-coord}
KEY="$HOME/.ssh/hm64_github_ed25519"
if [ -f "$KEY" ]; then
  GIT_SSH_COMMAND="ssh -i '$KEY' -o IdentitiesOnly=yes -o BatchMode=yes -o ConnectTimeout=20"
  export GIT_SSH_COMMAND
fi
mkdir -p "$DIR"
note() { echo "  [coord $(date +%H:%M:%S)] $*"; }
g() { git -C "$CLONE" "$@"; }

make_clone() {
  if [ -d "$CLONE/.git" ]; then return 0; fi
  rm -rf "$CLONE.tmp"; mkdir -p "$(dirname "$CLONE")"
  if git clone -q --single-branch --branch "$BRANCH" "$REMOTE" "$CLONE.tmp" 2>/dev/null </dev/null; then
    mv "$CLONE.tmp" "$CLONE"
  else
    if ! git ls-remote "$REMOTE" >/dev/null 2>&1 </dev/null; then rm -rf "$CLONE.tmp"; return 1; fi
    rm -rf "$CLONE.tmp"; mkdir -p "$CLONE.tmp"
    git -C "$CLONE.tmp" init -q
    git -C "$CLONE.tmp" checkout -q --orphan "$BRANCH"
    git -C "$CLONE.tmp" remote add origin "$REMOTE"
    printf '%s\n' "Claim files of the HM64 lab machines (which machine works on which block of a campaign)." "Written by tools/hm64_coord_sync.sh. No results here: those are on the lab-data branch." > "$CLONE.tmp/README.md"
    git -C "$CLONE.tmp" add README.md
    git -C "$CLONE.tmp" -c user.name="hm64-lab" -c user.email="hm64-lab@users.noreply.github.com" commit -q -m "lab-coord: start"
    if ! git -C "$CLONE.tmp" push -q -u origin "$BRANCH" </dev/null 2>/dev/null; then
      rm -rf "$CLONE.tmp"
      git clone -q --single-branch --branch "$BRANCH" "$REMOTE" "$CLONE.tmp" </dev/null 2>/dev/null || { rm -rf "$CLONE.tmp"; return 1; }
    fi
    mv "$CLONE.tmp" "$CLONE"
  fi
  g config user.name "hm64-lab ($ME)"; g config user.email "hm64-lab@users.noreply.github.com"
  return 0
}

round() {
  make_clone || return 1
  local f rel d changed=0 n
  while IFS= read -r f; do
    rel=${f#"$DIR"/}
    d=$(dirname "$rel")
    mkdir -p "$CLONE/$d"
    if ! cmp -s "$f" "$CLONE/$rel"; then cp "$f" "$CLONE/$rel"; changed=1; fi
  done < <(find "$DIR" -mindepth 2 -maxdepth 2 -type f -name "$ME.claims" 2>/dev/null)
  if [ "$changed" = 1 ]; then
    g add -A . >/dev/null 2>&1
    g commit -q -m "$ME: claims $(date '+%Y-%m-%d %H:%M:%S')" >/dev/null 2>&1 || true
  fi
  n=0
  while :; do
    g pull -q --rebase origin "$BRANCH" </dev/null >/dev/null 2>&1 || { g rebase --abort >/dev/null 2>&1; return 1; }
    if [ -z "$(g log --oneline "origin/$BRANCH..HEAD" 2>/dev/null)" ]; then break; fi
    if g push -q origin "HEAD:$BRANCH" </dev/null >/dev/null 2>&1; then break; fi
    n=$((n + 1)); [ "$n" -lt 6 ] || return 1
    sleep 1
  done
  while IFS= read -r f; do
    rel=${f#"$CLONE"/}
    if [ "$(basename "$f")" = "$ME.claims" ]; then continue; fi
    d=$(dirname "$rel")
    mkdir -p "$DIR/$d"
    if ! cmp -s "$f" "$DIR/$rel"; then cp "$f" "$DIR/$rel.tmp.$$" && mv "$DIR/$rel.tmp.$$" "$DIR/$rel"; fi
  done < <(find "$CLONE" -mindepth 2 -maxdepth 2 -type f -name "*.claims" -not -path "*/.git/*" 2>/dev/null)
  date +%s > "$DIR/.sync_ok.tmp.$$" && mv "$DIR/.sync_ok.tmp.$$" "$DIR/.sync_ok"
  return 0
}

FAILS=0
note "machine $ME, branch $BRANCH, every $EVERY s (rev $COORD_REV)"
while :; do
  if round; then
    if [ "$FAILS" -ge 3 ]; then note "GitHub reached again"; fi
    FAILS=0
  else
    FAILS=$((FAILS + 1))
    if [ "$FAILS" = 3 ]; then note "cannot reach GitHub (network or SSH key): the run goes on; blocks may be done twice until it is back"; fi
  fi
  [ "${HM64_COORD_ONCE:-0}" != 1 ] || { [ "$FAILS" = 0 ]; exit $?; }
  [ ! -f "$DIR/.stop" ] || break
  if [ -n "$FOLLOW" ] && ! kill -0 "$FOLLOW" 2>/dev/null; then break; fi
  sleep "$EVERY"
done
round || true
note "ended"
