# Spire area, round 06 (structural + the Orient / Ann-Queen exception)

Builder: PC session, 16 Nov 2026. Merged HSW r8 (dbdfc80), r9 (f3fb8a8) and r10 (5e83020) before the renders.
Shapes only, no global colour or stone move. Each fix was found by ray-casting the critics' pixels in a no-render
build, then checked by a before (round 05) / after (round 06) crop (list at the end).

## Keep-out exception (John, in the project thread, 16 Nov 03:00 UTC)
"Yes, PC may add the Orient and Ann/Queen exception to the Spire area build, render only." Implemented as a named
list `AREA_ZONE_EXCEPTIONS = {"orient", "annqueen_signals"}` in area_hero.py. The self-check still fails any other
new piece in the keep-out zone, and fails any excepted piece on the Spire lot, within 1 m of the lot line, or within
1 m of any Spire site object (collections spire / core / logistics / site_plant: hoarding, gate, gantry, truck bay,
crane, booms, hoist, sheds). area_hero still does nothing for the game export (game_l6). No gameplay file changed.
This round's counts: orient 12 pieces, annqueen_signals 7 pieces in the zone.
- **Orient Hotel**: two-level verandah on its two street fronts (19 cast-iron posts on the footpath, never on the
  road, at least 3 m from the lot), upper deck with a white lace balustrade, corrugated awning roof; HOTEL ORIENT
  lettering on the longest street front.
- **Ann/Queen**: the square signal / light poles inside the zone (more than 1.5 m from the lot) are now round tapered
  galvanised poles like the rest of the area. No new markings in the zone (none under the work zone).

## Fixes
1. **spire_ann_st_2018** (camera 290 m from the site): every tree within 30 m in front of the camera is removed,
   except the right-hand side (the fig in the photo). Crop: open street, brick left, fig right.
2. **Tree pairing** on a 1 m grid (outside HSW): trunks with no leaves within 2 m (0 this build) and far-crown blobs
   with no trunk within 12 m (608 faces) dropped; named ghost crowns from the critics' pixels dropped: the Willahra
   "lens" (a jacaranda at 71.5, -69) and the far crown at the Customs House (-78, -326); plus leaf cards within 2.5 m
   of the camera ray through the Willahra pixel (655,740).
3. **Two-tone roads**: rays show both tones are the same `roads` object and `clay_road` material. Two causes:
   (a) overlapping crowned ribbons of different OSM ways tilt different ways: every road face now shades with an up
   normal (custom normals, no geometry change); (b) the stair-step edge in ann_st_streetscape is a building
   **shadow** with shadow-map steps: sun shadow filter radius 2.5 and max resolution 0.006 m (shadow quality only).
4. **Mantra**: the photos do not fit one corner. spire_ann_st_2018 and ann_queen_corner show the blue running down
   the left silhouette from the crest (SE corner); fly_by_east shows a second blue band ~80 % across the north face
   and the horizontal "mantra" sign. Now: a 2.6 m azure #1E8FD0 stripe on the east face at the SE corner with a wedge
   crest (widens to 6.6 m and leans 3.2 m out over 9 m), a second stripe on the north face at (3.6, 97.5), and a
   horizontal white "mantra" sign at the top of the north face.
