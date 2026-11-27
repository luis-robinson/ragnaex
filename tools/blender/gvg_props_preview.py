"""Prévia sem janela dos objetos de cerco da Guerra de Guildas (gvg_props.py): folha frente / lado / costas / de cima,
folha da câmera do jogo (52°) em 4 giros, um filme por clipe (de lado em cima, câmera do jogo embaixo) e conta de chão.
  blender -b --factory-startup --python tools/blender/gvg_props_preview.py -- --out=<pasta ABSOLUTA> [--only=mob_siege_ram,prop_gvg_banner]
      [--export=<pasta ABSOLUTA dos GLB>] [--ground] [--no_strips] [--tint=r,g,b] [--tint2=r,g,b]
--ground imprime `GROUND <modelo> <clipe> min <z> (quadro, peça)`; `<<<` = passou do chão. As fotos pintam `tint`/`tint2`
(o GLB sai antes, com a cor crua).
"""
import math
import os
import sys

import bpy
from mathutils import Vector

sys.path.append(os.path.dirname(os.path.abspath(__file__)))
import chibi_kit as ck
import lowpoly_lib as lp
import prop_kit
import gvg_props as gv

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
    cam = bpy.data.objects.get("gv_cam")
    if cam is None:
        cam = bpy.data.objects.new("gv_cam", bpy.data.cameras.new("gv_cam"))
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
    res = bpy.data.images.new("gv_sheet", a.shape[1], a.shape[0], alpha=True)
    res.pixels = a.ravel().tolist()
    res.filepath_raw = out
    res.file_format = "PNG"
    res.save()
    bpy.data.images.remove(res)
    for p in paths:
        os.remove(p)


def game_eye(target, yaw, dist=20.0):
    a = math.radians(52)
    return (target[0] + math.sin(yaw) * dist * math.cos(a), target[1] - math.cos(yaw) * dist * math.cos(a), target[2] + dist * math.sin(a))


def lows(objs):
    worst, who = 1e9, ""
    for o in objs:
        mw = o.matrix_world
        z = min((mw @ v.co).z for v in o.data.vertices)
        if z < worst:
            worst, who = z, o.name
    return worst, who


def bounds(objs):
    lo, hi = Vector((1e9, 1e9, 1e9)), Vector((-1e9, -1e9, -1e9))
    for o in objs:
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
            pb.scale = (1, 1, 1)
    else:
        act = ck._tracks(rig)[clip].strips[0].action
        ad.action = act
        if getattr(ad, "action_slot", None) is None and getattr(act, "slots", None):
            ad.action_slot = act.slots[0]
        bpy.context.scene.frame_set(frame)
    bpy.context.view_layer.update()


def paint(name, rgb):
    m = bpy.data.materials.get(name)
    if m is None:
        return
    bsdf = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    bsdf.inputs["Base Color"].default_value = (*rgb, 1.0)
    m.diffuse_color = (*rgb, 1.0)


