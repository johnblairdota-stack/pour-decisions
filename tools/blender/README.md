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
  hand tools, rigging) -> `assets/props/props.glb`.
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
  estate next door (`data/hamilton_reach_2017.json`, traced off the 2017
  aerial by `tools/estate_to_game.py`) and the corrugated sheds
  (`shaders/cladding.gdshader`).

Materials are named by what they are (`skin`, `vest`, `hat`, `tape` ...). The
game replaces each with its own toon material and outline by that name
(`factory.gd`, `CREW_COLORS`), so the colours in Blender are only previews.

To check a batch in the game's own look:

    godot --path . --script res://tools/asset_gallery.gd -- --out=/tmp/gallery --set=crew   # or props, plant, towers, site, trees, street, water, river, buildings, estate
