"""Formas Ancestrais do Druida (ascensão 35, Ato II): form_ent.glb, form_alpha.glb e form_bird.glb.

Ent (Urso): árvore que anda — tronco largo, braços-galho, copa com galhada, coração de seiva aceso.
Lobo Alfa (Lobo): o lobo do druida maior e prateado, com juba, marca de lua na testa e olhos acesos.
Pássaro Arcano (Xamã): ave de luz — corpo pequeno, asas largas de penas em camadas, crista e cauda compridas, pontas acesas.
Mesmo rig dos monstros (build_monsters.MOB_BONES), então o jogo anima como as outras formas (FormModel) e os gestos têm
os mesmos nomes de druid_sets.FORM_CLIPS (maul, pounce, slam, roar, brace; impacto em EntityView.IMPACT_FRAME).
Armadura do conjunto: frm_<estilo>_<slot>_<osso>, pintada pela cor do item (materiais tint/tint2), como no Lobo/Urso.

Headless: blender -b --factory-startup --python <script que chama druid_ancestral.build(out_dir)>
"""
import math
import os
from mathutils import Vector

FORMS = ("ent", "alpha", "bird")
PREFIX = {"ent": "dru_b", "alpha": "dru_w", "bird": "dru_x"}      # conjuntos de cada build (druid_sets.DRU_SETS)


def _by_bone(ck, parts, tag):
    """Junta as partes do mesmo osso numa malha só (menos draw calls: cada boneco instancia o modelo inteiro)."""
    groups = {}
    for obj, bone in parts:
        groups.setdefault(bone, []).append(obj)
    return [(ck._join(objs, "%s_%s" % (tag, bone)), bone) for bone, objs in groups.items()]


# ---------------------------------------------------------------------------
# Ent
# ---------------------------------------------------------------------------
def ent(ck, lp, mk, bm, cid="form_ent"):
    V = Vector
    arm = lp.make_armature("rig_" + cid, mk.pivots(arm_r=(0.34, 0, 1.22), arm_l=(-0.34, 0, 1.22), head=(0, -0.1, 1.36),
                                                    leg_fr=(0.2, -0.16, 0.38), leg_fl=(-0.2, -0.16, 0.38), leg_br=(0.2, 0.16, 0.38), leg_bl=(-0.2, 0.16, 0.38)))
    bark = ck.mat("m_fent_bark", (0.42, 0.3, 0.2), 0.9)
    bark_d = ck.mat("m_fent_bark_d", (0.26, 0.18, 0.12), 0.9)
    moss = ck.mat("m_fent_moss", (0.38, 0.6, 0.28), 0.85)
    leaf = ck.mat("m_fent_leaf", (0.26, 0.5, 0.26), 0.8)
    leaf2 = ck.mat("m_fent_leaf2", (0.46, 0.74, 0.34), 0.8)
    glow = ck.mat("m_fent_glow", (0.6, 0.95, 0.3), 0.3, 1.1)
    pts = [((0, 0, 0.32), 0.44), ((0, 0.03, 0.9), 0.4), ((0, 0, 1.45), 0.31)]
    parts = [(mk.skin_body("trunk", pts, [(0, 1), (1, 2)], bark), "body")]
    # coração de seiva no peito (fenda acesa) e placas de casca
    parts.append((mk.blob("heart", 0.1, (0, -0.37, 0.98), glow, (0.7, 0.4, 1.3)), "body"))
    for i, (c, r) in enumerate([((0.22, -0.3, 1.0), 0.15), ((-0.22, -0.3, 1.0), 0.15), ((0.0, -0.36, 0.62), 0.17), ((0.1, 0.34, 0.95), 0.2), ((-0.28, 0.12, 0.55), 0.14)]):
        parts.append((mk.blob("plate%d" % i, r, c, bark_d if i < 3 else moss, (1.15, 0.45, 1.2)), "body"))
    # rosto: olhos acesos, sobrancelhas pesadas, boca talhada e barba de musgo
    for sx in (-1, 1):
        parts.append((mk.blob("eye%d" % sx, 0.065, (sx * 0.13, -0.34, 1.3), glow, (1, 0.5, 0.6)), "head"))
        parts.append((mk.blob("brow%d" % sx, 0.12, (sx * 0.14, -0.33, 1.4), bark_d, (1.3, 0.5, 0.4)), "head"))
    parts.append((mk.blob("mouth", 0.1, (0, -0.36, 1.12), bark_d, (1.5, 0.4, 0.5)), "head"))
    for k in range(5):
        x = (k - 2) * 0.07
        parts.append((mk.cone("beard%d" % k, (x, -0.36, 1.08), (x * 1.3, -0.4, 0.8 + abs(k - 2) * 0.06), 0.05, moss, 6), "head"))
    # raízes-pés: quatro raízes grossas com dedos
    for bone, sx, sy in (("leg_fr", 1, -1), ("leg_fl", -1, -1), ("leg_br", 1, 1), ("leg_bl", -1, 1)):
        top = V((sx * 0.2, sy * 0.16, 0.38))
        foot = V((sx * 0.62, sy * 0.52, 0.03))
        parts.append((ck.tube("root_" + bone, top, foot, 0.17, 0.07, bark_d, 8), bone))
        for k in (-1, 1):
            parts.append((ck.tube("toe_%s_%d" % (bone, k), foot, foot + V((sx * 0.16 - k * sy * 0.08, sy * 0.14 + k * sx * 0.08, -0.01)), 0.06, 0.015, bark_d, 6), bone))
    # braços-galho compridos com punho de nó, dedos-raiz e tufo de folhas no ombro
    for sx, bone in ((1, "arm_r"), (-1, "arm_l")):
        sh = V((sx * 0.34, 0, 1.22))
        el = V((sx * 0.8, -0.1, 0.95))
        hand = V((sx * 0.9, -0.28, 0.32))
        parts.append((ck.tube("branch%d" % sx, sh, el, 0.16, 0.11, bark, 8), bone))
        parts.append((ck.tube("forearm%d" % sx, el, hand, 0.11, 0.09, bark, 8), bone))
        parts.append((mk.blob("fist%d" % sx, 0.15, hand, bark_d, (1.0, 1.0, 1.1)), bone))
        for k in range(3):
            parts.append((ck.tube("finger%d_%d" % (sx, k), hand, hand + V((sx * 0.09 * (k - 1), -0.14, -0.22)), 0.05, 0.015, bark_d, 6), bone))
        parts.append((mk.blob("shoulder%d" % sx, 0.22, sh + V((sx * 0.06, 0, 0.12)), leaf2, (1.1, 1.0, 0.75)), bone))
        parts.append((mk.blob("mossarm%d" % sx, 0.13, el + V((0, 0, 0.1)), moss, (1.1, 0.8, 0.6)), bone))
    # copa em camadas + galhada que sai dela (lê de cima)
    for i, (c, r) in enumerate([((0, 0.06, 1.9), 0.6), ((-0.42, 0.1, 1.7), 0.4), ((0.44, 0.02, 1.72), 0.42), ((0.05, 0.4, 1.68), 0.38), ((0.0, -0.22, 1.78), 0.32), ((0.0, 0.05, 2.25), 0.34)]):
        parts.append((mk.blob("canopy%d" % i, r, c, leaf if i % 2 == 0 else leaf2, (1, 1, 0.8)), "head"))
    for sx in (-1, 1):
        root = V((sx * 0.2, 0.0, 2.0))
        mid = root + V((sx * 0.3, 0.02, 0.38))
        parts.append((ck.tube("horn_a%d" % sx, root, mid, 0.07, 0.05, bark_d, 6), "head"))
        parts.append((ck.tube("horn_b%d" % sx, mid, mid + V((sx * 0.2, 0.06, 0.3)), 0.05, 0.012, bark_d, 6), "head"))
        parts.append((ck.tube("horn_c%d" % sx, mid, mid + V((sx * -0.06, -0.1, 0.26)), 0.04, 0.01, bark_d, 6), "head"))
        parts.append((mk.blob("bud%d" % sx, 0.06, mid + V((sx * 0.2, 0.06, 0.32)), glow), "head"))
    mk.finish(arm, _by_bone(ck, parts, "ent"))
    bm.mob_actions(arm)
    return arm


