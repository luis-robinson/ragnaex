"""Conjuntos lendários do Berserker (12) e os machados deles, por construtor paramétrico (como paladin_sets.py).

Linguagem visual (original): bárbaro — pele, chifres, tiras de couro, troféus de osso e marcas de sangue.
Machados Gêmeos (carniceiro, couro): leve e veloz, capuz de pele, tiras cruzadas, saiote de couro, dois machados.
Executor (placa): pesado, tanque de apoio, elmo fechado com chifres, ombreira gigante, machado de duas mãos.
Punhos de Fúria (couro): monge da fúria — faixa/coque, tiara, capuz de tigre, coroa de contas, elmo de dragão, coroa de ouro;
colar de contas, faixa larga com pontas, ombreira de um lado, ataduras e sandálias (MONK_SETS, build_monk); garras (MONK_CLAWS, build_claw).
Peças: arm_<estilo>_<head|body|gloves|boots>_*; armas: wpn_main_<axe|axe2h|claw>_<estilo> e wpn_off_<axe|claw>_<estilo>.
"""
import math
from mathutils import Vector

# helm: hood | cap | horned | great ; horns: none | small | big | ram | crown ; ears = orelhas de lobo no capuz
# mask: skull (máscara de osso) | none ; fur: cor da pele (brown | white | black | red) ; chest: straps | plate
# pauldron: fur | spiked | skull | big_left ; kilt: nº de tiras do saiote ; glow: olhos/runas acesas (cor) ou None
BER_SETS = {
    # ---- Machados Gêmeos (couro, veloz) ----
    "ber_g5": {"helm": "hood", "ears": True, "horns": "none", "fur": "brown", "chest": "straps", "pauldron": "fur", "kilt": 5, "trophy": "fang"},
    "ber_g10": {"helm": "cap", "horns": "small", "fur": "brown", "chest": "straps", "pauldron": "fur", "kilt": 5, "trophy": "fang"},
    "ber_g15": {"helm": "hood", "ears": True, "horns": "none", "fur": "black", "chest": "straps", "pauldron": "skull", "kilt": 6, "trophy": "bone",
                "sash": True},
    "ber_g20": {"helm": "hood", "horns": "small", "fur": "black", "chest": "straps", "pauldron": "spiked", "kilt": 6, "trophy": "bone",
                "sash": True, "glow": (1.0, 0.25, 0.2)},
    "ber_g25": {"helm": "cap", "horns": "big", "fur": "red", "chest": "straps", "pauldron": "spiked", "kilt": 7, "trophy": "skull", "sash": True},
    "ber_g30": {"helm": "hood", "horns": "ram", "mask": "skull", "fur": "black", "chest": "straps", "pauldron": "skull", "kilt": 7, "trophy": "skull",
                "sash": True, "glow": (1.0, 0.2, 0.15)},
    # ---- Executor (placa, tanque de apoio) ----
    "ber_e5": {"helm": "great", "horns": "none", "fur": "brown", "chest": "plate", "pauldron": "big_left", "kilt": 4, "trophy": "none"},
    "ber_e10": {"helm": "horned", "horns": "big", "fur": "brown", "chest": "plate", "pauldron": "spiked", "kilt": 4, "trophy": "none"},
    "ber_e15": {"helm": "great", "horns": "small", "fur": "black", "chest": "plate", "pauldron": "skull", "kilt": 5, "trophy": "skull"},
    "ber_e20": {"helm": "horned", "horns": "ram", "fur": "white", "chest": "plate", "pauldron": "big_left", "kilt": 5, "trophy": "fang",
                "glow": (0.55, 0.85, 1.0)},
    "ber_e25": {"helm": "great", "horns": "big", "fur": "black", "chest": "plate", "pauldron": "spiked", "kilt": 5, "trophy": "skull",
                "glow": (1.0, 0.3, 0.15)},
    "ber_e30": {"helm": "great", "horns": "crown", "fur": "red", "chest": "plate", "pauldron": "big_left", "kilt": 6, "trophy": "skull",
                "glow": (1.0, 0.55, 0.15), "sash": True},
}
FUR = {"brown": (0.36, 0.24, 0.15), "white": (0.86, 0.85, 0.82), "black": (0.12, 0.1, 0.11), "red": (0.5, 0.12, 0.1)}
BONE = (0.92, 0.88, 0.76)


def _fur_ring(ck, P, name, c, r, n, size, material, z_jitter=0.02):
    """Gola de pele: tufos irregulares em anel."""
    out = []
    for k in range(n):
        a = math.tau * k / n
        jit = ((k * 37) % 7) / 7.0
        p = Vector(c) + Vector((math.cos(a) * r, math.sin(a) * r * 0.85, (jit - 0.5) * z_jitter))
        out.append(ck.ball(P + "%s_%d" % (name, k), size * (0.85 + jit * 0.35), p, material, (1.0, 1.0, 0.75)))
    return out


def _horns(ck, P, c, r, kind, material):
    V = Vector
    out = []
    if kind == "none":
        return out
    for sx in (-1, 1):
        if kind == "small":
            p0, p1 = c + V((sx * r * 0.8, -r * 0.1, r * 0.6)), c + V((sx * r * 1.05, -r * 0.25, r * 1.15))
            out.append(ck.tube(P + "head_horn_%d" % sx, p0, p1, 0.07, 0.008, material, 10))
        elif kind == "big":
            pts = [c + V((sx * r * 0.85, -r * 0.05, r * 0.45)), c + V((sx * r * 1.45, -r * 0.15, r * 0.7)),
                   c + V((sx * r * 1.75, -r * 0.3, r * 1.25)), c + V((sx * r * 1.7, -r * 0.45, r * 1.75))]
            for i in range(3):
                out.append(ck.tube(P + "head_horn_%d_%d" % (sx, i), pts[i], pts[i + 1], 0.1 - i * 0.03, 0.07 - i * 0.03 if i < 2 else 0.006, material, 10))
        elif kind == "ram":            # chifre enrolado para baixo, junto à cabeça
            prev = c + V((sx * r * 0.8, r * 0.1, r * 0.55))
            for i in range(1, 9):
                a = i * 0.7
                p = c + V((sx * r * (1.05 + 0.2 * math.sin(a * 0.5)), r * (0.1 - 0.35 * math.sin(a)), r * (0.55 + 0.4 * math.cos(a))))
                w = 0.1 * (1.0 - i / 10.0)
                out.append(ck.tube(P + "head_ram_%d_%d" % (sx, i), prev, p, w + 0.012, w, material, 10))
                prev = p
        elif kind == "crown":          # chifres que sobem em coroa
            for k in range(3):
                off = (k - 1) * 0.35
                p0 = c + V((sx * r * (0.55 + abs(off) * 0.4), -r * off * 0.6, r * 0.75))
                p1 = c + V((sx * r * (0.75 + abs(off) * 0.5), -r * off * 0.9, r * (1.55 - abs(off) * 0.4)))
                out.append(ck.tube(P + "head_crown_%d_%d" % (sx, k), p0, p1, 0.065, 0.006, material, 10))
    return out


