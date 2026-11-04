"""Conjuntos lendários do Bispo (12), maças e escudos do Sacerdote e cetros do Iluminado, por construtor paramétrico.

Linguagem visual (original): clérigo — túnicas longas, estola, capinha nos ombros, véu ou mitra, aros de luz.
Sacerdote (suporte, maça + escudo): véu/capuz, túnica com painel de cruz, estola, cordão; fica mais protetor a cada tier.
Iluminado (luz mágica, cetro de duas mãos): mitra ou coroa de raios, túnica em camadas, gola alta, halo, asas no topo.
Peças: arm_<estilo>_<head|body|gloves|boots>_*; armas: wpn_main_<mace|scepter>_<estilo>; escudos: wpn_off_shield_<estilo>.
"""
import math
from mathutils import Vector

# head: veil | coif | mitre | crown ; robe: (barra, abertura) ; over = sobretúnica mais curta (cor de destaque)
# stole = estola caindo na frente ; capelet = capinha nos ombros ; collar = gola alta ; emblem: cross | sun | dove | star
# wings: asas nas costas ; halo ; shoulder: none | plate | wing ; glow: cor das luzes (gema/halo/orbe)
BIS_SETS = {
    # ---- Sacerdote (suporte): véu e túnica, cada vez mais protegido ----
    "bis_s5": {"head": "veil", "robe": (0.1, 1.7), "stole": True, "capelet": False, "collar": False, "emblem": "cross", "shoulder": "none"},
    "bis_s10": {"head": "veil", "robe": (0.08, 1.8), "stole": True, "capelet": True, "collar": False, "emblem": "cross", "shoulder": "none"},
    "bis_s15": {"head": "coif", "robe": (0.08, 1.8), "over": 0.24, "stole": True, "capelet": True, "collar": False, "emblem": "dove", "shoulder": "plate"},
    "bis_s20": {"head": "coif", "robe": (0.07, 1.9), "over": 0.26, "stole": True, "capelet": True, "collar": True, "emblem": "sun", "shoulder": "plate",
                "halo": True, "glow": (1.0, 0.92, 0.6)},
    "bis_s25": {"head": "veil", "robe": (0.06, 1.9), "over": 0.28, "stole": True, "capelet": True, "collar": True, "emblem": "dove", "shoulder": "wing",
                "glow": (0.7, 0.9, 1.0)},
    "bis_s30": {"head": "crown", "robe": (0.05, 2.0), "over": 0.3, "stole": True, "capelet": True, "collar": True, "emblem": "sun", "shoulder": "wing",
                "halo": True, "wings": True, "glow": (1.0, 0.95, 0.7)},
    # ---- Iluminado (luz mágica): mitra, camadas e luz, cada vez mais radiante ----
    "bis_i5": {"head": "mitre", "robe": (0.08, 1.8), "stole": True, "capelet": False, "collar": True, "emblem": "star", "shoulder": "none"},
    "bis_i10": {"head": "mitre", "robe": (0.07, 1.9), "over": 0.22, "stole": True, "capelet": False, "collar": True, "emblem": "star", "shoulder": "none",
                "glow": (0.75, 0.9, 1.0)},
    "bis_i15": {"head": "crown", "robe": (0.07, 1.9), "over": 0.26, "stole": False, "capelet": True, "collar": True, "emblem": "sun", "shoulder": "plate",
                "glow": (1.0, 0.85, 0.45)},
    "bis_i20": {"head": "mitre", "robe": (0.06, 2.0), "over": 0.28, "stole": True, "capelet": True, "collar": True, "emblem": "sun", "shoulder": "wing",
                "halo": True, "glow": (1.0, 0.92, 0.6)},
    "bis_i25": {"head": "crown", "robe": (0.06, 2.0), "over": 0.3, "stole": True, "capelet": True, "collar": True, "emblem": "star", "shoulder": "wing",
                "halo": True, "glow": (0.65, 0.8, 1.0)},
    "bis_i30": {"head": "mitre", "robe": (0.05, 2.1), "over": 0.32, "stole": True, "capelet": True, "collar": True, "emblem": "sun", "shoulder": "wing",
                "halo": True, "wings": True, "glow": (1.0, 0.95, 0.75)},
}


