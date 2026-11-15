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
SUNK = {}                                               # r4: sink mask of the 1 m patch (trees.py reads it)


def sunk(x, y):
    m = SUNK.get("mask")
    if m is None:
        return False
    c, r = int(round(x - SUNK["x0"])), int(round(SUNK["y1"] - y))
    return 0 <= r < m.shape[0] and 0 <= c < m.shape[1] and bool(m[r, c])


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
    wet = np.zeros(sub.shape, bool)                     # r3: river halves of the over-water sheds, Percival's deck
    for ring in water_rings():
        m_, rr_, cc_ = PL.ring_mask(ring, L.LIDAR_BOX)
        if m_ is None:
            continue
        a0, a1 = max(rr_, r0), min(rr_ + m_.shape[0], r1 + 1)          # overlap of the ring box and the patch
        b0, b1 = max(cc_, c0), min(cc_ + m_.shape[1], c1 + 1)
        if a0 < a1 and b0 < b1:
            wet[a0 - r0:a1 - r0, b0 - c0:b1 - c0] |= m_[a0 - rr_:a1 - rr_, b0 - cc_:b1 - cc_]
    sink |= wet & (sub < 6.0)
    water_n = np.zeros(sub.shape, bool)                 # r3: low strips with water just north of them are decks the
    for k in range(1, 31):                              # LiDAR read as ground (riverwalk out over the river): sink them
        water_n |= np.roll(sub < 0.0, k, 0)
    water_n[:31] = False
    sink |= (sub < 5.0) & water_n & ~lawn_v & ~riprap_zone & (X >= 400.0)   # r4: real land west of HSW stays
    verts[:, 2] = np.where(sink.ravel(), np.minimum(verts[:, 2], W_["sink_to_ahd"]), verts[:, 2])
    SUNK["mask"], SUNK["x0"], SUNK["y1"] = sink, float(X[0, 0]), float(Y[0, 0])
    zz = verts[:, 2].reshape(R, Cn)
    zc2 = np.minimum.reduce([zz[:-1, :-1], zz[1:, :-1], zz[1:, 1:], zz[:-1, 1:]])   # lowest corner of each face
    mi = np.zeros(zc.shape, "i4")                                   # 0 paving (warm pale decomposed granite)
    mi[(zc > 16.0) & (slope < H["scrub_slope_deg"])] = 4            # cliff top: ground
    mi[(park | lawn) & (slope < H["scrub_slope_deg"]) & (cls != 3)] = 3
    mi[lawn] = 3
    mi[(slope >= H["scrub_slope_deg"]) & (slope < H["rock_slope_deg"])] = 2
    mi[slope >= H["rock_slope_deg"]] = 1
    mi[(mi == 1) & (X[:-1, :-1] < H["green_cliff_x_max"])] = 2      # r3: green hill, no bare tuff west of Barrel Hall
    mi[(mi == 0) & (X[:-1, :-1] < 400.0)] = 3                        # r5: the land west of HSW is park, not paving
    mi[(zc < 3.2) & (slope >= H["scrub_slope_deg"])] = 5            # river bank under the decks: dark mud/rock
    mi[zc2 < 2.6] = 5
    mi[zc2 < 0.0] = 5                                                # river bed
    ob = C.mesh_fast("hsw_terrain_1m", verts, faces, col, "footway")
    ob.data.materials[0] = rgbm("paving_dg", H["ground"]["paving"], "pave")   # r4: pavers with joints
    ob.data.materials.append(rgbm("tuff", H["cliff"]["tuff"][1], "tuff"))
    ob.data.materials.append(rgbm("scrub_bank", (0.10, 0.10, 0.05), "dg"))
    ob.data.materials.append(C.material("grass"))
    ob.data.materials.append(rgbm("clifftop_litter", (0.085, 0.09, 0.045), "dg"))
    ob.data.materials.append(rgbm("bank", (0.025, 0.022, 0.02)))
    ob.data.polygons.foreach_set("material_index", mi.ravel())
    ob.data.shade_smooth()
    names = [ob.name]
    meta = {"terrain_faces": int(len(faces)), "sunk_cells": int(sink.sum())}
    n2, m2 = cliff_dress(col, X, Y, sub, slope, zc, orig, riprap_zone)
    names += n2
    meta.update(m2)
    return names, meta


def shed_frame(sh, rec):
    """(Pt, ln, wd, rside, base) for a shed: Pt(u, v, z) in the shed frame, rside = +1/-1 the river side."""
    cx, cy, ln, wd, ang, base, eave, ridge = shed_geometry(sh, rec)
    c, s_ = math.cos(ang), math.sin(ang)
    Pt = lambda u, v, z: (cx + u * c - v * s_, cy + u * s_ + v * c, z)
    gp = L.ground_z(*Pt(0, wd / 2 + 6, 0)[:2])
    gm = L.ground_z(*Pt(0, -wd / 2 - 6, 0)[:2])
    return Pt, ln, wd, (1 if gp < gm else -1), base


