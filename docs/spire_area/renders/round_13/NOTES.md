# Spire area, round 13 (cloud, Cycles)

Builder: cloud session, 17 Nov 2026. Same renderer as rounds 7-12 (bpy 4.5). Rendered in two halves (showcase + pairs,
then heroes + commons) to stay under the cloud memory limit.

## Fixes (round 12 critique)
1. **Mantra roof void**: ray probe showed the black patch on the 110.6 m roof plate. Mantra's two OSM outlines each
   brought a roof plate at the same height, plus downward-facing rooftop box bottoms coplanar with it; Cycles shaded
   the back faces black. One plate kept (the larger outline), every downward face above the roof line dropped.
2. **Mantra flag**: now bisects the SE corner (45 deg, east + south) so it reads as a broad sheet from the NE and S
   cameras as well; top 0.8 m above the roof line, no longer towering over it; deeper blue #1A6CC0 (photo #1E78C8).
3. **Asphalt**: street asphalt roughly halved in albedo (ramp 0.026-0.058 linear).
4. **ann_queen_corner sky**: stops #e8e4e0 at the horizon to #c8d4e4 higher up, fewer clouds, 30 % brighter.
5. **Cathedral**: dressings and pinnacles #d2c9b4 (about 30 % less yellow); spires get staggered slate courses with
   dark joints and bump (a brick pattern, not true rounded fish scales). Ashlar courses already use a random
   per-course offset, so no change there.
6. **Foliage**: frustum_kill boxes added for ann_st_far (sky scraps, two bare trunks, longer reach), cathedral_grounds,
   customs_house and cathedral_from_carpark. The cathedral_forecourt box is gone (it left a bald gap); no canopy
   added back yet.

## Not done yet
Gable shell lilac (needs a probe for its material); forecourt canopy replacement; porch gap; Admiralty copies;
QUEEN ST sign; BUS ONLY; wheel stops; Mantra stepped crown; Orient verandah; Ann St road patch; arrows/hatching;
camera fits; Deanery cliff; keep-out trees (by rule).
