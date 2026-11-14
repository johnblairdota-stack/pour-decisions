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


# Window patterns per facade family (step 6): bay = window spacing along the wall, win = window width,
# sill/head = heights within the floor (fractions of LEVEL_HEIGHT), glass = curtain wall (no wall between).
FACADES = {
    "clay_fam_glass":    {"bay": 1.5, "win": 1.38, "sill": 0.30, "head": 0.97, "glass": (0.16, 0.22, 0.28), "rough": 0.12},
    "clay_fam_concrete": {"bay": 3.0, "win": 1.9, "sill": 0.28, "head": 0.80, "glass": (0.12, 0.15, 0.18), "rough": 0.2},
    "clay_fam_brick":    {"bay": 3.4, "win": 1.3, "sill": 0.30, "head": 0.78, "glass": (0.10, 0.12, 0.14), "rough": 0.2},
    "clay_fam_heritage": {"bay": 3.0, "win": 1.0, "sill": 0.22, "head": 0.85, "glass": (0.10, 0.11, 0.12), "rough": 0.25},
}


def facade_material(m, spec=None):
    """Procedural facade from material props (step 7a): base layer by shader type (render, brick in stretcher
    bond, mottled ashlar from a palette, glass), then the window grid from the facade UVs (u = metres round,
    v = metres AHD). Nothing comes from photos; the values are in looks.py."""
    nt = m.node_tree
    nodes, links = nt.nodes, nt.links
    bsdf = nodes.get("Principled BSDF")
    uv = nodes.new("ShaderNodeUVMap")
    uv.uv_map = "facade"
    sep = nodes.new("ShaderNodeSeparateXYZ")
    links.new(uv.outputs["UV"], sep.inputs[0])

    def mnode(op, a, b=None):
        n = nodes.new("ShaderNodeMath")
        n.operation = op
        for k, v in enumerate((a, b)):
            if v is None:
                continue
            if isinstance(v, (int, float)):
                n.inputs[k].default_value = v
            else:
                links.new(v, n.inputs[k])
        return n.outputs[0]

    base = tuple(m.diffuse_color)
    kind = m.get("shader", "render")
    base_out = None
    if kind == "brick":
        br = nodes.new("ShaderNodeTexBrick")
        links.new(uv.outputs["UV"], br.inputs["Vector"])
        br.inputs["Scale"].default_value = 1.0
        br.inputs["Brick Width"].default_value = 0.23
        br.inputs["Row Height"].default_value = 0.076
        br.inputs["Mortar Size"].default_value = 0.008
        br.inputs["Color1"].default_value = base
        br.inputs["Color2"].default_value = tuple(c * 0.82 for c in base[:3]) + (1,)
        br.inputs["Mortar"].default_value = (0.78, 0.74, 0.68, 1)
        br.offset = 0.5
        base_out = br.outputs["Color"]
    elif kind == "ashlar":
        pal = list(m.get("palette", [])) or [c for c in base[:3]] + [c * 0.9 for c in base[:3]] + [min(1, c * 1.08) for c in base[:3]]
        cols = [tuple(pal[i:i + 3]) for i in range(0, len(pal), 3)]
        sc = nodes.new("ShaderNodeMapping")
        links.new(uv.outputs["UV"], sc.inputs["Vector"])
        sc.inputs["Scale"].default_value = (1 / 0.6, 1 / 0.3, 1)
        vo = nodes.new("ShaderNodeTexVoronoi")
        vo.feature = "F1"
        vo.inputs["Randomness"].default_value = 0.0
        links.new(sc.outputs["Vector"], vo.inputs["Vector"])
        ramp = nodes.new("ShaderNodeValToRGB")
        ramp.color_ramp.interpolation = "CONSTANT"
        el = ramp.color_ramp.elements
        while len(el) < len(cols):
            el.new(0.5)
        for i, c in enumerate(cols):
            el[i].position = i / len(cols)
            el[i].color = (*c, 1)
        sepc = nodes.new("ShaderNodeSeparateColor")
        links.new(vo.outputs["Color"], sepc.inputs[0])
        links.new(sepc.outputs[0], ramp.inputs["Fac"])
        br = nodes.new("ShaderNodeTexBrick")                     # mortar joints on the same block size
        links.new(uv.outputs["UV"], br.inputs["Vector"])
        br.inputs["Scale"].default_value = 1.0
        br.inputs["Brick Width"].default_value = 0.6
        br.inputs["Row Height"].default_value = 0.3
        br.inputs["Mortar Size"].default_value = 0.015
        br.inputs["Color1"].default_value = (1, 1, 1, 1)
        br.inputs["Color2"].default_value = (1, 1, 1, 1)
        br.inputs["Mortar"].default_value = (0.82, 0.78, 0.72, 1)
        mixm = nodes.new("ShaderNodeMix")
        mixm.data_type = "RGBA"
        mixm.blend_type = "MULTIPLY"
        mixm.inputs["Factor"].default_value = 1.0
        links.new(ramp.outputs["Color"], mixm.inputs[6])
        links.new(br.outputs["Color"], mixm.inputs[7])
        base_out = mixm.outputs[2]
    else:
        noise = nodes.new("ShaderNodeTexNoise")
        noise.inputs["Scale"].default_value = 0.6
        links.new(uv.outputs["UV"], noise.inputs["Vector"])
        mixn = nodes.new("ShaderNodeMix")
        mixn.data_type = "RGBA"
        mixn.inputs[6].default_value = base
        mixn.inputs[7].default_value = tuple(c * 0.92 for c in base[:3]) + (1,)
        links.new(noise.outputs["Fac"], mixn.inputs["Factor"])
        base_out = mixn.outputs[2]
    out_col = base_out
    rough_out = None
    if spec:
        fu = mnode("FRACT", mnode("DIVIDE", sep.outputs["X"], spec["bay"]))
        fv = mnode("FRACT", mnode("DIVIDE", sep.outputs["Y"], spec.get("floor", L.LEVEL_HEIGHT)))
        half = spec["win"] / spec["bay"] / 2
        inu = mnode("LESS_THAN", mnode("ABSOLUTE", mnode("SUBTRACT", fu, 0.5)), half)
        inv = mnode("MULTIPLY", mnode("GREATER_THAN", fv, spec["sill"]), mnode("LESS_THAN", fv, spec["head"]))
        mask = mnode("MULTIPLY", inu, inv)
        mix = nodes.new("ShaderNodeMix")
        mix.data_type = "RGBA"
        links.new(mask, mix.inputs["Factor"])
        links.new(base_out, mix.inputs[6])
        mix.inputs[7].default_value = (*spec["glass"], 1)
        out_col = mix.outputs[2]
        r = nodes.new("ShaderNodeMapRange")
        links.new(mask, r.inputs["Value"])
        r.inputs["To Min"].default_value = 0.85 if kind != "glass" else 0.3
        r.inputs["To Max"].default_value = spec["rough"]
        rough_out = r.outputs["Result"]
    links.new(out_col, bsdf.inputs["Base Color"])
    if rough_out is not None:
        links.new(rough_out, bsdf.inputs["Roughness"])


