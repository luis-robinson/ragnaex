"""Avenida do Cortejo (field_parade, Ato III parte 1, Lv 47-49): o campo de festa abandonado a sudeste de Lumeria,
onde o desfile nunca termina. GDD design/gdd/ato3-excesso-45-50.md (§2, §3, §4, §7).
Chegada a NOROESTE (Lumeria sai pelo portão sul-leste, rumo 130; a chegada fica no rumo oposto, 310).

  * A AVENIDA  uma só, larga (8 m), em S: da chegada desce para sudeste, contorna o Posto pelo oeste e enrola para o
               largo do Palco Grande. Mosaico desbotado, bandeirolas dobradas dos dois lados, palcos baixos.
  * CENTRO     Posto dos Lúcidos (hub): anel de barricadas de móveis, chão cinza-azulado SEM enfeite, tendas, fogo.
               O cristal chega em L2 (hx3_cellars): `crystal_hint`.
  * OESTE      Arquibancadas: três lances em ferradura em volta da pista.
  * NORTE      Carros Alegóricos Tombados: quatro carros virados, máscara gigante, leque, bolo de andares, taça.
  * LESTE      Conservatório (fachada de tubos de órgão): entrada de dg_conservatory (opcional, onda 4).
  * SUL        Palco Grande (a frente olha para o sul e para a câmera) e o largo redondo da Prima-Donna, chefe de
               mundo. Em L3b (hx3_veil_open) a cortina do fundo dá lugar ao Véu Rasgado: portal para rift_garden.
  * MARCO      Arco do Triunfo de Fitas (16 m), ao lado da avenida, sobre o traçado antigo.
  Lugares (`_check_places`): Tenda do Ponto e Casa da Costureira (cabanas), Arraial dos Convertidos (acampamento),
  Altar da Máscara Partida (santuário), Conservatório (masmorra). O Posto dos Lúcidos é o hub (fica no centro).

Leitura de cima: a fita clara da avenida em S, as linhas de bandeirolas, o cinza-azulado do Posto, os lances das
arquibancadas, o espelho d'água a sudoeste. Chão só em tons do próprio chão (mosaico, anéis do largo): cor viva no
chão é aviso de golpe. A cor da festa fica nos panos, nas fitas do arco e nos carros.

Mapas que ainda não existem (dg_conservatory, rift_garden) saem em data["future_portals"]; a chefe de mundo em
data["world_boss_hint"]. A volta para Lumeria é portal de verdade.

Pilha de planos do chão (mm): manchas do campo 0,8/1,6/2,4 · manchas `Zone.patch` 4,5-6,8 · chão dos lugares 6,0 ·
acostamento 9,8 · trilha 10,8 · estrada/avenida 12 · mosaico da avenida 12,3 · largos 14 · mosaico/anéis do largo 14,5.

Estágios (data["stage_tags"]):
  l2_cristal (hx3_cellars): o pedestal do cristal no Posto
  l0_cortina (até hx3_veil_open): a cortina fechada no fundo do Palco Grande
  l3b_veu (hx3_veil_open): o Véu Rasgado no palco e o Posto da Aurora na boca dele

    blender -b --factory-startup --python tools/blender/zones/run_zone.py -- build_parade <pasta_png> --export
    (PARADE_POI=<posto|arco|arquibancadas|carros|conservatorio|palco|ponto|costureira|altar|arraial|chegada>)
"""
import math
import os
import random

from mathutils import Vector

import act2_dress
import act3_fields as af
import act3_ready
import build_lumeria as bl
import nature
import places
import zone_lib
from act3_fields import H, polar
from dress import Dress
from zone_lib import Zone, along, mat

ZONE = "field_parade"
LUMERIA_ARRIVE = (72.01, 60.42)          # chegada em city_lumeria (build_lumeria: future_portals to_field_parade "arrive")
ARRIVE_DEG = 220.0                       # graus do jogo (x = cos, z = sin): noroeste
HUB_R = 15.0
HUB_GATES = [0.0, 90.0, 180.0, -90.0]
AVENUE_W = 8.0
ARCH = (-47.0, -21.0)
STANDS = (-80.0, 22.0)                   # centro da pista das arquibancadas
FLOATS = (10.0, -78.0)
CONS = (89.0, -10.0)                     # corpo do Conservatório (a fachada olha para oeste)
CONS_FRONT = (72.0, -8.0)
STAGE = (30.0, 55.0)                     # Palco Grande (a frente olha para o sul)
ARENA, ARENA_R = (30.0, 77.0), 16.0      # largo da Prima-Donna
POND, POND_R = (-66.0, 68.0), 9.0        # Espelho d'Água
PROMPTER = (48.0, 22.0)
SEAMSTRESS = (-34.0, 90.0)
ALTAR = (64.0, -72.0)
CONVERT_CAMP = (-18.0, -94.0)
Q_CELLARS, Q_MIRRORS, Q_VEIL_OPEN = "hx3_cellars", "hx3_mirrors", "hx3_veil_open"
MOBS = {"convert": "convert", "hound": "silk_hound", "reflection": "vain_reflection", "first": "first_dancer", "dancer": "veil_dancer",
        "chorister": "chorister", "maestro": "choir_maestro", "alpha": "parade_alpha", "reveler": "masked_reveler", "master": "ceremony_master"}
BOSS_ID = "boss_prima_donna"             # id de trabalho (WP8): A Prima-Donna do Palco

GROUND = (0.66, 0.69, 0.5)               # relva pálida de campo de festa (sugestão de MapDef.ground_color)
PAVE = (0.86, 0.8, 0.76)                 # mosaico desbotado da avenida
LUCID = (0.6, 0.66, 0.74)
STONE, STONE_D = (0.9, 0.85, 0.76), (0.76, 0.7, 0.62)
WOOD = (0.62, 0.48, 0.36)
VELVET = (0.52, 0.22, 0.32)
TREES = [(0.36, 0.54, 0.4), (0.5, 0.62, 0.42), (0.94, 0.78, 0.82), (0.9, 0.84, 0.6)]      # copas: verde, rosa-pó e manteiga

PLACES = [
    {"type": "cabin", "id": "ponto", "pos": PROMPTER, "face": 200.0, "npc": "parade_prompter", "roof": (0.56, 0.3, 0.4), "wall": (0.92, 0.86, 0.8)},
    {"type": "cabin", "id": "costureira", "pos": SEAMSTRESS, "face": 300.0, "npc": "parade_seamstress", "roof": (0.58, 0.8, 0.7), "wall": (0.93, 0.9, 0.84)},
    {"type": "shrine", "id": "altar_mascara", "pos": ALTAR, "npc": "broken_mask_altar", "ground": (0.74, 0.72, 0.7)},
    {"type": "camp", "id": "arraial_convertidos", "pos": CONVERT_CAMP, "face": 60.0, "mob": MOBS["convert"], "count": 3, "cloth": (0.86, 0.72, 0.78),
     "respawn": 28.0, "ground": (0.62, 0.6, 0.52)},
]
EVENT_POINTS = [
    ("forced_dance", "avenida", 0.2, 1, MOBS["dancer"]),
    ("choir_corner", "carros_leste", 0.5, -1, MOBS["chorister"]),
    ("forced_dance", "arquibancadas", 0.62, 1, MOBS["dancer"]),
    ("choir_corner", "conservatorio_sul", 0.5, 1, MOBS["chorister"]),
    ("forced_dance", "carros_oeste", 0.5, -1, MOBS["dancer"]),
]


