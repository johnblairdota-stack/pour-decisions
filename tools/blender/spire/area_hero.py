"""Spire area, round 1 (thread "Polish the Spire area render"): everything AROUND the Spire site.

Built last (one line in build_all.MODULES). The Spire site is gameplay and hands off: this module adds
nothing within the keep-out zone (the lot + 9.5 m, and the Ann St strip in front of it, same numbers as
clear_kerb.py) and nothing on a carriageway except road surface marks. Its self-check fails the build if a
new piece's centre breaks either rule.

Parts (numbers in layout.AREA):
  car parks   St John's Cathedral car park and the other open-air car parks: asphalt draped on the ground,
              2.6 x 5.4 m bays, white lines, wheel stops, tree islands (trees where the LiDAR has trunks),
              light poles, entry gate and signs, low red-brick retaining wall + grass bank along Ann St
  forecourt   the cathedral's west front: the tree grove goes; bitumen drive loop, rolled kerb, garden beds
              (red cordyline, bromeliads), black tubular rail, noticeboard
  roads       asphalt patches, crack seal, manholes, side-entry pits, concrete gutter strip; a 40 km/h sign,
              a Story Bridge direction blade
  look        light(): sun + Nishita sky per view, half the world fill, warm sun, distance haze on aerials,
              dusk: lit windows and street lamps. restyle(): asphalt, footpaths, leaves, bark, car parks.
"""
import math
import os

import bpy

import layout as L
import common as C
import shapes as S

AREA = getattr(L, "AREA", {})
NEW = []          # (x, y, kind) of every new piece: the self-check reads it


def P(key, default):
    return AREA.get(key, default)


# ---------------------------------------------------------------------------------------------- guards
class Guard:
    """Keep-out zone (Spire site + Ann St strip) and the carriageways."""
    def __init__(self):
        import numpy as np
        import spire
        import trees as T
        self.np = np
        self.lot = S.ccw(spire.osm_lot())
        self.road = T.RoadGuard(pad=0.2)
        self.clear = 9.5
        self.ann_mid = (-16.0, 14.4)
        self.ann_along = (0.760, 0.650)

    def keepout(self, x, y, pad=0.0):
        if S.point_in(x, y, self.lot):
            return True
        d = min(seg_dist(x, y, a, b) for a, b in zip(self.lot, self.lot[1:] + self.lot[:1]))
        if d < self.clear + pad:
            return True
        rx, ry = x - self.ann_mid[0], y - self.ann_mid[1]
        along = rx * self.ann_along[0] + ry * self.ann_along[1]
        out = -rx * self.ann_along[1] + ry * self.ann_along[0]
        return abs(along) < 46.0 + pad and -2.0 - pad < out < 30.0 + pad

    def on_road(self, x, y):
        return self.road.on_road(x, y)

    def ok(self, x, y, road_ok=False, pad=0.0):
        return not self.keepout(x, y, pad) and (road_ok or not self.on_road(x, y))


def seg_dist(x, y, a, b):
    dx, dy = b[0] - a[0], b[1] - a[1]
    l2 = dx * dx + dy * dy or 1e-9
    k = max(0.0, min(1.0, ((x - a[0]) * dx + (y - a[1]) * dy) / l2))
    return math.hypot(a[0] + dx * k - x, a[1] + dy * k - y)


def note(x, y, kind):
    NEW.append((x, y, kind))


def gz(x, y):
    return L.ground_z(x, y)


# ---------------------------------------------------------------------------------------------- helpers
def mat(name, rgb, shader="render", **props):
    m = C.material_rgb("area_" + name, rgb, shader=shader)
    for k, v in props.items():
        m[k] = v
    return m


def put(buf, name, col, m, objs):
    ob = buf.object("area_" + name, col, "roof")
    if ob:
        ob.data.materials[0] = m
        objs.append(ob.name)
    return ob


def drape(buf, ring, lift, cell=1.5, guard=None):
    """Ground-following surface over a polygon: grid cells whose middle is inside."""
    xs = [p[0] for p in ring]
    ys = [p[1] for p in ring]
    x = min(xs)
    n = 0
    while x < max(xs):
        y = min(ys)
        while y < max(ys):
            cx, cy = x + cell / 2, y + cell / 2
            if S.point_in(cx, cy, ring) and (guard is None or not guard.keepout(cx, cy)):
                q = [(x, y), (x + cell, y), (x + cell, y + cell), (x, y + cell)]
                buf.add([(px, py, gz(px, py) + lift) for px, py in q], [[0, 1, 2, 3]])
                n += 1
            y += cell
        x += cell
    return n


def flat_rect(buf, cx, cy, ln, wd, ang, lift):
    """Thin mark lying on the ground (draped at its four corners)."""
    ux, uy = math.cos(ang), math.sin(ang)
    vx, vy = -uy, ux
    pts = [(cx - ux * ln / 2 - vx * wd / 2, cy - uy * ln / 2 - vy * wd / 2),
           (cx + ux * ln / 2 - vx * wd / 2, cy + uy * ln / 2 - vy * wd / 2),
           (cx + ux * ln / 2 + vx * wd / 2, cy + uy * ln / 2 + vy * wd / 2),
           (cx - ux * ln / 2 + vx * wd / 2, cy - uy * ln / 2 + vy * wd / 2)]
    buf.add([(px, py, gz(px, py) + lift) for px, py in pts], [[0, 1, 2, 3]])


def disc(buf, cx, cy, r, lift, k=14):
    pts = [(cx + r * math.cos(2 * math.pi * i / k), cy + r * math.sin(2 * math.pi * i / k)) for i in range(k)]
    buf.add([(px, py, gz(px, py) + lift) for px, py in pts], [list(range(k))])


def pole(buf, x, y, z0, h, r0=0.09, r1=0.06):
    import trees as T
    T.tube(buf, (x, y, z0), (x, y, z0 + h), r0, r1, 10)


def small_tree(trunks, leaves, x, y, h, seed):
    """Car-park / bed tree: round tapering trunk, curved limbs, clumpy crown (tuckeroo / brush box size)."""
    import trees as T
    g = gz(x, y)
    r = max(1.8, 0.33 * h)
    T.tube(trunks, (x, y, g - 0.2), (x, y, g + h * 0.45), 0.16, 0.11, 10)
    for k in range(4):
        a = seed * 1.3 + k * math.pi / 2
        mid = (x + math.cos(a) * r * 0.25, y + math.sin(a) * r * 0.25, g + h * 0.6)
        tip = (x + math.cos(a) * r * 0.55, y + math.sin(a) * r * 0.55, g + h * 0.78)
        T.tube(trunks, (x, y, g + h * 0.42), mid, 0.09, 0.06, 7)
        T.tube(trunks, mid, tip, 0.06, 0.03, 6)
    for k in range(5):                                   # clumps, not one ball
        a = seed + k * 2.39
        d = r * (0.15 if k == 0 else 0.5)
        leaves.cloud((x + math.cos(a) * d, y + math.sin(a) * d, g + h - r * (0.75 if k == 0 else 0.9)),
                     (r * 0.62, r * 0.62, r * 0.5), int(320 + 30 * r * r), 0.16, shell=0.35, top_bias=0.25)


