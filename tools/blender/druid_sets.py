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
            "glow": ck.mat(glow_name(cfg["glow"]), cfg["glow"], 0.3, 2.6) if cfg.get("glow") else None}


def glow_name(color):
    """Nome do material de brilho pela cor INTEIRA (r_g_b em centésimos). Antes era a soma dos canais: dru_x20 (0.55, 1.0, 0.7)
    e dru_b30 (0.7, 1.0, 0.55) davam os dois `m_dru_glow_225` e o 2º saía com a cor do 1º (dependia da ordem do build)."""
    return "m_dru_glow_%d_%d_%d" % tuple(int(round(c * 100)) for c in color[:3])


def form_tints(ck):
    """`tint`/`tint2` das formas com a base FIXA (ck.TINT_BASE, rugosidade 0.6), mesmo se a sessão já tem um `tint` de outro
    modelo (o cavalo deixa a pelagem 0.55/0.38/0.24): rodar só as formas dá o mesmo GLB que o build inteiro.
    Devolve (tint, tint2, guardado); chame `restore_tints(guardado)` depois do export para devolver o que havia."""
    out, saved = [], []
    for name in ("tint", "tint2"):
        m = ck.mat(name, ck.TINT_BASE, 0.6)
        b = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
        saved.append((m, tuple(b.inputs["Base Color"].default_value), b.inputs["Roughness"].default_value, tuple(m.diffuse_color)))
        b.inputs["Base Color"].default_value = (*ck.TINT_BASE, 1.0)
        b.inputs["Roughness"].default_value = 0.6
        m.diffuse_color = (*ck.TINT_BASE, 1.0)
        out.append(m)
    return out[0], out[1], saved


def restore_tints(saved):
    for m, col, rough, dif in saved:
        b = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
        b.inputs["Base Color"].default_value = col
        b.inputs["Roughness"].default_value = rough
        m.diffuse_color = dif


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
    if cfg.get("glow") == "tint":        # Ato II: brilho na cor do nível
        import ranger_sets as rs
        glow = rs.tint_glow(ck)
    else:
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
    elif hk == "ram":            # Ato II: crânio de carneiro no alto do galho, chifres enrolados, penas penduradas
        bone = ck.mat("m_dru_bone", BONE, 0.7)
        sk = top + up * 0.12
        parts += [ck.ball(n + "skull", 0.11, sk, bone, (1.0, 1.0, 0.95)), ck.ball(n + "muzzle", 0.07, sk - fwd * 0.115 - up * 0.06, bone, (0.8, 1.3, 0.8)),
                  ck.blade(n + "crown", sk + up * 0.08, sk + up * 0.3, 0.09, 0.07, glow, side, 0.4)]
        for sx in (-1, 1):
            parts.append(ck.ball(n + "eye%d" % sx, 0.03, sk + side * sx * 0.052 - fwd * 0.09 + up * 0.016, glow))
            parts += _ram_horn(ck, n + "horn%d" % sx, sk + side * sx * 0.09 - up * 0.03, sx, 0.115, 0.046, bone)
            for k in range(2):
                p = top - up * (0.04 + k * 0.05) + side * sx * 0.04
                parts.append(ck.blade(n + "feather%d_%d" % (sx, k), p, p + side * sx * 0.1 - up * (0.2 + k * 0.04), 0.07, 0.015, mats["tint2"], fwd))
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
        "tail": [(1, z, z), (3, r(-6), z), (5, r(22, 0, 10), z), (7, r(12, 0, -14), z), (11, r(16, 0, 10), z), (e, z, z)],
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
        "tail": [(1, z, z), (5, r(-12), z), (7, r(-22), z), (9, r(14), z), (13, r(4, 0, 8), z), (e, z, z)],
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
        "tail": [(1, z, z), (5, r(28), z), (8, r(-14), z), (11, r(6, 0, 10), z), (14, r(2, 0, -6), z), (e, z, z)],
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
        "tail": [(1, z, z), (4, r(-6), z), (7, r(26, 0, 12), z), (9, r(26, 0, -12), z), (11, r(26, 0, 12), z), (13, r(22), z), (e, z, z)],
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
        "tail": [(1, z, z), (6, r(-20), z), (12, r(-18), z), (e, z, z)],
        "body": [(1, z, z), (3, r(-6), p(0.04)), (6, r(6), p(low)), (9, r(5), p(low + 0.02)), (12, r(6), p(low)), (e - 2, r(-2), p(0.02)), (e, z, z)],
        "head": [(1, z, z), (3, r(-8), z), (6, r(16, 0, 4), z), (9, r(12, 0, -3), z), (12, r(12), z), (e, z, z)],
        "leg_fr": [(1, z, z), (3, r(-20), z), (6, r(-12, 0, 18), z), (12, r(-12, 0, 18), z), (e, z, z)],
        "leg_fl": [(1, z, z), (3, r(-20), z), (6, r(-12, 0, -18), z), (12, r(-12, 0, -18), z), (e, z, z)],
        "leg_br": [(1, z, z), (3, r(10), z), (6, r(12, 0, 14), z), (12, r(12, 0, 14), z), (e, z, z)],
        "leg_bl": [(1, z, z), (3, r(10), z), (6, r(12, 0, -14), z), (12, r(12, 0, -14), z), (e, z, z)]}, e, loop=False)


def _wolf_light(ck, lp, mob_kit, arm):
    """Tom claro que se lê de cima (52°) SÓ no lobo do druida: a barriga clara do quadrúpede fica escondida sob o tronco.
    Faixa clara no flanco baixo, peitoral, bochechas e meias + patas claras (m_form_wolf_light). Uma malha por osso."""
    V = Vector
    ml = ck.mat("m_form_wolf_light", (0, 0, 0))            # já existe (mob_kit.quadruped)
    bulk, hip, hc = _form_geom("wolf")
    groups = {"body": [], "head": []}
    for sx in (-1, 1):
        groups["body"].append(mob_kit.blob("lt_flank%d" % sx, 0.1, (sx * 0.16, 0.03, hip + 0.0), ml, (0.72, 3.5, 1.25)))
        groups["head"].append(mob_kit.blob("lt_cheek%d" % sx, 0.09, hc + V((sx * 0.145, -0.07, -0.07)), ml, (0.85, 1.15, 0.8), 2))
    groups["body"].append(mob_kit.blob("lt_chest", 0.17, (0, -0.42, hip - 0.07), ml, (1.2, 1.0, 0.95)))
    for name, objs in groups.items():
        obj = ck._join(objs, "fur_light_" + name)
        ck._smooth(obj.data)
        lp.attach(obj, arm, name)
    leg_r = 0.09
    for bone, sx, sy in (("leg_fr", 1, -1), ("leg_fl", -1, -1), ("leg_br", 1, 1), ("leg_bl", -1, 1)):       # mesmas medidas do quadruped
        top, foot = V((sx * 0.17, sy * 0.36, hip)), V((sx * 0.19, sy * 0.38, 0.07))
        sock = ck.tube("fur_light_" + bone, top.lerp(foot, 0.5), foot, leg_r * 1.02, leg_r * 0.9, ml, 8)
        ck._smooth(sock.data)
        lp.attach(sock, arm, bone)
        paw = next(o for o in arm.children if o.name == "paw_" + bone)
        paw.data.materials[0] = ml


FORM_GROUND_CLIPS = ("maul", "pounce", "slam", "attack")     # só os golpes; guarda/rugido afundam de propósito (ver nota abaixo)


def clear_form_ground(ck, arm, skip=None):
    """Pernas de um osso só: quando o corpo desaba (pisão, patada, bote, guarda) a pata atravessava o chão 0,15-0,3 m e o
    peito do lobo uns 0,1 m. Passada de chibi_kit.clear_ground: o corpo sobe o que falta, a cabeça ergue o focinho e cada
    perna abre (dianteiras para a frente, traseiras para trás) até a pata voltar à altura em que pisa parada.
    Só rotação/posição desses ossos: duração e quadro de impacto dos clipes não mudam.
    Fora da passada: "brace"/"roar"/"hit" (a guarda do urso agacha 0,22 m com pernas de 0,3 m: livrar o chão deitava o bicho
    de barriga, é escolha de pose e não de folga), os laços e o "die".
    skip = prefixo de malhas fora da conta (armadura do Ato II nas formas ancestrais: os clipes delas não mudam)."""
    by_bone = {}
    for o in arm.children:
        if o.type == "MESH" and o.parent_type == "BONE" and not (skip and o.name.startswith(skip)):
            by_bone.setdefault(o.parent_bone, []).append(o)
    modes = (("body", "lift"), ("head", "pitch"), ("leg_fr", "pitch-"), ("leg_fl", "pitch-"), ("leg_br", "pitch+"), ("leg_bl", "pitch+"))
    spec = [(b, by_bone[b], m) for b, m in modes if b in by_bone]
    return ck.clear_ground(arm, spec, [n for n in FORM_GROUND_CLIPS if n in ck._tracks(arm)], margin=0.0)


def build_forms(out_dir, only=None):
    """form_wolf.glb e form_bear.glb: o bicho do druida + armadura de animal de cada conjunto do Lobo/Urso.
    only = lista de formas ("wolf"/"bear") para refazer só essas (sem as ancestrais); None = tudo, como antes."""
    import os
    import bpy
    import chibi_kit as ck
    import lowpoly_lib as lp
    import mob_kit
    for prefix, kind in FORM_OF.items():
        if only is not None and kind not in only:
            continue
        ck.clear()
        tint, tint2, saved = form_tints(ck)          # base fixa: não herda o `tint` que outro modelo deixou na sessão
        if kind == "wolf":
            # pelo cinza-castanho médio, barriga/focinho claros, juba e patas escuras. O cinza (0.5, 0.52, 0.5) saía quase branco
            # no jogo: o FormModel usa a cor do glTF sem voltar de sRGB (0.5 vira ~0.74), então os números aqui são mais escuros.
            arm = mob_kit.quadruped("form_wolf", (0.29, 0.235, 0.18), (0.13, 0.105, 0.09), (0.66, 0.58, 0.45), "wolf")
            _wolf_light(ck, lp, mob_kit, arm)
        else:
            arm = mob_kit.quadruped("form_bear", (0.42, 0.29, 0.18), (0.24, 0.16, 0.1), (0.66, 0.52, 0.38), "bear")
        for style, cfg in DRU_SETS.items():
            if style.startswith("dru_" + prefix):
                form_armor(ck, lp, arm, kind, style, cfg, tint, tint2)
        for style, form in ACT2_FORM.items():          # Ato II: uma armadura de animal por build (cor/brilho por nível no jogo)
            if form == kind:
                form_armor2(ck, lp, arm, kind, style, tint, tint2)
        form_clips(lp, arm, kind)
        clear_form_ground(ck, arm)
        for style, form in ACT3_FORM.items():          # nível 50 (Ato III): posta DEPOIS da conta de chão, os clipes não mudam
            if form == kind:
                form_armor3(ck, lp, arm, kind, style, tint, tint2)
        bpy.ops.object.mode_set(mode="OBJECT")
        for o in bpy.context.scene.objects:
            if "." in o.name:
                o.name = o.name.replace(".", "_")
        if out_dir:                      # None = só monta a cena (prévia)
            lp.export_glb(os.path.join(out_dir, "form_%s.glb" % kind), [arm])
        restore_tints(saved)
    print("forms done")
    if only is not None:
        return
    import druid_ancestral          # ascensão: Ent, Lobo Alfa e Pássaro Arcano (form_ent/alpha/bird.glb)
    druid_ancestral.build(out_dir)


# ---------------------------------------------------------------------------
# Ato II (níveis 35/40/45 + Ápice da build): UM visual novo por build, tema guerra contra a Horda em Monte Kharzun.
# A malha é a mesma nos três níveis; muda a cor do item (tint), o destaque (tint2) e o brilho: o material "tint_glow"
# recebe no jogo a cor de GearCatalog.ACT2_VISUALS[...]["glows"][nível] (KitModel e FormModel).
#   dru_x35 Xamã  = Xamã da Estepe: máscara de crânio de carneiro com chifres enrolados, cocar de penas (tint2) que desce
#           pelas costas, feixes de talismãs de osso nos ombros, túnica de couro pintada. Cajado: crânio de carneiro.
#   dru_w35 Lobo  = Matilha de Guerra: elmo de cabeça de lobo inteira (o rosto dentro da boca aberta), crina (tint2),
#           ombreiras com garras, coleira de cravos, couro tachado. Maças: mandíbula de presas com miolo aceso.
#   dru_b35 Urso  = Montanha Viva: elmo de pedra com crista de musgo (tint2), lajes de pedra nos ombros com cristais
#           acesos, placas de casca e rocha, casco de pedra nas costas. Malho: pedregulho com cristais.
# Ficam FORA de DRU_SETS de propósito; as formas ancestrais ganham a armadura do Ato II em druid_ancestral.ACT2_STYLE.
ROCK = (0.3, 0.3, 0.34)


def _a2_mats(ck):
    import ranger_sets as rs
    return {"bone": ck.mat("m_dru_bone", BONE, 0.7), "fur": ck.mat("m_dru_fur_brown", FUR["brown"], 0.95),
            "furk": ck.mat("m_dru_fur_black", FUR["black"], 0.95), "bark": ck.mat("m_dru_bark", BARK, 0.9),
            "rock": ck.mat("m_dru_rock", ROCK, 0.9), "glow": rs.tint_glow(ck)}


def _ram_horn(ck, name, centre, sx, r0, thick, material, turns=1.55, n=9):
    """Chifre de carneiro: espiral num plano de lado (sobe, vai para trás, desce e volta para a frente), abrindo para fora."""
    V = Vector
    out = []
    prev = None
    for i in range(n + 1):
        k = i / n
        th = -0.5 + k * math.tau * turns * 0.5
        rad = r0 * (1.0 - 0.5 * k)
        p = V(centre) + V((sx * r0 * (0.1 + 0.75 * k), math.sin(th) * rad, math.cos(th) * rad))
        if prev is not None:
            out.append(ck.tube("%s_%d" % (name, i), prev, p, thick * (1.0 - 0.85 * (i - 1) / n), thick * (1.0 - 0.85 * k), material, 8))
        prev = p
    return out


def _a2_boots(ck, base, P, shell_m, cuff_m, band_m, m, fur=None, push=0.024):
    V = Vector
    rig, body, j = base["rig"], base["body"], base["j"]
    import ranger_sets as rs
    ck.armor_piece(body, rig, P + "boots_shell", "boots", shell_m, push, 0.016)
    for s in (".R", ".L"):
        tag = s.replace(".", "_")
        an, kn = V(j["ankle" + s]), V(j["knee" + s])
        k = [ck.tube(P + "boots_cuff" + tag, an + V((0, 0, 0.07)), an + V((0, 0, 0.115)), 0.086, 0.097, cuff_m, 12),
             ck.tube(P + "boots_wrap" + tag, an + V((0, 0, 0.02)), an + V((0, 0, 0.045)), 0.08, 0.08, band_m, 12)]
        if fur is not None:
            k += rs.fur_ring(ck, P + "boots_fur" + tag, an + V((0, 0, 0.115)), 0.082, 7, 0.045, fur, 0.012, 1.0)
        k.append(ck.ball(P + "boots_knee" + tag, 0.05, kn + V((0, -0.062, 0.0)), m, (1.0, 0.6, 1.1)))
        ck._rigid(rs.outward(k), rig, "shin" + s)


