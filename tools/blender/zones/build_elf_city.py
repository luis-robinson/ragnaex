"""Cidade Élfica (elf_city, Lv 17-21): vale de mata alta onde os elfos guardam a Árvore-Mãe Ancestral. No hub, o anel
da cidade (muralha clara, torres finas, casas de telhado verde-água) em volta da Grande Árvore; a raiz norte abre o
Coração da Árvore (dungeon do Rei Élfico). POIs: ninho dos grifos (NO, penhascos), bosque dos trents (NE, chão escuro),
campo de treino (L), poço da lua (O, lago). Riacho a oeste com pontes. Acampamento humano do cerco na entrada sul.

    import sys; sys.path += [r"C:/Users/luisf/Desktop/projects/ragnaex/tools/blender/zones"]
    import build_elf_city as z; z.build(export=True)
"""
import math
from mathutils import Vector
import random
import importlib
import nature
import places
import zone_lib
importlib.reload(zone_lib)
from zone_lib import Zone, cyl, box, blob, disc, cone

ZONE = "elf_city"
RING_R = 44.0
TREE_R = 6.0
AERIE = (-66.0, -64.0)
GROVE = (70.0, -58.0)
TRAINING = (88.0, 16.0)
MOONWELL = (-84.0, 14.0)
ELF_TREES = [(0.24, 0.46, 0.36), (0.3, 0.52, 0.4), (0.36, 0.58, 0.44)]
GROVE_TREES = [(0.17, 0.3, 0.2), (0.21, 0.34, 0.22)]
WALL = (0.86, 0.86, 0.78)
ROOF = (0.3, 0.56, 0.5)

PLACES = [
    {"type": "cabin", "id": "cerco", "pos": (36.0, 80.0), "face": 200.0, "npc": "siege_scout", "roof": (0.5, 0.36, 0.26)},
    {"type": "cabin", "id": "desertor", "pos": (-86.0, 62.0), "face": 20.0, "npc": "elf_deserter", "roof": ROOF, "wall": WALL},
    {"type": "camp", "id": "patrulha", "pos": (70.0, 64.0), "face": 140.0, "mob": "elf_warrior", "count": 4, "cloth": (0.36, 0.6, 0.46), "respawn": 22.0},
    {"type": "shrine", "id": "altar_lua", "pos": (-24.0, -100.0), "npc": "moon_altar", "ground": (0.74, 0.76, 0.8)},
    {"type": "dungeon", "id": "coracao", "dungeon": "dg_coracao"},
]


def polar(z, ang_deg, inset):
    a = math.radians(ang_deg)
    r = z.rim_r(a) - inset
    return (round(math.cos(a) * r, 1), round(math.sin(a) * r, 1))


