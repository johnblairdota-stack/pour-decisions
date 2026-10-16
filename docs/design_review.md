# Pour Decisions: design review

Reviewer brief: a fresh look by someone who has shipped couch co-op. I read the README and smoko doc, read the scripts, looked at all the screenshots, ran a full all-bot chapter headless (tower kit), and took fresh captures with `--cam=poker,screed --botcues`.

**What the run showed:** 11 pours of 58–76 s each and three climbs of 103–135 s. The full chapter is about 19.5 minutes (70,337 frames). The bots scored **quality 100 on every slab** and **1,934–2,013 points on every level**. Level 1 and level 11 scored within 4% of each other. Every pour had exactly one weeping clamp.

---

## Overall verdict

**What's great.** The subject is genuinely fresh, and the simulation under it is better than it needs to be:

- The slab is a heightfield that slumps, seeps, goes off and cold-joints (`pour.gd: step/_pair/defects`).
- The crane is a pendulum on a laggy operator (`climb.gd: _operate`, `OP_DELAY`).
- The trucks reverse on real Bézier paths.
- The whistle code is synthesised.

The world-first readability is the right philosophy for couch play: hand signs over the work, the cue glyph by the head, close-up PiPs framed in the job's colour. The one-button "A does the job" rule is a sound accessibility baseline. The climb day (dogman, tag line, rigger with podger and hammer) is the best set-piece: it's physical, legible and authentic.

**Biggest risk.** As built, it is a **beautiful simulation of a well-run pour, not a game about a pour going wrong**. Four things combine:

1. **The bots are perfect.** Quality is 100 every time (`main.gd: _grade`), so a human taking a job can only match or lose to the bot they replaced.
2. **The decisions are pre-made.** "A always does the right call" on loads (`line.gd: _bay`, the comment on line 1918). The pump picks its own speed (`main.gd: _update_pour`, line 1489). Poker and screed "don't undo each other".
3. **Every pour runs one scripted crisis.** It's a single clamp failure at 20–55% fill (`clamp_trigger`, `start_failure`).
4. **There's no difficulty curve.** Points are flat across 11 levels, and the level config only rolls dice for weather (`_level_cfg`).

The result is low tension, low skill expression and long stretches where 2–3 of the 5 jobs have nothing to do. Overcooked works because **the kitchen fights back and your mates are the bottleneck**. Here the site is polite, and the bottleneck is a timer you can't see failing.

The second risk is **TV readability**. The HUD text sits at 12–15 px on a 1600×900 canvas, which is about 14–18 px at 1080p. World labels are smaller still, and on a 40" TV at 2.5 m none of it reads. A party game lives or dies on that.

The good news is that the fixes are mostly tuning and exposing decisions the simulation already models. There's no need to rebuild.

---

## 1. Front end: crew select, job select, site and kit, joining, pause

**What works**
- The crew card (portrait, name, one-liner, job with up/down, climb-day role underneath) is clear. The strip of all five jobs along the bottom answers "who's a bot?" at a glance (`select.gd: _rebuild_slots`).
- The hard hat is always in the job's colour. That's a good invariant.
- The "Join in" card with Enter / pad A / QR is right. A late phone join takes "the most useful job a bot is doing" (`main.gd: join_phone`), which is a nice touch.
- The pause menu is clean and has the essentials (`pause.png`).

**Problems**
- **It auto-advances the moment everyone present is ready** (`_process_crew`, `if all: go_site()`). If P1 readies before P2's phone has loaded the page, P2 misses the crew screen. That's the classic party-game join race.
- **Job cycling skips taken jobs** (`crew.gd: cycle`), so two friends can't both hover "Boom" and negotiate. The first to press wins silently.
- **On the site page every player's stick drives one shared cursor** (`_process_site` sums `move_input()`). Two people pushing opposite ways jitter it.
- **Half the kit grid is padding.** "Line pump" and "Mast boom" are both "later chapter", so there's really one real choice and one variant. Showing two disabled cards in a 2×2 at equal weight wastes the screen and invites a "can't pick that" toast.
- **"Job" is overloaded.** It means a role ("Pick your crew: … your job"), a site ("THE JOB & THE KIT") and a task ("live jobs" list). For a new player these three collide.
- **The phone page says "you are player 2"** (`phone_controller.png`) and nothing else. It doesn't show your character, job colour or job icon.
- **The pause menu is built for a keyboard player.** The controls list leads with "Keyboard P1 WASD… Keyboard P2 arrows…". There's no per-job "how to" reminder, which is what a confused couch player actually needs mid-game.

