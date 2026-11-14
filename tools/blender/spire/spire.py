"""Spire itself (finished, or as a site at a stage): sloped brick podium, tower storeys, and every slab
as its own object per pour area (SLAB_L07_A / SLAB_L07_B). The slabs wrap round the core (core.py),
split by the construction joint in layout.JOINT. Numbers from layout.py."""
import json
import math

import layout as L
import common as C

EPS = 1e-6


def ccw(ring):
    return ring if C.signed_area(ring) > 0 else ring[::-1]


def inset(ring, d):
    """Move a closed CCW ring inwards by d (+) or outwards (-) (vertex-normal offset)."""
    ring = ccw(ring)
    closed = ring + ring[:2]
    return C.offset_line([ring[-1]] + closed, d)[1:len(ring) + 1]


def clip_u(ring, uj, keep_less):
    """Keep the part of a (u, v) ring with u <= uj (keep_less) or u >= uj."""
    def inside(p):
        return p[0] <= uj + EPS if keep_less else p[0] >= uj - EPS
    out = []
    n = len(ring)
    for i in range(n):
        p, q = ring[i], ring[(i + 1) % n]
        if inside(p):
            out.append(p)
        if inside(p) != inside(q):
            t = (uj - p[0]) / (q[0] - p[0])
            out.append((uj, p[1] + (q[1] - p[1]) * t))
    return out


def notch(poly, uj, cu, cv0, cv1):
    """Cut the core (u between uj and cu, v0..v1) out of a half that ends on the line u = uj.
    Returns (polygon, (v_low, v_high) of the cut edge)."""
    n = len(poly)
    for i in range(n):
        p, q = poly[i], poly[(i + 1) % n]
        if abs(p[0] - uj) < 1e-4 and abs(q[0] - uj) < 1e-4 and abs(p[1] - q[1]) > 1e-4:
            if p[1] < q[1]:
                path = [(uj, cv0), (cu, cv0), (cu, cv1), (uj, cv1)]
            else:
                path = [(uj, cv1), (cu, cv1), (cu, cv0), (uj, cv0)]
            return poly[:i + 1] + path + poly[i + 1:], (min(p[1], q[1]), max(p[1], q[1]))
    return poly, None


def pour_areas(ring_local):
    """Split a slab outline round the core into pour areas A (u <= joint) and B.
    Returns {"A": local ring, "B": local ring}, joint lines in local metres."""
    ring = ccw([L.local_to_uv(*p) for p in ring_local])
    u0, u1, v0, v1 = L.core_uv()
    uj = L.joint_u()
    a, cut = notch(ccw(clip_u(ring, uj, True)), uj, u0, v0, v1)
    b, _ = notch(ccw(clip_u(ring, uj, False)), uj, u1, v0, v1)
    joints = []
    if cut:
        joints = [[L.uv_to_local(uj, cut[1]), L.uv_to_local(uj, v1)], [L.uv_to_local(uj, v0), L.uv_to_local(uj, cut[0])]]
    tolocal = lambda poly: [L.uv_to_local(*p) for p in poly]
    return {"A": tolocal(a), "B": tolocal(b)}, joints


def lot_outline():
    o = L.osm()
    return ccw(C.clean_ring(o["line"](o["ways"][L.SPIRE["osm_way"]])))


def podium_bottom(lot):
    """Lot ring with the two Ann St corners pulled in (the brick face leans out to the boundary)."""
    out = list(lot)
    (ax, ay), (bx, by) = L.PODIUM["ann_st_corners"]
    ex, ey = bx - ax, by - ay
    ln = math.hypot(ex, ey)
    nx, ny = ey / ln, -ex / ln               # into the lot (right of west->north corner direction)
    s = L.PODIUM["ann_st_setback_at_ground_m"]
    for corner in L.PODIUM["ann_st_corners"]:
        i = min(range(len(out)), key=lambda k: math.dist(out[k], corner))
        out[i] = (out[i][0] + nx * s, out[i][1] + ny * s)
    return out


def grid_points(ring, step, keep_out=1.0):
    """Points on a step grid (plan frame) inside ring, clear of the core."""
    uvr = [L.local_to_uv(*p) for p in ring]
    us = [p[0] for p in uvr]
    vs = [p[1] for p in uvr]
    cu0, cu1, cv0, cv1 = L.core_uv()
    inner = inset(ring, keep_out)
    pts = []
    u = math.floor(min(us) / step) * step + step / 2
    while u < max(us):
        v = math.floor(min(vs) / step) * step + step / 2
        while v < max(vs):
            if not (cu0 - 0.5 < u < cu1 + 0.5 and cv0 - 0.5 < v < cv1 + 0.5):
                x, y = L.uv_to_local(u, v)
                if C.point_in_ring(x, y, inner):
                    pts.append((x, y))
            v += step
        u += step
    return pts