def ent_armor(ck, lp, ds, arm, style, cfg, tint, tint2):
    """Peças do conjunto no Ent: coroa (cabeça), faixa e manto (corpo), braçadeiras (luvas) e anéis nas raízes (botas)."""
    V = Vector
    m = ds._mats(ck, cfg)
    P = "frm_%s_" % style
    groups = {}

    def put(slot, bone, obj):
        groups.setdefault((slot, bone), []).append(obj)

    # coroa em volta da copa + galhada do conjunto
    for k in range(8):
        a = math.tau * k / 8
        c = V((math.cos(a) * 0.5, 0.06 + math.sin(a) * 0.5, 1.6))
        put("head", "head", ck.ball(P + "head_leaf_%d" % k, 0.13, c, tint if k % 2 == 0 else tint2, (1.0, 1.0, 0.55)))
    for o in ds._antlers(ck, P + "head_", V((-0.24, -0.1, 2.1)), V((0.24, -0.1, 2.1)), max(cfg["antlers"], 0.6) * 1.6, m["bone"]):
        put("head", "head", o)
    if cfg.get("glow"):
        put("head", "head", ck.ball(P + "head_gem", 0.07, V((0, -0.36, 1.5)), m["glow"]))
    # faixa na cintura + manto nos ombros
    put("body", "body", ck.tube(P + "body_sash", V((0, 0.01, 0.62)), V((0, 0.01, 0.78)), 0.47, 0.45, tint, 14))
    put("body", "body", ck.tube(P + "body_sash_rim", V((0, 0.01, 0.78)), V((0, 0.01, 0.82)), 0.47, 0.47, tint2, 14))
    for k in range(10):
        a = math.tau * k / 10
        mat = m["leaf"] if cfg["mantle"] == "leaves" else m["fur"]
        put("body", "body", ck.ball(P + "body_collar_%d" % k, 0.11, V((math.cos(a) * 0.34, math.sin(a) * 0.3, 1.36)), mat, (1, 1, 0.7)))
    if cfg["pauldron"] in ("skull", "bark"):
        put("body", "body", ck.ball(P + "body_trophy", 0.1, V((0, -0.42, 1.2)), m["bone"] if cfg["pauldron"] == "skull" else m["bark"], (1, 0.7, 1)))
    # braçadeiras nos antebraços
    for sx, bone in ((1, "arm_r"), (-1, "arm_l")):
        el = V((sx * 0.8, -0.1, 0.95))
        hand = V((sx * 0.9, -0.28, 0.32))
        put("gloves", bone, ck.tube(P + "gloves_band_%s" % bone, el.lerp(hand, 0.35), el.lerp(hand, 0.7), 0.135, 0.125, tint, 10))
        put("gloves", bone, ck.tube(P + "gloves_rim_%s" % bone, el.lerp(hand, 0.7), el.lerp(hand, 0.76), 0.14, 0.14, tint2, 10))
    # anéis nas raízes
    for bone, sx, sy in (("leg_fr", 1, -1), ("leg_fl", -1, -1), ("leg_br", 1, 1), ("leg_bl", -1, 1)):
        top = V((sx * 0.2, sy * 0.16, 0.38))
        foot = V((sx * 0.62, sy * 0.52, 0.03))
        put("boots", bone, ck.tube(P + "boots_band_%s" % bone, top.lerp(foot, 0.35), top.lerp(foot, 0.6), 0.16, 0.13, tint, 10))
    for (slot, bone), objs in groups.items():
        obj = ck._join(objs, "frm_%s_%s_%s" % (style, slot, bone))
        ck._smooth(obj.data)
        lp.attach(obj, arm, bone)


