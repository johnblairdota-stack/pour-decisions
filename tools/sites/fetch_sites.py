#!/usr/bin/env python3
"""Downloads everything public we can get for the SCP river sites (the new
levels after Riverlight), so the cloud can turn it into game data.
Run it on a PC that can reach the internet (the cloud is blocked from
these services):

    py tools/sites/fetch_sites.py OUT_DIR [--only=cbd,portside] [--skip=osm,dem,...]

Standard library only. Safe to re-run: finished files are skipped.

Areas
  portside  Alcyone Hotel Residences, Portside Wharf, Hamilton
  cbd       Spire (550 Queen St), Howard Smith Wharves, 1 William St,
            Brisbane Skytower (222 Margaret St), Queen's Wharf

Layers (each in OUT_DIR/<area>/<layer>/)
  osm      OpenStreetMap API, every element in the box, merged, gzipped
           (ODbL, (c) OpenStreetMap contributors)
  geocode  Nominatim lookups for each site (ODbL)
  dem      Queensland QldDem image service, 1 m bare ground, default mix
           (2014/2019 LiDAR + river bed) and the 2019 project alone where
           the service lets us lock it (CC BY 4.0, State of Queensland)
  aerial   Queensland aerial photos, every capture over each site listed,
           close-ups for the build years and the newest, plus a wide view
           (CC BY 4.0, State of Queensland)
  commons  Wikimedia Commons photos near each site and by name (each
           file's own licence, recorded in credits.csv)
  council  Brisbane City Council open data clipped to the box (CC BY 4.0)
  elvis    a list of the 2019 LiDAR 1 km tile names John orders from ELVIS
"""
import csv
import gzip
import json
import math
import os
import sys
import time
import urllib.error
import urllib.parse
import urllib.request

UA = "PourDecisions-sites/1.0 (game reference; one-off download)"

# Areas: (west, south, east, north) lon/lat. Sites: name, lat, lon (rough,
# refined by the geocode layer), build years, search words for photos.
AREAS = {
    "portside": {
        "box": (153.0540, -27.4530, 153.0860, -27.4250),
        "sites": [
            {"id": "alcyone", "name": "Alcyone Hotel Residences", "addr": "35 Hercules Street, Hamilton QLD",
             "lat": -27.4383, "lon": 153.0700, "years": (2015, 2017),
             "search": ["Alcyone Hotel Residences", "Portside Wharf Hamilton", "Hamilton Brisbane ferry terminal"]},
        ],
    },
    "cbd": {
        "box": (153.0080, -27.4870, 153.0520, -27.4500),
        "sites": [
            {"id": "spire", "name": "Spire Residences", "addr": "550 Queen Street, Brisbane City QLD",
             "lat": -27.4627, "lon": 153.0334, "years": (2015, 2017),
             "search": ["Spire Residences Brisbane", "550 Queen Street Brisbane", "Petrie Bight"]},
            {"id": "hsw", "name": "Howard Smith Wharves", "addr": "Howard Smith Wharves, Brisbane City QLD",
             "lat": -27.4640, "lon": 153.0362, "years": (2017, 2019),
             "search": ["Howard Smith Wharves", "Story Bridge Brisbane", "Customs House Brisbane"]},
            {"id": "william1", "name": "1 William Street", "addr": "1 William Street, Brisbane City QLD",
             "lat": -27.4738, "lon": 153.0262, "years": (2013, 2016),
             "search": ["1 William Street Brisbane", "Riverside Expressway", "Brisbane City Botanic Gardens"]},
            {"id": "skytower", "name": "Brisbane Skytower", "addr": "222 Margaret Street, Brisbane City QLD",
             "lat": -27.4705, "lon": 153.0290, "years": (2015, 2019),
             "search": ["Brisbane Skytower", "222 Margaret Street Brisbane"]},
            {"id": "queenswharf", "name": "Queen's Wharf Brisbane", "addr": "Queen's Wharf, Brisbane City QLD",
             "lat": -27.4730, "lon": 153.0235, "years": (2018, 2024),
             "search": ["Queen's Wharf Brisbane", "Neville Bonner Bridge", "Star Brisbane"]},
        ],
    },
}

