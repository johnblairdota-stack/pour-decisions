# OpenStreetMap reference — Riverlight, Hamilton (Northshore), Brisbane

Data © OpenStreetMap contributors, ODbL 1.0 (see LICENSE.md). Downloaded 2026-10-18.

Coordinates below are local metres from Riverlight's footprint centroid: +x = east, +y = north (flat-earth approximation, fine at this scale). Bearings are degrees clockwise from true north.

## How this was collected

- Overpass (overpass-api.de and 4 mirrors) could not be reached from this PC, so the data comes from the main OSM API (`api.openstreetmap.org/api/0.6/map.json`), downloaded in tiles and then filtered locally. The JSON files use the Overpass `out body geom;` layout (each way carries `geometry`), so code written for Overpass output reads them the same way.
- Local box: about ±1.5 km around Riverlight (lat -27.45716 to -27.43021, lon 153.07034 to 153.10070).
- Wide landmarks: the 6 km box was NOT downloaded in full. Instead: Sir Leo Hielscher (Gateway) Bridges relation 8611118 (full), Brisbane River water polygons 1627034 and 1693549 (full), Brisbane River centreline relation 2723358 (only the member ways that touch the 6 km box), Portside Wharf, Kingsford Smith Drive (Breakfast Creek to Hamilton strip), and buildings with height ≥ 80 m or ≥ 25 levels in a Brisbane CBD box (lat -27.4740 to -27.4610, lon 153.0180 to 153.0350; about 6 km west, at the edge of the 6 km box).

## Riverlight

- Geocode (Nominatim, "Riverlight, Hamilton QLD"): way 1153189757 "Riverlight Apartments", 320 MacArthur Avenue; Nominatim point -27.4436856, 153.0855156.
- "310 MacArthur Avenue, Hamilton QLD 4007": address node 6292435228 at -27.4441357, 153.0850265 (-48 m E, -51 m N).
- Footprint centroid: **-27.4436709, 153.0855133**.
- Footprint (way 1153189757): about **81.0 m × 21.8 m**, area 1530 m², long axis bearing **104° / 284°**. Tags: {"addr:housenumber":"320","addr:postcode":"4007","addr:state":"QLD","addr:street":"MacArthur Avenue","addr:suburb":"Hamilton","building":"yes","building:levels":"11","name":"Riverlight Apartments"}.
- OSM elements named "Riverlight": way 1153189756 "Riverlight North Apartments"; way 1153189757 "Riverlight Apartments".

## Buildings within 300 m (centroid distance)

| OSM id | name / address | building | levels | height | footprint (m) | long axis ° | dist m | bearing | x E m | y N m |
|---|---|---|---|---|---|---|---|---|---|---|
| 1153189757 | Riverlight Apartments | yes | 11 |  | 81×22 | 104 | 0 | 98° E | 0 | -0 |
| 1153189756 | Riverlight North Apartments | yes |  |  | 37×22 | 15 | 36 | 20° N | 12 | 34 |
| 1089801506 |  | yes |  |  | 35×21 | 106 | 80 | 218° SW | -50 | -63 |
| 864860916 |  | apartments | 4 |  | 62×43 | 137 | 170 | 99° E | 168 | -26 |
| 1074660043 | Riva Kitchen and Events | yes |  |  | 32×20 | 72 | 179 | 220° SW | -115 | -137 |
| 1082480814 |  | yes |  |  | 45×22 | 176 | 226 | 287° W | -216 | 66 |
| 1194945946 |  | yes |  |  | 11×9 | 123 | 296 | 44° NE | 206 | 213 |

7 buildings; 2 have levels or height tags.

## Roads within 300 m

| name | highway | nearest m | lanes | width | oneway | surface | sidewalk | ways |
|---|---|---|---|---|---|---|---|---|
| (unnamed) | service | 22 |  |  |  |  |  | 14 |
| (unnamed) | footway | 34 |  |  |  | paving_stones, concrete, paved |  | 52 |
| Angora Road | residential | 43 |  |  | no | asphalt |  | 1 |
| MacArthur Avenue | residential | 49 | 1 |  | no, yes | asphalt |  | 6 |
| Parkside Circuit | residential | 52 |  |  | no | asphalt |  | 2 |
| (unnamed) | unclassified | 58 |  |  |  |  |  | 1 |
| (unnamed) | residential | 66 | 1 |  |  | asphalt |  | 11 |
| (unnamed) | cycleway | 76 |  | 2 |  | concrete, asphalt, paved |  | 16 |
| Karakul Road | unclassified | 95 |  |  |  |  |  | 1 |
| MacArthur Avenue | unclassified | 134 | 1 |  | yes, no | asphalt |  | 4 |
| (unnamed) | path | 192 |  |  |  |  |  | 4 |
| Barcham Road | unclassified | 277 |  |  | no | asphalt |  | 1 |

## Key features (metres from Riverlight centre)

