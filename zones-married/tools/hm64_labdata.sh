set -uo pipefail
LABDATA_REV="2026-11-27a"
MODE="${1:-}"
ARGS_KEEP="${1:-}"
HM="$HOME/Documents/hm64"
TOOLS="$HM/tools"
DL="$HOME/Downloads"
DATA="${HM64_LABDATA_DIR:-$HM/lab-data}"
BRANCH="lab-data"
URL_DEFAULT="git@github.com:Nillows/HM64-RNG-Manipulations.git"
SSHKEY="$HOME/.ssh/hm64_github_ed25519"
MAXMB="${HM64_LABDATA_MAX_MB:-600}"
BUSYMODE="${HM64_LABDATA_BUSY:-finished}"
POLL="${HM64_LABDATA_POLL_S:-60}"
SETTLE="${HM64_LABDATA_SETTLE_S:-120}"
export GIT_TERMINAL_PROMPT=0
say() { printf '\n==> %s\n' "$*"; }
die() { printf '\nSTOP (lab data): %s\n' "$*"; exit 1; }
sha_of() { shasum -a 256 "$1" | awk '{print $1}'; }
size_of() { wc -c < "$1" | tr -d ' '; }
mt() { if [ "$(uname)" = Darwin ]; then stat -f %m "$1" 2>/dev/null || echo 0; else stat -c %Y "$1" 2>/dev/null || echo 0; fi; }
canon() { basename "$1" | sed -E -e 's/ ?\([0-9]+\)\.zip$/.zip/' -e 's/ [0-9]+\.zip$/.zip/'; }
lab_busy() {
  LOCKS=$(find "$HM/runs" -maxdepth 3 -name .running 2>/dev/null | sed "s#^$HM/##" | tr '\n' ' ')
  CONT=0
  if command -v docker >/dev/null 2>&1; then CONT=$(docker ps --format '{{.Image}}' 2>/dev/null | grep -c 'hm64-' || true); fi
  [ -n "${LOCKS// /}" ] || [ "${CONT:-0}" -gt 0 ]
}
case "$MODE" in ""|wait) ;; *) die "usage: hm64_labdata.sh [wait]   (wait = hold on until the lab run has ended, then upload)" ;; esac

