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


# ---------------------------------------------------------------------------
# Ato II (níveis 35/40/45; no híbrido, a armadura da 1ª build do par): UM visual novo por build/elemento, tema guerra contra
# a Horda em Monte Kharzun. A malha é a mesma nos três níveis; muda a cor do item (tint), o destaque (tint2) e o brilho:
# o material "tint_glow" recebe no jogo a cor de GearCatalog.ACT2_VISUALS[...]["glows"][nível] (KitModel), sempre dentro da
# faixa do elemento (fogo: brasa -> chama -> branco quente; gelo: verde-água -> branco frio -> aurora; raio: âmbar -> ouro
# claro -> ciano). A forma diz o elemento principal; o SEGUNDO elemento (o "favor" herdado do conjunto 30: ACT2_SECOND)
# continua aparecendo como gemas fixas no broche e no colar do cajado.
#   ele_f35 Fogo = Forja Viva: braseiro de ferro na cabeça com chifres de chama, ombreiras de rocha com veios de magma,
#           avental de forja e anel de brasas flutuando atrás dos ombros.
#   ele_g35 Gelo = Geleira: coroa alta e torta de cristais, ombreiras de lascas de geleira (a direita maior), túnica em
#           três camadas com gola de pele e capa de lascas de gelo.
#   ele_r35 Raio = Para-raios: chapéu de aba larga com haste alta de anéis, hastes nos dois ombros, túnica de faixas e
#           mochila de bobinas com arco aceso por trás da cabeça.
GLOW_BASE = (1.0, 0.6, 0.2)           # cor só do .glb; o jogo pinta por nível
ACT2_SECOND = {"fire": SECOND["fire"][-1], "frost": SECOND["frost"][-1], "storm": SECOND["storm"][-1]}


def _act2_robe(ck, base, mats, P, el, bottom, flare, hem_n=14):
    """Túnica, calça, barra do elemento, cinto, mangas largas e botas comuns aos três visuais. Devolve os materiais."""
    import bpy
    import ranger_sets as rs
    V = Vector
    rig, body, b, j = base["rig"], base["body"], base["b"], base["j"]
    t, t2, wh = mats["tint"], mats["tint2"], mats["white"]
    glow = rs.tint_glow(ck)
    deep = ck.mat("m_ele_deep_%s" % el, DEEP[el], 0.5, 0.4)
    el2 = ACT2_SECOND[el]
    gem2 = ck.mat("m_ele_glow_%s" % el2, GLOW[el2], 0.3, 0.8)
    ck.armor_piece(body, rig, P + "body_robe", "torso", t, 0.014, 0.014, 0.03)
    ck.armor_piece(body, rig, P + "body_legs", "legs", deep, 0.008, 0.012)
    sk = ck.skirt(P + "body_skirt", b, body, rig, t, bottom, flare)
    hem = ck._join(_hem(ck, P + "body_hem", b, el, bottom, flare, glow, hem_n), P + "body_hem")
    ck.transfer_weights(hem, sk, rig)
    rs.body_belt(ck, base, P + "body_belt", ck.Z["waist"] - 0.04, ck.Z["waist"] + 0.035, 1.21, t2)
    for s in (".R", ".L"):
        tag = s.replace(".", "_")
        el_, wr = V(j["elbow" + s]), V(j["wrist" + s])
        g = [ck.tube(P + "gloves_sleeve" + tag, el_.lerp(wr, 0.25), wr + V((0, 0, -0.012)), 0.076, 0.112, t, 14),
             ck.tube(P + "gloves_cuff" + tag, wr + V((0, 0, 0.008)), wr + V((0, 0, -0.018)), 0.116, 0.116, glow, 14),
             ck.tube(P + "gloves_band" + tag, el_.lerp(wr, 0.3), el_.lerp(wr, 0.42), 0.086, 0.092, t2, 14)]
        ck._rigid(rs.outward(g), rig, "forearm" + s)
        ck._rigid([ck.ball(P + "gloves_fist" + tag, b["hand"] * 1.15, ck.hand_center(base, s), wh, (1, 1, 1.1))], rig, "hand" + s)
    ck.armor_piece(body, rig, P + "boots_shell", "boots", deep, 0.02, 0.014)
    for s in (".R", ".L"):
        tag = s.replace(".", "_")
        an = V(j["ankle" + s])
        ck._rigid([ck.tube(P + "boots_cuff" + tag, an + V((0, 0, 0.06)), an + V((0, 0, 0.095)), 0.082, 0.088, t2, 12),
                   ck.ball(P + "boots_gem" + tag, 0.022, an + V((0, -0.085, 0.075)), glow)], rig, "shin" + s)
    return glow, deep, gem2


def _act2_hair(ck, base, P):
    """Cabelo comprido da cor da classe por baixo de coroa/chapéu aberto."""
    import bpy
    V = Vector
    c, r = V(base["head_c"]), base["b"]["head"]
    hair = bpy.data.materials.get("hair") or bpy.data.materials.get("tint")
    out = [ck._shell(P + "head_hair", c + V((0, r * 0.04, r * 0.02)), r * 1.06, 0.25, -0.85, -0.25, 0.04, hair)]
    for sx in (-1, 0, 1):
        out.append(ck.strand(P + "head_lock%d" % sx, c + V((sx * r * 0.45, r * 0.75, -r * 0.1)), r * 1.15, r * 0.3, r * 0.22, hair, taper=0.9, lean=(sx * 0.1, 0.5)))
    return out


