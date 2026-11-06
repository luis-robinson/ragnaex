"""Monstros "esculpidos" (substitui as primitivas de build_monsters): formas orgânicas com Skin/Subsurf,
olhos com brilho, focinho, orelhas, rabo... Usa o mesmo rig (MOB_BONES) e animações de build_monsters,
então o jogo não muda. Humanoides (bandido, esqueleto) saem do kit chibi.

    import mob_kit; mob_kit.build_all(r"<pasta>/ragnaex/assets/models")
"""
import bpy
import importlib
import math
import os
from mathutils import Vector, Matrix

import chibi_kit as ck
import lowpoly_lib as lp
import build_monsters as bm

importlib.reload(ck)
importlib.reload(lp)
importlib.reload(bm)


# ---------------------------------------------------------------------------
# helpers
# ---------------------------------------------------------------------------
def skin_body(name, pts, edges, material, sub=2):
    """Corpo contínuo a partir de um 'esqueleto de vértices' [(pos, raio)] + arestas."""
    me = bpy.data.meshes.new(name + "_mesh")
    me.from_pydata([p for p, _r in pts], edges, [])
    obj = ck._link(bpy.data.objects.new(name, me))
    sk = obj.modifiers.new("skin", "SKIN")
    sk.branch_smoothing = 0.7
    sk.use_smooth_shade = True
    for i, (_p, r) in enumerate(pts):
        sv = me.skin_vertices[0].data[i]
        sv.radius = (r, r) if not isinstance(r, tuple) else r
        sv.use_root = i == 0
    ss = obj.modifiers.new("sub", "SUBSURF")
    ss.levels = sub
    ck._bake(obj)
    obj.data.materials.append(material)
    ck._smooth(obj.data)
    return obj


def blob(name, r, center, material, scale=(1, 1, 1), cuts=3):
    o = ck.quad_sphere(name, r, (0, 0, 0), cuts=cuts)
    for v in o.data.vertices:
        v.co = Vector((v.co.x * scale[0], v.co.y * scale[1], v.co.z * scale[2])) + Vector(center)
    o.data.materials.append(material)
    return o


def cone(name, root, tip, r, material, segs=8):
    """Chifre/orelha/presa: cone liso da raiz até a ponta."""
    return ck.tube(name, root, tip, r, r * 0.08, material, segs)


def eyes(prefix, centers, size, m_eye, m_white, look=(0, -1, 0)):
    """Olhos ovais escuros com brilho branco (estilo ToS)."""
    out = []
    for i, c in enumerate(centers):
        c = Vector(c)
        out.append(blob("%s_eye%d" % (prefix, i), size, c, m_eye, (0.85, 0.45, 1.25), 2))
        out.append(blob("%s_hl%d" % (prefix, i), size * 0.32, c + Vector((size * 0.25, look[1] * size * 0.4, size * 0.4)), m_white, (1, 1, 1), 1))
    return out


def finish(arm, parts):
    for obj, bone in parts:
        ck._smooth(obj.data)
        lp.attach(obj, arm, bone)


def base_mats():
    return ck.mat("m_eye", (0.08, 0.06, 0.1), 0.25), ck.mat("m_white", (1, 1, 1), 0.3, 0.6)


# ---------------------------------------------------------------------------
# slime: gota brilhante com olhão
# ---------------------------------------------------------------------------
def slime(cid="mob_slime", color=(0.42, 0.88, 0.48)):
    arm = lp.make_armature("rig_" + cid, bm.MOB_BONES)
    m = ck.mat("m_slime_%s" % cid, color, 0.15)
    m_eye, m_white = base_mats()
    body = blob("body", 0.5, (0, 0, 0), m, cuts=4)
    for v in body.data.vertices:
        z = v.co.z
        # gota: base achatada e larga, topo afunilado
        k = 1.0 + 0.18 * max(0.0, -z / 0.5) - 0.25 * max(0.0, z / 0.5) ** 2
        v.co.x *= k
        v.co.y *= k
        v.co.z = max(z * 0.78, -0.3) + 0.42
    parts = [(body, "body"),
             (blob("shine", 0.09, (0.17, -0.3, 0.72), m_white, (1, 0.5, 0.7)), "body"),
             (blob("shine2", 0.04, (0.27, -0.24, 0.62), m_white), "body")]
    parts += [(o, "body") for o in eyes("s", [(-0.17, -0.41, 0.52), (0.15, -0.41, 0.52)], 0.1, m_eye, m_white)]
    parts.append((ck.tube("mouth", (-0.05, -0.47, 0.35), (0.05, -0.47, 0.35), 0.018, 0.018, m_eye, 6), "body"))
    finish(arm, parts)
    z = (0, 0, 0)
    lp.add_action(arm, "idle", {"body": [(1, (0, 0, 0), z), (16, (0, 0, 0), (0, 0, 0.08)), (32, (0, 0, 0), z)]}, 32)
    lp.add_action(arm, "run", {"body": [(1, (0, 0, 0), z), (6, (12, 0, 0), (0, 0, 0.32)), (12, (0, 0, 0), z)]}, 12)
    lp.add_action(arm, "attack", {"body": [(1, (-15, 0, 0), z), (6, (25, 0, 0), (0, -0.3, 0.2)), (14, (0, 0, 0), z)]}, 14, loop=False)
    lp.add_action(arm, "hit", {"body": [(1, (-20, 0, 0), (0, 0.1, -0.05)), (8, (0, 0, 0), z)]}, 8, loop=False)
    lp.add_action(arm, "die", {"root": [(1, (0, 0, 0), z), (20, (0, 0, 0), (0, 0, -0.35))]}, 20, loop=False)
    return arm


