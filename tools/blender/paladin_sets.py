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
    # ---- Templário (fogo sagrado, espada e escudo): elmo-balde, sobreveste longa com a cruz grande, chamas que crescem a cada tier ----
    "pal_t5": {"helm": "great", "visor": "jaw", "orn": [], "emblem": "cross", "layers": 1, "pauldron": [],
               "tabard": 0.3, "tabard_mat": "white", "mark": "tint", "faulds": 1, "trim": "tint", "gauntlet": 0.95, "knee": "plain"},
    "pal_t10": {"helm": "great", "visor": "bevor", "orn": ["crest"], "emblem": "cross", "layers": 1, "pauldron": ["round"],
                "tabard": 0.32, "tabard_mat": "white", "mark": "tint", "faulds": 1, "trim": "gold", "gauntlet": 1.0, "knee": "plain"},
    "pal_t15": {"helm": "great", "visor": "jaw", "orn": ["flame"], "emblem": "cross", "layers": 2, "pauldron": ["round"],
                "tabard": 0.32, "tabard_mat": "white", "mark": "tint", "faulds": 1, "trim": "tint", "gauntlet": 1.0, "knee": "spike"},
    "pal_t20": {"helm": "great", "visor": "jaw", "orn": ["flame", "rays"], "emblem": "sun", "layers": 2, "pauldron": ["flame"],
                "tabard": 0.34, "tabard_mat": "white", "mark": "gold", "faulds": 2, "trim": "gold", "gauntlet": 1.05, "knee": "plain"},
    "pal_t25": {"helm": "great", "visor": "bevor", "orn": ["flame", "horns"], "emblem": "cross", "layers": 2, "pauldron": ["spike", "flame"],
                "tabard": 0.34, "tabard_mat": "dark", "mark": "tint2", "faulds": 2, "trim": "tint2", "gauntlet": 1.15, "knee": "spike"},
    "pal_t30": {"helm": "great", "visor": "jaw", "orn": ["flame", "crown", "halo"], "emblem": "sun", "layers": 3, "pauldron": ["flame", "wing"],
                "tabard": 0.36, "tabard_mat": "white", "mark": "gold", "faulds": 2, "trim": "gold", "gauntlet": 1.15, "knee": "wing"},
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
    if "flame" in orn:         # chama sagrada no alto do elmo (Templário): línguas de fogo que brilham, abertas em leque
        fire = ck.mat("m_set_holyfire", (1.0, 0.36, 0.05), 0.3, 0.6)
        for k in range(5):
            a = math.radians(-50 + k * 25)
            h = 1.15 if k == 2 else (0.95 if k in (1, 3) else 0.7)
            root = c + V((math.sin(a) * r * 0.3, r * 0.05, r * 0.9))
            head.append(ck.blade(P + "head_flame_%d" % k, root, root + V((math.sin(a) * r * 0.55, r * 0.2, r * h)), r * 0.34, 0.05, fire, (math.cos(a), 0, -math.sin(a)), 0.3))
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
    if em == "cross" and cfg.get("mark"):       # Templário: sobreveste branca no peito com a cruz grande
        mk = pick[cfg["mark"]]
        chest += [ck.box(P + "body_surcoat", (0.24, 0.02, 0.26), (0, front + 0.012, ez - 0.03), pick[cfg["tabard_mat"]], 0.02),
                  ck.box(P + "body_cross_v", (0.055, 0.03, 0.22), (0, front - 0.004, ez - 0.02), mk, 0.01),
                  ck.box(P + "body_cross_h", (0.19, 0.03, 0.055), (0, front - 0.004, ez + 0.03), mk, 0.01)]
    elif em == "cross":
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
        bm_ = pick[cfg["mark"]] if cfg.get("mark") else tr
        bw_ = 1.4 if cfg.get("mark") else 1.0
        chest += [ck.box(P + "body_back_cross_v", (0.05 * bw_, 0.03, 0.2 * bw_), (0, back, ez), bm_, 0.01), ck.box(P + "body_back_cross_h", (0.15 * bw_, 0.03, 0.05 * bw_), (0, back, ez + 0.04), bm_, 0.01)]
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
            hw = 0.12 if cfg.get("mark") else 0.085       # sobreveste do Templário: pano mais largo
            hips += [_banner(ck, P + "body_tabard_" + side, y, top, hw, L, 0.016, tm),
                     _banner(ck, P + "body_tabard_hem_" + side, y + (-0.004 if side == "f" else 0.004), top, hw + 0.01, L + 0.025, 0.01, tr)]
        if cfg.get("mark"):    # cruz grande na sobreveste, na frente e atrás (de cima é o que se lê)
            mk = pick[cfg["mark"]]
            for side, y in (("f", -b["waist"] * d * 1.2 - 0.032), ("b", b["waist"] * d * 1.2 + 0.032)):
                hips += [ck.box(P + "body_tabard_mark_v_" + side, (0.045, 0.012, L * 0.62), (0, y, ck.Z["waist"] - 0.04 - L * 0.32), mk, 0.004),
                         ck.box(P + "body_tabard_mark_h_" + side, (0.15, 0.012, 0.04), (0, y, ck.Z["waist"] - 0.04 - L * 0.18), mk, 0.004)]
        else:
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
        if "round" in cfg["pauldron"]:     # bossa redonda no meio da ombreira
            pa.append(ck.ball(P + "body_pauldron_boss" + tag, 0.045, sh + V((sx * 0.13, 0, 0.1)), tr, (1, 1, 0.7)))
        if "flame" in cfg["pauldron"]:     # chamas sagradas saindo das ombreiras
            fire = ck.mat("m_set_holyfire", (1.0, 0.36, 0.05), 0.3, 0.6)
            for k in range(3):
                pa.append(ck.blade(P + "body_pauldron_flame_%d" % k + tag, top + V((sx * 0.01, -0.06 + k * 0.06, -0.03)),
                                   top + V((sx * (0.07 + 0.02 * (k == 1)), -0.08 + k * 0.08, 0.16 + 0.06 * (k == 1))), 0.07, 0.03, fire, (0, 1, 0), 0.3))
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
    # Templário: espada de cruzada (guarda reta e longa), o filete vira chama sagrada nos tiers altos
    "pal_t5": {"type": "sword", "w0": 0.038, "w1": 0.03, "tip": 0.12, "guard": "cross", "pommel": "ball", "grip_mat": "tint2"},
    "pal_t10": {"type": "sword", "w0": 0.04, "w1": 0.032, "tip": 0.13, "guard": "cross", "pommel": "ring", "fuller": True, "gem": True},
    "pal_t15": {"type": "sword", "w0": 0.042, "w1": 0.034, "tip": 0.13, "guard": "flame", "pommel": "gem", "fire": True},
    "pal_t20": {"type": "sword", "w0": 0.044, "w1": 0.036, "tip": 0.15, "guard": "sun", "pommel": "gem", "fire": True, "gem": True},
    "pal_t25": {"type": "sword", "w0": 0.045, "w1": 0.04, "tip": 0.12, "wave": 0.012, "guard": "flame", "pommel": "crown", "fire": True, "blade_mat": "dark"},
    "pal_t30": {"type": "sword", "w0": 0.046, "w1": 0.038, "tip": 0.16, "guard": "flame", "pommel": "gem", "gem": True, "halo": True, "fire": True},
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
    if cfg.get("fire"):            # filete de fogo sagrado (Templário), mais largo que o core
        fire = ck.mat("m_set_holyfire", (1.0, 0.36, 0.05), 0.3, 0.6)
        for sgn in (-1, 1):
            parts.append(_blade(ck, n + "fire_%d" % sgn, g + ridge * sgn * 0.013 * gs, fwd, side, start + 0.02, L * 0.9, 0.016, 0.01, 0.07, 0.004, cfg.get("wave", 0.0), fire))
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
    elif guard == "flame":         # braços em chama, subindo ao longo da lâmina
        fire = ck.mat("m_set_holyfire", (1.0, 0.36, 0.05), 0.3, 0.6)
        parts.append(ck.tube(n + "guard", gc - side * 0.1 * gs, gc + side * 0.1 * gs, 0.024, 0.024, gold, 8))
        for sx in (-1, 1):
            for k in range(2):
                parts.append(ck.blade(n + "flame_%d_%d" % (sx, k), gc + side * sx * (0.06 + k * 0.05) * gs,
                                      gc + side * sx * (0.1 + k * 0.06) * gs + fwd * (0.12 - k * 0.04) * gs, 0.045 * gs, 0.015, fire, ridge))
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


# Escudos do Templário: heater/kite com a cruz grande (reta ou pátea) sobre campo claro; chamas no alto nos tiers altos.
# shape: heater | kite | tower | round ; field / cross / rim = material (white, tint, tint2, gold, dark) ; flames: n línguas no topo
TEMPLAR_SHIELDS = {
    "pal_t5": {"shape": "heater", "field": "white", "cross": "tint", "patee": False, "rim": "tint"},
    "pal_t10": {"shape": "heater", "field": "white", "cross": "tint", "patee": True, "rim": "gold", "rivets": True},
    "pal_t15": {"shape": "kite", "field": "white", "cross": "tint", "patee": True, "rim": "tint", "flames": 3},
    "pal_t20": {"shape": "round", "field": "white", "cross": "gold", "patee": True, "rim": "gold", "flames": 5, "gem": "ambar"},
    "pal_t25": {"shape": "kite", "field": "dark", "cross": "tint2", "patee": True, "rim": "tint2", "flames": 3, "gem": "rubi"},
    "pal_t30": {"shape": "tower", "field": "white", "cross": "gold", "patee": True, "rim": "gold", "flames": 7, "gem": "ambar", "halo": True},
}


