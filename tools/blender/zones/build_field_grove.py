"""Bosque dos Xamãs (field_grove, Lv 14-18): mata velha e funda a leste da Floresta Sombria, ramo lateral opcional.
Garganta única no oeste (volta para a Floresta), o Posto da Guardiã logo depois da chegada (amigo: 3 tendas, fogo, cerca
baixa; não é vila: sem muro, sem cristal), riacho norte-sul com três pontes, a Aldeia dos Xamãs no meio-leste (hostil: ocas
redondas de couro, totens, potes de fumaça, varais, roda de menires com o fogo dos espíritos) e, no fim da trilha, o
Bosque do Arquidruida (arena redonda de ~18 m cercada de árvores velhas e menires; chão livre para a luta de invocações).

    blender -b --factory-startup --python tools/blender/zones/run_zone.py -- build_field_grove <pasta_png> --export
"""
import math
import os
import random
import importlib
import nature
import zone_lib
importlib.reload(zone_lib)
from zone_lib import Zone
from dress import Dress

ZONE = "field_grove"
SIZE = 220.0
RIM = (99.0, 4.0, 2.5, 1.5)        # raio útil 91-107 m: a regra de borda do _check_zone_layout só conta acerto em r > 95
GROUND = (0.25, 0.42, 0.36)        # = MapDef.ground_color e loading_art.ZONES["field_grove"]["ground"] (verde-azulado, frio)
TRAIL_W = 3.0
GORGE_ANG = 184.0                  # garganta da Floresta (rumo ~274: o oposto da saída leste da Floresta, rumo ~94)
FOREST_ARRIVE = (87.4, 10.7)        # chegada na Floresta, junto da garganta leste (build_field_forest.GROVE_ARRIVE)
POST = (-58.0, -6.0)               # Posto da Guardiã (amigo)
POST_R = 9.5
GATES = {"O": 180.0, "N": -90.0, "L": 0.0, "S": 90.0}        # por onde as trilhas saem do posto (graus do jogo)
# Aldeia dos Xamãs (hostil). 2026-11-19 (pedido: "maior, com mais xamãs; é apertado e mal dá para passar"): raio 16 -> 22 m
# (área x1,9), 7 -> 10 ocas em dois anéis desencontrados, roda de menires no centro. Regra de folga: dentro da clareira dois
# sólidos ou se tocam ou ficam a >= 4 m (ruas de 5-6 m: anel da praça e as quatro entradas). Peça comprida (varal, frisa)
# colide como fila de círculos pequenos: o `pillar` da sim é círculo do MAIOR lado, um colisor só tapava a rua.
VILLAGE = (50.0, 13.0)
VILLAGE_R = 22.0
VILLAGE_CLEAR = VILLAGE_R + 7.0    # sem árvore/pedra até aqui (as ocas de fora ficam a >= 4 m da mata)
ENTRIES = {"O": 185.0, "N": 290.0, "L": 25.0, "S": 105.0}      # por onde as trilhas entram na aldeia (graus do jogo)
STONE_R = 6.0                      # roda de menires (6, um a cada 60 graus a partir de 30)
HUTS = [(14.2, 53.0, 1.0), (14.2, 133.0, 1.0), (14.0, 230.0, 1.15), (14.2, 335.0, 1.0),                 # anel de dentro (230 = oca do chefe)
        (19.0, 79.0, 0.9), (19.0, 159.0, 0.9), (19.0, 203.0, 0.9), (19.0, 257.0, 0.9), (19.0, 308.0, 0.9), (19.0, 2.0, 0.9)]   # (raio, ângulo, escala)
SPIKES = (53.0, 133.0, 230.0, 335.0)       # frisas atrás das ocas de dentro, no vão entre duas ocas de fora
RACKS = (79.0, 257.0, 2.0)                 # varais nas costas de três ocas de fora (encostados nelas)
DRUMS = ((30.0, 0.85), (90.0, 0.7), (150.0, 0.8), (270.0, 0.65))      # tambores encostados por fora nos menires
GROVE = (52.0, -50.0)              # Bosque do Arquidruida (chefe)
GROVE_R = 18.0
CALL = (14.0, 64.0)                # Roda dos Chamados (xamãs invocadores, sul)
WOLVES = (-44.0, -52.0)            # Toca dos Lobos (noroeste, lado do posto)
BEARS = (62.0, 56.0)               # Clareira dos Ursos (sudeste)
EAST = (75.0, 38.0)                # invocadores no arco leste (fora da clareira da aldeia)
POND = (-46.0, 58.0)               # Lagoa do Musgo
POND_R = 8.0
ELDER = (8.0, -30.0)               # Árvore Anciã (landmark)
ELDER2 = (-34.0, 26.0)
TREE_COLS = [(0.12, 0.31, 0.29), (0.16, 0.38, 0.33), (0.21, 0.44, 0.36)]
MOSS = (0.3, 0.52, 0.4)
SPIRIT = (0.45, 0.95, 0.82)        # fogo e runas dos espíritos (verde-água)
PAINT = (0.16, 0.44, 0.44)         # tinta dos xamãs (totens, barra das ocas)
BONE = (0.88, 0.84, 0.72)
OCHRE = (0.78, 0.56, 0.24)
COOL_FLOWERS = [(0.62, 0.8, 0.95), (0.8, 0.7, 0.96), (0.92, 0.96, 0.94)]


