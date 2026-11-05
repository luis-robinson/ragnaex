"""Conjuntos lendários do Druida (18), armas e as formas de animal (lobo e urso) com a armadura de cada conjunto.

Linguagem visual (original): natureza — galhada, folhas, casca, musgo, pele, ossos e totens.
Xamã (cajado, túnicas): capuz com galhada ou coroa de folhas, manto de folhas, colar de totem, cajado vivo.
Lobo (duas maças, couro): capuz de pele de lobo com focinho, tiras e pele, presas.
Urso (malho, placa): elmo de crânio de urso, placas de casca com musgo, pele grossa.
Peças humanas: arm_<estilo>_<slot>_*; formas: form_<wolf|bear>.glb com frm_<estilo>_<slot>_* (presas aos ossos do bicho).
"""
import math
from mathutils import Vector

# head: antler_hood | leaf_crown | wolf_hood | bear_skull | wood_helm ; body: robe | leather | bark
# mantle: leaves | fur ; pauldron: leaf | fur | bark | skull ; antlers: tamanho (0 = sem) ; glow: cor (musgo/seiva acesa)
DRU_SETS = {
    # ---- Xamã ----
    "dru_x5": {"head": "leaf_crown", "body": "robe", "mantle": "leaves", "pauldron": "leaf", "antlers": 0.0, "fur": "brown"},
    "dru_x10": {"head": "antler_hood", "body": "robe", "mantle": "leaves", "pauldron": "leaf", "antlers": 0.8, "fur": "brown"},
    "dru_x15": {"head": "leaf_crown", "body": "robe", "mantle": "fur", "pauldron": "bark", "antlers": 0.6, "fur": "white", "glow": (0.6, 1.0, 0.55)},
    "dru_x20": {"head": "antler_hood", "body": "robe", "mantle": "leaves", "pauldron": "leaf", "antlers": 1.1, "fur": "brown", "glow": (0.55, 1.0, 0.7)},
    "dru_x25": {"head": "antler_hood", "body": "robe", "mantle": "fur", "pauldron": "bark", "antlers": 1.3, "fur": "black", "glow": (0.65, 0.75, 1.0)},
    "dru_x30": {"head": "leaf_crown", "body": "robe", "mantle": "leaves", "pauldron": "leaf", "antlers": 1.5, "fur": "white", "glow": (1.0, 0.9, 0.5)},
    # ---- Lobo ----
    "dru_w5": {"head": "wolf_hood", "body": "leather", "mantle": "fur", "pauldron": "fur", "antlers": 0.0, "fur": "brown"},
    "dru_w10": {"head": "wolf_hood", "body": "leather", "mantle": "fur", "pauldron": "fur", "antlers": 0.0, "fur": "white"},
    "dru_w15": {"head": "wolf_hood", "body": "leather", "mantle": "leaves", "pauldron": "leaf", "antlers": 0.0, "fur": "black"},
    "dru_w20": {"head": "wolf_hood", "body": "leather", "mantle": "fur", "pauldron": "skull", "antlers": 0.0, "fur": "black", "glow": (0.55, 0.9, 1.0)},
    "dru_w25": {"head": "wolf_hood", "body": "leather", "mantle": "fur", "pauldron": "skull", "antlers": 0.5, "fur": "white", "glow": (0.8, 0.95, 1.0)},
    "dru_w30": {"head": "wolf_hood", "body": "leather", "mantle": "leaves", "pauldron": "skull", "antlers": 0.7, "fur": "black", "glow": (0.6, 1.0, 0.7)},
    # ---- Urso ----
    "dru_b5": {"head": "bear_skull", "body": "bark", "mantle": "fur", "pauldron": "bark", "antlers": 0.0, "fur": "brown"},
    "dru_b10": {"head": "wood_helm", "body": "bark", "mantle": "fur", "pauldron": "bark", "antlers": 0.6, "fur": "brown"},
    "dru_b15": {"head": "bear_skull", "body": "bark", "mantle": "leaves", "pauldron": "skull", "antlers": 0.0, "fur": "black", "glow": (0.6, 1.0, 0.5)},
    "dru_b20": {"head": "wood_helm", "body": "bark", "mantle": "fur", "pauldron": "bark", "antlers": 1.0, "fur": "white"},
    "dru_b25": {"head": "bear_skull", "body": "bark", "mantle": "fur", "pauldron": "skull", "antlers": 0.8, "fur": "black", "glow": (1.0, 0.55, 0.3)},
    "dru_b30": {"head": "bear_skull", "body": "bark", "mantle": "leaves", "pauldron": "bark", "antlers": 1.3, "fur": "white", "glow": (0.7, 1.0, 0.55)},
}
FUR = {"brown": (0.4, 0.28, 0.17), "white": (0.86, 0.85, 0.8), "black": (0.14, 0.12, 0.12)}
BONE = (0.92, 0.88, 0.76)
LEAF = (0.36, 0.62, 0.28)
BARK = (0.36, 0.25, 0.16)


def _mats(ck, cfg):
    return {"fur": ck.mat("m_dru_fur_" + cfg["fur"], FUR[cfg["fur"]], 0.95), "bone": ck.mat("m_dru_bone", BONE, 0.7),
            "leaf": ck.mat("m_dru_leaf", LEAF, 0.7), "bark": ck.mat("m_dru_bark", BARK, 0.9),
            "glow": ck.mat("m_dru_glow_%d" % int(sum(cfg["glow"]) * 100), cfg["glow"], 0.3, 2.6) if cfg.get("glow") else None}


