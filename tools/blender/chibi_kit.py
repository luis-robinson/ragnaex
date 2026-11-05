"""Kit modular chibi (estilo Tree of Savior): corpo base masculino/feminino com edge loops limpos,
rig deformável, armaduras conformadas ao corpo (mesmos pesos) e armas presas na mão.

Rodar dentro do Blender (MCP ou headless):
    import sys; sys.path.append(r"C:/Users/luisf/Desktop/projects/ragnaex/tools/blender")
    import chibi_kit as ck; ck.preview()          # monta masculino + feminino lado a lado

Ideia: o corpo nasce de um "esqueleto de vértices" + modificador Skin (+ Subdivision) -> malha só de
quads com loops nas juntas. Armaduras = cópia da região do corpo empurrada pra fora + Solidify, então
herdam os vertex groups e deformam igual ao corpo. Tudo usa o mesmo rig -> peças trocáveis.
Frente do personagem = -Y. Direita do personagem (.R) = -X.
"""
import bpy
import bmesh
import json
import math
import os
import sys
from mathutils import Euler, Matrix, Quaternion, Vector

# ---------------------------------------------------------------------------
# proporções (unidades = metros do jogo; altura total ~1.7 com a cabeça chibi)
# ---------------------------------------------------------------------------
BODIES = {
    "male": dict(shoulder=0.215, hip=0.088, pelvis=0.165, waist=0.155, chest=0.185, upper=0.17,
                 arm=0.07, elbow=0.06, wrist=0.05, hand=0.058, thigh=0.088, knee=0.072, ankle=0.064,
                 toe=0.07, neck=0.065, depth=0.8, head=0.34),
    "female": dict(shoulder=0.19, hip=0.09, pelvis=0.17, waist=0.13, chest=0.165, upper=0.15,
                   arm=0.06, elbow=0.052, wrist=0.043, hand=0.05, thigh=0.086, knee=0.066, ankle=0.056,
                   toe=0.062, neck=0.056, depth=0.8, head=0.34),
}
# alturas das juntas (z)
Z = dict(ankle=0.07, knee=0.2, hip=0.34, pelvis=0.38, waist=0.54, chest=0.7, upper=0.82,
         neck=0.9, neck_top=0.99, head=1.31)

SKIN = (0.98, 0.84, 0.72)


# ---------------------------------------------------------------------------
# cena / materiais
# ---------------------------------------------------------------------------
def clear():
    """Limpa SÓ a cena ativa (objetos + dados órfãos criados por nós)."""
    for o in list(bpy.context.scene.objects):
        bpy.data.objects.remove(o, do_unlink=True)
    for coll in (bpy.data.meshes, bpy.data.armatures, bpy.data.actions):
        for b in list(coll):
            if b.users == 0:
                coll.remove(b)


def mat(name, color, rough=0.9, emission=0.0):
    m = bpy.data.materials.get(name)
    if m:
        return m
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    bsdf = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    bsdf.inputs["Base Color"].default_value = (*color, 1.0)
    bsdf.inputs["Roughness"].default_value = rough
    if emission > 0:
        bsdf.inputs["Emission Color"].default_value = (*color, 1.0)
        bsdf.inputs["Emission Strength"].default_value = emission
    m.diffuse_color = (*color, 1.0)
    return m


def _link(obj, coll=None):
    (coll or bpy.context.scene.collection).objects.link(obj)
    return obj


def _bake(obj):
    """Aplica todos os modificadores (sem bpy.ops) e devolve o mesmo objeto."""
    dg = bpy.context.evaluated_depsgraph_get()
    me = bpy.data.meshes.new_from_object(obj.evaluated_get(dg))
    old = obj.data
    obj.modifiers.clear()
    obj.data = me
    if old.users == 0:
        bpy.data.meshes.remove(old)
    return obj


def _smooth(me):
    for p in me.polygons:
        p.use_smooth = True


# ---------------------------------------------------------------------------
# rig
# ---------------------------------------------------------------------------
def joints(b):
    S, H = b["shoulder"], b["hip"]
    j = {
        "root": (0, 0, 0), "pelvis": (0, 0, Z["pelvis"]), "waist": (0, 0, Z["waist"]),
        "chest": (0, 0, Z["chest"]), "upper": (0, 0, Z["upper"]), "neck": (0, 0, Z["neck"]),
        "neck_top": (0, 0, Z["neck_top"]), "head_top": (0, 0, Z["head"] + b["head"]),
    }
    for side, sx in ((".R", -1), (".L", 1)):
        j["shoulder" + side] = (sx * S, 0, Z["upper"] + 0.01)
        j["elbow" + side] = (sx * (S + 0.045), 0.0, Z["upper"] - 0.15)
        j["wrist" + side] = (sx * (S + 0.075), -0.01, Z["upper"] - 0.29)
        j["hand_tip" + side] = (sx * (S + 0.085), -0.02, Z["upper"] - 0.37)
        j["hip" + side] = (sx * H, 0, Z["hip"])
        j["knee" + side] = (sx * H, -0.005, Z["knee"])
        j["ankle" + side] = (sx * H, 0.0, Z["ankle"])
        j["toe" + side] = (sx * H, -0.1, 0.03)
    return j


def bone_defs(j):
    """nome: (cabeça, cauda, pai)"""
    d = {
        "root": (j["root"], (0, 0, 0.12), None),
        "hips": (j["pelvis"], j["waist"], "root"),
        "spine": (j["waist"], j["chest"], "hips"),
        "chest": (j["chest"], j["neck"], "spine"),
        "neck": (j["neck"], j["neck_top"], "chest"),
        "head": (j["neck_top"], j["head_top"], "neck"),
    }
    for s in (".R", ".L"):
        d["upper_arm" + s] = (j["shoulder" + s], j["elbow" + s], "chest")
        d["forearm" + s] = (j["elbow" + s], j["wrist" + s], "upper_arm" + s)
        d["hand" + s] = (j["wrist" + s], j["hand_tip" + s], "forearm" + s)
        d["thigh" + s] = (j["hip" + s], j["knee" + s], "hips")
        d["shin" + s] = (j["knee" + s], j["ankle" + s], "thigh" + s)
        d["foot" + s] = (j["ankle" + s], j["toe" + s], "shin" + s)
    return d


def make_rig(name, j):
    arm_data = bpy.data.armatures.new(name + "_arm")
    rig = _link(bpy.data.objects.new(name, arm_data))
    bpy.context.view_layer.objects.active = rig
    bpy.ops.object.mode_set(mode="EDIT")
    eb = arm_data.edit_bones
    defs = bone_defs(j)
    for bn, (h, t, _p) in defs.items():
        b = eb.new(bn)
        b.head, b.tail = Vector(h), Vector(t)
        b.roll = 0.0
    for bn, (_h, _t, p) in defs.items():
        if p:
            eb[bn].parent = eb[p]
            eb[bn].use_connect = (Vector(eb[bn].head) - Vector(eb[p].tail)).length < 1e-4
    eb["root"].use_deform = False
    bpy.ops.object.mode_set(mode="OBJECT")
    rig.show_in_front = True
    return rig


# ---------------------------------------------------------------------------
# corpo (Skin modifier -> quads com loops)
# ---------------------------------------------------------------------------
def make_body(name, b, j, m_skin):
    """Esqueleto de vértices com raio por vértice; o Skin gera o tubo contínuo, Subsurf arredonda."""
    pts = []      # (pos, raio)
    edges = []

    def v(key, r):
        pts.append((j[key], r))
        return len(pts) - 1

    pelvis = v("pelvis", b["pelvis"])
    waist = v("waist", b["waist"])
    chest = v("chest", b["chest"])
    upper = v("upper", b["upper"])
    neck = v("neck", b["neck"])
    neck_top = v("neck_top", b["neck"])
    edges += [(pelvis, waist), (waist, chest), (chest, upper), (upper, neck), (neck, neck_top)]
    for s in (".R", ".L"):
        sh = v("shoulder" + s, b["arm"])
        el = v("elbow" + s, b["elbow"])
        wr = v("wrist" + s, b["wrist"])
        ha = v("hand_tip" + s, b["hand"])
        hp = v("hip" + s, b["thigh"])
        kn = v("knee" + s, b["knee"])
        an = v("ankle" + s, b["ankle"])
        to = v("toe" + s, b["toe"])
        edges += [(upper, sh), (sh, el), (el, wr), (wr, ha), (pelvis, hp), (hp, kn), (kn, an), (an, to)]
    me = bpy.data.meshes.new(name + "_mesh")
    me.from_pydata([p for p, _r in pts], edges, [])
    obj = _link(bpy.data.objects.new(name, me))
    skin = obj.modifiers.new("skin", "SKIN")
    skin.branch_smoothing = 0.6
    skin.use_smooth_shade = True
    for i, (_p, r) in enumerate(pts):
        sv = me.skin_vertices[0].data[i]
        sv.radius = (r, r)
        sv.use_root = (i == pelvis)
    sub = obj.modifiers.new("sub", "SUBSURF")
    sub.levels = 1
    sub.render_levels = 1
    _bake(obj)
    # achata o tronco na profundidade (chibi é mais "largo que fundo") e arredonda a barriga
    for vert in obj.data.vertices:
        co = vert.co
        if Z["hip"] - 0.02 < co.z < Z["neck"] and abs(co.x) < b["shoulder"] + 0.02:
            co.y *= b["depth"]
    obj.data.materials.append(m_skin)
    _smooth(obj.data)
    return obj


def quad_sphere(name, radius, center, cuts=3):
    """Esfera só de quads (cubo subdividido projetado) — loops limpos, sem polos."""
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=2.0)
    bmesh.ops.subdivide_edges(bm, edges=bm.edges[:], cuts=cuts, use_grid_fill=True)
    for vert in bm.verts:
        vert.co = vert.co.normalized() * radius + Vector(center)
    me = bpy.data.meshes.new(name + "_mesh")
    bm.to_mesh(me)
    bm.free()
    _smooth(me)
    return _link(bpy.data.objects.new(name, me))


def make_head(name, b, j, m_skin, m_eye, m_white):
    c = Vector(j["neck_top"]) + Vector((0, 0, b["head"] * 0.92))
    head = quad_sphere(name, b["head"], c, cuts=4)
    for vert in head.data.vertices:
        d = vert.co - c
        d.x *= 1.04
        d.y *= 0.96
        d.z *= 0.92
        if d.z < 0:            # queixo levemente afinado (rosto chibi)
            d.x *= 1.0 + d.z * 0.5
        vert.co = c + d
    head.data.materials.append(m_skin)
    parts = [head]
    # olhos grandes ovais (ToS), um pouco abaixo do centro
    for sx in (-1, 1):
        e = quad_sphere(name + "_eye", 0.06, (0, 0, 0), cuts=2)
        for vert in e.data.vertices:
            vert.co = Vector((vert.co.x * 0.85, vert.co.y * 0.35, vert.co.z * 1.35))
            vert.co += c + Vector((sx * 0.13, -b["head"] * 0.9, -0.04))
        e.data.materials.append(m_eye)
        parts.append(e)
        hl = quad_sphere(name + "_hl", 0.018, c + Vector((sx * 0.13 + 0.02, -b["head"] * 0.93, -0.0)), cuts=1)
        hl.data.materials.append(m_white)
        parts.append(hl)
    return parts, c


def make_hair(name, b, c, style, m_hair):
    """Cabelo = casca da esfera da cabeça sem a região do rosto (+ mechas)."""
    r = b["head"] * 1.07
    hair = quad_sphere(name, r, c, cuts=4)
    bm = bmesh.new()
    bm.from_mesh(hair.data)
    kill = []
    for f in bm.faces:
        d = f.calc_center_median() - Vector(c)
        long = style == "long"
        if d.y < -r * 0.25:            # frente: abre o rosto abaixo da linha do cabelo
            cut = r * 0.35
        elif d.y > r * 0.2:            # nuca: cobre até embaixo
            cut = -r * (0.95 if long else 0.62)
        else:                          # laterais
            cut = -r * (0.55 if long else 0.3)
        if d.z < cut:
            kill.append(f)
    bmesh.ops.delete(bm, geom=kill, context="FACES")
    bm.to_mesh(hair.data)
    bm.free()
    sol = hair.modifiers.new("sol", "SOLIDIFY")
    sol.thickness = 0.035
    sol.offset = 1.0
    _bake(hair)
    hair.data.materials.append(m_hair)
    _smooth(hair.data)
    parts = [hair]
    cv = Vector(c)
    if style == "long":
        # cabelo comprido atrás (cai até os ombros) + mechas laterais coladas nas bochechas
        parts.append(strand(name + "_back", cv + Vector((0, r * 0.72, -r * 0.1)), r * 1.15, r * 1.3, r * 0.42, m_hair, taper=0.4, lean=(0.0, 0.12)))
        for sx in (-1, 1):
            parts.append(strand(name + "_lock", cv + Vector((sx * r * 0.86, -r * 0.2, r * 0.25)), r * 1.15, r * 0.24, r * 0.24, m_hair, lean=(sx * 0.06, 0.0)))
    else:
        # costeletas curtas
        for sx in (-1, 1):
            parts.append(strand(name + "_side", cv + Vector((sx * r * 0.9, -r * 0.1, r * 0.2)), r * 0.55, r * 0.2, r * 0.22, m_hair))
    # franja: 3 mechas pontudas na testa, seguindo a curvatura
    for x in (-0.4, 0.0, 0.4):
        y = -math.sqrt(max(0.0, 1.0 - x * x)) * r * 0.86
        ln = r * (0.4 if x == 0.0 else 0.5)
        parts.append(strand(name + "_fringe", cv + Vector((x * r, y, r * 0.62)), ln, r * 0.62, r * 0.2, m_hair, taper=0.7, lean=(-x * 0.3, -0.25)))
    return parts


def strand(name, top, length, w, d, material, taper=0.85, lean=(0.0, 0.0)):
    """Mecha em gota: larga na raiz (top), afunila até a ponta. lean = deslocamento (x, y) da ponta / length."""
    obj = quad_sphere(name, 1.0, (0, 0, 0), cuts=2)
    for vert in obj.data.vertices:
        t = (1.0 - vert.co.z) * 0.5                     # 0 na raiz, 1 na ponta
        k = 1.0 - taper * (t ** 1.4)
        vert.co = Vector((vert.co.x * w * 0.5 * k + lean[0] * length * t,
                          vert.co.y * d * 0.5 * k + lean[1] * length * t,
                          -t * length)) + top
    obj.data.materials.append(material)
    return obj


# ---------------------------------------------------------------------------
# skinning
# ---------------------------------------------------------------------------
def skin_auto(obj, rig):
    """Pesos automáticos (bone heat)."""
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    rig.select_set(True)
    bpy.context.view_layer.objects.active = rig
    bpy.ops.object.parent_set(type="ARMATURE_AUTO")


def skin_rigid(obj, rig, bone):
    """Malha inteira presa a um bone (peso 1) — cabeça, cabelo, armas. Continua sendo 'skinned'."""
    vg = obj.vertex_groups.new(name=bone)
    vg.add(range(len(obj.data.vertices)), 1.0, "REPLACE")
    obj.parent = rig
    mod = obj.modifiers.new("rig", "ARMATURE")
    mod.object = rig


def dominant_bone(obj, vert):
    best, w = None, 0.0
    for g in vert.groups:
        if g.weight > w:
            best, w = obj.vertex_groups[g.group].name, g.weight
    return best


# ---------------------------------------------------------------------------
# armaduras conformadas (herdam os pesos do corpo)
# ---------------------------------------------------------------------------
REGIONS = {
    # peça: (bones dominantes, filtro extra por vértice (co, bone) -> bool)
    "torso": ({"hips", "spine", "chest", "upper_arm.R", "upper_arm.L", "thigh.R", "thigh.L", "neck"},
              lambda co, bn: (bn not in ("upper_arm.R", "upper_arm.L") or co.z > Z["upper"] - 0.06)
              and (bn not in ("thigh.R", "thigh.L") or co.z > Z["hip"] - 0.02)
              and (bn != "neck" or co.z < Z["neck"] + 0.02)),
    "legs": ({"thigh.R", "thigh.L", "shin.R", "shin.L", "hips"},
             lambda co, bn: co.z > 0.13 and (bn != "hips" or co.z < Z["pelvis"] + 0.05)),
    "boots": ({"foot.R", "foot.L", "shin.R", "shin.L"}, lambda co, bn: co.z < 0.16),
    "gloves": ({"hand.R", "hand.L", "forearm.R", "forearm.L"},
               lambda co, bn: bn.startswith("hand") or co.z < Z["upper"] - 0.22),
}


def armor_piece(body, rig, name, region, material, push=0.018, thick=0.016, flare=0.0):
    """Copia a região do corpo, empurra pra fora (normal) e dá espessura. flare abre a barra (saia/túnica)."""
    bones, extra = REGIONS[region]
    obj = body.copy()
    obj.data = body.data.copy()
    obj.name = name
    obj.data.name = name + "_mesh"
    obj.modifiers.clear()
    _link(obj)
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    deform = bm.verts.layers.deform.active
    names = {g.index: g.name for g in obj.vertex_groups}
    keep = set()
    for vert in bm.verts:
        bn, w = None, 0.0
        for gi, gw in vert[deform].items():
            if gw > w:
                bn, w = names[gi], gw
        if bn in bones and extra(vert.co, bn):
            keep.add(vert.index)
    kill = [f for f in bm.faces if not all(vv.index in keep for vv in f.verts)]
    bmesh.ops.delete(bm, geom=kill, context="FACES")
    bmesh.ops.delete(bm, geom=[vv for vv in bm.verts if not vv.link_faces], context="VERTS")
    bm.normal_update()
    for vert in bm.verts:
        vert.co += vert.normal * push
        if flare > 0 and vert.co.z < Z["waist"]:
            k = (Z["waist"] - vert.co.z) / (Z["waist"] - Z["hip"] + 0.05)
            vert.co.x *= 1.0 + flare * k
            vert.co.y *= 1.0 + flare * k
    bm.to_mesh(obj.data)
    bm.free()
    obj.data.materials.clear()
    obj.data.materials.append(material)
    obj.parent = None
    sol = obj.modifiers.new("sol", "SOLIDIFY")
    sol.thickness = thick
    sol.offset = 1.0
    sol.use_rim = True
    # o modificador de armature precisa ficar DEPOIS do solidify ao aplicar; aplicamos o solidify agora
    _bake(obj)
    _smooth(obj.data)
    obj.parent = rig
    mod = obj.modifiers.new("rig", "ARMATURE")
    mod.object = rig
    return obj


