#!/usr/bin/env python3
"""The 2825 tree tops found in the 2019 LiDAR (reference/elevation/
tree_points_2019.csv, tools/lidar/products.mjs) in the game frame, for
scripts/surrounds.gd to plant one tree at each at its real height.

Writes data/riverlight_trees_2019.json:

  trees  [[x, z, height]]   height above ground, metres
  tile   [[x, z] x 4]       the LiDAR tile's outline: inside it the game
                            plants these trees instead of made-up ones

    python3 tools/lidar_trees_to_game.py
"""
import csv
import json
import math
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "reference", "elevation", "tree_points_2019.csv")
OUT = os.path.join(ROOT, "data", "riverlight_trees_2019.json")
LAT0, LON0 = -27.4436709, 153.0855133   # as tools/osm_to_game.py
TURN = -14.4
M_LAT = 110860.0
M_LON = 111320.0 * math.cos(math.radians(LAT0))
E0, N0 = 508450.7, 6964419.7                     # the site's centre in MGA zone 56
TILE = (508000.0, 6964000.0, 509000.0, 6965000.0)  # the LiDAR tile, MGA


def to_game(lon, lat):
	e = (lon - LON0) * M_LON
	n = (lat - LAT0) * M_LAT
	a = math.radians(-TURN)
	return (-(e * math.cos(a) - n * math.sin(a)), e * math.sin(a) + n * math.cos(a))


def mga_game(e, n):
	"""MGA -> game, near enough over a kilometre (grid convergence ~0.04 deg)."""
	return to_game(LON0 + (e - E0) / M_LON, LAT0 + (n - N0) / M_LAT)


def main():
	trees = []
	for r in csv.DictReader(open(SRC)):
		x, z = to_game(float(r["lon"]), float(r["lat"]))
		trees.append([round(x, 1), round(z, 1), round(float(r["height_above_ground_m"]), 1)])
	tile = [[round(v, 1) for v in mga_game(e, n)] for e, n in
		[(TILE[0], TILE[1]), (TILE[2], TILE[1]), (TILE[2], TILE[3]), (TILE[0], TILE[3])]]
	out = {"source": "Tree tops from the Brisbane 2019 LiDAR. Includes material (c) State of Queensland, CC BY 4.0",
		"trees": trees, "tile": tile}
	with open(OUT, "w") as f:
		json.dump(out, f, separators=(",", ":"))
	print("wrote", OUT, len(trees), "trees")


if __name__ == "__main__":
	main()
