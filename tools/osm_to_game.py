#!/usr/bin/env python3
"""Turns the OpenStreetMap extracts in reference/osm/ into data/riverlight_osm.json,
the real layout round Riverlight in game coordinates, for scripts/surrounds.gd.

Game frame: metres, origin at Riverlight's footprint centroid, the world turned
so Riverlight's long side runs along x. -z is south (the river), +x is west
(upstream, the CBD), so x = -east and z = north after the turn.

    python3 tools/osm_to_game.py      (needs shapely)

Map data (c) OpenStreetMap contributors, ODbL 1.0.
"""
import csv
import json
import math
import os

from shapely.geometry import LineString, Polygon, Point, mapping, shape
from shapely.ops import unary_union
import shapely

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "reference", "osm")
OUT = os.path.join(ROOT, "data", "riverlight_osm.json")

LAT0, LON0 = -27.4436709, 153.0855133
TURN = -14.4         # turns the world so Riverlight's long side (bearing 104) lies along x
RADIUS = 1600.0      # keep everything within this of the site
M_LAT = 110860.0
M_LON = 111320.0 * math.cos(math.radians(LAT0))

ROAD_W = {
    "motorway": 22.0, "trunk": 16.0, "primary": 14.0, "secondary": 12.0, "tertiary": 10.0,
    "unclassified": 8.0, "residential": 7.5, "living_street": 6.0, "service": 5.0,
    "motorway_link": 8.0, "trunk_link": 8.0, "primary_link": 7.0, "secondary_link": 7.0,
}
PATH_W = {"footway": 2.0, "cycleway": 2.5, "path": 1.5, "pedestrian": 4.0, "steps": 2.0, "bridleway": 2.0}
BUILD_H = {
    "industrial": 9.0, "warehouse": 10.0, "container": 2.6, "shed": 3.5, "school": 8.0,
    "apartments": 15.0, "roof": 4.5, "commercial": 9.0, "retail": 6.0, "office": 12.0,
    "house": 6.0, "hotel": 20.0, "grandstand": 10.0, "church": 10.0, "sports_centre": 9.0,
    "parking": 8.0, "Clubhouse": 7.0, "boat": 4.0, "construction": 6.0,
}


def to_game(lon, lat):
    e = (lon - LON0) * M_LON
    n = (lat - LAT0) * M_LAT
    # Turn the world so the building's long side lies along x
    a = math.radians(-TURN)
    e2 = e * math.cos(a) - n * math.sin(a)
    n2 = e * math.sin(a) + n * math.cos(a)
    return (-e2, n2)


def tx(geom):
    if geom.geom_type == "Point":
        return Point(to_game(geom.x, geom.y))
    if geom.geom_type == "LineString":
        return LineString([to_game(x, y) for x, y in geom.coords])
    if geom.geom_type == "Polygon":
        return Polygon([to_game(x, y) for x, y in geom.exterior.coords],
                       [[to_game(x, y) for x, y in r.coords] for r in geom.interiors])
    if geom.geom_type.startswith("Multi") or geom.geom_type == "GeometryCollection":
        return unary_union([tx(g) for g in geom.geoms]) if geom.geom_type != "MultiLineString" else \
            [tx(g) for g in geom.geoms]
    return None


def rnd(pts):
    return [[round(x, 1), round(z, 1)] for x, z in pts]


def near(g):
    return g.distance(Point(0, 0)) < RADIUS


def polys(g):
    if g is None:
        return []
    if g.geom_type == "Polygon":
        return [g]
    if g.geom_type == "MultiPolygon":
        return list(g.geoms)
    return []


def lines(g):
    if isinstance(g, list):
        out = []
        for x in g:
            out += lines(x)
        return out
    if g is None:
        return []
    if g.geom_type == "LineString":
        return [g]
    if g.geom_type == "MultiLineString":
        return list(g.geoms)
    return []


# The game's own site (its slab, hardstand and truck road) keeps the ground clear
SITE_CUT = [(-45, -14, 50, 24), (-44.5, 21.1, 35.5, 30.1)]


def flat_ground(out, order):
    """Everything that lies flat on the ground (land use, water, drains, roads,
    paths) as one set of pieces that don't overlap, already cut into triangles,
    so no two pieces fight over the same spot on screen. Roads win over paths,
    paths over drains and water, and so on down the area draw order."""
    from shapely.geometry import box
    layers = [("road", unary_union([LineString(r["pts"]).buffer(r["w"] / 2, quad_segs=4)
                                    for r in out["roads"] if not r["bridge"] and len(r["pts"]) > 1]))]
    layers.append(("path", unary_union([LineString(p["pts"]).buffer(p["w"] / 2, quad_segs=2)
                                        for p in out["paths"] if len(p["pts"]) > 1])))
    layers.append(("drain", unary_union([LineString(d["pts"]).buffer(d["w"] / 2, quad_segs=2)
                                         for d in out["drains"] if len(d["pts"]) > 1])))
    for kind in reversed(order):
        geoms = []
        for a in out["areas"]:
            if a["kind"] == kind and len(a["pts"]) > 3:
                pg = Polygon(a["pts"], [h for h in a.get("holes", []) if len(h) > 3])
                geoms.append(pg if pg.is_valid else pg.buffer(0))
        if geoms:
            layers.append((kind, unary_union(geoms)))
    taken = unary_union([box(*r) for r in SITE_CUT])
    ground = []
    for kind, g in layers:
        g = g.difference(taken).simplify(0.2)
        taken = taken.union(g)
        tris = []
        for t in shapely.constrained_delaunay_triangles(g).geoms:
            if t.area < 0.05:
                continue
            q = list(t.exterior.coords)[:3]
            # All one way round (the way the game's ribbons wind), so every
            # triangle faces up and lights the same
            if (q[1][0] - q[0][0]) * (q[2][1] - q[0][1]) - (q[1][1] - q[0][1]) * (q[2][0] - q[0][0]) > 0:
                q = [q[0], q[2], q[1]]
            for x, z in q:
                tris += [round(x, 1), round(z, 1)]
        if tris:
            ground.append({"kind": kind, "tris": tris})
    return ground