def shield_templar(cfg):
    def fn(ck, name, mats):
        import shield_kit as sk
        pick = {"white": mats["white"], "tint": mats["tint"], "tint2": mats["tint2"], "gold": mats["trim"], "dark": mats["dark"]}
        S = 0.37
        shp = cfg["shape"]
        if shp == "round":
            out = [(math.cos(math.tau * i / 28) * S * 0.98, math.sin(math.tau * i / 28) * S * 0.98) for i in range(28)]
        elif shp == "kite":
            out = sk.mirror([(0, 0.95), (0.42, 0.88), (0.66, 0.6), (0.6, 0.0), (0.34, -0.6), (0, -1.12)], S)
        elif shp == "tower":
            out = sk.mirror([(0, 1.02), (0.5, 0.98), (0.7, 0.85), (0.7, -0.4), (0.5, -0.85), (0, -1.08)], S)
        else:
            out = sk.mirror(_heater(S), S)
        top = max(z for _, z in out)
        bot = min(z for _, z in out)
        wid = max(x for x, _ in out)
        cz = (top + bot) * 0.5 + S * 0.12
        parts = [sk.plate(name + "_aro", [(x * 1.08, z * 1.06) for x, z in out], -0.03, 0.03, pick[cfg["rim"]]),
                 sk.plate(name + "_corpo", out, -0.09, 0.02, pick[cfg["field"]])]
        cm = pick[cfg["cross"]]
        ends = [(0, top * 0.9), (0, bot * 0.86), (-wid * 0.86, cz), (wid * 0.86, cz)]
        for i, e in enumerate(ends):
            if cfg.get("patee"):        # braço que alarga para a ponta
                parts.append(sk.blade(name + "_cruz_%d" % i, (0, cz), e, 0.2, 0.05, cm, 0.88, -0.09))
            else:
                parts.append(sk.blade(name + "_cruz_%d" % i, (0, cz), e, 0.11, 0.05, cm, 0.5, -0.09))
        if cfg.get("rivets"):
            for i, (x, z) in enumerate(out[::2]):
                parts.append(ck.ball(name + "_rebite_%d" % i, 0.024, (x * 0.93, -0.055, z * 0.93), mats["trim"]))
        nf = int(cfg.get("flames", 0))
        if nf:
            fire = ck.mat("m_set_holyfire", (1.0, 0.36, 0.05), 0.3, 0.6)
            for i in range(nf):
                f = (i + 0.5) / nf - 0.5
                h = 0.32 - abs(f) * 0.32
                parts.append(sk.blade(name + "_chama_%d" % i, (f * wid * 1.5, top * 0.9), (f * wid * 1.9, top + S * (0.22 + h)), 0.1, 0.04, fire, 0.3, -0.04))
        if cfg.get("gem"):
            parts.append(sk.gem(name + "_gema", (0, cz), 0.07, sk.jewel(ck, cfg["gem"]), -0.15, 8, 1.0))
        if cfg.get("halo"):
            parts += sk.ring(name + "_halo", (0, cz), S * 0.3, 0.015, mats["trim"], 18, -0.12)
        return parts + sk._back(ck, name, mats)
    return fn


SET_SHIELDS = {"pal1": shield_pal1, "pal_g10": shield_pal_g10, "pal_g15": shield_pal_g15, "pal_g20": shield_pal_g20,
               "pal_g25": shield_pal_g25, "pal_g30": shield_pal_g30}
SET_SHIELDS.update({st: shield_templar(cf) for st, cf in TEMPLAR_SHIELDS.items()})



# ---------------------------------------------------------------------------
# Maças dos conjuntos (alternativa à espada): Guardião = maça de flanges de 1 mão, Cruzado = malho de 2 mãos.
# head (1 mão): flange (n flanges) | star (núcleo com cravos) | sun (disco com raios)
#   | hammer (martelo de guerra do Templário: bloco atravessado no cabo, face de bater no +X da arma; _hammer_head)
#     back: flat (duas faces) | spike (bico atrás) ; face: plain | studs | sun | crown ; emblem (lados largos): plain | cross | gem | sun
#     top: cap (pomo/gema de "cap") | spike ; core: metal | tint | white (bloco; o conjunto todo dourado pede bloco branco)
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
    # Templário = a build do martelo: martelos de guerra de uma mão (o tipo da arma continua "mace")
    "pal_t5": {"type": "mace", "head": "hammer", "core": "metal", "cap": "ball", "back": "flat", "face": "plain", "emblem": "plain"},
    "pal_t10": {"type": "mace", "head": "hammer", "core": "tint", "cap": "gem", "back": "flat", "face": "plain", "emblem": "cross"},
    "pal_t15": {"type": "mace", "head": "hammer", "core": "tint", "cap": "gem", "back": "spike", "face": "studs", "emblem": "cross", "fire": True},
    "pal_t20": {"type": "mace", "head": "hammer", "core": "tint", "cap": "gem", "back": "flat", "face": "sun", "emblem": "sun", "fire": True},
    "pal_t25": {"type": "mace", "head": "hammer", "core": "tint", "cap": "gem", "back": "spike", "face": "studs", "emblem": "gem", "top": "spike",
                "dark": True, "fire": True},
    "pal_t30": {"type": "mace", "head": "hammer", "core": "white", "cap": "gem", "back": "flat", "face": "crown", "emblem": "sun", "halo": True, "fire": True},
}


# martelo: meio comprimento do bloco (no eixo X da arma), meia altura (ao longo do cabo) e meia espessura
HAMMER_L, HAMMER_H, HAMMER_D = 0.15, 0.115, 0.1


def _block(ck, name, c, u, v, w, hu, hv, hw, material, bevel=0.0, taper=1.0):
    """Caixa orientada (eixos u, v, w; meias medidas hu, hv, hw); taper = escala da ponta +u (tronco de pirâmide)."""
    import bmesh
    bm = bmesh.new()
    vs = {}
    for su in (-1, 1):
        k = taper if su > 0 else 1.0
        for sv in (-1, 1):
            for sw in (-1, 1):
                vs[(su, sv, sw)] = bm.verts.new(c + u * hu * su + v * hv * sv * k + w * hw * sw * k)
    for ax in range(3):
        for sg in (-1, 1):
            a, b = [i for i in range(3) if i != ax]
            quad = []
            for sa, sb in ((-1, -1), (1, -1), (1, 1), (-1, 1)):
                key = [0, 0, 0]
                key[ax], key[a], key[b] = sg, sa, sb
                quad.append(vs[tuple(key)])
            bm.faces.new(quad)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    if bevel > 0:
        bmesh.ops.bevel(bm, geom=bm.edges[:], offset=bevel, segments=1, affect="EDGES")
    return ck.mesh_from(name, bm, material)


