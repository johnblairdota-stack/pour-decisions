"""Cloud runner: emulate `blender -b -P script -- args` with pip bpy, rendering with Cycles CPU
(EEVEE needs a GPU; on software GL it takes minutes per sample)."""
import os, sys, runpy
script = sys.argv[1]
sys.argv = [script, "--"] + sys.argv[2:]
SAMPLES = int(os.environ.get("CYC_SAMPLES", "48"))
sys.path.insert(0, os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(script))), "blender", "spire"))
import bpy
import preview as P
_orig = P.render
def cycles_render(path, w, h, transparent=False):
    sc = bpy.context.scene
    ev = getattr(sc.eevee, "use_shadows", None)
    sc.render.engine = "CYCLES"
    c = sc.cycles
    c.device = "CPU"
    c.samples = SAMPLES
    c.use_adaptive_sampling = True
    c.adaptive_threshold = 0.03
    c.use_denoising = True
    try:
        c.denoiser = "OPENIMAGEDENOISE"
    except TypeError:
        pass
    c.max_bounces = 4; c.diffuse_bounces = 2; c.glossy_bounces = 2; c.transmission_bounces = 4
    c.volume_bounces = 0; c.transparent_max_bounces = 8
    c.volume_step_rate = 4.0
    sc.render.threads_mode = "AUTO"
    return _orig(path, w, h, transparent)
P.render = cycles_render
runpy.run_path(script, run_name="__main__")
