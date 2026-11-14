"""Spire itself (finished, or as a site at a stage): sloped brick podium, tower storeys, and every slab
as its own object per pour area (SLAB_L07_A / SLAB_L07_B). The slabs wrap round the core (core.py),
split by the construction joint in layout.JOINT. Numbers from layout.py."""
import json
import math

import layout as L
import common as C
from looks import SPIRE_LOOK

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


def osm_lot():
    """The OSM lot / site boundary (hoarding line)."""
    o = L.osm()
    return ccw(C.clean_ring(o["line"](o["ways"][L.SPIRE["osm_way"]])))


BAY_M = 3.0


def walk(ring, step, start=0.0):
    """Points every `step` metres round a closed ring: (x, y, edge angle)."""
    out = []
    n = len(ring)
    carry = step - start          # distance since the last point (first point lands at `start`)
    for i in range(n):
        (ax, ay), (bx, by) = ring[i], ring[(i + 1) % n]
        ln = math.dist((ax, ay), (bx, by))
        if ln < 1e-6:
            continue
        ang = math.atan2(by - ay, bx - ax)
        t = step - carry
        last = None
        while t <= ln:
            out.append((ax + (bx - ax) * t / ln, ay + (by - ay) * t / ln, ang))
            last = t
            t += step
        carry = ln - last if last is not None else carry + ln
    return out


def crown(col, plate, top):
    """Spire's roof (step 7c, John's roof-pool photos + fly-by top-down): stone deck, glass balustrade with a
    white rounded top rail round the plate, an infinity pool along the W/SW curved edge, timber lounges and
    planters, and a curved cabana with black vertical louvres on the N side. As built only."""
    deck, rail, glass, pool, wood, louv, green = (C.MeshBuf() for _ in range(7))
    deck.prism(inset(plate, 0.3), top, top + 0.15)
    loop = inset(plate, 0.15)
    n = len(loop)
    for i in range(n):
        (ax, ay), (bx, by) = loop[i], loop[(i + 1) % n]
        glass.add([(ax, ay, top + 0.15), (bx, by, top + 0.15), (bx, by, top + 1.2), (ax, ay, top + 1.2)], [[0, 1, 2, 3]])
        rail.beam((ax, ay, top + 1.25), (bx, by, top + 1.25), 0.12)
    # pool: band 3.5 m wide inside the edge where the plan u < -6 (west end, curved)
    uvp = [L.local_to_uv(*q) for q in plate]
    outer = [q for q, (u, v) in zip(inset(plate, 0.6), uvp) if u < -6]
    inner = [q for q, (u, v) in zip(inset(plate, 4.1), uvp) if u < -6]
    if len(outer) >= 2:
        pool.prism(outer + inner[::-1], top + 0.15, top + 0.3)        # curved band = one closed ring
    # cabana: ring of louvres round a point on the north side (plan u +6, v +6)
    cx, cy = L.uv_to_local(6.0, 6.0)
    for k in range(28):
        a = math.pi * 0.15 + k * math.pi * 1.2 / 27
        x, y = cx + 6.0 * math.cos(a), cy + 6.0 * math.sin(a)
        louv.box(x, y, top + 2.6, 0.08, 0.5, 2.6, a)
        louv.box(x, y, top + 0.15, 0.05, 0.05, 2.5)
    ring6 = [(cx + 6.4 * math.cos(2 * math.pi * k / 24), cy + 6.4 * math.sin(2 * math.pi * k / 24)) for k in range(24)]
    louv.prism(ring6, top + 5.2, top + 5.5)
    glass.prism([(cx + 5.6 * math.cos(2 * math.pi * k / 16), cy + 5.6 * math.sin(2 * math.pi * k / 16)) for k in range(16)],
                top + 0.15, top + 2.6)
    # lounges and planters along the inner edge of the pool deck
    for u in (-14.0, -10.0, -6.0):
        x, y = L.uv_to_local(u, -2.0)
        wood.box(x, y, top + 0.15, 2.2, 0.8, 0.45, math.radians(L.TOWER_PLAN["rotation_deg"]))
    for u, v in ((-12.0, 3.0), (-4.0, 5.0), (12.0, -5.0)):
        x, y = L.uv_to_local(u, v)
        louv.box(x, y, top + 0.15, 1.2, 1.2, 0.8)
        green.box(x, y, top + 0.95, 1.1, 1.1, 1.4)
    objs = []
    for buf, name, rgb in ((deck, "deck", (0.55, 0.54, 0.51)), (rail, "rail", (0.93, 0.93, 0.91)), (glass, "glass", (0.25, 0.30, 0.33)),
                           (pool, "pool", (0.05, 0.25, 0.55)), (wood, "lounges", (0.70, 0.50, 0.30)),
                           (louv, "cabana", (0.06, 0.06, 0.07)), (green, "planters", (0.25, 0.45, 0.20))):
        ob = buf.object("SPIRE_roof_" + name, col, "roof")
        if ob:
            ob.data.materials[0] = C.material_rgb("spire_roof_" + name, rgb)
            objs.append(ob.name)
    return objs


