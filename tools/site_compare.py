#!/usr/bin/env python3
"""Puts the game's surroundings side by side with the real site data and
measures the gaps. Feed it the top-down shots from tools/site_compare.gd:

    godot --rendering-driver opengl3 --resolution 1500x1500 --path . \\
        --script res://tools/site_compare.gd -- --out=DIR
    python3 tools/site_compare.py DIR

Compares, in the game frame (tools/osm_to_game.py), 1 m a pixel:
  - the game from above against the July 2017 aerial (Brisbane 2017 10 cm SISP)
  - heights against the 2019 LiDAR surface (reference/elevation, 1 km tile
    round the site only), overall and building by building
  - the game's trees against the 2825 LiDAR tree tops
  - the game's flat ground against the real ground heights (AHD)

Writes PNGs and report.json into DIR. Needs numpy and Pillow.
"""
import csv
import json
import math
import os
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
REF = os.path.join(ROOT, "reference")
LAT0, LON0 = -27.4436709, 153.0855133
TURN = -14.4
M_LAT = 110860.0
M_LON = 111320.0 * math.cos(math.radians(LAT0))
E0, N0 = 508450.7, 6964419.7          # Riverlight centre in MGA zone 56
BOX_E, BOX_N = 507700.0, 6965170.0    # top-left of the 1500 m elevation box
TILE = (508000.0, 6964000.0, 509000.0, 6965000.0)   # the one LiDAR tile with a surface model
GAME = 1500                           # game shots: pixels = metres
LOW, SPAN = -10.0, 160.0              # tools/site_compare.gd height packing
VIEW = 800                            # metres shown in the side-by-sides
SITE = [(-50, -32), (50, -32), (50, 32), (-50, 32)]   # Riverlight itself (built by the levels, not here)


def to_game(lon, lat):
	e = (lon - LON0) * M_LON
	n = (lat - LAT0) * M_LAT
	a = math.radians(-TURN)
	return (-(e * math.cos(a) - n * math.sin(a)), e * math.sin(a) + n * math.cos(a))


def grid():
	"""Game x, z and local east, north (metres from the centre) of every game pixel."""
	c = np.arange(GAME) + 0.5
	x = GAME / 2 - c[None, :] * np.ones((GAME, 1))     # image right = -x (east)
	z = GAME / 2 - c[:, None] * np.ones((1, GAME))     # image up = +z (north)
	a = math.radians(-TURN)
	e2, n2 = -x, z
	e = e2 * math.cos(a) + n2 * math.sin(a)
	n = -e2 * math.sin(a) + n2 * math.cos(a)
	return x, z, e, n


def px(x, z):
	"""Game x, z -> game image column, row."""
	return (GAME / 2 - x, GAME / 2 - z)


def sample(img, cols, rows):
	"""Nearest sample of a 2D array; NaN outside."""
	h, w = img.shape[:2]
	ci, ri = np.floor(cols).astype(int), np.floor(rows).astype(int)
	ok = (ci >= 0) & (ri >= 0) & (ci < w) & (ri < h)
	out = np.full(cols.shape + img.shape[2:], np.nan, dtype=float)
	out[ok] = img[ri[ok], ci[ok]]
	return out


def game_heights(path):
	a = np.asarray(Image.open(path).convert("RGB")).astype(float)
	h = ((a[..., 0] - 64) * 128 + (a[..., 1] - 64)) / 16383 * SPAN + LOW
	h[a[..., 2] < 64] = np.nan
	return h


def mask(polys):
	"""Game-image mask of game-frame polygons."""
	im = Image.new("L", (GAME, GAME), 0)
	d = ImageDraw.Draw(im)
	for p in polys:
		d.polygon([px(*q) for q in p], fill=1)
	return np.asarray(im).astype(bool)


def crop(a):
	o = (GAME - VIEW) // 2
	return a[o:o + VIEW, o:o + VIEW]