MAP_DEFAULT='sunny-no-horse|hm64-dogwatch-beach-lineup2-52cfd712*.zip|0|one
sunny-no-horse|hm64-fullday-d90-*.zip|0|each
sunny-no-horse|hm64-fullday-d110-*.zip|0|each
sunny-no-horse|hm64-fullday-d140c90-*.zip|0|each
sunny-no-horse|hm64-fullday-d170c120-*.zip|0|each
sunny-horse|hm64-dogwatch-beach-lineup2-horse-b0f2a284.zip|1|each
sunny-horse|hm64-fullday-horse-d90.zip|1|each
sunny-horse|hm64-fullday-horse-d140c90.zip|1|each
sunny-horse|hm64-fullday-horse-d170c120.zip|1|each
sunny-horse|run-horse120-*.log|0|each
rainy-horse|hm64-dogwatch-rain-lineup2-horse-287c11a6.zip|1|each
rainy-horse|hm64-fullday-rain-horse-d90.zip|1|each
rainy-horse|hm64-fullday-rain-horse-d140c90.zip|1|each
rainy-horse|hm64-fullday-rain-horse-d170c120.zip|1|each
rainy-no-horse|hm64-dogwatch-rain-lineup2-nohorse-8e972d75.zip|1|each
rainy-no-horse|hm64-fullday-rain-nohorse-d90.zip|1|each
rainy-no-horse|hm64-fullday-rain-nohorse-d140c90.zip|1|each
rainy-no-horse|hm64-fullday-rain-nohorse-d170c120.zip|1|each
rainy-no-horse|run-rain120-*.log|0|each
married-sunny|hm64-dogwatch-married-lineup2-sunny-237e3d1d.zip|1|each
married-sunny|hm64-fullday-married-sunny-d90.zip|1|each
married-sunny|hm64-fullday-married-sunny-d140c90.zip|1|each
married-sunny|hm64-fullday-married-sunny-d170c120.zip|1|each
married-sunny|run-married120-*.log|0|each
married-rainy|hm64-dogwatch-married-lineup2-rainy-62991249.zip|1|each
married-rainy|hm64-fullday-married-rainy-d90.zip|0|each
married-rainy|hm64-fullday-married-rainy-d140c90.zip|0|each
married-rainy|hm64-fullday-married-rainy-d170c120.zip|0|each
married-sunny|hm64-fullday-married-sunny-d90@*.zip|0|each
married-sunny|hm64-fullday-married-sunny-d140c90@*.zip|0|each
married-sunny|hm64-fullday-married-sunny-d170c120@*.zip|0|each
married-rainy|hm64-fullday-married-rainy-d90@*.zip|0|each
married-rainy|hm64-fullday-married-rainy-d140c90@*.zip|0|each
married-rainy|hm64-fullday-married-rainy-d170c120@*.zip|0|each
spots-rainy-no-horse|hm64-spots-rain-lineup2-nohorse-8e972d75.zip|0|each
spots-rainy-no-horse|run-spots-*.log|0|each
spots-rainy-horse|hm64-spots-rain-lineup2-horse-287c11a6.zip|0|each
spots-rainy-no-horse|hm64-zones-rain-lineup2-nohorse-8e972d75.zip|0|each
spots-rainy-no-horse|run-zones-*.log|0|each
spots-rainy-horse|hm64-zones-rain-lineup2-horse-287c11a6.zip|0|each
spots-rainy-no-horse|hm64-zones-rain-lineup2-nohorse-8e972d75@*.zip|0|each
spots-rainy-horse|hm64-zones-rain-lineup2-horse-287c11a6@*.zip|0|each
spots-rainy-no-horse|hm64-gaps-rain-lineup2-nohorse-8e972d75@*.zip|0|each
spots-rainy-horse|hm64-gaps-rain-lineup2-horse-287c11a6@*.zip|0|each
sunny-no-horse|hm64-gaps-beach-lineup2-52cfd712@*.zip|0|each
sunny-horse|hm64-gaps-beach-lineup2-horse-b0f2a284@*.zip|0|each
spots-rainy-no-horse|run-gaps-*.log|0|each
sunny-no-horse|run-sunspots-*.log|0|each
sunny-no-horse|hm64-nutgaps-beach-lineup2-52cfd712@*.zip|0|each
sunny-horse|hm64-nutgaps-beach-lineup2-horse-b0f2a284@*.zip|0|each
married-sunny|hm64-gaps-married-lineup2-sunny-237e3d1d@*.zip|0|each
married-rainy|hm64-gaps-married-lineup2-rainy-62991249@*.zip|0|each
married-sunny|run-marzones-*.log|0|each
married-horse-sunny|hm64-dogwatch-married-horse-lineup2-sunny-0f33f322.zip|0|each
married-horse-rainy|hm64-dogwatch-married-horse-lineup2-rainy-8cbe43a5.zip|0|each
married-horse-sunny|hm64-fullday-marhorse-sunny-d90@*.zip|0|each
married-horse-sunny|hm64-fullday-marhorse-sunny-d140c90@*.zip|0|each
married-horse-sunny|hm64-fullday-marhorse-sunny-d170c120@*.zip|0|each
married-horse-rainy|hm64-fullday-marhorse-rainy-d90@*.zip|0|each
married-horse-rainy|hm64-fullday-marhorse-rainy-d140c90@*.zip|0|each
married-horse-rainy|hm64-fullday-marhorse-rainy-d170c120@*.zip|0|each
married-horse-sunny|run-marhorse120-*.log|0|each
sunny-no-horse|run-nutgaps-*.log|0|each'
if [ -f "$TOOLS/labdata_map.txt" ]; then MAP=$(grep -v '^[[:space:]]*$' "$TOOLS/labdata_map.txt"); MAPSRC="$TOOLS/labdata_map.txt"; else MAP="$MAP_DEFAULT"; MAPSRC="built in"; fi