# ---------------------------------------------------------------------------
# montagem
# ---------------------------------------------------------------------------
def build_base(prefix, sex, offset_x=0.0, hair_color=(0.35, 0.22, 0.15), hair_mat_name=None):
    b = BODIES[sex]
    j = joints(b)
    rig = make_rig(prefix + "_rig", j)
    m_skin = mat("m_skin", SKIN, 0.8)
    m_eye = mat("m_eye", (0.12, 0.09, 0.16), 0.3)
    m_white = mat("m_white", (1, 1, 1), 0.3, 0.5)
    m_hair = mat(hair_mat_name or ("m_hair_" + prefix), hair_color, 0.7)
    body = make_body(prefix + "_body", b, j, m_skin)
    skin_auto(body, rig)
    head_parts, c = make_head(prefix + "_head", b, j, m_skin, m_eye, m_white)
    hair_parts = make_hair(prefix + "_hair", b, c, "long" if sex == "female" else "short", m_hair)
    for p in head_parts + hair_parts:
        skin_rigid(p, rig, "head")
    rig.location.x = offset_x
    return {"rig": rig, "body": body, "sex": sex, "b": b, "j": j, "head_c": c}


def preview():
    clear()
    m = build_base("male", "male", -0.5)
    f = build_base("female", "female", 0.5, (0.85, 0.55, 0.3))
    print("ok:", [o.name for o in bpy.context.scene.objects if o.type == "MESH"].__len__(), "meshes")
    return m, f


# ---------------------------------------------------------------------------
# peças extras
# ---------------------------------------------------------------------------
def transfer_weights(obj, body, rig):
    """Copia os pesos do corpo pela superfície mais próxima (saias, cintos, capas)."""
    for g in body.vertex_groups:
        if obj.vertex_groups.get(g.name) is None:
            obj.vertex_groups.new(name=g.name)
    dt = obj.modifiers.new("dt", "DATA_TRANSFER")
    dt.object = body
    dt.use_vert_data = True
    dt.data_types_verts = {"VGROUP_WEIGHTS"}
    dt.vert_mapping = "POLYINTERP_NEAREST"
    dt.layers_vgroup_select_src = "ALL"
    dt.layers_vgroup_select_dst = "NAME"
    _bake(obj)
    obj.parent = rig
    mod = obj.modifiers.new("rig", "ARMATURE")
    mod.object = rig


def skirt(name, b, body, rig, material, bottom_z, flare=1.7, segs=16, rows=4):
    """Saia/barra de túnica: tubo de quads da cintura até bottom_z, pesos herdados do corpo."""
    top_z = Z["waist"] - 0.02
    r0 = b["waist"] * 1.18
    verts, faces = [], []
    for i in range(rows + 1):
        t = i / rows
        z = top_z + (bottom_z - top_z) * t
        r = r0 * (1.0 + (flare - 1.0) * t ** 1.2)
        for k in range(segs):
            a = 2 * math.pi * k / segs
            verts.append((math.cos(a) * r, math.sin(a) * r * b["depth"] * 1.05, z))
    for i in range(rows):
        for k in range(segs):
            a0, a1 = i * segs + k, i * segs + (k + 1) % segs
            faces.append((a0, a1, a1 + segs, a0 + segs))
    me = bpy.data.meshes.new(name + "_mesh")
    me.from_pydata(verts, [], faces)
    me.update()
    obj = _link(bpy.data.objects.new(name, me))
    sol = obj.modifiers.new("sol", "SOLIDIFY")
    sol.thickness = 0.014
    sub = obj.modifiers.new("sub", "SUBSURF")
    sub.levels = 1
    _bake(obj)
    obj.data.materials.append(material)
    _smooth(obj.data)
    transfer_weights(obj, body, rig)
    return obj


def mesh_from(name, bm, material):
    me = bpy.data.meshes.new(name + "_mesh")
    bm.to_mesh(me)
    bm.free()
    obj = _link(bpy.data.objects.new(name, me))
    obj.data.materials.append(material)
    return obj


def box(name, size, center, material, bevel=0.0):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    for vert in bm.verts:
        vert.co = Vector((vert.co.x * size[0], vert.co.y * size[1], vert.co.z * size[2])) + Vector(center)
    if bevel > 0:
        bmesh.ops.bevel(bm, geom=bm.edges[:], offset=bevel, segments=1, affect="EDGES")
    return mesh_from(name, bm, material)


def tube(name, a, bpt, r_a, r_b, material, segs=8):
    """Cilindro (laterais só de quads) de a até bpt."""
    a, bpt = Vector(a), Vector(bpt)
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=segs, radius1=r_a, radius2=r_b, depth=(bpt - a).length)
    rot = Vector((0, 0, 1)).rotation_difference((bpt - a).normalized()).to_matrix().to_4x4()
    bmesh.ops.transform(bm, matrix=rot, verts=bm.verts)
    for vert in bm.verts:
        vert.co += (a + bpt) * 0.5
    return mesh_from(name, bm, material)


def ball(name, r, center, material, scale=(1, 1, 1)):
    o = quad_sphere(name, r, (0, 0, 0), cuts=2)
    for vert in o.data.vertices:
        vert.co = Vector((vert.co.x * scale[0], vert.co.y * scale[1], vert.co.z * scale[2])) + Vector(center)
    o.data.materials.append(material)
    return o


def _join(objs, name):
    """Junta malhas sem bpy.ops (cada arma vira 1 objeto, multi-material)."""
    bm = bmesh.new()
    mats = []
    for o in objs:
        for m in o.data.materials:
            if m not in mats:
                mats.append(m)
        tmp = o.data.copy()
        for p in tmp.polygons:
            p.material_index = mats.index(o.data.materials[p.material_index])
        bm.from_mesh(tmp)
        bpy.data.meshes.remove(tmp)
        me_old = o.data
        bpy.data.objects.remove(o, do_unlink=True)
        if me_old.users == 0:
            bpy.data.meshes.remove(me_old)
    me = bpy.data.meshes.new(name + "_mesh")
    bm.to_mesh(me)
    bm.free()
    for m in mats:
        me.materials.append(m)
    return _link(bpy.data.objects.new(name, me))


# ---------------------------------------------------------------------------
# armas (rígidas no bone da mão)
# ---------------------------------------------------------------------------
METAL = (0.78, 0.8, 0.86)
GOLD = (0.9, 0.7, 0.3)
WOOD = (0.5, 0.33, 0.2)
LEATHER = (0.42, 0.27, 0.17)


def hand_center(base, side):
    j = base["j"]
    return (Vector(j["wrist" + side]) + Vector(j["hand_tip" + side])) * 0.5


def weapon(base, kind, accent=(0.4, 0.7, 1.0)):
    rig = base["rig"]
    hr = hand_center(base, ".R")
    hl = hand_center(base, ".L")
    m_metal = mat("m_metal", METAL, 0.35)
    m_gold = mat("m_gold", GOLD, 0.4)
    m_wood = mat("m_wood", WOOD, 0.8)
    m_leather = mat("m_leather", LEATHER, 0.8)
    m_accent = mat("m_accent_%.2f%.2f%.2f" % accent, accent, 0.5)
    made = []
    if kind in ("sword", "sword_shield"):
        fwd = Vector((0, -0.55, 0.83)).normalized()        # lâmina pra frente/cima
        g = hr
        # armas de chibi são exageradas (ToS): lâmina larga e longa
        parts = [tube("grip", g - fwd * 0.08, g + fwd * 0.08, 0.026, 0.026, m_leather, 6),
                 ball("pommel", 0.04, g - fwd * 0.1, m_gold),
                 box("guard", (0.26, 0.055, 0.05), g + fwd * 0.1, m_gold, 0.01),
                 tube("blade", g + fwd * 0.12, g + fwd * 0.82, 0.06, 0.02, m_metal, 4)]
        made.append((_join(parts, "w_sword"), "hand.R"))
        if kind == "sword_shield":
            # escudo redondo à frente do antebraço esquerdo, virado pra frente/fora
            c = Vector(base["j"]["wrist.L"]) * 0.55 + Vector(base["j"]["elbow.L"]) * 0.45 + Vector((0.06, -0.09, 0.02))
            sh = ball("shield", 0.23, (0, 0, 0), m_accent, (1.0, 0.22, 1.0))
            boss = ball("boss", 0.065, (0, -0.05, 0), m_gold, (1, 0.6, 1))
            rim = tube("rim", (0, 0.02, 0), (0, -0.03, 0), 0.24, 0.24, m_metal, 16)
            shield = _join([sh, boss, rim], "w_shield")
            rot = Matrix.Rotation(math.radians(-35), 4, "Z")    # gira a face pra fora (+X)
            for vert in shield.data.vertices:
                vert.co = rot @ vert.co + c
            made.append((shield, "forearm.L"))
    elif kind == "axe2h":
        up = Vector((0, -0.25, 1)).normalized()
        g = hr
        parts = [tube("shaft", g - up * 0.18, g + up * 0.75, 0.024, 0.024, m_wood, 6),
                 ball("axehead", 0.2, g + up * 0.66 + Vector((0, -0.12, 0)), m_metal, (0.18, 1.0, 0.85)),
                 box("socket", (0.06, 0.07, 0.12), g + up * 0.66, m_gold, 0.01)]
        made.append((_join(parts, "w_axe"), "hand.R"))
    elif kind in ("staff", "wand"):
        ln = 1.15 if kind == "staff" else 0.42
        g = hr
        up = Vector((-0.22, -0.12, 1.0)).normalized()          # inclinado pra fora do corpo (lado .R = -X)
        top = g + up * (ln * (0.55 if kind == "staff" else 0.75))
        parts = [tube("shaft", g - up * (ln * (0.45 if kind == "staff" else 0.25)), top, 0.022, 0.028, m_wood, 6),
                 tube("cap", top, top + up * 0.05, 0.045, 0.035, m_gold, 8),
                 ball("orb", 0.085 if kind == "staff" else 0.05, top + up * 0.13,
                      mat("m_orb_%.2f%.2f%.2f" % accent, accent, 0.2, 2.0))]
        made.append((_join(parts, "w_" + kind), "hand.R"))
    elif kind == "bow":
        g = hl
        pts = [g + Vector((0.0, -0.12 * (1 - t * t) + 0.02, t * 0.45)) for t in [i / 4 - 1 for i in range(9)]]
        parts = [tube("limb%d" % i, pts[i], pts[i + 1], 0.018, 0.018, m_wood, 6) for i in range(8)]
        parts.append(tube("string", pts[0], pts[-1], 0.004, 0.004, mat("m_string", (0.95, 0.95, 0.9)), 4))
        made.append((_join(parts, "w_bow"), "hand.L"))
    elif kind == "daggers":
        for side in (".R", ".L"):
            g = hand_center(base, side)
            fwd = Vector((0, -1, 0.3)).normalized()
            parts = [tube("grip", g - fwd * 0.05, g + fwd * 0.05, 0.018, 0.018, m_leather, 6),
                     box("guard", (0.1, 0.03, 0.03), g + fwd * 0.06, m_gold, 0.006),
                     tube("blade", g + fwd * 0.07, g + fwd * 0.3, 0.026, 0.006, m_metal, 4)]
            made.append((_join(parts, "w_dagger" + side), "hand" + side))
    elif kind == "scythe":
        g = hr
        top = g + Vector((0, 0, 0.85))
        parts = [tube("shaft", g - Vector((0, 0, 0.3)), top, 0.022, 0.022, mat("m_darkwood", (0.25, 0.2, 0.25), 0.8), 6)]
        prev = top
        for i in range(1, 7):
            a = i / 6
            p = top + Vector((0, -0.55 * a, 0.08 * math.sin(a * math.pi) - 0.18 * a * a))
            parts.append(tube("blade%d" % i, prev, p, 0.05 * (1 - a) + 0.008, 0.05 * (1 - a * 0.9) + 0.006, m_metal, 4))
            prev = p
        made.append((_join(parts, "w_scythe"), "hand.R"))
    out = []
    for obj, bone in made:
        _smooth(obj.data)
        skin_rigid(obj, rig, bone)
        out.append(obj)
    return out


# ---------------------------------------------------------------------------
# conjuntos de armadura
# ---------------------------------------------------------------------------
ARMOR_SETS = {
    # nome: lista de (peça, cor, opções). Peça = região do corpo (REGIONS) | skirt | pauldrons | belt
    "plate": [("torso", (0.75, 0.78, 0.85), dict(push=0.022, flare=0.12)),
              ("skirt", (0.55, 0.15, 0.18), dict(bottom=Z["knee"] + 0.07, flare=1.35)),
              ("legs", (0.3, 0.28, 0.35), dict(push=0.01)),
              ("boots", (0.62, 0.64, 0.7), dict(push=0.022)),
              ("gloves", (0.62, 0.64, 0.7), dict(push=0.01)),
              ("pauldrons", (0.75, 0.78, 0.85), {})],
    "robe": [("torso", (0.95, 0.95, 0.92), dict(push=0.014)),
             ("skirt", (0.95, 0.95, 0.92), dict(bottom=0.08, flare=1.9)),
             ("boots", (0.5, 0.42, 0.6), dict(push=0.014)),
             ("belt", (0.85, 0.68, 0.3), {})],
    "leather": [("torso", (0.45, 0.3, 0.2), dict(push=0.016, flare=0.15)),
                ("legs", (0.32, 0.4, 0.3), dict(push=0.01)),
                ("boots", (0.35, 0.22, 0.14), dict(push=0.02)),
                ("gloves", (0.35, 0.22, 0.14), dict(push=0.007)),
                ("belt", (0.25, 0.17, 0.1), {})],
}


def equip(base, set_name, tint=None):
    """Veste um conjunto. tint (r,g,b) pinta as peças de tecido do conjunto (TINTED) — ex.: cor da classe."""
    rig, body, b = base["rig"], base["body"], base["b"]
    prefix = rig.name.replace("_rig", "")
    out = []
    for piece, color, opt in ARMOR_SETS[set_name]:
        if tint and piece in TINTED.get(set_name, ()):
            color = tint
        m = mat("m_%s_%s_%.2f%.2f%.2f" % (set_name, piece, *color), color, 0.5 if set_name == "plate" else 0.85)
        name = "%s_%s_%s" % (prefix, set_name, piece)
        if piece in REGIONS:
            out.append(armor_piece(body, rig, name, piece, m, opt.get("push", 0.018), 0.016, opt.get("flare", 0.0)))
        elif piece == "skirt":
            out.append(skirt(name, b, body, rig, m, opt["bottom"], opt["flare"]))
        elif piece == "pauldrons":
            for s in (".R", ".L"):
                sh = Vector(base["j"]["shoulder" + s])
                p = ball(name + s, b["arm"] * 1.9, sh + Vector((0, 0, 0.02)), m, (1.1, 1.0, 0.75))
                _smooth(p.data)
                skin_rigid(p, rig, "upper_arm" + s)
                out.append(p)
        elif piece == "belt":
            r = b["waist"] * 1.12
            bt = tube(name, (0, 0, Z["waist"] - 0.035), (0, 0, Z["waist"] + 0.035), r, r, m, 16)
            for vert in bt.data.vertices:
                vert.co.y *= b["depth"] * 1.05
            _smooth(bt.data)
            transfer_weights(bt, body, rig)
            out.append(bt)
    return out


# ---------------------------------------------------------------------------
# animações (nomes que o Godot procura: idle run attack cast hit die block)
# Convenções medidas no rig: membros (apontam pra baixo) -X = balança pra FRENTE;
# coluna/cabeça +X = inclina pra frente; .R +Z = abre pra fora (.L usa -Z); Y = torção.
# ---------------------------------------------------------------------------
## Mãos chaveadas em quaternião: o Euler XYZ por canal passava perto de Y=±90° e a mão dava voltas inteiras entre
## duas poses (600-1900° num clipe de 1 s). Em quaternião (mesmo hemisfério da chave anterior) o caminho é o giro
## mais curto entre as MESMAS poses. O modo vale para todas as actions do osso (o export amostra com ele).
QUAT_BONES = ("hand.R", "hand.L")
HAND_MAX_TURN = 75.0      # graus por quadro (24 fps) entre chaves da mão; acima disso a arma "vira" num piscar (154-176° em 1-2 quadros)


def _reset_pose(rig):
    for pb in rig.pose.bones:
        pb.rotation_mode = "QUATERNION" if pb.name in QUAT_BONES else "XYZ"
        pb.rotation_euler = (0, 0, 0)
        pb.rotation_quaternion = (1, 0, 0, 0)
        pb.location = (0, 0, 0)


def _key_rot(pb, rot, frame, prev):
    """Chave de rotação (graus XYZ); mãos viram quaternião contínuo (prev: osso -> (quadro, quaternião) da chave anterior),
    girando no máximo HAND_MAX_TURN por quadro: a chave seguinte volta a mirar a pose escrita."""
    e = [math.radians(a) for a in rot]
    if pb.name not in QUAT_BONES:
        pb.rotation_mode = "XYZ"
        pb.rotation_euler = e
        pb.keyframe_insert("rotation_euler", frame=frame)
        return
    q = Euler(e, "XYZ").to_quaternion()
    last = prev.get(pb.name)
    if last is not None:
        f0, p = last
        if p.dot(q) < 0.0:
            q.negate()
        ang = math.degrees(p.rotation_difference(q).angle)
        cap = HAND_MAX_TURN * max(1, frame - f0)
        if ang > cap:
            q = p.slerp(q, cap / ang)
    prev[pb.name] = (frame, q.copy())
    pb.rotation_mode = "QUATERNION"
    pb.rotation_quaternion = q
    pb.keyframe_insert("rotation_quaternion", frame=frame)


def _action(rig, name, keys, frame_end):
    """keys = {bone: [(frame, (rx, ry, rz) graus, (lx, ly, lz) | None), ...]} -> Action numa NLA track."""
    ad = rig.animation_data or rig.animation_data_create()
    _reset_pose(rig)
    act = bpy.data.actions.new(name)
    ad.action = act
    prev = {}
    for bone, frames in keys.items():
        pb = rig.pose.bones[bone]
        for frame, rot, loc in sorted(frames, key=lambda k: k[0]):
            _key_rot(pb, rot, frame, prev)
            if loc is not None:
                pb.location = loc
                pb.keyframe_insert("location", frame=frame)
    act.use_frame_range = True
    act.frame_range = (1, frame_end)
    track = ad.nla_tracks.new()
    track.name = name
    strip = track.strips.new(name, 1, act)
    strip.name = name
    ad.action = None
    _reset_pose(rig)
    return act