# ---------------------------------------------------------------------------
# Lobo Alfa
# ---------------------------------------------------------------------------
def alpha(ck, lp, mk, cid="form_alpha"):
    """O lobo do druida (mob_kit.quadruped) prateado + juba de espinhos de pelo, marca de lua, olhos e garras acesos."""
    V = Vector
    arm = mk.quadruped(cid, (0.56, 0.6, 0.72), (0.24, 0.26, 0.38), (0.84, 0.87, 0.95), "wolf")
    hip = 0.45
    hc = V((0, -0.74, hip + 0.28))
    dark = ck.mat("m_falpha_mane", (0.26, 0.28, 0.4), 0.85)
    glow = ck.mat("m_falpha_glow", (0.35, 0.75, 1.0), 0.3, 1.2)
    parts = []
    # juba: três fileiras de tufos do pescoço até o meio do dorso
    for i in range(7):
        y = -0.58 + i * 0.13
        h = 0.2 - abs(i - 2) * 0.02
        for sx in (-0.09, 0.0, 0.09):
            root = V((sx, y, hip + 0.3 - abs(sx) * 0.5))
            parts.append((mk.cone("mane_%d_%d" % (i, int(sx * 100)), root, root + V((sx * 0.8, 0.09, h)), 0.06, dark, 6), "body"))
    # gola de pelo no peito
    for k in range(7):
        a = math.pi * (k / 6.0)
        parts.append((mk.blob("ruff%d" % k, 0.08, V((math.cos(a) * 0.2, -0.46, hip + 0.1 - math.sin(a) * 0.14)), dark, (1, 0.8, 1.2)), "body"))
    # marca de lua na testa + olhos acesos
    parts.append((mk.blob("moon", 0.05, hc + V((0, -0.13, 0.13)), glow, (1.3, 0.5, 0.8)), "head"))
    for sx in (-1, 1):
        parts.append((mk.blob("glare%d" % sx, 0.03, hc + V((sx * 0.085, -0.17, 0.05)), glow, (1.2, 0.5, 0.8)), "head"))
        parts.append((mk.cone("crest%d" % sx, hc + V((sx * 0.12, 0.04, 0.12)), hc + V((sx * 0.2, 0.16, 0.3)), 0.05, dark, 6), "head"))
    # garras acesas
    for bone, sx, sy in (("leg_fr", 1, -1), ("leg_fl", -1, -1), ("leg_br", 1, 1), ("leg_bl", -1, 1)):
        foot = V((sx * 0.19, sy * 0.38, 0.05))
        for k in (-1, 0, 1):
            parts.append((mk.cone("claw_%s_%d" % (bone, k), foot + V((k * 0.035, -0.05, 0.0)), foot + V((k * 0.05, -0.14, -0.03)), 0.022, glow, 5), bone))
    # ponta da cauda
    parts.append((mk.blob("tailtip", 0.07, V((0, 0.92, hip + 0.22)), glow, (0.8, 1.3, 0.8)), "tail"))
    mk.finish(arm, _by_bone(ck, parts, "alpha"))
    return arm


# ---------------------------------------------------------------------------
# Pássaro Arcano
# ---------------------------------------------------------------------------
BIRD_Z = 1.0          # altura do corpo no modelo (o jogo ainda sobe o boneco: Balance.ANC_BIRD_LIFT)