def build_forge(ck, base, mats, style):
    """ele_f35 — Forja Viva (Fogo)."""
    import ranger_sets as rs
    V = Vector
    rig, b, j = base["rig"], base["b"], base["j"]
    t, t2, gold, leather = mats["tint"], mats["tint2"], mats["trim"], mats["leather"]
    P = "arm_%s_" % style
    glow, deep, gem2 = _act2_robe(ck, base, mats, P, "fire", 0.075, 1.72)
    iron = ck.mat("m_ele_iron", (0.2, 0.18, 0.2), 0.5)
    c, r = V(base["head_c"]), b["head"]
    # ---------------- cabeça: braseiro de ferro no alto, brasas e labaredas, dois chifres de chama, diadema ----------------
    head = _act2_hair(ck, base, P)
    head += [ck.tube(P + "head_circlet", c + V((0, 0, r * 0.36)), c + V((0, 0, r * 0.48)), r * 1.12, r * 1.1, gold, 24),
             ck.ball(P + "head_gem", r * 0.13, c + V((0, -r * 1.14, r * 0.42)), gem2, (1, 0.6, 1.3)),
             ck.tube(P + "head_bowl", c + V((0, 0, r * 0.74)), c + V((0, 0, r * 1.2)), r * 0.72, r * 1.02, iron, 16),
             ck.tube(P + "head_bowl_rim", c + V((0, 0, r * 1.16)), c + V((0, 0, r * 1.26)), r * 1.06, r * 1.06, gold, 16),
             ck.ball(P + "head_coals", r * 0.94, c + V((0, 0, r * 1.2)), glow, (1.0, 1.0, 0.22))]
    for k in range(4):                   # pés do braseiro descendo até o diadema
        a = math.tau * k / 4 + math.pi / 4
        dv = V((math.cos(a), math.sin(a), 0))
        head.append(ck.tube(P + "head_leg_%d" % k, c + dv * r * 0.86 + V((0, 0, r * 0.95)), c + dv * r * 1.08 + V((0, 0, r * 0.44)), 0.026, 0.02, iron, 6))
    for k in range(5):                   # labaredas saindo do braseiro
        a = math.tau * k / 5 + 0.3
        dv = V((math.cos(a), math.sin(a), 0)) * (r * 0.5 if k else 0.0)
        hgt = r * (1.25 if k == 0 else 0.75 + 0.12 * (k % 2))
        head.append(ck.blade(P + "head_flame_%d" % k, c + dv + V((0, 0, r * 1.18)), c + dv * 1.15 + V((0, r * 0.08, r * 1.2 + hgt)), r * 0.52, r * 0.3,
                             glow if k % 2 == 0 else deep, (1, 0, 0) if k % 2 == 0 else (0, 1, 0), 0.3))
    for sx in (-1, 1):                   # chifres de chama: sobem das têmporas abrindo para fora
        p0 = c + V((sx * r * 1.0, -r * 0.1, r * 0.55))
        head += rs.curve(ck, P + "head_horn_%d" % sx, p0, c + V((sx * r * 1.75, r * 0.1, r * 1.85)), (sx * r * 0.42, 0, -r * 0.25), r * 0.2, glow, 5, 8, 0.006)
        head.append(ck.blade(P + "head_horn_fin_%d" % sx, p0 + V((sx * r * 0.2, 0, r * 0.1)), p0 + V((sx * r * 0.95, r * 0.25, r * 0.75)), r * 0.42, 0.03, deep, (0, 1, 0), 0.4))
        head.append(ck.tube(P + "head_horn_ring_%d" % sx, p0 - V((sx * r * 0.04, 0, 0.01)), p0 + V((sx * r * 0.1, 0, r * 0.08)), r * 0.25, r * 0.24, gold, 10))
    ck._rigid(rs.outward(head), rig, "head")
    # ---------------- corpo: avental de forja, broche de fornalha, gola de rocha com veios de magma ----------------
    d = b["depth"]
    front = -b["chest"] * d - 0.03
    back = b["chest"] * d + 0.03
    zc, zn, zw = ck.Z["chest"], ck.Z["neck"], ck.Z["waist"]
    chest = [ck.box(P + "body_bib", (0.2, 0.02, 0.2), (0, front - 0.004, zc - 0.03), leather, 0.01),
             ck.ball(P + "body_brooch", 0.045, (0, front - 0.02, zc + 0.03), glow, (1.0, 0.5, 1.2)),
             ck.ball(P + "body_brooch2", 0.024, (0, front - 0.022, zc - 0.06), gem2, (1, 0.6, 1.2))]
    for sx in (-1, 1):
        chest += [ck.ball(P + "body_rivet_%d" % sx, 0.018, (sx * 0.08, front - 0.016, zc + 0.05), gold),
                  ck.tube(P + "body_bib_strap_%d" % sx, (sx * 0.085, front, zc + 0.06), (sx * 0.1, front + 0.06, zn - 0.02), 0.016, 0.016, leather, 6)]
    rw = abs(V(j["shoulder.L"]).x) + b["arm"] * 0.9
    n = 12
    for k in range(n):                   # gola: pedras escuras com lava nas juntas
        a = math.tau * (k + 0.5) / n
        dv = V((math.cos(a), math.sin(a) * 0.84, 0))
        if dv.y < -0.7:
            continue
        chest.append(ck.ball(P + "body_rock_%d" % k, 0.085, dv * rw + V((0, 0, zn - 0.05)), iron, (1.0, 1.0, 0.7)))
        a2 = a + math.pi / n
        chest.append(ck.ball(P + "body_seam_%d" % k, 0.04, V((math.cos(a2), math.sin(a2) * 0.84, 0)) * rw * 1.04 + V((0, 0, zn - 0.055)), glow, (1.0, 1.0, 0.8)))
    # anel de brasas flutuando atrás dos ombros (plano em pé por fora da cabeça; de cima lê como um arco de chamas)
    R = 0.5
    dc = V((0, r * 1.25 + 0.03, zn + 0.22))
    for k in range(9):
        a = math.radians(-25 + k * 230.0 / 8.0)
        dv = V((math.cos(a), 0, math.sin(a)))
        p = dc + dv * R
        big = 1.0 + 0.3 * (k % 2 == 0)
        chest += [ck.blade(P + "body_ember_%d" % k, p - dv * 0.07 * big, p + dv * 0.15 * big, 0.11 * big, 0.05, glow if k % 2 == 0 else deep, V((-dv.z, 0, dv.x)), 0.35),
                  ck.ball(P + "body_ember_core_%d" % k, 0.03, p - dv * 0.085 * big, iron)]
    ck._rigid(rs.outward(chest), rig, "chest")
    wf = -b["waist"] * d * 1.21
    hips = [ck.blade(P + "body_apron", (0, wf - 0.012, zw + 0.0), (0, wf - 0.07, zw - 0.36), 0.25, 0.016, leather, (1, 0, 0), 0.75),
            ck.box(P + "body_buckle", (0.075, 0.025, 0.06), (0, wf - 0.022, zw), gold, 0.008),
            ck.ball(P + "body_buckle_core", 0.024, (0, wf - 0.04, zw), glow),
            ck.tube(P + "body_hammer_h", (0.14, wf * 0.75, zw - 0.02), (0.15, wf * 0.75 - 0.01, zw - 0.2), 0.012, 0.012, mats["wood"], 6),
            ck.box(P + "body_hammer", (0.05, 0.09, 0.05), (0.15, wf * 0.75 - 0.01, zw - 0.2), iron, 0.008)]
    ck._rigid(rs.outward(hips), rig, "hips")
    for s, sx in ((".R", -1), (".L", 1)):                 # ombreiras de rocha com veios acesos e duas pontas
        tag = s.replace(".", "_")
        sh = V(j["shoulder" + s])
        pa = [ck.ball(P + "body_pad" + tag, b["arm"] * 3.1, sh + V((sx * 0.06, 0, 0.06)), iron, (1.15, 1.15, 0.62)),
              ck.ball(P + "body_pad_rim" + tag, b["arm"] * 3.2, sh + V((sx * 0.06, 0, 0.02)), t2, (1.16, 1.16, 0.16))]
        for k in range(3):               # veios: riscos em zigue-zague por cima da pedra
            y = (k - 1) * 0.085
            q0 = sh + V((sx * -0.03, y, 0.165 - abs(k - 1) * 0.03))
            q1 = sh + V((sx * 0.09, y + 0.03, 0.17 - abs(k - 1) * 0.035))
            q2 = sh + V((sx * 0.21, y - 0.01, 0.105 - abs(k - 1) * 0.03))
            pa += [ck.tube(P + "body_vein%d_a%s" % (k, tag), q0, q1, 0.016, 0.016, glow, 5), ck.tube(P + "body_vein%d_b%s" % (k, tag), q1, q2, 0.016, 0.012, glow, 5)]
        for k, fy in enumerate((-1, 1)):
            pa.append(ck.tube(P + "body_spur%d%s" % (k, tag), sh + V((sx * 0.14, fy * 0.07, 0.1)), sh + V((sx * 0.3, fy * 0.12, 0.24)), 0.045, 0.004, iron, 6))
        ck._rigid(rs.outward(pa), rig, "upper_arm" + s)