def post(z, d, d_l2):
    """Hub: o Posto dos Lúcidos. Anel de barricadas de móveis com quatro vãos, chão cinza-azulado sem enfeite, três
    pavilhões de lona cinza, fogo de cozinha no meio, carga. Em L2 ganha o pedestal do cristal."""
    z.patch("posto", (0.0, 0.0), HUB_R + 2.5, LUCID)
    z.data["roads"].append({"kind": "street", "w": 0, "pts": [[0.0, 0.0]], "r": HUB_R})
    n = 24
    for i in range(n):
        a = 360.0 * (i + 0.5) / n
        if any(abs((a - g + 180.0) % 360.0 - 180.0) < 16.0 for g in HUB_GATES):
            continue
        q = H(HUB_R, a)
        bl.barricade(z, d, q, bl.facing(math.cos(math.radians(a)), math.sin(math.radians(a))) + (i % 3 - 1) * 6.0, 3.9)
    z.data["town"] = {"center": [0.0, 0.0], "radius": HUB_R, "gates": [list(H(HUB_R, g)) for g in HUB_GATES]}
    pole = d.m("posto_mastro", (0.5, 0.52, 0.58))
    for g in HUB_GATES:                                       # mastros cinza com pano azul-ardósia nos vãos (a festa não entra aqui)
        for s in (-1, 1):
            q = H(HUB_R + 0.3, g + s * 13.0)
            d.flag(q, (0.46, 0.54, 0.7), 4.4, -g + 90.0, pole=(0.5, 0.52, 0.58), tatter=False, w=1.0, drop=1.5)
            z.ob("pillar", q[0], q[1], (0.6, 4.4, 0.6), visible=False)
    for k, a in enumerate((-135.0, -45.0, 135.0)):
        q = H(9.6, a)
        d.tent_aurora(q, -a + 90.0, 1.0, color=(0.74, 0.78, 0.84), trim=(0.42, 0.48, 0.62), gold=(0.9, 0.9, 0.86))
        d.solid(q[0], q[1], 3.2, 3.2, 3.0)
    d.cookfire((0.0, 0.0), 1.1, 20.0)
    d.solid(0.0, 0.0, 1.9, 1.9, 1.0)
    d.cargo(H(11.0, 28.0), 5, 1.3)
    d.cargo(H(11.5, 62.0), 3, 1.0)
    d.weapon_rack(H(11.5, -62.0), 28.0)
    plinth = H(7.5, 45.0)
    st = d_l2.m("posto_pedestal", (0.7, 0.74, 0.8))
    d_l2.cyl("cristal", st, plinth, 1.5, 1.35, 0.3, 0.0, 8)
    d_l2.cyl("cristal", st, plinth, 1.05, 0.95, 0.3, 0.3, 8)
    for k in range(4):
        d_l2.cyl("cristal", st, H(1.9, 45.0 + 90.0 * k, plinth), 0.16, 0.12, 1.1, 0.0, 5)
    z.npc("parade_post_captain", 2.6, -2.8, -140.0)           # capitã do Posto (missões do Cortejo)
    z.npc("parade_post_quartermaster", *H(8.0, 20.0), -110.0) # intendente (mercador)
    z.npc("parade_post_medic", *H(7.0, 150.0), 110.0)         # curandeiro (poções)
    z.data["hangouts"] = [list(H(r, a)) for r, a in ((3.6, 60.0), (3.8, 170.0), (3.6, -70.0), (7.5, 95.0), (8.0, -90.0), (11.0, 178.0),
                                                      (11.5, 0.0), (11.0, 100.0))]
    z.cam_game = (0.0, 0.0)
    z.block((0.0, 0.0), HUB_R + 5.0)
    return plinth


def ribbon_arch(z, d, c, rot):
    """MARCO: o Arco do Triunfo de Fitas (16 m). Dois pilares creme, a verga com cornija, o ático com a máscara, e as fitas
    compridas (pano dobrado, cores da festa) caindo do vão e dos cantos. Peça alta: o jogo a deixa translúcida na frente do boneco."""
    st, std = d.m("arco_pedra", STONE), d.m("arco_pedra_esc", STONE_D)
    gold = d.m("arco_ouro", bl.OLD_GOLD)
    d.tall(c)
    for s in (-1, 1):
        q = bl.loc(c, rot, s * 6.2, 0.0)
        d.box("arco", std, q, (3.8, 0.8, 3.8), rot, 0.0)
        d.box("arco", st, q, (3.2, 11.4, 3.2), rot, 0.8)
        d.box("arco", gold, q, (3.5, 0.3, 3.5), rot, 9.4)
    d.box("arco", st, c, (15.8, 2.4, 3.4), rot, 12.2)
    d.box("arco", std, c, (16.8, 0.5, 4.2), rot, 14.6)
    d.box("arco", st, c, (9.0, 1.5, 3.0), rot, 15.1)
    d.box("arco", gold, c, (9.4, 0.25, 3.3), rot, 16.6)
    for f in (1, -1):
        bl.mask(d, "arco", bl.loc(c, rot, 0.0, f * 1.56), 15.85, rot + (0.0 if f > 0 else 180.0), 1.5)
    k = 0
    for x in (-3.9, -2.6, -1.3, 0.0, 1.3, 2.6, 3.9):          # fitas do vão (mais curtas no meio: passa gente por baixo)
        col = bl.BUNTING[k % len(bl.BUNTING)]
        cm = d.m("pano_fita_%d_%d" % (int(col[0] * 100), int(col[2] * 100)), col)
        drop = 4.0 + abs(x) * 1.4
        d.cloth("arco", cm, bl.loc(c, rot, x - 0.45, 0.6 if k % 2 else -0.6), 0.9, drop, rot, 12.2 - drop, 0.0)
        k += 1
    for s in (-1, 1):                                         # fitas dos cantos, presas em estacas no chão
        for f in (-1, 1):
            a, b = bl.loc(c, rot, s * 8.0, f * 1.6), bl.loc(c, rot, s * 13.5, f * 6.5)
            col = bl.BUNTING[(k + s + f) % len(bl.BUNTING)]
            d.tube("arco", d.m("fita_%d_%d" % (int(col[0] * 100), int(col[2] * 100)), col),
                   [(a[0], 14.4, a[1]), ((a[0] + b[0]) * 0.5, 5.6, (a[1] + b[1]) * 0.5), (b[0], 0.3, b[1])], 0.12, 0.08, 4)
            k += 1
    d.tall()
    for s in (-1, 1):
        q = bl.loc(c, rot, s * 6.2, 0.0)
        z.ob("pillar", q[0], q[1], (3.8, 12.0, 3.8), rot, visible=False)
    z.block(c, 11.0)


