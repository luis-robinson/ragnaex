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
from zone_lib import Zone, cyl, box, disc, blob, cone, B, _obj
import bmesh

FORT_C = (0.0, -30.0)
FORT_R = 28.0
ARRIVE_IN_FORT = (0.0, 96.0)          # chegada em todo mapa de fortaleza (o Bastião aponta para cá)

FORTS = {
    "fort_ghoul": {
        "name": "Covil do Carniçal", "seed": 31, "quest": "dw_ghoul_boss", "posts_quest": "dw_ghoul_posts", "after": None, "boss": "ghoul_giant",
        "ground": (0.4, 0.38, 0.24), "wall": (0.38, 0.3, 0.22), "wall_mat": "bark", "accent": (0.45, 0.68, 0.22), "patio": (0.32, 0.27, 0.18), "road": (0.36, 0.5, 0.16),
        "trees": [(0.36, 0.34, 0.26), (0.42, 0.38, 0.28)],
        "outside": [("larva", 14, 12.0), ("rot_zombie", 9, 16.0), ("rot_wolf", 5, 18.0), ("rot_bear", 3, 26.0), ("rot_ghoul", 6, 18.0), ("larva", 12, 12.0)],
        "inside": [("rot_ghoul", 6, 20.0), ("larva", 10, 12.0), ("rot_zombie", 6, 16.0)],
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
    if fid == "fort_ghoul":                           # monte de carne com costelas e bolhas; poço de podridão borbulhando
        disc(z.coll, z.P + "poco_podre", (c[0] + 12, c[1] - 4), 4.0, 0.03, z.M["accent"], 18, 0.4, 3)
        for k in range(6):
            a = math.tau * k / 6
            cyl(z.coll, z.P + "poco_bolha_%d" % k, (c[0] + 12 + math.cos(a) * 2.0, c[1] - 4 + math.sin(a) * 2.0), 0.5, 0.2, 0.6, z.M["accent"], 0.0, 6)
        z.ob("rock", c[0] + 12, c[1] - 4, (7.0, 1.0, 7.0), visible=False)
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
    if fid == "fort_ghoul":
        return build_ghoul(export)
    if fid == "fort_bones":
        return build_bones(export)
    if fid == "fort_frost":
        return build_frost(export)
    if fid == "lich_citadel":
        return build_citadel(export)
    cfg = FORTS[fid]
    z = Zone(fid, seed=cfg["seed"], palette={
        "road": cfg.get("road", (0.5, 0.46, 0.4)), "street": (0.56, 0.52, 0.48), "cliff_rock": (0.44, 0.42, 0.42), "cliff_rock_d": (0.34, 0.32, 0.33),
        "cliff_grass": cfg["ground"], "hill_grass": cfg["ground"], "leaf": cfg["trees"][0], "bark": cfg["wall"],
        "town_wall": cfg["wall"], "fort_wall": cfg["wall"], "accent": cfg["accent"], "bone": (0.9, 0.87, 0.78),
        "water_dark": (0.26, 0.3, 0.36), "patio": cfg["patio"], "flesh": (0.66, 0.5, 0.42), "fly": (0.12, 0.12, 0.08), "toxic": (0.5, 0.25, 0.55), "garden": (0.26, 0.34, 0.1),
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
    z.spawner(cfg["boss"], c[0], c[1] - 2, 2, 1, 120.0 if fid != "lich_citadel" else 300.0, when={"unless": q} if fid != "lich_citadel" else None)
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
    if fid == "fort_ghoul":                           # jardins venenosos: canteiros de cogumelos e flores doentes ao longo da estrada
        grnd = random.Random(77)
        for g, gc in enumerate([(-44, 62), (40, 62), (-58, 12), (34, 4), (-36, 88), (38, 84), (-74, 44), (72, 40)]):
            if not z.free(gc[0], gc[1], 2.0, 0.0):
                continue
            disc(z.coll, z.P + "jardim_%d" % g, gc, 6.0, 0.014, z.M["garden"], 20, 0.25, g)
            for k in range(10):
                q = (gc[0] + grnd.uniform(-4.5, 4.5), gc[1] + grnd.uniform(-4.5, 4.5))
                z.ob("flowers", q[0], q[1], (1.6, 0.6, 1.6), solid=False, color=[(0.62, 0.78, 0.2), (0.55, 0.3, 0.55), (0.8, 0.72, 0.25)][k % 3])
            for k in range(5):
                q = (gc[0] + grnd.uniform(-4, 4), gc[1] + grnd.uniform(-4, 4))
                cyl(z.coll, z.P + "cogumelo_pe_%d_%d" % (g, k), q, 0.18, 0.16, 0.8, z.M["bone"], 0.0, 6)
                cyl(z.coll, z.P + "cogumelo_chapeu_%d_%d" % (g, k), q, 0.7, 0.1, 0.45, z.M["accent"] if k % 2 else z.M["toxic"], 0.8, 8)
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
            if i % 3 == 0:                            # monte de pústulas que borbulha
                for k in range(4):
                    cyl(z.coll, z.P + "pustula_%d_%d" % (i, k), (p[0] + (k - 1.5) * 0.9, p[1] + (k % 2) * 0.8), 0.7 - k * 0.1, 0.25, 1.0 + k * 0.3, z.M["flesh"], 0.0, 7)
                z.ob("rock", p[0], p[1], (3.2, 1.6, 2.6), visible=False)
            if i % 2 == 0:                            # enxame de moscas pairando
                for k in range(9):
                    box(z.coll, z.P + "mosca_%d_%d" % (i, k), (p[0] + drnd.uniform(-1.6, 1.6), p[1] + drnd.uniform(-1.6, 1.6)), (0.16, 0.12, 0.16), drnd.uniform(0, 90), z.M["fly"], drnd.uniform(1.6, 3.2))
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



# ======================================================================================================
# Covil do Carniçal: pântano-ninho (layout próprio, sem o molde de muralha das outras fortalezas)
# ======================================================================================================
GHOUL_RIVER = [(-130, 40), (-92, 30), (-62, 44), (-30, 36), (0, 46), (30, 34), (62, 46), (92, 30), (130, 38)]
GHOUL_LAKES = [("lagoa_meio", (0, 66), 10.0), ("lagoa_oeste", (-92, 4), 9.0), ("lagoa_leste", (80, 66), 8.0),
               ("lagoa_no", (-56, -38), 8.5), ("lagoa_ne", (54, -50), 7.5), ("lagoa_sul", (-66, 86), 6.5)]
GHOUL_NESTS = [(-60, 60), (58, 12)]              # ninhos (os "postos" da quest dw_ghoul_posts)
GHOUL_W = [(0, 92), (-20, 82), (-42, 70), (-50, 56), (-48, 26), (-38, 10), (-18, 2), (0, 0)]
GHOUL_E = [(0, 92), (18, 80), (30, 62), (40, 44), (46, 24), (36, 8), (16, 2), (0, 0)]


def rib(coll, name, base, out_ang, height, curl, r0, r1, material, steps=7, sides=7):
    """Costela: tubo afinando que sobe da base e se curva para dentro (direção oposta a out_ang)."""
    bm = bmesh.new()
    rings = []
    dx, dz = -math.cos(out_ang), -math.sin(out_ang)          # para dentro
    for k in range(steps + 1):
        t = k / steps
        h = height * math.sin(t * math.pi / 2)
        inn = curl * (1.0 - math.cos(t * math.pi / 2))
        cx, cz = base[0] + dx * inn, base[1] + dz * inn
        r = r0 + (r1 - r0) * t
        # direção do tubo nesse ponto (para orientar o anel)
        ty = math.cos(t * math.pi / 2) * height
        th = math.sin(t * math.pi / 2) * curl
        L = math.hypot(ty, th) or 1.0
        ty, th = ty / L, th / L
        ring = []
        for j in range(sides):
            a = math.tau * j / sides
            side = math.cos(a) * r                             # ao longo do anel (tangente da caixa torácica)
            nrm = math.sin(a) * r                              # no plano (vertical, para dentro)
            px = cx + (-dz) * side + dx * (nrm * ty)
            pz = cz + dx * side + dz * (nrm * ty)
            py = h - nrm * th
            ring.append(bm.verts.new(B(px, pz, py)))
        rings.append(ring)
    for k in range(steps):
        for j in range(sides):
            bm.faces.new((rings[k][j], rings[k][(j + 1) % sides], rings[k + 1][(j + 1) % sides], rings[k + 1][j]))
    bm.faces.new(rings[-1])
    bm.normal_update()
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    return _obj(coll, name, bm, material)


def ghoul_nest(z, i, p, face_deg, cfg):
    """Ninho de carcaça: estacas de osso em anel (aberto para a trilha), monte de carne, ovos, poça de bile."""
    z.patch("ninho_%d" % i, p, 9.0, (0.2, 0.15, 0.1))
    disc(z.coll, z.P + "ninho_bile_%d" % i, (p[0] + 3.0, p[1] - 2.5), 2.4, 0.025, z.M["bile"], 16, 0.3, 50 + i)
    face = math.radians(face_deg)
    for k in range(14):
        a = math.tau * k / 14
        if abs((a - face + math.pi) % math.tau - math.pi) < 0.55:
            continue                                   # abertura para a trilha
        q = (p[0] + math.cos(a) * 7.5, p[1] + math.sin(a) * 7.5)
        h = 2.6 + (k % 3) * 0.9
        rib(z.coll, z.P + "ninho_estaca_%d_%d" % (i, k), q, a + math.pi, h, 1.2 + (k % 2) * 0.8, 0.38, 0.08, z.M["bone"], 5, 6)
        z.ob("pillar", q[0], q[1], (0.9, h, 0.9), visible=False)
    for k in range(5):                                  # monte de carne (onde dormem os da ninhada)
        a = math.tau * k / 5 + i
        blob(z.coll, z.P + "ninho_carne_%d_%d" % (i, k), (p[0] - 2.0 + math.cos(a) * 1.6, p[1] + 1.0 + math.sin(a) * 1.6), 1.6 - k * 0.12, 0.6, z.M["flesh"], 60 + k, 0.7)
    z.ob("rock", p[0] - 2.0, p[1] + 1.0, (4.6, 1.8, 4.6), visible=False)
    for k in range(6):                                  # ovos da larva
        a = math.tau * k / 6 + 0.3
        blob(z.coll, z.P + "ninho_ovo_%d_%d" % (i, k), (p[0] + 2.4 + math.cos(a) * 1.2, p[1] + 2.8 + math.sin(a) * 1.0), 0.55, 0.45, z.M["egg"], 70 + k, 1.1)


def ghoul_ribcage(z, c, R, gate):
    """O covil é o cadáver do bicho: costelas colossais em anel (colisão entre elas), brecha ao sul, crânio ao norte."""
    n = 30
    for i in range(n):
        a = math.tau * (i + 0.5) / n
        if abs((a - gate + math.pi) % math.tau - math.pi) * R < 7.0:
            continue
        p = (c[0] + math.cos(a) * R, c[1] + math.sin(a) * R)
        north = -math.sin(a)                            # -z = norte: costelas maiores perto do crânio
        h = 9.0 + 5.0 * max(0.0, north)
        rib(z.coll, z.P + "costela_%d" % i, p, a, h, 5.5 + 2.0 * max(0.0, north), 1.15, 0.3, z.M["bone"], 8, 8)
        # membrana de carne seca entre as costelas (lê como muro de cima)
        seg = math.tau * R / n + 0.2
        rot = zone_lib.along(-math.sin(a + math.pi / n), math.cos(a + math.pi / n))
        q = (c[0] + math.cos(a + math.pi / n) * R, c[1] + math.sin(a + math.pi / n) * R)
        if abs((a + math.pi / n - gate + math.pi) % math.tau - math.pi) * R >= 7.0:
            for k in (-1, 0, 1):                      # carne seca entre as costelas (lê como muro de cima)
                bq = (q[0] - math.sin(a) * k * 1.6, q[1] + math.cos(a) * k * 1.6)
                blob(z.coll, z.P + "membrana_%d_%d" % (i, k), bq, 1.5 + 0.3 * ((i + k) % 2), 0.2, z.M["hide"] if k else z.M["flesh"], i * 3 + k, 0.65)
        z.ob("wall", p[0], p[1], (seg, 4.0, 2.4), zone_lib.along(-math.sin(a), math.cos(a)), visible=False)
    z.block(c, R + 3)
    # coluna: vértebras do crânio para trás (fora do anel, ao norte)
    sk = (c[0], c[1] - R - 9.0)
    for k in range(7):
        v = (c[0] + math.sin(k * 0.7) * 2.0, c[1] - R - 20.0 - k * 4.4)
        cyl(z.coll, z.P + "vertebra_%d" % k, v, 2.2 - k * 0.15, 1.8 - k * 0.15, 2.2, z.M["bone"], 0.0, 9, 0.1, k)
        cone(z.coll, z.P + "vertebra_espinho_%d" % k, v, 0.9, 3.0 - k * 0.2, z.M["bone"], 2.2, 6)
        z.ob("rock", v[0], v[1], (4.2, 2.4, 4.2), visible=False)
    # crânio colossal (marco visível de toda a zona), olhando para o pátio
    blob(z.coll, z.P + "cranio", sk, 9.5, 4.5, z.M["bone"], 7, 0.75)
    blob(z.coll, z.P + "cranio_focinho", (sk[0], sk[1] + 8.0), 6.0, 2.6, z.M["bone"], 8, 0.6)
    for sx in (-1, 1):
        blob(z.coll, z.P + "cranio_orbita_%d" % sx, (sk[0] + sx * 4.0, sk[1] + 5.6), 2.4, 6.6, z.M["socket"], 20 + sx, 0.8)
        blob(z.coll, z.P + "cranio_olho_%d" % sx, (sk[0] + sx * 4.0, sk[1] + 6.4), 0.9, 7.6, z.M["toxic_glow"], 30 + sx, 1.0)
        cone(z.coll, z.P + "cranio_presa_%d" % sx, (sk[0] + sx * 2.6, sk[1] + 13.2), 0.8, 4.0, z.M["bone"], 0.0, 6)
        cone(z.coll, z.P + "cranio_chifre_%d" % sx, (sk[0] + sx * 7.5, sk[1] - 2.0), 1.6, 9.0, z.M["bone"], 6.0, 7)
    z.ob("rock", sk[0], sk[1], (19.0, 9.0, 19.0), visible=False)
    z.ob("rock", sk[0], sk[1] + 8.0, (12.0, 4.0, 8.0), visible=False)


def ghoul_mound(z, c):
    """Pátio do covil: monte de carne com costelinhas, poço de bile borbulhando, lama e ossos pelo chão."""
    m = (c[0], c[1] - 12)
    for k in range(9):                                  # monte: carne amontoada (blobs), mais alto no meio
        a = math.tau * k / 9
        rr = 0.0 if k == 0 else 4.2
        blob(z.coll, z.P + "monte_carne_%d" % k, (m[0] + math.cos(a) * rr, m[1] + math.sin(a) * rr), 4.6 if k == 0 else 2.8, 0.8 if k == 0 else 0.2,
             z.M["flesh"] if k % 2 == 0 else z.M["hide"], 80 + k, 0.7)
    for i in range(10):
        a = math.tau * i / 10 + 0.2
        p = (m[0] + math.cos(a) * 6.4, m[1] + math.sin(a) * 6.4)
        rib(z.coll, z.P + "monte_costela_%d" % i, p, a, 4.5 + (i % 3), 2.2, 0.5, 0.12, z.M["bone"], 6, 6)
    z.ob("hill", m[0], m[1], (13.0, 3.6, 13.0), visible=False)
    w = (c[0] + 13, c[1] - 6)
    disc(z.coll, z.P + "poco_borda", w, 5.0, 0.02, z.M["hide"], 20, 0.3, 4)
    disc(z.coll, z.P + "poco_bile", w, 3.8, 0.04, z.M["bile"], 18, 0.25, 3)
    for k in range(7):
        a = math.tau * k / 7
        blob(z.coll, z.P + "poco_bolha_%d" % k, (w[0] + math.cos(a) * 1.9, w[1] + math.sin(a) * 1.9), 0.45 + 0.15 * (k % 2), 0.05, z.M["toxic_glow"], 90 + k, 0.7)
    z.ob("rock", w[0], w[1], (7.0, 1.0, 7.0), visible=False)
    prnd = random.Random(19)
    for k in range(8):                                   # lama e poças pelo pátio
        a, r = prnd.uniform(0, math.tau), prnd.uniform(8, 22)
        q = (c[0] + math.cos(a) * r, c[1] + math.sin(a) * r * 0.9)
        z.patch("patio_lama_%d" % k, q, prnd.uniform(2.5, 4.5), (0.17, 0.13, 0.08))
        if k % 3 == 0:
            disc(z.coll, z.P + "patio_bile_%d" % k, q, 1.4, 0.022, z.M["bile"], 12, 0.3, 110 + k)


def build_ghoul(export=False):
    fid = "fort_ghoul"
    cfg = FORTS[fid]
    z = Zone(fid, seed=cfg["seed"], palette={
        "road": (0.34, 0.3, 0.2), "street": (0.4, 0.36, 0.26), "cliff_rock": (0.36, 0.34, 0.3), "cliff_rock_d": (0.27, 0.26, 0.23),
        "cliff_grass": (0.3, 0.34, 0.18), "hill_grass": (0.42, 0.24, 0.2), "leaf": (0.32, 0.36, 0.2), "bark": (0.3, 0.26, 0.2),
        "wood": (0.6, 0.54, 0.42), "water": (0.12, 0.2, 0.02), "bile": (0.4, 0.42, 0.08), "fort_wall": (0.34, 0.2, 0.17), "accent": (0.42, 0.6, 0.12),
        "bone": (0.72, 0.66, 0.52), "flesh": (0.46, 0.22, 0.2), "hide": (0.32, 0.19, 0.16), "egg": (0.62, 0.7, 0.38), "socket": (0.08, 0.06, 0.05),
        "mud": (0.27, 0.24, 0.15), "fly": (0.1, 0.1, 0.07), "toxic": (0.5, 0.25, 0.55), "toxic_glow": (0.75, 1.0, 0.25),
        "patio": (0.27, 0.21, 0.15),
    })
    q = cfg["quest"]
    gone = {"unless": q}
    arrive = ARRIVE_IN_FORT
    z.data["spawn"] = list(arrive)
    portal = polar(z, 90, 7)
    z.portal("to_bastion", portal, "field_ruins", BACK[fid], "Bastião da Aurora")
    c, R = FORT_C, FORT_R
    gate = math.radians(90.0)
    gate_pt = (c[0], c[1] + R)
    # ---------- chão do pântano: manchas de lama e musgo (lê de cima) ----------
    z.patch("charco", (0, 10), 112, (0.33, 0.33, 0.2), grass=True)
    mrnd = random.Random(91)
    for k in range(22):
        a, r = mrnd.uniform(0, math.tau), mrnd.uniform(10, 100)
        pc = (math.cos(a) * r, math.sin(a) * r)
        if k % 2:
            z.patch("lama_%d" % k, pc, mrnd.uniform(7, 14), (0.21, 0.18, 0.11))
        else:
            z.patch("musgo_%d" % k, pc, mrnd.uniform(8, 16), (0.25, 0.31, 0.12), grass=True)
    # ---------- rio de bile e lagoas (pontes de osso onde as trilhas cruzam) ----------
    z.river(GHOUL_RIVER, w=7.5, material="bile")
    for name, pc, r in GHOUL_LAKES:
        z.lake(name, pc, r, material="bile")
        lr = random.Random(len(name))                  # lóbulos: lagoa de borda torta, não um círculo
        for k in range(2):
            a = lr.uniform(0, math.tau)
            z.lake("%s_%d" % (name, k), (round(pc[0] + math.cos(a) * r * 0.7, 1), round(pc[1] + math.sin(a) * r * 0.7, 1)), round(r * lr.uniform(0.5, 0.7), 1), material="bile")
    # ---------- duas trilhas de lama que contornam a lagoa do meio e se juntam na brecha do covil ----------
    z.road("trilha_oeste", GHOUL_W, w=4.4)
    z.road("trilha_leste", GHOUL_E, w=4.4)
    z.road("vau", [(-50, 56), (-26, 60), (-12, 76), (0, 82)], w=2.6, end_clearing=False)      # atalho estreito pela margem da lagoa
    z.bridges()
    # ---------- ninhos (postos avançados da quest) ----------
    for i, (p, (mob, n)) in enumerate(zip(GHOUL_NESTS, cfg["posts"])):
        road_pt = (-50, 56) if i == 0 else (46, 24)
        face = math.degrees(math.atan2(road_pt[1] - p[1], road_pt[0] - p[0]))
        ghoul_nest(z, i, p, face, cfg)
        z.spawner(mob, p[0], p[1], 5, n, 22.0, when={"unless": cfg["posts_quest"]})
        z.npc("%s_post_spearman_%d" % (fid, i), p[0] + 2.0, p[1] + 3.0, 180.0)
        z.npc("%s_post_crossbow_%d" % (fid, i), p[0] - 2.0, p[1] + 3.0, 180.0)
        z.block(p, 10.0)
    # ---------- o covil: caixa torácica do bicho morto ----------
    z.patch("patio", c, R - 1.0, (0.38, 0.29, 0.2))
    ghoul_ribcage(z, c, R, gate)
    z.data["town"] = {"center": list(c), "radius": R, "gates": [list(gate_pt)]}
    ghoul_mound(z, c)                                  # monte de carne + poço de bile (onde o chefe dorme)
    for i in range(3):                                  # jaulas: gaiolas de costelinhas
        p = (c[0] - 16 + i * 4.0, c[1] + 6)
        for k in range(5):
            a = math.tau * k / 5
            rib(z.coll, z.P + "jaula_%d_%d" % (i, k), (p[0] + math.cos(a) * 1.4, p[1] + math.sin(a) * 1.4), a, 2.6, 1.0, 0.16, 0.06, z.M["bone"], 4, 5)
            z.ob("pillar", p[0] + math.cos(a) * 1.4, p[1] + math.sin(a) * 1.4, (0.3, 2.4, 0.3), visible=False)
    for i, nid in enumerate(["%s_prisoner_%d" % (fid, k) for k in range(3)]):
        z.npc(nid, c[0] - 16 + i * 4.0, c[1] + 6, 180.0)
    for k, (dx, dy) in enumerate([(14, 4), (17, 8), (11, 10)]):       # assentamento (depois da retomada)
        z.npc("%s_settler_%d" % (fid, k), c[0] + dx, c[1] + dy, 200.0)
    for k, (dx, dy) in enumerate([(19, 2), (8, 14), (20, 12)]):       # barracas da Aurora (só depois da retomada)
        z.ob("tent", c[0] + dx, c[1] + dy, (3.4, 2.4, 3.0), 200.0, color=(0.82, 0.78, 0.66), when={"if": q})
    for i, role in enumerate(["knight", "knight", "spearman", "priest", "crossbow"]):
        z.npc("%s_g_%s_%d" % (fid, role, i), c[0] - 6 + i * 3.0, c[1] + R - 4.0, 180.0)
    z.spawner(cfg["boss"], c[0], c[1] - 2, 2, 1, 120.0, when=gone)
    for i, (mob, n, resp) in enumerate(cfg["inside"]):
        a = math.tau * i / len(cfg["inside"]) + 0.6
        z.spawner(mob, c[0] + math.cos(a) * 14, c[1] + math.sin(a) * 12, 6, n, resp, when=gone)
    # ninhada espalhada pelo charco (fora das trilhas, das lagoas e do rio)
    out_pts = [(-82, 70), (24, 16), (-74, -14), (80, -10), (-22, 20), (46, 86)]
    for (mob, n, resp), p in zip(cfg["outside"], out_pts):
        z.spawner(mob, p[0], p[1], 9, n, resp, when=gone)
    z.data["hangouts"] = [[arrive[0] + dx, arrive[1] - 8] for dx in (-4, 0, 4)]
    # ---------- casulos pendurados em árvores mortas, pústulas, moscas, ossadas ----------
    drnd = random.Random(cfg["seed"] + 11)
    for i in range(40):
        a = drnd.uniform(0, math.tau)
        r = drnd.uniform(20, 100)
        p = (round(math.cos(a) * r, 1), round(math.sin(a) * r * 0.95 + 8, 1))
        if math.hypot(p[0] - c[0], p[1] - c[1]) < R + 6 or math.hypot(p[0] - arrive[0], p[1] - arrive[1]) < 12 or not z.free(p[0], p[1], 3.5, 0.0):
            continue
        kind = i % 4
        if kind == 0:                                   # monte de pústulas que borbulha
            for k in range(4):
                cyl(z.coll, z.P + "pustula_%d_%d" % (i, k), (p[0] + (k - 1.5) * 0.9, p[1] + (k % 2) * 0.8), 0.7 - k * 0.1, 0.25, 1.0 + k * 0.3, z.M["flesh"], 0.0, 7)
            z.ob("rock", p[0], p[1], (3.2, 1.6, 2.6), visible=False)
        elif kind == 1:                                 # ninho de ovos de larva
            for k in range(5):
                blob(z.coll, z.P + "ovos_%d_%d" % (i, k), (p[0] + drnd.uniform(-1.4, 1.4), p[1] + drnd.uniform(-1.4, 1.4)), drnd.uniform(0.45, 0.7), 0.35, z.M["egg"], i * 10 + k, 1.1)
        elif kind == 2:                                 # ossada de bicho grande (costelas saindo da lama)
            ang = drnd.uniform(0, math.tau)
            for k in range(5):
                bp = (p[0] + math.cos(ang) * (k - 2) * 1.3, p[1] + math.sin(ang) * (k - 2) * 1.3)
                for sx in (-1, 1):
                    rib(z.coll, z.P + "ossada_%d_%d_%d" % (i, k, sx), (bp[0] + math.cos(ang + math.pi / 2) * sx * 1.6, bp[1] + math.sin(ang + math.pi / 2) * sx * 1.6),
                        ang + math.pi / 2 * sx, 2.4 - abs(k - 2) * 0.4, 1.2, 0.22, 0.06, z.M["bone"], 4, 5)
            z.ob("rock", p[0], p[1], (5.0, 1.6, 4.0), math.degrees(-ang), visible=False)
        else:                                           # poça de bile com enxame de moscas
            disc(z.coll, z.P + "bile_%d" % i, p, drnd.uniform(1.8, 3.2), 0.022, z.M["bile"], 14, 0.3, i)
            for k in range(9):
                box(z.coll, z.P + "mosca_%d_%d" % (i, k), (p[0] + drnd.uniform(-1.6, 1.6), p[1] + drnd.uniform(-1.6, 1.6)), (0.16, 0.12, 0.16), drnd.uniform(0, 90), z.M["fly"], drnd.uniform(1.6, 3.2))
    z.cliffs(rock="cliff_rock", top="cliff_grass", snow=False)
    z.block((0, 0), 6)
    z.block(arrive, 9)
    z.scatter("tree", [((-80, 40), 30, 26), ((80, 30), 30, 24), ((-60, -70), 26, 14), ((60, -70), 26, 14), ((0, 100), 40, 10)],
              0, (1.5, 3.3, 1.5), [(0.32, 0.3, 0.22), (0.38, 0.34, 0.26)], margin=4.6, spacing=4.2, scale=(0.8, 1.3))
    z.rim_belt(110, (1.5, 3.3, 1.5), [(0.32, 0.3, 0.22), (0.38, 0.34, 0.26)])
    z.scatter("rock", [((0, 0), 105, 30)], 0, (1.4, 0.9, 1.2), [(0.4, 0.38, 0.32)], margin=3.5, spacing=3.0, scale=(0.7, 1.5))
    lakes_all = [(tuple(w["pos"]), w["r"]) for w in z.data["water"] if w["kind"] == "lake"]
    nrnd = random.Random(cfg["seed"] + 5)
    obs = z.data["obstacles"]
    fr = lambda x, zz, m: z.free(x, zz, m, 0.0)
    nature.fix_trees(obs, nrnd, dead=True, dead_cols=[(0.32, 0.3, 0.22), (0.38, 0.34, 0.26)])
    nature.shore(z.ob, nrnd, z.rivers, lakes_all, list(z.road_polys.values()), 7.5,
                 colors=[(0.4, 0.46, 0.18), (0.48, 0.42, 0.2)])
    nature.clear_banks(obs, z.rivers, lakes_all, 7.5)
    nature.woodland_floor(z.ob, fr, nrnd, [((0, 0), 100, 18)], bark=[(0.34, 0.3, 0.24), (0.3, 0.27, 0.22)], avoid=obs)
    return z.finish(export, poi=c, ground=(0.33, 0.33, 0.2))



# ======================================================================================================
# Fortaleza dos Ossos: necrópole na colina. Fenda funda corta o vale (só a ponte de ossos e a passarela da cripta
# atravessam), túmulos e mausoléus na encosta, muros de ossuário com crânios ao longo da estrada em zigue-zague,
# dois patamares de pedra em volta da torre negra (a estrada dá a volta entre eles até o portão).
# ======================================================================================================
BONES_CHASM = [(-130, 44), (-96, 36), (-64, 46), (-30, 38), (0, 44), (32, 36), (64, 46), (96, 38), (130, 44)]
BONES_ROAD = [(0, 92), (-26, 82), (18, 68), (-10, 56), (-4, 40), (-22, 24), (-36, 12), (-34, 2), (-18, -2), (-6, 0), (0, -1)]
BONES_CRYPT_PATH = [(18, 68), (40, 56), (46, 40), (50, 24), (54, 14)]
BONES_CRYPTS = [(-56, 64), (58, 10)]


def skull(z, name, p, r, y, mats):
    """Crânio pequeno (bola de osso com duas órbitas escuras na frente, para o sul)."""
    blob(z.coll, z.P + name, p, r, y + r * 0.8, mats["bone"], len(name), 0.9)
    for sx in (-1, 1):
        disc(z.coll, z.P + name + "_o%d" % sx, (p[0] + sx * r * 0.38, p[1] + r * 0.82), r * 0.26, y + r * 0.95, mats["socket"], 8)


def ossuary_wall(z, name, a, b, h=1.6):
    """Muro baixo de pedra escura coroado de crânios, de a até b (colisão de muro)."""
    ax, az = a
    bx, bz = b
    L = math.hypot(bx - ax, bz - az)
    rot = zone_lib.along(bx - ax, bz - az)
    mid = ((ax + bx) / 2, (az + bz) / 2)
    box(z.coll, z.P + name + "_base", mid, (L, h, 1.2), rot, z.M["tomb"], 0.0)
    n = max(2, int(L / 1.1))
    for k in range(n):
        t = (k + 0.5) / n
        skull(z, name + "_c%d" % k, (ax + (bx - ax) * t, az + (bz - az) * t), 0.42, h, z.M)
    z.ob("wall", mid[0], mid[1], (L, h + 0.6, 1.6), rot, visible=False)


def tomb_row(z, name, start, step, n, rnd):
    """Fileira de lápides e sarcófagos (colisão pequena em cada)."""
    for k in range(n):
        p = (start[0] + step[0] * k, start[1] + step[1] * k)
        if not z.free(p[0], p[1], 2.5, 0.0):
            continue
        if k % 3 == 2:                                  # sarcófago deitado com tampa
            box(z.coll, z.P + "%s_sarc_%d" % (name, k), p, (1.2, 0.7, 2.4), 0.0, z.M["tomb"], 0.0)
            box(z.coll, z.P + "%s_tampa_%d" % (name, k), p, (1.4, 0.18, 2.6), 0.0, z.M["tomb_l"], 0.7)
            z.ob("rock", p[0], p[1], (1.4, 0.9, 2.6), visible=False)
        else:                                           # lápide de pé, alguma torta, com cruz/arco no topo
            tilt = rnd.uniform(-12, 12)
            h = 1.6 + rnd.uniform(0, 0.6)
            box(z.coll, z.P + "%s_lap_%d" % (name, k), p, (1.3, h, 0.4), tilt, z.M["tomb_l"], 0.0)
            cyl(z.coll, z.P + "%s_lapt_%d" % (name, k), p, 0.65, 0.65, 0.4, z.M["tomb_l"], h, 8)
            disc(z.coll, z.P + "%s_cova_%d" % (name, k), (p[0], p[1] + 1.4), 0.9, 0.02, z.M["grave"], 8, 0.2, k)     # terra da cova
            z.ob("rock", p[0], p[1], (1.4, h, 0.7), visible=False)


def mausoleum(z, name, p, face):
    """Mausoléu: caixa de pedra, telhado em cunha, colunas e porta escura virada para `face` (graus do jogo)."""
    box(z.coll, z.P + name, p, (5.0, 3.6, 4.4), face, z.M["tomb"], 0.0)
    cone(z.coll, z.P + name + "_teto", p, 3.8, 2.4, z.M["roof_d"], 3.6, 4)
    a = math.radians(face)
    fx, fz = math.sin(a), math.cos(a)                     # frente (rot Y do jogo -> eixo z local)
    door = (p[0] + fx * 2.25, p[1] + fz * 2.25)
    box(z.coll, z.P + name + "_porta", door, (1.6, 2.4, 0.12), face, z.M["socket"], 0.0)
    for sx in (-1, 1):
        q = (door[0] + fz * sx * 1.6, door[1] - fx * sx * 1.6)
        cyl(z.coll, z.P + name + "_col%d" % sx, q, 0.3, 0.26, 3.4, z.M["tomb_l"], 0.0, 8)
    skull(z, name + "_cranio", (door[0], door[1]), 0.5, 2.6, z.M)
    z.ob("wall", p[0], p[1], (5.4, 3.6, 4.8), face, visible=False)


def crypt(z, i, p, face):
    """Cripta aberta (posto): entrada de pedra com escada descendo para o escuro, pilares, ossada e velas."""
    z.patch("cripta_%d" % i, p, 9.0, (0.3, 0.28, 0.3))
    a = math.radians(face)
    fx, fz = math.sin(a), math.cos(a)
    back = (p[0] - fx * 3.0, p[1] - fz * 3.0)
    box(z.coll, z.P + "cripta_%d_casa" % i, back, (6.0, 2.8, 3.4), face, z.M["tomb"], 0.0)
    cone(z.coll, z.P + "cripta_%d_teto" % i, back, 4.0, 1.6, z.M["roof_d"], 2.8, 4)
    disc(z.coll, z.P + "cripta_%d_poco" % i, (p[0] - fx * 0.8, p[1] - fz * 0.8), 1.6, 0.03, z.M["socket"], 12)
    for k in range(4):                                  # degraus descendo (faixas de pedra cada vez mais escuras)
        q = (p[0] - fx * (0.2 - k * 0.5), p[1] - fz * (0.2 - k * 0.5))
        box(z.coll, z.P + "cripta_%d_degrau_%d" % (i, k), q, (2.4, 0.06, 0.45), face, z.M["tomb_l"] if k % 2 else z.M["tomb"], 0.02)
    for sx in (-1, 1):
        q = (p[0] + fz * sx * 2.2 + fx * 0.6, p[1] - fx * sx * 2.2 + fz * 0.6)
        cyl(z.coll, z.P + "cripta_%d_pilar%d" % (i, sx), q, 0.42, 0.36, 3.2, z.M["tomb_l"], 0.0, 8)
        skull(z, "cripta_%d_cr%d" % (i, sx), q, 0.42, 3.2, z.M)
        cyl(z.coll, z.P + "cripta_%d_vela%d" % (i, sx), (q[0] + fx * 0.8, q[1] + fz * 0.8), 0.1, 0.1, 0.5, z.M["candle"], 0.0, 6)
        z.ob("pillar", q[0], q[1], (1.0, 3.2, 1.0), visible=False)
    z.ob("wall", back[0], back[1], (6.4, 2.8, 3.8), face, visible=False)


def build_bones(export=False):
    fid = "fort_bones"
    cfg = FORTS[fid]
    z = Zone(fid, seed=cfg["seed"], palette={
        "road": (0.42, 0.4, 0.42), "street": (0.46, 0.44, 0.46), "cliff_rock": (0.3, 0.29, 0.33), "cliff_rock_d": (0.22, 0.21, 0.25),
        "cliff_grass": (0.36, 0.36, 0.32), "hill_grass": (0.4, 0.38, 0.36), "leaf": (0.34, 0.32, 0.3), "bark": (0.3, 0.27, 0.26),
        "wood": (0.82, 0.78, 0.66), "chasm": (0.06, 0.04, 0.09), "fort_wall": cfg["wall"], "town_wall": cfg["wall"],
        "terrace": (0.24, 0.23, 0.27), "bone": (0.84, 0.8, 0.7), "socket": (0.05, 0.04, 0.06), "tomb": (0.28, 0.27, 0.3),
        "tomb_l": (0.5, 0.5, 0.52), "roof_d": (0.2, 0.18, 0.24), "grave": (0.24, 0.2, 0.18), "candle": (0.95, 0.88, 0.6), "accent": cfg["accent"],
    })
    q = cfg["quest"]
    gone = {"unless": q}
    arrive = ARRIVE_IN_FORT
    z.data["spawn"] = list(arrive)
    z.portal("to_bastion", polar(z, 90, 7), "field_ruins", BACK[fid], "Bastião da Aurora")
    c, R = FORT_C, FORT_R
    gate = math.radians(90.0)
    gate_pt = (c[0], c[1] + R)
    rnd = random.Random(cfg["seed"])
    # ---------- chão: terra cinza, manchas de grama morta e de cinza ----------
    z.patch("encosta", (0, 10), 112, (0.4, 0.39, 0.36), grass=True)
    for k in range(18):
        a, r = rnd.uniform(0, math.tau), rnd.uniform(10, 100)
        pc = (math.cos(a) * r, math.sin(a) * r)
        if k % 2:
            z.patch("cinza_%d" % k, pc, rnd.uniform(7, 13), (0.32, 0.31, 0.33))
        else:
            z.patch("morta_%d" % k, pc, rnd.uniform(8, 15), (0.42, 0.4, 0.3), grass=True)
    # ---------- a fenda: atravessa o vale de borda a borda; ponte de ossos onde a estrada e a trilha da cripta cruzam ----------
    z.river(BONES_CHASM, w=9.0, material="chasm")
    z.road("subida", BONES_ROAD, w=4.4)
    z.road("trilha_cripta", BONES_CRYPT_PATH, w=3.0)
    z.road("trilha_oeste", [(-26, 82), (-44, 72), (-52, 66)], w=2.8, end_clearing=False)
    z.bridges()
    for name, poly in z.road_polys.items():          # ponte de ossos: postes com crânio nas quatro pontas
        for i in range(1, len(poly) - 1):
            if zone_lib.poly_dist(poly[i], z.rivers[0]) < 0.9:
                t = (poly[min(i + 2, len(poly) - 1)] - poly[max(i - 2, 0)]).normalized()
                side = zone_lib.Vector((t.y, -t.x))
                for sa in (-1, 1):
                    for sb in (-1, 1):
                        bq = poly[i] + t * sa * 7.6 + side * sb * 2.9
                        cyl(z.coll, z.P + "ponte_poste_%s_%d_%d" % (name, sa, sb), (bq.x, bq.y), 0.3, 0.24, 2.4, z.M["bone"], 0.0, 8)
                        skull(z, "ponte_cranio_%s_%d_%d" % (name, sa, sb), (bq.x, bq.y), 0.48, 2.4, z.M)
                        z.ob("pillar", bq.x, bq.y, (0.7, 2.6, 0.7), visible=False)
                break
    # ---------- patamares em volta da torre: anel de fora com entrada a sudoeste, anel de dentro (muralha) com portão ao sul ----------
    z.patch("patio", c, R - 1.0, (0.3, 0.29, 0.33))
    z.patch("patamar", c, R + 9.0, (0.36, 0.35, 0.38))
    outer_gate = math.radians(130.0)
    z.ring_wall("patamar_fora", c, R + 10.0, [outer_gate], gate_half=4.0, height=1.5, thick=1.4, material="terrace")
    for k in range(40):                                # crânios na borda do patamar
        a = math.tau * (k + 0.5) / 40
        if zone_lib.angdiff(a, outer_gate) * (R + 10.0) < 5.0:
            continue
        skull(z, "patamar_cranio_%d" % k, (c[0] + math.cos(a) * (R + 10.0), c[1] + math.sin(a) * (R + 10.0)), 0.42, 1.5, z.M)
    z.ring_wall("fortaleza", c, R, [gate], gate_half=4.0, height=4.5, thick=2.0, material="fort_wall", towers=6)
    z.data["town"] = {"center": list(c), "radius": R, "gates": [list(gate_pt)]}
    landmark(z, fid, cfg)                              # torre negra com coroa de ossos
    # ---------- ossuário ao longo da estrada (perto da ponte) e túmulos na encosta ----------
    for k, (a, b) in enumerate([((-14, 60), (-24, 64)), ((4, 52), (14, 56)), ((-14, 30), (-28, 32)), ((8, 28), (18, 22))]):
        ossuary_wall(z, "ossuario_%d" % k, a, b)
    # campos de túmulos: fileiras paralelas na encosta (o que se lê de cima é o cemitério inteiro)
    for f, (corner, cols_n, rows_n) in enumerate([((-82, 90), 7, 3), ((30, 92), 7, 3), ((-90, 28), 4, 4), ((66, 62), 4, 3),
                                                 ((-66, -40), 5, 3), ((38, -48), 5, 3), ((70, 22), 3, 4), ((-46, 32), 3, 2)]):
        for rw in range(rows_n):
            tomb_row(z, "campo_%d_%d" % (f, rw), (corner[0], corner[1] - rw * 4.0), (3.6, 0.0), cols_n, rnd)
    for k, (p, face) in enumerate([((-78, 50), 90.0), ((78, 64), -90.0), ((-74, -8), 60.0), ((72, -14), -70.0)]):
        mausoleum(z, "mausoleu_%d" % k, p, face)
    # ---------- criptas (postos) ----------
    for i, (p, (mob, n)) in enumerate(zip(BONES_CRYPTS, cfg["posts"])):
        road_pt = (-52, 66) if i == 0 else (54, 14)
        face = math.degrees(math.atan2(road_pt[0] - p[0], road_pt[1] - p[1]))
        crypt(z, i, p, face)
        z.spawner(mob, p[0], p[1], 5, n, 22.0, when={"unless": cfg["posts_quest"]})
        z.npc("%s_post_spearman_%d" % (fid, i), p[0] + 2.0, p[1] + 3.0, 180.0)
        z.npc("%s_post_crossbow_%d" % (fid, i), p[0] - 2.0, p[1] + 3.0, 180.0)
        z.block(p, 10.0)
    # ---------- pátio: jaulas, assentamento, guarnição, chefe ----------
    for i in range(3):
        p = (c[0] - 16 + i * 4.0, c[1] + 6)
        for k in range(4):
            a = math.tau * k / 4 + math.pi / 4
            z.ob("pillar", p[0] + math.cos(a) * 1.4, p[1] + math.sin(a) * 1.4, (0.3, 2.4, 0.3), color=(0.3, 0.28, 0.3))
    for i in range(3):
        z.npc("%s_prisoner_%d" % (fid, i), c[0] - 16 + i * 4.0, c[1] + 6, 180.0)
    for k, (dx, dy) in enumerate([(14, 4), (17, 8), (11, 10)]):
        z.npc("%s_settler_%d" % (fid, k), c[0] + dx, c[1] + dy, 200.0)
    for k, (dx, dy) in enumerate([(19, 2), (8, 14), (20, 12)]):
        z.ob("tent", c[0] + dx, c[1] + dy, (3.4, 2.4, 3.0), 200.0, color=(0.82, 0.78, 0.66), when={"if": q})
    for i, role in enumerate(["knight", "knight", "spearman", "priest", "crossbow"]):
        z.npc("%s_g_%s_%d" % (fid, role, i), c[0] - 6 + i * 3.0, c[1] + R - 4.0, 180.0)
    z.spawner(cfg["boss"], c[0], c[1] - 2, 2, 1, 120.0, when=gone)
    for i, (mob, n, resp) in enumerate(cfg["inside"]):
        a = math.tau * i / len(cfg["inside"]) + 0.6
        z.spawner(mob, c[0] + math.cos(a) * 14, c[1] + math.sin(a) * 12, 6, n, resp, when=gone)
    for (mob, n, resp), p in zip(cfg["outside"], [(-60, 84), (34, 82), (-62, 20)]):
        z.spawner(mob, p[0], p[1], 9, n, resp, when=gone)
    # ---------- assalto aliado: sobe a estrada em zigue-zague até o portão ----------
    z.data["assaults"] = [{"id": "aurora", "from": [arrive[0], arrive[1] - 4.0],
                           "route": [list(p) for p in BONES_ROAD[1:-1]] + [[gate_pt[0], gate_pt[1] + 2]],
                           "target": [c[0], c[1] + 4], "radius": 12.0}]
    z.data["hangouts"] = [[arrive[0] + dx, arrive[1] - 8] for dx in (-4, 0, 4)]
    z.cliffs(rock="cliff_rock", top="cliff_grass", snow=False)
    z.block((0, 0), 6)
    z.block(arrive, 9)
    z.block(c, R + 13)
    cols = [(0.32, 0.3, 0.28), (0.26, 0.24, 0.24)]
    z.scatter("tree", [((-96, 70), 20, 10), ((92, 76), 20, 10), ((-90, -40), 24, 10), ((90, -46), 24, 10)], 0, (1.5, 3.3, 1.5), cols, margin=4.6, spacing=4.2)
    z.rim_belt(100, (1.5, 3.3, 1.5), cols)
    z.scatter("rock", [((0, 0), 105, 30)], 0, (1.4, 0.9, 1.2), [(0.44, 0.43, 0.46)], margin=3.5, spacing=3.0, scale=(0.7, 1.5))
    nrnd = random.Random(cfg["seed"] + 5)
    obs = z.data["obstacles"]
    nature.fix_trees(obs, nrnd, dead=True, dead_cols=cols)
    nature.clear_banks(obs, z.rivers, [], 9.0)
    nature.woodland_floor(z.ob, lambda x, zz, m: z.free(x, zz, m, 0.0), nrnd, [((0, 0), 100, 12)], bark=[(0.34, 0.3, 0.28), (0.28, 0.26, 0.26)], avoid=obs)
    return z.finish(export, poi=c, ground=(0.4, 0.39, 0.36))


# ======================================================================================================
# Torre do Mago Gélido: lago congelado. O vale é gelo; buracos de água escura bloqueiam, navios presos no gelo, montes de
# neve. A torre fica numa ilha no meio, cercada por um canal de água escura que só as pontes de gelo cruzam.
# ======================================================================================================
FROST_ROAD = [(0, 92), (14, 78), (2, 64), (-16, 50), (-10, 34), (0, 16), (0, 4), (0, -1)]
FROST_PATH_W = [(-16, 50), (-36, 50), (-52, 46), (-58, 40)]
FROST_PATH_E = [(0, 16), (24, 14), (44, 18), (56, 26)]
FROST_CAMPS = [(-60, 36), (58, 30)]
FROST_HOLES = [("buraco_0", (34, 62), 8.0), ("buraco_1", (-40, 76), 7.0), ("buraco_2", (-82, 10), 8.5), ("buraco_3", (84, 56), 7.0),
               ("buraco_4", (-70, -48), 7.5), ("buraco_5", (70, -44), 8.0), ("buraco_6", (28, 92), 5.5)]


def ship(z, name, p, rot, mats):
    """Navio preso no gelo, meio afundado e inclinado: casco, convés, mastro quebrado e vela rasgada."""
    box(z.coll, z.P + name + "_casco", p, (3.6, 2.0, 11.0), rot, mats["hull"], -0.4)
    a = math.radians(rot)
    fx, fz = math.sin(a), math.cos(a)
    cone(z.coll, z.P + name + "_proa", (p[0] + fx * 6.0, p[1] + fz * 6.0), 1.8, 2.4, mats["hull"], -0.4, 4)
    box(z.coll, z.P + name + "_conves", p, (3.2, 0.2, 10.4), rot, mats["deck"], 1.6)
    cyl(z.coll, z.P + name + "_mastro", (p[0] - fx * 1.0, p[1] - fz * 1.0), 0.25, 0.2, 7.0, mats["deck"], 1.6, 8)
    box(z.coll, z.P + name + "_vela", (p[0] - fx * 1.0, p[1] - fz * 1.0), (3.0, 3.2, 0.08), rot + 90.0, mats["sail"], 4.0)
    for k in range(3):                                  # gelo acumulado no casco
        blob(z.coll, z.P + name + "_neve_%d" % k, (p[0] + fx * (k - 1) * 3.6, p[1] + fz * (k - 1) * 3.6), 1.6, 0.3, mats["snow"], k, 0.5)
    z.ob("wall", p[0], p[1], (4.0, 3.0, 12.0), rot, visible=False)


def cultist_camp(z, i, p, mats):
    """Acampamento de cultistas numa ilha de neve: tenda roxa, círculo de runas, braseiro de fogo azul."""
    z.patch("ilha_%d" % i, p, 10.0, (0.9, 0.93, 0.97), grass=False)
    blob(z.coll, z.P + "ilha_%d_monte" % i, (p[0] - 4.0, p[1] - 3.0), 2.6, 0.0, mats["snow"], i, 0.45)
    z.ob("tent", p[0] - 3.0, p[1] - 2.5, (3.4, 2.6, 3.0), 30.0 * i, color=(0.42, 0.28, 0.58))
    disc(z.coll, z.P + "ilha_%d_runas" % i, (p[0] + 2.0, p[1] + 1.0), 3.0, 0.03, mats["rune"], 24)
    disc(z.coll, z.P + "ilha_%d_runas_in" % i, (p[0] + 2.0, p[1] + 1.0), 2.4, 0.035, mats["snow"], 24)
    cyl(z.coll, z.P + "ilha_%d_braseiro" % i, (p[0] + 2.0, p[1] + 1.0), 0.5, 0.6, 0.8, mats["deck"], 0.0, 8)
    cyl(z.coll, z.P + "ilha_%d_fogo" % i, (p[0] + 2.0, p[1] + 1.0), 0.35, 0.04, 1.0, mats["accent"], 0.8, 6)
    z.ob("rock", p[0] + 2.0, p[1] + 1.0, (1.2, 1.0, 1.2), visible=False)


def build_frost(export=False):
    fid = "fort_frost"
    cfg = FORTS[fid]
    z = Zone(fid, seed=cfg["seed"], palette={
        "road": (0.7, 0.76, 0.82), "street": (0.78, 0.84, 0.9), "cliff_rock": (0.5, 0.56, 0.64), "cliff_rock_d": (0.4, 0.46, 0.54),
        "cliff_grass": (0.86, 0.9, 0.95), "hill_grass": (0.86, 0.9, 0.95), "leaf": (0.62, 0.68, 0.74), "bark": (0.38, 0.36, 0.4),
        "wood": (0.7, 0.86, 0.96), "icewater": (0.05, 0.1, 0.18), "fort_wall": cfg["wall"], "town_wall": cfg["wall"],
        "accent": cfg["accent"], "snow": (0.95, 0.97, 1.0), "hull": (0.2, 0.13, 0.09), "deck": (0.32, 0.22, 0.14),
        "sail": (0.82, 0.8, 0.74), "rune": (0.55, 0.4, 0.85), "crack": (0.32, 0.48, 0.66), "patio": cfg["patio"],
    })
    q = cfg["quest"]
    gone = {"unless": q}
    arrive = ARRIVE_IN_FORT
    z.data["spawn"] = list(arrive)
    z.portal("to_bastion", polar(z, 90, 7), "field_ruins", BACK[fid], "Bastião da Aurora")
    c, R = FORT_C, FORT_R
    gate = math.radians(90.0)
    gate_pt = (c[0], c[1] + R)
    rnd = random.Random(cfg["seed"])
    # ---------- o lago congelado: gelo claro, rachaduras e montes de neve; margem de neve na borda ----------
    z.patch("neve", (0, 10), 112, (0.9, 0.93, 0.97), grass=False)
    z.patch("gelo", (0, 4), 92, (0.72, 0.84, 0.93), grass=False)
    for k in range(10):
        a, r = rnd.uniform(0, math.tau), rnd.uniform(20, 80)
        z.patch("placa_%d" % k, (math.cos(a) * r, math.sin(a) * r), rnd.uniform(6, 12), (0.8, 0.9, 0.97), grass=False)
    for k in range(140):                                 # rachaduras: riscos azuis no gelo
        a, r = rnd.uniform(0, math.tau), rnd.uniform(18, 88)
        p = (math.cos(a) * r, math.sin(a) * r)
        if math.hypot(p[0] - c[0], p[1] - c[1]) < R + 10:
            continue
        ang = rnd.uniform(0, 180)
        for s in range(3):                              # rachadura quebrada em três trechos tortos
            q = (p[0] + math.cos(math.radians(ang)) * s * 2.6, p[1] - math.sin(math.radians(ang)) * s * 2.6)
            box(z.coll, z.P + "racha_%d_%d" % (k, s), q, (2.8, 0.02, 0.22), ang + rnd.uniform(-25, 25), z.M["crack"], 0.015)
    # ---------- canal de água escura em volta da ilha da torre (só as pontes de gelo cruzam) e buracos no gelo ----------
    ring = [(c[0] + math.cos(math.tau * k / 24) * (R + 8.0), c[1] + math.sin(math.tau * k / 24) * (R + 8.0)) for k in range(26)]
    z.river(ring, w=6.0, material="icewater")
    for name, pc, r in FROST_HOLES:
        z.lake(name, pc, r, material="icewater")
    z.road("travessia", FROST_ROAD, w=4.4)
    z.road("trilha_oeste", FROST_PATH_W, w=3.0, end_clearing=False)
    z.road("trilha_leste", FROST_PATH_E, w=3.0, end_clearing=False)
    z.road("ponte_norte", [(0, -88), (0, -66), (0, -59)], w=3.0, end_clearing=False)      # ponte dos fundos (saída de gelo ao norte)
    z.bridges()
    # ---------- ilha da torre ----------
    z.patch("ilha_torre", c, R + 4.0, (0.88, 0.92, 0.97), grass=False)
    z.patch("patio", c, R - 6.0, (0.62, 0.7, 0.8), paved=True)
    z.data["town"] = {"center": list(c), "radius": R, "gates": [list(gate_pt)]}
    landmark(z, fid, cfg)                              # torre de gelo com cristal e picos
    for k in range(14):                                  # pedras de gelo na beira da ilha (sem fechar a passagem)
        a = math.tau * (k + 0.5) / 14
        if abs((a - gate + math.pi) % math.tau - math.pi) < 0.35 or abs((a + gate + math.pi) % math.tau - math.pi) < 0.25:
            continue
        p = (c[0] + math.cos(a) * (R + 2.0), c[1] + math.sin(a) * (R + 2.0))
        cyl(z.coll, z.P + "borda_%d" % k, p, 1.2, 0.2, 2.5 + (k % 3), z.M["accent"], 0.0, 6)
        z.ob("rock", p[0], p[1], (2.0, 2.5, 2.0), visible=False)
    # ---------- navios presos, montes de neve ----------
    for k, (p, rot) in enumerate([((-34, 92), 70.0), ((70, 8), -20.0), ((-60, -20), 30.0), ((40, -70), 100.0)]):
        ship(z, "navio_%d" % k, p, rot, z.M)
    for k in range(18):
        a, r = rnd.uniform(0, math.tau), rnd.uniform(40, 98)
        p = (math.cos(a) * r, math.sin(a) * r)
        if not z.free(p[0], p[1], 3.0, 0.0) or math.hypot(p[0] - c[0], p[1] - c[1]) < R + 14:
            continue
        blob(z.coll, z.P + "monte_neve_%d" % k, p, rnd.uniform(1.6, 3.0), -0.2, z.M["snow"], k, 0.45)
        z.ob("rock", p[0], p[1], (3.0, 1.2, 3.0), visible=False)
    # ---------- acampamentos de cultistas (postos) ----------
    for i, (p, (mob, n)) in enumerate(zip(FROST_CAMPS, cfg["posts"])):
        cultist_camp(z, i, p, z.M)
        z.spawner(mob, p[0], p[1], 5, n, 22.0, when={"unless": cfg["posts_quest"]})
        z.npc("%s_post_spearman_%d" % (fid, i), p[0] + 2.0, p[1] + 3.0, 180.0)
        z.npc("%s_post_crossbow_%d" % (fid, i), p[0] - 2.0, p[1] + 3.0, 180.0)
        z.block(p, 10.0)
    # ---------- ilha: jaulas, assentamento, guarnição, chefe ----------
    for i in range(3):
        p = (c[0] - 16 + i * 4.0, c[1] + 6)
        for k in range(4):
            a = math.tau * k / 4 + math.pi / 4
            z.ob("pillar", p[0] + math.cos(a) * 1.4, p[1] + math.sin(a) * 1.4, (0.3, 2.4, 0.3), color=(0.5, 0.6, 0.72))
    for i in range(3):
        z.npc("%s_prisoner_%d" % (fid, i), c[0] - 16 + i * 4.0, c[1] + 6, 180.0)
    for k, (dx, dy) in enumerate([(14, 4), (17, 8), (11, 10)]):
        z.npc("%s_settler_%d" % (fid, k), c[0] + dx, c[1] + dy, 200.0)
    for k, (dx, dy) in enumerate([(19, 2), (8, 14), (20, 12)]):
        z.ob("tent", c[0] + dx, c[1] + dy, (3.4, 2.4, 3.0), 200.0, color=(0.82, 0.78, 0.66), when={"if": q})
    for i, role in enumerate(["knight", "knight", "spearman", "priest", "crossbow"]):
        z.npc("%s_g_%s_%d" % (fid, role, i), c[0] - 6 + i * 3.0, c[1] + R - 4.0, 180.0)
    z.spawner(cfg["boss"], c[0], c[1] - 2, 2, 1, 120.0, when=gone)
    for i, (mob, n, resp) in enumerate(cfg["inside"]):
        a = math.tau * i / len(cfg["inside"]) + 0.6
        z.spawner(mob, c[0] + math.cos(a) * 14, c[1] + math.sin(a) * 12, 6, n, resp, when=gone)
    for (mob, n, resp), p in zip(cfg["outside"], [(-30, 60), (40, 40), (-78, 60)]):
        z.spawner(mob, p[0], p[1], 9, n, resp, when=gone)
    z.data["assaults"] = [{"id": "aurora", "from": [arrive[0], arrive[1] - 4.0],
                           "route": [list(p) for p in FROST_ROAD[1:-1]] + [[gate_pt[0], gate_pt[1] + 2]],
                           "target": [c[0], c[1] + 4], "radius": 12.0}]
    z.data["hangouts"] = [[arrive[0] + dx, arrive[1] - 8] for dx in (-4, 0, 4)]
    z.cliffs(rock="cliff_rock", top="cliff_grass", snow=True)
    z.block((0, 0), 6)
    z.block(arrive, 9)
    z.block(c, R + 12)
    pines = [(0.62, 0.68, 0.74), (0.55, 0.6, 0.66)]
    z.rim_belt(90, (1.5, 3.3, 1.5), pines)
    nrnd = random.Random(cfg["seed"] + 5)
    obs = z.data["obstacles"]
    lakes_all = [(tuple(w["pos"]), w["r"]) for w in z.data["water"] if w["kind"] == "lake"]
    nature.fix_trees(obs, nrnd, pine_frac=1.0, pine_cols=pines)
    nature.clear_banks(obs, z.rivers, lakes_all, 6.0)
    return z.finish(export, poi=c, ground=(0.86, 0.9, 0.95))


# ======================================================================================================
# Cidadela do Lich: necrópole. Uma cidade morta inteira dentro do anel de montanhas: muralha externa em ruínas (portão da
# cidade ao sul + brechas), ruas tortas entre casas sem teto e torres de ossos, um anel de ossuário no meio (o segundo
# portão, com três passagens) e, na praça do centro, o palácio do Lich com a agulha de almas (o marco) e o trono.
# Três "portões" da subida = cidade, ossuário, palácio; a avenida é o caminho mais curto, as ruas de lado também chegam.
# ======================================================================================================
CIT_C = (0.0, -30.0)                     # praça do palácio (centro do anel de dentro, raio FORT_R)
CIT_MID_R = 50.0                         # anel do ossuário (em volta da praça)
CIT_OUT_C, CIT_OUT_R = (0.0, -8.0), 81.0  # muralha da cidade
CIT_AVENUE = [(0, 92), (8, 84), (0, 73), (-12, 60), (-6, 46), (8, 34), (3, 20), (-6, 8), (0, 2), (0, -1)]
CIT_WEST = [(-12, 60), (-34, 57), (-56, 44), (-64, 24), (-66, 2), (-58, -18), (-48, -30)]
CIT_WEST_IN = [(-48, -30), (-40, -10), (-24, 2), (-6, 6)]
CIT_EAST = [(8, 34), (30, 40), (52, 34), (63, 14), (62, -8), (50, -30)]
CIT_EAST_IN = [(50, -30), (40, -10), (24, 2), (6, 6)]
CIT_ALLEYS = [("beco_oeste", [(-56, 44), (-40, 30), (-22, 34), (-6, 46)]), ("beco_leste", [(30, 40), (34, 58), (16, 64), (0, 73)]),
              ("beco_norte_o", [(-58, -18), (-50, -54), (-24, -76), (0, -84)]), ("beco_norte_l", [(62, -8), (52, -50), (26, -76), (0, -84)])]
CIT_POSTS = [(-64, 24), (63, 14)]        # pracinhas com torre de ossos (postos da quest)
CIT_SOUL_POOLS = [("alma_0", (-40, 76), 5.0), ("alma_1", (44, 74), 5.5), ("alma_2", (-82, -40), 6.0), ("alma_3", (80, -34), 6.0),
                  ("alma_4", (0, -96), 6.5), ("alma_5", (-30, 20), 3.6), ("alma_6", (30, 22), 3.6)]
CIT_TOWERS = [(-24, 72), (22, 50), (-48, 12), (48, 4), (-36, -64), (36, -64), (-72, 52), (74, 42)]


def bone_tower(z, name, p, h):
    """Torre de ossos: tronco de pedra escura coberto de ossos em espiral, coroa de crânios e chama de almas no topo."""
    cyl(z.coll, z.P + name, p, 1.9, 1.3, h, z.M["fort_wall"], 0.0, 8)
    for k in range(int(h * 1.6)):
        a = k * 0.9
        y = 0.5 + k * (h - 1.2) / (h * 1.6)
        q = (p[0] + math.cos(a) * 1.75, p[1] + math.sin(a) * 1.75)
        box(z.coll, z.P + "%s_osso_%d" % (name, k), q, (0.22, 0.22, 1.2), math.degrees(-a), z.M["bone"], y)
    for k in range(7):
        a = math.tau * k / 7
        skull(z, "%s_cr%d" % (name, k), (p[0] + math.cos(a) * 1.25, p[1] + math.sin(a) * 1.25), 0.42, h, z.M)
    cone(z.coll, z.P + name + "_chama", p, 0.9, 2.2, z.M["soul"], h + 0.2, 7)
    z.ob("pillar", p[0], p[1], (4.0, h, 4.0), visible=False)
    z.block(p, 5.0)


def ruined_ring(z, name, c, r, gates, gate_half, height, rnd, skulls=False, rubble=0.18, towers=0):
    """Muralha em ruínas: segmentos de altura variada; alguns viraram monte de entulho (baixo, ainda fecha); vãos em `gates` (rad)."""
    n = max(16, int(math.tau * r / 3.0))
    for i in range(n):
        am = math.tau * (i + 0.5) / n
        if any(zone_lib.angdiff(am, g) * r < gate_half + 0.4 for g in gates):
            continue
        p = (c[0] + math.cos(am) * r, c[1] + math.sin(am) * r)
        seg = math.tau * r / n + 0.15
        rot = zone_lib.along(-math.sin(am), math.cos(am))
        if rnd.random() < rubble:                         # entulho: pedras caídas (ainda fecha a passagem)
            for k in range(3):
                blob(z.coll, z.P + "%s_entulho_%d_%d" % (name, i, k), (p[0] + rnd.uniform(-1.2, 1.2), p[1] + rnd.uniform(-1.2, 1.2)),
                     rnd.uniform(0.7, 1.1), 0.25, z.M["fort_wall"], i * 3 + k, 0.6)
            z.ob("wall", p[0], p[1], (seg, 1.4, 2.4), rot, visible=False)
            continue
        h = height * rnd.uniform(0.55, 1.0)
        box(z.coll, z.P + "%s_muro_%d" % (name, i), p, (seg, h, 1.6), rot, z.M["fort_wall"], 0.0)
        if skulls and i % 2 == 0:
            skull(z, "%s_cr_%d" % (name, i), p, 0.42, h, z.M)
        z.ob("wall", p[0], p[1], (seg, h, 2.0), rot, visible=False)
    for k in range(towers):
        a = math.tau * (k + 0.5) / towers
        if any(zone_lib.angdiff(a, g) * r < gate_half + 4 for g in gates):
            continue
        p = (c[0] + math.cos(a) * r, c[1] + math.sin(a) * r)
        top = height + rnd.uniform(1.0, 3.0)
        cyl(z.coll, z.P + "%s_torre_%d" % (name, k), p, 2.2, 1.9, top, z.M["fort_wall"], 0.0, 8, 0.12, k)
        z.ob("pillar", p[0], p[1], (4.4, top, 4.4), visible=False)


def dead_house(z, name, p, rot, w, d, rnd, intact):
    """Casa da cidade morta: três paredes quebradas (prop `ruin`, aberta para a rua) com chão escuro; `intact` = sobrado
    (paredes mais altas). Nenhuma casa inteira: a cidade morreu. `rot` = graus do jogo (frente = +z local)."""
    wall_c = rnd.choice([(0.34, 0.31, 0.36), (0.3, 0.28, 0.33), (0.38, 0.35, 0.38)])
    tall = 1.45 if intact else 1.0                       # sobrado: paredes mais altas (ainda sem teto)
    a = math.radians(rot)
    ux, uz = math.cos(a), -math.sin(a)                   # eixo x local (largura) no plano do jogo
    fx, fz = math.sin(a), math.cos(a)                    # frente (+z local), virada para a rua
    disc(z.coll, z.P + name + "_chao", p, min(w, d) * 0.55, 0.01, z.M["floor"], 6, 0.2, len(name))
    back = (p[0] - fx * d / 2, p[1] - fz * d / 2)
    z.ob("ruin", back[0], back[1], (w, rnd.uniform(1.8, 3.2) * tall, 0.7), rot, color=wall_c)
    for sx in (-1, 1):
        q = (p[0] + ux * sx * w / 2, p[1] + uz * sx * w / 2)
        z.ob("ruin", q[0], q[1], (d, rnd.uniform(1.4, 2.8) * tall, 0.7), rot + 90, color=wall_c)


def build_citadel(export=False):
    fid = "lich_citadel"
    cfg = FORTS[fid]
    z = Zone(fid, seed=cfg["seed"], palette={
        "road": (0.36, 0.33, 0.38), "street": (0.42, 0.4, 0.44), "cliff_rock": (0.26, 0.23, 0.3), "cliff_rock_d": (0.19, 0.17, 0.22),
        "cliff_grass": (0.3, 0.27, 0.32), "hill_grass": (0.32, 0.29, 0.34), "leaf": (0.3, 0.26, 0.3), "bark": (0.26, 0.22, 0.26),
        "fort_wall": cfg["wall"], "town_wall": cfg["wall"], "accent": cfg["accent"], "roof": (0.24, 0.2, 0.3),
        "bone": (0.84, 0.8, 0.7), "socket": (0.05, 0.04, 0.06), "soul": (0.45, 1.0, 0.6), "soulwater": (0.1, 0.32, 0.22),
        "floor": (0.2, 0.18, 0.22), "pave_rua": (0.52, 0.48, 0.5), "palace": (0.17, 0.14, 0.21), "palace_l": (0.32, 0.26, 0.4),
        "tomb": (0.28, 0.27, 0.3), "tomb_l": (0.5, 0.5, 0.52), "roof_d": (0.2, 0.18, 0.24), "grave": (0.24, 0.2, 0.18),
    })
    q = cfg["quest"]
    rnd = random.Random(cfg["seed"])
    arrive = ARRIVE_IN_FORT
    z.data["spawn"] = list(arrive)
    z.portal("to_bastion", polar(z, 90, 7), "field_ruins", BACK[fid], "Bastião da Aurora")
    c, R = CIT_C, FORT_R
    gate = math.radians(90.0)
    gate_pt = (c[0], c[1] + R)
    # ---------- chão: terra roxa-escura; bairros com manchas próprias (cinza, praça calçada) ----------
    z.patch("cidade", (0, -4), 108, (0.26, 0.24, 0.28))
    for k in range(16):
        a, r = rnd.uniform(0, math.tau), rnd.uniform(14, 96)
        pc = (math.cos(a) * r, math.sin(a) * r - 6)
        z.patch("cinza_%d" % k, pc, rnd.uniform(6, 12), (0.25, 0.23, 0.27) if k % 2 else (0.34, 0.3, 0.33))
    z.patch("ossuario", c, CIT_MID_R + 3, (0.27, 0.25, 0.3))
    z.patch("praca", c, R - 0.5, (0.36, 0.32, 0.42), paved=True)
    # ---------- ruas: avenida torta (a subida), duas ruas de volta, becos ----------
    z.road("avenida", CIT_AVENUE, w=4.6, material="pave_rua")
    z.road("rua_oeste", CIT_WEST, w=3.8, material="pave_rua")
    z.road("rua_oeste_dentro", CIT_WEST_IN, w=3.6, material="pave_rua", end_clearing=False)
    z.road("rua_leste", CIT_EAST, w=3.8, material="pave_rua")
    z.road("rua_leste_dentro", CIT_EAST_IN, w=3.6, material="pave_rua", end_clearing=False)
    for name, pts in CIT_ALLEYS:
        z.road(name, pts, w=3.0, material="pave_rua", end_clearing=False)
    # ---------- água de almas: poços verdes (bloqueiam), velas de alma em volta ----------
    for name, p, r in CIT_SOUL_POOLS:
        z.lake(name, p, r, material="soulwater")
        for k in range(6):
            a = math.tau * k / 6 + 0.3
            cyl(z.coll, z.P + "%s_vela_%d" % (name, k), (p[0] + math.cos(a) * (r + 1.3), p[1] + math.sin(a) * (r + 1.3)), 0.12, 0.12, 0.5, z.M["soul"], 0.0, 6)
    # ---------- três portões: muralha da cidade, anel do ossuário, palácio ----------
    out_gates = [math.atan2(73 - CIT_OUT_C[1], 0 - CIT_OUT_C[0])] + [math.radians(d) for d in (28, 152, 214, 326)]
    ruined_ring(z, "muralha", CIT_OUT_C, CIT_OUT_R, out_gates, 4.2, 5.0, random.Random(7), rubble=0.14, towers=10)
    for sx in (-1, 1):                                    # portão da cidade: dois torreões com crânio e chama de almas
        p = (sx * 7.4, 73.0)
        cyl(z.coll, z.P + "portao_torre_%d" % sx, p, 2.2, 1.9, 5.2, z.M["fort_wall"], 0.0, 8)
        skull(z, "portao_cranio_%d" % sx, p, 0.7, 5.2, z.M)
        cone(z.coll, z.P + "portao_chama_%d" % sx, p, 0.6, 1.2, z.M["soul"], 6.4, 7)
        z.ob("pillar", p[0], p[1], (4.2, 5.2, 4.2), visible=False)
    mid_gates = [math.atan2(p[1] - c[1], p[0] - c[0]) for p in [(3, 20), (-48, -30), (50, -30)]]
    ruined_ring(z, "ossuario", c, CIT_MID_R, mid_gates, 4.4, 3.4, random.Random(11), skulls=True, rubble=0.1, towers=0)
    z.ring_wall("palacio", c, R, [gate], gate_half=4.0, height=5.5, thick=2.0, material="fort_wall", towers=6)
    z.data["town"] = {"center": list(c), "radius": R, "gates": [list(gate_pt)]}
    for k in range(36):                                   # coroa de crânios e cravos de osso no alto do muro do palácio
        a = math.tau * (k + 0.5) / 36
        if zone_lib.angdiff(a, gate) * R < 6.0:
            continue
        p = (c[0] + math.cos(a) * R, c[1] + math.sin(a) * R)
        if k % 2:
            skull(z, "palacio_cranio_%d" % k, p, 0.5, 5.5, z.M)
        else:
            cone(z.coll, z.P + "palacio_cravo_%d" % k, p, 0.35, 1.6, z.M["bone"], 5.5, 6)
    for sx in (-1, 1):                                    # braseiros de almas no portão do palácio
        p = (gate_pt[0] + sx * 5.6, gate_pt[1] + 2.4)
        cyl(z.coll, z.P + "braseiro_%d" % sx, p, 0.7, 0.5, 1.2, z.M["fort_wall"], 0.0, 8)
        cone(z.coll, z.P + "braseiro_alma_%d" % sx, p, 0.6, 1.4, z.M["soul"], 1.2, 7)
        z.ob("pillar", p[0], p[1], (1.4, 1.2, 1.4), visible=False)
    # ---------- palácio do Lich (fundo da praça) e a agulha de almas (o marco) ----------
    pal = (c[0], c[1] - 23.0)
    cyl(z.coll, z.P + "palacio_base", pal, 12.0, 11.0, 2.0, z.M["palace"], 0.0, 12)
    box(z.coll, z.P + "palacio_salao", (pal[0], pal[1] - 1.5), (20.0, 9.0, 8.0), 0.0, z.M["palace"], 2.0)
    for sx in (-1, 1):
        cyl(z.coll, z.P + "palacio_torre_%d" % sx, (pal[0] + sx * 10.5, pal[1] - 1.5), 2.6, 1.8, 17.0, z.M["palace"], 0.0, 8)
        cone(z.coll, z.P + "palacio_teto_%d" % sx, (pal[0] + sx * 10.5, pal[1] - 1.5), 2.8, 4.5, z.M["palace_l"], 17.0, 8)
        cone(z.coll, z.P + "palacio_chama_%d" % sx, (pal[0] + sx * 10.5, pal[1] - 1.5), 0.7, 1.6, z.M["soul"], 21.5, 6)
    cyl(z.coll, z.P + "agulha", (pal[0], pal[1] - 2.0), 3.4, 0.5, 36.0, z.M["palace"], 2.0, 8)
    for k in range(6):                                    # costelas de osso abraçando a agulha
        a = math.tau * k / 6
        rib(z.coll, z.P + "agulha_costela_%d" % k, (pal[0] + math.cos(a) * 3.6, pal[1] - 2.0 + math.sin(a) * 3.6), a, 22.0, 0.35, 0.5, 0.18, z.M["bone"])
    cone(z.coll, z.P + "agulha_alma", (pal[0], pal[1] - 2.0), 1.6, 5.0, z.M["soul"], 37.0, 8)
    z.ob("wall", pal[0], pal[1] - 1.5, (22.0, 12.0, 10.0), visible=False)
    for sx in (-1, 1):
        z.ob("pillar", pal[0] + sx * 10.5, pal[1] - 1.5, (5.2, 17.0, 5.2), visible=False)
    # trono: estrado de três degraus diante do palácio, colunas com chama de almas em volta (como antes: arena aberta)
    th = (c[0], c[1] - 12)
    for k in range(3):
        cyl(z.coll, z.P + "trono_degrau_%d" % k, th, 6.0 - k * 1.4, 5.8 - k * 1.4, 0.3, z.M["palace_l"] if k % 2 else z.M["palace"], k * 0.3, 16)
    box(z.coll, z.P + "trono", (th[0], th[1] - 1.4), (2.4, 3.6, 1.2), 0.0, z.M["palace"], 0.9)
    skull(z, "trono_cranio", (th[0], th[1] - 1.4), 0.7, 4.5, z.M)
    for i in range(8):
        a = math.tau * i / 8
        p = (th[0] + math.cos(a) * 9, th[1] + math.sin(a) * 9)
        cyl(z.coll, z.P + "coluna_%d" % i, p, 0.8, 0.7, 6.5, z.M["fort_wall"], 0.0, 8)        # mais baixa que antes: não tampa a luta
        cyl(z.coll, z.P + "chama_%d" % i, p, 0.6, 0.05, 1.6, z.M["soul"], 6.5, 6)
        z.ob("pillar", p[0], p[1], (1.6, 9.0, 1.6), visible=False)
    # ---------- torres de ossos pelos bairros ----------
    for k, p in enumerate(CIT_TOWERS):
        bone_tower(z, "torre_ossos_%d" % k, p, rnd.uniform(10.0, 14.0))
    # ---------- pracinhas dos postos (torre de ossos menor, guarda da Aurora depois) ----------
    for i, (p, (mob, n)) in enumerate(zip(CIT_POSTS, cfg["posts"])):
        z.patch("posto_%d" % i, p, 9.0, (0.38, 0.34, 0.4), paved=True)
        bone_tower(z, "posto_torre_%d" % i, (p[0] + (-7 if i == 0 else 7), p[1] - 4), 8.0)
        z.spawner(mob, p[0], p[1], 5, n, 22.0, when={"unless": cfg["posts_quest"]})
        z.npc("%s_post_spearman_%d" % (fid, i), p[0] + 2.0, p[1] + 3.0, 180.0)
        z.npc("%s_post_crossbow_%d" % (fid, i), p[0] - 2.0, p[1] + 3.0, 180.0)
        z.block(p, 9.0)
    # ---------- praça: jaulas, assentamento, guarnição, chefe e a guarda do trono ----------
    for i in range(3):
        p = (c[0] - 16 + i * 4.0, c[1] + 6)
        for k in range(4):
            a = math.tau * k / 4 + math.pi / 4
            z.ob("pillar", p[0] + math.cos(a) * 1.4, p[1] + math.sin(a) * 1.4, (0.3, 2.4, 0.3), color=(0.3, 0.28, 0.3))
        z.npc("%s_prisoner_%d" % (fid, i), p[0], p[1], 180.0)
    for k, (dx, dy) in enumerate([(14, 4), (17, 8), (11, 10)]):
        z.npc("%s_settler_%d" % (fid, k), c[0] + dx, c[1] + dy, 200.0)
    for k, (dx, dy) in enumerate([(19, 2), (8, 14), (20, 12)]):
        z.ob("tent", c[0] + dx, c[1] + dy, (3.4, 2.4, 3.0), 200.0, color=(0.82, 0.78, 0.66), when={"if": q})
    for i, role in enumerate(["knight", "knight", "spearman", "priest", "crossbow"]):
        z.npc("%s_g_%s_%d" % (fid, role, i), c[0] - 6 + i * 3.0, c[1] + R - 4.0, 180.0)
    z.spawner(cfg["boss"], c[0], c[1] - 2, 2, 1, 300.0)
    for i, (mob, n, resp) in enumerate(cfg["inside"]):
        a = math.tau * i / len(cfg["inside"]) + 0.6
        z.spawner(mob, c[0] + math.cos(a) * 14, c[1] + math.sin(a) * 12, 6, n, resp)
    for (mob, n, resp), p in zip(cfg["outside"], [(-34, 34), (38, -8)]):      # bairro oeste e anel do ossuário a leste
        z.spawner(mob, p[0], p[1], 9, n, resp)
    # ---------- assalto aliado: a Ofensiva sobe a avenida até a praça ----------
    z.data["assaults"] = [{"id": "aurora", "from": [arrive[0], arrive[1] - 4.0],
                           "route": [list(p) for p in CIT_AVENUE[1:-1]] + [[gate_pt[0], gate_pt[1] + 2]],
                           "target": [c[0], c[1] + 4], "radius": 12.0}]
    z.data["hangouts"] = [[arrive[0] + dx, arrive[1] - 8] for dx in (-4, 0, 4)]
    # ---------- casas mortas ao longo das ruas (abertas para a rua) ----------
    z.block(c, CIT_MID_R - 18)                            # anel de dentro: praça livre
    z.block(arrive, 9)
    z.block((0, 73), 9)
    z.block((0, 6), 10)                                   # cruzamento das ruas de dentro com a avenida, diante do palácio
    hrnd = random.Random(cfg["seed"] + 3)
    houses = 0
    for name, poly in list(z.road_polys.items()):
        for i in range(3, len(poly) - 3, 6):
            t = (poly[i + 2] - poly[i - 2]).normalized()
            side_v = zone_lib.Vector((t.y, -t.x))
            for sgn in (-1, 1):
                w, d = hrnd.uniform(5.0, 7.0), hrnd.uniform(4.2, 5.6)
                off = 2.6 + d / 2 + hrnd.uniform(1.4, 2.4)
                p = poly[i] + side_v * sgn * off
                x, zz = round(p.x, 1), round(p.y, 1)
                ro = math.hypot(x - CIT_OUT_C[0], zz - CIT_OUT_C[1])
                if not z.free(x, zz, d / 2 + 1.6) or ro > CIT_OUT_R - 5 or abs(math.hypot(x - c[0], zz - c[1]) - CIT_MID_R) < 6:
                    continue
                face = -side_v * sgn                     # frente da casa para a rua
                rot = math.degrees(math.atan2(face.x, face.y))
                dead_house(z, "casa_%d" % houses, (x, zz), rot, w, d, hrnd, intact=hrnd.random() < 0.25)
                z.block((x, zz), max(w, d) * 0.75)
                houses += 1
    # quarteirões entre as ruas: ruínas soltas (a cidade é cheia, não só a beira da rua)
    filler = 0
    for gx in range(-78, 79, 10):
        for gz in range(-86, 72, 10):
            if filler >= 48:
                break
            x, zz = gx + hrnd.uniform(-2.5, 2.5), gz + hrnd.uniform(-2.5, 2.5)
            ro = math.hypot(x - CIT_OUT_C[0], zz - CIT_OUT_C[1])
            rm = math.hypot(x - c[0], zz - c[1])
            if ro > CIT_OUT_R - 6 or abs(rm - CIT_MID_R) < 6 or rm < R + 6 or not z.free(x, zz, 6.0) or hrnd.random() < 0.3:
                continue
            w, d = hrnd.uniform(5.0, 7.5), hrnd.uniform(4.2, 6.0)
            dead_house(z, "bloco_%d" % filler, (round(x, 1), round(zz, 1)), hrnd.choice([0.0, 90.0, 180.0, 270.0]) + hrnd.uniform(-12, 12), w, d, hrnd, intact=hrnd.random() < 0.2)
            z.block((x, zz), max(w, d) * 0.75)
            filler += 1
    print("CIDADELA quarteirões", filler)
    # ---------- cemitério do fundo (atrás do palácio, fora do anel do ossuário) ----------
    for f, (corner, cols_n, rows_n) in enumerate([((-70, -64), 4, 3), ((50, -66), 4, 3), ((-24, -90), 4, 2)]):
        for rw in range(rows_n):
            tomb_row(z, "campo_%d_%d" % (f, rw), (corner[0], corner[1] - rw * 4.0), (3.6, 0.0), cols_n, rnd)
    # ---------- fora e no anel de montanhas: árvores mortas e pedras ----------
    z.cliffs(rock="cliff_rock", top="cliff_grass", snow=False)
    z.block((0, 0), 6)
    cols = [(0.3, 0.26, 0.3), (0.26, 0.22, 0.28)]
    z.rim_belt(90, (1.5, 3.3, 1.5), cols)
    z.scatter("rock", [((0, -4), 100, 50)], 0, (1.2, 0.8, 1.1), [(0.36, 0.33, 0.38)], margin=3.2, spacing=4.0, scale=(0.6, 1.3))
    nrnd = random.Random(cfg["seed"] + 5)
    obs = z.data["obstacles"]
    nature.fix_trees(obs, nrnd, dead=True, dead_cols=cols)
    nature.clear_banks(obs, z.rivers, [], 9.0)
    print("CIDADELA casas", houses)
    return z.finish(export, poi=c, ground=(0.3, 0.27, 0.31))


def build(export=False, only=None):
    out = []
    for fid in FORTS:
        if only and fid not in only:
            continue
        out.append(build_one(fid, export))
    return out