# ---------------------------------------------------------------------------
# quadrúpedes: lobo, javali, dragão
# ---------------------------------------------------------------------------
def quadruped(cid, fur, dark, light, kind="wolf"):
    hip0 = 0.4 if kind == "boar" else (0.5 if kind == "bear" else 0.45)
    # rabo com osso próprio (balança no idle e ondula na corrida); só os quadrúpedes têm
    arm = lp.make_armature("rig_" + cid, dict(bm.MOB_BONES, tail=((0, 0.52, hip0 + 0.14), (0, 0.9, hip0 + 0.2), "body")))
    m = ck.mat("m_%s_fur" % cid, fur, 0.8)
    md = ck.mat("m_%s_dark" % cid, dark, 0.8)
    ml = ck.mat("m_%s_light" % cid, light, 0.8)
    m_eye, m_white = base_mats()
    m_horn = ck.mat("m_horn", (0.95, 0.9, 0.78), 0.5)
    boar, dragon, bear = kind == "boar", kind == "dragon", kind == "bear"
    griffin = kind == "griffin"
    bulk = 1.25 if boar else (1.15 if dragon else (1.45 if bear else 1.0))
    hip = 0.4 if boar else (0.5 if bear else 0.45)
    # tronco contínuo: anca -> peito -> pescoço
    pts = [((0, 0.42, hip + 0.02), 0.2 * bulk), ((0, 0.05, hip + 0.06), 0.23 * bulk), ((0, -0.32, hip + 0.08), 0.25 * bulk),
           ((0, -0.55, hip + 0.18), 0.15 * bulk)]
    body = skin_body("body", pts, [(0, 1), (1, 2), (2, 3)], m)
    parts = [(body, "body")]
    # barriga clara
    parts.append((blob("belly", 0.19 * bulk, (0, -0.08, hip - 0.08), ml, (0.85, 1.9, 0.6)), "body"))
    # cabeça + focinho
    hc = Vector((0, -0.74 - (0.06 if bear else 0.0), hip + 0.28))
    parts.append((blob("head", 0.2 * bulk, hc, m, (0.95, 1.0, 0.9)), "head"))
    if boar:
        parts.append((blob("snout", 0.13, hc + Vector((0, -0.2, -0.05)), ml, (0.85, 1.0, 0.8)), "head"))
        parts.append((ck.tube("nose", hc + Vector((0, -0.3, -0.05)), hc + Vector((0, -0.34, -0.05)), 0.09, 0.09, md, 12), "head"))
        for sx in (-1, 1):
            parts.append((cone("tusk%d" % sx, hc + Vector((sx * 0.08, -0.26, -0.1)), hc + Vector((sx * 0.13, -0.32, 0.06)), 0.035, m_horn), "head"))
            parts.append((cone("ear%d" % sx, hc + Vector((sx * 0.13, -0.02, 0.15)), hc + Vector((sx * 0.22, 0.04, 0.3)), 0.06, md), "head"))
        # crina de cerdas no dorso
        for i in range(6):
            y = -0.45 + i * 0.15
            parts.append((cone("bristle%d" % i, (0, y, hip + 0.27 * bulk), (0, y + 0.06, hip + 0.42 * bulk), 0.05, md), "body"))
    elif griffin:
        # cabeça de águia clara, bico curvo dourado, tufos de pena no lugar das orelhas
        parts.append((blob("crest", 0.2, hc + Vector((0, 0.02, 0.04)), ml, (1.05, 1.1, 1.05)), "head"))
        beak = ck.mat("m_%s_beak" % cid, (0.98, 0.78, 0.3), 0.5)
        parts.append((cone("beak", hc + Vector((0, -0.14, 0.0)), hc + Vector((0, -0.34, -0.08)), 0.08, beak), "head"))
        parts.append((cone("beak_hook", hc + Vector((0, -0.3, -0.05)), hc + Vector((0, -0.34, -0.14)), 0.035, beak), "head"))
        for sx in (-1, 1):
            parts.append((cone("tuft%d" % sx, hc + Vector((sx * 0.1, 0.04, 0.14)), hc + Vector((sx * 0.16, 0.2, 0.3)), 0.05, ml), "head"))
        parts.append((blob("ruff", 0.22, (0, -0.52, hip + 0.2), ml, (1.2, 0.8, 1.05)), "body"))
    else:
        parts.append((blob("snout", 0.12 * bulk, hc + Vector((0, -0.2, -0.05)), ml if not dragon else m, (0.6, 1.0, 0.55)), "head"))
        parts.append((blob("nose", 0.045 * bulk, hc + Vector((0, -0.32 * bulk, -0.01)), md), "head"))
        for sx in (-1, 1):
            if dragon:
                parts.append((cone("horn%d" % sx, hc + Vector((sx * 0.1, 0.05, 0.15)), hc + Vector((sx * 0.2, 0.32, 0.4)), 0.05, m_horn), "head"))
            elif kind == "lynx":   # orelha pontuda com tufo escuro
                parts.append((cone("ear%d" % sx, hc + Vector((sx * 0.11, 0.02, 0.14)), hc + Vector((sx * 0.14, 0.05, 0.36)), 0.065, m), "head"))
                parts.append((cone("tuft%d" % sx, hc + Vector((sx * 0.14, 0.05, 0.34)), hc + Vector((sx * 0.15, 0.06, 0.46)), 0.02, md), "head"))
            elif bear:          # orelha redonda
                parts.append((blob("ear%d" % sx, 0.07 * bulk, hc + Vector((sx * 0.14 * bulk, 0.02, 0.17 * bulk)), m, (1, 0.6, 1)), "head"))
            else:
                parts.append((cone("ear%d" % sx, hc + Vector((sx * 0.11, 0.02, 0.14)), hc + Vector((sx * 0.15, 0.05, 0.36)), 0.065, m), "head"))
    parts += [(o, "head") for o in eyes(cid, [hc + Vector((sx * 0.1 * bulk, -0.16 * bulk, 0.07)) for sx in (-1, 1)], 0.045 * bulk, m_eye, m_white)]
    if kind == "wolf":
        # juba de pelos escuros no pescoço
        parts.append((blob("mane", 0.24, (0, -0.5, hip + 0.18), md, (1.15, 0.85, 1.0)), "body"))
    # pernas: tubo + pata
    leg_r = (0.09 if kind == "wolf" else (0.075 * 1.25 if bear else 0.075)) * bulk
    for bone, sx, sy in (("leg_fr", 1, -1), ("leg_fl", -1, -1), ("leg_br", 1, 1), ("leg_bl", -1, 1)):
        top = Vector((sx * 0.17 * bulk, sy * 0.36, hip))
        foot = Vector((sx * 0.19 * bulk, sy * 0.38, 0.07))
        parts.append((ck.tube("leg_" + bone, top, foot, leg_r, leg_r * 0.8, m, 8), bone))
        parts.append((blob("paw_" + bone, leg_r * 1.15, foot + Vector((0, -0.02, -0.01)), md, (1, 1.2, 0.7)), bone))
    # rabo
    if dragon:
        prev = Vector((0, 0.55, hip + 0.02))
        for i in range(1, 6):
            p = Vector((0, 0.55 + i * 0.2, hip - i * 0.05 + 0.08 * math.sin(i)))
            parts.append((ck.tube("tail%d" % i, prev, p, 0.15 * (1 - i / 7), 0.15 * (1 - (i + 1) / 7), m, 10), "body"))
            prev = p
        parts.append((cone("tail_tip", prev, prev + Vector((0, 0.18, 0.02)), 0.08, md), "body"))
        # asas: membrana triangular em leque + osso
        for sx in (-1, 1):
            sh = Vector((sx * 0.18, -0.2, hip + 0.3))
            tips = [sh + Vector((sx * 0.9, 0.2, 0.55)), sh + Vector((sx * 1.0, 0.55, 0.15)), sh + Vector((sx * 0.7, 0.75, -0.05))]
            bmesh_w = __import__("bmesh").new()
            vs = [bmesh_w.verts.new(sh)] + [bmesh_w.verts.new(t) for t in tips]
            bmesh_w.faces.new((vs[0], vs[1], vs[2]))
            bmesh_w.faces.new((vs[0], vs[2], vs[3]))
            wing = ck.mesh_from("wing%d" % sx, bmesh_w, md)
            sol = wing.modifiers.new("sol", "SOLIDIFY")
            sol.thickness = 0.03
            ck._bake(wing)
            parts.append((wing, "body"))
            parts.append((ck.tube("wingbone%d" % sx, sh, tips[0], 0.035, 0.02, m_horn, 6), "body"))
        for i in range(5):
            y = -0.4 + i * 0.2
            parts.append((cone("spike%d" % i, (0, y, hip + 0.28 * bulk), (0, y + 0.08, hip + 0.45 * bulk), 0.06, m_horn), "body"))
    elif griffin:
        # asas de penas (leque de lâminas) dobradas para trás e rabo de leão com tufo
        for sx in (-1, 1):
            sh = Vector((sx * 0.16, -0.22, hip + 0.28))
            for k in range(4):
                tip = sh + Vector((sx * (0.45 + k * 0.1), 0.25 + k * 0.2, 0.42 - k * 0.12))
                parts.append((ck.blade("feather%d_%d" % (sx, k), sh, tip, 0.34 - k * 0.04, 0.025, md if k % 2 else m, (0, 0, 1), 0.85), "body"))
            parts.append((ck.tube("wingbone%d" % sx, sh, sh + Vector((sx * 0.5, 0.2, 0.46)), 0.035, 0.02, ml, 6), "body"))
        tpts = [((0, 0.4, hip + 0.1), 0.05), ((0, 0.62, hip + 0.06), 0.04), ((0, 0.8, hip + 0.1), 0.035)]
        parts.append((skin_body("tail", tpts, [(0, 1), (1, 2)], m), "body"))
        parts.append((blob("tail_tip", 0.07, (0, 0.84, hip + 0.12), md, (0.9, 1.3, 0.9)), "body"))
    elif boar:
        parts.append((cone("tail", (0, 0.6, hip + 0.1), (0, 0.72, hip + 0.02), 0.03, md), "body"))
    elif bear:
        parts.append((blob("tail", 0.07 * bulk, (0, 0.6, hip + 0.16), m, (1, 1, 1)), "body"))
    elif kind == "lynx":         # rabo curto de ponta escura e manchas no dorso
        parts.append((blob("tail", 0.075, (0, 0.47, hip + 0.17), m, (0.85, 1.7, 0.85)), "body"))        # sai de dentro da anca (o tronco acaba em y≈0,45)
        parts.append((blob("tail_tip", 0.055, (0, 0.6, hip + 0.19), md, (0.85, 1.1, 0.85)), "body"))
        for i, (x, y) in enumerate(((0.1, -0.25), (-0.12, -0.05), (0.08, 0.15), (-0.06, 0.3), (0.13, 0.35))):
            parts.append((blob("spot%d" % i, 0.04, (x, y, hip + 0.22), md, (1, 1, 0.4)), "body"))
        parts.append((blob("hump", 0.2 * bulk, (0, -0.3, hip + 0.3 * bulk), m, (1.1, 1.0, 0.7)), "body"))
    else:
        # rabo de lobo: cheio e afinando, sobe um pouco e cai na ponta clara (não um disco achatado)
        tpts = [((0, 0.4, hip + 0.12), 0.1), ((0, 0.6, hip + 0.17), 0.095), ((0, 0.74, hip + 0.15), 0.1), ((0, 0.86, hip + 0.08), 0.08), ((0, 0.94, hip + 0.02), 0.045)]
        parts.append((skin_body("tail", tpts, [(0, 1), (1, 2), (2, 3), (3, 4)], m), "body"))
        parts.append((blob("tail_tip", 0.055, (0, 0.93, hip + 0.03), ml, (0.95, 1.2, 0.95)), "body"))
    for i, (o, bone) in enumerate(parts):          # tudo que é rabo vai para o osso do rabo
        if bone == "body" and o.name.startswith("tail"):
            o.name = "fur_" + o.name                  # nome igual ao osso "tail" faz o import do Godot renomear o osso
            parts[i] = (o, "tail")
    finish(arm, parts)
    bm.mob_actions(arm, quadruped=True)
    quad_motion(arm, kind)
    return arm


def _drop_clips(arm, names):
    ad = arm.animation_data
    for t in list(ad.nla_tracks if ad else []):
        if t.name in names:
            ad.nla_tracks.remove(t)


def quad_motion(arm, kind):
    """idle e corrida dos quadrúpedes (troca os do build_monsters): idle respira, olha em volta e abana o rabo;
    corrida em galope (patas da frente e de trás em pares opostos, corpo balança, cabeça compensa, rabo ondula).
    Urso: passo pesado, mais lento, rola de lado. Rig: corpo loc Y = cima, X- = empina; pernas X- = para a frente;
    cabeça Z = olha para o lado; rabo X = sobe/desce, Z = balança."""
    _drop_clips(arm, ("idle", "run"))
    heavy = kind in ("bear", "boar")
    tau = math.tau
    # idle: 48 quadros (2 s)
    n = 48
    k_idle = {b: [] for b in ("body", "head", "tail", "leg_fr", "leg_fl")}
    for f in range(1, n + 1, 3):
        p = (f - 1) / (n - 1) * tau
        k_idle["body"].append((f, (1.5 * math.sin(p), 0, 0), (0, 0.018 * (0.5 - 0.5 * math.cos(p)), 0)))
        look = math.sin(p) * (8 if heavy else 14)
        k_idle["head"].append((f, (3 + 3 * math.sin(2 * p), 0, look), (0, 0, 0)))
        wag = math.sin(2 * p) * (6 if heavy else 16)
        k_idle["tail"].append((f, (10 if not heavy else 4, 0, wag), (0, 0, 0)))
        k_idle["leg_fr"].append((f, (2 * math.sin(p), 0, 0), (0, 0, 0)))
        k_idle["leg_fl"].append((f, (-2 * math.sin(p), 0, 0), (0, 0, 0)))
    for b in k_idle:
        k_idle[b].append((n, k_idle[b][0][1], k_idle[b][0][2]))
    lp.add_action(arm, "idle", k_idle, n)
    # corrida: galope (lobo/lince/cão) ou passo pesado (urso/javali)
    n = 14 if heavy else 10
    legs_a = 34 if heavy else 50
    back_a = 30 if heavy else 42
    lift = 0.06 if heavy else 0.11
    pitch = 4 if heavy else 8
    roll = 5 if heavy else 1.5
    k_run = {b: [] for b in ("body", "head", "tail", "leg_fr", "leg_fl", "leg_br", "leg_bl")}
    for f in range(1, n + 1):
        p = (f - 1) / (n - 1) * tau
        k_run["body"].append((f, (-pitch * math.cos(p), 0, roll * math.sin(p)), (0, lift * (0.5 + 0.5 * math.sin(p)), 0)))
        k_run["head"].append((f, (0.6 * pitch * math.cos(p) + 4, 0, -0.5 * roll * math.sin(p)), (0, 0, 0)))
        k_run["leg_fr"].append((f, (-legs_a * math.sin(p), 0, 0), (0, 0, 0)))
        k_run["leg_fl"].append((f, (-legs_a * math.sin(p - 0.45), 0, 0), (0, 0, 0)))
        k_run["leg_br"].append((f, (back_a * math.sin(p + 0.25), 0, 0), (0, 0, 0)))
        k_run["leg_bl"].append((f, (back_a * math.sin(p - 0.2), 0, 0), (0, 0, 0)))
        k_run["tail"].append((f, (-8 + 10 * math.sin(p - 1.2), 0, (4 if heavy else 9) * math.sin(p + 0.6)), (0, 0, 0)))
    lp.add_action(arm, "run", k_run, n)