5. **BUS ONLY** (camera heading vs Ann St's one-way direction, SW ~225 deg, OSM ways 106866225 / 1469956583):
   | camera | heading | vs traffic | before (r05) | now |
   |---|---|---|---|---|
   | annqueen (street_ann_queen) | 215 | along | upside-down | upright |
   | annstcath (street_ann_cathedral) | 229 | along | upside-down | upright |
   | church_house_webber | 188 | along (37 deg off) | upside-down | upright |
   | carpark_raised | 239 | along | upside-down | upright |
   | cathedral_grounds | 132 | across (93 deg) | sideways | sideways |
   The round 3 flip was wrong (in r03 I took annstcath as looking north-east; it looks south-west). Undone:
   streetscape.py's orientation was right. Words stay flat and lifted.
6. **The Deanery**: its verandah posts / rails (the "scaffolding") removed: a plain sandstone house. The aerial
   "yellow light shafts" at (310-390, 250-330): rays hit `far_land` (ground.py skirt) about 1 km south; no steep
   faces there to drop, and after the HSW r9 river / far-roof fix the crop shows no shafts.
7. **Cathedral west face**: a big recessed pointed arch in three orders framing the west window and the portal;
   corner pinnacles in golden sandstone (the dressing material, local only). No global stone change.
8. Camera landmarks for the 3 bad fits: not this round.

## Shared files touched (small)
- `cathedral.py`: recessed west arch (3 arch orders), corner pinnacles in the sandstone material.

## Still rough
- The white cliff faces in the Deanery foreground.
- Signals: no mast arms or new lanterns yet (only round poles); no new Ann/Queen markings.
- The 3 badly fitting photo cameras.

## Crops (before = round_05, after = round_06; files in crops/, full size on the PC in spire_area_work\crops_r06)
- s2018_avenue (spire_ann_st_2018_render.png, box [0, 0, 1200, 1600]): crops/s2018_avenue_before.jpg -> crops/s2018_avenue_after.jpg
- ghost_willahra_lens (hero_willahra_admiralty.png, box [655, 740, 90, 45]): crops/ghost_willahra_lens_before.jpg -> crops/ghost_willahra_lens_after.jpg
- ghost_customs_house (hero_customs_house.png, box [1230, 480, 160, 50]): crops/ghost_customs_house_before.jpg -> crops/ghost_customs_house_after.jpg
- ghost_cathedral_ann_st_2012 (cathedral_ann_st_2012_render.png, box [0, 0, 1200, 1600]): crops/ghost_cathedral_ann_st_2012_before.jpg -> crops/ghost_cathedral_ann_st_2012_after.jpg
- ghost_ann_st_far (ann_st_far_render.png, box [0, 0, 1316, 1600]): crops/ghost_ann_st_far_before.jpg -> crops/ghost_ann_st_far_after.jpg
- ghost_cathedral_grounds (hero_cathedral_grounds.png, box [0, 0, 1600, 1000]): crops/ghost_cathedral_grounds_before.jpg -> crops/ghost_cathedral_grounds_after.jpg
- ghost_cathedral_from_carpark (hero_cathedral_from_carpark.png, box [0, 0, 1600, 1000]): crops/ghost_cathedral_from_carpark_before.jpg -> crops/ghost_cathedral_from_carpark_after.jpg
- road_ann_st_streetscape (hero_ann_st_streetscape.png, box [780, 560, 320, 440]): crops/road_ann_st_streetscape_before.jpg -> crops/road_ann_st_streetscape_after.jpg
- road_queen_st_streetscape (hero_queen_st_streetscape.png, box [520, 560, 980, 200]): crops/road_queen_st_streetscape_before.jpg -> crops/road_queen_st_streetscape_after.jpg
- road_willahra_admiralty (hero_willahra_admiralty.png, box [690, 690, 810, 70]): crops/road_willahra_admiralty_before.jpg -> crops/road_willahra_admiralty_after.jpg
- road_orient_front (orient_front_render.png, box [0, 0, 1205, 1600]): crops/road_orient_front_before.jpg -> crops/road_orient_front_after.jpg
- road_hero_orient_hotel (hero_orient_hotel.png, box [0, 0, 1600, 1000]): crops/road_hero_orient_hotel_before.jpg -> crops/road_hero_orient_hotel_after.jpg
- mantra_spire_ann_st_2018 (spire_ann_st_2018_render.png, box [850, 100, 350, 1100]): crops/mantra_spire_ann_st_2018_before.jpg -> crops/mantra_spire_ann_st_2018_after.jpg
- mantra_ann_queen_corner (ann_queen_corner_render.png, box [650, 200, 417, 900]): crops/mantra_ann_queen_corner_before.jpg -> crops/mantra_ann_queen_corner_after.jpg
- mantra_fly_by_east (fly_by_east_render.png, box [700, 0, 600, 755]): crops/mantra_fly_by_east_before.jpg -> crops/mantra_fly_by_east_after.jpg
- bus_only_annqueen (hero_annqueen.png, box [600, 550, 1000, 450]): crops/bus_only_annqueen_before.jpg -> crops/bus_only_annqueen_after.jpg
- bus_only_annstcath (hero_annstcath.png, box [600, 650, 700, 350]): crops/bus_only_annstcath_before.jpg -> crops/bus_only_annstcath_after.jpg
- bus_only_church_house_webber (hero_church_house_webber.png, box [0, 650, 900, 350]): crops/bus_only_church_house_webber_before.jpg -> crops/bus_only_church_house_webber_after.jpg
- bus_only_cathedral_grounds (hero_cathedral_grounds.png, box [0, 550, 1600, 450]): crops/bus_only_cathedral_grounds_before.jpg -> crops/bus_only_cathedral_grounds_after.jpg
- bus_only_carpark_raised (hero_carpark_raised.png, box [0, 0, 1600, 600]): crops/bus_only_carpark_raised_before.jpg -> crops/bus_only_carpark_raised_after.jpg
- deanery (hero_deanery.png, box [0, 0, 1600, 1000]): crops/deanery_before.jpg -> crops/deanery_after.jpg
- shafts_aerial_ne_dusk (aerial_ne_dusk_render.png, box [230, 170, 240, 240]): crops/shafts_aerial_ne_dusk_before.jpg -> crops/shafts_aerial_ne_dusk_after.jpg
- shafts_hero_aerial (hero_aerial.png, box [230, 170, 240, 240]): crops/shafts_hero_aerial_before.jpg -> crops/shafts_hero_aerial_after.jpg
- cathedral_westfront (hero_westfront.png, box [100, 150, 867, 1250]): crops/cathedral_westfront_before.jpg -> crops/cathedral_westfront_after.jpg
- cathedral_west_front_2010 (cathedral_west_front_2010_render.png, box [0, 0, 1600, 1200]): crops/cathedral_west_front_2010_before.jpg -> crops/cathedral_west_front_2010_after.jpg

Crop results: s2018 avenue open (fig kept); Mantra stripe + crest + horizontal sign match fly_by_east, stripe still
on the left edge in spire_ann_st_2018 / ann_queen_corner; BUS ONLY upright in annqueen and annstcath; Orient
verandah + lace balustrade visible in hero_orient_hotel; Willahra lens gone (a few cards left); recessed west arch
and golden pinnacles in hero_westfront. Not fixed: the stair-step shadow edge in ann_st_streetscape stays after the
softer shadow filter, so its steps come from the casting building's stepped outline (a buildings.py footprint), not
from shadow-map aliasing; and the Customs House view still has a lumpy far-crown blob (a different crown from the
named one, inside the 12 m trunk window).