COUNCIL = [
    "bicycle-racks", "bikeway-sections", "brisbane-bus-stops", "commercial-vehicle-loading-zones",
    "cp14-bicycle-network-overlay", "cp14-road-hierarchy-overlay-road-hierarchy", "ferry-terminals",
    "park-barbeque-locations", "park-drinking-fountain-tap-locations", "park-locations",
    "parking-line-locations", "parking-sign-locations",
    "protected-vegetation-natural-assets-local-law-2003-significant-urban-vegetation",
    "public-toilets-in-brisbane", "street-tree-landscape-character-precincts", "tracks-and-trails",
    "two-minute-passenger-loading-zones",
    # extra layers worth having in the city
    "street-trees", "taxi-zones", "city-cat-and-ferry-terminals",
]

OSM_API = "https://api.openstreetmap.org/api/0.6/map.json?bbox=%.5f,%.5f,%.5f,%.5f"
NOMINATIM = "https://nominatim.openstreetmap.org/search?format=jsonv2&limit=5&q="
DEM = "https://spatial-img.information.qld.gov.au/arcgis/rest/services/Elevation/QldDem/ImageServer"
AERIAL = "https://spatial-img.information.qld.gov.au/arcgis/rest/services/TimeSeries/AerialOrtho_AllUsers/ImageServer"
COMMONS = "https://commons.wikimedia.org/w/api.php"
BCC = "https://data.brisbane.qld.gov.au/api/explore/v2.1/catalog/datasets/%s/exports/geojson"


def log(*a):
    print(*a, flush=True)


def get(url, binary=False, data=None, tries=4, timeout=180):
    for attempt in range(tries):
        try:
            req = urllib.request.Request(url, data=data, headers={"User-Agent": UA})
            with urllib.request.urlopen(req, timeout=timeout) as r:
                body = r.read()
                return body if binary else json.loads(body.decode("utf-8"))
        except urllib.error.HTTPError as err:
            if err.code in (400, 404, 403):
                raise
            log("   HTTP %d, retry" % err.code)
        except Exception as err:
            log("   %s, retry" % err)
        time.sleep(2 ** (attempt + 1))
    raise RuntimeError("gave up on " + url)


def save_json(path, obj):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8") as f:
        json.dump(obj, f, indent=1, ensure_ascii=False)


def done(path):
    return os.path.exists(path) and os.path.getsize(path) > 0


# ---------------------------------------------------------------- OSM

def osm_tile(w, s, e, n, depth=0):
    try:
        return get(OSM_API % (w, s, e, n))["elements"]
    except urllib.error.HTTPError as err:
        if err.code == 400 and depth < 6:  # too many nodes: split in four
            mx, my = (w + e) / 2, (s + n) / 2
            out = []
            for b in ((w, s, mx, my), (mx, s, e, my), (w, my, mx, n), (mx, my, e, n)):
                out += osm_tile(*b, depth=depth + 1)
                time.sleep(1.0)
            return out
        raise


def layer_osm(area, a, out):
    path = os.path.join(out, "osm", "osm_all.json.gz")
    if done(path):
        return log("  osm: already have it")
    w, s, e, n = a["box"]
    step = 0.005
    seen, elems = set(), []
    lat = s
    while lat < n - 1e-9:
        lon = w
        while lon < e - 1e-9:
            t = (lon, lat, min(lon + step, e), min(lat + step, n))
            log("  osm tile %.4f,%.4f" % (t[0], t[1]))
            for el in osm_tile(*t):
                k = (el["type"], el["id"])
                if k not in seen:
                    seen.add(k)
                    elems.append(el)
            time.sleep(1.0)
            lon += step
        lat += step
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with gzip.open(path, "wt", encoding="utf-8") as f:
        json.dump({"box": a["box"], "downloaded": time.strftime("%Y-%m-%d"),
                   "licence": "ODbL 1.0, (c) OpenStreetMap contributors", "elements": elems}, f)
    log("  osm: %d elements" % len(elems))