HIP = 0.58
# Rig próprio do cavalo: pernas em 2 ossos (joelho/jarrete), pescoço + cabeça, rabo em 2 ossos.
# Eixos (testados): osso que desce, +X leva a ponta para trás; osso que sobe, +X inclina para a frente;
# osso para a frente, +X levanta a ponta; root: location Y = para cima.
HORSE_LEGS = {          # osso: (x, y topo, y joelho, z joelho, y casco, dianteira?)
    "leg_fr": (0.12, -0.33, -0.34, 0.28, -0.34, True),
    "leg_fl": (-0.12, -0.33, -0.34, 0.28, -0.34, True),
    "leg_br": (0.12, 0.34, 0.41, 0.3, 0.37, False),
    "leg_bl": (-0.12, 0.34, 0.41, 0.3, 0.37, False),
}


def horse_bones():
    h = HIP
    b = {
        "root": ((0, 0, 0), (0, 0, 0.2), None),
        "body": ((0, 0, h), (0, 0, h + 0.3), "root"),
        "neck": ((0, -0.42, h + 0.18), (0, -0.56, h + 0.5), "body"),
        "head": ((0, -0.58, h + 0.55), (0, -0.86, h + 0.46), "neck"),
        "tail": ((0, 0.5, h + 0.2), (0, 0.6, h + 0.08), "body"),
        "tail2": ((0, 0.6, h + 0.08), (0, 0.66, h - 0.22), "tail"),
    }
    for bone, (x, yt, yk, zk, yh, _front) in HORSE_LEGS.items():
        b[bone] = ((x, yt, h + 0.02), (x, yk, zk), "body")
        b[bone + "_lo"] = ((x, yk, zk), (x, yh, 0.0), bone)
    return b


def horse(cid="mob_horse"):
    """Cavalo de montaria (chibi): pernas com joelho/jarrete, pescoço alto com crina, rabo de crina e sela.
    A pelagem é o material "tint" (o jogo pinta uma cor por cavalo). Escalado no jogo (EntityView.HORSE_SCALE)."""
    arm = lp.make_armature("rig_" + cid, horse_bones())
    coat = ck.mat("tint", (0.55, 0.38, 0.24), 0.8)
    mane = ck.mat("m_horse_mane", (0.16, 0.12, 0.1), 0.8)
    hoof = ck.mat("m_horse_hoof", (0.2, 0.17, 0.15), 0.6)
    muzzle = ck.mat("m_horse_muzzle", (0.85, 0.8, 0.72), 0.8)
    leather = ck.mat("m_saddle", (0.36, 0.2, 0.12), 0.7)
    blanket = ck.mat("m_saddle_blanket", (0.7, 0.18, 0.16), 0.8)
    gold = ck.mat("m_saddle_gold", (0.9, 0.7, 0.3), 0.4)
    m_eye, m_white = base_mats()
    h = HIP
    V = Vector
    # barril estreito (as pernas curtas do boneco aparecem dos lados), peito cheio na frente, garupa redonda atrás
    pts = [((0, 0.42, h + 0.1), (0.14, 0.17)), ((0, 0.1, h + 0.1), (0.15, 0.19)), ((0, -0.24, h + 0.1), (0.16, 0.2)),
           ((0, -0.4, h + 0.12), (0.13, 0.17))]
    parts = [(skin_body("barrel", pts, [(0, 1), (1, 2), (2, 3)], coat), "body")]
    parts.append((blob("chest", 0.16, (0, -0.38, h + 0.06), coat, (0.95, 0.9, 1.1)), "body"))
    parts.append((blob("rump", 0.17, (0, 0.38, h + 0.14), coat, (1.0, 1.0, 0.95)), "body"))
    parts.append((blob("belly", 0.15, (0, 0.0, h - 0.02), coat, (0.85, 2.0, 0.6)), "body"))
    # pescoço (osso neck): tubo grosso que afina, crina em tufos na crista
    n0, n1 = V((0, -0.42, h + 0.16)), V((0, -0.57, h + 0.52))
    parts.append((ck.tube("neck_m", n0, n1, 0.12, 0.085, coat, 10), "neck"))
    parts.append((blob("neck_base", 0.13, n0 + V((0, 0.02, 0.02)), coat, (0.95, 1.1, 1.0)), "neck"))
    for k in range(7):
        t = k / 6.0
        p = n0.lerp(n1, t) + V((0, 0.09 - 0.02 * t, 0.06 - 0.02 * t))
        parts.append((blob("mane%d" % k, 0.06, p, mane, (0.7, 1.25, 1.0)), "neck"))
    # cabeça (osso head): crânio + focinho claro, orelhas, olhos, topete
    hc = V((0, -0.67, h + 0.56))
    head = blob("skull", 0.12, (0, 0, 0), coat, (0.85, 1.0, 0.95))
    parts.append((head, "head"))
    for v in head.data.vertices:
        v.co += hc
    snout = blob("snout", 0.1, hc + V((0, -0.15, -0.06)), coat, (0.8, 1.4, 0.85))
    parts.append((snout, "head"))
    parts.append((blob("muzzle", 0.085, hc + V((0, -0.27, -0.1)), muzzle, (0.95, 0.9, 0.85)), "head"))
    for sx in (-1, 1):
        parts.append((cone("ear%d" % sx, hc + V((sx * 0.06, 0.05, 0.08)), hc + V((sx * 0.08, 0.08, 0.22)), 0.035, coat), "head"))
        parts.append((blob("nostril%d" % sx, 0.016, hc + V((sx * 0.035, -0.34, -0.08)), hoof), "head"))
    parts += [(o_, "head") for o_ in eyes(cid, [hc + V((sx * 0.085, -0.04, 0.03)) for sx in (-1, 1)], 0.032, m_eye, m_white, look=(sx, -0.3, 0))]
    parts.append((blob("forelock", 0.05, hc + V((0, -0.05, 0.11)), mane, (0.8, 1.3, 0.6)), "head"))
    # rabo: toco no osso tail, mechas cheias no tail2
    parts.append((ck.tube("tail_dock", V((0, 0.5, h + 0.2)), V((0, 0.6, h + 0.08)), 0.05, 0.045, mane, 8), "tail"))
    for k, (dx, ln) in enumerate(((-0.035, 0.36), (0.0, 0.42), (0.035, 0.36))):
        parts.append((ck.strand("tail_hair%d" % k, V((dx, 0.6, h + 0.1)), ln, 0.1, 0.09, mane, taper=0.55, lean=(dx * 2.0, 0.22)), "tail2"))
    # pernas: braço/coxa no osso de cima, canela/boleto/casco no de baixo
    for bone, (x, yt, yk, zk, yh, front) in HORSE_LEGS.items():
        top, knee, foot = V((x, yt, h + 0.02)), V((x, yk, zk)), V((x, yh, 0.0))
        fet = V((x, yh, 0.1))
        if front:
            parts.append((blob("shoulder_" + bone, 0.085, top + V((0, 0.0, -0.04)), coat, (0.8, 1.0, 1.3)), bone))
            parts.append((ck.tube("arm_" + bone, top, knee, 0.075, 0.048, coat, 8), bone))
        else:
            parts.append((blob("haunch_" + bone, 0.12, top + V((0, -0.02, -0.06)), coat, (0.75, 1.1, 1.3)), bone))
            parts.append((ck.tube("gaskin_" + bone, top + V((0, 0.0, -0.08)), knee, 0.08, 0.045, coat, 8), bone))
        parts.append((blob("knee_" + bone, 0.05, knee, coat), bone + "_lo"))
        parts.append((ck.tube("cannon_" + bone, knee, fet, 0.043, 0.038, coat, 8), bone + "_lo"))
        parts.append((blob("fetlock_" + bone, 0.046, fet, coat), bone + "_lo"))
        parts.append((ck.tube("hoof_" + bone, fet - V((0, 0, 0.02)), foot, 0.05, 0.065, hoof, 8), bone + "_lo"))
    # sela: manta que cobre o lombo, assento com patilha atrás e cabeçote dourado, barrigueira e estribos
    parts.append((blob("blanket", 0.2, (0, -0.02, h + 0.19), blanket, (0.92, 1.15, 0.45)), "body"))
    parts.append((blob("saddle", 0.15, (0, -0.02, h + 0.27), leather, (0.85, 1.05, 0.4)), "body"))
    parts.append((blob("cantle", 0.1, (0, 0.11, h + 0.32), leather, (1.1, 0.35, 0.55)), "body"))
    parts.append((ck.ball("horn", 0.03, (0, -0.15, h + 0.34), gold), "body"))
    for sx in (-1, 1):
        parts.append((ck.tube("strap%d" % sx, (sx * 0.16, -0.04, h + 0.24), (sx * 0.19, -0.04, h + 0.0), 0.012, 0.012, leather, 5), "body"))
        parts.append((ck.tube("stirrup%d" % sx, (sx * 0.19, -0.07, h - 0.01), (sx * 0.19, -0.01, h - 0.01), 0.022, 0.022, gold, 6), "body"))
    finish(arm, parts)
    horse_actions(arm)
    return arm


def _gait_leg(q, duty, amp, flex):
    """Ângulo da perna (osso de cima, +X = para trás) e dobra do joelho numa fase q ∈ [0, 1).
    Apoio: o casco vai de frente para trás em linha; voo: volta para a frente em cosseno com o joelho dobrado."""
    if q < duty:
        return -amp + 2.0 * amp * q / duty, flex * 0.12 * math.sin(math.pi * q / duty)
    s = (q - duty) / (1.0 - duty)
    return amp * math.cos(math.pi * s), flex * math.sin(math.pi * s)


# andadura: (quadros, fase de cada perna, apoio, amplitude, dobra, pulo do corpo, balanço do corpo, cabeça)
GAITS = {
    "walk": (32, {"leg_bl": 0.0, "leg_fl": 0.25, "leg_br": 0.5, "leg_fr": 0.75}, 0.62, 16.0, 45.0, 0.012, 2.0, 5.0),
    "run": (16, {"leg_bl": 0.0, "leg_br": 0.1, "leg_fl": 0.42, "leg_fr": 0.52}, 0.4, 30.0, 85.0, 0.05, 7.0, 9.0),
}