def water_rings():
    """Round 3: rings that stand over the water on piles (river half of the over-water sheds + their decks,
    Mr Percival's deck)."""
    recs = rec_by_osm()
    rings = []
    for sh in H["sheds"]:
        if sh["osm"] not in H["over_water_sheds"] or sh["osm"] not in recs:
            continue
        Pt, ln, wd, rs, _ = shed_frame(sh, recs[sh["osm"]])
        v1 = wd / 2 + sh.get("deck_river_m", 0.0) + 1.6
        v0 = -wd / 2 + 0.6                               # r3: whole footprint (the land wall closes it)
        rings.append([Pt(u, rs * v, 0)[:2] for u, v in ((-ln / 2 - 1.6, v0), (ln / 2 + 1.6, v0), (ln / 2 + 1.6, v1), (-ln / 2 - 1.6, v1))])
    o = L.osm()                                         # riverwalk from HSW to Barrel Hall: the river side of the
    rx0, rx1 = H["riverwalk_piles_x"]                   # path stands on piles too (photo p09: water between the piles)
    for w in o["ways"].values():
        t = w.get("tags", {})
        if t.get("highway") not in ("footway", "cycleway", "living_street", "path", "pedestrian"):
            continue
        pts = o["line"](w)
        if len(pts) < 2 or not any(rx0 <= x <= rx1 and -60 <= y <= 120 for x, y in pts):
            continue
        if not [p for p in pts if L.ground_z(*p) < 2.5] and "Riverwalk" not in t.get("name", ""):
            continue
        pts = [p for p in C.densify(pts, 2.0) if rx0 <= p[0] <= rx1]
        if len(pts) < 2:
            continue
        hw = H["riverwalk"]["width_m"] / 2
        lf, rt = C.offset_line(pts, hw + 6.0), C.offset_line(pts, -(hw + 6.0))
        gl = sum(L.ground_z(*q) for q in lf) / len(lf)
        gr = sum(L.ground_z(*q) for q in rt) / len(rt)
        outer = lf if gl < gr else rt
        inner = C.offset_line(pts, -0.5 if gl < gr else 0.5)
        for i in range(len(pts) - 1):
            rings.append([inner[i], inner[i + 1], outer[i + 1], outer[i]])
    ex0, ey0, ex1, ey1 = H["felons_east_deck"]["box"]                    # r6: dining deck east of Felons
    rings.append([(ex0, ey0), (ex1, ey0), (ex1, ey1 - 6.0), (ex0, ey1 - 6.0)])
    P = H["percivals"]
    cx, cy = P["centre_xy"]
    dl, dw = P["deck_size_m"]
    a = math.radians(P["deck_angle_deg"])
    ca, sa = math.cos(a), math.sin(a)
    rings.append([(cx + u * ca - v * sa, cy + u * sa + v * ca) for u, v in
                  ((-dl / 2 - 0.5, -dw / 2 - 0.5), (dl / 2 + 0.5, -dw / 2 - 0.5), (dl / 2 + 0.5, dw / 2 + 0.5), (-dl / 2 - 0.5, dw / 2 + 0.5))])
    return rings


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
    gx_max = H["green_cliff_x_max"]
    ft_ = (slope < 22) & (zc > 14.0)
    nt_ = np.zeros_like(ft_)
    for dr in range(-4, 5):
        for dc in range(-4, 5):
            nt_ |= np.roll(np.roll(ft_, dr, 0), dc, 1)
    rr, cc = np.nonzero(steep & (zc > 4.0) & (X[:-1, :-1] >= gx_max) & ~nt_)
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
        out = rnd.uniform(-0.7, 0.15)
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
        blob(rip, X[r, c] + rnd.uniform(-.5, .5), Y[r, c] + rnd.uniform(-.5, .5), float(orig[r, c]) + s * 0.1, s, s * 0.55, rnd, 12, 7)
        nrip += 1
    # vegetation: leaf-card tufts on the ledges only (bare faces stay bare); hanging figs and vines off the rim
    leaves = FO.Foliage(seed=Cl["seed"])
    vines = FO.Foliage(seed=Cl["seed"] + 1)
    canopy = FO.Foliage(seed=Cl["seed"] + 2)
    tops = FO.Foliage(seed=Cl["seed"] + 3)
    jac = FO.Foliage(seed=Cl["seed"] + 4)
    hill_trunks = C.MeshBuf()
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
    ncan = 0
    ev = H["canopy_every_m"]
    ra, rb_ = H["canopy_r_m"]
    green = (slope >= H["scrub_slope_deg"] - 6) & (zc > 3.5) & (X[:-1, :-1] < gx_max) & (X[:-1, :-1] > 380)
    green &= ~((X[:-1, :-1] < 612.0) & (Y[:-1, :-1] < 85.0))          # r6: not on the wharf strip's bank edges
    top_band = near_top & (zc > 14.0) & (X[:-1, :-1] < gx_max) & (X[:-1, :-1] > 380)
    for r, c in zip(*np.nonzero(green | top_band)):
        if (r % ev) or (c % ev):
            continue
        ux, uy = -gx[r, c], -gy[r, c]
        ln = math.hypot(ux, uy) or 1.0
        ux, uy = ux / ln, uy / ln
        rad = rnd.uniform(ra, rb_)
        lift = rnd.uniform(1.5, 4.0) if green[r, c] else rnd.uniform(5.0, 10.0)   # crowns of trees behind the rim
        px_ = X[r, c] + ux * 1.2 + rnd.uniform(-1.5, 1.5)
        py_ = Y[r, c] + uy * 1.2 + rnd.uniform(-1.5, 1.5)
        pz_ = zc[r, c] + lift
        roll = rnd.random()
        if roll < 0.10:                                   # r5: groups of palms among the crowns (photo p12)
            for _ in range(rnd.randint(2, 4)):
                palm(canopy, hill_trunks, px_ + rnd.uniform(-3, 3), py_ + rnd.uniform(-3, 3), zc[r, c], rnd.uniform(7.0, 12.0), rnd)
        elif roll < 0.13:                                 # a jacaranda or two in flower
            jac.cloud((px_, py_, pz_), (rad, rad, rad * 0.6), int(9 * (20 + 4 * rad * rad)), 0.5, shell=0.2, top_bias=0.5)
        else:                                             # r4: distinct round crowns with lime-lit tops
            canopy.cloud((px_, py_, pz_), (rad, rad, rad * 0.75), int(9 * (22 + 5 * rad * rad)), 0.55, shell=0.12, top_bias=0.2)
            tops.cloud((px_ + 0.3, py_ - 0.3, pz_ + rad * 0.5), (rad * 0.7, rad * 0.7, rad * 0.28), int(3 * (22 + 5 * rad * rad)),
                       0.5, shell=0.3, top_bias=0.9)
        ncan += 1
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
             obj(hill_trunks, "hsw_hill_palm_trunks", col, rgbm("palm_trunk", (0.33, 0.30, 0.26))),
             obj(rip, "hsw_riprap", col, rgbm("riprap", (0.24, 0.22, 0.19), "dg"))]
    for fo, nm, a, b in ((leaves, "hsw_cliff_scrub", (0.05, 0.10, 0.035), (0.13, 0.20, 0.07)),
                         (vines, "hsw_cliff_vines", (0.045, 0.095, 0.03), (0.11, 0.19, 0.06)),
                         (canopy, "hsw_hill_canopy", (0.04, 0.09, 0.03), (0.12, 0.21, 0.06)),
                         (tops, "hsw_hill_tops", (0.22, 0.34, 0.06), (0.40, 0.52, 0.10)),
                         (jac, "hsw_jacaranda", (0.22, 0.13, 0.45), (0.38, 0.25, 0.65))):
        o_ = fo.object(nm, col, a, b)
        if o_:
            names.append(o_.name)
    return [n for n in names if n], {"cliff_slabs": nslab, "rim_rocks": nrim, "riprap": nrip, "cliff_tufts": nt,
                                     "hanging_vines": nh, "hill_canopy": ncan}


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
    "felons":     {"wall": (0.78, 0.76, 0.70), "roof": (0.60, 0.65, 0.70), "glass": (0.03, 0.035, 0.04), "bay": 4.0, "win": 3.75, "sill": 0.03, "head": 0.95},   # r2: mostly open glass
    "white_shed": {"wall": (0.80, 0.78, 0.72), "roof": (0.60, 0.65, 0.70), "glass": (0.03, 0.035, 0.04), "bay": 4.5, "win": 4.1, "sill": 0.04, "head": 0.93},
    "barrel_hall": {"wall": (0.20, 0.21, 0.21), "roof": (0.13, 0.14, 0.145), "glass": (0.06, 0.07, 0.075), "bay": 3.0, "win": 2.8, "sill": 0.05, "head": 0.75},
    "cream_shed": {"wall": (0.74, 0.69, 0.58), "roof": (0.48, 0.50, 0.50), "glass": (0.06, 0.07, 0.07), "bay": 3.5, "win": 2.2, "sill": 0.2, "head": 0.8},
    "glasshouse": {"wall": (0.30, 0.36, 0.34), "roof": (0.62, 0.64, 0.64), "glass": (0.12, 0.16, 0.15), "bay": 2.0, "win": 1.85, "sill": 0.04, "head": 0.95},
    "stanley":    {"wall": (0.80, 0.74, 0.60), "roof": (0.42, 0.16, 0.09), "glass": (0.05, 0.06, 0.07), "bay": 3.2, "win": 1.3, "sill": 0.3, "head": 0.82},
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
    awn = C.MeshBuf()
    rnd_p = random.Random(17)
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
                size = min(0.66 * math.hypot(wd / 2 + o, ridge - ze), 1.75 * (ln + 2 * o) / max(4, len(sh["letters"])))
                tob = C.text_obj(col, "hsw_roof_letters_%d" % sh["osm"], sh["letters"], (x, y, zz),
                                 (th, 0.0, head), size, H["letters_rgb"])
                try:
                    import bpy
                    import os
                    fp = os.path.join(L.HERE, "..", "..", "..", "fonts", "Barlow-SemiBold.ttf")
                    tob.data.font = bpy.data.fonts.load(os.path.abspath(fp), check_existing=True)
                    tob.data.space_character = 1.6
                except Exception as e:                       # font missing: Blender's default font
                    print("roof letters font:", e)
                letters.append(tob.name)
        if sh["osm"] in H["over_water_sheds"]:                # r3: river half on a grid of dark piles + bracing
            pg = H["pile_grid_m"]
            v1 = wd / 2 + sh.get("deck_river_m", 0.0) + 1.2
            nu_ = max(2, int(ln / 2.2))                                     # r6: chunky piles ~2.2 m apart
            for i in range(nu_ + 1):
                u = -ln / 2 + i * ln / nu_
                for v in np.arange(v1 % 3.0, v1 + 0.01, 3.0):
                    x, y, _ = Pt(u, rside * v, 0)
                    pw_ = rnd_p.uniform(0.55, 0.68)                                # r6: chunky, varied
                    piles.box(x + rnd_p.uniform(-0.15, 0.15), y + rnd_p.uniform(-0.15, 0.15), -2.5, pw_, pw_, base - 0.3 + 2.5,
                              rnd_p.uniform(0, 0.4))
                xa, ya, _ = Pt(u, rside * v1, 0)
                xb, yb, _ = Pt(u, rside * (v1 - pg), 0)
                frames.beam((xa, ya, base - 0.5), (xb, yb, 0.4), 0.12)            # cross bracing
                if i < nu_:
                    xc, yc, _ = Pt(u + ln / nu_, rside * v1, 0)
                    frames.beam((xa, ya, base - 0.5), (xc, yc, 0.4), 0.12)
                    frames.beam((xa, ya, 0.4), (xc, yc, base - 0.5), 0.12)
            for zw in (1.3, base - 0.9):                                     # r6: horizontal walers on the front row
                frames.beam(Pt(-ln / 2, rside * (v1 + 0.35), zw), Pt(ln / 2, rside * (v1 + 0.35), zw), 0.25, 0.35)
            under = [Pt(u, rside * v, base - 0.32)[:2] for u, v in ((-ln / 2, 0), (ln / 2, 0), (ln / 2, v1), (-ln / 2, v1))]
            decks.prism(under, base - 0.6, base - 0.3)                           # floor slab underside
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
                    if L.ground_z(x, y) < dz - 1.0 or sh["osm"] in H["over_water_sheds"]:
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
                aw = [Pt(-ln / 2 - 0.5, vo, eave - 0.95), Pt(ln / 2 + 0.5, vo, eave - 0.95),
                      Pt(ln / 2 + 0.5, vo + rside * 1.5, eave - 2.1), Pt(-ln / 2 - 0.5, vo + rside * 1.5, eave - 2.1)]
                awn.add(aw, [[0, 1, 2, 3]])                       # r3: fabric awnings along the deck edge (p12)
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
    out.append(obj(piles, "hsw_shed_piles", col, rgbm("piles", H["waterline"]["pile_rgb"], "pile")))
    out.append(obj(frames, "hsw_shed_frames", col, rgbm("frames", (0.12, 0.12, 0.12))))
    out.append(obj(awn, "hsw_shed_awnings", col, rgbm("awning", (0.80, 0.80, 0.77), "stripes")))
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
            if True:                                         # r3: the deck is over water (sunk ground below)
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
    win = {"bay": 2.9, "win": 1.5, "sill": 0.12, "head": 0.78, "glass": (0.05, 0.06, 0.06), "rough": 0.1, "floor": 5.0}
    out = [obj(wall, "mr_percivals_walls", col, rgbm("percivals_wall", P["wall"], "render", win)),
           obj(roof, "mr_percivals_roof", col, rgbm("percivals_roof", H["percivals_roof_r3"], "sheet")),
           obj(lan, "mr_percivals_lantern", col, rgbm("glass_dark", (0.05, 0.065, 0.07), "glass_green")),
           obj(deck, "mr_percivals_deck", col, rgbm("deck_boards", (0.36, 0.27, 0.19), "boards")),
           obj(pile, "mr_percivals_piles", col, rgbm("piles", H["waterline"]["pile_rgb"], "pile")),
           obj(rail, "mr_percivals_rail", col, rgbm("frames", (0.12, 0.12, 0.12)))]
    return [n for n in out if n]


