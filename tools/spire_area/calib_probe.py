import sys, os, json, math, collections
sys.path.insert(0, "tools/blender/spire")
import bpy
from mathutils import Vector
import layout as L, build_all, preview as P
build_all.build_all(None, write_meta=False)
sys.argv = ["x", "--", "/tmp"]
src = open("tools/spire_area/render_area.py").read().replace("\nmain()\n", "\n")
ns = {"__name__": "ra", "__file__": os.path.abspath("tools/spire_area/render_area.py")}
exec(compile(src, "ra", "exec"), ns)
A = json.load(open("tools/spire_area/area_cams.json"))
heroes = {h["id"]: h for h in A["heroes"]}
pc = {c["id"]: c for c in json.load(open("tools/blender/spire/photo_cams.json"))["cams"]}
cc = {c["id"]: c for c in json.load(open("tools/blender/spire/showcase_cams.json"))["cams"]}
lay = {c["id"]: c for c in L.CAMERAS + L.HERO_CAMERAS}
cam = P.camera("cam_probe")
sc = bpy.context.scene
dg = bpy.context.evaluated_depsgraph_get()
def setcam(v):
    if v in heroes:
        W, H = ns["place_agl"](cam, heroes[v])
    elif v in lay:
        W, H = ns["place_agl"](cam, lay[v])
    else:
        c = pc.get(v) or cc[v]
        W, H, _ = ns["photo_cam"](cam, c)
    sc.render.resolution_x, sc.render.resolution_y = W, H
    bpy.context.view_layer.update()
    return W, H
out = {}
def matmap(v, step=8):
    W, H = setcam(v)
    fr = [cam.matrix_world @ q for q in cam.data.view_frame(scene=sc)]
    o = cam.matrix_world.translation
    dg = bpy.context.evaluated_depsgraph_get()
    rows = []
    for py in range(step // 2, H, step):
        for px in range(step // 2, W, step):
            u, w_ = px / W, py / H
            p = fr[3].lerp(fr[0], u).lerp(fr[2].lerp(fr[1], u), w_)
            d = (p - o).normalized()
            hit, loc, n, idx, ob, mtx = sc.ray_cast(dg, o, d)
            if not hit:
                rows.append((px, py, "sky")); continue
            try: mi = ob.material_slots[ob.data.polygons[idx].material_index].name
            except Exception: mi = "?"
            rows.append((px, py, mi))
    out[v] = {"W": W, "H": H, "rows": rows}
for v in ("cathedral_west_front_2010", "fly_by_east", "spire_ann_st_2018", "ann_queen_corner", "crane_from_south", "cathedral_ann_st_2012"):
    matmap(v)
json.dump(out, open(sys.argv[-1] if sys.argv[-1].endswith(".json") else "/tmp/x.json", "w"))
# what hides the flag in crane_from_south
W, H = setcam("crane_from_south")
ob = bpy.data.objects["area_mantra_blue_fin"]
o = cam.matrix_world.translation
dg = bpy.context.evaluated_depsgraph_get()
from bpy_extras.object_utils import world_to_camera_view
cnt = collections.Counter(); inview = 0
for vtx in ob.data.vertices:
    wp = ob.matrix_world @ vtx.co
    if wp.z < 100: continue
    c = world_to_camera_view(sc, cam, wp)
    if not (0 <= c.x <= 1 and 0 <= c.y <= 1 and c.z > 0): continue
    inview += 1
    d = (wp - o); L_ = d.length; d.normalize()
    hit, loc, n, idx, hob, mtx = sc.ray_cast(dg, o, d, distance=L_ - 0.3)
    cnt[hob.name if hit else "VISIBLE"] += 1
    if inview < 4: print("FLAGPX", round(c.x * W), round((1 - c.y) * H))
print("FLAG crane_from_south in view", inview, cnt.most_common(8))
m = bpy.data.materials.get("area_mantra_blue")
print("FLAGMAT", dict(m.items()), [n.bl_idname for n in m.node_tree.nodes])
for l in m.node_tree.links:
    print("  L", l.from_node.name, l.from_socket.name, "->", l.to_node.name, l.to_socket.name)
b = m.node_tree.nodes.get("Principled BSDF")
for k in ("Alpha", "Transmission Weight", "Emission Strength", "Roughness", "Specular IOR Level"):
    if k in b.inputs: print("  ", k, b.inputs[k].default_value if not b.inputs[k].is_linked else "linked")