def layer_geocode(area, a, out):
    path = os.path.join(out, "geocode", "sites.json")
    if done(path):
        return log("  geocode: already have it")
    res = {}
    for site in a["sites"]:
        hits = []
        for q in (site["name"] + ", Brisbane", site["addr"]):
            try:
                hits += get(NOMINATIM + urllib.parse.quote(q))
            except Exception as err:
                log("   geocode %s: %s" % (q, err))
            time.sleep(1.2)
        res[site["id"]] = {"site": site, "hits": hits}
        log("  geocode %s: %d hits" % (site["id"], len(hits)))
    save_json(path, res)


# ---------------------------------------------------------------- ArcGIS helpers

def to_merc(lon, lat):
    x = lon * 20037508.34 / 180.0
    y = math.log(math.tan((90 + lat) * math.pi / 360.0)) * 20037508.34 / math.pi
    return x, y


def merc_box(lat, lon, half_m):
    # half_m is ground metres; Web Mercator metres stretch by 1/cos(lat)
    k = 1.0 / math.cos(math.radians(lat))
    x, y = to_merc(lon, lat)
    return (x - half_m * k, y - half_m * k, x + half_m * k, y + half_m * k)


def arc_query(service, bbox3857):
    q = urllib.parse.urlencode({
        "where": "1=1", "geometry": ",".join("%.2f" % v for v in bbox3857),
        "geometryType": "esriGeometryEnvelope", "inSR": 3857, "spatialRel": "esriSpatialRelIntersects",
        "outFields": "*", "returnGeometry": "false", "f": "json"})
    return get(service + "/query?" + q).get("features", [])


def arc_export(service, bbox, size, path, fmt="jpgpng", lock=None, sr=3857, pixel="", interp=""):
    if done(path):
        return True
    p = {"bbox": ",".join("%.2f" % v for v in bbox), "bboxSR": sr, "imageSR": sr,
         "size": "%d,%d" % size, "format": fmt, "f": "image"}
    if lock is not None:
        p["mosaicRule"] = json.dumps({"mosaicMethod": "esriMosaicLockRaster", "lockRasterIds": lock})
    if pixel:
        p["pixelType"] = pixel
    if interp:
        p["interpolation"] = interp
    try:
        body = get(service + "/exportImage?" + urllib.parse.urlencode(p), binary=True, timeout=600)
    except Exception as err:
        log("   export failed: %s" % err)
        return False
    if body[:1] == b"{":
        log("   export error: %s" % body[:300])
        return False
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "wb") as f:
        f.write(body)
    return True


def mga56(lat, lon):
    """WGS84/GDA94 lon/lat -> MGA zone 56 easting/northing (Transverse Mercator)."""
    a, f = 6378137.0, 1 / 298.257222101
    k0, lon0, fe, fn = 0.9996, math.radians(153.0), 500000.0, 10000000.0
    e2 = f * (2 - f)
    ep2 = e2 / (1 - e2)
    phi, lam = math.radians(lat), math.radians(lon)
    N = a / math.sqrt(1 - e2 * math.sin(phi) ** 2)
    T = math.tan(phi) ** 2
    C = ep2 * math.cos(phi) ** 2
    A = math.cos(phi) * (lam - lon0)
    M = a * ((1 - e2 / 4 - 3 * e2 ** 2 / 64 - 5 * e2 ** 3 / 256) * phi
             - (3 * e2 / 8 + 3 * e2 ** 2 / 32 + 45 * e2 ** 3 / 1024) * math.sin(2 * phi)
             + (15 * e2 ** 2 / 256 + 45 * e2 ** 3 / 1024) * math.sin(4 * phi)
             - (35 * e2 ** 3 / 3072) * math.sin(6 * phi))
    E = fe + k0 * N * (A + (1 - T + C) * A ** 3 / 6 + (5 - 18 * T + T * T + 72 * C - 58 * ep2) * A ** 5 / 120)
    Nn = fn + k0 * (M + N * math.tan(phi) * (A * A / 2 + (5 - T + 9 * C + 4 * C * C) * A ** 4 / 24
                                              + (61 - 58 * T + T * T + 600 * C - 330 * ep2) * A ** 6 / 720))
    return E, Nn


