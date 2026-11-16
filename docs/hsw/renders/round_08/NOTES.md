# HSW + Story Bridge, round 8 (16 Nov 2026)

Renders only (photos stay in PourDecisions-sites, never in git). Stage: AS BUILT, day light, no people, cars or boats.
Work list: the critic's ranked fixes on round 7 (rated ~46 %). Every Blender run held `blender.lock`
("HSW render thread") and waited for a free GPU. The Spire area branch (cathedral.py only) was not merged: it does
not touch HSW views.

## How to run (John's PC, Blender 4.5)

    blender -b --factory-startup -P tools/hsw/render_hsw.py -- <out_dir> heroes photos only=<ids> [scale=0.5]
    <blender python> -I tools/hsw/hsw_fit.py [ids]
    <blender python> -I tools/hsw/export_round.py <sites> <render_dir> 8 <pair ids> <hero ids>

## Changed this round
1. Crest skyline: every block on the crest (base above 12 m AHD, top above 30 m, x 380-1000, y 0-330) is built as
   cream balconied apartments, so no teal-striped slabs remain; Oakwood grey-white with near-black glazing.
   Trees on the crest strip above Felons (x 470-680, y 95-150) are capped at 9 m so the blocks show from the river.
   Fiume terrace on the hotel's east roof (glass balustrade, white umbrellas); palms round the hotel and in groups
   along the crest.
2. Lift tower at x 563 (14 m further west); the enclosed walkway leaves east to the crest. With the lift marks back
   in p12 and p13 the fits agree: lift error p12 2.9 px, p01 15.6 px (p01 rms 12.3, p12 7.0).
3. Cliff grey-buff (between round 6 and 7), orange only in the stain; bench spacing 4 m. A continuous low canopy line
   runs along the whole crest; the hill canopy has occasional rock gaps on the steepest faces.
4. Lawns: the OSM lawn terraces in a brighter green of their own; general paving buff, pink only on the one path;
   one tight cluster of 12 taupe umbrellas at the Rivershed's east end.
5. (Rivershed roof/gable, beach: not done this round.)
6. Far field: varied mid-rise (12-40 m) in the first 1.5 km of the far suburb; mist starts at 350 m; the ridge
   rises to the west (Mt Coot-tha).
7. Waterfront: shed piles irregular (about 1 in 5 missing); pier near-white with a faint warm pink and weathering;
   letters near-black; a taller, darker glazed wall fills the view through the arch.
8. Canopy: larger crowns (4.5-7.5 m), 35 % yellow-green crowns.

## Edits to shared files (please tell the Spire area thread)
- `trees.py`: HSW crest tree cap (x 470-680, y 95-150).
- `ground.py`: far-suburb mid-rise heights within 1.5 km.
- `layout.py`: `hsw_crest_ids()` now also requires base_ahd >= 12 (matches the new crest rule); HSW numbers.
- `landmarks.py` (HSW-owned): pier render material uses the "dg" weathering shader.

## Still missing
- Rivershed roof, gable cladding, folding doors; the beach between Barrel Hall and Rivershed.
- Far field still reads as a plane of boxes from the aerial heroes.
- p13 mangroves, riverwalk hero dressing, p04 re-solve.

## Photo fits (rms / holdout px)
p01 12.3 / 27.5, p04 26.5 / 64.4, p06 6.5 / 28.6, p07 15.7 / 31.4, p09 11.3 / 15.4, p10 3.9 / 15.4,
p12 7.0 / 20.0, p13 26.8 / 45.0 (lift mark added back; its error there is 31 px).
