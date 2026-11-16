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
import json
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


def drape_poly(name, ring, lift, col, cell=2.0):
    """r2: ground-following surface with the polygon's exact edge (no saw-tooth): one n-gon cut on a 2 m grid
    with bisect, then every vertex dropped onto the ground."""
    import bmesh
    from mathutils import Vector
    bm = bmesh.new()
    vs = [bm.verts.new((x, y, 0.0)) for x, y in ring]
    bm.faces.new(vs)
    xs = [p[0] for p in ring]
    ys = [p[1] for p in ring]
    for axis, lo, hi in ((0, min(xs), max(xs)), (1, min(ys), max(ys))):
        k = math.floor(lo / cell) * cell + cell
        while k < hi:
            co = Vector((k, 0, 0)) if axis == 0 else Vector((0, k, 0))
            no = Vector((1, 0, 0)) if axis == 0 else Vector((0, 1, 0))
            geom = bm.verts[:] + bm.edges[:] + bm.faces[:]
            bmesh.ops.bisect_plane(bm, geom=geom, plane_co=co, plane_no=no)
            k += cell
    bmesh.ops.triangulate(bm, faces=bm.faces[:])
    for v in bm.verts:
        v.co.z = gz(v.co.x, v.co.y) + lift
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    for p in me.polygons:
        if p.normal.z < 0:
            p.flip()
    ob = bpy.data.objects.new(name, me)
    col.objects.link(ob)
    return ob


def wheel_stop(buf, x, y, ang):
    """Precast concrete wheel stop: 1.8 m bar, trapezoid section 0.24 -> 0.12 m, 0.12 m high."""
    c, s = math.cos(ang), math.sin(ang)
    def rect(l, w):
        return [(x + dx * c - dy * s, y + dx * s + dy * c) for dx, dy in ((-l / 2, -w / 2), (l / 2, -w / 2), (l / 2, w / 2), (-l / 2, w / 2))]
    z = gz(x, y) + 0.05
    buf.loft(rect(1.8, 0.24), z, rect(1.74, 0.12), z + 0.12)


def kerb_ring(buf, ring, guard, gap=None):
    """Concrete kerb (0.15 x 0.15) along a polygon edge, following the ground."""
    for a, b in zip(ring, ring[1:] + ring[:1]):
        ln = math.dist(a, b)
        n = max(1, int(ln / 1.0))
        e = math.atan2(b[1] - a[1], b[0] - a[0])
        for i in range(n):
            t = (i + 0.5) / n
            x, y = a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t
            if gap and math.dist((x, y), gap[0]) < gap[1]:
                continue
            if guard.ok(x, y):
                buf.box(x, y, gz(x, y) - 0.05, ln / n + 0.02, 0.16, 0.22, e)


def crown_z(crown, x, y):
    """Road surface height with the 2.5 % crown streets.py / streetscape.py use."""
    ax, ay, nx, ny, hw = crown
    v = abs((x - ax) * nx + (y - ay) * ny)
    return gz(x, y) + 0.046 + 0.025 * max(0.0, hw - v) + 0.008


def road_rect(buf, cx, cy, ln, wd, ang, crown, lift, nu=1, nv=1):
    """r2: a mark lying on the crowned road (grid nu x nv so it follows the camber), UV 0..1 for soft edges."""
    ux, uy = math.cos(ang), math.sin(ang)
    vx, vy = -uy, ux
    verts, uvs = [], []
    for j in range(nv + 1):
        for i in range(nu + 1):
            a, b = i / nu - 0.5, j / nv - 0.5
            x, y = cx + ux * a * ln + vx * b * wd, cy + uy * a * ln + vy * b * wd
            verts.append((x, y, crown_z(crown, x, y) + lift))
            uvs.append((i / nu, j / nv))
    faces = [[j * (nu + 1) + i, j * (nu + 1) + i + 1, (j + 1) * (nu + 1) + i + 1, (j + 1) * (nu + 1) + i]
             for j in range(nv) for i in range(nu)]
    buf.add(verts, faces, [[uvs[k] for k in f] for f in faces])


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
        mid = (x + math.cos(a) * r * 0.18, y + math.sin(a) * r * 0.18, g + h * 0.62)     # r2: limbs end
        tip = (x + math.cos(a) * r * 0.32, y + math.sin(a) * r * 0.32, g + h * 0.74)     # inside the crown
        T.tube(trunks, (x, y, g + h * 0.42), mid, 0.09, 0.06, 7)
        T.tube(trunks, mid, tip, 0.06, 0.03, 6)
    for k in range(5):                                   # clumps, not one ball
        a = seed + k * 2.39
        d = r * (0.15 if k == 0 else 0.5)
        leaves.cloud((x + math.cos(a) * d, y + math.sin(a) * d, g + h - r * (0.75 if k == 0 else 0.9)),
                     (r * 0.66, r * 0.66, r * 0.55), int(420 + 40 * r * r), 0.16, shell=0.25, top_bias=0.2)


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
        ob_ = drape_poly("area_carpark_asphalt_%d" % wid, ring, 0.06, col)    # r2: exact edge, street asphalt
        ob_.data.materials.append(bpy.data.materials.get("clay_road") or mat("carpark_asphalt", (0.1, 0.1, 0.1)))
        objs.append(ob_.name)
        note(cx0, cy0, "carpark")
        gate_pt = None
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
                            flat_rect(lines, sx_, sy_, BD, 0.1, ang + math.pi / 2, 0.09)
                        bx, by = cx - vx * face * (BD / 2 - 0.05), cy - vy * face * (BD / 2 - 0.05)
                        flat_rect(lines, bx, by, BW, 0.1, ang, 0.09)                # back line
                        wx, wy = cx - vx * face * (BD / 2 - 0.75), cy - vy * face * (BD / 2 - 0.75)
                        wheel_stop(stops, wx, wy, ang)                              # r2: concrete bar
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
                        gate_pt = (gx, gy)
        kerb_ring(kerbs, ring, guard, gap=(gate_pt, 3.6) if gate_pt else None)   # r2: kerb, no lawn saw-tooth
    objs_before = len(objs)
    put(lines, "carpark_lines", col, mat("carpark_lines", (0.80, 0.80, 0.76)), objs)
    put(stops, "carpark_wheel_stops", col, mat("wheel_stops", (0.40, 0.39, 0.37)), objs)
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


