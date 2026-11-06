"""Fortalezas dos mortos-vivos do Bastião da Aurora (terceiro andar) e a Cidadela do Lich. Um mapa por fortaleza,
gerados por um laço: chegada ao sul (portal de volta ao Bastião), estrada curva até o portão, dois postos avançados
para retomar, a fortaleza com muralha, torres e pátio (marco próprio e o chefe), prisioneiros nas jaulas.
Retomada (quest do chefe): os mortos somem, nasce o assentamento da Aurora (NPCs + guarnição) e, nas fortalezas
seguintes, as levas aliadas sobem a estrada (`assaults`). Referência: fortalezas dos mortos-vivos de Wesnoth.

    import sys; sys.path += [r"C:/Users/luisf/Desktop/projects/ragnaex/tools/blender/zones"]
    import build_dawn_forts as f; f.build(export=True)          # todas
    f.build(export=True, only=["fort_bones"])
"""
import math
import random
import importlib
import nature
import places
import zone_lib
importlib.reload(zone_lib)
from zone_lib import Zone, cyl, box, disc

FORT_C = (0.0, -30.0)
FORT_R = 28.0
ARRIVE_IN_FORT = (0.0, 96.0)          # chegada em todo mapa de fortaleza (o Bastião aponta para cá)

FORTS = {
    "fort_ghoul": {
        "name": "Covil do Carniçal", "seed": 31, "quest": "dw_ghoul_boss", "posts_quest": "dw_ghoul_posts", "after": None, "boss": "ghoul_giant",
        "ground": (0.4, 0.38, 0.24), "wall": (0.38, 0.3, 0.22), "wall_mat": "bark", "accent": (0.45, 0.68, 0.22), "patio": (0.32, 0.27, 0.18),
        "trees": [(0.36, 0.34, 0.26), (0.42, 0.38, 0.28)],
        "outside": [("larva", 8, 14.0), ("rot_zombie", 5, 18.0), ("rot_wolf", 3, 20.0), ("rot_bear", 2, 30.0)],
        "inside": [("rot_ghoul", 4, 22.0), ("larva", 6, 14.0)],
        "posts": [("rot_ghoul", 3), ("rot_zombie", 4)],
    },
    "fort_bones": {
        "name": "Fortaleza dos Ossos", "seed": 37, "quest": "dw_bones_boss", "posts_quest": "dw_bones_posts", "after": "dw_ghoul_boss", "boss": "death_knight",
        "ground": (0.56, 0.54, 0.5), "wall": (0.26, 0.24, 0.28), "wall_mat": "town_wall", "accent": (0.9, 0.87, 0.78), "patio": (0.3, 0.29, 0.32),
        "trees": [(0.42, 0.38, 0.34), (0.36, 0.33, 0.3)],
        "outside": [("skeleton", 6, 18.0), ("skel_archer", 4, 20.0), ("skel_guard", 2, 24.0)],
        "inside": [("skel_guard", 3, 24.0), ("skel_archer", 3, 20.0), ("skeleton", 3, 18.0)],
        "posts": [("skeleton", 4), ("skel_archer", 3)],
    },
    "fort_frost": {
        "name": "Torre do Mago Gélido", "seed": 41, "quest": "dw_frost_boss", "posts_quest": "dw_frost_posts", "after": "dw_bones_boss", "boss": "frost_mage",
        "ground": (0.74, 0.82, 0.9), "wall": (0.5, 0.6, 0.72), "wall_mat": "town_wall", "accent": (0.6, 0.85, 1.0), "patio": (0.86, 0.92, 0.98),
        "trees": [(0.62, 0.68, 0.74), (0.55, 0.6, 0.66)],
        "outside": [("cultist", 4, 20.0), ("tower_bat", 6, 16.0), ("ghost", 3, 22.0)],
        "inside": [("cultist", 4, 20.0), ("ghost", 3, 22.0)],
        "posts": [("cultist", 3), ("tower_bat", 4)],
    },
    "lich_citadel": {
        "name": "Cidadela do Lich", "seed": 53, "quest": "dw_lich", "posts_quest": "dw_lich", "after": "dw_frost_boss", "boss": "lich_king",
        "ground": (0.32, 0.28, 0.36), "wall": (0.2, 0.17, 0.24), "wall_mat": "town_wall", "accent": (0.7, 0.5, 1.0), "patio": (0.4, 0.33, 0.48),
        "trees": [(0.3, 0.26, 0.3), (0.26, 0.22, 0.28)],
        "outside": [("citadel_horror", 3, 26.0), ("citadel_adept", 3, 26.0)],
        "inside": [("citadel_knight", 4, 26.0), ("citadel_adept", 2, 26.0)],
        "posts": [("citadel_knight", 2), ("citadel_horror", 2)],
    },
}
# portal de volta ao Bastião: chegada lá (gorge_in do lado; números do JSON do Bastião)
BACK = {"fort_ghoul": (-96.1, 0.0), "fort_bones": (0.0, -88.2), "fort_frost": (0.0, 99.8), "lich_citadel": (66.3, -73.7)}


