import json, sys, collections
from PIL import Image
S = sys.argv[1]; rdir = sys.argv[2]
C = json.load(open(S + "/calib.json"))
photos = {"cathedral_west_front_2010": S + "/artifact-files/04719e12-5f92-4afe-ab7d-83afdce65ea1/img/cathedral_west_front_2010_photo.jpg",
          "spire_ann_st_2018": S + "/artifact-files/04719e12-5f92-4afe-ab7d-83afdce65ea1/img/spire_ann_st_2018_photo.jpg",
          "cathedral_ann_st_2012": S + "/artifact-files/04719e12-5f92-4afe-ab7d-83afdce65ea1/img/cathedral_ann_st_2012_photo.jpg"}
for v in ("fly_by_east", "ann_queen_corner", "crane_from_south"):
    photos[v] = S + "/sites/spire_area_showcase/round_14/%s_photo.jpg" % v
def lin(c): c = c / 255; return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4
want = sys.argv[3].split(",") if len(sys.argv) > 3 else None
for v, d in C.items():
    W, H = d["W"], d["H"]
    try:
        r = Image.open("%s/%s_render.png" % (rdir, v)).convert("RGB")
    except Exception as e:
        print(v, "no render", e); continue
    sx, sy = r.width / W, r.height / H
    p = Image.open(photos[v]).convert("RGB").resize(r.size)
    acc = collections.defaultdict(lambda: [0, [0, 0, 0], [0, 0, 0]])
    for px, py, m in d["rows"]:
        x, y = int(px * sx), int(py * sy)
        a = acc[m]; a[0] += 1
        for k, c in enumerate(r.getpixel((x, y))): a[1][k] += lin(c)
        for k, c in enumerate(p.getpixel((x, y))): a[2][k] += lin(c)
    print("==", v)
    for m, (n, rs, ps) in sorted(acc.items(), key=lambda kv: -kv[1][0])[:14]:
        if want and m not in want: continue
        rr = [c / n for c in rs]; pp = [c / n for c in ps]
        tos = lambda l: "#" + "".join("%02x" % round(255 * (1.055 * c ** (1 / 2.4) - 0.055 if c > 0.0031308 else 12.92 * c)) for c in l)
        print("  %-34s n=%5d render %s photo %s ratio %s" % (m, n, tos(rr), tos(pp), " ".join("%.2f" % (pp[k] / max(rr[k], 1e-4)) for k in range(3))))
