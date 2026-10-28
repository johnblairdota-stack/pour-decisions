#!/usr/bin/env python3
"""The Hamilton Reach estate next door to Riverlight as it stood in July 2017,
traced by hand off the Queensland Government aerial (Brisbane 2017 10 cm
SISP, 1-19 Jul 2017; 800 x 800 m, 0.2 m a pixel, north up, centred on
Riverlight's footprint centroid; /mnt/project-files/visuals/photos/
qld_aerial_2017_site_800m.jpg). OpenStreetMap only has a handful of these
buildings, so the game's map (data/riverlight_osm.json) left the estate bare.

Writes data/hamilton_reach_2017.json in the game frame (tools/osm_to_game.py)
for scripts/neighbours.gd:

  blocks  [{name, kind, storeys, pts}]  apartment blocks and terrace rows
  houses  [{at, face}]                  the two-storey houses along the golf
                                        course, `face` the way the front looks
  parked  [[x, z, yaw]]                 the car yard over MacArthur Avenue
                                        (packed solid in 2017) and the cars in
                                        the riverside car park by the CityCat

    python3 tools/estate_to_game.py

Storeys are a judgement off the aerial (roof plant, shadows) and the estate's
2009 master plan (five storeys in the river and park precincts).
"""
import json
import math
import os
import random


ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "data", "hamilton_reach_2017.json")
PX = 0.2            # metres a pixel
MID = 2000.0        # the image's centre pixel is Riverlight's centroid
TURN = -14.4        # as tools/osm_to_game.py


def game(px, py):
	"""Aerial pixel -> game x, z."""
	e = (px - MID) * PX
	n = (MID - py) * PX
	a = math.radians(-TURN)
	e2 = e * math.cos(a) - n * math.sin(a)
	n2 = e * math.sin(a) + n * math.cos(a)
	return (-e2, n2)


def gdir(dx, dy):
	"""An aerial pixel direction -> a game direction."""
	x0, z0 = game(MID, MID)
	x1, z1 = game(MID + dx, MID + dy)
	ln = math.hypot(x1 - x0, z1 - z0)
	return ((x1 - x0) / ln, (z1 - z0) / ln)


def rect(a, b, w):
	"""A rectangle w pixels wide along the centreline a -> b."""
	dx, dy = b[0] - a[0], b[1] - a[1]
	ln = math.hypot(dx, dy)
	nx, ny = -dy / ln * w / 2, dx / ln * w / 2
	return [(a[0] + nx, a[1] + ny), (b[0] + nx, b[1] + ny), (b[0] - nx, b[1] - ny), (a[0] - nx, a[1] - ny)]


# name: (kind, storeys, outline in aerial pixels)
BLOCKS = {
	# the long block on the golf course corner, two wings meeting at the top
	"A1": ("apartments", 5, rect((2235, 1495), (2345, 1760), 70)),
	"A2": ("apartments", 5, rect((2265, 1465), (2530, 1715), 85)),
	# terrace rows round the pool
	"B": ("terraces", 3, rect((2370, 1785), (2435, 2060), 105)),
	"C": ("terraces", 3, rect((2520, 1740), (2640, 1880), 115)),
	"D": ("terraces", 3, rect((2640, 1895), (2760, 2040), 115)),
	"E": ("terraces", 3, [(2480, 2055), (2675, 2095), (2665, 2190), (2475, 2150)]),
	# the blocks down to the river
	"G1": ("apartments", 5, rect((2800, 2330), (2560, 2530), 120)),
	"G2": ("apartments", 5, rect((2550, 2520), (2420, 2680), 140)),
	"H1": ("terraces", 3, rect((2930, 2435), (3010, 2580), 90)),
	"H2": ("terraces", 2, [(2800, 2510), (2890, 2510), (2890, 2580), (2800, 2580)]),
	"I": ("terraces", 3, [(3060, 2535), (3280, 2545), (3280, 2600), (3060, 2595)]),
	"J": ("terraces", 3, [(2730, 2600), (3020, 2600), (3020, 2720), (2730, 2715)]),
	"K": ("terraces", 3, [(3050, 2615), (3360, 2640), (3355, 2735), (3050, 2725)]),
	"L": ("apartments", 4, [(2500, 2750), (2665, 2755), (2690, 2830), (2690, 2975), (2380, 2975),
		(2350, 2900), (2410, 2830), (2500, 2830)]),
	"M": ("apartments", 5, [(2130, 2750), (2410, 2740), (2410, 2900), (2130, 2910)]),
}

