"""Estepes de Cinza (field_steppe, Lv 35-40): vale de capim dourado queimado e manchas de cinza, fechado por mesas de
rocha e ravinas. No centro, o Posto da Caravana (anel de carroças de lona; serviços, cristal, o Mestre da Caravana).
Três acampamentos de guerra da Horda fecham três lados (oeste = trolls, nordeste = Ghar, sudeste = flechas de fogo):
cada um é um anel de estacas escuras com estandartes vermelhos atravessado pela estrada, e atrás dele a garganta que
leva ao mapa do acampamento (fort_trolls / fort_war / fort_fire). Retomado (quest do chefe), vira posto aliado:
estandartes branco-dourados, tendas da Aurora, sentinelas; a frente dele para de mandar investida ao Posto.
POIs: Cemitério dos Mamutes (sudoeste, do outro lado do rio), Acampamento dos Desertores (noroeste, escondido),
Totem dos Ventos ao pé do marco. Marco: o Totem Partido, numa mesa a nordeste. O rio largo azul-acinzentado corta o
oeste (duas pontes). Sul = passagem da Costa Partida; norte = passo do Monte Kharzun (fechado: sem mapa ainda).

    set RAGNAEX_ROOT=<projeto ou worktree>
    blender -b --factory-startup --python tools/blender/zones/run_zone.py -- build_field_steppe <pasta_png> --export
    (STEPPE_POI=<trolls|war|fire|mamutes|desertores|totem|passo> escolhe o alvo da CAM_poi)
"""
import math
import os
import random
import act2_dress
import horde
import nature
import places
import zone_lib
from zone_lib import Zone, box, cyl, cone, disc, mat

ZONE = "field_steppe"
COAST_ARRIVE = (27.6, -85.0)            # chegada em field_coast (build_field_coast.STEPPE_ARRIVE)
FORT_ARRIVE = (0.0, 96.0)               # chegada em todo mapa de acampamento (build_steppe_forts.ARRIVE)
KHARZUN_ARRIVE = (0.0, 92.6)            # chegada em field_kharzun (build_kharzun.py: "BACK steppe")
KHARZUN_READY = True                    # INTEGRAÇÃO (WP5): True quando field_kharzun estiver no MapsCatalog; refaça o JSON das Estepes
HUB_R = 22.0
HUB_GATES = [0.0, 90.0, 180.0, -90.0]   # graus: leste (Ghar e flechas), sul (Costa), oeste (trolls), norte (Kharzun)
CAMP_R = 13.0                           # anel de estacas de cada acampamento de guerra
FORT_Q = {"trolls": "hx_fort_trolls", "fire": "hx_fort_fire", "war": "hx_fort_war"}
ALL_FORTS = [FORT_Q["trolls"], FORT_Q["fire"], FORT_Q["war"]]
DES_HELP, DES_TURN = "hx_deserters_help", "hx_deserters_turn"
FRONTS = {
    "trolls": {"deg": 180.0, "label": "Toca do Rei-da-Rocha", "ground": (0.44, 0.42, 0.42)},
    "war": {"deg": -30.0, "label": "Arraial de Ghar", "ground": (0.46, 0.31, 0.26)},
    "fire": {"deg": 35.0, "label": "Paliçada das Flechas de Fogo", "ground": (0.27, 0.24, 0.23)},
}
RIVER = [(-100.0, -90.0), (-78.0, -66.0), (-58.0, -44.0), (-45.0, -17.0), (-47.0, 8.0), (-50.0, 34.0), (-40.0, 58.0), (-36.0, 84.0), (-40.0, 125.0)]
GRAVEYARD = (-88.0, 50.0)
DESERTERS = (-36.0, -82.0)
TOTEM = (42.0, -80.0)
SHRINE = (22.0, -62.0)
AURORA_BLUE = (0.36, 0.48, 0.78)
DRY = [(0.52, 0.44, 0.3), (0.46, 0.4, 0.3), (0.58, 0.5, 0.34)]

PLACES = [
    {"type": "cabin", "id": "marfim", "pos": (-56.0, 82.0), "face": 250.0, "npc": "ivory_hunter", "roof": (0.86, 0.82, 0.68), "wall": (0.56, 0.44, 0.32)},
    {"type": "cabin", "id": "canil", "pos": (40.0, 80.0), "face": 235.0, "npc": "wolf_racer", "roof": (0.5, 0.36, 0.3), "wall": (0.62, 0.5, 0.36)},
    {"type": "shrine", "id": "totem_ventos", "pos": SHRINE, "npc": "wind_totem", "ground": (0.72, 0.64, 0.5)},
    {"type": "camp", "id": "batedores", "pos": (86.0, 0.0), "face": 180.0, "mob": "wolf_raider", "count": 2, "cloth": horde.HORDE_RED, "respawn": 30.0,
     "ground": (0.4, 0.36, 0.32)},
]