def horse_actions(arm):
    """Clipes do cavalo gerados por laço (um key por quadro, último = primeiro para fechar o loop)."""
    z = (0, 0, 0)
    tau = 2.0 * math.pi
    # idle: respira, abaixa/levanta o pescoço, sacode o rabo, troca o peso de uma pata de trás
    n = 72
    keys = {b: [] for b in ("root", "body", "neck", "head", "tail", "tail2", "leg_bl", "leg_bl_lo")}
    for f in range(n + 1):
        t = f / n
        keys["root"].append((f + 1, z, (0, 0.006 * math.sin(tau * t * 2), 0)))
        keys["body"].append((f + 1, (0.8 * math.sin(tau * t * 2), 0, 0), z))
        keys["neck"].append((f + 1, (5.0 * math.sin(tau * t) + 2.0, 0, 2.5 * math.sin(tau * t + 1.0)), z))
        keys["head"].append((f + 1, (-4.0 * math.sin(tau * t + 0.6), 0, 4.0 * math.sin(tau * t)), z))
        keys["tail"].append((f + 1, (0, 0, 14.0 * math.sin(tau * t * 3)), z))
        keys["tail2"].append((f + 1, (0, 0, 18.0 * math.sin(tau * t * 3 - 0.9)), z))
        keys["leg_bl"].append((f + 1, (-4.0, 0, 0), z))
        keys["leg_bl_lo"].append((f + 1, (-10.0, 0, 0), z))
    lp.add_action(arm, "idle", keys, n + 1)
    for name, (n, phases, duty, amp, flex, bob, pitch, nod) in GAITS.items():
        keys = {b: [] for b in ("root", "body", "neck", "head", "tail", "tail2")}
        for bone in phases:
            keys[bone] = []
            keys[bone + "_lo"] = []
        for f in range(n + 1):
            t = f / n
            for bone, ph in phases.items():
                front = HORSE_LEGS[bone][5]
                a, k = _gait_leg((t - ph) % 1.0, duty, amp * (1.0 if front else 0.9), flex)
                keys[bone].append((f + 1, (a, 0, 0), z))
                # dianteira: o casco dobra para trás (joelho); traseira: para a frente (jarrete)
                keys[bone + "_lo"].append((f + 1, (k if front else -k * 0.8, 0, 0), z))
            if name == "run":       # galope: um voo por passada, o corpo balança (garupa sobe, peito sobe)
                up = bob * math.sin(tau * (t - 0.3))
                bp = pitch * math.sin(tau * (t - 0.05))
                keys["root"].append((f + 1, z, (0, up, 0)))
                keys["body"].append((f + 1, (bp, 0, 0), z))
                keys["neck"].append((f + 1, (-0.9 * bp + nod * math.sin(tau * (t - 0.2)) + 8.0, 0, 0), z))
                keys["head"].append((f + 1, (-0.5 * nod * math.sin(tau * (t - 0.2)) - 6.0, 0, 0), z))
                keys["tail"].append((f + 1, (-20.0 + 6.0 * math.sin(tau * t), 0, 0), z))
                keys["tail2"].append((f + 1, (-25.0 + 10.0 * math.sin(tau * t - 1.2), 0, 4.0 * math.sin(tau * t)), z))
            else:                   # passo: o corpo sobe 2x por passada e o pescoço acena junto
                keys["root"].append((f + 1, z, (0, bob * math.cos(tau * t * 2), 0)))
                keys["body"].append((f + 1, (0, 0, pitch * math.sin(tau * t)), z))
                keys["neck"].append((f + 1, (nod * math.sin(tau * t * 2) + 3.0, 0, 0), z))
                keys["head"].append((f + 1, (-0.5 * nod * math.sin(tau * t * 2), 0, 0), z))
                keys["tail"].append((f + 1, (0, 0, 8.0 * math.sin(tau * t)), z))
                keys["tail2"].append((f + 1, (0, 0, 10.0 * math.sin(tau * t - 0.8)), z))
        lp.add_action(arm, name, keys, n + 1)



# ---------------------------------------------------------------------------
# aranha
# ---------------------------------------------------------------------------
def spider(cid="mob_spider"):
    arm = lp.make_armature("rig_" + cid, bm.MOB_BONES)
    m = ck.mat("m_spider", (0.28, 0.24, 0.32), 0.6)
    ms = ck.mat("m_spider_mark", (0.85, 0.35, 0.3), 0.6)
    m_eye = ck.mat("m_spider_eye", (1.0, 0.25, 0.2), 0.3, 1.5)
    parts = [(blob("abdomen", 0.36, (0, 0.38, 0.5), m, (1, 1.15, 0.9)), "body"),
             (blob("mark", 0.13, (0, 0.36, 0.83), ms, (1, 1.4, 0.3)), "body"),
             (blob("thorax", 0.22, (0, -0.08, 0.42), m), "body"),
             (blob("head", 0.15, (0, -0.32, 0.45), m), "head")]
    for i, (x, z) in enumerate([(-0.07, 0.52), (0.07, 0.52), (-0.11, 0.47), (0.11, 0.47)]):
        parts.append((blob("eye%d" % i, 0.035 if i < 2 else 0.025, (x, -0.44, z), m_eye), "head"))
    for sx in (-1, 1):
        parts.append((cone("fang%d" % sx, (sx * 0.05, -0.44, 0.38), (sx * 0.03, -0.5, 0.26), 0.025, ck.mat("m_horn", (0.95, 0.9, 0.78), 0.5)), "head"))
        for i in range(4):
            y = -0.25 + i * 0.14
            bone = ("leg_fr" if i < 2 else "leg_br") if sx > 0 else ("leg_fl" if i < 2 else "leg_bl")
            root = Vector((sx * 0.15, y, 0.42))
            knee = Vector((sx * 0.5, y + (i - 1.5) * 0.12, 0.72))
            foot = Vector((sx * 0.75, y + (i - 1.5) * 0.25, 0.0))
            parts.append((ck.tube("leg%d%d_a" % (sx, i), root, knee, 0.045, 0.035, m, 6), bone))
            parts.append((ck.tube("leg%d%d_b" % (sx, i), knee, foot, 0.035, 0.012, m, 6), bone))
            parts.append((blob("knee%d%d" % (sx, i), 0.045, knee, m), bone))
    finish(arm, parts)
    bm.mob_actions(arm, quadruped=True)
    return arm


def crab(cid="mob_crab"):
    """Caranguejo do lago: casco largo e chato, 6 patas, pinças grandes nos braços (o golpe padrão é o beliscão),
    olhos em pedúnculo. Casco em "m_crab" (o jogo pinta o Rei e os filhotes pela cor do monstro)."""
    arm = lp.make_armature("rig_" + cid, bm.MOB_BONES)
    m = ck.mat("m_crab", (0.86, 0.4, 0.28), 0.55)
    md = ck.mat("m_crab_d", (0.62, 0.24, 0.18), 0.6)
    mb = ck.mat("m_crab_belly", (0.95, 0.82, 0.66), 0.6)
    m_eye = ck.mat("m_eye", (0.31, 0.27, 0.35), 0.3)
    m_white = ck.mat("m_white", (1.0, 1.0, 1.0), 0.3)
    parts = [(blob("shell", 0.42, (0, 0.02, 0.36), m, (1.45, 1.0, 0.55)), "body"),
             (blob("shell_ridge", 0.2, (0, -0.02, 0.5), md, (1.6, 0.7, 0.35)), "body"),
             (blob("belly", 0.36, (0, 0.04, 0.26), mb, (1.3, 0.9, 0.35)), "body")]
    for k in range(5):                                   # pintinhas no casco
        x = -0.34 + k * 0.17
        parts.append((blob("spot%d" % k, 0.04, (x, -0.06 + abs(k - 2) * 0.04, 0.55), md, (1.2, 1.0, 0.4)), "body"))
    for sx in (-1, 1):
        # olhos em pedúnculo
        base = Vector((sx * 0.13, -0.3, 0.48))
        tip = Vector((sx * 0.16, -0.36, 0.7))
        parts.append((ck.tube("stalk%d" % sx, base, tip, 0.03, 0.025, m, 6), "head"))
        parts.append((blob("eye%d" % sx, 0.06, tuple(tip), m_white), "head"))
        parts.append((blob("pupil%d" % sx, 0.035, (sx * 0.17, -0.41, 0.71), m_eye), "head"))
        # pinça: antebraço + garra (duas metades) no braço do lado
        bone = "arm_r" if sx > 0 else "arm_l"
        sh = Vector((sx * 0.46, -0.22, 0.34))
        el = Vector((sx * 0.62, -0.5, 0.36))
        parts.append((ck.tube("arm%d" % sx, sh, el, 0.07, 0.06, m, 7), bone))
        parts.append((blob("claw%d" % sx, 0.15, (sx * 0.64, -0.66, 0.38), m, (1.0, 1.35, 0.75)), bone))
        parts.append((cone("pincer_a%d" % sx, (sx * 0.6, -0.76, 0.42), (sx * 0.56, -0.98, 0.44), 0.06, md), bone))
        parts.append((cone("pincer_b%d" % sx, (sx * 0.7, -0.76, 0.34), (sx * 0.66, -0.94, 0.3), 0.05, md), bone))
        # 3 patas finas de cada lado
        for i in range(3):
            y = -0.05 + i * 0.16
            leg = ("leg_fr" if i < 2 else "leg_br") if sx > 0 else ("leg_fl" if i < 2 else "leg_bl")
            root = Vector((sx * 0.4, y, 0.3))
            knee = Vector((sx * 0.72, y + (i - 1) * 0.06, 0.42))
            foot = Vector((sx * 0.86, y + (i - 1) * 0.14, 0.0))
            parts.append((ck.tube("leg%d%d_a" % (sx, i), root, knee, 0.04, 0.032, md, 6), leg))
            parts.append((ck.tube("leg%d%d_b" % (sx, i), knee, foot, 0.032, 0.012, md, 6), leg))
    finish(arm, parts)
    bm.mob_actions(arm, quadruped=True)
    return arm