def window_material(m, spec):
    facade_material(m, spec)


def setup_morning():
    """Materials + Brisbane morning light (Eevee): physical (Nishita) sky with the sun at ~06:45 AEST on a
    clear autumn day, a sun lamp on the same bearing, light haze, AgX. Window grids on the facades."""
    import math
    sc = bpy.context.scene
    eng = [e.identifier for e in bpy.types.RenderSettings.bl_rna.properties["engine"].enum_items]
    sc.render.engine = "BLENDER_EEVEE_NEXT" if "BLENDER_EEVEE_NEXT" in eng else "BLENDER_EEVEE"
    vts = [v.identifier for v in sc.view_settings.bl_rna.properties["view_transform"].enum_items]
    sc.view_settings.view_transform = "AgX" if "AgX" in vts else "Filmic"
    sc.view_settings.exposure = L.MORNING["exposure"]
    sc.render.image_settings.file_format = "PNG"
    sc.render.image_settings.color_mode = "RGB"
    sc.render.film_transparent = False
    for m in bpy.data.materials:
        if m.get("look_done") or m.name.startswith("Dots") or m.users == 0:
            continue
        m.use_nodes = True
        bsdf = m.node_tree.nodes.get("Principled BSDF")
        if bsdf is None:
            continue
        bsdf.inputs["Base Color"].default_value = m.diffuse_color
        rough = {"clay_water": 0.06, "clay_spire_glass": 0.08, "clay_spire_balustrade": 0.8, "clay_spire_soffit": 0.9, "clay_balustrade": 0.05, "clay_steel": 0.45}.get(m.name, 0.85)
        bsdf.inputs["Roughness"].default_value = rough
        if m.name == "clay_water":                       # Brisbane River: brown-green, sky reflection, small ripples
            bsdf.inputs["Base Color"].default_value = (0.05, 0.055, 0.045, 1)   # step 7j: darker, less mirror-like
            bsdf.inputs["Roughness"].default_value = 0.22
            bsdf.inputs["Specular IOR Level"].default_value = 0.3
            nt = m.node_tree
            tex = nt.nodes.new("ShaderNodeTexNoise")
            tex.inputs["Scale"].default_value = 0.35
            tex.inputs["Detail"].default_value = 6.0
            geo = nt.nodes.new("ShaderNodeNewGeometry")
            nt.links.new(geo.outputs["Position"], tex.inputs["Vector"])
            bump = nt.nodes.new("ShaderNodeBump")
            bump.inputs["Strength"].default_value = 0.25
            nt.links.new(tex.outputs["Fac"], bump.inputs["Height"])
            nt.links.new(bump.outputs["Normal"], bsdf.inputs["Normal"])
        if m.name == "clay_road":                        # step 7d: bitumen with aggregate speckle and patches
            nt = m.node_tree
            geo = nt.nodes.new("ShaderNodeNewGeometry")
            sp = nt.nodes.new("ShaderNodeTexNoise")
            sp.inputs["Scale"].default_value = 40.0
            nt.links.new(geo.outputs["Position"], sp.inputs["Vector"])
            pa = nt.nodes.new("ShaderNodeTexVoronoi")
            pa.inputs["Scale"].default_value = 0.08
            nt.links.new(geo.outputs["Position"], pa.inputs["Vector"])
            ramp = nt.nodes.new("ShaderNodeValToRGB")
            ramp.color_ramp.elements[0].color = (0.030, 0.031, 0.034, 1)
            ramp.color_ramp.elements[1].color = (0.075, 0.075, 0.078, 1)
            mixf = nt.nodes.new("ShaderNodeMath")
            mixf.operation = "MULTIPLY_ADD"
            nt.links.new(sp.outputs["Fac"], mixf.inputs[0])
            mixf.inputs[1].default_value = 0.6
            sepc = nt.nodes.new("ShaderNodeSeparateColor")
            nt.links.new(pa.outputs["Color"], sepc.inputs[0])
            nt.links.new(sepc.outputs[0], mixf.inputs[2])
            nt.links.new(mixf.outputs[0], ramp.inputs["Fac"])
            nt.links.new(ramp.outputs["Color"], bsdf.inputs["Base Color"])
            bsdf.inputs["Roughness"].default_value = 0.9
        if m.get("shader") == "leaf":                    # step 7f: procedural leaf cards, two-tone, translucent
            nt = m.node_tree
            nodes, links = nt.nodes, nt.links
            uv = nodes.new("ShaderNodeUVMap")
            uv.uv_map = "facade"
            vo = nodes.new("ShaderNodeTexVoronoi")              # leaf clusters inside each card
            vo.inputs["Scale"].default_value = 3.2
            links.new(uv.outputs["UV"], vo.inputs["Vector"])
            cen = nodes.new("ShaderNodeMath")                   # fade to the card edge
            sep = nodes.new("ShaderNodeSeparateXYZ")
            links.new(uv.outputs["UV"], sep.inputs[0])
            dx = nodes.new("ShaderNodeVectorMath")
            dx.operation = "DISTANCE"
            links.new(uv.outputs["UV"], dx.inputs[0])
            dx.inputs[1].default_value = (0.5, 0.5, 0)
            ramp_a = nodes.new("ShaderNodeValToRGB")
            ramp_a.color_ramp.interpolation = "CONSTANT"
            ramp_a.color_ramp.elements[0].color = (1, 1, 1, 1)
            ramp_a.color_ramp.elements[1].position = 0.38
            ramp_a.color_ramp.elements[1].color = (0, 0, 0, 1)
            links.new(vo.outputs["Distance"], ramp_a.inputs["Fac"])
            edge = nodes.new("ShaderNodeMath")
            edge.operation = "LESS_THAN"
            links.new(dx.outputs["Value"], edge.inputs[0])
            edge.inputs[1].default_value = 0.5
            cen.operation = "MULTIPLY"
            links.new(ramp_a.outputs["Color"], cen.inputs[0])
            links.new(edge.outputs[0], cen.inputs[1])
            geo = nodes.new("ShaderNodeNewGeometry")
            nz = nodes.new("ShaderNodeTexNoise")                # tone varies across the crown and tree to tree
            nz.inputs["Scale"].default_value = 0.35
            links.new(geo.outputs["Position"], nz.inputs["Vector"])
            mix = nodes.new("ShaderNodeMix")
            mix.data_type = "RGBA"
            links.new(nz.outputs["Fac"], mix.inputs["Factor"])
            mix.inputs[6].default_value = m.diffuse_color
            mix.inputs[7].default_value = (*m.get("leaf2", m.diffuse_color[:3]), 1)
            links.new(mix.outputs[2], bsdf.inputs["Base Color"])
            ao = nodes.new("ShaderNodeAmbientOcclusion")         # darker inside the crown
            ao.inputs["Distance"].default_value = 1.5
            aom = nodes.new("ShaderNodeMix")
            aom.data_type = "RGBA"
            aom.blend_type = "MULTIPLY"
            links.new(ao.outputs["AO"], aom.inputs["Factor"])
            links.new(mix.outputs[2], aom.inputs[6])
            aom.inputs[7].default_value = (0.35, 0.4, 0.3, 1)
            links.new(aom.outputs[2], bsdf.inputs["Base Color"])
            bsdf.inputs["Roughness"].default_value = 0.6
            links.new(cen.outputs[0], bsdf.inputs["Alpha"])
            out = nodes.get("Material Output")
            tr = nodes.new("ShaderNodeBsdfTranslucent")
            links.new(mix.outputs[2], tr.inputs["Color"])
            ms = nodes.new("ShaderNodeMixShader")
            ms.inputs["Fac"].default_value = m.get("translucency", 0.3)
            links.new(bsdf.outputs[0], ms.inputs[1])
            links.new(tr.outputs[0], ms.inputs[2])
            tp = nodes.new("ShaderNodeBsdfTransparent")
            ms2 = nodes.new("ShaderNodeMixShader")
            links.new(cen.outputs[0], ms2.inputs["Fac"])
            links.new(tp.outputs[0], ms2.inputs[1])
            links.new(ms.outputs[0], ms2.inputs[2])
            links.new(ms2.outputs[0], out.inputs["Surface"])
            try:
                m.surface_render_method = "DITHERED"
            except AttributeError:
                m.blend_method = "HASHED"
            m.use_backface_culling = False
        if m.get("shader") == "canopy":                  # step 7j: far crowns, dark varied leaf mass with bumpy clumps
            nt = m.node_tree
            geo = nt.nodes.new("ShaderNodeNewGeometry")
            nz = nt.nodes.new("ShaderNodeTexNoise")
            nz.inputs["Scale"].default_value = 0.6
            nt.links.new(geo.outputs["Position"], nz.inputs["Vector"])
            ramp = nt.nodes.new("ShaderNodeValToRGB")
            c0 = m.diffuse_color
            ramp.color_ramp.elements[0].color = (c0[0] * 0.7, c0[1] * 0.7, c0[2] * 0.7, 1)
            ramp.color_ramp.elements[1].color = (c0[0] * 1.8, c0[1] * 1.7, c0[2] * 1.5, 1)
            nt.links.new(nz.outputs["Fac"], ramp.inputs["Fac"])
            nt.links.new(ramp.outputs["Color"], bsdf.inputs["Base Color"])
            vo = nt.nodes.new("ShaderNodeTexVoronoi")
            vo.inputs["Scale"].default_value = 2.5
            nt.links.new(geo.outputs["Position"], vo.inputs["Vector"])
            bump = nt.nodes.new("ShaderNodeBump")
            bump.inputs["Strength"].default_value = 0.8
            nt.links.new(vo.outputs["Distance"], bump.inputs["Height"])
            nt.links.new(bump.outputs["Normal"], bsdf.inputs["Normal"])
            bsdf.inputs["Roughness"].default_value = 0.9
        if m.name == "clay_grass":                       # lawn: colour patches and mown stripes
            nt = m.node_tree
            geo = nt.nodes.new("ShaderNodeNewGeometry")
            nz = nt.nodes.new("ShaderNodeTexNoise")
            nz.inputs["Scale"].default_value = 0.25
            nt.links.new(geo.outputs["Position"], nz.inputs["Vector"])
            wv = nt.nodes.new("ShaderNodeTexWave")
            wv.inputs["Scale"].default_value = 0.06
            wv.inputs["Distortion"].default_value = 0.0
            nt.links.new(geo.outputs["Position"], wv.inputs["Vector"])
            ramp = nt.nodes.new("ShaderNodeValToRGB")
            ramp.color_ramp.elements[0].color = (0.07, 0.15, 0.035, 1)
            ramp.color_ramp.elements[1].color = (0.17, 0.29, 0.07, 1)
            add = nt.nodes.new("ShaderNodeMath")
            add.operation = "MULTIPLY_ADD"
            nt.links.new(wv.outputs["Fac"], add.inputs[0])
            add.inputs[1].default_value = 0.25
            nt.links.new(nz.outputs["Fac"], add.inputs[2])
            nt.links.new(add.outputs[0], ramp.inputs["Fac"])
            nt.links.new(ramp.outputs["Color"], bsdf.inputs["Base Color"])
            bsdf.inputs["Roughness"].default_value = 0.95
            bump = nt.nodes.new("ShaderNodeBump")
            bump.inputs["Strength"].default_value = 0.15
            nz2 = nt.nodes.new("ShaderNodeTexNoise")
            nz2.inputs["Scale"].default_value = 40.0
            nt.links.new(geo.outputs["Position"], nz2.inputs["Vector"])
            nt.links.new(nz2.outputs["Fac"], bump.inputs["Height"])
            nt.links.new(bump.outputs["Normal"], bsdf.inputs["Normal"])
        if m.get("emit"):                                # lit signal aspects
            bsdf.inputs["Emission Color"].default_value = m.diffuse_color
            bsdf.inputs["Emission Strength"].default_value = m["emit"]
        if m.name == "clay_rock":                        # tuff cliff: grey-brown with vertical banding
            nt = m.node_tree
            geo = nt.nodes.new("ShaderNodeNewGeometry")
            wave = nt.nodes.new("ShaderNodeTexWave")
            wave.wave_type = "BANDS"
            wave.bands_direction = "X"
            wave.inputs["Scale"].default_value = 0.35
            wave.inputs["Distortion"].default_value = 6.0
            nt.links.new(geo.outputs["Position"], wave.inputs["Vector"])
            ramp = nt.nodes.new("ShaderNodeValToRGB")
            ramp.color_ramp.elements[0].color = (0.40, 0.36, 0.32, 1)
            ramp.color_ramp.elements[1].color = (0.62, 0.56, 0.49, 1)
            nt.links.new(wave.outputs["Fac"], ramp.inputs["Fac"])
            nt.links.new(ramp.outputs["Color"], bsdf.inputs["Base Color"])
            bump = nt.nodes.new("ShaderNodeBump")
            bump.inputs["Strength"].default_value = 0.4
            nt.links.new(wave.outputs["Fac"], bump.inputs["Height"])
            nt.links.new(bump.outputs["Normal"], bsdf.inputs["Normal"])
        if m.name == "clay_spire_glass":                 # step 7j: glass reflects the sky (photos), not flat paint
            bsdf.inputs["Base Color"].default_value = (0.022, 0.026, 0.032, 1)
            bsdf.inputs["Metallic"].default_value = 0.6
        if m.name == "clay_balustrade":
            bsdf.inputs["Alpha"].default_value = 0.35
            try:
                m.surface_render_method = "BLENDED"
            except AttributeError:
                m.blend_method = "BLEND"
        if m.name in FACADES:
            window_material(m, FACADES[m.name])
        elif m.get("win_bay"):
            facade_material(m, {k: (tuple(m["win_" + k]) if k == "glass" else m["win_" + k])
                                for k in ("bay", "win", "sill", "head", "glass", "rough", "floor") if "win_" + k in m})
        elif m.get("shader") in ("brick", "ashlar"):
            facade_material(m, None)
        m["look_done"] = True
    mo = L.MORNING
    apply_light(mo["sun_azimuth_deg"], mo["sun_elevation_deg"])
    nt = sc.world.node_tree
    out = nt.nodes.get("World Output")
    vol = nt.nodes.get("HAZE_morning")
    if vol is None and mo["haze_density"] > 0:
        vol = nt.nodes.new("ShaderNodeVolumePrincipled")
        vol.name = "HAZE_morning"
        vol.inputs["Density"].default_value = mo["haze_density"]
        vol.inputs["Color"].default_value = (0.85, 0.88, 0.95, 1)
        nt.links.new(vol.outputs[0], out.inputs["Volume"])
    try:
        sc.eevee.taa_render_samples = 32
        sc.eevee.use_shadows = True
        sc.eevee.volumetric_end = 2500.0
        sc.eevee.volumetric_tile_size = "8"
    except (AttributeError, TypeError):
        pass
    return sc


