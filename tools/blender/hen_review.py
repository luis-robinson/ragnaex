"""Galinha de Aldara (prop_hen.glb): refaz o modelo, confere e fotografa. Sem janela:

    blender -b --factory-startup --python tools/blender/hen_review.py -- [--out=<pasta dos GLB>] [--shots=<pasta das fotos>] [--no_export]

Imprime `HEN tris=... size=... min=... max=...` e, depois do export, `HEN_GLB ... COLOR_0=True/False`.
Fotos: `hen_game.png` (câmera do jogo, 52°), `hen_side.png`, `hen_front.png`, `hen_top.png`, `hen_flock.png` (bando visto de longe)."""
import json
import math
import os
import struct
import sys

import bpy
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.append(HERE)
import prop_kit  # noqa: E402

ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
opt = dict(a[2:].split("=", 1) if "=" in a else (a[2:], "1") for a in args if a.startswith("--"))
OUT = os.path.abspath(opt.get("out", os.path.join(ROOT, "assets", "models")))
SHOTS = os.path.abspath(opt.get("shots", os.path.join(ROOT, "production", "qa", "evidence", "hen")))


def measure(o):
    me = o.data
    tris = sum(len(p.vertices) - 2 for p in me.polygons)
    lo = Vector((min(v.co[i] for v in me.vertices) for i in range(3)))
    hi = Vector((max(v.co[i] for v in me.vertices) for i in range(3)))
    print("HEN tris=%d size=%.3f,%.3f,%.3f min=%.3f,%.3f,%.3f max=%.3f,%.3f,%.3f mats=%d" % (tris, *(hi - lo), *lo, *hi, len(me.materials)))


def shoot(name, loc, target, ortho=0.62, res=(640, 640)):
    sc = bpy.context.scene
    cam = bpy.data.objects.get("hen_cam")
    if cam is None:
        cam = bpy.data.objects.new("hen_cam", bpy.data.cameras.new("hen_cam"))
        sc.collection.objects.link(cam)
    cam.data.type = "ORTHO"
    cam.data.ortho_scale = ortho
    cam.location = loc
    cam.rotation_euler = (Vector(target) - Vector(loc)).to_track_quat("-Z", "Y").to_euler()
    sc.camera = cam
    sc.render.resolution_x, sc.render.resolution_y = res
    sc.render.filepath = os.path.join(SHOTS, name)
    bpy.ops.render.render(write_still=True)


def stage():
    sc = bpy.context.scene
    for eng in ("BLENDER_EEVEE", "BLENDER_EEVEE_NEXT"):
        try:
            sc.render.engine = eng
            break
        except TypeError:
            pass
    sc.view_settings.view_transform = "Standard"
    w = sc.world or bpy.data.worlds.new("hen_world")
    sc.world = w
    w.use_nodes = True
    bg = next(n for n in w.node_tree.nodes if n.type == "BACKGROUND")
    bg.inputs[0].default_value = (0.75, 0.80, 0.85, 1.0)
    bg.inputs[1].default_value = 0.55
    sun = bpy.data.objects.new("hen_sun", bpy.data.lights.new("hen_sun", "SUN"))
    sun.data.energy = 2.6
    sun.rotation_euler = (math.radians(38), math.radians(-18), math.radians(25))
    sc.collection.objects.link(sun)
    # chão de capim (só da foto; some antes do export porque o build limpa a cena)
    me = bpy.data.meshes.new("hen_floor")
    me.from_pydata([(-40, -40, 0), (40, -40, 0), (40, 40, 0), (-40, 40, 0)], [], [(0, 1, 2, 3)])
    gm = bpy.data.materials.new("hen_floor")
    gm.use_nodes = True
    next(n for n in gm.node_tree.nodes if n.type == "BSDF_PRINCIPLED").inputs["Base Color"].default_value = (0.20, 0.36, 0.14, 1.0)
    me.materials.append(gm)
    sc.collection.objects.link(bpy.data.objects.new("hen_floor", me))


def cam_at(yaw, pitch, dist=3.0, target=(0, 0, 0.17)):
    y, p = math.radians(yaw), math.radians(pitch)
    t = Vector(target)
    return t + Vector((math.sin(y) * math.cos(p), -math.cos(y) * math.cos(p), math.sin(p))) * dist, t


def glb_check(path):
    with open(path, "rb") as f:
        data = f.read()
    n = struct.unpack("<I", data[12:16])[0]
    js = json.loads(data[20:20 + n].decode("utf-8"))
    prims = [p for me in js["meshes"] for p in me["primitives"]]
    acc = js["accessors"]
    tris = sum(acc[p["indices"]]["count"] // 3 for p in prims)
    pos = acc[prims[0]["attributes"]["POSITION"]]
    col = prims[0]["attributes"].get("COLOR_0")
    print("HEN_GLB %s bytes=%d nodes=%d meshes=%d prims=%d materials=%d tris=%d attrs=%s COLOR_0=%s color_type=%s textures=%d min=%s max=%s" % (
        os.path.basename(path), len(data), len(js["nodes"]), len(js["meshes"]), len(prims), len(js.get("materials", [])), tris,
        sorted(prims[0]["attributes"]), col is not None, (acc[col]["type"], acc[col]["componentType"]) if col is not None else None,
        len(js.get("textures", [])), pos["min"], pos["max"]))


os.makedirs(SHOTS, exist_ok=True)
hen = prop_kit.build("hen")[0]
measure(hen)
stage()
shoot("hen_game.png", *cam_at(35, 52))
shoot("hen_game_back.png", *cam_at(150, 52))
shoot("hen_side.png", *cam_at(90, 4))
shoot("hen_front.png", *cam_at(0, 8))
shoot("hen_top.png", *cam_at(0, 89.9))
# bando de longe: como a câmera do jogo vê (24 m): cada galinha com poucas dezenas de pixels
import random  # noqa: E402
rnd = random.Random(7)
clones = []
for i in range(7):
    c = bpy.data.objects.new("hen_c%d" % i, hen.data)
    c.location = (rnd.uniform(-1.6, 1.6), rnd.uniform(-1.2, 1.2), 0)
    c.rotation_euler = (0, 0, rnd.uniform(0, 6.28))
    bpy.context.scene.collection.objects.link(c)
    clones.append(c)
shoot("hen_flock.png", *cam_at(0, 52, 24.0, (0, 0, 0)), ortho=4.6, res=(960, 540))
for c in clones:
    bpy.data.objects.remove(c, do_unlink=True)
bpy.data.objects.remove(bpy.data.objects["hen_cam"], do_unlink=True)
if "no_export" not in opt:
    prop_kit.build_all(OUT, only=["hen"])
    glb_check(os.path.join(OUT, "prop_hen.glb"))
