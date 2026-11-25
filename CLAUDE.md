# Pour Decisions: rules for every Claude session

John designs this game and plays it. He is not a programmer. He works from his phone through a project chat, and parallel Claude threads build the game in PRs. This file holds the rules every session needs, including sessions that can't see the project memory.

## The game in one paragraph
Godot 4.7 (Forward+, standard build, GDScript only), couch co-op concrete pours. A crew of six, with bots filling any job nobody takes, and phones that join as controllers (web server on :8080/:8081). Riverlight (11 levels, Hamilton, Brisbane) and Spire (34 pours) are both towers, plus a water tower tutorial. The README is the player-facing guide, so keep it true.

## Design rules (John's, keep them)
- Anyone can play any job with no experience, have a good time at it, and learn the real physical steps.
- PAY RULE: no job earns money for actions that don't help the pour (no spam pay, no overfill pay, no idle pay).
- Dogging: slew left and right are always from the crane operator's point of view. Signal text belongs in the arrows, not floating.
- Real site practice wins. The slump test follows AS 1012.3.1 (scripts/slump.gd).
- The recurring critique themes are what we're fixing first: bots too perfect, no difficulty curve, idle jobs, text too small for a TV, colour-only marking, and the game making decisions for the player.

## How work flows
- One PR per change. John merges each PR himself by saying "merge N". Never merge without that.
- **CI must be green.** `.github/workflows/smoke.yml` runs `tools/ci/smoke.sh` on every PR. Don't ask John to merge a red PR. If CI is red because of your change, fix it. If main was already red, say so.
- Every PR description has a **"How to see it"** line: which tower, which level, and what to look at, so John can check it in two minutes.
- **Work-in-progress limit:** at most 2 threads building code plus 1 design/research thread at a time. New ideas go on the list and wait.
- **No sync after every merge.** Merges go to main, and the release job (`tools/release/release.ps1` on John's PC) ships main to his PC folder and tablet once or twice a day, or when John says "ship it". Only the release thread runs it.
- **Core loop first:** until the recurring themes improve, prefer PRs that fix them over new towers, flights or renders.
- Render critic loops are capped at 5 rounds, or stop after 2 rounds with no gain. Showcase pages are refreshed at milestones, not after every model change.

## Code map (big files, edit with care)
| File | Lines (25 Nov) | What's in it |
| --- | --- | --- |
| scripts/main.gd | ~9.7k | game flow, phases, levels, camera, autotest flags, Spire extras. **Too big. Don't add to it.** |
| scripts/explore.gd | ~4.8k | free roam |
| scripts/line.gd | ~4.5k | trucks, hopper, pump, riser, clamps, slump (role key "line" = truck hand) |
| scripts/climb.gd | ~3.5k | climb days, boom tower jacking |
| scripts/pour.gd | ~1.8k | concrete volume and finish (pour.vol_k) |
| scripts/hud.gd, ui.gd | | TV HUD and shared UI |
| scripts/bots.gd | | bot behaviour |
| scripts/controller_page.gd | | the phone controller page |

- **New code goes in a new file.** A new tower, mode or system gets its own script, not more lines in main.gd. When you touch a big file anyway, move a self-contained piece out if you safely can.
- Several threads touch main.gd, line.gd, pour.gd, ui.gd, hud.gd, pause.gd and climb.gd. Keep diffs there small. Rebase on main before opening the PR, and again before asking for a merge.
- Role keys stay "line" and "pump" in code, even where the display names changed.

## Testing
- Quick check (about 10 min, what CI runs): `GODOT=/path/to/godot tools/ci/smoke.sh`. It imports, then runs short all-bot autotests (Riverlight top floor, tutorial, Spire top floor). Each run must finish with no script errors and no stalls. Each run uses a throwaway user folder, so saved progress never affects a test.
- Full run: `godot --headless --path . --fixed-fps 60 -- --autotest --nophones`. All 11 levels take 25–60 min. Don't run more than 2 at once or they time out.
- Getting Godot in the cloud: download `Godot_v4.7.2-stable_linux.x86_64.zip` from the godotengine GitHub releases, then `--headless --path . --import`.
- Syntax only: `pip install gdtoolkit && gdparse scripts/*.gd`.
- Other dev flags live in main.gd (`--startlevel=N`, `--site=spire`, `--tutorial`, `--shots=DIR --only=...`, `--trucktest`, `--human=<role>`). `--human` people are bots underneath, so drive them with ai_slow/ai_move, not Input.action_press.
- **Cloud renders are washed out** (software GL). Don't "fix" colour or exposure from a cloud shot. Check colour and fps on John's PC.
- Godot 4.7 can crash (AudioServer race) if `volume_db` is set every frame. Only set it when it changes.

## John's PC and tablet
- Play folder: `C:\Users\John\Documents\PourDecisions`. Tools: `C:\Users\John\Documents\PourDecisions-tools`. Back it up before overwriting anything, which the release script does.
- Never kill every Godot process. Kill only the PID your session started, because John may be playing.
- If a changed image still looks old, the `.godot\imported` cache is stale. The release script clears stale entries.
- The tablet (Galaxy Tab S10 Ultra) gets files over USB/MTP from `sync_to_tablet.ps1`. It must be unlocked with File transfer allowed. Only one sync runs at a time.

## Repo hygiene
- Large reference material (photos, LiDAR, render pairs) belongs in the project files folder, not in git. Don't add files over ~5 MB without a reason.
- Never commit secrets or John's own site photos.
