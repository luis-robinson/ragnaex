"""Conjuntos lendários do Assassino (12), adagas das Lâminas e espadas do Duelista, por construtor paramétrico (desenho original).

Lâminas (duas adagas): capuz justo com máscara de pano na boca, lenço com pontas soltas, colete curto de couro com tiras
cruzadas, frascos de veneno no cinto, faixas nos antebraços e joelhos, capa curta rasgada. Silhueta magra e escura.
Corsário (sabre + pistola): chapéu grande (tricórnio de abas viradas, bicorne atravessado ou bandana), casaca longa aberta
com abas atrás, faixa na cintura, boldrié, punhos e canos de bota dobrados, tapa-olho, dragonas, papagaio (CORSAIR_SETS,
build_corsair); pistolas de pederneira na mão esquerda (CORSAIR_PISTOLS, pistol_parts, que também desenha a pistola comum).
Duelista (duas espadas): esgrimista — chapéu de aba com pluma, bandana ou máscara de baile; casaca de abas compridas
atrás, gola alta, faixa na cintura com ponta caída, meia-capa num ombro, punhos largos nas luvas, botas de cano dobrado.
Peças: arm_<estilo>_<head|body|gloves|boots>_*; armas: wpn_main_<dagger|sword>_<estilo> e wpn_off_<dagger|sword|pistol>_<estilo>.
"""
import math
from mathutils import Vector

# head: hood_mask | cowl | mask_band | horned_hood (Lâminas) ; plume_hat | bandana | domino | circlet (Duelista)
# cape: comprimento (0 = sem) ; vials: frascos no cinto ; tails: pontas do lenço/faixa ; glow: cor do brilho
ASS_SETS = {
    # ---- Lâminas (duas adagas, veneno, furtividade) ----
    "ass_l5": {"kind": "blades", "head": "hood_mask", "cape": 0.0, "vials": 1, "tails": 2},
    "ass_l10": {"kind": "blades", "head": "mask_band", "cape": 0.2, "vials": 2, "tails": 2},
    "ass_l15": {"kind": "blades", "head": "cowl", "cape": 0.26, "vials": 2, "tails": 3, "glow": (0.55, 1.0, 0.35)},
    "ass_l20": {"kind": "blades", "head": "horned_hood", "cape": 0.3, "vials": 3, "tails": 2, "glow": (0.75, 0.45, 1.0)},
    "ass_l25": {"kind": "blades", "head": "cowl", "cape": 0.34, "vials": 3, "tails": 3, "glow": (0.4, 1.0, 0.75), "spikes": True},
    "ass_l30": {"kind": "blades", "head": "horned_hood", "cape": 0.4, "vials": 4, "tails": 4, "glow": (0.9, 0.35, 1.0), "spikes": True},
    # ---- Duelista (duas espadas, equilibrado) ----
    "ass_d5": {"kind": "duel", "head": "bandana", "cape": 0.0, "coat": 0.16, "tails": 2},
    "ass_d10": {"kind": "duel", "head": "plume_hat", "cape": 0.22, "coat": 0.2, "tails": 2, "plumes": 1},
    "ass_d15": {"kind": "duel", "head": "domino", "cape": 0.26, "coat": 0.22, "tails": 2},
    "ass_d20": {"kind": "duel", "head": "plume_hat", "cape": 0.3, "coat": 0.26, "tails": 3, "plumes": 2, "glow": (1.0, 0.45, 0.4)},
    "ass_d25": {"kind": "duel", "head": "circlet", "cape": 0.34, "coat": 0.28, "tails": 3, "glow": (0.55, 0.8, 1.0)},
    "ass_d30": {"kind": "duel", "head": "plume_hat", "cape": 0.4, "coat": 0.32, "tails": 3, "plumes": 3, "glow": (1.0, 0.85, 0.45)},
}
VIAL = (0.45, 0.95, 0.4)
PLUME = (0.96, 0.95, 0.92)


def _mask(ck, name, c, r, top, material):
    """Máscara de pano: só a metade de baixo e da frente da casca (boca e nariz cobertos, olhos livres)."""
    import bmesh
    o = ck.quad_sphere(name, r, c, cuts=4)
    bm = bmesh.new()
    bm.from_mesh(o.data)
    kill = [f for f in bm.faces if (f.calc_center_median() - Vector(c)).z > top * r or (f.calc_center_median() - Vector(c)).y > r * 0.35]
    bmesh.ops.delete(bm, geom=kill, context="FACES")
    bm.to_mesh(o.data)
    bm.free()
    sol = o.modifiers.new("sol", "SOLIDIFY")
    sol.thickness = 0.025
    sol.offset = 1.0
    ck._bake(o)
    o.data.materials.append(material)
    ck._smooth(o.data)
    return o


