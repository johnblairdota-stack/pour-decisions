# Story Bridge + Howard Smith Wharves (HSW) render: brief (15 Nov 2026)

John: "work on the Story Bridge and HSW in the render ... collect lots of pictures from the internet
for its own showcase. They will go into the same render. No people or cars. It should be accurate to the
images. That area will be our next playable area and should feel like the real HSW in Brisbane."

Same Blender scene as Spire (`tools/blender/spire/`, Blender 4.5 on John's PC). HSW and the Story Bridge
already exist there as step-6/7 quality modules (`hsw.py`, `landmarks.py`, `layout.HSW`,
`layout.STORY_BRIDGE`, `buildings.HSW_ZONE`). This work takes them to hero quality, photo-matched.
Default stage for this work = AS BUILT (today, ~2022-2026), not the 2017 dig.

## Rules carried over from Spire
- LiDAR (reference/sites/spire/lidar, LIDAR_BOX already covers HSW + Kangaroo Pt) is for measuring
  only; every visible surface is clean modelled geometry.
- layout.py stays the single source of truth for numbers; new HSW numbers go in `layout.HSW` with a
  `source`/`evidence` note.
- No people, no cars (also none on the Story Bridge deck). Boats: none moving; moored pontoons only.
- Don't "fix" exposure from washed-out cloud renders (PC colours are right).
- Reference photos are for John's private showcase only: never commit photos to git. URL lists are fine.
- Every build fails if a tree or prop sits on a road/path/water (reuse the carriageway check).

## What must read as the real place (checklist from photos)
Story Bridge
- Grey-green painted steel cantilever truss (not black, not red): K-pattern panels, the two tall
  main-pier towers of truss rising to ~80 m AHD, curved top chord down to the suspended span,
  riveted gusset feel at 2 px scale, lattice portal bracing between the trusses, lights along the rail.
- Main piers: massive concrete piers, the north one standing IN the HSW site beside Mr Percival's
  and Felons; stepped/rendered base, timber/rock gabion edge at the water.
- North anchor pier + approach spans stepping up onto the New Farm cliff top (Bowen Tce),
  approach piers in concrete with arches; deck underside visible from HSW (steel floor beams, stringers).
- Kangaroo Point end: south anchor pier on the Kangaroo Pt cliffs, approach to Main St.

HSW (west -> east along the strip under the cliff, check OSM + photos)
- Crystalbrook Vincent (ex-Fantauzzo) hotel at the cliff base under the bridge: jagged/faceted
  facade in natural tones, rooftop pool; car park entry.
- Heritage wharf sheds: long low corrugated-iron gable sheds, cream/white with timber, Felons
  Brewing Co (big shed with brewery tanks visible through glass, "FELONS" signage), Felons Barrel
  Hall (over-water shed), Rivershed, Stanley (the 1936 two-storey Howard Smith office, brick/render),
  Yoko, Betty's Burgers, Howard's Hall, Green House / Bougainvillea House (glass + steel pavilions).
- Mr Percival's: octagonal timber-clad over-water bar on piles between the bridge pier gabions,
  pink/white striped umbrellas (ok as static props).
- Main Lawn: big open grass area in front of the cliff, with the cliff + bridge as backdrop.
- Cliffs: ~20-25 m Brisbane tuff (pinkish/purple-grey, quarried faces, horizontal benches),
  shotcrete patches, rock bolts, mesh in places; vegetation tufts and figs/vines hanging over the top;
  Bowen Tce houses and Wilson Outlook Reserve fence at the top.
- Corten lift tower(s) up the cliff to Bowen Tce (rust-brown, with bridges to the cliff top) and stairs.
- Riverwalk: concrete-topped boardwalk on steel cantilevers along the river edge, steel balustrade,
  lights; pontoons + the Council ferry terminal (white/grey canopy) and HSW pontoon.
- Greenery matters a lot: figs, palms, frangipani, poincianas, planters, lawn edges, cliff vegetation.
- River: brown-green Brisbane River, mangrove fringe where present, Kangaroo Point cliffs opposite.

## Deliverables per round
1. Renders from camera spots matched to reference photos (photo_fit.py from hand marks where useful)
   + a few hero views (aerial from SW over the river, from Kangaroo Pt cliffs, Main Lawn toward the
   bridge, Riverwalk under the bridge, from the Story Bridge deck down, from Wilson Outlook, from a
   CityCat in the river, night is optional later).
2. A pairs folder: `PourDecisions-sites\hsw_showcase\round_NN\` holding `<id>_photo.jpg` +
   `<id>_render.jpg` (1600 px long side, q82) and `pairs.json`
   ([{id, title, photo_source_url, photo_credit, camera, notes, fit_px}]). The cloud thread copies this
   folder into the project and publishes the showcase.
3. Code + render-only outputs committed to branch `claude/project-thread-ulx8uc` (renders may go in
   docs/hsw/renders/round_NN/, max ~1600 px jpg). Photos never in git.
