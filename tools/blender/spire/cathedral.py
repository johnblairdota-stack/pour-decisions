"""St John's Cathedral, Gothic Revival parts (step 7a), per docs/spire/materials_from_photos.md.

Plan from the OSM footprint (rectangle + Latin cross), every height measured from the 2019 LiDAR inside the
footprint. Parts: nave with a steep (55 deg) terracotta roof, lower aisles with a cross gable per bay,
buttresses with pinnacle caps and flying buttresses to the clerestory, paired lancets with dark leadlight
in pale sandstone surrounds, transept arms with gable windows, a square crossing tower with a dark slate
pyramid roof, an apse at the east end, twin west towers (square, then octagonal belfry stages with a ring
of pinnacles, then tall dark slate spires with pale bands and finials), and a west front with three deep
portals, a blind arcade, a great traced window and a central gable with a rose.
Materials: mottled tuff ashlar (procedural), sandstone dressings, terracotta tile, slate, leadlight."""
import math

import numpy as np

import layout as L
import common as C
import shapes as S
import prep_lidar as PL
from looks import CATHEDRAL as LOOK

WAY = 26384715
PITCH = math.radians(55)
BAY = 6.0


def arch_pts(w, z0, z1):
    """Pointed arch outline (a, z): a across the wall, z up; spring at z1, apex 0.85 w above it."""
    apex = z1 + 0.85 * w
    right = [(w / 2, z0), (w / 2, z1)]
    for k in range(1, 4):
        t = k / 4
        right.append((w / 2 * math.cos(t * math.pi / 2), z1 + (apex - z1) * math.sin(t * math.pi / 2)))
    left = [(-a, z) for a, z in reversed(right[1:-1])]
    return [(-w / 2, z0)] + right + [(0.0, apex)] + left


