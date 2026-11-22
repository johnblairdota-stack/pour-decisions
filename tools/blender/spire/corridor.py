"""A river corridor for the game's flights, cut from the master Brisbane scene by what the camera sees.

    python tools/blender/spire/corridor.py <corridor> [out_dir] [--dry] [--check] [--pano=<tower>]
    (bpy from pip, as export_game.py; or blender -b --factory-startup -P ... -- <corridor> ...)

The master scene is 18 million triangles in well over 1,000 objects and 1,500 materials: far too much for a
tablet. A flight only ever sees a strip of it, from low on the water, from one side. This tool builds the whole
scene, walks the flight's camera path and keeps, face by face, only what that camera can see:

  in view      inside the camera's sweep at some point of the path, and facing it (the backs of buildings go)
  big enough   a face has to be bigger the further off it is (poles, signs, rails and lane lines go)
  on the skyline  past the near bank only what stands tall enough to show over it stays
  ground       the banks within reach of the path, thinned; nothing under the water
  trees        the near banks' crowns, each swapped for one 20-face lump
  towers       whatever stands on a game tower's own footprint goes into an object of its own
               ("tower_<id>"), so the game can hide the finished tower it is about to build

What is kept is merged for draw calls: the facades that fill most of the picture keep their own material
(so the game's window shader can dress them by name, as it does spire_site.glb), everything else shares one
vertex-coloured mesh. Budget: 150,000 triangles and 60 draws for a corridor.

Writes (same frame and transform as assets/spire/spire_site.glb: local x east, y north, z AHD; glTF y-up)
  assets/corridors/<corridor>.glb
  data/corridors/<corridor>.json    the path, the towers, each kept facade's window recipe, the counts
--dry    counts only                 --check  pictures from the path, whole scene beside the cut (out_dir)
--pano=<tower>  the far city beyond the corridor as a strip panorama from that tower's top (out_dir)

This places no equipment. Equipment, line routes and climb methods come from the mast climb thread / John.
"""
import json
import math
import os
import sys

import bpy
import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import layout as L  # noqa: E402

REPO = os.path.abspath(os.path.join(L.HERE, "..", "..", ".."))

# Camera paths are PROVISIONAL (set from the river mask, not yet flown in the game): (x, y, camera height AHD).
# Tower points are each site pack's origin (reference/sites/<id>/site.json) in this frame.
CORRIDORS = {
    "south_brisbane": {
        "name": "South Brisbane Reach",
        "path": [(215, -1350, 12), (215, -1600, 12), (150, -1880, 12), (-30, -2040, 12), (-260, -2040, 12),
                 (-470, -1860, 12), (-600, -1640, 12), (-690, -1480, 12), (-760, -1360, 12)],
        "towers": {
            "william1": {"name": "1 William St", "at": (-494.0, -1344.6), "top_ahd": 266.0, "site": "william1",
                         "equipment": "TBC: from the mast climb thread / John"},
            "queenswharf": {"name": "Queen's Wharf", "at": (-532.8, -1167.7), "top_ahd": 190.0, "site": "queenswharf",
                            "footprint_r": 110.0, "equipment": "TBC: from the mast climb thread / John"},
        },
    },
}

STEP = 25.0            # m between camera samples along the path
HALF_VIEW = 70.0       # deg either side of the heading the camera may look (it turns towards the tower)
NEAR = 300.0           # m: everything in view and big enough is kept this close
SKY_BASE, SKY_SLOPE = 14.0, 0.08     # past NEAR a face must top SKY_BASE + SKY_SLOPE * (d - NEAR) m AHD
FAR = 2600.0           # m: nothing further is kept live (the panorama's job)
AREA_K = 220.0         # a face must be at least (d / AREA_K)^2 m2 (and MIN_AREA)
MIN_AREA = 0.6
GROUND_R = 420.0       # m either side of the path: ground kept
GROUND_TRIS = 16000    # the ground is thinned to about this
TREE_R = 300.0         # m: tree crowns kept
TREE_MIN_R = 2.8       # m: smaller crowns are dropped
TREE_MAX = 2700        # crowns kept at most: the biggest and nearest win (the gardens and South Bank are thick with them)
TOWER_TRIS = 11000     # a game tower's own object is thinned to about this: its smallest faces (mullion lines, fins) go first
PLATE_Z, PLATE_AREA = 30.0, 100.0   # a big level face this high is a floor plate inside a tower (the hand-built towers
                                    # stack one per floor under their mullion lines): never seen from the water