def apply_light(az_deg, el_deg, kind="day"):
    """Sun lamp + physical sky for a sun position (step 7j: hard shadows, deep blue sky, little haze).
    kind 'dusk': low warm sun, darker sky, more exposure."""
    import math
    sc = bpy.context.scene
    mo = L.MORNING
    dusk = kind == "dusk" or el_deg < 6.0
    sun = bpy.data.objects.get("SUN_morning")
    if sun is None:
        sun = bpy.data.objects.new("SUN_morning", bpy.data.lights.new("SUN_morning", "SUN"))
        sc.collection.objects.link(sun)
    k = max(0.15, min(1.0, math.sin(math.radians(max(el_deg, 1.0))) * 2.2))
    sun.data.energy = mo["sun_strength"] * (0.12 if dusk else k)
    sun.data.color = (1.0, 0.62, 0.38) if dusk else mo["sun_colour"]
    sun.data.angle = math.radians(0.53)
    try:
        sun.data.shadow_maximum_resolution = 0.006
        sc.eevee.shadow_pool_size = "1024"
    except (AttributeError, TypeError):
        pass
    az, el = math.radians(az_deg), math.radians(max(el_deg, 0.5))
    d = Vector((math.sin(az) * math.cos(el), math.cos(az) * math.cos(el), math.sin(el)))   # towards the sun
    sun.rotation_euler = (-d).to_track_quat("-Z", "Y").to_euler()
    if sc.world is None:
        sc.world = bpy.data.worlds.new("World")
    w = sc.world
    w.use_nodes = True
    nt = w.node_tree
    bg = nt.nodes.get("Background")
    sky = nt.nodes.get("SKY_morning")
    if sky is None:
        sky = nt.nodes.new("ShaderNodeTexSky")
        sky.name = "SKY_morning"
        nt.links.new(sky.outputs["Color"], bg.inputs["Color"])
    try:
        sky.sky_type = "NISHITA"
        sky.sun_disc = False
        sky.sun_elevation = math.radians(-1.0) if dusk else el     # dusk: civil twilight, no sun glow on the river
        sky.sun_rotation = math.radians(90.0 - az_deg)   # Blender: 0 = +X (east), CCW
        sky.air_density = 1.0
        sky.dust_density = 1.2 if dusk else mo["haze_dust"]
        sky.ozone_density = 1.5
        sky.altitude = 30.0
    except (AttributeError, TypeError):
        pass
    bg.inputs["Strength"].default_value = mo["sky_strength"] * (6.0 if dusk else 1.0)
    sc.view_settings.exposure = mo["exposure"] + (0.5 if dusk else 0.0)
    try:
        sc.view_settings.look = "AgX - Medium High Contrast"
    except TypeError:
        pass


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
    cut = []
    if c.get("hide_above_ahd") is not None:                   # plan view of one level
        for ob in bpy.data.objects:
            if ob.type == "MESH" and ob.hide_render is False:
                zs = [(ob.matrix_world @ v.co).z for v in ob.data.vertices[:64]]
                if (zs and min(zs) > c["hide_above_ahd"]) or ob.name.startswith("CORE"):
                    ob.hide_render = True          # core hidden too: the slab's hole round it shows
                    cut.append(ob)
    sec = render(p, w, h)
    for ob in cut:
        ob.hide_render = False
    hide(["logistics"], False)
    return sec


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    mode = "mono" if "mono" in argv else ("look" if "look" in argv else "clay")
    every = ["top", "site", "fit", "slabs", "cams", "hero", "morning"]
    what = [a for a in argv if a in every] or every
    os.makedirs(L.DOCS, exist_ok=True)
    times = {}
    passes = [a for a in argv if a in ("finished", "stage", "hsw", "photos")] or ["finished", "stage", "hsw"]
    # ---------------------------------------------------------------- finished tower
    if "finished" in passes:
        finished(what, mode, times)
    if "stage" in passes:
        stage_pass(what, mode, times)
    if "hsw" in passes:
        hsw_pass(what, mode, times)
    if "photos" in passes:
        only = [a[5:] for a in argv if a.startswith("only=")]
        photos_pass(what, mode, times, only[0].split(",") if only else None)
    print("render seconds:", {k: round(v, 1) for k, v in times.items()})