def _hammer_head(ck, n, hc, fwd, side, ridge, cfg, mats, metal):
    """Cabeça do martelo de guerra: bloco atravessado no cabo, face de bater alargada no +side, costas chatas ou em bico."""
    t, t2, gold = mats["tint"], mats["tint2"], mats["trim"]
    L, H, D = HAMMER_L, HAMMER_H, HAMMER_D
    core = {"tint": t, "white": mats["white"]}.get(cfg.get("core"), metal)
    parts = [_block(ck, n + "block", hc, side, ridge, fwd, L, D, H, core, 0.016),
             ck.tube(n + "socket", hc - fwd * (H + 0.05), hc - fwd * (H - 0.01), 0.05, 0.062, gold, 8)]
    crown = cfg.get("face") == "crown"
    ends = (1, -1) if cfg.get("back", "flat") == "flat" else (1,)
    for sx in ends:                 # face de bater: cinta de ouro + tronco que alarga + lábio
        d = side * sx
        flare = 1.3 if crown else 1.18
        parts += [_block(ck, n + "band%d" % sx, hc + d * (L - 0.005), d, ridge, fwd, 0.022, D * 1.1, H * 1.1, gold, 0.008),
                  _block(ck, n + "face%d" % sx, hc + d * (L + 0.05), d, ridge, fwd, 0.04, D * 0.96, H * 0.96, metal, 0.012, flare),
                  _block(ck, n + "lip%d" % sx, hc + d * (L + 0.1), d, ridge, fwd, 0.014, D * flare, H * flare, gold if crown else metal, 0.008)]
        fc = hc + d * (L + 0.114)
        face = cfg.get("face", "plain")
        if face == "studs":         # quatro cravos em pirâmide
            for i, (sv, sw) in enumerate(((-1, -1), (1, -1), (1, 1), (-1, 1))):
                p = fc + ridge * sv * D * 0.55 + fwd * sw * H * 0.55
                parts.append(ck.tube(n + "stud%d_%d" % (sx, i), p - d * 0.01, p + d * 0.07, 0.042, 0.004, gold, 4))
        elif face == "sun":         # disco e raios curtos DENTRO da face (raio comprido escondia o bloco)
            parts.append(ck.tube(n + "fsun%d" % sx, fc - d * 0.005, fc + d * 0.03, 0.07, 0.045, gold, 10))
            for k in range(8):
                a = math.tau * k / 8
                r = ridge * math.cos(a) + fwd * math.sin(a)
                parts.append(ck.blade(n + "fray%d_%d" % (sx, k), fc + d * 0.004 + r * 0.055, fc + d * 0.004 + r * (0.135 if k % 2 == 0 else 0.105),
                                      0.05, 0.024, gold, d.cross(r)))
        elif face == "crown":       # coroa: dentes na borda da face, gema no meio
            fl = flare * 0.92
            for i, (sv, sw) in enumerate(((-1, -1), (1, -1), (1, 1), (-1, 1))):
                p = fc + ridge * sv * D * fl + fwd * sw * H * fl
                parts.append(ck.tube(n + "tooth%d_%d" % (sx, i), p - d * 0.02, p + d * 0.085, 0.042, 0.004, gold, 4))
            parts.append(ck.ball(n + "fgem%d" % sx, 0.05, fc + d * 0.01, t2))
    if len(ends) == 1:              # bico atrás (corvo): pirâmide longa saindo de uma cinta
        d = -side
        parts += [_block(ck, n + "band-1", hc + d * (L - 0.005), d, ridge, fwd, 0.022, D * 1.1, H * 1.1, gold, 0.008),
                  _block(ck, n + "pick", hc + d * (L + 0.11), d, ridge, fwd, 0.11, D * 0.6, H * 0.62, metal, 0.0, 0.08)]
    emb = cfg.get("emblem", "plain")
    for sg in (-1, 1):              # emblema nos lados largos (frente/trás): o que a câmera alta e o ícone veem
        o = ridge * sg
        fc = hc + o * D
        if emb == "cross":
            parts += [_block(ck, n + "cross_v%d" % sg, fc + o * 0.006, side, ridge, fwd, 0.02, 0.014, H * 0.74, gold, 0.004),
                      _block(ck, n + "cross_h%d" % sg, fc + o * 0.006 + fwd * H * 0.2, side, ridge, fwd, 0.062, 0.014, 0.02, gold, 0.004)]
        elif emb == "gem":
            parts += [ck.tube(n + "gem_ring%d" % sg, fc - o * 0.005, fc + o * 0.018, 0.066, 0.056, gold, 8),
                      ck.ball(n + "gem%d" % sg, 0.045, fc + o * 0.018, t2)]
        elif emb == "sun":
            parts.append(ck.tube(n + "sun%d" % sg, fc - o * 0.005, fc + o * 0.022, 0.05, 0.036, gold, 10))
            for k in range(8):
                a = math.tau * k / 8
                r = side * math.cos(a) + fwd * math.sin(a)
                parts.append(ck.blade(n + "sray%d_%d" % (sg, k), fc + o * 0.008 + r * 0.045, fc + o * 0.008 + r * 0.1, 0.032, 0.014, gold, o.cross(r)))
        else:                       # rebites
            for i, (su, sw) in enumerate(((-1, -1), (1, -1), (1, 1), (-1, 1))):
                parts.append(ck.ball(n + "rivet%d_%d" % (sg, i), 0.02, fc + side * su * L * 0.62 + fwd * sw * H * 0.58, gold))
    top = hc + fwd * H
    if cfg.get("top") == "spike":
        parts += [ck.tube(n + "top_base", top - fwd * 0.01, top + fwd * 0.03, 0.06, 0.05, gold, 8),
                  ck.tube(n + "top", top + fwd * 0.03, top + fwd * 0.2, 0.045, 0.004, metal, 6)]
    elif cfg.get("cap") == "gem":
        parts += [ck.tube(n + "cap", top - fwd * 0.01, top + fwd * 0.035, 0.06, 0.045, gold, 8), ck.ball(n + "cap_gem", 0.045, top + fwd * 0.05, t2, (1, 1, 1.3))]
    else:
        parts.append(ck.ball(n + "cap", 0.055, top + fwd * 0.01, gold, (1, 1, 0.8)))
    if cfg.get("glow"):
        parts.append(_block(ck, n + "glow_band", hc, side, ridge, fwd, 0.03, D * 1.08, H * 1.08, ck.mat("m_wpn_glow", (1.0, 0.92, 0.6), 0.3, 2.2), 0.006))
    return parts


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
        head = cfg["head"]
        if head != "hammer":
            parts.append(ck.tube(n + "core", hc - fwd * 0.13, hc + fwd * 0.13, 0.085, 0.085, core, 12))
        if head == "hammer":
            parts += _hammer_head(ck, n, hc, fwd, side, ridge, cfg, mats, metal)
        elif head == "flange":
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
        if head == "hammer":
            pass                    # o pomo de cima sai do _hammer_head
        elif cfg.get("cap") == "gem":
            parts += [ck.ball(n + "cap", 0.06, top, gold, (1, 1, 0.8)), ck.ball(n + "cap_gem", 0.045, top + fwd * 0.05, t2, (1, 1, 1.4))]
        else:
            parts.append(ck.ball(n + "cap", 0.065, top, gold, (1, 1, 0.8)))
        if cfg.get("horns"):
            for sx in (-1, 1):
                p1 = hc + side * sx * 0.13 - fwd * 0.08
                parts += [ck.tube(n + "horn_a%d" % sx, hc - fwd * 0.1, p1, 0.035, 0.028, t, 8),
                          ck.tube(n + "horn_b%d" % sx, p1, p1 + side * sx * 0.06 + fwd * 0.16, 0.028, 0.004, gold, 8)]
        wing_at, wing_s = hc - fwd * 0.16, 1.0
        if head == "hammer":
            wing_at = hc - fwd * (HAMMER_H + 0.07)
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
    if cfg.get("fire"):            # brasa sagrada em volta da cabeça (Templário)
        fire = ck.mat("m_set_holyfire", (1.0, 0.36, 0.05), 0.3, 0.6)
        if cfg.get("head") == "hammer":     # martelo: crista de chamas no alto do bloco
            for k, f in enumerate((-0.5, 0.0, 0.5)):      # só três línguas no meio: de cima (o idle mostra o topo) o bloco continua à vista
                root = hc + side * f * HAMMER_L + ridge * (0.03 if k % 2 else -0.03) + fwd * (HAMMER_H - 0.03)
                parts.append(ck.blade(n + "fire%d" % k, root, root + fwd * (0.2 - abs(f) * 0.12) + side * f * 0.05, 0.075, 0.028, fire, side))
        for k in range(0 if cfg.get("head") == "hammer" else 6):
            a = math.tau * k / 6
            d = side * math.cos(a) + ridge * math.sin(a)
            parts.append(ck.blade(n + "fire%d" % k, hc + d * 0.1 - fwd * 0.05, hc + d * 0.16 + fwd * 0.16, 0.06, 0.02, fire, fwd.cross(d)))
    if cfg.get("glow") and cfg.get("head") != "hammer":
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


# ---------------------------------------------------------------------------
# Ato II (níveis 35/40/45 + Ápice/híbrido da build): UM visual novo de ARMADURA por build, tema guerra contra a Horda em
# Monte Kharzun. A malha é a mesma nos três níveis; o jogo pinta a cor do item (tint), o destaque (tint2) e as peças acesas
# (material "tint_glow") por nível: GearCatalog.ACT2_VISUALS[...]["colors"/"accents"/"glows"]. Espadas, maças e escudos
# continuam os do nível 30 (ACT2_VISUALS "wpn"/"shield").
# Estes estilos NÃO entram no kit principal do Paladino (195 malhas, teto de 200): vão no kit extra
# kit_paladin_<sexo>_a2.glb (chibi_kit.A2_STYLES / build_kit_a2), que o KitModel só carrega quando uma peça dessas é vestida.
#   pal_g35 Guardião = Baluarte de Kharzun: elmo de cerco de topo chato com fenda acesa, crista em leque ATRAVESSADA (tint2),
#           ombreiras quadradas de torre com ameias e seteira acesa, gola de pele, placas rebitadas na barriga.
#   pal_c35 Cruzado = Lança da Aurora: celada de bico com olhos acesos, crina longa (tint2) caindo pelas costas, UMA ombreira
#           gigante com espigão no ombro direito, meia-capa (tint2) com gola de pele no esquerdo, tabardo comprido partido.
#   pal_t35 Templário = Chama de Guerra: elmo-balde coroado com um braseiro aceso no alto, viseira em cruz acesa, correntes
#           nos ombros com turíbulos acesos pendurados, saiote de escamas.
FUR_PALE = (0.8, 0.78, 0.74)


def _a2_mats(ck, mats):
    import berserker_sets as bs
    return (mats["tint"], mats["tint2"], mats["trim"], mats["dark"], mats["metal"], mats["white"],
            ck.mat("m_pal_fur", FUR_PALE, 0.95), bs._tint_glow(ck), bs)


def _a2_limbs(ck, base, mats, P, kind):
    """Manoplas e botas do Ato II. kind: tower (blocos quadrados) | lance (aletas) | flame (escamas e aro aceso)."""
    V = Vector
    rig, body, b, j = base["rig"], base["body"], base["b"], base["j"]
    t, t2, gold, dark, metal, wh, fur, glow, bs = _a2_mats(ck, mats)
    for s, sx in ((".R", -1), (".L", 1)):
        tag = s.replace(".", "_")
        el, wr = V(j["elbow" + s]), V(j["wrist" + s])
        big = 1.25 if kind == "tower" else 1.1
        g = [ck.tube(P + "gloves_cuff" + tag, el.lerp(wr, 0.2), wr + V((0, 0, 0.01)), 0.078 * big, 0.108 * big, t, 12),
             ck.tube(P + "gloves_rim" + tag, wr + V((0, 0, 0.005)), wr + V((0, 0, 0.032)), 0.115 * big, 0.115 * big, metal if kind == "tower" else gold, 12)]
        if kind == "tower":              # cotoveleira quadrada e placa rebitada no dorso
            g += [ck.box(P + "gloves_elbow" + tag, (0.13, 0.13, 0.09), el + V((sx * 0.02, 0.02, 0.0)), metal, 0.02),
                  ck.box(P + "gloves_plate" + tag, (0.04, 0.12, 0.12), el.lerp(wr, 0.6) + V((sx * 0.115, 0, 0)), metal, 0.012)]
            for k in range(2):
                g.append(ck.ball(P + "gloves_rivet_%d%s" % (k, tag), 0.02, el.lerp(wr, 0.45 + k * 0.3) + V((sx * 0.14, 0, 0)), gold))
            g.append(ck.box(P + "gloves_slit" + tag, (0.02, 0.028, 0.07), el.lerp(wr, 0.6) + V((sx * 0.138, 0, 0)), glow, 0.005))     # seteira acesa
        elif kind == "lance":            # aleta longa para fora, cotovelo redondo
            g += [ck.ball(P + "gloves_elbow" + tag, 0.07, el + V((sx * 0.02, 0.02, 0)), gold, (1.0, 1.0, 0.9)),
                  ck.ball(P + "gloves_gem" + tag, 0.028, el.lerp(wr, 0.62) + V((sx * 0.1, -0.02, 0)), glow, (0.7, 1.0, 1.3)),
                  ck.blade(P + "gloves_fin" + tag, el.lerp(wr, 0.25) + V((sx * 0.07, 0, 0)), el.lerp(wr, 0.9) + V((sx * 0.16, 0.02, 0.04)), 0.07, 0.03, gold, (0, 1, 0))]
        else:                            # aro aceso no punho e duas escamas
            g.append(ck.tube(P + "gloves_lit" + tag, el.lerp(wr, 0.55), el.lerp(wr, 0.68), 0.1, 0.106, glow, 12))
            for k in range(2):
                p = el.lerp(wr, 0.3 + k * 0.42) + V((sx * 0.085, 0, 0))
                g.append(ck.blade(P + "gloves_scale_%d%s" % (k, tag), p + V((0, 0, 0.05)), p + V((sx * 0.035, 0, -0.07)), 0.1, 0.03, metal, (0, 1, 0), 0.3))
        ck._rigid(bs._outward(g), rig, "forearm" + s)
        hc = V(ck.hand_center(base, s))
        fist = [ck.ball(P + "gloves_fist" + tag, b["hand"] * (1.55 if kind == "tower" else 1.4), hc, t, (1, 1, 1.1))]
        for k in range(2):
            fist.append(ck.box(P + "gloves_knuckle_%d%s" % (k, tag), (0.08, 0.03, 0.022), hc + V((sx * 0.01, -0.065, 0.035 - k * 0.032)), metal if kind == "tower" else gold, 0.008))
        ck._rigid(fist, rig, "hand" + s)
    ck.armor_piece(body, rig, P + "boots_shell", "boots", t, 0.028 if kind == "tower" else 0.024, 0.016)
    for s, sx in ((".R", -1), (".L", 1)):
        tag = s.replace(".", "_")
        kn, an = V(j["knee" + s]), V(j["ankle" + s])
        k = [ck.tube(P + "boots_cuff" + tag, an + V((0, 0, 0.06)), an + V((0, 0, 0.095)), 0.095, 0.095, metal if kind == "tower" else gold, 12)]
        if kind == "tower":              # joelheira quadrada com ameia e caneleira rebitada
            k += [ck.box(P + "boots_knee" + tag, (0.15, 0.07, 0.12), kn + V((0, -0.085, 0.015)), t, 0.02),
                  ck.box(P + "boots_knee_cap" + tag, (0.17, 0.085, 0.035), kn + V((0, -0.085, 0.085)), metal, 0.01),
                  ck.box(P + "boots_shin" + tag, (0.08, 0.03, 0.09), an.lerp(kn, 0.55) + V((0, -0.08, 0)), metal, 0.008),
                  ck.box(P + "boots_slit" + tag, (0.024, 0.03, 0.07), kn + V((0, -0.118, 0.015)), glow, 0.005)]
        elif kind == "lance":            # joelheira em ponta e asa no tornozelo
            k += [ck.ball(P + "boots_knee" + tag, 0.078, kn + V((0, -0.075, 0.01)), t, (1.05, 0.7, 1.0)),
                  ck.blade(P + "boots_knee_spike" + tag, kn + V((0, -0.11, -0.01)), kn + V((0, -0.19, 0.1)), 0.07, 0.04, gold, (1, 0, 0)),
                  ck.ball(P + "boots_knee_gem" + tag, 0.026, kn + V((0, -0.135, -0.02)), glow, (1.0, 0.6, 1.0)),
                  ck.blade(P + "boots_wing" + tag, an + V((sx * 0.07, 0.01, 0.08)), an + V((sx * 0.16, 0.07, 0.2)), 0.07, 0.025, t2, (0, 1, 0))]
        else:                            # joelheira redonda com brasa
            k += [ck.ball(P + "boots_knee" + tag, 0.08, kn + V((0, -0.075, 0.01)), t, (1.05, 0.7, 1.0)),
                  ck.ball(P + "boots_knee_lit" + tag, 0.03, kn + V((0, -0.13, 0.015)), glow, (1.0, 0.6, 1.0)),
                  ck.blade(P + "boots_scale" + tag, an.lerp(kn, 0.75) + V((0, -0.08, 0)), an.lerp(kn, 0.2) + V((0, -0.09, 0)), 0.1, 0.03, metal, (1, 0, 0), 0.3)]
        ck._rigid(bs._outward(k), rig, "shin" + s)
        toe = [ck.ball(P + "boots_toe" + tag, 0.062, an + V((0, -0.11, -0.04)), metal if kind == "tower" else gold, (1.0, 1.25, 0.6))]
        for q in range(2):
            toe.append(ck.box(P + "boots_lame_%d%s" % (q, tag), (0.125, 0.05, 0.022), an + V((0, -0.06 - q * 0.03, 0.0 - q * 0.02)), t, 0.008))
        ck._rigid(toe, rig, "foot" + s)


