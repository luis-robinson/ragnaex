"""Conjuntos lendários do Paladino (todos menos o pal1, que tem referência própria), montados por um construtor paramétrico.

Linguagem visual (original, só o "clima" de MMOs clássicos de cavaleiro): placa medieval pesada no Guardião (tanque),
cada vez mais fechada e maciça; placa clara com tabardo, asas e brilho sagrado no Cruzado (dano sagrado), cada vez
mais leve e radiante. Cada conjunto é uma linha em PAL_SETS; nada é escrito peça a peça.

Peças: arm_<estilo>_<head|body|gloves|boots>_<parte> (o jogo liga as do equipamento). Materiais: tint = cor do item,
tint2 = destaque derivado (KitModel.accent), trim = ouro, white, dark.
"""
import math
from mathutils import Vector

# elmo: open (rosto à mostra, nasal) | great (casco, guarda do queixo) | sallet (casco com aba de nuca)
#       | closed (elmo fechado de paladino: rosto coberto, só a fenda dos olhos acende)
# viseira: jaw (placa até o queixo) | bevor (queixo em ponta) | none ; no closed: slit | tslit | grille | beak
# enfeites do elmo: plume, crest, wings, horns, halo, rays, crown
# emblema: cross, sun, gem, shield, wing ; tabardo: comprimento (0 = sem) e material ; ombreira: camadas + spike/wing/ridge
PAL_SETS = {
    # ---- Guardião (tanque): mais fechado e maciço a cada tier ----
    "pal_g10": {"helm": "closed", "visor": "tslit", "orn": ["crest"], "emblem": "cross", "layers": 2, "pauldron": [],
                "tabard": 0.14, "tabard_mat": "white", "faulds": 2, "trim": "white", "gauntlet": 1.0, "knee": "plain"},
    "pal_g15": {"helm": "closed", "visor": "slit", "tail": True, "orn": ["plume"], "emblem": "shield", "layers": 3, "pauldron": [],
                "tabard": 0.17, "tabard_mat": "tint2", "faulds": 2, "trim": "gold", "gauntlet": 1.1, "knee": "plain"},
    "pal_g20": {"helm": "closed", "visor": "grille", "orn": ["rays"], "emblem": "sun", "layers": 2, "pauldron": ["ridge"],
                "tabard": 0.18, "tabard_mat": "white", "faulds": 2, "trim": "white", "gauntlet": 1.1, "knee": "spike"},
    "pal_g25": {"helm": "closed", "visor": "beak", "orn": ["horns"], "emblem": "gem", "layers": 3, "pauldron": ["spike"],
                "tabard": 0.0, "tabard_mat": "tint2", "faulds": 3, "trim": "tint2", "gauntlet": 1.25, "knee": "spike"},
    "pal_g30": {"helm": "closed", "visor": "tslit", "orn": ["crown", "halo"], "emblem": "sun", "layers": 3, "pauldron": ["wing"],
                "tabard": 0.22, "tabard_mat": "white", "faulds": 3, "trim": "gold", "gauntlet": 1.25, "knee": "wing"},
    # ---- Cruzado (dano sagrado): mais leve e radiante a cada tier ----
    "pal_c5": {"helm": "open", "visor": "none", "orn": ["plume"], "emblem": "cross", "layers": 1, "pauldron": [],
               "tabard": 0.22, "tabard_mat": "tint2", "faulds": 1, "trim": "gold", "gauntlet": 0.9, "knee": "plain"},
    "pal_c10": {"helm": "open", "visor": "none", "orn": ["wings"], "emblem": "cross", "layers": 2, "pauldron": [],
                "tabard": 0.22, "tabard_mat": "tint2", "faulds": 1, "trim": "gold", "gauntlet": 0.95, "knee": "plain"},
    "pal_c15": {"helm": "sallet", "visor": "none", "orn": ["crest", "plume"], "emblem": "wing", "layers": 2, "pauldron": ["ridge"],
                "tabard": 0.22, "tabard_mat": "white", "faulds": 2, "trim": "gold", "gauntlet": 1.0, "knee": "wing"},
    "pal_c20": {"helm": "open", "visor": "none", "orn": ["rays", "crest"], "emblem": "sun", "layers": 2, "pauldron": ["wing"],
                "tabard": 0.24, "tabard_mat": "white", "faulds": 2, "trim": "white", "gauntlet": 1.0, "knee": "plain"},
    "pal_c25": {"helm": "closed", "visor": "slit", "orn": ["crest", "crown"], "emblem": "cross", "layers": 3, "pauldron": ["spike"],
                "tabard": 0.24, "tabard_mat": "dark", "faulds": 2, "trim": "gold", "gauntlet": 1.1, "knee": "spike"},
    "pal_c30": {"helm": "open", "visor": "none", "orn": ["wings", "halo"], "emblem": "sun", "layers": 3, "pauldron": ["wing"],
                "tabard": 0.26, "tabard_mat": "white", "faulds": 2, "trim": "gold", "gauntlet": 1.05, "knee": "wing"},
}