def bird(ck, lp, mk, bm, cid="form_bird"):
    V = Vector
    z = BIRD_Z
    bones = mk.pivots(arm_r=(0.16, 0.0, z + 0.1), arm_l=(-0.16, 0.0, z + 0.1), head=(0, -0.2, z + 0.16),
                      leg_fr=(0.09, 0.02, z - 0.16), leg_fl=(-0.09, 0.02, z - 0.16))
    bones["tail"] = ((0, 0.26, z - 0.02), (0, 0.6, z - 0.06), "body")
    arm = lp.make_armature("rig_" + cid, bones)
    plume = ck.mat("m_fbird_plume", (0.34, 0.5, 0.92), 0.6)
    plume_d = ck.mat("m_fbird_dark", (0.2, 0.26, 0.62), 0.6)
    plume_l = ck.mat("m_fbird_light", (0.8, 0.9, 1.0), 0.5)
    gold = ck.mat("m_fbird_gold", (0.98, 0.8, 0.36), 0.4)
    glow = ck.mat("m_fbird_glow", (0.45, 0.85, 1.0), 0.3, 1.2)
    m_eye, m_white = mk.base_mats()
    parts = [(mk.blob("body", 0.24, (0, 0.02, z), plume, (0.9, 1.25, 0.95)), "body"),
             (mk.blob("chest", 0.19, (0, -0.1, z - 0.04), plume_l, (0.85, 1.0, 0.9)), "body"),
             (mk.blob("head", 0.17, (0, -0.3, z + 0.24), plume, (0.95, 1.0, 0.95)), "head"),
             (mk.blob("cheek", 0.12, (0, -0.36, z + 0.2), plume_l, (1.05, 0.8, 0.8)), "head"),
             (mk.cone("beak", (0, -0.43, z + 0.22), (0, -0.62, z + 0.16), 0.06, gold, 6), "head")]
    parts += [(o, "head") for o in mk.eyes("fbird", [(-0.09, -0.41, z + 0.29), (0.09, -0.41, z + 0.29)], 0.04, m_eye, m_white)]
    # crista: três penas compridas para trás, ponta acesa
    for k in (-1, 0, 1):
        root = V((k * 0.05, -0.26, z + 0.38))
        tip = root + V((k * 0.12, 0.3, 0.26 - abs(k) * 0.06))
        parts.append((ck.blade("crest%d" % k, root, tip, 0.09, 0.02, plume_d if k else gold, (1, 0, 0), 0.4), "head"))
        parts.append((mk.blob("crest_tip%d" % k, 0.035, tip, glow), "head"))
    # asas: osso do braço na raiz; três camadas de penas (cobertura, médias, rêmiges) abrindo para o lado, pontas acesas
    for sx, bone in ((1, "arm_r"), (-1, "arm_l")):
        root = V((sx * 0.16, 0.0, z + 0.1))
        parts.append((mk.blob("wing_sh%d" % sx, 0.1, root + V((sx * 0.06, 0, 0.0)), plume, (1.3, 1.0, 0.8)), bone))
        for i in range(6):                          # rêmiges: leque da frente para trás
            t = i / 5.0
            tip = root + V((sx * (1.15 - 0.5 * t), 0.1 + 0.5 * t, 0.12 - 0.1 * t))
            parts.append((ck.blade("wing_p%d_%d" % (sx, i), root + V((sx * 0.1, 0.03 * i, 0)), tip, 0.2, 0.02, plume_d if i % 2 == 0 else plume, (0, 1, 0), 0.5), bone))
            if i < 4:
                parts.append((mk.blob("wing_tip%d_%d" % (sx, i), 0.035, tip, glow, (1.2, 1.2, 0.6)), bone))
        for i in range(4):                          # cobertura clara por cima
            t = i / 3.0
            tip = root + V((sx * (0.62 - 0.2 * t), 0.04 + 0.3 * t, 0.15))
            parts.append((ck.blade("wing_c%d_%d" % (sx, i), root + V((sx * 0.06, 0.02 * i, 0.03)), tip, 0.17, 0.02, plume_l, (0, 1, 0), 0.5), bone))
        parts.append((ck.tube("wing_b%d" % sx, root, root + V((sx * 0.62, 0.0, 0.16)), 0.045, 0.02, plume, 6), bone))
    # cauda: leque de penas compridas com "olho" aceso (osso próprio: ondula)
    for k in range(-2, 3):
        root = V((k * 0.04, 0.26, z - 0.02))
        tip = V((k * 0.2, 0.95 - abs(k) * 0.1, z - 0.22 + abs(k) * 0.03))
        parts.append((ck.blade("tail%d" % k, root, tip, 0.13, 0.02, plume_d if k % 2 else plume, (1, 0, 0), 0.6), "tail"))
        parts.append((mk.blob("tail_eye%d" % k, 0.04, root.lerp(tip, 0.82), glow if k % 2 == 0 else gold, (1.2, 1.2, 0.5)), "tail"))
    # garras recolhidas
    for sx, bone in ((1, "leg_fr"), (-1, "leg_fl")):
        hipp = V((sx * 0.09, 0.02, z - 0.16))
        foot = hipp + V((0, -0.06, -0.2))
        parts.append((ck.tube("leg%d" % sx, hipp, foot, 0.035, 0.025, gold, 6), bone))
        for k in (-1, 0, 1):
            parts.append((mk.cone("talon%d_%d" % (sx, k), foot, foot + V((k * 0.05, -0.09, -0.05)), 0.02, gold, 5), bone))
    mk.finish(arm, _by_bone(ck, parts, "bird"))
    bm.mob_actions(arm, floating=True)
    return arm