def _chain(ck, name, p0, p1, sag, material, n=6, rad=0.012):
    """Corrente pendurada de p0 a p1 (barriga para baixo de sag), em n elos retos."""
    p0, p1 = Vector(p0), Vector(p1)
    out, prev = [], p0
    for i in range(1, n + 1):
        k = i / n
        p = p0.lerp(p1, k) + Vector((0, 0, -sag * math.sin(math.pi * k)))
        out.append(ck.tube("%s_%d" % (name, i), prev, p, rad, rad, material, 4))
        prev = p
    return out


def _censer(ck, name, top, drop, metal, glow, size=0.05):
    """Turíbulo pendurado numa corrente: brasa acesa numa gaiola de ferro com tampa em ponta."""
    V = Vector
    top = V(top)
    cp = top + V((0, 0, -drop))
    out = [ck.tube(name + "_chain", top, cp + V((0, 0, size * 1.2)), 0.008, 0.008, metal, 4),
           ck.ball(name + "_lit", size * 0.92, cp, glow, (1, 1, 1.1)),
           ck.tube(name + "_ring", cp + V((0, 0, -size * 0.22)), cp + V((0, 0, size * 0.22)), size, size, metal, 8),
           ck.tube(name + "_cap", cp + V((0, 0, size * 0.72)), cp + V((0, 0, size * 1.5)), size * 0.68, 0.006, metal, 8),
           ck.tube(name + "_foot", cp + V((0, 0, -size * 0.72)), cp + V((0, 0, -size * 1.6)), size * 0.56, 0.004, metal, 8)]
    for k in range(4):
        a = math.tau * (k + 0.5) / 4
        o = V((math.cos(a) * size * 0.94, math.sin(a) * size * 0.94, 0))
        out.append(ck.tube(name + "_bar_%d" % k, cp + o + V((0, 0, size * 0.8)), cp + o + V((0, 0, -size * 0.8)), 0.007, 0.007, metal, 4))
    return out


def build_bulwark(ck, base, mats, style):
    """pal_g35 — Baluarte de Kharzun (Guardião, placa)."""
    V = Vector
    rig, body, b, j = base["rig"], base["body"], base["b"], base["j"]
    t, t2, gold, dark, metal, wh, fur, glow, bs = _a2_mats(ck, mats)
    P = "arm_%s_" % style
    c, r = V(base["head_c"]), b["head"]
    # ---------------- cabeça: elmo de cerco de topo chato, fenda acesa, crista em leque atravessada ----------------
    head = [ck._shell(P + "head_helm", c, r * 1.16, -0.75, -0.62, -0.5, 0.04, t),
            ck.tube(P + "head_drum", c + V((0, 0, r * 0.3)), c + V((0, 0, r * 1.2)), r * 1.2, r * 1.1, t, 20),
            ck.tube(P + "head_top_rim", c + V((0, 0, r * 1.15)), c + V((0, 0, r * 1.23)), r * 1.14, r * 1.13, metal, 20),
            ck.tube(P + "head_band", c + V((0, 0, r * 0.26)), c + V((0, 0, r * 0.4)), r * 1.24, r * 1.23, metal, 20),
            ck.ball(P + "head_face", r * 0.86, c + V((0, -r * 0.82, -r * 0.14)), t, (1.1, 0.5, 1.02)),
            ck.box(P + "head_slit", (r * 1.3, 0.08, r * 0.13), c + V((0, -r * 1.25, r * 0.04)), glow, 0.02),
            ck.box(P + "head_nasal", (0.075, 0.1, r * 0.95), c + V((0, -r * 1.27, -r * 0.2)), metal, 0.02),
            ck.tube(P + "head_rim", c + V((0, 0, -r * 0.62)), c + V((0, 0, -r * 0.5)), r * 1.12, r * 1.22, metal, 20),
            ck.box(P + "head_crest_base", (r * 1.9, 0.12, 0.07), c + V((0, r * 0.05, r * 1.24)), metal, 0.02)]
    for sx in (-1, 1):
        for k in range(3):               # furos de respiro
            head.append(ck.box(P + "head_hole_%d_%d" % (sx, k), (0.03, 0.05, 0.03), c + V((sx * r * (0.3 + k * 0.17), -r * 1.2 + k * 0.035, -r * 0.42)), dark, 0.006))
    for k in range(6):
        a = math.pi * (0.22 + 0.56 * k / 5.0) + math.pi
        head.append(ck.ball(P + "head_rivet_%d" % k, 0.032, c + V((math.cos(a) * r * 1.26, math.sin(a) * r * 1.26, r * 0.33)), gold))
    for k in range(9):                   # crista de crina em leque, de orelha a orelha
        a = math.radians(-76 + k * 19)
        root = c + V((math.sin(a) * r * 0.75, r * 0.05, r * 1.22))
        tip = c + V((math.sin(a) * r * 1.6, r * 0.08, r * 1.25 + math.cos(a) * r * 0.85 + r * 0.12))
        head.append(ck.blade(P + "head_crest_%d" % k, root, tip, r * 0.36, 0.07, t2, (math.cos(a), 0, -math.sin(a)), 0.55))
    ck._rigid(bs._outward(head), rig, "head")
    # ---------------- corpo ----------------
    ck.armor_piece(body, rig, P + "body_plate", "torso", t, 0.018, 0.016, 0.04)
    ck.armor_piece(body, rig, P + "body_legs", "legs", metal, 0.008, 0.012)
    d = b["depth"]
    front = -b["chest"] * d - 0.035
    back = b["chest"] * d + 0.035
    zc, zn, zw = ck.Z["chest"], ck.Z["neck"], ck.Z["waist"]
    chest = bs._fur_ring(ck, P, "body_fur", (0, 0, zn - 0.075), b["chest"] * 0.8, 14, 0.066, fur)
    gorget = ck.tube(P + "body_gorget", (0, 0, zn - 0.05), (0, 0, zn + 0.075), b["chest"] * 0.74, b["chest"] * 0.58, metal, 14)
    for v in gorget.data.vertices:
        v.co.y *= 0.9
    chest += [gorget,
              ck.ball(P + "body_breast", 0.17, (0, front + 0.045, zc + 0.015), t, (1.3, 0.42, 1.0)),
              ck.box(P + "body_gate", (0.15, 0.035, 0.15), (0, front - 0.012, zc + 0.01), metal, 0.012),      # portão: grade acesa no peito
              ck.box(P + "body_gate_arch", (0.19, 0.04, 0.04), (0, front - 0.014, zc + 0.095), gold, 0.012)]
    for k in range(3):
        chest.append(ck.box(P + "body_gate_slit_%d" % k, (0.026, 0.03, 0.11), ((k - 1) * 0.045, front - 0.024, zc + 0.005), glow, 0.005))
    for k in range(3):                   # placas rebitadas da barriga
        w = 0.3 - k * 0.025
        zz = zw + 0.085 - k * 0.05
        chest.append(ck.box(P + "body_lame_%d" % k, (w, 0.036, 0.046), (0, -b["waist"] * d * 1.12 - 0.02, zz), t if k % 2 == 0 else metal, 0.012))
        for sx in (-1, 1):
            chest.append(ck.ball(P + "body_lame_rivet_%d_%d" % (k, sx), 0.017, (sx * (w * 0.5 - 0.03), -b["waist"] * d * 1.12 - 0.042, zz), gold))
    # costas: placa de reforço com três rebites e um losango aceso (a câmera alta vê as costas)
    chest += [ck.box(P + "body_back_plate", (0.22, 0.035, 0.2), (0, back, zc + 0.01), metal, 0.014),
              ck.blade(P + "body_back_lit", (0, back + 0.022, zc + 0.085), (0, back + 0.022, zc - 0.065), 0.1, 0.02, glow, (1, 0, 0), 0.5)]
    for k in range(3):
        chest.append(ck.ball(P + "body_back_rivet_%d" % k, 0.02, ((k - 1) * 0.085, back + 0.022, zc + 0.095), gold))
    ck._rigid(bs._outward(chest), rig, "chest")
    bs._belt(ck, base, P + "body_belt", zw - 0.05, zw + 0.04, 1.22, metal)
    wf = -b["waist"] * d * 1.22
    hips = [ck.box(P + "body_buckle", (0.09, 0.03, 0.075), (0, wf - 0.012, zw), gold, 0.012)]
    for k in range(3):                   # escarcelas quadradas, frente e costas
        x = (k - 1) * 0.1
        L = 0.2 if k == 1 else 0.16
        for side, y in (("f", wf - 0.008 + abs(k - 1) * 0.02), ("b", -wf + 0.008 - abs(k - 1) * 0.02)):
            hips += [ck.box(P + "body_tasset_%s%d" % (side, k), (0.092, 0.024, L), (x, y, zw - 0.04 - L * 0.5), t, 0.007),
                     ck.box(P + "body_tasset_rim_%s%d" % (side, k), (0.097, 0.028, 0.03), (x, y, zw - 0.04 - L + 0.012), metal, 0.005),
                     ck.ball(P + "body_tasset_rivet_%s%d" % (side, k), 0.016, (x, y + (-0.014 if side == "f" else 0.014), zw - 0.075), gold)]
    ck._rigid(bs._outward(hips), rig, "hips")
    for s, sx in ((".R", -1), (".L", 1)):                 # ombreiras: torre quadrada com ameias e seteira acesa
        tag = s.replace(".", "_")
        sh = V(j["shoulder" + s])
        ctr = sh + V((sx * 0.105, 0, 0.085))
        pa = [ck.box(P + "body_tower" + tag, (0.2, 0.23, 0.15), ctr, t, 0.018),
              ck.box(P + "body_tower_base" + tag, (0.225, 0.255, 0.04), ctr + V((0, 0, -0.07)), metal, 0.012),
              ck.box(P + "body_tower_top" + tag, (0.215, 0.245, 0.03), ctr + V((0, 0, 0.075)), metal, 0.01),
              ck.box(P + "body_tower_slit" + tag, (0.03, 0.035, 0.085), ctr + V((sx * 0.092, 0, 0.0)), glow, 0.006),
              ck.ball(P + "body_tower_lame" + tag, b["arm"] * 2.5, sh + V((sx * 0.1, 0, -0.06)), t, (1.1, 1.1, 0.6))]
        for qx in (-1, 1):
            for qy in (-1, 0, 1):        # ameias em volta do topo
                if qx == -sx and qy == 0:
                    continue
                pa.append(ck.box(P + "body_merlon_%d_%d%s" % (qx, qy, tag), (0.055, 0.055, 0.06), ctr + V((qx * 0.076, qy * 0.092, 0.115)), t, 0.01))
        for qy in (-1, 1):               # seteiras escuras nas faces da frente e de trás
            pa.append(ck.box(P + "body_tower_arrow_%d%s" % (qy, tag), (0.025, 0.03, 0.07), ctr + V((0, qy * 0.108, 0.0)), dark, 0.005))
        ck._rigid(bs._outward(pa), rig, "upper_arm" + s)
        hp = V(j["hip" + s])
        tas = [ck.box(P + "body_fauld_%d%s" % (k, tag), (0.045, 0.16 - k * 0.012, 0.1), hp + V((sx * (b["thigh"] + 0.04 + k * 0.006), 0, -0.01 - k * 0.07)),
                      t if k % 2 == 0 else metal, 0.012) for k in range(3)]
        ck._rigid(tas, rig, "thigh" + s)
    _a2_limbs(ck, base, mats, P, "tower")


