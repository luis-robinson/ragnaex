"""Brejo das Teias (field_marsh, Lv 12-16): campo opcional ao sul da Floresta Sombria (GDD design/gdd/brejo-das-teias.md).
Garganta única ao norte (volta para a Floresta), as Palafitas do Brejo no centro (amigo: deque de tábuas, duas palafitas,
fogo de cozinha, botes virados; sem muro, sem cristal), a Lagoa Turva ao sul com o Córrego Âmbar entrando pelo leste e o
canal saindo pelo sudoeste (duas pontes), e quatro lugares de caça em volta: Charco dos Sapos (oeste), Mata das Teias
(nordeste: árvores secas com véus de teia e casulos), Cais dos Contrabandistas (sudoeste) e a Ponta da Bocarra (sudeste:
arena limpa da Sapa-Mãe, cercada de taboas). A boca do Viveiro de Seiva (leste) fica RESERVADA: arco de raízes, fechada,
em `future_portals`. Marco: o Cipreste Enforcado (noroeste), seco e coberto de teia.

    blender -b --factory-startup --python tools/blender/zones/run_zone.py -- build_field_marsh <pasta_png> --export
    MARSH_CAM=charco|mata|cais|viveiro|chegada|cipreste  (só a foto de revisão CAM_game; padrão = as Palafitas)
"""
import math
import os
import random
import importlib
import nature
import places
import zone_lib
importlib.reload(zone_lib)
from zone_lib import Zone, Vector
from dress import Dress

ZONE = "field_marsh"
SIZE = 220.0
RIM = (99.0, 4.0, 2.5, 1.5)        # raio útil 91-107 m: a regra de borda do _check_zone_layout só conta acerto em r > 95
SEED = 29                          # com esta semente a garganta norte cai em (-8.1, -92.6) / chegada (-7.4, -84.7)
GROUND = (0.30, 0.38, 0.27)        # = MapDef.ground_color e loading_art.ZONES["field_marsh"]["ground"] (verde-oliva escuro)
GORGE_ANG = -95.0                  # garganta da Floresta (norte)
FOREST_ARRIVE = (-18.2, 103.5)     # chegada na Floresta, junto da garganta sul (build_field_forest: polar(100, 15))
HUB = (0.0, 0.0)                   # Palafitas do Brejo
DECK_R = 12.0
EXITS = {"N": -100.0, "L": -15.0, "SE": 38.0, "S": 110.0, "O": 190.0}      # por onde as estradas saem do deque (graus do jogo)
CHARCO = (-70.0, -14.0)            # Charco dos Sapos
CHARCO_LAKE = ((-72.0, -18.0), 9.0)
MATA = (56.0, -46.0)               # Mata das Teias
MATA_R = 18.0
MATA_TREES = [(8.0, 10.0), (8.0, 200.0), (8.0, 270.0), (8.0, 330.0),                       # (raio, ângulo): ruas de >= 4 m entre os troncos
              (14.5, 20.0), (14.5, 175.0), (14.5, 205.0), (14.5, 240.0), (14.5, 280.0), (14.5, 335.0)]
CAIS = (-44.5, 69.5)               # Cais dos Contrabandistas (lugar `camp`; o pedido era (-40, 66): em cima da ponta das estradas)
PONTA = (44.0, 72.0)               # Ponta da Bocarra (arena da Sapa-Mãe)
PONTA_R = 15.0
LAGOA = ((8.0, 48.0), 16.0)        # Lagoa Turva
CIPRESTE = (-34.0, -36.0)          # Cipreste Enforcado (marco)
PIER = (-18.0, 73.0)               # píer dos contrabandistas no canal de saída
GATHER = [(-66.0, -24.0), (48.0, -36.0), (-30.0, 40.0)]       # MapsCatalog.GATHER["field_marsh"]: sem sólido a < 9 m
CREEK = [(100, 24), (72, 22), (46, 30), (24, 44)]             # Córrego Âmbar (entra na lagoa)
OUTFLOW = [(-2, 62), (-14, 68), (-26, 84), (-38, 106)]        # canal de saída (some debaixo da borda sudoeste)
RIVER_W = 4.5
AMBER = (0.95, 0.75, 0.30)         # seiva acesa: só `glow_*` em teias, casulos, barris do Cais e no arco do Viveiro
AMBER_DULL = (0.62, 0.50, 0.22)    # seiva fosca (riscos na água do córrego, pedras da margem)
AMBER_TINT = False                 # True = o córrego vira material "water" tingido (water_tints); o _check_water_tints só
                                   # aceita isso em mapas da lista dele, então fica desligado até field_marsh entrar lá
TREE_COLS = [(0.20, 0.32, 0.22), (0.25, 0.38, 0.25), (0.30, 0.42, 0.26)]
DEAD_COLS = [(0.40, 0.36, 0.30), (0.36, 0.33, 0.29), (0.44, 0.40, 0.33)]
WEB = (0.80, 0.82, 0.78)
WEB_D = (0.66, 0.69, 0.66)
PLACES = [
    {"type": "cabin", "id": "benzedeira", "pos": (-54.5, 23.0), "face": 170.0, "npc": "marsh_healer", "roof": (0.42, 0.36, 0.26)},
    {"type": "cabin", "id": "bento", "pos": (24.0, -70.0), "face": 200.0, "npc": "marsh_bento", "roof": (0.36, 0.40, 0.30)},
    {"type": "camp", "id": "cais", "pos": CAIS, "face": -45.0, "mob": "marsh_smuggler", "count": 5, "ground": (0.44, 0.38, 0.28),
     "cloth": (0.36, 0.34, 0.26)},
    {"type": "shrine", "id": "altar_afogado", "pos": (-22.0, -56.0), "npc": "marsh_altar", "ground": (0.40, 0.42, 0.38)},
    {"type": "dungeon", "id": "viveiro", "dungeon": "dg_viveiro"},
]
# (monstro, x, z, raio, quantos, respawn). Fora do pedido: a sanguessuga da lagoa saiu de (-20, 34) (39 m do centro; a regra
# pede > 40) para (-17, 44); a do Charco de (-66, -26) (a 1 m da água sólida) para (-62, -29); o bando extra do Cais de
# (-48, 74) (dentro das tendas) para (-56, 62).
SPAWNERS = [
    ("marsh_leech", -62, -29, 8, 5, 14.0), ("marsh_leech", -17, 44, 7, 4, 14.0),
    ("bog_toad", -74, -2, 8, 4, 18.0), ("bog_toad", -70, 12, 8, 3, 18.0), ("bog_toad", -6, 76, 8, 4, 18.0),
    ("marsh_spider", 56, -46, 10, 6, 16.0), ("marsh_spider", 40, -60, 8, 4, 16.0), ("marsh_spider", 74, -30, 8, 4, 16.0),
    ("web_weaver", 66, -58, 6, 3, 20.0), ("web_weaver", 32, -48, 6, 2, 20.0),
    ("marsh_smuggler", -56, 62, 6, 3, 20.0),
]
PATROL = [(-36, 62), (-24, 80), (0, 84), (-24, 80)]          # ronda de contrabandistas no arco sul


def polar(z, ang_deg, inset):
    a = math.radians(ang_deg)
    r = z.rim_r(a) - inset
    return (round(math.cos(a) * r, 1), round(math.sin(a) * r, 1))


def face_to(x, z, tx, tz):
    return round(math.degrees(math.atan2(tx - x, tz - z)), 1)


def door_rot(c, t):
    """Giro de uma peça em `t` com a frente (eixo +yb do Dress) virada para `c`."""
    return math.degrees(math.atan2(-(c[0] - t[0]), -(c[1] - t[1])))


def local(c, rot):
    """Função (lx, ly) -> ponto do jogo no referencial de uma peça do Dress em `c` com giro `rot` (ly = frente)."""
    a = math.radians(rot)
    ca, sa = math.cos(a), math.sin(a)
    return lambda lx, ly: (c[0] + lx * ca - ly * sa, c[1] - lx * sa - ly * ca)


