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
import boss_gestures

importlib.reload(ck)
importlib.reload(lp)
importlib.reload(bm)
importlib.reload(boss_gestures)


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


def pivots(**heads):
    """MOB_BONES com a cabeça de alguns ossos movida (mesma direção e tamanho, então os eixos dos clipes não mudam):
    o pivô vai para o ombro/quadril/pescoço do bicho em vez do lugar genérico (braço em z=0,9, cabeça em y=-0,5)."""
    bones = dict(bm.MOB_BONES)
    for name, h in heads.items():
        h0, t0, parent = bones[name]
        bones[name] = (tuple(h), tuple(h[i] + t0[i] - h0[i] for i in range(3)), parent)
    return bones


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
    quad_combat(arm, kind)
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


def quad_combat(arm, kind):
    """attack/hit/die dos quadrúpedes (e o básico das formas Lobo/Urso do druida, que é o "attack" deles).
    Mordida (lobo, lince, cão, dragão, grifo): recolhe com a cabeça erguida, dá o bote e crava, sacode e volta.
    Javali: abaixa a cabeça e joga as presas para cima. Urso: empina e desce a pata direita em gancho.
    Impacto no quadro 5 (EntityView.IMPACT_FRAME["attack"]); o jogo estica a preparação até o startup do bicho.
    Morte: gane, as patas da frente dobram, rola de lado (raiz +Z) com as patas duras e quica."""
    _drop_clips(arm, ("attack", "hit", "die"))
    z = (0, 0, 0)
    r = lambda x=0.0, y=0.0, zz=0.0: (x, y, zz)
    p = lambda up=0.0, fwd=0.0: (0, up, fwd)
    heavy = kind in ("bear", "boar")
    if kind == "bear":
        e = 18
        atk = {
            "body": [(1, z, z), (3, r(-24), p(0.12, -0.04)), (5, r(12, 0, -6), p(-0.02, 0.14)), (8, r(10, 0, -4), p(-0.02, 0.12)), (12, r(2), p(0, 0.04)), (15, r(-2), p(0.01)), (e, z, z)],
            "head": [(1, z, z), (3, r(-14, 0, 6), z), (5, r(16, 0, -10), z), (8, r(12, 0, -6), z), (12, r(2), z), (e, z, z)],
            "leg_fr": [(1, z, z), (3, r(-80, 0, 14), z), (5, r(34, 0, -14), z), (8, r(24, 0, -8), z), (12, r(6), z), (e, z, z)],
            "leg_fl": [(1, z, z), (3, r(-30), z), (5, r(-8), z), (8, r(-6), z), (12, r(-2), z), (e, z, z)],
            "leg_br": [(1, z, z), (3, r(24), z), (5, r(-8), z), (9, r(-4), z), (e, z, z)],
            "leg_bl": [(1, z, z), (3, r(24), z), (5, r(-10), z), (9, r(-6), z), (e, z, z)],
            "tail": [(1, z, z), (3, r(16), z), (5, r(-6, 0, 8), z), (9, r(4, 0, -6), z), (e, z, z)],
        }
    elif kind == "boar":
        e = 16
        atk = {
            "body": [(1, z, z), (3, r(8), p(-0.04, -0.1)), (5, r(-10), p(0.04, 0.22)), (8, r(-6), p(0.02, 0.18)), (11, r(2), p(0, 0.06)), (e, z, z)],
            "head": [(1, z, z), (3, r(22), z), (5, r(-26), z), (8, r(-16, 0, 10), z), (11, r(-4, 0, -6), z), (e, z, z)],
            "leg_fr": [(1, z, z), (3, r(14), z), (5, r(-26), z), (8, r(-18), z), (12, r(-4), z), (e, z, z)],
            "leg_fl": [(1, z, z), (3, r(10), z), (5, r(-20), z), (8, r(-14), z), (12, r(-2), z), (e, z, z)],
            "leg_br": [(1, z, z), (3, r(-14), z), (5, r(30), z), (8, r(18), z), (12, r(4), z), (e, z, z)],
            "leg_bl": [(1, z, z), (3, r(-14), z), (5, r(26), z), (8, r(14), z), (12, r(2), z), (e, z, z)],
            "tail": [(1, z, z), (3, r(10), z), (5, r(-14), z), (9, r(6, 0, 10), z), (e, z, z)],
        }
    else:
        e = 16
        atk = {
            "body": [(1, z, z), (3, r(-7), p(-0.02, -0.08)), (5, r(9), p(0.03, 0.2)), (7, r(7), p(0.02, 0.17)), (10, r(4), p(0.01, 0.1)), (13, r(-2), p(0, 0.02)), (e, z, z)],
            "head": [(1, z, z), (3, r(-18), z), (5, r(26), z), (7, r(16, 0, 14), z), (9, r(18, 0, -12), z), (12, r(-4), z), (e, z, z)],
            "leg_fr": [(1, z, z), (3, r(10), z), (5, r(-36), z), (7, r(-24), z), (10, r(-10), z), (13, r(4), z), (e, z, z)],
            "leg_fl": [(1, z, z), (3, r(8), z), (5, r(-26), z), (7, r(-18), z), (10, r(-6), z), (13, r(2), z), (e, z, z)],
            "leg_br": [(1, z, z), (3, r(-12), z), (5, r(28), z), (7, r(16), z), (10, r(6), z), (e, z, z)],
            "leg_bl": [(1, z, z), (3, r(-12), z), (5, r(22), z), (7, r(12), z), (10, r(4), z), (e, z, z)],
            "tail": [(1, z, z), (3, r(16), z), (5, r(-12, 0, 8), z), (7, r(-6, 0, -10), z), (10, r(4, 0, 8), z), (e, z, z)],
        }
    lp.add_action(arm, "attack", atk, e, loop=False)
    # tranco: o corpo recua, a cabeça vira, o rabo encolhe e as patas da frente escorregam
    lp.add_action(arm, "hit", {
        "body": [(1, z, z), (2, r(-9, 0, 7), p(0.02, -0.09)), (5, r(4, 0, -3), p(-0.01, -0.05)), (7, r(-1), p(0, -0.02)), (10, z, z)],
        "head": [(1, z, z), (2, r(-24, 0, 16), z), (5, r(8, 0, -8), z), (7, r(-2), z), (10, z, z)],
        "leg_fr": [(1, z, z), (2, r(-14), z), (5, r(6), z), (10, z, z)],
        "leg_fl": [(1, z, z), (2, r(-10), z), (5, r(4), z), (10, z, z)],
        "leg_br": [(1, z, z), (2, r(10), z), (5, r(-4), z), (10, z, z)],
        "leg_bl": [(1, z, z), (2, r(8), z), (5, r(-4), z), (10, z, z)],
        "tail": [(1, z, z), (2, r(-26), z), (5, r(-14, 0, 6), z), (10, z, z)],
    }, 10, loop=False)
    # morte: rola sobre o lado direito; a raiz gira em volta do chão, então sobe (loc Y) para o corpo deitar em cima dele
    up = 0.2 if heavy else 0.16
    s = 1.25 if heavy else 1.0                  # pesado: cai mais devagar
    f = lambda x: int(round(1 + (x - 1) * s))
    e = f(24)
    lp.add_action(arm, "die", {
        "body": [(1, z, z), (f(4), r(-14), p(0.04, -0.05)), (f(9), r(12), p(-0.12, 0.02)), (f(14), r(4), p(-0.05)), (e, r(4), p(-0.05))],
        "head": [(1, z, z), (f(4), r(-32, 0, 8), z), (f(9), r(22), z), (f(14), r(6, 0, -18), z), (f(17), r(-4, 0, -10), z), (f(20), r(6, 0, -18), z), (e, r(6, 0, -18), z)],
        "leg_fr": [(1, z, z), (f(4), r(-16), z), (f(9), r(34), z), (f(14), r(-22), z), (f(17), r(-30), z), (e, r(-22), z)],
        "leg_fl": [(1, z, z), (f(4), r(-12), z), (f(9), r(30), z), (f(14), r(-10), z), (f(17), r(-16), z), (e, r(-10), z)],
        "leg_br": [(1, z, z), (f(4), r(8), z), (f(9), r(-18), z), (f(14), r(18), z), (f(17), r(26), z), (e, r(18), z)],
        "leg_bl": [(1, z, z), (f(4), r(8), z), (f(9), r(-18), z), (f(14), r(28), z), (f(17), r(34), z), (e, r(28), z)],
        "tail": [(1, z, z), (f(4), r(-24), z), (f(9), r(-30), z), (f(14), r(6, 0, 10), z), (f(17), r(10, 0, 18), z), (e, r(4, 0, 12), z)],
        "root": [(1, z, z), (f(9), z, (0, -0.02, 0)), (f(14), r(0, 0, 84), (0, up, 0)), (f(17), r(0, 0, 76), (0, up, 0)), (f(20), r(0, 0, 84), (0, up, 0)), (e, r(0, 0, 84), (0, up, 0))],
    }, e, loop=False)


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
    arm = lp.make_armature("rig_" + cid, pivots(leg_fr=(0.15, -0.18, 0.42), leg_fl=(-0.15, -0.18, 0.42), leg_br=(0.15, 0.1, 0.42),
                                                leg_bl=(-0.15, 0.1, 0.42), head=(0, -0.22, 0.45)))
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
    arm = lp.make_armature("rig_" + cid, pivots(arm_r=(0.46, -0.22, 0.34), arm_l=(-0.46, -0.22, 0.34), leg_fr=(0.4, 0.03, 0.3),
                                                leg_fl=(-0.4, 0.03, 0.3), leg_br=(0.4, 0.27, 0.3), leg_bl=(-0.4, 0.27, 0.3), head=(0, -0.3, 0.45)))
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
    boss_gestures.crab_attack(arm)
    return arm