def build(ck, base, mats, style, cfg):
    V = Vector
    rig, body, b, j = base["rig"], base["body"], base["b"], base["j"]
    t, t2, gold, wh, dark = mats["tint"], mats["tint2"], mats["trim"], mats["white"], mats["dark"]
    fur = ck.mat("m_ber_fur_" + cfg["fur"], FUR[cfg["fur"]], 0.95)
    bone = ck.mat("m_ber_bone", BONE, 0.7)
    leather = mats["leather"]
    metal = mats["metal"]
    heavy = cfg["chest"] == "plate"
    P = "arm_%s_" % style
    c = V(base["head_c"])
    r = b["head"]
    glow = ck.mat("m_ber_glow_%d" % int(sum(cfg["glow"]) * 100), cfg["glow"], 0.3, 3.0) if cfg.get("glow") else None
    # ---------------- cabeça ----------------
    helm = cfg["helm"]
    head = []
    if helm == "hood":           # capuz de pele que cobre a nuca, com borda de pele na testa
        head.append(ck._shell(P + "head_hood", c, r * 1.16, 0.28, -0.85, -0.42, 0.04, t))
        head += _fur_ring(ck, P, "head_fur", c + V((0, 0, r * 0.32)), r * 1.12, 14, r * 0.2, fur)
        if cfg.get("ears"):
            for sx in (-1, 1):
                head.append(ck.blade(P + "head_ear_%d" % sx, c + V((sx * r * 0.55, r * 0.1, r * 0.8)), c + V((sx * r * 0.85, r * 0.2, r * 1.5)),
                                     r * 0.5, 0.06, t, (1, 0, 0)))
    elif helm == "cap":          # gorro de couro com faixa de metal
        head += [ck._shell(P + "head_cap", c, r * 1.15, 0.38, -0.3, -0.05, 0.035, t),
                 ck.tube(P + "head_band", c + V((0, 0, r * 0.3)), c + V((0, 0, r * 0.44)), r * 1.2, r * 1.18, metal, 24)]
    elif helm == "horned":       # elmo aberto com protetor de nariz e bochechas
        head += [ck._shell(P + "head_helm", c, r * 1.16, 0.18, -0.6, -0.3, 0.035, t),
                 ck.box(P + "head_nasal", (0.06, 0.05, r * 0.6), c + V((0, -r * 1.14, -r * 0.05)), metal, 0.012),
                 ck.tube(P + "head_band", c + V((0, 0, r * 0.18)), c + V((0, 0, r * 0.32)), r * 1.24, r * 1.21, metal, 24)]
        for sx in (-1, 1):
            head.append(ck.box(P + "head_cheek_%d" % sx, (0.06, r * 0.5, r * 0.6), c + V((sx * r * 0.95, -r * 0.45, -r * 0.35)), t, 0.02))
    elif helm == "great":        # elmo fechado: fenda dos olhos, rebites, testa saliente
        head += [ck._shell(P + "head_helm", c, r * 1.16, -0.75, -0.62, -0.5, 0.04, t),
                 ck.ball(P + "head_face", r * 0.84, c + V((0, -r * 0.82, -r * 0.12)), t, (1.1, 0.48, 1.0)),
                 ck.box(P + "head_slit", (r * 1.2, 0.08, r * 0.13), c + V((0, -r * 1.24, r * 0.02)), dark, 0.02),
                 ck.box(P + "head_brow", (r * 1.45, 0.1, r * 0.16), c + V((0, -r * 1.2, r * 0.2)), metal, 0.03)]
        for k in range(4):
            head.append(ck.ball(P + "head_rivet_%d" % k, 0.028, c + V(((k - 1.5) * r * 0.32, -r * 1.27, r * 0.2)), gold))
        if glow:
            for sx in (-1, 1):
                head.append(ck.ball(P + "head_eye_%d" % sx, r * 0.07, c + V((sx * r * 0.3, -r * 1.27, r * 0.02)), glow, (1.4, 0.6, 0.7)))
    if cfg.get("mask") == "skull":   # máscara de osso sobre o rosto (olhos acesos)
        head += [ck.ball(P + "head_skull", r * 0.66, c + V((0, -r * 0.92, -r * 0.05)), bone, (1.05, 0.5, 1.05)),
                 ck.box(P + "head_skull_jaw", (r * 0.7, 0.06, r * 0.28), c + V((0, -r * 1.12, -r * 0.55)), bone, 0.02)]
        for sx in (-1, 1):
            head.append(ck.ball(P + "head_skull_eye_%d" % sx, r * 0.15, c + V((sx * r * 0.27, -r * 1.22, r * 0.02)), glow or dark, (1.1, 0.4, 1.0)))
    head += _horns(ck, P, c, r, cfg["horns"], bone if cfg["horns"] in ("ram", "crown") or not heavy else gold)
    ck._rigid(head, rig, "head")
    # ---------------- corpo ----------------
    ck.armor_piece(body, rig, P + "body_main", "torso", t if heavy else leather, 0.016 if heavy else 0.01, 0.016, 0.04 if heavy else 0.02)
    ck.armor_piece(body, rig, P + "body_legs", "legs", dark if heavy else leather, 0.008, 0.012)
    d = b["depth"]
    front = -b["chest"] * d - 0.035
    zc = ck.Z["chest"]
    chest = _fur_ring(ck, P, "body_mantle", (0, 0, ck.Z["neck"] - 0.06), b["chest"] * 0.68, 16, 0.075 if heavy else 0.065, fur)
    if heavy:                    # couraça: placa do peito, cinta de placas da barriga, rebites
        chest += [ck.ball(P + "body_breast", 0.17, (0, front + 0.045, zc + 0.01), t, (1.25, 0.42, 1.0)),
                  ck.box(P + "body_breast_rim", (0.32, 0.03, 0.035), (0, front - 0.005, zc - 0.11), metal, 0.008)]
        for k in range(2):
            chest.append(ck.box(P + "body_lame_%d" % k, (0.27 - k * 0.03, 0.035, 0.05), (0, -b["waist"] * d * 1.12 - 0.02, ck.Z["waist"] + 0.07 - k * 0.055),
                                t if k == 0 else metal, 0.012))
        for sx in (-1, 1):
            chest.append(ck.ball(P + "body_rivet_%d" % sx, 0.022, (sx * 0.11, front - 0.025, zc + 0.08), gold))
    else:                        # tiras cruzadas de couro com fivela de metal no meio
        for sx in (-1, 1):
            chest.append(ck.tube(P + "body_strap_%d" % sx, (sx * 0.15, front + 0.03, zc + 0.14), (-sx * 0.13, -b["waist"] * d - 0.03, ck.Z["waist"] + 0.02),
                                 0.022, 0.022, dark, 6))
        chest.append(ck.ball(P + "body_buckle", 0.035, (0, front - 0.01, zc - 0.03), metal, (1, 0.5, 1)))
    if glow and heavy:           # runa acesa no peito
        chest.append(ck.ball(P + "body_rune", 0.03, (0, front - 0.02, zc + 0.02), glow, (1, 0.4, 1.4)))
    tr = cfg["trophy"]
    if tr == "fang":             # colar de presas
        for k in range(5):
            a = math.pi * (0.25 + 0.5 * k / 4.0) + math.pi
            p = V((math.cos(a) * 0.13, math.sin(a) * 0.13 * d, ck.Z["neck"] - 0.13))
            chest.append(ck.tube(P + "body_fang_%d" % k, p, p + V((0, -0.01, -0.07)), 0.018, 0.003, bone, 6))
    elif tr == "bone":           # ossos cruzados nas costas
        back = b["chest"] * d + 0.04
        for sx in (-1, 1):
            chest.append(ck.tube(P + "body_bone_%d" % sx, (sx * 0.12, back, zc + 0.12), (-sx * 0.12, back, zc - 0.1), 0.02, 0.02, bone, 6))
    elif tr == "skull":          # caveira no peito
        chest += [ck.ball(P + "body_skull", 0.055, (0, front - 0.02, zc + 0.03), bone, (1, 0.7, 1.05)),
                  ck.ball(P + "body_skull_eye_l", 0.014, (-0.02, front - 0.06, zc + 0.04), glow or dark),
                  ck.ball(P + "body_skull_eye_r", 0.014, (0.02, front - 0.06, zc + 0.04), glow or dark)]
    ck._rigid(chest, rig, "chest")
    belt = ck.tube(P + "body_belt", (0, 0, ck.Z["waist"] - 0.04), (0, 0, ck.Z["waist"] + 0.035), b["waist"] * 1.18, b["waist"] * 1.18, leather, 16)
    for v in belt.data.vertices:
        v.co.y *= d * 1.05
    ck._smooth(belt.data)
    ck.transfer_weights(belt, body, rig)
    hips = [ck.ball(P + "body_belt_skull", 0.05, (0, -b["waist"] * d * 1.2 - 0.02, ck.Z["waist"]), bone if tr != "none" else metal, (1, 0.6, 1))]
    n = cfg["kilt"]              # saiote de tiras (frente e trás; dos lados as pernas passam)
    for k in range(n):
        x = (k - (n - 1) / 2.0) * 0.06
        L = 0.15 + ((k * 13) % 5) * 0.012
        for side, y in (("f", -b["waist"] * d * 1.18 - 0.012), ("b", b["waist"] * d * 1.18 + 0.012)):
            hips.append(ck.box(P + "body_kilt_%s%d" % (side, k), (0.05, 0.014, L), (x, y, ck.Z["waist"] - 0.035 - L * 0.5),
                               (t if heavy else leather) if k % 2 == 0 else (metal if heavy else t), 0.005))
    if cfg.get("sash"):          # faixa de pano caindo na frente (cor de destaque)
        hips.append(ck.box(P + "body_sash", (0.07, 0.016, 0.26), (0.06, -b["waist"] * d * 1.18 - 0.03, ck.Z["waist"] - 0.13), t2, 0.005))
    ck._rigid(hips, rig, "hips")
    for s, sx in ((".R", -1), (".L", 1)):
        tag = s.replace(".", "_")
        sh = V(j["shoulder" + s])
        pa = []
        pk = cfg["pauldron"]
        big = pk == "big_left" and s == ".L"
        if pk == "fur" or (pk == "big_left" and not big):
            pa += _fur_ring(ck, P, "body_pfur" + tag, sh + V((sx * 0.06, 0, 0.06)), 0.05, 6, 0.07, fur)
            if pk == "big_left":
                pa.append(ck.ball(P + "body_pauldron" + tag, b["arm"] * 2.2, sh + V((sx * 0.05, 0, 0.04)), t, (1.1, 1.05, 0.6)))
        if pk in ("spiked", "skull") or big:
            scale = 3.3 if big else 2.7
            pa += [ck.ball(P + "body_pauldron" + tag, b["arm"] * scale, sh + V((sx * (0.07 if big else 0.06), 0, 0.06)), t, (1.15, 1.1, 0.68)),
                   ck.ball(P + "body_pauldron_rim" + tag, b["arm"] * scale * 1.03, sh + V((sx * 0.065, 0, 0.03)), metal, (1.17, 1.12, 0.18))]
            top = sh + V((sx * 0.09, 0, 0.14 if big else 0.12))
            if pk == "spiked" or big:
                for k in range(3 if big else 2):
                    off = (k - (1 if big else 0.5)) * 0.08
                    pa.append(ck.tube(P + "body_pspike_%d%s" % (k, tag), top + V((0, off, -0.02)), top + V((sx * 0.07, off * 1.3, 0.16 if big else 0.12)),
                                      0.035, 0.004, bone if not heavy else metal, 8))
            if pk == "skull":
                pa += [ck.ball(P + "body_pskull" + tag, 0.065, top + V((sx * 0.03, -0.02, 0.0)), bone, (1, 0.9, 1.05)),
                       ck.ball(P + "body_pskull_eye" + tag, 0.016, top + V((sx * 0.03, -0.075, 0.01)), glow or dark)]
        ck._rigid(pa, rig, "upper_arm" + s)
    # ---------------- braços ----------------
    for s, sx in ((".R", -1), (".L", 1)):
        tag = s.replace(".", "_")
        el, wr = V(j["elbow" + s]), V(j["wrist" + s])
        if heavy:                # manopla de placa com cravos
            g = [ck.tube(P + "gloves_cuff" + tag, el.lerp(wr, 0.2), wr + V((0, 0, 0.01)), 0.08, 0.11, t, 12),
                 ck.tube(P + "gloves_rim" + tag, wr + V((0, 0, 0.005)), wr + V((0, 0, 0.03)), 0.115, 0.115, metal, 12)]
            for k in range(2):
                p = el.lerp(wr, 0.35 + k * 0.3) + V((sx * 0.09, 0, 0))
                g.append(ck.tube(P + "gloves_spike_%d" % k + tag, p, p + V((sx * 0.07, 0, 0.02)), 0.025, 0.003, metal, 6))
        else:                    # faixas de couro enroladas no antebraço
            g = [ck.tube(P + "gloves_wrap_%d" % k + tag, el.lerp(wr, 0.15 + k * 0.22), el.lerp(wr, 0.27 + k * 0.22), 0.074, 0.07, leather if k % 2 else t, 10)
                 for k in range(4)]
            g.append(ck.tube(P + "gloves_fur" + tag, wr + V((0, 0, 0.0)), wr + V((0, 0, 0.035)), 0.09, 0.085, fur, 10))
        ck._rigid(g, rig, "forearm" + s)
        fist = ck.ball(P + "gloves_fist" + tag, b["hand"] * (1.45 if heavy else 1.3), ck.hand_center(base, s), t if heavy else leather, (1, 1, 1.1))
        ck._rigid([fist], rig, "hand" + s)
    # ---------------- botas ----------------
    ck.armor_piece(body, rig, P + "boots_shell", "boots", t if heavy else leather, 0.026, 0.016)
    for s, sx in ((".R", -1), (".L", 1)):
        tag = s.replace(".", "_")
        kn, an = V(j["knee" + s]), V(j["ankle" + s])
        k = _fur_ring(ck, P, "boots_fur" + tag, an + V((0, 0, 0.1)), 0.075, 7, 0.05, fur)
        if heavy:
            k += [ck.ball(P + "boots_knee" + tag, 0.08, kn + V((0, -0.075, 0.01)), t, (1.05, 0.7, 1.0)),
                  ck.tube(P + "boots_knee_spike" + tag, kn + V((0, -0.12, 0.02)), kn + V((0, -0.2, 0.07)), 0.03, 0.004, metal, 8)]
        else:
            k.append(ck.tube(P + "boots_wrap" + tag, kn + V((0, 0, -0.03)), kn + V((0, 0, 0.0)), 0.07, 0.07, dark, 10))
        ck._rigid(k, rig, "shin" + s)


# ---------------------------------------------------------------------------
# Machados (formas em axe_kit.HEADS). head: bearded | crescent | cleaver | double | fang ; motivos: spike (ponta no topo), back (cravo atrás),
# fur (pele no cabo), skull (no colar), gem, glow (fio aceso: a COR do brilho, própria de cada conjunto e tirada da paleta
# dele em GearCatalog.SET_VISUALS; emissão em axe_kit.EDGE_GLOW_ENERGY), dark (lâmina escura)
AXE_GLOW = {
    "ber_g20": (0.10, 0.01, 0.24),     # Ceifador Veloz (conjunto cinza-violeta): violeta escuro
    "ber_g30": (0.85, 0.03, 0.03),     # Senhor da Carnificina (vermelho-sangue escuro): sangue
    "ber_e20": (0.14, 0.50, 0.95),     # Gigante do Inverno (azul-gelo): gelo
    "ber_e30": (0.95, 0.26, 0.02),     # Titã Escarlate (escarlate, runas âmbar): ouro em brasa
}
BER_AXES = {
    "ber_g5": {"type": "axe", "head": "bearded", "fur": True},
    "ber_g10": {"type": "axe", "head": "bearded", "back": True},
    "ber_g15": {"type": "axe", "head": "fang", "skull": True},
    "ber_g20": {"type": "axe", "head": "crescent", "dark": True, "glow": AXE_GLOW["ber_g20"]},
    "ber_g25": {"type": "axe", "head": "fang", "back": True, "gem": True},
    "ber_g30": {"type": "axe", "head": "crescent", "dark": True, "glow": AXE_GLOW["ber_g30"], "skull": True, "spike": True},
    "ber_e5": {"type": "axe2h", "head": "bearded", "fur": True},
    "ber_e10": {"type": "axe2h", "head": "double", "spike": True},
    "ber_e15": {"type": "axe2h", "head": "cleaver", "skull": True, "back": True},
    "ber_e20": {"type": "axe2h", "head": "crescent", "glow": AXE_GLOW["ber_e20"], "fur": True},
    "ber_e25": {"type": "axe2h", "head": "double", "dark": True, "spike": True, "gem": True},
    "ber_e30": {"type": "axe2h", "head": "double", "glow": AXE_GLOW["ber_e30"], "skull": True, "spike": True, "gem": True},
}
def build_axe(ck, base, mats, style, cfg, hand):
    """Machado do conjunto na mão (main = direita, off = esquerda), 1 malha. A forma vem de axe_kit (cabeça em leque, face
    fina de aço escuro, bisel claro, olho na cor do item, talas no cabo)."""
    import axe_kit
    name = ("wpn_main_%s_%s" % (cfg["type"], style)) if hand == "main" else ("wpn_off_axe_%s" % style)
    return axe_kit.build(ck, base, mats, name, cfg, hand, cfg["type"] == "axe2h")


