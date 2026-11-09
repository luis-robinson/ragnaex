"""Gestos de chefe dos bichos: maul, pounce, slam, roar, brace (sem laço). EntityView.FORM_CLIP manda cada família de skill
para um destes quando o modelo não tem o clipe humano; impacto em EntityView.IMPACT_FRAME (24 fps, quadro 1 = início):
maul 7, pounce 9, slam 8, roar 7, brace 6. Todos com preparo antes do impacto e acomodação depois, legíveis de cima:
slam = sobe/empina e desaba; pounce = agacha e salta para a frente; roar = recua, abre garras/braços e sacode;
maul = golpe largo de garra/pinça/braço; brace = se encolhe baixo.

Rig dos monstros (build_monsters.MOB_BONES, pivôs ajustados por mob_kit.pivots):
- corpo/raiz: X+ = inclina para a frente, Y = gira (yaw), Z = rola de lado; loc (0, cima, frente).
- membros que pendem (arm_*, leg_*): X- = ponta para a frente/cima; "out" abre para fora do lado dele (Z), "yaw" gira a ponta
  para fora em volta do próprio eixo (pinça/garra que aponta para a frente). Ossos *_r/*_fr/*_br ficam em +X.

    import boss_gestures; boss_gestures.add(arm, "crab")
"""
import lowpoly_lib as lp

Z = (0, 0, 0)
ONE = (1, 1, 1)
CLIPS = ("maul", "pounce", "slam", "roar", "brace")


def r(x=0.0, y=0.0, z=0.0):
    return (x, y, z)


def p(up=0.0, fwd=0.0):
    return (0, up, fwd)


def limb(bone, seq):
    """seq = [(quadro, x, out, yaw)] (out/yaw opcionais) -> chaves do osso, espelhando o lado."""
    s = -1 if bone.endswith("r") else 1
    out = []
    for k in seq:
        f, x = k[0], k[1]
        o = k[2] if len(k) > 2 else 0.0
        y = k[3] if len(k) > 3 else 0.0
        out.append((f, (x, s * y, s * o), Z))
    return out


def _at(keys, f, i):
    """valor linear do componente i (1 = rot, 2 = loc) de uma lista de chaves no quadro f"""
    if f <= keys[0][0]:
        return keys[0][i]
    for a, b in zip(keys, keys[1:]):
        if a[0] <= f <= b[0]:
            t = (f - a[0]) / float(b[0] - a[0])
            return tuple(a[i][j] + (b[i][j] - a[i][j]) * t for j in range(3))
    return keys[-1][i]


def plant(body, bone, seq=()):
    """Perna que segue o corpo sem afundar: desfaz a inclinação do corpo (X) e, quando ele abaixa, sobe a perna o mesmo tanto.
    seq = extra do membro [(quadro, x, out, yaw)] por cima disso."""
    extra = limb(bone, [(1, 0)] + list(seq) + [(body[-1][0], 0)]) if seq else limb(bone, [(1, 0), (body[-1][0], 0)])
    frames = sorted({k[0] for k in body} | {k[0] for k in extra})
    keys = []
    for f in frames:
        bx = _at(body, f, 1)[0]
        up = _at(body, f, 2)[1]
        ex = _at(extra, f, 1)
        keys.append((f, (ex[0] - bx, ex[1], ex[2]), (0, min(0.0, up), 0)))
    return keys


def _scaled(keys):
    """chaves de raiz com escala: completa com escala 1 as que não têm"""
    return [k if len(k) > 3 else (k[0], k[1], k[2], ONE) for k in keys]


def _add(arm, name, keys, end):
    lp.add_action(arm, name, keys, end, loop=False)