# ---------------------------------------------------------------------------
# espectro, ent, golem
# ---------------------------------------------------------------------------
def ghost(cid="mob_ghost"):
    arm = lp.make_armature("rig_" + cid, pivots(head=(0, -0.2, 1.1), arm_r=(0.36, -0.05, 1.05), arm_l=(-0.36, -0.05, 1.05)))
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
    arm = lp.make_armature("rig_" + cid, pivots(arm_r=(0.3, 0, 1.18), arm_l=(-0.3, 0, 1.18), head=(0, -0.1, 1.3),
                                                leg_fr=(0.18, -0.15, 0.36), leg_fl=(-0.18, -0.15, 0.36), leg_br=(0.18, 0.15, 0.36), leg_bl=(-0.18, 0.15, 0.36)))
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


def elf_parts(cid, cloth2, ears=True, cape=False, hair=None, hood=None):
    """Elfo (referência: elfos de Battle for Wesnoth): orelhas longas, faixa na testa, CABELO LONGO solto caindo pelas
    costas (o que se lê de cima e de trás), capa opcional e capuz de atirador (`hood` = cor) com o cabelo saindo por baixo."""
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
        if hair:                                       # mechas longas: da nuca até a cintura, abrindo um pouco
            hm = ck.mat("m_%s_longhair" % cid, hair, 0.55)
            zc = ck.Z["chest"]
            back = b["chest"] * b["depth"]
            for i, x in enumerate((-0.55, -0.27, 0.0, 0.27, 0.55)):
                root = c + V((x * r, r * 0.72, r * 0.25 - abs(x) * r * 0.2))
                tip = V((x * r * 1.35, back + 0.12 + abs(x) * 0.05, zc - 0.22 - (0.06 if i % 2 else 0.0)))
                head.append(ck.tube("%s_lock%d" % (cid, i), root, tip, r * 0.26, r * 0.07, hm, 7))
            head.append(ck.blade(cid + "_hairsheet", c + V((0, r * 0.8, r * 0.1)), V((0, back + 0.1, zc - 0.18)), r * 1.25, r * 0.12, hm, (1, 0, 0), 0.35))
            for sx in (-1, 1):                         # mechas da frente, por trás das orelhas, caindo nos ombros
                root = c + V((sx * r * 0.82, r * 0.2, -r * 0.05))
                head.append(ck.tube("%s_side%d" % (cid, sx), root, root + V((sx * r * 0.15, r * 0.15, -r * 1.05)), r * 0.2, r * 0.06, hm, 6))
        if hood:                                       # capuz de atirador: cobre o alto da cabeça, aberto na frente
            hd = ck.mat("m_%s_hood" % cid, hood, 0.8)
            head.append(ck.ball(cid + "_hood", r * 1.12, c + V((0, r * 0.12, r * 0.12)), hd, (1.0, 1.05, 0.95)))
            head.append(ck.tube(cid + "_hoodtip", c + V((0, r * 0.95, r * 0.4)), c + V((0, r * 1.5, -r * 0.2)), r * 0.35, r * 0.05, hd, 7))
        for p_ in head:
            ck.skin_rigid(p_, rig, "head")
        if cape:
            zc = ck.Z["chest"]
            back = b["chest"] * b["depth"] + 0.03
            ch = [ck.blade(cid + "_mantle", V((0, back, zc + 0.12)), V((0, back + 0.18, ck.Z["knee"])), 0.5, 0.03, band, (1, 0, 0), 0.4)]
            for p_ in ch:
                ck.skin_rigid(p_, rig, "chest")
    return add


def longbow(base, mats):
    """Arco longo (Wesnoth): estica o arco da mão 40% na vertical em volta do centro dele."""
    for o in bpy.context.scene.objects:
        if o.type == "MESH" and o.name.startswith("wpn_main_bow"):
            zs = [v.co.z for v in o.data.vertices]
            mid = (min(zs) + max(zs)) * 0.5
            for v in o.data.vertices:
                v.co.z = mid + (v.co.z - mid) * 1.4


def warrior_bows(base, mats):
    """Batedor élfico que troca a espada pelo arco com pouca vida: arco nas costas (wpn_back_bow, preso ao peito) e
    o mesmo arco na mão esquerda (wpn_alt_bow) que o jogo só mostra na troca (EntityView, SimEntity.stance == "bow")."""
    rig = base["rig"]
    hand = ck.kit_weapon(base, "bow", "main", mats)
    hand.name = "wpn_alt_bow"
    hand.data.name = "wpn_alt_bow"
    back = hand.copy()
    back.data = hand.data.copy()
    back.name = "wpn_back_bow"
    back.data.name = "wpn_back_bow"
    bpy.context.scene.collection.objects.link(back)
    back.modifiers.clear()
    back.vertex_groups.clear()
    c = sum((v.co for v in back.data.vertices), Vector()) / len(back.data.vertices)
    R = Matrix.Rotation(math.radians(38), 4, "Y") @ Matrix.Rotation(math.radians(90), 4, "Z")
    to = Vector((0.0, base["b"]["chest"] * base["b"]["depth"] + 0.06, ck.Z["chest"] - 0.02))
    for v in back.data.vertices:
        v.co = (R @ (v.co - c)) + to
    back.parent = None
    ck.skin_rigid(back, rig, "chest")


def elf_captain_parts(cid, cloth2, kind):
    """Capitães élficos: orelhas e manto do elf_parts + a peça que os distingue de cima (cabeça e ombros).
    hunter = chapéu de aba larga com pluma comprida e aljava; sky = elmo alado; sap = coroa de folhas e ombreiras de casca."""
    base_add = elf_parts(cid, cloth2, cape=True, hair=None if kind == "sky" else ((0.95, 0.85, 0.5) if kind == "hunter" else (0.62, 0.85, 0.5)))

    def add(base, mats):
        base_add(base, mats)
        V = Vector
        rig, b = base["rig"], base["b"]
        c, r = V(base["head_c"]), b["head"]
        gold = ck.mat("m_%s_gold" % cid, (0.95, 0.78, 0.3), 0.4)
        head = []
        body = []
        if kind == "hunter":
            felt = ck.mat("m_%s_hat" % cid, (0.22, 0.42, 0.3), 0.7)
            plume = ck.mat("m_%s_plume" % cid, (0.95, 0.55, 0.2), 0.6)
            head.append(ck.tube(cid + "_brim", c + V((0, 0, r * 0.62)), c + V((0, 0, r * 0.7)), r * 1.55, r * 1.5, felt, 18))
            head.append(ck.tube(cid + "_crown", c + V((0, 0, r * 0.68)), c + V((0, 0.02, r * 1.2)), r * 0.85, r * 0.55, felt, 14))
            head.append(ck.blade(cid + "_plume", c + V((r * 0.4, r * 0.2, r * 1.1)), c + V((r * 1.3, r * 1.4, r * 1.9)), r * 0.35, r * 0.05, plume, (1, 0, 0), 0.5))
            zc = ck.Z["chest"]
            back = b["chest"] * b["depth"] + 0.06
            body.append(ck.tube(cid + "_quiver", V((0.1, back, zc - 0.15)), V((0.2, back + 0.05, zc + 0.35)), 0.07, 0.08, felt, 8))
            for i in range(3):
                body.append(ck.tube(cid + "_arrow%d" % i, V((0.14 + i * 0.03, back + 0.05, zc + 0.3)), V((0.2 + i * 0.04, back + 0.08, zc + 0.5)), 0.012, 0.012, plume, 4))
        elif kind == "sky":
            plate = ck.mat("m_%s_helm" % cid, (0.88, 0.9, 0.95), 0.35)
            feather = ck.mat("m_%s_wing" % cid, (0.97, 0.97, 1.0), 0.6)
            head.append(ck.ball(cid + "_helm", r * 1.2, c + V((0, r * 0.04, r * 0.16)), plate, (1, 1.02, 0.9)))
            head.append(ck.tube(cid + "_rim", c + V((0, 0, r * 0.18)), c + V((0, 0, r * 0.3)), r * 1.22, r * 1.2, gold, 20))
            head.append(ck.tube(cid + "_crest", c + V((0, -r * 0.2, r * 1.0)), c + V((0, r * 0.7, r * 1.35)), r * 0.12, r * 0.04, gold, 6))
            for sx in (-1, 1):
                for k in range(3):
                    root = c + V((sx * r * 0.95, r * (0.05 + k * 0.12), r * (0.3 + k * 0.1)))
                    head.append(ck.blade(cid + "_wing%d_%d" % (sx, k), root, root + V((sx * r * (0.9 - k * 0.15), r * 0.35, r * (0.95 - k * 0.2))), r * 0.28, r * 0.04, feather, (0, 1, 0), 0.5))
        else:                                              # sap
            leaf = ck.mat("m_%s_leaf" % cid, (0.45, 0.85, 0.4), 0.6, 0.6)
            bark = ck.mat("m_%s_bark" % cid, (0.42, 0.3, 0.2), 0.85)
            for i in range(9):
                a = math.tau * i / 9
                root = c + V((math.cos(a) * r * 1.0, math.sin(a) * r * 1.0, r * 0.8))
                head.append(ck.blade(cid + "_leaf%d" % i, root, root + V((math.cos(a) * r * 0.45, math.sin(a) * r * 0.45, r * (0.85 + 0.3 * (i % 2)))), r * 0.42, r * 0.05, leaf, (-math.sin(a), math.cos(a), 0), 0.5))
            head.append(ck.ball(cid + "_sapgem", r * 0.16, c + V((0, -r * 0.95, r * 0.45)), ck.mat("m_%s_sap" % cid, (0.75, 1.0, 0.45), 0.3, 2.2)))
            zs = ck.Z["chest"] + 0.12
            for sx in (-1, 1):
                body.append(ck.ball(cid + "_pauldron%d" % sx, 0.15, V((sx * (b["chest"] + 0.05), 0.0, zs)), bark, (1.1, 1.0, 0.7)))
                body.append(ck.blade(cid + "_pleaf%d" % sx, V((sx * (b["chest"] + 0.08), 0.0, zs + 0.08)), V((sx * (b["chest"] + 0.3), 0.05, zs + 0.3)), 0.12, 0.02, leaf, (0, 1, 0), 0.5))
        for p_ in head:
            ck.skin_rigid(p_, rig, "head")
        for p_ in body:
            ck.skin_rigid(p_, rig, "chest")
    return add