def build(ck, base, mats, style, cfg):
    V = Vector
    rig, body, b, j = base["rig"], base["body"], base["b"], base["j"]
    t, t2, gold, wh, dark, leather = mats["tint"], mats["tint2"], mats["trim"], mats["white"], mats["dark"], mats["leather"]
    glow = ck.mat("m_ass_glow_%d" % int(sum(cfg["glow"]) * 100), cfg["glow"], 0.3, 2.6) if cfg.get("glow") else None
    vial = glow or ck.mat("m_ass_vial", VIAL, 0.2, 1.6)
    plume = ck.mat("m_ass_plume", PLUME, 0.85)
    blades = cfg["kind"] == "blades"
    P = "arm_%s_" % style
    c = V(base["head_c"])
    r = b["head"]
    # ---------------- cabeça ----------------
    hk = cfg["head"]
    head = []
    if hk in ("mask_band", "domino", "circlet", "plume_hat"):   # peça aberta: o elmo esconde o cabelo, então o kit desenha um cabelo curto (cor da classe)
        import bpy
        hair = bpy.data.materials.get("hair") or t
        head += [ck._shell(P + "head_hair", c + V((0, r * 0.04, r * 0.02)), r * 1.06, 0.25, -0.75, -0.2, 0.04, hair),
                 ck.strand(P + "head_tuft", c + V((0, r * 0.7, -r * 0.2)), r * 0.6, r * 0.3, r * 0.22, hair, taper=0.9, lean=(0.0, 0.9))]
    if hk in ("hood_mask", "cowl", "horned_hood"):      # capuz justo, aberto só nos olhos
        head.append(ck._shell(P + "head_hood", c, r * 1.15, 0.32, -1.0, -0.55, 0.035, t))
        if hk == "cowl":                                 # ponta longa caída nas costas
            head.append(ck.strand(P + "head_tail", c + V((0, r * 0.8, r * 0.4)), r * 1.3, r * 0.45, r * 0.3, t, taper=0.95, lean=(0.0, 1.0)))
        if hk == "horned_hood":                          # duas pontas como orelhas/chifres curtos
            for sx in (-1, 1):
                head.append(ck.blade(P + "head_horn_%d" % sx, c + V((sx * r * 0.55, r * 0.1, r * 0.8)), c + V((sx * r * 0.9, r * 0.35, r * 1.45)),
                                     r * 0.28, 0.03, t, (0, 1, 0)))
    if hk in ("hood_mask", "cowl", "horned_hood", "mask_band"):   # máscara de pano na boca e no nariz
        head.append(_mask(ck, P + "head_mask", c, r * 1.06, -0.4, t2 if hk == "mask_band" else dark))
    if hk == "mask_band":                                # faixa na testa com pontas soltas atrás
        head.append(ck.tube(P + "head_band", c + V((0, 0, r * 0.32)), c + V((0, 0, r * 0.46)), r * 1.11, r * 1.1, t2, 24))
    if hk == "bandana":
        head += [ck._shell(P + "head_bandana", c + V((0, r * 0.05, r * 0.05)), r * 1.1, 0.4, -0.2, 0.1, 0.03, t),
                 ck.ball(P + "head_knot", r * 0.18, c + V((0, r * 1.05, r * 0.25)), t2)]
    if hk == "domino":                                   # máscara de baile nos olhos + cabelo preso
        head.append(ck.blade(P + "head_domino", c + V((-r * 0.62, -r * 0.98, -0.03)), c + V((r * 0.62, -r * 0.98, -0.03)), 0.16, 0.02, dark, (0, 0, 1), 0.7))
        head.append(ck.tube(P + "head_band", c + V((0, 0, r * 0.12)), c + V((0, 0, r * 0.22)), r * 1.06, r * 1.05, dark, 24))
    if hk == "circlet":                                  # aro fino com pedra
        head += [ck.tube(P + "head_circlet", c + V((0, 0, r * 0.38)), c + V((0, 0, r * 0.48)), r * 1.1, r * 1.09, gold, 24),
                 ck.ball(P + "head_gem", 0.035, c + V((0, -r * 1.11, r * 0.44)), glow or t2, (1, 0.6, 1.3))]
    if hk == "plume_hat":                                # chapéu de aba larga virada de um lado, com plumas
        head += [ck._shell(P + "head_crown", c + V((0, 0, r * 0.2)), r * 1.0, 0.5, 0.25, 0.3, 0.035, t),
                 ck.tube(P + "head_brim", c + V((0, 0, r * 0.55)), c + V((0, 0, r * 0.6)), r * 1.6, r * 1.55, t, 28),
                 ck.tube(P + "head_band", c + V((0, 0, r * 0.62)), c + V((0, 0, r * 0.74)), r * 1.0, r * 0.98, t2, 24)]
        for k in range(cfg.get("plumes", 1)):
            head.append(ck.blade(P + "head_plume_%d" % k, c + V((r * 0.7, r * 0.1, r * 0.75)),
                                 c + V((r * (1.2 + k * 0.1), r * (1.0 + k * 0.15), r * (1.5 - k * 0.12))), r * 0.62, 0.012,
                                 plume if k % 2 == 0 else (glow or t2), (1, 0, 0.15), 0.4))
    if hk in ("mask_band", "bandana"):                   # pontas soltas atrás da cabeça
        for k in range(cfg["tails"]):
            x = (k - (cfg["tails"] - 1) / 2) * r * 0.25
            head.append(ck.blade(P + "head_tail_%d" % k, c + V((x, r * 1.0, r * 0.35)), c + V((x * 1.8, r * 1.6, -r * 0.4 - k * r * 0.12)),
                                 r * 0.2, 0.015, t2, (1, 0, 0), 0.25))
    ck._rigid(head, rig, "head")
    # ---------------- corpo ----------------
    ck.armor_piece(body, rig, P + "body_vest", "torso", t if blades else t, 0.012, 0.014, 0.02)
    ck.armor_piece(body, rig, P + "body_legs", "legs", dark if blades else leather, 0.008, 0.012)
    d = b["depth"]
    front = -b["chest"] * d - 0.03
    back = b["chest"] * d + 0.03
    zc = ck.Z["chest"]
    zn = ck.Z["neck"]
    chest = []
    if blades:
        # tiras cruzadas no peito com fivelas, lenço com pontas
        for sx in (-1, 1):
            chest.append(ck.tube(P + "body_strap_%d" % sx, (sx * 0.15, front + 0.02, zc + 0.14), (-sx * 0.12, front + 0.02, ck.Z["waist"] + 0.05), 0.016, 0.016, leather, 6))
        chest.append(ck.box(P + "body_buckle", (0.045, 0.02, 0.045), (0, front + 0.005, zc - 0.03), gold, 0.006))
        chest.append(ck.tube(P + "body_scarf", V((0, 0, zn - 0.04)), V((0, 0, zn + 0.03)), b["chest"] * 0.56, b["chest"] * 0.5, t2, 14))
        for k in range(cfg["tails"]):
            x = 0.04 + k * 0.03
            chest.append(ck.blade(P + "body_scarf_tail_%d" % k, (x, back + 0.0, zn - 0.03), (x + 0.04 + k * 0.02, back + 0.1, zn - 0.2 - k * 0.05), 0.05, 0.012, t2, (1, 0, 0), 0.2))
        if cfg.get("spikes"):                       # espinhos de metal no colarinho
            for k in range(5):
                a = math.pi * (0.2 + 0.6 * k / 4)
                p = V((math.cos(a) * b["chest"] * 0.55, math.sin(a) * b["chest"] * 0.5, zn - 0.02))
                chest.append(ck.tube(P + "body_spike_%d" % k, p, p + V((math.cos(a) * 0.03, math.sin(a) * 0.05, 0.07)), 0.014, 0.002, mats["metal"], 6))
        if cfg["cape"] > 0.0:                       # capa curta rasgada, pontas desiguais
            L = cfg["cape"]
            for k in range(5):
                x = (k - 2) * 0.065
                chest.append(ck.blade(P + "body_cape_%d" % k, (x * 0.8, back + 0.02, zn - 0.05), (x * 1.25, back + 0.08, zn - 0.05 - L * (0.75 + 0.25 * ((k * 3) % 4) / 3)),
                                      0.085, 0.014, dark if k % 2 == 0 else t, (1, 0, 0), 0.15))
    else:
        # gola alta, botões dourados, abas da casaca atrás, meia-capa no ombro esquerdo
        chest.append(ck.tube(P + "body_collar", V((0, 0, zn - 0.03)), V((0, 0, zn + 0.06)), b["chest"] * 0.55, b["chest"] * 0.6, t2, 16))
        for k in range(4):
            chest.append(ck.ball(P + "body_button_%d" % k, 0.016, (0.035, front - 0.005, zc + 0.1 - k * 0.06), gold))
        chest.append(ck.box(P + "body_lapel", (0.05, 0.015, 0.22), (-0.03, front - 0.002, zc), t2, 0.004))
        L = cfg["coat"]
        for sx in (-1, 1):                          # duas abas compridas atrás
            chest.append(ck.blade(P + "body_coattail_%d" % sx, (sx * 0.06, back - 0.01, ck.Z["waist"] + 0.02), (sx * 0.1, back + 0.05, ck.Z["waist"] - L - 0.08),
                                  0.11, 0.014, t, (1, 0, 0), 0.6))
            chest.append(ck.blade(P + "body_coattrim_%d" % sx, (sx * 0.06, back + 0.0, ck.Z["waist"] - L * 0.8), (sx * 0.1, back + 0.055, ck.Z["waist"] - L - 0.085),
                                  0.115, 0.016, gold, (1, 0, 0), 0.6))
        if cfg["cape"] > 0.0:                       # meia-capa caindo do ombro esquerdo
            Lc = cfg["cape"]
            sh = V(j["shoulder.L"])
            for k in range(3):
                chest.append(ck.blade(P + "body_halfcape_%d" % k, sh + V((-0.02 - k * 0.05, 0.04 + k * 0.03, 0.04)), sh + V((0.04 - k * 0.07, 0.14 + k * 0.02, -Lc - k * 0.03)),
                                      0.1, 0.014, t2 if k != 1 else t, (1, 0, 0.3), 0.3))
            chest.append(ck.ball(P + "body_clasp", 0.03, sh + V((-0.08, -0.05, 0.02)), glow or gold))
    if glow:
        chest.append(ck.ball(P + "body_charm", 0.024, (-0.07, front - 0.02, zc + 0.08), glow))
    ck._rigid(chest, rig, "chest")
    belt = ck.tube(P + "body_belt", (0, 0, ck.Z["waist"] - 0.035), (0, 0, ck.Z["waist"] + 0.03), b["waist"] * 1.18, b["waist"] * 1.18, leather if blades else t2, 16)
    for v in belt.data.vertices:
        v.co.y *= d * 1.05
    ck._smooth(belt.data)
    ck.transfer_weights(belt, body, rig)
    wf = -b["waist"] * d * 1.18
    hips = []
    if blades:                                      # frascos de veneno pendurados no cinto
        for k in range(cfg["vials"]):
            a = -0.9 + k * 0.45
            p = V((math.sin(a) * b["waist"] * 1.25, math.cos(a) * wf, ck.Z["waist"] - 0.06))
            hips += [ck.ball(P + "body_vial_%d" % k, 0.03, p, vial, (0.8, 0.8, 1.25)),
                     ck.ball(P + "body_vial_cap_%d" % k, 0.014, p + V((0, 0, 0.045)), dark)]
        hips.append(ck.box(P + "body_loin", (0.1, 0.014, 0.16), (0, wf - 0.012, ck.Z["waist"] - 0.12), dark, 0.004))
    else:                                           # faixa da cintura com ponta caída de lado
        hips.append(ck.ball(P + "body_sash_knot", 0.04, (0.13, wf * 0.7, ck.Z["waist"]), t2, (1, 0.8, 1)))
        for k in range(cfg["tails"] - 1):
            hips.append(ck.blade(P + "body_sash_%d" % k, (0.13, wf * 0.7, ck.Z["waist"] - 0.02), (0.17 + k * 0.03, wf * 0.6, ck.Z["waist"] - 0.24 - k * 0.04),
                                 0.06, 0.012, t2, (0, 1, 0), 0.3))
    ck._rigid(hips, rig, "hips")
    for s, sx in ((".R", -1), (".L", 1)):
        sh = V(j["shoulder" + s])
        if blades:                                  # ombreira pequena de couro só no direito
            if s == ".R":
                ck._rigid([ck.ball(P + "body_pauldron", b["arm"] * 1.7, sh + V((sx * 0.05, 0, 0.04)), leather, (1.1, 1.05, 0.55)),
                           ck.ball(P + "body_pauldron_rim", b["arm"] * 1.76, sh + V((sx * 0.05, 0, 0.02)), t2, (1.12, 1.07, 0.14))], rig, "upper_arm" + s)
        elif s == ".R":                             # dragona do esgrimista
            pa = [ck.ball(P + "body_epaulet", b["arm"] * 2.1, sh + V((sx * 0.05, 0, 0.05)), t2, (1.15, 1.0, 0.4))]
            for k in range(5):
                pa.append(ck.tube(P + "body_fringe_%d" % k, sh + V((sx * 0.1, (k - 2) * 0.025, 0.04)), sh + V((sx * 0.13, (k - 2) * 0.027, -0.04)), 0.008, 0.006, gold, 4))
            ck._rigid(pa, rig, "upper_arm" + s)
    # ---------------- braços ----------------
    for s in (".R", ".L"):
        tag = s.replace(".", "_")
        el, wr = V(j["elbow" + s]), V(j["wrist" + s])
        if blades:                                  # faixas enroladas no antebraço
            g = [ck.tube(P + "gloves_wrap%s_%d" % (tag, k), el.lerp(wr, 0.2 + k * 0.22), el.lerp(wr, 0.32 + k * 0.22), 0.072, 0.074, t2 if k % 2 else dark, 10) for k in range(4)]
        else:                                       # punho largo de luva de esgrima
            g = [ck.tube(P + "gloves_cuff" + tag, el.lerp(wr, 0.45), wr + V((0, 0, 0.01)), 0.1, 0.075, t, 14),
                 ck.tube(P + "gloves_cuff_rim" + tag, el.lerp(wr, 0.45), el.lerp(wr, 0.5), 0.104, 0.1, gold, 14)]
        ck._rigid(g, rig, "forearm" + s)
        fist = ck.ball(P + "gloves_fist" + tag, b["hand"] * 1.22, ck.hand_center(base, s), dark if blades else leather, (1, 1, 1.1))
        ck._rigid([fist], rig, "hand" + s)
    # ---------------- botas: uma por conjunto (o nível escolhe tiras, cano, biqueira, joelheira, cravos/esporas e asinhas) ----------------
    tier = LEVELS.index(int(style[5:]))
    boots(ck, base, mats, P, blades, tier, glow)


