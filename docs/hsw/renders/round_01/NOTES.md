# HSW + Story Bridge, round 1 (15 Nov 2026)

Renders only (photos stay in PourDecisions-sites, never in git). Stage: AS BUILT, day light.

## How to run (John's PC, Blender 4.5)

    blender -b --factory-startup -P tools/hsw/render_hsw.py -- <out_dir> heroes photos [only=id,..] [scale=0.5]
    <blender python> -I tools/hsw/hsw_fit.py [ids]          # solve photo cameras from tools/hsw/hsw_marks.json
    <blender python> -I tools/hsw/export_round.py <sites> <render_dir> 1 <pair ids> <hero ids>
    <blender python> -I -u tools/hsw/fetch_refs.py <sites> [collect download manifest sheets]   # reference photos

## Built this round
- Story Bridge (`landmarks.py`): grey-green steel, K panels in the deep panels, lattice portal bracing at the
  towers, deck underside (floor beams, 6 stringers, X bracing, approach plate girders), rail posts and lamp arms.
  Main piers rebuilt as one cream portal ACROSS the bridge with a round-headed arch under the road, plinth,
  string course, keystone band, pilasters, cornice (photos: from the river and from Kangaroo Pt show it face-on).
- HSW (`hsw_hero.py`, numbers in `layout.HSW`): 1 m terrain patch (paving, lawns from OSM, tuff cliff shader with
  benches, iron staining and wet streaks, scrub banks, dark river bank), ~1,800 cliff bushes; heritage sheds with
  sheet roofs, verandahs, decks on piles, roof letters FELONS BREWING CO and HSW; Felons Barrel Hall saw-tooth roof
  with glazed ends; Stanley (two storeys, hipped); glasshouses; Mr Percival's octagon with lantern on its deck;
  corten lift tower (position triangulated from 3 solved photos) + zigzag stair + link bridge; riverwalk deck on
  cantilevers with balustrade and lamps; ferry terminal pontoon, canopy, gangways; Wilson Outlook fence;
  hotel saw-tooth chevron facade (white + charcoal); mangrove fringe on the Kangaroo Pt bank.
- Brisbane River water: browner, less mirror (shared with Spire).

## Photo fits (px on the photo's own size)
| id | rms | max | photo size |
|---|---|---|---|
| p01_drone_se | 23.7 | 39.2 | 1600x1067 |
| p04_drone_dusk_se | 24.6 | 32.8 | 1051x791 |
| p06_drone_south | 10.6 | 18.9 | 1200x650 |
| p07_drone_sw_citycat | 21.1 | 33.1 | 1600x900 |
| p09_pier_face_on | 58.1 | 94.4 | 1600x1200 |
| p10_drone_lawns_se | 7.8 | 11.9 | 1000x562 |

Not used (did not solve to a believable spot): p02 (under the deck, south-west), p08 and p11 (Kangaroo Pt bank).

## Known gaps
- Only 6 good photo pairs (brief asked 10-12). Ground-level photos solve badly: few sharp landmarks and the
  lift tower / Felons / pier proportions in the model are still a few metres off (pier thickness assumed 10 m).
- Hotel: chevron fins only on river/east faces; lower floors, pool deck and rooftop not modelled.
- Shed walls read too solid; Felons should be mostly open/glass under a deep verandah.
- Cliff-top trees come from LiDAR tree points (generic shapes); no figs/vines hanging over the edge yet.
- No planters, umbrellas, palms along the riverwalk; lawns flat green; paths through the lawns not drawn.
- Bowen Tce houses and apartments are generic boxes.
- Barrel Hall site: an artist render (MMXXI, red brick arches) in the reference set is a proposal, not built.
- Dusk photos rendered in day light (night look later).
