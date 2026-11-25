# HM64 lab data (branch `lab-data`)

Raw results of the Power Nut lab runs on Thomas's Mac, for rebuilding and re-verifying the tool's data
(route tables, cast packs). Not part of the website: GitHub Pages serves the `main` branch only.
No ROM, saves or savestates in any file. sha256 of every file: `MANIFEST.txt`.

| folder | run | save |
|---|---|---|
| sunny-horse | horse120 (2026-11-23) | beach-lineup2-horse b0f2a284 |
| rainy-horse, rainy-no-horse | rain120 (2026-11-23/24) | beach-lineup2-horse-rainy 287c11a6, beach-lineup2-nohorse-rainy 8e972d75 |
| married-sunny, married-rainy | married120 (2026-11-25) | married no horse, sunny moved to spring 9 237e3d1d, rainy 62991249 |

Per save: `hm64-dogwatch-<label>.zip` (dog lines, traces, Lucky Timer cast tables) and
`hm64-fullday-<tag>-{d90,d140c90,d170c120}.zip` (the dog after the cast: casts 0.1-40 s held to 90 s, 40-90 s to
140 s, 80-120 s to 170 s), plus the run's log. A file named `*.part-aa`, `*.part-ab` ... was over 95 MB:
`cat name.part-* > name`.

Get only this branch:

    git clone --depth 1 --branch lab-data --single-branch https://github.com/Nillows/HM64-RNG-Manipulations.git hm64-lab-data

Then check: `cd hm64-lab-data && shasum -a 256 -c <(awk 'NR>1 {print $1"  "$3}' MANIFEST.txt)`

Not found on the Mac when this was last updated: married-sunny/hm64-fullday-married-sunny-d90.zip married-sunny/hm64-fullday-married-sunny-d140c90.zip married-sunny/hm64-fullday-married-sunny-d170c120.zip married-rainy/hm64-dogwatch-married-lineup2-rainy-62991249.zip married-rainy/hm64-fullday-married-rainy-d90.zip married-rainy/hm64-fullday-married-rainy-d140c90.zip married-rainy/hm64-fullday-married-rainy-d170c120.zip

Note: a lab run is still going (runs/dogspots/.running): the married files it has not finished yet are not here - run this again when it is done.
