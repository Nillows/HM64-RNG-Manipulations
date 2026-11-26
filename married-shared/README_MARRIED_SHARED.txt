HM64 lab: the married tables on several Macs (2026-11-25)
==========================================================
The married120 run, unchanged in what it measures (same saves, presets, windows, kit fullday-2), with the cast blocks
shared between Macs through the lab-coord branch on GitHub.

  Main Mac (has the run so far):   bash run_hm64_married_shared.sh up
  Helper Mac:                      bash run_hm64_married_shared.sh down      (a third Mac: middle)

What is shared: the cast blocks of the "dog after the cast" windows (step 6). Each cast block is cut into 50 parts;
a Mac claims a part, runs it, marks it done; the claims go to GitHub every 30 s; a Mac never takes a part another
holds or has done. The main Mac walks windows and blocks in order and each block from its top; a helper walks them
in reverse and each block from its bottom. A Mac silent for 90 minutes loses its claims to the others.
What is NOT shared: the dog-watch phases (steps 4-5). They build savestates on the Mac that runs them, so only the
main Mac makes them; a helper works on a save only after hm64_cloud_setup.sh has copied that save's finished
dog-watch run over the LAN (ROM, saves and savestates never go to GitHub).
Results: every Mac keeps its own part of each FD_casts_bNN.jsonl and uploads hm64-fullday-<window>@<machine>.zip to
lab-data at the end; the reports each Mac prints cover its own part only. Claude merges the parts by job tag.
On the main Mac everything measured so far counts: a finished block is only announced to the other Macs.

Tested (sandbox): the claim logic (2 and 3 machines, real git remote); the same shared stage end to end with the real
emulator in the zone campaign; this campaign's hook with a stub job runner (same rows as the unshared path; a second
machine finds every part done). NOT tested: this runner end to end, anything on a Mac.