# ---------------------------------------------------------------------------
# bípedes pesados: golens chefes, Trent Ancião (braços no ombro, pernas curtas)
# ---------------------------------------------------------------------------
def biped(arm, legs=("leg_fr", "leg_fl")):
    arms = ("arm_r", "arm_l")
    # pisão: agacha, sobe na ponta com os dois punhos acima da cabeça, desaba com o tronco e os punhos no chão (8)
    body = [(1, Z, Z), (3, r(4), p(-0.04)), (4, r(-12), p(0.08, -0.03)), (6, r(-18), p(0.11, -0.05)), (8, r(26), p(-0.1, 0.12)),
            (10, r(24, 0, 3), p(-0.1, 0.11)), (12, r(20, 0, -2), p(-0.07, 0.08)), (15, r(7), p(-0.02, 0.03)), (19, r(-2), p(0.01)), (22, Z, Z)]
    k = {"body": body, "head": [(1, Z, Z), (3, r(10), Z), (5, r(-24), Z), (8, r(14), Z), (10, r(12, 0, 6), Z), (12, r(10, 0, -6), Z), (16, r(2), Z), (22, Z, Z)]}
    for a in arms:
        k[a] = limb(a, [(1, 0), (3, -70, 12), (4, -140, 14), (6, -172, 12), (8, -62, 8), (10, -58, 8), (12, -52, 6), (15, -24, 3), (19, 4), (22, 0)])
    for g in legs:
        k[g] = plant(body, g, [(5, 4), (8, -4, 6), (12, -2, 4)])
    _add(arm, "slam", k, 22)
    # patada: gira o tronco, ergue o braço direito por fora e varre cruzando à frente; o esquerdo devolve com as costas da mão (7)
    body = [(1, Z, Z), (3, r(-6, -16), p(0.02, -0.04)), (5, r(-8, -28), p(0.03, -0.06)), (7, r(18, 26), p(-0.05, 0.14)), (9, r(16, 30), p(-0.05, 0.13)),
            (11, r(10, 12), p(-0.03, 0.08)), (14, r(2, -4), p(0, 0.02)), (18, Z, Z)]
    k = {"body": body,
         "head": [(1, Z, Z), (3, r(-8, 0, 10), Z), (5, r(-12, 0, 14), Z), (7, r(14, 0, -12), Z), (9, r(12, 0, -14), Z), (12, r(4), Z), (18, Z, Z)],
         "arm_r": limb("arm_r", [(1, 0), (3, -70, 40), (5, -125, 55), (7, -80, -35), (9, -55, -45), (11, -35, -20), (14, -6), (18, 0)]),
         "arm_l": limb("arm_l", [(1, 0), (3, -20, 10), (5, -35, 15), (7, -10, 5), (9, -70, 40), (11, -40, -25), (14, -8), (18, 0)])}
    for g in legs:
        k[g] = plant(body, g, [(5, 6), (7, -6, 4)])
    _add(arm, "maul", k, 18)
    # rugido: recolhe, empina o tronco, abre os braços em V acima da cabeça e sacode (7)
    body = [(1, Z, Z), (4, r(10), p(-0.06)), (7, r(-20), p(0.06)), (9, r(-18, 0, 4), p(0.06)), (11, r(-20, 0, -4), p(0.06)), (13, r(-18, 0, 3), p(0.05)),
            (15, r(-16), p(0.04)), (19, r(3), p(-0.01)), (22, Z, Z)]
    k = {"body": body,
         "head": [(1, Z, Z), (4, r(16), Z), (7, r(-30, 0, 8), Z), (9, r(-28, 0, -8), Z), (11, r(-30, 0, 8), Z), (13, r(-26), Z), (16, r(-12), Z), (19, r(4), Z), (22, Z, Z)]}
    for a in arms:
        k[a] = limb(a, [(1, 0), (4, -25, -12), (7, -30, 125), (9, -34, 132), (11, -28, 124), (13, -32, 130), (16, -20, 60), (19, 4), (22, 0)])
    for g in legs:
        k[g] = plant(body, g, [(7, 0, 6), (16, 0, 6)])
    _add(arm, "roar", k, 22)
    # bote: agacha com os braços para trás, salta para a frente com os punhos no alto e cai socando o chão (9)
    body = [(1, Z, Z), (3, r(10), p(-0.06)), (5, r(18), p(-0.12, -0.06)), (7, r(-10), p(0.3, 0.25)), (8, r(2), p(0.28, 0.4)), (9, r(22), p(-0.06, 0.45)),
            (11, r(18), p(-0.07, 0.4)), (13, r(10), p(-0.04, 0.3)), (16, r(2), p(0, 0.12)), (20, Z, Z)]
    k = {"body": body,
         "head": [(1, Z, Z), (5, r(14), Z), (7, r(-18), Z), (9, r(18), Z), (12, r(10), Z), (20, Z, Z)]}
    for a in arms:
        k[a] = limb(a, [(1, 0), (3, 20, 8), (5, 38, 12), (7, -150, 18), (8, -140, 14), (9, -62, 8), (11, -58, 6), (14, -26, 3), (20, 0)])
    for g in legs:
        k[g] = plant(body, g, [(5, 6), (7, 24), (8, 18), (9, -4, 6), (12, -2, 3)])
    _add(arm, "pounce", k, 20)
    # guarda: agacha e crava os punhos abertos no chão à frente, cabeça baixa entre os ombros (6)
    body = [(1, Z, Z), (3, r(-4), p(0.03)), (6, r(18), p(-0.08)), (9, r(16), p(-0.07)), (12, r(18), p(-0.08)), (15, r(5), p(-0.02)), (18, Z, Z)]
    k = {"body": body, "head": [(1, Z, Z), (3, r(-8), Z), (6, r(-6), Z), (12, r(-8), Z), (18, Z, Z)]}
    for a in arms:
        k[a] = limb(a, [(1, 0), (3, -14, 6), (6, -36, 18), (9, -34, 17), (12, -36, 18), (15, -12, 6), (18, 0)])
    for g in legs:
        k[g] = plant(body, g, [(6, 0, 10), (12, 0, 10)])
    _add(arm, "brace", k, 18)


