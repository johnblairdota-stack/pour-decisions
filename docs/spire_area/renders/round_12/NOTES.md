# Spire area, round 12 (cloud, Cycles)

Builder: cloud session, 16-17 Nov 2026. Same renderer as rounds 7-11 (bpy 4.5). The full run hit the cloud memory
limit after 33 of 36 images; crane_from_nw, crane_from_south and hero_crane were re-rendered from the same commit.

## Fixes (round 11 critique)
1. **Mantra crest**: the flag is about twice as wide (11 m out from the SE corner at roof height), raised 3 m so its
   top sits above the roof line, with a concave lower edge running 13 m down the corner.
2. **Mantra roof**: a cap prism closes the hole over the top tiers (crane_from_nw).
3. **Mantra sign**: bolder letters (2.9 m), the cream band lowered to sit on the top floor.
4. **Cathedral**: about 30% of the ashlar blocks are grey-mauve tuff (#8a8088) while the mean stays golden-tan;
   dressings pale cream #d8c8a0; crossing roof slate.
5. **Foliage**: new `frustum_kill`: tree faces projected into each critic box's camera (within 70 m, outside the
   keep-out zone) are dropped, so sparse crowns can no longer slip past the ray casts through alpha holes.
6. **Sky / road**: ann_queen_corner gets a paler dusk; asphalt darkened.

## Not done yet
Gable shell over the arch; porch gap; Admiralty copies; QUEEN ST sign; BUS ONLY; wheel stops; Mantra stepped crown;
Orient verandah band; Ann St road patch; arrows/hatching; car park asphalt; camera fits; Deanery cliff; keep-out trees.