def bleacher(z, d, c, rot, L=15.0, steps=5):
    """Um lance de arquibancada: degraus que sobem para trás (-yb), almofadas de cor nos assentos, guarda atrás e toldo."""
    wood, wood_d = d.m("arq_madeira", WOOD), d.m("arq_madeira_esc", (0.48, 0.36, 0.28))
    for i in range(steps):
        d.box("arquibancada", wood if i % 2 else wood_d, bl.loc(c, rot, 0.0, 2.0 - i * 1.0), (L, 0.55 * (i + 1), 1.0), rot, 0.0)
        for k in range(int(L / 2.4)):
            if (k + i) % 3 == 0:
                continue
            col = bl.BUNTING[(k + i * 2) % len(bl.BUNTING)]
            d.box("arquibancada", d.m("almofada_%d_%d" % (int(col[0] * 100), int(col[2] * 100)), col),
                  bl.loc(c, rot, -L * 0.5 + 1.2 + k * 2.4, 2.0 - i * 1.0), (1.3, 0.1, 0.6), rot, 0.55 * (i + 1))
    d.box("arquibancada", wood_d, bl.loc(c, rot, 0.0, 2.0 - steps * 1.0 + 0.35), (L, 0.55 * steps + 1.1, 0.2), rot, 0.0)
    for s in (-1, 1):
        d.flag(bl.loc(c, rot, s * (L * 0.5 - 0.3), -steps + 2.3), bl.BUNTING[(int(c[0]) + s) % len(bl.BUNTING)], 0.55 * steps + 4.0, rot + 90.0, tatter=False)
    z.ob("wall", *bl.loc(c, rot, 0.0, 2.5 - steps * 0.5), (L, 3.0, steps * 1.0 + 0.4), rot, visible=False)


def grandstands(z, d, c):
    """Arquibancadas: três lances em ferradura (aberta para leste, de onde vem a estrada) em volta da pista de terra batida,
    com o estrado dos juízes no meio. Os lances ficam ao norte, a oeste e ao sul-oeste: nenhum tapa a pista para a câmera."""
    z.patch("pista", c, 15.0, (0.76, 0.72, 0.62))
    light, dark = act2_dress.floor_tones(d, "pista", (0.76, 0.72, 0.62))
    for k in range(10):                                       # raia oval em tons do chão
        a0 = math.tau * k / 10
        d.arc("pista", dark if k % 2 else light, c, 9.5, a0, a0 + 0.5, 0.5, 0.0076, 0.2)
    for a in (-90.0, 180.0, 118.0):
        q = H(17.5, a, c)
        bleacher(z, d, q, bl.facing(c[0] - q[0], c[1] - q[1]), 14.0 if a != 180.0 else 16.0)
    wood = d.m("arq_madeira", WOOD)
    d.box("arquibancada", wood, (c[0] - 3.0, c[1] - 1.0), (4.0, 0.9, 3.0), 12.0, 0.0)          # estrado dos juízes, com o toldo caído
    d.awning((c[0] - 3.0, c[1] - 1.0), 4.4, 3.4, 12.0, (0.94, 0.8, 0.84), h=3.2, stripes=(0.98, 0.94, 0.86))
    d.solid(c[0] - 3.0, c[1] - 1.0, 4.0, 3.0, 2.0, 12.0)
    z.block(c, 23.0)


def parade_float(z, d, c, rot, kind):
    """Carro alegórico tombado: estrado inclinado com saia de pano, rodas (uma solta no chão) e a alegoria caída.
    kind: 0 máscara gigante, 1 bolo de andares, 2 leque, 3 taça."""
    wood = d.m("carro_madeira", WOOD)
    wheel = d.m("carro_roda", (0.34, 0.26, 0.24))
    gold = d.m("carro_ouro", bl.OLD_GOLD)
    col = bl.BUNTING[kind % len(bl.BUNTING)]
    skirt = d.m("carro_saia_%d" % kind, col)
    tilt = (10.0, 7.0) if kind % 2 else (-8.0, 9.0)
    d.box("carro", wood, c, (7.4, 0.5, 3.8), rot, 0.9, tilt)
    d.box("carro", skirt, c, (7.5, 0.7, 3.9), rot, 0.25, tilt)
    d.box("carro", gold, c, (7.6, 0.14, 4.0), rot, 0.92, tilt)
    for sx in (-2.6, 2.6):
        for sy in (-1.0, 1.0):
            if sx > 0 and sy > 0:
                continue
            d.cyl("carro", wheel, bl.loc(c, rot, sx, sy * 2.1), 0.8, 0.8, 0.22, 0.8, 8, rot, tilt=(90, 0))
    d.cyl("carro", wheel, bl.loc(c, rot, 4.6, 3.6), 0.8, 0.8, 0.22, 0.02, 8)                   # a roda que saiu
    d.box("carro", wood, bl.loc(c, rot, -5.2, 0.0), (3.4, 0.14, 0.14), rot, 0.5, (0, -8))          # o varal
    top = 1.3
    if kind == 0:
        mrot = bl.facing(0.25, 1.0)                           # a máscara gigante olha para o sul (para a câmera), seja qual for o giro do carro
        mc = bl.loc(c, rot, 0.4, 0.0)
        bl.mask(d, "carro", mc, top + 2.5, mrot, 3.2)
        d.box("carro", gold, bl.loc(mc, mrot, 0.0, -0.6), (0.5, 4.4, 0.3), mrot, top, (10, 0))
    elif kind == 1:
        cake = [d.m("bolo_a", (0.96, 0.9, 0.86)), d.m("bolo_b", (0.94, 0.76, 0.8)), d.m("bolo_c", (0.86, 0.9, 0.78))]
        for i, (r, h, x) in enumerate(((1.7, 1.3, -1.2), (1.3, 1.1, 0.2), (0.9, 1.0, 1.4))):      # os andares escorregaram uns dos outros
            d.cyl("carro", cake[i], bl.loc(c, rot, x, 0.3 * i), r, r * 0.94, h, top + i * 0.5, 10, rot, tilt=(0, 14.0 + 16.0 * i))
        d.cyl("carro", gold, bl.loc(c, rot, 3.0, 1.2), 0.3, 0.05, 1.2, 0.3, 6, rot, tilt=(0, 80))
    elif kind == 2:
        for i in range(7):                                    # leque: varetas abertas em meia-lua, o pano entre elas
            a = math.radians(-60.0 + 20.0 * i)
            p = bl.loc(c, rot, math.sin(a) * 1.9, -0.6)
            d.box("carro", gold, p, (0.16, 3.9, 0.12), rot, top + 0.1, (0, math.degrees(a)))
            if i < 6:
                a2 = math.radians(-50.0 + 20.0 * i)
                pc = bl.loc(c, rot, math.sin(a2) * 2.3, -0.56)
                d.box("carro", d.m("leque_pano_%d" % (i % 2), [(0.96, 0.84, 0.88), (0.86, 0.9, 0.98)][i % 2]), pc, (1.25, 2.6, 0.05), rot,
                      top + 1.2, (0, math.degrees(a2)))
    else:
        d.cyl("carro", gold, bl.loc(c, rot, -1.5, 0.2), 0.9, 0.3, 0.5, top + 0.9, 8, rot, tilt=(0, 70))          # taça deitada
        d.cyl("carro", gold, bl.loc(c, rot, -1.0, 0.2), 0.24, 0.24, 2.2, top + 0.9, 6, rot, tilt=(0, 70))
        d.cyl("carro", gold, bl.loc(c, rot, 1.1, 0.2), 0.3, 1.5, 2.4, top + 0.9, 10, rot, tilt=(0, 70))
        d.cyl("carro", d.m("vinho_fosco", bl.WINE), bl.loc(c, rot, 4.8, 1.0), 1.6, 1.6, 0.03, 0.01, 10)             # a poça fosca
    for k in range(3):                                        # fitas arrastadas pelo chão
        a = bl.loc(c, rot, -3.0 + k * 3.0, 1.9)
        b = bl.loc(c, rot, -4.0 + k * 3.6, 5.0 + k)
        colk = bl.BUNTING[(kind + k + 1) % len(bl.BUNTING)]
        d.tube("carro", d.m("fita_%d_%d" % (int(colk[0] * 100), int(colk[2] * 100)), colk),
               [(a[0], 1.0, a[1]), ((a[0] + b[0]) * 0.5, 0.12, (a[1] + b[1]) * 0.5 + 0.6), (b[0], 0.06, b[1])], 0.1, 0.07, 4)
    z.ob("wall", c[0], c[1], (7.6, 3.0, 4.2), rot, visible=False)
    z.block(c, 6.0)