def animate(rig, style="melee"):
    """style: melee | caster | bow | dagger. Loops: idle, run, block (o jogo marca loop ao carregar)."""
    r = lambda f, x=0, y=0, z=0: (f, (x, y, z), None)
    up = lambda f, x=0, y=0, z=0, h=0.0: (f, (x, y, z), (0, h, 0))     # loc no eixo do bone (hips: Y = cima)
    _action(rig, "idle", {
        "hips": [up(1), up(25, h=0.012), up(49)],
        "spine": [r(1, 2), r(25, 4), r(49, 2)],
        "head": [r(1), r(25, -3, 0, 2), r(49)],
        "upper_arm.R": [r(1, 0, 0, 8), r(25, 3, 0, 11), r(49, 0, 0, 8)],
        "upper_arm.L": [r(1, 0, 0, -8), r(25, 3, 0, -11), r(49, 0, 0, -8)],
        "forearm.R": [r(1, -18), r(49, -18)],
        "forearm.L": [r(1, -18), r(49, -18)],
    }, 49)
    _action(rig, "run", {
        "hips": [up(1), up(5, h=0.035), up(9), up(13, h=0.035), up(17)],
        "spine": [r(1, 12, 6), r(9, 12, -6), r(17, 12, 6)],
        "head": [r(1, -8), r(17, -8)],
        "thigh.R": [r(1, -45), r(9, 38), r(17, -45)],
        "thigh.L": [r(1, 38), r(9, -45), r(17, 38)],
        "shin.R": [r(1, 15), r(5, 25), r(11, 75), r(17, 15)],
        "shin.L": [r(1, 75), r(3, 70), r(9, 15), r(13, 25), r(17, 75)],
        "upper_arm.R": [r(1, 35, 0, 10), r(9, -40, 0, 10), r(17, 35, 0, 10)],
        "upper_arm.L": [r(1, -40, 0, -10), r(9, 35, 0, -10), r(17, -40, 0, -10)],
        "forearm.R": [r(1, -55), r(17, -55)],
        "forearm.L": [r(1, -55), r(17, -55)],
    }, 17)
    attacks = {
        "bow": {"upper_arm.L": [r(1, -85, 0, -5), r(8, -90, 0, -5), r(14, 0, 0, -8)],
                "forearm.L": [r(1, 0), r(14, -18)],
                "upper_arm.R": [r(1, -80, 0, 20), r(6, -85, 0, 40), r(9, -75, 0, 10), r(14, 0, 0, 8)],
                "forearm.R": [r(1, -90), r(6, -110), r(9, -40), r(14, -18)],
                "spine": [r(1, 0, -35), r(9, 0, -40), r(14, 2)]},
        "dagger": {"upper_arm.R": [r(1, 30, 0, 15), r(5, -95, 0, 0), r(14, 0, 0, 8)],
                   "forearm.R": [r(1, -100), r(5, -5), r(14, -18)],
                   "upper_arm.L": [r(1, -40), r(7, 30), r(10, -90), r(14, 0, 0, -8)],
                   "forearm.L": [r(1, -40), r(10, -5), r(14, -18)],
                   "spine": [r(1, 5, 25), r(5, 15, -20), r(10, 15, 20), r(14, 2)]},
        # melee/caster: golpe de cima pra baixo com a mão direita
        "melee": {"upper_arm.R": [r(1, -155, 0, 15), r(5, -25, 0, 5), r(14, 0, 0, 8)],
                  "forearm.R": [r(1, -40), r(5, -5), r(14, -18)],
                  "spine": [r(1, -6, 25), r(5, 18, -22), r(14, 2)],
                  "head": [r(1, -6), r(5, 8), r(14)],
                  "thigh.R": [r(1), r(5, -25), r(14)], "shin.R": [r(1), r(5, 20), r(14)]},
    }
    if style == "all":
        # kit modular: o jogo escolhe a variante pela arma (attack / attack_bow / attack_dagger)
        _action(rig, "attack", attacks["melee"], 14)
        _action(rig, "attack_bow", attacks["bow"], 14)
        _action(rig, "attack_dagger", attacks["dagger"], 14)
    else:
        _action(rig, "attack", attacks.get(style, attacks["melee"]), 14)
    _action(rig, "cast", {
        "upper_arm.R": [r(1, 0, 0, 8), r(6, -110, 0, 20), r(16, -85, 0, 10)],
        "upper_arm.L": [r(1, 0, 0, -8), r(6, -110, 0, -20), r(16, -85, 0, -10)],
        "forearm.R": [r(1, -18), r(6, -10), r(16, -15)],
        "forearm.L": [r(1, -18), r(6, -10), r(16, -15)],
        "spine": [r(1, 2), r(6, -10), r(16, 4)],
        "head": [r(1), r(6, -12), r(16)],
    }, 16)
    _action(rig, "hit", {
        "spine": [r(1, -22), r(9, 2)],
        "head": [r(1, -25, 0, 8), r(9)],
        "upper_arm.R": [r(1, 20, 0, 30), r(9, 0, 0, 8)],
        "upper_arm.L": [r(1, 20, 0, -30), r(9, 0, 0, -8)],
    }, 9)
    _action(rig, "die", {
        "root": [(1, (0, 0, 0), (0, 0, 0)), (10, (-60, 0, 0), (0, 0.02, -0.05)), (20, (-88, 0, 0), (0, 0.0, -0.1))],
        "spine": [r(1), r(20, -10)],
        "head": [r(1), r(20, -20, 0, 25)],
        "upper_arm.R": [r(1), r(14, -30, 0, 70)],
        "upper_arm.L": [r(1), r(14, -30, 0, -70)],
        "thigh.R": [r(1), r(20, -15)], "shin.R": [r(1), r(20, 30)],
    }, 20)
    _action(rig, "block", {
        "spine": [r(1, 8), r(25, 10), r(49, 8)],
        "upper_arm.L": [r(1, -75, 0, -15), r(49, -75, 0, -15)],
        "forearm.L": [r(1, -70), r(49, -70)],
        "upper_arm.R": [r(1, 15, 0, 15), r(49, 15, 0, 15)],
        "forearm.R": [r(1, -40), r(49, -40)],
        "thigh.R": [r(1, -15), r(49, -15)], "shin.R": [r(1, 20), r(49, 20)],
        "thigh.L": [r(1, 12), r(49, 12)],
    }, 49)


# ---------------------------------------------------------------------------
# animações de combate v2: poses completas (todo bone em todo key) a partir de uma base "em guarda".
# Cada golpe: antecipação -> impacto rápido -> follow-through -> volta à guarda.
# O jogo lê o frame de impacto de IMPACT e acelera/desacelera o clip para o impacto bater
# com o momento do dano da skill (startup).
# Convenções (medidas): membros -X = pra frente/cima; coluna +X = inclina pra frente;
# coluna +Y = gira o peito pra ESQUERDA do personagem (-Y = pro lado da espada);
# braço .R levantado: +Y = mão pra fora (direita), -Y = cruza pra esquerda; antebraço -X = dobra o cotovelo.
# ---------------------------------------------------------------------------
FPS = 24
POSE_BONES = ["root", "hips", "spine", "chest", "neck", "head", "upper_arm.R", "forearm.R", "hand.R",
              "upper_arm.L", "forearm.L", "hand.L", "thigh.R", "shin.R", "foot.R", "thigh.L", "shin.L", "foot.L"]
READY = {"spine": (6, 0, 0), "head": (-4, 0, 0),
         "upper_arm.R": (-30, 10, 0), "forearm.R": (-35, 0, 0), "hand.R": (60, 0, -30),
         "upper_arm.L": (-12, 0, -14), "forearm.L": (-40, 0, 0),
         "thigh.R": (-10, 0, 0), "shin.R": (14, 0, 0), "thigh.L": (8, 0, 0), "shin.L": (10, 0, 0)}
# frame (1-based) do impacto de cada golpe
IMPACT = {"atk_1h_a": 7, "atk_1h_b": 7, "atk_2h": 10, "atk_dual_a": 5, "atk_dual_b": 5, "atk_dagger": 5,
          "atk_bow": 8, "atk_staff": 7, "atk_spin": 8, "atk_thrust": 6, "cast": 10, "cast_buff": 8}


# Cabeça enorme: tronco dobrado demais vira a cabeça de ponta-cabeça e giro demais esconde braço e arma.
TAMED_CLIPS = ("atk_1h", "atk_2h", "atk_dual", "atk_dagger", "atk_thrust", "atk_staff", "atk_bow", "atk_shoot", "atk_leap", "atk_charge", "atk_throw",
               "atk_sweep", "atk_finisher", "atk_flurry", "atk_claw", "shout", "cast", "summon", "buff")
BODY_PITCH = (-14.0, 26.0)      # inclinação somada de spine + chest (frente positiva)
BODY_YAW = 40.0                 # giro somado de spine + chest
HEAD_PITCH = (-12.0, 12.0)      # para onde a cabeça aponta no fim
HEAD_YAW = 14.0


def _clamp(v, lo, hi):
    return max(lo, min(hi, v))


def _tame(pose, base):
    """Limita tronco e faz a cabeça compensar (continua olhando pra frente)."""
    get = lambda bn: pose.get(bn, base.get(bn, (0, 0, 0)))
    sp, ch, hd = get("spine"), get("chest"), get("head")
    pitch, yaw = sp[0] + ch[0], sp[1] + ch[1]
    kp = _clamp(pitch, *BODY_PITCH) / pitch if abs(pitch) > 0.01 else 1.0
    ky = _clamp(yaw, -BODY_YAW, BODY_YAW) / yaw if abs(yaw) > 0.01 else 1.0
    sp2 = (sp[0] * kp, sp[1] * ky, sp[2])
    ch2 = (ch[0] * kp, ch[1] * ky, ch[2])
    bp, by = sp2[0] + ch2[0], sp2[1] + ch2[1]
    hd2 = (_clamp(bp + hd[0], *HEAD_PITCH) - bp, _clamp(by + hd[1], -HEAD_YAW, HEAD_YAW) - by, hd[2])
    return dict(pose, spine=sp2, chest=ch2, head=hd2)


def _pose_action(rig, name, keys, frame_end, base=None):
    """keys = [(frame, {bone: (rx, ry, rz)}, hips_loc | None)]. Bones ausentes usam `base` (guarda)."""
    base = READY if base is None else base
    ad = rig.animation_data or rig.animation_data_create()
    for t in list(ad.nla_tracks):        # substitui clip de mesmo nome (ex.: "hit" de animate())
        if t.name == name:
            ad.nla_tracks.remove(t)
    act = bpy.data.actions.new(name)
    ad.action = act
    prev = {}
    for frame, pose, hips_loc in sorted(keys, key=lambda k: k[0]):
        if name.startswith(TAMED_CLIPS):
            pose = _tame(pose, base)
        for bn in POSE_BONES:
            pb = rig.pose.bones.get(bn)
            if pb is None:
                continue
            _key_rot(pb, pose.get(bn, base.get(bn, (0, 0, 0))), frame, prev)
        hp = rig.pose.bones["hips"]
        hp.location = hips_loc if hips_loc is not None else (0, 0, 0)
        hp.keyframe_insert("location", frame=frame)
    act.use_frame_range = True
    act.frame_range = (1, frame_end)
    track = ad.nla_tracks.new()
    track.name = name
    strip = track.strips.new(name, 1, act)
    strip.name = name
    ad.action = None
    _reset_pose(rig)
    return act


def _mirror(pose):
    """Espelha uma pose (direita <-> esquerda): troca .R/.L e inverte Y/Z."""
    out = {}
    for bn, (x, y, z) in pose.items():
        if bn.endswith(".R"):
            nb = bn[:-2] + ".L"
        elif bn.endswith(".L"):
            nb = bn[:-2] + ".R"
        else:
            nb = bn
        out[nb] = (x, -y, -z)
    return out


def animate_combat(rig):
    """Golpes por família de arma + magias + giro/estocada de skills. Chama depois de animate(rig, 'all')."""
    R = READY
    # --- 1 mão: corte horizontal (direita -> esquerda) e revés (esquerda -> direita): combo de 2 ---
    slash_wind = {"spine": (2, -38, 0), "head": (-4, 22, 0), "upper_arm.R": (-70, 70, 0), "forearm.R": (-70, 0, 0),
                  "hand.R": (45, 90, -60), "upper_arm.L": (-35, 0, -25), "forearm.L": (-55, 0, 0)}
    slash_hit = {"spine": (14, 34, 0), "head": (-2, -18, 0), "upper_arm.R": (-50, 10, 0), "forearm.R": (-70, 0, 0),
                 "hand.R": (75, 90, -75), "upper_arm.L": (-10, 0, -35), "forearm.L": (-30, 0, 0),
                 "thigh.R": (-32, 0, 0), "shin.R": (26, 0, 0), "thigh.L": (18, 0, 0), "shin.L": (14, 0, 0)}
    slash_follow = {"spine": (12, 44, 0), "head": (-2, -24, 0), "upper_arm.R": (-80, -40, 0), "forearm.R": (-5, 0, 0), "hand.R": (60, 75, -75),
                    "upper_arm.L": (-8, 0, -30), "thigh.R": (-30, 0, 0), "shin.R": (24, 0, 0), "thigh.L": (16, 0, 0)}
    # meio do arco: lâmina horizontal à frente-direita (sem passar por trás do corpo)
    slash_mid = dict(slash_hit)
    slash_mid.update({"spine": (8, -5, 0), "head": (-3, 6, 0), "upper_arm.R": (-90, 40, 0), "forearm.R": (-20, 0, 0), "hand.R": (60, 90, -60)})
    _pose_action(rig, "atk_1h_a", [(1, R, None), (4, slash_wind, (0, 0, -0.03)), (6, slash_mid, (0, -0.01, 0.04)), (7, slash_hit, (0, -0.02, 0.07)),
                                   (10, slash_follow, (0, -0.02, 0.06)), (16, R, None)], 16)
    back_wind = {"spine": (4, 36, 0), "head": (-4, -20, 0), "upper_arm.R": (-110, -50, 0), "forearm.R": (-5, 0, 0),
                 "hand.R": (90, 45, -60), "upper_arm.L": (-15, 0, -30)}
    back_hit = {"spine": (12, -30, 0), "head": (-2, 16, 0), "upper_arm.R": (-100, -30, 0), "forearm.R": (-5, 0, 0),
                "hand.R": (-15, 45, -75), "upper_arm.L": (-30, 0, -15), "forearm.L": (-50, 0, 0),
                "thigh.L": (-28, 0, 0), "shin.L": (24, 0, 0), "thigh.R": (14, 0, 0)}
    back_follow = {"spine": (10, -40, 0), "upper_arm.R": (-40, 30, 0), "forearm.R": (-50, 0, 0), "hand.R": (-90, -45, -75), "thigh.L": (-26, 0, 0), "shin.L": (22, 0, 0)}
    back_mid = dict(back_hit)
    back_mid.update({"spine": (8, 5, 0), "upper_arm.R": (-110, -40, 0), "forearm.R": (-5, 0, 0), "hand.R": (30, 75, -75)})
    _pose_action(rig, "atk_1h_b", [(1, R, None), (4, back_wind, (0, 0, -0.02)), (6, back_mid, (0, -0.01, 0.04)), (7, back_hit, (0, -0.02, 0.06)),
                                   (10, back_follow, (0, -0.02, 0.05)), (16, R, None)], 16)
    # --- 2 mãos: golpe de cima pra baixo, as duas mãos na arma ---
    over_wind = {"spine": (-18, -8, 0), "head": (-14, 0, 0), "upper_arm.R": (-150, 20, 0), "forearm.R": (-5, 0, 0),
                 "hand.R": (75, 30, -30), "upper_arm.L": (-150, -28, 0), "forearm.L": (-8, 0, 0),
                 "thigh.R": (-6, 0, 0), "thigh.L": (12, 0, 0)}
    over_hit = {"spine": (34, 4, 0), "head": (10, 0, 0), "upper_arm.R": (-80, 0, 0), "forearm.R": (-5, 0, 0),
                "hand.R": (45, 90, -75), "upper_arm.L": (-80, -18, 0), "forearm.L": (-10, 0, 0),
                "thigh.R": (-42, 0, 0), "shin.R": (48, 0, 0), "thigh.L": (28, 0, 0), "shin.L": (30, 0, 0)}
    _pose_action(rig, "atk_2h", [(1, R, None), (7, over_wind, (0, 0.04, -0.04)), (10, over_hit, (0, -0.09, 0.1)),
                                 (14, over_hit, (0, -0.09, 0.1)), (20, R, None)], 20)
    # --- duas armas: corte rápido da direita e da esquerda (alternados no jogo) ---
    dual_r_wind = {"spine": (4, -30, 0), "upper_arm.R": (-70, 60, 0), "forearm.R": (-70, 0, 0),
                   "upper_arm.L": (-60, 0, -20), "forearm.L": (-80, 0, 0)}
    dual_r_hit = {"spine": (12, 28, 0), "upper_arm.R": (-85, -45, 0), "forearm.R": (-10, 0, 0),
                  "upper_arm.L": (-50, 0, -30), "forearm.L": (-90, 0, 0), "thigh.R": (-28, 0, 0), "shin.R": (22, 0, 0)}
    _pose_action(rig, "atk_dual_a", [(1, R, None), (3, dual_r_wind, None), (5, dual_r_hit, (0, -0.02, 0.06)), (12, R, None)], 12)
    _pose_action(rig, "atk_dual_b", [(1, R, None), (3, _mirror(dual_r_wind), None), (5, _mirror(dual_r_hit), (0, -0.02, 0.06)), (12, R, None)], 12)
    # --- adaga: estocada ---
    stab_back = {"spine": (0, -22, 0), "upper_arm.R": (0, 90, 0), "forearm.R": (-70, 0, 0), "hand.R": (-30, -90, 75),
                 "upper_arm.L": (-45, 0, -20)}
    stab_hit = {"spine": (14, 22, 0), "upper_arm.R": (-80, 10, 0), "forearm.R": (-5, 0, 0), "hand.R": (90, 60, -15),
                "upper_arm.L": (5, 0, -25), "thigh.R": (-36, 0, 0), "shin.R": (30, 0, 0), "thigh.L": (20, 0, 0)}
    _pose_action(rig, "atk_dagger", [(1, R, None), (3, stab_back, (0, 0, -0.03)), (5, stab_hit, (0, -0.03, 0.1)),
                                     (8, stab_hit, (0, -0.03, 0.09)), (12, R, None)], 12)
    _pose_action(rig, "atk_thrust", [(1, R, None), (3, stab_back, (0, -0.04, -0.05)), (6, stab_hit, (0, -0.05, 0.16)),
                                     (10, stab_hit, (0, -0.05, 0.14)), (16, R, None)], 16)
    # --- arco: corpo de lado, braço esquerdo estica o arco, direito puxa a corda e solta ---
    # (resolvido numericamente: arco vertical com a barriga pra frente; mão direita na corda -> bochecha)
    bow_aim = {"spine": (2, 40, 0), "head": (0, -38, 0), "upper_arm.L": (-85, 30, 30), "forearm.L": (0, 0, 0),
               "hand.L": (90, 30, 0), "upper_arm.R": (-70, 30, 0), "forearm.R": (-80, 0, 0),
               "thigh.R": (14, 0, 0), "thigh.L": (-16, 0, 0), "shin.L": (14, 0, 0)}
    bow_draw = dict(bow_aim)
    bow_draw.update({"upper_arm.R": (-90, -90, 0), "forearm.R": (-110, 0, 0), "spine": (-4, 44, 0)})
    bow_release = dict(bow_aim)
    bow_release.update({"upper_arm.R": (-80, -40, 0), "forearm.R": (-55, 0, 0), "spine": (-2, 46, 0)})
    _pose_action(rig, "atk_bow", [(1, R, None), (4, bow_aim, None), (7, bow_draw, None), (8, bow_release, (0, 0.01, -0.02)),
                                  (11, bow_release, None), (16, R, None)], 16)
    # --- cajado/varinha: puxa e projeta a arma pra frente (projétil mágico) ---
    staff_wind = {"spine": (-8, -24, 0), "upper_arm.R": (-110, 80, 0), "forearm.R": (-60, 0, 0), "hand.R": (90, 90, -45),
                  "upper_arm.L": (-40, 0, -25), "forearm.L": (-60, 0, 0)}
    staff_hit = {"spine": (12, 16, 0), "upper_arm.R": (-110, 20, 0), "forearm.R": (-5, 0, 0), "hand.R": (90, 60, -45),
                 "upper_arm.L": (-70, 0, -10), "forearm.L": (-10, 0, 0), "thigh.R": (-24, 0, 0), "shin.R": (20, 0, 0)}
    _pose_action(rig, "atk_staff", [(1, R, None), (4, staff_wind, None), (7, staff_hit, (0, 0, 0.05)), (10, staff_hit, (0, 0, 0.04)),
                                    (16, R, None)], 16)
    # --- magia em área: ergue as mãos e empurra pra frente ---
    cast_up = {"spine": (-14, 0, 0), "head": (-16, 0, 0), "upper_arm.R": (-155, 0, 28), "forearm.R": (-22, 0, 0),
               "upper_arm.L": (-155, 0, -28), "forearm.L": (-22, 0, 0)}
    cast_hit = {"spine": (16, 0, 0), "head": (4, 0, 0), "upper_arm.R": (-78, 0, 10), "forearm.R": (-4, 0, 0),
                "upper_arm.L": (-78, 0, -10), "forearm.L": (-4, 0, 0), "thigh.R": (-22, 0, 0), "shin.R": (18, 0, 0)}
    _pose_action(rig, "cast", [(1, R, None), (6, cast_up, (0, 0.03, 0)), (10, cast_hit, (0, -0.02, 0.05)), (13, cast_hit, None),
                               (20, R, None)], 20)
    # --- buff/cura: braços abertos pro alto ---
    buff_up = {"spine": (-16, 0, 0), "head": (-22, 0, 0), "upper_arm.R": (-150, 0, 50), "forearm.R": (-15, 0, 0),
               "upper_arm.L": (-150, 0, -50), "forearm.L": (-15, 0, 0)}
    _pose_action(rig, "cast_buff", [(1, R, None), (8, buff_up, (0, 0.05, 0)), (12, buff_up, (0, 0.05, 0)), (18, R, None)], 18)
    # --- giro (skills físicas em volta de si) ---
    spin_arms = {"spine": (10, 0, 0), "upper_arm.R": (-82, 70, 0), "forearm.R": (-10, 0, 0),
                 "upper_arm.L": (-60, -50, 0), "forearm.L": (-20, 0, 0), "thigh.R": (-20, 0, 0), "shin.R": (20, 0, 0)}
    keys = [(1, R, None), (3, dict(spin_arms, root=(0, 0, 0)), (0, -0.04, 0))]
    for i, ang in enumerate((-120, -240, -360)):
        keys.append((3 + (i + 1) * 3, dict(spin_arms, root=(0, ang, 0)), (0, -0.04, 0)))
    keys.append((16, dict(R, root=(0, -360, 0)), None))
    _pose_action(rig, "atk_spin", keys, 16)
    # --- reações ---
    hit = {"spine": (-22, 8, 0), "head": (-28, 0, 10), "upper_arm.R": (10, 0, 35), "forearm.R": (-60, 0, 0),
           "upper_arm.L": (10, 0, -35), "forearm.L": (-60, 0, 0), "thigh.R": (12, 0, 0)}
    _pose_action(rig, "hit", [(1, R, None), (3, hit, (0, 0, -0.08)), (9, R, None)], 9)