TREE_FULL_R = 400.0    # m: nearer crowns are 20-face lumps, further ones 8-face (8-face crowns read as diamonds: none by default)
TRIM = ("_band", "balustrade", "city_detail")
TRIM_R = 200.0         # m: slab-edge bands, balcony glass and roof clutter are kept only this close
BANK = (0.16, 0.19, 0.11)
OWN_MATERIALS = 40     # facades that keep their own material (and window recipe); the rest share one mesh
BUDGET_TRIS, BUDGET_DRAWS = 150000, 60

GROUND = ("ground", "far_ground", "far_land", "cbd_ext_ground", "hsw_terrain")
CROWNS = ("tree_crowns", "wide_tree_crowns", "cbd_ext_tree_crowns", "palm_fronds", "far_suburbs_trees", "hsw_mangroves")
DROP = ("tree_trunks", "wide_tree_trunks", "cbd_ext_tree_trunks", "far_suburbs", "SLAB_", "SPIRE_", "COLUMNS", "PROPS",
        "EDGE_SCREENS", "FORMWORK", "river", "water")
# The parks built since (South Bank "sb_", the City Botanic Gardens "bg_", ...) name their parts <park>_<kind>_<what>:
GROUND_IN = ("_ground_",)
CROWNS_IN = ("tree_crowns", "tree_pines", "palm_fronds")
DROP_IN = ("tree_trunks",)
ICO = None
OCT = (np.array([(1, 0, 0), (-1, 0, 0), (0, 1, 0), (0, -1, 0), (0, 0, 1), (0, 0, -1)], float),
       np.array([(0, 2, 4), (2, 1, 4), (1, 3, 4), (3, 0, 4), (2, 0, 5), (1, 2, 5), (3, 1, 5), (0, 3, 5)]))


def samples(c):
    """Camera points every STEP m along the path, each with its unit heading."""
    pts = np.array(c["path"], float)
    out = []
    for a, b in zip(pts[:-1], pts[1:]):
        n = max(1, int(np.linalg.norm(b[:2] - a[:2]) / STEP))
        for i in range(n):
            out.append(a + (b - a) * i / n)
    out.append(pts[-1])
    out = np.array(out)
    d = np.gradient(out[:, :2], axis=0)
    d /= np.linalg.norm(d, axis=1)[:, None]
    return out, d


def faces(ob):
    """Per-face centre, normal, area, top z and corner count of a mesh (world space: transforms are applied)."""
    me = ob.data
    n = len(me.polygons)
    cen, nor, area = np.empty(n * 3), np.empty(n * 3), np.empty(n)
    lt, ls = np.empty(n, np.int32), np.empty(n, np.int32)
    me.polygons.foreach_get("center", cen)
    me.polygons.foreach_get("normal", nor)
    me.polygons.foreach_get("area", area)
    me.polygons.foreach_get("loop_total", lt)
    me.polygons.foreach_get("loop_start", ls)
    co = np.empty(len(me.vertices) * 3)
    me.vertices.foreach_get("co", co)
    co = co.reshape(-1, 3)
    lv = np.empty(len(me.loops), np.int32)
    me.loops.foreach_get("vertex_index", lv)
    mi = np.empty(n, np.int32)
    me.polygons.foreach_get("material_index", mi)
    ztop = np.maximum.reduceat(co[lv, 2], ls) if n else np.empty(0)
    return {"cen": cen.reshape(-1, 3), "nor": nor.reshape(-1, 3), "area": area, "lt": lt, "ls": ls, "co": co, "lv": lv,
            "ztop": ztop, "mi": mi}


