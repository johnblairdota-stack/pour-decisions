# Blender asset scripts

Each modelled asset is a Python script that builds it in Blender and exports
a `.glb` into `assets/`. Change a number, re-run, and Godot re-imports it.

    pip install bpy==5.2.3          # Blender as a Python module (Python 3.13)
    python tools/blender/crew.py    # -> assets/crew/crew.glb

Or open Blender 5.2, Scripting tab, open the script and Run.

- `kit.py`: shared helpers. Everything is written in Godot's coordinates
  (y up, +z = the way a character faces) so numbers match `scripts/factory.gd`.
- `crew.py`: the crew (body, hard hat, the eight named looks, each job's kit).
- `props.py`: tools in hand and on deck (screed, poker, clamp, pipe, slump kit,
  hand tools, rigging, the two-part bull float, washout sponge ball, wash-down
  gun, tag line eye) -> `assets/props/props.glb`.
- `plant.py`: the agitator truck (cab, chassis, drum with livery spiral, chute)
  and the line pump with its hopper -> `assets/plant/plant.glb`.
- `towers.py`: the boom tower's lattice sections, collar, turret and arms, the
  builder's hoist (mast sections, cage) and the tower crane -> `assets/plant/towers.glb`.
- `site.py`: the site set-up (sheds, loos, fencing, skip and bins, laydown, gas,
  genset, light tower, safety kit, crib corner, washout bay) -> `assets/site/site.glb`,
  placed by `scripts/yard.gd`; also the blue edge screens round the top floors.
- `trees.py`: fourteen local species (Moreton Bay fig, jacaranda, poinciana,
  spotted gum, paperbark, tuckeroo, she-oak, cabbage and foxtail palms,
  pandanus, grey mangrove, bottlebrush, lomandra), each with a `...Far`
  stand-in -> `assets/nature/trees.glb`, drawn as multimeshes by
  `scripts/flora.gd` (materials there, not in `factory.gd`) where
  `scripts/surrounds.gd` plants them.
- `street.py`: street and park furniture (street and park lights, bus shelter,
  benches, bins, bubbler, BBQ shelter, picnic tables, signs, bike hoops, the
  riverwalk railing) -> `assets/street/street.glb`, drawn by `scripts/street.gd`
  where `scripts/surrounds.gd` places them, with the kerbs and centre lines.
- `water.py`: the river (tinny, yachts, cruiser, rowing eight, channel piles,
  mooring buoy, pontoon, rock wall stones, the cruise ship at Portside) ->
  `assets/water/water.glb`, placed by `scripts/water.gd`; the water itself is
  `shaders/river.gdshader`.
- `buildings.py`: the neighbours (two-storey rendered houses, a high-set
  Queenslander, a post-war brick house, few-triangle `...Far` houses for the
  haze, roof kit: air conditioners, lift overrun, solar panels, whirlybird;
  20 and 40 foot shipping containers) -> `assets/buildings/buildings.glb`,
  placed by `scripts/neighbours.gd`, which also draws the Hamilton Reach
  estate next door (`data/hamilton_reach.json`, traced off the 2017
  and 2022 aerials by `tools/estate_to_game.py`) and the corrugated sheds
  (`shaders/cladding.gdshader`).
- `people.py`: the public (a chibi in civvies with the crew's joints, and
  extras for hair, hats, sunnies, backpacks, a coffee, a phone, a dog lead;
  a dog, a bicycle, a pram) -> `assets/people/people.glb`, walked along the
  map's paths by `scripts/people.gd`.
- `cars.py`: the traffic (sedan, hatch, SUV, dual-cab ute with a rack, van,
  a city bus, and 24-triangle far boxes) -> `assets/cars/cars.glb`. The
  body is white so `scripts/cars.gd` gives each car its own colour; it
  drives them along the real roads and parks the riverside car park traced in
  `tools/estate_to_game.py`.
- `citycat.py`: the CityCat (a 25 m catamaran, bow towards +x) and the
  Northshore Hamilton terminal (pontoon, shelter, gangway spans, landing)
  -> `assets/citycat/citycat.glb`, placed by `scripts/citycat.gd`; the same
  boat does the top-out fly-past.
- `fences.py`: fences and gates, a 3 m bay each (chain-link, palisade,
  Colorbond, timber paling, slat fence, pool glass, low wall, park bollards)
  plus sliding, driveway, pedestrian and boom gates ->
  `assets/fences/fences.glb`, laid round the estate, car yards, sheds, golf
  course and park by `scripts/fences.gd`.
- `wildlife.py`: brush-turkey, white ibis, masked lapwing, bush
  stone-curlew, magpie, kookaburra, rainbow lorikeet, pelican, koala,
  brushtail possum and eastern water dragon -> `assets/wildlife/wildlife.glb`,
  with Head, Tail, Leg and Wing joints that `scripts/wildlife.gd` moves
  (walking and pecking, flocks flying, pelicans drifting; possums only on a
  dawn pour).
- `cash.py`: Site Cash, the crew's money: a made-up note (tinted per
  denomination, the amount printed on it by the game), a wad, a leather
  wallet closed and open -> `assets/props/cash.glb`, painted by
  `scripts/cash_art.gd` (which also draws the note and wallet as SVG for the
  phones).
- `ute_kit.py`: 4x4 and camping gear for the Hilux, Ranger and Shark (bull
  bar, winch, spotlights, snorkel, light bar, mud tyres, roof rack, rooftop
  tent, awning, canopy, drawers, fridge, jerry cans, swag), each fitted to
  each ute as `kit_<item>_<ute>` -> `assets/cars/ute_kit.glb`, painted by
  `scripts/ute_kit.gd`.
- `smoko.py`: the coffee van at the Angora Rd gate (hatch propped open on its
  kerb side, counter, espresso machine, roof sign, A-frame menu board), a
  pulp four-cup tray, a takeaway cup, a meat pie and a sausage roll ->
  `assets/props/smoko.glb`, painted by `scripts/smoko_art.gd` (the food
  without outlines).

Effects that go with these models (Godot only, no Blender):

- `scripts/poker_fx.gd`: the poker's air bubbles (swell, wobble, pop with a
  ring and spatter), the churned froth round it, the glossy cream once the
  spot's compacted and the bleed-water puddle if it's held too long.
- `scripts/spray_fx.gd`: the wash-down jet from the `HoseGun` prop, drops
  that arc and splash, and `hose()` for the hose itself.
- `scripts/rope_fx.gd`: a sagging laid rope between two points (the climb
  section's second tag line, tied on with the `TagLineEye` prop).

Materials are named by what they are (`skin`, `vest`, `hat`, `tape` ...). The
game replaces each with its own toon material and outline by that name
(`factory.gd`, `CREW_COLORS`), so the colours in Blender are only previews.

To check a batch in the game's own look:

    godot --path . --script res://tools/asset_gallery.gd -- --out=/tmp/gallery --set=crew   # or props, plant, towers, site, trees, street, water, river, buildings, estate, people, crowd, cars, traffic, citycat, terminal, fences, fencing, wildlife, critters
