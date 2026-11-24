"""Floresta Sombria (field_forest, Lv 10-20): vale de mata fechada, Posto dos Caçadores no hub (povoado humano murado
sob cerco élfico: quartel, forja, mercado, sentinelas nas torres), garganta norte para a Cidade Élfica (rota das investidas),
ninhos de aranha (NW/SW), acampamento dos bandidos murado (NE, chefe no centro), bosque dos ents (SE), rio com
pontes, pântano e a Árvore-Mãe (landmark) ao norte. Portal de volta a Aldara na garganta oeste.

    import sys; sys.path += [r"C:/Users/luisf/Desktop/projects/ragnaex/tools/blender/zones"]
    import build_field_forest as z; z.build(export=True)
"""
import math
import random
import importlib
import nature
import places
import town_dress
import zone_lib
importlib.reload(zone_lib)
from zone_lib import Zone, ROAD_W

ZONE = "field_forest"
HUB = (-5.0, 0.0)          # povoado um pouco a oeste: o rio passa a ~30 m a leste
CAMP_R = 24.0
ELF_ANG = -93.0            # garganta norte (Cidade Élfica), entre o Círculo Druídico e a Árvore-Mãe
BANDITS = (68.0, -60.0)
BANDIT_R = 14.0
TREE_COLS = [(0.22, 0.4, 0.27), (0.27, 0.47, 0.3), (0.32, 0.52, 0.32)]
# Garganta leste (Bosque dos Xamãs, 2026-11-18), aberta DEPOIS da zona aprovada: portal, trilha e largo entram no fim do
# build (LATE_*, como em build_city_aldara) e o anel usa `late_gorges`; o resto do JSON sai byte a byte igual, fora a
# decoração tirada do caminho (lista no log: "garganta leste").
GROVE_ANG = 7.0
GROVE_ARRIVE_IN = (-85.2, -6.0)     # chegada no Bosque (build_field_grove: polar(184, 15))
LATE_TRAIL = [(42.0, -6.0), (55.0, -3.0), (67.0, 2.5), (78.0, 8.0)]      # sai da estrada leste, depois da ponte
LATE_W = 3.0                        # trilha estreita, como as do Bosque
LATE_DECOR = ("tree", "pine", "dead_tree", "rock", "bush", "flowers", "log", "stump", "reed")
# Garganta sul (Brejo das Teias, 2026-11-24), também aberta depois (mesmo padrão): sai do arco sul, entre o pântano e o rio.
MARSH_ANG = 100.0
MARSH_ARRIVE_IN = (-7.4, -84.7)     # chegada no Brejo (build_field_marsh: polar(-95, 15))
LATE_TRAIL_S = [(-4.0, 80.0), (-8.0, 88.0), (-13.0, 96.0)]
# Cerco Vivo do Posto (GDD elf-siege-posto; SIEGE["field_forest"]): uma rota por lado, pontos conferidos contra os colisores
# (>= 1,8 m de folga em todo trecho; _check_elf_siege AC-4). Os flancos acabam nos portões oeste (-29, 0) e leste (19, 0);
# nenhum `from` a menos de 20 m da chegada do portal élfico. `unless` = quest que cala o lado ("a|b" = qualquer uma).
Q_KING = "el6_king"
NORTH_ROUTE = [(2.0, -66.0), (-8.0, -46.0), (2.0, -34.0), (-5.0, -27.0), (-5.0, -20.0)]
RAIDS = [
    ("muralha_norte", (8.0, -80.0), NORTH_ROUTE, (-5.0, -14.0), Q_KING),
    ("flanco_oeste", (-30.0, -80.0), [(-40.0, -72.0), (-48.0, -58.0), (-41.0, -55.0), (-22.0, -54.0), (-12.0, -43.0), (-12.0, -40.0),
                                      (-34.0, -8.0), (-34.0, -2.0), (-30.0, 0.0)], (-17.0, -1.0), "els_steel|" + Q_KING),
    ("flanco_leste", (26.0, -82.0), [(5.0, -74.0), (-4.0, -48.0), (4.0, -39.0), (12.0, -40.0), (13.0, -28.0), (24.0, -4.0), (23.0, 0.0)],
     (8.0, 0.0), "els_lynx|" + Q_KING),
    ("patrulha_norte", (8.0, -80.0), NORTH_ROUTE, (-5.0, -14.0), Q_KING),
    ("assedio_crista", (12.0, -40.0), [], (-5.0, -14.0), Q_KING),          # kind harass no catálogo: arqueiros na crista
]
RAID_R = 12.0
# Chamas (leva que chegou e não foi repelida; só visual, game/world/siege_fx.gd): na fachada do quartel, da forja e do alojamento
# (raio, ângulo a partir do centro do Posto: 0,3 m antes da parede virada para a praça), e a fumaça no horizonte da garganta élfica.
FIRE_SPOTS = [(12.2, -45.0), (13.0, -135.0), (14.2, -160.0)]
SMOKE_POS = (-5.0, -105.0)
# Pontos de evento de estrada ("Emboscada dos Salteadores", GDD elf-band-living 3.3): (tipo, (x, z), monstro) na estrada de
# Aldara, na estrada sul e no arco norte; viram data["events"] (-> MapDef.road_events), regras em MapsCatalog.ROAD_EVENTS.
EVENT_POINTS = [
    ("ambush", (-79.2, 9.9), "bandit"),
    ("ambush", (27.5, 58.2), "bandit"),
    ("ambush", (24.4, -81.9), "bandit"),
]
PLACES = [
    {"type": "cabin", "id": "herborista", "pos": (-44.0, 30.0), "face": 60.0, "npc": "herbalist_maren", "roof": (0.36, 0.46, 0.32)},
    {"type": "cabin", "id": "cacador", "pos": (70.0, -16.0), "face": 170.0, "npc": "hunter_dario", "roof": (0.46, 0.32, 0.24)},
    {"type": "camp", "id": "emboscada", "pos": (46.0, 94.0), "face": 215.0, "mob": "bandit_footpad", "count": 4},
    {"type": "shrine", "id": "circulo", "pos": (-28.0, -100.0), "npc": "stone_druid", "ground": (0.56, 0.56, 0.56)},
    {"type": "dungeon", "id": "ninho", "dungeon": "dg_ninho"},
    {"type": "dungeon", "id": "pedreira", "dungeon": "dg_pedreira"},
]