def path_distance(cen, P):
    """Horizontal distance from each face to the nearest camera sample."""
    d = np.full(len(cen), 1e9)
    for p in P:
        d = np.minimum(d, np.hypot(cen[:, 0] - p[0], cen[:, 1] - p[1]))
    return d


def seen(f, P, D):
    """Distance to the nearest camera sample that has the face in its sweep and in front of it (1e9: never)."""
    cen, nor = f["cen"], f["nor"]
    best = np.full(len(cen), 1e9)
    cos_half = math.cos(math.radians(HALF_VIEW))
    for p, h in zip(P, D):
        v = cen - p                                    # camera -> face
        dh = np.hypot(v[:, 0], v[:, 1]) + 1e-6
        ahead = (v[:, 0] * h[0] + v[:, 1] * h[1]) / dh > cos_half
        d3 = np.linalg.norm(v, axis=1) + 1e-6
        facing = -(v * nor).sum(1) / d3 > 0.02
        ok = ahead & facing
        best = np.where(ok & (dh < best), dh, best)
    return best


def keep_mask(f, P, D):
    d = seen(f, P, D)
    big = f["area"] >= np.maximum(MIN_AREA, (d / AREA_K) ** 2)
    sky = (d <= NEAR) | (f["ztop"] >= SKY_BASE + SKY_SLOPE * (d - NEAR))
    return (d < FAR) & big & sky & ~plates(f), d


def plates(f):
    return (np.abs(f["nor"][:, 2]) > 0.9) & (f["ztop"] > PLATE_Z) & (f["area"] > PLATE_AREA)


def islands(f, pick):
    """Label the connected pieces among the picked faces (numpy label spreading). Returns a label per picked face."""
    idx = np.nonzero(pick)[0]
    lt, ls, lv = f["lt"][idx], f["ls"][idx], f["lv"]
    first = lv[ls]
    lab = np.arange(len(f["co"]))
    e0, e1 = [], []
    for k in range(1, int(lt.max())):
        m = lt > k
        e0.append(first[m])
        e1.append(lv[ls[m] + k])
    e0, e1 = np.concatenate(e0), np.concatenate(e1)
    for _ in range(200):
        low = np.minimum(lab[e0], lab[e1])
        new = lab.copy()
        np.minimum.at(new, e0, low)
        np.minimum.at(new, e1, low)
        new = new[new]
        if np.array_equal(new, lab):
            break
        lab = new
    return lab[first]


def ico():
    global ICO
    if ICO is None:
        t = (1 + 5 ** 0.5) / 2
        n = (1 + t * t) ** 0.5
        v = np.array([(-1, t, 0), (1, t, 0), (-1, -t, 0), (1, -t, 0), (0, -1, t), (0, 1, t),
                      (0, -1, -t), (0, 1, -t), (t, 0, -1), (t, 0, 1), (-t, 0, -1), (-t, 0, 1)], float) / n
        fs = [(0, 11, 5), (0, 5, 1), (0, 1, 7), (0, 7, 10), (0, 10, 11), (1, 5, 9), (5, 11, 4), (11, 10, 2), (10, 7, 6),
              (7, 1, 8), (3, 9, 4), (3, 4, 2), (3, 2, 6), (3, 6, 8), (3, 8, 9), (4, 9, 5), (2, 4, 11), (6, 2, 10), (8, 6, 7), (9, 8, 1)]
        ICO = (v, np.array(fs))
    return ICO