# ---------------------------------------------------------------- DEM

def layer_dem(area, a, out):
    w, s, e, n = a["box"]
    E0, N0 = mga56(s, w)
    E1, N1 = mga56(n, e)
    E0, N0 = math.floor(E0 / 1000) * 1000, math.floor(N0 / 1000) * 1000
    E1, N1 = math.ceil(E1 / 1000) * 1000, math.ceil(N1 / 1000) * 1000
    d = os.path.join(out, "dem")
    # rasters in the service over this box, to find the 2019 Brisbane project
    feats = []
    try:
        q = urllib.parse.urlencode({"where": "1=1", "geometry": "%d,%d,%d,%d" % (E0, N0, E1, N1),
                                    "geometryType": "esriGeometryEnvelope", "inSR": 28356,
                                    "spatialRel": "esriSpatialRelIntersects", "outFields": "*",
                                    "returnGeometry": "false", "f": "json"})
        feats = get(DEM + "/query?" + q).get("features", [])
    except Exception as err:
        log("  dem catalogue: %s" % err)
    save_json(os.path.join(d, "catalogue.json"), feats)
    lock2019 = []
    for ft in feats:
        at = ft.get("attributes", {})
        name = " ".join(str(v) for v in at.values())
        if "2019" in name and "Brisbane" in name:
            oid = at.get("OBJECTID") or at.get("objectid")
            if oid is not None:
                lock2019.append(oid)
    log("  dem: box E %d-%d N %d-%d, 2019 rasters %s" % (E0, E1, N0, N1, lock2019))
    for E in range(E0, E1, 1000):
        for N in range(N0, N1, 1000):
            tile = (E, N, E + 1000, N + 1000)
            p = os.path.join(d, "default", "dem_%d_%d.tif" % (E, N))
            arc_export(DEM, tile, (1000, 1000), p, fmt="tiff", sr=28356, pixel="F32", interp="RSP_BilinearInterpolation")
            if lock2019:
                p = os.path.join(d, "lidar2019", "dem_%d_%d.tif" % (E, N))
                arc_export(DEM, tile, (1000, 1000), p, fmt="tiff", sr=28356, pixel="F32",
                           interp="RSP_BilinearInterpolation", lock=lock2019)
            log("  dem tile %d %d" % (E, N))
    save_json(os.path.join(d, "README.json"), {
        "crs": "EPSG:28356 (MGA zone 56, GDA94)", "pixel_m": 1, "tiles": "dem_<E>_<N>.tif, 1000x1000 Float32",
        "units": "metres AHD", "source": DEM, "lock2019": lock2019,
        "credit": "Includes material (c) State of Queensland; (c) Commonwealth of Australia (Geoscience Australia, The Australian Hydrographic Office). CC BY 4.0"})