def _emblem(ck, P, name, kind, at, mats, glow, normal_y=-1.0):
    """Emblema na frente (normal_y=-1) ou nas costas (+1)."""
    V = Vector
    gold, wh = mats["trim"], mats["white"]
    at = V(at)
    out = []
    if kind == "cross":
        out += [ck.box(P + name + "_v", (0.035, 0.025, 0.14), at, gold, 0.006), ck.box(P + name + "_h", (0.1, 0.025, 0.035), at + V((0, 0, 0.03)), gold, 0.006)]
    elif kind == "sun":
        out.append(ck.ball(P + name + "_disc", 0.04, at, gold, (1, 0.45, 1)))
        for k in range(8):
            a = math.tau * k / 8
            d = V((math.cos(a), 0, math.sin(a)))
            out.append(ck.blade(P + name + "_ray%d" % k, at + d * 0.035, at + d * 0.085, 0.03, 0.015, gold, V((-math.sin(a), 0, math.cos(a)))))
    elif kind == "dove":           # duas asas abertas e um ponto de luz
        for sx in (-1, 1):
            out.append(ck.blade(P + name + "_wing%d" % sx, at + V((sx * 0.01, 0, 0)), at + V((sx * 0.1, 0, 0.05)), 0.05, 0.02, wh, V((0, 0, 1))))
        out.append(ck.ball(P + name + "_core", 0.022, at, glow or gold))
    elif kind == "star":
        for k in range(4):
            a = math.tau * k / 4 + math.pi / 4 * (k % 2)
            d = V((math.cos(a), 0, math.sin(a)))
            out.append(ck.blade(P + name + "_pt%d" % k, at, at + d * (0.09 if k % 2 == 0 else 0.06), 0.04, 0.02, gold, V((-math.sin(a), 0, math.cos(a)))))
        out.append(ck.ball(P + name + "_core", 0.024, at, glow or gold))
    for o in out:
        o.location.y += 0.0
    return out


