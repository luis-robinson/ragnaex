"""Vinhas do Perfume (field_perfume, Ato III parte 1, Lv 45-47): o vale de vinhedos ao norte de Lumeria.
GDD design/gdd/ato3-excesso-45-50.md (§2, §3, §4, §7). Chegada ao SUL (Lumeria sai pelo portão norte, rumo 0).

  * CENTRO   Quinta do Vinhateiro (hub sem cristal): pátio de muro baixo com quatro vãos, a casa, o poço e a pérgola.
  * OESTE    Vinhedo em Terraços: três patamares sólidos com videira em cima e as fileiras curvas no chão.
  * NORTE    Lagar dos Pés Roxos: a tina gigante com a roda de pedra (MARCO, 13 m) e a porta das Adegas (dg_cellars).
  * NOROESTE Poço de Névoa: arena redonda da chefe de mundo Dona Vindima.
  * LESTE    Santuário Profanado da Aurora, do outro lado do Riacho do Mosto (três pontes).
  * SUDOESTE Acampamento dos Fugidos (gente que escapou da festa).
  Lugares (`_check_places`): Casa do Tanoeiro e Casa da Destiladora (cabanas), Acampamento dos Fugidos, Santuário, Lagar.

Leitura de cima: fileiras paralelas de videira roxa e verde, terra lilás muito dessaturada debaixo delas, estradas de
terra clara, o riacho azul com juncos, jacarandás lilases (a cor viva fica nas copas, NUNCA no chão: anel/mancha
saturada no chão é aviso de golpe). A névoa lilás é só fx (`data["fx"]`, metade some em L2).

Os mapas vizinhos que ainda não existem (dg_cellars) saem em data["future_portals"]; a chefe de mundo em
data["world_boss_hint"] (o id ainda não está no MonstersCatalog). A volta para Lumeria é portal de verdade.

Pilha de planos do chão (mm): manchas do campo 0,8/1,6/2,4 · terra do vinhedo 3,4 · manchas `Zone.patch` 4,5-6,8 ·
chão dos lugares 6,0 · pegadas/anéis da arena 7,6-8,0 · acostamento 9,8 · trilha 10,8 · estrada 12 · praça 14.

Estágios (data["stage_tags"]; o catálogo liga em conquest_vis):
  l0_festim (até hx3_cellars): mesas de banquete e lanternas acesas no Lagar e na estrada
  l2_colheita (depois de hx3_cellars): cestos, caixas e carroças da vindima nos vinhedos (+ stage_npcs vinhateiros)

    blender -b --factory-startup --python tools/blender/zones/run_zone.py -- build_perfume <pasta_png> --export
    (PERFUME_POI=<quinta|terracos|lagar|nevoa|santuario|fugidos|tanoeiro|destiladora|chegada> escolhe o alvo da CAM_poi)
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

ZONE = "field_perfume"
LUMERIA_ARRIVE = (0.0, -94.0)            # chegada em city_lumeria (build_lumeria: future_portals to_field_perfume "arrive")
HUB_R = 17.0
HUB_GATES = [0.0, 90.0, 180.0, -90.0]
RIVER = [(74.0, -125.0), (60.0, -92.0), (47.0, -62.0), (52.0, -30.0), (44.0, 2.0), (50.0, 32.0), (40.0, 60.0), (46.0, 92.0), (54.0, 125.0)]
TERRACES = [((-93.0, -6.0), 9.0, 2), ((-88.0, 21.0), 8.0, 1), ((-91.0, -33.0), 8.0, 2)]
YARD = (-70.0, 4.0)                      # terreiro do vinhedo (cruzamento oeste)
LAGAR = (10.0, -88.0)
MIST = (-40.0, -57.0)                    # Poço de Névoa (arena da Dona Vindima)
MIST_R = 16.0
SHRINE = (88.0, -20.0)
E_JUNCTION = (72.0, -10.0)
CAMP = (-48.0, 79.0)
COOPER = (26.0, 70.0)
DISTILLER = (84.0, -50.0)
Q_CELLARS = "hx3_cellars"
MOBS = {"reveler": "masked_reveler", "master": "ceremony_master", "chorister": "chorister", "hound": "silk_hound",
        "dancer": "veil_dancer", "censer": "living_censer", "vine": "thirsty_vine"}
BOSS_ID = "boss_vindima"                 # id de trabalho (WP8): Dona Vindima, a Vinha que Bebe

GROUND = (0.6, 0.66, 0.48)               # relva sálvia (sugestão de MapDef.ground_color)
EARTH = (0.63, 0.58, 0.59)               # terra do vinhedo: lilás muito dessaturado
STONE, STONE_D = (0.88, 0.83, 0.75), (0.72, 0.66, 0.6)
MUST = (0.44, 0.3, 0.42)                 # mosto fosco (nunca brilha)
TREES = [(0.3, 0.5, 0.36), (0.42, 0.56, 0.38), (0.72, 0.6, 0.82), (0.66, 0.54, 0.78)]      # ciprestes e jacarandás lilases

PLACES = [
    {"type": "cabin", "id": "tanoeiro", "pos": COOPER, "face": 215.0, "npc": "perfume_cooper", "roof": (0.6, 0.44, 0.62), "wall": (0.9, 0.86, 0.78)},
    {"type": "cabin", "id": "destiladora", "pos": DISTILLER, "face": 150.0, "npc": "perfume_distiller", "roof": (0.86, 0.66, 0.5), "wall": (0.92, 0.88, 0.8)},
    {"type": "shrine", "id": "santuario_aurora", "pos": SHRINE, "npc": "aurora_shrine_perfume", "ground": (0.74, 0.72, 0.68)},
]
# Festim Sem Fim: (tipo, estrada, fração, lado, monstro)
EVENT_POINTS = [
    ("banquet", "sul", 0.52, 1, MOBS["reveler"]),
    ("sweet_smoke", "terracos", 0.5, -1, MOBS["censer"]),
    ("banquet", "santuario_norte", 0.42, 1, MOBS["reveler"]),
    ("sweet_smoke", "santuario_sul", 0.3, -1, MOBS["censer"]),
    ("banquet", "fugidos", 0.72, 1, MOBS["reveler"]),
]


def quinta(z, d):
    """Hub: a Quinta do Vinhateiro. Muro baixo de pedra creme com quatro vãos, casa de telhado ameixa, poço, pérgola de
    videira sobre as mesas, a prensa pequena e a carga da vindima. Sem cristal (GDD)."""
    z.patch("quinta", (0.0, 0.0), HUB_R + 3.5, (0.74, 0.7, 0.6))
    z.plaza("quinta", (0.0, 0.0), HUB_R - 1.5, "street")
    bl.ring_wall(z, d, "quinta", (0.0, 0.0), HUB_R, [(g, 3.3) for g in HUB_GATES], 1.5, 0.7, STONE, STONE_D, seg_len=3.0, towers=False)
    z.data["town"] = {"center": [0.0, 0.0], "radius": HUB_R, "gates": [list(H(HUB_R, g)) for g in HUB_GATES]}
    post = d.m("quinta_poste", STONE_D)
    for g in HUB_GATES:                                       # pilares dos vãos com uma lanterna apagada em cima
        for s in (-1, 1):
            q = H(HUB_R, g + s * 13.5)
            d.cyl("quinta", post, q, 0.55, 0.5, 2.4, 0.0, 6)
            d.box("quinta", d.m("lanterna_apagada", (0.84, 0.78, 0.72)), q, (0.4, 0.5, 0.4), 45.0, 2.4)
            z.ob("pillar", q[0], q[1], (1.1, 2.4, 1.1), visible=False)
    bl.house(z, d, (-8.0, -8.0), 40.0, 8.0, 5.6, 3.0, (0.93, 0.88, 0.8), (0.56, 0.4, 0.58), name="quinta_casa")
    bl.house(z, d, (9.5, -8.5), -50.0, 5.4, 4.2, 2.5, (0.9, 0.86, 0.8), (0.62, 0.46, 0.62), name="quinta_adega", extra=False)
    bl.wine_fountain(z, d, (0.0, 0.0), 0.75, top="jar")       # a bica da quinta, no meio do pátio
    d.cyl("fonte", d.m("vinho_fosco", bl.WINE), (0.0, 0.0), 1.8, 1.8, 0.03, 0.55, 12)      # o vinho 3 cm acima da tampa da bacia (no mesmo plano brigava)
    z.ob("well", 7.5, 8.5, (1.6, 1.4, 1.6))
    # pérgola (sudoeste): postes, travessas e videira por cima; mesas compridas debaixo
    pc = (-8.0, 8.0)
    wood = d.m("pergola_madeira", (0.56, 0.44, 0.34))
    for sx in (-3.2, 0.0, 3.2):
        for sy in (-1.8, 1.8):
            q = bl.loc(pc, -35.0, sx, sy)
            d.cyl("pergola", wood, q, 0.1, 0.09, 2.5, 0.0, 5)
        d.box("pergola", wood, bl.loc(pc, -35.0, sx, 0.0), (0.14, 0.12, 4.4), -35.0, 2.5)
    for k, sy in enumerate((-1.5, -0.5, 0.5, 1.5)):
        d.box("pergola", d.m("videira_%d" % (k % 2), af.VINE[k % 2]), bl.loc(pc, -35.0, 0.0, sy), (7.2, 0.3, 0.7), -35.0, 2.6)
    d.box("pergola", wood, pc, (4.6, 0.76, 1.1), -35.0, 0.0)
    d.box("pergola", d.m("mesa_toalha", (0.94, 0.9, 0.84)), pc, (4.8, 0.05, 1.3), -35.0, 0.76)
    z.ob("crate", pc[0], pc[1], (4.6, 0.9, 1.2), -35.0, visible=False)
    # prensa pequena (leste): tina de aduelas, parafuso e travessa
    pr = (10.0, 3.0)
    d.cyl("prensa", d.m("prensa_tina", (0.56, 0.4, 0.3)), pr, 1.3, 1.4, 1.0, 0.0, 10)
    d.cyl("prensa", d.m("lagar_mosto", MUST), pr, 1.15, 1.15, 0.05, 1.0, 10)
    d.cyl("prensa", wood, pr, 0.14, 0.14, 2.6, 0.0, 6)
    d.box("prensa", wood, pr, (3.0, 0.2, 0.24), 20.0, 2.2)
    z.ob("pillar", pr[0], pr[1], (2.8, 2.6, 2.8), visible=False)
    d.cargo((13.0, -2.0), 5, 1.4)
    d.cargo((-12.5, 1.5), 4, 1.2)
    d.cart((2.5, -11.5), 20.0, load=(0.5, 0.36, 0.6))
    z.npc("perfume_vintner", -5.0, -3.5, 150.0)               # o Vinhateiro (missões do campo)
    z.npc("perfume_lucid_scout", 5.5, -5.0, -150.0)           # batedora dos Lúcidos (poções)
    z.data["hangouts"] = [list(H(r, a)) for r, a in ((5.0, 30.0), (5.5, 150.0), (5.0, -100.0), (9.5, 78.0), (11.5, 178.0), (12.5, -92.0),
                                                      (12.5, 14.0), (13.5, 100.0))]
    z.cam_game = (0.0, 0.0)
    z.block((0.0, 0.0), HUB_R + 5.0)


def lagar(z, d, d_l0, c):
    """MARCO e entrada das Adegas: a tina de pisar do tamanho de uma praça, com a roda de pedra de pé num cavalete por
    cima (13 m). A porta da adega abre no pé da tina, virada para o sul (para a estrada e para a câmera)."""
    rot = bl.facing(0.0, 1.0)                                 # +yb local = sul
    st, std = d.m("lagar_pedra", STONE), d.m("lagar_pedra_esc", STONE_D)
    must = d.m("lagar_mosto", MUST)
    wood = d.m("lagar_madeira", (0.5, 0.38, 0.3))
    d.cyl("lagar", std, c, 10.2, 9.8, 0.7, 0.0, 16)
    d.cyl("lagar", st, c, 8.8, 8.6, 2.0, 0.7, 16)
    d.cyl("lagar", must, c, 7.7, 7.7, 0.06, 2.7, 16)
    for k in range(8):                                        # contrafortes
        q = H(9.0, 45.0 * k + 22.5, c)
        if abs(q[0] - c[0]) < 3.0 and q[1] > c[1]:
            continue
        d.box("lagar", std, q, (1.2, 2.3, 1.2), -(45.0 * k + 22.5), 0.0)
    # porta da adega (sul)
    door = bl.loc(c, rot, 0.0, 9.6)
    d.box("lagar", d.m("dungeon_boca", (0.04, 0.03, 0.05)), door, (3.4, 2.5, 1.4), rot, 0.0)
    d.box("lagar", st, bl.loc(c, rot, 0.0, 10.2), (5.0, 0.7, 1.0), rot, 2.5)
    for s in (-1, 1):
        d.box("lagar", st, bl.loc(c, rot, s * 2.2, 10.2), (0.9, 2.6, 1.0), rot, 0.0)
        z.ob("lamp", *bl.loc(c, rot, s * 3.6, 13.0), (0.4, 2.8, 0.4))
    d.box("lagar", d.m("glow_dg_cellars", (1.0, 0.8, 0.52)), bl.loc(c, rot, 0.0, 10.35), (2.6, 2.1, 0.1), rot, 0.08)
    bl.mask(d, "lagar", bl.loc(c, rot, 0.0, 10.72), 3.9, rot, 1.1)
    # cavalete e roda de pedra (peça alta: o jogo a deixa translúcida na frente do boneco)
    d.tall(c)
    top = 2.76
    for s in (-1, 1):
        for yb in (-1.6, 1.6):
            a, b = bl.loc(c, rot, s * 6.4, yb * 1.6), bl.loc(c, rot, s * 1.5, yb * 0.35)
            d.tube("lagar", wood, [(a[0], top, a[1]), (b[0], top + 5.6, b[1])], 0.3, 0.24, 5)
    d.box("lagar", wood, c, (4.4, 0.5, 0.5), rot, top + 5.35)
    wc = bl.loc(c, rot, 0.0, 0.75)
    d.cyl("lagar", st, wc, 4.6, 4.6, 1.5, top + 5.6, 16, rot, tilt=(90, 0))
    d.cyl("lagar", std, bl.loc(c, rot, 0.0, 0.95), 1.1, 1.1, 1.9, top + 5.6, 8, rot, tilt=(90, 0))
    for k in range(6):                                        # bossas na face da roda
        a = math.radians(60.0 * k + 30.0)
        d.cyl("lagar", std, bl.loc(c, rot, math.cos(a) * 2.9, 0.82), 0.5, 0.5, 1.64, top + 5.6 + math.sin(a) * 2.9, 6, rot, tilt=(90, 0))
    d.cyl("lagar", d.m("lagar_ouro", bl.OLD_GOLD), bl.loc(c, rot, 0.0, 1.0), 0.5, 0.5, 2.0, top + 5.6, 6, rot, tilt=(90, 0))
    d.tall()
    for k, a in enumerate((205.0, 250.0, 290.0, 335.0)):      # flâmulas no beiral de trás (pano dobrado, cores da festa)
        d.flag(H(9.6, a, c), bl.BUNTING[k % len(bl.BUNTING)], 6.0, -a + 90.0, tatter=False)
    z.ob("hill", c[0], c[1], (18.6, 6.0, 18.6), 0.0, visible=False)
    z.ob("hill", c[0], c[1], (15.4, 6.0, 15.4), 45.0, visible=False)
    # largo da frente: pegadas roxas (tons do próprio chão) e, em L0, o banquete dos pés roxos
    fore = (c[0], c[1] + 16.0)
    z.patch("lagar", fore, 8.5, (0.72, 0.68, 0.62))
    light, dark = act2_dress.floor_tones(d, "lagar", (0.72, 0.68, 0.62))
    rnd = random.Random(88)
    for i in range(46):
        q = (fore[0] + rnd.uniform(-7.0, 7.0), fore[1] + rnd.uniform(-5.5, 6.0))
        d.blob("pegada", dark if i % 3 else light, q, 0.16, 0.0076 + 0.0002 * (i % 2), 0.1, 6, sx=1.8, rot=rnd.uniform(0, 180))
    bl.banquet(af.NO_OB, d_l0, (c[0] - 9.5, c[1] + 15.5), 70.0, 5.0)      # peça de estágio: sem colisor
    bl.banquet(af.NO_OB, d_l0, (c[0] + 9.5, c[1] + 15.5), -70.0, 5.0)
    for s in (-1, 1):
        d_l0.box("lanterna", d_l0.m("glow_lanterna_ambar", (1.0, 0.84, 0.55)), bl.loc(c, rot, s * 2.2, 10.2), (0.42, 0.46, 0.42), 45.0, 2.7)
    portal = bl.loc(c, rot, 0.0, 12.6)
    front = bl.loc(c, rot, 0.0, 18.0)
    z.block(c, 13.0)
    z.block(fore, 9.0)
    return portal, front


def mist_well(z, d, c):
    """Poço de Névoa: arena redonda da Dona Vindima. Chão de terra clara com anéis em TONS DO PRÓPRIO CHÃO, o poço de pedra
    na borda norte (água leitosa fosca) e um círculo de cepas mortas por fora. Nada sólido dentro do raio da luta."""
    floor = (0.68, 0.65, 0.64)
    z.patch("nevoa", c, MIST_R + 3.0, floor)
    light, dark = act2_dress.floor_tones(d, "nevoa", floor)
    for k, (r, w, m) in enumerate(((MIST_R - 1.0, 0.7, dark), (10.0, 0.5, light), (5.0, 0.45, dark))):
        for j in range(6):
            a0 = math.tau * j / 6 + k * 0.4
            d.arc("arena", m, c, r, a0, a0 + 0.8, w, 0.0076 + 0.0002 * k, 0.25)
    well = (c[0] + 2.0, c[1] - MIST_R - 2.5)
    st, std = d.m("lagar_pedra", STONE), d.m("lagar_pedra_esc", STONE_D)
    d.cyl("poco", std, well, 2.9, 2.8, 0.4, 0.0, 12)
    d.cyl("poco", st, well, 2.5, 2.4, 0.9, 0.4, 12)
    d.cyl("poco", d.m("poco_leite", (0.8, 0.79, 0.84)), well, 2.05, 2.05, 0.05, 1.3, 12)
    for s in (-1, 1):
        d.cyl("poco", std, (well[0] + s * 2.3, well[1]), 0.22, 0.2, 3.2, 0.0, 6)
    d.box("poco", std, well, (5.0, 0.3, 0.4), 0.0, 3.2)
    bl.mask(d, "poco", (well[0], well[1] + 0.25), 2.6, 180.0, 0.9)
    z.ob("pillar", well[0], well[1], (5.6, 3.4, 5.6), visible=False)
    dead = d.m("cepa_morta", (0.46, 0.38, 0.4))
    for k in range(14):                                       # cepas retorcidas por fora da arena (vão largo para a estrada, ao sul)
        a = 360.0 * k / 14 + 12.0
        if 40.0 < a % 360.0 < 140.0 or 245.0 < a % 360.0 < 295.0:
            continue
        q = H(MIST_R + 2.2, a, c)
        d.tube("cepa", dead, [(q[0], 0.0, q[1]), (q[0] + 0.3, 1.0, q[1] - 0.2), (q[0] - 0.25, 1.9, q[1] + 0.2), (q[0] + 0.5, 2.6, q[1])], 0.3, 0.08, 5)
        d.solid(q[0], q[1], 0.9, 0.9, 2.6)
    z.block(c, MIST_R + 5.0)


def profaned(z, d, c):
    """O Santuário da Aurora, profanado pelo Festim: disco do sol rachado, fitas amarradas nos pilares, máscaras penduradas."""
    gold = d.m("sol_aurora", (0.86, 0.78, 0.56))
    st = d.m("lagar_pedra_esc", STONE_D)
    d.cyl("santuario", st, c, 1.5, 1.3, 0.5, 0.0, 8)
    d.cyl("santuario", gold, (c[0], c[1] - 0.3), 1.25, 1.25, 0.22, 2.0, 12, 0.0, tilt=(90, 0))
    d.box("santuario", d.m("sol_rachadura", (0.3, 0.24, 0.28)), (c[0] + 0.2, c[1] - 0.16), (0.12, 2.3, 0.06), 0.0, 0.85, tilt=(0, 16))
    for k in range(8):
        a = 360.0 * k / 8 + 22.5
        q = H(6.4, a, c)
        col = bl.BUNTING[k % len(bl.BUNTING)]
        cm = d.m("pano_fita_%d_%d" % (int(col[0] * 100), int(col[2] * 100)), col)
        d.cloth("santuario", cm, (q[0], q[1]), 0.5, 1.6, -a, 2.0 + (k % 3) * 0.5, 0.45)
        if k % 2 == 0:
            bl.mask(d, "santuario", H(5.9, a, c), 1.7, bl.facing(c[0] - q[0], c[1] - q[1]), 0.7)


def fugitives(z, d, c):
    """Acampamento dos Fugidos: quem escapou da festa. Tendas remendadas em meia-lua, fogo de cozinha, varal, carroça e
    uma barricada de móveis virada para a estrada. Lugar amigo (sem monstros)."""
    places._ground(z, "fugidos", c, 11.0, (0.62, 0.58, 0.5))
    for k, a in enumerate((60.0, 110.0, 160.0, 210.0)):
        q = H(7.4, a, c)
        z.ob("tent", q[0], q[1], (3.0, 2.2, 3.0), -a + 90.0, color=[(0.7, 0.72, 0.76), (0.78, 0.74, 0.66), (0.6, 0.64, 0.7)][k % 3])
    d.cookfire((c[0] + 0.5, c[1] - 0.5), 1.0, 30.0)
    d.solid(c[0] + 0.5, c[1] - 0.5, 1.8, 1.8, 1.0)
    d.laundry((c[0] - 8.5, c[1] - 3.0), (c[0] - 5.0, c[1] - 7.5))
    d.cart((c[0] + 8.5, c[1] - 1.0), 100.0, load=(0.74, 0.7, 0.6))
    d.solid(c[0] + 8.5, c[1] - 1.0, 2.0, 3.0, 1.4, 100.0)
    bl.barricade(z, d, (c[0] - 1.5, c[1] - 9.5), bl.facing(0.0, -1.0), 3.6)
    d.cargo((c[0] - 9.0, c[1] + 1.0), 4, 1.0)
    z.npc("fugitive_elder", round(c[0] + 2.5, 2), round(c[1] - 3.5, 2), bl.facing(0.6, -0.8))
    z.npc("fugitive_cook", round(c[0] - 1.8, 2), round(c[1] + 1.2, 2), 120.0)
    places._trail(z, "fugidos", Vector(c), Vector((c[0] + 5.5, c[1] - 6.5)))
    z.data.setdefault("places", []).append({"id": "fugidos", "type": "camp", "pos": [c[0], c[1]]})
    z.block(c, 12.5)


def build(export=False):
    z = Zone(ZONE, size=260.0, rim=(116.0, 6.0, 3.5, 2.2), seed=53, palette={
        "road": (0.87, 0.8, 0.66), "street": (0.84, 0.79, 0.7), "water": (0.5, 0.68, 0.86),
        "cliff_rock": (0.6, 0.66, 0.46), "cliff_rock_d": (0.5, 0.57, 0.42), "cliff_grass": (0.56, 0.7, 0.44),
        "hill_grass": (0.6, 0.7, 0.46), "leaf": (0.4, 0.6, 0.4), "wood": (0.56, 0.44, 0.34),
    })
    z.trail_color = (0.8, 0.73, 0.6)
    dn = Dress(z, seed=201)
    d_l0 = Dress(z, seed=202, tag="l0_festim", when={"unless": Q_CELLARS})
    d_l2 = Dress(z, seed=203, tag="l2_colheita", when={"if": Q_CELLARS})
    widths = {}

    def road(name, pts, w=zone_lib.ROAD_W):
        widths[name] = w
        return z.road(name, pts, w=w, end_clearing=False)

    # ---------- chegada (sul) e volta para Lumeria ----------
    portal, arrive = polar(z, 90.0, 7), polar(z, 90.0, 16)
    z.data["spawn"] = list(arrive)
    z.portal("to_city_lumeria", portal, "city_lumeria", LUMERIA_ARRIVE, "Lumeria, a Festa Eterna (Lv 45-47)")
    z.block(arrive, 7.5)
    print("BACK lumeria (target_pos do portal de Lumeria para as Vinhas)", arrive)
    quinta(z, dn)

    # ---------- estradas (curvas, em laços) e o Riacho do Mosto ----------
    road("sul", [(0.0, HUB_R - 1.0), (5.0, 28.0), (4.0, 40.0), (-4.0, 62.0), (2.0, 84.0), arrive, portal])
    road("norte", [(0.0, -HUB_R + 1.0), (6.0, -32.0), (-2.0, -50.0), (6.0, -62.0), (10.0, -70.0)])
    road("oeste", [(-HUB_R + 1.0, 0.0), (-32.0, 5.0), (-50.0, -2.0), (-62.0, 3.0), YARD])
    road("terracos", [YARD, (-76.0, -14.0), (-73.0, -30.0), (-62.0, -39.0)])
    road("nevoa", [(-62.0, -39.0), (-46.0, -36.0), (-24.0, -41.0), (-2.0, -50.0)])
    road("leste", [(HUB_R - 1.0, 0.0), (30.0, -7.0), (47.0, -6.0), (62.0, -7.0), E_JUNCTION])
    road("santuario_norte", [E_JUNCTION, (75.0, -30.0), (70.0, -48.0), (64.0, -62.0), (53.0, -74.0), (38.0, -80.0), (22.0, -77.0), (10.0, -70.0)])
    road("santuario_sul", [E_JUNCTION, (74.0, 12.0), (68.0, 32.0), (56.0, 44.0), (38.0, 43.0), (20.0, 50.0), (4.0, 40.0)])
    road("fugidos", [(-4.0, 62.0), (-20.0, 70.0), (-36.0, 66.0), (-54.0, 54.0), (-68.0, 34.0), YARD])
    z.arrival(arrive, toward=portal)
    z.river(RIVER, w=7.0)
    z.bridges()
    z.plaza("terreiro", YARD, 6.5, "road")
    z.plaza("largo_leste", E_JUNCTION, 5.5, "road")

    # ---------- chão: terra do vinhedo (lilás dessaturado), campo em manchas ----------
    tones = act2_dress.floor_tone_colors(GROUND, 0.07)
    dn.mottle([("campo_claro", tones[0]), ("campo_esc", tones[1]), ("campo_seco", (0.66, 0.67, 0.5))], [((0, 0), 110, 150)], y=0.0008, rmin=4.0, rmax=9.0)
    em = dn.m("patch_terra_vinha", EARTH)
    for c, r, sx, rot in (((-70.0, -8.0), 22.0, 1.5, 80.0), ((-56.0, 36.0), 15.0, 1.4, 60.0), ((-30.0, -86.0), 13.0, 1.6, 10.0),
                          ((28.0, -44.0), 11.0, 1.5, 70.0), ((-26.0, 42.0), 11.0, 1.4, 80.0), ((78.0, 28.0), 13.0, 1.6, 70.0),
                          ((26.0, 26.0), 9.0, 1.3, 30.0)):
        dn.blob("vinha_chao", em, c, r, 0.0034, 0.16, sx=sx, rot=rot)

    # ---------- POIs ----------
    for i, (c, r, lv) in enumerate(TERRACES):                 # Vinhedo em Terraços: patamares sólidos, videira em cima
        top = z.terrace("vinhedo_%d" % i, c, r, lv, rock="cliff_rock", top="hill_grass")
        rr = r * (1.0 - 0.28 * (lv - 1))
        for k in range(3):
            g = [H(rr * (0.32 + 0.24 * k), a, c) for a in (-70.0, -20.0, 30.0, 80.0)]
            af.vine_rows(dn, g, 1, y0=top, g="vinha_alta")
    door, door_front = lagar(z, dn, d_l0, LAGAR)
    mist_well(z, dn, MIST)
    fugitives(z, dn, CAMP)
    places.build(z, PLACES)
    profaned(z, dn, SHRINE)
    z.data["places"].append({"id": "lagar", "type": "dungeon", "pos": list(LAGAR)})

    # ---------- relevo: morros de borda e afloramentos ----------
    for i, (c, r, lv) in enumerate([((-64.0, -92.0), 8.0, 2), ((96.0, 42.0), 8.0, 2), ((-22.0, 104.0), 6.5, 1), ((60.0, -104.0), 6.0, 2),
                                     ((-100.0, 56.0), 7.0, 2), ((98.0, -74.0), 6.0, 1)]):
        z.hill("morro_%d" % i, c, r, lv, rock="cliff_rock", top="hill_grass", step=1.9)
    for i, (c, r) in enumerate([((-26.0, 22.0), 4.5), ((30.0, 8.0), 4.0), ((-28.0, -18.0), 4.5), ((24.0, -24.0), 4.0)]):
        z.terrace("afloramento_%d" % i, c, r, 1, top="cliff_grass")
    af.vine_hills(z)

    # ---------- fileiras de videira no chão (só visual; falhas viram passagem) ----------
    vok = lambda x, zz: dn.ok(x, zz, 0.9, road=1.3, blocked=True, water=1.6)
    n_vines = 0
    for guide, rows in (([(-84.0, -46.0), (-80.0, -24.0), (-82.0, -2.0), (-79.0, 20.0), (-72.0, 40.0), (-62.0, 52.0)], 6),
                        ([(-60.0, -30.0), (-54.0, -16.0), (-50.0, 0.0), (-52.0, 16.0), (-58.0, 32.0), (-52.0, 46.0), (-40.0, 54.0)], 7),
                        ([(-56.0, -92.0), (-34.0, -84.0), (-14.0, -88.0)], 6),
                        ([(22.0, -62.0), (30.0, -48.0), (34.0, -30.0), (30.0, -16.0)], 6),
                        ([(-36.0, 24.0), (-25.0, 40.0), (-24.0, 56.0)], 6),
                        ([(18.0, 14.0), (30.0, 26.0), (34.0, 38.0)], 5),
                        ([(88.0, 6.0), (86.0, 22.0), (80.0, 36.0), (70.0, 50.0), (62.0, 66.0), (64.0, 86.0)], 6),
                        ([(14.0, 98.0), (26.0, 90.0), (34.0, 80.0)], 4),
                        ([(-12.0, -22.0), (-22.0, -30.0), (-38.0, -28.0)], 4),
                        ([(60.0, -24.0), (62.0, -40.0), (58.0, -54.0)], 4),
                        ([(-20.0, 86.0), (-12.0, 96.0), (-14.0, 106.0)], 3),
                        ([(96.0, -34.0), (98.0, -48.0), (92.0, -62.0)], 3)):
        n_vines += af.vine_rows(dn, guide, rows, ok=vok)
    print("videiras no chao: %d moitas" % n_vines)

    # ---------- vegetação ----------
    obs = z.data["obstacles"]
    z.scatter("tree", [((0, 0), 108, 30), ((60, -20), 22, 6), ((-10, 84), 22, 6), ((-20, -70), 18, 5)], 0, (1.7, 4.2, 1.7), TREES,
              margin=5.0, spacing=8.0, hub_r=HUB_R + 7.0)
    z.rim_belt(64, (1.6, 4.4, 1.6), TREES[:2])
    nrnd = random.Random(531)
    free = lambda x, zz, m: z.free(x, zz, m, HUB_R + 5.0)
    nature.fix_trees(obs, nrnd)
    nature.scatter(z.ob, free, nrnd, "bush", [((0, 0), 106, 70)], (1.5, 0.85, 1.5), [(0.5, 0.36, 0.6), (0.44, 0.6, 0.4), (0.5, 0.64, 0.42)],
                   solid=False, margin=2.6, spacing=3.4, avoid=obs)
    nature.scatter(z.ob, free, nrnd, "flowers", [((0, 0), 104, 60)], (1.4, 0.4, 1.4), [(0.84, 0.74, 0.96), (0.98, 0.9, 0.7), (0.96, 0.78, 0.84)],
                   solid=False, margin=2.4, spacing=3.2, avoid=obs)
    nature.scatter(z.ob, free, nrnd, "rock", [((0, 0), 106, 26)], (1.4, 1.0, 1.2), [(0.72, 0.68, 0.62), (0.64, 0.6, 0.58)],
                   margin=3.8, spacing=4.0, scale=(0.7, 1.5), avoid=obs)
    nature.clear_banks(obs, z.rivers, [], z.river_w)
    nature.shore(z.ob, nrnd, z.rivers, [], list(z.road_polys.values()), z.river_w, colors=[(0.56, 0.66, 0.44), (0.62, 0.6, 0.7)], keep=0.65)

    # ---------- monstros (45-47; ids de MonstersCatalog.ACT3_MOBS). Teto do GDD §11: <= 140 vivos com x1,6 e escoltas ----------
    M = MOBS
    sp = z.spawner
    sp(M["vine"], -80.0, -20.0, 7, 3, 30.0)                   # Vinhas Sedentas: paradas entre as fileiras
    sp(M["vine"], -56.0, 22.0, 7, 3, 30.0)
    sp(M["vine"], -76.0, 34.0, 6, 2, 30.0)
    sp(M["vine"], 80.0, 30.0, 7, 3, 30.0)
    sp(M["vine"], -62.0, -76.0, 5, 2, 30.0)                   # as que guardam o caminho do Poço
    sp(M["reveler"], 16.0, 58.0, 7, 3, 24.0)                  # Foliões nas estradas
    sp(M["reveler"], 38.0, -18.0, 7, 3, 24.0)                # WP5: a 40+ m da Quinta (_check_zone_layout)
    sp(M["reveler"], -40.0, 10.0, 7, 3, 24.0)
    sp(M["reveler"], -6.0, -44.0, 7, 3, 24.0)
    sp(M["reveler"], 60.0, 54.0, 7, 3, 24.0)
    sp(M["hound"], -30.0, 44.0, 8, 3, 26.0)                   # matilhas de Galgos
    sp(M["hound"], 34.0, -40.0, 8, 3, 26.0)
    sp(M["hound"], 84.0, 6.0, 8, 3, 26.0)
    sp(M["chorister"], 80.0, -32.0, 6, 3, 26.0)               # Coristas: santuário e margens
    sp(M["chorister"], 30.0, 28.0, 6, 2, 26.0)
    sp(M["chorister"], -14.0, -64.0, 6, 2, 26.0)
    sp(M["censer"], 30.0, -86.0, 5, 2, 34.0)                  # 46-47: Incensários e Bailarinos em volta do Lagar
    sp(M["censer"], -16.0, -40.0, 5, 2, 34.0)
    sp(M["censer"], -68.0, -56.0, 4, 1, 34.0)
    sp(M["dancer"], -12.0, -80.0, 7, 3, 26.0)
    sp(M["dancer"], 34.0, -50.0, 6, 2, 26.0)
    sp(M["master"], 30.0, -68.0, 4, 1, 180.0)                 # Mestres de Cerimônias (3 Foliões de escolta cada); longe da porta das Adegas
    sp(M["master"], 70.0, -14.0, 4, 1, 180.0)
    z.data["world_boss_hint"] = [{"id": BOSS_ID, "name": "Dona Vindima, a Vinha que Bebe", "level": 47, "pos": list(MIST), "radius": 2.0,
                                  "arena_r": MIST_R, "respawn": "Balance.WORLD_BOSS_RESPAWN_S (600)", "summons": [M["vine"], M["vine"]]}]
    print("vivos (x1,6 + escoltas + chefe de mundo e 2 lacaios): %d" % af.live_count(z, extra=3))

    # ---------- acabamento ----------
    dn.road_edges((0.78, 0.74, 0.6), extra=1.4)
    dn.roadside(dn.m("seixo", (0.74, 0.7, 0.64)), dn.m("capim_beira", (0.52, 0.64, 0.42)), every=8.0)
    rnd = random.Random(535)
    for q in dn.spots([((0, 0), 104, 26)], r=1.2, spacing=14.0, blocked=True, road=2.0):      # cestos e escadas da vindima abandonada
        dn.crate(q, 0.7, rnd.uniform(0, 90), g="vindima")
        dn.sack((q[0] + 0.8, q[1] + 0.3), 0.9, g="vindima", color=(0.5, 0.36, 0.6))
    for q in dn.spots([((-66.0, 10.0), 26, 4), ((70.0, 34.0), 16, 2)], r=1.0, spacing=16.0, blocked=True, road=2.0):
        dn.scarecrow(q, rnd.uniform(0, 180))
    for q in d_l2.spots([((-68.0, 8.0), 28, 9), ((76.0, 30.0), 16, 4), ((-28.0, 42.0), 10, 3)], r=1.2, spacing=7.0, blocked=True, road=1.6):     # L2: a colheita volta
        d_l2.cargo(q, 3, 1.0, g="colheita")
        d_l2.hay((q[0] + 1.6, q[1] - 0.6), 0.6, g="colheita")
    d_l2.cart((YARD[0] + 3.5, YARD[1] + 8.5), 30.0, load=(0.5, 0.36, 0.6))
    for kind, name, frac, side in (("banquete", "sul", 0.3, 1), ("banquete", "leste", 0.75, -1), ("banquete", "oeste", 0.62, 1)):       # L0: mesas na beira da estrada
        poly = z.road_polys[name]
        i = int(len(poly) * frac)
        t = (poly[i + 1] - poly[i - 1]).normalized()
        q = poly[i] + Vector((-t.y, t.x)) * side * 5.0
        if dn.ok(q.x, q.y, 2.5, road=0.6):
            bl.banquet(af.NO_OB, d_l0, (q.x, q.y), along(t.x, t.y), 4.6)
    for k, (name, frac) in enumerate((("sul", 0.75), ("norte", 0.5), ("leste", 0.3), ("oeste", 0.3), ("santuario_sul", 0.55), ("fugidos", 0.4))):
        poly = z.road_polys[name]
        i = int(len(poly) * frac)
        t = (poly[i + 1] - poly[i - 1]).normalized()
        q = poly[i] + Vector((-t.y, t.x)) * 3.6
        dn.signpost((q.x, q.y), along(t.x, t.y)) if k % 2 == 0 else dn.flag((q.x, q.y), bl.BUNTING[k % 5], 4.6, along(t.x, t.y), tatter=False)

    # ---------- dados para a integração (WP5) ----------
    z.data["future_portals"] = [
        {"id": "to_dg_cellars", "pos": [round(door[0], 2), round(door[1], 2)], "arrive": [round(door_front[0], 2), round(door_front[1], 2)],
         "target_map": "dg_cellars", "label": "Adegas do Banquete (Lv 46-47)"},
    ]
    af.event_points(z, EVENT_POINTS, widths, bosses=[MIST])
    print("eventos:", [(e["kind"], e["pos"]) for e in z.data["events"]])
    z.data["stage_tags"] = [{"tag": "l0_festim", "unless": Q_CELLARS}, {"tag": "l2_colheita", "if": Q_CELLARS}]
    z.data["stage_npcs"] = {"freed_vintner_a": {"if": Q_CELLARS}, "freed_vintner_b": {"if": Q_CELLARS}, "freed_vintner_c": {"if": Q_CELLARS}}
    z.npc("freed_vintner_a", -66.0, 12.0, 90.0)
    z.npc("freed_vintner_b", -54.0, -10.0, 200.0)
    z.npc("freed_vintner_c", 74.0, 26.0, 250.0)
    z.data["living_hint"] = [
        {"id": "freed_vintner_a", "carry": "carry_crate", "route": [[-66.0, 12.0], [-58.0, 24.0], [-62.0, 36.0], [YARD[0] + 2.0, YARD[1] + 4.0]], "if": Q_CELLARS},
        {"id": "freed_vintner_b", "carry": "carry_sack", "route": [[-54.0, -10.0], [-64.0, -20.0], [YARD[0] - 2.0, YARD[1] - 3.0]], "if": Q_CELLARS},
        {"id": "freed_vintner_c", "carry": "carry_crate", "route": [[74.0, 26.0], [80.0, 38.0], [70.0, 46.0]], "if": Q_CELLARS},
    ]
    # névoa lilás baixa (só fx): a metade marcada some quando as Adegas caem (L2)
    mist_pts = [MIST, (MIST[0] - 14.0, MIST[1] + 10.0), (MIST[0] + 16.0, MIST[1] + 8.0), (-70.0, -10.0), (-58.0, 30.0), (-80.0, 24.0), (LAGAR[0], LAGAR[1] + 18.0),
                (30.0, -50.0), (78.0, 26.0), (60.0, -70.0), (-24.0, 44.0), (24.0, 30.0), (-10.0, -80.0), (84.0, -6.0)]
    z.data["fx"] = [dict({"kind": "mist", "pos": [round(p[0], 1), round(p[1], 1)], "r": 14.0 if i < 3 else 10.0}, **({"unless": Q_CELLARS} if i % 2 else {}))
                    for i, p in enumerate(mist_pts)]
    z.data["hangouts"] += [[YARD[0] + 2.0, YARD[1] + 2.5], [E_JUNCTION[0] - 2.0, E_JUNCTION[1] + 2.0], [CAMP[0] + 3.0, CAMP[1] - 5.0],
                           [LAGAR[0] + 4.0, LAGAR[1] + 19.0]]
    z.data["poi"] = {"quinta": [0.0, 6.5], "terracos": [YARD[0] - 6.0, YARD[1] - 6.0], "lagar": [LAGAR[0], LAGAR[1] + 16.0], "marco": [LAGAR[0], LAGAR[1] + 34.0], "nevoa": list(MIST),
                     "santuario": [SHRINE[0] - 6.0, SHRINE[1] + 4.0], "fugidos": [CAMP[0] + 3.0, CAMP[1] - 4.0], "tanoeiro": [COOPER[0] - 4.0, COOPER[1] - 4.0],
                     "destiladora": [DISTILLER[0] - 5.0, DISTILLER[1] + 5.0], "chegada": list(arrive)}
    z.data["landmark"] = {"id": "lagar_gigante", "pos": list(LAGAR), "height": 13.0}
    z.data["monster_ids"] = dict(MOBS)
    z.data["patrol_hint"] = [{"id": "ronda_vinhas", "mob": M["hound"], "route": [[round(p.x, 1), round(p.y, 1)] for name in ("terracos", "nevoa") for p in z.road_polys[name][::6]]}]
    z.data["gather_hint"] = [
        {"item": "Uva do Perfume (missão/alquimia)", "shape": "herb", "pos": [-66.0, -16.0], "radius": 14.0, "count": 6},
        {"item": "Uva do Perfume (missão/alquimia)", "shape": "herb", "pos": [76.0, 32.0], "radius": 10.0, "count": 4},
        {"item": "Fita do Festim", "shape": "crate", "pos": [LAGAR[0] + 8.0, LAGAR[1] + 22.0], "radius": 7.0, "count": 4},
        {"item": "Porcelana Chorosa", "shape": "relic", "pos": [SHRINE[0] - 8.0, SHRINE[1] + 10.0], "radius": 6.0, "count": 2},
        {"item": "erva do riacho (herb_blue)", "shape": "herb_blue", "pos": [38.0, 16.0], "radius": 6.0, "count": 3},
    ]
    z.data["ground_hint"] = {"ground_color": list(GROUND), "note": "relva salvia; terra do vinhedo lilas dessaturada pintada por cima"}

    act3_ready.promote(z.data)       # future_portals de mapa já registrado viram portal (act3_ready.READY)
    for d in (dn, d_l0, d_l2):
        d.flush()
    poi = z.data["poi"].get(os.environ.get("PERFUME_POI", "lagar"), z.data["poi"]["lagar"])
    data = z.finish(export, poi=tuple(poi), ground=GROUND)
    af.walk_check(data)
    return data
