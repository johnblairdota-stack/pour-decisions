# Brisbane model: coverage

Made by `python3 tools/city/coverage.py`. Don't edit by hand. Rules and the detail ladder are in
[METHOD.md](METHOD.md).

![Coverage map](coverage.svg)

Dark blue: measured tile with hand-built landmarks. Light blue: measured tile (2019 LiDAR). Grey: map and
aerial photo only. Dashed orange and dotted purple: the next two LiDAR orders. Numbers in the tiles are
building counts. Black dots are landmarks built by hand, white dots are landmarks still waiting.

| Measure | Now |
| --- | --- |
| Measured tiles (1 km each) | 32 |
| Share of Brisbane City (1343 km2) | 2.4 % |
| Buildings | 19782 (19310 with a measured height) |
| Trees | 101177 |
| Tiles with a hand-built landmark | 4 |
| Hand-built landmarks | 10 |
| Photo pairs (render matched to a photo) | 66 |
| City-wide buildings sharing one facade recipe | 93 % |
| Landmarks inside the model but still plain blocks | City Hall, Roma Street Parkland, XXXX Brewery, RNA Showgrounds, UQ Great Court |
| Landmarks outside the measured model | Suncorp Stadium, The Gabba, Brisbane Powerhouse, Breakfast Creek Hotel, Portside Wharf (Alcyone), Riverlight, Mt Coot-tha lookout, Gateway Bridge |
| Tiles in the next LiDAR orders | 1-fill: 10, 2-downriver: 29 |

## Measured tiles

| Tile | Grade | Buildings | Trees | Photo pairs | Hand-built | Waiting |
| --- | --- | --- | --- | --- | --- | --- |
| 501_6963 | 2 | 238 | 3029 | 0 |  |  |
| 502_6963 | 2 | 284 | 2575 | 0 |  |  |
| 503_6963 | 2 | 416 | 2836 | 0 |  | RNA Showgrounds |
| 504_6963 | 2 | 422 | 2704 | 0 |  |  |
| 501_6962 | 2 | 718 | 3244 | 0 |  | Roma Street Parkland |
| 502_6962 | 3 | 894 | 3705 | 4 | St John's Cathedral |  |
| 503_6962 | 3 | 693 | 4408 | 17 | Spire Residences, Story Bridge, Howard Smith Wharves, Customs House |  |
| 504_6962 | 2 | 1359 | 4060 | 0 |  |  |
| 498_6961 | 2 | 326 | 3679 | 0 |  |  |
| 499_6961 | 2 | 1178 | 4037 | 0 |  |  |
| 500_6961 | 2 | 491 | 2283 | 0 |  | XXXX Brewery |
| 501_6961 | 2 | 243 | 1789 | 0 |  |  |
| 502_6961 | 3 | 455 | 3052 | 31 | Brisbane Skytower, Queen's Wharf | City Hall |
| 503_6961 | 2 | 195 | 3292 | 2 |  |  |
| 504_6961 | 2 | 952 | 3601 | 0 |  |  |
| 498_6960 | 2 | 341 | 3505 | 0 |  |  |
| 499_6960 | 2 | 587 | 3033 | 0 |  |  |
| 500_6960 | 2 | 781 | 2402 | 0 |  |  |
| 501_6960 | 2 | 896 | 3061 | 0 |  |  |
| 502_6960 | 3 | 211 | 3403 | 11 | 1 William St, South Bank and BRISBANE sign, City Botanic Gardens |  |
| 503_6960 | 2 | 696 | 2984 | 1 |  |  |
| 504_6960 | 2 | 748 | 2970 | 0 |  |  |
| 498_6959 | 2 | 213 | 3474 | 0 |  |  |
| 499_6959 | 2 | 550 | 2344 | 0 |  |  |
| 500_6959 | 2 | 1054 | 2949 | 0 |  |  |
| 501_6959 | 2 | 1030 | 3536 | 0 |  |  |
| 502_6959 | 2 | 983 | 3391 | 0 |  |  |
| 498_6958 | 2 | 370 | 3827 | 0 |  |  |
| 499_6958 | 2 | 1119 | 3737 | 0 |  |  |
| 500_6958 | 2 | 791 | 3366 | 0 |  |  |
| 501_6958 | 2 | 199 | 2103 | 0 |  | UQ Great Court |
| 502_6958 | 2 | 315 | 2798 | 0 |  |  |
