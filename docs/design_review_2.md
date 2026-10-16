# Pour Decisions: critique of the 16 Oct build

Reviewer: couch co-op designer and UX reviewer. I read the README and `docs/design_review.md` (the earlier review), and read the scripts that matter: `main.gd` (player handling, hose, ops wiring, cover, camera, HUD feed, grading), `ops.gd`, `bots.gd`, `phones.gd`, `controller_page.gd`, `score.gd`, `hud.gd`, `sfx.gd`, `pause.gd` and parts of the others. I looked at all 33 fresh screenshots (tower 27, tutorial 4, truck 2, phone 5, plus `split.png`, which landed late) and ran the game headless myself.

Severity: **P0** breaks play, softlocks or can't be read. **P1** hurts fun or clarity a lot. **P2** is polish.

## Evidence base: runs

| Run | Setup | Result per slab (pour clock, medal) | Notes |
| --- | --- | --- | --- |
| A | Tower, all bots, bronze bots, incidents 1 (my run, `critic_run`) | L1 78.9 s **Silver**, L2 83.8 s **Silver**, L3 77.4 s **Gold**. Quality 100 every slab. | First climb: **157 s**. Start-up and washout added about 14 s per pour outside the clock (L1: pour phase 93.5 s vs 78.9 s on the clock). |
| B | `--human=boom --bots=gold` (idle boom operator, covered after 15 s) | L1 89.1 s Bronze, L2 90.2 s Bronze, L3 89.2 s Bronze. Quality 100. | A totally absent boom operator costs about 10 s a pour and **zero quality**. |
| C | `--human=hose --nocover` (idle pipe guy, nobody covers) | L1 99.5 s Bronze, quality 99 (0.2% cold joint) | The pour phase took **170.9 s**, against 99.5 s on the clock. **About 57 s of dead time** was spent waiting on the pipe guy's two radio calls (30 s auto each, −30 pts). No softlock. |
| Screenshot runs (yours) | Tower L1–4, tutorial, truck | Tutorial tank floor: **Gold in 49.2 s with bronze bots**. Truck L1: **Gold** with bronze bots. | Truck L1 bots earned "Good call on the output **+160**" against +30–50 on the tower (see the X exploit below). |

The anti-softlock systems held in every run. Nothing hung.

---

## 1. Verdict

**What's working.** The fantasy is fresh and specific, and the simulation is honest: slab heightfield, pendulum crane, Bézier trucks, whistle code. The co-op chains that exist are good ones:

- Weeping clamp → STOP pumping → pressure off (belt remote) → swap → pin.
- Haul rope parallelism.
- Docket judgement (now a real decision with consequences: big improvement since the last review).
- The pipe guy calling the pump on a person's remote. This last one is exactly the right *shape* of co-op: one person signals, the other acts.

The dragon's-breathing start-up is gorgeous flavour. A lot of the earlier review landed: job icons everywhere, off-screen arrows, the docket card, X high/low, a "Your job" pause page, the ready countdown, text-size settings and no more invisible NPC pokers. The phone controller looks and feels like a real product (`android_press.png`).

**The single biggest risk.** The game still plays itself, and now it *visibly* plays itself better than people do:

- Bronze bots alone take **Silver/Silver/Gold** on L1–3 (run A), Gold on the tutorial and Gold on the truck kit.
- Quality is 100 on every bot slab, so the quality half of the medal never moves.
- An AFK boom operator costs 10 s and nothing else (run B).

The predictable first-night experience: four friends join, they're slower than bots, they get Bronze, and the game tells them they did worse than the robots they replaced. Close behind is **TV readability**. Labels pile up at exactly the spots the new features send people to (the BIN, the truck bay, LADDER/HAUL ROPE), and at levels 1–3 a deck-plus-street crew is framed so wide that chibis are about 15 px tall (`pour.png`, `highlow.png`, `docket.png`).

---

## 2. Findings by area

### 2.1 First-time experience and onboarding

**F1. [P0] The join QR is too small to scan from the couch.**
- **Observed.** `select.gd` makes the QR 84×84 px; the pause menu's (`pause.gd`) is 110×110, on a 1600×900 canvas. On a 55" 1080p TV, 84 px is about 6 cm. Phone cameras scan reliably at about 10× the code's width, so roughly 0.6 m. (The `roles.png` "Join in" card mentions "scan the code", but it isn't drawn in autotest because of `--nophones`, so I'm going from code.)
- **Why it matters.** The phone pitch dies at the first step if everyone has to walk up to the TV.
- **Fix.** Make the QR at least 260 px on the crew screen (about 18 cm), centred in the Join card, with the URL under it in 28 px or more. Keep the pause QR at 200 px or more.

