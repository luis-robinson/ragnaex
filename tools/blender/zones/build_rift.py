"""A Fenda: o Jardim Sem Fim (rift_garden, Ato III parte 1, Lv 49-50), atrás do Véu Rasgado do Palco Grande.
GDD design/gdd/ato3-excesso-45-50.md (§2.2, §3.1, §4). Zona em LAÇO: aceita montaria, tudo liga em anel.

  * CENTRO   Posto da Aurora na boca do Véu (hub): anel de sebe baixa com três vãos (leste, oeste, sul). O Véu fica
             encostado na sebe do norte, de frente para a câmera; quem chega nasce no meio do Posto. Cristal em L4.
  * ANEL     a Alameda: uma estrada de mármore em laço (~58 m do centro), sebe por fora com falhas, lanternas de pérola.
  * NORTE    Pavilhão da Anfitriã: arena redonda de 20 m (Vessaline: 4 investidas de 10 m, ilhas do Palco Seguro),
             colunata só na metade norte (nada tapa a luta), o divã no fundo e a COROA DE CRISTAL flutuante (marco).
  * OESTE    Alameda dos Espelhos: arco de fora ladeado de espelhos de pé foscos.
  * SUDESTE  Lago de Perfume (colide como água) com os frascos gigantes na margem; estrada em volta.
  * SUDOESTE Labirinto de Sebes: três anéis concêntricos, dois vãos por anel (sem beco), fonte no meio.
  * NORDESTE Porta do Coração (rift_heart, L4 = hx3_veil): selada antes, acesa depois.

Leitura de cima: relva pálida, estradas e largos de mármore, o verde escuro das sebes (muros baixos, <= 2,4 m), flores
gigantes e copas pastel. A cor quente fica nas flores, nos véus e na coroa: NENHUMA cor viva nem brilho no chão (§4.4).

Pilha de planos do chão (mm): manchas da relva 0,8/1,6/2,4 · manchas `Zone.patch` 5,2-6,8 · acostamento 9,8 ·
estrada 12 · ladrilhos da alameda 12,3 · largos 14 · anéis/rosácea da arena 14,5-14,9.

Estágios (data["stage_tags"]): l0_porta_selada (até hx3_veil) · l4_manha (hx3_veil: cristal do Posto, Porta acesa).

    blender -b --factory-startup --python tools/blender/zones/run_zone.py -- build_rift <pasta_png> --export
    (RIFT_POI=<pavilhao|posto|espelhos|lago|labirinto|coracao|anel_sul>)
"""
import math
import os
import random

from mathutils import Vector

import act2_dress
import act3_dress
import act3_fields as af
import act3_ready
import build_lumeria as bl
import nature
import zone_lib
from act3_fields import H
from dress import Dress
from zone_lib import Zone, along, angdiff, poly_dist

ZONE = "rift_garden"
PARADE_ARRIVE = (8.5, 59.5)              # chegada em field_parade (field_parade.json -> future_portals to_rift_garden "arrive")
HUB_R = 14.0
HUB_GATES = [0.0, 180.0, 90.0]           # leste, oeste, sul (o norte é o Véu)
VEIL = (0.0, -11.6)                      # o rasgo, encostado na sebe do norte
VEIL_PORTAL = (0.0, -10.2)
ARRIVE = (0.0, -4.0)                     # = act3_ready.ARRIVE["rift_garden"]
ARENA, ARENA_R = (0.0, -74.0), 20.0      # Pavilhão da Anfitriã
ADRO = (0.0, -49.0)
APSE = (0.0, -100.0)
LAB, LAB_RINGS = (-52.0, 64.0), (5.5, 9.5, 13.5)
LAB_GAPS = ((45.0, 225.0), (135.0, 315.0), (0.0, 270.0))      # vãos de cada anel (de dentro para fora), graus do jogo
LAKE, LAKE_R = (66.0, 54.0), 11.0
MIRRORS = (-72.0, 2.0)                   # miolo do laço da Alameda dos Espelhos
DOOR, HEART_FRONT = (80.0, -56.0), (74.0, -47.0)      # HEART_FRONT = places.DUNGEONS["rift_heart"]["return"]
Q_VEIL = "hx3_veil"
BOSS_ID = "vessaline"                    # id de trabalho (WP8): Vessaline, a Anfitriã do Véu
MOBS = {"seductress": "seductress", "flayer": "flayer", "singer": "veil_singer", "matriarch": "thirst_matriarch", "alpha": "parade_alpha",
        "first": "first_dancer", "reflection": "vain_reflection", "maestro": "choir_maestro", "master": "ceremony_master"}
ESCORT = dict(af.ESCORT, thirst_matriarch=3)      # 2 Sedutoras + 1 Açoitadora (GDD §3.1)

GROUND = (0.72, 0.78, 0.7)               # relva pálida (sugestão de MapDef.ground_color)
MARBLE = (0.9, 0.88, 0.87)
MARBLE_D = (0.78, 0.76, 0.78)
HEDGE = [(0.26, 0.46, 0.34), (0.3, 0.52, 0.38)]
HEDGE_TOP = (0.4, 0.62, 0.46)
PEARL = (0.98, 0.93, 0.88)
FLOWERS = [(0.96, 0.5, 0.66), (0.98, 0.76, 0.42), (0.72, 0.56, 0.94), (0.98, 0.92, 0.94)]
TREES = [(0.94, 0.76, 0.82), (0.84, 0.76, 0.94), (0.56, 0.74, 0.6), (0.96, 0.88, 0.7)]      # copas de jardim: rosa, lilás, menta, manteiga
RING = [(0.0, -47.0), (30.0, -44.0), (52.0, -26.0), (60.0, 2.0), (52.0, 30.0), (30.0, 50.0), (2.0, 58.0), (-28.0, 52.0),
        (-50.0, 32.0), (-60.0, 2.0), (-52.0, -26.0), (-30.0, -44.0), (0.0, -47.0)]


