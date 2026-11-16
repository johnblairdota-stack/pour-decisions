# Spire area, round 02

Builder: PC session, 16 Nov 2026. Fixes from the round 01 critique (3 critics, ranked list), same cameras
as round 01 plus one new hero (`customs_house_river`); the `deanery` camera moved again. The Spire site is
unchanged; area_hero's self-check: 715 new pieces, none in the keep-out zone, none on a carriageway.

## Fix first (round 1 pushed too far)
1. **Sky**: the camera now sees a painted gradient sky (#C4D8EA horizon -> #8FB5DE -> #2F6FC0 zenith) with a
   few soft cumulus (noise on a cloud deck, none near the horizon); lighting still comes from the Nishita sky
   (World: Light Path "Is Camera Ray" mixes the two). Daylight +0.6 EV on round 1, sun +30 % on round 1's gain,
   warm #FFF1DC. Dusk views: peach -> lilac -> soft blue gradient, not navy.
2. **Aerial haze**: blue-grey (compositor mist colour ~#8fa3b8 at display), not khaki. The ghost spikes near
   the river are gone with the HSW round 6 ground fix (lone LiDAR spikes now sink). River colour is the HSW
   thread's (preview.py `clay_water`): not changed here.
3. **Dusk windows**: lit in floor runs (4 windows per run), ~15 % of runs lit, brightness 40-100 % per run,
   three colour temperatures (warm incandescent, warm white, cool LED).
4. **Roofs**: flat roofs now mix three membrane tones (pale / mid / warm grey, ~40 m patches) with fine grime;
   plant rooms + AC units on 99 flat roofs within 330 m (not Spire, cathedral, HSW or the HSW crest blocks).
5. **Cathedral roof**: tile #844836-ish (was #c8553a) with visible tile courses (line every 0.28 m + tile tone);
   slate roofs get courses too.
6. **Car park asphalt**: same material as the streets (`clay_road`), so same grey and wear.

## Then
7. **Trees**: whole trees are removed now (round 1 cut by area and left flat stumps and bare forks). Cleared:
   the forecourt in front of the west front and the `cathedral_west_front_2010` photo's view (a wedge from the
   camera to the west front: the photo shows the open drive). Figs outside HSW get a round tapered trunk
   instead of the bell flare. Species zones: cathedral grounds/forecourt = camphor laurels (round dense crowns,
   straight trunks); palms at the Orient / Ann-Queen corner. Car-park island trees: limbs end inside the crown.
8. **Neighbours**: Mantra, Willahra, Admiralty I/II now concrete with small punched windows (1.15 m in a 3 m bay,
   matte glass), not glass stripes. (Mantra's tower tiers sit on OSM 189779738 "Hotel Mantra", whose recipe was
   the podium's blue strip windows; both Mantra recipes get the concrete look. 13 views with Mantra in them
   were re-rendered after this fix.) Mantra's roof spike and the detached part of its blue fin are gone (109
   faces); the fin left on the facade hugs it. Soleil (Meriton) has white diagonal bands, not a red stripe.
9-10. **Cathedral west front**: the slate pent roof over the porch is now a solid stone gable; window tracery
   (two sub-arches and a circle in the head of the great west window); black handrails down the porch steps;
   ashlar blocks about twice the size (UV scale 0.5: ~0.7 m courses, 0.9-2 m blocks); dressings warm sandstone
   (were sage).
11-12. **Car park**: one surface with the polygon's exact edge (bisected on a 2 m grid, draped on the ground),
   concrete kerb round it (gap at the gate), wheel stops are precast concrete bars (trapezoid section).
   **Road wear**: patches are rectangles on the road crown (6 x 3 grid) with soft faded edges; crack seal, pits,
   manholes and the gutter strip also follow the crown. **BUS ONLY** is a flat decal (no extrusion), levelled.
13. **Deanery** hero moved (raised over Adelaide St). **Customs House**: 6 Corinthian-proportion columns with
   bases and capital blocks, entablature and pediment on the river front (Commons photo from the river), copper
   dome in verdigris green; new hero `customs_house_river`.
14. Second 40 km/h sign and the green Story Bridge blade re-placed on the footpath near Ann/Boundary St (the
   guard now looks for the nearest clear spot off the road instead of skipping).

## Shared files touched (small)
- `cathedral.py`: porch slate roof -> stone gable (1 line), window tracery (+7 lines), step handrails (+9 lines),
  a "rail" material.
- `trees.py`: figs outside HSW get a tapered tube trunk instead of `fig_trunk` (guarded by `in_hsw`, HSW unchanged).
- `street_catalogue.json`: 2 new tree-species zones (cathedral grounds camphor, Orient corner palms) ahead of the
  existing ones.
- No change to preview.py, streetscape.py, streets.py, buildings.py, looks.py, hsw*.py, layout.py.

## Still rough
- Signals (round galvanised poles, mast arms, ped lanterns, push buttons), turn arrows, hatched median noses and
  zebras at Ann/Queen: not done (streetscape.py).
- Orient Hotel verandah and HOTEL ORIENT lettering: not done.
- The 3 badly fitting photo cameras (orient_front, crane_from_south, queen_st_willahra): no new landmarks yet.
- One bare-branched tree near the Orient corner in `orient_hotel` (not from area_hero; source not found yet).
- River colour (HSW's material).
- "Shadow buffer full" warnings in the aerial views (Eevee shadow pool 512): some far shadows may drop.
