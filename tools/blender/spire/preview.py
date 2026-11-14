"""Clay / look previews of the Spire blockout (Workbench, each well under 30 s).

    blender -b --factory-startup -P tools/blender/spire/preview.py -- [clay|mono|look] [top site cams]

clay = grey palette with Spire warm and the logistics markers coloured; mono = one grey;
look = same palette for now (textures come in a later step).

Writes PNGs (max 1600 px) to docs/spire/:
    top_clay_over_2016.png    whole 800 m square, clay laid over the 2016 aerial
    site_clay_over_2016.png   160 m round the site, same idea (shows crane/hoist/gate markers)
    cam_<id>_<mode>.png       one per camera spot in layout.CAMERAS
"""
import math
import os
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy  # noqa: E402
import numpy as np  # noqa: E402
from mathutils import Vector  # noqa: E402

import layout as L  # noqa: E402
import build_all  # noqa: E402

MAX_PX = 1600


def setup(mode):
    sc = bpy.context.scene
    sc.render.engine = "BLENDER_WORKBENCH"
    sh = sc.display.shading
    sh.light = "STUDIO"
    sh.color_type = "SINGLE" if mode == "mono" else "MATERIAL"   # clay = the grey palette in common.py
    sh.single_color = (0.78, 0.78, 0.76)
    sh.show_shadows = True
    sh.shadow_intensity = 0.35
    sh.show_cavity = True
    sh.cavity_type = "WORLD"
    sh.show_object_outline = True
    sh.object_outline_color = (0.15, 0.15, 0.15)
    sc.display.light_direction = (0.35, -0.45, 0.82)
    sc.display.render_aa = "8"
    sc.render.image_settings.file_format = "PNG"
    sc.render.image_settings.color_mode = "RGBA"
    sc.view_settings.view_transform = "Standard"
    if sc.world is None:
        sc.world = bpy.data.worlds.new("World")
    sc.world.color = (0.80, 0.84, 0.88)
    return sc


def camera(name):
    cam = bpy.data.objects.get(name)
    if cam is None:
        cam = bpy.data.objects.new(name, bpy.data.cameras.new(name))
        bpy.context.scene.collection.objects.link(cam)
    bpy.context.scene.camera = cam
    return cam


def render(path, w, h, transparent=False):
    sc = bpy.context.scene
    sc.render.resolution_x, sc.render.resolution_y = w, h
    sc.render.resolution_percentage = 100
    sc.render.film_transparent = transparent
    sc.render.filepath = path
    t = time.time()
    bpy.ops.render.render(write_still=True)
    print("render %-40s %dx%d %.1fs" % (os.path.basename(path), w, h, time.time() - t))
    return time.time() - t


def load_rgba(path):
    im = bpy.data.images.load(path)
    w, h = im.size
    a = np.empty(w * h * 4, "f4")
    im.pixels.foreach_get(a)
    bpy.data.images.remove(im)
    return a.reshape(h, w, 4)


def save_rgb(arr, path):
    h, w = arr.shape[:2]
    im = bpy.data.images.new("out", w, h, alpha=False)
    rgba = np.ones((h, w, 4), "f4")
    rgba[:, :, :3] = arr[:, :, :3]
    im.pixels.foreach_set(rgba.ravel())
    im.filepath_raw = path
    im.file_format = "PNG"
    im.save()
    bpy.data.images.remove(im)


def hide(collections, hidden=True):
    for name in collections:
        col = bpy.data.collections.get(name)
        if col:
            col.hide_render = hidden