def finished(what, mode, times):
    build_all.build_all(None)
    if "fit" in what:     # finished tower over the 2018 aerial: checks the plate position
        setup("look")
        times["fit"] = top_overlay("site", L.SITE_VIEW["half"], L.aerial_path(2018, "site160m_0p1m"), 2018, alpha=0.5)
    if "slabs" in what:   # storeys + podium hidden: every slab pour A cream / B blue, L6 transfer orange, core
        setup("look")
        hidden = [bpy.data.objects.get(n) for n in ("SPIRE_storeys", "SPIRE_podium_brick", "SPIRE_parapet")]
        for ob in hidden:
            ob.hide_render = True
        hide(["buildings"])
        times["slabs"] = cam_view({"id": "spire_slabs", "pos": (-125.0, 150.0, 110.0), "look_at": (-3.0, 2.0, 70.0),
                                   "lens_mm": 50.0, "portrait": True}, "pours")
        times["slabs_top"] = cam_view({"id": "spire_slab_L07", "pos": (-3.0, 2.0, 90.0), "look_at": (-3.0, 2.01, 0.0),
                                       "lens_mm": 35.0, "portrait": False, "hide_above_ahd": 47.0}, "pours")
        for ob in hidden:
            ob.hide_render = False
        hide(["buildings"], False)
    if "cams" in what:
        setup(mode)
        for c in L.CAMERAS:
            if not c.get("show_logistics"):
                times[c["id"]] = cam_view(c, mode)
    if "hero" in what:    # landmarks from the LiDAR: Story Bridge + HSW, the cathedral
        setup(mode)
        for c in L.HERO_CAMERAS:
            times[c["id"]] = cam_view(c, mode)
    if "morning" in what:  # first pass of materials and morning light
        setup_morning()
        pick = {c["id"]: c for c in L.CAMERAS + L.HERO_CAMERAS}
        for c in (pick["hero_bridge_hsw"], pick["hero_cathedral"], pick["cam_ann_queen_corner"], pick["cam_queen_st"],
                  pick["hero_spire_facade"], pick["hero_cathedral_west_front"], pick["cam_ann_st_precinct"], pick["hero_spire_roof"],
                  pick["street_ann_queen"], pick["street_ann_cathedral"],
                  pick["hero_spire_green_wall"], pick["hero_cathedral_lawn"]):
            times[c["id"] + "_morning"] = cam_view(c, "morning")
        setup(mode)


