# Spire area, round 08 (cloud, Cycles)

Builder: cloud session, 16 Nov 2026. Merged HSW r11 (ba0459b) first. Same renderer as round 7 (Cycles, 32 samples,
`tools/spire_area/cloud_render.py`). Every tree fix was found by ray-casting the critics' boxes in the round 7 cameras
(object + hit point per box), and re-probed after a 12-view test render.

## Fixes (round 7 critique)
1. **Mantra**: the SE corner line runs the full height, 0.9 m wide, flush on the tower corner (ann_queen_corner photo).
   The crest wedge at that corner is bigger (14 m, leans 4.5 m out; fly_by_east photo: big wedge top-left). The
   "mantra" sign moved to the top of the NE face that looks at the fly_by_east camera, 3 m letters. Body a step warmer.
2. **Trees** (`round8_trees` in area_hero.py):
   - 25 named trees removed whole, each traced from a critic box: the crown the car park eye camera stood in, the
     near crown, the V and the dots in cathedral_ann_st_2012, the bare forks and dots in spire_ann_st_2018, the
     Deanery eucalypts, the car park V by the chancel, the river-edge trees and tall bare trunks at the Customs
     House, the far blob at the Customs House, the west-front speckle, the Willahra fork.
   - Build check: every trunk piece needs a crown (40+ leaf cards within max(2.5 m, half its height) of its top).
   - Build check: trunks standing below 1.2 m AHD (in the river) go.
   - Build check: leaf cards with no trunk within 10 m go.
3. **Sky per photo** (area_cams.json "sky"): deep clear blue for fly_by_east / spire_ann_st_2018 / the fly-by hero,
   pale grey-blue for ann_queen_corner and orient_front.
4. **Orient**: crenellated parapet removed; dark cornice and a hipped corrugated roof (#4A4C4E) over the whole
   footprint including the curved corner; deeper first-floor hood; warmer tan walls (D2B98A).
5. **Cathedral**: gable coping now slim wall stone instead of a proud cream ribbon; small pinnacle at the apex, no
   cross; window glass dark blue-grey (#1b222c), not brown; two more block tones (a darker and a lighter) with the
   same mean, so no global stone shift.
6. **Road dark shape**: both streetscape heroes now render at 11:30 so building shadows are short. The stepped
   light/dark patch on Ann St is still there at 11:30, so it is not a shadow: it is in the road surface itself
   (round 9: trace it face by face).
7. **Colours**: Ann St 2018 brick ochre-tan (AE8658) instead of salmon; Admiralty peach-pink (E2C9B0).

## Seen after the full render
- cathedral_ann_st_2012: a dark cone at the bottom left and a few leaf dots remain.

## Not done yet
Turn arrows and island hatching at Ann/Queen, car park asphalt colour, three worst camera fits, Deanery cliff and the
faceted hill at the Customs House, Customs House dome in the heroes, Spring Hill baths, BUS ONLY decal check,
cathedral lawn view base.