class Bag:
    """Faces gathered for one output mesh: polygons of any size, with a colour per face."""

    def __init__(self):
        self.co, self.loops, self.lt, self.col, self.nv = [], [], [], [], 0

    def take(self, f, mask, rgb):
        idx = np.nonzero(mask)[0]
        if not len(idx):
            return 0
        lt, ls = f["lt"][idx], f["ls"][idx]
        li = np.repeat(ls, lt) + (np.arange(lt.sum()) - np.repeat(np.cumsum(lt) - lt, lt))
        vi = f["lv"][li]
        used, inv = np.unique(vi, return_inverse=True)
        self.co.append(f["co"][used])
        self.loops.append(inv + self.nv)
        self.lt.append(lt)
        c = np.asarray(rgb, float)
        self.col.append(np.tile(c, (len(idx), 1)) if c.ndim == 1 else c[idx])
        self.nv += len(used)
        return int((lt - 2).sum())

    def lump(self, x, y, z, rx, rz, turn, rgb, simple=False):
        v, fs = OCT if simple else ico()
        ca, sa = math.cos(turn), math.sin(turn)
        w = np.column_stack((v[:, 0] * ca - v[:, 1] * sa, v[:, 0] * sa + v[:, 1] * ca, v[:, 2]))
        self.co.append(w * (rx, rx, rz) + (x, y, z))
        self.loops.append(fs.ravel() + self.nv)
        self.lt.append(np.full(len(fs), 3, np.int32))
        self.col.append(np.tile(np.asarray(rgb, float), (len(fs), 1)))
        self.nv += len(v)

    def tris(self):
        return int(sum((x - 2).sum() for x in self.lt))

    def object(self, name, mat, coloured):
        if not self.nv:
            return None
        co, loops, lt = np.concatenate(self.co), np.concatenate(self.loops), np.concatenate(self.lt)
        me = bpy.data.meshes.new(name)
        me.vertices.add(len(co))
        me.vertices.foreach_set("co", co.ravel())
        me.loops.add(len(loops))
        me.loops.foreach_set("vertex_index", loops.astype(np.int32))
        me.polygons.add(len(lt))
        me.polygons.foreach_set("loop_start", (np.cumsum(lt) - lt).astype(np.int32))
        me.polygons.foreach_set("loop_total", lt.astype(np.int32))
        me.update(calc_edges=True)
        me.validate()
        if coloured:
            col = np.repeat(np.concatenate(self.col), lt, axis=0)
            ca = me.color_attributes.new("Color", "BYTE_COLOR", "CORNER")
            ca.data.foreach_set("color", np.column_stack((col, np.ones(len(col)))).ravel())
        me.materials.append(mat)
        ob = bpy.data.objects.new(name, me)
        bpy.context.scene.collection.objects.link(ob)
        return ob


def flat_material(name, rgb=(0.8, 0.8, 0.8), vertex=False):
    m = bpy.data.materials.new(name)
    m.diffuse_color = (*rgb, 1.0)
    m.use_nodes = True
    b = m.node_tree.nodes.get("Principled BSDF")
    b.inputs["Base Color"].default_value = (*rgb, 1.0)
    b.inputs["Roughness"].default_value = 0.85
    if vertex:
        a = m.node_tree.nodes.new("ShaderNodeVertexColor")
        a.layer_name = "Color"
        m.node_tree.links.new(a.outputs["Color"], b.inputs["Base Color"])
    return m


def in_tower(cen, t):
    return np.hypot(cen[:, 0] - t["at"][0], cen[:, 1] - t["at"][1]) < t.get("footprint_r", 0.0)


def ring_of(t):
    fp = os.path.join(REPO, "reference", "sites", t["site"], "site.json")
    if t.get("footprint_r") or not os.path.exists(fp):
        return None
    s = json.load(open(fp))
    ring = s.get("osm_outline", {}).get("ring_local")
    if not ring:
        return None
    return np.array(ring, float) + np.array(t["at"])


def inside(ring, xy, pad=4.0):
    """Points inside the ring (even-odd), grown by a bounding pad first so the facade's own faces count."""
    c = ring.mean(0)
    r = c + (ring - c) * (1.0 + pad / max(1.0, np.abs(ring - c).max()))
    x, y = xy[:, 0], xy[:, 1]
    hit = np.zeros(len(xy), bool)
    for (x0, y0), (x1, y1) in zip(r, np.roll(r, -1, axis=0)):
        if y0 == y1:
            continue
        cross = ((y0 > y) != (y1 > y)) & (x < (x1 - x0) * (y - y0) / (y1 - y0) + x0)
        hit ^= cross
    return hit