def build_glacier(ck, base, mats, style):
    """ele_g35 — Geleira (Gelo)."""
    import ranger_sets as rs
    V = Vector
    rig, body, b, j = base["rig"], base["body"], base["b"], base["j"]
    t, t2, wh = mats["tint"], mats["tint2"], mats["white"]
    P = "arm_%s_" % style
    glow, deep, gem2 = _act2_robe(ck, base, mats, P, "frost", 0.07, 1.78, 16)
    ck.skirt(P + "body_tier2", b, body, rig, t2, 0.2, 1.6)          # túnica em camadas
    ck.skirt(P + "body_tier3", b, body, rig, wh, 0.36, 1.36)
    c, r = V(base["head_c"]), b["head"]
    # ---------------- cabeça: aro branco e coroa de cristais, alta e torta (pico à esquerda, atrás) ----------------
    head = _act2_hair(ck, base, P)
    head += [ck.tube(P + "head_circlet", c + V((0, 0, r * 0.38)), c + V((0, 0, r * 0.52)), r * 1.12, r * 1.1, wh, 24),
             ck.ball(P + "head_gem", r * 0.13, c + V((0, -r * 1.14, r * 0.45)), gem2, (1, 0.6, 1.3))]
    n = 11
    peak = math.radians(35)              # ângulo do pico (x+ = esquerda do personagem, y+ = costas)
    for k in range(n):
        a = math.tau * k / n + 0.2
        dv = V((math.cos(a), math.sin(a), 0))
        w = max(0.0, math.cos(a - peak)) ** 2
        hgt = r * (0.5 + 1.5 * w)
        lean = V((math.cos(peak), math.sin(peak), 0)) * r * 0.35 * w
        head.append(ck.tube(P + "head_shard_%d" % k, c + dv * r * 1.02 + V((0, 0, r * 0.42)), c + dv * r * 1.22 + lean + V((0, 0, r * 0.45 + hgt)),
                            r * (0.15 + 0.12 * w), r * 0.01, glow if k % 2 == 0 else deep, 6))
    pk = V((math.cos(peak), math.sin(peak), 0))
    for k in range(4):                   # lascas no alto da cabeça, tombando para o pico (de cima a coroa não fica só cabelo)
        a = math.tau * k / 4 + 0.6
        dv = V((math.cos(a), math.sin(a), 0)) * (r * 0.3 if k else 0.0)
        head.append(ck.tube(P + "head_spire_%d" % k, c + dv + pk * r * 0.2 + V((0, 0, r * 0.9)), c + dv * 1.9 + pk * r * (0.55 if k else 0.75) + V((0, 0, r * (1.5 if k else 2.0))),
                            r * (0.2 if k else 0.28), r * 0.01, deep if k % 2 else glow, 6))
    ck._rigid(rs.outward(head), rig, "head")
    # ---------------- corpo: gola de pele, broche, capa de lascas de gelo ----------------
    d = b["depth"]
    front = -b["chest"] * d - 0.03
    back = b["chest"] * d + 0.03
    zc, zn, zw = ck.Z["chest"], ck.Z["neck"], ck.Z["waist"]
    chest = [ck.box(P + "body_panel", (0.09, 0.015, 0.24), (0, front, zc - 0.04), t2, 0.004),
             ck.ball(P + "body_brooch", 0.042, (0, front - 0.016, zc + 0.08), glow, (0.9, 0.5, 1.4)),
             ck.ball(P + "body_brooch2", 0.024, (0, front - 0.018, zc - 0.01), gem2, (1, 0.6, 1.2))]
    rw = abs(V(j["shoulder.L"]).x) + b["arm"] * 0.8
    chest += rs.fur_ring(ck, P + "body_fur", (0, 0, zn - 0.045), rw, 16, 0.085, wh, 0.02, 0.86)
    n = 7                                # capa: lascas compridas penduradas dos ombros, a do meio mais longa
    for k in range(n):
        x = (k - (n - 1) / 2.0) * 0.085
        L = 0.62 - abs(k - (n - 1) / 2.0) * 0.085
        y0 = back + 0.045 + (0.02 if k % 2 else 0.0)
        chest.append(ck.blade(P + "body_cape_%d" % k, (x, y0, zn - 0.05), (x * 1.75, y0 + 0.13, zn - 0.05 - L), 0.13, 0.05, glow if k % 2 else deep, (1, 0, 0), 0.3))
    ck._rigid(rs.outward(chest), rig, "chest")
    wf = -b["waist"] * d * 1.21
    hips = [ck.tube(P + "body_buckle", (0, wf + 0.01, zw), (0, wf - 0.03, zw), 0.06, 0.05, wh, 6),
            ck.ball(P + "body_buckle_core", 0.03, (0, wf - 0.034, zw), glow, (1.0, 0.5, 1.0))]
    for sx in (-1, 1):
        hips.append(ck.tube(P + "body_icicle_%d" % sx, (sx * 0.1, wf * 0.95, zw - 0.03), (sx * 0.11, wf * 0.97, zw - 0.2), 0.026, 0.003, glow, 6))
    ck._rigid(rs.outward(hips), rig, "hips")
    for s, sx in ((".R", -1), (".L", 1)):                 # ombreiras de lascas de geleira (a direita maior, a coroa pende para a esquerda)
        tag = s.replace(".", "_")
        sh = V(j["shoulder" + s])
        S = 1.3 if sx < 0 else 0.95
        pa = rs.fur_ring(ck, P + "body_pfur" + tag, sh + V((sx * 0.04, 0, 0.02)), 0.085, 7, 0.06, wh, 0.02, 1.0)
        for k in range(4):
            fy = (k - 1.5) * 0.06
            up = 0.3 - abs(k - 1.5) * 0.07
            pa.append(ck.tube(P + "body_shard%d%s" % (k, tag), sh + V((sx * 0.04, fy * 0.7, 0.03)), sh + V((sx * (0.15 + 0.05 * (k % 2)) * S, fy * 1.6 * S, up * S)),
                              0.055 * S, 0.004, glow if k % 2 else deep, 6))
        ck._rigid(rs.outward(pa), rig, "upper_arm" + s)