def main():
    out = arg("--out")
    names = list(gv.BUILDERS) + ["prop_" + k for k in gv.PROP_BUILDERS]
    only = [s for s in arg("--only").split(",") if s] or names
    tint = tuple(float(x) for x in arg("--tint", "0.28,0.46,0.86").split(","))
    tint2 = tuple(float(x) for x in arg("--tint2", "0.98,0.82,0.36").split(","))
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
        rig = None
        if name.startswith("prop_"):
            kind = name[5:]
            prop_kit.build(kind)
            if arg("--export"):
                prop_kit.export_scene(os.path.join(arg("--export"), name + ".glb"), name, kind)
            objs = [o for o in bpy.context.scene.objects if o.type == "MESH"]
        else:
            ck.clear()
            rig = gv.BUILDERS[name]()
            for o in bpy.context.scene.objects:
                if "." in o.name:
                    o.name = o.name.replace(".", "_")
            if arg("--export"):
                lp.export_glb(os.path.join(arg("--export"), name + ".glb"), [rig])
            rig.hide_render = True
            objs = [o for o in rig.children if o.type == "MESH"]
        paint("tint", tint)
        paint("tint2", tint2)
        tris = sum(len(p.vertices) - 2 for o in objs for p in o.data.polygons)
        mats = sorted({m.name for o in objs for m in o.data.materials})
        clips = sorted(ck._tracks(rig)) if rig else []
        print("MODEL", name, len(objs), "malhas", tris, "tris", len(mats), "materiais:", " ".join(mats), "| clipes:", " ".join(
            "%s(%d)" % (c, round(ck._tracks(rig)[c].strips[0].action.frame_range[1])) for c in clips))
        if rig:
            print("BONES", name, " ".join(b.name for b in rig.data.bones))
        ck.box("gv_floor", (16, 16, 0.02), (0, 0, -0.011), ck.mat("m_gv_floor", (0.55, 0.62, 0.42), 1.0))
        if rig:
            play(rig, "idle", 1)
        lo, hi = bounds(objs)
        print("BOUNDS", name, [round(x, 2) for x in lo], [round(x, 2) for x in hi])
        span = max(hi.y - lo.y, hi.x - lo.x, hi.z) * 1.3
        mid = ((lo.x + hi.x) * 0.5, (lo.y + hi.y) * 0.5, hi.z * 0.45)
        tmp = [os.path.join(out, "_%s_%d.png" % (name, i)) for i in range(4)]
        shot(tmp[0], (mid[0] + 0.8, -20, hi.z * 0.6), mid, span)
        shot(tmp[1], (-20, mid[1] - 0.5, hi.z * 0.6), mid, span)
        shot(tmp[2], (mid[0] - 0.8, 20, hi.z * 0.6), mid, span)
        shot(tmp[3], (mid[0], mid[1], 30), (mid[0], mid[1] - 0.001, 0), span)
        stitch(tmp, os.path.join(out, "%s_views.png" % name), 2)
        tmp = [os.path.join(out, "_%s_g%d.png" % (name, i)) for i in range(4)]
        for i, yaw in enumerate((0.6, 2.2, math.pi + 0.5, -1.4)):
            shot(tmp[i], game_eye(mid, yaw), mid, span * 1.05)
        stitch(tmp, os.path.join(out, "%s_game.png" % name), 2)
        if rig and not arg("--no_strips"):
            for clip in clips:
                end = int(round(ck._tracks(rig)[clip].strips[0].action.frame_range[1]))
                step = max(1, math.ceil(end / 8))
                frames = list(range(1, end + 1, step))
                if clip == "attack" and gv.IMPACT["attack"] not in frames:
                    frames = sorted(set(frames + [gv.IMPACT["attack"]]))
                if frames[-1] != end:
                    frames.append(end)
                tp = []
                for view in (0, 1):
                    for f in frames:
                        play(rig, clip, f)
                        p = os.path.join(out, "_%s_s%d_%d.png" % (name, view, f))
                        if view == 0:
                            shot(p, (-20, mid[1] - 0.3, 0.8), (0, mid[1] - 0.3, hi.z * 0.5), span * 1.2, (380, 320))
                        else:
                            shot(p, game_eye(mid, 0.9), mid, span * 1.2, (380, 320))
                        tp.append(p)
                stitch(tp, os.path.join(out, "%s_strip_%s.png" % (name, clip)), len(frames))
                print("STRIP", name, clip, "quadros", frames)
        if rig and arg("--ground"):
            for clip in clips:
                act = ck._tracks(rig)[clip].strips[0].action
                worst, wf, who = 1e9, 0, ""
                for f in range(1, int(round(act.frame_range[1])) + 1):
                    play(rig, clip, f)
                    z, w_ = lows(objs)
                    if z < worst:
                        worst, wf, who = z, f, w_
                print("GROUND %s %-7s min %.3f (quadro %d, %s)%s" % (name, clip, worst, wf, who, "  <<<" if worst < -0.005 else ""))
        elif not rig:
            z, w_ = lows(objs)
            print("GROUND %s rest min %.3f%s" % (name, z, "  <<<" if z < -0.005 else ""))
        if rig:
            play(rig, None, 1)
        for o in list(bpy.context.scene.objects):
            bpy.data.objects.remove(o, do_unlink=True)
    print("preview done")


main()