def conservatory(z, d, c):
    """Conservatório do Coro Ferido: salão comprido de telhado lilás, rotunda na frente com cúpula e duas alas de tubos
    de órgão de ouro velho (em V, como um órgão) na fachada e na cumeeira. A porta (dg_conservatory) olha para oeste."""
    rot = bl.facing(-1.0, 0.0)                                # +yb local = oeste
    bl.house(z, d, c, rot, 20.0, 11.0, 6.2, (0.93, 0.89, 0.84), (0.66, 0.58, 0.82), name="conservatorio", extra=False)
    st, std = d.m("cons_pedra", STONE), d.m("cons_pedra_esc", STONE_D)
    gold = d.m("cons_tubo", bl.OLD_GOLD)
    gold_d = d.m("cons_tubo_esc", (0.66, 0.56, 0.36))
    rc = bl.loc(c, rot, 0.0, 7.0)
    d.cyl("conservatorio", std, rc, 5.0, 4.8, 0.5, 0.0, 12)
    d.cyl("conservatorio", st, rc, 4.4, 4.2, 6.6, 0.5, 12)
    d.cyl("conservatorio", std, rc, 4.6, 4.6, 0.4, 7.1, 12)
    d.cyl("conservatorio", d.m("cons_cupula", (0.74, 0.66, 0.88)), rc, 4.3, 0.9, 2.8, 7.5, 12)
    d.cyl("conservatorio", gold, rc, 0.3, 0.1, 2.2, 10.3, 6)
    door = bl.loc(c, rot, 0.0, 11.3)
    d.box("conservatorio", d.m("dungeon_boca", (0.04, 0.03, 0.05)), door, (2.8, 3.2, 0.9), rot, 0.0)
    d.box("conservatorio", st, bl.loc(c, rot, 0.0, 11.7), (4.4, 0.7, 0.9), rot, 3.2)
    d.box("conservatorio", d.m("glow_dg_conservatory", (0.72, 0.9, 1.0)), bl.loc(c, rot, 0.0, 11.82), (2.2, 2.7, 0.1), rot, 0.08)
    bl.mask(d, "conservatorio", bl.loc(c, rot, 0.0, 12.2), 4.9, rot, 1.2)
    for s in (-1, 1):                                         # tubos da fachada: sobem para fora
        for k in range(7):
            q = bl.loc(c, rot, s * (5.4 + k * 0.72), 5.9)
            h = 3.2 + k * 0.75
            d.cyl("conservatorio", gold if k % 2 else gold_d, q, 0.3, 0.3, h, 0.0, 6)
            d.cyl("conservatorio", gold_d, q, 0.34, 0.2, 0.4, h, 6)
    for k in range(-5, 6):                                    # tubos da cumeeira: um V invertido
        q = bl.loc(c, rot, k * 1.5, -1.0)
        d.cyl("conservatorio", gold if k % 2 else gold_d, q, 0.26, 0.26, 3.6 - abs(k) * 0.42, 7.2, 6)
    z.ob("pillar", rc[0], rc[1], (9.4, 8.0, 9.4), rot, visible=False)
    for s in (-1, 1):
        z.ob("wall", *bl.loc(c, rot, s * 7.6, 5.9), (5.4, 5.0, 1.0), rot, visible=False)
        z.ob("lamp", *bl.loc(c, rot, s * 3.4, 14.5), (0.4, 2.8, 0.4))
    z.block(c, 13.0)
    z.block(rc, 8.0)
    return bl.loc(c, rot, 0.0, 13.6), bl.loc(c, rot, 0.0, 18.5)