def build_dawn_lance(ck, base, mats, style):
    """pal_c35 — Lança da Aurora (Cruzado, placa)."""
    V = Vector
    rig, body, b, j = base["rig"], base["body"], base["b"], base["j"]
    t, t2, gold, dark, metal, wh, fur, glow, bs = _a2_mats(ck, mats)
    P = "arm_%s_" % style
    c, r = V(base["head_c"]), b["head"]
    # ---------------- cabeça: celada de bico, olhos acesos, crina longa caindo pelas costas ----------------
    head = [ck._shell(P + "head_helm", c, r * 1.16, -0.75, -0.5, -0.45, 0.035, t),
            ck.blade(P + "head_tail", c + V((0, r * 0.75, -r * 0.2)), c + V((0, r * 1.6, -r * 0.78)), r * 1.7, 0.06, t, (1, 0, 0), 0.3),
            ck.tube(P + "head_beak", c + V((0, -r * 0.62, -r * 0.3)), c + V((0, -r * 1.86, -r * 0.42)), r * 0.82, 0.015, t, 4),
            ck.blade(P + "head_beak_ridge", c + V((0, -r * 1.05, r * 0.12)), c + V((0, -r * 1.9, -r * 0.42)), 0.06, r * 0.16, gold, (1, 0, 0), 0.4),
            ck.box(P + "head_visor_brow", (r * 1.7, 0.1, r * 0.1), c + V((0, -r * 1.06, r * 0.36)), gold, 0.02),
            ck.blade(P + "head_comb", c + V((0, -r * 1.0, r * 0.6)), c + V((0, r * 0.9, r * 1.02)), r * 0.34, 0.07, gold, (0, 0, 1), 0.5),
            ck.tube(P + "head_brow", c + V((0, 0, r * 0.16)), c + V((0, 0, r * 0.28)), r * 1.24, r * 1.21, gold, 24),
            ck.tube(P + "head_plume_socket", c + V((0, r * 0.1, r * 1.08)), c + V((0, r * 0.2, r * 1.36)), 0.07, 0.085, gold, 8)]
    for sx in (-1, 1):                   # olhos: fendas inclinadas acesas nas faces do bico
        head.append(ck.blade(P + "head_eye_%d" % sx, c + V((sx * r * 0.16, -r * 1.2, r * 0.12)), c + V((sx * r * 0.84, -r * 0.95, r * 0.25)), r * 0.2, 0.09, glow, (0, 0, 1), 0.5))
        for k in range(3):
            head.append(ck.ball(P + "head_hole_%d_%d" % (sx, k), 0.02, c + V((sx * r * (0.14 + k * 0.1), -r * (1.5 - k * 0.2), -r * (0.22 - k * 0.02))), dark))
        head.append(ck.blade(P + "head_wing_%d" % sx, c + V((sx * r * 1.0, -r * 0.1, r * 0.35)), c + V((sx * r * 1.5, r * 0.75, r * 0.95)), r * 0.5, 0.05, gold, (0, 0.5, 1), 0.4))
    top = c + V((0, r * 0.2, r * 1.34))
    for i, x in enumerate((-0.06, 0.0, 0.06)):     # crina: sobe, arqueia para trás e desce até a cintura
        zz = 0.02 if i == 1 else 0.0
        pts = [top + V((x * 0.4, 0, 0)), top + V((x * 0.9, r * 0.35, r * 0.32 + zz)), top + V((x * 1.5, r * 0.95, r * 0.12 + zz)),
               top + V((x * 1.9, r * 1.4, -r * 0.7)), top + V((x * 2.0, r * 1.5, -r * 1.6)), top + V((x * 1.6, r * 1.42, -r * 2.5 - i * 0.03))]
        head.append(bs._ribbon(ck, P + "head_plume_%d" % i, pts, (1, 0, 0), [0.07, 0.13, 0.16, 0.16, 0.13, 0.015], 0.06, t2))
    ck._rigid(bs._outward(head), rig, "head")
    # ---------------- corpo ----------------
    ck.armor_piece(body, rig, P + "body_plate", "torso", t, 0.016, 0.016, 0.04)
    ck.armor_piece(body, rig, P + "body_legs", "legs", metal, 0.008, 0.012)
    d = b["depth"]
    front = -b["chest"] * d - 0.035
    back = b["chest"] * d + 0.035
    zc, zn, zw = ck.Z["chest"], ck.Z["neck"], ck.Z["waist"]
    chest = [ck.tube(P + "body_gorget", V((0, 0, zn - 0.05)), V((0, 0, zn + 0.02)), b["chest"] * 0.64, b["chest"] * 0.5, gold, 16),
             ck.ball(P + "body_sun", 0.05, (0, front - 0.004, zc + 0.02), glow, (1, 0.45, 1)),            # sol nascente aceso
             ck.box(P + "body_horizon", (0.2, 0.03, 0.028), (0, front - 0.006, zc - 0.012), gold, 0.008),
             ck.blade(P + "body_ridge", (0, front + 0.006, zc - 0.03), (0, front + 0.004, zc - 0.16), 0.035, 0.03, t, (1, 0, 0), 0.5)]
    for k in range(5):                   # raios só para cima
        a = math.radians(20 + k * 35)
        chest.append(ck.blade(P + "body_sun_ray_%d" % k, (math.cos(a) * 0.05, front - 0.002, zc + 0.02 + math.sin(a) * 0.05),
                              (math.cos(a) * 0.125, front - 0.006, zc + 0.02 + math.sin(a) * 0.125), 0.036, 0.02, gold, (-math.sin(a), 0, math.cos(a))))
    for k in range(2):
        chest.append(ck.box(P + "body_plackart_%d" % k, (0.2 - k * 0.03, 0.03, 0.045), (0, -b["waist"] * d * 1.12 - 0.02, zw + 0.07 - k * 0.055), t if k == 0 else gold, 0.012))
    # meia-capa no ombro ESQUERDO (+X): gola de pele por cima, pano em dobras até o joelho, por trás e pelo lado
    lsh = V(j["shoulder.L"])
    chest += bs._fur_ring(ck, P, "body_cape_fur", lsh + V((0.0, 0.02, 0.09)), 0.13, 10, 0.08, fur, 0.03)
    for i, (x0, x1) in enumerate(((0.02, 0.0), (0.15, 0.2), (0.27, 0.36))):
        yb = back + 0.03 - i * 0.045
        pts = [(x0, yb - 0.03, zn - 0.02), (x0 + (x1 - x0) * 0.25, yb + 0.05, zc + 0.05), (x0 + (x1 - x0) * 0.5, yb + 0.035, zw + 0.02),
               (x0 + (x1 - x0) * 0.8, yb + 0.09, zw - 0.17), (x1, yb + 0.07, zw - 0.31 + i * 0.03)]
        chest.append(bs._ribbon(ck, P + "body_cape_%d" % i, pts, (1, 0, 0.0) if i < 2 else (0.6, -0.8, 0), [0.15, 0.17, 0.18, 0.19, 0.17], 0.016, t2))
    chest += [ck.ball(P + "body_cape_clasp", 0.036, lsh + V((-0.09, -0.1, 0.03)), glow, (1.0, 0.6, 1.0)),
              ck.tube(P + "body_cape_cord", lsh + V((-0.09, -0.1, 0.03)), (-0.1, front + 0.01, zn - 0.06), 0.012, 0.012, gold, 6)]
    # costas: disco de sol (o lado direito das costas fica à mostra)
    chest.append(ck.ball(P + "body_back_disc", 0.06, (-0.07, back, zc + 0.02), gold, (1, 0.35, 1)))
    ck._rigid(bs._outward(chest), rig, "chest")
    bs._belt(ck, base, P + "body_belt", zw - 0.035, zw + 0.03, 1.16, gold)
    wf = -b["waist"] * d * 1.2
    hips = [ck.ball(P + "body_buckle", 0.04, (0, wf - 0.012, zw), glow, (1.0, 0.5, 1.0))]
    for side, y in (("f", wf - 0.02), ("b", -wf + 0.02)):     # tabardo comprido partido ao meio: duas abas por lado
        for sx in (-1, 1):
            pair = [_banner(ck, P + "body_tabard_%s%d" % (side, sx), y, zw - 0.03, 0.062, 0.34, 0.016, wh),
                    _banner(ck, P + "body_tabard_hem_%s%d" % (side, sx), y + (-0.004 if side == "f" else 0.004), zw - 0.03, 0.07, 0.365, 0.01, gold)]
            for o in pair:
                for v in o.data.vertices:
                    v.co.x += sx * 0.078
            hips += pair
            hips.append(ck.box(P + "body_tabard_mark_%s%d" % (side, sx), (0.022, 0.012, 0.15), (sx * 0.078, y + (-0.012 if side == "f" else 0.012), zw - 0.16), t2, 0.004))
    ck._rigid(bs._outward(hips), rig, "hips")
    for s, sx in ((".R", -1), (".L", 1)):
        tag = s.replace(".", "_")
        sh = V(j["shoulder" + s])
        pa = []
        if s == ".R":                    # ombreira gigante: quatro lâminas, espigão e gema acesa
            for k in range(4):
                pa.append(ck.ball(P + "body_pauldron_%d%s" % (k, tag), b["arm"] * (3.9 - k * 0.42), sh + V((sx * (0.05 + k * 0.04), 0, 0.12 - k * 0.07)),
                                  t if k % 2 == 0 else gold, (1.15, 1.15, 0.6)))
            top = sh + V((sx * 0.06, 0, 0.19))
            pa += [ck.tube(P + "body_pauldron_spike" + tag, top + V((0, 0, -0.03)), top + V((sx * 0.2, 0.0, 0.3)), 0.06, 0.004, gold, 8),
                   ck.blade(P + "body_pauldron_guard" + tag, sh + V((sx * -0.06, -0.14, 0.1)), sh + V((sx * -0.06, 0.14, 0.1)), 0.3, 0.035, t, (0, 0, 1), 0.5),
                   ck.ball(P + "body_pauldron_gem" + tag, 0.036, sh + V((sx * 0.25, -0.02, 0.1)), glow, (0.6, 1.0, 1.3))]
            for k in range(2):
                pa.append(ck.blade(P + "body_pauldron_fin_%d%s" % (k, tag), top + V((0, (k * 2 - 1) * 0.1, -0.05)), top + V((sx * 0.13, (k * 2 - 1) * 0.17, 0.12)), 0.08, 0.03, gold, (0, 1, 0)))
        else:                            # ombro esquerdo: uma lâmina pequena por baixo da pele
            pa.append(ck.ball(P + "body_pauldron_0" + tag, b["arm"] * 2.4, sh + V((sx * 0.07, 0, 0.03)), t, (1.1, 1.1, 0.6)))
        ck._rigid(bs._outward(pa), rig, "upper_arm" + s)
        hp = V(j["hip" + s])
        tas = [ck.box(P + "body_fauld_%d%s" % (k, tag), (0.04, 0.15 - k * 0.012, 0.11), hp + V((sx * (b["thigh"] + 0.035 + k * 0.006), 0, -0.02 - k * 0.075)),
                      t if k % 2 == 0 else gold, 0.012) for k in range(2)]
        ck._rigid(tas, rig, "thigh" + s)
    _a2_limbs(ck, base, mats, P, "lance")


