# HSW + Story Bridge, round 5 (16 Nov 2026)

Renders only (photos stay in PourDecisions-sites, never in git). Stage: AS BUILT, day light, no people, cars or boats.
Work list: the critic's ranked fixes on round 4 (rated ~42 %). Numbers are in `layout.HSW`.

## How to run (John's PC, Blender 4.5)

    blender -b --factory-startup -P tools/hsw/render_hsw.py -- <out_dir> heroes photos only=<ids> [scale=0.5]
    <blender python> -I tools/hsw/export_round.py <sites> <render_dir> 5 <pair ids> <hero ids>

## Changed this round
1. Bridge: mid steel-grey, slightly blue (albedo ~0.2, from p13), thinner secondary lacing; underside with
   cross-girders every half panel, thinner and evenly spaced; bearings on the main pier tops.
2. Hotel: fins dropped. A skin on every wall of every tier carries a photo-scale zig-zag texture (charcoal, tan,
   dark glass; 3.2 m floors, 4.8 m repeat), with green planter strips on the tier edges and one big jacaranda
   on the cliff side.
3. Ridge: a smooth sum of long sines (no random-walk shards), lower and haze-coloured. Far suburb denser
   (80,000 roofs and tree clumps). The land west of HSW is park, not pink paving.
4. Cliff grey-tan buff with stronger wet streaks. Canopy: brighter lime crown tops, palms in groups of 2-4.
5. Water: less khaki, more Fresnel sky, a fourth, large ripple scale so drone views do not go flat.
6. Pier arch: found that a round-4 edit had turned the back-wall colour into a comment, so the arch rendered
   black. The back wall is now lit warm grey, with bearings above.
7. Piles: one row with gaps (no second row behind). Riprap is now grey-brown rounded boulders.
8. Lawns olive, not apple-green. Umbrellas in denser clusters.
9. Skybridge 22 m longer to meet the Bowen Tce building. Mangroves are leaf-card clumps, not low-poly blobs.
   Roof letters wider and more spaced (p12).

## Photo fits
Unchanged (no landmark moved): p01 23.7, p04 28.6 (not reliable), p06 10.6, p07 21.3, p09 10.3, p10 7.8,
p12 8.2, p13 18.9 px rms.

## Still missing
- p13 tower apex and p09 bridge yaw not re-solved.
- Hotel pattern runs as horizontal zig-zag rows; the photo's chevrons stack in vertical columns.
- The park west of HSW (p07 left) still ends in a sheer edge at the water.
- Rivershed roof and end wall, Barrel Hall front, the main-lawn hero tree, island outline, dusk light.
