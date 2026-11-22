# HM64 Power Nut Tool — test build v31.27

A timing aid for catching the **Power Nut** from the ocean pier in **Harvest Moon 64 (USA, NTSC)** on a real N64.
It is one web page (`index.html`). It runs entirely in your browser, needs no install, and sends nothing anywhere
(the page makes no network requests).

Every random event in the game comes from one random number generator. The dog's behaviour on the beach is a
readout of where that generator is, and an emulator lab has recorded, for every dog path ("line") and every cast frame
up to 120 s after Jack reaches the end of the pier, every bite and what it catches. The page shows you the dog the lab
expects, lets you line it up with the dog on your TV, and tells you when to press B and when to let go.

> **Test build.** Automated tests ran in Chrome / Chromium only. Firefox and Safari have not been through them. Nothing
> has been verified on a real console by anyone but the author. Please report what you see (section 11).

---

## Contents
1. [Quick start](#1-quick-start)
2. [Setting up the game file](#2-setting-up-the-game-file)
3. [The route](#3-the-route)
4. [What the app starts with](#4-what-the-app-starts-with)
5. [Layer 1 — the histogram and its cast suggestion](#5-layer-1--the-histogram-and-its-cast-suggestion)
6. [Layer 2 — find your dog and tune it to your N64](#6-layer-2--find-your-dog-and-tune-it-to-your-n64)
7. [Layer 3 — Freestyle: choose your own cast](#7-layer-3--freestyle-choose-your-own-cast)
8. [Ending an attempt, results and reports](#8-ending-an-attempt-results-and-reports)
9. [Practice drills](#9-practice-drills)
10. [Every setting, explained](#10-every-setting-explained)
11. [Keys, limits and feedback](#11-keys-limits-and-feedback)

---

## 1. Quick start
1. Open the page in a **desktop browser with a keyboard** (Chrome recommended for now). It is about 29 MB and takes a
   few seconds to load.
2. Make the game file described in section 2 (or get a copy of one).
3. Nothing to set up: the page opens ready (section 4).
4. Play: walk the route (section 3) and **tap Space once the moment Jack stops at the end of the pier**. Click the dog
   card that matches your TV, tune it with **[ ]**, and cast on one of its bars (sections 6–7). Cast and reel on the
   controller; the keyboard is only for the tool.

---

## 2. Setting up the game file
The lab's tables were made on one specific kind of morning. Your file has to put the game in the same position, or the
tool's dog lines will not match your game.

**The file the tables were made on:**
- **Spring 4, Year 1, a sunny morning.** Other days and weather have not been tested.
- **No horse.** Anything that moves on the route and is not in the lab's file (a horse, farm animals) can draw random
  numbers before the beach and send you down a different path.
- **The fishing rod in Jack's hand** (equipped), not in the rucksack. Without it, B does nothing at the pier.
- **The dog left on the beach, in the far south-west corner** (bottom-left on screen), not carried anywhere on the
  day you play. From the end of the pier it sits at the lower-left edge of the screen.

**How to make it:**
1. The day before: take the dog to the beach, put it down in the farthest south-west (bottom-left) corner, and leave
   it there.
2. Make sure the rod is in Jack's hand and you have no horse.
3. Go home, go to bed and save in the diary, in the **first diary slot** (the lab's file is there; another slot needs
   extra menu presses, which makes you later than the tables).
4. The next morning must be sunny. If it rains, reload the day before and try again.

**Is my file right?** The dog's exact spot matters: the lab found that what counts is which 32-unit tile of the beach
the dog stands on, and a different tile shifts every dog line. You can't see tiles, so use the tool's own
check. After a few attempts in which you tapped Space at a bite (sections 5 and 8), open Setup & review → L5 →
**"Is the app working?"**. If your bite taps keep fitting "no dog line" (shown as **off the tables**), your file, your
menu speed or your route does not match the lab's, and the tool's advice will not apply.

---

## 3. The route
Everything from power-on to the end of the pier decides which dog line you get, so the route is played **as fast as
possible** with the same turns every time. Small hesitations are expected: the tables cover a range of human timings.

### 3.1 Power-on and menus
Turn the console on and **mash Start, then A**, through the title screen and the diary, to load your file as fast as
you can. (The tables start from power-on; whether pressing Reset instead gives the same start has not been checked.) The tables cover loading up to **4 game frames (about 0.13 s) later than the fastest
possible**.

### 3.2 Sparrows at the door
As Jack walks out of the house, look at the door: **two sparrows by the door** mean your menus were 5–6 frames late.
That morning has its own table. Tick **Sparrows at the door** on the page (or press **S**) before the pier. No sparrows
by the door: leave it unticked. (Sparrows also appear on some slower mornings that no table covers.)

### 3.3 General path (one held direction per screen)
- **House:** hold **up-left** through the fade-in, cut **down-left** around the table, then **down** out of the door.
- **Farm:** hold **left** to the exit.
- **Crossroads:** **left**, then cut **down-left**.
- **Ranch:** hold **down-right** to the beach. Keep holding it through the black screen into the beach.

### 3.4 The beach: the zigzag
The beach is three legs and two turns. Never stop and never walk straight down.
1. **Down-right** (held from the ranch, through the fade-in). Jack starts moving about a second after the beach
   appears.
2. **First cut, down-left:** the moment Jack clears the **small wall**, on that game frame or the next. This is the
   "tight first turn". Then **hug the back wall** going down-left.
   - Turned a little late (Jack drifts off the wall)? Correct by pressing up a moment and carry on. It costs up to half
     a second, and the tables cover it: those are the **Small fix** and **Big fix** presets (section 5).
3. **Second cut, down-right, onto the pier:** anywhere across the pier's width. Where you cut decides where Jack stops
   at the end: **Early** = near edge, **Middle**, **Late** = far edge. All of them are in the tables.
   - Cut outside the pier's window (too early or too late) and Jack does not make it onto the pier. That attempt is not
     in the tables: restart.
4. **Hold down-right** until Jack stops at the water at the end of the pier. He is now facing the sea, ready to cast.
   This moment is **READY**.

### 3.5 Space at the end of the pier (the control)
**Tap Space once, the moment Jack stops at the water.** That one tap starts the tool's stopwatch. Everything after it,
including the dog cards, the cast cue and the bite calls, counts from that tap. The tool allows for your reaction time
and learns your personal delay from your bite taps over time.

From here the hands are split: the **controller** casts (B) and reels; the **keyboard** is for the tool (Space taps,
the dog keys).

### 3.6 Stay awake
Jack lies down after **40 s** with no input. A red **WAKE JACK** line crosses the histogram 33.4 s after READY (and
every 33.4 s after that) while you are still waiting to cast. When it reaches the white line, push the stick
**down-right once**. That resets the nap timer and does not change the dog or the bites (measured in the lab). Never
push the stick after you have cast; fishing keeps him awake.

---

## 4. What the app starts with
A fresh browser opens ready, on the **Lucky Timer** tab:
- Route **Beach-lineup2 · dog on the beach** (the file in section 2), **Sparrows at the door** off.
- Start: **one Space tap when Jack stops at the end of the pier**. With this start the app offers no taps on the way in
  and hides **Pier only**; both come back only if you choose the fade-in start in Setup & review → L2.
- **Dog-watch on**, **5 dog cards**, the most likely dog **on the right**.
- **Freestyle on**: you choose the cast from your dog's bars (section 7). Switch it off (**Ctrl** or the box) for the
  app's own cast suggestion (section 5).
- Dog-watch animation keys: numpad **0** idle · **1** sit · **2** stand · **4** walk · **5** run · **6** sleep · **7** sniff ·
  **8** bark · **9** shoulder, plus **R** rollover · **F** flapper · **G** good-boy · **O** mess · **B** wiggle-bum.
- Front panels: picture of Jack · Lucky plan · dog-watch (drag the •••• grips to reorder).

Everything can be changed, and the browser remembers your changes. If you opened an earlier build on the same site, its
stored settings win over these defaults; change them by hand, or clear the site's data in the browser to start fresh.

Your settings, practice data and attempt history are stored **in your own browser**, for this site. Nothing is sent
anywhere or shared with other players. Clearing the browser's site data resets the tool.

The page also works offline: save it with your browser (File → Save Page As…) and open the saved file. A saved copy
keeps its own settings, separate from the website's.

The **Lucky Timer** tab (footer) is the tool. The **Dog reference** tab is a printable manual method (section 10).

---

## 5. Layer 1 — the histogram and its cast suggestion
This is the app's own cast suggestion: the best cast for "any dog this route can produce". It shows while
**Freestyle is off** (it is on by default: press **Ctrl** or untick the box).

**The front page, top to bottom:** the histogram; a slim lamp strip (stopwatch, Start / Stop, result keys, the
Sparrows / Pier only / Freestyle boxes); three panels you can drag into any order by their •••• grip: dog-watch,
Lucky plan, and the picture of Jack with the key list.

**The histogram** scrolls from right to left like a rhythm game:
- The **white line** is *now*.
- The **bold blue CAST line** is when to press B. Press as it crosses the white line. The lamp, the countdown and the
  glow around the screen edge all hit zero at that same moment. If the tool has learned that you press late, the bold
  line sits that much early, and a dashed "ghost" line marks the unaltered moment.
- **Bars** show the chance of a Power Nut for a cast at each moment, coloured by the bite the Nut comes on: **green** =
  let go at the **1st** bite, **gold** = hold through the 1st bite and let go at the **2nd**, **purple** = a later
  bite.

**The Lucky plan panel** shows the route name and **Cast at X after READY**, with − / + / best to move it, and
**Auto ✓ / Back to best** (lit when you moved something by hand: click it to go back to the best plan). It also has two
rows of buttons describing your run, each with its own best cast and odds:
- **Your first step on the beach:** Any / **Clean** (tight first turn, no correction) / **Small fix** (a small correction,
  0.17–0.30 s late) / **Big fix** (a bigger one, 0.33–0.50 s late).
- **2nd cut:** Any / **Early** / **Middle** / **Late** (where Jack stopped across the end of the pier).

Pick what you actually did if you know it, or leave Any. ★ marks the best 2nd cut for that first step. With the
pier-end start the plain suggestion is roughly **20 s after your tap at about 11 %** (shown live in the app; it
depends on the presets).

**After the cast** the lamp reads the bites for you:
- **RELEASE** (e.g. **BITE 1 = NUT: RELEASE**, **RELEASE ON A BITE**) = let go of B at this bite.
- **KEEP HOLDING** / **HOLD · TAP THE BITE** / **HOLD → BITE 2** = hold B through this bite and tap Space as it bites.
  From the tap, the tool works out which frames and dog lines fit and forecasts the next bite.
- **DUD — RESET** = no Nut is left on this cast: reset and save the time.
- A **pink release line** shows the best moment to let go without looking (with its chance, "blind x %").

---

## 6. Layer 2 — find your dog and tune it to your N64
Once you have tapped Space at the end of the pier, the **dog-watch** panel opens with **cards**. Each card plays what
one dog line's dog is doing *right now*, with its share of the likelihood (e.g. "17 % L5 +3").
- "**+3**" means three "sister" lines have become the very same dog by now; they are shown on one card.

**1. Choose your dog.** When a card does what the dog on your TV is doing, **click it**. The other cards disappear and
the panel becomes the **calibration view**: your dog drawn large, with three frames of it underneath (one game frame
earlier, the tuned one, one later). The dog sits on the right by default (left / middle / right in Dog-watch options), so you can put it
nearest your TV.
- Wrong dog? **Backspace** (or click it again) gives you the row back.
- A card that clearly isn't your dog can be thrown out with its **×** (or **Delete** for the top card); Backspace or
  "Undo ×" brings it back.
- Optional, if you can't tell yet: key the dog's facing with the **arrow keys** (two keys = a diagonal) whenever it
  turns, and long animations on their keys (numpad 0 idle, 1 sit, 2 stand, 4 walk, 5 run, 6 sleep, 7 sniff, 8 bark,
  9 shoulder; R rollover, F flapper, G good-boy, O mess, B wiggle-bum). Each key re-weights the lines, so the right card
  rises to the top.

**2. Tune it.** A card plays at the tool's best guess of your timing, so it can run a little early or late. Press
**[** (earlier) and **]** (later) to move it one game frame (33 ms), or **Shift + [ / ]** for 10 frames, until the
large dog turns **exactly** with the dog on your TV. The three small frames show what one frame either way looks like.

**3. The histogram changes.** With a dog chosen, the histogram stops showing odds for "any dog". It shows **that dog's
own Power Nut cast frames** as bars, at your tuned timing, and the cast suggestion re-aims to the best cast still
ahead, on any bite. In the lab's simulated runs, attempts with the right dog chosen got about 30 % instead of
about 12–13 % with no dog chosen.

**After the cast, the cards stay lit:** the card plays its dog *after* a cast on one particular frame. A card that
stays in step with your dog for more than about 3 s is the frame you landed on. Click it to **lock** that frame
(**[ ]** step it). The lamp then calls the bites exactly from the lab record: **HOLD · NUT IS BITE 2**,
**LET GO AT BITE 1 · NUT**, or **NO NUT ON THIS CAST**. Neighbouring frames show the same dog for 1–3 s after the cast
and then part, so a card parting early just means "not this exact frame".

---

## 7. Layer 3 — Freestyle: choose your own cast
Freestyle is a separate mode for when your dog is chosen and tuned: **you** choose when to cast, from your dog's own
Power Nut frames. No reflex correction is needed, because the dog on screen and the dog on your TV are in step.

**Switch it on and off** with the **Freestyle** box or the **Ctrl** key (changeable). It works before or during an
attempt. Beside the box, pick the target: **Power Nut** (default), or large / medium / small fish.

**What you see** (with a dog chosen; without one the histogram asks you to click your dog):
- **Bars** = your dog's cast frames that catch the target, coloured by bite: **green** = the 1st bite after the cast is
  the catch, **gold** = hold through the 1st bite, the 2nd is the catch.
- **Doubles / triples** (marked **×2** with a band behind them) = two or three neighbouring frames that catch the target
  on the same bite at the same moment. They give you a wider window (67–100 ms instead of 33 ms), so they are the best
  targets.
- The lamp counts down: **NEXT DOUBLE · GREEN · 4.2 s**. For your dog's last double it says **LAST DOUBLE** and pulses
  red from 8 s before (with the glow setting on).
- **Threads:** under the bars is a thin **release lane**. Every bar has a thread from the bar down to the moment its
  catch can be reeled in. Once you pass a bar, its thread's top stays on the white line and the thread swings upright.
  **When it stands straight up, let go of B** (only if you cast on that bar). The lamp says it too: **GREEN THREAD · LET
  GO IN 1.2 s → LET GO NOW**.
- **WAKE JACK** lines keep coming every 33.4 s until you cast (section 3.6).

**How to play it:**
- Watch the countdown, **press B on a bar**, ideally a double.
- **Simplest way, no keyboard needed:** cast in a **green** bar's window and let go at the **first nibble**. For a
  **gold** bar, hold through the first nibble and let go at the second.
- **Optional:** tap **Space as you cast**. The tool takes the nearest double (or group of bars) as the one you went for,
  leaves only that one's thread on screen, shows a pink release line inside its window, and grades the cast in the
  report: **INSIDE**, or **n ms EARLY / LATE**. **Backspace** = "that wasn't my cast". You don't need this; it only helps
  you focus on the release that's left.
- A freestyle attempt with no cast stops by itself at the end of the data (120 s after READY), without logging
  anything.

For a sense of scale (lab calculation): the best group of bars on a dog line is worth about **29 %** with a press
spread of ±150 ms and about **47 %** at ±60 ms. In other words, steadier hands are worth more than anything else.

---

## 8. Ending an attempt, results and reports
- **H** = caught the Power Nut · **M** = caught a fish / missed · **E** = empty line · **Esc** = stop without logging.
- **Bite taps** (Space at a bite while holding B) are what the tool learns from: your reaction, your clock, which dog
  lines you really land on. They are stored even when you press Esc.
- Setup & review → **L4 · Attempts**: every attempt has a **Report** (the cast moment close up: target, where your press
  landed, the dog line, the locked frame) and **Copy report** for sharing. **Remove** takes a bad attempt out of
  everything the tool learned (**Undo** puts it back). **Export** / **Clear** for the whole log.

---

## 9. Practice drills
Under the picture of Jack:
- **Cast + bite practice:** the whole motion as on the N64. The histogram counts down to CAST, you press Space (or a
  controller button on a USB pad) on the cue and **keep holding**, Jack casts, a bite comes 1.4–5.2 s later, and you
  **let go** the instant the rod dips. The lamp gives both results, e.g. **CAST +42 MS · CAUGHT 231 MS**. These feed your
  press habit and your release reaction.
- **Bite practice:** only the bite. Hold, let go when the rod dips. A bite can be caught for 20 video frames (334 ms):
  CAUGHT / LATE / TOO EARLY.
- **Esc** stops a drill.

---

## 10. Every setting, explained

### Front page
| Control | What it does |
|---|---|
| **Start / Stop**, **▶ Preview a lucky attempt** | Start / stop by mouse (Space starts, Esc stops); Preview plays an attempt's cues with no console. |
| **Power Nut (H) · Fish / missed (M) · Empty line (E)** | Log the result (the same as the keys). |
| **Sparrows at the door** (S) | Use the table for mornings with two sparrows at the house door (section 3.2). |
| **Pier only** (X) | Only shown with the fade-in start: a one-attempt override that makes the next (or last) Space the end-of-pier tap. Hidden (and X does nothing) with the default one-tap start, which already is that tap. |
| **Freestyle** box, **key** button, target menu | Freestyle mode on / off, change its key (default Ctrl), target Power Nut / large / medium / small fish. |
| **Dog-watch** panel: [ earlier · later ] · zero · Clear my pick · Undo × | Tune the dog cards by a frame, back to zero, drop your chosen dog, undo removed cards. |
| **Dog-watch options** → Dogs on screen 3 / 5 / 7 | How many cards (default 5). |
| → most likely dog on the left / in the middle / on the right | Where the top card (and the chosen, large dog) sits (default right). |
| → **Mouseover forecast** (off) | Hover a card to list that dog's next moves with countdowns. |
| → **No missed turns once I start** + late arrows allowed up to … ms | Strict arrow logging: once you start keying, every turn must be keyed (late entries allowed up to the limit). Lines that don't show your sequence drop out. |
| **Lucky plan** panel | See section 5 (presets, Cast at … − + best, Auto ✓ / Back to best, the last attempt in a few lines). |
| **Cast + bite practice**, **Bite practice** | Section 9. |

### Setup & review (the fold at the bottom)
**L1 · Plan details**
| Setting | What it does |
|---|---|
| **After the cast:** Auto / Smart zones / 1st bite / 2nd bite / 2nd bite + tap | The release rule the plan uses. Auto picks the best. Smart zones: let go of the 1st bite only inside a release window, otherwise hold and tap it. 1st bite / 2nd bite: fixed rules. 2nd bite + tap: always hold through bite 1 and tap it, so the tool can forecast bite 2 or call DUD. |
| **Aim for:** best odds per attempt / fastest Nut | Best chance per attempt, or the best chance per minute (an earlier cast with slightly lower odds). "An attempt costs … s besides the wait" = your reset time, used for the per-minute maths. Ignored while dog-watch is on (the cast stays on best odds). |
| **Personalized cast suggestion (experimental)** | Aims with your own measured timing (B presses, clock taps, how well your offset is known) instead of a plain bell curve. A loose or lopsided timing then prefers wide plateaus over narrow peaks. |
| **P(Nut) overview** | The chance for a cast at each moment with your timing spread. Click it to choose another cast time. |
| **How to do this attempt** | The route and the start in words. |

**L2 · Start & taps**
| Setting | What it does |
|---|---|
| **Start the stopwatch** | **"when Jack stops at the dock end (READY)"** (default): one Space tap, nothing on the way in. The other option, "when the beach starts to fade in", is a multi-tap start for experienced runners with slightly higher odds (11.6 % vs 11.0 %); choosing it brings back the tap strategies and **Pier only**. |
| **Start key** | Space by default. |

**L4 · Attempts**: section 8.

**L5 · Your timing**
| Fold | What it does |
|---|---|
| Timing picture | Each dot is something measured about you: left = early, right = late, top = steady, bottom = loose. |
| **Set by hand** | Start-tap delay, cast-cue correction (your B-press habit) and timing spread. Each is learned automatically while its box is ticked; untick one to set it yourself. |
| **Is the app working?** | Your bite taps vs the tables (do they fit a dog line, or are they "off the tables"?), Nuts expected vs caught, where your casts land. |
| **What the app learns, and its limits** | What is learned, from what, and how far it may move. |
| **Your data: clear stats** | Clear any one store (attempt log, bite taps, dog-watch records, clock taps, cast practice, bite practice) or **Clear all stats**. Settings and keys are kept. |
| **Your dog lines** | Which lines your attempts were on, vs how common the lab found them. "Also count what the dog-watch saw" is experimental. |
| **Bite practice**, **Cast practice** | Statistics and options of the drills ("tap instead of hold-and-let-go", "use it as my bite-tap delay", "moving cast line", "full wait", "hold on to the bite and let go", "Copy to my hand-set values", "Forget …"). |

### ⚙ Settings → Lucky Timer tab
| Setting | What it does |
|---|---|
| **Route (save / dog spot)** | Which lab table to use: **Beach-lineup2** for the file in section 2. The others are older saves and routes. |
| **Watch the dog at the dock end** | Turns the dog-watch panel (cards) on. |
| **Facing keys** arrow keys / W A S D | Keys for the dog's facing. |
| **Hands on B (stop logging) before the cast (s)** | Dog-watch logging closes this long before the cast (default 2 s). |
| **Dog-watch keys** | Reassign the animation keys (defaults in section 4) and the earlier / later card keys. Keys the tool itself uses are refused. **Reset these keys** returns to the defaults. |
| **Release line** | Show the pink release line (normal mode: best blind release; Freestyle: the middle of your marked cast's window). |
| **Cast tap** + precision | Optional: also tap Space when you press B, so the tool knows your real cast time. |
| **Glow around the screen edge** | The lamp's colour around the whole screen edge, for the corner of your eye. In Freestyle it also covers the LAST DOUBLE pulse. |
| **Facing when casting** SE / E | Only changes the picture of Jack. |
| **Sound too** / … release-window sounds | Beeps with the visual cues (off by default). |
| **Load your own angler frames** / Stick figure | Change the picture of Jack. |

### ⚙ Settings → Console & shared timing / Calibration & data tabs
Mostly settings of the older "Dog Oracle" page, which this build no longer shows. Two matter:
- **Console game update (ms; NTSC N64 = 33.430)**: **leave it at 33.430.** If it is changed, the front page shows a red
  warning with a one-click fix.
- **Your tap delay, mean (ms)**: the tool's first guess for your bite-tap delay, until it has learned yours.

### Dog reference tab
A manual method for when the live tool is not wanted: what the dog is doing as Jack stops at the end of the pier →
which line you are likely on → how long to wait before casting (best-odds and quick casts per behaviour), the
"harbinger" behaviours that give a line away, and a simple Space stopwatch (Space when Jack stops, Esc to stop; click
a cast time in the tables to count down to it). Tabs: **First 10 seconds, by line** · **As you stop** · **Harbingers**.
Its own settings: **Table** (Beach-lineup2 for the file in section 2), **Sparrows at the door** (S), **How exact is your
cast?** (±100 / 150 / 200 / 300 ms), **Aim for** best odds or a quick cast of **at least** n %, and **Your reaction when
Jack stops** (ms, taken off your Space tap). **Print the tables** gives a paper copy.

---

## 11. Keys, limits and feedback

### Keys
| Key | When | Does |
|---|---|---|
| **Space** | at the end of the pier | starts the attempt (the stopwatch) |
| **Space** | after the cast, holding B | marks a bite (the tool forecasts the next one) |
| **Space** | Freestyle, as you cast (optional) | marks your cast |
| **B** (controller) | — | cast, hold, let go. The tool never sees it |
| **Ctrl** | any time | Freestyle on / off (changeable) |
| **S** / **X** | before the pier | sparrows at the door / pier-only override (X: fade-in start only) |
| **Arrows** (or WASD), **Numpad 0–9**, **R F G O B** | dog-watch | dog facing / long animations (section 4) |
| **[ ]**, **Shift + [ ]** | dog chosen | move the dog 1 / 10 game frames |
| **Enter** | after the cast | lock the frame of the card you are tuning |
| **Backspace** | — | undo: the chosen dog, a removed card, the last arrow, a Freestyle cast mark |
| **Delete** | dog-watch | remove the top card |
| **H / M / E / Esc** | — | Nut / fish / empty / stop without logging |

### What is not verified yet
- **Browsers:** tested automatically in Chrome only. Firefox / Safari untested.
- **Real hardware:** the tables come from an emulator. The game logic is deterministic (the decompiled source shows no
  hardware randomness), but two things are open: whether a console steps the game at exactly the emulator's rate
  between the beach fade-in and the cast, and whether a person can match a card to one game frame by eye on a TV.
- **Two hands:** Space (keyboard) and B (controller) are different hands; how far apart they land is not measured.
- **One setup:** one save (section 2), one route (section 3), NTSC USA timing (16.715 ms per video frame).

### Feedback that helps
Your browser and system; what you did; what you expected; what happened. **Copy report** from the attempt list
(Setup & review → L4) gives a text block worth pasting, and "Is the app working?" (L5) tells whether your runs fit the
tables at all.