def polar(z, ang_deg, inset):
    a = math.radians(ang_deg)
    r = z.rim_r(a) - inset
    return (round(math.cos(a) * r, 1), round(math.sin(a) * r, 1))


def H(r, deg):
    return (round(math.cos(math.radians(deg)) * r, 2), round(math.sin(math.radians(deg)) * r, 2))


def route_of(*polys, step=7):
    """Rota de marcha (da garganta ao Posto): pontos das estradas dadas, de trás para a frente."""
    out = []
    for poly in polys:
        pts = list(reversed(poly))[::step]
        out += [[round(p.x, 1), round(p.y, 1)] for p in pts]
    return out


def caravan_post(z):
    """Posto da Caravana: anel de carroças com quatro vãos, praça de terra batida, fogueira e o estandarte no meio,
    serviços nos quatro cantos (forja, alquimia, mercado, depósito + cristal)."""
    z.M["patch_posto_terra"] = mat("patch_posto_terra", (0.64, 0.55, 0.42))      # terra batida (patch_ = chão pintado, não calçamento)
    z.patch("posto", (0.0, 0.0), HUB_R + 4.0, (0.6, 0.54, 0.42))
    z.plaza("posto", (0.0, 0.0), HUB_R - 2.5, "patch_posto_terra")
    gates = [math.radians(g) for g in HUB_GATES]
    horde.wagon_ring(z, "posto", (0.0, 0.0), HUB_R, gates, gate_half=4.6, canvases=(horde.CANVAS, (0.8, 0.74, 0.6), (0.9, 0.86, 0.78)))
    z.data["town"] = {"center": [0.0, 0.0], "radius": HUB_R, "gates": [list(H(HUB_R, g)) for g in HUB_GATES]}
    for g in HUB_GATES:                                   # mastros azuis nos vãos: quatro pares marcam as saídas de cima
        for sgn in (-1, 1):
            q = H(HUB_R, g + sgn * 15.5)
            horde.banner(z, "posto_vao_%d_%d" % (int(g), sgn), q, AURORA_BLUE, 4.6, -g + 90.0)
            z.ob("pillar", q[0], q[1], (0.7, 4.6, 0.7), visible=False)
            lq = H(HUB_R - 3.0, g + sgn * 13.0)
            z.ob("lamp", lq[0], lq[1], (0.4, 3.0, 0.4))
    horde.campfire(z, "posto_fogueira", (0.0, 0.0), 1.5)
    cyl(z.coll, z.P + "posto_mastro", (2.6, -2.6), 0.18, 0.12, 9.0, mat("vigia", (0.52, 0.38, 0.24)), 0.0, 6)
    horde.cloth(z.coll, z.P + "posto_bandeira", (2.6, -2.6), 2.6, 1.7, 0.0, mat("bandeira_aurora", horde.AURORA_GOLD), 7.1, tail=None)
    z.ob("pillar", 2.6, -2.6, (0.7, 9.0, 0.7), visible=False)
    # nordeste: forja de campo (carroça-forja + bigorna)
    horde.wagon(z, "posto_forja", H(15.0, -45.0), 45.0, (0.5, 0.36, 0.3), length=4.6)
    z.ob("anvil", *H(10.5, -34.0), (1.0, 0.9, 0.6), 30.0)
    z.ob("barrel", *H(11.5, -58.0), (0.8, 1.0, 0.8))
    # sudeste: mercado (duas barracas)
    for i, a in enumerate((28.0, 60.0)):
        z.ob("stall", *H(13.5, a), (3.0, 2.4, 2.0), -a + 90.0, color=[(0.82, 0.7, 0.36), (0.36, 0.5, 0.74)][i])
    # sudoeste: depósito (carroça + caixotes) e o cristal de retorno (pilar oculto vem do MapsCatalog.CRYSTALS)
    horde.wagon(z, "posto_deposito", H(15.0, 128.0), -128.0 + 90.0, (0.74, 0.7, 0.6), length=4.6)
    for k, a in enumerate((108.0, 116.0, 146.0)):
        z.ob("crate", *H(11.5 + (k % 2) * 1.2, a), (1.0, 1.0, 1.0), k * 25.0)
    # noroeste: alquimia (tenda + caldeirão)
    z.ob("tent", *H(15.0, -135.0), (3.2, 2.3, 3.0), 135.0 - 90.0, color=(0.5, 0.74, 0.6))
    z.ob("cauldron", *H(10.5, -122.0), (1.1, 1.0, 1.1))
    z.ob("well", *H(10.0, -152.0), (1.6, 1.4, 1.6))
    for k, a in enumerate((35.0, 145.0, 215.0, 325.0)):      # troncos-banco em volta da fogueira
        p = H(4.2, a)
        z.ob("log", p[0], p[1], (2.6, 0.6, 0.65), -a + 90.0, color=(0.46, 0.34, 0.24))
    for k, a in enumerate((-68.0, 68.0, 152.0)):             # tendas dos caravaneiros encostadas nas carroças
        z.ob("tent", *H(16.5, a), (3.0, 2.2, 2.8), -a + 90.0, color=[(0.86, 0.8, 0.64), AURORA_BLUE, (0.8, 0.5, 0.3)][k])
    z.npc("caravan_master", 1.5, 5.5, 0.0)
    z.npc("steppe_smith", *H(8.5, -42.0), 140.0)
    z.npc("steppe_merchant", *H(9.5, 44.0), -135.0)
    z.npc("steppe_storage", *H(9.5, 126.0), -50.0)
    z.npc("steppe_alchemist", *H(8.5, -132.0), 50.0)
    for i, g in enumerate((180.0, 0.0, -90.0)):           # sentinelas nos três vãos por onde chegam as investidas
        for k, (role, off) in enumerate((("knight", -2.6), ("spearman", 2.6), ("crossbow", 0.0))):
            px, pz = H(HUB_R - (4.0 if role != "crossbow" else 7.0), g)
            a = math.radians(g)
            z.npc("steppe_g_%s_%d" % (role, i * 3 + k), round(px - math.sin(a) * off, 2), round(pz + math.cos(a) * off, 2), 180.0)
    z.data["hangouts"] = [list(H(r, a)) for r, a in ((5.0, 20.0), (5.0, 150.0), (5.5, -110.0), (6.0, 80.0), (12.0, 8.0), (12.0, 84.0),
                                                      (12.5, 172.0), (12.5, -82.0), (16.0, 76.0), (16.0, -14.0))]
    z.cam_game = (0.0, 0.0)
    z.block((0.0, 0.0), HUB_R + 5.0)