# variantes de bota por nível (0..5): cada nível liga uma combinação diferente
BOOT_VARIANTS = [
    {"straps": 1, "cuff": 0.1, "toe": False, "knee": False, "spikes": 0, "wing": False},
    {"straps": 2, "cuff": 0.13, "toe": True, "knee": False, "spikes": 0, "wing": False},
    {"straps": 3, "cuff": 0.16, "toe": False, "knee": True, "spikes": 0, "wing": False},
    {"straps": 2, "cuff": 0.18, "toe": True, "knee": True, "spikes": 1, "wing": False},
    {"straps": 1, "cuff": 0.2, "toe": True, "knee": False, "spikes": 2, "wing": True},
    {"straps": 3, "cuff": 0.22, "toe": True, "knee": True, "spikes": 2, "wing": True},
]
LEVELS = [5, 10, 15, 20, 25, 30]


def boots(ck, base, mats, P, blades, tier, glow):
    """Botas do conjunto: Lâminas = enroladas em faixas com cravos; Duelista = cano dobrado com esporas. Variam por nível."""
    V = Vector
    rig, body, j = base["rig"], base["body"], base["j"]
    t, t2, gold, dark, leather, metal = mats["tint"], mats["tint2"], mats["trim"], mats["dark"], mats["leather"], mats["metal"]
    bv = BOOT_VARIANTS[tier]
    ck.armor_piece(body, rig, P + "boots_shell", "boots", dark if blades else leather, 0.022, 0.016)
    for s, sx in ((".R", -1), (".L", 1)):
        tag = s.replace(".", "_")
        an = V(j["ankle" + s])
        top = bv["cuff"]
        k = []
        if blades:                                   # faixas cruzadas subindo pela canela
            for i in range(bv["straps"] + 1):
                z = 0.02 + i * (top / (bv["straps"] + 1))
                k.append(ck.tube(P + "boots_wrap%s_%d" % (tag, i), an + V((0, 0, z)), an + V((0, 0, z + 0.022)), 0.078 + i * 0.003, 0.078 + i * 0.003, t2 if i % 2 else t, 12))
        else:                                        # cano dobrado na altura do nível, fivelas
            k.append(ck.tube(P + "boots_fold" + tag, an + V((0, 0, top)), an + V((0, 0, top + 0.06)), 0.09, 0.1 + tier * 0.004, t, 12))
            for i in range(bv["straps"]):
                z = 0.03 + i * 0.045
                k += [ck.tube(P + "boots_strap%s_%d" % (tag, i), an + V((0, 0, z)), an + V((0, 0, z + 0.016)), 0.081, 0.081, leather if i % 2 else t2, 12),
                      ck.box(P + "boots_buckle%s_%d" % (tag, i), (0.024, 0.01, 0.02), an + V((sx * 0.07, -0.03, z + 0.008)), gold, 0.003)]
        if bv["knee"]:                               # joelheira
            k.append(ck.ball(P + "boots_knee" + tag, 0.05, an + V((0, -0.06, top + 0.08)), metal if blades else t2, (1.0, 0.6, 1.1)))
        for i in range(bv["spikes"]):                # cravos na canela (Lâminas) / esporas no calcanhar (Duelista)
            if blades:
                k.append(ck.tube(P + "boots_spike%s_%d" % (tag, i), an + V((0, -0.07, 0.05 + i * 0.05)), an + V((0, -0.13, 0.08 + i * 0.05)), 0.016, 0.002, metal, 6))
            else:
                k.append(ck.tube(P + "boots_spur%s_%d" % (tag, i), an + V((sx * 0.02 * i, 0.07, 0.01)), an + V((sx * 0.03 * i, 0.13, 0.0)), 0.012, 0.004, gold, 6))
        if bv["wing"]:                               # asinha no tornozelo
            k.append(ck.blade(P + "boots_wing" + tag, an + V((sx * 0.07, 0.01, 0.06)), an + V((sx * 0.13, 0.06, 0.14)), 0.06, 0.012, glow or t2, (0, 1, 0), 0.3))
        ck._rigid(k, rig, "shin" + s)
        if bv["toe"]:                                # biqueira de metal
            ck._rigid([ck.ball(P + "boots_toe" + tag, 0.045, V(j["toe" + s]) if ("toe" + s) in j else an + V((0, -0.1, -0.04)), metal if blades else gold, (1.0, 1.2, 0.6))], rig,
                      "foot" + s if ("foot" + s) in rig.data.bones else "shin" + s)


