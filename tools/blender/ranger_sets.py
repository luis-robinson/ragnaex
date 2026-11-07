"""Conjuntos lendários do Ranger (18), arcos do Caçador e do Patrulheiro e mosquetes do Atirador, por construtor paramétrico.

Linguagem visual (original; só o "clima" de arqueiro clássico de MMO): couro leve, chapéu com pena ou capuz com
capinha, colete, aljava nas costas, braçadeira de arqueiro, capa curta de barra recortada. O Atirador troca a aljava
por bandoleira com frascos de pólvora, chapéu de três pontas ou óculos de latão, ombreira acolchoada do lado do coice.
O Patrulheiro (arco veloz, armadilhas e lentidão) lê de cima pela aba larga: chapéu de aba caída presa de um lado ou
capuz fundo com máscara de pano, capinha recortada cobrindo os dois ombros, aljava curta no quadril, faixas nas canelas.
Peças: arm_<estilo>_<head|body|gloves|boots>_*; armas: wpn_main_bow_<estilo> (mão esquerda) e wpn_main_rifle_<estilo>.
"""
import math
from mathutils import Vector

# head: feather_cap | hood | circlet | tricorn | goggles | slouch | cowl ; mantle: capinha recortada nos ombros ; wraps: faixas na canela
# back: quiver | bandolier | hip_quiver ; shoulder: bow | recoil | none ; strips: tiras da capa (padrão 5)
# cape: comprimento da capa (0 = sem) ; back: quiver | bandolier
# feathers: nº de penas no chapéu/aljava ; shoulder: bow (ombreira na esquerda) | recoil (acolchoada na direita)
RAN_SETS = {
    # ---- Caçador (arco + companheiro) ----
    "ran_c5": {"head": "feather_cap", "cape": 0.0, "back": "quiver", "feathers": 1, "shoulder": "bow", "scarf": False},
    "ran_c10": {"head": "hood", "cape": 0.22, "back": "quiver", "feathers": 2, "shoulder": "bow", "scarf": False},
    "ran_c15": {"head": "feather_cap", "cape": 0.26, "back": "quiver", "feathers": 3, "shoulder": "bow", "scarf": True},
    "ran_c20": {"head": "circlet", "cape": 0.3, "back": "quiver", "feathers": 3, "shoulder": "bow", "scarf": True, "glow": (0.6, 1.0, 0.7)},
    "ran_c25": {"head": "hood", "cape": 0.34, "back": "quiver", "feathers": 4, "shoulder": "bow", "scarf": True, "glow": (0.7, 0.85, 1.0)},
    "ran_c30": {"head": "circlet", "cape": 0.4, "back": "quiver", "feathers": 5, "shoulder": "bow", "scarf": True, "glow": (1.0, 0.9, 0.55)},
    # ---- Atirador (mosquete + armadilhas) ----
    "ran_a5": {"head": "tricorn", "cape": 0.0, "back": "bandolier", "feathers": 0, "shoulder": "recoil", "scarf": True},
    "ran_a10": {"head": "goggles", "cape": 0.2, "back": "bandolier", "feathers": 0, "shoulder": "recoil", "scarf": True},
    "ran_a15": {"head": "tricorn", "cape": 0.28, "back": "bandolier", "feathers": 1, "shoulder": "recoil", "scarf": True},
    "ran_a20": {"head": "goggles", "cape": 0.3, "back": "bandolier", "feathers": 0, "shoulder": "recoil", "scarf": False, "glow": (1.0, 0.6, 0.25)},
    "ran_a25": {"head": "tricorn", "cape": 0.34, "back": "bandolier", "feathers": 2, "shoulder": "recoil", "scarf": True, "glow": (0.55, 0.85, 1.0)},
    "ran_a30": {"head": "tricorn", "cape": 0.4, "back": "bandolier", "feathers": 3, "shoulder": "recoil", "scarf": True, "glow": (1.0, 0.75, 0.3)},
    # ---- Patrulheiro (arco veloz + armadilhas, sem bicho) ----
    "ran_p5": {"head": "slouch", "cape": 0.0, "back": "hip_quiver", "feathers": 1, "shoulder": "none", "scarf": False, "mantle": True, "wraps": True},
    "ran_p10": {"head": "cowl", "cape": 0.3, "back": "hip_quiver", "feathers": 2, "shoulder": "none", "scarf": False, "mantle": True, "wraps": True, "strips": 7},
    "ran_p15": {"head": "slouch", "cape": 0.34, "back": "hip_quiver", "feathers": 2, "shoulder": "none", "scarf": True, "mantle": True, "wraps": True, "strips": 7},
    "ran_p20": {"head": "cowl", "cape": 0.38, "back": "hip_quiver", "feathers": 3, "shoulder": "none", "scarf": False, "mantle": True, "wraps": True, "strips": 7, "glow": (0.55, 1.0, 0.85)},
    "ran_p25": {"head": "slouch", "cape": 0.42, "back": "hip_quiver", "feathers": 3, "shoulder": "none", "scarf": True, "mantle": True, "wraps": True, "strips": 7, "glow": (0.8, 0.6, 1.0)},
    "ran_p30": {"head": "cowl", "cape": 0.48, "back": "hip_quiver", "feathers": 4, "shoulder": "none", "scarf": False, "mantle": True, "wraps": True, "strips": 9, "glow": (0.85, 1.0, 0.5)},
}
FEATHER = (0.95, 0.94, 0.9)
BRASS = (0.85, 0.62, 0.28)


