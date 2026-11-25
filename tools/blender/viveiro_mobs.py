"""Viveiro de Seiva (dg_viveiro, 17-19; contrato production/session-state/viveiro-contract.md, GDD brejo-das-teias 3.9):

  mob_sap_sprout   Muda de Seiva (também a Muda Desperta `sap_hatchling`): arvorezinha andante de ~1,5 m no modelo. Pernas
                   de raiz, tronco bojudo rachado com a seiva acesa no peito (osso `core`), cabeça-bulbo de olhos âmbar com
                   duas folhas grandes e o broto aceso no topo, braços de graveto. Clipes: idle run attack cast hit die.
  mob_sap_tank     Tanque de Seiva (parado; "ovo" da Muda-Mãe): soco de pedra élfica, montantes de bronze, coluna de seiva
                   acesa (osso `core`), vidro em 4 quadrantes (`leg_fr` frente, `leg_br` trás, `arm_r` +X, `arm_l` -X), aro
                   de cima (`head`) e a muda que sai pela boca aberta (`body`). O material do jogo não tem transparência:
                   o vidro são faixas e reflexos claros POR FORA da seiva. Clipes: idle run attack cast hit die; no `die`
                   os quadrantes de vidro tombam para fora, a seiva escorre e some, o aro cai e a muda murcha.
  mob_sap_mother   A Muda-Mãe (chefe; escala 2,0 no jogo): muda grande da Árvore-Mãe enraizada num tanque partido (soco,
                   cacos e montantes tortos no osso `root`), tronco trançado com o oco de seiva acesa no peito (`core`),
                   cabeça-bulbo com coroa de folhas e o broto aceso, dois braços de raiz com garra (`arm_r` +X, `arm_l`)
                   e dois feixes de raiz na frente (`leg_r`, `leg_l`) que se arrastam. ~2,6 m no modelo.
                   Clipes: idle run attack cast cast_ground summon shout atk_sweep hit die + maul pounce slam roar brace.

Peças rígidas, uma malha por osso (lp.export_glb). Todos os ossos ficam de pé (x = X, y = para cima, z = -Y, a frente):
rot x positivo = inclina para a frente, y = gira, z positivo = tomba para -X; loc = (x, cima, frente). Todo clipe grava
TODOS os ossos com rot/loc/escala (lumeria_bosses._sclip): osso sem chave herdava a pose do clipe anterior no Godot.
Impactos = EntityView.IMPACT_FRAME (attack 5, cast 10, cast_ground 10, summon 11, shout 7, atk_sweep 8, maul 7, pounce 9,
slam 8, roar 7, brace 6).

    mob_kit.build_all(out, only=set(viveiro_mobs.BUILDERS))
    blender -b --factory-startup --python tools/blender/lumeria_mobs_preview.py -- --module=viveiro_mobs --out=<pasta absoluta>
        [--only=mob_sap_tank] [--poses=idle:1,die:24] [--ground] [--export=<abs assets/models>]
"""
import math

import bmesh
from mathutils import Vector

import chibi_kit as ck
import mob_kit as mk
import lumeria_bosses as lb

V = Vector
Z0, ONE = (0, 0, 0), (1, 1, 1)
SAP = (0.98, 0.74, 0.26)           # seiva acesa (âmbar; nunca vermelha)
SAP_L = (1.0, 0.88, 0.5)
BARK = (0.46, 0.34, 0.21)
BARK_D = (0.3, 0.21, 0.14)
BARK_L = (0.62, 0.5, 0.31)
BULB = (0.6, 0.62, 0.36)           # madeira verde da cabeça-bulbo
LEAF = (0.42, 0.64, 0.3)
LEAF_L = (0.68, 0.82, 0.38)
LEAF_G = (0.86, 0.8, 0.36)         # folha dourada da Árvore-Mãe
STONE = (0.5, 0.52, 0.48)
STONE_D = (0.36, 0.38, 0.35)
BRONZE = (0.62, 0.5, 0.3)
GLASS = (0.78, 0.9, 0.84)
INK = (0.1, 0.07, 0.05)

r = lb.r
_Parts, _vine, _hoop, _leaf, _flat, _sclip, _sc, _retime, _loop = lb._Parts, lb._vine, lb._hoop, lb._leaf, lb._flat, lb._sclip, lb._sc, lb._retime, lb._loop
s, c = math.sin, math.cos


def _mats(cid):
    m = lambda n, col, rough=0.85, em=0.0: ck.mat("m_%s_%s" % (cid, n), col, rough, em)
    return {"bark": m("bark", BARK), "bark_d": m("bark_d", BARK_D), "bark_l": m("bark_l", BARK_L), "bulb": m("bulb", BULB, 0.7),
            "leaf": m("leaf", LEAF, 0.8), "leaf_l": m("leaf_l", LEAF_L, 0.8), "leaf_g": m("leaf_g", LEAF_G, 0.7),
            "stone": m("stone", STONE, 0.9), "stone_d": m("stone_d", STONE_D, 0.9), "bronze": m("bronze", BRONZE, 0.45),
            "glass": m("glass", GLASS, 0.15), "ink": m("ink", INK, 0.6),
            "glow": m("glow_sap", SAP, 0.3, 2.0), "glow_l": m("glow_sap_l", SAP_L, 0.3, 2.4)}


def _pane(name, a0, a1, rad, z0, z1, thick, material, segs=4, jag=None):
    """Quadrante de parede de cilindro (casca fechada, com espessura). jag = altura extra por coluna (borda partida)."""
    bm_ = bmesh.new()
    cols = []
    for i in range(segs + 1):
        a = a0 + (a1 - a0) * i / segs
        top = z1 + (jag[i % len(jag)] if jag else 0.0)
        cols.append([bm_.verts.new((c(a) * rr, s(a) * rr, zz)) for rr in (rad, rad - thick) for zz in (z0, top)])      # o0 o1 i0 i1
    for i in range(segs):
        a_, b_ = cols[i], cols[i + 1]
        bm_.faces.new((a_[0], b_[0], b_[1], a_[1]))
        bm_.faces.new((b_[2], a_[2], a_[3], b_[3]))
        bm_.faces.new((a_[1], b_[1], b_[3], a_[3]))
        bm_.faces.new((b_[0], a_[0], a_[2], b_[2]))
    bm_.faces.new((cols[0][0], cols[0][1], cols[0][3], cols[0][2]))
    bm_.faces.new((cols[-1][1], cols[-1][0], cols[-1][2], cols[-1][3]))
    bmesh.ops.recalc_face_normals(bm_, faces=bm_.faces[:])
    return _flat(ck.mesh_from(name, bm_, material))


