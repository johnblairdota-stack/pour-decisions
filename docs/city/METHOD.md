# The Brisbane model: how we build it

Goal (John, 26 Nov 2026): a 1:1 Brisbane with shocking detail, growing outward from the towers the game is
about. The review that set these rules is at https://claude.ai/artifact/HsP4GjH3bczYtjf6DV8A6f (overall C:
good data, a method that could not grow).

Where the model stands is in [coverage.md](coverage.md), made by `python3 tools/city/coverage.py`.

## The detail ladder (what 1:1 means)

Every 1 km tile of the MGA zone 56 grid has a grade. A grade says how real the tile is, not how busy it looks.

| Grade | What is true of the tile |
| --- | --- |
| 0 | Nothing |
| 1 | Map only: aerial photo and outlines, heights guessed |
| 2 | Measured: real ground, real building heights, real tree tops, real roads (2019 LiDAR + OpenStreetMap) |
| 3 | Measured, with landmarks built by hand from references |
| 4 | Observed: roof shapes fitted to the LiDAR, roof colour from the aerial, walls from street-level photos |
| 5 | Photo-true: three or more photo views of the tile pass, from different sides |

`coverage.py` works out grades 0 to 3 today. Grades 4 and 5 arrive with the work that makes them possible.

## Rules

- **One lane.** The Brisbane model takes the one design/research slot (see CLAUDE.md). It never edits game
  scripts. Anything the game uses from it (a corridor, a backdrop image) goes in its own small PR.
- **Blender in the cloud only**, never on John's PC. One version for everybody: `tools/city/setup_cloud.sh`.
- **New areas arrive through the pipeline.** A new LiDAR tile becomes a grade 2 tile by running the data
  scripts. Nobody hand-places a suburb.
- **Observed before dealt.** A building is dressed by rule only when nothing real exists for it.
- **No guessed colours.** A colour is measured from a photo (`tools/spire_area/calib_probe.py` style) or left
  alone. Guessed hex values swung back and forth for sixteen rounds.
- **Landmarks: one file each**, with a fact sheet (sources, key sizes) and three photo views it has to match.
  `area_hero.py` and `hsw_hero.py` are too long: move a landmark out when you next touch it.
- **Every model PR** runs `python3 tools/city/coverage.py` and `python3 tools/city/check.py`, and says which
  coverage number moved. CI runs the check (`.github/workflows/city.yml`).
- **Critics**: five rounds at most. They give a list of what is wrong and later mark each item fixed or not.
  No 0 to 100 scores: three critics scored the same pictures 44, 56 and 66.
- **Showcase pages** are refreshed at milestones: a new ring of tiles, a new landmark, a grade change.
- **Photos never go in git.** John's own photos and downloaded reference photos stay on his PC
  (`Documents\PourDecisions-sites`) and in the project files folder.

## Two commands from nothing to a picture

    tools/city/setup_cloud.sh
    CYC_SAMPLES=32 /tmp/city-venv/bin/python tools/blender/spire/render_pairs.py tools/city/showcase/pairs.json out only=skytower_kp_2019 width=1000

The model builds from what is in git (`reference/sites/spire/`). The raw downloads (LiDAR tiles, big aerials,
OpenStreetMap extracts) are only needed to remake that data, and live on John's PC under
`Documents\PourDecisions-sites\data`.

## What is where

| Path | What |
| --- | --- |
| `tools/city/coverage.py` | the coverage map and table (the model's scoreboard) |
| `tools/city/check.py`, `known.json` | data check run by CI; `known.json` holds ceilings that only go down |
| `tools/city/landmarks.json` | places a local would look for, built or not |
| `tools/city/tiles_plan.json` | the next LiDAR orders |
| `tools/city/measure_build.py` | time, memory and triangles of the whole build, per module |
| `tools/city/showcase/` | the mega showcase builder, its photo camera lists and render jobs |
| `tools/sites/` | data scripts: raw downloads to `reference/sites/` (river, roads, paths, buildings, roof colours) |
| `tools/blender/spire/` | the Blender builders (`build_all.py` runs them in order) |

## The plan

1. Foundations: this folder, the setup script, the check. (PR of 26 Nov 2026.)
2. Build the city in tiles: each 1 km tile built and saved on its own in near, middle and far versions; a
   render loads only what its camera sees. Done when the whole model builds under 8 GB, a single view starts
   rendering in under 2 minutes, and adding a tile changes no other tile.
3. Grow along the river: LiDAR order 1 (fill the holes: Suncorp, Milton, the Gabba), then order 2 (down the
   river to Riverlight). Done at 71 measured tiles with Riverlight inside.
4. Observed detail: fitted roof shapes, aerial roof colour per building, walls from street-level photos. Done
   when under 30 % of centre-tile buildings are on a generic recipe (93 % city-wide today).
5. Landmarks as a list, in the order a local would miss them: City Hall, Suncorp Stadium, the Gabba,
   Riverlight, the Powerhouse, Roma Street Parkland.
6. Measure with numbers: coverage table, plus a skyline-outline overlap number for each photo view.

## Baseline before the tile build (26 Nov 2026)

`tools/city/measure_build.py`, cloud machine (4 cores, 15 GB), Blender 4.5: the whole city builds in 159 s
into 28.9 million triangles and 1,404 objects, and peaks at 9.8 GB before a single pixel is rendered. Every
render process pays that again. Trees are 8.4 million triangles, the Howard Smith Wharves module 6.1 million
and the city-wide buildings 6.4 million. Per-module numbers: [build_baseline.json](build_baseline.json).
