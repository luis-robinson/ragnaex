"""Prévia sem janela dos conjuntos do nível 50 (Ato III, chibi_kit.A3_STYLES): frente, costas e câmera do jogo (52°) lado a lado.
  blender -b --factory-startup --python tools/blender/lumeria_preview.py -- --out=<pasta ABSOLUTA> [--styles=pal_g50,ber_e50] [--sex=male|female|class]
Cores = as de GearCatalog.ACT3_VISUALS (espelho À MÃO em PALETTE: cor, destaque, brilho). Grava <pasta>/<estilo>_<sexo>.png.
"""
import math
import os
import sys

import bpy
from mathutils import Vector

sys.path.append(os.path.dirname(os.path.abspath(__file__)))
import chibi_kit as ck

IVORY = (0.94, 0.9, 0.82)
PALETTE = {          # estilo -> (tint, tint2, tint_glow)
    "pal_g50": (IVORY, (0.12, 0.16, 0.4), (1.0, 0.78, 0.3)),
    "ber_e50": (IVORY, (0.1, 0.09, 0.13), (1.0, 0.8, 0.35)),
    "bis_s50": (IVORY, (0.6, 0.58, 0.9), (1.0, 0.88, 0.55)),
    "dru_w50": (IVORY, (0.08, 0.34, 0.22), (1.0, 0.8, 0.4)),
    "ran_c50": (IVORY, (0.46, 0.6, 0.42), (1.0, 0.85, 0.5)),
    "ass_l50": (IVORY, (0.09, 0.27, 0.14), (0.75, 1.0, 0.3)),
    "ele_f50": (IVORY, (0.92, 0.42, 0.12), (1.0, 0.55, 0.15)),
    "nec_i50": (IVORY, (0.4, 0.14, 0.38), (0.8, 0.45, 1.0)),
}
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
        a = np.array(img.pixels[:], dtype=np.float32).reshape(img.size[1], img.size[0], 4)
        rows.append(a)
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
    styles = [s for s in arg("--styles").split(",") if s] or list(ck.A3_STYLES)
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
        for o in bpy.context.scene.objects:          # o jogo esconde o cabelo do boneco quando há peça de cabeça de conjunto
            if o.name.startswith("base_hair"):
                o.hide_render = True
        col, acc, glow = PALETTE.get(style, (IVORY, (0.7, 0.52, 0.2), (1.0, 0.62, 0.72)))
        paint("tint", col)
        paint("tint2", acc)
        paint("tint_glow", glow)
        paint("hair", ck.KIT_HAIR)
        tmp = [os.path.join(out, "_%s_%d.png" % (style, i)) for i in range(3)]
        shot(tmp[0], (0.9, -6, 1.5), (0, 0, 0.92), 2.35)
        shot(tmp[1], (-0.9, 6, 1.5), (0, 0, 0.92), 2.35)
        a = math.radians(52)
        shot(tmp[2], (math.sin(0.5) * 6 * math.cos(a), -math.cos(0.5) * 6 * math.cos(a), 0.9 + 6 * math.sin(a)), (0, 0, 0.9), 2.35)
        stitch(tmp, os.path.join(out, "%s_%s.png" % (style, sex)))
        print("PREVIEW", style, sex, len([o for o in bpy.context.scene.objects if o.name.startswith("arm_")]), "malhas")


main()