def build_rod(ck, base, mats, style):
    """ele_r35 — Para-raios (Raio)."""
    import ranger_sets as rs
    V = Vector
    rig, body, b, j = base["rig"], base["body"], base["b"], base["j"]
    t, t2, gold, dark, leather = mats["tint"], mats["tint2"], mats["trim"], mats["dark"], mats["leather"]
    P = "arm_%s_" % style
    bottom, flare = 0.075, 1.72
    glow, deep, gem2 = _act2_robe(ck, base, mats, P, "storm", bottom, flare)
    copper = ck.mat("m_ele_copper", (0.78, 0.45, 0.25), 0.35)
    c, r = V(base["head_c"]), b["head"]
    d = b["depth"]
    for k in range(3):                   # faixas na saia (acompanham a barra)
        tt = 0.35 + k * 0.24
        z = (ck.Z["waist"] - 0.02) + (bottom - (ck.Z["waist"] - 0.02)) * tt
        rr = b["waist"] * 1.18 * (1.0 + (flare - 1.0) * tt ** 1.2) + 0.03
        band = ck.tube(P + "body_band_%d" % k, (0, 0, z - 0.018), (0, 0, z + 0.018), rr * 1.02, rr * 0.99, t2 if k != 1 else deep, 16)
        for v in band.data.vertices:
            v.co.y *= d * 1.05
        ck._smooth(band.data)
        ck.transfer_weights(band, body, rig)
    # ---------------- cabeça: chapéu de aba larga, copa baixa, haste alta com três anéis e esfera acesa ----------------
    head = _act2_hair(ck, base, P)
    head += [ck.tube(P + "head_brim", c + V((0, 0, r * 0.5)), c + V((0, 0, r * 0.57)), r * 1.62, r * 1.56, t, 28),
             ck.tube(P + "head_brim_edge", c + V((0, 0, r * 0.49)), c + V((0, 0, r * 0.53)), r * 1.66, r * 1.66, t2, 28),
             ck._shell(P + "head_crown", c + V((0, 0, r * 0.2)), r * 0.98, 0.5, 0.3, 0.35, 0.035, t),
             ck.tube(P + "head_band", c + V((0, 0, r * 0.58)), c + V((0, 0, r * 0.72)), r * 1.0, r * 0.98, t2, 20),
             ck.ball(P + "head_gem", r * 0.13, c + V((0, -r * 1.0, r * 0.65)), gem2, (1, 0.6, 1.3))]
    p0, p1 = c + V((0, 0, r * 1.1)), c + V((0, r * 0.1, r * 2.25))
    head += [ck.tube(P + "head_rod", p0, p1, 0.036, 0.022, gold, 8),
             ck.tube(P + "head_rod_base", p0 - V((0, 0, 0.02)), p0 + V((0, 0, 0.07)), r * 0.3, r * 0.16, copper, 10),
             ck.ball(P + "head_rod_orb", r * 0.24, p1 + V((0, 0, r * 0.12)), glow)]
    for k in range(3):                   # anéis (discos) diminuindo para cima
        q = p0.lerp(p1, 0.28 + k * 0.24)
        head.append(ck.tube(P + "head_ring_%d" % k, q - V((0, 0, 0.016)), q + V((0, 0, 0.016)), r * (0.52 - k * 0.12), r * (0.52 - k * 0.12), copper if k % 2 == 0 else gold, 12))
    for sx in (-1, 1):                   # faíscas na esfera
        q = p1 + V((sx * r * 0.2, 0, r * 0.16))
        q1 = q + V((sx * r * 0.28, 0, r * 0.2))
        head += [ck.tube(P + "head_bolt%d_a" % sx, q, q1, 0.02, 0.016, glow, 5), ck.tube(P + "head_bolt%d_b" % sx, q1, q1 + V((sx * r * 0.05, 0, r * 0.36)), 0.016, 0.003, glow, 5)]
    ck._rigid(rs.outward(head), rig, "head")
    # ---------------- corpo: painel, broche, mochila de bobinas com arco por trás da cabeça ----------------
    front = -b["chest"] * d - 0.03
    back = b["chest"] * d + 0.03
    zc, zn, zw = ck.Z["chest"], ck.Z["neck"], ck.Z["waist"]
    chest = [ck.box(P + "body_panel", (0.09, 0.015, 0.24), (0, front, zc - 0.04), t2, 0.004),
             ck.ball(P + "body_brooch", 0.042, (0, front - 0.016, zc + 0.08), glow, (1, 0.6, 1.2)),
             ck.ball(P + "body_brooch2", 0.024, (0, front - 0.018, zc - 0.01), gem2, (1, 0.6, 1.2)),
             ck.box(P + "body_pack", (0.26, 0.11, 0.24), (0, back + 0.055, zc + 0.0), leather, 0.02),
             ck.box(P + "body_pack_plate", (0.16, 0.03, 0.12), (0, back + 0.115, zc + 0.01), copper, 0.01),
             ck.ball(P + "body_pack_core", 0.04, (0, back + 0.135, zc + 0.01), glow, (1.0, 0.5, 1.0))]
    for k in range(7):                   # gola alta aberta na frente
        a = math.pi * (0.1 + 0.8 * k / 6)
        p = V((math.cos(a) * b["chest"] * 0.55, math.sin(a) * b["chest"] * 0.5, zn - 0.02))
        chest.append(ck.blade(P + "body_collar%d" % k, p, p + V((math.cos(a) * 0.04, math.sin(a) * 0.04, 0.11)), 0.07, 0.012, t2, (-math.sin(a), math.cos(a), 0), 0.5))
    tops = []
    for sx in (-1, 1):                   # bobinas: núcleo que sobe por fora da cabeça, anéis de cobre, esfera acesa
        q0 = V((sx * 0.1, back + 0.09, zc + 0.1))
        q1 = V((sx * r * 1.42, r * 0.95, c.z + r * 0.75))
        ax = (q1 - q0).normalized()
        chest.append(ck.tube(P + "body_coil_core_%d" % sx, q0, q1, 0.026, 0.02, dark, 6))
        for k in range(6):
            q = q0.lerp(q1, 0.3 + k * 0.115)
            chest.append(ck.tube(P + "body_coil_%d_%d" % (sx, k), q - ax * 0.014, q + ax * 0.014, 0.062 - k * 0.004, 0.062 - k * 0.004, copper, 10))
        chest.append(ck.ball(P + "body_coil_orb_%d" % sx, 0.058, q1 + ax * 0.04, glow))
        tops.append(q1 + ax * 0.04)
    arc = [tops[0].lerp(tops[1], k / 6.0) + V((0, 0.03 * (-1) ** k, r * (0.55 * math.sin(math.pi * k / 6.0) + 0.1 * (-1) ** k * (0 < k < 6)))) for k in range(7)]
    for k in range(6):                   # arco elétrico em zigue-zague entre as bobinas, por cima e por trás da cabeça
        chest.append(ck.tube(P + "body_arc_%d" % k, arc[k], arc[k + 1], 0.02, 0.02, glow, 5))
    ck._rigid(rs.outward(chest), rig, "chest")
    wf = -b["waist"] * d * 1.21
    hips = [ck.box(P + "body_buckle", (0.07, 0.025, 0.06), (0, wf - 0.012, zw), copper, 0.008),
            ck.ball(P + "body_buckle_core", 0.024, (0, wf - 0.03, zw), glow),
            ck.blade(P + "body_sash", (0.06, wf - 0.008, zw - 0.02), (0.09, wf - 0.06, zw - 0.32), 0.075, 0.012, t2, (1, 0, 0), 0.3)]
    ck._rigid(rs.outward(hips), rig, "hips")
    for s, sx in ((".R", -1), (".L", 1)):                 # ombros: calota e haste para-raios com dois anéis e esfera acesa
        tag = s.replace(".", "_")
        sh = V(j["shoulder" + s])
        q0, q1 = sh + V((sx * 0.06, 0, 0.08)), sh + V((sx * 0.2, 0.02, 0.4))
        pa = [ck.ball(P + "body_pad" + tag, b["arm"] * 2.4, sh + V((sx * 0.05, 0, 0.05)), t2, (1.12, 1.08, 0.55)),
              ck.ball(P + "body_pad_rim" + tag, b["arm"] * 2.48, sh + V((sx * 0.05, 0, 0.025)), copper, (1.14, 1.1, 0.14)),
              ck.tube(P + "body_srod" + tag, q0, q1, 0.024, 0.016, gold, 6),
              ck.ball(P + "body_sorb" + tag, 0.045, q1 + V((0, 0, 0.03)), glow)]
        for k in range(2):
            q = q0.lerp(q1, 0.4 + k * 0.3)
            pa.append(ck.tube(P + "body_sring%d%s" % (k, tag), q - V((0, 0, 0.012)), q + V((0, 0, 0.012)), 0.07 - k * 0.02, 0.07 - k * 0.02, copper, 10))
        ck._rigid(rs.outward(pa), rig, "upper_arm" + s)


