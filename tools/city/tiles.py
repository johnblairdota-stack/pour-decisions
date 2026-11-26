"""The city in 1 km tiles: build once, save each tile on its own, load only what a camera can see.

    # 1. bake (once per model change): build the whole city, cut it into tiles, save them
    $CITY_VENV/bin/python tools/city/tiles.py bake <tiles_dir>

    # 2. render from the tiles (no rebuild): see render_pairs.py tiles=<tiles_dir>
    # 3. what would a camera load?
    $CITY_VENV/bin/python tools/city/tiles.py plan <tiles_dir> <pairs.json> [only=id,id]

Tiles are the 1 km squares of the MGA zone 56 grid, named by the km of their south-west corner (503_6962),
the same squares as the LiDAR and docs/city/coverage.md. Every face of the model goes to the tile its centre
is in. Each tile is saved twice: `near` (everything) and `far` (without the things too small to see from
FAR_FROM metres: lane paint, lamps, signs, kerbs, roof plant, footpaths). Things that are not meshes
(lights, empties) go in the `global` file, which is always loaded.

The tile files are a cache (hundreds of MB): they are never committed.
"""
import fnmatch
import json
import math
import os
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "blender", "spire"))
import layout as L  # noqa: E402

E0, N0 = L.ORIGIN_MGA56
FAR_FROM = 1500.0            # tiles whose nearest corner is farther than this from the camera load as `far`
BIG_FACE = 400.0             # an object with a face wider than this is not cut up: it goes in the global file
ALWAYS_R = 400.0             # tiles this close to the camera always load (their shadows reach the view)
FOV_PAD = math.radians(8.0)  # extra angle each side of the frame
# Objects left out of a `far` tile, by name. Each is under two pixels from FAR_FROM in a 1000 px frame.
FAR_DROP = ["*marking*", "*lane_line*", "*lines*", "*paint*", "*lamp*", "*light_col*", "*signal*", "*sign*", "*gantr*",
            "*kerb*", "*bin*", "*bollard*", "*bench*", "*bus_stop*", "*shelter*", "*path*", "*footway*", "*crossing*",
            "*steps*", "*roof_plant*", "*solar*", "*condenser*", "*vent*", "*stall*", "*pitch*", "*sail*", "*rail*post*",
            "*wheel_stop*", "*hydrant*", "*bike*", "*planter*", "*awning*", "*cable*"]


# Foliage in a `far` tile is thinned to this share of its triangles: a crown 1.5 km away is a few pixels wide.
FAR_THIN = ["*tree*", "*crown*", "*mangrove*", "*leaves*", "*blooms*", "*palm*", "*canopy*", "*hedge*", "*fig*"]
FAR_THIN_RATIO = 0.25
FAR_THIN_MIN = 4000          # faces: smaller pieces are not worth thinning


def is_foliage(name):
    low = name.lower()
    return any(fnmatch.fnmatch(low, pat) for pat in FAR_THIN)


def _thin(ob, bpy):
    """A lighter copy of a foliage piece for the far tile (edge-collapse to FAR_THIN_RATIO of the faces)."""
    scene = bpy.context.scene
    scene.collection.objects.link(ob)
    mod = ob.modifiers.new("thin", "DECIMATE")
    mod.ratio = FAR_THIN_RATIO
    me = bpy.data.meshes.new_from_object(ob.evaluated_get(bpy.context.evaluated_depsgraph_get()))
    me["city_mats"] = ob.data["city_mats"]
    ob.modifiers.remove(mod)
    scene.collection.objects.unlink(ob)
    lite = bpy.data.objects.new(ob.name, me)             # Blender adds .001; the loader strips it
    lite.hide_render, lite.visible_shadow, lite.visible_camera = ob.hide_render, ob.visible_shadow, ob.visible_camera
    for k in ob.keys():
        lite[k] = ob[k]
    return lite


