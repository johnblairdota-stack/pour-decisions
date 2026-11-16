# Spire area, round 04

Builder: PC session, 16 Nov 2026. Fixes from the round 03 critique (~23 %, flat on r02: two over-corrections).
This round moves in measured steps and was checked on a half-size test of 13 views before the full render.
The Spire site and the keep-out zone are untouched (no Orient verandah, no signals or markings in the zone:
John has not answered on the exception yet). area_hero self-check: 751 new pieces, none in the keep-out zone,
none on a carriageway. Same cameras as round 03.

## Fix first
1. **Mantra** (all 3 critics): body cream #E4DAC0, blue-grey glass (lin 0.10/0.14/0.19, not charcoal), balcony
   doors between slabs, **white balcony rails** (1 m solid rail at each of the 25 slabs). The old accent prisms
   (the cyan hairline) are deleted. New real geometry: a **3 m wide blue stripe #1F7BD0** up the facade (79 m,
   0.35 m proud, where buildings.py had its strip), sweeping out and up at the top into a **blue crest** (quarter
   arc, 9 m, tapering), and a white stacked **"mantra"** sign near the top of the stripe.
2. **Cathedral stone**: grey-mauve / brown tuff (#8D8590, #9A8B80, #A69B95, #94877E, #A0918A, per block) on the
   walls; sandstone #D6BE8A (x 0.9) on dressings only (quoins, tracery, copings, pinnacles). Anchored on the
   cathedral_west_front_2010 photo.
3. **Belfry**: 3 louvred lancets per face (dark slate glazing + 4 louvre boards each), just proud of the square
   stage (in r03 they sat inside the wall, so they vanished); a 7-arch blind arcade band under them; the corner
   turrets are round 16-sided drums with round cone caps; the pale "gold collar" bands on the spires are gone.
   Slate spire length kept from r03.
4. **Dusk aerial**: fog cut from 0.8 to 0.32 and blue-grey (0.30, 0.34, 0.42); dusk sky has a thin peach band at
   ~3-5 deg with lilac above and soft blue to the zenith; lit windows ~13.5 %, warm only (no white).

## Then
5. **Cumulus**: coverage up (threshold 0.47, cover 0.97, cells ~40 % bigger), shaded: grey-blue bases
   (#9EA6B6-ish) to white tops; still different in every view.
6. **Hard tone edges across roads**: not shadows or patches: flat-shaded triangles of the crowned road mesh and
   of the draped car park. Smooth shading on `roads`, `car_parks`, `kerb_gutter` and the area car park / drive
   surfaces (shading only, no geometry change).
7. **Bus lane**: deeper brick red #8F3A2E, lighter wear.
8. **spire_ann_st_2018**: the leaf wall in front of the camera thinned to 20 % in a wedge 4-45 m in front
   (the camera is ~290 m from the Spire site, well outside the keep-out zone). Floating leaf clumps in
   willahra_admiralty / customs_house / cathedral_from_carpark: not found as separate pieces this round.
9. **Willahra** off-white #EAE4D6, **Admiralty** warm off-white #E0D3BA, **Marriott** buff #D2C19C (one step each),
   all with full-storey balcony doors and blue-grey glass.
10. **Forecourt beds**: 2 red cordyline clumps per bed (were 5), darker burgundy; the rest green strappy clumps
   with small shrub crowns.
11. **Shards**: besides the Deanery / Customs House boxes, every lone ground spike > 1.5 m off its 5 x 5 median
   within 400 m is flattened (182 heights), except HSW (x > 370) and 70 m round the Spire site.
12. **Roofs**: plant rooms in 3 colours (mid grey, pale, dark) on top of the varied membrane tones.
13. **Window frames**: a 60 mm aluminium frame round every window and a centre mullion in windows wider than
   1.4 m, on every facade with a window grid.
14. **Wheel stops**: each end now sits on the ground (a flat bar on the slope read as a diagonal wedge); square
   bars across the bay end, parallel to the back line.
15. **West gable**: coped parapet along both raking edges and a stone cross at the apex. **Deanery bank**: a
   planted strip 3.5 m either side of the OSM cliff line, with scrub clumps.

## Shared files touched (small)
- `cathedral.py`: spire collars removed (5 lines), `drum()` helper, belfry lancets + louvres + arcade band,
  round turret drums, gable coping + cross.
- No other shared file changed this round. area_hero changes existing objects only outside the keep-out zone,
  plus shading-only changes on the road meshes.

## Not done / blocked
- Orient Hotel verandah + lettering, signals / markings at Ann-Queen: blocked (keep-out zone, waiting for John).
- Landmarks for the 3 badly fitting cameras (orient_front, crane_from_south, queen_st_willahra): not this round.
- Floating leaf clumps: need a crop with coordinates to find them.
- The Mantra stripe is placed where buildings.py had its accent strip; if the photos show it on another face,
  move it with `tools/blender/spire/area_hero.py` mantra_fin (stripe_xy).