# ---------------------------------------------------------------------------
# caranguejo: pinças (arm_*) que apontam para a frente, 3 patas de cada lado
# ---------------------------------------------------------------------------
def crab(arm):
    legs = ("leg_fr", "leg_fl", "leg_br", "leg_bl")
    # beliscão: ergue a pinça direita por fora e fecha cruzando, a esquerda logo depois (7)
    body = [(1, Z, Z), (3, r(-6, -14), p(0.03)), (5, r(-8, -20), p(0.04, -0.04)), (7, r(10, 18), p(-0.03, 0.1)), (9, r(8, 22), p(-0.02, 0.08)),
            (11, r(4, -10), p(0, 0.04)), (16, Z, Z)]
    k = {"body": body,
         "head": [(1, Z, Z), (5, r(-10), Z), (7, r(12), Z), (11, r(4), Z), (16, Z, Z)],
         "arm_r": limb("arm_r", [(1, 0), (3, -30, 0, 30), (5, -60, 0, 45), (7, 12, 0, -30), (9, 8, 0, -34), (12, -6, 0, -6), (16, 0)]),
         "arm_l": limb("arm_l", [(1, 0), (3, -10, 0, 8), (5, -18, 0, 12), (7, -30, 0, 30), (9, 10, 0, -28), (12, -4, 0, -4), (16, 0)])}
    for g in legs:
        k[g] = plant(body, g)
    _add(arm, "maul", k, 16)
    # pisão: empina o casco com as duas pinças no alto e desaba martelando o chão (8)
    body = [(1, Z, Z), (3, r(6), p(-0.04)), (5, r(-22), p(0.16)), (6, r(-24), p(0.17)), (8, r(14), p(-0.06, 0.06)), (10, r(12, 0, 4), p(-0.05, 0.05)),
            (12, r(10, 0, -3), p(-0.04, 0.04)), (15, r(3), Z), (20, Z, Z)]
    k = {"body": body, "head": [(1, Z, Z), (5, r(-16), Z), (8, r(14), Z), (12, r(6), Z), (20, Z, Z)]}
    for a in ("arm_r", "arm_l"):
        k[a] = limb(a, [(1, 0), (3, 10), (5, -80, 0, 15), (6, -86, 0, 15), (8, 10, 0, -4), (10, 8), (12, 6), (15, 2), (20, 0)])
    for g in legs:
        k[g] = plant(body, g, [(8, 0, 8), (12, 0, 4)])
    _add(arm, "slam", k, 20)
    # bote: agacha, salta para a frente de pinças escancaradas e fecha ao cair (9)
    body = [(1, Z, Z), (3, r(6), p(-0.06)), (5, r(10), p(-0.1, -0.05)), (7, r(-12), p(0.42, 0.22)), (8, r(-4), p(0.4, 0.35)), (9, r(12), p(-0.04, 0.4)),
            (11, r(8), p(-0.04, 0.34)), (13, r(4), p(-0.02, 0.22)), (18, Z, Z)]
    k = {"body": body, "head": [(1, Z, Z), (5, r(10), Z), (7, r(-16), Z), (9, r(12), Z), (13, r(4), Z), (18, Z, Z)]}
    for a in ("arm_r", "arm_l"):
        k[a] = limb(a, [(1, 0), (5, 15, 0, 10), (7, -35, 0, 35), (8, -30, 0, 40), (9, 6, 0, -22), (11, 4, 0, -24), (14, 0, 0, -5), (18, 0)])
    for g in legs:
        k[g] = plant(body, g, [(5, 0, 10), (7, 0, -18), (8, 0, -14), (9, 0, 10), (12, 0, 4)])
    _add(arm, "pounce", k, 18)
    # rugido: empina, pinças no alto e abertas, batendo e sacudindo (7)
    body = [(1, Z, Z), (4, r(8), p(-0.05)), (7, r(-24), p(0.12)), (9, r(-22, 0, 5), p(0.12)), (11, r(-24, 0, -5), p(0.12)), (13, r(-22, 0, 4), p(0.11)),
            (16, r(-14), p(0.06)), (19, r(3), Z), (22, Z, Z)]
    k = {"body": body,
         "head": [(1, Z, Z), (4, r(10), Z), (7, r(-20, 0, 10), Z), (9, r(-18, 0, -10), Z), (11, r(-20, 0, 10), Z), (14, r(-10), Z), (22, Z, Z)]}
    for a in ("arm_r", "arm_l"):
        k[a] = limb(a, [(1, 0), (4, 15, 0, -10), (7, -75, 0, 35), (9, -82, 0, 26), (11, -72, 0, 38), (13, -82, 0, 28), (16, -40, 0, 15), (19, 4), (22, 0)])
    for g in legs:
        k[g] = plant(body, g)
    _add(arm, "roar", k, 22)
    # guarda: encolhe rente ao chão com as pinças fechadas à frente (6)
    body = [(1, Z, Z), (3, r(-4), p(0.03)), (6, r(8), p(-0.08)), (9, r(6), p(-0.07)), (12, r(8), p(-0.08)), (15, r(2), p(-0.02)), (18, Z, Z)]
    k = {"body": body, "head": [(1, Z, Z), (6, r(16), Z), (12, r(14), Z), (18, Z, Z)]}
    for a in ("arm_r", "arm_l"):
        k[a] = limb(a, [(1, 0), (3, -10, 0, 8), (6, -14, 0, -34), (9, -12, 0, -32), (12, -14, 0, -34), (15, -4, 0, -8), (18, 0)])
    for g in legs:
        k[g] = plant(body, g)
    _add(arm, "brace", k, 18)