def build(ck, base, mats, style, cfg):
    """Monta um conjunto: elmo, corpo (placa, emblema, gorjal, cinto, faldas, tabardo, ombreiras), manoplas e botas."""
    V = Vector
    rig, body, b, j = base["rig"], base["body"], base["b"], base["j"]
    t, t2, gold, wh, dark = mats["tint"], mats["tint2"], mats["trim"], mats["white"], mats["dark"]
    pick = {"tint": t, "tint2": t2, "gold": gold, "white": wh, "dark": dark}
    tr = pick[cfg["trim"]]
    P = "arm_%s_" % style
    c = V(base["head_c"])
    r = b["head"]
    # ---------------- elmo ----------------
    helm = cfg["helm"]
    if helm == "open":
        head = [ck._shell(P + "head_helm", c, r * 1.15, 0.2, -0.62, -0.18, 0.035, t),
                ck.box(P + "head_nasal", (0.05, 0.05, r * 0.5), c + V((0, -r * 1.13, -r * 0.02)), tr, 0.012)]
    elif helm == "closed":
        head = _closed_helm(ck, P, c, r, cfg["visor"], t, tr, dark, mats)
    else:
        head = [ck._shell(P + "head_helm", c, r * 1.16, 0.12, -0.66 if helm == "sallet" else -0.6, -0.32, 0.035, t)]
    head.append(ck.tube(P + "head_brow", c + V((0, 0, r * 0.16)), c + V((0, 0, r * 0.3)), r * 1.25, r * 1.22, tr, 24))
    for k in range(5):         # rebites só na frente da faixa da testa
        a = math.pi * (0.3 + 0.4 * k / 4.0) + math.pi
        head.append(ck.ball(P + "head_rivet_%d" % k, 0.03, c + V((math.cos(a) * r * 1.27, math.sin(a) * r * 1.27, r * 0.23)), gold))
    if helm == "sallet" or cfg.get("tail"):       # aba de nuca, larga e inclinada para trás
        head.append(ck.blade(P + "head_tail", c + V((0, r * 0.8, -r * 0.1)), c + V((0, r * 1.45, -r * 0.65)), r * 1.5, 0.06, t, (1, 0, 0), 0.3))
    if helm == "closed":
        pass
    elif cfg["visor"] == "jaw":
        head.append(ck.box(P + "head_visor", (r * 1.2, 0.09, r * 0.5), c + V((0, -r * 1.02, -r * 0.5)), t, 0.04))
        head.append(ck.box(P + "head_visor_rim", (r * 1.24, 0.06, 0.04), c + V((0, -r * 1.07, -r * 0.27)), tr, 0.012))
    elif cfg["visor"] == "bevor":
        for sx in (-1, 1):
            head.append(ck.blade(P + "head_bevor_%d" % sx, c + V((sx * r * 0.62, -r * 0.92, -r * 0.3)), c + V((0, -r * 1.12, -r * 0.82)),
                                 r * 0.5, 0.06, t, (0, 0, 1)))
    orn = cfg["orn"]
    if "crest" in orn:
        head.append(ck.blade(P + "head_crest", c + V((0, -r * 0.9, r * 0.45)), c + V((0, r * 0.55, r * 1.55)), r * 0.38, 0.08, tr, (0, 1, 0)))
    if "plume" in orn:
        head.append(ck.strand(P + "head_plume", c + V((0, r * 0.05, r * 1.12)), r * 1.1, r * 0.42, r * 0.3, t2, taper=0.75, lean=(0.0, 1.0)))
    if "wings" in orn:
        for sx in (-1, 1):
            for k, (up, out, w) in enumerate(((1.45, 1.55, 0.62), (1.05, 1.35, 0.45))):
                head.append(ck.blade(P + "head_wing_%d_%d" % (sx, k), c + V((sx * r * 0.9, r * 0.15, r * 0.45 - k * 0.04)),
                                     c + V((sx * r * out, r * (0.55 + k * 0.15), r * up)), r * w, 0.05, wh, (0, 1, 0.4)))
    if "horns" in orn:
        for sx in (-1, 1):
            p0, p1, p2 = c + V((sx * r * 0.92, -r * 0.05, r * 0.5)), c + V((sx * r * 1.42, -r * 0.18, r * 0.72)), c + V((sx * r * 1.55, -r * 0.42, r * 1.2))
            head += [ck.tube(P + "head_horn_a_%d" % sx, p0, p1, 0.085, 0.065, tr, 10), ck.tube(P + "head_horn_b_%d" % sx, p1, p2, 0.065, 0.012, tr, 10)]
    if "rays" in orn:          # leque de raios atrás da cabeça: de cima é o que aparece
        for k in range(7):
            a = math.radians(-66 + k * 22)
            tip = c + V((math.sin(a) * r * 1.75, r * 0.85, r * 0.45 + math.cos(a) * r * 1.75))
            head.append(ck.blade(P + "head_ray_%d" % k, c + V((0, r * 0.8, r * 0.45)), tip, r * 0.3, 0.04, gold, (math.cos(a), 0, -math.sin(a))))
    if "crown" in orn:
        for k in range(8):
            a = math.tau * k / 8
            d = V((math.cos(a), math.sin(a), 0))
            head.append(ck.blade(P + "head_crown_%d" % k, c + d * r * 1.02 + V((0, 0, r * 0.6)), c + d * r * 1.08 + V((0, 0, r * 1.02)),
                                 r * 0.26, 0.04, gold, (-d.y, d.x, 0)))
    if "halo" in orn:          # anel sobre a cabeça, inclinado para trás
        n = 18
        ring = [c + V((math.cos(math.tau * i / n) * r * 0.78, r * 0.25 + math.sin(math.tau * i / n) * r * 0.5, r * 1.62)) for i in range(n)]
        for i in range(n):
            head.append(ck.tube(P + "head_halo_%d" % i, ring[i], ring[(i + 1) % n], 0.022, 0.022, gold, 6))
    ck._rigid(head, rig, "head")
    # ---------------- corpo ----------------
    ck.armor_piece(body, rig, P + "body_plate", "torso", t, 0.016, 0.016, 0.04)
    ck.armor_piece(body, rig, P + "body_legs", "legs", mats["metal"], 0.008, 0.012)      # cota de malha por baixo
    d = b["depth"]
    front = -b["chest"] * d - 0.035
    em = cfg["emblem"]
    ez = Z_CHEST(ck) + 0.03
    chest = [ck.tube(P + "body_gorget", V((0, 0, ck.Z["neck"] - 0.05)), V((0, 0, ck.Z["neck"] + 0.01)), b["chest"] * 0.62, b["chest"] * 0.5, tr, 16)]
    if em == "cross":
        chest += [ck.box(P + "body_cross_v", (0.045, 0.03, 0.17), (0, front, ez), tr, 0.01), ck.box(P + "body_cross_h", (0.13, 0.03, 0.045), (0, front, ez + 0.035), tr, 0.01)]
    elif em == "sun":
        chest.append(ck.ball(P + "body_sun", 0.045, (0, front, ez), gold, (1, 0.5, 1)))
        for k in range(8):
            a = math.tau * k / 8
            chest.append(ck.blade(P + "body_sun_ray_%d" % k, (math.cos(a) * 0.04, front, ez + math.sin(a) * 0.04),
                                  (math.cos(a) * 0.1, front - 0.005, ez + math.sin(a) * 0.1), 0.035, 0.02, gold, (-math.sin(a), 0, math.cos(a))))
    elif em == "gem":
        chest += [ck.ball(P + "body_gem", 0.04, (0, front - 0.01, ez), t2, (1, 0.6, 1.2)),
                  ck.tube(P + "body_gem_rim", (0, front + 0.005, ez), (0, front - 0.012, ez), 0.06, 0.055, tr, 14)]
    elif em == "shield":
        chest += [ck.blade(P + "body_crest", (0, front, ez + 0.08), (0, front - 0.005, ez - 0.09), 0.15, 0.03, t2, (1, 0, 0), 0.35),
                  ck.box(P + "body_crest_bar", (0.03, 0.035, 0.1), (0, front - 0.02, ez), tr, 0.008)]
    elif em == "wing":
        for sx in (-1, 1):
            chest.append(ck.blade(P + "body_wing_%d" % sx, (sx * 0.02, front, ez - 0.02), (sx * 0.14, front - 0.005, ez + 0.07), 0.07, 0.025, wh, (0, 0, 1)))
        chest.append(ck.ball(P + "body_wing_gem", 0.025, (0, front - 0.01, ez), t2))
    # crista no meio do peito e placa da barriga (lâminas), emblema repetido nas costas (a câmera alta vê as costas)
    chest.append(ck.blade(P + "body_ridge", (0, front + 0.006, ez + 0.13), (0, front + 0.004, ez - 0.13), 0.035, 0.03, t, (1, 0, 0), 0.5))
    for k in range(2):
        zz = ck.Z["waist"] + 0.07 - k * 0.055
        chest.append(ck.box(P + "body_plackart_%d" % k, (0.2 - k * 0.03, 0.03, 0.045), (0, -b["waist"] * d * 1.12 - 0.02, zz), t if k == 0 else tr, 0.012))
    back = b["chest"] * d + 0.035
    if em in ("cross", "shield", "wing"):
        chest += [ck.box(P + "body_back_cross_v", (0.05, 0.03, 0.2), (0, back, ez), tr, 0.01), ck.box(P + "body_back_cross_h", (0.15, 0.03, 0.05), (0, back, ez + 0.04), tr, 0.01)]
    else:
        chest.append(ck.ball(P + "body_back_disc", 0.07, (0, back, ez), tr, (1, 0.35, 1)))
        for k in range(8):
            a = math.tau * k / 8
            chest.append(ck.blade(P + "body_back_ray_%d" % k, (math.cos(a) * 0.06, back, ez + math.sin(a) * 0.06),
                                  (math.cos(a) * 0.13, back + 0.004, ez + math.sin(a) * 0.13), 0.04, 0.02, gold, (-math.sin(a), 0, math.cos(a))))
    ck._rigid(chest, rig, "chest")
    belt = ck.tube(P + "body_belt", (0, 0, ck.Z["waist"] - 0.035), (0, 0, ck.Z["waist"] + 0.03), b["waist"] * 1.16, b["waist"] * 1.16, tr, 16)
    for v in belt.data.vertices:
        v.co.y *= d * 1.05
    ck._smooth(belt.data)
    ck.transfer_weights(belt, body, rig)
    hips = [ck.box(P + "body_buckle", (0.07, 0.03, 0.06), (0, -b["waist"] * d * 1.2 - 0.01, ck.Z["waist"]), gold, 0.01)]
    if cfg["tabard"] > 0.0:    # tabardo: pano na frente e atrás, do cinto para baixo
        L = cfg["tabard"]
        tm = pick[cfg["tabard_mat"]]
        for side, y in (("f", -b["waist"] * d * 1.2 - 0.02), ("b", b["waist"] * d * 1.2 + 0.02)):
            top = ck.Z["waist"] - 0.03
            hips += [_banner(ck, P + "body_tabard_" + side, y, top, 0.085, L, 0.016, tm),
                     _banner(ck, P + "body_tabard_hem_" + side, y + (-0.004 if side == "f" else 0.004), top, 0.095, L + 0.025, 0.01, tr)]
        hips += [ck.box(P + "body_tabard_mark_v", (0.025, 0.012, 0.08), (0, -b["waist"] * d * 1.2 - 0.032, ck.Z["waist"] - 0.1), tr, 0.004),
                 ck.box(P + "body_tabard_mark_h", (0.065, 0.012, 0.022), (0, -b["waist"] * d * 1.2 - 0.032, ck.Z["waist"] - 0.085), tr, 0.004)]
    ck._rigid(hips, rig, "hips")
    for s, sx in ((".R", -1), (".L", 1)):
        tag = s.replace(".", "_")
        sh = V(j["shoulder" + s])
        pa = []
        n = cfg["layers"]
        for k in range(n):     # lâminas empilhadas, de cima (maior) para baixo
            sz = 1.0 - k * 0.12
            ctr = sh + V((sx * (0.06 + k * 0.03), 0, 0.06 - k * 0.075))
            pa.append(ck.ball(P + "body_pauldron_%d%s" % (k, tag), b["arm"] * 2.7 * sz, ctr, t if k % 2 == 0 or n == 1 else tr, (1.15, 1.1, 0.68)))
        pa.append(ck.ball(P + "body_pauldron_rim" + tag, b["arm"] * 2.78, sh + V((sx * 0.055, 0, 0.03)), tr, (1.17, 1.12, 0.18)))
        rr = b["arm"] * 2.78
        for k in range(7):     # rebites em volta da borda, do lado de fora
            a = math.pi * (-0.45 + 0.9 * k / 6.0)
            pa.append(ck.ball(P + "body_pauldron_rivet_%d%s" % (k, tag), 0.018, sh + V((sx * (0.055 + math.cos(a) * rr * 1.1), math.sin(a) * rr * 1.06, 0.045)), gold))
        top = sh + V((sx * 0.07, 0, 0.13))
        if "spike" in cfg["pauldron"]:
            pa.append(ck.blade(P + "body_pauldron_spike" + tag, top, top + V((sx * 0.08, 0, 0.17)), 0.08, 0.05, tr, (0, 1, 0)))
        if "ridge" in cfg["pauldron"]:
            pa.append(ck.blade(P + "body_pauldron_ridge" + tag, top + V((0, -0.1, -0.02)), top + V((sx * 0.02, 0.12, 0.03)), 0.06, 0.04, tr, (0, 0, 1)))
        if "wing" in cfg["pauldron"]:
            for k in range(3):
                pa.append(ck.blade(P + "body_pauldron_wing_%d%s" % (k, tag), top + V((0, 0.02, -0.02)),
                                   top + V((sx * (0.12 + k * 0.05), 0.1 + k * 0.03, 0.2 - k * 0.07)), 0.08, 0.03, wh, (0, 1, 0)))
        ck._rigid(pa, rig, "upper_arm" + s)
        hp = V(j["hip" + s])
        tas = []
        for k in range(cfg["faulds"]):
            tas.append(ck.box(P + "body_fauld_%d%s" % (k, tag), (0.04, 0.15 - k * 0.012, 0.11), hp + V((sx * (b["thigh"] + 0.035 + k * 0.006), 0, -0.02 - k * 0.075)),
                              t if k % 2 == 0 else tr, 0.012))
        ck._rigid(tas, rig, "thigh" + s)
    # ---------------- manoplas ----------------
    g = cfg["gauntlet"]
    for s, sx in ((".R", -1), (".L", 1)):
        tag = s.replace(".", "_")
        el, wr = V(j["elbow" + s]), V(j["wrist" + s])
        parts = [ck.tube(P + "gloves_cuff" + tag, el.lerp(wr, 0.25), wr + V((0, 0, 0.01)), 0.075 * g, 0.105 * g, t, 12),
                 ck.tube(P + "gloves_rim" + tag, wr + V((0, 0, 0.005)), wr + V((0, 0, 0.03)), 0.112 * g, 0.112 * g, tr, 12)]
        if g >= 1.2:
            parts.append(ck.blade(P + "gloves_fin" + tag, el.lerp(wr, 0.3) + V((sx * 0.07, 0, 0)), el.lerp(wr, 0.85) + V((sx * 0.13, 0, 0.02)), 0.06, 0.03, tr, (0, 1, 0)))
        ck._rigid(parts, rig, "forearm" + s)
        hc = ck.hand_center(base, s)
        kn = [ck.box(P + "gloves_knuckle_%d%s" % (k, tag), (0.075, 0.03, 0.022), V(hc) + V((sx * 0.01, -0.06, 0.035 - k * 0.032)), tr, 0.008) for k in range(2)]
        ck._rigid(kn, rig, "hand" + s)
        fist = ck.ball(P + "gloves_fist" + tag, b["hand"] * 1.4 * min(g, 1.15), ck.hand_center(base, s), t, (1, 1, 1.1))
        ck._rigid([fist], rig, "hand" + s)
    # ---------------- botas e joelheiras ----------------
    ck.armor_piece(body, rig, P + "boots_shell", "boots", t, 0.026, 0.016)
    for s, sx in ((".R", -1), (".L", 1)):
        tag = s.replace(".", "_")
        kn, an = V(j["knee" + s]), V(j["ankle" + s])
        k = [ck.ball(P + "boots_knee" + tag, 0.075, kn + V((0, -0.075, 0.01)), t, (1.05, 0.7, 1.0)),
             ck.tube(P + "boots_cuff" + tag, an + V((0, 0, 0.06)), an + V((0, 0, 0.09)), 0.09, 0.09, tr, 12)]
        if cfg["knee"] == "spike":
            k.append(ck.blade(P + "boots_knee_spike" + tag, kn + V((0, -0.11, 0.0)), kn + V((0, -0.17, 0.09)), 0.06, 0.04, tr, (1, 0, 0)))
        elif cfg["knee"] == "wing":
            k.append(ck.blade(P + "boots_wing" + tag, an + V((sx * 0.07, 0.01, 0.08)), an + V((sx * 0.15, 0.06, 0.2)), 0.07, 0.025, wh, (0, 1, 0)))
        ck._rigid(k, rig, "shin" + s)
        toe = [ck.ball(P + "boots_toe" + tag, 0.06, an + V((0, -0.11, -0.04)), tr, (1.0, 1.25, 0.6))]
        for q in range(2):
            toe.append(ck.box(P + "boots_lame_%d%s" % (q, tag), (0.12, 0.05, 0.022), an + V((0, -0.06 - q * 0.03, 0.0 - q * 0.02)), t, 0.008))
        ck._rigid(toe, rig, "foot" + s)