# ---------------------------------------------------------------------------
# animações v3: ciclos procedurais (seno com fases defasadas = movimento sobreposto) para idle/corrida,
# pulo/queda/pouso, dash, reações com mais quadros e golpes com antecipação + acomodação.
# Os frames de impacto (IMPACT) não mudam: o tempo de dano do jogo continua igual.
# ---------------------------------------------------------------------------
def _add(a, b):
    return tuple(x + y for x, y in zip(a, b))


def _blend(a, b, w):
    """Pose entre a e b (w=0 -> a, w=1 -> b); bones ausentes usam READY."""
    out = {}
    for bn in set(a) | set(b):
        pa = a.get(bn, READY.get(bn, (0, 0, 0)))
        pb = b.get(bn, READY.get(bn, (0, 0, 0)))
        out[bn] = tuple(x + (y - x) * w for x, y in zip(pa, pb))
    return out


def _cycle(rig, name, frames, pose_at, step=2):
    """Ciclo fechado: amostra pose_at(fase 0..2π) a cada `step` frames; o último frame = o primeiro."""
    keys = []
    f = 1
    while f <= frames + 1:
        ph = math.tau * (f - 1) / frames
        pose, hips = pose_at(ph)
        keys.append((f, pose, hips))
        f += step
    if keys[-1][0] != frames + 1:
        pose, hips = pose_at(math.tau)
        keys.append((frames + 1, pose, hips))
    _pose_action(rig, name, keys, frames + 1, base={})


def _idle_pose(ph):
    s, s2 = math.sin(ph), math.sin(2 * ph)
    p = {
        "hips": (0, 2 * s, 0),
        "spine": (6 + 1.5 * math.sin(ph + 0.4), -2 * s, 0),
        "chest": (2.5 * math.sin(ph + 0.8), -1.5 * s, 0),          # respiração
        "neck": (0, 0, 0),
        "head": (-4 - 2 * math.sin(ph + 1.2), 5 * math.sin(ph * 1 + 2.0), 1.5 * s),
        "upper_arm.R": _add(READY["upper_arm.R"], (3 * math.sin(ph + 0.9), 0, 0)),
        "forearm.R": _add(READY["forearm.R"], (-4 * math.sin(ph + 1.3), 0, 0)),
        "hand.R": READY["hand.R"],
        "upper_arm.L": _add(READY["upper_arm.L"], (3 * math.sin(ph + 1.1), 0, -2 * math.sin(ph + 1.4))),
        "forearm.L": _add(READY["forearm.L"], (-5 * math.sin(ph + 1.5), 0, 0)),
        "hand.L": (0, 0, 0),
        "thigh.R": _add(READY["thigh.R"], (-2 * s, 0, 0)), "shin.R": _add(READY["shin.R"], (3 * s, 0, 0)),
        "thigh.L": _add(READY["thigh.L"], (2 * s, 0, 0)), "shin.L": _add(READY["shin.L"], (2 * s, 0, 0)),
        "foot.R": (0, 0, 0), "foot.L": (0, 0, 0),
    }
    return p, (0.012 * s, -0.012 + 0.008 * s2, 0)


def _run_pose(ph):
    s, c = math.sin(ph), math.cos(ph)
    swing_r = max(0.0, c) ** 1.4           # perna direita passando pra frente (no ar)
    swing_l = max(0.0, -c) ** 1.4
    p = {
        "root": (0, 0, 0),
        "hips": (0, 9 * s, 3 * c),
        "spine": (20, -15 * s, 0),
        "chest": (4, -7 * s, -2 * c),
        "neck": (0, 4 * s, 0),
        "head": (-12, 14 * s, 2 * c),          # cabeça estável olhando pra frente
        # pernas curtas do chibi: passada ampla (±62°) e joelho bem dobrado na volta
        "thigh.R": (-62 * s, 0, 0), "shin.R": (16 + 100 * swing_r, 0, 0), "foot.R": (-26 * swing_r + 18 * max(0.0, -s), 0, 0),
        "thigh.L": (62 * s, 0, 0), "shin.L": (16 + 100 * swing_l, 0, 0), "foot.L": (-26 * swing_l + 18 * max(0.0, s), 0, 0),
        # braço da arma balança pouco (lâmina estável, em guarda); o do escudo balança mais
        "upper_arm.R": (READY["upper_arm.R"][0] + 18 * s, 14, 0), "forearm.R": (-55 + 8 * c, 0, 0), "hand.R": READY["hand.R"],
        "upper_arm.L": (-46 * s - 14, -14, 0), "forearm.L": (-62 - 16 * c, 0, 0), "hand.L": (0, 0, 0),
    }
    return p, (0, 0.03 * math.cos(2 * ph) - 0.012, 0)


def _rolled(euler_deg, roll_deg):
    """Euler (graus) com um giro extra no eixo do osso."""
    q = Euler(tuple(math.radians(a) for a in euler_deg), "XYZ").to_quaternion() @ Quaternion((0, 1, 0), math.radians(roll_deg))
    return tuple(math.degrees(a) for a in q.to_euler("XYZ"))


def _block_pose(ph):
    s = math.sin(ph)
    p = {
        "spine": (10 + 1.5 * s, -6, 0), "chest": (2 * math.sin(ph + 0.6), 0, 0), "head": (-2, 4, 0),
        "upper_arm.L": (-58 + 2 * s, -22, 0), "forearm.L": (-78, 0, 0), "hand.L": (0, 0, 0),
        "upper_arm.R": (-74 + 2 * s, 34, 0), "forearm.R": (-62 - 3 * s, 0, 0), "hand.R": (150, 0, -60),
        "thigh.R": (-20, 0, 0), "shin.R": (26 + 2 * s, 0, 0), "thigh.L": (14, 0, 0), "shin.L": (14, 0, 0),
    }
    return p, (0, -0.035 - 0.006 * s, 0)


def _shield_guard_pose(ph):
    """Guarda de escudo: antebraço atravessado na frente do peito, escudo de pé com a face para o golpe. Corpo atrás do escudo,
    peso no pé de trás. Braço achado por busca no rig (tools/blender/shield_mount.py --guard): face à frente, sem tocar tronco/cabeça."""
    s = math.sin(ph)
    p = {
        "spine": (12 + 1.5 * s, -10, 0), "chest": (3 + 2 * math.sin(ph + 0.6), -6, 0), "head": (-4, 8, 0),
        "upper_arm.L": (-60 + 2 * s, 22.5, -37.5), "forearm.L": _rolled((-67.5, 0, 0), -15), "hand.L": (0, 0, 0),
        "upper_arm.R": (-40, 25, 0), "forearm.R": (-45 - 3 * s, 0, 0), "hand.R": READY["hand.R"],
        "thigh.R": (-24, 0, 0), "shin.R": (30 + 2 * s, 0, 0), "thigh.L": (18, 0, 0), "shin.L": (16, 0, 0),
    }
    return p, (0, -0.05 - 0.006 * s, 0)


def animate_v3(rig):
    """Chama depois de animate(rig, 'all') e animate_combat(rig): substitui/adiciona clipes."""
    R = READY
    _cycle(rig, "idle", 48, _idle_pose, step=3)
    _cycle(rig, "run", 16, _run_pose, step=1)
    _cycle(rig, "block", 32, _block_pose, step=4)
    _cycle(rig, "block_shield", 32, _shield_guard_pose, step=4)
    # tiro de mosquete: mira no ombro (braços à frente, cabeça encostada), coice para trás e volta
    aim = {"spine": (4, 0, 0), "head": (-2, -10, 0), "upper_arm.R": (-80, 10, 0), "forearm.R": (-20, 0, 0), "hand.R": (0, 0, 0),
           "upper_arm.L": (-75, -35, 0), "forearm.L": (-30, 0, 0), "thigh.R": (-12, 0, 0), "shin.R": (16, 0, 0), "thigh.L": (10, 0, 0), "shin.L": (12, 0, 0)}
    kick = dict(aim, **{"spine": (-8, 0, 0), "head": (-8, -10, 0), "upper_arm.R": (-95, 12, 0), "upper_arm.L": (-88, -35, 0)})
    _pose_action(rig, "atk_rifle", [(1, R, None), (4, aim, (0, 0.01, 0)), (6, kick, (0, 0.04, 0)), (9, aim, (0, 0.01, 0)), (13, R, None)], 13)
    # --- pulo: impulso (pernas estendem, braços sobem) -> encolhe no alto ---
    # braços sobem PRA FORA (Z abre), não na frente do rosto; no alto, encolhe as pernas
    push = {"spine": (-8, 0, 0), "head": (-16, 0, 0), "thigh.R": (-6, 0, 0), "shin.R": (4, 0, 0), "thigh.L": (8, 0, 0),
            "shin.L": (4, 0, 0), "foot.R": (34, 0, 0), "foot.L": (34, 0, 0),
            **ARM_V}
    tuck = {"spine": (20, 0, 0), "head": (-10, 0, 0), "thigh.R": (-80, 0, 0), "shin.R": (108, 0, 0), "thigh.L": (-50, 0, 0),
            "shin.L": (96, 0, 0), "foot.R": (-14, 0, 0), "foot.L": (-14, 0, 0),
            **ARM_SIDE}
    _pose_action(rig, "jump", [(1, _blend(R, push, 0.6), (0, -0.04, 0)), (3, push, (0, 0.02, 0)), (8, tuck, (0, 0.06, 0)),
                               (12, tuck, (0, 0.06, 0))], 12)
    # --- queda (loop): pernas se esticam pro pouso, braços abertos balançando ---
    fall_a = {"spine": (6, 0, 0), "head": (6, 0, 0), "thigh.R": (-34, 0, 0), "shin.R": (40, 0, 0), "thigh.L": (-12, 0, 0),
              "shin.L": (28, 0, 0), **ARM_SIDE}
    fall_b = dict(fall_a, **_blend(ARM_SIDE, ARM_V, 0.35), **{"thigh.R": (-28, 0, 0), "thigh.L": (-18, 0, 0)})
    _pose_action(rig, "fall", [(1, fall_a, None), (7, fall_b, None), (13, fall_a, None)], 13)
    # --- pouso: amortece (agacha) e volta à guarda ---
    crouch = {"spine": (26, 0, 0), "head": (-14, 0, 0), "thigh.R": (-56, 0, 0), "shin.R": (82, 0, 0), "foot.R": (-24, 0, 0),
              "thigh.L": (-38, 0, 0), "shin.L": (70, 0, 0), "foot.L": (-26, 0, 0),
              **ARM_FRONT}
    _pose_action(rig, "land", [(1, crouch, (0, -0.16, 0.02)), (3, crouch, (0, -0.18, 0.02)), (6, _blend(crouch, R, 0.7), (0, -0.05, 0)),
                               (8, R, None)], 8)
    # --- dash: inclina baixo pra frente, braços pra trás (ninja), pernas em tesoura ---
    dash = {"spine": (34, 0, 0), "chest": (8, 0, 0), "head": (-24, 0, 0), "thigh.R": (-50, 0, 0), "shin.R": (60, 0, 0),
            "thigh.L": (40, 0, 0), "shin.L": (50, 0, 0), "upper_arm.R": (60, 0, 0), "forearm.R": (-20, 0, 0),
            "upper_arm.L": (60, 0, 0), "forearm.L": (-20, 0, 0)}
    _pose_action(rig, "dash", [(1, _blend(R, dash, 0.5), (0, -0.04, 0.04)), (3, dash, (0, -0.1, 0.1)), (7, dash, (0, -0.1, 0.1)),
                               (10, _blend(dash, R, 0.6), (0, -0.04, 0.02))], 10)
    # --- reação a golpe: estalo pra trás, recua e se recompõe com pequeno balanço ---
    hit = {"spine": (-24, 10, 0), "chest": (-6, 0, 0), "head": (-30, -8, 12), "upper_arm.R": (10, 0, 38), "forearm.R": (-62, 0, 0),
           "upper_arm.L": (12, 0, -36), "forearm.L": (-62, 0, 0), "thigh.R": (14, 0, 0), "shin.R": (20, 0, 0), "thigh.L": (-10, 0, 0)}
    _pose_action(rig, "hit", [(1, R, None), (2, _blend(R, hit, 0.8), (0, 0, -0.06)), (3, hit, (0, -0.02, -0.1)),
                              (6, _blend(hit, R, 0.55), (0, -0.01, -0.05)), (8, _blend(R, hit, -0.12), None), (11, R, None)], 11)
    # --- morte: cambaleia, os joelhos cedem, cai de costas e assenta ---
    stagger = dict(hit, **{"spine": (-14, 18, 0)})
    kneel = {"spine": (18, 10, 0), "head": (20, 0, 8), "thigh.R": (-70, 0, 0), "shin.R": (110, 0, 0), "thigh.L": (-50, 0, 0),
             "shin.L": (95, 0, 0), "upper_arm.R": (20, 0, 0), "forearm.R": (-30, 0, 0), "upper_arm.L": (20, 0, 0), "forearm.L": (-30, 0, 0)}
    down = {"root": (-86, 0, 6), "spine": (-8, 0, 0), "head": (-18, 20, 25), "thigh.R": (-30, 0, 0), "shin.R": (40, 0, 0),
            "thigh.L": (-10, 0, 0), "shin.L": (14, 0, 0), "upper_arm.R": (-80, 80, 0), "forearm.R": (-10, 0, 0),
            "upper_arm.L": (-70, -85, 0), "forearm.L": (-25, 0, 0)}
    bounce = dict(down, **{"root": (-80, 0, 6), "head": (-10, 20, 25)})
    _pose_action(rig, "die", [(1, R, None), (4, stagger, (0, 0, -0.08)), (11, kneel, (0, -0.32, 0.04)),
                              (19, down, (0, -0.05, -0.12)), (22, bounce, (0, -0.03, -0.12)), (26, down, (0, -0.05, -0.12)),
                              (30, down, (0, -0.05, -0.12))], 30)
    _settle_attacks(rig)
    _ranged_and_magic(rig)
    _skill_clips(rig)
    _family_clips(rig)


