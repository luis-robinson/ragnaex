"""Poses dos clipes de arquétipo do pacote C2 (production/qa/spell-attack-anim-research-2026-11-23.md):
cast_heal_nature, cast_curse, cast_wind, summon_rise, summon_call, atk_bow_charge, atk_pistol_pair, atk_pistol_fan,
atk_scythe_reap, shout_rally.

    blender -b --factory-startup --python tools/blender/archetype_clips_solve.py                 (resolve e grava archetype_clips_data.py)
    blender -b --factory-startup --python tools/blender/archetype_clips_solve.py -- --dry        (só o relatório)
    ... -- [--dry] --shots=<pasta ABSOLUTA> [--clips=a,b] [--step=2] [--ground]   (folha por clipe: câmera do jogo 52°, lado, frente;
                                                                                   impacto com fundo amarelo; --ground = com a folga do chão)

O desenho de cada chave fica AQUI (CLIPS): tronco e quadril à mão; mãos por ALVO (posição da mão + direção da arma),
resolvidas por FK no rig do kit; pés plantados por alvo quando o corpo desce ou dá passo. O resultado (pose inteira por chave,
por sexo: a largura do ombro muda) vai para archetype_clips_data.py, lido por chibi_kit.animate_archetypes. Mudou uma chave:
rode de novo, refaça os kits (chibi_kit.build_kits) e `--import`.

Convenções: personagem olha para -Y, direita dele = -X. `yaw` + = vira para a ESQUERDA dele (root, spine, chest).
Alvo de mão: ("w", p) = ponto no espaço do root; ("s", d) = ombro + d girando com o peito; ("sw", d) = ombro + d nos eixos do root.
O braço tem ~0,34 m do ombro ao centro da mão: |d| maior que isso = braço esticado nessa direção.
Impactos (chibi_kit.C2_IMPACT = EntityView.IMPACT_FRAME): a pose da chave do impacto é a que identifica o gesto (o jogo
encolhe o preparo; o que se vê em velocidade normal é do impacto em diante).
"""
import math
import os
import sys

import bpy
from mathutils import Matrix, Vector, Euler

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.append(HERE)
import chibi_kit as ck

ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []


def arg(name, default=""):
    for a in ARGS:
        if a.startswith(name + "="):
            return a.split("=", 1)[1]
    return default


def az(phi, el=0.0):
    """Direção: phi = azimute em graus (0 = frente, + = direita do personagem), el = elevação."""
    p, e = math.radians(phi), math.radians(el)
    return Vector((-math.sin(p) * math.cos(e), -math.cos(p) * math.cos(e), math.sin(e)))


R = ck.READY
HEAD_C = Vector((0, 0, 1.32))
HEAD_R = 0.40            # arma e mãos passam por fora da cabeça
# eixo da arma na mão direita no repouso (kit_weapon) e comprimento a partir da mão
AXES = {"sword": (Vector((0, -0.55, 0.83)).normalized(), 0.85), "staff": (Vector((-0.22, -0.12, 1.0)).normalized(), 0.8),
        "scythe": (Vector((0, 0, 1)), 0.9), "any": (Vector((-0.08, -0.3, 0.95)).normalized(), 0.85)}
BLADE = Vector((0, -1, 0))        # para onde sai a lâmina da foice no repouso


def T(sp=(6, 0), ch=(0, 0), hd=(-4, 0, 0), root=0.0, hy=0.0):
    """Tronco: spine/chest = (inclinação, giro), cabeça (x, y[, z]), root = giro do corpo todo, hy = giro do quadril."""
    hd = tuple(hd) + (0,) * (3 - len(hd))
    return {"root": (0, root, 0), "hips": (0, hy, 0), "spine": (sp[0], sp[1], 0), "chest": (ch[0], ch[1], 0), "head": hd}


def A(space, pos, dir=None, bend=(-125, -4), elbow=None, hand=None, grip=None, lead=None):
    """Alvo de braço. dir = direção da arma (só .R); hand = giro da mão escrito à mão; grip = mão esquerda no cabo da arma
    da direita, a `grip` metros da mão direita (pos é ignorado); lead = direção em que a lâmina da foice vai na frente."""
    return {"space": space, "pos": Vector(pos), "dir": None if dir is None else Vector(dir).normalized(), "bend": bend,
            "elbow": elbow, "hand": hand, "grip": grip, "lead": None if lead is None else Vector(lead).normalized()}


def K(f, trunk=None, hips=(0, 0, 0), R=None, L=None, legs=None, feet=None, raw=None, blend=None, extra=None):
    """Chave. raw = pose escrita (parte de READY); trunk/R/L/legs/feet por cima; blend = w: mistura a chave anterior com READY."""
    return {"f": f, "trunk": trunk, "hips": tuple(hips), "R": R, "L": L, "legs": legs, "feet": feet, "raw": raw, "blend": blend,
            "extra": extra}


# pernas escritas (as mesmas famílias do chibi_kit._family_clips)
WIDE = {"thigh.R": (-18, 0, 0), "shin.R": (20, 0, 0), "thigh.L": (14, 0, 0), "shin.L": (16, 0, 0)}
LUNGE = {"thigh.R": (-46, 0, 0), "shin.R": (48, 0, 0), "thigh.L": (32, 0, 0), "shin.L": (26, 0, 0)}
LUNGE_L = {"thigh.L": (-46, 0, 0), "shin.L": (48, 0, 0), "thigh.R": (32, 0, 0), "shin.R": (26, 0, 0)}
SINK = {"thigh.R": (-34, 0, 0), "shin.R": (46, 0, 0), "thigh.L": (-22, 0, 0), "shin.L": (40, 0, 0)}
TIPTOE = dict(WIDE, **{"foot.R": (16, 0, 0), "foot.L": (16, 0, 0)})
# pés plantados (x, y, altura do tornozelo[, quanto o tornozelo fica acima da ponta do pé; 0,04 = pé chato])
FR, FL = (-0.12, -0.06, 0.07), (0.12, 0.07, 0.07)

# --- arco (mão ESQUERDA segura o arco): os ângulos do atk_bow do kit ---
BOW_SIDE = {"spine": (2, 48, 0), "chest": (0, 8, 0), "head": (0, -50, 0), "thigh.R": (16, 0, 0), "shin.R": (8, 0, 0),
            "thigh.L": (-18, 0, 0), "shin.L": (16, 0, 0)}
