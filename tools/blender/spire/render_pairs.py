"""Renders from the same point of view as a reference photo (mega showcase pairs), Cycles CPU in the cloud.

    CYC_SAMPLES=32 python tools/blender/spire/render_pairs.py <pairs.json> <out_dir> [only=id,id] [width=1000]

pairs.json: [{"id", "lat", "lon" (camera, e.g. the photo's GPS), "f35" (35 mm equivalent lens), "size": [w, h] of the
photo, "target": [x, y, z] (a point in the Spire frame, z m AHD) and "at": [u, v] (where that point sits in the
photo, 0-1 from the top left), optional "eye" (m above ground or water, default 1.7) or "z" (absolute AHD), optional "dist" (m from the
target, along the GPS bearing: for photos whose GPS fix is plainly too near or too far)}].
The camera stands at the GPS spot and is turned so the target lands on the same pixel. Writes <id>.png.
"""
import json
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy  # noqa: E402
from mathutils import Vector  # noqa: E402

import build_all  # noqa: E402
import layout as L  # noqa: E402
import preview as P  # noqa: E402
import render_cbd as RC  # noqa: E402


def ground(x, y):
    b = L.LIDAR_BOX
    if b[0] <= x < b[2] and b[1] < y <= b[3]:
        return L.ground_z(x, y)
    import far_roads as FR
    return float(FR.GROUND.z([x], [y])[0]) if FR.GROUND else 5.0


def blue_sky(strength=1.5):
    """Clear summer sky for the pairs: saturated blue overhead, paler at the horizon (critic round 1: the
    physical sky read as flat grey haze beside the photos)."""
    nt = bpy.context.scene.world.node_tree
    bg = nt.nodes.get("Background")
    geo = nt.nodes.new("ShaderNodeNewGeometry")
    sep = nt.nodes.new("ShaderNodeSeparateXYZ")
    nt.links.new(geo.outputs["Incoming"], sep.inputs[0])
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    e = ramp.color_ramp.elements
    e[0].position, e[0].color = 0.0, (0.42, 0.62, 0.86, 1)      # horizon
    e[1].position, e[1].color = 0.55, (0.045, 0.16, 0.56, 1)    # overhead
    mid = ramp.color_ramp.elements.new(0.12)
    mid.color = (0.16, 0.36, 0.78, 1)
    ab = nt.nodes.new("ShaderNodeMath")
    ab.operation = "ABSOLUTE"
    nt.links.new(sep.outputs["Z"], ab.inputs[0])
    nt.links.new(ab.outputs[0], ramp.inputs["Fac"])
    nt.links.new(ramp.outputs["Color"], bg.inputs["Color"])
    bg.inputs["Strength"].default_value = strength


def shoot(p, out, width):
    x, y = L.to_local(p["lat"], p["lon"])
    if p.get("dist"):
        tx, ty = p["target"][0], p["target"][1]
        k = p["dist"] / (math.hypot(x - tx, y - ty) or 1.0)
        x, y = tx + (x - tx) * k, ty + (y - ty) * k
    z = p["z"] if "z" in p else max(ground(x, y), 0.6) + p.get("eye", 1.7)
    w, h = p["size"]
    diag = math.hypot(w, h)
    sw, sh = 43.27 * w / diag, 43.27 * h / diag           # the frame with a 35 mm diagonal at the photo's shape
    cam = P.camera("cam_pair")
    cam.data.type = "PERSP"
    cam.data.sensor_fit = "HORIZONTAL"
    cam.data.sensor_width = sw
    cam.data.lens = p["f35"]
    cam.data.clip_start, cam.data.clip_end = p.get("clip", 0.5), 9000      # "clip": skip things nearer than this (m)
    pos, tgt = Vector((x, y, z)), Vector(p["target"])
    d = tgt - pos
    yaw = math.atan2(d.y, d.x) + math.atan((p["at"][0] - 0.5) * sw / p["f35"])
    pitch = math.atan2(d.z, math.hypot(d.x, d.y)) - math.atan((0.5 - p["at"][1]) * sh / p["f35"])
    look = Vector((math.cos(pitch) * math.cos(yaw), math.cos(pitch) * math.sin(yaw), math.sin(pitch)))
    cam.location = pos
    cam.rotation_euler = look.to_track_quat("-Z", "Y").to_euler()
    P.hide(["logistics"], True)
    P.render(os.path.join(out, p["id"] + ".png"), width, round(width * h / w))
    return {"id": p["id"], "pos": [round(x, 1), round(y, 1), round(z, 1)]}


def main():
    argv = sys.argv[1:]
    pairs = json.load(open(argv[0]))
    out = os.path.abspath(argv[1])
    os.makedirs(out, exist_ok=True)
    only = next((a[5:].split(",") for a in argv if a.startswith("only=")), None)
    width = int(next((a[6:] for a in argv if a.startswith("width=")), 1000))
    build_all.build_all(None, write_meta=False)
    P.setup_morning()
    az, el = L.sun_position("2019-01", 11.5)               # the photos are clear late-morning summer days
    P.apply_light(az, el)
    blue_sky()
    bpy.context.scene.view_settings.exposure += 0.8       # critic round 1: renders read a stop darker than the photos
    RC.setup_cycles(int(os.environ.get("CYC_SAMPLES", "32")))
    done = [shoot(p, out, width) for p in pairs if not only or p["id"] in only]
    json.dump(done, open(os.path.join(out, "cams.json"), "w"), indent=1)


if __name__ == "__main__":
    main()