- Ferry terminal node 170910504 "Bretts Wharf": centre -2115 m E, 374 m N (2147 m, 280° W).
- Ferry terminal node 170908655 "Northshore Hamilton": centre -170 m E, -200 m N (263 m, 220° SW).
- Ferry terminal node 1726365549 "Apollo Road": centre -2144 m E, 58 m N (2145 m, 272° W).
- Ferry terminal way 566447532 "Brisbane Cruise Terminal": centre -1465 m E, 341 m N (1504 m, 283° W).
- Ferry terminal way 566447534 "Bretts Wharf": centre -2106 m E, 387 m N (2141 m, 280° W).
- Ferry terminal way 1059862948 "Apollo Road": centre -2147 m E, 45 m N (2147 m, 271° W).
- Ferry terminal way 318655544 "Northshore Hamilton": centre -164 m E, -181 m N (245 m, 222° SW).
- Park way 724658996 "(unnamed)": nearest edge 33 m E, -28 m N (43 m), centre -52 m E, -52 m N.
- Park way 34901774 "Northshore Riverside Park": nearest edge 54 m E, -34 m N (64 m), centre -58 m E, -120 m N.
- Park way 1285007493 "(unnamed)": nearest edge 185 m E, -83 m N (202 m), centre 206 m E, -80 m N.
- Park way 503313374 "(unnamed)": nearest edge -109 m E, 234 m N (258 m), centre -73 m E, 342 m N.
- Park way 1015733737 "(unnamed)": nearest edge -342 m E, -52 m N (346 m), centre -394 m E, -63 m N.
- Park way 1015733733 "Maritime Green Park": nearest edge -681 m E, 51 m N (683 m), centre -770 m E, 65 m N.
- Golf course relation 13987567 "Royal Queensland Golf Club": nearest edge 111 m E, 109 m N (156 m), centre 994 m E, 291 m N.
- Riverbank (Brisbane River water polygon, nearest point): -32 m E, -181 m N (184 m, 190° S).
- River crossing straight out from the site (same bearing): far bank at -116 m E, -650 m N; width along that line ≈ 476 m.
- River width at the site (shortest chord through the mid-river point): ≈ **473 m** (chord bearing 16°).
- Sir Leo Hielscher (Gateway) Bridges, relation 8611118: centre 1472 m E, -12 m N (1472 m, 90° E).
- Portside Wharf (way 33804234): centre -1555 m E, 325 m N (1589 m, 282° W).

## Tall CBD buildings (height ≥ 80 m or ≥ 25 levels): 73

