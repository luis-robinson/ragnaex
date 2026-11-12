"""Acampamentos de guerra da Horda nas Estepes de Cinza (Ato II, 35-40): um mapa por acampamento, gerados por um laço
no padrão das fortalezas do Bastião (build_dawn_forts): chegada ao sul (portal de volta às Estepes), estrada curva com
dois postos avançados, o acampamento murado com o pátio do chefe, colonos presos em jaulas.
  fort_trolls  Toca do Rei-da-Rocha: bacia de pedregulhos, fenda com ponte na subida, boca de caverna e ossadas.
  fort_fire    Paliçada das Flechas de Fogo: chão de carvão, torres de vigia na estrada, braseiros, a pira de sinal.
  fort_war     Arraial de Ghar: paliçada dupla (arena no meio), tambores de guerra, a tenda de comando.
Retomada (quest do chefe, `hx_fort_*`): a Horda some, os estandartes vermelhos viram branco-dourados (conquest_vis),
nasce o posto aliado (colonos, ferreiro de campo, mercador, guarnição da Aurora).

    set RAGNAEX_ROOT=<projeto ou worktree>
    blender -b --factory-startup --python tools/blender/zones/run_zone.py -- build_steppe_forts <pasta_png> --export --only=fort_war
"""
import math
import random
import act2_dress
import horde
import nature
import zone_lib
from zone_lib import Zone, box, cyl, cone, disc, mat

FORT_C = (0.0, -30.0)
FORT_R = 28.0
ARRIVE = (0.0, 96.0)                     # chegada (build_field_steppe.FORT_ARRIVE aponta para cá)
# portal de volta: a chegada nas Estepes, do lado de fora do anel do acampamento (números do build_field_steppe: "BACK <lado>")
BACK = {"fort_trolls": (-101.6, 0.0), "fort_war": (77.1, -44.5), "fort_fire": (84.9, 59.4)}
DRY = [(0.52, 0.44, 0.3), (0.46, 0.4, 0.3), (0.58, 0.5, 0.34)]
AURORA_BLUE = (0.36, 0.48, 0.78)

FORTS = {
    "fort_trolls": {
        "name": "Toca do Rei-da-Rocha", "seed": 61, "quest": "hx_fort_trolls", "boss": "boss_troll_king",
        "ground": (0.56, 0.52, 0.46), "patio": (0.44, 0.42, 0.42), "wall": (0.46, 0.44, 0.44), "road": (0.46, 0.42, 0.38), "trail": (0.47, 0.41, 0.33),      # terra pisada quente (cinza frio lia como asfalto no chão bege)
        "outside": [("troll_whelp", 5, 20.0), ("troll_whelp", 4, 20.0), ("troll", 2, 28.0), ("troll", 2, 28.0)],
        "inside": [("troll", 3, 28.0), ("troll_whelp", 4, 20.0)], "posts": [("troll_whelp", 4), ("troll", 2)],
        "road_pts": [(-16, 74), (12, 60), (13, 50), (11, 36), (-4, 24), (4, 12)],      # cruza a fenda de frente (ponte reta)
    },
    "fort_fire": {
        "name": "Paliçada das Flechas de Fogo", "seed": 67, "quest": "hx_fort_fire", "boss": "boss_crossbow_master",
        "ground": (0.4, 0.36, 0.32), "patio": (0.25, 0.23, 0.22), "wall": horde.STAKE_DARK, "road": (0.34, 0.31, 0.29), "trail": (0.3, 0.27, 0.26),
        "outside": [("orc_archer", 5, 20.0), ("orc_archer", 4, 20.0), ("orc_crossbow", 3, 24.0), ("orc_archer", 4, 20.0)],
        "inside": [("orc_crossbow", 4, 24.0), ("orc_archer", 4, 20.0)], "posts": [("orc_archer", 4), ("orc_crossbow", 3)],
        "road_pts": [(14, 76), (-12, 56), (10, 34), (-4, 14)],
    },
    "fort_war": {
        "name": "Arraial de Ghar", "seed": 71, "quest": "hx_fort_war", "boss": "boss_ghar",
        "ground": (0.6, 0.48, 0.34), "patio": (0.5, 0.34, 0.28), "wall": horde.STAKE_DARK, "road": (0.5, 0.4, 0.32), "trail": (0.5, 0.38, 0.29),
        "outside": [("orc_warrior", 5, 20.0), ("wolf_raider", 2, 30.0), ("orc_warrior", 4, 20.0), ("goblin_agitator", 1, 90.0)],
        "inside": [("orc_warrior", 5, 20.0), ("goblin_agitator", 1, 90.0)], "posts": [("orc_warrior", 4), ("orc_warrior", 3)],
        "road_pts": [(-12, 78), (16, 58), (-10, 36), (2, 14)],
    },
}


