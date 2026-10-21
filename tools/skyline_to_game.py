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

# The game is set in 2016-18: towers in the map that went up after that
BUILT_LATER = {"The One Residences", "300 George", "Queen's Wharf Residences",
               "443 Queen Street", "Sky Quay", "57 Skyring Terrace"}
# Far landmarks the extract doesn't reach (lon, lat, height m, ground m,
# width m, colour, kind, name). From /mnt/project-files/visuals/skyline/research.md;
# the Mt Coot-tha mast heights and the airport tower's spot are estimates.
LANDMARKS = [
    (152.94333, -27.46639, 150, 265, 12, "c0392b", "mast", "BTQ-7 tower (Seven)"),
    (152.94750, -27.46444, 150, 265, 12, "c0392b", "mast", "ABQ tower (ABC)"),
    (152.948056, -27.463056, 150, 270, 10, "e8e8e8", "mast", "TXA tower (shared)"),
    (152.950, -27.462, 150, 260, 12, "c0392b", "mast", "QTQ-9 tower (Nine)"),
    (152.945, -27.465, 150, 265, 12, "e8e8e8", "mast", "TVQ-10 tower (Ten)"),
    (153.118, -27.392, 75, 0, 12, "d9d9d6", "tower", "Brisbane Airport control tower"),
    (153.1040, -27.4485, 40, 0, 5, "8b4a36", "mast", "Commonwealth Acetate chimney"),
    (153.04349, -27.45063, 35, 0, 60, "2f3236", "gasholder", "Gasworks gasholder frame"),
    (153.1790, -27.3790, 80, 0, 16, "c0392b", "gantry", "Port of Brisbane container cranes"),
    (153.1803, -27.3803, 80, 0, 16, "e8e8e8", "gantry", "Port of Brisbane container cranes"),
    (153.1816, -27.3816, 80, 0, 16, "c0392b", "gantry", "Port of Brisbane container cranes"),
]
# Hills as soft mounds (lon, lat, height m above the river, radius m, colour, name)
HILLS = [
    (152.94639, -27.46306, 287, 2600, "6d8257", "Mt Coot-tha"),
    (152.9592, -27.4848, 226, 1600, "6d8257", "Mt Coot-tha lookout ridge"),
    (153.0728, -27.5428, 195, 1500, "6d8257", "Mt Gravatt"),
    (153.0500, -27.4385, 64, 900, "56743f", "Toorak Hill"),
    (153.0560, -27.4395, 60, 700, "56743f", "Eldernell (Hamilton Hill)"),
    (153.062, -27.430, 45, 1100, "56743f", "Ascot ridge"),
]


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
    lines = []
    for f in sky["features"]:
        tags = f["tags"]
        if "line" in f:
            lines.append(LineString([to_game(lon, lat) for lon, lat in f["line"]]))
            continue
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
            if tags.get("name", "") in BUILT_LATER:
                continue
            towers.append({"pts": ring(list(poly.exterior.coords)[:-1]), "h": round(h, 1),
                           "c": tower_colour(tags, h), "name": tags.get("name", "")})
        elif "pt" in f and h > 0:
            x, z = to_game(*f["pt"])
            if math.hypot(x, z) >= NEAR:
                masts.append({"at": [round(x, 1), round(z, 1)], "h": round(h, 1), "name": tags.get("name", "")})
    # The river, all the way up to the city
    wide = json.load(open(os.path.join(SRC, "osm_landmarks_wide.json")))["elements"]
    for e in wide:
        if e["type"] == "relation" and e["id"] in RIVER_REL:
            for m in e["members"]:
                if m.get("geometry"):
                    lines.append(LineString([to_game(p["lon"], p["lat"]) for p in m["geometry"]]))
    # The outline's cut off at the edge of the download, so close it against
    # the box; the river's faces are the thin ones (land is kilometres across)
    w, s, e, n = sky["box"]
    lines.append(Polygon([to_game(w, s), to_game(e, s), to_game(e, n), to_game(w, n)]).exterior)
    water = []
    # (minus the near map's own river, so the two never overlap)
    near_map = json.load(open(os.path.join(ROOT, "data", "riverlight_osm.json")))
    near = unary_union([Polygon(a["pts"]).buffer(0) for a in near_map["areas"] if a["kind"] == "water"]).buffer(0.5)
    for p in polygonize(unary_union(lines)):
        if p.area < 2000.0 or not p.buffer(-260.0).is_empty:
            continue
        p = p.difference(near)
        for q in getattr(p, "geoms", [p]):
            if q.area > 2000.0:
                water.append(ring(list(q.simplify(4.0).exterior.coords)[:-1]))
    for lon, lat, h, base, w, c, kind, name in LANDMARKS:
        x, z = to_game(lon, lat)
        masts.append({"at": [round(x, 1), round(z, 1)], "h": h, "base": base, "w": w, "c": c,
                      "kind": kind, "name": name})
    # Riparian Plaza's 50 m mast, and a crane on Skytower (topped out July 2018)
    for t in towers:
        cx = sum(p[0] for p in t["pts"]) / len(t["pts"])
        cz = sum(p[1] for p in t["pts"]) / len(t["pts"])
        if t["name"] == "Riparian Plaza":
            masts.append({"at": [round(cx, 1), round(cz, 1)], "h": 50, "base": t["h"], "w": 3, "c": "d0d4d6",
                          "kind": "mast", "name": "Riparian Plaza mast"})
        elif t["name"] == "Brisbane Skytower":
            masts.append({"at": [round(cx, 1), round(cz, 1)], "h": 30, "base": t["h"], "w": 3, "c": "e8c33a",
                          "kind": "crane", "name": "Skytower's tower crane"})
    hills = []
    for lon, lat, h, r, c, name in HILLS:
        x, z = to_game(lon, lat)
        hills.append({"at": [round(x, 1), round(z, 1)], "h": h, "r": r, "c": c, "name": name})
    out = {"source": "OpenStreetMap contributors, ODbL 1.0; landmarks from public sources",
           "towers": towers, "masts": masts, "water": water, "hills": hills}
    json.dump(out, open(OUT, "w"), separators=(",", ":"))
    print("wrote %s: %d towers, %d masts, %d water, %d hills" % (OUT, len(towers), len(masts), len(water), len(hills)))


if __name__ == "__main__":
    main()