def crab_attack(arm):
    """Básico do caranguejo (troca o genérico de combat_actions, que com a pinça pivotando no ombro a enterrava no chão):
    abre as duas pinças no alto e fecha num beliscão à frente; impacto no 5 (EntityView.IMPACT_FRAME["attack"])."""
    for t in list(arm.animation_data.nla_tracks if arm.animation_data else []):
        if t.name == "attack":
            arm.animation_data.nla_tracks.remove(t)
    body = [(1, Z, Z), (3, r(-8), p(0.03, -0.06)), (5, r(10), p(-0.02, 0.16)), (7, r(8, 0, 4), p(-0.02, 0.13)), (10, r(4), p(0, 0.07)), (13, r(-2), Z), (16, Z, Z)]
    k = {"body": body, "head": [(1, Z, Z), (3, r(-10), Z), (5, r(10), Z), (9, r(4), Z), (16, Z, Z)]}
    for a in ("arm_r", "arm_l"):
        k[a] = limb(a, [(1, 0), (3, -45, 0, 25), (5, 6, 0, -22), (7, 4, 0, -26), (10, -4, 0, -8), (16, 0)])
    for g in ("leg_fr", "leg_fl", "leg_br", "leg_bl"):
        k[g] = plant(body, g)
    _add(arm, "attack", k, 16)