**F2. [P1] The tutorial coach panel is a wall of text, and it's semi-transparent.**
- **Observed.** `tutorial/*.png`: 8–9 lines of 15–16 px text. World labels show through the panel ("jules", "HOIST" in `tutorial/hose.png`).
- **Fix.** One line per job, at 22 px or more, on an opaque panel. Move the general paragraph ("A round slab, pumped from the far side…") into a 3 s intro card. Show only the lines for jobs a *person* holds, and drop each line once that job has done its action once.

**F3. [P1] The second person to join becomes the pipe guy, the role most likely to stall the room.**
- **Observed.** `crew.gd JOIN_ORDER = ["boom", "hose", …]`. The pipe guy owns two blocking radio calls at every start-up (`ops.gd STEPS air/concrete`). Run C: an idle pipe guy cost 57 s before the clock even started.
- **Why it matters.** The newest player is the most likely to miss a cue, and here that blocks five people.
- **Fix.** See F14. Either make the radio calls non-blocking for people too, or make the second joiner the poker. The poker is self-paced and impossible to stall, and you can see the work.

**F4. [P2] The pre-pour briefing card sits in the middle of the screen, over the work.**
- **Observed.** `staff.png` and `inspect.png`: the card covers the crew, the HOIST station and BOOM REMOTE, and on L2 the defect hand sign.
- **Fix.** Slide it in on the left under the tickets, and collapse it after 4 s. (The earlier review flagged this too.)

**F5. [P2] Briefing jargon.** "About 41s to keep an edge wet" is meaningless to a non-concreter. Use "Hot day: concrete goes off in 40 s. Keep pouring against the fresh edge", with the wet-edge colour key.

### 2.2 Core loop and the six jobs

**Boom operator**

**F6. [P1] With a bot pipe guy (solo, and the default for P1), the bot decides where the concrete lands.**
- **Observed.** `discharge()` returns the pipe guy's hands. `bots.gd _hose` walks to `_hose_spot()`, the lowest good spot within 2 m of the tip. The boom operator's gold is `good_pour_spot(discharge())` (`main.gd _handle_player`, boom branch).
- **Why it matters.**
  - The person steering is overridden by up to 2 m without being told. "I aimed there, it landed over there."
  - Their gold button is nearly always gold, because the bot pipe guy only stands on good spots. So gold teaches nothing.
