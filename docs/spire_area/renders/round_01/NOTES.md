# Spire area, round 01

Builder: PC session, 16 Nov 2026. Same cameras as round 00 (then/now), except two moved (see below).
Render: `blender -b --factory-startup -P tools/spire_area/render_area.py -- <out> showcase heroes pairs commons`
(build ~100 s, 35 images ~11 min on the PC GPU). The Spire site itself is unchanged in every view.

## What changed
New module `tools/blender/spire/area_hero.py` (built last; hook = one line in `build_all.MODULES`):
- **Self-check**: every new piece's centre is tested against the Spire keep-out zone (lot + 9.5 m, and the
  Ann St strip: same numbers as clear_kerb.py) and the carriageways; the build fails if one is inside.
  Round 01: 594 pieces, none in the zone, none on a road (road marks are allowed on the road only).
- **Render-only**: `area_hero.build()` does nothing for the game export stage (`game_l6`), so the game's
  site model is not touched.
- **St John's Cathedral car park** (OSM 1243599981, checked against the 2022 aerial) and four other open-air
  car parks: asphalt draped on the sloping ground (the old flat slab sat up to 4 m under the grass), 2.6 x 5.4 m
  bays along the cathedral axis, side + back lines, wheel stops, raised tree islands where the LiDAR has a
  trunk (and every 9th bay), new clumpy island trees, 7.5 m light poles, low red-brick retaining wall with
  a grass bank on the Ann St side, entry gate posts + swing leaves, "CATHEDRAL CAR PARK" sign.
  90 bays, 10 islands. streets.py's old flat car-park slab and bay lines are hidden inside these car parks.
- **Cathedral west front forecourt**: the tree grove in front of the west front is gone (2010 photo); new
  bitumen U drive with rolled kerb, four beds with red cordyline, bromeliads and shrubs, black tubular rail,
  "ST JOHN'S CATHEDRAL" noticeboard.
- **Roads**: asphalt patches, crack seal, manholes, side-entry pits, a concrete gutter strip along every kerb
  within 330 m (not in the keep-out zone).
- **Signs**: 40 km/h sign on Ann St by the cathedral. (A second 40 sign and the Story Bridge blade near
  Ann/Boundary St fell on the road and were skipped by the guard: re-place next round.)
- **BUS ONLY** words: lifted 5 cm and levelled, so "BUS C" (half the words under the crowned red lane) is fixed.
- **Neighbours**: own wall colours for Mantra (cream), Marriott (buff), Skyline (darker), Willahra, Admiralty I/II,
  Macrossan (peach); flat roofs toned down to weathered grey (no glaring white roofs).
- **Brick block in the forecourt view** (OSM 1210526673): the 12 m "tower" (LiDAR top incl. trees) is now a low
  brick hall with a steep gable roof, as in the forecourt photo.
- **Cathedral colours**: tuff ashlar buff/mauve palette, paler sandstone dressings, terracotta roofs,
  near-black spire slate, grey porch slate.
- **Look** (`area_hero.light()`, called by render_area.py per view): warm sun (#FFF1DC, 0.5 deg disc, +15 %),
  half the sky fill, AgX Medium High Contrast; distance haze (compositor mist) on aerial views; dusk views:
  ~20 % of windows lit warm, street lamp heads and car park lamps lit.
- **Materials** (restyle, once per scene): mid-grey asphalt (was near black and blue), warm grey concrete
  footpaths, smaller leaves (7 leaf cells per card instead of 3: ~8-10 cm leaves), brown bark #5B4A3C.
- Cameras moved: `willahra_admiralty` (was inside a building) and `deanery` (was behind trees, then inside
  a roof): both in `tools/spire_area/area_cams.json`.

## Shared files touched (small)
- `tools/blender/spire/build_all.py`: one line, `MODULES.append(__import__("area_hero"))`.
- `tools/blender/spire/cathedral.py`: (1) west front block's tile roof starts 0.8 m behind the front plane,
  so the stone gable shows (was the "salmon pyramid"); (2) the three full-width string courses at and above
  the gable eave are gone (the "floating bars"); the two low courses stay.
- Merged `origin/claude/project-thread-ulx8uc` (HSW round 6, 89e35a9): trees.py, ground.py, photo_fit.py,
  layout.STORY_BRIDGE. No Spire photo camera uses Story Bridge marks, so no Spire camera moved
  (photo_fit.py re-run: only the bridge landmark table in photo_cams.json changed).
  Note: the round 01 renders started one minute before this merge, so they use the pre-merge HSW files.

## Still rough
- Three photo cameras still fit badly (orient_front 141 px, crane_from_south 148 px, queen_st_willahra 187 px):
  each photo shows only 3-4 known landmarks. Needs new landmarks (podium tops, kerb corners) next round.
- Trees: still one generic shape family; species by street not yet done; leaves still block the
  spire_ann_st_2018 Commons view.
- Signals, mast arms, ped lanterns, council light types: not changed yet (streetscape.py).
- Cathedral west front: steps with rails and the receding portal orders are still basic; spires could be
  herringbone slate.
- Markings: no new turn arrows, hatched median noses or zebras yet.
- Orient Hotel (curved corner, verandah, HOTEL ORIENT lettering) and the Lawler building: not done.
- Mantra's blue fin still stands off the facade.
- Far field: jagged river banks; the HSW merge may fix the floating spike (check in round 02).
