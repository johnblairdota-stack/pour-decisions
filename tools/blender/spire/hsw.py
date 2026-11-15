"""Howard Smith Wharves (its own level later), clean.

As built (finished stage):
- buildings of the strip from the clean builder (OSM footprints + LiDAR-measured tiers): the heritage
  wharf sheds (Felons Barrel Hall, Rivershed, Felons Brewing Co), the Crystalbrook Vincent hotel, ...
- the riverwalk as a timber deck on steel cantilever beams and headstocks (RESEARCH.md)
- Mr Percival's over-water bar: 30 x 20 m deck on piles beside the bridge's north pier, light pavilion roof
- a corten lift tower against the cliff with stair landings and a link to the cliff top (photo
  hb-m-hsw-shoot2-2, position estimated)

Mid-build stage "hsw_2017" (late 2017, from my_photos/hsw and RESEARCH.md):
- basement dig at the hotel footprint with shotcrete walls (ground.py lowers the ground there)
- rock anchors in a grid on the cliff face behind the dig
- one tower crane beside the dig
- shed E (Felons Barrel Hall, the over-water shed east of the bridge pier) lifted on temporary steel
- boardwalk headstocks and piles without the deck; blue hoarding along the strip
"""
import math

import numpy as np

import layout as L
import common as C
import buildings as B
import shapes as S

DECK_AHD = 3.6
DECK_W = 5.0
CANTILEVER_STEP = 5.0


def boardwalk(col, with_deck=True):
    o = L.osm()
    hx0, hy0, hx1, hy1 = B.HSW_ZONE
    deck, beams = C.MeshBuf(), C.MeshBuf()
    walks = 0
    for wid, w in o["ways"].items():
        t = w.get("tags", {})
        if t.get("highway") not in ("footway", "cycleway", "living_street", "path", "pedestrian"):
            continue
        pts = o["line"](w)
        if len(pts) < 2 or not any(hx0 <= x <= hx1 and hy0 <= y <= hy1 for x, y in pts):
            continue
        if not [p for p in pts if L.ground_z(*p) < 2.5] and "Riverwalk" not in t.get("name", ""):
            continue
        pts = C.densify(pts, 2.0)
        left, right = C.offset_line(pts, DECK_W / 2), C.offset_line(pts, -DECK_W / 2)
        n = len(pts)
        z = [max(DECK_AHD, L.ground_z(*p) + 0.15) for p in pts]
        if with_deck:
            verts = ([(x, y, zz) for (x, y), zz in zip(left, z)] + [(x, y, zz) for (x, y), zz in zip(right, z)] +
                     [(x, y, zz - 0.35) for (x, y), zz in zip(left, z)] + [(x, y, zz - 0.35) for (x, y), zz in zip(right, z)])
            faces = [[i, n + i, n + i + 1, i + 1] for i in range(n - 1)]
            faces += [[2 * n + i + 1, 3 * n + i + 1, 3 * n + i, 2 * n + i] for i in range(n - 1)]
            faces += [[i, i + 1, 2 * n + i + 1, 2 * n + i] for i in range(n - 1)]
            faces += [[n + i + 1, n + i, 3 * n + i, 3 * n + i + 1] for i in range(n - 1)]
            deck.add(verts, faces)
        acc = 0.0
        for i in range(1, n):
            acc += math.dist(pts[i - 1], pts[i])
            if acc >= CANTILEVER_STEP:
                acc = 0.0
                (lx, ly), (rx, ry) = left[i], right[i]
                beams.beam((lx, ly, z[i] - 0.6), (rx, ry, z[i] - 0.6), 0.45)                       # headstock / cantilever
                mx, my = (lx + rx) / 2, (ly + ry) / 2
                beams.beam((mx, my, z[i] - 0.6), (mx, my, min(L.ground_z(mx, my), 0.0) - 1.0), 0.6)   # pile
        walks += 1
    objs = []
    for buf, name, key in ((deck, "hsw_boardwalk_deck", "timber"), (beams, "hsw_boardwalk_headstocks_piles", "steel")):
        ob = buf.object(name, col, key)
        if ob:
            objs.append(ob.name)
    return objs, walks