BOW_AIM = dict(BOW_SIDE, **{"upper_arm.L": (-88, 28, 30), "forearm.L": (0, 0, 0), "hand.L": (90, 30, 0),
                            "upper_arm.R": (-75, 20, 0), "forearm.R": (-70, 0, 0)})
BOW_DRAW = dict(BOW_AIM, **{"upper_arm.R": (-95, -95, 0), "forearm.R": (-135, 0, 0), "spine": (-2, 52, 0), "chest": (-4, 10, 0)})
BOW_REL = dict(BOW_AIM, **{"upper_arm.R": (-115, -60, 0), "forearm.R": (-10, 0, 0), "spine": (-6, 56, 0), "head": (-4, -50, 0)})
DEEP = {"thigh.R": (34, 0, 0), "shin.R": (40, 0, 0), "thigh.L": (-48, 0, 0), "shin.L": (52, 0, 0)}
# base funda e arco apontado para o alto enquanto puxa (o braço do arco sobe 16-20°): de longe o que se lê é o corpo
# descendo para trás, girando de lado (root) e o arco subindo; ao soltar o arco cai para a linha do alvo e o corpo salta para trás
BOW_FULL = dict(BOW_DRAW, **DEEP, **{"upper_arm.L": (-104, 28, 30), "upper_arm.R": (-97, -100, 0), "forearm.R": (-140, 0, 0),
                                    "spine": (-10, 54, 0), "chest": (-6, 10, 0), "head": (-6, -50, 0)})
BOW_STRAIN = dict(BOW_FULL, **{"upper_arm.L": (-108, 28, 30), "upper_arm.R": (-98, -106, 0), "forearm.R": (-144, 0, 0),
                               "spine": (-12, 55, 0), "chest": (-7, 11, 0)})
BOW_LOOSE = dict(BOW_REL, **DEEP, **{"upper_arm.L": (-86, 28, 30), "upper_arm.R": (-112, -70, 0), "forearm.R": (-30, 0, 0),
                                    "spine": (4, 56, 0), "chest": (2, 8, 0), "head": (0, -50, 0)})
BOW_KICK = dict(BOW_REL, **{"upper_arm.L": (-112, 28, 30), "upper_arm.R": (-118, -100, 0), "forearm.R": (-4, 0, 0),
                            "spine": (-12, 58, 0), "chest": (-6, 12, 0), "head": (-8, -50, 0),
                            "thigh.R": (20, 0, 0), "shin.R": (14, 0, 0), "thigh.L": (-30, 0, 0), "shin.L": (20, 0, 0)})
BOW_REST = dict(BOW_REL, **{"upper_arm.L": (-84, 28, 30), "upper_arm.R": (-100, -70, 0), "forearm.R": (-24, 0, 0), "spine": (-4, 52, 0)})

# --- pistola (mão ESQUERDA): os ângulos do atk_pistol do kit (cano alinhado com o braço esticado) ---
P_AIM = dict(R, **{"upper_arm.L": (-110, -35, 45), "forearm.L": (-6, 0, 0), "hand.L": (45, 45, -15),
                   "upper_arm.R": (30, 0, 20), "forearm.R": (-30, 0, 0), "spine": (4, -24, 0), "chest": (2, -10, 0), "head": (0, 20, 0),
                   "thigh.L": (-26, 0, 0), "shin.L": (22, 0, 0), "thigh.R": (16, 0, 0), "shin.R": (10, 0, 0)})
P_KICK = dict(P_AIM, **{"upper_arm.L": (-124, -35, 45), "forearm.L": (-16, 0, 0), "hand.L": (36, 45, -15),
                        "spine": (-2, -22, 0), "chest": (-3, -9, 0), "head": (-5, 19, 0)})
P_BACK = {"upper_arm.L": (-25, 0, -18), "forearm.L": (-105, 0, 0), "hand.L": (20, 0, 0)}         # pistola recolhida, cano para cima
P_STANCE_R = {"thigh.R": (-26, 0, 0), "shin.R": (22, 0, 0), "thigh.L": (16, 0, 0), "shin.L": (10, 0, 0)}
P_LOW = {"thigh.L": (-38, 0, 0), "shin.L": (44, 0, 0), "thigh.R": (8, 0, 0), "shin.R": (34, 0, 0)}
P_UP = {"upper_arm.L": (-62, -30, 24), "forearm.L": (-118, 0, 0), "hand.L": (30, 30, -10)}         # floreio: cano para o alto, junto ao ombro


def fan(f, root, kick, hips):
    p = dict(P_KICK if kick else P_AIM, **P_LOW)
    p["root"] = (0, root, 0)
    sp, ch = p["spine"], p["chest"]
    p["spine"], p["chest"] = (sp[0] + 4, sp[1], 0), (ch[0], ch[1], 0)
    return K(f, raw=p, hips=hips)