TREE_PREFIX = ("leaves_", "tree_", "blooms_", "palm_")


def clear_trees(rings, guard):
    """Remove whole trees whose trunk is inside the rings: every tree face within the crown radius of such a
    trunk, plus any tree face whose centre is inside the rings (canopy-fill trees, grown 2 m for trunks)."""
    import numpy as np
    cyl = [(x, y, 0.5 * h + 1.0) for x, y, h, g in L.tree_points()
           if any(S.point_in(x, y, r) for r in rings)]
    grown = []
    for r in rings:
        cx = sum(p[0] for p in r) / len(r)
        cy = sum(p[1] for p in r) / len(r)
        grown.append([(x + (x - cx) / max(1e-6, math.hypot(x - cx, y - cy)) * 2.0,
                       y + (y - cy) / max(1e-6, math.hypot(x - cx, y - cy)) * 2.0) for x, y in r])

    def test(X, Y, Z, rr):
        hit = in_rings_np(X, Y, rr)
        for cx, cy, rad in cyl:
            hit |= (X - cx) ** 2 + (Y - cy) ** 2 < rad * rad
        return hit
    gone = 0
    for ob in list(bpy.data.objects):
        if ob.type == "MESH" and ob.name.startswith(TREE_PREFIX):
            rr = grown if ("trunk" in ob.name or "palm" in ob.name) else rings
            gone += drop_where(ob, lambda X, Y, Z, rr=rr: test(X, Y, Z, rr))
    return gone