def _arm(side, fwd=0.0, up=0.0, yaw=0.0):
    """Rotação de um osso de braço de pé no ombro: fwd = ponta para a frente, up = abre/ergue para o lado dele."""
    return (-fwd, side * yaw, side * up)


def _both(seq, fn=None):
    """seq = [(quadro, fwd, up[, yaw])] -> chaves dos dois braços."""
    return {"arm_r": [(k[0], _arm(1, *k[1:]), Z0) for k in seq], "arm_l": [(k[0], _arm(-1, *k[1:]), Z0) for k in seq]}


# ---------------------------------------------------------------------------
# Muda de Seiva
# ---------------------------------------------------------------------------
SPROUT_BONES = {
    "root": ((0, 0, 0), (0, 0, 0.2), None),
    "body": ((0, 0, 0.3), (0, 0, 0.55), "root"),
    "head": ((0, 0, 0.74), (0, 0, 0.98), "body"),
    "core": ((0, -0.2, 0.5), (0, -0.2, 0.62), "body"),
    "arm_r": ((0.26, 0, 0.64), (0.26, 0, 0.82), "body"),
    "arm_l": ((-0.26, 0, 0.64), (-0.26, 0, 0.82), "body"),
    "leg_r": ((0.16, 0, 0.32), (0.16, 0, 0.5), "root"),
    "leg_l": ((-0.16, 0, 0.32), (-0.16, 0, 0.5), "root"),
}


