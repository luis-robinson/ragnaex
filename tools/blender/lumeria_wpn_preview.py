"""Prévia sem janela das armas despertas do nível 50 (onda 4, chibi_kit.A3_WEAPONS) NA MÃO, com o conjunto 50 da build:
frente, costas, câmera do jogo (52°) e um close da arma, lado a lado.
  blender -b --factory-startup --python tools/blender/lumeria_wpn_preview.py -- --out=<pasta ABSOLUTA> [--styles=ran_c50,ass_l50] [--sex=male|female|class]
Cores = PALETTE de lumeria_preview.py (lida do arquivo, sem importar: ele roda ao importar). Grava <pasta>/wpn_<estilo>_<sexo>.png.
"""
import ast
import math
import os
import sys

import bpy
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.append(HERE)
import chibi_kit as ck

W, H = 460, 640


def palette():
    """IVORY e PALETTE de lumeria_preview.py (espelho à mão de GearCatalog.ACT3_VISUALS)."""
    env = {}
    tree = ast.parse(open(os.path.join(HERE, "lumeria_preview.py"), encoding="utf-8").read())
    for node in tree.body:
        if isinstance(node, ast.Assign) and getattr(node.targets[0], "id", "") in ("IVORY", "PALETTE"):
            exec(compile(ast.Module([node], []), "palette", "exec"), env)
    return env["IVORY"], env["PALETTE"]


def arg(name, default=""):
    for a in sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []:
        if a.startswith(name + "="):
            return a.split("=", 1)[1]
    return default


def paint(name, col):
    m = bpy.data.materials.get(name)
    if m:
        m.diffuse_color = (*col, 1.0)


def shot(path, eye, target, ortho):
    sc = bpy.context.scene
    cam = bpy.data.objects.get("lum_cam")
    if cam is None:
        cam = bpy.data.objects.new("lum_cam", bpy.data.cameras.new("lum_cam"))
        sc.collection.objects.link(cam)
    cam.data.type = "ORTHO"
    cam.data.ortho_scale = ortho
    cam.data.clip_end = 100
    cam.location = Vector(eye)
    cam.rotation_euler = (Vector(target) - Vector(eye)).to_track_quat("-Z", "Y").to_euler()
    sc.camera = cam
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


def main():
    out = arg("--out")
    ivory, pal = palette()
    styles = [s for s in arg("--styles").split(",") if s] or sorted({k[:7] for k in ck.A3_WEAPONS})
    sex_arg = arg("--sex", "class")
    sc = bpy.context.scene
    sc.render.engine = "BLENDER_WORKBENCH"
    sc.render.resolution_x, sc.render.resolution_y = W, H
    sc.render.film_transparent = False
    sh = sc.display.shading
    sh.light = "STUDIO"
    sh.color_type = "MATERIAL"
    sh.show_object_outline = True
    sh.show_cavity = True
    sc.world = sc.world or bpy.data.worlds.new("w")
    sc.world.color = (0.36, 0.4, 0.36)
    os.makedirs(out, exist_ok=True)
    for style in styles:
        cid = ck.style_class(style)
        sex = ck.CLASS_BODY[cid] if sex_arg == "class" else sex_arg
        base = ck.build_kit_addon(sex, None, cid, "_a3", only_styles=[style])
        base["rig"].hide_render = True
        for o in bpy.context.scene.objects:
            if o.name.startswith("base_hair"):
                o.hide_render = True
        col, acc, glow = pal.get(style, (ivory, (0.7, 0.52, 0.2), (1.0, 0.62, 0.72)))
        paint("tint", col)
        paint("tint2", acc)
        paint("tint_glow", glow)
        paint("hair", ck.KIT_HAIR)
        wpn = [o for o in bpy.context.scene.objects if o.type == "MESH" and o.name.startswith("wpn_")]
        lo, hi = Vector((9, 9, 9)), Vector((-9, -9, -9))
        for o in wpn:
            for v in o.data.vertices:
                p = o.matrix_world @ v.co
                lo = Vector((min(lo.x, p.x), min(lo.y, p.y), min(lo.z, p.z)))
                hi = Vector((max(hi.x, p.x), max(hi.y, p.y), max(hi.z, p.z)))
        tmp = [os.path.join(out, "_w_%s_%d.png" % (style, i)) for i in range(4)]
        shot(tmp[0], (1.6, -8, 1.9), (0, -0.1, 1.12), 3.1)
        shot(tmp[1], (-1.6, 8, 1.9), (0, -0.1, 1.12), 3.1)
        a = math.radians(52)
        shot(tmp[2], (math.sin(0.5) * 8 * math.cos(a), -math.cos(0.5) * 8 * math.cos(a), 1.0 + 8 * math.sin(a)), (0, -0.1, 1.0), 3.1)
        c = (lo + hi) * 0.5              # close: de lado/frente/cima, enquadrando só a(s) arma(s)
        size = max((hi - lo).length * 1.2, 0.7)
        for o in bpy.context.scene.objects:          # no close só a arma
            if o.type == "MESH" and not o.name.startswith("wpn_"):
                o.hide_render = True
        shot(tmp[3], c + Vector((-5.0, -4.2, 3.0)), c, size)
        stitch(tmp, os.path.join(out, "wpn_%s_%s.png" % (style, sex)))
        print("WPN_PREVIEW", style, sex, sorted(o.name for o in wpn), "low_z=%.3f" % lo.z, "size=%s" % [round(x, 2) for x in (hi - lo)])


main()
