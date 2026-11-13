"""Spire master layout. Every other Spire script imports this file.

Frame (all numbers in metres):
  origin  = centre of Spire's footprint (mean of OSM way 186586603's corners)
  +x      = east, +y = north (MGA zone 56 grid; grid north is within 0.02 deg of true north here)
  z       = metres AHD (Australian Height Datum, about mean sea level)

Real data lives in reference/sites/spire/ (made by prep_data.py). This file only
holds the frame, the loaders and the few things a person placed by hand
(crane, hoist, truck gate, camera spots), each with a note saying why.

Pure Python + numpy. No bpy here, so it also runs outside Blender.
"""
import gzip
import json
import math
import os

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.normpath(os.path.join(HERE, "..", "..", ".."))
REF = os.path.join(REPO, "reference", "sites", "spire")
DOCS = os.path.join(REPO, "docs", "spire")

# ---------------------------------------------------------------- frame
ORIGIN_MGA56 = (503046.57, 6962279.05)        # easting, northing of the origin
ORIGIN_LATLON = (-27.4630417, 153.0308272)    # same point, GDA94/WGS84 (Nominatim for the OSM way)
DATA_HALF = 400.0     # reference data covers x, y in [-400, 400] (an 800 m square)
MODEL_HALF = 400.0    # the blockout covers the same square

# ---------------------------------------------------------------- Spire itself
SPIRE = {
    "osm_way": 186586603,
    "name": "Spire Residences",
    "address": "550 Queen Street, Brisbane City",
    "height_m": 131.1,          # OSM height tag (roof); real data, not checked against drawings
    "levels_pt_slabs": 43,      # suspended post-tensioned slabs (John's build notes)
    "pours_per_level": 2,
    "transfer_slab_level": 6,
    "transfer_slab_thick_m": 1.25,
    "builder": "Hutchinson Builders",
    "engineer": "ADG",
    "completed": "2017-06",
}

# Default road widths (kerb to kerb, metres) by OSM highway class when the way has no width/lanes tag.
ROAD_WIDTH = {"primary": 14.0, "secondary": 12.0, "tertiary": 10.0, "secondary_link": 7.0,
              "tertiary_link": 7.0, "unclassified": 7.0, "residential": 7.0, "service": 4.5,
              "living_street": 5.0, "pedestrian": 6.0, "footway": 2.0, "steps": 2.0, "cycleway": 2.5,
              "path": 2.0}
LANE_WIDTH = 3.3
FOOTPATH_WIDTH = 3.5    # verge each side of a car road (kerb to property line), rough CBD value
KERB_HEIGHT = 0.15
LEVEL_HEIGHT = 3.2      # used only when OSM has levels but no height
DEFAULT_HEIGHT = 12.0   # used when OSM has neither (flagged in metadata)
RIVER_LEVEL_AHD = 0.3   # rough mean water level for the blockout water plane

# ---------------------------------------------------------------- hand-placed site logistics
# Worked out by eye from John's construction photos (my_photos/spire, NOT in git) and the
# 2015-2017 aerials (reference/sites/spire/aerial_*). Positions are the best read, not survey.
# "confidence": high = seen from above in an aerial; medium = clear in a photo, placed by matching;
# low = a guess from one oblique photo.
#
# Street names round the site (OSM): Ann Street runs along the NW face (4 lanes, red bus lane,
# bus stop 5 "F/S Orient Hotel" at (-24, 13)); Queen Street curves past the E face; Clark Lane
# runs along the SW face from Ann St at (-36, 11) to (-15, -14) and on to Queen St.
CRANE = {
    "kind": "external tower crane, tied to the building",
    "mast_xy": (-25.7, 8.1),      # mast centre: NW (Ann St) face, 5 m in from the west corner, 1.5 m out
    "mast_size_m": 2.0,
    "tie_face": "NW (Ann St)",
    "jib_length_m": 45.0,         # rough: the 2017 aerial shows about 31 m of jib lying over the roof
    "counter_jib_m": 14.0,
    "jib_heading_deg": -35.0,     # 2017 aerial: jib pointing SE across the roof (0 = east, CCW +)
    "height_over_roof_m": 18.0,   # rough, from the fly-by photos
    "confidence": "medium",
    "evidence": [
        "aerial_2017_site160m_0p1m.jpg: crane head and cab just off the west corner, jib lies SE over the roof",
        "photo 'construction site fly by almost complete with crane placement 2.jpg' (camera SW, looking NE "
        "up Ann St): blue mast runs the full height at the left (NW/Ann St) edge of the SW face, ties every few floors",
        "photo '... crane placement 3.jpg' (camera N, looking S to the river): mast on the near (NW) face, right-hand end",
    ],
}
HOIST = {
    "kind": "builder's hoist (personnel/materials), mast tied to the face",
    "mast_xy": (-9.5, 18.5),      # NW (Ann St) face, north end, just outside the slab edge
    "car_size_m": (3.2, 1.5),
    "face": "NW (Ann St)",
    "confidence": "low",
    "evidence": [
        "aerial_2017_site160m_0p1m.jpg: small box sticking out past the roof edge on the NW face, north end "
        "(crop px ~690,615) - reads as a hoist mast top",
        "No photo shows it clearly. Alternative: the dark vertical strip down the middle of the SW face in "
        "'... crane placement 2.jpg' may be the hoist. Ask John.",
    ],
}
TRUCK_GATE = {
    "street": "Ann Street",
    "centre_xy": (-16.0, 14.4),   # middle of the Ann St boundary
    "width_m": 7.0,
    "along_xy": (0.760, 0.650),   # unit vector along the Ann St boundary (west corner -> north corner)
    "facing": "NW",
    "kerb_zone_now": "council 'Loading Zone Commercial Vehicle 20 Min' sign at (-13.5, 21.3) (2026 data)",
    "confidence": "medium",
    "evidence": [
        "photo 'construction site 2015.jpg', April half (camera NW, looking SE): Ann St hoarding along the "
        "near edge, a truck standing just inside it about a third along from the north end",
        "aerial_2015_site160m_0p1m.jpg: two trucks inside the dig close to the Ann St line at about "
        "(-13..-6, 13..17); a truck at the Ann St kerb near the Clark Lane corner",
        "photo 'construction site 2015.jpg', March half: site sheds (3 portables) on the SW (Clark Lane) "
        "boundary near Ann St, so the gate is not on that side",
    ],
}
SITE_SHEDS = {"xy": (-20.0, -4.0), "along_xy": (0.644, -0.767), "count": 3, "size_m": (3.0, 7.0),
              "note": "3 portables along the Clark Lane (SW) boundary, 2015 aerial + March 2015 photo"}