def polar(z, ang_deg, inset):
    a = math.radians(ang_deg)
    r = z.rim_r(a) - inset
    return (round(math.cos(a) * r, 1), round(math.sin(a) * r, 1))


def clear_late(obs, poly, spots, w):
    """Tira a decoração que ficou no caminho de uma garganta aberta depois (trilha `poly` de largura `w` e largos `spots`)."""
    def in_the_way(o):
        if o["kind"] not in LATE_DECOR or not o["visible"] or o.get("y"):
            return False
        p = zone_lib.Vector(o["pos"])
        half = (o["size"][0] + o["size"][2]) * 0.25
        pad = 1.6 if o.get("solid", True) else 0.4
        return zone_lib.poly_dist(p, poly) < w * 0.5 + pad + half or any((p - c).length < r + half for c, r in spots)
    gone = [o for o in obs if in_the_way(o)]
    obs[:] = [o for o in obs if not in_the_way(o)]
    return gone


def event_points(z):
    """data["events"] nos pontos pedidos; EVENT_CONFLICT se um deles quebrar as regras do _check_event_points."""
    data = z.data
    data["events"] = []
    hub = zone_lib.Vector(HUB)
    for kind, pos, mob in EVENT_POINTS:
        q = zone_lib.Vector(pos)
        far = lambda c, r: (q - zone_lib.Vector(c[:2])).length >= r
        arrivals = [data["spawn"]] + [v for k, v in data.items() if k.startswith("arrive_from_")]
        why = ""
        if (q - hub).length < 40.0:
            why = "hub"
        elif not all(far(p["pos"], 25.0) for p in data["portals"]) or not all(far(a, 25.0) for a in arrivals):
            why = "portal/chegada"
        elif not all(far(v, 25.0) for v in data["npcs"].values()):
            why = "npc"
        elif not all(far(o["pos"], max(o["size"][0], o["size"][2]) * 0.5 + 0.6) for o in data["obstacles"] if o.get("solid", True) and o["kind"] != "cliff"):
            why = "obstaculo"
        elif not all(far(e["pos"], 30.0) for e in data["events"]):
            why = "outro ponto"
        if why:
            print("EVENT_CONFLICT %s em %s: %s" % (kind, pos, why))
        data["events"].append({"kind": kind, "pos": [round(q.x, 2), round(q.y, 2)], "mob": mob})