def build_war_flame(ck, base, mats, style):
    """pal_t35 — Chama de Guerra (Templário, placa)."""
    V = Vector
    rig, body, b, j = base["rig"], base["body"], base["b"], base["j"]
    t, t2, gold, dark, metal, wh, fur, glow, bs = _a2_mats(ck, mats)
    P = "arm_%s_" % style
    c, r = V(base["head_c"]), b["head"]
    # ---------------- cabeça: elmo-balde coroado, viseira em cruz acesa, braseiro aceso no alto ----------------
    head = [ck._shell(P + "head_helm", c, r * 1.16, -0.75, -0.62, -0.5, 0.04, t),
            ck.ball(P + "head_face", r * 0.86, c + V((0, -r * 0.82, -r * 0.14)), t, (1.1, 0.5, 1.02)),
            ck.box(P + "head_slit", (r * 1.2, 0.08, r * 0.12), c + V((0, -r * 1.25, r * 0.05)), glow, 0.02),
            ck.box(P + "head_slit_v", (r * 0.13, 0.08, r * 0.8), c + V((0, -r * 1.26, -r * 0.2)), glow, 0.02),
            ck.tube(P + "head_rim", c + V((0, 0, -r * 0.62)), c + V((0, 0, -r * 0.5)), r * 1.12, r * 1.2, gold, 20),
            ck.tube(P + "head_crown_band", c + V((0, 0, r * 0.4)), c + V((0, 0, r * 0.58)), r * 1.2, r * 1.14, gold, 20)]
    for sx in (-1, 1):                   # molduras da cruz
        head.append(ck.box(P + "head_slit_rim_%d" % sx, (0.03, 0.07, r * 0.84), c + V((sx * r * 0.12, -r * 1.27, -r * 0.2)), gold, 0.006))
    for k in range(8):                   # coroa
        a = math.tau * (k + 0.5) / 8
        dd = V((math.cos(a), math.sin(a), 0))
        head.append(ck.blade(P + "head_crown_%d" % k, c + dd * r * 1.15 + V((0, 0, r * 0.5)), c + dd * r * 1.24 + V((0, 0, r * 1.02)),
                             r * 0.4, 0.05, gold, (-dd.y, dd.x, 0), 0.3))
    bz = r * 1.1                         # braseiro: três pés, bacia de ferro, brasa e línguas de fogo
    head += [ck.tube(P + "head_bowl", c + V((0, 0, bz + r * 0.1)), c + V((0, 0, bz + r * 0.42)), r * 0.36, r * 0.74, metal, 12),
             ck.tube(P + "head_bowl_rim", c + V((0, 0, bz + r * 0.4)), c + V((0, 0, bz + r * 0.48)), r * 0.78, r * 0.76, gold, 12),
             ck.ball(P + "head_ember", r * 0.56, c + V((0, 0, bz + r * 0.46)), glow, (1.0, 1.0, 0.42))]
    for k in range(3):
        a = math.tau * k / 3 + 0.5
        head.append(ck.tube(P + "head_bowl_leg_%d" % k, c + V((math.cos(a) * r * 0.62, math.sin(a) * r * 0.62, r * 0.9)),
                            c + V((math.cos(a) * r * 0.42, math.sin(a) * r * 0.42, bz + r * 0.2)), 0.03, 0.03, metal, 5))
    for k in range(6):                   # chamas: uma alta no meio e cinco em volta
        if k == 0:
            root, tip, w = c + V((0, 0, bz + r * 0.5)), c + V((0.02, r * 0.12, bz + r * 1.5)), r * 0.52
            wd = (1, 0, 0)
        else:
            a = math.tau * k / 5
            root = c + V((math.cos(a) * r * 0.36, math.sin(a) * r * 0.36, bz + r * 0.48))
            tip = c + V((math.cos(a) * r * 0.62, math.sin(a) * r * 0.62 + r * 0.08, bz + r * (1.0 + 0.14 * (k % 2))))
            w = r * 0.36
            wd = (-math.sin(a), math.cos(a), 0)
        head.append(ck.blade(P + "head_flame_%d" % k, root, tip, w, r * 0.16, glow, wd, 0.3))
    ck._rigid(bs._outward(head), rig, "head")
    # ---------------- corpo ----------------
    ck.armor_piece(body, rig, P + "body_plate", "torso", t, 0.016, 0.016, 0.04)
    ck.armor_piece(body, rig, P + "body_legs", "legs", metal, 0.008, 0.012)
    d = b["depth"]
    front = -b["chest"] * d - 0.035
    back = b["chest"] * d + 0.035
    zc, zn, zw = ck.Z["chest"], ck.Z["neck"], ck.Z["waist"]
    chest = [ck.tube(P + "body_gorget", V((0, 0, zn - 0.05)), V((0, 0, zn + 0.02)), b["chest"] * 0.64, b["chest"] * 0.5, gold, 16),
             ck.box(P + "body_surcoat", (0.25, 0.02, 0.27), (0, front + 0.012, zc - 0.0), wh, 0.02),
             ck.box(P + "body_cross_v", (0.06, 0.03, 0.23), (0, front - 0.004, zc + 0.0), t2, 0.01),
             ck.box(P + "body_cross_h", (0.2, 0.03, 0.06), (0, front - 0.004, zc + 0.05), t2, 0.01),
             ck.ball(P + "body_cross_gem", 0.03, (0, front - 0.02, zc + 0.05), glow, (1, 0.6, 1)),
             ck.box(P + "body_back_coat", (0.25, 0.02, 0.27), (0, back - 0.012, zc), wh, 0.02),
             ck.box(P + "body_back_cross_v", (0.07, 0.03, 0.25), (0, back + 0.004, zc), t2, 0.01),
             ck.box(P + "body_back_cross_h", (0.21, 0.03, 0.07), (0, back + 0.004, zc + 0.05), t2, 0.01)]
    rs, ls = V(j["shoulder.R"]), V(j["shoulder.L"])
    # correntes: de ombro a ombro pela frente e por trás
    chest += _chain(ck, P + "body_chain_f", rs + V((0.02, -0.13, 0.06)), ls + V((-0.02, -0.13, 0.06)), 0.13, metal, 8, 0.014)
    chest += _chain(ck, P + "body_chain_b", rs + V((0.02, 0.13, 0.06)), ls + V((-0.02, 0.13, 0.06)), 0.16, metal, 8, 0.014)
    chest += _censer(ck, P + "body_censer_back", (0, back + 0.06, zn - 0.1), 0.2, metal, glow, 0.06)
    ck._rigid(bs._outward(chest), rig, "chest")
    bs._belt(ck, base, P + "body_belt", zw - 0.04, zw + 0.035, 1.18, gold)
    hips = [ck.box(P + "body_buckle", (0.07, 0.03, 0.06), (0, -b["waist"] * d * 1.2 - 0.012, zw), glow, 0.01)]
    n = 12
    for row in range(3):                 # saiote de escamas: três fiadas em volta do quadril
        rad = b["waist"] * (1.2 + row * 0.1)
        zz = zw - 0.035 - row * 0.075
        for k in range(n):
            a = math.tau * (k + 0.5 * (row % 2)) / n
            dd = V((math.cos(a), math.sin(a) * d * 1.05, 0))
            p = V((dd.x * rad, dd.y * rad, zz))
            m_ = t if row % 2 == 0 else metal
            if row == 2 and k % 3 == 0:
                m_ = gold
            hips.append(ck.blade(P + "body_scale_%d_%d" % (row, k), p + V((0, 0, 0.02)), p + dd * 0.025 + V((0, 0, -0.105)), 0.115, 0.022, m_, (-math.sin(a), math.cos(a), 0), 0.35))
    ck._rigid(bs._outward(hips), rig, "hips")
    for s, sx in ((".R", -1), (".L", 1)):                 # ombreiras redondas em duas lâminas, corrente e turíbulo pendurado
        tag = s.replace(".", "_")
        sh = V(j["shoulder" + s])
        pa = []
        for k in range(2):
            pa.append(ck.ball(P + "body_pauldron_%d%s" % (k, tag), b["arm"] * (3.1 - k * 0.4), sh + V((sx * (0.06 + k * 0.035), 0, 0.07 - k * 0.07)),
                              t if k == 0 else gold, (1.15, 1.12, 0.62)))
        pa += [ck.ball(P + "body_pauldron_boss" + tag, 0.05, sh + V((sx * 0.1, 0, 0.14)), gold, (1, 1, 0.7)),
               ck.ball(P + "body_pauldron_lit" + tag, 0.026, sh + V((sx * 0.1, 0, 0.175)), glow)]
        pa += _chain(ck, P + "body_pchain" + tag, sh + V((sx * 0.13, -0.13, 0.04)), sh + V((sx * 0.13, 0.13, 0.04)), 0.09, metal, 6, 0.013)
        pa += _censer(ck, P + "body_censer" + tag, sh + V((sx * 0.21, 0, 0.0)), 0.13, metal, glow, 0.052)
        ck._rigid(bs._outward(pa), rig, "upper_arm" + s)
    _a2_limbs(ck, base, mats, P, "flame")