# ---------------------------------------------------------------- lift tower + stairs
def lift_tower(col):
    T = H["lift_tower"]
    x, y = T["xy"]
    sx, sy = H["lift_tower_r2"]["size_m"]
    g = L.ground_z(x, y)
    cor, glass, steel, teal = C.MeshBuf(), C.MeshBuf(), C.MeshBuf(), C.MeshBuf()
    for fx in (-1, 1):                                                   # r3: corten corner columns (p12)
        for fy in (-1, 1):
            cor.box(x + fx * (sx / 2 - 0.3), y + fy * (sy / 2 - 0.3), g - 0.3, 0.6, 0.6, T["top_ahd"] - g)
    teal.box(x, y, g - 0.3, sx - 0.3, sy - 0.3, T["top_ahd"] - g)            # teal glass shaft
    zz_ = g + 3.0
    while zz_ < T["top_ahd"] - 1:                                        # mullion bands
        cor.box(x, y, zz_, sx - 0.2, sy - 0.2, 0.12)
        zz_ += 3.0
    cx, cy = T["cliff_top_xy"]
    gt = L.ground_z(cx, cy)
    zl = T["link_ahd"]
    cor.box(x, y, T["top_ahd"], sx + 1.4, sy + 1.4, 0.5)                           # cap
    cy = cy + H["skybridge_extra_m"]                                    # r4: reach the Bowen Tce building
    steel.box(x, (y + cy) / 2 + sy / 4, zl - 0.5, 2.6, abs(cy - y) - sy / 2, 0.5)   # link bridge deck
    teal.box(x, (y + cy) / 2 + sy / 4, zl, 2.8, abs(cy - y) - sy / 2, 2.6)          # r3: enclosed teal skybridge
    steel.box(x, (y + cy) / 2 + sy / 4, zl + 2.6, 3.2, abs(cy - y) - sy / 2, 0.25)
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
                        obj(teal, "hsw_lift_tower_glass", col, rgbm("lift_teal", H["lift_glass"], "glass_green")),
                        obj(steel, "hsw_lift_tower_steel", col, rgbm("corten_dark", (0.20, 0.09, 0.05), "corten"))) if n]