def outlaw_parts(cid, kind, cloth2):
    """Linha dos fora-da-lei (referência: os fora-da-lei de Battle for Wesnoth, arte nossa): o que se lê de cima é a cabeça.
    footpad = lenço amarrado com pontas soltas e bolsa de funda; thief = capuz fundo com bico e máscara de pano;
    poacher = chapéu de feltro mole de aba caída e aljava; brute = careca, barba cheia e pele de bicho num ombro;
    outlaw = capuz curto com cachecol, ombreira cravejada e faixa vermelha; thug = careca com faixa e ombros largos;
    chief = tricórnio com pluma, barba, casaca comprida e argola de ouro."""
    def add(base, mats):
        V = Vector
        rig, b = base["rig"], base["b"]
        c, r = V(base["head_c"]), b["head"]
        acc = ck.mat("m_%s_acc" % cid, cloth2, 0.75)
        leather = ck.mat("m_%s_strap" % cid, (0.3, 0.2, 0.13), 0.85)
        beard_m = ck.mat("m_%s_beard" % cid, (0.32, 0.2, 0.12), 0.8)
        steel = ck.mat("m_%s_steel" % cid, (0.62, 0.62, 0.66), 0.4)
        gold = ck.mat("m_%s_gold" % cid, (0.95, 0.78, 0.3), 0.4)
        zc, back = ck.Z["chest"], b["chest"] * b["depth"]
        head, body = [], []

        def beard(scale):
            head.append(ck.ball(cid + "_beard", r * 0.4 * scale, c + V((0, -r * 0.62, -r * 0.82)), beard_m, (1.25, 0.7, 0.85)))

        def bald_shine():
            head.append(ck.ball(cid + "_scalp", r * 1.01, c + V((0, r * 0.02, r * 0.06)), ck.mat("m_%s_scalp" % cid, (0.93, 0.76, 0.62), 0.45), (1, 1, 0.98)))

        if kind == "footpad":
            head.append(ck.ball(cid + "_kerchief", r * 1.1, c + V((0, r * 0.08, r * 0.22)), acc, (1.0, 1.02, 0.84)))
            head.append(ck.tube(cid + "_knot", c + V((0, r * 1.0, r * 0.25)), c + V((0, r * 1.2, r * 0.25)), r * 0.16, r * 0.12, acc, 6))
            for sx in (-1, 1):
                head.append(ck.blade("%s_tail%d" % (cid, sx), c + V((sx * r * 0.1, r * 1.15, r * 0.22)), c + V((sx * r * 0.55, r * 1.75, -r * 0.35)), r * 0.24, r * 0.04, acc, (1, 0, 0), 0.4))
            body.append(ck.ball(cid + "_pouch", 0.07, V((0.2, -0.05, ck.Z["waist"] - 0.04)), leather, (1, 0.8, 1.1)))
            body.append(ck.tube(cid + "_sling", V((0.2, -0.08, ck.Z["waist"])), V((0.26, -0.1, ck.Z["hip"])), 0.012, 0.012, leather, 4))
        elif kind == "thief":
            hd = ck.mat("m_%s_hood" % cid, (0.2, 0.19, 0.24), 0.85)
            head.append(ck.ball(cid + "_hood", r * 1.16, c + V((0, r * 0.14, r * 0.1)), hd, (1.0, 1.08, 1.0)))
            head.append(ck.tube(cid + "_hoodtip", c + V((0, r * 0.9, r * 0.6)), c + V((0, r * 1.7, r * 0.05)), r * 0.42, r * 0.04, hd, 7))
            head.append(ck.tube(cid + "_mask", c + V((0, 0, -r * 0.42)), c + V((0, 0, -r * 0.1)), r * 1.0, r * 1.04, acc, 18))
            for sx in (-1, 1):
                body.append(ck.tube("%s_belt_knife%d" % (cid, sx), V((sx * 0.17, -0.02, ck.Z["waist"])), V((sx * 0.2, -0.02, ck.Z["hip"] - 0.02)), 0.02, 0.008, steel, 4))
        elif kind == "poacher":
            felt = ck.mat("m_%s_hat" % cid, (0.4, 0.3, 0.18), 0.85)
            head.append(ck.tube(cid + "_brim", c + V((0, r * 0.05, r * 0.5)), c + V((0, r * 0.05, r * 0.44)), r * 1.45, r * 1.6, felt, 16))
            head.append(ck.ball(cid + "_hatcrown", r * 1.02, c + V((0, r * 0.05, r * 0.62)), felt, (1.0, 1.0, 0.78)))
            head.append(ck.tube(cid + "_hatband", c + V((0, 0, r * 0.52)), c + V((0, 0, r * 0.64)), r * 1.0, r * 0.98, acc, 16))
            head.append(ck.blade(cid + "_feather", c + V((r * 0.85, r * 0.2, r * 0.75)), c + V((r * 1.4, r * 1.0, r * 1.35)), r * 0.28, r * 0.04, acc, (1, 0, 0), 0.5))
            body.append(ck.tube(cid + "_quiver", V((-0.1, back + 0.06, zc - 0.18)), V((-0.2, back + 0.1, zc + 0.3)), 0.07, 0.08, leather, 8))
            for i in range(3):
                body.append(ck.tube(cid + "_arrow%d" % i, V((-0.14 - i * 0.03, back + 0.1, zc + 0.26)), V((-0.2 - i * 0.04, back + 0.13, zc + 0.46)), 0.012, 0.012, acc, 4))
        elif kind == "brute":
            bald_shine()
            beard(1.15)
            fur = ck.mat("m_%s_fur" % cid, (0.5, 0.42, 0.32), 0.95)
            body.append(ck.ball(cid + "_fur", 0.2, V((b["chest"] * 0.8, 0.02, zc + 0.16)), fur, (1.1, 1.1, 0.75)))
            body.append(ck.tube(cid + "_strap", V((b["chest"] * 0.8, -0.1, zc + 0.15)), V((-b["chest"] * 0.7, -0.12, ck.Z["waist"])), 0.03, 0.03, leather, 5))
        elif kind == "outlaw":
            hd = ck.mat("m_%s_cowl" % cid, (0.3, 0.24, 0.18), 0.85)
            head.append(ck.ball(cid + "_cowl", r * 1.14, c + V((0, r * 0.15, r * 0.14)), hd, (1.0, 1.05, 0.95)))
            head.append(ck.tube(cid + "_scarf", c + V((0, 0, -r * 1.02)), c + V((0, 0, -r * 0.8)), r * 0.72, r * 0.78, acc, 16))
            for sx in (-1, 1):
                body.append(ck.ball("%s_pauldron%d" % (cid, sx), 0.15, V((sx * (b["chest"] + 0.04), 0.0, zc + 0.12)), leather, (1.1, 1.0, 0.7)))
                for k in range(3):
                    body.append(ck.tube("%s_stud%d_%d" % (cid, sx, k), V((sx * (b["chest"] + 0.04 + (k - 1) * 0.06), -0.02, zc + 0.2)),
                                        V((sx * (b["chest"] + 0.04 + (k - 1) * 0.06), -0.02, zc + 0.3)), 0.025, 0.004, steel, 4))
            body.append(ck.tube(cid + "_sash", V((b["chest"] * 0.9, -0.12, zc + 0.12)), V((-b["chest"] * 0.8, -0.13, ck.Z["waist"] - 0.02)), 0.045, 0.045, ck.mat("m_%s_sash" % cid, (0.75, 0.15, 0.12), 0.7), 5))
            body.append(ck.ball(cid + "_pouch", 0.07, V((-0.2, -0.05, ck.Z["waist"] - 0.04)), leather, (1, 0.8, 1.1)))
        elif kind == "thug":
            bald_shine()
            head.append(ck.tube(cid + "_band", c + V((0, 0, r * 0.32)), c + V((0, 0, r * 0.46)), r * 1.04, r * 1.03, acc, 18))
            beard(0.85)
            for sx in (-1, 1):
                body.append(ck.ball("%s_shoulder%d" % (cid, sx), 0.16, V((sx * (b["chest"] + 0.03), 0.0, zc + 0.12)), leather, (1.15, 1.0, 0.75)))
        else:                                   # chief (salteador)
            felt = ck.mat("m_%s_tricorne" % cid, (0.16, 0.12, 0.1), 0.8)
            head.append(ck.ball(cid + "_hatcrown", r * 0.9, c + V((0, r * 0.05, r * 0.85)), felt, (1.0, 1.0, 0.62)))
            for i in range(3):                  # tricórnio: três abas viradas, uma na frente
                a = math.radians(-90 + i * 120)
                d = V((math.cos(a), math.sin(a), 0))
                head.append(ck.blade("%s_brim%d" % (cid, i), c + V((0, 0, r * 0.7)) + d * r * 0.2, c + V((0, 0, r * 1.05)) + d * r * 1.5, r * 1.7, r * 0.06, felt, (-d.y, d.x, 0), 0.5))
            head.append(ck.tube(cid + "_hatband", c + V((0, 0, r * 0.7)), c + V((0, 0, r * 0.8)), r * 0.92, r * 0.9, gold, 16))
            head.append(ck.blade(cid + "_plume", c + V((r * 0.5, r * 0.3, r * 1.1)), c + V((r * 1.4, r * 1.6, r * 1.6)), r * 0.45, r * 0.05, ck.mat("m_%s_plume" % cid, (0.85, 0.15, 0.12), 0.6), (1, 0, 0), 0.5))
            beard(1.0)
            head.append(ck.tube(cid + "_earring", c + V((r * 0.98, 0, -r * 0.3)), c + V((r * 1.0, 0, -r * 0.45)), r * 0.09, r * 0.09, gold, 8))
            coat = ck.mat("m_%s_coat" % cid, cloth2, 0.75)
            body.append(ck.blade(cid + "_coattail", V((0, back + 0.03, ck.Z["waist"])), V((0, back + 0.14, ck.Z["knee"] - 0.06)), 0.46, 0.03, coat, (1, 0, 0), 0.35))
            for sx in (-1, 1):
                body.append(ck.ball("%s_lapel%d" % (cid, sx), 0.12, V((sx * 0.1, -b["chest"] * b["depth"] - 0.02, zc + 0.05)), coat, (0.6, 0.3, 1.2)))
                body.append(ck.ball("%s_epaulet%d" % (cid, sx), 0.12, V((sx * (b["chest"] + 0.03), 0.0, zc + 0.13)), gold, (1.15, 1.0, 0.55)))
        for p_ in head:
            ck.skin_rigid(p_, rig, "head")
        for p_ in body:
            ck.skin_rigid(p_, rig, "chest")
    return add