def build_steppe_shaman(ck, base, mats, style):
    """dru_x35 — Xamã da Estepe (Xamã, cajado)."""
    import ranger_sets as rs
    V = Vector
    rig, body, b, j = base["rig"], base["body"], base["b"], base["j"]
    t, t2, gold, dark, leather, wh = mats["tint"], mats["tint2"], mats["trim"], mats["dark"], mats["leather"], mats["white"]
    m = _a2_mats(ck)
    bone, fur, glow = m["bone"], m["fur"], m["glow"]
    P = "arm_%s_" % style
    c, r = V(base["head_c"]), b["head"]
    # ---------------- cabeça: capuz de couro, crânio de carneiro por cima (focinho sobre a testa), chifres enrolados, cocar ----------------
    head = [ck._shell(P + "head_hood", c, r * 1.15, 0.3, -0.85, -0.45, 0.04, t),
            ck._shell(P + "head_skull", c + V((0, -r * 0.04, r * 0.08)), r * 1.12, 0.45, 0.2, 0.25, 0.045, bone),
            ck.ball(P + "head_muzzle", r * 0.38, c + V((0, -r * 1.0, r * 0.64)), bone, (0.72, 1.3, 0.5)),
            ck.ball(P + "head_nose", r * 0.1, c + V((0, -r * 1.46, r * 0.62)), dark, (1.3, 0.6, 0.7))]
    for sx in (-1, 1):
        head += [ck.ball(P + "head_socket_%d" % sx, r * 0.12, c + V((sx * r * 0.3, -r * 1.16, r * 0.84)), glow, (1.0, 0.5, 1.0)),
                 ck.tube(P + "head_tooth_%d" % sx, c + V((sx * r * 0.16, -r * 1.32, r * 0.5)), c + V((sx * r * 0.16, -r * 1.34, r * 0.3)), 0.028, 0.004, bone, 6),
                 ck.tube(P + "head_horn_ring_%d" % sx, c + V((sx * r * 0.86, -r * 0.02, r * 0.5)), c + V((sx * r * 1.02, -r * 0.02, r * 0.56)), r * 0.3, r * 0.27, gold, 10)]
        head += _ram_horn(ck, P + "head_horn_%d" % sx, c + V((sx * r * 0.9, r * 0.05, r * 0.12)), sx, r * 0.56, r * 0.24, bone)
    # cocar: leque de penas de orelha a orelha, em pé, atrás do crânio; faixa de contas na base
    nf = 11
    for k in range(nf):
        a = -1.25 + 2.5 * k / (nf - 1)
        dv = V((math.sin(a), 0.0, math.cos(a)))
        root = c + dv * r * 1.04 + V((0, r * 0.42, 0))
        ln = r * (1.0 - 0.28 * abs(a))
        tip = root + dv * ln + V((0, r * 0.38, 0))
        head.append(ck.blade(P + "head_feather_%d" % k, root, tip, r * 0.36, 0.035, t2, V((math.cos(a), 0, -math.sin(a))), 0.55))
        head.append(ck.blade(P + "head_feather_tip_%d" % k, root.lerp(tip, 0.72), tip + dv * r * 0.1, r * 0.2, 0.045, wh, V((math.cos(a), 0, -math.sin(a))), 0.5))
        head.append(ck.ball(P + "head_bead_%d" % k, r * 0.09, root + V((0, -r * 0.02, 0)), glow if k == nf // 2 else gold))
    for sx in (-1, 1):                   # duas penas penduradas de cada argola dos chifres
        for k in range(2):
            p = c + V((sx * r * 1.08, -r * 0.1 + k * r * 0.22, r * 0.36))
            head.append(ck.blade(P + "head_drop_%d_%d" % (sx, k), p, p + V((sx * r * 0.12, r * 0.05, -r * (0.75 + 0.2 * k))), r * 0.26, 0.03, t2 if k else wh, (0, 1, 0), 0.5))
    ck._rigid(rs.outward(head), rig, "head")
    # ---------------- corpo: túnica de couro pintada ----------------
    ck.armor_piece(body, rig, P + "body_main", "torso", t, 0.013, 0.016, 0.03)
    ck.armor_piece(body, rig, P + "body_legs", "legs", leather, 0.008, 0.012)
    sk = ck.skirt(P + "body_skirt", b, body, rig, t, 0.08, 1.9)
    hem = []                             # barra pintada: dentes (tint2) em volta e franja de couro
    hr = b["waist"] * 1.18 * 1.9 + 0.014
    for k in range(14):
        a = math.tau * (k + 0.5) / 14
        dv = V((math.cos(a), math.sin(a) * b["depth"] * 1.05, 0))
        tang = V((-dv.y, dv.x, 0)).normalized()
        p = dv * hr + V((0, 0, 0.085))
        hem.append(ck.blade(P + "body_hem_%d" % k, p - tang * 0.0, dv * hr * 0.85 + V((0, 0, 0.2)), 0.1, 0.014, t2, tang, 0.12))
        hem.append(ck.tube(P + "body_fringe_%d" % k, p + tang * 0.045, p + tang * 0.045 + V((0, 0, -0.05)), 0.014, 0.008, bone if k % 2 else leather, 5))
    hem = ck._join(rs.outward(hem), P + "body_hem")
    ck.transfer_weights(hem, sk, rig)
    ck.skirt(P + "body_over", b, body, rig, fur, ck.Z["waist"] - 0.2, 1.55)
    d = b["depth"]
    front = -b["chest"] * d - 0.032
    back = b["chest"] * d + 0.03
    zc, zn, zw = ck.Z["chest"], ck.Z["neck"], ck.Z["waist"]
    yb = back + 0.05 + r * 0.2
    chest = [ck.tube(P + "body_sun", (0, front + 0.012, zc + 0.02), (0, front - 0.012, zc + 0.02), 0.085, 0.08, t2, 12),
             ck.ball(P + "body_sun_eye", 0.04, (0, front - 0.016, zc + 0.02), glow, (1.0, 0.4, 1.0))]
    for k in range(8):                   # raios pintados em volta do sol
        a = math.tau * k / 8
        dv = V((math.cos(a), 0, math.sin(a)))
        chest.append(ck.blade(P + "body_ray_%d" % k, V((0, front - 0.004, zc + 0.02)) + dv * 0.085, V((0, front + 0.004, zc + 0.02)) + dv * 0.135, 0.04, 0.012, t2, V((-dv.z, 0, dv.x))))
    for k in range(9):                   # colar de ossos e dentes
        a = math.pi * (0.15 + 0.7 * k / 8.0)
        p = V((math.cos(a) * b["chest"] * 0.55, -math.sin(a) * b["chest"] * 0.6 - 0.02, zn - 0.07 - math.sin(a) * 0.04))
        chest.append(ck.tube(P + "body_tooth_%d" % k, p, p + V((0, -0.012, -0.085 if k % 2 == 0 else -0.05)), 0.02, 0.003, bone if k != 4 else glow, 6))
    chest += rs.fur_ring(ck, P + "body_collar", (0, 0.01, zn - 0.045), b["chest"] * 0.6, 12, 0.062, fur, 0.02, 0.9)
    # trilha do cocar: duas fileiras de penas descendo pelas costas até a cintura, por fora da cabeça
    spine_pts = [(0, back + 0.04, zn + 0.02), (0, yb, zc + 0.06), (0, yb + 0.01, zw + 0.02), (0, yb + 0.03, zw - 0.14)]
    chest.append(rs.ribbon(ck, P + "body_trail_band", spine_pts, (1, 0, 0), [0.07, 0.07, 0.06, 0.04], 0.03, leather))
    for k in range(6):
        tt = k / 5.0
        root = V((0, yb + 0.02 + 0.02 * tt, zn - 0.04 - tt * 0.46))
        for sx in (-1, 1):
            tip = root + V((sx * (0.2 - 0.04 * tt), 0.09, -0.11))
            chest.append(ck.blade(P + "body_trail_%d_%d" % (k, sx), root + V((sx * 0.02, 0, 0)), tip, 0.1, 0.02, t2, (0, 0.4, 1), 0.55))
            chest.append(ck.blade(P + "body_trail_tip_%d_%d" % (k, sx), root.lerp(tip, 0.7), tip + V((sx * 0.03, 0.012, -0.016)), 0.055, 0.028, wh, (0, 0.4, 1), 0.5))
        chest.append(ck.ball(P + "body_trail_bead_%d" % k, 0.022, root + V((0, 0.02, 0)), gold if k % 2 else bone))
    ck._rigid(rs.outward(chest), rig, "chest")
    rs.body_belt(ck, base, P + "body_belt", zw - 0.04, zw + 0.035, 1.2, leather)
    wf = -b["waist"] * d * 1.2
    hips = [ck.blade(P + "body_flap", (0, wf - 0.014, zw - 0.01), (0, wf - 0.06, zw - 0.3), 0.17, 0.016, t2, (1, 0, 0), 0.75),
            ck.ball(P + "body_buckle", 0.045, (0, wf - 0.012, zw), bone, (1.0, 0.6, 1.0)),
            ck.ball(P + "body_gourd", 0.058, (-0.13, wf + 0.02, zw - 0.07), leather, (1.0, 0.9, 1.15)),
            ck.ball(P + "body_gourd_top", 0.03, (-0.13, wf + 0.02, zw + 0.0), glow)]
    for k in range(3):                   # marcas pintadas (acesas) na aba da frente
        hips.append(ck.ball(P + "body_mark_%d" % k, 0.026 - k * 0.004, (0, wf - 0.034 - k * 0.012, zw - 0.08 - k * 0.065), glow, (1.2, 0.3, 0.9)))
    for k, x in enumerate((0.1, 0.14, 0.17)):      # ossos pendurados no quadril esquerdo
        p = V((x, wf + 0.04 + k * 0.03, zw - 0.04))
        hips.append(ck.tube(P + "body_charm_%d" % k, p, p + V((0.01, 0, -0.1 - 0.02 * (k % 2))), 0.016, 0.012, bone, 6))
    ck._rigid(rs.outward(hips), rig, "hips")
    for s, sx in ((".R", -1), (".L", 1)):          # ombros: pele + feixe de talismãs (ossos pendurados, caveirinha, penas)
        tag = s.replace(".", "_")
        sh = V(j["shoulder" + s])
        pa = [ck.ball(P + "body_pad" + tag, b["arm"] * 2.5, sh + V((sx * 0.05, 0, 0.05)), fur, (1.12, 1.08, 0.68)),
              ck.ball(P + "body_pskull" + tag, 0.062, sh + V((sx * 0.09, -0.03, 0.125)), bone, (1.0, 0.95, 1.05)),
              ck.ball(P + "body_pskull_eye_a" + tag, 0.017, sh + V((sx * 0.07, -0.082, 0.135)), glow),
              ck.ball(P + "body_pskull_eye_b" + tag, 0.017, sh + V((sx * 0.115, -0.078, 0.135)), glow)]
        for k in range(5):
            a = -0.9 + k * 0.45
            p = sh + V((sx * (0.13 + 0.02 * math.cos(a)), math.sin(a) * 0.1, 0.07))
            pa.append(ck.tube(P + "body_pbone_%d" % k + tag, p, p + V((sx * 0.035, math.sin(a) * 0.02, -0.12 - 0.03 * (k % 2))), 0.017, 0.012, bone, 6))
        for k in range(3):
            fy = (k - 1) * 0.07
            pa.append(ck.blade(P + "body_pfeather_%d" % k + tag, sh + V((sx * 0.07, fy + 0.03, 0.1)), sh + V((sx * (0.24 - abs(k - 1) * 0.03), fy * 1.6 + 0.09, 0.22)), 0.07, 0.02, t2, (0, 1, 0), 0.55))
        ck._rigid(rs.outward(pa), rig, "upper_arm" + s)
    # ---------------- braços: faixas de couro, pulseira de osso, penas no cotovelo ----------------
    for s, sx in ((".R", -1), (".L", 1)):
        tag = s.replace(".", "_")
        el, wr = V(j["elbow" + s]), V(j["wrist" + s])
        g = [ck.tube(P + "gloves_sleeve" + tag, el.lerp(wr, 0.2), wr + V((0, 0, 0.005)), 0.074, 0.1, t, 12),
             ck.tube(P + "gloves_bangle" + tag, wr + V((0, 0, 0.03)), wr + V((0, 0, 0.0)), 0.108, 0.108, bone, 12),
             ck.tube(P + "gloves_band" + tag, el.lerp(wr, 0.22), el.lerp(wr, 0.34), 0.086, 0.088, t2, 12)]
        for k in range(2):
            g.append(ck.blade(P + "gloves_feather_%d" % k + tag, el.lerp(wr, 0.28) + V((sx * 0.06, 0.03, 0)), el.lerp(wr, 0.28) + V((sx * (0.17 + k * 0.03), 0.1 + k * 0.05, -0.05 - k * 0.05)), 0.06, 0.018, t2 if k else wh, (0, 0.5, 1), 0.55))
        ck._rigid(rs.outward(g), rig, "forearm" + s)
        ck._rigid([ck.ball(P + "gloves_fist" + tag, b["hand"] * 1.26, ck.hand_center(base, s), leather, (1, 1, 1.1))], rig, "hand" + s)
    _a2_boots(ck, base, P, leather, t, t2, bone, fur)


def build_war_pack(ck, base, mats, style):
    """dru_w35 — Matilha de Guerra (Lobo, duas maças)."""
    import ranger_sets as rs
    V = Vector
    rig, body, b, j = base["rig"], base["body"], base["b"], base["j"]
    t, t2, gold, dark, leather, metal = mats["tint"], mats["tint2"], mats["trim"], mats["dark"], mats["leather"], mats["metal"]
    m = _a2_mats(ck)
    bone, fur, glow = m["bone"], m["furk"], m["glow"]
    P = "arm_%s_" % style
    c, r = V(base["head_c"]), b["head"]
    # ---------------- cabeça: cabeça de lobo inteira; mandíbula de cima sobre a testa, a de baixo fecha no queixo ----------------
    head = [ck._shell(P + "head_helm", c, r * 1.17, 0.34, -0.95, -0.5, 0.045, t),
            ck.ball(P + "head_snout", r * 0.47, c + V((0, -r * 1.02, r * 0.68)), t, (0.86, 1.4, 0.56)),
            ck.ball(P + "head_bridge", r * 0.2, c + V((0, -r * 1.15, r * 0.86)), metal, (0.9, 2.2, 0.5)),
            ck.ball(P + "head_nose", r * 0.12, c + V((0, -r * 1.62, r * 0.7)), dark, (1.2, 0.7, 0.8)),
            ck.box(P + "head_brow", (r * 1.5, 0.07, r * 0.16), c + V((0, -r * 1.02, r * 0.44)), metal, 0.02)]
    for sx in (-1, 1):
        head += [ck.ball(P + "head_eye_%d" % sx, r * 0.11, c + V((sx * r * 0.36, -r * 1.1, r * 0.9)), glow, (1.2, 0.8, 0.6)),
                 ck.blade(P + "head_ear_%d" % sx, c + V((sx * r * 0.52, -r * 0.05, r * 0.9)), c + V((sx * r * 0.9, r * 0.1, r * 1.72)), r * 0.52, 0.07, t, (1, 0.3, 0), 0.4),
                 ck.blade(P + "head_ear_in_%d" % sx, c + V((sx * r * 0.55, -r * 0.1, r * 0.95)), c + V((sx * r * 0.86, r * 0.02, r * 1.55)), r * 0.28, 0.05, t2, (1, 0.3, 0), 0.4),
                 # presas de cima: uma grande na frente, duas menores para trás
                 ck.tube(P + "head_fang_a_%d" % sx, c + V((sx * r * 0.24, -r * 1.48, r * 0.52)), c + V((sx * r * 0.22, -r * 1.52, r * 0.14)), r * 0.1, 0.004, bone, 6),
                 ck.tube(P + "head_fang_b_%d" % sx, c + V((sx * r * 0.36, -r * 1.24, r * 0.47)), c + V((sx * r * 0.36, -r * 1.27, r * 0.22)), r * 0.075, 0.004, bone, 6),
                 ck.tube(P + "head_fang_c_%d" % sx, c + V((sx * r * 0.5, -r * 1.02, r * 0.42)), c + V((sx * r * 0.5, -r * 1.05, r * 0.24)), r * 0.06, 0.004, bone, 6),
                 # mandíbula de baixo: barra da orelha ao queixo, presas subindo
                 ck.ball(P + "head_cheek_%d" % sx, r * 0.38, c + V((sx * r * 1.0, -r * 0.4, -r * 0.3)), metal, (0.42, 1.0, 1.05)),
                 ck.tube(P + "head_jaw_%d" % sx, c + V((sx * r * 0.98, -r * 0.45, -r * 0.5)), c + V((sx * r * 0.4, -r * 1.14, -r * 0.74)), r * 0.15, r * 0.12, t, 8),
                 ck.tube(P + "head_jawfang_a_%d" % sx, c + V((sx * r * 0.42, -r * 1.14, -r * 0.7)), c + V((sx * r * 0.46, -r * 1.22, -r * 0.34)), r * 0.09, 0.004, bone, 6),
                 ck.tube(P + "head_jawfang_b_%d" % sx, c + V((sx * r * 0.68, -r * 0.86, -r * 0.6)), c + V((sx * r * 0.72, -r * 0.92, -r * 0.36)), r * 0.065, 0.004, bone, 6)]
    head.append(ck.tube(P + "head_chin", c + V((-r * 0.42, -r * 1.14, -r * 0.74)), c + V((r * 0.42, -r * 1.14, -r * 0.74)), r * 0.12, r * 0.12, t, 8))
    for k in range(7):                   # crina em crista da testa à nuca
        a = -0.55 + k * 0.42
        root = c + V((0, math.sin(a) * r * 1.13, math.cos(a) * r * 1.13))
        head.append(ck.blade(P + "head_mane_%d" % k, root, root + V((0, math.sin(a + 0.5), math.cos(a + 0.5))) * r * (0.78 - abs(k - 2.5) * 0.06), r * 0.5, 0.15,
                             t2, (0, math.cos(a), -math.sin(a)), 0.4))
    ck._rigid(rs.outward(head), rig, "head")
    # ---------------- corpo: couro tachado ----------------
    ck.armor_piece(body, rig, P + "body_main", "torso", t, 0.013, 0.016, 0.03)
    ck.armor_piece(body, rig, P + "body_legs", "legs", leather, 0.008, 0.012)
    d = b["depth"]
    front = -b["chest"] * d - 0.032
    back = b["chest"] * d + 0.03
    zc, zn, zw = ck.Z["chest"], ck.Z["neck"], ck.Z["waist"]
    chest = []
    for sx in (-1, 1):                   # tiras cruzadas com tachas
        p0, p1 = V((sx * 0.15, front + 0.018, zc + 0.15)), V((-sx * 0.13, -b["waist"] * d - 0.03, zw + 0.03))
        chest.append(ck.tube(P + "body_strap_%d" % sx, p0, p1, 0.024, 0.024, dark, 6))
        for k in range(4):
            chest.append(ck.ball(P + "body_stud_%d_%d" % (sx, k), 0.017, p0.lerp(p1, 0.12 + k * 0.25) + V((0, -0.022, 0)), metal))
        chest.append(ck.tube(P + "body_bstrap_%d" % sx, (sx * 0.15, back - 0.015, zc + 0.15), (-sx * 0.13, b["waist"] * d + 0.03, zw + 0.03), 0.024, 0.024, dark, 6))
    chest += [ck.ball(P + "body_skull", 0.062, (0, front - 0.012, zc + 0.01), bone, (1.0, 0.55, 1.1)),      # crânio de lobo no cruzamento
              ck.ball(P + "body_skull_snout", 0.036, (0, front - 0.03, zc - 0.045), bone, (0.8, 0.6, 1.3)),
              ck.ball(P + "body_skull_eye_l", 0.017, (-0.026, front - 0.044, zc + 0.02), glow),
              ck.ball(P + "body_skull_eye_r", 0.017, (0.026, front - 0.044, zc + 0.02), glow)]
    # coleira de cravos
    rw = b["chest"] * 0.6
    col = ck.tube(P + "body_collar", (0, 0.0, zn - 0.085), (0, 0.0, zn - 0.015), rw, rw * 0.94, dark, 14)
    for v in col.data.vertices:
        v.co.y *= 0.88
    chest.append(col)
    for k in range(10):
        a = math.tau * (k + 0.5) / 10
        dv = V((math.cos(a), math.sin(a) * 0.88, 0))
        chest.append(ck.tube(P + "body_collar_spike_%d" % k, dv * rw * 0.96 + V((0, 0, zn - 0.05)), dv * rw * 1.42 + V((0, 0, zn - 0.02)), 0.028, 0.003, metal, 6))
    chest.append(ck.ball(P + "body_collar_tag", 0.03, (0, -rw * 0.9, zn - 0.1), glow, (1.0, 0.5, 1.2)))
    for k in range(5):                   # crina de pele pela espinha
        tt = k / 4.0
        p = V((0, back + 0.02, zn - 0.08 - tt * 0.3))
        chest.append(ck.blade(P + "body_mane_%d" % k, p, p + V((0, 0.13 - tt * 0.03, 0.05)), 0.12, 0.1, t2, (0, 0.3, 1), 0.4))
    ck._rigid(rs.outward(chest), rig, "chest")
    rs.body_belt(ck, base, P + "body_belt", zw - 0.04, zw + 0.035, 1.2, dark)
    wf, wb = -b["waist"] * d * 1.2, b["waist"] * d * 1.2
    hips = [ck.ball(P + "body_buckle", 0.05, (0, wf - 0.008, zw), metal, (1.0, 0.5, 1.0)),
            ck.ball(P + "body_buckle_gem", 0.022, (0, wf - 0.034, zw), glow),
            ck.blade(P + "body_tail", (0, wb + 0.01, zw - 0.02), (0.05, wb + 0.13, zw - 0.36), 0.15, 0.09, fur, (1, 0, 0), 0.5),
            ck.blade(P + "body_tail_tip", (0.035, wb + 0.09, zw - 0.25), (0.055, wb + 0.145, zw - 0.4), 0.09, 0.07, bone, (1, 0, 0), 0.4)]
    for k in range(5):                   # saiote de pele em tiras, tacha em cada uma
        x = (k - 2) * 0.066
        for side, y, sg in (("f", wf - 0.012, -1), ("b", wb + 0.012, 1)):
            if side == "b" and k == 2:
                continue
            hips.append(ck.blade(P + "body_kilt_%s%d" % (side, k), (x, y, zw - 0.03), (x * 1.12, y + sg * 0.02, zw - 0.2), 0.075, 0.018, fur if k % 2 else t, (1, 0, 0), 0.45))
            hips.append(ck.ball(P + "body_kilt_stud_%s%d" % (side, k), 0.014, (x * 1.03, y + sg * 0.014, zw - 0.085), metal))
    ck._rigid(rs.outward(hips), rig, "hips")
    for s, sx in ((".R", -1), (".L", 1)):          # ombreiras com três garras
        tag = s.replace(".", "_")
        sh = V(j["shoulder" + s])
        pa = [ck.ball(P + "body_pauldron" + tag, b["arm"] * 2.65, sh + V((sx * 0.06, 0, 0.055)), t, (1.12, 1.1, 0.68)),
              ck.ball(P + "body_pauldron_rim" + tag, b["arm"] * 2.73, sh + V((sx * 0.06, 0, 0.028)), metal, (1.13, 1.11, 0.15)),
              ck.ball(P + "body_pauldron_fur" + tag, b["arm"] * 2.2, sh + V((sx * 0.03, 0, -0.005)), fur, (1.2, 1.15, 0.5))]
        for k in range(3):
            fy = (k - 1) * 0.075
            pa += rs.curve(ck, P + "body_claw_%d" % k + tag, sh + V((sx * 0.07, fy, 0.1)), sh + V((sx * 0.27, fy * 1.5, 0.19 - abs(k - 1) * 0.03)), (sx * 0.01, 0, 0.09), 0.036, bone, 4, 6)
            pa.append(ck.ball(P + "body_claw_stud_%d" % k + tag, 0.022, sh + V((sx * 0.065, fy, 0.115)), metal))
        ck._rigid(rs.outward(pa), rig, "upper_arm" + s)
    # ---------------- braços: braçadeiras com garras sobre a mão ----------------
    for s, sx in ((".R", -1), (".L", 1)):
        tag = s.replace(".", "_")
        el, wr = V(j["elbow" + s]), V(j["wrist" + s])
        g = [ck.tube(P + "gloves_cuff" + tag, el.lerp(wr, 0.22), wr + V((0, 0, 0.01)), 0.075, 0.094, t, 12),
             ck.tube(P + "gloves_rim" + tag, el.lerp(wr, 0.2), el.lerp(wr, 0.3), 0.095, 0.091, metal, 12),
             ck.tube(P + "gloves_strap" + tag, el.lerp(wr, 0.66), el.lerp(wr, 0.76), 0.097, 0.099, dark, 12)]
        g += rs.fur_ring(ck, P + "gloves_fur" + tag, el.lerp(wr, 0.18), 0.076, 6, 0.045, fur, 0.01, 1.0)
        for k in range(3):
            g.append(ck.ball(P + "gloves_stud_%d" % k + tag, 0.014, el.lerp(wr, 0.71) + V((sx * 0.07, (k - 1) * 0.06, 0)), metal))
        ck._rigid(rs.outward(g), rig, "forearm" + s)
        hc = V(ck.hand_center(base, s))
        hand = [ck.ball(P + "gloves_fist" + tag, b["hand"] * 1.3, hc, leather, (1, 1, 1.1)),
                ck.ball(P + "gloves_plate" + tag, b["hand"] * 1.0, hc + V((sx * b["hand"] * 0.75, 0, 0.02)), metal, (0.5, 1.1, 1.0))]
        for k in range(3):
            fy = (k - 1) * 0.045
            hand.append(ck.tube(P + "gloves_claw_%d" % k + tag, hc + V((sx * b["hand"] * 0.95, fy, 0.0)), hc + V((sx * b["hand"] * 1.0, fy * 1.3 - 0.03, -0.15)), 0.02, 0.003, bone, 6))
        ck._rigid(rs.outward(hand), rig, "hand" + s)
    _a2_boots(ck, base, P, leather, t, dark, metal, fur)


def build_living_mountain(ck, base, mats, style):
    """dru_b35 — Montanha Viva (Urso, malho)."""
    import ranger_sets as rs
    V = Vector
    rig, body, b, j = base["rig"], base["body"], base["b"], base["j"]
    t, t2, gold, dark, leather = mats["tint"], mats["tint2"], mats["trim"], mats["dark"], mats["leather"]
    m = _a2_mats(ck)
    bark, rock, glow = m["bark"], m["rock"], m["glow"]
    P = "arm_%s_" % style
    c, r = V(base["head_c"]), b["head"]
    # ---------------- cabeça: elmo de pedra em lajes, crista de musgo, cristais acesos ----------------
    head = [ck._shell(P + "head_helm", c, r * 1.18, 0.3, -0.85, -0.45, 0.055, t),
            ck.box(P + "head_brow", (r * 2.0, r * 0.5, r * 0.34), c + V((0, -r * 1.0, r * 0.52)), rock, 0.025),
            ck.box(P + "head_cap", (r * 1.5, r * 1.5, r * 0.3), c + V((0, r * 0.05, r * 1.06)), rock, 0.03),
            ck.box(P + "head_nasal", (r * 0.26, 0.07, r * 0.62), c + V((0, -r * 1.2, r * 0.16)), t, 0.02),
            ck.blade(P + "head_crystal", c + V((0, -r * 1.18, r * 0.5)), c + V((0, -r * 1.42, r * 1.2)), r * 0.36, r * 0.26, glow, (1, 0, 0), 0.4)]
    for sx in (-1, 1):
        head += [ck.box(P + "head_cheek_%d" % sx, (0.09, r * 0.72, r * 0.86), c + V((sx * r * 1.12, -r * 0.5, -r * 0.2)), rock, 0.02),
                 ck.box(P + "head_side_%d" % sx, (0.1, r * 0.9, r * 0.5), c + V((sx * r * 1.14, r * 0.25, r * 0.3)), t, 0.02),
                 ck.blade(P + "head_crystal_a_%d" % sx, c + V((sx * r * 0.6, -r * 0.1, r * 1.1)), c + V((sx * r * 1.12, -r * 0.2, r * 1.9)), r * 0.38, r * 0.28, glow, (1, 0, 0), 0.4),
                 ck.blade(P + "head_crystal_b_%d" % sx, c + V((sx * r * 0.85, r * 0.25, r * 0.95)), c + V((sx * r * 1.45, r * 0.4, r * 1.42)), r * 0.26, r * 0.2, glow, (0, 1, 0), 0.4)]
    for k in range(7):                   # crista de musgo da testa à nuca
        a = -0.6 + k * 0.4
        jit = ((k * 37) % 7) / 7.0
        head.append(ck.ball(P + "head_moss_%d" % k, r * (0.3 + 0.1 * jit), c + V((0, math.sin(a) * r * 1.26, math.cos(a) * r * 1.26 + (r * 0.12 if abs(a) < 0.5 else 0))), t2, (1.25, 1.0, 0.75)))
    ck._rigid(rs.outward(head), rig, "head")
    # ---------------- corpo: casca com placas de rocha ----------------
    ck.armor_piece(body, rig, P + "body_main", "torso", bark, 0.016, 0.016, 0.04)
    ck.armor_piece(body, rig, P + "body_legs", "legs", leather, 0.008, 0.012)
    d = b["depth"]
    front = -b["chest"] * d - 0.035
    back = b["chest"] * d + 0.03
    zc, zn, zw = ck.Z["chest"], ck.Z["neck"], ck.Z["waist"]
    chest = [ck.box(P + "body_plate", (0.3, 0.07, 0.2), (0, front + 0.012, zc + 0.03), t, 0.02),
             ck.box(P + "body_plate_l", (0.13, 0.06, 0.11), (-0.08, front - 0.005, zc + 0.09), rock, 0.015),
             ck.box(P + "body_plate_r", (0.11, 0.06, 0.13), (0.09, front - 0.005, zc - 0.0), rock, 0.015),
             ck.blade(P + "body_heart", (0, front - 0.02, zc - 0.07), (0, front - 0.06, zc + 0.1), 0.085, 0.07, glow, (1, 0, 0), 0.5),
             ck.ball(P + "body_moss", 0.06, (-0.09, front - 0.02, zc + 0.15), t2, (1.4, 0.5, 0.6)),
             ck.box(P + "body_gorget", (0.34, b["chest"] * d * 2.2, 0.07), (0, 0, zn - 0.055), t, 0.025)]
    for k in range(2):
        chest.append(ck.box(P + "body_belly_%d" % k, (0.25 - k * 0.04, 0.05, 0.065), (0, -b["waist"] * d * 1.12 - 0.02, zw + 0.115 - k * 0.075), rock if k else t, 0.012))
    # casco de pedra nas costas: domo em lajes, musgo no alto, cristais para trás
    sc = V((0, back + 0.07, zc - 0.01))
    chest.append(ck.ball(P + "body_shell", 0.25, sc, t, (1.12, 0.6, 1.2)))
    chest.append(ck.ball(P + "body_shell_rim", 0.26, sc + V((0, -0.035, 0)), rock, (1.16, 0.3, 1.24)))
    for k, (x, z, w, h) in enumerate(((0, 0.12, 0.2, 0.15), (-0.15, -0.0, 0.14, 0.16), (0.15, -0.0, 0.14, 0.16), (0, -0.14, 0.2, 0.12))):
        chest.append(ck.box(P + "body_shell_slab_%d" % k, (w, 0.07, h), sc + V((x, 0.125 - abs(x) * 0.25 - abs(z) * 0.12, z)), rock, 0.02))
    for k, (x, z, s2) in enumerate(((0.0, 0.3, 0.085), (-0.14, 0.24, 0.07), (0.15, 0.23, 0.075), (-0.24, 0.1, 0.05), (0.25, 0.08, 0.055))):
        chest.append(ck.ball(P + "body_shell_moss_%d" % k, s2, sc + V((x, 0.03, z)), t2, (1.3, 1.1, 0.7)))
    for k, (x, z, ln) in enumerate(((-0.07, 0.03, 0.26), (0.08, 0.06, 0.2), (0.0, -0.1, 0.16))):
        root = sc + V((x, 0.1, z))
        chest.append(ck.blade(P + "body_shell_crystal_%d" % k, root, root + V((x * 1.5, ln, ln * 0.75)), 0.1, 0.08, glow, (1, 0, 0), 0.4))
    ck._rigid(rs.outward(chest), rig, "chest")
    rs.body_belt(ck, base, P + "body_belt", zw - 0.04, zw + 0.035, 1.2, leather)
    wf, wb = -b["waist"] * d * 1.2, b["waist"] * d * 1.2
    hips = [ck.box(P + "body_buckle", (0.1, 0.045, 0.09), (0, wf - 0.008, zw), t, 0.015),
            ck.ball(P + "body_buckle_gem", 0.024, (0, wf - 0.036, zw), glow)]
    for k in range(5):                   # saiote de lascas de casca e pedra
        x = (k - 2) * 0.068
        for side, y in (("f", wf - 0.012), ("b", wb + 0.012)):
            hips.append(ck.blade(P + "body_kilt_%s%d" % (side, k), (x, y, zw - 0.03), (x * 1.12, y, zw - 0.2 + abs(k - 2) * 0.015), 0.08, 0.03, t if k % 2 == 0 else bark, (1, 0, 0), 0.5))
    ck._rigid(rs.outward(hips), rig, "hips")
    for s, sx in ((".R", -1), (".L", 1)):          # ombros: lajes empilhadas, cristais e musgo
        tag = s.replace(".", "_")
        sh = V(j["shoulder" + s])
        pa = [ck.box(P + "body_slab" + tag, (0.27, 0.27, 0.1), sh + V((sx * 0.065, 0, 0.085)), t, 0.025),
              ck.box(P + "body_slab_b" + tag, (0.19, 0.2, 0.085), sh + V((sx * 0.1, 0.02, 0.165)), rock, 0.022),
              ck.box(P + "body_slab_c" + tag, (0.1, 0.24, 0.13), sh + V((sx * 0.2, 0.0, 0.03)), rock, 0.02),
              ck.ball(P + "body_slab_moss" + tag, 0.06, sh + V((sx * 0.02, 0.08, 0.15)), t2, (1.3, 1.2, 0.6)),
              ck.blade(P + "body_slab_crystal_a" + tag, sh + V((sx * 0.1, -0.05, 0.19)), sh + V((sx * 0.25, -0.08, 0.47)), 0.1, 0.08, glow, (0, 1, 0), 0.4),
              ck.blade(P + "body_slab_crystal_b" + tag, sh + V((sx * 0.14, 0.04, 0.18)), sh + V((sx * 0.3, 0.09, 0.35)), 0.075, 0.06, glow, (0, 1, 0), 0.4)]
        ck._rigid(rs.outward(pa), rig, "upper_arm" + s)
    # ---------------- braços: manoplas de pedra ----------------
    for s, sx in ((".R", -1), (".L", 1)):
        tag = s.replace(".", "_")
        el, wr = V(j["elbow" + s]), V(j["wrist" + s])
        g = [ck.tube(P + "gloves_cuff" + tag, el.lerp(wr, 0.2), wr + V((0, 0, 0.01)), 0.082, 0.112, t, 8),
             ck.tube(P + "gloves_rim" + tag, wr + V((0, 0, 0.035)), wr + V((0, 0, 0.0)), 0.122, 0.12, rock, 8),
             ck.ball(P + "gloves_moss" + tag, 0.04, el.lerp(wr, 0.25) + V((sx * 0.06, 0.02, 0)), t2, (1.0, 1.2, 0.7)),
             ck.blade(P + "gloves_crystal" + tag, el.lerp(wr, 0.55) + V((sx * 0.08, 0, 0)), el.lerp(wr, 0.25) + V((sx * 0.2, 0.02, 0.03)), 0.06, 0.05, glow, (0, 1, 0), 0.4)]
        ck._rigid(rs.outward(g), rig, "forearm" + s)
        ck._rigid([ck.ball(P + "gloves_fist" + tag, b["hand"] * 1.5, ck.hand_center(base, s), t, (1, 1, 1.05))], rig, "hand" + s)
    _a2_boots(ck, base, P, t, rock, t2, rock, None, 0.03)


def _a2_weapon_axes(ck, base, hand):
    g = Vector(ck.hand_center(base, ".R" if hand == "main" else ".L"))
    fwd = Vector((0, -0.55, 0.83)).normalized()
    side = Vector((1, 0, 0))
    return g, fwd, side, fwd.cross(side).normalized()


def build_fang_mace(ck, base, mats, style, hand="main"):
    """Maça do Lobo no Ato II: cabeça de ferro escuro com seis presas em mandíbula e miolo aceso (uma em cada mão)."""
    import ranger_sets as rs
    V = Vector
    g, fwd, side, ridge = _a2_weapon_axes(ck, base, hand)
    t, t2, dark, leather = mats["tint"], mats["tint2"], mats["dark"], mats["leather"]
    m = _a2_mats(ck)
    n = "m_%s_%s_" % (style, hand)
    hc = g + fwd * 0.55
    parts = [ck.tube(n + "shaft", g - fwd * 0.13, g + fwd * 0.44, 0.03, 0.028, leather, 8), ck.ball(n + "pommel", 0.05, g - fwd * 0.15, m["bone"], (1, 1, 1.1)),
             ck.tube(n + "collar", g + fwd * 0.36, g + fwd * 0.43, 0.055, 0.06, t, 10),
             ck.ball(n + "core", 0.105, hc, dark), ck.tube(n + "band", hc - fwd * 0.035, hc + fwd * 0.035, 0.112, 0.112, m["glow"], 12),
             ck.ball(n + "cap", 0.05, hc + fwd * 0.11, t, (1, 1, 0.8)), ck.tube(n + "tip", hc + fwd * 0.12, hc + fwd * 0.27, 0.035, 0.003, m["bone"], 6)]
    for k in range(3):
        parts.append(ck.tube(n + "wrap%d" % k, g + fwd * (-0.08 + k * 0.07), g + fwd * (-0.055 + k * 0.07), 0.035, 0.035, t2, 8))
    for k in range(6):                   # presas: saem do pé da cabeça, abrem e voltam para a ponta
        a = math.tau * k / 6
        dv = side * math.cos(a) + ridge * math.sin(a)
        parts += rs.curve(ck, n + "fang%d" % k, hc - fwd * 0.07 + dv * 0.08, hc + fwd * 0.2 + dv * 0.11, dv * 0.12, 0.042, m["bone"], 4, 6)
        parts.append(ck.ball(n + "tuft%d" % k, 0.04, g + fwd * 0.4 + dv * 0.05, m["furk"], (1, 1, 1)))
    obj = ck._join(rs.outward(parts), ("wpn_main_mace_%s" % style) if hand == "main" else ("wpn_off_mace_%s" % style))
    ck._smooth(obj.data)
    ck.skin_rigid(obj, base["rig"], "hand.R" if hand == "main" else "hand.L")
    return obj


def build_stone_maul(ck, base, mats, style):
    """Malho do Urso no Ato II: pedregulho amarrado num tronco, cristais acesos nas duas faces e no topo, musgo."""
    import ranger_sets as rs
    V = Vector
    g, fwd, side, ridge = _a2_weapon_axes(ck, base, "main")
    t, t2, leather = mats["tint"], mats["tint2"], mats["leather"]
    m = _a2_mats(ck)
    n = "m_%s_main_" % style
    hc = g + fwd * 0.98
    parts = [ck.tube(n + "shaft", g - fwd * 0.36, g + fwd * 0.9, 0.036, 0.034, m["bark"], 8), ck.tube(n + "butt", g - fwd * 0.44, g - fwd * 0.35, 0.05, 0.042, m["rock"], 8)]
    for k in range(4):
        parts.append(ck.tube(n + "wrap%d" % k, g + fwd * (-0.26 + k * 0.12), g + fwd * (-0.235 + k * 0.12), 0.041, 0.041, leather, 8))
    parts += [ck.tube(n + "head", hc - side * 0.24, hc + side * 0.24, 0.165, 0.15, t, 7),
              ck.ball(n + "bulge", 0.17, hc + side * 0.03 + fwd * 0.02, t, (1.25, 0.95, 1.05)),
              ck.ball(n + "moss", 0.09, hc + fwd * 0.13 - side * 0.08 + ridge * 0.04, t2, (1.5, 1.0, 0.6)),
              ck.blade(n + "top", hc + fwd * 0.1, hc + fwd * 0.4 + side * 0.04, 0.12, 0.1, m["glow"], side, 0.4)]
    for sx in (-1, 1):
        fc = hc + side * sx * 0.25
        parts += [ck.tube(n + "face%d" % sx, hc + side * sx * 0.22, fc + side * sx * 0.03, 0.15, 0.115, m["rock"], 7),
                  ck.tube(n + "rope%d" % sx, hc + side * sx * 0.09, hc + side * sx * 0.13, 0.172, 0.172, leather, 8),
                  ck.blade(n + "crystal%d" % sx, fc, fc + side * sx * 0.2 + fwd * 0.03, 0.11, 0.09, m["glow"], fwd, 0.4)]
        for k in range(3):
            a = math.tau * k / 3 + 0.5
            dv = fwd * math.cos(a) + ridge * math.sin(a)
            parts.append(ck.blade(n + "shard%d_%d" % (sx, k), fc + dv * 0.07, fc + dv * 0.1 + side * sx * 0.11, 0.05, 0.04, m["glow"], dv, 0.4))
    obj = ck._join(rs.outward(parts), "wpn_main_mace2h_%s" % style)
    ck._smooth(obj.data)
    ck.skin_rigid(obj, base["rig"], "hand.R")
    return obj


ACT2_SETS = {"dru_x35": build_steppe_shaman, "dru_w35": build_war_pack, "dru_b35": build_living_mountain}
ACT2_FORM = {"dru_w35": "wolf", "dru_b35": "bear"}          # armadura de animal do Ato II (form_armor2)
DRU_STAFFS["dru_x35"] = {"head": "ram", "glow": "tint"}


def form_armor2(ck, lp, arm, kind, style, tint, tint2):
    """Armadura de animal do Ato II (mesmos nomes/ossos de form_armor): lobo = barda tachada, crina (tint2), coleira de
    cravos e garras nos ombros; urso = casco de pedra com musgo (tint2) e cristais acesos (tint_glow)."""
    V = Vector
    bulk, hip, hc = _form_geom(kind)
    m = _a2_mats(ck)
    metal = ck.mat("m_metal", ck.METAL, 0.35)
    dark = ck.mat("m_set_dark", (0.2, 0.16, 0.3), 0.5)
    bone, rock, glow = m["bone"], m["rock"], m["glow"]
    P = "frm_%s_" % style
    groups = {}

    def put(slot, bone_name, obj):
        groups.setdefault((slot, bone_name), []).append(obj)

    r = 0.2 * bulk
    back = V((0, 0.0, hip + 0.22 * bulk))
    neck = V((0, -0.5, hip + 0.18))
    if kind == "wolf":
        put("head", "head", ck.ball(P + "head_cap", r * 1.04, hc + V((0, 0.03, 0.07)), tint, (1.0, 0.92, 0.62)))
        put("head", "head", ck.ball(P + "head_brow", r * 0.8, hc + V((0, -r * 0.6, r * 0.42)), metal, (1.05, 0.5, 0.3)))
        put("head", "head", ck.tube(P + "head_band", hc + V((0, -0.08, -0.04)), hc + V((0, -0.16, -0.04)), r * 0.85, r * 0.75, dark, 12))
        put("head", "head", ck.ball(P + "head_gem", 0.04, hc + V((0, -r * 0.78, r * 0.62)), glow))
        for sx in (-1, 1):
            put("head", "head", ck.tube(P + "head_spike_%d" % sx, hc + V((sx * r * 0.6, -r * 0.3, r * 0.55)), hc + V((sx * r * 1.15, -r * 0.55, r * 1.0)), 0.035, 0.004, bone, 6))
        for k in range(3):               # crina em crista na cabeça
            root = hc + V((0, -r * 0.3 + k * r * 0.5, r * 0.72))
            put("head", "head", ck.blade(P + "head_mane_%d" % k, root, root + V((0, r * 0.45, r * 0.8)), r * 0.55, 0.045, tint2, (0, 1, -0.4), 0.4))
        put("body", "body", ck.ball(P + "body_saddle", 0.26 * bulk, back + V((0, 0.02, 0.02)), tint, (0.97, 1.55, 0.36)))
        put("body", "body", ck.ball(P + "body_saddle_rim", 0.27 * bulk, back + V((0, 0.02, -0.02)), dark, (0.99, 1.57, 0.1)))
        for k in range(6):               # crina pela espinha + tachas na barda
            y = -0.33 + k * 0.13
            root = back + V((0, y, 0.085))
            put("body", "body", ck.blade(P + "body_mane_%d" % k, root, root + V((0, 0.13, 0.17 - k * 0.012)), 0.13, 0.045, tint2, (0, 1, -0.5), 0.4))
            for sx in (-1, 1):
                put("body", "body", ck.ball(P + "body_stud_%d_%d" % (k, sx), 0.026, back + V((sx * 0.15, y + 0.06, 0.08)), metal))
        for k in range(10):              # coleira de cravos
            a = math.tau * k / 10
            dv = V((math.cos(a), 0, math.sin(a)))
            p = neck + V((dv.x * 0.2, 0, dv.z * 0.17 + 0.02))
            put("body", "body", ck.ball(P + "body_collar_%d" % k, 0.058, p, dark, (1, 0.8, 1)))
            if dv.z > -0.3:
                put("body", "body", ck.tube(P + "body_collar_spike_%d" % k, p, p + V((dv.x * 0.13, -0.02, dv.z * 0.13)), 0.03, 0.003, metal, 6))
        put("body", "body", ck.ball(P + "body_collar_tag", 0.04, neck + V((0, -0.06, 0.2)), glow))
    else:
        put("head", "head", ck.ball(P + "head_cap", r * 1.08, hc + V((0, 0.04, 0.07)), tint, (1.05, 0.9, 0.7)))
        put("head", "head", ck.box(P + "head_brow", (r * 1.7, r * 0.5, r * 0.3), hc + V((0, -r * 0.55, r * 0.45)), rock, 0.03))
        put("head", "head", ck.tube(P + "head_band", hc + V((0, -0.08, -0.04)), hc + V((0, -0.16, -0.04)), r * 0.85, r * 0.75, rock, 12))
        put("head", "head", ck.blade(P + "head_gem", hc + V((0, -r * 0.5, r * 0.55)), hc + V((0, -r * 0.8, r * 1.35)), r * 0.42, r * 0.32, glow, (1, 0, 0), 0.4))
        for sx in (-1, 1):
            put("head", "head", ck.blade(P + "head_crystal_%d" % sx, hc + V((sx * r * 0.5, 0.0, r * 0.6)), hc + V((sx * r * 0.95, 0.05, r * 1.2)), r * 0.3, r * 0.24, glow, (0, 1, 0), 0.4))
        for k in range(3):
            put("head", "head", ck.ball(P + "head_moss_%d" % k, r * 0.34, hc + V((0, -r * 0.1 + k * r * 0.42, r * 0.78 - k * r * 0.08)), tint2, (1.3, 1.0, 0.7)))
        put("body", "body", ck.ball(P + "body_saddle", 0.28 * bulk, back + V((0, 0.03, 0.03)), tint, (0.98, 1.5, 0.5)))
        put("body", "body", ck.ball(P + "body_saddle_rim", 0.29 * bulk, back + V((0, 0.03, -0.03)), tint2, (1.0, 1.52, 0.12)))
        for k in range(3):               # lajes em duas fileiras, cristais na espinha, musgo entre elas
            y = -0.3 + k * 0.3
            for sx in (-1, 1):
                put("body", "body", ck.box(P + "body_slab_%d_%d" % (k, sx), (0.2 * bulk, 0.24, 0.07), back + V((sx * 0.13 * bulk, y + 0.03, 0.2 - abs(k - 1) * 0.04)), rock, 0.025))
            root = back + V((0, y, 0.2 - abs(k - 1) * 0.03))
            put("body", "body", ck.blade(P + "body_crystal_%d" % k, root, root + V((0.03 * (k - 1), 0.12, 0.3 - abs(k - 1) * 0.06)), 0.16, 0.12, glow, (1, 0, 0), 0.4))
            put("body", "body", ck.ball(P + "body_moss_%d" % k, 0.085, back + V((0.02, y + 0.16, 0.21 - abs(k - 0.5) * 0.03)), tint2, (1.5, 1.0, 0.6)))
        for k in range(10):              # gola de pedras
            a = math.tau * k / 10
            put("body", "body", ck.ball(P + "body_collar_%d" % k, 0.065 * bulk, neck + V((math.cos(a) * 0.2 * bulk, 0, math.sin(a) * 0.17 * bulk + 0.02)), tint2 if k in (2, 3) else rock, (1, 0.8, 1)))
    # patas: braçadeiras (luvas = da frente, botas = de trás)
    for slot, legs in (("gloves", ("leg_fr", "leg_fl")), ("boots", ("leg_br", "leg_bl"))):
        for bone_name in legs:
            sx = 1 if bone_name.endswith("r") else -1
            sy = -1 if slot == "gloves" else 1
            top = V((sx * 0.17 * bulk, sy * 0.36, hip))
            foot = V((sx * 0.19 * bulk, sy * 0.38, 0.07))
            leg_r = (0.09 if kind == "wolf" else 0.075 * 1.25) * bulk
            put(slot, bone_name, ck.tube(P + "%s_band_%s" % (slot, bone_name), top.lerp(foot, 0.45), top.lerp(foot, 0.7), leg_r * 1.25, leg_r * 1.15, tint, 10))
            put(slot, bone_name, ck.tube(P + "%s_rim_%s" % (slot, bone_name), top.lerp(foot, 0.7), top.lerp(foot, 0.75), leg_r * 1.3, leg_r * 1.3, metal if kind == "wolf" else tint2, 10))
            if kind == "wolf":
                for k in range(3):       # cravos na braçadeira
                    a = (k - 1) * 0.8
                    dv = V((sx * math.cos(a), sy * math.sin(a), 0))
                    p = top.lerp(foot, 0.55) + dv * leg_r * 1.15
                    put(slot, bone_name, ck.tube(P + "%s_spike%d_%s" % (slot, k, bone_name), p, p + dv * 0.07 + V((0, 0, 0.02)), 0.022, 0.003, metal, 6))
            if slot == "gloves":
                pad = top + V((0, 0, 0.02))
                put(slot, bone_name, ck.ball(P + "%s_pad_%s" % (slot, bone_name), leg_r * 1.6, pad, tint, (1.0, 1.0, 0.7)))
                if kind == "wolf":       # ombreira com três garras
                    for k in range(3):
                        fy = (k - 1) * 0.07
                        p0 = pad + V((sx * 0.05, fy, 0.07))
                        p1 = pad + V((sx * 0.2, fy * 1.4 + 0.05, 0.15 - abs(k - 1) * 0.02))
                        mid = p0.lerp(p1, 0.5) + V((0, 0, 0.06))
                        put(slot, bone_name, ck.tube(P + "%s_claw%da_%s" % (slot, k, bone_name), p0, mid, 0.034, 0.024, bone, 6))
                        put(slot, bone_name, ck.tube(P + "%s_claw%db_%s" % (slot, k, bone_name), mid, p1, 0.024, 0.003, bone, 6))
                else:                    # laje com cristal
                    put(slot, bone_name, ck.box(P + "%s_slab_%s" % (slot, bone_name), (0.2, 0.22, 0.07), pad + V((sx * 0.04, 0, 0.09)), rock, 0.025))
                    put(slot, bone_name, ck.blade(P + "%s_crystal_%s" % (slot, bone_name), pad + V((sx * 0.06, 0, 0.1)), pad + V((sx * 0.2, 0.03, 0.3)), 0.11, 0.09, glow, (0, 1, 0), 0.4))
    import bmesh
    for (slot, bone_name), objs in groups.items():
        for o in objs:                   # normais para fora (o toon corta a face de trás)
            bm = bmesh.new()
            bm.from_mesh(o.data)
            bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
            bm.to_mesh(o.data)
            bm.free()
        obj = ck._join(objs, "frm_%s_%s_%s" % (style, slot, bone_name))
        ck._smooth(obj.data)
        lp.attach(obj, arm, bone_name)


def register(ck):
    import paladin_sets
    for style, fn in ACT2_SETS.items():                    # Ato II: um visual novo por build (35/40/45 + Ápice)
        ck.SET_STYLES[style] = (lambda st, f: (lambda base, mats: (f(ck, base, mats, st), paladin_sets.join_slots("arm_%s_" % st))))(style, fn)
    ck.SET_WEAPONS["dru_w35_mace"] = lambda base, mats: build_fang_mace(ck, base, mats, "dru_w35")
    ck.SET_WEAPONS["dru_w35_offmace"] = lambda base, mats: build_fang_mace(ck, base, mats, "dru_w35", "off")
    ck.SET_WEAPONS["dru_b35_mace"] = lambda base, mats: build_stone_maul(ck, base, mats, "dru_b35")
    for style, cfg in DRU_SETS.items():
        ck.SET_STYLES[style] = (lambda st, cf: (lambda base, mats: (build(ck, base, mats, st, cf), paladin_sets.join_slots("arm_%s_" % st))))(style, cfg)
    for style, cfg in DRU_STAFFS.items():
        ck.SET_WEAPONS[style + "_staff"] = (lambda st, cf: (lambda base, mats: build_staff(ck, base, mats, st, cf)))(style, cfg)
    for style, cfg in DRU_MACES.items():
        ck.SET_WEAPONS[style + "_mace"] = (lambda st, cf: (lambda base, mats: paladin_sets.build_mace(ck, base, mats, st, cf)))(style, cfg)
        if cfg["type"] == "mace":                # Lobo: a segunda maça, na mão esquerda
            ck.SET_WEAPONS[style + "_offmace"] = (lambda st, cf: (lambda base, mats: paladin_sets.build_mace(ck, base, mats, st, cf, "off")))(style, cfg)


# ---------------------------------------------------------------------------
# Ato III (nível 50, GDD ato3-lendarios-50): UM visual novo por build no tema de Lumeria. Malhas no kit extra
# kit_druid_<sexo>_a3.glb (chibi_kit.A3_STYLES); motivos comuns em lumeria_kit.py. Fora de DRU_SETS e de ACT2_SETS.
#   dru_w50 Lobo = Galope do Desfile: máscara de lobo sorridente em porcelana (orelhas em pé, sorriso de ouro, lágrima na
#           testa), fitas longas (tint2, verde-garrafa) caindo das braçadeiras, guizos nos punhos, tornozelos e cinto, colar
#           de lanterninhas acesas. No lobo (form_wolf) e no Alfa: a mesma máscara, coleira de guizos e lanternas, fitas
#           (form_armor3, malhas frm_dru_w50_*, postas DEPOIS da conta de chão: os clipes não mudam).
def build_parade_gallop(ck, base, mats, style):
    """dru_w50 — Galope do Desfile (Lobo/Fera)."""
    import lumeria_kit as lk
    import berserker_sets as bs
    import elementalist_sets as es
    V = Vector
    rig, body, b, j = base["rig"], base["body"], base["b"], base["j"]
    M = lk.lum_mats(ck, mats)
    t, t2, gold, porc, glow, leather = M["t"], M["t2"], M["gold"], M["porc"], M["glow"], M["leather"]
    P = "arm_%s_" % style
    c, r = V(base["head_c"]), b["head"]
    d = b["depth"]
    front = -b["chest"] * d - 0.03
    back = b["chest"] * d + 0.03
    zc, zn, zw = ck.Z["chest"], ck.Z["neck"], ck.Z["waist"]
    # ---------------- cabeça: cabelo solto, máscara de lobo sorridente, laço de seda na nuca ----------------
    head = es._act2_hair(ck, base, P)
    head += lk.mask(ck, P + "head_mask", c + V((0, -r * 0.97, -r * 0.02)), r * 0.7, M, kind="wolf", tears=(), wide=1.25)
    head.append(ck.tube(P + "head_tie", c + V((0, 0, r * 0.02)), c + V((0, 0, r * 0.16)), r * 1.2, r * 1.19, t2, 18))
    for sx in (-1, 1):
        p0 = c + V((sx * r * 0.1, r * 1.1, r * 0.1))
        head += [lk.silk(ck, P + "head_tail%d" % sx, p0, p0 + V((sx * r * 0.55, r * 0.5, -r * 1.25)), (1, 0, 0), r * 0.24, r * 0.34, t2, (0, r * 0.14, 0), 3),
                 ck.blade(P + "head_bow%d" % sx, p0, p0 + V((sx * r * 0.5, r * 0.12, r * 0.28)), r * 0.42, r * 0.1, t2, (0, 0, 1), 0.55)]
    head += lk.bell(ck, P + "head_bow_bell", c + V((0, r * 1.14, r * 0.1)), r * 0.11, M)
    ck._rigid(bs._outward(head), rig, "head")
    # ---------------- corpo: couro claro, colar de lanterninhas, cinto de guizos, faixa de seda ----------------
    ck.armor_piece(body, rig, P + "body_vest", "torso", t, 0.014, 0.014, 0.025)
    ck.armor_piece(body, rig, P + "body_legs", "legs", leather, 0.008, 0.012)
    chest = [ck.tube(P + "body_collar", V((0, 0, zn - 0.05)), V((0, 0, zn + 0.01)), b["chest"] * 0.7, b["chest"] * 0.52, t2, 14)]
    n = 7
    for k in range(n):                   # colar: lanterninhas penduradas num arco pela frente do peito
        a = math.pi * (1.12 + 0.76 * k / (n - 1))
        p = V((math.cos(a) * b["chest"] * 1.02, math.sin(a) * b["chest"] * d * 1.15 - 0.02, zn - 0.09 - 0.07 * math.sin(math.pi * k / (n - 1))))
        chest += lk.lantern(ck, P + "body_neck_lantern%d" % k, p + V((0, 0, -0.04)), 0.034 if k % 2 == 0 else 0.028, M, hang=p + V((0, 0.03, 0.05)), segs=5)
    chest.append(ck.ball(P + "body_back_knot", 0.05, (0, back + 0.02, zn - 0.08), t2, (1.4, 0.6, 0.8)))
    ck._rigid(bs._outward(chest), rig, "chest")
    bs._belt(ck, base, P + "body_belt", zw - 0.04, zw + 0.03, 1.2, gold)
    wf = -b["waist"] * d * 1.22
    hips = []
    for k in range(5):                   # guizos no cinto
        x = (k - 2) * b["waist"] * 0.5
        y = -math.sqrt(max(0.0, 1.0 - (x / (b["waist"] * 1.26)) ** 2)) * b["waist"] * d * 1.26
        hips += lk.bell(ck, P + "body_belt_bell%d" % k, (x, y - 0.02, zw - 0.065), 0.03, M)
    for side, y in (("f", wf - 0.02), ("b", -wf + 0.02)):
        hips.append(ps_banner(ck, P + "body_loin_" + side, y, zw - 0.03, 0.09, 0.27, 0.016, t))
    for sx in (-1, 1):                   # faixa de seda amarrada no quadril: duas pontas compridas de cada lado
        p0 = V((sx * b["waist"] * 1.2, 0.0, zw - 0.02))
        for i in range(2):
            hips.append(lk.silk(ck, P + "body_sash%d_%d" % (sx, i), p0, p0 + V((sx * (0.1 + i * 0.05), 0.06 - i * 0.14, -0.34 + i * 0.06)), (0.3 * sx, 1, 0), 0.07, 0.1, t2, (sx * 0.04, 0, 0), 3))
    ck._rigid(bs._outward(hips), rig, "hips")
    for s, sx in ((".R", -1), (".L", 1)):                 # braçadeiras de ouro com fitas longas; ombreira de couro com guizos
        tag = s.replace(".", "_")
        sh, el = V(j["shoulder" + s]), V(j["elbow" + s])
        ab = sh.lerp(el, 0.55)
        pa = [ck.ball(P + "body_pad" + tag, b["arm"] * 2.3, sh + V((sx * 0.06, 0, 0.03)), t, (1.15, 1.1, 0.55)),
              ck.tube(P + "body_pad_rim" + tag, sh + V((sx * 0.06, 0, -0.02)), sh + V((sx * 0.06, 0, 0.005)), b["arm"] * 2.62, b["arm"] * 2.5, gold, 12),
              ck.tube(P + "body_armband" + tag, ab + V((0, 0, 0.025)), ab + V((0, 0, -0.025)), b["arm"] * 1.5, b["arm"] * 1.45, gold, 10)]
        for k in range(3):
            a = math.radians(-60 + k * 60)
            pa += lk.bell(ck, P + "body_pad_bell%d%s" % (k, tag), sh + V((sx * (0.06 + math.cos(a) * b["arm"] * 2.6), math.sin(a) * b["arm"] * 2.6, -0.035)), 0.028, M)
        for i, sy in enumerate((-1, 1)):                  # fitas longas das braçadeiras: abrem para fora e para trás
            p0 = ab + V((sx * b["arm"] * 1.35, sy * 0.03, -0.01))
            p1 = p0 + V((sx * (0.2 + i * 0.07), 0.1 + sy * 0.1, -0.5 + i * 0.1))
            pa.append(lk.silk(ck, P + "body_ribbon%d%s" % (i, tag), p0, p1, (0.35 * sx, 1, 0), 0.075, 0.12, t2, (sx * 0.07, 0, 0), 4))
        ck._rigid(bs._outward(pa), rig, "upper_arm" + s)
    lk.limbs(ck, base, mats, P, M, "leather", bells=True, boots_m=leather)


#   dru_b50 Urso = Guarda da Colheita Mascarada: máscara de urso em porcelana (orelhas redondas, focinho curto, lágrima;
#           também no urso: frm_dru_b50_*), ombros largos de casca envernizada em lajes com aro de ouro, lanternas-cabaça
#           acesas na cintura e no ombro esquerdo, fitas de seda (tint2, verde-musgo).
def build_masked_harvest(ck, base, mats, style):
    """dru_b50 — Guarda da Colheita Mascarada (Urso)."""
    import lumeria_kit as lk
    import berserker_sets as bs
    import elementalist_sets as es
    V = Vector
    rig, body, b, j = base["rig"], base["body"], base["b"], base["j"]
    M = lk.lum_mats(ck, mats)
    t, t2, gold, porc, glow, leather = M["t"], M["t2"], M["gold"], M["porc"], M["glow"], M["leather"]
    bark = _lum_bark(ck)
    P = "arm_%s_" % style
    c, r = V(base["head_c"]), b["head"]
    d = b["depth"]
    front = -b["chest"] * d - 0.03
    back = b["chest"] * d + 0.03
    zc, zn, zw = ck.Z["chest"], ck.Z["neck"], ck.Z["waist"]
    wf = -b["waist"] * d * 1.22
    # ---------------- cabeça: cabelo solto, máscara de urso, coroa de espigas/folhas de ouro, laço ----------------
    head = es._act2_hair(ck, base, P)
    head += lk.mask(ck, P + "head_mask", c + V((0, -r * 0.98, -r * 0.02)), r * 0.72, M, kind="bear", tears=(1,), wide=1.28, tear_len=0.3)
    head.append(ck.tube(P + "head_tie", c + V((0, 0, r * 0.3)), c + V((0, 0, r * 0.46)), r * 1.14, r * 1.1, t2, 18))
    for k in range(5):                   # folhas largas de ouro e porcelana em leque atrás da faixa (coroa da colheita)
        a = math.radians(-64 + k * 32)
        root = c + V((math.sin(a) * r * 0.9, r * 0.4, r * 0.42 + math.cos(a) * r * 0.42))
        head.append(ck.blade(P + "head_leaf%d" % k, root, root + V((math.sin(a) * r * 0.62, r * 0.3, math.cos(a) * r * 0.62 + r * 0.08)), r * 0.52, r * 0.08, gold if k % 2 == 0 else porc, (math.cos(a), 0, -math.sin(a)), 0.45))
    for sx in (-1, 1):
        p0 = c + V((sx * r * 0.1, r * 1.1, r * 0.36))
        head.append(lk.silk(ck, P + "head_tail%d" % sx, p0, p0 + V((sx * r * 0.5, r * 0.5, -r * 1.3)), (1, 0, 0), r * 0.26, r * 0.36, t2, (0, r * 0.14, 0), 3))
    ck._rigid(bs._outward(head), rig, "head")
    # ---------------- corpo: couro claro, gola de seda, colar de cabacinhas, cinto de lanternas-cabaça ----------------
    ck.armor_piece(body, rig, P + "body_vest", "torso", t, 0.016, 0.014, 0.03)
    ck.armor_piece(body, rig, P + "body_legs", "legs", leather, 0.008, 0.012)
    chest = [ck.tube(P + "body_collar", V((0, 0, zn - 0.05)), V((0, 0, zn + 0.015)), b["chest"] * 0.72, b["chest"] * 0.52, t2, 14),
             ck.ball(P + "body_breast", 1.0, (0, front + 0.02, zc + 0.01), bark, (b["chest"] * 0.7, 0.045, 0.13)),
             ck.ball(P + "body_breast_rim", 1.0, (0, front + 0.03, zc + 0.01), gold, (b["chest"] * 0.77, 0.035, 0.143)),
             ck.ball(P + "body_breast_tear", 0.026, (0, front - 0.022, zc + 0.02), glow, (0.8, 0.6, 1.9)),
             ck.ball(P + "body_back_plate", 1.0, (0, back - 0.01, zc + 0.02), bark, (b["chest"] * 0.8, 0.06, 0.17)),
             ck.ball(P + "body_back_rim", 1.0, (0, back - 0.022, zc + 0.02), gold, (b["chest"] * 0.87, 0.05, 0.184))]
    ck._rigid(bs._outward(chest), rig, "chest")
    bs._belt(ck, base, P + "body_belt", zw - 0.04, zw + 0.03, 1.2, gold)
    hips = []
    for k, fx in enumerate((-1.0, -0.55, 0.55, 1.0)):     # lanternas-cabaça penduradas no cinto
        x = fx * b["waist"] * 1.1
        y = -math.sqrt(max(0.0, 1.0 - (x / (b["waist"] * 1.27)) ** 2)) * b["waist"] * d * 1.27
        hips += lk.gourd(ck, P + "body_gourd%d" % k, (x, y - 0.04, zw - 0.13), 0.05 if k in (0, 3) else 0.042, M, hang=(x, y - 0.01, zw - 0.03))
    for side, y in (("f", wf - 0.02), ("b", -wf + 0.02)):
        hips.append(ps_banner(ck, P + "body_loin_" + side, y, zw - 0.03, 0.09, 0.28, 0.016, t2))
    for sx in (-1, 1):
        p0 = V((sx * b["waist"] * 1.2, 0.03, zw - 0.02))
        hips.append(lk.silk(ck, P + "body_sash%d" % sx, p0, p0 + V((sx * 0.1, 0.1, -0.34)), (0.3 * sx, 1, 0), 0.08, 0.11, t2, (sx * 0.04, 0, 0), 3))
    ck._rigid(bs._outward(hips), rig, "hips")
    for s, sx in ((".R", -1), (".L", 1)):                 # ombros de casca envernizada: três lajes sobrepostas com aro de ouro
        tag = s.replace(".", "_")
        sh = V(j["shoulder" + s])
        pa = []
        for k in range(3):
            pc = sh + V((sx * (0.04 + k * 0.075), 0, 0.075 - k * 0.045))
            pa += [ck.ball(P + "body_bark%d%s" % (k, tag), 1.0, pc, bark, (0.13 - k * 0.008, 0.2 - k * 0.015, 0.07)),
                   ck.ball(P + "body_bark_rim%d%s" % (k, tag), 1.0, pc + V((0, 0, -0.022)), gold, (0.14 - k * 0.008, 0.212 - k * 0.015, 0.05))]
        top = sh + V((sx * 0.06, 0, 0.14))
        if s == ".L":
            pa += lk.gourd(ck, P + "body_shoulder_gourd", top + V((sx * 0.03, 0, 0.09)), 0.085, M)
        else:
            pa += [ck.blade(P + "body_leaf%d" % k, top + V((0, (k - 1) * 0.05, -0.02)), top + V((sx * 0.1, (k - 1) * 0.13, 0.15)), 0.09, 0.02, gold, (0, 1, 0), 0.45) for k in range(3)]
        for i, sy in enumerate((-1, 1)):
            p0 = sh + V((sx * 0.22, sy * 0.1, -0.02))
            pa.append(lk.silk(ck, P + "body_ribbon%d%s" % (i, tag), p0, p0 + V((sx * 0.1, sy * 0.06 + 0.04, -0.32 - i * 0.06)), (1, sy * 0.7, 0), 0.08, 0.11, t2, (sx * 0.04, 0, 0), 3))
        ck._rigid(bs._outward(pa), rig, "upper_arm" + s)
    lk.limbs(ck, base, mats, P, M, "leather", ribbon=0.5, boots_m=leather)


def _lum_bark(ck):
    """Casca envernizada (castanho-mel lustroso) do conjunto do Urso."""
    return ck.mat("m_lum_bark", (0.4, 0.22, 0.1), 0.25)


def ps_banner(ck, name, y, top, half_w, length, thick, material):
    import paladin_sets
    return paladin_sets._banner(ck, name, y, top, half_w, length, thick, material)


def form_armor3(ck, lp, arm, kind, style, tint, tint2):
    """Armadura de animal do nível 50 (mesmos nomes/ossos de form_armor). Lobo: máscara de porcelana sorridente sobre o
    focinho, coleira de guizos com lanterninhas, manta de seda (tint2) com barra de ouro, fitas nas patas."""
    import lumeria_kit as lk
    V = Vector
    bulk, hip, hc = _form_geom(kind)
    M = lk.lum_mats(ck, {"tint": tint, "tint2": tint2, "dark": ck.mat("m_set_dark", (0.2, 0.16, 0.3), 0.5),
                         "metal": ck.mat("m_metal", ck.METAL, 0.35), "leather": ck.mat("m_leather", ck.LEATHER, 0.8)})
    gold, porc, glow = M["gold"], M["porc"], M["glow"]
    groups = {}

    def put(slot, bone_name, objs):
        groups.setdefault((slot, bone_name), []).extend(objs if isinstance(objs, list) else [objs])

    P = "frm_%s_" % style
    r = 0.2 * bulk
    back = V((0, 0.0, hip + 0.22 * bulk))
    neck = V((0, -0.5, hip + 0.18))
    if kind == "bear":
        _bear_armor3(ck, lk, M, put, P, bulk, hip, hc, tint, tint2)
        _form_join(ck, lp, arm, groups, style)
        return
    # cabeça: máscara inclinada sobre a testa e o focinho (orelhas e sorriso lidos de cima), laço na nuca
    put("head", "head", lk.mask(ck, P + "head_mask", hc + V((0, -r * 0.5, r * 0.52)), r * 0.86, M, facing=(0, -0.62, 0.78), kind="wolf", tears=(), wide=1.2))
    put("head", "head", ck.tube(P + "head_tie", hc + V((0, r * 0.3, -r * 0.2)), hc + V((0, r * 0.45, -r * 0.2)), r * 1.0, r * 1.02, tint2, 12))
    for sx in (-1, 1):
        p0 = hc + V((sx * r * 0.2, r * 0.6, r * 0.75))
        put("head", "head", ck.blade(P + "head_bow%d" % sx, p0, p0 + V((sx * r * 0.9, r * 0.5, r * 0.5)), r * 0.7, r * 0.14, tint2, (0, 1, 0.3), 0.55))
    # corpo: manta de seda com barra de ouro, lágrima pintada na anca, fitas ao vento, coleira
    put("body", "body", ck.ball(P + "body_cloth", 0.26 * bulk, back + V((0, 0.04, 0.02)), tint2, (0.99, 1.5, 0.38)))
    put("body", "body", ck.ball(P + "body_cloth_rim", 0.27 * bulk, back + V((0, 0.04, -0.02)), gold, (1.01, 1.53, 0.1)))
    put("body", "body", ck.ball(P + "body_dish", 0.13 * bulk, back + V((0, 0.02, 0.085)), porc, (1.0, 1.25, 0.3)))
    put("body", "body", ck.ball(P + "body_dish_tear", 0.035, back + V((0, 0.0, 0.125)), glow, (0.7, 1.9, 0.5)))
    for sx in (-1, 1):
        for i in range(2):
            p0 = back + V((sx * 0.2, 0.18 + i * 0.14, 0.02))
            put("body", "body", lk.silk(ck, P + "body_ribbon%d_%d" % (sx, i), p0, p0 + V((sx * 0.16, 0.34, -0.1 + i * 0.12)), (0, 0.2, 1), 0.08, 0.12, tint2, (sx * 0.05, 0, 0.04), 3))
    for k in range(10):                  # coleira: guizos e, por cima do pescoço, lanterninhas
        a = math.tau * k / 10
        dv = V((math.cos(a), 0, math.sin(a)))
        p = neck + V((dv.x * 0.2, 0, dv.z * 0.17 + 0.02))
        put("body", "body", ck.ball(P + "body_collar%d" % k, 0.05, p, tint, (1, 0.8, 1)))
        if dv.z > 0.2 and k % 2 == 0:
            put("body", "body", lk.lantern(ck, P + "body_collar_lantern%d" % k, p + dv * 0.09 + V((0, 0, 0.02)), 0.05, M, segs=5))
        elif dv.z > -0.5:
            put("body", "body", lk.bell(ck, P + "body_collar_bell%d" % k, p + dv * 0.06, 0.036, M))
    # patas: braçadeira de seda com aro de ouro e um guizo; nas da frente, pires no ombro com duas fitas
    for slot, legs in (("gloves", ("leg_fr", "leg_fl")), ("boots", ("leg_br", "leg_bl"))):
        for bone_name in legs:
            sx = 1 if bone_name.endswith("r") else -1
            sy = -1 if slot == "gloves" else 1
            top = V((sx * 0.17 * bulk, sy * 0.36, hip))
            foot = V((sx * 0.19 * bulk, sy * 0.38, 0.07))
            leg_r = 0.09 * bulk
            put(slot, bone_name, ck.tube(P + "%s_band_%s" % (slot, bone_name), top.lerp(foot, 0.5), top.lerp(foot, 0.68), leg_r * 1.22, leg_r * 1.14, tint2, 10))
            put(slot, bone_name, ck.tube(P + "%s_rim_%s" % (slot, bone_name), top.lerp(foot, 0.68), top.lerp(foot, 0.73), leg_r * 1.28, leg_r * 1.28, gold, 10))
            put(slot, bone_name, lk.bell(ck, P + "%s_bell_%s" % (slot, bone_name), top.lerp(foot, 0.6) + V((sx * leg_r * 1.4, 0, 0)), 0.032, M))
            if slot == "gloves":
                pad = top + V((sx * 0.02, 0, 0.04))
                put(slot, bone_name, lk.saucers(ck, P + "%s_dish_%s" % (slot, bone_name), pad, leg_r * 1.7, 2, M, 0.04, 0.28, (sx * 0.5, 0, 1), [porc, tint]))
                p0 = pad + V((sx * 0.1, 0.02, 0.02))
                put(slot, bone_name, lk.silk(ck, P + "%s_ribbon_%s" % (slot, bone_name), p0, p0 + V((sx * 0.14, 0.3, 0.02)), (0, 0.2, 1), 0.07, 0.1, tint2, (sx * 0.04, 0, 0.03), 3))
    _form_join(ck, lp, arm, groups, style)


def _form_join(ck, lp, arm, groups, style):
    """Fecha a armadura de animal do 50: normais para fora, uma malha por (slot, osso), presa ao osso."""
    import bmesh
    for (slot, bone_name), objs in groups.items():
        for o in objs:                   # normais para fora (o toon corta a face de trás)
            bm = bmesh.new()
            bm.from_mesh(o.data)
            bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
            bm.to_mesh(o.data)
            bm.free()
        obj = ck._join(objs, "frm_%s_%s_%s" % (style, slot, bone_name))
        ck._smooth(obj.data)
        lp.attach(obj, arm, bone_name)


def _bear_armor3(ck, lk, M, put, P, bulk, hip, hc, tint, tint2):
    """Urso do nível 50 (dru_b50): máscara de urso em porcelana sobre a testa e o focinho, lajes de casca envernizada com
    aro de ouro no lombo, coleira de seda com lanternas-cabaça, fitas verde-musgo, braçadeiras de casca nas patas."""
    V = Vector
    gold, porc, glow = M["gold"], M["porc"], M["glow"]
    bark = _lum_bark(ck)
    r = 0.2 * bulk
    back = V((0, 0.0, hip + 0.22 * bulk))
    neck = V((0, -0.5, hip + 0.18))
    mask = lk.mask(ck, P + "head_mask", hc + V((0, -r * 0.42, r * 0.56)), r * 0.84, M, facing=(0, -0.6, 0.8), kind="bear", tears=(1,), wide=1.22, tear_len=0.3)
    # Onda 4: o focinho e o nariz DE VERDADE do urso saíam por baixo da máscara (ela fica deitada na testa). O focinho pintado
    # da máscara sai e entra uma luva de porcelana com aro de ouro e nariz de tinta POR CIMA do focinho do bicho (medidas de
    # mob_kit.quadruped: focinho 0,12*bulk em hc+(0,-0.2,-0.05), nariz 0,045*bulk em hc+(0,-0.32*bulk,-0.01)).
    import bpy
    for o in [o for o in mask if o.name.endswith(("_snout", "_nose", "_muzzle"))]:
        mask.remove(o)
        bpy.data.objects.remove(o, do_unlink=True)
    put("head", "head", mask)
    put("head", "head", [ck.ball(P + "head_snout", 1.0, hc + V((0, -0.2, -0.045)), M["porc"], (0.09 * bulk, 0.136 * bulk, 0.083 * bulk)),
                         ck.tube(P + "head_snout_rim", hc + V((0, -0.285, -0.045)), hc + V((0, -0.255, -0.045)), 0.128, 0.134, gold, 10),
                         ck.ball(P + "head_nose", 0.055 * bulk, hc + V((0, -0.32 * bulk, -0.008)), M["ink"], (1.1, 1.0, 0.95)),
                         ck.tube(P + "head_muzzle", hc + V((0, -0.2 - 0.136 * bulk + 0.012, -0.06)), hc + V((0, -0.2 - 0.118 * bulk, -0.12)), 0.012, 0.012, gold, 5)])
    put("head", "head", ck.tube(P + "head_tie", hc + V((0, r * 0.32, -r * 0.2)), hc + V((0, r * 0.47, -r * 0.2)), r * 1.02, r * 1.04, tint2, 12))
    for sx in (-1, 1):
        p0 = hc + V((sx * r * 0.2, r * 0.62, r * 0.8))
        put("head", "head", ck.blade(P + "head_bow%d" % sx, p0, p0 + V((sx * r * 0.9, r * 0.5, r * 0.45)), r * 0.7, r * 0.14, tint2, (0, 1, 0.3), 0.55))
    for k in range(3):                   # lombo: três lajes de casca sobrepostas, da cernelha à anca, com aro de ouro e fita de seda entre elas
        pc = back + V((0, -0.2 + k * 0.24, 0.035 - k * 0.012))
        put("body", "body", ck.ball(P + "body_bark%d" % k, 1.0, pc, bark, (0.27 * bulk * (1.0 - k * 0.07), 0.19, 0.075 * bulk)))
        put("body", "body", ck.ball(P + "body_bark_rim%d" % k, 1.0, pc + V((0, 0, -0.022)), gold, (0.285 * bulk * (1.0 - k * 0.07), 0.2, 0.055 * bulk)))
    put("body", "body", ck.ball(P + "body_dish", 0.11 * bulk, back + V((0, -0.2, 0.1)), porc, (1.0, 1.1, 0.32)))
    put("body", "body", ck.ball(P + "body_dish_tear", 0.035, back + V((0, -0.2, 0.14)), glow, (0.7, 1.9, 0.5)))
    for sx in (-1, 1):
        put("body", "body", lk.gourd(ck, P + "body_gourd%d" % sx, back + V((sx * 0.33 * bulk, 0.06, -0.1)), 0.075, M, hang=back + V((sx * 0.25 * bulk, 0.06, 0.03))))
        for i in range(2):
            p0 = back + V((sx * 0.26 * bulk, 0.2 + i * 0.16, 0.0))
            put("body", "body", lk.silk(ck, P + "body_ribbon%d_%d" % (sx, i), p0, p0 + V((sx * 0.14, 0.3, -0.12 + i * 0.1)), (0, 0.2, 1), 0.09, 0.13, tint2, (sx * 0.05, 0, 0.04), 3))
    for k in range(10):                  # coleira de seda: cabacinhas acesas por cima do pescoço, contas de ouro embaixo
        a = math.tau * k / 10
        dv = V((math.cos(a), 0, math.sin(a)))
        p = neck + V((dv.x * 0.2 * bulk, 0, dv.z * 0.17 * bulk + 0.02))
        put("body", "body", ck.ball(P + "body_collar%d" % k, 0.055, p, tint2, (1, 0.8, 1)))
        if dv.z > 0.2 and k % 2 == 0:
            put("body", "body", lk.gourd(ck, P + "body_collar_gourd%d" % k, p + dv * 0.1 + V((0, 0, 0.02)), 0.055, M))
        elif dv.z > -0.5:
            put("body", "body", ck.ball(P + "body_collar_bead%d" % k, 0.034, p + dv * 0.06, gold))
    for slot, legs in (("gloves", ("leg_fr", "leg_fl")), ("boots", ("leg_br", "leg_bl"))):
        for bone_name in legs:
            sx = 1 if bone_name.endswith("r") else -1
            sy = -1 if slot == "gloves" else 1
            top = V((sx * 0.17 * bulk, sy * 0.36, hip))
            foot = V((sx * 0.19 * bulk, sy * 0.38, 0.07))
            leg_r = 0.09 * bulk
            put(slot, bone_name, ck.tube(P + "%s_band_%s" % (slot, bone_name), top.lerp(foot, 0.48), top.lerp(foot, 0.7), leg_r * 1.24, leg_r * 1.16, bark, 10))
            put(slot, bone_name, ck.tube(P + "%s_rim_%s" % (slot, bone_name), top.lerp(foot, 0.7), top.lerp(foot, 0.75), leg_r * 1.3, leg_r * 1.3, gold, 10))
            put(slot, bone_name, ck.ball(P + "%s_tear_%s" % (slot, bone_name), 0.026, top.lerp(foot, 0.58) + V((sx * leg_r * 1.25, 0, 0)), glow, (0.6, 1.0, 1.7)))
            if slot == "gloves":
                pad = top + V((sx * 0.03, 0, 0.05))
                put(slot, bone_name, ck.ball(P + "%s_pad_%s" % (slot, bone_name), 1.0, pad, bark, (leg_r * 1.5, leg_r * 1.9, leg_r * 0.8)))
                put(slot, bone_name, ck.ball(P + "%s_pad_rim_%s" % (slot, bone_name), 1.0, pad + V((0, 0, -0.02)), gold, (leg_r * 1.62, leg_r * 2.02, leg_r * 0.6)))
                p0 = pad + V((sx * 0.1, 0.02, 0.0))
                put(slot, bone_name, lk.silk(ck, P + "%s_ribbon_%s" % (slot, bone_name), p0, p0 + V((sx * 0.14, 0.3, 0.0)), (0, 0.2, 1), 0.08, 0.11, tint2, (sx * 0.04, 0, 0.03), 3))


def _paper_lantern(ck, name, c, s, M, hang=None):
    """Lanterna de papel (meia-altura ~s): bojo aceso (tint_glow), tampas de ouro velho e borla de seda (tint2)."""
    V = Vector
    c = V(c)
    gold = M["gold"]
    out = [ck.ball(name + "_paper", s * 0.82, c, M["glow"], (1, 1, 1.2)),
           ck.tube(name + "_top", c + V((0, 0, s * 0.82)), c + V((0, 0, s * 1.02)), s * 0.5, s * 0.34, gold, 6),
           ck.tube(name + "_bottom", c + V((0, 0, -s * 1.02)), c + V((0, 0, -s * 0.82)), s * 0.34, s * 0.5, gold, 6),
           ck.tube(name + "_tassel", c + V((0, 0, -s * 1.7)), c + V((0, 0, -s * 1.02)), s * 0.2, s * 0.08, M["t2"], 5)]
    if hang is not None:
        out.append(ck.tube(name + "_hang", V(hang), c + V((0, 0, s * 1.0)), max(s * 0.07, 0.006), max(s * 0.07, 0.006), gold, 4))
    return out


#   dru_x50 Xamã = Céu de Lanternas: CHAPÉU de abas largas de seda (tint2, índigo), inclinado para trás, com 6 lanternas de
#           papel acesas penduradas na aba, estrelas de ouro e uma lua crescente no alto; máscara de LUA (metade porcelana
#           com lágrima, metade noite com estrelas); manto de seda estrelado pelas costas até a canela.
def build_lantern_sky(ck, base, mats, style):
    """dru_x50 — Céu de Lanternas (Xamã, cajado)."""
    import lumeria_kit as lk
    import berserker_sets as bs
    import elementalist_sets as es
    from mathutils import Quaternion
    V = Vector
    rig, body, b, j = base["rig"], base["body"], base["b"], base["j"]
    M = lk.lum_mats(ck, mats)
    t, t2, gold, porc, glow, silk = M["t"], M["t2"], M["gold"], M["porc"], M["glow"], M["silk"]
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
    ck.skirt(P + "body_skirt", b, body, rig, t, 0.1, 1.6)
    bs._belt(ck, base, P + "body_belt", zw - 0.04, zw + 0.035, 1.21, gold)
    # ---------------- cabeça: cabelo solto, chapéu de abas largas inclinado, lanternas na aba, máscara de lua ----------------
    head = es._act2_hair(ck, base, P)
    q = Quaternion((1, 0, 0), math.radians(-13))          # a frente da aba sobe: o rosto aparece na câmera alta
    hat0 = c + V((0, r * 0.05, r * 0.4))
    R = r * 1.95

    def hp(x, y, z):
        return hat0 + q @ V((x, y, z))

    hat = [ck.tube(P + "head_brim", V((0, 0, 0)), V((0, 0, r * 0.26)), R, r * 1.1, t2, 18),
           ck.tube(P + "head_brim_rim", V((0, 0, -r * 0.03)), V((0, 0, r * 0.04)), R * 1.03, R * 1.02, gold, 18),
           ck.tube(P + "head_crown", V((0, 0, r * 0.2)), V((0, 0, r * 1.0)), r * 1.14, r * 0.36, t2, 18),
           ck.tube(P + "head_crown_band", V((0, 0, r * 0.22)), V((0, 0, r * 0.44)), r * 1.18, r * 0.95, gold, 18),
           ck.ball(P + "head_crown_knob", r * 0.16, V((0, 0, r * 1.06)), gold)]
    for k in range(5):                   # lua crescente de ouro em pé no alto do chapéu
        a0, a1 = math.radians(-150 + k * 60), math.radians(-150 + (k + 1) * 60)
        rr = r * 0.36
        m0 = V((math.sin(a0) * rr, 0, r * 1.5 - math.cos(a0) * rr))
        m1 = V((math.sin(a1) * rr, 0, r * 1.5 - math.cos(a1) * rr))
        w0, w1 = (0.02 + 0.09 * math.sin(math.pi * k / 5)) * r, (0.02 + 0.09 * math.sin(math.pi * (k + 1) / 5)) * r
        hat.append(ck.tube(P + "head_moon%d" % k, m0, m1, w0, w1, gold, 6))
    hat.append(ck.ball(P + "head_moon_star", r * 0.1, V((0, 0, r * 1.52)), glow))
    for k in range(6):                   # estrelas de ouro pintadas na aba, entre as lanternas
        a = math.tau * k / 6
        rr = r * 1.45
        hat.append(ck.ball(P + "head_star%d" % k, r * 0.1, V((math.sin(a) * rr, -math.cos(a) * rr, r * 0.26 * (R - rr) / (R - r * 1.1) + r * 0.01)), gold if k % 2 else glow, (1, 1, 0.4)))
    for o in hat:
        for v in o.data.vertices:
            v.co = hat0 + q @ v.co
    head += hat
    for k in range(6):                   # lanternas de papel penduradas na beira da aba (nenhuma bem na frente do rosto)
        a = math.tau * (k + 0.5) / 6
        s_ = r * (0.25 if k % 2 == 0 else 0.21)
        top = hp(math.sin(a) * R * 0.97, -math.cos(a) * R * 0.97, -r * 0.02)
        head += _paper_lantern(ck, P + "head_lantern%d" % k, top + V((0, 0, -r * 0.2 - s_)), s_, M, hang=top)
    s_ = r * 0.66
    mc = c + V((0, -r * 1.0, -r * 0.08))
    wx, dy = 0.82 * 1.18 * s_, 0.34 * s_
    head += lk.mask(ck, P + "head_mask", mc, s_, M, tears=(-1,), wide=1.18, tear_len=0.4)
    night = [ck.ball(P + "head_mask_night", 1.0, (0.42 * wx, -0.02 * s_, 0), silk, (0.7 * wx, dy * 1.25, 0.9 * s_)),
             ck.ball(P + "head_mask_lid", s_ * 0.14, (0.5 * wx, -dy * 1.22 - 0.01 * s_, 0.14 * s_), gold, (1.3, 0.5, 0.2))]
    for k, (x, z) in enumerate(((0.3, 0.5), (0.72, -0.2), (0.4, -0.5))):
        night.append(ck.ball(P + "head_mask_star%d" % k, s_ * 0.07, (x * wx, -dy * 1.25 * math.sqrt(max(0.0, 1.0 - ((x - 0.42) / 0.7) ** 2 - (z / 0.9) ** 2)) - 0.02 * s_, z * s_), gold))
    head += lk.place(night, mc)
    ck._rigid(bs._outward(head), rig, "head")
    # ---------------- corpo: capelinha, broche de lua, manto estrelado nas costas (pesos do corpo) ----------------
    cape = ck.tube(P + "body_mantle", V((0, 0, zn - 0.14)), V((0, 0, zn + 0.03)), b["shoulder"] * 1.36, b["chest"] * 0.55, t2, 16)
    hem = ck.tube(P + "body_mantle_hem", V((0, 0, zn - 0.155)), V((0, 0, zn - 0.13)), b["shoulder"] * 1.4, b["shoulder"] * 1.38, gold, 16)
    for o in (cape, hem):
        for v in o.data.vertices:
            v.co.y *= 0.8
    chest = [cape, hem,
             ck.ball(P + "body_brooch", 0.045, (0, front - 0.055, zn - 0.09), porc, (1, 0.5, 1)),
             ck.ball(P + "body_brooch_night", 0.04, (0.014, front - 0.062, zn - 0.085), silk, (1, 0.5, 1)),
             ck.ball(P + "body_brooch_tear", 0.016, (-0.03, front - 0.075, zn - 0.1), glow, (0.8, 0.6, 1.6))]
    for k in range(7):                   # estrelas na capelinha
        a = math.radians(-135 + k * 45)
        chest.append(ck.ball(P + "body_mantle_star%d" % k, 0.022, (math.sin(a) * b["shoulder"] * 1.04, -math.cos(a) * b["shoulder"] * 0.83, zn - 0.075), glow if k % 2 == 0 else gold, (1, 1, 0.8)))
    ck._rigid(bs._outward(chest), rig, "chest")
    p0, p1 = V((0, back + 0.06, zn - 0.06)), V((0, back + 0.34, 0.13))
    train = [lk.silk(ck, P + "body_cloak", p0, p1, (1, 0, 0), 0.4, 0.74, t2, (0, 0, 0), 6, 0.016),
             lk.silk(ck, P + "body_cloak_hem", p0.lerp(p1, 0.93), p1 + (p1 - p0) * 0.03, (1, 0, 0), 0.75, 0.78, gold, (0, 0, 0), 1, 0.02)]
    stars = ((-0.5, 0.2), (0.45, 0.14), (0.0, 0.34), (-0.62, 0.5), (0.55, 0.46), (0.12, 0.6), (-0.3, 0.72), (0.6, 0.78), (-0.7, 0.84), (0.2, 0.86))
    nrm = (p1 - p0).cross(V((1, 0, 0))).normalized()
    if nrm.y < 0:
        nrm = -nrm
    for k, (fx, fk) in enumerate(stars):
        w = 0.4 + (0.74 - 0.4) * fk
        train.append(ck.ball(P + "body_cloak_star%d" % k, 0.024 if k % 3 else 0.034, p0.lerp(p1, fk) + V((fx * w * 0.5, 0, 0)) + nrm * 0.012, glow if k % 2 == 0 else gold, (1, 0.5, 1)))
    lk.skinned(ck, base, bs._outward(train))
    hips = [lk.silk(ck, P + "body_sash%d" % sx, (sx * 0.05, wf - 0.02, zw - 0.02), (sx * 0.09, wf - 0.075, zw - 0.34), (1, 0, 0), 0.08, 0.1, t2, (0, -0.012, 0), 3) for sx in (-1, 1)]
    hips.append(ck.ball(P + "body_buckle", 0.04, (0, wf - 0.014, zw), gold, (1.1, 0.5, 1.1)))
    hips += _paper_lantern(ck, P + "body_hip_lantern", (b["waist"] * 1.36, -0.02, zw - 0.15), 0.05, M, hang=(b["waist"] * 1.26, -0.02, zw - 0.02))
    ck._rigid(bs._outward(hips), rig, "hips")
    lk.limbs(ck, base, mats, P, M, "cloth", boots_m=porc)


ACT3_SETS = {"dru_w50": build_parade_gallop, "dru_b50": build_masked_harvest, "dru_x50": build_lantern_sky}
ACT3_FORM = {"dru_w50": "wolf", "dru_b50": "bear"}          # armadura de animal do nível 50 (form_armor3); Ent e Pássaro: druid_ancestral.ACT3_STYLE (onda 4)


# ---------------------------------------------------------------------------
# Onda 4 do nível 50: armas "despertas" (GDD ato3-lendarios-50 §3.3). Malhas SÓ no kit extra kit_druid_<sexo>_a3.glb
# (chibi_kit.A3_WEAPONS lê ACT3_WEAPONS; o kit principal não ganha malha). Mesmos eixos, punho e alcance das armas do Ato II
# (build_staff / build_fang_mace / build_stone_maul): os clipes e a conta de chão das armas (clear_weapons) continuam valendo.
#   dru_x50 Xamã = Lua Cheia Desperta: haste de porcelana com aros de ouro, crescente de ouro velho no alto abraçando uma
#           lanterna de papel acesa (a lua cheia), duas lanterninhas penduradas nas pontas e fitas de seda (tint2).
#   dru_w50 Lobo = Guizo do Desfile (uma em cada mão): miolo de porcelana, seis presas de OURO que se fecham em gaiola em
#           volta de uma chama acesa, guizo no pomo, duas fitas de seda (tint2).
#   dru_b50 Urso = Tambor da Colheita: tonel de porcelana com aros de ouro, tampos de casca envernizada com lágrima acesa,
#           lanterna-cabaça grande no topo, fitas verde-musgo (tint2) nas duas pontas.
def _along(objs, c, axis):
    """Leva peças modeladas na origem com o eixo em +Z até c, com o eixo virado para axis."""
    q = Vector((0, 0, 1)).rotation_difference(Vector(axis).normalized())
    c = Vector(c)
    for o in objs:
        for v in o.data.vertices:
            v.co = q @ v.co + c
    return objs


# Altura a mais do cajado do Xamã 50 sobre os outros cajados. Era 0,16 (a lua passava da aba do chapéu), mas a CABEÇA
# (estrela e lanterninhas de lado) é que entrava no chão quando o cajado vira para baixo: cast_bolt -0,21 m, atk_1h_b -0,11.
MOON_STAFF_EXTRA = 0.0


def build_moon_staff(ck, base, mats, style):
    """Cajado do Xamã no nível 50 (wpn_main_staff_<estilo>): crescente de ouro com a lua cheia acesa dentro."""
    import lumeria_kit as lk
    import ranger_sets as rs
    V = Vector
    M = lk.lum_mats(ck, mats)
    t, t2, gold, glow, porc = M["t"], M["t2"], M["gold"], M["glow"], M["porc"]
    g = V(ck.hand_center(base, ".R"))
    up = V((-0.22, -0.12, 1.0)).normalized()
    side = V((1, 0, 0))
    fwd = up.cross(side).normalized()
    n = "st_%s_" % style
    ln = 1.3
    foot, top = g - up * ln * 0.42, g + up * (ln * 0.57 + MOON_STAFF_EXTRA)
    parts = [ck.tube(n + "shaft", foot, top, 0.032, 0.026, t, 8), ck.tube(n + "ferrule", foot - up * 0.03, foot + up * 0.07, 0.022, 0.04, gold, 8),
             ck.tube(n + "neck", top - up * 0.06, top + up * 0.03, 0.036, 0.05, gold, 8)]
    for k in range(4):                   # aros de ouro pela haste; punho de seda
        p = foot.lerp(top, 0.16 + k * 0.2)
        parts.append(ck.tube(n + "ring%d" % k, p - up * 0.014, p + up * 0.014, 0.039, 0.039, gold, 8))
    parts.append(ck.tube(n + "grip", g - up * 0.07, g + up * 0.07, 0.036, 0.036, t2, 8))
    c0 = top + up * 0.2
    rr = 0.165
    for k in range(6):                   # crescente aberto para cima (lê de cima e de frente), mais grosso embaixo
        a0, a1 = math.radians(-150 + k * 50), math.radians(-150 + (k + 1) * 50)
        w0, w1 = 0.016 + 0.042 * math.sin(math.pi * k / 6), 0.016 + 0.042 * math.sin(math.pi * (k + 1) / 6)
        parts.append(ck.tube(n + "moon%d" % k, c0 + side * math.sin(a0) * rr - up * math.cos(a0) * rr, c0 + side * math.sin(a1) * rr - up * math.cos(a1) * rr, w0, w1, gold, 6))
    full = [ck.ball(n + "full", 0.105, (0, 0, 0), glow, (1, 1, 1.08)),
            ck.tube(n + "full_top", (0, 0, 0.102), (0, 0, 0.135), 0.055, 0.036, gold, 6), ck.tube(n + "full_bottom", (0, 0, -0.14), (0, 0, -0.102), 0.03, 0.055, gold, 6)]
    for k in range(4):                   # varetas da lanterna
        a = math.tau * (k + 0.5) / 4
        full.append(ck.tube(n + "full_rib%d" % k, (math.cos(a) * 0.107, math.sin(a) * 0.107, -0.055), (math.cos(a) * 0.107, math.sin(a) * 0.107, 0.055), 0.009, 0.008, gold, 4))
    parts += _along(full, c0 + up * 0.01, up)
    parts.append(ck.ball(n + "star", 0.032, c0 + up * 0.2, glow))
    for sx in (-1, 1):
        tip = c0 + side * sx * math.sin(math.radians(150)) * rr + up * math.cos(math.radians(30)) * rr
        parts.append(ck.ball(n + "tip%d" % sx, 0.026, tip, gold))
        hang = c0 + side * sx * rr * 0.42 - up * rr * 0.88              # lanterninhas sob o arco, rentes à haste
        parts += _paper_lantern(ck, n + "lantern%d" % sx, hang - up * 0.07, 0.036, M, hang=hang)
        p0 = top + side * sx * 0.035 - up * 0.02
        parts.append(lk.silk(ck, n + "ribbon%d" % sx, p0, p0 + side * sx * 0.07 - up * 0.26 + fwd * 0.02, fwd, 0.06, 0.085, t2, side * sx * 0.025, 3))
    obj = ck._join(rs.outward(parts), "wpn_main_staff_%s" % style)
    ck._smooth(obj.data)
    ck.skin_rigid(obj, base["rig"], "hand.R")
    return obj


def build_bell_mace(ck, base, mats, style, hand="main"):
    """Maça do Lobo no nível 50 (wpn_main_mace_<estilo> / wpn_off_mace_<estilo>): presas de ouro em gaiola com chama acesa."""
    import lumeria_kit as lk
    import ranger_sets as rs
    V = Vector
    M = lk.lum_mats(ck, mats)
    t, t2, gold, glow, porc = M["t"], M["t2"], M["gold"], M["glow"], M["porc"]
    g, fwd, side, ridge = _a2_weapon_axes(ck, base, hand)
    n = "m_%s_%s_" % (style, hand)
    hc = g + fwd * 0.55
    parts = [ck.tube(n + "shaft", g - fwd * 0.13, g + fwd * 0.44, 0.03, 0.028, t, 8),
             ck.tube(n + "collar", g + fwd * 0.36, g + fwd * 0.44, 0.05, 0.066, gold, 10),
             ck.ball(n + "core", 0.1, hc - fwd * 0.01, porc, (1, 1, 1)), ck.tube(n + "band", hc - fwd * 0.04, hc + fwd * 0.0, 0.106, 0.106, gold, 12),
             ck.ball(n + "flame", 0.082, hc + fwd * 0.15, glow, (1, 1, 1.1)), ck.ball(n + "knob", 0.03, hc + fwd * 0.3, gold)]
    parts += lk.bell(ck, n + "pommel", g - fwd * 0.17, 0.05, M)
    for k in range(3):
        parts.append(ck.tube(n + "wrap%d" % k, g + fwd * (-0.08 + k * 0.07), g + fwd * (-0.055 + k * 0.07), 0.035, 0.035, t2 if k != 1 else gold, 8))
    for k in range(6):                   # presas de ouro: saem do aro, abrem e fecham em gaiola em volta da chama
        a = math.tau * k / 6
        dv = side * math.cos(a) + ridge * math.sin(a)
        parts += rs.curve(ck, n + "fang%d" % k, hc - fwd * 0.03 + dv * 0.09, hc + fwd * 0.28 + dv * 0.012, dv * 0.105, 0.027, gold, 5, 6, 0.01)
    for sx in (-1, 1):                   # fitas de seda saindo do colar
        p0 = g + fwd * 0.38 + side * sx * 0.05
        parts.append(lk.silk(ck, n + "ribbon%d" % sx, p0, p0 + side * sx * 0.15 - fwd * 0.26 + ridge * 0.03, ridge, 0.055, 0.085, t2, side * sx * 0.03, 3))
    obj = ck._join(rs.outward(parts), ("wpn_main_mace_%s" % style) if hand == "main" else ("wpn_off_mace_%s" % style))
    ck._smooth(obj.data)
    ck.skin_rigid(obj, base["rig"], "hand.R" if hand == "main" else "hand.L")
    return obj


def build_harvest_maul(ck, base, mats, style):
    """Malho do Urso no nível 50 (wpn_main_mace2h_<estilo>): tonel de porcelana, tampos de casca com lágrima, cabaça acesa no topo."""
    import lumeria_kit as lk
    import ranger_sets as rs
    V = Vector
    M = lk.lum_mats(ck, mats)
    t, t2, gold, glow, porc = M["t"], M["t2"], M["gold"], M["glow"], M["porc"]
    bark = _lum_bark(ck)
    g, fwd, side, ridge = _a2_weapon_axes(ck, base, "main")
    n = "m_%s_main_" % style
    hc = g + fwd * 0.98
    parts = [ck.tube(n + "shaft", g - fwd * 0.36, g + fwd * 0.9, 0.036, 0.034, bark, 8), ck.tube(n + "butt", g - fwd * 0.45, g - fwd * 0.35, 0.03, 0.05, gold, 8),
             ck.tube(n + "socket", g + fwd * 0.76, g + fwd * 0.86, 0.044, 0.07, gold, 8)]
    for k in range(4):
        parts.append(ck.tube(n + "wrap%d" % k, g + fwd * (-0.26 + k * 0.12), g + fwd * (-0.235 + k * 0.12), 0.041, 0.041, t2 if k % 2 == 0 else gold, 8))
    parts += [ck.tube(n + "head", hc - side * 0.23, hc + side * 0.23, 0.155, 0.155, t, 10),
              ck.ball(n + "belly", 1.0, hc, t, (0.2, 0.17, 0.17))]
    for k in (-1, 0, 1):                 # aros de ouro do tonel
        parts.append(ck.tube(n + "hoop%d" % k, hc + side * (k * 0.15 - 0.018), hc + side * (k * 0.15 + 0.018), 0.168 if k == 0 else 0.162, 0.168 if k == 0 else 0.162, gold, 10))
    for sx in (-1, 1):
        fc = hc + side * sx * 0.23
        parts += [ck.tube(n + "face%d" % sx, fc, fc + side * sx * 0.03, 0.15, 0.13, bark, 10),
                  ck.tube(n + "face_rim%d" % sx, fc - side * sx * 0.012, fc + side * sx * 0.012, 0.166, 0.166, gold, 10)]
        tear = [ck.ball(n + "tear%d" % sx, 0.034, (0, 0, 0.04), glow, (0.8, 2.0, 0.5)), ck.ball(n + "drop%d" % sx, 0.046, (0, -0.045, 0.04), glow, (1.0, 1.25, 0.5))]
        parts += _along(tear, fc, side * sx)
        p0 = fc - fwd * 0.12 + side * sx * 0.01
        # as duas fitas saem do tampo de FORA (-X): a do tampo de dentro (+X, virada para o corpo) entrava 0,24 m na
        # máscara de urso nos lançamentos (cast_heal_nature, cast_buff, atk_leap)
        if sx < 0:
            for k, (rl, off) in enumerate(((0.34, 0.035), (0.24, -0.04))):
                q0 = p0 + ridge * off
                parts.append(lk.silk(ck, n + "ribbon%d" % k, q0, q0 + side * sx * (0.1 - k * 0.04) - fwd * rl + ridge * off * 0.8, ridge, 0.07, 0.1 - k * 0.02, t2, side * sx * 0.04, 3))
    # cabaça menor e mais baixa no tonel (era 0,115 a 0,275 do centro): entrava 0,27 m na máscara de urso nos lançamentos
    parts += _along(lk.gourd(ck, n + "gourd", (0, 0, 0), 0.085, M), hc + fwd * 0.215, fwd)
    obj = ck._join(rs.outward(parts), "wpn_main_mace2h_%s" % style)
    ck._smooth(obj.data)
    ck.skin_rigid(obj, base["rig"], "hand.R")
    return obj


ACT3_WEAPONS = {          # chave começa pelo estilo (chibi_kit.style_class decide a classe); fn(ck, base, mats)
    "dru_x50_staff": lambda ck, base, mats: build_moon_staff(ck, base, mats, "dru_x50"),
    "dru_w50_mace": lambda ck, base, mats: build_bell_mace(ck, base, mats, "dru_w50"),
    "dru_w50_offmace": lambda ck, base, mats: build_bell_mace(ck, base, mats, "dru_w50", "off"),
    "dru_b50_mace": lambda ck, base, mats: build_harvest_maul(ck, base, mats, "dru_b50"),
}
