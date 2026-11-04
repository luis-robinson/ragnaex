"""Conjuntos lendários do Elementalista (18 = 3 focos × 6 níveis) e cajados, por construtor paramétrico (desenho original).

Linguagem visual: maga de túnica longa. O elemento PRINCIPAL dá o chapéu/coroa, a barra da túnica e a cor;
o SEGUNDO elemento (conjuntos de combinação) aparece nos ombros e nos orbes que flutuam em volta.
fogo: chapéu pontudo com labaredas ou diadema de chamas, barra com línguas de fogo subindo, ombreiras de chama.
gelo: coroa de cristais ou capuz de pele, barra com pingentes de gelo, ombros de cristal.
raio: chapéu de aba larga com chifres de raio ou faixa de chifres, barra em zigue-zague, ombros com hastes elétricas.
Peças: arm_<estilo>_<head|body|gloves|boots>_*; arma: wpn_main_staff_<estilo>.
"""
import math
from mathutils import Vector

GLOW = {"fire": (1.0, 0.4, 0.08), "frost": (0.4, 0.78, 1.0), "storm": (1.0, 0.82, 0.22)}
DEEP = {"fire": (0.75, 0.18, 0.08), "frost": (0.25, 0.5, 0.9), "storm": (0.35, 0.28, 0.75)}
# elemento favorecido (2º) por nível: igual a GearCatalog.SET_VISUALS "favor"
SECOND = {"fire": [None, "storm", "frost", None, "storm", "frost"],
          "frost": [None, "fire", "storm", None, "fire", "storm"],
          "storm": [None, "fire", "frost", None, "fire", "frost"]}
HEADS = {"fire": ["flame_hat", "flame_circlet", "flame_hat", "flame_circlet", "flame_hat", "flame_hat"],
         "frost": ["ice_crown", "fur_hood", "ice_crown", "fur_hood", "ice_crown", "ice_crown"],
         "storm": ["storm_hat", "horn_band", "storm_hat", "horn_band", "storm_hat", "storm_hat"]}
LEVELS = [5, 10, 15, 20, 25, 30]
LETTER = {"fire": "f", "frost": "g", "storm": "r"}


def _sets():
    out = {}
    for el in ("fire", "frost", "storm"):
        for i, lv in enumerate(LEVELS):
            out["ele_%s%d" % (LETTER[el], lv)] = {"el": el, "second": SECOND[el][i], "head": HEADS[el][i], "tier": i,
                                                  "robe": (0.08 - i * 0.005, 1.7 + i * 0.06), "over": 0.0 if i < 2 else 0.2 + i * 0.02,
                                                  "mantle": i >= 1, "collar": i >= 2, "orbs": [0, 1, 2, 2, 3, 3][i]}
    return out


ELE_SETS = _sets()


def _hem(ck, name, b, el, bottom, flare, material, n=14):
    """Enfeite da barra da túnica: línguas de fogo subindo, pingentes de gelo descendo ou zigue-zague de raio."""
    r = b["waist"] * 1.18 * flare + 0.012
    out = []
    for k in range(n):
        a = math.tau * (k + 0.5) / n
        d = Vector((math.cos(a), math.sin(a) * b["depth"] * 1.05, 0))
        p = d * r + Vector((0, 0, bottom))
        tang = Vector((-d.y, d.x, 0)).normalized()
        if el == "fire":
            out.append(ck.blade("%s_%d" % (name, k), p - Vector((0, 0, 0.01)), p + Vector((0, 0, 0.09 + 0.05 * (k % 2))) + d * 0.01, 0.07, 0.012, material, tang, 0.3))
        elif el == "frost":
            out.append(ck.tube("%s_%d" % (name, k), p + Vector((0, 0, 0.01)), p - Vector((0, 0, 0.06 + 0.04 * (k % 2))), 0.022, 0.003, material, 5))
        else:
            q = p + Vector((0, 0, 0.07)) + tang * 0.04
            out += [ck.tube("%s_%d_a" % (name, k), p, q, 0.011, 0.011, material, 5),
                    ck.tube("%s_%d_b" % (name, k), q, q + Vector((0, 0, 0.04)) - tang * 0.03, 0.011, 0.006, material, 5)]
    return out


