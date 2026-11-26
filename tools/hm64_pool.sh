#!/bin/bash
# HM64 lab pool (2026-11-25): the container and the campaigns live on GitHub; every Mac runs the same thing.
#
#   bash hm64_pool.sh image-push                      (main Mac) put the container hm64-lab:arm64 on branch lab-image
#   bash hm64_pool.sh base-push                       (main Mac) put the lab code (no ROM / saves / results) on lab-campaigns
#   bash hm64_pool.sh campaign-push <folder>          (main Mac) put a campaign folder (campaign.json + its files) on lab-campaigns
#   bash hm64_pool.sh list                            the campaigns on GitHub
#   bash hm64_pool.sh run <campaign> topdown|bottomup|middleout [workers]
#   bash hm64_pool.sh sync user@other-mac [campaign]  LAN: compare and copy sourcefiles/ and what a campaign needs from the main Mac
#
# ROM, saves in sourcefiles/ and savestates travel only over the LAN (sync) or by hand; never to GitHub.
POOL_REV="2026-11-25a"
set -u
CMD=${1:-}
[ $# -gt 0 ] && shift
HM64_DIR="$HOME/Documents/hm64"
LAB=${HM64_LAB:-$HM64_DIR/runs/dogspots/hm64-lab}
POOL="$HM64_DIR/pool"
REMOTE=${HM64_POOL_REMOTE:-git@github.com:Nillows/HM64-RNG-Manipulations.git}
RAW=${HM64_POOL_RAW:-https://raw.githubusercontent.com/Nillows/HM64-RNG-Manipulations/main}
TAG=hm64-lab:arm64
KEY="$HOME/.ssh/hm64_github_ed25519"
PATH="$PATH:/Applications/Docker.app/Contents/Resources/bin:/usr/local/bin:/opt/homebrew/bin"; export PATH
COPYFILE_DISABLE=1; export COPYFILE_DISABLE
if [ -f "$KEY" ]; then GIT_SSH_COMMAND="ssh -i '$KEY' -o IdentitiesOnly=yes -o BatchMode=yes -o ConnectTimeout=20"; export GIT_SSH_COMMAND; fi
say() { printf '\n==> %s\n' "$*"; }
die() { printf '\nSTOP: %s\n' "$*" >&2; exit 1; }
sha() { shasum -a 256 "$1" | cut -d' ' -f1; }
gitc() { git -c user.name="hm64-lab" -c user.email="hm64-lab@users.noreply.github.com" "$@"; }
forbidden() { grep -i -E '\.(z64|n64|v64|saveram|sra|srm|sav|st|state)$' || true; }
docker_up() {
  command -v docker >/dev/null 2>&1 || die "docker not found (is Docker Desktop installed?)"
  if docker info >/dev/null 2>&1; then return 0; fi
  open -a Docker >/dev/null 2>&1 || true
  local n=0
  until docker info >/dev/null 2>&1; do n=$((n + 1)); [ "$n" -lt 36 ] || die "Docker is not running and did not start in 3 minutes"; sleep 5; done
}
# fetch_branch BRANCH DIR: DIR becomes the newest commit of BRANCH (shallow); returns 1 if the branch does not exist
fetch_branch() {
  local b=$1 d=$2
  mkdir -p "$d"
  [ -d "$d/.git" ] || { git -C "$d" init -q && git -C "$d" remote add origin "$REMOTE"; }
  git -C "$d" remote set-url origin "$REMOTE"
  git -C "$d" fetch -q --depth 1 origin "$b" </dev/null 2>/dev/null || return 1
  git -C "$d" checkout -q -f --detach FETCH_HEAD && git -C "$d" clean -q -fdx
}
# push_one BRANCH DIR MESSAGE: DIR's files become ONE new commit that replaces the branch (no history kept)
push_orphan() {
  local b=$1 d=$2 m=$3
  rm -rf "$d/.git"; git -C "$d" init -q; git -C "$d" checkout -q --orphan "$b"
  git -C "$d" remote add origin "$REMOTE"; git -C "$d" add -A .
  gitc -C "$d" commit -q -m "$m" || die "nothing to commit in $d"
  git -C "$d" push -q -f origin "HEAD:$b" </dev/null || die "push to branch $b failed (network or this Mac's GitHub key)"
}
jget() { python3 -I -c 'import json,sys
d=json.load(open(sys.argv[1]))
for k in sys.argv[2].split("."):
    d=d[int(k)] if isinstance(d,list) else d.get(k,"")
    if d=="" : break
print(d if not isinstance(d,(dict,list)) else json.dumps(d))' "$1" "$2"; }

image_push() {
  docker_up
  local id w n
  id=$(docker image inspect "$TAG" --format '{{.Id}}' 2>/dev/null) || die "the image $TAG is not on this Mac"
  say "container $TAG ($id) -> branch lab-image"
  w="$POOL/image-out"; rm -rf "$w"; mkdir -p "$w"
  if fetch_branch lab-image "$POOL/image-in" && [ -f "$POOL/image-in/image.json" ] && [ "$(jget "$POOL/image-in/image.json" id)" = "$id" ]; then echo "  GitHub already has this container: nothing to do"; return 0; fi
  if docker run --rm "$TAG" sh -c 'find / -xdev -type f 2>/dev/null' | grep -v '^/var/lib/shells.state$' | forbidden | grep -q .; then die "the container holds a ROM / save / savestate file: it must not go to GitHub. Tell Claude."; fi
  echo "  saving and compressing (a minute or two) ..."
  docker save "$TAG" | gzip -6 > "$w/image.tar.gz" || die "docker save failed"
  ( cd "$w" && split -b 90m image.tar.gz image.tar.gz.part- && rm image.tar.gz ) || die "split failed"
  { printf '{"tag": "%s", "id": "%s", "made": "%s", "parts": [' "$TAG" "$id" "$(date '+%Y-%m-%d %H:%M')"; n=0
    for f in "$w"/image.tar.gz.part-*; do [ "$n" = 0 ] || printf ', '; printf '{"name": "%s", "sha256": "%s"}' "$(basename "$f")" "$(sha "$f")"; n=$((n + 1)); done
    printf ']}\n'; } > "$w/image.json"
  printf '%s\n' "The HM64 lab container ($TAG), compressed and split. Loaded by tools: bash hm64_pool.sh run ... (or: cat image.tar.gz.part-* | gunzip | docker load)." > "$w/README.md"
  push_orphan lab-image "$w" "container $id"
  echo "  pushed: $(ls "$w" | grep -c part-) parts, $(du -sh "$w" | cut -f1)"; rm -rf "$w"
}
image_ensure() {   # image_ensure [wanted id]
  docker_up
  local want=${1:-} have d f p s
  have=$(docker image inspect "$TAG" --format '{{.Id}}' 2>/dev/null || true)
  d="$POOL/image-in"
  if [ -n "$want" ] && [ "$have" = "$want" ]; then echo "  container: up to date ($have)"; return 0; fi
  fetch_branch lab-image "$d" || die "no container on GitHub yet (branch lab-image): on the main Mac run  bash hm64_pool.sh image-push"
  [ -z "$want" ] && want=$(jget "$d/image.json" id)
  [ "$(jget "$d/image.json" id)" = "$want" ] || die "GitHub's container ($(jget "$d/image.json" id)) is not the one this campaign names ($want): on the main Mac run  bash hm64_pool.sh image-push"
  if [ "$have" = "$want" ]; then echo "  container: up to date ($have)"; return 0; fi
  echo "  container: this Mac has ${have:-none}, the campaign wants $want -> loading it from GitHub's copy"
  python3 -I -c 'import json,sys
for p in json.load(open(sys.argv[1]))["parts"]: print(p["name"], p["sha256"])' "$d/image.json" > "$d/.parts" || die "image.json unreadable"
  while read -r p s; do [ "$(sha "$d/$p")" = "$s" ] || die "container part $p is damaged (sha256)"; done < "$d/.parts"
  ( cd "$d" && cat $(cut -d' ' -f1 .parts) ) | gunzip | docker load >/dev/null || die "docker load failed"
  have=$(docker image inspect "$TAG" --format '{{.Id}}' 2>/dev/null || true)
  [ "$have" = "$want" ] || die "the loaded container is $have, not $want"
  echo "  container: loaded ($have)"
}
camp_clone() {   # the lab-campaigns branch with history, pushable -> $POOL/campaigns
  local d="$POOL/campaigns"
  if [ -d "$d/.git" ]; then git -C "$d" fetch -q origin lab-campaigns </dev/null 2>/dev/null && git -C "$d" reset -q --hard origin/lab-campaigns && return 0; fi
  rm -rf "$d"; mkdir -p "$POOL"
  if git clone -q --single-branch --branch lab-campaigns "$REMOTE" "$d" </dev/null 2>/dev/null; then return 0; fi
  git ls-remote "$REMOTE" >/dev/null 2>&1 </dev/null || die "cannot reach GitHub (network or this Mac's GitHub key)"
  mkdir -p "$d"; git -C "$d" init -q; git -C "$d" checkout -q --orphan lab-campaigns; git -C "$d" remote add origin "$REMOTE"
  printf '%s\n' "HM64 lab campaigns: one folder per campaign (campaign.json + its files, MANIFEST.sha256), base/ = the lab code. No ROM, saves or savestates." > "$d/README.md"
  git -C "$d" add README.md; gitc -C "$d" commit -q -m "lab-campaigns: start"
  git -C "$d" push -q -u origin lab-campaigns </dev/null || die "push to lab-campaigns failed"
}
put_folder() {   # put_folder SRC NAME: SRC becomes campaigns/NAME with a manifest, committed and pushed
  local src=$1 name=$2 d
  camp_clone; d="$POOL/campaigns/$name"
  if ( cd "$src" && find . -type f ) | forbidden | grep -q .; then die "$src holds a ROM / save / savestate file: not uploaded. $( (cd "$src" && find . -type f) | forbidden | head -n 3 | tr '\n' ' ')"; fi
  rm -rf "$d"; mkdir -p "$d"; ( cd "$src" && tar cf - --exclude .git --exclude __pycache__ --exclude .DS_Store . ) | ( cd "$d" && tar xf - )
  ( cd "$d" && find . -type f ! -name MANIFEST.sha256 | sort | while IFS= read -r f; do printf '%s  %s\n' "$(sha "$f")" "$f"; done > MANIFEST.sha256 )
  git -C "$POOL/campaigns" add -A "$name"
  if git -C "$POOL/campaigns" diff --cached --quiet; then echo "  GitHub already has exactly this: nothing to do"; return 0; fi
  gitc -C "$POOL/campaigns" commit -q -m "$name: $(date '+%Y-%m-%d %H:%M')"
  git -C "$POOL/campaigns" push -q origin lab-campaigns </dev/null || die "push to lab-campaigns failed"
  echo "  pushed $name ($(wc -l < "$d/MANIFEST.sha256" | tr -d ' ') files, $(du -sh "$d" | cut -f1))"
}
check_manifest() { ( cd "$1" && shasum -a 256 -c MANIFEST.sha256 >/dev/null 2>&1 ) || die "$1 does not match its MANIFEST.sha256 (damaged download?)"; }
base_push() {
  [ -d "$LAB" ] || die "no lab work folder here ($LAB)"
  say "lab code of $LAB -> lab-campaigns/base"
  local w="$POOL/base-out"; rm -rf "$w"; mkdir -p "$w"
  ( cd "$LAB" && tar czf "$w/hm64-lab-code.tar.gz" --exclude ./data --exclude ./results --exclude ./states --exclude '__pycache__' --exclude '.running' --exclude '*.z64' --exclude '*.SaveRAM' --exclude '*.st' --exclude '*.state' --exclude '*.sra' . ) || die "tar failed"
  if tar tzf "$w/hm64-lab-code.tar.gz" | forbidden | grep -q .; then die "the code bundle would hold a ROM / save / savestate: $(tar tzf "$w/hm64-lab-code.tar.gz" | forbidden | head -n 3 | tr '\n' ' ')"; fi
  [ "$(wc -c < "$w/hm64-lab-code.tar.gz")" -lt 94000000 ] || die "the code bundle is over 94 MB ($(du -sh "$w/hm64-lab-code.tar.gz" | cut -f1)): tell Claude what is in $LAB"
  put_folder "$w" base; rm -rf "$w"
  say "this script -> lab-campaigns/tools (so any Mac can fetch it)"
  mkdir -p "$w"; cp "$0" "$w/hm64_pool.sh"; put_folder "$w" tools; rm -rf "$w"
}
find_rom() {     # find_rom SHA: path of a file with that sha256 in sourcefiles/ or the lab
  local want=$1 f
  if [ -f "$LAB/data/rom/Harvest_Moon_64_USA.z64" ] && [ "$(sha "$LAB/data/rom/Harvest_Moon_64_USA.z64")" = "$want" ]; then printf '%s\n' "$LAB/data/rom/Harvest_Moon_64_USA.z64"; return 0; fi
  while IFS= read -r f; do if [ "$(sha "$f")" = "$want" ]; then printf '%s\n' "$f"; return 0; fi; done < <(find -L "$HM64_DIR/sourcefiles" -maxdepth 3 -type f \( -iname '*.z64' -o -iname '*.n64' \) 2>/dev/null)
  return 1
}
run_campaign() {
  local name=${1:-} order=${2:-} workers=${3:-} c j f s p want rom n i
  case "$order" in topdown|bottomup|middleout) ;; *) die "usage: bash hm64_pool.sh run <campaign> topdown|bottomup|middleout [workers]" ;; esac
  [ ! -d "$HM64_DIR/runs/dogspots/.running" ] || die "a lab run is going on this Mac ($HM64_DIR/runs/dogspots/.running): one at a time. If none is running, delete that folder."
  say "campaign $name ($order) on $(scutil --get LocalHostName 2>/dev/null || hostname -s)   pool script $POOL_REV"
  camp_clone; c="$POOL/campaigns/$name"; j="$c/campaign.json"
  [ -f "$j" ] || die "no campaign '$name' on GitHub. There are: $(cd "$POOL/campaigns" && ls -d */ 2>/dev/null | tr -d / | grep -v -E '^(base|tools)$' | tr '\n' ' ')"
  check_manifest "$c"
  echo "  $(jget "$j" title)   (version $(jget "$j" version))"
  say "1/4 the container"
  image_ensure "$(jget "$j" image.id)"
  say "2/4 the lab code"
  want=$(jget "$j" base_sha256)
  [ -f "$POOL/campaigns/base/hm64-lab-code.tar.gz" ] || die "no lab code on GitHub (lab-campaigns/base): on the main Mac run  bash hm64_pool.sh base-push"
  check_manifest "$POOL/campaigns/base"
  [ -z "$want" ] || [ "$(sha "$POOL/campaigns/base/hm64-lab-code.tar.gz")" = "$want" ] || die "GitHub's lab code is not the version this campaign names: on the main Mac run base-push and campaign-push again"
  mkdir -p "$LAB"
  if [ -f "$LAB/.pool_base" ] && [ "$(cat "$LAB/.pool_base")" = "$(sha "$POOL/campaigns/base/hm64-lab-code.tar.gz")" ]; then echo "  lab code: up to date"
  elif [ -f "$LAB/tools/zigzag_campaign.py" ] && [ ! -f "$LAB/.pool_base" ] && [ "${HM64_POOL_KEEP_LAB:-1}" = 1 ]; then echo "  lab code: this Mac has its own lab folder (not from GitHub): kept as it is"
  else ( cd "$LAB" && tar xzf "$POOL/campaigns/base/hm64-lab-code.tar.gz" ) || die "unpacking the lab code failed"; sha "$POOL/campaigns/base/hm64-lab-code.tar.gz" > "$LAB/.pool_base"; echo "  lab code: installed from GitHub"; fi
  say "3/4 ROM, saves, and what this campaign needs from the main Mac"
  want=$(jget "$j" rom_sha256)
  rom=$(find_rom "$want") || die "the ROM (sha256 ${want:0:12}...) is not on this Mac: put it into ~/Documents/hm64/sourcefiles/ and run this again"
  mkdir -p "$LAB/data/rom"; chmod -R u+w "$LAB/data" 2>/dev/null || true
  [ "$rom" = "$LAB/data/rom/Harvest_Moon_64_USA.z64" ] || cp "$rom" "$LAB/data/rom/Harvest_Moon_64_USA.z64"
  echo "  ROM: sha256 ok"
  n=$(python3 -I -c 'import json,sys; print(len(json.load(open(sys.argv[1])).get("saves",[])))' "$j")
  i=0
  while [ "$i" -lt "$n" ]; do
    f=$(jget "$j" "saves.$i.file"); s=$(jget "$j" "saves.$i.sha256"); p=$(jget "$j" "saves.$i.repo_path")
    mkdir -p "$HM64_DIR/sourcefiles/pool"
    if [ -n "$(find -L "$HM64_DIR/sourcefiles" "$LAB/data/saves_dogspots" -maxdepth 3 -type f 2>/dev/null | while IFS= read -r x; do [ "$(sha "$x")" = "$s" ] && { echo y; break; }; done)" ]; then echo "  save $f: on this Mac"
    elif [ -n "$p" ] && curl -fsSL --max-time 60 "$RAW/$(printf '%s' "$p" | sed 's/ /%20/g')" -o "$HM64_DIR/sourcefiles/pool/$f" 2>/dev/null && [ "$(sha "$HM64_DIR/sourcefiles/pool/$f")" = "$s" ]; then echo "  save $f: fetched from the repo's $p"
    else rm -f "$HM64_DIR/sourcefiles/pool/$f"; die "the save $f (sha256 ${s:0:12}...) is not on this Mac and not at $p in the repo: copy it into ~/Documents/hm64/sourcefiles/ (or run  bash hm64_pool.sh sync  from the main Mac)"; fi
    i=$((i + 1))
  done
  n=$(python3 -I -c 'import json,sys; print(len(json.load(open(sys.argv[1])).get("needs",[])))' "$j")
  i=0
  while [ "$i" -lt "$n" ]; do
    p=$(jget "$j" "needs.$i")
    [ -e "$LAB/$p" ] || echo "  note: $p is not on this Mac (comes from the main Mac:  bash hm64_pool.sh sync user@this-mac $name ). The runner says what it can do without it."
    i=$((i + 1))
  done
  say "4/4 the run"
  f=$(jget "$j" runner)
  [ -f "$c/$f" ] || die "the campaign has no runner $f"
  w="$POOL/run/$name"; rm -rf "$w"; mkdir -p "$w"; ( cd "$c" && tar cf - . ) | ( cd "$w" && tar xf - )
  cd "$w" || die "no $w"
  exec bash "$f" "$order" $workers </dev/null
}
manifest_of() { ( cd "$1" 2>/dev/null && find . -type f ! -name '.DS_Store' | sort | while IFS= read -r f; do printf '%s  %s\n' "$(shasum -a 256 "$f" | cut -d' ' -f1)" "$f"; done ); }
sync_lan() {
  local R=${1:-} name=${2:-} RL='Documents/hm64' a b n p
  [ -n "$R" ] || die "usage: bash hm64_pool.sh sync user@other-mac [campaign]"
  mkdir -p "$HOME/.ssh"
  rs() { ssh -o ConnectTimeout=15 -o ControlMaster=auto -o ControlPath="$HOME/.ssh/hm64-cm-%C" -o ControlPersist=600 "$R" "$@"; }
  say "sourcefiles: this Mac <-> $R"
  rs 'echo "  reached $(hostname -s)"' </dev/null || die "cannot reach $R over ssh"
  a="$POOL/.sf_here"; b="$POOL/.sf_there"; mkdir -p "$POOL" "$HM64_DIR/sourcefiles"
  manifest_of "$HM64_DIR/sourcefiles" > "$a"
  rs "mkdir -p '$RL/sourcefiles' && cd '$RL/sourcefiles' && find . -type f ! -name '.DS_Store' | sort | while IFS= read -r f; do printf '%s  %s\n' \"\$(shasum -a 256 \"\$f\" | cut -d' ' -f1)\" \"\$f\"; done" </dev/null > "$b" || die "could not list sourcefiles on $R"
  python3 -I - "$a" "$b" "$POOL/.sf_plan" <<'PY' || die "sourcefiles differ in content (see above): nothing was copied. Decide which copy is right, fix it by hand, run this again."
import sys
def L(p):
    d = {}
    for ln in open(p, encoding="utf-8", errors="replace"):
        ln = ln.rstrip("\n")
        if "  " in ln:
            h, f = ln.split("  ", 1); d[f] = h
    return d
a, b = L(sys.argv[1]), L(sys.argv[2])
clash = sorted(f for f in a if f in b and a[f] != b[f])
to, frm = sorted(f for f in a if f not in b), sorted(f for f in b if f not in a)
print(f"  same on both: {sum(1 for f in a if b.get(f) == a[f])}   only here: {len(to)}   only there: {len(frm)}   different content: {len(clash)}")
for f in clash: print(f"  DIFFERENT: {f}   here {a[f][:12]}...  there {b[f][:12]}...")
with open(sys.argv[3] + ".to", "w") as o: o.write("".join(f + "\n" for f in to))
with open(sys.argv[3] + ".from", "w") as o: o.write("".join(f + "\n" for f in frm))
sys.exit(3 if clash else 0)
PY
  if [ -s "$POOL/.sf_plan.to" ]; then ( cd "$HM64_DIR/sourcefiles" && tar cf - -T "$POOL/.sf_plan.to" ) | rs "cd '$RL/sourcefiles' && tar xf -" || die "copy to $R failed"; echo "  copied to $R: $(wc -l < "$POOL/.sf_plan.to" | tr -d ' ') files"; fi
  if [ -s "$POOL/.sf_plan.from" ]; then rs "cd '$RL/sourcefiles' && tar cf - -T -" < "$POOL/.sf_plan.from" | ( cd "$HM64_DIR/sourcefiles" && tar xf - ) || die "copy from $R failed"; echo "  copied from $R: $(wc -l < "$POOL/.sf_plan.from" | tr -d ' ') files"; fi
  [ -n "$name" ] || return 0
  camp_clone; [ -f "$POOL/campaigns/$name/campaign.json" ] || die "no campaign '$name' on GitHub"
  say "what campaign $name needs from this Mac -> $R"
  n=$(python3 -I -c 'import json,sys; print(len(json.load(open(sys.argv[1])).get("needs",[])))' "$POOL/campaigns/$name/campaign.json")
  i=0
  while [ "$i" -lt "$n" ]; do
    p=$(jget "$POOL/campaigns/$name/campaign.json" "needs.$i"); i=$((i + 1))
    if [ ! -e "$LAB/$p" ]; then echo "  $p: not on this Mac (yet)"; continue; fi
    a=$(manifest_of "$LAB/$p" | shasum -a 256 | cut -d' ' -f1)
    b=$(rs "cd '$RL/runs/dogspots/hm64-lab/$p' 2>/dev/null && find . -type f ! -name '.DS_Store' | sort | while IFS= read -r f; do printf '%s  %s\n' \"\$(shasum -a 256 \"\$f\" | cut -d' ' -f1)\" \"\$f\"; done | shasum -a 256 | cut -d' ' -f1" </dev/null || true)
    if [ "$a" = "$b" ]; then echo "  $p: identical on both"; continue; fi
    rs "mkdir -p '$RL/runs/dogspots/hm64-lab'" </dev/null
    ( cd "$LAB" && tar cf - "$p" ) | rs "cd '$RL/runs/dogspots/hm64-lab' && tar xf -" || die "copy of $p failed"
    echo "  $p: copied ($(du -sh "$LAB/$p" | cut -f1))"
  done
}
case "$CMD" in
  image-push) image_push ;;
  base-push) base_push ;;
  campaign-push) [ -f "${1:-}/campaign.json" ] || die "usage: bash hm64_pool.sh campaign-push <folder with campaign.json>"; n=$(jget "$1/campaign.json" name); [ -n "$n" ] || die "campaign.json has no name"; say "campaign $n -> lab-campaigns"; put_folder "$1" "$n" ;;
  list) camp_clone; for d in "$POOL/campaigns"/*/; do [ -f "$d/campaign.json" ] && echo "  $(jget "$d/campaign.json" name)   $(jget "$d/campaign.json" version)   $(jget "$d/campaign.json" title)"; done ;;
  run) run_campaign "$@" ;;
  sync) sync_lan "$@" ;;
  *) sed -n '2,12p' "$0"; exit 2 ;;
esac