def build():
    st = L.stage()
    col = C.collection("spire")
    levels = L.spire_levels()
    lot = lot_outline()
    plate = ccw(L.tower_outline())
    ground_min = min(L.ground_z(x, y) for x, y in lot)
    deck = st["deck_level"] if st else None
    objs, slabs, joint_lines = [], [], None

    def outline_for(lv):
        return lot if lv["kind"] in ("ground", "podium") else plate

    # ---------------------------------------------------------------- slabs (one object per pour area)
    for lv in levels:
        if deck is not None and lv["n"] > deck:
            break
        ring = outline_for(lv)
        z1 = lv["top_ahd"]
        z0 = z1 - lv["slab_m"] if lv["kind"] != "ground" else ground_min - 0.5
        key = "transfer" if lv["kind"] == "transfer" else "slab"
        if lv["kind"] == "ground":
            parts, joints = {"1": ring}, []
        else:
            parts, joints = pour_areas(ring)
            if lv["kind"] == "tower" and joint_lines is None:
                joint_lines = joints
        for tag, part in parts.items():
            if len(part) < 3:
                continue
            on_deck = deck is not None and lv["n"] == deck
            poured = not on_deck or tag in st["deck_pours_done"]
            buf = C.MeshBuf()
            if poured:
                buf.prism(part, z0, z1)
                mat = key if tag != "B" else key + "_b"
            else:
                buf.prism(part, z0 + lv["slab_m"] * 0.45, z0 + lv["slab_m"] * 0.55)   # reo mat
                mat = "reo"
            name = "SLAB_%s_%s" % (lv["name"], tag)
            ob = buf.object(name, col, mat)
            ob["level"] = lv["name"]
            ob["pour_area"] = tag
            ob["poured"] = poured
            ob["top_ahd"] = z1
            ob["thickness_m"] = lv["slab_m"]
            ob["area_m2"] = round(C.signed_area(ccw(part)), 1)
            ob["joint_lines"] = json.dumps([[[round(v, 2) for v in p] for p in seg] for seg in joints])
            ob["joint_is_assumption"] = L.JOINT["assumption"]
            slabs.append({"name": name, "level": lv["name"], "pour_area": tag, "poured": poured,
                          "area_m2": ob["area_m2"]})
            if on_deck:   # formwork deck under both pour areas
                fb = C.MeshBuf()
                fb.prism(part, z0 - 0.25, z0)
                objs.append(fb.object("FORMWORK_%s_%s" % (lv["name"], tag), col, "formwork").name)

    if st is None:
        # ------------------------------------------------------------ finished: podium, storeys, parapet
        top_podium = next(lv for lv in levels if lv["name"] == L.PODIUM["top_level"])["top_ahd"]
        pb = C.MeshBuf()
        pb.loft(podium_bottom(lot), ground_min - 0.5, lot, top_podium)
        objs.append(pb.object("SPIRE_podium_brick", col, "brick").name)
        sb = C.MeshBuf()
        for lo, hi in zip(levels[:-1], levels[1:]):
            if lo["kind"] in ("ground", "podium"):
                continue
            sb.prism(inset(plate, 0.6), lo["top_ahd"], hi["top_ahd"] - hi["slab_m"])
        objs.append(sb.object("SPIRE_storeys", col, "spire").name)
        top = levels[-1]["top_ahd"]
        pp = C.MeshBuf()
        pp.prism(inset(plate, 0.3), top, top + L.LEVELS["parapet_m"])
        objs.append(pp.object("SPIRE_parapet", col, "spire").name)
    else:
        # ------------------------------------------------------------ site: columns, props, screens
        by_n = {lv["n"]: lv for lv in levels}
        cb = C.MeshBuf()
        for n in range(0, deck):
            lo, hi = by_n[n], by_n[n + 1]
            for x, y in grid_points(outline_for(hi), st["column_grid_m"]):
                cb.box(x, y, lo["top_ahd"], 0.6, 0.6, hi["top_ahd"] - hi["slab_m"] - lo["top_ahd"])
        objs.append(cb.object("COLUMNS_assumed_grid", col, "column").name)
        pr = C.MeshBuf()
        for k in range(0, st["props_levels_below"] + 1):
            hi = by_n[deck - k]
            lo = by_n[deck - k - 1]
            step = 1.5 if k == 0 else 3.0                       # formwork props, then backprops
            under = hi["top_ahd"] - hi["slab_m"] - (0.25 if k == 0 else 0.0)
            for x, y in grid_points(outline_for(hi), step, 0.6):
                pr.box(x, y, lo["top_ahd"], 0.12, 0.12, under - lo["top_ahd"])
        objs.append(pr.object("PROPS_and_backprops", col, "prop").name)
        z0 = by_n[deck - st["screen_levels"]]["top_ahd"]
        z1 = by_n[deck]["top_ahd"] + st["screen_above_deck_m"]
        scr = C.MeshBuf()
        outer, inner = inset(plate, -0.8), inset(plate, -0.65)
        n = len(outer)
        for i in range(n):
            j = (i + 1) % n
            scr.add([(*inner[i], z0), (*outer[i], z0), (*outer[j], z0), (*inner[j], z0),
                     (*inner[i], z1), (*outer[i], z1), (*outer[j], z1), (*inner[j], z1)],
                    [[0, 1, 5, 4], [1, 2, 6, 5], [2, 3, 7, 6], [3, 0, 4, 7]])
        objs.append(scr.object("EDGE_SCREENS", col, "screen").name)

    typ = levels[-1]["typical_ftf_solved_m"]
    return {"module": "spire", "stage": st["name"] if st else "finished", "objects": objs,
            "slabs": slabs, "slab_objects": len(slabs), "levels_total": len(levels),
            "base_ahd": levels[0]["top_ahd"], "roof_ahd": levels[-1]["top_ahd"], "typical_ftf_m": typ,
            "plate_area_m2": round(C.signed_area(plate), 1), "lot_area_m2": round(C.signed_area(lot), 1),
            "joint": {"plan_px_x": L.JOINT["plan_px_x"], "assumption": True,
                      "lines_local": [[[round(v, 2) for v in p] for p in seg] for seg in (joint_lines or [])]},
            "note": "Typical floor to floor %.2f m is solved from the OSM height (low; check a section). "
                    "Joint position and column grid are assumptions." % typ}