# ---------------------------------------------------------------------------------------------- car parks
CARPARK_MAIN = 1243599981           # St John's Cathedral car park (OSM amenity=parking, the L round the north side)
CARPARK_OTHER = (1243599979, 1243599980, 1210507997, 1210662509)
CATHEDRAL_AXIS = math.atan2(-121.0 + 65.7, -50.4 + 90.8)   # west front -> chancel (OSM outline), bays follow it


def carparks(col, guard, objs, report):
    import numpy as np
    import foliage as FO
    import trees as T
    o = L.osm()
    trunks_pts = [(x, y, h) for x, y, h, g in L.tree_points() if 3 <= h <= 30]
    tp = np.array([(x, y) for x, y, h in trunks_pts] or [(1e9, 1e9)])
    asphalt, lines, stops, kerbs, islands, wall, cap, bank = (C.MeshBuf() for _ in range(8))
    poles_b, heads, lamp_glass, signs_b, sign_face, rail = (C.MeshBuf() for _ in range(6))
    trunks = C.MeshBuf()
    leaves = FO.Foliage(seed=301)
    shrubs = FO.Foliage(seed=302)
    nb = ni = nt = 0
    for wid in (CARPARK_MAIN,) + CARPARK_OTHER:
        w = o["ways"].get(wid)
        if not w:
            continue
        ring = S.ccw(C.clean_ring(o["line"](w)))
        if len(ring) < 3:
            continue
        cx0 = sum(p[0] for p in ring) / len(ring)
        cy0 = sum(p[1] for p in ring) / len(ring)
        if guard.keepout(cx0, cy0):
            report.append("car park %d in the keep-out zone: skipped" % wid)
            continue
        drape(asphalt, ring, 0.06, guard=guard)
        if wid == CARPARK_MAIN:
            ang = CATHEDRAL_AXIS
        else:
            ang = S.min_rect(ring)[4]
        ux, uy = math.cos(ang), math.sin(ang)
        vx, vy = -uy, ux
        us = [p[0] * ux + p[1] * uy for p in ring]
        vs = [p[0] * vx + p[1] * vy for p in ring]
        BW, BD, AISLE = 2.6, 5.4, 6.4
        rows = []                                       # (v of the bay's aisle end, facing +1 / -1)
        v = min(vs) + 0.6
        while v < max(vs):
            rows.append((v + BD, -1))                   # bays from v to v + BD, aisle above
            rows.append((v + BD + AISLE, +1))           # bays from v + BD + AISLE up
            v += 2 * BD + AISLE
        inside = lambda x, y: S.point_in(x, y, ring) and not guard.keepout(x, y, 1.0)
        for va, face in rows:
            vmid = va - face * BD / 2 if face < 0 else va + BD / 2
            u = min(us) + 0.3
            k = 0
            while u + BW < max(us):
                um = u + BW / 2
                cx, cy = ux * um + vx * vmid, uy * um + vy * vmid
                corners = [(ux * (um + a * BW / 2) + vx * (vmid + b * BD / 2), uy * (um + a * BW / 2) + vy * (vmid + b * BD / 2))
                           for a in (-1, 1) for b in (-1, 1)]
                if all(inside(*c) for c in corners + [(cx, cy)]):
                    near = float(np.min(np.hypot(tp[:, 0] - cx, tp[:, 1] - cy)))
                    island = near < 2.2 or k % 9 == 8
                    if island:                                                     # raised island with a tree
                        islands.box(cx, cy, gz(cx, cy) - 0.1, BW - 0.3, BD - 0.4, 0.25, ang)
                        kerbs.box(cx, cy, gz(cx, cy) - 0.1, BW - 0.1, BD - 0.2, 0.18, ang)
                        if near >= 2.2:
                            small_tree(trunks, leaves, cx, cy, 7.0 + (k * 1.7) % 3, k + wid % 7)
                            nt += 1
                        shrubs.tufts((cx, cy, gz(cx, cy) + 0.15), 0.9, 40, 0.6)
                        if k % 18 == 8:                                            # light pole in every 2nd island
                            lx, ly = cx + vx * face * (BD / 2 - 0.6), cy + vy * face * (BD / 2 - 0.6)
                            pole(poles_b, lx, ly, gz(lx, ly), 7.5)
                            hx_, hy_ = lx - vx * face * 0.6, ly - vy * face * 0.6
                            heads.box(hx_, hy_, gz(lx, ly) + 7.3, 0.35, 0.8, 0.14, ang + math.pi / 2)
                            lamp_glass.box(hx_, hy_, gz(lx, ly) + 7.27, 0.3, 0.6, 0.03, ang + math.pi / 2)
                            note(lx, ly, "pole")
                        ni += 1
                        note(cx, cy, "island")
                    else:
                        for a in (-1, 1):                                          # side lines
                            sx_, sy_ = cx + ux * a * BW / 2, cy + uy * a * BW / 2
                            flat_rect(lines, sx_, sy_, BD, 0.1, ang + math.pi / 2, 0.075)
                        bx, by = cx - vx * face * (BD / 2 - 0.05), cy - vy * face * (BD / 2 - 0.05)
                        flat_rect(lines, bx, by, BW, 0.1, ang, 0.075)               # back line
                        wx, wy = cx - vx * face * (BD / 2 - 0.75), cy - vy * face * (BD / 2 - 0.75)
                        stops.box(wx, wy, gz(wx, wy) + 0.04, 1.65, 0.16, 0.1, ang)  # wheel stop
                        nb += 1
                        note(cx, cy, "bay")
                k += 1
                u += BW
        if wid == CARPARK_MAIN:
            # Ann St edge: low red-brick retaining wall with a grass bank (2012 photo), entry with gate posts
            ann = [(-26, 19), (-36, 11), (-55, -6), (-61, -11), (-74, -23), (-87, -34), (-95, -40), (-102, -47)]
            edges = list(zip(ring, ring[1:] + ring[:1]))
            gate_done = False
            for a, b in edges:
                mx, my = (a[0] + b[0]) / 2, (a[1] + b[1]) / 2
                da = min(seg_dist(mx, my, p, q) for p, q in zip(ann[:-1], ann[1:]))
                if da > 22 or math.dist(a, b) < 3:
                    continue
                ln = math.dist(a, b)
                e = math.atan2(b[1] - a[1], b[0] - a[0])
                gate_u = ln / 2 if (not gate_done and ln > 9) else None
                steps = max(1, int(ln / 1.0))
                for i in range(steps):
                    t0, t1 = i / steps, (i + 1) / steps
                    tm = (t0 + t1) / 2 * ln
                    if gate_u is not None and abs(tm - gate_u) < 3.2:
                        continue
                    p0 = (a[0] + (b[0] - a[0]) * t0, a[1] + (b[1] - a[1]) * t0)
                    p1 = (a[0] + (b[0] - a[0]) * t1, a[1] + (b[1] - a[1]) * t1)
                    pmx, pmy = (p0[0] + p1[0]) / 2, (p0[1] + p1[1]) / 2
                    if not guard.ok(pmx, pmy):
                        continue
                    z = min(gz(*p0), gz(*p1))
                    wall.box(pmx, pmy, z - 0.3, ln / steps + 0.01, 0.23, 0.9 + abs(gz(*p0) - gz(*p1)), e)
                    cap.box(pmx, pmy, z + 0.6 + abs(gz(*p0) - gz(*p1)), ln / steps + 0.01, 0.3, 0.06, e)
                    nx_, ny_ = math.sin(e), -math.cos(e)             # outward (ring is ccw: right of the edge)
                    for j in range(2):
                        bxp, byp = pmx + nx_ * (0.6 + 1.0 * j), pmy + ny_ * (0.6 + 1.0 * j)
                        if guard.ok(bxp, byp):
                            bank.add([(bxp + math.cos(e) * ln / steps / 2 - nx_ * 0.5, byp + math.sin(e) * ln / steps / 2 - ny_ * 0.5, gz(bxp, byp) + 0.05),
                                      (bxp + math.cos(e) * ln / steps / 2 + nx_ * 0.5, byp + math.sin(e) * ln / steps / 2 + ny_ * 0.5, gz(bxp, byp) + 0.04),
                                      (bxp - math.cos(e) * ln / steps / 2 + nx_ * 0.5, byp - math.sin(e) * ln / steps / 2 + ny_ * 0.5, gz(bxp, byp) + 0.04),
                                      (bxp - math.cos(e) * ln / steps / 2 - nx_ * 0.5, byp - math.sin(e) * ln / steps / 2 - ny_ * 0.5, gz(bxp, byp) + 0.05)],
                                     [[0, 1, 2, 3]])
                    note(pmx, pmy, "wall")
                if gate_u is not None:
                    gx = a[0] + (b[0] - a[0]) * gate_u / ln
                    gy = a[1] + (b[1] - a[1]) * gate_u / ln
                    if guard.ok(gx, gy):
                        for s in (-1, 1):                                       # gate posts + open swing leaf
                            px_, py_ = gx + math.cos(e) * s * 3.0, gy + math.sin(e) * s * 3.0
                            rail.box(px_, py_, gz(px_, py_), 0.12, 0.12, 1.4, e)
                            lx2 = px_ - math.cos(e) * s * 0.2 - math.sin(e) * 2.6
                            ly2 = py_ - math.sin(e) * s * 0.2 + math.cos(e) * 2.6
                            for zz in (0.25, 1.15):
                                rail.beam((px_, py_, gz(px_, py_) + zz), (lx2, ly2, gz(px_, py_) + zz), 0.05)
                            rail.beam((lx2, ly2, gz(px_, py_) + 0.2), (lx2, ly2, gz(px_, py_) + 1.2), 0.05)
                        sx_, sy_ = gx + math.cos(e) * 4.2 - math.sin(e) * 0.3, gy + math.sin(e) * 4.2 + math.cos(e) * 0.3
                        pole(signs_b, sx_, sy_, gz(sx_, sy_), 2.6, 0.04, 0.04)
                        sign_face.box(sx_, sy_, gz(sx_, sy_) + 1.7, 0.9, 0.04, 0.9, e)
                        C.text_obj(col, "area_carpark_sign_text", "CATHEDRAL\nCAR PARK\nPERMIT\nHOLDERS ONLY",
                                   (sx_ + math.sin(e) * 0.03, sy_ - math.cos(e) * 0.03, gz(sx_, sy_) + 2.15),
                                   (math.pi / 2, 0, e), 0.13, (0.05, 0.12, 0.35))
                        note(gx, gy, "gate")
                        gate_done = True
    objs_before = len(objs)
    put(asphalt, "carpark_asphalt", col, mat("carpark_asphalt", P("carpark_asphalt_rgb", (0.105, 0.102, 0.098)), asphalt=True), objs)
    put(lines, "carpark_lines", col, mat("carpark_lines", (0.80, 0.80, 0.76)), objs)
    put(stops, "carpark_wheel_stops", col, mat("wheel_stops", (0.55, 0.53, 0.50)), objs)
    put(kerbs, "carpark_kerbs", col, mat("carpark_kerb", (0.50, 0.48, 0.45)), objs)
    put(islands, "carpark_island_mulch", col, mat("mulch", (0.13, 0.08, 0.05)), objs)
    put(wall, "carpark_brick_wall", col, mat("carpark_brick", (0.36, 0.13, 0.08), shader="brick"), objs)
    put(cap, "carpark_wall_cap", col, mat("wall_cap", (0.55, 0.52, 0.48)), objs)
    put(bank, "carpark_grass_bank", col, bpy.data.materials.get("clay_grass") or mat("grass", (0.12, 0.2, 0.06)), objs)
    put(poles_b, "carpark_light_poles", col, mat("galv", (0.45, 0.46, 0.46)), objs)
    put(heads, "carpark_light_heads", col, mat("lamp_head", (0.18, 0.19, 0.2)), objs)
    put(lamp_glass, "carpark_lamp_glass", col, mat("lamp_glass", (0.9, 0.85, 0.7), lamp=True), objs)
    put(signs_b, "carpark_sign_posts", col, mat("galv", (0.45, 0.46, 0.46)), objs)
    put(sign_face, "carpark_sign_face", col, mat("sign_white", (0.85, 0.85, 0.82)), objs)
    put(rail, "carpark_gate", col, mat("black_rail", (0.02, 0.02, 0.02)), objs)
    put(trunks, "carpark_tree_trunks", col, mat("bark", P("bark_rgb", (0.105, 0.069, 0.045))), objs)
    ob = leaves.object("area_carpark_leaves", col, (0.045, 0.10, 0.035), (0.12, 0.20, 0.06))
    if ob:
        objs.append(ob.name)
    ob = shrubs.object("area_carpark_shrubs", col, (0.05, 0.12, 0.04), (0.14, 0.22, 0.07))
    if ob:
        objs.append(ob.name)
    report.append("car parks: %d bays, %d islands, %d new trees, %d objects" % (nb, ni, nt, len(objs) - objs_before))
    # streets.py's flat car-park slab + bay lines (one level for the whole sloping lot): hide the faces
    # inside these car parks, the draped surface replaces them
    rings = []
    for wid in (CARPARK_MAIN,) + CARPARK_OTHER:
        w = o["ways"].get(wid)
        if w:
            rings.append(S.ccw(C.clean_ring(o["line"](w))))
    for name in ("car_parks", "car_park_bay_lines"):
        drop_faces(bpy.data.objects.get(name), rings)


