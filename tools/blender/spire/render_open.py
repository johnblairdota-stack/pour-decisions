"""The game's high open (assets/open/brisbane_high.jpg): Brisbane from high over Woolloongabba at
first light, the river's bends through the city (looking down steeply enough that the model's edge and the horizon stay out of frame). Cycles CPU (cloud: pip bpy).

    CYC_SAMPLES=48 python tools/blender/spire/render_open.py <out_dir> [el=7] [az=78]

Writes <out_dir>/open_high.png (1920 x 1080); convert to JPEG quality 88 for the game.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy  # noqa: E402,F401

import build_all  # noqa: E402
import preview as P  # noqa: E402
import render_cbd as R  # noqa: E402

CAM = {"id": "open_high", "pos": (-150, -2900, 900), "look_at": (-330, -950, 0), "lens": 24, "size": (1920, 1080)}


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]
    out = os.path.abspath(argv[0])
    os.makedirs(out, exist_ok=True)
    el = float(next((a[3:] for a in argv if a.startswith("el=")), 7.0))
    az = float(next((a[3:] for a in argv if a.startswith("az=")), 78.0))
    build_all.build_all(None, write_meta=False)
    P.setup_morning()
    P.apply_light(az, el)          # (first light: the sun just up in the east, long shadows across the city)
    R.setup_cycles(int(os.environ.get("CYC_SAMPLES", "48")))
    R.shoot(CAM, out, 1.0)


if __name__ == "__main__":
    main()