def war_camp(z, side, f, c):
    """Acampamento de guerra na estrada: anel de estacas escuras com dois vãos (Posto e garganta). Antes da retomada:
    chão queimado, tendas e estandartes vermelhos, torre de teto vermelho; depois: grama, tendas e estandartes da Aurora."""
    g, q = f["deg"], FORT_Q[side]
    before, after = {"unless": q}, {"if": q}
    ga = math.radians(g)
    disc(z.coll, z.P + "chao_front_%s" % side, c, CAMP_R + 9.0, 0.007, mat("patch_front_" + side, f["ground"]), 40, 0.12, len(side))
    disc(z.coll, z.P + "limpo_%s_chao" % side, c, CAMP_R + 8.0, 0.005, z.M["patch_limpo"], 40, 0.1, len(side) + 3)
    z.data["roads"].append({"kind": "street", "w": 0, "pts": [list(c)], "r": CAMP_R - 1.0})
    z.ring_wall("front_" + side, c, CAMP_R, [ga, ga + math.pi], gate_half=3.6, height=2.9, material="estaca_horda", stakes=True)
    P = lambda r, deg: (round(c[0] + math.cos(math.radians(g + deg)) * r, 2), round(c[1] + math.sin(math.radians(g + deg)) * r, 2))
    for k, deg in enumerate((60.0, 120.0, -60.0, -120.0)):      # tendas encostadas no anel (as duas versões no mesmo chão)
        p = P(8.6, deg)
        z.ob("tent", p[0], p[1], (3.2, 2.3, 3.0), -(g + deg) + 90.0, color=horde.HORDE_RED if k % 2 == 0 else (0.42, 0.2, 0.18), when=before)
        z.ob("tent", p[0], p[1], (3.2, 2.3, 3.0), -(g + deg) + 90.0, color=AURORA_BLUE if k % 2 == 0 else (0.88, 0.84, 0.7), when=after)
    for k, deg in enumerate((22.0, -22.0, 158.0, -158.0)):      # estandartes nos dois vãos: vermelho da Horda -> branco-dourado da Aurora
        p = P(CAMP_R + 0.4, deg)
        horde.banner(z, "estandarte_horda_%s_%d" % (side, k), p, horde.HORDE_RED, 6.0, -g + 90.0)
        horde.banner(z, "estandarte_aurora_%s_%d" % (side, k), p, horde.AURORA_GOLD, 6.0, -g + 90.0, pole=(0.82, 0.68, 0.48))
        z.ob("pillar", p[0], p[1], (0.6, 6.0, 0.6), visible=False)
    tw = P(9.4, 90.0)
    horde.watchtower(z, "torre_horda_%s" % side, tw, horde.HORDE_RED)
    cone(z.coll, z.P + "torre_aurora_%s_teto" % side, tw, 2.9, 1.9, mat("teto_aurora", AURORA_BLUE), 7.5, 4)
    fp = P(5.6, -90.0)
    horde.campfire(z, "front_%s_fogueira" % side, fp, 1.2)
    if side == "trolls":                                   # pedregulhos e ossos roídos
        for k, deg in enumerate((40.0, 140.0, -140.0, -35.0, 95.0)):
            p = P(CAMP_R + 5.0 + (k % 2) * 2.5, deg)
            z.ob("rock", p[0], p[1], (2.6 + k * 0.3, 1.8, 2.4), k * 50.0, color=(0.52, 0.5, 0.5))
        horde.skull(z, "front_trolls_cranio", P(CAMP_R + 6.0, -100.0), ga + 2.0, 0.8)
    elif side == "war":                                    # tambores de guerra dos dois lados do vão
        for k, deg in enumerate((150.0, -150.0)):
            horde.drum(z, "front_war_tambor_%d" % k, P(CAMP_R + 4.5, deg), 1.4)
        for k, deg in enumerate((75.0, 105.0, -75.0)):
            p = P(CAMP_R + 4.0, deg)
            z.ob("fence", p[0], p[1], (3.4, 1.4, 0.5), -(g + deg), color=horde.STAKE_DARK)
    else:                                                  # braseiros das flechas de fogo e chão de carvão
        for k, deg in enumerate((45.0, 135.0, -45.0, -135.0, 180.0)):
            p = P(CAMP_R + 4.0 + (k == 4) * 4.0, deg + (k == 4) * 14.0)
            cyl(z.coll, z.P + "front_fire_braseiro_%d" % k, p, 0.7, 0.9, 1.1, mat("braseiro", (0.22, 0.2, 0.2)), 0.0, 8)
            cyl(z.coll, z.P + "front_fire_chama_%d" % k, p, 0.6, 0.1, 1.3, mat("glow_brasa", (1.0, 0.56, 0.2)), 1.1, 6)
            z.ob("pillar", p[0], p[1], (1.8, 2.0, 1.8), visible=False)
    for k, (role, off) in enumerate((("spearman", -2.4), ("crossbow", 2.4))):     # sentinelas do posto aliado (só depois)
        p = P(CAMP_R - 3.0, 180.0)
        z.npc("steppe_p_%s_%s_%d" % (side, role, k), round(p[0] - math.sin(ga) * off, 2), round(p[1] + math.cos(ga) * off, 2), 180.0)
    z.data.setdefault("places", []).append({"id": "forte_" + side, "type": "dungeon", "pos": [c[0], c[1]]})
    z.block(c, CAMP_R + 6.0)