UP = (0, -0.04, 1)
# clipe -> (arma da direita, quadro final, [chaves])
CLIPS = {
    # Grito de guerra de ALIADO (vs `shout`, de ameaça): toma fôlego encolhido e ergue a arma como estandarte, peito para fora,
    # na ponta dos pés; a arma acena duas vezes e o braço livre chama o grupo para a frente.
    "shout_rally": ("any", 22, [
        K(1, raw=R),
        K(4, T((16, -14), (4, -4), (8, 8)), (0, -0.08, 0), A("s", (-0.02, -0.1, -0.3), az(25, 30)), A("s", (-0.12, -0.2, -0.12)), legs=SINK),
        K(7, T((-8, 10), (-6, 4), (-10, -6)), (0, 0.06, 0.02), A("sw", (-0.05, -0.02, 0.36), UP), A("sw", (0.2, 0.12, -0.22)), legs=TIPTOE),
        K(9, T((-8, 2), (-6, 0), (-10, -2)), (0, 0.07, 0.02), A("sw", (-0.1, -0.02, 0.35), (-0.36, -0.04, 1)), A("sw", (0.22, 0.04, -0.2)), legs=TIPTOE),
        K(11, T((-6, 14), (-6, 6), (-10, -8)), (0, 0.05, 0.03), A("sw", (0.0, -0.03, 0.36), (0.34, -0.06, 1)), A("sw", (0.08, -0.3, 0.02)), legs=TIPTOE),
        K(14, T((-4, 6), (-4, 2), (-8, -4)), (0, 0.02, 0.03), A("sw", (-0.05, -0.03, 0.35), (-0.08, -0.06, 1)), A("sw", (0.1, -0.3, -0.02)), legs=WIDE),
        K(18, blend=0.6, hips=(0, 0.0, 0.01)),
        K(22, raw=R),
    ]),
    # Chamado (Druida, Ranger): mão em concha na boca (assobio), o corpo recua tomando ar, e o braço da arma é lançado para
    # o alto e para a frente (o "vem!"), com passo à frente; o braço abana chamando.
    "summon_call": ("staff", 22, [
        K(1, raw=R),
        K(3, T((0, 10), (-2, 4), (-6, -6)), (0, 0.02, -0.02), A("sw", (-0.08, 0.06, -0.3), (0, 0.15, 1)), A("sw", (-0.05, -0.2, 0.1)), legs=WIDE),
        K(5, T((-8, 16), (-6, 6), (-10, -8)), (0, 0.04, -0.04), A("sw", (-0.1, 0.16, -0.27), (0, 0.3, 0.95)), A("sw", (-0.04, -0.25, 0.2)), legs=WIDE),
        K(7, T((-9, 18), (-5, 6), (-12, -8)), (0, 0.055, -0.045), A("sw", (-0.1, 0.17, -0.26), (0, 0.34, 0.94)), A("sw", (-0.04, -0.25, 0.21)), legs=TIPTOE),
        K(9, T((12, -14), (2, -6), (-8, 8)), (0, -0.04, 0.09), A("sw", (-0.04, -0.22, 0.28), az(0, 50)), A("sw", (0.22, -0.02, -0.2)), legs=LUNGE),
        K(11, T((10, -20), (2, -8), (-8, 12)), (0, -0.02, 0.1), A("sw", (-0.1, -0.16, 0.31), az(-25, 66)), A("sw", (0.2, 0.06, -0.22)), legs=LUNGE),
        K(13, T((12, -10), (2, -4), (-8, 6)), (0, -0.04, 0.1), A("sw", (-0.02, -0.25, 0.25), az(12, 44)), A("sw", (0.22, 0.0, -0.2)), legs=LUNGE),
        K(15, T((10, -14), (2, -6), (-8, 8)), (0, -0.03, 0.09), A("sw", (-0.06, -0.2, 0.29), az(-10, 58)), A("sw", (0.2, 0.04, -0.22)), legs=LUNGE),
        K(18, blend=0.6, hips=(0, -0.01, 0.03)),
        K(22, raw=R),
    ]),
    # Erguer dos mortos (Necromancer): ergue a mão livre, CRAVA a palma para baixo agachando (a foice de pé ao lado) e puxa
    # devagar do chão para o alto, com esforço; no impacto a mão passa do ombro e o corpo se abre para trás com a foice erguida.
    "summon_rise": ("scythe", 26, [
        K(1, raw=R),
        K(4, T((-8, 0), (-4, 0), (-8, 0)), (0, 0.04, -0.02), A("s", (-0.1, -0.08, -0.27), (0, 0, 1)), A("sw", (0.06, -0.14, 0.33)), legs=WIDE),
        K(7, T((22, 6), (6, 2), (10, -4)), (0, -0.17, 0.03), A("sw", (-0.12, -0.14, -0.2), (0, 0.04, 1)), A("w", (0.13, -0.36, 0.2)), feet=(FR, FL)),
        K(9, T((14, 3), (4, -2), (6, -2)), (0, -0.11, 0.02), A("sw", (-0.12, -0.13, -0.2), (0, 0.03, 1)), A("w", (0.14, -0.38, 0.5)), feet=(FR, FL)),
        K(11, T((2, -4), (-2, -2), (-6, 4)), (0, -0.02, 0.0), A("sw", (-0.13, -0.1, -0.16), (-0.05, 0, 1)), A("sw", (0.06, -0.3, 0.12)), feet=(FR, FL)),
        K(14, T((-10, 4), (-8, 2), (-12, -2)), (0, 0.06, -0.02), A("sw", (-0.16, -0.02, 0.12), (-0.18, 0, 1)), A("sw", (0.1, -0.08, 0.34)), legs=TIPTOE),
        K(17, T((-8, 8), (-8, 2), (-12, -4)), (0, 0.05, -0.02), A("sw", (-0.17, -0.02, 0.11), (-0.26, 0, 1)), A("sw", (0.12, -0.06, 0.34)), legs=TIPTOE),
        K(21, blend=0.6, hips=(0, 0.01, 0)),
        K(26, raw=R),
    ]),
    # Maldição (Necromancer): a foice risca o sinal no ar (sobe cruzada, desce), a mão livre em GARRA dispara para o alvo com
    # o bote (impacto) e arranca para trás, puxando para si; o corpo vai para o pé de trás com a foice subindo.
    "cast_curse": ("scythe", 22, [
        K(1, raw=R),
        K(3, T((0, -10), (0, -4), (-4, 6)), (0, 0.02, -0.02), A("sw", (0.0, -0.22, 0.2), az(-38, 52)), A("s", (-0.1, -0.2, -0.1)), legs=WIDE),
        K(5, T((6, 14), (2, 6), (-2, -8)), (0, -0.02, 0.0), A("sw", (-0.12, -0.26, -0.02), az(42, 12)), A("sw", (0.08, 0.1, -0.26)), legs=WIDE),
        K(8, T((16, -22), (6, -10), (0, 20)), (0, -0.06, 0.1), A("sw", (-0.1, 0.14, -0.22), az(150, 24)), A("sw", (-0.08, -0.34, 0.03)), legs=LUNGE_L),
        K(10, T((17, -26), (6, -10), (2, 22)), (0, -0.07, 0.11), A("sw", (-0.1, 0.15, -0.21), az(154, 28)), A("sw", (-0.09, -0.34, 0.01)), legs=LUNGE_L),
        K(13, T((-10, 16), (-4, 8), (-8, -10)), (0, 0.0, -0.06), A("sw", (-0.1, -0.12, 0.27), az(8, 72)), A("s", (-0.08, -0.12, -0.1)),
          legs={"thigh.R": (10, 0, 0), "shin.R": (30, 0, 0), "thigh.L": (-30, 0, 0), "shin.L": (20, 0, 0)}),
        K(16, T((-8, 20), (-4, 8), (-8, -12)), (0, 0.01, -0.07), A("sw", (-0.11, -0.1, 0.28), az(0, 76)), A("s", (-0.07, -0.1, -0.11)),
          legs={"thigh.R": (12, 0, 0), "shin.R": (32, 0, 0), "thigh.L": (-28, 0, 0), "shin.L": (18, 0, 0)}),
        K(19, blend=0.6, hips=(0, 0, -0.02)),
        K(22, raw=R),
    ]),
    # Vento (vs gelo, que varre de lado a lado): recolhe baixo torcido e gira o corpo todo uma volta, braços abertos subindo
    # em espiral (pulinho); ao fechar a volta as duas mãos empurram a rajada para a frente (impacto) e abrem para o alto.
    "cast_wind": ("staff", 22, [
        K(1, raw=R),
        K(4, T((10, -28), (2, -12), (0, 14), root=-25), (0, -0.1, -0.02), A("sw", (-0.12, 0.14, -0.26), az(125, 5)), A("s", (-0.2, -0.2, -0.12)), legs=SINK),
        K(6, T((4, -6), (0, -2), (-4, 4), root=100), (0, -0.02, 0), A("sw", (-0.34, 0.0, -0.02), az(88, 12)), A("sw", (0.34, 0.0, 0.0)), legs=WIDE),
        K(8, T((0, 6), (-2, 2), (-6, -2), root=250), (0, 0.05, 0.02), A("sw", (-0.3, -0.02, 0.16), az(80, 38)), A("sw", (0.3, -0.02, 0.16)), legs=TIPTOE),
        K(9, T((14, 14), (4, 6), (-2, -10), root=335), (0, -0.04, 0.1), A("sw", (0.0, -0.33, 0.06), az(-8, 28)), A("sw", (0.0, -0.33, 0.04)), legs=LUNGE),
        K(11, T((6, 22), (0, 10), (-6, -12), root=360), (0, 0.0, 0.11), A("sw", (-0.16, -0.22, 0.22), az(18, 58)), A("sw", (0.18, -0.2, 0.22)), legs=LUNGE),
        K(14, T((8, 16), (2, 6), (-4, -8), root=360), (0, -0.03, 0.09), A("sw", (-0.2, -0.2, 0.12), az(24, 48)), A("sw", (0.22, -0.18, 0.1)), legs=LUNGE),
        K(18, blend=0.6, hips=(0, -0.01, 0.03)),
        K(22, raw=dict(R, root=(0, 360, 0))),
    ]),
    # Cura da natureza (Druida): ajoelha com o cajado fincado ao lado e a mão livre no chão (impacto), aperta, e sobe abrindo
    # a mão do chão até o alto (o broto cresce), na ponta dos pés, cabeça erguida.
    "cast_heal_nature": ("staff", 24, [
        K(1, raw=R),
        K(3, T((-4, 0), (-2, 0), (-6, 0)), (0, 0.03, -0.01), A("sw", (-0.12, -0.1, -0.2), (0, -0.1, 1)), A("sw", (0.16, -0.1, -0.2)), legs=WIDE),
        K(6, T((16, -4), (4, -2), (4, 2)), (0, -0.11, 0.03), A("sw", (-0.1, -0.2, -0.14), (0, -0.04, 1)), A("sw", (0.08, -0.26, -0.18)),
          feet=((-0.11, 0.1, 0.08, 0.07), (0.12, -0.14, 0.07))),
        K(8, T((22, -6), (6, -2), (8, 4)), (0, -0.19, 0.04), A("sw", (-0.1, -0.24, -0.1), (0, 0, 1)), A("w", (0.15, -0.38, 0.12)),
          feet=((-0.11, 0.2, 0.09, 0.08), (0.12, -0.16, 0.07))),
        K(10, T((24, -6), (6, -2), (10, 4)), (0, -0.2, 0.04), A("sw", (-0.1, -0.24, -0.11), (0, 0.02, 1)), A("w", (0.15, -0.38, 0.11)),
          feet=((-0.11, 0.2, 0.09, 0.08), (0.12, -0.16, 0.07))),
        K(12, T((6, 0), (0, 0), (-4, 0)), (0, -0.07, 0.02), A("sw", (-0.13, -0.16, 0.0), (-0.04, -0.04, 1)), A("sw", (0.12, -0.3, 0.0)),
          feet=((-0.11, 0.08, 0.08, 0.06), (0.12, -0.12, 0.07))),
        K(14, T((-10, 6), (-8, 2), (-12, -4)), (0, 0.06, 0.0), A("sw", (-0.16, -0.06, 0.22), (-0.12, -0.05, 1)), A("sw", (0.16, -0.06, 0.33)), legs=TIPTOE),
        K(17, T((-8, -2), (-8, 0), (-12, 2)), (0, 0.05, 0.0), A("sw", (-0.17, -0.05, 0.21), (-0.2, -0.05, 1)), A("sw", (0.19, -0.04, 0.32)), legs=TIPTOE),
        K(20, blend=0.6, hips=(0, 0.01, 0)),
        K(24, raw=R),
    ]),
    # Tiro carregado: mira, puxa até o fim com a base funda, SEGURA tremendo (o corpo arqueia para trás) e solta (impacto):
    # o braço da corda voa para trás e o do arco chuta para cima.
    "atk_bow_charge": ("any", 24, [
        K(1, raw=R),
        K(3, raw=ck._blend(R, BOW_AIM, 0.7), hips=(0, -0.02, 0)),
        K(5, raw=dict(BOW_AIM, root=(0, 16, 0)), hips=(0, -0.03, 0)),
        K(8, raw=dict(BOW_FULL, root=(0, 40, 0)), hips=(0, -0.13, -0.1)),
        K(10, raw=dict(BOW_STRAIN, root=(0, 46, 0)), hips=(0, -0.15, -0.13)),
        K(11, raw=dict(BOW_FULL, root=(0, 44, 0)), hips=(0, -0.14, -0.12)),
        K(12, raw=dict(BOW_LOOSE, root=(0, 34, 0)), hips=(0, -0.1, -0.05)),
        K(14, raw=dict(BOW_KICK, root=(0, 44, 0)), hips=(0, 0.03, -0.16)),
        K(17, raw=dict(BOW_REST, root=(0, 24, 0)), hips=(0, -0.03, -0.09)),
        K(20, blend=0.6, hips=(0, -0.01, -0.02)),
        K(24, raw=R),
    ]),
    # Par de tiros: pistola (esquerda) atira, o tronco troca de ombro e a mão direita dispara a segunda batida apontando a
    # arma dela para o alvo, e a pistola volta para o terceiro tiro. (O kit tem UMA pistola: a batida da direita aponta o sabre.)
    "atk_pistol_pair": ("sword", 20, [
        K(1, raw=R),
        K(3, raw=ck._blend(R, P_AIM, 0.8)),
        K(5, raw=P_AIM, hips=(0, -0.02, 0.02)),
        K(6, raw=P_KICK, hips=(0, -0.01, -0.04)),
        K(8, T((4, 22), (2, 10), (0, -20)), (0, -0.02, 0.04), A("sw", (0.05, -0.34, 0.02), az(0, 4)), P_BACK, legs=P_STANCE_R),
        K(10, T((-2, 20), (-3, 9), (-5, -19)), (0, -0.01, -0.03), A("sw", (0.05, -0.32, 0.08), az(0, 26)), P_BACK, legs=P_STANCE_R),
        K(12, raw=P_AIM, hips=(0, -0.02, 0.03)),
        K(13, raw=P_KICK, hips=(0, -0.01, -0.04)),
        K(15, raw=dict(P_KICK, **{"upper_arm.L": (-118, -35, 45), "hand.L": (40, 45, -15)}), hips=(0, -0.01, -0.03)),
        K(17, blend=0.5),
        K(20, raw=R),
    ]),
    # Leque de tiros: base baixa, a pistola varre o arco da direita para a esquerda dando quatro coices, e fecha com o cano
    # para o alto junto ao ombro (floreio).
    "atk_pistol_fan": ("sword", 22, [
        K(1, raw=R),
        K(3, raw=dict(ck._blend(R, dict(P_AIM, **P_LOW), 0.8), root=(0, -22, 0)), hips=(0, -0.03, 0)),
        fan(5, -30, False, (0, -0.07, 0.02)),
        fan(6, -30, True, (0, -0.06, -0.03)),
        fan(7, -12, False, (0, -0.07, 0.01)),
        fan(8, -10, True, (0, -0.06, -0.03)),
        fan(9, 8, False, (0, -0.07, 0.01)),
        fan(10, 10, True, (0, -0.06, -0.03)),
        fan(11, 28, False, (0, -0.07, 0.01)),
        fan(12, 30, True, (0, -0.06, -0.04)),
        K(15, raw=dict(R, **P_UP, **{"root": (0, 12, 0), "spine": (-4, -10, 0), "chest": (-4, -4, 0), "head": (-8, 8, 0),
                                    "upper_arm.R": (20, 0, 24), "forearm.R": (-30, 0, 0)}), hips=(0, 0.02, -0.02)),
        K(18, raw=dict(R, **P_UP, **{"root": (0, 4, 0), "spine": (-2, -6, 0), "chest": (-3, -2, 0), "head": (-6, 4, 0),
                                    "upper_arm.R": (16, 0, 20), "forearm.R": (-32, 0, 0)}), hips=(0, 0.01, -0.01)),
        K(22, raw=R),
    ]),
    # Ceifada: a foice vai para trás à direita com o corpo torcido, passo à frente, e varre BAIXO da direita para a esquerda
    # passando da frente (impacto) até atrás do outro lado, com o corpo todo girando junto; as duas mãos no cabo.
    "atk_scythe_reap": ("scythe", 24, [
        K(1, raw=R),
        K(3, T((0, -24), (0, -10), (-2, 12), root=-15), (0, 0.01, -0.03), A("s", (0.1, -0.2, -0.05), az(128, 32)), A("w", (0, 0, 0), grip=-0.14),
          feet=(FR, FL)),
        K(5, T((4, -28), (0, -12), (0, 14), root=-35), (0, -0.06, -0.06), A("s", (0.06, -0.16, -0.1), az(150, 12)), A("w", (0, 0, 0), grip=-0.14),
          feet=((-0.12, 0.0, 0.07), (0.12, -0.1, 0.11, 0.07))),
        K(7, T((14, -6), (4, -2), (0, 2), root=5), (0, -0.12, 0.06), A("s", (0.12, -0.24, -0.2), az(72, -14), lead=az(-18, 0)), A("w", (0, 0, 0), grip=-0.14),
          feet=((-0.12, 0.02, 0.07), (0.13, -0.26, 0.07))),
        K(8, T((18, 16), (6, 6), (0, -10), root=30), (0, -0.14, 0.12), A("s", (0.17, -0.26, -0.22), az(6, -18), lead=az(-84, 0)), A("w", (0, 0, 0), grip=-0.14),
          feet=((-0.12, 0.06, 0.08, 0.07), (0.13, -0.26, 0.07))),
        K(10, T((16, 28), (6, 12), (0, -14), root=80), (0, -0.13, 0.13), A("s", (0.22, -0.24, -0.2), az(-72, -8), lead=az(-162, 0)), A("w", (0, 0, 0), grip=-0.14),
          feet=((-0.12, 0.08, 0.09, 0.08), (0.13, -0.26, 0.07))),
        K(12, T((12, 28), (4, 12), (-2, -14), root=110), (0, -0.1, 0.12), A("s", (0.24, -0.2, -0.14), az(-128, 4)), A("w", (0, 0, 0), grip=-0.14),
          feet=((-0.12, 0.08, 0.09, 0.08), (0.13, -0.26, 0.07))),
        K(15, T((10, 24), (4, 10), (-2, -12), root=100), (0, -0.07, 0.1), A("s", (0.24, -0.2, -0.12), az(-120, 14)), A("w", (0, 0, 0), grip=-0.14),
          feet=((-0.12, 0.06, 0.08, 0.06), (0.13, -0.22, 0.07))),
        K(19, blend=0.62, hips=(0, -0.02, 0.03)),
        K(24, raw=R),
    ]),
}
# o que cada clipe mostra na folha de revisão (malhas do kit: principal, secundária)
SHOW = {"shout_rally": ("sword", None), "summon_call": ("staff", None), "summon_rise": ("scythe", None), "cast_curse": ("scythe", None),
        "cast_wind": ("staff", None), "cast_heal_nature": ("staff", None), "atk_bow_charge": ("bow", None),
        "atk_pistol_pair": ("sword", "pistol"), "atk_pistol_fan": ("sword", "pistol"), "atk_scythe_reap": ("scythe", None)}