def percivals(col):
    P = L.HSW["mr_percivals"]
    cx, cy, ln, wd, ang = P["centre_xy"][0], P["centre_xy"][1], P["size_m"][0], P["size_m"][1], math.radians(P["angle_deg"])
    deck, frame, roof = C.MeshBuf(), C.MeshBuf(), C.MeshBuf()
    deck.box(cx, cy, P["deck_ahd"] - 0.5, ln, wd, 0.5, ang)
    c, s = math.cos(ang), math.sin(ang)
    for i in range(int(ln // 5) + 1):
        for j in range(int(wd // 5) + 1):
            u, v = -ln / 2 + i * ln / int(ln // 5), -wd / 2 + j * wd / int(wd // 5)
            x, y = cx + u * c - v * s, cy + u * s + v * c
            frame.box(x, y, -3.0, 0.5, 0.5, P["deck_ahd"] - 0.5 + 3.0)                         # piles
            if i % 2 == 0 and j % 2 == 0:
                frame.box(x, y, P["deck_ahd"], 0.25, 0.25, P["roof_m"])                        # pavilion posts
    roof.box(cx, cy, P["deck_ahd"] + P["roof_m"], ln * 0.8, wd * 0.8, 0.35, ang)
    frame.box(cx, cy, P["deck_ahd"], ln * 0.3, 2.0, 1.1, ang)                                   # the bar
    return [deck.object("mr_percivals_deck", col, "timber").name, frame.object("mr_percivals_piles_posts", col, "steel").name,
            roof.object("mr_percivals_roof", col, "roof").name]


def lift_towers(col):
    objs = []
    for k, t in enumerate(L.HSW["lift_towers"]):
        x, y = t["xy"]
        g = L.ground_z(x, y)
        top = t["top_ahd"]
        cb, gb = C.MeshBuf(), C.MeshBuf()
        ang = math.radians(t["face_deg"])
        cb.box(x, y, g, 4.0, 4.0, top - g, ang)                                                   # corten shaft
        ux, uy = math.cos(ang), math.sin(ang)
        z = g + 4.0
        while z < top - 1:
            cb.box(x + ux * 4.0, y + uy * 4.0, z, 3.6, 3.0, 0.25, ang)                            # stair landings
            gb.box(x + ux * 5.7, y + uy * 5.7, z + 0.25, 0.08, 3.0, 1.1, ang)                     # glass balustrade
            z += 3.6
        cx, cy = t["cliff_top_xy"]
        dx, dy = cx - x, cy - y
        cb.box((x + cx) / 2, (y + cy) / 2, top - 1.2, math.hypot(dx, dy), 2.4, 0.4, math.atan2(dy, dx))   # link bridge
        objs += [cb.object("hsw_lift_tower_%d_corten" % k, col, "corten").name,
                 gb.object("hsw_lift_tower_%d_glass" % k, col, "balustrade").name]
    return objs


def midbuild(col, st):
    objs = []
    hotel = L.HSW["hotel_way"]
    o = L.osm()
    ring = S.clean(o["line"](o["ways"][hotel]), 0.3)
    base = min(L.ground_z(x, y) for x, y in ring)
    # shotcrete basement walls round the dig (the ground inside is lowered by ground.py)
    sw = C.MeshBuf()
    n = len(ring)
    for i in range(n):
        (ax, ay), (bx, by) = ring[i], ring[(i + 1) % n]
        mx, my = (ax + bx) / 2, (ay + by) / 2
        sw.box(mx, my, base - st["dig_depth_m"], math.dist((ax, ay), (bx, by)), 0.35, st["dig_depth_m"] + 0.4,
               math.atan2(by - ay, bx - ax))
    objs.append(sw.object("hsw_dig_shotcrete_walls", col, "shotcrete").name)
    # rock anchors on the cliff behind the dig: 2.5 m grid on steep ground north of the hotel
    an = C.MeshBuf()
    cx = sum(p[0] for p in ring) / n
    ymax = max(p[1] for p in ring)
    xs = [p[0] for p in ring]
    count = 0
    for x in np.arange(min(xs) - 5, max(xs) + 5, 2.5):
        for y in np.arange(ymax - 5, ymax + 30, 2.5):
            z = L.ground_z(x, y)
            dz = abs(L.ground_z(x, y + 1) - L.ground_z(x, y - 1)) / 2
            if dz > 0.8:
                an.box(x, y - 0.3, z, 0.35, 0.35, 0.35)
                count += 1
    objs.append(an.object("hsw_rock_anchors", col, "anchor").name)
    # tower crane beside the dig
    kx, ky = st["crane_xy"]
    kz = L.ground_z(kx, ky)
    cr = C.MeshBuf()
    cr.box(kx, ky, kz, 1.8, 1.8, st["crane_height_m"])
    h = math.radians(st["crane_jib_deg"])
    cr.box(kx + math.cos(h) * 22, ky + math.sin(h) * 22, kz + st["crane_height_m"], 44, 1.3, 1.5, h)
    cr.box(kx - math.cos(h) * 7, ky - math.sin(h) * 7, kz + st["crane_height_m"], 14, 2.0, 1.2, h)
    cr.box(kx, ky, kz + st["crane_height_m"] + 1.5, 1.1, 1.1, 8.0)
    objs.append(cr.object("hsw_tower_crane", col, "crane").name)
    # shed E lifted on temporary steel
    meta = B.build(zone=None, collection="hsw", only={st["shed_e_way"]}, lift=st["shed_lift_m"], suffix="_shedE_lifted")
    objs += meta["objects"]
    rec = next(b for b in B.records() if b["osm"] == st["shed_e_way"])
    sring = rec["tiers"][0]["ring"]
    cxs, cys, ln, wd, ang = S.min_rect(sring)
    stl = C.MeshBuf()
    c, s = math.cos(ang), math.sin(ang)
    for i in range(int(ln // 4) + 1):
        for j in range(int(wd // 4) + 1):
            u = -ln / 2 + i * ln / max(1, int(ln // 4))
            v = -wd / 2 + j * wd / max(1, int(wd // 4))
            x, y = cxs + u * c - v * s, cys + u * s + v * c
            stl.box(x, y, rec["base_ahd"] - 1.0, 0.3, 0.3, st["shed_lift_m"] + 1.0)
    objs.append(stl.object("hsw_shedE_temporary_steel", col, "steel").name)
    # hoarding along the landward edge of the strip
    hb = C.MeshBuf()
    hx0, hy0, hx1, hy1 = B.HSW_ZONE
    for x in np.arange(hx0, hx1, 6.0):
        best = None
        for y in np.arange(hy0, hy1, 1.0):
            if 2.5 < L.ground_z(x, y) < 6.0:
                best = y
        if best is not None:
            hb.box(x + 3, best, L.ground_z(x + 3, best), 6.0, 0.1, 2.4)
    objs.append(hb.object("hsw_hoarding", col, "hoarding").name)
    return objs, {"anchors": count, "dig_depth_m": st["dig_depth_m"], "shed_e": rec["name"]}


def build():
    st = L.hsw_stage()
    col = C.collection("hsw")
    excl = ()
    if st:
        excl = (L.HSW["hotel_way"], st["shed_e_way"])
    meta = B.build(zone=B.HSW_ZONE, collection="hsw", exclude=excl)
    objs = list(meta["objects"])
    bw, walks = boardwalk(col, with_deck=st is None)
    objs += bw
    out = {}
    if st is None:
        objs += percivals(col) + lift_towers(col)
    else:
        mb, out = midbuild(col, st)
        objs += mb
    return {"module": "hsw", "stage": st["name"] if st else "as built (2019)", "objects": objs,
            "buildings": meta["buildings"], "boardwalk_ways": walks, "zone_local": B.HSW_ZONE, "midbuild": out,
            "note": "Lift tower position, Mr Percival's size and which shed is 'E' are estimates from the photos; "
                    "the dig depth and crane spot are assumptions."}