def _top_vertex(prefix):
    """Ponta mais alta (z) das malhas que começam com `prefix` (ex.: a ponta do cajado para virar lança)."""
    best = None
    for o in bpy.context.scene.objects:
        if o.type == "MESH" and o.name.startswith(prefix):
            for v in o.data.vertices:
                w = o.matrix_world @ v.co
                if best is None or w.z > best.z:
                    best = w.copy()
    return best


def loyalist_parts(cid, kind, cloth2):
    """Guarnição da Luz (referência: loyalists de Battle for Wesnoth, arte nossa). De cima o que conta é a cabeça:
    spearman = elmo aberto com crista vermelha, lança (cajado com ponta); knight = elmo fechado de balde com pluma e
    tabardo com sol; paladin = elmo claro com auréola dourada; priest = mitra branca e dourada com disco de sol no cajado;
    crossbow = chapéu de ferro de aba larga."""
    def add(base, mats):
        V = Vector
        rig, b = base["rig"], base["b"]
        c, r = V(base["head_c"]), b["head"]
        steel = ck.mat("m_%s_steel" % cid, (0.82, 0.84, 0.88), 0.35)
        gold = ck.mat("m_%s_gold" % cid, (0.98, 0.8, 0.3), 0.35, 0.3)
        acc = ck.mat("m_%s_acc" % cid, cloth2, 0.7)
        zc, front = ck.Z["chest"], -b["chest"] * b["depth"]
        head, body, hand = [], [], []
        if kind == "spearman":
            head.append(ck.ball(cid + "_helm", r * 1.1, c + V((0, r * 0.05, r * 0.22)), steel, (1, 1.02, 0.8)))
            head.append(ck.tube(cid + "_rim", c + V((0, 0, r * 0.12)), c + V((0, 0, r * 0.22)), r * 1.12, r * 1.1, steel, 18))
            head.append(ck.blade(cid + "_crest", c + V((0, -r * 0.7, r * 1.0)), c + V((0, r * 1.1, r * 0.95)), r * 0.42, r * 0.07, acc, (0, 0, 1), 0.5))
            tip = _top_vertex("wpn_main_staff")
            if tip is not None:
                hand.append(ck.blade(cid + "_spearhead", tip - V((0, 0, 0.02)), tip + V((0, -0.05, 0.3)), 0.11, 0.03, steel, (1, 0, 0), 0.4))
                hand.append(ck.tube(cid + "_pennant_pole", tip - V((0, 0, 0.12)), tip - V((0, 0, 0.02)), 0.03, 0.03, gold, 6))
        elif kind == "knight":
            head.append(ck.tube(cid + "_bucket", c + V((0, 0, -r * 0.55)), c + V((0, 0, r * 0.75)), r * 1.12, r * 1.05, steel, 16))
            head.append(ck.ball(cid + "_dome", r * 1.05, c + V((0, 0, r * 0.72)), steel, (1, 1, 0.45)))
            head.append(ck.tube(cid + "_slit", c + V((-r * 0.55, -r * 1.1, r * 0.12)), c + V((r * 0.55, -r * 1.1, r * 0.12)), r * 0.07, r * 0.07, ck.mat("m_%s_dark" % cid, (0.08, 0.08, 0.1), 0.6), 6))
            head.append(ck.tube(cid + "_cross", c + V((0, -r * 1.12, -r * 0.4)), c + V((0, -r * 1.12, r * 0.6)), r * 0.06, r * 0.06, gold, 4))
            for k in range(3):
                head.append(ck.blade("%s_plume%d" % (cid, k), c + V((0, r * 0.1, r * 1.1)), c + V(((k - 1) * r * 0.35, r * 1.6, r * (1.7 - abs(k - 1) * 0.25))), r * 0.3, r * 0.05, acc, (1, 0, 0), 0.45))
            body.append(ck.blade(cid + "_tabard", V((0, front - 0.03, zc + 0.12)), V((0, front - 0.05, ck.Z["knee"] + 0.04)), 0.3, 0.02, acc, (1, 0, 0), 0.25))
            body.append(ck.ball(cid + "_sun", 0.07, V((0, front - 0.07, zc - 0.04)), gold, (1, 0.4, 1)))
        elif kind == "paladin":
            head.append(ck.ball(cid + "_helm", r * 1.08, c + V((0, r * 0.18, r * 0.36)), ck.mat("m_%s_white" % cid, (0.95, 0.94, 0.9), 0.3), (1, 1.0, 0.72)))
            head.append(ck.tube(cid + "_visor", c + V((0, 0, r * 0.38)), c + V((0, 0, r * 0.5)), r * 1.1, r * 1.08, gold, 18))
            for sx in (-1, 1):
                head.append(ck.blade("%s_wingcheek%d" % (cid, sx), c + V((sx * r * 0.95, r * 0.1, r * 0.45)), c + V((sx * r * 1.45, r * 0.55, r * 1.05)), r * 0.3, r * 0.04, gold, (0, 1, 0), 0.45))
            head.append(ck.tube(cid + "_halo", c + V((0, r * 0.25, r * 1.45)), c + V((0, r * 0.25, r * 1.52)), r * 0.85, r * 0.85, gold, 20))
            head.append(ck.tube(cid + "_halo_in", c + V((0, r * 0.25, r * 1.44)), c + V((0, r * 0.25, r * 1.53)), r * 0.66, r * 0.66, ck.mat("m_%s_glow" % cid, (1.0, 0.95, 0.7), 0.3, 1.5), 20))
            for sx in (-1, 1):
                body.append(ck.ball("%s_pauldron%d" % (cid, sx), 0.16, V((sx * (b["chest"] + 0.04), 0.0, zc + 0.12)), gold, (1.15, 1.0, 0.7)))
        elif kind == "priest":
            white = ck.mat("m_%s_white" % cid, (0.97, 0.96, 0.92), 0.5)
            head.append(ck.tube(cid + "_mitre", c + V((0, 0, r * 0.45)), c + V((0, 0, r * 1.75)), r * 0.9, r * 0.25, white, 12))
            head.append(ck.tube(cid + "_mitre_band", c + V((0, 0, r * 0.45)), c + V((0, 0, r * 0.62)), r * 0.93, r * 0.9, gold, 12))
            head.append(ck.blade(cid + "_mitre_cross", c + V((0, -r * 0.62, r * 0.8)), c + V((0, -r * 0.5, r * 1.45)), r * 0.2, r * 0.03, gold, (1, 0, 0), 0.5))
            body.append(ck.blade(cid + "_stole", V((0, front - 0.03, zc + 0.15)), V((0, front - 0.04, ck.Z["knee"])), 0.12, 0.02, gold, (1, 0, 0), 0.3))
            tip = _top_vertex("wpn_main_staff")
            if tip is not None:
                hand.append(ck.tube(cid + "_sun", tip + V((0, 0.02, 0.06)), tip + V((0, -0.02, 0.06)), 0.16, 0.16, gold, 14))
                hand.append(ck.ball(cid + "_sun_core", 0.07, tip + V((0, -0.03, 0.06)), ck.mat("m_%s_glow" % cid, (1.0, 0.95, 0.7), 0.3, 1.8)))
        else:                                   # crossbow
            head.append(ck.tube(cid + "_brim", c + V((0, 0, r * 0.45)), c + V((0, 0, r * 0.52)), r * 1.55, r * 1.5, steel, 16))
            head.append(ck.ball(cid + "_kettle", r * 1.02, c + V((0, r * 0.02, r * 0.55)), steel, (1, 1, 0.72)))
            body.append(ck.blade(cid + "_tabard", V((0, front - 0.03, zc + 0.12)), V((0, front - 0.04, ck.Z["waist"] - 0.1)), 0.26, 0.02, acc, (1, 0, 0), 0.25))
        for p_ in head:
            ck.skin_rigid(p_, rig, "head")
        for p_ in body:
            ck.skin_rigid(p_, rig, "chest")
        for p_ in hand:
            ck.skin_rigid(p_, rig, "hand.R")
    return add