class Cath:
    def __init__(self, cx, cy, ang, g):
        self.cx, self.cy, self.g = cx, cy, g
        self.ux, self.uy = math.cos(ang), math.sin(ang)
        self.vx, self.vy = -self.uy, self.ux
        self.ang = ang
        self.b = {k: C.MeshBuf() for k in ("stone", "dress", "tile", "slate", "spire", "glass")}

    def P(self, u, v, z):
        return (self.cx + u * self.ux + v * self.vx, self.cy + u * self.uy + v * self.vy, self.g + z)

    def xy(self, u, v):
        return self.P(u, v, 0)[:2]

    def block(self, key, u0, u1, v0, v1, z0, z1):
        self.b[key].prism(S.ccw([self.xy(u0, v0), self.xy(u1, v0), self.xy(u1, v1), self.xy(u0, v1)]),
                          self.g + z0, self.g + z1)

    def gable_roof(self, key, u0, u1, v0, v1, eave, along_u=True):
        """Pitched roof over a rectangle; ridge along u (or along v). Returns the ridge height."""
        if along_u:
            vm, r = (v0 + v1) / 2, eave + math.tan(PITCH) * (v1 - v0) / 2
            vs = [self.P(u0, v0, eave), self.P(u1, v0, eave), self.P(u1, v1, eave), self.P(u0, v1, eave),
                  self.P(u0, vm, r), self.P(u1, vm, r)]
            self.b[key].add(vs, [[0, 1, 5, 4], [2, 3, 4, 5], [0, 4, 3], [1, 2, 5]])
        else:
            um, r = (u0 + u1) / 2, eave + math.tan(PITCH) * (u1 - u0) / 2
            vs = [self.P(u0, v0, eave), self.P(u1, v0, eave), self.P(u1, v1, eave), self.P(u0, v1, eave),
                  self.P(um, v0, r), self.P(um, v1, r)]
            self.b[key].add(vs, [[1, 2, 5, 4], [3, 0, 4, 5], [0, 1, 4], [2, 3, 5]])
        return r

    def gable_end(self, key, u, v0, v1, eave, ridge, out):
        vm = (v0 + v1) / 2
        vs = [self.P(u, v0, eave), self.P(u, v1, eave), self.P(u, vm, ridge)]
        self.b[key].add(vs, [[0, 1, 2] if out > 0 else [2, 1, 0]])

    def lancet(self, along_u, fixed, c, w, z0, z1, out, frame=True, key="glass"):
        """Pointed window on a wall plane. along_u: wall at v = fixed (faces out*v); else wall at u = fixed."""
        def put(pts, push, k):
            vs = [self.P(c + a, fixed + out * push, z) if along_u else self.P(fixed + out * push, c + a, z) for a, z in pts]
            face = list(range(len(vs)))
            flip = (out < 0) if along_u else (out > 0)
            self.b[k].add(vs, [face[::-1] if flip else face])
        if frame:
            put(arch_pts(w + 0.5, z0 - 0.25, z1), 0.05, "dress")
        put(arch_pts(w, z0, z1), 0.09, key)

    def pinnacle(self, u, v, z, h=3.0, r=0.45):
        """Gabled pinnacle (photos): square shaft, a small gable on each face, then a tall crocketed spike."""
        x, y, zz = self.P(u, v, z)
        sh = h * 0.38
        self.b["dress"].box(x, y, zz, 2 * r, 2 * r, sh, self.ang)
        gz, gh = zz + sh, r * 1.3
        for k in range(4):                                               # gablets on the four faces
            a = self.ang + k * math.pi / 2
            ox, oy = math.cos(a), math.sin(a)
            px, py = -oy, ox
            p0 = (x + ox * r + px * r, y + oy * r + py * r, gz)
            p1 = (x + ox * r - px * r, y + oy * r - py * r, gz)
            p2 = (x + ox * r, y + oy * r, gz + gh)
            q2 = (x, y, gz + gh)
            self.b["dress"].add([p0, p1, p2], [[0, 1, 2], [2, 1, 0]])
            self.b["dress"].add([p0, p2, q2, (x + px * r, y + py * r, gz + gh * 0.5)], [[0, 1, 2, 3]])
            self.b["dress"].add([p1, p2, q2, (x - px * r, y - py * r, gz + gh * 0.5)], [[3, 2, 1, 0]])
        n = 8
        rr = r * 0.8
        ring = [(x + rr * math.cos(self.ang + math.pi / 8 + k * math.pi / 4), y + rr * math.sin(self.ang + math.pi / 8 + k * math.pi / 4),
                 gz + gh * 0.4) for k in range(n)]
        self.b["dress"].add(ring + [(x, y, zz + h)], [[k, (k + 1) % n, n] for k in range(n)])

    def arch_frame(self, uplane, c, w, z0, z1, t, out, key="dress"):
        """A moulded arch order: strip between an outer and an inner pointed arch, on the plane u = uplane."""
        def line(wd):
            pts = [(-wd / 2, z0), (-wd / 2, z1)]
            apex = z1 + 0.85 * wd
            for k in range(1, 7):
                s = k / 7
                pts.append((-wd / 2 * math.cos(s * math.pi / 2), z1 + (apex - z1) * math.sin(s * math.pi / 2)))
            pts.append((0.0, apex))
            pts += [(-a, z) for a, z in reversed(pts[1:-1])]
            return pts + [(wd / 2, z0)]
        A, Bn = line(w), line(w - 2 * t)
        vs = [self.P(uplane, c + a, z) for a, z in A] + [self.P(uplane, c + a, z) for a, z in Bn]
        n = len(A)
        faces = [[i, i + 1, n + i + 1, n + i] for i in range(n - 1)]
        if out < 0:
            faces = [f[::-1] for f in faces]
        self.b[key].add(vs, faces)

    def octagon(self, key, u, v, r, z0, z1):
        ring = [self.xy(u + r * math.cos(math.pi / 8 + k * math.pi / 4), v + r * math.sin(math.pi / 8 + k * math.pi / 4))
                for k in range(8)]
        self.b[key].prism(S.ccw(ring), self.g + z0, self.g + z1)

    def weather(self, u0, u1, v_in, v_out, z, h):
        """Sloping sandstone weathering on a buttress set-off: high at the wall (v_in), down to z at v_out (area r5)."""
        vs = [self.P(u0, v_in, z), self.P(u1, v_in, z), self.P(u1, v_out, z), self.P(u0, v_out, z),
              self.P(u0, v_in, z + h), self.P(u1, v_in, z + h)]
        self.b["dress"].add(vs, [[3, 2, 1, 0], [4, 5, 2, 3], [0, 1, 5, 4], [0, 4, 3], [1, 2, 5]])

    def drum(self, key, u, v, r, z0, z1, n=16):
        """Round turret drum (area r4)."""
        x, y, _ = self.P(u, v, 0)
        self.b[key].prism([(x + r * math.cos(2 * math.pi * k / n), y + r * math.sin(2 * math.pi * k / n)) for k in range(n)],
                          self.g + z0, self.g + z1)

    def spire(self, u, v, r, z0, z1):
        x, y, _ = self.P(u, v, 0)
        n = 8
        a0 = self.ang + math.pi / 8
        base = [(x + r * math.cos(a0 + k * math.pi / 4), y + r * math.sin(a0 + k * math.pi / 4), self.g + z0) for k in range(n)]
        self.b["spire"].add(base + [(x, y, self.g + z1)], [[k, (k + 1) % n, n] for k in range(n)])
        # area r4: the pale stone bands ("gold collars") near the top are gone (critic + photos)
        self.b["dress"].box(x, y, self.g + z1, 0.25, 0.25, 2.2, self.ang)           # finial and cross
        self.b["dress"].box(x, y, self.g + z1 + 1.3, 1.1, 0.2, 0.2, self.ang)