def grand_stage(z, d, d_cur, d_veil, c):
    """Palco Grande: tablado de 24 m, torres de moldura, viga com a máscara, coxias de veludo. A frente (+yb) olha para o SUL:
    o largo da Prima-Donna fica entre o palco e a câmera. Fundo: a cortina fechada (até hx3_veil_open) ou o Véu Rasgado."""
    rot = bl.facing(0.0, 1.0)
    wood, wood_d = d.m("palco_madeira", (0.66, 0.5, 0.36)), d.m("palco_madeira_esc", (0.5, 0.38, 0.3))
    gold = d.m("palco_filete", bl.OLD_GOLD)
    st = d.m("arco_pedra", STONE)
    d.box("palcao", wood, c, (24.0, 1.4, 9.0), rot, 0.0)
    d.box("palcao", gold, bl.loc(c, rot, 0.0, 4.5), (24.2, 0.2, 0.16), rot, 1.25)
    d.box("palcao", wood_d, bl.loc(c, rot, 0.0, 5.3), (9.0, 0.7, 1.6), rot, 0.0)
    d.box("palcao", wood_d, bl.loc(c, rot, 0.0, 6.4), (9.0, 0.35, 0.8), rot, 0.0)
    for k in range(-5, 6):                                    # ribalta: lanternas apagadas na beira do tablado
        if abs(k) < 2:
            continue
        d.box("palcao", d.m("lanterna_apagada", (0.84, 0.78, 0.72)), bl.loc(c, rot, k * 2.1, 4.2), (0.34, 0.3, 0.34), rot + 45.0, 1.4)
    for s in (-1, 1):
        q = bl.loc(c, rot, s * 11.0, -3.0)
        d.box("palcao", st, q, (2.6, 10.0, 2.6), rot, 1.4)
        d.box("palcao", gold, q, (2.9, 0.3, 2.9), rot, 9.4)
        d.cyl("palcao", d.m("palco_teto", (0.9, 0.62, 0.66)), q, 2.2, 0.0, 2.4, 11.4, 4, rot + 45.0)
        cm = d.m("pano_palco_%d" % int(VELVET[0] * 100), VELVET)
        hm = d.m("pano_palco_%d_barra" % int(VELVET[0] * 100), tuple(k * 0.8 for k in VELVET))
        d.cloth("palcao", cm, bl.loc(c, rot, s * 9.6, -2.4), 2.8, 8.4, rot + (0.0 if s < 0 else 180.0), 1.6, 0.0, None, hm)
    d.box("palcao", st, bl.loc(c, rot, 0.0, -3.0), (24.6, 1.5, 2.2), rot, 10.2)
    d.box("palcao", gold, bl.loc(c, rot, 0.0, -3.0), (25.0, 0.25, 2.5), rot, 11.7)
    bl.mask(d, "palcao", bl.loc(c, rot, 0.0, -1.85), 12.9, rot, 2.2)
    back = d_cur.m("pano_palco_fundo", (0.92, 0.84, 0.88))
    for k in range(5):                                        # L0: a cortina do fundo, fechada
        d_cur.cloth("palcao", back, bl.loc(c, rot, -9.0 + k * 3.6, -3.3), 3.6, 8.6, rot, 1.6, 0.0, "swallow", None)
    torn = d_veil.m("pano_palco_fundo", (0.92, 0.84, 0.88))
    for k in (0, 4):                                          # L3b: o Véu Rasgado (o meio abriu)
        d_veil.cloth("palcao", torn, bl.loc(c, rot, -9.0 + k * 3.6, -3.3), 3.6, 8.6, rot, 1.6, 0.0, "teeth", None)
    for x, w, drop in ((-5.2, 1.6, 4.0), (4.0, 1.4, 3.2)):
        d_veil.cloth("palcao", torn, bl.loc(c, rot, x, -3.3), w, drop, rot, 10.2 - drop, 0.0, "teeth", None)
    d_veil.box("veu", d_veil.m("glow_veu", (0.98, 0.9, 0.96)), bl.loc(c, rot, 0.0, -3.2), (2.6, 8.0, 0.2), rot, 1.5)
    d_veil.box("veu", d_veil.m("glow_veu_borda", (0.86, 0.74, 0.92)), bl.loc(c, rot, 0.0, -3.3), (3.4, 8.6, 0.12), rot, 1.45)
    # escada da coxia oeste (+x local = oeste): é por ela que se chega ao Véu; o portal fica aqui, a 25 m do meio do largo
    # (quem volta da Fenda não cai em cima da Prima-Donna)
    d.box("palcao", wood_d, bl.loc(c, rot, 13.4, 1.0), (2.8, 0.7, 3.2), rot, 0.0)
    d.box("palcao", wood_d, bl.loc(c, rot, 14.9, 1.0), (1.2, 0.35, 3.2), rot, 0.0)
    for k, (x, yb) in enumerate(((-16.0, 3.0), (-19.5, -2.5))):      # L3b: o Posto da Aurora ao lado do palco (sem colisor: peça de estágio)
        d_veil.tent_aurora(bl.loc(c, rot, x, yb), rot - 30.0 + k * 50.0, 0.9)
    for yb in (-1.2, 3.2):
        d_veil.flag(bl.loc(c, rot, 16.6, yb), (0.96, 0.9, 0.62), 5.0, rot + 90.0, tatter=False)
    z.ob("wall", c[0], c[1], (24.0, 6.0, 9.0), rot, visible=False)
    z.ob("wall", *bl.loc(c, rot, 0.0, 5.7), (9.0, 1.0, 2.4), rot, visible=False)
    z.ob("wall", *bl.loc(c, rot, 13.4, 1.0), (2.8, 1.0, 3.2), rot, visible=False)
    z.block(c, 14.0)
    return bl.loc(c, rot, 17.6, 1.0), bl.loc(c, rot, 21.5, 4.5)


def prima_arena(z, d, c):
    """Largo da Prima-Donna: calçada redonda de mosaico desbotado, anéis em TONS DO PRÓPRIO CHÃO (três, como os tempos da
    ária), bancos baixos por fora. Nada sólido dentro do raio da luta."""
    z.plaza("palco", c, ARENA_R + 0.5, "pave_avenida")
    light, dark = act2_dress.floor_tones(d, "largo", PAVE)
    for k, r in enumerate((4.0, 8.0, 12.0)):
        for j in range(8):
            a0 = math.tau * j / 8 + k * 0.3
            d.arc("largo", dark if (j + k) % 2 else light, c, r, a0, a0 + 0.55, 0.5, 0.0145 + 0.0002 * k, 0.15)
    wood = d.m("arq_madeira", WOOD)
    for k in range(12):
        a = 360.0 * k / 12 + 15.0
        if 230.0 < a < 310.0 or 150.0 < a < 210.0 or a < 30.0 or a > 330.0:      # vãos: palco (norte), avenida (oeste), estrada (leste)
            continue
        q = H(ARENA_R + 2.4, a, c)
        d.box("largo", wood, q, (3.0, 0.5, 0.7), -a + 90.0, 0.0)
        d.solid(q[0], q[1], 3.0, 0.8, 0.6, -a + 90.0)
    z.block(c, ARENA_R + 4.0)


def avenue_dress(z, d, poly, rnd):
    """A avenida: mosaico desbotado (ladrilhos em dois tons do próprio chão), bandeirolas dobradas dos dois lados e
    palcos baixos de rua. Os ladrilhos ficam 0,3 mm acima da fita (12,0 mm)."""
    light, dark = act2_dress.floor_tones(d, "avenida", PAVE, 0.09)
    rose = d.m("patch_tom_avenida_rosado", (0.84, 0.76, 0.74))
    n = len(poly)
    for i in range(2, n - 2):
        t = (poly[i + 1] - poly[i - 1]).normalized()
        nr = Vector((-t.y, t.x))
        for _ in range(3):
            q = poly[i] + nr * rnd.uniform(-AVENUE_W * 0.44, AVENUE_W * 0.44) + t * rnd.uniform(-0.8, 0.8)
            s = rnd.uniform(0.55, 1.0)
            d.box("mosaico", (light, dark, rose)[rnd.randrange(3)], (q.x, q.y), (s, 0.003, s), along(t.x, t.y) + (45.0 if rnd.random() < 0.5 else 0.0), 0.0123)
    acc, k = 0.0, 0
    for i in range(3, n - 3):
        acc += (poly[i] - poly[i - 1]).length
        if acc < 11.0:
            continue
        acc = 0.0
        t = (poly[i + 1] - poly[i - 1]).normalized()
        nr = Vector((-t.y, t.x))
        ends = []
        for s in (-1, 1):
            q = poly[i] + nr * s * (AVENUE_W * 0.5 + 1.1)
            if d.ok(q.x, q.y, 0.4, road=-3.0):
                d.flag((q.x, q.y), bl.BUNTING[(k + (s > 0)) % len(bl.BUNTING)], 5.2, along(t.x, t.y) + (0.0 if s > 0 else 180.0), pole=(0.86, 0.8, 0.74), tatter=k % 4 == 3)
                ends.append(q)
        if len(ends) == 2 and k % 2 == 0:                     # varal de bandeirolas dobradas atravessando a avenida (de cima: linha pontilhada)
            a, b = ends
            mid = (a + b) * 0.5
            d.tube("varal", d.m("festa_cordao", (0.5, 0.42, 0.4)), [(a.x, 5.1, a.y), (mid.x, 4.5, mid.y), (b.x, 5.1, b.y)], 0.03, 0.03, 3)
            for j in range(1, 8):
                u = j / 8.0
                q = a.lerp(b, u)
                col = bl.BUNTING[(j + k) % len(bl.BUNTING)]
                d.cloth("varal", d.m("pano_fita_%d_%d" % (int(col[0] * 100), int(col[2] * 100)), col), (q.x, q.y), 0.55, 0.7,
                        along(nr.x, nr.y), 5.1 - 0.6 * math.sin(math.pi * u) - 0.72, -0.27, "swallow")
        k += 1


