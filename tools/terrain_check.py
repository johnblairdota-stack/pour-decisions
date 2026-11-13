#!/usr/bin/env python3
"""Checks data/terrain.bin (tools/terrain_to_game.py) against the map, and
says what would look wrong: streets that lean across, buildings whose pad
isn't level, dry land too close to the river, the site pad off 0, and
anything floating or buried by more than 10 cm.

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
H = np.fromfile(os.path.join(ROOT, "data", "terrain.bin"), "<f4").reshape(N, N)
D = json.load(open(os.path.join(ROOT, "data", "riverlight_osm.json")))
RIVER_Y = -2.5
TOL = 0.10


def y(x, z):
    x = np.atleast_1d(np.asarray(x, float))
    z = np.atleast_1d(np.asarray(z, float))
    out = ndimage.map_coordinates(H, [(z + HALF) / CELL, (x + HALF) / CELL], order=1, mode="nearest")
    return np.where((np.abs(x) < HALF - 1) & (np.abs(z) < HALF - 1), out, 0.0)


def inside(pts, m=10):
    return all(abs(a) < HALF - m and abs(b) < HALF - m for a, b in pts)


bad = []
# streets: level across their full width (a car's track, 1.8 m, leaning less than 10 cm)
worst = (0, None)
for r in D["roads"]:
    if r.get("bridge") or not inside(r["pts"]):
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
            if lean > worst[0]:
                worst = (lean, (r["name"], round(cx), round(cz)))
print("streets: worst lean across a car's track %.3f m at %s" % worst)
if worst[0] > TOL:
    bad.append("street leans %.2f m across at %s" % worst)

# streets' grade along
grades = []
for r in D["roads"]:
    if r.get("bridge") or not inside(r["pts"]):
        continue
    for (x0, z0), (x1, z1) in zip(r["pts"], r["pts"][1:]):
        L = math.hypot(x1 - x0, z1 - z0)
        for t in np.arange(0, max(L - 4, 0), 4.0):
            a = (x0 + (x1 - x0) * t / L, z0 + (z1 - z0) * t / L)
            b = (x0 + (x1 - x0) * (t + 4) / L, z0 + (z1 - z0) * (t + 4) / L)
            grades.append(abs(float(y(*b)[0] - y(*a)[0])) / 4.0)
print("streets: grade p95 %.1f%%  max %.1f%%" % (np.percentile(grades, 95) * 100, max(grades) * 100))
if max(grades) > 0.12:
    bad.append("a street climbs %.0f%%" % (max(grades) * 100))

# buildings: corners on a level pad (walls neither floating nor buried)
worst = (0, None)
steps = []
for b in D["buildings"]:
    p = b["pts"]
    if len(p) < 3 or not inside(p, 20):
        continue
    ys = y([q[0] for q in p], [q[1] for q in p])
    s = float(ys.max() - ys.min())
    if s > TOL * 2:
        steps.append((round(s, 2), b["kind"], round(p[0][0]), round(p[0][1])))
    if s > worst[0]:
        worst = (s, (b["kind"], b["name"], round(p[0][0]), round(p[0][1])))
print("buildings: worst step round a footprint %.3f m at %s; %d over %.2f m" % (worst + (len(steps), TOL * 2)))
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
    m = (np.abs(xs) < HALF - 1) & (np.abs(zs) < HALF - 1)
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
at, worst, offs, fine, where = 4, 0.0, [], [], None
for k in range(struct.unpack_from("<I", f, 0)[0]):
    nl = f[at]
    at += 1 + nl
    nv = struct.unpack_from("<I", f, at)[0]
    at += 4
    v = np.frombuffer(f, "<f4", nv * 3, at).reshape(-1, 3)
    at += nv * 12
    # (the middle of each triangle against the heights there)
    c = v.reshape(-1, 3, 3).mean(axis=1)
    m = (np.abs(c[:, 0]) < HALF - 1) & (np.abs(c[:, 2]) < HALF - 1)
    if m.any():
        e = np.abs(c[m, 1] - y(c[m, 0], c[m, 2]))
        offs.append(e)
        fine.append(e[np.maximum(np.abs(c[m, 0]), np.abs(c[m, 2])) < 320.0])
        if e.max() > worst:
            worst = float(e.max())
            where = (round(float(c[m][e.argmax(), 0])), round(float(c[m][e.argmax(), 2])))
offs = np.concatenate(offs)
fine = np.concatenate(fine)
# (a triangle's middle, against the heights: how far a prop standing there
# could float or sink; 4 m triangles within 320 m of the site, 8 m out)
print("ground mesh: off the heights p99 %.3f m near the site, %.3f m everywhere; furthest %.3f m at %s"
      % (np.percentile(fine, 99), np.percentile(offs, 99), worst, where))
if np.percentile(fine, 99) > TOL or np.percentile(offs, 99) > TOL * 2:
    bad.append("ground mesh too far off the heights")

if bad:
    print("\nOUT:\n  " + "\n  ".join(bad))
    sys.exit(1)
print("\nall in")