def mammoth_graveyard(z):
    """Cemitério dos Mamutes: chão de cinza clara, carcaças com costelas em arco, crânios com presas, um círculo de presas."""
    c = GRAVEYARD
    z.patch("mamutes", c, 19.0, (0.74, 0.72, 0.66))
    for i, (dx, dz, ang, n) in enumerate(((-6.0, -8.0, 0.4, 6), (8.0, 4.0, 2.0, 5), (-9.0, 9.0, 1.2, 4))):
        horde.ribcage(z, "mamute_%d" % i, (c[0] + dx, c[1] + dz), ang, n)
    for i, (dx, dz, ang, s) in enumerate(((2.0, -13.0, 1.6, 1.2), (13.0, -6.0, 3.0, 1.0), (-1.0, 14.0, 4.4, 1.0), (-15.0, 1.0, 0.0, 0.9))):
        horde.skull(z, "mamute_cranio_%d" % i, (c[0] + dx, c[1] + dz), ang, s)
    ivory = mat("marfim", (0.96, 0.93, 0.8))
    for k in range(6):                                      # portal de presas na chegada da estrada (lado leste)
        a = -0.9 + k * 0.36
        base = (c[0] + math.cos(a) * 17.5, c[1] + math.sin(a) * 17.5)
        if k in (2, 3):
            continue
        horde.rib(z.coll, z.P + "mamutes_presa_%d" % k, base, a, 5.0, 2.4, 0.4, 0.08, ivory)
        z.ob("pillar", base[0], base[1], (1.0, 5.0, 1.0), visible=False)
    z.block(c, 20.0)


