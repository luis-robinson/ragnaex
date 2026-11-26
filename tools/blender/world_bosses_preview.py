"""Prévia sem janela dos Chefes de Mundo (world_bosses.py), em quadro deitado (bicho de quatro patas):
folha frente / lado / costas / de cima, folha da câmera do jogo (52°) em 4 giros, folha de poses e conta de chão.
  blender -b --factory-startup --python tools/blender/world_bosses_preview.py -- --out=<pasta ABSOLUTA> [--only=mob_a,mob_b]
      [--poses=idle:1,atk_charge:5,slam:6,slam:8] [--strip=<clipe>] [--ground] [--export=<pasta ABSOLUTA dos GLB>]
--ground imprime `GROUND <modelo> <clipe> <z mínimo> <z mínimo das patas no pior quadro>`; --strip filma um clipe inteiro
(um quadro sim, um não) de lado e na câmera do jogo.
"""
import math
import os
import sys

import bpy
from mathutils import Vector

sys.path.append(os.path.dirname(os.path.abspath(__file__)))
import chibi_kit as ck
import mob_kit as mk
import world_bosses as wb

W, H = 560, 440


def arg(name, default=""):
    for a in sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []:
        if a == name:
            return "1"
        if a.startswith(name + "="):
            return a.split("=", 1)[1]
    return default


def shot(path, eye, target, ortho, res=(W, H)):
    sc = bpy.context.scene
    cam = bpy.data.objects.get("wb_cam")
    if cam is None:
        cam = bpy.data.objects.new("wb_cam", bpy.data.cameras.new("wb_cam"))
        sc.collection.objects.link(cam)
    cam.data.type = "ORTHO"
    cam.data.ortho_scale = ortho
    cam.data.clip_end = 200
    cam.location = Vector(eye)
    cam.rotation_euler = (Vector(target) - Vector(eye)).to_track_quat("-Z", "Y").to_euler()
    sc.camera = cam
    sc.render.resolution_x, sc.render.resolution_y = res
    sc.render.filepath = path
    bpy.ops.render.render(write_still=True)


def stitch(paths, out, cols=0):
    import numpy as np
    tiles = []
    for p in paths:
        img = bpy.data.images.load(p)
        tiles.append(np.array(img.pixels[:], dtype=np.float32).reshape(img.size[1], img.size[0], 4))
        bpy.data.images.remove(img)
    cols = cols or len(tiles)
    while len(tiles) % cols:
        tiles.append(np.zeros_like(tiles[0]))
    rows = [np.concatenate(tiles[i:i + cols], axis=1) for i in range(0, len(tiles), cols)]
    a = np.concatenate(rows[::-1], axis=0)
    res = bpy.data.images.new("wb_sheet", a.shape[1], a.shape[0], alpha=True)
    res.pixels = a.ravel().tolist()
    res.filepath_raw = out
    res.file_format = "PNG"
    res.save()
    bpy.data.images.remove(res)
    for p in paths:
        os.remove(p)


def game_eye(target, yaw, dist=14.0):
    a = math.radians(52)
    return (target[0] + math.sin(yaw) * dist * math.cos(a), target[1] - math.cos(yaw) * dist * math.cos(a), target[2] + dist * math.sin(a))


def meshes(rig):
    return [o for o in rig.children if o.type == "MESH"]


def lows(rig):
    """(z mínimo de tudo, peça, z mínimo de cada perna)"""
    worst, who, legs = 1e9, "", {}
    for o in meshes(rig):
        mw = o.matrix_world
        z = min((mw @ v.co).z for v in o.data.vertices)
        if o.parent_bone.startswith("leg_"):
            legs[o.parent_bone] = z
        if z < worst:
            worst, who = z, o.name
    return worst, who, legs


def bounds(rig):
    lo, hi = Vector((1e9, 1e9, 1e9)), Vector((-1e9, -1e9, -1e9))
    for o in meshes(rig):
        for v in o.data.vertices:
            p = o.matrix_world @ v.co
            for i in range(3):
                lo[i] = min(lo[i], p[i])
                hi[i] = max(hi[i], p[i])
    return lo, hi


def play(rig, clip, frame):
    ad = rig.animation_data
    for t in ad.nla_tracks:
        t.mute = True
    if clip is None:
        bpy.context.scene.frame_set(1)
        ad.action = None
        for pb in rig.pose.bones:
            pb.rotation_euler = (0, 0, 0)
            pb.location = (0, 0, 0)
    else:
        act = ck._tracks(rig)[clip].strips[0].action
        ad.action = act
        if getattr(ad, "action_slot", None) is None and getattr(act, "slots", None):
            ad.action_slot = act.slots[0]
        bpy.context.scene.frame_set(frame)
    bpy.context.view_layer.update()