def undead_parts(cid, kind, glow):
    """Mortos-vivos (referência: mortos-vivos de Battle for Wesnoth, arte nossa). Cabeça e ombros definem cada um:
    blade = meio-elmo enferrujado com chifre e ombreira; archer = capuz rasgado e aljava; guard = elmo de crista e
    escudo grande; knight = coroa de espinhos negra, capa e olhos acesos; ghoul = corcunda, careca, gotas de veneno;
    giant = barriga inchada, corcova e bolhas; cultist = capuz pontudo vermelho-escuro e máscara de osso;
    frost = coroa de estilhaços de gelo e ombreiras geladas; lichking = coroa alta, gola de espinhos e capa."""
    def add(base, mats):
        V = Vector
        rig, b = base["rig"], base["b"]
        c, r = V(base["head_c"]), b["head"]
        zc, back, front = ck.Z["chest"], b["chest"] * b["depth"], -b["chest"] * b["depth"]
        rust = ck.mat("m_%s_rust" % cid, (0.45, 0.32, 0.25), 0.7)
        dark = ck.mat("m_%s_dark" % cid, (0.14, 0.12, 0.16), 0.6)
        bone = ck.mat("m_%s_bone" % cid, (0.9, 0.87, 0.78), 0.6)
        gl = ck.mat("m_%s_glow" % cid, glow, 0.3, 2.2)
        head, body = [], []
        if kind == "blade":
            head.append(ck.ball(cid + "_halfhelm", r * 1.08, c + V((0, r * 0.08, r * 0.3)), rust, (1, 1.02, 0.7)))
            head.append(ck.tube(cid + "_horn", c + V((r * 0.6, 0, r * 0.75)), c + V((r * 1.2, r * 0.2, r * 1.5)), r * 0.16, r * 0.02, bone, 6))
            body.append(ck.ball(cid + "_pauldron", 0.17, V((-(b["chest"] + 0.04), 0.0, zc + 0.13)), rust, (1.2, 1.0, 0.75)))
        elif kind == "archer":
            hd = ck.mat("m_%s_hood" % cid, (0.3, 0.28, 0.24), 0.9)
            head.append(ck.ball(cid + "_hood", r * 1.14, c + V((0, r * 0.15, r * 0.12)), hd, (1, 1.05, 0.95)))
            for k in range(3):
                head.append(ck.blade("%s_rag%d" % (cid, k), c + V(((k - 1) * r * 0.4, r * 0.9, -r * 0.1)), c + V(((k - 1) * r * 0.55, r * 1.25, -r * 0.9)), r * 0.25, r * 0.03, hd, (1, 0, 0), 0.5))
            body.append(ck.tube(cid + "_quiver", V((-0.1, back + 0.06, zc - 0.18)), V((-0.2, back + 0.1, zc + 0.3)), 0.07, 0.08, rust, 8))
        elif kind == "guard":
            head.append(ck.ball(cid + "_helm", r * 1.1, c + V((0, r * 0.04, r * 0.2)), dark, (1, 1.02, 0.85)))
            head.append(ck.blade(cid + "_crest", c + V((0, -r * 0.6, r * 1.05)), c + V((0, r * 1.0, r * 1.0)), r * 0.35, r * 0.06, bone, (0, 0, 1), 0.5))
        elif kind == "knight":
            for i in range(7):
                a = math.tau * i / 7
                root = c + V((math.cos(a) * r * 0.9, math.sin(a) * r * 0.9, r * 0.75))
                head.append(ck.tube("%s_spike%d" % (cid, i), root, root + V((math.cos(a) * r * 0.2, math.sin(a) * r * 0.2, r * (0.7 + 0.25 * (i % 2)))), r * 0.12, r * 0.01, dark, 5))
            head.append(ck.tube(cid + "_band", c + V((0, 0, r * 0.62)), c + V((0, 0, r * 0.8)), r * 0.98, r * 0.96, dark, 18))
            body.append(ck.blade(cid + "_cape", V((0, back + 0.03, zc + 0.14)), V((0, back + 0.2, ck.Z["ankle"])), 0.55, 0.03, ck.mat("m_%s_cape" % cid, (0.3, 0.08, 0.12), 0.7), (1, 0, 0), 0.4))
            for sx in (-1, 1):
                body.append(ck.tube("%s_shoulder_spike%d" % (cid, sx), V((sx * (b["chest"] + 0.04), 0, zc + 0.16)), V((sx * (b["chest"] + 0.2), 0.05, zc + 0.38)), 0.07, 0.01, dark, 5))
        elif kind in ("ghoul", "giant"):
            pus = ck.mat("m_%s_pus" % cid, (0.55, 0.85, 0.25), 0.4, 0.6)
            hide = ck.mat("m_%s_hide" % cid, (0.4, 0.46, 0.32), 0.8)
            body.append(ck.ball(cid + "_hump", 0.3 if kind == "ghoul" else 0.36, V((0.04, back + 0.08, zc + 0.16)), hide, (1.1, 0.95, 0.95)))
            head.append(ck.ball(cid + "_jaw", r * 0.55, c + V((0, -r * 0.62, -r * 0.62)), ck.mat("m_%s_mouth" % cid, (0.25, 0.08, 0.08), 0.6), (1.2, 0.6, 0.6)))
            for i in range(5):
                x = (i - 2) * r * 0.2
                head.append(ck.tube("%s_tooth%d" % (cid, i), c + V((x, -r * 0.95, -r * 0.48)), c + V((x, -r * 0.98, -r * 0.7)), r * 0.06, r * 0.01, bone, 4))
            for sx in (-1, 1):
                head.append(ck.blade("%s_ear%d" % (cid, sx), c + V((sx * r * 0.9, r * 0.1, r * 0.2)), c + V((sx * r * 1.4, r * 0.3, r * 0.6)), r * 0.28, r * 0.04, hide, (0, 1, 0), 0.5))
            if kind == "giant":
                sore = ck.mat("m_%s_sore" % cid, (0.55, 0.12, 0.12), 0.5)
                rot_m = ck.mat("m_%s_mottle" % cid, (0.3, 0.36, 0.16), 0.8)
                for i in range(5):                    # feridas abertas na barriga, com borda de pus
                    a = -0.9 + i * 0.45
                    q = V((math.sin(a) * 0.31, front - 0.31 + abs(math.sin(a)) * 0.08, ck.Z["waist"] + 0.09 * math.cos(a * 3)))
                    body.append(ck.ball("%s_pusrim%d" % (cid, i), 0.1, q, pus, (1.2, 0.45, 1.0)))
                    body.append(ck.ball("%s_sore%d" % (cid, i), 0.075, q + V((0, -0.015, 0)), sore, (1.2, 0.5, 0.95)))
                body.append(ck.ball(cid + "_gash", 0.12, V((0.0, front - 0.36, ck.Z["waist"] - 0.06)), sore, (2.0, 0.4, 0.6)))
                for i in range(10):                   # manchas de podridão no corpo
                    a = math.tau * i / 10
                    body.append(ck.ball("%s_mottle%d" % (cid, i), 0.07, V((math.cos(a) * 0.3, math.sin(a) * 0.25 + 0.02, ck.Z["waist"] + 0.18 + 0.05 * (i % 3))), rot_m, (1.0, 0.5, 1.0)))
                head.append(ck.tube(cid + "_horn", c + V((r * 0.15, -r * 0.4, r * 0.75)), c + V((r * 0.35, -r * 0.9, r * 1.6)), r * 0.2, r * 0.02, bone, 6))
                fly = ck.mat("m_%s_fly" % cid, (0.08, 0.08, 0.06), 0.6)
                for i in range(24):                   # nuvem de moscas em volta da cabeça
                    a = math.tau * i / 12 + (0.26 if i >= 12 else 0.0)
                    head.append(ck.ball("%s_fly%d" % (cid, i), r * (0.05 if i < 12 else 0.04), c + V((math.cos(a) * r * (1.3 + 0.2 * (i % 3)), math.sin(a) * r * 1.3, r * (0.2 + 0.25 * (i % 4)))), fly))
                rust = ck.mat("m_%s_bell" % cid, (0.5, 0.36, 0.2), 0.5)
                body.append(ck.tube(cid + "_bellchain", V((0.22, front + 0.02, ck.Z["waist"] + 0.02)), V((0.24, front - 0.02, ck.Z["hip"])), 0.015, 0.015, rust, 4))
                body.append(ck.tube(cid + "_bell", V((0.24, front - 0.02, ck.Z["hip"] + 0.02)), V((0.24, front - 0.02, ck.Z["hip"] - 0.14)), 0.05, 0.11, rust, 10))
                for sx in (-1, 1):                    # chaminés de gás nas costas
                    body.append(ck.tube("%s_chimney%d" % (cid, sx), V((sx * 0.14, back + 0.2, zc + 0.2)), V((sx * 0.2, back + 0.32, zc + 0.5)), 0.06, 0.05, rust, 7))
                for i in range(4):
                    body.append(ck.tube("%s_backspike%d" % (cid, i), V(((i - 1.5) * 0.09, back + 0.2, zc + 0.05 + i * 0.05)), V(((i - 1.5) * 0.12, back + 0.45, zc + 0.3 + i * 0.07)), 0.05, 0.01, bone, 5))
            if kind == "giant":
                body.append(ck.ball(cid + "_belly", 0.34, V((0, front - 0.05, ck.Z["waist"])), ck.mat("m_%s_belly" % cid, (0.42, 0.48, 0.24), 0.7), (1.1, 0.9, 1.0)))
                for i in range(6):
                    a = math.tau * i / 6
                    body.append(ck.ball("%s_blister%d" % (cid, i), 0.06, V((math.cos(a) * 0.25, front - 0.15 + math.sin(a) * 0.08, ck.Z["waist"] + 0.05 * math.sin(a * 2))), pus))
            for i in range(3):
                head.append(ck.ball("%s_drip%d" % (cid, i), r * 0.08, c + V(((i - 1) * r * 0.25, -r * 0.92, -r * 0.75)), pus, (0.7, 0.7, 1.4)))
        elif kind == "cultist":
            hd = ck.mat("m_%s_hood" % cid, (0.42, 0.08, 0.1), 0.85)
            head.append(ck.ball(cid + "_hood", r * 1.16, c + V((0, r * 0.12, r * 0.15)), hd, (1, 1.05, 1.0)))
            head.append(ck.tube(cid + "_hoodtip", c + V((0, r * 0.4, r * 1.0)), c + V((0, r * 0.9, r * 2.0)), r * 0.5, r * 0.03, hd, 8))
            head.append(ck.ball(cid + "_mask", r * 0.62, c + V((0, -r * 0.62, -r * 0.05)), bone, (1.1, 0.4, 1.0)))
            for sx in (-1, 1):
                head.append(ck.ball("%s_eyehole%d" % (cid, sx), r * 0.1, c + V((sx * r * 0.25, -r * 0.88, r * 0.05)), gl))
        elif kind == "frost":
            ice = ck.mat("m_%s_ice" % cid, (0.7, 0.9, 1.0), 0.15, 0.6)
            for i in range(8):
                a = math.tau * i / 8
                root = c + V((math.cos(a) * r * 0.85, math.sin(a) * r * 0.85, r * 0.7))
                head.append(ck.blade("%s_shard%d" % (cid, i), root, root + V((math.cos(a) * r * 0.3, math.sin(a) * r * 0.3, r * (0.9 + 0.4 * (i % 2)))), r * 0.22, r * 0.06, ice, (-math.sin(a), math.cos(a), 0), 0.4))
            for sx in (-1, 1):
                body.append(ck.ball("%s_iceshoulder%d" % (cid, sx), 0.16, V((sx * (b["chest"] + 0.04), 0.0, zc + 0.13)), ice, (1.1, 1.0, 0.7)))
                body.append(ck.blade("%s_icicle%d" % (cid, sx), V((sx * (b["chest"] + 0.06), 0, zc + 0.2)), V((sx * (b["chest"] + 0.16), 0.02, zc + 0.48)), 0.08, 0.03, ice, (0, 1, 0), 0.4))
        else:                                   # lichking
            crown = ck.mat("m_%s_crown" % cid, (0.55, 0.45, 0.75), 0.3, 0.4)
            for i in range(9):
                a = math.tau * i / 9
                root = c + V((math.cos(a) * r * 0.88, math.sin(a) * r * 0.88, r * 0.7))
                head.append(ck.tube("%s_tine%d" % (cid, i), root, root + V((math.cos(a) * r * 0.15, math.sin(a) * r * 0.15, r * (1.1 + 0.5 * (i % 3 == 0)))), r * 0.1, r * 0.01, crown, 5))
            head.append(ck.tube(cid + "_circlet", c + V((0, 0, r * 0.6)), c + V((0, 0, r * 0.82)), r * 0.98, r * 0.95, crown, 18))
            head.append(ck.ball(cid + "_gem", r * 0.16, c + V((0, -r * 0.95, r * 0.72)), gl))
            body.append(ck.blade(cid + "_cape", V((0, back + 0.03, zc + 0.16)), V((0, back + 0.24, ck.Z["ankle"])), 0.62, 0.03, ck.mat("m_%s_cape" % cid, (0.16, 0.08, 0.24), 0.7), (1, 0, 0), 0.4))
            for i in range(5):
                a = math.pi * (0.15 + 0.7 * i / 4)
                body.append(ck.tube("%s_collar%d" % (cid, i), V((math.cos(a) * 0.2, back * 0.4 + math.sin(a) * 0.08, zc + 0.2)), V((math.cos(a) * 0.32, back * 0.4 + math.sin(a) * 0.2, zc + 0.5)), 0.05, 0.01, crown, 5))
        for p_ in head:
            ck.skin_rigid(p_, rig, "head")
        for p_ in body:
            ck.skin_rigid(p_, rig, "chest")
    return add


