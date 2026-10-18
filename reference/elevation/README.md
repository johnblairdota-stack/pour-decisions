# Elevation (ground height) for the Riverlight area

Downloaded: 2026-10-18

## Licence and credit

- Licence: **Creative Commons Attribution 4.0 (CC BY 4.0)**, https://creativecommons.org/licenses/by/4.0/
- Credit (required on any copy, from the service): "Includes material © State of Queensland (Department of Natural Resources and Mines, Manufacturing, and Regional and Rural Development); © Commonwealth of Australia (Geoscience Australia, The Australian Hydrographic Office); © www.deepreef.org 2025"
- Source service: Queensland Government `QldDem` image service, https://spatial-img.information.qld.gov.au/arcgis/rest/services/Elevation/QldDem/ImageServer (`exportImage`, 1 m pixels, bilinear).
- Underlying LiDAR datasets (metadata on QSpatial):
  - Brisbane 2019 Project: https://qldspatial.information.qld.gov.au/catalogue/custom/viewMetadataDetails.page?uuid=%7BE5EAAFE5-3EDA-4FC6-B41E-78237CDEC0BE%7D
  - Brisbane 2014 LGA: http://qldspatial.information.qld.gov.au/catalogue/custom/viewMetadataDetails.page?uuid=%7B3594F263-F8B4-4F21-923D-0E78B7D02C80%7D

## Area

- 1500 m × 1500 m box, centred on the Riverlight centre (-27.4436709, 153.0855133 = MGA zone 56 E 508450.7, N 6964419.7).
- Box in MGA zone 56 (EPSG:28356, GDA94): E 507700 to 509200, N 6963670 to 6965170.
- North is up. Heights are metres above AHD (Australian Height Datum, about mean sea level).

## Files (all in git)

| file | size | what it is |
|---|---|---|
| qld_dem_2019_1m_1500m_mga56.tif | 7.6 MB | 1 m bare-ground DEM from the **2019** LiDAR only. 1500 × 1500, Float32. The river and some edges are empty (no data), about 16% of pixels. Riverlight was mostly built by 2019. Ground at the Riverlight centre: **5.85 m**. |
| qld_dem_default_1m_1500m_mga56.tif | 9.0 MB | 1 m DEM from the service default mix: **2014** LiDAR on land, plus coarse river-bed (bathymetry) data. No gaps. Ground at the Riverlight centre: 4.01 m (before the site was filled). River bed down to -12.9 m. |
| heightmap_2m_750px_u16.png | 0.8 MB | Game-ready heightmap. 2 m pixels, 750 × 750, 16-bit greyscale. Uses 2019 where it exists, else the default mix. **Height in metres = pixel / 1000 − 20.** (0 = no data.) Range -12.85 m to 20.13 m. |
| hillshade_1m_preview.png | 1.3 MB | 1 m shaded-relief picture for quick visual checks only. Light from the north-west. |

Note: the GeoTIFFs use "sparse" tiles. Empty 128 × 128 tiles have no bytes. GDAL and QGIS read them fine. Some small JavaScript readers (geotiff.js 2.1) crash on them.

## Surface model (DSM), building heights and trees (2019 LiDAR)

Made: 2026-10-18, from one LiDAR tile that John ordered from ELVIS.

- Source tile: `Brisbane_2019_Prj_SW_508000_6964000_1k_class_AHD.laz` (classified point cloud, 84 MB, 17.0 M points). It covers only **E 508000-509000, N 6964000-6965000** (1 km x 1 km). That is the middle of the 1500 m box, with Riverlight in it. The rest of the box has no DSM.
- Capture: Brisbane 2019 Project, flown **2019-06-11 to 2019-08-16**.
- Licence: the tile's metadata says "© State of Queensland (Department of Resources) 2023" and "Limited Use Licence". ELVIS lists Queensland LiDAR as CC BY 4.0. Keep the raw tile out of git. Credit the State of Queensland on any copy.
- The raw tile and the 1 m DSM GeoTIFF are in `lidar_2019/` (in `.gitignore`).
- Scripts: `tools/lidar/grid.js` then `tools/lidar/products.mjs` (Node, with npm packages laz-perf 0.0.6, geotiff 2.1.3, proj4 2.15.0).

| file | in git | what it is |
|---|---|---|
| lidar_2019/qld_dsm_2019_1m_1500m_mga56.tif | no (9 MB) | 1 m DSM (highest point in each cell, noise and water left out). Same 1500 x 1500 box, Float32, EPSG:28356, NaN = no data. |
| dsm_2019_2m_750px_u16.png | yes | Game-ready DSM, same box and pixels as `heightmap_2m_750px_u16.png`. 2 m pixels (highest of each 2 x 2). **Height in metres = pixel / 500 − 20** (a different scale from the heightmap, so tall buildings fit). 0 = no data. |
| building_heights.csv | yes | Every OSM building whose centre is within 1.5 km of the Riverlight centre (424). Height above ground = 90th percentile of the DSM inside the footprint − median ground inside the footprint. Ground = the 2019 ground points, with gaps under roofs filled from the sides. Only 43 are inside the tile; the rest say "outside 2019 LiDAR tile". |
| canopy_height_2019_1m_u8.png | yes | Tree canopy height, 1 m pixels, the 1 km tile only (top-left = E 508000, N 6965000). **Height in metres = pixel / 4.** Uses vegetation points only, and leaves out OSM footprints and building points (grown by 1 m). |
| tree_points_2019.csv | yes | 2825 tree tops: local highest points (5 x 5 m window) of the canopy height that are over 3 m. lon/lat (WGS84), height above ground, ground height (AHD). |

Notes on the capture year:
- "nothing tall here in 2019: may postdate the capture" means the footprint was under 2.5 m in 2019. **Riverlight North Apartments** is one of these (1.2 m in 2019).
- "OSM start_date ... postdates the 2019 capture" is added when OSM gives a build year after 2019.