# ---------------------------------------------------------------------------
# espectro, ent, golem
# ---------------------------------------------------------------------------
def ghost(cid="mob_ghost"):
    arm = lp.make_armature("rig_" + cid, bm.MOB_BONES)
    m = ck.mat("m_ghost", (0.72, 0.92, 1.0), 0.3, 0.35)
    m_eye = ck.mat("m_ghost_eye", (0.15, 0.2, 0.4), 0.3)
    body = blob("body", 0.42, (0, 0, 0), m, cuts=4)
    for v in body.data.vertices:
        z = v.co.z
        if z < 0:
            # lençol: desce e ondula na barra
            a = math.atan2(v.co.y, v.co.x)
            v.co.z = z * 2.4 + 0.06 * math.sin(a * 6)
            v.co.x *= 1.0 + (-z) * 0.5
            v.co.y *= 1.0 + (-z) * 0.5
        v.co.z += 1.15
    parts = [(body, "body")]
    for sx in (-1, 1):
        parts.append((blob("eye%d" % sx, 0.07, (sx * 0.13, -0.38, 1.22), m_eye, (0.8, 0.4, 1.4)), "head"))
        arm_obj = ck.strand("arm%d" % sx, Vector((sx * 0.38, -0.05, 1.05)), 0.4, 0.14, 0.12, m, taper=0.8, lean=(sx * 0.5, -0.4))
        parts.append((arm_obj, "arm_r" if sx > 0 else "arm_l"))
    parts.append((blob("mouth", 0.05, (0, -0.4, 1.06), m_eye, (1.2, 0.4, 0.8)), "head"))
    finish(arm, parts)
    bm.mob_actions(arm, floating=True)
    return arm


def elemental(cid, kind):
    """Elemental do Elementalista: núcleo que flutua (rig do fantasma) com a forma do elemento.
    fire = chama em gota com labaredas; frost = núcleo de gelo cercado de cristais; storm = orbe com anéis e raios."""
    arm = lp.make_armature("rig_" + cid, bm.MOB_BONES)
    m_eye, m_white = base_mats()
    z0 = 1.05
    parts = []
    if kind == "fire":
        core = ck.mat("m_el_fire", (1.0, 0.4, 0.08), 0.4, 0.7)
        hot = ck.mat("m_el_fire_hot", (1.0, 0.78, 0.2), 0.4, 1.2)
        dark = ck.mat("m_el_fire_dark", (0.8, 0.15, 0.05), 0.5, 0.5)
        body = blob("body", 0.36, (0, 0, 0), core, cuts=4)
        for v in body.data.vertices:          # gota: estreita em cima, ponta que sobe
            if v.co.z > 0:
                k = 1.0 - v.co.z / 0.36 * 0.55
                v.co.x *= k
                v.co.y *= k
                v.co.z *= 1.9
            v.co.z += z0
        parts.append((body, "body"))
        parts.append((blob("belly", 0.2, (0, -0.16, z0 - 0.04), hot, (1, 0.6, 1.2)), "body"))
        for i in range(7):                    # labaredas em volta, inclinadas para cima
            a = math.tau * i / 7
            d = Vector((math.cos(a), math.sin(a), 0))
            root = Vector((0, 0, z0 + 0.1)) + d * 0.26
            parts.append((cone("flame%d" % i, root, root + d * 0.18 + Vector((0, 0, 0.4 + 0.12 * (i % 2))), 0.11, dark if i % 2 else core), "head"))
        parts.append((cone("crest", Vector((0, 0.04, z0 + 0.55)), Vector((0, 0.12, z0 + 0.95)), 0.1, hot), "head"))
        for sx in (-1, 1):
            parts.append((ck.strand("arm%d" % sx, Vector((sx * 0.32, -0.02, z0)), 0.36, 0.11, 0.08, core, taper=0.95, lean=(sx * 0.6, -0.2)), "arm_r" if sx > 0 else "arm_l"))
        eye_y, eye_z = -0.33, z0 + 0.12
    elif kind == "frost":
        core = ck.mat("m_el_frost", (0.42, 0.75, 1.0), 0.15, 0.4)
        ice = ck.mat("m_el_frost_ice", (0.75, 0.93, 1.0), 0.1, 0.2)
        deep = ck.mat("m_el_frost_deep", (0.2, 0.45, 0.95), 0.2, 0.3)
        parts.append((blob("body", 0.34, (0, 0, z0), core, (1, 0.9, 1.15), cuts=3), "body"))
        for i in range(9):                    # cristais em volta (coroa de gelo em cima, saias embaixo)
            a = math.tau * i / 9
            d = Vector((math.cos(a), math.sin(a), 0))
            up = i % 3 != 2
            root = Vector((0, 0, z0 + (0.15 if up else -0.15))) + d * 0.22
            tip = root + d * 0.18 + Vector((0, 0, 0.42 if up else -0.38))
            parts.append((ck.tube("shard%d" % i, root, tip, 0.08, 0.008, ice if i % 2 else deep, 6), "head" if up else "body"))
        for sx in (-1, 1):                    # braços: punhos de cristal
            sh = Vector((sx * 0.34, 0, z0))
            parts.append((ck.tube("arm%d" % sx, sh, sh + Vector((sx * 0.22, -0.08, -0.2)), 0.07, 0.05, deep, 6), "arm_r" if sx > 0 else "arm_l"))
            parts.append((ck.tube("fist%d" % sx, sh + Vector((sx * 0.2, -0.08, -0.18)), sh + Vector((sx * 0.3, -0.12, -0.38)), 0.1, 0.01, ice, 6), "arm_r" if sx > 0 else "arm_l"))
        eye_y, eye_z = -0.31, z0 + 0.06
    else:
        core = ck.mat("m_el_storm", (0.45, 0.45, 1.0), 0.3, 0.7)
        bolt = ck.mat("m_el_storm_bolt", (1.0, 0.88, 0.25), 0.3, 1.4)
        dark = ck.mat("m_el_storm_cloud", (0.35, 0.38, 0.6), 0.6, 0.3)
        parts.append((blob("body", 0.3, (0, 0, z0), core, cuts=4), "body"))
        for i in range(6):                    # nuvem escura em volta da cintura
            a = math.tau * i / 6
            parts.append((blob("cloud%d" % i, 0.17, (math.cos(a) * 0.3, math.sin(a) * 0.3, z0 - 0.22), dark, (1.2, 1.2, 0.8), 2), "body"))
        for r_, tilt, nm in ((0.48, 0.35, "ring_a"), (0.42, -0.5, "ring_b")):       # anéis elétricos
            for i in range(16):
                a0, a1 = math.tau * i / 16, math.tau * (i + 1) / 16
                p0 = Vector((math.cos(a0) * r_, math.sin(a0) * r_ * math.cos(tilt), z0 + math.sin(a0) * r_ * math.sin(tilt)))
                p1 = Vector((math.cos(a1) * r_, math.sin(a1) * r_ * math.cos(tilt), z0 + math.sin(a1) * r_ * math.sin(tilt)))
                parts.append((ck.tube("%s_%d" % (nm, i), p0, p1, 0.022, 0.022, bolt, 5), "body"))
        for i in range(5):                    # raios em zigue-zague na cabeça
            a = math.pi * (0.15 + 0.7 * i / 4)
            d = Vector((math.cos(a), 0.2, math.sin(a)))
            p0 = Vector((0, 0, z0)) + d * 0.28
            p1 = p0 + d * 0.16 + Vector((0.06, 0, 0))
            p2 = p1 + d * 0.16 - Vector((0.06, 0, 0))
            parts.append((ck.tube("bolt%d_a" % i, p0, p1, 0.035, 0.03, bolt, 5), "head"))
            parts.append((ck.tube("bolt%d_b" % i, p1, p2, 0.03, 0.005, bolt, 5), "head"))
        for sx in (-1, 1):
            parts.append((ck.strand("arm%d" % sx, Vector((sx * 0.28, 0, z0)), 0.32, 0.09, 0.06, core, taper=0.95, lean=(sx * 0.7, -0.3)), "arm_r" if sx > 0 else "arm_l"))
        eye_y, eye_z = -0.27, z0 + 0.04
    for o_ in eyes("e", [(-0.1, eye_y, eye_z), (0.1, eye_y, eye_z)], 0.055, m_eye, m_white):
        parts.append((o_, "head"))
    finish(arm, parts)
    bm.mob_actions(arm, floating=True)
    return arm


def ent(cid="mob_ent"):
    arm = lp.make_armature("rig_" + cid, bm.MOB_BONES)
    bark = ck.mat("m_bark", (0.45, 0.32, 0.22), 0.9)
    bark_d = ck.mat("m_bark_d", (0.3, 0.2, 0.14), 0.9)
    leaf = ck.mat("m_leaf", (0.38, 0.66, 0.32), 0.8)
    leaf2 = ck.mat("m_leaf2", (0.5, 0.78, 0.38), 0.8)
    glow = ck.mat("m_ent_eye", (1.0, 0.85, 0.3), 0.3, 2.0)
    pts = [((0, 0, 0.35), 0.34), ((0, 0.02, 0.9), 0.3), ((0, 0, 1.45), 0.26)]
    trunk = skin_body("trunk", pts, [(0, 1), (1, 2)], bark)
    parts = [(trunk, "body")]
    for sx in (-1, 1):
        parts.append((blob("eye%d" % sx, 0.06, (sx * 0.11, -0.28, 1.25), glow, (1, 0.5, 0.7)), "head"))
        parts.append((blob("brow%d" % sx, 0.09, (sx * 0.12, -0.27, 1.34), bark_d, (1.2, 0.5, 0.4)), "head"))
    parts.append((blob("mouth", 0.08, (0, -0.3, 1.02), bark_d, (1.4, 0.4, 0.5)), "head"))
    # raízes-pés
    for bone, sx, sy in (("leg_fr", 1, -1), ("leg_fl", -1, -1), ("leg_br", 1, 1), ("leg_bl", -1, 1)):
        parts.append((ck.tube("root_" + bone, (sx * 0.15, sy * 0.12, 0.4), (sx * 0.45, sy * 0.4, 0.02), 0.12, 0.05, bark_d, 8), bone))
    # braços-galhos com folhas
    for sx, bone in ((1, "arm_r"), (-1, "arm_l")):
        sh = Vector((sx * 0.25, 0, 1.2))
        el = Vector((sx * 0.62, -0.1, 1.0))
        hand = Vector((sx * 0.75, -0.25, 0.6))
        parts.append((ck.tube("branch%d" % sx, sh, el, 0.11, 0.08, bark, 8), bone))
        parts.append((ck.tube("forearm%d" % sx, el, hand, 0.08, 0.05, bark, 8), bone))
        parts.append((blob("leafhand%d" % sx, 0.2, el + Vector((0, 0, 0.18)), leaf2), bone))
    # copa
    for i, (c, r, mm) in enumerate([((0, 0.05, 1.85), 0.5, leaf), ((-0.32, 0.1, 1.68), 0.34, leaf2), ((0.34, 0.0, 1.7), 0.36, leaf2), ((0.05, 0.3, 1.65), 0.32, leaf)]):
        parts.append((blob("canopy%d" % i, r, c, mm, (1, 1, 0.82)), "head"))
    finish(arm, parts)
    bm.mob_actions(arm)
    return arm


