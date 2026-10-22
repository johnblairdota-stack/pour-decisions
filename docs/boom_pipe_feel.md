# Cursor prompt: Boom operator + Pipe guy feel rebuild (Pour Decisions)

Paste everything below the line into Cursor (Agent mode, Opus 5.5). Open the folder first (see "Setup").

## Setup (do this before pasting)

Use a git clone, not your play folder, so the work becomes a branch and a PR:

```
cd C:\Users\John\Documents
git clone https://github.com/johnblairdota-stack/pour-decisions.git pour-decisions-git
cd pour-decisions-git
git checkout -b boom-pipe-feel
```

Open `pour-decisions-git` in Cursor. Your PourDecisions play folder stays untouched until you've tested it. When you're happy, back it up under a new name (for example `PourDecisions_backup_22oct`) and copy the build over.

Design board for reference (the pictures the spec below describes): https://claude.ai/artifact/RQouG3jKWgbazTwSy9Fwmg

---

You are working in **Pour Decisions**, a Godot 4.7 GDScript couch co-op game about a concrete pour on a real Brisbane tower (Riverlight, Hamilton). Six crew jobs; bots fill any job nobody's playing; phones join as controllers. Role keys in code: `boom` (Boom operator), `hose` (Pipe guy), `line` (Truck hand), `pump` (Pump operator), `poker`, `screed`.

Your task: rebuild how the **Boom operator** and **Pipe guy** roles feel, so they're true to real concrete boom pumping and also fun and punchy. Build it as one branch, in small commits (one per numbered part below), then open a PR to `main`.

## Ground rules

- Match the surrounding code: tabs, `##` doc comments above functions, short plain-English comments in the code's own voice (it talks about "the crew", "the deck", "the end hose"). Constants go in `UPPER_CASE` blocks next to the code that uses them, each with a `#` comment that gives its unit.
- Keep role keys `"boom"` and `"hose"`. Don't rename anything that other files reference.
- Don't touch climb days: on climb days the boom player is the **dogman** (`climb.gd`), and that already works. Only change the pour.
- Everything must still work for: bots on every job (all-bot autotest), the tutorial water tower (round slab, `tutorial` flag, `TUT_R`), the truck boom kit (`--kit=truck`, outriggers), wind parking (`BOOM_WIND`, 72 km/h), the start-up and washout bin steps (`ops.gd`: `ops.wants_bin()`, `ops.over_bin()`, `ops.pump()`), split-screen and phones.
- Bots should play the new mechanics competently but not perfectly. Never make a bot depend on a human doing something.
- Colours and meanings follow the existing "Site Kit": gold `ffd23f` = now / sweet spot, alarm red `ff3b2f` = danger only, done green `4fb36b`. Job colours mark whose prompt it is: boom `ffc72c`, pipe guy `2fd3e8`. Button colours A `3fe0c5`, B `ff5a5f`, X `9b6bff`, Y `ffc23d`. Use the existing `p.cue(...)`, `p.gold(...)`, `p.bark(...)`, `p.say(...)`, `hud.toast(...)`, `score.award(...)` and `score.trickle(...)` helpers, plus `sfx.hit(...)` sounds (the sounds are made in code in `sfx.gd`; add new synth sounds there if needed).
- Player input helpers (`scripts/player.gd`): `move_input()` = stick, `action_*` = A, `leave_pressed()` = B, `alt_*` = X, `slow_*` = Y. Bots drive the same helpers through `ai_move`, `ai_action`, `ai_alt`, `ai_slow`, `ai_leave` (set in `scripts/bots.gd`).

## Where the code is today (main branch, commit cd19570)

