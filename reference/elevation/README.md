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

## Not done: surface model (DSM), point cloud, building heights

The brief asked for a DSM or classified point cloud, then a CSV of OSM building heights (DSM minus DEM).

- ELVIS (https://elevation.fsdf.org.au) lists the right files. For the 9 km² around the site:
  - 2019 LiDAR point cloud: 9 tiles `Brisbane_2019_Prj_SW_{507000..509000}_{6963000..6965000}_1k_las.zip`, about **945 MB** total.
  - 2014 LiDAR point cloud: 9 tiles, about 250 MB total.
  - 2019 1 m DEM tiles: 9 files, about 25 MB.
- These files are on Amazon S3 with "requester pays" turned on. A direct download returns "AccessDenied". The only free way is the ELVIS order form. It asks for an email address and then emails a download link.
- There is no free public DSM web service for this area. (The only DSM is the 30 m SRTM one, which is too coarse.)

### What John can do (free, about 10 minutes)

1. Open https://elevation.fsdf.org.au
2. Draw a box around Hamilton Northshore (or zoom in and use the select tool).
3. Under **QLD Government → Point Clouds → AHD**, tick the 9 `Brisbane_2019_Prj` tiles listed above.
4. Enter your email and submit. Wait for the email. Download the zip files.
5. Put them in `reference/elevation/lidar_2019/` (this folder is in `.gitignore`). Then ask Claude to make the DSM and the building-height CSV.