# The game is set in 2017: these roads went through the MacArthur Ave car
# yard later (the July 2017 aerial shows cars there)
NOT_YET = {"Barcham Road", "Karakul Road"}


def lidar_heights():
    """Building heights measured off the 2019 LiDAR (reference/elevation/
    building_heights.csv), for the buildings inside its tile that stood then;
    None for the ones it shows weren't built yet."""
    out = {}
    with open(os.path.join(ROOT, "reference", "elevation", "building_heights.csv")) as f:
        for r in csv.DictReader(f):
            if r["note"].startswith("nothing tall here in 2019"):
                out[r["osm_id"]] = None     # not built yet in 2019, so not in 2017
            elif r["height_above_ground_m"] and not r["note"]:
                out[r["osm_id"]] = float(r["height_above_ground_m"])
    return out


def load(name):
    return json.load(open(os.path.join(SRC, name + ".geojson")))["features"]


def main():
    out = {
        "source": "OpenStreetMap contributors, ODbL 1.0 (reference/osm)",
        "origin": [LAT0, LON0], "turn_deg": TURN,
        "frame": "metres; x = west, z = north (after the turn); origin at Riverlight's centroid",
        "roads": [], "paths": [], "buildings": [], "areas": [], "drains": [],
        "trees": [], "lamps": [], "ferry": [], "piers": [], "riverlight": [], "fences": [],
    }
    seen = set()
    river_lines = []
    measured = lidar_heights()
    feats = load("osm_roads") + load("osm_landuse") + load("osm_buildings") + load("osm_landmarks_wide")
    for f in feats:
        p = f["properties"]
        fid = p.get("id") or f.get("id")
        if fid in seen:
            continue
        seen.add(fid)
        try:
            g = tx(shape(f["geometry"]))
        except Exception:
            continue
        if g is None or (not isinstance(g, list) and g.is_empty):
            continue
        if not isinstance(g, list) and not near(g):
            continue
        hw = p.get("highway")
        if p.get("name", "").startswith("Riverlight"):
            for pg in polys(g):
                out["riverlight"].append({"name": p.get("name"), "levels": p.get("building:levels"),
                                          "pts": rnd(pg.simplify(0.3).exterior.coords)})
            continue
        if "building" in p and polys(g):
            if fid in measured and measured[fid] is None:
                continue
            kind = p["building"]
            h = None
            if p.get("height"):
                try:
                    h = float(str(p["height"]).split()[0])
                except ValueError:
                    pass
            if h is None and p.get("building:levels"):
                try:
                    h = float(p["building:levels"]) * 3.2
                except ValueError:
                    pass
            if measured.get(fid) and measured[fid] > 2.5:
                h = measured[fid]
            for pg in polys(g):
                out["buildings"].append({"kind": kind, "h": round(h or BUILD_H.get(kind, 6.0), 1),
                                         "name": p.get("name", ""),
                                         "pts": rnd(pg.simplify(0.5).exterior.coords)})
            continue
        if p.get("name") in NOT_YET:
            continue
        if hw in ROAD_W:
            w = ROAD_W[hw]
            if p.get("width"):
                try:
                    w = float(str(p["width"]).split()[0])
                except ValueError:
                    pass
            elif p.get("lanes"):
                try:
                    w = max(w * 0.6, float(p["lanes"]) * 3.5)
                except ValueError:
                    pass
            for ln in lines(g):
                out["roads"].append({"kind": hw, "w": round(w, 1), "name": p.get("name", ""),
                                     "bridge": p.get("bridge") == "yes", "layer": p.get("layer", "0"),
                                     "pts": rnd(ln.simplify(0.5).coords)})
            continue
        if hw in PATH_W:
            if polys(g):
                for pg in polys(g):
                    out["areas"].append({"kind": "paving", "pts": rnd(pg.simplify(0.5).exterior.coords)})
            for ln in lines(g):
                out["paths"].append({"kind": hw, "w": PATH_W[hw], "pts": rnd(ln.simplify(0.4).coords)})
            continue
        if p.get("natural") == "tree" and g.geom_type == "Point":
            out["trees"].append([round(g.x, 1), round(g.y, 1)])
            continue
        if hw == "street_lamp" and g.geom_type == "Point":
            out["lamps"].append([round(g.x, 1), round(g.y, 1)])
            continue
        if p.get("amenity") == "ferry_terminal" and g.geom_type == "Point":
            out["ferry"].append({"name": p.get("name", ""), "at": [round(g.x, 1), round(g.y, 1)]})
            continue
        if p.get("waterway") == "river" and lines(g):
            river_lines.extend(lines(g))
            continue
        if p.get("waterway") in ("drain", "stream", "canal") and lines(g):
            for ln in lines(g):
                out["drains"].append({"w": 6.0 if p.get("waterway") == "drain" else 4.0,
                                      "pts": rnd(ln.simplify(0.8).coords)})
            continue
        if p.get("barrier") in ("fence", "wall") and lines(g):
            for ln in lines(g):
                out["fences"].append({"kind": p["barrier"], "pts": rnd(ln.simplify(0.5).coords)})
            continue
        if p.get("man_made") == "pier":
            for pg in polys(g):
                out["piers"].append({"pts": rnd(pg.simplify(0.5).exterior.coords)})
            for ln in lines(g):
                out["piers"].append({"line": rnd(ln.coords), "w": 3.0})
            continue
        kind = None
        if p.get("leisure") == "golf_course":
            kind = "golf"
        elif p.get("golf"):
            kind = "golf_water"
        elif p.get("natural") == "water" or p.get("water") or p.get("waterway") == "riverbank":
            kind = "water"
        elif p.get("natural") in ("beach", "sand"):
            kind = "beach"
        elif p.get("natural") in ("scrub", "wood") or p.get("landuse") == "forest":
            kind = "scrub"
        elif p.get("leisure") in ("park", "garden", "playground", "recreation_ground") or p.get("landuse") in ("grass", "recreation_ground", "village_green"):
            kind = "park"
        elif p.get("leisure") == "pitch":
            kind = "pitch"
        elif p.get("amenity") == "parking" or p.get("parking"):
            kind = "parking"
        elif p.get("landuse") in ("industrial", "commercial", "retail", "railway", "port"):
            kind = "industrial"
        elif p.get("landuse") in ("brownfield", "construction", "greenfield"):
            kind = "vacant"
        elif p.get("landuse") == "residential":
            kind = "residential"
        elif p.get("man_made") == "bridge":
            kind = "bridge"
        if kind:
            for pg in polys(g):
                pg = pg.intersection(Point(0, 0).buffer(RADIUS * 1.6, 32)) if kind == "water" else pg
                for q in polys(pg):
                    out["areas"].append({"kind": kind, "name": p.get("name", ""),
                                         "pts": rnd(q.simplify(1.0).exterior.coords),
                                         "holes": [rnd(r.simplify(1.0).coords) for r in q.interiors]})
    # The river's centreline (for the CityCat), upstream (+x) end first
    from shapely.ops import linemerge
    merged = linemerge(river_lines) if river_lines else None
    best = max(lines(merged), key=lambda l: l.length) if merged is not None else None
    if best is not None:
        best = best.intersection(Point(0, 0).buffer(2500, 32))
        best = max(lines(best), key=lambda l: l.length)
        pts = list(best.simplify(5.0).coords)
        if pts[0][0] < pts[-1][0]:
            pts.reverse()
        out["river_line"] = rnd(pts)
    # Where a CityCat berths: the water's edge nearest the terminal, and which
    # way the bank runs there
    water = unary_union([Polygon(a["pts"]) for a in out["areas"] if a["kind"] == "water" and len(a["pts"]) > 3])
    for fe in out["ferry"]:
        at = Point(fe["at"])
        edge = water.boundary
        d = edge.project(at)
        e = edge.interpolate(d)
        e2 = edge.interpolate(d + 5.0)
        fe["edge"] = [round(e.x, 1), round(e.y, 1)]
        fe["bank_deg"] = round(math.degrees(math.atan2(e2.y - e.y, e2.x - e.x)), 1)
    # A CityCat's run down from the city to the terminal: the middle of the
    # water every 100 m, from upstream (+x) in to the berth
    route = []
    for x in range(1500, 150, -100):
        cut = water.intersection(LineString([(x, -1200), (x, 400)]))
        segs = sorted(lines(cut), key=lambda l: -l.length)
        if segs:
            m = segs[0].interpolate(0.5, normalized=True)
            route.append([float(x), round(m.y, 1)])
    out["cat_route"] = route
    # Big things first, so smaller areas draw on top
    order = ["residential", "industrial", "vacant", "golf", "park", "scrub", "pitch", "parking",
             "paving", "beach", "golf_water", "water", "bridge"]
    out["areas"].sort(key=lambda a: (order.index(a["kind"]) if a["kind"] in order else 99))
    out["ground"] = flat_ground(out, order)
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    json.dump(out, open(OUT, "w"), separators=(",", ":"))
    for k, v in out.items():
        if isinstance(v, list):
            print(k, len(v))
    print("wrote", OUT, os.path.getsize(OUT), "bytes")


if __name__ == "__main__":
    main()