SEEDS_R = [(-30, 10, 0), ck.ARM_V["upper_arm.R"], ck.ARM_FRONT["upper_arm.R"], ck.ARM_SIDE["upper_arm.R"], ck.ARM_CHEST["upper_arm.R"],
           ck.ARM_LOW_FRONT_R["upper_arm.R"], ck.ARM_BACK_HIGH_R["upper_arm.R"], ck.ARM_SIDE_LOW_R["upper_arm.R"], (-90, 60, 0), (-150, 0, 0)]
HAND_SEEDS = [(60, 0, -30), ck.ARM_V["hand.R"], ck.ARM_FRONT["hand.R"], ck.ARM_SIDE["hand.R"], ck.ARM_LOW_FRONT_R["hand.R"],
              ck.ARM_BACK_HIGH_R["hand.R"], ck.ARM_SIDE_LOW_R["hand.R"], (0, 0, 0), (90, 90, -60)]
TRUNK = ("root", "hips", "spine", "chest", "neck", "head")


def setup(sex):
    ck.clear()
    base = ck.build_base("base", sex, 0.0, ck.KIT_HAIR, "hair")
    B = base["rig"].data.bones
    S = {"B": B, "REST": {b.name: b.matrix_local.copy() for b in B}, "PAR": {b.name: (b.parent.name if b.parent else None) for b in B},
         "ORDER": [b.name for b in B], "g.R": ck.hand_center(base, ".R"), "g.L": ck.hand_center(base, ".L"), "base": base}
    S["RINV"] = {k: m.inverted() for k, m in S["REST"].items()}
    return S