def queen_st_podium(col, lot, ground_min, top):
    """Queen St face of the podium (photos): glass shopfront at street level, vertical timber battens and a
    planted wall above. The Queen St edges are the lot edges facing east."""
    import foliage as FO
    bat, plant, shop = C.MeshBuf(), C.MeshBuf(), C.MeshBuf()
    green = FO.Foliage(seed=21)
    n = len(lot)
    for i in range(n):
        (ax, ay), (bx, by) = lot[i], lot[(i + 1) % n]
        ang = math.atan2(by - ay, bx - ax)
        nx, ny = math.sin(ang), -math.cos(ang)               # outward for a CCW ring
        if nx < 0.6:
            continue
        ln = math.dist((ax, ay), (bx, by))
        gz = min(L.ground_z(ax, ay), L.ground_z(bx, by))
        mx, my = (ax + bx) / 2, (ay + by) / 2
        shop.box(mx + nx * 0.1, my + ny * 0.1, gz, ln, 0.2, 4.2, ang)
        k = int(ln // 0.3)
        for j in range(k):
            t = (j + 0.5) / k
            bat.box(ax + (bx - ax) * t + nx * 0.2, ay + (by - ay) * t + ny * 0.2, gz + 4.5, 0.08, 0.15, (top - gz - 4.5) * 0.55, ang)
        z_led = top - 0.2                                               # planter ledge along the podium top
        plant.box(mx + nx * 0.45, my + ny * 0.45, z_led - 0.9, ln, 0.9, 0.9, ang)
        ux_, uy_ = math.cos(ang), math.sin(ang)
        k2 = max(2, int(ln / 1.6))
        for j in range(k2):                                              # spilling shrubs on the ledge
            tt = (j + 0.5) / k2 - 0.5
            green.cloud((mx + ux_ * tt * ln + nx * 0.6, my + uy_ * tt * ln + ny * 0.6, z_led + 0.3), (0.9, 0.6, 0.6), 35, 0.45, shell=0.5)
        hang = [(mx + ux_ * ((j + 0.5) / (k2 * 3) - 0.5) * ln + nx * 0.9, my + uy_ * ((j + 0.5) / (k2 * 3) - 0.5) * ln + ny * 0.9, z_led - 0.4)
                for j in range(k2 * 3)]
        green.strands(hang, (nx, ny), (top - gz - 4.5) * 0.7, 0.35, 0.5)  # trailing plants over the battens
        zm = gz + 4.5 + (top - gz - 4.5) * 0.55                          # vertical garden panel between battens
        green.cloud((mx + nx * 0.3, my + ny * 0.3, zm + (top - zm) * 0.4), (ln * 0.5, 0.25, (top - zm) * 0.45), int(ln * 25), 0.4, shell=0.2)
    objs = []
    for buf, name, key, col_ in ((bat, "SPIRE_queen_st_battens", "battens", SPIRE_LOOK["battens"]),
                                 (plant, "SPIRE_queen_st_planter_ledge", "ledge", (0.10, 0.10, 0.11)),
                                 (shop, "SPIRE_queen_st_shopfront", "shopfront", SPIRE_LOOK["shopfront"])):
        ob = buf.object(name, col, "roof")
        if ob:
            ob.data.materials[0] = C.material_rgb("spire_" + key, col_)
            objs.append(ob.name)
    og = green.object("SPIRE_green_facade", col, (0.04, 0.11, 0.03), (0.14, 0.27, 0.07))
    if og:
        objs.append(og.name)
    return objs


def lot_outline():
    """Podium slab edge: traced from the 2019 LiDAR (step 4); the OSM lot if that is missing."""
    try:
        return ccw(C.clean_ring(L.spire_podium_outline()))
    except OSError:
        return osm_lot()


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


def facade(col, levels, outline_for, plate, upto_n=None):
    """The as-built facade on every finished floor (one look in every view and stage): dark glass line set
    back under the slab, white frame posts (thick, varied, staggered floor to floor like the photos),
    white slab-edge bands and glass balustrades. upto_n: only storeys whose top level is below this."""
    objs = []
    sb, fr, gl, eb = C.MeshBuf(), C.MeshBuf(), C.MeshBuf(), C.MeshBuf()
    for lo, hi in zip(levels[:-1], levels[1:]):
        if upto_n is not None and hi["n"] > upto_n:
            break
        if lo["kind"] == "ground" or (lo["kind"] == "podium" and hi["kind"] == "podium"):
            continue
        inset_m = 0.2 if hi["kind"] == "transfer" else 0.9                     # L5->L6: flush, no dark recess
        sb.prism(inset(plate, inset_m), lo["top_ahd"] - 0.05, hi["top_ahd"] - hi["slab_m"] + 0.02)
        if lo["kind"] in ("ground", "podium"):
            continue
        ring = outline_for(lo)
        z0, z1 = lo["top_ahd"], hi["top_ahd"] - hi["slab_m"]
        h = (lo["n"] * 2654435761) % 1000 / 1000.0                       # per-floor stagger (photos: posts never line up)
        for x, y, ang in walk(inset(ring, 0.15), BAY_M, BAY_M * h):
            k = (int(x * 7.3) * 31 + int(y * 5.1) * 17 + lo["n"] * 13) % 10
            wv = 0.24 + 0.20 * k / 10.0                                  # 0.24-0.44 m posts, varied
            fr.box(x, y, z0, wv, 0.42, z1 - z0, ang)
            if k in (2, 7):                                              # paired posts on some bays
                fr.box(x + math.cos(ang) * 0.75, y + math.sin(ang) * 0.75, z0, 0.22, 0.42, z1 - z0, ang)
        eb.prism(ring, z0 - 0.03, z0 + 0.22)                             # white slab-edge band (photos)
        bal = inset(ring, 0.08)
        n = len(bal)
        for i in range(n):
            (ax_, ay_), (bx_, by_) = bal[i], bal[(i + 1) % n]
            gl.add([(ax_, ay_, z0), (bx_, by_, z0), (bx_, by_, z0 + 1.05), (ax_, ay_, z0 + 1.05)], [[0, 1, 2, 3]])
    for buf, name, mat in ((sb, "SPIRE_storeys", "spire_glass"), (fr, "SPIRE_facade_frames", "band"),
                           (eb, "SPIRE_slab_edge_bands", "band"), (gl, "SPIRE_glass_balustrades", "spire_balustrade")):
        ob = buf.object(name, col, mat)
        if ob:
            objs.append(ob.name)
    return objs


def build():
    st = L.spire_stage()
    col = C.collection("spire")
    levels = L.spire_levels()
    lot = lot_outline()
    plate = ccw(L.tower_outline())
    ground_min = min(L.ground_z(x, y) for x, y in lot)
    deck = st["deck_level"] if st else None
    objs, slabs, joint_lines = [], [], None

    plate_out = ccw(inset(plate, -0.35))     # step 5: staggered slab edges (photos): odd levels stick out

    def outline_for(lv):
        if lv["kind"] in ("ground", "podium"):
            return lot
        return plate_out if (lv["kind"] == "tower" and lv["n"] % 2 == 1) else plate

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
                done = st is None or lv["n"] < st["deck_level"] - st["screen_levels"]
                mat = "spire_soffit" if done else (key if tag != "B" else key + "_b")   # step 7b: balcony soffits warm grey (photos)
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
        obp = pb.object("SPIRE_podium_brick", col, "brick")
        obp.data.materials[0] = C.material_rgb("spire_podium_brick", SPIRE_LOOK["podium_brick"], shader="brick")
        objs.append(obp.name)
        objs += queen_st_podium(col, lot, ground_min, top_podium)
        objs += facade(col, levels, outline_for, plate)
        top = levels[-1]["top_ahd"]
        pp = C.MeshBuf()
        pp.prism(inset(plate, 0.05), top - 0.6, top + 0.12)      # step 7c: slab edge only; the railing is in crown()
        objs.append(pp.object("SPIRE_parapet", col, "band").name)
        objs += crown(col, plate, top)
        lb = C.MeshBuf()
        (ax_, ay_), (bx_, by_) = L.PODIUM["ann_st_corners"]
        (ux_, uy_), (nx_, ny_) = L.ann_st_frame()
        s = L.PODIUM["ann_st_setback_at_ground_m"]
        for t0, t1 in L.PODIUM["lobby_t"]:
            p0 = (ax_ + (bx_ - ax_) * t0 - nx_ * (s + 0.2), ay_ + (by_ - ay_) * t0 - ny_ * (s + 0.2))
            p1 = (ax_ + (bx_ - ax_) * t1 - nx_ * (s + 0.2), ay_ + (by_ - ay_) * t1 - ny_ * (s + 0.2))
            mx, my = (p0[0] + p1[0]) / 2, (p0[1] + p1[1]) / 2
            lb.box(mx, my, L.ground_z(mx, my) - 0.2, math.dist(p0, p1), 0.3, 4.2, math.atan2(uy_, ux_))
        objs.append(lb.object("SPIRE_ann_st_lobby_glass", col, "spire_glass").name)
        # the other PT slabs in John's count: plant decks and basements (labelled; heights assumed)
        for e in L.spire_extra_slabs():
            if e["kind"] == "basement":
                ring = lot
            elif e["name"] == "LMR":
                ring = ccw(inset(L.core_outline(), -1.5))
            else:
                ring = ccw(inset(L.core_outline(), -4.0))            # step 7c: plant box over the core (photos)
            eb = C.MeshBuf()
            eb.prism(ring, e["top_ahd"] - e["slab_m"], e["top_ahd"])
            ob = eb.object("SLAB_%s" % e["name"], col, "slab")
            if e["kind"] == "plant":
                ob.data.materials[0] = C.material_rgb("spire_plant_box", (0.06, 0.065, 0.07))
            ob["kind"] = e["kind"]
            ob["note"] = e["note"]
            if e["kind"] == "plant":
                pb2 = C.MeshBuf()
                pb2.prism(ring, e["top_ahd"] - (3.3 if e["name"] == "PLANT" else 3.3), e["top_ahd"] - e["slab_m"])
                obr = pb2.object("SPIRE_%s_room" % e["name"], col, "roof")
                obr.data.materials[0] = C.material_rgb("spire_plant_box", (0.06, 0.065, 0.07))   # charcoal (photos)
                objs.append(obr.name)
            slabs.append({"name": ob.name, "level": e["name"], "pour_area": "1", "poured": True, "kind": e["kind"]})
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
        objs += facade(col, levels, outline_for, plate, upto_n=deck - st["screen_levels"])

    typ = levels[-1]["typical_ftf_solved_m"]
    return {"module": "spire", "stage": st["name"] if st else "finished", "objects": objs,
            "slabs": slabs, "slab_objects": len(slabs), "levels_total": len(levels),
            "base_ahd": levels[0]["top_ahd"], "roof_ahd": levels[-1]["top_ahd"], "typical_ftf_m": typ,
            "plate_area_m2": round(C.signed_area(plate), 1), "lot_area_m2": round(C.signed_area(lot), 1),
            "joint": {"plan_px_x": L.JOINT["plan_px_x"], "assumption": True,
                      "lines_local": [[[round(v, 2) for v in p] for p in seg] for seg in (joint_lines or [])]},
            "note": "Typical floor to floor %.2f m is solved from the OSM height (low; check a section). "
                    "Joint position and column grid are assumptions." % typ}