def layer_elvis(area, a, out):
    w, s, e, n = a["box"]
    E0, N0 = mga56(s, w)
    E1, N1 = mga56(n, e)
    names = []
    for E in range(int(E0 // 1000) * 1000, int(math.ceil(E1 / 1000)) * 1000, 1000):
        for N in range(int(N0 // 1000) * 1000, int(math.ceil(N1 / 1000)) * 1000, 1000):
            names.append("Brisbane_2019_Prj_SW_%d_%d_1k_class_AHD.laz" % (E, N))
    p = os.path.join(out, "elvis", "tiles_to_order.txt")
    os.makedirs(os.path.dirname(p), exist_ok=True)
    with open(p, "w") as f:
        f.write("\n".join(names) + "\n")
    log("  elvis: %d tile names" % len(names))


# ---------------------------------------------------------------- aerials

def layer_aerial(area, a, out):
    d = os.path.join(out, "aerial")
    for site in a["sites"]:
        bb = merc_box(site["lat"], site["lon"], 400)
        try:
            feats = arc_query(AERIAL, bb)
        except Exception as err:
            log("  aerial catalogue %s: %s" % (site["id"], err))
            continue
        caps = []
        for ft in feats:
            at = ft["attributes"]
            caps.append({k: at.get(k) for k in at})
        save_json(os.path.join(d, site["id"], "captures.json"), caps)
        # keep Brisbane 10 cm captures (fine detail); one per year
        by_year = {}
        for c in caps:
            nm = str(c.get("Name") or c.get("name") or "")
            oid = c.get("OBJECTID") or c.get("objectid")
            yr = None
            for y in range(2000, 2031):
                if str(y) in nm:
                    yr = y
            if yr is None or oid is None:
                continue
            res = c.get("LowPS") or c.get("lowps") or 1.0
            if yr not in by_year or (res and res < by_year[yr][1]):
                by_year[yr] = (oid, res or 1.0, nm)
        y0, y1 = site["years"]
        want = [y for y in by_year if y0 - 1 <= y <= y1 + 1]
        if by_year:
            want.append(max(by_year))
        for yr in sorted(set(want)):
            oid, res, nm = by_year[yr]
            p = os.path.join(d, site["id"], "aerial_%d_800m_0p2m.jpg" % yr)
            ok = arc_export(AERIAL, bb, (4000, 4000), p, fmt="jpg", lock=[oid])
            log("  aerial %s %d %s %s" % (site["id"], yr, nm, "ok" if ok else "FAILED"))
    # wide view of the whole area, newest capture
    w, s, e, n = a["box"]
    x0, y0 = to_merc(w, s)
    x1, y1 = to_merc(e, n)
    for label, lock in (("newest", None),):
        p = os.path.join(d, "area_%s_wide.jpg" % label)
        size = (4000, int(4000 * (y1 - y0) / (x1 - x0)))
        ok = arc_export(AERIAL, (x0, y0, x1, y1), size, p, fmt="jpg", lock=lock)
        log("  aerial wide %s %s" % (label, "ok" if ok else "FAILED"))
    save_json(os.path.join(d, "README.json"), {
        "crs": "EPSG:3857, north up", "source": AERIAL,
        "credit": "Includes material (c) State of Queensland (Department of Resources). CC BY 4.0. "
                  "The State gives no warranty in relation to the data and accepts no liability for its use."})


# ---------------------------------------------------------------- Commons photos

def commons(params):
    params = dict(params, format="json")
    return get(COMMONS + "?" + urllib.parse.urlencode(params))


def commons_info(titles):
    out = {}
    for i in range(0, len(titles), 40):
        r = commons({"action": "query", "titles": "|".join(titles[i:i + 40]), "prop": "imageinfo",
                     "iiprop": "url|extmetadata|size|mime", "iiurlwidth": 1600})
        for pg in r.get("query", {}).get("pages", {}).values():
            if pg.get("imageinfo"):
                out[pg["title"]] = pg["imageinfo"][0]
        time.sleep(0.5)
    return out


def layer_commons(area, a, out):
    d = os.path.join(out, "commons")
    credits_path = os.path.join(d, "credits.csv")
    titles = {}
    for site in a["sites"]:
        try:
            r = commons({"action": "query", "list": "geosearch", "gsnamespace": 6, "gslimit": 500,
                         "gsradius": 700, "gscoord": "%f|%f" % (site["lat"], site["lon"])})
            for g in r.get("query", {}).get("geosearch", []):
                titles.setdefault(g["title"], set()).add(site["id"])
        except Exception as err:
            log("  commons geo %s: %s" % (site["id"], err))
        for words in site["search"]:
            try:
                r = commons({"action": "query", "list": "search", "srnamespace": 6, "srlimit": 80,
                             "srsearch": words})
                for g in r.get("query", {}).get("search", []):
                    titles.setdefault(g["title"], set()).add(site["id"])
            except Exception as err:
                log("  commons search %s: %s" % (words, err))
            time.sleep(0.5)
    log("  commons: %d candidate files" % len(titles))
    info = commons_info(sorted(titles))
    rows = []
    for t, ii in sorted(info.items()):
        if not str(ii.get("mime", "")).startswith("image/"):
            continue
        meta = ii.get("extmetadata", {})
        lic = meta.get("LicenseShortName", {}).get("value", "")
        if not any(k in lic for k in ("CC", "Public domain", "PD", "Attribution")):
            continue
        fn = t.split(":", 1)[1]
        safe = "".join(ch if ch.isalnum() or ch in "._-" else "_" for ch in fn)[:120]
        sites = sorted(titles[t])
        p = os.path.join(d, sites[0], safe)
        if not done(p):
            url = ii.get("thumburl") or ii.get("url")
            try:
                body = get(url, binary=True)
                os.makedirs(os.path.dirname(p), exist_ok=True)
                with open(p, "wb") as f:
                    f.write(body)
            except Exception as err:
                log("   photo %s: %s" % (fn, err))
                continue
            time.sleep(0.3)
        rows.append({"file": os.path.relpath(p, d), "sites": " ".join(sites), "title": t,
                     "description": _strip(meta.get("ImageDescription", {}).get("value", ""))[:300],
                     "date": _strip(meta.get("DateTimeOriginal", {}).get("value", "")),
                     "author": _strip(meta.get("Artist", {}).get("value", "")),
                     "licence": lic, "lat": meta.get("GPSLatitude", {}).get("value", ""),
                     "lon": meta.get("GPSLongitude", {}).get("value", ""),
                     "source": ii.get("descriptionurl", "")})
    os.makedirs(d, exist_ok=True)
    with open(credits_path, "w", newline="", encoding="utf-8") as f:
        wr = csv.DictWriter(f, fieldnames=list(rows[0].keys()) if rows else ["file"])
        wr.writeheader()
        wr.writerows(rows)
    log("  commons: %d photos saved" % len(rows))


def _strip(html):
    out, depth = [], 0
    for ch in str(html):
        if ch == "<":
            depth += 1
        elif ch == ">":
            depth = max(0, depth - 1)
        elif depth == 0:
            out.append(ch)
    return "".join(out).strip()


# ---------------------------------------------------------------- council

def layer_council(area, a, out):
    w, s, e, n = a["box"]
    d = os.path.join(out, "council")
    for ds in COUNCIL:
        p = os.path.join(d, ds + ".geojson")
        if done(p):
            continue
        got = None
        for field in ("geo_point_2d", "geo_shape", "geopoint", "geometry"):
            q = urllib.parse.urlencode({"where": "in_bbox(%s, %f, %f, %f, %f)" % (field, s, w, n, e)})
            try:
                got = get(BCC % ds + "?" + q, binary=True)
                break
            except urllib.error.HTTPError as err:
                if err.code == 404:
                    break
            except Exception:
                pass
        if got is None:
            log("  council %s: not found or no geo field" % ds)
            continue
        os.makedirs(d, exist_ok=True)
        with open(p, "wb") as f:
            f.write(got)
        try:
            nf = len(json.loads(got.decode("utf-8")).get("features", []))
        except Exception:
            nf = "?"
        log("  council %s: %s features" % (ds, nf))
        time.sleep(0.5)


LAYERS = [("geocode", layer_geocode), ("osm", layer_osm), ("dem", layer_dem), ("elvis", layer_elvis),
          ("aerial", layer_aerial), ("commons", layer_commons), ("council", layer_council)]


def main():
    args = [x for x in sys.argv[1:] if not x.startswith("--")]
    if not args:
        print(__doc__)
        sys.exit(1)
    root = args[0]
    only = skip = None
    for x in sys.argv[1:]:
        if x.startswith("--only="):
            only = x[7:].split(",")
        if x.startswith("--skip="):
            skip = x[7:].split(",")
    for area, a in AREAS.items():
        if only and area not in only:
            continue
        out = os.path.join(root, area)
        log("== %s" % area)
        for name, fn in LAYERS:
            if skip and name in skip:
                continue
            try:
                fn(area, a, out)
            except Exception as err:
                log("  %s FAILED: %s" % (name, err))
    log("done")


if __name__ == "__main__":
    main()