# ---------------------------------------------------------------------------
# aranha: 2 patas da frente por lado em leg_fr/leg_fl, as de trás em leg_br/leg_bl, presas na cabeça
# ---------------------------------------------------------------------------
def spider(arm):
    front, back = ("leg_fr", "leg_fl"), ("leg_br", "leg_bl")
    # golpe: empina com as patas da frente no alto e crava à frente, presas mordendo (7)
    body = [(1, Z, Z), (3, r(-10), p(0.06)), (5, r(-20), p(0.12, -0.04)), (7, r(14), p(-0.04, 0.14)), (9, r(12), p(-0.04, 0.12)), (11, r(6), p(0, 0.06)), (16, Z, Z)]
    k = {"body": body, "head": [(1, Z, Z), (3, r(-14), Z), (5, r(-20), Z), (7, r(22), Z), (9, r(18), Z), (12, r(4), Z), (16, Z, Z)]}
    for g in front:
        k[g] = limb(g, [(1, 0), (3, -20, 40), (5, -30, 72), (7, -38, -4), (9, -34, -4), (12, -10, 4), (16, 0)])
    for g in back:
        k[g] = plant(body, g)
    _add(arm, "maul", k, 16)
    # pisão: empina alto com todas as patas da frente erguidas e desaba (8)
    body = [(1, Z, Z), (3, r(6), p(-0.04)), (5, r(-34), p(0.16)), (6, r(-36), p(0.17)), (8, r(14), p(-0.08, 0.06)), (10, r(12, 0, 4), p(-0.07, 0.05)),
            (12, r(9, 0, -3), p(-0.05, 0.04)), (15, r(3), p(-0.01)), (20, Z, Z)]
    k = {"body": body, "head": [(1, Z, Z), (5, r(-24), Z), (8, r(18), Z), (12, r(8), Z), (20, Z, Z)]}
    for g in front:
        k[g] = limb(g, [(1, 0), (3, 6, -5), (5, -10, 85), (6, -12, 90), (8, -16, 6), (10, -14, 6), (13, -6, 3), (20, 0)])
    for g in back:
        k[g] = plant(body, g, [(8, 0, 8), (12, 0, 4)])
    _add(arm, "slam", k, 20)
    # bote: agacha abrindo as patas, salta para a frente encolhida e cai esparramada (9)
    body = [(1, Z, Z), (3, r(4), p(-0.06)), (5, r(8), p(-0.14, -0.05)), (7, r(-14), p(0.38, 0.25)), (8, r(-4), p(0.36, 0.38)), (9, r(10), p(-0.04, 0.42)),
            (11, r(6), p(-0.06, 0.36)), (13, r(3), p(-0.02, 0.24)), (18, Z, Z)]
    k = {"body": body, "head": [(1, Z, Z), (5, r(10), Z), (7, r(-16), Z), (9, r(14), Z), (13, r(4), Z), (18, Z, Z)]}
    for g in front:
        k[g] = plant(body, g, [(5, 0, 12), (7, -30, -28), (8, -24, -22), (9, 0, 16), (11, 0, 10)])
    for g in back:
        k[g] = plant(body, g, [(5, 0, 12), (7, 20, -28), (8, 14, -22), (9, 0, 16), (11, 0, 10)])
    _add(arm, "pounce", k, 18)
    # rugido: empina com as patas da frente abertas no alto, balançando, presas tremendo (7)
    body = [(1, Z, Z), (4, r(8), p(-0.05)), (7, r(-28), p(0.14)), (9, r(-26, 0, 5), p(0.14)), (11, r(-28, 0, -5), p(0.14)), (13, r(-26, 0, 4), p(0.13)),
            (16, r(-16), p(0.07)), (19, r(3), Z), (22, Z, Z)]
    k = {"body": body,
         "head": [(1, Z, Z), (4, r(12), Z), (7, r(-22, 0, 10), Z), (9, r(-20, 0, -10), Z), (11, r(-22, 0, 10), Z), (14, r(-10), Z), (22, Z, Z)]}
    for g in front:
        k[g] = limb(g, [(1, 0), (4, 10, -10), (7, -20, 85), (9, -30, 95), (11, -18, 80), (13, -28, 92), (16, -10, 40), (19, 2), (22, 0)])
    for g in back:
        k[g] = plant(body, g)
    _add(arm, "roar", k, 22)
    # guarda: achata o corpo no chão, patas de trás abertas, as da frente dobradas à frente como escudo (6)
    body = [(1, Z, Z), (3, r(-4), p(0.03)), (6, r(6), p(-0.14)), (9, r(5), p(-0.13)), (12, r(6), p(-0.14)), (15, r(2), p(-0.03)), (18, Z, Z)]
    k = {"body": body, "head": [(1, Z, Z), (6, r(16), Z), (12, r(14), Z), (18, Z, Z)]}
    for g in front:
        k[g] = plant(body, g, [(3, -6), (6, -22, 12), (9, -20, 11), (12, -22, 12), (15, -6, 3)])
    for g in back:
        k[g] = plant(body, g, [(6, 0, 14), (12, 0, 14)])
    _add(arm, "brace", k, 18)


