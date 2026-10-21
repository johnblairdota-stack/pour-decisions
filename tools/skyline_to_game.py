#!/usr/bin/env python3
"""Turns the skyline extract (reference/osm/skyline_osm.json, from
tools/skyline_fetch.py), the river out to the city (reference/osm/
osm_landmarks_wide.json) and the hand-placed far landmarks below into
data/riverlight_skyline.json, in the same game frame as tools/osm_to_game.py,
for scripts/surrounds.gd.

    python3 tools/skyline_to_game.py      (needs shapely)

Map data (c) OpenStreetMap contributors, ODbL 1.0.
"""
import json
import math
import os

from shapely.geometry import LineString, Point, Polygon
from shapely.ops import polygonize, unary_union

from osm_to_game import to_game

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "reference", "osm")
OUT = os.path.join(ROOT, "data", "riverlight_skyline.json")
NEAR = 1500.0        # closer than this, data/riverlight_osm.json already has it
RIVER_REL = (1627034, 1693549)

# Far landmarks the extract doesn't reach (lon, lat, height m, kind, name).
# Heights from public sources; see /mnt/project-files/visuals/skyline/research.md
LANDMARKS = []
# Hills as soft mounds (lon, lat, height m above the river, radius m, name)
HILLS = []


def ring(pts):
    return [[round(x, 1), round(z, 1)] for x, z in pts]


def tower_colour(tags, h):
    for k in ("building:colour", "colour"):
        v = tags.get(k, "")
        if v.startswith("#") and len(v) == 7:
            return v
    if h >= 90:
        return "8fa3b2"      # glass towers: blue-grey
    if h >= 45:
        return "c9ced0"      # concrete and glass residential towers
    return "ddd6c8"          # mid-rise: off-white and sandstone render


def main():
    sky = json.load(open(os.path.join(SRC, "skyline_osm.json")))
    towers = []
    masts = []
    for f in sky["features"]:
        tags = f["tags"]
        h = float(f.get("h") or 0.0)
        if "poly" in f:
            pts = [to_game(lon, lat) for lon, lat in f["poly"]]
            poly = Polygon(pts)
            if not poly.is_valid or poly.area < 30.0:
                continue
            if poly.centroid.distance(Point(0, 0)) < NEAR:
                continue
            if "building:part" in tags and "building" not in tags:
                pass
            h = h if h > 0 else 20.0
            towers.append({"pts": ring(list(poly.exterior.coords)[:-1]), "h": round(h, 1),
                           "c": tower_colour(tags, h), "name": tags.get("name", "")})
        elif "pt" in f and h > 0:
            x, z = to_game(*f["pt"])
            if math.hypot(x, z) >= NEAR:
                masts.append({"at": [round(x, 1), round(z, 1)], "h": round(h, 1), "name": tags.get("name", "")})
    # The river, all the way up to the city
    wide = json.load(open(os.path.join(SRC, "osm_landmarks_wide.json")))["elements"]
    lines = []
    for e in wide:
        if e["type"] == "relation" and e["id"] in RIVER_REL:
            for m in e["members"]:
                if m.get("geometry"):
                    lines.append(LineString([to_game(p["lon"], p["lat"]) for p in m["geometry"]]))
    water = []
    for p in polygonize(unary_union(lines)):
        if p.area > 2000.0:
            water.append(ring(list(p.simplify(4.0).exterior.coords)[:-1]))
    for lon, lat, h, kind, name in LANDMARKS:
        x, z = to_game(lon, lat)
        masts.append({"at": [round(x, 1), round(z, 1)], "h": h, "kind": kind, "name": name})
    hills = []
    for lon, lat, h, r, name in HILLS:
        x, z = to_game(lon, lat)
        hills.append({"at": [round(x, 1), round(z, 1)], "h": h, "r": r, "name": name})
    out = {"source": "OpenStreetMap contributors, ODbL 1.0; landmarks from public sources",
           "towers": towers, "masts": masts, "water": water, "hills": hills}
    json.dump(out, open(OUT, "w"), separators=(",", ":"))
    print("wrote %s: %d towers, %d masts, %d water, %d hills" % (OUT, len(towers), len(masts), len(water), len(hills)))


if __name__ == "__main__":
    main()
