"""Conjuntos lendários do Necromancer (18 = 3 focos × 6 níveis) e foices, por construtor paramétrico (desenho original).

Invocador: capuz com máscara de caveira ou coroa de ossos, túnica, ombreiras de caveira, costelas no peito, caveiras flutuando.
Ceifador: capuz fundo de barra rasgada, manto longo esfarrapado, ombreiras com cravos, correntes no cinto.
Sombras (maldições e canalização): capuz alto ou diadema com olho, túnica com runas, gola de aletas, orbes do vazio.
Peças: arm_<estilo>_<head|body|gloves|boots>_*; arma: wpn_main_scythe_<estilo>.
"""
import math
from mathutils import Vector

BONE = (0.92, 0.89, 0.8)
LEVELS = [5, 10, 15, 20, 25, 30]
FOCUS = {"i": "invocador", "c": "ceifador", "s": "sombras"}
HEADS = {"i": ["skull_hood", "bone_crown", "skull_hood", "bone_crown", "skull_hood", "bone_crown"],
         "c": ["reaper_hood", "reaper_hood", "horned_hood", "reaper_hood", "horned_hood", "horned_hood"],
         "s": ["void_cowl", "eye_circlet", "void_cowl", "eye_circlet", "void_cowl", "void_cowl"]}
GLOW = {"i": (0.45, 1.0, 0.75), "c": (1.0, 0.3, 0.25), "s": (0.75, 0.4, 1.0)}
# lâmina: crescent | double | jagged | bone ; glow = fio que brilha
BLADES = {"i": ["bone", "crescent", "bone", "double", "bone", "double"],
          "c": ["crescent", "jagged", "crescent", "jagged", "double", "jagged"],
          "s": ["crescent", "crescent", "double", "crescent", "jagged", "double"]}


def _sets():
    out = {}
    for f in "ics":
        for i, lv in enumerate(LEVELS):
            out["nec_%s%d" % (f, lv)] = {"focus": f, "tier": i, "head": HEADS[f][i], "blade": BLADES[f][i],
                                         "robe": (0.08 - i * 0.005, 1.6 + i * 0.07), "cape": 0.0 if f != "c" else 0.35 + i * 0.05,
                                         "orbs": [0, 1, 1, 2, 2, 3][i] if f != "c" else 0, "spikes": i >= 2, "glow": i >= 1}
    return out


NEC_SETS = _sets()


def build(ck, base, mats, style, cfg):
    import bpy
    V = Vector
    rig, body, b, j = base["rig"], base["body"], base["b"], base["j"]
    t, t2, gold, dark, leather, metal = mats["tint"], mats["tint2"], mats["trim"], mats["dark"], mats["leather"], mats["metal"]
    f, tier = cfg["focus"], cfg["tier"]
    bone = ck.mat("m_nec_bone", BONE, 0.7)
    glow = ck.mat("m_nec_glow_%s" % f, GLOW[f], 0.3, 1.2)
    P = "arm_%s_" % style
    c = V(base["head_c"])
    r = b["head"]
    # ---------------- cabeça ----------------
    hk = cfg["head"]
    head = []
    if hk in ("bone_crown", "eye_circlet"):              # peça aberta: cabelo comprido da cor da classe
        hair = bpy.data.materials.get("hair") or t
        head.append(ck._shell(P + "head_hair", c + V((0, r * 0.04, r * 0.02)), r * 1.06, 0.25, -0.85, -0.25, 0.04, hair))
        for sx in (-1, 1):
            head.append(ck.strand(P + "head_lock%d" % sx, c + V((sx * r * 0.5, r * 0.6, -r * 0.1)), r * 1.0, r * 0.3, r * 0.22, hair, taper=0.9, lean=(sx * 0.15, 0.4)))
    if hk in ("skull_hood", "reaper_hood", "horned_hood", "void_cowl"):
        deep = {"skull_hood": 0.3, "reaper_hood": 0.15, "horned_hood": 0.2, "void_cowl": 0.35}[hk]
        head.append(ck._shell(P + "head_hood", c, r * 1.17, deep, -1.0, -0.6, 0.035, t))
        if hk in ("reaper_hood", "horned_hood"):          # barra rasgada do capuz caindo nos ombros
            for k in range(7):
                a = math.pi * (0.1 + 0.8 * k / 6)
                d = V((math.cos(a), math.sin(a), 0))
                head.append(ck.blade(P + "head_rag%d" % k, c + d * r * 1.05 + V((0, 0, -r * 0.3)), c + d * r * 1.2 + V((0, 0, -r * (0.85 + 0.15 * (k % 2)))),
                                     r * 0.35, 0.015, t if k % 2 else dark, V((-d.y, d.x, 0)), 0.2))
        if hk == "void_cowl":                             # ponta alta do capuz
            head.append(ck.tube(P + "head_peak", c + V((0, r * 0.2, r * 0.8)), c + V((0, r * 0.55, r * 1.55)), r * 0.45, r * 0.04, t, 12))
    if hk == "skull_hood":                                # meia máscara de caveira (testa e nariz)
        head.append(ck.blade(P + "head_skullmask", c + V((-r * 0.55, -r * 1.03, r * 0.25)), c + V((r * 0.55, -r * 1.03, r * 0.25)), r * 0.42, 0.03, bone, (0, 0, 1), 0.6))
        for sx in (-1, 1):
            head.append(ck.ball(P + "head_socket%d" % sx, r * 0.1, c + V((sx * r * 0.28, -r * 1.06, r * 0.27)), glow if cfg["glow"] else dark, (1, 0.4, 0.8)))
    if hk == "bone_crown":                                # coroa de ossos e costelas
        head.append(ck.tube(P + "head_band", c + V((0, 0, r * 0.36)), c + V((0, 0, r * 0.48)), r * 1.11, r * 1.1, bone, 24))
        for k in range(9):
            a = math.tau * k / 9 + math.pi * 1.5
            d = V((math.cos(a), math.sin(a), 0))
            tall = r * (0.55 if k % 2 == 0 else 0.35)
            head.append(ck.tube(P + "head_bone%d" % k, c + d * r * 1.1 + V((0, 0, r * 0.42)), c + d * r * 1.25 + V((0, 0, r * 0.42 + tall)), r * 0.09, r * 0.05, bone, 6))
            head.append(ck.ball(P + "head_knob%d" % k, r * 0.09, c + d * r * 1.25 + V((0, 0, r * 0.42 + tall)), bone))
        head.append(ck.ball(P + "head_gem", 0.035, c + V((0, -r * 1.12, r * 0.44)), glow, (1, 0.6, 1.3)))
    if hk == "horned_hood":                               # chifres saindo do capuz
        for sx in (-1, 1):
            p0 = c + V((sx * r * 0.6, 0, r * 0.65))
            p1 = p0 + V((sx * r * 0.35, r * 0.15, r * 0.35))
            head += [ck.tube(P + "head_horn%d_a" % sx, p0, p1, r * 0.15, r * 0.1, dark, 8), ck.tube(P + "head_horn%d_b" % sx, p1, p1 + V((sx * r * 0.05, r * 0.3, r * 0.3)), r * 0.1, r * 0.01, dark, 8)]
    if hk in ("reaper_hood", "horned_hood"):              # sombra no rosto: só os olhos brilham
        for sx in (-1, 1):
            head.append(ck.ball(P + "head_eye%d" % sx, r * 0.09, c + V((sx * r * 0.26, -r * 1.02, -r * 0.05)), glow, (1, 0.4, 0.7)))
    if hk == "eye_circlet":                               # diadema com olho aberto na testa
        head += [ck.tube(P + "head_circlet", c + V((0, 0, r * 0.36)), c + V((0, 0, r * 0.46)), r * 1.11, r * 1.1, gold, 24),
                 ck.ball(P + "head_eye_white", r * 0.16, c + V((0, -r * 1.12, r * 0.45)), mats["white"], (1.3, 0.5, 0.8)),
                 ck.ball(P + "head_eye_iris", r * 0.08, c + V((0, -r * 1.2, r * 0.45)), glow)]
    ck._rigid(head, rig, "head")
    # ---------------- corpo ----------------
    ck.armor_piece(body, rig, P + "body_robe", "torso", t, 0.014, 0.014, 0.03)
    ck.armor_piece(body, rig, P + "body_legs", "legs", dark, 0.008, 0.012)
    bottom, flare = cfg["robe"]
    if f != "c":
        ck.skirt(P + "body_skirt", b, body, rig, t, bottom, flare)
    else:                                                  # Ceifador: saiote curto de couro (o manto faz a silhueta)
        ck.skirt(P + "body_skirt", b, body, rig, leather, ck.Z["knee"] + 0.05, 1.3)
    d = b["depth"]
    front = -b["chest"] * d - 0.03
    back = b["chest"] * d + 0.03
    zc, zn = ck.Z["chest"], ck.Z["neck"]
    chest = []
    if f == "i":                                           # costelas de osso sobre o peito
        for k in range(4):
            z = zc + 0.08 - k * 0.055
            for sx in (-1, 1):
                chest.append(ck.tube(P + "body_rib%d_%d" % (sx, k), (0, front - 0.005, z), (sx * 0.13, front + 0.03, z - 0.04), 0.012, 0.009, bone, 5))
        chest.append(ck.tube(P + "body_sternum", (0, front - 0.006, zc + 0.12), (0, front - 0.006, zc - 0.12), 0.016, 0.014, bone, 6))
    elif f == "c":                                         # correntes cruzadas no peito
        for sx in (-1, 1):
            for k in range(6):
                p = V((sx * 0.14, front + 0.01, zc + 0.12)).lerp(V((-sx * 0.12, front + 0.01, ck.Z["waist"] + 0.05)), k / 5)
                chest.append(ck.ball(P + "body_chain%d_%d" % (sx, k), 0.018, p, metal, (1, 0.5, 1)))
    else:                                                  # runas do vazio no peitoral
        chest.append(ck.box(P + "body_panel", (0.1, 0.015, 0.24), (0, front, zc - 0.04), t2, 0.004))
        for k in range(3):
            chest.append(ck.ball(P + "body_rune%d" % k, 0.018, (0, front - 0.012, zc + 0.06 - k * 0.07), glow, (1, 0.4, 1)))
    if cfg["spikes"] or f == "s":                          # gola: cravos (Invocador/Ceifador) ou aletas (Sombras)
        for k in range(7):
            a = math.pi * (0.1 + 0.8 * k / 6)
            p = V((math.cos(a) * b["chest"] * 0.55, math.sin(a) * b["chest"] * 0.5, zn - 0.02))
            if f == "s":
                chest.append(ck.blade(P + "body_fin%d" % k, p, p + V((math.cos(a) * 0.05, math.sin(a) * 0.05, 0.13)), 0.07, 0.012, t2, (-math.sin(a), math.cos(a), 0), 0.5))
            else:
                chest.append(ck.tube(P + "body_spike%d" % k, p, p + V((math.cos(a) * 0.04, math.sin(a) * 0.05, 0.09)), 0.018, 0.002, bone if f == "i" else metal, 6))
    if cfg["cape"] > 0.0:                                  # manto longo esfarrapado do Ceifador
        L = cfg["cape"]
        for k in range(7):
            x = (k - 3) * 0.06
            chest.append(ck.blade(P + "body_cloak%d" % k, (x * 0.85, back + 0.02, zn - 0.04), (x * 1.4, back + 0.12, zn - 0.05 - L - 0.08 * ((k * 5) % 3)),
                                  0.095, 0.014, t if k % 2 == 0 else dark, (1, 0, 0), 0.15))
    for i in range(cfg["orbs"]):                           # caveiras (Invocador) ou orbes do vazio (Sombras) flutuando
        a = math.pi * (0.25 + 0.5 * i / max(1, cfg["orbs"] - 1)) if cfg["orbs"] > 1 else math.pi * 0.5
        p = V((math.cos(a) * 0.36, 0.1 + math.sin(a) * 0.06, zn + 0.14 + 0.05 * (i % 2)))
        if f == "i":
            chest += [ck.ball(P + "body_skull%d" % i, 0.05, p, bone, (0.9, 0.85, 1.0)),
                      ck.ball(P + "body_skulleye%d" % i, 0.016, p + V((0, -0.045, 0.005)), glow, (2.2, 0.6, 1.0))]
        else:
            chest.append(ck.ball(P + "body_orb%d" % i, 0.045, p, glow))
    ck._rigid(chest, rig, "chest")
    belt = ck.tube(P + "body_belt", (0, 0, ck.Z["waist"] - 0.035), (0, 0, ck.Z["waist"] + 0.03), b["waist"] * 1.2, b["waist"] * 1.2, leather if f == "c" else t2, 16)
    for v in belt.data.vertices:
        v.co.y *= d * 1.05
    ck._smooth(belt.data)
    ck.transfer_weights(belt, body, rig)
    hips = []
    wf = -b["waist"] * d * 1.22
    if f == "c":                                           # corrente pendurada e foice-amuleto no cinto
        for k in range(5):
            hips.append(ck.ball(P + "body_hchain%d" % k, 0.016, (0.1 + k * 0.012, wf * 0.8, ck.Z["waist"] - 0.04 - k * 0.04), metal, (1, 0.5, 1)))
    else:                                                  # faixa caindo na frente com selo
        hips += [ck.blade(P + "body_sash", (0, wf, ck.Z["waist"] - 0.02), (0, wf - 0.01, ck.Z["waist"] - 0.32), 0.09, 0.012, t2, (1, 0, 0), 0.5),
                 ck.ball(P + "body_seal", 0.03, (0, wf - 0.02, ck.Z["waist"] - 0.08), glow if cfg["glow"] else gold, (1, 0.5, 1))]
    ck._rigid(hips, rig, "hips")
    for s, sx in ((".R", -1), (".L", 1)):
        sh = V(j["shoulder" + s])
        tag = s.replace(".", "_")
        if f == "i":                                       # caveira no ombro
            pa = [ck.ball(P + "body_sskull" + tag, b["arm"] * 1.8, sh + V((sx * 0.06, 0, 0.06)), bone, (1, 1, 0.9)),
                  ck.ball(P + "body_sskulleye" + tag, b["arm"] * 0.45, sh + V((sx * 0.06, -b["arm"] * 1.6, 0.07)), glow if cfg["glow"] else dark, (2.0, 0.6, 1.0))]
        elif f == "c":                                     # ombreira de metal escuro com cravos
            pa = [ck.ball(P + "body_pauldron" + tag, b["arm"] * 2.2, sh + V((sx * 0.06, 0, 0.05)), dark, (1.15, 1.05, 0.55))]
            for k in range(2 + (tier >= 3)):
                pa.append(ck.tube(P + "body_pspike%s_%d" % (tag, k), sh + V((sx * 0.08, (k - 0.5) * 0.06, 0.08)), sh + V((sx * 0.14, (k - 0.5) * 0.08, 0.2)), 0.025, 0.002, metal, 6))
        else:                                              # aletas do vazio
            pa = [ck.ball(P + "body_pad" + tag, b["arm"] * 1.9, sh + V((sx * 0.05, 0, 0.04)), t2, (1.1, 1.05, 0.5))]
            for k in range(3):
                pa.append(ck.blade(P + "body_sfin%s_%d" % (tag, k), sh + V((sx * 0.06, (k - 1) * 0.04, 0.06)), sh + V((sx * (0.16 + k * 0.02), (k - 1) * 0.06, 0.17)),
                                   0.06, 0.012, glow if k == 1 and cfg["glow"] else t, (0, 1, 0), 0.3))
        ck._rigid(pa, rig, "upper_arm" + s)
    # ---------------- mangas e punhos ----------------
    for s in (".R", ".L"):
        tag = s.replace(".", "_")
        el_, wr = V(j["elbow" + s]), V(j["wrist" + s])
        if f == "c":
            g = [ck.tube(P + "gloves_bracer" + tag, el_.lerp(wr, 0.25), wr, 0.075, 0.08, dark, 12),
                 ck.tube(P + "gloves_strap" + tag, el_.lerp(wr, 0.6), el_.lerp(wr, 0.68), 0.084, 0.084, leather, 12)]
        else:
            g = [ck.tube(P + "gloves_sleeve" + tag, el_.lerp(wr, 0.3), wr + V((0, 0, -0.01)), 0.075, 0.1, t, 14),
                 ck.tube(P + "gloves_cuff" + tag, wr + V((0, 0, 0.005)), wr + V((0, 0, -0.015)), 0.103, 0.103, bone if f == "i" else t2, 14)]
        ck._rigid(g, rig, "forearm" + s)
        fist = ck.ball(P + "gloves_fist" + tag, b["hand"] * 1.15, ck.hand_center(base, s), dark if f != "i" else bone, (1, 1, 1.1))
        ck._rigid([fist], rig, "hand" + s)
    # ---------------- botas ----------------
    ck.armor_piece(body, rig, P + "boots_shell", "boots", dark, 0.02, 0.014)
    for s in (".R", ".L"):
        tag = s.replace(".", "_")
        an = V(j["ankle" + s])
        k = [ck.tube(P + "boots_cuff" + tag, an + V((0, 0, 0.06)), an + V((0, 0, 0.09)), 0.08, 0.085, t2 if f != "i" else bone, 12)]
        if f == "c":
            k.append(ck.tube(P + "boots_spike" + tag, an + V((0, -0.02, 0.1)), an + V((0, -0.08, 0.18)), 0.02, 0.002, metal, 6))
        ck._rigid(k, rig, "shin" + s)


