# Spire area, round 16 (cloud, Cycles)

Builder: cloud session, 17 Nov 2026. Same renderer (bpy 4.5), rendered in parts. The last round before John's pause.

## Fixes (round 15 critique)
0. **Mantra blue** (r15 went white): a later preview material pass copies diffuse_color into Base Color; the paint
   now sets both. Base #135cc6 = the r15-test lit face #4e91bf scaled to the photo's #3f78b8.
1. **Ann/Queen fig**: 3-4x the cards at 0.55 m (no far-crown LOD), two-tone #2f4a2a / #4f6b3a with little
   translucency, a dark solid under-canopy mass, three 0.3-0.45 m limbs reaching from the right of the frame.
2. **Skies, per camera**: new area_cams.json "sky_gain" (linear photo/render gain on the painted sky, measured on a
   ray-cast sky mask with tools/spire_area/calib_compare.py, two passes) and "sky_cloud". cathedral_forecourt ended
   within ~1 % of its photo; queen_st_willahra and orient_front set; ann_st_far now pale and cloudy like its photo;
   cirrus almost off on the deep / navy skies. ann_queen_corner top 30 % darkened to the measured #707b8c, near-white
   bottom kept.
3. The old spire_ann_st_2018 pixel box is back (without it a trunkless spray hangs over the Spire facade).
4. **Cathedral**: block-to-block spread cut to ~0.55 of the original palette (same measured hue), large-scale
   weathering noise (x0.86-1.06) over the blocks, leaded glass lifted to #3a4654 / #4a5666.
5. **Willahra** salmon #e6b8a0, **Marriott** orange-cream #e8c49a. (Calibration on queen_st_willahra says the
   Willahra wall reads ~4x darker than the photo: it is mostly in shade / window grid, so the hue alone may not show.)

## Not done
aerial_ne_dusk olive plane in the sky; fish-scale slate; grey roofs; footpath texture; heritage boxes; bus-lane edge;
camera fits (ann_queen_corner).