def _feather(ck, name, root, tip, width, material, wdir=(1, 0, 0)):
    return ck.blade(name, root, tip, width, 0.012, material, wdir, 0.4)


def build(ck, base, mats, style, cfg):
    V = Vector
    rig, body, b, j = base["rig"], base["body"], base["b"], base["j"]
    t, t2, gold, wh, dark, leather = mats["tint"], mats["tint2"], mats["trim"], mats["white"], mats["dark"], mats["leather"]
    feather = ck.mat("m_ran_feather", FEATHER, 0.8)
    brass = ck.mat("m_ran_brass", BRASS, 0.35)
    glow = ck.mat("m_ran_glow_%d" % int(sum(cfg["glow"]) * 100), cfg["glow"], 0.3, 2.6) if cfg.get("glow") else None
    P = "arm_%s_" % style
    c = V(base["head_c"])
    r = b["head"]
    # ---------------- cabeça ----------------
    hk = cfg["head"]
    head = []
    if hk == "feather_cap":        # gorro mole de aba curta, pena longa caída para trás
        head += [ck._shell(P + "head_cap", c + V((0, r * 0.05, r * 0.08)), r * 1.13, 0.42, -0.1, 0.12, 0.035, t),
                 ck.tube(P + "head_brim", c + V((0, -r * 0.05, r * 0.42)), c + V((0, -r * 0.05, r * 0.5)), r * 1.22, r * 1.2, t2, 24)]
    elif hk == "hood":             # capuz de caçador com ponta e capinha nos ombros
        head += [ck._shell(P + "head_hood", c, r * 1.17, 0.3, -1.0, -0.5, 0.035, t),
                 ck.strand(P + "head_tip", c + V((0, r * 0.75, r * 0.55)), r * 0.85, r * 0.5, r * 0.38, t, taper=0.9, lean=(0.0, 0.8))]
    elif hk == "circlet":          # aro de folhas e uma pedra na testa
        head.append(ck.tube(P + "head_circlet", c + V((0, 0, r * 0.4)), c + V((0, 0, r * 0.52)), r * 1.12, r * 1.1, gold, 24))
        for k in range(8):
            a = math.pi * (0.15 + 0.7 * k / 7.0) + math.pi
            d = V((math.cos(a), math.sin(a), 0))
            head.append(ck.blade(P + "head_leaf_%d" % k, c + d * r * 1.1 + V((0, 0, r * 0.47)), c + d * r * 1.25 + V((0, 0, r * 0.75)), r * 0.2, 0.02, t2, V((-d.y, d.x, 0))))
        head.append(ck.ball(P + "head_gem", 0.035, c + V((0, -r * 1.13, r * 0.48)), glow or t2, (1, 0.6, 1.3)))
    elif hk == "tricorn":          # chapéu de três pontas
        head.append(ck._shell(P + "head_crown", c + V((0, 0, r * 0.12)), r * 1.08, 0.48, 0.2, 0.25, 0.035, t))
        for k in range(3):
            a = math.tau * k / 3 - math.pi / 2
            d = V((math.cos(a), math.sin(a), 0))
            head.append(ck.blade(P + "head_brim_%d" % k, c + V((0, 0, r * 0.5)), c + d * r * 1.45 + V((0, 0, r * 1.08)), r * 1.55, 0.05, t, V((-d.y, d.x, 0)), 0.55))     # pontas viradas para cima
        head.append(ck.tube(P + "head_band", c + V((0, 0, r * 0.55)), c + V((0, 0, r * 0.66)), r * 1.06, r * 1.04, t2, 24))
    elif hk == "goggles":          # boné de couro com óculos de latão em cima da aba
        head += [ck._shell(P + "head_cap", c, r * 1.14, 0.35, -0.3, -0.05, 0.035, leather),
                 ck.tube(P + "head_strap", c + V((0, 0, r * 0.42)), c + V((0, 0, r * 0.5)), r * 1.18, r * 1.16, dark, 24)]
        for sx in (-1, 1):
            p = c + V((sx * r * 0.32, -r * 1.05, r * 0.55))
            head += [ck.tube(P + "head_lens_rim_%d" % sx, p + V((0, 0.02, 0)), p - V((0, 0.03, 0)), r * 0.24, r * 0.22, brass, 12),
                     ck.ball(P + "head_lens_%d" % sx, r * 0.18, p - V((0, 0.03, 0)), glow or t2, (1, 0.4, 1))]
    elif hk == "slouch":           # chapéu de patrulheiro: copa baixa e aba larga caída, presa para cima do lado esquerdo
        head += [ck._shell(P + "head_crown", c + V((0, 0, r * 0.12)), r * 1.08, 0.5, -0.05, 0.3, 0.035, t),
                 ck.tube(P + "head_brim", c + V((0, 0, r * 0.45)), c + V((0, 0, r * 0.45)) + V((0.0, -0.05, 1.0)).normalized() * 0.022, r * 1.8, r * 1.74, t, 28),
                 ck.tube(P + "head_band", c + V((0, 0, r * 0.52)), c + V((0, 0, r * 0.66)), r * 1.08, r * 1.05, t2, 24),
                 ck.blade(P + "head_pinned", c + V((r * 1.05, 0, r * 0.5)), c + V((r * 1.35, r * 0.1, r * 1.15)), r * 1.4, 0.03, t, (0, 1, 0), 0.5)]
        if glow:
            head.append(ck.ball(P + "head_pin", r * 0.12, c + V((r * 1.12, -r * 0.05, r * 0.8)), glow, (0.5, 1, 1)))
    elif hk == "cowl":             # capuz fundo, ponta longa caída nas costas e máscara de pano no rosto
        head += [ck._shell(P + "head_cowl", c + V((0, r * 0.04, r * 0.04)), r * 1.22, 0.22, -1.0, -0.6, 0.04, t),
                 ck.strand(P + "head_tail", c + V((0, r * 0.9, r * 0.2)), r * 1.3, r * 0.7, r * 0.4, t, taper=0.95, lean=(0.0, 0.5)),
                 ck.ball(P + "head_mask", r * 0.5, c + V((0, -r * 0.6, -r * 0.5)), t2, (1.3, 0.8, 0.55))]
        if glow:
            head.append(ck.ball(P + "head_clasp", r * 0.13, c + V((0, -r * 1.12, r * 0.62)), glow, (1, 0.5, 1.4)))
    for k in range(cfg["feathers"] if hk in ("feather_cap", "tricorn", "slouch") else 0):     # penas no chapéu
        a = 0.35 + k * 0.25
        head.append(_feather(ck, P + "head_feather_%d" % k, c + V((r * 0.5, r * 0.2, r * 0.75)),
                             c + V((r * (0.9 + k * 0.12), r * (1.1 + k * 0.1), r * (1.4 - k * 0.15))), r * 0.3, feather if k % 2 == 0 else t2, (math.cos(a), 0, math.sin(a))))
    ck._rigid(head, rig, "head")
    # ---------------- corpo ----------------
    ck.armor_piece(body, rig, P + "body_vest", "torso", t, 0.012, 0.014, 0.02)
    ck.armor_piece(body, rig, P + "body_legs", "legs", leather, 0.008, 0.012)
    d = b["depth"]
    front = -b["chest"] * d - 0.03
    back = b["chest"] * d + 0.03
    zc = ck.Z["chest"]
    chest = [ck.box(P + "body_lacing", (0.04, 0.02, 0.2), (0, front, zc - 0.04), t2, 0.005)]
    for k in range(3):
        chest.append(ck.box(P + "body_lace_%d" % k, (0.09, 0.015, 0.012), (0, front - 0.012, zc + 0.04 - k * 0.06), gold, 0.002))
    if cfg.get("scarf"):           # lenço no pescoço com ponta caindo
        chest += [ck.tube(P + "body_scarf", V((0, 0, ck.Z["neck"] - 0.04)), V((0, 0, ck.Z["neck"] + 0.02)), b["chest"] * 0.55, b["chest"] * 0.48, t2, 14),
                  ck.blade(P + "body_scarf_tail", (0.05, front + 0.01, ck.Z["neck"] - 0.04), (0.09, front - 0.01, zc - 0.05), 0.07, 0.015, t2, (1, 0, 0))]
    if cfg["back"] == "quiver":    # aljava nas costas, inclinada, com penas das flechas
        q0 = V((0.08, back + 0.04, zc - 0.14))
        q1 = V((-0.06, back + 0.06, zc + 0.16))
        chest += [ck.tube(P + "body_quiver", q0, q1, 0.06, 0.07, leather, 10),
                  ck.tube(P + "body_quiver_rim", q1, q1 + (q1 - q0).normalized() * 0.02, 0.075, 0.075, gold, 10),
                  ck.tube(P + "body_quiver_strap", (0.15, front + 0.02, zc + 0.14), (-0.13, front + 0.02, ck.Z["waist"] + 0.04), 0.018, 0.018, leather, 6)]
        for k in range(max(2, cfg["feathers"])):
            off = V(((k - 1) * 0.025, 0.0, 0.0))
            chest.append(_feather(ck, P + "body_fletch_%d" % k, q1 + off, q1 + off + (q1 - q0).normalized() * 0.11, 0.035, feather if k % 2 == 0 else t2))
    elif cfg["back"] == "hip_quiver":     # aljava curta no quadril (vai nos quadris, abaixo)
        pass
    else:                          # bandoleira com frascos de pólvora e cartuchos
        chest.append(ck.tube(P + "body_bandolier", (-0.15, front + 0.02, zc + 0.14), (0.13, front + 0.02, ck.Z["waist"] + 0.04), 0.024, 0.024, dark, 6))
        for k in range(5):
            tt = (k + 0.5) / 5
            p = V((-0.15, front + 0.01, zc + 0.14)).lerp(V((0.13, front + 0.01, ck.Z["waist"] + 0.04)), tt)
            chest.append(ck.tube(P + "body_cartridge_%d" % k, p, p + V((0, -0.025, 0.035)), 0.014, 0.014, brass, 6))
        chest += [ck.ball(P + "body_flask", 0.045, (0.1, back + 0.02, zc - 0.05), brass, (1, 0.7, 1.3)),
                  ck.ball(P + "body_flask_cap", 0.02, (0.1, back + 0.02, zc + 0.02), dark)]
    if glow:
        chest.append(ck.ball(P + "body_charm", 0.026, (-0.07, front - 0.02, zc + 0.08), glow))
    if cfg.get("mantle"):          # capinha recortada cobrindo os dois ombros (de cima, um anel de pano em volta do pescoço)
        rw = abs(V(j["shoulder.L"]).x) + b["arm"] * 2.3
        zt = ck.Z["neck"] - 0.02
        mt = ck.tube(P + "body_mantle", (0, 0, zt - 0.11), (0, 0, zt), rw, b["chest"] * 0.5, t2, 18)
        for v in mt.data.vertices:
            v.co.y *= 0.8
        chest.append(mt)
        n_d = 10
        for k in range(n_d):       # barra em pontas
            a = math.tau * (k + 0.5) / n_d
            dv = V((math.cos(a), math.sin(a) * 0.8, 0))
            chest.append(ck.blade(P + "body_dag_%d" % k, dv * rw * 0.97 + V((0, 0, zt - 0.1)), dv * rw * 1.04 + V((0, 0, zt - 0.2)), rw * 0.55, 0.012, t2 if k % 2 else t, V((-dv.y, dv.x, 0)), 0.3))
        chest.append(ck.ball(P + "body_brooch", 0.03, (0.0, -b["chest"] * 0.5 - 0.02, zt - 0.03), glow or gold, (1, 0.5, 1)))
    if cfg["cape"] > 0.0:          # capa curta de barra recortada (de cima, a capa é o que aparece)
        L = cfg["cape"]
        ns = cfg.get("strips", 5)
        for k in range(ns):
            x = (k - (ns - 1) / 2.0) * (0.28 / (ns - 1))
            chest.append(ck.blade(P + "body_cape_%d" % k, (x * 0.8, back + 0.02, ck.Z["neck"] - 0.05), (x * 1.2, back + 0.08, ck.Z["neck"] - 0.05 - L - (k % 2) * 0.04),
                                  0.1, 0.015, t if k % 2 == 0 else t2, (1, 0, 0), 0.2))
    ck._rigid(chest, rig, "chest")
    belt = ck.tube(P + "body_belt", (0, 0, ck.Z["waist"] - 0.035), (0, 0, ck.Z["waist"] + 0.03), b["waist"] * 1.18, b["waist"] * 1.18, leather, 16)
    for v in belt.data.vertices:
        v.co.y *= d * 1.05
    ck._smooth(belt.data)
    ck.transfer_weights(belt, body, rig)
    hips = [ck.box(P + "body_buckle", (0.06, 0.025, 0.05), (0, -b["waist"] * d * 1.2 - 0.01, ck.Z["waist"]), brass if cfg["back"] == "bandolier" else gold, 0.008),
            ck.ball(P + "body_pouch", 0.045, (-0.11, -b["waist"] * d * 1.12 - 0.02, ck.Z["waist"] - 0.04), leather, (1, 0.6, 1)),
            ck.box(P + "body_tasset_f", (0.12, 0.014, 0.12), (0, -b["waist"] * d * 1.18 - 0.012, ck.Z["waist"] - 0.1), t, 0.004)]
    if cfg["back"] == "hip_quiver":       # aljava curta pendurada no quadril direito, inclinada para trás
        q0 = V((-b["waist"] * 1.2 - 0.03, 0.05, ck.Z["waist"] - 0.2))
        q1 = V((-b["waist"] * 1.15 - 0.05, 0.1, ck.Z["waist"] + 0.04))
        hips += [ck.tube(P + "body_hquiver", q0, q1, 0.05, 0.06, leather, 10),
                 ck.tube(P + "body_hquiver_rim", q1, q1 + (q1 - q0).normalized() * 0.02, 0.065, 0.065, gold, 10)]
        for k in range(max(2, cfg["feathers"])):
            off = V((0.0, (k - 1) * 0.022, 0.0))
            hips.append(_feather(ck, P + "body_hfletch_%d" % k, q1 + off, q1 + off + (q1 - q0).normalized() * 0.1, 0.032, feather if k % 2 == 0 else t2, (0, 1, 0)))
    ck._rigid(hips, rig, "hips")
    if cfg["shoulder"] != "none":
        _pauldron(ck, rig, b, j, P, cfg, t, gold, leather, brass, feather)
    _arms_boots(ck, base, rig, body, b, j, P, cfg, t, t2, leather)