def larva(cid="mob_larva"):
    """Larva do Carniçal: verme claro e segmentado, mandíbulas e manchas de veneno (rig e clipes do slime)."""
    arm = lp.make_armature("rig_" + cid, bm.MOB_BONES)
    m = ck.mat("m_%s_skin" % cid, (0.86, 0.84, 0.66), 0.45)
    spot = ck.mat("m_%s_spot" % cid, (0.55, 0.8, 0.25), 0.4, 0.4)
    m_eye, m_white = base_mats()
    parts = []
    for i in range(5):
        y = -0.32 + i * 0.17
        rr = 0.17 - abs(i - 1.2) * 0.022
        parts.append((blob("seg%d" % i, rr, (0, y, rr), m, (1.0, 0.9, 0.85)), "body"))
        if i % 2 == 1:
            parts.append((blob("spot%d" % i, rr * 0.4, (0.05, y, rr * 1.75), spot, (1, 1, 0.5)), "body"))
    for sx in (-1, 1):
        parts.append((ck.tube("mandible%d" % sx, (sx * 0.06, -0.44, 0.12), (sx * 0.02, -0.56, 0.08), 0.03, 0.008, m_eye, 5), "body"))
    parts += [(o, "body") for o in eyes("l", [(-0.07, -0.45, 0.22), (0.07, -0.45, 0.22)], 0.04, m_eye, m_white)]
    finish(arm, parts)
    z = (0, 0, 0)
    lp.add_action(arm, "idle", {"body": [(1, (0, 0, 0), z), (12, (0, 0, 6), (0, 0, 0.02)), (24, (0, 0, 0), z)]}, 24)
    lp.add_action(arm, "run", {"body": [(1, (0, 0, -10), z), (4, (0, 0, 10), (0, -0.04, 0.03)), (8, (0, 0, -10), z)]}, 8)
    lp.add_action(arm, "attack", {"body": [(1, (-10, 0, 0), z), (5, (20, 0, 0), (0, -0.2, 0.08)), (12, (0, 0, 0), z)]}, 12, loop=False)
    lp.add_action(arm, "hit", {"body": [(1, (-15, 0, 0), (0, 0.06, 0)), (6, (0, 0, 0), z)]}, 6, loop=False)
    lp.add_action(arm, "die", {"root": [(1, (0, 0, 0), z), (14, (0, 0, 0), (0, 0, -0.2))]}, 14, loop=False)
    return arm


