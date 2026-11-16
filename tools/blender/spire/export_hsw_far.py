"""Howard Smith Wharves and the Story Bridge as faraway scenery for the game (Spire level, pick-screen flight).

    blender -b --factory-startup -P tools/blender/spire/export_hsw_far.py     (or bpy from pip: see export_game.py)

Writes assets/spire/hsw_far.glb: the HSW render's buildings (hsw.py / hsw_hero.py, as built 2019) and the
Story Bridge (landmarks.py), cheap: no leaf cards (foliage.GAME: 8-face crowns), none of the 1 m terrain, rip-rap,
mangroves or balcony rails, and one object per material. The ground and the river under it are already in
spire_site.glb (export_game.py). Same frame as spire_site.glb: local x east, y north, z AHD; glTF y-up, so the
game places it with the very same transform (spire_site.gd puts it under the site model's node)."""
import os
import sys

import bpy

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import layout as L  # noqa: E402

REPO = os.path.abspath(os.path.join(L.HERE, "..", "..", ".."))
OUT_GLB = os.path.join(REPO, "assets", "spire", "hsw_far.glb")
# render pieces the far model leaves out (faces, and nobody sees them from 300 m+)
DROP = ("hsw_terrain_1m", "hsw_mangroves", "hsw_riprap", "hsw_lidar_rails", "hsw_crest_rails", "hsw_riverwalk_balustrade",
        "hsw_wilson_outlook_fence", "hsw_riverwalk_lamps", "hsw_cliff_scrub", "hsw_cliff_vines", "hsw_felons_east_rail",
        "hsw_umbrella_poles", "hsw_felons_east_poles", "mr_percivals_rail", "hsw_planters", "hsw_hotel_planters",
        "hsw_paths_dg", "hsw_hotel_terrace_planting", "hsw_palms_planting", "cathedral",
        "hsw_riverwalk_piles", "hsw_shed_piles", "hsw_felons_east_piles", "mr_percivals_piles", "hsw_lidar_balconies",
        "hsw_crest_balconies")


def main():
    import foliage
    import build_all
    import hsw
    import landmarks
    foliage.GAME = True
    build_all.clear()
    L.ACTIVE_STAGE = None
    hsw.build()
    landmarks.build()
    for ob in list(bpy.data.objects):
        if ob.type != "MESH" or ob.name.startswith(DROP) or not ob.data.polygons:
            bpy.data.objects.remove(ob)
    # one object per material ("hsw_far_<material>"), transforms applied
    bymat = {}
    for ob in bpy.data.objects:
        ob.data.transform(ob.matrix_world)
        ob.matrix_world = ob.matrix_world.Identity(4)
        mats = [m for m in ob.data.materials if m]
        key = mats[0].name if len(mats) == 1 else ob.name
        bymat.setdefault(key, []).append(ob)
    for key, obs in bymat.items():
        if len(obs) > 1:
            with bpy.context.temp_override(active_object=obs[0], selected_editable_objects=obs, object=obs[0]):
                bpy.ops.object.join()
        obs[0].name = "hsw_far_" + key
    for m in bpy.data.materials:                     # plain principled with the render colour (as export_game.py)
        c = tuple(m.diffuse_color)
        m.use_nodes = True
        b = m.node_tree.nodes.get("Principled BSDF")
        if b:
            b.inputs["Base Color"].default_value = c
            b.inputs["Roughness"].default_value = 0.85
    obs = [o for o in bpy.data.objects if o.type == "MESH"]
    faces = sum(len(o.data.polygons) for o in obs)
    tris = sum(len(p.vertices) - 2 for o in obs for p in o.data.polygons)
    print("export_hsw_far: %d objects, %d faces, %d triangles" % (len(obs), faces, tris))
    for o in sorted(obs, key=lambda o: -len(o.data.polygons))[:15]:
        print("   %-40s %6d" % (o.name, len(o.data.polygons)))
    if os.environ.get("SPIRE_EXPORT_DRY"):
        return
    bpy.ops.export_scene.gltf(filepath=OUT_GLB, export_format="GLB", use_selection=False, export_yup=True,
                              export_apply=True, export_texcoords=False, export_normals=False,
                              export_materials="EXPORT", export_cameras=False, export_lights=False,
                              export_extras=False)
    print("export_hsw_far: %s (%.1f MB)" % (OUT_GLB, os.path.getsize(OUT_GLB) / 1e6))


if __name__ == "__main__":
    main()
