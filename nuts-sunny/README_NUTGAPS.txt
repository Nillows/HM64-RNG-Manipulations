HM64 lab pool campaign "nuts-sunny" (2026-11-26 evening)

Why: the sunny zone tables of v32.27 show 116 (no horse) and 167 (horse) cast frames as "not proven" outside the north
end of the pier: their Power Nut is a 5th or 6th bite 142-151 s after READY, later than the recorded part of the cast.
They belong to 12 + 15 cast states. This campaign casts each of them once from the north spot, the middle and the south
and holds it to 170 s after READY: 36 + 45 casts. A test with made-up results says: with these casts no frame of
either file stays "not proven".

What a machine does (bash hm64_pool.sh run nuts-sunny topdown|bottomup|middleout):
  gate   the no-cast dog of the 11 + 13 lines involved, from their middle and south member, to 170 s (22 + 26 jobs),
         and each cast's recorded row again at the recorded spot (12 + 15 control casts: the recorded bites must come
         out). Every machine runs this for itself: on the PC it is the proof of the new container on both saves.
  B1     the 36 + 45 casts, shared through branch lab-coord (2 blocks per save).
Results: results/gaps/<label>/GB1_casts.jsonl next to this afternoon's files (nothing of them is changed); zips
hm64-nutgaps-<label>@<machine>.zip (the new casts, the gate's verdict, the log) -> lab-data (script rev 2026-11-26l);
every result file also goes to branch lab-parts-<machine> as before.
It needs what the sunny pier-spot campaign needed (the two sunny dog-watch folders and their beach savestates).
No ROM, saves or savestates are in this folder.