def bat(cid="mob_bat"):
    """Morcego da Torre: corpo pequeno e peludo, asas grandes de membrana nos braços, orelhas e olhos vermelhos (rig do fantasma)."""
    arm = lp.make_armature("rig_" + cid, bm.MOB_BONES)
    fur = ck.mat("m_%s_fur" % cid, (0.24, 0.18, 0.28), 0.8)
    wing = ck.mat("m_%s_wing" % cid, (0.36, 0.22, 0.38), 0.7)
    eye = ck.mat("m_%s_eye" % cid, (1.0, 0.25, 0.2), 0.3, 2.0)
    parts = [(blob("body", 0.2, (0, 0, 1.1), fur, (1, 0.9, 1.1)), "body"),
             (blob("head", 0.14, (0, -0.12, 1.32), fur), "head")]
    for sx in (-1, 1):
        parts.append((ck.tube("ear%d" % sx, (sx * 0.07, -0.1, 1.42), (sx * 0.12, -0.06, 1.6), 0.05, 0.005, fur, 5), "head"))
        parts.append((blob("eye%d" % sx, 0.03, (sx * 0.06, -0.25, 1.34), eye), "head"))
        w = ck.blade("wing%d" % sx, Vector((sx * 0.15, 0.02, 1.15)), Vector((sx * 0.75, 0.1, 1.3)), 0.42, 0.02, wing, (0, 0, 1), 0.3)
        parts.append((w, "arm_r" if sx > 0 else "arm_l"))
        parts.append((ck.tube("wingbone%d" % sx, (sx * 0.15, 0.0, 1.22), (sx * 0.75, 0.08, 1.34), 0.02, 0.01, fur, 4), "arm_r" if sx > 0 else "arm_l"))
    finish(arm, parts)
    bm.mob_actions(arm, floating=True)
    return arm


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
    sh, hip, neck = {"ancient": ((0.78, 1.25), (0.3, 0.5), (-0.2, 1.2)), "crystal": ((0.5, 1.38), (0.18, 0.5), (-0.05, 1.5)),
                     "heart": ((0.9, 1.3), (0.34, 0.52), (-0.2, 1.45))}[kind]
    arm = lp.make_armature("rig_" + cid, pivots(arm_r=(sh[0], 0, sh[1]), arm_l=(-sh[0], 0, sh[1]), leg_fr=(hip[0], 0, hip[1]),
                                                leg_fl=(-hip[0], 0, hip[1]), head=(0, neck[0], neck[1])))
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


# chefes humanoides: modelos que guardam os gestos de skill do kit (chibi_kit.MOB_BOSS_KEEP); mob_skeleton = Senhor da Cripta e
# Capitão dos Ossos, mob_lich = Conde Vargo
BOSS_HUMANOIDS = {"mob_bandit_chief", "mob_elf_king", "mob_elf_warden", "mob_elf_captain_hunter", "mob_elf_captain_sky", "mob_elf_captain_sap",
                  "mob_ghoul_giant", "mob_death_knight", "mob_frost_mage", "mob_lich_king", "mob_skeleton", "mob_lich"}


