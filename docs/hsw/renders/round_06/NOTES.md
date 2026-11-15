# HSW + Story Bridge, round 6 (16 Nov 2026)

Renders only (photos stay in PourDecisions-sites, never in git). Stage: AS BUILT, day light, no people, cars or boats.
Work list: the critic's shape fixes on round 5. Numbers are in `layout.HSW` and `layout.STORY_BRIDGE`.
Shared PC: every Blender run took `PourDecisions-sites/blender.lock` ("HSW render thread"), one GPU render at a time.

## How to run (John's PC, Blender 4.5)

    blender -b --factory-startup -P tools/hsw/render_hsw.py -- <out_dir> heroes photos only=<ids> [scale=0.5]
    <blender python> -I tools/hsw/hsw_fit.py [ids]
    <blender python> -I tools/hsw/export_round.py <sites> <render_dir> 6 <pair ids> <hero ids>

## The big one: the bridge was in the wrong place
The four tower peaks in the 2019 LiDAR surface (all at ~80.5 m AHD) put the north pier centre at x 481, y 66 and
the south at x 488, y -215. The model had the bridge axis tilted the other way and the north pier ~9 m east and
~6 m north. `STORY_BRIDGE` centre/axis now come from those peaks. Everything that hung off the bridge got better:

| id | rms r5 | rms r6 | holdout r6 |
|---|---|---|---|
| p01_drone_se | 23.7 | 21.3 | 69.9 |
| p04_drone_dusk_se | 28.6 | 26.1 | 111 (still not reliable) |
| p06_drone_south | 10.6 | 6.5 | 28.6 |
| p07_drone_sw_citycat | 21.3 | 15.7 | 31.4 (lens held at 42 mm: the free solve ran off to a 14 mm lens) |
| p09_pier_face_on | 10.3 | 11.3 | 15.4 (now on the bridge line, heading 0 deg, as the photo) |
| p10_drone_lawns_se | 7.8 | 3.9 | 15.4 |
| p12_river_felons | 8.2 | 7.4 | 11.9 |
| p13_kp_bank_ferry | 18.9 | 24.9 | 34.1 (tower apex marks added; apex error ~25 px, was ~85) |

p09 is now solved with the camera held on the bridge centre line (hsw_fit no longer shifts a strong position prior).
photo_fit.py: a photo with "f35_fixed" now also holds the lens in the solve (strong focal prior).

## Changed this round
1. Pier arch: 13 m wide (43 % of the face), round-headed, crown 8.2 m under the pier top (p09); thin archivolt
   ring on both faces; nothing inside the arch; a glazed, mullioned wall of the HSW buildings 16 m behind it.
   Corner pilasters and cornice kept; bearings on the pier tops.
2. Hotel: vertical 2.4 m columns of offset parallelogram panels (white, light grey, charcoal) leaning in alternate
   directions, every 4th column a dark glass bay; terrace and rooftop planting; the jacaranda on the SW corner;
   no trees in front of or beside the hotel. Oakwood apartments: balcony slabs on every floor over dark recesses.
3. Felons east end: the gap between Felons and Barrel Hall (x 578-606) is an open dining deck on piles with
   umbrellas and a railing. NOTE: photos p09 and p12 are November 2019, before Felons Barrel Hall opened (2021),
   so Barrel Hall is not in them; the model is as built today. Rays through the Felons east end in p12/p13 land at
   x 605-620 while OSM and the LiDAR gable both end Felons at x 576: left as mapped, flagged here.
4. Wharf: chunky piles (0.55-0.68 m) about 2.2 m apart with horizontal walers and bracing; pale blue-grey roofs;
   no trees on the strip in front of the FELONS / HSW roofs; Mr Percival's larger (r 8.6 m) under a grey roof.
5. Bridge lattice: slimmer top chord with a handrail line, thinner diagonals, flat gusset plates; underside with thin
   cross-girders every 3.5 m and thin stringers (the thick tilted planks are gone).
6. Leaf-card trees now reach 380 m round HSW (no low-poly crowns in the p13 foreground). Lone LiDAR spikes left
   standing in the river after the mud-flat sink are pulled under too.

## Edits to shared files (please tell the Spire area thread)
- `trees.py`: HSW-only tree rules (no trees on the wharf strip x 400-612, y < 95, or round the hotel).
- `ground.py`: lone river spikes sink (only when not in a construction stage); far land / suburb colours.
- `layout.STORY_BRIDGE` centre_xy and axis changed (affects every view of the bridge, Spire scene included).
- No change to streets.py, preview.py or looks.py this round.

## Still missing
- Felons east end vs the 2019 photos (see 3); lift/Felons marks still left out of p12/p13.
- Canopy crown variety, cliff ledges and fracture lines, far suburb street trees, mangrove shoreline, Rivershed.