def photo_cam(c, out_dir, look):
    """Render one solved photo camera (photo_cams.json) at the photo's aspect, long side 1600 px."""
    import json as _j
    cam = camera("cam_photo")
    cam.data.type = "PERSP"
    cam.data.sensor_fit = "AUTO"
    cam.data.sensor_width = c["blender"]["sensor_mm"]
    cam.data.lens = c["blender"]["lens_mm"]
    cam.data.shift_x = 0.0
    cam.data.shift_y = c["blender"]["shift_y"]
    x, y, z = c["pos"]
    street = z - L.ground_z(x, y) < 3.0
    cam.data.clip_start, cam.data.clip_end = (6.0 if street else 0.5), 6000   # street cams: nothing on the lens
    cam.location = (x, y, z)
    h, p = math.radians(c["heading_deg"]), math.radians(c["pitch_deg"])
    d = Vector((math.sin(h) * math.cos(p), math.cos(h) * math.cos(p), math.sin(p)))
    cam.rotation_euler = d.to_track_quat("-Z", "Y").to_euler()
    W, H = c["size"]
    k = 1600 / max(W, H)
    hide(["logistics"], c["stage"] == "as_built")
    dusk = "dusk" in c["id"]
    hour = float(c.get("time_h") or (17.4 if dusk else 12.0))                   # EXIF time when known, else midday
    apply_light(*L.sun_position(c.get("date", ""), hour), "dusk" if dusk else "day")
    # trees stay in: the 6 m near clip on street cams removes any crown right on the lens
    path = os.path.join(out_dir, "%s_render.png" % c["id"])
    sec = render(path, int(round(W * k)), int(round(H * k)))
    hide(["logistics", "trees"], False)
    return sec