def build(export=False):
    z = Zone(ZONE, size=260.0, rim=(116.0, 5.0, 4.0, 2.0), seed=59, palette={
        "road": (0.84, 0.78, 0.68), "street": (0.84, 0.8, 0.74), "pave_avenida": PAVE, "water": (0.56, 0.74, 0.86),
        "cliff_rock": (0.62, 0.66, 0.48), "cliff_rock_d": (0.52, 0.57, 0.43), "cliff_grass": (0.6, 0.7, 0.46),
        "hill_grass": (0.64, 0.72, 0.48), "leaf": (0.42, 0.6, 0.42), "wood": WOOD,
    })
    z.trail_color = (0.8, 0.74, 0.64)
    dn = Dress(z, seed=301)
    d_l2 = Dress(z, seed=302, tag="l2_cristal", when={"if": Q_CELLARS})
    d_cur = Dress(z, seed=303, tag="l0_cortina", when={"unless": Q_VEIL_OPEN})
    d_veil = Dress(z, seed=304, tag="l3b_veu", when={"if": Q_VEIL_OPEN})
    widths = {}

    def road(name, pts, w=zone_lib.ROAD_W, material="road"):
        widths[name] = w
        return z.road(name, pts, w=w, material=material, end_clearing=False)

    # ---------- chegada (noroeste) e volta para Lumeria ----------
    portal, arrive = polar(z, ARRIVE_DEG, 7), polar(z, ARRIVE_DEG, 16)
    z.data["spawn"] = list(arrive)
    z.portal("to_city_lumeria", portal, "city_lumeria", LUMERIA_ARRIVE, "Lumeria, a Festa Eterna (Lv 45-47)")
    z.block(arrive, 7.5)
    print("BACK lumeria (target_pos do portal de Lumeria para o Cortejo)", arrive, "rumo %.0f" % (math.degrees(math.atan2(arrive[0], -arrive[1])) % 360.0))
    crystal = post(z, dn, d_l2)

    # ---------- a avenida em S e as estradas (laços, sem beco) ----------
    av = road("avenida", [portal, arrive, (-58.0, -57.0), (-40.0, -46.0), (-29.0, -26.0), (-29.0, -4.0), (-22.0, 18.0), (-10.0, 36.0), (-2.0, 54.0),
                          (4.0, 69.0), (15.0, 76.0)], w=AVENUE_W, material="pave_avenida")
    road("posto_oeste", [(-HUB_R + 1.0, 0.0), (-22.0, -2.0), (-29.0, -4.0)])
    road("posto_sul", [(0.0, HUB_R - 1.0), (-4.0, 26.0), (-10.0, 36.0)])
    road("norte", [(0.0, -HUB_R + 1.0), (5.0, -34.0), (0.0, -52.0), (6.0, -64.0)])
    road("carros_oeste", [(6.0, -64.0), (-12.0, -71.0), (-30.0, -62.0), (-40.0, -46.0)])
    road("carros_leste", [(6.0, -64.0), (30.0, -63.0), (52.0, -48.0), (66.0, -28.0), CONS_FRONT])
    road("leste", [(HUB_R - 1.0, 0.0), (34.0, -5.0), (54.0, -2.0), CONS_FRONT])
    road("conservatorio_sul", [CONS_FRONT, (75.0, 16.0), (68.0, 40.0), (58.0, 62.0), (46.0, 75.0)])
    road("arquibancadas", [(-29.0, -4.0), (-46.0, 3.0), (-60.0, 12.0), (-63.0, 28.0), (-58.0, 44.0), (-42.0, 55.0), (-22.0, 58.0), (-2.0, 54.0)])
    z.arrival(arrive, toward=portal, material="pave_avenida")
    z.plaza("largo_conservatorio", CONS_FRONT, 6.5, "road")
    z.lake("espelho", POND, POND_R)

    # ---------- chão ----------
    tones = act2_dress.floor_tone_colors(GROUND, 0.07)
    dn.mottle([("campo_claro", tones[0]), ("campo_esc", tones[1]), ("campo_palha", (0.72, 0.71, 0.54))], [((0, 0), 110, 150)], y=0.0008, rmin=4.0, rmax=9.0)
    for i, (c, r) in enumerate([((-44.0, -18.0), 15.0), (FLOATS, 20.0), ((56.0, 30.0), 13.0), ((-40.0, 74.0), 13.0), ((36.0, -30.0), 12.0)]):
        z.patch("feira_%d" % i, c, r, [(0.74, 0.72, 0.6), (0.7, 0.7, 0.58)][i % 2], grass=True)      # terreiros pisados da feira

    # ---------- POIs ----------
    arch_rot = bl.facing(0.8, 0.6)
    ribbon_arch(z, dn, ARCH, arch_rot)
    old = [Vector(bl.loc(ARCH, arch_rot, 0.0, yb)) for yb in (-16.0, -8.0, 0.0, 8.0, 15.0)]      # o traçado antigo da avenida passa debaixo do arco
    dn.strip("avenida_velha", dn.m("patch_avenida_velha", (0.8, 0.75, 0.7)), old, 6.0, 0.0072, 0.3, taper=True)
    grandstands(z, dn, STANDS)
    z.patch("carros", FLOATS, 8.0, (0.78, 0.74, 0.64), y=0.0064)
    for k, (dx, dz, rot) in enumerate(((-11.0, -6.0, 25.0), (8.0, -9.0, -40.0), (13.0, 5.0, 80.0), (-6.0, 8.0, 150.0))):
        parade_float(z, dn, (FLOATS[0] + dx, FLOATS[1] + dz), rot, k)
    cons_portal, cons_front = conservatory(z, dn, CONS)
    veil_portal, veil_front = grand_stage(z, dn, d_cur, d_veil, STAGE)
    prima_arena(z, dn, ARENA)
    places.build(z, PLACES)
    z.data["places"].append({"id": "conservatorio", "type": "dungeon", "pos": list(CONS)})
    # Altar da Máscara Partida: a máscara de pedra rachada ao meio no centro do círculo
    half = dn.m("mascara_marfim", bl.IVORY)
    dn.cyl("altar", dn.m("arco_pedra_esc", STONE_D), ALTAR, 1.5, 1.3, 0.5, 0.0, 8)
    bl.mask(dn, "altar", (ALTAR[0] - 0.75, ALTAR[1]), 1.6, 20.0, 1.3)
    dn.box("altar", dn.m("mascara_olho", (0.2, 0.16, 0.22)), (ALTAR[0] + 0.1, ALTAR[1] + 0.05), (0.12, 2.4, 0.3), 20.0, 0.5)
    dn.box("altar", half, (ALTAR[0] + 1.3, ALTAR[1] + 0.8), (1.1, 0.24, 1.5), 50.0, 0.0, (0, 12))

    # ---------- relevo: morros de borda e afloramentos ----------
    for i, (c, r, lv) in enumerate([((-98.0, -20.0), 8.0, 2), ((92.0, 50.0), 8.0, 2), ((16.0, -106.0), 6.0, 1), ((-94.0, 62.0), 7.0, 2),
                                     ((96.0, -52.0), 7.0, 2), ((-10.0, 106.0), 6.5, 1), ((78.0, 84.0), 6.0, 1)]):
        z.hill("morro_%d" % i, c, r, lv, rock="cliff_rock", top="hill_grass", step=1.9)
    for i, (c, r) in enumerate([((28.0, 24.0), 4.5), ((-52.0, 30.0), 4.0), ((30.0, -44.0), 4.5), ((-70.0, -30.0), 4.5), ((52.0, -72.0), 4.0)]):
        z.terrace("afloramento_%d" % i, c, r, 1, top="cliff_grass")
    af.vine_hills(z, rock_cols=((0.94, 0.78, 0.82), (0.5, 0.62, 0.42), (0.9, 0.84, 0.6)))

    # ---------- vegetação ----------
    obs = z.data["obstacles"]
    z.scatter("tree", [((0, 0), 108, 30), ((60, 20), 20, 5), ((-30, 84), 20, 5), ((-70, -40), 18, 5)], 0, (1.7, 4.2, 1.7), TREES,
              margin=6.5, spacing=8.0, hub_r=HUB_R + 8.0)
    z.rim_belt(64, (1.6, 4.4, 1.6), TREES[:2])
    nrnd = random.Random(591)
    free = lambda x, zz, m: z.free(x, zz, m + 2.0, HUB_R + 5.0)
    nature.fix_trees(obs, nrnd)
    nature.scatter(z.ob, free, nrnd, "bush", [((0, 0), 106, 60)], (1.5, 0.85, 1.5), [(0.5, 0.64, 0.42), (0.9, 0.74, 0.8), (0.58, 0.68, 0.46)],
                   solid=False, margin=2.6, spacing=3.4, avoid=obs)
    nature.scatter(z.ob, free, nrnd, "flowers", [((0, 0), 104, 70)], (1.4, 0.4, 1.4), [(0.98, 0.78, 0.84), (0.99, 0.93, 0.66), (0.84, 0.74, 0.96)],
                   solid=False, margin=2.4, spacing=3.2, avoid=obs)
    nature.scatter(z.ob, free, nrnd, "rock", [((0, 0), 106, 22)], (1.4, 1.0, 1.2), [(0.74, 0.7, 0.64), (0.66, 0.62, 0.6)],
                   margin=3.8, spacing=4.0, scale=(0.7, 1.5), avoid=obs)
    nature.clear_banks(obs, [], [(POND, POND_R)], 0.0)
    nature.shore(z.ob, nrnd, [], [(POND, POND_R)], list(z.road_polys.values()), 0.0, colors=[(0.6, 0.7, 0.48), (0.7, 0.66, 0.76)], keep=0.6)

    # ---------- monstros (47-49; ids de MonstersCatalog.ACT3_MOBS). Teto do GDD §11: <= 140 vivos com x1,6 e escoltas ----------
    M = MOBS
    sp = z.spawner
    sp(M["convert"], -56.0, -44.0, 7, 3, 26.0)                # Convertidos: ao longo da avenida e nos terreiros
    sp(M["convert"], -44.0, -8.0, 7, 3, 26.0)
    sp(M["convert"], -34.0, 40.0, 7, 3, 26.0)
    sp(M["convert"], 30.0, -28.0, 7, 3, 26.0)                # WP5: a 40+ m do Posto (_check_zone_layout)
    sp(M["convert"], 44.0, 40.0, 7, 3, 26.0)
    sp(M["hound"], -74.0, 44.0, 8, 3, 26.0)                   # matilhas de Galgos
    sp(M["hound"], 38.0, -38.0, 8, 3, 26.0)
    sp(M["hound"], 62.0, 22.0, 8, 3, 26.0)
    sp(M["reflection"], -50.0, 70.0, 6, 2, 28.0)              # Reflexos: no Espelho d'Água e entre os carros
    sp(M["reflection"], -80.0, 56.0, 6, 2, 28.0)
    sp(M["reflection"], FLOATS[0] - 2.0, FLOATS[1] - 1.0, 6, 2, 28.0)
    sp(M["reflection"], 46.0, -18.0, 6, 2, 28.0)
    sp(M["first"], -40.0, -30.0, 4, 1, 150.0)                 # Primeiros Bailarinos (2 Bailarinos de escolta cada)
    sp(M["first"], FLOATS[0] + 2.0, FLOATS[1] - 16.0, 4, 1, 150.0)
    sp(M["first"], -16.0, 62.0, 4, 1, 150.0)
    sp(M["dancer"], -22.0, -52.0, 7, 3, 26.0)
    sp(M["dancer"], 56.0, 56.0, 7, 3, 26.0)
    sp(M["chorister"], 78.0, -30.0, 6, 3, 26.0)               # o Coro, em volta do Conservatório
    sp(M["chorister"], 61.0, 10.0, 6, 3, 26.0)
    sp(M["maestro"], 52.0, -30.0, 4, 1, 180.0)               # longe da porta do Conservatório
    sp(M["reveler"], -76.0, -34.0, 6, 3, 24.0)                # foliões que vieram da cidade
    sp(M["reveler"], 6.0, -42.0, 6, 3, 24.0)
    sp(M["master"], STANDS[0] + 4.0, STANDS[1] + 4.0, 4, 1, 180.0)      # o Mestre de Cerimônias na pista das arquibancadas
    # Galgo Alfa: ronda o trecho sul da avenida com o carro vazio (WP5: nem na chegada de Lumeria nem a 12 m do portão do Posto)
    alpha = [(p.x, p.y) for p in av[6:-4:7]][2:6]
    z.spawner(M["alpha"], round(alpha[0][0], 2), round(alpha[0][1], 2), 3, 1, 180.0, route=alpha)
    z.data["world_boss_hint"] = [{"id": BOSS_ID, "name": "A Prima-Donna do Palco", "level": 48, "pos": list(ARENA), "radius": 2.0,
                                  "arena_r": ARENA_R, "respawn": "Balance.WORLD_BOSS_RESPAWN_S (600)", "summons": [M["chorister"], M["chorister"]]}]
    print("vivos (x1,6 + escoltas + chefe de mundo e 2 lacaios): %d" % af.live_count(z, extra=3))

    # ---------- acabamento ----------
    rnd = random.Random(595)
    avenue_dress(z, dn, av, rnd)
    dn.road_edges((0.78, 0.75, 0.62), extra=1.4, skip=("avenida",))
    dn.strip("beira", dn.m("patch_acostamento", (0.78, 0.75, 0.62)), av, AVENUE_W + 1.6, 0.0098, 0.3)
    dn.roadside(dn.m("seixo", (0.76, 0.72, 0.66)), dn.m("capim_beira", (0.56, 0.66, 0.44)), every=8.0, skip=("avenida",))
    for frac, side in ((0.2, 1), (0.38, -1), (0.56, 1), (0.74, -1), (0.9, 1)):      # palcos baixos de rua ao longo da avenida
        i = int(len(av) * frac)
        t = (av[i + 1] - av[i - 1]).normalized()
        nr = Vector((-t.y, t.x)) * side
        q = av[i] + nr * (AVENUE_W * 0.5 + 4.0)
        if dn.ok(q.x, q.y, 4.2, road=-3.4, blocked=True):
            bl.stage(z, dn, (q.x, q.y), bl.facing(-nr.x, -nr.y), curtain=[VELVET, (0.36, 0.4, 0.62), (0.4, 0.56, 0.5)][int(frac * 10) % 3])
            dn.reserve(q.x, q.y, 5.0)
    for q in dn.spots([((0, 0), 104, 22)], r=1.6, spacing=15.0, blocked=True, road=2.2):      # restos da feira: bancas caídas, carga, mesas
        k = rnd.random()
        if any(math.hypot(q[0] - m["pos"][0], q[1] - m["pos"][1]) < 4.0 for m in z.data["spawners"]):
            continue                                          # nada sólido no miolo de um bando
        if k < 0.4:
            dn.awning(q, 3.0, 2.2, rnd.uniform(0, 180), bl.BUNTING[rnd.randrange(5)], h=2.3, stripes=(0.98, 0.95, 0.9))
            dn.solid(q[0], q[1], 2.8, 2.0, 2.0)
        elif k < 0.7:
            dn.cargo(q, 4, 1.2, g="feira")
        else:
            bl.banquet(z, dn, q, rnd.uniform(0, 180), 4.6)
    for k, (name, frac) in enumerate((("norte", 0.5), ("leste", 0.45), ("conservatorio_sul", 0.35), ("arquibancadas", 0.3), ("carros_leste", 0.3), ("carros_oeste", 0.6))):
        poly = z.road_polys[name]
        i = int(len(poly) * frac)
        t = (poly[i + 1] - poly[i - 1]).normalized()
        q = poly[i] + Vector((-t.y, t.x)) * 3.6
        dn.signpost((q.x, q.y), along(t.x, t.y)) if k % 2 == 0 else dn.flag((q.x, q.y), bl.BUNTING[k % 5], 4.6, along(t.x, t.y), tatter=True)

    # ---------- dados para a integração (WP5) ----------
    r2 = lambda p: [round(p[0], 2), round(p[1], 2)]
    z.data["future_portals"] = [
        {"id": "to_dg_conservatory", "pos": r2(cons_portal), "arrive": r2(cons_front), "target_map": "dg_conservatory",
         "label": "Conservatório do Coro Ferido (Lv 48-49)"},
        {"id": "to_rift_garden", "pos": r2(veil_portal), "arrive": r2(veil_front), "target_map": "rift_garden", "label": "O Véu Rasgado (Lv 49-50)",
         "level": 49, "if": [Q_MIRRORS, Q_VEIL_OPEN]},
    ]
    af.event_points(z, EVENT_POINTS, widths, bosses=[ARENA])
    print("eventos:", [(e["kind"], e["pos"]) for e in z.data["events"]])
    z.data["stage_tags"] = [{"tag": "l2_cristal", "if": Q_CELLARS}, {"tag": "l0_cortina", "unless": Q_VEIL_OPEN}, {"tag": "l3b_veu", "if": Q_VEIL_OPEN}]
    z.data["crystal_hint"] = {"pos": r2(crystal), "if": Q_CELLARS}
    z.data["stage_npcs"] = {"veil_aurora_officer": {"if": Q_VEIL_OPEN}}
    z.npc("veil_aurora_officer", round(veil_front[0] - 1.0, 2), round(veil_front[1] + 5.0, 2), 20.0)
    z.data["hangouts"] += [[CONS_FRONT[0] - 3.0, CONS_FRONT[1] + 3.0], [-33.0, -12.0], [ARENA[0] - 19.0, ARENA[1] + 6.0], [STANDS[0] + 14.0, STANDS[1] - 4.0]]
    z.data["poi"] = {"posto": [0.0, 5.0], "arco": [ARCH[0] + 5.0, ARCH[1] + 9.0], "arquibancadas": [STANDS[0] + 5.0, STANDS[1] + 2.0],
                     "carros": [FLOATS[0], FLOATS[1] + 3.0], "conservatorio": [CONS_FRONT[0] + 3.0, CONS_FRONT[1]], "palco": [ARENA[0], ARENA[1] - 6.0], "veu": [STAGE[0] - 14.0, STAGE[1] + 6.0],
                     "ponto": [PROMPTER[0] - 7.0, PROMPTER[1] - 5.0], "costureira": [SEAMSTRESS[0] + 4.0, SEAMSTRESS[1] - 5.0],
                     "altar": [ALTAR[0] - 5.0, ALTAR[1] + 5.0], "arraial": [CONVERT_CAMP[0] + 5.0, CONVERT_CAMP[1] + 7.0], "chegada": list(arrive)}
    z.data["landmark"] = {"id": "arco_de_fitas", "pos": list(ARCH), "height": 16.8}
    z.data["monster_ids"] = dict(MOBS)
    z.data["gather_hint"] = [
        {"item": "Fita do Festim", "shape": "crate", "pos": [FLOATS[0] + 2.0, FLOATS[1] + 16.0], "radius": 8.0, "count": 5},
        {"item": "Fita do Festim", "shape": "crate", "pos": [STANDS[0] + 16.0, STANDS[1] + 14.0], "radius": 7.0, "count": 3},
        {"item": "Porcelana Chorosa", "shape": "relic", "pos": [ALTAR[0] - 9.0, ALTAR[1] + 9.0], "radius": 6.0, "count": 2},
        {"item": "Porcelana Chorosa", "shape": "relic", "pos": [POND[0] + 14.0, POND[1] + 6.0], "radius": 6.0, "count": 2},
        {"item": "flor de papel (missão da Costureira)", "shape": "star", "pos": [-20.0, 76.0], "radius": 8.0, "count": 4},
    ]
    z.data["ground_hint"] = {"ground_color": list(GROUND), "note": "relva palida; a avenida e o material pave_avenida (calcamento)"}

    act3_ready.promote(z.data)       # future_portals de mapa já registrado viram portal (act3_ready.READY)
    for d in (dn, d_l2, d_cur, d_veil):
        d.flush()
    poi = z.data["poi"].get(os.environ.get("PARADE_POI", "palco"), z.data["poi"]["palco"])
    data = z.finish(export, poi=tuple(poi), ground=GROUND)
    af.walk_check(data)
    return data