def in_rings_np(X, Y, rings):
    """Vectorised point-in-polygon for several rings (any of them)."""
    import numpy as np
    hit = np.zeros(len(X), bool)
    for ring in rings:
        ins = np.zeros(len(X), bool)
        n = len(ring)
        for i in range(n):
            (x1, y1), (x2, y2) = ring[i], ring[(i + 1) % n]
            if y1 == y2:
                continue
            c = ((y1 > Y) != (y2 > Y)) & (X < (x2 - x1) * (Y - y1) / (y2 - y1) + x1)
            ins ^= c
        hit |= ins
    return hit


def drop_faces(ob, rings):
    """Delete the faces of an existing merged object whose centre is inside any of the rings."""
    if ob is None or ob.type != "MESH" or not ob.data.polygons:
        return 0
    import numpy as np
    xs = [p[0] for r in rings for p in r]
    ys = [p[1] for r in rings for p in r]
    bb = [ob.matrix_world @ __import__("mathutils").Vector(c) for c in ob.bound_box]
    if max(v.x for v in bb) < min(xs) or min(v.x for v in bb) > max(xs) or \
            max(v.y for v in bb) < min(ys) or min(v.y for v in bb) > max(ys):
        return 0
    me = ob.data
    cen = np.empty(len(me.polygons) * 3, "f4")
    me.polygons.foreach_get("center", cen)
    cen = cen.reshape(-1, 3)
    dead = np.nonzero(in_rings_np(cen[:, 0], cen[:, 1], rings))[0]
    if not len(dead):
        return 0
    import bmesh
    bm = bmesh.new()
    bm.from_mesh(me)
    bm.faces.ensure_lookup_table()
    bmesh.ops.delete(bm, geom=[bm.faces[int(i)] for i in dead], context="FACES")
    bm.to_mesh(me)
    bm.free()
    me.update()
    return len(dead)


