HM64 lab pool campaign "zones-married" (2026-11-27a) - the pier zones of the married, no-horse files

  bash ~/Documents/hm64/pool/campaigns/tools/hm64_pool.sh run zones-married topdown|bottomup|middleout </dev/null

For the sunny (237e3d1d) and the rainy (62991249) married save, sunny first:
  gate  every machine for itself: each dog line from a member standing in the middle (Jack's z 176.4) and the south
        (194.4) zone, no cast, to 170 s after READY, compared with the recorded line: 224 + 182 line jobs (a line that
        differs is a finding). Control casts at the recorded spot: 672 + 546 (the recorded bites must come out, or
        part A is skipped for that save on this machine).
  A     recorded casts whose dog comes within 48 units of a tile the zone's camera grid treats differently, + every
        100th other cast, from the middle and the south zone, each held as long as its recording:
        sunny 39,258 casts in 2,437 jobs; rainy 141,614 casts in 6,461 jobs. 8 lines per save never stand outside the
        north zone (183 / 1,930 casts): nothing to measure.
Plans: sunspots/zone_plan.py + sunny_plan.py (the sunny pier-spot campaign's) on the married recordings of lab-data
(dog-watch zz_lines, FD windows d90 / d140c90 / d170c120 of both Macs: 75,997 + 174,787 recorded casts).
Needs on the machine: results/dogwatch/<label> and states/dogwatch/<label>/b of both married saves (pool "sync" from
the main Mac, or "pull" on a machine the main Mac cannot reach). No ROM, saves or savestates in this folder.
Results: results/gaps/<label>/GA_gate*.json(l), GA_casts.jsonl; runs/hm64-gaps-<label>@<machine>.zip; lab-data folders
married-sunny / married-rainy (lab-data script 2026-11-27a).
Runner = the late-Nuts runner of 2026-11-26 (ran on both kinds of machine) with other saves, plans and part A.
New and NOT tested: under Windows (WSL) the runner starts a PowerShell process that asks Windows to stay awake.
NOT tested: this campaign on a real emulator (the machine's own gate is that check: watch its first minutes).
