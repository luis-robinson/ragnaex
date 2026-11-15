"""Silhueta do pedestal da lista de personagens (espaço vazio, "Novo personagem"): manequim chibi liso, sem rosto.

    blender -b --factory-startup --python tools/blender/menu_silhouette.py -- [--preview=<png>] [--out=<glb>]

Mesmas proporções do `chibi_kit` (média dos corpos masculino e feminino, cabeça de 0,34 m, ~1,65 m com a cabeça),
pés em z = 0, olhando para -Y (= +Z no Godot, como o kit). Os braços abrem `ARM_OUT` graus para fora (pose neutra).
O corpo nasce como no kit (esqueleto de vértices + Skin), junta com a cabeça e vira UMA casca fechada (remesh por voxel,
sem sobreposição interna: o jogo deixa a peça translúcida) reduzida para menos de `MAX_TRIS` triângulos.

Saída (`assets/models/menu_silhouette.glb`):
  menu_silhouette   vazio raiz, origem nos pés; ação `idle` (2 s, laço: respira em escala, a cabeça sobe ~3 cm)
    silhouette      a malha; material único `silhouette` (Principled, rugosidade 1; o jogo troca por translúcido/brilho)
Prévia (`--preview`): importa `menu_set.glb`, põe o GLB exportado no vazio `SPOT_pedestal` e fotografa de `CAM_list`
com a luz de revisão do `menu_set.render`. Não salva .blend.
"""
import bpy
import math
import os
import shutil
import sys
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
    sys.path.append(HERE)
import chibi_kit as ck  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(HERE))
OUT = os.path.join(ROOT, "assets", "models", "menu_silhouette.glb")
SET_GLB = os.path.join(ROOT, "assets", "models", "menu_set.glb")
PREVIEW = os.path.join(ROOT, "production", "qa", "evidence", "start-flow", "silhouette_preview.png")

ARM_OUT = 14.0          # graus: braços afastados do corpo
ELBOW_BEND = 8.0        # graus: cotovelo levemente dobrado para a frente
VOXEL = 0.016           # remesh (m)
MAX_TRIS = 2900
FPS, LOOP = 24, 48      # 2 s
BREATH = (1.012, 1.012, 1.022)      # escala no meio do fôlego (x, y, z do Blender)
COLOR = (0.82, 0.86, 0.94)


def neutral_body():
    """Média dos corpos masculino e feminino do kit."""
    m, f = ck.BODIES["male"], ck.BODIES["female"]
    return {k: (m[k] + f[k]) * 0.5 for k in m}


def _rot_out(p, pivot, sx, deg):
    """Gira `p` em volta de `pivot` no plano XZ, abrindo para o lado `sx` (+1 = .L, -1 = .R)."""
    a = math.radians(deg)
    ux, uz = (p[0] - pivot[0]) * sx, p[2] - pivot[2]
    x2 = ux * math.cos(a) - uz * math.sin(a)
    z2 = ux * math.sin(a) + uz * math.cos(a)
    return (pivot[0] + x2 * sx, p[1], pivot[2] + z2)


def posed_joints(b):
    j = dict(ck.joints(b))
    for side, sx in ((".R", -1), (".L", 1)):
        sh = j["shoulder" + side]
        for k in ("elbow", "wrist", "hand_tip"):
            j[k + side] = _rot_out(j[k + side], sh, sx, ARM_OUT)
        # antebraço e mão um pouco para a frente (-Y)
        el = Vector(j["elbow" + side])
        for k in ("wrist", "hand_tip"):
            v = Vector(j[k + side]) - el
            j[k + side] = tuple(el + Vector((v.x, v.y - abs(v.z) * math.tan(math.radians(ELBOW_BEND)), v.z)))
    return j


def build_mesh(mat):
    b = neutral_body()
    j = posed_joints(b)
    body = ck.make_body("sil_body", b, j, mat)
    head = ck.quad_sphere("sil_head", b["head"], (0, 0, 0), cuts=4)
    c = Vector(j["neck_top"]) + Vector((0, 0, b["head"] * 0.92))
    for v in head.data.vertices:
        d = v.co.copy()
        d.x *= 1.04
        d.y *= 0.96
        d.z *= 0.92
        if d.z < 0:                         # queixo afinado, como o `make_head` do kit
            d.x *= 1.0 + d.z * 0.5
        if d.y > 0 and d.z > -0.05:         # volume de cabelo atrás e em cima (leitura de "cabeça", sem penteado)
            d.y *= 1.1
            d.z *= 1.12
        v.co = c + d
    head.data.materials.append(mat)
    # pescoço que entra na cabeça (no kit a esfera só encosta no pescoço; depois do remesh vira um fio)
    neck = ck.tube("sil_neck", (0, 0, ck.Z["neck"] - 0.02), (0, 0, ck.Z["neck_top"] + 0.1), b["neck"] * 1.15,
                   b["neck"] * 1.5, mat, 10)
    ob = ck._join([body, neck, head], "silhouette")
    rm = ob.modifiers.new("remesh", "REMESH")
    rm.mode = "VOXEL"
    rm.voxel_size = VOXEL
    rm.use_smooth_shade = True
    ck._bake(ob)
    tris = sum(len(p.vertices) - 2 for p in ob.data.polygons)
    if tris > MAX_TRIS:
        dec = ob.modifiers.new("decimate", "DECIMATE")
        dec.ratio = MAX_TRIS / tris * 0.97
        ck._bake(ob)
    ob.data.materials.clear()
    ob.data.materials.append(mat)
    for p in ob.data.polygons:
        p.use_smooth = True
    return ob