**Recommendations**
1. Replace auto-advance with **"all ready → 3-second countdown, any new join or B cancels"**. Show "Waiting for phones…" while a phone page is open but not yet joined.
2. Let jobs be hovered by more than one person, and resolve on ready: "Boom taken by P1, pick another". Or allow a shared job for poker (it already supports two helpers).
3. On the site page, only P1 (or whoever pressed last) drives the cursor. Show their colour on the highlight.
4. Show the two playable kits large, and the "later chapter" kits as small locked thumbnails underneath.
5. Rename by purpose: **Crew** (who), **Role** or **Job** (what you do; pick one word and use it everywhere), **Site** (where), and **Call-outs** or **Tasks** (the left list).
6. The phone page should show the **character name, the job icon and name on a job-coloured background**, and the job's 1-line "your A does…" text. Tint the A button in the job colour.
7. Add a **"Your job"** tab in pause: a 3-panel picture card per role showing what A, X and Y do on a pour and on a climb day. Put it first, ahead of the key bindings.

---

## 2. HUD

**What works**
- The layout zones are sensible: task top-centre, score top-right, live list left, PiP bottom-right, call-outs centre.
- The pump panel showing only during pours and the wind panel only on climbs (`hud.gd: set_pump/set_wind`) is the right instinct.
- Close-ups framed in the job colour with the cue badge in the corner (`cue_badge.gd`) are excellent. That's the single best HUD idea here, especially for the hammer timing.
- The split screen (deck on top, street band below, ladder markers on the seam) is a clever answer to a real problem.

**Problems (specific)**
- **Size.** These are at a 1600×900 canvas with `canvas_items` stretch:

  | Element | Size | Code |
  | --- | --- | --- |
  | Live-list rows | 15 px | `hud.gd:213` |
  | Rank label | 12 px | `hud.gd:140` |
  | Pump panel | 12–13 px | `hud.gd:157–165` |
  | "Esc pause" | 14 px | `hud.gd:264` |
  | Station labels and name tags | ~8–12 px on screen (`pour.png`: "robbo", "POKER", "SCREED") | — |

  A 10-ft UI wants roughly 24 px or more at 1080p for anything you must read, which is about 20 px or more on this canvas.
- **Colour carries the job, and the palette fails colourblind players.** Boom is yellow `#ffc72c` and pump is orange `#ff7a1a`. Line is green `#7cd992` and the urgent ticket border is red. Under deuteranopia/protanopia, yellow/orange/green collapse together. Screeder white against concrete-grey, and poker lilac against the purple "raw" overlay, are both low-contrast. Ticket icons are task letters (E, T, H, C, V, P, R, W, !, ?), not job letters. So the only job cue on a ticket is the colour of its disc: "E" means wet Edge in boom yellow, "T" means Truck in pump orange.
- **The hand signs aren't job-coloured** (`signs.gd:159`: always ORANGE, then RED). The README says "Bots run for their red signs", but a person can't tell from the sign whose red sign it is.
- **Several things are duplicated.**
  - "Slump test the truck" (ticket) is also the "SLUMP TEST" hand sign plus "Check the docket" world text plus the PiP plus the cue by the head (`signs.png`).
  - "C4 weeping · 9 m up" (ticket) is also the PiP title "C4 WEEPING · 9 m up", the "! C4" world label and the hand sign.
  - The slab report says quality three times: "quality 100%" in the header, "Slab quality bonus (100%)" and "Engineer's happy." (`grade.png`).
- **Things are missing when needed.**
  - The **wet-edge** bar is the most important pour timer, but it's a 3-px line on a ticket labelled "Wet edge", with no location. On the deck, nothing shows *where* the edge is about to go cold.
  - The **weeping clamp's time-to-burst** is only the ticket bar. The boom operator, who must stop pumping, gets a red "STOP pumping!" cue (good), but isn't told *how long* until it bursts if they don't.
  - **Why the pump panel's numbers matter** isn't readable: "LINE 73 bar" in muted grey. Nobody on a couch knows whether 73 is good.
- **Clutter and collision.** World text overlaps: "Good load" on "?? m³ left", and "tash" on "7.6 m³ left" (`trucks.png`). "CLANG! CLANG! R-clip on" stacks on itself (`align.png`). Two A cues read "screed / hold" on top of each other (`critic_shots/poker.png`). The station rings for LADDER, PIPES, SPARES/CLAMPS and HAUL ROPE pile into one corner. "CLAMPS" and "SPARES" both label the same bin.
- **Broken promises.** The README says there's "No instruction text in the game", but the rigger says "stick up to line up the holes" and the dogman banner says "Push the stick toward the green ghost (1.9 m to go)". (I think the text is *good*; just own it.) The jack screenshot (`jack.png`) shows the old HUD with a full-width keys bar, so refresh `haul.png`, `jack.png` and `topout.png`.
- **The split screen's street band is too far out.** In `split_two_players.png` the pump operator is about 25 px tall and the TRUCK BAY and PUMP PANEL labels are unreadable. The band takes 34% of the height (`BAND_FRAC`), but its camera frames the whole street. The `depress.png` capture shows the line hand at 15 m pinned under the pump panel in the top-right corner. Their "Drop the pressure!" bark runs off-screen, and the C6 close-up is half blocked by a yellow walkway beam.
- **The main camera is too wide for deck work.** With only the poker and screeder as "humans" (`critic_shots/screed.png`), the camera still frames the whole tower top. The chibis are about 40 px and the purple/gold overlays they depend on barely show.

