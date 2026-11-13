# Spire reference data: sources and licences

Everything here is cropped to the 800 m square round Spire Residences (550 Queen St, Brisbane City),
in the local frame of `tools/blender/spire/layout.py` (origin = Spire footprint centre, MGA56
503046.57 E, 6962279.05 N; +x east, +y north, z metres AHD). Made by `tools/blender/spire/prep_data.py`
from the site download in `PourDecisions-sites/data/cbd` (not in git).

| File | What | Source | Licence |
|---|---|---|---|
| `osm_spire_800m.json.gz` | OSM nodes, ways, relations (880 m square + whole Story Bridge outline) | OpenStreetMap, Overpass, Nov 2026 | ODbL 1.0, (c) OpenStreetMap contributors |
| `dem_1m.f32.gz`, `dem_1m.json` | Ground heights, 1 m grid, metres AHD, 801 x 801, float32 little-endian, rows north to south | Queensland DEM image service (QldDem, default mix) | CC BY 4.0, (c) State of Queensland (Department of Resources) |
| `aerial_YYYY_800m_0p5m.jpg` | Aerial photo, local frame, north up, 0.5 m/px, 1600 px (2015, 2016, 2017, 2018, 2022) | Queensland aerial orthophoto time series (Brisbane 10 cm SISP captures) | CC BY 4.0, (c) State of Queensland (Department of Resources) |
| `aerial_YYYY_site160m_0p1m.jpg` | Close crop of the site, 160 m square, 0.1 m/px (upsampled from 0.2 m), 2015-2018 | same | same |
| `council_spire.geojson` | Loading zones, bus stops, parking signs and lines, road hierarchy, bikeways, significant trees, parks, toilets | Brisbane City Council open data (data.brisbane.qld.gov.au) | CC BY 4.0, (c) Brisbane City Council |

Attribution lines to show in the game credits:

- Map data (c) OpenStreetMap contributors, ODbL 1.0.
- Includes material (c) State of Queensland (Department of Resources) 2026, CC BY 4.0. The State gives no
  warranty in relation to the data and accepts no liability for its use.
- Contains data from Brisbane City Council, CC BY 4.0.

Notes
- Aerials are ordinary orthophotos, not true-ortho: tall buildings lean away from the camera's nadir.
- The aerial download box is a few metres short at the north edge (Web Mercator y scale); those rows are flat grey.
- The OSM database as a whole is ODbL: if a derived database is shared, it must stay under ODbL.
- Not here on purpose: John's own photos (`my_photos/`) and Wikimedia Commons photos. They are used for
  matching only and stay out of git. `layout.py` names the photo files it read but holds no image data.
