HM64 lab pool campaign "gaps-rainy" (2026-11-26e) - what v32.23's rainy tables still mark "not proven", and why casts differ

Start (any Mac of the pool, one direction each):
  bash ~/Documents/hm64/pool/campaigns/tools/hm64_pool.sh run gaps-rainy topdown|bottomup|middleout </dev/null

Parts, in this order for both rainy saves (no horse 8e972d75, horse 287c11a6):
  gate  every Mac for itself (not shared): the chosen members of the part-A lines must show the recorded dog for 8 s, and
        casts at the recorded spot must give the recorded bites. Fails -> part A is skipped on that Mac, the rest runs.
  A     the 3 + 1 dog lines never cast away from the north zone, from a member that stands in the middle / south zone
        on its own beach state (labels through its k_off): 4,878 + 456 casts, every one held to 170 s after READY
  B1    recorded Nuts after the measured part of a zone cast (or after the recorded row of a copied cast): 2,264 +
        1,650 casts held to the Nut's bite + 120 VIs
  C     per-frame trace (generator value, dog on the camera's grid, position, facing, action) of 144 + 144 casts that
        differ between the north spot and a zone, from both
  B2    every cast a zone measured with other bites than the recording, held on to 170 s: 40,676 + 29,503 casts
Results: results/gaps/<label>/GA_gate*.json(l), GA_casts.jsonl, GB1_casts.jsonl, GC_trace.jsonl, GB2_casts.jsonl in
the lab work folder; runs/hm64-gaps-<label>@<machine>.zip; every 30 min to branch lab-parts-<machine>; at the end to
lab-data (folders spots-rainy-*; lab-data script rev 2026-11-26h).
Needs on the Mac (the pool's "sync" copies them from the main Mac): the rainy dog-watch results and beach savestates
and the pier-spot run's summary. No ROM, saves or savestates in this folder.

Checked before sending (sandbox): the plan's label rule on 4,765 measured rows; on the x86 emulator with a small
dog-watch run of the rainy no-horse save - a member on another beach state shows the representative's dog and cast
hashes label for label (north, middle and south members), casts from it give the representative's bites, and the
trace job's bites equal the cast job's; the runner end to end with a stand-in emulator, two machines on one table.
Not checked: the native ARM image with these jobs, the real job lengths, `hm64_pool.sh run` on a real Mac.
