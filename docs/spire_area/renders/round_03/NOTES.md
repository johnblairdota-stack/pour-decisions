# Spire area, round 03

Builder: PC session, 16 Nov 2026. Fixes from the round 02 critique (score ~25 %). Same cameras as round 02.
The Spire site is unchanged. area_hero self-check: 710 new pieces, none in the keep-out zone, none on a carriageway.

## 16. Floating boxes and the twin spike: what they were
Checked first, in a no-render build listing every object by collection: in the as-built scene the
`logistics` and `site_plant` collections are empty, so **none of them were Spire site parts**.
- The floating boxes (ann_queen_corner, queen_st_streetscape, mantra) were **my round 2 roof plant rooms**,
  placed at a building's LiDAR top where buildings.py draws the roof lower. Fix: a plant room is only placed
  where a downward ray from above hits a drawn building roof within 1.5 m of the expected height (93 buildings).
- The twin spike (flyby, fly_by_east) was a pair of **LiDAR mast cones** from buildings.py (`bldg_spires_masts`)
  standing above a tower whose roof is drawn lower. Fix in area_hero: every mast cone with no surface within 3 m
  under its base is dropped (80 groups, 205 faces). buildings.py itself is unchanged.

## Changed
1. **Car park "navy"**: it was not the material (the car park already used the street's `clay_road`); the shade
   under the trees and the cathedral was lit only by the very blue Nishita sky. The light from the sky is now
   desaturated (World: Hue/Saturation 0.45 between the sky texture and the lighting background; the camera
   still sees the painted sky). Car park lines #D8D6C8.
2. **Dusk aerial**: a strong peach-lilac haze band over the far suburbs and hills (mist strength 0.8, colour
   ~#c9a6ae at display); lit windows come in 1-2 window units (run 1.6 bays), warm tones only.
3. **Neighbour towers**: cream #E4D8BF with balcony doors the full storey height (2.3 m in a 3 m bay, sill 0.06,
   head 0.86), no dot grid. Mantra: 25 balcony slabs (0.95 m out, 0.22 m thick) up the tower; **Mantra's blue fin
   and crest are restored** and pulled flush onto the facade (72 vertices moved to 0.25 m off the footprint);
   only the roof spike is dropped.
4. **Cathedral silhouette**: belfry octagon 2.5 m tall (was 6 m), so the dark slate spires start lower and are
   about 30 % longer to the same LiDAR top (the photo-fit landmark is unchanged); slate base radius 0.45 x tower
   width (was 0.36); pale turret cones half height (3 m, was 6 m); belfry lancets moved onto the square stage.
5-6. **West front / stone**: buff tuff palette only (no lilac): C9A777, B9976E, D2B488, BFA07A, AE8E68; dressings
   warm sandstone (#cbb58c family); leaded glass (lead cames on a 0.3 x 0.45 m grid, dark panes, low roughness).
7. **Light**: sun gain 1.6 (was 1.3), sky fill 0.42 (was 0.55) for darker, crisper shadows; a pale horizon band
   (#DCE6EE); cumulus about twice the size and different in every view (4D noise, W changes per view).
8. **hero_aerial haze**: blue-grey, stronger (0.62, colour lin (0.42, 0.55, 0.76)).
9. **BUS ONLY** turned 180 deg: Ann St is one-way south-west in OSM, so the words now read for a driver in the
   bus lane (they read upside-down from cameras looking north-east, as in reality). Bus lane red #A8433A with wear.
10. **Ground shards** at the Deanery cliff and the Customs House bank: in two boxes, heights more than 0.6 m off
   their 5 x 5 median are replaced, then 7 passes of 3 x 3 smoothing (ground mesh only; ground_z for roads is
   unchanged). **The Deanery**: warm sandstone ashlar walls, darker roof, cream verandah posts.
11. Road patches: wider soft fade (outer 40 %, max 60 % opacity), colour closer to the road.
12. Trees: no cuff ring on fig trunks (the limb stub was wider than the trunk top); whole-tree clearing now also
   takes a neighbour whose crown centre sits inside a removed crown (no bare forks left behind).
13. Foliage warmer (less teal): leaf colours shifted warm, crown shading warmer, far crowns olive.
14. **Street poles**: 291 square street-light / sign poles outside the Spire keep-out zone replaced by round
   tapered galvanised poles at the same spots (davit arms and heads unchanged).
15. Roof greys: wider spread (0.15-0.44) and smaller patches (~22 m).

## Shared files touched (small)
- `cathedral.py`: belfry 2.5 m, slate spire base 0.45, turret cones 3 m, belfry lancets on the square stage.
- `trees.py`: fig limb stub radius 0.26 outside HSW (no cuff), guarded by `in_hsw`.
- area_hero changes existing objects only outside the keep-out zone: `street_poles` (square poles out),
  `bldg_spires_masts` (floating cones out), the ground mesh in two boxes, `bldg_look_568836537_*` (Mantra).

## Not done / still rough
- **Orient Hotel verandah + HOTEL ORIENT lettering, and the bare tree at the Orient corner: not done on purpose.**
  The Orient's footprint touches the Spire lot, so it is inside the keep-out zone (lot + 9.5 m); area_hero must
  not add anything there. Needs a decision from John / the cloud thread (allow an exception for the Orient's own
  facade, or leave it).
- Signals on round galvanised poles with mast arms, ped lanterns and push buttons; turn arrows, hatched median
  noses and zebras at Ann/Queen: not this round (most of Ann/Queen is also inside the keep-out strip).
- The 3 badly fitting photo cameras: no new landmarks yet.
- Blank brick facades: not found in this round's views; needs a named view.
- River colour (HSW thread's material).
- The west front gable is still a plain tan triangle (no tracery in the gable, no receding orders depth).
- The Deanery cliff faces still read pale (fewer shards, but the steep real cliff keeps the pale ground colour).
