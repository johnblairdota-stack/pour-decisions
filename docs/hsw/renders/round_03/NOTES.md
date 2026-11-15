# HSW + Story Bridge, round 3 (16 Nov 2026)

Renders only (photos stay in PourDecisions-sites, never in git). Stage: AS BUILT, day light, no people, cars or boats.
Work list: the critic's ranked fixes on round 2. Numbers are in `layout.HSW` (round 3 block).

## How to run (John's PC, Blender 4.5)

    blender -b --factory-startup -P tools/hsw/render_hsw.py -- <out_dir> heroes photos only=<ids> [scale=0.5]
    <blender python> -I tools/hsw/export_round.py <sites> <render_dir> 3 <pair ids> <hero ids>

## Changed this round
1. Canopy: west of Barrel Hall (x < 655) the hill is solid green: no bare tuff, overlapping leaf-card crowns
   every 3 m on the slope, crowns behind the rim, figs and vines spilling over. Bare tuff stays SE of Barrel Hall.
2. Piles: Felons, the HSW shed, Barrel Hall and Mr Percival's stand over the water on a grid of weathered timber
   piles with cross bracing; the riverwalk front from HSW to Barrel Hall too. The LiDAR read these decks as ground,
   so low strips with water within 30 m to the north now sink under the river (no dark slab, no sawtooth, no grey
   spit by HSW). The terrain patch now runs from x 300 to 870. Riprap stays at the Rivershed point.
3. Bridge steel dark charcoal (from p13, p09), extra lattice lacing in every truss panel.
4. Ground: warmer, darker paving and sand-pink paths; warmer riverwalk concrete; the city floor is no longer white;
   the Kangaroo Pt island is mud under mangroves.
5. River: ripples at two scales plus a Fresnel sky tint at grazing angles.
6. Cliff: desaturated tuff; slabs only on the bare face SE of Barrel Hall, sunk into it; no loose cubes on the rim.
7. Pier: warm cream render, bolder cornice and corner pilasters, one mid-dark back wall inside the arch.
8. Roof letters mid grey, no outline offset (it warped the N and W). Felons and the sheds get fabric awnings.
   Mr Percival's has one dark roof (no porch gable), palms.
9. Wilson Outlook hero: the camera clipped the first 28 m of ground (the dark void); now 6 m.
10. Lift: corten corner columns, teal glass shaft, enclosed teal skybridge.
11. Hotel: angled fins with a light face and a dark glass face; the tip swaps side each floor (chevrons).
12. Horizon: compositor mist toward a warm haze (the sky is left alone), a hazy ridge ring at ~5 km, far land
    tree green, far suburbs split into terracotta roofs, grey roofs and tree clumps.
13. Stanley (the cream two-storey house west of the HSW shed) has a terracotta hip roof. The HSW fig trunks are slimmer.

## Photo fits
Unchanged from round 2 (no landmark moved): p01 23.7, p04 28.6 (holdout 87, not reliable), p06 10.6, p07 21.3,
p09 10.3, p10 7.8, p12 8.2, p13 18.9 (holdout 48.7, weak) px rms.

## Still missing
- p13 north tower apex sits ~85 px low and the p09 bridge yaw looks off against the pier: not re-solved this round.
- Lift tower or Felons east end a few metres off (p12/p13 marks left out).
- Rivershed end wall, island outline, hotel pool deck and lower floors, Bowen Tce buildings.
- The canopy is leaf cards on a 3 m grid: it reads as a blanket, not as single big crowns.
- Dusk photos rendered in day light.