def top_overlay(name, half, aerial, year, alpha=0.55):
    """Ortho top-down clay (no ground) laid over the local-frame aerial of the same square."""
    cam = camera("cam_top")
    cam.data.type = "ORTHO"
    cam.data.ortho_scale = 2 * half
    cam.data.clip_end = 2000
    cam.location = (0, 0, 900)
    cam.rotation_euler = (0, 0, 0)
    hide(["ground"])
    tmp = os.path.join(L.DOCS, "_tmp_%s.png" % name)
    sec = render(tmp, MAX_PX, MAX_PX, transparent=True)
    hide(["ground"], False)
    clay = load_rgba(tmp)
    os.remove(tmp)
    air = load_rgba(aerial)                       # aerial is exactly the same square (see prep_data.py)
    if air.shape[:2] != clay.shape[:2]:
        raise RuntimeError("aerial %s is %s, render is %s" % (aerial, air.shape, clay.shape))
    rgb = clay[:, :, :3]
    sat = rgb.max(2, keepdims=True) - rgb.min(2, keepdims=True)
    a = clay[:, :, 3:4] * np.where(sat > 0.12, 0.85, alpha)   # Spire + logistics markers nearly solid
    out = air[:, :, :3] * (1 - a) + rgb * a
    p = os.path.join(L.DOCS, "%s_clay_over_%d.png" % (name, year))
    save_rgb(out, p)
    print("wrote", p)
    return sec


def cam_view(c, mode):
    cam = camera("cam_photo")
    cam.data.type = "PERSP"
    cam.data.lens = c["lens_mm"]
    cam.data.sensor_width = 36.0
    cam.data.sensor_fit = "AUTO"
    cam.data.shift_y = c.get("shift_y", 0.0)
    cam.data.clip_start, cam.data.clip_end = 0.5, 3000
    pos = Vector(c["pos"])
    pos.z += L.ground_z(c["pos"][0], c["pos"][1])   # pos z is eye height above ground
    cam.location = pos
    look = Vector(c["look_at"])
    look.z += L.ground_z(look.x, look.y)             # look_at z is also height above ground
    d = look - pos
    if c.get("shift_y"):
        d.z = 0.0          # shift lens: camera level, frame moved up, verticals stay straight
    cam.rotation_euler = d.to_track_quat("-Z", "Y").to_euler()
    w, h = (1067, 1600) if c.get("portrait") else (1600, 1067)
    p = os.path.join(L.DOCS, "%s_%s.png" % (c["id"], mode))
    hide(["logistics"], not c.get("show_logistics", False))   # photo taken after completion: no crane
    sec = render(p, w, h)
    hide(["logistics"], False)
    return sec


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    mode = "mono" if "mono" in argv else ("look" if "look" in argv else "clay")
    what = [a for a in argv if a in ("top", "site", "fit", "slabs", "cams")] or ["top", "site", "fit", "slabs", "cams"]
    os.makedirs(L.DOCS, exist_ok=True)
    build_all.build_all()
    setup(mode)
    times = {}
    if "top" in what:
        setup("look")   # overlay always uses the palette so Spire and the markers stand out
        times["top"] = top_overlay("top", L.TOP_VIEW["half"], L.aerial_path(L.TOP_VIEW["aerial_year"]),
                                   L.TOP_VIEW["aerial_year"])
    if "site" in what:
        setup("look")
        times["site"] = top_overlay("site", L.SITE_VIEW["half"],
                                    L.aerial_path(L.SITE_VIEW["aerial_year"], "site160m_0p1m"),
                                    L.SITE_VIEW["aerial_year"], alpha=0.6)
    if "fit" in what:     # finished tower over the 2018 aerial: checks the plate position
        setup("look")
        hide(["logistics"])
        times["fit"] = top_overlay("site", L.SITE_VIEW["half"], L.aerial_path(2018, "site160m_0p1m"), 2018, alpha=0.5)
        hide(["logistics"], False)
    if "slabs" in what:   # storeys hidden: every slab, pour A cream / pour B blue, L6 transfer orange
        setup("look")
        st = bpy.data.objects.get("SPIRE_storeys")
        st.hide_render = True
        hide(["logistics", "buildings"])
        times["slabs"] = cam_view({"id": "spire_slabs", "pos": (-125.0, 150.0, 110.0), "look_at": (-3.0, 2.0, 70.0),
                                   "lens_mm": 50.0, "portrait": True}, "pours")
        st.hide_render = False
        hide(["logistics", "buildings"], False)
    if "cams" in what:
        setup(mode)
        for c in L.CAMERAS:
            times[c["id"]] = cam_view(c, mode)
    print("render seconds:", {k: round(v, 1) for k, v in times.items()})


if __name__ == "__main__":
    main()