def sap_sprout(cid="mob_sap_sprout"):
    arm = mk.lp.make_armature("rig_" + cid, SPROUT_BONES)
    M = _mats(cid)
    P = _Parts()
    for bone, sx in (("leg_r", 1), ("leg_l", -1)):
        P.add(bone, _vine("leg%d" % sx, [(sx * 0.15, 0, 0.36), (sx * 0.19, -0.01, 0.2), (sx * 0.2, -0.03, 0.07)], 0.115, 0.09, M["bark_d"], 6, 2),
              mk.blob("foot%d" % sx, 1.0, (sx * 0.21, -0.09, 0.065), M["bark_d"], (0.125, 0.2, 0.065), 2))
        for k, (dx, dy) in enumerate(((0.1, -0.2), (-0.04, -0.26), (0.13, 0.08))):
            P.add(bone, mk.cone("toe%d_%d" % (sx, k), (sx * 0.21, -0.09, 0.05), (sx * (0.21 + dx), -0.09 + dy, 0.02), 0.045, M["bark"], 5))
    P.add("body", mk.blob("trunk", 1.0, (0, 0, 0.5), M["bark"], (0.28, 0.25, 0.27), 2),
          mk.blob("hip", 1.0, (0, 0.01, 0.34), M["bark_d"], (0.24, 0.21, 0.12), 2),
          ck.ball("crack", 1.0, (0, -0.215, 0.5), M["ink"], (0.11, 0.05, 0.16)))
    for k, a in enumerate((0.5, 2.1, 3.6, 5.2)):               # gola de folhas (o que a câmera alta vê entre cabeça e tronco)
        o = V((c(a), s(a), 0))
        P.add("body", _flat(_leaf("collar%d" % k, o * 0.12 + V((0, 0, 0.72)), o * 0.42 + V((0, 0, 0.64)), 0.24, M["leaf"] if k % 2 else M["leaf_l"])))
    P.add("core", ck.ball("sap", 1.0, (0, -0.235, 0.5), M["glow"], (0.07, 0.04, 0.12)))
    hc = V((0, -0.02, 1.02))
    P.add("head", mk.blob("bulb", 1.0, hc, M["bulb"], (0.35, 0.33, 0.31), 2),
          mk.blob("bulb_tip", 1.0, hc + V((0, 0, 0.26)), M["bulb"], (0.17, 0.17, 0.14), 2),
          ck.ball("mouth", 1.0, hc + V((0, -0.315, -0.11)), M["ink"], (0.09, 0.03, 0.035)))
    for sx in (1, -1):
        P.add("head", ck.ball("eye%d" % sx, 1.0, hc + V((sx * 0.14, -0.29, 0.03)), M["glow_l"], (0.07, 0.04, 0.085)),
              ck.ball("brow%d" % sx, 1.0, hc + V((sx * 0.15, -0.29, 0.13)), M["bark_d"], (0.1, 0.04, 0.03)),
              _flat(_leaf("top_leaf%d" % sx, hc + V((sx * 0.03, 0, 0.36)), hc + V((sx * 0.46, -0.04, 0.5)), 0.3, M["leaf_l"] if sx > 0 else M["leaf"])))
    P.add("head", _vine("stem", [hc + V((0, 0, 0.3)), hc + V((0.02, 0, 0.42)), hc + V((0.05, -0.02, 0.52))], 0.045, 0.03, M["leaf"], 5, 2),
          ck.ball("bud", 0.075, hc + V((0.06, -0.03, 0.57)), M["glow"], (1, 1, 1.3)))
    for bone, sx in (("arm_r", 1), ("arm_l", -1)):
        P.add(bone, _vine("twig%d" % sx, [(sx * 0.24, 0, 0.64), (sx * 0.42, -0.02, 0.6), (sx * 0.5, -0.07, 0.44), (sx * 0.49, -0.12, 0.33)], 0.07, 0.05, M["bark_l"], 6, 2))
        hand = V((sx * 0.49, -0.12, 0.33))
        for k, d in enumerate(((sx * 0.08, -0.08, -0.14), (-sx * 0.03, -0.13, -0.12), (sx * 0.02, 0.05, -0.15))):
            P.add(bone, mk.cone("claw%d_%d" % (sx, k), hand, hand + V(d), 0.04, M["bark_d"], 5))
        P.add(bone, _flat(_leaf("arm_leaf%d" % sx, (sx * 0.42, 0, 0.62), (sx * 0.66, 0.04, 0.74), 0.16, M["leaf"])))
    P.finish(arm, cid)

    pulse = lambda amp=0.16: [(f, Z0, Z0, (1 + amp * s((f - 1) / 47 * math.tau * 2),) * 3) for f in list(range(1, 48, 4)) + [48]]
    _sclip(arm, "idle", 48, {
        "body": _loop(48, 4, lambda ph: (r(2 * s(ph), 0, 2.5 * s(ph + 0.6)), (0, 0.012 * s(2 * ph), 0))),
        "head": _loop(48, 4, lambda ph: (r(4 * s(ph + 0.9), 7 * s(ph + 1.4), 3 * s(ph)), Z0)),
        "arm_r": _loop(48, 4, lambda ph: (_arm(1, 6 * s(ph + 1.0), 5 + 4 * s(ph)), Z0)),
        "arm_l": _loop(48, 4, lambda ph: (_arm(-1, 6 * s(ph + 2.0), 5 + 4 * s(ph + 0.8)), Z0)),
        "core": pulse()}, loop=True)
    _sclip(arm, "run", 16, {
        "body": _loop(16, 1, lambda ph: (r(9 + 3 * s(2 * ph), 5 * s(ph), 5 * c(ph)), (0, 0.035 * abs(s(ph)), 0))),
        "head": _loop(16, 1, lambda ph: (r(5 * c(2 * ph), -6 * s(ph), -4 * c(ph)), Z0)),
        "leg_r": _loop(16, 1, lambda ph: (r(-28 * s(ph)), (0, 0.13 * abs(s(ph)) + 0.05 * max(0.0, c(ph)), 0))),      # o pé gira em volta da anca: sobe o que a ponta desceria
        "leg_l": _loop(16, 1, lambda ph: (r(28 * s(ph)), (0, 0.13 * abs(s(ph)) + 0.05 * max(0.0, -c(ph)), 0))),
        "arm_r": _loop(16, 1, lambda ph: (_arm(1, -34 * s(ph), 14), Z0)),
        "arm_l": _loop(16, 1, lambda ph: (_arm(-1, 34 * s(ph), 14), Z0))}, loop=True)
    # attack (5): recua, ergue o braço direito e chicoteia de cima com uma cabeçada
    _sclip(arm, "attack", 15, {
        "body": [(3, r(-14, -14, 0), (0, -0.02, 0)), (5, r(24, 16, 0), (0, 0.0, 0.1)), (7, r(20, 12, 0), (0, 0, 0.08)), (11, r(6), Z0)],
        "head": [(3, r(-16), Z0), (5, r(20), Z0), (8, r(12), Z0), (12, r(2), Z0)],
        "arm_r": [(3, _arm(1, -40, 110), Z0), (5, _arm(1, 85, 30), Z0), (7, _arm(1, 78, 24), Z0), (11, _arm(1, 20, 8), Z0)],
        "arm_l": [(3, _arm(-1, -20, 30), Z0), (5, _arm(-1, 20, 20), Z0), (11, _arm(-1, 4, 6), Z0)],
        "leg_r": [(5, r(-16), (0, 0.06, 0)), (9, r(-8), (0, 0.03, 0))], "leg_l": [(5, r(12), (0, 0.06, 0)), (9, r(6), (0, 0.03, 0))],
        "core": _sc([(3, 0.8), (5, 1.35), (9, 1.1), (13, 1.0)])})
    # cast (10): encolhe, estica com os braços para o alto e a seiva do peito acende
    _sclip(arm, "cast", 20, {
        "body": [(5, r(12), (0, -0.07, 0), (1.06, 0.9, 1.06)), (10, r(-10), (0, 0.06, 0), (0.95, 1.1, 0.95)), (13, r(-6), (0, 0.03, 0), ONE), (18, r(0), Z0, ONE)],
        "head": [(5, r(14), Z0), (10, r(-22), Z0), (14, r(-8), Z0)],
        "arm_r": [(5, _arm(1, 30, -6), Z0), (10, _arm(1, -10, 150), Z0), (13, _arm(1, -6, 135), Z0), (18, _arm(1, 0, 10), Z0)],
        "arm_l": [(5, _arm(-1, 30, -6), Z0), (10, _arm(-1, -10, 150), Z0), (13, _arm(-1, -6, 135), Z0), (18, _arm(-1, 0, 10), Z0)],
        "core": _sc([(5, 0.7), (10, 1.6), (14, 1.3), (19, 1.0)])})
    _sclip(arm, "hit", 10, {
        "body": [(2, r(-16, 0, 7), (0, 0, -0.05)), (5, r(6, 0, -3), Z0)], "head": [(2, r(-22, 0, 10), Z0), (5, r(8, 0, -5), Z0)],
        "arm_r": [(2, _arm(1, -30, 40), Z0), (6, _arm(1, 6, 6), Z0)], "arm_l": [(2, _arm(-1, -30, 40), Z0), (6, _arm(-1, 6, 6), Z0)],
        "core": _sc([(2, 0.4), (6, 1.0)])})
    # die: cambaleia e cai de costas; as folhas murcham e a seiva apaga
    _sclip(arm, "die", 24, {
        "root": [(4, r(8), Z0), (9, r(-24), (0, 0.04, -0.05)), (14, r(-82), (0, 0.27, -0.12)), (16, r(-76), (0, 0.27, -0.12)), (18, r(-82), (0, 0.27, -0.12))],
        "body": [(4, r(10), Z0), (9, r(-10), Z0), (14, r(-4), Z0)],
        "head": [(4, r(14), Z0), (9, r(-20), Z0), (14, r(10, 0, 14), Z0), (18, r(6, 0, 12), Z0)],
        "arm_r": [(4, _arm(1, 30, 20), Z0), (9, _arm(1, -30, 80), Z0), (14, _arm(1, -10, 60), Z0), (18, _arm(1, -6, 50), Z0)],
        "arm_l": [(4, _arm(-1, 30, 20), Z0), (9, _arm(-1, -40, 70), Z0), (14, _arm(-1, -14, 66), Z0), (18, _arm(-1, -10, 56), Z0)],
        "leg_r": [(4, r(0), (0, 0.06, 0)), (9, r(-30), (0, 0.1, 0)), (14, r(16), Z0), (18, r(10), Z0)], "leg_l": [(4, r(0), (0, 0.06, 0)), (9, r(10), (0, 0.06, 0)), (14, r(-12), Z0), (18, r(-6), Z0)],
        "core": _sc([(4, 1.4), (9, 0.7), (13, 1.2), (19, 0.001)])})
    return arm