def build(export=False):
    z = Zone(ZONE, seed=3, palette={
        "leaf": (0.2, 0.38, 0.26), "cliff_grass": (0.26, 0.42, 0.28), "hill_grass": (0.3, 0.46, 0.3),
        "cliff_rock": (0.38, 0.37, 0.36), "road": (0.55, 0.46, 0.34), "water": (0.3, 0.52, 0.6), "water_dark": (0.24, 0.34, 0.3),
    })
    portal = polar(z, 175, 7)
    arrive = polar(z, 175, 15)
    z.data["spawn"] = list(arrive)
    z.portal("to_town", portal, "city_aldara", places.grow_aldara((98.3, -32.1)), "Vale de Aldara")

    elf_portal = polar(z, ELF_ANG, 7)
    elf_arrive = polar(z, ELF_ANG, 15)
    z.portal("to_elf_city", elf_portal, "elf_city", (0.0, 99.5), "Cidade Élfica")
    z.block(elf_arrive, 6)
    ea = math.radians(ELF_ANG)
    for sgn in (-1, 1):                     # marco élfico na garganta: colunas claras e lanternas verdes
        for k, r_in in enumerate((9.0, 13.0)):
            pr = z.rim_r(ea) - r_in
            px, pz = math.cos(ea) * pr - math.sin(ea) * 4.2 * sgn, math.sin(ea) * pr + math.cos(ea) * 4.2 * sgn
            z.ob("pillar", px, pz, (0.8, 4.2 - k * 0.8, 0.8), color=(0.86, 0.9, 0.8))
            z.ob("lamp", px - math.sin(ea) * 1.2 * sgn, pz + math.cos(ea) * 1.2 * sgn, (0.4, 3.0, 0.4), color=(0.55, 0.95, 0.6))

    # ---------- hub: Posto dos Caçadores (povoado murado) ----------
    hx, hz = HUB
    H = lambda r, a: (hx + math.cos(math.radians(a)) * r, hz + math.sin(math.radians(a)) * r)
    gate_deg = [180.0, 0.0, -90.0, 90.0]                # O, L, N (elfos), S
    gates = [math.radians(a) for a in gate_deg]
    z.patch("clareira", HUB, CAMP_R + 10, (0.5, 0.62, 0.38), grass=True)
    # chão de terra batida do povoado entre a clareira (0.006) e as ruas (0.012): sem z-fighting
    zone_lib.disc(z.coll, z.P + "chao_posto", HUB, CAMP_R - 1.0, 0.009, z.M["street"], 48, 0.03, 5)
    z.data["roads"].append({"kind": "street", "w": 0, "pts": [[HUB[0], HUB[1]]], "r": CAMP_R - 1.0})
    z.plaza("praca", HUB, 7.5, "road")
    z.ring_wall("posto", HUB, CAMP_R, gates, gate_half=3.2, height=3.4, stakes=True, towers=8)
    z.data["town"] = {"center": [hx, hz], "radius": CAMP_R, "gates": [[round(H(CAMP_R, a)[0], 2), round(H(CAMP_R, a)[1], 2)] for a in gate_deg]}
    for a in gate_deg:                                   # ruas radiais praça -> portão
        z.road("rua_%d" % int(a), [H(7.0, a), H(CAMP_R - 2.0, a)], w=3.4, material="road", end_clearing=False)
    # centro = Fogueira Comunal + roda de carroças dos refugiados + varais de peles + Trompa do Cerco (GDD living-towns 3.2;
    # o poço e a estátua genérica saíram). Colisores ocultos pelo z.ob; resumo em town.centerpiece (check _check_town_identity)
    z.data["town"]["centerpiece"] = town_dress.posto(z, HUB)
    # quadrantes entre as ruas: NE quartel, NO forja + alojamento dos caçadores, SE mercado, SO casas
    roof_q = (0.42, 0.34, 0.5)
    z.ob("house", *H(15.5, -45.0), (8.5, 5.0, 6.0), 45.0, roof=roof_q)          # quartel
    for i, a in enumerate((-30.0, -60.0)):
        z.ob("pillar", *H(10.0, a), (0.5, 1.8, 0.5))                          # bonecos de treino
    z.ob("house", *H(16.0, -135.0), (6.5, 4.4, 5.5), 135.0, roof=(0.5, 0.3, 0.24))   # forja
    z.ob("anvil", *H(10.5, -120.0), (1.0, 0.9, 0.6), 30.0)
    z.ob("barrel", *H(10.5, -150.0), (0.8, 1.0, 0.8))
    z.ob("house", *H(17.0, -160.0), (5.5, 4.2, 5.0), 160.0, roof=(0.36, 0.46, 0.32))  # alojamento dos caçadores
    for i, a in enumerate((25.0, 45.0, 65.0)):
        z.ob("stall", *H(12.5, a), (3.0, 2.4, 2.0), a + 90.0, color=[(0.75, 0.4, 0.3), (0.35, 0.55, 0.7), (0.8, 0.7, 0.35)][i])
    z.ob("house", *H(18.0, 45.0), (6.0, 4.2, 5.0), 45.0, roof=(0.6, 0.32, 0.28))     # armazém do mercador
    for i, a in enumerate((115.0, 140.0, 165.0)):
        z.ob("house", *H(17.0, a), (5.0, 4.0, 4.6), a, roof=[(0.62, 0.32, 0.3), (0.5, 0.42, 0.3), (0.55, 0.36, 0.42)][i])
    for a in (130.0, 152.0):
        z.ob("crate", *H(11.0, a), (1.0, 1.0, 1.0), a)
    for a in gate_deg:
        for sgn in (-1, 1):
            g = math.radians(a)
            px, pz = H(CAMP_R - 2.0, a)
            z.ob("lamp", px - math.sin(g) * 3.2 * sgn, pz + math.cos(g) * 3.2 * sgn, (0.4, 3.0, 0.4))
    # NPCs de serviço e sentinelas (nomes/papéis em MapsCatalog.FOREST_NPCS)
    z.npc("ranger_post", *H(5.5, 120.0), -60.0)
    z.npc("forest_commander", *H(8.0, -60.0), 120.0)
    z.npc("forest_smith", *H(9.0, -140.0), 40.0)
    z.npc("forest_merchant", *H(8.5, 45.0), -135.0)
    z.npc("forest_alchemist", *H(6.5, 160.0), -20.0)
    for i, a in enumerate((-90.0, 180.0, 0.0, 90.0)):                    # soldados nos portões (quatro no norte, de onde vêm os elfos)
        g = math.radians(a)
        offs = (-3.3, -1.1, 1.1, 3.3) if a == -90.0 else (-2.0, 2.0)
        for k, off in enumerate(offs):
            px, pz = H(CAMP_R - 4.0, a)
            z.npc("guard_w_%d_%d" % (i, k), px - math.sin(g) * off, pz + math.cos(g) * off, (a + 180.0) % 360.0 - 180.0)
    for i, a in enumerate((-135.0, -45.0, 45.0, 135.0, -112.0, -68.0, 22.0, 158.0)):   # caçadoras no muro (o lado norte em dobro)
        z.npc("guard_a_%d" % i, *H(CAMP_R - 3.0, a), a)
    z.data["hangouts"] = [list(H(r, a)) for r, a in ((3.5, 0), (4.0, 90), (4.0, 200), (5.0, 280), (12.0, 0), (12.0, 95), (12.0, 185), (12.0, -90))]

    # ---------- estradas ----------
    z.road("W", [(HUB[0] - CAMP_R, 0), (-38, 7), (-54, -3), (-70, 9), arrive, portal], end_clearing=False)
    z.road("N", [(HUB[0], -CAMP_R), (2, -34), (-8, -46), (-30, -56), (-50, -54)])
    gate_dir = math.atan2(-26 - BANDITS[1], 44 - BANDITS[0])
    gate_out = (BANDITS[0] + math.cos(gate_dir) * (BANDIT_R + 3), BANDITS[1] + math.sin(gate_dir) * (BANDIT_R + 3))
    z.road("E", [(HUB[0] + CAMP_R, 0), (32, -2), (42, -6), (48, -22), gate_out,       # cruza o rio de frente (>= 60 graus)
            (BANDITS[0] + math.cos(gate_dir) * (BANDIT_R - 4), BANDITS[1] + math.sin(gate_dir) * (BANDIT_R - 4))])
    z.road("S", [(HUB[0], CAMP_R), (-6, 36), (6, 50), (26, 58), (50, 58)])
    z.road("SW", [(-6, 36), (-24, 46), (-42, 58)])
    z.road("arvore", [(-8, -46), (2, -66), (8, -80)])
    # rota das investidas: garganta élfica -> junção da Árvore-Mãe -> estrada norte -> portão norte
    z.road("elfos", [elf_portal, elf_arrive, (-4, -92), (8, -80)], end_clearing=False)
    # Cerco Vivo: uma rota por lado (o `raid` antigo nascia na chegada do portal élfico e saiu). Sem peças de paliçada:
    # os trechos são os portões oeste e leste. Quem solta as levas é o SiegeSystem (relógio do mapa).
    z.data["raids"] = [{"side": side, "from": list(src), "route": [list(p) for p in pts], "target": list(tgt), "radius": RAID_R, "unless": unless}
                       for side, src, pts, tgt, unless in RAIDS]
    z.data["fx"] = [{"kind": "fire", "pos": [round(v, 2) for v in H(r, a)]} for r, a in FIRE_SPOTS]
    z.data["fx"].append({"kind": "smoke", "pos": list(SMOKE_POS), "unless": Q_KING})
    # arcos entre POIs (sem becos): norte = aranhas → Árvore-Mãe → bandidos; sul = ents → pântano → aranhas SO
    gate2 = math.atan2(-80 - BANDITS[1], 44 - BANDITS[0])
    g2_out = (BANDITS[0] + math.cos(gate2) * (BANDIT_R + 3), BANDITS[1] + math.sin(gate2) * (BANDIT_R + 3))
    g2_in = (BANDITS[0] + math.cos(gate2) * (BANDIT_R - 4), BANDITS[1] + math.sin(gate2) * (BANDIT_R - 4))
    z.road("arco_aranhas", [(-50, -54), (-40, -74), (-20, -84), (8, -80)], end_clearing=False)
    z.road("arco_norte", [(8, -80), (26, -82), (44, -82), g2_out, g2_in])
    z.road("arco_sul", [(50, 58), (36, 76), (16, 82), (-4, 80), (-14, 72), (-30, 66), (-42, 60)])

    # ---------- água ----------
    z.river([(42, -128), (34, -84), (26, -40), (32, -6), (30, 30), (16, 66), (4, 124)], w=6.5)
    z.lake("pantano", (-30, 84), 10.0, "water_dark")
    z.bridges()

    # ---------- acampamento dos bandidos (NE) ----------
    z.plaza("bandidos", BANDITS, BANDIT_R - 1.0, "road")
    z.ring_wall("bandidos", BANDITS, BANDIT_R, [gate_dir, gate2], gate_half=3.2, height=3.4, stakes=True, towers=5)
    for i in range(4):
        a = gate_dir + math.pi + (i - 1.5) * 0.7
        z.ob("tent", BANDITS[0] + math.cos(a) * 8.5, BANDITS[1] + math.sin(a) * 8.5, (3.2, 2.3, 3.2), math.degrees(-a), color=(0.6, 0.32, 0.28))
    for i in range(5):
        a = gate_dir - 1.2 - i * 0.25          # longe dos dois portões
        z.ob("crate", BANDITS[0] + math.cos(a) * 10.5, BANDITS[1] + math.sin(a) * 10.5, (1.0, 1.0, 1.0))

    # ---------- relevo e landmark ----------
    z.giant_tree("arvore_mae", (14, -94), trunk_r=3.4, height=24.0)
    z.hill("rochedo_ne", (96, -10), 9, 3)
    z.hill("rochedo_sw", (-82, 40), 8, 2)
    z.hill("rochedo_nw", (-76, -86), 10, 3)
    z.hill("rochedo_se", (86, 82), 8, 2)
    # afloramentos baixos de rocha pela mata (relevo visto de cima)
    for i, (c, r, lv) in enumerate([((-32, -36), 6, 2), ((52, 10), 7, 2), ((-70, -20), 7, 2), ((88, -30), 6, 1), ((-60, 30), 6, 1)]):
        z.terrace("afloramento_%d" % i, c, r, lv, top="cliff_grass")

    grove_portal = polar(z, GROVE_ANG, 7)
    grove_arrive = polar(z, GROVE_ANG, 15)
    z.late_gorges.append(math.atan2(grove_portal[1], grove_portal[0]))
    marsh_portal = polar(z, MARSH_ANG, 7)
    marsh_arrive = polar(z, MARSH_ANG, 15)
    z.late_gorges.append(math.atan2(marsh_portal[1], marsh_portal[0]))
    z.cliffs()

    places.build(z, PLACES)

    # ---------- vegetação ----------
    z.block(HUB, CAMP_R + 10)
    z.block(BANDITS, BANDIT_R + 3)
    z.scatter("tree", [((-58, -54), 26, 70), ((-46, 62), 20, 40), ((66, 56), 26, 55), ((20, -70), 28, 50),
                       ((-80, -20), 24, 40), ((90, -50), 20, 30), ((-10, 100), 22, 35), ((60, 100), 16, 18), ((-100, 90), 14, 14)],
              0, (1.6, 3.6, 1.6), TREE_COLS, margin=4.2, spacing=3.4, scale=(1.0, 1.6))
    z.scatter("tree", [((0, 0), 110, 240)], 0, (1.6, 3.6, 1.6), TREE_COLS, margin=4.6, spacing=4.0, hub_r=CAMP_R + 12, scale=(0.9, 1.4))
    z.rim_belt(170, (1.6, 3.6, 1.6), TREE_COLS[:2])
    z.scatter("rock", [((-58, -54), 26, 10), ((66, 56), 20, 8), ((0, 0), 100, 25)], 0, (1.4, 0.9, 1.2), [(0.5, 0.5, 0.48)],
              margin=3.5, spacing=2.5, hub_r=CAMP_R + 10, scale=(0.8, 1.6))

    # ---------- natureza (passe 3): pinheiros na mata, sub-bosque, troncos/tocos, flores frias, juncos ----------
    nrnd = random.Random(41)
    obs = z.data["obstacles"]
    fr = lambda x, zz, m: z.free(x, zz, m, CAMP_R + 12)
    nature.fix_trees(obs, nrnd, pine_frac=0.3)
    nature.scatter(z.ob, fr, nrnd, "bush", [((0, 0), 110, 120)], (1.7, 0.95, 1.7), [(0.24, 0.42, 0.27), (0.3, 0.5, 0.3)],
                   solid=False, margin=2.6, spacing=2.6, avoid=obs)
    nature.scatter(z.ob, fr, nrnd, "flowers", [((0, 0), 105, 26)], (1.6, 0.45, 1.6), [(0.6, 0.7, 0.98), (0.95, 0.95, 0.9), (0.75, 0.55, 0.95)],
                   solid=False, margin=2.6, spacing=4.0, avoid=obs)
    nature.woodland_floor(z.ob, fr, nrnd, [((-58, -54), 26, 10), ((66, 56), 26, 10), ((20, -70), 28, 8), ((-80, -20), 24, 8),
                                           ((0, 0), 100, 20)], avoid=obs)
    nature.clear_banks(obs, z.rivers, [((-30, 84), 10.0)], z.river_w)
    nature.shore(z.ob, nrnd, z.rivers, [((-30, 84), 10.0)], list(z.road_polys.values()), z.river_w)

    # ---------- monstros ----------
    z.spawner("spider", -60, -50, 10, 6, 14.0)
    z.spawner("spider", -42, -68, 9, 5, 14.0)
    z.spawner("spider", -46, 64, 10, 6, 14.0)
    # bandidos (linha dos fora-da-lei): trombadinhas e gatunos na trilha, o bando pesado na paliçada, clandestinos de tocaia
    z.spawner("bandit_footpad", 50, -36, 8, 3, 16.0)
    z.spawner("bandit_thief", 54, -30, 6, 2, 18.0)
    z.spawner("bandit", BANDITS[0] - 2, BANDITS[1] + 2, 6, 4, 18.0)
    z.spawner("bandit_archer", BANDITS[0] + 4, BANDITS[1] - 5, 5, 3, 20.0)
    z.spawner("bandit_thief", BANDITS[0] - 6, BANDITS[1] - 6, 4, 2, 20.0)
    z.spawner("bandit_archer", 40, 98, 6, 2, 20.0)                     # tocaia junto da emboscada
    for route in ([(14, -81), (26, -82), (44, -82), (26, -82)], [(50, 58), (40, 72), (26, 80), (40, 72)]):
        z.spawner("bandit_outlaw", route[0][0], route[0][1], 2, 1, 60.0, route=route)   # fora-da-lei com 2 trombadinhas faz ronda
    z.spawner("bandit_chief", BANDITS[0] + 3, BANDITS[1] - 2, 2, 1, 180.0)
    z.spawner("ent", 66, 54, 10, 4, 24.0)
    z.spawner("ent", 82, 36, 8, 3, 24.0)
    # mais vida na mata (11-15): aranhas no arco norte e no sudoeste, ents e trents jovens no bosque SE
    z.spawner("spider", -24, -72, 9, 5, 14.0)
    z.spawner("spider", -66, 46, 8, 5, 14.0)
    z.spawner("ent", 52, 74, 9, 4, 24.0)
    z.spawner("ent", 94, 56, 7, 3, 24.0)
    z.spawner("trent_young", 60, 30, 8, 4, 20.0)
    z.spawner("trent_young", 76, 72, 8, 4, 20.0)
    z.data["arrive_from_town"] = list(arrive)

    # ---------- garganta leste: Bosque dos Xamãs (entra por último: nada acima muda) ----------
    z.portal("to_field_grove", grove_portal, "field_grove", GROVE_ARRIVE_IN, "Bosque dos Xamãs (Lv 14-18)")
    late_poly = z.road("leste", LATE_TRAIL + [grove_arrive, grove_portal], w=LATE_W, end_clearing=False)
    z.arrival(grove_arrive, toward=grove_portal, r=6.0, name="chegada_leste")
    spots = [(zone_lib.Vector(grove_arrive), 7.0), (zone_lib.Vector(grove_portal), 7.0)]
    gone = clear_late(obs, late_poly, spots, LATE_W)
    z.data["arrive_from_field_grove"] = list(grove_arrive)
    print("garganta leste: portal %s chegada %s; %d objetos tirados do caminho: %s"
          % (grove_portal, grove_arrive, len(gone), [(o["kind"], o["pos"]) for o in gone]))

    # ---------- garganta sul: Brejo das Teias (por último, mesmo padrão: nada acima muda) ----------
    z.portal("to_field_marsh", marsh_portal, "field_marsh", MARSH_ARRIVE_IN, "Brejo das Teias (Lv 12-16)")
    south_poly = z.road("sul", LATE_TRAIL_S + [marsh_arrive, marsh_portal], w=LATE_W, end_clearing=False)
    z.arrival(marsh_arrive, toward=marsh_portal, r=6.0, name="chegada_sul")
    spots = [(zone_lib.Vector(marsh_arrive), 7.0), (zone_lib.Vector(marsh_portal), 7.0)]
    gone = clear_late(obs, south_poly, spots, LATE_W)
    z.data["arrive_from_field_marsh"] = list(marsh_arrive)
    print("garganta sul: portal %s chegada %s; %d objetos tirados do caminho: %s"
          % (marsh_portal, marsh_arrive, len(gone), [(o["kind"], o["pos"]) for o in gone]))
    for o in obs:                    # o que sobrou de sólido perto da trilha (lugar, penhasco...): tem de dar vazio
        if o.get("solid", True) and not o.get("y"):
            p = zone_lib.Vector(o["pos"])
            half = max(o["size"][0], o["size"][2]) * 0.5
            if zone_lib.poly_dist(p, south_poly) < LATE_W * 0.5 + 1.0 + half or (p - zone_lib.Vector(marsh_arrive)).length < 6.0 + half:
                print("GORGE_CONFLICT sul: %s em %s (%s)" % (o["kind"], o["pos"], o["size"]))
    lake_d = zone_lib.poly_dist(zone_lib.Vector((-30.0, 84.0)), south_poly) - 10.0
    river_d = min(zone_lib.poly_dist(q, rv) for q in south_poly for rv in z.rivers) - z.river_w * 0.5
    print("garganta sul: folga do pantano %.1f m, do rio %.1f m" % (lake_d, river_d))
    event_points(z)
    print("chegada da Floresta:", arrive, "portal:", portal)
    return z.finish(export, poi=BANDITS, ground=(0.36, 0.52, 0.34))