def trent(cid="mob_trent"):
    """Trent Ancião: ent mais pesado e velho, tronco largo coberto de musgo, braços-raiz compridos e copa escura."""
    arm = lp.make_armature("rig_" + cid, bm.MOB_BONES)
    bark = ck.mat("m_trent_bark", (0.38, 0.28, 0.2), 0.9)
    bark_d = ck.mat("m_trent_bark_d", (0.24, 0.17, 0.12), 0.9)
    moss = ck.mat("m_trent_moss", (0.36, 0.56, 0.26), 0.85)
    leaf = ck.mat("m_trent_leaf", (0.22, 0.42, 0.24), 0.8)
    glow = ck.mat("m_trent_eye", (0.6, 1.0, 0.45), 0.3, 2.2)
    pts = [((0, 0, 0.3), 0.42), ((0, 0.03, 0.85), 0.38), ((0, 0, 1.4), 0.3)]
    parts = [(skin_body("trunk", pts, [(0, 1), (1, 2)], bark), "body")]
    for i, (c, r) in enumerate([((0.2, -0.3, 0.7), 0.16), ((-0.25, -0.26, 1.05), 0.14), ((0.05, 0.32, 0.9), 0.18), ((-0.3, 0.1, 0.5), 0.13)]):
        parts.append((blob("moss%d" % i, r, c, moss, (1.2, 0.5, 1.0)), "body"))
    for sx in (-1, 1):
        parts.append((blob("eye%d" % sx, 0.065, (sx * 0.12, -0.33, 1.22), glow, (1, 0.5, 0.6)), "head"))
        parts.append((blob("brow%d" % sx, 0.11, (sx * 0.13, -0.31, 1.32), bark_d, (1.3, 0.5, 0.4)), "head"))
    parts.append((blob("mouth", 0.1, (0, -0.35, 0.98), bark_d, (1.5, 0.4, 0.55)), "head"))
    for bone, sx, sy in (("leg_fr", 1, -1), ("leg_fl", -1, -1), ("leg_br", 1, 1), ("leg_bl", -1, 1)):
        parts.append((ck.tube("root_" + bone, (sx * 0.18, sy * 0.15, 0.36), (sx * 0.6, sy * 0.5, 0.02), 0.16, 0.06, bark_d, 8), bone))
    for sx, bone in ((1, "arm_r"), (-1, "arm_l")):
        sh = Vector((sx * 0.3, 0, 1.18))
        el = Vector((sx * 0.75, -0.12, 0.92))
        hand = Vector((sx * 0.85, -0.3, 0.25))
        parts.append((ck.tube("branch%d" % sx, sh, el, 0.14, 0.1, bark, 8), bone))
        parts.append((ck.tube("forearm%d" % sx, el, hand, 0.1, 0.06, bark, 8), bone))
        for k in range(3):                   # dedos-raiz
            parts.append((ck.tube("finger%d_%d" % (sx, k), hand, hand + Vector((sx * 0.08 * (k - 1), -0.12, -0.2)), 0.05, 0.015, bark_d, 6), bone))
        parts.append((blob("mossarm%d" % sx, 0.13, el + Vector((0, 0, 0.1)), moss, (1.1, 0.8, 0.6)), bone))
    for i, (c, r) in enumerate([((0, 0.05, 1.8), 0.56), ((-0.38, 0.1, 1.62), 0.38), ((0.4, 0.0, 1.64), 0.4), ((0.05, 0.36, 1.6), 0.36), ((0.0, -0.2, 1.7), 0.3)]):
        parts.append((blob("canopy%d" % i, r, c, leaf if i % 2 == 0 else moss, (1, 1, 0.8)), "head"))
    finish(arm, parts)
    bm.mob_actions(arm)
    return arm


def elf_parts(cid, cloth2, ears=True, cape=False):
    """Elfo: orelhas longas para trás e para cima (o que se lê de cima), faixa na testa e, no chefe, manto."""
    def add(base, mats):
        V = Vector
        rig, b = base["rig"], base["b"]
        c, r = V(base["head_c"]), b["head"]
        skin = ck.mat("m_%s_ear" % cid, (0.96, 0.86, 0.74), 0.7)
        band = ck.mat("m_%s_band" % cid, cloth2, 0.6)
        head = []
        if ears:
            for sx in (-1, 1):
                root = c + V((sx * r * 0.92, r * 0.05, r * 0.05))
                head.append(ck.blade("%s_ear%d" % (cid, sx), root, root + V((sx * r * 0.85, r * 0.35, r * 0.55)), r * 0.28, r * 0.05, skin, (0, 1, 0), 0.5))
        head.append(ck.tube(cid + "_band", c + V((0, 0, r * 0.3)), c + V((0, 0, r * 0.42)), r * 1.03, r * 1.02, band, 20))
        head.append(ck.ball(cid + "_gem", r * 0.12, c + V((0, -r * 1.02, r * 0.36)), ck.mat("m_%s_gem" % cid, (0.6, 1.0, 0.7), 0.3, 1.8)))
        for p_ in head:
            ck.skin_rigid(p_, rig, "head")
        if cape:
            zc = ck.Z["chest"]
            back = b["chest"] * b["depth"] + 0.03
            ch = [ck.blade(cid + "_mantle", V((0, back, zc + 0.12)), V((0, back + 0.18, ck.Z["knee"])), 0.5, 0.03, band, (1, 0, 0), 0.4)]
            for p_ in ch:
                ck.skin_rigid(p_, rig, "chest")
    return add


def golem(cid="mob_golem"):
    arm = lp.make_armature("rig_" + cid, bm.MOB_BONES)
    stone = ck.mat("m_stone", (0.62, 0.6, 0.58), 0.9)
    stone_d = ck.mat("m_stone_d", (0.45, 0.43, 0.42), 0.9)
    moss = ck.mat("m_moss", (0.42, 0.62, 0.32), 0.9)
    core = ck.mat("m_core", (1.0, 0.6, 0.2), 0.3, 3.0)
    parts = [(ck.box("torso", (0.9, 0.62, 0.72), (0, 0, 1.0), stone, 0.12), "body"),
             (ck.box("belly", (0.6, 0.5, 0.36), (0, 0.02, 0.55), stone_d, 0.1), "body"),
             (blob("core", 0.11, (0, -0.33, 1.02), core), "body"),
             (blob("moss", 0.3, (0.1, 0.0, 1.38), moss, (1.4, 1.0, 0.25)), "body"),
             (ck.box("head", (0.38, 0.34, 0.3), (0, -0.12, 1.5), stone, 0.07), "head")]
    for sx in (-1, 1):
        parts.append((blob("eye%d" % sx, 0.04, (sx * 0.08, -0.29, 1.52), core), "head"))
        bone = "arm_r" if sx > 0 else "arm_l"
        parts.append((ck.box("shoulder%d" % sx, (0.36, 0.38, 0.34), (sx * 0.62, 0, 1.18), stone_d, 0.08), bone))
        parts.append((ck.box("forearm%d" % sx, (0.3, 0.32, 0.5), (sx * 0.68, -0.04, 0.78), stone, 0.08), bone))
        parts.append((ck.box("fist%d" % sx, (0.36, 0.36, 0.3), (sx * 0.7, -0.06, 0.45), stone_d, 0.08), bone))
        leg_bone = "leg_fr" if sx > 0 else "leg_fl"
        parts.append((ck.box("leg%d" % sx, (0.3, 0.32, 0.42), (sx * 0.24, 0, 0.21), stone_d, 0.08), leg_bone))
    finish(arm, parts)
    bm.mob_actions(arm)
    return arm


def _spike(name, root, tip, r, material, segs=5):
    """Cristal/chifre facetado: cone de poucos lados (lê como cristal com o toon)."""
    return ck.tube(name, root, tip, r, r * 0.05, material, segs)