def polar(z, ang_deg, inset):
    a = math.radians(ang_deg)
    r = z.rim_r(a) - inset
    return (round(math.cos(a) * r, 1), round(math.sin(a) * r, 1))


def face_to(x, z, tx, tz):
    return round(math.degrees(math.atan2(tx - x, tz - z)), 1)


def door_rot(c, t):
    """Giro de uma tenda/oca em `t` com a porta virada para `c` (convenção do Dress.tent_*)."""
    return math.degrees(math.atan2(-(c[0] - t[0]), -(c[1] - t[1])))


def hut(d, c, rot, s=1.0):
    """Oca redonda dos xamãs: parede de pau a pique, teto cônico de couro com barra pintada, varas no topo, crânio na porta."""
    wall = d.m("oca_parede", (0.46, 0.37, 0.28))
    hide = d.m("oca_couro", (0.64, 0.52, 0.37))
    hide2 = d.m("oca_couro_b", (0.54, 0.42, 0.3))
    paint = d.m("oca_barra", PAINT)
    wood = d.m("tenda_vara", (0.36, 0.28, 0.2))
    d.cyl("oca", wall, c, 2.3 * s, 2.2 * s, 1.3 * s, 0.0, 9, rot)
    d.cyl("oca", hide, c, 3.0 * s, 0.4 * s, 2.3 * s, 1.2 * s, 9, rot)
    d.cyl("oca", paint, c, 3.04 * s, 2.5 * s, 0.45 * s, 1.2 * s, 9, rot, cap=False)
    d.cyl("oca", hide2, c, 1.5 * s, 0.42 * s, 1.0 * s, 2.42 * s, 9, rot + 20, cap=False)      # remendo escuro perto do topo
    for k in range(3):
        d.cyl("oca", wood, c, 0.05, 0.04, 1.3 * s, 3.0 * s, 4, rot + k * 60, tilt=(16, 0))
    a = math.radians(rot)
    dx, dz = -math.sin(a), -math.cos(a)
    q = (c[0] + dx * 2.2 * s, c[1] + dz * 2.2 * s)
    d.box("oca", d.m("tenda_boca", (0.12, 0.1, 0.1)), q, (1.0 * s, 1.35 * s, 0.3 * s), rot, 0.0)
    d.rock("oca", d.m("osso", (0.9, 0.87, 0.78)), (c[0] + dx * 2.45 * s, c[1] + dz * 2.45 * s), 0.24 * s, 1.5 * s, 0.9, sub=1)
    d.solid(c[0], c[1], 4.8 * s, 4.8 * s, 3.4)


def smoke_pot(d, c, s=1.0):
    """Pote de fumaça: vaso de barro com brasa e três tufos claros subindo (fumaça parada, lida de cima)."""
    d.cyl("pote", d.m("pote_barro", (0.5, 0.36, 0.28)), c, 0.34 * s, 0.46 * s, 0.55 * s, 0.0, 7)
    d.cyl("pote", d.m("pote_boca", PAINT), c, 0.48 * s, 0.4 * s, 0.1 * s, 0.55 * s, 7, cap=False)
    d.cyl("pote", d.m("glow_espirito", SPIRIT), c, 0.3 * s, 0.0, 0.3 * s, 0.56 * s, 5)
    sm = d.m("fumaca", (0.8, 0.86, 0.84))
    for k, (r, y) in enumerate(((0.3, 1.2), (0.25, 1.8), (0.17, 2.4))):
        d.rock("mini", sm, (c[0] + 0.12 * k * s, c[1] - 0.1 * k * s), r * s, y * s, 0.8, sub=1)


def rack(d, p0, p1, hides=2):
    """Varal de secar (peles e ervas) entre dois pontos."""
    wd = d.m("cavalete", (0.4, 0.3, 0.22))
    rot = zone_lib.along(p1[0] - p0[0], p1[1] - p0[1])
    L = math.hypot(p1[0] - p0[0], p1[1] - p0[1])
    mid = ((p0[0] + p1[0]) * 0.5, (p0[1] + p1[1]) * 0.5)
    for p in (p0, p1):
        d.cyl("armas", wd, p, 0.07, 0.06, 1.9, 0.0, 5)
    d.box("armas", wd, mid, (L + 0.2, 0.08, 0.08), rot, 1.8)
    cols = [d.m("pele_cervo", (0.6, 0.45, 0.3)), d.m("pele_lobo", (0.5, 0.5, 0.52)), d.m("erva_seca", (0.42, 0.56, 0.36))]
    for k in range(hides):
        t = (k + 0.5) / hides
        q = (p0[0] + (p1[0] - p0[0]) * t, p0[1] + (p1[1] - p0[1]) * t)
        d.box("armas", cols[k % 3], q, (L / hides * 0.72, 1.1, 0.06), rot, 0.66)
    chain(d, p0, p1, 0.6, 1.9)


