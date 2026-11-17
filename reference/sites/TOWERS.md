# SCP river-site towers: data packs (16 Nov 2026)

Data collection only for the shortlisted towers other than Spire. No models or game code yet.
Each `reference/sites/<id>/` pack mirrors the Spire pack and is made by
`python3 tools/sites/prep_site.py <PourDecisions-sites>/data [ids] [--only=osm,dem,lidar,aerial,council]`
from the raw download on John's PC (`Documents/PourDecisions-sites/data`).

Frame (same as Spire): origin = centroid of the site's OSM outline, +x east, +y north on the
MGA zone 56 grid, z = metres AHD, data covers x, y in [-400, 400].

| Pack | What |
|---|---|
| `site.json` | origin (lat/lon + MGA56), OSM outline in local metres, aerial affine and coverage |
| `osm_<id>_800m.json.gz` | every OSM element touching the 880 m square |
| `dem_1m.f32.gz` + `dem_1m.json` | 801 x 801 1 m terrain (QldDem default DEM) |
| `lidar/` (CBD only) | 2019 LiDAR: `dsm_1m`, `ground_1m`, `class_1m`, `tree_points.csv`, `building_heights.csv` (OSM footprints), `lidar.json` (site height profile) |
| `aerial_YYYY_800m_0p5m.jpg` | 800 m aerial per year at 0.5 m/px, north up, local frame |
| `aerial_YYYY_site<N>m.jpg` | site close-up for each construction year at 0.2 m/px |
| `council_<id>.geojson` | Brisbane City Council layers (kerbs, paths, trees, lights, etc.) |
| `CREDITS.md` | sources and licences |

Reference photos (Wikimedia Commons, John's own) stay OUT of git. Contact sheets live in
`/mnt/project-files/visuals/sites/research-16nov/sheets/`.

## 1 William St (`william1`)
- Origin -27.47380 153.02620 area; OSM way 521115344. 46 levels, 260 m roof / 267 m to mast tip
  (LiDAR top 266.6 m AHD, matches the surveyed 266.35 m AHD). Ground median 7.7 m AHD. Bulk of
  the roof cells sit at 180-220 m above ground (the sloped crown).
- Plan: rounded lozenge, rotated off the grid, wrapped by the Riverside Expressway ramps.
- Aerials: 2012 car park cleared and bulk dig; Sep 2013 basement with perimeter wall; Jul 2015 core +
  oval deck with red/white perimeter screen and about three red/white luffers near local (-28,-10),
  (+8,-8), (+35,-4) (+/-5 m for lean); Jul 2016 near top, crown frame, one luffer; 2017 complete;
  2022 Queen's Wharf basement next door. 2018-2020 aerials only 60 % covered.
- Photos: dark blue-grey glass with bronze/brown spandrels and slim vertical fins; sloped crown with
  a mast; wide curved glass entrance canopy. During the build: red/pink perimeter screen round the
  top floors, black hoist masts up the faces, two or three red/white Favco luffers on the core.
- Build: Brookfield Multiplex 2013-2016; split core with two jump systems; Lindores Favco cranes
  (M380D 60 m jib, M220DX 50 m, M380D 60 m, all 16 t).

## Brisbane Skytower (`skytower`)
- Origin -27.4718484 153.0287410 (MGA 502839.55 6961301.12); OSM way 683336940. 90 levels, about
  270 m. LiDAR top 277.1 m AHD, ground 4.4 m AHD; almost all roof cells 260-300 m.
- Plan: rounded triangle. 2015 triangular pit (old Vision Brisbane hole); 2016 core + early slabs
  with a red/white luffer; 2017 deck centred near (+5,+5), luffer mast near (+10,-5) with jib to SE,
  Mary Lane (111 Mary St) site NW near (-40,+40) with two cranes; 2018 one luffer; 2019/2022
  topped out with the roof pool at the east/SE corner.
- Photos: deep navy glass with fine horizontal bands, darker crown; curved timber-look canopy at
  the Skyrise entrance. Build stage photos May 2016 to Jan 2019 show the jump form on top with a
  red/white luffer above it, teal/blue builder hoarding at street level.
- Build: Hutchinson Builders 2015-2019 (not Multiplex). L3 podium; amenity L40/L66/L89/L90; OM
  jump form (ICQ) from Feb 2016 on a 4-5 day cycle; crane sequence internal Favco luffer, then a
  climbing flat-top cantilevered off L66 (6 x 4 m steps), recovery crane, stiff-leg.

## Queen's Wharf (`queenswharf`)
- Origin = centroid of the OSM landuse=construction way 514750387 (no tower footprints in OSM).
  -27.4735626 153.0254439 (MGA 502513.76 6961111.31). 2019 LiDAR is the basement pit
  (ground median -2.1 m AHD, top 89.8 m is a crane or 1 William edge).
- Aerials: 2017 Executive + Neville Bonner buildings coming down; 2018-19 big basement across
  William St; 2020 podium slabs, cores, cranes, barge in the river (bridge works); Jul 2021
  Rosewood/Dorsett round tower NW near (-35,+40) with its jump form, Star Grand arc towers along the
  SW curve near (-50,-60) with blue screens, round deck near (+45,-55) (likely the Residences),
  Neville Bonner Bridge landing near (-120,-65); 2022 arcs and cores higher.
- No aerial or LiDAR shows the finished towers (newest public aerial is 2022). Geometry of the
  finished buildings must come from photos.
- Photos: Star Grand towers in warm gold glass, round Dorsett, Sky Deck; 9-10 red/white luffers
  in 2020; white cable-stayed Neville Bonner Bridge; Brisbane sign on the South Bank side.
- Build: Multiplex; 7-level podium over the expressway, 5-level basement 26 m deep, Sky Deck 100 m
  up; 7 satellite pumps + 3 pump stations, 4 + 2 jump forms, up to 10 cranes, 23 lifts. Tower heights
  disagree between sources.

## Howard Smith Wharves (`hsw`)
- Origin -27.4627883 153.0371228 (MGA 503667.95 6962304.46); OSM way 564498898. Already has its own
  Blender module and refs from the HSW render thread; this pack adds the same-frame data.
- Aerials: 2016-17 empty wharf strip; 2018 works along the cliff and wharf; 2019 open; 2020/2022
  complete with the ferry terminal. LiDAR top 80.7 m is the Story Bridge.

## Alcyone, Portside Hamilton (`alcyone`) - paused by John
- Origin -27.4397484 153.0696457 (MGA 506882.83 6964855.12); OSM way 566453920. No LiDAR tile in
  the download (DEM only).
- Aerials: 2015 car park; 2016 slabs rising round a central tower crane; 2017 complete; 2018 street
  rebuilt.

## Gaps
- Finished Queen's Wharf: no OSM towers, no post-2022 aerials.
- No public aerial after 2022 and none for 2014.
- SCP's own pump/boom setups per tower are not published on pages that could be read.
- The CBD Commons photo download on the PC was partial and has no credits file yet.
