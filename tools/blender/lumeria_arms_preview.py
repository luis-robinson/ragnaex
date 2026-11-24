"""Prévia sem janela das armas despertas do nível 50 (onda 4, chibi_kit.A3_WEAPONS): para cada arma do estilo, o boneco com o
conjunto 50 e a arma na mão (frente e câmera do jogo a 52°) + a arma de perto (frente e costas).
  blender -b --factory-startup --python tools/blender/lumeria_arms_preview.py -- --out=<pasta ABSOLUTA> [--styles=pal_g50,...] [--sex=male|female|class]
Cores = lumeria_preview.PALETTE (espelho de GearCatalog.ACT3_VISUALS). Grava <pasta>/<malha>_<sexo>.png.
"""
import math
import os
import sys

import bpy
from mathutils import Vector

sys.path.append(os.path.dirname(os.path.abspath(__file__)))
import chibi_kit as ck

IVORY = (0.94, 0.9, 0.82)
PALETTE = {"pal_g50": ((0.12, 0.16, 0.4), (1.0, 0.78, 0.3)), "pal_c50": ((0.45, 0.08, 0.14), (1.0, 0.82, 0.45)), "pal_t50": ((0.85, 0.45, 0.1), (1.0, 0.68, 0.22)),
           "ber_g50": ((0.72, 0.1, 0.12), (1.0, 0.45, 0.35)), "ber_e50": ((0.1, 0.09, 0.13), (1.0, 0.8, 0.35)), "ber_m50": ((0.1, 0.55, 0.5), (1.0, 0.75, 0.45)),
           "bis_s50": ((0.6, 0.58, 0.9), (1.0, 0.88, 0.55)), "bis_i50": ((0.85, 0.66, 0.25), (1.0, 0.95, 0.7)), "bis_b50": ((0.9, 0.56, 0.52), (1.0, 0.8, 0.5))}
W, H = 440, 600


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


def bounds(objs):
    pts = [o.matrix_world @ v.co for o in objs for v in o.data.vertices]
    lo = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
    hi = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
    return lo, hi


def main():
    out = arg("--out")
    styles = [s for s in arg("--styles").split(",") if s] or list(PALETTE)
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
        acc, glow = PALETTE[style]
        paint("tint", IVORY)
        paint("tint2", acc)
        paint("tint_glow", glow)
        paint("tint_glow_edge", glow)
        paint("hair", ck.KIT_HAIR)
        wpns = [o for o in bpy.context.scene.objects if o.type == "MESH" and o.name.startswith("wpn_")]
        mains = [o for o in wpns if o.name.startswith("wpn_main_")]
        offs = [o for o in wpns if o.name.startswith("wpn_off_")]
        for mi, m in enumerate(mains):
            for o in wpns:
                o.hide_render = not (o is m or (mi == 0 and o in offs))
            lo, hi = bounds([m])
            c = (lo + hi) * 0.5
            size = max((hi - lo).length * 1.25, 0.6) * float(arg("--close", "1"))
            tmp = [os.path.join(out, "_%s_%d.png" % (m.name, i)) for i in range(4)]
            shot(tmp[0], (0.9, -6, 1.5), (0, 0, 1.05), 2.9)
            a = math.radians(52)
            shot(tmp[1], (math.sin(0.5) * 6 * math.cos(a), -math.cos(0.5) * 6 * math.cos(a), 1.0 + 6 * math.sin(a)), (0, 0, 1.0), 2.9)
            others = [o for o in bpy.context.scene.objects if o.type == "MESH" and o is not m and not o.hide_render]
            for o in others:                 # de perto: só a arma (frente e costas/de cima)
                o.hide_render = True
            if "axe" in m.name:              # a lâmina do machado fica de lado para a frente do boneco: fotos pelos flancos
                shot(tmp[2], (c.x - 5, c.y - 1.2, c.z + 1.0), c, size)
                shot(tmp[3], (c.x + 5, c.y + 1.2, c.z + 2.6), c, size)
            else:
                shot(tmp[2], (c.x + 1.2, c.y - 5, c.z + 1.6), c, size)
                shot(tmp[3], (c.x - 1.2, c.y + 5, c.z + 3.2), c, size)
            for o in others:
                o.hide_render = False
            stitch(tmp, os.path.join(out, "%s_%s.png" % (m.name, sex)))
            print("PREVIEW", m.name, sex, "verts", len(m.data.vertices), "z", round(lo.z, 3), round(hi.z, 3))
        print("MESHES", style, sex, sorted(o.name for o in bpy.context.scene.objects if o.type == "MESH" and o.name.startswith(("wpn_", "arm_"))))


main()