def bird_armor(ck, lp, ds, arm, style, cfg, tint, tint2):
    """Peças do conjunto no Pássaro: diadema (cabeça), peitoral e colar de penas (corpo), faixas nas asas (luvas) e anilhas (botas)."""
    V = Vector
    z = BIRD_Z
    m = ds._mats(ck, cfg)
    P = "frm_%s_" % style
    groups = {}

    def put(slot, bone, obj):
        groups.setdefault((slot, bone), []).append(obj)

    put("head", "head", ck.tube(P + "head_band", V((0, -0.3, z + 0.33)), V((0, -0.3, z + 0.37)), 0.15, 0.13, tint2, 12))
    put("head", "head", ck.ball(P + "head_cap", 0.12, V((0, -0.27, z + 0.36)), tint, (1.0, 1.0, 0.5)))
    for o in ds._antlers(ck, P + "head_", V((-0.08, -0.26, z + 0.38)), V((0.08, -0.26, z + 0.38)), cfg["antlers"] * 0.8, m["bone"]):
        put("head", "head", o)
    if cfg.get("glow"):
        put("head", "head", ck.ball(P + "head_gem", 0.035, V((0, -0.43, z + 0.34)), m["glow"]))
    put("body", "body", ck.ball(P + "body_plate", 0.17, V((0, -0.14, z - 0.05)), tint, (0.9, 0.8, 0.9)))
    for k in range(8):
        a = math.tau * k / 8
        mat = m["leaf"] if cfg["mantle"] == "leaves" else m["fur"]
        put("body", "body", ck.ball(P + "body_collar_%d" % k, 0.06, V((math.cos(a) * 0.16, -0.2 + math.sin(a) * 0.05, z + 0.1 + math.sin(a) * 0.12)), mat, (1, 0.8, 1)))
    put("body", "body", ck.tube(P + "body_rim", V((0, -0.02, z - 0.2)), V((0, 0.16, z - 0.2)), 0.2, 0.18, tint2, 12))
    for sx, bone in ((1, "arm_r"), (-1, "arm_l")):
        root = V((sx * 0.16, 0.0, z + 0.1))
        a, b = root + V((sx * 0.22, 0.0, 0.06)), root + V((sx * 0.4, 0.0, 0.11))
        put("gloves", bone, ck.tube(P + "gloves_band_%s" % bone, a, b, 0.07, 0.06, tint, 10))
        put("gloves", bone, ck.tube(P + "gloves_rim_%s" % bone, b, b + (b - a) * 0.2, 0.065, 0.065, tint2, 10))
    for sx, bone in ((1, "leg_fr"), (-1, "leg_fl")):
        hipp = V((sx * 0.09, 0.02, z - 0.16))
        put("boots", bone, ck.tube(P + "boots_band_%s" % bone, hipp + V((0, -0.02, -0.07)), hipp + V((0, -0.035, -0.13)), 0.05, 0.05, tint, 8))
    for (slot, bone), objs in groups.items():
        obj = ck._join(objs, "frm_%s_%s_%s" % (style, slot, bone))
        ck._smooth(obj.data)
        lp.attach(obj, arm, bone)


# ---------------------------------------------------------------------------
# Clipes: laços próprios do pássaro e os cinco gestos (mesmos nomes de druid_sets.FORM_CLIPS)
# Eixos do rig (build_monsters.combat_actions): corpo loc Y = cima, Z = frente; corpo/cabeça +X = inclina para a frente;
# braço -X = levanta para a frente; braço Z = abre para o lado (direito -, esquerdo +).
# ---------------------------------------------------------------------------
def bird_loops(lp, arm):
    """idle (paira batendo as asas devagar) e run (voo inclinado, batida funda) por cima dos laços genéricos."""
    z = (0, 0, 0)
    tau = math.tau
    for name, n, beats, lean, amp in (("idle", 24, 1, 0.0, 32.0), ("run", 16, 1, 22.0, 46.0)):
        old = __import__("bpy").data.actions.get(name)
        keys = {b: [] for b in ("body", "head", "arm_r", "arm_l", "tail", "leg_fr", "leg_fl")}
        for f in range(1, n + 1):
            ph = (f - 1) / (n - 1) * tau * beats
            s, c = math.sin(ph), math.cos(ph)
            keys["body"].append((f, (lean + 3 * c, 0, 0), (0, 0.07 * s, 0)))                     # sobe quando a asa desce
            keys["head"].append((f, (-lean * 0.7 - 3 * c, 0, 0), z))
            keys["arm_r"].append((f, (-6 + 8 * c, 0, -8 - amp * s), z))                          # batida: abre para cima / fecha para baixo
            keys["arm_l"].append((f, (-6 + 8 * c, 0, 8 + amp * s), z))
            keys["tail"].append((f, (-lean * 0.5 + 7 * math.sin(ph - 0.9), 0, 0), z))
            keys["leg_fr"].append((f, (30 + lean, 0, 0), z))
            keys["leg_fl"].append((f, (30 + lean, 0, 0), z))
        _replace(lp, arm, name, keys, n, True)


def _replace(lp, arm, name, keys, end, loop):
    """Troca a ação `name` (trilha NLA e Action) pela nova."""
    import bpy
    ad = arm.animation_data
    if ad:
        for tr in list(ad.nla_tracks):
            if tr.name == name:
                ad.nla_tracks.remove(tr)
    old = bpy.data.actions.get(name)
    if old:
        bpy.data.actions.remove(old)
    lp.add_action(arm, name, keys, end, loop=loop)


