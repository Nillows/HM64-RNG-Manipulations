HM64 Power Nut lab - CAMERA ZONES OF THE DOCK END ON THE RAINY FILES (2026-11-25)

What the pier-spot run found
  The camera's visibility grid has exactly three versions along the dock end (dumped from the emulator at every spot):
    north   Jack's z 154.8 - 158.4   (3 game frames of second-cut timing)   315 tiles   <- all recorded cast data
    middle  164 - 188.4              (5 game frames)                        302 tiles
    south   194 - 196.1              (3 game frames)                        287 tiles
  Inside a zone every spot is the same game. Between zones a cast differs only when the dog is on a tile one grid
  shows and the other does not (it stops drawing random numbers off the grid).

What this run does - the "probe, then only what is needed" plan
  From the recorded dog paths, Claude predicted which recorded casts can differ in another zone: the dog comes within
  48 units of a tile the two grids treat differently, before the cast's last bite + 10 s. On the spot run's measured
  casts that rule caught 99.3% of the real differences and every new Nut, while flagging 34% of the casts.
  This run casts those from the middle zone and from the south zone (minus the ones the spot run already made), and
  every 100th of the other casts as a check that copying them is safe:
    no horse   middle 52,655   south 52,989 casts
    horse      middle 32,422   south 32,655 casts
  All other casts of a zone are copied from the north table.

Needs    the folders of the rain120 run and of the pier-spot run (results/spots/<label>); stops with a clear line if
         something is missing. Nothing of them is changed.
Time     about 4 h (no horse) + 2.5 h (horse) at 14 workers (estimate from the spot run's speed). Queues behind a
         running lab, keeps the Mac awake, Ctrl-C and the same command continue.
         HM64_SPOTS_ONLY=nohorse (or horse) in front of the command = one save only.
Result   results/spots/<label>/SP3_zones.jsonl + ZONES.md, zip ~/Documents/hm64/runs/hm64-zones-<label>.zip, then the
         lab-data branch is brought up to date (tools/hm64_labdata.sh 2026-11-25d).

Tested   sandbox (x86 build, small rainy run): the zone stage and its report, the runner through a docker stand-in
         incl. the upload to a stand-in GitHub. The cast job is the one the pier-spot run used on the Mac.
NOT run  on the Mac with these plans.