def _antlers(ck, P, base_l, base_r, size, material):
    """Galhada: haste que sobe e abre, com 2 pontas por lado."""
    V = Vector
    out = []
    if size <= 0.0:
        return out
    for sx, root in ((-1, base_l), (1, base_r)):
        root = V(root)
        mid = root + V((sx * 0.1, 0.02, 0.16)) * size
        top = mid + V((sx * 0.12, 0.05, 0.16)) * size
        out += [ck.tube(P + "antler_a_%d" % sx, root, mid, 0.024, 0.02, material, 6), ck.tube(P + "antler_b_%d" % sx, mid, top, 0.02, 0.006, material, 6),
                ck.tube(P + "antler_t1_%d" % sx, mid, mid + V((sx * -0.02, -0.06, 0.12)) * size, 0.016, 0.004, material, 6),
                ck.tube(P + "antler_t2_%d" % sx, mid + (top - mid) * 0.5, mid + (top - mid) * 0.5 + V((sx * 0.1, -0.03, 0.05)) * size, 0.014, 0.004, material, 6)]
    return out


def _leaves(ck, P, name, c, r, n, size, material, tilt=0.6, z=0.0):
    """Anel de folhas em leque (manto, coroa)."""
    V = Vector
    out = []
    for k in range(n):
        a = math.tau * k / n
        d = V((math.cos(a), math.sin(a), 0))
        root = V(c) + d * r + V((0, 0, z))
        tip = root + d * size * 0.7 + V((0, 0, -size * tilt))
        out.append(ck.blade(P + "%s_%d" % (name, k), root, tip, size * 0.55, 0.02, material, V((-d.y, d.x, 0))))
    return out