def build_staff2(ck, base, mats, style, el):
    """Cajados do Ato II: braseiro de forja (fogo), lança de geleira (gelo), para-raios (raio). Brilho = tint_glow."""
    import ranger_sets as rs
    V = Vector
    g = V(ck.hand_center(base, ".R"))
    up = V((-0.22, -0.12, 1.0)).normalized()
    side = V((1, 0, 0))
    fwd = up.cross(side).normalized()
    glow = rs.tint_glow(ck)
    deep = ck.mat("m_ele_deep_%s" % el, DEEP[el], 0.5, 0.4)
    gem2 = ck.mat("m_ele_glow_%s" % ACT2_SECOND[el], GLOW[ACT2_SECOND[el]], 0.3, 0.8)
    iron = ck.mat("m_ele_iron", (0.2, 0.18, 0.2), 0.5)
    copper = ck.mat("m_ele_copper", (0.78, 0.45, 0.25), 0.35)
    gold, t, t2, wh = mats["trim"], mats["tint"], mats["tint2"], mats["white"]
    n = "es_%s_" % style
    ln = 1.45
    bot, top = g - up * ln * 0.42, g + up * ln * 0.58
    parts = [ck.tube(n + "shaft", bot, top, 0.031, 0.029, mats["dark"], 8),
             ck.tube(n + "foot", bot - up * 0.06, bot + up * 0.03, 0.012, 0.036, gold, 8)]
    for k in range(4):
        z = 0.1 + k * 0.12
        parts.append(ck.tube(n + "wrap%d" % k, g + up * (z - 0.016), g + up * (z + 0.016), 0.038, 0.038, t if k % 2 == 0 else t2, 8))
    parts.append(ck.tube(n + "collar", top - up * 0.035, top + up * 0.035, 0.056, 0.05, gold, 10))
    for sg in (-1, 1):                   # segundo elemento: gemas no colar
        parts.append(ck.ball(n + "gem2_%d" % sg, 0.036, top + fwd * sg * 0.062, gem2, (1, 0.6, 1.2)))
    hc = top + up * 0.2

    def ring(tag, ctr, rad, thick, material, segs=12):
        return [ck.tube(n + "%s%d" % (tag, i), ctr + (side * math.cos(math.tau * i / segs) + fwd * math.sin(math.tau * i / segs)) * rad,
                        ctr + (side * math.cos(math.tau * (i + 1) / segs) + fwd * math.sin(math.tau * (i + 1) / segs)) * rad, thick, thick, material, 5) for i in range(segs)]

    if el == "fire":               # cesto de ferro (braseiro) com brasa e labareda, corrente com brasa pendurada
        for k in range(5):
            a = math.tau * k / 5
            dd = side * math.cos(a) + fwd * math.sin(a)
            parts += rs.curve(ck, n + "bar%d" % k, top + up * 0.02, top + up * 0.26 + dd * 0.15, dd * 0.05 - up * 0.04, 0.02, iron, 3, 5, 0.014)
        parts += ring("rim", top + up * 0.26, 0.15, 0.02, gold)
        parts += [ck.ball(n + "coal", 0.11, top + up * 0.2, glow, (1, 1, 0.8)),
                  ck.blade(n + "flame", top + up * 0.2, top + up * 0.62, 0.2, 0.12, glow, side, 0.32),
                  ck.blade(n + "flame_b", top + up * 0.22, top + up * 0.5 + side * 0.07, 0.13, 0.09, deep, fwd, 0.35),
                  ck.blade(n + "flame_c", top + up * 0.22, top + up * 0.46 - side * 0.08, 0.11, 0.08, deep, fwd, 0.35),
                  ck.tube(n + "chain", top - up * 0.02 + side * 0.05, top - up * 0.17 + side * 0.09, 0.008, 0.008, iron, 4),
                  ck.ball(n + "ember", 0.034, top - up * 0.19 + side * 0.09, glow)]
    elif el == "frost":            # um cristal enorme, duas lascas abertas, anel de lascas pequenas flutuando
        parts += rs.fur_ring(ck, n + "fur", top + up * 0.03, 0.05, 6, 0.04, wh, 0.01, 1.0)
        parts += [ck.blade(n + "crystal", top + up * 0.02, top + up * 0.66, 0.19, 0.13, glow, side, 0.3),
                  ck.blade(n + "crystal_b", top + up * 0.02, top + up * 0.5, 0.13, 0.17, deep, fwd, 0.3)]
        for sx in (-1, 1):
            parts.append(ck.blade(n + "wing%d" % sx, top + up * 0.03, top + up * 0.34 + side * sx * 0.2, 0.1, 0.07, deep, fwd, 0.3))
        for k in range(6):
            a = math.tau * k / 6 + 0.3
            dd = side * math.cos(a) + fwd * math.sin(a)
            q = top + up * (0.3 + 0.03 * (k % 2)) + dd * 0.24
            parts.append(ck.tube(n + "float%d" % k, q - up * 0.05, q + up * 0.08, 0.026, 0.003, glow if k % 2 else deep, 5))
    else:                          # haste de para-raios: três anéis diminuindo, garfo de duas pontas, esfera acesa, faíscas
        parts.append(ck.tube(n + "rod", top, top + up * 0.6, 0.02, 0.012, gold, 6))
        for k in range(3):
            parts += ring("ring%d_" % k, top + up * (0.1 + k * 0.13), 0.14 - k * 0.035, 0.016, copper if k % 2 == 0 else gold, 10)
            for sg in (-1, 1):
                parts.append(ck.tube(n + "spoke%d_%d" % (k, sg), top + up * (0.1 + k * 0.13), top + up * (0.1 + k * 0.13) + side * sg * (0.14 - k * 0.035), 0.008, 0.008, copper, 4))
        parts.append(ck.ball(n + "orb", 0.085, top + up * 0.55, glow))
        for sx in (-1, 1):
            parts += rs.curve(ck, n + "prong%d" % sx, top + up * 0.4, top + up * 0.72 + side * sx * 0.1, side * sx * 0.07, 0.018, gold, 3, 5, 0.004)
            q0 = top + up * 0.57 + side * sx * 0.09
            q1 = q0 + side * sx * 0.09 + up * 0.05
            parts += [ck.tube(n + "bolt%d_a" % sx, q0, q1, 0.016, 0.012, glow, 5), ck.tube(n + "bolt%d_b" % sx, q1, q1 + side * sx * 0.02 + up * 0.12, 0.012, 0.002, glow, 5)]
    obj = ck._join(rs.outward(parts), "wpn_main_staff_%s" % style)
    ck._smooth(obj.data)
    ck.skin_rigid(obj, base["rig"], "hand.R")
    return obj