# ---------------------------------------------------------------------------
# espectro: flutua (raiz), lençol no corpo, braços-fita
# ---------------------------------------------------------------------------
def ghost(arm):
    # garra: recua, avança girando e rasga com a direita, depois a esquerda (7)
    k = {"root": [(1, Z, Z), (3, r(-8), p(0.06, -0.08)), (5, r(-10), p(0.1, -0.1)), (7, r(18), p(-0.02, 0.3)), (9, r(16), p(-0.02, 0.28)),
                  (12, r(6), p(0.02, 0.12)), (16, Z, Z)],
         "body": [(1, Z, Z), (3, r(0, -14), Z), (5, r(0, -24), Z), (7, r(0, 24), Z), (9, r(0, 28), Z), (11, r(0, -12), Z), (16, Z, Z)],
         "head": [(1, Z, Z), (5, r(-10), Z), (7, r(14), Z), (16, Z, Z)],
         "arm_r": limb("arm_r", [(1, 0), (3, -60, 40), (5, -120, 60), (7, -70, -40), (9, -50, -45), (12, -20, -10), (16, 0)]),
         "arm_l": limb("arm_l", [(1, 0), (5, -30, 20), (7, -20, 10), (9, -90, 50), (11, -50, -30), (16, 0)])}
    _add(arm, "maul", k, 16)
    # mergulho: sobe alto com os braços acima e despenca inclinado sobre o alvo (8)
    k = {"root": [(1, Z, Z), (3, Z, p(-0.06)), (5, r(-12), p(0.55, -0.05)), (6, r(-14), p(0.6, -0.06)), (8, r(24), p(-0.1, 0.15)), (10, r(20), p(-0.09, 0.13)),
                  (12, r(14), p(-0.06, 0.1)), (15, r(5), p(-0.02, 0.04)), (19, r(-2), p(0.02)), (22, Z, Z)],
         "head": [(1, Z, Z), (5, r(-22), Z), (8, r(16), Z), (12, r(8), Z), (22, Z, Z)]}
    for a in ("arm_r", "arm_l"):
        k[a] = limb(a, [(1, 0), (3, -20, 10), (5, -165, 20), (6, -170, 18), (8, -60, 5), (10, -55, 5), (13, -30), (18, 4), (22, 0)])
    _add(arm, "slam", k, 22)
    # investida: puxa para trás, dispara esticado para a frente com os braços estendidos e volta à deriva (9)
    k = {"root": _scaled([(1, Z, Z), (3, r(-6), p(0.04, -0.1)), (5, r(-12), p(0.08, -0.18), (1.05, 0.95, 0.95)), (7, r(28), p(0.0, 0.35), (0.86, 0.95, 1.32)),
                          (9, r(32), p(-0.04, 0.55), (0.9, 0.92, 1.26)), (11, r(26), p(-0.04, 0.5), (0.96, 0.98, 1.1)), (13, r(14), p(0, 0.36)),
                          (16, r(4), p(0.02, 0.15)), (20, Z, Z)]),
         "head": [(1, Z, Z), (5, r(10), Z), (7, r(-14), Z), (9, r(-10), Z), (20, Z, Z)]}
    for a in ("arm_r", "arm_l"):
        k[a] = limb(a, [(1, 0), (3, 30, 15), (5, 40, 20), (7, -100, 10), (9, -95, -10), (11, -90, -5), (14, -40), (20, 0)])
    _add(arm, "pounce", k, 20)
    # grito: incha, recua e abre os braços, tremendo (7)
    k = {"root": [(1, Z, Z, ONE), (4, r(8), p(-0.06), (0.92, 0.9, 0.92)), (7, r(-16), p(0.18), (1.22, 1.2, 1.22)), (9, r(-14, 0, 4), p(0.18), (1.18, 1.24, 1.18)),
                  (11, r(-16, 0, -4), p(0.18), (1.24, 1.18, 1.24)), (13, r(-14, 0, 3), p(0.16), (1.2, 1.22, 1.2)), (16, r(-8), p(0.08), (1.08, 1.08, 1.08)),
                  (19, r(2), p(-0.01), ONE), (22, Z, Z, ONE)],
         "head": [(1, Z, Z), (4, r(14), Z), (7, r(-26, 0, 8), Z), (9, r(-24, 0, -8), Z), (11, r(-26, 0, 8), Z), (14, r(-12), Z), (22, Z, Z)]}
    for a in ("arm_r", "arm_l"):
        k[a] = limb(a, [(1, 0), (4, -30, -15), (7, -40, 120), (9, -44, 128), (11, -36, 118), (13, -42, 126), (16, -20, 50), (19, 2), (22, 0)])
    _add(arm, "roar", k, 22)
    # guarda: se enrola, encolhe e abraça o corpo (6)
    k = {"root": [(1, Z, Z, ONE), (3, r(-4), p(0.04), ONE), (6, r(16), p(-0.1), (0.9, 0.85, 0.9)), (9, r(14), p(-0.09), (0.92, 0.86, 0.92)),
                  (12, r(16), p(-0.1), (0.9, 0.85, 0.9)), (15, r(4), p(-0.02), (0.98, 0.98, 0.98)), (18, Z, Z, ONE)],
         "head": [(1, Z, Z), (6, r(18), Z), (12, r(16), Z), (18, Z, Z)]}
    for a in ("arm_r", "arm_l"):
        k[a] = limb(a, [(1, 0), (3, -20, 10), (6, -80, -35), (12, -80, -35), (15, -30, -10), (18, 0)])
    _add(arm, "brace", k, 18)


