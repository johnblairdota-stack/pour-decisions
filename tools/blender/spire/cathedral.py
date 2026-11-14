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
        x, y, zz = self.P(u, v, z)
        self.b["dress"].box(x, y, zz, 2 * r, 2 * r, h * 0.35, self.ang)
        ring = [(x + r * math.cos(self.ang + math.pi / 4 + k * math.pi / 2), y + r * math.sin(self.ang + math.pi / 4 + k * math.pi / 2),
                 zz + h * 0.35) for k in range(4)]
        self.b["dress"].add(ring + [(x, y, zz + h)], [[k, (k + 1) % 4, 4] for k in range(4)])

    def octagon(self, key, u, v, r, z0, z1):
        ring = [self.xy(u + r * math.cos(math.pi / 8 + k * math.pi / 4), v + r * math.sin(math.pi / 8 + k * math.pi / 4))
                for k in range(8)]
        self.b[key].prism(S.ccw(ring), self.g + z0, self.g + z1)

    def spire(self, u, v, r, z0, z1):
        x, y, _ = self.P(u, v, 0)
        n = 8
        a0 = self.ang + math.pi / 8
        base = [(x + r * math.cos(a0 + k * math.pi / 4), y + r * math.sin(a0 + k * math.pi / 4), self.g + z0) for k in range(n)]
        self.b["spire"].add(base + [(x, y, self.g + z1)], [[k, (k + 1) % n, n] for k in range(n)])
        for f in (0.62, 0.74, 0.86):                                    # pale stone bands near the top
            zr = z0 + (z1 - z0) * f
            rr = r * (1 - f) + 0.08
            self.b["dress"].prism([(x + rr * math.cos(a0 + k * math.pi / 4), y + rr * math.sin(a0 + k * math.pi / 4)) for k in range(n)],
                                  self.g + zr, self.g + zr + 0.35)
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
                x0 = a1 + s * 0.7
                K.block("dress", bu - 0.6, bu + 0.6, x0 - 0.7, x0 + 0.7, -0.3, aisle_top - 1.5)
                K.block("dress", bu - 0.45, bu + 0.45, x0 - 0.45, x0 + 0.45, aisle_top - 1.5, aisle_top + 1.2)
                K.pinnacle(bu, x0, aisle_top + 1.2, 3.2, 0.45)
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
        oct_top = sq_top + 6.0                      # step 7b (photos): short belfry, tall slim spire
        K.block("stone", tu - ts / 2, tu + ts / 2, tv - ts / 2, tv + ts / 2, -0.5, sq_top)
        for du in (-1, 1):                                              # angle buttresses stepping in
            for dv in (-1, 1):
                K.block("dress", tu + du * ts / 2 - 0.6, tu + du * ts / 2 + 0.6, tv + dv * ts / 2 - 0.6, tv + dv * ts / 2 + 0.6,
                        -0.3, sq_top * 0.6)
                K.block("dress", tu + du * ts / 2 - 0.4, tu + du * ts / 2 + 0.4, tv + dv * ts / 2 - 0.4, tv + dv * ts / 2 + 0.4,
                        sq_top * 0.6, sq_top - 0.5)
        K.octagon("stone", tu, tv, ts * 0.52, sq_top, oct_top)
        for s in (-1, 1):                                               # tall paired belfry lancets
            for d in (-0.7, 0.7):
                K.lancet(True, tv + s * ts * 0.48, tu + d, 0.9, sq_top + 1.2, oct_top - 2.5, s)
                K.lancet(False, tu + s * ts * 0.48, tv + d, 0.9, sq_top + 1.2, oct_top - 2.5, s)
        for du in (-1, 1):                                              # step 7b: round corner turrets with cone caps
            for dv in (-1, 1):
                K.octagon("stone", tu + du * ts * 0.48, tv + dv * ts * 0.48, 0.9, sq_top - 4.0, oct_top + 1.0)
                x_, y_, _ = K.P(tu + du * ts * 0.48, tv + dv * ts * 0.48, 0)
                ring_ = [(x_ + 1.0 * math.cos(k * math.pi / 4), y_ + 1.0 * math.sin(k * math.pi / 4), g + oct_top + 1.0) for k in range(8)]
                K.b["dress"].add(ring_ + [(x_, y_, g + oct_top + 6.0)], [[k, (k + 1) % 8, 8] for k in range(8)])
        K.spire(tu, tv, ts * 0.36, oct_top, top)
        tower_meta.append({"uv": [round(tu, 1), round(tv, 1)], "spire_top_m": round(top, 1), "octagon_from_m": round(sq_top, 1)})
    # ------------------------------------------------------------ west front between the towers
    uw = west * (hl - 0.05)
    fw = max(nave_w, abs(west_towers[0][1] - west_towers[1][1]) - ts)
    ub0, ub1 = sorted((uw, uw - west * front))
    K.block("stone", ub0, ub1, -fw / 2, fw / 2, -0.5, eave)
    K.gable_roof("tile", ub0, ub1, -fw / 2 - 0.3, fw / 2 + 0.3, eave)
    K.gable_end("stone", uw, -fw / 2, fw / 2, eave, eave + math.tan(PITCH) * (fw / 2 + 0.3), west)
    for dv, w_, h_ in ((-fw * 0.3, 2.2, 4.4), (0.0, 3.0, 5.4), (fw * 0.3, 2.2, 4.4)):           # three deep portals
        K.lancet(False, uw, dv, w_ + 1.4, 0.0, h_, west, frame=False, key="dress")
        K.lancet(False, uw + west * 0.06, dv, w_, 0.0, h_ - 0.3, west, frame=False)
    for k in range(11):                                                 # blind arcade band
        dv = -fw * 0.42 + k * fw * 0.84 / 10
        K.lancet(False, uw, dv, 0.7, 7.9, 9.0, west, frame=False, key="dress")
    for z in (7.3, 10.2, eave - 0.4, eave + 3.5, eave + 6.0):           # string courses (+ gable stripes, photos)
        K.b["dress"].prism(S.ccw([K.xy(uw, -fw / 2), K.xy(uw + west * 0.4, -fw / 2), K.xy(uw + west * 0.4, fw / 2),
                                  K.xy(uw, fw / 2)]), g + z, g + z + 0.3)
    gw = min(7.0, fw * 0.6)
    gw_top = max(12.0, eave - 2.5)
    K.lancet(False, uw, 0.0, gw, 11.0, gw_top, west)                   # great west window, 5 lights
    for k in (-2, -1, 1, 2):
        x, y, _ = K.P(uw + west * 0.14, k * gw / 5, 0)
        K.b["dress"].box(x, y, g + 11.0, 0.18, 0.22, gw_top - 11.0 + 0.6 * gw, ang)
    n = 12                                                              # rose in the central gable
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
            "glass": C.material_rgb("cathedral_leadlight", LOOK["leadlight"])}
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