def cut(c):
    """Walk every mesh of the built scene and bag what the path's camera sees."""
    P, D = samples(c)
    rings = {k: ring_of(t) for k, t in c["towers"].items()}
    own, shared, ground, crowns = {}, Bag(), Bag(), Bag()
    towers = {k: Bag() for k in c["towers"]}
    weight, src_tris, kept_by, by_src = {}, 0, {}, {}
    lumps, tower_parts = [], {k: [] for k in c["towers"]}
    pano_hide = {}                                           # object name -> kept mask (the panorama leaves these out)
    for ob in list(bpy.data.objects):
        if ob.type != "MESH" or not ob.data.polygons:
            continue
        if ob.matrix_world != ob.matrix_world.Identity(4):
            ob.data.transform(ob.matrix_world)
            ob.matrix_world = ob.matrix_world.Identity(4)
        f = faces(ob)
        src_tris += int((f["lt"] - 2).sum())
        name = ob.name
        mats = [m for m in ob.data.materials]
        rgbs = np.array([tuple(m.diffuse_color)[:3] if m else (0.6, 0.6, 0.6) for m in mats] or [(0.6, 0.6, 0.6)])
        if name.startswith(DROP) or any(w in name for w in DROP_IN):
            continue
        if name.startswith(GROUND) or any(w in name for w in GROUND_IN):
            m = (path_distance(f["cen"], P) < GROUND_R) & (f["ztop"] > L.RIVER_LEVEL_AHD - 0.5)
            pano_hide[name] = m
            # (the aerial-draped ground has no colour of its own: the river bank's grass and mud stand in)
            plain = np.array([m is None or "aerial" in m.name or min(tuple(m.diffuse_color)[:3]) > 0.55 for m in (mats or [None])])
            grgb = np.where(plain[:, None], np.array(BANK), rgbs)
            kept_by["ground"] = kept_by.get("ground", 0) + ground.take(f, m, grgb[np.clip(f["mi"], 0, len(grgb) - 1)])
            continue
        if name.startswith(CROWNS) or any(w in name for w in CROWNS_IN):
            m = path_distance(f["cen"], P) < TREE_R
            pano_hide[name] = m
            if m.any():
                lab = islands(f, m)
                idx = np.nonzero(m)[0]
                order = np.argsort(lab, kind="stable")
                lab_s, idx_s = lab[order], idx[order]
                starts = np.nonzero(np.r_[True, lab_s[1:] != lab_s[:-1]])[0]
                cen = f["cen"][idx_s]
                lo = np.minimum.reduceat(cen, starts, axis=0)
                hi = np.maximum.reduceat(cen, starts, axis=0)
                rgb = rgbs[0]
                for a, b in zip(lo, hi):
                    rx = max(b[0] - a[0], b[1] - a[1]) * 0.5 + 0.6
                    if rx < TREE_MIN_R:
                        continue
                    x, y = (a[0] + b[0]) * 0.5, (a[1] + b[1]) * 0.5
                    rz = max((b[2] - a[2]) * 0.5 + 0.6, rx * 0.75) * 1.35
                    dist = min(math.hypot(x - p[0], y - p[1]) for p in P)
                    lumps.append((rx / max(dist, 60.0), x, y, b[2] + 0.6 - rz * 0.8, rx * 1.1, rz, tuple(rgb), dist > TREE_FULL_R))
            continue
        m, d = keep_mask(f, P, D)
        if any(w in name for w in TRIM):                     # slab-edge bands and balcony glass: only close up
            m &= d < TRIM_R
        pano_hide[name] = m
        for k, t in c["towers"].items():                     # the game tower's own footprint: its own object
            tm = inside(rings[k], f["cen"][:, :2]) if rings[k] is not None else in_tower(f["cen"], t)
            near = np.hypot(f["cen"][:, 0] - t["at"][0], f["cen"][:, 1] - t["at"][1]) < 400
            tm &= near & (f["area"] >= MIN_AREA) & ~plates(f)
            pano_hide[name] = pano_hide[name] | tm
            if tm.any():
                tower_parts[k].append((f, tm, rgbs[np.clip(f["mi"], 0, len(rgbs) - 1)]))
            m &= ~tm
        if not m.any():
            continue
        for i, mat in enumerate(mats or [None]):
            mm = m & (f["mi"] == i)
            if not mm.any():
                continue
            key = mat.name if mat else name
            own.setdefault(key, {"mat": mat, "parts": []})["parts"].append((f, mm))
            by_src[name] = by_src.get(name, 0) + int((f["lt"][mm] - 2).sum())
            weight[key] = weight.get(key, 0.0) + float((f["area"][mm] / np.maximum(d[mm], 30.0) ** 2).sum())
    # the facades that fill most of the picture keep their own material; the rest go into the shared mesh
    recipe = {k for k, v in own.items() if v["mat"] is not None and "win_bay" in v["mat"] and "win_glass" in v["mat"]}
    top = set(sorted(recipe, key=lambda k: -weight[k])[:OWN_MATERIALS])
    out = {"own": {}, "shared": shared, "ground": ground, "crowns": crowns, "towers": towers}
    for key, v in own.items():
        rgb = tuple(v["mat"].diffuse_color)[:3] if v["mat"] else (0.6, 0.6, 0.6)
        bag = out["own"].setdefault(key, Bag()) if key in top else shared
        for f, mm in v["parts"]:
            n = bag.take(f, mm, rgb)
            kept_by["own" if key in top else "shared"] = kept_by.get("own" if key in top else "shared", 0) + n
    print("   biggest sources:", sorted(by_src.items(), key=lambda x: -x[1])[:25])
    lumps.sort(key=lambda l: -l[0])                          # the biggest, nearest crowns
    for _, x, y, z, rx, rz, rgb, far in lumps[:TREE_MAX]:
        crowns.lump(x, y, z, rx, rz, abs(x * 3.1 + y * 1.7), rgb, far)
    for k, parts in tower_parts.items():                     # a tower's biggest faces, up to its share
        if not parts:
            continue
        area = np.concatenate([f["area"][tm] for f, tm, _ in parts])
        tri = np.concatenate([(f["lt"][tm] - 2) for f, tm, _ in parts])
        order = np.argsort(-area)
        over = np.nonzero(np.cumsum(tri[order]) > TOWER_TRIS)[0]
        floor = float(area[order][over[0]]) if len(over) else 0.0
        for f, tm, rgb in parts:
            towers[k].take(f, tm & (f["area"] > floor), rgb)
    kept_by["crowns"] = crowns.tris()
    kept_by["towers"] = sum(b.tris() for b in towers.values())
    return out, {"source_triangles": src_tris, "kept": kept_by, "samples": len(P)}, pano_hide, {k: own[k]["mat"] for k in top}


