"""South Bank Parklands and the Cultural Forecourt in the master render (John, 22 Nov: "build the BRISBANE sign at South
Bank and the rest of South Bank in better detail").

Before this the whole bank was bare grey ground with LiDAR tree blobs sitting on it. Now:
  * the ground is a mosaic of lawn, garden bed, paving, sand and lagoon water read off the State aerial (2 m cells
    smoothed to 1 m), cut by the river mask, building footprints and roads;
  * Clem Jones Promenade is a clean paved ribbon along the bank with a river wall, rail and lamp posts;
  * the Cultural Forecourt lawn and the BRISBANE sign (eight block letters, about 2.5 m tall) are placed by hand from
    the three Commons sign photos;
  * the trees are replanted with clear trunks and raised crowns, palms round Streets Beach;
  * the Arbour (curled steel posts under magenta bougainvillea) winds through the parklands.

No OpenStreetMap detail of the parklands could be fetched for this (the cloud cannot reach it), so the Arbour route and
the sign position are read off the aerial and the photos, not surveyed."""
import csv
import gzip
import json
import math
import os

import numpy as np

import common as C
import layout as L

# inland edge down the back of the parklands, then back up the river (water is cut by the river mask)
ZONE = [(-1112.0, -1120.0), (-1075.0, -1260.0), (-1010.0, -1400.0), (-962.0, -1500.0), (-915.0, -1600.0), (-880.0, -1680.0),
        (-850.0, -1760.0), (-800.0, -1850.0), (-750.0, -1930.0), (-690.0, -2010.0), (-640.0, -2060.0), (-520.0, -2060.0),
        (-560.0, -1800.0), (-650.0, -1560.0), (-800.0, -1380.0), (-940.0, -1200.0), (-1020.0, -1120.0)]
BANK_GUESS = [(-1062.0, -1140.0), (-1019.0, -1205.0), (-987.0, -1260.0), (-957.0, -1310.0), (-927.0, -1360.0), (-887.0, -1410.0),
              (-857.0, -1460.0), (-815.0, -1550.0), (-750.0, -1600.0), (-705.0, -1650.0), (-670.0, -1700.0), (-655.0, -1750.0),
              (-635.0, -1800.0), (-610.0, -1850.0), (-585.0, -1900.0), (-570.0, -1950.0), (-560.0, -2000.0)]
# City Botanic Gardens and the Gardens Point bank (John, 22 Nov: the park looked poor from the tower tops). Buildings,
# roads and the river are cut out of it, so the ring only has to be generous.
GARDENS = [(-335.0, -1170.0), (125.0, -1170.0), (125.0, -1800.0), (-60.0, -1840.0), (-200.0, -1800.0), (-200.0, -1560.0), (-330.0, -1380.0)]
POND = (-238.0, -1262.0, 16.0, 10.0)                             # the lagoon by the Alice St side: centre, half axes (2022 aerial)
BEACH = (-830.0, -1790.0, -640.0, -1570.0)                       # Streets Beach: sand and lagoon only count in here
ARBOUR = [(-962.0, -1392.0), (-940.0, -1440.0), (-918.0, -1490.0), (-893.0, -1535.0), (-882.0, -1575.0), (-878.0, -1615.0),
          (-862.0, -1648.0), (-843.0, -1690.0), (-822.0, -1740.0), (-800.0, -1785.0), (-775.0, -1830.0), (-750.0, -1870.0),
          (-720.0, -1905.0), (-690.0, -1940.0), (-655.0, -1985.0)]
PROM_W = 9.0                                                     # Clem Jones Promenade width (m)
SIGN = {"s": -6.0, "t": 17.5, "h": 2.5, "depth": 0.7, "gap": 0.3}   # along the bank from the forecourt datum, inland of the bank
TERRACE = (15.0, 56.0, 5.45)                                     # forecourt terrace: river edge and inland edge (m from the bank), level (m AHD; 2019 LiDAR ground is 4.4 to 5.3)
SIGN_DATUM = (-1019.0, -1205.0)                                  # bank point the forecourt is laid out from (snapped to the mask)
LETTERS = [("B", (0.80, 0.02, 0.22), (0.90, 0.20, 0.02)), ("R", (0.42, 0.03, 0.55), (0.85, 0.05, 0.40)),
           ("I", (0.95, 0.60, 0.02), (0.85, 0.08, 0.30)), ("S", (0.05, 0.14, 0.75), (0.45, 0.06, 0.70)),
           ("B", (0.08, 0.10, 0.70), (0.02, 0.45, 0.80)), ("A", (0.01, 0.45, 0.50), (0.02, 0.20, 0.60)),
           ("N", (0.03, 0.45, 0.08), (0.01, 0.12, 0.05)), ("E", (0.38, 0.05, 0.60), (0.85, 0.15, 0.50))]
MATS = {   # name: (rgb, roughness)
    "sb_lawn": ((0.150, 0.270, 0.045), 0.95), "sb_garden": ((0.045, 0.085, 0.030), 0.95), "sb_pave": ((0.520, 0.500, 0.455), 0.85),
    "sb_prom": ((0.600, 0.585, 0.545), 0.8), "sb_sand": ((0.800, 0.730, 0.560), 0.95), "sb_lagoon": ((0.060, 0.520, 0.560), 0.06),
    "sb_wall": ((0.640, 0.630, 0.600), 0.8), "sb_steel": ((0.300, 0.310, 0.330), 0.4), "sb_post": ((0.130, 0.120, 0.150), 0.5),
    "sb_bloom": ((0.720, 0.030, 0.330), 0.8), "sb_frond": ((0.085, 0.200, 0.045), 0.6), "sb_palm_trunk": ((0.420, 0.390, 0.330), 0.85),
    "sb_plinth": ((0.300, 0.300, 0.300), 0.8), "sb_pond": ((0.030, 0.045, 0.028), 0.05)}
_PROM = None                                                     # (bank line, promenade level per point, inland side) once built