# ---------------------------------------------------------------- riverwalk
def riverwalk(col):
    R = H["riverwalk"]
    o = L.osm()
    x0, y0, x1, y1 = H["patch_box"]
    deck, steel, rail, lamp = C.MeshBuf(), C.MeshBuf(), C.MeshBuf(), C.MeshBuf()
    piles, fas = C.MeshBuf(), C.MeshBuf()
    walks = 0
    wr = water_rings()
    rx0_, rx1_ = H["riverwalk_piles_x"]
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
            out = left[i] if gl < gr else right[i]
            inn = right[i] if gl < gr else left[i]
            wet = min(gl, gr) < Wl["sink_below_ahd"] + 0.6 or (rx0_ <= pts[i][0] <= rx1_ and any(C.point_in_ring(*out, rg) for rg in wr))
            if wet:                                              # round 2: dark timber pile colonnade (photo p09)
                ox, oy = out[0] * 0.92 + inn[0] * 0.08, out[1] * 0.92 + inn[1] * 0.08
                if prev_out is not None and math.dist(prev_out[:2], out) < 4.0:
                    fas.beam((*prev_out[:2], prev_out[2] - 0.25), (*out, z[i] - 0.25), 0.3, 0.7)
                if pacc >= Wl["pile_every_m"]:
                    pacc = 0.0
                    pw = Wl["pile_w_m"]
                    piles.beam((ox, oy, z[i] - 0.4), (ox, oy, -2.5), pw)
                    mx, my = (inn[0] + out[0]) / 2, (inn[1] + out[1]) / 2
                    pass                                                       # r5: one row only (gaps)
                    piles.beam((ox, oy, z[i] - 0.7), (mx, my, z[i] - 0.7), 0.3, 0.5)          # headstock
                    if prev_pile and math.dist(prev_pile[:2], (ox, oy)) < 4.0:   # walers + X bracing between piles
                        piles.beam((*prev_pile[:2], 1.3), (ox, oy, 1.3), 0.22, 0.3)
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
           obj(piles, "hsw_riverwalk_piles", col, rgbm("piles", H["waterline"]["pile_rgb"], "pile")),
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
                zz = z0                                       # r3: angled fins, light face + dark glass face,
                fl = 0                                        # the tip swaps side each floor -> chevrons (p07, p09)
                while zz < z1 - 0.5:
                    zt = min(zz + 3.2, z1)
                    sa_ = s1 if fl % 2 == 0 else s0
                    tip = (ax_ + ux * sa_ + nx * Ht["depth_m"], ay_ + uy * sa_ + ny * Ht["depth_m"])
                    za, zb = zz, zt - 0.08
                    fins.add([(*p0, za), (*tip, za), (*tip, zb), (*p0, zb)], [[0, 1, 2, 3]])
                    alt.add([(*tip, za), (*p1, za), (*p1, zb), (*tip, zb)], [[0, 1, 2, 3]])
                    mid.add([(*p0, zb), (*tip, zb), (*p1, zb)], [[0, 1, 2]])
                    zz, fl = zt, fl + 1
                k += 1
    return [n for n in (obj(fins, "hsw_hotel_fins", col, rgbm("hotel_fin", Ht["colour"])),
                        obj(mid, "hsw_hotel_fins_mid", col, rgbm("hotel_fin_mid", (0.40, 0.40, 0.40))),
                        obj(alt, "hsw_hotel_fins_timber", col, rgbm("hotel_fin_glass", (0.06, 0.07, 0.08), "glass_green"))) if n]