ACT2_SETS = {"pal_g35": build_bulwark, "pal_c35": build_dawn_lance, "pal_t35": build_war_flame}


def register_a2(ck):
    """Estilos do Ato II no kit EXTRA (chibi_kit.A2_STYLES): fn(base, mats), 1 malha por slot."""
    for style, fn in ACT2_SETS.items():
        ck.A2_STYLES[style] = (lambda st, f: (lambda base, mats: (f(ck, base, mats, st), join_slots("arm_%s_" % st))))(style, fn)


# ---------------------------------------------------------------------------
# Ato III (nível 50, GDD ato3-lendarios-50): UM visual novo por build no tema de Lumeria (porcelana com lágrima pintada,
# máscaras, fitas de seda, espelhos/vidro, lanternas, ouro velho). Malhas no kit extra kit_paladin_<sexo>_a3.glb
# (chibi_kit.A3_STYLES / build_kit_a3); motivos comuns em lumeria_kit.py. tint = marfim, tint2 = fitas, tint_glow = lágrima e chama.
#   pal_g50 Guardião = Vigília da Lágrima Dourada: elmo fechado liso com viseira-máscara de porcelana e UMA lágrima, pires
#           empilhados no alto do elmo e nos ombros (torre larga), fitas azul-noite caindo dos pires, lanterna acesa de pé
#           na ombreira esquerda, peitoral de porcelana com a lágrima pintada.
def build_tear_vigil(ck, base, mats, style):
    """pal_g50 — Vigília da Lágrima Dourada (Guardião, placa)."""
    import lumeria_kit as lk
    V = Vector
    rig, body, b, j = base["rig"], base["body"], base["b"], base["j"]
    M = lk.lum_mats(ck, mats)
    t, t2, gold, porc, glow, metal, bs = M["t"], M["t2"], M["gold"], M["porc"], M["glow"], M["metal"], M["bs"]
    P = "arm_%s_" % style
    c, r = V(base["head_c"]), b["head"]
    # ---------------- cabeça: elmo fechado, viseira-máscara com uma lágrima, pires no alto com botão aceso, fitas na nuca ----------------
    head = [ck._shell(P + "head_helm", c, r * 1.13, -0.8, -0.72, -0.62, 0.04, t),
            ck.tube(P + "head_rim", c + V((0, 0, -r * 0.68)), c + V((0, 0, -r * 0.55)), r * 1.15, r * 1.21, gold, 20),
            ck.tube(P + "head_brow", c + V((0, 0, r * 0.5)), c + V((0, 0, r * 0.6)), r * 1.17, r * 1.12, gold, 20),
            ck.tube(P + "head_silk", c + V((0, 0, r * 0.6)), c + V((0, 0, r * 0.82)), r * 1.115, r * 0.965, t2, 20)]
    for k in range(4):                   # filete de ouro da testa à nuca, por cima do elmo
        a0, a1 = math.radians(-58 + k * 29), math.radians(-58 + (k + 1) * 29)
        head.append(ck.tube(P + "head_seam%d" % k, c + V((0, math.sin(a0) * r * 1.25, math.cos(a0) * r * 1.25)), c + V((0, math.sin(a1) * r * 1.25, math.cos(a1) * r * 1.25)), r * 0.05, r * 0.05, gold, 5))
    head += lk.mask(ck, P + "head_mask", c + V((0, -r * 1.06, -r * 0.06)), r * 0.72, M, tears=(1,), wide=1.22, tear_len=0.62)
    head += lk.saucers(ck, P + "head_top", c + V((0, 0, r * 1.02)), r * 0.62, 3, M, r * 0.15, 0.27)
    head.append(ck.ball(P + "head_top_flame", r * 0.17, c + V((0, 0, r * 1.56)), glow, (1, 1, 1.35)))
    for sx in (-1, 1):                   # duas fitas curtas na nuca
        p0 = c + V((sx * r * 0.3, r * 1.08, r * 0.35))
        head.append(lk.silk(ck, P + "head_ribbon%d" % sx, p0, p0 + V((sx * r * 0.35, r * 0.45, -r * 1.2)), (1, 0, 0), r * 0.26, r * 0.34, t2, (0, r * 0.12, 0), 3))
    ck._rigid(bs._outward(head), rig, "head")
    # ---------------- corpo ----------------
    ck.armor_piece(body, rig, P + "body_plate", "torso", t, 0.018, 0.016, 0.05)
    ck.armor_piece(body, rig, P + "body_legs", "legs", metal, 0.008, 0.012)
    d = b["depth"]
    front = -b["chest"] * d - 0.035
    back = b["chest"] * d + 0.035
    zc, zn, zw = ck.Z["chest"], ck.Z["neck"], ck.Z["waist"]
    chest = [ck.tube(P + "body_gorget", V((0, 0, zn - 0.06)), V((0, 0, zn + 0.03)), b["chest"] * 0.7, b["chest"] * 0.52, gold, 16),
             ck.ball(P + "body_breast", 1.0, (0, front + 0.02, zc + 0.02), porc, (b["chest"] * 0.78, 0.05, 0.15)),
             ck.ball(P + "body_breast_rim", 1.0, (0, front + 0.032, zc + 0.02), gold, (b["chest"] * 0.86, 0.04, 0.165)),
             ck.ball(P + "body_breast_tear", 0.03, (0, front - 0.03, zc + 0.03), glow, (0.8, 0.6, 2.0)),
             ck.ball(P + "body_breast_drop", 0.036, (0, front - 0.028, zc - 0.045), glow, (1, 0.6, 1.2)),
             ck.ball(P + "body_back_dish", 1.0, (0, back - 0.015, zc + 0.02), porc, (b["chest"] * 0.7, 0.045, 0.14)),
             ck.ball(P + "body_back_boss", 0.045, (0, back + 0.03, zc + 0.02), gold, (1, 0.5, 1))]
    ck._rigid(bs._outward(chest), rig, "chest")
    bs._belt(ck, base, P + "body_belt", zw - 0.04, zw + 0.035, 1.2, gold)
    wf = -b["waist"] * d * 1.22
    hips = [ck.ball(P + "body_buckle", 0.045, (0, wf - 0.012, zw), porc, (1.0, 0.5, 1.0)),
            ck.ball(P + "body_buckle_tear", 0.02, (0, wf - 0.034, zw - 0.005), glow, (0.8, 0.6, 1.6))]
    for side, y in (("f", wf - 0.02), ("b", -wf + 0.02)):         # tabardo de seda com barra de ouro
        hips += [_banner(ck, P + "body_tabard_" + side, y, zw - 0.03, 0.105, 0.33, 0.016, t2),
                 _banner(ck, P + "body_tabard_hem_" + side, y + (0.005 if side == "f" else -0.005), zw - 0.03, 0.12, 0.36, 0.01, gold)]
    ck._rigid(bs._outward(hips), rig, "hips")
    for s, sx in ((".R", -1), (".L", 1)):                         # ombreiras: três pires empilhados, fitas caindo, lanterna na esquerda
        tag = s.replace(".", "_")
        sh = V(j["shoulder" + s])
        pc = sh + V((sx * 0.15, 0, -0.03))
        tilt = V((sx * 0.55, 0, 1)).normalized()
        pa = lk.saucers(ck, P + "body_pauldron" + tag, pc, b["arm"] * 3.6, 3, M, 0.062, 0.2, tilt)
        top = pc + tilt * 0.19
        if s == ".L":                    # lanterna de pé na ponta de fora da ombreira (por fora da cabeça: lê de cima)
            pa += lk.lantern(ck, P + "body_lantern", top + V((sx * 0.07, 0, 0.11)), 0.095, M)
        else:
            pa.append(ck.ball(P + "body_pauldron_knob" + tag, 0.05, top + V((0, 0, 0.02)), gold, (1, 1, 0.8)))
        for i, sy in enumerate((-1, 1)):
            p0 = pc + V((sx * 0.12, sy * 0.12, 0.0))
            pa.append(lk.silk(ck, P + "body_pribbon%d%s" % (i, tag), p0, p0 + V((sx * 0.12, sy * 0.07, -0.36 - i * 0.05)), (1, sy * 0.7, 0), 0.085, 0.11, t2, (sx * 0.04, 0, 0), 3))
        ck._rigid(bs._outward(pa), rig, "upper_arm" + s)
        hp = V(j["hip" + s])
        tas = [ck.box(P + "body_fauld_%d%s" % (k, tag), (0.04, 0.16 - k * 0.014, 0.11), hp + V((sx * (b["thigh"] + 0.04 + k * 0.006), 0, -0.02 - k * 0.075)),
                      porc if k == 0 else t, 0.014) for k in range(2)]
        tas.append(ck.ball(P + "body_fauld_stud" + tag, 0.022, hp + V((sx * (b["thigh"] + 0.068), 0, -0.02)), gold))
        ck._rigid(tas, rig, "thigh" + s)
    lk.limbs(ck, base, mats, P, M, "plate")