def great_tree(z, c):
    """Árvore-Mãe Ancestral: tronco largo, raízes em leque e a copa ALTA (> câmera do jogo, 19 m): de perto não tampa ninguém."""
    cyl(z.coll, z.P + "arvore_tronco", c, TREE_R * 1.45, TREE_R * 0.8, 36.0, z.M["bark"], 0.0, 14, 0.08, 3)
    for i in range(10):
        a = math.tau * i / 10 + 0.2
        if abs(math.atan2(math.sin(a - math.pi / 4), math.cos(a - math.pi / 4))) < 0.45:
            continue                         # sudeste (de frente para a câmera): a porta do Coração da Árvore fica aqui
        rt = (c[0] + math.cos(a) * TREE_R * 1.9, c[1] + math.sin(a) * TREE_R * 1.9)
        box(z.coll, z.P + "arvore_raiz_%d" % i, rt, (TREE_R * 2.2, 1.6 + (i % 3) * 0.5, 1.8), math.degrees(-a), z.M["bark"], 0.0)
    rnd = random.Random(5)
    for i in range(11):
        a = math.tau * i / 11
        off = 0.0 if i == 0 else rnd.uniform(9.0, 15.0)
        y = 44.0 if i == 0 else rnd.uniform(36.0, 41.0)
        r = 15.0 if i == 0 else rnd.uniform(8.0, 10.5)
        blob(z.coll, z.P + "arvore_copa_%d" % i, (c[0] + math.cos(a) * off, c[1] + math.sin(a) * off), r, y, z.M["leaf"], i, 0.6)
    # plataformas em anel no tronco (vida élfica no alto), com guarda-corpo e casulos de luz pendurados
    for k, (pz, pr) in enumerate(((9.0, TREE_R * 1.9), (16.0, TREE_R * 1.7))):
        cyl(z.coll, z.P + "arvore_deque_%d" % k, c, pr, pr, 0.35, z.M["road"], pz, 28)
        cyl(z.coll, z.P + "arvore_deque_aba_%d" % k, c, pr + 0.15, pr - 0.3, 0.4, z.M["bark"], pz - 0.4, 28)
        n_post = 20
        for i in range(n_post):
            a = math.tau * i / n_post
            q = (c[0] + math.cos(a) * (pr - 0.2), c[1] + math.sin(a) * (pr - 0.2))
            cyl(z.coll, z.P + "arvore_poste_%d_%d" % (k, i), q, 0.07, 0.07, 1.0, z.M["town_wall"], pz + 0.35, 6)
            if i % 4 == 0:
                g = (c[0] + math.cos(a) * (pr + 0.6), c[1] + math.sin(a) * (pr + 0.6))
                blob(z.coll, z.P + "arvore_casulo_%d_%d" % (k, i), g, 0.4, pz - 0.9, z.M["glow"], i, 1.3)
        for i in range(4):                   # braços de galho que seguram o deque
            a = math.tau * (i + 0.5) / 4 + k
            box(z.coll, z.P + "arvore_braco_%d_%d" % (k, i), (c[0] + math.cos(a) * pr * 0.75, c[1] + math.sin(a) * pr * 0.75),
                (pr * 0.9, 0.6, 0.6), math.degrees(-a), z.M["bark"], pz - 1.6)
    for i in range(8):                       # lanternas penduradas nos galhos baixos (pontos de luz vistos de cima)
        a = math.tau * (i + 0.5) / 8
        p = (c[0] + math.cos(a) * 13.0, c[1] + math.sin(a) * 13.0)
        cone(z.coll, z.P + "arvore_lanterna_%d" % i, p, 0.5, 0.9, z.M["glow"], 7.5 + (i % 3), 6)
    z.ob("pillar", c[0], c[1], (TREE_R * 3.0, 36.0, TREE_R * 3.0), visible=False)
    z.block(c, TREE_R * 3.4)


