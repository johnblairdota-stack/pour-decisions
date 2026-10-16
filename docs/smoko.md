# Smoko: preliminary design

Status: design only. The worn-out look is prototyped: the crew slouch at the end of every pour, and the `--weary` dev flag keeps it on all the time. Nothing else here is built yet.

## What it's for

- **Pace with a rhythm.** Right now the game runs flat out from the first truck to the slab report. A real pour day has a rhythm: push hard while the concrete's coming, then grab a breather while the crane flies a section in or the next truck backs on. Smoko makes the quiet moments useful. You don't just wait through them, you recover in them.
- **Crew feel.** Chibis that visibly flag and then perk up after a cuppa are funny and likeable. They give the crew a personality between the jobs.
- **A light decision, never a punishment.** Being tired makes you slower and sloppier. It never fails a level. The choice is *when* you rest, not *whether* you get punished.

## The real thing (for flavour and numbers)

- On-site building workers get a **10-minute paid morning rest between 9 and 11 am** and a **30-minute meal break between noon and 1 pm**. A paid crib break kicks in on long overtime days. (Building and construction on-site award, clause 28.)
- On hot Queensland days the guidance is: **small, frequent drinks (150–200 mL every 15–20 minutes)**, rest anyone who's dehydrated in the shade until they've rehydrated, rotate people out of the sun between about 10 am and 2 pm, and stop if you see headaches, dizziness, cramps or heavy sweating. (Master Builders QLD, hot conditions.)
- Concrete waits for nobody. You **don't stop a pour for smoko**. Crews take breaks in rotation, or once the slab is finished.

## The mechanic

### 1. "Puff": a tiredness meter per crew member

- Every crew member (players and bots) has `weary` from 0 (fresh) to 1 (cooked). It's already on `player.gd`.
- Exertion fills it:

  | Activity | Rate |
  |---|---|
  | Running when urgent | high |
  | Hammering, poking, screeding, carrying a pipe, climbing the ladder | medium |
  | Standing about, riding the hoist | none (it slowly recovers) |

- **Heat multiplies it.** The level's temperature (the 21–35 °C on the briefing card) scales the rate: about ×0.7 at 21 °C, ×1.5 at 35 °C. Rain cools you down.
- What it does, gently (all scale with `weary`):
  - **Look:** they slouch, the head hangs and lolls, eyelids droop, arms dangle and sweat drips. This part is built.
  - **Walk:** up to 35% slower. Built, with `weary` driving it.
  - **Timing windows:** the hammer's gold band, the hole tolerance and the poker radius shrink by up to about 25%. The cue ring wobbles a little.
  - **Over about 0.85:** "cooked". They shuffle, can't run for red signs, and a sweat-drop icon goes over their head. A **WATER** hand sign (in the style of the existing job signs) appears over them for whoever is nearest.

### 2. Water esky: quick top-ups during a pour

- A blue esky sits at the crib shed on the ground, and a water jug by the boom remote on the deck.
- Stand at it and **hold A**, about 2 seconds: a big gulp, a little "ahh" bark, and `weary` drops by 0.4.
- The best times are when nothing needs you: while the crane flies a section in, while a truck reverses on, or while the line is being remade.
- It's in the same A-button language as everything else. No new controls.
- Bots drink on their own when they're idle and over 0.5. A cooked bot is a visual nudge to cover for them.

### 3. Smoko: the proper break between pours

- After the slab report, once the level is above about 0.5 average tiredness (or on a schedule: one morning smoko around level 3 and lunch around level 6, echoing the 9–11 am rest and the noon meal break), the foreman calls **"SMOKO!"**
- It's a short scene, about 10 seconds or less, skippable with A:
  - The crew wander to the crib shed under the shade cloth and sit on milk crates and the esky.
  - Tea and water come out, and there's some banter in the speech bubbles ("Who brought the Iced VoVos?", "Pump's running sweet today"). Everyone's tiredness resets.
  - The sky moves on (morning → midday → arvo), so the chapter feels like a working day.
- **Optional push-on:** the foreman can call "skip smoko". You save the scene, but the crew start the next pour already a bit tired. It's a small risk/reward choice for speed-runners.

### 4. Hot days (the extreme case)

- Over 33 °C, the briefing card says "**Hot one today: water every 15 minutes**".
- Tiredness builds faster, and a **"Rotate out of the sun"** tip appears: a cooked bot steps off its job for 10 seconds into the shade, and the nearest free person (or bot) covers. This teaches the real rotation practice without a lecture.

### Points

- **+10 "Kept the crew watered"** for each top-up taken before someone hits cooked.
- **+25** at the end of the level if nobody got cooked.
- **No negative points** for being tired. Slower work is the only cost.

## Animation notes (the prototype)

`player.gd → animate()` blends on `weary`:

- **Torso:** leans forward 0.2 rad, and the body squashes about 7% (a slump).
- **Head:** drops 9 cm, pitches down 0.42 rad, and lolls slowly side to side (0.8 Hz). The usual quick bob fades out.
- **Eyes:** the lids close to about 25% open, with a slow blink every few seconds.
- **Arms:** the walking swing shrinks, they hang forward a touch and dangle.
- **Sweat:** small blue drops fall off the hard hat above 0.45.
- **Walking:** speed × (1 − 0.35 × weary).

Still to add:

- A yawn: the head tips back and the mouth opens, every 6–10 seconds while cooked.
- A sit-down pose for smoko: legs forward, hands on knees.
- A "perk up" pop when they drink: squash and stretch plus a sparkle.

## Open questions for John

1. Should smoko be called by the game (on a schedule or on tiredness) or by the players (anyone can hold Y at the crib shed between pours)?
2. Does heat belong in every level or just summer chapters?
3. Do real SCP crews break differently on a big pour day (rotating the line hand out, say)? That would be worth copying.

## Sources

- Building and construction on-site award, clause 28 (meal break, rest period, crib): https://www.fwc.gov.au/documents/consolidated_awards/an/an120089/an120089-30.htm
- Master Builders Queensland, hot conditions: https://www.mbqld.com.au/resource-hub/health-safety-and-environment/common-hazards/hot-conditions