# ---------------------------------------------------------------------------------------------- forecourt
WEST_FRONT = ((-90.8, -65.7), (-110.7, -83.4))     # OSM outline: the west front wall on the Ann St side


def forecourt_zone():
    """Between the Ann St footpath and the west front (2010 photo: open drive and beds, no grove)."""
    (ax, ay), (bx, by) = WEST_FRONT
    e = math.atan2(by - ay, bx - ax)
    ux, uy = math.cos(e), math.sin(e)
    nx, ny = uy, -ux                                   # away from the church, towards Ann St
    ring = []
    for t, d in ((-4.0, 1.0), (math.dist(WEST_FRONT[0], WEST_FRONT[1]) + 4.0, 1.0),
                 (math.dist(WEST_FRONT[0], WEST_FRONT[1]) + 4.0, 11.0), (-4.0, 11.0)):
        ring.append((ax + ux * t + nx * d, ay + uy * t + ny * d))
    return ring, (ux, uy), (nx, ny), e


def forecourt(col, guard, objs, report):
    import foliage as FO
    ring, (ux, uy), (nx, ny), e = forecourt_zone()
    (ax, ay), (bx, by) = WEST_FRONT
    # 1. the grove goes: leaves, crowns and trunks with their middle in the zone
    gone = 0
    for ob in list(bpy.data.objects):
        if ob.type == "MESH" and (ob.name.startswith(("leaves_", "tree_", "blooms_", "palm_"))):
            gone += drop_faces(ob, [ring])
    # 2. drive loop: bitumen U from Ann St to the porch and back, rolled kerb both sides
    drive, kerb, beds, rail, board, post = (C.MeshBuf() for _ in range(6))
    red = FO.Foliage(seed=311)
    green = FO.Foliage(seed=312)
    L_ = math.dist(WEST_FRONT[0], WEST_FRONT[1])
    mid = (ax + ux * L_ / 2, ay + uy * L_ / 2)
    path = []
    for i in range(25):                                # U: in at one end, past the porch, out at the other
        t = i / 24
        a = math.pi * t
        along = -L_ * 0.42 * math.cos(a)
        out = 11.0 - 7.0 * math.sin(a)
        path.append((mid[0] + ux * along + nx * out, mid[1] + uy * along + ny * out))
    for p, q in zip(path[:-1], path[1:]):
        c = ((p[0] + q[0]) / 2, (p[1] + q[1]) / 2)
        if not guard.ok(*c):
            continue
        flat_rect(drive, c[0], c[1], math.dist(p, q) + 0.25, 4.0, math.atan2(q[1] - p[1], q[0] - p[0]), 0.07)
        hd = math.atan2(q[1] - p[1], q[0] - p[0])
        for s in (-1, 1):
            kx, ky = c[0] - math.sin(hd) * s * 2.05, c[1] + math.cos(hd) * s * 2.05
            kerb.box(kx, ky, gz(kx, ky) - 0.05, math.dist(p, q) + 0.2, 0.3, 0.17, hd)
        note(c[0], c[1], "drive")
    # 3. beds inside the loop and beside the porch: red cordyline, bromeliads, low shrubs; black tubular rail
    for k, (along, out, rw, rd) in enumerate(((-L_ * 0.22, 7.0, 5.0, 3.2), (L_ * 0.22, 7.0, 5.0, 3.2),
                                               (-L_ * 0.5 - 2.0, 3.0, 3.0, 4.0), (L_ * 0.5 + 2.0, 3.0, 3.0, 4.0))):
        cx = mid[0] + ux * along + nx * out
        cy = mid[1] + uy * along + ny * out
        if not guard.ok(cx, cy):
            continue
        beds.box(cx, cy, gz(cx, cy) - 0.1, rw, rd, 0.32, e)
        g = gz(cx, cy) + 0.22
        for j in range(9):
            px = cx + ux * ((j % 3) - 1) * rw * 0.3 + nx * ((j // 3) - 1) * rd * 0.28
            py = cy + uy * ((j % 3) - 1) * rw * 0.3 + ny * ((j // 3) - 1) * rd * 0.28
            if j % 2 == 0:
                red.tufts((px, py, g), 0.35, 22, 1.1)                   # cordyline: red strappy clumps
            else:
                green.tufts((px, py, g), 0.45, 18, 0.45)                # bromeliads
        green.cloud((cx, cy, g + 0.3), (rw * 0.45, rd * 0.4, 0.35), 260, 0.14, shell=0.4, top_bias=0.6)
        corners = [(cx + ux * a_ * rw / 2 + nx * b_ * rd / 2, cy + uy * a_ * rw / 2 + ny * b_ * rd / 2)
                   for a_, b_ in ((-1, -1), (1, -1), (1, 1), (-1, 1))]
        for p, q in zip(corners, corners[1:] + corners[:1]):           # tubular rail round the bed
            rail.beam((p[0], p[1], gz(*p) + 0.75), (q[0], q[1], gz(*q) + 0.75), 0.05)
            n = max(1, int(math.dist(p, q) / 1.8))
            for i in range(n + 1):
                x_ = p[0] + (q[0] - p[0]) * i / n
                y_ = p[1] + (q[1] - p[1]) * i / n
                rail.beam((x_, y_, gz(x_, y_)), (x_, y_, gz(x_, y_) + 0.78), 0.05)
        note(cx, cy, "bed")
    # 4. noticeboard by the drive entry
    nbx, nby = mid[0] - ux * (L_ * 0.5 + 3.5) + nx * 11.0, mid[1] - uy * (L_ * 0.5 + 3.5) + ny * 11.0
    if guard.ok(nbx, nby):
        for s in (-1, 1):
            post.box(nbx + ux * s * 0.8, nby + uy * s * 0.8, gz(nbx, nby), 0.12, 0.12, 2.1, e)
        board.box(nbx, nby, gz(nbx, nby) + 0.9, 1.8, 0.1, 1.1, e)
        C.text_obj(col, "area_cathedral_noticeboard_text", "ST JOHN'S\nCATHEDRAL", (nbx + nx * 0.06, nby + ny * 0.06, gz(nbx, nby) + 1.55),
                   (math.pi / 2, 0, e + math.pi), 0.2, (0.85, 0.80, 0.62))
        note(nbx, nby, "sign")
    put(drive, "forecourt_drive", col, mat("forecourt_bitumen", (0.12, 0.115, 0.11), asphalt=True), objs)
    put(kerb, "forecourt_rolled_kerb", col, mat("kerb_concrete", (0.52, 0.50, 0.46)), objs)
    put(beds, "forecourt_beds", col, mat("bed_mulch", (0.11, 0.07, 0.045)), objs)
    put(rail, "forecourt_rail", col, mat("black_rail", (0.02, 0.02, 0.02)), objs)
    put(post, "forecourt_board_posts", col, mat("board_post", (0.06, 0.05, 0.045)), objs)
    put(board, "forecourt_board", col, mat("board_face", (0.16, 0.05, 0.05)), objs)
    ob = red.object("area_cordyline", col, (0.30, 0.03, 0.03), (0.55, 0.08, 0.06))
    if ob:
        objs.append(ob.name)
    ob = green.object("area_bed_plants", col, (0.05, 0.12, 0.04), (0.15, 0.25, 0.08))
    if ob:
        objs.append(ob.name)
    report.append("forecourt: %d tree faces removed, drive + %d beds" % (gone, 4))


# ---------------------------------------------------------------------------------------------- roads
def roads(col, guard, objs, report):
    """Wear on the carriageways: asphalt patches, crack seal, manholes, side-entry pits by the kerb;
    concrete gutter strip. Everything lies on the road surface (marks, not props)."""
    import random
    import streetscape as SS
    rnd = random.Random(7)
    patch, crack, manhole, pit, gutter = (C.MeshBuf() for _ in range(5))
    np_ = nm = 0
    o = L.osm()
    for w in o["ways"].values():
        t = w.get("tags", {})
        if t.get("highway") not in SS.CAR or t.get("bridge", "no") != "no" or t.get("tunnel", "no") != "no":
            continue
        pts = o["line"](w)
        if len(pts) < 2 or not any(math.hypot(x, y) < 330 for x, y in pts):
            continue
        hw = SS.road_width(t) / 2
        acc = rnd.uniform(0, 30)
        for (ax, ay), (bx, by) in zip(pts[:-1], pts[1:]):
            ln = math.dist((ax, ay), (bx, by))
            if ln < 1:
                continue
            e = math.atan2(by - ay, bx - ax)
            ux, uy = (bx - ax) / ln, (by - ay) / ln
            nx, ny = -uy, ux
            s = acc
            while s < ln:
                x, y = ax + ux * s, ay + uy * s
                if math.hypot(x, y) < 330 and not guard.keepout(x, y, 2.0):
                    r = rnd.random()
                    off = rnd.uniform(-hw * 0.8, hw * 0.8)
                    px, py = x + nx * off, y + ny * off
                    if r < 0.35:                                         # patch (darker, newer asphalt)
                        flat_rect(patch, px, py, rnd.uniform(1.5, 6.0), rnd.uniform(1.0, 2.6), e + rnd.uniform(-0.05, 0.05), 0.093)
                        np_ += 1
                    elif r < 0.6:                                        # crack seal: thin wandering strip
                        q = (px, py)
                        a = e + rnd.uniform(-0.6, 0.6)
                        for _ in range(rnd.randint(4, 9)):
                            q2 = (q[0] + math.cos(a) * 0.9, q[1] + math.sin(a) * 0.9)
                            flat_rect(crack, (q[0] + q2[0]) / 2, (q[1] + q2[1]) / 2, 0.95, 0.03, a, 0.095)
                            q = q2
                            a += rnd.uniform(-0.5, 0.5)
                    else:                                                 # manhole
                        disc(manhole, px, py, 0.33, 0.094)
                        nm += 1
                    note(px, py, "roadmark")
                    for sd in (-1, 1):                                    # side-entry pit at each kerb
                        kx, ky = x + nx * sd * (hw - 0.25), y + ny * sd * (hw - 0.25)
                        if rnd.random() < 0.5 and not guard.keepout(kx, ky, 2.0):
                            flat_rect(pit, kx, ky, 1.2, 0.35, e, 0.095)
                            note(kx, ky, "roadmark")
                s += rnd.uniform(18, 40)
            acc = s - ln
            # concrete gutter strip (0.35 m) along both kerbs
            for sd in (-1, 1):
                for i in range(int(ln // 4) + 1):
                    s0 = i * 4
                    s1 = min(ln, s0 + 4)
                    if s1 - s0 < 0.5:
                        continue
                    mx, my = ax + ux * (s0 + s1) / 2 + nx * sd * (hw - 0.18), ay + uy * (s0 + s1) / 2 + ny * sd * (hw - 0.18)
                    if math.hypot(mx, my) < 330 and not guard.keepout(mx, my, 1.0):
                        flat_rect(gutter, mx, my, s1 - s0, 0.36, e, 0.088)
    put(patch, "road_patches", col, mat("road_patch", (0.075, 0.074, 0.073), asphalt=True), objs)
    put(crack, "road_crack_seal", col, mat("crack_seal", (0.025, 0.025, 0.026)), objs)
    put(manhole, "road_manholes", col, mat("manhole", (0.06, 0.055, 0.05), metal=True), objs)
    put(pit, "road_side_pits", col, mat("pit_grate", (0.03, 0.03, 0.03)), objs)
    put(gutter, "road_gutter_strip", col, mat("gutter_concrete", (0.36, 0.35, 0.33)), objs)
    report.append("roads: %d patches, %d manholes" % (np_, nm))


# ---------------------------------------------------------------------------------------------- signs
def signs(col, guard, objs, report):
    """Missing signs from the photos: 40 km/h on Ann St (cathedral side), green Story Bridge direction blade
    on Ann St north-east of Queen St."""
    posts, white, green, red = (C.MeshBuf() for _ in range(4))
    items = P("signs", [
        {"kind": "speed40", "xy": (-114.0, -46.0), "facing_deg": 220.0},
        {"kind": "speed40", "xy": (86.0, 120.0), "facing_deg": 40.0},
        {"kind": "story_bridge", "xy": (90.0, 118.0), "facing_deg": 40.0},
    ])
    n = 0
    for it in items:
        x, y = it["xy"]
        if not guard.ok(x, y):
            report.append("sign at (%.0f, %.0f) off: keep-out or road" % (x, y))
            continue
        e = math.radians(90.0 - it["facing_deg"])           # the face looks along facing_deg (deg from north)
        z = gz(x, y) + L.KERB_HEIGHT
        pole(posts, x, y, z, 3.0, 0.04, 0.04)
        if it["kind"] == "speed40":
            import trees as T
            k = 20
            ring = [(x + 0.3 * math.cos(2 * math.pi * i / k) * math.cos(e + math.pi / 2), y + 0.3 * math.cos(2 * math.pi * i / k) * math.sin(e + math.pi / 2),
                     z + 2.55 + 0.3 * math.sin(2 * math.pi * i / k)) for i in range(k)]
            red.add([(px + math.cos(e) * 0.05, py + math.sin(e) * 0.05, pz) for px, py, pz in ring], [list(range(k))[::-1]])
            inner = [(x + 0.24 * math.cos(2 * math.pi * i / k) * math.cos(e + math.pi / 2), y + 0.24 * math.cos(2 * math.pi * i / k) * math.sin(e + math.pi / 2),
                      z + 2.55 + 0.24 * math.sin(2 * math.pi * i / k)) for i in range(k)]
            white.add([(px + math.cos(e) * 0.06, py + math.sin(e) * 0.06, pz) for px, py, pz in inner], [list(range(k))[::-1]])
            C.text_obj(col, "area_sign40", "40", (x + math.cos(e) * 0.07, y + math.sin(e) * 0.07, z + 2.55),
                       (math.pi / 2, 0, e + math.pi / 2), 0.26, (0.02, 0.02, 0.02))
        else:
            green.box(x, y, z + 2.4, 1.9, 0.05, 0.45, e + math.pi / 2)
            C.text_obj(col, "area_sign_story_bridge", "STORY BRIDGE  ->", (x + math.cos(e) * 0.04, y + math.sin(e) * 0.04, z + 2.62),
                       (math.pi / 2, 0, e + math.pi / 2), 0.2, (0.95, 0.95, 0.95))
        note(x, y, "sign")
        n += 1
    put(posts, "sign_posts", col, mat("galv", (0.45, 0.46, 0.46)), objs)
    put(white, "sign_white_faces", col, mat("sign_white", (0.85, 0.85, 0.82)), objs)
    put(red, "sign_red_rings", col, mat("sign_red", (0.55, 0.03, 0.03)), objs)
    put(green, "sign_green_blades", col, mat("sign_green", (0.01, 0.17, 0.07)), objs)
    report.append("signs: %d" % n)


# ---------------------------------------------------------------------------------------------- neighbours
def hx(s):
    s = s.lstrip("#")
    return tuple((int(s[i:i + 2], 16) / 255) ** 1.6 for i in (0, 2, 4))     # hex -> between the repo look (raw) and linear


NEIGHBOUR_WALLS = {        # critic round 0 (photos): own albedo per building, sRGB
    568836537: "E3D8BC",   # Mantra on Queen: cream
    26253094: "D8C8A4",    # Marriott: buff
    236155564: "8C969E",   # Skyline (Meriton): dark glass tower, grey frame
    236155562: "8C969E",
    26253098: "EEEBE2",    # Willahra: white
    26386571: "E6DCC6", 26386543: "E6DCC6",   # Admiralty I / II: white with tan spandrels
    224320345: "D9AE88",   # Macrossan: Petrie Bight peach
}
CATHEDRAL_LOOK = {"ashlar": ["C9A777", "8A7A86", "B9976E", "A08E8C", "D2B488"], "dressing": "DCCDA6",
                  "tile": "A8452C", "spire": "2A2624", "slate": "6A6866"}
HALL_OSM = 1210526673      # brick block in the forecourt view: LiDAR top includes trees; photo shows a low gabled hall


def neighbours(col, guard, objs, report):
    """Per-building wall colours, roofs that are not glaring white, the low brick hall, cathedral colours.
    Material colours only (setup_morning builds the shaders from them afterwards)."""
    n = 0
    for osm, h in NEIGHBOUR_WALLS.items():
        m = bpy.data.materials.get("look_%d_wall" % osm)
        if m:
            m.diffuse_color = (*hx(h), 1)
            n += 1
    for m in bpy.data.materials:
        if m.name.endswith("_roof") and (m.name.startswith("look_") or m.name.startswith("gen_")):
            r, g, b, _ = m.diffuse_color
            lum = 0.2126 * r + 0.7152 * g + 0.0722 * b
            if lum > 0.45:                                                 # flat roofs: weathered membrane grey
                k = 0.42 / lum
                m.diffuse_color = (r * k, g * k, b * k * 0.98, 1)
    # cathedral palette
    cm = bpy.data.materials.get("cathedral_tuff_ashlar")
    if cm:
        pal = [hx(c) for c in CATHEDRAL_LOOK["ashlar"]]
        cm["palette"] = [c for col_ in pal for c in col_]
        cm.diffuse_color = (*pal[0], 1)
    for name, key in (("cathedral_sandstone", "dressing"), ("cathedral_terracotta", "tile"),
                      ("cathedral_spire_slate", "spire"), ("cathedral_slate", "slate")):
        m = bpy.data.materials.get(name)
        if m:
            m.diffuse_color = (*hx(CATHEDRAL_LOOK[key]), 1)
    # the low brick hall: drop the tall block's faces, build walls + a steep gable roof on its footprint
    o = L.osm()
    w = o["ways"].get(HALL_OSM)
    if w:
        ring = S.ccw(C.clean_ring(o["line"](w)))
        grown = [(x + (x - sum(p[0] for p in ring) / len(ring)) * 0.3, y + (y - sum(p[1] for p in ring) / len(ring)) * 0.3) for x, y in ring]
        gone = sum(drop_faces(ob, [grown]) for ob in list(bpy.data.objects) if ob.name.startswith("bldg_"))
        cx, cy, ln, wd, ang = S.min_rect(ring)
        g = min(gz(x, y) for x, y in ring)
        walls, roof = C.MeshBuf(), C.MeshBuf()
        walls.box(cx, cy, g - 0.5, ln, wd, 5.0, ang)
        ux, uy, vx, vy = math.cos(ang), math.sin(ang), -math.sin(ang), math.cos(ang)
        eave, ridge = g + 4.5, g + 4.5 + math.tan(math.radians(50)) * (wd / 2 + 0.4)
        c4 = [(cx + ux * a * (ln / 2 + 0.4) + vx * b * (wd / 2 + 0.4), cy + uy * a * (ln / 2 + 0.4) + vy * b * (wd / 2 + 0.4))
              for a, b in ((-1, -1), (1, -1), (1, 1), (-1, 1))]
        r0 = (cx - ux * (ln / 2 + 0.4), cy - uy * (ln / 2 + 0.4))
        r1 = (cx + ux * (ln / 2 + 0.4), cy + uy * (ln / 2 + 0.4))
        roof.add([(*c4[0], eave), (*c4[1], eave), (*r1, ridge), (*r0, ridge)], [[0, 1, 2, 3]])
        roof.add([(*c4[2], eave), (*c4[3], eave), (*r0, ridge), (*r1, ridge)], [[0, 1, 2, 3]])
        e0 = [(cx - ux * ln / 2 + vx * b * wd / 2, cy - uy * ln / 2 + vy * b * wd / 2) for b in (-1, 1)]
        e1 = [(cx + ux * ln / 2 + vx * b * wd / 2, cy + uy * ln / 2 + vy * b * wd / 2) for b in (-1, 1)]
        for ee in (e0, e1):                                               # brick gable ends
            mid = ((ee[0][0] + ee[1][0]) / 2, (ee[0][1] + ee[1][1]) / 2)
            walls.add([(*ee[0], g + 4.5), (*ee[1], g + 4.5), (*mid, ridge - 0.3)], [[0, 1, 2], [2, 1, 0]])
        put(walls, "hall_walls", col, mat("hall_brick", hx("8E4A36"), shader="brick", win_bay=3.2, win_win=1.0,
                                           win_sill=0.25, win_head=0.7, win_glass=list(hx("2A2E33")), win_rough=0.2,
                                           win_floor=4.5), objs)
        put(roof, "hall_roof", col, mat("hall_roof", hx("5E6266")), objs)
        note(cx, cy, "building")
        report.append("brick hall %d rebuilt low and gabled (%d tall faces dropped)" % (HALL_OSM, gone))
    report.append("neighbours: %d wall colours, roofs toned, cathedral palette" % n)


# ---------------------------------------------------------------------------------------------- self-check
def self_check(guard, report):
    bad_zone = [(round(x, 1), round(y, 1), k) for x, y, k in NEW if guard.keepout(x, y)]
    bad_road = [(round(x, 1), round(y, 1), k) for x, y, k in NEW if k not in ("roadmark",) and guard.on_road(x, y)]
    if bad_zone or bad_road:
        raise RuntimeError("area_hero self-check failed: in the Spire keep-out zone %s; on a carriageway %s"
                           % (bad_zone[:10], bad_road[:10]))
    report.append("self-check: %d new pieces, none in the keep-out zone, none on a carriageway" % len(NEW))


def build():
    NEW.clear()
    _STATE.clear()
    if L.ACTIVE_STAGE is not None and L.ACTIVE_STAGE is L.STAGES.get("game_l6"):
        return {"module": "area_hero", "objects": [], "note": "render-only: skipped for the game export"}
    col = C.collection("area_hero")
    guard = Guard()
    objs, report = [], []
    neighbours(col, guard, objs, report)
    nb = 0
    for ob in bpy.data.objects:                       # "BUS C": half the words sank under the crowned red lane
        if ob.name.startswith("busonly") and not guard.keepout(ob.location.x, ob.location.y):
            ob.location.z += 0.05
            ob.rotation_euler.y = 0.0
            nb += 1
    report.append("BUS ONLY words lifted: %d" % nb)
    carparks(col, guard, objs, report)
    forecourt(col, guard, objs, report)
    roads(col, guard, objs, report)
    signs(col, guard, objs, report)
    self_check(guard, report)
    for r in report:
        print("  area_hero:", r)
    return {"module": "area_hero", "objects": objs, "report": report}


# ---------------------------------------------------------------------------------------------- look
_STATE = {}


def restyle():
    """Once per scene, after preview.setup_morning: the area's material fixes (critic round 0)."""
    if _STATE.get("styled"):
        return
    _STATE["styled"] = True
    dusk_nodes = []
    for m in bpy.data.materials:
        if not m.use_nodes or m.node_tree is None:
            continue
        nt = m.node_tree
        bsdf = nt.nodes.get("Principled BSDF")
        if bsdf is None:
            continue
        if m.get("asphalt") or m.name in ("clay_road",):
            asphalt(m, bsdf)
        if m.name in ("clay_footpath", "clay_footway"):
            br = next((n for n in nt.nodes if n.bl_idname == "ShaderNodeTexBrick"), None)
            if br is not None:                                           # warm grey concrete, not cold pavers
                c0 = P("footpath_rgb", (0.40, 0.375, 0.34))
                br.inputs["Color1"].default_value = (*c0, 1)
                br.inputs["Color2"].default_value = (c0[0] * 0.93, c0[1] * 0.93, c0[2] * 0.92, 1)
        if m.get("shader") == "leaf":                                    # smaller leaves: more cells per card
            for n in nt.nodes:
                if n.bl_idname == "ShaderNodeTexVoronoi":
                    n.inputs["Scale"].default_value = P("leaf_cells", 7.0)
        if m.name in ("tree_trunks", "area_bark") or m.name.startswith("tree_trunks"):
            if m.name != "tree_trunks_eucalypt":
                bsdf.inputs["Base Color"].default_value = (*P("bark_rgb", (0.105, 0.069, 0.045)), 1)
        if m.get("lamp"):
            bsdf.inputs["Emission Color"].default_value = (1.0, 0.78, 0.5, 1)
            v = nt.nodes.new("ShaderNodeValue")
            v.name = "AREA_DUSK"
            v.outputs[0].default_value = 0.0
            mul = nt.nodes.new("ShaderNodeMath")
            mul.operation = "MULTIPLY"
            mul.inputs[1].default_value = 40.0
            nt.links.new(v.outputs[0], mul.inputs[0])
            nt.links.new(mul.outputs[0], bsdf.inputs["Emission Strength"])
            dusk_nodes.append(v)
        if m.get("win_bay") or m.name.startswith("bldg_") or "_wall" in m.name:
            v = lit_windows(m, nt, bsdf)
            if v is not None:
                dusk_nodes.append(v)
    for name in ("street_heads", "street_lanterns"):                     # street lamps at dusk
        ob = bpy.data.objects.get(name)
        if ob and name == "street_heads" and ob.data.materials:
            m = ob.data.materials[0]
            if m.use_nodes and not m.node_tree.nodes.get("AREA_DUSK"):
                b = m.node_tree.nodes.get("Principled BSDF")
                if b:
                    b.inputs["Emission Color"].default_value = (1.0, 0.75, 0.45, 1)
                    v = m.node_tree.nodes.new("ShaderNodeValue")
                    v.name = "AREA_DUSK"
                    mul = m.node_tree.nodes.new("ShaderNodeMath")
                    mul.operation = "MULTIPLY"
                    mul.inputs[1].default_value = 25.0
                    m.node_tree.links.new(v.outputs[0], mul.inputs[0])
                    m.node_tree.links.new(mul.outputs[0], b.inputs["Emission Strength"])
                    dusk_nodes.append(v)
    _STATE["dusk"] = dusk_nodes


def asphalt(m, bsdf):
    """Mid-grey worn asphalt (critic: too dark and blue): recolour the ramp / base, keep the speckle."""
    nt = m.node_tree
    lo, hi = P("asphalt_lo", (0.060, 0.059, 0.057)), P("asphalt_hi", (0.150, 0.146, 0.140))
    ramp = next((n for n in nt.nodes if n.bl_idname == "ShaderNodeValToRGB"), None)
    if ramp is not None:
        ramp.color_ramp.elements[0].color = (*lo, 1)
        ramp.color_ramp.elements[1].color = (*hi, 1)
        return
    geo = nt.nodes.new("ShaderNodeNewGeometry")
    nz = nt.nodes.new("ShaderNodeTexNoise")
    nz.inputs["Scale"].default_value = 0.35
    nt.links.new(geo.outputs["Position"], nz.inputs["Vector"])
    sp = nt.nodes.new("ShaderNodeTexNoise")
    sp.inputs["Scale"].default_value = 45.0
    nt.links.new(geo.outputs["Position"], sp.inputs["Vector"])
    add = nt.nodes.new("ShaderNodeMath")
    add.operation = "MULTIPLY_ADD"
    nt.links.new(sp.outputs["Fac"], add.inputs[0])
    add.inputs[1].default_value = 0.5
    nt.links.new(nz.outputs["Fac"], add.inputs[2])
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    base = tuple(m.diffuse_color)[:3]
    ramp.color_ramp.elements[0].color = (base[0] * 0.75, base[1] * 0.75, base[2] * 0.75, 1)
    ramp.color_ramp.elements[1].color = (min(1, base[0] * 1.35), min(1, base[1] * 1.35), min(1, base[2] * 1.35), 1)
    nt.links.new(add.outputs[0], ramp.inputs["Fac"])
    nt.links.new(ramp.outputs["Color"], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = 0.92


def lit_windows(m, nt, bsdf):
    """Dusk: about half the windows lit warm. The window mask is the Mix whose Factor feeds from the grid."""
    mix = None
    for n in nt.nodes:
        if n.bl_idname == "ShaderNodeMix" and n.data_type == "RGBA" and n.inputs["Factor"].is_linked \
                and not n.inputs[7].is_linked and n.inputs[6].is_linked:
            src = n.inputs["Factor"].links[0].from_node
            if src.bl_idname == "ShaderNodeMath" and src.operation == "MULTIPLY":
                mix = n
                break
    if mix is None:
        return None
    mask = mix.inputs["Factor"].links[0].from_socket
    uv = next((n for n in nt.nodes if n.bl_idname == "ShaderNodeUVMap"), None)
    if uv is None:
        return None
    bay = float(m.get("win_bay", 3.0))
    flo = float(m.get("win_floor", L.LEVEL_HEIGHT))
    sep = nt.nodes.new("ShaderNodeSeparateXYZ")
    nt.links.new(uv.outputs["UV"], sep.inputs[0])

    def op(o_, a, b):
        n = nt.nodes.new("ShaderNodeMath")
        n.operation = o_
        for k, v in enumerate((a, b)):
            if v is None:
                continue
            if isinstance(v, (int, float)):
                n.inputs[k].default_value = v
            else:
                nt.links.new(v, n.inputs[k])
        return n.outputs[0]
    cu = op("FLOOR", op("DIVIDE", sep.outputs["X"], bay), None)
    cv = op("FLOOR", op("DIVIDE", sep.outputs["Y"], flo), None)
    comb = nt.nodes.new("ShaderNodeCombineXYZ")
    nt.links.new(cu, comb.inputs[0])
    nt.links.new(cv, comb.inputs[1])
    wn = nt.nodes.new("ShaderNodeTexWhiteNoise")
    wn.noise_dimensions = "2D"
    nt.links.new(comb.outputs[0], wn.inputs["Vector"])
    on = op("GREATER_THAN", wn.outputs["Value"], 0.8)
    v = nt.nodes.new("ShaderNodeValue")
    v.name = "AREA_DUSK"
    v.outputs[0].default_value = 0.0
    strength = op("MULTIPLY", op("MULTIPLY", op("MULTIPLY", mask, on), v.outputs[0]), 0.45)
    bsdf.inputs["Emission Color"].default_value = (1.0, 0.72, 0.42, 1)
    nt.links.new(strength, bsdf.inputs["Emission Strength"])
    return v


def mist(on, start=250.0, depth=2600.0, strength=0.42, rgb=(0.62, 0.68, 0.76)):
    """Distance haze for aerial views (compositor mist pass, as in tools/hsw/render_hsw.horizon)."""
    sc = bpy.context.scene
    sc.view_layers[0].use_pass_mist = True
    ms = sc.world.mist_settings
    ms.start, ms.depth, ms.falloff = start, depth, "LINEAR"
    sc.use_nodes = True
    nt = sc.node_tree
    if not nt.nodes.get("AREA_MIX"):
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
        mul2.name = "AREA_MIST_K"
        nt.links.new(mul.outputs[0], mul2.inputs[0])
        mix = nt.nodes.new("CompositorNodeMixRGB")
        mix.name = "AREA_MIX"
        nt.links.new(mul2.outputs[0], mix.inputs[0])
        nt.links.new(rl.outputs["Image"], mix.inputs[1])
        nt.links.new(mix.outputs[0], comp.inputs["Image"])
    nt.nodes["AREA_MIST_K"].inputs[1].default_value = strength if on else 0.0
    nt.nodes["AREA_MIX"].inputs[2].default_value = (*rgb, 1)


def light(az, el, dusk, kind):
    """Per view, after preview.apply_light: warm sun with a 0.5 deg disc, half the sky fill, AgX MHC,
    haze for aerials, dusk lamps and windows."""
    restyle()
    sc = bpy.context.scene
    sun = bpy.data.objects.get("SUN_morning")
    w = sc.world
    bg = w.node_tree.nodes.get("Background")
    if not dusk:
        if sun:
            sun.data.color = P("sun_rgb", (1.0, 0.945, 0.863))
            sun.data.angle = math.radians(0.5)
            sun.data.energy = sun.data.energy * P("sun_gain", 1.15)
        if bg:
            bg.inputs["Strength"].default_value *= P("sky_fill_gain", 0.5)
        sc.view_settings.exposure += P("exposure_add_day", 0.1)
    else:
        if bg:
            bg.inputs["Strength"].default_value *= 0.8
    try:
        sc.view_settings.look = "AgX - Medium High Contrast"
    except TypeError:
        pass
    for v in _STATE.get("dusk", []):
        v.outputs[0].default_value = 1.0 if dusk else 0.0
    mist(kind == "aerial", strength=0.3 if dusk else 0.42, rgb=(0.36, 0.33, 0.40) if dusk else (0.66, 0.71, 0.78))