def hotel_skin(col):
    """Round 5: the Vincent's zig-zag facade as a texture on a skin 0.15 m outside every wall of every tier
    (charcoal, tan and dark glass chevrons at photo scale, p09/p07), green planter strips on the tier edges,
    and one big jacaranda on the cliff side of the hotel."""
    import foliage as FO
    rec = rec_by_osm()[H["hotel_way"]]
    skin, plant = C.MeshBuf(), C.MeshBuf()
    terr = FO.Foliage(seed=78)
    for ti, t in enumerate(rec["tiers"]):
        ring = S.ccw([tuple(p) for p in t["ring"]])
        z0 = rec["base_ahd"] + 4.0 if ti == 0 else rec["tiers"][ti - 1]["top_ahd"]
        z1 = t["top_ahd"] - 0.6
        acc = 0.0
        for i in range(len(ring)):
            (ax_, ay_), (bx, by) = ring[i], ring[(i + 1) % len(ring)]
            ln = math.dist((ax_, ay_), (bx, by))
            if ln < 0.5:
                continue
            nx, ny = (by - ay_) / ln, -(bx - ax_) / ln
            a = (ax_ + nx * 0.15, ay_ + ny * 0.15)
            b = (bx + nx * 0.15, by + ny * 0.15)
            q = [(*a, z0), (*b, z0), (*b, z1), (*a, z1)]
            skin.add(q, [[0, 1, 2, 3]], [[(acc, z0), (acc + ln, z0), (acc + ln, z1), (acc, z1)]])
            acc += ln
        plant.prism(ring, z1 + 0.3, z1 + 0.9)
        for (ax_, ay_), (bx, by) in zip(ring, ring[1:] + ring[:1]):       # r6: terrace and rooftop planting
            ln = math.dist((ax_, ay_), (bx, by))
            for k in range(int(ln // 2.5)):
                f_ = (k + 0.5) / max(1, int(ln // 2.5))
                terr.cloud((ax_ + (bx - ax_) * f_, ay_ + (by - ay_) * f_, z1 + 1.3), (1.2, 1.2, 0.7), 40, 0.35, shell=0.3, top_bias=0.5)
    jac = FO.Foliage(seed=77)
    cx, cy = min(rec["tiers"][0]["ring"], key=lambda p: p[0] + p[1])   # r6: the SW (river) corner
    cx, cy = cx - 4.0, cy - 4.0
    g = L.ground_z(cx, cy)
    tr = C.MeshBuf()
    tr.beam((cx, cy, g), (cx, cy, g + 9.0), 0.7)
    jac.cloud((cx, cy, g + 13.0), (8.0, 8.0, 4.5), 2400, 0.55, shell=0.2, top_bias=0.5)
    names = [obj(skin, "hsw_hotel_chevron_skin", col, rgbm("hotel_chevron", (0.45, 0.38, 0.30), "chevron")),
             obj(plant, "hsw_hotel_planters", col, C.material_rgb("hsw_hotel_planter", (0.05, 0.10, 0.035), shader="canopy")),
             obj(tr, "hsw_hotel_jacaranda_trunk", col, rgbm("palm_trunk", (0.33, 0.30, 0.26)))]
    o_ = terr.object("hsw_hotel_terrace_planting", col, (0.05, 0.11, 0.035), (0.15, 0.25, 0.07))
    if o_:
        names.append(o_.name)
    names += felons_east_deck(col) + oakwood(col)
    o_ = jac.object("hsw_hotel_jacaranda", col, (0.25, 0.15, 0.50), (0.42, 0.28, 0.70))
    if o_:
        names.append(o_.name)
    return [n for n in names if n]


def felons_east_deck(col):
    """Round 6: the open dining deck on piles east of Felons (photos p12/p13: umbrellas, then the green slope)."""
    D = H["felons_east_deck"]
    x0, y0, x1, y1 = D["box"]
    z = D["deck_ahd"]
    deck, piles, rail, umb, pole = (C.MeshBuf() for _ in range(5))
    deck.prism([(x0, y0), (x1, y0), (x1, y1), (x0, y1)], z - 0.4, z)
    for x in np.arange(x0 + 0.5, x1, 2.4):
        for y in np.arange(y0 + 0.5, y1, 3.0):
            piles.box(x, y, -2.5, 0.6, 0.6, z - 0.4 + 2.5)
    for (ax_, ay_), (bx, by) in (((x0, y0), (x1, y0)), ((x1, y0), (x1, y1))):
        rail.beam((ax_, ay_, z + 1.1), (bx, by, z + 1.1), 0.08)
        for f_ in np.linspace(0, 1, int(math.dist((ax_, ay_), (bx, by)) // 2) + 1):
            px_, py_ = ax_ + (bx - ax_) * f_, ay_ + (by - ay_) * f_
            rail.beam((px_, py_, z), (px_, py_, z + 1.1), 0.06)
    for x in np.arange(x0 + 2.5, x1 - 1, 4.2):
        for y in np.arange(y0 + 2.5, y1 - 1, 4.2):
            pole.beam((x, y, z), (x, y, z + 2.5), 0.06)
            ring_ = [(x + 1.4 * math.cos(t), y + 1.4 * math.sin(t), z + 2.2) for t in np.linspace(0, 2 * math.pi, 9)[:-1]]
            umb.add(ring_ + [(x, y, z + 2.75)], [[i, (i + 1) % 8, 8] for i in range(8)])
    return [n for n in (obj(deck, "hsw_felons_east_deck", col, rgbm("deck_boards", (0.36, 0.27, 0.19), "boards")),
                        obj(piles, "hsw_felons_east_piles", col, rgbm("piles", H["waterline"]["pile_rgb"], "pile")),
                        obj(rail, "hsw_felons_east_rail", col, rgbm("frames", (0.12, 0.12, 0.12))),
                        obj(umb, "hsw_felons_east_umbrellas", col, rgbm("umbrella", (0.86, 0.84, 0.78))),
                        obj(pole, "hsw_felons_east_poles", col, rgbm("frames", (0.12, 0.12, 0.12)))) if n]


def oakwood(col):
    """Round 6: the cream Oakwood apartments above HSW: regular balcony slabs on every floor with dark recesses."""
    rec = rec_by_osm().get(H["oakwood_way"])
    if rec is None:
        return []
    slabs, rec_ = C.MeshBuf(), C.MeshBuf()
    for ti, t in enumerate(rec["tiers"]):
        ring = [tuple(p) for p in t["ring"]]
        cx = sum(p[0] for p in ring) / len(ring)
        cy = sum(p[1] for p in ring) / len(ring)
        def grow(d):
            out = []
            for x, y in ring:
                r_ = math.hypot(x - cx, y - cy) or 1.0
                out.append((cx + (x - cx) * (r_ + d) / r_, cy + (y - cy) * (r_ + d) / r_))
            return out
        z0 = rec["base_ahd"] + 4.0 if ti == 0 else rec["tiers"][ti - 1]["top_ahd"]
        z = z0
        while z < t["top_ahd"] - 1.0:
            slabs.prism(grow(1.6), z, z + 0.22)                               # balcony slab
            rec_.prism(grow(0.05), z + 0.22, z + 2.4)                         # dark recess band (glass behind)
            z += 3.0
        slabs.prism(grow(1.6), t["top_ahd"] - 0.3, t["top_ahd"] + 0.3)
    return [n for n in (obj(slabs, "hsw_oakwood_balconies", col, rgbm("oakwood_cream", (0.78, 0.71, 0.56))),
                        obj(rec_, "hsw_oakwood_recess", col, rgbm("oakwood_glass", (0.06, 0.07, 0.08), "glass_green"))) if n]


def mangroves(col):
    import foliage as FO
    M = H["mangroves"]
    rnd = random.Random(M["seed"])
    fo = FO.Foliage(seed=M["seed"])
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
            r = rnd.uniform(1.4, 2.8)
            fo.cloud((xx, yy, z + r * 0.55), (r, r, r * 0.7), int(30 + 10 * r * r), 0.5, shell=0.2, top_bias=0.4)
            n += 1
    ob = fo.object("hsw_mangroves", col, (0.035, 0.07, 0.025), (0.09, 0.15, 0.05))   # r5: leaf cards, not blobs
    return ([ob.name] if ob else []), n


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
                if not C.point_in_ring(x, y, ring) or rnd.random() < 0.25:
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
            if nplant % 2 == 0 and x > 612.0:
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
    names_h = hotel_skin(col)
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
        wr.inputs["To Max"].default_value = 0.7
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
    elif kind == "stripes":
        # r4: striped fabric awnings (photo p12): bands across the awning, 0.6 m wide
        sep = nodes.new("ShaderNodeSeparateXYZ")
        links.new(geo.outputs["Position"], sep.inputs[0])
        add = nodes.new("ShaderNodeMath")
        add.operation = "ADD"
        links.new(sep.outputs["X"], add.inputs[0])
        links.new(sep.outputs["Y"], add.inputs[1])
        pp = nodes.new("ShaderNodeMath")
        pp.operation = "PINGPONG"
        links.new(add.outputs[0], pp.inputs[0])
        pp.inputs[1].default_value = 0.6
        lt = nodes.new("ShaderNodeMath")
        lt.operation = "LESS_THAN"
        links.new(pp.outputs[0], lt.inputs[0])
        lt.inputs[1].default_value = 0.3
        c1 = mix_rgb(lt.outputs[0], base, (0.22, 0.22, 0.23, 1))
        links.new(c1, bsdf.inputs["Base Color"])
        bsdf.inputs["Roughness"].default_value = 0.8
    elif kind == "pile":
        # r4: weathered timber with a dark wet band and green slime below the tide line (~1.2 m AHD)
        sep = nodes.new("ShaderNodeSeparateXYZ")
        links.new(geo.outputs["Position"], sep.inputs[0])
        mr = nodes.new("ShaderNodeMapRange")
        links.new(sep.outputs["Z"], mr.inputs["Value"])
        mr.inputs["From Min"].default_value, mr.inputs["From Max"].default_value = 1.0, 1.6
        mr.inputs["To Min"].default_value, mr.inputs["To Max"].default_value = 1.0, 0.0
        nz = nodes.new("ShaderNodeTexNoise")
        nz.inputs["Scale"].default_value = 3.0
        links.new(geo.outputs["Position"], nz.inputs["Vector"])
        c0 = mix_rgb(nz.outputs["Fac"], tuple(c * 0.8 for c in base[:3]) + (1,), tuple(min(1, c * 1.2) for c in base[:3]) + (1,))
        c1 = mix_rgb(mr.outputs["Result"], c0, (0.03, 0.04, 0.025, 1))
        links.new(c1, bsdf.inputs["Base Color"])
        bsdf.inputs["Roughness"].default_value = 0.9
    elif kind == "pave":
        # r4: sand-pink concrete pavers 0.6 x 0.3 m with darker joints and warm blotches (photo p10)
        br = nodes.new("ShaderNodeTexBrick")
        links.new(geo.outputs["Position"], br.inputs["Vector"])
        br.inputs["Scale"].default_value = 1.0
        br.inputs["Brick Width"].default_value = 0.6
        br.inputs["Row Height"].default_value = 0.3
        br.inputs["Mortar Size"].default_value = 0.012
        br.inputs["Color1"].default_value = base
        br.inputs["Color2"].default_value = tuple(c * 0.9 for c in base[:3]) + (1,)
        br.inputs["Mortar"].default_value = tuple(c * 0.6 for c in base[:3]) + (1,)
        nz = nodes.new("ShaderNodeTexNoise")
        nz.inputs["Scale"].default_value = 0.1
        links.new(geo.outputs["Position"], nz.inputs["Vector"])
        c1 = mix_rgb(nz.outputs["Fac"], br.outputs["Color"], tuple(c * 0.85 for c in base[:3]) + (1,), "MULTIPLY")
        links.new(c1, bsdf.inputs["Base Color"])
        bsdf.inputs["Roughness"].default_value = 0.9
    elif kind == "chevron":
        # r6: VERTICAL columns (2.4 m) of offset parallelogram panels in white, light grey and charcoal, every 4th
        # column a dark glass bay (photos p09, p07, p13): reads light-to-mid
        uv = nodes.new("ShaderNodeUVMap")
        uv.uv_map = "facade"
        sep = nodes.new("ShaderNodeSeparateXYZ")
        links.new(uv.outputs["UV"], sep.inputs[0])

        def m_(op, a, b=None):
            n_ = nodes.new("ShaderNodeMath")
            n_.operation = op
            for i_, v_ in enumerate((a, b)):
                if v_ is None:
                    continue
                if isinstance(v_, (int, float)):
                    n_.inputs[i_].default_value = v_
                else:
                    links.new(v_, n_.inputs[i_])
            return n_.outputs[0]
        u_, v_ = sep.outputs["X"], sep.outputs["Y"]
        col_ = m_("FLOOR", m_("DIVIDE", u_, 2.4))
        glass = m_("GREATER_THAN", m_("FLOORED_MODULO", col_, 4.0), 2.5)
        par = m_("FLOORED_MODULO", col_, 2.0)                       # 0 / 1: alternate columns lean the other way
        sgn = m_("SUBTRACT", 1.0, m_("MULTIPLY", par, 2.0))
        vv = m_("ADD", m_("ADD", v_, m_("MULTIPLY", m_("MULTIPLY", m_("FRACT", m_("DIVIDE", u_, 2.4)), 1.3), sgn)),
                m_("MULTIPLY", par, 1.6))
        tone = m_("DIVIDE", m_("FLOORED_MODULO", m_("FLOOR", m_("DIVIDE", vv, 3.2)), 3.0), 3.0)
        ramp = nodes.new("ShaderNodeValToRGB")
        ramp.color_ramp.interpolation = "CONSTANT"
        el = ramp.color_ramp.elements
        el[0].position, el[0].color = 0.0, (0.72, 0.71, 0.68, 1)
        el[1].position, el[1].color = 0.30, (0.42, 0.42, 0.41, 1)
        e3 = el.new(0.6)
        e3.color = (0.07, 0.07, 0.075, 1)
        links.new(tone, ramp.inputs["Fac"])
        c1 = mix_rgb(glass, ramp.outputs["Color"], (0.03, 0.035, 0.045, 1))
        links.new(c1, bsdf.inputs["Base Color"])
        rr_ = nodes.new("ShaderNodeMapRange")
        links.new(glass, rr_.inputs["Value"])
        rr_.inputs["To Min"].default_value, rr_.inputs["To Max"].default_value = 0.7, 0.08
        links.new(rr_.outputs["Result"], bsdf.inputs["Roughness"])