def colourise(v, lo, hi, cmap):
	"""Values -> RGB through a list of (t, colour) stops; NaN grey."""
	t = np.clip((v - lo) / (hi - lo), 0, 1)
	out = np.zeros(v.shape + (3,))
	for (t0, c0), (t1, c1) in zip(cmap, cmap[1:]):
		m = (t >= t0) & (t <= t1)
		f = ((t - t0) / max(t1 - t0, 1e-9))[m][:, None]
		out[m] = np.array(c0) * (1 - f) + np.array(c1) * f
	out[np.isnan(v)] = (205, 205, 205)
	return out.astype(np.uint8)


DIVERGE = [(0.0, (33, 102, 172)), (0.5, (247, 247, 247)), (1.0, (178, 24, 43))]
SEQ = [(0.0, (247, 251, 255)), (0.4, (107, 174, 214)), (1.0, (8, 48, 107))]


def label(img, text):
	d = ImageDraw.Draw(img)
	try:
		f = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", 22)
	except OSError:
		f = ImageFont.load_default()
	d.rectangle([0, 0, img.width, 34], fill=(20, 20, 20))
	d.text((10, 6), text, fill=(255, 255, 255), font=f)
	return img


def side(a, b, ta, tb, out):
	w = Image.new("RGB", (a.width + b.width + 10, max(a.height, b.height)), (255, 255, 255))
	w.paste(label(a, ta), (0, 0))
	w.paste(label(b, tb), (a.width + 10, 0))
	w.save(out)