def clips(lp, arm, kind):
    z = (0, 0, 0)

    def r(x=0.0, y=0.0, zz=0.0):
        return (x, y, zz)

    def p(up=0.0, fwd=0.0):
        return (0, up, fwd)

    if kind == "ent":
        kl = 0.4          # pernas do ent: pivô longe da raiz, giro pequeno
        # golpe de galho: recolhe, levanta o braço direito bem alto e desce cruzando (impacto no 7)
        lp.add_action(arm, "maul", {
            "body": [(1, z, z), (3, r(-8, 0, -8), p(0.02, -0.05)), (5, r(-14, 0, -14), p(0.05, -0.08)), (7, r(20, 0, 12), p(-0.04, 0.16)), (10, r(16, 0, 10), p(-0.04, 0.14)),
                     (14, r(6, 0, 3), p(-0.01, 0.05)), (18, r(-2), p(0.01)), (20, z, z)],
            "head": [(1, z, z), (5, r(-12, 0, -8), z), (7, r(16, 0, 8), z), (10, r(12, 0, 4), z), (16, r(-3), z), (20, z, z)],
            "arm_r": [(1, z, z), (3, r(-70, 0, -20), z), (5, r(-165, 0, -24), z), (7, r(-38, 0, 22), z), (10, r(-30, 0, 20), z), (15, r(-8, 0, 4), z), (20, z, z)],
            "arm_l": [(1, z, z), (5, r(20, 0, 18), z), (7, r(-22, 0, 10), z), (12, r(-10, 0, 6), z), (20, z, z)],
            "leg_fr": [(1, z, z), (5, r(8 * kl), z), (7, r(-22 * kl), z), (14, r(-6 * kl), z), (20, z, z)],
            "leg_bl": [(1, z, z), (5, r(-6 * kl), z), (7, r(12 * kl), z), (20, z, z)]}, 20, loop=False)
        # marcha do ent: recua e avança de ombro, os dois braços na frente (impacto no 9)
        lp.add_action(arm, "pounce", {
            "body": [(1, z, z), (4, r(-10), p(0.0, -0.12)), (6, r(-12), p(-0.03, -0.16)), (9, r(26), p(0.03, 0.5)), (12, r(20), p(0.0, 0.42)), (16, r(8), p(0.0, 0.16)), (21, z, z)],
            "head": [(1, z, z), (6, r(-10), z), (9, r(18), z), (12, r(10), z), (21, z, z)],
            "arm_r": [(1, z, z), (6, r(30, 0, -14), z), (9, r(-95, 0, 14), z), (12, r(-85, 0, 12), z), (17, r(-20), z), (21, z, z)],
            "arm_l": [(1, z, z), (6, r(30, 0, 14), z), (9, r(-95, 0, -14), z), (12, r(-85, 0, -12), z), (17, r(-20), z), (21, z, z)],
            "leg_fr": [(1, z, z), (6, r(16 * kl), z), (9, r(-34 * kl), z), (14, r(-10 * kl), z), (21, z, z)],
            "leg_fl": [(1, z, z), (6, r(-10 * kl), z), (9, r(-26 * kl), z), (14, r(-8 * kl), z), (21, z, z)],
            "leg_br": [(1, z, z), (6, r(-12 * kl), z), (9, r(26 * kl), z), (21, z, z)],
            "leg_bl": [(1, z, z), (6, r(-12 * kl), z), (9, r(22 * kl), z), (21, z, z)]}, 21, loop=False)
        # tremor de raízes: os dois braços sobem acima da copa e desabam no chão, o tronco afunda e quica (impacto no 8)
        lp.add_action(arm, "slam", {
            "body": [(1, z, z), (3, r(4), p(-0.03)), (5, r(-18), p(0.1, -0.06)), (6, r(-20), p(0.11, -0.06)), (8, r(28), p(-0.12, 0.14)), (10, r(24), p(-0.1, 0.12)),
                     (13, r(14), p(-0.05, 0.06)), (17, r(3), p(0.02)), (20, r(-2), p(0.01)), (23, z, z)],
            "head": [(1, z, z), (5, r(-20), z), (8, r(20), z), (11, r(12, 0, 5), z), (15, r(4, 0, -4), z), (23, z, z)],
            "arm_r": [(1, z, z), (3, r(-40, 0, -16), z), (5, r(-172, 0, -18), z), (6, r(-176, 0, -16), z), (8, r(-48, 0, 6), z), (11, r(-44, 0, 6), z), (17, r(-12), z), (23, z, z)],
            "arm_l": [(1, z, z), (3, r(-40, 0, 16), z), (5, r(-172, 0, 18), z), (6, r(-176, 0, 16), z), (8, r(-48, 0, -6), z), (11, r(-44, 0, -6), z), (17, r(-12), z), (23, z, z)],
            "leg_fr": [(1, z, z), (5, r(10 * kl, 0, 0), z), (8, r(-20 * kl, 0, 14), z), (14, r(-8 * kl, 0, 8), z), (23, z, z)],
            "leg_fl": [(1, z, z), (5, r(10 * kl, 0, 0), z), (8, r(-20 * kl, 0, -14), z), (14, r(-8 * kl, 0, -8), z), (23, z, z)],
            "leg_br": [(1, z, z), (5, r(-8 * kl), z), (8, r(14 * kl, 0, 10), z), (23, z, z)],
            "leg_bl": [(1, z, z), (5, r(-8 * kl), z), (8, r(14 * kl, 0, -10), z), (23, z, z)]}, 23, loop=False)
        # chamado: recolhe e abre os braços para o alto, a copa treme (impacto no 7; gritos, buffs e invocações)
        lp.add_action(arm, "roar", {
            "body": [(1, z, z), (4, r(10), p(-0.05)), (7, r(-14), p(0.06)), (9, r(-13, 0, 3), p(0.06)), (11, r(-14, 0, -3), p(0.06)), (13, r(-13, 0, 2), p(0.05)),
                     (17, r(3), p(-0.01)), (22, z, z)],
            "head": [(1, z, z), (4, r(14), z), (7, r(-24, 0, 7), z), (9, r(-22, 0, -7), z), (11, r(-24, 0, 7), z), (13, r(-20, 0, -4), z), (18, r(4), z), (22, z, z)],
            "arm_r": [(1, z, z), (4, r(-20, 0, 14), z), (7, r(-120, 0, -58), z), (9, r(-126, 0, -54), z), (11, r(-120, 0, -58), z), (13, r(-116, 0, -52), z), (18, r(-14, 0, -6), z), (22, z, z)],
            "arm_l": [(1, z, z), (4, r(-20, 0, -14), z), (7, r(-120, 0, 58), z), (9, r(-126, 0, 54), z), (11, r(-120, 0, 58), z), (13, r(-116, 0, 52), z), (18, r(-14, 0, 6), z), (22, z, z)],
            "leg_fr": [(1, z, z), (7, r(0, 0, 10), z), (13, r(0, 0, 10), z), (22, z, z)],
            "leg_fl": [(1, z, z), (7, r(0, 0, -10), z), (13, r(0, 0, -10), z), (22, z, z)]}, 22, loop=False)
        # casca: crava as raízes abertas, abaixa e cruza os braços na frente (impacto no 6; buffs de defesa)
        lp.add_action(arm, "brace", {
            "body": [(1, z, z), (3, r(-5), p(0.03)), (6, r(10), p(-0.12)), (9, r(8), p(-0.1)), (12, r(10), p(-0.12)), (16, r(-2), p(0.01)), (19, z, z)],
            "head": [(1, z, z), (3, r(-8), z), (6, r(14), z), (12, r(12), z), (19, z, z)],
            "arm_r": [(1, z, z), (3, r(-30, 0, -20), z), (6, r(-78, 0, 34), z), (12, r(-76, 0, 32), z), (16, r(-16, 0, 6), z), (19, z, z)],
            "arm_l": [(1, z, z), (3, r(-30, 0, 20), z), (6, r(-78, 0, -34), z), (12, r(-76, 0, -32), z), (16, r(-16, 0, -6), z), (19, z, z)],
            "leg_fr": [(1, z, z), (6, r(-10 * kl, 0, 16), z), (12, r(-10 * kl, 0, 16), z), (19, z, z)],
            "leg_fl": [(1, z, z), (6, r(-10 * kl, 0, -16), z), (12, r(-10 * kl, 0, -16), z), (19, z, z)],
            "leg_br": [(1, z, z), (6, r(10 * kl, 0, 14), z), (12, r(10 * kl, 0, 14), z), (19, z, z)],
            "leg_bl": [(1, z, z), (6, r(10 * kl, 0, -14), z), (12, r(10 * kl, 0, -14), z), (19, z, z)]}, 19, loop=False)
        return
    # ---- pássaro: as asas são os braços (Z abre/fecha; X leva para a frente) ----
    up, down = 58.0, 34.0
    # pena cortante: recolhe a asa direita atrás e corta para a frente, o corpo gira junto (impacto no 7)
    lp.add_action(arm, "maul", {
        "body": [(1, z, z), (3, r(-10, 0, -10), p(0.06, -0.06)), (5, r(-14, 0, -16), p(0.1, -0.1)), (7, r(18, 0, 14), p(-0.02, 0.2)), (10, r(12, 0, 8), p(0.0, 0.14)),
                 (14, r(3), p(0.03, 0.03)), (18, z, z)],
        "head": [(1, z, z), (5, r(-8, 0, 12), z), (7, r(12, 0, -10), z), (12, r(4), z), (18, z, z)],
        "arm_r": [(1, z, z), (3, r(20, 0, -up * 0.7), z), (5, r(34, 0, -up), z), (7, r(-70, 0, 12), z), (10, r(-58, 0, 10), z), (14, r(-10, 0, -14), z), (18, z, z)],
        "arm_l": [(1, z, z), (5, r(10, 0, up * 0.5), z), (7, r(16, 0, down * 0.6), z), (12, r(0, 0, 14), z), (18, z, z)],
        "tail": [(1, z, z), (5, r(14), z), (7, r(-18), z), (12, r(-6), z), (18, z, z)]}, 18, loop=False)
    # mergulho: sobe, fecha as asas e mergulha de bico, abre e freia (impacto no 9)
    lp.add_action(arm, "pounce", {
        "body": [(1, z, z), (4, r(-16), p(0.16, -0.1)), (6, r(-10), p(0.26, -0.08)), (9, r(46), p(-0.26, 0.5)), (11, r(34), p(-0.22, 0.44)), (14, r(-8), p(0.02, 0.18)),
                 (18, r(-3), p(0.04, 0.04)), (21, z, z)],
        "head": [(1, z, z), (6, r(10), z), (9, r(-26), z), (11, r(-18), z), (15, r(4), z), (21, z, z)],
        "arm_r": [(1, z, z), (4, r(0, 0, -up), z), (6, r(4, 0, -up * 0.9), z), (9, r(30, 0, down + 8), z), (11, r(26, 0, down), z), (14, r(-14, 0, -up * 0.8), z), (18, r(-4, 0, -12), z), (21, z, z)],
        "arm_l": [(1, z, z), (4, r(0, 0, up), z), (6, r(4, 0, up * 0.9), z), (9, r(30, 0, -down - 8), z), (11, r(26, 0, -down), z), (14, r(-14, 0, up * 0.8), z), (18, r(-4, 0, 12), z), (21, z, z)],
        "tail": [(1, z, z), (6, r(18), z), (9, r(-30), z), (14, r(16), z), (21, z, z)]}, 21, loop=False)
    # tempestade: sobe com as asas no alto e bate as duas para baixo de uma vez (impacto no 8; magia no chão)
    lp.add_action(arm, "slam", {
        "body": [(1, z, z), (3, r(4), p(-0.04)), (5, r(-18), p(0.24, -0.04)), (6, r(-20), p(0.27, -0.04)), (8, r(16), p(-0.1, 0.06)), (10, r(12), p(-0.07, 0.05)),
                 (13, r(4), p(0.03, 0.02)), (16, r(-2), p(0.02)), (18, z, z)],
        "head": [(1, z, z), (5, r(-16), z), (8, r(18), z), (12, r(6), z), (18, z, z)],
        "arm_r": [(1, z, z), (3, r(-6, 0, down * 0.6), z), (5, r(-16, 0, -up - 14), z), (6, r(-18, 0, -up - 18), z), (8, r(-30, 0, down + 12), z), (10, r(-26, 0, down + 6), z), (14, r(-6, 0, -18), z), (18, z, z)],
        "arm_l": [(1, z, z), (3, r(-6, 0, -down * 0.6), z), (5, r(-16, 0, up + 14), z), (6, r(-18, 0, up + 18), z), (8, r(-30, 0, -down - 12), z), (10, r(-26, 0, -down - 6), z), (14, r(-6, 0, 18), z), (18, z, z)],
        "tail": [(1, z, z), (5, r(-20), z), (8, r(24), z), (13, r(6), z), (18, z, z)]}, 18, loop=False)
    # canto arcano: abre as asas inteiras, peito para cima, as pontas tremem (impacto no 7; raios, curas e buffs; curto depois do impacto: invocação tem recuperação curta)
    lp.add_action(arm, "roar", {
        "body": [(1, z, z), (4, r(8), p(-0.05)), (7, r(-22), p(0.14)), (9, r(-20, 0, 3), p(0.15)), (11, r(-22, 0, -3), p(0.14)), (13, r(-20), p(0.13)), (15, r(2), p(0.02)), (17, z, z)],
        "head": [(1, z, z), (4, r(12), z), (7, r(-20), z), (9, r(-18, 0, 6), z), (11, r(-20, 0, -6), z), (13, r(-16), z), (17, z, z)],
        "arm_r": [(1, z, z), (4, r(6, 0, down * 0.7), z), (7, r(-22, 0, -up), z), (9, r(-24, 0, -up + 9), z), (11, r(-22, 0, -up), z), (13, r(-24, 0, -up + 9), z), (15, r(-6, 0, -14), z), (17, z, z)],
        "arm_l": [(1, z, z), (4, r(6, 0, -down * 0.7), z), (7, r(-22, 0, up), z), (9, r(-24, 0, up - 9), z), (11, r(-22, 0, up), z), (13, r(-24, 0, up - 9), z), (15, r(-6, 0, 14), z), (17, z, z)],
        "tail": [(1, z, z), (7, r(-26), z), (10, r(-22), z), (13, r(-26), z), (17, z, z)]}, 17, loop=False)
    # resguardo: fecha as asas em volta do corpo e encolhe (impacto no 6; buffs de defesa)
    lp.add_action(arm, "brace", {
        "body": [(1, z, z), (3, r(-6), p(0.05)), (6, r(12), p(-0.08)), (10, r(10), p(-0.06)), (13, r(12), p(-0.08)), (16, r(-2), p(0.02)), (18, z, z)],
        "head": [(1, z, z), (6, r(16), z), (13, r(14), z), (18, z, z)],
        "arm_r": [(1, z, z), (3, r(0, 0, -up * 0.6), z), (6, r(-46, 0, down + 20), z), (13, r(-44, 0, down + 18), z), (16, r(-8, 0, -10), z), (18, z, z)],
        "arm_l": [(1, z, z), (3, r(0, 0, up * 0.6), z), (6, r(-46, 0, -down - 20), z), (13, r(-44, 0, -down - 18), z), (16, r(-8, 0, 10), z), (18, z, z)],
        "tail": [(1, z, z), (6, r(20), z), (13, r(18), z), (18, z, z)]}, 18, loop=False)