def chain(d, p0, p1, w, h):
    """Colisor de peça comprida e fina: fila de círculos de diâmetro `w` (um `pillar` só viraria um círculo do comprimento)."""
    L = math.hypot(p1[0] - p0[0], p1[1] - p0[1])
    n = max(1, int(math.ceil(L / (w * 0.9))))
    for k in range(n + 1):
        t = k / n
        d.solid(p0[0] + (p1[0] - p0[0]) * t, p0[1] + (p1[1] - p0[1]) * t, w, w, h)


# ---------------------------------------------------------------------------------------------------------------
# peças do Brejo (todas em lote, pelo Dress)
# ---------------------------------------------------------------------------------------------------------------
def stilt_hut(d, c, rot, s=1.0, roof=(0.56, 0.5, 0.3)):
    """Palafita: casa de tábuas sobre seis estacas, teto de palha em pirâmide, rampa na frente (< 5,2 m de altura)."""
    wood = d.m("palafita_estaca", (0.36, 0.28, 0.2))
    floor = d.m("palafita_piso", (0.5, 0.4, 0.28))
    wall = d.m("palafita_parede", (0.58, 0.47, 0.32))
    wall2 = d.m("palafita_ripa", (0.46, 0.36, 0.25))
    thatch = d.m("palafita_palha_%d" % int(roof[0] * 100), roof)
    thatch2 = d.m("palafita_palha_esc_%d" % int(roof[0] * 100), tuple(k * 0.82 for k in roof))
    P = local(c, rot)
    for lx in (-2.1, 0.0, 2.1):
        for ly in (-1.55, 1.55):
            d.cyl("palafita", wood, P(lx * s, ly * s), 0.15 * s, 0.12 * s, 1.3 * s, 0.0, 5)
    d.box("palafita", floor, c, (5.2 * s, 0.16 * s, 4.2 * s), rot, 1.22 * s)
    d.box("palafita", wall, c, (4.2 * s, 2.0 * s, 3.2 * s), rot, 1.38 * s)
    for lx in (-1.4, 0.0, 1.4):                                   # ripas escuras (parede de tábuas em pé)
        d.box("palafita", wall2, P(lx * s, 0.0), (0.12 * s, 2.02 * s, 3.26 * s), rot, 1.38 * s)
    d.cyl("palafita", thatch, c, 3.75 * s, 0.3 * s, 1.75 * s, 3.3 * s, 4, rot + 45.0)
    d.cyl("palafita", thatch2, c, 3.8 * s, 3.2 * s, 0.3 * s, 3.26 * s, 4, rot + 45.0, cap=False)      # beiral escuro
    d.box("palafita", d.m("tenda_boca", (0.12, 0.1, 0.1)), P(0.0, 1.6 * s), (0.95 * s, 1.55 * s, 0.1 * s), rot, 1.38 * s)
    d.box("palafita", floor, P(0.0, 3.1 * s), (1.1 * s, 0.1 * s, 2.5 * s), rot, 0.62 * s, tilt=(-29.0, 0))      # rampa
    d.solid(c[0], c[1], 5.0 * s, 5.0 * s, 5.0 * s)


def cattail(d, c, h=1.6, n=5):
    """Taboa: tufo alto de folhas com duas espigas marrons (não colide)."""
    leaf = d.m("taboa_folha", (0.33, 0.45, 0.26))
    leaf2 = d.m("taboa_folha_b", (0.4, 0.5, 0.28))
    head = d.m("taboa_espiga", (0.36, 0.25, 0.16))
    rnd = d.rnd
    d.tuft("mini", leaf if rnd.random() < 0.6 else leaf2, c, 0.45, h, n, w=0.1)
    for _ in range(2):
        q = (c[0] + rnd.uniform(-0.3, 0.3), c[1] + rnd.uniform(-0.3, 0.3))
        hh = h * rnd.uniform(0.75, 1.0)
        d.cyl("mini", leaf, q, 0.025, 0.02, hh, 0.0, 3)
        d.cyl("mini", head, q, 0.07, 0.06, 0.34, hh - 0.1, 4)


def lily(d, c, r, y, flower=False):
    """Vitória-régia miúda: disco baixo sobre a água (às vezes com flor clara)."""
    pad = d.m("lirio_folha", (0.31, 0.46, 0.29)) if d.rnd.random() < 0.6 else d.m("lirio_folha_b", (0.37, 0.5, 0.3))
    d.cyl("mini", pad, c, r, r * 0.92, 0.02, y, 7, d.rnd.uniform(0, 50))
    if flower:
        d.cyl("mini", d.m("lirio_flor", (0.9, 0.84, 0.86)), c, 0.16, 0.0, 0.2, y + 0.02, 5)


def frog_eggs(d, c, n=7):
    """Desova: cacho de bolhas verde-claras (não colide, sem brilho)."""
    egg = d.m("ova_sapo", (0.70, 0.84, 0.64))
    egg2 = d.m("ova_sapo_b", (0.60, 0.76, 0.58))
    rnd = d.rnd
    for k in range(n):
        a, r = rnd.uniform(0, math.tau), rnd.uniform(0.0, 0.7)
        d.rock("mini", egg if k % 3 else egg2, (c[0] + math.cos(a) * r, c[1] + math.sin(a) * r), rnd.uniform(0.18, 0.32), 0.0, 0.9, sub=1)


def cocoon(d, c, s=1.0, y=0.0):
    """Casulo de teia com a cinta de seiva acesa (não colide)."""
    silk = d.m("casulo", (0.84, 0.85, 0.8))
    d.rock("casulo", silk, c, 0.68 * s, y, 1.55, sub=1)
    d.cyl("casulo", d.m("glow_seiva", AMBER), c, 0.66 * s, 0.58 * s, 0.18 * s, y + 0.8 * s, 6, cap=False)


def sap_barrel(d, c, s=1.0):
    """Barril de seiva do contrabando: aro aceso (âmbar) no meio e a tampa melada."""
    d.barrel(c, s, color=(0.42, 0.32, 0.22))
    d.cyl("carga", d.m("glow_seiva", AMBER), c, 0.43 * s, 0.43 * s, 0.09 * s, 0.62 * s, 8, cap=False)
    d.cyl("carga", d.m("seiva_fosca", AMBER_DULL), c, 0.3 * s, 0.3 * s, 0.03, 1.0 * s, 8)


def web_tree(d, c, h, rnd):
    """Véu de teia numa árvore seca (o tronco é o prop `dead_tree`): saia clara pendurada do alto e fios até o chão.
    Peça alta: malha própria (`det_alto`), o jogo a deixa translúcida na frente do boneco."""
    web, web_d = d.m("teia", WEB), d.m("teia_sombra", WEB_D)
    d.tall(c)
    d.cyl("teia", web, c, 2.5, 0.25, h * 0.42, h * 0.56, 7, rnd.uniform(0, 50), cap=False)
    d.cyl("teia", web_d, c, 1.6, 0.2, h * 0.3, h * 0.44, 6, rnd.uniform(0, 50), cap=False)
    for k in range(5):
        a = math.tau * k / 5 + rnd.uniform(-0.3, 0.3)
        r0, r1 = 2.3, rnd.uniform(2.6, 3.6)
        p0 = (c[0] + math.cos(a) * r0, h * 0.58, c[1] + math.sin(a) * r0)
        p1 = (c[0] + math.cos(a) * r1, 0.02, c[1] + math.sin(a) * r1)
        mid = ((p0[0] + p1[0]) * 0.5, h * 0.24, (p0[2] + p1[2]) * 0.5)
        d.tube("teia", web, [p0, mid, p1], 0.035, 0.02, 3)
    d.tall()


def strand(d, m, p0, p1, sag, r=0.04):
    """Fio de teia entre dois pontos altos (x, y, z), com barriga."""
    pts = []
    for i in range(5):
        t = i / 4.0
        pts.append((p0[0] + (p1[0] - p0[0]) * t, p0[1] + (p1[1] - p0[1]) * t - sag * math.sin(math.pi * t), p0[2] + (p1[2] - p0[2]) * t))
    d.tube("teia_fio", m, pts, r, r, 3)


