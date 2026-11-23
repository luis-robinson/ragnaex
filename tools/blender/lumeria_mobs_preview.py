"""Prévia sem janela das Demônias da Sede (lumeria_mobs.py): folha frente / costas / lado / câmera do jogo (52°) de frente e
de costas / cabeça de perto, mais uma folha de poses (um quadro de cada clipe pedido) e a conta de chão por clipe.
  blender -b --factory-startup --python tools/blender/lumeria_mobs_preview.py -- --out=<pasta ABSOLUTA> [--only=mob_a,mob_b]
      [--poses=idle:1,run:5,attack:5,die:30] [--ground] [--export=<pasta ABSOLUTA dos GLB>] [--module=lumeria_bosses]
--ground imprime `GROUND <modelo> <clipe> <z mínimo>` (todas as malhas, quadro a quadro) ; --export grava o GLB pelo mesmo
caminho do mob_kit.build_all (ck.export_glb) sem montar os outros monstros.
"""
import math
import os
import sys

import bpy
from mathutils import Vector

sys.path.append(os.path.dirname(os.path.abspath(__file__)))
import chibi_kit as ck
import mob_kit as mk          # noqa: F401 (lumeria_mobs importa mob_kit)
import lumeria_mobs as lm

W, H = 420, 560


def arg(name, default=""):
    for a in sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []:
        if a == name:
            return "1"
        if a.startswith(name + "="):
            return a.split("=", 1)[1]
    return default


if arg("--module"):               # outro módulo com BUILDERS/HUMANOIDS (lumeria_bosses: chefes de mundo e lacaios)
    import importlib
    lm = importlib.import_module(arg("--module"))


def shot(path, eye, target, ortho, res=(W, H)):
    sc = bpy.context.scene
    cam = bpy.data.objects.get("lum_cam")
    if cam is None:
        cam = bpy.data.objects.new("lum_cam", bpy.data.cameras.new("lum_cam"))
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


def stitch(paths, out):
    import numpy as np
    rows = []
    for p in paths:
        img = bpy.data.images.load(p)
        rows.append(np.array(img.pixels[:], dtype=np.float32).reshape(img.size[1], img.size[0], 4))
        bpy.data.images.remove(img)
    a = np.concatenate(rows, axis=1)
    res = bpy.data.images.new("lum_sheet", a.shape[1], a.shape[0], alpha=True)
    res.pixels = a.ravel().tolist()
    res.filepath_raw = out
    res.file_format = "PNG"
    res.save()
    bpy.data.images.remove(res)
    for p in paths:
        os.remove(p)


def game_eye(target, yaw, dist=12.0):
    a = math.radians(52)
    return (target[0] + math.sin(yaw) * dist * math.cos(a), target[1] - math.cos(yaw) * dist * math.cos(a), target[2] + dist * math.sin(a))


def meshes(rig):
    return [o for o in rig.children if o.type == "MESH"]


LOW = [""]


def bounds(rig):
    dg = bpy.context.evaluated_depsgraph_get()
    lo, hi = Vector((1e9, 1e9, 1e9)), Vector((-1e9, -1e9, -1e9))
    for o in meshes(rig):
        ev = o.evaluated_get(dg)
        me = ev.to_mesh()
        for v in me.vertices:
            p = ev.matrix_world @ v.co
            if p.z < lo.z:
                g = max(o.data.vertices[v.index].groups, key=lambda g_: g_.weight, default=None) if v.index < len(o.data.vertices) else None
                LOW[0] = "%s/%s" % (o.name, o.vertex_groups[g.group].name if g else "?")
            for i in range(3):
                lo[i] = min(lo[i], p[i])
                hi[i] = max(hi[i], p[i])
        ev.to_mesh_clear()
    return lo, hi


def play(rig, clip, frame):
    ad = rig.animation_data
    for t in ad.nla_tracks:
        t.mute = True
    if clip is None:
        bpy.context.scene.frame_set(1)      # as faixas NLA voltam a valer: no quadro 1 todas estão em repouso
        ad.action = None
        for pb in rig.pose.bones:
            pb.rotation_euler = (0, 0, 0)
            pb.rotation_quaternion = (1, 0, 0, 0)
            pb.location = (0, 0, 0)
        for t in ad.nla_tracks:
            t.mute = False
    else:
        act = ck._tracks(rig)[clip].strips[0].action
        ad.action = act
        if getattr(ad, "action_slot", None) is None and getattr(act, "slots", None):
            ad.action_slot = act.slots[0]
        bpy.context.scene.frame_set(frame)
    bpy.context.view_layer.update()