def drop_where(ob, test):
    """Delete faces whose centre (X, Y, Z arrays) passes test(X, Y, Z) -> bool array."""
    if ob is None or ob.type != "MESH" or not ob.data.polygons:
        return 0
    import numpy as np
    me = ob.data
    cen = np.empty(len(me.polygons) * 3, "f4")
    me.polygons.foreach_get("center", cen)
    cen = cen.reshape(-1, 3)
    dead = np.nonzero(test(cen[:, 0], cen[:, 1], cen[:, 2]))[0]
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
    # r2: whole trees go (round 1 cut by area and left stumps and bare forks); also the trees in the
    # cathedral_west_front_2010 photo's view, where the photo shows the open drive
    cam = (-156.2, -63.5)
    hd = math.radians(115.5)
    wedge = [(cam[0] + d * math.sin(hd + a), cam[1] + d * math.cos(hd + a))
             for d, a in ((8, -0.56), (8, 0.56), (50, 0.56), (50, 0.0), (50, -0.56))]
    gone = clear_trees([ring, wedge], guard)
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
    put(drive, "forecourt_drive", col, (bpy.data.materials.get("clay_road") or mat("forecourt_bitumen", (0.12, 0.115, 0.11))), objs)
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
            crown = (ax, ay, nx, ny, hw)
            s = acc
            while s < ln:
                x, y = ax + ux * s, ay + uy * s
                if math.hypot(x, y) < 330 and not guard.keepout(x, y, 2.0):
                    r = rnd.random()
                    off = rnd.uniform(-hw * 0.8, hw * 0.8)
                    px, py = x + nx * off, y + ny * off
                    if r < 0.35:                                         # patch (darker, newer asphalt)
                        road_rect(patch, px, py, rnd.uniform(1.5, 6.0), rnd.uniform(1.0, 2.6), e, crown, 0.012, 6, 3)
                        np_ += 1
                    elif r < 0.6:                                        # crack seal: thin wandering strip
                        q = (px, py)
                        a = e + rnd.uniform(-0.6, 0.6)
                        for _ in range(rnd.randint(4, 9)):
                            q2 = (q[0] + math.cos(a) * 0.9, q[1] + math.sin(a) * 0.9)
                            road_rect(crack, (q[0] + q2[0]) / 2, (q[1] + q2[1]) / 2, 0.95, 0.03, a, crown, 0.016)
                            q = q2
                            a += rnd.uniform(-0.5, 0.5)
                    else:                                                 # manhole
                        disc(manhole, px, py, 0.33, crown_z(crown, px, py) - gz(px, py) + 0.014)
                        nm += 1
                    note(px, py, "roadmark")
                    for sd in (-1, 1):                                    # side-entry pit at each kerb
                        kx, ky = x + nx * sd * (hw - 0.25), y + ny * sd * (hw - 0.25)
                        if rnd.random() < 0.5 and not guard.keepout(kx, ky, 2.0):
                            road_rect(pit, kx, ky, 1.2, 0.35, e, crown, 0.016)
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
                        road_rect(gutter, mx, my, s1 - s0, 0.36, e, crown, 0.01, 2, 1)
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
        if not guard.ok(x, y, pad=0.0) or guard.road.on_road(x, y):
            spot = None                                     # r2: nearest clear spot just off the kerb (<= 6 m)
            for r_ in (0.5, 1.0, 1.5, 2.0, 2.5, 3.0, 4.0, 5.0, 6.0):
                for k_ in range(16):
                    qx, qy = x + r_ * math.cos(k_ * math.pi / 8), y + r_ * math.sin(k_ * math.pi / 8)
                    if guard.ok(qx, qy) and not guard.road.on_road(qx, qy):
                        spot = (qx, qy)
                        break
                if spot:
                    break
            if spot is None:
                report.append("sign at (%.0f, %.0f) off: keep-out or road" % (x, y))
                continue
            report.append("sign moved (%.0f, %.0f) -> (%.1f, %.1f), off the road" % (x, y, spot[0], spot[1]))
            x, y = spot
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
    # r2 (critic): roof read orange (#c8553a) -> photo #7f4535..#8a4a38; dressings read sage -> warm sandstone
    for name, rgb in (("cathedral_terracotta", P("cath_tile_lin", (0.20, 0.085, 0.036))),
                      ("cathedral_sandstone", P("cath_dress_lin", (0.50, 0.40, 0.25)))):
        m = bpy.data.materials.get(name)
        if m:
            m.diffuse_color = (*rgb, 1)
    st = bpy.data.objects.get("cathedral_stone")                     # r2: big irregular ashlar blocks, not brick
    if st and st.data.uv_layers.get("facade"):
        import numpy as np
        lay = st.data.uv_layers["facade"].data
        uv = np.empty(len(lay) * 2, "f4")
        lay.foreach_get("uv", uv)
        lay.foreach_set("uv", uv * P("ashlar_uv_scale", 0.5))
    # r2 (critic): Mantra, Willahra, Admiralty are concrete with punched windows and deep balconies, not glass stripes
    for osm in (568836537, 189779738, 26253098, 26386571, 26386543):   # 189779738: OSM "Hotel Mantra" carries the tower tiers
        m = bpy.data.materials.get("look_%d_wall" % osm)
        if m:
            m["shader"] = "render"
            for k, v in (("bay", 3.0), ("win", 1.15), ("sill", 0.3), ("head", 0.78), ("floor", 3.1), ("rough", 0.35)):
                m["win_" + k] = v
            m["win_glass"] = [0.028, 0.034, 0.042]
    # Soleil (Meriton): white diagonals, not a red stripe
    for nm in ("look_224320346_accent",):
        m = bpy.data.materials.get(nm)
        if m:
            m.diffuse_color = (0.85, 0.85, 0.83, 1)
    m = bpy.data.materials.get("look_224320346_wall")
    if m:
        m["diag"] = True
    # Mantra: no roof spike; the blue fin hugs the facade (drop pieces standing > 0.8 m off the footprint)
    recs = {b["osm"]: b for b in json.load(open(os.path.join(L.REF, "lidar", "buildings_clean.json")))["buildings"]}
    b = recs.get(568836537)
    if b:
        top = max(t["top_ahd"] for t in b["tiers"])
        rings = [S.ccw([tuple(p) for p in t["ring"]]) for t in b["tiers"]]
        grown = [[(x + (x - sum(p[0] for p in r) / len(r)) * 0.04, y + (y - sum(p[1] for p in r) / len(r)) * 0.04) for x, y in r]
                 for r in rings]
        gone = 0
        gone += drop_where(bpy.data.objects.get("bldg_spires_masts"), lambda X, Y, Z: in_rings_np(X, Y, grown))
        for ob in list(bpy.data.objects):
            if ob.name.startswith("bldg_look_568836537_") and ob.type == "MESH":
                gone += drop_where(ob, lambda X, Y, Z: (Z > top + 1.5) & in_rings_np(X, Y, grown) |
                                   (~in_rings_np(X, Y, grown) & (Z > b["base_ahd"] + 12)))
        report.append("Mantra: %d spike / detached fin faces dropped" % gone)
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


