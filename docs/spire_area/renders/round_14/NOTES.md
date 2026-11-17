# Spire area, round 14 (cloud, Cycles)

Builder: cloud session, 17 Nov 2026. Same renderer (bpy 4.5), rendered in two halves.

## Fixes (round 13 critique)
1. **Mantra flag**: 5.5 m out at the roof, concave edge running back to the corner over ~30 m (10 floors), top 1.5 m
   above the roof plate (parapet line); still bisecting the SE corner; colour #2e8fd6. The "blue shard" at the left
   edge of cathedral_forecourt is this flag seen far off (probe: area_mantra_blue_fin at 110 m), not a copy.
2. **Street asphalt**: probe showed streets and the car park share one material; halving the albedo only moved
   sunlit streets #7b -> #6c, the rest was grazing-angle specular sheen of the sky. Streets now matt (specular 0.12,
   roughness 0.97) and darker (0.013-0.030 linear): queen_st_streetscape test #52504d (r13 #7b7772). The car park
   gets its own copy of the material at the r13 values.
3. **Fig**: the r13 ann_st_far frustum boxes took the real fig on Ann St; they are gone. The bare debris trunk
   (probe: tree_trunks at 103.5, 171.8) is a named kill.
4. **Skies**: ann_queen_corner stops measured from its photo (#b1bdd3 low -> #798dae top; the critic's target was
   paler than the photo, the photo won). Less cloud on deep / navy daylight skies.
5. **Cathedral**: dressings #d6c296; spire slates back to #2e2e33 / #323237 with the joints kept; leaded glass
   #1b222c / #232c38 at roughness 0.1.
6. **Foliage**: customs_house plates are tree_crowns_far lumps ~120 m out (probe): frustum box with 200 m reach;
   customs_house_river and annstcath boxes added.

## Not done yet
Lilac gable shell; forecourt canopy; porch gap; Admiralty copies; QUEEN ST sign; BUS ONLY; wheel stops; Mantra stepped
crown; Orient verandah; Ann St road patch; arrows/hatching; camera fits; Deanery cliff.
