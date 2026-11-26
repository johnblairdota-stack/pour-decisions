"""Baseline for the tile work: how long each part of the whole-city build takes and how much memory it holds.

    $CITY_VENV/bin/python tools/city/measure_build.py [out.json]

Builds the full scene once (no render) and prints, per module, seconds, memory after it, and triangles added.
"""
import json
import os
import resource
import sys
import time

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "blender", "spire"))
import bpy  # noqa: E402
import build_all as B  # noqa: E402
import layout as L  # noqa: E402


def rss_gb():
    for line in open("/proc/self/status"):
        if line.startswith("VmRSS"):
            return int(line.split()[1]) / 1048576.0
    return 0.0


def tris():
    n = 0
    for me in bpy.data.meshes:
        me.calc_loop_triangles()
        n += len(me.loop_triangles)
    return n


def main():
    B.clear()
    L.ACTIVE_STAGE = None
    rows, last = [], 0
    t0 = time.time()
    for m in B.MODULES:
        t = time.time()
        r = m.build()
        n = tris()
        rows.append({"module": r.get("module", m.__name__), "seconds": round(time.time() - t, 1),
                     "rss_gb": round(rss_gb(), 2), "tris_added": n - last})
        last = n
        print("%-14s %7.1fs  %5.2f GB  +%d tris" % (rows[-1]["module"], rows[-1]["seconds"], rows[-1]["rss_gb"], rows[-1]["tris_added"]), flush=True)
    out = {"blender": bpy.app.version_string, "total_seconds": round(time.time() - t0, 1), "tris": last,
           "objects": len(bpy.data.objects), "peak_gb": round(resource.getrusage(resource.RUSAGE_SELF).ru_maxrss / 1048576.0, 2),
           "modules": rows}
    print(json.dumps({k: v for k, v in out.items() if k != "modules"}))
    if len(sys.argv) > 1:
        json.dump(out, open(sys.argv[1], "w"), indent=1)


if __name__ == "__main__":
    main()