def main():
	out = sys.argv[1]
	x, z, e, n = grid()
	E, N = E0 + e, N0 + n
	in_tile = (E >= TILE[0]) & (E < TILE[2]) & (N >= TILE[1]) & (N < TILE[3])
	site = mask([SITE])
	report = {}

	# --- 1. From above against the July 2017 aerial
	aer = np.asarray(Image.open(os.path.join(REF, "photos", "qld_aerial_2017_site_800m.jpg")).convert("RGB"))
	a = sample(aer, 2000 + e / 0.2, 2000 - n / 0.2)
	a = np.nan_to_num(a, nan=255).astype(np.uint8)
	col = np.asarray(Image.open(os.path.join(out, "game_colour.png")).convert("RGB"))
	A, C = Image.fromarray(crop(a)), Image.fromarray(crop(col))
	side(A, C, "Real: July 2017 aerial", "Game: same view", os.path.join(out, "1_aerial_vs_game.png"))
	Image.blend(A, C, 0.5).save(os.path.join(out, "1_aerial_game_blend.png"))

	# --- 2. Heights against the 2019 LiDAR surface
	dsm = np.asarray(Image.open(os.path.join(REF, "elevation", "dsm_2019_2m_750px_u16.png"))).astype(float)
	gnd = np.asarray(Image.open(os.path.join(REF, "elevation", "heightmap_2m_750px_u16.png"))).astype(float)
	dsm = np.where(dsm > 0, dsm / 500 - 20, np.nan)
	gnd = np.where(gnd > 0, gnd / 1000 - 20, np.nan)
	cols, rows = (E - BOX_E) / 2, (BOX_N - N) / 2
	real_dsm, real_gnd = sample(dsm, cols, rows), sample(gnd, cols, rows)
	real_h = real_dsm - real_gnd
	real_h[~in_tile] = np.nan
	game_h = game_heights(os.path.join(out, "game_height.png"))
	game_g = np.nanmedian(game_h[(game_h > -1) & (game_h < 1)])
	game_h = game_h - game_g
	diff = game_h - real_h
	diff[site] = np.nan
	side(Image.fromarray(crop(colourise(real_h, 0, 40, SEQ))), Image.fromarray(crop(colourise(np.where(in_tile, game_h, np.nan), 0, 40, SEQ))),
		"Real height above ground (2019 LiDAR)", "Game height", os.path.join(out, "2_heights.png"))
	Image.fromarray(crop(colourise(diff, -15, 15, DIVERGE))).save(os.path.join(out, "2_height_diff.png"))
	ok = in_tile & ~site & ~np.isnan(diff)
	report["heights"] = {
		"tile_m2": int(ok.sum()),
		"real_built_or_tree_over_3m_pct": round(100 * float((real_h[ok] > 3).mean()), 1),
		"game_over_3m_pct": round(100 * float((game_h[ok] > 3).mean()), 1),
		"game_too_low_by_over_5m_pct": round(100 * float((diff[ok] < -5).mean()), 1),
		"game_too_high_by_over_5m_pct": round(100 * float((diff[ok] > 5).mean()), 1),
	}

	# Building by building: every OSM footprint in the tile, plus the traced 2017 estate blocks
	rows_out = []
	heights = {r["osm_id"]: r for r in csv.DictReader(open(os.path.join(REF, "elevation", "building_heights.csv")))}
	feats = json.load(open(os.path.join(REF, "osm", "osm_buildings.geojson")))["features"]
	for f in feats:
		g = f["geometry"]
		if g["type"] != "Polygon":
			continue
		poly = [to_game(lon, lat) for lon, lat in g["coordinates"][0]]
		rows_out.append((f["properties"].get("id"), f["properties"].get("name", ""), poly))
	estate = json.load(open(os.path.join(ROOT, "data", "hamilton_reach_2017.json")))
	for b in estate["blocks"]:
		rows_out.append(("estate/" + b["name"], "%s %d storeys (traced 2017)" % (b["kind"], b["storeys"]), [tuple(p) for p in b["pts"]]))
	builds = []
	for oid, name, poly in rows_out:
		m = mask([poly]) & ok
		if m.sum() < 40:
			continue
		r = np.nanpercentile(real_h[m], 90)
		gm = np.nanpercentile(game_h[m], 90)
		builds.append({"id": oid, "name": name, "area_m2": int(m.sum()), "real_m": round(float(r), 1),
			"game_m": round(float(gm), 1), "diff_m": round(float(gm - r), 1),
			"lidar_note": heights.get(oid, {}).get("note", "")})
	builds.sort(key=lambda b: -abs(b["diff_m"]) * math.sqrt(b["area_m2"]))
	report["buildings"] = builds

	# --- 3. Trees against the LiDAR tree tops
	real_t = []
	for r in csv.DictReader(open(os.path.join(REF, "elevation", "tree_points_2019.csv"))):
		gx, gz = to_game(float(r["lon"]), float(r["lat"]))
		real_t.append((gx, gz, float(r["height_above_ground_m"])))
	real_t = np.array(real_t)
	gt = json.load(open(os.path.join(out, "game_trees.json")))["trees"]
	game_t = np.array([(t[1], t[2], t[3]) for t in gt if t[3] > 3.0])
	species = {}
	for t in gt:
		if t[3] > 3.0:
			species[t[0]] = species.get(t[0], 0) + 1

	def inside(p):
		c, r = px(p[:, 0], p[:, 1])
		ci, ri = np.clip(c.astype(int), 0, GAME - 1), np.clip(r.astype(int), 0, GAME - 1)
		return in_tile[ri, ci] & ~site[ri, ci] & (np.abs(c - GAME / 2) < GAME / 2) & (np.abs(r - GAME / 2) < GAME / 2)

	rt, gtt = real_t[inside(real_t)], game_t[inside(game_t)]

	def nearest(a, b):
		d = np.sqrt(((a[:, None, :2] - b[None, :, :2]) ** 2).sum(-1))
		return d.min(1)

	dr, dg = nearest(rt, gtt), nearest(gtt, rt)
	report["trees"] = {
		"real_tree_tops_in_tile": len(rt), "game_trees_over_3m_in_tile": len(gtt),
		"real_with_game_tree_within_8m_pct": round(100 * float((dr < 8).mean()), 1),
		"game_with_real_tree_within_8m_pct": round(100 * float((dg < 8).mean()), 1),
		"real_height_median_m": round(float(np.median(rt[:, 2])), 1),
		"real_height_p90_m": round(float(np.percentile(rt[:, 2], 90)), 1),
		"game_height_median_m": round(float(np.median(gtt[:, 2])), 1),
		"game_height_p90_m": round(float(np.percentile(gtt[:, 2], 90)), 1),
		"game_species_over_3m": dict(sorted(species.items(), key=lambda s: -s[1])),
	}
	# Tree map: real tops in green, game trees in red, over the aerial
	base = Image.fromarray(crop(a)).convert("RGB")
	base = Image.blend(base, Image.new("RGB", base.size, (255, 255, 255)), 0.45)
	d = ImageDraw.Draw(base)
	o = (GAME - VIEW) / 2
	for (tx, tz, th), c in [(p, (30, 140, 40)) for p in real_t] + [(p, (215, 40, 40)) for p in game_t]:
		cx, cy = px(tx, tz)
		cx, cy = cx - o, cy - o
		if 0 <= cx < VIEW and 0 <= cy < VIEW:
			rr = 1.5 + th / 6
			d.ellipse([cx - rr, cy - rr, cx + rr, cy + rr], outline=c, width=2)
	# the LiDAR tile's edge
	edge = [px(*to_game(LON0 + (ee - E0) / M_LON, LAT0 + (nn - N0) / M_LAT)) for ee, nn in
		[(TILE[0], TILE[1]), (TILE[2], TILE[1]), (TILE[2], TILE[3]), (TILE[0], TILE[3]), (TILE[0], TILE[1])]]
	d.line([(p[0] - o, p[1] - o) for p in edge], fill=(60, 60, 60), width=2)
	label(base, "Trees: green = real LiDAR tree tops (2019), red = game trees")
	base.save(os.path.join(out, "3_trees.png"))

	# Trees per 50 m cell, game minus real
	cell = 50
	k = GAME // cell

	def counts(p):
		c, r = px(p[:, 0], p[:, 1])
		h, _, _ = np.histogram2d(r, c, bins=k, range=[[0, GAME], [0, GAME]])
		return h
	cmask = in_tile.reshape(k, cell, k, cell).mean((1, 3)) > 0.99
	cd = np.where(cmask, counts(game_t) - counts(real_t), np.nan)
	big = np.kron(cd, np.ones((cell, cell)))
	Image.fromarray(crop(colourise(big, -12, 12, DIVERGE))).save(os.path.join(out, "3_tree_density_diff.png"))

	# --- 4. Ground: the game is flat; the real ground isn't
	real_g_all = sample(gnd, cols, rows)
	land = (game_h > -0.5) & ~np.isnan(real_g_all) & (game_h < 1.5)
	water = np.abs(game_h + game_g - 0.02) < 0.05
	report["ground"] = {
		"game_ground_y": round(float(game_g), 2),
		"real_ground_ahd_median_on_game_land_m": round(float(np.nanmedian(real_g_all[land & ~water])), 2),
		"real_ground_ahd_p10_p90_m": [round(float(v), 2) for v in np.nanpercentile(real_g_all[land & ~water], [10, 90])],
		"real_ground_ahd_at_site_m": round(float(np.nanmedian(real_g_all[site])), 2),
		"river_mean_level_ahd_m": 0.1,
	}
	Image.fromarray(crop(colourise(np.where(water, np.nan, real_g_all), 0, 12, SEQ))).save(os.path.join(out, "4_real_ground_ahd.png"))

	json.dump(report, open(os.path.join(out, "report.json"), "w"), indent=1)
	print(json.dumps({k: v for k, v in report.items() if k != "buildings"}, indent=1))
	for b in builds[:20]:
		print(b)


if __name__ == "__main__":
	main()