def _closed_helm(ck, P, c, r, visor, t, tr, dark, mats):
    """Elmo fechado: casco inteiro cobre o rosto; a viseira tem a forma da fenda e os olhos acendem lá dentro."""
    V = Vector
    glow = ck.mat("m_set_eyeglow", (0.75, 0.95, 1.0), 0.3, 3.0)
    head = [ck._shell(P + "head_helm", c, r * 1.16, -0.75, -0.62, -0.5, 0.035, t),
            ck.ball(P + "head_face", r * 0.82, c + V((0, -r * 0.84, -r * 0.1)), t, (1.1, 0.46, 1.0))]   # placa do rosto, saliente
    fy = -r * 1.22                 # frente da viseira (em cima da placa)
    ez = r * 0.02                  # altura da fenda dos olhos
    if visor in ("slit", "tslit", "beak"):
        head.append(ck.box(P + "head_slit", (r * 1.25, 0.08, r * 0.13), c + V((0, fy, ez)), dark, 0.02))
        for sx in (-1, 1):
            head.append(ck.ball(P + "head_eye_%d" % sx, r * 0.07, c + V((sx * r * 0.3, fy - 0.02, ez)), glow, (1.4, 0.6, 0.7)))
    if visor == "tslit":           # respiro vertical abaixo da fenda + filete
        head += [ck.box(P + "head_breath", (r * 0.12, 0.08, r * 0.5), c + V((0, fy, ez - r * 0.33)), dark, 0.015),
                 ck.box(P + "head_slit_rim", (r * 1.32, 0.06, 0.03), c + V((0, fy - 0.02, ez + r * 0.1)), tr, 0.008)]
    if visor == "grille":          # grade de barras verticais
        head.append(ck.box(P + "head_grille_bg", (r * 0.95, 0.07, r * 0.62), c + V((0, fy + 0.01, ez - r * 0.18)), dark, 0.02))
        for k in range(5):
            head.append(ck.box(P + "head_bar_%d" % k, (0.03, 0.06, r * 0.66), c + V(((k - 2) * r * 0.19, fy - 0.02, ez - r * 0.18)), t, 0.006))
        for sx in (-1, 1):
            head.append(ck.ball(P + "head_eye_%d" % sx, r * 0.07, c + V((sx * r * 0.3, fy - 0.005, ez)), glow, (1.4, 0.6, 0.7)))
    if visor == "beak":            # focinho pontudo de bascinete, com furos de respiro
        head.append(ck.blade(P + "head_beak", c + V((0, fy + 0.02, ez - r * 0.12)), c + V((0, fy - r * 0.55, ez - r * 0.4)), r * 0.8, r * 0.5, t, (1, 0, 0), 0.25))
        for k in range(3):
            head.append(ck.ball(P + "head_hole_%d" % k, 0.018, c + V(((k - 1) * r * 0.16, fy - r * 0.32, ez - r * 0.3)), dark))
    head.append(ck.blade(P + "head_face_ridge", c + V((0, fy - 0.01, ez + r * 0.6)), c + V((0, fy - 0.02, ez - r * 0.72)), 0.05, 0.035, tr, (1, 0, 0), 0.5))
    return head