say "lab data 1/5  is a lab run going? (lab-data script $LABDATA_REV)"
BUSY=no
if lab_busy; then
  BUSY=yes
  echo "  a lab run is going (${LOCKS:-no lock file}; ${CONT:-0} hm64 container(s))"
  if [ "$MODE" = wait ]; then
    if command -v caffeinate >/dev/null 2>&1; then caffeinate -i -w $$ & fi
    echo "  waiting for it to end (checked every $POLL s; leave this window open) ..."
    n=0
    while :; do
      while lab_busy; do
        sleep "$POLL"; n=$((n + 1))
        if [ $((n % 15)) -eq 0 ]; then echo "  still running at $(date '+%a %H:%M') (${LOCKS:-containers only})"; fi
      done
      echo "  no lab run at $(date '+%a %H:%M'); letting the last files settle for $SETTLE s, then checking once more"
      sleep "$SETTLE"
      if lab_busy; then echo "  a lab stage started again (${LOCKS:-containers}): waiting on"; else break; fi
    done
    BUSY=no
    echo "  the lab run has ended"
  elif [ "$BUSYMODE" = skip ]; then
    echo "  HM64_LABDATA_BUSY=skip: nothing is collected or uploaded while a run is going. Run this again when it is done."
    exit 0
  else
    echo "  only finished, complete files are uploaded now; run this again (or with: wait) for the rest"
  fi
else
  echo "  no lab run is going"
fi

say "lab data 2/5  the $BRANCH branch (your site clone and its main branch are not touched)"
MAINREPO=""
if [ -f "$TOOLS/repo_path.txt" ]; then MAINREPO=$(cat "$TOOLS/repo_path.txt"); fi
URL=""
if [ -n "$MAINREPO" ] && [ -d "$MAINREPO/.git" ]; then URL=$(git -C "$MAINREPO" remote get-url origin 2>/dev/null || true); fi
[ -n "$URL" ] || URL="$URL_DEFAULT"
case "$URL" in https://github.com/*) URL="git@github.com:$(printf '%s' "$URL" | sed -E -e 's#^https://github.com/##' -e 's#\.git$##').git" ;; esac
if [ -f "$SSHKEY" ]; then export GIT_SSH_COMMAND="ssh -i '$SSHKEY' -o IdentitiesOnly=yes"; echo "  push access: the release SSH key ($SSHKEY)"; else echo "  push access: this Mac's usual SSH keys (no $SSHKEY)"; fi
REMOTE_HEAD=""
t=0
while :; do
  if REMOTE_HEAD=$(git ls-remote --heads "$URL" "$BRANCH" 2>/tmp/hm64_labdata_err.$$ | awk '{print $1}'); then rm -f /tmp/hm64_labdata_err.$$; break; fi
  t=$((t + 1))
  if [ "$t" -ge 3 ]; then E=$(grep -v '^$' /tmp/hm64_labdata_err.$$ | head -n 1); rm -f /tmp/hm64_labdata_err.$$; die "GitHub cannot be read ($E). Nothing was changed. Check the internet connection and run the same command again."; fi
  sleep 5