def _pauldron(ck, rig, b, j, P, cfg, t, gold, leather, brass, feather):
    V = Vector
    side = ".L" if cfg["shoulder"] == "bow" else ".R"
    sx = 1 if side == ".L" else -1
    sh = V(j["shoulder" + side])
    pa = [ck.ball(P + "body_pauldron", b["arm"] * 2.4, sh + V((sx * 0.06, 0, 0.05)), t if cfg["shoulder"] == "bow" else leather, (1.1, 1.05, 0.6)),
          ck.ball(P + "body_pauldron_rim", b["arm"] * 2.47, sh + V((sx * 0.06, 0, 0.025)), gold if cfg["shoulder"] == "bow" else brass, (1.12, 1.07, 0.15))]
    if cfg["shoulder"] == "bow" and cfg["feathers"] >= 3:
        for k in range(2):
            pa.append(_feather(ck, P + "body_pfeather_%d" % k, sh + V((sx * 0.1, 0.02, 0.1)), sh + V((sx * (0.2 + k * 0.05), 0.06, 0.2 - k * 0.05)), 0.05, feather, (0, 1, 0)))
    ck._rigid(pa, rig, "upper_arm" + side)


def _arms_boots(ck, base, rig, body, b, j, P, cfg, t, t2, leather):
    V = Vector
    # ---------------- braços: braçadeira de arqueiro / luvas ----------------
    for s, sxx in ((".R", -1), (".L", 1)):
        tag = s.replace(".", "_")
        el, wr = V(j["elbow" + s]), V(j["wrist" + s])
        g = [ck.tube(P + "gloves_cuff" + tag, el.lerp(wr, 0.35), wr + V((0, 0, 0.01)), 0.07, 0.085, t if s == ".L" else leather, 12),
             ck.tube(P + "gloves_strap" + tag, el.lerp(wr, 0.6), el.lerp(wr, 0.68), 0.088, 0.088, t2, 12)]
        ck._rigid(g, rig, "forearm" + s)
        fist = ck.ball(P + "gloves_fist" + tag, b["hand"] * 1.25, ck.hand_center(base, s), leather, (1, 1, 1.1))
        ck._rigid([fist], rig, "hand" + s)
    # ---------------- botas ----------------
    ck.armor_piece(body, rig, P + "boots_shell", "boots", leather, 0.022, 0.016)
    for s, sxx in ((".R", -1), (".L", 1)):
        tag = s.replace(".", "_")
        an = V(j["ankle" + s])
        k = [ck.tube(P + "boots_cuff" + tag, an + V((0, 0, 0.07)), an + V((0, 0, 0.11)), 0.085, 0.09, t, 12),
             ck.tube(P + "boots_wrap" + tag, an + V((0, 0, 0.02)), an + V((0, 0, 0.04)), 0.075, 0.075, t2, 12)]
        if cfg.get("wraps"):       # faixas de pano subindo a canela
            kn = V(j["knee" + s]) if ("knee" + s) in j else an + V((0, 0, 0.14))
            for w in range(3):
                p0 = an.lerp(kn, 0.3 + w * 0.2)
                k.append(ck.tube(P + "boots_band%d" % w + tag, p0, p0 + V((0, 0.006, 0.026)), 0.078 - w * 0.004, 0.078 - w * 0.004, t2 if w % 2 == 0 else leather, 12))
        ck._rigid(k, rig, "shin" + s)