`scripts/main.gd` (about 5,000 lines):
- Boom state: `tip_target`, `tip_pos`, `tip_kick` (~line 182); arms `arm1/arm2`, `l1/l2`, `head`, `yaw_node`; `_build_boom()` ~1332 builds the two-section boom for each kit.
- Each frame (~2765): rests the boom when not pouring, `tip_pos = tip_pos.lerp(tip_target, delta*4)`, then `_update_whip()`, `_update_boom()` (2-bone IK from `head` to the tip, ~4275), `_update_stream()`.
- Who pumps (~2950): `pipe_calls()` (~3919) is true when anyone's on the end hose. The pipe guy's held A (`hose_call`) switches the pump; the boom's A only pumps for the bin steps, with nobody on the hose, or when a person on the hose has gone quiet for `HOSE_QUIET` (6 s). The whip flings lumps here: `if q > 0.0 and _whip > 0.2`.
- Boom operator input (`_handle_player`, `if p.busy == "boom":` ~3328): the stick moves `tip_target` across the slab, mapped to the screen by `_pad_dir()` (~3832). It has a dead zone (`BOOM_DEAD`), speeds up when held hard (`BOOM_RUSH_*`), can only lead the hose by `BOOM_LEAD` and is clamped to the slab (plus the bin). The operator is auto-walked by `_walk_boom_op()` (~3554). X toggles high/low output using `speed_advice` from `_speed_advice()` (~3219). Gold comes from `pour.good_pour_spot()`.
- Whip (~3815-3870): `BOOM_SPEED`, `BOOM_POUR_K`, `WHIP_FROM`, `WHIP_FULL`, `_update_whip()`. Only a person on the boom can whip; it swings the pipe guy like a pendulum.
- Pipe guy (~3870-3970): `HOSE_REACH` 2 m leash from `hose_anchor()` (the deck right under the boom tip), `take_hose()`, `drop_hose()`, `discharge()`, `_hose_work()` (hold A = pump on, the barks "Pump it!"/"Stop!", gold on `good_pour_spot`), `_draw_hose()`. If the pipe guy walks past the leash, the anchor clamps them, so the boom drags them about.
- Dead code you can use: `call_boom(at)` (~3311) and `call_marker` ("▼ BOOM HERE"), with `call_t`. Nothing calls `call_boom()` today. `bots.gd` already makes the boom bot go to `call_marker` when it's visible.