done
if [ -e "$DATA" ] && [ ! -d "$DATA/.git" ]; then die "$DATA exists but is not a git folder. Move it away and run the same command again."; fi
if [ -d "$DATA/.git" ]; then
  cd "$DATA" || die "cannot enter $DATA"
  CUR=$(git symbolic-ref --short HEAD 2>/dev/null || true)
  [ "$CUR" = "$BRANCH" ] || die "$DATA is on branch '${CUR:-none}', not $BRANCH. Nothing was changed."
  if git remote get-url origin >/dev/null 2>&1; then git remote set-url origin "$URL"; else git remote add origin "$URL"; fi
  if [ -n "$REMOTE_HEAD" ]; then
    git fetch -q origin "$BRANCH" || die "git fetch of $BRANCH failed. Nothing was changed."
    if git rev-parse -q --verify HEAD >/dev/null 2>&1; then
      set -- $(git rev-list --left-right --count "HEAD...FETCH_HEAD")
      if [ "$1" -gt 0 ] && [ "$2" -gt 0 ]; then
        LOCALN=$1; REMOTEN=$2
        BASE=$(git merge-base HEAD FETCH_HEAD 2>/dev/null || true)
        [ -n "$BASE" ] || die "$DATA and GitHub's $BRANCH share no history. Sort that out by hand; nothing was changed."
        CHG=$(git diff --name-only --diff-filter=MDRT "$BASE" HEAD | grep -v -e '^README.md$' -e '^MANIFEST.txt$' || true)
        [ -z "$CHG" ] || die "$DATA changed or removed files that are on GitHub ($(printf '%s' "$CHG" | head -n 3 | tr '\n' ' ')): not joined automatically. Nothing was changed."
        KEEP="$DATA.keep.$$"; rm -rf "$KEEP"; mkdir -p "$KEEP"
        git diff --name-only --diff-filter=A "$BASE" HEAD | grep -v -e '^README.md$' -e '^MANIFEST.txt$' > "$KEEP/.list" || true
        while IFS= read -r f; do mkdir -p "$KEEP/$(dirname "$f")"; cp "$f" "$KEEP/$f" || die "could not set $f aside"; done < "$KEEP/.list"
        BK="before-join-$(date +%Y%m%d-%H%M%S)"
        git branch -f "$BK" HEAD
        git reset -q --hard FETCH_HEAD || die "could not take GitHub's $BRANCH (your commits are kept as branch $BK in $DATA)"
        while IFS= read -r f; do
          if [ -f "$f" ]; then cmp -s "$f" "$KEEP/$f" || die "$f is on GitHub with other content than this Mac's copy (this Mac's commits are kept as branch $BK in $DATA)"
          else mkdir -p "$(dirname "$f")"; cp "$KEEP/$f" "$f"; fi
        done < "$KEEP/.list"
        echo "  another Mac has uploaded meanwhile: took its $REMOTEN commit(s), kept this Mac's $(wc -l < "$KEEP/.list" | tr -d ' ') new files ($LOCALN local commit(s) kept as branch $BK)"
        rm -rf "$KEEP"
        set -- 0 0
      fi
      if [ "$2" -gt 0 ]; then git merge -q --ff-only FETCH_HEAD || die "could not fast-forward $DATA (local edits in the way?)"; echo "  pulled $2 commit(s) from GitHub"; fi
    else
      git reset -q --hard FETCH_HEAD || die "could not take GitHub's $BRANCH into the empty $DATA"
    fi
  fi
  echo "  $DATA (branch $BRANCH, GitHub has ${REMOTE_HEAD:-no such branch yet})"
elif [ -n "$REMOTE_HEAD" ]; then
  echo "  no local copy yet: fetching GitHub's $BRANCH into $DATA"
  git clone -q --branch "$BRANCH" --single-branch "$URL" "$DATA" || die "git clone of $BRANCH failed. Nothing was changed."
  cd "$DATA" || die "cannot enter $DATA"
else
  echo "  $BRANCH does not exist yet: starting it in $DATA (no history shared with main)"
  mkdir -p "$DATA" && cd "$DATA" || die "cannot make $DATA"
  git init -q . && git symbolic-ref HEAD "refs/heads/$BRANCH" && git remote add origin "$URL" || die "git init failed in $DATA"
fi
if [ -n "${GIT_SSH_COMMAND:-}" ]; then git config core.sshCommand "$GIT_SSH_COMMAND"; fi

