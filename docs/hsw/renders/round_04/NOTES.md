# HSW + Story Bridge, round 4 (16 Nov 2026)

Renders only (photos stay in PourDecisions-sites, never in git). Stage: AS BUILT, day light, no people, cars or boats.
Work list: the critic's ranked fixes on round 3 (rated ~37 %). Numbers are in `layout.HSW`.

## How to run (John's PC, Blender 4.5)

    blender -b --factory-startup -P tools/hsw/render_hsw.py -- <out_dir> heroes photos only=<ids> [scale=0.5]
    <blender python> -I tools/hsw/export_round.py <sites> <render_dir> 4 <pair ids> <hero ids>

## Changed this round
1. Water: the bump was wired but too weak and too fine to read, and roughness 0.5 hid it. Now glossy (roughness
   0.07), ripples at three scales (~16 m swell, ~5 m wind waves, ~1 m chop), Eevee screen-space reflections on,
   so the sky and the bank mirror at grazing angles and the sun glitters. Sun disc 1.6 deg for a softer shadow edge.
2. Ground: sand-pink pavers (about sRGB 190,155,135) with 0.6 x 0.3 m joints and warm blotches; sand-pink paths;
   the riverwalk deck in the same warm pavers.
3. Bridge: chords 1.5x and deeper, heavier diagonals and posts, gusset blocks at every joint, real cross-girders
   under the deck, the pale cream footway strip at the deck edge is now dark steel.
4. Canopy: distinct round crowns every ~5 m with lime-lit tops, palms among them, two jacarandas in flower.
   Cliff tuff warmer again with stronger iron stain. No slab boxes at all (Wilson Outlook box rocks gone).
   Wilson Outlook camera moved 8 m west so the near tree does not block the view.
5. Hotel: fins 4.8 m pitch, 1.8 m deep, near-white face against dark glass.
6. Pier: warmer cream; posts, a beam and a low plinth inside the arch.
7. Roof letters lighter; striped awnings; piles vary in size and set, with a dark wet band below 1.2 m AHD;
   riprap now rounded rocks.
8. Horizon ridge lower and haze-coloured; far land mottled green.
9. The dark wedge in p07 was real land west of HSW cut by the deck-strip rule; that rule now stops at x 400.
   No tree stands on a sunk cell. The skybridge runs 14 m further to the Bowen Tce building.

## Photo fits
Unchanged (no landmark moved): p01 23.7, p04 28.6 (not reliable), p06 10.6, p07 21.3, p09 10.3, p10 7.8,
p12 8.2, p13 18.9 px rms.

## Still missing
- p13 tower apex (~85 px low) and p09 bridge yaw not re-solved.
- Hotel chevrons may still read as a grid from far; a photo-scale facade texture would do better.
- Lift tower / Felons east end position; Rivershed end wall; island outline; hotel pool deck; Bowen Tce buildings.
- Dusk photos rendered in day light.