**Recommendations:** see the dedicated **HUD optimisation** section below.

---

## 3. Boom operator

**What works:** steering the hose with a lagging IK boom feels right, and the concrete visibly heaps and slumps under the hose. The red shaking "STOP pumping!" cue during a clamp failure is a strong cross-role moment (`main.gd: _handle_player`, lines 1665–1669). The bay overlay and out-of-sequence penalty teach the real "far end first" pour plan. Walking the operator beside the hose (`_walk_boom_op`) is authentic and cute.

**Problems**
- **There's no decision left.** The pump picks high or low itself (line 1489), and the bot boom just aims at `pour.lowest_point(cur_bay)`. The human's job reduces to "hold A, push toward the low spot". The X high/low button in the README no longer does anything on the boom (there's no X branch in the boom handler). So the controls table is stale.
- **There's nothing to read on the wet edge, and nothing to juggle.** Real boom work is a constant trade-off: lay a thin layer across the whole bay to keep the edge alive, or build to full depth locally. Pokers shout for the hose, and the hopper level dictates pace. Only the first is lightly modelled.
- **There's no failure state with spectacle.** Over-pouring spills over the form (`FORM_H`), but it's quietly scored. A hose whip only happens if the hopper runs dry, which the pump bot rarely allows.

**Recommendations**
- Give the boom operator **pace control back on the triggers or X**. High output places faster and raises line pressure (and clamp wear: `wear` already scales with `speed_high`, line 708). Low is gentle. That links boom and line hand directly: "ease off, C4's weeping" becomes a call the boom chooses.
- Draw the **wet edge on the slab**: a pulsing cold-blue band along any poured edge whose `edge_left` is under 40%, turning to a dashed "cold joint" line when it fails. Show the boom operator a small arrow to the coldest edge.
- Make the poker's Y "boom over here" a **real request**: a coloured beacon in the poker's colour with a 6-second ring. Bonus points if the boom gets there before it expires. It's already half-built (`call_boom`, `call_marker`).
- Add a **"spill" moment**: concrete over the form edge drops to the street in a satisfying splat, costs points and makes the screeder's job harder. It's funny and teaches the limit.

---

## 4. Pump operator

**What works:** the twin-slot truck feed, reversing paths, the stop-dead rule when someone's behind a reversing truck, the docket age, and testing the next truck while the first discharges are all well observed. The slump-cone animation (rodding, lift, sag proportional to slump, `_show_slump`) is lovely, and so is the "Pressure's off!" handshake with the line hand.

**Problems**
- **The water/reject decision is fake.** The game computes the verdict, and A is always right (comment at `line.gd:1918`). The README calls this a feature ("pressing A is never the wrong call"), but it erases this role's only judgement call. The real dilemma is: the hopper's at 15%, the only truck here is 88 minutes old, and the next is 6 minutes out. Use it, or risk the hose whip and the cold joint?
- **There's a lot of waiting.** Per truck, the operator waves in (tap), slump tests (1.4 s hold), then accepts or waters (tap). With 8 m³ trucks at 1.8 m³/s discharge and a 5 m³ hopper, the role spends most of the pour standing at the bay. "Truck queued · 34 min old" tickets for every queued truck inflate the list without asking for action.
- **Priming and stroking are invisible.** "Priming the line with slurry" is a toast, and "STROKE THE PUMP" only appears when the line's idle, which with a bot boom is rare.
- **On climb days the job is "(on the ground)"**: nothing to do for 100–135 s.

**Recommendations**
- **Expose the verdict as information, not instruction.** After the slump test, show a docket card over the truck: age (with a 90-minute bar), measured slump against the spec band, and the water allowance left. Then: **A accept, X add water (only if allowance remains), B reject**. Keep an *Assist* toggle that highlights the "right" answer for kids and first-timers. Score by outcome, not by button: a bad load used becomes a weak patch on the slab that the engineer finds, visible in the report.
- **Make rejection cost something real.** The plant takes 25–40 s to send a replacement (`top_up` already reorders). The hopper might run dry, so the pump op has to ask the boom to drop to low output. That's a two-person conversation.
- Collapse queued-truck tickets into the pump panel ("next: 2 trucks, 34 / 51 min"). Raise a ticket only when a truck **crosses 75 minutes**.
- **Give the pump op work on climb days**: rigging the slings on the next tower section at ground level (hook, shackle, tag line on: three A prompts with a timing check) before the crane takes it. That's real dogman-on-the-ground work, and it puts the pump op into the climb loop.
- Make the **hopper level physical**: a big readable hopper with a coloured fill visible from the deck camera, and a klaxon at 20%. The boom op should be able to see it without reading 13-px text.

---

## 5. Line hand

**What works:** this is the most authentic and cooperative loop in the game.

- Weep, then stop pumping, then pressure off (pump op), then open, clean, fit, close, pin. That's a genuine multi-role procedure.
- The haul rope, which lets a ground player send parts while the line hand climbs, is exactly the kind of parallelism co-op games want.
- The magnetic ladder stops (`_ladder`) remove fiddly alignment.
- The tap test for blockages (ring vs thud) is a great audio puzzle.
- The red, shaking cue when you try to open under pressure, with the grout spit, teaches safety by consequence.

**Problems**
- **There's one incident per pour.** `clamp_used` and a single `clamp_trigger` mean the line hand's whole pour is one 15–25 s repair, then nothing. For a human, that's the worst-paced job in the game.
- **The burst timer is short and invisible to others.** At `WEAR_TIME` 18 s on high, if the boom doesn't stop in time it bursts. Fine, but only the ticket bar shows it.
- Blockages only happen under `--blocktest`, or from a still line going off (rare with bots). The tap test is the best puzzle in the game, and most players will never see it.
- The step text "Swap clamp C4 · clean groove" is good, but appears in three places (see HUD).

**Recommendations**
- Turn incidents into a **director**: one guaranteed incident per bay from level 3 or so, drawn from weeping clamp, blockage (from a stiff or old load being used: this links to the pump decision), a **loose riser bracket** (a new, short task), and a **hose end change**. Scale frequency by level and by how many humans are playing.
- Let wear depend on **real causes**: high output, stiff loads accepted and pins left out. The line hand's failures then become everyone's story.
- **Let the line hand do something between incidents**: a "walk the line" patrol that spots a clamp *before* it weeps (tap A on clamps for a pre-emptive check and bonus), or sending empty clamp kits down.
- Show the **weeping clamp on the boom operator's screen space**: a small "C4 ⚠ 12 s" chip attached to the boom op's cue, so the person who must react sees the countdown.

---

## 6. Poker hand

**What works:**

- The plunge loop has great feel: shudder, rising bubbles, drone pitch rising (`sfx.rumble_pitch`), phone haptics every 0.3 s, and a chime when it's done.
- Over-vibration gives bleed water and −10. That's a real skill, and the hold-just-long-enough tension works.
- The drive-unit tow is a nice spatial constraint.
- "VIBRATE HERE" signs only appear over patches close to going off, which is the right volume of help.

**Problems**
- **The raw overlay is purple on grey concrete under a lilac-hatted player.** At normal camera distance it's barely visible (`critic_shots/screed.png`, `poker.png`). With the overlay hidden for bots, spectators see nothing.
- **Two crew NPCs also poke** (`_update_npcs`: one helper if the poker is a bot, two if it's a human). With a human poker, two invisible helpers do much of the work, so the human's contribution is diluted and they can't feel ownership.
- **The tag line is a hold-A-and-stand role on climb days.** It's passive.

**Recommendations**
- Use a **pattern, not just a hue**, for raw concrete: animated diagonal hatching or "wet sheen" sparkles, which work for colourblind players and read at distance. Show it to everyone, not just the holder. It's world information.
- Scale NPC helpers to **zero with a human poker and 4 players**, one with 2–3 players, and two in solo. Give the human a combo meter ("3 clean plunges in a row ×1.5"), which is real skill expression.
- **Tag line:** make it active. The load's spin target shows as a ghost outline, and the tagger pulls (stick) against the spin. Hold too hard near the boom head and the rope burns (drop). It's already modelled (`tag_strength`, `twist`).

---

## 7. Screeder

**What works:**

- Walking backwards and sawing is a real technique, faithfully animated.
- The surplus roll is visible and spills off the ends when overloaded (`MAX_CARRY`). That's lovely, readable physics.
- Stepping out over the form for the edge (`_finish_to_edge`) solves a real fiddly-edges problem elegantly.
- The gold overlay as "ready to screed" works in principle.

**Problems**
- **The poker and screed can happen in either order.** That removes the most natural co-op chain in the game (poker leads, screeder follows). It's realistic for nobody, and it means the two deck players never need to coordinate.
- **Steering is unclear.** The stick is "walk direction", and the board faces opposite. On a camera that orbits, a backwards-walking player is confusing for the first minute.
- **Downtime.** Nothing is ready to screed for the first ~20% of every pour. On climb days the screeder does nothing; the defect fix only happens on some levels and is a 1.2 s hold.

**Recommendations**
- **Restore a soft order:** screeding unvibrated concrete is allowed but leaves a "skin over honeycomb" defect, which the engineer's core-sample flag reveals in the report. Pokers following the screeder over finished work leave footprints. That creates a conga-line dance that's real and funny.
- Show a **ghost board** on the ground ahead of the screeder when idle, aligned with where it will go. Add a small "pull ↓" arrow toward the player while working.
- **Give the screeder the edges and levels**: a straightedge check (hold A, a bubble level reads high or low spots), and fixing high spots by pulling surplus *to* them. The current surplus mechanic already supports a "fill the low spot" skill.
- **Climb day:** make the screeder the **hoist and materials runner**, bringing up R-clips and pins (or the next section's bolts) in the hoist cage. It's real labouring work and gives them a reason to be on the deck.

---

## 8. Climb days

**What works:** this is the standout.

- **Dogging:** the crane driver's 0.35 s reaction lag, snapping to four whistle calls, the synthesised whistle code, and chibi hand signals per call (`_gesture`). The ghost target, the drop ring that turns green, the plumb line, and light knocks bouncing off while hard ones wreck the section. Low over the runway the crew steady it. All of it is a genuine skill toy, learnable in a minute.
- Flying the next section in during jacking keeps things moving.
- **Rigging:** the podger levering, the gold band on the cue ring, the hammer's swing timing with a close-up from the hammer side, and the R-clip snap all have strong feel.

**Problems**
- **Two of five jobs are idle** (pump and screeder) for 103–135 s per climb, three times a chapter.
- **The dogman's text banner says how to play.** "Push the stick toward the green ghost (1.9 m to go)" (`climb.gd: _signal`) duplicates the task bar ("dog it onto the ghost 1.9 m off, 2.0 m up") and the ghost itself.
- **Pinning repeats.** 4 pins × (align, podger, 3 blows, clip) × 2 sections is about 48 inputs, with no variation between pins. The bot does a section's pins in 14 s; a human will take 30 s or more, and it feels samey by the second section.
- **The hammer window is generous and static.** `SWEET` is 0.6–0.88 of a 1-second wind-up. There's no risk beyond "over-swung, reset".
- **The align close-up is blocked by the rigger's own hard hat** (`align.png`: the PiP is mostly green helmet).

**Recommendations**
- **Bring everyone in:** the pump op rigs slings on the ground (see §4), and the screeder runs pins and clips by hoist (§7). The rigger can't clip a pin until the screeder's delivered the R-clips. That's a light dependency, and nobody idles.
- **Vary pins:** one in four is "tight" (needs the podger plus a heavier 4-blow drive), and one has a burr (X to file it). Shrink the gold band by 15% per section on later climbs. Add a "glancing blow" if you release early: the pin backs out a little.
- **Make wind matter more visibly**: a gust warning 3 s ahead (the windsock snaps around and a whistle tone sounds) so the dogman can call "dog everything" proactively. Score bonus for calling it *before* the limit.
- Drop the "Push the stick…" banner after the first successful landing. Keep only the whistle call ("TROLLEY IN · four short"), which is flavourful.
- Move the align close-up camera over the shoulder on the *off* side, so the lug plates aren't behind the helmet.

---

## 9. Inspection, weather, traffic, truck kit

**What works:**

- The engineer's hold point with a missing bar chair is a nice pre-pour beat.
- The briefing card ties weather to consequences ("26 °C, about 39 s to keep an edge wet").
- The truck kit's outriggers and reach limits, with hand-placing beyond reach as a penalty, is a meaningful kit difference.

**Problems**
- **The defect is trivial**: one sign, a 1.2 s hold, given to the screeder.
- **The briefing card sits over the defect sign** (`inspect.png`: the card covers the deck, and the hand sign peeks out above it).
- **Weather is mostly a timer change.** Rain says "hold the pump", but with bots it's just a pause. Heat only shortens `open`.
- **Traffic rolls a 30% chance from level 2 on** (`_level_cfg`). There's no escalation and no authored day.
- **The truck kit has no climbs**, so it's strictly less content, and it stops the line hand's ladder work entirely (the riser lies along the ground).

**Recommendations**
- **Turn the inspection into a 20-second "find the faults" mini-game for everyone**: 2–4 defects (missing chair, a cover block, a cast-in item, a tie wire sticking up), each in a different job's colour. The pre-pour becomes a warm-up where every player learns to move.
- Make the briefing a **3-second card that slides to the left list** rather than a modal in the middle of the screen.
- **Author the chapter** (see §10): level 5 is "the hot one", level 8 "the storm", level 10 "peak-hour traffic".
- **Rain** should mark the surface where it lands while pumping, and the screeder can float it out later. That gives the pause a choice.
- **Truck kit:** give the line hand **hose-end and boom-section** jobs (a worn reducer, a boom pipe clamp at the elbow), and the outrigger setup as a 2-player timed task (pads under each leg, level bubble).

---

## 10. Scoring, ranks, grading, structure, replayability

**What works:** the "+N" pops off whoever did the work (`score.gd: _pop`) are great feedback. Ranks from Labourer to Concrete Legend have flavour. The itemised slab report teaches what mattered.

**Problems**
- **The bot ceiling.** An all-bot crew gets quality 100 and about 2,000 points every level and finishes at Site Super. A human can't exceed the bot on quality. The only differentiators are a few points of "Finished early". There's **no win condition that rewards humans for being humans**.
- **There's no failure.** A slab can't fail, and the chapter can't be lost. "Engineer's happy / Passable / not impressed" are the only stakes.
- **The curve is flat.** Same bays, same one clamp, same truck mix from L1 to L11.
- **The rank ladder is absolute** (26,000 for Legend), so it's a progress bar, not a goal.
- **There's no per-player recognition at the end of each slab.** `by_person` exists but only shows at top-out.
- **It's a 20-minute single run** with no save or chapter select, and R restarts everything. The top-out facts card ends with keyboard instructions.

**Recommendations**
- **Per-slab star targets** (yes, bring stars back): bronze, silver and gold point thresholds per level, tuned so **bots alone earn bronze**. Humans who make better decisions (pace, load calls, pre-emptive checks) reach gold. Give each level a "par" pour time.
- **Make quality fallible for bots too.** Give bots a skill setting (Apprentice / Leading Hand / Legend) that adds hesitation and the occasional wrong call. In solo, the bots are your crew to babysit, which creates the drama.
- **Per-slab awards** (Moving Out / Overcooked style): "Most concrete placed", "Saved the clamp", "Cleanest pins", "Bleed-water champion" (a funny shame award). One card, 3 seconds, every slab.
- **Author an 11-level arc** with one new twist per level:
  - **L1** tutorial pour, no failure
  - **L2** first weeping clamp
  - **L3** first stiff load decision
  - **L4** first climb
  - **L5** hot day
  - **L6** blockage
  - **L7** climb in wind
  - **L8** storm
  - **L9** traffic and old loads
  - **L10** final climb at height
  - **L11** "the big one": a double-size slab and every system on
- **Session shape:** a chapter select after level 1, saving the best stars per level. Two "quick shift" modes for parties: a single 5-minute pour, or a single climb.

---

## 11. Bots

**What works:** the bots use the same buttons, do route search on each level's walkable grid, unstick themselves, and bark useful lines ("Clamp coming up!", "Pressure's off!"). This is exactly what makes solo playable and the world feel alive. The pump bot running parts up the haul rope in parallel is a lovely emergent co-op moment. In my 11-level run nothing stalled (19.5 min, no timeout).

**Problems**
- **The bots are too good and too pre-emptive.** The boom bot stops at `wear > 0.25` and aims at the exact lowest point. The pump bot makes perfect calls, and the dogman bot uses a privileged autopilot (`climb.dog_bot = p`) unless `_naive_dog`. The README's "through the same buttons" isn't true for the dogman.
- **Bots solve the human's problems for them.** If a human is the line hand, the pump bot automatically runs parts (`_help_parts`) and drops pressure. The human never has to ask. The same goes for crew helpers on the poker.
- **The bots never need the human.** No bot ever waits on a person in a way that's visible and timed.

**Recommendations**
- Give each bot a **skill tier** and **reaction delay** (0.4–1.5 s), plus a small mistake rate on judgement calls. Make bots occasionally **ask** rather than do: the boom bot calls "Pump op, I'm on low, hopper?", and the pump bot waits for a "pressure off" request from a human line hand (Y = call, which the README says is the signals button).
- Add a **"Ping" (Y) for humans to command bots**: Y near a task assigns the nearest idle bot to it, with a speech bubble and a coloured line. That's how solo becomes managerial and fun rather than spectating.
- Make the dogman bot go through the whistle layer the same as a human (keep `_naive_dog` behaviour, but tune it).

---

## 12. Smoko (docs/smoko.md)

**Verdict: worth building, but smaller and later than the doc proposes.** The *flavour* (a cuppa, Iced VoVos, crew banter, the sky moving from morning to arvo) is the soul the game needs between levels, and it's cheap. A per-person **tiredness meter** that slows walking and shrinks timing windows is risky in a party game: it punishes the busiest player, makes the game feel slower, and adds a fourth resource to watch. With humans already idling, giving them "drink water" as their downtime job is a bandage over the pacing problem.

**How I'd build it**
1. **Phase 1 (S): the scene only.** It fires between L3/L4 (morning smoko) and L6/L7 (lunch). It runs 8 seconds and can be skipped by everyone holding A. The crew sit on crates; per-slab awards and banter play as speech bubbles. It doubles as the **chapter checkpoint and save**, and the sky changes. No meter.
2. **Phase 2 (M): heat only.** On "hot day" levels (authored, not random), tiredness builds only for players doing hard work in the sun. The esky (hold A, 2 s) is a *choice during a lull*. Cap the penalty at a 15% walk-speed reduction, and never touch timing windows (accessibility).
3. **Skip the "skip smoko" risk/reward.** It adds a menu decision nobody will take at a party.

Bots drinking when idle is good as background life.

---

## 13. Everything else

**Audio**
- The synthesised whistles, pump stroke and rattle are great.
- Add **job-specific alarm voices**. The line hand needs a distinctive clang-rattle when a clamp starts weeping, the pump op a reversing beeper and a hopper-low klaxon, and the deck a "going off" chime. Players on a couch navigate by ear when the screen is busy.
- There's no music. A low radio track that ducks during crises would add a lot of mood.

**Haptics**
- Android-only phone vibration is fine. Add pad rumble (`Input.start_joy_vibration`) on the same patterns; it's 10 lines of code.

**Camera**
- The main camera frames by humans, but **zooms out to include the whole tower** too often. Bias it to the humans' bounding box plus 3 m, and let the hand-sign markers clamp to the screen edge (with an arrow) when off-screen.
- The off-screen sign arrow is the single biggest missing navigation aid.

**Onboarding**
- There's no tutorial. Level 1 should be a **guided pour**: no failures, each job's first action gets a 2-line caption card in the job colour, then it switches off.
- Level 4 (first climb) needs the same treatment for the dogman and rigger.

**Session length**
- The 20-minute chapter is fine for a session, but **each pour (about 60 s) is short and each climb (about 2 min) is long**. Party players want 3–5-minute rounds with a result screen. Consider merging a climb and the following pour into one "day", scored together.

**Virality**
- The funny moments are already there: a wrecked tower section crumpling, a hose whip, bleed water, a rejected truck driving off. Make them **louder**: slow-mo plus a stinger and a "replay" GIF (last 5 s) at the slab report.
- Name tags on chibis ("Robbo got grouted") in the call-outs make clips shareable.

---

## HUD optimisation: concrete list

**Cut**
- The **"Esc pause"** hint (14 px, bottom left). Every player knows Start or Esc; put it in the front end only.
- **Queued-truck tickets** ("Truck queued · 34 min old"). Fold them into the pump panel.
- The **"Wet edge" ticket** as a generic bar. Replace it with the in-world edge band (below).
- **Per-truck world text** ("3.5 m³ left", "Check the docket") when the truck isn't selected or near the pump op.
- The **dogman instruction banner** after the first landing.
- **The level label "L2/11"** from the score box. Move it to the task bar ("L2 · POUR bay 2 of 4").
- The **duplicate quality text** in the slab report: keep one big "QUALITY 100" stamp and the bonus line.

**Merge**
- **Ticket and PiP title:** when a ticket has a close-up, the PiP *is* the ticket. Put its countdown bar along the PiP's bottom edge, and drop the left-list row while the PiP is up.
- **Pump panel and hopper:** one tall vertical hopper gauge (green/amber/red plus a pattern) with two truck icons beside it (filled = at the pump, outline = on the road, with a number on each for docket age). Show line pressure as an icon that turns red with a "!" only when it matters. No "73 bar".
- **Score and rank:** a big score with the rank as a small badge icon. Move the rank progress bar to the slab report.
- **Wind:** fold it into the task bar on climb days as an icon with a gust gauge and a limit tick.

**Move**
- **Briefing card:** off the centre and into a left-side slide-in that collapses into the list after 4 s.
- **Close-ups:** dock them in **player order** along the bottom edge, one per human, each in that human's job colour, with the player's name and pad or phone colour on the tab. Never show a bot's PiP unless it's working on a human's problem (the clamp the human boom operator must wait for).
- **Call-out toasts:** out of top-centre (where the task lives) to just above the relevant player. Keep top-centre for crew-wide alerts only (STOP, EMERGENCY STOP, burst).

**Add**
- **Off-screen indicators** for hand signs: an edge arrow in the job colour with the job icon.
- **Job icons, not letters:**
  - **boom:** a crane-arm silhouette
  - **line:** a clamp ring
  - **pump:** a truck
  - **poker:** a vertical rod with waves
  - **screed:** a horizontal board

  Use them on hats (a decal), tickets, signs, PiP tabs and the phone. **Every job has a unique icon and a unique colour**, so colour is never the only channel.
- **A colourblind-safe palette option**: an Okabe–Ito-style set (boom `#E69F00`, line `#0072B2`, pump `#D55E00`, poker `#CC79A7`, screed `#F0E442` with a dark outline). Plus **patterns** on the overlays: hatch for raw, dots for ready-to-screed, stripes for the cold edge.
- **The wet edge on the slab:** a pulsing band in world space along the edge that's cooling, with a timer number floating over the worst spot.
- **Hand signs tinted by job colour and showing the job icon.** Red stays for urgency as a ring, not as the fill.
- **Player-coloured rings on button cues**, so when two A cues overlap you know which is yours. The cue's ring is in your *player* colour; the glyph is A-teal.
- **A text-size slider** (100 / 125 / 150%) in pause.
- **Raise minimum sizes**: the task bar to 26 px, tickets to 22 px, the score to 36 px, world labels to an on-screen floor of about 18 px with distance scaling. Signs and pops already scale with distance; do the same for name tags and station labels (`F.label3d` usage in `_make_station`).
- **Split-screen street band:** tighten the camera to the pump operator's 10 m radius, and raise `BAND_FRAC` to 0.4 when the street player is doing hands-on work.

---

## Top 15 changes (prioritised)

| # | Change | Impact | Effort |
|---|---|---|---|
| 1 | **Real decisions back in the pump op's hands:** a docket card after the slump test with accept / water / reject, scored by consequence (a weak patch, a blockage, a dry hopper). Keep the "right answer" highlight as an Assist option (`line.gd: _bay`). | High | S |
| 2 | **Incident director:** 1 incident per bay from L3 (clamp, blockage, bracket, hose end), scaled by level and human count. Causes are linked to choices (high output, stiff loads, missing pins) (`main.gd: _update_pour`, `line.gd: start_failure`). | High | M |
| 3 | **Bot skill tiers and mistakes**, plus **bronze/silver/gold per slab with bots alone earning bronze**. Humans finally beat the bot (`bots.gd`, `main.gd: _grade`). | High | M |
| 4 | **TV legibility pass:** minimum sizes (task 26, tickets 22, world labels with an ~18 px on-screen floor), a text-size slider, and refreshed screenshots (`hud.gd`, `ui.gd`, `_make_station`). | High | S |
| 5 | **Job icons and a colourblind palette and patterns:** unique icon per job on hats, signs, tickets, PiPs and the phone. Hand signs tinted by job. Pattern overlays for raw, screed-ready and the cold edge (`ui.gd ROLE`, `signs.gd`, `pour` shader). | High | M |
| 6 | **Nobody idles on climb days:** the pump op rigs slings on the ground, and the screeder hoists pins and R-clips to the rigger (`climb.gd`, `bots.gd`). | High | M |
| 7 | **Wet edge drawn on the slab**, plus the boom op's pace control on X (high/low feeds clamp wear and pressure), replacing the auto speed at `main.gd:1489`. | High | M |
| 8 | **Authored 11-level arc**: one new twist per level, L1 a guided tutorial pour with caption cards, and L4 the guided first climb (`_level_cfg`, `_brief_text`). | High | M |
| 9 | **Off-screen sign arrows and a tighter human-biased camera.** Fix the split-screen street band framing and the PiP occlusion (the helmet in align, the beam on C6) (`_update_camera`, `_build_insets`). | Med | M |
| 10 | **Soft poker-then-screed order** (a skin-over-honeycomb defect), and **NPC poker helpers scaled to zero** with a human poker in 3–4 player games (`pour.gd: screed_strip`, `_update_npcs`). | Med | S |
| 11 | **Per-slab awards card and per-player breakdown** (data already in `score.by_person` / `by_role`), plus a 5 s "replay" of the slab's funniest moment (a wreck, whip or spill). | Med | M |
| 12 | **Front end fixes:** ready-countdown instead of auto-advance, a phone page showing character, job icon and colour, a "Your job" tab in pause, and the term clean-up (Role / Site / Tasks) (`select.gd`, `controller_page.gd`, `pause.gd`). | Med | S |
| 13 | **HUD merge:** the PiP becomes the ticket (with a countdown on the PiP edge). The pump panel becomes a gauge with truck icons. Cut queued-truck tickets, "Esc pause", and duplicate world text and banners. | Med | S |
| 14 | **Bots ask, humans command:** Y-ping assigns the nearest bot to a task. Bots request help from humans ("pressure off?") rather than silently covering (`bots.gd: _help_parts`, `_pump`). | Med | M |
| 15 | **Smoko, phase 1 only:** an 8-second skippable crib-shed scene at L3/L4 and L6/L7 that doubles as a checkpoint and save, with sky time-of-day. Defer the tiredness meter to "hot day" levels. | Low | S |

**Stay true to the job.** Every change above uses something real: docket judgement, pump output vs line wear, the wet edge, rigging slings, hoisting gear, and the poker-then-screed order. Most of them are already modelled in the simulation. The prototype doesn't need more realism; it needs the realism to **ask players for decisions** and to **show the consequences big enough to see from the couch**.