say "lab data 3/5  looking for results in $HM/runs and $DL (table: $MAPSRC; newest copy of each file)"
NOW=$(date +%s)
CAND=$( { find "$HM/runs" -maxdepth 4 -type f \( -name 'hm64-*.zip' -o -name 'run-*.log' \) 2>/dev/null; find "$DL" -maxdepth 1 -type f -name 'hm64-*.zip' 2>/dev/null; } | while IFS= read -r f; do printf '%s\t%s\n' "$(mt "$f")" "$f"; done | sort -rn )
MISSING=""
NOTYET=""
REFUSED=""
BIG=""
NEW=0
SAME=0
SAMEIN=0
MATCHED="|"
zsig() { unzip -v "$1" 2>/dev/null </dev/null | awk 'NF >= 8 && $7 ~ /^[0-9a-fA-F]+$/ && length($7) == 8 { n = $8; for (i = 9; i <= NF; i++) n = n " " $i; print $1, $7, n }' | LC_ALL=C sort; }
same_inside() {
  a="$1"; b="$2"
  sa=$(zsig "$a"); sb=$(zsig "$b")
  [ -n "$sa" ] && [ "$sa" = "$sb" ]
}
take() {
  folder="$1"; b="$2"; src="$3"; m="$4"
  dst="$DATA/$folder/$b"
  case "$b" in
    *.zip)
      age=$((NOW - m))
      if [ "$BUSY" = yes ] && [ "$age" -lt "$SETTLE" ]; then NOTYET="$NOTYET $folder/$b"; echo "  not finished yet (changed $age s ago), left for next time: $folder/$b"; return 0; fi
      if ! unzip -tq "$src" >/dev/null 2>&1 </dev/null; then NOTYET="$NOTYET $folder/$b"; echo "  not a complete zip (still being written, or damaged), left out: $src"; return 0; fi
      bad=$(unzip -Z1 "$src" 2>/dev/null </dev/null | grep -i -E '\.(z64|n64|v64|saveram|sra|eep|fla|mpk|st|state)$' | head -n 2 | tr '\n' ' ')
      if [ -n "$bad" ]; then REFUSED="$REFUSED $folder/$b"; echo "  REFUSED (holds a ROM / save / savestate: $bad): $src"; return 0; fi ;;
  esac
  mkdir -p "$DATA/$folder"
  sz=$(size_of "$src")
  if [ "$sz" -gt 99614720 ]; then
    if ls "$dst".part-* >/dev/null 2>&1 && cat "$dst".part-* | cmp -s - "$src"; then SAME=$((SAME + 1)); return 0; fi
    if ls "$dst".part-* >/dev/null 2>&1; then
      tmpz="$DATA/.cmp_$$.zip"; cat "$dst".part-* > "$tmpz"
      if same_inside "$src" "$tmpz"; then rm -f "$tmpz"; SAME=$((SAME + 1)); SAMEIN=$((SAMEIN + 1)); return 0; fi
      rm -f "$tmpz"
    fi
    rm -f "$dst" "$dst".part-*
    split -b 90m "$src" "$dst.part-" || die "could not split $src"
    BIG="$BIG $folder/$b"
  else
    if [ -f "$dst" ] && cmp -s "$src" "$dst"; then SAME=$((SAME + 1)); return 0; fi
    if [ -f "$dst" ] && same_inside "$src" "$dst"; then SAME=$((SAME + 1)); SAMEIN=$((SAMEIN + 1)); return 0; fi
    rm -f "$dst".part-*
    cp "$src" "$dst" || die "could not copy $src"
  fi
  NEW=$((NEW + 1))
  echo "  + $folder/$b ($((sz / 1048576)) MB)   <- $src"
}
while IFS='|' read -r folder pat need how; do
  [ -n "$folder" ] || continue
  seen="|"; n=0
  while IFS=$'\t' read -r m f; do
    [ -n "$f" ] || continue
    b=$(canon "$f")
    case "$b" in $pat) ;; *) continue ;; esac
    MATCHED="$MATCHED$b|"
    case "$seen" in *"|$b|"*) continue ;; esac
    seen="$seen$b|"
    take "$folder" "$b" "$f" "$m"
    n=$((n + 1))
    if [ "$how" = one ]; then break; fi
  done <<LIST
$CAND
LIST
  if [ "$n" -eq 0 ] && [ "$need" = 1 ]; then
    if ! ls "$DATA/$folder"/$pat >/dev/null 2>&1 && ! ls "$DATA/$folder"/$pat.part-aa >/dev/null 2>&1; then MISSING="$MISSING $folder/$pat"; echo "  not on this Mac yet: $folder/$pat"; fi
  fi
done <<MAPEND
$MAP
MAPEND
echo "  $NEW new or changed, $SAME already up to date$( [ "$SAMEIN" -gt 0 ] && echo " ($SAMEIN of them: same files inside as the copy on GitHub, only zipped again - not uploaded again)" )"
list_unmapped() {
  while IFS=$'\t' read -r m f; do
    [ -n "$f" ] || continue
    b=$(canon "$f")
    if [ "${f#$HM/runs/}" = "$f" ]; then continue; fi
    if [ "${b#hm64-dogwatch-}" = "$b" ] && [ "${b#hm64-fullday-}" = "$b" ]; then continue; fi
    if [ "${b%.zip}" = "$b" ]; then continue; fi
    if [ "${MATCHED#*|$b|}" != "$MATCHED" ]; then continue; fi
    printf '%s\n' "$b"
  done
}
UNMAPPED=$(printf '%s\n' "$CAND" | list_unmapped | sort -u)
if [ -n "$UNMAPPED" ]; then
  echo "  result zips in runs/ that are not in the table (NOT uploaded; tell Claude if they should be): $(printf '%s\n' "$UNMAPPED" | wc -l | tr -d ' ')"
  printf '%s\n' "$UNMAPPED" | head -n 12 | sed 's/^/    /'
