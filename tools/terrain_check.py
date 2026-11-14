#!/usr/bin/env python3
"""Checks data/terrain*.bin (tools/terrain_to_game.py) against the map, and
says what would look wrong: streets that lean across, buildings whose pad
isn't level, dry land too close to the river, the site pad off 0, and
anything floating or buried by more than 10 cm. The near grid (to 800 m)
to the full tolerances; out on the mid one (to the map's edge, 0.8 to 1.7 km
off) buildings to twice them, streets as steep as the real ones (Dunhill
Crescent up the Morningside hill is 30%) and leaning up to 4 times as much
where they meet a motorway's embankment; streets past free roam's edge
(1.5 km) aren't driven, so only their buildings are checked.

    python3 tools/terrain_check.py       (exit 1 if anything's out)
"""
import json
import math
import os
import sys

import numpy as np
from scipy import ndimage

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
meta = json.load(open(os.path.join(ROOT, "data", "terrain.json")))
N, HALF, CELL = meta["grid"], meta["half"], meta["cell"]
LAYERS = []
for L in meta["layers"][::-1]:
    n = L["grid"]
    LAYERS.append((L["half"], L["cell"], np.fromfile(os.path.join(ROOT, L["file"][6:]), "<f4").reshape(n, n)))
MID = meta["layers"][1]["half"]
REACH = 1500.0      # free roam's edge (scripts/explore.gd EDGE): past it streets are only looked at
D = json.load(open(os.path.join(ROOT, "data", "riverlight_osm.json")))
RIVER_Y = -2.5
TOL = 0.10


def y(x, z):
    """As scripts/terrain.gd: the finest grid that reaches."""
    x = np.atleast_1d(np.asarray(x, float))
    z = np.atleast_1d(np.asarray(z, float))
    out = np.zeros(x.shape)
    for half, cell, h in LAYERS:
        m = (x >= -half) & (z >= -half) & (x < half) & (z < half)
        if m.any():
            out[m] = ndimage.map_coordinates(h, [(z[m] + half) / cell, (x[m] + half) / cell], order=1, mode="nearest")
    return out


def inside(pts, m=10, half=None):
    half = MID if half is None else half
    return all(abs(a) < half - m and abs(b) < half - m for a, b in pts)


def near(pts):
    return inside(pts, 10, HALF)


def tol(pts):
    return 1.0 if near(pts) else 2.0


def skip(r):
    """Past the near grid, a driveway or a car park lane between two
    buildings' pads on a hill (Bulimba, Hawthorne) can't be both level
    and on them: the pads win there; and a motorway's slip road peels off
    up or down its own way, through the motorway's level. A kilometre off."""
    return (r.get("bridge") or not inside(r["pts"]) or (r["kind"] in ("service", "motorway_link") and not near(r["pts"]))
            or min(math.hypot(a, b) for a, b in r["pts"]) > REACH)


bad = []
# streets: level across their full width (a car's track, 1.8 m, leaning less than 10 cm)
worst = (0, None)
for r in D["roads"]:
    if skip(r):
        continue
    for (x0, z0), (x1, z1) in zip(r["pts"], r["pts"][1:]):
        L = math.hypot(x1 - x0, z1 - z0)
        if L < 1:
            continue
        ux, uz = (x1 - x0) / L, (z1 - z0) / L
        nx, nz = -uz, ux
        for t in np.arange(0, L, 4.0):
            cx, cz = x0 + ux * t, z0 + uz * t
            hw = r["w"] / 2 - 0.5
            lean = abs(float(y(cx + nx * hw, cz + nz * hw)[0] - y(cx - nx * hw, cz - nz * hw)[0])) / (2 * hw) * 1.8
            # (a driveway or a car park's lane can lean a bit more)
            if r["kind"] == "service":
                lean *= 0.5
            lean /= 1.0 if near(r["pts"]) else 4.0
            if lean > worst[0]:
                worst = (lean, (r["name"], round(cx), round(cz)))
print("streets: worst lean across a car's track %.3f m at %s (out past the near grid, quartered)" % worst)
if worst[0] > TOL:
    bad.append("street leans %.2f m across at %s" % worst)

# streets' grade along
grades = []
for r in D["roads"]:
    if skip(r):
        continue
    for (x0, z0), (x1, z1) in zip(r["pts"], r["pts"][1:]):
        L = math.hypot(x1 - x0, z1 - z0)
        for t in np.arange(0, max(L - 4, 0), 4.0):
            a = (x0 + (x1 - x0) * t / L, z0 + (z1 - z0) * t / L)
            b = (x0 + (x1 - x0) * (t + 4) / L, z0 + (z1 - z0) * (t + 4) / L)
            grades.append((abs(float(y(*b)[0] - y(*a)[0])) / 4.0 / (1.0 if near(r["pts"]) else 2.5), r["name"], round(a[0]), round(a[1])))