`scripts/bots.gd`: boom bot ~320-410 (`_boom_goal`, `pour.next_face_point`, `_boom_ok`, steering through `ai_move` rotated by `cam_yaw`); pipe guy bot `_hose()` ~432-495 and `_hose_spot()` (walks to the lowest wanted spot within reach of the anchor and holds A when it's worth it).

`scripts/pour.gd`: the slab heightfield. `height_at(local)`, `deposit(local, q)`, `SLAB` (slab depth), `good_pour_spot()`, `leading_strip()`, `cur_bay`, `bay_of_x()`, `skip_near()`, `round_r`, `bw/bd`, `vol_k`, `mark_bleed()`.

`scripts/ops.gd`: start-up (air, slurry into the bin, "concrete's on" radio call by the pipe guy: `radio()`, `SIGNAL_AIR`, `SIGNAL_CONC`, `ON_THE_DOT`) and washout. `ops.primed` = concrete is flowing for real.

`scripts/line.gd`: the pump and line. `line.run(delta, want)` returns m³ out this frame; `line.pumping`, `line.speed_high`, `line.hopper`, `HOPPER_CAP`, `fail_i`, `wear`, `blocked`, `line_down()`, `tripped`. Constants block at the top of the file.

`scripts/climb.gd`: `_gesture(p, call_name, dir, slow)` (~2281) already poses chibi arms for dogman hand signals. Reuse its approach for the pipe guy's signals.

Text the players read:
- `scripts/ui.gd`: `ROLE_TEXT` (~112), `JOB_CARD` (~125: goal, watch, steps; the phone ticket and pause menu highlight the live step by matching words in the cue verbs, so keep the step keywords in sync with your new cue verbs), `ROLE_HOW` (~160).
- `scripts/crew.gd` ~22-31: job descriptions on the crew screen.
- `scripts/coach.gd` ~124-195: the tutorial and coach hints for boom and hose.
- `scripts/controller_page.gd`: the phone page (HTML/JS in a GDScript string; no backslashes in that string). The ticket shows JOB_CARD steps. Only change it if a new gauge needs to show on the phone (see part 9). Otherwise, JOB_CARD changes flow through by themselves.

## The design (what to build)

Why it feels off today: the pipe guy (even a bot) switches the pump, so the boom's A sits idle all pour. The boom stick moves a dot on the floor (no swing, no reach, no weight). The only skill test is a penalty (swing hard and the hose whips). The operator is walked for you. Nobody talks to the boom: `call_boom` is never used. The pipe guy holds A the whole pour and gets dragged by the boom.

Real-world facts this is based on (keep them true):
- The operator's radio remote ("belly box") has a proportional lever per motion: **slew** (swing the boom round its tower) and each **boom section** (raise/unfold, lower/fold). It also has pump on/off, output, reverse ("suck back"), horn and e-stop.
- Every pump stroke pushes a slug of concrete up the line, so the boom bounces and the end hose bucks in rhythm.
- Real **hose whip** happens mostly at **start-up/restart** (air in the line, starting the pump fast, a low hopper sucking air) and when the hose is **stretched** to reach (the end hose should hang close to vertical). Nobody goes near the end hose at start-up until the operator says it's safe.
- The hose hand guides the hose and talks to the operator with standard hand signals: boom left/right, up/down, extend/retract (out/in), stop boom, start pump/more, slow, stop pump, "little bit", all done. Unclear signals aren't answered.
- The hose hand keeps the end hose about 0.6-0.9 m above the deck, lays concrete in even lifts, walks forwards, and doesn't get between the hose and a column.

### Boom operator

**1. Belly Box controls (the stick drives the machine, not a dot).**
- Replace the free x/z cursor with **polar control round the boom's mast** (`head`'s position on the ground). Stick left/right = **slew** (angular speed round the mast); stick up/down = **reach** (radius out/in), both mapped so "left" swings the way that reads as left on screen. Use `cam_yaw` like `_pad_dir()` does, so it still feels screen-relative: work out the tangential and radial directions at the tip, then project the screen-right and screen-up vectors onto them.
- Give it **weight**: keep a slew rate and a reach rate that ease toward the stick's target rate (spool up over ~0.35 s). When you let go hard (the stick snaps from big to near zero within ~0.1 s at speed), it **overshoots and sways**: a damped spring on the tip, about 0.3-0.6 m past and back, over ~1 s. If the player **eases off** (the stick falls through mid values over ≥0.25 s) as it arrives, it stops dead: award gold **"FEATHERED"** (+10, with a cooldown so it can't be farmed: only after a move of ≥2 m and at least 3 s apart). Show the sway with `tip_kick` or a separate offset.
- Keep the existing limits: clamp the radius to what `l1 + l2` can reach, keep the tip over the slab (or the bin when `ops.wants_bin()`), handle the tutorial's round slab, the truck kit, and wind parking. Keep `BOOM_POUR_K` (slower while pumping).
- **Remove the speed-wind-up whip** (`BOOM_RUSH_*`, `WHIP_FROM`, `WHIP_FULL`, the speed-based part of `_update_whip()`). Keep the pendulum animation code for parts 4 and 13. A rough stop now causes sway, not flung lumps.
- **A = horn** during the pour (when not over the bin): a short two-tone honk (`sfx`). For ~2.5 s after a honk, the crew is "braced": a big swing (≥90° slew or a ≥6 m move) after a honk gives +5 "Warned the deck"; a big swing without one makes the pipe guy and poker bark ("Oi! Horn!"). Keep A pumping over the bin for slurry and washout exactly as now.
- **Faint reach rings** on the deck: two or three dashed arcs round the mast at the current radius ±, visible only to the boom operator's view while they hold the remote (one MeshInstance3D line or a thin torus slice; keep it cheap).
- **Let the operator walk.** Remove the auto-walk in `_walk_boom_op()` for people (keep it for bots and covering players). While holding the remote, the player walks slowly (~0.55x, like `HOSE_WALK_K`) with the remote on its strap. The stick drives the boom, so: **hold B to walk** (stick moves the player, boom holds still), tap B (under 0.25 s) to put the remote down as now. Standing under the boom tip (within ~2 m of `hose_anchor()`) shows a red "out from under the boom" cue.

