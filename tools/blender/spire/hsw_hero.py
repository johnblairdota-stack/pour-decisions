"""Howard Smith Wharves at hero quality, AS BUILT (HSW round 1, 15 Nov 2026). Called by hsw.build().

Every number is in layout.HSW (with its source); photos are in PourDecisions-sites/refs/hsw (not in git).
- terrain patch: the LiDAR ground (ground_smooth) at 1 m over HSW + its cliffs, replacing the 2 m ground
  there: paving on the strip, lawns (OSM outdoor_seating polygons), tuff on the cliff faces, scrub on the
  steep banks, ground/grass on the cliff top. Bushes scattered on the cliff faces and ledges.
- heritage sheds: gable sheds with sheet-iron roofs, open/glazed walls, decks on timber piles over the river,
  roof lettering (FELONS BREWING CO, HSW); glasshouses; Stanley (two storeys, hipped roof).
- Mr Percival's: octagonal sage-green pavilion with a lantern on a deck on piles.
- corten lift tower with dark slots, top platform, link bridge to Bowen Tce, zigzag stair beside it.
- riverwalk: concrete-topped deck on steel cantilevers + piles, balustrade and lamps where it is over water.
- ferry terminal + HSW pontoon with canopy and gangway; Wilson Outlook fence on the cliff edge.
Materials made here carry m["shader"] = sheet | tuff | boards | corten | glass_green; preview.setup_morning
calls shade() for them."""
import math
import random

import numpy as np

import layout as L
import common as C
import shapes as S

H = L.HSW


def rgbm(name, rgb, shader="render", window=None):
    return C.material_rgb("hsw_" + name, rgb, window=window, shader=shader)


def obj(buf, name, col, mat):
    ob = buf.object(name, col, "steel")
    if ob is None:
        return None
    ob.data.materials[0] = mat
    return ob.name


# ---------------------------------------------------------------- terrain patch
def in_patch(x, y):
    x0, y0, x1, y1 = H["patch_box"]
    return x0 <= x <= x1 and y0 <= y <= y1


def terrain(col):
    import prep_lidar as PL
    g = L.lidar("ground_smooth")
    X0, Y0, X1, Y1 = L.LIDAR_BOX
    x0, y0, x1, y1 = H["patch_box"]
    c0, c1 = int(x0 - X0), int(x1 - X0)
    r0, r1 = int(Y1 - y1), int(Y1 - y0)
    sub = g[r0:r1 + 1, c0:c1 + 1]
    R, Cn = sub.shape
    X, Y = np.meshgrid(X0 + np.arange(c0, c1 + 1) + 0.5, Y1 - np.arange(r0, r1 + 1) - 0.5)
    verts = np.stack([X, Y, sub], -1).reshape(-1, 3)
    idx = np.arange(R * Cn).reshape(R, Cn)
    faces = np.stack([idx[:-1, :-1], idx[1:, :-1], idx[1:, 1:], idx[:-1, 1:]], -1).reshape(-1, 4)
    gy, gx = np.gradient(sub)
    slope = np.degrees(np.arctan(np.hypot(gx, gy)))[:-1, :-1]
    zc = sub[:-1, :-1]
    # lawns + parks (grass), from OSM polygons
    o = L.osm()
    lawn = np.zeros(g.shape, bool)
    park = np.zeros(g.shape, bool)
    for w in o["ways"].values():
        t = w.get("tags", {})
        is_lawn = t.get("name") in H["lawns"]
        is_park = t.get("leisure") in ("park", "garden") or t.get("landuse") == "grass"
        if not (is_lawn or is_park):
            continue
        ring = o["line"](w)
        if len(ring) < 3:
            continue
        m_, rr, cc = PL.ring_mask(ring, L.LIDAR_BOX)
        if m_ is None:
            continue
        (lawn if is_lawn else park)[rr:rr + m_.shape[0], cc:cc + m_.shape[1]] |= m_
    lawn = lawn[r0:r1, c0:c1]
    park = park[r0:r1, c0:c1]
    cls = L.lidar("class")[r0:r1, c0:c1]
    W_ = H["waterline"]
    # round 2: the river bank under the decks sinks under the water (no pale spit / sawtooth at the waterline);
    # the riprap stretch keeps its ground and gets boulders instead
    rx0, ry0, rx1, ry1 = W_["riprap_box"]
    riprap_zone = (X >= rx0) & (X <= rx1) & (Y >= ry0) & (Y <= ry1)
    orig = sub.copy()
    sink = (sub < W_["sink_below_ahd"]) & ~riprap_zone
    lawn_v = np.zeros(sub.shape, bool)
    lawn_v[:-1, :-1] = lawn
    sink &= ~lawn_v
    verts[:, 2] = np.where(sink.ravel(), np.minimum(verts[:, 2], W_["sink_to_ahd"]), verts[:, 2])
    zz = verts[:, 2].reshape(R, Cn)
    zc2 = np.minimum.reduce([zz[:-1, :-1], zz[1:, :-1], zz[1:, 1:], zz[:-1, 1:]])   # lowest corner of each face
    mi = np.zeros(zc.shape, "i4")                                   # 0 paving (warm pale decomposed granite)
    mi[(zc > 16.0) & (slope < H["scrub_slope_deg"])] = 4            # cliff top: ground
    mi[(park | lawn) & (slope < H["scrub_slope_deg"]) & (cls != 3)] = 3
    mi[lawn] = 3
    mi[(slope >= H["scrub_slope_deg"]) & (slope < H["rock_slope_deg"])] = 2
    mi[slope >= H["rock_slope_deg"]] = 1
    mi[(zc < 3.2) & (slope >= H["scrub_slope_deg"])] = 5            # river bank under the decks: dark mud/rock
    mi[zc2 < 2.6] = 5
    mi[zc2 < 0.0] = 5                                                # river bed
    ob = C.mesh_fast("hsw_terrain_1m", verts, faces, col, "footway")
    ob.data.materials[0] = rgbm("paving_dg", H["ground"]["paving"], "dg")
    ob.data.materials.append(rgbm("tuff", H["cliff"]["tuff"][1], "tuff"))
    ob.data.materials.append(rgbm("scrub_bank", (0.10, 0.10, 0.05), "dg"))
    ob.data.materials.append(C.material("grass"))
    ob.data.materials.append(rgbm("clifftop_litter", (0.085, 0.09, 0.045), "dg"))
    ob.data.materials.append(rgbm("bank", (0.06, 0.05, 0.04)))
    ob.data.polygons.foreach_set("material_index", mi.ravel())
    ob.data.shade_smooth()
    names = [ob.name]
    meta = {"terrain_faces": int(len(faces)), "sunk_cells": int(sink.sum())}
    n2, m2 = cliff_dress(col, X, Y, sub, slope, zc, orig, riprap_zone)
    names += n2
    meta.update(m2)
    return names, meta


