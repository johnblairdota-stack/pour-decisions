"""Overview renders of the CBD extension (cbd_ext.py) in the master scene, Cycles CPU (cloud: pip bpy).

    CYC_SAMPLES=32 python tools/blender/spire/render_cbd.py <out_dir> [scale=0.75] [only=id,id]

Absolute camera positions (local metres, z metres AHD).
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy  # noqa: E402
from mathutils import Vector  # noqa: E402

import build_all  # noqa: E402
import preview as P  # noqa: E402

CAMS = [
    {"id": "cbd_top", "ortho": 1250.0, "pos": (-370, -1160, 900), "look_at": (-370, -1160, 0), "size": (1600, 1600),
     "note": "straight down over the extension: towers against the 2022 aerial"},
    {"id": "cbd_from_kangaroo_pt", "pos": (225, -1240, 40), "look_at": (-380, -1150, 55), "lens": 24,
     "note": "Kangaroo Point cliffs across the river, looking west at Skytower and 1 William St"},
    {"id": "cbd_oblique_se", "pos": (520, -2250, 520), "look_at": (-330, -1000, 40), "lens": 30,
     "note": "high from the SE over the river bend: the whole extension against the Spire square"},
    {"id": "cbd_from_southbank", "pos": (-880, -1420, 18), "look_at": (-470, -1150, 90), "lens": 26,
     "note": "South Bank side, looking NE over the river at Queen's Wharf and 1 William St"},
    {"id": "cbd_from_spire_roof", "pos": (-60, -150, 230), "look_at": (-330, -1150, 90), "lens": 35,
     "note": "from the Spire roof looking SW down the CBD"},
    {"id": "river_top", "ortho": 4300.0, "pos": (-150, -650, 3000), "look_at": (-150, -650, 0), "size": (1600, 1600),
     "note": "straight down over the river bends traced from the aerials"},
    {"id": "river_high_north", "pos": (300, 1600, 900), "look_at": (-150, -1200, 0), "lens": 26,
     "note": "high over Fortitude Valley looking south over the CBD bend, Kangaroo Point and the Milton reach"},
    {"id": "river_downstream", "pos": (1150, -950, 380), "look_at": (1800, 1300, 0), "lens": 26,
     "note": "high over Kangaroo Point looking NE downstream past New Farm"},
    {"id": "bridges_south_bank", "pos": (-1450, -2050, 260), "look_at": (-900, -900, 10), "lens": 24,
     "note": "from over West End looking NE: Goodwill, Captain Cook, Neville Bonner, Victoria, Kurilpa"},
    {"id": "bridges_milton_reach", "pos": (-1900, -300, 220), "look_at": (-1050, -750, 10), "lens": 26,
     "note": "from over Milton looking SE: Go Between, Merivale, William Jolly, Kurilpa, Victoria"},
    {"id": "bridges_kp_green", "pos": (480, -1380, 95), "look_at": (190, -940, 25), "lens": 26,
     "note": "from over Kangaroo Point looking NW along the Kangaroo Point Bridge to the city"},
    {"id": "roads_top", "ortho": 2600.0, "pos": (-900, -1000, 3000), "look_at": (-900, -1000, 0), "size": (1600, 1600),
     "note": "straight down over the south-west: roads, rail and bridges on the aerial"},
    {"id": "city_top", "ortho": 4200.0, "pos": (-46, -279, 3000), "look_at": (-46, -279, 0), "size": (1600, 1600),
     "note": "straight down over the whole 4 x 4 km LiDAR area"},
    {"id": "city_from_north", "pos": (-900, 1900, 420), "look_at": (-350, -600, 30), "lens": 28,
     "note": "from over Herston looking south: Spring Hill, the CBD and the river beyond"},
    {"id": "city_from_west", "pos": (-2300, -500, 300), "look_at": (-400, -800, 40), "lens": 28,
     "note": "from over Paddington looking east: Suncorp Stadium, Roma Street, the CBD"},
    {"id": "city_from_south", "pos": (-300, -2700, 330), "look_at": (-350, -900, 40), "lens": 28,
     "note": "from over Woolloongabba looking north: the Gabba, Kangaroo Point, South Bank, the CBD"},
    {"id": "road_riverside_expressway", "pos": (-600, -1295, 21), "look_at": (-505, -1440, 10), "lens": 28,
     "note": "over the Riverside Expressway deck by 1 William St: lane lines, lights, parapets"},
    {"id": "road_stanley_street", "pos": (455, -2600, 28), "look_at": (330, -2568, 6), "lens": 28,
     "note": "over Stanley St, Woolloongabba: markings, signals, street lights, house roofs"},
    {"id": "city_street_west_end", "pos": (-1500, -1450, 60), "look_at": (-700, -1000, 60), "lens": 30,
     "note": "low over West End roofs looking NE to the CBD"},
]


def setup_cycles(samples):
    sc = bpy.context.scene
    sc.render.engine = "CYCLES"
    c = sc.cycles
    c.device = "CPU"
    c.samples = samples
    c.use_adaptive_sampling = True
    c.adaptive_threshold = 0.03
    c.use_denoising = True
    c.max_bounces = 4
    c.diffuse_bounces = 2
    c.glossy_bounces = 2
    c.transmission_bounces = 4
    c.volume_bounces = 0
    c.transparent_max_bounces = 64
    for m in bpy.data.materials:                      # leaf cards matt (frosty crowns otherwise)
        if m.get("shader") == "leaf" and m.node_tree:
            for n in m.node_tree.nodes:
                if n.type == "BSDF_PRINCIPLED":
                    n.inputs["Specular IOR Level"].default_value = 0.08
                    n.inputs["Roughness"].default_value = 0.9


def shoot(c, out, scale):
    cam = P.camera("cam_cbd")
    if c.get("ortho"):
        cam.data.type = "ORTHO"
        cam.data.ortho_scale = c["ortho"]
    else:
        cam.data.type = "PERSP"
        cam.data.lens = c["lens"]
        cam.data.sensor_width = 36.0
    cam.data.clip_start, cam.data.clip_end = 1.0, 8000
    pos, look = Vector(c["pos"]), Vector(c["look_at"])
    cam.location = pos
    cam.rotation_euler = (look - pos).to_track_quat("-Z", "Y").to_euler()
    w, h = c.get("size", (1600, 900))
    P.hide(["logistics"], True)
    P.render(os.path.join(out, c["id"] + ".png"), int(w * scale), int(h * scale))


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]
    out = os.path.abspath(argv[0])
    os.makedirs(out, exist_ok=True)
    scale = float(next((a[6:] for a in argv if a.startswith("scale=")), 0.75))
    only = next((a[5:].split(",") for a in argv if a.startswith("only=")), None)
    build_all.build_all(None, write_meta=False)
    P.setup_morning()
    setup_cycles(int(os.environ.get("CYC_SAMPLES", "32")))
    for c in CAMS:
        if only and c["id"] not in only:
            continue
        shoot(c, out, scale)


if __name__ == "__main__":
    main()