def camera_fix(x, y, z=None, eye=1.65):
    """Where a photo camera really stood once South Bank has its own surfaces: a camera on the promenade goes to the
    rail (the photos are taken leaning on it, no rail in frame) at eye height above the paving; one on the forecourt
    terrace stands on the terrace. Returns (x, y, z) or None when the camera is somewhere else."""
    if _PROM is None:
        return None
    line, zs, sgn = _PROM
    i = min(range(len(line)), key=lambda k: (line[k][0] - x) ** 2 + (line[k][1] - y) ** 2)
    a, b = line[max(i - 1, 0)], line[min(i + 1, len(line) - 1)]
    dl = math.hypot(b[0] - a[0], b[1] - a[1]) or 1.0
    nx, ny = -(b[1] - a[1]) / dl * sgn, (b[0] - a[0]) / dl * sgn     # inland
    t = (x - line[i][0]) * nx + (y - line[i][1]) * ny
    if 0 < i < len(line) - 1 and -8.0 < t < PROM_W + 0.5 and (z is None or z < zs[i] + 3.0):
        return line[i][0] - nx * 0.5, line[i][1] - ny * 0.5, zs[i] + eye
    o, u, n = forecourt_frame(line)
    s2, t2 = (x - o[0]) * u[0] + (y - o[1]) * u[1], (x - o[0]) * n[0] + (y - o[1]) * n[1]
    if -52.0 < s2 < 42.0 and TERRACE[0] < t2 < TERRACE[1] and z is None:
        return x, y, TERRACE[2] + eye
    return None


def in_zone(x, y):
    """True where this module plants the trees itself (city_wide and cbd_ext skip their own there)."""
    if -340.0 < x < 130.0 and -1845.0 < y < -1165.0:
        return C.point_in_ring(x, y, GARDENS)
    return ZONE[0][0] - 10 < x < -500.0 and -2070.0 < y < -1110.0 and C.point_in_ring(x, y, ZONE)


def _water():
    rv = json.load(open(os.path.join(L.REF, "river", "river.json")))
    wat = np.frombuffer(gzip.open(os.path.join(L.REF, "river", "water_2m.u8.gz")).read(), "u1").reshape(rv["rows"], rv["cols"])
    return rv, wat