ACT2_SETS = {"ele_f35": ("fire", build_forge), "ele_g35": ("frost", build_glacier), "ele_r35": ("storm", build_rod)}


def register(ck):
    import paladin_sets
    for style, (el, fn) in ACT2_SETS.items():                # Ato II: um visual novo por build (35/40/45; híbridos pela 1ª build)
        ck.SET_STYLES[style] = (lambda st, f: (lambda base, mats: (f(ck, base, mats, st), paladin_sets.join_slots("arm_%s_" % st))))(style, fn)
        ck.SET_WEAPONS[style + "_staff"] = (lambda st, e: (lambda base, mats: build_staff2(ck, base, mats, st, e)))(style, el)
    for style, cfg in ELE_SETS.items():
        ck.SET_STYLES[style] = (lambda st, cf: (lambda base, mats: (build(ck, base, mats, st, cf), paladin_sets.join_slots("arm_%s_" % st))))(style, cfg)
        ck.SET_WEAPONS[style + "_staff"] = (lambda st, cf: (lambda base, mats: build_staff(ck, base, mats, st, cf)))(style, cfg)


# ---------------------------------------------------------------------------
# Ato III (nível 50, GDD ato3-lendarios-50): UM visual novo por build no tema de Lumeria. Malhas no kit extra
# kit_elementalist_<sexo>_a3.glb (chibi_kit.A3_STYLES); motivos comuns em lumeria_kit.py. Função simples (sem o par
# (elemento, fn) de ACT2_SETS): o 2º elemento não entra no visual do 50.
#   ele_f50 Fogo = Lanterna do Fim da Festa: coroa-lanterna alta (UMA lanterna grande acesa no alto da cabeça, sustentada
#           por quatro braços de ouro, e duas pequenas pendendo dos lados), meia-máscara de porcelana com lágrima de brasa,
#           manto em fitas de seda (tint2, laranja-brasa) caindo da gola pelas costas e pelos ombros, lanterna em cada ombro.
def build_feast_end_lantern(ck, base, mats, style):
    """ele_f50 — Lanterna do Fim da Festa (Fogo)."""
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
    ck.armor_piece(body, rig, P + "body_robe", "torso", t, 0.014, 0.014, 0.03)
    ck.armor_piece(body, rig, P + "body_legs", "legs", porc, 0.008, 0.012)
    ck.skirt(P + "body_skirt", b, body, rig, t, 0.075, 1.72)
    bs._belt(ck, base, P + "body_belt", zw - 0.04, zw + 0.035, 1.21, t2)
    # ---------------- cabeça: cabelo solto, aro de ouro, lanterna grande no alto, duas pendentes, meia-máscara ----------------
    head = _act2_hair(ck, base, P)
    head.append(ck.tube(P + "head_ring", c + V((0, 0, r * 0.5)), c + V((0, 0, r * 0.66)), r * 1.1, r * 1.01, gold, 20))
    lc = c + V((0, 0, r * 1.72))
    ls_ = r * 0.44
    head += lk.lantern(ck, P + "head_lantern", lc, ls_, M, segs=8)
    for k in range(4):                   # braços de ouro: do aro até o pé da lanterna, em arco
        a = math.tau * (k + 0.5) / 4
        dv = V((math.cos(a), math.sin(a), 0))
        p0, p1, p2 = c + dv * r * 1.03 + V((0, 0, r * 0.6)), c + dv * r * 0.82 + V((0, 0, r * 1.06)), lc + dv * ls_ * 0.5 + V((0, 0, -ls_ * 0.95))
        head += [ck.tube(P + "head_arm%d_a" % k, p0, p1, r * 0.06, r * 0.05, gold, 5), ck.tube(P + "head_arm%d_b" % k, p1, p2, r * 0.05, r * 0.045, gold, 5),
                 ck.blade(P + "head_flame%d" % k, p0 + V((0, 0, r * 0.02)), p0 + dv * r * 0.22 + V((0, 0, r * 0.52)), r * 0.24, r * 0.07, gold, (-dv.y, dv.x, 0), 0.35)]
    for sx in (-1, 1):                   # lanterninhas pendentes dos lados do aro
        hp_ = c + V((sx * r * 1.1, -r * 0.05, r * 0.52))
        head += lk.lantern(ck, P + "head_side_lantern%d" % sx, hp_ + V((sx * r * 0.1, 0, -r * 0.48)), r * 0.17, M, hang=hp_)
    head += lk.mask(ck, P + "head_mask", c + V((0, -r * 0.97, -r * 0.1)), r * 0.52, M, tears=(1,), wide=1.5, tall=0.62, tear_len=0.42, eye_z=-0.08)
    ck._rigid(bs._outward(head), rig, "head")
    # ---------------- corpo: gola de ouro, manto em fitas, estola ----------------
    chest = [ck.tube(P + "body_collar", V((0, 0, zn - 0.07)), V((0, 0, zn + 0.02)), b["chest"] * 0.82, b["chest"] * 0.52, gold, 16),
             ck.ball(P + "body_brooch", 0.04, (0, front - 0.02, zn - 0.09), glow, (1, 0.6, 1.2))]
    n = 7
    for k in range(n):                   # manto: sete fitas em leque das costas aos ombros, pontas em alturas alternadas
        a = math.radians(-96 + k * 32)
        p0 = V((math.sin(a) * b["chest"] * 0.8, 0.02 + math.cos(a) * (back - 0.04), zn - 0.04))
        p1 = V((math.sin(a) * (b["shoulder"] + 0.22), 0.05 + math.cos(a) * (back + 0.2), zw - 0.08 + (0.1 if k % 2 else 0.0) + abs(k - 3) * 0.035))
        chest.append(lk.silk(ck, P + "body_mantle%d" % k, p0, p1, (math.cos(a), -math.sin(a) * 0.7, 0), 0.13, 0.19, t2, (math.sin(a) * 0.03, math.cos(a) * 0.04, 0), 4))
        chest.append(ck.ball(P + "body_mantle_tip%d" % k, 0.022, p1 + V((0, 0, -0.01)), gold))
    ck._rigid(bs._outward(chest), rig, "chest")
    wf = -b["waist"] * d * 1.22
    stole = [lk.silk(ck, P + "body_stole%d" % sx, (sx * 0.06, wf - 0.022, zw - 0.02), (sx * 0.085, wf - 0.1, zw - 0.4), (1, 0, 0), 0.09, 0.11, t2, (0, -0.012, 0), 3) for sx in (-1, 1)]
    stole += [ck.ball(P + "body_buckle", 0.042, (0, wf - 0.014, zw), porc, (1.1, 0.5, 1.1)),
              ck.ball(P + "body_buckle_tear", 0.018, (0, wf - 0.036, zw - 0.008), glow, (0.8, 0.6, 1.7))]
    ck._rigid(bs._outward(stole), rig, "hips")
    for s, sx in ((".R", -1), (".L", 1)):                 # ombros: pires de ouro com uma lanterna de pé
        tag = s.replace(".", "_")
        sh = V(j["shoulder" + s])
        pc = sh + V((sx * 0.1, 0, 0.0))
        pa = lk.saucers(ck, P + "body_dish" + tag, pc, b["arm"] * 2.5, 1, M, 0.05, 0.2, (sx * 0.4, 0, 1), [porc])
        pa += lk.lantern(ck, P + "body_lantern" + tag, pc + V((sx * 0.07, 0, 0.14)), 0.075, M)
        ck._rigid(bs._outward(pa), rig, "upper_arm" + s)
    lk.limbs(ck, base, mats, P, M, "cloth", boots_m=porc)