SITE_NOTES = [
    "No photo in my_photos/spire has EXIF GPS; every spot here is read by eye.",
    "Aerials are not true-ortho: tall things lean away from the plane's nadir, so tops sit a few metres off their bases.",
]

# ---------------------------------------------------------------- camera spots for photo matching
# No photo in my_photos/spire has EXIF GPS, so each spot is estimated from what the photo shows
# (which buildings line up). pos/look_at z = metres above the ground at that point.
# lens_mm on a 36 x 24 mm sensor (long side vertical when portrait). shift_y = shift-lens rise
# (camera kept level), as a fraction of the long side, read from where the horizon sits in the photo.
# Orient Hotel = OSM "Johnny Ringo's Country Saloon" (x -3..26, y 21..49); Mantra on Queen (x -8..19,
# y 72..98, 118 m); St John's Cathedral (x -111..-50, y -132..-66).
CAMERAS = [
    {"id": "cam_ann_queen_corner", "photo": "Spire-Residences opposite corner intersection of Ann and Queen st.jpg",
     "pos": (92.0, 160.0, 1.6), "look_at": (0.0, 0.0, 1.6), "lens_mm": 24.0, "portrait": True, "shift_y": 0.32,
     "note": "Canon 5D3 at 24 mm (EXIF), shift lens. Orient Hotel dead in front of Spire, St John's spires just "
             "right of Spire (camera must sit on the side where y > 1.52 x), Mantra on Queen close on the right, "
             "Spire about a third of the frame high (~190 m away). Best fit: the Ann St junction NE of the Orient."},
    {"id": "cam_ann_far", "photo": "Spire-Residences futher away on ann st.jpg",
     "pos": (150.0, 203.0, 1.7), "look_at": (0.0, 0.0, 1.7), "lens_mm": 45.0, "portrait": True, "shift_y": 0.30,
     "note": "On Ann St about 250 m NE, looking SW down the road; Orient Hotel at the road's end just right of "
             "Spire, Mantra on Queen on the right. Lens from Spire filling ~2/3 of the frame height."},
    {"id": "cam_ann_footpath", "photo": "Spire-Residences street view Ann st 1.jpg",
     "pos": (-8.0, 30.0, 1.6), "look_at": (-70.0, -60.0, 1.6), "lens_mm": 28.0, "portrait": True, "shift_y": 0.20,
     "note": "Ann St, SE kerb, at the north end of Spire's podium, looking SW: sloped brick podium on the left, "
             "Clark Lane heritage roofs and St John's Cathedral ahead to the right of the road."},
    {"id": "cam_flyby_crane", "photo": "Spire-Residences construction site fly by almost complete with crane placement 2.jpg",
     "pos": (-120.0, -150.0, 330.0), "look_at": (0.0, 0.0, 60.0), "lens_mm": 50.0, "portrait": True,
     "shift_y": 0.0, "show_logistics": True,
     "note": "Aerial fly-by during the build (crane up): camera high to the SW looking NE up Ann St, steeply "
             "down. Used to check the crane and hoist spots, so the logistics markers are shown."},
]
TOP_VIEW = {"half": 400.0, "aerial_year": 2016}   # top-down clay overlay: whole 800 m square, 2016 aerial
SITE_VIEW = {"half": 80.0, "aerial_year": 2016}   # close top-down of the site (matches aerial_*_site160m)