def chain(d, p0, p1, w, h):
    """Colisor de peça comprida e fina: fila de círculos de diâmetro `w` de p0 a p1 (um `pillar` só viraria um círculo do
    comprimento inteiro)."""
    L = math.hypot(p1[0] - p0[0], p1[1] - p0[1])
    n = max(1, int(math.ceil(L / (w * 0.9))))
    for k in range(n + 1):
        t = k / n
        d.solid(p0[0] + (p1[0] - p0[0]) * t, p0[1] + (p1[1] - p0[1]) * t, w, w, h)


def gate_posts(poly, c, r, half):
    """Dois pontos, um de cada lado da trilha `poly`, onde ela cruza o círculo de raio `r` em volta de `c` (totens da entrada)."""
    k = min(range(1, len(poly) - 1), key=lambda i: abs(math.hypot(poly[i][0] - c[0], poly[i][1] - c[1]) - r))
    tx, tz = poly[k + 1][0] - poly[k - 1][0], poly[k + 1][1] - poly[k - 1][1]
    tl = math.hypot(tx, tz)
    nx, nz = -tz / tl, tx / tl
    return [(poly[k][0] + nx * half * sg, poly[k][1] + nz * half * sg) for sg in (-1, 1)], zone_lib.along(tx, tz)


def build(export=False):
    z = Zone(ZONE, size=SIZE, rim=RIM, seed=9, palette={
        "leaf": (0.13, 0.33, 0.3), "cliff_grass": (0.2, 0.38, 0.33), "hill_grass": (0.26, 0.45, 0.37),
        "cliff_rock": (0.36, 0.39, 0.38), "road": (0.5, 0.45, 0.36), "water": (0.26, 0.54, 0.56),
    })
    px, pz = POST
    P = lambda r, a: (px + math.cos(math.radians(a)) * r, pz + math.sin(math.radians(a)) * r)
    V = lambda r, a: (VILLAGE[0] + math.cos(math.radians(a)) * r, VILLAGE[1] + math.sin(math.radians(a)) * r)
    G = lambda r, a: (GROVE[0] + math.cos(math.radians(a)) * r, GROVE[1] + math.sin(math.radians(a)) * r)
    portal = polar(z, GORGE_ANG, 7)
    arrive = polar(z, GORGE_ANG, 15)
    z.data["spawn"] = list(arrive)
    z.data["arrive_from_field_forest"] = list(arrive)
    z.cam_game = {"posto": POST, "chamados": CALL}.get(os.environ.get("GROVE_CAM", ""), VILLAGE)      # só a foto de revisão
    z.portal("to_field_forest", portal, "field_forest", FOREST_ARRIVE, "Floresta Sombria")
    z.block(arrive, 7.5)

    # ---------- chão por região (lido de cima): terreiro do posto, terra escura da aldeia, laje musgosa da arena ----------
    z.patch("posto", POST, POST_R + 1.5, (0.55, 0.5, 0.38), y=0.0104)            # acima do acostamento (9,8 mm)
    z.patch("aldeia", VILLAGE, VILLAGE_R + 1.5, (0.4, 0.38, 0.31), y=0.0104)
    z.patch("arena", GROVE, GROVE_R, (0.36, 0.45, 0.4), y=0.0104)
    z.patch("chamados", CALL, 11.0, (0.4, 0.42, 0.33))
    z.patch("lobos", WOLVES, 10.0, (0.3, 0.44, 0.36), grass=True)
    z.patch("ursos", BEARS, 10.0, (0.33, 0.46, 0.34), grass=True)
    z.patch("leste", EAST, 7.5, (0.36, 0.42, 0.33), grass=True)
    z.data["town"] = {"center": [px, pz], "radius": 0.0, "gates": []}

    # ---------- riacho (norte-sul, separa o posto da aldeia) e a Lagoa do Musgo ----------
    z.river([(-30, -124), (-28, -90), (-18, -62), (-22, -36), (-14, -10), (-18, 18), (-10, 44), (-16, 72), (-8, 100), (-4, 126)], w=4.5)
    z.lake("lagoa", POND, POND_R)

    # ---------- trilhas (estreitas, curvas; laços norte, sul e leste: sem beco) ----------
    g = lambda k: P(POST_R - 2.5, GATES[k])
    vw, vn, vs, ve = V(VILLAGE_R - 3.0, ENTRIES["O"]), V(VILLAGE_R - 2.0, ENTRIES["N"]), V(VILLAGE_R - 2.0, ENTRIES["S"]), V(VILLAGE_R - 2.0, ENTRIES["L"])
    g_s, g_w = G(GROVE_R - 5.0, 86.0), G(GROVE_R - 5.0, 188.0)
    z.road("chegada", [g("O"), (-74, -8), arrive, portal], w=TRAIL_W, end_clearing=False)
    r_vau = z.road("vau", [g("L"), (-40, -3), (-28, -7), (-15, -4), (-3, -3), (10, 4), (22, 9), vw], w=TRAIL_W, end_clearing=False)
    r_bosque = z.road("bosque", [vn, (61, -16), (58, -27), g_s], w=TRAIL_W, end_clearing=False)
    r_sul = z.road("sul", [vs, (40, 42), (27, 54), (CALL[0] + 3, CALL[1] - 4)], w=TRAIL_W, end_clearing=False)
    z.road("arco_sul", [(CALL[0] + 3, CALL[1] - 4), (0, 68), (-14, 70), (-28, 64), (-36, 46), (-46, 34), (-54, 18), g("S")], w=TRAIL_W, end_clearing=False)
    z.road("norte", [g("N"), (-56, -30), (WOLVES[0] + 4, WOLVES[1] + 6), (-34, -60), (-19, -64), (-4, -62), (14, -60), (30, -56), g_w],
           w=TRAIL_W, end_clearing=False)
    r_leste = z.road("arco_leste", [ve, (EAST[0] + 2, EAST[1] - 6), (73, 48), (BEARS[0] - 4, BEARS[1] - 2), (40, 42)], w=TRAIL_W, end_clearing=False)
    z.arrival(arrive, toward=portal, r=6.0)
    gates = [gate_posts(poly, VILLAGE, VILLAGE_R + 4.5, 3.8) for poly in (r_vau, r_bosque, r_sul, r_leste)]      # totens das 4 entradas
    z.bridges()

    # ---------- relevo: afloramentos baixos e as duas árvores anciãs (landmarks, fora das trilhas) ----------
    for i, (c, r, lv) in enumerate([((-74, -44), 7, 2), ((-20, 44), 5, 1), ((20, 33), 6, 2), ((84, -10), 7, 2),
                                    ((20, -84), 6, 2), ((-76, 38), 6, 2), ((30, 84), 6, 1), ((6, 22), 5, 1)]):
        z.terrace("afloramento_%d" % i, c, r, lv, top="cliff_grass")
    z.giant_tree("arvore_ancia", ELDER, trunk_r=2.8, height=20.0)
    z.giant_tree("arvore_ancia_b", ELDER2, trunk_r=2.2, height=16.0)
    z.cliffs()

    # ---------- vegetação: mata velha e fechada, só as clareiras e as trilhas abertas ----------
    for c, r in ((POST, POST_R + 4.0), (VILLAGE, VILLAGE_CLEAR), (GROVE, GROVE_R + 5.5), (CALL, 13.0), (WOLVES, 9.5), (BEARS, 9.5), (EAST, 7.5)):
        z.block(c, r)
    for posts, _rot in gates:              # mata a >= 4 m dos totens das entradas
        for q in posts:
            z.block(q, 6.2)
    z.scatter("tree", [((-72, -66), 24, 55), ((-76, 60), 22, 45), ((0, -84), 22, 45), ((84, -30), 16, 26),
                       ((20, 86), 20, 36), ((-30, -24), 16, 28), ((24, -24), 18, 34), ((20, 30), 16, 28), ((-40, 30), 14, 20),
                       ((84, 14), 14, 22), ((40, 70), 14, 22), ((-6, -44), 14, 20), ((76, -60), 14, 20)],
              0, (1.6, 3.6, 1.6), TREE_COLS, margin=3.4, spacing=3.4, scale=(1.15, 1.9))
    z.scatter("tree", [((0, 0), 104, 440)], 0, (1.6, 3.6, 1.6), TREE_COLS, margin=3.6, spacing=3.4, scale=(1.0, 1.7))
    z.rim_belt(150, (1.6, 3.6, 1.6), TREE_COLS[:2])
    z.scatter("rock", [(GROVE, 30, 8), (WOLVES, 16, 8), ((0, 0), 96, 24)], 0, (1.4, 0.9, 1.2), [(0.42, 0.47, 0.45)],
              margin=3.0, spacing=2.5, scale=(0.8, 1.6))

    nrnd = random.Random(97)
    obs = z.data["obstacles"]
    fr = lambda x, zz, m: z.free(x, zz, m)
    nature.fix_trees(obs, nrnd, pine_frac=0.1)
    nature.scatter(z.ob, fr, nrnd, "bush", [((0, 0), 100, 140)], (1.7, 0.95, 1.7), [(0.15, 0.36, 0.31), (0.2, 0.43, 0.35), (0.26, 0.48, 0.36)],
                   solid=False, margin=2.2, spacing=2.6, avoid=obs)
    nature.scatter(z.ob, fr, nrnd, "flowers", [((0, 0), 98, 26), (WOLVES, 9, 5), (BEARS, 9, 5)], (1.6, 0.45, 1.6), COOL_FLOWERS,
                   solid=False, margin=2.4, spacing=3.6, avoid=obs)
    nature.woodland_floor(z.ob, fr, nrnd, [((-72, -66), 24, 9), ((-76, 60), 22, 8), ((0, -84), 22, 8), ((20, 86), 20, 7), ((0, 0), 96, 26)], avoid=obs)

    # Bosque do Arquidruida: anel de menires em toda a volta e árvores velhas atrás deles, só do lado norte (a câmera olha do
    # sul: nada alto entre ela e a luta). As duas bocas das trilhas (sul e oeste) ficam abertas.
    ring = []
    for k in range(16):
        a = 11.25 + 22.5 * k
        if min(abs((a - e + 180.0) % 360.0 - 180.0) for e in (86.0, 188.0)) < 12.0:
            continue
        ring.append(a)
        if math.sin(math.radians(a)) < 0.3:
            q = G(GROVE_R + 3.4, a + 5.0)
            s = 2.3 + 0.35 * (k % 3)
            z.ob("tree", q[0], q[1], (1.6 * s, 3.6 * s, 1.6 * s), color=TREE_COLS[k % 2])
    nature.clear_banks(obs, z.rivers, [(POND, POND_R)], z.river_w)
    nature.shore(z.ob, nrnd, z.rivers, [(POND, POND_R)], list(z.road_polys.values()), z.river_w)

    # ---------- NPCs e pontos de bot (nomes/papéis: world-builder, MapsCatalog.PLACE_NPCS["field_grove"]) ----------
    fire = (px + 0.5, pz + 0.5)
    warden = (px - 1.6, pz - 2.2)
    herbalist = P(5.4, 128.0)
    scout = P(4.2, 22.0)
    for nid, p in (("grove_warden", warden), ("grove_herbalist", herbalist), ("grove_scout", scout)):
        z.npc(nid, round(p[0], 2), round(p[1], 2), face_to(p[0], p[1], *fire))
    z.data["hangouts"] = [[round(q[0], 2), round(q[1], 2)] for q in (P(3.6, 60.0), P(3.4, 205.0), P(5.2, -100.0), P(6.4, -20.0), P(6.4, 70.0),
                                                                    P(6.2, 165.0), P(13.5, 180.0), P(13.5, 0.0))]

    # ---------- monstros (ids do plano; modelos mob_<id> e dados feitos à parte) ----------
    # aldeia: 12 Metamorfos em 6 duplas + 5 Chamadores (antes 8 + 2), espalhados para puxar 1-3 por vez. Nenhum a menos de
    # 40 m da origem (regra do _check_zone_layout): o lado oeste da aldeia só tem a dupla do anel da praça.
    for r, a, n in ((16.0, ENTRIES["L"], 2), (16.0, ENTRIES["S"], 2), (16.0, ENTRIES["N"] - 2.0, 2), (10.5, 190.0, 2),
                    (25.0, 335.0, 2), (25.0, 133.0, 2)):
        q = V(r, a)
        z.spawner("shaman_shifter", round(q[0], 1), round(q[1], 1), 3.5 if r > 12.0 else 3.0, n, 20.0)
    z.spawner("shaman_caller", VILLAGE[0] + 2.5, VILLAGE[1] - 1.0, 3.0, 2, 22.0)      # roda de menires
    for a in (20.0, 100.0, 300.0):                                                    # um atrás de cada dupla das entradas
        q = V(10.5, a)
        z.spawner("shaman_caller", round(q[0], 1), round(q[1], 1), 2.5, 1, 22.0)
    z.spawner("shaman_shifter", 38, -18, 5, 3, 20.0)                              # sentinelas a noroeste da aldeia
    z.spawner("shaman_shifter", 61, -21, 6, 3, 20.0)                              # guardam a trilha do bosque
    z.spawner("shaman_shifter", 33, 48, 6, 3, 20.0)                               # trilha sul
    z.spawner("shaman_caller", CALL[0] + 2.5, CALL[1] - 1.5, 7, 3, 22.0)                      # Roda dos Chamados
    z.spawner("shaman_caller", EAST[0], EAST[1], 6, 3, 22.0)                      # arco leste
    z.spawner("grove_wolf", WOLVES[0], WOLVES[1], 8, 4, 16.0)                           # Toca dos Lobos (borda noroeste)
    z.spawner("grove_bear", BEARS[0], BEARS[1], 7, 3, 20.0)                             # Clareira dos Ursos (borda sudeste)
    z.spawner("boss_archdruid", GROVE[0], GROVE[1], 2, 1, 180.0)                  # Bosque do Arquidruida (chefe)

    # ---------- acabamento (dress.py) ----------
    # pilha (mm): mata 0,8/1,6/2,4 < sombra 3,2 < musgo das clareiras 4,0 < manchas Zone.patch 6,0/6,8 < anéis da arena 7,4/7,8
    #             < acostamento 9,8 < terreiros (posto, aldeia, arena) 10,4 < trilha 12
    d = Dress(z, 317)
    d.mottle([("bosque_escuro", (0.2, 0.36, 0.32)), ("bosque_musgo", (0.29, 0.48, 0.38)), ("bosque_folha", (0.27, 0.41, 0.33))],
             [((0, 0), 102, 160)], y=0.0008, rmin=3.0, rmax=8.5, step=0.0008)
    d.mottle([("bosque_sombra", (0.17, 0.31, 0.29))], [((-72, -66), 24, 10), ((-76, 60), 22, 9), ((0, -84), 22, 9), ((20, 86), 18, 7),
                                                      ((24, -24), 18, 8), ((84, -30), 14, 6)], y=0.0032, rmin=5.0, rmax=10.0, group="mata")
    d.mottle([("bosque_claro", (0.33, 0.53, 0.42))], [(WOLVES, 9, 5), (BEARS, 9, 5), (EAST, 7, 4)], y=0.004, rmin=2.0, rmax=4.0, group="clareira")
    d.road_edges((0.42, 0.42, 0.33), extra=-0.3, wvar=0.4)
    d.roadside(d.m("seixo_trilha", (0.5, 0.53, 0.5)), d.m("capim_trilha", (0.28, 0.5, 0.38)), every=5.5)
    rnd = d.rnd

    # Posto da Guardiã: tendas viradas para o fogo, cerca baixa com um vão por trilha, lenha, ervas secando, caixotes
    d.cookfire(fire, 1.1, 30.0)
    d.solid(fire[0], fire[1], 2.4, 2.4, 1.4)
    canvas, trim = (0.82, 0.8, 0.66), (0.22, 0.5, 0.5)
    for i, a in enumerate((225.0, -45.0, 45.0)):
        t = P(6.7, a)
        d.tent_aurora(t, door_rot(POST, t), 0.95, canvas, trim, (0.9, 0.86, 0.62))
        d.solid(t[0], t[1], 3.0, 3.0, 2.6)
    gate_half = 20.0
    edges = sorted(a % 360.0 for a in GATES.values())
    for i, a0 in enumerate(edges):
        a1 = edges[(i + 1) % len(edges)] + (360.0 if i == len(edges) - 1 else 0.0)
        lo, hi = a0 + gate_half, a1 - gate_half
        n = max(1, int(round(math.radians(hi - lo) * POST_R / 3.6)))
        for k in range(n):
            p0, p1 = P(POST_R, lo + (hi - lo) * k / n), P(POST_R, lo + (hi - lo) * (k + 1) / n)
            d.fence_run(p0, p1, 0.9, color=(0.5, 0.4, 0.28), gap=1.8)
            mx, mz = (p0[0] + p1[0]) * 0.5, (p0[1] + p1[1]) * 0.5
            d.solid(mx, mz, math.hypot(p1[0] - p0[0], p1[1] - p0[1]) + 0.1, 0.4, 0.9, zone_lib.along(p1[0] - p0[0], p1[1] - p0[1]))
        for a in (lo, hi):                                   # lampião de estaca em cada mourão de porteira
            d.torch(P(POST_R, a), 2.0)
    wq = P(7.9, 112.0)
    d.woodpile(wq, 10.0, 3, 2.2)
    d.solid(wq[0], wq[1], 2.4, 1.4, 1.0, 10.0)
    rack(d, P(8.0, 140.0), P(8.0, 158.0), 3)                 # ervas e peles da herborista
    cq = P(7.9, 12.0)
    d.cargo(cq, 4, 1.1)
    d.solid(cq[0], cq[1], 2.2, 2.2, 1.1)
    d.weapon_rack(P(7.8, -70.0), 20.0)
    d.solid(P(7.8, -70.0)[0], P(7.8, -70.0)[1], 2.4, 0.6, 1.5, 20.0)
    for k, a in ((0, GATES["L"] + 27.0), (1, GATES["O"] - 27.0)):
        q = P(POST_R + 1.6, a)
        d.signpost(q, 40.0 + 70.0 * k)
        d.solid(q[0], q[1], 0.5, 0.5, 2.4)

    # Aldeia dos Xamãs: roda de menires com o fogo dos espíritos no centro e tambores por fora dela, anel da praça (rua de
    # ~5 m), ocas em dois anéis desencontrados, frisas e varais só onde não fecham passagem, totens e tochas nas 4 entradas
    ritual = VILLAGE
    d.blob("ritual", d.m("patch_ritual", (0.34, 0.36, 0.31)), ritual, STONE_R + 1.8, 0.0108, 0.12)
    d.brazier(ritual, 1.6, fire="glow_espirito", color=SPIRIT)
    d.solid(ritual[0], ritual[1], 1.8, 1.8, 2.0)
    for k in range(6):
        q = V(STONE_R, 30.0 + 60.0 * k)
        d.standing_stone(q, 2.4 + 0.5 * (k % 3), (0.47, 0.52, 0.5), rune=SPIRIT if k % 2 == 0 else None)
        d.solid(q[0], q[1], 1.1, 1.1, 2.4)
    for a, r in DRUMS:
        q = V(STONE_R + 0.45 + r * 0.75, a)
        d.drum(q, r, color=PAINT)
        d.solid(q[0], q[1], r * 2, r * 2, 1.0)
    for r, a, s_ in HUTS:
        t = V(r, a)
        hut(d, t, door_rot(VILLAGE, t), s_)
    tot_cols = (PAINT, BONE, OCHRE)
    for poly, (posts, rot) in zip((r_vau, r_bosque, r_sul, r_leste), gates):     # um par de totens (e de tochas dos espíritos) em cada entrada
        for q in posts:
            d.totem(q, 4.4, rot + 90.0, tot_cols)
            d.solid(q[0], q[1], 1.0, 1.0, 4.4)
        for q in gate_posts(poly, VILLAGE, VILLAGE_R - 3.5, 3.6)[0]:
            d.torch(q, 2.3, fire="glow_espirito_tocha")
    for r, a, s_ in HUTS[:4]:                                # pote de fumaça ao lado da porta das ocas de dentro
        smoke_pot(d, V(r - 3.3 * s_, a + 13.0), 1.0 + 0.25 * (int(a) % 3))
    for a in (0.0, 120.0, 240.0):
        smoke_pot(d, V(2.6, a), 1.1)
    for a in RACKS:                                          # varal nas costas da oca (encostado nela: não abre fresta)
        rack(d, V(21.2, a), V(23.6, a), 2)
    for a in SPIKES:                                         # frisas (aldeia hostil, sem muro inteiro)
        q = V(VILLAGE_R - 0.5, a)
        d.spikes(q, 270.0 - a, 3.4)
        tx, tz = -math.sin(math.radians(a)) * 1.3, math.cos(math.radians(a)) * 1.3
        chain(d, (q[0] - tx, q[1] - tz), (q[0] + tx, q[1] + tz), 0.9, 1.2)
    for k in range(9):
        a = rnd.uniform(0, 360)
        d.bones(V(rnd.uniform(8.0, 20.0), a), 4, 1.1, skull=k % 2 == 0)

    # Bosque do Arquidruida: menires (runa acesa um sim, um não), anéis de musgo no tom do próprio chão, totens nas duas bocas,
    # raízes e cogumelos acesos só na borda. O miolo fica vazio: a luta é de invocações.
    t1, t2 = d.m("patch_arena_a", (0.32, 0.41, 0.37)), d.m("patch_arena_b", (0.4, 0.49, 0.43))
    d.arc("arena", t1, GROVE, GROVE_R - 3.5, 0.0, math.tau, 1.1, y=0.0114, wvar=0.25)
    d.arc("arena", t2, GROVE, GROVE_R - 9.0, 0.0, math.tau, 0.8, y=0.0118, wvar=0.25)
    d.blob("arena", t1, GROVE, 2.6, 0.0114, 0.1)
    for k, a in enumerate(ring):
        q = G(GROVE_R + 0.6, a)
        d.standing_stone(q, 3.2 + 0.6 * (k % 3), (0.45, 0.5, 0.49), rune=SPIRIT if k % 2 == 0 else None, lean=4.0)
        d.solid(q[0], q[1], 1.3, 1.3, 3.0)
        if k % 3 == 0:
            for j in range(3):
                d.mushroom(G(GROVE_R - 0.8 + rnd.uniform(-0.4, 0.4), a + 7.0 + j * 3.0), rnd.uniform(0.8, 1.3), cap=SPIRIT, glow=True)
    for e in (86.0, 188.0):
        for sg in (-1, 1):
            q = G(GROVE_R + 0.4, e + sg * 9.5)
            d.totem(q, 5.0, e + 90.0, tot_cols)
            d.solid(q[0], q[1], 1.0, 1.0, 5.0)
    root = d.m("raiz_velha", (0.33, 0.27, 0.22))
    for k, a in enumerate(ring):
        if math.sin(math.radians(a)) < 0.3 and k % 2 == 0:          # raízes das árvores velhas entrando na borda da arena
            p0, p1, p2 = G(GROVE_R + 3.0, a + 5.0), G(GROVE_R + 0.4, a + 12.0), G(GROVE_R - 2.2, a + 9.0)
            d.tube("raiz", root, [(p0[0], 0.5, p0[1]), (p1[0], 0.3, p1[1]), (p2[0], 0.0, p2[1])], 0.3, 0.08, 5)

    # Roda dos Chamados (invocadores do sul): fogueira dos espíritos, 5 menires baixos, uma oca, totem e potes
    d.brazier(CALL, 1.2, fire="glow_espirito", color=SPIRIT)
    d.solid(CALL[0], CALL[1], 1.5, 1.5, 1.8)
    for k in range(5):
        a = math.tau * k / 5 + 0.5
        q = (CALL[0] + math.cos(a) * 5.4, CALL[1] + math.sin(a) * 5.4)
        d.standing_stone(q, 1.9 + 0.4 * (k % 2), (0.47, 0.52, 0.5), rune=SPIRIT if k % 2 else None)
        d.solid(q[0], q[1], 1.1, 1.1, 2.0)
    hq = (CALL[0] - 5.5, CALL[1] + 5.5)
    hut(d, hq, door_rot(CALL, hq), 0.9)
    tq = (CALL[0] + 7.0, CALL[1] + 4.5)
    d.totem(tq, 4.2, 30.0, tot_cols)
    d.solid(tq[0], tq[1], 1.0, 1.0, 4.2)
    smoke_pot(d, (CALL[0] - 2.5, CALL[1] - 3.2), 1.2)
    smoke_pot(d, (CALL[0] + 3.4, CALL[1] + 2.0), 1.0)
    # arco leste: acampamento pequeno de invocadores (oca, totem, varal)
    hq = (EAST[0] - 6.0, EAST[1] + 3.0)
    hut(d, hq, door_rot(EAST, hq), 0.95)
    tq = (EAST[0] + 4.5, EAST[1] + 3.0)
    d.totem(tq, 4.2, 70.0, tot_cols)
    d.solid(tq[0], tq[1], 1.0, 1.0, 4.2)
    smoke_pot(d, (EAST[0] - 3.5, EAST[1] - 3.0), 1.1)
    # sentinelas (trilha do vau e trilha do bosque): totem de aviso com ossos
    for q, rot in (((11.0, 0.5), 80.0), ((64.5, -17.0), 10.0), ((23.0, 58.5), 40.0)):
        if d.ok(q[0], q[1], 0.6, road=0.5):
            d.totem(q, 3.8, rot, tot_cols)
            d.solid(q[0], q[1], 1.0, 1.0, 3.8)
            d.bones((q[0] + 1.2, q[1] + 0.8), 3, 0.9, skull=True)
    # Toca dos Lobos e Clareira dos Ursos: lajes musgosas baixas, ossos
    for c, n, rr in ((WOLVES, 4, 10.0), (BEARS, 3, 10.0)):
        for q in d.spots([(c, rr, n)], r=1.8, spacing=7.0, road=1.2):
            d.outcrop(q, 2.0, 3, (0.42, 0.46, 0.44), top=MOSS, hmul=0.8)
            d.solid(q[0], q[1], 2.8, 2.8, 1.4)
        for k in range(3):
            a = rnd.uniform(0, math.tau)
            d.bones((c[0] + math.cos(a) * rnd.uniform(2.0, 6.5), c[1] + math.sin(a) * rnd.uniform(2.0, 6.5)), 3, 1.0, skull=k == 0)
    # mata velha: lajes cobertas de musgo, menires perdidos, samambaias e cogumelos (os acesos só perto da aldeia e do bosque)
    for q in d.spots([((0, 0), 96, 26)], r=2.0, spacing=14.0, road=1.5, blocked=True):
        d.outcrop(q, 2.2, 3, (0.4, 0.45, 0.43), top=MOSS, hmul=0.7)
        d.solid(q[0], q[1], 3.0, 3.0, 1.4)
    for q in d.spots([((0, 0), 94, 9)], r=0.8, spacing=24.0, road=1.2, blocked=True):
        d.standing_stone(q, rnd.uniform(1.8, 2.8), (0.45, 0.5, 0.49), lean=10.0)
        d.solid(q[0], q[1], 1.1, 1.1, 2.2)
    fern = d.m("samambaia", (0.22, 0.5, 0.4))
    fern2 = d.m("samambaia_b", (0.3, 0.56, 0.42))
    for q in d.spots([((0, 0), 98, 150)], r=0.5, spacing=3.5, road=0.3, blocked=True, tries=5):
        for j in range(rnd.randint(2, 4)):
            d.tuft("mini", fern if j % 2 else fern2, (q[0] + rnd.uniform(-0.8, 0.8), q[1] + rnd.uniform(-0.8, 0.8)), 0.55, 0.75, 6, w=0.13)
    for q in d.spots([((0, 0), 96, 44)], r=0.5, spacing=6.0, road=0.4, blocked=True, tries=6):
        for j in range(rnd.randint(2, 4)):
            d.mushroom((q[0] + rnd.uniform(-0.7, 0.7), q[1] + rnd.uniform(-0.7, 0.7)), rnd.uniform(0.7, 1.3),
                       cap=[(0.56, 0.5, 0.7), (0.8, 0.78, 0.66), (0.42, 0.62, 0.6)][j % 3], glow=False)
    for q in d.spots([(VILLAGE, VILLAGE_R + 14.0, 16), (GROVE, GROVE_R + 12.0, 10), (CALL, 14.0, 5)], r=0.5, spacing=5.0, road=0.4, blocked=True, tries=6):
        for j in range(rnd.randint(2, 3)):
            d.mushroom((q[0] + rnd.uniform(-0.6, 0.6), q[1] + rnd.uniform(-0.6, 0.6)), rnd.uniform(0.8, 1.4), cap=SPIRIT, glow=True)
    # Lagoa do Musgo: pedras na beira
    for k in range(6):
        a = math.tau * k / 6 + 0.4
        q = (POND[0] + math.cos(a) * (POND_R + 2.6), POND[1] + math.sin(a) * (POND_R + 2.6))
        if d.ok(q[0], q[1], 0.8, road=0.6, water=0.2):
            d.rock("lagoa", d.m("pedra_musgo", (0.36, 0.48, 0.42)), q, rnd.uniform(0.5, 0.9), 0.0, 0.6, sub=1)
    sg_ = (arrive[0] + 4.5, arrive[1] - 4.6)                 # placa na chegada
    if d.ok(sg_[0], sg_[1], 0.5, road=0.3):
        d.signpost(sg_, 200.0)
        d.solid(sg_[0], sg_[1], 0.5, 0.5, 2.4)
    d.flush()

    print("field_grove: portal %s chegada %s posto %s aldeia %s bosque %s" % (portal, arrive, POST, VILLAGE, GROVE))
    print("field_grove: borda no bosque %.1f (centro a %.1f)" % (z.rim_r(math.atan2(GROVE[1], GROVE[0])), math.hypot(*GROVE)))
    print("field_grove: npcs %s" % z.data["npcs"])
    print("field_grove: spawners %s" % [(s["monster_id"], s["pos"], s["radius"], s["count"]) for s in z.data["spawners"]])
    print("field_grove: pontes %s" % z.data.get("bridges"))
    return z.finish(export, poi=GROVE, ground=GROUND)