def assemble(c, cid, bags, mats):
    """The kept faces as the corridor's own objects; the rest of the scene is left as it is (for --check / --pano)."""
    made = []
    vcol = flat_material("cor_%s_paint" % cid, vertex=True)
    gcol = flat_material("cor_%s_ground" % cid, vertex=True)
    tcol = flat_material("cor_%s_trees" % cid, vertex=True)
    for key, bag in bags["own"].items():
        m = mats[key]
        ob = bag.object("cor_" + key, m, False)
        if ob:
            made.append(ob)
    for name, bag, mat in (("cor_shared", bags["shared"], vcol), ("cor_ground", bags["ground"], gcol), ("cor_trees", bags["crowns"], tcol)):
        ob = bag.object(name, mat, True)
        if ob:
            made.append(ob)
    for k, bag in bags["towers"].items():
        ob = bag.object("tower_" + k, vcol, True)
        if ob:
            made.append(ob)
    g = bpy.data.objects.get("cor_ground")
    if g:
        bpy.context.view_layer.objects.active = g
        tri = sum(len(p.vertices) - 2 for p in g.data.polygons)
        if tri > GROUND_TRIS:
            mod = g.modifiers.new("dec", "DECIMATE")
            mod.ratio = GROUND_TRIS / tri
            with bpy.context.temp_override(object=g, active_object=g, selected_objects=[g]):
                bpy.ops.object.modifier_apply(modifier=mod.name)
    for ob in made:
        if ob.name != "cor_trees":
            continue
        for p in ob.data.polygons:
            p.use_smooth = True
    return made