def build(ck, base, mats, style, cfg):
    V = Vector
    rig, body, b, j = base["rig"], base["body"], base["b"], base["j"]
    t, t2, gold, wh, dark = mats["tint"], mats["tint2"], mats["trim"], mats["white"], mats["dark"]
    m = _mats(ck, cfg)
    P = "arm_%s_" % style
    c = V(base["head_c"])
    r = b["head"]
    glow = m["glow"]
    # ---------------- cabeça ----------------
    hk = cfg["head"]
    head = []
    if hk == "antler_hood":           # capuz com galhada saindo de cima
        head.append(ck._shell(P + "head_hood", c, r * 1.16, 0.28, -0.9, -0.45, 0.035, t))
        head += _leaves(ck, P, "head_brim", c + V((0, 0, r * 0.3)), r * 1.08, 10, r * 0.32, m["leaf"], 0.2)
    elif hk == "leaf_crown":          # coroa de folhas e um pequeno véu
        head.append(ck._shell(P + "head_veil", c, r * 1.14, 0.3, -0.75, -0.4, 0.03, t))
        head += _leaves(ck, P, "head_crown", c + V((0, 0, r * 0.5)), r * 1.05, 14, r * 0.42, m["leaf"], -0.5)
    elif hk == "wolf_hood":           # pele de lobo: cabeça do bicho por cima, focinho sobre a testa, orelhas
        head += [ck._shell(P + "head_pelt", c, r * 1.17, 0.32, -1.0, -0.5, 0.04, m["fur"]),
                 ck.ball(P + "head_snout", r * 0.42, c + V((0, -r * 0.95, r * 0.62)), m["fur"], (0.8, 1.2, 0.55)),
                 ck.ball(P + "head_nose", r * 0.1, c + V((0, -r * 1.42, r * 0.66)), dark)]
        for sx in (-1, 1):
            head += [ck.blade(P + "head_ear_%d" % sx, c + V((sx * r * 0.5, -r * 0.2, r * 0.85)), c + V((sx * r * 0.7, -r * 0.05, r * 1.45)), r * 0.45, 0.06, m["fur"], (1, 0, 0)),
                     ck.tube(P + "head_fang_%d" % sx, c + V((sx * r * 0.25, -r * 1.15, r * 0.4)), c + V((sx * r * 0.22, -r * 1.2, r * 0.18)), 0.03, 0.004, m["bone"], 6)]
            if glow:
                head.append(ck.ball(P + "head_eye_%d" % sx, r * 0.07, c + V((sx * r * 0.27, -r * 1.22, r * 0.78)), glow))
        head.append(ck.blade(P + "head_tail", c + V((0, r * 0.9, -r * 0.2)), c + V((0, r * 1.25, -r * 1.4)), r * 0.9, 0.04, m["fur"], (1, 0, 0), 0.4))
    elif hk == "bear_skull":          # crânio de urso por cima: cúpula, orelhas redondas, focinho com dentes
        # capuz de pele com o rosto aberto e o crânio do urso por cima, focinho sobre a testa (como o capuz de lobo)
        head += [ck._shell(P + "head_pelt", c, r * 1.18, 0.32, -1.0, -0.5, 0.04, m["fur"]),
                 ck._shell(P + "head_skull", c + V((0, 0.0, r * 0.08)), r * 1.12, 0.45, 0.2, 0.25, 0.04, m["bone"]),
                 ck.ball(P + "head_muzzle", r * 0.42, c + V((0, -r * 0.98, r * 0.68)), m["bone"], (0.95, 1.15, 0.55)),
                 ck.ball(P + "head_nose", r * 0.11, c + V((0, -r * 1.42, r * 0.72)), dark)]
        for sx in (-1, 1):
            head += [ck.ball(P + "head_ear_%d" % sx, r * 0.24, c + V((sx * r * 0.72, 0, r * 0.95)), m["fur"], (1, 0.6, 1)),
                     ck.tube(P + "head_tooth_%d" % sx, c + V((sx * r * 0.22, -r * 1.25, r * 0.46)), c + V((sx * r * 0.22, -r * 1.27, r * 0.24)), 0.032, 0.004, m["bone"], 6),
                     ck.ball(P + "head_socket_%d" % sx, r * 0.11, c + V((sx * r * 0.3, -r * 1.2, r * 0.86)), glow or dark, (1, 0.5, 1))]
    elif hk == "wood_helm":           # elmo de casca com galhos
        head += [ck._shell(P + "head_helm", c, r * 1.17, 0.12, -0.62, -0.32, 0.04, m["bark"]),
                 ck.tube(P + "head_band", c + V((0, 0, r * 0.18)), c + V((0, 0, r * 0.32)), r * 1.24, r * 1.21, t, 24),
                 ck.box(P + "head_nasal", (0.06, 0.05, r * 0.55), c + V((0, -r * 1.14, -r * 0.02)), m["bark"], 0.012)]
        head += _leaves(ck, P, "head_moss", c + V((0, 0, r * 0.95)), r * 0.5, 7, r * 0.3, m["leaf"], -0.3)
    head += _antlers(ck, P + "head_", c + V((-r * 0.55, 0, r * 0.85)), c + V((r * 0.55, 0, r * 0.85)), cfg["antlers"] * 0.95, m["bone"] if hk != "antler_hood" else m["bark"])
    ck._rigid(head, rig, "head")
    # ---------------- corpo ----------------
    bk = cfg["body"]
    ck.armor_piece(body, rig, P + "body_main", "torso", t if bk != "bark" else m["bark"], 0.016 if bk == "bark" else 0.012, 0.016, 0.04 if bk == "bark" else 0.02)
    ck.armor_piece(body, rig, P + "body_legs", "legs", mats["leather"] if bk != "robe" else t, 0.008, 0.012)
    if bk == "robe":
        ck.skirt(P + "body_skirt", b, body, rig, t, 0.07, 1.85)
        ck.skirt(P + "body_over", b, body, rig, t2, ck.Z["waist"] - 0.24, 1.5)
    d = b["depth"]
    front = -b["chest"] * d - 0.035
    zc = ck.Z["chest"]
    chest = []
    if cfg["mantle"] == "leaves":
        chest += _leaves(ck, P, "body_mantle", (0, 0, ck.Z["neck"] - 0.04), b["chest"] * 0.62, 14, 0.13, m["leaf"], 0.75)
    else:
        for k in range(14):
            a = math.tau * k / 14
            jit = ((k * 37) % 7) / 7.0
            chest.append(ck.ball(P + "body_fur_%d" % k, 0.07 * (0.85 + jit * 0.35), V((math.cos(a) * b["chest"] * 0.66, math.sin(a) * b["chest"] * 0.56, ck.Z["neck"] - 0.06)), m["fur"], (1, 1, 0.75)))
    if bk == "bark":                    # placas de casca com musgo
        chest += [ck.ball(P + "body_plate", 0.16, (0, front + 0.045, zc), m["bark"], (1.25, 0.42, 1.05)),
                  ck.ball(P + "body_moss", 0.08, (0.05, front - 0.01, zc + 0.08), m["leaf"], (1.3, 0.4, 0.7))]
        for k in range(2):
            chest.append(ck.box(P + "body_ring_%d" % k, (0.26 - k * 0.03, 0.03, 0.04), (0, -b["waist"] * d * 1.12 - 0.02, ck.Z["waist"] + 0.06 - k * 0.05), t, 0.01))
    elif bk == "leather":               # tiras cruzadas e presa no peito
        for sx in (-1, 1):
            chest.append(ck.tube(P + "body_strap_%d" % sx, (sx * 0.15, front + 0.03, zc + 0.14), (-sx * 0.13, -b["waist"] * d - 0.03, ck.Z["waist"] + 0.02), 0.022, 0.022, dark, 6))
    # colar de totem: contas e uma peça no meio (osso ou gema acesa)
    for k in range(7):
        a = math.pi * (0.2 + 0.6 * k / 6.0) + math.pi
        p = V((math.cos(a) * 0.13, math.sin(a) * 0.13 * d - 0.01, ck.Z["neck"] - 0.12 - math.sin((k / 6.0) * math.pi) * 0.03))
        chest.append(ck.ball(P + "body_bead_%d" % k, 0.018, p, t2 if k % 2 else m["bone"]))
    chest.append(ck.ball(P + "body_totem", 0.035, (0, front - 0.02, ck.Z["neck"] - 0.17), glow or m["bone"], (1, 0.6, 1.3)))
    chest.append(ck.ball(P + "body_back_knot", 0.06, (0, b["chest"] * d + 0.04, zc + 0.02), m["leaf"] if cfg["mantle"] == "leaves" else m["fur"], (1.2, 0.5, 1)))
    ck._rigid(chest, rig, "chest")
    belt = ck.tube(P + "body_belt", (0, 0, ck.Z["waist"] - 0.035), (0, 0, ck.Z["waist"] + 0.03), b["waist"] * 1.18, b["waist"] * 1.18, mats["leather"], 16)
    for v in belt.data.vertices:
        v.co.y *= d * 1.05
    ck._smooth(belt.data)
    ck.transfer_weights(belt, body, rig)
    hips = [ck.ball(P + "body_pouch", 0.045, (0.1, -b["waist"] * d * 1.15 - 0.02, ck.Z["waist"] - 0.03), mats["leather"], (1, 0.6, 1))]
    if bk != "robe":                    # saiote de folhas/pele
        for k in range(5):
            x = (k - 2) * 0.065
            for side, y in (("f", -b["waist"] * d * 1.18 - 0.012), ("b", b["waist"] * d * 1.18 + 0.012)):
                hips.append(ck.blade(P + "body_kilt_%s%d" % (side, k), (x, y, ck.Z["waist"] - 0.03), (x * 1.1, y, ck.Z["waist"] - 0.19), 0.07, 0.015,
                                     m["leaf"] if cfg["mantle"] == "leaves" else (m["fur"] if bk == "leather" else m["bark"]), (1, 0, 0), 0.4))
    ck._rigid(hips, rig, "hips")
    for s, sx in ((".R", -1), (".L", 1)):
        tag = s.replace(".", "_")
        sh = V(j["shoulder" + s])
        pk = cfg["pauldron"]
        pa = []
        if pk == "leaf":
            pa += _leaves(ck, P, "body_pleaf" + tag, sh + V((sx * 0.07, 0, 0.06)), 0.05, 5, 0.12, m["leaf"], 0.3)
        elif pk == "fur":
            pa.append(ck.ball(P + "body_pfur" + tag, b["arm"] * 2.4, sh + V((sx * 0.06, 0, 0.05)), m["fur"], (1.1, 1.05, 0.7)))
        elif pk == "bark":
            pa += [ck.ball(P + "body_pbark" + tag, b["arm"] * 2.7, sh + V((sx * 0.06, 0, 0.06)), m["bark"], (1.15, 1.1, 0.68)),
                   ck.ball(P + "body_pmoss" + tag, b["arm"] * 1.4, sh + V((sx * 0.07, 0, 0.13)), m["leaf"], (1.1, 1.1, 0.4))]
        elif pk == "skull":
            pa += [ck.ball(P + "body_pfur" + tag, b["arm"] * 2.3, sh + V((sx * 0.06, 0, 0.04)), m["fur"], (1.1, 1.05, 0.65)),
                   ck.ball(P + "body_pskull" + tag, 0.065, sh + V((sx * 0.1, -0.02, 0.12)), m["bone"], (1, 0.9, 1.05)),
                   ck.ball(P + "body_pskull_eye" + tag, 0.016, sh + V((sx * 0.1, -0.075, 0.13)), glow or dark)]
        ck._rigid(pa, rig, "upper_arm" + s)
    # ---------------- braços ----------------
    for s, sx in ((".R", -1), (".L", 1)):
        tag = s.replace(".", "_")
        el, wr = V(j["elbow" + s]), V(j["wrist" + s])
        if bk == "robe":
            g = [ck.tube(P + "gloves_sleeve" + tag, el.lerp(wr, 0.35), wr + V((0, 0, -0.01)), 0.07, 0.11, t, 14)]
            g += [ck.tube(P + "gloves_vine_%d" % k + tag, el.lerp(wr, 0.15 + k * 0.25), el.lerp(wr, 0.22 + k * 0.25), 0.075, 0.075, m["leaf"], 10) for k in range(3)]
        elif bk == "bark":
            g = [ck.tube(P + "gloves_cuff" + tag, el.lerp(wr, 0.2), wr + V((0, 0, 0.01)), 0.08, 0.11, m["bark"], 12),
                 ck.tube(P + "gloves_rim" + tag, wr + V((0, 0, 0.005)), wr + V((0, 0, 0.03)), 0.115, 0.115, t, 12)]
        else:
            g = [ck.tube(P + "gloves_wrap_%d" % k + tag, el.lerp(wr, 0.15 + k * 0.22), el.lerp(wr, 0.27 + k * 0.22), 0.074, 0.07, mats["leather"] if k % 2 else t, 10)
                 for k in range(4)]
        ck._rigid(g, rig, "forearm" + s)
        fist = ck.ball(P + "gloves_fist" + tag, b["hand"] * (1.4 if bk == "bark" else 1.28), ck.hand_center(base, s), m["bark"] if bk == "bark" else mats["leather"], (1, 1, 1.1))
        ck._rigid([fist], rig, "hand" + s)
    # ---------------- pés ----------------
    ck.armor_piece(body, rig, P + "boots_shell", "boots", m["bark"] if bk == "bark" else mats["leather"], 0.024, 0.016)
    for s, sx in ((".R", -1), (".L", 1)):
        tag = s.replace(".", "_")
        an = V(j["ankle" + s])
        k = []
        for q in range(6):
            a = math.tau * q / 6
            k.append(ck.ball(P + "boots_fur_%d" % q + tag, 0.045, an + V((math.cos(a) * 0.07, math.sin(a) * 0.06, 0.1)), m["fur"] if cfg["mantle"] == "fur" else m["leaf"], (1, 1, 0.7)))
        ck._rigid(k, rig, "shin" + s)


