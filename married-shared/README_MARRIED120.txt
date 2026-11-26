HM64 Power Nut lab - MARRIED TABLES TO 120 s (2026-11-25)

WHAT IT DOES
One overnight command that makes the beach-lineup2 data set on your two married, no-horse saves (married-nohorse.zip),
one after the other:
  1. sunny   "Harvest Moon 64 (USA).beach-lineup2-nohorse-married-sunny.SaveRAM" (sha256 01999fee...), as a copy
             moved from spring 8 to spring 9 (see 2 below; the copy is sha256 237e3d1d...)
  2. rainy   "Harvest Moon 64 (USA).beach-lineup2-nohorse-married-rainy.SaveRAM" (sha256 62991249..., spring 9)
Both are found by sha256 in ~/Documents/hm64/sourcefiles (any subfolder) or ~/Downloads, whatever their names, or
inside married-nohorse.zip in ~/Downloads; copies are kept in ~/Documents/hm64/sourcefiles/married/.
For each save it uses the same recipe, lab code, windows and native ARM image as the sunny lineup2, horse and rainy runs:
  A. Dog-watch run, preset "dogwatch": menus 0-6 game frames late, the zig-zag with its turn windows, D 84 / 86, beach
     wait 0-30 VIs, every second cut. Every dog line's natural path and what the dog shows for 40 s. Then the Lucky
     Timer cast tables: every game frame 0.1-40 s, every bite to 90 s.
  B. Dog after the cast, the three windows of the app's data:
       married-<save>-d90       casts 0.1-40 s, everything followed to  90 s after READY
       married-<save>-d140c90   casts 40-90 s,  everything followed to 140 s
       married-<save>-d170c120  casts 80-120 s, everything followed to 170 s
None of the other results or savestates are touched: labels married-lineup2-sunny-237e3d1d and
married-lineup2-rainy-62991249, their own folders.

THE MAC STAYS AWAKE
The script holds caffeinate -dims for its whole length (display, idle, disk and system sleep), tied to the script: it
ends when the script ends or is stopped. It also reads pmset: if Low Power Mode is on it prints a WARNING (the run is
slower; turn it off in System Settings > Energy), and on a Mac with an Energy Mode setting it notes that High Power is
there if you want the fans up. Leave Docker Desktop open.

BEFORE IT SPENDS THE NIGHT (for BOTH saves; it stops at the first problem, nothing half-done)
- finds both saves (and takes them out of married-nohorse.zip if that is where they are)
- the sunny save: makes the spring 9 copy (tools/save_redate.py: only the two date bytes and the checksum change) and
  checks it comes out byte for byte as the sandbox's copy (sha256 237e3d1d...)
- reads each save's diary slot 0 and checks it is what this run is for: sunny / rain, married to Karen, no horse, no
  baby, spring 9, dog on the beach on tile 18:23, rod in Jack's hand, valid checksum (tools/save_check.py)
- the lab health test
- plays the reference route from power-on twice on each save (tools/married_z0_check.py): the two boots must agree, and
  each save must give exactly what Claude's sandbox got: sunny beach load at draw 1073, the dog's first move 213 VIs
  later (draw 1180), READY 339 VIs after the beach load at x -92 z 194, draw 1259; rainy 7429 / 9382 / 10593.

WHAT THE SANDBOX FOUND (read before you start)
1. Marriage changes nothing on the reference route. Karen stands idle in the house from 6:00 to 7:59 at x -128 z -64
   [decomp npc.c, her married schedule], and idle draws no random numbers: a copy of the sunny married save with the
   marriage taken out gives the same route to the draw. Off the reference route (other menu timings, other turns in
   the house) she could still be in Jack's way; the run finds out.