def polar(z, ang_deg, inset):
    a = math.radians(ang_deg)
    r = z.rim_r(a) - inset
    return (round(math.cos(a) * r, 1), round(math.sin(a) * r, 1))


def standards(z, fid, name, p, rot=0.0, h=6.0):
    """Par de estandartes no mesmo mastro: vermelho da Horda (antes) e branco-dourado da Aurora (depois)."""
    horde.banner(z, "estandarte_horda_%s" % name, p, horde.HORDE_RED, h, rot)
    horde.banner(z, "estandarte_aurora_%s" % name, p, horde.AURORA_GOLD, h, rot, pole=(0.82, 0.68, 0.48))
    z.ob("pillar", p[0], p[1], (0.6, h, 0.6), visible=False)


def landmark(z, fid, cfg, q):
    """O que se vê no pátio de cada acampamento (e onde o chefe fica)."""
    c = FORT_C
    if fid == "fort_trolls":                          # boca de caverna no fundo da bacia, ossadas e pedregulhos
        rock = z.M["fort_wall"]
        cyl(z.coll, z.P + "toca_morro", (c[0], c[1] - 19), 11.0, 7.0, 6.0, rock, 0.0, 11, 0.2, 3)
        cyl(z.coll, z.P + "toca_pico", (c[0] - 2, c[1] - 21), 6.0, 2.0, 5.0, rock, 6.0, 9, 0.25, 5)
        box(z.coll, z.P + "toca_boca", (c[0], c[1] - 9.4), (6.0, 3.6, 2.4), 0.0, mat("dungeon_boca", (0.03, 0.03, 0.05)))
        z.ob("hill", c[0], c[1] - 19, (20.0, 8.0, 20.0), visible=False)
        horde.ribcage(z, "toca_ossada", (c[0] - 13, c[1] + 4), 1.2, 5)
        horde.skull(z, "toca_cranio", (c[0] + 14, c[1] + 2), 2.4, 1.1)
        for k in range(7):
            a = math.tau * k / 7 + 0.3
            z.ob("rock", c[0] + math.cos(a) * 20.0, c[1] + math.sin(a) * 19.0, (2.8 + (k % 3) * 0.6, 2.0, 2.6), k * 40.0, color=(0.5, 0.48, 0.48))
    elif fid == "fort_fire":                          # pira de sinal no meio, braseiros em roda, alvos de treino
        cyl(z.coll, z.P + "pira_base", (c[0], c[1] - 12), 3.4, 2.8, 2.4, mat("braseiro", (0.22, 0.2, 0.2)), 0.0, 10)
        cyl(z.coll, z.P + "pira_chama", (c[0], c[1] - 12), 2.4, 0.2, 5.0, mat("glow_brasa", (1.0, 0.56, 0.2)), 2.4, 8)
        z.ob("pillar", c[0], c[1] - 12, (6.6, 7.0, 6.6), visible=False)
        for k in range(6):
            a = math.tau * k / 6 + 0.5
            p = (c[0] + math.cos(a) * 19.0, c[1] + math.sin(a) * 19.0)
            cyl(z.coll, z.P + "braseiro_%d" % k, p, 0.7, 0.9, 1.1, mat("braseiro", (0.22, 0.2, 0.2)), 0.0, 8)
            cyl(z.coll, z.P + "braseiro_chama_%d" % k, p, 0.6, 0.1, 1.3, mat("glow_brasa", (1.0, 0.56, 0.2)), 1.1, 6)
            z.ob("pillar", p[0], p[1], (1.8, 2.0, 1.8), visible=False)
        for k, dx in enumerate((-15.0, -11.0, 11.0, 15.0)):
            z.ob("pillar", c[0] + dx, c[1] - 2.0, (0.6, 1.9, 0.6), color=(0.74, 0.62, 0.36))       # alvos de palha
    else:                                             # arena de Ghar: anel de dentro, tenda de comando, tambores
        z.ring_wall("arena", c, 13.0, [math.radians(90.0), math.radians(-90.0)], gate_half=3.4, height=2.6, material="fort_wall", stakes=True)
        disc(z.coll, z.P + "arena_chao", c, 12.0, 0.014, mat("patch_arena", (0.62, 0.5, 0.36)), 32)
        cone(z.coll, z.P + "tenda_ghar", (c[0], c[1] - 20.5), 6.0, 6.5, mat("pano_horda_tenda", horde.HORDE_RED), 0.0, 10)
        cone(z.coll, z.P + "tenda_ghar_aurora", (c[0], c[1] - 20.5), 6.1, 6.6, mat("teto_aurora", AURORA_BLUE), 0.0, 10)
        z.ob("pillar", c[0], c[1] - 20.5, (10.0, 6.5, 10.0), visible=False)
        for k, dx in enumerate((-17.0, 17.0)):
            horde.drum(z, "tambor_%d" % k, (c[0] + dx, c[1] + 6.0), 1.7)
        for k, dx in enumerate((-9.0, 9.0)):
            standards(z, fid, "arena_%d" % k, (c[0] + dx, c[1] - 15.0), 0.0, 8.0)