def broken_totem(z):
    """Marco: o Totem Partido sobre uma mesa. Fuste de anéis vermelho/osso/ocre com asas, topo quebrado em dente de
    serra; a cabeça caída ao pé da mesa. ~25 m: aparece na câmera de longe em qualquer ponto do vale."""
    top = z.hill("mesa_totem", TOTEM, 10.0, 3, rock="cliff_rock", top="hill_grass", step=2.2)
    cols = [mat("totem_vermelho", (0.6, 0.2, 0.16)), mat("totem_osso", (0.88, 0.84, 0.72)), mat("totem_ocre", (0.84, 0.62, 0.24))]
    y = top
    for i in range(5):
        cyl(z.coll, z.P + "totem_anel_%d" % i, TOTEM, 2.6 - i * 0.12, 2.4 - i * 0.12, 3.6, cols[i % 3], y, 8)
        if i in (1, 3):                                     # olhos de runa (vento) virados para o Posto
            for sx in (-0.8, 0.8):
                box(z.coll, z.P + "totem_olho_%d_%d" % (i, sx > 0), (TOTEM[0] - 1.9 + 0.0, TOTEM[1] + 1.5 + sx), (0.5, 0.7, 0.5), 35.0, mat("glow_vento", (0.5, 0.9, 0.9)), y + 1.6)
        y += 3.6
    box(z.coll, z.P + "totem_asas", TOTEM, (15.0, 1.2, 0.9), 40.0, cols[0], top + 9.6)
    box(z.coll, z.P + "totem_asas_ponta", TOTEM, (18.0, 0.6, 0.6), 40.0, cols[2], top + 10.8)
    for k in range(5):                                      # quebra: lascas desiguais no topo
        a = math.tau * k / 5
        cyl(z.coll, z.P + "totem_lasca_%d" % k, (TOTEM[0] + math.cos(a) * 1.0, TOTEM[1] + math.sin(a) * 1.0), 0.7, 0.05, 1.2 + (k % 3) * 0.9, cols[1], y, 5)
    head = (TOTEM[0] - 15.0, TOTEM[1] + 6.0)                # a cabeça caída (lado do Posto)
    box(z.coll, z.P + "totem_cabeca", head, (5.2, 2.6, 3.0), 25.0, cols[0], 0.0)
    box(z.coll, z.P + "totem_cabeca_bico", (head[0] - 2.6, head[1] + 1.4), (2.6, 1.2, 1.2), 25.0, cols[2], 0.6)
    z.ob("wall", head[0], head[1], (5.6, 2.6, 3.4), 25.0, visible=False)
    z.block(head, 5.0)
    return y


def deserters_camp(z):
    """Acampamento dos Desertores: meia-lua de estacas escondida atrás de pedras. Enquanto a escolha não for "entregar",
    ficam as tendas cinza-esverdeadas (sem vermelho: largaram o estandarte); "ajudar" traz a barraca do mercador orc
    e o curral dos lobos de montaria."""
    c = DESERTERS
    stay = {"unless": DES_TURN}
    helped = {"if": DES_HELP}
    z.patch("desertores", c, 13.0, (0.5, 0.46, 0.38))
    z.ring_wall("desertores", c, 12.0, [math.radians(60.0)], gate_half=11.0, height=2.4, material="estaca_horda", stakes=True)
    for k, deg in enumerate((200.0, 250.0, 300.0)):
        p = (c[0] + math.cos(math.radians(deg)) * 7.6, c[1] + math.sin(math.radians(deg)) * 7.6)
        z.ob("tent", p[0], p[1], (3.2, 2.3, 3.0), -deg + 90.0, color=[(0.46, 0.5, 0.4), (0.52, 0.48, 0.38)][k % 2], when=stay)
    horde.campfire(z, "desertores_fogueira", (c[0] + 1.0, c[1] + 1.5), 1.1)
    horde.banner(z, "desertores_bandeira_rasgada", (c[0] + 8.5, c[1] + 9.5), (0.5, 0.5, 0.46), 5.0, 30.0)
    z.ob("stall", c[0] + 7.5, c[1] - 1.0, (3.0, 2.4, 2.0), 80.0, color=(0.56, 0.7, 0.4), when=helped)
    for k in range(5):                                       # curral dos lobos (só cerca: os lobos vêm do pacote de montaria)
        a = math.radians(95.0 + k * 34.0)
        z.ob("fence", c[0] - 5.0 + math.cos(a) * 4.2, c[1] + 8.5 + math.sin(a) * 4.2, (2.8, 1.0, 0.3), -math.degrees(a) + 90.0, color=(0.44, 0.34, 0.24), when=helped)
    z.npc("deserter_chief", c[0] + 3.5, c[1] + 4.5, 20.0)
    z.npc("deserter_merchant", c[0] + 6.0, c[1] + 0.5, 60.0)
    z.npc("deserter_wolf_keeper", c[0] - 3.0, c[1] + 6.0, 0.0)
    z.data.setdefault("places", []).append({"id": "desertores", "type": "camp", "pos": [c[0], c[1]]})
    z.block(c, 15.0)


