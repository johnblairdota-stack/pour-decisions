# Howard Smith Wharves reference data: sources and licences

Everything here is cropped to the 800 m square round Howard Smith Wharves, in a local frame:
origin = centroid of OSM way 564498898 (MGA56 503667.95 E, 6962304.46 N; -27.4627883, 153.0371228), +x east, +y north,
z metres AHD. Made by `tools/sites/prep_site.py` from the site download in `PourDecisions-sites/data/cbd`
(not in git). See `site.json` for the file list.

| File | What | Source | Licence |
|---|---|---|---|
| `osm_hsw_800m.json.gz` | OSM nodes, ways, relations touching the 880 m square | OpenStreetMap, Nov 2026 | ODbL 1.0, (c) OpenStreetMap contributors |
| `dem_1m.f32.gz`, `dem_1m.json` | Ground heights incl. river bed, 1 m, 801 x 801, float32 LE, rows north to south | QldDem default mix | CC BY 4.0, (c) State of Queensland |
| `lidar/*` | 2019 DSM, ground, class grid, building heights, tree tops, site height profile (800 x 800, 1 m) | Brisbane 2019 Project LiDAR via ELVIS | CC BY 4.0, (c) State of Queensland |
| `aerial_YYYY_800m_0p5m.jpg` | Aerial, local frame, north up, 0.5 m/px | Qld aerial orthophoto time series | CC BY 4.0, (c) State of Queensland |
| `aerial_YYYY_site*m.jpg` | Close crop of the site, 1600 px (resampled from 0.2 m) | same | same |
| `council_hsw.geojson` | Loading zones, bus stops, parking signs/lines, road hierarchy, bikeways, significant trees, parks | Brisbane City Council open data | CC BY 4.0, (c) Brisbane City Council |

Credits to show in the game:
- Map data (c) OpenStreetMap contributors, ODbL 1.0.
- Includes material (c) State of Queensland (Department of Resources) 2026, CC BY 4.0. The State gives no
  warranty in relation to the data and accepts no liability for its use.
- Contains data from Brisbane City Council, CC BY 4.0.

Notes
- Aerials are ordinary orthophotos, not true-ortho: tall buildings lean away from the camera's nadir.
- Grey areas in an aerial = outside every square downloaded for that year.
- Not here on purpose: John's own photos and Wikimedia Commons photos (matching only, kept out of git).