# ---------------------------------------------------------------------------
# slime: só esmaga/estica (escala da raiz, que fica no chão) e inclina
# ---------------------------------------------------------------------------
def slime(arm):
    k = {"root": _scaled([(1, Z, Z), (3, Z, p(0, -0.04), (1.15, 0.85, 1.15)), (5, Z, p(0.04, -0.08), (0.86, 1.25, 0.86)), (7, Z, p(0, 0.25), (1.12, 0.85, 1.3)),
                          (9, Z, p(0, 0.22), (1.2, 0.82, 1.15)), (11, Z, p(0, 0.12), (0.94, 1.08, 0.96)), (13, Z, p(0, 0.04), (1.03, 0.97, 1.03)), (16, Z, Z)]),
         "body": [(1, Z, Z), (3, r(-6), Z), (5, r(-24), Z), (7, r(32), Z), (9, r(28), Z), (11, r(8), Z), (13, r(-3), Z), (16, Z, Z)]}
    _add(arm, "maul", k, 16)
    k = {"root": _scaled([(1, Z, Z), (3, Z, Z, (1.2, 0.75, 1.2)), (5, Z, p(0, -0.04), (1.32, 0.6, 1.32)), (7, Z, p(0.55, 0.25), (0.8, 1.35, 0.85)),
                          (8, Z, p(0.5, 0.38), (0.86, 1.25, 0.9)), (9, Z, p(0, 0.45), (1.45, 0.55, 1.4)), (11, Z, p(0.1, 0.42), (0.88, 1.18, 0.9)),
                          (13, Z, p(0, 0.36), (1.1, 0.9, 1.1)), (16, Z, p(0, 0.16), (0.97, 1.03, 0.97)), (20, Z, Z)]),
         "body": [(1, Z, Z), (5, r(10), Z), (7, r(-14), Z), (9, r(10), Z), (11, r(-4), Z), (20, Z, Z)]}
    _add(arm, "pounce", k, 20)
    k = {"root": _scaled([(1, Z, Z), (3, Z, Z, (1.15, 0.82, 1.15)), (5, Z, p(0.3), (0.72, 1.55, 0.72)), (6, Z, p(0.34), (0.7, 1.6, 0.7)), (8, Z, Z, (1.65, 0.42, 1.65)),
                          (10, Z, Z, (0.85, 1.22, 0.85)), (12, Z, Z, (1.15, 0.88, 1.15)), (15, Z, Z, (0.96, 1.05, 0.96)), (20, Z, Z)]),
         "body": [(1, Z, Z), (5, r(-8), Z), (8, r(4), Z), (20, Z, Z)]}
    _add(arm, "slam", k, 20)
    k = {"root": _scaled([(1, Z, Z), (4, Z, Z, (1.15, 0.8, 1.15)), (7, Z, p(0.02), (1.38, 1.3, 1.38)), (9, Z, p(0.02), (1.28, 1.4, 1.28)), (11, Z, p(0.02), (1.4, 1.26, 1.4)),
                          (13, Z, p(0.02), (1.3, 1.36, 1.3)), (16, Z, Z, (1.12, 1.1, 1.12)), (19, Z, Z, (0.96, 1.04, 0.96)), (22, Z, Z)]),
         "body": [(1, Z, Z), (4, r(8), Z), (7, r(-14, 0, 6), Z), (9, r(-12, 0, -6), Z), (11, r(-14, 0, 6), Z), (13, r(-12, 0, -4), Z), (16, r(-5), Z), (22, Z, Z)]}
    _add(arm, "roar", k, 22)
    k = {"root": _scaled([(1, Z, Z), (3, Z, Z, (0.94, 1.08, 0.94)), (6, Z, Z, (1.38, 0.62, 1.38)), (9, Z, Z, (1.34, 0.65, 1.34)), (12, Z, Z, (1.38, 0.62, 1.38)),
                          (15, Z, Z, (1.05, 0.95, 1.05)), (18, Z, Z)]),
         "body": [(1, Z, Z), (3, r(-4), Z), (6, r(4), Z), (12, r(4), Z), (18, Z, Z)]}
    _add(arm, "brace", k, 18)


def quad(arm):
    """quadrúpedes de pelo (javali): os mesmos gestos das formas do druida (rig com tail/body/head/leg_*)"""
    import druid_sets
    druid_sets.form_clips(lp, arm, "wolf")


KINDS = {"biped": biped, "biped4": lambda arm: biped(arm, ("leg_fr", "leg_fl", "leg_br", "leg_bl")), "crab": crab, "spider": spider,
         "ghost": ghost, "slime": slime, "quad": quad}


def add(arm, kind):
    for name in CLIPS:             # refazer não duplica
        tr = arm.animation_data.nla_tracks.get(name) if arm.animation_data else None
        if tr:
            arm.animation_data.nla_tracks.remove(tr)
    KINDS[kind](arm)