def hanged_cypress(z, d, c, rnd):
    """Cipreste Enforcado: cipreste-do-brejo seco e cinzento, base em saia de raízes, copa de galhos nus cobertos de teia
    com casulos pendurados (marco visto de toda a zona; 22 m). Uma malha `det_alto` + os fios acesos à parte."""
    bark = d.m("cipreste_casca", (0.42, 0.39, 0.34))
    bark_d = d.m("cipreste_casca_esc", (0.33, 0.31, 0.28))
    web, web_d = d.m("teia", WEB), d.m("teia_sombra", WEB_D)
    silk = d.m("casulo", (0.84, 0.85, 0.8))
    glow = d.m("glow_seiva", AMBER)
    ends = []
    d.tall(c)
    d.cyl("cipreste", bark, c, 4.6, 2.7, 5.5, 0.0, 10, 0.0, jitter=0.1)
    d.cyl("cipreste", bark_d, c, 2.7, 1.9, 7.0, 5.5, 9, 14.0, jitter=0.06)
    d.cyl("cipreste", bark, c, 1.9, 1.1, 6.0, 12.5, 8, 30.0, tilt=(3, -2))
    d.cyl("cipreste", bark_d, c, 1.1, 0.25, 3.6, 18.4, 6, 10.0, tilt=(6, -4))          # ponta quebrada, torta
    for k in range(7):                                              # raízes em saia (joelhos do cipreste)
        a = math.tau * k / 7 + rnd.uniform(-0.15, 0.15)
        r1 = rnd.uniform(5.6, 7.4)
        d.tube("cipreste", bark_d if k % 2 else bark, [(c[0] + math.cos(a) * 2.6, 3.4, c[1] + math.sin(a) * 2.6),
                                                        (c[0] + math.cos(a) * 4.4, 1.3, c[1] + math.sin(a) * 4.4),
                                                        (c[0] + math.cos(a) * r1, 0.0, c[1] + math.sin(a) * r1)], 0.85, 0.3, 5)
        q = (c[0] + math.cos(a + 0.4) * (r1 + 0.8), c[1] + math.sin(a + 0.4) * (r1 + 0.8))
        d.cyl("cipreste", bark, q, 0.34, 0.12, rnd.uniform(0.7, 1.3), 0.0, 5)           # joelho solto
    for k in range(8):                                              # galhos nus
        a = math.tau * k / 8 + rnd.uniform(-0.2, 0.2)
        y0 = 10.5 + 1.1 * (k % 4) + rnd.uniform(-0.4, 0.4)
        L = rnd.uniform(5.5, 8.5)
        rr = 1.7 if y0 < 12.5 else 1.3
        p0 = (c[0] + math.cos(a) * rr, y0, c[1] + math.sin(a) * rr)
        p1 = (c[0] + math.cos(a) * (rr + L * 0.55), y0 + 1.5, c[1] + math.sin(a) * (rr + L * 0.55))
        p2 = (c[0] + math.cos(a + 0.18) * (rr + L), y0 + 1.0, c[1] + math.sin(a + 0.18) * (rr + L))
        d.tube("cipreste", bark_d, [p0, p1, p2], 0.5, 0.12, 5)
        b1 = (c[0] + math.cos(a - 0.5) * (rr + L * 0.9), y0 + 2.6, c[1] + math.sin(a - 0.5) * (rr + L * 0.9))
        d.tube("cipreste", bark, [p1, b1], 0.22, 0.07, 4)
        ends.append((p2, b1))
    for k, (p2, b1) in enumerate(ends):                             # lençóis de teia entre os galhos e fios pendurados
        q2 = ends[(k + 1) % len(ends)][0]
        mid = ((p2[0] + q2[0]) * 0.5, (p2[2] + q2[2]) * 0.5)
        d.rock("cipreste_teia", web if k % 2 else web_d, mid, rnd.uniform(2.6, 3.4), (p2[1] + q2[1]) * 0.5 - 1.8, 0.3, sx=1.3,
               rot=math.degrees(-math.atan2(q2[2] - p2[2], q2[0] - p2[0])), sub=1)
        strand(d, web, p2, q2, 1.6, 0.05)
        drop = rnd.uniform(3.5, 6.5)
        d.tube("cipreste_teia", web, [p2, (p2[0], p2[1] - drop, p2[2])], 0.05, 0.03, 3)
        if k % 2 == 0:                                              # os "enforcados": casulos pendurados nos fios
            d.rock("cipreste_teia", silk, (p2[0], p2[2]), 0.6, p2[1] - drop - 1.3, 1.6, sub=1)
        d.tube("cipreste_teia", web, [b1, (b1[0], b1[1] - rnd.uniform(2.0, 4.0), b1[2])], 0.04, 0.02, 3)
    d.rock("cipreste_teia", web, c, 4.2, 15.2, 0.4, sub=1)          # véu no miolo da copa
    d.tall()
    for k, (p2, b1) in enumerate(ends):                             # veios de seiva acesa (fora da malha alta: `glow_*`)
        if k % 2 == 0:
            drop = 3.5
            d.cyl("cipreste_seiva", glow, (p2[0], p2[2]), 0.3, 0.26, 0.16, p2[1] - drop, 6, cap=False)
            strand(d, glow, b1, p2, 0.9, 0.035)
    z.ob("pillar", c[0], c[1], (8.0, 22.0, 8.0), visible=False)


def deck(z, d, c, r):
    """Deque das Palafitas: fundo escuro (plano acima da estrada) e tábuas de verdade em fiadas leste-oeste, estacas de
    amarração na beira. As tábuas ficam com 6 cm de altura: o boneco pisa nelas sem afundar à vista."""
    zone_lib.disc(z.coll, z.P + "chao_palafitas", c, r + 0.3, 0.0132, zone_lib.mat("patch_palafitas", (0.27, 0.22, 0.17)), 48, 0.03, 4)
    z.data["roads"].append({"kind": "street", "w": 0, "pts": [[c[0], c[1]]], "r": r + 0.5})
    tones = [d.m("deque_a", (0.56, 0.45, 0.31)), d.m("deque_b", (0.5, 0.4, 0.27)), d.m("deque_c", (0.61, 0.5, 0.35))]
    rnd = d.rnd
    row = -r + 0.3
    k = 0
    while row < r - 0.2:
        half = math.sqrt(max(0.0, r * r - row * row)) + rnd.uniform(-0.25, 0.25)
        x = -half
        while x < half - 0.4:
            L = min(rnd.uniform(2.4, 4.2), half - x)
            d.box("deque", tones[(k + rnd.randrange(2)) % 3], (c[0] + x + L * 0.5, c[1] + row), (L - 0.06, 0.05, 0.5), rnd.uniform(-0.8, 0.8), 0.0125)
            x += L
            k += 1
        row += 0.56
    post = d.m("palafita_estaca", (0.36, 0.28, 0.2))
    for i in range(24):                                             # estacas baixas na beira (fora das saídas)
        a = 7.5 + 15.0 * i
        if min(abs((a - e + 180.0) % 360.0 - 180.0) for e in EXITS.values()) < 24.0:
            continue
        q = (c[0] + math.cos(math.radians(a)) * (r + 0.1), c[1] + math.sin(math.radians(a)) * (r + 0.1))
        d.cyl("deque", post, q, 0.16, 0.13, rnd.uniform(0.8, 1.15), 0.0, 5)