def main():
    out = arg("--out")
    only = [s for s in arg("--only").split(",") if s] or list(lm.BUILDERS)
    poses = [p.split(":") for p in arg("--poses", "idle:1,run:5,attack:5,die:30").split(",") if p]
    sc = bpy.context.scene
    sc.render.engine = "BLENDER_WORKBENCH"
    sc.render.film_transparent = False
    sh = sc.display.shading
    sh.light = "STUDIO"
    sh.color_type = "MATERIAL"
    sh.show_object_outline = True
    sh.show_cavity = True
    sc.world = sc.world or bpy.data.worlds.new("w")
    sc.world.color = (0.36, 0.4, 0.36)
    os.makedirs(out, exist_ok=True)
    if arg("--flat"):                 # base de comparação: o corpo do kit sem esticar as pernas
        for k in lm.KINDS.values():
            k["leg"], k["torso"] = 0.0, 0.0
    for name in only:
        ck.clear()
        rig = lm.BUILDERS[name]()
        for o in bpy.context.scene.objects:
            if "." in o.name:
                o.name = o.name.replace(".", "_")
        if arg("--export"):
            if name in lm.HUMANOIDS:
                ck.export_glb(rig, os.path.join(arg("--export"), name + ".glb"))
            else:
                mk.lp.export_glb(os.path.join(arg("--export"), name + ".glb"), [rig])
        rig.hide_render = True
        tris = sum(len(p.vertices) - 2 for o in meshes(rig) for p in o.data.polygons)
        print("MODEL", name, len(meshes(rig)), "malhas", tris, "tris", "clipes:", " ".join(sorted(ck._tracks(rig))))
        # chão plano para ver o que encosta/atravessa
        if bpy.data.objects.get("lum_floor") is None:
            fl = ck.box("lum_floor", (14, 14, 0.02), (0, 0, -0.011), ck.mat("m_lum_floor", (0.5, 0.52, 0.46), 1.0))
        play(rig, None, 1)
        lo, hi = bounds(rig)
        print("BOUNDS", name, [round(x, 2) for x in lo], [round(x, 2) for x in hi])
        hgt = hi.z
        mid = (0, 0, hgt * 0.5)
        tmp = [os.path.join(out, "_%s_%d.png" % (name, i)) for i in range(7)]
        orth = hgt * 1.3
        shot(tmp[0], (0.9, -12, hgt * 0.75), mid, orth)
        shot(tmp[1], (-0.9, 12, hgt * 0.75), mid, orth)
        shot(tmp[2], (-12, 0.3, hgt * 0.75), mid, orth)
        shot(tmp[3], game_eye(mid, 0.5), mid, orth)
        shot(tmp[4], game_eye(mid, math.pi - 0.6), mid, orth)
        hc = (0, 0, hgt - 0.36)
        shot(tmp[5], (2.2, -9, hgt + 0.2), hc, 1.25)
        shot(tmp[6], (-2.6, 9, hgt + 2.6), hc, 1.25)
        stitch(tmp, os.path.join(out, "%s.png" % name))
        if hi.y - lo.y > 2.0:            # cauda comprida: a silhueta inteira na câmera do jogo
            c2 = (0, (lo.y + hi.y) * 0.5, 0.5)
            span = (hi.y - lo.y) * 1.15
            t2 = [os.path.join(out, "_%s_t%d.png" % (name, i)) for i in range(3)]
            shot(t2[0], game_eye(c2, 0.5, 20), c2, span, (640, 560))
            shot(t2[1], game_eye(c2, math.pi * 0.5, 20), c2, span, (640, 560))
            shot(t2[2], (c2[0], c2[1], 30), (c2[0], c2[1] + 0.001, 0), span, (640, 560))
            stitch(t2, os.path.join(out, "%s_tail.png" % name))
        if poses:
            tp = []
            for i, (clip, fr) in enumerate(poses):
                if clip not in ck._tracks(rig):
                    continue
                play(rig, clip, int(fr))
                p = os.path.join(out, "_%s_p%d.png" % (name, i))
                shot(p, game_eye(mid, 0.9), mid, orth * 1.15)
                tp.append(p)
                p = os.path.join(out, "_%s_q%d.png" % (name, i))
                shot(p, (-12, -1.5, 0.7), (0, 0, hgt * 0.45), orth * 1.15)
                tp.append(p)
            stitch(tp, os.path.join(out, "%s_poses.png" % name))
        if arg("--ground"):
            for clip in sorted(ck._tracks(rig)):
                act = ck._tracks(rig)[clip].strips[0].action
                worst, wf = 1e9, 0
                for f in range(1, int(round(act.frame_range[1])) + 1):
                    play(rig, clip, f)
                    z = bounds(rig)[0].z
                    if z < worst:
                        worst, wf, low = z, f, LOW[0]
                print("GROUND %s %-14s %.3f (quadro %d) %s%s" % (name, clip, worst, wf, low, "  <<<" if worst < -0.03 and clip != "die" else ""))
        play(rig, None, 1)
    print("preview done")


main()
