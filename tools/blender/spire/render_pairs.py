"""Renders from the same point of view as a reference photo (mega showcase pairs), Cycles CPU in the cloud.

    CYC_SAMPLES=32 python tools/blender/spire/render_pairs.py <pairs.json> <out_dir> [only=id,id] [width=1000] [tiles=<dir>]

tiles=<dir>: skip the build and load only the tiles the cameras see (made by tools/city/tiles.py bake <dir>).

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


TILE_GROUND = None          # set when rendering from saved tiles (tools/city/tiles.py): no builders have run


def ground(x, y):
    if TILE_GROUND:
        return TILE_GROUND.z(x, y)
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
    e[0].position, e[0].color = 0.0, (0.62, 0.77, 0.92, 1)      # horizon
    e[1].position, e[1].color = 0.45, (0.05, 0.17, 0.58, 1)    # overhead
    mid = ramp.color_ramp.elements.new(0.12)
    mid.color = (0.17, 0.38, 0.82, 1)
    ab = nt.nodes.new("ShaderNodeMath")
    ab.operation = "ABSOLUTE"
    nt.links.new(sep.outputs["Z"], ab.inputs[0])
    nt.links.new(ab.outputs[0], ramp.inputs["Fac"])
    nt.links.new(ramp.outputs["Color"], bg.inputs["Color"])
    bg.inputs["Strength"].default_value = strength


def palms(x, y, yaw, count):
    """Royal palms (pale trunk, feather crown) scattered over a yellow-green lawn in the fan ahead of the camera."""
    import random
    rnd = random.Random(7)
    fx, fy = math.cos(yaw), math.sin(yaw)

    def mat(name, col, rough):
        m = bpy.data.materials.get(name) or bpy.data.materials.new(name)
        m.use_nodes = True
        bs = m.node_tree.nodes["Principled BSDF"]
        bs.inputs["Base Color"].default_value = (*col, 1)
        bs.inputs["Roughness"].default_value = rough
        return m

    parts = {"trunk": ([], []), "frond": ([], []), "lawn": ([], [])}

    def quad(key, pts):
        v, f = parts[key]
        f.append(list(range(len(v), len(v) + len(pts))))
        v.extend(pts)

    g0 = ground(x, y)
    quad("lawn", [(x + 130.0 * math.cos(a), y + 130.0 * math.sin(a), g0 + 0.4) for a in (math.tau * i / 40 for i in range(40))])
    for _ in range(count):
        t, s = rnd.uniform(45.0, 120.0), rnd.choice((-1, 1)) * rnd.uniform(4.0, 48.0)
        px, py = x + fx * t - fy * s, y + fy * t + fx * s
        gz, ht = ground(px, py), rnd.uniform(16.0, 22.0)
        for i in range(8):                                   # trunk
            a0, a1 = math.tau * i / 8, math.tau * (i + 1) / 8
            quad("trunk", [(px + 0.42 * math.cos(a0), py + 0.42 * math.sin(a0), gz), (px + 0.42 * math.cos(a1), py + 0.42 * math.sin(a1), gz),
                           (px + 0.3 * math.cos(a1), py + 0.3 * math.sin(a1), gz + ht), (px + 0.3 * math.cos(a0), py + 0.3 * math.sin(a0), gz + ht)])
        for i in range(22):                                  # drooping feather fronds
            a = math.tau * i / 13 + rnd.uniform(-0.2, 0.2)
            lift = rnd.uniform(-0.2, 0.9)
            cx_, cy_ = math.cos(a), math.sin(a)
            prev = None
            for k in range(5):
                u = k / 4.0
                rr, zz = 6.5 * u, ht + 1.2 + 4.0 * u * lift - 5.5 * u * u
                wd = 1.1 * math.sin(math.pi * min(1.0, u + 0.15))
                cur = ((px + cx_ * rr - cy_ * wd, py + cy_ * rr + cx_ * wd, gz + zz), (px + cx_ * rr + cy_ * wd, py + cy_ * rr - cx_ * wd, gz + zz))
                if prev:
                    quad("frond", [prev[0], prev[1], cur[1], cur[0]])
                prev = cur
    cols = {"trunk": ((0.62, 0.60, 0.52), 0.8), "frond": ((0.10, 0.22, 0.05), 0.6), "lawn": ((0.40, 0.48, 0.13), 0.95)}
    for key, (v, f) in parts.items():
        me = bpy.data.meshes.new("pair_royal_" + key)
        me.from_pydata(v, [], f)
        ob = bpy.data.objects.new("pair_royal_" + key, me)
        ob.data.materials.append(mat("pair_royal_" + key, *cols[key]))
        bpy.context.scene.collection.objects.link(ob)


def warm_neighbours():
    """Critic rounds 10 to 18: the generic towers read as pale blue-white striped boxes. Brisbane's are cream, sandstone,
    grey and dark glass, so every generic wall and band is tinted one of those (by name, so it is the same each run)."""
    tints = ((0.86, 0.78, 0.62), (0.78, 0.69, 0.54), (0.62, 0.63, 0.64), (0.80, 0.76, 0.68), (0.34, 0.38, 0.44), (0.70, 0.62, 0.50))
    for m in bpy.data.materials:
        if not m.name.startswith("gen_") or not m.use_nodes or m.name.rsplit("_", 1)[-1] not in ("wall", "band"):
            continue
        t = tints[sum(ord(c) for c in m.name.rsplit("_", 1)[0]) % len(tints)]
        bs = m.node_tree.nodes.get("Principled BSDF")
        if not bs:
            continue
        inp = bs.inputs["Base Color"]
        if inp.links:
            src = inp.links[0].from_socket
            mx = m.node_tree.nodes.new("ShaderNodeMix")
            mx.data_type, mx.blend_type = "RGBA", "MULTIPLY"
            mx.inputs[0].default_value = 1.0
            m.node_tree.links.new(src, mx.inputs[6])
            mx.inputs[7].default_value = (*t, 1)
            m.node_tree.links.new(mx.outputs[2], inp)
        else:
            c = inp.default_value
            inp.default_value = (c[0] * t[0], c[1] * t[1], c[2] * t[2], 1)


def shoot(p, out, width):
    x, y = p["pos"] if "pos" in p else L.to_local(p["lat"], p["lon"])
    if p.get("dist"):
        tx, ty = p["target"][0], p["target"][1]
        k = p["dist"] / (math.hypot(x - tx, y - ty) or 1.0)
        x, y = tx + (x - tx) * k, ty + (y - ty) * k
    z = p["z"] if "z" in p else max(ground(x, y), 0.6) + p.get("eye", 1.7)
    import southbank as SB
    fix = SB.camera_fix(x, y, p.get("z"))                  # South Bank promenade and forecourt have their own levels
    if fix:
        x, y, z = fix
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
    for x0, y0, x1, y1, hw, zmin in p.get("drop", []):       # "drop": things newer than the photo, as capsules [x0, y0, x1, y1, half width, above z]
        import numpy as np
        ex, ey = x1 - x0, y1 - y0
        el = ex * ex + ey * ey
        for o in bpy.data.objects:
            if o.type != "MESH" or o.name.startswith("hero_") or not len(o.data.vertices):
                continue
            co = np.empty(len(o.data.vertices) * 3, dtype=np.float32)
            o.data.vertices.foreach_get("co", co)
            co = co.reshape(-1, 3) @ np.array(o.matrix_world.to_3x3(), dtype=np.float32).T + np.array(o.matrix_world.translation, dtype=np.float32)
            t = np.clip(((co[:, 0] - x0) * ex + (co[:, 1] - y0) * ey) / el, 0.0, 1.0)
            hit = (co[:, 2] > zmin) & (np.hypot(co[:, 0] - x0 - t * ex, co[:, 1] - y0 - t * ey) < hw)
            if not hit.any():
                continue
            co = np.empty(len(o.data.vertices) * 3, dtype=np.float32)   # sink them (deleting through bmesh ran out of memory on the big meshes)
            o.data.vertices.foreach_get("co", co)
            co = co.reshape(-1, 3)
            co[hit, 2] -= 80.0
            o.data.vertices.foreach_set("co", co.ravel())
            o.data.update()
    for o in bpy.data.objects:                             # "year": Queen's Wharf (2024) is left out of older photos
        if o.name.startswith("hero_qw_"):
            o.hide_render = p.get("year", 9999) < 2023
    river = bpy.data.materials.get("clay_water")           # "river": the water colour on the photo's day (brown after rain, blue on a clear evening)
    if river:
        river.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (*p.get("river", (0.20, 0.185, 0.115)), 1)
    cam.location = pos
    cam.rotation_euler = look.to_track_quat("-Z", "Y").to_euler()
    for o in [o for o in bpy.data.objects if o.name.startswith("pair_royal")]:
        bpy.data.objects.remove(o)
    if p.get("palms"):                                       # "palms": royal palms and a mown lawn in front of the camera (Botanic Gardens)
        palms(x, y, math.atan2(d.y, d.x), p["palms"])
    if p.get("clear"):                                       # "clear": half width (m) of a tree-free lane to the target
        import bmesh
        ax, ay = tgt.x - x, tgt.y - y
        ln = math.hypot(ax, ay)
        ax, ay = ax / ln, ay / ln
        for o in bpy.data.objects:
            if o.type == "MESH" and ("tree" in o.name or "palm" in o.name or o.name.startswith(("leaves_", "blooms_"))):
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
    tiles_dir = next((a[6:] for a in argv if a.startswith("tiles=")), None)
    if tiles_dir:                                          # load only the 1 km tiles these cameras can see
        global TILE_GROUND
        sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "city"))
        import tiles as T
        index = json.load(open(os.path.join(tiles_dir, "index.json")))
        want = T.tiles_for(index, [T.camera_xy(p) for p in pairs if not only or p["id"] in only])
        st = T.load(tiles_dir, want)
        TILE_GROUND = st.pop("ground")
        print("tiles loaded:", json.dumps(st), flush=True)
    else:
        build_all.build_all(None, write_meta=False)
    P.setup_morning()
    az, el = L.sun_position("2019-01", 11.5)               # the photos are clear late-morning summer days
    P.apply_light(az, el)
    blue_sky()
    warm_neighbours()
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
        bs.inputs["Base Color"].default_value = (0.17, 0.19, 0.135, 1)
        bs.inputs["Roughness"].default_value = 0.09
        bs.inputs["Specular IOR Level"].default_value = 0.6
        for ln in list(bs.inputs["Normal"].links):
            nt.links.remove(ln)
        g2 = nt.nodes.new("ShaderNodeNewGeometry")           # round 6: small wind ripples so it reads as water
        rip = nt.nodes.new("ShaderNodeTexNoise")
        rip.inputs["Scale"].default_value = 0.6
        rip.inputs["Detail"].default_value = 4.0
        sc = nt.nodes.new("ShaderNodeMapping")
        sc.inputs["Scale"].default_value = (1.0, 0.35, 1.0)
        nt.links.new(g2.outputs["Position"], sc.inputs["Vector"])
        nt.links.new(sc.outputs["Vector"], rip.inputs["Vector"])
        rb = nt.nodes.new("ShaderNodeBump")
        rb.inputs["Strength"].default_value = 1.0
        rb.inputs["Distance"].default_value = 0.4
        nt.links.new(rip.outputs["Fac"], rb.inputs["Height"])
        nt.links.new(rb.outputs["Normal"], bs.inputs["Normal"])
    leaf = bpy.data.materials.get("tree_crowns_far")       # critic round 3: dark, uneven canopy, not mint balls
    if leaf and leaf.node_tree:
        nt = leaf.node_tree
        bs = nt.nodes.get("Principled BSDF")
        geo = nt.nodes.new("ShaderNodeNewGeometry")
        ns = nt.nodes.new("ShaderNodeTexNoise")
        ns.inputs["Scale"].default_value = 0.045
        ns.inputs["Detail"].default_value = 6.0
        nt.links.new(geo.outputs["Position"], ns.inputs["Vector"])
        rp = nt.nodes.new("ShaderNodeValToRGB")
        rp.color_ramp.elements[0].position, rp.color_ramp.elements[0].color = 0.30, (0.010, 0.038, 0.012, 1)
        rp.color_ramp.elements[1].position, rp.color_ramp.elements[1].color = 0.72, (0.10, 0.19, 0.04, 1)
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
