# HSW + Story Bridge, round 9 (16 Nov 2026)

Renders only (photos stay in PourDecisions-sites, never in git). Stage: AS BUILT, day light, no people, cars or boats.
Work list: the critic's ranked fixes on round 8 (rated ~44 %). Every Blender run held `blender.lock`
("HSW render thread"), waited for a free GPU (the Spire area thread was rendering at the start), and only deleted
a lock that still had that name.

## How to run (John's PC, Blender 4.5)

    blender -b --factory-startup -P tools/hsw/render_hsw.py -- <out_dir> heroes photos only=<ids> [scale=0.5]
    <blender python> -I tools/hsw/hsw_fit.py [ids]
    <blender python> -I tools/hsw/export_round.py <sites> <render_dir> 9 <pair ids> <hero ids>

## Changed this round
1. Artefacts: the pale shard fins were the round-8 "rock gap" faces in the green hill; removed. Through the arch
   the back wall is now a lit zig-zag glazed facade (the hotel pattern), not black. Less mirror on the water
   (roughness 0.16, specular 0.25) cuts the white smears. The p01 green wedges and post were a LiDAR boat strip
   and a mudflat mid-river (x 400-620, y -215 to -112): sunk, no mangroves there. Wilson Outlook: no trees, crowns,
   tufts or figs within 50 m of the lookout; lens 24 mm.
2. Skyline: canopy crowns on the crest above Felons and the lift are 40 % smaller so the cream blocks clear it from
   the river. Fiume terrace (glass balustrade, white umbrellas) moved off the hotel roof onto the crest strip above
   Felons (x 535-560, y 100-112). Hill canopy recoloured: ~38 % yellow-green (#8fb43a-#b5c94a range), ~5 % dry
   olive crowns, jacarandas only at the hotel corner. Palms round the hotel and in groups along the crest (round 8).
3. Cliff: smaller blocks with darker joints (joint contrast doubled), twice the scrub on the ledges.
4. Water olive-brown (0.12, 0.10, 0.055), less mirror.
5. Umbrellas: one cluster of 12 taupe umbrellas with tables on the Rivershed Lawn (x 735, y -20). Paving warm buff.
6. Far field: ridge soft and pale (emissive haze colour), pink/red roofs desaturated.
7. Bridge: colour kept; a deep cross-girder every 7 m and a lower stringer layer give the underside depth.
8. Shed piles are round (10-sided tubes) and varied, with the wet tide band; about 1 in 5 missing.
9. Rivershed: own style, grey-cream cladding with smaller glazing, blue-grey roof, verandah awning, roof vents.
Smaller: the lift's rust stair spur is gone; Mr Percival's balustrade white.

## Edits to shared files (please tell the Spire area thread)
- `ground.py`: far roof colour; HSW-only river sinks (boat strip and mudflat in x 400-620, y -215 to -112).
- `trees.py`: no trees within 50 m of the Wilson Outlook lookout.
- `landmarks.py` (HSW-owned): underside deep cross-girders and a lower stringer layer; arch back-wall material.
- No change to streets.py, preview.py or looks.py.

## Photo fits (rms / holdout px), unchanged this round (no landmark moved)
p01 12.3 / 27.5, p04 26.5 / 64.4, p06 6.5 / 28.6, p07 15.7 / 31.4, p09 11.3 / 15.4, p10 3.9 / 15.4,
p12 7.0 / 20.0, p13 26.8 / 45.0.

## Still missing
- Far field still lacks dense small roofs and street trees; p04 and p13 not re-solved.
- Sand patch and riprap between Barrel Hall and the Rivershed; main-lawn shadow wedge; kiosk vines on the pier.