# ---------------------------------------------------------------------------
# Punhos de Fúria (couro, monge da fúria): o que se lê de cima é a CABEÇA (faixa com coque, tiara de bronze, capuz de
# tigre, coroa de contas, elmo de dragão, coroa de ouro), o COLAR DE CONTAS no peito, a FAIXA LARGA na cintura com duas
# pontas caindo na frente, a ombreira de UM lado só (esquerdo) e as ataduras nos antebraços e canelas, sandálias.
# head: band | tiara | tiger | lotus | dragon | crown ; beads: contas do colar ; sash: cor da faixa (tint2 | red | stripe)
# guard: ombreira (cloth | bronze | pelt | lotus | iron | gold) ; bracer: braçadeira por cima da atadura (None | bronze | iron | gold)
MONK_SETS = {
    "ber_m5": {"head": "band", "beads": 10, "sash": "tint2", "guard": "cloth", "bracer": None},
    "ber_m10": {"head": "tiara", "beads": 12, "sash": "tint2", "guard": "bronze", "bracer": "bronze"},
    "ber_m15": {"head": "tiger", "beads": 12, "sash": "stripe", "guard": "pelt", "bracer": None},
    "ber_m20": {"head": "lotus", "beads": 14, "sash": "red", "guard": "lotus", "bracer": "bronze", "emblem": True},
    "ber_m25": {"head": "dragon", "beads": 14, "sash": "tint2", "guard": "iron", "bracer": "iron", "glow": (1.0, 0.35, 0.15)},
    "ber_m30": {"head": "crown", "beads": 18, "big_beads": True, "sash": "red", "guard": "gold", "bracer": "gold", "emblem": True,
                "glow": (1.0, 0.8, 0.3)},
}
MONK_COL = {"bronze": (0.72, 0.45, 0.2), "iron": (0.34, 0.35, 0.4), "red": (0.62, 0.12, 0.1), "bead": (0.42, 0.24, 0.14),
            "tiger": (0.9, 0.55, 0.16), "stripe": (0.12, 0.09, 0.08), "cloth": (0.88, 0.84, 0.74), "lotus": (0.95, 0.55, 0.7), "straw": (0.86, 0.72, 0.42)}


def _outward(objs):
    """Normais para fora (tubo/lâmina espelhados saem com a face virada e somem no toon, que corta a face de trás)."""
    import bmesh
    for o in objs:
        bm = bmesh.new()
        bm.from_mesh(o.data)
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
        bm.to_mesh(o.data)
        bm.free()
    return objs