**2. Signal & Answer (the dance with the pipe guy).** Build the shared "signal" system once, in main.gd:
- `var boom_signal := ""` (one of `LEFT`, `RIGHT`, `OUT`, `IN`, `UP`, `DOWN`, `LITTLE_BIT`, `STOP_BOOM`, `ALL_DONE`), `boom_signal_t` (time since it was given), and `boom_signal_dir` (world direction for LEFT/RIGHT/OUT/IN).
- The pipe guy gives signals (part 11 says how). Show the signal as a **big paper speech card over the pipe guy** (reuse the bark/balloon style in `player.gd` `bark()` / `_update_balloons()`, or a Label3D with a dark pill) with a small pictogram or arrow and the words (BOOM LEFT, LITTLE BIT, STOP BOOM...). Pose the pipe guy's arms like `climb._gesture()`. On the boom operator, show a cue whose verb names the signal ("BOOM LEFT", "STOP BOOM") with a progress bar draining over the **answer window** (~1.5 s), urgent/gold in its last half.
- **Answering.** LEFT/RIGHT: slew that way (rate in the right direction above a threshold) within the window. OUT/IN: reach that way. UP/DOWN: this game has no boom height, so map UP/DOWN to the end hose height in part 12, or leave them out. LITTLE_BIT: a short nudge (stick above the dead zone for 0.08-0.4 s, then released) toward the pipe guy. STOP_BOOM: the tip speed falls under ~0.2 m/s within the window. ALL_DONE: nothing to do; it's a cheer moment.
- **Rewards.** A right answer in time gives +6 and builds an **"IN SYNC ×n"** streak shown on the operator's cue (gold pulse plus star sparks via `p.gold()`). Each right answer adds +1, so the streak becomes worth chasing. A wrong direction or a timeout breaks the streak, and the pipe guy barks ("Other left!", "Oi! Boom!"). Never give a negative score for a missed signal, just the broken streak.
- **Bot boom operator:** answers signals after a reaction delay of 0.3-0.9 s (use the existing bot tier, `score.bot_tier`, if handy) and steers toward the pipe guy as now. Remember the boom bot already chases `call_marker`. Make `call_boom()` the way a signal sets that marker, or replace it, but keep the bot working.