2. Your sunny married save is spring 8, the Planting Festival [decomp game.c setFestivalDailyBits; spring 1, New Year's,
   is one too]. On a festival morning the route draws 8 fewer random numbers on the farm (beach load at draw 1065
   instead of 1073), so its tables would only fit festival mornings. You said the tables are for ordinary days, so the
   run uses the same save moved to spring 9 (a Tuesday): its route is the ordinary one, to the draw the same as your
   unmarried sunny lineup2 save (spring 4). Tested: spring 3, 4, 5, 6, 9, 12 and every weekday give the ordinary route.
3. Your rainy married save (spring 9) gives the same reference route as your rainy no-horse save (spring 5), to the draw.
4. Both married saves have the dog at x -197.272 z 222.243: the same tile as the other lineup2 saves (18:23), 0.4 units
   from the horse saves' spot and 1.8 from the no-horse saves' spot. Different dog spots make slightly different dog lines (the horse comparison found 1-3% of
   twin casts differ by the spot), so these tables belong to these saves.
5. Your saves have a second fishing rod in the hoe's slot (tools [24, 1, 3, ...]); the run never changes tools, so it
   does not matter here.
6. Small test of the recipe in the sandbox (preset dogwatch-test, 2 lines cast): see the end of this file.

HOW LONG
Not measured on these saves. Your sunny horse run took about 4 h 50 min; the rainy saves took longer in phase 3 (115 /
111 min against 73). So about 5 h for the sunny save and 6 h for the rainy one, about 11 h for both. Every stage prints
an ETA. Ctrl-C any time; running the same command again carries on where it stopped. Needs 25 GB free.

WHAT TO SEND BACK
When a save is finished its zips are copied to ~/Documents/hm64/runs/hm64-married120-<time>/ (the second save adds its
own when it is done):
  hm64-dogwatch-married-lineup2-sunny-237e3d1d.zip   (lines, traces, Lucky Timer cast tables, DOGWATCH.md, ZIGZAG.md)
  hm64-fullday-married-sunny-d90.zip, -d140c90.zip, -d170c120.zip
  hm64-dogwatch-married-lineup2-rainy-62991249.zip
  hm64-fullday-married-rainy-d90.zip, -d140c90.zip, -d170c120.zip
  run-married120-<time>.log
No ROM, saves or savestates are inside. Files over 30 MB go through the GitHub repo's devfiles/ folder.

OPTIONS
  HM64_MARRIED_ONLY=sunny bash run_hm64_married120.sh     one save only (sunny or rainy)
  bash run_hm64_married120.sh 13                          workers (default: the image's CPU count - 1)
  HM64_MARRIED_WAIT=0 bash ...                            stop instead of queueing behind another lab run

NOT TESTED
- Not run on your Mac or under Docker. In the sandbox it ran end to end through a stand-in for docker on the x86 build
  (with stand-ins for caffeinate and pmset), with the small test preset (dogwatch-test, 2 lines, 2 casts per block,
  one test window), on both saves, starting from married-nohorse.zip in Downloads.
- The ARM image on these saves: the pre-flight compares it with the sandbox's x86 records of both routes.

SANDBOX TEST (2026-11-25, stand-in Mac, preset dogwatch-test = the small recipe: 2 menu rhythms, one house / crossroads
turn, D 84 / 86, waits 0-30 VIs by 6)
- From married-nohorse.zip in Downloads: both saves taken out, the spring 9 copy made (sha256 237e3d1d..., equal to the
  sandbox's), both saves PASS, both reference routes equal to the sandbox records.
- Sunny married: 11 house arrivals (8 in band), 7 ranch / 7 beach states, 42 line keys, 26 dog lines after Z6.
  Rainy married: 18 line keys, 51 dog lines, 355 (line, timing) variants - the same counts as the rainy no-horse test
  copy gave in the rain run's sandbox test.
- One 90-s window, 2 lines, 4 casts per save: 0 job errors, 1,496 hash checks equal, 0 different.
- Whole test 11 min; a second start finds every stage done; with no saves anywhere it stops at step 2 before any work.
  caffeinate started with the script and ended with it.
