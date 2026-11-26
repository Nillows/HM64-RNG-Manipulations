HM64 lab pool campaign "spots-sunny" (2026-11-26a) - does the pier end's camera zone matter on a SUNNY morning?

Start (any Mac of the pool, one direction each):
  bash ~/Documents/hm64/pool/campaigns/tools/hm64_pool.sh run spots-sunny topdown|bottomup|middleout </dev/null

Why: every sunny cast was recorded with Jack at the north end of the pier end, like the rainy ones. In the rain the
middle and south zones turned out to play differently (a dog off the camera's grid draws no random numbers). The sunny
recordings show the dog near a tile the zones' grids treat differently on 14% / 11% of the recorded casts (10,878 of
76,215 no horse, 9,869 of 87,725 horse), and 3-6 dog lines per window leave the grid: so it has to be measured.

For both sunny saves (no horse 52cfd712, horse b0f2a284), in this order:
  gate  = THE FAST CHECK, every Mac for itself (not shared): each dog line from a member that stands in the middle
          (Jack's z 176.4) and in the south (194.4) zone, NO cast, watched to 170 s after READY (the end of the cast
          data) and compared with the recorded line, dog change for change: 224 + 296 line jobs. Prints per zone on
          how many lines the dog is the recorded one to the end. A line that differs is a FINDING, not a failure.
          Plus control casts at the recorded spot (642 + 785): the recorded bites must come out, otherwise this lab is
          not on the recorded casts and part A is skipped for that save (GATE FAILED: tell Claude).
  A     the casts that can differ: every recorded cast whose dog comes within 48 units of a tile the zone's grid
        treats differently, + every 100th other cast as a check of the ones that are copied; from the middle and from
        the south zone; each held exactly as long as its recording (90 / 110 / 140 / 170 s), so every recorded bite is
        compared and nothing stays "not proven": 22,877 + 21,156 casts in 1,853 + 1,962 jobs.
Same jobs, label rule and driver as the rainy gap campaign's part A (proved on both Macs on 2026-11-26: gate passed,
all jobs present, no duplicates). 8 lines per save never stand outside the north zone: nothing to measure.
Results: results/gaps/<label>/GA_gate*.json(l), GA_casts.jsonl in the lab work folder; runs/hm64-gaps-<label>@<machine>.zip;
every 30 min to branch lab-parts-<machine>; at the end to lab-data (folders sunny-no-horse, sunny-horse; lab-data
script rev 2026-11-26j: skips zips whose contents are already on GitHub).
Needs on the Mac (the pool's "sync" copies them from the main Mac): results/dogwatch/<label> and
states/dogwatch/<label>/b (the beach savestates) of both sunny saves. No ROM, saves or savestates in this folder.

Checked before sending (sandbox): plans made from the lab-data copies of the sunny runs (dog-watch zz_lines, the
full-day windows, FD1 lines to label 10198); the driver with a stand-in emulator (fast check counts, non-fatal lines,
fatal control casts, two machines on one table, all jobs once); the runner end to end on a stand-in Mac.
NOT checked: a real emulator run on a sunny save (the Mac's own gate is that check: watch its first minutes);
whether the Macs' dog-watch folders are the ones on lab-data (the driver stops with a message if not).
