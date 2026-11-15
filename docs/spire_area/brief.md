# Spire area render: brief (15 Nov 2026)

John: "I want to reactivate Spire Residence and the local area showcase render work with its own loop.
Lots of kerbside things and the crane and booms had to be taken away from Spire so that in game it looks
like a site and not a finished building. So the critic and showcase builder will need to know to work on
lighting, textures, greenery, car parks, roads, road markings, signs, lights, traffic lights and whatever
else it can find to improve in the blender file, but not to add more to the Spire site that will affect
the gameplay. It should take time finding new photos for the surrounding areas and create new hero
photos of other buildings as well as the cathedral and its parking lot."

Same Blender scene (`tools/blender/spire/`, Blender 4.5 on John's PC, rebuilt from scripts; nobody saves a
shared .blend). The HSW + Story Bridge thread works in the same scene on branch
`claude/project-thread-ulx8uc`; this work is on `claude/project-thread-o8dogj` (started from its tip
e285392). Merge `origin/claude/project-thread-ulx8uc` in before each round.

## HARD RULE: the Spire site is gameplay, hands off
The Spire site (tower under construction, its kerbside setup, crane, booms, hoist, hoarding, gate, sheds,
site plant) is driven by the playable level now. Do NOT add to it or change it:
- Don't edit `spire.py`, `core.py`, `logistics.py`, `site_plant.py`, `clear_kerb.py`, `export_game.py`,
  or `layout.SPIRE / TOWER_PLAN / LEVELS / CORE / JOINT / PODIUM / STAGES / CRANE / HOIST / TRUCK_GATE /
  SITE_SHEDS / PLANT`. Don't run `export_game.py` and don't touch `assets/`.
- KEEP-OUT ZONE for anything new: the lot (hoarding outline) + 9.5 m, and the Ann St strip in front
  (clear_kerb.py: ANN_MID (-16, 14.4), along (0.760, 0.650), +-46 m along, 30 m out). `area_hero.py`
  must not add objects there; its self-check fails the build if any new object's centre is inside.
  Material/lighting changes that happen to also recolour roads in that zone are fine (no new geometry).
- Spire itself: leave it as it is in every view.

## Shared-file etiquette (HSW thread works in the same files)
- New work goes in NEW files: `tools/blender/spire/area_hero.py` (built last, hook = one line in
  build_all.MODULES) and `tools/spire_area/` (render, cams, marks, fit, export, fetch_refs).
- Don't edit `hsw.py`, `hsw_hero.py`, `landmarks.py`, `layout.HSW*`, `tools/hsw/`.
- If a shared file must change (`streets.py`, `streetscape.py`, `trees.py`, `preview.py`, `looks.py`,
  `buildings.py`, `cathedral.py`, `ground.py`), keep the change small, note it in the round's NOTES.md,
  and the cloud thread tells the HSW thread.
- PC folders: clone `PourDecisions-sites\spire_area_build`; refs `PourDecisions-sites\refs\spire_area\`;
  pairs `PourDecisions-sites\spire_area_showcase\round_NN\`. Never use `hsw_build`.
- GPU: only one Blender at a time on the PC. Take `PourDecisions-sites\blender.lock` (write thread name +
  time), delete it when done; if it exists and is under 45 min old, wait.

## Rules carried over
- No cars, no people. No trees, shrubs or props on roads (carriageway check; build fails if any).
- LiDAR is for measuring; visible geometry is clean modelled geometry.
- layout.py stays the source of numbers; new numbers go in a new `layout.AREA` dict with source notes
  (append at the end of layout.py to keep merges easy) or in `tools/spire_area/*.json`.
- Washed-out cloud exposure is not a bug; judge colour on the PC renders.
- Reference photos never go in git (URL lists are fine). They are fine on John's private showcase.

## What to improve (everything around the site)
Lighting: sun/sky/haze, bounce light in streets, contact shadows, AO under kerbs and awnings, glass
reflections on neighbour towers, believable exposure in shaded street canyons.
Textures: neighbour facades from photos (brick, render, sandstone, tuff, glass, precast), wear and
staining, roof plant, road asphalt ageing and patches, concrete footpaths and pavers, kerb and channel.
Greenery: species by street (figs, poincianas, jacarandas, palms, brush box, tuckeroos), planted medians,
cathedral grounds lawn + garden beds, hedges, green walls, vines, grass verges, shrubs in car parks.
Car parks: St John's Cathedral car park (layout, bays, wheel stops, line marking, trees, lighting, gate,
signs), other open-air car parks and basement ramps in the 800 m model.
Roads + markings: lane lines, stop lines, pedestrian crossings (zebra + signalised), turn arrows, bike
lanes/boxes, yellow no-stopping lines, loading zones, red bus lane, raised medians, manholes, drains.
Signs: street blades, regulatory (no stopping, bus lane, clearway, one way, speed), parking signs,
wayfinding, building names (cathedral noticeboard etc.).
Lights: council street lights (types, spacing, both sides), pedestrian lights, car park lights.
Traffic signals: correct heads per approach, mast arms, pedestrian lanterns + push buttons, controller box.
Other: bus stops/shelters, bins, benches, bike racks, bollards, fences, retaining walls, stairs, the
Petrie Bight area, Fortitude Valley edge, Spring Hill streets, Story Bridge approach roads.

## Photos (take real time on this)
New reference photos of the surrounding area, filed by category in `refs\spire_area\<category>\` +
manifest.csv. Categories (start list): cathedral_exterior, cathedral_car_park, cathedral_grounds,
ann_st, queen_st, adelaide_st, wickham_tce_boundary_st, petrie_bight, church_house_webber_deanery,
orient_hotel, willahra_admiralty_mantra, other_towers_near_spire, street_furniture_signals,
road_markings, greenery_street_trees, aerial_overview, story_bridge_approach. Sources: Wikimedia
Commons (licence known), Openverse, venue/architect pages, Google image results gathered in John's
Chrome (cloud thread writes `reference/sites/spire_area/google_image_urls.tsv`).

## Deliverables per round (same shape as HSW)
1. Heroes from `layout`-style cameras in `tools/spire_area/area_cams.json`: keep the existing showcase
   views comparable, and add NEW heroes of other nearby buildings (Orient Hotel, Willahra, Admiralty,
   Church House/Webber House, Mantra, Petrie Bight towers, Customs House if in range) and of
   St John's Cathedral and its car park (eye level + raised).
2. Photo pairs solved with photo_fit (marks in `tools/spire_area/area_marks.json`): photo + render
   (1600 px long side, q82) + pairs.json in `PourDecisions-sites\spire_area_showcase\round_NN\`.
   Include the existing private pairs, re-rendered.
3. Code + render-only jpgs committed to `claude/project-thread-o8dogj` in docs/spire_area/renders/round_NN/
   with renders.json and NOTES.md (what changed, what's still rough, shared files touched).
4. Publish only `pairs/` + `pairs/pairs.json` into the showcase artifact
   https://claude.ai/artifact/1Ypy5MWrAwrkhK8Zgy8F6G (read it first, then republish keeping other files).
   The page reads `pairs/pairs.json` as {"pairs": [{id, photo, render, caption, date, fit_px, stage}]}
   (file names relative to pairs/). The cloud thread owns index.html + img/; also copy the round's
   heroes + pairs into `/mnt/project-files`-reachable form by committing render jpgs (photos stay off git).
