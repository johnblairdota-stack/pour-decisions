# Spire area, round 15 (cloud, Cycles)

Builder: cloud session, 17 Nov 2026. Same renderer (bpy 4.5). Rendered in parts (the cloud box runs out of memory
on long runs; the crane views were rendered one at a time).

## Method change: measured colours (critic proposal)
`tools/spire_area/calib_probe.py` ray-casts a material map (one sample every 8 px) through the real camera of six
photo views; `calib_compare.py` compares the mean linear colour of each material's pixels in the render and the
photo and prints the ratio. Colours this round were set from those ratios, then re-measured on a test render.
(Camera fits of a few px mean small or thin materials are noisy; big ones are reliable.)

## Fixes (round 14 critique)
1. **Dressings**: measured (2010 west front + 2012 Ann St) -> #ccb7a2. After: hue within a few % of both photos.
2. **Ashlar**: west-front ratio applied (warmer), block-to-block spread x1.5 so the mottling shows.
3. **Flag**: its material had NO node tree (so it rendered as a pale viewport colour). Now an explicit opaque
   Principled paint, alpha 1, no transmission or emission, base #1871cf from the measured render/target ratio.
   It IS in crane_from_south: it sits behind the tower crane's jib from that camera (probe: 16 of 20 flag
   vertices visible), so the photo's broad sheet there is partly a camera-fit question.
4. **Skies**: deeper zenith on the clear "deep" skies (#0c4c9e top) and much less cirrus; ann_queen_corner sky
   brightened by the measured photo/render ratio (1.72/1.53/1.33) with a near-white horizon.
5. **Trees**: the annstcath frustum box (it felled the street trees) and an old spire_ann_st_2018 pixel box that sat
   on the photo's fig crown (it thinned it to dots on bare limbs) are gone. New: a big dark fig at Ann/Queen
   (right of the camera, 14 m, crown 7 m radius). Pixel boxes for the floating bits at annstcath, customs_house,
   ann_st_far trunks and the two Deanery poles (only trees are removed: if those poles are street poles they stay).
6. **Car park** lifted (r14 read #1c1c20); **lawn** muted (#566e40-#6e8452).

## Not done yet
Fish-scale slate normal (slates are staggered courses with joints); lilac gable shell; forecourt canopy; porch gap;
Admiralty copies; QUEEN ST sign; BUS ONLY; wheel stops; stepped crown; Orient verandah; road patch; arrows; camera
fits (ann_queen_corner in particular is offset); Deanery cliff.