# ---------------------------------------------------------------------------
# Arcos (mão esquerda, em pé como o arco do kit). tips: wing | leaf | horn | crescent | crystal | flame
RAN_BOWS = {"ran_c5": {"tips": "leaf", "size": 1.0}, "ran_c10": {"tips": "horn", "size": 1.05}, "ran_c15": {"tips": "wing", "size": 1.1},
            "ran_c20": {"tips": "leaf", "size": 1.12, "gem": True}, "ran_c25": {"tips": "crystal", "size": 1.15, "gem": True},
            "ran_c30": {"tips": "wing", "size": 1.2, "gem": True, "glow": True},
            # Patrulheiro: arcos curtos e bem curvos (de cavalaria), pontas em meia-lua e fitas ao vento
            "ran_p5": {"tips": "crescent", "size": 0.88, "curve": 1.35}, "ran_p10": {"tips": "ribbon", "size": 0.9, "curve": 1.35},
            "ran_p15": {"tips": "crescent", "size": 0.93, "curve": 1.4, "gem": True, "ribbon": True},
            "ran_p20": {"tips": "ribbon", "size": 0.95, "curve": 1.4, "gem": True, "fins": True, "glow": (0.55, 1.0, 0.85)},
            "ran_p25": {"tips": "crescent", "size": 0.98, "curve": 1.45, "gem": True, "fins": True, "ribbon": True, "glow": (0.8, 0.6, 1.0)},
            "ran_p30": {"tips": "crescent", "size": 1.02, "curve": 1.5, "gem": True, "fins": True, "ribbon": True, "glow": (0.85, 1.0, 0.5)}}