def build(ck, base, mats, style, cfg):
    import bpy
    V = Vector
    rig, body, b, j = base["rig"], base["body"], base["b"], base["j"]
    t, t2, gold, wh = mats["tint"], mats["tint2"], mats["trim"], mats["white"]
    el, el2, tier = cfg["el"], cfg["second"], cfg["tier"]
    glow = ck.mat("m_ele_glow_%s" % el, GLOW[el], 0.3, 0.8)
    deep = ck.mat("m_ele_deep_%s" % el, DEEP[el], 0.5, 0.4)
    glow2 = ck.mat("m_ele_glow_%s" % el2, GLOW[el2], 0.3, 0.8) if el2 else glow
    deep2 = ck.mat("m_ele_deep_%s" % el2, DEEP[el2], 0.5, 0.4) if el2 else deep
    P = "arm_%s_" % style
    c = V(base["head_c"])
    r = b["head"]
    # ---------------- cabeça ----------------
    hk = cfg["head"]
    head = []
    if hk in ("flame_circlet", "horn_band", "ice_crown", "storm_hat", "flame_hat"):     # peça aberta: cabelo comprido da cor da classe
        hair = bpy.data.materials.get("hair") or t
        head += [ck._shell(P + "head_hair", c + V((0, r * 0.04, r * 0.02)), r * 1.06, 0.25, -0.85, -0.25, 0.04, hair)]
        for sx in (-1, 0, 1):
            head.append(ck.strand(P + "head_lock%d" % sx, c + V((sx * r * 0.45, r * 0.75, -r * 0.1)), r * 1.15, r * 0.3, r * 0.22, hair, taper=0.9, lean=(sx * 0.1, 0.5)))
    if hk == "flame_hat":          # chapéu pontudo de aba larga; a ponta vira labareda
        head += [ck.tube(P + "head_brim", c + V((0, 0, r * 0.5)), c + V((0, 0, r * 0.56)), r * 1.7, r * 1.62, t, 28),
                 ck.tube(P + "head_cone", c + V((0, 0, r * 0.52)), c + V((r * 0.15, r * 0.25, r * 1.75)), r * 0.95, r * 0.12, t, 16),
                 ck.tube(P + "head_band", c + V((0, 0, r * 0.56)), c + V((0, 0, r * 0.72)), r * 0.98, r * 0.92, t2, 20)]
        for k in range(3):
            head.append(ck.blade(P + "head_flame%d" % k, c + V((r * 0.15, r * 0.25, r * 1.6)), c + V((r * (0.1 + 0.25 * (k - 1)), r * 0.4, r * (2.15 - 0.15 * abs(k - 1)))),
                                 r * 0.3, 0.015, glow if k == 1 else deep, (1, 0, 0), 0.3))
        head.append(ck.ball(P + "head_gem", 0.04, c + V((0, -r * 0.98, r * 0.64)), glow2, (1, 0.6, 1.3)))
    elif hk == "flame_circlet":    # diadema com chamas na testa
        head.append(ck.tube(P + "head_circlet", c + V((0, 0, r * 0.36)), c + V((0, 0, r * 0.46)), r * 1.11, r * 1.1, gold, 24))
        for k in range(5):
            a = math.pi * (1.25 + 0.5 * k / 4)
            d = V((math.cos(a), math.sin(a), 0))
            head.append(ck.blade(P + "head_flame%d" % k, c + d * r * 1.1 + V((0, 0, r * 0.42)), c + d * r * 1.2 + V((0, 0, r * (0.85 + 0.2 * (k == 2)))),
                                 r * 0.22, 0.015, glow if k % 2 == 0 else deep, V((-d.y, d.x, 0)), 0.3))
    elif hk == "ice_crown":        # coroa de cristais de alturas diferentes
        head.append(ck.tube(P + "head_circlet", c + V((0, 0, r * 0.4)), c + V((0, 0, r * 0.5)), r * 1.1, r * 1.09, wh, 24))
        for k in range(9):
            a = math.tau * k / 9 + math.pi * 1.5
            d = V((math.cos(a), math.sin(a), 0))
            h = 0.45 + 0.35 * (1.0 - abs(math.sin(a / 2 - math.pi * 0.75)))
            head.append(ck.tube(P + "head_shard%d" % k, c + d * r * 1.08 + V((0, 0, r * 0.45)), c + d * r * 1.18 + V((0, 0, r * (0.45 + h))),
                                r * 0.12, r * 0.01, glow if k % 2 else deep, 6))
    elif hk == "fur_hood":         # capuz com borda de pele e pingentes
        head.append(ck._shell(P + "head_hood", c, r * 1.15, 0.3, -1.0, -0.5, 0.035, t))
        for k in range(16):            # tufos de pele em volta do rosto
            a = math.pi * (-0.15 + 1.3 * k / 15)
            head.append(ck.ball(P + "head_fur%d" % k, r * 0.17, c + V((math.cos(a) * r * 0.95, -r * 0.72, math.sin(a) * r * 0.75 + r * 0.05)), wh, (1, 0.7, 1)))
        for sx in (-1, 1):
            head.append(ck.tube(P + "head_icicle%d" % sx, c + V((sx * r * 0.85, -r * 0.4, -r * 0.3)), c + V((sx * r * 0.9, -r * 0.42, -r * 0.75)), r * 0.1, r * 0.01, glow, 6))
    elif hk == "storm_hat":        # aba larga ondulada, copa baixa e dois chifres de raio
        head += [ck.tube(P + "head_brim", c + V((0, 0, r * 0.5)), c + V((0, 0, r * 0.56)), r * 1.75, r * 1.7, t, 28),
                 ck._shell(P + "head_crown", c + V((0, 0, r * 0.2)), r * 0.98, 0.5, 0.3, 0.35, 0.035, t),
                 ck.tube(P + "head_band", c + V((0, 0, r * 0.58)), c + V((0, 0, r * 0.7)), r * 1.0, r * 0.98, t2, 20)]
    if hk in ("storm_hat", "horn_band"):
        if hk == "horn_band":
            head.append(ck.tube(P + "head_band", c + V((0, 0, r * 0.36)), c + V((0, 0, r * 0.48)), r * 1.11, r * 1.1, t2, 24))
        z0 = r * (0.85 if hk == "storm_hat" else 0.5)
        for sx in (-1, 1):             # chifre em zigue-zague
            p0 = c + V((sx * r * 0.55, -r * 0.2, z0))
            p1 = p0 + V((sx * r * 0.35, 0, r * 0.35))
            p2 = p1 + V((-sx * r * 0.05, 0, r * 0.25))
            p3 = p2 + V((sx * r * 0.3, 0, r * 0.35))
            head += [ck.tube(P + "head_horn%d_a" % sx, p0, p1, r * 0.09, r * 0.08, glow, 5), ck.tube(P + "head_horn%d_b" % sx, p1, p2, r * 0.08, r * 0.07, glow, 5),
                     ck.tube(P + "head_horn%d_c" % sx, p2, p3, r * 0.07, r * 0.01, glow, 5)]
    ck._rigid(head, rig, "head")
    # ---------------- corpo: túnica, sobretúnica, barra ----------------
    ck.armor_piece(body, rig, P + "body_robe", "torso", t, 0.014, 0.014, 0.03)
    ck.armor_piece(body, rig, P + "body_legs", "legs", deep, 0.008, 0.012)
    bottom, flare = cfg["robe"]
    sk = ck.skirt(P + "body_skirt", b, body, rig, t, bottom, flare)
    hem_src, hem_b, hem_f = sk, bottom, flare
    if cfg["over"] > 0.0:
        ob = ck.Z["waist"] - cfg["over"]
        ck.skirt(P + "body_over", b, body, rig, t2, ob, flare * 0.85)
    hem = ck._join(_hem(ck, P + "body_hem", b, el, hem_b, hem_f, glow if tier >= 3 else deep), P + "body_hem")
    ck.transfer_weights(hem, hem_src, rig)
    d = b["depth"]
    front = -b["chest"] * d - 0.03
    back = b["chest"] * d + 0.03
    zc, zn = ck.Z["chest"], ck.Z["neck"]
    chest = [ck.box(P + "body_panel", (0.09, 0.015, 0.24), (0, front, zc - 0.04), t2, 0.004),
             ck.ball(P + "body_brooch", 0.035, (0, front - 0.012, zc + 0.08), glow, (1, 0.6, 1.2))]
    if el2:
        chest.append(ck.ball(P + "body_brooch2", 0.022, (0, front - 0.016, zc + 0.01), glow2, (1, 0.6, 1.2)))
    if cfg["collar"]:              # gola alta aberta na frente
        for k in range(7):
            a = math.pi * (0.1 + 0.8 * k / 6)
            p = V((math.cos(a) * b["chest"] * 0.55, math.sin(a) * b["chest"] * 0.5, zn - 0.02))
            chest.append(ck.blade(P + "body_collar%d" % k, p, p + V((math.cos(a) * 0.04, math.sin(a) * 0.04, 0.11)), 0.07, 0.012, t2, (-math.sin(a), math.cos(a), 0), 0.5))
    if cfg["mantle"]:              # capinha curta nas costas
        for k in range(5):
            x = (k - 2) * 0.07
            chest.append(ck.blade(P + "body_mantle%d" % k, (x * 0.8, back + 0.01, zn - 0.04), (x * 1.25, back + 0.07, zn - 0.24 - (k % 2) * 0.05),
                                  0.1, 0.014, t if k % 2 == 0 else t2, (1, 0, 0), 0.25))
    for i in range(cfg["orbs"]):   # orbes elementais flutuando (alternam principal/segundo elemento)
        a = math.pi * (0.25 + 0.5 * i / max(1, cfg["orbs"] - 1)) if cfg["orbs"] > 1 else math.pi * 0.5
        p = V((math.cos(a) * 0.36, 0.1 + math.sin(a) * 0.06, zn + 0.12 + 0.05 * (i % 2)))
        chest.append(ck.ball(P + "body_orb%d" % i, 0.045, p, glow2 if (i % 2 and el2) else glow))
    ck._rigid(chest, rig, "chest")
    belt = ck.tube(P + "body_belt", (0, 0, ck.Z["waist"] - 0.035), (0, 0, ck.Z["waist"] + 0.03), b["waist"] * 1.2, b["waist"] * 1.2, t2, 16)
    for v in belt.data.vertices:
        v.co.y *= d * 1.05
    ck._smooth(belt.data)
    ck.transfer_weights(belt, body, rig)
    sash = [ck.blade(P + "body_sash", (0.06, -b["waist"] * d * 1.22, ck.Z["waist"] - 0.02), (0.09, -b["waist"] * d * 1.3, ck.Z["waist"] - 0.3), 0.07, 0.012, t2, (1, 0, 0), 0.3)]
    ck._rigid(sash, rig, "hips")
    # ombros: motivo do 2º elemento (ou do principal)
    sel = el2 or el
    smat, sdeep = (glow2, deep2) if el2 else (glow, deep)
    for s, sx in ((".R", -1), (".L", 1)):
        sh = V(j["shoulder" + s])
        pa = [ck.ball(P + "body_pad" + s.replace(".", "_"), b["arm"] * 1.9, sh + V((sx * 0.05, 0, 0.04)), t2, (1.1, 1.05, 0.5))]
        tag = s.replace(".", "_")
        if sel == "fire":
            for k in range(3):
                pa.append(ck.blade(P + "body_sflame%s_%d" % (tag, k), sh + V((sx * (0.04 + k * 0.03), (k - 1) * 0.04, 0.06)),
                                   sh + V((sx * (0.08 + k * 0.04), (k - 1) * 0.05, 0.2 + 0.04 * (k == 1))), 0.06, 0.012, smat if k == 1 else sdeep, (0, 1, 0), 0.3))
        elif sel == "frost":
            for k in range(3):
                pa.append(ck.tube(P + "body_sshard%s_%d" % (tag, k), sh + V((sx * 0.06, (k - 1) * 0.04, 0.06)),
                                  sh + V((sx * (0.14 + k * 0.03), (k - 1) * 0.07, 0.16 + 0.05 * (k == 1))), 0.03, 0.003, smat if k % 2 else sdeep, 6))
        else:
            for k in range(2):
                p0 = sh + V((sx * 0.06, (k - 0.5) * 0.06, 0.06))
                p1 = p0 + V((sx * 0.06, 0, 0.08))
                pa += [ck.tube(P + "body_srod%s_%d" % (tag, k), p0, p1, 0.014, 0.012, gold, 5),
                       ck.ball(P + "body_sspark%s_%d" % (tag, k), 0.026, p1 + V((0, 0, 0.02)), smat)]
        ck._rigid(pa, rig, "upper_arm" + s)
    # ---------------- mangas largas e punhos ----------------
    for s in (".R", ".L"):
        tag = s.replace(".", "_")
        el_, wr = V(j["elbow" + s]), V(j["wrist" + s])
        g = [ck.tube(P + "gloves_sleeve" + tag, el_.lerp(wr, 0.3), wr + V((0, 0, -0.01)), 0.075, 0.105, t, 14),
             ck.tube(P + "gloves_cuff" + tag, wr + V((0, 0, 0.005)), wr + V((0, 0, -0.015)), 0.108, 0.108, glow if tier >= 2 else t2, 14)]
        ck._rigid(g, rig, "forearm" + s)
        fist = ck.ball(P + "gloves_fist" + tag, b["hand"] * 1.15, ck.hand_center(base, s), wh, (1, 1, 1.1))
        ck._rigid([fist], rig, "hand" + s)
    # ---------------- botas ----------------
    ck.armor_piece(body, rig, P + "boots_shell", "boots", deep, 0.02, 0.014)
    for s in (".R", ".L"):
        tag = s.replace(".", "_")
        an = V(j["ankle" + s])
        ck._rigid([ck.tube(P + "boots_cuff" + tag, an + V((0, 0, 0.06)), an + V((0, 0, 0.09)), 0.08, 0.085, t2, 12)], rig, "shin" + s)


