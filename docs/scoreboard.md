# Theme scoreboard

The critics keep finding the same eight problems. This page keeps one row for each, with a score, the number that measures it, and what would move it. **Every core-loop PR names the row it moves and updates that row here in the same PR.** A whole-game critique (about every 25 PRs) re-checks every row.

Sources: `docs/design_review.md` (Oct), `docs/design_review_2.md` (16 Oct), the 29 Oct whole-game critique, review 4 of 12 Nov (`critique-12nov/design_review_4.md` in the project files) and the three blind critics of 13 Nov (`critique-13nov/ranked-report.md`). Code checked against main `a3984fe` (25 Nov).

## Scale

| Score | Meaning |
| --- | --- |
| **0 Open** | The problem is there, nothing has moved it. |
| **1 Partly** | Some of it is fixed, but a critic or a playtest would still raise it. |
| **2 Mostly** | Fixed in the code; not yet confirmed by the number or a TV playtest. |
| **3 Fixed** | The number hits its target **and** a TV playtest agrees. |

Only a number or a playtest moves a row to 3. A code change alone stops at 2.

## The board (25 Nov)

| # | Theme | Score | The number | Today | Target |
| --- | --- | --- | --- | --- | --- |
| 1 | Bots too perfect | **2 Mostly** | Bot mistakes per pour (slips, misreads, late kills) | not printed yet | 2 or more a pour at bronze tier, 1 at gold |
| 2 | The game makes decisions for the player | **1 Partly** | Answer leaks: decision prompts where the right option looks different with Gold assist off | **1** (slump call) | 0 |
| 3 | No difficulty curve | **1 Partly** | Medal spread: all-bot pour time ÷ gold target, bottom floors vs top | **backwards**: L1-3 1.26, L9-11 0.96 | top floors at least 10% harder than L1-3 for the same bots |
| 4 | Idle jobs | **1 Partly** | Idle %: share of pour time each job has nothing to do | not printed yet | no job above 25% on a pour day |
| 5 | Text too small for a TV | **1 Partly** | Smallest on-screen text at 1080p, default settings | **about 19 px** (13 px base) | 24 px or more |
| 6 | Colour-only marking | **2 Mostly** | Marks that use colour alone (audit list below) | **1** to check (trade colours) | 0 |
| 7 | Empty-hopper spiral | **0 Open** | Blockages from a starved line per pour, all-bot | not printed yet | 0, and the herald says why when it happens |
| 8 | A dropped phone stays a person | **0 Open** | Seconds until a dropped phone's job goes to a bot | **never** | 15 s or less |

Total: **8 of 24.** The core-loop month aims for 16.

---

## 1. Bots too perfect: 2 Mostly

**What the critics said.** Bots never miss, so an all-bot crew sets an impossible bar and humans feel worse than the AI (Oct review, 29 Oct). Review 4 marked it "fixed (mostly)".

**Fixed so far.** Slips with a line of chat (`bots.gd` `_plan_slips`, about line 70), a misread chance at the slump call, and pace and reaction by tier: `PACE` 0.75 / 0.88 / 1.0 and `REACT_T` 1.3 / 0.8 / 0.45 s (`bots.gd:32-34`). The bot tier starts at bronze and steps up only when the crew beats it.

**Still open.** Nobody has counted how often the bots actually slip in a pour, so "mostly" is a reading of the code, not a measurement. Tier 2 (gold) bots kill a spike in 0.45 s, faster than most people can.

**The number.** Count per pour, by tier: slips that happened, wrong slump calls, spike kills slower than 1 s. Print one line per slab.
**To reach 3.** The number is in range at every tier, and on a TV playtest nobody says "the bots are better than us".

## 2. The game makes decisions for the player: 1 Partly

**What the critics said.** Raised in every review: gold assist and the slump reading state the answer (29 Oct); the right call pulses harder even with Gold assist off, and the fade was earned by routine presses (review 4, F1 and F3); the help belonged to the crew character, not the person (F2, and 3 of 3 critics on 13 Nov).