def build(ck, base, mats, style, cfg):
    V = Vector
    rig, body, b, j = base["rig"], base["body"], base["b"], base["j"]
    t, t2, gold, wh, dark = mats["tint"], mats["tint2"], mats["trim"], mats["white"], mats["dark"]
    P = "arm_%s_" % style
    c = V(base["head_c"])
    r = b["head"]
    glow = ck.mat("m_bis_glow_%d" % int(sum(cfg["glow"]) * 100), cfg["glow"], 0.3, 3.0) if cfg.get("glow") else None
    # ---------------- cabeça ----------------
    hk = cfg["head"]
    head = []
    if hk == "veil":               # véu: capuz macio que cai nas costas, faixa na testa
        head += [ck._shell(P + "head_veil", c, r * 1.15, 0.3, -1.05, -0.55, 0.03, wh),
                 ck.tube(P + "head_band", c + V((0, 0, r * 0.3)), c + V((0, 0, r * 0.42)), r * 1.19, r * 1.17, t, 24),
                 ck.blade(P + "head_drape", c + V((0, r * 0.75, r * 0.1)), c + V((0, r * 1.05, -r * 1.25)), r * 1.5, 0.03, wh, (1, 0, 0), 0.3)]
    elif hk == "coif":             # touca justa com testeira de metal e cruz na testa
        head += [ck._shell(P + "head_coif", c, r * 1.15, 0.32, -0.95, -0.5, 0.035, t),
                 ck.tube(P + "head_band", c + V((0, 0, r * 0.28)), c + V((0, 0, r * 0.4)), r * 1.2, r * 1.18, gold, 24),
                 ck.box(P + "head_mark_v", (0.035, 0.03, 0.11), c + V((0, -r * 1.2, r * 0.48)), gold, 0.006),
                 ck.box(P + "head_mark_h", (0.08, 0.03, 0.03), c + V((0, -r * 1.2, r * 0.5)), gold, 0.006)]
    elif hk == "mitre":            # mitra alta: duas placas em ponta, faixa de ouro e cruz
        head.append(ck._shell(P + "head_cap", c, r * 1.13, 0.35, -0.3, 0.05, 0.03, t))
        for sy, k in ((-1, "f"), (1, "b")):
            head.append(ck.blade(P + "head_mitre_" + k, c + V((0, sy * r * 0.18, r * 0.55)), c + V((0, sy * r * 0.05, r * 2.05)), r * 1.55, 0.05, t, (1, 0, 0), 0.25))
        head += [ck.tube(P + "head_band", c + V((0, 0, r * 0.38)), c + V((0, 0, r * 0.55)), r * 1.17, r * 1.15, gold, 24),
                 ck.box(P + "head_mitre_v", (0.04, 0.03, r * 1.0), c + V((0, -r * 0.24, r * 1.25)), gold, 0.006),
                 ck.box(P + "head_mitre_h", (r * 0.6, 0.03, 0.04), c + V((0, -r * 0.27, r * 1.4)), gold, 0.006)]
        for sx in (-1, 1):         # fitas caindo atrás
            head.append(ck.box(P + "head_lappet_%d" % sx, (0.05, 0.015, r * 0.9), c + V((sx * r * 0.25, r * 1.0, -r * 0.45)), t2, 0.004))
    elif hk == "crown":            # coroa de raios sobre um véu curto
        head += [ck._shell(P + "head_veil", c, r * 1.14, 0.3, -0.75, -0.4, 0.03, wh),
                 ck.tube(P + "head_circlet", c + V((0, 0, r * 0.42)), c + V((0, 0, r * 0.58)), r * 1.16, r * 1.14, gold, 24)]
        for k in range(9):
            a = math.pi * (0.1 + 0.8 * k / 8.0) + math.pi
            d = V((math.cos(a), math.sin(a), 0))
            head.append(ck.blade(P + "head_ray_%d" % k, c + d * r * 1.12 + V((0, 0, r * 0.55)), c + d * r * 1.2 + V((0, 0, r * (1.15 if k % 2 == 0 else 0.95))),
                                 r * 0.22, 0.04, gold, V((-d.y, d.x, 0))))
        head.append(ck.ball(P + "head_gem", 0.04, c + V((0, -r * 1.2, r * 0.5)), glow or t2, (1, 0.6, 1.3)))
    if cfg.get("halo"):
        n = 20
        ring = [c + V((math.cos(math.tau * i / n) * r * 0.85, r * 0.3 + math.sin(math.tau * i / n) * r * 0.55, r * (1.75 if hk != "mitre" else 2.25))) for i in range(n)]
        for i in range(n):
            head.append(ck.tube(P + "head_halo_%d" % i, ring[i], ring[(i + 1) % n], 0.022, 0.022, glow or gold, 6))
    ck._rigid(head, rig, "head")
    # ---------------- corpo: túnica longa ----------------
    ck.armor_piece(body, rig, P + "body_robe", "torso", t, 0.014, 0.014, 0.03)
    ck.armor_piece(body, rig, P + "body_legs", "legs", wh, 0.008, 0.012)
    bottom, flare = cfg["robe"]
    ck.skirt(P + "body_skirt", b, body, rig, t, bottom, flare)
    if cfg.get("over"):            # sobretúnica mais curta, cor de destaque
        ck.skirt(P + "body_over", b, body, rig, t2, ck.Z["waist"] - cfg["over"], flare * 0.85)
    d = b["depth"]
    front = -b["chest"] * d - 0.03
    zc = ck.Z["chest"]
    chest = []
    if cfg.get("collar"):          # gola alta aberta
        chest.append(ck.tube(P + "body_collar", V((0, 0, ck.Z["neck"] - 0.04)), V((0, 0, ck.Z["neck"] + 0.07)), b["chest"] * 0.5, b["chest"] * 0.62, gold, 16))
    if cfg.get("capelet"):         # capinha nos ombros
        chest.append(ck.tube(P + "body_capelet", V((0, 0, ck.Z["neck"] - 0.02)), V((0, 0, zc + 0.02)), b["chest"] * 0.55, b["chest"] * 1.18, wh, 18))
        chest.append(ck.tube(P + "body_capelet_hem", V((0, 0, zc + 0.01)), V((0, 0, zc + 0.04)), b["chest"] * 1.2, b["chest"] * 1.2, gold, 18))
    # painel da frente com o emblema (e o mesmo nas costas: a câmera alta vê as costas)
    chest.append(ck.box(P + "body_panel", (0.13, 0.02, 0.3), (0, front, zc - 0.06), wh, 0.006))
    chest += _emblem(ck, P, "body_emblem", cfg["emblem"], (0, front - 0.02, zc + 0.02), mats, glow)
    chest += _emblem(ck, P, "body_back", cfg["emblem"], (0, b["chest"] * d + 0.04, zc + 0.02), mats, glow)
    if cfg.get("wings"):           # asas nas costas
        for sx in (-1, 1):
            for k in range(4):
                root = V((sx * 0.06, b["chest"] * d + 0.05, zc + 0.06))
                tip = root + V((sx * (0.42 - k * 0.07), 0.12 + k * 0.03, 0.3 - k * 0.14))
                chest.append(ck.blade(P + "body_wing_%d_%d" % (sx, k), root, tip, 0.13 - k * 0.015, 0.03, wh, (0, 0.3, 1)))
    ck._rigid(chest, rig, "chest")
    # cordão na cintura e estola
    belt = ck.tube(P + "body_cord", (0, 0, ck.Z["waist"] - 0.03), (0, 0, ck.Z["waist"] + 0.02), b["waist"] * 1.2, b["waist"] * 1.2, gold, 16)
    for v in belt.data.vertices:
        v.co.y *= d * 1.05
    ck._smooth(belt.data)
    ck.transfer_weights(belt, body, rig)
    hips = []
    if cfg.get("stole"):           # estola: duas faixas caindo do pescoço até abaixo do joelho
        for sx in (-1, 1):
            hips += [ck.box(P + "body_stole_%d" % sx, (0.055, 0.016, 0.44), (sx * 0.06, -b["waist"] * d * 1.2 - 0.03, ck.Z["waist"] - 0.07), t2, 0.005),
                     ck.box(P + "body_stole_end_%d" % sx, (0.06, 0.02, 0.03), (sx * 0.06, -b["waist"] * d * 1.2 - 0.035, ck.Z["waist"] - 0.29), gold, 0.004)]
    hips.append(ck.ball(P + "body_knot", 0.035, (0.05, -b["waist"] * d * 1.22 - 0.02, ck.Z["waist"]), gold))
    ck._rigid(hips, rig, "hips")
    for s, sx in ((".R", -1), (".L", 1)):
        tag = s.replace(".", "_")
        sh = V(j["shoulder" + s])
        pa = []
        if cfg["shoulder"] in ("plate", "wing"):
            pa += [ck.ball(P + "body_pauldron" + tag, b["arm"] * 2.2, sh + V((sx * 0.05, 0, 0.05)), t, (1.1, 1.05, 0.55)),
                   ck.ball(P + "body_pauldron_rim" + tag, b["arm"] * 2.28, sh + V((sx * 0.05, 0, 0.025)), gold, (1.12, 1.07, 0.15))]
        if cfg["shoulder"] == "wing":
            top = sh + V((sx * 0.07, 0, 0.1))
            for k in range(3):
                pa.append(ck.blade(P + "body_pwing_%d" % k + tag, top, top + V((sx * (0.13 + k * 0.04), 0.08 + k * 0.03, 0.17 - k * 0.06)), 0.07, 0.025, wh, (0, 1, 0)))
        if pa:
            ck._rigid(pa, rig, "upper_arm" + s)
    # ---------------- mangas e luvas ----------------
    for s, sx in ((".R", -1), (".L", 1)):
        tag = s.replace(".", "_")
        el, wr = V(j["elbow" + s]), V(j["wrist" + s])
        g = [ck.tube(P + "gloves_sleeve" + tag, el.lerp(wr, 0.35), wr + V((0, 0, -0.01)), 0.07, 0.115, t, 14),      # manga larga
             ck.tube(P + "gloves_cuff" + tag, wr + V((0, 0, -0.012)), wr + V((0, 0, 0.012)), 0.12, 0.12, gold, 14)]
        ck._rigid(g, rig, "forearm" + s)
        fist = ck.ball(P + "gloves_fist" + tag, b["hand"] * 1.25, ck.hand_center(base, s), wh, (1, 1, 1.1))
        ck._rigid([fist], rig, "hand" + s)
    # ---------------- sandálias/botas ----------------
    ck.armor_piece(body, rig, P + "boots_shell", "boots", wh, 0.02, 0.014)
    for s, sx in ((".R", -1), (".L", 1)):
        tag = s.replace(".", "_")
        an = V(j["ankle" + s])
        k = [ck.tube(P + "boots_band" + tag, an + V((0, 0, 0.05)), an + V((0, 0, 0.075)), 0.075, 0.075, gold, 12)]
        if cfg["shoulder"] == "wing":
            k.append(ck.blade(P + "boots_wing" + tag, an + V((sx * 0.06, 0.01, 0.06)), an + V((sx * 0.13, 0.05, 0.16)), 0.06, 0.02, wh, (0, 1, 0)))
        ck._rigid(k, rig, "shin" + s)