def fk(S, pose, hips, only=None):
    M = {}
    REST, RINV, PAR = S["REST"], S["RINV"], S["PAR"]
    for n in S["ORDER"]:
        if only and n not in only:
            continue
        r = pose.get(n, (0, 0, 0))
        Lm = Euler([math.radians(a) for a in r], "XYZ").to_matrix().to_4x4()
        if n == "hips":
            Lm = Matrix.Translation(hips) @ Lm
        p = PAR[n]
        M[n] = (REST[n] @ Lm) if p is None else (M[p] @ RINV[p] @ REST[n] @ Lm)
    return M


def climb(ev, v, step=16.0, lo=0.4):
    v = list(v)
    c = ev(v)
    while step > lo:
        imp = False
        for i in range(len(v)):
            for d in (-step, step):
                w = list(v)
                w[i] += d
                cw = ev(w)
                if cw < c - 1e-8:
                    v, c, imp = w, cw, True
        if not imp:
            step *= 0.5
    return c, v


def seg_dist(a, b, p):
    ab = b - a
    t = max(0.0, min(1.0, (p - a).dot(ab) / ab.length_squared))
    return (a + ab * t - p).length


def near(prev, e):
    """A mesma rotação XYZ escrita perto de `prev` (voltas de 360° e o outro ramo de Euler): a interpolação não dá a volta."""
    best = None
    for cand in (tuple(e), (e[0] + 180, 180 - e[1], e[2] + 180)):
        c = tuple(x + 360.0 * round((p - x) / 360.0) for x, p in zip(cand, prev))
        d = sum(abs(a - b) for a, b in zip(c, prev))
        if best is None or d < best[0]:
            best = (d, c)
    return best[1]