# ---------------------------------------------------------------------------
# Armas: um par por conjunto (as duas mãos usam o mesmo desenho). dagger: lâmina curta para a frente; sword: florete/sabre fino.
# shape: straight | leaf | kris (ondulada) | fang (larga na ponta) ; guard: bar | hook | ring | cup | swept ; core = filete de veneno/brilho
ASS_WEAPONS = {
    "ass_l5": {"type": "dagger", "shape": "straight", "guard": "bar"},
    "ass_l10": {"type": "dagger", "shape": "leaf", "guard": "bar", "core": True},
    "ass_l15": {"type": "dagger", "shape": "kris", "guard": "hook", "core": True},
    "ass_l20": {"type": "dagger", "shape": "fang", "guard": "hook", "dark": True, "core": True},
    "ass_l25": {"type": "dagger", "shape": "kris", "guard": "hook", "dark": True, "core": True, "gem": True},
    "ass_l30": {"type": "dagger", "shape": "fang", "guard": "hook", "dark": True, "core": True, "gem": True},
    "ass_d5": {"type": "sword", "shape": "straight", "guard": "bar"},
    "ass_d10": {"type": "sword", "shape": "straight", "guard": "ring"},
    "ass_d15": {"type": "sword", "shape": "leaf", "guard": "cup"},
    "ass_d20": {"type": "sword", "shape": "straight", "guard": "swept", "core": True},
    "ass_d25": {"type": "sword", "shape": "fang", "guard": "cup", "gem": True, "core": True},
    "ass_d30": {"type": "sword", "shape": "straight", "guard": "swept", "gem": True, "core": True},
    # Corsário: sabre de abordagem (cutelo largo na ponta, guarda de concha/cesto) na direita; a pistola é CORSAIR_PISTOLS
    "ass_c5": {"type": "sword", "shape": "cutlass", "guard": "ring"},
    "ass_c10": {"type": "sword", "shape": "cutlass", "guard": "cup", "gem": True},
    "ass_c15": {"type": "sword", "shape": "cutlass", "guard": "swept"},
    "ass_c20": {"type": "sword", "shape": "cutlass", "guard": "cup", "core": True, "gem": True},
    "ass_c25": {"type": "sword", "shape": "cutlass", "guard": "swept", "dark": True, "core": True},
    "ass_c30": {"type": "sword", "shape": "cutlass", "guard": "swept", "gem": True, "core": True},
}
SHAPES = {"straight": (1.0, 0.85, 0.0), "leaf": (0.8, 1.25, 0.0), "kris": (1.0, 0.9, 1.0), "fang": (0.9, 1.45, 0.0),
          "cutlass": (1.05, 1.7, 0.0)}   # base, ponta, onda


def build_weapon(ck, base, mats, style, cfg, hand):
    """Adaga ou espada do conjunto na mão (main = direita, off = esquerda), 1 malha."""
    import paladin_sets
    V = Vector
    tag = ".R" if hand == "main" else ".L"
    g = V(ck.hand_center(base, tag))
    if hand == "off":                                # par misto (Trapaceiro): a mão esquerda tem tipo/forma/guarda próprios
        cfg = dict(cfg, type=cfg.get("off_type", cfg["type"]), shape=cfg.get("off_shape", cfg["shape"]), guard=cfg.get("off_guard", cfg["guard"]))
    wt = cfg["type"]
    dag = wt == "dagger"
    fwd = (V((0, -1, 0.3)) if dag else V((0, -0.55, 0.83))).normalized()
    side = V((1, 0, 0))
    ridge = fwd.cross(side).normalized()
    t, t2, gold = mats["tint"], mats["tint2"], mats["trim"]
    metal = mats["dark"] if cfg.get("dark") else mats["metal"]
    b0, b1, wave = SHAPES[cfg["shape"]]
    L, G = (0.27, 0.055) if dag else (0.66, 0.08)
    w = 0.034 if dag else 0.026
    n = "w_%s_%s_" % (style, hand)
    start = G + 0.025
    parts = [paladin_sets._blade(ck, n + "blade", g, fwd, side, start, L, w * b0, w * b1, 0.08 if dag else 0.1, 0.013, wave * 0.01, metal)]
    if cfg.get("core"):
        gm = ck.mat("m_ass_wpn_glow_%s" % ("v" if dag else "d"), (0.5, 1.0, 0.35) if dag else (1.0, 0.85, 0.55), 0.3, 2.3)
        for sg in (-1, 1):
            parts.append(paladin_sets._blade(ck, n + "core_%d" % sg, g + ridge * sg * 0.011, fwd, side, start + 0.02, L * 0.8, w * 0.3, w * 0.25, 0.03, 0.003, 0.0, gm))
    parts += [ck.tube(n + "grip", g - fwd * G, g + fwd * G, 0.021, 0.021, mats["leather"], 8),
              ck.ball(n + "pommel", 0.03 if dag else 0.036, g - fwd * (G + 0.025), gold)]
    for k in range(2 if dag else 3):
        z = -G + (k + 0.5) * 2 * G / (2 if dag else 3)
        parts.append(ck.tube(n + "wrap_%d" % k, g + fwd * (z - 0.006), g + fwd * (z + 0.006), 0.025, 0.025, t2, 8))
    gc = g + fwd * (G + 0.012)
    gd = cfg["guard"]
    if gd in ("bar", "hook", "cup", "swept", "ring"):
        parts.append(ck.tube(n + "guard", gc - side * 0.09, gc + side * 0.09, 0.016, 0.016, gold, 8))
    if gd == "hook":                                 # gancho para trás de um lado (pega a lâmina do inimigo)
        parts.append(ck.blade(n + "hook", gc + side * 0.08, gc + side * 0.13 + fwd * 0.08, 0.03, 0.012, metal, ridge))
    if gd == "cup":                                  # concha em volta da mão
        parts.append(ck.ball(n + "cup", 0.075, gc - fwd * 0.015, t, (1.0, 1.0, 0.45)))
    if gd in ("ring", "swept"):                      # arco da mão: da guarda até o pomo, por fora dos dedos
        pts = [gc + side * 0.0 - ridge * 0.0]
        for i in range(7):
            a = math.pi * i / 6
            pts.append(g + fwd * (G * math.cos(a) * 1.05) + ridge * (math.sin(a) * 0.075))
        for i in range(len(pts) - 1):
            parts.append(ck.tube(n + "bow_%d" % i, pts[i], pts[i + 1], 0.009, 0.009, gold, 6))
    if gd == "swept":                                # aros curvos extras dos dois lados
        for sx in (-1, 1):
            for i in range(5):
                a0, a1 = math.pi * i / 5, math.pi * (i + 1) / 5
                parts.append(ck.tube(n + "swept_%d_%d" % (sx, i), gc + side * sx * 0.05 * (1 + math.sin(a0)) + fwd * 0.05 * (math.cos(a0) - 1),
                                     gc + side * sx * 0.05 * (1 + math.sin(a1)) + fwd * 0.05 * (math.cos(a1) - 1), 0.008, 0.008, gold, 6))
    if cfg.get("gem"):
        for sg in (-1, 1):
            parts.append(ck.ball(n + "gem_%d" % sg, 0.024, gc + ridge * sg * 0.022, t2, (1, 0.6, 1.2)))
    name = ("wpn_main_%s_%s" if hand == "main" else "wpn_off_%s_%s") % (wt, style)
    obj = ck._join(parts, name)
    ck._smooth(obj.data)
    ck.skin_rigid(obj, base["rig"], "hand" + tag)
    return obj


