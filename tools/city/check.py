#!/usr/bin/env python3
"""Quick check of the Brisbane model's data. No Blender, standard Python only. CI runs it on every model PR.

    python3 tools/city/check.py

Fails (exit 1) on things that have gone wrong before or would spoil a render:
  - a building standing in the river
  - a building with an impossible height, a broken outline, or far outside the model box
  - two buildings with the same map id
  - more trees in the river, or more buildings in two data sets, than the counts in known.json
    (those counts only ever go down: fix some, then lower the number)
  - a measured tile with no buildings or no trees at all
  - the coverage files in docs/city being out of date
Warnings are printed but do not fail the check.
"""
import collections
import csv
import gzip
import json
import os
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
REF = os.path.join(ROOT, "reference", "sites", "spire")
TALLEST_M = 300.0          # Brisbane Skytower is 270 m; nothing real is taller
RIVER_EDGE_M = 6.0         # wharves and boardwalks reach a little over the water


class Water:
    def __init__(self):
        j = json.load(open(os.path.join(REF, "river", "river.json")))
        self.x0, self.y0, self.x1, self.y1 = j["box_local"]
        self.step, self.rows, self.cols = j["step_m"], j["rows"], j["cols"]
        self.m = gzip.open(os.path.join(REF, "river", "water_2m.u8.gz")).read()
        assert len(self.m) == self.rows * self.cols, "water mask size does not match river.json"

    def cell(self, x, y):
        c, r = int((x - self.x0) / self.step), int((self.y1 - y) / self.step)
        if 0 <= c < self.cols and 0 <= r < self.rows:
            return self.m[r * self.cols + c] != 0
        return False

    def deep(self, x, y):
        """True when the point and the points RIVER_EDGE_M round it are all water."""
        d = RIVER_EDGE_M
        return all(self.cell(x + dx, y + dy) for dx, dy in ((0, 0), (d, 0), (-d, 0), (0, d), (0, -d)))


def area(ring):
    return abs(sum(ring[i][0] * ring[i - 1][1] - ring[i - 1][0] * ring[i][1] for i in range(len(ring)))) / 2.0


def main():
    errors, warns = [], []
    water = Water()
    seen = collections.Counter()
    known = json.load(open(os.path.join(HERE, "known.json")))
    n_b = n_t = on_water = 0
    roofs = {b.get("osm") for b in json.load(open(os.path.join(REF, "wide", "buildings_wide.json")))["buildings"]
             if b.get("tags", {}).get("building") == "roof"}
    for path in ("wide/buildings_wide.json", "lidar/buildings_clean.json", "ext/buildings_ext.json"):
        box = json.load(open(os.path.join(REF, "wide", "wide.json")))["box_local"]
        river_hits = []
        for b in json.load(open(os.path.join(REF, path)))["buildings"]:
            n_b += 1
            tag = "%s building osm %s" % (path.split("/")[0], b.get("osm"))
            seen[(path, b.get("osm"))] += 1
            ring = b["tiers"][0]["ring"]
            if len(ring) < 3 or area(ring) < 1.0:
                errors.append("%s: broken outline" % tag)
                continue
            cx, cy = sum(p[0] for p in ring) / len(ring), sum(p[1] for p in ring) / len(ring)
            top = max(t["top_ahd"] for t in b["tiers"])
            h = top - b["base_ahd"]
            if h > TALLEST_M:
                errors.append("%s: height %.1f m" % (tag, h))
            if h < 0.5:
                errors.append("%s: height %.1f m" % (tag, h))
            if not (box[0] - 1500 <= cx <= box[2] + 1500 and box[1] - 1500 <= cy <= box[3] + 1500):
                errors.append("%s: at (%.0f, %.0f), far outside the model" % (tag, cx, cy))
            if water.deep(cx, cy):
                kind = b.get("tags", {}).get("building", "")
                if kind == "roof" or b.get("osm") in roofs or b.get("osm") in known["on_water_ok"]:
                    on_water += 1                    # ferry stop covers, pontoons and piers really do stand in the river
                else:
                    errors.append("in the river: %s (%s) at (%.0f, %.0f)" % (tag, b.get("name") or kind or "?", cx, cy))
            if h < 0.5 and b.get("osm") in known["flat_ok"]:
                errors.pop()
    by_id = collections.Counter()
    for (path, osm), n in seen.items():
        if n > 1 and osm:
            errors.append("%s: map id %s appears %d times" % (path, osm, n))
        by_id[osm] += 1
    twice = sum(1 for n in by_id.values() if n > 1)
    if twice > known["max_in_two_sets"]:
        errors.append("%d buildings are in two data sets (was %d): they would be built twice" % (twice, known["max_in_two_sets"]))
    elif twice:
        warns.append("%d buildings are in two data sets (the tile build will give each building one home)" % twice)
    if on_water:
        warns.append("%d ferry covers, pontoons and piers stand on the water (allowed)" % on_water)
    wet = 0
    for path in ("wide/tree_points_wide.csv", "lidar/tree_points.csv", "ext/tree_points_ext.csv"):
        rows = csv.reader(open(os.path.join(REF, path)))
        next(rows)
        for r in rows:
            n_t += 1
            if water.deep(float(r[0]), float(r[1])):
                wet += 1
    if wet > known["max_trees_in_river"]:
        errors.append("%d trees stand in the river (was %d)" % (wet, known["max_trees_in_river"]))
    elif wet:
        warns.append("%d of %d trees stand in the river" % (wet, n_t))
    cov = json.load(open(os.path.join(ROOT, "docs", "city", "coverage.json"))) if os.path.exists(os.path.join(ROOT, "docs", "city", "coverage.json")) else None
    if cov:
        for name, t in cov["tiles"].items():
            if t["lidar"] and t["buildings"] == 0 and name not in known.get("no_buildings_ok", []):
                errors.append("measured tile %s has no buildings" % name)
            if t["lidar"] and t["trees"] == 0:
                errors.append("measured tile %s has no trees" % name)
    if subprocess.call([sys.executable, os.path.join(HERE, "coverage.py"), "--check"]) != 0:
        errors.append("docs/city/coverage files are out of date: run python3 tools/city/coverage.py")
    print("checked %d buildings and %d trees" % (n_b, n_t))
    for w in warns:
        print("warning:", w)
    for e in errors[:60]:
        print("FAIL:", e)
    if len(errors) > 60:
        print("... and %d more" % (len(errors) - 60))
    print("city check: %s" % ("FAILED (%d)" % len(errors) if errors else "passed"))
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