def main():
    out = arg("--out")
    only = [s for s in arg("--only").split(",") if s] or list(wb.BUILDERS)
    poses = [p.split(":") for p in arg("--poses", "idle:1,run:5,attack:3,attack:5,atk_charge:3,atk_charge:5,slam:6,slam:8,roar:7,maul:5,maul:7,pounce:7,brace:6,die:34").split(",") if p]
    sc = bpy.context.scene
    sc.render.engine = "BLENDER_WORKBENCH"
    sc.render.film_transparent = False
    sh = sc.display.shading
    sh.light = "STUDIO"
    sh.color_type = "MATERIAL"
    sh.show_object_outline = True
    sh.show_cavity = True
    sh.show_shadows = True
    sh.shadow_intensity = 0.35
    sc.world = sc.world or bpy.data.worlds.new("w")
    sc.world.color = (0.36, 0.4, 0.36)
    os.makedirs(out, exist_ok=True)
    for name in only:
        ck.clear()
        rig = wb.BUILDERS[name]()
        for o in bpy.context.scene.objects:
            if "." in o.name:
                o.name = o.name.replace(".", "_")
        if arg("--export"):
            mk.lp.export_glb(os.path.join(arg("--export"), name + ".glb"), [rig])
        rig.hide_render = True
        tris = sum(len(p.vertices) - 2 for o in meshes(rig) for p in o.data.polygons)
        mats = {m.name for o in meshes(rig) for m in o.data.materials}
        print("MODEL", name, len(meshes(rig)), "malhas", tris, "tris", len(mats), "materiais", "clipes:", " ".join(sorted(ck._tracks(rig))))
        if bpy.data.objects.get("wb_floor") is None:
            ck.box("wb_floor", (14, 14, 0.02), (0, 0, -0.011), ck.mat("m_wb_floor", (0.55, 0.62, 0.42), 1.0))
        play(rig, None, 1)
        lo, hi = bounds(rig)
        print("BOUNDS", name, [round(x, 2) for x in lo], [round(x, 2) for x in hi])
        span = max(hi.y - lo.y, hi.x - lo.x, hi.z) * 1.25
        mid = (0, (lo.y + hi.y) * 0.5, hi.z * 0.45)
        tmp = [os.path.join(out, "_%s_%d.png" % (name, i)) for i in range(4)]
        shot(tmp[0], (0.6, -14, hi.z * 0.6), mid, span)
        shot(tmp[1], (-14, mid[1] - 0.4, hi.z * 0.6), mid, span)
        shot(tmp[2], (-0.6, 14, hi.z * 0.6), mid, span)
        shot(tmp[3], (0, mid[1], 20), (0, mid[1] - 0.001, 0), span)
        stitch(tmp, os.path.join(out, "%s_views.png" % name), 2)
        tmp = [os.path.join(out, "_%s_g%d.png" % (name, i)) for i in range(4)]
        for i, yaw in enumerate((0.6, 2.2, math.pi + 0.5, -1.4)):
            shot(tmp[i], game_eye(mid, yaw), mid, span * 1.05)
        stitch(tmp, os.path.join(out, "%s_game.png" % name), 2)
        hc = (0.0, lo.y + 0.38, hi.z * 0.55)
        tmp = [os.path.join(out, "_%s_h%d.png" % (name, i)) for i in range(2)]
        shot(tmp[0], (-6, lo.y - 9, hi.z * 0.9), hc, span * 0.5)
        shot(tmp[1], (5, lo.y - 7, hi.z + 6), hc, span * 0.5)
        stitch(tmp, os.path.join(out, "%s_head.png" % name))
        if poses:
            tp = []
            for i, (clip, fr) in enumerate(poses):
                if clip not in ck._tracks(rig):
                    continue
                play(rig, clip, int(fr))
                p = os.path.join(out, "_%s_p%d.png" % (name, i))
                shot(p, game_eye(mid, 0.9), mid, span * 1.12, (400, 320))
                tp.append(p)
                p = os.path.join(out, "_%s_q%d.png" % (name, i))
                shot(p, (-14, mid[1] - 0.2, 0.6), (0, mid[1] - 0.2, hi.z * 0.6), span * 1.12, (400, 320))
                tp.append(p)
            stitch(tp, os.path.join(out, "%s_poses.png" % name), 6)
        for clip in [c for c in arg("--strip").split(",") if c]:
            end = int(round(ck._tracks(rig)[clip].strips[0].action.frame_range[1]))
            frames = list(range(1, end + 1, 2 if end > 14 else 1))
            tp = []
            for view in (0, 1):
                for f in frames:
                    play(rig, clip, f)
                    p = os.path.join(out, "_%s_s%d_%d.png" % (name, view, f))
                    if view == 0:
                        shot(p, (-14, mid[1] - 0.3, 0.6), (0, mid[1] - 0.3, hi.z * 0.6), span * 1.45, (300, 260))
                    else:
                        shot(p, game_eye(mid, 0.9), mid, span * 1.45, (300, 260))
                    tp.append(p)
            stitch(tp, os.path.join(out, "%s_strip_%s.png" % (name, clip)), len(frames))
            print("STRIP", clip, "quadros", frames)
        if arg("--ground"):
            for clip in sorted(ck._tracks(rig)):
                act = ck._tracks(rig)[clip].strips[0].action
                worst, wf, who, air = 1e9, 0, "", 0.0
                for f in range(1, int(round(act.frame_range[1])) + 1):
                    play(rig, clip, f)
                    z, w_, legs = lows(rig)
                    air = max(air, min(legs.values()))
                    if z < worst:
                        worst, wf, who = z, f, w_
                print("GROUND %s %-11s min %.3f (quadro %d, %s)  maior vão sob as 4 patas %.3f%s" % (name, clip, worst, wf, who, air, "  <<<" if worst < -0.005 and clip != "die" else ""))
        play(rig, None, 1)
    print("preview done")


main()