# ---------------------------------------------------------------------------
# Corsário (sabre + pistola): de cima lê-se o CHAPÉU grande (tricórnio de abas viradas, bicorne atravessado, bandana) e a
# CASACA longa aberta na frente com abas largas atrás; faixa colorida na cintura, boldrié cruzado, punhos e canos de bota
# dobrados. Tapa-olho em alguns níveis, dragonas douradas no capitão, papagaio no ombro do Coral.
# head: bandana | tricorn | bicorne | bandana_tricorn | captain | ghost ; plumes: penas no chapéu ; coat: comprimento da casaca
# eyepatch: tapa-olho ; epaulets: dragonas ; parrot: papagaio no ombro ; glow: brilho (fantasma/almirante)
CORSAIR_SETS = {
    "ass_c5": {"head": "bandana", "plumes": 0, "coat": 0.2, "eyepatch": False, "epaulets": False, "tails": 2},
    "ass_c10": {"head": "tricorn", "plumes": 1, "coat": 0.24, "eyepatch": False, "epaulets": False, "tails": 2},
    "ass_c15": {"head": "bandana_tricorn", "plumes": 1, "coat": 0.26, "eyepatch": True, "epaulets": False, "tails": 2, "parrot": True},
    "ass_c20": {"head": "bicorne", "plumes": 2, "coat": 0.3, "eyepatch": False, "epaulets": True, "tails": 3, "glow": (1.0, 0.55, 0.3)},
    "ass_c25": {"head": "ghost", "plumes": 1, "coat": 0.32, "eyepatch": True, "epaulets": True, "tails": 3, "glow": (0.45, 1.0, 0.85)},
    "ass_c30": {"head": "captain", "plumes": 3, "coat": 0.36, "eyepatch": False, "epaulets": True, "tails": 3, "glow": (1.0, 0.85, 0.4)},
}
PARROT = [(0.2, 0.75, 0.3), (0.95, 0.25, 0.2), (0.25, 0.45, 0.95), (1.0, 0.85, 0.2)]


def _open_skirt(ck, name, b, body, rig, material, bottom_z, flare, gap=0.62, segs=20, rows=4):
    """Barra da casaca: como chibi_kit.skirt, mas aberta na frente (some o arco com sin(a) < -gap; a frente é -Y)."""
    import bpy
    top_z = ck.Z["waist"] - 0.02
    r0 = b["waist"] * 1.22
    verts, faces = [], []
    for i in range(rows + 1):
        t = i / rows
        z = top_z + (bottom_z - top_z) * t
        r = r0 * (1.0 + (flare - 1.0) * t ** 1.2)
        for k in range(segs + 1):
            a = 2 * math.pi * k / segs
            verts.append((math.cos(a) * r, math.sin(a) * r * b["depth"] * 1.08 + 0.012 * t, z))
    for i in range(rows):
        for k in range(segs):
            a = 2 * math.pi * (k + 0.5) / segs
            if math.sin(a) < -gap:
                continue
            a0, a1 = i * (segs + 1) + k, i * (segs + 1) + k + 1
            faces.append((a0, a1, a1 + segs + 1, a0 + segs + 1))
    me = bpy.data.meshes.new(name + "_mesh")
    me.from_pydata(verts, [], faces)
    me.update()
    obj = ck._link(bpy.data.objects.new(name, me))
    sol = obj.modifiers.new("sol", "SOLIDIFY")
    sol.thickness = 0.016
    sub = obj.modifiers.new("sub", "SUBSURF")
    sub.levels = 1
    ck._bake(obj)
    obj.data.materials.append(material)
    ck._smooth(obj.data)
    ck.transfer_weights(obj, body, rig)
    return obj


def _brim(ck, name, c, r_in, size, lift, material, segs=48, thick=0.03, edge=0.0):
    """Aba de tricórnio: anel em volta da copa com três pontas (uma para a frente, -Y). Entre as pontas a borda vira para
    cima (`lift`) e encolhe; nas pontas fica baixa e comprida. `edge` > 0 = só o debrum (faixa fina na borda)."""
    import bpy
    verts, faces = [], []
    for k in range(segs):
        a = math.tau * k / segs
        f = (math.cos(3 * (a + math.pi / 2)) + 1.0) * 0.5          # 1 nas pontas (frente e ±120°), 0 no meio dos lados
        ro = r_in * (1.0 + (size - 1.0) * (0.72 + 0.28 * f))
        ri = ro - edge if edge > 0.0 else r_in
        zo = lift * (1.0 - f) ** 1.3
        zi = zo * 0.85 if edge > 0.0 else 0.0
        verts += [(c.x + math.cos(a) * ri, c.y + math.sin(a) * ri, c.z + zi), (c.x + math.cos(a) * ro, c.y + math.sin(a) * ro, c.z + zo)]
    for k in range(segs):
        i0, i1 = 2 * k, 2 * ((k + 1) % segs)
        faces.append((i0, i1, i1 + 1, i0 + 1))
    me = bpy.data.meshes.new(name + "_mesh")
    me.from_pydata(verts, [], faces)
    me.update()
    obj = ck._link(bpy.data.objects.new(name, me))
    sol = obj.modifiers.new("sol", "SOLIDIFY")
    sol.thickness = thick
    sol.offset = 0.0
    ck._bake(obj)
    obj.data.materials.append(material)
    ck._smooth(obj.data)
    return obj


def _tricorn(ck, P, c, r, t, trim, size, upturn=1.0):
    """Tricórnio: copa + aba larga de três pontas (uma para a frente) virada para cima entre elas, com debrum dourado."""
    V = Vector
    base = c + V((0, 0, r * 0.52))
    return [ck._shell(P + "head_crown", c + V((0, 0, r * 0.2)), r * 1.06, 0.5, 0.25, 0.3, 0.035, t),
            _brim(ck, P + "head_brim", base, r * 1.0, size, r * 0.75 * upturn, t, thick=0.035),
            _brim(ck, P + "head_brimtrim", base + V((0, 0, 0.004)), r * 1.0, size + 0.03, r * 0.75 * upturn + 0.006, trim, thick=0.05, edge=r * 0.14)]