def photos_pass(what, mode, times, only=None):
    """Every solved photo camera, in its own build stage (as_built / 2017_top ...)."""
    import json as _j
    cams = [c for c in _j.load(open(os.path.join(L.HERE, "photo_cams.json")))["cams"] if not c.get("skip")]
    if only:
        cams = [c for c in cams if c["id"] in only]
    out_dir = os.path.join(L.DOCS, "photo_cams")
    os.makedirs(out_dir, exist_ok=True)
    stage_of = {"as_built": None}
    for st in sorted({c["stage"] for c in cams}, key=lambda s: s != "as_built"):
        build_all.build_all(stage_of.get(st, st), write_meta=False)
        setup_morning()
        for c in cams:
            if c["stage"] == st:
                times["photo_" + c["id"]] = photo_cam(c, out_dir, True)


def hsw_pass(what, mode, times):
    """Howard Smith Wharves mid-build (late 2017): clay + morning views."""
    build_all.build_all("hsw_2017")
    cams = [{"id": "hsw2017_overview", "pos": (520.0, -170.0, 80.0), "look_at": (600.0, 70.0, 12.0), "lens_mm": 24.0,
             "portrait": False, "show_logistics": True},
            {"id": "hsw2017_dig", "pos": (470.0, -10.0, 45.0), "look_at": (465.0, 100.0, 5.0), "lens_mm": 28.0,
             "portrait": False, "show_logistics": True}]
    setup(mode)
    for c in cams:
        times[c["id"]] = cam_view(c, mode)
    setup_morning()
    for c in cams:
        times[c["id"] + "_morning"] = cam_view(c, "morning")


def stage_pass(what, mode, times):
    # ---------------------------------------------------------------- 2016 site at the L6 transfer slab
    build_all.build_all("2016_l6")
    if "top" in what:
        setup("look")   # overlay always uses the palette so Spire and the markers stand out
        times["top"] = top_overlay("top", L.TOP_VIEW["half"], L.aerial_path(L.TOP_VIEW["aerial_year"]),
                                   L.TOP_VIEW["aerial_year"])
    if "site" in what:
        setup("look")
        times["site"] = top_overlay("site", L.SITE_VIEW["half"],
                                    L.aerial_path(L.SITE_VIEW["aerial_year"], "site160m_0p1m"),
                                    L.SITE_VIEW["aerial_year"], alpha=0.6)
    if "cams" in what:
        setup("look")
        for c in L.STAGE_CAMERAS:
            times[c["id"]] = cam_view(dict(c, show_logistics=True), "2016")


if __name__ == "__main__":
    main()