def build_bow(ck, base, mats, style, cfg):
    V = Vector
    g = V(ck.hand_center(base, ".L"))
    t, t2, gold, wh = mats["tint"], mats["tint2"], mats["trim"], mats["white"]
    wood = mats["wood"]
    S = cfg["size"]
    n = "b_%s_" % style
    # recurvo: a curva vai para a frente e as pontas voltam para trás
    pts = []
    for i in range(13):
        tt = i / 6.0 - 1.0
        cv = cfg.get("curve", 1.0)         # recurvo mais fechado (arco curto do Patrulheiro)
        y = -0.15 * cv * (1 - tt * tt) + 0.03 + 0.06 * cv * max(0.0, abs(tt) - 0.75) / 0.25 * (abs(tt) > 0.75)
        pts.append(g + V((0.0, y * S, tt * 0.5 * S)))
    parts = [ck.tube(n + "limb%d" % i, pts[i], pts[i + 1], 0.022 - abs(i - 6) * 0.0015, 0.022 - abs(i + 1 - 6) * 0.0015, t if 2 < i < 9 else wood, 6) for i in range(12)]
    parts += [ck.tube(n + "string", pts[0], pts[-1], 0.004, 0.004, ck.mat("m_string", (0.95, 0.95, 0.9)), 4),
              ck.tube(n + "grip", g - V((0, 0, 0.06)), g + V((0, 0, 0.06)), 0.03, 0.03, mats["leather"], 8)]
    for sz, tip, nb in ((1, pts[-1], pts[-2]), (-1, pts[0], pts[1])):
        dirv = (tip - nb).normalized()
        tk = cfg["tips"]
        if tk == "leaf":
            parts.append(ck.blade(n + "tip%d" % sz, tip, tip + dirv * 0.12 * S + V((0, 0.03, 0)), 0.06 * S, 0.015, t2, (1, 0, 0)))
        elif tk == "horn":
            parts.append(ck.tube(n + "tip%d" % sz, tip, tip + dirv * 0.1 * S + V((0, 0.06, 0)), 0.022, 0.004, wh, 6))
        elif tk == "wing":
            for k in range(3):
                parts.append(ck.blade(n + "tip%d_%d" % (sz, k), tip - dirv * 0.06 * k, tip - dirv * 0.06 * k + V((0, 0.12 + k * 0.03, sz * (0.05 - k * 0.02))) * S, 0.05 * S, 0.012, wh, (1, 0, 0)))
        elif tk == "crystal":
            parts.append(ck.blade(n + "tip%d" % sz, tip, tip + dirv * 0.14 * S, 0.06 * S, 0.04, ck.mat("m_ran_crystal", (0.6, 0.85, 1.0), 0.2, 1.8), (1, 0, 0)))
        elif tk == "crescent":
            parts.append(ck.blade(n + "tip%d" % sz, tip, tip + V((0, 0.12, sz * 0.04)) * S, 0.07 * S, 0.014, gold, (1, 0, 0)))
        if tk == "ribbon" or cfg.get("ribbon"):     # fita ao vento pendurada na ponta
            parts.append(ck.blade(n + "ribbon%d" % sz, tip, tip + V((0.01, 0.13, -0.1 if sz > 0 else 0.06)) * S, 0.035 * S, 0.008, t2, (1, 0, 0), 0.25))
            parts.append(ck.ball(n + "knot%d" % sz, 0.016, tip, gold))
    if cfg.get("gem"):
        parts.append(ck.ball(n + "gem", 0.035, g + V((0, -0.035, 0.08)), t2, (1, 0.6, 1.3)))
        parts.append(ck.ball(n + "gem2", 0.035, g + V((0, -0.035, -0.08)), t2, (1, 0.6, 1.3)))
    if cfg.get("fins"):            # aletas de vento nos braços do arco, para a frente
        for i in (3, 9):
            parts.append(ck.blade(n + "fin%d" % i, pts[i], pts[i] + V((0, -0.08, 0.04 if i > 6 else -0.04)) * S, 0.05 * S, 0.012, t2, (1, 0, 0), 0.35))
    if cfg.get("glow"):
        gcol = cfg["glow"] if isinstance(cfg["glow"], tuple) else (1.0, 0.9, 0.55)
        gm = ck.mat("m_ran_glow_bow" if gcol == (1.0, 0.9, 0.55) else "m_ran_glow_bow_%d" % int(sum(gcol) * 100), gcol, 0.3, 2.5)
        parts.append(ck.tube(n + "glow", pts[3], pts[9], 0.008, 0.008, gm, 4))
    obj = ck._join(parts, "wpn_main_bow_%s" % style)
    ck._smooth(obj.data)
    ck.skin_rigid(obj, base["rig"], "hand.L")
    return obj