def polar(z, ang_deg, inset):
    a = math.radians(ang_deg)
    r = z.rim_r(a) - inset
    return (round(math.cos(a) * r, 1), round(math.sin(a) * r, 1))


def landmark(z, fid, cfg):
    """Marco do pátio, um por fortaleza (o que se vê de longe)."""
    c = FORT_C
    acc = z.M["accent"]
    wall = z.M["fort_wall"]
    if fid == "fort_ghoul":                           # monte de carne com costelas e bolhas
        top = z.hill("monte", (c[0], c[1] - 10), 7, 2, rock="fort_wall", top="accent", step=1.6)
        for i in range(8):
            a = math.tau * i / 8
            p = (c[0] + math.cos(a) * 6.5, c[1] - 10 + math.sin(a) * 6.5)
            cyl(z.coll, z.P + "costela_%d" % i, p, 0.5, 0.15, 6.0, z.M["bone"], 0.0, 6)
    elif fid == "fort_bones":                         # torre negra com coroa de ossos
        cyl(z.coll, z.P + "torre", (c[0], c[1] - 10), 5.0, 4.2, 18.0, wall, 0.0, 10)
        for i in range(10):
            a = math.tau * i / 10
            p = (c[0] + math.cos(a) * 4.4, c[1] - 10 + math.sin(a) * 4.4)
            cyl(z.coll, z.P + "osso_%d" % i, p, 0.4, 0.05, 4.0 + (i % 2) * 2.0, z.M["bone"], 18.0, 6)
        z.ob("wall", c[0], c[1] - 10, (9.0, 18.0, 9.0), visible=False)
    elif fid == "fort_frost":                         # torre de gelo alta com cristal no topo
        cyl(z.coll, z.P + "torre", (c[0], c[1] - 10), 4.6, 3.4, 26.0, wall, 0.0, 10)
        cyl(z.coll, z.P + "cristal", (c[0], c[1] - 10), 2.6, 0.2, 7.0, acc, 26.0, 6)
        for i in range(6):
            a = math.tau * i / 6
            p = (c[0] + math.cos(a) * 12, c[1] + 4 + math.sin(a) * 12)
            cyl(z.coll, z.P + "pico_%d" % i, p, 1.0, 0.1, 5.0 + i % 3, acc, 0.0, 6)
        z.ob("wall", c[0], c[1] - 10, (8.5, 26.0, 8.5), visible=False)
    else:                                             # trono do Lich: plataforma, colunas e chama roxa
        cyl(z.coll, z.P + "trono_base", (c[0], c[1] - 12), 6.0, 5.4, 0.6, wall, 0.0, 16)
        for i in range(8):
            a = math.tau * i / 8
            p = (c[0] + math.cos(a) * 9, c[1] - 12 + math.sin(a) * 9)
            cyl(z.coll, z.P + "coluna_%d" % i, p, 0.8, 0.7, 9.0, wall, 0.0, 8)
            cyl(z.coll, z.P + "chama_%d" % i, p, 0.6, 0.05, 1.6, acc, 9.0, 6)
            z.ob("pillar", p[0], p[1], (1.6, 9.0, 1.6), visible=False)