def measure():
    o = L.osm()
    ring = S.clean(o["line"](o["ways"][WAY]), 0.3)
    cx, cy, ln, wd, ang = S.min_rect(ring)
    box = L.LIDAR_BOX
    m, r0, c0 = PL.ring_mask(ring, box)
    sub = (slice(r0, r0 + m.shape[0]), slice(c0, c0 + m.shape[1]))
    g = float(np.median(L.lidar("ground")[sub][m]))
    rr, cc = np.nonzero(m)
    X = box[0] + c0 + cc + 0.5
    Y = box[3] - r0 - rr - 0.5
    H = L.lidar("dsm")[sub][m] - g
    ux, uy = math.cos(ang), math.sin(ang)
    U = (X - cx) * ux + (Y - cy) * uy
    V = (X - cx) * -uy + (Y - cy) * ux
    return cx, cy, ln, wd, ang, g, U, V, H


def build():
    o = L.osm()
    if WAY not in o["ways"]:
        return {"module": "cathedral", "objects": [], "note": "cathedral not in the OSM crop"}
    col = C.collection("landmarks")
    cx, cy, ln, wd, ang, g, U, V, H = measure()
    K = Cath(cx, cy, ang, g)
    hl = ln / 2
    nave_w = 0.42 * wd
    centre = np.abs(V) < 0.12 * wd
    ridge_m = float(np.percentile(H[centre], 70))                      # measured nave ridge
    eave = ridge_m - math.tan(PITCH) * nave_w / 2                       # 55 deg roof down to the eave
    aisle_top = max(5.0, min(eave - 5.0, float(np.percentile(H[np.abs(V) > 0.32 * wd], 50))))
    # towers from the LiDAR (tall groups); the west end is the end with the tower pair
    tall = H > ridge_m + 6
    towers = []
    if tall.any():
        pts = np.stack([U[tall], V[tall], H[tall]], 1)
        used = np.zeros(len(pts), bool)
        for i in np.argsort(-pts[:, 2]):
            if used[i]:
                continue
            near = (np.abs(pts[:, 0] - pts[i, 0]) < 7) & (np.abs(pts[:, 1] - pts[i, 1]) < 7)
            used |= near
            grp = pts[near]
            if len(grp) >= 4:
                towers.append((float(grp[:, 0].mean()), float(grp[:, 1].mean()), float(grp[:, 2].max())))
            if len(towers) >= 3:
                break
    west = -1 if not towers or sum(t[0] for t in towers) < 0 else 1
    west_towers = sorted([t for t in towers if abs(t[0] - west * hl) < 0.3 * ln], key=lambda t: t[1])[:2]
    if len(west_towers) < 2:
        west_towers = [(west * (hl - 4.5), s * (nave_w / 2 + 3.5), ridge_m + 30.0) for s in (-1, 1)]
    front = 9.0                                                         # depth of the west front block
    nu0, nu1 = (-hl + front, hl - nave_w / 2) if west < 0 else (-hl + nave_w / 2, hl - front)
    apse_u = nu1 if west < 0 else nu0
    # ------------------------------------------------------------ nave
    K.block("stone", nu0, nu1, -nave_w / 2, nave_w / 2, -0.5, eave)
    K.gable_roof("tile", nu0 - 0.3, nu1 + 0.3, -nave_w / 2 - 0.4, nave_w / 2 + 0.4, eave)
    # ------------------------------------------------------------ transept (from the LiDAR, else a third from the east)
    wide = (np.abs(V) > 0.30 * wd) & (H > eave - 2)
    if wide.sum() > 20:
        tu0, tu1 = float(np.percentile(U[wide], 10)), float(np.percentile(U[wide], 90))
    else:
        tu0, tu1 = -west * hl * 0.35 - 5, -west * hl * 0.35 + 5
    um, tw = (tu0 + tu1) / 2, max(8.0, min(14.0, tu1 - tu0))
    K.block("stone", um - tw / 2, um + tw / 2, -wd / 2 - 1.5, wd / 2 + 1.5, -0.5, eave)
    K.gable_roof("tile", um - tw / 2 - 0.3, um + tw / 2 + 0.3, -wd / 2 - 1.8, wd / 2 + 1.8, eave, along_u=False)
    for s in (-1, 1):
        K.lancet(True, s * (wd / 2 + 1.5), um, tw * 0.45, 3.5, eave - 3.0, s)
    # ------------------------------------------------------------ aisles: cross gable per bay, lancets, buttresses
    bays = np.arange(nu0 + BAY / 2, nu1 - BAY / 2 + 0.01, BAY)
    for s in (-1, 1):
        a0, a1 = s * nave_w / 2, s * wd / 2
        K.block("stone", nu0, nu1, min(a0, a1), max(a0, a1), -0.5, aisle_top)
        for ub in bays:
            if abs(ub - um) < tw / 2 + 1:
                continue
            K.gable_roof("tile", ub - BAY / 2 + 0.5, ub + BAY / 2 - 0.5, min(a0, a1) - (0.4 if s < 0 else 0),
                         max(a0, a1) + (0.4 if s > 0 else 0), aisle_top, along_u=False)
            for d in (-0.75, 0.75):
                K.lancet(True, a1, ub + d, 0.9, 2.2, aisle_top - 1.4, s)                    # paired aisle lancets
                if eave - aisle_top > 5:
                    K.lancet(True, a0, ub + d * 0.8, 0.8, aisle_top + 3.0, eave - 1.6, s)    # clerestory pair
            bu = ub + BAY / 2
            if bu < nu1 - 0.5:
                x0 = a1 + s * 1.0                                              # thick buttress, three stepped offsets
                # area r5: stepped stone (not cream slabs) with a sloping sandstone weathering at each set-off
                K.block("stone", bu - 0.8, bu + 0.8, x0 - 1.0, x0 + 1.0, -0.3, aisle_top * 0.4)
                K.weather(bu - 0.82, bu + 0.82, x0 - s * 1.0, x0 + s * 1.02, aisle_top * 0.4, 0.55)
                K.block("stone", bu - 0.7, bu + 0.7, x0 - 0.75 - s * 0.25, x0 + 0.75 - s * 0.25, aisle_top * 0.4, aisle_top * 0.75)
                K.weather(bu - 0.72, bu + 0.72, x0 - s * 1.0, x0 + s * 0.52, aisle_top * 0.75, 0.5)
                K.block("stone", bu - 0.6, bu + 0.6, x0 - 0.5 - s * 0.5, x0 + 0.5 - s * 0.5, aisle_top * 0.75, aisle_top + 1.2)
                K.pinnacle(bu, x0 - s * 0.5, aisle_top + 1.2, 4.0, 0.55)
                K.b["dress"].beam(K.P(bu, x0, aisle_top + 0.8), K.P(bu, a0 + s * 0.2, eave - 2.0), 0.45)   # flying buttress
    # ------------------------------------------------------------ apse at the east end
    r = nave_w / 2
    sgn = -west
    pts = [K.xy(apse_u + sgn * r * math.sin(k * math.pi / 6), -r * math.cos(k * math.pi / 6)) for k in range(7)]
    K.b["stone"].prism(S.ccw(pts), g - 0.5, g + eave)
    ring3 = [(*p, g + eave) for p in pts]
    K.b["tile"].add(ring3 + [K.P(apse_u, 0, eave + math.tan(PITCH) * r)], [[k, k + 1, 7] for k in range(6)])
    for k in range(1, 6):
        a = k * math.pi / 6
        x, y, _ = K.P(apse_u + sgn * (r + 0.06) * math.sin(a), -(r + 0.06) * math.cos(a), 0)
        K.b["glass"].box(x, y, g + 3.0, 1.0, 0.2, eave - 5.0, ang + sgn * a)
    # ------------------------------------------------------------ crossing tower: square, belfry lancets, slate pyramid
    side = nave_w
    ct_top = ridge_m + 8.0
    K.block("stone", um - side / 2, um + side / 2, -side / 2, side / 2, eave, ct_top)
    for s in (-1, 1):
        for d in (-1.2, 1.2):
            K.lancet(True, s * side / 2, um + d, 1.0, ridge_m + 1.5, ct_top - 2.5, s)
            K.lancet(False, um + s * side / 2, d, 1.0, ridge_m + 1.5, ct_top - 2.5, s)
    for du in (-1, 1):
        for dv in (-1, 1):
            K.pinnacle(um + du * side / 2, dv * side / 2, ct_top, 3.5, 0.5)
    hs = side / 2 + 0.3
    pyr = [K.P(um - hs, -hs, ct_top), K.P(um + hs, -hs, ct_top), K.P(um + hs, hs, ct_top), K.P(um - hs, hs, ct_top),
           K.P(um, 0, ct_top + side * 0.75)]
    K.b["slate"].add(pyr, [[0, 1, 4], [1, 2, 4], [2, 3, 4], [3, 0, 4]])
    # ------------------------------------------------------------ west towers: square -> octagon -> pinnacle ring -> spire
    tower_meta = []
    ts = 7.5
    for tu, tv, top in west_towers:
        sq_top = ridge_m + 2.0
        oct_top = sq_top + 2.5                      # area r3: shorter belfry -> the slate spire is ~30 % longer (top = LiDAR)
        K.block("stone", tu - ts / 2, tu + ts / 2, tv - ts / 2, tv + ts / 2, -0.5, sq_top)
        for du in (-1, 1):                                              # angle buttresses stepping in
            for dv in (-1, 1):
                for z0_, z1_, hw_ in ((-0.3, sq_top * 0.35, 1.0), (sq_top * 0.35, sq_top * 0.7, 0.8), (sq_top * 0.7, sq_top - 0.5, 0.6)):
                    K.block("stone", tu + du * ts / 2 - hw_, tu + du * ts / 2 + hw_, tv + dv * ts / 2 - hw_, tv + dv * ts / 2 + hw_, z0_, z1_)
                    K.block("dress", tu + du * ts / 2 - hw_ - 0.04, tu + du * ts / 2 + hw_ + 0.04,    # area r5: set-off cap
                            tv + dv * ts / 2 - hw_ - 0.04, tv + dv * ts / 2 + hw_ + 0.04, z1_ - 0.12, z1_)
        K.octagon("stone", tu, tv, ts * 0.52, sq_top, oct_top)
        for s in (-1, 1):                                               # area r4: 3 louvred belfry lancets per face
            pl = s * ts * 0.505                                         # just proud of the square stage (r3 sat inside it)
            for d in (-1.6, 0.0, 1.6):
                K.lancet(True, tv + pl, tu + d, 0.85, sq_top - 4.6, sq_top - 1.5, s, key="slate")
                K.lancet(False, tu + pl, tv + d, 0.85, sq_top - 4.6, sq_top - 1.5, s, key="slate")
                for zl in (sq_top - 4.2, sq_top - 3.6, sq_top - 3.0, sq_top - 2.4):   # louvre boards
                    K.block("dress", tu + d - 0.4, tu + d + 0.4, *sorted((tv + pl, tv + pl + s * 0.1)), zl, zl + 0.08)
                    K.block("dress", *sorted((tu + pl, tu + pl + s * 0.1)), tv + d - 0.4, tv + d + 0.4, zl, zl + 0.08)
            for k in range(7):                                          # blind arcade band under the belfry
                d = -ts * 0.36 + k * ts * 0.72 / 6
                K.lancet(True, tv + pl, tu + d, 0.5, sq_top - 7.0, sq_top - 6.2, s, frame=False, key="dress")
                K.lancet(False, tu + pl, tv + d, 0.5, sq_top - 7.0, sq_top - 6.2, s, frame=False, key="dress")
        for du in (-1, 1):                                              # area r5: slender octagonal corner pinnacles
            for dv in (-1, 1):
                K.octagon("dress", tu + du * ts * 0.48, tv + dv * ts * 0.48, 0.85, sq_top - 4.0, oct_top + 1.0)   # area r6: golden sandstone (2010 photo)
                x_, y_, _ = K.P(tu + du * ts * 0.48, tv + dv * ts * 0.48, 0)
                ring_ = [(x_ + 0.95 * math.cos(ang + math.pi / 8 + k * math.pi / 4), y_ + 0.95 * math.sin(ang + math.pi / 8 + k * math.pi / 4),
                          g + oct_top + 1.0) for k in range(8)]
                K.b["dress"].add(ring_ + [(x_, y_, g + oct_top + 5.5)], [[k, (k + 1) % 8, 8] for k in range(8)])
        K.spire(tu, tv, ts * 0.45, oct_top, top)                       # area r3: broader slate base
        tower_meta.append({"uv": [round(tu, 1), round(tv, 1)], "spire_top_m": round(top, 1), "octagon_from_m": round(sq_top, 1)})
    # ------------------------------------------------------------ west front between the towers
    uw = west * (hl - 0.05)
    fw = max(nave_w, abs(west_towers[0][1] - west_towers[1][1]) - ts)
    ub0, ub1 = sorted((uw, uw - west * front))
    K.block("stone", ub0, ub1, -fw / 2, fw / 2, -0.5, eave)
    # area r1: the roof starts 0.8 m behind the front plane so the stone gable shows (was a salmon triangle)
    K.gable_roof("tile", *(sorted((ub0 + 0.8, ub1)) if west < 0 else sorted((ub0, ub1 - 0.8))), -fw / 2 - 0.3, fw / 2 + 0.3, eave)
    K.gable_end("stone", uw, -fw / 2, fw / 2, eave, eave + math.tan(PITCH) * (fw / 2 + 0.3), west)
    gr_ = eave + math.tan(PITCH) * (fw / 2 + 0.3)                       # area r4: coped gable parapet + cross
    for s_ in (-1, 1):
        K.b["dress"].beam(K.P(uw + west * 0.15, s_ * (fw / 2 + 0.3), eave + 0.2), K.P(uw + west * 0.15, 0.0, gr_ + 0.35), 0.55, 0.4)
    xg_, yg_, _ = K.P(uw + west * 0.15, 0.0, 0)
    K.b["dress"].box(xg_, yg_, g + gr_ + 0.3, 0.3, 0.3, 2.4, ang)
    K.b["dress"].box(xg_, yg_, g + gr_ + 1.9, 0.3, 1.3, 0.28, ang)
    for dv, w_, h_ in ((-fw * 0.3, 2.2, 4.4), (fw * 0.3, 2.2, 4.4)):                        # side portals, two orders
        for k in range(2):
            K.arch_frame(uw + west * (0.5 - 0.35 * k), dv, w_ + 1.2 - 0.6 * k, 0.0, h_ - 0.3 * k, 0.3, west)
        K.block("stone", *sorted((uw, uw + west * 0.5)), dv - w_ / 2 - 0.9, dv - w_ / 2 - 0.3, -0.5, h_)
        K.block("stone", *sorted((uw, uw + west * 0.5)), dv + w_ / 2 + 0.3, dv + w_ / 2 + 0.9, -0.5, h_)
        K.lancet(False, uw + west * 0.02, dv, w_, 0.0, h_ - 0.6, west, frame=False)
    # central porch (photos): projecting gabled porch, four arch orders stepping back to the doors, steps in front
    pd, pw, ph = 3.0, 7.2, 6.2
    up = uw + west * pd
    for s_ in (-1, 1):                                                  # porch side piers with gabled pinnacles
        K.block("stone", *sorted((uw, up)), s_ * pw / 2 - (0.8 if s_ > 0 else 0), s_ * pw / 2 + (0.8 if s_ < 0 else 0), -0.5, ph + 1.0)
        K.block("dress", *sorted((up - west * 0.6, up + west * 0.4)), s_ * (pw / 2 + 0.3) - 0.5, s_ * (pw / 2 + 0.3) + 0.5, -0.5, ph + 0.4)
        K.pinnacle(up, s_ * (pw / 2 + 0.3), ph + 0.4, 4.5, 0.5)
    K.block("stone", *sorted((uw, up)), -pw / 2, pw / 2, ph + 1.0, ph + 1.6)
    # area r7 (critics + 2010 photo): no gable over the porch (it read as a grey triangular hood); the photo shows a
    # flat front with a horizontal arcaded band over the portals: a level coped parapet instead
    K.block("dress", *sorted((uw, up + west * 0.15)), -pw / 2 - 0.15, pw / 2 + 0.15, ph + 1.6, ph + 1.85)
    for k in range(4):                                                  # arch orders stepping in to the doors
        K.arch_frame(up - west * (0.02 + 0.85 * k), 0.0, pw - 0.6 - 0.9 * k, 0.0, ph - 2.6 - 0.25 * k, 0.42, west)
        K.block("dress", *sorted((up - west * 0.85 * k, up - west * (0.85 * k + 0.85))), -(pw - 0.6 - 0.9 * k) / 2, -(pw - 0.6 - 0.9 * k) / 2 + 0.45, -0.5, ph - 2.6 - 0.25 * k)
        K.block("dress", *sorted((up - west * 0.85 * k, up - west * (0.85 * k + 0.85))), (pw - 0.6 - 0.9 * k) / 2 - 0.45, (pw - 0.6 - 0.9 * k) / 2, -0.5, ph - 2.6 - 0.25 * k)
    K.lancet(False, uw + west * 0.03, 0.0, 2.8, 0.0, 2.9, west, frame=False)              # dark doors at the back
    for k in range(5):                                                  # steps down to the forecourt
        K.block("dress", *sorted((up + west * 0.4 * k, up + west * 0.4 * (k + 1))), -pw / 2 - 0.8 * k, pw / 2 + 0.8 * k,
                -0.6, 0.15 * (5 - k) - 0.6)
    K.b.setdefault("rail", C.MeshBuf())                                 # area r2: black handrails down the steps
    for s_ in (-1, 1):
        for dv in (pw / 2 + 0.2, 1.2):
            p0 = K.P(up + west * 0.1, s_ * dv, 0.15 + 0.9)
            p1 = K.P(up + west * 2.0, s_ * (dv + 1.5 if dv > 2 else dv), -0.6 + 0.9)
            K.b["rail"].beam(p0, p1, 0.05)
            for t in (0.0, 0.5, 1.0):
                q = tuple(p0[i] + (p1[i] - p0[i]) * t for i in range(3))
                K.b["rail"].beam((q[0], q[1], q[2] - 0.95), q, 0.05)
    for k in range(11):                                                 # blind arcade band
        dv = -fw * 0.42 + k * fw * 0.84 / 10
        K.lancet(False, uw, dv, 0.7, 7.9, 9.0, west, frame=False, key="dress")
    for z in (7.3, 10.2):                  # string courses (area r1: the 3 full-width bars at the gable floated: gone)
        K.b["dress"].prism(S.ccw([K.xy(uw, -fw / 2), K.xy(uw + west * 0.4, -fw / 2), K.xy(uw + west * 0.4, fw / 2),
                                  K.xy(uw, fw / 2)]), g + z, g + z + 0.3)
    gw = min(7.0, fw * 0.6)
    gw_top = max(12.0, eave - 2.5)
    K.lancet(False, uw, 0.0, gw, 11.0, gw_top, west)                   # great west window, 5 lights
    for k_ in range(3):                                                 # area r6: big recessed arch, 3 orders stepping in
        # area r7 (critics): the r6 orders stood 0.15-1.05 m proud in cream and read as floating ribbons. Now carved:
        # wall stone, each order only 0.04 m further in front than the one inside it (0.12 m at most)
        K.arch_frame(uw + west * (0.04 + 0.04 * (2 - k_)), 0.0, fw * 0.86 - 1.1 * k_, 0.0, gw_top - 0.6 - 0.4 * k_, 0.55, west,
                     key="stone")
    for k in (-2, -1, 1, 2):
        x, y, _ = K.P(uw + west * 0.14, k * gw / 5, 0)
        K.b["dress"].box(x, y, g + 11.0, 0.18, 0.22, gw_top - 11.0 + 0.6 * gw, ang)
    head = gw_top + 0.05                                                # area r2: tracery in the window head
    for s_ in (-1, 1):                                                  # two sub-arches over the lights
        K.arch_frame(uw + west * 0.16, s_ * gw / 4, gw / 2 - 0.2, 11.0, head, 0.16, west)
    cz_, cr_ = head + 0.62 * gw * 0.55, gw * 0.17                       # a circle above them
    ring_ = [K.P(uw + west * 0.16, cr_ * math.cos(2 * math.pi * k / 16), cz_ + cr_ * math.sin(2 * math.pi * k / 16)) for k in range(17)]
    for p_, q_ in zip(ring_[:-1], ring_[1:]):
        K.b["dress"].beam(p_, q_, 0.16)
    n = 12                                                             # rose in the central gable
    rz, rr = eave + 2.0, 1.5
    rose = [K.P(uw + west * 0.1, rr * math.cos(2 * math.pi * k / n), rz + rr * math.sin(2 * math.pi * k / n)) for k in range(n)]
    K.b["glass"].add(rose, [list(range(n)) if west < 0 else list(range(n - 1, -1, -1))])
    for s in (-1, 1):
        K.pinnacle(uw, s * fw / 2, eave, 4.0, 0.5)
    # ------------------------------------------------------------ materials
    mats = {"stone": C.material_rgb("cathedral_tuff_ashlar", LOOK["ashlar"][0], shader="ashlar", palette=LOOK["ashlar"]),
            "dress": C.material_rgb("cathedral_sandstone", LOOK["dressing"]),
            "tile": C.material_rgb("cathedral_terracotta", LOOK["tile"]),
            "slate": C.material_rgb("cathedral_slate", LOOK["slate"]),
            "spire": C.material_rgb("cathedral_spire_slate", LOOK["spire_slate"]),
            "glass": C.material_rgb("cathedral_leadlight", LOOK["leadlight"]),
            "rail": C.material_rgb("cathedral_rail", (0.02, 0.02, 0.02))}
    objs = []
    for key, buf in K.b.items():
        ob = buf.object("cathedral_" + key, col, "roof")
        if ob:
            ob.data.materials[0] = mats[key]
            objs.append(ob.name)
    return {"module": "cathedral", "objects": objs, "ground_ahd": round(g, 2), "length_m": round(ln, 1),
            "width_m": round(wd, 1), "nave_ridge_m": round(ridge_m, 1), "nave_eave_m": round(eave, 1),
            "aisle_m": round(aisle_top, 1), "transept_u": [round(um, 1), round(tw, 1)], "west_end": west,
            "west_towers": tower_meta, "crossing_tower_top_m": round(ct_top, 1), "source": LOOK["src"],
            "note": "Heights from the LiDAR; plan proportions, bay rhythm and detail sizes from the photo notes."}