def target(S, M, side, spec):
    sh = S["B"]["upper_arm" + side].head_local
    if spec["space"] == "w":
        return (M["root"] @ S["RINV"]["root"]) @ spec["pos"]
    if spec["space"] == "s":
        return (M["chest"] @ S["RINV"]["chest"]) @ (sh + spec["pos"])
    return (M["chest"] @ S["RINV"]["chest"]) @ sh + (M["root"] @ S["RINV"]["root"]).to_3x3() @ spec["pos"]


def solve_arm(S, pose, hips, side, spec, seed, axis, reach, weapon=None):
    """Resolve upper_arm/forearm (+ hand.R quando há direção de arma). Devolve (variáveis, info)."""
    chain = TRUNK + ("upper_arm" + side, "forearm" + side, "hand" + side)
    M0 = fk(S, pose, hips, TRUNK)
    rootR = (M0["root"] @ S["RINV"]["root"]).to_3x3()
    if spec["grip"] is not None and weapon is not None:
        tpos = weapon[0] + weapon[1] * spec["grip"]
    else:
        tpos = target(S, M0, side, spec)
    head_c = (M0["head"] @ S["RINV"]["head"]) @ HEAD_C
    tdir = None if spec["dir"] is None else (rootR @ spec["dir"]).normalized()
    lead = None if spec["lead"] is None else (rootR @ spec["lead"]).normalized()
    sx = 1.0 if side == ".L" else -1.0
    hint = rootR @ (Vector(spec["elbow"]) if spec["elbow"] else Vector((sx * 0.6, 0.35, -1.0))).normalized()
    lo, hi = spec["bend"]
    g0 = S["g" + side]
    use_hand = side == ".R" and tdir is not None
    n = 7 if use_hand else 4

    def parts(v):
        p = dict(pose)
        p["upper_arm" + side], p["forearm" + side] = tuple(v[0:3]), (v[3], 0, 0)
        if use_hand:
            p["hand" + side] = tuple(v[4:7])
        Mg = fk(S, p, hips, chain)
        D = Mg["hand" + side] @ S["RINV"]["hand" + side]
        return Mg, D @ g0, D.to_3x3()

    def raw(v):
        Mg, g, R3 = parts(v)
        c = 40 * (g - tpos).length_squared + (0 if lo <= v[3] <= hi else 1 + 0.01 * min(abs(v[3] - lo), abs(v[3] - hi)))
        c += 8 * max(0.0, HEAD_R - 0.04 - (g - head_c).length) ** 2
        if use_hand:
            u = R3 @ axis
            c += 2.5 * (1 - u.dot(tdir))
            c += 6 * max(0.0, HEAD_R - seg_dist(g, g + u * reach, head_c)) ** 2
            if lead is not None:
                c += 0.25 * (1 - (R3 @ BLADE).dot(lead))
        sh_p, el = Mg["upper_arm" + side].to_translation(), Mg["forearm" + side].to_translation()
        mid = (sh_p + g) * 0.5
        d = el - mid
        if d.length > 1e-4:
            c += 0.01 * (1 - d.normalized().dot(hint))
        return c

    def ev(v):
        return raw(v) + 2e-6 * sum((a - b) ** 2 for a, b in zip(v, seed))

    c, v = climb(ev, list(seed[:n]))
    best = (raw(v), v)
    Mg, g, R3 = parts(v)
    bad = (g - tpos).length > 0.02 or (use_hand and math.degrees(math.acos(max(-1, min(1, (R3 @ axis).dot(tdir))))) > 8)
    if bad:
        seeds = [tuple(s) if side == ".R" else (s[0], -s[1], -s[2]) for s in SEEDS_R]
        for s in seeds:
            for hs in (HAND_SEEDS if use_hand else [None]):
                st = list(s) + [-30.0] + (list(hs) if use_hand else [])
                c2, v2 = climb(raw, st)
                if c2 < best[0] - 1e-4:
                    best = (c2, v2)
                if not use_hand:
                    break
        v = best[1]
    v = list(near(seed[0:3], v[0:3])) + [v[3]] + list(v[4:])
    v = [round(x, 1) for x in v]
    Mg, g, R3 = parts(v)
    info = {"pos": (g - tpos).length, "g": g, "u": (R3 @ axis) if side == ".R" else None,
            "dir": math.degrees(math.acos(max(-1, min(1, (R3 @ axis).dot(tdir))))) if use_hand else 0.0,
            "head": (g - head_c).length}
    return v, info