def build_monk(ck, base, mats, style, cfg):
    import bpy
    V = Vector
    rig, body, b, j = base["rig"], base["body"], base["b"], base["j"]
    t, t2, gold, dark, leather, metal = mats["tint"], mats["tint2"], mats["trim"], mats["dark"], mats["leather"], mats["metal"]
    cloth = ck.mat("m_monk_cloth", MONK_COL["cloth"], 0.9)
    bronze = ck.mat("m_monk_bronze", MONK_COL["bronze"], 0.35)
    iron = ck.mat("m_monk_iron", MONK_COL["iron"], 0.4)
    red = ck.mat("m_monk_red", MONK_COL["red"], 0.8)
    bead = ck.mat("m_monk_bead", MONK_COL["bead"], 0.5)
    glow = ck.mat("m_monk_glow_%d" % int(sum(cfg["glow"]) * 100), cfg["glow"], 0.3, 3.0) if cfg.get("glow") else None
    hair = bpy.data.materials.get("hair") or t
    metal_of = {"bronze": bronze, "iron": iron, "gold": gold}
    P = "arm_%s_" % style
    c = V(base["head_c"])
    r = b["head"]
    hk = cfg["head"]
    # ---------------- cabeça ----------------
    head = []
    if hk in ("band", "tiara", "crown"):     # cabelo preso à mostra (cor da classe) com coque no alto (a Lótus usa chapéu)
        head += [ck._shell(P + "head_hair", c + V((0, r * 0.04, r * 0.02)), r * 1.07, 0.25, -0.8, -0.25, 0.04, hair),
                 ck.ball(P + "head_topknot", r * 0.32, c + V((0, r * 0.25, r * 1.18)), hair, (1, 1, 0.9))]
        knot_ring = ck.tube(P + "head_knot_ring", c + V((0, r * 0.25, r * 1.0)), c + V((0, r * 0.25, r * 1.08)), r * 0.3, r * 0.3,
                            gold if hk in ("lotus", "crown") else t2, 12)
        head.append(knot_ring)
    if hk == "band":                     # faixa de pano na testa, nó atrás com duas pontas compridas
        head += [ck.tube(P + "head_band", c + V((0, 0, r * 0.3)), c + V((0, 0, r * 0.48)), r * 1.12, r * 1.11, t2, 24),
                 ck.ball(P + "head_knot", r * 0.15, c + V((0, r * 1.1, r * 0.4)), t2)]
        for sx in (-1, 1):
            head.append(ck.blade(P + "head_tail_%d" % sx, c + V((sx * r * 0.06, r * 1.12, r * 0.38)), c + V((sx * r * 0.35, r * 1.7, -r * 0.35)),
                                 r * 0.22, 0.015, t2, (1, 0, 0), 0.3))
    if hk == "tiara":                    # tiara de bronze com placa na testa
        head += [ck.tube(P + "head_tiara", c + V((0, 0, r * 0.34)), c + V((0, 0, r * 0.46)), r * 1.13, r * 1.12, bronze, 24),
                 ck.box(P + "head_tiara_plate", (r * 0.42, 0.04, r * 0.32), c + V((0, -r * 1.13, r * 0.48)), bronze, 0.01),
                 ck.ball(P + "head_tiara_gem", r * 0.09, c + V((0, -r * 1.17, r * 0.5)), t2, (1, 0.5, 1))]
    if hk == "tiger":                    # capuz de tigre: cúpula listrada, orelhas, focinho na testa, pele nas costas
        tiger = ck.mat("m_monk_tiger", MONK_COL["tiger"], 0.9)
        stripe = ck.mat("m_monk_stripe", MONK_COL["stripe"], 0.9)
        head += [ck._shell(P + "head_hood", c + V((0, r * 0.05, 0)), r * 1.17, 0.3, -1.0, -0.45, 0.045, tiger),
                 ck.ball(P + "head_snout", r * 0.36, c + V((0, -r * 1.0, r * 0.72)), tiger, (0.75, 1.3, 0.5)),
                 ck.ball(P + "head_muzzle", r * 0.18, c + V((0, -r * 1.42, r * 0.66)), cloth, (1.0, 0.8, 0.7)),
                 ck.ball(P + "head_nose", r * 0.08, c + V((0, -r * 1.55, r * 0.72)), stripe)]
        for k in range(5):               # listras pretas por cima da cúpula, da testa para a nuca
            a = (k - 2) * 0.42
            p = c + V((math.sin(a) * r * 1.0, -math.cos(a) * r * 0.25, math.cos(a) * r * 1.13))
            head.append(ck.box(P + "head_stripe_%d" % k, (r * 0.13, r * 1.2, 0.03), p, stripe, 0.008))
        for sx in (-1, 1):
            head += [ck.ball(P + "head_ear_%d" % sx, r * 0.24, c + V((sx * r * 0.66, r * 0.05, r * 1.0)), tiger, (1, 0.55, 1)),
                     ck.ball(P + "head_ear_in_%d" % sx, r * 0.13, c + V((sx * r * 0.66, r * -0.06, r * 1.0)), cloth, (1, 0.4, 1)),
                     ck.ball(P + "head_tiger_eye_%d" % sx, r * 0.07, c + V((sx * r * 0.26, -r * 1.12, r * 0.92)), gold)]
    if hk == "lotus":                    # chapéu cônico de palha (kasa) com aba larga, lótus vermelha no topo, fitas
        lotus = ck.mat("m_monk_lotus", MONK_COL["lotus"], 0.6)
        straw = ck.mat("m_monk_straw", MONK_COL["straw"], 0.85)
        top = c + V((0, 0, r * 1.75))
        head += [ck.tube(P + "head_kasa", c + V((0, 0, r * 0.62)), top, r * 1.95, r * 0.12, straw, 20),
                 ck.tube(P + "head_kasa_rim", c + V((0, 0, r * 0.58)), c + V((0, 0, r * 0.66)), r * 1.98, r * 1.96, red, 20),
                 ck.tube(P + "head_kasa_band", c + V((0, 0, r * 1.02)), c + V((0, 0, r * 1.1)), r * 1.3, r * 1.25, red, 20)]
        for k in range(8):               # pétalas da lótus no topo, abertas
            a2 = math.tau * k / 8
            head.append(ck.ball(P + "head_petal_%d" % k, r * 0.16, top + V((math.cos(a2) * r * 0.2, math.sin(a2) * r * 0.2, r * 0.05)), red if k % 2 else lotus, (1, 0.45, 0.6)))
        head.append(ck.ball(P + "head_lotus_core", r * 0.11, top + V((0, 0, r * 0.12)), gold))
        for sx in (-1, 1):               # fitas vermelhas caindo da aba, atrás
            head.append(ck.blade(P + "head_ribbon_%d" % sx, c + V((sx * r * 0.5, r * 1.6, r * 0.6)), c + V((sx * r * 0.8, r * 2.0, -r * 0.5)),
                                 r * 0.2, 0.015, red, (1, 0, 0), 0.3))
    if hk == "dragon":                   # elmo de ferro: cúpula, aletas de dragão nos lados, chifres, olhos acesos
        head += [ck._shell(P + "head_dome", c, r * 1.15, 0.2, 0.05, 0.12, 0.035, iron),
                 ck.tube(P + "head_rim", c + V((0, 0, r * 0.14)), c + V((0, 0, r * 0.28)), r * 1.19, r * 1.17, t, 24),
                 ck.box(P + "head_ridge", (0.05, r * 2.1, 0.06), c + V((0, 0, r * 1.12)), gold, 0.01)]
        head.append(ck._shell(P + "head_neck", c + V((0, r * 0.06, -r * 0.08)), r * 1.12, 0.5, -0.75, -0.45, 0.03, t))     # pano sob o elmo (nuca)
        for sx in (-1, 1):
            for k in range(3):               # aletas de dragão (cones: os dois lados iguais)
                head.append(ck.tube(P + "head_fin_%d_%d" % (sx, k), c + V((sx * r * 1.0, r * (0.0 + k * 0.32), r * (0.4 - k * 0.12))),
                                    c + V((sx * r * 2.0, r * (0.25 + k * 0.3), r * (0.9 - k * 0.25))), r * 0.17, 0.004, t if k % 2 else iron, 6))
            head += [ck.tube(P + "head_horn_%d" % sx, c + V((sx * r * 0.45, -r * 0.6, r * 0.95)), c + V((sx * r * 0.7, -r * 0.3, r * 1.6)), 0.06, 0.006, gold, 8),
                     ck.ball(P + "head_eye_%d" % sx, r * 0.14, c + V((sx * r * 0.3, -r * 1.16, r * 0.1)), glow or dark, (1.1, 0.4, 0.8))]
    if hk == "crown":                    # coroa de ouro alta com pontas e gema acesa
        head.append(ck.tube(P + "head_crown", c + V((0, 0, r * 0.32)), c + V((0, 0, r * 0.5)), r * 1.14, r * 1.13, gold, 24))
        for k in range(9):
            a = math.tau * k / 9
            p = c + V((math.cos(a) * r * 1.12, math.sin(a) * r * 1.12, r * 0.48))
            head.append(ck.tube(P + "head_crown_%d" % k, p, p + V((math.cos(a) * r * 0.06, math.sin(a) * r * 0.06, r * (0.42 if k % 2 == 0 else 0.26))), 0.05, 0.004, gold, 6))
        head.append(ck.ball(P + "head_gem", r * 0.12, c + V((0, -r * 1.15, r * 0.42)), glow or t2, (1, 0.5, 1.2)))
    ck._rigid(_outward(head), rig, "head")
    # ---------------- corpo ----------------
    ck.armor_piece(body, rig, P + "body_vest", "torso", t, 0.012, 0.016, 0.02)
    ck.armor_piece(body, rig, P + "body_legs", "legs", cloth if hk in ("band", "tiger") else dark, 0.008, 0.012)
    d = b["depth"]
    front = -b["chest"] * d - 0.035
    back = b["chest"] * d + 0.035
    zc, zn, zw = ck.Z["chest"], ck.Z["neck"], ck.Z["waist"]
    chest = []
    # gola cruzada do gibão (pano claro em V na frente)
    for sx in (-1, 1):
        chest.append(ck.tube(P + "body_lapel_%d" % sx, (sx * 0.13, front + 0.01, zn - 0.04), (-sx * 0.04, front - 0.005, zc - 0.12), 0.026, 0.026, cloth, 6))
    # colar de contas (rosário) em volta do pescoço, caindo em U no peito
    nb = cfg["beads"]
    br = 0.04 if cfg.get("big_beads") else 0.031
    for k in range(nb):
        a = math.pi * 2 * k / nb
        drop = 0.5 * (1 + math.cos(a))           # frente (a = 0) cai mais
        p = V((math.sin(a) * b["chest"] * 0.62, -math.cos(a) * b["chest"] * d * 0.7, zn - 0.03 - drop * 0.12))
        if math.cos(a) > 0:
            p.y = front - 0.022 - (1 - abs(math.sin(a))) * 0.01
        chest.append(ck.ball(P + "body_bead_%d" % k, br, p, (glow or gold) if k == 0 else bead))
    if cfg.get("emblem"):                # medalhão de lótus no peito
        lotus = ck.mat("m_monk_lotus", MONK_COL["lotus"], 0.6)
        for k in range(6):
            a = math.tau * k / 6
            chest.append(ck.ball(P + "body_lotus_%d" % k, 0.035, V((math.cos(a) * 0.04, front - 0.012, zc - 0.03 + math.sin(a) * 0.04)), lotus, (1, 0.35, 1.3)))
        chest.append(ck.ball(P + "body_lotus_core", 0.025, V((0, front - 0.02, zc - 0.03)), glow or gold))
    ck._rigid(_outward(chest), rig, "chest")
    # faixa larga na cintura com nó na frente e duas pontas caindo (lê de cima como cinta colorida)
    sk = cfg["sash"]
    sash_m = {"tint2": t2, "red": red, "stripe": ck.mat("m_monk_tiger", MONK_COL["tiger"], 0.9)}[sk]
    belt = ck.tube(P + "body_sash", (0, 0, zw - 0.06), (0, 0, zw + 0.05), b["waist"] * 1.22, b["waist"] * 1.2, sash_m, 16)
    for v in belt.data.vertices:
        v.co.y *= d * 1.05
    ck._smooth(belt.data)
    ck.transfer_weights(belt, body, rig)
    wf = -b["waist"] * d * 1.22
    hips = [ck.ball(P + "body_sash_knot", 0.05, (0.06, wf - 0.01, zw), sash_m, (1, 0.6, 1))]
    for k, sx in enumerate((0.04, 0.09)):
        hips.append(ck.blade(P + "body_sash_tail_%d" % k, (sx, wf - 0.015, zw - 0.02), (sx + 0.03 * (k * 2 - 1), wf - 0.03, zw - 0.3 - k * 0.04),
                             0.075, 0.012, sash_m, (1, 0, 0), 0.2))
    if sk == "stripe":                   # listras pretas na faixa de tigre
        stripe = ck.mat("m_monk_stripe", MONK_COL["stripe"], 0.9)
        for k in range(6):
            a = math.tau * k / 6
            hips.append(ck.box(P + "body_sash_stripe_%d" % k, (0.025, 0.03, 0.1),
                               (math.cos(a) * b["waist"] * 1.24, math.sin(a) * b["waist"] * 1.24 * d * 1.05, zw), stripe, 0.004))
    ck._rigid(_outward(hips), rig, "hips")
    # ombreira só no ombro esquerdo
    sh = V(j["shoulder.L"])
    gk = cfg["guard"]
    pa = []
    if gk == "cloth":                    # pano dobrado amarrado
        pa.append(ck.ball(P + "body_guard", b["arm"] * 2.0, sh + V((0.05, 0, 0.03)), cloth, (1.1, 1.05, 0.5)))
    elif gk == "pelt":                   # pele de tigre jogada no ombro
        tiger = ck.mat("m_monk_tiger", MONK_COL["tiger"], 0.9)
        pa += [ck.ball(P + "body_guard", b["arm"] * 2.3, sh + V((0.05, 0, 0.05)), tiger, (1.15, 1.1, 0.6)),
               ck.box(P + "body_guard_stripe", (0.03, 0.12, 0.06), sh + V((0.06, 0, 0.11)), ck.mat("m_monk_stripe", MONK_COL["stripe"], 0.9), 0.005)]
    elif gk == "lotus":                  # placas em pétala
        lotus = ck.mat("m_monk_lotus", MONK_COL["lotus"], 0.6)
        for k in range(3):
            pa.append(ck.ball(P + "body_guard_%d" % k, b["arm"] * (2.2 - k * 0.3), sh + V((0.05 + k * 0.025, 0, 0.05 - k * 0.055)), lotus if k % 2 else t, (1.1, 1.05, 0.45)))
    else:                                # metal em camadas (bronze / ferro / ouro)
        mm = metal_of[gk]
        for k in range(3):
            pa.append(ck.ball(P + "body_guard_%d" % k, b["arm"] * (2.3 - k * 0.3), sh + V((0.05 + k * 0.025, 0, 0.06 - k * 0.055)), mm if k % 2 == 0 else t, (1.1, 1.05, 0.45)))
        if gk == "gold" or glow:
            pa.append(ck.ball(P + "body_guard_gem", b["arm"] * 0.5, sh + V((0.1, -0.04, 0.09)), glow or t2))
    pa.append(ck.tube(P + "body_guard_strap", sh + V((0.03, 0, -0.08)), sh + V((0.035, 0, -0.105)), b["arm"] * 1.25, b["arm"] * 1.25, leather, 10))
    ck._rigid(_outward(pa), rig, "upper_arm.L")
    # ---------------- braços: ataduras (+ braçadeira de metal nos tiers altos) ----------------
    for s, sx in ((".R", -1), (".L", 1)):
        tag = s.replace(".", "_")
        el, wr = V(j["elbow" + s]), V(j["wrist" + s])
        g = [ck.tube(P + "gloves_wrap%s_%d" % (tag, i), el.lerp(wr, 0.12 + i * 0.2), el.lerp(wr, 0.26 + i * 0.2), 0.08, 0.082, cloth if i % 2 == 0 else t2, 10)
             for i in range(4)]
        if cfg.get("bracer"):
            bm_ = metal_of[cfg["bracer"]]
            g += [ck.tube(P + "gloves_bracer" + tag, el.lerp(wr, 0.35), wr + V((0, 0, 0.02)), 0.09, 0.095, bm_, 12),
                  ck.box(P + "gloves_bracer_plate" + tag, (0.05, 0.04, 0.12), el.lerp(wr, 0.6) + V((sx * 0.07, 0, 0)), bm_, 0.008)]
            if glow:
                g.append(ck.tube(P + "gloves_rune" + tag, el.lerp(wr, 0.55), el.lerp(wr, 0.6), 0.098, 0.098, glow, 12))
        ck._rigid(_outward(g), rig, "forearm" + s)
        ck._rigid([ck.ball(P + "gloves_fist" + tag, b["hand"] * 1.25, ck.hand_center(base, s), cloth, (1, 1, 1.1))], rig, "hand" + s)
    # ---------------- pernas: sandália + ataduras cruzadas na canela ----------------
    ck.armor_piece(body, rig, P + "boots_shell", "boots", leather, 0.012, 0.01)
    for s, sx in ((".R", -1), (".L", 1)):
        tag = s.replace(".", "_")
        kn, an = V(j["knee" + s]), V(j["ankle" + s])
        k = [ck.tube(P + "boots_wrap%s_%d" % (tag, i), an.lerp(kn, 0.08 + i * 0.2), an.lerp(kn, 0.2 + i * 0.2), 0.072, 0.072, cloth if i % 2 == 0 else t2, 10)
             for i in range(4)]
        k.append(ck.box(P + "boots_sole" + tag, (0.13, 0.22, 0.025), an + V((0, -0.05, -0.065)), leather, 0.01))
        if cfg.get("bracer") in ("iron", "gold"):
            k.append(ck.ball(P + "boots_knee" + tag, 0.06, kn + V((0, -0.06, 0.0)), metal_of[cfg["bracer"]], (1.0, 0.6, 1.1)))
        ck._rigid(_outward(k), rig, "shin" + s)


# Garras (soqueira com lâminas): plain = soqueira lisa com lâminas curtas ; beast = garras curvas ; glow = fio aceso
MONK_CLAWS = {
    "ber_m5": {"blades": 3, "len": 0.34, "curve": 0.0, "guard": "plain"},
    "ber_m10": {"blades": 3, "len": 0.38, "curve": 0.0, "guard": "bronze"},
    "ber_m15": {"blades": 3, "len": 0.44, "curve": 0.3, "guard": "plain", "beast": True},
    "ber_m20": {"blades": 3, "len": 0.42, "curve": 0.12, "guard": "gold"},
    "ber_m25": {"blades": 3, "len": 0.5, "curve": 0.35, "guard": "dark", "beast": True, "glow": (1.0, 0.35, 0.15)},
    "ber_m30": {"blades": 4, "len": 0.54, "curve": 0.3, "guard": "gold", "beast": True, "glow": (1.0, 0.8, 0.3)},
}