def golem_boss(cid, kind):
    """Chefes da Pedreira dos Golens (rig do golem). De cima o que define cada um é o dorso:
    ancient = musgo e uma árvore nas costas; crystal = coroa e agulhas de cristal azul; heart = rocha escura
    rachada de lava, núcleo exposto, chifres e placas flutuando."""
    V = Vector
    arm = lp.make_armature("rig_" + cid, bm.MOB_BONES)
    if kind == "ancient":
        stone = ck.mat("m_%s_stone" % cid, (0.5, 0.52, 0.46), 0.9)
        stone_d = ck.mat("m_%s_stone_d" % cid, (0.34, 0.36, 0.32), 0.9)
        moss = ck.mat("m_%s_moss" % cid, (0.36, 0.58, 0.28), 0.9)
        moss2 = ck.mat("m_%s_moss2" % cid, (0.5, 0.7, 0.34), 0.85)
        bark = ck.mat("m_%s_bark" % cid, (0.42, 0.3, 0.2), 0.9)
        glow = ck.mat("m_%s_glow" % cid, (0.55, 1.0, 0.45), 0.3, 2.6)
        parts = [(ck.box("torso", (1.15, 0.8, 0.82), (0, 0.05, 1.0), stone, 0.14), "body"),
                 (ck.box("belly", (0.78, 0.62, 0.42), (0, 0.0, 0.5), stone_d, 0.12), "body"),
                 (ck.box("head", (0.4, 0.36, 0.3), (0, -0.32, 1.3), stone, 0.08), "head"),
                 (ck.box("brow", (0.46, 0.12, 0.1), (0, -0.5, 1.4), stone_d, 0.03), "head"),
                 (blob("core", 0.12, (0, -0.42, 0.98), glow), "body")]
        for sx in (-1, 1):
            parts.append((blob("eye%d" % sx, 0.045, (sx * 0.1, -0.5, 1.3), glow), "head"))
        # manto de musgo nas costas e ombros + árvore jovem crescendo do dorso
        parts.append((blob("moss_back", 0.62, (0, 0.18, 1.42), moss, (1.0, 0.75, 0.32)), "body"))
        for i, (c, r) in enumerate([((0.45, 0.25, 1.36), 0.22), ((-0.42, 0.3, 1.34), 0.24), ((0.1, 0.45, 1.2), 0.2)]):
            parts.append((blob("moss_tuft%d" % i, r, c, moss2, (1.1, 1.0, 0.6)), "body"))
        parts.append((ck.tube("trunk", (0.12, 0.3, 1.45), (0.2, 0.42, 2.25), 0.11, 0.06, bark, 7), "body"))
        parts.append((ck.tube("branch", (0.18, 0.4, 2.0), (0.48, 0.52, 2.2), 0.05, 0.02, bark, 6), "body"))
        for i, (c, r) in enumerate([((0.2, 0.44, 2.42), 0.36), ((0.46, 0.52, 2.26), 0.24), ((-0.06, 0.4, 2.3), 0.24)]):
            parts.append((blob("canopy%d" % i, r, c, moss2 if i else moss, (1, 1, 0.8)), "body"))
        for sx in (-1, 1):
            bone = "arm_r" if sx > 0 else "arm_l"
            parts.append((ck.box("shoulder%d" % sx, (0.5, 0.5, 0.46), (sx * 0.78, 0, 1.2), stone_d, 0.1), bone))
            parts.append((blob("shoulder_moss%d" % sx, 0.28, (sx * 0.8, 0.04, 1.46), moss, (1.0, 1.0, 0.45)), bone))
            parts.append((ck.box("forearm%d" % sx, (0.38, 0.4, 0.62), (sx * 0.88, -0.08, 0.72), stone, 0.1), bone))
            parts.append((ck.box("fist%d" % sx, (0.52, 0.5, 0.42), (sx * 0.92, -0.12, 0.3), stone_d, 0.1), bone))
            parts.append((blob("rune%d" % sx, 0.06, (sx * 0.92, -0.38, 0.32), glow, (1.4, 0.4, 0.6)), bone))
            leg_bone = "leg_fr" if sx > 0 else "leg_fl"
            parts.append((ck.box("leg%d" % sx, (0.4, 0.42, 0.5), (sx * 0.3, 0, 0.25), stone_d, 0.1), leg_bone))
    elif kind == "crystal":
        stone = ck.mat("m_%s_stone" % cid, (0.62, 0.66, 0.74), 0.85)
        stone_d = ck.mat("m_%s_stone_d" % cid, (0.42, 0.46, 0.56), 0.85)
        cry = ck.mat("m_%s_cry" % cid, (0.35, 0.68, 1.0), 0.15, 1.6)
        cry_d = ck.mat("m_%s_cry_d" % cid, (0.2, 0.42, 0.85), 0.2, 0.8)
        parts = [(ck.box("torso", (0.7, 0.48, 0.72), (0, 0, 1.12), stone, 0.12), "body"),
                 (ck.box("waist", (0.42, 0.36, 0.34), (0, 0, 0.66), stone_d, 0.1), "body"),
                 (ck.box("head", (0.3, 0.3, 0.32), (0, -0.08, 1.66), stone, 0.08), "head"),
                 (blob("core", 0.14, (0, -0.26, 1.14), cry), "body")]
        for sx in (-1, 1):
            parts.append((blob("eye%d" % sx, 0.04, (sx * 0.07, -0.24, 1.68), cry), "head"))
        # coroa de cristais (o que se vê de cima) e agulhas nas costas
        for i in range(5):
            a = math.pi * (0.15 + 0.7 * i / 4)
            root = V((math.cos(a) * 0.14, -0.02 + math.sin(a) * 0.1, 1.8))
            parts.append((_spike("crown%d" % i, root, root + V((math.cos(a) * 0.12, 0.06, 0.34 + 0.12 * (i == 2))), 0.06, cry), "head"))
        for i, (x, y, h, r) in enumerate([(0.0, 0.26, 0.9, 0.13), (0.22, 0.24, 0.65, 0.1), (-0.22, 0.24, 0.65, 0.1), (0.12, 0.3, 0.45, 0.08), (-0.14, 0.3, 0.5, 0.08)]):
            root = V((x, y, 1.3))
            parts.append((_spike("back%d" % i, root, root + V((x * 0.6, 0.25, h)), r, cry if i % 2 == 0 else cry_d), "body"))
        for sx in (-1, 1):
            bone = "arm_r" if sx > 0 else "arm_l"
            parts.append((ck.box("shoulder%d" % sx, (0.3, 0.32, 0.28), (sx * 0.5, 0, 1.36), stone_d, 0.08), bone))
            parts.append((_spike("pauldron%d" % sx, V((sx * 0.52, 0.02, 1.48)), V((sx * 0.8, 0.1, 1.86)), 0.09, cry), bone))
            parts.append((ck.box("forearm%d" % sx, (0.22, 0.24, 0.46), (sx * 0.56, -0.04, 0.96), stone, 0.07), bone))
            parts.append((_spike("blade%d" % sx, V((sx * 0.58, -0.08, 0.76)), V((sx * 0.64, -0.3, 0.12)), 0.1, cry), bone))
            leg_bone = "leg_fr" if sx > 0 else "leg_fl"
            parts.append((ck.box("leg%d" % sx, (0.22, 0.26, 0.5), (sx * 0.18, 0, 0.25), stone_d, 0.07), leg_bone))
    else:                                   # heart
        rock = ck.mat("m_%s_rock" % cid, (0.4, 0.26, 0.22), 0.9)
        rock_d = ck.mat("m_%s_rock_d" % cid, (0.24, 0.16, 0.14), 0.9)
        lava = ck.mat("m_%s_lava" % cid, (1.0, 0.5, 0.15), 0.3, 3.0)
        cry = ck.mat("m_%s_cry" % cid, (0.35, 0.68, 1.0), 0.15, 1.4)
        moss = ck.mat("m_%s_moss" % cid, (0.36, 0.56, 0.28), 0.9)
        parts = [(ck.box("torso", (1.3, 0.9, 0.95), (0, 0.04, 1.05), rock, 0.16), "body"),
                 (ck.box("belly", (0.9, 0.7, 0.5), (0, 0, 0.5), rock_d, 0.12), "body"),
                 (blob("core", 0.26, (0, -0.44, 1.08), lava), "body"),
                 (ck.box("core_frame_t", (0.62, 0.1, 0.1), (0, -0.48, 1.38), rock_d, 0.03), "body"),
                 (ck.box("core_frame_b", (0.62, 0.1, 0.1), (0, -0.48, 0.78), rock_d, 0.03), "body"),
                 (ck.box("head", (0.46, 0.4, 0.34), (0, -0.3, 1.62), rock, 0.08), "head")]
        for sx in (-1, 1):
            parts.append((blob("eye%d" % sx, 0.05, (sx * 0.11, -0.5, 1.64), lava), "head"))
            parts.append((ck.tube("horn%d" % sx, V((sx * 0.2, -0.22, 1.74)), V((sx * 0.56, -0.12, 2.12)), 0.15, 0.1, rock_d, 7), "head"))
            parts.append((cone("horn_tip%d" % sx, V((sx * 0.56, -0.12, 2.12)), V((sx * 0.62, -0.42, 2.5)), 0.1, rock_d), "head"))
            parts.append((ck.box("brow_crack%d" % sx, (0.14, 0.02, 0.03), (sx * 0.11, -0.52, 1.72), lava, 0.005), "head"))
        # rachaduras de lava no peito e nas costas
        for i, (c, s) in enumerate([((0.36, -0.46, 1.3), (0.06, 0.02, 0.36)), ((-0.4, -0.46, 0.9), (0.05, 0.02, 0.3)),
                                    ((0.2, 0.5, 1.2), (0.3, 0.02, 0.05)), ((-0.25, 0.5, 0.9), (0.4, 0.02, 0.05))]):
            parts.append((ck.box("crack%d" % i, s, c, lava, 0.01), "body"))
        # dorso: metade cristal, metade musgo (os dois guardiões), placas de rocha flutuando
        for i, (x, h) in enumerate([(0.3, 0.6), (0.48, 0.45), (0.16, 0.5)]):
            root = V((x, 0.3, 1.5))
            parts.append((_spike("back_cry%d" % i, root, root + V((x * 0.4, 0.2, h)), 0.11, cry), "body"))
        parts.append((blob("back_moss", 0.36, (-0.34, 0.25, 1.5), moss, (1.1, 1.0, 0.5)), "body"))
        for i, sx in enumerate((-1, 1)):            # placas de rocha soltas, inclinadas, flutuando atrás dos ombros
            pl = ck.box("plate%d" % i, (0.42, 0.12, 0.3), (0, 0, 0), rock_d, 0.04)
            R = Matrix.Rotation(sx * 0.5, 4, "Y") @ Matrix.Rotation(0.35, 4, "X")
            for v in pl.data.vertices:
                v.co = R @ v.co + V((sx * 0.86, 0.52, 1.95))
            parts.append((pl, "body"))
            parts.append((ck.box("plate_glow%d" % i, (0.3, 0.02, 0.04), (sx * 0.86, 0.6, 1.86), lava, 0.005), "body"))
        for sx in (-1, 1):
            bone = "arm_r" if sx > 0 else "arm_l"
            parts.append((ck.box("shoulder%d" % sx, (0.56, 0.56, 0.5), (sx * 0.9, 0, 1.28), rock_d, 0.12), bone))
            parts.append((ck.box("forearm%d" % sx, (0.44, 0.46, 0.7), (sx * 1.0, -0.08, 0.74), rock, 0.12), bone))
            parts.append((ck.box("fist%d" % sx, (0.6, 0.58, 0.48), (sx * 1.04, -0.14, 0.28), rock_d, 0.12), bone))
            parts.append((ck.box("arm_crack%d" % sx, (0.04, 0.02, 0.4), (sx * 1.0, -0.32, 0.74), lava, 0.01), bone))
            leg_bone = "leg_fr" if sx > 0 else "leg_fl"
            parts.append((ck.box("leg%d" % sx, (0.46, 0.48, 0.52), (sx * 0.34, 0, 0.26), rock_d, 0.12), leg_bone))
    finish(arm, parts)
    bm.mob_actions(arm)
    return arm


# ---------------------------------------------------------------------------
# humanoides do kit chibi: bandido e esqueleto
# ---------------------------------------------------------------------------
def spiked_crown(base, cid, spikes, mats):
    """Coroa de pontas por cima do capuz: de cima é a cabeça que define o chefe."""
    c, r = Vector(base["head_c"]), base["b"]["head"]
    ring = r * 1.24
    z = r * 0.5
    parts = [ck.tube(cid + "_crown_band", c + Vector((0, 0, z)), c + Vector((0, 0, z + r * 0.16)), ring, ring * 0.98, mats["trim"], 24)]
    for i in range(spikes):
        a = math.tau * i / spikes
        d = Vector((math.cos(a), math.sin(a), 0))
        tall = r * (0.75 if i % 2 == 0 else 0.48)
        base_p = c + d * ring * 0.97 + Vector((0, 0, z + r * 0.1))
        parts.append(ck.tube("%s_crown_spike_%d" % (cid, i), base_p, base_p + d * r * 0.16 + Vector((0, 0, tall)), r * 0.17, r * 0.015, mats["trim"], 6))
    for p in parts:
        ck.skin_rigid(p, base["rig"], "head")