def build_one(fid, export=False):
    cfg = FORTS[fid]
    z = Zone(fid, seed=cfg["seed"], palette={
        "road": (0.5, 0.46, 0.4), "street": (0.56, 0.52, 0.48), "cliff_rock": (0.44, 0.42, 0.42), "cliff_rock_d": (0.34, 0.32, 0.33),
        "cliff_grass": cfg["ground"], "hill_grass": cfg["ground"], "leaf": cfg["trees"][0], "bark": cfg["wall"],
        "town_wall": cfg["wall"], "fort_wall": cfg["wall"], "accent": cfg["accent"], "bone": (0.9, 0.87, 0.78),
        "water_dark": (0.26, 0.3, 0.36), "patio": cfg["patio"],
    })
    rnd = random.Random(cfg["seed"])
    q, after = cfg["quest"], cfg["after"]
    portal = polar(z, 90, 7)
    arrive = ARRIVE_IN_FORT
    z.data["spawn"] = list(arrive)
    z.portal("to_bastion", portal, "field_ruins", BACK[fid], "Bastião da Aurora")
    z.patch("chao", (0, 0), 110, cfg["ground"])
    c = FORT_C
    gate = math.radians(90.0)
    gate_pt = (c[0], c[1] + FORT_R)
    # ---------- estrada da chegada ao portão (curva), postos avançados nos lados ----------
    z.road("subida", [arrive, (-14, 70), (10, 40), (-6, 14), (gate_pt[0], gate_pt[1] + 2)], w=4.4)
    posts = [(-56.0, 36.0), (54.0, 26.0)]
    for i, (p, (mob, n)) in enumerate(zip(posts, cfg["posts"])):
        z.road("posto_%d" % i, [((-14, 70) if i == 0 else (10, 40)), p], w=3.2)
        disc(z.coll, z.P + "posto_chao_%d" % i, p, 8.0, 0.012, z.M["street"], 24)
        for k in range(6):                            # paliçada do posto (estacas em anel, abertura para a estrada)
            a = math.tau * k / 6 + 0.5
            z.ob("fence", p[0] + math.cos(a) * 7.0, p[1] + math.sin(a) * 7.0, (4.0, 1.4, 0.5), math.degrees(-a) + 90, color=cfg["wall"])
        z.ob("tent", p[0], p[1] - 2.0, (3.4, 2.4, 3.0), 0, color=cfg["wall"])
        z.spawner(mob, p[0], p[1], 5, n, 22.0, when={"unless": cfg["posts_quest"]})
        z.npc("%s_post_spearman_%d" % (fid, i), p[0] + 2.0, p[1] + 3.0, 180.0)
        z.npc("%s_post_crossbow_%d" % (fid, i), p[0] - 2.0, p[1] + 3.0, 180.0)
        z.block(p, 9.0)
    # ---------- fortaleza: muralha com torres, portão ao sul, pátio ----------
    disc(z.coll, z.P + "patio", c, FORT_R - 1.0, 0.012, z.M["patio"], 48)
    z.ring_wall("fortaleza", c, FORT_R, [gate], gate_half=4.0, height=5.0, thick=2.0, material="fort_wall", towers=6)
    z.data["town"] = {"center": list(c), "radius": FORT_R, "gates": [list(gate_pt)]}
    landmark(z, fid, cfg)
    for i in range(3):                                # jaulas dos prisioneiros (vivem até a fortaleza cair)
        p = (c[0] - 16 + i * 4.0, c[1] + 6)
        for k in range(4):
            a = math.tau * k / 4 + math.pi / 4
            z.ob("pillar", p[0] + math.cos(a) * 1.4, p[1] + math.sin(a) * 1.4, (0.3, 2.4, 0.3), color=(0.3, 0.28, 0.3))
    for i, nid in enumerate(["%s_prisoner_%d" % (fid, k) for k in range(3)]):
        z.npc(nid, c[0] - 16 + i * 4.0, c[1] + 6, 180.0)
    for k, (dx, dy) in enumerate([(14, 4), (17, 8), (11, 10)]):       # assentamento (depois da retomada)
        z.npc("%s_settler_%d" % (fid, k), c[0] + dx, c[1] + dy, 200.0)
    for i, role in enumerate(["knight", "knight", "spearman", "priest", "crossbow"]):
        z.npc("%s_g_%s_%d" % (fid, role, i), c[0] - 6 + i * 3.0, c[1] + FORT_R - 4.0, 180.0)
    z.spawner(cfg["boss"], c[0], c[1] - 2, 2, 1, 240.0 if fid != "lich_citadel" else 300.0, when={"unless": q} if fid != "lich_citadel" else None)
    for i, (mob, n, resp) in enumerate(cfg["inside"]):
        a = math.tau * i / len(cfg["inside"]) + 0.6
        z.spawner(mob, c[0] + math.cos(a) * 14, c[1] + math.sin(a) * 12, 6, n, resp, when={"unless": q} if fid != "lich_citadel" else None)
    for i, (mob, n, resp) in enumerate(cfg["outside"]):
        a = math.radians(-160 + i * 50)
        p = (round(math.cos(a) * 62, 1), round(math.sin(a) * 40 + 40, 1))
        z.spawner(mob, p[0], p[1], 9, n, resp, when={"unless": q} if fid != "lich_citadel" else None)
    if fid == "lich_citadel":                         # portões internos na subida: muralhas com vão na estrada
        for k, y in enumerate((62.0, 32.0)):
            for sx in (-1, 1):
                z.ob("wall", sx * 30.0, y, (44.0, 4.4, 2.0), 0, color=cfg["wall"])
            for sx in (-1, 1):
                z.ob("pillar", sx * 7.0, y, (2.4, 6.0, 2.4), color=cfg["wall"])
    # ---------- assalto aliado: sobe da chegada ao pátio enquanto a fortaleza não cai ----------
    if after:
        z.data["assaults"] = [{"id": "aurora", "from": [arrive[0], arrive[1] - 4.0], "route": [[-14, 70], [10, 40], [-6, 14], [gate_pt[0], gate_pt[1] + 2]],
                               "target": [c[0], c[1] + 4], "radius": 12.0}]
    z.data["hangouts"] = [[arrive[0] + dx, arrive[1] - 8] for dx in (-4, 0, 4)]
    # ---------- identidade do caminho: bile, ossos, cristais de gelo, chamas roxas ----------
    drnd = random.Random(cfg["seed"] + 11)
    for i in range(26):
        a = drnd.uniform(0, math.tau)
        r = drnd.uniform(24, 95)
        p = (round(math.cos(a) * r, 1), round(math.sin(a) * r * 0.9 + 10, 1))
        if math.hypot(p[0] - c[0], p[1] - c[1]) < FORT_R + 6 or math.hypot(p[0] - arrive[0], p[1] - arrive[1]) < 12 or not z.free(p[0], p[1], 3.0, 0.0):
            continue
        if fid == "fort_ghoul":
            disc(z.coll, z.P + "bile_%d" % i, p, drnd.uniform(1.8, 3.4), 0.02, z.M["accent"], 14, 0.3, i)
        elif fid == "fort_bones":
            for k in range(3):
                cyl(z.coll, z.P + "ossada_%d_%d" % (i, k), (p[0] + k * 0.6, p[1] + (k % 2) * 0.5), 0.35, 0.08, 1.2 + k * 0.5, z.M["bone"], 0.0, 6)
        elif fid == "fort_frost":
            cyl(z.coll, z.P + "gelo_%d" % i, p, drnd.uniform(0.7, 1.3), 0.08, drnd.uniform(2.5, 5.0), z.M["accent"], 0.0, 6)
            z.ob("rock", p[0], p[1], (1.6, 2.0, 1.6), visible=False)
        else:
            cyl(z.coll, z.P + "brasa_base_%d" % i, p, 0.6, 0.5, 0.8, z.M["fort_wall"], 0.0, 8)
            cyl(z.coll, z.P + "brasa_%d" % i, p, 0.45, 0.04, 1.6, z.M["accent"], 0.8, 6)
            z.ob("rock", p[0], p[1], (1.2, 1.0, 1.2), visible=False)
    z.cliffs(snow=(fid == "fort_frost"))
    z.block((0, 0), 6)
    z.block(c, FORT_R + 4)
    z.block(arrive, 8)
    z.scatter("tree", [((0, 0), 110, 70)], 0, (1.5, 3.3, 1.5), cfg["trees"], margin=4.6, spacing=4.5, scale=(0.8, 1.2))
    z.rim_belt(110, (1.5, 3.3, 1.5), cfg["trees"])
    z.scatter("rock", [((0, 0), 105, 40)], 0, (1.4, 0.9, 1.2), [(0.5, 0.48, 0.48)], margin=3.5, spacing=3.0, scale=(0.7, 1.6))
    z.scatter("ruin", [((0, 0), 100, 20)], 0, (2.4, 1.6, 0.7), [cfg["wall"]], margin=4.0, spacing=5.0, scale=(0.7, 1.5))
    nrnd = random.Random(cfg["seed"] + 5)
    obs = z.data["obstacles"]
    fr = lambda x, zz, m: z.free(x, zz, m, 0.0)
    nature.fix_trees(obs, nrnd, dead=True, dead_cols=cfg["trees"])
    nature.woodland_floor(z.ob, fr, nrnd, [((0, 0), 100, 14)], bark=[(0.42, 0.38, 0.33), (0.36, 0.33, 0.3)], avoid=obs)
    return z.finish(export, poi=c, ground=cfg["ground"])


def build(export=False, only=None):
    out = []
    for fid in FORTS:
        if only and fid not in only:
            continue
        out.append(build_one(fid, export))
    return out
