#!/usr/bin/env python3
"""Downloads the skyline round Riverlight from the OpenStreetMap API into
reference/osm/skyline_osm.json: every building 18 m or 6 storeys and up (and
any named tower, mast or chimney) from the CBD out past the Gateway Bridge.
Run it somewhere that can reach api.openstreetmap.org (the cloud can't).

    python3 tools/skyline_fetch.py

Small tiles, split again when a tile has too much in it, a pause between
calls (the API's usage policy). Standard library only.

Map data (c) OpenStreetMap contributors, ODbL 1.0.
"""
import json
import os
import sys
import time
import urllib.error
import urllib.request

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "reference", "osm", "skyline_osm.json")
API = "https://api.openstreetmap.org/api/0.6/map.json?bbox=%.5f,%.5f,%.5f,%.5f"
UA = "PourDecisions-skyline/1.0 (game reference; one-off download)"
# lon/lat box: the CBD and Kangaroo Point (~7 km WSW) to past the Gateway (~3 km E)
BOX = (153.010, -27.490, 153.125, -27.405)
STEP = 0.01
MIN_H = 18.0
MIN_LEVELS = 6


def height(tags):
    for k in ("height", "building:height"):
        v = tags.get(k)
        if v:
            try:
                return float(v.replace("m", "").strip())
            except ValueError:
                pass
    lv = tags.get("building:levels")
    if lv:
        try:
            return float(lv) * 3.2
        except ValueError:
            pass
    return 0.0


def wanted(tags):
    if tags.get("man_made") in ("tower", "mast", "chimney", "communications_tower") or tags.get("tower:type") == "communication":
        return True
    if "building" not in tags and "building:part" not in tags:
        return False
    try:
        lv = float(tags.get("building:levels", "0"))
    except ValueError:
        lv = 0.0
    return height(tags) >= MIN_H or lv >= MIN_LEVELS


def fetch(w, s, e, n, depth=0):
    url = API % (w, s, e, n)
    for attempt in range(4):
        try:
            req = urllib.request.Request(url, headers={"User-Agent": UA})
            with urllib.request.urlopen(req, timeout=120) as r:
                return json.load(r)["elements"]
        except urllib.error.HTTPError as err:
            if err.code == 400 and depth < 4:
                # too many nodes in this tile: split it in four
                mx, my = (w + e) / 2, (s + n) / 2
                out = []
                for b in ((w, s, mx, my), (mx, s, e, my), (w, my, mx, n), (mx, my, e, n)):
                    out += fetch(*b, depth=depth + 1)
                    time.sleep(1.0)
                return out
            print("  HTTP %d on %s, retrying" % (err.code, url), file=sys.stderr)
        except Exception as err:  # network hiccup
            print("  %s on %s, retrying" % (err, url), file=sys.stderr)
        time.sleep(2 ** (attempt + 1))
    print("  GAVE UP on %s" % url, file=sys.stderr)
    return []


def main():
    w0, s0, e0, n0 = BOX
    found = {}
    tiles = []
    lon = w0
    while lon < e0 - 1e-9:
        lat = s0
        while lat < n0 - 1e-9:
            tiles.append((lon, lat, min(lon + STEP, e0), min(lat + STEP, n0)))
            lat += STEP
        lon += STEP
    for i, t in enumerate(tiles):
        els = fetch(*t)
        nodes = {el["id"]: (el["lon"], el["lat"]) for el in els if el["type"] == "node"}
        ways = {el["id"]: el for el in els if el["type"] == "way"}
        # The river's outline: the member ways of its water relations
        for el in els:
            tags = el.get("tags", {})
            if el["type"] == "relation" and (tags.get("water") == "river" or tags.get("waterway") == "riverbank"):
                for m in el.get("members", []):
                    w = ways.get(m["ref"]) if m["type"] == "way" else None
                    key = "riverway/%d" % m["ref"]
                    if w is None or key in found:
                        continue
                    pts = [nodes[nd] for nd in w.get("nodes", []) if nd in nodes]
                    if len(pts) >= 2:
                        found[key] = {"id": key, "tags": {"river_rel": str(el["id"]), "role": m.get("role", "")}, "line": pts}
        for el in els:
            tags = el.get("tags", {})
            if not wanted(tags):
                continue
            key = "%s/%d" % (el["type"], el["id"])
            if key in found:
                continue
            if el["type"] == "node":
                found[key] = {"id": key, "tags": tags, "pt": [el["lon"], el["lat"]], "h": height(tags)}
            elif el["type"] == "way":
                pts = [nodes[nd] for nd in el.get("nodes", []) if nd in nodes]
                if len(pts) >= 3:
                    found[key] = {"id": key, "tags": tags, "poly": pts, "h": height(tags)}
        print("tile %d/%d: %d so far" % (i + 1, len(tiles), len(found)))
        time.sleep(1.0)
    out = {"source": "OpenStreetMap API, (c) OpenStreetMap contributors, ODbL 1.0",
           "box": BOX, "min_h": MIN_H, "min_levels": MIN_LEVELS,
           "downloaded": time.strftime("%Y-%m-%d"), "features": list(found.values())}
    with open(OUT, "w") as f:
        json.dump(out, f)
    print("wrote %s: %d features" % (OUT, len(found)))


if __name__ == "__main__":
    main()