# ---------------------------------------------------------------------------
# Cajados: cabeça pelo elemento principal, e uma gema do segundo elemento (combinação)
def build_staff(ck, base, mats, style, cfg):
    V = Vector
    g = V(ck.hand_center(base, ".R"))
    up = V((-0.22, -0.12, 1.0)).normalized()
    side = V((1, 0, 0))
    fwd = up.cross(side).normalized()
    el, el2, tier = cfg["el"], cfg["second"], cfg["tier"]
    glow = ck.mat("m_ele_glow_%s" % el, GLOW[el], 0.3, 0.8)
    deep = ck.mat("m_ele_deep_%s" % el, DEEP[el], 0.5, 0.4)
    glow2 = ck.mat("m_ele_glow_%s" % el2, GLOW[el2], 0.3, 0.8) if el2 else None
    wood = mats["wood"] if tier < 3 else mats["dark"]
    gold = mats["trim"]
    n = "es_%s_" % style
    ln = 1.35
    bot, top = g - up * ln * 0.42, g + up * ln * 0.58
    parts = [ck.tube(n + "shaft", bot, top, 0.03, 0.028, wood, 8),
             ck.tube(n + "foot", bot - up * 0.05, bot + up * 0.03, 0.02, 0.034, gold, 8)]
    for k in range(2 + tier // 2):
        z = 0.1 + k * 0.12
        parts.append(ck.tube(n + "wrap%d" % k, g + up * (z - 0.015), g + up * (z + 0.015), 0.036, 0.036, mats["tint"], 8))
    parts.append(ck.tube(n + "collar", top - up * 0.03, top + up * 0.03, 0.05, 0.045, gold, 10))
    hc = top + up * 0.17
    S = 1.0 + tier * 0.08
    if el == "fire":               # garras segurando uma chama de cristal
        for k in range(4):
            a = math.tau * k / 4 + 0.4
            dd = side * math.cos(a) + fwd * math.sin(a)
            p1 = top + up * 0.08 + dd * 0.09 * S
            parts += [ck.tube(n + "claw%d_a" % k, top + up * 0.02, p1, 0.02, 0.016, gold, 6), ck.tube(n + "claw%d_b" % k, p1, hc + up * 0.06 + dd * 0.04, 0.016, 0.004, gold, 6)]
        parts.append(ck.blade(n + "flame", hc - up * 0.08, hc + up * 0.24 * S, 0.12 * S, 0.08, glow, side, 0.35))
        parts.append(ck.blade(n + "flame_b", hc - up * 0.06, hc + up * 0.15 * S + side * 0.04, 0.08 * S, 0.06, deep, fwd, 0.35))
    elif el == "frost":            # buquê de cristais
        for k in range(5):
            a = math.tau * k / 5
            dd = side * math.cos(a) + fwd * math.sin(a)
            parts.append(ck.tube(n + "shard%d" % k, top + up * 0.03 + dd * 0.02, hc + up * 0.08 * S + dd * 0.08 * S, 0.035 * S, 0.004, glow if k % 2 else deep, 6))
        parts.append(ck.tube(n + "core", top + up * 0.03, hc + up * 0.22 * S, 0.05 * S, 0.005, glow, 6))
    else:                          # anel com orbe e raios
        for i in range(14):
            a0, a1 = math.tau * i / 14, math.tau * (i + 1) / 14
            parts.append(ck.tube(n + "ring%d" % i, hc + (side * math.cos(a0) + up * math.sin(a0)) * 0.13 * S,
                                 hc + (side * math.cos(a1) + up * math.sin(a1)) * 0.13 * S, 0.016, 0.016, gold, 6))
        parts.append(ck.ball(n + "orb", 0.07 * S, hc, glow))
        for sx in (-1, 1):
            p0 = hc + side * sx * 0.13 * S
            p1 = p0 + side * sx * 0.06 + up * 0.06
            parts += [ck.tube(n + "bolt%d_a" % sx, p0, p1, 0.016, 0.012, glow, 5), ck.tube(n + "bolt%d_b" % sx, p1, p1 + side * sx * 0.02 + up * 0.08, 0.012, 0.002, glow, 5)]
    if glow2:                      # combinação: gema do segundo elemento presa no colar do cajado
        for sg in (-1, 1):
            parts.append(ck.ball(n + "gem2_%d" % sg, 0.035, top + fwd * sg * 0.055, glow2, (1, 0.6, 1.2)))
    obj = ck._join(parts, "wpn_main_staff_%s" % style)
    ck._smooth(obj.data)
    ck.skin_rigid(obj, base["rig"], "hand.R")
    return obj


def register(ck):
    import paladin_sets
    for style, cfg in ELE_SETS.items():
        ck.SET_STYLES[style] = (lambda st, cf: (lambda base, mats: (build(ck, base, mats, st, cf), paladin_sets.join_slots("arm_%s_" % st))))(style, cfg)
        ck.SET_WEAPONS[style + "_staff"] = (lambda st, cf: (lambda base, mats: build_staff(ck, base, mats, st, cf)))(style, cfg)