def build(export=False):
    z = Zone(ZONE, seed=13, palette={
        "leaf": (0.3, 0.54, 0.32), "cliff_grass": (0.3, 0.5, 0.38), "hill_grass": (0.38, 0.58, 0.42), "bark": (0.46, 0.36, 0.26),
        "cliff_rock": (0.52, 0.52, 0.5), "road": (0.78, 0.74, 0.62), "street": (0.84, 0.82, 0.74), "water": (0.36, 0.62, 0.78),
        "water_dark": (0.3, 0.5, 0.66), "town_wall": WALL, "roof": ROOF, "glow": (0.7, 1.0, 0.75), "hedge_l": (0.42, 0.62, 0.34),
    })
    portal = polar(z, 90, 7)
    arrive = polar(z, 90, 15)
    z.data["spawn"] = list(arrive)
    z.portal("to_forest", portal, "field_forest", (-5.3, -101.0), "Floresta Sombria")

    # ---------- hub: anel da cidade em volta da Grande Árvore ----------
    gate_deg = [90.0, 0.0, 180.0, -125.0, -55.0, -90.0]   # S (cerco), L (treino), O (poço), NO (grifos), NE (trents), N (Coração)
    gates = [math.radians(a) for a in gate_deg]
    H = lambda r, a: (math.cos(math.radians(a)) * r, math.sin(math.radians(a)) * r)
    z.patch("clareira", (0, 0), RING_R + 10, (0.5, 0.66, 0.46), grass=True)
    # chão da cidade: musgo com grama (a cidade é dentro da mata, não um largo de pedra); só a praça das raízes é calçada
    z.M["patch_musgo"] = zone_lib.mat("patch_musgo", (0.4, 0.58, 0.34))
    zone_lib.disc(z.coll, z.P + "chao_cidade", (0, 0), RING_R - 1.0, 0.009, z.M["patch_musgo"], 64, 0.02, 3)
    z.M["pave_raiz"] = zone_lib.mat("pave_raiz", (0.56, 0.62, 0.46))
    z.plaza("raiz", (0, 0), 24.0, "pave_raiz")             # praça musgosa das raízes
    # muro vivo: casca de árvore com sebe por cima (não pedra); árvores-vigia no lugar das torres
    z.ring_wall("cidade", (0, 0), RING_R, gates, gate_half=3.6, height=3.4, thick=1.6, material="bark", towers=0)
    z.M["pe_muro"] = zone_lib.mat("pe_muro", (0.36, 0.3, 0.22))
    zone_lib.disc(z.coll, z.P + "pe_muro", (0, 0), RING_R + 2.2, 0.008, z.M["pe_muro"], 72, 0.0, 1)      # faixa de terra escura sob o muro vivo: o anel lê de cima
    n_hedge = int(math.tau * RING_R / 3.2)
    for i in range(n_hedge):
        a = math.tau * (i + 0.5) / n_hedge
        if any(zone_lib.angdiff(a, g) * RING_R < 4.6 for g in gates):
            continue
        blob(z.coll, z.P + "sebe_%d" % i, (math.cos(a) * RING_R, math.sin(a) * RING_R), 1.6 + 0.3 * (i % 3), 3.6, z.M["leaf"] if i % 2 else z.M["hedge_l"], i, 0.55)
    for i in range(10):
        a = 360.0 * (i + 0.5) / 10
        if any(abs((a - g + 180.0) % 360.0 - 180.0) < 12.0 for g in gate_deg):
            continue
        z.ob("tree", *H(RING_R - 2.6, a), (2.6, 8.5, 2.6), color=(0.3, 0.6, 0.4))
    z.data["town"] = {"center": [0.0, 0.0], "radius": RING_R, "gates": [[round(H(RING_R, a)[0], 2), round(H(RING_R, a)[1], 2)] for a in gate_deg]}
    great_tree(z, (0.0, 0.0))
    for a in gate_deg:                                    # avenidas da praça até os portões
        z.road("av_%d" % int(a), [H(24.0, a), H(RING_R - 2.0, a)], w=4.0, material="road", end_clearing=False)
    z.road("anel", [H(27.0, 360.0 * k / 24) for k in range(25)], w=3.0, material="road", end_clearing=False)     # passeio em volta da praça
    # casas que crescem das árvores (prop_elf_treehouse / prop_elf_hut, tools/blender/elf_props.py), de frente para a praça
    face = lambda a: round(math.degrees(math.atan2(-math.cos(math.radians(a)), -math.sin(math.radians(a)))), 1)
    for i in range(14):
        a = 360.0 * (i + 0.5) / 14
        if any(abs((a - g + 180.0) % 360.0 - 180.0) < 13.0 for g in gate_deg):
            continue
        if i % 2 == 0:
            z.ob("elf_treehouse", *H(33.5, a), (5.6, 13.0, 5.6), face(a), color=WALL, roof=ROOF)
        else:
            z.ob("elf_hut", *H(31.0, a), (3.8, 4.6, 3.8), face(a), color=WALL, roof=ROOF)
            z.ob("elf_hut", *H(37.0, a + 6.0), (3.2, 3.9, 3.2), face(a + 6.0), color=WALL, roof=(0.36, 0.6, 0.5))
    for i in range(16):
        a = 360.0 * i / 16
        if any(abs((a - g + 180.0) % 360.0 - 180.0) < 8.0 for g in gate_deg):
            continue
        z.ob("elf_lantern", *H(23.6, a), (1.2, 3.4, 0.5), face(a) + 90.0)
    # mata dentro da cidade: árvores, arbustos e flores entre as casas (longe das ruas e das casas)
    rin = random.Random(77)
    houses = [(Vector(o["pos"]), max(o["size"][0], o["size"][2]) * 0.5 + 1.6) for o in z.data["obstacles"] if o["kind"].startswith("elf_") and o.get("solid", True)]
    paths = [poly for k, poly in z.road_polys.items() if k.startswith("av_") or k == "anel"]
    placed = []
    for kind, n, size, cols, solid in (("tree", 16, (1.7, 4.6, 1.7), [(0.26, 0.5, 0.3), (0.32, 0.56, 0.34)], True),
                                       ("bush", 34, (1.6, 0.9, 1.6), [(0.3, 0.52, 0.32), (0.38, 0.6, 0.36)], False),
                                       ("flowers", 30, (1.5, 0.45, 1.5), [(0.85, 0.95, 1.0), (0.95, 0.85, 0.5), (0.75, 0.6, 0.95)], False)):
        k = 0
        for _ in range(n * 30):
            if k >= n:
                break
            a = rin.uniform(0, math.tau)
            r = rin.uniform(21.0, RING_R - 3.2)
            q = Vector((math.cos(a) * r, math.sin(a) * r))
            if any((q - hc).length < hr + (1.4 if solid else 0.6) for hc, hr in houses):
                continue
            if any(zone_lib.poly_dist(q, poly) < (3.4 if solid else 2.4) for poly in paths):
                continue
            if any((q - pp).length < (3.0 if solid else 1.6) for pp in placed):
                continue
            sc = rin.uniform(0.85, 1.3)
            z.ob(kind, q.x, q.y, (size[0] * sc, size[1] * sc, size[2] * sc), 0.0, solid=solid, color=cols[rin.randrange(len(cols))])
            placed.append(q)
            k += 1
    for a in gate_deg:                                    # portais em arco de dois troncos (só visual: a passagem fica livre)
        z.ob("elf_arch", *H(RING_R - 0.5, a), (5.6, 5.4, 0.9), face(a), solid=False)
    z.data["hangouts"] = [list(arrive), [10.0, 80.0], [-8.0, 70.0], [30.0, 72.0], list(H(28.0, 90.0)), [-70.0, 26.0], [76.0, 24.0]]

    # ---------- estradas (curvas; os portões ligam os POIs e há arcos entre eles) ----------
    gS, gE, gW, gNW, gNE, gN = (H(RING_R, a) for a in gate_deg)
    z.road("S", [gS, (8, 58), (-6, 76), (2, 90), arrive, portal], end_clearing=False)
    z.road("L", [gE, (60, 6), (74, 18), (TRAINING[0] - 8, TRAINING[1])])
    z.road("O", [gW, (-52, 0), (-66, 2), (MOONWELL[0] + 11, MOONWELL[1] - 5)])      # cruza o riacho de frente (ponte reta)
    z.road("NO", [gNW, (-34, -50), (-48, -60), (AERIE[0] + 8, AERIE[1] + 4)])
    z.road("NE", [gNE, (34, -48), (52, -52), (GROVE[0] - 8, GROVE[1] + 2)])
    z.road("N", [gN, (2, -50), (0, -55)])
    z.road("arco_norte", [(AERIE[0] + 8, AERIE[1] + 4), (-50, -84), (-26, -92), (6, -94), (36, -86), (GROVE[0] - 8, GROVE[1] + 2)])
    z.road("arco_leste", [(GROVE[0] + 4, GROVE[1] + 10), (86, -30), (TRAINING[0] + 2, TRAINING[1] - 8)])
    z.road("arco_sul", [(TRAINING[0] - 2, TRAINING[1] + 8), (82, 42), (64, 56), (40, 70), (-6, 76)], end_clearing=False)
    z.road("arco_oeste", [(MOONWELL[0] + 8, MOONWELL[1] + 12), (-82, 46), (-72, 72), (-58, 86), (-30, 84), (-6, 76)], end_clearing=False)

    # ---------- água: riacho a oeste (pontes nas estradas) e o poço da lua ----------
    z.river([(-34, -128), (-38, -96), (-54, -60), (-58, -26), (-62, 4), (-66, 34), (-48, 70), (-40, 128)], w=5.5)
    z.lake("poco_lua", MOONWELL, 10.0, "water_dark")
    z.bridges()

    # ---------- POIs ----------
    z.patch("ninho", AERIE, 16.0, (0.56, 0.54, 0.48), grass=False)        # rocha clara dos ninhos
    for i, (dx, dz, r, lv) in enumerate([(-10, -8, 6, 3), (8, -12, 5, 2), (-14, 10, 5, 2)]):
        z.terrace("ninho_%d" % i, (AERIE[0] + dx, AERIE[1] + dz), r, lv, top="cliff_grass")
    for i in range(5):                                                     # ninhos (anéis de galhos) no chão
        a = math.tau * i / 5 + 0.4
        p = (AERIE[0] + 4 + math.cos(a) * 7.0, AERIE[1] + 2 + math.sin(a) * 7.0)
        z.ob("log", p[0], p[1], (2.4, 0.6, 2.4), math.degrees(a), color=(0.6, 0.5, 0.34))
    z.patch("bosque", GROVE, 18.0, (0.22, 0.32, 0.22), grass=True)        # chão escuro do bosque dos trents
    z.patch("treino", TRAINING, 13.0, (0.74, 0.7, 0.58))
    for i in range(6):
        a = math.tau * i / 6
        z.ob("pillar", TRAINING[0] + math.cos(a) * 8.0, TRAINING[1] + math.sin(a) * 8.0, (0.5, 1.9, 0.5), color=(0.7, 0.55, 0.36))
    for i in range(3):
        z.ob("fence", TRAINING[0] + 11.0, TRAINING[1] - 6.0 + i * 6.0, (5.0, 1.2, 0.4), 90.0)
    for i in range(6):                                                     # colunas brancas em volta do poço
        a = math.tau * (i + 0.5) / 6
        z.ob("pillar", MOONWELL[0] + math.cos(a) * 13.5, MOONWELL[1] + math.sin(a) * 13.5, (0.9, 3.6, 0.9), color=WALL)

    # ---------- relevo ----------
    z.hill("colina_se", (90, 80), 9, 2)
    z.hill("colina_n", (30, -104), 8, 2)
    for i, (c, r, lv) in enumerate([((-90, -26), 7, 2), ((96, -60), 6, 2), ((-30, 104), 6, 1), ((60, 100), 6, 1)]):
        z.terrace("afloramento_%d" % i, c, r, lv, top="cliff_grass")
    z.cliffs()

    z.avoid = [(MOONWELL, 13.0), ((0.0, 0.0), RING_R + 2.0)]
    places.build(z, PLACES)

    # ---------- vegetação ----------
    z.block((0, 0), RING_R + 9)
    z.block(AERIE, 18)
    z.block(TRAINING, 14)
    z.block(MOONWELL, 15)
    z.scatter("tree", [(GROVE, 20, 34)], 0, (1.8, 4.2, 1.8), GROVE_TREES, margin=4.0, spacing=4.2, scale=(1.2, 1.8))
    z.scatter("tree", [((-20, -70), 22, 26), ((50, -90), 18, 16), ((-90, 50), 20, 22), ((90, 50), 16, 12), ((-60, 100), 16, 14), ((20, 104), 14, 10)],
              0, (1.7, 4.0, 1.7), ELF_TREES, margin=4.2, spacing=3.6, scale=(1.1, 1.7))
    z.scatter("tree", [((0, 0), 112, 200)], 0, (1.7, 4.0, 1.7), ELF_TREES, margin=4.6, spacing=4.2, hub_r=RING_R + 12, scale=(1.0, 1.5))
    z.rim_belt(170, (1.7, 4.0, 1.7), ELF_TREES[:2])
    z.scatter("rock", [(AERIE, 22, 12), ((0, 0), 100, 18)], 0, (1.4, 0.9, 1.2), [(0.6, 0.6, 0.58)], margin=3.5, spacing=2.5,
              hub_r=RING_R + 10, scale=(0.8, 1.6))
    nrnd = random.Random(53)
    obs = z.data["obstacles"]
    fr = lambda x, zz, m: z.free(x, zz, m, RING_R + 12)
    nature.fix_trees(obs, nrnd, pine_frac=0.15)
    nature.scatter(z.ob, fr, nrnd, "bush", [((0, 0), 110, 110)], (1.7, 0.95, 1.7), [(0.28, 0.5, 0.38), (0.34, 0.58, 0.42)],
                   solid=False, margin=2.6, spacing=2.6, avoid=obs)
    nature.scatter(z.ob, fr, nrnd, "flowers", [((0, 0), 105, 34)], (1.6, 0.45, 1.6), [(0.85, 0.95, 1.0), (0.7, 0.95, 0.75), (0.95, 0.85, 0.5)],
                   solid=False, margin=2.6, spacing=4.0, avoid=obs)
    nature.woodland_floor(z.ob, fr, nrnd, [(GROVE, 20, 10), ((-20, -70), 22, 8), ((0, 0), 100, 18)], avoid=obs)
    nature.clear_banks(obs, z.rivers, [(MOONWELL, 10.0)], z.river_w)
    nature.shore(z.ob, nrnd, z.rivers, [(MOONWELL, 10.0)], list(z.road_polys.values()), z.river_w)

    # ---------- monstros ----------
    for i, a in enumerate((45.0, 135.0, -100.0, -20.0)):                 # guarnição dentro do anel (entre árvore e muro)
        x, zz = H(31.0, a)
        z.spawner("elf_warrior" if i % 2 == 0 else "elf_archer", round(x, 1), round(zz, 1), 6, 4, 22.0)
    z.spawner("elf_warden", 17.0, 10.0, 3, 2, 60.0)                       # guardam a porta do Coração, no tronco (sudeste)
    z.spawner("griffin", AERIE[0] + 4, AERIE[1] + 2, 11, 5, 26.0)
    z.spawner("trent", GROVE[0], GROVE[1], 12, 4, 30.0)
    z.spawner("elf_warrior", TRAINING[0] - 2, TRAINING[1] - 3, 7, 4, 22.0)
    z.spawner("elf_archer", TRAINING[0] + 3, TRAINING[1] + 4, 6, 3, 22.0)
    z.spawner("elf_archer", MOONWELL[0] + 13, MOONWELL[1] + 8, 6, 3, 22.0)
    z.spawner("elf_lynx", -20.0, -78.0, 9, 4, 18.0)
    return z.finish(export, poi=AERIE, ground=(0.4, 0.58, 0.42))