fi

say "lab data 4/5  README.md + MANIFEST.txt"
{
  echo "HM64 raw lab results: sha256, bytes, file"
  find . -path ./.git -prune -o -type f ! -name MANIFEST.txt ! -name README.md ! -name .DS_Store -print | sed 's#^\./##' | LC_ALL=C sort | while IFS= read -r f; do printf '%s  %11s  %s\n' "$(sha_of "$f")" "$(size_of "$f")" "$f"; done
} > MANIFEST.txt
H1='#'
cat > README.md <<README_END
$H1 HM64 lab data (branch \`$BRANCH\`)

Raw results of the Power Nut lab runs on Thomas's Mac, for rebuilding and re-verifying the tool's data
(route tables, cast packs). Not part of the website: GitHub Pages serves the \`main\` branch only.
No ROM, saves or savestates in any file. sha256 of every file: \`MANIFEST.txt\`.
Kept up to date by \`~/Documents/hm64/tools/hm64_labdata.sh\` ($LABDATA_REV), which every release runs.

| folder | run | save |
|---|---|---|
| sunny-no-horse | dog-watch + full-day d90 / d110 / d140c90 / d170c120 (2026-11-16 to 22) | beach-lineup2 52cfd712 |
| sunny-horse | horse120 (2026-11-23) | beach-lineup2-horse b0f2a284 |
| rainy-horse, rainy-no-horse | rain120 (2026-11-23/24; its log is in rainy-no-horse) | beach-lineup2-horse-rainy 287c11a6, beach-lineup2-nohorse-rainy 8e972d75 |
| married-sunny, married-rainy | married120 (2026-11-25; its log is in married-sunny) | married no horse, sunny moved to spring 9 237e3d1d, rainy 62991249 |
| spots-rainy-no-horse, spots-rainy-horse | pier spots (2026-11-25; \`hm64-spots-<label>.zip\`: every line from every pier spot, the recorded casts from three other spots; \`hm64-gaps-<label>@<machine>.zip\`: the gap campaign of 2026-11-26 (lines never cast away from the north zone, Nuts after the measured part, casts held to 170 s, per-frame traces); \`hm64-zones-<label>.zip\`: the casts that can differ, from the middle and south camera zones; logs in spots-rainy-no-horse) | the two rainy saves |

Per save: \`hm64-dogwatch-<label>.zip\` (dog lines, traces, Lucky Timer cast tables) and
\`hm64-fullday-<tag>-{d90,d140c90,d170c120}.zip\` (the dog after the cast: casts 0.1-40 s held to 90 s, 40-90 s to
140 s, 80-120 s to 170 s), plus the run's log. A file named \`*.part-aa\`, \`*.part-ab\` ... was over 95 MB:
\`cat name.part-* > name\`.

Get only this branch:

    git clone --depth 1 --branch $BRANCH --single-branch https://github.com/Nillows/HM64-RNG-Manipulations.git hm64-lab-data

Then check: \`cd hm64-lab-data && shasum -a 256 -c <(awk 'NR>1 {print \$1"  "\$3}' MANIFEST.txt)\`

Last update: $(date '+%Y-%m-%d').
Not on the Mac at the last update:${MISSING:- nothing missing}
Left out as unfinished at the last update:${NOTYET:- none}
$( [ "$BUSY" = yes ] && echo "A lab run was still going at the last update: its unfinished files are not here yet." || echo "No lab run was going at the last update." )
README_END
echo "  $(($(wc -l < MANIFEST.txt) - 1)) files listed"

say "lab data 5/5  commit and push to GitHub (branch $BRANCH only)"
git add -A . || die "git add failed in $DATA"
ADDMB=$(git diff --cached --name-only --diff-filter=AM | while IFS= read -r f; do [ -f "$f" ] && size_of "$f"; done | awk '{s += $1} END {print int(s / 1048576)}')
if [ "${ADDMB:-0}" -gt "$MAXMB" ]; then
  git reset -q
  die "this upload would add $ADDMB MB, more than the $MAXMB MB safety limit. Nothing was committed or pushed. If that amount is right, run the same command with HM64_LABDATA_MAX_MB=$((ADDMB + 100)) in front."
fi
if [ -z "$(git diff --cached --name-only | grep -v '^README.md$' || true)" ] && git rev-parse -q --verify HEAD >/dev/null 2>&1; then
  git reset -q
  git checkout -q -- README.md 2>/dev/null || true
  echo "  nothing new to commit"
else
  WHAT=$(git diff --cached --name-only | grep -v -e '^README.md$' -e '^MANIFEST.txt$' | cut -d/ -f1 | sort -u | tr '\n' ' ')
  git diff --cached --stat | tail -n 12
  if [ -z "$(git config user.name 2>/dev/null)" ] || [ -z "$(git config user.email 2>/dev/null)" ]; then
    HN=$(hostname 2>/dev/null | tr 'A-Z' 'a-z' | sed 's/\.local$//; s/[^a-z0-9-]/-/g')
    git config user.name "hm64-lab (${HN:-lab})"
    git config user.email "hm64-lab@users.noreply.github.com"
    echo "  git had no name / e-mail on this machine: this folder now commits as hm64-lab (${HN:-lab})"
  fi
  git commit -q -m "lab data: ${WHAT:-notes }$(date +%Y-%m-%d)" || die "git commit failed in $DATA (is git's user.name / user.email set?)"
  echo "  committed $(git rev-parse --short HEAD) ($ADDMB MB of files)"
fi
if ! git rev-parse -q --verify HEAD >/dev/null 2>&1; then echo "  nothing to upload yet"; exit 0; fi
R=$(git ls-remote --heads origin "$BRANCH" 2>/dev/null | awk '{print $1}')
if [ "$R" = "$(git rev-parse HEAD)" ]; then
  echo "  GitHub's $BRANCH already has everything ($(git rev-parse --short HEAD))"
else
  t=0
  until git push -u origin "$BRANCH"; do
    t=$((t + 1))
    if [ "$t" = 1 ] && [ "${HM64_LABDATA_RETRY:-0}" -lt 3 ] && git fetch -q origin "$BRANCH" 2>/dev/null && [ "$(git rev-list --count "HEAD..FETCH_HEAD" 2>/dev/null || echo 0)" -gt 0 ]; then
      echo "  another Mac pushed first: joining its upload and trying again"
      HM64_LABDATA_RETRY=$(( ${HM64_LABDATA_RETRY:-0} + 1 )); export HM64_LABDATA_RETRY
      sleep $(( HM64_LABDATA_RETRY * 3 ))
      exec bash "$0" ${ARGS_KEEP:-} </dev/null
    fi
    [ "$t" -lt 3 ] || die "git push failed. The commit is safe in $DATA; run the same command again to push it."
    echo "  push failed, trying again in 5 s"; sleep 5
  done
  R=$(git ls-remote --heads origin "$BRANCH" 2>/dev/null | awk '{print $1}')
  if [ "$R" = "$(git rev-parse HEAD)" ]; then echo "  pushed: GitHub's $BRANCH = your copy ($(git rev-parse --short HEAD))"; else echo "  warning: pushed, but GitHub's $BRANCH reads '${R:-nothing}', your copy $(git rev-parse HEAD)"; fi
fi
echo
echo "LAB DATA DONE. For Claude: branch $BRANCH of Nillows/HM64-RNG-Manipulations is at $(git rev-parse --short HEAD)."
[ -z "${MISSING// /}" ] || echo "  Not on this Mac yet:$MISSING"
[ -z "${NOTYET// /}" ] || echo "  Left out as unfinished:$NOTYET"
[ -z "${REFUSED// /}" ] || echo "  REFUSED (ROM / save inside):$REFUSED"
[ -z "${BIG// /}" ] || echo "  Split into parts:$BIG"
if [ "$BUSY" = yes ]; then echo "  A lab run is still going: run  bash ~/Documents/hm64/tools/hm64_release.sh labdata wait </dev/null  to upload the rest by itself when it ends."; fi
exit 0