def tri_count(obs):
    return sum(len(p.vertices) - 2 for o in obs for p in o.data.polygons)


def looks_of(mats):
    out = {}
    for name, m in mats.items():
        out[name] = {"glass": [round(float(x), 4) for x in m["win_glass"]][:3], "bay": float(m["win_bay"]),
                     "win": float(m["win_win"]), "sill": float(m["win_sill"]), "head": float(m["win_head"]),
                     "floor": float(m.get("win_floor", L.LEVEL_HEIGHT)), "diag": bool(m.get("diag", False)),
                     "wall": [round(float(x), 4) for x in tuple(m.diffuse_color)[:3]]}
    return out


def check_cams(c):
    P, D = samples(c)
    cams = []
    towers = list(c["towers"].values())
    for frac in (0.15, 0.45, 0.7, 0.92):
        i = int(frac * (len(P) - 1))
        t = towers[0]["at"]
        ahead = P[i][:2] + D[i] * 400.0
        look = (ahead * 0.55 + np.array(t) * 0.45)
        cams.append({"id": "path_%02d" % int(frac * 100), "pos": (float(P[i][0]), float(P[i][1]), float(P[i][2])),
                     "look_at": (float(look[0]), float(look[1]), 45.0), "lens": 22, "size": (960, 540)})
    return cams


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]
    cid = argv[0]
    c = CORRIDORS[cid]
    out_dir = os.path.abspath(next((a for a in argv[1:] if not a.startswith("--")), "corridor_out"))
    dry, check = "--dry" in argv, "--check" in argv
    pano = next((a[7:] for a in argv if a.startswith("--pano=")), None)
    import build_all
    import foliage
    import trees
    foliage.GAME = True
    trees.hero = lambda x, y: False
    trees.HERO_CENTRES = []
    build_all.build_all(None, write_meta=False)
    source = [o for o in bpy.data.objects if o.type == "MESH"]
    bags, stats, pano_hide, mats = cut(c)
    made = assemble(c, cid, bags, mats)
    stats["triangles"] = tri_count(made)
    stats["draws"] = len(made)
    stats["objects"] = {o.name: tri_count([o]) for o in sorted(made, key=lambda o: -len(o.data.polygons))}
    stats["budget"] = {"triangles": BUDGET_TRIS, "draws": BUDGET_DRAWS,
                       "within": stats["triangles"] <= BUDGET_TRIS and stats["draws"] <= BUDGET_DRAWS}
    print("corridor %s: %d -> %d triangles, %d draws (budget %d / %d)" % (
        cid, stats["source_triangles"], stats["triangles"], stats["draws"], BUDGET_TRIS, BUDGET_DRAWS))
    print("   kept before thinning:", stats["kept"])
    for n, t in list(stats["objects"].items())[:14]:
        print("   %-46s %7d" % (n, t))
    if check or pano:
        os.makedirs(out_dir, exist_ok=True)
        import preview as P
        import render_cbd as R
        P.setup_morning()
        P.apply_light(55.0, 32.0)
        R.setup_cycles(int(os.environ.get("CYC_SAMPLES", "24")))
    if check:
        for cam in check_cams(c):
            for which, show_src in (("all", True), ("cut", False)):
                for o in source:
                    o.hide_render = not show_src and not o.name.startswith(("river", "water"))
                for o in made:
                    o.hide_render = show_src
                R.shoot(dict(cam, id="%s_%s_%s" % (cid, cam["id"], which)), out_dir, 1.0)
    if pano:
        t = c["towers"][pano]
        render_pano(cid, pano, t, source, made, pano_hide, out_dir)
    if dry:
        return stats
    keep = {o.name for o in made}
    for o in list(bpy.data.objects):                 # (text and curves too: the exporter turns them into meshes)
        if o.name not in keep:
            bpy.data.objects.remove(o)
    for m in bpy.data.materials:                     # plain principled with the render colour (as export_game.py)
        if m.name.startswith("cor_%s_" % cid):
            continue
        col = tuple(m.diffuse_color)
        m.use_nodes = True
        b = m.node_tree.nodes.get("Principled BSDF")
        if b:
            b.inputs["Base Color"].default_value = col
            b.inputs["Roughness"].default_value = 0.85
    glb = os.path.join(REPO, "assets", "corridors", cid + ".glb")
    os.makedirs(os.path.dirname(glb), exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=glb, export_format="GLB", use_selection=False, export_yup=True, export_apply=True,
                              export_texcoords=False, export_normals=False, export_materials="EXPORT",
                              export_vertex_color="ACTIVE", export_all_vertex_colors=False,
                              export_cameras=False, export_lights=False, export_extras=False)
    P, _ = samples(c)
    data = {"id": cid, "name": c["name"], "glb": "res://assets/corridors/%s.glb" % cid,
            "frame": "as assets/spire/spire_site.glb: local x east, y north, z AHD (glTF y-up); origin = the Spire site",
            "path_provisional": [list(p) for p in c["path"]],
            "towers": {k: {"name": t["name"], "at": list(t["at"]), "top_ahd": t["top_ahd"], "object": "tower_" + k,
                           "equipment": t["equipment"]} for k, t in c["towers"].items()},
            "looks": looks_of(mats), "stats": stats,
            "rules": {"step_m": STEP, "half_view_deg": HALF_VIEW, "near_m": NEAR, "skyline": [SKY_BASE, SKY_SLOPE],
                      "far_m": FAR, "area_k": AREA_K, "ground_m": GROUND_R, "trees_m": TREE_R}}
    jp = os.path.join(REPO, "data", "corridors", cid + ".json")
    os.makedirs(os.path.dirname(jp), exist_ok=True)
    json.dump(data, open(jp, "w"), indent=1)
    print("corridor %s: %s (%.2f MB), %s" % (cid, glb, os.path.getsize(glb) / 1e6, jp))
    return stats