# ---------------------------------------------------------------------------
# Maças do Sacerdote (formato de paladin_sets.PAL_MACES, uma mão) e escudos (formato do shield_kit)
BIS_MACES = {
    "bis_s5": {"type": "mace", "head": "flange", "n": 6, "core": "tint", "cap": "ball"},
    "bis_s10": {"type": "mace", "head": "flange", "n": 6, "core": "tint", "cap": "gem"},
    "bis_s15": {"type": "mace", "head": "sun", "core": "tint", "cap": "gem"},
    "bis_s20": {"type": "mace", "head": "flange", "n": 8, "core": "tint", "cap": "gem", "halo": True, "glow": True},
    "bis_s25": {"type": "mace", "head": "flange", "n": 8, "core": "tint", "cap": "gem", "wings": True},
    "bis_s30": {"type": "mace", "head": "sun", "core": "tint", "cap": "gem", "wings": True, "halo": True, "glow": True},
}


def _round(R, n=28):
    return [(math.cos(math.tau * i / n) * R, math.sin(math.tau * i / n) * R) for i in range(n)]


def shield_s5(ck, name, mats):
    """Aurora: escudo redondo pequeno com cruz em relevo."""
    import shield_kit as sk
    t, gold, wh = mats["tint"], mats["trim"], mats["white"]
    R = 0.33
    parts = [sk.plate(name + "_aro", [(x * 1.08, z * 1.08) for x, z in _round(R)], -0.03, 0.03, gold), sk.plate(name + "_corpo", _round(R), -0.08, 0.02, wh),
             ck.box(name + "_cruz_v", (0.08, 0.05, R * 1.5), (0, -0.09, 0), t, 0.012), ck.box(name + "_cruz_h", (R * 1.5, 0.05, 0.08), (0, -0.09, 0), t, 0.012)]
    return parts + sk._back(ck, name, mats)


