"""Showcase export (step 7g).

    blender -b --factory-startup -P tools/blender/spire/showcase.py -- <commons dir> [render]

1. render: renders every camera in showcase_cams.json (free-licence Wikimedia Commons photos) in the
   photo's build stage at the photo's aspect -> docs/spire/showcase/real/<id>_render.jpg
2. copies each Commons photo, resized to 1600 px long side (q82, otherwise unmodified)
   -> docs/spire/showcase/real/<id>_photo.jpg, and writes credits.json (author, licence, links)
3. exports the best renders listed in BEST to docs/spire/showcase/<name>.jpg (1600 px wide, q88)
John's own collected photos are never used here."""
import json
import math
import os
import sys

import bpy
import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import layout as L  # noqa: E402

OUT = os.path.join(L.DOCS, "showcase")
REAL = os.path.join(OUT, "real")
BEST = ["hero_spire_facade_morning", "street_ann_queen_morning", "hero_spire_green_wall_morning",
        "hero_cathedral_west_front_morning", "hero_cathedral_lawn_morning", "hero_bridge_hsw_morning",
        "hero_spire_roof_morning", "cam_queen_st_morning", "street_ann_cathedral_morning", "stage_flyby_sw_2016"]


def load(path):
    im = bpy.data.images.load(path)
    w, h = im.size
    a = np.empty(w * h * 4, "f4")
    im.pixels.foreach_get(a)
    bpy.data.images.remove(im)
    return a.reshape(h, w, 4)[:, :, :3]


def save_jpg(a, path, q):
    h, w = a.shape[:2]
    im = bpy.data.images.new("o", w, h)
    rgba = np.ones((h, w, 4), "f4")
    rgba[:, :, :3] = a
    im.pixels.foreach_set(rgba.ravel())
    im.filepath_raw = path
    im.file_format = "JPEG"
    sc = bpy.context.scene
    sc.render.image_settings.file_format = "JPEG"
    sc.render.image_settings.quality = q
    im.save_render(path, scene=sc)
    sc.render.image_settings.file_format = "PNG"
    bpy.data.images.remove(im)


def save_plain(a, path, q=82):
    """Photo writer without a view transform: colours stay exactly as in the source photo."""
    h, w = a.shape[:2]
    im = bpy.data.images.new("o", w, h)
    rgba = np.ones((h, w, 4), "f4")
    rgba[:, :, :3] = a
    im.pixels.foreach_set(rgba.ravel())
    im.filepath_raw = path
    im.file_format = "JPEG"
    try:
        im.save(quality=q)
    except TypeError:
        im.save()
    bpy.data.images.remove(im)


def resize(a, long_side=None, width=None):
    H, W = a.shape[:2]
    k = (long_side / max(W, H)) if long_side else (width / W)
    if k >= 1:
        return a
    h, w = int(H * k), int(W * k)
    # box filter: average the source pixels in each target cell
    r = (np.arange(h + 1) * H / h).astype(int)
    c = (np.arange(w + 1) * W / w).astype(int)
    cs = np.pad(a.cumsum(0).cumsum(1), ((1, 0), (1, 0), (0, 0)))
    s = cs[r[1:]][:, c[1:]] - cs[r[:-1]][:, c[1:]] - cs[r[1:]][:, c[:-1]] + cs[r[:-1]][:, c[:-1]]
    area = ((r[1:] - r[:-1])[:, None] * (c[1:] - c[:-1])[None, :])[..., None]
    return s / area


def main():
    argv = sys.argv[sys.argv.index("--") + 1:]
    commons = argv[0]
    os.makedirs(REAL, exist_ok=True)
    cams = [c for c in json.load(open(os.path.join(L.HERE, "showcase_cams.json")))["cams"] if not c.get("skip")]
    lic = json.load(open(os.path.join(commons, "showcase_licences.json"), encoding="utf-8"))
    marks = {p["id"]: p for p in json.load(open(os.path.join(L.HERE, "showcase_marks.json")))["photos"]}
    if "render" in argv:
        import build_all
        import preview as P
        build_all.build_all(None, write_meta=False)
        P.setup_morning()
        for c in cams:
            P.hide(["spire", "core"], c["stage"] == "pre_spire")
            c2 = dict(c, stage="as_built")
            tmp_dir = os.path.join(L.DOCS, "photo_cams")
            P.photo_cam(c2, tmp_dir, True)
            P.hide(["spire", "core"], False)
            src = os.path.join(tmp_dir, "%s_render.png" % c["id"])
            save_jpg(load(src), os.path.join(REAL, "%s_render.jpg" % c["id"]), 88)
            os.remove(src)
    credits = []
    for c in cams:
        m = marks[c["id"]]
        li = lic[m["commons"]]
        a = load(os.path.join(commons, m["src_dir"], m["file"]))
        save_plain(resize(a, long_side=1600), os.path.join(REAL, "%s_photo.jpg" % c["id"]), 82)
        credits.append({"id": c["id"], "title": m["commons"], "author": li["author"], "licence": li["licence"],
                        "licence_url": li["licence_url"], "commons_page": li["page"], "date": m.get("date") or li.get("date"),
                        "fit_rms_px": c["fit_rms_px"], "caption": m["caption"]})
    json.dump({"note": "Real photos: Wikimedia Commons, reused under the licence named; resized only.", "pairs": credits},
              open(os.path.join(REAL, "credits.json"), "w", encoding="utf-8"), indent=1)
    for name in BEST:
        p = os.path.join(L.DOCS, name + ".png")
        if os.path.exists(p):
            save_jpg(resize(load(p), width=1600), os.path.join(OUT, name + ".jpg"), 88)
    print("showcase:", len(credits), "pairs,", len(BEST), "best")


if __name__ == "__main__":
    main()