def breathe(root):
    root.animation_data_create()
    act = bpy.data.actions.new("idle")
    root.animation_data.action = act
    for f, s in ((1, (1.0, 1.0, 1.0)), (1 + LOOP // 2, BREATH), (1 + LOOP, (1.0, 1.0, 1.0))):
        root.scale = s
        root.keyframe_insert("scale", frame=f)
    root.scale = (1.0, 1.0, 1.0)
    sc = bpy.context.scene
    sc.render.fps = FPS
    sc.frame_start, sc.frame_end = 1, 1 + LOOP
    return act


def build(export=True, path=OUT):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    mat = ck.mat("silhouette", COLOR, rough=1.0)
    ob = build_mesh(mat)
    root = bpy.data.objects.new("menu_silhouette", None)
    root.empty_display_size = 0.3
    bpy.context.scene.collection.objects.link(root)
    ob.parent = root
    breathe(root)
    bpy.context.view_layer.update()
    tris = sum(len(p.vertices) - 2 for p in ob.data.polygons)
    cs = [ob.matrix_world @ Vector(v) for v in ob.bound_box]
    print("SIL tris=%d altura=%.3f largura=%.3f fundo=%.3f pe_min_z=%.4f" % (
        tris, max(v.z for v in cs), max(v.x for v in cs) - min(v.x for v in cs),
        max(v.y for v in cs) - min(v.y for v in cs), min(v.z for v in cs)))
    if export:
        os.makedirs(os.path.dirname(path), exist_ok=True)
        ck.deselect_everything()
        bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=False, use_active_scene=True,
                                  export_apply=True, export_yup=True, export_animations=True, export_materials="EXPORT",
                                  export_cameras=False, export_lights=False)
        print("SIL export: %s (%d KB)" % (path, os.path.getsize(path) // 1024))
    return root, ob


def _preview_material(m):
    """Só na prévia: translúcido com borda que brilha (o que o jogo faz com o material `silhouette`)."""
    m.use_nodes = True
    nt = m.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    lw = nt.nodes.new("ShaderNodeLayerWeight")
    lw.inputs["Blend"].default_value = 0.45
    em = nt.nodes.new("ShaderNodeEmission")
    em.inputs["Color"].default_value = (0.75, 0.88, 1.0, 1.0)
    em.inputs["Strength"].default_value = 1.6
    tr = nt.nodes.new("ShaderNodeBsdfTransparent")
    mr = nt.nodes.new("ShaderNodeMapRange")
    mr.inputs["To Min"].default_value = 0.35
    mr.inputs["To Max"].default_value = 0.95
    nt.links.new(lw.outputs["Facing"], mr.inputs["Value"])
    mx = nt.nodes.new("ShaderNodeMixShader")
    nt.links.new(mr.outputs["Result"], mx.inputs[0])
    nt.links.new(tr.outputs[0], mx.inputs[1])
    nt.links.new(em.outputs[0], mx.inputs[2])
    nt.links.new(mx.outputs[0], out.inputs["Surface"])
    for attr, val in (("surface_render_method", "BLENDED"), ("blend_method", "BLEND"), ("use_backface_culling", True)):
        try:
            setattr(m, attr, val)
        except (AttributeError, TypeError) as err:
            print("preview mat:", attr, err)


def preview(png=PREVIEW, glb=OUT):
    """Cenário do menu + o GLB exportado no `SPOT_pedestal`, foto de `CAM_list` (luz do `menu_set.render`)."""
    import menu_set as ms
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=SET_GLB)
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=glb)
    mine = [o for o in bpy.data.objects if o not in before]
    root = next(o for o in mine if o.name.startswith("menu_silhouette") and o.parent is None)
    spot = bpy.data.objects["SPOT_pedestal"]
    root.animation_data_clear()
    root.matrix_world = spot.matrix_world.copy()
    for o in mine:
        if o.type == "MESH":
            for m in o.data.materials:
                _preview_material(m)
                print("SIL material:", m.name)
    bpy.context.view_layer.update()
    tmp = os.path.join(bpy.app.tempdir or os.path.dirname(png), "sil_preview")
    shots = (("CAM_list", (1280, 720), "", False),)
    paths = ms.render(tmp, "sil", shots)
    os.makedirs(os.path.dirname(png), exist_ok=True)
    shutil.copyfile(paths[0], png)
    print("SIL preview:", png)
    return png


def _main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    opt = {a.split("=")[0]: (a.split("=", 1)[1] if "=" in a else "") for a in argv}
    out = opt.get("--out") or OUT
    build(export=True, path=out)
    if "--no_preview" not in opt:
        preview(opt.get("--preview") or PREVIEW, out)


if __name__ == "__main__":
    _main()
