"""Ruínas de Vel'Thar (field_ruins, Lv 20-30): vale seco de pedra. Acampamento da erudita no hub (praça antiga
cercada de colunas), cemitério (NE), bairro em ruínas (S), pântano dos espectros (N), pedreira dos golens (SW),
altar do Dragonete (W) e o zigurate partido (landmark, NE). Riacho escuro com pontes. Portal de volta a Aldara
na garganta leste.

    import sys; sys.path += [r"C:/Users/luisf/Desktop/projects/ragnaex/tools/blender/zones"]
    import build_field_ruins as z; z.build(export=True)
"""
import math
import random
import importlib
import nature
import places
import zone_lib
importlib.reload(zone_lib)
from zone_lib import Zone, cyl, box, disc

ZONE = "field_ruins"
HUB_R = 12.0
ALTAR = (-86.0, -12.0)
GRAVE = (58.0, -54.0)
DISTRICT = (8.0, 74.0)
MARSH = (-16.0, -80.0)
QUARRY = (-64.0, 58.0)
ZIGGURAT = (44.0, -96.0)
DEAD_TREES = [(0.5, 0.46, 0.38), (0.56, 0.52, 0.42)]
STONE = (0.68, 0.66, 0.6)


PLACES = [
    {"type": "cabin", "id": "coveiro", "pos": (62.0, -14.0), "face": 110.0, "npc": "gravedigger_osric", "roof": (0.34, 0.32, 0.36), "wall": (0.5, 0.46, 0.42)},
    {"type": "cabin", "id": "escavacao", "pos": (66.0, 84.0), "face": 140.0, "npc": "digger_vera", "roof": (0.58, 0.44, 0.3), "wall": (0.6, 0.5, 0.38)},
    {"type": "camp", "id": "patrulha", "pos": (-80.0, -42.0), "face": 70.0, "mob": "skeleton", "count": 4, "cloth": (0.32, 0.3, 0.34), "respawn": 22.0},
    {"type": "shrine", "id": "obelisco", "pos": (44.0, 56.0), "npc": "stone_obelisk", "ground": (0.56, 0.56, 0.56)},
    {"type": "dungeon", "id": "cripta", "dungeon": "dg_cripta"},
]

def polar(z, ang_deg, inset):
    a = math.radians(ang_deg)
    r = z.rim_r(a) - inset
    return (round(math.cos(a) * r, 1), round(math.sin(a) * r, 1))


