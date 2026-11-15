# HSW + Story Bridge, round 2 (16 Nov 2026)

Renders only (photos stay in PourDecisions-sites, never in git). Stage: AS BUILT, day light, no people, cars or boats.
Work list: the critic's ranked fixes on round 1. Numbers are in `layout.HSW` (round 2 block).

## How to run (John's PC, Blender 4.5)

    blender -b --factory-startup -P tools/hsw/render_hsw.py -- <out_dir> heroes photos only=<ids> [scale=0.5]
    <blender python> -I tools/hsw/hsw_fit.py [ids]          # solve photo cameras from tools/hsw/hsw_marks.json
    <blender python> -I tools/hsw/export_round.py <sites> <render_dir> 2 <pair ids> <hero ids>

## Changed this round (critic's list)
1. Cliff: the bench lines and wave streaks (the grid) are gone. The tuff is warm tan-ochre in fractured blocks
   with thin dark joints, iron stain and soft wet streaks. About 1,100 jutting slabs give overhangs and broken faces,
   and smaller blocks make a ragged rim. The faces are mostly bare, with leaf-card tufts on the ledges only.
2. Trees: HSW now gets leaf-card trees (as round Spire) in a mix of fig, eucalypt, poinciana, palm and scrub trees.
   No trunk on a cliff face, right on the rim or on low sand. Figs and vines hang off the rim. The big blob
   crowns in the Wilson Outlook view are gone. Far crowns are less umbrella-shaped.
3. Waterline: the river bank under the decks sinks under the water, so the pale spit and the sawtooth are gone.
   Dark timber piles every 2.6 m with headstocks and X bracing, a dark fascia under the riverwalk edge,
   all shed and Percival's piles dark. Riprap boulders at the Rivershed point.
4. Ground: warm decomposed-granite paving, sand-pink paths through the lawns (OSM footways), dark leaf litter on
   the cliff top. Low riverside land near HSW is grass, not bare white.
5. River: olive-brown with silt patches and fine ripples, matte sheen (no mirror hot spot); the bridge shadow stays.
6. Sheds: roof letters about 50 % bigger in a bold spaced font (Barlow SemiBold, in fonts/). Felons and the white
   sheds are mostly glass. Mr Percival's is mint with arched windows, white arch frames and four palms.
7. North main pier: arch crown 8.2 m under the pier top (read off photo p09), dark panels inside the arch,
   broad corner pilasters. Pier thickness stays 10 m (14 m fitted the photos worse).
8. Bridge: near-black deck underside with a dark soffit, extra hangers in the truss panels and sway braces.
9. Hotel: chevron fins in three tones (white, mid grey, charcoal) per floor, not black slots.
10-13. Lift tower slimmer (3.6 m) in oxide red. Far suburbs tinted toward terracotta roofs. The Kangaroo Pt bank and
   island are dark mud with mangroves near the water. Umbrellas on the outdoor-seating lawns, planters and palms
   along the riverwalk.
14. Fits: p09 and p04 re-marked and re-solved; two new eye-level pairs (p12, p13). 8 pairs in all.

## Photo fits (px on the photo's own size)
| id | rms | max | holdout | marks | photo size |
|---|---|---|---|---|---|
| p01_drone_se | 23.7 | 39.2 | 43.5 | 9 | 1600x1067 |
| p04_drone_dusk_se | 28.6 | 49.8 | 87.0 | 9 | 1051x791 |
| p06_drone_south | 10.6 | 18.9 | 31.7 | 6 | 1200x650 |
| p07_drone_sw_citycat | 21.3 | 33.4 | 30.0 | 9 | 1600x900 |
| p08_from_kangaroo_pt (fit only) | 16.6 | 33.8 | 27.4 | 10 | 1600x900 |
| p09_pier_face_on | 10.3 | 14.6 | 15.3 | 6 | 1600x1200 |
| p10_drone_lawns_se | 7.8 | 11.9 | 14.0 | 6 | 1000x562 |
| p12_river_felons (new) | 8.2 | 15.6 | 23.7 | 6 | 1600x1200 |
| p13_kp_bank_ferry (new, weak) | 18.9 | 33.4 | 48.7 | 7 | 1600x1200 |

- p09: was 58 px. Two marks sat at the pier edges where the pier hides the true shed ends; they are dropped and
  the arch springing is added. The camera solves about 35 m west of the bridge line (heading 17 deg).
- p04: holdout 103 -> 87 px. Still not trustworthy (dusk drone photo, maybe lens distortion).
- p12/p13: the lift tower top and the Felons east ridge end miss by 100-150 px. So the model lift tower or the
  Felons east end is a few metres off. Left out of the fit; check next round.
- Not used: p02 (focal solves to 7.6 mm), p11 (camera solves below the ground), p08 (fits, but the solved spot on
  the Kangaroo Pt bank is behind a toilet block and trees in the model, so the render shows no HSW).

## Still missing
- Hotel pool deck, lower floors and rooftop; Bowen Tce buildings are still plain boxes.
- Rivershed roof vents, annex and verandah are unchanged from round 1.
- Aerial haze for the far city: a world volume turned the Eevee renders black, so it is left out.
- Lawn edges are still 1 m steps; the cliff top behind the rim is thinner than the photos.
- Lift tower and Felons east end position (see p12/p13).
- Dusk photos rendered in day light.
