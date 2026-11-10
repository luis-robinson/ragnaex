"""Bastião da Aurora (field_ruins, Lv 20-30): a última cidade da Luz, sitiada pelos mortos-vivos por três lados.
Cidade murada grande no centro (catedral com torre e flecha dourada = marco; mercado, quartel, casas) e a guarnição
da Aurora nos portões. Cada portão (O, N, S) dá para um front de guerra com a cor dele (pântano pútrido do Carniçal,
cinza de ossos, campo gelado da Torre) e uma garganta para a fortaleza daquele lado; por ali vêm as investidas.
O leste é o lado seguro: estrada para Aldara, cabanas, o rochedo do Dragonete. A Cripta fica no front norte.

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
RING_R = 56.0
PLAZA_R = 24.0                     # raio da praça (as avenidas dos portões chegam aqui)
WALL = (0.84, 0.82, 0.76)
ROOFS = [(0.3, 0.42, 0.7), (0.62, 0.24, 0.22), (0.36, 0.5, 0.74), (0.7, 0.58, 0.36)]
# fronts: ângulo do portão e da garganta, cor do chão queimado, monstros do lado e a quest que o cala
FRONTS = {
    "ghoul": {"deg": 180.0, "ground": (0.46, 0.43, 0.26), "quest": "dw_ghoul_boss", "fort_name": "Covil do Carniçal"},
    "bones": {"deg": -90.0, "ground": (0.6, 0.58, 0.54), "quest": "dw_bones_boss", "fort_name": "Fortaleza dos Ossos"},
    "frost": {"deg": 90.0, "ground": (0.68, 0.78, 0.86), "quest": "dw_frost_boss", "fort_name": "Torre do Mago Gélido"},
}
FORT_ARRIVE = (0.0, 96.0)       # chegada nos mapas das fortalezas (build_dawn_forts.ARRIVE_IN_FORT)
CITADEL_DEG = -48.0
DRAGON = (72.0, 52.0)
DEAD_TREES = [(0.42, 0.38, 0.32), (0.5, 0.45, 0.36)]

PLACES = [
    {"type": "cabin", "id": "coveiro", "pos": (74.0, -38.0), "face": 160.0, "npc": "gravedigger_osric", "roof": (0.34, 0.32, 0.36), "wall": (0.5, 0.46, 0.42)},
    {"type": "cabin", "id": "escavacao", "pos": (60.0, 92.0), "face": 200.0, "npc": "digger_vera", "roof": (0.58, 0.44, 0.3), "wall": (0.6, 0.5, 0.38)},
    {"type": "shrine", "id": "capela", "pos": (96.0, 22.0), "npc": "dawn_board", "ground": (0.82, 0.78, 0.68)},
    {"type": "camp", "id": "ninho_putrido", "pos": (-70.0, 42.0), "face": 200.0, "mob": "rot_ghoul", "count": 3, "cloth": (0.4, 0.46, 0.3), "respawn": 22.0,
     "when": {"unless": "dw_ghoul_boss"}},
    {"type": "dungeon", "id": "cripta", "dungeon": "dg_cripta"},
]


def polar(z, ang_deg, inset):
    a = math.radians(ang_deg)
    r = z.rim_r(a) - inset
    return (round(math.cos(a) * r, 1), round(math.sin(a) * r, 1))


H = lambda r, a: (round(math.cos(math.radians(a)) * r, 2), round(math.sin(math.radians(a)) * r, 2))


def cathedral(z, c, S=0.72):
    """Catedral da Aurora (escala S): nave e transepto em cruz, telhados azuis, torre central com flecha dourada (o marco
    que se vê de qualquer ponto do vale). Colisão por caixas invisíveis; a praça fica em volta."""
    stone, roof = z.M["cathedral_stone"], z.M["roof_blue"]
    gold, glass, dark = z.M["gold"], z.M["glass"], z.M["cathedral_trim"]
    P = lambda dx, dy: (c[0] + dx * S, c[1] + dy * S)
    box(z.coll, z.P + "catedral_nave", c, (26.0 * S, 9.0 * S, 10.0 * S), 0.0, stone, 0.0)
    box(z.coll, z.P + "catedral_transepto", c, (10.0 * S, 9.0 * S, 22.0 * S), 0.0, stone, 0.0)
    box(z.coll, z.P + "catedral_telhado_nave", c, (27.0 * S, 2.4 * S, 7.0 * S), 0.0, roof, 9.0 * S)
    box(z.coll, z.P + "catedral_telhado_trans", c, (7.0 * S, 2.4 * S, 23.0 * S), 0.0, roof, 9.0 * S)
    cyl(z.coll, z.P + "catedral_torre", c, 4.2 * S, 3.8 * S, 22.0 * S, stone, 0.0, 12)
    cyl(z.coll, z.P + "catedral_flecha", c, 4.0 * S, 0.25, 11.0 * S, roof, 22.0 * S, 12)
    cyl(z.coll, z.P + "catedral_sol", c, 1.2, 1.2, 0.5, gold, 33.0 * S, 12)
    for sx in (-1, 1):                                    # torres da fachada (oeste) e da abside (leste)
        for sy in (-1, 1):
            p = P(sx * 12.0, sy * 4.2)
            cyl(z.coll, z.P + "catedral_torreta_%d_%d" % (sx, sy), p, 1.5 * S, 1.3 * S, 12.0 * S, stone, 0.0, 8)
            cyl(z.coll, z.P + "catedral_cone_%d_%d" % (sx, sy), p, 1.6 * S, 0.1, 4.0 * S, roof, 12.0 * S, 8)
    for i in range(-5, 6):                                # contrafortes e vitrais nas laterais da nave
        if i == 0:
            continue
        for sy in (-1, 1):
            box(z.coll, z.P + "catedral_contraforte_%d_%d" % (i, sy), P(i * 2.2, sy * 5.4), (0.8 * S, 7.0 * S, 0.9 * S), 0.0, dark, 0.0)
            if abs(i) < 5 and abs(i) != 1:
                box(z.coll, z.P + "catedral_vitral_%d_%d" % (i, sy), P(i * 2.2 + 1.1, sy * 5.05), (0.9 * S, 3.6 * S, 0.15), 0.0, glass, 3.2 * S)
    for sx in (-1, 1):                                    # vitrais do transepto
        for k in (-1, 1):
            box(z.coll, z.P + "catedral_vitral_t_%d_%d" % (sx, k), P(k * 2.0, sx * 11.05), (1.0 * S, 3.8 * S, 0.15), 0.0, glass, 3.2 * S)
    box(z.coll, z.P + "catedral_porta", P(-13.05, 0), (0.2, 4.6 * S, 3.2 * S), 0.0, gold, 0.0)      # portal dourado (oeste)
    cyl(z.coll, z.P + "catedral_rosacea", P(-13.1, 0), 1.6 * S, 1.6 * S, 0.2, glass, 6.0 * S, 16)
    box(z.coll, z.P + "catedral_cornija", c, (26.4 * S, 0.5, 10.4 * S), 0.0, dark, 8.6 * S)
    z.ob("wall", c[0], c[1], (26.5 * S, 9.0 * S, 10.5 * S), visible=False)
    z.ob("wall", c[0], c[1], (10.5 * S, 9.0 * S, 22.5 * S), visible=False)
    z.block(c, 18.0 * S)


def wall_towers(z, gate_deg):
    """12 torres na muralha (fora dos portões): base larga, ameias, flâmula azul e um besteiro lá em cima."""
    stone, roof = z.M["town_wall"], z.M["roof_blue"]
    for k in range(12):
        a = 15.0 + 30.0 * k
        if any(abs((a - g + 180.0) % 360.0 - 180.0) < 10.0 for g in gate_deg):
            continue
        p = H(RING_R, a)
        cyl(z.coll, z.P + "torre_%d" % k, p, 3.0, 2.7, 8.0, stone, 0.0, 10)
        for m in range(8):                                # ameias
            b = math.tau * m / 8
            box(z.coll, z.P + "torre_%d_ameia_%d" % (k, m), (p[0] + math.cos(b) * 2.4, p[1] + math.sin(b) * 2.4), (1.0, 1.0, 0.7), math.degrees(-b), stone, 8.0)
        cyl(z.coll, z.P + "torre_%d_mastro" % k, (p[0] + 1.6, p[1]), 0.08, 0.08, 4.0, z.M["cathedral_trim"], 8.0, 4)
        box(z.coll, z.P + "torre_%d_flamula" % k, (p[0] + 2.2, p[1]), (1.2, 0.8, 0.06), 0.0, roof, 10.8)
        z.ob("pillar", p[0], p[1], (6.0, 8.0, 6.0), visible=False)
        z.npc("dawn_g_tower_wall_%d" % k, p[0], p[1], round(math.degrees(math.atan2(math.cos(math.radians(a)), math.sin(math.radians(a)))), 1))


def build(export=False):
    z = Zone(ZONE, seed=9, palette={
        "road": (0.7, 0.64, 0.52), "street": (0.82, 0.78, 0.7), "cliff_rock": (0.56, 0.53, 0.5), "cliff_rock_d": (0.45, 0.42, 0.39), "cliff_grass": (0.5, 0.52, 0.42),
        "hill_grass": (0.52, 0.54, 0.44), "water_dark": (0.28, 0.32, 0.4), "stone_ruin": (0.7, 0.68, 0.62), "leaf": (0.4, 0.46, 0.36),
        "town_wall": WALL, "roof_blue": (0.3, 0.42, 0.72), "gold": (0.98, 0.8, 0.32), "cathedral_stone": (0.86, 0.8, 0.68),
        "cathedral_trim": (0.62, 0.56, 0.48), "glass": (0.45, 0.65, 0.95), "putrid": (0.45, 0.68, 0.22), "clean_grass": (0.46, 0.66, 0.36),
    })
    rnd = random.Random(21)
    portal = polar(z, -3, 7)
    arrive = polar(z, -3, 15)
    z.data["spawn"] = list(arrive)
    z.portal("to_town", portal, "city_aldara", places.grow_aldara((-98.3, -30.2)), "Vale de Aldara")

    # ---------- cidade: muro de pedra clara, 4 portões (L = Aldara; O, N, S = os fronts) ----------
    gate_deg = [0.0, 180.0, -90.0, 90.0]
    gates = [math.radians(a) for a in gate_deg]
    z.patch("campo_cidade", (0, 0), RING_R + 8, (0.56, 0.6, 0.44), grass=True)
    z.M["chao_cidade"] = zone_lib.mat("chao_cidade", (0.6, 0.56, 0.5))
    disc(z.coll, z.P + "chao_cidade", (0, 0), RING_R - 1.0, 0.009, z.M["chao_cidade"], 64, 0.02, 3)
    z.M["pave_praca"] = zone_lib.mat("pave_praca", (0.78, 0.72, 0.62))
    z.plaza("praca", (0, 0), PLAZA_R, "pave_praca")
    z.ring_wall("cidade", (0, 0), RING_R, gates, gate_half=4.0, height=4.2, thick=1.8, material="town_wall", towers=0)
    wall_towers(z, gate_deg)
    z.data["town"] = {"center": [0.0, 0.0], "radius": RING_R, "gates": [list(H(RING_R, a)) for a in gate_deg]}
    cathedral(z, (0.0, 0.0))
    for a in gate_deg:                                    # avenidas da praça aos portões
        z.road("av_%d" % int(a), [H(PLAZA_R, a), H(RING_R - 2.0, a)], w=4.4, material="road", end_clearing=False)
    z.road("anel", [H(30.0, 360.0 * k / 28) for k in range(29)], w=3.2, material="road", end_clearing=False)
    z.road("anel_externo", [H(45.0, 360.0 * k / 34) for k in range(35)], w=3.2, material="road", end_clearing=False)
    face = lambda a: round(math.degrees(math.atan2(-math.cos(math.radians(a)), -math.sin(math.radians(a)))), 1)
    near_gate = lambda a, tol: any(abs((a - g + 180.0) % 360.0 - 180.0) < tol for g in gate_deg)

    # ---------- bairros: mercado (SE), quartel (NO), jardim do claustro (NE), casas em dois anéis ----------
    MARKET, BARRACKS, CLOISTER, HALL = H(40.0, 45.0), H(40.0, -135.0), H(40.0, -45.0), H(40.0, 135.0)
    z.patch("mercado", MARKET, 10.0, (0.74, 0.56, 0.38))
    z.patch("quartel", BARRACKS, 11.0, (0.62, 0.56, 0.48))
    z.patch("claustro", CLOISTER, 10.0, (0.5, 0.66, 0.42), grass=True)
    z.patch("salao", HALL, 10.0, (0.7, 0.66, 0.6))
    for i in range(6):
        a = math.tau * (i + 0.5) / 6
        z.ob("stall", MARKET[0] + math.cos(a) * 7.0, MARKET[1] + math.sin(a) * 7.0, (3.0, 2.4, 2.0), math.degrees(-a) + 90, color=ROOFS[i % 4])
    z.ob("fountain", MARKET[0], MARKET[1], (3.0, 1.6, 3.0))
    for k in range(-2, 3):                                # quartel: bonecos de treino e baias de armas
        z.ob("pillar", BARRACKS[0] + k * 3.0, BARRACKS[1] - 4.0, (0.5, 1.9, 0.5), color=(0.7, 0.55, 0.36))
    for k in (-1, 1):
        z.ob("fence", BARRACKS[0] + 8.0 * k, BARRACKS[1], (0.4, 1.2, 6.0))
    z.ob("tent", BARRACKS[0], BARRACKS[1] + 4.0, (4.0, 2.6, 3.2), 0, color=(0.36, 0.48, 0.78))
    z.lake("fonte_claustro", CLOISTER, 3.0, "water")
    for i in range(8):
        a = math.tau * i / 8
        z.ob("flowers", CLOISTER[0] + math.cos(a) * 6.0, CLOISTER[1] + math.sin(a) * 6.0, (2.0, 0.5, 2.0), solid=False, color=(0.95, 0.9, 0.6))
    z.ob("statue", HALL[0], HALL[1], (2.2, 3.0, 2.2), color=(0.9, 0.86, 0.72))
    k = 0
    for ring_r, n in ((36.0, 18), (51.0, 30)):
        for i in range(n):
            a = 360.0 * (i + 0.5) / n
            if near_gate(a, 9.0 if ring_r < 40 else 6.0):
                continue
            x, y = H(ring_r, a)
            if any(math.hypot(x - d[0], y - d[1]) < 12.5 for d in (MARKET, BARRACKS, CLOISTER, HALL)):
                continue
            z.ob("house", x, y, (5.0 if ring_r > 40 else 4.4, 3.4 + (k % 3) * 0.4, 4.4), face(a), color=(0.9, 0.86, 0.76), roof=ROOFS[k % 4])
            k += 1
    for a in range(0, 360, 30):
        if not near_gate(a, 8.0):
            z.ob("lamp", *H(27.5, a), (0.4, 3.2, 0.4))
    # NPCs de serviço (na praça, em volta da catedral) e a guarnição dos portões
    for nid, a, r in (("dawn_commander", 160.0, 20.0), ("high_priest", -160.0, 20.0), ("ruins_scholar", -20.0, 20.0), ("dawn_smith", 20.0, 20.0),
                      ("dawn_alchemist", 112.0, 24.0), ("dawn_relic", -68.0, 21.0), ("dawn_storage", 68.0, 21.0)):
        x, y = H(r, a)
        z.npc(nid, x, y, face(a))
    z.npc("dawn_merchant", MARKET[0] - 3.0, MARKET[1] - 3.0, 225.0)
    roles = ["knight", "knight", "spearman", "spearman", "priest", "crossbow", "crossbow"]
    slots = [(51.5, -2.4), (51.5, 2.4), (48.0, -2.6), (48.0, 2.6), (44.0, 0.0), (41.0, -2.4), (41.0, 2.4)]
    for side, f in FRONTS.items():
        g = f["deg"]
        for i, role in enumerate(roles):
            r, t = slots[i]
            x, y = H(r, g)
            tx, ty = -math.sin(math.radians(g)) * t, math.cos(math.radians(g)) * t
            z.npc("dawn_g_%s_%s_%d" % (side, role, i), round(x + tx, 2), round(y + ty, 2), face(g) + 180.0)
    for i, role in enumerate(["spearman", "spearman"]):
        z.npc("dawn_g_east_%s_%d" % (role, i), 50.0, -2.4 + i * 4.8, 90.0)
    for i in range(2):                                    # paladinos rondando o anel
        x, y = H(30.0, 90.0 + i * 180.0)
        z.npc("dawn_g_ring_paladin_%d" % i, x, y, 0.0)
    z.data["hangouts"] = [list(H(18.0, a)) for a in range(0, 360, 45)]

    # ---------- fronts: estrada do portão à garganta, chão queimado, trincheira, barricadas e posto avançado ----------
    raids = []
    clean_flowers = []                                     # flores do front limpo: postas depois do rio (fora d'água e das estradas)
    for side, f in FRONTS.items():
        g = f["deg"]
        gorge_out = polar(z, g, 9)
        gorge_in = polar(z, g, 22)
        mid = H(86.0, g + 9.0)
        outer = H(RING_R + 6.0, g)
        z.road("front_" + side, [H(RING_R + 1.0, g), outer, mid, gorge_in, gorge_out], w=4.0, end_clearing=False)
        z.portal("to_fort_" + side, gorge_out, "fort_" + side, FORT_ARRIVE, f["fort_name"])
        print("BACK", side, gorge_in)
        z.patch("front_" + side, H(84.0, g), 26.0, f["ground"])
        for j in range(-4, 5):                            # barricada de estacas em arco, com vão na estrada
            a = g + j * 6.0
            if abs(j) <= 1:
                continue
            x, y = H(72.0, a)
            z.ob("fence", x, y, (4.4, 1.3, 0.5), face(a) + 90.0, color=(0.46, 0.36, 0.26))
        if side == "ghoul":                               # poças de bile no pântano do Carniçal
            for q in range(7):
                pp = H(78.0 + (q % 3) * 7.0, g - 16.0 + q * 5.5)
                disc(z.coll, z.P + "chao_front_ghoul_bile_%d" % q, pp, 2.2 + (q % 2), 0.02, z.M["putrid"], 14, 0.3, q)
        # front limpo (aparece quando a fortaleza do lado cai): grama, flores e um acampamento da Aurora no caminho do reforço
        disc(z.coll, z.P + "limpo_%s_chao" % side, H(84.0, g), 25.0, 0.004, z.M["clean_grass"], 36, 0.1, len(side))     # abaixo das estradas
        cw = {"if": f["quest"]}
        frnd = random.Random(len(side) * 7)
        for k in range(14):
            fx, fy = H(70.0 + frnd.uniform(0, 30), g + frnd.uniform(-18, 18))
            clean_flowers.append((fx, fy, [(0.95, 0.9, 0.55), (0.9, 0.6, 0.7), (0.7, 0.8, 0.95)][k % 3], cw))
        camp_c = H(92.0, g - 14.0)
        for k in range(3):
            a = math.radians(g - 14.0) + (k - 1) * 0.5
            z.ob("tent", camp_c[0] + math.cos(a + 1.6) * 5.0, camp_c[1] + math.sin(a + 1.6) * 5.0, (3.4, 2.4, 3.0), face(g) + (k - 1) * 30, color=(0.36, 0.48, 0.78), when=cw)
        for k in (-1, 1):
            bx, by = H(78.0, g + k * 6.0)
            z.ob("pillar", bx, by, (0.4, 4.0, 0.4), color=(0.85, 0.75, 0.4), when=cw)
            z.ob("lamp", bx + 1.0, by, (0.4, 3.0, 0.4), when=cw)
        z.ob("statue", camp_c[0], camp_c[1], (1.6, 2.4, 1.6), color=(0.92, 0.88, 0.72), when=cw)
        post = H(72.0, g + 30.0)                           # posto avançado da Aurora: tenda e fogueira
        z.ob("tent", post[0], post[1], (3.6, 2.4, 3.2), face(g + 30.0), color=(0.36, 0.48, 0.78))
        z.npc("dawn_g_%s_post_spearman_0" % side, post[0] + 3.0, post[1], face(g))
        z.npc("dawn_g_%s_post_crossbow_1" % side, post[0] - 3.0, post[1], face(g))
        z.block(post, 5.0)
        raids.append({"side": side, "from": list(gorge_in), "route": [list(mid), list(outer)], "target": [0.0, 0.0], "radius": RING_R - 6.0,
                      "unless": f["quest"]})
    z.data["raids"] = raids
    # reforço das fortalezas retomadas: sai da mesma garganta da investida, faz a mesma rota até o portão do lado e segue a
    # avenida até a borda da praça; ronda ali, do lado dele (a catedral no meio da praça não é contornada pela ronda)
    deg_of = {s: f["deg"] for s, f in FRONTS.items()}
    z.data["assaults"] = [{"id": "reforco_" + r["side"], "from": r["from"],
                           "route": list(r["route"]) + [list(H(RING_R - 2.0, deg_of[r["side"]])), list(H(PLAZA_R, deg_of[r["side"]]))],
                           "target": list(H(PLAZA_R - 6.0, deg_of[r["side"]])), "radius": 5.0}
                          for r in raids]

    # ---------- selo da Cidadela do Lich (garganta NE): abre com as três fortalezas retomadas ----------
    cit_out, cit_in = polar(z, CITADEL_DEG, 7), polar(z, CITADEL_DEG, 18)
    z.road("cidadela", [H(RING_R + 6.0, -90.0), H(76.0, -70.0), cit_in, cit_out], w=4.0, end_clearing=False)
    z.portal("to_lich_citadel", cit_out, "lich_citadel", FORT_ARRIVE, "Cidadela do Lich")
    print("BACK citadel", cit_in)
    # ---------- leste seguro: estrada de Aldara, rochedo do Dragonete ----------
    z.road("E", [H(RING_R + 1.0, 0.0), (72, 4), (88, -4), arrive, portal], end_clearing=False)
    z.road("dragao", [(72, 4), (80, 30), (DRAGON[0] - 6, DRAGON[1] - 10)])
    top = z.hill("rochedo", (DRAGON[0] + 12, DRAGON[1] + 10), 7, 3, rock="cliff_rock", top="stone_ruin", step=2.6)
    z.M["pave_altar"] = zone_lib.mat("pave_altar", (0.6, 0.52, 0.64))
    disc(z.coll, z.P + "dragao_base", DRAGON, 10.0, 0.016, z.M["pave_altar"], 32)
    z.data["roads"].append({"kind": "street", "w": 0, "pts": [list(DRAGON)], "r": 10.0})
    z.block(DRAGON, 12)

    # ---------- água: riacho escuro do norte ao sudoeste (pontes nas estradas) ----------
    z.river([(-30, -128), (-50, -96), (-66, -70), (-80, -40), (-84, -12), (-86, 18), (-96, 50), (-120, 80)], w=5.0, material="water_dark")
    z.bridges()
    for fx, fy, col, cw in clean_flowers:
        if z.free(fx, fy, 2.0, 0.0):
            z.ob("flowers", fx, fy, (1.8, 0.5, 1.8), color=col, when=cw)

    z.cliffs(snow=False)
    places.build(z, PLACES)

    # ---------- vegetação: árvores mortas nos fronts, mata viva no leste ----------
    z.block((0, 0), RING_R + 6)
    for side, f in FRONTS.items():
        z.block(H(84.0, f["deg"]), 10.0)
    z.scatter("tree", [((0, 0), 110, 80)], 0, (1.5, 3.3, 1.5), DEAD_TREES, margin=4.6, spacing=4.5, hub_r=RING_R + 8, scale=(0.8, 1.2))
    z.scatter("tree", [((85, 0), 30, 30)], 0, (2.0, 4.6, 2.0), [(0.3, 0.5, 0.32), (0.36, 0.56, 0.34)], margin=4.6, spacing=4.5, hub_r=RING_R + 8)
    z.rim_belt(110, (1.5, 3.3, 1.5), DEAD_TREES)
    z.scatter("rock", [((0, 0), 105, 50)], 0, (1.4, 0.9, 1.2), [(0.62, 0.6, 0.56)], margin=3.5, spacing=3.0, hub_r=RING_R + 6, scale=(0.7, 1.6))
    z.scatter("ruin", [((0, 0), 100, 22)], 0, (2.4, 1.6, 0.7), [(0.7, 0.68, 0.62)], margin=4.0, spacing=5.0, hub_r=RING_R + 8, scale=(0.7, 1.5))
    nrnd = random.Random(43)
    obs = z.data["obstacles"]
    fr = lambda x, zz, m: z.free(x, zz, m, RING_R + 8)
    nature.fix_trees(obs, nrnd, dead=True, dead_cols=[(0.42, 0.36, 0.3), (0.5, 0.44, 0.36), (0.36, 0.33, 0.3)])
    nature.scatter(z.ob, fr, nrnd, "bush", [((0, 0), 105, 40)], (1.6, 0.85, 1.6), [(0.42, 0.46, 0.3), (0.5, 0.5, 0.32)], solid=False, margin=2.6, spacing=3.0, avoid=obs)
    nature.woodland_floor(z.ob, fr, nrnd, [((0, 0), 100, 14)], bark=[(0.42, 0.38, 0.33), (0.36, 0.33, 0.3)], avoid=obs)
    nature.clear_banks(obs, z.rivers, [], z.river_w)
    nature.shore(z.ob, nrnd, z.rivers, [], list(z.road_polys.values()), z.river_w, colors=[(0.4, 0.48, 0.3), (0.46, 0.46, 0.32)], keep=0.75)

    # ---------- monstros dos fronts (calam quando a fortaleza do lado cai) ----------
    for side, mobs in (("ghoul", [("larva", 6, 14.0), ("rot_zombie", 4, 18.0), ("rot_ghoul", 3, 20.0), ("rot_wolf", 3, 20.0)]),
                       ("bones", [("skeleton", 5, 18.0), ("skel_archer", 3, 20.0), ("skel_guard", 2, 24.0)]),
                       ("frost", [("cultist", 4, 20.0), ("tower_bat", 4, 16.0), ("ghost", 3, 22.0)])):
        f = FRONTS[side]
        for i, (mid_, n, resp) in enumerate(mobs):
            x, y = H(88.0 + (i % 2) * 8.0, f["deg"] - 18.0 + i * 12.0)
            z.spawner(mid_, x, y, 8, n, resp, when={"unless": f["quest"]})
    z.spawner("dragonling", DRAGON[0], DRAGON[1], 2, 1, 120.0)          # chefe opcional do 30: volta em 2 min (era 5)
    return z.finish(export, poi=DRAGON, ground=(0.55, 0.56, 0.46))