def humanoid(cid, style, cloth, weapon, skin=None, eye=None, offhand=None, hide_hair=False, head=None, crown=0, extra=None, after=None, sex="male", hair=(0.25, 0.18, 0.14), attack=None):
    ck.clear()
    base = ck.build_base(cid, sex, 0.0, hair)
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
    if weapon:
        ck.kit_weapon(base, weapon, "main", mats)
    if offhand:
        ck.kit_weapon(base, offhand, "off", mats)
    if after:
        after(base, mats)
    if cid.startswith("form_"):
        ck.animate(base["rig"], "all")    # forma do jogador (demônio): o mesmo jogo de clipes do kit, não só os do monstro
        ck.animate_combat(base["rig"])
        ck.animate_v3(base["rig"])
    else:
        ck.mob_clips(base["rig"], weapon, offhand, attack, boss=cid in BOSS_HUMANOIDS)
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
SK_BONE = (0.92, 0.9, 0.82)
# bichos que são (ou vestem) chefes: gestos maul/pounce/slam/roar/brace (boss_gestures), para as skills especiais não
# repetirem o "attack"
BOSS_GESTURES = {"mob_boar": "quad", "mob_crab": "crab", "mob_slime": "slime", "mob_spider": "spider", "mob_ghost": "ghost", "mob_trent": "biped4",
                 "mob_golem_ancient": "biped", "mob_crystal_warden": "biped", "mob_quarry_heart": "biped"}


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
        # Linha dos fora-da-lei (Floresta): cada tipo com cabeça própria (outlaw_parts) e a arma do papel
        "mob_bandit_footpad": lambda: humanoid("mob_bandit_footpad", "leather", (0.55, 0.5, 0.3), "mace", head="none", hide_hair=True, extra=outlaw_parts("mob_bandit_footpad", "footpad", (0.75, 0.3, 0.2))),
        "mob_bandit_thief": lambda: humanoid("mob_bandit_thief", "leather", (0.26, 0.25, 0.3), "dagger", offhand="dagger", head="none",
                                             hide_hair=True, extra=outlaw_parts("mob_bandit_thief", "thief", (0.15, 0.14, 0.17))),
        "mob_bandit_poacher": lambda: humanoid("mob_bandit_poacher", "leather", (0.38, 0.4, 0.24), "bow", head="none", hide_hair=True, extra=outlaw_parts("mob_bandit_poacher", "poacher", (0.85, 0.7, 0.4))),
        "mob_bandit": lambda: humanoid("mob_bandit", "leather", (0.55, 0.22, 0.2), "mace2h", head="none", hide_hair=True,
                                       extra=outlaw_parts("mob_bandit", "brute", (0.5, 0.2, 0.18))),
        "mob_bandit_outlaw": lambda: humanoid("mob_bandit_outlaw", "leather", (0.34, 0.28, 0.22), "mace", head="none", hide_hair=True,
                                              extra=outlaw_parts("mob_bandit_outlaw", "outlaw", (0.55, 0.45, 0.32))),
        "mob_bandit_thug": lambda: humanoid("mob_bandit_thug", "leather", (0.5, 0.32, 0.22), "mace", head="none", hide_hair=True,
                                            extra=outlaw_parts("mob_bandit_thug", "thug", (0.7, 0.18, 0.15))),
        "mob_bandit_chief": lambda: humanoid("mob_bandit_chief", "leather", (0.55, 0.12, 0.12), "mace2h", head="none", hide_hair=True,
                                             extra=outlaw_parts("mob_bandit_chief", "chief", (0.5, 0.1, 0.12))),
        # Cerco élfico: elfos de couro/tecido verde, Guardião de placa clara, Rei de placa dourada com coroa e manto
        # Herói élfico (guerreiro da cidade): couro reforçado verde-escuro, tiara dourada, cabelo castanho longo
        "mob_elf_warrior": lambda: humanoid("mob_elf_warrior", "leather", (0.24, 0.42, 0.3), "sword", skin=(0.96, 0.86, 0.74),
                                            head="none", hair=(0.45, 0.3, 0.18), extra=elf_parts("mob_elf_warrior", (0.9, 0.75, 0.3), hair=(0.45, 0.3, 0.18), cape=True),
                                            after=warrior_bows),
        # Lutador élfico (batedor das investidas): túnica verde clara, cabelo ruivo longo, espada; arco nas costas para a troca
        "mob_elf_fighter": lambda: humanoid("mob_elf_fighter", "leather", (0.42, 0.62, 0.38), "sword", skin=(0.96, 0.86, 0.74),
                                            head="none", hair=(0.72, 0.38, 0.18), extra=elf_parts("mob_elf_fighter", (0.6, 0.45, 0.28), hair=(0.72, 0.38, 0.18)),
                                            after=warrior_bows),
        # Arqueiro élfico (batedor arqueiro): loiro de cabelo longo, túnica verde, arco longo
        "mob_elf_bowman": lambda: humanoid("mob_elf_bowman", "cloth", (0.38, 0.62, 0.36), "bow", skin=(0.96, 0.86, 0.74),
                                           head="none", hair=(0.95, 0.85, 0.5), extra=elf_parts("mob_elf_bowman", (0.55, 0.4, 0.25), hair=(0.95, 0.85, 0.5)),
                                           after=longbow),
        # capitães dos fortes élficos e cidadãos (Cidade Élfica)
        "mob_elf_captain_hunter": lambda: humanoid("mob_elf_captain_hunter", "leather", (0.3, 0.5, 0.36), "bow", skin=(0.96, 0.86, 0.74),
                                                   head="none", extra=elf_captain_parts("mob_elf_captain_hunter", (0.85, 0.55, 0.25), "hunter")),
        "mob_elf_captain_sky": lambda: humanoid("mob_elf_captain_sky", "plate", (0.86, 0.88, 0.94), "sword2h", skin=(0.96, 0.86, 0.74),
                                                head="none", hide_hair=True, extra=elf_captain_parts("mob_elf_captain_sky", (0.3, 0.5, 0.8), "sky")),
        "mob_elf_captain_sap": lambda: humanoid("mob_elf_captain_sap", "cloth", (0.45, 0.6, 0.35), "staff", skin=(0.96, 0.86, 0.74),
                                                head="none", hair=(0.62, 0.85, 0.5), extra=elf_captain_parts("mob_elf_captain_sap", (0.6, 0.85, 0.4), "sap")),
        "mob_elf_citizen": lambda: humanoid("mob_elf_citizen", "cloth", (0.6, 0.78, 0.62), None, skin=(0.96, 0.86, 0.74),
                                            head="none", extra=elf_parts("mob_elf_citizen", (0.85, 0.75, 0.45), hair=(0.72, 0.5, 0.28)), hair=(0.72, 0.5, 0.28)),
        "mob_elf_citizen_f": lambda: humanoid("mob_elf_citizen_f", "cloth", (0.75, 0.62, 0.82), None, skin=(0.96, 0.86, 0.74),
                                              head="none", extra=elf_parts("mob_elf_citizen_f", (0.55, 0.8, 0.7), hair=(0.95, 0.88, 0.62)), sex="female", hair=(0.95, 0.88, 0.62)),
        # Xamã élfica: túnica clara, cabelo prateado longo, cajado
        "mob_elf_mage": lambda: humanoid("mob_elf_mage", "cloth", (0.86, 0.88, 0.8), "staff", skin=(0.96, 0.86, 0.74), sex="female",
                                         head="none", hair=(0.88, 0.9, 0.95), extra=elf_parts("mob_elf_mage", (0.3, 0.75, 0.55), cape=True, hair=(0.88, 0.9, 0.95))),
        # Atirador élfico (arqueiro da cidade): capuz e capa verde-musgo, cabelo loiro saindo por baixo, arco longo
        "mob_elf_archer": lambda: humanoid("mob_elf_archer", "cloth", (0.3, 0.48, 0.3), "bow", skin=(0.96, 0.86, 0.74),
                                           head="none", hide_hair=True, hair=(0.9, 0.78, 0.45), extra=elf_parts("mob_elf_archer", (0.6, 0.45, 0.28), cape=True, hair=(0.9, 0.78, 0.45), hood=(0.24, 0.38, 0.24)),
                                           after=longbow),
        "mob_elf_warden": lambda: humanoid("mob_elf_warden", "plate", (0.88, 0.86, 0.74), "sword2h", skin=(0.96, 0.86, 0.74),
                                           head="none", hair=(0.8, 0.82, 0.86), extra=elf_parts("mob_elf_warden", (0.3, 0.6, 0.5), hair=(0.8, 0.82, 0.86))),
        "mob_elf_king": lambda: humanoid("mob_elf_king", "plate", (0.95, 0.8, 0.35), "sword", skin=(0.96, 0.86, 0.74),
                                         head="none", crown=7, hair=(0.96, 0.88, 0.55), extra=elf_parts("mob_elf_king", (0.22, 0.5, 0.42), cape=True, hair=(0.96, 0.88, 0.55))),
        "mob_trent": trent,
        "mob_griffin": lambda: quadruped("mob_griffin", (0.8, 0.62, 0.36), (0.55, 0.4, 0.22), (0.96, 0.94, 0.88), "griffin"),
        "mob_elf_lynx": lambda: quadruped("mob_elf_lynx", (0.74, 0.56, 0.32), (0.2, 0.36, 0.24), (0.95, 0.9, 0.78), "lynx"),
        # Terceiro andar: guarnição da Luz (Bastião da Aurora) e mortos-vivos das fortalezas
        "mob_loyal_spearman": lambda: humanoid("mob_loyal_spearman", "leather", (0.32, 0.42, 0.72), "staff", head="none", hide_hair=True, attack="atk_thrust",
                                               after=loyalist_parts("mob_loyal_spearman", "spearman", (0.8, 0.18, 0.15))),
        "mob_loyal_knight": lambda: humanoid("mob_loyal_knight", "plate", (0.78, 0.8, 0.86), "sword2h", head="none", hide_hair=True,
                                             after=loyalist_parts("mob_loyal_knight", "knight", (0.25, 0.4, 0.8))),
        "mob_loyal_paladin": lambda: humanoid("mob_loyal_paladin", "plate", (0.95, 0.93, 0.85), "mace", offhand="shield", head="none", hide_hair=True,
                                              after=loyalist_parts("mob_loyal_paladin", "paladin", (0.95, 0.8, 0.35))),
        "mob_loyal_priest": lambda: humanoid("mob_loyal_priest", "cloth", (0.96, 0.95, 0.9), "staff", head="none", hide_hair=True, sex="female",
                                             after=loyalist_parts("mob_loyal_priest", "priest", (0.95, 0.8, 0.35))),
        "mob_loyal_crossbow": lambda: humanoid("mob_loyal_crossbow", "leather", (0.55, 0.45, 0.32), "bow", head="none", hide_hair=True,
                                               after=loyalist_parts("mob_loyal_crossbow", "crossbow", (0.25, 0.4, 0.8))),
        "mob_skel_blade": lambda: humanoid("mob_skel_blade", "plate", (0.36, 0.32, 0.3), "sword2h", skin=SK_BONE, eye=(0.4, 0.8, 1.0), hide_hair=True,
                                           head="none", extra=undead_parts("mob_skel_blade", "blade", (0.4, 0.8, 1.0))),
        "mob_skel_archer": lambda: humanoid("mob_skel_archer", "cloth", (0.4, 0.37, 0.32), "bow", skin=SK_BONE, eye=(0.4, 0.8, 1.0), hide_hair=True,
                                            head="none", extra=undead_parts("mob_skel_archer", "archer", (0.4, 0.8, 1.0))),
        "mob_skel_guard": lambda: humanoid("mob_skel_guard", "plate", (0.3, 0.28, 0.3), "sword", offhand="shield", skin=SK_BONE, eye=(0.4, 0.8, 1.0),
                                           hide_hair=True, head="none", extra=undead_parts("mob_skel_guard", "guard", (0.4, 0.8, 1.0))),
        "mob_death_knight": lambda: humanoid("mob_death_knight", "plate", (0.18, 0.16, 0.2), "sword2h", skin=SK_BONE, eye=(1.0, 0.3, 0.25), hide_hair=True,
                                             head="none", extra=undead_parts("mob_death_knight", "knight", (1.0, 0.3, 0.25))),
        "mob_ghoul": lambda: humanoid("mob_ghoul", "leather", (0.35, 0.32, 0.26), None, skin=(0.55, 0.62, 0.45), eye=(0.9, 0.95, 0.3), hide_hair=True,
                                      head="none", extra=undead_parts("mob_ghoul", "ghoul", (0.6, 0.9, 0.3))),
        "mob_ghoul_giant": lambda: humanoid("mob_ghoul_giant", "leather", (0.3, 0.26, 0.18), "axe2h", skin=(0.34, 0.42, 0.18), eye=(0.95, 0.9, 0.3), hide_hair=True,
                                            head="none", extra=undead_parts("mob_ghoul_giant", "giant", (0.6, 0.9, 0.3))),
        "mob_cultist": lambda: humanoid("mob_cultist", "cloth", (0.28, 0.1, 0.12), "wand", skin=(0.8, 0.76, 0.74), hide_hair=True,
                                        head="none", extra=undead_parts("mob_cultist", "cultist", (1.0, 0.35, 0.25))),
        "mob_frost_mage": lambda: humanoid("mob_frost_mage", "cloth", (0.45, 0.6, 0.8), "staff", skin=SK_BONE, eye=(0.5, 0.9, 1.0), hide_hair=True,
                                           head="none", extra=undead_parts("mob_frost_mage", "frost", (0.5, 0.9, 1.0))),
        "mob_lich_king": lambda: humanoid("mob_lich_king", "cloth", (0.2, 0.12, 0.28), "staff", skin=SK_BONE, eye=(0.75, 0.5, 1.0), hide_hair=True,
                                          head="none", extra=undead_parts("mob_lich_king", "lichking", (0.75, 0.5, 1.0))),
        "mob_rot_bear": lambda: quadruped("mob_rot_bear", (0.36, 0.38, 0.28), (0.42, 0.14, 0.14), (0.9, 0.86, 0.72), "bear"),
        "mob_rot_wolf": lambda: quadruped("mob_rot_wolf", (0.38, 0.4, 0.32), (0.42, 0.14, 0.14), (0.9, 0.86, 0.72), "wolf"),
        "mob_larva": larva,
        "mob_bat": bat,
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
        if name in BOSS_GESTURES:
            boss_gestures.add(arm, BOSS_GESTURES[name])
        for o in bpy.context.scene.objects:
            if "." in o.name:
                o.name = o.name.replace(".", "_")
        if name.startswith(("mob_bandit", "mob_loyal_", "mob_skel_")) or name in ("mob_death_knight", "mob_ghoul", "mob_ghoul_giant", "mob_cultist",
                                                                              "mob_frost_mage", "mob_lich_king", "mob_skeleton", "mob_zombie", "mob_lich", "mob_skeleton_king", "form_demon",
                    "mob_elf_warrior", "mob_elf_archer", "mob_elf_warden", "mob_elf_king", "mob_elf_mage",
                    "mob_elf_captain_hunter", "mob_elf_captain_sky", "mob_elf_captain_sap", "mob_elf_citizen", "mob_elf_citizen_f",
                    "mob_elf_fighter", "mob_elf_bowman"):
            ck.export_glb(arm, os.path.join(out_dir, name + ".glb"))
        else:
            lp.export_glb(os.path.join(out_dir, name + ".glb"), [arm])
    print("mobs done")