# ---------------------------------------------------------------------------
# Armas: cajados do Xamã, maças do Lobo (duas), malhos do Urso
# staff head: spiral | crystal | leaves | antler | seed | moon
DRU_STAFFS = {"dru_x5": {"head": "spiral"}, "dru_x10": {"head": "antler"}, "dru_x15": {"head": "leaves"},
              "dru_x20": {"head": "crystal"}, "dru_x25": {"head": "moon"}, "dru_x30": {"head": "seed"}}
DRU_MACES = {   # formato de paladin_sets.PAL_MACES; o Lobo tem a mesma maça nas duas mãos
    "dru_w5": {"type": "mace", "head": "flange", "n": 6, "core": "metal", "cap": "ball"},
    "dru_w10": {"type": "mace", "head": "star", "core": "tint", "cap": "ball"},
    "dru_w15": {"type": "mace", "head": "flange", "n": 8, "core": "tint", "cap": "gem"},
    "dru_w20": {"type": "mace", "head": "star", "core": "tint", "cap": "gem", "dark": True, "glow": True},
    "dru_w25": {"type": "mace", "head": "flange", "n": 8, "core": "tint", "cap": "gem", "horns": True},
    "dru_w30": {"type": "mace", "head": "star", "core": "tint", "cap": "gem", "dark": True, "horns": True, "glow": True},
    "dru_b5": {"type": "mace2h", "face": "plain"},
    "dru_b10": {"type": "mace2h", "face": "gem"},
    "dru_b15": {"type": "mace2h", "face": "plain", "spikes": True},
    "dru_b20": {"type": "mace2h", "face": "gem", "glow": True},
    "dru_b25": {"type": "mace2h", "face": "gem", "spikes": True, "dark": True},
    "dru_b30": {"type": "mace2h", "face": "sun", "spikes": True, "glow": True},
}