#   pal_c50 Cruzado = Cortejo do Juízo Claro: elmo aberto com MEIA-máscara de porcelana partida em diagonal (filete de ouro
#           na quebra, lágrima no olho que ficou), penacho de seda (tint2, vinho), ombreiras altas em barbatana, espelho
#           redondo no peito, fitas cruzadas nas costas e capa longa em cinco tiras de seda até o tornozelo.
def build_clear_judgement(ck, base, mats, style):
    """pal_c50 — Cortejo do Juízo Claro (Cruzado, placa)."""
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
    metal = M["metal"]
    # ---------------- cabeça: elmo aberto, meia-máscara em diagonal, penacho e duas fitas ----------------
    head = [ck._shell(P + "head_helm", c, r * 1.13, 0.3, -0.8, -0.6, 0.04, t),
            ck.tube(P + "head_rim", c + V((0, 0, -r * 0.66)), c + V((0, 0, -r * 0.54)), r * 1.15, r * 1.21, gold, 20),
            ck.tube(P + "head_brow", c + V((0, 0, r * 0.42)), c + V((0, 0, r * 0.54)), r * 1.2, r * 1.14, gold, 20)]
    s_ = r * 0.76
    mc = c + V((0, -r * 1.05, -r * 0.05))
    dn = V((-0.75, 0, -0.66)).normalized()
    co = mc + V((-0.05 * s_, 0, -0.12 * s_))
    head += lk.cut(lk.mask(ck, P + "head_mask", mc, s_, M, tears=(1,), wide=1.22, tear_len=0.45), co, dn)
    dv = V((0.66, 0, -0.75)).normalized()
    pts = []
    for q in (-0.95, -0.5, 0.0, 0.5, 0.95):          # filete de ouro ao longo da quebra, acompanhando a curva da máscara
        pts.append(co + dv * s_ * q + V((0, -0.34 * s_ * math.sqrt(max(0.0, 1.0 - q * q * 0.9)) - 0.03 * s_, 0)))
    for k in range(4):
        head.append(ck.tube(P + "head_break%d" % k, pts[k], pts[k + 1], s_ * 0.05, s_ * 0.05, gold, 5))
    head += [ck.blade(P + "head_plume", c + V((0, -r * 0.5, r * 0.95)), c + V((0, r * 1.75, r * 1.55)), r * 1.05, r * 0.36, t2, (0, -0.3, 1), 0.35),
             ck.tube(P + "head_plume_foot", c + V((0, -r * 0.45, r * 0.98)), c + V((0, -r * 0.35, r * 1.28)), r * 0.2, r * 0.13, gold, 8)]
    for sx in (-1, 1):
        p0 = c + V((sx * r * 0.3, r * 1.08, r * 0.3))
        head.append(lk.silk(ck, P + "head_ribbon%d" % sx, p0, p0 + V((sx * r * 0.4, r * 0.5, -r * 1.25)), (1, 0, 0), r * 0.24, r * 0.32, t2, (0, r * 0.12, 0), 3))
    ck._rigid(bs._outward(head), rig, "head")
    # ---------------- corpo: couraça, espelho no peito, fitas cruzadas nas costas, capa em tiras ----------------
    ck.armor_piece(body, rig, P + "body_plate", "torso", t, 0.018, 0.016, 0.05)
    ck.armor_piece(body, rig, P + "body_legs", "legs", metal, 0.008, 0.012)
    chest = [ck.tube(P + "body_gorget", V((0, 0, zn - 0.06)), V((0, 0, zn + 0.03)), b["chest"] * 0.7, b["chest"] * 0.52, gold, 16)]
    chest += lk.mirror(ck, P + "body_mirror", (0, front - 0.005, zc + 0.02), 0.085, M, rays=8, tear=True)
    for sx in (-1, 1):                   # fitas cruzadas nas costas (X de seda) com um broche de porcelana no cruzamento
        p0 = V((sx * b["chest"] * 0.85, back + 0.005, zn - 0.05))
        p1 = V((-sx * b["waist"] * 0.95, back + 0.02 + (0.012 if sx > 0 else 0.0), zw + 0.05))
        chest.append(lk.silk(ck, P + "body_cross%d" % sx, p0, p1, (1, 0, sx * 0.9), 0.08, 0.08, t2, (0, 0.012, 0), 3))
    chest += [ck.ball(P + "body_cross_boss", 0.045, (0, back + 0.04, (zn + zw) * 0.5), porc, (1, 0.5, 1)),
              ck.ball(P + "body_cross_tear", 0.018, (0, back + 0.062, (zn + zw) * 0.5 - 0.005), glow, (0.8, 0.6, 1.7))]
    ck._rigid(bs._outward(chest), rig, "chest")
    cape = []
    for k in range(5):                   # capa longa: cinco tiras do alto das costas até o tornozelo, abrindo (pesos do corpo)
        q = (k - 2) / 2.0
        cape.append(lk.silk(ck, P + "body_cape%d" % k, (q * b["chest"] * 0.8, back + 0.05, zn - 0.02), (q * 0.42, back + 0.36 - abs(q) * 0.08, 0.12 + (k % 2) * 0.07),
                            (1, -q * 0.3, 0), 0.115, 0.17, t2, (0, 0.05, 0), 6, 0.016))
    lk.skinned(ck, base, bs._outward(cape))
    bs._belt(ck, base, P + "body_belt", zw - 0.04, zw + 0.035, 1.2, gold)
    hips = [_banner(ck, P + "body_tabard_f", wf - 0.02, zw - 0.03, 0.1, 0.34, 0.016, t2),
            _banner(ck, P + "body_tabard_hem_f", wf - 0.015, zw - 0.03, 0.115, 0.37, 0.01, gold),
            ck.ball(P + "body_buckle", 0.045, (0, wf - 0.014, zw), porc, (1.0, 0.5, 1.0)),
            ck.ball(P + "body_buckle_tear", 0.02, (0, wf - 0.036, zw - 0.005), glow, (0.8, 0.6, 1.6))]
    ck._rigid(bs._outward(hips), rig, "hips")
    for s, sx in ((".R", -1), (".L", 1)):                 # ombreiras altas: pires + barbatana de porcelana subindo para fora, fio de ouro
        tag = s.replace(".", "_")
        sh = V(j["shoulder" + s])
        pc = sh + V((sx * 0.1, 0, -0.01))
        pa = lk.saucers(ck, P + "body_pauldron" + tag, pc, b["arm"] * 3.1, 2, M, 0.06, 0.22, (sx * 0.5, 0, 1))
        root = pc + V((sx * 0.02, 0, 0.08))
        pa += [ck.blade(P + "body_fin" + tag, root, root + V((sx * 0.26, 0.02, 0.36)), 0.3, 0.045, porc, (0, 1, 0), 0.4),
               ck.blade(P + "body_fin_gold" + tag, root + V((sx * 0.03, 0, 0.0)), root + V((sx * 0.21, 0.02, 0.27)), 0.38, 0.03, gold, (0, 1, 0), 0.4),
               ck.ball(P + "body_fin_tear" + tag, 0.026, root + V((sx * 0.14, -0.035, 0.16)), glow, (0.8, 0.6, 1.8))]
        ck._rigid(bs._outward(pa), rig, "upper_arm" + s)
        hp = V(j["hip" + s])
        tas = [ck.box(P + "body_fauld_%d%s" % (k, tag), (0.04, 0.15 - k * 0.014, 0.11), hp + V((sx * (b["thigh"] + 0.04 + k * 0.006), 0, -0.02 - k * 0.075)),
                      t if k == 0 else porc, 0.014) for k in range(2)]
        ck._rigid(tas, rig, "thigh" + s)
    lk.limbs(ck, base, mats, P, M, "plate")


ACT3_SETS = {"pal_g50": build_tear_vigil, "pal_c50": build_clear_judgement}
