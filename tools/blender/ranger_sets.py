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
    if cfg.get("fang"):            # presas de travar logo abaixo da ponta
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
    if glow is not None and cfg.get("glow"):
        parts.append(ck.tube(n + "rune", g + ax * 0.3, g + ax * 0.9 * L, 0.024, 0.023, glow, 8))
    return parts


def build_spear(ck, base, mats, style, cfg):
    V = Vector
    g = V(ck.hand_center(base, ".R"))
    ax = V(SPEAR_AXIS).normalized()
    glow = ck.mat("m_ran_spear_glow_%d" % int(sum(cfg["glow"]) * 100), cfg["glow"], 0.3, 2.5) if cfg.get("glow") else None
    obj = ck._join(spear_parts(ck, "s_%s_" % style, g, ax, mats, cfg, glow), "wpn_main_spear_%s" % style)
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
    for style, cfg in LAN_SETS.items():
        ck.SET_STYLES[style] = (lambda st, cf: (lambda base, mats: (build_lancer(ck, base, mats, st, cf), paladin_sets.join_slots("arm_%s_" % st))))(style, cfg)
    for style, cfg in RAN_SPEARS.items():
        ck.SET_WEAPONS[style + "_spear"] = (lambda st, cf: (lambda base, mats: build_spear(ck, base, mats, st, cf)))(style, cfg)