# ---------------------------------------------------------------------------
# Tanque de Seiva (parado)
# ---------------------------------------------------------------------------
TANK_R = 0.44
TANK_BONES = {
    "root": ((0, 0, 0), (0, 0, 0.2), None),                          # soco, montantes, raízes de fora
    "core": ((0, 0, 0.38), (0, 0, 0.6), "root"),                      # coluna de seiva (escala y = nível)
    "body": ((0, 0, 0.9), (0, 0, 1.15), "root"),                      # a muda
    "head": ((0, 0, 1.56), (0, 0, 1.76), "root"),                     # aro de cima
    "leg_fr": ((0, -TANK_R, 0.38), (0, -TANK_R, 0.6), "root"),        # vidro da frente
    "leg_br": ((0, TANK_R, 0.38), (0, TANK_R, 0.6), "root"),          # vidro de trás
    "arm_r": ((TANK_R, 0, 0.38), (TANK_R, 0, 0.6), "root"),           # vidro +X
    "arm_l": ((-TANK_R, 0, 0.38), (-TANK_R, 0, 0.6), "root"),         # vidro -X
}
TANK_PANES = (("leg_fr", -90.0), ("arm_r", 0.0), ("leg_br", 90.0), ("arm_l", 180.0))


def sap_tank(cid="mob_sap_tank"):
    arm = mk.lp.make_armature("rig_" + cid, TANK_BONES)
    M = _mats(cid)
    P = _Parts()
    R = TANK_R
    P.add("root", _flat(ck.tube("plinth", (0, 0, 0), (0, 0, 0.2), 0.64, 0.58, M["stone_d"], 8)), _flat(ck.tube("step", (0, 0, 0.2), (0, 0, 0.36), 0.52, 0.5, M["stone"], 8)),
          _hoop("foot_ring", (0, 0, 0.38), R + 0.04, 0.04, M["bronze"], 16))
    for k in range(4):
        a = math.radians(45 + 90 * k)
        P.add("root", ck.tube("post%d" % k, (c(a) * (R + 0.03), s(a) * (R + 0.03), 0.36), (c(a) * (R + 0.03), s(a) * (R + 0.03), 1.56), 0.04, 0.04, M["bronze"], 5))
    for k, a in enumerate((0.9, 3.4, 5.0)):                           # raízes que escaparam por baixo do soco
        dx, dy = c(a), s(a)
        P.add("root", _vine("root%d" % k, [(dx * 0.4, dy * 0.4, 0.3), (dx * 0.6, dy * 0.6, 0.24), (dx * 0.74, dy * 0.74, 0.09), (dx * 0.92, dy * 0.92, 0.04)], 0.075, 0.03, M["bark_d"], 5, 2))
    P.add("core", _flat(ck.tube("sap", (0, 0, 0.38), (0, 0, 1.18), R - 0.04, R - 0.04, M["glow"], 10)),
          ck.ball("sap_top", 1.0, (0, 0, 1.18), M["glow_l"], (R - 0.06, R - 0.06, 0.02)))
    for bone, deg in TANK_PANES:                                      # vidro: faixa de baixo, faixa de cima e um reflexo em pé
        a0, a1 = math.radians(deg - 43), math.radians(deg + 43)
        P.add(bone, _pane(bone + "_low", a0, a1, R, 0.4, 0.56, 0.025, M["glass"]), _pane(bone + "_high", a0, a1, R, 1.3, 1.54, 0.025, M["glass"]),
              _pane(bone + "_glint", math.radians(deg + 12), math.radians(deg + 22), R + 0.004, 0.56, 1.3, 0.02, M["glass"], 1),
              _pane(bone + "_glint2", math.radians(deg - 30), math.radians(deg - 26), R + 0.004, 0.7, 1.12, 0.02, M["glass"], 1))
    P.add("head", _hoop("top_ring", (0, 0, 1.56), R + 0.04, 0.045, M["bronze"], 16))
    # a muda: caule que sai da seiva pela boca aberta, quatro folhas e o broto aceso; a câmera alta vê tudo por cima
    P.add("body", _vine("stem", [(0, 0, 1.0), (0.04, -0.02, 1.3), (-0.03, 0.02, 1.6), (0.02, -0.02, 1.84)], 0.07, 0.04, M["leaf"], 6, 2))
    for k, (a, zz, L) in enumerate(((0.4, 1.5, 0.36), (2.5, 1.62, 0.34), (4.3, 1.74, 0.36), (5.6, 1.8, 0.3))):
        o = V((c(a), s(a), 0))
        P.add("body", _flat(_leaf("leaf%d" % k, o * 0.03 + V((0, 0, zz)), o * L + V((0, 0, zz + 0.14)), 0.24, M["leaf_l"] if k % 2 else M["leaf_g"])))
    P.add("body", ck.ball("bud", 0.085, (0.02, -0.02, 1.93), M["glow_l"], (1, 1, 1.35)))
    P.finish(arm, cid)

    lvl = lambda amp: [(f, Z0, Z0, (1.0, 1 + amp * s((f - 1) / 47 * math.tau * 2), 1.0)) for f in list(range(1, 48, 4)) + [48]]
    sway = lambda a: _loop(48, 4, lambda ph: (r(a * s(ph), 0, a * 0.7 * s(ph + 0.9)), Z0))
    _sclip(arm, "idle", 48, {"core": lvl(0.035), "body": sway(4.0)}, loop=True)
    _sclip(arm, "run", 16, {}, loop=True)
    bubble = {"core": [(5, Z0, Z0, (1.0, 0.94, 1.0)), (10, Z0, Z0, (1.0, 1.12, 1.0)), (14, Z0, Z0, (1.0, 1.04, 1.0)), (20, Z0, Z0, ONE)],
              "body": [(5, r(6), (0, -0.04, 0)), (10, r(-8), (0, 0.1, 0)), (14, r(-3), (0, 0.04, 0)), (20, Z0, Z0)],
              "head": [(10, Z0, (0, 0.03, 0)), (14, Z0, Z0)]}
    _sclip(arm, "cast", 22, bubble)
    _sclip(arm, "attack", 17, _retime(bubble, 10, 5))
    rattle = lambda sx, sz: [(2, r(4 * sx, 0, 4 * sz), Z0), (4, r(-3 * sx, 0, -3 * sz), Z0), (7, r(1 * sx, 0, 1 * sz), Z0)]
    _sclip(arm, "hit", 10, {"core": [(2, r(0, 0, 3), Z0, (1.03, 0.9, 1.03)), (5, r(0, 0, -2), Z0, (1.0, 1.06, 1.0)), (8, Z0, Z0, ONE)],
                            "body": [(2, r(-12, 0, 8), Z0), (5, r(8, 0, -5), Z0), (8, r(-2), Z0)],
                            "head": [(2, r(3, 0, 2), (0, 0.02, 0)), (5, r(-2, 0, -1), Z0)],
                            "leg_fr": rattle(1, 0), "leg_br": rattle(-1, 0), "arm_r": rattle(0, -1), "arm_l": rattle(0, 1)})
    # die: o vidro racha e os quatro quadrantes tombam para fora; a seiva escorre (alarga e baixa) e some; o aro cai torto
    # por cima do soco e a muda murcha para a frente
    fall = lambda rx, rz, t0: [(t0, r(3 * rx, 0, 3 * rz), Z0), (t0 + 4, r(48 * rx, 0, 48 * rz), (0, -0.06, 0)), (t0 + 8, r(97 * rx, 0, 97 * rz), (0, -0.2, 0)),
                               (t0 + 10, r(93 * rx, 0, 93 * rz), (0, -0.2, 0)), (t0 + 12, r(97 * rx, 0, 97 * rz), (0, -0.2, 0))]
    _sclip(arm, "die", 28, {
        "leg_fr": fall(1, 0, 3), "arm_r": fall(0, -1, 4), "leg_br": fall(-1, 0, 5), "arm_l": fall(0, 1, 4),
        "core": [(3, Z0, Z0, (1.04, 1.06, 1.04)), (7, Z0, Z0, (1.5, 0.5, 1.5)), (11, Z0, Z0, (1.85, 0.12, 1.85)), (16, Z0, Z0, (1.9, 0.03, 1.9)), (23, Z0, Z0, (0.001, 0.001, 0.001))],
        "head": [(4, r(0), (0, 0.03, 0)), (9, r(10, 0, 8), (0, -0.5, 0)), (13, r(22, 0, 14), (0, -1.0, -0.04)), (15, r(19, 0, 12), (0, -0.97, -0.04)), (17, r(22, 0, 14), (0, -1.0, -0.04))],
        "body": [(4, r(-8), Z0), (9, r(14, 0, 6), (0, -0.2, 0)), (15, r(58, 0, 16), (0, -0.52, 0)), (18, r(54, 0, 15), (0, -0.52, 0)), (21, r(58, 0, 16), (0, -0.52, 0))]})
    return arm