def cliff_dress(col, X, Y, sub, slope, zc, orig, riprap_zone):
    """Round 2 cliff: jutting tuff slabs (overhangs, fractured faces), a ragged rim of blocks, leaf-card tufts
    on the ledges only, figs and vines hanging off the rim, riprap boulders at the Rivershed point."""
    import foliage as FO
    Cl = H["cliff"]
    T = H["trees"]
    rnd = random.Random(Cl["seed"])
    rock = C.MeshBuf()
    gy, gx = np.gradient(sub)
    gy, gx = -gy[:-1, :-1], gx[:-1, :-1]                     # rows run south: +y uphill is -d/drow
    steep = slope >= H["rock_slope_deg"]
    rr, cc = np.nonzero(steep & (zc > 4.0))
    order = list(range(len(rr)))
    rnd.shuffle(order)
    nslab = 0
    for i in order[:Cl["slabs"]]:
        r, c = rr[i], cc[i]
        ux, uy = -gx[r, c], -gy[r, c]                         # downhill = out of the face
        ln = math.hypot(ux, uy) or 1.0
        ux, uy = ux / ln, uy / ln
        z = float(zc[r, c])
        w, d, h = rnd.uniform(1.2, 4.0), rnd.uniform(0.6, 1.8), rnd.uniform(1.5, 4.0)
        out = rnd.uniform(-0.3, 0.5)
        rock.box(X[r, c] + ux * out, Y[r, c] + uy * out, z - h * rnd.uniform(0.2, 0.6), w, d, h,
                 math.atan2(uy, ux) + math.pi / 2 + rnd.uniform(-0.35, 0.35))
        nslab += 1
    # ragged rim: rock cells with flat cliff-top ground just uphill
    flat_top = (slope < 22) & (zc > 14.0)
    near_top = np.zeros_like(flat_top)
    for dr in (-2, -1, 0, 1, 2):
        for dc in (-2, -1, 0, 1, 2):
            near_top |= np.roll(np.roll(flat_top, dr, 0), dc, 1)
    rim = steep & near_top & (zc > 12.0)
    rr, cc = np.nonzero(rim)
    order = list(range(len(rr)))
    rnd.shuffle(order)
    nrim = 0
    rim_pts = []
    for i in order:
        r, c = rr[i], cc[i]
        ux, uy = -gx[r, c], -gy[r, c]
        ln = math.hypot(ux, uy) or 1.0
        ux, uy = ux / ln, uy / ln
        rim_pts.append((float(X[r, c]), float(Y[r, c]), float(zc[r, c]), ux, uy))
        if nrim < Cl["rim_rocks"]:
            s = rnd.uniform(0.6, 1.6)
            rock.box(X[r, c] + ux * 0.5, Y[r, c] + uy * 0.5, zc[r, c] - s * 1.1, s * rnd.uniform(1.0, 1.8), s, s * rnd.uniform(0.8, 1.4),
                     rnd.uniform(0, math.pi))
            nrim += 1
    # riprap boulders along the Rivershed point (photo p06: dark rock armour at the waterline)
    rip = C.MeshBuf()
    nrip = 0
    z0r, z1r = H["waterline"]["riprap_z"]
    st = H["waterline"]["riprap_every_m"]
    rr, cc = np.nonzero(riprap_zone[:-1, :-1] & (orig[:-1, :-1] > z0r) & (orig[:-1, :-1] < z1r))
    for r, c in zip(rr, cc):
        if (r + c) % max(1, int(st)) or rnd.random() < 0.3:
            continue
        s = rnd.uniform(0.5, 1.3)
        blob(rip, X[r, c] + rnd.uniform(-.5, .5), Y[r, c] + rnd.uniform(-.5, .5), float(orig[r, c]) + s * 0.2, s, s * 0.6, rnd, 6, 3)
        nrip += 1
    # vegetation: leaf-card tufts on the ledges only (bare faces stay bare); hanging figs and vines off the rim
    leaves = FO.Foliage(seed=Cl["seed"])
    vines = FO.Foliage(seed=Cl["seed"] + 1)
    ledge = (slope >= H["scrub_slope_deg"] - 4) & (slope < H["rock_slope_deg"] + 4) & (zc > 5.0) & (zc < 36.0)
    rr, cc = np.nonzero(ledge)
    order = list(range(len(rr)))
    rnd.shuffle(order)
    nt = 0
    for i in order[:Cl["shrubs"]]:
        r, c = rr[i], cc[i]
        rad = rnd.uniform(0.6, 1.8)
        leaves.cloud((X[r, c], Y[r, c], zc[r, c] + rad * 0.4), (rad, rad, rad * 0.6), int(30 + 25 * rad * rad), 0.35,
                     shell=0.3, top_bias=0.4)
        nt += 1
    nh = 0
    last = []
    lo, hi = T["hanging_len_m"]
    for x, y, z, ux, uy in rim_pts:
        if any(math.hypot(x - a, y - b) < T["hanging_every_m"] for a, b in last):
            continue
        if rnd.random() < 0.35:
            continue
        last.append((x, y))
        ln = rnd.uniform(lo, hi)
        k = rnd.randint(5, 12)
        pts = [(x + ux * 0.6 + rnd.uniform(-2.5, 2.5) * -uy, y + uy * 0.6 + rnd.uniform(-2.5, 2.5) * ux, z + rnd.uniform(-0.5, 0.8))
               for _ in range(k)]
        vines.strands(pts, (ux, uy, 0.0), ln, 0.5, 0.75)
        if rnd.random() < 0.5:                                   # a fig spilling over the edge
            rr_ = rnd.uniform(2.5, 4.5)
            leaves.cloud((x + ux * 1.5, y + uy * 1.5, z - rr_ * 0.6), (rr_, rr_, rr_ * 1.2), int(9 * (40 + 6 * rr_ * rr_)), 0.5,
                         shell=0.25, top_bias=0.2)
        nh += 1
    names = [obj(rock, "hsw_cliff_slabs", col, rgbm("tuff", H["cliff"]["tuff"][1], "tuff")),
             obj(rip, "hsw_riprap", col, rgbm("riprap", (0.10, 0.09, 0.085), "tuff_dark"))]
    for fo, nm, a, b in ((leaves, "hsw_cliff_scrub", (0.05, 0.10, 0.035), (0.13, 0.20, 0.07)),
                         (vines, "hsw_cliff_vines", (0.045, 0.095, 0.03), (0.11, 0.19, 0.06))):
        o_ = fo.object(nm, col, a, b)
        if o_:
            names.append(o_.name)
    return [n for n in names if n], {"cliff_slabs": nslab, "rim_rocks": nrim, "riprap": nrip, "cliff_tufts": nt,
                                     "hanging_vines": nh}


def blob(buf, x, y, z, r, rz, rnd, nu=7, nv=4):
    verts = [(x, y, z + rz)]
    for j in range(1, nv):
        th = math.pi * j / nv
        for i in range(nu):
            ph = 2 * math.pi * i / nu + j * 0.4
            k = rnd.uniform(0.8, 1.15)
            verts.append((x + r * k * math.sin(th) * math.cos(ph), y + r * k * math.sin(th) * math.sin(ph),
                          z + rz * math.cos(th)))
    verts.append((x, y, z - rz))
    faces = [[0, 1 + (i + 1) % nu, 1 + i] for i in range(nu)]
    for j in range(nv - 2):
        a, b = 1 + j * nu, 1 + (j + 1) * nu
        faces += [[a + i, a + (i + 1) % nu, b + (i + 1) % nu, b + i] for i in range(nu)]
    last = 1 + (nv - 2) * nu
    bot = len(verts) - 1
    faces += [[last + i, last + (i + 1) % nu, bot] for i in range(nu)]
    buf.add(verts, faces)


# ---------------------------------------------------------------- sheds
SHED_STYLES = {   # wall, roof, glass, walls glazed fraction, deck
    "felons":     {"wall": (0.78, 0.76, 0.70), "roof": (0.72, 0.73, 0.73), "glass": (0.03, 0.035, 0.04), "bay": 4.0, "win": 3.75, "sill": 0.03, "head": 0.95},   # r2: mostly open glass
    "white_shed": {"wall": (0.80, 0.78, 0.72), "roof": (0.70, 0.71, 0.71), "glass": (0.03, 0.035, 0.04), "bay": 4.5, "win": 4.1, "sill": 0.04, "head": 0.93},
    "barrel_hall": {"wall": (0.20, 0.21, 0.21), "roof": (0.13, 0.14, 0.145), "glass": (0.06, 0.07, 0.075), "bay": 3.0, "win": 2.8, "sill": 0.05, "head": 0.75},
    "cream_shed": {"wall": (0.74, 0.69, 0.58), "roof": (0.48, 0.50, 0.50), "glass": (0.06, 0.07, 0.07), "bay": 3.5, "win": 2.2, "sill": 0.2, "head": 0.8},
    "glasshouse": {"wall": (0.30, 0.36, 0.34), "roof": (0.62, 0.64, 0.64), "glass": (0.12, 0.16, 0.15), "bay": 2.0, "win": 1.85, "sill": 0.04, "head": 0.95},
    "stanley":    {"wall": (0.76, 0.70, 0.58), "roof": (0.36, 0.38, 0.39), "glass": (0.05, 0.06, 0.07), "bay": 3.2, "win": 1.3, "sill": 0.3, "head": 0.82},
}


def rec_by_osm():
    import json
    import os
    return {b["osm"]: b for b in json.load(open(os.path.join(L.REF, "lidar", "buildings_clean.json")))["buildings"]}


def shed_geometry(sh, rec):
    """(cx, cy, length, width, angle, base, eave, ridge) from the LiDAR gable fit or the footprint."""
    if rec.get("gable"):
        g = rec["gable"]
        return g["cx"], g["cy"], g["length"], g["width"], g["angle"], rec["base_ahd"], g["eave_ahd"], g["ridge_ahd"]
    tiers = rec["tiers"]
    ring = max(tiers, key=lambda t: abs(S.area(t["ring"])))["ring"]
    cx, cy, ln, wd, ang = S.min_rect([tuple(p) for p in ring])
    lo = min(t["top_ahd"] for t in tiers)
    hi = max(t["top_ahd"] for t in tiers)
    if hi - lo < 1.5:
        lo = hi - 0.22 * wd
    return cx, cy, ln, wd, ang, rec["base_ahd"], lo, hi