def build_corsair(ck, base, mats, style, cfg):
    import bpy
    V = Vector
    rig, body, b, j = base["rig"], base["body"], base["b"], base["j"]
    t, t2, gold, wh, dark, leather, metal = mats["tint"], mats["tint2"], mats["trim"], mats["white"], mats["dark"], mats["leather"], mats["metal"]
    glow = ck.mat("m_ass_glow_%d" % int(sum(cfg["glow"]) * 100), cfg["glow"], 0.3, 2.6) if cfg.get("glow") else None
    plume = ck.mat("m_ass_plume", PLUME, 0.85)
    bone = bone_mat(ck)
    P = "arm_%s_" % style
    c = V(base["head_c"])
    r = b["head"]
    hk = cfg["head"]
    tier = LEVELS.index(int(style[5:]))
    # ---------------- cabeça ----------------
    head = []
    hair = bpy.data.materials.get("hair") or t
    if hk != "bandana":                                  # cabelo por baixo do chapéu (cor da classe), rabo preso atrás
        head += [ck._shell(P + "head_hair", c + V((0, r * 0.04, r * 0.02)), r * 1.06, 0.25, -0.75, -0.2, 0.04, hair),
                 ck.strand(P + "head_tail", c + V((0, r * 0.95, -r * 0.1)), r * 0.7, r * 0.28, r * 0.22, hair, taper=0.9, lean=(0.0, 0.5))]
    if hk in ("bandana", "bandana_tricorn"):             # lenço amarrado na cabeça, nó e pontas soltas atrás
        bcol = t if hk == "bandana" else t2
        head += [ck._shell(P + "head_bandana", c + V((0, r * 0.05, r * 0.03)), r * 1.11, 0.36, -0.3, 0.05, 0.03, bcol),
                 ck.ball(P + "head_knot", r * 0.2, c + V((r * 0.25, r * 1.04, r * 0.2)), bcol)]
        for k in range(cfg["tails"]):
            head.append(ck.blade(P + "head_btail_%d" % k, c + V((r * 0.25, r * 1.05, r * 0.15)),
                                 c + V((r * (0.45 + 0.25 * k), r * 1.6, -r * (0.5 + 0.2 * k))), r * 0.28, 0.015, bcol, (1, 0, 0), 0.3))
        if hk == "bandana":                              # brinco de argola
            head.append(ck.tube(P + "head_earring", c + V((r * 0.98, -r * 0.05, -r * 0.35)), c + V((r * 0.98, -r * 0.05, -r * 0.29)), r * 0.13, r * 0.13, gold, 10))
    if hk in ("tricorn", "bandana_tricorn"):
        head += _tricorn(ck, P, c + V((0, 0, r * (0.05 if hk == "bandana_tricorn" else 0.0))), r, t, gold, 1.75)
        head.append(ck.tube(P + "head_band", c + V((0, 0, r * 0.55)), c + V((0, 0, r * 0.68)), r * 1.07, r * 1.05, t2, 24))
    if hk == "captain":                                  # tricórnio enorme de almirante, debrum largo e roseta
        head += _tricorn(ck, P, c + V((0, 0, r * 0.05)), r, t, gold, 2.05, 1.15)
        head += [ck.tube(P + "head_band", c + V((0, 0, r * 0.58)), c + V((0, 0, r * 0.74)), r * 1.09, r * 1.06, gold, 24),
                 ck.ball(P + "head_rosette", r * 0.24, c + V((-r * 0.7, -r * 0.75, r * 0.95)), t2, (1, 0.5, 1)),
                 ck.ball(P + "head_rosette_gem", r * 0.1, c + V((-r * 0.72, -r * 0.84, r * 0.95)), glow or gold, (1, 0.6, 1))]
    if hk == "ghost":                                    # tricórnio rasgado do navio fantasma com caveira na frente
        head += _tricorn(ck, P, c, r, dark, t2, 1.8)
        head += [ck.ball(P + "head_skull", r * 0.2, c + V((0, -r * 1.35, r * 0.95)), bone, (1.0, 0.6, 0.95)),
                 ck.ball(P + "head_skull_jaw", r * 0.12, c + V((0, -r * 1.39, r * 0.8)), bone, (1.0, 0.6, 0.8))]
        for sx in (-1, 1):
            head.append(ck.ball(P + "head_skull_eye_%d" % sx, r * 0.05, c + V((sx * r * 0.07, -r * 1.47, r * 0.98)), glow or dark))
        for k in range(4):                               # rasgos: pontas caídas no fim das abas
            a = math.tau * (k + 0.5) / 4 + math.pi / 4
            p = c + V((math.cos(a) * r * 1.3, math.sin(a) * r * 1.3, r * 0.75))
            head.append(ck.blade(P + "head_rag_%d" % k, p, p + V((math.cos(a) * r * 0.2, math.sin(a) * r * 0.2, -r * 0.45)), r * 0.3, 0.015, dark, (-math.sin(a), math.cos(a), 0), 0.3))
    if hk == "bicorne":                                  # bicorne atravessado: meia-lua alta de orelha a orelha, debrum e roseta
        head += [ck._shell(P + "head_crown", c + V((0, 0, r * 0.12)), r * 1.06, 0.45, 0.2, 0.25, 0.035, t),
                 ck.ball(P + "head_bicorne", r * 1.0, c + V((0, 0, r * 0.82)), t, (2.15, 0.42, 0.85)),
                 ck.ball(P + "head_bicorne_trim", r * 1.02, c + V((0, 0, r * 0.8)), gold, (2.2, 0.36, 0.86)),
                 ck.ball(P + "head_cockade", r * 0.24, c + V((-r * 0.9, -r * 0.42, r * 0.95)), t2, (1, 0.45, 1)),
                 ck.ball(P + "head_cockade_c", r * 0.1, c + V((-r * 0.9, -r * 0.5, r * 0.95)), glow or gold, (1, 0.6, 1))]
    for k in range(cfg["plumes"]):                       # plumas presas de um lado da copa, caindo para trás
        root = c + V((r * 0.75, r * 0.15, r * 0.95))
        tip = c + V((r * (1.35 + 0.12 * k), r * (1.15 + 0.25 * k), r * (1.75 - 0.22 * k)))
        head.append(ck.blade(P + "head_plume_%d" % k, root, tip, r * 0.62, 0.014, plume if k % 2 == 0 else (glow or t2), (1, 0, 0.2), 0.4))
    if cfg.get("eyepatch"):                              # tapa-olho no olho direito + correia em volta da cabeça
        head += [ck.ball(P + "head_patch", r * 0.2, c + V((-r * 0.36, -r * 1.0, r * 0.08)), dark, (1.0, 0.35, 0.85)),
                 ck.tube(P + "head_patch_strap", c + V((0, 0, r * 0.16)), c + V((0, 0, r * 0.22)), r * 1.06, r * 1.06, dark, 24)]
    ck._rigid(head, rig, "head")
    # ---------------- corpo: casaca aberta, abas atrás, babado, boldrié e faixa ----------------
    ck.armor_piece(body, rig, P + "body_coat", "torso", t, 0.013, 0.015, 0.03)
    ck.armor_piece(body, rig, P + "body_legs", "legs", leather if tier % 2 == 0 else dark, 0.008, 0.012)
    zc, zn, zw = ck.Z["chest"], ck.Z["neck"], ck.Z["waist"]
    L = cfg["coat"]
    _open_skirt(ck, P + "body_coatskirt", b, body, rig, t, zw - L, 1.55 + 0.1 * tier)
    d = b["depth"]
    front = -b["chest"] * d - 0.03
    back = b["chest"] * d + 0.03
    chest = [ck.box(P + "body_shirt", (0.1, 0.02, 0.24), (0, front + 0.006, zc - 0.02), wh, 0.006)]      # camisa branca aparecendo na abertura
    for k in range(3):                                   # babado (jabô) no pescoço
        chest.append(ck.blade(P + "body_jabot_%d" % k, (0.0, front - 0.004, zn - 0.03 - k * 0.035), ((k - 1) * 0.03, front - 0.03, zn - 0.08 - k * 0.04),
                              0.07 - k * 0.01, 0.012, wh, (1, 0, 0), 0.4))
    for sx in (-1, 1):                                   # lapelas largas dobradas com debrum, botões dourados
        chest += [ck.box(P + "body_lapel_%d" % sx, (0.045, 0.018, 0.26), (sx * 0.075, front - 0.002, zc - 0.02), t2, 0.006),
                  ck.box(P + "body_lapel_trim_%d" % sx, (0.01, 0.02, 0.26), (sx * 0.1, front - 0.006, zc - 0.02), gold, 0.002)]
        for k in range(3):
            chest.append(ck.ball(P + "body_button_%d_%d" % (sx, k), 0.013, (sx * 0.075, front - 0.012, zc + 0.06 - k * 0.07), gold))
    chest.append(ck.tube(P + "body_collar", V((0, 0, zn - 0.04)), V((0, 0, zn + 0.05)), b["chest"] * 0.55, b["chest"] * 0.62, t, 16))
    s0, s1 = V((-0.15, front + 0.005, zc + 0.15)), V((0.15, front * 1.05, zw - 0.02))      # boldrié: ombro direito ao quadril esquerdo
    chest += [ck.tube(P + "body_baldric", s0, s1, 0.02, 0.02, leather, 6),
              ck.tube(P + "body_baldric_b", V((-0.15, back - 0.005, zc + 0.15)), V((0.15, back, zw - 0.02)), 0.02, 0.02, leather, 6),
              ck.box(P + "body_baldric_buckle", (0.045, 0.02, 0.04), s0.lerp(s1, 0.45) + V((0, -0.016, 0)), gold, 0.005)]
    for sx in (-1, 1):                                   # abas compridas da casaca atrás, com debrum
        chest += [ck.blade(P + "body_coattail_%d" % sx, (sx * 0.07, back - 0.01, zw + 0.03), (sx * 0.13, back + 0.08, zw - L - 0.16),
                           0.15, 0.016, t, (1, 0, 0), 0.6),
                  ck.blade(P + "body_coattrim_%d" % sx, (sx * 0.08, back + 0.0, zw - L * 0.7), (sx * 0.135, back + 0.085, zw - L - 0.165),
                           0.155, 0.018, gold, (1, 0, 0), 0.6)]
    if glow:
        chest.append(ck.ball(P + "body_brooch", 0.026, (0.07, front - 0.02, zn - 0.06), glow))
    if cfg.get("parrot"):                                # papagaio no ombro direito (de cima, uma mancha de cor viva)
        pm = [ck.mat("m_ass_parrot_%d" % i, c_, 0.6) for i, c_ in enumerate(PARROT)]
        sh = V(j["shoulder.R"]) + V((-0.03, 0.03, 0.12))
        S = 1.6
        chest += [ck.ball(P + "body_parrot", 0.055 * S, sh + V((0, 0, 0.04 * S)), pm[1], (0.9, 1.0, 1.25)),
                  ck.ball(P + "body_parrot_head", 0.04 * S, sh + V((0, -0.02 * S, 0.11 * S)), pm[1]),
                  ck.tube(P + "body_parrot_beak", sh + V((0, -0.055 * S, 0.11 * S)), sh + V((0, -0.085 * S, 0.09 * S)), 0.016 * S, 0.003, pm[3], 6),
                  ck.blade(P + "body_parrot_wing", sh + V((-0.05 * S, 0.0, 0.07 * S)), sh + V((-0.06 * S, 0.06 * S, -0.02)), 0.06 * S, 0.015, pm[2], (0, 1, 0), 0.4),
                  ck.blade(P + "body_parrot_wing2", sh + V((0.05 * S, 0.0, 0.07 * S)), sh + V((0.06 * S, 0.06 * S, -0.02)), 0.06 * S, 0.015, pm[2], (0, 1, 0), 0.4),
                  ck.blade(P + "body_parrot_tail", sh + V((0, 0.04 * S, 0.0)), sh + V((0, 0.14 * S, -0.12 * S)), 0.05 * S, 0.012, pm[0], (1, 0, 0), 0.3)]
    ck._rigid(chest, rig, "chest")
    sash = ck.tube(P + "body_sash", (0, 0, zw - 0.04), (0, 0, zw + 0.04), b["waist"] * 1.24, b["waist"] * 1.24, t2, 16)      # faixa larga na cintura
    for v in sash.data.vertices:
        v.co.y *= d * 1.08
    ck._smooth(sash.data)
    ck.transfer_weights(sash, body, rig)
    wf = -b["waist"] * d * 1.24
    hips = [ck.ball(P + "body_sash_knot", 0.04, (-0.13, wf * 0.75, zw), t2, (1, 0.8, 1))]
    for k in range(cfg["tails"]):                        # pontas da faixa caindo do lado esquerdo do quadril
        hips.append(ck.blade(P + "body_sash_tail_%d" % k, (-0.13, wf * 0.75, zw - 0.02), (-0.17 - k * 0.03, wf * 0.6, zw - 0.2 - k * 0.05),
                             0.06, 0.012, t2, (0, 1, 0), 0.3))
    hips.append(ck.box(P + "body_holster", (0.05, 0.03, 0.1), (0.15, wf * 0.45, zw - 0.08), leather, 0.01))       # coldre vazio do lado da pistola
    ck._rigid(hips, rig, "hips")
    if cfg.get("epaulets"):                              # dragonas douradas com franja nos dois ombros
        for s, sx in ((".R", -1), (".L", 1)):
            sh = V(j["shoulder" + s])
            pa = [ck.ball(P + "body_epaulet" + s.replace(".", "_"), b["arm"] * 2.0, sh + V((sx * 0.04, 0, 0.05)), gold, (1.15, 1.0, 0.35))]
            for k in range(5):
                pa.append(ck.tube(P + "body_fringe%s_%d" % (s.replace(".", "_"), k), sh + V((sx * 0.1, (k - 2) * 0.025, 0.04)),
                                  sh + V((sx * 0.12, (k - 2) * 0.027, -0.05)), 0.008, 0.006, gold, 4))
            ck._rigid(pa, rig, "upper_arm" + s)
    # ---------------- braços: punho largo virado da casaca ----------------
    for s in (".R", ".L"):
        tag = s.replace(".", "_")
        el, wr = V(j["elbow" + s]), V(j["wrist" + s])
        g = [ck.tube(P + "gloves_cuff" + tag, el.lerp(wr, 0.35), wr + V((0, 0, 0.01)), 0.078, 0.112, t, 14),
             ck.tube(P + "gloves_cuff_rim" + tag, wr + V((0, 0, 0.0)), wr + V((0, 0, 0.018)), 0.114, 0.114, gold, 14),
             ck.tube(P + "gloves_ruffle" + tag, wr - V((0, 0, 0.012)), wr - V((0, 0, 0.03)), 0.07, 0.085, wh, 12)]
        ck._rigid(g, rig, "forearm" + s)
        ck._rigid([ck.ball(P + "gloves_fist" + tag, b["hand"] * 1.22, ck.hand_center(base, s), leather, (1, 1, 1.1))], rig, "hand" + s)
    # ---------------- botas de cano alto dobrado (balde), fivela; cano sobe com o nível ----------------
    ck.armor_piece(body, rig, P + "boots_shell", "boots", dark, 0.022, 0.016)
    for s, sx in ((".R", -1), (".L", 1)):
        tag = s.replace(".", "_")
        kn, an = V(j["knee" + s]), V(j["ankle" + s])
        top = an.lerp(kn, 0.7 + 0.05 * min(tier, 4))
        k = [ck.tube(P + "boots_bucket" + tag, top - V((0, 0, 0.02)), top + V((0, 0, 0.05)), 0.095, 0.12 + tier * 0.004, leather, 14),
             ck.tube(P + "boots_bucket_rim" + tag, top + V((0, 0, 0.045)), top + V((0, 0, 0.06)), 0.121 + tier * 0.004, 0.121 + tier * 0.004, t2, 14),
             ck.tube(P + "boots_strap" + tag, an + V((0, 0, 0.04)), an + V((0, 0, 0.058)), 0.083, 0.083, leather, 12),
             ck.box(P + "boots_buckle" + tag, (0.026, 0.01, 0.022), an + V((sx * 0.07, -0.03, 0.05)), gold, 0.003)]
        if tier >= 3:
            k.append(ck.tube(P + "boots_spur" + tag, an + V((0, 0.07, 0.02)), an + V((0, 0.13, 0.01)), 0.012, 0.004, gold, 6))
        ck._rigid(k, rig, "shin" + s)