def humanoid(cid, style, cloth, weapon, skin=None, eye=None, offhand=None, hide_hair=False, head=None, crown=0, extra=None):
    ck.clear()
    base = ck.build_base(cid, "male", 0.0, (0.25, 0.18, 0.14))
    mats = ck._kit_mats()
    mats["tint"] = ck.mat("m_%s_cloth" % cid, cloth, 0.7)
    if skin:
        ms = ck.mat("m_%s_skin" % cid, skin, 0.7)
        for o in bpy.context.scene.objects:
            if o.type == "MESH" and o.name in (cid + "_body", cid + "_head"):
                o.data.materials[0] = ms
    if eye:
        me = ck.mat("m_%s_eyes" % cid, eye, 0.3, 2.5)
        for o in bpy.context.scene.objects:
            if o.type == "MESH" and o.name.startswith(cid + "_head_eye"):
                o.data.materials[0] = me
    if hide_hair:
        for o in list(bpy.context.scene.objects):
            if o.name.startswith(cid + "_hair"):
                bpy.data.objects.remove(o, do_unlink=True)
    for slot, plist in ck.KIT_STYLES[style].items():
        for part, opt in plist:
            ck.kit_piece(base, style, slot, part, opt, mats)
    if head != "none":
        ck.kit_head(base, head or style, mats)
    if extra:
        extra(base, mats)
    if crown:
        spiked_crown(base, cid, crown, mats)
    ck.kit_weapon(base, weapon, "main", mats)
    if offhand:
        ck.kit_weapon(base, offhand, "off", mats)
    if cid.startswith("form_"):
        ck.animate(base["rig"], "all")    # forma do jogador (demônio): o mesmo jogo de clipes do kit, não só os do monstro
        ck.animate_combat(base["rig"])
        ck.animate_v3(base["rig"])
    else:
        ck.animate(base["rig"], "melee")
    return base["rig"]


def demon_parts(base, mats):
    """Forma demoníaca do Necromancer: chifres curvos, asas de morcego, rabo com ponta de lança."""
    V = Vector
    rig, b, j = base["rig"], base["b"], base["j"]
    c, r = V(base["head_c"]), b["head"]
    horn = ck.mat("m_demon_horn", (0.18, 0.12, 0.12), 0.5)
    wing = ck.mat("m_demon_wing", (0.3, 0.06, 0.1), 0.7)
    glow = ck.mat("m_demon_glow", (1.0, 0.45, 0.1), 0.3, 1.6)
    head = []
    for sx in (-1, 1):                     # chifre curvo para trás e para cima
        pts = [c + V((sx * r * 0.55, -r * 0.1, r * 0.6))]
        for k in range(1, 5):
            a = k / 4
            pts.append(c + V((sx * r * (0.6 + 0.6 * a), r * (0.1 + 0.7 * a * a), r * (0.6 + 1.3 * a - 0.4 * a * a))))
        for k in range(4):
            head.append(ck.tube("demon_horn%d_%d" % (sx, k), pts[k], pts[k + 1], r * (0.26 - k * 0.06), r * (0.2 - k * 0.05), horn, 8))
    for p_ in head:
        ck.skin_rigid(p_, rig, "head")
    zc = ck.Z["chest"]
    back = b["chest"] * b["depth"] + 0.02
    chest = []
    for sx in (-1, 1):                     # asas: braço da asa + membranas
        root = V((sx * 0.08, back, zc + 0.08))
        elbow = root + V((sx * 0.5, 0.18, 0.42))
        tip = elbow + V((sx * 0.45, 0.08, 0.2))
        chest += [ck.tube("demon_wbone%d_a" % sx, root, elbow, 0.03, 0.025, horn, 6), ck.tube("demon_wbone%d_b" % sx, elbow, tip, 0.025, 0.008, horn, 6)]
        for k in range(3):
            low = root + V((sx * (0.2 + k * 0.28), 0.12, -0.3 + k * 0.1))
            chest.append(ck.blade("demon_membrane%d_%d" % (sx, k), elbow.lerp(tip, k / 2.0), low, 0.32, 0.012, wing, (0, 0, 1), 0.5))
    chest.append(ck.ball("demon_core", 0.05, (0, -b["chest"] * b["depth"] - 0.04, zc + 0.05), glow))
    for p_ in chest:
        ck.skin_rigid(p_, rig, "chest")
    hips = []
    pts = [V((0, b["waist"] * b["depth"] + 0.02, ck.Z["waist"] - 0.05))]
    for k in range(1, 6):
        pts.append(pts[0] + V((0.03 * math.sin(k), 0.09 * k, -0.06 * k + 0.012 * k * k)))
    for k in range(5):
        hips.append(ck.tube("demon_tail%d" % k, pts[k], pts[k + 1], 0.035 - k * 0.005, 0.03 - k * 0.005, ck.mat("m_demon_skin_t", (0.62, 0.14, 0.16), 0.7), 6))
    hips.append(ck.blade("demon_tail_tip", pts[-1], pts[-1] + V((0, 0.12, 0.03)), 0.1, 0.02, horn, (1, 0, 0), 0.4))
    for p_ in hips:
        ck.skin_rigid(p_, rig, "hips")


# ---------------------------------------------------------------------------
def build_all(out_dir, only=None):
    os.makedirs(out_dir, exist_ok=True)
    builders = {
        "mob_slime": lambda: slime(),
        "mob_wolf": lambda: quadruped("mob_wolf", (0.55, 0.56, 0.62), (0.3, 0.3, 0.36), (0.85, 0.85, 0.88), "wolf"),
        "mob_boar": lambda: quadruped("mob_boar", (0.55, 0.38, 0.27), (0.32, 0.22, 0.16), (0.85, 0.66, 0.6), "boar"),
        "mob_dragon": lambda: quadruped("mob_dragon", (0.78, 0.25, 0.28), (0.45, 0.12, 0.18), (0.95, 0.75, 0.5), "dragon"),
        "mob_lynx": lambda: quadruped("mob_lynx", (0.82, 0.62, 0.38), (0.36, 0.25, 0.16), (0.95, 0.88, 0.78), "lynx"),
        "mob_spider": spider,
        "mob_crab": crab,
        "mob_ghost": ghost,
        "mob_ent": ent,
        "mob_horse": horse,
        "mob_elemental_fire": lambda: elemental("mob_elemental_fire", "fire"),
        "mob_elemental_frost": lambda: elemental("mob_elemental_frost", "frost"),
        "mob_elemental_storm": lambda: elemental("mob_elemental_storm", "storm"),
        "mob_golem": golem,
        "mob_golem_ancient": lambda: golem_boss("mob_golem_ancient", "ancient"),
        "mob_crystal_warden": lambda: golem_boss("mob_crystal_warden", "crystal"),
        "mob_quarry_heart": lambda: golem_boss("mob_quarry_heart", "heart"),
        "mob_bandit": lambda: humanoid("mob_bandit", "leather", (0.62, 0.2, 0.2), "sword"),
        # Cerco élfico: elfos de couro/tecido verde, Guardião de placa clara, Rei de placa dourada com coroa e manto
        "mob_elf_warrior": lambda: humanoid("mob_elf_warrior", "leather", (0.3, 0.56, 0.42), "sword", skin=(0.96, 0.86, 0.74),
                                            head="none", extra=elf_parts("mob_elf_warrior", (0.85, 0.8, 0.5))),
        "mob_elf_archer": lambda: humanoid("mob_elf_archer", "cloth", (0.42, 0.66, 0.4), "bow", skin=(0.96, 0.86, 0.74),
                                           head="leather", extra=elf_parts("mob_elf_archer", (0.6, 0.45, 0.28))),
        "mob_elf_warden": lambda: humanoid("mob_elf_warden", "plate", (0.88, 0.86, 0.74), "sword2h", skin=(0.96, 0.86, 0.74),
                                           head="none", extra=elf_parts("mob_elf_warden", (0.3, 0.6, 0.5))),
        "mob_elf_king": lambda: humanoid("mob_elf_king", "plate", (0.95, 0.8, 0.35), "sword", skin=(0.96, 0.86, 0.74),
                                         head="none", crown=7, extra=elf_parts("mob_elf_king", (0.22, 0.5, 0.42), cape=True)),
        "mob_trent": trent,
        "mob_griffin": lambda: quadruped("mob_griffin", (0.8, 0.62, 0.36), (0.55, 0.4, 0.22), (0.96, 0.94, 0.88), "griffin"),
        "mob_elf_lynx": lambda: quadruped("mob_elf_lynx", (0.74, 0.56, 0.32), (0.2, 0.36, 0.24), (0.95, 0.9, 0.78), "lynx"),
        "mob_skeleton": lambda: humanoid("mob_skeleton", "plate", (0.42, 0.4, 0.38), "sword", skin=(0.92, 0.9, 0.82),
                                         eye=(1.0, 0.3, 0.2), offhand="shield", hide_hair=True),
        "mob_zombie": lambda: humanoid("mob_zombie", "leather", (0.32, 0.36, 0.28), "axe", skin=(0.52, 0.62, 0.42), eye=(0.95, 0.9, 0.3)),
        "mob_bone_hound": lambda: quadruped("mob_bone_hound", (0.9, 0.88, 0.8), (0.35, 0.3, 0.28), (0.98, 0.97, 0.92), "wolf"),
        "mob_skeleton_king": lambda: humanoid("mob_skeleton_king", "plate", (0.32, 0.22, 0.45), "sword2h", skin=(0.92, 0.9, 0.82),
                                              eye=(0.4, 0.9, 1.0), hide_hair=True, crown=8),
        "form_demon": lambda: humanoid("form_demon", "leather", (0.28, 0.07, 0.1), "scythe", skin=(0.68, 0.16, 0.18),
                                       eye=(1.0, 0.75, 0.15), hide_hair=True, head="none", extra=demon_parts),
        "mob_lich": lambda: humanoid("mob_lich", "cloth", (0.3, 0.16, 0.42), "staff", skin=(0.86, 0.84, 0.8), eye=(0.5, 0.9, 1.0), hide_hair=True, head="leather", crown=8),
    }
    for name, fn in builders.items():
        if only and name not in only:
            continue
        ck.clear()
        arm = fn()
        for o in bpy.context.scene.objects:
            if "." in o.name:
                o.name = o.name.replace(".", "_")
        if name in ("mob_bandit", "mob_skeleton", "mob_zombie", "mob_lich", "mob_skeleton_king", "form_demon",
                    "mob_elf_warrior", "mob_elf_archer", "mob_elf_warden", "mob_elf_king"):
            ck.export_glb(arm, os.path.join(out_dir, name + ".glb"))
        else:
            lp.export_glb(os.path.join(out_dir, name + ".glb"), [arm])
    print("mobs done")