**3. Feel kit for the boom (all four).**
- **Kit 1, Unfold & stow:** at the start of the pour (after the briefing, before or while the start-up begins), the boom starts **folded** (arms tucked, tip near the mast top). The operator unfolds it with the stick up in two clunks (arm 1 swings out, then arm 2), about 1.5 s each with a heavy clank sound and a little bounce. Bots do it on their own. At washout end, the boom folds back the same way (stick down) and the crew gives a small cheer. Keep it short: never block the pour for more than ~4 s, and auto-complete it after 8 s if a person ignores it. Skip this in the tutorial if it gets in the way of the tutorial's own steps.
- **Kit 2, Stroke thump:** while `line.pumping`, run a stroke clock (about 16-22 strokes a minute on HIGH, 10-14 on LOW, matching `line.speed_high`). On each stroke: a low "whump" (`sfx`), a little downward tip bounce (`tip_kick`), a small hose shake, and a 15 ms buzz on the boom operator's and pipe guy's phones (look at how `phones.gd` / `controller_page.gd` already send buzz patterns, and add a "thump" event if one doesn't exist). Keep it subtle: the deck breathes with the pump.
- **Kit 3, Start-up kick (the real whip):** the first ~3 s after the concrete reaches the hose (the `ops` "concrete" stage / when `ops.primed` turns true), the end hose kicks. If the output is on LOW, the kick is a short shiver. If it's on HIGH, it's a proper whip: reuse the old pendulum on whoever's holding the hose, and fling a few lumps (`pour.deposit` off to the side, as the old whip did). Restarts after a stop longer than ~20 s, or after a line repair, do a smaller kick. The bot boom operator always starts on LOW. Show the boom operator a cue at start-up: "start on LOW" (X).
- **Kit 5, Suck back (Y):** Y on the boom remote "reverses a stroke". It's only allowed when the pump is not pumping. Tap Y right before a move of ≥2 m: no drip trail, +5 "Clean move" (cooldown 4 s). Moving ≥2 m within 2 s of the pump stopping, **without** a suck back, leaves a thin **drip trail** of small deposits along the path over fresh deck (tiny `pour.deposit` amounts every ~0.4 m, which the screeder and poker then have to deal with). Bots suck back about 70% of the time. Small, but it's a real button with a visible payoff.
- **X high/low** stays as it is (`speed_advice`), with the start-up hint from kit 3.

### Pipe guy

**4. Keep It Hanging (the pipe guy's half of signal & answer).** Replace "the boom drags you" with a lean gauge:
- Measure the **lean**: the horizontal distance from the pipe guy's hands (or `discharge()`) to `hose_anchor()`, divided by `HOSE_REACH`. Under ~0.6 = **hanging true** (green, walk freely). 0.6-1.0 = **leaning**. While leaning, a **signal charge** fills over ~0.5 s in that direction; when full, it fires `LEFT/RIGHT/OUT/IN` (whichever polar direction round the mast best matches the pull), and the charge resets. Show the charge as a small arc or bar on the pipe guy's cue.
- Past 1.0 (pulling against the leash) = **STRETCHED**: the pipe guy can't go further (clamp as now, but don't drag them when the boom moves; instead, if the boom moves away and the pipe guy doesn't follow, the lean grows). While stretched, the flow is choked (output ×0.4) and the hose starts to buck (the pendulum at low strength). After ~1.5 s stretched while pumping, a stronger kick and "STRETCHED!" in red alarm. That's the real cause of hose whip, and it replaces the old speed-based whip.
- **Y on the end hose:** tap (<0.25 s) = **LITTLE BIT** (in the direction the pipe guy is facing or pushing); hold (≥0.4 s) = **STOP BOOM**. When the bay is full (`pour` says the current bay is done), the pipe guy crosses their arms automatically: **ALL DONE**.
- **The pipe guy still owns the pump call (hold A)**, as since PR #11. Keep `pipe_calls()`, `HOSE_QUIET` and the barks. Gold when the boom answers your signal in time: both players get the In Sync moment (+3 for the pipe guy).
- **Bot pipe guy:** today it walks toward `_hose_spot(anchor)`. Make it walk toward the wanted spot even when that's beyond the leash, so it leans and its signals fire naturally (with a person on the boom, that's the whole point). It uses LITTLE_BIT when the gap is under ~1 m, and STOP_BOOM when the boom is swinging past a good spot. It must never stay STRETCHED for long: if the boom doesn't answer within ~3 s, it walks back toward the anchor and pours where it is.

**5. Lay the Lift (the pipe guy's craft).**
- Draw a **ring on the deck round the landing point** (`discharge()` projected to the slab) while the pipe guy is pumping. It's a timing meter: a white fill that rises with the concrete height under the hose (`pour.height_at`) toward a **gold band at slab level** (`pour.SLAB`, about 0.9-1.1x). Above 1.3x `SLAB` it turns orange: **HEAPING**.
- Leaving a spot (moving ≥0.6 m) while it's in the gold band gives a small +4 "Nice lift" (a gold pop, cooldown ~1.5 s). Every five nice lifts in a row gives a bigger "LIFTS ×5" +10. Leaving a heap (>1.3x `SLAB`) makes the screeder bark "Oi! Heap!" (cooldown 8 s) and breaks the run. Keep the existing "Concrete placed" trickle.
- Show the run count on the pipe guy's cue ("LIFTS ×7"). The old "move on before it piles up" watch line becomes the ring.

**6. Feel kit for the pipe guy (kit 1 and 4).**
- **Stand clear (kit 1):** from the moment `ops` reaches the slurry/concrete step until the start-up kick (part 3, kit 3) is over, the pipe guy should stand **outside a ring ~2.5 m round `hose_anchor()`**. Show the ring (dashed gold) and a cue: "stand clear till the thumbs up". After the kick, the boom operator presses A to give the **thumbs up** (the boom bot does it automatically after ~0.5 s). Then the pipe guy takes the hose. Grabbing the hose before the thumbs up while it's kicking = thrown off (pendulum, drop the hose, a comic bark), no score loss. Grabbing it within 1.5 s of the thumbs up = +5 "Safe start". This must not break the existing "concrete's on" radio call in `ops.gd`: the radio call still comes first, then the kick, then the thumbs up. The bot pipe guy waits correctly.
- **Hose height (kit 4):** if the boom tip is too low over the deck (the hose would touch, for example over a fresh heap where `pour.height_at` under the tip plus the hose length is above the tip height), the end hose scrapes (sound) and the pipe guy's `UP` signal fires automatically. The boom answers with stick **up** (reach out lifts the tip a little, or add a small tip height offset the operator raises with up). If that clashes with the reach control in part 1, skip UP/DOWN entirely and drop this kit item. Say so in the PR.

### Text, tickets and hints

**7.** Update `ui.gd` `JOB_CARD`, `ROLE_TEXT` and `ROLE_HOW`, `crew.gd` descriptions and `coach.gd` hints for both jobs. Keep every step's keyword list matching the new cue verbs so the phone ticket highlights the live step. Suggested tickets:
- Boom: goal "Swing the boom, answer the pipe guy." Steps: [stick] "Swing round the tower, up/down reach. Ease off to stop clean" (keywords: swing, reach, feather), [stick] "Answer the pipe guy's signals" (boom left, boom right, out, in, little bit, stop boom), [A] "Horn before a big swing · thumbs up at start-up" (horn, thumbs), [Y] "Suck back before you move" (suck back), [X] "Start on LOW, then high or low output" (high, low, output). Watch: "the pipe guy's hands."
- Pipe guy: goal "Lay it level and lead the boom." Steps: [A] "Grab the end hose (after the thumbs up)" (end hose, take, stand clear), [stick] "Lean toward where it's wanted to signal the boom" (lean, signal, stretched), [A] "Hold for concrete, leave each spot in the gold" (pump on, pumping, lift, heap), [Y] "Tap LITTLE BIT, hold STOP BOOM" (little bit, stop boom). Watch: "the ring under the hose."

**8.** Keep the TV cues big and short (they're read on a TV from the couch): verbs like "BOOM LEFT", "FEATHERED", "IN SYNC ×4", "NICE LIFT", "HEAPING", "STRETCHED!", "STAND CLEAR", "HORN". UPPERCASE gold only in the gold moment, red only for danger.

**9 (optional).** If it's cheap, show the signal card and the lift gauge on the phone ticket too (the way the pump operator's ticket shows its live gauge in `controller_page.gd`). If it isn't cheap, skip it and say so in the PR.

## Testing

1. Syntax: `pip install gdtoolkit`, then `gdparse scripts/*.gd`. (Godot 4.7 syntax; gdparse catches most parse errors but not all.)
2. Headless all-bot run (you need Godot 4.7 on the PATH; on John's PC it's the Godot editor exe he uses):
   - `godot --headless --path . --import`
   - `godot --headless --path . --fixed-fps 60 -- --autotest --nophones`
   - `godot --headless --path . --fixed-fps 60 -- --autotest --nophones --tutorial`
   - `godot --headless --path . --fixed-fps 60 -- --autotest --nophones --kit=truck`
   - With people on the jobs (idle "people", nobody covering), so the line copes: `-- --autotest --nophones --human=boom --nocover` and `--human=hose --nocover`.
   The autotest prints `[autotest]` lines and ends with "TOPPED OUT with N points". A full 11-level run takes a long time. Add `--startlevel=3` (or similar; check `main.gd` for the flag list) to test one level when iterating. The all-bot level time should stay roughly where it is (140-190 s a level since PR #12). The all-bot slab quality and score shouldn't drop much. Report before/after numbers in the PR.
3. Play it windowed with a gamepad or keyboard (P1 number keys swap jobs: 1 boom, 6 pipe guy) and check: unfold, slew/reach feel and FEATHERED, sway on a rough stop, horn, signals and answers both ways, suck back vs drip trail, the start-up stand clear → kick → thumbs up → grab sequence, nice lifts and heaps, stretched hose, washout into the bin and the fold-away.

## Acceptance checklist

- [ ] The boom stick slews and reaches round the mast, screen-relative, with weight, sway and FEATHERED stops; no speed-whip.
- [ ] The boom operator walks themselves (hold B), tap B puts the remote down; bots are still auto-walked.
- [ ] A: horn in the pour, pump into the bin in the bin steps, thumbs up at start-up.
- [ ] The pipe guy's lean fires signals; Y gives LITTLE BIT / STOP BOOM; ALL DONE on a full bay; STRETCHED chokes the flow and bucks the hose.
- [ ] The boom gets a readable answer cue with a window; In Sync streak, barks on a miss, no negative score.
- [ ] The lift ring, nice lifts, heaps.
- [ ] Unfold & stow, stroke thump (+ phone buzz), start-up kick (LOW vs HIGH), suck back vs drip trail.
- [ ] Stand clear → kick → thumbs up → grab, with the radio call intact.
- [ ] Bots do all of it sensibly; all-bot, tutorial, truck-kit and `--human` runs top out.
- [ ] JOB_CARD / ROLE_HOW / crew / coach text updated and step keywords match the cues.
- [ ] Climb days (dogman) untouched.

## PR

Open a PR from `boom-pipe-feel` to `main` titled "Boom operator and pipe guy: real levers, hand signals, lifts". In the body, list what each part does, anything skipped (and why), the before/after autotest numbers, and what to try first when playing. Don't merge it yourself.