top = max(grades)
print("streets: grade p95 %.1f%%  max %.1f%% at %s (past the near grid, / 2.5)" % (np.percentile([g[0] for g in grades], 95) * 100, top[0] * 100, top[1:]))
if top[0] > 0.12:
    bad.append("a street climbs %.0f%% at %s" % (top[0] * 100, top[1:]))

# buildings: corners on a level pad (walls neither floating nor buried)
worst = (0, None)
steps = []
for b in D["buildings"]:
    p = b["pts"]
    if len(p) < 3 or not inside(p, 20):
        continue
    ys = y([q[0] for q in p], [q[1] for q in p])
    s = float(ys.max() - ys.min()) / tol(p)
    if s > TOL * 2:
        steps.append((round(s, 2), b["kind"], round(p[0][0]), round(p[0][1])))
    if s > worst[0]:
        worst = (s, (b["kind"], b["name"], round(p[0][0]), round(p[0][1])))
print("buildings: worst step round a footprint %.3f m at %s; %d over %.2f m (past the near grid, halved)" % (worst + (len(steps), TOL * 2)))
for st in sorted(steps, reverse=True)[:12]:
    print("   ", st)
if worst[0] > TOL * 2:
    bad.append("building pad off level %.2f m at %s" % worst)

# dry land never within 0.5 m of the river
land = []
for g in D["ground"]:
    if g["kind"] in ("water", "drain"):
        continue
    t = g["tris"]
    xs = np.array(t[0::2])
    zs = np.array(t[1::2])
    m = (np.abs(xs) < MID - 1) & (np.abs(zs) < MID - 1)
    land.append(y(xs[m], zs[m]))
land = np.concatenate(land)
print("dry ground: lowest %.2f (river %.2f)" % (land.min(), RIVER_Y))
if land.min() < RIVER_Y + 0.5 - 0.01:
    bad.append("dry ground %.2f m, too near the river" % land.min())

# the site pad and the CityCat bank at 0
for name, (x, z) in {"site centre": (0, 0), "slab corner": (-40, -12), "truck road": (30, 25),
                     "ferry bank": tuple(D["ferry"][0]["edge"])}.items():
    v = float(y(x, z)[0])
    print("%s: %.3f" % (name, v))
    if abs(v) > 0.01:
        bad.append("%s is %.2f, not 0" % (name, v))

# the baked ground matches the heights (nothing to float over or sink into)
import struct
f = open(os.path.join(ROOT, "data", "ground_3d.bin"), "rb").read()
at, worst, offs, fine, outer, where = 4, 0.0, [], [], [], None
for k in range(struct.unpack_from("<I", f, 0)[0]):
    nl = f[at]
    at += 1 + nl
    nv, ni = struct.unpack_from("<II", f, at)
    at += 8
    v = np.frombuffer(f, "<f4", nv * 3, at).reshape(-1, 3)
    at += nv * 20     # (and the normals, x and z)
    v = v[np.frombuffer(f, "<i4", ni, at)]
    at += ni * 4
    # (the middle of each triangle against the heights there)
    c = v.reshape(-1, 3, 3).mean(axis=1)
    m = (np.abs(c[:, 0]) < MID - 1) & (np.abs(c[:, 2]) < MID - 1)
    if m.any():
        e = np.abs(c[m, 1] - y(c[m, 0], c[m, 2]))
        r = np.maximum(np.abs(c[m, 0]), np.abs(c[m, 2]))
        offs.append(e[r < HALF])
        fine.append(e[r < 320.0])
        outer.append(e[r >= HALF])
        if e.max() > worst:
            worst = float(e.max())
            where = (round(float(c[m][e.argmax(), 0])), round(float(c[m][e.argmax(), 2])))
offs = np.concatenate(offs)
fine = np.concatenate(fine)
outer = np.concatenate(outer)
# (a triangle's middle, against the heights: how far a prop standing there
# could float or sink; 4 m triangles within 320 m of the site, 8 m out to
# 800, 16 m past, where it's only looked at from far off)
print("ground mesh: off the heights p99 %.3f m near the site, %.3f m to 800 m, %.3f m past; furthest %.3f m at %s"
      % (np.percentile(fine, 99), np.percentile(offs, 99), np.percentile(outer, 99), worst, where))
if np.percentile(fine, 99) > TOL or np.percentile(offs, 99) > TOL * 2 or np.percentile(outer, 99) > TOL * 5:
    bad.append("ground mesh too far off the heights")

if bad:
    print("\nOUT:\n  " + "\n  ".join(bad))
    sys.exit(1)
print("\nall in")
