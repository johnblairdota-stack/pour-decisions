# Spire build (Blender)

Real-world Spire Residences (550 Queen St, Brisbane) and ~400 m round it, built from real data
first as a grey blockout, then cut into game parts later.

Blender 4.5 (the PC's install). Run from the repo root:

    blender -b --factory-startup -P tools/blender/spire/preview.py -- clay     # build + all previews (~5 s)
    blender -b --factory-startup -P tools/blender/spire/build_all.py -- --save C:/temp/spire.blend
    blender -b --factory-startup -P tools/blender/spire/prep_data.py -- <PourDecisions-sites>/data/cbd   # only to remake reference data

## Files

- `layout.py`: the one master layout. Frame (metres, origin = Spire footprint centre, +x east, +y north,
  z = metres AHD), loaders for the reference data, and the hand-placed things with their evidence:
  `CRANE`, `HOIST`, `TRUCK_GATE`, `SITE_SHEDS`, `CAMERAS`. Every other script imports it. No bpy.
- `common.py`: bpy helpers (materials, mesh buffers, polyline offset).
- `ground.py`: DEM ground mesh (2 m) + river water plane.
- `streets.py`: OSM carriageways, footpaths with 150 mm kerbs, footways.
- `buildings.py`: OSM footprints extruded to tagged height (Spire = its own object, warm clay;
  untagged = 12 m, blue-grey).
- `spire.py`: Spire itself (step 2): podium on the whole lot (GF-L3), tower plate traced from the typical
  floor plan and fitted to the 2018 roof, lift core, and every slab as its own object split into its two
  pours (`SLAB_L07_A`, `SLAB_L07_B`; custom props level, pour, top_ahd, slab_m). L6 = 1.25 m transfer slab.
- `landmarks.py`: Story Bridge line (rough deck + truss silhouette for the skyline).
- `logistics.py`: crane, hoist, truck gate and site shed markers.
- `build_all.py`: clears the scene, runs every `build()`, writes `docs/spire/blockout_meta.json`.
- `preview.py`: Workbench renders to `docs/spire/` (each under 2 s).
- `prep_data.py`: makes `reference/sites/spire/` from the big download. See `reference/sites/spire/CREDITS.md`.

Each module's `build()` returns a metadata dict (objects, counts, sources, notes).

## Step 1 results (docs/spire/)

- `top_clay_over_2016.png`: whole 800 m square, clay over the 2016 aerial.
- `site_clay_over_2016.png`: 160 m round the site. Spire footprint sits on the 2016 dig; crane jib (yellow),
  truck gate (red, Ann St), hoist (blue dot, NW face).
- `cam_ann_queen_corner_clay.png`, `cam_ann_far_clay.png`, `cam_ann_footpath_clay.png`: from the spots of
  three of John's street photos (spots estimated, no GPS in the photos). Crane hidden: photos are post-2017.

## Step 2 results (docs/spire/)

- `site_clay_over_2018.png`: finished tower plate over the 2018 aerial (roof with the pool) - placement check.
- `spire_slabs_pours.png`: storeys hidden, 88 slab pours + core; pour joint seen end-on, L6 transfer in orange.
- The street views now show the rounded tower on its podium.

## Step 3 results (docs/spire/)

Core and pours reworked (John, 14 Nov): the core is its own element (`core.py`), cast ahead of the
slabs in a climbing jump form, square and plumb. Each slab wraps round it in two pour areas, A (west
third) and B, split by a construction joint of two short lines from the core faces to the slab edge
(`layout.JOINT`, an assumption). Slab objects carry `pour_area`, `poured`, `area_m2`, `joint_lines`.

- `spire_slab_L07_pours.png`: plan of L07: pour A grey, pour B blue, the core hole, the two joint lines.
- `spire_slabs_pours.png`: all slabs, joint end-on, L6 transfer orange.
- `cam_ann_footpath_clay.png`: the sloped brick podium face on Ann St (`layout.PODIUM`).
- Stage `2016_l6` (`build_all.py -- --stage 2016_l6`): L1-L5 done on an assumed 8 m column grid, L6
  transfer on the deck (pour A poured, B formwork + reo), formwork props + 3 levels of backprops, edge
  screens, core 3 levels ahead with the jump-form rig, crane, hoist placeholder, two Schwing KVM 26
  booms, Putzmeister BSA 2109 HD line pump in the Ann St gate, delivery line, agitator, hoarding, and
  sheds on the Ann St footpath gantry seen in the 2016 aerial.
  Renders: `site_clay_over_2016.png`, `top_clay_over_2016.png`, `stage_flyby_sw_2016.png`, `stage_deck_nw_2016.png`.
- Neighbour heights: no DSM exists for the CBD on the state service (ground DEM only). Heights stay OSM
  height, else OSM levels x 3.2 m, else 12 m. Ordering the CBD LiDAR tiles from ELVIS would fix this.

## Known gaps (next steps)

- Floor count: 43 PT slabs to the LiDAR roof (136 m AHD) gives 2.53 m floor to floor above L6 - too low for real floors. Check the section.
- The plate scale is fitted to the 2018 roof (25.5 px/m), not the drawing's scale bar (21.8 px/m).
- Pour joint position, column grid, boom and pump spots are assumptions. Jump-form system for Spire is unknown.
- Footpath width is a default (3.5 m), not measured. Kerb lines can come from council parking lines.
- Hoist position is unknown (John doesn't know): placeholder only.

## Step 4 results (2019 LiDAR)

Data: 16 x 1 km tiles of the Brisbane 2019 LiDAR (ELVIS order, raw files in PourDecisions-sites, not in
git). `tools/lidar/grid_spire.js` grids each tile (Node + laz-perf); `prep_lidar.py` makes the small
products in `reference/sites/spire/lidar/` over `layout.LIDAR_BOX` (1.6 x 1.4 km incl. HSW and Kangaroo Pt).

- Ground is now the 2019 LiDAR everywhere (`layout.ground_z`), 2 m mesh, 1 m over HSW and its cliffs.
- Buildings: rendered as the LiDAR roofscape (1 m, solid to the ground). LOD1 prisms with LiDAR heights
  per OSM footprint are kept hidden for the game's far LOD (`building_heights.csv`, 451 footprints).
- Spire refit from the LiDAR: roof deck 136.0 m AHD, plant top 147.7 m; tower centred at (0.0, 4.6),
  turned 43.0 deg; podium edge traced from the LiDAR (`spire_podium.json`), podium roof ~36 m AHD = L5,
  so the podium is L1-L5 and the tower starts at the L6 transfer slab.
- Story Bridge: 1 m voxels straight from the bridge points (truss, piers, approaches at true height).
- St John's Cathedral: 0.5 m solid from its points (nave, towers, spires, buttresses).
- Howard Smith Wharves: own module `hsw.py` (1 m LiDAR solid of the strip under the cliffs, named OSM
  features listed in the metadata). Mid-build 2017-18 state: not built yet.
- Trees: 9,760 tree tops from the LiDAR. River bed pushed under the water where the LiDAR saw water.
- Booms fold over their own pour area (never past the slab edge).
- First pass of materials + a low ENE morning sun (Eevee): `*_morning.png`.
- Renders: `hero_bridge_hsw_clay.png` (photo to compare: my_photos/hsw/...aerial-2017-06-june),
  `hero_hsw_lift_tower_clay.png` (photo: my_photos/hsw/hb-m-hsw-shoot2-2), `hero_cathedral_clay.png`,
  `hero_bridge_hsw_morning.png`, `cam_ann_queen_corner_morning.png`. Photos are John's, not in git.

## Step 5 results (clean look)

Rule from here on: the LiDAR is for measuring only. No mesh made straight from points or the DSM is shown.

- Buildings (`prep_clean.py` -> `lidar/buildings_clean.json`, built by `buildings.py`): 1,102 OSM footprints,
  simplified to 0.3 m and squared, extruded to LiDAR-measured roof tiers; parapets on flat roofs, clean
  gables on pitched ones, pyramids for spires and masts, floor lines every 3.2 m, and four facade families
  (heritage stone, brick low-rise, 70s-80s concrete, glass) picked from height and OSM tags.
- Story Bridge (`landmarks.py`, `layout.STORY_BRIDGE`): parametric steel cantilever truss (anchor arms,
  cantilevers, suspended span, chords, verticals, diagonals, top bracing, floor beams), main and anchor
  piers, approach spans on piers, deck, footways, railings, lights. LiDAR only fixed the alignment,
  pier positions (main span 280 m), top chord and deck heights.
- St John's Cathedral (`cathedral.py`): nave, aisles with lean-to roofs, transept, buttresses, two towers
  with spires and pinnacles; heights from the LiDAR, plan from the OSM footprint.
- HSW (`hsw.py`): clean buildings of the strip, the riverwalk as a timber deck on steel cantilevers.
- Ground: LiDAR ground smoothed (no cars/noise), rock colour on slopes over 40 deg (the cliffs). Streets now
  cover the whole LiDAR area.
- Trees: clean models (fig, jacaranda/poinciana, eucalypt, palm, generic) on the LiDAR tree tops.
- Spire: 43 PT slabs (L1-L42 + the roof slab at 136 m AHD, John's count); staggered slab edges.
- New: `cam_queen_st_*` (Queen St street level), `*_morning.png` for the bridge, cathedral and two street views.

## Step 6 results

- Floors: 40 storeys above ground (GF + L1-L38 + roof storey), podium L1-L5 as measured, tower 2.9 m
  floor to floor from the L6 transfer; RF (L39) at 138.0 m AHD, inside the LiDAR roof band. The rest of
  John's 43 PT slabs are labelled PLANT, LMR (roof plant) and B1, B2 (basements) - heights assumed.
- Facades: window grids per family from facade UVs (u = metres round, v = metres AHD): curtain wall
  (1.5 m mullions) on glass, punched windows on concrete, brick and stone; floor lines as geometry.
- Spire: white frame posts round every balcony level staggered half a bay on alternate levels (the "net"),
  staggered slab edges, glass balustrades, dark glass line, Ann St lobby glazing under the brick podium.
- HSW: corten lift tower with landings and a link to the cliff top, Mr Percival's (30 x 20 m deck on piles,
  pavilion roof), boardwalk on headstocks and piles. Stage `hsw_2017` (preview pass `hsw`): basement dig
  with shotcrete walls, rock anchors on the cliff, one tower crane, shed E (Felons Barrel Hall) lifted on
  temporary steel, boardwalk headstocks without deck, blue hoarding.
- Light: physical (Nishita) sky, sun ~10 deg up at bearing 80 deg (06:45 AEST, mid-April), AgX.
- Roads: 2.5 % crown, dashed centre / lane lines and edge lines, driveways without footpaths, council bus
  stops (pole + sign, shelters on Ann/Queen St).
- Hotel and Mr Percival's heights fixed: roofs now use building points only (the bridge sits above them).
- Renders: `*_morning.png` (bridge + HSW, cathedral, Ann/Queen corner, Queen St, Spire facade close-up),
  `hsw2017_overview_*`, `hsw2017_dig_*`. Matching photos (John's, not in git) are named in layout.py.
