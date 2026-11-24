"""Conjuntos lendários do Bispo (18), maças e escudos do Sacerdote e do Clérigo de Batalha e cetros do Iluminado, por construtor paramétrico.

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
    # ---- Clérigo de Batalha (maça e escudo na linha de frente): placa sobre a túnica curta, elmo de clérigo, ombreiras largas ----
    # plate = couraça no lugar do corpo da túnica (a saia vira a túnica branca por baixo) ; gauntlet / greaves = manoplas e grevas
    # helm_orn: crest | wings ; shoulder "big" = duas lâminas e bossa
    "bis_b5": {"head": "helm", "helm_orn": [], "robe": (0.22, 1.45), "plate": True, "gauntlet": True, "greaves": True,
               "stole": False, "capelet": False, "collar": False, "emblem": "cross", "shoulder": "plate"},
    "bis_b10": {"head": "helm", "helm_orn": ["crest"], "robe": (0.2, 1.5), "over": 0.26, "plate": True, "gauntlet": True, "greaves": True,
                "stole": False, "capelet": False, "collar": False, "emblem": "cross", "shoulder": "big"},
    "bis_b15": {"head": "helm", "helm_orn": ["wings"], "robe": (0.2, 1.5), "over": 0.28, "plate": True, "gauntlet": True, "greaves": True,
                "stole": False, "capelet": False, "collar": True, "emblem": "dove", "shoulder": "big", "glow": (0.75, 1.0, 0.85)},
    "bis_b20": {"head": "helm", "helm_orn": ["crest"], "robe": (0.18, 1.55), "over": 0.3, "plate": True, "gauntlet": True, "greaves": True,
                "stole": True, "capelet": False, "collar": True, "emblem": "sun", "shoulder": "big", "halo": True, "glow": (1.0, 0.9, 0.55)},
    "bis_b25": {"head": "helm", "helm_orn": ["wings", "crest"], "robe": (0.18, 1.55), "over": 0.3, "plate": True, "gauntlet": True, "greaves": True,
                "stole": True, "capelet": False, "collar": True, "emblem": "star", "shoulder": "wing", "glow": (0.85, 0.65, 1.0)},
    "bis_b30": {"head": "helm", "helm_orn": ["wings", "crest"], "robe": (0.16, 1.6), "over": 0.32, "plate": True, "gauntlet": True, "greaves": True,
                "stole": True, "capelet": False, "collar": True, "emblem": "sun", "shoulder": "wing", "halo": True, "wings": True, "glow": (1.0, 0.95, 0.75)},
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
    elif hk == "helm":             # elmo de clérigo: touca de pano por baixo, calota de metal, testeira e nasal com cruz
        head += [ck._shell(P + "head_coif", c, r * 1.14, 0.3, -1.0, -0.62, 0.03, wh),
                 ck._shell(P + "head_cap", c, r * 1.2, 0.36, 0.05, 0.12, 0.04, t),
                 ck.tube(P + "head_band", c + V((0, 0, r * 0.2)), c + V((0, 0, r * 0.36)), r * 1.26, r * 1.24, gold, 24),
                 ck.box(P + "head_nasal", (0.032, 0.04, r * 0.42), c + V((0, -r * 1.22, r * 0.08)), gold, 0.01),
                 ck.box(P + "head_nasal_h", (r * 0.42, 0.05, 0.045), c + V((0, -r * 1.24, r * 0.28)), gold, 0.01)]
        ho = cfg.get("helm_orn", [])
        if "crest" in ho:          # crista baixa de frente para trás (de cima, a linha do elmo)
            head.append(ck.blade(P + "head_crest", c + V((0, -r * 0.85, r * 0.75)), c + V((0, r * 0.75, r * 1.05)), r * 0.32, 0.07, gold, (0, 1, 0)))
        if "wings" in ho:          # asinhas brancas dos lados do elmo
            for sx in (-1, 1):
                for k in range(2):
                    head.append(ck.blade(P + "head_wing_%d_%d" % (sx, k), c + V((sx * r * 1.0, r * 0.1, r * 0.35 - k * 0.05)),
                                         c + V((sx * r * (1.6 - k * 0.2), r * (0.5 + k * 0.15), r * (1.05 - k * 0.3))), r * (0.5 - k * 0.1), 0.05, wh, (0, 1, 0.4)))
    if cfg.get("halo"):
        n = 20
        ring = [c + V((math.cos(math.tau * i / n) * r * 0.85, r * 0.3 + math.sin(math.tau * i / n) * r * 0.55, r * (1.75 if hk != "mitre" else 2.25))) for i in range(n)]
        for i in range(n):
            head.append(ck.tube(P + "head_halo_%d" % i, ring[i], ring[(i + 1) % n], 0.022, 0.022, glow or gold, 6))
    ck._rigid(head, rig, "head")
    # ---------------- corpo: túnica longa ----------------
    plate = cfg.get("plate", False)
    ck.armor_piece(body, rig, P + "body_robe", "torso", t, 0.02 if plate else 0.014, 0.018 if plate else 0.014, 0.03)
    ck.armor_piece(body, rig, P + "body_legs", "legs", mats["metal"] if plate else wh, 0.008, 0.012)
    bottom, flare = cfg["robe"]
    ck.skirt(P + "body_skirt", b, body, rig, wh if plate else t, bottom, flare)      # de placa: a túnica branca aparece por baixo
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
    if plate:                      # couraça: crista no meio do peito e lâmina da barriga
        chest.append(ck.box(P + "body_plackart", (0.2, 0.03, 0.05), (0, -b["waist"] * d * 1.12 - 0.02, ck.Z["waist"] + 0.06), gold, 0.012))
        chest.append(ck.blade(P + "body_ridge", (0, front + 0.004, zc + 0.12), (0, front + 0.004, zc - 0.14), 0.035, 0.03, t, (1, 0, 0), 0.5))
    # painel da frente com o emblema (e o mesmo nas costas: a câmera alta vê as costas)
    chest.append(ck.box(P + "body_panel", (0.1, 0.02, 0.16) if plate else (0.13, 0.02, 0.3), (0, front, zc if plate else zc - 0.06), wh, 0.006))
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
        if cfg["shoulder"] == "big":   # ombreira larga de duas lâminas com bossa (Clérigo de Batalha)
            pa += [ck.ball(P + "body_pauldron" + tag, b["arm"] * 2.7, sh + V((sx * 0.06, 0, 0.06)), t, (1.15, 1.1, 0.62)),
                   ck.ball(P + "body_pauldron_2" + tag, b["arm"] * 2.3, sh + V((sx * 0.1, 0, -0.02)), gold, (1.1, 1.05, 0.5)),
                   ck.ball(P + "body_pauldron_rim" + tag, b["arm"] * 2.78, sh + V((sx * 0.06, 0, 0.03)), gold, (1.17, 1.12, 0.15)),
                   ck.ball(P + "body_pauldron_boss" + tag, 0.04, sh + V((sx * 0.13, 0, 0.12)), wh, (1, 1, 0.7))]
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
        if cfg.get("gauntlet"):    # manopla de placa com borda dourada
            g = [ck.tube(P + "gloves_cuff" + tag, el.lerp(wr, 0.25), wr + V((0, 0, 0.01)), 0.075, 0.105, t, 12),
                 ck.tube(P + "gloves_rim" + tag, wr + V((0, 0, 0.005)), wr + V((0, 0, 0.03)), 0.112, 0.112, gold, 12)]
        else:
            g = [ck.tube(P + "gloves_sleeve" + tag, el.lerp(wr, 0.35), wr + V((0, 0, -0.01)), 0.07, 0.115, t, 14),      # manga larga
                 ck.tube(P + "gloves_cuff" + tag, wr + V((0, 0, -0.012)), wr + V((0, 0, 0.012)), 0.12, 0.12, gold, 14)]
        ck._rigid(g, rig, "forearm" + s)
        gl = cfg.get("gauntlet", False)
        fist = ck.ball(P + "gloves_fist" + tag, b["hand"] * (1.35 if gl else 1.25), ck.hand_center(base, s), t if gl else wh, (1, 1, 1.1))
        ck._rigid([fist], rig, "hand" + s)
    # ---------------- sandálias/botas ----------------
    gr = cfg.get("greaves", False)
    ck.armor_piece(body, rig, P + "boots_shell", "boots", t if gr else wh, 0.024 if gr else 0.02, 0.016 if gr else 0.014)
    for s, sx in ((".R", -1), (".L", 1)):
        tag = s.replace(".", "_")
        an = V(j["ankle" + s])
        k = [ck.tube(P + "boots_band" + tag, an + V((0, 0, 0.05)), an + V((0, 0, 0.075)), 0.075, 0.075, gold, 12)]
        if gr:                     # joelheira de placa
            k.append(ck.ball(P + "boots_knee" + tag, 0.07, V(j["knee" + s]) + V((0, -0.07, 0.01)), gold, (1.05, 0.7, 1.0)))
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
    # Clérigo de Batalha: maças de guerra mais pesadas (cravos e flanges largos)
    "bis_b5": {"type": "mace", "head": "star", "core": "metal", "cap": "ball"},
    "bis_b10": {"type": "mace", "head": "flange", "n": 8, "core": "metal", "cap": "gem"},
    "bis_b15": {"type": "mace", "head": "star", "core": "tint", "cap": "gem", "wings": True},
    "bis_b20": {"type": "mace", "head": "sun", "core": "tint", "cap": "gem", "glow": True, "horns": True},
    "bis_b25": {"type": "mace", "head": "star", "core": "tint", "cap": "gem", "dark": True, "glow": True},
    "bis_b30": {"type": "mace", "head": "flange", "n": 8, "core": "tint", "cap": "gem", "wings": True, "halo": True, "glow": True, "horns": True},
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


# Escudos do Clérigo de Batalha: escudo de guerra (redondo com umbo, heater com faixas, torre) e duas maças cruzadas em relevo.
# shape: round | heater | tower ; boss = umbo no meio com cruz ; bands = faixas ; maces ; wings ; gem ; halo
BATTLE_SHIELDS = {
    "bis_b5": {"shape": "round", "field": "tint", "rim": "gold", "boss": True, "bands": 0},
    "bis_b10": {"shape": "heater", "field": "white", "rim": "tint", "boss": False, "bands": 2, "maces": True},
    "bis_b15": {"shape": "round", "field": "tint", "rim": "gold", "boss": True, "bands": 0, "wings": True, "gem": "ciano"},
    "bis_b20": {"shape": "tower", "field": "white", "rim": "gold", "boss": False, "bands": 3, "maces": True, "gem": "ambar"},
    "bis_b25": {"shape": "heater", "field": "tint", "rim": "gold", "boss": True, "bands": 0, "wings": True, "gem": "violeta"},
    "bis_b30": {"shape": "tower", "field": "white", "rim": "gold", "boss": False, "bands": 2, "maces": True, "wings": True, "gem": "branco", "halo": True},
}


def shield_battle(cfg):
    def fn(ck, name, mats):
        import shield_kit as sk
        pick = {"white": mats["white"], "tint": mats["tint"], "tint2": mats["tint2"], "gold": mats["trim"]}
        gold, wh = mats["trim"], mats["white"]
        S = 0.36
        if cfg["shape"] == "round":
            out = _round(S)
        elif cfg["shape"] == "tower":
            out = sk.mirror([(0, 1.05), (0.55, 1.0), (0.72, 0.88), (0.72, -0.7), (0.55, -0.98), (0, -1.05)], S)
        else:
            out = sk.mirror([(0, 0.82), (0.42, 0.86), (0.76, 0.78), (0.76, 0.2), (0.56, -0.42), (0.28, -0.82), (0, -1.05)], S)
        top = max(z for _, z in out)
        wid = max(x for x, _ in out)
        parts = [sk.plate(name + "_aro", [(x * 1.09, z * 1.07) for x, z in out], -0.03, 0.03, pick[cfg["rim"]]),
                 sk.plate(name + "_corpo", out, -0.09, 0.02, pick[cfg["field"]])]
        for k in range(int(cfg.get("bands", 0))):
            z = top * (0.55 - k * 0.55)
            parts.append(sk.rib(name + "_faixa_%d" % k, z, wid * 0.92, 0.04, 0.06, gold, -0.07, 0.9))
        if cfg.get("maces"):       # duas maças cruzadas em relevo
            for k in (-1, 1):
                a, b_ = (k * wid * 0.62, -top * 0.62), (-k * wid * 0.42, top * 0.5)
                parts.append(sk.blade(name + "_cabo_%d" % (k + 1), a, b_, 0.05, 0.03, gold, 0.5, -0.11))
                parts.append(ck.ball(name + "_cabeca_%d" % (k + 1), 0.06, (b_[0], -0.13, b_[1]), gold, (1, 0.6, 1)))
        if cfg.get("boss"):
            parts.append(sk.plate(name + "_umbo", [(math.cos(math.tau * i / 16) * S * 0.3, math.sin(math.tau * i / 16) * S * 0.3) for i in range(16)], -0.17, -0.07, gold))
            for i in range(4):
                a = math.tau * i / 4 + math.pi / 2
                parts.append(sk.blade(name + "_cruz_%d" % i, (math.cos(a) * S * 0.3, math.sin(a) * S * 0.3), (math.cos(a) * S * 0.9, math.sin(a) * S * 0.9), 0.1, 0.03, wh, 0.75, -0.09))
        if cfg.get("wings"):
            for k in (-1, 1):
                for i in range(3):
                    parts.append(sk.blade(name + "_asa_%d_%d" % (k, i), (k * wid * 0.55, top * 0.6), (k * wid * (1.35 - i * 0.14), top * (1.15 - i * 0.25)), 0.11, 0.035, wh, 0.3, -0.05))
        if cfg.get("gem"):
            parts.append(sk.gem(name + "_gema", (0, 0 if cfg.get("boss") else top * 0.1), 0.065, sk.jewel(ck, cfg["gem"]), -0.19 if cfg.get("boss") else -0.15, 8, 1.0))
        if cfg.get("halo"):
            parts += sk.ring(name + "_halo", (0, top * 1.08), S * 0.28, 0.015, gold, 18, -0.06)
        return parts + sk._back(ck, name, mats)
    return fn


BIS_SHIELDS = {"bis_s5": shield_s5, "bis_s10": shield_s10, "bis_s15": shield_s15, "bis_s20": shield_s20, "bis_s25": shield_s25, "bis_s30": shield_s30}
BIS_SHIELDS.update({st: shield_battle(cf) for st, cf in BATTLE_SHIELDS.items()})


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


# ---------------------------------------------------------------------------
# Ato II (níveis 35/40/45 + Ápice da build; no híbrido, a armadura da 1ª build do par): UM visual novo por build, tema guerra
# contra a Horda em Monte Kharzun. A malha é a mesma nos três níveis; muda a cor do item (tint), o destaque (tint2) e o
# brilho: o material "tint_glow" recebe no jogo a cor de GearCatalog.ACT2_VISUALS[...]["glows"][nível] (KitModel).
# Os ESCUDOS continuam os do nível 30 (orçamento de malhas do kit): só armadura, maça e cetro são novos.
#   bis_s35 Sacerdote = Capelã de Campanha: chapéu largo de peregrino com borlas, manta enrolada e rolos de atadura,
#           túnica de campanha com bolsa, e oratório portátil nas costas com velas acesas.
#   bis_i35 Iluminado = Farol da Aurora: tiara em gaiola aberta com um orbe aceso flutuando em cima, mangas longas em
#           camadas, túnica alta e lisa, e gola de raios de sol aberta por trás dos ombros.
#   bis_b35 Clérigo de Batalha = Martelo da Vanguarda: bacinete de ponta com camal de malha e asas varridas para trás,
#           manto único de placa nos ombros, saiote blindado e livro acorrentado no quadril.
def _a2_body(ck, base, P, robe_m, legs_m, skirt_m, bottom, flare, belt_m, boots_m, plate=False):
    """Corpo, calça, saia, cinto e botas (peças que seguem o corpo). Devolve a saia."""
    import ranger_sets as rs
    rig, body, b = base["rig"], base["body"], base["b"]
    ck.armor_piece(body, rig, P + "body_robe", "torso", robe_m, 0.02 if plate else 0.014, 0.018 if plate else 0.014, 0.03)
    ck.armor_piece(body, rig, P + "body_legs", "legs", legs_m, 0.008, 0.012)
    sk = ck.skirt(P + "body_skirt", b, body, rig, skirt_m, bottom, flare)
    rs.body_belt(ck, base, P + "body_belt", ck.Z["waist"] - 0.04, ck.Z["waist"] + 0.035, 1.21, belt_m)
    ck.armor_piece(body, rig, P + "boots_shell", "boots", boots_m, 0.024 if plate else 0.02, 0.016 if plate else 0.014)
    return sk


def _skirt_band(ck, base, name, bottom, flare, tt, half, material):
    """Faixa em volta da saia na altura tt (0 = cintura, 1 = barra), com os pesos do corpo."""
    b, d = base["b"], base["b"]["depth"]
    top = ck.Z["waist"] - 0.02
    z = top + (bottom - top) * tt
    rr = b["waist"] * 1.18 * (1.0 + (flare - 1.0) * tt ** 1.2) + 0.022
    band = ck.tube(name, (0, 0, z - half), (0, 0, z + half), rr * 1.02, rr * 0.99, material, 16)
    for v in band.data.vertices:
        v.co.y *= d * 1.05
    ck._smooth(band.data)
    ck.transfer_weights(band, base["body"], base["rig"])
    return band


def _candle(ck, name, foot, h, wax, glow):
    V = Vector
    foot = V(foot)
    return [ck.tube(name, foot, foot + V((0, 0, h)), 0.022, 0.019, wax, 6),
            ck.blade(name + "_flame", foot + V((0, 0, h - 0.005)), foot + V((0, 0, h + 0.085)), 0.05, 0.04, glow, (1, 0, 0), 0.35)]


def build_chaplain(ck, base, mats, style):
    """bis_s35 — Capelã de Campanha (Sacerdote)."""
    import ranger_sets as rs
    import necromancer_sets as ns
    V = Vector
    rig, b, j = base["rig"], base["b"], base["j"]
    t, t2, gold, wh, leather, wood = mats["tint"], mats["tint2"], mats["trim"], mats["white"], mats["leather"], mats["wood"]
    P = "arm_%s_" % style
    glow = rs.tint_glow(ck)
    bottom, flare = 0.085, 1.78
    _a2_body(ck, base, P, t, wh, t, bottom, flare, leather, leather)
    _skirt_band(ck, base, P + "body_hem", bottom, flare, 0.93, 0.022, t2)
    c, r = V(base["head_c"]), b["head"]
    # ---------------- cabeça: touca branca, chapéu de peregrino de aba larga, faixa com concha, quatro borlas ----------------
    head = [ck._shell(P + "head_coif", c, r * 1.14, 0.3, -0.95, -0.5, 0.03, wh),
            ck.tube(P + "head_brim", c + V((0, 0, r * 0.46)), c + V((0, 0, r * 0.56)), r * 1.86, r * 1.7, t, 28),
            ck.tube(P + "head_brim_edge", c + V((0, 0, r * 0.44)), c + V((0, 0, r * 0.49)), r * 1.9, r * 1.9, gold, 28),
            ck._shell(P + "head_crown", c + V((0, 0, r * 0.06)), r * 1.21, 0.42, 0.38, 0.38, 0.035, t),
            ck.tube(P + "head_band", c + V((0, 0, r * 0.56)), c + V((0, 0, r * 0.74)), r * 1.13, r * 1.05, t2, 20),
            ck.ball(P + "head_badge", r * 0.2, c + V((0, -r * 1.1, r * 0.67)), gold, (1.0, 0.4, 1.0)),
            ck.ball(P + "head_badge_core", r * 0.1, c + V((0, -r * 1.17, r * 0.67)), glow, (1.0, 0.5, 1.0))]
    for k in range(4):                   # borlas penduradas na aba (lados e atrás)
        a = math.radians((20, 160, 62, 118)[k])
        p = c + V((math.cos(a) * r * 1.8, math.sin(a) * r * 1.8, r * 0.45))
        head += [ck.tube(P + "head_cord%d" % k, p, p - V((0, 0, r * 0.42)), 0.01, 0.01, gold, 4),
                 ck.ball(P + "head_tassel_k%d" % k, r * 0.085, p - V((0, 0, r * 0.44)), gold),
                 ck.tube(P + "head_tassel%d" % k, p - V((0, 0, r * 0.46)), p - V((0, 0, r * 0.78)), r * 0.05, r * 0.12, t2, 6)]
    ck._rigid(rs.outward(head), rig, "head")
    # ---------------- corpo: escapulário branco com cruz, gola, mochila-oratório com velas, manta enrolada ----------------
    d = b["depth"]
    front = -b["chest"] * d - 0.03
    back = b["chest"] * d + 0.03
    zc, zn, zw = ck.Z["chest"], ck.Z["neck"], ck.Z["waist"]
    chest = [ck.box(P + "body_panel", (0.13, 0.02, 0.3), (0, front, zc - 0.06), wh, 0.006),
             ck.box(P + "body_cross_v", (0.035, 0.025, 0.15), (0, front - 0.016, zc - 0.01), gold, 0.006),
             ck.box(P + "body_cross_h", (0.1, 0.025, 0.035), (0, front - 0.016, zc + 0.025), gold, 0.006),
             ck.ball(P + "body_cross_core", 0.022, (0, front - 0.03, zc + 0.025), glow),
             ck.tube(P + "body_capelet", V((0, 0, zn - 0.02)), V((0, 0, zc + 0.05)), b["chest"] * 0.55, b["chest"] * 1.12, wh, 18),
             ck.tube(P + "body_capelet_hem", V((0, 0, zc + 0.04)), V((0, 0, zc + 0.07)), b["chest"] * 1.14, b["chest"] * 1.14, t2, 18)]
    # mochila: caixa de madeira nas costas, manta enrolada por cima, postes que sobem por fora da cabeça até o oratório
    py = back + 0.085
    chest += [ck.box(P + "body_pack", (0.3, 0.15, 0.3), (0, py, zc + 0.0), wood, 0.015),
              ck.box(P + "body_pack_lid", (0.32, 0.17, 0.04), (0, py, zc + 0.16), leather, 0.01),
              ck.tube(P + "body_blanket", (-0.3, py + 0.01, zc + 0.25), (0.3, py + 0.01, zc + 0.25), 0.075, 0.075, t2, 10)]
    for sx in (-1, 1):
        chest += [ck.tube(P + "body_blanket_strap%d" % sx, (sx * 0.15, py + 0.01, zc + 0.25), (sx * 0.19, py + 0.01, zc + 0.25), 0.081, 0.081, leather, 10),
                  ck.ball(P + "body_blanket_end%d" % sx, 0.05, (sx * 0.305, py + 0.01, zc + 0.25), wh, (0.3, 1, 1)),
                  ck.tube(P + "body_pack_strap%d" % sx, (sx * 0.1, py - 0.05, zc + 0.14), (sx * 0.11, front + 0.012, zc + 0.14), 0.016, 0.016, leather, 5)]
    sy = r * 1.9 + 0.15                  # o oratório fica atrás da ABA do chapéu (raio 1,9 r) e acima dela: os postes saem da
    sz = c.z + r * 0.72                  # mochila para trás e só então sobem, por fora da aba (antes atravessavam a aba)
    for sx in (-1, 1):
        knee = V((sx * 0.15, sy, zc + 0.2))
        chest.append(ck.tube(P + "body_post%d" % sx, (sx * 0.12, py + 0.05, zc + 0.12), knee, 0.022, 0.02, wood, 6))
        chest.append(ck.tube(P + "body_post_up%d" % sx, knee, (sx * 0.15, sy, sz), 0.02, 0.018, wood, 6))
        chest.append(ck.ball(P + "body_post_knee%d" % sx, 0.028, knee, leather))
    chest += [ck.box(P + "body_shrine_floor", (0.44, 0.2, 0.035), (0, sy, sz), wood, 0.008),
              ck.box(P + "body_shrine_back", (0.34, 0.03, 0.3), (0, sy + 0.07, sz + 0.16), wood, 0.008),
              ck.box(P + "body_shrine_icon", (0.2, 0.02, 0.2), (0, sy + 0.05, sz + 0.15), wh, 0.006),
              ck.ball(P + "body_shrine_sun", 0.06, (0, sy + 0.03, sz + 0.16), glow, (1.0, 0.4, 1.0))]
    for sx in (-1, 1):                   # telhadinho de duas águas da cor de destaque
        chest.append(rs.ribbon(ck, P + "body_shrine_roof%d" % sx, [(sx * 0.25, sy, sz + 0.27), (0, sy, sz + 0.42)], (0, 1, 0), (0.26, 0.26), 0.03, t2))
        chest += [ck.tube(P + "body_shrine_col%d" % sx, (sx * 0.17, sy - 0.06, sz), (sx * 0.17, sy - 0.06, sz + 0.3), 0.016, 0.016, gold, 6)]
        chest += _candle(ck, P + "body_candle%d" % sx, (sx * 0.1, sy - 0.055, sz + 0.015), 0.1, wh, glow)
    chest += _candle(ck, P + "body_candle_top", (0, sy, sz + 0.41), 0.07, wh, glow)
    ck._rigid(rs.outward(chest), rig, "chest")
    wf = -b["waist"] * d * 1.21
    hips = [ck.box(P + "body_satchel", (0.15, 0.08, 0.14), (0.17, wf * 0.55, zw - 0.11), leather, 0.012),
            ck.box(P + "body_satchel_flap", (0.16, 0.085, 0.06), (0.17, wf * 0.55 - 0.004, zw - 0.065), t2, 0.01),
            ck.ball(P + "body_satchel_clasp", 0.02, (0.17, wf * 0.55 - 0.05, zw - 0.09), glow),
            ck.ball(P + "body_knot", 0.03, (-0.05, wf - 0.012, zw), gold)]
    for k in range(3):                   # rolos de atadura no cinto, à direita
        hips.append(ck.tube(P + "body_roll%d" % k, (-0.13 - k * 0.045, wf * (0.82 - k * 0.2), zw - 0.03), (-0.13 - k * 0.045, wf * (0.82 - k * 0.2), zw - 0.12), 0.026, 0.026, wh, 8))
    ck._rigid(rs.outward(hips), rig, "hips")
    for s, sx in ((".R", -1), (".L", 1)):                 # ombros: rolo de atadura deitado sobre a capinha
        tag = s.replace(".", "_")
        sh = V(j["shoulder" + s])
        pa = [ck.ball(P + "body_pad" + tag, b["arm"] * 2.1, sh + V((sx * 0.05, 0, 0.04)), wh, (1.1, 1.05, 0.5)),
              ck.tube(P + "body_sroll" + tag, sh + V((sx * 0.07, -0.085, 0.1)), sh + V((sx * 0.07, 0.085, 0.1)), 0.045, 0.045, wh, 8),
              ck.tube(P + "body_sroll_band" + tag, sh + V((sx * 0.07, -0.02, 0.1)), sh + V((sx * 0.07, 0.02, 0.1)), 0.049, 0.049, t2, 8)]
        ck._rigid(rs.outward(pa), rig, "upper_arm" + s)
    # ---------------- mangas com ataduras, terço no pulso direito, botas de caminhada ----------------
    for s, sx in ((".R", -1), (".L", 1)):
        tag = s.replace(".", "_")
        el, wr = V(j["elbow" + s]), V(j["wrist" + s])
        g = [ck.tube(P + "gloves_sleeve" + tag, el.lerp(wr, 0.3), wr + V((0, 0, -0.01)), 0.072, 0.11, t, 14),
             ck.tube(P + "gloves_cuff" + tag, wr + V((0, 0, -0.012)), wr + V((0, 0, 0.012)), 0.115, 0.115, wh, 14),
             ck.tube(P + "gloves_wrap" + tag, el.lerp(wr, 0.4), el.lerp(wr, 0.55), 0.086, 0.094, wh, 14)]
        if sx < 0:
            for k in range(5):
                g.append(ck.ball(P + "gloves_bead%d" % k, 0.014, wr + V((-0.118, -0.02 + 0.0, 0.0 - k * 0.03)), gold))
            g.append(ck.ball(P + "gloves_bead_core", 0.024, wr + V((-0.118, -0.02, -0.165)), glow))
        else:
            g.append(ck.ball(P + "gloves_gem", 0.02, wr + V((0.118, -0.02, 0.0)), glow))
        ck._rigid(rs.outward(g), rig, "forearm" + s)
        ck._rigid([ck.ball(P + "gloves_fist" + tag, b["hand"] * 1.25, ck.hand_center(base, s), wh, (1, 1, 1.1))], rig, "hand" + s)
        an = V(j["ankle" + s])
        ck._rigid(rs.outward([ck.tube(P + "boots_cuff" + tag, an + V((0, 0, 0.055)), an + V((0, 0, 0.1)), 0.08, 0.088, wh, 12),
                              ck.tube(P + "boots_band" + tag, an + V((0, 0, 0.035)), an + V((0, 0, 0.055)), 0.079, 0.079, t2, 12),
                              ck.ball(P + "boots_gem" + tag, 0.018, an + V((0, -0.085, 0.078)), glow)]), rig, "shin" + s)


def build_beacon(ck, base, mats, style):
    """bis_i35 — Farol da Aurora (Iluminado)."""
    import ranger_sets as rs
    import necromancer_sets as ns
    import elementalist_sets as es
    V = Vector
    rig, b, j = base["rig"], base["b"], base["j"]
    t, t2, gold, wh = mats["tint"], mats["tint2"], mats["trim"], mats["white"]
    P = "arm_%s_" % style
    glow = rs.tint_glow(ck)
    bottom, flare = 0.045, 2.0
    _a2_body(ck, base, P, t, wh, t, bottom, flare, gold, wh)
    _skirt_band(ck, base, P + "body_hem", bottom, flare, 0.94, 0.026, gold)
    _skirt_band(ck, base, P + "body_hem2", bottom, flare, 0.8, 0.012, t2)
    c, r = V(base["head_c"]), b["head"]
    # ---------------- cabeça: aro, gaiola aberta de seis hastes até um anel no alto, orbe aceso flutuando com aro de farol ----------------
    head = es._act2_hair(ck, base, P)
    head += [ck.tube(P + "head_circlet", c + V((0, 0, r * 0.36)), c + V((0, 0, r * 0.5)), r * 1.13, r * 1.11, gold, 24),
             ck.ball(P + "head_gem", r * 0.12, c + V((0, -r * 1.14, r * 0.43)), glow, (1, 0.6, 1.3))]
    ztop = r * 1.42
    for k in range(6):
        a = math.tau * (k + 0.5) / 6
        dv = V((math.cos(a), math.sin(a), 0))
        head += rs.curve(ck, P + "head_bar%d" % k, c + dv * r * 1.1 + V((0, 0, r * 0.48)), c + dv * r * 0.36 + V((0, 0, ztop)), dv * r * 0.42 + V((0, 0, r * 0.12)), 0.024, gold, 5, 6, 0.02)
        head.append(ck.ball(P + "head_bar_knob%d" % k, r * 0.085, c + dv * r * 1.12 + V((0, 0, r * 0.5)), t2))
    ux, uy = V((1, 0, 0)), V((0, 1, 0))
    head += ns._ring(ck, P + "head_top_ring", c + V((0, 0, ztop)), ux, uy, r * 0.36, 0.024, gold, 12)
    oc = c + V((0, 0, r * 1.86))
    head.append(ck.ball(P + "head_orb", r * 0.34, oc, glow))
    head += ns._ring(ck, P + "head_orb_ring", oc, ux, uy, r * 0.56, 0.018, gold, 14)
    for k in range(8):                   # raios curtos em volta do aro do orbe
        a = math.tau * k / 8
        dv = V((math.cos(a), math.sin(a), 0))
        head.append(ck.blade(P + "head_orb_ray%d" % k, oc + dv * r * 0.58, oc + dv * r * (0.95 if k % 2 == 0 else 0.78), r * 0.2, 0.02, gold if k % 2 else glow, V((-dv.y, dv.x, 0)), 0.35))
    ck._rigid(rs.outward(head), rig, "head")
    # ---------------- corpo: gola alta, faixa branca com sol, gola de raios aberta por trás dos ombros ----------------
    d = b["depth"]
    front = -b["chest"] * d - 0.03
    back = b["chest"] * d + 0.03
    zc, zn, zw = ck.Z["chest"], ck.Z["neck"], ck.Z["waist"]
    chest = [ck.tube(P + "body_collar", V((0, 0, zn - 0.04)), V((0, 0, zn + 0.08)), b["chest"] * 0.5, b["chest"] * 0.64, gold, 16),
             ck.box(P + "body_panel", (0.085, 0.016, 0.3), (0, front, zc - 0.05), wh, 0.005),
             ck.ball(P + "body_sun", 0.04, (0, front - 0.016, zc + 0.04), glow, (1, 0.45, 1))]
    for k in range(8):
        a = math.tau * k / 8
        dv = V((math.cos(a), 0, math.sin(a)))
        chest.append(ck.blade(P + "body_sun_ray%d" % k, V((0, front - 0.014, zc + 0.04)) + dv * 0.036, V((0, front - 0.014, zc + 0.04)) + dv * 0.085, 0.03, 0.014, gold, V((-dv.z, 0, dv.x))))
    # raios: leque de meio círculo num plano tombado para trás, raiz na nuca; de cima lê como um sol nascendo atrás dos ombros
    tilt = math.radians(38)
    up_t = V((0, math.sin(tilt), math.cos(tilt)))
    rc = V((0, back + 0.05, zn - 0.02))
    chest.append(ck.blade(P + "body_rays_base", rc - up_t * 0.02, rc + up_t * 0.2, 0.42, 0.03, gold, ux, 0.2))
    n = 11
    for k in range(n):
        a = math.pi * k / (n - 1)
        dv = ux * math.cos(a) + up_t * math.sin(a)
        long_ = k % 2 == 0
        tip = rc + dv * (0.74 if long_ else 0.56)
        chest.append(ck.blade(P + "body_ray%d" % k, rc + dv * 0.12, tip, 0.15 if long_ else 0.11, 0.024, gold if long_ else t2, ux * -math.sin(a) + up_t * math.cos(a), 0.3))
        if long_:
            chest.append(ck.ball(P + "body_ray_tip%d" % k, 0.034, tip - dv * 0.02, glow))
    ck._rigid(rs.outward(chest), rig, "chest")
    wf = -b["waist"] * d * 1.21
    hips = [ck.blade(P + "body_stole", (0, wf - 0.006, zw - 0.02), (0, wf - 0.04, zw - 0.42), 0.1, 0.012, wh, (1, 0, 0), 0.7),
            ck.ball(P + "body_buckle", 0.034, (0, wf - 0.02, zw), glow, (1, 0.5, 1))]
    ck._rigid(rs.outward(hips), rig, "hips")
    for s, sx in ((".R", -1), (".L", 1)):                 # 1ª camada da manga: sino branco do ombro ao cotovelo, com filete
        tag = s.replace(".", "_")
        sh, el = V(j["shoulder" + s]), V(j["elbow" + s])
        pa = [ck.ball(P + "body_pad" + tag, b["arm"] * 2.0, sh + V((sx * 0.04, 0, 0.03)), t, (1.1, 1.05, 0.55)),
              ck.tube(P + "body_bell" + tag, sh + V((sx * 0.02, 0, -0.02)), el + V((sx * 0.012, 0, 0.0)), 0.08, 0.125, wh, 14),
              ck.tube(P + "body_bell_hem" + tag, el + V((sx * 0.012, 0, 0.012)), el + V((sx * 0.012, 0, -0.012)), 0.129, 0.129, gold, 14)]
        ck._rigid(rs.outward(pa), rig, "upper_arm" + s)
    # ---------------- mangas: 2ª camada larga até o pulso e cauda comprida pendurada; botas brancas ----------------
    for s, sx in ((".R", -1), (".L", 1)):
        tag = s.replace(".", "_")
        el, wr = V(j["elbow" + s]), V(j["wrist" + s])
        g = [ck.tube(P + "gloves_sleeve" + tag, el.lerp(wr, 0.12), wr + V((0, 0, -0.02)), 0.08, 0.14, t, 14),
             ck.tube(P + "gloves_cuff" + tag, wr + V((0, 0, 0.0)), wr + V((0, 0, -0.03)), 0.145, 0.145, gold, 14),
             rs.ribbon(ck, P + "gloves_tail" + tag, [wr + V((0, 0.13, -0.01)), wr + V((0, 0.17, -0.16)), wr + V((0, 0.15, -0.3))], (1, 0, 0), (0.16, 0.13, 0.03), 0.014, t2),
             ck.ball(P + "gloves_gem" + tag, 0.022, wr + V((sx * 0.14, -0.03, -0.012)), glow)]
        ck._rigid(rs.outward(g), rig, "forearm" + s)
        ck._rigid([ck.ball(P + "gloves_fist" + tag, b["hand"] * 1.25, ck.hand_center(base, s), wh, (1, 1, 1.1))], rig, "hand" + s)
        an = V(j["ankle" + s])
        ck._rigid(rs.outward([ck.tube(P + "boots_band" + tag, an + V((0, 0, 0.05)), an + V((0, 0, 0.08)), 0.077, 0.077, gold, 12),
                              ck.ball(P + "boots_gem" + tag, 0.02, an + V((0, -0.085, 0.07)), glow)]), rig, "shin" + s)


def build_vanguard(ck, base, mats, style):
    """bis_b35 — Martelo da Vanguarda (Clérigo de Batalha)."""
    import ranger_sets as rs
    import necromancer_sets as ns
    V = Vector
    rig, b, j = base["rig"], base["b"], base["j"]
    t, t2, gold, wh, metal = mats["tint"], mats["tint2"], mats["trim"], mats["white"], mats["metal"]
    P = "arm_%s_" % style
    glow = rs.tint_glow(ck)
    chain = ck.mat("m_bis_chain", (0.62, 0.64, 0.7), 0.45)
    bottom, flare = 0.2, 1.5
    sk = _a2_body(ck, base, P, t, metal, wh, bottom, flare, gold, t, True)
    d = b["depth"]
    zc, zn, zw = ck.Z["chest"], ck.Z["neck"], ck.Z["waist"]
    tas = []                             # saiote blindado: lâminas de placa nos lados e atrás (a frente fica com o tabardo)
    n = 10
    for k in range(n):
        a = math.tau * (k + 0.5) / n
        if abs(math.sin(a) + 1.0) < 0.2:
            continue
        dv = V((math.cos(a), math.sin(a) * d * 1.05, 0))
        tang = V((-dv.y, dv.x, 0)).normalized()
        p0 = dv * (b["waist"] * 1.24) + V((0, 0, zw - 0.03))
        p1 = dv * (b["waist"] * 1.18 * 1.36 + 0.03) + V((0, 0, zw - 0.26))
        tas += [rs.ribbon(ck, P + "body_tasset%d" % k, [p0, p0.lerp(p1, 0.55) + dv * 0.012, p1], tang, (0.105, 0.125, 0.11), 0.02, t),
                ck.tube(P + "body_tasset_rim%d" % k, p1 - tang * 0.058, p1 + tang * 0.058, 0.014, 0.014, gold, 5)]
    tas = ck._join(rs.outward(tas), P + "body_tassets")
    ck._smooth(tas.data)
    ck.transfer_weights(tas, sk, rig)
    c, r = V(base["head_c"]), b["head"]
    # ---------------- cabeça: bacinete de ponta para trás, camal de malha, testeira com gema, asas varridas ----------------
    head = [ck._shell(P + "head_aventail", c, r * 1.15, 0.26, -1.08, -0.86, 0.03, chain),
            ck._shell(P + "head_cap", c, r * 1.21, 0.36, 0.0, 0.1, 0.04, t),
            ck.tube(P + "head_point_a", c + V((0, 0.0, r * 0.6)), c + V((0, r * 0.16, r * 1.22)), r * 1.05, r * 0.5, t, 16),
            ck.tube(P + "head_point_b", c + V((0, r * 0.16, r * 1.22)), c + V((0, r * 0.55, r * 1.78)), r * 0.5, r * 0.03, t, 12),
            ck.blade(P + "head_ridge", c + V((0, -r * 1.12, r * 0.5)), c + V((0, r * 0.5, r * 1.74)), r * 0.2, 0.05, gold, (1, 0, 0), 0.5),
            ck.tube(P + "head_band", c + V((0, 0, r * 0.18)), c + V((0, 0, r * 0.36)), r * 1.27, r * 1.25, gold, 24),
            ck.box(P + "head_nasal", (0.034, 0.04, r * 0.46), c + V((0, -r * 1.23, r * 0.06)), gold, 0.01),
            ck.ball(P + "head_gem", r * 0.11, c + V((0, -r * 1.27, r * 0.3)), glow, (1, 0.6, 1.2))]
    for k in range(9):                   # barra do camal caindo nos ombros (dentes de malha)
        a = math.pi * (-0.1 + 1.2 * k / 8)
        dv = V((math.cos(a), math.sin(a), 0))
        head.append(ck.blade(P + "head_mail%d" % k, c + dv * r * 1.08 + V((0, 0, -r * 0.7)), c + dv * r * 1.3 + V((0, 0, -r * 1.22)), r * 0.5, 0.02, chain, V((-dv.y, dv.x, 0)), 0.35))
    for sx in (-1, 1):                   # asas varridas para trás, três penas de cada lado
        for k in range(3):
            root = c + V((sx * r * 1.12, r * 0.05, r * (0.34 - k * 0.1)))
            tip = c + V((sx * r * (1.75 - k * 0.2), r * (1.15 + k * 0.28), r * (1.02 - k * 0.38)))
            head.append(ck.blade(P + "head_wing%d_%d" % (sx, k), root, tip, r * (0.5 - k * 0.07), 0.045, wh if k else t2, (0, 0.35, 1), 0.35))
        head.append(ck.ball(P + "head_wing_boss%d" % sx, r * 0.16, c + V((sx * r * 1.2, r * 0.02, r * 0.3)), gold, (0.5, 1, 1)))
    ck._rigid(rs.outward(head), rig, "head")
    # ---------------- corpo: tabardo curto, manto único de placa de ombro a ombro com rebites e fecho aceso ----------------
    front = -b["chest"] * d - 0.03
    back = b["chest"] * d + 0.03
    rw = abs(V(j["shoulder.L"]).x) + 0.2
    mantle = [ck.tube(P + "body_mantle", V((0, 0, zn + 0.035)), V((0, 0, zn - 0.085)), b["chest"] * 0.62, rw, t, 20),
              ck.tube(P + "body_mantle_drop", V((0, 0, zn - 0.085)), V((0, 0, zn - 0.2)), rw, rw * 1.05, t, 20),
              ck.tube(P + "body_mantle_rim", V((0, 0, zn - 0.19)), V((0, 0, zn - 0.23)), rw * 1.07, rw * 1.07, gold, 20),
              ck.tube(P + "body_mantle_neck", V((0, 0, zn + 0.02)), V((0, 0, zn + 0.085)), b["chest"] * 0.6, b["chest"] * 0.7, gold, 16)]
    for o in mantle:
        for v in o.data.vertices:
            v.co.y *= 0.88
    chest = mantle
    for k in range(10):                  # rebites na borda do manto
        a = math.tau * (k + 0.5) / 10
        chest.append(ck.ball(P + "body_rivet%d" % k, 0.026, (math.cos(a) * rw * 0.9, math.sin(a) * rw * 1.04 * 0.88, zn - 0.14), gold))
    chest += [ck.ball(P + "body_clasp", 0.055, (0, -rw * 1.04 * 0.88, zn - 0.14), glow, (1, 0.5, 1.2)),
              ck.box(P + "body_tabard", (0.15, 0.018, 0.2), (0, front - 0.004, zc - 0.03), wh, 0.006),
              ck.box(P + "body_cross_v", (0.036, 0.024, 0.14), (0, front - 0.02, zc - 0.03), t2, 0.006),
              ck.box(P + "body_cross_h", (0.1, 0.024, 0.036), (0, front - 0.02, zc + 0.0), t2, 0.006),
              ck.box(P + "body_back_v", (0.045, 0.024, 0.2), (0, back + 0.0, zc - 0.03), gold, 0.006),
              ck.box(P + "body_back_h", (0.14, 0.024, 0.045), (0, back + 0.0, zc + 0.02), gold, 0.006),
              ck.box(P + "body_plackart", (0.2, 0.03, 0.05), (0, -b["waist"] * d * 1.12 - 0.02, zw + 0.06), gold, 0.012)]
    ck._rigid(rs.outward(chest), rig, "chest")
    wf = -b["waist"] * d * 1.21
    hips = [ck.blade(P + "body_tab", (0, wf - 0.006, zw - 0.01), (0, wf - 0.04, zw - 0.36), 0.15, 0.014, wh, (1, 0, 0), 0.8),
            ck.box(P + "body_tab_v", (0.034, 0.02, 0.13), (0, wf - 0.03, zw - 0.19), t2, 0.005),
            ck.box(P + "body_tab_h", (0.09, 0.02, 0.034), (0, wf - 0.03, zw - 0.16), t2, 0.005)]
    bx = -(b["waist"] * 1.24 + 0.075)    # livro acorrentado no quadril direito
    bk = V((bx, -0.03, zw - 0.2))
    for k in range(4):
        hips.append(ck.ball(P + "body_bchain%d" % k, 0.016, V((bx + 0.03, -0.03, zw - 0.02 - k * 0.035)), chain, (1, 0.6, 1.2)))
    hips += [ck.box(P + "body_book", (0.075, 0.16, 0.2), bk, t2, 0.01),
             ck.box(P + "body_book_pages", (0.05, 0.14, 0.205), bk + V((0, -0.016, 0)), wh, 0.004),
             ck.box(P + "body_book_clasp", (0.082, 0.03, 0.05), bk + V((0, -0.076, 0)), gold, 0.006),
             ck.ball(P + "body_book_sigil", 0.034, bk + V((-0.04, 0.0, 0.01)), glow, (0.4, 1, 1))]
    for sy in (-1, 1):
        for sz in (-1, 1):
            hips.append(ck.ball(P + "body_book_corner%d_%d" % (sy, sz), 0.022, bk + V((-0.03, sy * 0.07, sz * 0.09)), gold))
    ck._rigid(rs.outward(hips), rig, "hips")
    # ---------------- manoplas e grevas de placa ----------------
    for s, sx in ((".R", -1), (".L", 1)):
        tag = s.replace(".", "_")
        el, wr = V(j["elbow" + s]), V(j["wrist" + s])
        g = [ck.tube(P + "gloves_cuff" + tag, el.lerp(wr, 0.2), wr + V((0, 0, 0.01)), 0.078, 0.11, t, 12),
             ck.tube(P + "gloves_rim" + tag, wr + V((0, 0, 0.005)), wr + V((0, 0, 0.032)), 0.117, 0.117, gold, 12),
             ck.ball(P + "gloves_couter" + tag, 0.06, el + V((sx * 0.02, 0.02, 0.0)), gold, (1, 1, 0.8)),
             ck.ball(P + "gloves_gem" + tag, 0.022, el.lerp(wr, 0.6) + V((sx * 0.085, -0.03, 0)), glow)]
        ck._rigid(rs.outward(g), rig, "forearm" + s)
        ck._rigid([ck.ball(P + "gloves_fist" + tag, b["hand"] * 1.38, ck.hand_center(base, s), t, (1, 1, 1.1))], rig, "hand" + s)
        an = V(j["ankle" + s])
        ck._rigid(rs.outward([ck.tube(P + "boots_band" + tag, an + V((0, 0, 0.05)), an + V((0, 0, 0.078)), 0.079, 0.079, gold, 12),
                              ck.ball(P + "boots_knee" + tag, 0.072, V(j["knee" + s]) + V((0, -0.07, 0.01)), gold, (1.05, 0.7, 1.0)),
                              ck.ball(P + "boots_gem" + tag, 0.02, V(j["knee" + s]) + V((0, -0.125, 0.012)), glow)]), rig, "shin" + s)


def build_mace2(ck, base, mats, style, kind):
    """Maças do Ato II (eixo das maças do kit, uma mão): lantern = maça-lanterna de capelã (miolo aceso entre flanges),
    hammer = martelo de guerra curto com runa acesa nas duas faces. Brilho = tint_glow."""
    import ranger_sets as rs
    import necromancer_sets as ns
    V = Vector
    g = V(ck.hand_center(base, ".R"))
    fwd = V((0, -0.55, 0.83)).normalized()
    side = V((1, 0, 0))
    ridge = fwd.cross(side).normalized()
    t, t2, gold, wh, metal, wood = mats["tint"], mats["tint2"], mats["trim"], mats["white"], mats["metal"], mats["wood"]
    glow = rs.tint_glow(ck)
    n = "m_%s_main_" % style
    hc = g + fwd * 0.56
    parts = [ck.ball(n + "pommel", 0.045, g - fwd * 0.15, gold), ck.tube(n + "collar", g + fwd * 0.36, g + fwd * 0.42, 0.05, 0.052, gold, 10)]
    for k in range(3):
        parts.append(ck.tube(n + "wrap%d" % k, g + fwd * (-0.08 + k * 0.07), g + fwd * (-0.055 + k * 0.07), 0.035, 0.035, gold if kind == "hammer" else t2, 8))
    if kind == "lantern":
        parts += [ck.tube(n + "shaft", g - fwd * 0.13, g + fwd * 0.44, 0.03, 0.028, wood, 8),
                  ck.ball(n + "core", 0.1, hc, glow, (1, 1, 1.2)),
                  ck.tube(n + "base", hc - fwd * 0.16, hc - fwd * 0.11, 0.07, 0.1, gold, 10),
                  ck.tube(n + "roof", hc + fwd * 0.11, hc + fwd * 0.2, 0.11, 0.03, t, 10),
                  ck.tube(n + "roof_rim", hc + fwd * 0.1, hc + fwd * 0.125, 0.118, 0.118, gold, 10),
                  ck.tube(n + "finial_v", hc + fwd * 0.2, hc + fwd * 0.33, 0.016, 0.016, gold, 5),
                  ck.tube(n + "finial_h", hc + fwd * 0.27 - side * 0.045, hc + fwd * 0.27 + side * 0.045, 0.016, 0.016, gold, 5)]
        for k in range(6):
            a = math.tau * k / 6
            dv = side * math.cos(a) + ridge * math.sin(a)
            parts.append(ck._flange(n + "flange%d" % k, hc, fwd, dv, 0.19, 0.27, 0.03, metal))
        tie = g - fwd * 0.17                 # fita de oração amarrada no pomo
        parts.append(rs.ribbon(ck, n + "ribbon", [tie, tie - fwd * 0.05 + V((0, 0.03, -0.1)), tie + V((0, 0.05, -0.22))], (1, 0, 0), (0.05, 0.05, 0.02), 0.01, t2))
    else:
        parts += [ck.tube(n + "shaft", g - fwd * 0.13, g + fwd * 0.5, 0.032, 0.03, t2, 8),
                  ck.box(n + "block", (0.15, 0.15, 0.15), hc, metal, 0.02)]
        import mathutils
        rot = mathutils.Matrix.Translation(hc) @ V((0, 0, 1)).rotation_difference(fwd).to_matrix().to_4x4() @ mathutils.Matrix.Translation(-hc)
        parts[-1].data.transform(rot)
        for sg in (-1, 1):                   # duas cabeças (uma de cada lado), cinta dourada e runa acesa na face
            fc = hc + side * sg * 0.17
            parts += [ck.tube(n + "head%d" % sg, hc + side * sg * 0.05, fc, 0.1, 0.115, metal, 8),
                      ck.tube(n + "hband%d" % sg, hc + side * sg * 0.09, hc + side * sg * 0.125, 0.122, 0.122, gold, 8),
                      ck.tube(n + "face%d" % sg, fc, fc + side * sg * 0.02, 0.118, 0.095, t, 8),
                      ck.ball(n + "rune%d" % sg, 0.06, fc + side * sg * 0.02, glow, (0.35, 1, 1))]
        parts += [ck.tube(n + "spike", hc + fwd * 0.07, hc + fwd * 0.27, 0.05, 0.004, gold, 6),
                  ck.ball(n + "top_gem", 0.04, hc + ridge * 0.08, glow, (1, 0.5, 1)),
                  ck.ball(n + "top_gem_b", 0.04, hc - ridge * 0.08, glow, (1, 0.5, 1))]
        for sx in (-1, 1):                   # asinhas na gola
            for k in range(2):
                parts.append(ck.blade(n + "wing%d_%d" % (sx, k), g + fwd * 0.4 + side * sx * 0.03, g + fwd * (0.36 - k * 0.07) + side * sx * (0.17 - k * 0.04), 0.06, 0.016, wh, ridge))
    obj = ck._join(rs.outward(parts), "wpn_main_mace_%s" % style)
    ck._smooth(obj.data)
    ck.skin_rigid(obj, base["rig"], "hand.R")
    return obj


def build_scepter2(ck, base, mats, style):
    """Cetro do Ato II do Iluminado: farol — plataforma, quatro colunas, orbe aceso, telhado em cone e roda de raios."""
    import ranger_sets as rs
    import necromancer_sets as ns
    V = Vector
    g = V(ck.hand_center(base, ".R"))
    up = V((-0.22, -0.12, 1.0)).normalized()
    side = V((1, 0, 0))
    fwd = up.cross(side).normalized()
    t, t2, gold, wh = mats["tint"], mats["tint2"], mats["trim"], mats["white"]
    glow = rs.tint_glow(ck)
    n = "s_%s_" % style
    ln = 1.3
    top = g + up * (ln * 0.58)
    parts = [ck.tube(n + "shaft", g - up * (ln * 0.42), top, 0.027, 0.031, wh, 8), ck.tube(n + "foot", g - up * (ln * 0.47), g - up * (ln * 0.41), 0.012, 0.04, gold, 8)]
    for k in range(4):
        z = ln * (-0.3 + k * 0.24)
        parts.append(ck.tube(n + "ring%d" % k, g + up * z, g + up * (z + 0.035), 0.041, 0.041, gold if k % 2 else t, 10))
    parts += [ck.tube(n + "deck", top, top + up * 0.05, 0.055, 0.125, gold, 12),
              ck.tube(n + "deck_rim", top + up * 0.045, top + up * 0.07, 0.132, 0.132, t2, 12)]
    oc = top + up * 0.2
    for k in range(4):
        a = math.tau * k / 4 + math.pi / 4
        dv = side * math.cos(a) + fwd * math.sin(a)
        parts.append(ck.tube(n + "pillar%d" % k, top + up * 0.06 + dv * 0.105, top + up * 0.33 + dv * 0.105, 0.014, 0.014, gold, 5))
    parts += [ck.ball(n + "orb", 0.105, oc, glow),
              ck.tube(n + "roof", top + up * 0.33, top + up * 0.5, 0.15, 0.02, t, 12),
              ck.tube(n + "roof_rim", top + up * 0.32, top + up * 0.345, 0.156, 0.156, gold, 12),
              ck.ball(n + "finial", 0.036, top + up * 0.52, glow)]
    for k in range(10):                  # roda de raios em pé atrás do orbe
        a = math.tau * k / 10
        dv = side * math.cos(a) + up * math.sin(a)
        if dv.dot(up) < -0.5:
            continue
        parts.append(ck.blade(n + "ray%d" % k, oc + dv * 0.15, oc + dv * (0.36 if k % 2 == 0 else 0.27), 0.07, 0.02, gold if k % 2 else glow, fwd.cross(dv), 0.35))
    obj = ck._join(rs.outward(parts), "wpn_main_scepter_%s" % style)
    ck._smooth(obj.data)
    ck.skin_rigid(obj, base["rig"], "hand.R")
    return obj


ACT2_SETS = {"bis_s35": build_chaplain, "bis_i35": build_beacon, "bis_b35": build_vanguard}
ACT2_MACES = {"bis_s35": "lantern", "bis_b35": "hammer"}


def register(ck):
    import paladin_sets
    for style, fn in ACT2_SETS.items():                    # Ato II: um visual novo por build (35/40/45 + Ápice); escudos = os do 30
        ck.SET_STYLES[style] = (lambda st, f: (lambda base, mats: (f(ck, base, mats, st), paladin_sets.join_slots("arm_%s_" % st))))(style, fn)
    for style, kind in ACT2_MACES.items():
        ck.SET_WEAPONS[style + "_mace"] = (lambda st, kd: (lambda base, mats: build_mace2(ck, base, mats, st, kd)))(style, kind)
    ck.SET_WEAPONS["bis_i35_scepter"] = lambda base, mats: build_scepter2(ck, base, mats, "bis_i35")
    import shield_kit
    for style, cfg in BIS_SETS.items():
        ck.SET_STYLES[style] = (lambda st, cf: (lambda base, mats: (build(ck, base, mats, st, cf), paladin_sets.join_slots("arm_%s_" % st))))(style, cfg)
    for style, cfg in BIS_MACES.items():
        ck.SET_WEAPONS[style + "_mace"] = (lambda st, cf: (lambda base, mats: paladin_sets.build_mace(ck, base, mats, st, cf)))(style, cfg)
    for style, cfg in BIS_SCEPTERS.items():
        ck.SET_WEAPONS[style + "_scepter"] = (lambda st, cf: (lambda base, mats: build_scepter(ck, base, mats, st, cf)))(style, cfg)
    shield_kit.FAMILIES.update(BIS_SHIELDS)


# ---------------------------------------------------------------------------
# Ato III (nível 50, GDD ato3-lendarios-50): UM visual novo por build no tema de Lumeria. Malhas no kit extra
# kit_bishop_<sexo>_a3.glb (chibi_kit.A3_STYLES); motivos comuns em lumeria_kit.py.
#   bis_s50 Sacerdote = Lanterna da Última Vigília: véu de seda (tint2, lavanda) que cobre a cabeça e desce até o chão,
#           coroa de ouro com 5 lanternas acesas em volta, máscara de porcelana com lágrimas sob os dois olhos, asas curtas
#           de vidro facetado nas costas, túnica marfim com estola.
def build_vigil_lantern(ck, base, mats, style):
    """bis_s50 — Lanterna da Última Vigília (Sacerdote)."""
    import lumeria_kit as lk
    import berserker_sets as bs
    V = Vector
    rig, body, b, j = base["rig"], base["body"], base["b"], base["j"]
    M = lk.lum_mats(ck, mats)
    t, t2, gold, porc, glow, glass = M["t"], M["t2"], M["gold"], M["porc"], M["glow"], M["glass"]
    P = "arm_%s_" % style
    c, r = V(base["head_c"]), b["head"]
    d = b["depth"]
    front = -b["chest"] * d - 0.03
    back = b["chest"] * d + 0.03
    zc, zn, zw = ck.Z["chest"], ck.Z["neck"], ck.Z["waist"]
    # ---------------- túnica ----------------
    ck.armor_piece(body, rig, P + "body_robe", "torso", t, 0.014, 0.014, 0.03)
    ck.armor_piece(body, rig, P + "body_legs", "legs", porc, 0.008, 0.012)
    ck.skirt(P + "body_skirt", b, body, rig, t, 0.07, 1.75)
    bs._belt(ck, base, P + "body_belt", zw - 0.04, zw + 0.035, 1.21, gold)
    # ---------------- cabeça: véu, coroa de 5 lanternas, máscara com duas lágrimas ----------------
    head = [ck._shell(P + "head_veil", c, r * 1.1, 0.1, -1.0, -0.72, 0.035, t2),
            ck.tube(P + "head_crown", c + V((0, 0, r * 0.6)), c + V((0, 0, r * 0.74)), r * 1.065, r * 0.975, gold, 20)]
    head += lk.mask(ck, P + "head_mask", c + V((0, -r * 1.0, -r * 0.1)), r * 0.62, M, tears=(-1, 1), wide=1.25, tear_len=0.42)
    for k in range(5):                   # lanternas em volta da coroa, a da frente mais alta
        a = math.tau * k / 5 - math.pi / 2
        dv = V((math.cos(a), math.sin(a), 0))
        s_ = r * (0.27 if k == 0 else 0.22)
        foot = c + dv * r * 1.0 + V((0, 0, r * 0.68))
        lc = c + dv * r * 1.06 + V((0, 0, r * 0.7 + s_ * 1.7 + (r * 0.12 if k == 0 else 0.0)))
        head.append(ck.tube(P + "head_post%d" % k, foot, lc + V((0, 0, -s_ * 0.9)), s_ * 0.16, s_ * 0.3, gold, 5))
        head += lk.lantern(ck, P + "head_lantern%d" % k, lc, s_, M)
    for sx in (-1, 1):                   # véu caindo pelos lados do rosto até os ombros
        p0 = c + V((sx * r * 0.98, -r * 0.1, -r * 0.3))
        head.append(lk.silk(ck, P + "head_veil_side%d" % sx, p0, p0 + V((sx * r * 0.12, r * 0.1, -r * 0.95)), (0, 1, 0), r * 0.7, r * 0.5, t2, (sx * r * 0.06, 0, 0), 3))
    ck._rigid(bs._outward(head), rig, "head")
    # véu comprido pelas costas até a canela (pesos do corpo, como a saia) + barra de ouro; até o chão ele afundava
    # 0,3 m nos agachamentos (atk_finisher, buff_guard, cast_holy)
    train = [lk.silk(ck, P + "body_train", (0, back + 0.1, zn + 0.1), (0, back + 0.37, 0.22), (1, 0, 0), 0.4, 0.68, t2, (0, 0.05, 0), 7, 0.016),
             lk.silk(ck, P + "body_train_hem", (0, back + 0.355, 0.3), (0, back + 0.382, 0.205), (1, 0, 0), 0.7, 0.72, gold, (0, 0, 0), 1, 0.014)]
    lk.skinned(ck, base, bs._outward(train))
    # ---------------- corpo: gola, estola, asas de vidro ----------------
    chest = [ck.tube(P + "body_collar", V((0, 0, zn - 0.06)), V((0, 0, zn + 0.02)), b["chest"] * 0.74, b["chest"] * 0.5, gold, 16),
             ck.ball(P + "body_brooch", 0.04, (0, front - 0.012, zc + 0.1), porc, (1, 0.5, 1.15)),
             ck.ball(P + "body_brooch_tear", 0.018, (0, front - 0.034, zc + 0.09), glow, (0.8, 0.6, 1.7))]
    for sx in (-1, 1):                   # asas curtas: três lascas de vidro em leque, a de cima mais longa
        root = V((sx * 0.06, back + 0.03, zc + 0.08))
        for k in range(3):
            tip = root + V((sx * (0.46 - k * 0.08), 0.2 + k * 0.02, 0.34 - k * 0.26))
            chest.append(ck.blade(P + "body_wing%d_%d" % (sx, k), root + V((0, 0, -k * 0.05)), tip, 0.2 - k * 0.03, 0.03, glass, (0, 0, 1), 0.38))
        chest.append(ck.ball(P + "body_wing_root%d" % sx, 0.05, root + V((0, 0.01, -0.03)), gold, (1, 0.6, 1.4)))
    ck._rigid(bs._outward(chest), rig, "chest")
    wf = -b["waist"] * d * 1.22
    hips = [lk.silk(ck, P + "body_stole%d" % sx, (sx * 0.055, wf - 0.02, zw - 0.02), (sx * 0.075, wf - 0.085, zw - 0.36), (1, 0, 0), 0.085, 0.1, t2, (0, -0.012, 0), 3) for sx in (-1, 1)]
    hips += [ck.ball(P + "body_buckle", 0.04, (0, wf - 0.014, zw), porc, (1.1, 0.5, 1.1))]
    hips += lk.lantern(ck, P + "body_hip_lantern", (-b["waist"] * 1.32, -0.03, zw - 0.14), 0.05, M, hang=(-b["waist"] * 1.25, -0.03, zw - 0.02))
    ck._rigid(bs._outward(hips), rig, "hips")
    for s, sx in ((".R", -1), (".L", 1)):                 # ombros: pires de porcelana com laço de seda
        tag = s.replace(".", "_")
        sh = V(j["shoulder" + s])
        pa = lk.saucers(ck, P + "body_dish" + tag, sh + V((sx * 0.07, 0, 0.0)), b["arm"] * 2.5, 2, M, 0.045, 0.28, (sx * 0.45, 0, 1), [porc, porc])
        for i, sy in enumerate((-1, 1)):
            p0 = sh + V((sx * 0.14, sy * 0.05, 0.02))
            pa.append(lk.silk(ck, P + "body_bow%d%s" % (i, tag), p0, p0 + V((sx * 0.1, sy * 0.07, -0.2 - i * 0.04)), (1, sy * 0.6, 0), 0.06, 0.08, t2, (sx * 0.03, 0, 0), 2))
        ck._rigid(bs._outward(pa), rig, "upper_arm" + s)
    lk.limbs(ck, base, mats, P, M, "cloth", boots_m=porc)


#   bis_i50 Iluminado = Espelho do Meio-Dia: mitra ALTA e estreita de vidro facetado com arestas de ouro e um espelho
#           redondo na frente (lágrima pintada), ínfulas de seda (tint2, dourada) caindo pelas costas, espelho redondo com
#           raios de sol em cada ombro (virado para cima: lê da câmera), manto curto com fitas douradas, máscara pequena.
def build_noon_mirror(ck, base, mats, style):
    """bis_i50 — Espelho do Meio-Dia (Iluminado)."""
    import lumeria_kit as lk
    import berserker_sets as bs
    V = Vector
    rig, body, b, j = base["rig"], base["body"], base["b"], base["j"]
    M = lk.lum_mats(ck, mats)
    t, t2, gold, porc, glow, glass = M["t"], M["t2"], M["gold"], M["porc"], M["glow"], M["glass"]
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
    ck.skirt(P + "body_skirt", b, body, rig, t, 0.07, 1.7)
    bs._belt(ck, base, P + "body_belt", zw - 0.04, zw + 0.035, 1.21, gold)
    # ---------------- cabeça: touca, mitra de vidro, espelho na frente, ínfulas, máscara ----------------
    m0, m1, m2 = c + V((0, 0, r * 0.52)), c + V((0, 0, r * 1.6)), c + V((0, 0, r * 2.35))
    # mitra de PORCELANA facetada com ouro velho (era de vidro: no toon lia transparente/sem matéria): corpo de porcelana,
    # coifa de cima em seda (tint2), cinta e ponteira de ouro, arestas grossas e uma faixa de seda de pé na frente e atrás
    m3 = m1.lerp(m2, 0.62)
    mitre = [ck.tube(P + "head_mitre0", m0, m1, r * 0.95, r * 0.8, porc, 6), ck.tube(P + "head_mitre1", m1, m3, r * 0.8, r * 0.33, t2, 6),
             ck.tube(P + "head_mitre_tip", m3, m2, r * 0.345, r * 0.04, gold, 6),
             ck.tube(P + "head_mitre_girdle", m1 + V((0, 0, -r * 0.12)), m1 + V((0, 0, r * 0.1)), r * 0.88, r * 0.8, gold, 6),
             ck.tube(P + "head_mitre_base", m0 + V((0, 0, r * 0.1)), m0 + V((0, 0, r * 0.22)), r * 0.99, r * 0.96, gold, 6)]
    for sy in (-1, 1):                   # faixa vertical (frente e costas), por cima da faceta
        mitre.append(ck.box(P + "head_mitre_orphrey%d" % sy, (r * 0.34, r * 0.2, r * 0.9), m0.lerp(m1, 0.5) + V((0, sy * r * 0.86, r * 0.04)), t2, 0.004))
    edges = []
    for k in range(6):                   # arestas de ouro nas quinas das facetas
        a = math.tau * (k + 0.5) / 6 + math.pi / 2
        dv = V((math.cos(a), math.sin(a), 0))
        edges += [ck.tube(P + "head_edge%d_a" % k, m0 + dv * r * 0.955, m1 + dv * r * 0.805, r * 0.032, r * 0.032, gold, 4),
                  ck.tube(P + "head_edge%d_b" % k, m1 + dv * r * 0.81, m3 + dv * r * 0.33, r * 0.07, r * 0.05, gold, 4)]
    for o in mitre + edges:              # estreita de frente para trás
        for v in o.data.vertices:
            v.co.y = c.y + (v.co.y - c.y) * 0.5
    head = [ck._shell(P + "head_coif", c, r * 1.09, 0.15, -0.9, -0.7, 0.035, t),
            ck.tube(P + "head_band", c + V((0, 0, r * 0.46)), c + V((0, 0, r * 0.62)), r * 1.12, r * 1.03, gold, 20),
            ck.ball(P + "head_finial", r * 0.13, m2 + V((0, 0, r * 0.06)), glow)] + mitre + edges
    head += lk.mirror(ck, P + "head_mirror", c + V((0, -r * 0.5, r * 1.2)), r * 0.31, M, facing=(0, -1, 0.12), rays=8, tear=True)
    for sx in (-1, 1):                   # ínfulas: duas fitas largas da base da mitra até o meio das costas
        p0 = c + V((sx * r * 0.28, r * 1.05, r * 0.5))
        head += [lk.silk(ck, P + "head_lappet%d" % sx, p0, p0 + V((sx * r * 0.3, r * 0.5, -r * 1.7)), (1, 0, 0), r * 0.3, r * 0.4, t2, (0, r * 0.14, 0), 4),
                 ck.ball(P + "head_lappet_end%d" % sx, r * 0.09, p0 + V((sx * r * 0.3, r * 0.5, -r * 1.76)), gold)]
    head += lk.mask(ck, P + "head_mask", c + V((0, -r * 1.0, -r * 0.1)), r * 0.6, M, tears=(1,), wide=1.25, tear_len=0.42)
    ck._rigid(bs._outward(head), rig, "head")
    # ---------------- corpo: manto curto com fitas douradas, broche-espelho, estola ----------------
    cape = ck.tube(P + "body_mantle", V((0, 0, zn - 0.13)), V((0, 0, zn + 0.03)), b["shoulder"] * 1.34, b["chest"] * 0.55, t, 16)
    hem = ck.tube(P + "body_mantle_hem", V((0, 0, zn - 0.145)), V((0, 0, zn - 0.12)), b["shoulder"] * 1.38, b["shoulder"] * 1.36, gold, 16)
    for o in (cape, hem):
        for v in o.data.vertices:
            v.co.y *= 0.8
    chest = [cape, hem]
    chest += lk.mirror(ck, P + "body_brooch", (0, front - 0.05, zn - 0.09), 0.05, M)
    for k in range(6):                   # fitas douradas do manto: caem da barra, pelas costas e pelos lados
        a = math.radians(-100 + k * 40)
        p0 = V((math.sin(a) * b["shoulder"] * 1.25, math.cos(a) * b["shoulder"] * 1.0, zn - 0.12))
        p1 = p0 + V((math.sin(a) * 0.08, math.cos(a) * 0.1, -0.26 - (k % 2) * 0.07))
        chest.append(lk.silk(ck, P + "body_fringe%d" % k, p0, p1, (math.cos(a), -math.sin(a), 0), 0.085, 0.1, t2, (0, 0, 0), 3))
    ck._rigid(bs._outward(chest), rig, "chest")
    hips = [lk.silk(ck, P + "body_stole%d" % sx, (sx * 0.055, wf - 0.02, zw - 0.02), (sx * 0.08, wf - 0.09, zw - 0.4), (1, 0, 0), 0.09, 0.105, t2, (0, -0.012, 0), 3) for sx in (-1, 1)]
    hips += lk.mirror(ck, P + "body_buckle", (0, wf - 0.02, zw), 0.045, M)
    ck._rigid(bs._outward(hips), rig, "hips")
    for s, sx in ((".R", -1), (".L", 1)):                 # ombros: espelho redondo com raios, virado para cima e para fora
        tag = s.replace(".", "_")
        sh = V(j["shoulder" + s])
        pa = [ck.ball(P + "body_pad" + tag, b["arm"] * 2.3, sh + V((sx * 0.07, 0, 0.0)), porc, (1.15, 1.15, 0.6))]
        pa += lk.mirror(ck, P + "body_sun" + tag, sh + V((sx * 0.13, 0, 0.1)), 0.115, M, facing=(sx * 0.5, -0.12, 0.86), rays=10)
        ck._rigid(bs._outward(pa), rig, "upper_arm" + s)
    lk.limbs(ck, base, mats, P, M, "cloth", boots_m=porc)


#   bis_b50 Clérigo de Batalha = Hino da Taça Partida: ESTANDARTE de seda (tint2, coral) num mastro nas costas, acima da
#           cabeça, com a taça partida bordada e sinos na barra; capacete aberto com uma taça de ouro no alto; máscara de
#           porcelana PARTIDA e remendada com ouro (fios em zigue-zague); ombreiras de placa com lanterna de pé.
def build_broken_cup_hymn(ck, base, mats, style):
    """bis_b50 — Hino da Taça Partida (Clérigo de Batalha)."""
    import lumeria_kit as lk
    import berserker_sets as bs
    import paladin_sets as ps
    V = Vector
    rig, body, b, j = base["rig"], base["body"], base["b"], base["j"]
    M = lk.lum_mats(ck, mats)
    t, t2, gold, porc, glow, metal = M["t"], M["t2"], M["gold"], M["porc"], M["glow"], M["metal"]
    P = "arm_%s_" % style
    c, r = V(base["head_c"]), b["head"]
    d = b["depth"]
    front = -b["chest"] * d - 0.03
    back = b["chest"] * d + 0.03
    zc, zn, zw = ck.Z["chest"], ck.Z["neck"], ck.Z["waist"]
    wf = -b["waist"] * d * 1.22
    # ---------------- túnica curta de batalha ----------------
    ck.armor_piece(body, rig, P + "body_robe", "torso", t, 0.016, 0.014, 0.04)
    ck.armor_piece(body, rig, P + "body_legs", "legs", metal, 0.008, 0.012)
    ck.skirt(P + "body_skirt", b, body, rig, t, 0.2, 1.55)
    bs._belt(ck, base, P + "body_belt", zw - 0.04, zw + 0.035, 1.21, gold)
    # ---------------- cabeça: capacete aberto com camal de seda, taça no alto, máscara remendada com ouro ----------------
    head = [ck._shell(P + "head_helm", c, r * 1.12, 0.3, -0.35, -0.2, 0.04, t),
            ck._shell(P + "head_coif", c, r * 1.07, 0.1, -0.95, -0.7, 0.03, t2),
            ck.tube(P + "head_brow", c + V((0, 0, r * 0.36)), c + V((0, 0, r * 0.5)), r * 1.2, r * 1.15, gold, 20)]
    for k in range(4):                   # crista de ouro da testa à nuca
        a0, a1 = math.radians(-62 + k * 31), math.radians(-62 + (k + 1) * 31)
        head.append(ck.tube(P + "head_crest%d" % k, c + V((0, math.sin(a0) * r * 1.23, math.cos(a0) * r * 1.23)), c + V((0, math.sin(a1) * r * 1.23, math.cos(a1) * r * 1.23)), r * 0.07, r * 0.07, gold, 5))
    head += [ck.tube(P + "head_boss", c + V((0, 0, r * 1.1)), c + V((0, 0, r * 1.26)), r * 0.34, r * 0.2, gold, 10),
             ck.ball(P + "head_boss_tear", r * 0.13, c + V((0, 0, r * 1.3)), glow, (1, 1, 1.2))]
    s_ = r * 0.68
    mc = c + V((0, -r * 1.02, -r * 0.06))
    wx = 0.82 * 1.2 * s_
    head += lk.mask(ck, P + "head_mask", mc, s_, M, tears=(1,), wide=1.2, tear_len=0.4)

    def surf(x, z):
        return mc.y - 0.34 * s_ * math.sqrt(max(0.0, 1.0 - (x / wx) ** 2 - (z / s_) ** 2)) - 0.03 * s_

    cracks = [[(-0.5, 0.82), (-0.24, 0.5), (-0.36, 0.14), (-0.04, -0.14), (0.12, -0.5), (0.34, -0.82)],          # a quebra principal e dois ramos
              [(-0.36, 0.14), (-0.66, -0.02), (-0.8, -0.3)], [(-0.04, -0.14), (0.3, -0.2), (0.52, -0.44)]]
    for i, line in enumerate(cracks):
        for k in range(len(line) - 1):
            (x0, z0), (x1, z1) = line[k], line[k + 1]
            head.append(ck.tube(P + "head_crack%d_%d" % (i, k), (mc.x + x0 * wx, surf(x0 * wx, z0 * s_), mc.z + z0 * s_), (mc.x + x1 * wx, surf(x1 * wx, z1 * s_), mc.z + z1 * s_),
                                s_ * 0.05, s_ * 0.05, gold, 5))
    ck._rigid(bs._outward(head), rig, "head")
    # ---------------- corpo: gola, peitoral de porcelana rachado, estola; estandarte nas costas ----------------
    chest = [ck.tube(P + "body_collar", V((0, 0, zn - 0.06)), V((0, 0, zn + 0.02)), b["chest"] * 0.74, b["chest"] * 0.5, gold, 16),
             ck.ball(P + "body_breast", 1.0, (0, front + 0.02, zc + 0.01), porc, (b["chest"] * 0.74, 0.045, 0.14)),
             ck.ball(P + "body_breast_rim", 1.0, (0, front + 0.03, zc + 0.01), gold, (b["chest"] * 0.82, 0.035, 0.154)),
             ck.tube(P + "body_breast_crack0", (-b["chest"] * 0.3, front - 0.02, zc + 0.12), (0.01, front - 0.028, zc + 0.02), 0.011, 0.011, gold, 5),
             ck.tube(P + "body_breast_crack1", (0.01, front - 0.028, zc + 0.02), (b["chest"] * 0.22, front - 0.02, zc - 0.1), 0.011, 0.011, gold, 5),
             ck.ball(P + "body_breast_tear", 0.024, (b["chest"] * 0.28, front - 0.02, zc + 0.04), glow, (0.8, 0.6, 1.8))]
    py = max(back + 0.2, c.y + r * 1.42)                  # mastro: sai da cintura, passa por trás da cabeça e sobe reto
    z0, z1 = c.z + r * 0.75, c.z + r * 2.45
    chest += [ck.tube(P + "body_pole0", (0, back + 0.02, zw + 0.04), (0, py, z0), 0.022, 0.02, gold, 6),
              ck.tube(P + "body_pole1", (0, py, z0), (0, py, z1 + 0.06), 0.02, 0.018, gold, 6),
              ck.tube(P + "body_pole_bar", (-0.215, py, z1), (0.215, py, z1), 0.016, 0.016, gold, 6),
              ck.ball(P + "body_pole_socket", 0.045, (0, back + 0.03, zw + 0.06), gold, (1, 0.7, 1.2)),
              ck.ball(P + "body_pole_finial", 0.045, (0, py, z1 + 0.1), glow, (1, 1, 1.3)),
              ck.tube(P + "body_pole_cup", (0, py, z1 + 0.03), (0, py, z1 + 0.09), 0.02, 0.05, gold, 8)]
    by = py + 0.03
    length = z1 - (c.z + r * 0.75)
    chest += [ps._banner(ck, P + "body_banner", by, z1 - 0.01, 0.19, length, 0.02, t2),
              ps._banner(ck, P + "body_banner_hem", by, z1 - 0.01, 0.21, length + 0.04, 0.01, gold)]
    ez = z1 - length * 0.36
    for f in (-1, 1):                    # a taça partida bordada nas duas faces: cálice de ouro com a rachadura acesa
        y = by + f * 0.013
        chest += [ck.ball(P + "body_emblem_cup%d" % f, 1.0, (0, y, ez + 0.03), gold, (0.075, 0.008, 0.06)),
                  ck.box(P + "body_emblem_stem%d" % f, (0.022, 0.012, 0.07), (0, y, ez - 0.05), gold, 0.004),
                  ck.box(P + "body_emblem_foot%d" % f, (0.09, 0.012, 0.022), (0, y, ez - 0.09), gold, 0.004),
                  ck.tube(P + "body_emblem_crack%d" % f, (-0.035, y + f * 0.006, ez + 0.085), (0.02, y + f * 0.006, ez - 0.02), 0.009, 0.009, glow, 4)]
    for k, x in enumerate((-0.215, 0.215)):               # sinos nas pontas da travessa e na ponta do pano
        chest += lk.bell(ck, P + "body_bar_bell%d" % k, (x, py, z1 - 0.045), 0.034, M)
    chest += lk.bell(ck, P + "body_banner_bell", (0, by, z1 - length - 0.06), 0.04, M)
    for k, x in enumerate((-0.17, 0.17)):
        chest += lk.bell(ck, P + "body_banner_bell_side%d" % k, (x, by, z1 - length * 0.8 - 0.05), 0.03, M)
    ck._rigid(bs._outward(chest), rig, "chest")
    hips = [lk.silk(ck, P + "body_stole%d" % sx, (sx * 0.055, wf - 0.02, zw - 0.02), (sx * 0.075, wf - 0.07, zw - 0.3), (1, 0, 0), 0.085, 0.1, t2, (0, -0.012, 0), 3) for sx in (-1, 1)]
    hips += [ck.ball(P + "body_buckle", 0.04, (0, wf - 0.014, zw), porc, (1.1, 0.5, 1.1)),
             ck.tube(P + "body_buckle_crack", (-0.025, wf - 0.034, zw + 0.03), (0.02, wf - 0.034, zw - 0.03), 0.007, 0.007, gold, 4)]
    ck._rigid(bs._outward(hips), rig, "hips")
    for s, sx in ((".R", -1), (".L", 1)):                 # ombreiras de placa em duas lâminas com lanterna de pé
        tag = s.replace(".", "_")
        sh = V(j["shoulder" + s])
        pa = []
        for k in range(2):
            pc = sh + V((sx * (0.05 + k * 0.06), 0, 0.045 - k * 0.055))
            pa += [ck.ball(P + "body_pauldron%d%s" % (k, tag), b["arm"] * (2.7 - k * 0.25), pc, t if k == 0 else porc, (1.12, 1.15, 0.6)),
                   ck.ball(P + "body_pauldron_rim%d%s" % (k, tag), b["arm"] * (2.88 - k * 0.25), pc + V((0, 0, -0.02)), gold, (1.12, 1.15, 0.42))]
        pa += lk.lantern(ck, P + "body_lantern" + tag, sh + V((sx * 0.25, 0, 0.13)), 0.07, M)   # por fora da cabeça chibi: lê de frente e de cima
        ck._rigid(bs._outward(pa), rig, "upper_arm" + s)
        hp = V(j["hip" + s])
        tas = [ck.box(P + "body_fauld_%d%s" % (k, tag), (0.035, 0.14 - k * 0.014, 0.1), hp + V((sx * (b["thigh"] + 0.075 + k * 0.006), 0, 0.0 - k * 0.07)),
                      porc if k == 0 else t, 0.012) for k in range(2)]
        ck._rigid(tas, rig, "thigh" + s)
    lk.limbs(ck, base, mats, P, M, "plate")


ACT3_SETS = {"bis_s50": build_vigil_lantern, "bis_i50": build_noon_mirror, "bis_b50": build_broken_cup_hymn}


# Armas despertas do nível 50 (onda 4): malhas wpn_<main|off>_<tipo>_<estilo> só no kit extra _a3 (chibi_kit.A3_WEAPONS);
# as funções ficam em lumeria_arms_a.py (uma por estilo, faz todas as armas da build). Chave = <estilo>_arms.
def _arms(style):
    def fn(ck, base, mats):
        import lumeria_arms_a
        return getattr(lumeria_arms_a, style)(ck, base, mats, style)
    return fn


ACT3_WEAPONS = {st + "_arms": _arms(st) for st in ("bis_s50", "bis_i50", "bis_b50")}