def sheds(col):
    recs = rec_by_osm()
    walls, roofs, decks, piles, frames = {}, {}, C.MeshBuf(), C.MeshBuf(), C.MeshBuf()
    out, letters = [], []
    for sh in H["sheds"]:
        rec = recs.get(sh["osm"])
        if rec is None:
            continue
        st = SHED_STYLES[sh["style"]]
        cx, cy, ln, wd, ang, base, eave, ridge = shed_geometry(sh, rec)
        base = max(base, 3.2) if sh["style"] not in ("barrel_hall",) else max(base, 3.0)
        if eave - base < 3.0:
            eave = base + 3.5
            ridge = max(ridge, eave + 0.2 * wd)
        c, s = math.cos(ang), math.sin(ang)
        Pt = lambda u, v, z: (cx + u * c - v * s, cy + u * s + v * c, z)
        # which long side faces the river (lower ground further out)
        gp = L.ground_z(*Pt(0, wd / 2 + 6, 0)[:2])
        gm = L.ground_z(*Pt(0, -wd / 2 - 6, 0)[:2])
        rside = 1 if gp < gm else -1
        wb = walls.setdefault(sh["style"], C.MeshBuf())
        rb = roofs.setdefault(sh["style"], C.MeshBuf())
        ring = [Pt(-ln / 2, -wd / 2, 0)[:2], Pt(ln / 2, -wd / 2, 0)[:2], Pt(ln / 2, wd / 2, 0)[:2], Pt(-ln / 2, wd / 2, 0)[:2]]
        if sh["style"] == "stanley":
            wb.prism(ring, base - 0.5, eave if eave - base > 6 else base + 8.0)
            import buildings as B
            B.hipped(rb, ring, eave if eave - base > 6 else base + 8.0, 24.0)
            frames.prism([Pt(u, v, 0)[:2] for u, v in ((-ln / 2 - .25, -wd / 2 - .25), (ln / 2 + .25, -wd / 2 - .25),
                                                       (ln / 2 + .25, wd / 2 + .25), (-ln / 2 - .25, wd / 2 + .25))],
                         base + 3.9, base + 4.3)                     # string course between the storeys
        elif sh["style"] == "barrel_hall":
            # saw-tooth: a row of small gables with ridges ACROSS the shed, glazed gable ends to the river
            # (photo overview_aerial/pg_034f3524: 9 gables, dark sheet roof, glass walls on steel frames)
            wb.prism(ring, base - 0.3, eave)
            k = max(3, int(round(ln / 7.8)))
            bw_ = ln / k
            o = 0.6
            for i in range(k):
                u0, u1 = -ln / 2 + i * bw_, -ln / 2 + (i + 1) * bw_
                um = (u0 + u1) / 2
                for sv in (-1, 1):
                    wb.add([Pt(u0, sv * wd / 2, eave), Pt(u1, sv * wd / 2, eave), Pt(um, sv * wd / 2, ridge)],
                           [[0, 1, 2] if sv < 0 else [2, 1, 0]])
                for a_, b_ in ((u0, um), (u1, um)):
                    q = [Pt(a_, -wd / 2 - o, eave), Pt(a_, wd / 2 + o, eave), Pt(b_, wd / 2 + o, ridge), Pt(b_, -wd / 2 - o, ridge)]
                    f = [0, 1, 2, 3] if a_ > b_ else [3, 2, 1, 0]
                    rb.add(q + [(p[0], p[1], p[2] - 0.15) for p in q], [f, [4 + j for j in f[::-1]]])
                frames.beam(Pt(um, -wd / 2 - o, ridge + 0.05), Pt(um, wd / 2 + o, ridge + 0.05), 0.2)
                for sv in (-1, 1):                                   # raking steel struts on the glass ends
                    frames.beam(Pt(um, sv * (wd / 2 + 0.1), base), Pt(um, sv * (wd / 2 + 0.1), ridge), 0.18)
                    frames.beam(Pt(u0, sv * (wd / 2 + 0.1), base), Pt(um - bw_ * 0.25, sv * (wd / 2 + 0.1), eave), 0.14)
        else:
            wb.prism(ring, base - 0.3, eave)
            for su in (-1, 1):                                       # gable end triangles
                u = su * ln / 2
                wb.add([Pt(u, -wd / 2, eave), Pt(u, wd / 2, eave), Pt(u, 0, ridge)], [[0, 1, 2] if su > 0 else [2, 1, 0]])
            o = 0.8
            ze = eave - o * (ridge - eave) / (wd / 2)
            for sv in (-1, 1):                                       # two roof planes with thickness
                a, b = Pt(-ln / 2 - o, sv * (wd / 2 + o), ze), Pt(ln / 2 + o, sv * (wd / 2 + o), ze)
                cc_, dd = Pt(ln / 2 + o, 0, ridge), Pt(-ln / 2 - o, 0, ridge)
                q = [a, b, cc_, dd]
                ql = [(p[0], p[1], p[2] - 0.18) for p in q]
                L_ = ln + 2 * o
                sl = math.hypot(wd / 2 + o, ridge - ze)
                uv = [(0, 0), (L_, 0), (L_, sl), (0, sl)]
                f_top = [0, 1, 2, 3] if sv < 0 else [3, 2, 1, 0]
                rb.add(q + ql, [f_top, [4 + i for i in f_top[::-1]], [0, 4, 5, 1], [2, 6, 7, 3]],
                       [[uv[i] for i in f_top], [uv[i] for i in f_top[::-1]], [(0, 0), (0, .2), (L_, .2), (L_, 0)],
                        [(L_, sl), (L_, sl - .2), (0, sl - .2), (0, sl)]])
            for su in (-1, 1):                                       # barge boards / fascia
                frames.beam(Pt(su * (ln / 2 + o), -wd / 2 - o, ze), Pt(su * (ln / 2 + o), 0, ridge + 0.05), 0.3, 0.35)
                frames.beam(Pt(su * (ln / 2 + o), wd / 2 + o, ze), Pt(su * (ln / 2 + o), 0, ridge + 0.05), 0.3, 0.35)
            frames.beam(Pt(-ln / 2 - o, -wd / 2 - o, ze), Pt(ln / 2 + o, -wd / 2 - o, ze), 0.25, 0.3)
            frames.beam(Pt(-ln / 2 - o, wd / 2 + o, ze), Pt(ln / 2 + o, wd / 2 + o, ze), 0.25, 0.3)
            if sh["style"] in ("felons", "white_shed", "barrel_hall"):   # roof vents along the ridge
                k = int(ln // 9)
                for i in range(k):
                    u = -ln / 2 + (i + 0.5) * ln / k
                    x, y, _ = Pt(u, 0, 0)
                    rb.box(x, y, ridge - 0.1, 1.6, 1.6, 0.9, ang)
            if sh.get("letters"):
                th = math.atan2(ridge - ze, wd / 2 + o)
                head = ang if rside < 0 else ang + math.pi
                x, y, z = Pt(0, rside * (wd / 2 + o) * 0.48, 0)
                zz = ze + (ridge - ze) * 0.52 + 0.12
                # round 2: bigger, bolder, spaced letters (photo p09: they fill ~60 % of the roof slope)
                size = min(0.66 * math.hypot(wd / 2 + o, ridge - ze), 1.55 * (ln + 2 * o) / max(4, len(sh["letters"])))
                tob = C.text_obj(col, "hsw_roof_letters_%d" % sh["osm"], sh["letters"], (x, y, zz),
                                 (th, 0.0, head), size, (0.035, 0.035, 0.04))
                try:
                    import bpy
                    import os
                    fp = os.path.join(L.HERE, "..", "..", "..", "fonts", "Barlow-SemiBold.ttf")
                    tob.data.font = bpy.data.fonts.load(os.path.abspath(fp), check_existing=True)
                    tob.data.space_character = 1.35
                    tob.data.offset = 0.02
                except Exception as e:                       # font missing: Blender's default font
                    print("roof letters font:", e)
                letters.append(tob.name)
        # deck on piles: on the river side (and a 1.5 m apron round over-water sheds)
        dr = sh.get("deck_river_m", 0.0)
        if dr > 0:
            v0, v1 = (wd / 2, wd / 2 + dr) if rside > 0 else (-wd / 2 - dr, -wd / 2)
            dz = base + 0.05
            ringd = [Pt(-ln / 2 - 1.5, v0 - (1.5 if rside < 0 else 0), 0)[:2], Pt(ln / 2 + 1.5, v0 - (1.5 if rside < 0 else 0), 0)[:2],
                     Pt(ln / 2 + 1.5, v1 + (1.5 if rside > 0 else 0), 0)[:2], Pt(-ln / 2 - 1.5, v1 + (1.5 if rside > 0 else 0), 0)[:2]]
            decks.prism(ringd, dz - 0.35, dz)
            vo = v1 + 1.5 if rside > 0 else v0 - 1.5
            u = -ln / 2 - 1.5
            while u <= ln / 2 + 1.6:
                for v in (vo - rside * 0.2, (v0 + v1) / 2):
                    x, y, _ = Pt(u, v, 0)
                    if L.ground_z(x, y) < dz - 1.0:
                        piles.box(x, y, -3.0, 0.45, 0.45, dz - 0.35 + 3.0)
                x, y, _ = Pt(u, vo - rside * 0.1, 0)
                frames.beam((x, y, dz), (x, y, dz + 1.1), 0.08)          # balustrade post
                u += 2.0
            frames.beam(Pt(-ln / 2 - 1.5, vo - rside * 0.1, dz + 1.1), Pt(ln / 2 + 1.5, vo - rside * 0.1, dz + 1.1), 0.08)
            frames.beam(Pt(-ln / 2 - 1.5, vo - rside * 0.1, dz + 0.55), Pt(ln / 2 + 1.5, vo - rside * 0.1, dz + 0.55), 0.04)
            # verandah roof over the river-side deck on posts (Felons: deep verandah)
            if sh["style"] in ("felons", "white_shed"):
                for u in np.arange(-ln / 2, ln / 2 + 0.1, 4.0):
                    x, y, _ = Pt(u, vo - rside * 0.6, 0)
                    frames.beam((x, y, dz), (x, y, eave - 0.6), 0.18)
                hi_, lo_ = Pt(0, rside * wd / 2, eave - 0.3), Pt(0, vo, eave - 0.9)
                q = [Pt(-ln / 2 - 0.5, rside * wd / 2, eave - 0.3), Pt(ln / 2 + 0.5, rside * wd / 2, eave - 0.3),
                     Pt(ln / 2 + 0.5, vo, eave - 0.9), Pt(-ln / 2 - 0.5, vo, eave - 0.9)]
                rb.add(q + [(p[0], p[1], p[2] - 0.15) for p in q],
                       [[0, 1, 2, 3] if rside < 0 else [3, 2, 1, 0], [7, 6, 5, 4] if rside < 0 else [4, 5, 6, 7]])
    for style, buf in walls.items():
        st = SHED_STYLES[style]
        win = {"bay": st["bay"], "win": st["win"], "sill": st["sill"], "head": st["head"], "glass": st["glass"],
               "rough": 0.1, "floor": 4.6 if style == "stanley" else 30.0}
        if style != "stanley":
            win["floor"] = 7.0
        out.append(obj(buf, "hsw_shed_walls_" + style, col, rgbm("shed_wall_" + style, st["wall"], "render", win)))
    for style, buf in roofs.items():
        out.append(obj(buf, "hsw_shed_roof_" + style, col, rgbm("shed_roof_" + style, SHED_STYLES[style]["roof"], "sheet")))
    out.append(obj(decks, "hsw_shed_decks", col, rgbm("deck_boards", (0.36, 0.27, 0.19), "boards")))
    out.append(obj(piles, "hsw_shed_piles", col, rgbm("piles", H["waterline"]["pile_rgb"])))
    out.append(obj(frames, "hsw_shed_frames", col, rgbm("frames", (0.12, 0.12, 0.12))))
    return [n for n in out + letters if n]


# ---------------------------------------------------------------- Mr Percival's
def percivals(col):
    P = H["percivals"]
    cx, cy = P["centre_xy"]
    r = P["radius_m"]
    dz = P["deck_ahd"]
    wall, roof, deck, pile, lan, rail = (C.MeshBuf() for _ in range(6))
    dl, dw = P["deck_size_m"]
    a = math.radians(P["deck_angle_deg"])
    deck.box(cx, cy, dz - 0.4, dl, dw, 0.4, a)
    ca, sa = math.cos(a), math.sin(a)
    for i in range(int(dl // 3.5) + 1):
        for j in range(int(dw // 3.5) + 1):
            u, v = -dl / 2 + i * dl / int(dl // 3.5), -dw / 2 + j * dw / int(dw // 3.5)
            x, y = cx + u * ca - v * sa, cy + u * sa + v * ca
            if L.ground_z(x, y) < dz - 1.0:
                pile.box(x, y, -3.5, 0.5, 0.5, dz - 0.4 + 3.5)
    corners = [(-dl / 2, -dw / 2), (dl / 2, -dw / 2), (dl / 2, dw / 2), (-dl / 2, dw / 2)]
    for k in range(4):                                               # deck balustrade
        (u0, v0), (u1, v1) = corners[k], corners[(k + 1) % 4]
        p0 = (cx + u0 * ca - v0 * sa, cy + u0 * sa + v0 * ca)
        p1 = (cx + u1 * ca - v1 * sa, cy + u1 * sa + v1 * ca)
        rail.beam((*p0, dz + 1.1), (*p1, dz + 1.1), 0.08)
        nposts = int(math.dist(p0, p1) // 2)
        for t in range(nposts + 1):
            q = (p0[0] + (p1[0] - p0[0]) * t / nposts, p0[1] + (p1[1] - p0[1]) * t / nposts)
            rail.beam((*q, dz), (*q, dz + 1.1), 0.06)
    oct_ = [(cx + r * math.cos(math.pi / 8 + k * math.pi / 4), cy + r * math.sin(math.pi / 8 + k * math.pi / 4)) for k in range(8)]
    wall.prism(oct_, dz, P["wall_top_ahd"])
    # roof: octagonal pyramid with eaves to the lantern ring, lantern drum, small cap
    ro = r + 1.2
    rl = P["lantern_r"]
    zl = P["roof_top_ahd"] - 2.2
    ze = P["wall_top_ahd"] - 0.3
    outer = [(cx + ro * math.cos(math.pi / 8 + k * math.pi / 4), cy + ro * math.sin(math.pi / 8 + k * math.pi / 4), ze) for k in range(8)]
    inner = [(cx + rl * math.cos(math.pi / 8 + k * math.pi / 4), cy + rl * math.sin(math.pi / 8 + k * math.pi / 4), zl) for k in range(8)]
    roof.add(outer + inner, [[k, (k + 1) % 8, 8 + (k + 1) % 8, 8 + k] for k in range(8)] + [list(range(7, -1, -1))])
    lan.prism([p[:2] for p in inner], zl, zl + 1.2)
    top = [(cx + (rl + 0.5) * math.cos(math.pi / 8 + k * math.pi / 4), cy + (rl + 0.5) * math.sin(math.pi / 8 + k * math.pi / 4), zl + 1.2) for k in range(8)]
    roof.add(top + [(cx, cy, P["roof_top_ahd"])], [[k, (k + 1) % 8, 8] for k in range(8)] + [list(range(7, -1, -1))])
    # front gable porch on the side facing the river (south)
    wall.box(cx, cy - r - 1.0, dz, 4.4, 2.6, 3.4)
    roof.add([(cx - 2.8, cy - r - 2.6, dz + 3.4), (cx + 2.8, cy - r - 2.6, dz + 3.4), (cx, cy - r - 2.6, dz + 5.2),
              (cx - 2.8, cy - r + 0.5, dz + 3.4), (cx + 2.8, cy - r + 0.5, dz + 3.4), (cx, cy - r + 0.5, dz + 5.2)],
             [[0, 2, 5, 3], [2, 1, 4, 5], [0, 1, 2]])
    win = {"bay": 2.9, "win": 1.5, "sill": 0.12, "head": 0.78, "glass": (0.05, 0.06, 0.06), "rough": 0.1, "floor": 5.0}
    out = [obj(wall, "mr_percivals_walls", col, rgbm("percivals_wall", P["wall"], "render", win)),
           obj(roof, "mr_percivals_roof", col, rgbm("percivals_roof", P["roof"], "sheet")),
           obj(lan, "mr_percivals_lantern", col, rgbm("glass_dark", (0.05, 0.065, 0.07), "glass_green")),
           obj(deck, "mr_percivals_deck", col, rgbm("deck_boards", (0.36, 0.27, 0.19), "boards")),
           obj(pile, "mr_percivals_piles", col, rgbm("piles", H["waterline"]["pile_rgb"])),
           obj(rail, "mr_percivals_rail", col, rgbm("frames", (0.12, 0.12, 0.12)))]
    return [n for n in out if n]


# ---------------------------------------------------------------- lift tower + stairs
def lift_tower(col):
    T = H["lift_tower"]
    x, y = T["xy"]
    sx, sy = H["lift_tower_r2"]["size_m"]
    g = L.ground_z(x, y)
    cor, glass, steel = C.MeshBuf(), C.MeshBuf(), C.MeshBuf()
    cor.box(x, y, g - 0.3, sx, sy, T["top_ahd"] - g)
    for fx, fy, rot in ((0, -1, 0.0), (0, 1, 0.0), (-1, 0, math.pi / 2), (1, 0, math.pi / 2)):   # dark slots
        for off in (-1.2, 0.0, 1.2):
            px = x + fx * (sx / 2 + 0.03) + (off if fy else 0.0)
            py = y + fy * (sy / 2 + 0.03) + (off if fx else 0.0)
            glass.box(px, py, g + 1.0, 0.35 if fy else 0.08, 0.08 if fy else 0.35, T["top_ahd"] - g - 3.0)
    cx, cy = T["cliff_top_xy"]
    gt = L.ground_z(cx, cy)
    zl = T["link_ahd"]
    cor.box(x, y, T["top_ahd"], sx + 1.4, sy + 1.4, 0.5)                           # cap
    steel.box(x, (y + cy) / 2 + sy / 4, zl - 0.5, 2.6, abs(cy - y) - sy / 2, 0.5)   # link bridge deck
    for sxx in (-1.3, 1.3):
        steel.beam((x + sxx, y + sy / 2, zl + 1.1), (x + sxx, cy, zl + 1.1), 0.08)
        steel.beam((x + sxx, y + sy / 2, zl - 0.5), (x + sxx, cy, zl - 0.5), 0.3, 0.5)
    glass.box(x - sx / 2 - 1.6, y, zl - 0.2, 3.2, sy + 2.0, 0.3)                 # top viewing platform
    # zigzag stair beside the tower (east side), flights of 3.6 m rise
    stx = x + sx / 2 + 2.6
    z = g
    k = 0
    while z < zl - 0.5:
        z2 = min(z + 3.6, zl)
        y0, y1 = (y - 2.5, y + 2.5) if k % 2 == 0 else (y + 2.5, y - 2.5)
        off = -0.8 if k % 2 == 0 else 0.8
        steel.beam((stx + off, y0, z), (stx + off, y1, z2), 1.4, 0.25)
        steel.box(stx, y1 + (0.9 if k % 2 == 0 else -0.9), z2 - 0.2, 3.2, 1.8, 0.2)
        z, k = z2, k + 1
    for px in (stx - 1.7, stx + 1.7):
        for py in (y - 3.5, y + 3.5):
            steel.beam((px, py, g), (px, py, zl + 1.1), 0.18)
    return [n for n in (obj(cor, "hsw_lift_tower_corten", col, rgbm("corten_oxide", H["lift_tower_r2"]["rgb"], "corten")),
                        obj(glass, "hsw_lift_tower_slots", col, rgbm("glass_dark", (0.05, 0.065, 0.07), "glass_green")),
                        obj(steel, "hsw_lift_tower_steel", col, rgbm("corten_dark", (0.20, 0.09, 0.05), "corten"))) if n]


# ---------------------------------------------------------------- riverwalk
def riverwalk(col):
    R = H["riverwalk"]
    o = L.osm()
    x0, y0, x1, y1 = H["patch_box"]
    deck, steel, rail, lamp = C.MeshBuf(), C.MeshBuf(), C.MeshBuf(), C.MeshBuf()
    piles, fas = C.MeshBuf(), C.MeshBuf()
    walks = 0
    for wid, w in o["ways"].items():
        t = w.get("tags", {})
        if t.get("highway") not in ("footway", "cycleway", "living_street", "path", "pedestrian"):
            continue
        pts = o["line"](w)
        if len(pts) < 2 or not any(x0 <= x <= x1 and y0 <= y <= y1 for x, y in pts):
            continue
        if not [p for p in pts if L.ground_z(*p) < 2.5] and "Riverwalk" not in t.get("name", ""):
            continue
        pts = C.densify(pts, 2.0)
        hw = R["width_m"] / 2
        left, right = C.offset_line(pts, hw), C.offset_line(pts, -hw)
        z = [max(R["deck_ahd"], L.ground_z(*p) + 0.12) for p in pts]
        n = len(pts)
        verts = ([(x, y, zz) for (x, y), zz in zip(left, z)] + [(x, y, zz) for (x, y), zz in zip(right, z)] +
                 [(x, y, zz - 0.4) for (x, y), zz in zip(left, z)] + [(x, y, zz - 0.4) for (x, y), zz in zip(right, z)])
        faces = [[i, n + i, n + i + 1, i + 1] for i in range(n - 1)]
        faces += [[2 * n + i + 1, 3 * n + i + 1, 3 * n + i, 2 * n + i] for i in range(n - 1)]
        faces += [[i, i + 1, 2 * n + i + 1, 2 * n + i] for i in range(n - 1)]
        faces += [[n + i + 1, n + i, 3 * n + i, 3 * n + i + 1] for i in range(n - 1)]
        deck.add(verts, faces)
        acc, lacc, pacc = 0.0, 0.0, 0.0
        prev_out = None
        prev_pile = None
        Wl = H["waterline"]
        for i in range(1, n):
            dd = math.dist(pts[i - 1], pts[i])
            acc += dd
            lacc += dd
            pacc += dd
            gl, gr = L.ground_z(*left[i]), L.ground_z(*right[i])
            wet = min(gl, gr) < Wl["sink_below_ahd"] + 0.6
            out = left[i] if gl < gr else right[i]
            inn = right[i] if gl < gr else left[i]
            if wet:                                              # round 2: dark timber pile colonnade (photo p09)
                ox, oy = out[0] * 0.92 + inn[0] * 0.08, out[1] * 0.92 + inn[1] * 0.08
                if prev_out is not None and math.dist(prev_out[:2], out) < 4.0:
                    fas.beam((*prev_out[:2], prev_out[2] - 0.25), (*out, z[i] - 0.25), 0.3, 0.7)
                if pacc >= Wl["pile_every_m"]:
                    pacc = 0.0
                    pw = Wl["pile_w_m"]
                    piles.beam((ox, oy, z[i] - 0.4), (ox, oy, -2.5), pw)
                    mx, my = (inn[0] + out[0]) / 2, (inn[1] + out[1]) / 2
                    piles.beam((mx, my, z[i] - 0.4), (mx, my, -2.5), pw)
                    piles.beam((ox, oy, z[i] - 0.7), (mx, my, z[i] - 0.7), 0.3, 0.5)          # headstock
                    if prev_pile and math.dist(prev_pile[:2], (ox, oy)) < 4.0:   # X bracing between piles
                        piles.beam((*prev_pile[:2], z[i] - 0.8), (ox, oy, 0.6), 0.14)
                        piles.beam((*prev_pile[:2], 0.6), (ox, oy, z[i] - 0.8), 0.14)
                    prev_pile = (ox, oy)
            else:
                prev_pile = None
            if wet:
                rail.beam((*out, z[i]), (*out, z[i] + R["rail_m"]), 0.07)
                if prev_out is not None and math.dist(prev_out[:2], out) < 4.0:
                    rail.beam((*prev_out[:2], prev_out[2] + R["rail_m"]), (*out, z[i] + R["rail_m"]), 0.07)
                    rail.beam((*prev_out[:2], prev_out[2] + 0.1), (*out, z[i] + 0.1), 0.05)
                prev_out = (*out, z[i])
                if acc >= 5.0:                                       # steel cantilever + pile from land side
                    acc = 0.0
                    steel.beam((*inn, z[i] - 0.6), (*out, z[i] - 0.6), 0.35, 0.5)
                    mx, my = (inn[0] * 0.8 + out[0] * 0.2), (inn[1] * 0.8 + out[1] * 0.2)
                    steel.beam((mx, my, z[i] - 0.6), (mx, my, min(L.ground_z(mx, my), 0.0) - 1.0), 0.5)
            if lacc >= R["lamp_every_m"]:
                lacc = 0.0
                q = inn
                lamp.beam((*q, z[i]), (*q, z[i] + 4.5), 0.12)
                lamp.box(q[0], q[1], z[i] + 4.5, 0.5, 0.5, 0.25)
        walks += 1
    out = [obj(deck, "hsw_riverwalk_deck", col, rgbm("riverwalk", R["colour"], "render")),
           obj(steel, "hsw_riverwalk_cantilevers", col, rgbm("steel_grey", (0.18, 0.19, 0.2))),
           obj(rail, "hsw_riverwalk_balustrade", col, rgbm("frames", (0.12, 0.12, 0.12))),
           obj(lamp, "hsw_riverwalk_lamps", col, rgbm("frames", (0.12, 0.12, 0.12))),
           obj(piles, "hsw_riverwalk_piles", col, rgbm("piles", H["waterline"]["pile_rgb"])),
           obj(fas, "hsw_riverwalk_fascia", col, rgbm("fascia", H["waterline"]["fascia_rgb"]))]
    return [n for n in out if n], walks


# ---------------------------------------------------------------- pontoons + ferry terminal
def pontoons(col):
    Pn = H["pontoons"]
    o = L.osm()
    flt, can, gw = C.MeshBuf(), C.MeshBuf(), C.MeshBuf()
    for wid in Pn["ways"]:
        w = o["ways"].get(wid)
        if not w:
            continue
        pts = o["line"](w)
        cx, cy, ln, wd, ang = S.min_rect(pts)
        ln, wd = max(ln, 6.0), max(min(wd, 9.0), 4.0)
        z = Pn["deck_ahd"]
        flt.box(cx, cy, z - 1.0, ln, wd, 1.0, ang)
        if wid == Pn["ways"][0]:                                    # ferry terminal canopy
            c, s = math.cos(ang), math.sin(ang)
            for u in (-ln / 2 + 1, 0.0, ln / 2 - 1):
                for v in (-wd / 2 + 0.8, wd / 2 - 0.8):
                    flt.beam((cx + u * c - v * s, cy + u * s + v * c, z), (cx + u * c - v * s, cy + u * s + v * c, z + Pn["canopy_m"]), 0.2)
            can.box(cx, cy, z + Pn["canopy_m"], ln + 0.6, wd + 0.8, 0.35, ang)
        # gangway to the nearest dry ground (step north until the ground is above 3 m)
        bx, by = cx, cy
        for k in range(60):
            if L.ground_z(bx, by + k) > 3.0:
                break
        ex, ey = cx, cy + k
        sx, sy = cx, cy + wd / 2
        gw.beam((sx, sy, z + 0.2), (ex, ey, L.ground_z(ex, ey) + 0.3), 1.8, 0.25)
        for d in (-0.9, 0.9):
            gw.beam((sx + d, sy, z + 1.3), (ex + d, ey, L.ground_z(ex, ey) + 1.4), 0.06)
    return [n for n in (obj(flt, "hsw_pontoons", col, rgbm("pontoon", (0.30, 0.31, 0.32))),
                        obj(can, "hsw_ferry_canopy", col, rgbm("canopy", (0.85, 0.86, 0.86))),
                        obj(gw, "hsw_gangways", col, rgbm("steel_grey", (0.18, 0.19, 0.2)))) if n]


# ---------------------------------------------------------------- Wilson Outlook fence
def wilson_fence(col):
    F = H["wilson_fence"]
    o = L.osm()
    w = o["ways"].get(F["park_way"])
    if not w:
        return []
    ring = o["line"](w)
    xs = [p[0] for p in ring]
    ys = [p[1] for p in ring]
    fb = C.MeshBuf()
    prev = None
    for x in np.arange(min(xs), max(xs), F["post_m"]):
        edge = None
        for y in np.arange(max(ys), min(ys), -1.0):
            if not C.point_in_ring(x, y, ring):
                continue
            if L.ground_z(x, y) - L.ground_z(x, y - 4) > 5.0:
                edge = (x, y + 0.5)
                break
        if edge is None:
            prev = None
            continue
        z = L.ground_z(*edge)
        fb.beam((*edge, z), (*edge, z + F["height_m"]), 0.07)
        if prev and math.dist(prev[:2], edge) < 6:
            fb.beam((*prev[:2], prev[2] + F["height_m"]), (*edge, z + F["height_m"]), 0.06)
            fb.beam((*prev[:2], prev[2] + 0.15), (*edge, z + 0.15), 0.05)
            fb.beam((*prev[:2], prev[2] + F["height_m"] / 2), (*edge, z + F["height_m"] / 2), 0.03)
        prev = (*edge, z)
    n = obj(fb, "hsw_wilson_outlook_fence", col, rgbm("frames", (0.12, 0.12, 0.12)))
    return [n] if n else []


def hotel_fins(col):
    """Crystalbrook Vincent (ex-Fantauzzo): faceted saw-tooth facade in natural tones on the faces that look
    at the river/bridge (photos overview_aerial/pg_0d874e9b, pg_67e0b628; brief). Fins on each tier."""
    Ht = H["hotel_fins"]
    rec = rec_by_osm()[H["hotel_way"]]
    fins, alt, mid = C.MeshBuf(), C.MeshBuf(), C.MeshBuf()
    k = 0
    for ti, t in enumerate(rec["tiers"]):
        ring = S.ccw([tuple(p) for p in t["ring"]])
        z0 = rec["base_ahd"] + 4.0 if ti == 0 else rec["tiers"][ti - 1]["top_ahd"]
        z1 = t["top_ahd"] - 0.6
        for i in range(len(ring)):
            (ax_, ay_), (bx, by) = ring[i], ring[(i + 1) % len(ring)]
            ln = math.dist((ax_, ay_), (bx, by))
            if ln < 4.0:
                continue
            ux, uy = (bx - ax_) / ln, (by - ay_) / ln
            nx, ny = uy, -ux                                 # outward normal of a ccw ring
            if ny > -0.3 and nx < 0.6:                       # river (south) and east faces only
                continue
            n = int(ln // Ht["pitch_m"])
            for j in range(n):
                s0 = j * Ht["pitch_m"] + 0.3
                s1 = s0 + Ht["pitch_m"] - 0.6
                p0 = (ax_ + ux * s0, ay_ + uy * s0)
                p1 = (ax_ + ux * s1, ay_ + uy * s1)
                tip = (ax_ + ux * s1 + nx * Ht["depth_m"], ay_ + uy * s1 + ny * Ht["depth_m"])
                zz = z0                                       # r2: floor-high pieces in 3 tones -> chevrons
                fl = 0
                while zz < z1 - 0.5:
                    zt = min(zz + 3.2, z1)
                    tone = (j + fl) % 3
                    (fins, mid, alt)[tone].prism([p0, p1, tip], zz, zt - 0.08)
                    zz, fl = zt, fl + 1
                k += 1
    return [n for n in (obj(fins, "hsw_hotel_fins", col, rgbm("hotel_fin", Ht["colour"])),
                        obj(mid, "hsw_hotel_fins_mid", col, rgbm("hotel_fin_mid", (0.40, 0.40, 0.40))),
                        obj(alt, "hsw_hotel_fins_timber", col, rgbm("hotel_fin_timber", (0.13, 0.13, 0.14)))) if n]


def mangroves(col):
    M = H["mangroves"]
    rnd = random.Random(M["seed"])
    x0, y0, x1, y1 = M["box"]
    cls = L.lidar("class")
    buf = C.MeshBuf()
    n = 0
    for x in np.arange(x0, x1, M["every_m"]):
        for y in np.arange(y0, y1, M["every_m"]):
            xx, yy = x + rnd.uniform(-0.8, 0.8), y + rnd.uniform(-0.8, 0.8)
            z = L.ground_z(xx, yy)
            if not (M["z"][0] <= z <= M["z"][1]) or cls[L.lidar_cell(xx, yy)] == 6:
                continue
            if z > 2.6 and min(L.ground_z(xx + 7 * math.cos(a), yy + 7 * math.sin(a)) for a in (0, 1.57, 3.14, 4.71)) > 0.3:
                continue
            r = rnd.uniform(1.2, 2.6)
            blob(buf, xx, yy, z + r * 0.55, r, r * rnd.uniform(0.6, 0.85), rnd)
            n += 1
    name = obj(buf, "hsw_mangroves", col, C.material_rgb("hsw_mangrove", (0.035, 0.065, 0.025), shader="canopy"))
    return ([name] if name else []), n


# ---------------------------------------------------------------- round 2 dressing
def palm(fo, trunks, x, y, g, h, rnd):
    """Cocos-style palm: thin leaning trunk, arching fronds of leaf cards."""
    lean = rnd.uniform(0, 2 * math.pi)
    tx, ty = x + math.cos(lean) * h * 0.06, y + math.sin(lean) * h * 0.06
    trunks.beam((x, y, g), (tx, ty, g + h), 0.3)
    n = 11
    for k in range(n):
        a = 2 * math.pi * k / n + rnd.uniform(-.2, .2)
        ln = rnd.uniform(3.0, 4.2)
        pts = [(tx + math.cos(a) * ln * f, ty + math.sin(a) * ln * f, g + h + 1.0 * f - 2.4 * f * f) for f in [i / 8 for i in range(1, 9)]]
        fo.strands([(px, py, pz + 0.2) for px, py, pz in pts], (0, 0, 1), 0.6, 0.5, 0.85)


def dressing(col):
    """Critic round 2: Mr Percival's arched windows + palms, umbrellas on the outdoor-seating lawns,
    planters and palms along the riverwalk."""
    import foliage as FO
    rnd = random.Random(31)
    P = H["percivals"]
    cx, cy = P["centre_xy"]
    r = P["radius_m"] + 0.06
    dz = P["deck_ahd"]
    arch, frame = C.MeshBuf(), C.MeshBuf()
    for k in range(8):                                   # arched windows on the octagon faces
        a0, a1 = math.pi / 8 + k * math.pi / 4, math.pi / 8 + (k + 1) * math.pi / 4
        p0 = (cx + r * math.cos(a0), cy + r * math.sin(a0))
        p1 = (cx + r * math.cos(a1), cy + r * math.sin(a1))
        ux, uy = (p1[0] - p0[0]), (p1[1] - p0[1])
        ln = math.hypot(ux, uy)
        ux, uy = ux / ln, uy / ln
        nx, ny = uy, -ux
        if ny < -0.9:                                    # the porch side (south) has the door
            continue
        w = ln * 0.58
        mx, my = (p0[0] + p1[0]) / 2, (p0[1] + p1[1]) / 2
        z0, zs = dz + 0.9, P["wall_top_ahd"] - 0.6 - w / 2
        prof = [(-w / 2, z0)] + [(w / 2 * math.cos(math.pi - math.pi * j / 10), zs + w / 2 * math.sin(math.pi - math.pi * j / 10)) for j in range(11)] + [(w / 2, z0)]
        for buf, grow, off in ((frame, 0.22, 0.03), (arch, 0.0, 0.07)):
            pr = [(u * (1 + grow / max(w, .1) * 2), z if z > z0 + .01 else z - grow) for u, z in prof]
            vs = [(mx + ux * u + nx * off, my + uy * u + ny * off, z) for u, z in pr]
            buf.add(vs, [list(range(len(vs) - 1, -1, -1))])
    fo = FO.Foliage(seed=41)
    trunks = C.MeshBuf()
    npalm = 0
    for ang in (0.6, 2.3, 3.6, 5.2):                     # palms on Percival's deck (photo p09)
        x, y = cx + math.cos(ang) * (r + 3.0), cy + math.sin(ang) * (r + 2.0)
        palm(fo, trunks, x, y, dz, rnd.uniform(4.5, 7.0), rnd)
        npalm += 1
    # umbrellas on the outdoor-seating lawns (OSM leisure=outdoor_seating) on a loose 5 m grid
    o = L.osm()
    umb, pole, plant = C.MeshBuf(), C.MeshBuf(), C.MeshBuf()
    nu = 0
    for w in o["ways"].values():
        if w.get("tags", {}).get("leisure") != "outdoor_seating":
            continue
        ring = o["line"](w)
        if len(ring) < 3:
            continue
        xs, ys = [p[0] for p in ring], [p[1] for p in ring]
        for x in np.arange(min(xs) + 2, max(xs) - 2, 5.0):
            for y in np.arange(min(ys) + 2, max(ys) - 2, 5.0):
                if not C.point_in_ring(x, y, ring) or rnd.random() < 0.55:
                    continue
                g = L.ground_z(x, y)
                x2, y2 = x + rnd.uniform(-1, 1), y + rnd.uniform(-1, 1)
                rr = rnd.uniform(1.2, 1.5)
                pole.beam((x2, y2, g), (x2, y2, g + 2.5), 0.06)
                ring_ = [(x2 + rr * math.cos(t), y2 + rr * math.sin(t), g + 2.2) for t in np.linspace(0, 2 * math.pi, 9)[:-1]]
                umb.add(ring_ + [(x2, y2, g + 2.75)], [[i, (i + 1) % 8, 8] for i in range(8)])
                nu += 1
    # planters + palms along the riverwalk's land side (photo p10)
    R_ = H["riverwalk"]
    acc = 0.0
    nplant = 0
    for wid, w in o["ways"].items():
        t = w.get("tags", {})
        if t.get("highway") not in ("footway", "cycleway", "path", "pedestrian"):
            continue
        if "Riverwalk" not in t.get("name", "") and not [p for p in o["line"](w) if L.ground_z(*p) < 2.5]:
            continue
        pts = C.densify(o["line"](w), 2.0)
        if not any(in_patch(*p) for p in pts):
            continue
        inner = C.offset_line(pts, R_["width_m"] / 2 - 0.8)
        outer = C.offset_line(pts, -(R_["width_m"] / 2 - 0.8))
        for i in range(1, len(pts)):
            acc += math.dist(pts[i - 1], pts[i])
            a_, b_ = inner[i], outer[i]
            x, y = a_ if L.ground_z(*a_) >= L.ground_z(*b_) else b_
            if not in_patch(x, y) or acc < 14.0:
                continue
            acc = 0.0
            g = max(R_["deck_ahd"], L.ground_z(x, y) + 0.12)
            plant.box(x, y, g, 1.2, 1.2, 0.7)
            fo.cloud((x, y, g + 1.1), (0.8, 0.8, 0.5), 60, 0.3, shell=0.3, top_bias=0.4)
            if nplant % 2 == 0:
                palm(fo, trunks, x, y, g + 0.7, rnd.uniform(4.0, 6.5), rnd)
                npalm += 1
            nplant += 1
    # sand-pink decomposed-granite paths: OSM footways on the strip (not the riverwalk deck), draped 6 cm up
    paths = C.MeshBuf()
    npath = 0
    G_ = H["ground"]
    for wid, w in o["ways"].items():
        t = w.get("tags", {})
        if t.get("highway") not in ("footway", "path", "pedestrian", "cycleway"):
            continue
        pts = o["line"](w)
        if len(pts) < 2 or not all(in_patch(*p) for p in pts):
            continue
        if "Riverwalk" in t.get("name", "") or [p for p in pts if L.ground_z(*p) < 2.5]:
            continue
        if max(L.ground_z(*p) for p in pts) > 12.0:             # cliff-top streets keep their own footpaths
            continue
        pts = C.densify(pts, 1.0)
        lf, rt = C.offset_line(pts, G_["path_w_m"] / 2), C.offset_line(pts, -G_["path_w_m"] / 2)
        n = len(pts)
        vs = [(x, y, L.ground_z(x, y) + 0.06) for x, y in lf] + [(x, y, L.ground_z(x, y) + 0.06) for x, y in rt]
        paths.add(vs, [[i, n + i, n + i + 1, i + 1] for i in range(n - 1)])
        npath += 1
    names = [obj(paths, "hsw_paths_dg", col, rgbm("path_dg", G_["path"], "dg")),
             obj(arch, "mr_percivals_arched_windows", col, rgbm("glass_dark", (0.05, 0.065, 0.07), "glass_green")),
             obj(frame, "mr_percivals_arch_frames", col, rgbm("percivals_trim", (0.86, 0.88, 0.84))),
             obj(trunks, "hsw_palm_trunks", col, rgbm("palm_trunk", (0.33, 0.30, 0.26))),
             obj(umb, "hsw_umbrellas", col, rgbm("umbrella", (0.86, 0.84, 0.78))),
             obj(pole, "hsw_umbrella_poles", col, rgbm("frames", (0.12, 0.12, 0.12))),
             obj(plant, "hsw_planters", col, rgbm("planter", (0.22, 0.21, 0.20)))]
    ob = fo.object("hsw_palms_planting", col, (0.07, 0.15, 0.045), (0.18, 0.30, 0.08))
    if ob:
        names.append(ob.name)
    return [n for n in names if n], {"palms": npalm, "umbrellas": nu, "planters": nplant, "paths": npath}


def build(col):
    meta = {}
    names_h = hotel_fins(col)
    mg, meta["mangroves"] = mangroves(col)
    names_h += mg
    names, m = terrain(col)
    meta.update(m)
    names += sheds(col)
    names += percivals(col)
    names += lift_tower(col)
    rw, walks = riverwalk(col)
    names += rw
    meta["riverwalk_ways"] = walks
    names += pontoons(col)
    names += wilson_fence(col) + names_h
    dn, meta["dressing"] = dressing(col)
    names += dn
    meta["objects"] = [n for n in names if n]
    return meta


# ---------------------------------------------------------------- shaders (called from preview.setup_morning)
def shade(m, bsdf):
    nt = m.node_tree
    nodes, links = nt.nodes, nt.links
    kind = m.get("shader")
    base = tuple(m.diffuse_color)

    def mix_rgb(fac, a, b, blend="MIX"):
        mx = nodes.new("ShaderNodeMix")
        mx.data_type = "RGBA"
        mx.blend_type = blend
        if isinstance(fac, float):
            mx.inputs["Factor"].default_value = fac
        else:
            links.new(fac, mx.inputs["Factor"])
        for k, v in ((6, a), (7, b)):
            if isinstance(v, tuple):
                mx.inputs[k].default_value = v
            else:
                links.new(v, mx.inputs[k])
        return mx.outputs[2]

    geo = nodes.new("ShaderNodeNewGeometry")
    if kind in ("tuff", "tuff_dark"):
        # round 2: no bench lines or wave streaks (they read as a grid). Fractured blocks: Voronoi cells with
        # their own tan-ochre tone, thin dark joints at the cell edges, orange iron stain, soft wet streaks.
        T = H["cliff"]["tuff"]
        if kind == "tuff_dark":
            T = tuple(tuple(c * 0.28 for c in t) for t in T)
        warp = nodes.new("ShaderNodeTexNoise")
        warp.inputs["Scale"].default_value = 0.15
        links.new(geo.outputs["Position"], warp.inputs["Vector"])
        wv = nodes.new("ShaderNodeVectorMath")
        wv.operation = "MULTIPLY_ADD"
        links.new(warp.outputs["Color"], wv.inputs[0])
        wv.inputs[1].default_value = (2.5, 2.5, 1.0)
        links.new(geo.outputs["Position"], wv.inputs[2])
        sc_ = nodes.new("ShaderNodeVectorMath")                   # blocks taller than wide (vertical joints)
        sc_.operation = "MULTIPLY"
        links.new(wv.outputs[0], sc_.inputs[0])
        sc_.inputs[1].default_value = (1.0, 1.0, 0.3)
        vo = nodes.new("ShaderNodeTexVoronoi")
        vo.inputs["Scale"].default_value = 0.16
        links.new(sc_.outputs[0], vo.inputs["Vector"])
        ramp = nodes.new("ShaderNodeValToRGB")
        el = ramp.color_ramp.elements
        el[0].position, el[0].color = 0.15, (*T[0], 1)
        el[1].position, el[1].color = 0.85, (*T[1], 1)
        links.new(vo.outputs["Color"], ramp.inputs["Fac"])
        nz = nodes.new("ShaderNodeTexNoise")                       # tone inside each block
        nz.inputs["Scale"].default_value = 0.6
        nz.inputs["Detail"].default_value = 8.0
        links.new(geo.outputs["Position"], nz.inputs["Vector"])
        c0 = mix_rgb(0.35, ramp.outputs["Color"], (*T[0], 1))
        c0 = mix_rgb(nz.outputs["Fac"], c0, ramp.outputs["Color"], "OVERLAY")
        stain = nodes.new("ShaderNodeTexNoise")                    # orange iron staining
        stain.inputs["Scale"].default_value = 0.06
        stain.inputs["Detail"].default_value = 4.0
        links.new(geo.outputs["Position"], stain.inputs["Vector"])
        sm = nodes.new("ShaderNodeMapRange")
        links.new(stain.outputs["Fac"], sm.inputs["Value"])
        sm.inputs["From Min"].default_value, sm.inputs["From Max"].default_value = 0.52, 0.68
        sm.inputs["To Max"].default_value = 0.7
        c1 = mix_rgb(sm.outputs["Result"], c0, (*T[2], 1))
        ed = nodes.new("ShaderNodeTexVoronoi")                     # thin dark joints between the blocks
        ed.feature = "DISTANCE_TO_EDGE"
        ed.inputs["Scale"].default_value = 0.16
        links.new(sc_.outputs[0], ed.inputs["Vector"])
        jr = nodes.new("ShaderNodeMapRange")
        links.new(ed.outputs["Distance"], jr.inputs["Value"])
        jr.inputs["From Min"].default_value, jr.inputs["From Max"].default_value = 0.0, 0.025
        jr.inputs["To Min"].default_value, jr.inputs["To Max"].default_value = 0.35, 0.0
        c2 = mix_rgb(jr.outputs["Result"], c1, (0.07, 0.055, 0.045, 1))
        wet = nodes.new("ShaderNodeTexNoise")                      # soft dark wet streaks (stretched down)
        wvec = nodes.new("ShaderNodeVectorMath")
        wvec.operation = "MULTIPLY"
        links.new(geo.outputs["Position"], wvec.inputs[0])
        wvec.inputs[1].default_value = (0.5, 0.5, 0.04)
        links.new(wvec.outputs[0], wet.inputs["Vector"])
        wet.inputs["Scale"].default_value = 1.0
        wr = nodes.new("ShaderNodeMapRange")
        links.new(wet.outputs["Fac"], wr.inputs["Value"])
        wr.inputs["From Min"].default_value, wr.inputs["From Max"].default_value = 0.6, 0.75
        wr.inputs["To Max"].default_value = 0.45
        c3 = mix_rgb(wr.outputs["Result"], c2, (0.15, 0.12, 0.09, 1))
        links.new(c3, bsdf.inputs["Base Color"])
        bump = nodes.new("ShaderNodeBump")
        bump.inputs["Strength"].default_value = 0.9
        bump.inputs["Distance"].default_value = 0.3
        nz2 = nodes.new("ShaderNodeTexNoise")
        nz2.inputs["Scale"].default_value = 1.4
        nz2.inputs["Detail"].default_value = 8.0
        links.new(geo.outputs["Position"], nz2.inputs["Vector"])
        hb = nodes.new("ShaderNodeMath")
        hb.operation = "MULTIPLY_ADD"
        links.new(ed.outputs["Distance"], hb.inputs[0])
        hb.inputs[1].default_value = 3.0
        links.new(nz2.outputs["Fac"], hb.inputs[2])
        links.new(hb.outputs[0], bump.inputs["Height"])
        links.new(bump.outputs["Normal"], bsdf.inputs["Normal"])
        bsdf.inputs["Roughness"].default_value = 0.95
    elif kind == "dg":
        # decomposed granite / soil: base colour with soft blotches and fine grit
        nz = nodes.new("ShaderNodeTexNoise")
        nz.inputs["Scale"].default_value = 0.12
        nz.inputs["Detail"].default_value = 6.0
        links.new(geo.outputs["Position"], nz.inputs["Vector"])
        c1 = mix_rgb(nz.outputs["Fac"], tuple(c * 0.82 for c in base[:3]) + (1,), tuple(min(1, c * 1.12) for c in base[:3]) + (1,))
        gr = nodes.new("ShaderNodeTexNoise")
        gr.inputs["Scale"].default_value = 30.0
        links.new(geo.outputs["Position"], gr.inputs["Vector"])
        c2 = mix_rgb(0.25, c1, gr.outputs["Color"], "OVERLAY")
        links.new(c2, bsdf.inputs["Base Color"])
        bsdf.inputs["Roughness"].default_value = 0.95
    elif kind in ("sheet", "boards"):
        uv = nodes.new("ShaderNodeUVMap")
        uv.uv_map = "facade"
        sep = nodes.new("ShaderNodeSeparateXYZ")
        links.new(uv.outputs["UV"], sep.inputs[0])
        pitch = 0.76 if kind == "sheet" else 0.14
        src = sep.outputs["X"] if kind == "sheet" else sep.outputs["Y"]
        if kind == "boards":
            src = geo.outputs["Position"]
            sp = nodes.new("ShaderNodeSeparateXYZ")
            links.new(src, sp.inputs[0])
            src = sp.outputs["X"]
        fr = nodes.new("ShaderNodeMath")
        fr.operation = "PINGPONG"
        links.new(src, fr.inputs[0])
        fr.inputs[1].default_value = pitch / 2
        lt = nodes.new("ShaderNodeMath")
        lt.operation = "LESS_THAN"
        links.new(fr.outputs[0], lt.inputs[0])
        lt.inputs[1].default_value = 0.03 if kind == "sheet" else 0.012
        dark = tuple(c * 0.8 for c in base[:3]) + (1,)
        c1 = mix_rgb(lt.outputs[0], base, dark)
        nz = nodes.new("ShaderNodeTexNoise")
        nz.inputs["Scale"].default_value = 0.3
        links.new(geo.outputs["Position"], nz.inputs["Vector"])
        c2 = mix_rgb(nz.outputs["Fac"], c1, tuple(c * 0.86 for c in base[:3]) + (1,))
        links.new(c2, bsdf.inputs["Base Color"])
        bsdf.inputs["Roughness"].default_value = 0.55 if kind == "sheet" else 0.85
        if kind == "sheet":
            bsdf.inputs["Metallic"].default_value = 0.35
    elif kind == "corten":
        nz = nodes.new("ShaderNodeTexNoise")
        nz.inputs["Scale"].default_value = 1.5
        nz.inputs["Detail"].default_value = 10.0
        links.new(geo.outputs["Position"], nz.inputs["Vector"])
        c1 = mix_rgb(nz.outputs["Fac"], tuple(c * 0.7 for c in base[:3]) + (1,), tuple(min(1, c * 1.35) for c in base[:3]) + (1,))
        links.new(c1, bsdf.inputs["Base Color"])
        bsdf.inputs["Roughness"].default_value = 0.8
    elif kind == "glass_green":
        bsdf.inputs["Base Color"].default_value = base
        bsdf.inputs["Roughness"].default_value = 0.08
        bsdf.inputs["Metallic"].default_value = 0.3