def shield_s10(ck, name, mats):
    """Vigília: heater branco com orla da cor do item e chama (gota) no meio."""
    import shield_kit as sk
    t, gold, wh = mats["tint"], mats["trim"], mats["white"]
    S = 0.36
    half = [(0, 0.82), (0.42, 0.86), (0.76, 0.78), (0.76, 0.2), (0.56, -0.42), (0.28, -0.82), (0, -1.05)]
    out = sk.mirror(half, S)
    parts = [sk.plate(name + "_aro", [(x * 1.09, z * 1.06) for x, z in out], -0.03, 0.03, t), sk.plate(name + "_corpo", out, -0.08, 0.02, wh)]
    flame = sk.mirror([(0, 0.42), (0.16, 0.08), (0.14, -0.2), (0, -0.34)], S)
    parts.append(sk.plate(name + "_chama", flame, -0.13, -0.05, gold, 0.0, S * 0.1))
    return parts + sk._back(ck, name, mats)


def shield_s15(ck, name, mats):
    """Claustro: oval com pomba de asas abertas e gema."""
    import shield_kit as sk
    t, gold, wh = mats["tint"], mats["trim"], mats["white"]
    out = [(math.cos(math.tau * i / 28) * 0.3, math.sin(math.tau * i / 28) * 0.4) for i in range(28)]
    parts = [sk.plate(name + "_aro", [(x * 1.08, z * 1.06) for x, z in out], -0.03, 0.03, gold), sk.plate(name + "_corpo", out, -0.09, 0.02, t)]
    for k in (-1, 1):
        for i in range(3):
            parts.append(sk.blade(name + "_asa_%d_%d" % (k, i), (k * 0.03, 0.04), (k * (0.26 - i * 0.04), 0.06 + i * 0.07), 0.08, 0.03, wh, 0.3, -0.1))
    parts.append(sk.gem(name + "_gema", (0, -0.08), 0.05, sk.jewel(ck, "ciano"), -0.12, 6, 1.2))
    return parts + sk._back(ck, name, mats)


