# Brisbane model: coverage

Made by `python3 tools/city/coverage.py`. Don't edit by hand. Rules and the detail ladder are in
[METHOD.md](METHOD.md).

![Coverage map](coverage.svg)

Dark blue: measured tile with hand-built landmarks. Light blue: measured tile (2019 LiDAR). Grey: map and
aerial photo only. Dashed orange and dotted purple: the next two LiDAR orders. Numbers in the tiles are
building counts. Black dots are landmarks built by hand, white dots are landmarks still waiting.

| Measure | Now |
| --- | --- |
| Measured tiles (1 km each) | 71 |
| Share of Brisbane City (1343 km2) | 5.3 % |
| Buildings | 32281 (30799 with a measured height) |
| Trees | 211298 |
| Tiles with a hand-built landmark | 4 |
| Hand-built landmarks | 10 |
| Photo pairs (render matched to a photo) | 66 |
| City-wide buildings sharing one facade recipe | 95 % |
| Landmarks inside the model but still plain blocks | City Hall, Roma Street Parkland, Suncorp Stadium, XXXX Brewery, The Gabba, RNA Showgrounds, Brisbane Powerhouse, Breakfast Creek Hotel, Portside Wharf (Alcyone), Riverlight, UQ Great Court, Gateway Bridge |
| Landmarks outside the measured model | Mt Coot-tha lookout |
| Tiles in the next LiDAR orders | 1-fill: 0, 2-downriver: 0 |

## Measured tiles

| Tile | Grade | Buildings | Trees | Photo pairs | Hand-built | Waiting |
| --- | --- | --- | --- | --- | --- | --- |
| 503_6965 | 2 | 655 | 2730 | 0 |  |  |
| 504_6965 | 2 | 666 | 2685 | 0 |  |  |
| 505_6965 | 2 | 1065 | 4226 | 0 |  |  |
| 506_6965 | 2 | 323 | 3342 | 0 |  |  |
| 507_6965 | 2 | 54 | 2391 | 0 |  |  |
| 508_6965 | 2 | 114 | 1889 | 0 |  |  |
| 509_6965 | 2 | 36 | 1848 | 0 |  |  |
| 503_6964 | 2 | 264 | 2336 | 0 |  |  |
| 504_6964 | 2 | 341 | 2078 | 0 |  | Breakfast Creek Hotel |
| 505_6964 | 2 | 642 | 2408 | 0 |  |  |
| 506_6964 | 2 | 111 | 1759 | 0 |  | Portside Wharf (Alcyone) |
| 507_6964 | 2 | 133 | 950 | 0 |  |  |
| 508_6964 | 2 | 43 | 1512 | 0 |  | Riverlight |
| 509_6964 | 2 | 9 | 630 | 0 |  | Gateway Bridge |
| 498_6963 | 2 | 25 | 3844 | 0 |  |  |
| 499_6963 | 2 | 274 | 3764 | 0 |  |  |
| 500_6963 | 2 | 774 | 4195 | 0 |  |  |
| 501_6963 | 2 | 238 | 3015 | 0 |  |  |
| 502_6963 | 2 | 284 | 2575 | 0 |  |  |
| 503_6963 | 2 | 416 | 2826 | 0 |  | RNA Showgrounds |
| 504_6963 | 2 | 422 | 2677 | 0 |  |  |
| 505_6963 | 2 | 190 | 2955 | 0 |  |  |
| 506_6963 | 2 | 88 | 3667 | 0 |  |  |
| 507_6963 | 2 | 37 | 1757 | 0 |  |  |
| 508_6963 | 2 | 28 | 1174 | 0 |  |  |
| 509_6963 | 2 | 29 | 2040 | 0 |  |  |
| 498_6962 | 2 | 726 | 3717 | 0 |  |  |
| 499_6962 | 2 | 1060 | 4152 | 0 |  |  |
| 500_6962 | 2 | 1312 | 3971 | 0 |  | Suncorp Stadium |
| 501_6962 | 2 | 720 | 3232 | 0 |  | Roma Street Parkland |
| 502_6962 | 3 | 894 | 3705 | 4 | St John's Cathedral |  |
| 503_6962 | 3 | 693 | 4408 | 17 | Spire Residences, Story Bridge, Howard Smith Wharves, Customs House |  |
| 504_6962 | 2 | 1359 | 4044 | 0 |  |  |
| 505_6962 | 2 | 17 | 2902 | 0 |  |  |
| 506_6962 | 2 | 59 | 3817 | 0 |  |  |
| 507_6962 | 2 | 54 | 2808 | 0 |  |  |
| 508_6962 | 2 | 34 | 2821 | 0 |  |  |
| 509_6962 | 2 | 0 | 3203 | 0 |  |  |
| 498_6961 | 2 | 326 | 3663 | 0 |  |  |
| 499_6961 | 2 | 1178 | 4018 | 0 |  |  |
| 500_6961 | 2 | 492 | 2271 | 0 |  | XXXX Brewery |
| 501_6961 | 2 | 243 | 1784 | 0 |  |  |
| 502_6961 | 3 | 455 | 3047 | 31 | Brisbane Skytower, Queen's Wharf | City Hall |
| 503_6961 | 2 | 195 | 3278 | 2 |  |  |
| 504_6961 | 2 | 954 | 3572 | 0 |  |  |
| 505_6961 | 2 | 126 | 2539 | 0 |  | Brisbane Powerhouse |
| 506_6961 | 2 | 27 | 3714 | 0 |  |  |
| 507_6961 | 2 | 142 | 3352 | 0 |  |  |
| 508_6961 | 2 | 81 | 3427 | 0 |  |  |
| 509_6961 | 2 | 81 | 2862 | 0 |  |  |
| 498_6960 | 2 | 341 | 3505 | 0 |  |  |
| 499_6960 | 2 | 587 | 3033 | 0 |  |  |
| 500_6960 | 2 | 781 | 2395 | 0 |  |  |
| 501_6960 | 2 | 896 | 3061 | 0 |  |  |
| 502_6960 | 3 | 211 | 3351 | 11 | 1 William St, South Bank and BRISBANE sign, City Botanic Gardens |  |
| 503_6960 | 2 | 702 | 2971 | 1 |  |  |
| 504_6960 | 2 | 752 | 2936 | 0 |  |  |
| 498_6959 | 2 | 213 | 3474 | 0 |  |  |
| 499_6959 | 2 | 550 | 2323 | 0 |  |  |
| 500_6959 | 2 | 1054 | 2933 | 0 |  |  |
| 501_6959 | 2 | 1030 | 3533 | 0 |  |  |
| 502_6959 | 2 | 986 | 3383 | 0 |  |  |
| 503_6959 | 2 | 633 | 2939 | 0 |  | The Gabba |
| 504_6959 | 2 | 519 | 3742 | 0 |  |  |
| 498_6958 | 2 | 370 | 3827 | 0 |  |  |
| 499_6958 | 2 | 1119 | 3737 | 0 |  |  |
| 500_6958 | 2 | 791 | 3366 | 0 |  |  |
| 501_6958 | 2 | 199 | 2101 | 0 |  | UQ Great Court |
| 502_6958 | 2 | 315 | 2782 | 0 |  |  |
| 503_6958 | 2 | 514 | 2794 | 0 |  |  |
| 504_6958 | 2 | 536 | 3532 | 0 |  |  |