#   ele_g50 Gelo = Espelho da Geada: coroa de sete cristais-espelho em LEQUE (de orelha a orelha, inclinada para trás),
#           espelho redondo na testa, meia-máscara com lágrima, ombreiras de cacos de vidro, manto de seda (tint2,
#           branco-azulado) em cinco panos largos pelas costas.
def build_frost_mirror(ck, base, mats, style):
    """ele_g50 — Espelho da Geada (Gelo)."""
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
    # ---------------- túnica ----------------
    ck.armor_piece(body, rig, P + "body_robe", "torso", t, 0.014, 0.014, 0.03)
    ck.armor_piece(body, rig, P + "body_legs", "legs", porc, 0.008, 0.012)
    ck.skirt(P + "body_skirt", b, body, rig, t, 0.075, 1.72)
    bs._belt(ck, base, P + "body_belt", zw - 0.04, zw + 0.035, 1.21, t2)
    # ---------------- cabeça: cabelo solto, aro, leque de cristais, espelho na testa, meia-máscara ----------------
    head = _act2_hair(ck, base, P)
    head.append(ck.tube(P + "head_ring", c + V((0, 0, r * 0.5)), c + V((0, 0, r * 0.66)), r * 1.1, r * 1.01, gold, 20))
    for k in range(7):
        a = math.radians(-81 + k * 27)
        q = abs(k - 3) / 3.0
        dv = V((math.sin(a), 0.38, math.cos(a))).normalized()
        root = c + V((math.sin(a) * r * 0.82, r * 0.12, r * 0.42 + math.cos(a) * r * 0.5))
        ln = r * (1.55 - 0.55 * q)
        wd = V((math.cos(a), 0, -math.sin(a)))
        head += [ck.blade(P + "head_crystal%d" % k, root, root + dv * ln, r * 0.46, r * 0.12, glass, wd, 0.3),
                 ck.blade(P + "head_crystal_back%d" % k, root + V((0, r * 0.07, 0)), root + V((0, r * 0.07, 0)) + dv * ln * 0.8, r * 0.6, r * 0.07, gold, wd, 0.3)]
        if k < 6:                        # lasca curta acesa entre dois cristais
            a2 = math.radians(-81 + (k + 0.5) * 27)
            r2 = c + V((math.sin(a2) * r * 0.86, r * 0.02, r * 0.42 + math.cos(a2) * r * 0.54))
            head.append(ck.blade(P + "head_shard%d" % k, r2, r2 + V((math.sin(a2), 0.3, math.cos(a2))).normalized() * r * 0.5, r * 0.18, r * 0.08, glow, (math.cos(a2), 0, -math.sin(a2)), 0.35))
    head += lk.mirror(ck, P + "head_brow_mirror", c + V((0, -r * 0.93, r * 0.62)), r * 0.2, M, facing=(0, -1, 0.5))
    head += lk.mask(ck, P + "head_mask", c + V((0, -r * 0.97, -r * 0.1)), r * 0.52, M, tears=(-1,), wide=1.5, tall=0.62, tear_len=0.42, eye_z=-0.08)
    ck._rigid(bs._outward(head), rig, "head")
    # ---------------- corpo: gola de ouro, broche-espelho, manto em panos ----------------
    chest = [ck.tube(P + "body_collar", V((0, 0, zn - 0.07)), V((0, 0, zn + 0.02)), b["chest"] * 0.82, b["chest"] * 0.52, gold, 16)]
    chest += lk.mirror(ck, P + "body_brooch", (0, front - 0.03, zn - 0.09), 0.05, M, tear=True)
    ck._rigid(bs._outward(chest), rig, "chest")
    mantle = []
    for k in range(5):                   # manto: cinco panos largos da gola até a barriga da perna (pesos do corpo)
        q = (k - 2) / 2.0
        p0 = V((q * b["chest"] * 0.95, back + 0.02 - abs(q) * 0.07, zn - 0.04))
        p1 = V((q * 0.5, back + 0.34 - abs(q) * 0.14, 0.2 + abs(q) * 0.16))
        mantle.append(lk.silk(ck, P + "body_mantle%d" % k, p0, p1, (1, -q * 0.5, 0), 0.15, 0.24, t2, (0, 0.05, 0), 6, 0.016))
    lk.skinned(ck, base, bs._outward(mantle))
    stole = [lk.silk(ck, P + "body_stole%d" % sx, (sx * 0.06, wf - 0.022, zw - 0.02), (sx * 0.085, wf - 0.1, zw - 0.4), (1, 0, 0), 0.09, 0.11, t2, (0, -0.012, 0), 3) for sx in (-1, 1)]
    stole += lk.mirror(ck, P + "body_buckle", (0, wf - 0.02, zw), 0.042, M)
    ck._rigid(bs._outward(stole), rig, "hips")
    for s, sx in ((".R", -1), (".L", 1)):                 # ombreiras de vidro: pires de porcelana com cinco cacos em pé, abrindo para fora
        tag = s.replace(".", "_")
        sh = V(j["shoulder" + s])
        pc = sh + V((sx * 0.09, 0, 0.0))
        pa = lk.saucers(ck, P + "body_dish" + tag, pc, b["arm"] * 2.7, 1, M, 0.05, 0.2, (sx * 0.4, 0, 1), [porc])
        for k in range(5):
            a = math.radians(-70 + k * 35)
            root = pc + V((sx * 0.02, math.sin(a) * 0.07, 0.03))
            tip = root + V((sx * (0.12 + math.cos(a) * 0.14), math.sin(a) * 0.17, 0.2 - abs(k - 2) * 0.045))
            pa.append(ck.blade(P + "body_glass%d%s" % (k, tag), root, tip, 0.11, 0.035, glass if k % 2 == 0 else gold, (-math.sin(a), sx * math.cos(a), 0), 0.35))
        pa.append(ck.ball(P + "body_glass_core" + tag, 0.04, pc + V((sx * 0.03, 0, 0.08)), glow, (1, 1, 1.3)))
        ck._rigid(bs._outward(pa), rig, "upper_arm" + s)
    lk.limbs(ck, base, mats, P, M, "cloth", boots_m=porc)


ACT3_SETS = {"ele_f50": build_feast_end_lantern, "ele_g50": build_frost_mirror}