def shield_s20(ck, name, mats):
    """Graça: redondo com sol de raios longos e halo."""
    import shield_kit as sk
    t, gold, wh = mats["tint"], mats["trim"], mats["white"]
    R = 0.35
    parts = [sk.plate(name + "_aro", [(x * 1.08, z * 1.08) for x, z in _round(R)], -0.03, 0.03, gold), sk.plate(name + "_corpo", _round(R), -0.09, 0.02, t)]
    for i in range(16):
        a = math.tau * i / 16
        parts.append(sk.blade(name + "_raio_%d" % i, (math.cos(a) * R * 0.2, math.sin(a) * R * 0.2), (math.cos(a) * R * (0.95 if i % 2 == 0 else 0.7), math.sin(a) * R * (0.95 if i % 2 == 0 else 0.7)),
                              0.05, 0.03, wh if i % 2 else gold, 0.3, -0.09))
    parts += sk.ring(name + "_halo", (0, 0), R * 0.55, 0.014, gold, 20, -0.11)
    parts.append(sk.gem(name + "_gema", (0, 0), 0.06, sk.jewel(ck, "branco"), -0.16, 8, 1.0))
    return parts + sk._back(ck, name, mats)


def shield_s25(ck, name, mats):
    """Graça Serena: kite com duas asas subindo dos lados e lírio no meio."""
    import shield_kit as sk
    t, gold, wh = mats["tint"], mats["trim"], mats["white"]
    S = 0.36
    half = [(0, 0.86), (0.4, 0.7), (0.5, 0.2), (0.32, -0.5), (0, -1.08)]
    out = sk.mirror(half, S)
    parts = [sk.plate(name + "_aro", [(x * 1.1, z * 1.06) for x, z in out], -0.03, 0.03, gold), sk.plate(name + "_corpo", out, -0.09, 0.02, t)]
    for k in (-1, 1):
        for i in range(4):
            parts.append(sk.blade(name + "_asa_%d_%d" % (k, i), (k * S * 0.4, S * 0.3), (k * S * (1.15 - i * 0.12), S * (0.95 - i * 0.25)), 0.11, 0.035, wh, 0.3, -0.05))
    for k in (-1, 0, 1):        # lírio de três pétalas
        parts.append(sk.blade(name + "_petala_%d" % (k + 1), (0, -S * 0.1), (k * S * 0.24, S * (0.4 if k == 0 else 0.25)), 0.08, 0.03, gold, 0.4, -0.11))
    return parts + sk._back(ck, name, mats)