# ---------------------------------------------------------------------------
def build(out_dir, only=None):
    """form_ent.glb, form_alpha.glb e form_bird.glb com a armadura de cada conjunto da build."""
    import bpy
    import chibi_kit as ck
    import lowpoly_lib as lp
    import mob_kit as mk
    import build_monsters as bm
    import druid_sets as ds
    for kind in FORMS:
        if only and kind not in only:
            continue
        ck.clear()
        tint, tint2, saved = ds.form_tints(ck)          # base fixa (ver druid_sets.form_tints)
        if kind == "ent":
            arm = ent(ck, lp, mk, bm)
        elif kind == "alpha":
            arm = alpha(ck, lp, mk)
        else:
            arm = bird(ck, lp, mk, bm)
        for style, cfg in ds.DRU_SETS.items():
            if not style.startswith(PREFIX[kind]):
                continue
            if kind == "ent":
                ent_armor(ck, lp, ds, arm, style, cfg, tint, tint2)
            elif kind == "alpha":
                ds.form_armor(ck, lp, arm, "wolf", style, cfg, tint, tint2)
            else:
                bird_armor(ck, lp, ds, arm, style, cfg, tint, tint2)
        if kind == "alpha":
            ds.form_clips(lp, arm, "wolf")
        else:
            if kind == "bird":
                bird_loops(lp, arm)
            clips(lp, arm, kind)
        bpy.ops.object.mode_set(mode="OBJECT")
        for o in bpy.context.scene.objects:
            if "." in o.name:
                o.name = o.name.replace(".", "_")
        lp.export_glb(os.path.join(out_dir, "form_%s.glb" % kind), [arm])
        ds.restore_tints(saved)
    print("ancestral forms done")