def audit(z, arena):
    """Confere as regras do pedido que o build não garante sozinho; cada problema sai numa linha MARSH_AUDIT."""
    obs = z.data["obstacles"]
    solids = [(Vector(o["pos"]), max(o["size"][0], o["size"][2]) * 0.5, o) for o in obs
              if o.get("solid", True) and o["kind"] not in ("cliff", "water") and not o.get("y")]
    bad = 0

    def near(p, skip=None):
        return min((((p - q).length - r, o) for q, r, o in solids if o is not skip and (o["kind"] != "lamp" or (p - q).length > 0.1)), key=lambda v: v[0])

    for name, poly in z.road_polys.items():
        w = (places.TRAIL_W if name.startswith("trilha_") else next((r["w"] for r in z.data["roads"] if r.get("kind") == "road"), 4.0)) * 0.5
        for q, r, o in solids:
            if o["kind"] in ("hill", "wall") and name.startswith("trilha_"):
                continue                 # a trilha de um lugar acaba na boca/porta dele
            dd = zone_lib.poly_dist(q, poly) - r
            if dd < min(w, 1.5) + 0.2:
                print("MARSH_AUDIT sólido %s %s a %.1f m do eixo da estrada %s" % (o["kind"], o["pos"], dd, name))
                bad += 1
    for s in z.data["spawners"]:
        dd, o = near(Vector(s["pos"]))
        if dd < 3.0:
            print("MARSH_AUDIT spawner %s %s a %.1f m de %s %s" % (s["monster_id"], s["pos"], dd, o["kind"], o["pos"]))
            bad += 1
        for w in z.data["water"]:
            if w["kind"] == "lake" and (Vector(s["pos"]) - Vector(w["pos"])).length < w["r"] + 1.0:
                print("MARSH_AUDIT spawner %s %s dentro de lago" % (s["monster_id"], s["pos"]))
                bad += 1
        if any(zone_lib.poly_dist(Vector(s["pos"]), rv) < RIVER_W * 0.5 + 1.0 for rv in z.rivers):
            print("MARSH_AUDIT spawner %s %s dentro de rio" % (s["monster_id"], s["pos"]))
            bad += 1
        for p in z.data["portals"]:
            if (Vector(s["pos"]) - Vector(p["pos"])).length < 8.0 + s["radius"] * 0.0:
                print("MARSH_AUDIT spawner %s a < 8 m do portal" % s["monster_id"])
                bad += 1
    ids = list(z.data["npcs"].items())
    for i, (nid, v) in enumerate(ids):
        dd, o = near(Vector(v[:2]))
        if dd < 1.0:
            print("MARSH_AUDIT NPC %s a %.1f m de %s %s" % (nid, dd, o["kind"], o["pos"]))
            bad += 1
        for nid2, v2 in ids[i + 1:]:
            if (Vector(v[:2]) - Vector(v2[:2])).length < 2.5:
                print("MARSH_AUDIT NPCs %s e %s colados" % (nid, nid2))
                bad += 1
    for h in z.data["hangouts"]:
        dd, o = near(Vector(h))
        if dd < 0.8:
            print("MARSH_AUDIT ponto de bot %s a %.1f m de %s" % (h, dd, o["kind"]))
            bad += 1
    for g in GATHER:
        dd, o = near(Vector(g))
        if dd < 9.0 - 8.0:           # o centro livre; os pontos espalham no raio (GatherSystem.spread_gather procura chão andável)
            print("MARSH_AUDIT colheita %s com sólido a %.1f m" % (g, dd))
            bad += 1
        n = sum(1 for q, r, o in solids if (q - Vector(g)).length - r < 9.0)
        print("field_marsh: colheita %s: %d sólidos a < 9 m" % (g, n))
    for q, r, o in solids:
        if (q - Vector(arena[0])).length - r < arena[1]:
            print("MARSH_AUDIT sólido %s %s dentro da arena" % (o["kind"], o["pos"]))
            bad += 1
    print("field_marsh: auditoria %s (%d problemas; %d sólidos, %d obstáculos)" % ("ok" if bad == 0 else "COM PROBLEMAS", bad, len(solids), len(obs)))