def shield_s30(ck, name, mats):
    """Coro Celeste: heater grande com asas abertas, halo e estrela de luz."""
    import shield_kit as sk
    t, gold, wh = mats["tint"], mats["trim"], mats["white"]
    S = 0.37
    half = [(0, 0.86), (0.42, 0.9), (0.78, 0.8), (0.78, 0.2), (0.58, -0.42), (0.28, -0.82), (0, -1.05)]
    out = sk.mirror(half, S)
    parts = [sk.plate(name + "_aro", [(x * 1.08, z * 1.06) for x, z in out], -0.03, 0.03, gold), sk.plate(name + "_corpo", out, -0.09, 0.02, wh)]
    for k in (-1, 1):
        for i in range(4):
            parts.append(sk.blade(name + "_asa_%d_%d" % (k, i), (k * S * 0.5, S * 0.72), (k * S * (1.22 - i * 0.1), S * (1.25 - i * 0.22)), 0.12, 0.04, wh, 0.3, -0.05))
    parts += sk.ring(name + "_halo", (0, S * 1.05), S * 0.3, 0.016, gold, 18, -0.06)
    for i in range(4):
        a = math.tau * i / 4 + math.pi / 4
        parts.append(sk.blade(name + "_estrela_%d" % i, (0, S * 0.15), (math.cos(a) * S * 0.42, S * 0.15 + math.sin(a) * S * 0.42), 0.09, 0.03, gold, 0.3, -0.1))
    parts.append(sk.gem(name + "_gema", (0, S * 0.15), 0.07, sk.jewel(ck, "branco"), -0.14, 8, 1.0))
    return parts + sk._back(ck, name, mats)


BIS_SHIELDS = {"bis_s5": shield_s5, "bis_s10": shield_s10, "bis_s15": shield_s15, "bis_s20": shield_s20, "bis_s25": shield_s25, "bis_s30": shield_s30}


# ---------------------------------------------------------------------------
# Cetros do Iluminado: cabo longo de duas mãos (em pé, como o cajado) e cabeça sagrada.
# head: orb (esfera entre garras) | sun (disco de raios) | cross (cruz ornada) | star | wing (asas em volta da esfera) | crescent
BIS_SCEPTERS = {
    "bis_i5": {"head": "orb"},
    "bis_i10": {"head": "cross"},
    "bis_i15": {"head": "sun"},
    "bis_i20": {"head": "wing", "halo": True},
    "bis_i25": {"head": "star", "halo": True},
    "bis_i30": {"head": "wing", "halo": True, "rays": True},
}


