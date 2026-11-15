"""Render HSW + Story Bridge views (as built, morning look).

    blender -b --factory-startup -P tools/hsw/render_hsw.py -- <out_dir> [heroes] [photos] [only=id1,id2] [scale=0.5]

heroes: layout.HSW_HERO_CAMERAS (pos / look_at in absolute metres AHD) -> <out_dir>/hero_<id>.png
photos: tools/hsw/hsw_cams.json (solved by photo_fit.py from tools/hsw/hsw_marks.json) -> <out_dir>/<id>_render.png
"""
import json
import math
import os
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
SPIRE = os.path.join(os.path.dirname(HERE), "blender", "spire")
sys.path.insert(0, SPIRE)
import bpy  # noqa: E402
from mathutils import Vector  # noqa: E402

import layout as L  # noqa: E402
import build_all  # noqa: E402
import preview as P  # noqa: E402


def place(cam, pos, look, lens, shift_y=0.0):
    cam.data.type = "PERSP"
    cam.data.sensor_fit = "AUTO"
    cam.data.sensor_width = 36.0
    cam.data.lens = lens
    cam.data.shift_x = 0.0
    cam.data.shift_y = shift_y
    cam.data.clip_start, cam.data.clip_end = 0.3, 6000
    cam.location = pos
    d = Vector(look) - Vector(pos)
    if shift_y:
        d.z = 0.0
    cam.rotation_euler = d.to_track_quat("-Z", "Y").to_euler()


def horizon():
    """Round 3: a hazy ridge silhouette ring far out, and a compositor mist pass that fades distance toward a
    warm haze (a world volume blacks out Eevee). The sky itself (mist = 1) is left alone."""
    import random
    sc = bpy.context.scene
    R = L.HSW["ridge"]
    rnd = random.Random(3)
    n = 180
    cx, cy = 640.0, 60.0
    hs = []
    h = sum(R["h_m"]) / 2
    for i in range(n):
        h = min(max(h + rnd.uniform(-18, 18), R["h_m"][0]), R["h_m"][1])
        hs.append(h)
    verts, faces = [], []
    for i in range(n):
        a = 2 * math.pi * i / n
        d = R["dist_m"] * (1 + 0.15 * math.sin(3 * a))
        x, y = cx + d * math.cos(a), cy + d * math.sin(a)
        verts += [(x, y, -5.0), (x, y, hs[i])]
    for i in range(n):
        j = (i + 1) % n
        faces.append((2 * i, 2 * j, 2 * j + 1, 2 * i + 1))
    me = bpy.data.meshes.new("hsw_far_ridge")
    me.from_pydata(verts, [], faces)
    ob = bpy.data.objects.new("hsw_far_ridge", me)
    m = bpy.data.materials.new("hsw_far_ridge")
    m.use_nodes = True
    m.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (*R["rgb"], 1)
    ob.data.materials.append(m)
    sc.collection.objects.link(ob)
    M = L.HSW["mist"]
    sc.view_layers[0].use_pass_mist = True
    ms = sc.world.mist_settings
    ms.start, ms.depth, ms.falloff = M["start_m"], M["depth_m"], "LINEAR"
    sc.use_nodes = True
    nt = sc.node_tree
    for nd in list(nt.nodes):
        nt.nodes.remove(nd)
    rl = nt.nodes.new("CompositorNodeRLayers")
    comp = nt.nodes.new("CompositorNodeComposite")
    lt = nt.nodes.new("CompositorNodeMath")
    lt.operation = "LESS_THAN"
    lt.inputs[1].default_value = 0.999
    nt.links.new(rl.outputs["Mist"], lt.inputs[0])
    mul = nt.nodes.new("CompositorNodeMath")
    mul.operation = "MULTIPLY"
    nt.links.new(rl.outputs["Mist"], mul.inputs[0])
    nt.links.new(lt.outputs[0], mul.inputs[1])
    mul2 = nt.nodes.new("CompositorNodeMath")
    mul2.operation = "MULTIPLY"
    nt.links.new(mul.outputs[0], mul2.inputs[0])
    mul2.inputs[1].default_value = M["strength"]
    mix = nt.nodes.new("CompositorNodeMixRGB")
    nt.links.new(mul2.outputs[0], mix.inputs[0])
    nt.links.new(rl.outputs["Image"], mix.inputs[1])
    mix.inputs[2].default_value = (*M["rgb"], 1)
    nt.links.new(mix.outputs[0], comp.inputs["Image"])


def main():
    argv = sys.argv[sys.argv.index("--") + 1:]
    out = argv[0]
    os.makedirs(out, exist_ok=True)
    only = next((a[5:].split(",") for a in argv if a.startswith("only=")), None)
    scale = float(next((a[6:] for a in argv if a.startswith("scale=")), 1.0))
    t = time.time()
    build_all.build_all(None, write_meta=False)
    print("build %.1fs" % (time.time() - t))
    P.setup_morning()
    P.hide(["logistics"])
    horizon()
    cam = P.camera("cam_hsw")
    if "heroes" in argv:
        for c in L.HSW_HERO_CAMERAS:
            if only and c["id"] not in only:
                continue
            place(cam, c["pos"], c["look_at"], c["lens_mm"], c.get("shift_y", 0.0))
            cam.data.clip_start = c.get("clip_m", 0.3)
            P.apply_light(*L.sun_position(c.get("date", "2024-04-15"), c.get("hour", 9.0)))
            w, h = c.get("size", (1600, 900))
            P.render(os.path.join(out, "hero_%s.png" % c["id"]), int(w * scale), int(h * scale))
    if "photos" in argv:
        cams = json.load(open(os.path.join(HERE, "hsw_cams.json")))["cams"]
        for c in cams:
            if c.get("skip") or (only and c["id"] not in only):
                continue
            cam.data.type = "PERSP"
            cam.data.sensor_fit = "AUTO"
            cam.data.sensor_width = c["blender"]["sensor_mm"]
            cam.data.lens = c["blender"]["lens_mm"]
            cam.data.shift_x = 0.0
            cam.data.shift_y = c["blender"]["shift_y"]
            # low cameras: clip the first metres so a bush or tree trunk at the solved spot does not fill the lens
            cam.data.clip_start, cam.data.clip_end = (c.get("clip_m") or (30.0 if c["eye_above_ground_m"] < 3.0 else 0.3)), 6000
            x, y, z = c["pos"]
            cam.location = (x, y, z)
            hd, pt = math.radians(c["heading_deg"]), math.radians(c["pitch_deg"])
            d = Vector((math.sin(hd) * math.cos(pt), math.cos(hd) * math.cos(pt), math.sin(pt)))
            cam.rotation_euler = d.to_track_quat("-Z", "Y").to_euler()
            # round 1: day light only (dusk/night look is a later round); photo hour clamped into the day
            hour = min(max(float(c.get("time_h") or 10.0), 8.5), 15.5)
            P.apply_light(*L.sun_position(c.get("date") or "2024-04-15", hour))
            W, H = c["size"]
            k = 1600 / max(W, H) * scale
            P.render(os.path.join(out, "%s_render.png" % c["id"]), int(round(W * k)), int(round(H * k)))
    print("total %.1fs" % (time.time() - t))


main()
