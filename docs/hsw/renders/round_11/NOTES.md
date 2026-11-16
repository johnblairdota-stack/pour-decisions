# HSW + Story Bridge, round 11 (16 Nov 2026)

First round rendered in the CLOUD (John: keep Blender off his PC; it crashed it and costs game fps).
Renders only, as built, day light, no people, cars or boats.

## How to run (cloud, pip bpy 5.2.3, software GL)

    python3 -m venv bpyenv && bpyenv/bin/pip install bpy==5.2.3 numpy pillow
    apt-get install -y libegl1 libegl-mesa0 libgl1-mesa-dri libgbm1      # Eevee needs EGL (llvmpipe)
    HSW_TAA=8 bpyenv/bin/python runbpy.py tools/hsw/render_hsw.py <out> heroes photos scale=0.5
    # runbpy.py: import bpy; sys.argv = ["blender", "--", *args]; runpy.run_path(script, run_name="__main__")

About 1 min to build, 4-7 min per view at 800 px and 8 TAA samples; the full set takes ~110 min.
render_hsw.py now builds the mist compositor as a Blender 5 node group when `scene.node_tree` is gone
(the 4.x path is unchanged). Cloud renders are 800 px wide (PC rounds were 1600) and a touch paler/softer;
that is the renderer, not the model.

## Changes (critic round 10 list)
1. Crest apartment row: the 4 m LiDAR tiles are now 1-4 clean rectangular slabs per block (principal axis
   of the LiDAR cells, split along the long axis every ~35 m with 3 m gaps), each to its 95th-percentile DSM
   height + 1 m, a roof parapet, a white balcony band every 3 m on all faces and dark rails; cream/pale-yellow
   walls (`layout.HSW["lidar_blocks"]`).
2. Canopy: the lime set (~40 % of crowns) is now ~#9cbf3a-#c2d455, brighter lit tops, lobes 20 % larger so
   crowns overlap, crest palms cut to a fifth (fewer skyline sticks).
3. Bridge steel back halfway: (0.162, 0.178, 0.20), ~15 % darker than r09's mid blue-grey (p13 only).
4. Shed roofs mid galvanised grey (Felons, white shed, cream shed, Rivershed, glasshouse).
5. Fiume terrace: a dark base under the slab and a back/side wall.

## Edits to shared files (tell the Spire area thread)
- `layout.py`: `HSW["lidar_blocks"]` (slab keys, colours), `HSW["bridge_steel"]` (the bridge is lighter again
  in the Spire scene too).
- `tools/hsw/render_hsw.py` only for the cloud compositor / HSW_TAA.

## Photo fits: unchanged (no camera or landmark moved).

## Still open
Water Fresnel, far-field tree/roof carpet and horizon edge, ground paths/lawn, Rivershed east front and awning,
lift arm landing, cliff darker with talus, hotel cubes, p07 teal stack, re-solve p04/p13.