def _banner(ck, name, y, top, half_w, length, thick, material):
    """Pano do tabardo: largo no cinto, ponta embaixo (pentágono com espessura), no plano XZ em y."""
    import bmesh
    pts = [(-half_w, top), (half_w, top), (half_w * 0.85, top - length * 0.8), (0.0, top - length), (-half_w * 0.85, top - length * 0.8)]
    bm = bmesh.new()
    f = [bm.verts.new((x, y - thick * 0.5, z)) for x, z in pts]
    bk = [bm.verts.new((x, y + thick * 0.5, z)) for x, z in pts]
    bm.faces.new(list(reversed(f)))
    bm.faces.new(bk)
    for i in range(len(pts)):
        k = (i + 1) % len(pts)
        bm.faces.new((f[i], f[k], bk[k], bk[i]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    return ck.mesh_from(name, bm, material)


def Z_CHEST(ck):
    return ck.Z["chest"]


def join_slots(prefix):
    """Junta as peças de cada slot (arm_<estilo>_<slot>_*) numa malha só, mantendo os pesos por bone (bpy join junta grupos
    por nome). Sem isso cada boneco no jogo instancia centenas de malhas escondidas e a GPU estoura o limite de recursos."""
    import bpy
    for slot in ("head", "body", "gloves", "boots"):
        objs = [o for o in bpy.data.objects if o.type == "MESH" and o.name.startswith("%s%s_" % (prefix, slot))]
        if len(objs) < 2:
            continue
        with bpy.context.temp_override(active_object=objs[0], object=objs[0], selected_objects=objs, selected_editable_objects=objs):
            bpy.ops.object.join()
        objs[0].name = "%s%s_all" % (prefix, slot)



# ---------------------------------------------------------------------------
# Armas dos conjuntos: uma espada por conjunto (Guardião = 1 mão, Cruzado = montante), com o motivo do conjunto.
# lâmina: w0/w1 = meia-largura na base/perto da ponta, tip = comprimento da ponta, wave = lâmina ondulada (flamberge),
#   core = filete brilhante no meio ; guarda: cross | down | sun | horn | wing ; pomo: ball | gem | ring | crown
# halo = anel na guarda ; blade_mat: metal | dark ; grip_mat: leather | tint2
PAL_WEAPONS = {
    "pal1": {"type": "sword", "w0": 0.04, "w1": 0.034, "tip": 0.13, "guard": "down", "pommel": "gem", "gem": True},
    "pal_g10": {"type": "sword", "w0": 0.036, "w1": 0.032, "tip": 0.1, "guard": "cross", "pommel": "ring", "fuller": True},
    "pal_g15": {"type": "sword", "w0": 0.05, "w1": 0.044, "tip": 0.12, "guard": "down", "pommel": "gem", "gem": True},
    "pal_g20": {"type": "sword", "w0": 0.04, "w1": 0.032, "tip": 0.14, "guard": "sun", "pommel": "ball", "fuller": True},
    "pal_g25": {"type": "sword", "w0": 0.045, "w1": 0.058, "tip": 0.08, "guard": "horn", "pommel": "crown", "gem": True, "blade_mat": "dark"},
    "pal_g30": {"type": "sword", "w0": 0.042, "w1": 0.036, "tip": 0.14, "guard": "wing", "pommel": "gem", "gem": True, "halo": True, "core": True},
    "pal_c5": {"type": "sword2h", "w0": 0.05, "w1": 0.042, "tip": 0.14, "guard": "cross", "pommel": "ball", "grip_mat": "tint2"},
    "pal_c10": {"type": "sword2h", "w0": 0.052, "w1": 0.044, "tip": 0.16, "guard": "wing", "pommel": "ring", "fuller": True},
    "pal_c15": {"type": "sword2h", "w0": 0.048, "w1": 0.062, "tip": 0.12, "guard": "wing", "pommel": "gem", "gem": True, "grip_mat": "tint2"},
    "pal_c20": {"type": "sword2h", "w0": 0.056, "w1": 0.046, "tip": 0.18, "guard": "sun", "pommel": "ball", "core": True},
    "pal_c25": {"type": "sword2h", "w0": 0.05, "w1": 0.046, "tip": 0.14, "wave": 0.016, "guard": "horn", "pommel": "crown", "gem": True, "grip_mat": "tint2"},
    "pal_c30": {"type": "sword2h", "w0": 0.058, "w1": 0.05, "tip": 0.2, "guard": "wing", "pommel": "gem", "gem": True, "halo": True, "core": True},
}
LEN = {"sword": 0.62, "sword2h": 0.95}           # lâmina sem a ponta
GRIP = {"sword": 0.09, "sword2h": 0.2}           # meio cabo (a mão fica no meio)


def _blade(ck, name, g, fwd, side, start, length, w0, w1, tip, thick, wave, material, n=14):
    """Lâmina de espada: seção em losango (fio fino, nervura grossa no meio), afina até a ponta; `wave` ondula o fio."""
    import bmesh
    ridge = fwd.cross(side).normalized()
    bm = bmesh.new()
    rings = []
    for i in range(n + 1):
        t = i / n
        c = g + fwd * (start + length * t)
        w = w0 + (w1 - w0) * t
        if wave > 0.0:
            w += wave * math.sin(t * math.pi * 6.0)
        rings.append([bm.verts.new(c - side * w), bm.verts.new(c + ridge * thick), bm.verts.new(c + side * w), bm.verts.new(c - ridge * thick)])
    tipv = bm.verts.new(g + fwd * (start + length + tip))
    for i in range(n):
        a, b = rings[i], rings[i + 1]
        for k in range(4):
            bm.faces.new((a[k], a[(k + 1) % 4], b[(k + 1) % 4], b[k]))
    for k in range(4):
        bm.faces.new((rings[-1][k], rings[-1][(k + 1) % 4], tipv))
    bm.faces.new(list(reversed(rings[0])))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    return ck.mesh_from(name, bm, material)


def build_weapon(ck, base, mats, style, cfg):
    """Espada do conjunto na mão direita (mesmo eixo das armas do kit), 1 malha: wpn_main_<tipo>_<estilo>."""
    V = Vector
    g = V(ck.hand_center(base, ".R"))
    fwd = V((0, -0.55, 0.83)).normalized()
    side = V((1, 0, 0))
    ridge = fwd.cross(side).normalized()
    t, t2, gold, metal = mats["tint"], mats["tint2"], mats["trim"], mats["metal"]
    wt = cfg["type"]
    L, G = LEN[wt], GRIP[wt]
    gs = 1.6 if wt == "sword" else 1.9            # escala da guarda: no chibi a guarda precisa aparecer de longe
    bw = 1.3                                      # lâminas mais largas que o real
    bm = mats["dark"] if cfg.get("blade_mat") == "dark" else metal
    start = G + 0.03
    n = "w_%s_" % style
    parts = [_blade(ck, n + "blade", g, fwd, side, start, L, cfg["w0"] * bw * (1.0 if wt == "sword" else 1.15), cfg["w1"] * bw * (1.0 if wt == "sword" else 1.15),
                    cfg["tip"], 0.016, cfg.get("wave", 0.0) * bw, bm)]
    if cfg.get("fuller"):          # canal no meio da lâmina, nas duas faces
        for sgn in (-1, 1):
            parts.append(_blade(ck, n + "fuller_%d" % sgn, g + ridge * sgn * 0.012 * gs, fwd, side, start + 0.04, L * 0.7, 0.008, 0.006, 0.02, 0.004, 0.0, gold))
    if cfg.get("core"):            # filete que brilha
        glow = ck.mat("m_wpn_glow", (1.0, 0.92, 0.6), 0.3, 2.2)
        for sgn in (-1, 1):
            parts.append(_blade(ck, n + "core_%d" % sgn, g + ridge * sgn * 0.013 * gs, fwd, side, start + 0.03, L * 0.85, 0.011, 0.008, 0.05, 0.004, 0.0, glow))
    # cabo e pomo
    gm = t2 if cfg.get("grip_mat") == "tint2" else mats["leather"]
    parts.append(ck.tube(n + "grip", g - fwd * G, g + fwd * G, 0.026, 0.026, gm, 8))
    for k in range(3 if wt == "sword" else 5):     # tiras do cabo
        z = -G + (k + 0.5) * (2 * G) / (3 if wt == "sword" else 5)
        parts.append(ck.tube(n + "wrap_%d" % k, g + fwd * (z - 0.008), g + fwd * (z + 0.008), 0.03, 0.03, gold, 8))
    pp = g - fwd * (G + 0.04)
    pom = cfg["pommel"]
    if pom == "ball":
        parts.append(ck.ball(n + "pommel", 0.042, pp, gold))
    elif pom == "gem":
        parts += [ck.ball(n + "pommel", 0.038, pp, gold), ck.ball(n + "pommel_gem", 0.026, pp - fwd * 0.03, t2, (1, 1, 1.3))]
    elif pom == "ring":
        for i in range(12):
            a0, a1 = math.tau * i / 12, math.tau * (i + 1) / 12
            parts.append(ck.tube(n + "pommel_ring_%d" % i, pp + side * math.cos(a0) * 0.04 + fwd * math.sin(a0) * 0.04,
                                 pp + side * math.cos(a1) * 0.04 + fwd * math.sin(a1) * 0.04, 0.013, 0.013, gold, 6))
    elif pom == "crown":
        parts.append(ck.ball(n + "pommel", 0.036, pp, gold))
        for i in range(5):
            a = math.tau * i / 5
            d = side * math.cos(a) + ridge * math.sin(a)
            parts.append(ck.blade(n + "pommel_spike_%d" % i, pp + d * 0.025, pp + d * 0.04 - fwd * 0.06, 0.022, 0.012, gold, fwd.cross(d)))
    # guarda
    gc = g + fwd * (G + 0.015)
    guard = cfg["guard"]
    if guard == "cross":
        parts.append(ck.tube(n + "guard", gc - side * 0.14 * gs, gc + side * 0.14 * gs, 0.022, 0.022, gold, 8))
        for sx in (-1, 1):
            parts.append(ck.ball(n + "guard_end_%d" % sx, 0.03, gc + side * sx * 0.15 * gs, t))
    elif guard == "down":          # braços curvados para o cabo
        for sx in (-1, 1):
            parts.append(ck.blade(n + "guard_%d" % sx, gc, gc + side * sx * 0.15 * gs - fwd * 0.06, 0.05, 0.03, t, ridge))
        parts.append(ck.ball(n + "guard_mid", 0.04, gc, gold, (1.3, 0.8, 1.0)))
    elif guard == "horn":          # chifres para a frente, ao longo da lâmina
        parts.append(ck.ball(n + "guard_mid", 0.045, gc, t, (1.4, 0.8, 1.0)))
        for sx in (-1, 1):
            p1 = gc + side * sx * 0.1 * gs
            p2 = gc + side * sx * 0.13 * gs + fwd * 0.12 * gs
            parts += [ck.tube(n + "horn_a_%d" % sx, gc, p1, 0.026, 0.02, t, 8), ck.tube(n + "horn_b_%d" % sx, p1, p2, 0.02, 0.004, gold, 8)]
    elif guard == "sun":           # disco com raios em volta da base da lâmina
        parts.append(ck.ball(n + "guard_disc", 0.07 * gs, gc, gold, (1.0, 1.0, 0.35)))
        for i in range(10):
            a = math.tau * i / 10
            d = side * math.cos(a) + ridge * math.sin(a) * 0.35
            parts.append(ck.blade(n + "guard_ray_%d" % i, gc + d * 0.06 * gs, gc + d.normalized() * 0.15 * gs + fwd * 0.02, 0.035, 0.012, gold, fwd))
    elif guard == "wing":          # asas abertas para os lados e para a ponta
        parts.append(ck.ball(n + "guard_mid", 0.04, gc, gold, (1.3, 0.8, 1.0)))
        for sx in (-1, 1):
            for k in range(3):
                parts.append(ck.blade(n + "wing_%d_%d" % (sx, k), gc + side * sx * 0.03,
                                      gc + side * sx * (0.17 - k * 0.03) * gs + fwd * (0.05 + k * 0.05) * gs, 0.05 * gs, 0.015, mats["white"], ridge))
    if cfg.get("gem"):
        for sg in (-1, 1):         # gema nas duas faces da guarda
            parts.append(ck.ball(n + "guard_gem_%d" % sg, 0.034, gc + ridge * sg * 0.035, t2, (1, 0.6, 1.2)))
    if cfg.get("halo"):            # anel em volta da lâmina logo acima da guarda
        hc = g + fwd * (start + 0.12)
        for i in range(16):
            a0, a1 = math.tau * i / 16, math.tau * (i + 1) / 16
            parts.append(ck.tube(n + "halo_%d" % i, hc + (side * math.cos(a0) + ridge * math.sin(a0)) * 0.09 * gs,
                                 hc + (side * math.cos(a1) + ridge * math.sin(a1)) * 0.09 * gs, 0.011, 0.011, gold, 6))
    obj = ck._join(parts, "wpn_main_%s_%s" % (wt, style))
    ck._smooth(obj.data)
    ck.skin_rigid(obj, base["rig"], "hand.R")
    return obj


def weapon_styles():
    return PAL_WEAPONS



# ---------------------------------------------------------------------------
# Escudos dos conjuntos do Guardião: famílias no formato do shield_kit (x = lado, z = altura, frente em -y),
# registradas em shield_kit.FAMILIES com o nome do estilo; montagem, ícone e checagem de contato vêm de graça.
def _heater(S, w=0.78, top=0.82, waist=0.2):
    return [(0, top), (w * 0.55, top + 0.04), (w, top - 0.04), (w, waist), (w * 0.75, -0.42), (w * 0.38, -0.82), (0, -1.05)]


def shield_pal1(ck, name, mats):
    """Fortaleza: heater roxo com aro branco e o V do peito do conjunto."""
    import shield_kit as sk
    t, wh, gold = mats["tint"], mats["white"], mats["trim"]
    S = 0.37
    out = sk.mirror(_heater(S), S)
    parts = [sk.plate(name + "_aro", [(x * 1.08, z * 1.06) for x, z in out], -0.03, 0.03, wh), sk.plate(name + "_corpo", out, -0.09, 0.02, t)]
    for k in (-1, 1):
        parts.append(sk.blade(name + "_v_%d" % k, (k * S * 0.62, S * 0.62), (0, -S * 0.42), 0.16, 0.05, wh, 0.5, -0.1))
    parts.append(sk.gem(name + "_gema", (0, S * 0.5), 0.065, sk.jewel(ck, "violeta"), -0.12, 6, 1.2))
    return parts + sk._back(ck, name, mats)


def shield_pal_g10(ck, name, mats):
    """Bastião: heater clássico, cruz em relevo e rebites na borda."""
    import shield_kit as sk
    t, t2, gold = mats["tint"], mats["tint2"], mats["trim"]
    S = 0.37
    out = sk.mirror(_heater(S), S)
    parts = [sk.plate(name + "_aro", [(x * 1.08, z * 1.06) for x, z in out], -0.03, 0.03, gold), sk.plate(name + "_corpo", out, -0.08, 0.02, t),
             ck.box(name + "_cruz_v", (0.1, 0.05, S * 2.1), (0, -0.09, -S * 0.08), mats["white"], 0.012),
             ck.box(name + "_cruz_h", (S * 1.45, 0.05, 0.1), (0, -0.09, S * 0.36), mats["white"], 0.012)]
    for i, (x, z) in enumerate(out[::2]):
        parts.append(ck.ball(name + "_rebite_%d" % i, 0.026, (x * 0.93, -0.055, z * 0.93), gold))
    return parts + sk._back(ck, name, mats)


def shield_pal_g15(ck, name, mats):
    """Muralha: escudo-torre alto, três faixas em arco e o brasão no meio."""
    import shield_kit as sk
    t, t2, gold = mats["tint"], mats["tint2"], mats["trim"]
    S = 0.36
    half = [(0, 1.05), (0.42, 1.0), (0.66, 0.86), (0.7, 0.3), (0.7, -0.5), (0.5, -0.86), (0, -1.1)]
    out = sk.mirror(half, S)
    parts = [sk.plate(name + "_aro", [(x * 1.07, z * 1.05) for x, z in out], -0.03, 0.03, gold), sk.plate(name + "_corpo", out, -0.08, 0.02, t)]
    for k, z in enumerate((0.62, -0.05, -0.62)):
        parts.append(sk.rib(name + "_faixa_%d" % k, z * S, S * 0.66, 0.05, 0.07, gold, -0.06, 0.9))
    crest = sk.mirror([(0, 0.34), (0.24, 0.3), (0.22, 0.0), (0, -0.3)], S)
    parts.append(sk.plate(name + "_brasao", crest, -0.13, -0.05, t2, 0.0, S * 0.28))
    return parts + sk._back(ck, name, mats)


def shield_pal_g20(ck, name, mats):
    """Aurora: escudo redondo, umbo de sol e raios até a borda."""
    import shield_kit as sk
    t, t2, gold, wh = mats["tint"], mats["tint2"], mats["trim"], mats["white"]
    R = 0.36
    out = [(math.cos(math.tau * i / 28) * R, math.sin(math.tau * i / 28) * R) for i in range(28)]
    parts = [sk.plate(name + "_aro", [(x * 1.08, z * 1.08) for x, z in out], -0.03, 0.03, wh), sk.plate(name + "_corpo", out, -0.09, 0.02, t)]
    for i in range(12):
        a = math.tau * i / 12
        parts.append(sk.blade(name + "_raio_%d" % i, (math.cos(a) * R * 0.28, math.sin(a) * R * 0.28), (math.cos(a) * R * 0.95, math.sin(a) * R * 0.95),
                              0.07 if i % 2 == 0 else 0.045, 0.03, gold, 0.25, -0.09))
    parts.append(sk.plate(name + "_umbo", [(math.cos(math.tau * i / 16) * R * 0.3, math.sin(math.tau * i / 16) * R * 0.3) for i in range(16)], -0.17, -0.07, gold))
    parts.append(sk.gem(name + "_gema", (0, 0), 0.06, sk.jewel(ck, "ambar"), -0.18, 8, 1.0))
    return parts + sk._back(ck, name, mats)


def shield_pal_g25(ck, name, mats):
    """Basalto: kite angular escuro, chifres nos cantos de cima, gema vermelha e cravos."""
    import shield_kit as sk
    t, t2, gold = mats["tint"], mats["tint2"], mats["trim"]
    S = 0.37
    half = [(0, 0.72), (0.5, 0.86), (0.78, 0.7), (0.66, 0.1), (0.36, -0.62), (0, -1.1)]
    out = sk.mirror(half, S)
    parts = [sk.plate(name + "_aro", [(x * 1.08, z * 1.06) for x, z in out], -0.03, 0.03, t2), sk.plate(name + "_corpo", out, -0.1, 0.02, t)]
    for k in (-1, 1):
        parts.append(sk.blade(name + "_chifre_%d" % k, (k * S * 0.66, S * 0.74), (k * S * 1.12, S * 1.32), 0.13, 0.06, gold, 0.3, -0.06))
        parts.append(sk.band(name + "_veio_%d" % k, [(k * S * 0.12, S * 0.34), (k * S * 0.42, S * 0.12), (k * S * 0.5, -S * 0.3)], 0.05, 0.02, t2, -0.08, 0.4))
    parts.append(sk.gem(name + "_gema", (0, S * 0.32), 0.075, sk.jewel(ck, "rubi"), -0.14, 6, 1.3))
    for i, z in enumerate((-0.2, -0.5, -0.78)):
        parts.append(ck.ball(name + "_cravo_%d" % i, 0.03, (0, -0.1, z * S), gold))
    return parts + sk._back(ck, name, mats)


def shield_pal_g30(ck, name, mats):
    """Égide: heater grande com asas abertas no alto, halo e sol no meio."""
    import shield_kit as sk
    t, t2, gold, wh = mats["tint"], mats["tint2"], mats["trim"], mats["white"]
    S = 0.37
    out = sk.mirror(_heater(S, 0.76, 0.86), S)
    parts = [sk.plate(name + "_aro", [(x * 1.08, z * 1.06) for x, z in out], -0.03, 0.03, gold), sk.plate(name + "_corpo", out, -0.09, 0.02, t)]
    for k in (-1, 1):
        for i in range(4):
            parts.append(sk.blade(name + "_asa_%d_%d" % (k, i), (k * S * 0.5, S * 0.7), (k * S * (1.2 - i * 0.1), S * (1.25 - i * 0.22)),
                                  0.12, 0.04, wh, 0.3, -0.05))
    parts += sk.ring(name + "_halo", (0, S * 1.05), S * 0.32, 0.018, gold, 18, -0.06)
    for i in range(8):
        a = math.tau * i / 8
        parts.append(sk.blade(name + "_sol_%d" % i, (math.cos(a) * S * 0.12, S * 0.2 + math.sin(a) * S * 0.12),
                              (math.cos(a) * S * 0.36, S * 0.2 + math.sin(a) * S * 0.36), 0.06, 0.03, gold, 0.3, -0.1))
    parts.append(sk.gem(name + "_gema", (0, S * 0.2), 0.07, sk.jewel(ck, "branco"), -0.14, 8, 1.0))
    return parts + sk._back(ck, name, mats)


SET_SHIELDS = {"pal1": shield_pal1, "pal_g10": shield_pal_g10, "pal_g15": shield_pal_g15, "pal_g20": shield_pal_g20,
               "pal_g25": shield_pal_g25, "pal_g30": shield_pal_g30}



# ---------------------------------------------------------------------------
# Maças dos conjuntos (alternativa à espada): Guardião = maça de flanges de 1 mão, Cruzado = malho de 2 mãos.
# head (1 mão): flange (n flanges) | star (núcleo com cravos) | sun (disco com raios)
# face (malho): plain | cross | gem | sun ; spikes = cravos no malho ; wings / halo / glow / dark como nas espadas
PAL_MACES = {
    "pal1": {"type": "mace", "head": "flange", "n": 6, "core": "tint", "cap": "gem"},
    "pal_g10": {"type": "mace", "head": "flange", "n": 6, "core": "metal", "cap": "ball"},
    "pal_g15": {"type": "mace", "head": "flange", "n": 8, "core": "tint", "cap": "gem"},
    "pal_g20": {"type": "mace", "head": "sun", "core": "tint", "cap": "ball"},
    "pal_g25": {"type": "mace", "head": "star", "core": "tint", "cap": "gem", "dark": True, "horns": True},
    "pal_g30": {"type": "mace", "head": "flange", "n": 8, "core": "tint", "cap": "gem", "wings": True, "halo": True, "glow": True},
    "pal_c5": {"type": "mace2h", "face": "cross"},
    "pal_c10": {"type": "mace2h", "face": "plain", "wings": True},
    "pal_c15": {"type": "mace2h", "face": "gem"},
    "pal_c20": {"type": "mace2h", "face": "sun", "glow": True},
    "pal_c25": {"type": "mace2h", "face": "gem", "spikes": True, "dark": True},
    "pal_c30": {"type": "mace2h", "face": "sun", "wings": True, "halo": True, "glow": True},
}


def build_mace(ck, base, mats, style, cfg, hand="main"):
    """Maça do conjunto (eixo das armas do kit), 1 malha: wpn_main_<mace|mace2h>_<estilo>, ou wpn_off_mace_<estilo> na esquerda."""
    V = Vector
    g = V(ck.hand_center(base, ".R" if hand == "main" else ".L"))
    fwd = V((0, -0.55, 0.83)).normalized()
    side = V((1, 0, 0))
    ridge = fwd.cross(side).normalized()
    t, t2, gold, wh = mats["tint"], mats["tint2"], mats["trim"], mats["white"]
    metal = mats["dark"] if cfg.get("dark") else mats["metal"]
    glow = ck.mat("m_wpn_glow", (1.0, 0.92, 0.6), 0.3, 2.2)
    n = "m_%s_%s_" % (style, hand)
    parts = []
    if cfg["type"] == "mace":
        hc = g + fwd * 0.56
        parts += [ck.tube(n + "shaft", g - fwd * 0.13, g + fwd * 0.46, 0.03, 0.028, t2, 8), ck.ball(n + "pommel", 0.045, g - fwd * 0.15, gold),
                  ck.tube(n + "collar", g + fwd * 0.38, g + fwd * 0.43, 0.05, 0.05, gold, 10)]
        for k in range(3):
            parts.append(ck.tube(n + "wrap%d" % k, g + fwd * (-0.08 + k * 0.07), g + fwd * (-0.06 + k * 0.07), 0.034, 0.034, gold, 8))
        core = t if cfg.get("core") == "tint" else metal
        parts.append(ck.tube(n + "core", hc - fwd * 0.13, hc + fwd * 0.13, 0.085, 0.085, core, 12))
        head = cfg["head"]
        if head == "flange":
            for k in range(cfg["n"]):
                a = math.tau * k / cfg["n"]
                d = side * math.cos(a) + ridge * math.sin(a)
                parts.append(ck._flange(n + "flange%d" % k, hc, fwd, d, 0.2, 0.3, 0.032, metal))
        elif head == "star":
            parts.append(ck.ball(n + "ball", 0.13, hc, metal))
            for k in range(14):        # cravos espalhados na esfera (espiral de Fibonacci)
                z = 1.0 - 2.0 * (k + 0.5) / 14
                r = math.sqrt(1.0 - z * z)
                a = k * 2.39996
                d = (side * math.cos(a) * r + ridge * math.sin(a) * r + fwd * z).normalized()
                parts.append(ck.tube(n + "spike%d" % k, hc + d * 0.11, hc + d * 0.21, 0.035, 0.003, gold, 6))
        elif head == "sun":
            parts.append(ck.ball(n + "disc", 0.15, hc, gold, (1.0, 1.0, 0.45)))
            parts.append(ck.ball(n + "disc_core", 0.09, hc, t, (1.0, 1.0, 0.6)))
            for k in range(12):
                a = math.tau * k / 12
                d = side * math.cos(a) + fwd * math.sin(a)
                parts.append(ck.blade(n + "ray%d" % k, hc + d * 0.12, hc + d * (0.26 if k % 2 == 0 else 0.2), 0.06, 0.03, gold, fwd.cross(d) if k % 3 else ridge))
        top = hc + fwd * 0.15
        if cfg.get("cap") == "gem":
            parts += [ck.ball(n + "cap", 0.06, top, gold, (1, 1, 0.8)), ck.ball(n + "cap_gem", 0.045, top + fwd * 0.05, t2, (1, 1, 1.4))]
        else:
            parts.append(ck.ball(n + "cap", 0.065, top, gold, (1, 1, 0.8)))
        if cfg.get("horns"):
            for sx in (-1, 1):
                p1 = hc + side * sx * 0.13 - fwd * 0.08
                parts += [ck.tube(n + "horn_a%d" % sx, hc - fwd * 0.1, p1, 0.035, 0.028, t, 8),
                          ck.tube(n + "horn_b%d" % sx, p1, p1 + side * sx * 0.06 + fwd * 0.16, 0.028, 0.004, gold, 8)]
        wing_at, wing_s = hc - fwd * 0.16, 1.0
    else:
        hc = g + fwd * 0.98
        parts += [ck.tube(n + "shaft", g - fwd * 0.34, g + fwd * 0.88, 0.033, 0.03, t2, 8), ck.tube(n + "butt", g - fwd * 0.42, g - fwd * 0.33, 0.045, 0.04, gold, 8),
                  ck.tube(n + "collar", g + fwd * 0.8, g + fwd * 0.88, 0.055, 0.055, gold, 10)]
        for k in range(4):
            parts.append(ck.tube(n + "wrap%d" % k, g + fwd * (-0.26 + k * 0.12), g + fwd * (-0.235 + k * 0.12), 0.038, 0.038, gold, 8))
        parts.append(ck.tube(n + "head", hc - side * 0.22, hc + side * 0.22, 0.14, 0.14, metal, 8))
        for sx in (-1, 1):
            fc = hc + side * sx * 0.24
            parts += [ck.tube(n + "face%d" % sx, hc + side * sx * 0.22, fc, 0.135, 0.11, metal, 8),
                      ck.tube(n + "band%d" % sx, hc + side * sx * 0.1, hc + side * sx * 0.16, 0.15, 0.15, t, 8)]
            face = cfg["face"]
            if face == "cross":
                parts += [ck.tube(n + "cross_v%d" % sx, fc - fwd * 0.08, fc + fwd * 0.08, 0.022, 0.022, gold, 6),
                          ck.tube(n + "cross_h%d" % sx, fc - ridge * 0.06 + fwd * 0.02, fc + ridge * 0.06 + fwd * 0.02, 0.022, 0.022, gold, 6)]
            elif face == "gem":
                parts.append(ck.ball(n + "face_gem%d" % sx, 0.06, fc + side * sx * 0.01, t2, (0.6, 1, 1)))
            elif face == "sun":
                parts.append(ck.ball(n + "face_sun%d" % sx, 0.07, fc + side * sx * 0.01, gold, (0.5, 1, 1)))
                for k in range(8):
                    a = math.tau * k / 8
                    d = fwd * math.cos(a) + ridge * math.sin(a)
                    parts.append(ck.blade(n + "face_ray%d_%d" % (sx, k), fc + d * 0.06, fc + d * 0.13, 0.04, 0.02, gold, side))
            if cfg.get("spikes"):
                for k in range(4):
                    a = math.tau * k / 4 + math.pi / 4
                    d = fwd * math.cos(a) + ridge * math.sin(a)
                    parts.append(ck.tube(n + "spike%d_%d" % (sx, k), hc + side * sx * 0.05 + d * 0.13, hc + side * sx * 0.05 + d * 0.24, 0.035, 0.003, gold, 6))
        parts.append(ck.tube(n + "top", hc + fwd * 0.12, hc + fwd * 0.3, 0.055, 0.004, gold, 8))
        # emblema também nas faces largas (frente/trás): é o que a câmera alta e o ícone veem
        for sg in (-1, 1):
            fc = hc + ridge * sg * 0.14
            parts.append(ck.ball(n + "plate%d" % sg, 0.1, fc, t, (1.6, 0.25, 1.0)))
            face = cfg["face"]
            if face in ("cross", "plain"):
                parts += [ck.box(n + "pcross_v%d" % sg, (0.035, 0.03, 0.16), fc + ridge * sg * 0.02, gold, 0.006),
                          ck.box(n + "pcross_h%d" % sg, (0.13, 0.03, 0.035), fc + ridge * sg * 0.02 + V((0, 0, 0.025)), gold, 0.006)]
            elif face == "gem":
                parts.append(ck.ball(n + "pgem%d" % sg, 0.06, fc + ridge * sg * 0.025, t2, (1, 0.55, 1.2)))
            elif face == "sun":
                parts.append(ck.ball(n + "psun%d" % sg, 0.05, fc + ridge * sg * 0.025, gold, (1, 0.5, 1)))
                for k in range(8):
                    a = math.tau * k / 8
                    d = side * math.cos(a) + fwd * math.sin(a)
                    parts.append(ck.blade(n + "pray%d_%d" % (sg, k), fc + ridge * sg * 0.02 + d * 0.05, fc + ridge * sg * 0.02 + d * 0.12, 0.035, 0.015, gold, ridge.cross(d)))
        wing_at, wing_s = hc - fwd * 0.18, 1.25
    if cfg.get("glow"):
        parts.append(ck.tube(n + "glow", hc - fwd * 0.04, hc + fwd * 0.04, 0.155 if cfg["type"] == "mace2h" else 0.1, 0.155 if cfg["type"] == "mace2h" else 0.1, glow, 14))
    if cfg.get("wings"):
        for sx in (-1, 1):
            for k in range(3):
                parts.append(ck.blade(n + "wing%d_%d" % (sx, k), wing_at + side * sx * 0.04,
                                      wing_at + side * sx * (0.2 - k * 0.04) * wing_s - fwd * (0.02 + k * 0.06) * wing_s, 0.06 * wing_s, 0.016, wh, ridge))
    if cfg.get("halo"):
        hh = wing_at - fwd * 0.06
        for i in range(16):
            a0, a1 = math.tau * i / 16, math.tau * (i + 1) / 16
            parts.append(ck.tube(n + "halo%d" % i, hh + (side * math.cos(a0) + ridge * math.sin(a0)) * 0.1 * wing_s,
                                 hh + (side * math.cos(a1) + ridge * math.sin(a1)) * 0.1 * wing_s, 0.012, 0.012, gold, 6))
    obj = ck._join(parts, ("wpn_main_%s_%s" % (cfg["type"], style)) if hand == "main" else ("wpn_off_mace_%s" % style))
    ck._smooth(obj.data)
    ck.skin_rigid(obj, base["rig"], "hand.R" if hand == "main" else "hand.L")
    return obj


def register(ck):
    """Põe cada conjunto em chibi_kit.SET_STYLES (fn(base, mats)); cada um sai com 1 malha por slot."""
    def wrap(fn, prefix):
        return lambda base, mats: (fn(base, mats), join_slots(prefix))
    ck.SET_STYLES["pal1"] = wrap(ck.SET_STYLES["pal1"], "arm_pal1_")
    import shield_kit
    shield_kit.FAMILIES.update(SET_SHIELDS)       # o kit monta wpn_off_shield_<estilo> para cada família
    ck.SET_WEAPONS = {st: (lambda st_, cf: (lambda base, mats: build_weapon(ck, base, mats, st_, cf)))(st, cf) for st, cf in PAL_WEAPONS.items()}
    for st, cf in PAL_MACES.items():          # maça do conjunto ao lado da espada
        ck.SET_WEAPONS[st + "_mace"] = (lambda st_, cf_: (lambda base, mats: build_mace(ck, base, mats, st_, cf_)))(st, cf)
    for style, cfg in PAL_SETS.items():
        ck.SET_STYLES[style] = wrap((lambda st, cf: (lambda base, mats: build(ck, base, mats, st, cf)))(style, cfg), "arm_%s_" % style)