# Poses de braço resolvidas numericamente (busca em grade no rig: mão no alvo, antebraço -15°).
# hand.R: também resolvido (a arma da mão direita continua apontando pra cima/frente em cada pose).
# Chibi: ombro a 0,83 m, topo da cabeça a 1,65 m, braço ~0,3 m -> "braços pro alto" = V ao lado da cabeça.
ARM_V = {"upper_arm.R": (160, -60, -30), "forearm.R": (-15, 0, 0), "hand.R": (-135, -15, -15), "upper_arm.L": (160, 60, 30), "forearm.L": (-15, 0, 0)}
ARM_FRONT = {"upper_arm.R": (-90, 10, -30), "forearm.R": (-15, 0, 0), "hand.R": (-150, 165, -15), "upper_arm.L": (-90, -10, 30), "forearm.L": (-15, 0, 0)}
ARM_SIDE = {"upper_arm.R": (140, -70, -60), "forearm.R": (-15, 0, 0), "hand.R": (90, -150, -60), "upper_arm.L": (140, 70, 60), "forearm.L": (-15, 0, 0)}
ARM_CHEST = {"upper_arm.R": (-80, -30, 30), "forearm.R": (-15, 0, 0), "hand.R": (-60, -180, -60), "upper_arm.L": (-80, 30, -30), "forearm.L": (-15, 0, 0)}


def _ranged_and_magic(rig):
    """Arco (arco na mão ESQUERDA, direita puxa a corda), cajado/varinha e magias, com poses mais legíveis.
    Braço levantado: +Y abre o .R pra fora, -Y abre o .L pra fora (não usar Z para abrir)."""
    R = READY
    # --- arco: de lado pro alvo; mira -> puxa até a bochecha (devagar) -> solta (estalo) -> recuo -> guarda ---
    side = {"spine": (2, 48, 0), "chest": (0, 8, 0), "head": (0, -50, 0),
            "thigh.R": (16, 0, 0), "shin.R": (8, 0, 0), "thigh.L": (-18, 0, 0), "shin.L": (16, 0, 0)}
    aim = dict(side, **{"upper_arm.L": (-88, 28, 30), "forearm.L": (0, 0, 0), "hand.L": (90, 30, 0),
                         "upper_arm.R": (-75, 20, 0), "forearm.R": (-70, 0, 0)})
    draw = dict(aim, **{"upper_arm.R": (-95, -95, 0), "forearm.R": (-135, 0, 0), "spine": (-2, 52, 0), "chest": (-4, 10, 0)})
    release = dict(aim, **{"upper_arm.R": (-115, -60, 0), "forearm.R": (-10, 0, 0), "spine": (-6, 56, 0), "head": (-4, -50, 0)})
    recoil = dict(release, **{"upper_arm.L": (-80, 28, 30), "spine": (-2, 50, 0)})
    _pose_action(rig, "atk_bow", [(1, R, None), (3, _blend(R, aim, 0.7), (0, -0.02, 0)), (5, aim, (0, -0.03, 0)),
                                  (7, draw, (0, -0.04, -0.02)), (8, release, (0, -0.02, -0.04)), (10, recoil, (0, -0.02, -0.03)),
                                  (13, _blend(recoil, R, 0.6), None), (16, R, None)], 16)
    # --- cajado/varinha: ergue por trás (antecipação), arremessa a ponta pra frente com o corpo, segura e volta ---
    staff_wind = {"spine": (-12, -30, 0), "chest": (-4, -8, 0), "head": (-10, 20, 0),
                  "upper_arm.R": (-140, 70, 0), "forearm.R": (-55, 0, 0), "hand.R": (90, 90, -45),
                  "upper_arm.L": (-50, -30, 0), "forearm.L": (-50, 0, 0),
                  "thigh.R": (6, 0, 0), "thigh.L": (-14, 0, 0), "shin.L": (12, 0, 0)}
    staff_hit = {"spine": (18, 18, 0), "chest": (6, 6, 0), "head": (-6, -14, 0),
                 "upper_arm.R": (-105, 20, 0), "forearm.R": (-5, 0, 0), "hand.R": (90, 60, -45),
                 "upper_arm.L": (-75, -20, 0), "forearm.L": (-10, 0, 0),
                 "thigh.R": (-34, 0, 0), "shin.R": (30, 0, 0), "thigh.L": (18, 0, 0), "shin.L": (12, 0, 0)}
    _pose_action(rig, "atk_staff", [(1, R, None), (3, _blend(R, staff_wind, 0.6), (0, 0.01, -0.02)), (5, staff_wind, (0, 0.02, -0.04)),
                                    (7, staff_hit, (0, -0.03, 0.08)), (10, staff_hit, (0, -0.03, 0.07)),
                                    (13, _blend(staff_hit, R, 0.6), (0, -0.01, 0.03)), (16, R, None)], 16)
    # --- magia em área: junta energia no peito, ergue os braços abertos e empurra as duas mãos pra frente ---
    gather = dict(ARM_CHEST, **{"spine": (10, 0, 0), "head": (4, 0, 0), "thigh.R": (-10, 0, 0), "shin.R": (14, 0, 0),
                                "thigh.L": (-10, 0, 0), "shin.L": (14, 0, 0)})
    cast_up = dict(ARM_V, **{"spine": (-16, 0, 0), "chest": (-6, 0, 0), "head": (-14, 0, 0)})
    cast_push = dict(ARM_FRONT, **{"spine": (18, 0, 0), "chest": (6, 0, 0), "head": (2, 0, 0), "thigh.R": (-26, 0, 0),
                                   "shin.R": (22, 0, 0), "thigh.L": (14, 0, 0)})
    _pose_action(rig, "cast", [(1, R, None), (3, gather, (0, -0.03, 0)), (6, cast_up, (0, 0.04, 0)), (8, cast_up, (0, 0.05, 0)),
                               (10, cast_push, (0, -0.03, 0.06)), (14, cast_push, (0, -0.03, 0.05)),
                               (17, _blend(cast_push, R, 0.6), None), (20, R, None)], 20)
    # --- buff/cura: recolhe, abre os braços pro alto (cabeça erguida) e desce devagar ---
    buff_up = dict(ARM_V, **{"spine": (-18, 0, 0), "chest": (-8, 0, 0), "head": (-22, 0, 0)})
    _pose_action(rig, "cast_buff", [(1, R, None), (3, gather, (0, -0.03, 0)), (8, buff_up, (0, 0.06, 0)), (12, buff_up, (0, 0.07, 0)),
                                    (15, _blend(buff_up, R, 0.5), (0, 0.02, 0)), (18, R, None)], 18)
    # --- idles por arma: arco baixo na mão esquerda; cajado em pé ao lado do corpo ---
    def idle_bow(ph):
        p, h = _idle_pose(ph)
        s = math.sin(ph)
        p.update({"upper_arm.L": (-8 + 2 * s, -8, 0), "forearm.L": (-28, 0, 0), "hand.L": (20, 0, 0),
                  "upper_arm.R": (-6 + 2 * math.sin(ph + 0.8), 8, 0), "forearm.R": (-22, 0, 0), "hand.R": (0, 0, 0),
                  "spine": (3 + 1.5 * s, 0, 0)})
        return p, h
    _cycle(rig, "idle_bow", 48, idle_bow, step=3)

    def idle_staff(ph):
        p, h = _idle_pose(ph)
        s = math.sin(ph)
        p.update({"upper_arm.R": (-22 + 2 * s, 18, 0), "forearm.R": (-62, 0, 0), "hand.R": (75, 0, -10),
                  "upper_arm.L": (-10, -6, 0), "forearm.L": (-30 - 3 * s, 0, 0), "spine": (3 + 1.5 * s, 0, 0)})
        return p, h
    _cycle(rig, "idle_staff", 48, idle_staff, step=3)


# mais poses resolvidas (mão no alvo + arma alinhada; .L = espelho)
ARM_LOW_FRONT_R = {"upper_arm.R": (-70, -30, 60), "forearm.R": (-15, 0, 0), "hand.R": (150, 165, 0)}
ARM_BACK_HIGH_R = {"upper_arm.R": (90, -50, 75), "forearm.R": (-15, 0, 0), "hand.R": (150, -165, 30)}
ARM_SIDE_LOW_R = {"upper_arm.R": (-20, 80, 15), "forearm.R": (-15, 0, 0), "hand.R": (-75, 165, 45)}
# frame (1-based) do impacto dos clipes de skill
IMPACT.update({"cast_ground": 10, "cast_channel": 14, "cast_target": 8, "atk_leap": 12, "atk_charge": 5, "atk_throw": 7,
               "atk_shoot_multi": 8, "summon": 11})


def _both(right):
    """Pose .R + o espelho .L (os dois braços fazem o mesmo)."""
    out = dict(right)
    out.update(_mirror(right))
    return out


def _skill_clips(rig):
    """Clipes pela FORMA da skill (EntityView._action_clip): chão, canalizar, alvo, salto, investida, arremesso, leque, invocar."""
    R = READY
    legs_wide = {"thigh.R": (-14, 0, 0), "shin.R": (16, 0, 0), "thigh.L": (12, 0, 0), "shin.L": (12, 0, 0)}
    # --- magia no chão: ergue os braços em V e crava as duas mãos pra baixo/frente ---
    up = dict(ARM_V, **{"spine": (-14, 0, 0), "chest": (-6, 0, 0), "head": (-16, 0, 0)}, **legs_wide)
    down = dict(_both(ARM_LOW_FRONT_R), **{"spine": (30, 0, 0), "chest": (8, 0, 0), "head": (14, 0, 0),
                                           "thigh.R": (-36, 0, 0), "shin.R": (40, 0, 0), "thigh.L": (18, 0, 0), "shin.L": (20, 0, 0)})
    _pose_action(rig, "cast_ground", [(1, R, None), (5, up, (0, 0.05, 0)), (8, up, (0, 0.06, 0)), (10, down, (0, -0.1, 0.05)),
                                      (14, down, (0, -0.1, 0.05)), (18, _blend(down, R, 0.6), None), (22, R, None)], 22)
    # --- canalizar: mãos no peito juntando energia (tremendo), abre e empurra ---
    gather = dict(ARM_CHEST, **{"spine": (8, 0, 0), "head": (6, 0, 0)}, **legs_wide)
    shake = dict(gather, **{"spine": (10, 3, 0), "chest": (2, -3, 0)})
    push = dict(ARM_FRONT, **{"spine": (16, 0, 0), "chest": (6, 0, 0), "head": (2, 0, 0), "thigh.R": (-28, 0, 0), "shin.R": (24, 0, 0), "thigh.L": (14, 0, 0)})
    _pose_action(rig, "cast_channel", [(1, R, None), (4, gather, (0, -0.03, 0)), (7, shake, (0, -0.03, 0)), (10, gather, (0, -0.04, 0)),
                                       (12, shake, (0, -0.04, 0)), (14, push, (0, -0.02, 0.06)), (19, push, (0, -0.02, 0.05)),
                                       (24, R, None)], 24)
    # --- no alvo: estende o braço da arma pro alvo, o outro pra trás ---
    point = dict(R, **{"upper_arm.R": ARM_FRONT["upper_arm.R"], "forearm.R": (-5, 0, 0), "hand.R": ARM_FRONT["hand.R"],
                       "upper_arm.L": (30, 0, -20), "forearm.L": (-30, 0, 0), "spine": (6, 22, 0), "chest": (2, 8, 0), "head": (0, -18, 0),
                       "thigh.R": (-26, 0, 0), "shin.R": (22, 0, 0), "thigh.L": (16, 0, 0)})
    wind = dict(point, **{"upper_arm.R": ARM_BACK_HIGH_R["upper_arm.R"], "hand.R": ARM_BACK_HIGH_R["hand.R"], "spine": (-4, -20, 0)})
    _pose_action(rig, "cast_target", [(1, R, None), (5, wind, None), (8, point, (0, -0.02, 0.05)), (12, point, (0, -0.02, 0.04)),
                                      (18, R, None)], 18)
    # --- salto e esmagar: agacha, sobe com a arma no alto, cai cravando ---
    crouch = dict(R, **{"spine": (24, 0, 0), "thigh.R": (-60, 0, 0), "shin.R": (90, 0, 0), "thigh.L": (-50, 0, 0), "shin.L": (84, 0, 0),
                        "upper_arm.R": (-30, 20, 0), "forearm.R": (-60, 0, 0), "upper_arm.L": (-20, -10, 0)})
    air = dict(_both({"upper_arm.R": (160, -60, -30), "forearm.R": (-15, 0, 0), "hand.R": (-135, -15, -15)}),
               **{"spine": (-18, 0, 0), "head": (-12, 0, 0), "thigh.R": (-40, 0, 0), "shin.R": (70, 0, 0), "thigh.L": (-20, 0, 0), "shin.L": (50, 0, 0)})
    slam = dict(_both(ARM_LOW_FRONT_R), **{"spine": (40, 0, 0), "chest": (10, 0, 0), "head": (16, 0, 0),
                                           "thigh.R": (-60, 0, 0), "shin.R": (80, 0, 0), "thigh.L": (-30, 0, 0), "shin.L": (60, 0, 0)})
    _pose_action(rig, "atk_leap", [(1, R, None), (4, crouch, (0, -0.14, 0)), (7, air, (0, 0.45, 0.2)), (10, air, (0, 0.38, 0.35)),
                                   (12, slam, (0, -0.16, 0.4)), (16, slam, (0, -0.16, 0.4)), (22, R, None)], 22)
    # --- investida: abaixa e avança com o ombro/arma à frente ---
    lean = dict(R, **{"spine": (36, -10, 0), "chest": (8, 0, 0), "head": (-26, 8, 0),
                      "upper_arm.R": ARM_FRONT["upper_arm.R"], "forearm.R": (-10, 0, 0), "hand.R": ARM_FRONT["hand.R"],
                      "upper_arm.L": (-40, -30, 0), "forearm.L": (-70, 0, 0),
                      "thigh.R": (-56, 0, 0), "shin.R": (50, 0, 0), "thigh.L": (42, 0, 0), "shin.L": (46, 0, 0)})
    _pose_action(rig, "atk_charge", [(1, _blend(R, lean, 0.4), (0, -0.04, 0)), (3, lean, (0, -0.1, 0.12)), (5, lean, (0, -0.1, 0.16)),
                                     (10, lean, (0, -0.08, 0.12)), (14, _blend(lean, R, 0.6), None), (18, R, None)], 18)
    # --- arremesso: arma pra trás no alto e lança pra frente com o corpo ---
    cock = dict(R, **ARM_BACK_HIGH_R, **{"spine": (-6, -30, 0), "chest": (-4, -8, 0), "head": (0, 22, 0),
                                       "upper_arm.L": ARM_FRONT["upper_arm.L"], "forearm.L": (-20, 0, 0),
                                       "thigh.R": (10, 0, 0), "thigh.L": (-24, 0, 0), "shin.L": (20, 0, 0)})
    throw = dict(R, **ARM_LOW_FRONT_R, **{"spine": (22, 26, 0), "chest": (8, 8, 0), "head": (6, -16, 0),
                                       "upper_arm.L": (20, 0, -25), "forearm.L": (-30, 0, 0),
                                       "thigh.R": (-30, 0, 0), "shin.R": (26, 0, 0), "thigh.L": (18, 0, 0)})
    _pose_action(rig, "atk_throw", [(1, R, None), (4, cock, (0, 0, -0.04)), (6, _blend(cock, throw, 0.5), (0, -0.02, 0.03)),
                                    (7, throw, (0, -0.03, 0.08)), (11, throw, (0, -0.03, 0.07)), (16, R, None)], 16)
    # --- arco em leque: mira, puxa e varre o corpo soltando ---
    side = {"spine": (2, 48, 0), "chest": (0, 8, 0), "head": (0, -50, 0), "thigh.R": (16, 0, 0), "shin.R": (8, 0, 0),
            "thigh.L": (-18, 0, 0), "shin.L": (16, 0, 0)}
    aim = dict(side, **{"upper_arm.L": (-88, 28, 30), "forearm.L": (0, 0, 0), "hand.L": (90, 30, 0), "upper_arm.R": (-75, 20, 0), "forearm.R": (-70, 0, 0)})
    draw = dict(aim, **{"upper_arm.R": (-95, -95, 0), "forearm.R": (-135, 0, 0), "spine": (-2, 58, 0)})
    rel_a = dict(aim, **{"upper_arm.R": (-115, -60, 0), "forearm.R": (-10, 0, 0), "spine": (-4, 62, 0)})
    rel_b = dict(rel_a, **{"spine": (-4, 30, 0), "head": (0, -26, 0)})
    _pose_action(rig, "atk_shoot_multi", [(1, R, None), (4, aim, None), (7, draw, (0, -0.03, 0)), (8, rel_a, (0, -0.02, -0.03)),
                                          (11, rel_b, (0, -0.02, -0.03)), (14, _blend(rel_b, R, 0.5), None), (18, R, None)], 18)
    # --- invocar: ergue a arma/braços, segura e abre os braços pra baixo (o chamado sai do chão) ---
    raise_ = dict(ARM_V, **{"spine": (-18, 0, 0), "chest": (-8, 0, 0), "head": (-24, 0, 0)}, **legs_wide)
    open_ = dict(_both(ARM_SIDE_LOW_R), **{"spine": (10, 0, 0), "head": (8, 0, 0), "thigh.R": (-20, 0, 0), "shin.R": (22, 0, 0), "thigh.L": (14, 0, 0)})
    _pose_action(rig, "summon", [(1, R, None), (6, raise_, (0, 0.06, 0)), (9, raise_, (0, 0.07, 0)), (11, open_, (0, -0.06, 0)),
                                 (16, open_, (0, -0.06, 0)), (22, R, None)], 22)