# ---------------------------------------------------------------------------
def build_scythe(ck, base, mats, style, cfg):
    """Foice do conjunto, no mesmo eixo da foice do kit (cabo para cima, lâmina para a frente)."""
    V = Vector
    g = V(ck.hand_center(base, ".R"))
    f, tier = cfg["focus"], cfg["tier"]
    bone = ck.mat("m_nec_bone", BONE, 0.7)
    glow = ck.mat("m_nec_glow_%s" % f, GLOW[f], 0.3, 1.2)
    shaft_m = bone if cfg["blade"] == "bone" else mats["dark"]
    blade_m = mats["metal"] if f != "s" else mats["dark"]
    n = "sc_%s_" % style
    S = 1.0 + tier * 0.06
    top = g + V((0, 0, 0.9 * S))
    parts = []
    if cfg["blade"] == "bone":                    # cabo de vértebras
        for k in range(9):
            z0 = -0.3 + k * (0.9 * S + 0.3) / 9
            parts.append(ck.ball(n + "vert%d" % k, 0.032, g + V((0, 0, z0 + 0.05)), bone, (1, 1, 0.7)))
        parts.append(ck.tube(n + "shaft", g - V((0, 0, 0.3)), top, 0.018, 0.018, mats["dark"], 6))
    else:
        parts.append(ck.tube(n + "shaft", g - V((0, 0, 0.32)), top, 0.024, 0.022, shaft_m, 8))
        for k in range(2 + tier // 2):
            z = 0.12 + k * 0.1
            parts.append(ck.tube(n + "wrap%d" % k, g + V((0, 0, z - 0.012)), g + V((0, 0, z + 0.012)), 0.03, 0.03, mats["tint"], 8))
    parts.append(ck.ball(n + "pommel", 0.04, g - V((0, 0, 0.34)), mats["trim"]))

    def blade(tag, root, dirn, length, width, curve, jag):
        prev = root
        out = []
        for i in range(1, 8):
            a = i / 7
            p = root + dirn * (length * a) + V((0, 0, curve * math.sin(a * math.pi) - 0.22 * length * a * a))
            w = width * (1 - a) + 0.008
            if jag and i % 2 == 0:
                out.append(ck.tube(n + "%s_jag%d" % (tag, i), p, p + V((0, 0.0, -0.06)), w * 0.5, 0.004, blade_m, 4))
            out.append(ck.tube(n + "%s%d" % (tag, i), prev, p, w + 0.004, w, blade_m, 4))
            prev = p
        return out

    L = 0.6 * S
    parts += blade("blade", top, V((0, -1, 0)), L, 0.06, 0.1, cfg["blade"] == "jagged")
    if cfg["blade"] == "double":                  # segunda lâmina menor para trás
        parts += blade("blade_b", top - V((0, 0, 0.05)), V((0, 1, 0)), L * 0.55, 0.045, 0.06, False)
    parts.append(ck.ball(n + "socket", 0.05, top, mats["trim"] if f != "i" else bone, (1, 1, 1.2)))
    if tier >= 1:                                 # gema/olho no encaixe
        parts.append(ck.ball(n + "gem", 0.032, top + V((0.04, 0, 0)), glow, (0.5, 1, 1)))
    if tier >= 3:                                 # fio que brilha na lâmina
        prev = top + V((0, -0.06, -0.01))
        for i in range(1, 6):
            a = i / 5
            p = top + V((0, -L * 0.9 * a, 0.1 * math.sin(a * math.pi) - 0.2 * L * a * a - 0.02))
            parts.append(ck.tube(n + "edge%d" % i, prev, p, 0.01, 0.008, glow, 4))
            prev = p
    if f == "i" and tier >= 2:                    # caveira no topo
        parts.append(ck.ball(n + "skull", 0.06, top + V((0, 0.03, 0.07)), bone, (0.9, 0.85, 1.0)))
    obj = ck._join(parts, "wpn_main_scythe_%s" % style)
    ck._smooth(obj.data)
    ck.skin_rigid(obj, base["rig"], "hand.R")
    return obj


# ---------------------------------------------------------------------------
# Ato II (níveis 35/40/45; no híbrido, a armadura da 1ª build do par): UM visual novo por build, tema guerra contra a Horda
# em Monte Kharzun. A malha é a mesma nos três níveis; muda a cor do item (tint), o destaque (tint2) e o brilho: o material
# "tint_glow" recebe no jogo a cor de GearCatalog.ACT2_VISUALS[...]["glows"][nível] (KitModel).
#   nec_i35 Invocador = Ossuário de Guerra: coroa de ossos de dedos, crânio de orc em cada ombro, couraça de costelas e
#           armação de espinha e costelas subindo por trás dos ombros com um crânio de chifres no alto.
#   nec_c35 Ceifador  = Ceifeiro do Campo: capuz alto e pontudo de carrasco, laço de corda no pescoço, ombreiras com
#           correntes e lanternas acesas, couro rasgado e capa de tiras de estandartes caídos presas numa trave.
#   nec_s35 Sombras   = Eclipse: capuz com véu no rosto e crescente na testa, lascas flutuando nos ombros, túnica lisa e
#           disco de sol negro com aro aceso por trás da cabeça.
OLD_BONE = (0.66, 0.6, 0.48)


def _ring(ck, name, ctr, u, v, rad, thick, material, segs=16, a0=0.0, a1=math.tau):
    """Aro (ou arco de a0 a a1) de tubos no plano u-v."""
    out = []
    for i in range(segs):
        s0, s1 = a0 + (a1 - a0) * i / segs, a0 + (a1 - a0) * (i + 1) / segs
        out.append(ck.tube("%s%d" % (name, i), ctr + (u * math.cos(s0) + v * math.sin(s0)) * rad, ctr + (u * math.cos(s1) + v * math.sin(s1)) * rad, thick, thick, material, 5))
    return out


def lantern(ck, name, top, s, frame, glow):
    """Lanterna pendurada pelo ponto `top`: miolo aceso, tampa, pé e quatro barras."""
    V = Vector
    top = V(top)
    ctr = top - V((0, 0, s * 1.0))
    out = [ck.box(name + "_core", (s * 0.8, s * 0.8, s * 1.1), ctr, glow, s * 0.1),
           ck.box(name + "_cap", (s * 1.15, s * 1.15, s * 0.24), ctr + V((0, 0, s * 0.66)), frame, s * 0.05),
           ck.box(name + "_foot", (s * 1.05, s * 1.05, s * 0.2), ctr - V((0, 0, s * 0.62)), frame, s * 0.05),
           ck.tube(name + "_ring", ctr + V((0, 0, s * 0.75)), top, s * 0.14, s * 0.09, frame, 5)]
    for i, (dx, dy) in enumerate(((-1, -1), (1, -1), (1, 1), (-1, 1))):
        out.append(ck.tube(name + "_bar%d" % i, ctr + V((dx * s * 0.45, dy * s * 0.45, -s * 0.6)), ctr + V((dx * s * 0.45, dy * s * 0.45, s * 0.6)), s * 0.08, s * 0.08, frame, 4))
    return out


def _curve(ck, name, p0, p1, bend, r0, material, n=4, segs=8, r1=0.004):
    import ranger_sets as rs
    return rs.curve(ck, name, p0, p1, bend, r0, material, n, segs, r1)


def _skull(ck, name, ctr, R, face, bone, eye_m, dark, tusks=0.0, horns=0.0):
    """Crânio olhando para `face` (vetor no plano do chão): calota, maxilar, órbitas acesas; presas (orc) ou chifres opcionais."""
    V = Vector
    ctr = V(ctr)
    f = V(face).normalized()
    sd = V((-f.y, f.x, 0))
    up = V((0, 0, 1))
    out = [ck.ball(name + "_dome", R, ctr, bone, (1.0, 1.0, 0.92)),
           ck.ball(name + "_jaw", R * 0.62, ctr + f * R * 0.45 - up * R * 0.62, bone, (1.0, 1.0, 0.75)),
           ck.ball(name + "_nose", R * 0.14, ctr + f * R * 0.98 - up * R * 0.2, dark, (1, 1, 1.4))]
    for sg in (-1, 1):
        out.append(ck.ball(name + "_eye%d" % sg, R * 0.27, ctr + f * R * 0.82 + sd * sg * R * 0.4 + up * R * 0.08, eye_m))
        if tusks > 0.0:               # presas de orc subindo do maxilar
            p0 = ctr + f * R * 0.75 + sd * sg * R * 0.52 - up * R * 0.7
            out += _curve(ck, name + "_tusk%d" % sg, p0, p0 + f * R * 0.2 + sd * sg * R * 0.25 + up * R * 1.5 * tusks, f * R * 0.35, R * 0.2, bone, 4, 6, 0.006)
        if horns > 0.0:               # chifres abrindo para os lados e para cima
            p0 = ctr + sd * sg * R * 0.8 + up * R * 0.45
            out += _curve(ck, name + "_horn%d" % sg, p0, p0 + sd * sg * R * 1.3 * horns + up * R * 1.2 * horns, sd * sg * R * 0.4 - up * R * 0.3, R * 0.28, dark, 4, 6, 0.006)
    return out


def _a2_robe(ck, base, mats, P, robe_m, legs_m, bottom, flare, belt_m, boots_m=None):
    """Corpo, calça, saia, cinto e botas (peças que seguem o corpo). Devolve a saia."""
    import ranger_sets as rs
    rig, body, b = base["rig"], base["body"], base["b"]
    ck.armor_piece(body, rig, P + "body_robe", "torso", robe_m, 0.014, 0.014, 0.03)
    ck.armor_piece(body, rig, P + "body_legs", "legs", legs_m, 0.008, 0.012)
    sk = ck.skirt(P + "body_skirt", b, body, rig, robe_m, bottom, flare)
    rs.body_belt(ck, base, P + "body_belt", ck.Z["waist"] - 0.04, ck.Z["waist"] + 0.035, 1.21, belt_m)
    ck.armor_piece(body, rig, P + "boots_shell", "boots", boots_m or mats["dark"], 0.02, 0.014)
    return sk


def _a2_hair(ck, base, P):
    import elementalist_sets as es
    return es._act2_hair(ck, base, P)


def build_ossuary(ck, base, mats, style):
    """nec_i35 — Ossuário de Guerra (Invocador)."""
    import ranger_sets as rs
    V = Vector
    rig, b, j = base["rig"], base["b"], base["j"]
    t, t2, dark = mats["tint"], mats["tint2"], mats["dark"]
    P = "arm_%s_" % style
    bone = ck.mat("m_nec_bone", BONE, 0.7)
    old = ck.mat("m_nec_bone_old", OLD_BONE, 0.8)
    glow = rs.tint_glow(ck)
    _a2_robe(ck, base, mats, P, t, dark, 0.07, 1.74, t2)
    c, r = V(base["head_c"]), b["head"]
    # ---------------- cabeça: aro de osso com caveirinha na testa e coroa de dedos (três falanges, ponta em garra) ----------------
    head = _a2_hair(ck, base, P)
    head.append(ck.tube(P + "head_band", c + V((0, 0, r * 0.34)), c + V((0, 0, r * 0.5)), r * 1.13, r * 1.11, old, 24))
    head += _skull(ck, P + "head_mark", c + V((0, -r * 1.12, r * 0.47)), r * 0.2, (0, -1, 0), bone, glow, dark)
    n = 9
    for k in range(n):
        a = math.tau * (k + 0.5) / n + math.pi * 1.5
        dv = V((math.cos(a), math.sin(a), 0))
        tall = 1.0 if k % 2 == 0 else 0.72
        p0 = c + dv * r * 1.1 + V((0, 0, r * 0.46))
        p1 = p0 + dv * r * 0.26 * tall + V((0, 0, r * 0.44 * tall))
        p2 = p1 + dv * r * 0.12 * tall + V((0, 0, r * 0.4 * tall))
        p3 = p2 - dv * r * 0.1 * tall + V((0, 0, r * 0.3 * tall))
        head += [ck.tube(P + "head_fa%d" % k, p0, p1, r * 0.1, r * 0.08, bone, 6), ck.tube(P + "head_fb%d" % k, p1, p2, r * 0.08, r * 0.065, bone, 6),
                 ck.tube(P + "head_fc%d" % k, p2, p3, r * 0.065, r * 0.012, old, 6),
                 ck.ball(P + "head_k1_%d" % k, r * 0.115, p1, old), ck.ball(P + "head_k2_%d" % k, r * 0.095, p2, old)]
    ck._rigid(rs.outward(head), rig, "head")
    # ---------------- corpo: couraça de costelas com coração aceso, gola de vértebras ----------------
    d = b["depth"]
    front = -b["chest"] * d - 0.03
    back = b["chest"] * d + 0.03
    zc, zn, zw = ck.Z["chest"], ck.Z["neck"], ck.Z["waist"]
    chest = [ck.ball(P + "body_heart", 0.05, (0, front + 0.012, zc + 0.02), glow, (1.0, 0.45, 1.25)),
             ck.tube(P + "body_sternum", (0, front - 0.026, zc + 0.15), (0, front - 0.02, zc - 0.13), 0.026, 0.018, bone, 6)]
    for k in range(5):
        z = zc + 0.13 - k * 0.058
        w = b["chest"] * (1.0 - k * 0.05) + 0.035
        for sx in (-1, 1):
            chest += _curve(ck, P + "body_rib%d_%d" % (sx, k), (0, front - 0.03, z), (sx * w, front + 0.13, z - 0.035), (sx * 0.035, -0.03, 0), 0.021, bone, 3, 5, 0.014)
    for k in range(7):                   # gola de vértebras em ponta
        a = math.pi * (0.08 + 0.84 * k / 6)
        p = V((math.cos(a) * b["chest"] * 0.6, math.sin(a) * b["chest"] * 0.55, zn - 0.02))
        chest += [ck.ball(P + "body_vert%d" % k, 0.036, p, old, (1, 1, 0.8)),
                  ck.tube(P + "body_vspike%d" % k, p, p + V((math.cos(a) * 0.05, math.sin(a) * 0.06, 0.1)), 0.02, 0.003, bone, 5)]
    # armação nas costas: espinha subindo por fora da cabeça, quatro pares de costelas abrindo em leque, crânio de chifres no alto
    sp = [V((0, back + 0.03, zw + 0.06)), V((0, back + 0.1, zc + 0.1)), V((0, r * 1.2 + 0.05, zn + 0.16)), V((0, r * 1.2 + 0.07, c.z + r * 0.45)), V((0, r * 1.2 + 0.05, c.z + r * 1.2))]
    for i in range(len(sp) - 1):
        chest.append(ck.tube(P + "body_spine%d" % i, sp[i], sp[i + 1], 0.03, 0.03, old, 6))
        for q in (0.25, 0.75):
            chest.append(ck.ball(P + "body_sv%d_%d" % (i, int(q * 4)), 0.052, sp[i].lerp(sp[i + 1], q), bone, (1.25, 0.9, 0.7)))
    for k in range(4):
        root = sp[2].lerp(sp[4], 0.08 + k * 0.27)
        reach = 0.62 - k * 0.07
        for sx in (-1, 1):
            tip = root + V((sx * reach, -0.22 - k * 0.03, 0.2 + k * 0.03))
            chest += _curve(ck, P + "body_wing%d_%d" % (sx, k), root, tip, (sx * 0.1, 0.16, 0.12), 0.044, bone, 5, 6, 0.016)
            chest.append(ck.tube(P + "body_wtip%d_%d" % (sx, k), tip - V((sx * 0.03, -0.012, 0.012)), tip + V((sx * 0.02, -0.09, 0.03)), 0.022, 0.003, glow, 5))
    chest += _skull(ck, P + "body_top", sp[4] + V((0, -0.02, 0.13)), 0.115, (0, -1, 0), bone, glow, dark, 0.0, 1.0)
    ck._rigid(rs.outward(chest), rig, "chest")
    wf = -b["waist"] * d * 1.21
    hips = [ck.blade(P + "body_sash", (0, wf - 0.004, zw - 0.02), (0, wf - 0.03, zw - 0.34), 0.1, 0.012, t2, (1, 0, 0), 0.5)]
    hips += _skull(ck, P + "body_buckle", (0, wf - 0.02, zw), 0.05, (0, -1, 0), bone, glow, dark)
    for k in range(5):                   # ossos de dedo pendurados no cinto
        x = (k - 2) * 0.075
        if k == 2:
            continue
        y = -math.sqrt(max(0.0, 1.0 - (x / (b["waist"] * 1.25)) ** 2)) * b["waist"] * d * 1.25
        hips += [ck.tube(P + "body_dang%d" % k, (x, y - 0.01, zw - 0.03), (x, y - 0.02, zw - 0.13 - 0.03 * (k % 2)), 0.017, 0.013, bone, 5),
                 ck.ball(P + "body_dangk%d" % k, 0.022, (x, y - 0.02, zw - 0.135 - 0.03 * (k % 2)), old)]
    ck._rigid(rs.outward(hips), rig, "hips")
    for s, sx in ((".R", -1), (".L", 1)):                 # crânio de orc em cada ombro, virado para a frente e para fora
        tag = s.replace(".", "_")
        sh = V(j["shoulder" + s])
        pa = _skull(ck, P + "body_orc" + tag, sh + V((sx * 0.085, -0.01, 0.1)), b["arm"] * 1.2 + 0.075, (sx * 0.55, -0.83, 0), old, glow, dark, 1.45)
        pa.append(ck.ball(P + "body_orcpad" + tag, b["arm"] * 2.3, sh + V((sx * 0.05, 0, 0.02)), t2, (1.15, 1.1, 0.4)))
        ck._rigid(rs.outward(pa), rig, "upper_arm" + s)
    # ---------------- mangas, punhos e botas ----------------
    for s in (".R", ".L"):
        tag = s.replace(".", "_")
        el_, wr = V(j["elbow" + s]), V(j["wrist" + s])
        g = [ck.tube(P + "gloves_sleeve" + tag, el_.lerp(wr, 0.25), wr + V((0, 0, -0.012)), 0.076, 0.108, t, 14),
             ck.tube(P + "gloves_cuff" + tag, wr + V((0, 0, 0.008)), wr + V((0, 0, -0.018)), 0.112, 0.112, bone, 14)]
        for k in range(3):               # ossos do antebraço por cima da manga
            a = math.tau * k / 3 + 0.5
            o = V((math.cos(a), math.sin(a), 0))
            g.append(ck.tube(P + "gloves_ulna%d%s" % (k, tag), el_.lerp(wr, 0.3) + o * 0.085, wr + o * 0.11 + V((0, 0, 0.01)), 0.016, 0.014, old, 5))
        ck._rigid(rs.outward(g), rig, "forearm" + s)
        ck._rigid([ck.ball(P + "gloves_fist" + tag, b["hand"] * 1.15, ck.hand_center(base, s), bone, (1, 1, 1.1))], rig, "hand" + s)
        an = V(j["ankle" + s])
        ck._rigid(rs.outward([ck.tube(P + "boots_cuff" + tag, an + V((0, 0, 0.06)), an + V((0, 0, 0.095)), 0.082, 0.088, bone, 12),
                              ck.tube(P + "boots_claw" + tag, an + V((0, -0.07, 0.05)), an + V((0, -0.15, 0.015)), 0.024, 0.003, old, 5),
                              ck.ball(P + "boots_gem" + tag, 0.02, an + V((0, -0.085, 0.08)), glow)]), rig, "shin" + s)


def build_field_reaper(ck, base, mats, style):
    """nec_c35 — Ceifeiro do Campo (Ceifador)."""
    import ranger_sets as rs
    V = Vector
    rig, b, j = base["rig"], base["b"], base["j"]
    t, t2, dark, leather, metal, wood = mats["tint"], mats["tint2"], mats["dark"], mats["leather"], mats["metal"], mats["wood"]
    P = "arm_%s_" % style
    iron = ck.mat("m_nec_iron", (0.2, 0.19, 0.22), 0.5)
    rope = ck.mat("m_nec_rope", (0.7, 0.6, 0.4), 0.9)
    glow = rs.tint_glow(ck)
    knee = ck.Z["knee"] + 0.04
    sk = _a2_robe(ck, base, mats, P, t, iron, knee, 1.42, leather, iron)
    hem = []                             # barra rasgada: tiras de couro e pano desiguais
    n = 12
    for k in range(n):
        a = math.tau * (k + 0.5) / n
        dv = V((math.cos(a), math.sin(a) * b["depth"] * 1.05, 0))
        p = dv * (b["waist"] * 1.18 * 1.42 + 0.01) + V((0, 0, knee + 0.02))
        hem.append(ck.blade(P + "body_rag_%d" % k, p, p + dv * 0.03 - V((0, 0, 0.1 + 0.07 * ((k * 5) % 3) / 2.0)), 0.085, 0.012, (t, dark, leather)[k % 3], V((-dv.y, dv.x, 0)), 0.3))
    hem = ck._join(rs.outward(hem), P + "body_rags")
    ck._smooth(hem.data)
    ck.transfer_weights(hem, sk, rig)
    c, r = V(base["head_c"]), b["head"]
    # ---------------- cabeça: capuz de carrasco, alto e pontudo, tombando para trás; rosto no escuro, só os olhos acesos ----------------
    head = [ck._shell(P + "head_hood", c, r * 1.17, 0.12, -1.0, -0.62, 0.035, t),
            ck.ball(P + "head_face", r * 1.02, c + V((0, -r * 0.06, -r * 0.04)), iron, (0.98, 1.0, 0.98)),
            ck.tube(P + "head_cone_a", c + V((0, 0.0, r * 0.62)), c + V((0, r * 0.16, r * 1.5)), r * 0.96, r * 0.5, t, 14),
            ck.tube(P + "head_cone_b", c + V((0, r * 0.16, r * 1.5)), c + V((0, r * 0.5, r * 2.15)), r * 0.5, r * 0.22, t, 12),
            ck.tube(P + "head_cone_c", c + V((0, r * 0.5, r * 2.15)), c + V((0, r * 1.0, r * 2.42)), r * 0.22, r * 0.03, t, 10),
            ck.tube(P + "head_cone_band", c + V((0, r * 0.03, r * 0.82)), c + V((0, r * 0.06, r * 1.0)), r * 0.93, r * 0.82, t2, 14)]
    for sx in (-1, 1):                   # olhos: fendas inclinadas
        head.append(ck.blade(P + "head_eye%d" % sx, c + V((sx * r * 0.14, -r * 1.07, -r * 0.1)), c + V((sx * r * 0.5, -r * 0.98, r * 0.06)), r * 0.2, 0.03, glow, (0, 0, 1), 0.4))
    for k in range(9):                   # barra do capuz em tiras, caindo nos ombros
        a = math.pi * (-0.08 + 1.16 * k / 8)
        dv = V((math.cos(a), math.sin(a), 0))
        head.append(ck.blade(P + "head_rag%d" % k, c + dv * r * 1.05 + V((0, 0, -r * 0.35)), c + dv * r * 1.24 + V((0, 0, -r * (0.95 + 0.2 * (k % 2)))),
                             r * 0.42, 0.016, t if k % 2 else t2, V((-dv.y, dv.x, 0)), 0.25))
    ck._rigid(rs.outward(head), rig, "head")
    # ---------------- corpo: laço de corda, tiras de couro em X ----------------
    d = b["depth"]
    front = -b["chest"] * d - 0.03
    back = b["chest"] * d + 0.03
    zc, zn, zw = ck.Z["chest"], ck.Z["neck"], ck.Z["waist"]
    chest = _ring(ck, P + "body_noose", V((0, 0.0, zn - 0.035)), V((1, 0, 0)), V((0, 0.9, 0)), b["chest"] * 0.72, 0.026, rope, 12)
    chest += [ck.tube(P + "body_knot", (0.02, front + 0.0, zn - 0.05), (0.025, front - 0.02, zn - 0.16), 0.034, 0.03, rope, 6),
              ck.tube(P + "body_rope_end", (0.025, front - 0.02, zn - 0.16), (0.04, front - 0.015, zc - 0.1), 0.018, 0.016, rope, 5)]
    for sx in (-1, 1):
        chest.append(rs.ribbon(ck, P + "body_strap%d" % sx, [(sx * 0.15, front + 0.03, zc + 0.15), (0, front - 0.004, zc), (-sx * 0.13, front + 0.03, zw + 0.05)],
                               (1, 0, 0), (0.06, 0.06, 0.06), 0.012, leather))
    chest.append(ck.ball(P + "body_stud", 0.03, (0, front - 0.012, zc), iron, (1, 0.5, 1)))
    # trave de estandarte atrás dos ombros e tiras de bandeiras caídas (compridas, desiguais, com dobra)
    py = max(back + 0.1, r * 0.62)
    pz = zn + 0.03
    chest += [ck.tube(P + "body_pole", (-0.5, py, pz), (0.5, py, pz), 0.022, 0.022, wood, 6)]
    for sx in (-1, 1):
        chest += [ck.tube(P + "body_pole_tip%d" % sx, (sx * 0.5, py, pz), (sx * 0.62, py, pz), 0.032, 0.003, iron, 6),
                  ck.tube(P + "body_pole_strap%d" % sx, (sx * 0.1, py, pz), (sx * 0.12, front + 0.02, zn - 0.03), 0.014, 0.014, leather, 5)]
    cols = (t2, dark, t, t2, leather, t, t2)
    lens = (0.42, 0.62, 0.78, 0.7, 0.56, 0.74, 0.46)
    for k in range(7):
        x = (k - 3) * 0.135
        L = lens[k]
        pts = [(x, py + 0.012, pz + 0.01), (x * 1.04, py + 0.07, pz - L * 0.3), (x * 1.1, py + 0.05 + 0.03 * (k % 2), pz - L * 0.65), (x * 1.16, py + 0.11, pz - L)]
        chest.append(rs.ribbon(ck, P + "body_strip%d" % k, pts, (1, 0, 0), (0.125, 0.12, 0.11, 0.1), 0.014, cols[k]))
        chest.append(ck.blade(P + "body_strip_end%d" % k, pts[-1], (pts[-1][0] + 0.02 * (-1) ** k, pts[-1][1] + 0.02, pts[-1][2] - 0.1), 0.085, 0.012, cols[k], (1, 0, 0), 0.2))
    chest.append(ck.ball(P + "body_sigil", 0.05, (0, py + 0.085, pz - lens[3] * 0.34), glow, (1.0, 0.3, 1.3)))
    ck._rigid(rs.outward(chest), rig, "chest")
    wf = -b["waist"] * d * 1.21
    hips = [ck.box(P + "body_buckle", (0.075, 0.025, 0.065), (0, wf - 0.012, zw), iron, 0.008),
            ck.ball(P + "body_buckle_core", 0.022, (0, wf - 0.03, zw), glow)]
    for k in range(6):                   # corrente caída no quadril esquerdo
        hips.append(ck.ball(P + "body_hchain%d" % k, 0.017, (0.06 + k * 0.02, wf * (0.95 - k * 0.04), zw - 0.04 - 0.05 * math.sin(math.pi * k / 5.0)), metal, (1, 0.5, 1)))
    ck._rigid(rs.outward(hips), rig, "hips")
    for s, sx in ((".R", -1), (".L", 1)):                 # ombreira de ferro com gancho, corrente e lanterna acesa
        tag = s.replace(".", "_")
        sh = V(j["shoulder" + s])
        hook = sh + V((sx * 0.25, -0.01, 0.2))
        pa = [ck.ball(P + "body_pauldron" + tag, b["arm"] * 2.5, sh + V((sx * 0.06, 0, 0.05)), iron, (1.15, 1.1, 0.6)),
              ck.ball(P + "body_pauldron_rim" + tag, b["arm"] * 2.58, sh + V((sx * 0.06, 0, 0.02)), t2, (1.16, 1.12, 0.15))]
        pa += _curve(ck, P + "body_hook" + tag, sh + V((sx * 0.07, 0, 0.1)), hook, (0, 0, 0.07), 0.026, iron, 4, 6, 0.016)
        for k in range(3):
            pa.append(ck.ball(P + "body_lchain%d%s" % (k, tag), 0.016, hook - V((0, 0, 0.02 + k * 0.035)), metal, (1, 0.6, 1.2)))
        pa += lantern(ck, P + "body_lantern" + tag, hook - V((0, 0, 0.11)), 0.115, iron, glow)
        ck._rigid(rs.outward(pa), rig, "upper_arm" + s)
    # ---------------- braçadeiras de couro com tiras, botas com cravo ----------------
    for s in (".R", ".L"):
        tag = s.replace(".", "_")
        el_, wr = V(j["elbow" + s]), V(j["wrist" + s])
        g = [ck.tube(P + "gloves_bracer" + tag, el_.lerp(wr, 0.22), wr, 0.076, 0.084, leather, 12),
             ck.tube(P + "gloves_band" + tag, el_.lerp(wr, 0.3), el_.lerp(wr, 0.42), 0.087, 0.089, iron, 12),
             ck.tube(P + "gloves_wrap" + tag, el_.lerp(wr, 0.72), el_.lerp(wr, 0.86), 0.09, 0.091, t2, 12),
             ck.blade(P + "gloves_tail" + tag, el_.lerp(wr, 0.8) + V((0, 0.08, 0)), el_.lerp(wr, 0.8) + V((0, 0.13, -0.17)), 0.05, 0.01, t2, (1, 0, 0), 0.3)]
        ck._rigid(rs.outward(g), rig, "forearm" + s)
        ck._rigid([ck.ball(P + "gloves_fist" + tag, b["hand"] * 1.15, ck.hand_center(base, s), iron, (1, 1, 1.1))], rig, "hand" + s)
        an = V(j["ankle" + s])
        ck._rigid(rs.outward([ck.tube(P + "boots_cuff" + tag, an + V((0, 0, 0.06)), an + V((0, 0, 0.1)), 0.082, 0.09, leather, 12),
                              ck.tube(P + "boots_band" + tag, an + V((0, 0, 0.035)), an + V((0, 0, 0.055)), 0.08, 0.08, iron, 12),
                              ck.tube(P + "boots_spike" + tag, an + V((0, -0.03, 0.09)), an + V((0, -0.1, 0.17)), 0.022, 0.002, metal, 6)]), rig, "shin" + s)


def build_eclipse(ck, base, mats, style):
    """nec_s35 — Eclipse (Sombras)."""
    import ranger_sets as rs
    V = Vector
    rig, b, j = base["rig"], base["b"], base["j"]
    t, t2, gold = mats["tint"], mats["tint2"], mats["trim"]
    P = "arm_%s_" % style
    void = ck.mat("m_nec_void", (0.07, 0.06, 0.1), 0.45)
    glow = rs.tint_glow(ck)
    _a2_robe(ck, base, mats, P, t, void, 0.05, 1.86, t2)
    c, r = V(base["head_c"]), b["head"]
    # ---------------- cabeça: capuz fundo, véu no rosto (só os olhos acesos), aro com crescente na testa ----------------
    head = [ck._shell(P + "head_cowl", c, r * 1.17, 0.42, -1.0, -0.62, 0.035, t),
            ck.tube(P + "head_circlet", c + V((0, 0, r * 0.4)), c + V((0, 0, r * 0.5)), r * 1.2, r * 1.19, gold, 24),
            ck.ball(P + "head_moon_dark", r * 0.15, c + V((0, -r * 1.2, r * 0.56)), void, (1, 0.4, 1))]
    head += _ring(ck, P + "head_moon", c + V((0, -r * 1.21, r * 0.56)), V((1, 0, 0)), V((0, 0, 1)), r * 0.2, r * 0.045, glow, 8, math.pi * 1.1, math.pi * 1.9)
    for k in range(7):                   # véu: tiras que acompanham o rosto do nariz até o peito (os olhos ficam de fora)
        a = math.radians(-54 + k * 18.0)
        dv = V((math.sin(a), -math.cos(a), 0))
        pts = [c + dv * r * (1.07 * math.cos(math.asin(z))) + V((0, 0, r * z)) for z in (-0.42, -0.62, -0.82)] + [c + dv * r * 0.66 + V((0, 0, -r * (1.06 + 0.1 * (k % 2))))]
        head.append(rs.ribbon(ck, P + "head_veil%d" % k, pts, (dv.y, -dv.x, 0), (r * 0.38, r * 0.38, r * 0.34, r * 0.24), 0.014, t if k % 2 else t2))
    head.append(ck.tube(P + "head_veil_cord", c + V((0, 0, -r * 0.45)), c + V((0, 0, -r * 0.4)), r * 0.99, r * 0.995, gold, 20))
    for k in range(5):                   # barra do capuz caindo nas costas
        a = math.pi * (0.18 + 0.64 * k / 4)
        dv = V((math.cos(a), math.sin(a), 0))
        head.append(ck.blade(P + "head_fall%d" % k, c + dv * r * 1.05 + V((0, 0, -r * 0.4)), c + dv * r * 1.2 + V((0, 0, -r * 1.1)), r * 0.6, 0.016, t, V((-dv.y, dv.x, 0)), 0.3))
    ck._rigid(rs.outward(head), rig, "head")
    # ---------------- sol negro: disco escuro com aro aceso e coroa de raios, por trás da cabeça (segue a cabeça) ----------------
    R = r * 1.58
    dc = c + V((0, r * 1.14, r * 0.3))
    ux, uz = V((1, 0, 0)), V((0, 0, 1))
    sun = [ck.tube(P + "body_sun_disc", dc, dc + V((0, 0.035, 0)), R, R * 0.97, void, 28)]
    sun += _ring(ck, P + "body_sun_rim", dc + V((0, 0.012, 0)), ux, uz, R * 1.01, 0.03, glow, 28)
    for k in range(12):
        a = math.tau * k / 12 + math.pi / 12
        dv = ux * math.cos(a) + uz * math.sin(a)
        long_ = k % 2 == 0
        sun.append(ck.blade(P + "body_sun_ray%d" % k, dc + V((0, 0.02, 0)) + dv * R * 1.03, dc + V((0, 0.02, 0)) + dv * R * (1.42 if long_ else 1.22), R * 0.3, 0.022,
                            t2 if long_ else void, V((-dv.z, 0, dv.x)), 0.3))
    ck._rigid(rs.outward(sun), rig, "head")
    # ---------------- corpo: túnica lisa, faixa com as fases da lua, gola baixa ----------------
    d = b["depth"]
    front = -b["chest"] * d - 0.03
    zc, zn, zw = ck.Z["chest"], ck.Z["neck"], ck.Z["waist"]
    chest = [ck.box(P + "body_panel", (0.075, 0.014, 0.27), (0, front, zc - 0.045), t2, 0.004)]
    for k in range(3):                   # fases: crescente, cheia (apagada, com aro), minguante
        p = V((0, front - 0.012, zc + 0.045 - k * 0.085))
        if k == 1:
            chest.append(ck.ball(P + "body_phase1", 0.026, p, void, (1, 0.4, 1)))
            chest += _ring(ck, P + "body_phase1_rim", p - V((0, 0.006, 0)), ux, uz, 0.03, 0.007, glow, 10)
        else:
            chest.append(ck.ball(P + "body_phase%d" % k, 0.024, p, glow, (0.55, 0.4, 1)))
    chest += _ring(ck, P + "body_collar", V((0, 0, zn - 0.035)), V((1, 0, 0)), V((0, 0.9, 0)), b["chest"] * 0.7, 0.024, t2, 12)
    ck._rigid(rs.outward(chest), rig, "chest")
    wf = -b["waist"] * d * 1.21
    hips = [ck.blade(P + "body_sash", (0, wf - 0.004, zw - 0.02), (0, wf - 0.03, zw - 0.36), 0.085, 0.012, t2, (1, 0, 0), 0.5),
            ck.ball(P + "body_seal", 0.034, (0, wf - 0.02, zw), void, (1, 0.45, 1))]
    hips += _ring(ck, P + "body_seal_rim", V((0, wf - 0.03, zw)), ux, uz, 0.038, 0.008, glow, 10)
    ck._rigid(rs.outward(hips), rig, "hips")
    for s, sx in ((".R", -1), (".L", 1)):                 # calota baixa e três lascas escuras flutuando sobre cada ombro (a do meio acesa)
        tag = s.replace(".", "_")
        sh = V(j["shoulder" + s])
        pa = [ck.ball(P + "body_pad" + tag, b["arm"] * 2.2, sh + V((sx * 0.05, 0, 0.04)), t2, (1.12, 1.08, 0.45))]
        for k in range(3):
            q = sh + V((sx * (0.13 + 0.08 * k), (k - 1) * 0.12 - 0.04, 0.2 + 0.08 * (k == 1)))
            L = 0.17 + 0.07 * (k == 1)
            tilt = V((sx * 0.25, (k - 1) * 0.2, 1.0)).normalized()
            pa += [ck.tube(P + "body_shard%d_a%s" % (k, tag), q, q + tilt * L, 0.055, 0.003, glow if k == 1 else t2, 5),
                   ck.tube(P + "body_shard%d_b%s" % (k, tag), q, q - tilt * L * 0.6, 0.055, 0.003, glow if k == 1 else t2, 5)]
        ck._rigid(rs.outward(pa), rig, "upper_arm" + s)
    # ---------------- mangas longas, botas ----------------
    for s in (".R", ".L"):
        tag = s.replace(".", "_")
        el_, wr = V(j["elbow" + s]), V(j["wrist" + s])
        g = [ck.tube(P + "gloves_sleeve" + tag, el_.lerp(wr, 0.2), wr + V((0, 0, -0.02)), 0.076, 0.125, t, 14),
             ck.tube(P + "gloves_cuff" + tag, wr + V((0, 0, 0.0)), wr + V((0, 0, -0.026)), 0.129, 0.129, t2, 14),
             ck.ball(P + "gloves_gem" + tag, 0.02, el_.lerp(wr, 0.6) + V((0, -0.1, 0)), glow)]
        ck._rigid(rs.outward(g), rig, "forearm" + s)
        ck._rigid([ck.ball(P + "gloves_fist" + tag, b["hand"] * 1.15, ck.hand_center(base, s), void, (1, 1, 1.1))], rig, "hand" + s)
        an = V(j["ankle" + s])
        ck._rigid(rs.outward([ck.tube(P + "boots_cuff" + tag, an + V((0, 0, 0.06)), an + V((0, 0, 0.095)), 0.082, 0.088, t2, 12),
                              ck.ball(P + "boots_gem" + tag, 0.02, an + V((0, -0.085, 0.078)), glow)]), rig, "shin" + s)


def build_scythe2(ck, base, mats, style, kind):
    """Foices do Ato II (mesmo eixo da foice do kit): bone = maxilar e espinha, field = foice de guerra com lanterna e tira de
    estandarte, eclipse = crescente duplo em volta de um disco negro. Fio aceso = tint_glow."""
    import ranger_sets as rs
    V = Vector
    g = V(ck.hand_center(base, ".R"))
    glow = rs.tint_glow(ck)
    bone = ck.mat("m_nec_bone", BONE, 0.7)
    old = ck.mat("m_nec_bone_old", OLD_BONE, 0.8)
    iron = ck.mat("m_nec_iron", (0.2, 0.19, 0.22), 0.5)
    void = ck.mat("m_nec_void", (0.07, 0.06, 0.1), 0.45)
    t, t2, gold, dark, metal = mats["tint"], mats["tint2"], mats["trim"], mats["dark"], mats["metal"]
    n = "sc_%s_" % style
    S = 1.36
    top = g + V((0, 0, 0.9 * S))
    fw = V((0, -1, 0))
    parts = []

    def blade(tag, root, dirn, length, width, curve, material, jag=False, edge=True):
        out = []
        prev = root
        pe = None
        for i in range(1, 8):
            a = i / 7
            p = root + dirn * (length * a) + V((0, 0, curve * math.sin(a * math.pi) - 0.22 * length * a * a))
            w = width * (1 - a) + 0.008
            if jag and i % 2 == 0:
                out.append(ck.tube(n + "%s_jag%d" % (tag, i), p, p + V((0, 0, -0.085)) + dirn * 0.02, w * 0.6, 0.004, material, 4))
            out.append(ck.tube(n + "%s%d" % (tag, i), prev, p, w + 0.004, w, material, 4))
            if edge:                  # fio aceso por baixo da lâmina
                q = p - V((0, 0, w * 0.75))
                if pe is not None:
                    out.append(ck.tube(n + "%s_edge%d" % (tag, i), pe, q, 0.013, 0.011, glow, 4))
                pe = q
            prev = p
        return out

    if kind == "bone":                 # cabo de vértebras, lâmina de maxilar com dentes, crânio de chifres no encaixe
        parts.append(ck.tube(n + "shaft", g - V((0, 0, 0.32)), top, 0.019, 0.019, dark, 6))
        for k in range(11):
            parts.append(ck.ball(n + "vert%d" % k, 0.034, g + V((0, 0, -0.27 + k * (0.9 * S + 0.25) / 11)), bone if k % 2 else old, (1, 1, 0.7)))
        parts += blade("blade", top, fw, 0.74 * S / 1.3, 0.075, 0.12, bone, True)
        parts += blade("rib", top - V((0, 0, 0.06)), -fw, 0.34, 0.04, 0.05, old, False, False)
        parts += _skull(ck, n + "skull", top + V((0, 0.02, 0.06)), 0.07, (0, -1, 0), bone, glow, dark, 0.0, 0.8)
        parts.append(ck.tube(n + "pommel", g - V((0, 0, 0.3)), g - V((0, 0, 0.42)), 0.03, 0.003, old, 6))
    elif kind == "field":              # foice de guerra: lâmina larga e dentada, lanterna na corrente, tira de estandarte
        parts.append(ck.tube(n + "shaft", g - V((0, 0, 0.34)), top, 0.025, 0.023, mats["wood"], 8))
        for k in range(3):
            z = 0.1 + k * 0.11
            parts.append(ck.tube(n + "wrap%d" % k, g + V((0, 0, z - 0.014)), g + V((0, 0, z + 0.014)), 0.031, 0.031, mats["leather"], 8))
        parts += blade("blade", top, fw, 0.78 * S / 1.3, 0.085, 0.11, iron, True)
        parts += [ck.tube(n + "socket", top - V((0, 0, 0.1)), top + V((0, 0, 0.05)), 0.04, 0.045, iron, 8),
                  ck.tube(n + "spike", top + V((0, 0, 0.04)), top + V((0, 0, 0.26)), 0.03, 0.003, iron, 6),
                  ck.tube(n + "butt", g - V((0, 0, 0.33)), g - V((0, 0, 0.45)), 0.03, 0.003, iron, 6)]
        hook = top + V((0, 0.17, 0.02))
        parts.append(ck.tube(n + "arm", top - V((0, 0, 0.02)), hook, 0.018, 0.014, iron, 5))
        for k in range(2):
            parts.append(ck.ball(n + "chain%d" % k, 0.015, hook - V((0, 0, 0.025 + k * 0.035)), metal, (1, 0.6, 1.2)))
        parts += lantern(ck, n + "lantern", hook - V((0, 0, 0.08)), 0.075, iron, glow)
        parts.append(rs.ribbon(ck, n + "banner", [top - V((0, -0.03, 0.12)), top - V((0, -0.1, 0.24)), top - V((0, -0.07, 0.4)), top - V((0, -0.12, 0.52))],
                               (1, 0, 0), (0.085, 0.09, 0.08, 0.04), 0.012, t2))
    else:                              # eclipse: disco negro com aro aceso no encaixe, crescente grande para a frente e pequeno para trás
        parts.append(ck.tube(n + "shaft", g - V((0, 0, 0.34)), top, 0.023, 0.021, void, 8))
        for k in range(3):
            z = 0.1 + k * 0.11
            parts.append(ck.tube(n + "wrap%d" % k, g + V((0, 0, z - 0.012)), g + V((0, 0, z + 0.012)), 0.029, 0.029, t if k % 2 == 0 else t2, 8))
        parts += blade("blade", top, fw, 0.76 * S / 1.3, 0.07, 0.13, void)
        parts += blade("blade_b", top - V((0, 0, 0.03)), -fw, 0.4, 0.05, 0.07, void)
        dc = top + V((0, 0, 0.02))
        parts.append(ck.tube(n + "disc", dc - V((0.02, 0, 0)), dc + V((0.02, 0, 0)), 0.115, 0.115, void, 16))
        parts += _ring(ck, n + "disc_rim", dc, V((0, 1, 0)), V((0, 0, 1)), 0.12, 0.017, glow, 14)
        parts += [ck.tube(n + "shard", top + V((0, 0, 0.2)), top + V((0, 0, 0.36)), 0.035, 0.003, glow, 5),
                  ck.tube(n + "shard_b", top + V((0, 0, 0.2)), top + V((0, 0, 0.15)), 0.035, 0.003, glow, 5),
                  ck.ball(n + "pommel", 0.036, g - V((0, 0, 0.36)), gold)]
    obj = ck._join(rs.outward(parts), "wpn_main_scythe_%s" % style)
    ck._smooth(obj.data)
    ck.skin_rigid(obj, base["rig"], "hand.R")
    return obj


ACT2_SETS = {"nec_i35": ("bone", build_ossuary), "nec_c35": ("field", build_field_reaper), "nec_s35": ("eclipse", build_eclipse)}


def register(ck):
    import paladin_sets
    for style, (kind, fn) in ACT2_SETS.items():              # Ato II: um visual novo por build (35/40/45; híbridos pela 1ª build)
        ck.SET_STYLES[style] = (lambda st, f: (lambda base, mats: (f(ck, base, mats, st), paladin_sets.join_slots("arm_%s_" % st))))(style, fn)
        ck.SET_WEAPONS[style + "_scythe"] = (lambda st, kd: (lambda base, mats: build_scythe2(ck, base, mats, st, kd)))(style, kind)
    for style, cfg in NEC_SETS.items():
        ck.SET_STYLES[style] = (lambda st, cf: (lambda base, mats: (build(ck, base, mats, st, cf), paladin_sets.join_slots("arm_%s_" % st))))(style, cfg)
        ck.SET_WEAPONS[style + "_scythe"] = (lambda st, cf: (lambda base, mats: build_scythe(ck, base, mats, st, cf)))(style, cfg)


# ---------------------------------------------------------------------------
# Ato III (nível 50, GDD ato3-lendarios-50): UM visual novo por build no tema de Lumeria. Malhas no kit extra
# kit_necromancer_<sexo>_a3.glb (chibi_kit.A3_STYLES); motivos comuns em lumeria_kit.py. Função simples (sem o par
# (tipo, fn) de ACT2_SETS).
#   nec_i50 Invocador = Cortejo de Porcelana: capuz alto de seda (tint2, ameixa) que cai para trás, com máscaras cegas
#           penduradas como troféus; UMA máscara de porcelana sem olhos em cada ombro, grande, virada para fora e para cima
#           (assinatura, lida de cima); lágrima pintada no rosto; túnica marfim com tiras de seda até o tornozelo.
def build_porcelain_cortege(ck, base, mats, style):
    """nec_i50 — Cortejo de Porcelana (Invocador)."""
    import lumeria_kit as lk
    import berserker_sets as bs
    V = Vector
    rig, body, b, j = base["rig"], base["body"], base["b"], base["j"]
    M = lk.lum_mats(ck, mats)
    t, t2, gold, porc, glow = M["t"], M["t2"], M["gold"], M["porc"], M["glow"]
    P = "arm_%s_" % style
    c, r = V(base["head_c"]), b["head"]
    d = b["depth"]
    front = -b["chest"] * d - 0.03
    back = b["chest"] * d + 0.03
    zc, zn, zw = ck.Z["chest"], ck.Z["neck"], ck.Z["waist"]
    # ---------------- túnica ----------------
    _a2_robe(ck, base, mats, P, t, mats["dark"], 0.07, 1.74, gold, t2)
    # ---------------- cabeça: capuz alto caindo para trás, troféus pendurados, lágrima pintada sob o olho esquerdo ----------------
    k0, k1, k2 = c + V((0, r * 0.1, r * 0.55)), c + V((0, r * 0.55, r * 1.5)), c + V((0, r * 1.35, r * 1.75))
    head = [ck._shell(P + "head_hood", c, r * 1.12, 0.2, -0.95, -0.7, 0.04, t2),
            ck.tube(P + "head_peak0", k0, k1, r * 0.88, r * 0.5, t2, 12),
            ck.tube(P + "head_peak1", k1, k2, r * 0.5, r * 0.2, t2, 10),
            ck.ball(P + "head_peak_end", r * 0.22, k2, t2),
            ck.ball(P + "head_tear", r * 0.055, c + V((r * 0.38, -r * 0.93, -r * 0.28)), glow, (0.8, 0.6, 2.2)),
            ck.ball(P + "head_tear_drop", r * 0.075, c + V((r * 0.38, -r * 0.9, -r * 0.42)), glow, (1, 0.6, 1.2))]
    for i, (ang, drop) in enumerate(((0.0, 0.5), (math.radians(125), 0.3), (math.radians(-125), 0.3))):       # troféus: atrás, e um de cada lado
        dv = V((math.sin(ang), math.cos(ang), 0))
        hang = (k2 if i == 0 else c + dv * r * 1.08 + V((0, 0, r * 0.3)))
        mc = hang + dv * r * 0.12 + V((0, 0, -r * drop))
        head.append(ck.tube(P + "head_trophy_cord%d" % i, hang, mc + V((0, 0, r * 0.2)), 0.008, 0.008, gold, 4))
        head += lk.mask(ck, P + "head_trophy%d" % i, mc, r * 0.26, M, facing=(dv.x, dv.y, 0.15), eyes=False, tears=(1,), wide=1.1, tear_len=0.4)
    ck._rigid(bs._outward(head), rig, "head")
    # ---------------- corpo: gola alta, corrente com medalhão-máscara, tiras de seda ----------------
    chest = [ck.tube(P + "body_collar", V((0, 0, zn - 0.07)), V((0, 0, zn + 0.03)), b["chest"] * 0.82, b["chest"] * 0.55, t2, 14),
             ck.tube(P + "body_collar_rim", V((0, 0, zn - 0.085)), V((0, 0, zn - 0.065)), b["chest"] * 0.86, b["chest"] * 0.84, gold, 14)]
    chest += lk.mask(ck, P + "body_pendant", (0, front - 0.03, zc + 0.03), 0.075, M, eyes=False, tears=(-1, 1), tear_len=0.4)
    for sx in (-1, 1):
        chest.append(ck.tube(P + "body_pendant_chain%d" % sx, (sx * b["chest"] * 0.6, front + 0.05, zn - 0.07), (sx * 0.03, front - 0.03, zc + 0.1), 0.009, 0.009, gold, 4))
        chest.append(lk.silk(ck, P + "body_back%d" % sx, (sx * 0.07, back - 0.01, zn - 0.06), (sx * 0.13, back + 0.1, zw + 0.02), (1, 0, 0), 0.12, 0.15, t2, (0, 0.03, 0), 3))
    ck._rigid(bs._outward(chest), rig, "chest")
    wf = -b["waist"] * d * 1.22
    strips = []
    for k in range(6):                   # tiras de seda do cinto até o tornozelo, em volta da saia (pesos do corpo)
        a = math.tau * (k + 0.5) / 6
        dv = V((math.cos(a), math.sin(a) * d * 1.05, 0))
        p0 = dv * b["waist"] * 1.24 + V((0, 0, zw - 0.03))
        p1 = dv * b["waist"] * 2.12 + V((0, 0, 0.12 + 0.05 * (k % 2)))
        strips.append(lk.silk(ck, P + "body_strip%d" % k, p0, p1, (-math.sin(a), math.cos(a), 0), 0.09, 0.14, t2, dv * 0.012, 5, 0.014))
    lk.skinned(ck, base, bs._outward(strips))
    hips = lk.mask(ck, P + "body_buckle", (0, wf - 0.02, zw - 0.005), 0.055, M, eyes=False, tears=(1,), tear_len=0.4)
    ck._rigid(bs._outward(hips), rig, "hips")
    for s, sx in ((".R", -1), (".L", 1)):                 # ombros de máscaras: rosto cego virado para fora e para cima
        tag = s.replace(".", "_")
        sh = V(j["shoulder" + s])
        pa = [ck.ball(P + "body_pad" + tag, b["arm"] * 2.4, sh + V((sx * 0.07, 0, 0.02)), t2, (1.15, 1.15, 0.6))]
        pa += lk.mask(ck, P + "body_shoulder_mask" + tag, sh + V((sx * 0.21, -0.02, 0.1)), 0.18, M, facing=(sx * 0.66, -0.3, 0.69), eyes=False,
                      tears=(sx,), wide=1.12, tear_len=0.5)
        for i, sy in enumerate((-1, 1)):
            p0 = sh + V((sx * 0.14, sy * 0.09, -0.02))
            pa.append(lk.silk(ck, P + "body_fall%d%s" % (i, tag), p0, p0 + V((sx * 0.1, sy * 0.05, -0.3 - i * 0.05)), (1, sy * 0.7, 0), 0.075, 0.1, t2, (sx * 0.03, 0, 0), 3))
        ck._rigid(bs._outward(pa), rig, "upper_arm" + s)
    # mangas, punhos de ouro e botas (a casca das botas já vem em _a2_robe)
    for s, sx in ((".R", -1), (".L", 1)):
        tag = s.replace(".", "_")
        el_, wr, an = V(j["elbow" + s]), V(j["wrist" + s]), V(j["ankle" + s])
        g = [ck.tube(P + "gloves_sleeve" + tag, el_.lerp(wr, 0.2), wr + V((0, 0, -0.014)), 0.076, 0.118, t, 14),
             ck.tube(P + "gloves_cuff" + tag, wr + V((0, 0, 0.01)), wr + V((0, 0, -0.022)), 0.123, 0.123, gold, 14),
             ck.tube(P + "gloves_band" + tag, el_.lerp(wr, 0.45), el_.lerp(wr, 0.58), 0.094, 0.103, t2, 12)]
        g += lk.mask(ck, P + "gloves_mask" + tag, el_.lerp(wr, 0.62) + V((sx * 0.105, 0, 0)), 0.05, M, facing=(sx, 0, 0), eyes=False, tears=(), rim=False)
        ck._rigid(bs._outward(g), rig, "forearm" + s)
        ck._rigid([ck.ball(P + "gloves_fist" + tag, b["hand"] * 1.15, ck.hand_center(base, s), porc, (1, 1, 1.1))], rig, "hand" + s)
        ck._rigid(bs._outward([ck.tube(P + "boots_cuff" + tag, an + V((0, 0, 0.06)), an + V((0, 0, 0.096)), 0.084, 0.09, gold, 12),
                               ck.ball(P + "boots_tear" + tag, 0.02, an + V((0, -0.088, 0.075)), glow, (0.7, 0.6, 1.5))]), rig, "shin" + s)



#   nec_c50 Ceifador = Colheita do Último Brinde: capuz RASGADO de seda (tint2, borra de vinho) com bico caído e farrapos
#           pendendo da barra, máscara de porcelana SEM boca com uma lágrima, GOLA ALTA de taças quebradas (cacos de vidro
#           e ouro abrindo em volta do pescoço, lidos de cima), taça derramando no ombro, barra da túnica em farrapos.
def build_last_toast_harvest(ck, base, mats, style):
    """nec_c50 — Colheita do Último Brinde (Ceifador)."""
    import lumeria_kit as lk
    import berserker_sets as bs
    import bpy
    V = Vector
    rig, body, b, j = base["rig"], base["body"], base["b"], base["j"]
    M = lk.lum_mats(ck, mats)
    t, t2, gold, porc, glow, glass = M["t"], M["t2"], M["gold"], M["porc"], M["glow"], M["glass"]
    leather, dark, ink = M["leather"], M["dark"], M["ink"]
    hair = bpy.data.materials.get("hair") or t
    P = "arm_%s_" % style
    c, r = V(base["head_c"]), b["head"]
    d = b["depth"]
    front = -b["chest"] * d - 0.03
    back = b["chest"] * d + 0.03
    zc, zn, zw = ck.Z["chest"], ck.Z["neck"], ck.Z["waist"]
    wf = -b["waist"] * d * 1.22
    import paladin_sets as ps
    # ---------------- túnica ----------------
    ck.armor_piece(body, rig, P + "body_robe", "torso", t, 0.014, 0.014, 0.03)
    ck.armor_piece(body, rig, P + "body_legs", "legs", dark, 0.008, 0.012)
    ck.skirt(P + "body_skirt", b, body, rig, t, 0.09, 1.7)
    bs._belt(ck, base, P + "body_belt", zw - 0.04, zw + 0.035, 1.21, gold)
    # ---------------- cabeça: capuz rasgado, máscara sem boca ----------------
    k0, k1 = c + V((0, r * 0.25, r * 0.7)), c + V((0, r * 1.25, r * 0.95))
    head = [ck._shell(P + "head_hood", c, r * 1.14, 0.42, -0.9, -0.62, 0.04, t2),
            ck.tube(P + "head_peak", k0, k1, r * 0.8, r * 0.12, t2, 10),
            ck.tube(P + "head_hood_trim", c + V((0, -r * 0.2, r * 0.44)), c + V((0, -r * 0.2, r * 0.52)), r * 1.14, r * 1.1, gold, 18)]
    for k in range(9):                   # farrapos: tiras desiguais pendendo da barra do capuz, dos lados e atrás
        a = math.radians(70 + k * 27.5)  # 70° (lado esquerdo) a 290° (lado direito), passando pela nuca
        dv = V((math.sin(a), -math.cos(a), 0))
        root = c + dv * r * 1.1 + V((0, 0, -r * 0.5))
        ln = r * (0.75 + 0.5 * ((k * 7) % 4) / 3.0)
        head.append(ck.blade(P + "head_tatter%d" % k, root, root + dv * r * 0.22 + V((0, 0, -ln)), r * 0.42, r * 0.06, t2, (-dv.y, dv.x, 0), 0.3))
    head += lk.mask(ck, P + "head_mask", c + V((0, -r * 1.03, -r * 0.08)), r * 0.76, M, tears=(-1,), wide=1.16, tall=1.04, tear_len=0.7, eye_z=0.22)
    ck._rigid(bs._outward(head), rig, "head")
    # ---------------- corpo: gola de taças quebradas, corrente de taças, farrapos na barra ----------------
    chest = [ck.tube(P + "body_collar", V((0, 0, zn - 0.08)), V((0, 0, zn + 0.0)), b["chest"] * 0.86, b["chest"] * 0.6, gold, 16)]
    n = 11
    for k in range(n):                   # cacos: abrem para fora e para cima, de ombro a ombro pela nuca (a frente fica livre)
        a = math.radians(48 + k * 26.4)
        dv = V((math.sin(a), -math.cos(a) * 0.9, 0))
        root = dv * b["chest"] * 0.72 + V((0, 0, zn - 0.03))
        tip = dv * (r * (1.5 + 0.2 * (k % 2))) + V((0, 0, zn + 0.2 + 0.05 * ((k * 5) % 3)))
        chest.append(ck.blade(P + "body_shard%d" % k, root, tip, 0.17, 0.026, glass if k % 2 == 0 else gold, (-dv.y, dv.x, 0), 0.6))
    a0, a1 = V((-b["chest"] * 0.8, front + 0.02, zn - 0.09)), V((b["chest"] * 0.8, front + 0.02, zn - 0.09))
    chest += ps._chain(ck, P + "body_chain", a0, a1, 0.12, gold, 8, 0.012)
    for k in range(3):
        q = 0.25 + k * 0.25
        chest += lk.goblet(ck, P + "body_cup%d" % k, a0.lerp(a1, q) + V((0, -0.05, -0.12 * math.sin(math.pi * q) - 0.005)), 0.042, M)
    ck._rigid(bs._outward(chest), rig, "chest")
    hips = lk.mask(ck, P + "body_buckle", (0, wf - 0.02, zw - 0.005), 0.055, M, tears=(-1,), tear_len=0.4)
    for k in range(10):                  # farrapos de seda caindo do cinto, em volta da saia
        a = math.tau * (k + 0.5) / 10
        dv = V((math.cos(a), math.sin(a) * d * 1.05, 0))
        p0 = dv * b["waist"] * 1.25 + V((0, 0, zw - 0.04))
        ln = 0.2 + 0.14 * ((k * 3) % 4) / 3.0
        hips.append(ck.blade(P + "body_rag%d" % k, p0, p0 + dv * ln * 0.45 + V((0, 0, -ln)), 0.13, 0.016, t2, (-math.sin(a), math.cos(a), 0), 0.3))
    ck._rigid(bs._outward(hips), rig, "hips")
    for s, sx in ((".R", -1), (".L", 1)):                 # ombros: manta rasgada; no direito, taça grande derramando vinho aceso
        tag = s.replace(".", "_")
        sh = V(j["shoulder" + s])
        pa = [ck.ball(P + "body_pad" + tag, b["arm"] * 2.5, sh + V((sx * 0.06, 0, 0.02)), t2, (1.2, 1.2, 0.6))]
        for k in range(4):
            a = math.radians(-70 + k * 47)
            p0 = sh + V((sx * (0.06 + math.cos(a) * 0.12), math.sin(a) * 0.13, 0.0))
            pa.append(ck.blade(P + "body_shred%d%s" % (k, tag), p0, p0 + V((sx * math.cos(a) * 0.08, math.sin(a) * 0.07, -0.2 - (k % 2) * 0.09)), 0.11, 0.016, t2, (-math.sin(a), sx * math.cos(a), 0), 0.3))
        if s == ".R":
            top = sh + V((sx * 0.2, 0, 0.24))
            pa += lk.goblet(ck, P + "body_shoulder_cup", top, 0.11, M)
            pa += [ck.ball(P + "body_spill0", 0.03, top + V((sx * 0.085, -0.02, -0.03)), glow, (0.8, 0.8, 1.8)),
                   ck.ball(P + "body_spill1", 0.036, top + V((sx * 0.1, -0.02, -0.12)), glow, (1, 1, 1.3))]
        else:
            pa += lk.mask(ck, P + "body_shoulder_mask", sh + V((sx * 0.17, -0.02, 0.1)), 0.13, M, facing=(sx * 0.6, -0.3, 0.74), eyes=False, tears=(sx,), tear_len=0.45)
        ck._rigid(bs._outward(pa), rig, "upper_arm" + s)
    lk.limbs(ck, base, mats, P, M, "cloth", boots_m=dark)


ACT3_SETS = {"nec_i50": build_porcelain_cortege, "nec_c50": build_last_toast_harvest}