def tile_key(x, y):
    return int((x + E0) // 1000), int((y + N0) // 1000)


def tile_box(e, n):
    """Local-frame box (x0, y0, x1, y1) of tile (e, n)."""
    return e * 1000.0 - E0, n * 1000.0 - N0, (e + 1) * 1000.0 - E0, (n + 1) * 1000.0 - N0


def is_small(name):
    low = name.lower()
    return any(fnmatch.fnmatch(low, pat) for pat in FAR_DROP)


# ------------------------------------------------------------------------------------------------ choosing tiles
def camera_xy(p):
    """Where a pairs.json camera stands and looks (plan only): (x, y, tx, ty, half horizontal angle)."""
    x, y = p["pos"] if "pos" in p else L.to_local(p["lat"], p["lon"])
    tx, ty = p["target"][0], p["target"][1]
    if p.get("dist"):
        k = p["dist"] / (math.hypot(x - tx, y - ty) or 1.0)
        x, y = tx + (x - tx) * k, ty + (y - ty) * k
    w, h = p["size"]
    sw = 43.27 * w / math.hypot(w, h)
    yaw = math.atan2(ty - y, tx - x) + math.atan((p["at"][0] - 0.5) * sw / p["f35"])
    half = math.atan(sw / 2.0 / p["f35"])
    steep = abs(p.get("z", 0.0) - p["target"][2]) > 1.5 * math.hypot(tx - x, ty - y)   # looking down from high up
    return x, y, yaw, (math.pi if steep else half)


def tiles_for(index, cams, far_from=FAR_FROM):
    """{tile name: 'near' | 'far'} for one or more cameras [(x, y, yaw, half_angle)]."""
    want = {}
    for name, t in index["tiles"].items():
        e, n = (int(v) for v in name.split("_"))
        x0, y0, x1, y1 = tile_box(e, n)
        for cx, cy, yaw, half in cams:
            px, py = min(max(cx, x0), x1), min(max(cy, y0), y1)         # nearest point of the tile
            d = math.hypot(px - cx, py - cy)
            seen = d <= ALWAYS_R
            if not seen:
                for qx, qy in ((x0, y0), (x1, y0), (x0, y1), (x1, y1), (px, py), ((x0 + x1) / 2, (y0 + y1) / 2)):
                    a = math.atan2(qy - cy, qx - cx) - yaw
                    a = (a + math.pi) % math.tau - math.pi
                    if abs(a) <= half + FOV_PAD:
                        seen = True
                        break
                if not seen and half < math.pi / 2:                     # a tile wider than the frame, straddling it
                    lx, ly = math.cos(yaw), math.sin(yaw)
                    side = [(qx - cx) * -ly + (qy - cy) * lx for qx, qy in ((x0, y0), (x1, y0), (x0, y1), (x1, y1))]
                    ahead = [(qx - cx) * lx + (qy - cy) * ly for qx, qy in ((x0, y0), (x1, y0), (x0, y1), (x1, y1))]
                    seen = min(side) < 0 < max(side) and max(ahead) > 0
            if seen:
                lod = "near" if d <= far_from else "far"
                if want.get(name) != "near":
                    want[name] = lod
    return want


# ------------------------------------------------------------------------------------------------ baking
_VAL = {"FLOAT": ("value", 1, "f4"), "INT": ("value", 1, "i4"), "BOOLEAN": ("value", 1, "?"), "INT8": ("value", 1, "i4"),
        "FLOAT_VECTOR": ("vector", 3, "f4"), "FLOAT2": ("vector", 2, "f4"), "FLOAT_COLOR": ("color", 4, "f4"),
        "BYTE_COLOR": ("color", 4, "f4"), "INT16_2D": ("value", 2, "i4"), "INT32_2D": ("value", 2, "i4")}


def _split_mesh(ob, np, bpy):
    """Cut one mesh object into per-tile meshes in world coordinates. Returns {(e, n): mesh}."""
    me = ob.data
    nv, nl, npoly = len(me.vertices), len(me.loops), len(me.polygons)
    if not npoly:
        return {}
    co = np.empty(nv * 3, "f4")
    me.vertices.foreach_get("co", co)
    M = np.array(ob.matrix_world, "f8")
    co = (co.reshape(-1, 3).astype("f8") @ M[:3, :3].T + M[:3, 3]).astype("f4")
    vi = np.empty(nl, "i4")
    me.loops.foreach_get("vertex_index", vi)
    ls = np.empty(npoly, "i4")
    lt = np.empty(npoly, "i4")
    me.polygons.foreach_get("loop_start", ls)
    me.polygons.foreach_get("loop_total", lt)
    xy = co[vi, :2].astype("f8")
    span = (np.maximum.reduceat(xy, ls, axis=0) - np.minimum.reduceat(xy, ls, axis=0)).max()
    if span > BIG_FACE:                                     # the river plane, the far land skirt: one face covers many
        return None                                         # tiles, so the whole object stays in the global file
    cen = np.add.reduceat(xy, ls, axis=0) / lt[:, None]
    key = (np.floor((cen[:, 0] + E0) / 1000.0).astype("i8") * 100000 + np.floor((cen[:, 1] + N0) / 1000.0).astype("i8"))
    attrs = []
    for a in me.attributes:
        if a.name.startswith(".") or a.name == "position" or a.domain == "EDGE" or a.data_type not in _VAL:
            continue
        prop, width, dt = _VAL[a.data_type]
        buf = np.empty(len(a.data) * width, dt)
        a.data.foreach_get(prop, buf)
        attrs.append((a.name, a.data_type, a.domain, prop, width, buf.reshape(-1, width)))
    uv_active = me.uv_layers.active.name if me.uv_layers.active else None
    out = {}
    for k in np.unique(key):
        pm = key == k
        whole = bool(pm.all())
        lm = np.repeat(pm, lt)
        used, inv = np.unique(vi[lm], return_inverse=True)
        new = bpy.data.meshes.new(me.name)
        new.vertices.add(len(used))
        new.vertices.foreach_set("co", co[used].ravel())
        new.loops.add(int(lm.sum()))
        new.loops.foreach_set("vertex_index", inv.astype("i4"))
        tot = lt[pm]
        new.polygons.add(len(tot))
        new.polygons.foreach_set("loop_start", (np.cumsum(tot) - tot).astype("i4"))
        new.polygons.foreach_set("loop_total", tot)
        for name, dtype, dom, prop, width, buf in attrs:
            sel = buf if whole and dom != "POINT" else buf[{"POINT": used, "CORNER": lm, "FACE": pm}[dom]]
            try:
                at = new.attributes.get(name) or new.attributes.new(name, dtype, dom)
                at.data.foreach_set(prop, sel.ravel())
            except (RuntimeError, TypeError, AttributeError):
                pass
        if uv_active and new.uv_layers.get(uv_active):
            new.uv_layers.active = new.uv_layers[uv_active]
        new["city_mats"] = json.dumps([m.name if m else "" for m in me.materials])   # materials live in global.blend,
        new.update(calc_edges=True)                                                  # once, not in every tile file
        out[(int(k // 100000), int(k % 100000))] = new
    return out


def bake(out_dir, build=True):
    import bpy
    import numpy as np
    t0 = time.time()
    if build:
        import build_all as B
        B.build_all(None, write_meta=False)
    print("tiles: scene ready in %.0f s" % (time.time() - t0), flush=True)
    os.makedirs(out_dir, exist_ok=True)
    scene = bpy.context.scene
    tiles, glob = {}, []
    for ob in list(bpy.data.objects):
        if ob.type == "CAMERA":
            continue
        cols = [c.name for c in ob.users_collection]
        if ob.type != "MESH" or ob.modifiers or ob.instance_type != "NONE" or ob.parent or ob.children:
            ob["city_cols"] = json.dumps(cols)
            glob.append(ob)
            continue
        pieces = _split_mesh(ob, np, bpy)
        if pieces is None:
            ob["city_cols"] = json.dumps(cols)
            glob.append(ob)
            print("tiles: %s kept whole (very large faces)" % ob.name)
            continue
        for (e, n), me in pieces.items():
            piece = bpy.data.objects.new("%s@%d_%d" % (ob.name, e, n), me)
            piece.hide_render = ob.hide_render
            piece.visible_shadow = ob.visible_shadow
            piece.visible_camera = ob.visible_camera
            for k in ob.keys():
                try:
                    piece[k] = ob[k]
                except (TypeError, ValueError):
                    pass
            piece["city_cols"] = json.dumps(cols)
            piece["city_src"] = ob.name
            tiles.setdefault((e, n), []).append(piece)
    print("tiles: cut into %d tiles in %.0f s" % (len(tiles), time.time() - t0), flush=True)
    index = {"made": time.strftime("%Y-%m-%d %H:%M"), "blender": bpy.app.version_string, "far_from_m": FAR_FROM,
             "collections_hidden": [c.name for c in bpy.data.collections if c.hide_render], "tiles": {}}
    for m in bpy.data.materials:
        m.use_fake_user = True
    bpy.data.libraries.write(os.path.join(out_dir, "global.blend"), set(glob) | set(bpy.data.materials),
                             path_remap="ABSOLUTE", fake_user=True, compress=True)
    for (e, n), obs in sorted(tiles.items()):
        name = "%d_%d" % (e, n)
        far = [o for o in obs if not is_small(o.name)]
        far = [_thin(o, bpy) if is_foliage(o.name) and len(o.data.polygons) >= FAR_THIN_MIN else o for o in far]
        bpy.data.libraries.write(os.path.join(out_dir, name + "_near.blend"), set(obs), path_remap="ABSOLUTE", compress=True)
        bpy.data.libraries.write(os.path.join(out_dir, name + "_far.blend"), set(far), path_remap="ABSOLUTE", compress=True)
        tri = lambda lst: int(sum(sum(len(p.vertices) - 2 for p in o.data.polygons) for o in lst))  # noqa: E731
        index["tiles"][name] = {"objects": len(obs), "tris_near": tri(obs), "objects_far": len(far), "tris_far": tri(far)}
        for o in far:                                       # the thinned copies are only needed in the file
            if o not in obs:
                me = o.data
                bpy.data.objects.remove(o)
                bpy.data.meshes.remove(me)
    # ground height sampler for cameras (8 m), so a tile render never needs the builders
    import render_pairs as RP
    bx = [min(tile_box(*map(int, k.split("_")))[0] for k in index["tiles"]), min(tile_box(*map(int, k.split("_")))[1] for k in index["tiles"]),
          max(tile_box(*map(int, k.split("_")))[2] for k in index["tiles"]), max(tile_box(*map(int, k.split("_")))[3] for k in index["tiles"])]
    step = 8.0
    cols_n, rows_n = int((bx[2] - bx[0]) / step) + 1, int((bx[3] - bx[1]) / step) + 1
    import far_roads as FR
    xs, ys = np.meshgrid(bx[0] + np.arange(cols_n) * step, bx[3] - np.arange(rows_n) * step)
    Z = (FR.GROUND.z(xs.ravel(), ys.ravel()).reshape(xs.shape) if FR.GROUND else np.full(xs.shape, 5.0)).astype("f4")
    b = L.LIDAR_BOX                                         # inside the centre box the 1 m LiDAR ground is the truth
    for r in range(rows_n):
        for c in range(cols_n):
            if b[0] <= xs[r, c] < b[2] and b[1] < ys[r, c] <= b[3]:
                Z[r, c] = RP.ground(float(xs[r, c]), float(ys[r, c]))
    np.save(os.path.join(out_dir, "ground_8m.npy"), Z)
    index["ground"] = {"x0": bx[0], "y1": bx[3], "step": step, "rows": rows_n, "cols": cols_n}
    index["seconds"] = round(time.time() - t0)
    json.dump(index, open(os.path.join(out_dir, "index.json"), "w"), indent=1)
    print("tiles: %d tiles saved to %s in %d s" % (len(index["tiles"]), out_dir, index["seconds"]))
    return index


# ------------------------------------------------------------------------------------------------ loading
class GroundGrid:
    def __init__(self, out_dir, g):
        import numpy as np
        self.g, self.Z = g, np.load(os.path.join(out_dir, "ground_8m.npy"))

    def z(self, x, y):
        g = self.g
        c = min(max(int(round((x - g["x0"]) / g["step"])), 0), g["cols"] - 1)
        r = min(max(int(round((g["y1"] - y) / g["step"])), 0), g["rows"] - 1)
        return float(self.Z[r, c])


def _append(path, bpy, materials=False):
    with bpy.data.libraries.load(path, link=False) as (src, dst):
        dst.objects = list(src.objects)
        if materials:
            dst.materials = list(src.materials)
    return [o for o in dst.objects if o is not None]


def load(out_dir, want):
    """Load the global file and the wanted tiles ({name: 'near'|'far'}) into the open scene. Returns stats."""
    import bpy
    t0 = time.time()
    index = json.load(open(os.path.join(out_dir, "index.json")))
    for ob in list(bpy.data.objects):
        if ob.type != "CAMERA":
            bpy.data.objects.remove(ob, do_unlink=True)
    for me in list(bpy.data.meshes):
        bpy.data.meshes.remove(me)
    for m in list(bpy.data.materials):
        bpy.data.materials.remove(m)
    obs = _append(os.path.join(out_dir, "global.blend"), bpy, materials=True)
    mats = {m.name: m for m in bpy.data.materials}
    tris = 0
    for name, lod in sorted(want.items()):
        got = _append(os.path.join(out_dir, "%s_%s.blend" % (name, lod)), bpy)
        tris += index["tiles"][name]["tris_" + lod]
        for ob in got:
            for mn in json.loads(ob.data.get("city_mats", "[]")):
                ob.data.materials.append(mats.get(mn))
        obs += got
    for ob in obs:
        src = ob.get("city_src")
        if src and "@" in ob.name and ob.name[-4:-3] == "." and ob.name[-3:].isdigit():
            ob.name = ob.name[:-4]                          # a thinned copy carries Blender's .001: scripts match on names
        names = json.loads(ob.get("city_cols", "[]")) or ["tiles"]
        for cn in names:
            col = bpy.data.collections.get(cn)
            if not col:
                col = bpy.data.collections.new(cn)
                bpy.context.scene.collection.children.link(col)
            col.objects.link(ob)
    for cn in index.get("collections_hidden", []):
        if bpy.data.collections.get(cn):
            bpy.data.collections[cn].hide_render = True
    return {"tiles": len(want), "near": sum(1 for v in want.values() if v == "near"), "objects": len(obs),
            "tris": tris, "seconds": round(time.time() - t0, 1), "ground": GroundGrid(out_dir, index["ground"])}


def plan(out_dir, pairs, only=None):
    index = json.load(open(os.path.join(out_dir, "index.json")))
    total = sum(t["tris_near"] for t in index["tiles"].values())
    rows = []
    for p in pairs:
        if only and p["id"] not in only:
            continue
        want = tiles_for(index, [camera_xy(p)])
        tris = sum(index["tiles"][k]["tris_" + v] for k, v in want.items())
        rows.append((p["id"], len(want), sum(1 for v in want.values() if v == "near"), tris, 100.0 * tris / total))
    return rows, total, len(index["tiles"])


if __name__ == "__main__":
    a = sys.argv[1:]
    if a and a[0] == "bake":
        bake(os.path.abspath(a[1]))
    elif a and a[0] == "plan":
        only = next((x[5:].split(",") for x in a if x.startswith("only=")), None)
        rows, total, n = plan(os.path.abspath(a[1]), json.load(open(a[2])), only)
        print("%d tiles, %.1f million triangles in all" % (n, total / 1e6))
        for r in rows:
            print("%-34s %3d tiles (%2d near)  %5.1f M tris  %3.0f %% of the city" % (r[0], r[1], r[2], r[3] / 1e6, r[4]))
    else:
        print(__doc__)
