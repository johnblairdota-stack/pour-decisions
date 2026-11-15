# HSW + Story Bridge, round 7 (16 Nov 2026)

Renders only (photos stay in PourDecisions-sites, never in git). Stage: AS BUILT, day light, no people, cars or boats.
Work list: the critic's ranked fixes on round 6 (rated ~42 %). Every Blender run took `blender.lock`
("HSW render thread"), waited for a free GPU, and only ever deleted a lock that still had that name in it.

## How to run (John's PC, Blender 4.5)

    blender -b --factory-startup -P tools/hsw/render_hsw.py -- <out_dir> heroes photos only=<ids> [scale=0.5]
    <blender python> -I tools/hsw/hsw_fit.py [ids]
    <blender python> -I tools/hsw/export_round.py <sites> <render_dir> 7 <pair ids> <hero ids>

## Changed this round
1. Cliff crest: the apartment blocks on the crest (Bowen Tce, Oakwood; 27 buildings in x 380-950, y 60-320,
   top >= 30 m AHD) are now built by `hsw_hero.crest_blocks`: cream-brown walls with punched windows, a balcony
   slab on every floor with a dark rail. The generic teal/white boxes for them are skipped.
2. Lift tower 17 m west (x 577), behind the last third of Felons; skybridge runs to the crest. Fits that mark the
   lift improved: p01 21.3 -> 13.6 px, p04 holdout 111 -> 74 px.
3. p13 camera now stands on the Kangaroo Pt bank at eye height (it was inside the bank). Mid-river LiDAR returns
   in front of HSW (moored boats, open water in p13) and the pier strip west of HSW (the p01 spit) sink under the
   river; no mangroves there. Mangrove mud lighter.
4. Canopy: two greens (warm green and olive) mixed crown by crown. Cliff tuff warmer.
5. Underside: no flat soffit plate, so light shows between the thin girders. Shed piles fewer and fatter
   (0.7-0.85 m, ~3.2 m apart); riverwalk piles 0.75 m every 3.2 m.
6. Ridge drawn as a flat emissive haze colour (no shading streaks).
7. Hotel pattern 2.5x smaller, with cream panels added (white, cream, light grey, charcoal, glass bays).
8. FELONS lettering sized to fit the roof (no clipped F), dark grey. Mr Percival's radius 10.5 m (about the photo
   width), dark slate roof, larger glazed arches.
9. One umbrella cluster (max 14, by the Rivershed); one sand-pink path (the longest); finer chop on the water.
10. Ferry pontoon: kept as built. The pair photos are from 2019-2020 (p09/p12 are Nov 2019, p10 was published
    Sep 2020, p06 is the builder's completion shot), so they likely predate the HSW ferry terminal (research: opened
    2020-21). Not verified against an exact opening date.

## Edits to shared files (please tell the Spire area thread)
- `buildings.py`: `SKIP |= L.hsw_crest_ids()` (the crest blocks HSW now builds itself).
- `layout.py`: new function `hsw_crest_ids()`; lift tower position in `HSW`.
- `ground.py`: mangrove mud colour.
- Nothing in streets.py, trees.py, preview.py or looks.py this round.

## Photo fits
rms / holdout px: p01 13.6 / 34.1 (was 21.3), p04 24.9 / 73.9 (was 26.1 / 111), p06 6.5, p07 15.7, p09 11.3, p10 3.9,
p12 7.4, p13 23.6 / 33.3 (camera now at eye height on the bank).

## Still missing
- Kangaroo Pt shoreline still steps (2 m ground); far field still boxes on a green plane.
- Cliff lip still fairly straight; canopy crowns could be bigger and brighter on top.
