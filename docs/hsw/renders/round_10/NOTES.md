# HSW + Story Bridge, round 10 (16 Nov 2026)

Renders only (photos stay in PourDecisions-sites, never in git). Stage: AS BUILT, day light, no people, cars or boats.
Work list: the critic's four asset jobs (round 9 rated ~43 %). Every Blender run held `blender.lock`
("HSW render thread"), waited for a free GPU, and only deleted a lock that still had that name.

## How to run (John's PC, Blender 4.5)

    blender -b --factory-startup -P tools/hsw/render_hsw.py -- <out_dir> heroes photos only=<ids> [scale=0.5]
    <blender python> -I tools/hsw/export_round.py <sites> <render_dir> 10 <pair ids> <hero ids>

## 2. Cream blocks: why they never showed (measured through the solved p12 camera)
Camera p12: (516.4, -84.0, 2.5), heading 6.6 deg, 29.6 mm (35 mm equiv), fit 7.0 px.
- Every crest building from the footprint data (OSM + buildings_clean) projects with its roof at 42-52 % down
  the frame, while the cliff crest line projects at 38-44 %. So all of them sat BEHIND the crest, hidden.
- Their LiDAR heights are right (DSM 90th percentile within each footprint is within 0-5 m of the clean tops).
- The raw 2019 LiDAR surface along the same sight lines tops out at 58-65 m AHD (class 3 = building) at
  x 530-600, y 180-200, projecting at 35-36 % down the frame, above the crest. **No OSM or clean footprint covers
  those cells.** The cream apartment row above Felons was simply missing from the footprint data.
- LiDAR building cells (DSM - ground > 8 m) in x 430-800, y 95-340 not covered by any footprint: 6,749 m2 in
  6 blocks. The largest: x 516-656, y 162-228, roof 65 m AHD, ground 26 m (about 13 storeys over the crest).
- Fix: `hsw_hero.lidar_blocks` builds these from the LiDAR cells on a 4 m tile grid, each tile to its own
  90th-percentile DSM height, cream walls with window bands, a balcony slab and dark rail every 3 m on the outside
  faces (`layout.HSW["lidar_blocks"]`, source noted there). LiDAR used only to measure position and height.
- Result in p12: the new roofline sits at about 33-36 % down the frame, 6-9 % of frame height above the canopy
  (the critic read the photo at ~27 %, ~10 % above the canopy).
- Crest blocks from footprints are now one block per building (largest tier) instead of tiered cakes.

## 1, 3, 4 and extras
1. Hill canopy: fewer, larger crowns (every 10 m, radius 8-13 m), each three overlapping lobes; 40 % lime
   (#8fb43a-#b5c94a), the rest a brighter mid-green; lime-lit tops; tree species round HSW now mostly fig and
   poinciana (pale eucalypt trunks 25 % -> 6 %).
3. Cliff: tall Voronoi cells (vertical fractures) instead of crazy paving, large horizontal strata bands with dark
   ledge lines, stronger value range; the round-9 dark joints and wet streaks stay.
4. Bridge steel one step (~30 %) darker, slight green-grey (0.135, 0.145, 0.14); diagonal bracing between the
   underside cross-girders.
6. Water olive-yellow-green in the near field.
7. Shed roofs pale galvanised grey instead of white.

## Edits to shared files (please tell the Spire area thread)
- `layout.py`: `HSW["lidar_blocks"]`, `HSW["trees"]["mix"]`, `HSW["bridge_steel"]` (the bridge is darker in the
  Spire scene too).
- `landmarks.py` (HSW-owned): underside diagonal bracing.
- No change to streets.py, trees.py, ground.py, preview.py or looks.py.

## Photo fits (rms / holdout px), unchanged (no landmark moved)
p01 12.3 / 27.5, p04 26.5 / 64.4, p06 6.5 / 28.6, p07 15.7 / 31.4, p09 11.3 / 15.4, p10 3.9 / 15.4,
p12 7.0 / 20.0, p13 26.8 / 45.0.

## Still missing
- The LiDAR blocks are stepped (4 m tiles) from the air; they should get simplified outlines.
- Far field tree-covered suburb; Fiume base and back wall; tables and lawn texture; Rivershed awning size.