def kharzun_pass(z):
    """Passo do Monte Kharzun (norte): garganta fechada por um portão de estacas da Horda até os três acampamentos caírem
    (E5). Ainda não existe mapa do outro lado: sem portal na sim; a posição fica em data["future_portals"]."""
    out, inn = polar(z, -90.0, 9), polar(z, -90.0, 20)
    z.portal_angles.append(math.atan2(out[1], out[0]))
    z.block(out, 7)
    stake = z.M["estaca_horda"]
    for i in range(-4, 5):
        x = inn[0] + i * 1.5
        h = 4.2 + (i % 3) * 0.5
        cyl(z.coll, z.P + "passo_fechado_estaca_%d" % i, (x, inn[1] - 4.0), 0.5, 0.45, h, stake, 0.0, 6)
        cone(z.coll, z.P + "passo_fechado_ponta_%d" % i, (x, inn[1] - 4.0), 0.52, 0.8, stake, h, 6)
    for k, sx in enumerate((-8.0, 8.0)):
        horde.banner(z, "passo_fechado_estandarte_%d" % k, (inn[0] + sx, inn[1] - 3.0), horde.HORDE_RED, 7.0, 0.0)
        horde.banner(z, "passo_aberto_estandarte_%d" % k, (inn[0] + sx, inn[1] - 3.0), horde.AURORA_GOLD, 7.0, 0.0, pole=(0.82, 0.68, 0.48))
        z.ob("pillar", inn[0] + sx, inn[1] - 3.0, (0.6, 7.0, 0.6), visible=False)
    if KHARZUN_READY:      # o mapa existe: portal de verdade (quem tranca é o MapsCatalog.PORTAL_GATES: nível 40 + os três fortes)
        z.portal("to_field_kharzun", out, "field_kharzun", KHARZUN_ARRIVE, "Monte Kharzun (Lv 40-45)")
        return inn, out
    z.ob("wall", inn[0], inn[1] - 4.0, (16.0, 5.0, 1.6), 0.0, visible=False)       # fechado na sim até o mapa existir
    z.data["future_portals"] = [{"id": "to_field_kharzun", "pos": list(out), "arrive": list(inn), "target_map": "field_kharzun",
                                 "label": "Monte Kharzun (Lv 40-45)", "if": ALL_FORTS}]
    return inn, out