# ---------------------------------------------------------------------------------------------- roofs
def roof_plant(col, guard, objs, report):
    """r2 (critic): flat roofs get plant rooms, AC units and a lift overrun, so they do not read as blank slabs.
    Not on the Spire site, the cathedral, HSW or the HSW crest blocks; not on gabled / hipped roofs."""
    import random
    import buildings as B
    skip = set(B.SKIP) | set(L.hsw_crest_ids()) | {HALL_OSM}
    rooms, units = C.MeshBuf(), C.MeshBuf()
    n = 0
    for b in B.records():
        if b["osm"] in skip or b["gable"] or str(b["osm"]) in B._ROOFS:
            continue
        t = b["tiers"][-1]
        ring = S.ccw([tuple(p) for p in t["ring"]])
        cx = sum(p[0] for p in ring) / len(ring)
        cy = sum(p[1] for p in ring) / len(ring)
        x0, y0, x1, y1 = B.HSW_ZONE
        if math.hypot(cx, cy) > 330 or (x0 <= cx <= x1 and y0 <= cy <= y1) or guard.keepout(cx, cy, 5.0):
            continue
        area = abs(C.signed_area(ring))
        if area < 120 or t["top_ahd"] - b["base_ahd"] < 9:
            continue
        rnd = random.Random(b["osm"])
        top = t["top_ahd"] + 0.9                                      # on the parapet cap level
        _, _, ln, wd, ang = S.min_rect(ring)
        ux, uy, vx, vy = math.cos(ang), math.sin(ang), -math.sin(ang), math.cos(ang)
        tries = 0
        placed = 0
        want = 1 + (area > 400) + (area > 900)
        while placed < want and tries < 20:
            tries += 1
            sx, sy = rnd.uniform(3.0, min(8.0, ln * 0.4)), rnd.uniform(2.5, min(6.0, wd * 0.4))
            px = cx + ux * rnd.uniform(-0.25, 0.25) * ln + vx * rnd.uniform(-0.25, 0.25) * wd
            py = cy + uy * rnd.uniform(-0.25, 0.25) * ln + vy * rnd.uniform(-0.25, 0.25) * wd
            corners = [(px + ux * a * sx / 2 + vx * c * sy / 2, py + uy * a * sx / 2 + vy * c * sy / 2) for a in (-1, 1) for c in (-1, 1)]
            if not all(S.point_in(x, y, ring) for x, y in corners):
                continue
            rooms.box(px, py, top - 0.9, sx, sy, rnd.uniform(2.4, 3.6), ang)
            for k in range(rnd.randint(2, 5)):                         # AC units beside it
                ax_ = px + ux * (sx / 2 + 1.2 + 1.4 * (k // 2)) * (1 if k % 2 else -1)
                ay_ = py + uy * (sx / 2 + 1.2 + 1.4 * (k // 2)) * (1 if k % 2 else -1)
                if S.point_in(ax_, ay_, ring):
                    units.box(ax_, ay_, top - 0.9, 1.1, 1.1, 1.0, ang)
            placed += 1
        if placed:
            note(cx, cy, "roof")
            n += 1
    put(rooms, "roof_plant_rooms", col, mat("plant_room", (0.42, 0.42, 0.41)), objs)
    put(units, "roof_ac_units", col, mat("ac_units", (0.55, 0.56, 0.56)), objs)
    report.append("roof plant on %d buildings" % n)


CUSTOMS_OSM = 26253545


def customs_house(col, guard, objs, report):
    """r2 (critic + Commons photos from the river): Corinthian colonnade of 6 columns with entablature and
    pediment on the river front, the copper dome above it in verdigris green."""
    import trees as T
    o = L.osm()
    w = o["ways"].get(CUSTOMS_OSM)
    m = bpy.data.materials.get("look_%d_accent" % CUSTOMS_OSM)
    if m:
        m.diffuse_color = (0.09, 0.20, 0.15, 1)
    if not w:
        return
    ring = S.ccw(C.clean_ring(o["line"](w)))
    cx = sum(p[0] for p in ring) / len(ring)
    cy = sum(p[1] for p in ring) / len(ring)
    tx, ty = 80.0 - cx, -310.0 - cy                                 # towards the river
    tl = math.hypot(tx, ty)
    best = None
    for a, b in zip(ring, ring[1:] + ring[:1]):
        ln = math.dist(a, b)
        nx, ny = (b[1] - a[1]) / ln, -(b[0] - a[0]) / ln             # outward (ccw ring)
        score = (nx * tx + ny * ty) / tl * ln
        if best is None or score > best[0]:
            best = (score, a, b, nx, ny, ln)
    _, a, b, nx, ny, ln = best
    ux, uy = (b[0] - a[0]) / ln, (b[1] - a[1]) / ln
    mx, my = (a[0] + b[0]) / 2, (a[1] + b[1]) / 2
    g = min(gz(*a), gz(*b))
    cols_, stone = C.MeshBuf(), C.MeshBuf()
    span = min(ln * 0.55, 16.0)
    H, R = 9.5, 0.45
    for i in range(6):
        u = -span / 2 + span * i / 5
        px, py = mx + ux * u + nx * 2.2, my + uy * u + ny * 2.2
        T.tube(cols_, (px, py, g + 1.0), (px, py, g + 1.0 + H), R, R * 0.86, 14)
        cols_.box(px, py, g + 0.4, 1.2, 1.2, 0.6, math.atan2(uy, ux))             # base
        cols_.box(px, py, g + 1.0 + H - 0.1, 1.15, 1.15, 0.7, math.atan2(uy, ux))  # capital block
    e = math.atan2(uy, ux)
    ex, ey = mx + nx * 1.6, my + ny * 1.6
    stone.box(ex, ey, g - 0.2, span + 2.4, 4.0, 1.2, e)                          # podium / steps
    stone.box(ex, ey, g + 1.0 + H + 0.6, span + 2.0, 3.6, 1.4, e)               # entablature
    zp = g + 1.0 + H + 2.0
    l2 = (span + 2.0) / 2
    tri = [(ex - ux * l2 + nx * 1.8, ey - uy * l2 + ny * 1.8, zp), (ex + ux * l2 + nx * 1.8, ey + uy * l2 + ny * 1.8, zp),
           (ex + nx * 1.8, ey + ny * 1.8, zp + 2.6),
           (ex - ux * l2 - nx * 1.8, ey - uy * l2 - ny * 1.8, zp), (ex + ux * l2 - nx * 1.8, ey + uy * l2 - ny * 1.8, zp),
           (ex - nx * 1.8, ey - ny * 1.8, zp + 2.6)]
    stone.add(tri, [[0, 1, 2], [5, 4, 3], [0, 2, 5, 3], [1, 4, 5, 2], [0, 3, 4, 1]])  # pediment
    if not guard.ok(mx + nx * 2.2, my + ny * 2.2):
        report.append("Customs House portico off: keep-out or road")
        return
    note(mx + nx * 2.2, my + ny * 2.2, "building")
    wall = bpy.data.materials.get("look_%d_wall" % CUSTOMS_OSM)
    ston = mat("customs_sandstone", tuple(wall.diffuse_color)[:3] if wall else (0.62, 0.52, 0.36))
    put(cols_, "customs_columns", col, ston, objs)
    put(stone, "customs_portico", col, ston, objs)
    report.append("Customs House: 6-column portico + pediment on the river front, copper dome green")


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
            ob.location.z += 0.035                    # r2: flat paint decal (no extrusion), just above the crown
            ob.rotation_euler.y = 0.0
            if ob.type == "FONT":
                ob.data.extrude = 0.0
            nb += 1
    report.append("BUS ONLY words lifted: %d" % nb)
    carparks(col, guard, objs, report)
    forecourt(col, guard, objs, report)
    roads(col, guard, objs, report)
    signs(col, guard, objs, report)
    roof_plant(col, guard, objs, report)
    customs_house(col, guard, objs, report)
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
        if m.name == "area_road_patch":
            soft_edges(m, nt, bsdf)
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
        if m.name.endswith("_roof") and m.name.startswith(("look_", "gen_")):
            roof_tones(nt, bsdf)
        if m.name == "cathedral_terracotta":
            tile_courses(nt, bsdf)
        if m.get("diag"):
            diag_stripes(nt, bsdf)
        if m.name == "cathedral_slate" or m.name == "cathedral_spire_slate":
            tile_courses(nt, bsdf, course=0.22, dark=0.7)
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


def soft_edges(m, nt, bsdf):
    """r2: road patches fade out over their outer 20 % (UV 0..1), so they read as worn repairs, not tiles."""
    uv = nt.nodes.new("ShaderNodeUVMap")
    uv.uv_map = "facade"
    sep = nt.nodes.new("ShaderNodeSeparateXYZ")
    nt.links.new(uv.outputs["UV"], sep.inputs[0])
    edge = None
    for comp in ("X", "Y"):
        a = nt.nodes.new("ShaderNodeMath")
        a.operation = "SUBTRACT"
        a.inputs[0].default_value = 1.0
        nt.links.new(sep.outputs[comp], a.inputs[1])
        mn = nt.nodes.new("ShaderNodeMath")
        mn.operation = "MINIMUM"
        nt.links.new(sep.outputs[comp], mn.inputs[0])
        nt.links.new(a.outputs[0], mn.inputs[1])
        if edge is None:
            edge = mn.outputs[0]
        else:
            m2 = nt.nodes.new("ShaderNodeMath")
            m2.operation = "MINIMUM"
            nt.links.new(edge, m2.inputs[0])
            nt.links.new(mn.outputs[0], m2.inputs[1])
            edge = m2.outputs[0]
    mr = nt.nodes.new("ShaderNodeMapRange")
    nt.links.new(edge, mr.inputs["Value"])
    mr.inputs["From Min"].default_value = 0.0
    mr.inputs["From Max"].default_value = 0.2
    mr.inputs["To Max"].default_value = 0.85
    nt.links.new(mr.outputs["Result"], bsdf.inputs["Alpha"])
    try:
        m.surface_render_method = "DITHERED"
    except AttributeError:
        m.blend_method = "HASHED"


def diag_stripes(nt, bsdf):
    """r2: Soleil's white diagonal bands over the facade (UV: u metres round, v metres up)."""
    src = bsdf.inputs["Base Color"].links[0].from_socket if bsdf.inputs["Base Color"].is_linked else None
    uv = next((n for n in nt.nodes if n.bl_idname == "ShaderNodeUVMap"), None)
    if uv is None:
        return
    sep = nt.nodes.new("ShaderNodeSeparateXYZ")
    nt.links.new(uv.outputs["UV"], sep.inputs[0])
    add = nt.nodes.new("ShaderNodeMath")
    add.operation = "ADD"
    nt.links.new(sep.outputs["X"], add.inputs[0])
    nt.links.new(sep.outputs["Y"], add.inputs[1])
    div = nt.nodes.new("ShaderNodeMath")
    div.operation = "DIVIDE"
    nt.links.new(add.outputs[0], div.inputs[0])
    div.inputs[1].default_value = 22.0
    fr = nt.nodes.new("ShaderNodeMath")
    fr.operation = "FRACT"
    nt.links.new(div.outputs[0], fr.inputs[0])
    lt = nt.nodes.new("ShaderNodeMath")
    lt.operation = "LESS_THAN"
    nt.links.new(fr.outputs[0], lt.inputs[0])
    lt.inputs[1].default_value = 0.07
    mx = nt.nodes.new("ShaderNodeMix")
    mx.data_type = "RGBA"
    nt.links.new(lt.outputs[0], mx.inputs["Factor"])
    if src is not None:
        nt.links.new(src, mx.inputs[6])
    else:
        mx.inputs[6].default_value = bsdf.inputs["Base Color"].default_value
    mx.inputs[7].default_value = (0.86, 0.86, 0.84, 1)
    nt.links.new(mx.outputs[2], bsdf.inputs["Base Color"])


def roof_tones(nt, bsdf):
    """r2: flat roofs in mixed membrane tones (pale, mid and warm grey patches ~40 m across) with fine grime."""
    geo = nt.nodes.new("ShaderNodeNewGeometry")
    big = nt.nodes.new("ShaderNodeTexNoise")
    big.inputs["Scale"].default_value = 0.025
    big.inputs["Detail"].default_value = 1.0
    nt.links.new(geo.outputs["Position"], big.inputs["Vector"])
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    el = ramp.color_ramp.elements
    el[0].position, el[0].color = 0.35, (0.20, 0.205, 0.21, 1)
    el[1].position, el[1].color = 0.65, (0.36, 0.35, 0.33, 1)
    e3 = el.new(0.5)
    e3.color = (0.27, 0.25, 0.22, 1)
    nt.links.new(big.outputs["Fac"], ramp.inputs["Fac"])
    fine = nt.nodes.new("ShaderNodeTexNoise")
    fine.inputs["Scale"].default_value = 1.5
    nt.links.new(geo.outputs["Position"], fine.inputs["Vector"])
    mx = nt.nodes.new("ShaderNodeMix")
    mx.data_type = "RGBA"
    mx.blend_type = "MULTIPLY"
    mx.inputs["Factor"].default_value = 0.35
    nt.links.new(ramp.outputs["Color"], mx.inputs[6])
    nt.links.new(fine.outputs["Color"], mx.inputs[7])
    nt.links.new(mx.outputs[2], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = 0.9


def tile_courses(nt, bsdf, course=0.28, dark=0.72):
    """r2: visible tile / slate courses (horizontal lines every course in world z) and tile-to-tile tone."""
    geo = nt.nodes.new("ShaderNodeNewGeometry")
    sep = nt.nodes.new("ShaderNodeSeparateXYZ")
    nt.links.new(geo.outputs["Position"], sep.inputs[0])
    dv = nt.nodes.new("ShaderNodeMath")
    dv.operation = "DIVIDE"
    nt.links.new(sep.outputs["Z"], dv.inputs[0])
    dv.inputs[1].default_value = course
    fr = nt.nodes.new("ShaderNodeMath")
    fr.operation = "FRACT"
    nt.links.new(dv.outputs[0], fr.inputs[0])
    lt = nt.nodes.new("ShaderNodeMath")
    lt.operation = "LESS_THAN"
    nt.links.new(fr.outputs[0], lt.inputs[0])
    lt.inputs[1].default_value = 0.18
    wn = nt.nodes.new("ShaderNodeTexNoise")
    wn.inputs["Scale"].default_value = 3.5
    nt.links.new(geo.outputs["Position"], wn.inputs["Vector"])
    base = tuple(bsdf.inputs["Base Color"].default_value)
    m1 = nt.nodes.new("ShaderNodeMix")
    m1.data_type = "RGBA"
    nt.links.new(wn.outputs["Fac"], m1.inputs["Factor"])
    m1.inputs[6].default_value = (base[0] * 0.85, base[1] * 0.85, base[2] * 0.85, 1)
    m1.inputs[7].default_value = (min(1, base[0] * 1.12), min(1, base[1] * 1.1), min(1, base[2] * 1.08), 1)
    m2 = nt.nodes.new("ShaderNodeMix")
    m2.data_type = "RGBA"
    m2.blend_type = "MULTIPLY"
    nt.links.new(lt.outputs[0], m2.inputs["Factor"])
    nt.links.new(m1.outputs[2], m2.inputs[6])
    m2.inputs[7].default_value = (dark, dark, dark, 1)
    nt.links.new(m2.outputs[2], bsdf.inputs["Base Color"])
    bump = nt.nodes.new("ShaderNodeBump")
    bump.inputs["Strength"].default_value = 0.3
    nt.links.new(lt.outputs[0], bump.inputs["Height"])
    nt.links.new(bump.outputs["Normal"], bsdf.inputs["Normal"])


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
    # r2: lit windows come in floor runs (a flat = 3-6 windows on one floor), ~15 % lit, 3 colour temperatures
    run = op("FLOOR", op("DIVIDE", op("DIVIDE", sep.outputs["X"], bay), P("window_run", 4.0)), None)
    cv = op("FLOOR", op("DIVIDE", sep.outputs["Y"], flo), None)
    comb = nt.nodes.new("ShaderNodeCombineXYZ")
    nt.links.new(run, comb.inputs[0])
    nt.links.new(cv, comb.inputs[1])
    wn = nt.nodes.new("ShaderNodeTexWhiteNoise")
    wn.noise_dimensions = "3D"
    nt.links.new(comb.outputs[0], wn.inputs["Vector"])
    sepc = nt.nodes.new("ShaderNodeSeparateColor")                      # two independent randoms per run
    nt.links.new(wn.outputs["Color"], sepc.inputs[0])
    on = op("GREATER_THAN", wn.outputs["Value"], P("window_off", 0.85))
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    ramp.color_ramp.interpolation = "CONSTANT"
    el = ramp.color_ramp.elements
    el[0].position, el[0].color = 0.0, (1.0, 0.62, 0.32, 1)            # warm incandescent
    el[1].position, el[1].color = 0.45, (1.0, 0.86, 0.66, 1)           # warm white
    e3 = el.new(0.8)
    e3.color = (0.78, 0.88, 1.0, 1)                                     # cool LED / TV
    nt.links.new(sepc.outputs[0], ramp.inputs["Fac"])
    v = nt.nodes.new("ShaderNodeValue")
    v.name = "AREA_DUSK"
    v.outputs[0].default_value = 0.0
    dim = op("MULTIPLY_ADD", sepc.outputs[1], 0.6)                       # brightness 0.4-1.0 per run
    nt.nodes[dim.node.name].inputs[2].default_value = 0.4
    strength = op("MULTIPLY", op("MULTIPLY", op("MULTIPLY", op("MULTIPLY", mask, on), v.outputs[0]), dim), P("window_gain", 0.8))
    nt.links.new(ramp.outputs["Color"], bsdf.inputs["Emission Color"])
    nt.links.new(strength, bsdf.inputs["Emission Strength"])
    return v


SKY_DAY = [(0.0, "C4D8EA"), (0.22, "8FB5DE"), (1.0, "2F6FC0")]          # horizon -> zenith (critic r1 target)
SKY_DUSK = [(0.0, "E9B58F"), (0.12, "C8A3B6"), (0.45, "7E7FAE"), (1.0, "4E5C8E")]   # peach, lilac, soft blue


def lin(h):
    h = h.lstrip("#")
    c = [int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)]
    return tuple(x / 12.92 if x <= 0.04045 else ((x + 0.055) / 1.055) ** 2.4 for x in c)


def sky(dusk):
    """r2: the camera sees a painted gradient sky with a few soft cumulus; lighting still comes from the
    Nishita sky (Light Path 'Is Camera Ray' picks one or the other)."""
    w = bpy.context.scene.world
    nt = w.node_tree
    out = nt.nodes.get("World Output")
    bg = nt.nodes.get("Background")
    if not nt.nodes.get("AREA_SKY_MIX"):
        tc = nt.nodes.new("ShaderNodeTexCoord")
        sep = nt.nodes.new("ShaderNodeSeparateXYZ")
        nt.links.new(tc.outputs["Generated"], sep.inputs[0])
        cl = nt.nodes.new("ShaderNodeMath")
        cl.operation = "MAXIMUM"
        nt.links.new(sep.outputs["Z"], cl.inputs[0])
        cl.inputs[1].default_value = 0.0
        pw = nt.nodes.new("ShaderNodeMath")
        pw.operation = "POWER"
        nt.links.new(cl.outputs[0], pw.inputs[0])
        pw.inputs[1].default_value = 0.7
        ramp = nt.nodes.new("ShaderNodeValToRGB")
        ramp.name = "AREA_SKY_RAMP"
        nt.links.new(pw.outputs[0], ramp.inputs["Fac"])
        # clouds: noise on the direction projected onto a cloud deck, only above ~5 deg, sparse
        dv = nt.nodes.new("ShaderNodeVectorMath")
        dv.operation = "DIVIDE"
        nt.links.new(tc.outputs["Generated"], dv.inputs[0])
        cz = nt.nodes.new("ShaderNodeCombineXYZ")
        mz = nt.nodes.new("ShaderNodeMath")
        mz.operation = "MAXIMUM"
        nt.links.new(sep.outputs["Z"], mz.inputs[0])
        mz.inputs[1].default_value = 0.06
        for i in range(3):
            nt.links.new(mz.outputs[0], cz.inputs[i])
        nt.links.new(cz.outputs[0], dv.inputs[1])
        nz = nt.nodes.new("ShaderNodeTexNoise")
        nz.inputs["Scale"].default_value = P("cloud_scale", 1.6)
        nz.inputs["Detail"].default_value = 6.0
        nz.inputs["Roughness"].default_value = 0.55
        nt.links.new(dv.outputs[0], nz.inputs["Vector"])
        cr = nt.nodes.new("ShaderNodeMapRange")
        cr.name = "AREA_CLOUD"
        nt.links.new(nz.outputs["Fac"], cr.inputs["Value"])
        cr.inputs["From Min"].default_value = P("cloud_from", 0.60)
        cr.inputs["From Max"].default_value = P("cloud_from", 0.60) + 0.12
        fade = nt.nodes.new("ShaderNodeMapRange")                       # no clouds near the horizon
        nt.links.new(sep.outputs["Z"], fade.inputs["Value"])
        fade.inputs["From Min"].default_value = 0.06
        fade.inputs["From Max"].default_value = 0.3
        cf = nt.nodes.new("ShaderNodeMath")
        cf.operation = "MULTIPLY"
        nt.links.new(cr.outputs["Result"], cf.inputs[0])
        nt.links.new(fade.outputs["Result"], cf.inputs[1])
        cmix = nt.nodes.new("ShaderNodeMix")
        cmix.data_type = "RGBA"
        cmix.name = "AREA_CLOUD_MIX"
        nt.links.new(cf.outputs[0], cmix.inputs["Factor"])
        nt.links.new(ramp.outputs["Color"], cmix.inputs[6])
        cbg = nt.nodes.new("ShaderNodeBackground")
        cbg.name = "AREA_SKY_BG"
        nt.links.new(cmix.outputs[2], cbg.inputs["Color"])
        lp = nt.nodes.new("ShaderNodeLightPath")
        ms = nt.nodes.new("ShaderNodeMixShader")
        ms.name = "AREA_SKY_MIX"
        nt.links.new(lp.outputs["Is Camera Ray"], ms.inputs["Fac"])
        nt.links.new(bg.outputs[0], ms.inputs[1])
        nt.links.new(cbg.outputs[0], ms.inputs[2])
        nt.links.new(ms.outputs[0], out.inputs["Surface"])
    ramp = nt.nodes["AREA_SKY_RAMP"].color_ramp
    stops = SKY_DUSK if dusk else SKY_DAY
    el = ramp.elements
    while len(el) > 2:
        el.remove(el[-1])
    while len(el) < len(stops):
        el.new(0.5)
    for e, (pos, h) in zip(el, stops):
        e.position, e.color = pos, (*lin(h), 1)
    nt.nodes["AREA_CLOUD_MIX"].inputs[7].default_value = (1.0, 0.86, 0.80, 1) if dusk else (1.0, 1.0, 1.0, 1)
    nt.nodes["AREA_CLOUD"].inputs["To Max"].default_value = 0.55 if dusk else P("cloud_cover", 0.85)
    nt.nodes["AREA_SKY_BG"].inputs["Strength"].default_value = P("sky_cam_dusk", 1.3) if dusk else P("sky_cam_day", 1.55)


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
            sun.data.energy = sun.data.energy * P("sun_gain", 1.3)
        if bg:
            bg.inputs["Strength"].default_value *= P("sky_fill_gain", 0.55)
        sc.view_settings.exposure += P("exposure_add_day", 0.7)          # r2: +0.6 EV on round 1
    else:
        if bg:
            bg.inputs["Strength"].default_value *= 0.8
    try:
        sc.view_settings.look = "AgX - Medium High Contrast"
    except TypeError:
        pass
    for v in _STATE.get("dusk", []):
        v.outputs[0].default_value = 1.0 if dusk else 0.0
    sky(dusk)
    # r2: blue-grey haze (#8fa3b8 at display), not khaki; dusk a lilac-grey
    mist(kind == "aerial", strength=0.32 if dusk else P("haze_k", 0.5),
         rgb=P("haze_dusk", (0.30, 0.27, 0.36)) if dusk else P("haze_day", (0.36, 0.48, 0.64)))
