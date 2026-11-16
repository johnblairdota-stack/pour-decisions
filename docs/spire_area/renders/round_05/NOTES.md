# Spire area, round 05 (structural)

Builder: PC session, 16 Nov 2026. Shapes only, no global colour or light pass; the two pinned items (sky values,
Mantra body #e8dcc0) and the cathedral stone step are the only colour changes. Every fix was checked with the
critic's crop box, before (round 04) and after (round 05), listed at the end. The Spire site and the keep-out zone
are unchanged. area_hero self-check: 751 new pieces, none in the keep-out zone, none on a carriageway.

## 1. Mantra stripe
Found the right face by projecting Mantra's tower outline (OSM 189779738 top tier) into spire_ann_st_2018,
ann_queen_corner and fly_by_east with their solved cameras: the left edge of Mantra in the first two (and the right
edge of the face in fly_by_east) is the south-east corner; the face those cameras see is the **east face** that ends
at that corner. The first try of this round put the stripe on the south face (invisible from the north-east);
after the crop check it moved to the east face. Now: a 3 m blue #1F7BD0 stripe on the east face from the SE corner
(14.5, 70.0), from the podium roof (38.8 m AHD) to the tower roof, 0.05 m proud of the balcony slab edges, flaring
out at the top into the crest (6 m radius sweep), white stacked "mantra" sign. All free-standing blue blades are
gone (the r4 crest stood on a face no camera sees). Body cream #E8DCC0 (pinned).

## 2. Floating leaves
New build checks in area_hero (counts printed every build):
- every leaf crown (foliage.CLOUDS) must have trunk / branch wood within 0.5 m of its volume, else its leaf cards go
  (62 orphan crowns this build);
- no tree inside a building: a crown whose centre is > 1 m inside a footprint of a building >= 5 m tall and below its
  roof loses leaves and trunk (457 trees: LiDAR tree points inside footprints);
- leaf cards inside any building volume go (the Deanery "tree in the wall");
- low leaf cards: over a carriageway (< 2.5 m up), or any tree leaf card < 2 m above the ground (the sparse shrub
  clouds that read as floating discs at the Customs House).
The ghost leaf wall in spire_ann_st_2018 is thinned (r4) and checked again by crop.

## 3. Road patches
The patch and crack-seal meshes (stair-step edges in ann_st_streetscape and queen_st_streetscape) are no longer
built: plain asphalt. Manholes, side-entry pits and the gutter strip stay.

## 4. BUS ONLY
Checked by crop in hero_annstcath and hero_church_house_webber: Ann St is one-way south-west in OSM (ways
106866225 and 1469956583 are drawn north-east -> south-west with oneway=yes), and the words read upright for a
driver in the bus lane heading south-west, so they read upside-down from cameras looking north-east. That is
correct; not changed.

## 5. Cathedral shape
- Aisle buttresses: three stepped stone stages (were cream sandstone slabs) with a sloping sandstone weathering
  at each set-off; west tower angle buttresses in stone with a sandstone cap at each set-off.
- Corner turrets: slender octagonal pinnacles (0.85 m octagon shafts, 4.5 m octagonal spirelets), not round drums.
- Stone: the r04 hue family moved half a step toward the 2010 photo: 5 wall samples from cathedral_west_front_2010
  average #AE9378 against the r04 mean #998D89; each r04 colour + (10, 3, -8):
  #978888, #A48E78, #B09E8D, #9E8A76, #AA9482. Dressings unchanged.

## 6. Pinned sky
- Day: r03's clean blue gradient with r04's heaped cumulus, but less cover (threshold 0.53, not 0.47) so the sky is
  not a milky veil; aerial day haze 0.45 (was 0.62).
- Dusk: fog #7A86A8, horizon band peach #E8A890 under lilac #9C7CA8, far ridge #5B6E8C (a low ridge ring 3 km out,
  emission-only, so the far field ends in hills, not an olive carpet). Do not change these again.

## 7-8. Not done this round
- Tree crowns, Willahra / Marriott dome, Customs House / Deanery massing: not this round.
- Landmarks for the 3 badly fitting cameras: not this round.

## Blocked
- **Orient Hotel / Ann-Queen exception**: the self-check change needed for it (a named exception list) was blocked
  on the PC because the OK reached this session second-hand (relayed), not from John directly. Not worked around.
  It needs John's own OK in the thread; the code for the verandah + lettering is ready to add then.