def build_staff(ck, base, mats, style, cfg):
    """Cajado vivo, em pé como o do kit: galho torto com a cabeça do conjunto."""
    V = Vector
    g = V(ck.hand_center(base, ".R"))
    up = V((-0.22, -0.12, 1.0)).normalized()
    side = V((1, 0, 0))
    fwd = up.cross(side).normalized()
    bark = ck.mat("m_dru_bark", BARK, 0.9)
    leaf = ck.mat("m_dru_leaf", LEAF, 0.7)
    glow = ck.mat("m_dru_staff_glow", (0.65, 1.0, 0.6), 0.25, 2.8)
    n = "st_%s_" % style
    ln = 1.3
    pts = [g - up * ln * 0.42 + side * 0.0]
    for k in range(1, 7):        # galho levemente torto
        pts.append(g + up * (ln * (-0.42 + k * 0.165)) + side * (0.025 * math.sin(k * 1.7)) + fwd * (0.02 * math.cos(k * 1.3)))
    parts = []
    for k in range(len(pts) - 1):
        parts.append(ck.tube(n + "shaft%d" % k, pts[k], pts[k + 1], 0.034 - k * 0.002, 0.032 - k * 0.002, bark, 8))
    parts += [ck.tube(n + "wrap%d" % k, pts[2 + k] - up * 0.02, pts[2 + k] + up * 0.02, 0.038, 0.038, mats["tint"], 8) for k in range(2)]
    top = pts[-1]
    hk = cfg["head"]
    if hk == "spiral":           # galho que se enrola em volta de uma pedra
        for k in range(10):
            a0, a1 = k * 0.75, (k + 1) * 0.75
            p0 = top + up * (0.02 + k * 0.022) + (side * math.cos(a0) + fwd * math.sin(a0)) * (0.1 - k * 0.006)
            p1 = top + up * (0.02 + (k + 1) * 0.022) + (side * math.cos(a1) + fwd * math.sin(a1)) * (0.1 - (k + 1) * 0.006)
            parts.append(ck.tube(n + "curl%d" % k, p0, p1, 0.024, 0.022, bark, 6))
        parts.append(ck.ball(n + "stone", 0.06, top + up * 0.12, glow))
    elif hk == "crystal":
        for sx in (-1, 1):
            parts.append(ck.tube(n + "fork%d" % sx, top, top + up * 0.18 + side * sx * 0.08, 0.025, 0.012, bark, 6))
        parts.append(ck.blade(n + "crystal", top + up * 0.05, top + up * 0.36, 0.11, 0.08, glow, side))
    elif hk == "leaves":
        parts.append(ck.ball(n + "bud", 0.06, top + up * 0.06, mats["tint"]))
        for k in range(8):
            a = math.tau * k / 8
            d = (side * math.cos(a) + fwd * math.sin(a))
            parts.append(ck.blade(n + "leaf%d" % k, top + up * 0.05, top + up * 0.18 + d * 0.16, 0.08, 0.015, leaf, up.cross(d)))
    elif hk == "antler":
        bone = ck.mat("m_dru_bone", BONE, 0.7)
        for sx in (-1, 1):
            mid = top + up * 0.12 + side * sx * 0.08
            parts += [ck.tube(n + "ant_a%d" % sx, top, mid, 0.024, 0.02, bone, 6), ck.tube(n + "ant_b%d" % sx, mid, mid + up * 0.16 + side * sx * 0.06, 0.02, 0.005, bone, 6),
                      ck.tube(n + "ant_c%d" % sx, mid, mid + up * 0.09 - side * sx * 0.04, 0.016, 0.004, bone, 6)]
        parts.append(ck.ball(n + "core", 0.045, top + up * 0.1, glow))
    elif hk == "moon":
        for k in range(9):           # crescente
            a0 = math.pi * (0.15 + 0.7 * k / 9.0)
            a1 = math.pi * (0.15 + 0.7 * (k + 1) / 9.0)
            c0 = top + up * 0.15
            parts.append(ck.tube(n + "moon%d" % k, c0 + (side * math.cos(a0 + math.pi * 0.5) + up * math.sin(a0 + math.pi * 0.5)) * 0.14,
                                 c0 + (side * math.cos(a1 + math.pi * 0.5) + up * math.sin(a1 + math.pi * 0.5)) * 0.14, 0.03 - abs(k - 4) * 0.004, 0.03 - abs(k - 3.5) * 0.004,
                                 mats["trim"], 6))
        parts.append(ck.ball(n + "star", 0.045, top + up * 0.15, glow))
    elif hk == "seed":           # semente acesa entre folhas e uma coroa de galhos
        parts.append(ck.ball(n + "seed", 0.08, top + up * 0.14, glow, (1, 1, 1.3)))
        for k in range(6):
            a = math.tau * k / 6
            d = (side * math.cos(a) + fwd * math.sin(a))
            parts += [ck.tube(n + "branch%d" % k, top, top + up * 0.26 + d * 0.11, 0.018, 0.005, bark, 6),
                      ck.blade(n + "leaf%d" % k, top + up * 0.03, top + up * 0.12 + d * 0.15, 0.07, 0.014, leaf, up.cross(d))]
    obj = ck._join(parts, "wpn_main_staff_%s" % style)
    ck._smooth(obj.data)
    ck.skin_rigid(obj, base["rig"], "hand.R")
    return obj