def claw_parts(ck, n, g, mats, cfg, guard_m=None, metal_m=None, axis=None):
    """Garra de punho (katar de três lâminas): manopla grossa por cima do punho fechado, barra nos nós dos dedos e
    lâminas LONGAS saindo dos nós para a frente (lê de cima como três riscos claros saindo da mão). Centro g = mão.
    Também desenha a garra comum do kit (cfg sem estilo). axis = pulso -> ponta da mão: as lâminas seguem a linha do
    antebraço (na pose de luta apontam para a frente, não atravessadas no corpo)."""
    V = Vector
    punch = V(axis).normalized() if axis is not None else V((0, -1, 0.22)).normalized()     # para onde o soco vai
    grip = V((0, -0.55, 0.83))
    grip = (grip - punch * grip.dot(punch)).normalized()      # fileira de nós dos dedos, perpendicular ao soco
    up = grip.cross(punch).normalized()             # costas da mão
    gm = guard_m or mats["leather"]
    mm = metal_m or mats["metal"]
    k0 = g + punch * 0.075
    parts = [ck.box(n + "guard", (0.13, 0.13, 0.2), g + punch * 0.01 + up * 0.035, gm, 0.02),            # manopla (cobre o punho)
             ck.tube(n + "cuff", g - punch * 0.09 - grip * 0.11, g - punch * 0.09 + grip * 0.11, 0.075, 0.075, gm, 10),   # punho/bracelete
             ck.tube(n + "knuckle", k0 - grip * 0.1, k0 + grip * 0.1, 0.036, 0.036, mm, 10)]
    nb = cfg.get("blades", 3)
    L = cfg.get("len", 0.34)
    cv = cfg.get("curve", 0.0)
    for i in range(nb):
        off = (i - (nb - 1) / 2) * (0.16 / max(1, nb - 1))
        root = k0 + grip * off + punch * 0.02
        mid = root + punch * L * 0.55 + up * L * cv * 0.12
        tip = root + punch * L + up * L * cv * 0.5
        parts.append(ck.blade(n + "blade%d_a" % i, root, mid, 0.06, 0.016, mm, tuple(grip), 0.15))
        parts.append(ck.blade(n + "blade%d_b" % i, mid - punch * 0.01, tip, 0.05, 0.012, mm, tuple(grip), 0.8))
    if cfg.get("glow"):
        gl = _tint_glow(ck) if cfg["glow"] == "tint" else ck.mat("m_monk_claw_glow_%d" % int(sum(cfg["glow"]) * 100), cfg["glow"], 0.3, 2.6)
        parts.append(ck.tube(n + "glow", k0 - grip * 0.1 + punch * 0.02, k0 + grip * 0.1 + punch * 0.02, 0.02, 0.02, gl, 8))
    if cfg.get("beast"):                 # cravos na manopla (garra de fera)
        for i in (-1, 0, 1):
            parts.append(ck.tube(n + "spike%d" % i, g + grip * i * 0.06 + up * 0.09, g + grip * i * 0.07 + up * 0.17 - punch * 0.03, 0.022, 0.003, mm, 6))
    return parts


def build_claw(ck, base, mats, style, cfg, hand):
    side_tag = ".R" if hand == "main" else ".L"
    g = Vector(ck.hand_center(base, side_tag))
    gk = cfg.get("guard", "plain")
    guard_m = {"plain": mats["leather"], "bronze": ck.mat("m_monk_bronze", MONK_COL["bronze"], 0.35), "gold": mats["trim"], "dark": mats["dark"]}[gk]
    metal_m = mats["dark"] if gk == "dark" else mats["metal"]
    j = base["j"]
    axis = Vector(j["hand_tip" + side_tag]) - Vector(j["wrist" + side_tag])
    parts = _outward(claw_parts(ck, "c_%s_%s_" % (style, hand), g, mats, cfg, guard_m, metal_m, axis))
    obj = ck._join(parts, ("wpn_main_claw_%s" % style) if hand == "main" else ("wpn_off_claw_%s" % style))
    ck._smooth(obj.data)
    ck.skin_rigid(obj, base["rig"], "hand" + side_tag)
    return obj


# ---------------------------------------------------------------------------
# Ato II (níveis 35/40/45 + Ápice da build): UM visual novo por build, tema guerra contra a Horda em Monte Kharzun.
# A malha é a mesma nos três níveis; o que muda é a cor do item (tint), o destaque (tint2, derivado) e o brilho: material
# "tint_glow" (fio do machado: "tint_glow_edge") recebe no jogo a cor de GearCatalog.ACT2_VISUALS[...]["glows"][nível].
#   ber_g35 Machados Gêmeos = Montador de Warg: crânio de warg na cabeça com crina tingida (crista da testa à nuca),
#           presas de javali nos DOIS ombros, pele de lobo nas costas, disco de ferro no peito.
#   ber_e35 Executor = Quebra-Hordas: elmo de balde com chifres de touro abertos e crista de ferro, gorjal alto, ombreiras
#           em três lâminas com torres de cravos, fornalha acesa no peito, estandarte de guerra nas costas (acima da cabeça).
#   ber_m35 Punhos = Tambor do Trovão: diadema de ferro com chifres curtos e rabo de cavalo alto, aro de tambores de
#           guerra nas costas (lê de cima como um arco atrás dos ombros), cinturão de campeão, manoplas de ferro enormes.
GLOW_BASE = (1.0, 0.5, 0.15)          # cor só do .glb; o jogo pinta por nível
FUR["gray"] = (0.44, 0.42, 0.42)


def _tint_glow(ck):
    return ck.mat("tint_glow", GLOW_BASE, 0.3, 2.0)