# ================================================================ maths
def mga56(lat, lon):
    """GDA94 lat/lon (deg) -> MGA zone 56 easting, northing (m)."""
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


def to_local(lat, lon):
    E, N = mga56(lat, lon)
    return E - ORIGIN_MGA56[0], N - ORIGIN_MGA56[1]


def to_merc(lon, lat):
    x = lon * 20037508.34 / 180.0
    y = math.log(math.tan((90 + lat) * math.pi / 360.0)) * 20037508.34 / math.pi
    return x, y


def local_to_merc_affine():
    """Affine (2x3) that maps local (x, y) to Web Mercator (EPSG:3857). Fitted on a grid; error < 1 cm
    over the 800 m square."""
    import numpy as np
    lat0, lon0 = ORIGIN_LATLON
    rows, rhs = [], []
    for i in range(-3, 4):
        for j in range(-3, 4):
            lat, lon = lat0 + i * 0.0015, lon0 + j * 0.0015
            x, y = to_local(lat, lon)
            rows.append([x, y, 1.0])
            rhs.append(to_merc(lon, lat))
    sol, *_ = np.linalg.lstsq(np.array(rows), np.array(rhs), rcond=None)
    return sol.T  # 2x3


# ================================================================ loaders (cached)
_cache = {}


def ref(name):
    return os.path.join(REF, name)


def osm():
    """Cropped OSM (raw elements) -> dict with local-metre geometry."""
    if "osm" in _cache:
        return _cache["osm"]
    raw = json.load(gzip.open(ref("osm_spire_800m.json.gz"), "rt", encoding="utf-8"))
    nodes, ways, rels = {}, {}, []
    for el in raw["elements"]:
        t = el["type"]
        if t == "node":
            nodes[el["id"]] = to_local(el["lat"], el["lon"])
        elif t == "way":
            ways[el["id"]] = el
        else:
            rels.append(el)

    def line(w):
        return [nodes[n] for n in w["nodes"] if n in nodes]

    _cache["osm"] = out = {"nodes": nodes, "ways": ways, "rels": rels, "line": line}
    return out


def tag_float(t, *keys):
    for k in keys:
        v = t.get(k)
        if v is None:
            continue
        try:
            return float(str(v).lower().replace("m", "").strip())
        except ValueError:
            pass
    return None


def building_height(t):
    """(height above ground, source) from OSM tags."""
    h = tag_float(t, "height", "building:height")
    if h is not None:
        return h, "osm height"
    lv = tag_float(t, "building:levels")
    if lv is not None:
        return lv * LEVEL_HEIGHT, "osm levels x %.1f m" % LEVEL_HEIGHT
    return DEFAULT_HEIGHT, "default (no tag)"


def dem():
    """DEM crop: (array rows north->south, x0, y0, step). Metres AHD."""
    if "dem" in _cache:
        return _cache["dem"]
    import numpy as np
    hdr = json.load(open(ref("dem_1m.json"), encoding="utf-8"))
    a = np.frombuffer(gzip.open(ref("dem_1m.f32.gz"), "rb").read(), dtype="<f4").reshape(hdr["rows"], hdr["cols"])
    _cache["dem"] = out = (a, hdr["x0"], hdr["y0"], hdr["step"])
    return out


def ground_z(x, y):
    """Bilinear DEM height (m AHD) at local x, y."""
    a, x0, y0, s = dem()
    c = (x - x0) / s
    r = (y0 - y) / s
    c = min(max(c, 0.0), a.shape[1] - 1.001)
    r = min(max(r, 0.0), a.shape[0] - 1.001)
    c0, r0 = int(c), int(r)
    fc, fr = c - c0, r - r0
    top = a[r0, c0] * (1 - fc) + a[r0, c0 + 1] * fc
    bot = a[r0 + 1, c0] * (1 - fc) + a[r0 + 1, c0 + 1] * fc
    return float(top * (1 - fr) + bot * fr)


def aerial_path(year, kind="800m_0p5m"):
    return ref("aerial_%d_%s.jpg" % (year, kind))


AERIAL_800 = {"half": 400.0, "px": 1600, "m_per_px": 0.5}     # aerial_YYYY_800m_0p5m.jpg
AERIAL_SITE = {"half": 80.0, "px": 1600, "m_per_px": 0.1}     # aerial_YYYY_site160m_0p1m.jpg (upsampled from 0.2 m)


def local_to_aerial_px(x, y, spec=AERIAL_800):
    """Local metres -> (col, row) pixel in a local-frame aerial crop (row 0 = north edge)."""
    return (x + spec["half"]) / spec["m_per_px"], (spec["half"] - y) / spec["m_per_px"]