# ---------------------------------------------------------------------------
# Formas: lobo e urso com a armadura de cada conjunto (frm_<estilo>_<slot>_*)
FORM_OF = {"w": "wolf", "b": "bear"}


def _form_geom(kind):
    """Mesmas medidas que mob_kit.quadruped usa para o bicho."""
    bulk = 1.45 if kind == "bear" else 1.0
    hip = 0.5 if kind == "bear" else 0.45
    return bulk, hip, Vector((0, -0.74 - (0.06 if kind == "bear" else 0.0), hip + 0.28))


def form_armor(ck, lp, arm, kind, style, cfg, tint, tint2):
    """Peças de armadura no bicho, juntas por osso: elmo (cabeça), sela + gola (corpo), braçadeiras (pernas)."""
    V = Vector
    bulk, hip, hc = _form_geom(kind)
    m = _mats(ck, cfg)
    P = "frm_%s_" % style
    groups = {}

    def put(slot, bone, obj):
        groups.setdefault((slot, bone), []).append(obj)

    # elmo / máscara
    r = 0.2 * bulk
    if kind == "bear":
        put("head", "head", ck.ball(P + "head_cap", r * 1.05, hc + V((0, 0.04, 0.07)), m["bone"] if style.endswith(("5", "15", "25", "30")) else m["bark"], (1.05, 0.9, 0.7)))
    else:
        put("head", "head", ck.ball(P + "head_cap", r * 1.02, hc + V((0, 0.03, 0.07)), tint, (1.0, 0.9, 0.62)))
    put("head", "head", ck.tube(P + "head_band", hc + V((0, -0.08, -0.04)), hc + V((0, -0.16, -0.04)), r * 0.85, r * 0.75, tint2, 12))
    for o in _antlers(ck, P + "head_", hc + V((-r * 0.45, 0.02, r * 0.7)), hc + V((r * 0.45, 0.02, r * 0.7)), cfg["antlers"] * 1.1, m["bone"]):
        put("head", "head", o)
    if cfg.get("glow"):
        put("head", "head", ck.ball(P + "head_gem", 0.035 * bulk, hc + V((0, -r * 0.75, r * 0.6)), m["glow"]))
    # sela/manta nas costas + gola
    back = V((0, 0.0, hip + 0.22 * bulk))
    put("body", "body", ck.ball(P + "body_saddle", 0.26 * bulk, back + V((0, 0.02, 0.02)), tint, (0.95, 1.5, 0.35)))
    put("body", "body", ck.ball(P + "body_saddle_rim", 0.27 * bulk, back + V((0, 0.02, -0.02)), tint2, (0.97, 1.52, 0.1)))
    neck = V((0, -0.5, hip + 0.18))
    for k in range(10):
        a = math.tau * k / 10
        mat = m["leaf"] if cfg["mantle"] == "leaves" else m["fur"]
        put("body", "body", ck.ball(P + "body_collar_%d" % k, 0.06 * bulk, neck + V((math.cos(a) * 0.2 * bulk, 0, math.sin(a) * 0.17 * bulk + 0.02)), mat, (1, 0.8, 1)))
    if cfg["pauldron"] in ("skull", "bark"):
        put("body", "body", ck.ball(P + "body_trophy", 0.07 * bulk, back + V((0, -0.15, 0.08 * bulk)), m["bone"] if cfg["pauldron"] == "skull" else m["bark"], (1, 0.9, 1)))
    # braçadeiras nas patas (luvas = da frente, botas = de trás)
    for slot, legs in (("gloves", ("leg_fr", "leg_fl")), ("boots", ("leg_br", "leg_bl"))):
        for bone in legs:
            sx = 1 if bone.endswith("r") else -1
            sy = -1 if slot == "gloves" else 1
            top = V((sx * 0.17 * bulk, sy * 0.36, hip))
            foot = V((sx * 0.19 * bulk, sy * 0.38, 0.07))
            leg_r = (0.09 if kind == "wolf" else 0.075 * 1.25) * bulk
            put(slot, bone, ck.tube(P + "%s_band_%s" % (slot, bone), top.lerp(foot, 0.45), top.lerp(foot, 0.7), leg_r * 1.25, leg_r * 1.15, tint, 10))
            put(slot, bone, ck.tube(P + "%s_rim_%s" % (slot, bone), top.lerp(foot, 0.7), top.lerp(foot, 0.75), leg_r * 1.3, leg_r * 1.3, tint2, 10))
            if slot == "gloves":
                put(slot, bone, ck.ball(P + "%s_pad_%s" % (slot, bone), leg_r * 1.6, top + V((0, 0, 0.02)), tint, (1.0, 1.0, 0.7)))
    for (slot, bone), objs in groups.items():
        obj = ck._join(objs, "frm_%s_%s_%s" % (style, slot, bone))
        ck._smooth(obj.data)
        lp.attach(obj, arm, bone)


## Golpes do bicho (EntityView.FORM_CLIP manda cada família de skill para um destes); impacto em EntityView.IMPACT_FRAME.
## Rig de monstro (build_monsters.MOB_BONES): body/head/leg_* ; X do corpo + = mergulha o focinho, - = empina.
FORM_CLIPS = ("maul", "pounce", "slam", "roar", "brace")