def build(export=False):
    z = Zone(ZONE, seed=9, palette={
        "road": (0.62, 0.58, 0.5), "street": (0.66, 0.64, 0.6), "cliff_rock": (0.56, 0.53, 0.5), "cliff_rock_d": (0.45, 0.42, 0.39), "cliff_grass": (0.5, 0.52, 0.42),
        "hill_grass": (0.52, 0.54, 0.44), "water_dark": (0.28, 0.32, 0.4), "stone_ruin": (0.7, 0.68, 0.62), "leaf": (0.4, 0.44, 0.36),
    })
    rnd = random.Random(21)
    portal = polar(z, -3, 7)
    arrive = polar(z, -3, 15)
    z.data["spawn"] = list(arrive)
    z.portal("to_town", portal, "city_aldara", places.grow_aldara((-98.3, -30.2)), "Vale de Aldara")

    # ---------- hub: praça antiga com colunas (acampamento da erudita) ----------
    z.M["pave_hub"] = zone_lib.mat("pave_hub", (0.82, 0.71, 0.55))       # praça quente: o hub salta do cinza
    z.plaza("hub", (0, 0), HUB_R, "pave_hub")
    for i in range(10):
        a = math.tau * (i + 0.5) / 10
        if i in (0, 5):
            continue            # aberturas leste/oeste
        h = 6.0 if i % 3 else 3.2     # colunas inteiras e partidas
        z.ob("pillar", math.cos(a) * (HUB_R + 0.5), math.sin(a) * (HUB_R + 0.5), (1.5, h, 1.5), color=STONE)
    z.ob("tent", -5.5, -4.0, (3.0, 2.2, 3.0), 30, color=(0.55, 0.5, 0.65))
    z.ob("tent", -5.0, 5.0, (3.0, 2.2, 3.0), 150, color=(0.55, 0.5, 0.65))
    z.ob("crate", 5.5, -5.0, (1.0, 1.0, 1.0))
    z.ob("crate", 6.3, -4.0, (0.8, 0.8, 0.8))
    z.ob("statue", 0.0, 0.0, (2.0, 1.0, 2.0), solid=False, color=(0.5, 0.45, 0.5))
    for x, zz in ((8, 3), (8, -3), (-9, 0)):
        z.ob("lamp", x, zz, (0.4, 3.0, 0.4))
    z.npc("ruins_scholar", 4.0, 3.0, 90.0)
    z.data["hangouts"] = [[2, 6], [-2, -6], [6, 0], [-3, 3]]

    # ---------- estradas ----------
    z.road("E", [(HUB_R, 0), (30, 8), (52, -2), (74, 6), arrive, portal], end_clearing=False)
    z.road("W", [(-HUB_R, 0), (-30, -8), (-50, 2), (-66, -10), (ALTAR[0] + 12, ALTAR[1])], material="road")
    z.road("N", [(0, -HUB_R), (-8, -30), (4, -48), (-6, -62)])
    z.road("NE", [(30, 8), (38, -14), (44, -34), (GRAVE[0] - 6, GRAVE[1] + 10)])
    z.road("S", [(0, HUB_R), (8, 30), (-4, 46), (DISTRICT[0] - 2, DISTRICT[1] - 12)])
    z.road("SW", [(-50, 2), (-60, 22), (-56, 40), (QUARRY[0] + 6, QUARRY[1] - 8)])
    z.road("zigurate", [(44, -34), (36, -58), (40, -78)])
    z.road("arco_norte", [(-6, -62), (10, -74), (26, -80), (40, -78)], end_clearing=False)
    z.road("arco_sul", [(QUARRY[0] + 6, QUARRY[1] - 8), (-40, 66), (-20, 74), (DISTRICT[0] - 2, DISTRICT[1] - 12)], end_clearing=False)
    z.road("altar_pedreira", [(ALTAR[0] + 12, ALTAR[1]), (-70, 4), (-76, 24), (-68, 42), (QUARRY[0] + 6, QUARRY[1] - 8)], end_clearing=False)

    # ---------- água escura: riacho do pântano até a borda SW ----------
    z.lake("pantano", MARSH, 12.0, "water_dark")
    z.river([(-26, -128), (-24, -100), MARSH, (-34, -52), (-42, -20), (-44, 18), (-78, 40), (-130, 70)], w=5.5, material="water_dark")
    z.bridges()

    # ---------- altar do Dragonete (W) ----------
    z.M["pave_altar"] = zone_lib.mat("pave_altar", (0.6, 0.52, 0.64))
    disc(z.coll, z.P + "altar_base", ALTAR, 13.0, 0.016, z.M["pave_altar"], 36)
    cyl(z.coll, z.P + "altar_degrau", ALTAR, 6.0, 5.6, 0.35, z.M["stone_ruin"], 0.0, 16)
    z.data["roads"].append({"kind": "street", "w": 0, "pts": [list(ALTAR)], "r": 13.0})
    for i in range(12):
        a = math.tau * i / 12
        if abs(((a + math.pi) % math.tau) - math.pi) < 0.3:
            continue            # entrada pelo leste
        z.ob("pillar", ALTAR[0] + math.cos(a) * 12, ALTAR[1] + math.sin(a) * 12, (1.6, 6.0 if i % 2 else 4.0, 1.6), color=(0.6, 0.55, 0.6))
    z.block(ALTAR, 15)

    z.patch("cemiterio", GRAVE, 18.0, (0.34, 0.31, 0.29))
    z.patch("bairro", DISTRICT, 30.0, (0.72, 0.64, 0.52), paved=True)
    z.patch("pedreira", QUARRY, 22.0, (0.74, 0.62, 0.44))
    z.patch("pantano", MARSH, 22.0, (0.6, 0.56, 0.4), grass=True)

    # ---------- cemitério (NE): lápides em fileiras + cerca ----------
    for row in range(5):
        for col in range(6):
            x = GRAVE[0] - 10 + col * 4.0 + rnd.uniform(-0.3, 0.3)
            zz = GRAVE[1] - 8 + row * 4.0
            if abs(x - (GRAVE[0] - 6)) < 2.2 and row >= 3:
                continue        # corredor da estrada
            z.ob("ruin", x, zz, (0.9, 1.1 + rnd.uniform(0, 0.4), 0.3), rnd.uniform(-8, 8), color=STONE)
    for i in range(-6, 7):
        z.ob("fence", GRAVE[0] + i * 2.4, GRAVE[1] - 12, (2.4, 1.0, 0.3))
    for i in range(-4, 5):
        z.ob("fence", GRAVE[0] + 15, GRAVE[1] + i * 2.4, (0.3, 1.0, 2.4))
    z.block(GRAVE, 16)

    # ---------- bairro em ruínas (S): restos de casas (paredes partidas) ----------
    for gx in range(-2, 3):
        for gz in range(-1, 2):
            if (gx, gz) == (-1, -1):
                continue        # praça de entrada
            cx, cz = DISTRICT[0] + gx * 11, DISTRICT[1] + gz * 11
            for side in range(4):
                if rnd.random() < 0.35:
                    continue
                a = side * math.pi / 2
                L = rnd.uniform(3.0, 6.0)
                px, pz = cx + math.cos(a) * 3.2, cz + math.sin(a) * 3.2
                z.ob("ruin", px, pz, (L, rnd.uniform(1.2, 3.0), 0.7), math.degrees(a) + 90, color=STONE)
    z.block(DISTRICT, 30)

    # ---------- pedreira dos golens (SW) ----------
    z.hill("pedreira_a", (QUARRY[0] - 14, QUARRY[1] + 6), 8, 3, rock="cliff_rock", top="stone_ruin", step=2.2)
    z.hill("pedreira_b", (QUARRY[0] + 4, QUARRY[1] + 18), 7, 2, rock="cliff_rock", top="stone_ruin", step=2.2)
    z.scatter("rock", [(QUARRY, 18, 22)], 0, (1.6, 1.2, 1.4), [(0.6, 0.58, 0.55)], margin=3.0, spacing=3.0, scale=(1.0, 2.0))
    z.block(QUARRY, 16)

    # ---------- landmark: zigurate partido (NE) ----------
    top = z.hill("zigurate", ZIGGURAT, 15, 4, rock="stone_ruin", top="street", step=3.0)
    cyl(z.coll, z.P + "zigurate_torre", ZIGGURAT, 3.2, 2.6, 9.0, z.M["stone_ruin"], top, 8)
    for i in range(5):
        a = math.tau * i / 5
        box(z.coll, z.P + "zigurate_pedra_%d" % i, (ZIGGURAT[0] + math.cos(a) * 2.8, ZIGGURAT[1] + math.sin(a) * 2.8),
            (1.2, 1.0 + i * 0.6, 1.0), math.degrees(a), z.M["stone_ruin"], top + 9.0)

    z.hill("morro_s", (-40, 96), 9, 2)
    for i, (c, r, lv) in enumerate([((-22, -34), 6, 2), ((20, -40), 6, 2), ((60, 30), 7, 2), ((-30, 40), 7, 1), ((80, -40), 7, 2), ((-60, -50), 7, 2)]):
        z.terrace("plataforma_%d" % i, c, r, lv, rock="stone_ruin", top="stone_ruin")
    z.hill("morro_e", (96, 40), 9, 3)
    z.cliffs(snow=False)

    places.build(z, PLACES)

    # ---------- vegetação seca, pedras, restos ----------
    z.block((0, 0), HUB_R + 4)
    z.scatter("tree", [((0, 0), 110, 90), (MARSH, 24, 16), ((80, 70), 20, 14)], 0, (1.5, 3.3, 1.5), DEAD_TREES,
              margin=4.6, spacing=4.5, hub_r=HUB_R + 6, scale=(0.8, 1.2))
    z.rim_belt(110, (1.5, 3.3, 1.5), DEAD_TREES)
    z.scatter("rock", [((0, 0), 105, 60)], 0, (1.4, 0.9, 1.2), [(0.62, 0.6, 0.56)], margin=3.5, spacing=3.0, hub_r=HUB_R + 4, scale=(0.7, 1.6))
    z.scatter("ruin", [((0, 0), 100, 30), ((40, 20), 20, 8)], 0, (2.4, 1.6, 0.7), [STONE], margin=4.0, spacing=5.0, hub_r=HUB_R + 6, scale=(0.7, 1.5))
    z.scatter("pillar", [((30, -30), 30, 6), ((-30, 40), 30, 6)], 0, (1.3, 3.5, 1.3), [STONE], margin=4.0, spacing=8.0, hub_r=HUB_R + 6)

    # ---------- natureza (passe 3): árvores secas, moitas ressecadas, troncos podres, juncos do pântano ----------
    nrnd = random.Random(43)
    obs = z.data["obstacles"]
    fr = lambda x, zz, m: z.free(x, zz, m, HUB_R + 6)
    nature.fix_trees(obs, nrnd, dead=True, dead_cols=[(0.42, 0.36, 0.3), (0.5, 0.44, 0.36), (0.36, 0.33, 0.3)])
    nature.scatter(z.ob, fr, nrnd, "bush", [((0, 0), 105, 45), (MARSH, 26, 12)], (1.6, 0.85, 1.6),
                   [(0.42, 0.46, 0.3), (0.5, 0.5, 0.32), (0.36, 0.42, 0.3)], solid=False, margin=2.6, spacing=3.0, avoid=obs)
    nature.woodland_floor(z.ob, fr, nrnd, [((0, 0), 100, 14), (MARSH, 24, 6)], bark=[(0.42, 0.38, 0.33), (0.36, 0.33, 0.3)], avoid=obs)
    nature.clear_banks(obs, z.rivers, [(MARSH, 12.0)], z.river_w)
    nature.shore(z.ob, nrnd, z.rivers, [(MARSH, 12.0)], list(z.road_polys.values()), z.river_w,
                 colors=[(0.4, 0.48, 0.3), (0.46, 0.46, 0.32)], keep=0.75)

    # ---------- monstros ----------
    z.spawner("skeleton", GRAVE[0], GRAVE[1], 10, 6, 16.0)
    z.spawner("skeleton", DISTRICT[0] - 6, DISTRICT[1] - 4, 10, 6, 16.0)
    z.spawner("skeleton", 36, 26, 9, 5, 16.0)
    z.spawner("ghost", MARSH[0] + 14, MARSH[1] + 14, 10, 4, 20.0)
    z.spawner("ghost", DISTRICT[0] + 16, DISTRICT[1] + 6, 9, 4, 20.0)
    z.spawner("golem", QUARRY[0], QUARRY[1], 9, 3, 30.0)
    z.spawner("golem", QUARRY[0] + 14, QUARRY[1] - 10, 8, 3, 30.0)
    z.spawner("dragonling", ALTAR[0], ALTAR[1], 2, 1, 300.0)
    print("chegada das Ruínas:", arrive, "portal:", portal)
    return z.finish(export, poi=ALTAR, ground=(0.55, 0.52, 0.47))