**Fixed so far.** The gold fades per job. Routine presses now earn much less fade than calls (`GOLD_STEP_ROUTINE` 0.003 vs `GOLD_STEP` 0.01, `main.gd:4187-4259`), so a truck hand loses the help by making calls, not by rodding. Help is per person for NEW players (#113, #120). The slump reading becomes a bare number once the help has faded.

**Still open.** The slump call still marks the right answer as urgent, Gold assist on or off: `line.gd:4264-4271` passes `urgent = (right == "use")`, `(right == "water")`, `(right == "reject")`. An urgent cue pulses faster and bigger on the TV and the phone. That's the one answer leak left that I found.

**The number.** Answer leaks: decision prompts (slump call, docket check, test-or-skip, the poker's spot, the dogman's call) where the right option is drawn differently from the wrong ones while Gold assist is off. Today **1**.
**To reach 3.** 0 leaks, and a first-timer on the truck makes the call from the tape on a TV playtest.
**Next PR that moves it.** Pass the same `urgent` to all three slump buttons (review 4, F1). Size S.

## 3. No difficulty curve: 1 Partly

**What the critics said.** Every slab bronze, then every slab the same (29 Oct). The incident ramp only lands on the pump operator; load quality is flat on every floor (review 4, F4 and F12).

**Fixed so far.** Named days with their own weather and grade (`story.gd`). Line faults by floor: 1 on L1-3, 2 on L4-8, 3 on L9-11 (`_trouble_n`, `main.gd:4800`). Medal targets add slack per planned fault (`score.gd:137` `FAULT_T` clamp 30 s, block 40 s).

**Still open.** The truck hand's job is the same on floor 10 as on floor 2: off-spec loads are about 21% on every floor except quiet L1 (`line.gd:1860-1867`). The poker and screeder see no change up the tower. Because the medal slack grows with the faults, the medal may not get harder at all, which is the number below.

**The number.** Medal spread: for an all-bot crew at a fixed tier, pour time ÷ gold target on L1 and on L11 (and the medal each got). Printed today in the autotest's `level N: ... medal ... in T s (silver S, gold G ...)` line. A real curve means the same bots do worse on L11 than on L1.
**Today.** Backwards. Bronze-tier bots average 1.26 × the gold time on L1-3 and 0.96 on L9-11, and their one gold was on L9 (see "Baseline runs" at the bottom). The fault slack added in #119 over-pays for each fault.
**To reach 3.** L11's ratio is at least 10% worse than L1's for the same bots, more than one job feels it, and a playtest crew says the top floors were harder.
**Next PR that moves it.** First, trim `FAULT_T` (try clamp 15 s, block 25 s) and re-run, so the top floors are at least as hard as the bottom. Then off-spec loads rising with the floor (about 10% on L2 to 25% by L10) and named-day load rules (review 4, F12). Size S.

## 4. Idle jobs: 1 Partly

**What the critics said.** The poker and screeder wait at the start of every pour; on climb days the rigger pins alone while three watch (review 4, F5 and F10; 29 Oct; both October reviews).

**Fixed so far.** Smoko run for the screeder, second tag line for the hose hand, slinging, pin bags and the hopper wash-down on climb days. Trades (#175 onward) let a person move between their trade's tasks: Y beside a trade-mate bot takes its task (#180), and when the line goes down the pump bot calls it and waits for a pumpy to say "Mine!" (Y) and climb up to fix it, so the boom op and line hand have the repair to do while the pump's off (stage 5 part 2).

**Still open.** The start-up steps belong to the pump, hose and boom only (`ops.gd` `STEPS`, about line 58). The climb's pin stage is still one person's work.

**The number.** Idle %: for each job, the share of the pour (and separately of a climb day) where that job has no cue, isn't walking to one, and isn't being covered. One line per slab, one figure per job.
**To reach 3.** No job above 25% idle on a pour day, none above 40% on a climb day, and nobody on a playtest asks "what do I do now?".
**Next PR that moves it.** A start-up step each for the poker (start the vibrator) and the screeder (check the levels) (review 4, F10). Size S to M.

## 5. Text too small for a TV: 1 Partly

**What the critics said.** All three 13 Nov critics, both October reviews; the docket was the smallest text on screen (review 4, F7 and F23).

**Fixed so far.** Screen text defaults to 125% (`settings.gd:35`). The docket now goes to the truck hand's phone (`controller_page.gd:161`). The slim HUD (#116).

**Still open.** The game draws on a 1600 × 900 canvas, stretched to the screen. The smallest labels are 13 px (in `hud.gd` and `pause.gd`), which is about 13 × 1.2 × 1.25 = **19.5 px** on a 1080p TV at default settings. Fourteen more labels are 14 or 15 px. World labels (names, station signs) aren't counted yet.

**The number.** Smallest text a player must read, in pixels on a 1080p screen, at default settings: the smallest visible label during a pour, measured in the game rather than read from the code.
**To reach 3.** 24 px or more for anything a player must read, and John can read every word from the couch on the TV.
**Next PR that moves it.** A floor of 18 px base size in `UI.label` for anything that isn't decoration. Size S.

## 6. Colour-only marking: 2 Mostly

**What the critics said.** Jobs told apart only by hat colour (October reviews, 29 Oct). Review 4 marked it fixed.

**Fixed so far.** Job icons on the hats and the HUD hat discs, P tags on people.

**Still open, to check.** The new trade colours (`trades.gd:33`): pumpies orange `ff7a1a`, concreters green `7cd992`. To someone with red-green colour blindness those two can look close. They need the trade's icon or name wherever the colour is used to mark where a trade can work.

**The number.** Count of player-facing marks that rely on colour alone. Audit list, checked by hand and with a colour-blind filter on a screenshot:
- [x] Job on the hat (icon)
- [x] Who is who (P tag)
- [ ] Trade highlight on pour day (orange vs green): needs an icon or word
- [ ] Gold cue vs normal cue: gold also has a ring and pulse? check on the TV
- [ ] Slump spec band on the tape: check
**To reach 3.** Every item ticked, and the colour-blind screenshot still tells every mark apart.

## 7. The empty-hopper spiral: 0 Open

**What the critics said.** An idle truck hand empties the hopper, the line sits, it blocks, and the pump operator gets blamed and climbs the riser for something they didn't do (29 Oct, review 4 F15, the method review).

**Fixed so far.** Cover makes it rarer: a bot steps in for a lost or idle person.

**Still open.** The line still goes off at full speed with no concrete to pump: `idle_t` grows whenever the line is still (`line.gd:1607-1612`), blocks at `SET_TIME` 40 s, and the pump can't stroke an empty hopper. Nothing tells the crew why.

**The number.** Blockages per pour where the hopper was empty and no truck was at the bay as the line went off. All-bot runs, every level.
**To reach 3.** 0 in all-bot runs; when a human crew causes one, the herald names the cause ("No concrete from the trucks: the line's going off").
**Next PR that moves it.** Half-speed `idle_t` while the hopper is empty and no truck is at the bay, plus the herald line (review 4, F15). Size S.

## 8. A dropped phone stays a person: 0 Open

**What the critics said.** When a phone drops off the Wi-Fi, its chibi stays a "human" forever: no cover, the camera frames them, Macca shouts at an empty seat (review 4, F17; open since 12 Nov).

**Still open.** `phones.gd:491` `_release` only zeroes the inputs.

**The number.** Seconds from a phone's socket closing to a bot taking the job (and the same phone getting it back when it rejoins). Today **never**.
**To reach 3.** 15 s or less, a toast says "P3's phone dropped out", and on a playtest turning a phone's Wi-Fi off and on gives the seat back.
**Next PR that moves it.** A 15 s timer in `phones.gd` that hands the job to a bot (review 4, F17). Size S.

---

## How the numbers get printed (design, not built yet)

The plan is one new file, `scripts/scoreboard.gd`, so `main.gd` only gets a couple of lines (one to create it, one to call it when a slab is signed). It watches the game and, at the end of each slab in an autotest, prints one line:

```
[scoreboard] L11 tier=bronze medal=silver ratio=1.07 idle%=pump:8,line:22,hose:5,boom:3,poker:31,screed:28 bot_mistakes=3 starve_blocks=0 min_font_px=19.5 leaks=1
```

| Field | How it's measured |
| --- | --- |
| `ratio`, `medal` | pour clock ÷ gold target, both already in `main.gd`'s level line |
| `idle%` | each frame, per job: no cue in `p.cues`, not walking to a station, not covered, divided by pour time |
| `bot_mistakes` | a counter bumped where `bots.gd` slips, misreads or kills late |
| `starve_blocks` | in `line.gd` `_block`: was the hopper empty with no truck at the bay? (one line in line.gd, or read from outside) |
| `min_font_px` | walk the visible HUD Controls once a second, take the smallest font size × screen scale, as it would be at 1080p |
| `leaks` | at each decision prompt, are the right and wrong options' `urgent`/`gold` flags the same with Gold assist off? |

Rows 6 (colour) and 8 (dropped phone) are checked by hand and by a short scripted test, not printed every run.

`tools/ci/smoke.sh` then copies the `[scoreboard]` lines into `summary.txt`, so they show in the CI summary on every PR. A PR that makes a number worse shows it before John merges.

Building this waits for a free build slot (two build threads are running).

## Baseline runs

All-bot autotest, cloud, headless, main `a3984fe`, 25 Nov. Bots start at bronze tier and step up as they beat it.

One run from L1 up (it hit the 25 min limit during L11) and two runs of L11 alone. Ratio = pour time ÷ gold target; under 1.00 beats the gold time. A medal also needs quality: silver 85%, gold 95% (`score.gd:52-53`), so some slabs inside the time still got bronze.

| Floor | Line faults planned | Pour time | Gold target (fault slack) | Ratio | Quality | Medal |
| --- | --- | --- | --- | --- | --- | --- |
| L1 | 1 | 134.8 s | 121 s (0) | 1.11 | 90 | Silver |
| L2 | 1 | 168.6 s | 121 s (0) | 1.39 | 89 | Bronze |
| L3 | 1 | 155.9 s | 122 s (0) | 1.28 | 86 | Bronze |
| L4 | 2 | 150.9 s | 152 s (30) | 0.99 | 81 | Bronze |
| L5 | 2 | 163.0 s | 153 s (30) | 1.07 | 87 | Silver |
| L6 | 2 | 162.5 s | 153 s (30) | 1.06 | 80 | Bronze |
| L7 | 2 | 164.9 s | 153 s (30) | 1.08 | 92 | Silver |
| L8 | 2 | 169.9 s | 154 s (30) | 1.10 | 92 | Bronze |
| L9 | 3 | 167.5 s | 184 s (60) | 0.91 | 96 | **Gold** |
| L10 | 3 | 204.1 s | 205 s (80) | 1.00 | 81 | Bronze |
| L11 (run a) | 3 | 183.1 s | 195 s (70) | 0.94 | 94 | Silver |
| L11 (run b) | 3 | 195.3 s | 195 s (70) | 1.00 | 81 | Bronze |

**What it says.** The curve runs backwards. On L1-3 the bronze-tier bots average 1.26 × the gold time; on L9-11 they average 0.96, and the only gold of the chapter was L9. The fault slack (30 s a clamp, 40 s a block) is more than a fault really costs these bots, so each extra fault makes the medal easier, not harder. Pour times also swing a lot (L11: 183 s and 195 s; quality 94% and 81%), so one run per floor is noisy: the printed number should be the average of at least two runs. The bots stayed at bronze tier all chapter.

Row 3's number today: **L1-3 ratio 1.26, L9-11 ratio 0.96**, so the top is about 24% easier than the bottom. Target: the top at least 10% harder.

## History

| Date | Total | What changed |
| --- | --- | --- |
| 25 Nov | 8 / 24 | First board. |