def form_clips(lp, arm, kind):
    z = (0, 0, 0)
    hv = 1.0 if kind == "bear" else 0.0      # peso: o urso empina mais, desaba mais fundo, segura o impacto e assenta quicando
    k = lambda a, b: a + (b - a) * hv          # valor do lobo -> valor do urso
    def r(x, y=0.0, zz=0.0):
        return (x, y, zz)
    def p(y, zz=0.0):
        return (0, y, zz)
    end = lambda w, b: int(round(k(w, b)))
    # patada: arma com as patas de trás, empina, rasga com a direita e depois a esquerda, a cabeça morde junto (impacto no 7)
    e = end(16, 20)
    lp.add_action(arm, "maul", {
        "body": [(1, z, z), (3, r(8, 0, -4), p(-0.03 - 0.03 * hv)), (5, r(k(-26, -34), 0, 8), p(k(0.12, 0.2))), (7, r(k(20, 10), 0, -12), p(k(-0.12, -0.05))),
                 (9, r(k(14, 8), 0, -6), p(k(-0.1, -0.05))), (11, r(k(16, 6), 0, 12), p(k(-0.1, -0.03))), (e - 3, r(-4, 0, 0), p(k(0.02, 0.04))), (e, z, z)],
        "head": [(1, z, z), (3, r(10), z), (5, r(-18, 6), z), (7, r(k(26, 8), -8), z), (9, r(k(20, 6), 4), z), (11, r(k(16, 4), 8), z), (e - 3, r(-5), z), (e, z, z)],
        "leg_fr": [(1, z, z), (3, r(15), z), (5, r(k(-70, -85)), z), (7, r(40, 0, 6), z), (9, r(22), z), (11, r(10), z), (e, z, z)],
        "leg_fl": [(1, z, z), (3, r(15), z), (5, r(k(-30, -45)), z), (7, r(-24), z), (9, r(-10), z), (11, r(45, 0, -6), z), (e - 2, r(6), z), (e, z, z)],
        "leg_br": [(1, z, z), (3, r(-18), z), (5, r(22), z), (7, r(-8), z), (11, r(-4), z), (e, z, z)],
        "leg_bl": [(1, z, z), (3, r(-18), z), (5, r(22), z), (7, r(-12), z), (11, r(-6), z), (e, z, z)]}, e, loop=False)
    # bote: agacha, salta com as patas esticadas e cai no alvo, quica e assenta (impacto no 9)
    e = end(18, 21)
    lp.add_action(arm, "pounce", {
        "body": [(1, z, z), (3, r(6), p(-0.06, -0.04)), (5, r(10), p(-0.14 - 0.04 * hv, -0.08)), (7, r(-24), p(0.62, 0.3)), (8, r(-6), p(0.5, 0.42)),
                 (9, r(18), p(-0.06, k(0.45, 0.4))), (11, r(k(12, 16)), p(-0.04, k(0.36, 0.3))), (13, r(6), p(-0.1 - 0.04 * hv, 0.2)), (e - 2, r(-2), p(0.01, 0.02)), (e, z, z)],
        "head": [(1, z, z), (5, r(12), z), (7, r(-14), z), (9, r(22), z), (11, r(14), z), (13, r(6), z), (e, z, z)],
        "leg_fr": [(1, z, z), (5, r(30), z), (7, r(-70), z), (9, r(20), z), (11, r(12), z), (13, r(-6), z), (e, z, z)],
        "leg_fl": [(1, z, z), (5, r(30), z), (7, r(-64), z), (9, r(24), z), (11, r(10), z), (13, r(-4), z), (e, z, z)],
        "leg_br": [(1, z, z), (5, r(-30), z), (7, r(55), z), (8, r(40), z), (9, r(-10), z), (12, r(-14), z), (e, z, z)],
        "leg_bl": [(1, z, z), (5, r(-30), z), (7, r(50), z), (8, r(45), z), (9, r(-8), z), (12, r(-12), z), (e, z, z)]}, e, loop=False)
    # pisão: empina alto, desaba com as duas patas, o corpo afunda e quica (impacto no 8; área em volta)
    e = end(18, 23)
    lp.add_action(arm, "slam", {
        "body": [(1, z, z), (3, r(8), p(-0.05)), (5, r(k(-42, -55)), p(k(0.32, 0.42), -0.05)), (6, r(k(-36, -50)), p(k(0.3, 0.4), -0.04)), (8, r(k(22, 8)), p(k(-0.16, -0.06), 0.08)),
                 (10, r(k(18, 6)), p(k(-0.14, -0.06), 0.07)), (12, r(k(14, 6)), p(k(-0.1, -0.04), 0.05)), (14, r(k(4, 2)), p(k(0.0, 0.04))), (e - 2, r(-3), p(0.02)), (e, z, z)],
        "head": [(1, z, z), (3, r(8), z), (5, r(-24), z), (8, r(k(18, 4)), z), (10, r(k(14, 2), 0, 4), z), (12, r(10, 0, -4), z), (e, z, z)],
        "leg_fr": [(1, z, z), (3, r(12), z), (5, r(k(-85, -100)), z), (8, r(25, 0, 8), z), (12, r(20, 0, 6), z), (e - 2, r(-4), z), (e, z, z)],
        "leg_fl": [(1, z, z), (3, r(12), z), (5, r(k(-85, -100)), z), (8, r(25, 0, -8), z), (12, r(20, 0, -6), z), (e - 2, r(-4), z), (e, z, z)],
        "leg_br": [(1, z, z), (3, r(-12), z), (5, r(k(26, 34)), z), (8, r(-16, 0, 6), z), (12, r(-10), z), (e, z, z)],
        "leg_bl": [(1, z, z), (3, r(-12), z), (5, r(k(26, 34)), z), (8, r(-16, 0, -6), z), (12, r(-10), z), (e, z, z)]}, e, loop=False)
    # rugido: recolhe e solta; o lobo crava as patas e uiva de focinho para cima, o urso fica de pé nas patas de trás
    # e abre os braços (impacto no 7; magias, gritos e buffs de força)
    e = end(18, 22)
    rear = k(-16, -48)
    lp.add_action(arm, "roar", {
        "body": [(1, z, z), (4, r(10), p(-0.06, -0.02)), (7, r(rear), p(k(0.06, 0.16), k(0.04, -0.05))), (9, r(rear + 2, 0, 3), p(k(0.06, 0.16), k(0.04, -0.05))),
                 (11, r(rear, 0, -3), p(k(0.05, 0.15), k(0.04, -0.05))), (13, r(rear + 2), p(k(0.05, 0.14), k(0.03, -0.04))), (e - 3, r(4), p(-0.03 * hv)), (e, z, z)],
        "head": [(1, z, z), (4, r(18), z), (7, r(k(-38, -20), 0, 8), z), (9, r(k(-36, -18), 0, -8), z), (11, r(k(-38, -20), 0, 8), z), (13, r(k(-34, -16)), z), (e - 3, r(6), z), (e, z, z)],
        "leg_fr": [(1, z, z), (4, r(-10, 0, 6), z), (7, r(k(-12, -60), 0, k(14, 34)), z), (11, r(k(-12, -64), 0, k(14, 30)), z), (13, r(k(-10, -56), 0, k(12, 28)), z), (e - 2, r(6), z), (e, z, z)],
        "leg_fl": [(1, z, z), (4, r(-10, 0, -6), z), (7, r(k(-12, -60), 0, k(-14, -34)), z), (11, r(k(-12, -64), 0, k(-14, -30)), z), (13, r(k(-10, -56), 0, k(-12, -28)), z), (e - 2, r(6), z), (e, z, z)],
        "leg_br": [(1, z, z), (4, r(8), z), (7, r(k(10, 40)), z), (13, r(k(10, 38)), z), (e - 2, r(-4), z), (e, z, z)],
        "leg_bl": [(1, z, z), (4, r(8), z), (7, r(k(10, 40)), z), (13, r(k(10, 38)), z), (e - 2, r(-4), z), (e, z, z)]}, e, loop=False)
    # guarda: crava as patas abertas, abaixa o corpo e respira pesado (impacto no 6; buffs de defesa)
    e = end(16, 19)
    low = k(-0.16, -0.22)
    lp.add_action(arm, "brace", {
        "body": [(1, z, z), (3, r(-6), p(0.04)), (6, r(6), p(low)), (9, r(5), p(low + 0.02)), (12, r(6), p(low)), (e - 2, r(-2), p(0.02)), (e, z, z)],
        "head": [(1, z, z), (3, r(-8), z), (6, r(16, 0, 4), z), (9, r(12, 0, -3), z), (12, r(12), z), (e, z, z)],
        "leg_fr": [(1, z, z), (3, r(-20), z), (6, r(-12, 0, 18), z), (12, r(-12, 0, 18), z), (e, z, z)],
        "leg_fl": [(1, z, z), (3, r(-20), z), (6, r(-12, 0, -18), z), (12, r(-12, 0, -18), z), (e, z, z)],
        "leg_br": [(1, z, z), (3, r(10), z), (6, r(12, 0, 14), z), (12, r(12, 0, 14), z), (e, z, z)],
        "leg_bl": [(1, z, z), (3, r(10), z), (6, r(12, 0, -14), z), (12, r(12, 0, -14), z), (e, z, z)]}, e, loop=False)