# ---------------------------------------------------------------------------
# A Muda-Mãe (chefe)
# ---------------------------------------------------------------------------
MOTHER_BONES = {
    "root": ((0, 0, 0), (0, 0, 0.2), None),                          # tanque partido + raízes de trás
    "body": ((0, 0.02, 0.5), (0, 0.02, 0.85), "root"),                # tronco
    "core": ((0, -0.25, 1.22), (0, -0.25, 1.4), "body"),              # seiva do peito
    "head": ((0, -0.06, 1.66), (0, -0.06, 1.9), "body"),
    "arm_r": ((0.44, 0, 1.5), (0.44, 0, 1.75), "body"),
    "arm_l": ((-0.44, 0, 1.5), (-0.44, 0, 1.75), "body"),
    "leg_r": ((0.42, -0.36, 0.4), (0.42, -0.36, 0.6), "root"),        # feixe de raízes da frente, +X
    "leg_l": ((-0.42, -0.36, 0.4), (-0.42, -0.36, 0.6), "root"),
}


def sap_mother(cid="mob_sap_mother"):
    arm = mk.lp.make_armature("rig_" + cid, MOTHER_BONES)
    M = _mats(cid)
    P = _Parts()
    # ---- o tanque partido: soco, aro, cacos, montantes tortos e a seiva que sobrou na bacia ----
    P.add("root", _flat(ck.tube("plinth", (0, 0, 0), (0, 0, 0.2), 0.82, 0.76, M["stone_d"], 8)), _flat(ck.tube("step", (0, 0, 0.2), (0, 0, 0.36), 0.68, 0.66, M["stone"], 8)),
          _hoop("foot_ring", (0, 0, 0.38), 0.63, 0.05, M["bronze"], 18),
          ck.ball("spill", 1.0, (0, 0, 0.37), M["glow"], (0.56, 0.56, 0.025)))
    jags = ((0.3, 0.52, 0.2, 0.44, 0.12), (0.16, 0.4, 0.62, 0.3, 0.2), (0.42, 0.18, 0.34, 0.56, 0.26))
    for k, (deg, span) in enumerate(((-150.0, 50.0), (20.0, 64.0), (118.0, 56.0))):
        P.add("root", _pane("shard%d" % k, math.radians(deg), math.radians(deg + span), 0.6, 0.38, 0.5, 0.03, M["glass"], 4, jags[k]))
    for k, (deg, lean) in enumerate(((45.0, 0.22), (135.0, 0.3), (-110.0, 0.12))):
        a = math.radians(deg)
        P.add("root", ck.tube("post%d" % k, (c(a) * 0.63, s(a) * 0.63, 0.36), (c(a) * (0.63 + lean), s(a) * (0.63 + lean), 1.0 - lean), 0.05, 0.045, M["bronze"], 5))
    for k, a in enumerate((0.5, 1.35, 2.1, 2.9)):                    # raízes de trás e dos lados: saem da bacia, passam o soco e fincam
        dx, dy = c(a), s(a)
        L = 1.25 + 0.2 * (k % 2)
        P.add("root", _vine("root%d" % k, [(dx * 0.25, dy * 0.25, 0.5), (dx * 0.6, dy * 0.6, 0.56), (dx * 0.86, dy * 0.86, 0.3), (dx * 1.05, dy * 1.05, 0.1), (dx * L, dy * L, 0.05)],
                            0.16, 0.05, M["bark_d"] if k % 2 else M["bark"], 6, 2))
    for bone, sx in (("leg_r", 1), ("leg_l", -1)):                    # feixes da frente (arrastam o tanque)
        for k, (a, L) in enumerate(((-0.6, 1.45), (-1.15, 1.3))):
            a = a if sx > 0 else math.pi - a
            dx, dy = c(a), s(a)
            P.add(bone, _vine("front%d_%d" % (sx, k), [(dx * 0.3, dy * 0.3, 0.52), (dx * 0.62, dy * 0.62, 0.6), (dx * 0.9, dy * 0.9, 0.32), (dx * 1.1, dy * 1.1, 0.11), (dx * L, dy * L, 0.06)],
                               0.17, 0.055, M["bark"] if k else M["bark_l"], 6, 2))
    # ---- tronco: duas hastes trançadas, veio de seiva, o oco do peito, ombros e a gola de folhas ----
    for k, ph in enumerate((0.0, math.pi)):
        pts = []
        for i in range(11):
            t = i / 10
            a = ph + t * math.tau * 1.1
            rad = 0.13 * (1 - 0.3 * t)
            pts.append((c(a) * rad, 0.02 - 0.06 * t * t + s(a) * rad, 0.4 + t * 1.2))
        P.add("body", _vine("stock%d" % k, pts, 0.25, 0.19, M["bark"] if k == 0 else M["bark_l"], 7, 2))
        P.add("body", _vine("vein%d" % k, [(q[0] * 1.9, q[1] * 1.9 - 0.02, q[2]) for q in pts[1:9]], 0.035, 0.02, M["glow"], 4, 2))
    P.add("body", mk.blob("chest", 1.0, (0, 0.0, 1.3), M["bark"], (0.36, 0.3, 0.34), 2),
          ck.ball("hollow", 1.0, (0, -0.25, 1.24), M["ink"], (0.17, 0.08, 0.22)),
          mk.blob("hump", 1.0, (0, 0.2, 1.42), M["bark_d"], (0.3, 0.22, 0.24), 2))
    for sx in (1, -1):
        P.add("body", mk.blob("shoulder%d" % sx, 1.0, (sx * 0.42, 0, 1.5), M["bark_d"], (0.2, 0.19, 0.18), 2))
    for k in range(6):
        a = math.tau * (k + 0.5) / 6
        o = V((c(a), s(a), 0))
        P.add("body", _flat(_leaf("collar%d" % k, o * 0.16 + V((0, -0.03, 1.62)), o * 0.62 + V((0, -0.03, 1.5)), 0.34, M["leaf"] if k % 2 else M["leaf_l"])))
    for k, (x, a) in enumerate(((0.16, 1.2), (-0.18, 1.9))):         # galhos novos nas costas
        tip = V((x + c(a) * 0.3, 0.3 + s(a) * 0.3, 1.86))
        P.add("body", _vine("twig%d" % k, [(x, 0.24, 1.46), (x * 1.3, 0.38, 1.68), tip], 0.05, 0.025, M["bark_l"], 5, 2),
              _flat(_leaf("twig_leaf%d" % k, tip, tip + V((c(a) * 0.3, 0.12, 0.14)), 0.2, M["leaf_g"])))
    P.add("core", ck.ball("heart", 1.0, (0, -0.27, 1.24), M["glow_l"], (0.115, 0.06, 0.16)))
    # ---- cabeça-bulbo: olhos e boca de seiva, coroa de folhas douradas e o broto aceso ----
    hc = V((0, -0.1, 1.96))
    P.add("head", mk.blob("bulb", 1.0, hc, M["bulb"], (0.37, 0.35, 0.36), 2), mk.blob("bulb_tip", 1.0, hc + V((0, 0.02, 0.3)), M["bulb"], (0.2, 0.2, 0.16), 2),
          ck.ball("mouth", 1.0, hc + V((0, -0.32, -0.15)), M["glow"], (0.13, 0.04, 0.045)),
          mk.blob("jaw", 1.0, hc + V((0, -0.2, -0.24)), M["bark"], (0.2, 0.16, 0.09), 1))
    for sx in (1, -1):
        P.add("head", ck.ball("eye%d" % sx, 1.0, hc + V((sx * 0.155, -0.305, 0.04)), M["glow_l"], (0.085, 0.04, 0.07)),
              ck.ball("brow%d" % sx, 1.0, hc + V((sx * 0.17, -0.3, 0.13)), M["bark_d"], (0.13, 0.05, 0.035)),
              mk.cone("horn%d" % sx, hc + V((sx * 0.26, 0.05, 0.2)), hc + V((sx * 0.52, 0.12, 0.5)), 0.07, M["bark_d"], 6))
    top = hc + V((0, 0.02, 0.38))
    for k in range(7):
        a = math.tau * (k + 0.5) / 7
        o = V((c(a), s(a), 0))
        P.add("head", _flat(_leaf("crown%d" % k, top + o * 0.06, top + o * 0.66 + V((0, 0, 0.1 + 0.12 * (k % 2))), 0.4, M["leaf_g"] if k % 2 else M["leaf_l"])))
    P.add("head", _vine("stem", [top, top + V((0.03, 0, 0.2)), top + V((0.0, -0.03, 0.38))], 0.06, 0.04, M["leaf"], 5, 2),
          ck.ball("bud", 0.12, top + V((0, -0.03, 0.47)), M["glow"], (1, 1, 1.3)))
    # ---- braços de raiz: sobem do ombro, dobram e descem até a garra ----
    for bone, sx in (("arm_r", 1), ("arm_l", -1)):
        pts = [(sx * 0.42, 0, 1.5), (sx * 0.8, 0.03, 1.74), (sx * 1.12, -0.06, 1.5), (sx * 1.24, -0.2, 1.05), (sx * 1.22, -0.3, 0.7)]
        P.add(bone, _vine("arm%d" % sx, pts, 0.2, 0.15, M["bark"] if sx > 0 else M["bark_l"], 7, 3),
              _vine("arm_vein%d" % sx, [(q[0] + sx * 0.02, q[1] - 0.17, q[2]) for q in pts[1:]], 0.035, 0.02, M["glow"], 4, 2))
        fist = V((sx * 1.22, -0.32, 0.58))
        P.add(bone, mk.blob("fist%d" % sx, 1.0, fist, M["bark_d"], (0.24, 0.24, 0.22), 2))
        for k, d in enumerate(((sx * 0.16, -0.2, -0.36), (-sx * 0.12, -0.26, -0.34), (sx * 0.02, 0.16, -0.38), (sx * 0.26, 0.04, -0.3))):
            P.add(bone, mk.cone("claw%d_%d" % (sx, k), fist + V(d) * 0.3, fist + V(d), 0.09, M["bark_l"], 5))
        el = V((sx * 0.86, 0.03, 1.78))
        for k, d in enumerate(((sx * 0.3, 0.1, 0.2), (0.0, 0.26, 0.16))):
            P.add(bone, _flat(_leaf("arm_leaf%d_%d" % (sx, k), el, el + V(d), 0.22, M["leaf"] if k else M["leaf_g"])))
    P.finish(arm, cid)

    pulse = lambda amp=0.14: [(f, Z0, Z0, (1 + amp * s((f - 1) / 47 * math.tau * 2),) * 3) for f in list(range(1, 48, 4)) + [48]]
    _sclip(arm, "idle", 48, {
        "body": _loop(48, 4, lambda ph: (r(2 * s(ph), 2 * s(ph + 0.5), 2 * s(ph + 0.9)), Z0)),
        "head": _loop(48, 4, lambda ph: (r(4 * s(ph + 0.8), 7 * s(ph + 1.5), 0), Z0)),
        "arm_r": _loop(48, 4, lambda ph: (_arm(1, 5 * s(ph + 1.0), 4 + 4 * s(ph)), Z0)),
        "arm_l": _loop(48, 4, lambda ph: (_arm(-1, 5 * s(ph + 2.1), 4 + 4 * s(ph + 1.0)), Z0)),
        "leg_r": _loop(48, 4, lambda ph: (r(0, 4 * s(ph), 0), Z0)), "leg_l": _loop(48, 4, lambda ph: (r(0, 4 * s(ph + 1.6), 0), Z0)),
        "core": pulse()}, loop=True)
    # run: arrasta o tanque: um braço finca à frente, o tronco puxa, depois o outro
    _sclip(arm, "run", 16, {
        "body": _loop(16, 1, lambda ph: (r(11 + 4 * s(2 * ph), 9 * s(ph), 4 * c(ph)), Z0)),
        "head": _loop(16, 1, lambda ph: (r(-6 + 4 * c(2 * ph), -7 * s(ph), 0), Z0)),
        "arm_r": _loop(16, 1, lambda ph: (_arm(1, 14 + 26 * s(ph), 16 + 8 * c(ph)), Z0)),
        "arm_l": _loop(16, 1, lambda ph: (_arm(-1, 14 - 26 * s(ph), 16 - 8 * c(ph)), Z0)),
        "leg_r": _loop(16, 1, lambda ph: (r(0, 10 * s(ph), 0), (0, 0.04 * max(0.0, c(ph)), 0))),
        "leg_l": _loop(16, 1, lambda ph: (r(0, 10 * s(ph), 0), (0, 0.04 * max(0.0, -c(ph)), 0)))}, loop=True)
    # ---- gestos-base ----
    # golpe de garra do braço direito, de fora para dentro (impacto 7)
    swipe = {"body": [(4, r(-8, -26, 0), Z0), (7, r(16, 30, 0), Z0), (10, r(12, 24, 0), Z0), (16, r(3, 4, 0), Z0)],
             "head": [(4, r(-8, 14, 0), Z0), (7, r(12, -14, 0), Z0), (14, r(2), Z0)],
             "arm_r": [(4, _arm(1, -30, 95), Z0), (7, _arm(1, 72, 8, 0), Z0), (10, _arm(1, 66, -4), Z0), (16, _arm(1, 12, 6), Z0)],
             "arm_l": [(4, _arm(-1, 10, 26), Z0), (7, _arm(-1, -24, 34), Z0), (14, _arm(-1, 0, 8), Z0)],
             "core": _sc([(4, 0.8), (7, 1.7), (12, 1.1), (18, 1.0)])}
    # os dois braços abrem e fecham na frente (impacto 8)
    sweep = {"body": [(4, r(-12), Z0), (8, r(20), Z0), (11, r(17), Z0), (17, r(4), Z0)],
             "head": [(4, r(-14), Z0), (8, r(14), Z0), (15, r(2), Z0)],
             "core": _sc([(4, 0.8), (8, 1.8), (13, 1.2), (19, 1.0)])}
    sweep.update(_both([(4, -24, 86), (8, 70, -6), (11, 64, -10), (17, 10, 6)]))
    # pisão: encolhe, ergue os dois braços e desaba com as garras no chão à frente (impacto 8)
    slam = {"body": [(3, r(9), (0, -0.05, 0)), (6, r(-20), (0, 0.04, 0)), (8, r(34), (0, -0.04, 0.05)), (11, r(31), (0, -0.04, 0.05)), (18, r(6), Z0)],
            "head": [(3, r(8), Z0), (6, r(-24), Z0), (8, r(22), Z0), (12, r(14), Z0), (19, r(2), Z0)],
            "leg_r": [(8, r(0, 8, 0), (0, 0.05, 0)), (11, r(0, 4, 0), Z0)], "leg_l": [(8, r(0, -8, 0), (0, 0.05, 0)), (11, r(0, -4, 0), Z0)],
            "core": _sc([(3, 0.7), (6, 1.4), (8, 2.4), (13, 1.4), (20, 1.0)])}
    slam.update(_both([(3, 16, 4), (6, -24, 128), (8, 44, 16), (11, 40, 14), (18, 8, 6)]))
    # urro: junta, joga a cabeça para trás, abre os braços e sacode; a seiva do peito acende (impacto 7)
    roar = {"body": [(4, r(12), (0, -0.04, 0)), (7, r(-18), (0, 0.03, 0)), (9, r(-15, 0, 3), (0, 0.03, 0)), (11, r(-17, 0, -3), (0, 0.03, 0)), (13, r(-14), (0, 0.02, 0)), (18, r(-2), Z0)],
            "head": [(4, r(16), Z0), (7, r(-30), Z0), (9, r(-26, 6, 0), Z0), (11, r(-30, -6, 0), Z0), (13, r(-24), Z0), (18, r(-2), Z0)],
            "core": _sc([(4, 0.6), (7, 2.6), (10, 2.1), (13, 2.4), (19, 1.0)])}
    roar.update(_both([(4, 34, -8), (7, -26, 76), (9, -22, 70), (11, -26, 76), (13, -20, 66), (18, 0, 8)]))
    # chamado: finca as garras, puxa a seiva do chão e ergue os braços devagar (impacto 11)
    summon = {"body": [(4, r(22), (0, -0.06, 0)), (8, r(24), (0, -0.07, 0)), (11, r(-14), (0, 0.04, 0)), (14, r(-10), (0, 0.03, 0)), (21, r(0), Z0)],
              "head": [(4, r(18), Z0), (8, r(22), Z0), (11, r(-26), Z0), (15, r(-14), Z0), (22, r(0), Z0)],
              "leg_r": [(8, r(0, 10, 0), Z0), (11, r(0, -8, 0), (0, 0.06, 0)), (15, r(0, 0, 0), Z0)],
              "leg_l": [(8, r(0, -10, 0), Z0), (11, r(0, 8, 0), (0, 0.06, 0)), (15, r(0, 0, 0), Z0)],
              "core": _sc([(4, 0.7), (8, 0.5), (11, 2.8), (15, 1.8), (22, 1.0)])}
    summon.update(_both([(4, 30, 10), (8, 34, 12), (11, -20, 118), (14, -16, 108), (21, 0, 8)]))
    # casca: encolhe atrás dos braços cruzados (impacto 6)
    brace = {"body": [(3, r(8), (0, -0.03, 0)), (6, r(16), (0, -0.08, 0), (1.05, 0.93, 1.05)), (11, r(15), (0, -0.08, 0), (1.05, 0.93, 1.05)), (16, r(3), Z0, ONE)],
             "head": [(6, r(22), (0, -0.03, 0)), (11, r(20), (0, -0.03, 0)), (16, r(2), Z0)],
             "core": _sc([(6, 0.4), (11, 0.4), (16, 1.0)])}
    brace.update(_both([(3, 20, 10), (6, 52, -22, 20), (11, 50, -22, 20), (16, 8, 6)]))

    _sclip(arm, "maul", 20, swipe)
    _sclip(arm, "attack", 18, _retime(swipe, 7, 5))
    _sclip(arm, "atk_sweep", 21, sweep)
    _sclip(arm, "slam", 22, slam)
    _sclip(arm, "cast_ground", 24, _retime(slam, 8, 10))
    lunge = dict(_retime(slam, 8, 9))                                 # bote: o pisão com o tanque arrastado para a frente
    lunge["root"] = [(4, r(0), (0, 0, -0.1)), (9, r(0), (0, 0, 0.55)), (12, r(0), (0, 0, 0.5)), (20, r(0), Z0)]
    _sclip(arm, "pounce", 23, lunge)
    _sclip(arm, "roar", 21, roar)
    _sclip(arm, "shout", 21, roar)
    _sclip(arm, "cast", 24, _retime(roar, 7, 10))
    _sclip(arm, "summon", 24, summon)
    _sclip(arm, "brace", 18, brace)
    _sclip(arm, "hit", 10, {
        "body": [(2, r(-12, 0, 6), Z0), (5, r(5, 0, -3), Z0), (8, r(-1), Z0)], "head": [(2, r(-20, 0, 10), Z0), (5, r(8, 0, -5), Z0)],
        "arm_r": [(2, _arm(1, -20, 30), Z0), (6, _arm(1, 4, 6), Z0)], "arm_l": [(2, _arm(-1, -20, 30), Z0), (6, _arm(-1, 4, 6), Z0)],
        "core": _sc([(2, 0.4), (6, 1.0)])})
    # die: estremece, ergue-se uma última vez e desaba para a frente sobre o tanque; os braços caem abertos, a seiva apaga
    die = {"body": [(3, r(-10, 0, -5), Z0), (8, r(-22, 0, 6), (0, 0.04, 0)), (14, r(30, 0, 10), (0, -0.1, 0)), (19, r(56, 0, 14), (0, -0.2, 0)),
                    (22, r(52, 0, 13), (0, -0.2, 0)), (25, r(56, 0, 14), (0, -0.2, 0))],
           "head": [(3, r(-12), Z0), (8, r(-34), Z0), (14, r(10), Z0), (19, r(34, 0, -12), Z0), (25, r(30, 0, -12), Z0)],
           "leg_r": [(8, r(0, 12, 0), (0, 0.05, 0)), (14, r(0, 20, 0), Z0), (20, r(0, 24, 0), Z0)],
           "leg_l": [(8, r(0, -12, 0), (0, 0.05, 0)), (14, r(0, -20, 0), Z0), (20, r(0, -24, 0), Z0)],
           "core": _sc([(3, 2.2), (8, 2.8), (12, 0.8), (16, 1.3), (22, 0.001)])}
    die.update(_both([(3, -20, 40), (8, -40, 110), (14, -30, 60), (19, -52, 70), (22, -48, 66), (25, -52, 70)]))
    _sclip(arm, "die", 30, die)
    return arm


BUILDERS = {
    "mob_sap_sprout": sap_sprout,
    "mob_sap_tank": sap_tank,
    "mob_sap_mother": sap_mother,
}
HUMANOIDS = set()          # todos de peças rígidas (lp.export_glb)