def render_pano(cid, tid, t, source, made, hide, out_dir):
    """The far city as a strip panorama from the tower's top: the scene with the corridor's own faces and
    everything nearer than NEAR * 2 taken out, sky see-through. 360 degrees round, 12 above to 30 below level."""
    for o in made:
        o.hide_render = True
    eye = np.array((t["at"][0], t["at"][1], t["top_ahd"] + 6.0))
    for o in source:
        o.hide_render = o.name.startswith(("river", "water"))        # (the game draws its own river)
        if not o.data.polygons or o.hide_render:
            continue
        n = len(o.data.polygons)
        cen = np.empty(n * 3)
        o.data.polygons.foreach_get("center", cen)
        cen = cen.reshape(-1, 3)
        kill = np.hypot(cen[:, 0] - eye[0], cen[:, 1] - eye[1]) < NEAR * 2
        if o.name in hide:
            kill |= hide[o.name]
        if kill.all():
            o.hide_render = True
        elif kill.any():
            import bmesh
            bm = bmesh.new()
            bm.from_mesh(o.data)
            bm.faces.ensure_lookup_table()
            bmesh.ops.delete(bm, geom=[bm.faces[i] for i in np.nonzero(kill)[0]], context="FACES")
            bm.to_mesh(o.data)
            bm.free()
    import preview as P
    cam = P.camera("cam_pano")
    cam.data.type = "PANO"
    cam.data.panorama_type = "EQUIRECTANGULAR"
    cam.data.latitude_min, cam.data.latitude_max = math.radians(-30.0), math.radians(12.0)
    cam.data.longitude_min, cam.data.longitude_max = -math.pi, math.pi
    cam.data.clip_start, cam.data.clip_end = 1.0, 12000
    cam.location = eye
    cam.rotation_euler = (math.pi / 2, 0.0, 0.0)             # level, looking north: the strip's middle is north
    bpy.context.scene.render.image_settings.color_mode = "RGBA"     # (the sky stays see-through: the game's own sky shows)
    P.render(os.path.join(out_dir, "%s_pano_%s.png" % (cid, tid)), 4096, 480, transparent=True)


if __name__ == "__main__":
    main()
