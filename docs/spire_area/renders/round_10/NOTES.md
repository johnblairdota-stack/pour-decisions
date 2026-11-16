# Spire area, round 10 (cloud, Cycles)

Builder: cloud session, 16 Nov 2026. Merged HSW r13 (182c93c: layout.py bridge colours). Same renderer as rounds 7-9.

## Fixes (round 9 critique)
1. **Mantra**: over the top ~4 floors the corner wing also flares out sideways about 5.5 m, curved like a fin
   (outward ~ height^2.2), still attached and nothing above the roof. The sign is dark blue lowercase "mantra"
   (#1b5fa8) on the cream top-floor wall, no panel; the top-floor balcony slabs and rails within 8 m of it are
   removed so they cannot cut the letters. Body cream a step warmer again (F2DBAE).
2. **Skies**: real gradients: cobalt zenith #1f5fb0 fading to #8fb8e0 with cumulus (cathedral views, fly_by_east),
   near-navy zenith #1a3f8f for spire_ann_st_2018, pale blue with denser thin cloud for orient_front /
   ann_queen_corner.
3. **Cathedral**: stone back to warm golden-tan (mean about #9a8a72) with grey-brown darks #6f6458 instead of violet,
   smaller blocks (UV scale 0.5 -> 0.72), golden dressings #c9a46a, near-black spires #2e2e33. Pink street banners
   removed.
4. **Foliage**: 7 more boxes in `pixel_kill` (cathedral_ann_st_2012 x3, carpark_eye speckle, customs_house blob,
   customs_house_river stump, orient_hotel cluster).
5. **Orient**: roof steeper (~32 deg) so it no longer reads as a thin visor; walls less yellow (CFAE8E).
6. **Lawns**: grass ramp #4f7a35 to #6b8f45 (was near-black olive).

## Not done yet
Admiralty copies that still read cream (fly_by_east, aerials: a different building record); QUEEN ST sign clipping;
porch / nave seating over the black gap; raised BUS ONLY; oversized wheel stops; Mantra stepped crown; Orient
verandah band and shutters; Ann St road patch; arrows/hatching; car park asphalt; camera fits; Deanery cliff.
Trees inside the keep-out zone (queen_st_willahra fork) left alone.
