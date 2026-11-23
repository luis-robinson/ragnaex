"""Conjuntos lendários do Ranger (18), arcos do Caçador, mosquetes do Atirador e lanças do Lanceiro, por construtor paramétrico.

Linguagem visual (original; só o "clima" de arqueiro clássico de MMO): couro leve, chapéu com pena ou capuz com
capinha, colete, aljava nas costas, braçadeira de arqueiro, capa curta de barra recortada. O Atirador troca a aljava
por bandoleira com frascos de pólvora, chapéu de três pontas ou óculos de latão, ombreira acolchoada do lado do coice.
O Lanceiro (lança, caça de perto) é o caçador de feras: cabeça de bicho (capuz de javali, crânio de lobo, juba, elmo de
serpe, bico de corvo, crânio chifrudo), gola de pelo, um troféu grande no ombro esquerdo e dardos nas costas (LAN_SETS).
Peças: arm_<estilo>_<head|body|gloves|boots>_*; armas: wpn_main_bow_<estilo> (mão esquerda), wpn_main_rifle_<estilo> e
wpn_main_spear_<estilo> (mão direita; spear_parts também desenha a lança comum do kit).
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
            "ran_c30": {"tips": "wing", "size": 1.2, "gem": True, "glow": True}}


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
        cv = cfg.get("curve", 1.0)         # recurvo mais fechado (opcional)
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
        elif tk == "hawk":         # Ato II: asa de falcão (3 penas para trás) e garra de osso para a frente
            hawk = ck.mat("m_ran_hawk", (0.5, 0.36, 0.24), 0.85)
            for k in range(3):
                q = tip - dirv * 0.07 * k
                parts.append(ck.blade(n + "tip%d_%d" % (sz, k), q, q + V((0, 0.17 + k * 0.035, sz * (0.07 - k * 0.03))) * S, 0.06 * S, 0.014, (wh, hawk, t2)[k], (1, 0, 0)))
            parts += curve(ck, n + "talon%d" % sz, tip, tip + dirv * 0.1 * S + V((0, -0.07, 0)) * S, V((0, 0.0, sz * 0.03)), 0.02, gold, 3, 6)
        if tk == "ribbon" or cfg.get("ribbon"):     # fita ao vento pendurada na ponta
            parts.append(ck.blade(n + "ribbon%d" % sz, tip, tip + V((0.01, 0.13, -0.1 if sz > 0 else 0.06)) * S, 0.035 * S, 0.008, t2, (1, 0, 0), 0.25))
            parts.append(ck.ball(n + "knot%d" % sz, 0.016, tip, gold))
    lit = tint_glow(ck) if cfg.get("glow") == "tint" else None     # Ato II: brilho na cor do nível
    if cfg.get("gem"):
        parts.append(ck.ball(n + "gem", 0.035, g + V((0, -0.035, 0.08)), lit or t2, (1, 0.6, 1.3)))
        parts.append(ck.ball(n + "gem2", 0.035, g + V((0, -0.035, -0.08)), lit or t2, (1, 0.6, 1.3)))
    if cfg.get("fins"):            # aletas de vento nos braços do arco, para a frente
        for i in (3, 9):
            parts.append(ck.blade(n + "fin%d" % i, pts[i], pts[i] + V((0, -0.08, 0.04 if i > 6 else -0.04)) * S, 0.05 * S, 0.012, t2, (1, 0, 0), 0.35))
    if lit:
        parts += [ck.tube(n + "glow_a", pts[2], pts[5], 0.011, 0.011, lit, 4), ck.tube(n + "glow_b", pts[7], pts[10], 0.011, 0.011, lit, 4)]
    elif cfg.get("glow"):
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
    hv = cfg.get("heavy")          # Ato II: cano grosso de peça de cerco, boca em sino, bipé dobrado
    for bx in barrels:
        parts += [ck.tube(n + "barrel%d" % int(bx * 1000), g + fwd * 0.05 + up * 0.035 + side * bx, g + fwd * (0.9 if hv else 0.82) + up * 0.035 + side * bx, 0.034 if hv else 0.022, 0.028 if hv else 0.02, ck.mat("m_ran_gunmetal", (0.2, 0.2, 0.24), 0.4) if hv else metal, 8),
                  ck.tube(n + "muzzle%d" % int(bx * 1000), g + fwd * (0.86 if hv else 0.8) + up * 0.035 + side * bx, g + fwd * (0.96 if hv else 0.85) + up * 0.035 + side * bx, 0.034 if hv else 0.03, 0.052 if hv else 0.03, gold, 8)]
    if hv:
        parts += [ck.tube(n + "breech", g - fwd * 0.02 + up * 0.035, g + fwd * 0.12 + up * 0.035, 0.05, 0.046, metal, 8),
                  ck.box(n + "sight", (0.014, 0.014, 0.05), g + fwd * 0.84 + up * 0.08, gold, 0.003)]
        for sx in (-1, 1):         # pernas do bipé dobradas sob o cano
            parts.append(ck.tube(n + "bipod%d" % sx, g + fwd * 0.5 - up * 0.01 + side * sx * 0.02, g + fwd * 0.74 - up * 0.03 + side * sx * 0.035, 0.009, 0.009, metal, 5))
    if cfg.get("drum"):            # tambor de munição sob o corpo
        parts += [ck.tube(n + "drum", g + fwd * 0.2 - up * 0.075 - side * 0.03, g + fwd * 0.2 - up * 0.075 + side * 0.03, 0.062, 0.062, ck.mat("m_ran_gunmetal", (0.2, 0.2, 0.24), 0.4), 10),
                  ck.tube(n + "drum_rim", g + fwd * 0.2 - up * 0.075 - side * 0.036, g + fwd * 0.2 - up * 0.075 + side * 0.036, 0.04, 0.04, gold, 10)]
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
        if hv:                     # três anéis acesos no cano e a boca em brasa
            for k in range(3):
                parts.append(ck.tube(n + "rune%d" % k, g + fwd * (0.36 + k * 0.15) + up * 0.035, g + fwd * (0.4 + k * 0.15) + up * 0.035, 0.04, 0.039, glow, 8))
            parts.append(ck.tube(n + "bore", g + fwd * 0.93 + up * 0.035, g + fwd * 0.965 + up * 0.035, 0.03, 0.04, glow, 8))
        else:
            parts.append(ck.tube(n + "rune", g + fwd * 0.4 + up * 0.035, g + fwd * 0.7 + up * 0.035, 0.024, 0.022, glow, 8))
    return parts


def build_rifle(ck, base, mats, style, cfg):
    V = Vector
    g = V(ck.hand_center(base, ".R"))
    glow = tint_glow(ck) if cfg.get("glow") == "tint" else ck.mat("m_ran_rifle_glow", (1.0, 0.7, 0.3), 0.3, 2.5)
    obj = ck._join(rifle_parts(ck, "r_%s_" % style, g, mats, cfg, glow), "wpn_main_rifle_%s" % style)
    ck._smooth(obj.data)
    ck.skin_rigid(obj, base["rig"], "hand.R")
    return obj


# ---------------------------------------------------------------------------
# Lanceiro (lança de duas mãos, caça de perto): caçador de feras tribal. De cima lê pela cabeça de bicho (capuz de javali,
# crânio de lobo, juba de leão, elmo de serpe, máscara de corvo, crânio chifrudo), pela gola de pelo em volta dos ombros,
# por UMA ombreira grande de troféu no ombro esquerdo (presas, crânio, penas, escamas) e pelo feixe de dardos nas costas.
# head: boar | wolf | mane | serpent | raven | beast ; trophy: tusk | skull | feather | scale | antler ; fur: pelo da gola (FURS)
# javelins: dardos nas costas ; necklace: colar de dentes ; flap: avental de couro na frente ; glow: brilho
LAN_SETS = {
    "ran_l5": {"head": "boar", "trophy": "tusk", "fur": "brown", "javelins": 2, "necklace": False, "flap": True},
    "ran_l10": {"head": "wolf", "trophy": "skull", "fur": "grey", "javelins": 3, "necklace": True, "flap": True},
    "ran_l15": {"head": "mane", "trophy": "tusk", "fur": "cream", "javelins": 3, "necklace": True, "flap": True},
    "ran_l20": {"head": "serpent", "trophy": "scale", "fur": "dark", "javelins": 3, "necklace": False, "flap": True, "glow": (0.5, 1.0, 0.75)},
    "ran_l25": {"head": "raven", "trophy": "feather", "fur": "dark", "javelins": 4, "necklace": True, "flap": True, "glow": (0.8, 0.55, 1.0)},
    "ran_l30": {"head": "beast", "trophy": "antler", "fur": "cream", "javelins": 4, "necklace": True, "flap": True, "glow": (1.0, 0.85, 0.4)},
}
BONE = (0.95, 0.91, 0.8)
FURS = {"brown": (0.5, 0.36, 0.24), "grey": (0.6, 0.6, 0.62), "cream": (0.93, 0.86, 0.7), "dark": (0.2, 0.17, 0.24)}


def build_lancer(ck, base, mats, style, cfg):
    V = Vector
    rig, body, b, j = base["rig"], base["body"], base["b"], base["j"]
    t, t2, gold, wh, dark, leather = mats["tint"], mats["tint2"], mats["trim"], mats["white"], mats["dark"], mats["leather"]
    bone = ck.mat("m_ran_bone", BONE, 0.7)
    fur = ck.mat("m_ran_fur_" + cfg["fur"], FURS[cfg["fur"]], 0.95)
    glow = ck.mat("m_ran_glow_%d" % int(sum(cfg["glow"]) * 100), cfg["glow"], 0.3, 2.6) if cfg.get("glow") else None
    eye = glow or ck.mat("m_ran_eye_dark", (0.1, 0.06, 0.08), 0.9)
    P = "arm_%s_" % style
    c = V(base["head_c"])
    r = b["head"]
    hk = cfg["head"]
    head = []
    # ---------------- cabeça: bicho por cima do capuz ----------------
    if hk == "boar":               # capuz de couro de javali: focinho na testa, presas para cima, orelhas e crina nas costas
        head += [ck._shell(P + "head_hood", c, r * 1.16, 0.3, -1.0, -0.45, 0.04, t),
                 ck.ball(P + "head_snout", r * 0.42, c + V((0, -r * 0.92, r * 0.62)), t, (0.95, 1.0, 0.62)),
                 ck.ball(P + "head_nose", r * 0.2, c + V((0, -r * 1.3, r * 0.58)), ck.mat("m_ran_eye_dark", (0.1, 0.06, 0.08), 0.9), (1.2, 0.5, 0.9))]
        for sx in (-1, 1):
            head += [ck.tube(P + "head_tusk_%d" % sx, c + V((sx * r * 0.3, -r * 1.2, r * 0.48)), c + V((sx * r * 0.55, -r * 1.32, r * 0.9)), r * 0.09, r * 0.02, bone, 6),
                     ck.blade(P + "head_ear_%d" % sx, c + V((sx * r * 0.55, -r * 0.2, r * 0.95)), c + V((sx * r * 0.95, r * 0.1, r * 1.35)), r * 0.42, 0.03, t, (0, 1, 0))]
        for k in range(5):         # crina eriçada do topo até a nuca
            y = -r * 0.35 + k * r * 0.33
            head.append(ck.blade(P + "head_bristle_%d" % k, c + V((0, y, r * 1.08 - k * r * 0.12)), c + V((0, y + r * 0.25, r * 1.45 - k * r * 0.16)), r * 0.3, 0.025, fur, (0, 1, 0)))
    elif hk in ("wolf", "beast"):  # crânio de bicho como elmo: calota de osso, focinho comprido sobre a testa, presas, pelo nas costas
        big = 1.1 if hk == "beast" else 1.0
        head += [ck._shell(P + "head_skull", c + V((0, 0, r * 0.05)), r * 1.15, 0.38, -0.2, 0.0, 0.04, bone),
                 ck.tube(P + "head_muzzle", c + V((0, -r * 0.6, r * 0.62)), c + V((0, -r * 1.55 * big, r * 0.42)), r * 0.38 * big, r * 0.2 * big, bone, 8),
                 ck.ball(P + "head_muzzle_tip", r * 0.2 * big, c + V((0, -r * 1.55 * big, r * 0.42)), bone, (1, 1, 0.8)),
                 ck.ball(P + "head_nose", r * 0.1 * big, c + V((0, -r * 1.68 * big, r * 0.5)), dark)]
        for sx in (-1, 1):
            head += [ck.ball(P + "head_socket_%d" % sx, r * 0.14, c + V((sx * r * 0.32, -r * 0.88, r * 0.78)), eye, (1, 0.6, 0.8)),
                     ck.blade(P + "head_fang_%d" % sx, c + V((sx * r * 0.2, -r * 1.35 * big, r * 0.3)), c + V((sx * r * 0.2, -r * 1.4 * big, r * 0.02)), r * 0.12, 0.02, bone, (1, 0, 0))]
            if hk == "wolf":
                head.append(ck.blade(P + "head_ear_%d" % sx, c + V((sx * r * 0.5, -r * 0.05, r * 1.0)), c + V((sx * r * 0.7, r * 0.1, r * 1.6)), r * 0.45, 0.03, fur, (0, 1, 0)))
            else:                  # chifres grandes que abrem e voltam para trás (silhueta de cima)
                p0 = c + V((sx * r * 0.55, -r * 0.2, r * 0.95))
                pts = [p0, p0 + V((sx * r * 0.55, r * 0.05, r * 0.45)), p0 + V((sx * r * 1.05, r * 0.35, r * 0.75)), p0 + V((sx * r * 1.35, r * 0.85, r * 0.85))]
                for k in range(3):
                    head.append(ck.tube(P + "head_horn_%d_%d" % (sx, k), pts[k], pts[k + 1], r * (0.16 - k * 0.045), r * (0.12 - k * 0.04), bone, 8))
                head.append(ck.tube(P + "head_tine_%d" % sx, pts[1], pts[1] + V((sx * r * 0.1, -r * 0.3, r * 0.5)), r * 0.08, r * 0.015, bone, 6))
        head.append(ck.strand(P + "head_pelt", c + V((0, r * 0.85, r * 0.55)), r * 1.5, r * 1.3, r * 0.4, fur, taper=0.6, lean=(0.0, 0.45)))
    elif hk == "mane":             # juba: tufos em leque em volta da cabeça (sol de cima) e orelhas redondas
        head.append(ck._shell(P + "head_cap", c + V((0, r * 0.04, r * 0.06)), r * 1.12, 0.45, -0.4, -0.1, 0.035, t))
        n = 16
        for k in range(n):
            a = math.tau * k / n + math.pi / 2
            d = V((math.cos(a), math.sin(a), 0))
            front = d.y < -0.75    # deixa o rosto aberto
            if front:
                continue
            root = c + d * r * 0.9 + V((0, 0, r * 0.35))
            head.append(ck.blade(P + "head_mane_%d" % k, root, root + d * r * (1.35 + 0.3 * (k % 2)) + V((0, 0, -r * 0.2)), r * 0.85, 0.04, t if k % 2 == 0 else fur, V((-d.y, d.x, 0)), 0.4))
        for sx in (-1, 1):
            head.append(ck.ball(P + "head_ear_%d" % sx, r * 0.2, c + V((sx * r * 0.62, r * 0.05, r * 1.02)), t, (1, 0.5, 1)))
        head.append(ck.ball(P + "head_brow", r * 0.16, c + V((0, -r * 1.08, r * 0.55)), gold, (1.6, 0.5, 0.7)))
    elif hk == "serpent":          # elmo de escamas com cabeça de serpe na testa e barbatana no topo
        head += [ck._shell(P + "head_helm", c, r * 1.15, 0.2, -0.7, -0.35, 0.04, t),
                 ck.ball(P + "head_snake", r * 0.38, c + V((0, -r * 1.0, r * 0.66)), t2, (0.8, 1.25, 0.5)),
                 ck.blade(P + "head_fin", c + V((0, -r * 0.7, r * 1.05)), c + V((0, r * 1.0, r * 1.25)), r * 0.9, 0.035, t2, (0, 0, 1), 0.35)]
        for sx in (-1, 1):
            head += [ck.ball(P + "head_snake_eye_%d" % sx, r * 0.08, c + V((sx * r * 0.2, -r * 1.25, r * 0.78)), eye),
                     ck.blade(P + "head_fang_%d" % sx, c + V((sx * r * 0.15, -r * 1.38, r * 0.55)), c + V((sx * r * 0.13, -r * 1.42, r * 0.22)), r * 0.1, 0.02, bone, (1, 0, 0)),
                     ck.blade(P + "head_gill_%d" % sx, c + V((sx * r * 1.0, r * 0.1, r * 0.3)), c + V((sx * r * 1.55, r * 0.45, r * 0.55)), r * 0.55, 0.03, t2, (0, 0, 1), 0.35)]
        for k in range(4):         # faixas de escama no elmo
            head.append(ck.tube(P + "head_scale_%d" % k, c + V((0, 0, r * (0.55 + k * 0.12))), c + V((0, 0, r * (0.6 + k * 0.12))), r * (1.17 - k * 0.12), r * (1.15 - k * 0.12), t2 if k % 2 else t, 18))
    elif hk == "raven":            # capuz escuro, máscara de bico comprido e leque de penas atrás
        head += [ck._shell(P + "head_hood", c, r * 1.17, 0.28, -1.0, -0.5, 0.04, dark),
                 ck.blade(P + "head_beak", c + V((0, -r * 0.92, r * 0.55)), c + V((0, -r * 2.0, r * 0.15)), r * 0.62, r * 0.4, gold, (1, 0, 0), 0.25),
                 ck.ball(P + "head_mask", r * 0.55, c + V((0, -r * 0.82, r * 0.62)), t, (1.25, 0.5, 0.55))]
        for sx in (-1, 1):
            head.append(ck.ball(P + "head_eye_%d" % sx, r * 0.12, c + V((sx * r * 0.36, -r * 1.12, r * 0.7)), eye, (1, 0.5, 0.8)))
        for k in range(7):
            a = math.pi * (0.15 + 0.7 * k / 6.0)
            d = V((math.cos(a), math.sin(a), 0))
            root = c + V((0, r * 0.6, r * 0.75))
            head.append(ck.blade(P + "head_feather_%d" % k, root, root + d * r * 1.1 + V((0, r * 0.25, r * 0.55)), r * 0.32, 0.02, dark if k % 2 else t, V((-d.y, d.x, 0)), 0.45))
    ck._rigid(head, rig, "head")
    # ---------------- corpo: colete de couro, arreio cruzado, gola de pelo, troféu no ombro, dardos nas costas ----------------
    ck.armor_piece(body, rig, P + "body_vest", "torso", t, 0.012, 0.014, 0.05)
    ck.armor_piece(body, rig, P + "body_legs", "legs", leather, 0.008, 0.012)
    d = b["depth"]
    front = -b["chest"] * d - 0.03
    back = b["chest"] * d + 0.03
    zc = ck.Z["chest"]
    zn = ck.Z["neck"]
    chest = []
    for sx in (-1, 1):             # arreio em X no peito e nas costas
        chest += [ck.tube(P + "body_strap_f%d" % sx, (sx * 0.15, front + 0.015, zc + 0.15), (-sx * 0.13, front + 0.015, ck.Z["waist"] + 0.04), 0.017, 0.017, leather, 6),
                  ck.tube(P + "body_strap_b%d" % sx, (sx * 0.15, back - 0.01, zc + 0.15), (-sx * 0.13, back - 0.01, ck.Z["waist"] + 0.04), 0.017, 0.017, leather, 6)]
    chest.append(ck.ball(P + "body_ring", 0.032, (0, front + 0.005, zc - 0.02), gold, (1, 0.5, 1)))
    if cfg.get("necklace"):        # colar de presas
        for k in range(7):
            a = math.pi * (0.25 + 0.5 * k / 6.0)
            p = V((math.cos(a) * b["chest"] * 0.5, -math.sin(a) * b["chest"] * 0.55 - 0.02, zn - 0.07 - math.sin(a) * 0.03))
            chest.append(ck.blade(P + "body_tooth_%d" % k, p, p + V((0, -0.01, -0.06)), 0.028, 0.012, bone, (1, 0, 0)))
    # gola de pelo: anel de tufos em volta dos ombros (de cima é o que aparece)
    rw = abs(V(j["shoulder.L"]).x) + b["arm"] * 1.6
    nt = 16
    for k in range(nt):
        a = math.tau * (k + 0.5) / nt
        dv = V((math.cos(a), math.sin(a) * 0.82, 0))
        root = dv * rw * 0.62 + V((0, 0, zn - 0.03))
        chest.append(ck.blade(P + "body_fur_%d" % k, root, dv * rw * 1.08 + V((0, 0, zn - 0.13 - (k % 2) * 0.03)), rw * 0.5, 0.02, fur if k % 3 else t2, V((-dv.y, dv.x, 0)), 0.35))
    # dardos de caça nas costas, em leque
    nj = cfg.get("javelins", 3)
    for k in range(nj):
        off = (k - (nj - 1) / 2.0) * 0.05
        p0 = V((0.12 + off, back + 0.05, ck.Z["waist"] - 0.05))
        p1 = V((-0.16 + off * 1.6, back + 0.09, zn + 0.32))
        chest += [ck.tube(P + "body_jav_%d" % k, p0, p1, 0.012, 0.012, mats["wood"], 6),
                  ck.blade(P + "body_javtip_%d" % k, p1, p1 + (p1 - p0).normalized() * 0.1, 0.045, 0.012, mats["metal"], (1, 0, 0)),
                  ck.blade(P + "body_javfl_%d" % k, p0, p0 - (p1 - p0).normalized() * 0.06, 0.035, 0.01, t2, (1, 0, 0))]
    chest.append(ck.tube(P + "body_javband", V((0.0, back + 0.06, zc - 0.05)), V((0.0, back + 0.07, zc - 0.01)), 0.07, 0.07, leather, 8))
    if glow:
        chest.append(ck.ball(P + "body_charm", 0.03, (0, front - 0.01, zc - 0.02), glow))
    ck._rigid(chest, rig, "chest")
    # troféu no ombro esquerdo (a lança vai na direita)
    sh = V(j["shoulder.L"])
    tk = cfg["trophy"]
    tro = [ck.ball(P + "body_pauldron", b["arm"] * 2.3, sh + V((0.05, 0, 0.04)), leather, (1.1, 1.05, 0.6))]
    if tk == "tusk":
        for k in range(3):
            a = -0.5 + k * 0.5
            tro.append(ck.tube(P + "body_tusk_%d" % k, sh + V((0.08, a * 0.08, 0.07)), sh + V((0.2, a * 0.14, 0.2 - abs(a) * 0.05)), 0.026, 0.005, bone, 6))
    elif tk == "skull":
        tro += [ck.ball(P + "body_tskull", 0.075, sh + V((0.1, -0.02, 0.1)), bone, (1, 1.2, 0.85)),
                ck.tube(P + "body_tsnout", sh + V((0.1, -0.08, 0.09)), sh + V((0.1, -0.17, 0.07)), 0.045, 0.025, bone, 6),
                ck.ball(P + "body_teye", 0.02, sh + V((0.13, -0.08, 0.12)), eye)]
    elif tk == "feather":
        for k in range(5):
            a = -0.7 + k * 0.35
            tro.append(ck.blade(P + "body_tfeather_%d" % k, sh + V((0.08, a * 0.06, 0.06)), sh + V((0.26, a * 0.18, 0.12 - abs(a) * 0.06)), 0.07, 0.012, dark if k % 2 else t, (0, 0, 1), 0.4))
    elif tk == "scale":
        for k in range(3):
            tro.append(ck.ball(P + "body_tscale_%d" % k, b["arm"] * (2.4 - k * 0.35), sh + V((0.06 + k * 0.03, 0, 0.06 - k * 0.04)), t2 if k % 2 else t, (1.1, 1.05, 0.35)))
        tro.append(ck.blade(P + "body_tspine", sh + V((0.08, 0.06, 0.08)), sh + V((0.12, -0.08, 0.22)), 0.06, 0.015, t2, (0, 1, 0)))
    elif tk == "antler":
        p0 = sh + V((0.08, 0.0, 0.08))
        tro += [ck.tube(P + "body_ant0", p0, p0 + V((0.12, 0.04, 0.12)), 0.022, 0.016, bone, 6),
                ck.tube(P + "body_ant1", p0 + V((0.12, 0.04, 0.12)), p0 + V((0.16, 0.12, 0.24)), 0.016, 0.006, bone, 6),
                ck.tube(P + "body_ant2", p0 + V((0.12, 0.04, 0.12)), p0 + V((0.24, -0.04, 0.18)), 0.014, 0.005, bone, 6),
                ck.ball(P + "body_tskull", 0.06, sh + V((0.1, -0.03, 0.08)), bone, (1, 1.2, 0.85))]
    if glow:
        tro.append(ck.ball(P + "body_tgem", 0.022, sh + V((0.06, -0.08, 0.06)), glow))
    ck._rigid(tro, rig, "upper_arm.L")
    # cinto e avental de couro
    belt = ck.tube(P + "body_belt", (0, 0, ck.Z["waist"] - 0.035), (0, 0, ck.Z["waist"] + 0.03), b["waist"] * 1.18, b["waist"] * 1.18, leather, 16)
    for v in belt.data.vertices:
        v.co.y *= d * 1.05
    ck._smooth(belt.data)
    ck.transfer_weights(belt, body, rig)
    hips = [ck.box(P + "body_buckle", (0.06, 0.025, 0.05), (0, -b["waist"] * d * 1.2 - 0.01, ck.Z["waist"]), bone if not glow else gold, 0.008),
            ck.ball(P + "body_pouch", 0.045, (0.12, -b["waist"] * d * 1.1 - 0.02, ck.Z["waist"] - 0.04), leather, (1, 0.6, 1))]
    if cfg.get("flap"):
        hips += [ck.blade(P + "body_flap_f", (0, -b["waist"] * d * 1.18 - 0.012, ck.Z["waist"] - 0.02), (0, -b["waist"] * d * 1.22 - 0.03, ck.Z["waist"] - 0.24), 0.17, 0.012, fur, (1, 0, 0), 0.3),
                 ck.blade(P + "body_flap_b", (0, b["waist"] * d * 1.18 + 0.012, ck.Z["waist"] - 0.02), (0, b["waist"] * d * 1.22 + 0.03, ck.Z["waist"] - 0.22), 0.17, 0.012, t, (1, 0, 0), 0.3)]
    ck._rigid(hips, rig, "hips")
    # ---------------- braços: faixas e luvas sem dedo ----------------
    for s in (".R", ".L"):
        tag = s.replace(".", "_")
        el, wr = V(j["elbow" + s]), V(j["wrist" + s])
        g = [ck.tube(P + "gloves_wrap" + tag, el.lerp(wr, 0.3), wr + V((0, 0, 0.01)), 0.072, 0.082, leather, 12)]
        for w in range(3):
            p0 = el.lerp(wr, 0.35 + w * 0.2)
            g.append(ck.tube(P + "gloves_band%d" % w + tag, p0, p0 + (wr - el).normalized() * 0.02, 0.085, 0.085, t2 if w % 2 == 0 else t, 12))
        ck._rigid(g, rig, "forearm" + s)
        fist = ck.ball(P + "gloves_fist" + tag, b["hand"] * 1.22, ck.hand_center(base, s), leather, (1, 1, 1.1))
        ck._rigid([fist], rig, "hand" + s)
    # ---------------- botas com punho de pelo e faixas na canela ----------------
    ck.armor_piece(body, rig, P + "boots_shell", "boots", leather, 0.022, 0.016)
    for s in (".R", ".L"):
        tag = s.replace(".", "_")
        an = V(j["ankle" + s])
        kn = V(j["knee" + s]) if ("knee" + s) in j else an + V((0, 0, 0.14))
        k = []
        for w in range(6):         # tufos de pelo em volta do cano
            a = math.tau * w / 6
            dv = V((math.cos(a), math.sin(a), 0))
            k.append(ck.blade(P + "boots_fur%d" % w + tag, an + V((0, 0, 0.09)) + dv * 0.07, an + V((0, 0, 0.04)) + dv * 0.12, 0.07, 0.015, fur, V((-dv.y, dv.x, 0)), 0.3))
        for w in range(2):
            p0 = an.lerp(kn, 0.45 + w * 0.22)
            k.append(ck.tube(P + "boots_band%d" % w + tag, p0, p0 + V((0, 0.006, 0.024)), 0.074, 0.074, t2 if w % 2 == 0 else leather, 12))
        ck._rigid(k, rig, "shin" + s)


# ---------------------------------------------------------------------------
# Lanças (mão direita, ponta para a frente no eixo das armas do kit). head: leaf | tusk | broad | wave | barb | wing
RAN_SPEARS = {"ran_l5": {"head": "tusk", "len": 1.0, "tassel": True},
              "ran_l10": {"head": "leaf", "len": 1.04, "fang": True, "tassel": True},
              "ran_l15": {"head": "broad", "len": 1.06, "tassel": True, "gold": True},
              "ran_l20": {"head": "wave", "len": 1.08, "fang": True, "glow": (0.5, 1.0, 0.75)},
              "ran_l25": {"head": "barb", "len": 1.1, "feathers": True, "glow": (0.8, 0.55, 1.0)},
              "ran_l30": {"head": "wing", "len": 1.14, "fang": True, "tassel": True, "gold": True, "glow": (1.0, 0.85, 0.4)}}


SPEAR_AXIS = (-0.16, -0.55, 0.83)     # eixo das armas do kit, um pouco para fora (a haste não cruza o rosto parado)


def spear_parts(ck, n, g, ax, mats, cfg, glow=None):
    """Lança: haste longa de g - ax*0.62 até a ponta (a mão segura a um terço da base). ax = eixo das armas do kit."""
    V = Vector
    side = V((1, 0, 0))
    L = cfg.get("len", 1.0)
    t, t2, gold = mats["tint"], mats["tint2"], mats["trim"]
    wood, metal, leather = mats["wood"], mats["metal"], mats["leather"]
    bone = ck.mat("m_ran_bone", BONE, 0.7)
    top = g + ax * 1.22 * L          # alvado (onde a ponta encaixa)
    parts = [ck.tube(n + "shaft", g - ax * 0.62, top, 0.021, 0.019, wood, 8),
             ck.tube(n + "butt", g - ax * 0.68, g - ax * 0.6, 0.012, 0.026, metal, 8),
             ck.tube(n + "grip", g - ax * 0.12, g + ax * 0.14, 0.027, 0.027, leather, 8),
             ck.tube(n + "socket", top - ax * 0.06, top + ax * 0.02, 0.03, 0.026, gold if cfg.get("gold") else metal, 8)]
    hk = cfg.get("head", "leaf")
    blade_m = gold if hk == "broad" and cfg.get("gold") else metal
    if hk == "leaf":
        parts.append(ck.blade(n + "head", top, top + ax * 0.34, 0.11, 0.022, blade_m, side, 0.4))
    elif hk == "tusk":             # ponta de presa curva (osso)
        parts += [ck.tube(n + "head", top, top + ax * 0.2 - V((0, 0.02, 0)), 0.04, 0.025, bone, 8),
                  ck.tube(n + "head2", top + ax * 0.2 - V((0, 0.02, 0)), top + ax * 0.34 + V((0, 0.0, -0.03)), 0.025, 0.004, bone, 8)]
    elif hk == "broad":            # ponta larga de folha de louro
        parts.append(ck.blade(n + "head", top, top + ax * 0.4, 0.17, 0.024, blade_m, side, 0.35))
    elif hk == "wave":             # ponta ondulada (serpe)
        pts = [top + ax * (0.08 * k) + side * (0.03 * math.sin(k * 1.6)) for k in range(6)]
        for k in range(5):
            parts.append(ck.blade(n + "wave%d" % k, pts[k], pts[k + 1] + ax * 0.02, 0.11 - k * 0.015, 0.02, t2 if glow is None else glow, side, 0.5))
        parts.append(ck.blade(n + "head", pts[-1], pts[-1] + ax * 0.08, 0.05, 0.02, metal, side))
    elif hk == "barb":             # ponta farpada (farpas para trás)
        parts.append(ck.blade(n + "head", top, top + ax * 0.36, 0.09, 0.02, mats["dark"], side, 0.45))
        for sx in (-1, 1):
            parts.append(ck.blade(n + "barb%d" % sx, top + ax * 0.12, top + ax * 0.04 + side * sx * 0.09, 0.04, 0.016, mats["dark"], ax, 0.5))
    elif hk == "wing":             # ponta grande com asas de travar
        parts.append(ck.blade(n + "head", top, top + ax * 0.44, 0.14, 0.024, metal, side, 0.38))
        for sx in (-1, 1):
            parts.append(ck.blade(n + "wing%d" % sx, top + ax * 0.02, top - ax * 0.02 + side * sx * 0.16, 0.07, 0.02, gold, ax, 0.45))
    elif hk == "troll":            # Ato II: lâmina larga e escura de matar troll, farpas para trás, travessa de presas, fio aceso
        parts.append(ck.blade(n + "head", top, top + ax * 0.5, 0.17, 0.026, mats["dark"], side, 0.3))
        parts.append(ck.blade(n + "head_edge", top + ax * 0.03, top + ax * 0.47, 0.06, 0.03, glow if glow is not None else metal, side, 0.3))
        for sx in (-1, 1):
            parts.append(ck.blade(n + "barb%d" % sx, top + ax * 0.2, top + ax * 0.06 + side * sx * 0.15, 0.06, 0.02, mats["dark"], ax, 0.5))
            parts += curve(ck, n + "tusk%d" % sx, top - ax * 0.03, top + ax * 0.1 + side * sx * 0.17, side * sx * 0.04 - ax * 0.03, 0.026, bone, 3, 6)
    if cfg.get("fang") and hk != "troll":            # presas de travar logo abaixo da ponta
        for sx in (-1, 1):
            parts.append(ck.tube(n + "fang%d" % sx, top - ax * 0.02, top + ax * 0.06 + side * sx * 0.08, 0.016, 0.004, bone, 6))
    if cfg.get("tassel"):          # penacho/fita caindo do alvado
        parts += [ck.ball(n + "knot", 0.03, top - ax * 0.09, t2),
                  ck.blade(n + "tassel", top - ax * 0.09, top - ax * 0.3 - V((0, 0.02, 0.04)), 0.06, 0.012, t, side, 0.3)]
    if cfg.get("feathers"):
        for k in range(3):
            parts.append(ck.blade(n + "feather%d" % k, top - ax * 0.08, top - ax * (0.26 + k * 0.03) + side * (k - 1) * 0.05, 0.045, 0.01, t if k % 2 else mats["dark"], side, 0.4))
    for k in range(2):             # faixas de couro tingido na haste
        z = -0.4 + k * 0.85
        parts.append(ck.tube(n + "band%d" % k, g + ax * z, g + ax * (z + 0.03), 0.026, 0.026, t, 8))
    if glow is not None and hk == "troll":
        for k in range(2):
            parts.append(ck.tube(n + "rune%d" % k, g + ax * (0.55 + k * 0.3) * L, g + ax * (0.6 + k * 0.3) * L, 0.026, 0.026, glow, 8))
    elif glow is not None and cfg.get("glow"):
        parts.append(ck.tube(n + "rune", g + ax * 0.3, g + ax * 0.9 * L, 0.024, 0.023, glow, 8))
    return parts


def build_spear(ck, base, mats, style, cfg):
    V = Vector
    g = V(ck.hand_center(base, ".R"))
    ax = V(SPEAR_AXIS).normalized()
    if cfg.get("glow") == "tint":
        glow = tint_glow(ck)
    else:
        glow = ck.mat("m_ran_spear_glow_%d" % int(sum(cfg["glow"]) * 100), cfg["glow"], 0.3, 2.5) if cfg.get("glow") else None
    obj = ck._join(spear_parts(ck, "s_%s_" % style, g, ax, mats, cfg, glow), "wpn_main_spear_%s" % style)
    ck._smooth(obj.data)
    ck.skin_rigid(obj, base["rig"], "hand.R")
    return obj


# ---------------------------------------------------------------------------
# Ato II (níveis 35/40/45 + Ápice da build): UM visual novo por build, tema guerra contra a Horda em Monte Kharzun.
# A malha é a mesma nos três níveis; muda a cor do item (tint), o destaque (tint2) e o brilho: o material "tint_glow"
# recebe no jogo a cor de GearCatalog.ACT2_VISUALS[...]["glows"][nível] (KitModel).
#   ran_c35 Caçador  = Batedor da Estepe: gorro de pele com asas de falcão, manto de penas nos ombros, duas aljavas
#           cruzadas e capa de capim da estepe (tiras de palha) nas costas.
#   ran_a35 Atirador = Artilheiro de Cerco: touca de piloto com óculos na testa e luneta de latão no olho direito,
#           cartucheiras cruzadas, casaco comprido e barril de pólvora nas costas com pavio aceso.
#   ran_l35 Lanceiro = Caça-Trolls: elmo com duas presas de troll enormes subindo das bochechas, gola de couro de troll,
#           manto de couro de troll com espinhos na espinha e leque de dardos de ponta acesa.
GLOW_BASE = (1.0, 0.6, 0.2)           # cor só do .glb; o jogo pinta por nível
GRASS = (0.78, 0.68, 0.38)
TROLL = (0.4, 0.47, 0.36)


def tint_glow(ck):
    return ck.mat("tint_glow", GLOW_BASE, 0.3, 2.0)


def outward(objs):
    """Normais para fora (peça espelhada sai com a face virada e some no toon, que corta a face de trás)."""
    import bmesh
    for o in objs:
        bm = bmesh.new()
        bm.from_mesh(o.data)
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
        bm.to_mesh(o.data)
        bm.free()
    return objs


def ribbon(ck, name, pts, wdir, widths, thick, material):
    """Faixa de pano/couro com espessura passando pelos pontos (dobras = pontos fora da linha); largura no sentido wdir."""
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


def curve(ck, name, p0, p1, bend, r0, material, n=4, segs=8, r1=0.004):
    """Presa/chifre/haste curva de p0 a p1, arqueada por bend, afinando de r0 a r1."""
    p0, p1, bend = Vector(p0), Vector(p1), Vector(bend)
    out = []
    prev = p0
    for i in range(1, n + 1):
        k = i / n
        p = p0.lerp(p1, k) + bend * math.sin(math.pi * k)
        out.append(ck.tube("%s_%d" % (name, i), prev, p, r0 + (r1 - r0) * (i - 1) / n, r0 + (r1 - r0) * k, material, segs))
        prev = p
    return out


def fur_ring(ck, name, c, r, n, size, material, z_jitter=0.02, squash=0.85):
    """Gola/borda de pele: tufos irregulares em anel."""
    out = []
    for k in range(n):
        a = math.tau * k / n
        jit = ((k * 37) % 7) / 7.0
        p = Vector(c) + Vector((math.cos(a) * r, math.sin(a) * r * squash, (jit - 0.5) * z_jitter))
        out.append(ck.ball("%s_%d" % (name, k), size * (0.85 + jit * 0.35), p, material, (1.0, 1.0, 0.75)))
    return out


def body_belt(ck, base, name, z0, z1, k, material):
    """Cinto que acompanha o corpo (pesos do corpo)."""
    b, d = base["b"], base["b"]["depth"]
    belt = ck.tube(name, (0, 0, z0), (0, 0, z1), b["waist"] * k, b["waist"] * k, material, 16)
    for v in belt.data.vertices:
        v.co.y *= d * 1.05
    ck._smooth(belt.data)
    ck.transfer_weights(belt, base["body"], base["rig"])
    return belt


def _act2_arms_boots(ck, base, P, cuff_m, band_m, fist_m, boot_m, trim_m, fur=None):
    """Braçadeiras, luvas e botas de cano alto comuns aos três visuais do Ato II do Ranger."""
    V = Vector
    rig, body, b, j = base["rig"], base["body"], base["b"], base["j"]
    for s in (".R", ".L"):
        tag = s.replace(".", "_")
        el, wr = V(j["elbow" + s]), V(j["wrist" + s])
        g = [ck.tube(P + "gloves_cuff" + tag, el.lerp(wr, 0.25), wr + V((0, 0, 0.01)), 0.074, 0.092, cuff_m, 12),
             ck.tube(P + "gloves_rim" + tag, el.lerp(wr, 0.22), el.lerp(wr, 0.32), 0.094, 0.09, band_m, 12),
             ck.tube(P + "gloves_strap" + tag, el.lerp(wr, 0.66), el.lerp(wr, 0.75), 0.095, 0.097, band_m, 12)]
        if fur is not None:
            g += fur_ring(ck, P + "gloves_fur" + tag, el.lerp(wr, 0.2), 0.075, 6, 0.045, fur, 0.01, 1.0)
        ck._rigid(outward(g), rig, "forearm" + s)
        ck._rigid([ck.ball(P + "gloves_fist" + tag, b["hand"] * 1.28, ck.hand_center(base, s), fist_m, (1, 1, 1.1))], rig, "hand" + s)
    ck.armor_piece(body, rig, P + "boots_shell", "boots", boot_m, 0.024, 0.016)
    for s in (".R", ".L"):
        tag = s.replace(".", "_")
        an, kn = V(j["ankle" + s]), V(j["knee" + s])
        k = [ck.tube(P + "boots_cuff" + tag, an + V((0, 0, 0.075)), an + V((0, 0, 0.12)), 0.086, 0.096, cuff_m, 12),
             ck.tube(P + "boots_wrap" + tag, an + V((0, 0, 0.02)), an + V((0, 0, 0.045)), 0.078, 0.078, band_m, 12),
             ck.ball(P + "boots_knee" + tag, 0.06, kn + V((0, -0.06, 0.0)), trim_m, (1.0, 0.6, 1.1))]
        if fur is not None:
            k += fur_ring(ck, P + "boots_fur" + tag, an + V((0, 0, 0.12)), 0.082, 7, 0.045, fur, 0.012, 1.0)
        ck._rigid(outward(k), rig, "shin" + s)


def build_scout(ck, base, mats, style):
    """ran_c35 — Batedor da Estepe (Caçador, arco)."""
    V = Vector
    rig, body, b, j = base["rig"], base["body"], base["b"], base["j"]
    t, t2, gold, leather, wood = mats["tint"], mats["tint2"], mats["trim"], mats["leather"], mats["wood"]
    feather = ck.mat("m_ran_feather", FEATHER, 0.8)
    hawk = ck.mat("m_ran_hawk", (0.5, 0.36, 0.24), 0.85)
    fur = ck.mat("m_ran_fur_cream", FURS["cream"], 0.95)
    grass = ck.mat("m_ran_grass", GRASS, 0.9)
    glow = tint_glow(ck)
    P = "arm_%s_" % style
    c, r = V(base["head_c"]), b["head"]
    # ---------------- cabeça: gorro de pele com borda de pelo, asas de falcão abertas para trás, pedra acesa na testa ----------------
    head = [ck._shell(P + "head_cap", c + V((0, r * 0.03, r * 0.05)), r * 1.14, 0.36, -0.7, -0.3, 0.04, t)]
    head += fur_ring(ck, P + "head_fur", c + V((0, r * 0.06, r * 0.44)), r * 1.12, 16, r * 0.24, fur, 0.02, 1.0)
    # cabeça de falcão na testa: bico de ouro, olhos acesos, crista de penas tingidas do topo à nuca
    head += [ck.blade(P + "head_beak", c + V((0, -r * 0.95, r * 0.86)), c + V((0, -r * 1.62, r * 0.4)), r * 0.44, r * 0.3, gold, (1, 0, 0), 0.3),
             ck.ball(P + "head_brow", r * 0.42, c + V((0, -r * 0.82, r * 0.82)), hawk, (1.25, 0.9, 0.6)),
             ck.strand(P + "head_tail", c + V((0, r * 0.85, r * 0.75)), r * 0.9, r * 0.4, r * 0.34, t, taper=0.9, lean=(0.0, 0.7))]
    for sx in (-1, 1):
        head.append(ck.ball(P + "head_eye_%d" % sx, r * 0.13, c + V((sx * r * 0.36, -r * 1.02, r * 0.88)), glow, (1.0, 0.7, 0.8)))
    for k in range(4):
        a = -0.2 + k * 0.42
        root = c + V((0, math.sin(a) * r * 1.12, math.cos(a) * r * 1.12))
        head.append(ck.blade(P + "head_crest_%d" % k, root, root + V((0, math.sin(a + 0.7), math.cos(a + 0.7))) * r * (0.75 - k * 0.07), r * 0.42, 0.04,
                             t2 if k % 2 == 0 else feather, (0, math.cos(a), -math.sin(a)), 0.45))
    for sx in (-1, 1):                   # asa: 5 penas largas em leque quase deitado, da têmpora para fora e para trás (de cima, duas asas abertas)
        root = c + V((sx * r * 0.98, -r * 0.1, r * 0.55))
        head.append(ck.ball(P + "head_wing_root_%d" % sx, r * 0.26, root, gold, (0.6, 1.2, 1.0)))
        for k in range(5):
            a = -0.25 + k * 0.38      # 0 = para fora, pi/2 = para trás
            dv = V((sx * math.cos(a), math.sin(a), 0.42 - k * 0.04))
            wd = V((-sx * math.sin(a), math.cos(a), 0.12))
            head.append(ck.blade(P + "head_wing_%d_%d" % (sx, k), root + V((0, r * 0.06 * k, 0.004 * k)), root + dv * r * (1.25 + 0.16 * (2 - abs(k - 2))), r * 0.46, 0.024,
                                 (feather, hawk, t2, hawk, feather)[k], wd, 0.55))
    ck._rigid(outward(head), rig, "head")
    # ---------------- corpo ----------------
    ck.armor_piece(body, rig, P + "body_vest", "torso", t, 0.012, 0.014, 0.03)
    ck.armor_piece(body, rig, P + "body_legs", "legs", leather, 0.008, 0.012)
    d = b["depth"]
    front = -b["chest"] * d - 0.03
    back = b["chest"] * d + 0.03
    zc, zn, zw = ck.Z["chest"], ck.Z["neck"], ck.Z["waist"]
    chest = [ck.box(P + "body_lacing", (0.04, 0.02, 0.2), (0, front, zc - 0.04), t2, 0.005),
             ck.ball(P + "body_brooch", 0.034, (0, front - 0.02, zn - 0.07), glow, (1.0, 0.5, 1.2))]
    # manto de penas de falcão: duas fiadas em volta dos ombros
    rw = abs(V(j["shoulder.L"]).x) + b["arm"] * 2.0
    for row, (n, rr, drop, wd) in enumerate(((14, 0.72, 0.1, 0.5), (16, 1.06, 0.2, 0.44))):
        for k in range(n):
            a = math.tau * (k + 0.5 * row) / n
            dv = V((math.cos(a), math.sin(a) * 0.84, 0))
            m = (hawk, feather, hawk, t2)[k % 4] if row else (feather, hawk)[k % 2]
            chest.append(ck.blade(P + "body_mantle_%d_%d" % (row, k), dv * rw * (rr - 0.45) + V((0, 0, zn - 0.01 - row * 0.03)),
                                  dv * rw * rr + V((0, 0, zn - 0.03 - drop)), rw * wd, 0.016, m, V((-dv.y, dv.x, 0)), 0.5))
    # duas aljavas cruzadas nas costas, com as penas das flechas (uma acesa em cada)
    for sx in (-1, 1):
        q0 = V((-sx * 0.1, back + 0.07, zw + 0.0))
        q1 = V((sx * 0.2, back + 0.1 + r * 0.25, zn + 0.1))
        ax = (q1 - q0).normalized()
        chest += [ck.tube(P + "body_quiver_%d" % sx, q0, q1, 0.05, 0.062, leather, 10),
                  ck.tube(P + "body_quiver_rim_%d" % sx, q1, q1 + ax * 0.025, 0.068, 0.068, gold, 10),
                  ck.tube(P + "body_quiver_band_%d" % sx, q0.lerp(q1, 0.45), q0.lerp(q1, 0.52), 0.064, 0.065, t2, 10),
                  ck.tube(P + "body_qstrap_%d" % sx, (sx * 0.14, front + 0.02, zc + 0.14), (-sx * 0.12, front + 0.02, zw + 0.04), 0.016, 0.016, leather, 6)]
        for k in range(3):
            off = V(((k - 1) * 0.028, 0, 0))
            chest.append(_feather(ck, P + "body_fletch_%d_%d" % (sx, k), q1 + off, q1 + off + ax * 0.13, 0.04, glow if k == 1 else feather))
    # capa de capim da estepe: tiras de palha e pano em duas camadas, pontas desiguais
    for row in range(2):
        n = 7 if row == 0 else 6
        for k in range(n):
            x = (k - (n - 1) / 2.0) * (0.36 / n)
            L = 0.3 + row * 0.2 + ((k * 7 + row * 3) % 5) * 0.03
            y0 = back + 0.03 + r * 0.12 - row * 0.02
            m = (grass, t, grass, t2)[(k + row) % 4]
            chest.append(ck.blade(P + "body_ghillie_%d_%d" % (row, k), (x * 0.9, y0, zn - 0.06 - row * 0.04), (x * 1.9, y0 + 0.1 + row * 0.04, zn - 0.06 - L),
                                  0.085, 0.014, m, (1, 0, 0), 0.25))
    ck._rigid(outward(chest), rig, "chest")
    body_belt(ck, base, P + "body_belt", zw - 0.035, zw + 0.03, 1.18, leather)
    wf = -b["waist"] * d * 1.2
    hips = [ck.box(P + "body_buckle", (0.065, 0.025, 0.055), (0, wf - 0.01, zw), gold, 0.008),
            ck.ball(P + "body_buckle_gem", 0.02, (0, wf - 0.028, zw), glow),
            ck.ball(P + "body_pouch", 0.048, (-0.11, wf * 0.93 - 0.02, zw - 0.04), leather, (1, 0.6, 1)),
            ck.box(P + "body_tasset_f", (0.12, 0.014, 0.13), (0, wf - 0.004, zw - 0.1), t, 0.004)]
    for k in range(5):                   # franja de capim na cintura, atrás
        x = (k - 2) * 0.055
        hips.append(ck.blade(P + "body_fringe_%d" % k, (x, -wf, zw - 0.02), (x * 1.3, -wf + 0.04, zw - 0.2 - (k % 2) * 0.04), 0.06, 0.012, grass if k % 2 == 0 else t2, (1, 0, 0), 0.25))
    ck._rigid(outward(hips), rig, "hips")
    sh = V(j["shoulder.L"])              # ombreira de arqueiro na esquerda com garra de falcão
    pa = [ck.ball(P + "body_pauldron", b["arm"] * 2.4, sh + V((0.06, 0, 0.06)), t, (1.1, 1.05, 0.6)),
          ck.ball(P + "body_pauldron_rim", b["arm"] * 2.47, sh + V((0.06, 0, 0.035)), gold, (1.12, 1.07, 0.15))]
    for k in range(3):
        pa += curve(ck, P + "body_talon_%d" % k, sh + V((0.08, (k - 1) * 0.045, 0.1)), sh + V((0.2, (k - 1) * 0.07, 0.12)), (0, 0, 0.06), 0.02, gold, 3, 6)
    ck._rigid(outward(pa), rig, "upper_arm.L")
    _act2_arms_boots(ck, base, P, t, t2, leather, leather, gold, fur)


def build_gunner(ck, base, mats, style):
    """ran_a35 — Artilheiro de Cerco (Atirador, mosquete)."""
    V = Vector
    rig, body, b, j = base["rig"], base["body"], base["b"], base["j"]
    t, t2, gold, dark, leather, wood, metal = mats["tint"], mats["tint2"], mats["trim"], mats["dark"], mats["leather"], mats["wood"], mats["metal"]
    brass = ck.mat("m_ran_brass", BRASS, 0.35)
    fur = ck.mat("m_ran_fur_cream", FURS["cream"], 0.95)
    glow = tint_glow(ck)
    P = "arm_%s_" % style
    c, r = V(base["head_c"]), b["head"]
    # ---------------- cabeça: touca de piloto com abas, faixa de cor no topo, óculos na testa, luneta no olho direito ----------------
    head = [ck._shell(P + "head_cap", c, r * 1.15, 0.32, -0.75, -0.55, 0.04, t),
            ck.tube(P + "head_strap", c + V((0, 0, r * 0.4)), c + V((0, 0, r * 0.5)), r * 1.19, r * 1.17, leather, 24)]
    arc = [c + V((0, math.sin(a) * r * 1.17, math.cos(a) * r * 1.17)) for a in [-0.95 + k * 0.38 for k in range(7)]]
    for k in range(6):                   # rolo acolchoado da testa à nuca (a cor de destaque lê de cima)
        head.append(ck.tube(P + "head_ridge_%d" % k, arc[k], arc[k + 1], r * 0.2, r * 0.2, t2, 8))
    for sx in (-1, 1):
        head += [ck.ball(P + "head_flap_%d" % sx, r * 0.4, c + V((sx * r * 1.08, -r * 0.05, -r * 0.35)), leather, (0.35, 0.9, 1.25)),
                 ck.ball(P + "head_flap_fur_%d" % sx, r * 0.24, c + V((sx * r * 1.06, -r * 0.05, -r * 0.78)), fur, (0.5, 0.9, 0.7)),
                 ck.ball(P + "head_stud_%d" % sx, r * 0.1, c + V((sx * r * 1.19, -r * 0.05, r * 0.02)), brass)]
        p = c + V((sx * r * 0.36, -r * 1.02, r * 0.66))          # óculos de latão levantados
        head += [ck.tube(P + "head_lens_rim_%d" % sx, p + V((0, 0.03, 0.01)), p - V((0, 0.045, 0.012)), r * 0.3, r * 0.27, brass, 12),
                 ck.ball(P + "head_lens_%d" % sx, r * 0.23, p - V((0, 0.04, 0.012)), glow, (1, 0.4, 1))]
    head.append(ck.box(P + "head_bridge", (r * 0.3, 0.03, 0.03), c + V((0, -r * 1.1, r * 0.66)), brass, 0.008))
    e = c + V((-r * 0.36, -r * 0.98, r * 0.1))                  # luneta: tubo de latão em dois corpos, lente acesa
    head += [ck.tube(P + "head_scope_a", e, e + V((0, -r * 0.5, 0)), r * 0.24, r * 0.22, brass, 10),
             ck.tube(P + "head_scope_b", e + V((0, -r * 0.45, 0)), e + V((0, -r * 0.8, 0)), r * 0.17, r * 0.19, dark, 10),
             ck.tube(P + "head_scope_ring", e + V((0, -r * 0.76, 0)), e + V((0, -r * 0.84, 0)), r * 0.22, r * 0.22, brass, 10),
             ck.ball(P + "head_scope_lens", r * 0.17, e + V((0, -r * 0.83, 0)), glow, (1, 0.35, 1)),
             ck.tube(P + "head_scope_arm", e + V((0, -r * 0.1, r * 0.2)), c + V((-r * 0.75, -r * 0.75, r * 0.45)), 0.014, 0.014, brass, 6)]
    ck._rigid(outward(head), rig, "head")
    # ---------------- corpo: casaco comprido, gola alta, cartucheiras em X, ombreira de coice ----------------
    ck.armor_piece(body, rig, P + "body_coat", "torso", t, 0.014, 0.014, 0.03)
    ck.armor_piece(body, rig, P + "body_legs", "legs", dark, 0.008, 0.012)
    tails = ck.skirt(P + "body_tails", b, body, rig, t, 0.25, 1.55)
    d = b["depth"]
    front = -b["chest"] * d - 0.03
    back = b["chest"] * d + 0.03
    zc, zn, zw = ck.Z["chest"], ck.Z["neck"], ck.Z["waist"]
    chest = []
    for k in range(9):                   # gola alta aberta na frente
        a = math.pi * (-0.1 + 1.2 * k / 8)
        p = V((math.cos(a) * b["chest"] * 0.6, math.sin(a) * b["chest"] * 0.55, zn - 0.03))
        chest.append(ck.blade(P + "body_collar_%d" % k, p, p + V((math.cos(a) * 0.05, math.sin(a) * 0.05, 0.13)), 0.1, 0.014, t2 if k % 2 else t, (-math.sin(a), math.cos(a), 0), 0.55))
    for sx in (-1, 1):                   # cartucheiras cruzadas (frente e costas), cartuchos de latão
        a0, a1 = V((sx * 0.15, front + 0.015, zc + 0.15)), V((-sx * 0.13, front + 0.015, zw + 0.04))
        chest += [ck.tube(P + "body_belt_f%d" % sx, a0, a1, 0.026, 0.026, leather, 6),
                  ck.tube(P + "body_belt_b%d" % sx, (sx * 0.15, back - 0.012, zc + 0.15), (-sx * 0.13, back - 0.012, zw + 0.04), 0.026, 0.026, leather, 6)]
        for k in range(5):
            p = a0.lerp(a1, (k + 0.6) / 5.6)
            chest.append(ck.tube(P + "body_cart_%d_%d" % (sx, k), p + V((0, -0.012, -0.02)), p + V((0, -0.03, 0.03)), 0.015, 0.013, brass, 6))
        chest.append(ck.box(P + "body_lapel_%d" % sx, (0.07, 0.014, 0.17), (sx * 0.06, front - 0.002, zc + 0.03), t2, 0.004))
    chest += [ck.ball(P + "body_button_%d" % k, 0.018, (0, front - 0.016, zc + 0.09 - k * 0.075), brass) for k in range(3)]
    # barril de pólvora atravessado nas costas (atrás da cabeça não: abaixo da nuca), aros de ferro, pavio aceso subindo
    ky = back + 0.115
    kz = zc + 0.02
    chest += [ck.tube(P + "body_keg", (-0.2, ky, kz), (0.2, ky, kz), 0.105, 0.105, wood, 12),
              ck.tube(P + "body_keg_belly", (-0.11, ky, kz), (0.11, ky, kz), 0.118, 0.118, wood, 12)]
    for k, x in enumerate((-0.19, -0.115, 0.115, 0.19)):
        chest.append(ck.tube(P + "body_keg_hoop_%d" % k, (x - 0.014, ky, kz), (x + 0.014, ky, kz), 0.122 if abs(x) < 0.15 else 0.11, 0.122 if abs(x) < 0.15 else 0.11, metal, 12))
    chest += [ck.box(P + "body_keg_tag", (0.12, 0.02, 0.1), (0, ky + 0.115, kz), t2, 0.005),
              ck.tube(P + "body_keg_bung", (0.06, ky, kz + 0.1), (0.06, ky, kz + 0.15), 0.03, 0.026, brass, 8)]
    fz = c.z + r * 0.35                  # o pavio sobe por fora da cabeça (lado esquerdo) e a faísca aparece de frente e de cima
    fx = r * 1.3
    chest += curve(ck, P + "body_fuse", (0.06, ky, kz + 0.14), (fx, ky - 0.02, fz), (0.1, 0.06, -0.08), 0.013, leather, 6, 5, 0.011)
    chest += [ck.ball(P + "body_fuse_spark", 0.055, (fx, ky - 0.02, fz + 0.01), glow),
              ck.blade(P + "body_fuse_flare", (fx, ky - 0.02, fz + 0.02), (fx + 0.02, ky - 0.03, fz + 0.2), 0.08, 0.04, glow, (1, 0, 0), 0.35)]
    ck._rigid(outward(chest), rig, "chest")
    body_belt(ck, base, P + "body_belt", zw - 0.04, zw + 0.035, 1.2, leather)
    wf = -b["waist"] * d * 1.2
    hips = [ck.box(P + "body_buckle", (0.075, 0.025, 0.065), (0, wf - 0.01, zw), brass, 0.008),
            ck.ball(P + "body_buckle_gem", 0.022, (0, wf - 0.03, zw), glow),
            ck.ball(P + "body_flask", 0.05, (0.13, wf * 0.8, zw - 0.07), brass, (0.8, 0.7, 1.25)),
            ck.ball(P + "body_flask_cap", 0.02, (0.13, wf * 0.8, zw - 0.0), dark),
            ck.ball(P + "body_pouch", 0.05, (-0.13, wf * 0.8, zw - 0.06), leather, (0.8, 0.8, 1.0))]
    ck._rigid(outward(hips), rig, "hips")
    sh = V(j["shoulder.R"])              # ombreira acolchoada do coice (direita), rebites de latão
    pa = [ck.ball(P + "body_pad", b["arm"] * 2.6, sh + V((-0.06, 0, 0.06)), leather, (1.1, 1.1, 0.62)),
          ck.ball(P + "body_pad_rim", b["arm"] * 2.68, sh + V((-0.06, 0, 0.03)), brass, (1.12, 1.12, 0.15))]
    for k in range(3):
        pa.append(ck.box(P + "body_pad_quilt_%d" % k, (0.03, b["arm"] * 4.4, 0.03), sh + V((-0.02 - k * 0.045, 0, 0.115 - k * 0.022)), t, 0.01))
    ck._rigid(outward(pa), rig, "upper_arm.R")
    sh = V(j["shoulder.L"])
    ck._rigid(outward([ck.ball(P + "body_epaulet", b["arm"] * 2.0, sh + V((0.05, 0, 0.05)), t2, (1.1, 1.05, 0.5)),
                       ck.ball(P + "body_epaulet_stud", 0.028, sh + V((0.07, 0, 0.1)), brass)]), rig, "upper_arm.L")
    _act2_arms_boots(ck, base, P, t, brass, leather, leather, brass)


def build_trollhunter(ck, base, mats, style):
    """ran_l35 — Caça-Trolls (Lanceiro, lança)."""
    V = Vector
    rig, body, b, j = base["rig"], base["body"], base["b"], base["j"]
    t, t2, gold, dark, leather, wood, metal = mats["tint"], mats["tint2"], mats["trim"], mats["dark"], mats["leather"], mats["wood"], mats["metal"]
    bone = ck.mat("m_ran_bone", BONE, 0.7)
    hide = ck.mat("m_ran_troll", TROLL, 0.9)
    fur = ck.mat("m_ran_fur_brown", FURS["brown"], 0.95)
    glow = tint_glow(ck)
    P = "arm_%s_" % style
    c, r = V(base["head_c"]), b["head"]
    # ---------------- cabeça: elmo aberto, testeira de ferro, duas presas de troll enormes subindo das bochechas ----------------
    head = [ck._shell(P + "head_helm", c, r * 1.16, 0.3, -0.8, -0.45, 0.045, t),
            ck.box(P + "head_brow", (r * 1.7, 0.09, r * 0.2), c + V((0, -r * 1.12, r * 0.42)), metal, 0.03),
            ck.box(P + "head_nasal", (0.07, 0.07, r * 0.6), c + V((0, -r * 1.2, r * 0.14)), metal, 0.02),
            ck.ball(P + "head_gem", r * 0.13, c + V((0, -r * 1.2, r * 0.46)), glow, (1.0, 0.5, 1.2))]
    for sx in (-1, 1):
        root = c + V((sx * r * 1.0, -r * 0.55, -r * 0.42))
        head += [ck.ball(P + "head_cheek_%d" % sx, r * 0.36, root + V((0, r * 0.12, r * 0.1)), metal, (0.45, 1.0, 1.1)),
                 ck.tube(P + "head_tusk_ring_%d" % sx, root + V((sx * r * 0.06, -r * 0.1, r * 0.02)), root + V((sx * r * 0.14, -r * 0.2, r * 0.16)), r * 0.25, r * 0.23, gold, 10)]
        head += curve(ck, P + "head_tusk_%d" % sx, root + V((sx * r * 0.1, -r * 0.15, r * 0.08)), c + V((sx * r * 1.5, -r * 0.75, r * 1.75)),
                      (sx * r * 0.42, -r * 0.5, -r * 0.25), r * 0.21, bone, 6, 10, 0.006)
    for k in range(6):                   # espinhos de troll em fila no topo do elmo, da testa à nuca
        a = -0.75 + k * 0.42
        root = c + V((0, math.sin(a) * r * 1.12, math.cos(a) * r * 1.12))
        head.append(ck.blade(P + "head_spine_%d" % k, root, root + V((0, math.sin(a + 0.45), math.cos(a + 0.45))) * r * (0.85 - abs(k - 2) * 0.08), r * 0.46, 0.07,
                             hide if k % 2 else t2, (0, math.cos(a), -math.sin(a)), 0.4))
    ck._rigid(outward(head), rig, "head")
    # ---------------- corpo ----------------
    ck.armor_piece(body, rig, P + "body_vest", "torso", t, 0.012, 0.014, 0.05)
    ck.armor_piece(body, rig, P + "body_legs", "legs", leather, 0.008, 0.012)
    d = b["depth"]
    front = -b["chest"] * d - 0.03
    back = b["chest"] * d + 0.03
    zc, zn, zw = ck.Z["chest"], ck.Z["neck"], ck.Z["waist"]
    chest = []
    for sx in (-1, 1):
        chest.append(ck.tube(P + "body_strap_f%d" % sx, (sx * 0.15, front + 0.015, zc + 0.15), (-sx * 0.13, front + 0.015, zw + 0.04), 0.02, 0.02, leather, 6))
    chest += [ck.tube(P + "body_disc", (0, front + 0.01, zc - 0.02), (0, front - 0.03, zc - 0.02), 0.07, 0.062, metal, 10),
              ck.ball(P + "body_rune", 0.03, (0, front - 0.034, zc - 0.02), glow, (1.0, 0.45, 1.4))]
    for k in range(7):                   # colar de dentes de troll
        a = math.pi * (0.2 + 0.6 * k / 6.0)
        p = V((math.cos(a) * b["chest"] * 0.52, -math.sin(a) * b["chest"] * 0.58 - 0.02, zn - 0.08 - math.sin(a) * 0.035))
        chest.append(ck.tube(P + "body_tooth_%d" % k, p, p + V((0, -0.012, -0.075 if k % 2 else -0.055)), 0.018, 0.003, bone, 6))
    # gola de couro de troll: rolo grosso em volta dos ombros com verrugas de osso
    rw = abs(V(j["shoulder.L"]).x) + b["arm"] * 1.2
    n = 14
    for k in range(n):
        a = math.tau * (k + 0.5) / n
        dv = V((math.cos(a), math.sin(a) * 0.84, 0))
        chest.append(ck.ball(P + "body_collar_%d" % k, 0.085, dv * rw + V((0, 0, zn - 0.06)), hide, (1.0, 1.0, 0.72)))
        if k % 2 == 0 and dv.y > -0.5:
            chest.append(ck.tube(P + "body_collar_spike_%d" % k, dv * rw * 1.05 + V((0, 0, zn - 0.03)), dv * rw * 1.5 + V((0, 0, zn + 0.05)), 0.026, 0.003, bone, 6))
    # manto de couro de troll nas costas (passa por fora da cabeça), espinhos em fila na espinha
    yb = back + 0.05 + r * 0.2
    cloak_pts = [(0, back + 0.03, zn - 0.05), (0, yb, zc + 0.02), (0, yb - 0.02, zw + 0.0), (0, yb + 0.03, zw - 0.17), (0, yb + 0.0, zw - 0.3)]
    chest.append(ribbon(ck, P + "body_cloak", cloak_pts, (1, 0, 0), [0.4, 0.46, 0.42, 0.36, 0.2], 0.035, hide))
    for sx in (-1, 1):
        chest.append(ribbon(ck, P + "body_cloak_edge_%d" % sx, [(sx * 0.2, back + 0.035, zn - 0.06), (sx * 0.235, yb + 0.012, zc + 0.02), (sx * 0.215, yb - 0.008, zw),
                                                                 (sx * 0.18, yb + 0.04, zw - 0.17)], (1, 0, 0), [0.05, 0.05, 0.05, 0.03], 0.045, t2))
    for k in range(5):
        tt = k / 4.0
        p = V((0, yb + 0.01 - 0.02 * tt, zc + 0.1 - tt * 0.36))
        chest.append(ck.tube(P + "body_cloak_spine_%d" % k, p, p + V((0, 0.13 - tt * 0.04, 0.06)), 0.036 - tt * 0.008, 0.004, bone, 6))
    # leque de dardos de caça atrás do ombro direito, pontas acesas
    for k in range(4):
        off = (k - 1.5) * 0.085
        p0 = V((0.06 + off * 0.3, yb + 0.05, zw + 0.02))
        p1 = V((-0.12 + off * 2.2, yb + 0.1 + r * 0.25, zn + 0.42 - abs(k - 1.5) * 0.04))
        ax = (p1 - p0).normalized()
        chest += [ck.tube(P + "body_jav_%d" % k, p0, p1, 0.013, 0.013, wood, 6),
                  ck.blade(P + "body_javtip_%d" % k, p1, p1 + ax * 0.14, 0.06, 0.02, glow, (1, 0, 0)),
                  ck.tube(P + "body_javsock_%d" % k, p1 - ax * 0.03, p1 + ax * 0.01, 0.02, 0.018, metal, 6)]
    chest.append(ck.tube(P + "body_javband", V((0.02, yb + 0.03, zc - 0.07)), V((0.02, yb + 0.1, zc - 0.05)), 0.075, 0.075, leather, 8))
    ck._rigid(outward(chest), rig, "chest")
    body_belt(ck, base, P + "body_belt", zw - 0.04, zw + 0.035, 1.2, leather)
    wf = -b["waist"] * d * 1.2
    hips = [ck.ball(P + "body_buckle", 0.055, (0, wf - 0.008, zw), bone, (1.0, 0.6, 1.0)),
            ck.ball(P + "body_buckle_eye_l", 0.014, (-0.02, wf - 0.04, zw + 0.012), glow),
            ck.ball(P + "body_buckle_eye_r", 0.014, (0.02, wf - 0.04, zw + 0.012), glow),
            ck.blade(P + "body_flap_f", (0, wf - 0.012, zw - 0.02), (0, wf - 0.04, zw - 0.25), 0.18, 0.014, hide, (1, 0, 0), 0.3),
            ck.blade(P + "body_flap_f2", (0, wf - 0.02, zw - 0.02), (0, wf - 0.05, zw - 0.17), 0.1, 0.012, t2, (1, 0, 0), 0.3)]
    for sx in (-1, 1):                   # troféu: orelha/dente de troll pendurado
        p = V((sx * b["waist"] * 1.2, 0.0, zw - 0.05))
        hips.append(ck.tube(P + "body_trophy_%d" % sx, p, p + V((sx * 0.02, 0, -0.13)), 0.03, 0.004, bone, 6))
    ck._rigid(outward(hips), rig, "hips")
    sh = V(j["shoulder.L"])              # troféu no ombro esquerdo: mão de troll em garra (3 unhas de osso)
    tro = [ck.ball(P + "body_pauldron", b["arm"] * 2.6, sh + V((0.06, 0, 0.06)), hide, (1.1, 1.08, 0.66)),
           ck.ball(P + "body_pauldron_rim", b["arm"] * 2.68, sh + V((0.06, 0, 0.03)), metal, (1.12, 1.1, 0.15))]
    for k in range(3):
        fy = (k - 1) * 0.07
        tro += curve(ck, P + "body_claw_%d" % k, sh + V((0.07, fy, 0.1)), sh + V((0.24, fy * 1.5, 0.2 - abs(k - 1) * 0.03)), (0.02, 0, 0.08), 0.034, bone, 4, 6)
    ck._rigid(outward(tro), rig, "upper_arm.L")
    sh = V(j["shoulder.R"])
    ck._rigid(outward([ck.ball(P + "body_cap_r", b["arm"] * 2.1, sh + V((-0.05, 0, 0.05)), t, (1.1, 1.05, 0.55)),
                       ck.ball(P + "body_cap_r_rim", b["arm"] * 2.17, sh + V((-0.05, 0, 0.028)), metal, (1.12, 1.07, 0.14))]), rig, "upper_arm.R")
    _act2_arms_boots(ck, base, P, t, t2, leather, leather, metal, fur)


ACT2_SETS = {"ran_c35": build_scout, "ran_a35": build_gunner, "ran_l35": build_trollhunter}
# armas do Ato II ("glow": "tint" -> material tint_glow, pintado na cor do nível)
RAN_BOWS["ran_c35"] = {"tips": "hawk", "size": 1.26, "curve": 1.15, "gem": True, "fins": True, "glow": "tint"}
RAN_RIFLES["ran_a35"] = {"bands": 4, "scope": True, "carved": True, "heavy": True, "drum": True, "glow": "tint"}
RAN_SPEARS["ran_l35"] = {"head": "troll", "len": 1.16, "fang": True, "tassel": True, "gold": True, "glow": "tint"}


def register(ck):
    import paladin_sets
    for style, fn in ACT2_SETS.items():                    # Ato II: um visual novo por build (35/40/45 + Ápice)
        ck.SET_STYLES[style] = (lambda st, f: (lambda base, mats: (f(ck, base, mats, st), paladin_sets.join_slots("arm_%s_" % st))))(style, fn)
    for style, cfg in RAN_SETS.items():
        ck.SET_STYLES[style] = (lambda st, cf: (lambda base, mats: (build(ck, base, mats, st, cf), paladin_sets.join_slots("arm_%s_" % st))))(style, cfg)
    for style, cfg in RAN_BOWS.items():
        ck.SET_WEAPONS[style + "_bow"] = (lambda st, cf: (lambda base, mats: build_bow(ck, base, mats, st, cf)))(style, cfg)
    for style, cfg in RAN_RIFLES.items():
        ck.SET_WEAPONS[style + "_rifle"] = (lambda st, cf: (lambda base, mats: build_rifle(ck, base, mats, st, cf)))(style, cfg)
    for style, cfg in LAN_SETS.items():
        ck.SET_STYLES[style] = (lambda st, cf: (lambda base, mats: (build_lancer(ck, base, mats, st, cf), paladin_sets.join_slots("arm_%s_" % st))))(style, cfg)
    for style, cfg in RAN_SPEARS.items():
        ck.SET_WEAPONS[style + "_spear"] = (lambda st, cf: (lambda base, mats: build_spear(ck, base, mats, st, cf)))(style, cfg)


# ---------------------------------------------------------------------------
# Ato III (nível 50, GDD ato3-lendarios-50): UM visual novo por build no tema de Lumeria. Malhas no kit extra
# kit_ranger_<sexo>_a3.glb (chibi_kit.A3_STYLES); motivos comuns em lumeria_kit.py.
#   ran_c50 Caçador = Arco da Lanterna Errante: capuz curto de seda (tint2, verde-sálvia), máscara de pássaro em porcelana
#           com bico de ponta de ouro e penas na sobrancelha, aljava-lanterna alta nas costas (gaiola de ouro com a chama
#           dentro, flechas saindo por cima), capa curta em cinco fitas, ombreira de penas de porcelana.
def build_wandering_lantern(ck, base, mats, style):
    """ran_c50 — Arco da Lanterna Errante (Caçador)."""
    import lumeria_kit as lk
    import berserker_sets as bs
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
    # ---------------- cabeça: capuz curto com bico atrás, máscara de pássaro ----------------
    head = [ck._shell(P + "head_hood", c, r * 1.11, 0.12, -0.8, -0.6, 0.04, t2),
            ck.tube(P + "head_hood_tip", c + V((0, r * 0.75, r * 0.6)), c + V((0, r * 1.5, r * 0.28)), r * 0.42, r * 0.03, t2, 8)]
    head += lk.mask(ck, P + "head_mask", c + V((0, -r * 1.0, -r * 0.02)), r * 0.66, M, kind="bird", tears=(1,), wide=1.3, tall=0.85, tear_len=0.34)
    ck._rigid(bs._outward(head), rig, "head")
    # ---------------- corpo: gibão, capa curta de fitas, aljava-lanterna ----------------
    ck.armor_piece(body, rig, P + "body_jerkin", "torso", t, 0.014, 0.014, 0.03)
    ck.armor_piece(body, rig, P + "body_legs", "legs", leather, 0.008, 0.012)
    chest = [ck.tube(P + "body_collar", V((0, 0, zn - 0.06)), V((0, 0, zn + 0.02)), b["chest"] * 0.78, b["chest"] * 0.52, t2, 14),
             ck.ball(P + "body_clasp", 0.036, (0, front - 0.03, zn - 0.07), porc, (1, 0.5, 1.15)),
             ck.ball(P + "body_clasp_tear", 0.016, (0, front - 0.05, zn - 0.08), glow, (0.8, 0.6, 1.7)),
             ck.tube(P + "body_strap", (b["chest"] * 0.8, front + 0.03, zn - 0.06), (-b["chest"] * 0.7, front - 0.01, zw + 0.08), 0.022, 0.022, leather, 5)]
    for k in range(5):                   # capa curta: cinco fitas em leque pelas costas e pelos ombros
        a = math.radians(-64 + k * 32)
        p0 = V((math.sin(a) * b["chest"] * 0.75, back - 0.03 + math.cos(a) * 0.03, zn - 0.03))
        p1 = V((math.sin(a) * (b["shoulder"] + 0.2), back + 0.1 + math.cos(a) * 0.16, zw + 0.02 + abs(k - 2) * 0.07))
        chest.append(lk.silk(ck, P + "body_cape%d" % k, p0, p1, (math.cos(a), -math.sin(a) * 0.6, 0), 0.13, 0.17, t2, (0, 0.035, 0), 4))
    # aljava-lanterna: gaiola alta de ouro, inclinada, com a chama dentro; flechas com penas de seda saindo por cima
    q0, q1 = V((-0.12, back + 0.1, zw + 0.02)), V((0.3, back + 0.2, zn + 0.42))
    ax = (q1 - q0).normalized()
    u = ax.cross(V((0, 1, 0))).normalized()
    w = ax.cross(u).normalized()
    chest += [ck.tube(P + "body_quiver_flame", q0.lerp(q1, 0.12), q0.lerp(q1, 0.88), 0.07, 0.076, glow, 8),
              ck.tube(P + "body_quiver_foot", q0 - ax * 0.03, q0.lerp(q1, 0.12), 0.06, 0.095, gold, 8),
              ck.tube(P + "body_quiver_mouth", q0.lerp(q1, 0.88), q1, 0.096, 0.104, gold, 8)]
    for k in range(3):
        m_ = q0.lerp(q1, 0.3 + k * 0.2)
        chest.append(ck.tube(P + "body_quiver_ring%d" % k, m_ - ax * 0.012, m_ + ax * 0.012, 0.096, 0.096, gold, 8))
    for k in range(4):
        a = math.tau * (k + 0.5) / 4
        o = (u * math.cos(a) + w * math.sin(a)) * 0.09
        chest.append(ck.tube(P + "body_quiver_post%d" % k, q0.lerp(q1, 0.1) + o, q0.lerp(q1, 0.9) + o, 0.009, 0.009, gold, 4))
    for k in range(4):
        a = math.tau * k / 4 + 0.4
        o = (u * math.cos(a) + w * math.sin(a)) * 0.035
        s0, s1 = q1 + o, q1 + o * 1.8 + ax * (0.2 + 0.03 * (k % 2))
        chest += [ck.tube(P + "body_arrow%d" % k, s0, s1, 0.008, 0.008, leather, 4),
                  ck.blade(P + "body_fletch%d" % k, s1 - ax * 0.1, s1 + ax * 0.02, 0.06, 0.012, porc if k % 2 else t2, o, 0.5)]
    ck._rigid(bs._outward(chest), rig, "chest")
    bs._belt(ck, base, P + "body_belt", zw - 0.04, zw + 0.03, 1.2, leather)
    wf = -b["waist"] * d * 1.22
    hips = [ck.ball(P + "body_buckle", 0.036, (0, wf - 0.012, zw - 0.005), gold, (1.1, 0.5, 1.1))]
    hips += lk.lantern(ck, P + "body_hip_lantern", (b["waist"] * 1.3, -0.04, zw - 0.15), 0.055, M, hang=(b["waist"] * 1.22, -0.04, zw - 0.02))
    for sx in (-1, 1):                   # abas curtas do gibão
        hips.append(lk.silk(ck, P + "body_tail%d" % sx, (sx * 0.07, -wf + 0.01, zw - 0.02), (sx * 0.11, -wf + 0.07, zw - 0.27), (1, 0, 0), 0.12, 0.14, t, (0, 0.02, 0), 2))
    ck._rigid(bs._outward(hips), rig, "hips")
    for s, sx in ((".R", -1), (".L", 1)):
        tag = s.replace(".", "_")
        sh = V(j["shoulder" + s])
        pa = [ck.ball(P + "body_pad" + tag, b["arm"] * 2.1, sh + V((sx * 0.05, 0, 0.03)), t2, (1.15, 1.1, 0.55))]
        if s == ".L":                    # ombreira de penas de porcelana no braço do arco
            for k in range(4):
                a = math.radians(-50 + k * 33)
                root = sh + V((sx * 0.06, math.sin(a) * 0.05, 0.05))
                pa.append(ck.blade(P + "body_feather%d" % k, root, root + V((sx * 0.25, math.sin(a) * 0.2, 0.02 - abs(k - 1.5) * 0.03)), 0.1, 0.022, porc if k % 2 == 0 else gold, (0, 1, 0), 0.5))
        ck._rigid(bs._outward(pa), rig, "upper_arm" + s)
    lk.limbs(ck, base, mats, P, M, "leather", ribbon=0.6, boots_m=leather)


ACT3_SETS = {"ran_c50": build_wandering_lantern}
