"""Floresta Sombria (field_forest, Lv 10-20): vale de mata fechada, acampamento dos rangers no hub (paliçada),
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
import zone_lib
importlib.reload(zone_lib)
from zone_lib import Zone, ROAD_W

ZONE = "field_forest"
CAMP_R = 17.0
BANDITS = (68.0, -60.0)
BANDIT_R = 14.0
TREE_COLS = [(0.22, 0.4, 0.27), (0.27, 0.47, 0.3), (0.32, 0.52, 0.32)]
PLACES = [
    {"type": "cabin", "id": "herborista", "pos": (-44.0, 30.0), "face": 60.0, "npc": "herbalist_maren", "roof": (0.36, 0.46, 0.32)},
    {"type": "cabin", "id": "cacador", "pos": (70.0, -16.0), "face": 170.0, "npc": "hunter_dario", "roof": (0.46, 0.32, 0.24)},
    {"type": "camp", "id": "emboscada", "pos": (46.0, 94.0), "face": 215.0, "mob": "bandit", "count": 4},
    {"type": "shrine", "id": "circulo", "pos": (-28.0, -100.0), "npc": "stone_druid", "ground": (0.56, 0.56, 0.56)},
    {"type": "dungeon", "id": "ninho", "dungeon": "dg_ninho"},
]


def polar(z, ang_deg, inset):
    a = math.radians(ang_deg)
    r = z.rim_r(a) - inset
    return (round(math.cos(a) * r, 1), round(math.sin(a) * r, 1))


def build(export=False):
    z = Zone(ZONE, seed=3, palette={
        "leaf": (0.2, 0.38, 0.26), "cliff_grass": (0.26, 0.42, 0.28), "hill_grass": (0.3, 0.46, 0.3),
        "cliff_rock": (0.38, 0.37, 0.36), "road": (0.55, 0.46, 0.34), "water": (0.3, 0.52, 0.6), "water_dark": (0.24, 0.34, 0.3),
    })
    portal = polar(z, 175, 7)
    arrive = polar(z, 175, 15)
    z.data["spawn"] = list(arrive)
    z.portal("to_town", portal, "city_aldara", places.grow_aldara((98.3, -32.1)), "Vale de Aldara")

    # ---------- hub: acampamento dos rangers ----------
    gates = [math.pi, 0.0, -math.pi / 2, math.pi / 2]
    z.patch("clareira", (0, 0), CAMP_R + 11, (0.5, 0.62, 0.38), grass=True)   # clareira clara: o acampamento "fura" a mata
    z.plaza("acampamento", (0, 0), CAMP_R - 1.0, "road")
    z.ring_wall("acampamento", (0, 0), CAMP_R, gates, gate_half=3.0, height=2.8, stakes=True, towers=4)
    for i, a in enumerate((45, 135, 225, 315)):
        r = math.radians(a)
        z.ob("tent", math.cos(r) * 10.5, math.sin(r) * 10.5, (3.0, 2.2, 3.0), a + 90, color=(0.45, 0.5, 0.35))
    z.ob("crate", 3.5, -5.5, (1.0, 1.0, 1.0))
    z.ob("crate", 4.6, -5.0, (0.8, 0.8, 0.8))
    z.ob("well", -4.0, 3.0, (1.6, 1.4, 1.6))
    for a in gates:
        for s in (-1, 1):
            p = (math.cos(a) * (CAMP_R - 2) - math.sin(a) * 3.6 * s, math.sin(a) * (CAMP_R - 2) + math.cos(a) * 3.6 * s)
            z.ob("lamp", p[0], p[1], (0.4, 3.0, 0.4))
    z.npc("ranger_post", 3.5, 2.0, -100.0)
    z.data["hangouts"] = [[0, 4], [-4, -3], [5, -2], [-2, 6], [-6, -1]]

    # ---------- estradas ----------
    z.road("W", [(-CAMP_R, 0), (-30, 7), (-50, -3), (-70, 9), arrive, portal], end_clearing=False)
    z.road("N", [(0, -CAMP_R), (6, -30), (-8, -46), (-30, -56), (-50, -54)])
    gate_dir = math.atan2(-26 - BANDITS[1], 44 - BANDITS[0])
    gate_out = (BANDITS[0] + math.cos(gate_dir) * (BANDIT_R + 3), BANDITS[1] + math.sin(gate_dir) * (BANDIT_R + 3))
    z.road("E", [(CAMP_R, 0), (30, -8), (40, -22), gate_out, (BANDITS[0] + math.cos(gate_dir) * (BANDIT_R - 4), BANDITS[1] + math.sin(gate_dir) * (BANDIT_R - 4))])
    z.road("S", [(0, CAMP_R), (-6, 30), (6, 48), (26, 58), (50, 58)])
    z.road("SW", [(-6, 30), (-24, 44), (-42, 58)])
    z.road("arvore", [(-8, -46), (2, -66), (8, -80)])
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
    for i, (c, r, lv) in enumerate([((-24, -24), 6, 2), ((52, 10), 7, 2), ((-70, -20), 7, 2), ((88, -30), 6, 1), ((-60, 30), 6, 1)]):
        z.terrace("afloramento_%d" % i, c, r, lv, top="cliff_grass")

    z.cliffs()

    places.build(z, PLACES)

    # ---------- vegetação ----------
    z.block((0, 0), CAMP_R + 11)
    z.block(BANDITS, BANDIT_R + 3)
    z.scatter("tree", [((-58, -54), 26, 70), ((-46, 62), 20, 40), ((66, 56), 26, 55), ((20, -70), 28, 50),
                       ((-80, -20), 24, 40), ((90, -50), 20, 30), ((-10, 100), 22, 35), ((60, 100), 16, 18), ((-100, 90), 14, 14)],
              0, (1.6, 3.6, 1.6), TREE_COLS, margin=4.2, spacing=3.4, scale=(1.0, 1.6))
    z.scatter("tree", [((0, 0), 110, 240)], 0, (1.6, 3.6, 1.6), TREE_COLS, margin=4.6, spacing=4.0, hub_r=CAMP_R + 6, scale=(0.9, 1.4))
    z.rim_belt(170, (1.6, 3.6, 1.6), TREE_COLS[:2])
    z.scatter("rock", [((-58, -54), 26, 10), ((66, 56), 20, 8), ((0, 0), 100, 25)], 0, (1.4, 0.9, 1.2), [(0.5, 0.5, 0.48)],
              margin=3.5, spacing=2.5, hub_r=CAMP_R + 4, scale=(0.8, 1.6))

    # ---------- natureza (passe 3): pinheiros na mata, sub-bosque, troncos/tocos, flores frias, juncos ----------
    nrnd = random.Random(41)
    obs = z.data["obstacles"]
    fr = lambda x, zz, m: z.free(x, zz, m, CAMP_R + 6)
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
    z.spawner("bandit", 50, -36, 8, 4, 18.0)
    z.spawner("bandit", BANDITS[0] - 2, BANDITS[1] + 2, 6, 4, 18.0)
    z.spawner("bandit_archer", BANDITS[0] + 4, BANDITS[1] - 5, 5, 3, 20.0)
    z.spawner("bandit_chief", BANDITS[0] + 3, BANDITS[1] - 2, 2, 1, 180.0)
    z.spawner("ent", 66, 54, 10, 4, 24.0)
    z.spawner("ent", 82, 36, 8, 3, 24.0)
    z.data["arrive_from_town"] = list(arrive)
    print("chegada da Floresta:", arrive, "portal:", portal)
    return z.finish(export, poi=BANDITS, ground=(0.36, 0.52, 0.34))