def _ribbon(ck, name, pts, wdir, widths, thick, material):
    """Faixa de pano com espessura passando pelos pontos (dobras = pontos fora da linha); largura no sentido wdir."""
    import bmesh
    w = Vector(wdir).normalized()
    pts = [Vector(p) for p in pts]
    bm = bmesh.new()
    front, backv = [], []
    for i, (p, wd) in enumerate(zip(pts, widths)):
        ax = pts[min(i + 1, len(pts) - 1)] - pts[max(i - 1, 0)]
        n = ax.cross(w).normalized() * thick * 0.5
        front.append((bm.verts.new(p - w * wd * 0.5 + n), bm.verts.new(p + w * wd * 0.5 + n)))
        backv.append((bm.verts.new(p - w * wd * 0.5 - n), bm.verts.new(p + w * wd * 0.5 - n)))
    last = len(pts) - 1
    for i in range(last):
        bm.faces.new((front[i][0], front[i][1], front[i + 1][1], front[i + 1][0]))
        bm.faces.new((backv[i][0], backv[i + 1][0], backv[i + 1][1], backv[i][1]))
        bm.faces.new((front[i][0], front[i + 1][0], backv[i + 1][0], backv[i][0]))
        bm.faces.new((front[i][1], backv[i][1], backv[i + 1][1], front[i + 1][1]))
    bm.faces.new((front[0][0], backv[0][0], backv[0][1], front[0][1]))
    bm.faces.new((front[last][0], front[last][1], backv[last][1], backv[last][0]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    return ck.mesh_from(name, bm, material)


def _tusk(ck, name, p0, p1, bend, r0, material, n=4, segs=8):
    """Presa/chifre curvo de p0 a p1, arqueado por bend, afinando até a ponta."""
    p0, p1, bend = Vector(p0), Vector(p1), Vector(bend)
    out = []
    prev = p0
    for i in range(1, n + 1):
        k = i / n
        p = p0.lerp(p1, k) + bend * math.sin(math.pi * k)
        out.append(ck.tube("%s_%d" % (name, i), prev, p, max(r0 * (1.0 - (i - 1) / n), 0.008), max(r0 * (1.0 - k), 0.004), material, segs))
        prev = p
    return out


def _belt(ck, base, name, z0, z1, k, material):
    """Cinto que acompanha o corpo (pesos do corpo)."""
    b, d = base["b"], base["b"]["depth"]
    belt = ck.tube(name, (0, 0, z0), (0, 0, z1), b["waist"] * k, b["waist"] * k, material, 16)
    for v in belt.data.vertices:
        v.co.y *= d * 1.05
    ck._smooth(belt.data)
    ck.transfer_weights(belt, base["body"], base["rig"])
    return belt


def build_warg(ck, base, mats, style):
    """ber_g35 — Montador de Warg (Machados Gêmeos, couro)."""
    V = Vector
    rig, body, b, j = base["rig"], base["body"], base["b"], base["j"]
    t, t2, dark, leather, metal = mats["tint"], mats["tint2"], mats["dark"], mats["leather"], mats["metal"]
    fur = ck.mat("m_ber_fur_gray", FUR["gray"], 0.95)
    bone = ck.mat("m_ber_bone", BONE, 0.7)
    glow = _tint_glow(ck)
    P = "arm_%s_" % style
    c, r = V(base["head_c"]), b["head"]
    # ---------------- cabeça: capuz de couro, crânio de warg por cima, crina tingida ----------------
    head = [ck._shell(P + "head_hood", c, r * 1.16, 0.3, -0.85, -0.42, 0.04, t),
            ck.ball(P + "head_skull", r * 1.0, c + V((0, -r * 0.28, r * 0.6)), bone, (1.02, 1.12, 0.74)),
            ck.ball(P + "head_snout", r * 0.36, c + V((0, -r * 1.12, r * 0.7)), bone, (0.82, 1.55, 0.55)),
            ck.ball(P + "head_nose", r * 0.11, c + V((0, -r * 1.64, r * 0.72)), dark)]
    for sx in (-1, 1):
        head += [ck.ball(P + "head_socket_%d" % sx, r * 0.15, c + V((sx * r * 0.42, -r * 0.98, r * 1.02)), glow, (1.0, 0.9, 0.6)),
                 ck.ball(P + "head_browbone_%d" % sx, r * 0.2, c + V((sx * r * 0.44, -r * 0.8, r * 1.16)), bone, (1.1, 0.9, 0.5)),
                 ck.tube(P + "head_fang_%d" % sx, c + V((sx * r * 0.2, -r * 1.5, r * 0.6)), c + V((sx * r * 0.22, -r * 1.52, r * 0.12)), 0.034, 0.004, bone, 6),
                 ck.tube(P + "head_fang2_%d" % sx, c + V((sx * r * 0.34, -r * 1.2, r * 0.56)), c + V((sx * r * 0.38, -r * 1.22, r * 0.26)), 0.026, 0.004, bone, 6)]
        head += _tusk(ck, P + "head_jaw_%d" % sx, c + V((sx * r * 1.02, -r * 0.35, -r * 0.4)), c + V((sx * r * 1.02, -r * 1.25, r * 0.12)),
                      (sx * r * 0.22, 0, -r * 0.12), 0.05, bone, 3)
    for k in range(7):                   # crina: tufos de pele com penas de cor (tint2) em leque, da testa à nuca
        a = -0.15 + k * 0.42
        root = c + V((0, math.sin(a) * r * 1.08, math.cos(a) * r * 1.08))
        outd = V((0, math.sin(a + 0.35), math.cos(a + 0.35)))
        tang = V((0, math.cos(a), -math.sin(a)))
        head.append(ck.ball(P + "head_mane_%d" % k, r * (0.3 - k * 0.012), root + outd * r * 0.1, fur, (0.6, 1.0, 1.0)))
        head.append(ck.blade(P + "head_crest_%d" % k, root, root + outd * r * (0.95 - abs(k - 2) * 0.09), r * 0.5, 0.07, t2, tuple(tang), 0.4))
    ck._rigid(_outward(head), rig, "head")
    # ---------------- corpo ----------------
    ck.armor_piece(body, rig, P + "body_main", "torso", leather, 0.01, 0.016, 0.02)
    ck.armor_piece(body, rig, P + "body_legs", "legs", leather, 0.008, 0.012)
    d = b["depth"]
    front = -b["chest"] * d - 0.035
    back = b["chest"] * d + 0.035
    zc, zn, zw = ck.Z["chest"], ck.Z["neck"], ck.Z["waist"]
    chest = _fur_ring(ck, P, "body_mantle", (0, 0, zn - 0.06), b["chest"] * 0.7, 16, 0.075, fur)
    # bandoleira larga do ombro esquerdo à cintura direita, disco de ferro com runa acesa no peito
    chest += [ck.tube(P + "body_strap_f", (0.15, front + 0.03, zc + 0.15), (-0.13, -b["waist"] * d - 0.03, zw + 0.02), 0.032, 0.032, dark, 6),
              ck.tube(P + "body_strap_b", (0.15, back - 0.03, zc + 0.15), (-0.13, b["waist"] * d + 0.03, zw + 0.02), 0.032, 0.032, dark, 6),
              ck.tube(P + "body_disc", (0, front + 0.0, zc), (0, front - 0.035, zc), 0.085, 0.075, metal, 10),
              ck.tube(P + "body_disc_rim", (0, front - 0.02, zc), (0, front - 0.04, zc), 0.058, 0.05, t, 10),
              ck.ball(P + "body_rune", 0.032, (0, front - 0.042, zc), glow, (1.0, 0.45, 1.5))]
    for k in range(5):                   # colar de presas
        a = math.pi * (0.25 + 0.5 * k / 4.0) + math.pi
        p = V((math.cos(a) * 0.14, math.sin(a) * 0.14 * d, zn - 0.13))
        chest.append(ck.tube(P + "body_fang_%d" % k, p, p + V((0, -0.01, -0.08)), 0.02, 0.003, bone, 6))
    # pele de lobo nas costas (meia capa curta, com rabo)
    chest.append(_ribbon(ck, P + "body_pelt", [(0, back + 0.02, zn - 0.04), (0, back + 0.065, zc + 0.0), (0, back + 0.05, zw + 0.03), (0, back + 0.085, zw - 0.1)],
                         (1, 0, 0), [0.36, 0.4, 0.3, 0.16], 0.035, fur))
    chest += _tusk(ck, P + "body_pelt_tail", (0, back + 0.085, zw - 0.08), (0.05, back + 0.14, zw - 0.3), (0, 0.04, 0), 0.05, fur, 3)
    for k in range(6):
        sx = -1 if k % 2 else 1
        chest.append(ck.ball(P + "body_pelt_tuft_%d" % k, 0.06, (sx * (0.19 - (k // 2) * 0.03), back + 0.055, zc + 0.08 - (k // 2) * 0.1), fur, (1, 0.7, 1)))
    ck._rigid(_outward(chest), rig, "chest")
    _belt(ck, base, P + "body_belt", zw - 0.045, zw + 0.04, 1.2, leather)
    wf = -b["waist"] * d * 1.2
    hips = [ck.box(P + "body_belt_plate_%d" % k, (0.075, 0.03, 0.085), ((k - 1) * 0.085, wf - 0.012 + abs(k - 1) * 0.012, zw), metal, 0.008) for k in range(3)]
    hips.append(ck.ball(P + "body_belt_gem", 0.026, (0, wf - 0.032, zw), glow))
    for sx in (-1, 1):                   # troféus: crânios pendurados no quadril
        p = V((sx * b["waist"] * 1.22, 0.01, zw - 0.09))
        hips += [ck.ball(P + "body_trophy_%d" % sx, 0.055, p, bone, (0.9, 1.0, 1.05)),
                 ck.ball(P + "body_trophy_eye_%d" % sx, 0.018, p + V((sx * 0.045, -0.02, 0.01)), dark)]
    n = 7
    for k in range(n):
        x = (k - (n - 1) / 2.0) * 0.06
        L = 0.17 + ((k * 13) % 5) * 0.014
        for side, y in (("f", wf - 0.004), ("b", -wf + 0.004)):
            hips.append(ck.box(P + "body_kilt_%s%d" % (side, k), (0.05, 0.014, L), (x, y, zw - 0.035 - L * 0.5), leather if k % 2 == 0 else t, 0.005))
            if k % 2 == 0:
                hips.append(ck.ball(P + "body_stud_%s%d" % (side, k), 0.017, (x, y + (-0.01 if side == "f" else 0.01), zw - 0.03 - L * 0.82), metal))
    hips.append(ck.box(P + "body_sash", (0.075, 0.016, 0.28), (0.07, wf - 0.022, zw - 0.14), t2, 0.005))
    ck._rigid(_outward(hips), rig, "hips")
    for s, sx in ((".R", -1), (".L", 1)):                 # ombros: pele + lâmina de ferro + duas presas de javali para cima
        tag = s.replace(".", "_")
        sh = V(j["shoulder" + s])
        pa = _fur_ring(ck, P, "body_pfur" + tag, sh + V((sx * 0.06, 0, 0.03)), 0.075, 7, 0.075, fur)
        pa += [ck.ball(P + "body_pauldron" + tag, b["arm"] * 2.5, sh + V((sx * 0.06, 0, 0.07)), t, (1.15, 1.1, 0.6)),
               ck.ball(P + "body_pauldron_rim" + tag, b["arm"] * 2.58, sh + V((sx * 0.065, 0, 0.04)), metal, (1.17, 1.12, 0.16))]
        for k, fy in enumerate((-1, 1)):
            p0 = sh + V((sx * 0.07, fy * 0.065, 0.1))
            pa += _tusk(ck, P + "body_tusk%d%s" % (k, tag), p0, p0 + V((sx * 0.13, fy * 0.05, 0.27)), (sx * 0.09, fy * 0.015, -0.02), 0.05, bone, 4)
        ck._rigid(_outward(pa), rig, "upper_arm" + s)
    # ---------------- braços: faixas + braçal de ferro com garras ----------------
    for s, sx in ((".R", -1), (".L", 1)):
        tag = s.replace(".", "_")
        el, wr = V(j["elbow" + s]), V(j["wrist" + s])
        g = [ck.tube(P + "gloves_wrap_%d" % k + tag, el.lerp(wr, 0.1 + k * 0.2), el.lerp(wr, 0.22 + k * 0.2), 0.074, 0.07, leather if k % 2 else t, 10) for k in range(2)]
        g += [ck.tube(P + "gloves_bracer" + tag, el.lerp(wr, 0.5), wr + V((0, 0, 0.012)), 0.082, 0.092, metal, 10),
              ck.tube(P + "gloves_fur" + tag, el.lerp(wr, 0.44), el.lerp(wr, 0.52), 0.092, 0.09, fur, 10)]
        for k in range(2):
            p = el.lerp(wr, 0.6 + k * 0.25) + V((sx * 0.08, 0, 0))
            g.append(ck.tube(P + "gloves_claw_%d" % k + tag, p, p + V((sx * 0.085, 0, 0.035)), 0.026, 0.003, bone, 6))
        ck._rigid(_outward(g), rig, "forearm" + s)
        ck._rigid([ck.ball(P + "gloves_fist" + tag, b["hand"] * 1.3, ck.hand_center(base, s), leather, (1, 1, 1.1))], rig, "hand" + s)
    # ---------------- botas ----------------
    ck.armor_piece(body, rig, P + "boots_shell", "boots", leather, 0.026, 0.016)
    for s, sx in ((".R", -1), (".L", 1)):
        tag = s.replace(".", "_")
        kn, an = V(j["knee" + s]), V(j["ankle" + s])
        k = _fur_ring(ck, P, "boots_fur" + tag, an + V((0, 0, 0.1)), 0.078, 7, 0.052, fur)
        k += [ck.tube(P + "boots_wrap" + tag, kn + V((0, 0, -0.035)), kn + V((0, 0, 0.0)), 0.072, 0.072, t, 10),
              ck.tube(P + "boots_knee_tusk" + tag, kn + V((0, -0.07, -0.01)), kn + V((0, -0.15, 0.085)), 0.032, 0.004, bone, 6)]
        ck._rigid(_outward(k), rig, "shin" + s)


def build_siege(ck, base, mats, style):
    """ber_e35 — Quebra-Hordas (Executor, placa)."""
    V = Vector
    rig, body, b, j = base["rig"], base["body"], base["b"], base["j"]
    t, t2, gold, dark, metal, wood = mats["tint"], mats["tint2"], mats["trim"], mats["dark"], mats["metal"], mats["wood"]
    fur = ck.mat("m_ber_fur_black", FUR["black"], 0.95)
    bone = ck.mat("m_ber_bone", BONE, 0.7)
    glow = _tint_glow(ck)
    P = "arm_%s_" % style
    c, r = V(base["head_c"]), b["head"]
    # ---------------- cabeça: elmo de balde, viseira em cruz acesa, chifres de touro, crista de ferro ----------------
    head = [ck._shell(P + "head_helm", c, r * 1.17, -0.75, -0.62, -0.5, 0.04, t),
            ck.ball(P + "head_face", r * 0.86, c + V((0, -r * 0.82, -r * 0.14)), t, (1.1, 0.5, 1.02)),
            ck.box(P + "head_slit", (r * 1.25, 0.08, r * 0.14), c + V((0, -r * 1.25, r * 0.04)), glow, 0.02),
            ck.box(P + "head_bar", (0.075, 0.1, r * 0.95), c + V((0, -r * 1.27, -r * 0.2)), metal, 0.02),
            ck.box(P + "head_brow", (r * 1.6, 0.11, r * 0.17), c + V((0, -r * 1.2, r * 0.24)), metal, 0.03),
            ck.tube(P + "head_rim", c + V((0, 0, -r * 0.62)), c + V((0, 0, -r * 0.5)), r * 1.12, r * 1.2, metal, 20),
            ck.box(P + "head_ridge", (0.07, r * 2.0, 0.1), c + V((0, r * 0.05, r * 1.14)), metal, 0.015)]
    for k in range(3):                   # torres da crista
        p = c + V((0, (k - 1) * r * 0.62 + r * 0.05, r * (1.17 - abs(k - 1) * 0.12)))
        head.append(ck.tube(P + "head_crest_%d" % k, p, p + V((0, (k - 1) * r * 0.12, r * (0.5 if k == 1 else 0.36))), 0.05, 0.005, metal, 6))
    for k in range(4):
        head.append(ck.ball(P + "head_rivet_%d" % k, 0.03, c + V(((k - 1.5) * r * 0.36, -r * 1.29, r * 0.24)), gold))
    for sx in (-1, 1):
        root = c + V((sx * r * 0.98, 0, r * 0.42))
        head.append(ck.tube(P + "head_horn_ring_%d" % sx, root, root + V((sx * r * 0.2, 0, r * 0.02)), 0.125, 0.115, gold, 10))
        head += _tusk(ck, P + "head_horn_%d" % sx, root + V((sx * r * 0.15, 0, r * 0.02)), c + V((sx * r * 2.2, -r * 0.3, r * 1.25)),
                      (sx * r * 0.3, 0, -r * 0.42), 0.105, bone, 5, 10)
        head += _tusk(ck, P + "head_jaw_%d" % sx, c + V((sx * r * 0.5, -r * 1.18, -r * 0.6)), c + V((sx * r * 0.66, -r * 1.5, -r * 0.02)),
                      (0, -r * 0.1, -r * 0.05), 0.05, bone, 3)
    ck._rigid(_outward(head), rig, "head")
    # ---------------- corpo ----------------
    ck.armor_piece(body, rig, P + "body_main", "torso", t, 0.018, 0.016, 0.04)
    ck.armor_piece(body, rig, P + "body_legs", "legs", dark, 0.008, 0.012)
    d = b["depth"]
    front = -b["chest"] * d - 0.035
    back = b["chest"] * d + 0.035
    zc, zn, zw = ck.Z["chest"], ck.Z["neck"], ck.Z["waist"]
    chest = _fur_ring(ck, P, "body_mantle", (0, 0, zn - 0.085), b["chest"] * 0.76, 14, 0.062, fur)
    gorget = ck.tube(P + "body_gorget", (0, 0, zn - 0.055), (0, 0, zn + 0.085), b["chest"] * 0.78, b["chest"] * 0.6, metal, 14)
    gorget_rim = ck.tube(P + "body_gorget_rim", (0, 0, zn + 0.07), (0, 0, zn + 0.1), b["chest"] * 0.64, b["chest"] * 0.62, t, 14)
    for o in (gorget, gorget_rim):
        for v in o.data.vertices:
            v.co.y *= 0.9
    chest += [gorget, gorget_rim,
              ck.ball(P + "body_breast", 0.175, (0, front + 0.045, zc + 0.01), t, (1.3, 0.42, 1.0)),
              ck.box(P + "body_furnace", (0.24, 0.035, 0.15), (0, front - 0.012, zc + 0.0), metal, 0.012),
              ck.box(P + "body_breast_rim", (0.33, 0.03, 0.035), (0, front - 0.005, zc - 0.115), metal, 0.008)]
    for k in range(3):                   # fornalha: três fendas acesas
        chest.append(ck.box(P + "body_slit_%d" % k, (0.034, 0.03, 0.105), ((k - 1) * 0.065, front - 0.024, zc + 0.0), glow, 0.006))
    for k in range(2):
        chest.append(ck.box(P + "body_lame_%d" % k, (0.28 - k * 0.03, 0.035, 0.05), (0, -b["waist"] * d * 1.12 - 0.02, zw + 0.07 - k * 0.055), t if k == 0 else metal, 0.012))
    for sx in (-1, 1):
        chest.append(ck.ball(P + "body_rivet_%d" % sx, 0.024, (sx * 0.15, front - 0.012, zc + 0.09), gold))
    # estandarte de guerra: haste inclinada para trás (passa por fora da cabeça), travessa de osso, pano dobrado em duas pontas
    hy = r * 1.32
    p0, p1 = V((0.03, back - 0.01, zc - 0.12)), V((0.05, hy + 0.1, c.z + r * 1.75))
    chest += [ck.tube(P + "body_pole", p0, p1, 0.024, 0.02, wood, 6),
              ck.tube(P + "body_pole_socket", p0 + V((0, 0.0, -0.02)), p0.lerp(p1, 0.1), 0.045, 0.04, metal, 8),
              ck.tube(P + "body_pole_bar", p1 + V((-0.2, 0, -0.03)), p1 + V((0.2, 0, -0.03)), 0.02, 0.02, bone, 6),
              ck.ball(P + "body_pole_skull", 0.062, p1 + V((0, -0.005, 0.045)), bone, (1.0, 0.95, 1.1)),
              ck.ball(P + "body_pole_eye_l", 0.018, p1 + V((-0.025, -0.055, 0.05)), glow),
              ck.ball(P + "body_pole_eye_r", 0.018, p1 + V((0.025, -0.055, 0.05)), glow)]
    for sx in (-1, 1):                   # chifres curtos na ponta da haste
        chest.append(ck.tube(P + "body_pole_horn_%d" % sx, p1 + V((sx * 0.04, 0, 0.07)), p1 + V((sx * 0.13, 0, 0.19)), 0.022, 0.003, bone, 6))
        fx = sx * 0.095                  # cada metade do pano: desce em dobras e termina em ponta
        chest.append(_ribbon(ck, P + "body_flag_%d" % sx, [p1 + V((fx, 0.012, -0.035)), p1 + V((fx, 0.05, -0.17)), p1 + V((fx, 0.008, -0.31)),
                                                          p1 + V((fx + sx * 0.02, 0.045, -0.45)), p1 + V((fx + sx * 0.035, 0.02, -0.6))],
                             (1, 0, 0), [0.19, 0.19, 0.185, 0.15, 0.02], 0.016, t2))
    chest.append(ck.ball(P + "body_flag_sigil", 0.05, p1 + V((0, 0.055, -0.2)), glow, (1.0, 0.25, 1.35)))
    ck._rigid(_outward(chest), rig, "chest")
    _belt(ck, base, P + "body_belt", zw - 0.05, zw + 0.04, 1.22, metal)
    wf = -b["waist"] * d * 1.22
    hips = [ck.ball(P + "body_belt_skull", 0.06, (0, wf - 0.015, zw), metal, (1.0, 0.65, 1.05)),
            ck.ball(P + "body_belt_eye_l", 0.016, (-0.024, wf - 0.05, zw + 0.012), glow),
            ck.ball(P + "body_belt_eye_r", 0.016, (0.024, wf - 0.05, zw + 0.012), glow)]
    for k in range(3):                   # escarcelas: três placas largas na frente e atrás, barra de ferro
        x = (k - 1) * 0.098
        L = 0.21 if k == 1 else 0.17
        for side, y in (("f", wf - 0.008 + abs(k - 1) * 0.02), ("b", -wf + 0.008 - abs(k - 1) * 0.02)):
            hips += [ck.box(P + "body_tasset_%s%d" % (side, k), (0.09, 0.022, L), (x, y, zw - 0.04 - L * 0.5), t, 0.007),
                     ck.box(P + "body_tasset_rim_%s%d" % (side, k), (0.094, 0.026, 0.03), (x, y, zw - 0.04 - L + 0.01), metal, 0.005)]
    for sx in (-1, 1):
        hips.append(ck.box(P + "body_sash_%d" % sx, (0.05, 0.016, 0.25), (sx * 0.049, wf - 0.03, zw - 0.15), t2, 0.005))
    ck._rigid(_outward(hips), rig, "hips")
    for s, sx in ((".R", -1), (".L", 1)):                 # ombreiras: três lâminas em escada, torres de cravos, barra de pele
        tag = s.replace(".", "_")
        sh = V(j["shoulder" + s])
        pa = _fur_ring(ck, P, "body_pfur" + tag, sh + V((sx * 0.07, 0, -0.03)), 0.085, 7, 0.06, fur)
        for k in range(3):
            pa.append(ck.ball(P + "body_pauldron%d%s" % (k, tag), b["arm"] * (3.3 - k * 0.25), sh + V((sx * (0.05 + k * 0.035), 0, 0.1 - k * 0.055)),
                              t if k % 2 == 0 else metal, (1.15, 1.12, 0.46)))
        top = sh + V((sx * 0.075, 0, 0.17))
        for k in range(3):
            off = (k - 1) * 0.085
            pa.append(ck.tube(P + "body_pspike_%d%s" % (k, tag), top + V((0, off, -0.03)), top + V((sx * 0.085, off * 1.25, 0.2 if k == 1 else 0.15)), 0.042, 0.004, metal, 6))
        pa.append(ck.ball(P + "body_prune" + tag, 0.03, sh + V((sx * 0.2, -0.02, 0.085)), glow, (0.6, 1.0, 1.3)))
        ck._rigid(_outward(pa), rig, "upper_arm" + s)
    # ---------------- braços: manoplas de placa com cotoveleira e soqueira de cravos ----------------
    for s, sx in ((".R", -1), (".L", 1)):
        tag = s.replace(".", "_")
        el, wr = V(j["elbow" + s]), V(j["wrist" + s])
        g = [ck.tube(P + "gloves_cuff" + tag, el.lerp(wr, 0.15), wr + V((0, 0, 0.01)), 0.085, 0.118, t, 12),
             ck.tube(P + "gloves_rim" + tag, wr + V((0, 0, 0.005)), wr + V((0, 0, 0.032)), 0.123, 0.123, metal, 12),
             ck.ball(P + "gloves_elbow" + tag, 0.075, el + V((sx * 0.02, 0.02, 0)), metal, (1.0, 1.0, 0.9)),
             ck.tube(P + "gloves_elbow_spike" + tag, el + V((sx * 0.05, 0.03, 0)), el + V((sx * 0.1, 0.13, 0.03)), 0.03, 0.003, metal, 6)]
        for k in range(2):
            p = el.lerp(wr, 0.4 + k * 0.3) + V((sx * 0.095, 0, 0))
            g.append(ck.tube(P + "gloves_spike_%d" % k + tag, p, p + V((sx * 0.08, 0, 0.02)), 0.028, 0.003, metal, 6))
        ck._rigid(_outward(g), rig, "forearm" + s)
        hc = V(ck.hand_center(base, s))
        ck._rigid([ck.ball(P + "gloves_fist" + tag, b["hand"] * 1.5, hc, t, (1, 1, 1.1))], rig, "hand" + s)
    # ---------------- botas ----------------
    ck.armor_piece(body, rig, P + "boots_shell", "boots", t, 0.028, 0.016)
    for s, sx in ((".R", -1), (".L", 1)):
        tag = s.replace(".", "_")
        kn, an = V(j["knee" + s]), V(j["ankle" + s])
        k = _fur_ring(ck, P, "boots_fur" + tag, an + V((0, 0, 0.1)), 0.08, 7, 0.05, fur)
        k += [ck.ball(P + "boots_knee" + tag, 0.088, kn + V((0, -0.075, 0.01)), t, (1.08, 0.7, 1.05)),
              ck.ball(P + "boots_knee_rim" + tag, 0.092, kn + V((0, -0.07, -0.02)), metal, (1.1, 0.72, 0.3)),
              ck.tube(P + "boots_knee_spike" + tag, kn + V((0, -0.12, 0.02)), kn + V((0, -0.21, 0.085)), 0.034, 0.004, metal, 8),
              ck.box(P + "boots_shin" + tag, (0.07, 0.03, 0.1), an.lerp(kn, 0.55) + V((0, -0.075, 0)), metal, 0.008)]
        ck._rigid(_outward(k), rig, "shin" + s)


def build_drum(ck, base, mats, style):
    """ber_m35 — Tambor do Trovão (Punhos de Fúria, couro)."""
    import bpy
    V = Vector
    rig, body, b, j = base["rig"], base["body"], base["b"], base["j"]
    t, t2, gold, dark, leather = mats["tint"], mats["tint2"], mats["trim"], mats["dark"], mats["leather"]
    cloth = ck.mat("m_monk_cloth", MONK_COL["cloth"], 0.9)
    iron = ck.mat("m_monk_iron", MONK_COL["iron"], 0.4)
    bead = ck.mat("m_monk_bead", MONK_COL["bead"], 0.5)
    glow = _tint_glow(ck)
    hair = bpy.data.materials.get("hair") or t
    P = "arm_%s_" % style
    c, r = V(base["head_c"]), b["head"]
    # ---------------- cabeça: cabelo preso, diadema de ferro com chifres curtos, rabo de cavalo alto (tint2) ----------------
    head = [ck._shell(P + "head_hair", c + V((0, r * 0.04, r * 0.02)), r * 1.07, 0.25, -0.8, -0.25, 0.04, hair),
            ck.tube(P + "head_circlet", c + V((0, 0, r * 0.26)), c + V((0, 0, r * 0.56)), r * 1.15, r * 1.1, iron, 24),
            ck.tube(P + "head_circlet_rim", c + V((0, 0, r * 0.22)), c + V((0, 0, r * 0.3)), r * 1.18, r * 1.17, gold, 24),
            ck.box(P + "head_plate", (r * 0.56, 0.05, r * 0.5), c + V((0, -r * 1.12, r * 0.5)), iron, 0.012),
            ck.ball(P + "head_gem", r * 0.13, c + V((0, -r * 1.17, r * 0.52)), glow, (1.0, 0.5, 1.3)),
            ck.tube(P + "head_knot_ring", c + V((0, r * 0.3, r * 0.98)), c + V((0, r * 0.3, r * 1.14)), r * 0.3, r * 0.26, gold, 12)]
    for sx in (-1, 1):
        head += _tusk(ck, P + "head_horn_%d" % sx, c + V((sx * r * 0.5, -r * 0.98, r * 0.55)), c + V((sx * r * 0.78, -r * 1.2, r * 1.28)),
                      (sx * r * 0.08, -r * 0.1, 0), 0.06, gold, 3)
        head.append(ck.box(P + "head_cheek_%d" % sx, (0.05, r * 0.42, r * 0.5), c + V((sx * r * 1.1, -r * 0.3, r * 0.1)), iron, 0.012))
    # rabo de cavalo: sobe do coque e cai para trás ; crista de ferro da testa ao coque
    head += _tusk(ck, P + "head_tail", c + V((0, r * 0.3, r * 1.08)), c + V((0, r * 1.85, r * 0.2)), (0, r * 0.3, r * 1.0), r * 0.3, t2, 6, 10)
    head.append(ck.box(P + "head_ridge", (0.07, r * 1.25, 0.06), c + V((0, -r * 0.42, r * 1.02)), iron, 0.012))
    for k in range(3):
        head.append(ck.ball(P + "head_ridge_stud_%d" % k, 0.03, c + V((0, -r * (0.85 - k * 0.38), r * (0.78 + k * 0.17))), gold))
    ck._rigid(_outward(head), rig, "head")
    # ---------------- corpo ----------------
    ck.armor_piece(body, rig, P + "body_vest", "torso", t, 0.012, 0.016, 0.02)
    ck.armor_piece(body, rig, P + "body_legs", "legs", dark, 0.008, 0.012)
    d = b["depth"]
    front = -b["chest"] * d - 0.035
    back = b["chest"] * d + 0.035
    zc, zn, zw = ck.Z["chest"], ck.Z["neck"], ck.Z["waist"]
    chest = []
    for sx in (-1, 1):
        chest.append(ck.tube(P + "body_lapel_%d" % sx, (sx * 0.13, front + 0.01, zn - 0.04), (-sx * 0.04, front - 0.005, zc - 0.12), 0.026, 0.026, cloth, 6))
    nb = 12                              # rosário curto (a marca da build), a conta do meio acesa
    for k in range(nb):
        a = math.pi * 2 * k / nb
        drop = 0.5 * (1 + math.cos(a))
        p = V((math.sin(a) * b["chest"] * 0.62, -math.cos(a) * b["chest"] * d * 0.7, zn - 0.03 - drop * 0.1))
        if math.cos(a) > 0:
            p.y = front - 0.022 - (1 - abs(math.sin(a))) * 0.01
        chest.append(ck.ball(P + "body_bead_%d" % k, 0.036, p, glow if k == 0 else bead))
    # aro de tambores de guerra nas costas: plano em pé atrás da cabeça, 5 tambores no arco de cima, braços de ferro até as costas
    R = 0.4
    dc = V((0, r * 1.3 + 0.03, zc + 0.3))
    pts = []
    for k in range(5):
        a = math.radians(-12 + k * 204.0 / 4.0)
        p = dc + V((math.cos(a) * R, 0, math.sin(a) * R))
        pts.append(p)
        chest += [ck.tube(P + "body_drum_%d" % k, p + V((0, -0.04, 0)), p + V((0, 0.04, 0)), 0.118, 0.118, t, 12),
                  ck.tube(P + "body_drum_skin_%d" % k, p + V((0, -0.05, 0)), p + V((0, 0.05, 0)), 0.096, 0.096, cloth, 12),
                  ck.ball(P + "body_drum_mark_f%d" % k, 0.042, p + V((0, -0.052, 0)), glow, (1.0, 0.3, 1.0)),
                  ck.ball(P + "body_drum_mark_b%d" % k, 0.042, p + V((0, 0.052, 0)), glow, (1.0, 0.3, 1.0))]
    for k in range(4):
        chest.append(ck.tube(P + "body_drum_arc_%d" % k, pts[k], pts[k + 1], 0.028, 0.028, gold, 6))
    for sx in (-1, 1):
        chest.append(ck.tube(P + "body_drum_arm_%d" % sx, (sx * 0.1, back - 0.02, zc + 0.02), pts[0 if sx > 0 else 4] + V((-sx * 0.06, 0, 0)), 0.03, 0.026, iron, 6))
    ck._rigid(_outward(chest), rig, "chest")
    # cinturão de campeão: ferro largo, placa redonda de ouro com miolo aceso, duas pontas de faixa (tint2)
    _belt(ck, base, P + "body_sash", zw - 0.07, zw + 0.06, 1.24, iron)
    wf = -b["waist"] * d * 1.24
    hips = [ck.tube(P + "body_buckle", (0, wf + 0.01, zw), (0, wf - 0.03, zw), 0.095, 0.085, gold, 12),
            ck.ball(P + "body_buckle_core", 0.04, (0, wf - 0.032, zw), glow, (1.0, 0.4, 1.0))]
    for sx in (-1, 1):
        hips += [ck.ball(P + "body_belt_stud_%d" % sx, 0.028, (sx * 0.125, wf * 0.82, zw), gold),
                 ck.blade(P + "body_sash_tail_%d" % sx, (sx * 0.1, wf - 0.005, zw - 0.04), (sx * 0.13, wf - 0.03, zw - 0.36), 0.085, 0.014, t2, (1, 0, 0), 0.2)]
    ck._rigid(_outward(hips), rig, "hips")
    for s, sx in ((".R", -1), (".L", 1)):                 # ombros: calota de ferro com cravo e nó de corda, nos dois lados
        tag = s.replace(".", "_")
        sh = V(j["shoulder" + s])
        pa = [ck.ball(P + "body_guard" + tag, b["arm"] * 2.25, sh + V((sx * 0.05, 0, 0.06)), iron, (1.12, 1.08, 0.55)),
              ck.ball(P + "body_guard_rim" + tag, b["arm"] * 2.32, sh + V((sx * 0.055, 0, 0.035)), gold, (1.14, 1.1, 0.14)),
              ck.tube(P + "body_guard_spike" + tag, sh + V((sx * 0.07, 0, 0.11)), sh + V((sx * 0.13, 0, 0.24)), 0.04, 0.004, gold, 6),
              ck.tube(P + "body_guard_rope" + tag, sh + V((sx * 0.03, 0, -0.075)), sh + V((sx * 0.035, 0, -0.105)), b["arm"] * 1.3, b["arm"] * 1.3, cloth, 10)]
        ck._rigid(_outward(pa), rig, "upper_arm" + s)
    # ---------------- braços: manoplas de ferro enormes (o punho é a arma) ----------------
    for s, sx in ((".R", -1), (".L", 1)):
        tag = s.replace(".", "_")
        el, wr = V(j["elbow" + s]), V(j["wrist" + s])
        g = [ck.tube(P + "gloves_wrap" + tag, el.lerp(wr, 0.08), el.lerp(wr, 0.3), 0.08, 0.082, cloth, 10),
             ck.tube(P + "gloves_gauntlet" + tag, el.lerp(wr, 0.26), wr + V((0, 0, 0.02)), 0.098, 0.128, iron, 12),
             ck.tube(P + "gloves_rim_a" + tag, el.lerp(wr, 0.26), el.lerp(wr, 0.34), 0.104, 0.106, gold, 12),
             ck.tube(P + "gloves_rune" + tag, el.lerp(wr, 0.62), el.lerp(wr, 0.7), 0.122, 0.124, glow, 12),
             ck.tube(P + "gloves_rim_b" + tag, wr + V((0, 0, 0.0)), wr + V((0, 0, 0.03)), 0.133, 0.133, gold, 12)]
        ck._rigid(_outward(g), rig, "forearm" + s)
        hc = V(ck.hand_center(base, s))
        fist = [ck.ball(P + "gloves_fist" + tag, b["hand"] * 1.65, hc, iron, (1, 1, 1.1))]
        for k in range(3):
            fist.append(ck.ball(P + "gloves_stud_%d" % k + tag, 0.026, hc + V(((k - 1) * 0.045, -b["hand"] * 1.5, -0.02)), gold))
        ck._rigid(_outward(fist), rig, "hand" + s)
    # ---------------- pernas: sandália, ataduras e caneleira de ferro ----------------
    ck.armor_piece(body, rig, P + "boots_shell", "boots", leather, 0.012, 0.01)
    for s, sx in ((".R", -1), (".L", 1)):
        tag = s.replace(".", "_")
        kn, an = V(j["knee" + s]), V(j["ankle" + s])
        k = [ck.tube(P + "boots_wrap%s_%d" % (tag, i), an.lerp(kn, 0.08 + i * 0.2), an.lerp(kn, 0.2 + i * 0.2), 0.072, 0.072, cloth if i % 2 == 0 else t2, 10) for i in range(4)]
        k += [ck.box(P + "boots_sole" + tag, (0.13, 0.22, 0.025), an + V((0, -0.05, -0.065)), leather, 0.01),
              ck.box(P + "boots_shin" + tag, (0.075, 0.03, 0.1), an.lerp(kn, 0.55) + V((0, -0.072, 0)), iron, 0.008),
              ck.ball(P + "boots_knee" + tag, 0.066, kn + V((0, -0.06, 0.0)), iron, (1.0, 0.6, 1.1)),
              ck.ball(P + "boots_knee_stud" + tag, 0.022, kn + V((0, -0.1, 0.0)), gold)]
        ck._rigid(_outward(k), rig, "shin" + s)


ACT2_SETS = {"ber_g35": build_warg, "ber_e35": build_siege, "ber_m35": build_drum}
# armas do Ato II: fio/lâmina acesa na cor do nível ("glow": "tint" -> material tint_glow_edge / tint_glow)
BER_AXES["ber_g35"] = {"type": "axe", "head": "cleaver", "dark": True, "glow": "tint", "back": True, "fur": True, "tassel": True}
BER_AXES["ber_e35"] = {"type": "axe2h", "head": "bearded", "dark": True, "glow": "tint", "poll": True, "spike": True, "skull": True, "tassel": True}
MONK_CLAWS["ber_m35"] = {"blades": 4, "len": 0.56, "curve": 0.2, "guard": "dark", "beast": True, "glow": "tint"}


def register(ck):
    import paladin_sets
    for style, fn in ACT2_SETS.items():                    # Ato II: um visual novo por build (35/40/45 + Ápice)
        ck.SET_STYLES[style] = (lambda st, f: (lambda base, mats: (f(ck, base, mats, st), paladin_sets.join_slots("arm_%s_" % st))))(style, fn)
    for style, cfg in MONK_SETS.items():
        ck.SET_STYLES[style] = (lambda st, cf: (lambda base, mats: (build_monk(ck, base, mats, st, cf), paladin_sets.join_slots("arm_%s_" % st))))(style, cfg)
    for style, cfg in MONK_CLAWS.items():                  # duas garras: uma em cada mão
        ck.SET_WEAPONS["ber_claw_" + style] = (lambda st, cf: (lambda base, mats: build_claw(ck, base, mats, st, cf, "main")))(style, cfg)
        ck.SET_WEAPONS["ber_offclaw_" + style] = (lambda st, cf: (lambda base, mats: build_claw(ck, base, mats, st, cf, "off")))(style, cfg)
    for style, cfg in BER_SETS.items():
        ck.SET_STYLES[style] = (lambda st, cf: (lambda base, mats: (build(ck, base, mats, st, cf), paladin_sets.join_slots("arm_%s_" % st))))(style, cfg)
    for style, cfg in BER_AXES.items():
        ck.SET_WEAPONS["ber_axe_" + style] = (lambda st, cf: (lambda base, mats: build_axe(ck, base, mats, st, cf, "main")))(style, cfg)
        if cfg["type"] == "axe":                           # Gêmeos: o segundo machado, na mão esquerda
            ck.SET_WEAPONS["ber_off_" + style] = (lambda st, cf: (lambda base, mats: build_axe(ck, base, mats, st, cf, "off")))(style, cfg)
