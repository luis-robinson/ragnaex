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


def register(ck):
    import paladin_sets
    for style, cfg in NEC_SETS.items():
        ck.SET_STYLES[style] = (lambda st, cf: (lambda base, mats: (build(ck, base, mats, st, cf), paladin_sets.join_slots("arm_%s_" % st))))(style, cfg)
        ck.SET_WEAPONS[style + "_scythe"] = (lambda st, cf: (lambda base, mats: build_scythe(ck, base, mats, st, cf)))(style, cfg)
