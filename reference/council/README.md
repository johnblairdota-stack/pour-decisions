# Brisbane City Council open data, clipped to the site

- Source: Brisbane City Council Open Data portal, https://data.brisbane.qld.gov.au (Opendatasoft API v2.1, `exports/geojson`)
- Licence: **Creative Commons Attribution 4.0 (CC BY 4.0)**, https://creativecommons.org/licenses/by/4.0/ . Each dataset page says CC BY 4.0.
- Credit (required on any copy): "Contains data from Brisbane City Council, licensed under CC BY 4.0."
- Downloaded: 2026-10-18
- Clip box: about 1.5 km × 1.5 km around the Riverlight centre (-27.4436709, 153.0855133). Lat -27.45041 to -27.43693, lon 153.07792 to 153.09311.
- Clip rule: features that **touch** the box. Large polygons (for example waterway vegetation) and long lines are kept whole, so some features go outside the box.
- Coordinates: WGS84 lon/lat (EPSG:4326).

## Files

| file | features | what it shows |
|---|---|---|
| park-locations.geojson | 5 | Park boundaries and names (Northshore Riverside Park and others) |
| tracks-and-trails.geojson | 25 | Park paths and tracks, with surface type |
| bikeway-sections.geojson | 11 | Bikeways: width, on/off road, street name |
| cp14-bicycle-network-overlay.geojson | 13 | City Plan bicycle network routes |
| cp14-road-hierarchy-overlay-road-hierarchy.geojson | 38 | Road class (arterial, suburban, district, etc.) |
| park-barbeque-locations.geojson | 8 | BBQ points in parks |
| park-drinking-fountain-tap-locations.geojson | 12 | Drinking fountains and taps |
| park-dog-off-leash-areas.geojson | 2 | Dog off-leash areas, with fence type |
| public-toilets-in-brisbane.geojson | 4 | Public toilets |
| ferry-terminals.geojson | 1 | Northshore Hamilton CityCat terminal point |
| cp14-lgip-pfti-active-and-public-transport-existing-ferry-terminal.geojson | 3 | Ferry terminals (City Plan infrastructure list) |
| cp14-lgip-pfti-parks-and-comm-facilities-existing-trunk-park.geojson | 8 | Trunk parks (City Plan infrastructure list) |
| bicycle-racks.geojson | 1 | Bike rack at the ferry terminal (8 bays) |
| bike-repair-stations.geojson | 1 | Bike repair station (Colmslie, across the river) |
| bikeway-counts-counter-locations.geojson | 1 | Bike counter point |
| brisbane-bus-stops.geojson | 3 | Bus stops |
| parking-sign-locations.geojson | 43 | Parking sign posts: type, category |
| parking-line-locations.geojson | 116 | Painted parking lines: subtype, colour |
| two-minute-passenger-loading-zones.geojson | 4 | 2-minute loading zones |
| commercial-vehicle-loading-zones.geojson | 2 | Loading zones |
| street-tree-landscape-character-precincts.geojson | 5 | Street tree character precinct areas (which tree palette the council uses there) |
| protected-vegetation-...-council-vegetation.geojson | 8 | Protected council vegetation areas |
| protected-vegetation-...-significant-urban-vegetation.geojson | 23 | Significant urban vegetation areas |
| protected-vegetation-...-waterway-and-wetland-vegetati.geojson | 4 | Waterway and wetland vegetation (large polygons) |

## Not available on this portal

I searched the whole catalogue (447 datasets). These are **not published** by the council as open data:

- Individual street and park trees (species, height, point location). Only tree "precincts" and protected vegetation areas exist.
- Footpaths, kerbs and road edges.
- Streetlights. (In Brisbane, most streetlights belong to Energex, not the council.)
- A general park furniture list (seats, bins, shelters). Only BBQs, taps, toilets and bike racks are published.

Also, much of Northshore Hamilton is run by Economic Development Queensland (a state body), so some street assets there may not be in council data at all.

Better sources for those items: OpenStreetMap (already in `reference/osm/`), the LiDAR point cloud (see `reference/elevation/README.md`), and the aerial photos.