# Pistolas de pederneira (mão esquerda). Coronha na mão, cano saindo da frente do punho.
# barrel: comprimento ; double: dois canos ; bell: boca de bacamarte ; carved: coronha na cor do item ; dark: metal escuro
# skull: caveira no pomo ; gem: pedra no fecho ; glow: filete brilhante no cano
def pistol_parts(ck, n, g, mats, cfg, glow=None):
    """Partes da pistola no eixo das armas do kit: `fwd` = eixo do punho (como o cabo de uma espada), o cano sai
    perpendicular, para a frente (onde aponta o braço esticado)."""
    V = Vector
    fwd = V((0, -0.55, 0.83)).normalized()
    side = V((1, 0, 0))
    bar = -fwd.cross(side).normalized()                  # para a frente/baixo com o braço solto; para o alvo com ele esticado
    t, t2, gold = mats["tint"], mats["tint2"], mats["trim"]
    wood = t if cfg.get("carved") else mats["wood"]
    metal = mats["dark"] if cfg.get("dark") else mats["metal"]
    Lb = cfg.get("barrel", 0.3)
    top = g + fwd * 0.07                                 # culatra (em cima do punho)
    parts = [ck.tube(n + "grip", g - fwd * 0.07 - bar * 0.035, top - bar * 0.01, 0.026, 0.021, wood, 8),
             ck.ball(n + "butt", 0.032, g - fwd * 0.08 - bar * 0.04, mats["dark"] if cfg.get("skull") else gold, (1, 1, 1.2)),
             ck.box(n + "lock", (0.03, 0.07, 0.045), top + bar * 0.01, metal, 0.006),
             ck.tube(n + "stock", top - bar * 0.02 - fwd * 0.012, top + bar * Lb * 0.62 - fwd * 0.012, 0.024, 0.02, wood, 8),
             ck.blade(n + "hammer", top - bar * 0.025 + fwd * 0.015, top - bar * 0.055 + fwd * 0.065, 0.025, 0.012, metal, side),
             ck.tube(n + "guard", g + bar * 0.035 + fwd * 0.0, top + bar * 0.05 - fwd * 0.03, 0.007, 0.007, gold, 6),
             ck.tube(n + "trigger", top + bar * 0.02 - fwd * 0.02, top + bar * 0.025 - fwd * 0.045, 0.006, 0.004, gold, 4)]
    barrels = (-0.018, 0.018) if cfg.get("double") else (0.0,)
    for bx in barrels:
        a = top + side * bx + fwd * 0.006
        parts += [ck.tube(n + "barrel%d" % int(bx * 1000), a - bar * 0.02, a + bar * Lb, 0.019, 0.017, metal, 8),
                  ck.tube(n + "muzzle%d" % int(bx * 1000), a + bar * (Lb - 0.02), a + bar * (Lb + 0.01), 0.04 if cfg.get("bell") else 0.024,
                          0.05 if cfg.get("bell") else 0.026, gold, 10)]
    for k in range(2):
        z = 0.12 + k * 0.1
        parts.append(ck.tube(n + "band%d" % k, top + bar * z - fwd * 0.004, top + bar * (z + 0.016) - fwd * 0.004, 0.028, 0.028, gold, 8))
    if cfg.get("skull"):
        parts.append(ck.ball(n + "skull", 0.03, g - fwd * 0.11 - bar * 0.05, ck.mat("m_ass_beak", (0.9, 0.86, 0.74), 0.6), (1, 0.9, 1)))
    if cfg.get("gem"):
        parts.append(ck.ball(n + "gem", 0.016, top + side * 0.02 + bar * 0.01, t2, (0.5, 1, 1)))
    if glow and cfg.get("glow"):
        parts.append(ck.tube(n + "rune", top + bar * 0.05 + fwd * 0.024, top + bar * (Lb - 0.03) + fwd * 0.024, 0.008, 0.008, glow, 6))
    return parts