def solve_legs(S, pose, hips, feet):
    B = S["B"]
    M0 = fk(S, pose, hips, ("root",))
    Rm = M0["root"] @ S["RINV"]["root"]
    errs = []
    for side, tgt in (("R", feet[0]), ("L", feet[1])):
        tv = Rm @ Vector(tgt[0:3])
        chain = ("root", "hips", "thigh." + side, "shin." + side, "foot." + side)

        def ev_leg(v):
            p = dict(pose)
            p["thigh." + side], p["shin." + side] = (v[0], 0, v[1]), (v[2], 0, 0)
            Mg = fk(S, p, hips, chain)
            a = (Mg["foot." + side] @ S["RINV"]["foot." + side]) @ B["foot." + side].head_local
            return (a - tv).length_squared + (0 if v[2] >= 0 else 1.0) + 1e-7 * v[2]
        best = None
        for tx in range(-100, 61, 20):
            for tz in range(-40, 41, 20):
                for sx in range(0, 131, 26):
                    c = ev_leg((tx, tz, sx))
                    if best is None or c < best[0]:
                        best = (c, [tx, tz, sx])
        c, v = climb(ev_leg, best[1], 10.0, 0.2)
        pose["thigh." + side], pose["shin." + side] = (round(v[0], 1), 0, round(v[1], 1)), (round(v[2], 1), 0, 0)
        want = tgt[3] if len(tgt) > 3 else 0.04
        bestf = None
        for fx in range(-90, 61, 2):
            p = dict(pose)
            p["foot." + side] = (fx, 0, 0)
            Mg = fk(S, p, hips, chain)
            D = Mg["foot." + side] @ S["RINV"]["foot." + side]
            h, t = D @ B["foot." + side].head_local, D @ B["foot." + side].tail_local
            e = abs((h.z - t.z) - want)
            if bestf is None or e < bestf[0]:
                bestf = (e, fx)
        pose["foot." + side] = (bestf[1], 0, 0)
        errs.append(math.sqrt(max(c, 0.0)))
    return errs


def solve_clip(S, clip, wkey, keys):
    axis, reach = AXES[wkey]
    out = []
    seed_r = [-30, 10, 0, -35, 60, 0, -30]
    seed_l = [-12, 0, -14, -40]
    prev = dict(R)
    for k in keys:
        if k["blend"] is not None:
            pose = ck._blend(prev, R, k["blend"])
            out.append((k["f"], pose, k["hips"]))
            continue
        pose = dict(R)
        if k["raw"]:
            pose.update(k["raw"])
        if k["trunk"]:
            pose.update(k["trunk"])
        if k["legs"]:
            for b in ("foot.R", "foot.L"):
                pose[b] = (0, 0, 0)
            pose.update(k["legs"])
        if k["extra"]:
            pose.update(k["extra"])
        pose = ck._tame(pose, R)
        hips = k["hips"]
        line = "%-17s f%-2d" % (clip, k["f"])
        if k["feet"]:
            e = solve_legs(S, pose, hips, k["feet"])
            line += " pes=%.3f/%.3f" % tuple(e)
        weapon = None
        spec = k["R"]
        if isinstance(spec, dict) and "space" in spec:
            if spec["dir"] is None:
                spec = dict(spec, dir=Vector((0, -0.2, 1)).normalized())
            v, info = solve_arm(S, pose, hips, ".R", spec, seed_r, axis, reach)
            pose["upper_arm.R"], pose["forearm.R"], pose["hand.R"] = tuple(v[0:3]), (v[3], 0, 0), tuple(v[4:7])
            seed_r = v
            weapon = (info["g"], info["u"])
            line += " R: err=%.3f dir=%.0f cabeca=%.2f ponta_z=%.2f" % (info["pos"], info["dir"], info["head"], (info["g"] + info["u"] * reach).z)
        elif isinstance(spec, dict):
            pose.update(spec)
        spec = k["L"]
        if isinstance(spec, dict) and "space" in spec:
            v, info = solve_arm(S, pose, hips, ".L", spec, seed_l, axis, reach, weapon)
            pose["upper_arm.L"], pose["forearm.L"] = tuple(v[0:3]), (v[3], 0, 0)
            pose["hand.L"] = spec["hand"] if spec["hand"] else (0, 0, 0)
            seed_l = v
            line += " L: err=%.3f cabeca=%.2f" % (info["pos"], info["head"])
        elif isinstance(spec, dict):
            pose.update(spec)
        print(line)
        pose = {b: tuple(round(x, 1) for x in pose[b]) for b in ck.POSE_BONES if b in pose}
        prev = pose
        out.append((k["f"], pose, hips))
    return out