# ---------------------------------------------------------------------------
# Mosquetes (mão direita, cano para a frente). stock: plain | carved ; bands ; scope ; bayonet ; double ; glow
RAN_RIFLES = {"ran_a5": {"bands": 2}, "ran_a10": {"bands": 3, "scope": True}, "ran_a15": {"bands": 3, "bayonet": True, "carved": True},
              "ran_a20": {"bands": 3, "scope": True, "glow": True}, "ran_a25": {"bands": 4, "double": True, "carved": True},
              "ran_a30": {"bands": 4, "scope": True, "bayonet": True, "carved": True, "glow": True}}


def rifle_parts(ck, n, g, mats, cfg, glow=None):
    """Partes do mosquete: coronha atrás da mão, cano para a frente (eixo das armas do kit)."""
    V = Vector
    fwd = V((0, -0.55, 0.83)).normalized()
    side = V((1, 0, 0))
    up = fwd.cross(side).normalized() * -1.0
    t, t2, gold = mats["tint"], mats["tint2"], mats["trim"]
    wood = mats["wood"]
    metal = mats["metal"]
    parts = [ck.tube(n + "stock", g - fwd * 0.42 - up * 0.04, g - fwd * 0.05, 0.06, 0.035, t if cfg.get("carved") else wood, 8),
             ck.tube(n + "body", g - fwd * 0.08, g + fwd * 0.32, 0.04, 0.035, wood, 8),
             ck.tube(n + "trigger", g - fwd * 0.02 - up * 0.04, g + fwd * 0.03 - up * 0.07, 0.008, 0.008, gold, 4)]
    barrels = (-0.022, 0.022) if cfg.get("double") else (0.0,)
    for bx in barrels:
        parts += [ck.tube(n + "barrel%d" % int(bx * 1000), g + fwd * 0.05 + up * 0.035 + side * bx, g + fwd * 0.82 + up * 0.035 + side * bx, 0.022, 0.02, metal, 8),
                  ck.tube(n + "muzzle%d" % int(bx * 1000), g + fwd * 0.8 + up * 0.035 + side * bx, g + fwd * 0.85 + up * 0.035 + side * bx, 0.03, 0.03, gold, 8)]
    for k in range(cfg.get("bands", 2)):
        z = 0.15 + k * 0.17
        parts.append(ck.tube(n + "band%d" % k, g + fwd * z, g + fwd * (z + 0.025), 0.05, 0.05, gold, 8))
    if cfg.get("scope"):
        parts += [ck.tube(n + "scope", g + fwd * 0.08 + up * 0.11, g + fwd * 0.36 + up * 0.11, 0.025, 0.025, mats["dark"], 8),
                  ck.ball(n + "lens", 0.025, g + fwd * 0.37 + up * 0.11, glow or t2, (1, 0.4, 1))]
    if cfg.get("bayonet"):
        parts.append(ck.blade(n + "bayonet", g + fwd * 0.82 - up * 0.01, g + fwd * 1.05 - up * 0.01, 0.04, 0.012, metal, side))
    if cfg.get("carved"):
        parts.append(ck.ball(n + "medal", 0.03, g - fwd * 0.25 - up * 0.01 + side * 0.055, gold, (0.4, 1, 1)))
    if glow and cfg.get("glow"):
        parts.append(ck.tube(n + "rune", g + fwd * 0.4 + up * 0.035, g + fwd * 0.7 + up * 0.035, 0.024, 0.022, glow, 8))
    return parts


def build_rifle(ck, base, mats, style, cfg):
    V = Vector
    g = V(ck.hand_center(base, ".R"))
    glow = ck.mat("m_ran_rifle_glow", (1.0, 0.7, 0.3), 0.3, 2.5)
    obj = ck._join(rifle_parts(ck, "r_%s_" % style, g, mats, cfg, glow), "wpn_main_rifle_%s" % style)
    ck._smooth(obj.data)
    ck.skin_rigid(obj, base["rig"], "hand.R")
    return obj


def register(ck):
    import paladin_sets
    for style, cfg in RAN_SETS.items():
        ck.SET_STYLES[style] = (lambda st, cf: (lambda base, mats: (build(ck, base, mats, st, cf), paladin_sets.join_slots("arm_%s_" % st))))(style, cfg)
    for style, cfg in RAN_BOWS.items():
        ck.SET_WEAPONS[style + "_bow"] = (lambda st, cf: (lambda base, mats: build_bow(ck, base, mats, st, cf)))(style, cfg)
    for style, cfg in RAN_RIFLES.items():
        ck.SET_WEAPONS[style + "_rifle"] = (lambda st, cf: (lambda base, mats: build_rifle(ck, base, mats, st, cf)))(style, cfg)