IMPACT.update({"atk_sweep": 8, "atk_finisher": 10, "atk_flurry": 5, "atk_claw": 6, "shout": 7, "cast_fire": 8, "cast_ice": 8, "cast_bolt": 7,
               "cast_holy": 8, "cast_shadow": 8, "cast_nature": 9, "buff_power": 7, "buff_guard": 6, "buff_focus": 8})


def _arms(right, left):
    """Junta o braço direito de uma pose com o esquerdo de outra."""
    out = {k: v for k, v in right.items() if k.endswith(".R") and k.split(".")[0] in ("upper_arm", "forearm", "hand")}
    out.update({k: v for k, v in left.items() if k.endswith(".L") and k.split(".")[0] in ("upper_arm", "forearm", "hand")})
    return out


def _family_clips(rig):
    """Clipes por FAMÍLIA de skill (EntityView._action_clip): cada elemento e cada tipo de buff tem o próprio gesto."""
    R = READY
    lunge = {"thigh.R": (-46, 0, 0), "shin.R": (48, 0, 0), "thigh.L": (32, 0, 0), "shin.L": (26, 0, 0)}
    low = {"thigh.R": (-60, 0, 0), "shin.R": (86, 0, 0), "thigh.L": (-48, 0, 0), "shin.L": (80, 0, 0)}
    wide = {"thigh.R": (-18, 0, 0), "shin.R": (20, 0, 0), "thigh.L": (14, 0, 0), "shin.L": (16, 0, 0)}
    front_both = _arms(ARM_FRONT, ARM_FRONT)
    down_both = _both(ARM_LOW_FRONT_R)
    open_both = _both(ARM_SIDE_LOW_R)
    # --- golpe largo: torce todo o corpo pra trás e varre até passar do alvo ---
    wind = dict(_arms(ARM_BACK_HIGH_R, ARM_FRONT), **{"spine": (6, -58, 0), "chest": (0, -22, 0), "head": (0, 44, 0)}, **wide)
    hit = dict(_arms(ARM_FRONT, ARM_SIDE_LOW_R), **{"spine": (16, 52, 0), "chest": (4, 22, 0), "head": (2, -38, 0)}, **lunge)
    follow = dict(hit, **{"spine": (14, 78, 0), "chest": (4, 26, 0), "head": (2, -54, 0)})
    _pose_action(rig, "atk_sweep", [(1, R, None), (5, wind, (0, -0.02, -0.05)), (7, _blend(wind, hit, 0.45), (0, -0.05, 0.02)), (8, hit, (0, -0.08, 0.1)),
                                    (12, follow, (0, -0.08, 0.1)), (17, _blend(follow, R, 0.6), (0, -0.03, 0.04)), (22, R, None)], 22)
    # --- finalizador: agacha, sobe com tudo no alto e crava ---
    gather = dict(_arms(ARM_CHEST, ARM_CHEST), **{"spine": (30, 0, 0), "head": (-12, 0, 0)}, **low)
    top = dict(ARM_V, **{"spine": (-24, 0, 0), "chest": (-10, 0, 0), "head": (-14, 0, 0), "thigh.R": (-30, 0, 0), "shin.R": (54, 0, 0), "thigh.L": (-8, 0, 0), "shin.L": (40, 0, 0)})
    crash = dict(down_both, **{"spine": (46, 0, 0), "chest": (12, 0, 0), "head": (18, 0, 0)}, **low)
    _pose_action(rig, "atk_finisher", [(1, R, None), (5, gather, (0, -0.16, 0)), (8, top, (0, 0.2, 0.05)), (9, top, (0, 0.22, 0.1)), (10, crash, (0, -0.2, 0.18)),
                                       (15, crash, (0, -0.2, 0.18)), (19, _blend(crash, R, 0.55), (0, -0.08, 0.08)), (24, R, None)], 24)
    # --- rajada: três estocadas alternadas com o tronco girando ---
    sa = dict(_arms(ARM_FRONT, ARM_SIDE_LOW_R), **{"spine": (16, 26, 0), "chest": (4, 10, 0), "head": (0, -28, 0)}, **lunge)
    sb = dict(_arms(ARM_SIDE_LOW_R, ARM_FRONT), **{"spine": (16, -26, 0), "chest": (4, -10, 0), "head": (0, 28, 0)}, **dict(lunge, **{"thigh.R": (28, 0, 0), "shin.R": (24, 0, 0), "thigh.L": (-44, 0, 0), "shin.L": (46, 0, 0)}))
    coil = dict(_arms(ARM_BACK_HIGH_R, ARM_CHEST), **{"spine": (4, -18, 0), "head": (0, 14, 0)}, **wide)
    _pose_action(rig, "atk_flurry", [(1, R, None), (3, coil, (0, -0.02, -0.05)), (5, sa, (0, -0.08, 0.1)), (7, coil, (0, -0.04, 0.0)), (9, sb, (0, -0.08, 0.14)),
                                     (11, coil, (0, -0.04, 0.04)), (13, sa, (0, -0.1, 0.18)), (17, _blend(sa, R, 0.6), (0, -0.03, 0.06)), (21, R, None)], 21)
    # --- garras: abre os dois braços no alto e rasga em X ---
    rear = dict(ARM_V, **{"spine": (-16, 0, 0), "chest": (-8, 0, 0), "head": (-6, 0, 0)}, **wide)
    rake = dict(down_both, **{"spine": (34, 0, 0), "chest": (10, 0, 0), "head": (-6, 0, 0)}, **lunge)
    _pose_action(rig, "atk_claw", [(1, R, None), (4, rear, (0, 0.04, -0.04)), (6, rake, (0, -0.1, 0.12)), (10, rake, (0, -0.1, 0.12)), (15, _blend(rake, R, 0.6), (0, -0.04, 0.05)), (19, R, None)], 19)
    # --- grito: encolhe e estufa o peito, cabeça pra trás ---
    crunch = dict(_arms(ARM_CHEST, ARM_CHEST), **{"spine": (32, 0, 0), "chest": (6, 0, 0), "head": (22, 0, 0)}, **low)
    roar = dict(open_both, **{"spine": (-24, 0, 0), "chest": (-14, 0, 0), "head": (-36, 0, 0)}, **wide)
    roar2 = dict(roar, **{"spine": (-24, 4, 0), "chest": (-14, -4, 0)})
    _pose_action(rig, "shout", [(1, R, None), (4, crunch, (0, -0.1, 0)), (7, roar, (0, 0.05, 0)), (10, roar2, (0, 0.05, 0)), (13, roar, (0, 0.05, 0)), (16, _blend(roar, R, 0.5), None), (21, R, None)], 21)
    # --- fogo: puxa a mão pra trás e arremessa com o corpo todo ---
    pull = dict(_arms(ARM_BACK_HIGH_R, ARM_FRONT), **{"spine": (-6, -42, 0), "chest": (-2, -14, 0), "head": (0, 34, 0)}, **wide)
    thrust = dict(_arms(ARM_FRONT, ARM_BACK_HIGH_R), **{"spine": (18, 16, 0), "chest": (6, 6, 0), "head": (0, -16, 0)}, **lunge)
    thrust["upper_arm.L"], thrust["forearm.L"] = (30, 0, -30), (-30, 0, 0)
    _pose_action(rig, "cast_fire", [(1, R, None), (5, pull, (0, -0.03, -0.05)), (7, _blend(pull, thrust, 0.5), (0, -0.05, 0.02)), (8, thrust, (0, -0.08, 0.1)), (12, thrust, (0, -0.07, 0.09)),
                                    (16, _blend(thrust, R, 0.6), (0, -0.03, 0.04)), (21, R, None)], 21)
    # --- gelo: dois braços varrem de um lado ao outro, em leque ---
    ia = dict(front_both, **{"spine": (6, -54, 0), "chest": (0, -18, 0), "head": (0, 40, 0)}, **wide)
    ib = dict(front_both, **{"spine": (12, 50, 0), "chest": (2, 18, 0), "head": (0, -36, 0)}, **lunge)
    _pose_action(rig, "cast_ice", [(1, R, None), (5, ia, (0, -0.02, 0)), (8, ib, (0, -0.06, 0.06)), (12, ib, (0, -0.06, 0.05)), (17, _blend(ib, R, 0.6), None), (21, R, None)], 21)
    # --- raio: aponta pro céu e crava o braço, chamando o raio ---
    call = dict(_arms(ARM_V, ARM_CHEST), **{"spine": (-18, -16, 0), "chest": (-8, 0, 0), "head": (-26, 8, 0)}, **wide)
    strike = dict(_arms(ARM_LOW_FRONT_R, ARM_SIDE_LOW_R), **{"spine": (32, 14, 0), "chest": (10, 0, 0), "head": (6, -8, 0)}, **lunge)
    _pose_action(rig, "cast_bolt", [(1, R, None), (5, call, (0, 0.05, 0)), (7, strike, (0, -0.09, 0.09)), (11, strike, (0, -0.08, 0.08)), (15, _blend(strike, R, 0.6), (0, -0.03, 0.03)), (19, R, None)], 19)
    # --- sagrado: mãos juntas de cabeça baixa, abre pro alto ---
    pray = dict(_arms(ARM_CHEST, ARM_CHEST), **{"spine": (18, 0, 0), "head": (26, 0, 0)}, **low)
    glory = dict(ARM_V, **{"spine": (-20, 0, 0), "chest": (-10, 0, 0), "head": (-28, 0, 0)}, **wide)
    _pose_action(rig, "cast_holy", [(1, R, None), (4, pray, (0, -0.1, 0)), (6, pray, (0, -0.12, 0)), (8, glory, (0, 0.1, 0)), (13, glory, (0, 0.12, 0)), (17, _blend(glory, R, 0.6), (0, 0.03, 0)), (21, R, None)], 21)
    # --- sombra: se fecha sobre si e atira os braços pra fora ---
    hunch = dict(_arms(ARM_CHEST, ARM_CHEST), **{"spine": (34, 0, 0), "chest": (12, 0, 0), "head": (24, 0, 0)}, **low)
    fling = dict(open_both, **{"spine": (-8, 0, 0), "chest": (-6, 0, 0), "head": (-4, 0, 0)}, **lunge)
    _pose_action(rig, "cast_shadow", [(1, R, None), (5, hunch, (0, -0.14, 0)), (8, fling, (0, -0.04, 0.06)), (12, fling, (0, -0.04, 0.05)), (16, _blend(fling, R, 0.6), None), (21, R, None)], 21)
    # --- natureza: mãos no chão e puxa a terra pra cima ---
    reach = dict(down_both, **{"spine": (48, 0, 0), "chest": (12, 0, 0), "head": (-10, 0, 0)}, **low)
    lift = dict(front_both, **{"spine": (-10, 0, 0), "chest": (-6, 0, 0), "head": (-14, 0, 0)}, **wide)
    _pose_action(rig, "cast_nature", [(1, R, None), (5, reach, (0, -0.2, 0.04)), (7, reach, (0, -0.21, 0.04)), (9, lift, (0, 0.06, 0)), (13, lift, (0, 0.07, 0)), (18, _blend(lift, R, 0.6), None), (22, R, None)], 22)
    # --- buffs: força (flexiona e explode), guarda (finca os pés), foco (mão no rosto e solta) ---
    flex = dict(_arms(ARM_CHEST, ARM_CHEST), **{"spine": (28, 0, 0), "head": (16, 0, 0)}, **low)
    burst = dict(open_both, **{"spine": (-18, 0, 0), "chest": (-12, 0, 0), "head": (-20, 0, 0)}, **wide)
    _pose_action(rig, "buff_power", [(1, R, None), (4, flex, (0, -0.12, 0)), (7, burst, (0, 0.06, 0)), (12, burst, (0, 0.06, 0)), (16, _blend(burst, R, 0.5), None), (20, R, None)], 20)
    brace = dict(front_both, **{"spine": (16, 0, 0), "chest": (6, 0, 0), "head": (-10, 0, 0)}, **low)
    _pose_action(rig, "buff_guard", [(1, R, None), (3, _blend(R, brace, 0.5), (0, 0.04, 0)), (6, brace, (0, -0.15, 0)), (12, brace, (0, -0.14, 0)), (15, _blend(brace, R, 0.5), None), (19, R, None)], 19)
    breathe = dict(_arms(ARM_CHEST, ARM_CHEST), **{"spine": (14, 0, 0), "head": (10, 0, 0)}, **low)
    loose = dict(_arms(ARM_V, ARM_SIDE_LOW_R), **{"spine": (-12, 14, 0), "chest": (-4, 6, 0), "head": (-12, -8, 0)}, **wide)
    _pose_action(rig, "buff_focus", [(1, R, None), (5, breathe, (0, -0.1, 0)), (8, loose, (0, 0.07, 0)), (13, loose, (0, 0.08, 0)), (16, _blend(loose, R, 0.5), None), (20, R, None)], 20)