## Shared files touched (small)
- `cathedral.py`: `weather()` helper, aisle buttresses in stone with sloped weatherings, tower angle buttresses in
  stone with set-off caps, slender octagonal corner pinnacles (replaces r04's round drums).

## Render notes
Two NVIDIA driver faults this round (EXIT 11; one an out-of-memory while another Blender ran); the render was
re-run until all 36 images were made.

## Crops (before = round_04, after = round_05; files in crops/, full size on the PC in spire_area_work\crops_r05)
- mantra_spire_ann_st_2018 (spire_ann_st_2018_render.png, box [850, 100, 350, 1100]): crops/mantra_spire_ann_st_2018_before.jpg -> crops/mantra_spire_ann_st_2018_after.jpg
- mantra_ann_queen_corner (ann_queen_corner_render.png, box [650, 200, 417, 900]): crops/mantra_ann_queen_corner_before.jpg -> crops/mantra_ann_queen_corner_after.jpg
- mantra_fly_by_east (fly_by_east_render.png, box [700, 0, 600, 755]): crops/mantra_fly_by_east_before.jpg -> crops/mantra_fly_by_east_after.jpg
- leaves_willahra_admiralty (hero_willahra_admiralty.png, box [655, 740, 90, 45]): crops/leaves_willahra_admiralty_before.jpg -> crops/leaves_willahra_admiralty_after.jpg
- leaves_customs_house_a (hero_customs_house.png, box [1230, 480, 160, 70]): crops/leaves_customs_house_a_before.jpg -> crops/leaves_customs_house_a_after.jpg
- leaves_customs_house_b (hero_customs_house.png, box [1090, 640, 510, 350]): crops/leaves_customs_house_b_before.jpg -> crops/leaves_customs_house_b_after.jpg
- leaves_cathedral_from_carpark_a (hero_cathedral_from_carpark.png, box [720, 340, 300, 440]): crops/leaves_cathedral_from_carpark_a_before.jpg -> crops/leaves_cathedral_from_carpark_a_after.jpg
- leaves_cathedral_from_carpark_b (hero_cathedral_from_carpark.png, box [150, 740, 560, 220]): crops/leaves_cathedral_from_carpark_b_before.jpg -> crops/leaves_cathedral_from_carpark_b_after.jpg
- leaves_queen_st_streetscape (hero_queen_st_streetscape.png, box [180, 580, 350, 110]): crops/leaves_queen_st_streetscape_before.jpg -> crops/leaves_queen_st_streetscape_after.jpg
- leaves_deanery_tree_in_wall (hero_deanery.png, box [940, 470, 100, 110]): crops/leaves_deanery_tree_in_wall_before.jpg -> crops/leaves_deanery_tree_in_wall_after.jpg
- leaves_spire_ann_st_2018 (spire_ann_st_2018_render.png, box [0, 0, 1200, 1600]): crops/leaves_spire_ann_st_2018_before.jpg -> crops/leaves_spire_ann_st_2018_after.jpg
- leaves_cathedral_ann_st_2012 (cathedral_ann_st_2012_render.png, box [0, 0, 1200, 1600]): crops/leaves_cathedral_ann_st_2012_before.jpg -> crops/leaves_cathedral_ann_st_2012_after.jpg
- patches_ann_st_streetscape (hero_ann_st_streetscape.png, box [790, 560, 230, 440]): crops/patches_ann_st_streetscape_before.jpg -> crops/patches_ann_st_streetscape_after.jpg
- patches_queen_st_streetscape (hero_queen_st_streetscape.png, box [0, 590, 1500, 170]): crops/patches_queen_st_streetscape_before.jpg -> crops/patches_queen_st_streetscape_after.jpg
- bus_only_annstcath (hero_annstcath.png, box [600, 650, 700, 350]): crops/bus_only_annstcath_before.jpg -> crops/bus_only_annstcath_after.jpg
- bus_only_church_house_webber (hero_church_house_webber.png, box [0, 650, 900, 350]): crops/bus_only_church_house_webber_before.jpg -> crops/bus_only_church_house_webber_after.jpg
- cathedral_westfront (hero_westfront.png, box [100, 150, 867, 1250]): crops/cathedral_westfront_before.jpg -> crops/cathedral_westfront_after.jpg
- cathedral_west_front_2010 (cathedral_west_front_2010_render.png, box [0, 0, 1600, 1200]): crops/cathedral_west_front_2010_before.jpg -> crops/cathedral_west_front_2010_after.jpg
- sky_hero_aerial (hero_aerial.png, box [0, 0, 1600, 500]): crops/sky_hero_aerial_before.jpg -> crops/sky_hero_aerial_after.jpg
- sky_cathedral_grounds (hero_cathedral_grounds.png, box [0, 0, 1600, 500]): crops/sky_cathedral_grounds_before.jpg -> crops/sky_cathedral_grounds_after.jpg
- dusk_aerial_ne_dusk (aerial_ne_dusk_render.png, box [0, 0, 1600, 1200]): crops/dusk_aerial_ne_dusk_before.jpg -> crops/dusk_aerial_ne_dusk_after.jpg

Crop results (after vs before): Mantra stripe now visible on the left edge in spire_ann_st_2018 and ann_queen_corner
and on the face edge in fly_by_east; Customs House leaf discs gone; road patches gone; buttresses and pinnacles
changed; BUS ONLY unchanged (correct). Still there: the leaf clump in willahra_admiralty (655,740) (a high crown that
has wood under it, so the check keeps it) and the Deanery tree just in front of the wall (940,470): next round.
