# HM64 lab data (branch `lab-data`)

Raw results of the Power Nut lab runs on Thomas's Mac, for rebuilding and re-verifying the tool's data
(route tables, cast packs). Not part of the website: GitHub Pages serves the `main` branch only.
No ROM, saves or savestates in any file. sha256 of every file: `MANIFEST.txt`.
Kept up to date by `~/Documents/hm64/tools/hm64_labdata.sh` (2026-11-26g), which every release runs.

| folder | run | save |
|---|---|---|
| sunny-no-horse | dog-watch + full-day d90 / d110 / d140c90 / d170c120 (2026-11-16 to 22) | beach-lineup2 52cfd712 |
| sunny-horse | horse120 (2026-11-23) | beach-lineup2-horse b0f2a284 |
| rainy-horse, rainy-no-horse | rain120 (2026-11-23/24; its log is in rainy-no-horse) | beach-lineup2-horse-rainy 287c11a6, beach-lineup2-nohorse-rainy 8e972d75 |
| married-sunny, married-rainy | married120 (2026-11-25; its log is in married-sunny) | married no horse, sunny moved to spring 9 237e3d1d, rainy 62991249 |
| spots-rainy-no-horse, spots-rainy-horse | pier spots (2026-11-25; `hm64-spots-<label>.zip`: every line from every pier spot, the recorded casts from three other spots; `hm64-zones-<label>.zip`: the casts that can differ, from the middle and south camera zones; logs in spots-rainy-no-horse) | the two rainy saves |

Per save: `hm64-dogwatch-<label>.zip` (dog lines, traces, Lucky Timer cast tables) and
`hm64-fullday-<tag>-{d90,d140c90,d170c120}.zip` (the dog after the cast: casts 0.1-40 s held to 90 s, 40-90 s to
140 s, 80-120 s to 170 s), plus the run's log. A file named `*.part-aa`, `*.part-ab` ... was over 95 MB:
`cat name.part-* > name`.

Get only this branch:

    git clone --depth 1 --branch lab-data --single-branch https://github.com/Nillows/HM64-RNG-Manipulations.git hm64-lab-data

Then check: `cd hm64-lab-data && shasum -a 256 -c <(awk 'NR>1 {print $1"  "$3}' MANIFEST.txt)`

Last update: 2026-11-26.
Not on the Mac at the last update: nothing missing
Left out as unfinished at the last update: none
No lab run was going at the last update.
