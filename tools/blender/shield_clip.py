"""Mede, com o rig real, quanto cada escudo entra no corpo e na cabeça (idle e bloqueio): blender -b --factory-startup --python tools/blender/shield_clip.py"""
import sys
import bpy
from mathutils.bvhtree import BVHTree
R = __file__.replace("\\", "/").rsplit("tools/", 1)[0]
sys.path.append(R + "tools/blender")
import chibi_kit as ck
import shield_kit

base = ck.build_kit("male")
rig = base["rig"]
sc = bpy.context.scene
rig.animation_data_create()
# as ações valem pela trilha NLA, que é o que vai no GLB: o nome pode ter virado "block.001"
act = {t.name: t.strips[0].action for t in rig.animation_data.nla_tracks if t.strips}
for t in rig.animation_data.nla_tracks:
    t.mute = True
print("ACOES", {n: act[n].name for n in ("idle", "block_shield")})


def tree(obj, dg):
    e = obj.evaluated_get(dg)
    me = e.to_mesh()
    vs = [e.matrix_world @ v.co for v in me.vertices]
    fs = [tuple(p.vertices) for p in me.polygons]
    t = BVHTree.FromPolygons(vs, fs)
    return t, vs


names = {"tronco": ("base_body", "base_torso"), "cabeca": ("base_head",)}
body = [o for o in sc.objects if o.type == "MESH" and "hair" not in o.name and "eye" not in o.name and not o.name.startswith("arm_cape")
        and (o.name in ("base_body", "base_head") or o.name.startswith(("arm_plate_body", "arm_plate_head", "arm_pal1_body", "arm_pal1_head")))]
print("CORPO", [o.name for o in body][:12])
for anim, frames in (("idle", (1, 25)), ("block_shield", (1, 9, 17))):
    rig.animation_data_create()
    rig.animation_data.action = act[anim]
    for fr in frames:
        sc.frame_set(fr)
        dg = bpy.context.evaluated_depsgraph_get()
        parts = [tree(o, dg) for o in body]
        counts = {}
        for st in shield_kit.FAMILIES:
            t, _ = tree(bpy.data.objects.get("wpn_off_shield_" + st), dg)
            counts[st] = sum(len(t.overlap(p[0])) for p in parts)
        cuff = min(counts.values())         # a braçadeira abraça o braço de propósito: é a linha de base
        for st in shield_kit.FAMILIES:
            sh = bpy.data.objects.get("wpn_off_shield_" + st)
            t, vs = tree(sh, dg)
            hits = counts[st] - cuff
            near = 9.0
            for p in parts:
                for v in vs[::2]:
                    r = p[0].find_nearest(v)
                    if r[0] is not None and r[3] < near:
                        near = r[3]
            print("CLIP %-6s f%-2d %-10s toques=%-4d dist=%.3f" % (anim, fr, st, hits, near))
print("CLIP_FIM")