# ---------------------------------------------------------------------------------------------------------------
# peças
# ---------------------------------------------------------------------------------------------------------------
def hedge(z, d, a, b, k=0, h=2.2, w=1.3, collide=True):
    """Um lance de sebe aparada entre dois pontos (muro baixo: <= 2,4 m). Flores miúdas no topo de alguns lances."""
    a, b = Vector(a), Vector(b)
    t = b - a
    mid = (a + b) * 0.5
    rot = along(t.x, t.y)
    c = (mid.x, mid.y)
    d.box("sebe", d.m("sebe_%d" % (k % 2), HEDGE[k % 2]), c, (t.length + 0.2, h, w), rot, 0.0)
    d.box("sebe", d.m("sebe_topo", HEDGE_TOP), c, (t.length + 0.2, 0.14, w * 0.78), rot, h)
    if k % 3 == 0:
        col = FLOWERS[(k // 3) % len(FLOWERS)]
        fm = d.m("sebe_flor_%d_%d" % (int(col[0] * 100), int(col[2] * 100)), col)
        for u in (-0.3, 0.05, 0.34):
            q = bl.loc(c, rot, u * t.length, 0.2 if u > 0 else -0.25)
            d.box("sebe", fm, q, (0.34, 0.16, 0.34), rot + 45.0, h + 0.1)
    if collide:
        z.ob("wall", mid.x, mid.y, (t.length, h, w + 0.2), rot, visible=False)


def hedge_ring(z, d, c, r, gaps, half=2.3, h=2.2, seg=2.7):
    """Anel de sebe em volta de `c` com vãos (graus do jogo) de meia-largura `half` m."""
    n = max(10, int(math.tau * r / seg))
    for i in range(n):
        a0, a1 = math.tau * i / n, math.tau * (i + 1) / n
        am = (a0 + a1) * 0.5
        if any(angdiff(am, math.radians(g)) * r < half + seg * 0.5 for g in gaps):
            continue
        hedge(z, d, (c[0] + math.cos(a0) * r, c[1] + math.sin(a0) * r), (c[0] + math.cos(a1) * r, c[1] + math.sin(a1) * r), i, h)


def lantern(d, c, h=3.0):
    """Lanterna de pérola num poste claro (a luz do Jardim): baixa, não tapa o boneco."""
    d.cyl("lanterna", d.m("lanterna_poste", MARBLE_D), c, 0.14, 0.09, h, 0.0, 6)
    d.cyl("lanterna", d.m("lanterna_poste", MARBLE_D), c, 0.3, 0.2, 0.25, 0.0, 6)
    d.box("lanterna", d.m("glow_lanterna_perola", PEARL), c, (0.46, 0.56, 0.46), 45.0, h)
    d.cyl("lanterna", d.m("lanterna_tampa", bl.OLD_GOLD), c, 0.42, 0.0, 0.34, h + 0.56, 4, 45.0)


def giant_flower(d, c, hh, col, k=0):
    """Flor gigante (2,6-4,2 m): caule curvo, seis pétalas em taça, miolo de ouro velho e uma folha."""
    stem = d.m("flor_caule", (0.42, 0.62, 0.46))
    lean = ((k % 3) - 1) * 0.35
    d.tube("flor", stem, [(c[0], 0.0, c[1]), (c[0] + lean, hh * 0.55, c[1] + 0.2), (c[0], hh, c[1])], 0.17, 0.1, 5)
    pm = d.m("flor_petala_%d_%d" % (int(col[0] * 100), int(col[2] * 100)), col)
    for i in range(6):
        a = 60.0 * i + k * 17.0
        d.box("flor", pm, act3_dress.P(c, 0.82, a), (1.45, 0.14, 0.82), -a, hh, (0, -20))
    d.rock("flor", d.m("flor_miolo", bl.OLD_GOLD), c, 0.44, hh + 0.02, 0.7)
    d.box("flor", stem, act3_dress.P(c, 0.7, k * 77.0), (1.3, 0.08, 0.55), -k * 77.0, hh * 0.34, (0, 24))


def flacon(z, d, c, s=1.0, col=(0.9, 0.76, 0.86), rot=0.0):
    """Frasco de perfume gigante (margem do Lago): corpo facetado de vidro pastel, gargalo e tampa de ouro velho."""
    glass = d.m("frasco_%d_%d" % (int(col[0] * 100), int(col[2] * 100)), col)
    gold = d.m("frasco_ouro", bl.OLD_GOLD)
    d.cyl("frasco", gold, c, 1.25 * s, 1.2 * s, 0.25, 0.0, 8, rot)
    d.cyl("frasco", glass, c, 1.1 * s, 1.25 * s, 1.5 * s, 0.25, 8, rot)
    d.cyl("frasco", glass, c, 1.25 * s, 0.4 * s, 0.7 * s, 0.25 + 1.5 * s, 8, rot)
    d.cyl("frasco", gold, c, 0.3 * s, 0.3 * s, 0.4 * s, 0.25 + 2.2 * s, 6, rot)
    d.rock("frasco", gold, c, 0.46 * s, 0.25 + 2.5 * s, 0.9)
    z.ob("pillar", c[0], c[1], (2.5 * s, 3.2 * s, 2.5 * s), visible=False)


def crystal_spire(z, d, c, hh, k=0):
    """Agulha de cristal da borda (os "penhascos de cristal" do Jardim): fuste pálido, ponta acesa."""
    body = d.m("cristal_borda_%d" % (k % 2), [(0.86, 0.8, 0.94), (0.92, 0.84, 0.9)][k % 2])
    tilt = (((k * 7) % 5) - 2) * 3.0, (((k * 3) % 5) - 2) * 3.0
    d.cyl("agulha", body, c, 1.1, 0.6, hh * 0.72, 0.0, 6, k * 23.0, tilt)
    d.cyl("agulha", d.m("glow_cristal_borda", (0.98, 0.9, 0.98)), c, 0.6, 0.0, hh * 0.28, hh * 0.72, 6, k * 23.0, tilt)
    q = act3_dress.P(c, 1.2, k * 97.0)
    d.cyl("agulha", body, q, 0.6, 0.0, hh * 0.45, 0.0, 5, k * 41.0, (10, -8))
    z.ob("pillar", c[0], c[1], (2.4, hh, 2.4), visible=False)


def parterre(z, d, c, rot, k=0):
    """Canteiro de jardim: moldura de sebe baixa e flores (a cor viva fica nas flores, em volume, nunca pintada no chão)."""
    L, W = 4.2, 3.0
    hm = d.m("sebe_0", HEDGE[0])
    for s in (-1, 1):
        d.box("canteiro", hm, bl.loc(c, rot, 0.0, s * (W * 0.5 - 0.2)), (L, 0.55, 0.4), rot, 0.0)
        d.box("canteiro", hm, bl.loc(c, rot, s * (L * 0.5 - 0.2), 0.0), (0.4, 0.55, W - 0.8), rot, 0.0)
    d.box("canteiro", d.m("canteiro_terra", (0.52, 0.44, 0.42)), c, (L - 0.8, 0.3, W - 0.8), rot, 0.0)
    for i in range(3):
        for j in range(2):
            col = FLOWERS[(k + i + j) % len(FLOWERS)]
            d.rock("canteiro", d.m("canteiro_flor_%d_%d" % (int(col[0] * 100), int(col[2] * 100)), col), bl.loc(c, rot, -1.1 + i * 1.1, -0.5 + j * 1.0), 0.44, 0.28, 0.6)
    z.ob("crate", c[0], c[1], (L, 0.7, W), rot, visible=False)


def topiary(z, d, c, k=0):
    """Topiaria baixa (<= 2,6 m): cone, duas bolas ou cubos girados sobre um pé curto."""
    m = d.m("sebe_%d" % (k % 2), HEDGE[k % 2])
    d.cyl("topiaria", d.m("topiaria_pe", (0.5, 0.4, 0.34)), c, 0.14, 0.12, 0.5, 0.0, 5)
    if k % 3 == 0:
        d.cyl("topiaria", m, c, 0.95, 0.0, 2.1, 0.4, 7, k * 13.0)
    elif k % 3 == 1:
        d.rock("topiaria", m, c, 0.85, 0.45, 0.95)
        d.rock("topiaria", m, c, 0.55, 1.55, 0.95)
    else:
        for i, sz in enumerate((1.4, 1.05, 0.7)):
            d.box("topiaria", m, c, (sz, 0.62, sz), i * 30.0 + k * 9.0, 0.4 + i * 0.64)
    z.ob("pillar", c[0], c[1], (1.5, 2.5, 1.5), visible=False)


def post(z, d, d_l4):
    """Hub: o Posto da Aurora na boca do Véu. Sebe baixa em anel com três vãos, duas tendas, fogo, carga; o Véu Rasgado
    ao norte (o portal de volta para o Palco Grande). Em L4 ganha o pedestal do cristal."""
    z.patch("posto", (0.0, 0.0), HUB_R + 1.6, (0.84, 0.82, 0.76))
    z.data["roads"].append({"kind": "street", "w": 0, "pts": [[0.0, 0.0]], "r": HUB_R})
    hedge_ring(z, d, (0.0, 0.0), HUB_R, HUB_GATES, half=3.0, h=1.5)
    z.data["town"] = {"center": [0.0, 0.0], "radius": HUB_R, "gates": [list(H(HUB_R, g)) for g in HUB_GATES]}
    for g in HUB_GATES:
        for s in (-1, 1):
            q = H(HUB_R + 0.2, g + s * 15.5)
            d.flag(q, (0.3, 0.42, 0.72), 4.6, -g + 90.0, pole=(0.86, 0.82, 0.74), tatter=False, w=1.0, drop=1.6)
            z.ob("pillar", q[0], q[1], (0.5, 4.6, 0.5), visible=False)
    for a in (48.0, 132.0):
        q = H(8.8, a)
        d.tent_aurora(q, -a + 90.0, 1.0)
        d.solid(q[0], q[1], 3.2, 3.2, 3.0)
    d.cookfire((-6.0, -3.6), 1.0, 20.0)
    d.solid(-6.0, -3.6, 1.8, 1.8, 1.0)
    d.cargo(H(11.0, 20.0), 4, 1.2)
    d.weapon_rack(H(11.2, 160.0), -70.0)
    # o Véu Rasgado: o rasgo aceso, a borda lilás e os panos em dentes dos dois lados (a frente olha para o sul/câmera)
    rot = bl.facing(0.0, 1.0)
    d.box("veu", d.m("glow_veu", (0.98, 0.9, 0.96)), VEIL, (2.6, 7.0, 0.2), rot, 0.2)
    d.box("veu", d.m("glow_veu_borda", (0.86, 0.74, 0.92)), bl.loc(VEIL, rot, 0.0, -0.12), (3.5, 7.7, 0.12), rot, 0.1)
    torn = d.m("pano_veu", (0.92, 0.84, 0.88))
    for s in (-1, 1):
        d.cloth("veu", torn, bl.loc(VEIL, rot, s * 1.6, 0.05), 2.4, 6.4, rot + (180.0 if s < 0 else 0.0), 1.2, 0.0, "teeth")
        d.cyl("veu", d.m("lanterna_poste", MARBLE_D), bl.loc(VEIL, rot, s * 4.1, 0.0), 0.16, 0.1, 7.8, 0.0, 6)
        z.ob("pillar", *bl.loc(VEIL, rot, s * 4.1, 0.0), (0.6, 7.8, 0.6), visible=False)
    d.tube("veu", d.m("lanterna_tampa", bl.OLD_GOLD), [(-4.1, 7.7, VEIL[1]), (0.0, 7.2, VEIL[1]), (4.1, 7.7, VEIL[1])], 0.06, 0.06, 4)
    plinth = H(8.2, -52.0)
    st = d_l4.m("posto_pedestal", (0.86, 0.84, 0.86))
    d_l4.cyl("cristal", st, plinth, 1.5, 1.35, 0.3, 0.0, 8)
    d_l4.cyl("cristal", st, plinth, 1.05, 0.95, 0.3, 0.3, 8)
    z.npc("rift_aurora_captain", 3.4, 2.6, -150.0)            # capitã do Posto da Aurora (missões da Fenda)
    z.npc("rift_aurora_quartermaster", *H(9.4, -16.0), -100.0)
    z.npc("rift_aurora_medic", *H(9.0, -158.0), 110.0)
    z.data["hangouts"] = [list(H(r, a)) for r, a in ((3.4, 70.0), (3.8, 170.0), (5.0, 100.0), (7.0, 20.0), (10.5, 90.0), (10.8, 182.0),
                                                      (11.0, -2.0), (7.4, -120.0))]
    z.cam_game = (0.0, 0.0)
    z.block((0.0, 0.0), HUB_R + 5.0)
    return plinth


def pavilion(z, d):
    """Pavilhão da Anfitriã: a arena de 20 m (nada sólido dentro), anéis e rosácea em TONS DO PRÓPRIO CHÃO, colunata com
    véus só na metade norte, lanternas na metade sul, o divã da Anfitriã no fundo e a Coroa de Cristal flutuante."""
    c, R = ARENA, ARENA_R
    z.plaza("pavilhao", c, R + 0.5, "pave_pavilhao")
    z.plaza("adro", ADRO, 7.0, "pave_pavilhao")
    light, dark = act2_dress.floor_tones(d, "pavilhao", MARBLE, 0.1)
    for k, r in enumerate((5.0, 10.0, 15.0, 19.4)):
        n = 8 + k * 4
        for j in range(n):
            a0 = math.tau * j / n + k * 0.2
            d.arc("pavilhao", dark if (j + k) % 2 else light, c, r, a0 + 0.03, a0 + math.tau / n - 0.03, 0.42, 0.0145 + 0.0001 * k, 0.1)
    for j in range(8):                                        # rosácea do centro
        a = 45.0 * j
        d.blob("pavilhao", dark, act3_dress.P(c, 2.3, a), 0.95, 0.0149, 0.04, 14, sx=1.9, rot=-a)
    st, std = d.m("pavilhao_marmore", MARBLE), d.m("pavilhao_marmore_esc", MARBLE_D)
    gold = d.m("pavilhao_ouro", bl.OLD_GOLD)
    cols = [H(R + 2.6, a, c) for a in range(-172, -7, 15)]
    for i, q in enumerate(cols):
        d.cyl("pavilhao3d", std, q, 0.85, 0.8, 0.5, 0.0, 8)
        d.cyl("pavilhao3d", st, q, 0.58, 0.5, 6.0, 0.5, 8)
        d.cyl("pavilhao3d", gold, q, 0.56, 0.8, 0.4, 6.5, 8)
        z.ob("pillar", q[0], q[1], (1.5, 6.9, 1.5), visible=False)
        if i == 0:
            continue
        p = cols[i - 1]
        t = Vector(q) - Vector(p)
        mid = ((p[0] + q[0]) * 0.5, (p[1] + q[1]) * 0.5)
        rot = along(t.x, t.y)
        d.box("pavilhao3d", st, mid, (t.length + 0.8, 0.7, 1.0), rot, 6.9)
        d.box("pavilhao3d", gold, mid, (t.length + 0.9, 0.14, 1.15), rot, 7.6)
        if i % 2 == 0:                                        # véus entre as colunas (altos: a barra fica a 3 m do chão)
            col = [(0.96, 0.8, 0.86), (0.98, 0.93, 0.94), (0.88, 0.8, 0.95)][(i // 2) % 3]
            d.cloth("pavilhao3d", d.m("pano_veu_%d_%d" % (int(col[0] * 100), int(col[2] * 100)), col), (p[0] + t.x * 0.1, p[1] + t.y * 0.1),
                    t.length * 0.8, 3.8, rot, 3.1, 0.0, "teeth")
    for a in (22.0, 58.0, 122.0, 158.0):                      # metade sul: só lanternas baixas (a câmera olha daqui)
        q = H(R + 2.4, a, c)
        lantern(d, q, 3.2)
        z.ob("pillar", q[0], q[1], (0.5, 3.4, 0.5), visible=False)
    # o divã da Anfitriã, no fundo, e a máscara com a lágrima atrás dele
    rot = bl.facing(0.0, 1.0)
    d.box("divan", std, APSE, (10.0, 0.5, 5.0), rot, 0.0)
    d.box("divan", st, APSE, (8.0, 0.5, 3.6), rot, 0.5)
    vel = d.m("divan_veludo", (0.86, 0.62, 0.72))
    d.box("divan", vel, bl.loc(APSE, rot, 0.0, 0.3), (4.4, 0.7, 1.7), rot, 1.0)
    d.box("divan", vel, bl.loc(APSE, rot, -1.5, -0.5), (1.4, 1.7, 0.5), rot, 1.0, (-12, 0))
    d.box("divan", gold, bl.loc(APSE, rot, 0.0, 0.3), (4.7, 0.16, 1.9), rot, 0.92)
    bl.mask(d, "divan", bl.loc(APSE, rot, 0.0, -1.5), 5.2, rot, 2.6)
    z.ob("wall", APSE[0], APSE[1], (10.0, 3.0, 5.0), rot, visible=False)
    # MARCO: a Coroa de Cristal flutuante sobre o divã (norte da arena: a sombra/altura não cobre a luta)
    crown = d.m("glow_coroa", (0.98, 0.92, 0.98))
    for k in range(12):
        a = 30.0 * k
        q = H(4.2, a, APSE)
        d.box("coroa", gold, q, (2.3, 0.9, 0.3), -a + 90.0, 10.6)
        d.cyl("coroa", crown, q, 0.5, 0.0, 3.4 if k % 2 == 0 else 2.2, 11.5, 5, a)
        d.cyl("coroa", crown, q, 0.3, 0.0, 1.2, 10.6, 5, a, (180, 0))
    for k in range(6):                                        # fios de véu caindo da coroa
        q = H(3.6, 60.0 * k + 30.0, APSE)
        d.cloth("coroa", d.m("pano_veu_98_94", (0.98, 0.93, 0.94)), q, 0.7, 4.6, 60.0 * k, 6.0, -0.35, "teeth")
    z.block(c, R + 6.5)
    z.block(APSE, 9.0)
    z.block(ADRO, 9.0)


def labyrinth(z, d):
    """Labirinto de Sebes: três anéis concêntricos com dois vãos cada (todo corredor é um laço: sem beco), fonte no meio."""
    z.patch("labirinto", LAB, LAB_RINGS[-1] + 2.5, MARBLE_D)
    for r, gaps in zip(LAB_RINGS, LAB_GAPS):
        hedge_ring(z, d, LAB, r, gaps, half=2.3, h=2.3)
    bl.wine_fountain(z, d, LAB, 0.62)
    for g in LAB_GAPS[-1]:                                    # lanternas nos dois portais de fora
        for s in (-1, 1):
            q = H(LAB_RINGS[-1] + 0.4, g + s * 13.5, LAB)
            lantern(d, q, 3.0)
            z.ob("pillar", q[0], q[1], (0.5, 3.2, 0.5), visible=False)
    z.block(LAB, LAB_RINGS[-1] + 3.5)


def heart_door(z, d, d_pre, d_l4):
    """Porta do Coração (rift_heart): arco de mármore com o vidro fosco; selada com correntes e máscara até hx3_veil,
    acesa depois (L4). Devolve (portal, frente)."""
    f = Vector(HEART_FRONT) - Vector(DOOR)
    rot = bl.facing(f.x, f.y)
    st, std = d.m("pavilhao_marmore", MARBLE), d.m("pavilhao_marmore_esc", MARBLE_D)
    gold = d.m("pavilhao_ouro", bl.OLD_GOLD)
    z.plaza("porta_coracao", HEART_FRONT, 6.0, "pave_pavilhao")
    d.box("porta", std, DOOR, (8.4, 0.4, 3.0), rot, 0.0)
    for s in (-1, 1):
        q = bl.loc(DOOR, rot, s * 3.0, 0.0)
        d.box("porta", st, q, (1.4, 7.0, 1.4), rot, 0.4)
        d.box("porta", gold, q, (1.7, 0.3, 1.7), rot, 7.4)
    d.box("porta", st, DOOR, (8.2, 1.3, 1.6), rot, 7.7)
    d.box("porta", gold, DOOR, (8.6, 0.25, 1.9), rot, 9.0)
    for k in range(5):                                        # a coroa vazia no alto do arco
        q = bl.loc(DOOR, rot, (k - 2) * 0.9, 0.0)
        d.cyl("porta", gold, q, 0.3, 0.0, 1.4 - abs(k - 2) * 0.3, 9.25, 4, rot + 45.0)
    d.box("porta", d.m("porta_vidro", (0.6, 0.63, 0.72)), bl.loc(DOOR, rot, 0.0, -0.1), (4.6, 7.0, 0.3), rot, 0.4)
    d_l4.box("porta", d_l4.m("glow_coracao", (0.98, 0.9, 0.96)), bl.loc(DOOR, rot, 0.0, 0.14), (3.8, 6.4, 0.1), rot, 0.6)
    chain = d_pre.m("porta_corrente", (0.6, 0.52, 0.36))
    a, b = bl.loc(DOOR, rot, -2.4, 0.4), bl.loc(DOOR, rot, 2.4, 0.4)
    d_pre.tube("porta", chain, [(a[0], 6.4, a[1]), (b[0], 1.0, b[1])], 0.1, 0.1, 4)
    d_pre.tube("porta", chain, [(a[0], 1.0, a[1]), (b[0], 6.4, b[1])], 0.1, 0.1, 4)
    bl.mask(d_pre, "porta", bl.loc(DOOR, rot, 0.0, 0.5), 3.7, rot, 1.5)
    z.ob("wall", DOOR[0], DOOR[1], (8.4, 7.0, 2.0), rot, visible=False)
    for s in (-1, 1):
        q = bl.loc(DOOR, rot, s * 5.4, 2.6)
        lantern(d, q, 3.2)
        z.ob("pillar", q[0], q[1], (0.5, 3.4, 0.5), visible=False)
    z.block(DOOR, 9.0)
    z.block(HEART_FRONT, 7.0)
    return bl.loc(DOOR, rot, 0.0, 2.6), HEART_FRONT


def roadside_hedges(z, d, poly, gap_every=9, gap=3, off=zone_lib.ROAD_W * 0.5 + 2.6):
    """Sebe por FORA do anel (o lado longe do centro), em lances com falhas largas a cada ~25 m: muro baixo que desenha a
    alameda de cima sem fechar nada."""
    n = 0
    for i in range(0, len(poly) - 2, 2):
        if (i // 2) % gap_every >= gap_every - gap:
            continue
        pts = []
        for j in (i, i + 2):
            t = (poly[min(len(poly) - 1, j + 1)] - poly[max(0, j - 1)]).normalized()
            nr = Vector((-t.y, t.x))
            if (poly[j] + nr).length < poly[j].length:
                nr = -nr
            pts.append(poly[j] + nr * off)
        mid = (pts[0] + pts[1]) * 0.5
        if any((mid - c).length < r + 1.0 for c, r in z.blocked):
            continue
        if any(poly_dist(mid, other) < zone_lib.ROAD_W * 0.5 + 2.0 for name, other in z.road_polys.items() if other is not poly):
            continue
        if any((mid - Vector(s["pos"])).length < s["radius"] + 1.5 for s in z.data["spawners"]):
            continue
        hedge(z, d, pts[0], pts[1], i // 2, 2.0)
        n += 1
    return n


# ---------------------------------------------------------------------------------------------------------------
def build(export=False):
    z = Zone(ZONE, size=260.0, rim=(116.0, 4.0, 3.0, 2.0), seed=61, palette={
        "road": (0.88, 0.86, 0.84), "street": (0.86, 0.85, 0.85), "pave_pavilhao": MARBLE, "water": (0.74, 0.72, 0.86),
        "cliff_rock": (0.8, 0.74, 0.86), "cliff_rock_d": (0.68, 0.62, 0.78), "cliff_grass": (0.44, 0.62, 0.5),
        "hill_grass": (0.56, 0.7, 0.58), "leaf": (0.5, 0.68, 0.56), "wood": (0.86, 0.82, 0.8),
    })
    z.trail_color = (0.86, 0.84, 0.82)
    z.water_tint("water")
    dn = Dress(z, seed=331)
    d_pre = Dress(z, seed=332, tag="l0_porta_selada", when={"unless": Q_VEIL})
    d_l4 = Dress(z, seed=333, tag="l4_manha", when={"if": Q_VEIL})
    widths = {}

    def road(name, pts, w=zone_lib.ROAD_W):
        widths[name] = w
        return z.road(name, pts, w=w, end_clearing=False)

    # ---------- chegada: o Véu no Posto; a volta para o Palco Grande é portal de verdade ----------
    z.data["spawn"] = list(ARRIVE)
    z.data["portals"].append({"id": "to_field_parade", "pos": list(VEIL_PORTAL), "radius": 2.0, "target_map": "field_parade",
                              "target_pos": list(PARADE_ARRIVE), "label": "Avenida do Cortejo (Lv 47-49)"})
    crystal = post(z, dn, d_l4)

    # ---------- estradas: três raios do Posto, o anel, e os laços dos POIs (nenhum beco) ----------
    ring = road("anel", RING, w=5.2)
    road("leste", [(HUB_R - 1.0, 0.0), (34.0, -6.0), (60.0, 2.0)])
    road("oeste", [(-HUB_R + 1.0, 0.0), (-36.0, 5.0), (-60.0, 2.0)])
    road("sul", [(0.0, HUB_R - 1.0), (-5.0, 36.0), (2.0, 58.0)])
    alley = road("espelhos", [(-52.0, -26.0), (-74.0, -24.0), (-89.0, -4.0), (-86.0, 20.0), (-70.0, 32.0), (-50.0, 32.0)])
    road("lago", [(52.0, 30.0), (72.0, 31.0), (85.0, 45.0), (83.0, 64.0), (68.0, 75.0), (48.0, 71.0), (30.0, 50.0)])
    road("labirinto_leste", [(-28.0, 52.0), (-31.0, 60.0), H(LAB_RINGS[-1] + 2.0, 0.0, LAB)])
    road("labirinto_norte", [(-50.0, 32.0), (-54.0, 40.0), H(LAB_RINGS[-1] + 2.0, 270.0, LAB)])
    road("coracao_sul", [(52.0, -26.0), (66.0, -33.0), HEART_FRONT])
    road("coracao_norte", [(30.0, -44.0), (50.0, -57.0), (64.0, -56.0), HEART_FRONT])
    road("pavilhao", [(0.0, -47.0), (0.0, -52.0)])
    z.lake("perfume", LAKE, LAKE_R)

    # ---------- chão ----------
    tones = act2_dress.floor_tone_colors(GROUND, 0.06)
    dn.mottle([("relva_clara", tones[0]), ("relva_esc", tones[1]), ("relva_perola", (0.78, 0.8, 0.74))], [((0, 0), 110, 150)],
              y=0.0008, rmin=4.0, rmax=9.0)
    z.patch("espelhos", MIRRORS, 10.0, MARBLE_D)

    # ---------- POIs ----------
    pavilion(z, dn)
    labyrinth(z, dn)
    heart_portal, heart_front = heart_door(z, dn, d_pre, d_l4)
    k = 0
    for i in range(3, len(alley) - 3, 4):                     # Alameda dos Espelhos: espelhos de pé foscos dos dois lados
        t = (alley[i + 1] - alley[i - 1]).normalized()
        nr = Vector((-t.y, t.x))
        for s in (-1, 1):
            q = alley[i + (1 if s > 0 else 0)] + nr * s * (zone_lib.ROAD_W * 0.5 + 1.7)
            rot = bl.facing(-nr.x * s, -nr.y * s)
            act3_dress.standing_mirror(dn, (q.x, q.y), rot, 2.8, 1.6, k % 4 == 3)
            z.ob("pillar", q.x, q.y, (1.8, 2.8, 0.6), rot, visible=False)
            k += 1
    for j, (a, s, col) in enumerate(((200.0, 1.2, (0.92, 0.76, 0.86)), (250.0, 0.9, (0.8, 0.84, 0.96)), (310.0, 1.0, (0.96, 0.88, 0.7)), (140.0, 0.8, (0.84, 0.76, 0.94)))):
        q = H(LAKE_R + 3.4, a, LAKE)                          # frascos gigantes na margem do Lago de Perfume
        flacon(z, dn, q, s, col, j * 20.0)
        dn.reserve(q[0], q[1], 2.2)
    for s in (-1, 1):                                         # fontes de vinho no adro do Pavilhão
        q = (ADRO[0] + s * 12.5, ADRO[1] - 5.5)
        bl.wine_fountain(z, dn, q, 0.8, top="jar")
        dn.reserve(q[0], q[1], 3.0)

    # ---------- borda: morros de cristal pálido com sebe nos patamares, agulhas de cristal e copas pastel ----------
    af.vine_hills(z, rock_cols=((0.3, 0.52, 0.38), (0.94, 0.76, 0.82), (0.84, 0.76, 0.94)), boulder=(0.86, 0.8, 0.92))
    rnd = random.Random(611)
    for k in range(46):
        a = math.tau * (k + rnd.uniform(-0.3, 0.3)) / 46
        r = z.rim_r(a) - rnd.uniform(5.0, 9.0)
        q = (math.cos(a) * r, math.sin(a) * r)
        if dn.ok(q[0], q[1], 1.6, road=4.0, blocked=True, rim=1.0):
            crystal_spire(z, dn, q, rnd.uniform(4.5, 7.5), k)
            dn.reserve(q[0], q[1], 2.0)
            z.block(q, 3.0)

    # ---------- monstros (49-50; ids do GDD §3 e §3.1). Teto do GDD §11: <= 140 vivos com x1,6 e escoltas ----------
    M = MOBS
    sp = z.spawner
    sp(M["seductress"], 40.0, -22.0, 6, 3, 26.0)              # Sedutoras: por dentro do anel e no sul
    sp(M["seductress"], -42.0, 18.0, 6, 3, 26.0)
    sp(M["seductress"], 16.0, 84.0, 6, 3, 26.0)
    sp(M["flayer"], -40.0, -24.0, 6, 2, 28.0)                 # Açoitadoras
    sp(M["flayer"], 41.0, 20.0, 6, 2, 28.0)
    sp(M["flayer"], -16.0, 84.0, 6, 2, 28.0)
    sp(M["singer"], -72.0, -48.0, 6, 2, 28.0)                 # Cantoras do Véu (à distância): cantos abertos
    sp(M["singer"], 92.0, 16.0, 6, 2, 28.0)
    sp(M["matriarch"], -52.0, -72.0, 4, 1, 180.0)             # Matriarcas Veladas (2 Sedutoras + 1 Açoitadora de escolta)
    sp(M["matriarch"], 52.0, -76.0, 4, 1, 180.0)
    sp(M["matriarch"], -84.0, 46.0, 4, 1, 180.0)
    sp(M["first"], MIRRORS[0], MIRRORS[1] - 8.0, 4, 1, 150.0) # Primeiros Bailarinos (2 Bailarinos de escolta)
    sp(M["first"], 74.0, -10.0, 4, 1, 150.0)
    sp(M["reflection"], MIRRORS[0] + 2.0, MIRRORS[1] + 12.0, 6, 2, 28.0)      # Reflexos: na Alameda dos Espelhos e no Lago
    sp(M["reflection"], -96.0, -26.0, 5, 2, 28.0)
    sp(M["reflection"], 92.0, -12.0, 5, 2, 28.0)
    sp(M["maestro"], 38.0, 90.0, 4, 1, 180.0)                 # Maestro do Coro (3 Coristas)
    sp(M["master"], 23.0, 41.0, 4, 1, 180.0)                  # Mestre de Cerimônias (3 Foliões)
    alpha = [(p.x, p.y) for p in ring[len(ring) // 2 - 22:len(ring) // 2 + 23:11]]      # Galgo Alfa: ronda o arco sul do anel
    z.spawner(M["alpha"], round(alpha[0][0], 2), round(alpha[0][1], 2), 3, 1, 180.0, route=alpha)
    z.spawner(BOSS_ID, ARENA[0], ARENA[1], 2, 1, 600.0)       # Vessaline, a Anfitriã do Véu (chefe principal, grupo de 4)
    live = 2
    for s in z.data["spawners"]:
        n = int(math.ceil(s["count"] * af.SPAWN_MULT)) if s["count"] > 1 else 1
        live += n * (1 + ESCORT.get(s["monster_id"], 0))
    print("vivos (x1,6 + escoltas + 2 lacaios da Vessaline): %d" % live)

    # ---------- vegetação ----------
    obs = z.data["obstacles"]
    z.scatter("tree", [((0, 0), 108, 26), ((-20, -90), 16, 4), ((70, 6), 18, 4), ((0, 96), 20, 5), ((-96, 40), 16, 4)], 0, (1.7, 4.2, 1.7), TREES,
              margin=6.5, spacing=8.5, hub_r=HUB_R + 8.0)
    z.rim_belt(60, (1.6, 4.4, 1.6), TREES)
    nrnd = random.Random(613)
    free = lambda x, zz, m: z.free(x, zz, m + 2.0, HUB_R + 5.0)
    nature.fix_trees(obs, nrnd)
    nature.scatter(z.ob, free, nrnd, "bush", [((0, 0), 106, 56)], (1.5, 0.9, 1.5), [(0.3, 0.52, 0.38), (0.94, 0.76, 0.82), (0.84, 0.76, 0.94)],
                   solid=False, margin=2.6, spacing=3.4, avoid=obs)
    nature.scatter(z.ob, free, nrnd, "flowers", [((0, 0), 104, 90)], (1.4, 0.4, 1.4), FLOWERS, solid=False, margin=2.4, spacing=3.0, avoid=obs)
    nature.clear_banks(obs, [], [(LAKE, LAKE_R)], 0.0)
    nature.shore(z.ob, nrnd, [], [(LAKE, LAKE_R)], list(z.road_polys.values()), 0.0, colors=[(0.9, 0.72, 0.82), (0.8, 0.74, 0.94)], keep=0.6)

    # ---------- acabamento ----------
    light, dark = act2_dress.floor_tones(dn, "alameda", (0.88, 0.86, 0.84), 0.07)
    for i in range(2, len(ring) - 2):                         # ladrilhos da alameda em dois tons do próprio mármore
        t = (ring[i + 1] - ring[i - 1]).normalized()
        nr = Vector((-t.y, t.x))
        for _ in range(2):
            q = ring[i] + nr * rnd.uniform(-2.2, 2.2) + t * rnd.uniform(-0.8, 0.8)
            s = rnd.uniform(0.6, 1.0)
            dn.box("mosaico", (light, dark)[rnd.randrange(2)], (q.x, q.y), (s, 0.003, s), along(t.x, t.y) + 45.0, 0.0123)
    dn.road_edges((0.82, 0.82, 0.78), extra=1.4)
    print("lances de sebe na alameda:", roadside_hedges(z, dn, ring))
    acc, k = 0.0, 0
    for i in range(3, len(ring) - 3):                         # lanternas de pérola por DENTRO do anel
        acc += (ring[i] - ring[i - 1]).length
        if acc < 19.0:
            continue
        acc = 0.0
        t = (ring[i + 1] - ring[i - 1]).normalized()
        nr = Vector((-t.y, t.x))
        if (ring[i] + nr).length > ring[i].length:
            nr = -nr
        q = ring[i] + nr * (2.6 + 1.2)
        if dn.ok(q.x, q.y, 0.4, road=0.6, blocked=True):
            lantern(dn, (q.x, q.y), 3.0)
            dn.solid(q.x, q.y, 0.5, 0.5, 3.0)
        k += 1
    k = 0
    for q in dn.spots([((0, 0), 104, 40), ((-24, 76), 14, 5), ((84, 0), 14, 5), ((-70, -70), 16, 5), ((30, -84), 12, 4)], r=1.2, spacing=9.0,
                      blocked=True, tall=True):               # flores gigantes: longe da estrada e fora da área de luta dos bandos
        giant_flower(dn, q, rnd.uniform(2.6, 4.2), FLOWERS[k % len(FLOWERS)], k)
        dn.solid(q[0], q[1], 0.7, 0.7, 3.0)
        k += 1
    print("flores gigantes:", k)
    in_pack = lambda q: any(math.hypot(q[0] - s["pos"][0], q[1] - s["pos"][1]) < s["radius"] + 2.5 for s in z.data["spawners"])
    k = 0
    for q in dn.spots([((0, 0), 100, 30)], r=2.8, spacing=13.0, blocked=True, road=1.2):       # canteiros
        if in_pack(q):
            continue
        parterre(z, dn, q, rnd.choice((0.0, 30.0, 60.0, 90.0, 120.0, 150.0)), k)
        dn.reserve(q[0], q[1], 3.0)
        k += 1
    n = 0
    for q in dn.spots([((0, 0), 104, 34)], r=1.1, spacing=8.0, blocked=True, road=1.0):        # topiarias
        if in_pack(q):
            continue
        topiary(z, dn, q, n)
        dn.reserve(q[0], q[1], 1.2)
        n += 1
    print("canteiros: %d, topiarias: %d" % (k, n))
    for k, (name, frac) in enumerate((("leste", 0.55), ("oeste", 0.55), ("sul", 0.5), ("lago", 0.5), ("coracao_sul", 0.5))):
        poly = z.road_polys[name]
        i = int(len(poly) * frac)
        t = (poly[i + 1] - poly[i - 1]).normalized()
        q = poly[i] + Vector((-t.y, t.x)) * 3.6
        if dn.ok(q.x, q.y, 0.5, road=0.4):
            dn.signpost((q.x, q.y), along(t.x, t.y))

    # ---------- dados para a integração ----------
    r2 = lambda p: [round(p[0], 2), round(p[1], 2)]
    z.data["future_portals"] = [
        {"id": "to_rift_heart", "pos": r2(heart_portal), "arrive": r2(heart_front), "target_map": "rift_heart",
         "label": "O Coração do Jardim (raide, Lv 50)", "level": 50, "if": [Q_VEIL]},
    ]
    z.data["places"] = [{"id": "posto_aurora", "type": "camp", "pos": [0.0, 0.0]}, {"id": "porta_coracao", "type": "dungeon", "pos": list(DOOR), "dungeon": "rift_heart"}]
    z.data["boss_hint"] = {"id": BOSS_ID, "name": "Vessaline, a Anfitriã do Véu", "level": 50, "pos": list(ARENA), "radius": 2.0,
                           "arena_r": ARENA_R, "clear_r": ARENA_R + 0.5, "respawn": 600.0, "summons": [M["first"], M["first"]],
                           "islands": [list(H(11.0, a, ARENA)) for a in (45.0, 135.0, 225.0, 315.0)], "island_r": 4.0,
                           "note": "Cortejo: 4 investidas de 10 m cabem em qualquer direção (diâmetro 40 m, nada sólido dentro); ilhas do Palco Seguro sugeridas"}
    z.data["stage_tags"] = [{"tag": "l0_porta_selada", "unless": Q_VEIL}, {"tag": "l4_manha", "if": Q_VEIL}]
    z.data["crystal_hint"] = {"pos": r2(crystal), "if": Q_VEIL}
    z.data["hangouts"] += [[ADRO[0] - 4.0, ADRO[1] + 1.0], [HEART_FRONT[0] - 3.0, HEART_FRONT[1] + 3.0], [-33.0, 62.0], [58.0, 34.0]]
    z.data["poi"] = {"posto": [0.0, 4.0], "pavilhao": [ARENA[0], ARENA[1] + 6.0], "espelhos": [-84.0, 8.0], "lago": [LAKE[0] - 7.0, LAKE[1] - 16.0],
                     "labirinto": [LAB[0] + 4.0, LAB[1] + 4.0], "coracao": [HEART_FRONT[0], HEART_FRONT[1] + 2.0], "anel_sul": [2.0, 58.0],
                     "chegada": list(ARRIVE)}
    z.data["landmark"] = {"id": "coroa_de_cristal", "pos": list(APSE), "height": 14.9}
    z.data["monster_ids"] = dict(MOBS, boss=BOSS_ID)
    z.data["gather_hint"] = [
        {"item": "Porcelana Chorosa", "shape": "relic", "pos": [LAB[0], LAB[1] + 7.5], "radius": 2.0, "count": 2},
        {"item": "Porcelana Chorosa", "shape": "relic", "pos": [MIRRORS[0] - 6.0, MIRRORS[1] + 2.0], "radius": 6.0, "count": 2},
        {"item": "Fita do Festim", "shape": "crate", "pos": [22.0, -60.0], "radius": 6.0, "count": 3},
        {"item": "Fita do Festim", "shape": "crate", "pos": [44.0, 60.0], "radius": 5.0, "count": 3},
    ]
    z.data["ground_hint"] = {"ground_color": list(GROUND), "mounts": True,
                             "note": "relva palida; estradas/largos de marmore (road, pave_pavilhao); ceu rosa-perola no ambiente do MapDef"}
    print("PORTAIS promovidos (act3_ready.READY):", act3_ready.promote(z.data))

    for d in (dn, d_pre, d_l4):
        d.flush()
    poi = z.data["poi"].get(os.environ.get("RIFT_POI", "pavilhao"), z.data["poi"]["pavilhao"])
    data = z.finish(export, poi=tuple(poi), ground=GROUND)
    af.walk_check(data, extra={"lab_centro": [LAB[0], LAB[1] + 3.6], "lab_meio": [LAB[0], LAB[1] + 7.5], "lab_fora": [LAB[0], LAB[1] + 11.5]})
    return data
