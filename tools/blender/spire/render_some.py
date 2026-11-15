"""Render only the named hero/street cams in the morning look (faster than the full preview pass).

    blender -b --factory-startup -P tools/blender/spire/render_some.py -- street_ann_queen hero_spire_green_wall
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import layout as L  # noqa: E402
import build_all  # noqa: E402
import preview as P  # noqa: E402

names = sys.argv[sys.argv.index("--") + 1:]
pick = {c["id"]: c for c in L.CAMERAS + L.HERO_CAMERAS}
build_all.build_all(None, write_meta=False)
P.setup_morning()
for n in names:
    print("render", n, round(P.cam_view(pick[n], "morning"), 1), "s")