def build(export=False):
    z = Zone(ZONE, seed=17, palette={
        "road": (0.5, 0.44, 0.36), "street": (0.66, 0.6, 0.5), "water": (0.42, 0.52, 0.62),
        "cliff_rock": (0.64, 0.47, 0.36), "cliff_rock_d": (0.5, 0.36, 0.29), "cliff_grass": (0.74, 0.62, 0.36),
        "hill_grass": (0.78, 0.66, 0.38), "leaf": (0.5, 0.52, 0.3), "wood": (0.5, 0.38, 0.26),
        "estaca_horda": horde.STAKE_DARK, "patch_limpo": (0.66, 0.72, 0.4),
    })
    portal = polar(z, 100, 7)           # sul-sudoeste: a Costa sai pelo norte-nordeste (rumo 18), a chegada aqui fica no rumo oposto (~190)
    arrive = polar(z, 100, 16)
    z.data["spawn"] = list(arrive)
    z.portal("to_field_coast", portal, "field_coast", COAST_ARRIVE, "Costa Partida (Lv 30-35)")
    print("BACK coast", arrive)
    caravan_post(z)

    # ---------- frentes: centro do acampamento, garganta e portal de cada lado ----------
    fr = {}
    for side, f in FRONTS.items():
        g = f["deg"]
        rim = z.rim_r(math.radians(g))
        rc = rim - 36.0
        fr[side] = {"c": H(rc, g), "pre": H(rc - CAMP_R - 5.0, g), "post": H(rc + CAMP_R + 2.0, g), "in": polar(z, g, 16), "out": polar(z, g, 8)}
        z.portal("to_fort_" + side, fr[side]["out"], "fort_" + side, zone_lib.fort_arrive("fort_" + side, FORT_ARRIVE), f["label"])
        print("BACK", side, fr[side]["in"], "centro", fr[side]["c"], "rim %.1f" % rim)
    pass_in, pass_out = kharzun_pass(z)

    # ---------- estradas (todas curvas; laços entre POIs, sem beco) ----------
    t, w, fi = fr["trolls"], fr["war"], fr["fire"]
    r_oeste = z.road("oeste", [(-HUB_R + 1.0, 0.0), (-33.0, -4.0), (-39.0, -4.0), (-51.0, -5.0), (-56.0, 4.0), t["pre"], t["c"], t["post"], t["in"], t["out"]], end_clearing=False)
    r_leste = z.road("leste", [(HUB_R - 1.0, 0.0), (26.0, -2.0), (31.0, -3.0)], end_clearing=False)
    r_guerra = z.road("guerra", [(31.0, -3.0), (40.0, -10.0), (47.0, -20.0), w["pre"], w["c"], w["post"], w["in"], w["out"]], end_clearing=False)
    r_fogo = z.road("fogo", [(31.0, -3.0), (41.0, 5.0), (47.0, 19.0), fi["pre"], fi["c"], fi["post"], fi["in"], fi["out"]], end_clearing=False)
    z.road("sul", [(0.0, HUB_R - 1.0), (3.0, 40.0), (6.0, 62.0), (-6.0, 84.0), arrive, portal], end_clearing=False)
    z.road("norte", [(0.0, -HUB_R + 1.0), (4.0, -40.0), (-6.0, -62.0), (2.0, -84.0), pass_in], end_clearing=False)
    z.road("mamutes", [(-56.0, 4.0), (-65.0, 20.0), (-71.0, 38.0), (-69.0, 54.0), (-60.0, 64.0)], end_clearing=False)
    z.road("sul_oeste", [(3.0, 40.0), (-14.0, 54.0), (-30.0, 62.0), (-46.0, 66.0), (-60.0, 64.0)], end_clearing=False)
    z.road("sudeste", [(6.0, 62.0), (30.0, 64.0), (43.0, 55.0), fi["pre"]], end_clearing=False)
    z.road("desertores", [(-6.0, -62.0), (-18.0, -70.0), (-30.0, -68.0), (-36.0, -54.0), (-30.0, -34.0), (-29.0, -14.0), (-33.0, -4.0)], end_clearing=False)
    z.road("totem", [(4.0, -40.0), (16.0, -47.0), (30.0, -43.0), (41.0, -30.0), (47.0, -20.0)], end_clearing=False)
    z.river(RIVER, w=8.0)
    z.bridges()

    # ---------- investidas (três lados, cada uma calada pela quest do acampamento) e reforços dos postos retomados ----------
    routes = {"trolls": route_of(r_oeste), "war": route_of(r_guerra, r_leste), "fire": route_of(r_fogo, r_leste)}
    raids = []
    for side in ("trolls", "war", "fire"):
        rt = [p for p in routes[side] if math.hypot(p[0], p[1]) < math.hypot(*fr[side]["c"]) - CAMP_R - 2.0 and math.hypot(p[0], p[1]) > HUB_R + 2.0]
        gate = H(HUB_R, {"trolls": 180.0, "war": 0.0, "fire": 0.0}[side])
        raids.append({"side": side, "from": list(fr[side]["pre"]), "route": rt + [list(gate)], "target": [0.0, 0.0], "radius": HUB_R - 6.0,
                      "unless": FORT_Q[side]})
    z.data["raids"] = raids
    z.data["assaults"] = [{"id": "reforco_" + r["side"], "from": r["from"], "route": r["route"], "target": list(H(8.0, {"trolls": 180.0, "war": -20.0, "fire": 20.0}[r["side"]])),
                           "radius": 5.0} for r in raids]

    # ---------- acampamentos de guerra, cemitério, desertores, marco ----------
    for side, f in FRONTS.items():
        war_camp(z, side, f, fr[side]["c"])
    mammoth_graveyard(z)
    deserters_camp(z)
    top = broken_totem(z)
    print("totem topo %.1f m" % top)

    # ---------- relevo: mesas de rocha, afloramentos e ravinas (borda e campo) ----------
    for i, (c, r, lv) in enumerate([((-99.0, -40.0), 9.0, 3), ((70.0, -96.0), 8.0, 3), ((100.0, 76.0), 8.0, 2), ((-8.0, 104.0), 6.0, 2),
                                     ((-98.0, 88.0), 8.0, 3), ((-66.0, -98.0), 8.0, 2), ((106.0, -36.0), 7.0, 2)]):
        z.hill("mesa_%d" % i, c, r, lv, rock="cliff_rock", top="hill_grass", step=2.2)
    for i, (c, r, lv) in enumerate([((24.0, 26.0), 5.0, 1), ((-20.0, 30.0), 5.5, 1), ((62.0, 4.0), 5.5, 2), ((-14.0, -34.0), 5.0, 1), ((-74.0, -26.0), 6.0, 2)]):
        z.terrace("afloramento_%d" % i, c, r, lv, top="cliff_grass")
    horde.ravine(z, "norte", [polar(z, -122.0, 2), (-44.0, -98.0), (-22.0, -100.0), (-14.0, -94.0)], 5.0)
    horde.ravine(z, "leste", [polar(z, 4.0, 2), (104.0, 14.0), (98.0, 26.0), (104.0, 40.0)], 5.0)
    horde.ravine(z, "sul", [polar(z, 58.0, 2), (58.0, 86.0), (64.0, 76.0), (60.0, 68.0)], 4.5)
    for i, (c, r) in enumerate([((-34.0, 18.0), 8.0), ((30.0, -22.0), 8.0), ((20.0, 42.0), 10.0), ((-16.0, 80.0), 11.0), ((70.0, -70.0), 10.0), ((-58.0, -20.0), 8.0),
                                 ((84.0, 28.0), 9.0), ((-12.0, -80.0), 9.0), ((-98.0, 22.0), 9.0), ((52.0, 100.0), 8.0)]):
        z.patch("cinza_%d" % i, c, r, [(0.62, 0.59, 0.54), (0.54, 0.51, 0.46)][i % 2])

    z.cliffs(snow=False)
    places.build(z, PLACES)

    # ---------- vegetação de estepe: poucas árvores secas, moitas douradas, pedras, capim alto na beira do rio ----------
    obs = z.data["obstacles"]
    z.scatter("tree", [((0, 0), 108, 34), ((-70, -30), 26, 8), ((60, 30), 24, 6)], 0, (1.8, 4.0, 1.8), DRY, margin=4.8, spacing=7.0, hub_r=HUB_R + 8.0)
    z.rim_belt(60, (1.8, 4.0, 1.8), DRY)
    z.scatter("rock", [((0, 0), 108, 60), ((-90, 0), 26, 12), ((36, -76), 20, 8)], 0, (1.5, 1.0, 1.3), [(0.58, 0.5, 0.44), (0.5, 0.46, 0.42)],
              margin=3.6, spacing=3.2, hub_r=HUB_R + 7.0, scale=(0.7, 1.8))
    nrnd = random.Random(71)
    free = lambda x, zz, m: z.free(x, zz, m, HUB_R + 5.0)
    nature.fix_trees(obs, nrnd, dead=True, dead_cols=DRY)
    nature.scatter(z.ob, free, nrnd, "tree", [((-52, -30), 12, 4), ((-46, 22), 12, 5), ((-42, 74), 12, 4)], (2.2, 4.2, 2.2),
                   [(0.5, 0.56, 0.3), (0.56, 0.58, 0.32)], margin=5.0, spacing=5.0, rotate=False, avoid=obs)        # salgueiros ralos no rio
    nature.scatter(z.ob, free, nrnd, "bush", [((0, 0), 106, 110)], (1.6, 0.85, 1.6), [(0.7, 0.6, 0.32), (0.62, 0.54, 0.3), (0.74, 0.66, 0.38)],
                   solid=False, margin=2.6, spacing=3.2, avoid=obs)
    nature.scatter(z.ob, free, nrnd, "reeds", [((0, 0), 106, 90)], (1.4, 1.2, 1.4), [(0.76, 0.66, 0.36), (0.68, 0.58, 0.32)],
                   solid=False, margin=2.2, spacing=3.0, avoid=obs)
    nature.clear_banks(obs, z.rivers, [], z.river_w)
    nature.shore(z.ob, nrnd, z.rivers, [], list(z.road_polys.values()), z.river_w, colors=[(0.62, 0.62, 0.36), (0.56, 0.58, 0.34)], keep=0.7)

    # ---------- monstros (ids do contrato; MapsCatalog.STAND_INS troca os que ainda não existem) ----------
    bt, bw, bf = {"unless": FORT_Q["trolls"]}, {"unless": FORT_Q["war"]}, {"unless": FORT_Q["fire"]}
    tc, wc, fc = t["c"], w["c"], fi["c"]
    z.spawner("troll_whelp", tc[0], tc[1], 8, 4, 20.0, when=bt)              # dentro do anel de cada acampamento
    z.spawner("orc_warrior", wc[0], wc[1], 8, 4, 20.0, when=bw)
    z.spawner("orc_archer", fc[0], fc[1], 8, 4, 20.0, when=bf)
    z.spawner("troll_whelp", -66.0, -18.0, 8, 4, 20.0, when=bt)              # margem oeste: terra dos trolls
    z.spawner("troll", -92.0, -22.0, 7, 2, 28.0, when=bt)
    z.spawner("troll", -96.0, 22.0, 7, 2, 28.0, when=bt)
    z.spawner("orc_warrior", 82.0, -20.0, 8, 4, 20.0, when=bw)               # nordeste: a tropa de Ghar
    z.spawner("orc_warrior", 60.0, -62.0, 8, 3, 22.0, when=bw)
    z.spawner("goblin_agitator", 74.0, -58.0, 3, 1, 90.0, when=bw)
    z.spawner("orc_archer", 74.0, 22.0, 8, 4, 20.0, when=bf)                 # sudeste: os arqueiros
    z.spawner("orc_crossbow", 78.0, 70.0, 7, 3, 24.0, when=bf)
    z.spawner("orc_archer", 32.0, 46.0, 7, 3, 20.0, when=bf)
    z.spawner("troll_whelp", GRAVEYARD[0] + 4.0, GRAVEYARD[1] + 2.0, 12, 5, 20.0)   # sempre: cemitério, estrada sul, passo do norte
    z.spawner("troll", -74.0, 74.0, 6, 2, 28.0)
    z.spawner("wolf_raider", -14.0, 70.0, 7, 2, 30.0)
    z.spawner("goblin_agitator", -22.0, 44.0, 3, 1, 90.0)
    z.spawner("wolf_raider", 22.0, -92.0, 7, 2, 30.0)
    z.spawner("orc_crossbow", -16.0, -50.0, 7, 3, 24.0)
    z.spawner("orc_warrior", pass_in[0], pass_in[1] + 8.0, 6, 3, 22.0)
    z.spawner("orc_archer", 52.0, -2.0, 6, 3, 20.0)
    act2_dress.steppe(z, HUB_R, HUB_GATES, {s: {"c": fr[s]["c"], "deg": FRONTS[s]["deg"]} for s in FRONTS}, CAMP_R, GRAVEYARD, DESERTERS, TOTEM, SHRINE, FORT_Q)
    poi = {"trolls": tc, "war": wc, "fire": fc, "mamutes": GRAVEYARD, "desertores": DESERTERS, "totem": (TOTEM[0] - 6.0, TOTEM[1] + 8.0),
           "passo": (pass_in[0], pass_in[1] + 6.0)}[os.environ.get("STEPPE_POI", "war")]
    return z.finish(export, poi=poi, ground=(0.76, 0.64, 0.36))