def build(export=False):
    pal = {"leaf": (0.22, 0.34, 0.22), "cliff_grass": (0.28, 0.38, 0.26), "hill_grass": (0.32, 0.42, 0.28),
           "cliff_rock": (0.36, 0.36, 0.33), "cliff_rock_d": (0.29, 0.29, 0.27), "road": (0.50, 0.42, 0.30),
           "water": AMBER_DULL if AMBER_TINT else (0.26, 0.38, 0.34), "water_dark": (0.18, 0.26, 0.22), "wood": (0.44, 0.33, 0.22)}
    z = Zone(ZONE, size=SIZE, rim=RIM, seed=SEED, palette=pal)
    z.trail_color = (0.47, 0.4, 0.29)
    H = lambda r, a: (HUB[0] + math.cos(math.radians(a)) * r, HUB[1] + math.sin(math.radians(a)) * r)
    M = lambda r, a: (MATA[0] + math.cos(math.radians(a)) * r, MATA[1] + math.sin(math.radians(a)) * r)
    A = lambda r, a: (PONTA[0] + math.cos(math.radians(a)) * r, PONTA[1] + math.sin(math.radians(a)) * r)
    portal = polar(z, GORGE_ANG, 7)
    arrive = polar(z, GORGE_ANG, 15)
    z.data["spawn"] = list(arrive)
    z.data["arrive_from_field_forest"] = list(arrive)
    z.data["town"] = {"center": [HUB[0], HUB[1]], "radius": 0.0, "gates": []}
    cams = {"charco": CHARCO, "mata": MATA, "cais": CAIS, "viveiro": (70.0, 0.0), "chegada": arrive, "cipreste": (CIPRESTE[0], CIPRESTE[1] + 8.0),
            "lagoa": (0.0, 44.0)}
    z.cam_game = cams.get(os.environ.get("MARSH_CAM", ""), HUB)          # só a foto de revisão
    z.portal("to_forest", portal, "field_forest", FOREST_ARRIVE, "Floresta Sombria")
    z.block(arrive, 6)

    # ---------- chão por região (lido de cima). Pilha (mm): manchas do campo 0,8/1,6/2,4 < lodo 3,4 < lama do Cais 5,2
    #            < manchas Zone.patch 6,0 (= chão dos lugares) < poças 6,6 < anéis da arena 7,4/7,8 < acostamento 9,8
    #            < trilha de lugar 10,8 < estrada 12 < fundo do deque 13,2 ----------
    z.patch("clareira", HUB, 20.0, (0.36, 0.42, 0.30))
    z.patch("charco", CHARCO, 18.0, (0.24, 0.32, 0.22), grass=True)
    z.patch("mata_teias", MATA, 20.0, (0.36, 0.38, 0.33))
    z.patch("cais", CAIS, 15.0, (0.44, 0.38, 0.28), y=0.0052)        # por baixo do chão do acampamento (lugar `camp`, 6,0 mm)
    z.patch("ponta", PONTA, PONTA_R, (0.46, 0.42, 0.32))

    # ---------- água: Lagoa Turva, Córrego Âmbar (entra), canal (sai), poço do Charco ----------
    if AMBER_TINT:
        z.water_tint("water")
    z.lake("lagoa_turva", LAGOA[0], LAGOA[1], "water_dark")
    z.lake("charco", CHARCO_LAKE[0], CHARCO_LAKE[1], "water_dark")
    creek = z.river(CREEK, w=RIVER_W, material="water" if AMBER_TINT else "water_dark")
    z.river(OUTFLOW, w=RIVER_W, material="water_dark")

    # ---------- estradas (curvas; três laços, um ramo só até a porta fechada do Viveiro) ----------
    e = lambda k: H(DECK_R - 1.0, EXITS[k])
    junction = (-36.0, 62.0)                                        # largo do Cais: S, arco oeste e arco sul se encontram
    z.road("N", [portal, arrive, (-14, -64), (-6, -40), (-4, -24), e("N")], w=4.0, end_clearing=False)
    z.road("O", [e("O"), (-30, -6), (-50, -16), (-58, -14)], w=4.0, end_clearing=False)
    z.road("L", [e("L"), (30, -14), (44, -30), (52, -40)], w=4.0, end_clearing=False)
    z.road("S", [e("S"), (-16, 30), (-26, 48), junction], w=4.0, end_clearing=False)
    z.road("SE", [e("SE"), (22, 14), (33, 22), (41, 33), (51, 46), (51.5, 56), A(PONTA_R - 3.5, -62.0)], w=4.0, end_clearing=False)
    z.road("arco_oeste", [(-58, -14), (-62, -5), (-66, 6), (-63, 30), (-51, 50), junction], w=3.0, end_clearing=False)
    z.road("arco_sul", [junction, (-25.5, 80), (-12, 86), (4, 86), (22, 83), A(PONTA_R - 3.5, 158.0)], w=3.0, end_clearing=False)
    z.road("arco_leste", [(52, -40), (62, -31), (73, -15), (66.5, -8), (64.5, -1.5)], w=3.0, end_clearing=False)
    z.arrival(arrive, toward=portal, r=6.0)
    z.bridges()

    # ---------- relevo: afloramentos baixos de lama e pedra (só onde cabem) e o marco ----------
    n_t = 0
    for c, r, lv in [((-80, -48), 6, 2), ((84, 42), 6, 2), ((34, -88), 6, 1), ((-84, 34), 6, 2), ((14, 100), 5, 1), ((-30, 14), 4, 1),
                     ((88, -62), 5, 2), ((-48, -70), 6, 2), ((24, 4), 4, 1), ((-2, -58), 4, 1)]:
        if math.hypot(*c) + r > z.rim_r(math.atan2(c[1], c[0])) - 5.0 or not z.free(c[0], c[1], r + 5.0):
            continue
        if any(math.hypot(c[0] - s[1], c[1] - s[2]) < r + s[3] + 2.0 for s in SPAWNERS) or any(math.hypot(c[0] - g[0], c[1] - g[1]) < r + 10.0 for g in GATHER):
            continue
        if any(math.hypot(c[0] - p["pos"][0], c[1] - p["pos"][1]) < r + 16.0 for p in PLACES if "pos" in p):
            continue
        z.terrace("lama_%d" % n_t, c, r, lv, top="cliff_grass")
        n_t += 1
    z.cliffs(snow=False)

    z.avoid = [(LAGOA[0], LAGOA[1] + 1.0), (CHARCO_LAKE[0], CHARCO_LAKE[1] + 1.0), (CIPRESTE, 9.0), (PONTA, PONTA_R)]
    places.build(z, PLACES)

    # ---------- Mata das Teias: árvores secas postas à mão (ruas de 4 m), o resto da mata fica fora da clareira ----------
    mrnd = random.Random(53)
    web_trees = []
    for r, a in MATA_TREES:
        q = M(r, a)
        s = mrnd.uniform(1.25, 1.6)
        z.ob("dead_tree", q[0], q[1], (1.5 * s, 3.9 * s, 1.5 * s), color=DEAD_COLS[mrnd.randrange(3)])
        web_trees.append((q, 3.9 * s))

    # ---------- vegetação: brejo aberto, com mata em anéis entre os lugares; 30% das árvores secas ----------
    for c, r in ((HUB, 22.0), (CHARCO, 13.0), (MATA, MATA_R + 3.0), (PONTA, PONTA_R + 4.5), (junction, 5.0), (CIPRESTE, 12.5), (PIER, 7.5)):
        z.block(c, r)
    for g in GATHER:
        z.block(g, 9.5)
    for s in SPAWNERS:
        z.block((s[1], s[2]), 5.2)
    for q in PATROL:
        z.block(q, 3.0)
    z.scatter("tree", [((-40, -70), 22, 34), ((-84, -40), 16, 20), ((30, -24), 16, 22), ((84, -8), 14, 14), ((-30, 14), 16, 20),
                       ((-84, 44), 16, 20), ((76, 28), 16, 20), ((72, 52), 12, 12), ((16, 100), 16, 16), ((-64, 90), 14, 12),
                       ((-10, -52), 12, 10), ((36, 6), 12, 10), ((86, -52), 12, 12), ((-20, 62), 8, 5)],
              0, (1.6, 3.6, 1.6), TREE_COLS, margin=3.6, spacing=3.6, scale=(1.1, 1.8))
    z.scatter("tree", [((0, 0), 104, 230)], 0, (1.6, 3.6, 1.6), TREE_COLS, margin=3.8, spacing=4.2, scale=(1.0, 1.6))
    z.rim_belt(150, (1.6, 3.6, 1.6), TREE_COLS[:2])
    z.scatter("rock", [(CHARCO, 26, 6), ((0, 0), 96, 16)], 0, (1.4, 0.9, 1.2), [(0.38, 0.39, 0.36)], margin=3.0, spacing=2.5, scale=(0.8, 1.5))

    nrnd = random.Random(113)
    obs = z.data["obstacles"]
    fr = lambda x, zz, m: z.free(x, zz, m)
    nature.fix_trees(obs, nrnd)
    for o in obs:                                                   # 30% da mata seca (cinza): o brejo afoga as árvores
        if o["kind"] == "tree" and not o.get("y") and nrnd.random() < 0.3:
            o["kind"] = "dead_tree"
            o["color"] = list(DEAD_COLS[nrnd.randrange(len(DEAD_COLS))])
    nature.scatter(z.ob, fr, nrnd, "bush", [((0, 0), 100, 110)], (1.7, 0.95, 1.7), [(0.22, 0.34, 0.22), (0.27, 0.4, 0.25), (0.33, 0.43, 0.27)],
                   solid=False, margin=2.2, spacing=2.8, avoid=obs)
    nature.scatter(z.ob, fr, nrnd, "flowers", [((0, 0), 98, 14), (CHARCO, 16, 4)], (1.6, 0.45, 1.6), [(0.86, 0.88, 0.7), (0.72, 0.64, 0.82), (0.9, 0.86, 0.9)],
                   solid=False, margin=2.4, spacing=4.0, avoid=obs)
    nature.woodland_floor(z.ob, fr, nrnd, [((-40, -70), 22, 7), ((-84, -40), 16, 5), ((76, 28), 16, 5), (CHARCO, 24, 6), ((0, 0), 96, 18)],
                          bark=[(0.36, 0.3, 0.22), (0.4, 0.35, 0.27)], avoid=obs)
    lakes = [LAGOA, CHARCO_LAKE]
    nature.clear_banks(obs, z.rivers, lakes, z.river_w)
    nature.shore(z.ob, nrnd, z.rivers, lakes, list(z.road_polys.values()), z.river_w, colors=[(0.36, 0.46, 0.27), (0.42, 0.5, 0.3)],
                 every=3.2, keep=0.7, blocked=[(PONTA, PONTA_R + 1.0)])

    # ---------- NPCs e pontos de bot (nomes/papéis: world-builder, MapsCatalog.PLACE_NPCS["field_marsh"]) ----------
    fire = HUB
    guide, merchant = (-3.5, 3.0), (5.0, -4.0)
    z.npc("marsh_guide", guide[0], guide[1], face_to(guide[0], guide[1], *fire))
    z.npc("marsh_merchant", merchant[0], merchant[1], face_to(merchant[0], merchant[1], *fire))
    stall = (7.6, -6.3)
    z.ob("stall", stall[0], stall[1], (3.0, 2.4, 2.0), math.degrees(math.atan2(stall[1], stall[0])) + 90.0 + 180.0, color=(0.46, 0.5, 0.3))
    z.data["hangouts"] = [[round(q[0], 2), round(q[1], 2)] for q in (H(6.0, -75.0), H(7.5, -135.0), H(8.0, 170.0), H(6.5, 100.0), H(8.5, 62.0),
                                                                    H(7.0, 10.0), H(4.2, -150.0), H(4.5, 45.0))]

    # ---------- monstros (ids do world-builder) ----------
    for mid, x, zz, r, n, resp in SPAWNERS:
        z.spawner(mid, x, zz, r, n, resp)
    z.spawner("marsh_smuggler", PATROL[0][0], PATROL[0][1], 2, 2, 60.0, route=PATROL)
    z.spawner("bog_mother", PONTA[0], PONTA[1], 2, 1, 180.0)

    # ---------- acabamento (dress.py) ----------
    d = Dress(z, 431)
    rnd = d.rnd
    d.mottle([("brejo_escuro", (0.25, 0.33, 0.24)), ("brejo_musgo", (0.34, 0.42, 0.28)), ("brejo_oliva", (0.32, 0.37, 0.25))],
             [((0, 0), 102, 170)], y=0.0008, rmin=3.0, rmax=8.5, step=0.0008)
    d.mottle([("brejo_lodo", (0.26, 0.3, 0.23))], [((-40, -70), 22, 8), ((-84, -40), 16, 6), ((76, 28), 16, 6), ((-30, 14), 16, 6), ((16, 100), 16, 5),
                                                  ((-84, 44), 16, 6)], y=0.0034, rmin=5.0, rmax=9.0, group="lodo")
    d.road_edges((0.41, 0.37, 0.27), extra=-0.2, wvar=0.45)
    d.roadside(d.m("seixo_brejo", (0.44, 0.44, 0.4)), d.m("capim_brejo", (0.3, 0.42, 0.26)), every=5.0)

    # Palafitas do Brejo: deque, fogo de cozinha no centro, duas palafitas (noroeste e nordeste: a câmera olha do sul),
    # cerca baixa em trechos, botes virados, redes secando, carga do mercador
    deck(z, d, HUB, DECK_R)
    d.cookfire(fire, 1.1, 20.0)
    d.solid(fire[0], fire[1], 2.4, 2.4, 1.4)
    for a, roof in ((-137.0, (0.56, 0.5, 0.3)), (-57.0, (0.5, 0.47, 0.3))):
        t = H(17.0, a)
        stilt_hut(d, t, door_rot(HUB, t), 1.0, roof)
    edges = sorted(a % 360.0 for a in EXITS.values())
    for i, a0 in enumerate(edges):
        a1 = edges[(i + 1) % len(edges)] + (360.0 if i == len(edges) - 1 else 0.0)
        lo, hi = a0 + 26.0, a1 - 26.0
        if hi - lo < 14.0:
            continue
        n = max(1, int(round(math.radians(hi - lo) * (DECK_R + 0.6) / 3.2)))
        for k in range(n):
            p0, p1 = H(DECK_R + 0.6, lo + (hi - lo) * k / n), H(DECK_R + 0.6, lo + (hi - lo) * (k + 1) / n)
            d.fence_run(p0, p1, 0.85, color=(0.4, 0.31, 0.22), gap=1.6)
            chain(d, p0, p1, 0.45, 0.9)
    for a, rr, ro in ((150.0, 15.6, 25.0), (228.0, 15.2, 110.0)):          # botes virados (casco para cima)
        q = H(rr, a)
        d.rowboat(q, ro, 3.8, color=(0.42, 0.34, 0.24), y0=0.62, tilt=(180, 0))
        d.solid(q[0], q[1], 2.0, 2.0, 0.8)
    for a, rr in ((74.0, 15.0), (12.0, 15.6)):                             # redes secando
        q = H(rr, a)
        ro = 90.0 - a
        d.net_rack(q, ro, 3.6)
        ar = math.radians(ro)
        chain(d, (q[0] - math.cos(ar) * 1.8, q[1] + math.sin(ar) * 1.8), (q[0] + math.cos(ar) * 1.8, q[1] - math.sin(ar) * 1.8), 0.5, 2.0)
    d.fish_rack(H(14.6, -100.0 + 34.0), 100.0 - 34.0 + 90.0)
    cq = (9.6, -8.9)
    d.cargo(cq, 4, 1.0)
    d.solid(cq[0], cq[1], 2.0, 2.0, 1.1)
    for q in ((4.6, -8.6), (9.9, -4.0)):
        d.sack(q, 1.0)
    # vida em cima do deque (tudo baixo e fora do caminho entre as saídas e o fogo): esteiras, tocos de sentar, cestos, mesa de peixe
    for q, sx, sz, ro, col, trim in ((H(4.6, 196.0), 2.6, 1.7, 20.0, (0.5, 0.42, 0.26), (0.36, 0.42, 0.26)), (H(5.6, 75.0), 2.4, 1.6, -30.0, (0.46, 0.4, 0.3), (0.56, 0.4, 0.24))):
        d.box("deque", d.m("esteira_%d" % int(col[0] * 100), col), q, (sx, 0.02, sz), ro, 0.064)
        d.box("deque", d.m("esteira_%d" % int(trim[0] * 100), trim), q, (sx * 0.72, 0.02, sz * 0.62), ro, 0.07)
    seat = d.m("cavalete", (0.4, 0.3, 0.22))
    for a in (40.0, 115.0, 250.0, 320.0):
        d.cyl("deque", seat, H(2.7, a), 0.27, 0.24, 0.4, 0.06, 7)
    basket, fishm = d.m("cesto", (0.66, 0.56, 0.36)), d.m("peixe_seco", (0.78, 0.6, 0.46))
    for q in (H(10.2, 128.0), H(10.6, 136.0), H(9.8, -62.0), H(10.4, 222.0)):
        d.cyl("deque", basket, q, 0.3, 0.38, 0.42, 0.06, 7)
        d.cyl("deque", fishm, q, 0.3, 0.3, 0.04, 0.44, 7)
    tq = H(9.6, 150.0)
    d.box("deque", seat, tq, (1.9, 0.08, 0.9), 60.0, 0.78)
    P = local(tq, 60.0)
    for lx in (-0.8, 0.8):
        for ly in (-0.35, 0.35):
            d.cyl("deque", seat, P(lx, ly), 0.05, 0.05, 0.74, 0.06, 4)
    for lx in (-0.5, 0.0, 0.5):
        d.box("deque", fishm, P(lx, 0.0), (0.16, 0.06, 0.5), 60.0 + 20.0 * lx, 0.86)
    d.solid(tq[0], tq[1], 1.6, 1.6, 0.9)
    bq = H(10.2, -48.0)
    for k, (dx, dz) in enumerate(((0.0, 0.0), (0.9, 0.3), (0.3, 0.95))):
        d.barrel((bq[0] + dx, bq[1] + dz), 0.9 + 0.1 * (k % 2))
    d.solid(bq[0] + 0.4, bq[1] + 0.4, 1.9, 1.9, 1.0)
    sq = H(14.0, EXITS["N"] + 22.0)
    d.signpost(sq, 30.0, n=3)
    d.solid(sq[0], sq[1], 0.5, 0.5, 2.4)
    for a in (EXITS["N"] - 16.0, EXITS["S"] + 16.0, EXITS["O"] + 15.0, EXITS["L"] - 15.0):     # lampião de estaca em quatro saídas
        d.torch(H(DECK_R + 0.9, a), 2.0)

    # garganta norte: dois tocos de cipreste e a placa torta
    stump = d.m("cipreste_casca", (0.42, 0.39, 0.34))
    for sx in (-1, 1):
        q = (arrive[0] + sx * 6.4, arrive[1] - 2.0 + sx * 1.2)
        d.cyl("toco", stump, q, 1.15, 0.7, 2.3 + 0.5 * sx, 0.0, 8, 20.0 * sx, tilt=(3.0 * sx, 2.0), jitter=0.12)
        d.cyl("toco", d.m("cipreste_casca_esc", (0.33, 0.31, 0.28)), q, 0.5, 0.0, 0.9, 2.2 + 0.5 * sx, 5, 0.0, tilt=(8.0 * sx, 0))
        d.solid(q[0], q[1], 2.0, 2.0, 2.6)
        for k in range(3):
            a = rnd.uniform(0, math.tau)
            d.cyl("toco", stump, (q[0] + math.cos(a) * 1.7, q[1] + math.sin(a) * 1.7), 0.3, 0.1, rnd.uniform(0.5, 1.0), 0.0, 5)
    sg = (arrive[0] + 4.6, arrive[1] + 4.4)
    d.cyl("placa", d.m("placa_poste", (0.44, 0.32, 0.22)), sg, 0.1, 0.08, 2.5, 0.0, 5, 0.0, tilt=(0, 13))
    for k in range(2):
        d.box("placa", d.m("placa_velha", (0.6, 0.52, 0.36)), (sg[0] + 0.38 - 0.1 * k, sg[1]), (1.4, 0.34, 0.07), 20.0 + 150.0 * k, 1.85 - k * 0.45, tilt=(0, 13))
    d.solid(sg[0], sg[1], 0.6, 0.6, 2.4)

    # Charco dos Sapos: passarela de tábuas até a beira, vitórias-régias, taboas, desova, troncos podres
    d.planks([(-58.5, -14.5), (-61.5, -15.8), (-64.6, -16.6)], 1.5, 0.05, color=(0.46, 0.37, 0.26))
    for q in ((-64.9, -15.6), (-64.5, -17.6)):
        d.cyl("passarela", d.m("palafita_estaca", (0.36, 0.28, 0.2)), q, 0.12, 0.1, 1.0, 0.0, 5)
    for lake, n in ((CHARCO_LAKE, 26), (LAGOA, 44)):
        (lx, lz), lr = lake
        for k in range(n):
            a, r = rnd.uniform(0, math.tau), lr * math.sqrt(rnd.uniform(0.08, 0.86))
            q = (lx + math.cos(a) * r, lz + math.sin(a) * r)
            if any(zone_lib.poly_dist(Vector(q), rv) < RIVER_W for rv in z.rivers):
                continue
            lily(d, q, rnd.uniform(0.35, 0.75), 0.03, flower=k % 5 == 0)
        for k in range(int(lr * 3.2)):                                # taboas na beira (fora da boca das estradas)
            a = math.tau * k / int(lr * 3.2) + rnd.uniform(-0.05, 0.05)
            r = lr + rnd.uniform(-0.9, 1.6)
            q = (lx + math.cos(a) * r, lz + math.sin(a) * r)
            if rnd.random() < 0.62 and all(zone_lib.poly_dist(Vector(q), p) > 3.4 for p in z.road_polys.values()) \
                    and all(zone_lib.poly_dist(Vector(q), rv) > RIVER_W * 0.5 + 0.4 for rv in z.rivers):
                cattail(d, q, rnd.uniform(1.3, 1.9))
    for a in (20.0, 95.0, 160.0, 250.0, 310.0):
        q = (CHARCO_LAKE[0][0] + math.cos(math.radians(a)) * (CHARCO_LAKE[1] + 1.4), CHARCO_LAKE[0][1] + math.sin(math.radians(a)) * (CHARCO_LAKE[1] + 1.4))
        frog_eggs(d, q, 6)
    rot_log = d.m("tronco_podre", (0.33, 0.29, 0.22))
    moss = d.m("tronco_musgo", (0.33, 0.43, 0.27))
    for q, ro, L in (((-79.5, -8.5), 30.0, 3.4), ((-63.0, -27.5), 110.0, 3.0), ((-80.5, -25.0), 70.0, 3.6)):
        if d.ok(q[0], q[1], 1.2, road=0.6, water=0.3):
            d.log("tronco", rot_log, q, 0.42, L, ro, 0.36)
            d.rock("tronco", moss, q, 0.5, 0.45, 0.4, sx=1.8, rot=ro, sub=1)
            ar = math.radians(ro)
            chain(d, (q[0] - math.cos(ar) * L * 0.4, q[1] + math.sin(ar) * L * 0.4), (q[0] + math.cos(ar) * L * 0.4, q[1] - math.sin(ar) * L * 0.4), 0.9, 0.8)

    # poças rasas pelo brejo (só visual: tinta escura acima das manchas de região) com taboas e uma régia ou outra
    pud = d.m("patch_poca", (0.2, 0.28, 0.25))
    pud2 = d.m("patch_poca_b", (0.23, 0.31, 0.26))
    for q in d.spots([((0, 0), 98, 60), (CHARCO, 17, 9), ((-8, 70), 12, 4), ((30, 50), 10, 3)], r=2.6, spacing=9.0, road=1.2, water=2.5, tries=8):
        if any(math.hypot(q[0] - c[0], q[1] - c[1]) < rr for c, rr in ((HUB, 22.0), (MATA, MATA_R + 2.0), (PONTA, PONTA_R + 3.0), (CAIS, 13.0))) \
                or any(math.hypot(q[0] - p["pos"][0], q[1] - p["pos"][1]) < 11.0 for p in PLACES if "pos" in p):
            continue
        r = rnd.uniform(1.6, 3.2)
        d.blob("poca", pud if rnd.random() < 0.5 else pud2, q, r, 0.0066, 0.3, sx=rnd.uniform(1.0, 1.7), rot=rnd.uniform(0, 180))
        for k in range(rnd.randint(2, 4)):
            a = rnd.uniform(0, math.tau)
            cattail(d, (q[0] + math.cos(a) * r * 0.9, q[1] + math.sin(a) * r * 0.9), rnd.uniform(1.1, 1.6), 4)
        if rnd.random() < 0.5:
            lily(d, (q[0] + rnd.uniform(-0.6, 0.6), q[1] + rnd.uniform(-0.6, 0.6)), rnd.uniform(0.3, 0.5), 0.008)

    # Mata das Teias: véus nas árvores secas, fios entre elas (alguns de seiva acesa), casulos no chão e pendurados
    web_m, glow_m = d.m("teia", WEB), d.m("glow_seiva", AMBER)
    for q, h in web_trees:
        web_tree(d, q, h, rnd)
    k = 0
    for i, (qa, ha) in enumerate(web_trees):
        for qb, hb in web_trees[i + 1:]:
            L = math.hypot(qa[0] - qb[0], qa[1] - qb[1])
            if L > 11.5:
                continue
            strand(d, glow_m if k % 3 == 0 else web_m, (qa[0], ha * 0.9, qa[1]), (qb[0], hb * 0.9, qb[1]), 0.9 + L * 0.07, 0.035 if k % 3 == 0 else 0.045)
            if k % 2 == 0:                                          # casulo pendurado no meio do fio
                mx, mz, my = (qa[0] + qb[0]) * 0.5, (qa[1] + qb[1]) * 0.5, (ha + hb) * 0.45 - (0.9 + L * 0.07)
                d.tube("teia_fio", web_m, [(mx, my, mz), (mx, my - 1.1, mz)], 0.04, 0.03, 3)
                cocoon(d, (mx, mz), 0.8, my - 2.2)
            k += 1
    for r, a, s in ((5.2, 60.0, 1.0), (10.8, 222.0, 1.2), (11.5, 300.0, 0.9), (4.6, 235.0, 1.1), (16.0, 258.0, 1.0)):
        cocoon(d, M(r, a), s)
    webg = d.m("patch_teia_chao", (0.42, 0.44, 0.4))
    for q, h in web_trees[::2]:
        d.blob("teia_chao", webg, (q[0] + rnd.uniform(-1, 1), q[1] + rnd.uniform(-1, 1)), rnd.uniform(2.2, 3.2), 0.0066, 0.35)

    # Cais dos Contrabandistas: píer no canal, canoas, barris de seiva (aro aceso), caixotes
    rv = z.rivers[1]
    pi = min(range(2, len(rv) - 2), key=lambda i: (rv[i] - Vector(PIER)).length)
    t = (rv[pi + 1] - rv[pi - 1]).normalized()
    nr = Vector((-t.y, t.x))
    if nr.x > 0:
        nr = -nr                                                    # para a margem oeste (lado do acampamento)
    bank, mid = rv[pi] + nr * (RIVER_W * 0.5 + 3.4), rv[pi] - nr * 0.4
    d.planks([tuple(bank), tuple((bank + mid) * 0.5), tuple(mid)], 1.7, 0.12, color=(0.44, 0.35, 0.25))
    for f in (0.35, 0.68, 1.0):
        for sgn in (-1, 1):
            q = bank + (mid - bank) * f + t * 0.95 * sgn
            d.cyl("passarela", d.m("palafita_estaca", (0.36, 0.28, 0.2)), (q.x, q.y), 0.13, 0.11, 1.1, -0.2, 5)
    pier_rot = zone_lib.along(t.x, t.y)
    cq = rv[pi] + t * 2.6 + nr * 0.6
    d.rowboat((cq.x, cq.y), pier_rot, 3.6, color=(0.4, 0.33, 0.24), y0=0.03)
    cq = bank + t * 3.0 + nr * 0.8
    d.rowboat((cq.x, cq.y), pier_rot + 35.0, 3.6, color=(0.46, 0.36, 0.25), y0=0.0, tilt=(8, 0))
    d.solid(cq.x, cq.y, 1.8, 1.8, 0.7)
    for k, (du, dv) in enumerate(((-1.6, 1.0), (-2.4, 1.9), (-1.5, 2.2))):
        q = bank + t * du + nr * dv
        sap_barrel(d, (q.x, q.y), 1.0 + 0.1 * k)
    q = bank + t * (-2.0) + nr * 1.7
    d.solid(q.x, q.y, 2.2, 2.2, 1.0)
    C = lambda r, a: (CAIS[0] + math.cos(math.radians(a)) * r, CAIS[1] + math.sin(math.radians(a)) * r)
    for r, a in ((4.6, 150.0), (5.5, 160.0), (4.8, 250.0)):
        sap_barrel(d, C(r, a), 1.0)
    d.solid(C(5.0, 155.0)[0], C(5.0, 155.0)[1], 1.8, 1.8, 1.0)
    d.solid(C(4.8, 250.0)[0], C(4.8, 250.0)[1], 0.9, 0.9, 1.0)
    cg = C(5.2, 205.0)
    d.cargo(cg, 5, 1.3)
    d.solid(cg[0], cg[1], 2.4, 2.4, 1.2)
    d.net_rack(C(11.5, 120.0), 60.0, 3.4)
    cb = C(11.0, 95.0)
    d.rowboat(cb, 150.0, 3.6, color=(0.4, 0.33, 0.24), y0=0.0, tilt=(10, 0))
    d.solid(cb[0], cb[1], 1.8, 1.8, 0.7)
    d.weapon_rack(C(4.2, 60.0), 30.0)
    d.solid(C(4.2, 60.0)[0], C(4.2, 60.0)[1], 2.0, 0.6, 1.5)

    # Ponta da Bocarra: arena limpa; anéis de lama no tom do próprio chão, taboas altas e desova só por fora da borda
    t1, t2 = d.m("patch_ponta_a", (0.42, 0.39, 0.3)), d.m("patch_ponta_b", (0.5, 0.45, 0.35))
    d.arc("arena", t1, PONTA, PONTA_R - 3.0, 0.0, math.tau, 1.2, y=0.0074, wvar=0.3)
    d.arc("arena", t2, PONTA, PONTA_R - 8.5, 0.0, math.tau, 0.8, y=0.0078, wvar=0.3)
    for k in range(64):
        a = 360.0 * k / 64 + rnd.uniform(-2, 2)
        for rr in (PONTA_R + 0.9, PONTA_R + 2.3):
            q = A(rr + rnd.uniform(-0.4, 0.4), a + (2.8 if rr > PONTA_R + 1.5 else 0.0))
            if all(zone_lib.poly_dist(Vector(q), p) > 3.2 for p in z.road_polys.values()) and math.hypot(*q) < z.rim_r(math.atan2(q[1], q[0])) - 2.5:
                cattail(d, q, rnd.uniform(1.7, 2.4), 6)
    for a in (15.0, 80.0, 135.0, 200.0, 318.0):
        q = A(PONTA_R + 0.2, a)
        if all(zone_lib.poly_dist(Vector(q), p) > 3.0 for p in z.road_polys.values()):
            frog_eggs(d, q, 9)

    # Córrego Âmbar: riscos de seiva fosca na água e pedras de resina na margem (o brilho fica para teias e barris)
    sap = d.m("patch_seiva_agua", AMBER_DULL)
    sap2 = d.m("patch_seiva_agua_b", (0.5, 0.44, 0.24))
    i = 3
    while i < len(creek) - 8:
        n = rnd.randint(5, 8)
        off = rnd.uniform(-1.2, 1.2)
        pts = []
        for j in range(i, i + n):
            tt = (creek[min(j + 1, len(creek) - 1)] - creek[j - 1]).normalized()
            pts.append(creek[j] + Vector((-tt.y, tt.x)) * (off + 0.25 * math.sin(j * 1.3)))
        if not any(b["road"] == "SE" and (Vector(b["pos"]) - pts[len(pts) // 2]).length < 6.0 for b in z.data.get("bridges", [])):
            d.strip("seiva", sap if i % 2 else sap2, pts, rnd.uniform(0.35, 0.7), 0.0215, 0.5, taper="point")
        i += n - rnd.randint(1, 3)
    resin = d.m("resina", (0.58, 0.45, 0.22))
    for i in range(4, len(creek) - 3, 5):
        tt = (creek[i + 1] - creek[i - 1]).normalized()
        q = creek[i] + Vector((-tt.y, tt.x)) * (RIVER_W * 0.5 + rnd.uniform(0.5, 1.2)) * (1 if i % 2 else -1)
        if d.ok(q.x, q.y, 0.5, road=0.8, water=0.0):
            d.rock("resina", resin, (q.x, q.y), rnd.uniform(0.3, 0.55), 0.0, 0.65, sub=1)

    # o marco e o resto do brejo: cogumelos foscos, samambaias, pedras com musgo
    hanged_cypress(z, d, CIPRESTE, rnd)
    fern, fern2 = d.m("samambaia_brejo", (0.27, 0.42, 0.27)), d.m("samambaia_brejo_b", (0.34, 0.47, 0.29))
    for q in d.spots([((0, 0), 98, 120)], r=0.5, spacing=3.8, road=0.3, blocked=True, tries=5):
        for j in range(rnd.randint(2, 4)):
            d.tuft("mini", fern if j % 2 else fern2, (q[0] + rnd.uniform(-0.8, 0.8), q[1] + rnd.uniform(-0.8, 0.8)), 0.55, 0.8, 6, w=0.13)
    for q in d.spots([((0, 0), 96, 40)], r=0.5, spacing=6.0, road=0.4, blocked=True, tries=6):
        for j in range(rnd.randint(2, 4)):
            d.mushroom((q[0] + rnd.uniform(-0.7, 0.7), q[1] + rnd.uniform(-0.7, 0.7)), rnd.uniform(0.7, 1.3),
                       cap=[(0.56, 0.44, 0.34), (0.74, 0.7, 0.58), (0.5, 0.5, 0.36)][j % 3], glow=False)
    for q in d.spots([((0, 0), 96, 16)], r=2.0, spacing=16.0, road=1.5, blocked=True):
        d.outcrop(q, 1.9, 3, (0.38, 0.39, 0.36), top=(0.31, 0.42, 0.27), hmul=0.6)
        d.solid(q[0], q[1], 2.8, 2.8, 1.2)
    d.flush()

    audit(z, (PONTA, PONTA_R))
    print("field_marsh: portal %s chegada %s (chegada na Floresta %s)" % (portal, arrive, FOREST_ARRIVE))
    print("field_marsh: lugares %s" % [(p["id"], p["type"], p["pos"]) for p in z.data["places"]])
    print("field_marsh: portais futuros %s" % z.data.get("future_portals"))
    print("field_marsh: npcs %s" % z.data["npcs"])
    print("field_marsh: spawners (%d vivos) %s" % (sum(s["count"] for s in z.data["spawners"]),
                                                  [(s["monster_id"], s["pos"], s["radius"], s["count"]) for s in z.data["spawners"]]))
    print("field_marsh: pontes %s" % z.data.get("bridges"))
    return z.finish(export, poi=PONTA, ground=GROUND)