def scepter_parts(ck, n, g, up, mats, cfg, glow):
    """Partes do cetro com o pé em g e o eixo `up` (usado pelo cetro comum do kit e pelos de conjunto)."""
    V = Vector
    t, t2, gold, wh = mats["tint"], mats["tint2"], mats["trim"], mats["white"]
    side = V((1, 0, 0))
    fwd = up.cross(side).normalized()
    ln = 1.25
    top = g + up * (ln * 0.58)
    parts = [ck.tube(n + "shaft", g - up * (ln * 0.42), top, 0.026, 0.03, t, 8), ck.ball(n + "foot", 0.04, g - up * (ln * 0.43), gold)]
    for k in range(3):
        z = 0.1 + k * 0.3
        parts.append(ck.tube(n + "ring%d" % k, g + up * (ln * (z - 0.42)), g + up * (ln * (z - 0.42) + 0.03), 0.04, 0.04, gold, 10))
    parts.append(ck.tube(n + "collar", top, top + up * 0.06, 0.05, 0.07, gold, 10))
    hc = top + up * 0.17
    hk = cfg["head"]
    orb_r = 0.09
    if hk in ("orb", "wing"):
        for k in range(4):            # garras que seguram a esfera
            a = math.tau * k / 4
            d = side * math.cos(a) + fwd * math.sin(a)
            parts.append(ck.tube(n + "claw%d" % k, top + up * 0.05 + d * 0.04, hc + d * 0.11 + up * 0.06, 0.02, 0.008, gold, 6))
        parts.append(ck.ball(n + "orb", orb_r, hc, glow))
    if hk == "wing":
        for sx in (-1, 1):
            for k in range(3):
                parts.append(ck.blade(n + "wing%d_%d" % (sx, k), hc + side * sx * 0.06, hc + side * sx * (0.26 - k * 0.05) + up * (0.12 - k * 0.07), 0.07, 0.02, wh, fwd))
    if hk == "cross":
        parts += [ck.tube(n + "cross_v", top + up * 0.04, top + up * 0.42, 0.03, 0.03, gold, 8),
                  ck.tube(n + "cross_h", top + up * 0.26 - side * 0.13, top + up * 0.26 + side * 0.13, 0.03, 0.03, gold, 8),
                  ck.ball(n + "cross_gem", 0.05, top + up * 0.26, glow)]
        for k, p in enumerate((top + up * 0.43, top + up * 0.26 - side * 0.14, top + up * 0.26 + side * 0.14)):
            parts.append(ck.ball(n + "cross_tip%d" % k, 0.035, p, gold))
    if hk == "sun":
        parts.append(ck.ball(n + "sun", 0.08, hc, glow, (1, 0.5, 1)))
        for k in range(12):
            a = math.tau * k / 12
            d = side * math.cos(a) + up * math.sin(a)
            parts.append(ck.blade(n + "ray%d" % k, hc + d * 0.07, hc + d * (0.2 if k % 2 == 0 else 0.15), 0.05, 0.02, gold, fwd.cross(d)))
    if hk == "star":
        for k in range(8):
            a = math.tau * k / 8
            d = side * math.cos(a) + up * math.sin(a)
            parts.append(ck.blade(n + "star%d" % k, hc, hc + d * (0.22 if k % 2 == 0 else 0.12), 0.07, 0.025, gold, fwd.cross(d)))
        parts.append(ck.ball(n + "star_core", 0.06, hc, glow))
    if cfg.get("halo"):
        hh = hc + up * 0.02
        m = 18
        for i in range(m):
            a0, a1 = math.tau * i / m, math.tau * (i + 1) / m
            parts.append(ck.tube(n + "halo%d" % i, hh + (side * math.cos(a0) + up * math.sin(a0)) * 0.19, hh + (side * math.cos(a1) + up * math.sin(a1)) * 0.19,
                                 0.012, 0.012, gold, 6))
    if cfg.get("rays"):
        for k in range(6):
            a = math.tau * k / 6 + 0.26
            d = side * math.cos(a) + up * math.sin(a)
            parts.append(ck.blade(n + "longray%d" % k, hc + d * 0.2, hc + d * 0.34, 0.04, 0.015, glow, fwd.cross(d)))
    return parts


def build_scepter(ck, base, mats, style, cfg):
    V = Vector
    g = V(ck.hand_center(base, ".R"))
    up = V((-0.22, -0.12, 1.0)).normalized()          # igual ao cajado do kit (mão direita, sx = -1)
    glow = ck.mat("m_bis_scepter_glow", (1.0, 0.95, 0.7), 0.25, 3.0)
    obj = ck._join(scepter_parts(ck, "s_%s_" % style, g, up, mats, cfg, glow), "wpn_main_scepter_%s" % style)
    ck._smooth(obj.data)
    ck.skin_rigid(obj, base["rig"], "hand.R")
    return obj


def register(ck):
    import paladin_sets
    import shield_kit
    for style, cfg in BIS_SETS.items():
        ck.SET_STYLES[style] = (lambda st, cf: (lambda base, mats: (build(ck, base, mats, st, cf), paladin_sets.join_slots("arm_%s_" % st))))(style, cfg)
    for style, cfg in BIS_MACES.items():
        ck.SET_WEAPONS[style + "_mace"] = (lambda st, cf: (lambda base, mats: paladin_sets.build_mace(ck, base, mats, st, cf)))(style, cfg)
    for style, cfg in BIS_SCEPTERS.items():
        ck.SET_WEAPONS[style + "_scepter"] = (lambda st, cf: (lambda base, mats: build_scepter(ck, base, mats, st, cf)))(style, cfg)
    shield_kit.FAMILIES.update(BIS_SHIELDS)