- **Fix.**
  - When the boom operator is a person and the pipe guy is a bot, have the bot pipe guy *follow* the tip (stay under it, only nudge into corners the boom can't reach: the outer 0.6 m that `out_k` blocks).
  - Compute the boom operator's gold from the tip, not the hose hands.

**F7. [P1] The X high/low button can be farmed for points.**
- **Observed.** `main.gd _handle_player`: every X press flips `line.speed_high` and awards +10 "Good call on the output" if the new state matches `speed_advice`. `_speed_advice()` returns "want high" whenever the pump is on LOW and the hopper is above 60%, and returns nothing once it's HIGH. So tapping X, X, X… earns +10 every second press for as long as the hopper is full. The truck-kit bots logged **+160 and +140** for this row (truck `log.txt`), against +30–50 on the tower.
- **Fix.** Pay once per advice episode, with a 10 s cooldown, and only if the advice had been showing for at least 0.5 s. Charge −10 for switching *against* level-1+ advice.

**F8. [P2] The boom operator's body is on rails.**
- **Observed.** `_walk_boom_op` auto-walks them round the walkway.
- **Why it matters.** It's correct and stops footprint trouble. But a person on the boom only ever moves a crosshair, and on TV they lose track of which chibi is them.
- **Fix.** Give the boom operator's chibi a ground ring in their player colour, and draw a thin dashed "line of sight" from the remote to the hose end while pumping.

**Pipe guy (new)**

**F9. [P1] Two people are both "hold A to pump" for the same concrete.**
- **Observed.** `_hose_work` sets `hose_call` from A held. `_update_pour` lets the call drive a bot boom's trigger. A person on the boom also holds A to pump, and their cue just goes gold while the pipe guy calls.
- **Why it matters.** With two people this is good: a signal and a response. But the boom operator's own judgement and the pipe guy's are redundant, and nobody is told who's in charge. Real crews have a clear rule: the hoseman calls, the operator pumps.
- **Fix.** When a person holds the hose, the boom operator's A becomes "pump on the call". Add a short "on the call" streak bonus for starting within 0.5 s of the call and stopping within 0.5 s of "Stop!". Give the pipe guy a *second* call on Y: "boom left/right/up" as a hand signal. That makes the hose a real two-person instrument, not one person steering while the other presses.

**F10. [P1] Footprints charge the pipe guy for walking where the job forces them.**
- **Observed.** In `_footprints`, the exempt list is `["boom", "rigger", "dogman"]`. "hose" is missing. The pipe guy is clamped to within 2 m of the tip (`_hose_work`), so a moving boom drags them across whatever is there, including screeded finish: −3 per 0.4 m stride, and it spoils the finish.
- **Fix.** Exempt `busy == "hose"` and show prints without the penalty. Or penalise only voluntary steps, not leash drags.

**F11. [P2] A bot boom pumps without the pipe guy after 6 s quiet.**
- **Observed.** `HOSE_QUIET`. A pipe guy who lets go on purpose to walk to the next spot (walk speed ×0.55) gets concrete arriving mid-walk.
- **Fix.** Pause the quiet timer while the pipe guy is moving the stick.

**Poker**

**F12. [P2] Plunge-creep, the red shake and "let go" all read well on paper.**
- **Observed.** `poker.png`: the purple patch only shows next to the holder, and the "Needs a poke first!" balloon is partly hidden behind a white quad (it reads "Ne___ds a poke first!").
- **Fix.** Check that balloon's render priority against the boom stream mesh, and give speech balloons `no_depth_test`.

**Screeder**

**F13. [P2] Gold is overloaded across jobs.** The screeder's "ready to screed" overlay is also *gold*; see F27.

**Pump operator and line hand.** These jobs are in good shape since the docket change. The `remote.png` and `ladder.png` flow (Y pressure off from anywhere → "Pressure's off!" → swap) reads well in the close-up.

**Climb day**

**F14a. [P1] Two people sit out every climb.**
- **Observed.** Run A's first climb took **157 s**. On a climb the screeder and pipe guy are "a breather" (README table), and the poker only works during `guide`. In `pin.png`, `sling.png` and `align.png`, robbo and nev stand on the deck doing nothing for the whole climb.
- **Why it matters.** At four players, one or two people sit out 2.5 min three times a chapter.
- **Fix.**
  - Pipe guy: on climb days, hook up and unhook the new boom section's hose, and swing the end hose clear for the dogman.
  - Screeder: runs R-clips/pins up the hoist, or cleans and oils the pin holes (a short A-hold per lug before the rigger can podger).
  - Or switch the idle people to "spotter" with a Y call that the dogman's crane honours.

### 2.3 Co-op dynamics

**F14. [P1] The start-up radio calls are chores, not co-op.**
- **Observed.** `ops.radio`: press A when told, from anywhere, no skill. A person who misses it blocks everyone for up to 30 s (`AUTO_T`), or about 19 s with cover (15 s cover + 4 s `RADIO_AUTO_T`). Run C: 57 s of dead time per pour.
- **Fix.** Give the radio a *read*. "The dragon's breathing" only counts once the hose actually puffs (it does: `steam`), and "concrete's on" only when the stream turns from slurry-tan to grey (it does: `stream_color`). Early is −5, on the colour change is +15. And for people, auto-complete after 6 s (not 30), with the same small penalty. The call becomes a 1-second reaction test with a payoff, and it can never hold the room.

**F15. [P1] Bots still never need a person; people only need bots.**
- **Observed.** Run B. The pump bot runs parts unasked (`bots._help_parts`). Covering (15 s) means an AFK player is invisible in the result.
- **Fix.** Give the people something only they can do, which the bots *wait on* with a visible timer:
  - The docket call for a person-held pump job (already true).
  - The pipe guy's call for a person on the boom.
  - Pressure off for a person line hand: the bot pump op should *wait for a Y request* from the line hand ("Pressure off!", a Y cue for the line hand) rather than reacting to the joint opening.

**F16. [P2] Who's being covered isn't visible.** It's a 3 s toast. Put a "covered by crew" chip on that person's ticket and name tag, and on their phone (see F35).

### 2.4 Start-up and washout

**F17. [P0] The BIN, the key target of both sequences, can't be read.**
- **Observed.** `tower/startup.png`, `tower/washout.png`, `tutorial/startup.png`, `tutorial/washout.png`:
  - The labels "nev", "jules", "BIN", "SLURRY INTO THE BIN" / "WASHOUT INTO THE BIN" and the hand sign all overprint each other in one spot.
  - The bin itself is hidden under the two chibis standing on it: the boom operator's walkway spot and the pipe guy both converge there.
  - The tower framings are your harness camera (`_shot_cam` 12 m from the bin), but the label stack is independent of camera.
- **Fix.**
  - Drop the station label "BIN" while the ops sign is up (the sign already says it).
  - Move the bin 1.5 m along the walkway away from BOOM REMOTE.
  - Park the bot boom operator 2 m off the bin during bin steps.
  - Lay world labels out with a simple screen-space de-overlap pass (sort by priority, nudge up by label height). That one pass also fixes F23.

**F18. [P2] The step count says "of 6", the README says 5.**
- **Observed.** `ops.gd PRIME_ORDER` includes `slurry_go`, a wait with no person (the "Start-up 2 of 6" ticket in `slump.png`).
- **Fix.** Number only the steps a person does ("1 of 5"), and show `slurry_go` as a progress bar on step 4.

**F19. [P2] The washout overlaps finishing, which is good, but the top bar says both at once and the clock collides.**
- **Observed.** `washout.png`: "screed 4% and washout to go" runs into the "1:16" clock.
- **Fix.** Give the clock a fixed column, and ellipsize or wrap the task text.

**Pacing.** At about 14 s with bots, the start-up is fine. Keep it, but make it skippable for the radio steps (F14). The washout's "miss the bin and it lands on the finished slab" is a nice consequence. Make it visible: a grey splat on the screeded surface in the report.

### 2.5 HUD and TV readability at 2.5 m

**F20. [P0 at L1–3, P1 after] The camera is too wide whenever people are both on the deck and on the street.**
- **Observed.** `_update_camera`: below `SPLIT_Y` (9 m, levels 1–3), `main_follow = up + down` and `dist = spread * 1.6 + 10`. The deck centre to the truck bay is about 20 m, so the camera sits at about 40 m and chibis are about 12–15 px tall, as in `pour.png`, `highlow.png` and `docket.png` (all-bot default framing). The X high/low cue that `highlow.png` was taken to show **can't be seen** at that scale. `trans2.png` shows the same for the street band (Tash about 20 px, labels illegible).
- **Fix.**
  - Split on *distance between groups* (more than about 12 m), not on deck height.
  - Tighten the street band camera to the street person's 8 m radius, and raise `BAND_FRAC` to 0.4 for hands-on work.
  - Floor chibi on-screen height at about 60 px (1080p) by capping `dist`.

**F21. [P1] The default text size is too small for a TV.**
- **Observed.** HUD labels are mostly 14–18 px on the 1600×900 canvas (counted in `hud.gd`/`pause.gd`/`coach.gd`: 47 labels at 12–18 px). That's about 17–22 px at 1080p. The "Screen text" default is 100%.
- **Fix.**
  - Default Screen text to 125%.
  - Test 150%. At 150%, the left tickets (about 420 px), the task bar (about 400) and the score/pump panels (about 330) sum past 1600 px and will collide, so let the tickets drop under the score column, or cap ticket width.

**F22. [P1] The slab report overflows its card.**
- **Observed.** `grade.png`: "Start-up and washout +95" and "Slump tests" render below the card border. `hud.show_report` adds up to 8 rows and `show_medal` then inserts the medal row, but the anchored `PanelContainer` doesn't regrow.
- **Fix.**
  - Call `card.reset_size()` (and re-place it) after `show_medal`.
  - Or cap rows at 5, plus a "+N more" row.
  - Right-align the points column: +600 and +430 currently sit at different x.

**F23. [P1] World labels collide everywhere the action is.** All of these are the same de-overlap pass as F17:
- LADDER/HAUL ROPE in every street shot.
- "tash" over "5.8 m³ left" over the pressure-off cue (`remote.png`).
- "Good load" over "7.8 m³ left" (`trucks.png`, `split.png`).
- "CLANG!" over "R-clip on" (`align.png`, `pin.png`).
- "POKER" station over "nev"/"gus" (`hose.png`, `poker.png`, `tutorial/hose.png`).

Also: truck labels ("44 min", "2.4 m³ left", "SETTLING TANK") are about 8 px. Show those only for the truck at the bay, or when the pump op is within 6 m.

**F24. [P1] The station spots drawn on top leak into the close-ups and cover the people in them.**
- **Observed.** `_make_station` sets `no_depth_test = true` on the ring (render layer 1). Close-up cameras use `cull_mask = 1`, so the rings render in every PiP. The orange TRUCK BAY disc fills a third of the slump-test close-up (`slump.png`, `docket.png`, `screed.png`), and a red LADDER disc sits in the clamp close-up (`ladder.png`, `remote.png`). In the main view they paint over chibis' legs (`slump.png`, tash), and a pale ring floats through trees (`staff.png`, `inspect.png`, bottom left).
- **Fix.**
  - Put rings on their own layer (for example 3) and leave it out of close-up cameras.
  - Draw them with the depth test on, and only draw an x-ray copy at 25% alpha when they're occluded.

**F25. [P2] Things said twice.**
- The start-up/washout step appears as both the left ticket and the top-bar subtitle (`startup.png`, `washout.png`), which contradicts "nothing is said twice".
- There's one "Truck queued · N min old" ticket per truck: three of the four tickets in `truck/pour.png`.
- **Fix.** Drop the subtitle when a ticket carries the same text. Fold queued trucks into the pump panel, and raise a ticket only after 75 min.

**F26. [P2] "HOPPER 99% · LOW" reads as "the hopper is low".**
- **Observed.** `startup.png` and `slump.png` show it in red at 0–4%. There, "LOW" (the pump output) sits beside a red hopper % and reads as one warning.
- **Fix.** Label it "OUTPUT LOW", on its own row, in the boom colour.

**F27. [P1] Gold means six things.**
- **Observed.**
  - Boom job colour `#ffc72c`.
  - Y glyph `#ffc23d`.
  - Gold-assist state `#ffd23f`.
  - The gold medal.
  - The "+N" pops.
  - The screeder's ready-to-screed overlay.

  `ui.gd ROLE["boom"]` and `GLYPH["Y"]` are within a few RGB points of the assist gold. On the phone, a gold Y (the pump op's "pressure off", which is a gold moment per the README) is visually unchanged (`android_gold_and_hold.png`). For the boom operator, *everything* is already gold.
- **Why it matters.** Gold assist is the headline new teaching tool, and it's least visible exactly where it's used most.
- **Fix.**
  - Make the assist state a *shape and motion*, not a hue: a white-gold double ring plus sparkle, and the glyph scaling 1.15×.
  - Or move the boom job to a different hue: the hose is already cyan, so try a warm red-orange, and move the pump to brown or amber.
  - Change the screed-ready overlay to a pattern (dots).

**F28. [P2] Off-screen arrows collide with the close-ups.**
- **Observed.** `split.png`: the line hand's edge arrow and its "C7 C…" label sit on the PiP's top edge, clipped at the screen edge.
- **Fix.** Treat the PiP rectangles as screen edges for the arrow clamp.

**F29. [P2] The "Esc pause" hint is keyboard-only.** Show it only when someone is on keys, otherwise "Start: pause" (or nothing).

### 2.6 Menus, pause and options

**F30. [P1] Phones can't pause.**
- **Observed.** `pause.gd` toggles only on Esc or `JOY_BUTTON_START`. The phone page has no menu button.
- **Why it matters.** A phones-only party (laptop by the TV) can't pause, read "Your job", change Gold assist or restart without walking to the laptop.
- **Fix.** Add a small ≡ button on the phone (top left, long-press 0.5 s so it isn't hit by accident). It sends "menu" to `toggle()`, and the stick and A/B navigate the menu.

**F31. [P2] The pause "Your job" page is excellent.**
- **Observed.** `pause.png`: all six jobs, with icons and both pour and climb.
- **Fix.** Open it on the pressing player's *own* job, larger, with the other five collapsed. Add "Docket help" next to Gold assist under an "Assists" heading. Rename "Incidents: Normal" to "What goes wrong: Normal".

**F32. [P2] Kit select is good now.** The two playable kits are big and the later chapters small (`select.png`). The "Stage 7" subtitle is unexplained.

### 2.7 Phone controller

**F33. [P1] The stick can stick at a stale value.**
- **Observed.** `controller_page.gd sendStick(false)` throttles to 33 ms with no trailing send. If the thumb's last movement lands inside the throttle window and then holds still, the game keeps the previous vector until the next move.
- **Why it matters.** The new boom steering curve is meant for fine creeping; this makes it overshoot or creep on.
- **Fix.** On a throttled skip, `setTimeout(() => sendStick(true), 34 - elapsed)`. Or send from `requestAnimationFrame` whenever the value changed.

**F34. [P1] Crewmates cover phone players who are actively holding a button.**
- **Observed.** In `main.gd _cover`, `idle_in` only resets via `raw_active()`, which returns false for `ai` players (phones), or via a WebSocket message (`phones.gd _on_message`). A held A, or a stick held still at an angle, sends nothing.
- **Why it matters.** After 15 s, with the job's urgency at 1 or more, the bot takes over mid-hold. The next phone message then calls `uncover()`, which clears `ai_action`, so a still-held A is dropped.
- **Fix.**
  - Treat `p.ai_action or p.ai_alt or p.ai_slow or p.ai_move != Vector2.ZERO` as active for phone players in `_cover`.
  - In `uncover()`, keep the phone's latched button state.

**F35. [P1] The phone's empty middle is wasted.**
- **Observed.** `android_connected.png`: about 40% of the screen is black.
- **Fix.** Put the **one thing you need** there:
  - Your top ticket in your job colour ("Read the docket", "C3 weeping · get a clamp kit").
  - The docket card itself for the pump op. Private info on the phone makes the pump op *call it out*, which is great co-op.
  - "Covered by the crew: tap to take back".
  - Remove "you are player 1" (the P1 badge says it).

**F36. [P2] The phone joins the game before "Tap to join".**
- **Observed.** `connect()` runs on page load, so just opening the URL takes a chibi and job (`join_phone`). The gate only hides itself.
- **Fix.** Connect on the gate tap.

**F37. [P2] The screen sleeps, and the iOS home-screen icon breaks if the IP changes.**
- **Observed.**
  - The phone screen will dim and lock during climbs and the report. The Wake Lock API needs a secure context, and `http://192.168…` isn't one.
  - An iOS home-screen web app is bound to the IP and port. A laptop on DHCP gets a new address next week and the icon opens a dead page.
- **Fix.**
  - Use the silent-looping-`<video playsinline muted>` (NoSleep) trick after the gate tap.
  - Print the address big on the TV, and have the page show "Game not found at 192.168.x.x. Scan the new code on the TV".

**F38. [P2] A disconnected phone stays a "person" forever.**
- **Observed.** `phones._release` zeroes the inputs, but the chibi is still counted in `humans()`. The camera keeps framing them (F20) and they get covered after 15 s.
- **Fix.** After 10 s disconnected, hand the job back to a bot and show "P3 dropped out" on the TV. Reconnecting with the token reclaims it.

**F39. [P2] Layout nits.**
- **Observed.** `android_gold_and_hold.png`: the Y verb pill sits on A's hold ring.
- **Fix.** Put verb pills above Y/B (they're at the top) and below X/A.

**F40. [P2] iOS has no haptics.**
- **Observed.** `navigator.vibrate` doesn't exist on iOS.
- **Fix.** Make visual feedback carry it, for example a 1-frame screen-edge flash in the job colour on "clamp shut" or "hammer hit" events that currently only buzz.

**Latency.** Godot polls the WebSocket every frame and tap latching is handled (`MIN_TAP_MS`), so I expect 30–80 ms on home Wi-Fi, which is fine for this game. The risk is 2.4 GHz congestion with 4 phones plus streaming. Add a tiny ping dot (green, amber, red) on the phone, and on the TV's crew strip, so people blame the Wi-Fi, not the game.

### 2.8 Difficulty, scoring, medals, progression

**F41. [P1] The medal targets are beaten by the bots alone.**
- **Observed.**
  - Tower: silver 86 s, gold 78 s (`score.gd`). Bronze bots: 78.9/83.8/77.4 s → Silver/Silver/**Gold** (run A).
  - Tutorial: gold 62 s, bots 49.2 s.
  - Truck L1: Gold.
  - With any human slower than a bot (run B: +10 s), the crew gets Bronze.
- **Why it matters.** The medal punishes having friends play.
- **Fix.**
  - Set targets so *bronze bots alone* land mid-Bronze: tower silver at about 72 s, gold at about 64 s (tune by run).
  - Add the people's contribution: a "crew bonus" time credit per person-performed key action (docket right, clamp swapped, gold hammer blows), so skilled people beat bots.
  - Or medal on *points*, not clock.

**F42. [P1] Quality is always 100 for bots, so it never differentiates.**
- **Observed.** Runs A and B. Only run C's absent pipe guy dented it (99%).
- **Fix.** Make some quality sources *inevitable without good human calls*: a bad load arriving in every pour at Normal (a bot accepts it at bronze tier 30% of the time), and wind or heat days that cost the bots a little. Make bots fallible at bronze.

**F43. [P1] The difficulty curve is flat at the default setting.**
- **Observed.** At Incidents Normal, `_plan_incidents` gives exactly one clamp per pour on every level. Points per level in run A are 2,265/2,205/2,349.
- **Fix.** Author the chapter. The Incidents setting should scale an authored curve, not replace it (L2 first clamp, L3 first stiff load, L5 hot day, L6 first blockage, and so on, as in the earlier review).

**F44. [P2] Per-person stats include the bot's work while you were covered.**
- **Observed.** `score.award` credits `by_person` whenever `who.bot` is false, and a covered human isn't `bot`.
- **Fix.** Skip `by_person` while `who.covering`.

**F45. [P2] "Finished early" pays 2 pts/s under 132 s.** That's about 100 pts a pour and dwarfs judgement calls (a good docket call is +15). Shrink it, or make it scale with the medal.

### 2.9 Bots and the anti-stall systems

**What's right.** Nothing softlocked in any run. Idle boom and idle pipe guy both resolved, and the README's watchdog list matches the code (`ops.update AUTO_T`, `FINISH_STALL/FINISH_MAX`, `COVER_AFTER`).

**F46. [P1] Cover is invisible in the result and silent in the room.**
- **Observed.** Run B: an AFK boom operator still gets quality 100 and their name on the points.
- **Fix.**
  - A covered person's role shows "covered" on the slab report (no shame, just honesty), and doesn't earn medals' worth of points.
  - Shorten cover to 10 s for *blocking* steps, and lengthen it to 25 s for non-blocking jobs (poker/screed), so the game doesn't take people's jobs away while they're watching to learn.

**F47. [P2] The ops nag toast uses job names in caps** ("PIPE GUY: the dragon's breathing?"). Use the person's name: "Nev (P2): radio it, the dragon's breathing!". People respond to their name, not their job.

### 2.10 Audio and feel (from `sfx.gd`)

**F48. [P1] The pump's heartbeat is inaudible on TV speakers.**
- **Observed.** The stroke is a 46 Hz sine (`sfx.gd _process`, `pumping`). The clamp rattle has a 31 Hz component. Most TV and laptop speakers roll off below 80–120 Hz, so the defining sound of the pour is silent, and the weeping-clamp warning is only the noise half.
- **Fix.** Add a 2nd and 3rd harmonic (92 and 138 Hz) plus a short 1–2 kHz "chuff" transient on each stroke. Pitch the rattle up to 200–600 Hz clicks.

**F49. [P2] One "tink" for 21 different events, and no music.**
- **Fix.**
  - Give each job one signature earcon (pump: air-brake chuff; line: clamp clunk; poker: rising drone; boom: radio squelch; hose: radio squelch plus the two-tone "concrete's on"; screed: scrape).
  - Add the truck reversing beeper. It's iconic, and you already model reversing.
  - Add a low radio/ute music bed that ducks during alarms.

**F50. [P2] Per-sample synthesis in GDScript with string matching may crackle.**
- **Observed.** A `match kind` runs per event per sample at 22 kHz.
- **Why it matters.** On a mid laptop with 4 WebSocket clients, a frame hitch starves the 0.12 s buffer.
- **Fix.** Precompute the one-shot hits into `AudioStreamWAV`s at start-up and play them from a small pool. Keep only the continuous drones synthesised.

### 2.11 Realism versus fun

- The start-up and washout are authentic and charming ("the dragon's breathing" is the best line in the game). Keep the words, cut the waiting (F14).
- The boom operator never on the pad is correct, but it reduces the job to a crosshair. Compensate with the hose dialogue (F9).
- Footprints in the finish are real and a funny, visible consequence. Just don't charge the jobs that *must* stand in it (F10).
- The idle climb roles are realistic (concreters do stand around), but in a party game, standing around reads as "my job is boring". Give them real side work (F14a).

### 2.12 Bugs and likely bugs (code citations)

| # | Sev | Where | What goes wrong |
| --- | --- | --- | --- |
| B1 | P1 | `main.gd _handle_player` (boom, `alt_pressed`) + `_speed_advice` | X toggling farms +10 "Good call on the output" (F7). |
| B2 | P1 | `controller_page.gd sendStick` | No trailing send, so a stale stick vector (F33). |
| B3 | P1 | `main.gd _cover` / `player.gd raw_active` / `phones.gd _on_message` | Phone players covered mid-hold; `uncover()` drops a held A (F34). |
| B4 | P1 | `hud.gd show_report` / `show_medal` | Report rows overflow the card (`grade.png`). |
| B5 | P1 | `main.gd _make_station` + `_update_camera` (`cam.cull_mask = 1`) | Always-on-top rings render inside close-ups (`slump.png`, `ladder.png`). |
| B6 | P1 | `main.gd _footprints` | Missing "hose" exemption (F10). |
| B7 | P1 | `pause.gd _input` | No way to pause from a phone (F30). |
| B8 | P2 | `controller_page.gd` (`connect()` at load) | Joins before "Tap to join" (F36). |
| B9 | P2 | `hud.gd:449` (`set_pump`) | "next in 0s" / "next in 1s" shows when no more trucks are coming (`washout.png`, `tutorial/washout.png`). Should read "last load in" or hide. |
| B10 | P2 | `ops.gd ticket()` | "of 6" counts the no-person `slurry_go` wait (F18). |
| B11 | P2 | `score.gd award` | `by_person` credits covered players (F44). |
| B12 | P2 | `main.gd _hose_work` | Leash enforcement teleports the pipe guy (`p.position` clamp) with no drag animation or feedback. Add a stumble and a "hose tugged" bark. |
| B13 | P2 | `main.gd _handle_player` → `ops.radio` | During both radio steps (including the 2.4 s "waiting on the air…"), `radio()` returns true and the handler returns early, so the pipe guy can't take the end hose or do anything else until the call is made. Only claim A, not the whole frame. |
| B14 | P2 | `phones._release` | A dropped phone stays in `humans()`: camera framing, cover (F38). |
| B15 | P2 | `poker.png` | Speech balloon partly occluded by a white quad (F12). |
| B16 | P2 | engine log | Repeated "Can't change the size of a SubViewport with a SubViewportContainer parent that has stretch enabled" while the split opens (screenshot run log). The band SubViewport is resized with `stretch` on, so set `stretch = false` or stop setting `size`. Harmless now, but it spams the log and the resize is being ignored. |

---

## 3. Top 10 prioritised actions

1. **[P0] Fix world-label overlap with one screen-space de-overlap pass.** Cut the BIN station label during ops steps, and move the bin off the boom operator's spot (F17, F23).
2. **[P0] Fix the camera at L1–3: split on distance, not height.** Tighten the street band, and set a minimum chibi size (F20).
3. **[P0] Make the join QR 260 px or more, and the URL 28 px or more** (F1).
4. **[P1] Retune medals so bronze bots alone land in Bronze.** Add a person bonus. Make bot quality fallible (F41, F42).
5. **[P1] Make start-up radio calls non-blocking for people** (6 s auto), and turn them into a timing read on the puff and the colour change (F14, F3).
6. **[P1] Fix the phone input bugs:** the trailing stick send, cover detection for held phone buttons, and a phone pause button (F33, F34, F30).
7. **[P1] Separate "gold assist" from gold-coloured things.** Use a shape and motion treatment, and recolour the boom job (F27).
8. **[P1] Define the boom and pipe-guy contract:** the bot pipe guy follows a person's tip, the boom operator's gold comes from the tip, and add "on the call" bonuses and pipe-guy Y signals (F6, F9).
9. **[P1] Fix the scoring and penalty bugs:** the X-toggle farm, the footprint exemption for the hose, report overflow, and rings in close-ups (B1, B4, B5, B6).
10. **[P1] Give the screeder and pipe guy real work on climb days,** and make the pump heartbeat audible on TV speakers (F14a, F48).

---

## 4. Questions for John

1. **Slurry at start-up:** does SCP actually pump the slurry into a skip or bin on the deck, discharge it on the ground, or spread it thin in the slab where the engineer allows? And who calls "concrete's on" on your crew: the hoseman, the operator or the leading hand?
2. **"The dragon's breathing":** is that a real SCP call, or a crew in-joke? (Either way, keep it. I'd just like to know whether to bill it as authentic.)
3. **The hoseman and the operator:** what are the actual hand signals the hoseman gives the operator (pump on, stop, boom left/right, up/down, slow)? Those would make perfect Y/X calls for the pipe guy.
4. **The washout:** in the water washout, who opens the release valve, and is there a real risk moment (blow-back, a pressure spike) that the crew watches for? A small "stand clear" beat would be great.
5. **Two trucks on the hopper:** does SCP really run a twin feed, and how often? On site, who decides to add water: the pump operator, the concreter, or only with the builder's OK?
6. **Climb days:** what do the concreters and the hoseman actually do while the boom climbs? (Clean up, strip the end hose, prep the next pour?) That's your answer for the idle roles.
7. **Testing:** who will you test with first, crew mates or non-construction friends? The fixes above lean toward non-construction friends. If it's the crew, the realism budget can go up.
8. **Hardware:** is the TV build going to run on a laptop on the same Wi-Fi as the phones, and is that Wi-Fi 2.4 or 5 GHz? Is there a fixed IP for it (it affects the iPhone home-screen icon)?
