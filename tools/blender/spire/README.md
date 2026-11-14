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
- `cam_flyby_crane_clay.png`: from the SW fly-by photo during the build, crane shown.

## Step 2 results (docs/spire/)

- `site_clay_over_2018.png`: finished tower plate over the 2018 aerial (roof with the pool) - placement check.
- `spire_slabs_pours.png`: storeys hidden, 88 slab pours + core; pour joint seen end-on, L6 transfer in orange.
- The street views now show the rounded tower on its podium.

## Known gaps (next steps)

- Floor heights are solved from the OSM height (typical 2.88 m floor to floor - low). Need a real section.
- The plate scale is fitted to the 2018 roof (25.5 px/m), not the drawing's scale bar (21.8 px/m).
- Pour joint position is a guess (straight across the short axis through the core).
- Podium is a plain prism of the lot; the sloped brick face and the podium setbacks are not modelled.
- 223 of 325 buildings have no height in OSM (12 m guess). Heights from LiDAR next.
- Footpath width is a default (3.5 m), not measured. Kerb lines can come from council parking lines.
- Hoist position is a low-confidence read; ask John.