| OSM id | name | height | levels | x E m | y N m |
|---|---|---|---|---|---|
| way 683336940 | Brisbane Skytower | 269.7 | 90 | -5609 | -3116 |
| way 44173034 | Aurora Tower | 207 | 69 | -5445 | -2384 |
| way 134816032 | One One One Eagle St | 195 | 53 | -5456 | -2654 |
| way 140808831 | Riparian Plaza | 188 | 53 | -5449 | -2713 |
| way 138278498 | Central Plaza 1 | 174 | 44 | -5575 | -2586 |
| way 243870312 | 180 Brisbane | 152 m | 34 | -6027 | -2566 |
| way 153545827 | 400 George | 150 m | 34 | -6389 | -2754 |
| way 236155564 | Skyline Apartments | 150 m | 47 | -5204 | -2105 |
| way 153545818 | Santos Place | 146 m | 38 | -6424 | -2788 |
| way 141453792 |  | 145 | 30 | -5927 | -3196 |
| way 49748184 | M on Mary | 143 m | 43 | -5803 | -3138 |
| way 224320345 | Macrossan Residences | 143 m | 37 | -5247 | -2095 |
| way 144179730 | 275 George St | 142 m | 32 | -6186 | -2882 |
| way 134816031 | Riverside Centre | 142 | 40 | -5445 | -2597 |
| way 128686875 | Oaks Charlotte Towers | 138 | 44 | -5747 | -2944 |
| way 140804995 | Waterfront Place | 138 | 40 | -5433 | -2943 |
| way 481145058 | Abian | 136 | 41 | -5637 | -3291 |
| way 140794397 | Festival Towers | 135 m | 42 | -5823 | -3087 |
| way 24317212 | AMP Place | 135 | 35 | -5500 | -2823 |
| way 141282241 | Hitachi | 134 m | 30 | -6154 | -2933 |
| way 140808722 | Blue Tower | 134 | 35 | -5519 | -2738 |
| way 140804554 |  | 133 m | 40 | -5501 | -2967 |
| way 186586603 | Spire Residences | 131.1 |  | -5405 | -2139 |
| way 1465613265 | The Westin Brisbane | 130.6 | 38 | -5633 | -3072 |
| way 140792852 | Education House | 130 m | 30 | -5862 | -3187 |
| way 101469133 | King George Central | 129 | 27 | -6004 | -2675 |
| way 141295842 | State Law Building | 128 m | 30 | -6274 | -2802 |
| way 140806846 |  | 127 m | 29 | -5804 | -2978 |
| way 141318819 |  | 126 m | 28 | -5787 | -2617 |
| way 26386543 | Admiralty Towers II | 126 m | 38 | -5284 | -2241 |
| way 140794201 | River City Apartments | 124 |  | -5695 | -3126 |
| way 93414424 |  | 122 m | 27 | -5628 | -2626 |
| way 146581572 |  | 120 |  | -5534 | -2393 |
| way 373595546 |  | 118 | 26 | -6123 | -2621 |
| way 568836537 | Mantra on Queen | 118 m | 30 | -5397 | -2053 |
| way 26326112 |  | 114 | 27 | -5712 | -2183 |
| way 141453889 | HSBC | 114 m | 25 | -5694 | -2606 |
| way 141456531 |  | 112 |  | -5923 | -2622 |
| way 140798228 | Mineral House | 110 | 30 | -5822 | -3301 |
| way 135843087 | Central Plaza 2 | 110 | 30 | -5539 | -2617 |
| way 141195287 | Matisse Tower | 109 m | 24 | -5709 | -3064 |
| way 141622215 | Westpac | 109 m | 24 | -5755 | -2646 |
| way 140794202 | Four Points by Sheraton | 107 | 33 | -5661 | -3115 |
| way 141454227 | Terrica Place | 105 | 24 | -5742 | -2491 |
| way 141622865 |  | 103.2 |  | -6088 | -2600 |
| way 49233018 |  | 102 |  | -5648 | -2353 |
| way 140998705 |  | 100 m | 25 | -5911 | -2866 |
| way 141453919 |  | 100 |  | -5695 | -2541 |
| way 141195067 | River Park Central | 99 m | 29 | -5696 | -3046 |
| way 26253094 | Marriott | 96 m |  | -5310 | -2189 |
| way 136558076 | Emirates House | 96 m | 24 | -5424 | -2472 |
| way 136558081 |  | 96 m | 19 | -5405 | -2443 |
| way 185027629 | 127 Creek Street | 96 |  | -5704 | -2437 |
| way 26252651 | Sofitel Brisbane Central | 95 |  | -5886 | -2417 |
| way 481491826 | Mantra Midtown | 95 m | 28 | -5710 | -2996 |
| way 140799323 |  | 93 m | 27 | -5979 | -3126 |
| way 144178180 | The Grosvenor | 93 m | 27 | -5483 | -3151 |
| way 141453900 | Brisbane Club Tower | 93 m | 20 | -5728 | -2578 |
| way 141621913 |  | 90 m | 22 | -5686 | -2897 |
| way 141295835 | Northbank Plaza | 89 m | 22 | -6198 | -2822 |
| way 26253703 |  | 89 m | 22 | -5403 | -2356 |
| way 49748172 | Worley Parsons | 88 |  | -5714 | -3205 |
| way 140809654 | InterContinental | 87 m |  | -5799 | -2815 |
| way 26386571 | Admiralty Towers I | 87 m | 28 | -5227 | -2169 |
| way 125720072 | Quay West | 86 m | 25 | -5676 | -3327 |
| way 26253098 | Willahra Towers | 86 m | 25 | -5387 | -2169 |
| way 243893440 | Brisbane City Hall Clock Tower | 85 |  | -6101 | -2775 |
| way 49233010 |  | 82 |  | -5624 | -2384 |
| way 26253030 | Oracle | 80 |  | -5525 | -2308 |
| way 141295964 | Heritage Lanes | 39 m | 34 | -6237 | -2762 |
| way 141194516 | Oaks on Margaret |  | 31 | -5636 | -3149 |
| way 141318681 |  |  | 26 | -5781 | -2687 |
| way 1554383917 |  |  | 30 | -5742 | -2067 |

## Map image

- `osm_map_z17.png`: 1280 × 1280 px, 5 × 5 OSM standard tiles at zoom 17 (x 121270–121274, y 75931–75935), about 1.06 m per pixel (≈ 1.36 km square). Riverlight centre (red cross) is at pixel (700, 637). The raw tiles are not in git.

## Gaps and caveats

- No OSM `height` tag on Riverlight; only `building:levels=11` on the main block. Riverlight North has no levels tag. Most nearby buildings have no levels or height.
- No road `width` tags near the site (only `lanes=1` on parts of MacArthur Avenue and `width=2` on a cycleway). Kingsford Smith Drive is more than 300 m away (it is in `osm_landmarks_wide.json`).
- The CityCat stop for the site is "Northshore Hamilton" (node 170908655 / way 318655544). Bretts Wharf, Apollo Road and the cruise terminal are listed for context.
- River width is measured on the OSM water polygon; it includes wharf and berth water on the south bank, so treat ≈ 470 m as an upper value (the map shows about 420 m bank to bank straight south of the site).
- No `roof:shape`, `roof:colour` or `building:colour` tags were found on the buildings within 300 m.
