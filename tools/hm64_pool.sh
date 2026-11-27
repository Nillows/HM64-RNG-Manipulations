#!/bin/bash
# HM64 lab pool (2026-11-25): the container and the campaigns live on GitHub; every Mac runs the same thing.
#
#   bash hm64_pool.sh image-push                      (main Mac) put the container hm64-lab:arm64 on branch lab-image
#   bash hm64_pool.sh base-push                       (main Mac) put the lab code (no ROM / saves / results) on lab-campaigns
#   bash hm64_pool.sh campaign-push <folder>          (main Mac) put a campaign folder (campaign.json + its files) on lab-campaigns
#   bash hm64_pool.sh list                            the campaigns on GitHub
#   bash hm64_pool.sh run <campaign> topdown|bottomup|middleout [workers]
#   bash hm64_pool.sh sync user@other-mac [campaign]  LAN: compare and copy sourcefiles/ and what a campaign needs from the main Mac
#   bash hm64_pool.sh pull user@main-mac [campaign]   LAN, started on the HELPER (for a machine the main Mac cannot ssh into,
#                                                     e.g. Ubuntu under Windows): fetch missing sourcefiles and the campaign's needs
#   bash hm64_pool.sh image-build                     (Linux x86-64 only) build the x86 container from the lab code on GitHub
#   bash hm64_pool.sh tools-push                      (main Mac) put THIS script on lab-campaigns/tools (no lab code is touched)
#
# 2026-11-26b: Linux x86-64 machines. There the container is hm64-lab:amd64 = the x86 mupen64plus 2.6.0 bundle image of
# the first lab (top-level Dockerfile of the lab code; compared with the ARM image on 2026-11-16: 0 differing rows),
# built on the machine itself; the runners get HM64_LAB_IMAGE / HM64_LAB_PLATFORM. Macs: nothing changes.
#
# 2026-11-26c: on Linux x86-64 the default container is hm64-lab:amd64-nd = mupen64plus 2.6.0 built from the pinned
# source with the "new dynarec" (the Macs' translator, for x86-64): on Thomas's PC 311.6 jobs/min against 123.1 of the
# bundle image, and the sunny no-horse gate as recorded (642 control casts, the same fast-check counts). It is built
# on the machine when missing. HM64_LAB_IMAGE=hm64-lab:amd64 still gives the bundle image. New: tools-push, and "run"
# hands over to a newer copy of this script when GitHub (lab-campaigns/tools) has one.
#
# 2026-11-26d: "sync" and "pull" wake the other machine first (wake-on-LAN) when tools/hm64_wake.sh knows it
# (bash tools/hm64_wake.sh add NAME user@host IP); a machine it does not know is contacted as before.
#
# 2026-11-27a: several campaigns, the whole pool.
#   bash hm64_pool.sh work topdown|bottomup|middleout [campaign ...]
#       works through the named campaigns (none named: the queue, tools/queue.txt on lab-campaigns) one after the other
#       on this machine. Before each, a helper that knows the main Mac (set-main) fetches what the campaign needs from
#       it. A campaign whose runner says "SKIPPED on this helper" (its dog-watch is not finished on the main Mac yet)
#       is tried again every 20 min (HM64_POOL_WORK_WAIT_MIN) for up to 36 h (HM64_POOL_WORK_HOURS); a campaign that
#       stops with an error is tried 3 times. The machine is kept awake for the whole time (Mac: caffeinate; Windows
#       under WSL: a PowerShell stay-awake request). Log of each campaign: ~/Documents/hm64/pool/work-<campaign>.log
#   bash hm64_pool.sh set-main user@main-mac      (a helper) where "work" fetches from; needs a key login to that Mac
#   bash hm64_pool.sh tools-push [campaign ...]   (main Mac) this script -> GitHub; with names: they become the queue
#   campaign.json "needs_when": {"<need>": "<file in the lab folder>"}: sync / pull leave a need alone until that file
#       exists on the main Mac (a dog-watch folder is only copied once its run has finished).
#
# ROM, saves in sourcefiles/ and savestates travel only over the LAN (sync) or by hand; never to GitHub.
POOL_REV="2026-11-27a"
set -u
CMD=${1:-}
[ $# -gt 0 ] && shift
HM64_DIR="$HOME/Documents/hm64"
LAB=${HM64_LAB:-$HM64_DIR/runs/dogspots/hm64-lab}
POOL="$HM64_DIR/pool"
REMOTE=${HM64_POOL_REMOTE:-git@github.com:Nillows/HM64-RNG-Manipulations.git}
RAW=${HM64_POOL_RAW:-https://raw.githubusercontent.com/Nillows/HM64-RNG-Manipulations/main}
TAG=hm64-lab:arm64
PLAT=linux/arm64
X86=no
if [ "$(uname -s)" = Linux ] && [ "$(uname -m)" = x86_64 ]; then X86=yes; TAG=${HM64_LAB_IMAGE:-hm64-lab:amd64-nd}; PLAT=linux/amd64; fi
HM64_LAB_IMAGE=$TAG; HM64_LAB_PLATFORM=$PLAT; export HM64_LAB_IMAGE HM64_LAB_PLATFORM
KEY="$HOME/.ssh/hm64_github_ed25519"
PATH="$PATH:/Applications/Docker.app/Contents/Resources/bin:/usr/local/bin:/opt/homebrew/bin"; export PATH
COPYFILE_DISABLE=1; export COPYFILE_DISABLE
if [ -f "$KEY" ]; then GIT_SSH_COMMAND="ssh -i '$KEY' -o IdentitiesOnly=yes -o BatchMode=yes -o ConnectTimeout=20"; export GIT_SSH_COMMAND; fi
say() { printf '\n==> %s\n' "$*"; }
die() { printf '\nSTOP: %s\n' "$*" >&2; exit 1; }
wake_first() { if [ -f "$HM64_DIR/tools/hm64_wake.sh" ]; then bash "$HM64_DIR/tools/hm64_wake.sh" wake-target "$1" </dev/null || true; fi; }
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
image_build_x86() {   # the x86 container, built here from the lab code on GitHub (no ROM, no saves in it)
  docker_up
  local t="$POOL/campaigns/base/hm64-lab-code.tar.gz" w="$POOL/x86-build" bs
  [ -f "$t" ] || die "no lab code on GitHub (lab-campaigns/base)"
  check_manifest "$POOL/campaigns/base"
  bs=$(sha "$t")
  rm -rf "$w"; mkdir -p "$w"
  ( cd "$w" && tar xzf "$t" ./Dockerfile ./.dockerignore ./native ./vendor/mupen64plus-bundle-linux64-2.6.0.tar.gz 2>/dev/null; [ -f Dockerfile ] && [ -d native ] && [ -f vendor/mupen64plus-bundle-linux64-2.6.0.tar.gz ] ) || die "the lab code on GitHub has no x86 container recipe (Dockerfile, native/, vendor/ bundle)"
  rm -rf "$w/native/build"
  if ( cd "$w" && find . -type f ) | forbidden | grep -q .; then die "the container recipe holds a ROM / save / savestate file: not built. Tell Claude."; fi
  echo "  building $TAG from the lab code ${bs:0:12}... (first time: 5 to 15 minutes, needs the internet for Ubuntu packages)"
  docker build --platform "$PLAT" --build-arg INSTALL_CLAUDE=0 --build-arg USER_UID="$(id -u)" --build-arg USER_GID="$(id -g)" --label "hm64.base=$bs" -t "$TAG" "$w" > "$POOL/x86-build.log" 2>&1 </dev/null || { tail -n 25 "$POOL/x86-build.log"; die "the container build failed (whole log: $POOL/x86-build.log)"; }
  docker run --rm --platform "$PLAT" "$TAG" python3 -c "import ctypes, platform; [ctypes.CDLL('/opt/m64h/native/build/' + n) for n in ('mupen64plus-video-hook.so', 'mupen64plus-input-script.so')]; ctypes.CDLL('/opt/mupen64plus/libmupen64plus.so.2'); print('  emulator core and plugins load on', platform.machine())" </dev/null || die "the emulator does not load in the built container"
  rm -rf "$w"
  echo "  container: built $(docker image inspect "$TAG" --format '{{.Id}}')"
}
image_build_x86_nd() {   # the fast x86 container: the ARM recipe of the lab code, for x86-64, with the new dynarec
  docker_up
  local t="$POOL/campaigns/base/hm64-lab-code.tar.gz" w="$POOL/x86-nd-build" bs
  [ -f "$t" ] || die "no lab code on GitHub (lab-campaigns/base)"
  check_manifest "$POOL/campaigns/base"
  bs=$(sha "$t")
  rm -rf "$w"; mkdir -p "$w"
  ( cd "$w" && tar xzf "$t" ./docker/Dockerfile.arm64 ./.dockerignore ./native ./vendor/mupen64plus-core-2.6.0-b0d68c20.tar.gz ./vendor/mupen64plus-rsp-hle-2.6.0-2798e65d.tar.gz 2>/dev/null; [ -f docker/Dockerfile.arm64 ] && [ -d native ] && [ -f vendor/mupen64plus-core-2.6.0-b0d68c20.tar.gz ] && [ -f vendor/mupen64plus-rsp-hle-2.6.0-2798e65d.tar.gz ] ) || die "the lab code on GitHub lacks the emulator sources (docker/Dockerfile.arm64, native/, vendor/)"
  rm -rf "$w/native/build"
  sed -e 's#^FROM --platform=linux/arm64 ubuntu:24.04#FROM --platform=linux/amd64 ubuntu:24.04#' -e 's#libsdl2-dev libpng-dev zlib1g-dev libgl-dev \\#libsdl2-dev libpng-dev zlib1g-dev libgl-dev nasm \\#' -e 's#all OSD=0 VULKAN=0 OPTFLAGS=#all OSD=0 VULKAN=0 NEW_DYNAREC=1 OPTFLAGS=#' "$w/docker/Dockerfile.arm64" > "$w/Dockerfile.nd"
  grep -q 'platform=linux/amd64' "$w/Dockerfile.nd" && grep -q 'NEW_DYNAREC=1' "$w/Dockerfile.nd" && grep -q 'libgl-dev nasm' "$w/Dockerfile.nd" || die "the container recipe could not be adapted (the lab code's ARM recipe changed). Tell Claude."
  if ( cd "$w" && find . -type f ) | forbidden | grep -q .; then die "the container recipe holds a ROM / save / savestate file: not built. Tell Claude."; fi
  echo "  building $TAG from the lab code ${bs:0:12}... (the emulator from source; 3 to 10 minutes, needs the internet for Ubuntu packages)"
  docker build --platform "$PLAT" --label "hm64.base=$bs" -t "$TAG" -f "$w/Dockerfile.nd" "$w" > "$POOL/x86-nd-build.log" 2>&1 </dev/null || { tail -n 25 "$POOL/x86-nd-build.log"; die "the container build failed (whole log: $POOL/x86-nd-build.log)"; }
  docker run --rm --platform "$PLAT" "$TAG" python3 -c "import ctypes, platform; [ctypes.CDLL('/opt/m64h/native/build/' + n) for n in ('mupen64plus-video-hook.so', 'mupen64plus-input-script.so')]; ctypes.CDLL('/opt/mupen64plus/libmupen64plus.so.2'); print('  emulator core and plugins load on', platform.machine())" </dev/null || die "the emulator does not load in the built container"
  rm -rf "$w"
  echo "  container: built $(docker image inspect "$TAG" --format '{{.Id}}')"
}
image_ensure() {   # image_ensure [wanted id]
  docker_up
  local want=${1:-} have d f p s
  if [ "$X86" = yes ]; then
    have=$(docker image inspect "$TAG" --format '{{.Id}}' 2>/dev/null || true)
    if [ -n "$have" ]; then echo "  container: x86 image $TAG ($have), built on this machine (the campaign's ARM container $want is for the Macs)"; return 0; fi
    if [ "$TAG" = hm64-lab:amd64 ]; then image_build_x86; else image_build_x86_nd; fi
    return 0
  fi
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
  f="$POOL/campaigns/tools/hm64_pool.sh"
  if [ -z "${HM64_POOL_HANDED:-}" ] && [ -f "$f" ]; then
    s=$(grep -m1 '^POOL_REV=' "$f" | cut -d'"' -f2 || true)
    if [ -n "$s" ] && [[ "$s" > "$POOL_REV" ]]; then
      echo "  GitHub has a newer pool script ($s): handing over to it"
      HM64_POOL_HANDED=1; export HM64_POOL_HANDED
      exec bash "$f" run "$name" "$order" $workers </dev/null
    fi
  fi
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
  else ( cd "$LAB" && tar xzf "$POOL/campaigns/base/hm64-lab-code.tar.gz" 2>/dev/null; [ -f tools/zigzag_campaign.py ] ) || die "unpacking the lab code failed"; sha "$POOL/campaigns/base/hm64-lab-code.tar.gz" > "$LAB/.pool_base"; echo "  lab code: installed from GitHub"; fi
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
need_when() { python3 -I -c 'import json,sys; print(json.load(open(sys.argv[1])).get("needs_when",{}).get(sys.argv[2],""))' "$1" "$2" 2>/dev/null || true; }
work_loop() {
  local order=${1:-} camps main hours every t0 pass waiting c log rc tries_file n left WPS=/mnt/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe
  CAF=""; WIN=""
  case "$order" in topdown|bottomup|middleout) ;; *) die "usage: bash hm64_pool.sh work topdown|bottomup|middleout [campaign ...]" ;; esac
  shift
  camp_clone
  camps="$*"
  if [ -z "$camps" ] && [ -f "$POOL/campaigns/tools/queue.txt" ]; then camps=$(grep -v -E '^[[:space:]]*(#|$)' "$POOL/campaigns/tools/queue.txt" | tr '\n' ' '); fi
  [ -n "$camps" ] || die "no campaigns to work on: name them, or on the main Mac run  bash hm64_pool.sh tools-push <campaign> ..."
  for c in $camps; do [ -f "$POOL/campaigns/$c/campaign.json" ] || die "no campaign '$c' on GitHub"; done
  main=""; if [ -f "$POOL/main.txt" ]; then main=$(head -n 1 "$POOL/main.txt"); fi
  hours=${HM64_POOL_WORK_HOURS:-36}; every=${HM64_POOL_WORK_WAIT_MIN:-20}
  if command -v caffeinate >/dev/null 2>&1; then caffeinate -ims -w $$ & CAF=$!
  elif grep -qi microsoft /proc/version 2>/dev/null && [ -x "$WPS" ]; then "$WPS" -NoProfile -NonInteractive -EncodedCommand QQBkAGQALQBUAHkAcABlACAALQBOAGEAbQBlAHMAcABhAGMAZQAgAEgATQAgAC0ATgBhAG0AZQAgAEEAdwBhAGsAZQAgAC0ATQBlAG0AYgBlAHIARABlAGYAaQBuAGkAdABpAG8AbgAgACcAWwBEAGwAbABJAG0AcABvAHIAdAAoACIAawBlAHIAbgBlAGwAMwAyAC4AZABsAGwAIgApAF0AIABwAHUAYgBsAGkAYwAgAHMAdABhAHQAaQBjACAAZQB4AHQAZQByAG4AIAB1AGkAbgB0ACAAUwBlAHQAVABoAHIAZQBhAGQARQB4AGUAYwB1AHQAaQBvAG4AUwB0AGEAdABlACgAdQBpAG4AdAAgAGYAKQA7ACcAOwAgAFsAdgBvAGkAZABdAFsASABNAC4AQQB3AGEAawBlAF0AOgA6AFMAZQB0AFQAaAByAGUAYQBkAEUAeABlAGMAdQB0AGkAbwBuAFMAdABhAHQAZQAoAFsAdQBpAG4AdAAzADIAXQAyADEANAA3ADQAOAAzADYANAA5ACkAOwAgAHcAaABpAGwAZQAgACgAJAB0AHIAdQBlACkAIAB7ACAAUwB0AGEAcgB0AC0AUwBsAGUAZQBwACAALQBTAGUAYwBvAG4AZABzACAANgAwACAAfQA= </dev/null >/dev/null 2>&1 & WIN=$!; fi
  trap '[ -z "$CAF" ] || kill "$CAF" 2>/dev/null; [ -z "$WIN" ] || kill "$WIN" 2>/dev/null' EXIT
  say "work ($order) on $(scutil --get LocalHostName 2>/dev/null || hostname -s): campaigns [$camps]   main Mac: ${main:-none set (nothing is fetched)}   pool script $POOL_REV"
  tries_file="$POOL/.work_tries"; : > "$tries_file"
  t0=$(date +%s); pass=0
  while :; do
    pass=$((pass + 1)); waiting=""
    for c in $camps; do
      n=$(grep -c "^$c\$" "$tries_file" || true)
      if [ "$n" -ge 3 ]; then echo "  campaign $c stopped with an error 3 times: left out (see $POOL/work-$c.log)"; continue; fi
      say "work pass $pass: campaign $c"
      if [ -n "$main" ]; then ( HM64_POOL_BATCH=1; export HM64_POOL_BATCH; pull_lan "$main" "$c" ) </dev/null || echo "  (could not fetch from $main: going on with what is here)"; fi
      log="$POOL/work-$c.log"
      ${HM64_POOL_RUN_CMD:-bash "$0" run} "$c" "$order" </dev/null 2>&1 | tee "$log"      # HM64_POOL_RUN_CMD: test hook
      rc=${PIPESTATUS[0]}
      if [ "$rc" != 0 ]; then echo "  campaign $c stopped with an error (exit $rc)"; echo "$c" >> "$tries_file"; waiting="$waiting $c"
      elif grep -q "SKIPPED on this helper" "$log"; then echo "  campaign $c: part of it is waiting for the main Mac"; waiting="$waiting $c"; fi
    done
    camps=$waiting
    left=""; for c in $camps; do n=$(grep -c "^$c\$" "$tries_file" || true); [ "$n" -ge 3 ] || left="$left $c"; done
    [ -n "$left" ] || break
    if [ $(( ($(date +%s) - t0) / 3600 )) -ge "$hours" ]; then echo "  $hours h are over: stopping with [$left] unfinished on this machine"; break; fi
    say "waiting for [$left]: trying again in $every min  ($(date '+%a %H:%M'))"
    sleep $((every * 60))
  done
  say "WORK DONE on this machine  $(date '+%a %H:%M')"
}
manifest_of() { ( cd "$1" 2>/dev/null && find . -type f ! -name '.DS_Store' | sort | while IFS= read -r f; do printf '%s  %s\n' "$(shasum -a 256 "$f" | cut -d' ' -f1)" "$f"; done ); }
sync_lan() {
  local R=${1:-} name=${2:-} RL='Documents/hm64' a b n p w
  [ -n "$R" ] || die "usage: bash hm64_pool.sh sync user@other-mac [campaign]"
  mkdir -p "$HOME/.ssh"
  rs() { ssh ${HM64_POOL_BATCH:+-o BatchMode=yes} -o ConnectTimeout=15 -o ControlMaster=auto -o ControlPath="$HOME/.ssh/hm64-cm-%C" -o ControlPersist=600 "$R" "$@"; }
  say "sourcefiles: this Mac <-> $R"
  wake_first "$R"
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
    w=$(need_when "$POOL/campaigns/$name/campaign.json" "$p")
    if [ -n "$w" ] && [ ! -e "$LAB/$w" ]; then echo "  $p: not finished on this Mac yet ($w is not there): left alone"; continue; fi
    a=$(manifest_of "$LAB/$p" | shasum -a 256 | cut -d' ' -f1)
    b=$(rs "cd '$RL/runs/dogspots/hm64-lab/$p' 2>/dev/null && find . -type f ! -name '.DS_Store' | sort | while IFS= read -r f; do printf '%s  %s\n' \"\$(shasum -a 256 \"\$f\" | cut -d' ' -f1)\" \"\$f\"; done | shasum -a 256 | cut -d' ' -f1" </dev/null || true)
    if [ "$a" = "$b" ]; then echo "  $p: identical on both"; continue; fi
    rs "mkdir -p '$RL/runs/dogspots/hm64-lab'" </dev/null
    ( cd "$LAB" && tar cf - "$p" ) | rs "cd '$RL/runs/dogspots/hm64-lab' && tar xf -" || die "copy of $p failed"
    echo "  $p: copied ($(du -sh "$LAB/$p" | cut -f1))"
  done
}
pull_lan() {    # started on the helper: what the main Mac would push with "sync"
  local R=${1:-} name=${2:-} RL='Documents/hm64' a b n p i w
  [ -n "$R" ] || die "usage: bash hm64_pool.sh pull user@main-mac [campaign]"
  mkdir -p "$HOME/.ssh" "$POOL" "$HM64_DIR/sourcefiles"
  rs() { ssh ${HM64_POOL_BATCH:+-o BatchMode=yes} -o ConnectTimeout=15 -o ControlMaster=auto -o ControlPath="$HOME/.ssh/hm64-cm-%C" -o ControlPersist=600 "$R" "$@"; }
  say "sourcefiles: $R -> this machine (only files this machine does not have)"
  wake_first "$R"
  rs 'echo "  reached $(hostname -s)"' </dev/null || die "cannot reach $R over ssh (is Remote Login on there, is the address right?)"
  a="$POOL/.sf_here"; b="$POOL/.sf_there"
  manifest_of "$HM64_DIR/sourcefiles" > "$a"
  rs "cd '$RL/sourcefiles' && find . -type f ! -name '.DS_Store' ! -path './pool/*' | sort | while IFS= read -r f; do printf '%s  %s\n' \"\$(shasum -a 256 \"\$f\" | cut -d' ' -f1)\" \"\$f\"; done" </dev/null > "$b" || die "could not list sourcefiles on $R"
  python3 -I - "$a" "$b" "$POOL/.sf_plan" <<'PY' || die "could not compare the sourcefiles lists"
import sys
def L(p):
    d = {}
    for ln in open(p, encoding="utf-8", errors="replace"):
        ln = ln.rstrip("\n")
        if "  " in ln:
            h, f = ln.split("  ", 1); d[f] = h
    return d
a, b = L(sys.argv[1]), L(sys.argv[2])
have = set(a.values())
frm = sorted(f for f in b if f not in a and b[f] not in have)
clash = sorted(f for f in a if f in b and a[f] != b[f])
print(f"  there: {len(b)} files   already here: {sum(1 for f in b if b[f] in have)}   to fetch: {len(frm)}   same name, other content (NOT fetched): {len(clash)}")
for f in clash: print(f"  DIFFERENT: {f}")
open(sys.argv[3] + ".from", "w").write("".join(f + "\n" for f in frm))
PY
  if [ -s "$POOL/.sf_plan.from" ]; then rs "cd '$RL/sourcefiles' && tar cf - -T -" < "$POOL/.sf_plan.from" | ( cd "$HM64_DIR/sourcefiles" && tar xf - ) || die "copy from $R failed"; echo "  fetched: $(wc -l < "$POOL/.sf_plan.from" | tr -d ' ') files"; fi
  [ -n "$name" ] || return 0
  camp_clone; [ -f "$POOL/campaigns/$name/campaign.json" ] || die "no campaign '$name' on GitHub"
  say "what campaign $name needs: $R -> this machine"
  n=$(python3 -I -c 'import json,sys; print(len(json.load(open(sys.argv[1])).get("needs",[])))' "$POOL/campaigns/$name/campaign.json")
  i=0
  mkdir -p "$LAB"
  while [ "$i" -lt "$n" ]; do
    p=$(jget "$POOL/campaigns/$name/campaign.json" "needs.$i"); i=$((i + 1))
    w=$(need_when "$POOL/campaigns/$name/campaign.json" "$p")
    if [ -n "$w" ] && ! rs "test -e '$RL/runs/dogspots/hm64-lab/$w'" </dev/null; then echo "  $p: not finished on $R yet: left alone"; continue; fi
    b=$(rs "cd '$RL/runs/dogspots/hm64-lab/$p' 2>/dev/null && find . -type f ! -name '.DS_Store' | sort | while IFS= read -r f; do printf '%s  %s\n' \"\$(shasum -a 256 \"\$f\" | cut -d' ' -f1)\" \"\$f\"; done | shasum -a 256 | cut -d' ' -f1" </dev/null || true)
    if [ -z "$b" ] || [ "$b" = "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855" ]; then echo "  $p: not on $R"; continue; fi
    a=""; [ ! -e "$LAB/$p" ] || a=$(manifest_of "$LAB/$p" | shasum -a 256 | cut -d' ' -f1)
    if [ "$a" = "$b" ]; then echo "  $p: identical on both"; continue; fi
    rs "cd '$RL/runs/dogspots/hm64-lab' && tar cf - '$p'" </dev/null | ( cd "$LAB" && tar xf - ) || die "copy of $p failed"
    a=$(manifest_of "$LAB/$p" | shasum -a 256 | cut -d' ' -f1)
    [ "$a" = "$b" ] || die "$p arrived damaged (the two lists of sha256 differ)"
    echo "  $p: fetched and checked ($(du -sh "$LAB/$p" | cut -f1))"
  done
}
case "$CMD" in
  image-build) [ "$X86" = yes ] || die "image-build is for Linux x86-64 machines; the Macs load the ARM container (run does it)"; camp_clone; if [ "$TAG" = hm64-lab:amd64 ]; then image_build_x86; else image_build_x86_nd; fi ;;
  tools-push) [ "$X86" = no ] || die "tools-push is for the main Mac"; say "this script ($POOL_REV) -> lab-campaigns/tools"; camp_clone; w="$POOL/tools-out"; rm -rf "$w"; mkdir -p "$w"; cp "$0" "$w/hm64_pool.sh"
    if [ $# -gt 0 ]; then for c in "$@"; do [ -f "$POOL/campaigns/$c/campaign.json" ] || die "no campaign '$c' on GitHub (campaign-push it first)"; printf '%s\n' "$c"; done > "$w/queue.txt"; echo "  queue: $*"
    elif [ -f "$POOL/campaigns/tools/queue.txt" ]; then cp "$POOL/campaigns/tools/queue.txt" "$w/queue.txt"; echo "  queue kept: $(tr '\n' ' ' < "$w/queue.txt")"; fi
    put_folder "$w" tools; rm -rf "$w" ;;
  set-main) [ -n "${1:-}" ] || die "usage: bash hm64_pool.sh set-main user@main-mac"; mkdir -p "$POOL"; printf '%s\n' "$1" > "$POOL/main.txt"; echo "  main Mac for this machine: $1" ;;
  work) if [ -z "${HM64_POOL_WORKCOPY:-}" ]; then mkdir -p "$POOL"; cp "$0" "$POOL/.hm64_pool_work.sh"; HM64_POOL_WORKCOPY=1; export HM64_POOL_WORKCOPY; exec bash "$POOL/.hm64_pool_work.sh" work "$@"; fi; work_loop "$@" ;;
  pull) pull_lan "$@" ;;
  image-push) [ "$X86" = no ] || die "image-push is for the main Mac (the ARM container); this machine builds its own x86 container"; image_push ;;
  base-push) base_push ;;
  campaign-push) [ -f "${1:-}/campaign.json" ] || die "usage: bash hm64_pool.sh campaign-push <folder with campaign.json>"; n=$(jget "$1/campaign.json" name); [ -n "$n" ] || die "campaign.json has no name"; say "campaign $n -> lab-campaigns"; put_folder "$1" "$n" ;;
  list) camp_clone; for d in "$POOL/campaigns"/*/; do [ -f "$d/campaign.json" ] && echo "  $(jget "$d/campaign.json" name)   $(jget "$d/campaign.json" version)   $(jget "$d/campaign.json" title)"; done ;;
  run) run_campaign "$@" ;;
  sync) sync_lan "$@" ;;
  *) sed -n '2,12p' "$0"; exit 2 ;;
esac
