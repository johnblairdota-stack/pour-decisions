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

# ---------------------------------------------------------------- Spire massing (step 2)
# Tower plate traced from the architect's "Typical Floor Plan" (my_photos/spire/Spire-Residences floor
# plan.jpg, NOT in git): pixel points, image 1414 x 1000, y down. Scale bar 0-10 m = 115 -> 333 px.
# Slab edge (outer line, balconies included), clockwise from the top-left.
TOWER_PLAN = {
    "px": [(300, 128), (400, 112), (500, 118), (600, 124), (700, 124), (800, 118), (900, 110), (960, 108),
           (1020, 140), (1060, 200), (1100, 260), (1150, 330), (1190, 400), (1225, 450), (1240, 500),
           (1230, 560), (1200, 620), (1160, 680), (1110, 740), (1050, 790), (980, 830), (900, 860),
           (800, 880), (720, 892), (650, 878), (580, 850), (500, 810), (420, 770), (350, 730), (290, 690),
           (245, 640), (215, 580), (205, 500), (215, 420), (235, 330), (255, 250), (275, 180)],
    "core_px": (555, 365, 860, 560),        # lift + stair core box (x0, y0, x1, y1)
    "px_per_m": 25.5,             # scale bar reads 21.8 px/m, but the 2018 roof is ~16% smaller: fitted
    # Plan +x (the straight top edge) runs along Ann St, 40.5 deg from east. Checked on the roof plan
    # vs aerial_2018: pool on the E side, plant on the NW side, pointed corner to the S.
    "rotation_deg": 40.5,
    # Where the plate's centroid sits in the local frame: roof centroid read from aerial_2018_site160m
    # (lean of the roof ignored, OSM outlines of the neighbours sit on their roofs too). Tuned by overlay.
    "centre_xy": (-2.5, 2.5),
}
# Levels. Facts (John's notes): 43 suspended PT slabs, 2 pours each, L6 = 1250 mm transfer slab.
# Not from drawings (rough, from the podium elevations and the OSM height): podium top ~11.5 m over
# Ann St; ground floor 4.5 m; L1-L6 3.2 m; typical floor-to-floor solved so the roof slab lands at
# the OSM height. Flagged in the metadata as solved, not measured.
LEVELS = {
    "ground_floor_m": 4.5,
    "podium_ftf_m": 3.2,
    "podium_levels": 3,            # L1-L3 fill the whole lot (OSM footprint); tower plate from L4 up
    "transfer_level": 6,
    "slab_m": 0.20,                # typical PT slab
    "transfer_m": 1.25,
    "top_level": 43,
    "roof_over_top_m": 3.0,        # roof slab above L43
    "parapet_m": 1.2,
    "pour_split": "plan x = 0",    # 2 pours a level: split across the short axis through the core
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
    "john": "John does not know where the hoist was (14 Nov 2026). Keep as a placeholder.",
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


# ================================================================ Spire massing helpers
def plan_to_local(px, py):
    """Floor-plan pixel -> local metres (rotated and placed per TOWER_PLAN)."""
    P = TOWER_PLAN
    cx, cy = _plan_centroid_px()
    u = (px - cx) / P["px_per_m"]
    v = -(py - cy) / P["px_per_m"]          # image y is down
    a = math.radians(P["rotation_deg"])
    x0, y0 = P["centre_xy"]
    return (x0 + u * math.cos(a) - v * math.sin(a), y0 + u * math.sin(a) + v * math.cos(a))


def _plan_centroid_px():
    pts = TOWER_PLAN["px"]
    a = cx = cy = 0.0
    for i in range(len(pts)):
        (x1, y1), (x2, y2) = pts[i], pts[(i + 1) % len(pts)]
        c = x1 * y2 - x2 * y1
        a += c
        cx += (x1 + x2) * c
        cy += (y1 + y2) * c
    a *= 0.5
    return cx / (6 * a), cy / (6 * a)


def tower_outline():
    return [plan_to_local(*p) for p in TOWER_PLAN["px"]]


def core_outline():
    x0, y0, x1, y1 = TOWER_PLAN["core_px"]
    return [plan_to_local(x, y) for x, y in ((x0, y1), (x1, y1), (x1, y0), (x0, y0))]


def pour_split_line():
    """Two local points on the pour joint (plan x through the plate centroid, along plan y)."""
    cx, cy = _plan_centroid_px()
    return plan_to_local(cx, cy - 600), plan_to_local(cx, cy + 600)


def spire_base_ahd():
    """Ground floor level: ground at the middle of the Ann St frontage (main entry side)."""
    return round(ground_z(*TRUCK_GATE["centre_xy"]), 2)


def spire_levels():
    """List of levels, bottom up: name, number, kind, top-of-slab AHD, slab thickness, pours."""
    Lv = LEVELS
    base = spire_base_ahd()
    roof = base + SPIRE["height_m"] - Lv["parapet_m"]
    out = [{"name": "GF", "n": 0, "kind": "ground", "top_ahd": base, "slab_m": 0.3, "pours": 1}]
    z = base + Lv["ground_floor_m"]
    for n in range(1, Lv["transfer_level"] + 1):
        kind = "podium" if n <= Lv["podium_levels"] else ("transfer" if n == Lv["transfer_level"] else "tower")
        out.append({"name": "L%02d" % n, "n": n, "kind": kind, "top_ahd": round(z, 3),
                    "slab_m": Lv["transfer_m"] if kind == "transfer" else Lv["slab_m"], "pours": 2})
        z += Lv["podium_ftf_m"]
    z_t = out[-1]["top_ahd"]
    n_typ = Lv["top_level"] - Lv["transfer_level"]          # L7 .. L43
    ftf = (roof - Lv["roof_over_top_m"] - z_t) / n_typ
    for n in range(Lv["transfer_level"] + 1, Lv["top_level"] + 1):
        z_t += ftf
        out.append({"name": "L%02d" % n, "n": n, "kind": "tower", "top_ahd": round(z_t, 3),
                    "slab_m": Lv["slab_m"], "pours": 2})
    out.append({"name": "RF", "n": Lv["top_level"] + 1, "kind": "roof", "top_ahd": round(roof, 3),
                "slab_m": Lv["slab_m"], "pours": 1})
    for lv in out:
        lv["typical_ftf_solved_m"] = round(ftf, 3)
    return out