def _settle_attacks(rig):
    """Golpes com antecipação (meio caminho pra preparação) e acomodação (meio caminho de volta) — impacto igual."""
    acts = {t.name: t for t in (rig.animation_data.nla_tracks if rig.animation_data else [])}
    for name in ("atk_1h_a", "atk_1h_b", "atk_2h", "atk_dual_a", "atk_dual_b", "atk_dagger", "atk_thrust", "atk_staff", "cast", "cast_buff"):
        tr = acts.get(name)
        if tr is None or not tr.strips:
            continue
        act = tr.strips[0].action
        end = int(act.frame_range[1])
        imp = IMPACT.get(name, 6)
        for fc in _fcurves(act):
            kps = fc.keyframe_points
            if len(kps) < 3:
                continue
            # acomodação: um key entre o último golpe e a volta, com leve passagem do ponto (overshoot)
            f_set = min(end - 1, imp + max(3, (end - imp) * 2 // 3))
            v_end = fc.evaluate(end)
            v_follow = fc.evaluate(imp + 2)
            fc.keyframe_points.insert(f_set, v_end + (v_end - v_follow) * 0.08, options={"FAST"})
            # antecipação: pequena contração antes do preparo
            v0 = fc.evaluate(1)
            v_wind = fc.evaluate(max(2, imp - 3))
            fc.keyframe_points.insert(2, v0 - (v_wind - v0) * 0.12, options={"FAST"})
            fc.update()


def _fcurves(act):
    """fcurves da action (Blender 5: dentro de layers/strips/channelbags)."""
    fcs = list(getattr(act, "fcurves", []) or [])
    if fcs:
        return fcs
    out = []
    for layer in getattr(act, "layers", []):
        for strip in layer.strips:
            for cb in getattr(strip, "channelbags", []):
                out.extend(cb.fcurves)
    return out


# ---------------------------------------------------------------------------
# elenco: classe -> (sexo, conjunto, cor da classe, arma, estilo de animação, cor do cabelo)
# cores = data/catalog/classes_catalog.gd
# ---------------------------------------------------------------------------
CLASSES = {
    "paladin": ("male", "plate", (0.95, 0.85, 0.45), "sword_shield", "melee", (0.85, 0.65, 0.3)),
    "berserker": ("male", "leather", (0.85, 0.3, 0.25), "axe2h", "melee", (0.55, 0.2, 0.12)),
    "bishop": ("female", "robe", (0.95, 0.95, 0.9), "staff", "caster", (0.95, 0.85, 0.55)),
    "druid": ("female", "leather", (0.45, 0.8, 0.35), "staff", "caster", (0.4, 0.28, 0.16)),
    "ranger": ("female", "leather", (0.5, 0.75, 0.55), "bow", "bow", (0.75, 0.4, 0.2)),
    "assassin": ("male", "leather", (0.55, 0.35, 0.75), "daggers", "dagger", (0.2, 0.18, 0.25)),
    "elementalist": ("female", "robe", (0.35, 0.6, 0.95), "wand", "caster", (0.25, 0.3, 0.55)),
    "necromancer": ("male", "robe", (0.4, 0.85, 0.65), "scythe", "melee", (0.85, 0.85, 0.9)),
    "npc_villager": ("male", "leather", (0.8, 0.75, 0.6), None, "melee", (0.45, 0.3, 0.18)),
}
# qual peça de cada conjunto recebe a cor da classe
TINTED = {"plate": {"skirt"}, "robe": {"torso", "skirt"}, "leather": {"torso"}}


def build_class(cid):
    sex, armor, color, wpn, style, hair = CLASSES[cid]
    base = build_base(cid, sex, 0.0, hair)
    equip(base, armor, color)
    if wpn:
        weapon(base, wpn, color)
    animate(base["rig"], style)
    return base


def export_glb(rig, path):
    bpy.ops.object.select_all(action="DESELECT")
    rig.hide_set(False)
    rig.select_set(True)
    for c in rig.children_recursive:
        c.select_set(True)
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=True, export_apply=False,
                              export_animations=True, export_animation_mode="NLA_TRACKS",
                              export_yup=True, export_materials="EXPORT", export_skins=True)
    print("exported", path)


def build_all(out_dir, only=None):
    import os
    os.makedirs(out_dir, exist_ok=True)
    for cid in CLASSES:
        if only and cid not in only:
            continue
        clear()
        base = build_class(cid)
        export_glb(base["rig"], os.path.join(out_dir, cid + ".glb"))
    print("characters done")


def preview_kit():
    """Masculino de placa + espada/escudo, feminina de manto + cajado (para avaliar o visual)."""
    clear()
    m = build_base("male", "male", -0.45)
    equip(m, "plate")
    weapon(m, "sword_shield", (0.2, 0.35, 0.75))
    f = build_base("female", "female", 0.45, (0.85, 0.55, 0.3))
    equip(f, "robe")
    weapon(f, "staff", (0.5, 0.8, 1.0))
    for o in bpy.context.scene.objects:
        if o.type == "ARMATURE":
            o.hide_set(True)
    return m, f


# ===========================================================================
# KIT MODULAR: um GLB por corpo (kit_male / kit_female) com TODAS as peças, todas no mesmo rig.
# O jogo (EntityView) mostra só as peças do equipamento e pinta pela cor do item.
# Nomes (viram nós no Godot; sem "."):
#   base_*                          corpo/cabeça/olhos (sempre visíveis)
#   base_hair*                      cabelo (material "hair": cor da classe; some com elmo/capuz)
#   arm_<estilo>_<slot>_<parte>     estilo plate|leather|cloth · slot head|body|gloves|boots
#   wpn_main_<tipo> / wpn_off_<tipo>
# Material "tint" = recebe a cor do item no jogo.
# ===========================================================================
KIT_HAIR = (0.5, 0.36, 0.22)
TINT_BASE = (0.85, 0.85, 0.85)
KIT_STYLES = {
    "plate": {"body": [("torso", {"push": 0.022, "flare": 0.12}), ("skirt", {"bottom": Z["knee"] + 0.07, "flare": 1.35}),
                       ("pauldrons", {}), ("belt", {"mat": "trim"}), ("collar", {"mat": "trim"})],
              "legs": [("legs", {"push": 0.01})],
              "gloves": [("gloves", {"push": 0.012})], "boots": [("boots", {"push": 0.022})]},
    "leather": {"body": [("torso", {"push": 0.016, "flare": 0.15}), ("belt", {"mat": "belt"}),
                         ("mantle", {"mat": "tint2"}), ("strap", {"mat": "belt"}), ("pouch", {"mat": "leather"})],
                "legs": [("legs", {"push": 0.01})],
                "gloves": [("gloves", {"push": 0.008})], "boots": [("boots", {"push": 0.02})]},
    "cloth": {"body": [("torso", {"push": 0.014}), ("skirt", {"bottom": 0.08, "flare": 1.9}), ("belt", {"mat": "belt"}),
                        ("mantle", {"mat": "tint2"}), ("sash", {"mat": "tint2"})],
              "legs": [("legs", {"push": 0.008})],
              "gloves": [("gloves", {"push": 0.006})], "boots": [("boots", {"push": 0.012})]},
}
KIT_STYLES["cape"] = {"cape": [("cape", {})]}       # capa é peça própria, igual para todas as classes
KIT_MAIN = ["sword", "sword2h", "mace", "mace2h", "axe", "axe2h", "dagger", "bow", "staff", "wand", "scythe", "scepter", "rifle"]
KIT_OFF = ["shield", "orb", "sword", "mace", "axe", "dagger"]


def _kit_mats():
    return {"tint": mat("tint", TINT_BASE, 0.6), "tint2": mat("tint2", TINT_BASE, 0.6), "pants": mat("pants", (0.3, 0.27, 0.33), 0.9),
            "belt": mat("belt", (0.36, 0.23, 0.14), 0.8), "trim": mat("trim", GOLD, 0.4),
            "metal": mat("m_metal", METAL, 0.35), "wood": mat("m_wood", WOOD, 0.8), "leather": mat("m_leather", LEATHER, 0.8),
            "white": mat("m_set_white", (0.93, 0.92, 0.96), 0.5), "dark": mat("m_set_dark", (0.2, 0.16, 0.3), 0.5),
            "band": mat("m_set_band", (0.66, 0.62, 0.74), 0.6)}


def kit_piece(base, style, slot, part, opt, mats):
    rig, body, b = base["rig"], base["body"], base["b"]
    name = "arm_%s_%s_%s" % (style, slot, part)
    m = mats[opt.get("mat", "tint")]
    if part in REGIONS:
        return [armor_piece(body, rig, name, part, m, opt["push"], 0.016, opt.get("flare", 0.0))]
    if part == "skirt":
        return [skirt(name, b, body, rig, m, opt["bottom"], opt["flare"])]
    if part == "pauldrons":
        out = []
        for s, tag in ((".R", "R"), (".L", "L")):
            p = ball("%s_%s" % (name, tag), b["arm"] * 1.9, Vector(base["j"]["shoulder" + s]) + Vector((0, 0, 0.02)), m, (1.1, 1.0, 0.75))
            _smooth(p.data)
            skin_rigid(p, rig, "upper_arm" + s)
            out.append(p)
        return out
    if part == "belt":
        r = b["waist"] * 1.12
        bt = tube(name, (0, 0, Z["waist"] - 0.035), (0, 0, Z["waist"] + 0.035), r, r, m, 16)
        for vert in bt.data.vertices:
            vert.co.y *= b["depth"] * 1.05
        _smooth(bt.data)
        transfer_weights(bt, body, rig)
        return [bt]
    if part == "collar":
        p = tube(name, (0, 0, Z["neck"] - 0.03), (0, 0, Z["neck"] + 0.04), b["neck"] * 2.0, b["neck"] * 1.55, m, 16)
        _smooth(p.data)
        skin_rigid(p, rig, "chest")
        return [p]
    if part == "mantle":                # manto curto: é o que mais aparece de cima
        p = ball(name, b["shoulder"] * 1.25, (0, 0.01, Z["upper"] + 0.03), m, (1.05, 0.85, 0.38))
        _smooth(p.data)
        skin_rigid(p, rig, "chest")
        return [p]
    if part == "cape":
        return [_cape(name, b, rig, m)]
    if part == "strap":                 # bandoleira do ombro ao quadril
        y = -(b["chest"] * b["depth"] + 0.012)
        pts = [Vector((b["shoulder"] * (0.75 - 1.4 * t), y * (1.0 - 0.18 * math.sin(t * math.pi) * -1.0), Z["upper"] + (Z["waist"] - Z["upper"]) * t)) for t in (0.0, 0.34, 0.67, 1.0)]
        st = _join([tube("%s%d" % (name, i), pts[i], pts[i + 1], 0.024, 0.024, m, 6) for i in range(3)], name)
        _smooth(st.data)
        transfer_weights(st, body, rig)
        return [st]
    if part == "pouch":
        p = box(name, (0.1, 0.07, 0.1), (b["waist"] * 0.92, -b["waist"] * b["depth"] * 0.6, Z["waist"] - 0.07), m, 0.015)
        skin_rigid(p, rig, "hips")
        return [p]
    if part == "sash":                  # faixa na frente do cinto
        p = box(name, (0.13, 0.03, 0.34), (0, -(b["waist"] * b["depth"] * 1.28), Z["waist"] - 0.19), m, 0.01)
        skin_rigid(p, rig, "hips")
        return [p]
    return []


def _cape(name, b, rig, material):
    """Capa nas costas (frente do boneco é -Y), presa ao peito: de cima/atrás é a maior área do personagem."""
    rows, cols = 6, 6
    top, bottom = Z["upper"] + 0.05, Z["knee"]
    verts, faces = [], []
    for r in range(rows + 1):
        t = r / rows
        half = b["shoulder"] * (0.72 + 0.5 * t)
        for c in range(cols + 1):
            s = c / cols * 2.0 - 1.0
            y = b["chest"] * b["depth"] + 0.04 + 0.12 * t * t - 0.05 * s * s + 0.012 * math.cos(s * 9.0) * t
            verts.append((s * half, y, top + (bottom - top) * t))
    for r in range(rows):
        for c in range(cols):
            a = r * (cols + 1) + c
            faces.append((a, a + 1, a + cols + 2, a + cols + 1))
    me = bpy.data.meshes.new(name)
    me.from_pydata(verts, [], faces)
    o = bpy.data.objects.new(name, me)
    bpy.context.collection.objects.link(o)
    sol = o.modifiers.new("sol", "SOLIDIFY")
    sol.thickness = 0.02
    _bake(o)
    o.data.materials.append(material)
    _smooth(o.data)
    skin_rigid(o, rig, "chest")
    return o


def _shell(name, c, r, face_top, back_bottom, side_bottom, thick, material):
    """Casca esférica com abertura do rosto (elmo/capuz)."""
    o = quad_sphere(name, r, c, cuts=4)
    bm = bmesh.new()
    bm.from_mesh(o.data)
    kill = []
    for f in bm.faces:
        d = f.calc_center_median() - Vector(c)
        if d.y < -r * 0.25:
            cut = face_top
        elif d.y > r * 0.2:
            cut = back_bottom
        else:
            cut = side_bottom
        if d.z < cut * r:
            kill.append(f)
    bmesh.ops.delete(bm, geom=kill, context="FACES")
    bm.to_mesh(o.data)
    bm.free()
    sol = o.modifiers.new("sol", "SOLIDIFY")
    sol.thickness = thick
    sol.offset = 1.0
    _bake(o)
    o.data.materials.append(material)
    _smooth(o.data)
    return o


def kit_head(base, style, mats):
    """Elmo (placa), capuz (couro) ou tiara (tecido). Rígidos no bone da cabeça."""
    c = Vector(base["head_c"])
    r = base["b"]["head"]
    n = "arm_%s_head_" % style
    parts = []
    if style == "plate":
        parts.append(_shell(n + "helm", c, r * 1.17, 0.18, -0.6, -0.35, 0.03, mats["tint"]))
        parts.append(box(n + "crest", (0.045, r * 1.3, 0.07), c + Vector((0, 0.0, r * 1.2)), mats["trim"], 0.01))
        parts.append(box(n + "nose", (0.04, 0.03, r * 0.5), c + Vector((0, -r * 1.12, r * 0.05)), mats["trim"], 0.008))
        parts.append(tube(n + "brow", c + Vector((0, 0, r * 0.24)), c + Vector((0, 0, r * 0.38)), r * 1.27, r * 1.235, mats["trim"], 24))
        # crista de ponta a ponta do elmo: de cima, a cabeça é o que mais aparece
        parts.append(ball(n + "ridge", r, c + Vector((0, r * 0.14, r * 0.92)), mats["tint2"], (0.2, 1.08, 0.72)))
    elif style == "leather":
        parts.append(_shell(n + "hood", c, r * 1.16, 0.38, -0.85, -0.45, 0.03, mats["tint"]))
        parts.append(strand(n + "tip", c + Vector((0, r * 0.75, r * 0.55)), r * 0.8, r * 0.5, r * 0.4, mats["tint"], taper=0.9, lean=(0.0, 0.7)))
        parts.append(tube(n + "trim", c + Vector((0, 0, r * 0.44)), c + Vector((0, 0, r * 0.56)), r * 1.21, r * 1.16, mats["tint2"], 24))
        parts.append(ball(n + "knot", r * 0.28, c + Vector((0, r * 0.2, r * 1.24)), mats["tint2"], (1.0, 1.3, 0.6)))
    else:
        ring_r = r * 1.1
        parts.append(tube(n + "band", c + Vector((0, 0, r * 0.4)), c + Vector((0, 0, r * 0.5)), ring_r, ring_r * 0.97, mats["trim"], 20))
        parts.append(ball(n + "gem", 0.04, c + Vector((0, -ring_r, r * 0.47)), mats["tint"], (1, 0.6, 1.2)))
    for p in parts:
        _smooth(p.data)
        skin_rigid(p, base["rig"], "head")
    return parts




# Montagem do escudo (resolvida no rig por tools/blender/shield_mount.py): no idle o antebraço atravessa as costas,
# escudo de pé com a ponta para baixo e a face para fora (um pouco para cima: a câmera é alta).
SHIELD_TURN = 88.1      # graus em Z
SHIELD_TILT = -12.2     # graus em X
SHIELD_SPIN = -86.4     # graus em Y (no plano do escudo)
SHIELD_OFFSET = (0.298, 0.310, 0.042)     # centro do escudo a partir do antebraço, no repouso
SHIELD_SCALE = 1.16     # chibi pede equipamento exagerado
SHIELD_OUTLINE = 0.016  # espessura do contorno soldado (shield_kit.hull)


def _shield_rot():
    """Rotação do escudo no repouso (face = -Y do modelo, topo = +Z)."""
    return (Matrix.Rotation(math.radians(SHIELD_TURN), 3, "Z") @ Matrix.Rotation(math.radians(SHIELD_TILT), 3, "X")
            @ Matrix.Rotation(math.radians(SHIELD_SPIN), 3, "Y"))


def _shield_anchor(base):
    """Ponto do antebraço e centro do escudo: o suporte liga um ao outro."""
    arm = Vector(base["j"]["wrist.L"]) * 0.55 + Vector(base["j"]["elbow.L"]) * 0.45
    return arm, arm + Vector(SHIELD_OFFSET)     # colado no lado de fora do antebraço


def kit_shield_grip(base, mats):
    """Suporte do escudo, peça própria: braçadeira no antebraço e duas hastes que afinam até a placa."""
    import shield_kit
    arm, c = _shield_anchor(base)
    ouro = mat("m_escudo_ouro", (0.95, 0.66, 0.16), 0.32)
    wrist, elbow = Vector(base["j"]["wrist.L"]), Vector(base["j"]["elbow.L"])
    # a alça sai reta do antebraço até as costas do escudo (pela normal), não até o centro: o escudo fica abaixo do braço
    n = (_shield_rot() @ Vector((0, -1, 0))).normalized()
    back = arm + n * ((c - arm).dot(n) - 0.04)
    along = (wrist - elbow).normalized()
    parts = [tube("grip_faixa", arm + (wrist - arm) * 0.5, arm + (elbow - arm) * 0.5, 0.088, 0.092, ouro, 10)]
    for k in (-1, 1):
        parts.append(tube("grip_haste_%d" % k, arm + along * k * 0.07, back + along * k * 0.09, 0.045, 0.035, ouro, 6))
    obj = _join(parts, "wpn_off_grip")
    shield_kit.hull(obj, SHIELD_OUTLINE, mat("m_contorno", (0.12, 0.1, 0.16), 0.9))
    skin_rigid(obj, base["rig"], "forearm.L")
    return obj


def kit_shield(base, style, name, mats):
    """Escudo de uma família de shield_kit.py, preso no antebraço esquerdo."""
    import shield_kit
    gold = dict(mats, trim=mat("m_escudo_ouro", (0.95, 0.66, 0.16), 0.32))     # ouro mais fundo que o filete das armaduras
    obj = _join(shield_kit.FAMILIES[style](sys.modules[__name__], name, gold), name)
    rot = _shield_rot().to_4x4()
    c = _shield_anchor(base)[1]
    inner = shield_kit.INNER.get(style, 1.0)
    for vert in obj.data.vertices:
        co = vert.co * SHIELD_SCALE * shield_kit.SIZES.get(style, 1.0)
        co.x *= inner if co.x < 0.0 else 1.0
        vert.co = rot @ co + c
    shield_kit.hull(obj, SHIELD_OUTLINE, mat("m_contorno", (0.12, 0.1, 0.16), 0.9))
    skin_rigid(obj, base["rig"], "forearm.L")
    return obj


def _mace_1h(g, fwd, mm, mg, ml, mt):
    """Maça de flanges: cabo grosso com tiras, colar de ouro, cabeça com 6 flanges em volta de um núcleo e tampa."""
    side = Vector((1, 0, 0))
    ridge = fwd.cross(side).normalized()
    hc = g + fwd * 0.54
    parts = [tube("shaft", g - fwd * 0.13, g + fwd * 0.44, 0.03, 0.028, ml, 8), ball("pommel", 0.045, g - fwd * 0.15, mg),
             tube("collar", g + fwd * 0.36, g + fwd * 0.4, 0.045, 0.045, mg, 10),
             tube("core", hc - fwd * 0.12, hc + fwd * 0.12, 0.08, 0.08, mt, 10), ball("cap", 0.08, hc + fwd * 0.14, mg, (1, 1, 0.8))]
    for k in range(3):
        parts.append(tube("wrap%d" % k, g + fwd * (-0.08 + k * 0.07), g + fwd * (-0.06 + k * 0.07), 0.034, 0.034, mg, 8))
    for k in range(6):
        a = math.tau * k / 6
        d = side * math.cos(a) + ridge * math.sin(a)
        parts.append(_flange("flange%d" % k, hc, fwd, d, 0.18, 0.28, 0.03, mm))
    return parts


def _maul_2h(g, fwd, mm, mg, ml, mt):
    """Malho de duas mãos: cabo longo com tiras e ponteira, cabeça larga chanfrada com faixas de ouro e espigão."""
    side = Vector((1, 0, 0))
    hc = g + fwd * 0.94
    parts = [tube("shaft", g - fwd * 0.34, g + fwd * 0.84, 0.032, 0.03, ml, 8), tube("butt", g - fwd * 0.4, g - fwd * 0.33, 0.04, 0.036, mm, 8),
             tube("collar", g + fwd * 0.78, g + fwd * 0.84, 0.05, 0.05, mg, 10),
             tube("head", hc - side * 0.2, hc + side * 0.2, 0.12, 0.12, mm, 8)]
    for sx in (-1, 1):
        parts += [tube("face%d" % sx, hc + side * sx * 0.2, hc + side * sx * 0.25, 0.115, 0.09, mm, 8),
                  tube("band%d" % sx, hc + side * sx * 0.12, hc + side * sx * 0.17, 0.128, 0.128, mt, 8)]
    parts.append(tube("spike", hc + fwd * 0.1, hc + fwd * 0.26, 0.05, 0.004, mg, 8))
    for k in range(4):
        parts.append(tube("wrap%d" % k, g + fwd * (-0.26 + k * 0.12), g + fwd * (-0.235 + k * 0.12), 0.037, 0.037, mg, 8))
    return parts


def _flange(name, c, fwd, d, out, length, thick, material):
    """Flange da maça: lâmina em trapézio saindo do núcleo na direção `d`, ao longo de `fwd`."""
    bm = bmesh.new()
    n = fwd.cross(d).normalized() * thick * 0.5
    pts = [c - fwd * length * 0.5 + d * 0.05, c + fwd * length * 0.5 + d * 0.05,
           c + fwd * length * 0.3 + d * out, c - fwd * length * 0.3 + d * out]
    top = [bm.verts.new(p + n) for p in pts]
    bot = [bm.verts.new(p - n) for p in pts]
    bm.faces.new(top)
    bm.faces.new(list(reversed(bot)))
    for i in range(4):
        k = (i + 1) % 4
        bm.faces.new((top[i], top[k], bot[k], bot[i]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    return mesh_from(name, bm, material)


def kit_weapon(base, wtype, hand, mats):
    """Arma do kit na mão principal (.R; arco na .L) ou secundária (.L; escudo no antebraço)."""
    side = ".L" if (hand == "off" or wtype == "bow") else ".R"
    sx = 1.0 if side == ".L" else -1.0
    g = hand_center(base, side)
    fwd = Vector((0, -0.55, 0.83)).normalized()
    mm, mg, mw, ml, mt = mats["metal"], mats["trim"], mats["wood"], mats["leather"], mats["tint"]
    bone = "hand" + side
    parts = []
    if wtype == "sword":
        parts = [tube("grip", g - fwd * 0.08, g + fwd * 0.08, 0.026, 0.026, ml, 6), ball("pommel", 0.04, g - fwd * 0.1, mg),
                 box("guard", (0.26, 0.055, 0.05), g + fwd * 0.1, mg, 0.01), tube("blade", g + fwd * 0.12, g + fwd * 0.82, 0.06, 0.02, mm, 4)]
    elif wtype == "sword2h":
        parts = [tube("grip", g - fwd * 0.18, g + fwd * 0.1, 0.028, 0.028, ml, 6), ball("pommel", 0.045, g - fwd * 0.2, mg),
                 box("guard", (0.36, 0.06, 0.06), g + fwd * 0.12, mg, 0.012), tube("blade", g + fwd * 0.14, g + fwd * 1.18, 0.085, 0.025, mm, 4)]
    elif wtype == "mace":
        parts = _mace_1h(g, fwd, mm, mg, ml, mt)
    elif wtype == "mace2h":
        parts = _maul_2h(g, fwd, mm, mg, ml, mt)
    elif wtype == "axe":
        parts = [tube("shaft", g - fwd * 0.1, g + fwd * 0.5, 0.024, 0.024, mw, 6),
                 ball("axehead", 0.13, g + fwd * 0.44 + Vector((0, -0.08, 0)), mm, (0.18, 0.8, 0.7))]
    elif wtype == "axe2h":
        up = Vector((0, -0.25, 1)).normalized()
        parts = [tube("shaft", g - up * 0.18, g + up * 0.75, 0.024, 0.024, mw, 6),
                 ball("axehead", 0.2, g + up * 0.66 + Vector((0, -0.12, 0)), mm, (0.18, 1.0, 0.85)),
                 box("socket", (0.06, 0.07, 0.12), g + up * 0.66, mg, 0.01)]
    elif wtype == "dagger":
        f2 = Vector((0, -1, 0.3)).normalized()
        parts = [tube("grip", g - f2 * 0.05, g + f2 * 0.05, 0.018, 0.018, ml, 6), box("guard", (0.1, 0.03, 0.03), g + f2 * 0.06, mg, 0.006),
                 tube("blade", g + f2 * 0.07, g + f2 * 0.32, 0.03, 0.006, mm, 4)]
    elif wtype == "bow":
        pts = [g + Vector((0.0, -0.12 * (1 - t * t) + 0.02, t * 0.45)) for t in [i / 4 - 1 for i in range(9)]]
        parts = [tube("limb%d" % i, pts[i], pts[i + 1], 0.018, 0.018, mw, 6) for i in range(8)]
        parts.append(tube("string", pts[0], pts[-1], 0.004, 0.004, mat("m_string", (0.95, 0.95, 0.9)), 4))
    elif wtype in ("staff", "wand"):
        ln = 1.15 if wtype == "staff" else 0.42
        up = Vector((0.22 * sx, -0.12, 1.0)).normalized()
        top = g + up * (ln * (0.55 if wtype == "staff" else 0.75))
        parts = [tube("shaft", g - up * (ln * (0.45 if wtype == "staff" else 0.25)), top, 0.022, 0.028, mw, 6),
                 tube("cap", top, top + up * 0.05, 0.045, 0.035, mg, 8),
                 ball("orb", 0.085 if wtype == "staff" else 0.05, top + up * 0.13, mt)]
    elif wtype == "scepter":
        import bishop_sets
        up = Vector((0.22 * sx, -0.12, 1.0)).normalized()
        parts = bishop_sets.scepter_parts(sys.modules[__name__], "sc_", g, up, mats, {"head": "orb"}, mt)
    elif wtype == "rifle":
        import ranger_sets
        parts = ranger_sets.rifle_parts(sys.modules[__name__], "rf_", g, mats, {"bands": 2})
    elif wtype == "scythe":
        top = g + Vector((0, 0, 0.85))
        parts = [tube("shaft", g - Vector((0, 0, 0.3)), top, 0.022, 0.022, mat("m_darkwood", (0.25, 0.2, 0.25), 0.8), 6)]
        prev = top
        for i in range(1, 7):
            a = i / 6
            p = top + Vector((0, -0.55 * a, 0.08 * math.sin(a * math.pi) - 0.18 * a * a))
            parts.append(tube("blade%d" % i, prev, p, 0.05 * (1 - a) + 0.008, 0.05 * (1 - a * 0.9) + 0.006, mm, 4))
            prev = p
    elif wtype == "shield":
        bone = "forearm.L"
        return kit_shield(base, "juramento", "wpn_%s_shield" % hand, mats)
    elif wtype == "orb":
        oc = g + Vector((0.05 * sx, -0.1, 0.13))
        parts = [ball("orb", 0.085, oc, mt), tube("ring", oc + Vector((0, 0, -0.012)), oc + Vector((0, 0, 0.012)), 0.11, 0.11, mg, 16)]
    obj = _join(parts, "wpn_%s_%s" % (hand, wtype))
    _smooth(obj.data)
    skin_rigid(obj, base["rig"], bone)
    return obj


# ---------------------------------------------------------------------------
# conjuntos lendários com visual próprio (estilo do kit = id curto; o item usa armor_style igual)
# referência: reference/<classe>/set_N/frente.PNG e costas.PNG
# ---------------------------------------------------------------------------
def blade(name, root, tip, width, thick, material, wdir=(1, 0, 0), mid=0.45):
    """Lâmina/aleta afinando até a ponta: losango alongado de root a tip, largura no sentido wdir."""
    root, tip = Vector(root), Vector(tip)
    w = Vector(wdir).normalized() * width * 0.5
    ax = tip - root
    n = ax.cross(w).normalized() * thick * 0.5
    m = root + ax * mid
    bm = bmesh.new()
    pts = [root - w * 0.55, m - w, tip, m + w, root + w * 0.55]
    top = [bm.verts.new(p + n) for p in pts]
    bot = [bm.verts.new(p - n) for p in pts]
    bm.faces.new(top)
    bm.faces.new(list(reversed(bot)))
    for i in range(len(pts)):
        k = (i + 1) % len(pts)
        bm.faces.new((top[i], top[k], bot[k], bot[i]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    return mesh_from(name, bm, material)


def _rigid(objs, rig, bone):
    for o in objs:
        _smooth(o.data)
        skin_rigid(o, rig, bone)
    return objs


def kit_set_pal1(base, mats):
    """Paladino lv5 (reference/paladin/set_1): placa roxa (tint = cor do item) sobre traje branco canelado.
    Elmo com crista central e duas aletas tipo orelha, viseira até o queixo; ombreiras em bloco;
    emblema em V no peito e nas costas; manoplas grandes com punho escuro; faldas laterais; joelheiras; botas."""
    rig, body, b, j = base["rig"], base["body"], base["b"], base["j"]
    t, wh = mats["tint"], mats["white"]
    dark = mats["dark"]
    P = "arm_pal1_"
    # ---------- cabeça ----------
    c = Vector(base["head_c"])
    r = b["head"]
    head = [_shell(P + "head_helm", c, r * 1.16, 0.12, -0.62, -0.3, 0.035, t),
            box(P + "head_visor", (r * 1.2, 0.09, r * 0.62), c + Vector((0, -r * 1.02, -r * 0.42)), t, 0.04),
            box(P + "head_slit", (r * 0.14, 0.1, r * 0.66), c + Vector((0, -r * 1.08, -r * 0.4)), wh, 0.012),
            box(P + "head_brow", (r * 1.55, 0.05, 0.06), c + Vector((0, -r * 1.08, r * 0.14)), wh, 0.015),
            blade(P + "head_crest", c + Vector((0, -r * 0.95, r * 0.3)), c + Vector((0, -r * 0.1, r * 1.85)), r * 0.42, 0.09, t, (0, 1, 0)),
            blade(P + "head_crest_in", c + Vector((0, -r * 1.0, r * 0.4)), c + Vector((0, -r * 0.3, r * 1.55)), r * 0.16, 0.11, wh, (0, 1, 0))]
    for sx in (-1, 1):
        head.append(blade(P + "head_ear_%d" % sx, c + Vector((sx * r * 0.6, r * 0.05, r * 0.55)),
                          c + Vector((sx * r * 1.0, r * 0.25, r * 1.85)), r * 0.55, 0.08, t, (1, -0.35 * sx, 0)))
        head.append(blade(P + "head_ear_in_%d" % sx, c + Vector((sx * r * 0.66, r * 0.0, r * 0.75)),
                          c + Vector((sx * r * 0.94, r * 0.18, r * 1.6)), r * 0.2, 0.1, wh, (1, -0.35 * sx, 0)))
        head.append(blade(P + "head_spike_%d" % sx, c + Vector((sx * r * 1.08, -r * 0.2, r * 0.05)),
                          c + Vector((sx * r * 1.35, -r * 0.15, r * 0.2)), 0.07, 0.04, t, (0, 0, 1)))
    _rigid(head, rig, "head")
    # ---------- corpo: traje branco + placas ----------
    armor_piece(body, rig, P + "body_suit", "torso", wh, 0.012, 0.012, 0.05)
    armor_piece(body, rig, P + "body_legs", "legs", wh, 0.008, 0.012)
    d = b["depth"]
    front = -b["chest"] * d - 0.03
    chest = [box(P + "body_emblem", (0.15, 0.05, 0.08), (0, front, Z["chest"] + 0.06), t, 0.02),
             blade(P + "body_emblem_v_l", (-0.075, front - 0.005, Z["chest"] + 0.1), (0, front - 0.01, Z["chest"] - 0.04), 0.06, 0.05, t, (0, 1, 0)),
             blade(P + "body_emblem_v_r", (0.075, front - 0.005, Z["chest"] + 0.1), (0, front - 0.01, Z["chest"] - 0.04), 0.06, 0.05, t, (0, 1, 0)),
             ball(P + "body_gem", 0.022, (0, front - 0.035, Z["chest"] + 0.06), wh),
             box(P + "body_back", (0.17, 0.05, 0.12), (0, b["chest"] * d + 0.03, Z["chest"] + 0.02), t, 0.02),
             blade(P + "body_back_v", (0, b["chest"] * d + 0.06, Z["chest"] + 0.08), (0, b["chest"] * d + 0.07, Z["chest"] - 0.1), 0.09, 0.05, dark, (1, 0, 0)),
             box(P + "body_collar", (0.2, 0.17, 0.04), (0, 0, Z["neck"] - 0.01), wh, 0.015)]
    _rigid(chest, rig, "chest")
    belt = tube(P + "body_belt", (0, 0, Z["waist"] - 0.03), (0, 0, Z["waist"] + 0.03), b["waist"] * 1.14, b["waist"] * 1.14, mats["band"], 16)
    for v in belt.data.vertices:
        v.co.y *= d * 1.05
    _smooth(belt.data)
    transfer_weights(belt, body, rig)
    for s, sx in ((".R", -1), (".L", 1)):
        sh = Vector(j["shoulder" + s])
        pa = [box(P + "body_pauldron" + s.replace(".", "_"), (0.22, 0.25, 0.15), sh + Vector((sx * 0.05, 0, 0.03)), t, 0.035),
              box(P + "body_pauldron_rim" + s.replace(".", "_"), (0.23, 0.26, 0.04), sh + Vector((sx * 0.055, 0, -0.055)), wh, 0.014),
              box(P + "body_pauldron_top" + s.replace(".", "_"), (0.13, 0.16, 0.05), sh + Vector((sx * 0.04, 0, 0.12)), t, 0.018),
              box(P + "body_pauldron_stud" + s.replace(".", "_"), (0.05, 0.05, 0.05), sh + Vector((sx * 0.165, -0.06, 0.05)), wh, 0.01)]
        _rigid(pa, rig, "upper_arm" + s)
        hp = Vector(j["hip" + s])
        tas = [box(P + "body_tasset" + s.replace(".", "_"), (0.035, 0.13, 0.17), hp + Vector((sx * (b["thigh"] + 0.03), 0, -0.05)), t, 0.012),
               box(P + "body_tasset_rim" + s.replace(".", "_"), (0.03, 0.15, 0.19), hp + Vector((sx * (b["thigh"] + 0.015), 0, -0.05)), wh, 0.01)]
        _rigid(tas, rig, "thigh" + s)
    # ---------- manoplas ----------
    for s, sx in ((".R", -1), (".L", 1)):
        el, wr = Vector(j["elbow" + s]), Vector(j["wrist" + s])
        mid = el.lerp(wr, 0.55)
        g = [box(P + "gloves_cuff" + s.replace(".", "_"), (0.2, 0.2, 0.17), mid + Vector((sx * 0.015, 0, 0.01)), t, 0.035),
             tube(P + "gloves_band" + s.replace(".", "_"), wr + Vector((0, 0, 0.015)), wr + Vector((0, 0, 0.05)), 0.09, 0.09, wh, 12),
             box(P + "gloves_plate" + s.replace(".", "_"), (0.06, 0.13, 0.11), mid + Vector((sx * 0.11, 0, 0.02)), wh, 0.018),
             box(P + "gloves_top" + s.replace(".", "_"), (0.14, 0.15, 0.04), el.lerp(wr, 0.15) + Vector((sx * 0.01, 0, 0.0)), t, 0.015)]
        _rigid(g, rig, "forearm" + s)
        fist = ball(P + "gloves_fist" + s.replace(".", "_"), b["hand"] * 1.45, hand_center(base, s), t, (1, 1, 1.1))
        _rigid([fist], rig, "hand" + s)
    # ---------- botas e joelheiras ----------
    armor_piece(body, rig, P + "boots_shell", "boots", t, 0.026, 0.016)
    for s, sx in ((".R", -1), (".L", 1)):
        kn, an = Vector(j["knee" + s]), Vector(j["ankle" + s])
        k = [box(P + "boots_knee" + s.replace(".", "_"), (0.18, 0.09, 0.14), kn + Vector((0, -0.08, 0.01)), t, 0.03),
             box(P + "boots_knee_rim" + s.replace(".", "_"), (0.19, 0.08, 0.035), kn + Vector((0, -0.085, -0.07)), wh, 0.012),
             box(P + "boots_knee_side" + s.replace(".", "_"), (0.04, 0.15, 0.13), kn + Vector((sx * 0.085, 0, 0.01)), t, 0.012),
             box(P + "boots_cuff" + s.replace(".", "_"), (0.14, 0.15, 0.04), an + Vector((0, 0, 0.07)), t, 0.012)]
        _rigid(k, rig, "shin" + s)


SET_STYLES = {"pal1": kit_set_pal1}
SET_WEAPONS = {}
import paladin_sets as _paladin_sets      # demais conjuntos do Paladino (construtor paramétrico)
_paladin_sets.register(sys.modules[__name__])
import berserker_sets as _berserker_sets  # conjuntos e machados do Berserker
_berserker_sets.register(sys.modules[__name__])
import bishop_sets as _bishop_sets        # conjuntos, maças, escudos e cetros do Bispo
_bishop_sets.register(sys.modules[__name__])
import druid_sets as _druid_sets          # conjuntos, cajados e maças do Druida (formas: druid_sets.build_forms)
_druid_sets.register(sys.modules[__name__])
import ranger_sets as _ranger_sets        # conjuntos, arcos e mosquetes do Ranger
_ranger_sets.register(sys.modules[__name__])
import assassin_sets as _assassin_sets    # conjuntos, adagas e espadas do Assassino
_assassin_sets.register(sys.modules[__name__])
import elementalist_sets as _elementalist_sets    # conjuntos e cajados do Elementalista
_elementalist_sets.register(sys.modules[__name__])
import necromancer_sets as _necromancer_sets      # conjuntos e foices do Necromancer
_necromancer_sets.register(sys.modules[__name__])


# Kit por classe: corpo + peças comuns + só os conjuntos/armas/escudos da classe. O kit_<male|female> genérico (NPCs) não
# leva nada de conjunto. Cada boneco instancia o kit inteiro, então o tamanho do kit é o custo de GPU por personagem.
CLASS_BODY = {"paladin": "male", "berserker": "male", "bishop": "female", "druid": "female", "ranger": "female",
              "assassin": "male", "elementalist": "female", "necromancer": "male"}
CLASS_PREFIX = {"paladin": "pal", "berserker": "ber", "bishop": "bis", "druid": "dru", "ranger": "ran", "assassin": "ass", "elementalist": "ele", "necromancer": "nec"}        # prefixo dos estilos de conjunto de cada classe
SHIELD_CLASSES = ("paladin", "bishop")                       # só eles empunham escudo


def style_class(key):
    """Classe dona de um estilo/arma de conjunto (pelo prefixo), ou None se for peça comum."""
    for cid, pre in CLASS_PREFIX.items():
        if key.startswith(pre):
            return cid
    return None


def build_kit(sex, out_dir=None, class_id=None):
    """Monta um kit (corpo + peças + armas + animações). class_id: kit da classe (com os conjuntos dela); None = genérico.
    Exporta kit_<classe>.glb (ou kit_<sexo>.glb) se out_dir."""
    import os
    clear()
    base = build_base("base", sex, 0.0, KIT_HAIR, "hair")
    import looks                          # cabelos, barbas e olhos da criação de personagem
    looks.build_looks(sys.modules[__name__], base)
    mats = _kit_mats()
    for style, slots in KIT_STYLES.items():
        for slot, plist in slots.items():
            for part, opt in plist:
                kit_piece(base, style, slot, part, opt, mats)
        if style != "cape":
            kit_head(base, style, mats)
    for key, fn in SET_STYLES.items():
        if class_id is not None and style_class(key) == class_id:
            fn(base, mats)
    for t in KIT_MAIN:
        kit_weapon(base, t, "main", mats)
    for t in KIT_OFF:
        kit_weapon(base, t, "off", mats)
    for key, fn in SET_WEAPONS.items():      # armas próprias dos conjuntos (wpn_main_<tipo>_<estilo>)
        if class_id is not None and style_class(key) == class_id:
            fn(base, mats)
    import shield_kit
    if class_id in SHIELD_CLASSES:
        for style in shield_kit.FAMILIES:
            if style_class(style) in (None, class_id):
                kit_shield(base, style, "wpn_off_shield_" + style, mats)
        kit_shield_grip(base, mats)
    animate(base["rig"], "all")
    animate_combat(base["rig"])
    animate_v3(base["rig"])
    # Godot não aceita "." em nome de nó
    for o in bpy.context.scene.objects:
        if "." in o.name:
            o.name = o.name.replace(".", "_")
    if out_dir:
        os.makedirs(out_dir, exist_ok=True)
        export_glb(base["rig"], os.path.join(out_dir, ("kit_%s_%s.glb" % (class_id, sex)) if class_id else "kit_%s.glb" % sex))
    return base


def build_kits(out_dir, only=None):
    """Kits genéricos (NPCs) e um por classe. only = lista de classes (e/ou "male"/"female") para refazer só essas."""
    for sex in ("male", "female"):
        if only is None or sex in only:
            build_kit(sex, out_dir)
    for cid in CLASS_BODY:                    # cada classe nos dois sexos (escolha na criação)
        if only is None or cid in only:
            for sex in ("male", "female"):
                build_kit(sex, out_dir, cid)
    print("kits done")