def build_forms(out_dir):
    """form_wolf.glb e form_bear.glb: o bicho do druida + armadura de animal de cada conjunto do Lobo/Urso."""
    import os
    import bpy
    import chibi_kit as ck
    import lowpoly_lib as lp
    import mob_kit
    tint = ck.mat("tint", ck.TINT_BASE, 0.6)
    for prefix, kind in FORM_OF.items():
        ck.clear()
        tint = ck.mat("tint", ck.TINT_BASE, 0.6)
        tint2 = ck.mat("tint2", ck.TINT_BASE, 0.6)
        if kind == "wolf":
            arm = mob_kit.quadruped("form_wolf", (0.5, 0.52, 0.5), (0.28, 0.3, 0.28), (0.82, 0.84, 0.8), "wolf")
        else:
            arm = mob_kit.quadruped("form_bear", (0.42, 0.29, 0.18), (0.24, 0.16, 0.1), (0.66, 0.52, 0.38), "bear")
        for style, cfg in DRU_SETS.items():
            if style.startswith("dru_" + prefix):
                form_armor(ck, lp, arm, kind, style, cfg, tint, tint2)
        form_clips(lp, arm, kind)
        bpy.ops.object.mode_set(mode="OBJECT")
        for o in bpy.context.scene.objects:
            if "." in o.name:
                o.name = o.name.replace(".", "_")
        lp.export_glb(os.path.join(out_dir, "form_%s.glb" % kind), [arm])
    print("forms done")


def register(ck):
    import paladin_sets
    for style, cfg in DRU_SETS.items():
        ck.SET_STYLES[style] = (lambda st, cf: (lambda base, mats: (build(ck, base, mats, st, cf), paladin_sets.join_slots("arm_%s_" % st))))(style, cfg)
    for style, cfg in DRU_STAFFS.items():
        ck.SET_WEAPONS[style + "_staff"] = (lambda st, cf: (lambda base, mats: build_staff(ck, base, mats, st, cf)))(style, cfg)
    for style, cfg in DRU_MACES.items():
        ck.SET_WEAPONS[style + "_mace"] = (lambda st, cf: (lambda base, mats: paladin_sets.build_mace(ck, base, mats, st, cf)))(style, cfg)
        if cfg["type"] == "mace":                # Lobo: a segunda maça, na mão esquerda
            ck.SET_WEAPONS[style + "_offmace"] = (lambda st, cf: (lambda base, mats: paladin_sets.build_mace(ck, base, mats, st, cf, "off")))(style, cfg)