# The houses along the golf course, centres off a 0.8x crop at (1400, 600):
# a front row on the street and a back row behind, all facing south-west
HOUSE_CROP = [(150, 125), (100, 185), (215, 180), (155, 240), (275, 245), (215, 305), (335, 305),
	(270, 365), (385, 370), (330, 430), (445, 435), (390, 490), (505, 490), (445, 550), (565, 550),
	(505, 610), (610, 610), (560, 660), (645, 680)]
HOUSE_FACE = (-0.72, 0.70)

# Car parks: (outline, holes, how full); cars nose up/down the image in
# double rows with an aisle between
CARPARKS = [
	([(700, 880), (1010, 880), (1180, 1060), (1350, 1220), (1490, 1400), (1520, 1520), (1520, 2000),
		(1100, 2000), (1100, 1850), (700, 1850)], [(830, 1530, 1000, 1810), (700, 1400, 1520, 1440)], 0.86),
	([(790, 2090), (1090, 2100), (1180, 2350), (1100, 2520), (780, 2520)], [], 0.5),
]


def inside(p, poly):
	"""Point in polygon (even-odd)."""
	x, y = p
	c = False
	for i in range(len(poly)):
		x1, y1 = poly[i]
		x2, y2 = poly[(i + 1) % len(poly)]
		if (y1 > y) != (y2 > y) and x < (x2 - x1) * (y - y1) / (y2 - y1) + x1:
			c = not c
	return c


def main():
	blocks = []
	for name, (kind, storeys, pts) in BLOCKS.items():
		g = [game(*p) for p in pts]
		blocks.append({"name": name, "kind": kind, "storeys": storeys,
			"pts": [[round(x, 1), round(z, 1)] for x, z in g]})
	face = gdir(*HOUSE_FACE)
	houses = []
	for cx, cy in HOUSE_CROP:
		x, z = game(1400 + cx / 0.8, 600 + cy / 0.8)
		houses.append({"at": [round(x, 1), round(z, 1)], "face": [round(face[0], 3), round(face[1], 3)]})
	parked = []
	rnd = random.Random(2017)
	for outline, holes, full in CARPARKS:
		xs = [p[0] for p in outline]
		ys = [p[1] for p in outline]
		x = min(xs) + 8
		while x < max(xs) - 8:
			y = min(ys) + 14
			k = 0
			while y < max(ys) - 14:
				if inside((x, y), outline) and not any(h[0] <= x <= h[2] and h[1] <= y <= h[3] for h in holes) \
						and rnd.random() < full:
					gx, gz = game(x, y)
					yaw = math.degrees(math.atan2(*gdir(0, -1 if k % 2 else 1)))
					parked.append([round(gx, 1), round(gz, 1), round(yaw + rnd.uniform(-4, 4))])
				# back to back pairs (5 m each), then a 6.5 m aisle
				y += 25 if k % 2 == 0 else 57.5
				k += 1
			x += 13
	out = {"source": "Traced from the Brisbane 2017 10 cm SISP aerial. Includes material (c) State of "
		"Queensland (Department of Natural Resources and Mines, Manufacturing and Regional and Rural "
		"Development), 2026, CC BY 4.0", "blocks": blocks, "houses": houses, "parked": parked}
	with open(OUT, "w") as f:
		json.dump(out, f, indent=1)
	print("wrote", OUT, len(blocks), "blocks", len(houses), "houses", len(parked), "parked cars")


if __name__ == "__main__":
	main()
