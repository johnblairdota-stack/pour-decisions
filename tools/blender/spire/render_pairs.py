"""Renders from the same point of view as a reference photo (mega showcase pairs), Cycles CPU in the cloud.

    CYC_SAMPLES=32 python tools/blender/spire/render_pairs.py <pairs.json> <out_dir> [only=id,id] [width=1000]

pairs.json: [{"id", "lat", "lon" (camera, e.g. the photo's GPS), "f35" (35 mm equivalent lens), "size": [w, h] of the
photo, "target": [x, y, z] (a point in the Spire frame, z m AHD) and "at": [u, v] (where that point sits in the
photo, 0-1 from the top left), optional "eye" (m above ground or water, default 1.7) or "z" (absolute AHD), optional "pos" ([x, y] in the Spire frame, in place of a GPS fix that is plainly wrong), optional "dist" (m from the
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
    e[0].position, e[0].color = 0.0, (0.30, 0.52, 0.88, 1)      # horizon
    e[1].position, e[1].color = 0.55, (0.045, 0.16, 0.56, 1)    # overhead
    mid = ramp.color_ramp.elements.new(0.12)
    mid.color = (0.10, 0.30, 0.78, 1)
    ab = nt.nodes.new("ShaderNodeMath")
    ab.operation = "ABSOLUTE"
    nt.links.new(sep.outputs["Z"], ab.inputs[0])
    nt.links.new(ab.outputs[0], ramp.inputs["Fac"])
    nt.links.new(ramp.outputs["Color"], bg.inputs["Color"])
    bg.inputs["Strength"].default_value = strength


def shoot(p, out, width):
    x, y = p["pos"] if "pos" in p else L.to_local(p["lat"], p["lon"])
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
    if p.get("level"):                                     # perspective-corrected photo: level camera, shifted lens
        cam.data.shift_y = (p["f35"] * d.z / math.hypot(d.x, d.y) - (0.5 - p["at"][1]) * sh) / sw
        pitch = 0.0
        look = Vector((math.cos(yaw), math.sin(yaw), 0.0))
    else:
        cam.data.shift_y = 0.0
    if p.get("no_masts"):                                  # photo older than a bridge between camera and tower
        for o in bpy.data.objects:
            if o.type == "MESH" and not o.name.startswith("hero_"):
                import bmesh
                bm = bmesh.new()
                bm.from_mesh(o.data)
                M = o.matrix_world
                dead = []
                for v in bm.verts:                         # anything tall standing in the lane between camera and tower
                    q = M @ v.co
                    t = (q.x - x) * d.x + (q.y - y) * d.y
                    t /= (d.x * d.x + d.y * d.y)
                    off = abs((q.x - x) * d.y - (q.y - y) * d.x) / math.hypot(d.x, d.y)
                    if q.z > 26.0 and 0.0 < t < 0.78 and off < 60.0:
                        dead.append(v)
                if dead:
                    bmesh.ops.delete(bm, geom=dead, context="VERTS")
                    bm.to_mesh(o.data)
                bm.free()
    cam.location = pos
    cam.rotation_euler = look.to_track_quat("-Z", "Y").to_euler()
    if p.get("clear"):                                       # "clear": half width (m) of a tree-free lane to the target
        import bmesh
        ax, ay = tgt.x - x, tgt.y - y
        ln = math.hypot(ax, ay)
        ax, ay = ax / ln, ay / ln
        for o in bpy.data.objects:
            if o.type == "MESH" and ("tree" in o.name or "palm" in o.name):
                bm = bmesh.new()
                bm.from_mesh(o.data)
                M = o.matrix_world
                dead = []
                for v in bm.verts:
                    wp = M @ v.co
                    t = (wp.x - x) * ax + (wp.y - y) * ay
                    if -5 < t < ln and abs(-(wp.x - x) * ay + (wp.y - y) * ax) < p["clear"] * (0.35 + 0.65 * t / ln) + 3:
                        dead.append(v)
                if dead:
                    bmesh.ops.delete(bm, geom=dead, context="VERTS")
                    bm.to_mesh(o.data)
                bm.free()
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
    river = bpy.data.materials.get("clay_water")           # critic round 2: grey-green, not beige
    if river:
        for nd in river.node_tree.nodes:
            if nd.type == "MIX" and nd.inputs[6].default_value[0] > nd.inputs[6].default_value[2]:
                nd.inputs[6].default_value, nd.inputs[7].default_value = (0.105, 0.11, 0.07, 1), (0.135, 0.135, 0.085, 1)
    if river:
        river.node_tree.nodes["Principled BSDF"].inputs["Roughness"].default_value = 0.3     # no mirror streaks
        river.node_tree.nodes["Principled BSDF"].inputs["Specular IOR Level"].default_value = 0.12   # less sky blue
    if river:                                              # round 5: still read grey-lilac, so a plain olive river
        nt = river.node_tree
        bs = nt.nodes["Principled BSDF"]
        for ln in list(bs.inputs["Base Color"].links):
            nt.links.remove(ln)
        bs.inputs["Base Color"].default_value = (0.15, 0.16, 0.10, 1)
        bs.inputs["Roughness"].default_value = 0.45
        bs.inputs["Specular IOR Level"].default_value = 0.08
    leaf = bpy.data.materials.get("tree_crowns_far")       # critic round 3: dark, uneven canopy, not mint balls
    if leaf and leaf.node_tree:
        nt = leaf.node_tree
        bs = nt.nodes.get("Principled BSDF")
        geo = nt.nodes.new("ShaderNodeNewGeometry")
        ns = nt.nodes.new("ShaderNodeTexNoise")
        ns.inputs["Scale"].default_value = 0.07
        ns.inputs["Detail"].default_value = 6.0
        nt.links.new(geo.outputs["Position"], ns.inputs["Vector"])
        rp = nt.nodes.new("ShaderNodeValToRGB")
        rp.color_ramp.elements[0].position, rp.color_ramp.elements[0].color = 0.35, (0.03, 0.09, 0.02, 1)
        rp.color_ramp.elements[1].position, rp.color_ramp.elements[1].color = 0.70, (0.15, 0.26, 0.06, 1)
        nt.links.new(ns.outputs["Fac"], rp.inputs["Fac"])
        nt.links.new(rp.outputs["Color"], bs.inputs["Base Color"])
        fine = nt.nodes.new("ShaderNodeTexNoise")
        fine.inputs["Scale"].default_value = 1.4
        fine.inputs["Detail"].default_value = 8.0
        nt.links.new(geo.outputs["Position"], fine.inputs["Vector"])
        bp = nt.nodes.new("ShaderNodeBump")
        bp.inputs["Strength"].default_value = 1.0
        bp.inputs["Distance"].default_value = 1.2
        nt.links.new(fine.outputs["Fac"], bp.inputs["Height"])
        nt.links.new(bp.outputs["Normal"], bs.inputs["Normal"])
        bs.inputs["Roughness"].default_value = 0.9
    RC.setup_cycles(int(os.environ.get("CYC_SAMPLES", "32")))
    done = [shoot(p, out, width) for p in pairs if not only or p["id"] in only]
    json.dump(done, open(os.path.join(out, "cams.json"), "w"), indent=1)


if __name__ == "__main__":
    main()
