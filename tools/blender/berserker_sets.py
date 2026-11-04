"""Conjuntos lendários do Berserker (12) e os machados deles, por construtor paramétrico (como paladin_sets.py).

Linguagem visual (original): bárbaro — pele, chifres, tiras de couro, troféus de osso e marcas de sangue.
Machados Gêmeos (carniceiro, couro): leve e veloz, capuz de pele, tiras cruzadas, saiote de couro, dois machados.
Executor (placa): pesado, tanque de apoio, elmo fechado com chifres, ombreira gigante, machado de duas mãos.
Peças: arm_<estilo>_<head|body|gloves|boots>_*; armas: wpn_main_<axe|axe2h>_<estilo> e wpn_off_axe_<estilo>.
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
# Machados. head: bearded | crescent | cleaver | double | fang ; motivos: spike (ponta no topo), back (cravo atrás),
# fur (pele no cabo), skull (no colar), gem, glow (fio aceso), dark (lâmina escura)
BER_AXES = {
    "ber_g5": {"type": "axe", "head": "bearded", "fur": True},
    "ber_g10": {"type": "axe", "head": "bearded", "back": True},
    "ber_g15": {"type": "axe", "head": "fang", "skull": True},
    "ber_g20": {"type": "axe", "head": "crescent", "dark": True, "glow": True},
    "ber_g25": {"type": "axe", "head": "fang", "back": True, "gem": True},
    "ber_g30": {"type": "axe", "head": "crescent", "dark": True, "glow": True, "skull": True, "spike": True},
    "ber_e5": {"type": "axe2h", "head": "bearded", "fur": True},
    "ber_e10": {"type": "axe2h", "head": "double", "spike": True},
    "ber_e15": {"type": "axe2h", "head": "cleaver", "skull": True, "back": True},
    "ber_e20": {"type": "axe2h", "head": "crescent", "glow": True, "fur": True},
    "ber_e25": {"type": "axe2h", "head": "double", "dark": True, "spike": True, "gem": True},
    "ber_e30": {"type": "axe2h", "head": "double", "glow": True, "skull": True, "spike": True, "gem": True},
}
HEADS = {
    "bearded": [(0.12, 0.0), (0.2, 0.08), (0.24, 0.22), (0.18, 0.36), (0.02, 0.4), (-0.2, 0.36), (-0.3, 0.22), (-0.16, 0.12), (-0.08, 0.0)],
    "crescent": [(0.1, 0.0), (0.3, 0.14), (0.38, 0.32), (0.26, 0.42), (0.1, 0.34), (0.0, 0.4), (-0.1, 0.34), (-0.26, 0.42), (-0.38, 0.32), (-0.3, 0.14), (-0.1, 0.0)],
    "cleaver": [(0.14, 0.0), (0.2, 0.38), (0.06, 0.44), (-0.22, 0.42), (-0.16, 0.0)],
    "fang": [(0.1, 0.0), (0.22, 0.1), (0.3, 0.3), (0.2, 0.33), (0.18, 0.4), (0.06, 0.38), (0.0, 0.44), (-0.08, 0.37), (-0.18, 0.4), (-0.22, 0.32),
             (-0.32, 0.3), (-0.24, 0.1), (-0.1, 0.0)],
}


def _prism(ck, name, outline, ctr, u, v, w, thick, material):
    """Placa a partir de um contorno 2D (u ao longo do cabo, v para fora), com espessura no eixo w."""
    import bmesh
    bm = bmesh.new()
    f = [bm.verts.new(ctr + u * a + v * c + w * thick * 0.5) for a, c in outline]
    k = [bm.verts.new(ctr + u * a + v * c - w * thick * 0.5) for a, c in outline]
    bm.faces.new(f)
    bm.faces.new(list(reversed(k)))
    for i in range(len(outline)):
        n = (i + 1) % len(outline)
        bm.faces.new((f[i], f[n], k[n], k[i]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    return ck.mesh_from(name, bm, material)


def build_axe(ck, base, mats, style, cfg, hand):
    """Machado do conjunto na mão (main = direita, off = esquerda), 1 malha."""
    V = Vector
    side_tag = ".R" if hand == "main" else ".L"
    g = V(ck.hand_center(base, side_tag))
    fwd = V((0, -0.55, 0.83)).normalized()
    side = V((1, 0, 0))
    out = -fwd.cross(side).normalized()          # a lâmina aponta para a frente do boneco
    t, t2, gold = mats["tint"], mats["tint2"], mats["trim"]
    metal = mats["dark"] if cfg.get("dark") else mats["metal"]
    bone = ck.mat("m_ber_bone", BONE, 0.7)
    big = cfg["type"] == "axe2h"
    S = 1.45 if big else 0.72                    # duas mãos: cabeça enorme (o golpe também é mais largo); uma mão: compacto
    shaft = (0.95 if big else 0.52)
    hc = g + fwd * (shaft - 0.06)
    n = "a_%s_%s_" % (style, hand)
    parts = [ck.tube(n + "shaft", g - fwd * (0.32 if big else 0.12), g + fwd * (shaft + 0.06), 0.032 if big else 0.027, 0.03 if big else 0.025, mats["wood"], 8),
             ck.ball(n + "pommel", 0.045, g - fwd * (0.35 if big else 0.14), gold)]
    for k in range(4 if big else 3):
        z = (-0.26 if big else -0.08) + k * (0.12 if big else 0.07)
        parts.append(ck.tube(n + "wrap%d" % k, g + fwd * z, g + fwd * (z + 0.022), 0.036, 0.036, t2, 8))
    head = HEADS["bearded" if cfg["head"] == "double" else cfg["head"]]
    outline = [(a * S, c * S) for a, c in head]
    sides = (1, -1) if cfg["head"] == "double" else (1,)
    for sg in sides:
        vv = out * sg
        parts.append(_prism(ck, n + "blade%d" % sg, outline, hc + vv * 0.03, fwd, vv, side, 0.04 if big else 0.032, metal))
        edge = [(a * 1.04, c * 1.05) for a, c in outline if c > 0.2 * S]       # fio: faixa clara na borda de corte
        if len(edge) >= 3:
            em = ck.mat("m_ber_edge_glow", (1.0, 0.25, 0.15), 0.3, 2.4) if cfg.get("glow") else mats["metal"]
            parts.append(_prism(ck, n + "edge%d" % sg, edge + [(edge[-1][0] * 0.95, edge[-1][1] * 0.9), (edge[0][0] * 0.95, edge[0][1] * 0.9)],
                                hc + vv * 0.03, fwd, vv, side, 0.018, em))
    parts.append(ck.tube(n + "socket", hc - fwd * 0.12 * S, hc + fwd * 0.12 * S, 0.045 * S, 0.045 * S, t, 8))
    if cfg.get("back") and cfg["head"] != "double":       # cravo atrás da cabeça
        parts.append(ck.tube(n + "back", hc - out * 0.04, hc - out * 0.2 * S, 0.04 * S, 0.004, metal, 8))
    if cfg.get("spike"):                                   # ponta no topo do cabo
        parts.append(ck.tube(n + "spike", hc + fwd * 0.12 * S, hc + fwd * 0.3 * S, 0.035 * S, 0.004, gold, 8))
    if cfg.get("fur"):
        parts.append(ck.tube(n + "fur", hc - fwd * 0.2 * S, hc - fwd * 0.13 * S, 0.06 * S, 0.055 * S, ck.mat("m_ber_fur_brown", FUR["brown"], 0.95), 10))
    if cfg.get("skull"):
        parts.append(ck.ball(n + "skull", 0.05 * S, hc - fwd * 0.18 * S + out * 0.02, bone, (1, 0.85, 1.05)))
    if cfg.get("gem"):
        for sg in (-1, 1):
            parts.append(ck.ball(n + "gem%d" % sg, 0.032 * S, hc + side * sg * 0.025, t2, (0.5, 1, 1)))
    wt = cfg["type"]
    obj = ck._join(parts, ("wpn_main_%s_%s" % (wt, style)) if hand == "main" else ("wpn_off_axe_%s" % style))
    ck._smooth(obj.data)
    ck.skin_rigid(obj, base["rig"], "hand" + side_tag)
    return obj


def register(ck):
    import paladin_sets
    for style, cfg in BER_SETS.items():
        ck.SET_STYLES[style] = (lambda st, cf: (lambda base, mats: (build(ck, base, mats, st, cf), paladin_sets.join_slots("arm_%s_" % st))))(style, cfg)
    for style, cfg in BER_AXES.items():
        ck.SET_WEAPONS["ber_axe_" + style] = (lambda st, cf: (lambda base, mats: build_axe(ck, base, mats, st, cf, "main")))(style, cfg)
        if cfg["type"] == "axe":                           # Gêmeos: o segundo machado, na mão esquerda
            ck.SET_WEAPONS["ber_off_" + style] = (lambda st, cf: (lambda base, mats: build_axe(ck, base, mats, st, cf, "off")))(style, cfg)
