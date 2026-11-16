# Spire area, round 07 (first cloud round: Blender in the cloud, Cycles)

Builder: cloud session, 16 Nov 2026. John's PC is no longer used for renders (it crashed during round 6 work).
Same scene build as before (`build_all` + area_hero), rendered by `tools/spire_area/cloud_render.py`:
pip `bpy 4.5` on CPU, **Cycles** at 32 samples with OpenImageDenoise (EEVEE on the cloud's software GL took
about 5 min per sample, so it is not usable there). Recipe in `docs/spire_area/brief.md` ("Where Blender runs").

**This round is a new baseline.** Cycles traces real shadows and bounce light, so the whole set looks different
from rounds 0-6 (softer, more bounce in shade, no shadow-map artefacts). Judge round 7 against the photos, not
against round 6's look.

## Renderer notes
- The road "stair-step" the critics flagged in rounds 4-6 was EEVEE's shadow map. In Cycles it is gone.
- Tree leaf cards are alpha-cut. With Cycles' default transparency limit (8) the deep crowns ran out of bounces
  and came out frosty blue-white. `transparent_max_bounces` is now 64; crowns are green again.

## Fixes (from the round 6 critique)
1. **West arch** (cathedral.py): the three orders of the great west arch are carved stone steps, not cream ribbons.
2. **Porch gable** removed: the west porch ends in a level dressed parapet, like the real porch.
3. **Stumps / ghost crowns**: trees (leaves and trunks) are cleared along camera rays through each critic box
   (Deanery, car park eye x4, Ann St outside the cathedral x3, cathedral from the car park, Church House / Webber,
   Orient x2). Function `ray_boxes` in area_hero.py.
4. **Mantra**: the south-east stripe is a band that tapers 22 m down from the crest (6 steps) plus the crest wedge;
   the north stripe stays.
5. **Orient Hotel** (from the 2026 orient_front photo): no posts or lace; two cantilevered awnings, ochre walls
   (D7C88E), dark roof, HOTEL ORIENT lettering. Hero camera moved 2.2 m west and turned 4 deg right.
6. **Signal target boards** are black, as in the photos.
7. **Brick building** in spire_ann_st_2018: the east part of the block (x > 121) is brick (9A5A40) with its windows kept.
8. **Light**: warmer sun (1.0, 0.915, 0.77); thinner dusk haze (0.26).
9. Neighbour walls: Marriott D8BC94, Willahra E6DCC4.

## Not done yet
- Turn arrows and island hatching at Ann/Queen.
- Car park asphalt colour (#55524f in the photos).
- The three worst-fitting photo cameras.
- The cliff behind the Deanery.
- Aerial views look hazy and flat brown in Cycles; needs grading for this renderer.
- Seen in the Cycles aerial: a thin red line along some roads (bus-lane paint reading too strong from the air) and
  pale light streaks over the river near the Story Bridge.