def bank_line():
    """The guessed bank snapped to the river mask (first dry cell going inland), smoothed. Returns points and inland normals."""
    rv, wat = _water()
    x0, y1, st = rv["box_local"][0], rv["box_local"][3], rv["step_m"]

    def wet(x, y):
        c, r = int((x - x0) / st), int((y1 - y) / st)
        return bool(wat[r, c])
    pts = C.densify(BANK_GUESS, 3.0)
    out = []
    for i, (x, y) in enumerate(pts):
        a, b = pts[max(i - 1, 0)], pts[min(i + 1, len(pts) - 1)]
        dl = math.hypot(b[0] - a[0], b[1] - a[1])
        ux, uy = (b[0] - a[0]) / dl, (b[1] - a[1]) / dl
        nx, ny = -uy, ux                                           # left of travel; travel runs upstream to downstream along the south bank
        if wet(x + nx * 30.0, y + ny * 30.0) and not wet(x - nx * 30.0, y - ny * 30.0):
            nx, ny = -nx, -ny
        k = None
        for q in range(-60, 61):                                   # from 30 m out in the river to 30 m inland
            d = q * 0.5
            if not wet(x + nx * d, y + ny * d) and wet(x + nx * (d - 1.0), y + ny * (d - 1.0)):
                k = d
                break
        out.append([x, y, nx, ny, k])
    ks = [o[4] for o in out]
    for i, o in enumerate(out):                                    # fill misses, then a moving average
        if o[4] is None:
            near = [ks[j] for j in range(max(0, i - 8), min(len(ks), i + 9)) if ks[j] is not None]
            o[4] = sum(near) / len(near) if near else 0.0
    sm = []
    for i in range(len(out)):
        w = [out[j][4] for j in range(max(0, i - 4), min(len(out), i + 5))]
        w.sort()
        sm.append(w[len(w) // 2])
    sm2 = [sum(sm[max(0, i - 3):i + 4]) / len(sm[max(0, i - 3):i + 4]) for i in range(len(sm))]
    line = [(o[0] + o[2] * k, o[1] + o[3] * k) for o, k in zip(out, sm2)]
    nrm = [(o[2], o[3]) for o in out]
    return line, nrm


def forecourt_frame(line):
    """Datum on the bank beside the forecourt, the unit vector along the bank (downstream, to the south-east) and inland."""
    i = min(range(len(line)), key=lambda k: math.hypot(line[k][0] - SIGN_DATUM[0], line[k][1] - SIGN_DATUM[1]))
    a, b = line[max(i - 6, 0)], line[min(i + 6, len(line) - 1)]
    dl = math.hypot(b[0] - a[0], b[1] - a[1])
    u = ((b[0] - a[0]) / dl, (b[1] - a[1]) / dl)
    n = (u[1], -u[0])
    if n[0] > 0:                                                   # inland is to the west here
        n = (-n[0], -n[1])
    return line[i], u, n


def fc(o, u, n, s, t):
    return (o[0] + u[0] * s + n[0] * t, o[1] + u[1] * s + n[1] * t)


def forecourt_lawn(o, u, n):
    """The lawn the sign stands at the river edge of (photo a is taken from the lawn, photo b from the path behind its bollards)."""
    return [fc(o, u, n, *p) for p in ((-46.0, 16.0), (36.0, 16.0), (36.0, 40.0), (-15.0, 40.0), (-15.0, 33.0), (-46.0, 33.0))]


def _rgb(bx0, by0, bx1, by1):
    """1 m colour grid of a box: the 2 m State aerial, sharpened by the 0.5 m aerial where the tower packs carry it."""
    from PIL import Image
    Image.MAX_IMAGE_PIXELS = None
    rv, wat = _water()
    X0, Y1 = rv["box_local"][0], rv["box_local"][3]
    W, H = int(bx1 - bx0), int(by1 - by0)
    box = ((bx0 - X0) / 2, (Y1 - by1) / 2, (bx1 - X0) / 2, (Y1 - by0) / 2)
    rgb = np.asarray(Image.open(os.path.join(L.REF, "river", "aerial_wide.jpg")).convert("RGB").crop(box).resize((W, H), Image.BILINEAR)).astype("f4")
    wt = np.asarray(Image.fromarray(wat * 255).crop(box).resize((W, H), Image.BILINEAR)) > 100
    fp = os.path.join(L.REF, "ext", "aerial_2022_ext.jpg")
    if os.path.exists(fp):
        m = json.load(open(os.path.join(L.REF, "ext", "ext.json")))
        ex0, ey1 = m["box_local"][0], m["box_local"][3]
        fine = np.asarray(Image.open(fp).convert("RGB").crop(((bx0 - ex0) * 2, (ey1 - by1) * 2, (bx1 - ex0) * 2, (ey1 - by0) * 2)).resize((W, H), Image.BOX)).astype("f4")
        ok = np.abs(fine - np.array([86.0, 90.0, 76.0])).max(2) > 9.0      # (86, 90, 76) is the aerial's no-data fill; outside the image crops to black
        ok &= fine.max(2) > 8.0
        ok = ~_near(~ok, 2)
        rgb[ok] = fine[ok]
    return rgb, wt


def classify_zone(ring, beach=None):
    """1 m class grid over a ring: 0 nothing, 1 paving, 2 lawn, 3 garden bed (under canopy), 4 sand, 5 lagoon."""
    from PIL import Image, ImageDraw
    bx0, by0 = min(p[0] for p in ring) - 4, min(p[1] for p in ring) - 4
    bx1, by1 = max(p[0] for p in ring) + 4, max(p[1] for p in ring) + 4
    bx0, by0, bx1, by1 = [2 * math.floor(v / 2) for v in (bx0, by0, bx1, by1)]
    W, H = int(bx1 - bx0), int(by1 - by0)
    rgb, wt = _rgb(bx0, by0, bx1, by1)
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    mean = (r + g + b) / 3.0
    green = g - (r + b) / 2.0
    cls = np.ones((H, W), "u1")
    cls[(green > 6.0) & (mean > 86.0)] = 2
    cls[(green > 4.0) & (mean <= 86.0)] = 3
    cls[(mean <= 60.0)] = 3                                        # deep shade under figs
    if beach:
        xs = bx0 + np.arange(W) + 0.5
        ys = by1 - np.arange(H) - 0.5
        XX, YY = np.meshgrid(xs, ys)
        inb = (XX > beach[0]) & (XX < beach[2]) & (YY > beach[1]) & (YY < beach[3])
        lag = inb & (b > r + 14.0) & (mean > 120.0)
        cls[inb & (mean > 178.0) & (green < 6.0)] = 4
        cls[lag] = 5
    mk = Image.new("L", (W, H), 0)
    d = ImageDraw.Draw(mk)
    d.polygon([(p[0] - bx0, by1 - p[1]) for p in ring], fill=1)
    zone = np.asarray(mk) > 0
    bd = Image.new("L", (W, H), 0)
    d = ImageDraw.Draw(bd)
    for fp in (("wide", "buildings_wide.json.gz"), ("ext", "buildings_ext.json"), ("lidar", "buildings_clean.json")):
        p = os.path.join(L.REF, *fp)
        if not os.path.exists(p):
            continue
        for rec in json.load(L.ropen(p))["buildings"]:
            for t in rec["tiers"]:
                rg = t["ring"]
                if max(q[0] for q in rg) < bx0 or min(q[0] for q in rg) > bx1 or max(q[1] for q in rg) < by0 or min(q[1] for q in rg) > by1:
                    continue
                d.polygon([(q[0] - bx0, by1 - q[1]) for q in rg], fill=1, outline=1)
    built = np.asarray(bd) > 0
    cls[~zone | wt | built] = 0
    if beach:
        cls[(cls == 4) & ~_near(cls == 5, 45)] = 1                  # pale paving far from the lagoon is not sand
    return cls, (bx0, by1), zone & ~wt, built


def classify(line):
    """South Bank: the zone grid with the promenade band and the forecourt blanked (they are drawn as clean polygons)."""
    from PIL import Image, ImageDraw
    cls, org, zone, built = classify_zone(ZONE, BEACH)
    bx0, by1 = org
    H, W = cls.shape
    pm = Image.new("L", (W, H), 0)
    d = ImageDraw.Draw(pm)
    off = C.offset_line(line, PROM_W) if _inland_left(line) else C.offset_line(line, -PROM_W)
    d.polygon([(p[0] - bx0, by1 - p[1]) for p in line + off[::-1]], fill=1)
    o, u, n = forecourt_frame(line)
    d.polygon([(p[0] - bx0, by1 - p[1]) for p in (fc(o, u, n, -52, 0), fc(o, u, n, 42, 0), fc(o, u, n, 42, TERRACE[1]), fc(o, u, n, -52, TERRACE[1]))], fill=1)
    cls[np.asarray(pm) > 0] = 0
    return cls, org, zone, built


def _near(mask, rad):
    """Crude dilation by rad cells (box), numpy only."""
    m = mask.astype("u1")
    c = np.cumsum(np.cumsum(np.pad(m, rad), 0), 1)
    c = np.pad(c, ((1, 0), (1, 0)))
    k = 2 * rad + 1
    s = c[k:, k:] - c[:-k, k:] - c[k:, :-k] + c[:-k, :-k]
    return s > 0


def _inland_left(line):
    """True when inland is to the left of travel along the bank line."""
    rv, wat = _water()
    x0, y1, st = rv["box_local"][0], rv["box_local"][3], rv["step_m"]
    i = len(line) // 2
    a, b = line[i - 2], line[i + 2]
    dl = math.hypot(b[0] - a[0], b[1] - a[1])
    nx, ny = -(b[1] - a[1]) / dl, (b[0] - a[0]) / dl
    x, y = line[i][0] + nx * 20.0, line[i][1] + ny * 20.0
    return not wat[int((y1 - y) / st), int((x - x0) / st)]


def sign_letters(line):
    """Each letter: (char, colours, centre xy, width). The sign reads left to right from the forecourt side."""
    o, u, n = forecourt_frame(line)
    h = SIGN["h"]
    ws = [h * (0.36 if ch == "I" else 0.78) for ch, _, _ in LETTERS]
    total = sum(ws) + SIGN["gap"] * (len(ws) - 1)
    # a viewer on the forecourt looks toward the river (along -n); their left is then -u when u x n points down
    left = (-u[0], -u[1]) if (u[0] * n[1] - u[1] * n[0]) < 0 else (u[0], u[1])
    # check: left = rotate view (-n) by +90 deg
    v = (-n[0], -n[1])
    left = (-v[1], v[0])
    c0 = fc(o, u, n, SIGN["s"], SIGN["t"])
    out, run = [], -total / 2
    for (ch, c1, c2), w in zip(LETTERS, ws):
        mid = run + w / 2
        out.append((ch, c1, c2, (c0[0] - left[0] * mid, c0[1] - left[1] * mid), w))
        run += w + SIGN["gap"]
    return out, left, n, total


def trees(cls, org, built, ring=None, fill=False, land=None, line=None):
    """Tree points in a zone: (x, y, ground or None, height, kind). LiDAR points where the packs have them; with fill,
    canopy the aerial shows but no point covers gets a jittered 9 m grid of its own (ground None = sample it)."""
    ring = ring or ZONE
    out = []
    H, W = cls.shape
    sand = _near(cls >= 4, 9)
    have = np.zeros((H, W), bool)
    lp = np.array(line) if line else None
    if land is not None:
        land = ~_near(~land, 2)                                    # two metres back from the water
    x0, y0 = min(p[0] for p in ring), min(p[1] for p in ring)
    x1, y1 = max(p[0] for p in ring), max(p[1] for p in ring)
    for fp in (os.path.join(L.REF, "wide", "tree_points_wide.csv.gz"), os.path.join(L.REF, "ext", "tree_points_ext.csv")):
        if not os.path.exists(fp):
            continue
        ext = "ext" in os.path.basename(fp)
        with L.ropen(fp) as f:
            for r in csv.DictReader(f):
                x, y = float(r["x_local"]), float(r["y_local"])
                if not (x0 < x < x1 and y0 < y < y1):
                    continue
                h, g = float(r["height_m"]), float(r["ground_ahd"])
                if not C.point_in_ring(x, y, ring) or h < 3.5 or h > 45.0:
                    continue
                if not ext and x > -933.0 + 2.0 and ring is ZONE:  # the ext box has its own, denser points
                    continue
                c, rw = int(x - org[0]), int(org[1] - y)
                if not (0 <= rw < H and 0 <= c < W) or built[rw, c] or (land is not None and not land[rw, c]):
                    continue
                if lp is not None and ((lp[:, 0] - x) ** 2 + (lp[:, 1] - y) ** 2).min() < 25.0:      # keep the rail clear (photo cameras stand at it)
                    continue
                have[rw, c] = True
                out.append((x, y, g, h, "palm" if sand[rw, c] else _kind(x, y, h)))
    if fill:
        have = _near(have, 7)
        gy = 4
        while gy < H:
            gx = 4
            while gx < W:
                hsh = math.sin(gx * 12.9898 + gy * 78.233) * 43758.5453
                j1 = hsh - math.floor(hsh)
                j2 = hsh * 7.13 - math.floor(hsh * 7.13)
                c, rw = int(gx + (j1 - 0.5) * 6), int(gy + (j2 - 0.5) * 6)
                gx += 9
                if 0 <= rw < H and 0 <= c < W and cls[rw, c] == 3 and not have[rw, c] and (land is None or land[rw, c]):
                    h = 9.0 + 12.0 * j2
                    out.append((org[0] + c + 0.5, org[1] - rw - 0.5, None, h, _kind(org[0] + c, org[1] - rw, h)))
            gy += 9
    return out


def _kind(x, y, h):
    """Species mix by height and a position hash: broad figs, conical hoop and bunya pines, palms, ordinary shade trees."""
    hsh = math.sin(x * 127.1 + y * 311.7) * 43758.5453
    j = hsh - math.floor(hsh)
    if h > 24.0 and j < 0.45:
        return "pine"
    if h > 15.0:
        return "fig" if j < 0.75 else "pine"
    if 8.0 < h < 15.0 and j > 0.9:
        return "palm"
    return "shade"


def plan_image(path):
    """Top-down check of the layout over the aerial (no Blender needed)."""
    from PIL import Image, ImageDraw
    line, nrm = bank_line()
    cls, org, zone, built = classify(line)
    pal = np.array([(40, 40, 40), (170, 165, 150), (90, 170, 60), (30, 80, 30), (230, 210, 150), (60, 200, 210)], "u1")
    im = Image.fromarray(pal[cls]).resize((cls.shape[1] * 2, cls.shape[0] * 2), Image.NEAREST)
    d = ImageDraw.Draw(im)
    P = lambda p: ((p[0] - org[0]) * 2, (org[1] - p[1]) * 2)
    d.line([P(p) for p in line], fill=(255, 255, 255), width=2)
    o, u, n = forecourt_frame(line)
    d.polygon([P(p) for p in forecourt_lawn(o, u, n)], outline=(0, 255, 0))
    for ch, c1, c2, c, w in sign_letters(line)[0]:
        d.ellipse([P(c)[0] - 2, P(c)[1] - 2, P(c)[0] + 2, P(c)[1] + 2], fill=tuple(int(v * 255) for v in c1))
    d.line([P(p) for p in ARBOUR], fill=(255, 0, 200), width=2)
    for x, y, g, h, k in trees(cls, org, built):
        d.point(P((x, y)), fill=(255, 255, 0) if k == "palm" else (0, 0, 0))
    gc, gorg, gz, gb = classify_zone(GARDENS)
    gi = Image.fromarray(pal[gc]).resize((gc.shape[1] * 2, gc.shape[0] * 2), Image.NEAREST)
    gd = ImageDraw.Draw(gi)
    cols = {"palm": (255, 255, 0), "pine": (255, 0, 0), "fig": (0, 0, 0), "shade": (0, 0, 255)}
    for x, y, g, h, k in trees(gc, gorg, gb, GARDENS, True):
        gd.point(((x - gorg[0]) * 2, (gorg[1] - y) * 2), fill=cols[k] if g is not None else (255, 255, 255))
    gi.save(path.replace(".png", "_gardens.png"))
    for nm, p in (("a", (-1058, -1210)), ("b", (-1057, -1203)), ("c", (-1081, -1203)), ("1", (-969, -1276)), ("2", (-882, -1406))):
        d.text(P(p), nm, fill=(255, 0, 0))
    im.save(path)
    return cls.shape, sign_letters(line)[0][0][3], sign_letters(line)[0][-1][3]


# ----------------------------------------------------------------------------------------------------------- Blender
def _mat(name, rgb, rough, rgb2=None, scale=0.2, emit=0.0, metal=0.0):
    """Plain node material the morning look leaves alone; rgb2 adds a soft two-tone noise so big areas are not flat."""
    import bpy
    m = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    bs = nt.nodes.get("Principled BSDF")
    bs.inputs["Base Color"].default_value = (*rgb, 1)
    bs.inputs["Roughness"].default_value = rough
    bs.inputs["Metallic"].default_value = metal
    if rgb2 and not nt.nodes.get("sb_noise"):
        geo = nt.nodes.new("ShaderNodeNewGeometry")
        no = nt.nodes.new("ShaderNodeTexNoise")
        no.name = "sb_noise"
        no.inputs["Scale"].default_value = scale
        no.inputs["Detail"].default_value = 4.0
        ramp = nt.nodes.new("ShaderNodeValToRGB")
        ramp.color_ramp.elements[0].position, ramp.color_ramp.elements[1].position = 0.38, 0.62
        ramp.color_ramp.elements[0].color, ramp.color_ramp.elements[1].color = (*rgb, 1), (*rgb2, 1)
        nt.links.new(geo.outputs["Position"], no.inputs["Vector"])
        nt.links.new(no.outputs["Fac"], ramp.inputs["Fac"])
        nt.links.new(ramp.outputs["Color"], bs.inputs["Base Color"])
        if emit:
            nt.links.new(ramp.outputs["Color"], bs.inputs["Emission Color"])
    if emit:
        bs.inputs["Emission Strength"].default_value = emit
        if not rgb2:
            bs.inputs["Emission Color"].default_value = (*rgb, 1)
    m.diffuse_color = (*rgb, 1)
    m["look_done"] = True
    return m


def _mosaic(cls, org, G, col, prefix="sb_ground_", run=6):
    """One mesh per ground class: row runs of 1 m cells (cut every 6 m so they follow the ground), draped and lifted."""
    import far_roads as FR
    lifts = {1: ("sb_pave", 0.10), 2: ("sb_lawn", 0.14), 3: ("sb_garden", 0.12), 4: ("sb_sand", 0.16), 5: ("sb_lagoon", 0.22), 6: ("sb_pond", 0.22)}
    names = []
    H, W = cls.shape
    for k, (mname, lift) in lifts.items():
        quads = []
        for r in range(H):
            row = cls[r] == k
            if not row.any():
                continue
            d = np.diff(np.concatenate(([0], row.astype("i1"), [0])))
            for a, b in zip(np.flatnonzero(d == 1), np.flatnonzero(d == -1)):
                c = a
                while c < b:
                    e = min(b, c + run)
                    quads.append((org[0] + c, org[0] + e, org[1] - r))
                    c = e
        if not quads:
            continue
        q = np.array(quads, "f8")
        if k < 5:                                                  # roads and rail keep their own surface
            mid = (q[:, 0] + q[:, 1]) / 2
            keep = np.array([not FR.on_road(mx, my - 0.5) for mx, my in zip(mid, q[:, 2])])
            q = q[keep]
        n = len(q)
        vx = np.stack([q[:, 0], q[:, 1], q[:, 1], q[:, 0]], 1).ravel()
        vy = np.stack([q[:, 2] - 1.0, q[:, 2] - 1.0, q[:, 2], q[:, 2]], 1).ravel()
        vz = G.z(vx, vy) + lift
        if k >= 5:
            vz[:] = float(np.median(vz))
        ob = C.mesh_fast(prefix + mname[3:], np.stack([vx, vy, vz], 1), np.arange(4 * n).reshape(n, 4), col, "roof")
        ob.data.materials[0] = _mats(mname)
        names.append(ob.name)
    return names


def _mats(name):
    two = {"sb_lawn": ((0.20, 0.30, 0.06), 0.25), "sb_pave": ((0.46, 0.44, 0.40), 0.6), "sb_sand": ((0.72, 0.64, 0.47), 0.4),
           "sb_garden": ((0.07, 0.11, 0.035), 0.5), "sb_prom": ((0.54, 0.525, 0.49), 0.6), "sb_bloom": ((0.55, 0.02, 0.42), 0.9)}
    rgb, rough = MATS[name]
    t = two.get(name)
    return _mat(name, rgb, rough, t[0] if t else None, t[1] if t else 0.2, metal=1.0 if name == "sb_steel" else 0.0)


def _grid(buf, o, u, n, s0, s1, t0, t1, G, lift, step=2.0, flat=None):
    """Rectangle in forecourt coordinates: draped on the ground, or flat at a level."""
    ns, nt = max(1, round((s1 - s0) / step)), max(1, round((t1 - t0) / step))
    pts = [fc(o, u, n, s0 + (s1 - s0) * i / ns, t0 + (t1 - t0) * j / nt) for j in range(nt + 1) for i in range(ns + 1)]
    zs = G.z([p[0] for p in pts], [p[1] for p in pts])
    verts = [(p[0], p[1], (float(z) if flat is None else flat) + lift) for p, z in zip(pts, zs)]
    faces = [[j * (ns + 1) + i, j * (ns + 1) + i + 1, (j + 1) * (ns + 1) + i + 1, (j + 1) * (ns + 1) + i] for j in range(nt) for i in range(ns)]
    buf.add(verts, faces, [])


def _sign(line, G, col, bufs):
    """Eight block letters from Blender's own font, squared up to the photo's chunky proportions."""
    import bpy
    letters, left, n, total = sign_letters(line)
    h, dep = SIGN["h"], SIGN["depth"]
    right = (-left[0], -left[1])
    names = []
    cx = sum(l[3][0] for l in letters) / len(letters)
    cy = sum(l[3][1] for l in letters) / len(letters)
    g0 = TERRACE[2] + 0.05
    hw = total / 2 + 0.5
    ring = [(cx + right[0] * a + n[0] * b, cy + right[1] * a + n[1] * b) for a, b in ((-hw, -0.75), (hw, -0.75), (hw, 0.75), (-hw, 0.75))]
    bufs["sb_plinth"].prism(ring, g0 - 0.5, g0 + 0.12)
    for i, (ch, c1, c2, (lx, ly), w) in enumerate(letters):
        cu = bpy.data.curves.new("sb_glyph", "FONT")
        cu.body = ch
        cu.size = 1.0
        cu.offset = 0.03                                          # heavier strokes; from 0.04 the bowls of the B close up and its face is left unfilled
        cu.extrude = 0.5
        tmp = bpy.data.objects.new("sb_glyph", cu)
        col.objects.link(tmp)
        bpy.context.view_layer.update()
        me = bpy.data.meshes.new_from_object(tmp.evaluated_get(bpy.context.evaluated_depsgraph_get()))
        bpy.data.objects.remove(tmp, do_unlink=True)
        bpy.data.curves.remove(cu)
        co = np.empty(len(me.vertices) * 3, "f4")
        me.vertices.foreach_get("co", co)
        co = co.reshape(-1, 3)
        mn, mx = co.min(0), co.max(0)
        a = (co[:, 0] - mn[0]) / (mx[0] - mn[0]) * w - w / 2       # across the letter
        b = (co[:, 1] - mn[1]) / (mx[1] - mn[1]) * h               # up
        d = (co[:, 2] - mn[2]) / (mx[2] - mn[2]) * dep - dep / 2   # toward the forecourt
        out = np.stack([lx + right[0] * a + n[0] * d, ly + right[1] * a + n[1] * d, g0 + 0.12 + b], 1)
        me.vertices.foreach_set("co", out.ravel().astype("f4"))
        me.update()
        me.name = "sb_sign_%d_%s" % (i, ch)
        ob = bpy.data.objects.new(me.name, me)
        me.materials.clear()
        me.materials.append(_mat("sb_sign_%d" % i, c1, 0.45, c2, 1.1, emit=0.08))
        col.objects.link(ob)
        names.append(ob.name)
    return names, (cx, cy)


def _palm(trunk, frond, x, y, g, h):
    import trees as T
    seed = (x * 12.9898 + y * 78.233) % 6.2832
    lx, ly = 0.07 * h * math.cos(seed), 0.07 * h * math.sin(seed)
    T.tube(trunk, (x, y, g - 0.2), (x + lx, y + ly, g + h - 1.0), 0.24, 0.15, 7)
    tx, ty, tz = x + lx, y + ly, g + h - 1.0
    for i in range(13):
        a = seed + math.tau * i / 13
        lift = 0.75 * math.sin(seed * 3.0 + i * 2.1)
        ca, sa = math.cos(a), math.sin(a)
        prev = None
        for k in range(5):
            q = k / 4.0
            rr, zz = 3.8 * q, 0.5 + 2.2 * q * (0.4 + lift * 0.5) - 3.2 * q * q
            wd = 0.6 * math.sin(math.pi * min(1.0, q + 0.15))
            cur = ((tx + ca * rr - sa * wd, ty + sa * rr + ca * wd, tz + zz), (tx + ca * rr + sa * wd, ty + sa * rr - ca * wd, tz + zz))
            if prev:
                frond.add([prev[0], prev[1], cur[1], cur[0]], [[0, 1, 2, 3]], [])
            prev = cur


CROWNS = [("sb_crown_a", (0.065, 0.160, 0.040), (0.110, 0.230, 0.055)), ("sb_crown_b", (0.040, 0.110, 0.035), (0.070, 0.160, 0.045)),
          ("sb_crown_c", (0.130, 0.250, 0.050), (0.200, 0.320, 0.070)), ("sb_crown_d", (0.090, 0.170, 0.070), (0.150, 0.210, 0.060))]
PINE = ("sb_crown_pine", (0.020, 0.060, 0.030), (0.040, 0.085, 0.035))


def _plant(points, col, prefix, G, skip=None):
    """Trees with clear trunks and raised crowns in four leaf colours, conical pines, palms. Returns names and counts."""
    import bpy
    import trees as T
    import far_roads as FR
    trunks, ptr, pfr, pine = C.MeshBuf(), C.MeshBuf(), C.MeshBuf(), C.MeshBuf()
    crowns = [C.MeshBuf() for _ in CROWNS]
    cnt = {"shade": 0, "fig": 0, "palm": 0, "pine": 0}
    for x, y, g, h, kind in points:
        if FR.on_road(x, y) or (skip and skip(x, y)):
            continue
        if g is None:
            g = float(G.z([x], [y])[0])
        hsh = math.sin(x * 12.9898 + y * 78.233) * 43758.5453
        j = hsh - math.floor(hsh)
        if kind == "palm":
            _palm(ptr, pfr, x, y, g, max(h, 7.0))
        elif kind == "pine":
            if FR.over_deck(x, y, 4.0):
                continue
            T.tube(trunks, (x, y, g - 0.2), (x, y, g + h * 0.9), 0.4, 0.1, 7)
            for k in range(5):                                     # stacked whorls, narrowing to the top
                q = k / 4.0
                T.blob(pine, x, y, g + h * (0.32 + 0.16 * k), h * (0.20 - 0.035 * k), h * 0.11)
        else:
            fig = kind == "fig"
            rr = min((0.50 if fig else 0.42) * h, 12.0 if fig else 8.5)
            if FR.over_deck(x, y, rr * 1.2):
                continue
            clear = h * (0.24 if fig else 0.28)
            T.trunk(trunks, x, y, g, 0.45 if fig else 0.2 + 0.012 * h, clear, 3, rr * 0.9)
            buf = crowns[1 if fig and j < 0.7 else int(j * 3.999)]
            T.crown(buf, x, y, g + h * (0.56 if fig else 0.60), rr, 0.8 if fig else 0.9, 6 if fig else 5)
        cnt[kind] += 1
    names = []
    jobs = [(trunks, "trunks", bpy.data.materials.get("tree_trunks")), (ptr, "palm_trunks", _mats("sb_palm_trunk")), (pfr, "palm_fronds", _mats("sb_frond")),
            (pine, "pines", _mat(PINE[0], PINE[1], 0.9, PINE[2], 0.9))]
    jobs += [(b, "crowns_" + nm[-1], _mat(nm, c1, 0.9, c2, 0.5)) for b, (nm, c1, c2) in zip(crowns, CROWNS)]
    for buf, name, mat in jobs:
        if not buf.v:
            continue
        ob = C.mesh_object(prefix + "_tree_" + name, buf.v, buf.f, col, "tree")     # "tree" in the name: render_pairs "clear" lanes find them
        if mat:
            ob.data.materials[0] = mat
        if "fronds" not in name:
            for p in ob.data.polygons:
                p.use_smooth = True
        names.append(ob.name)
    return names, cnt


def _smooth(pts, passes=2):
    for _ in range(passes):                                        # Chaikin corner cutting
        out = [pts[0]]
        for a, b in zip(pts, pts[1:]):
            out += [(a[0] * 0.75 + b[0] * 0.25, a[1] * 0.75 + b[1] * 0.25), (a[0] * 0.25 + b[0] * 0.75, a[1] * 0.25 + b[1] * 0.75)]
        pts = out + [pts[-1]]
    return pts


def _arbour(G, bufs, cls, org, built):
    """The Arbour: pairs of curling steel posts every 3.5 m with bougainvillea over the top, on its own paved path."""
    import trees as T
    pts = C.densify(_smooth(ARBOUR), 3.5)
    zs = G.z([p[0] for p in pts], [p[1] for p in pts])
    n = 0
    prev = None
    for i, ((x, y), g) in enumerate(zip(pts, zs)):
        a, b = pts[max(i - 1, 0)], pts[min(i + 1, len(pts) - 1)]
        dl = math.hypot(b[0] - a[0], b[1] - a[1]) or 1.0
        ux, uy = (b[0] - a[0]) / dl, (b[1] - a[1]) / dl
        nx, ny = -uy, ux
        g = float(g)
        c, r = int(x - org[0]), int(org[1] - y)
        if not (0 <= r < cls.shape[0] and 0 <= c < cls.shape[1]) or built[r, c]:
            prev = None
            continue
        cur = ((x + nx * 1.8, y + ny * 1.8, g + 0.2), (x - nx * 1.8, y - ny * 1.8, g + 0.2))
        if prev:
            bufs["sb_pave"].add([prev[0], prev[1], cur[1], cur[0]], [[0, 1, 2, 3]], [])
        prev = cur
        for sg in (-1.0, 1.0):
            prof = ((2.4, 0.0), (2.4, 3.2), (1.9, 4.7), (0.7, 5.5), (0.0, 5.2))     # distance out from the centre line, height
            for (d0, z0), (d1, z1) in zip(prof, prof[1:]):
                T.tube(bufs["sb_post"], (x + nx * sg * d0, y + ny * sg * d0, g + z0), (x + nx * sg * d1, y + ny * sg * d1, g + z1), 0.09, 0.08, 6)
        hsh = math.sin(x * 12.9898 + y * 78.233) * 43758.5453
        j = hsh - math.floor(hsh)
        T.blob(bufs["sb_bloom"], x + nx * (j - 0.5) * 1.6, y + ny * (j - 0.5) * 1.6, g + 5.3 + 0.3 * j, 2.6 + 0.5 * j, 0.75)
        T.blob(bufs["sb_bloom"], x + nx * (0.5 - j) * 3.0 + ux * 1.7, y + ny * (0.5 - j) * 3.0 + uy * 1.7, g + 4.6 + 0.4 * j, 1.6, 0.6)
        if i % 3 == 0:
            T.blob(bufs["sb_frond"], x - nx * 1.5 + ux * 0.9, y - ny * 1.5 + uy * 0.9, g + 5.0, 1.5, 0.55)
        n += 1
    return n


def _promenade(line, G, bufs):
    """Clem Jones Promenade: flat paved ribbon on the bank, river wall, rail and lamp posts."""
    import trees as T
    left = _inland_left(line)
    sgn = 1.0 if left else -1.0
    inner = C.offset_line(line, sgn * PROM_W)
    ref = C.offset_line(line, sgn * (PROM_W + 4.0))
    zs = np.maximum(G.z([p[0] for p in ref], [p[1] for p in ref]), 2.2)
    zs = np.convolve(np.pad(zs, 6, mode="edge"), np.ones(13) / 13.0, "valid") + 0.12
    global _PROM
    _PROM = (line, [float(v) for v in zs], sgn)
    for i in range(len(line) - 1):
        a, b, c, d = line[i], line[i + 1], inner[i + 1], inner[i]
        za, zb = float(zs[i]), float(zs[i + 1])
        bufs["sb_prom"].add([(a[0], a[1], za), (b[0], b[1], zb), (c[0], c[1], zb), (d[0], d[1], za)], [[0, 1, 2, 3]], [])
        bufs["sb_wall"].add([(a[0], a[1], -2.0), (b[0], b[1], -2.0), (b[0], b[1], zb + 0.35), (a[0], a[1], za + 0.35)], [[0, 1, 2, 3]], [])   # river face
        bufs["sb_wall"].beam((a[0], a[1], za + 0.17), (b[0], b[1], zb + 0.17), 0.45, 0.36)                                               # kerb
        bufs["sb_steel"].beam((a[0], a[1], za + 1.15), (b[0], b[1], zb + 1.15), 0.07, 0.07)
        bufs["sb_steel"].beam((a[0], a[1], za + 0.75), (b[0], b[1], zb + 0.75), 0.04, 0.04)
        bufs["sb_steel"].beam((a[0], a[1], za + 0.3), (a[0], a[1], za + 1.15), 0.06, 0.06)
        bufs["sb_wall"].add([(d[0], d[1], za), (c[0], c[1], zb), (c[0], c[1], zb - 1.5), (d[0], d[1], za - 1.5)], [[0, 1, 2, 3]], [])      # inland step
        if i % 9 == 4:                                             # lamp post every ~27 m, 1.2 m in from the inland edge
            px, py = d[0] + (a[0] - d[0]) * 0.13, d[1] + (a[1] - d[1]) * 0.13
            qx, qy = d[0] + (a[0] - d[0]) * 0.3, d[1] + (a[1] - d[1]) * 0.3
            T.tube(bufs["sb_steel"], (px, py, za), (px, py, za + 6.5), 0.10, 0.07, 6)
            bufs["sb_steel"].beam((px, py, za + 6.4), (qx, qy, za + 6.6), 0.10, 0.08)
            bufs["sb_wall"].beam((qx, qy, za + 6.55), (qx + (qx - px) * 0.35, qy + (qy - py) * 0.35, za + 6.55), 0.32, 0.12)
    return round(sum(math.hypot(b[0] - a[0], b[1] - a[1]) for a, b in zip(line, line[1:])))


def build():
    """Called by hero_towers.build once the far ground and the roads exist. Returns object names and a parts note."""
    import bpy
    import far_roads as FR
    G = FR.GROUND
    if G is None:
        return [], {}
    col = C.collection("southbank")
    line, nrm = bank_line()
    cls, org, zone, built = classify(line)
    objs = _mosaic(cls, org, G, col)
    bufs = {k: C.MeshBuf() for k in MATS}
    o, u, n = forecourt_frame(line)
    te, ti, tz = TERRACE
    pz = max(float(G.z([fc(o, u, n, 0.0, PROM_W + 4.0)[0]], [fc(o, u, n, 0.0, PROM_W + 4.0)[1]])[0]), 2.2) + 0.12
    _grid(bufs["sb_prom"], o, u, n, -52.0, 42.0, PROM_W - 0.5, te, G, 0.0, flat=pz)         # lower promenade under the terrace wall
    _grid(bufs["sb_pave"], o, u, n, -52.0, 42.0, te, ti, G, 0.0, flat=tz)
    _grid(bufs["sb_lawn"], o, u, n, -46.0, -15.0, te + 1.0, 33.0, G, 0.05, flat=tz)
    _grid(bufs["sb_lawn"], o, u, n, -15.0, 36.0, te + 1.0, 40.0, G, 0.05, flat=tz)
    for a, b in (((-52.0, te), (42.0, te + 0.5)), ((-52.0, te), (-51.5, ti)), ((41.5, te), (42.0, ti)), ((-52.0, ti - 0.5), (42.0, ti))):   # terrace walls
        ring = [fc(o, u, n, a[0], a[1]), fc(o, u, n, b[0], a[1]), fc(o, u, n, b[0], b[1]), fc(o, u, n, a[0], b[1])]
        bufs["sb_wall"].prism(ring, 0.5, tz + (0.45 if b[1] - a[1] < 1.0 and a[1] == te else 0.0))
    for s0, s1, t in ((-46.0, -15.0, 33.6), (-15.0, 36.0, 40.6)):   # stainless bollards along the path edge of the lawn
        k = 0
        while s0 + k * 3.0 <= s1:
            x, y = fc(o, u, n, s0 + k * 3.0, t)
            import trees as T
            T.tube(bufs["sb_steel"], (x, y, tz), (x, y, tz + 0.95), 0.065, 0.065, 8)
            k += 1
    sign, sign_c = _sign(line, G, col, bufs)
    objs += sign
    prom_m = _promenade(line, G, bufs)
    posts = _arbour(G, bufs, cls, org, built)
    for k, buf in bufs.items():
        if not buf.v:
            continue
        ob = C.mesh_object("sb_" + k[3:], buf.v, buf.f, col, "roof")
        ob.data.materials[0] = _mats(k)
        if k in ("sb_bloom", "sb_post", "sb_steel"):
            for p in ob.data.polygons:
                p.use_smooth = True
        objs.append(ob.name)
    lawn = forecourt_lawn(o, u, n)
    tnames, cnt = _plant(trees(cls, org, built, None, False, zone, line), col, "sb", G, lambda x, y: C.point_in_ring(x, y, lawn) or math.hypot(x - sign_c[0], y - sign_c[1]) < 14.0)
    objs += tnames
    gobjs, gparts = gardens(G, col)
    objs += gobjs
    area = {nm: int((cls == k).sum()) for k, nm in ((1, "paving"), (2, "lawn"), (3, "garden beds"), (4, "sand"), (5, "lagoon"))}
    parts = {"BRISBANE sign": "8 letters, %.1f m tall, %.1f m long" % (SIGN["h"], sign_letters(line)[3]),
             "Cultural Forecourt": "lawn, paving, bollards", "Clem Jones Promenade": "%d m of paving, river wall, rail, lamp posts" % prom_m,
             "Ground from the aerial (m2)": area, "The Arbour": "%d post pairs under bougainvillea" % posts, "Trees replanted": cnt, "City Botanic Gardens": gparts}
    return objs, parts


def gardens(G, col):
    """City Botanic Gardens: lawns, beds and paths from the aerial, the lagoon, and a mixed planting in place of the
    uniform LiDAR blobs."""
    cls, org, zone, built = classify_zone(GARDENS)
    px, py, pa, pb = POND
    H, W = cls.shape
    xs = org[0] + np.arange(W) + 0.5
    ys = org[1] - np.arange(H) - 0.5
    XX, YY = np.meshgrid(xs, ys)
    e = ((XX - px) / pa) ** 2 + ((YY - py) / pb) ** 2
    cls[(e < 1.0) & (cls > 0)] = 6
    cls[(e >= 1.0) & (e < 1.5) & (cls > 0)] = 1                     # path round the lagoon
    objs = _mosaic(cls, org, G, col, "bg_ground_", 3)
    pts = trees(cls, org, built, GARDENS, True, zone)
    names, cnt = _plant(pts, col, "bg", G, lambda x, y: ((x - px) / pa) ** 2 + ((y - py) / pb) ** 2 < 1.6)
    area = {nm: int((cls == k).sum()) for k, nm in ((1, "paths and paving"), (2, "lawn"), (3, "garden beds"), (6, "lagoon"))}
    return objs + names, {"Ground from the aerial (m2)": area, "Trees": cnt}