def build_pistol(ck, base, mats, style, cfg):
    V = Vector
    g = V(ck.hand_center(base, ".L"))
    glow = ck.mat("m_ass_pistol_glow_g", (0.45, 1.0, 0.85), 0.3, 2.5) if cfg.get("ghost") else ck.mat("m_ass_pistol_glow", (1.0, 0.7, 0.3), 0.3, 2.5)
    obj = ck._join(pistol_parts(ck, "p_%s_" % style, g, mats, cfg, glow), "wpn_off_pistol_%s" % style)
    ck._smooth(obj.data)
    ck.skin_rigid(obj, base["rig"], "hand.L")
    return obj


CORSAIR_PISTOLS = {
    "ass_c5": {"barrel": 0.26},
    "ass_c10": {"barrel": 0.3, "gem": True},
    "ass_c15": {"barrel": 0.24, "bell": True, "carved": True},
    "ass_c20": {"barrel": 0.3, "double": True, "gem": True},
    "ass_c25": {"barrel": 0.32, "dark": True, "skull": True, "glow": True, "ghost": True},
    "ass_c30": {"barrel": 0.34, "double": True, "carved": True, "gem": True, "glow": True},
}


def bone_mat(ck):
    return ck.mat("m_ass_beak", (0.9, 0.86, 0.74), 0.6)


def register(ck):
    import paladin_sets
    for style, cfg in CORSAIR_SETS.items():
        ck.SET_STYLES[style] = (lambda st, cf: (lambda base, mats: (build_corsair(ck, base, mats, st, cf), paladin_sets.join_slots("arm_%s_" % st))))(style, cfg)
    for style, cfg in ASS_SETS.items():
        ck.SET_STYLES[style] = (lambda st, cf: (lambda base, mats: (build(ck, base, mats, st, cf), paladin_sets.join_slots("arm_%s_" % st))))(style, cfg)
    for style, cfg in ASS_WEAPONS.items():
        for hand in ("main", "off"):
            if hand == "off" and style in CORSAIR_PISTOLS:          # Corsário: a mão esquerda é a pistola do conjunto
                ck.SET_WEAPONS["%s_off" % style] = (lambda st, cf: (lambda base, mats: build_pistol(ck, base, mats, st, cf)))(style, CORSAIR_PISTOLS[style])
                continue
            ck.SET_WEAPONS["%s_%s" % (style, hand)] = (lambda st, cf, h: (lambda base, mats: build_weapon(ck, base, mats, st, cf, h)))(style, cfg, hand)