def write(data):
    lines = ['"""GERADO por archetype_clips_solve.py: poses resolvidas dos clipes de arquétipo do pacote C2. Não edite à mão."""',
             "# sexo -> clipe -> (quadro final, [(quadro, pose, quadril)])", "SOLVED = {"]
    for sex, clips in data.items():
        lines.append('    "%s": {' % sex)
        for clip, (end, out) in clips.items():
            lines.append('        "%s": (%d, [' % (clip, end))
            for f, pose, hips in out:
                body_s = ", ".join('"%s": (%s)' % (k, ", ".join("%g" % round(x, 1) for x in pose[k])) for k in ck.POSE_BONES if k in pose)
                lines.append("            (%d, {%s}, (%s))," % (f, body_s, ", ".join("%g" % x for x in hips)))
            lines.append("        ]),")
        lines.append("    },")
    lines.append("}")
    with open(os.path.join(HERE, "archetype_clips_data.py"), "w", encoding="utf-8", newline="\n") as fh:
        fh.write("\n".join(lines) + "\n")
    print("gravado archetype_clips_data.py")


# ---------------------------------------------------------------------------
# folha de revisão (sem janela): o clipe quadro a quadro em três câmeras
# ---------------------------------------------------------------------------
TW, TH = 190, 230


def shots(S, clips, out_dir, only):
    import numpy as np
    base = S["base"]
    rig = base["rig"]
    mats = ck._kit_mats()
    for t in ("sword", "staff", "scythe", "bow"):
        ck.kit_weapon(base, t, "main", mats)
    ck.kit_weapon(base, "pistol", "off", mats)
    for name, col in (("tint", (0.55, 0.75, 0.95)), ("hair", ck.KIT_HAIR)):
        m = bpy.data.materials.get(name)
        if m:
            m.diffuse_color = (*col, 1.0)
    for m in bpy.data.materials:
        try:
            bsdf = next(nd for nd in m.node_tree.nodes if nd.type == "BSDF_PRINCIPLED")
            m.diffuse_color = bsdf.inputs["Base Color"].default_value
        except Exception:
            pass
    sc = bpy.context.scene
    sc.render.engine = "BLENDER_WORKBENCH"
    sc.render.resolution_x, sc.render.resolution_y = TW, TH
    sc.render.film_transparent = False
    sh = sc.display.shading
    sh.light = "STUDIO"
    sh.color_type = "MATERIAL"
    sh.show_object_outline = True
    sh.show_cavity = True
    sc.world = sc.world or bpy.data.worlds.new("w")
    me = bpy.data.meshes.new("floor")
    me.from_pydata([(-3, -3, 0), (3, -3, 0), (3, 3, 0), (-3, 3, 0)], [], [(0, 1, 2, 3)])
    fl = bpy.data.objects.new("floor", me)
    fm = bpy.data.materials.new("floor")
    fm.diffuse_color = (0.42, 0.5, 0.4, 1)
    me.materials.append(fm)
    sc.collection.objects.link(fl)
    cam = bpy.data.objects.new("c2_cam", bpy.data.cameras.new("c2_cam"))
    sc.collection.objects.link(cam)
    cam.data.type = "ORTHO"
    cam.data.ortho_scale = 3.0
    sc.camera = cam
    rig.hide_render = True
    a = math.radians(52)
    yaw = math.radians(35)
    views = [((math.sin(yaw) * 8 * math.cos(a), -math.cos(yaw) * 8 * math.cos(a), 0.8 + 8 * math.sin(a)), (0, 0, 0.8)),     # câmera do jogo
             ((-8, -0.6, 1.6), (0, 0, 0.85)),            # lado direito (o da arma)
             ((0.5, -8, 1.6), (0, 0, 0.85))]             # frente
    os.makedirs(out_dir, exist_ok=True)
    step = int(arg("--step", "2"))
    for clip, (end, keys) in clips.items():
        if only and clip not in only:
            continue
        ck._pose_action(rig, clip, [(f, dict(p), h) for f, p, h in keys], end)
        ad = rig.animation_data
        main, off = SHOW[clip]
        for o in rig.children:
            if o.name.startswith("wpn_"):
                o.hide_render = not (o.name == "wpn_main_%s" % main or o.name == "wpn_off_%s" % off)
        if "--ground" in ARGS:
            spec = [(b, objs, m) for b, objs, m in ck.kit_weapon_pieces(rig) if any(not o.hide_render for o in objs)]
            spec = [(b, [o for o in objs if not o.hide_render], m) for b, objs, m in spec]
            print("clear_ground", clip, ck.clear_ground(rig, spec, [clip]).get(clip))
        for t in ad.nla_tracks:
            t.mute = t.name != clip
        imp = ck.C2_IMPACT.get(clip, 0)
        frames = sorted(set(list(range(1, end + 1, step)) + [imp, end]))
        rows = []
        for eye, tgt in views:
            tiles = []
            for f in frames:
                sc.frame_set(f)
                sc.world.color = (0.62, 0.56, 0.2) if f == imp else (0.33, 0.36, 0.4)
                cam.location = Vector(eye)
                cam.rotation_euler = (Vector(tgt) - Vector(eye)).to_track_quat("-Z", "Y").to_euler()
                path = os.path.join(out_dir, "_t.png")
                sc.render.filepath = path
                bpy.ops.render.render(write_still=True)
                img = bpy.data.images.load(path)
                tiles.append(np.array(img.pixels[:], dtype=np.float32).reshape(img.size[1], img.size[0], 4))
                bpy.data.images.remove(img)
            rows.append(np.concatenate(tiles, axis=1))
        sheet = np.concatenate(rows[::-1], axis=0)
        res = bpy.data.images.new("c2_sheet", sheet.shape[1], sheet.shape[0], alpha=True)
        res.pixels = sheet.ravel().tolist()
        res.filepath_raw = os.path.join(out_dir, "%s.png" % clip)
        res.file_format = "PNG"
        res.save()
        bpy.data.images.remove(res)
        print("folha", clip, "quadros", frames, "impacto", imp)
    if os.path.exists(os.path.join(out_dir, "_t.png")):
        os.remove(os.path.join(out_dir, "_t.png"))


def run():
    only = [c for c in arg("--clips").split(",") if c]
    data = {}
    S = None
    sexes = ("female", "male") if not arg("--shots") else ("male",)
    if arg("--sex"):
        sexes = (arg("--sex"),)
    for sex in sexes:
        S = setup(sex)
        data[sex] = {}
        for clip, (wkey, end, keys) in CLIPS.items():
            if only and clip not in only:
                continue
            data[sex][clip] = (end, solve_clip(S, clip, wkey, keys))
    if arg("--shots"):
        shots(S, data[sexes[-1]], arg("--shots"), only)
    if "--dry" in ARGS or only or len(sexes) < 2:
        return
    write({"male": data["male"], "female": data["female"]})


run()