def build_one(fid, export=False):
    cfg = FORTS[fid]
    z = Zone(fid, seed=cfg["seed"], palette={
        "road": cfg["road"], "street": (0.56, 0.5, 0.42), "cliff_rock": (0.64, 0.47, 0.36), "cliff_rock_d": (0.5, 0.36, 0.29),
        "cliff_grass": cfg["ground"], "hill_grass": (0.74, 0.62, 0.38), "leaf": DRY[0], "wood": (0.5, 0.38, 0.26),
        "fort_wall": cfg["wall"], "patio": cfg["patio"], "chasm": (0.1, 0.08, 0.09), "estaca_horda": horde.STAKE_DARK,
        "patch_trilha": cfg["trail"],          # estrada na cor escolhida aqui (a "road" do jogo sai quase igual ao chão do acampamento)
    })
    q = cfg["quest"]
    before = {"unless": q}
    portal = polar(z, 90, 7)
    z.data["spawn"] = list(ARRIVE)
    z.portal("to_steppe", portal, "field_steppe", BACK[fid], "Estepes de Cinza")
    z.patch("chao", (0, 0), 110, cfg["ground"], grass=True)
    c = FORT_C
    gate_pt = (c[0], c[1] + FORT_R)
    road = [ARRIVE] + cfg["road_pts"] + [(gate_pt[0], gate_pt[1] + 2), (c[0], c[1] + 16.0)]
    z.road("subida", road, w=4.4, material="patch_trilha", end_clearing=False)
    z.arrival(ARRIVE, portal, 6.5, "patch_trilha")      # largo de terra na chegada e trilha até o portal (a estrada não nasce num corte reto)
    if fid == "fort_trolls":                          # fenda atravessada na subida: só a ponte passa
        z.river([(-130, 46), (-90, 40), (-50, 46), (-10, 41), (30, 45), (70, 39), (130, 44)], w=7.0, material="chasm")
        z.bridges()
    # ---------- postos avançados (um de cada lado da estrada) ----------
    posts = [(-56.0, 60.0 if fid == "fort_trolls" else 36.0), (54.0, 64.0 if fid == "fort_trolls" else 26.0)]
    for i, (p, (mob, n)) in enumerate(zip(posts, cfg["posts"])):
        z.road("posto_%d" % i, [road[1 + i], ((road[1 + i][0] + p[0]) * 0.5, (road[1 + i][1] + p[1]) * 0.5 + 6.0), p], w=3.2, material="patch_trilha")
        disc(z.coll, z.P + "posto_chao_%d" % i, p, 8.0, 0.012, z.M["street"], 24)
        for k in range(6):
            a = math.tau * k / 6 + 0.5
            z.ob("fence", p[0] + math.cos(a) * 7.0, p[1] + math.sin(a) * 7.0, (4.0, 1.4, 0.5), math.degrees(-a) + 90, color=horde.STAKE_DARK)
        z.ob("tent", p[0], p[1] - 2.5, (3.4, 2.4, 3.0), 0, color=horde.HORDE_RED, when=before)
        z.ob("tent", p[0], p[1] - 2.5, (3.4, 2.4, 3.0), 0, color=AURORA_BLUE, when={"if": q})
        standards(z, fid, "posto_%d" % i, (p[0] + 4.0, p[1] - 4.0), 0.0, 5.5)
        z.spawner(mob, p[0], p[1] + 1.0, 5, n, 22.0, when=before)
        z.npc("%s_post_spearman_%d" % (fid, i), p[0] + 2.0, p[1] + 3.0, 180.0)
        z.npc("%s_post_crossbow_%d" % (fid, i), p[0] - 2.0, p[1] + 3.0, 180.0)
        z.block(p, 9.0)
    # ---------- acampamento: muro (pedregulhos na Toca, estacas escuras nos outros), portão ao sul, pátio ----------
    disc(z.coll, z.P + "patio", c, FORT_R - 1.0, 0.012, mat("patch_patio_" + fid, cfg["patio"]), 48)
    z.data["roads"].append({"kind": "street", "w": 0, "pts": [list(c)], "r": FORT_R - 1.0})
    if fid == "fort_trolls":
        z.ring_wall("fortaleza", c, FORT_R, [math.radians(90.0)], gate_half=4.4, height=4.0, thick=3.0, material="fort_wall")
    else:
        z.ring_wall("fortaleza", c, FORT_R, [math.radians(90.0)], gate_half=4.2, height=3.6, material="fort_wall", stakes=True)
    z.data["town"] = {"center": list(c), "radius": FORT_R, "gates": [list(gate_pt)]}
    for k, sx in enumerate((-6.5, 6.5)):              # estandartes do portão e torres de vigia
        standards(z, fid, "portao_%d" % k, (gate_pt[0] + sx, gate_pt[1] + 1.5), 0.0, 7.0)
        horde.watchtower(z, "torre_%d" % k, (gate_pt[0] + sx * 1.9, gate_pt[1] - 3.5), horde.HORDE_RED if fid != "fort_trolls" else (0.5, 0.46, 0.44), 6.5)
    if fid == "fort_fire":                            # torres dos arqueiros ao longo da subida
        for k, p in enumerate(((-26, 66), (26, 46), (-24, 24), (20, 10))):
            horde.watchtower(z, "torre_estrada_%d" % k, p, horde.HORDE_RED, 7.0)
            z.block(p, 4.0)
    landmark(z, fid, cfg, q)
    for i in range(3):                                # jaulas dos colonos presos (somem na retomada: viram os colonos do posto)
        p = (c[0] - 20 + i * 4.0, c[1] + 12)
        for k in range(4):
            a = math.tau * k / 4 + math.pi / 4
            z.ob("pillar", p[0] + math.cos(a) * 1.4, p[1] + math.sin(a) * 1.4, (0.3, 2.4, 0.3), color=(0.3, 0.26, 0.24))
        z.npc("%s_prisoner_%d" % (fid, i), p[0], p[1], 180.0)
    for k, (dx, dy) in enumerate([(16, 12), (19, 16), (13, 18)]):       # posto aliado (depois da retomada)
        z.npc("%s_settler_%d" % (fid, k), c[0] + dx, c[1] + dy, 200.0)
    z.ob("anvil", c[0] + 18.5, c[1] + 10.0, (1.0, 0.9, 0.6), 30.0, when={"if": q})
    z.ob("stall", c[0] + 21.0, c[1] + 15.0, (3.0, 2.4, 2.0), 60.0, color=(0.82, 0.7, 0.36), when={"if": q})
    for i, role in enumerate(["knight", "knight", "spearman", "priest", "crossbow"]):
        z.npc("%s_g_%s_%d" % (fid, role, i), c[0] - 6 + i * 3.0, c[1] + FORT_R - 4.0, 180.0)
    bpos = (c[0], c[1] - 2.0) if fid != "fort_fire" else (c[0], c[1] - 2.0)
    z.spawner(cfg["boss"], bpos[0], bpos[1], 2, 1, 120.0, when=before)
    for i, (mob, n, resp) in enumerate(cfg["inside"]):
        a = math.radians(40.0 + i * 100.0)
        z.spawner(mob, c[0] + math.cos(a) * 17.0, c[1] + math.sin(a) * 14.0, 6, n, resp, when=before)
    for i, (mob, n, resp) in enumerate(cfg["outside"]):
        a = math.radians(-165 + i * 50)
        p = (round(math.cos(a) * 60, 1), round(math.sin(a) * 34 + (62 if fid == "fort_trolls" and i in (0, 3) else 44), 1))      # trolls: os dois de fora ficam aquém da fenda (z ~41-48), em chão seco
        z.spawner(mob, p[0], p[1], 9, n, resp, when=before)
    z.data["hangouts"] = [[ARRIVE[0] + dx, ARRIVE[1] - 8] for dx in (-4, 0, 4)]
    # ---------- chão: manchas de cinza, pedras, mesas na borda ----------
    drnd = random.Random(cfg["seed"] + 11)
    for i in range(9):
        a, r = drnd.uniform(0, math.tau), drnd.uniform(44, 92)
        p = (round(math.cos(a) * r, 1), round(math.sin(a) * r * 0.9 + 10, 1))
        if math.hypot(p[0] - c[0], p[1] - c[1]) > FORT_R + 12:
            z.patch("cinza_%d" % i, p, drnd.uniform(6.0, 10.0), [(0.62, 0.59, 0.54), (0.54, 0.51, 0.46)][i % 2])
    for i, (hc, r, lv) in enumerate([((-92.0, -30.0), 9.0, 3), ((92.0, -40.0), 8.0, 2), ((-84.0, 84.0), 7.0, 2), ((86.0, 88.0), 7.0, 2)]):
        z.hill("mesa_%d" % i, hc, r, lv, rock="cliff_rock", top="hill_grass", step=2.2)
    z.cliffs(snow=False)
    z.block((0, 0), 6)
    z.block(c, FORT_R + 4)
    z.block(ARRIVE, 8)
    z.scatter("tree", [((0, 0), 108, 26)], 0, (1.8, 4.0, 1.8), DRY, margin=4.8, spacing=7.0)
    z.rim_belt(50, (1.8, 4.0, 1.8), DRY)
    z.scatter("rock", [((0, 0), 105, 50 if fid == "fort_trolls" else 30)], 0, (1.5, 1.0, 1.3), [(0.58, 0.5, 0.44), (0.5, 0.46, 0.42)], margin=3.6, spacing=3.2, scale=(0.7, 1.8))
    nrnd = random.Random(cfg["seed"] + 5)
    obs = z.data["obstacles"]
    free = lambda x, zz, m: z.free(x, zz, m, 0.0)
    nature.fix_trees(obs, nrnd, dead=True, dead_cols=DRY)
    nature.scatter(z.ob, free, nrnd, "bush", [((0, 10), 100, 60)], (1.6, 0.85, 1.6), [(0.7, 0.6, 0.32), (0.62, 0.54, 0.3)], solid=False, margin=2.6, spacing=3.2, avoid=obs)
    if z.rivers:
        nature.clear_banks(obs, z.rivers, [], z.river_w)
    act2_dress.fort(z, fid, c, FORT_R, gate_pt, ARRIVE, posts, q)
    return z.finish(export, poi=(c[0], c[1] + 8.0), ground=cfg["ground"])


def build(export=False, only=None):
    out = []
    for fid in FORTS:
        if only and fid not in only:
            continue
        out.append(build_one(fid, export))
    return out
