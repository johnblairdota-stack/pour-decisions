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
  placed by `scripts/yard.gd`.

Materials are named by what they are (`skin`, `vest`, `hat`, `tape` ...). The
game replaces each with its own toon material and outline by that name
(`factory.gd`, `CREW_COLORS`), so the colours in Blender are only previews.

To check a batch in the game's own look:

    godot --path . --script res://tools/asset_gallery.gd -- --out=/tmp/gallery --set=crew   # or props, plant, towers, site
