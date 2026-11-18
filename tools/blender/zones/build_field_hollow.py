"""Mata dos Zumbidos (field_hollow, Lv 4-8): mata fechada ao sul-sudoeste de Aldara, ramo lateral opcional.
Garganta única no norte-nordeste (volta para Aldara), riacho com duas pontes, trilhas estreitas de terra, o
Acampamento da Mateira no meio (3 tendas, fogo, cerca baixa; não é vila: sem muro, sem cristal) e as clareiras de caça:
Prado de Flores (vespas, SO), Clareira da Colmeia (S, âmbar), Encosta dos Ursos (L, depois do riacho), Toca da Ursa
(chefe, SE) e a clareira do aprendiz perdido (O).

    blender -b --factory-startup --python tools/blender/zones/run_zone.py -- build_field_hollow <pasta_png> --export
"""
import math
import random
import importlib
import nature
import zone_lib
importlib.reload(zone_lib)
from zone_lib import Zone
from dress import Dress

ZONE = "field_hollow"
SIZE = 220.0
RIM = (99.0, 4.0, 2.5, 1.5)        # raio útil 91-107 m: a regra de borda do _check_zone_layout só conta acerto em r > 95
GROUND = (0.3, 0.45, 0.29)         # = MapDef.ground_color e loading_art.ZONES["field_hollow"]["ground"]
TRAIL_W = 3.0
GORGE_ANG = -66.0                  # garganta de Aldara (rumo 24 graus: o oposto da saída de Aldara, rumo 206)
ALDARA_ARRIVE = (-51.5, 105.6)     # chegada em Aldara, junto da garganta sudoeste (build_city_aldara.HOLLOW_ARRIVE)
CAMP = (2.0, -12.0)
CAMP_R = 10.0
GATES = {"N": -72.0, "L": 14.0, "S": 81.0, "SO": 150.0}      # por onde as trilhas saem do acampamento (graus do jogo)
MEADOW = (-50.0, 20.0)             # Prado de Flores
MEADOW2 = (-33.0, 39.0)
HIVE = (10.0, 63.0)                # Clareira da Colmeia
SLOPE = (74.0, -34.0)              # Encosta dos Ursos
CUBS = (41.0, 21.0)                # filhotes, do lado de cá do riacho
OAK = (-30.0, -15.0)               # Carvalho Velho (landmark)
LOST = (-66.0, 50.0)               # clareira do aprendiz perdido
TREE_COLS = [(0.16, 0.34, 0.22), (0.2, 0.4, 0.25), (0.25, 0.45, 0.27)]
WARM_FLOWERS = [(0.98, 0.8, 0.35), (0.96, 0.62, 0.3), (0.95, 0.5, 0.6), (0.98, 0.92, 0.6)]
HONEY = (0.95, 0.68, 0.2)


def polar(z, ang_deg, inset):
    a = math.radians(ang_deg)
    r = z.rim_r(a) - inset
    return (round(math.cos(a) * r, 1), round(math.sin(a) * r, 1))


def face_to(x, z, tx, tz):
    return round(math.degrees(math.atan2(tx - x, tz - z)), 1)


def build(export=False):
    z = Zone(ZONE, size=SIZE, rim=RIM, seed=6, palette={
        "leaf": (0.18, 0.36, 0.24), "cliff_grass": (0.24, 0.4, 0.26), "hill_grass": (0.3, 0.46, 0.29),
        "cliff_rock": (0.4, 0.38, 0.35), "road": (0.6, 0.5, 0.36), "water": (0.32, 0.56, 0.62),
    })
    cx, cz = CAMP
    C = lambda r, a: (cx + math.cos(math.radians(a)) * r, cz + math.sin(math.radians(a)) * r)
    portal = polar(z, GORGE_ANG, 7)
    arrive = polar(z, GORGE_ANG, 15)
    den = polar(z, 45.0, 26)           # Toca da Ursa: clareira encostada no paredão sudeste
    den_rock = polar(z, 45.0, 9)
    z.data["spawn"] = list(arrive)
    z.data["arrive_from_town"] = list(arrive)
    z.cam_game = CAMP
    z.portal("to_town", portal, "city_aldara", ALDARA_ARRIVE, "Vale de Aldara")
    z.block(arrive, 7.5)

    # ---------- chão por região (lido de cima): acampamento de terra, prados quentes, âmbar da colmeia, toca de pedra ----------
    z.patch("acampamento", CAMP, CAMP_R + 1.5, (0.6, 0.51, 0.37), y=0.0104)      # acima do acostamento (9,8 mm): a beira escura das trilhas não risca o terreiro
    z.patch("prado", MEADOW, 19.0, (0.7, 0.72, 0.4), grass=True)
    z.patch("prado_b", MEADOW2, 10.5, (0.68, 0.71, 0.41), grass=True)
    z.patch("colmeia", HIVE, 11.5, (0.76, 0.61, 0.33), grass=True)
    z.patch("toca", den, 11.0, (0.5, 0.45, 0.37))
    z.patch("encosta", SLOPE, 14.5, (0.42, 0.5, 0.32), grass=True)
    z.patch("perdido", LOST, 7.0, (0.5, 0.52, 0.36), grass=True)
    z.patch("filhotes", CUBS, 9.5, (0.4, 0.5, 0.31), grass=True)
    z.data["town"] = {"center": [cx, cz], "radius": 0.0, "gates": []}

    # ---------- riacho (norte e leste) ----------
    z.river([(-122, -54), (-86, -44), (-52, -34), (-22, -44), (4, -54), (30, -48), (52, -28), (70, -2), (92, 18), (126, 36)], w=4.5)

    # ---------- trilhas (estreitas, curvas; laço sul e laço leste: sem beco fora o do aprendiz e o da encosta) ----------
    g = lambda k: C(CAMP_R - 2.5, GATES[k])
    z.road("N", [g("N"), (8, -31), (14, -42), (22, -60), (30, -71), arrive, portal], w=TRAIL_W, end_clearing=False)
    z.road("SO", [g("SO"), (-22, 2), (-36, 8), (-47, 17), (-56, 32), (-62, 42), (LOST[0] + 2, LOST[1] - 3)], w=TRAIL_W)
    z.road("S", [g("S"), (7, 14), (1, 30), (8, 44), (HIVE[0], HIVE[1] - 9)], w=TRAIL_W, end_clearing=False)
    z.road("L", [g("L"), (26, -7), (40, -4), (52, -8), (62, -15), (72, -23), (SLOPE[0] - 2, SLOPE[1] + 5)], w=TRAIL_W)
    z.road("arco_oeste", [(-47, 17), (-41, 36), (-26, 50), (-8, 57), (HIVE[0], HIVE[1] - 9)], w=TRAIL_W, end_clearing=False)
    z.road("arco_sul", [(HIVE[0], HIVE[1] - 9), (24, 51), (38, 55), (den[0] - 7, den[1] - 2)], w=TRAIL_W, end_clearing=False)
    z.road("arco_leste", [(40, -4), (45, 9), (50, 24), (57, 38), (den[0] - 1, den[1] - 8)], w=TRAIL_W, end_clearing=False)
    z.arrival(arrive, toward=portal, r=6.0)
    z.bridges()

    # ---------- relevo: rochedo da toca (a ursa mora ao pé dele) e afloramentos baixos pela mata ----------
    z.hill("rochedo_toca", den_rock, 8.0, 3)
    for i, (c, r, lv) in enumerate([((-24, 22), 6, 2), ((30, 30), 5, 1), ((-74, -18), 7, 2), ((-12, -76), 6, 2),
                                    ((84, 44), 6, 2), ((-22, 84), 6, 1), ((60, -62), 6, 2)]):
        z.terrace("afloramento_%d" % i, c, r, lv, top="cliff_grass")
    z.giant_tree("carvalho_velho", OAK, trunk_r=2.6, height=18.0)      # landmark, fora das trilhas
    z.cliffs()

    # ---------- vegetação: mata fechada, só as clareiras e as trilhas abertas ----------
    for c, r in ((CAMP, CAMP_R + 4.0), (MEADOW, 15.0), (MEADOW2, 8.0), (HIVE, 12.0), (den, 11.5), (SLOPE, 12.0), (LOST, 7.5), (CUBS, 8.5)):
        z.block(c, r)
    z.scatter("tree", [((-70, -70), 26, 60), ((60, -70), 22, 40), ((-80, 10), 24, 55), ((-50, 76), 24, 50), ((36, 84), 20, 34),
                       ((84, 10), 18, 34), ((-20, -24), 18, 34), ((28, 10), 14, 26), ((-14, 32), 16, 28), ((-40, -62), 18, 30),
                       ((70, -66), 18, 30), ((8, -84), 18, 30), ((44, -30), 14, 24), ((30, -12), 10, 12), ((76, 28), 14, 22), ((-8, 2), 9, 8)],
              0, (1.6, 3.6, 1.6), TREE_COLS, margin=3.4, spacing=3.2, scale=(1.0, 1.6))
    z.scatter("tree", [((0, 0), 104, 460)], 0, (1.6, 3.6, 1.6), TREE_COLS, margin=3.6, spacing=3.3, scale=(0.95, 1.5))
    z.rim_belt(150, (1.6, 3.6, 1.6), TREE_COLS[:2])
    z.scatter("rock", [(den, 16, 8), (SLOPE, 16, 8), ((0, 0), 96, 22)], 0, (1.4, 0.9, 1.2), [(0.48, 0.48, 0.45)],
              margin=3.0, spacing=2.5, scale=(0.8, 1.6))

    nrnd = random.Random(53)
    obs = z.data["obstacles"]
    fr = lambda x, zz, m: z.free(x, zz, m)
    nature.fix_trees(obs, nrnd, pine_frac=0.18)
    nature.scatter(z.ob, fr, nrnd, "bush", [((0, 0), 100, 130)], (1.7, 0.95, 1.7), [(0.2, 0.4, 0.25), (0.26, 0.46, 0.28), (0.3, 0.5, 0.3)],
                   solid=False, margin=2.2, spacing=2.6, avoid=obs)
    # flores: quentes nos prados e na colmeia (o prado se lê amarelo-rosado de cima), poucas e claras pela mata
    open_fr = lambda x, zz, m: all(nature.poly_dist(zone_lib.Vector((x, zz)), p) > m for p in list(z.road_polys.values()) + z.rivers)
    nature.scatter(z.ob, open_fr, nrnd, "flowers", [(MEADOW, 17, 34), (MEADOW2, 9, 12), (HIVE, 10.5, 12), (LOST, 6, 4), (CUBS, 8, 4)],
                   (1.6, 0.45, 1.6), WARM_FLOWERS, solid=False, margin=2.0, spacing=2.8, scale=(0.8, 1.4), avoid=obs)
    nature.scatter(z.ob, fr, nrnd, "flowers", [((0, 0), 98, 18)], (1.6, 0.45, 1.6), [(0.95, 0.95, 0.86), (0.98, 0.8, 0.35)],
                   solid=False, margin=2.4, spacing=4.0, avoid=obs)
    nature.woodland_floor(z.ob, fr, nrnd, [((-70, -70), 26, 8), ((-80, 10), 24, 8), ((-50, 76), 24, 8), ((36, 84), 20, 6), ((0, 0), 96, 18)], avoid=obs)
    nature.clear_banks(obs, z.rivers, [], z.river_w)
    nature.shore(z.ob, nrnd, z.rivers, [], list(z.road_polys.values()), z.river_w)

    # ---------- NPCs e pontos de bot (nomes/papéis em MapsCatalog.PLACE_NPCS["field_hollow"]) ----------
    fire = (cx + 0.5, cz + 0.5)
    brena = (cx - 1.6, cz - 2.2)
    osvaldo = C(5.4, 126.0)
    rui = C(3.6, 10.0)
    for nid, p in (("hollow_brena", brena), ("hollow_osvaldo", osvaldo), ("hollow_rui", rui)):
        z.npc(nid, round(p[0], 2), round(p[1], 2), face_to(p[0], p[1], *fire))
    z.npc("hollow_apprentice", LOST[0] - 1.0, LOST[1] + 1.5, face_to(LOST[0] - 1.0, LOST[1] + 1.5, LOST[0] + 2, LOST[1] - 3))
    z.data["hangouts"] = [[round(q[0], 2), round(q[1], 2)] for q in (C(3.6, 60.0), C(3.4, 200.0), C(5.2, -95.0), C(6.6, 12.0), C(6.4, 84.0),
                                                                    C(6.2, 160.0), C(13.5, -72.0), C(13.5, 150.0))]

    # ---------- monstros (ids do plano; modelos mob_<id> feitos à parte) ----------
    z.spawner("wasp", MEADOW[0] - 2, MEADOW[1] + 3, 10, 5, 12.0)                 # Prado de Flores
    z.spawner("wasp", MEADOW2[0], MEADOW2[1] + 1, 7, 4, 12.0)
    z.spawner("wasp_soldier", -60, 35, 6, 3, 16.0)                               # guardam o caminho do aprendiz
    z.spawner("wasp", HIVE[0] - 9, HIVE[1] + 2, 6, 4, 12.0)                      # em volta da Colmeia
    z.spawner("wasp_soldier", HIVE[0] + 8, HIVE[1] + 4, 6, 3, 16.0)
    z.spawner("hive", HIVE[0], HIVE[1] + 1.5, 1, 1, 150.0)
    z.spawner("bear_cub", CUBS[0], CUBS[1], 7, 4, 16.0)
    z.spawner("bear_cub", SLOPE[0] - 7, SLOPE[1] - 5, 6, 3, 16.0)                # Encosta dos Ursos
    z.spawner("bear", SLOPE[0] + 5, SLOPE[1] + 1, 7, 3, 20.0)
    z.spawner("bear", 60, 44, 5, 2, 20.0)                                        # na trilha da toca
    z.spawner("bear_mother", den[0] + 1.5, den[1] + 1.5, 2, 1, 150.0)            # Toca da Ursa (chefe de campo)

    # ---------- acabamento (dress.py): chão da mata, beira de trilha, acampamento, colmeia, toca ----------
    # pilha (mm): mata 0,8/1,6/2,4 < sombra das clareiras 3,2 < manchas Zone.patch 6,0/6,8 < mel 7,4 < acostamento 9,8 < trilha 12
    d = Dress(z, 211)
    d.mottle([("mata_escura", (0.25, 0.4, 0.26)), ("mata_musgo", (0.34, 0.49, 0.29)), ("mata_folha", (0.33, 0.43, 0.27))],
             [((0, 0), 102, 150)], y=0.0008, rmin=3.0, rmax=8.5, step=0.0008)
    d.mottle([("mata_sombra", (0.22, 0.36, 0.25))], [((-70, -70), 26, 10), ((-80, 10), 22, 9), ((-50, 76), 22, 9), ((36, 84), 18, 7),
                                                    ((60, -70), 20, 8)], y=0.0032, rmin=5.0, rmax=10.0, group="mata")
    d.road_edges((0.52, 0.47, 0.33), extra=-0.3, wvar=0.4)
    d.roadside(d.m("seixo_trilha", (0.56, 0.54, 0.48)), d.m("capim_trilha", (0.36, 0.52, 0.3)), every=6.0)

    # acampamento: tendas viradas para o fogo, cerca baixa com um vão por trilha, lenha, barris de mel, peles
    d.cookfire(fire, 1.1, 30.0)
    d.solid(fire[0], fire[1], 2.4, 2.4, 1.4)
    canvas, trim = (0.84, 0.76, 0.56), (0.36, 0.5, 0.32)
    for i, a in enumerate((219.0, -29.0, 47.0)):
        t = C(6.9, a)
        rot = math.degrees(math.atan2(-(cx - t[0]), -(cz - t[1])))
        d.tent_aurora(t, rot, 0.95, canvas, trim, HONEY if i == 1 else (0.9, 0.84, 0.6))
        d.solid(t[0], t[1], 3.0, 3.0, 2.6)
    gate_half = 20.0
    edges = sorted(a % 360.0 for a in GATES.values())
    for i, a0 in enumerate(edges):
        a1 = edges[(i + 1) % len(edges)] + (360.0 if i == len(edges) - 1 else 0.0)
        lo, hi = a0 + gate_half, a1 - gate_half
        n = max(1, int(round(math.radians(hi - lo) * CAMP_R / 3.6)))
        for k in range(n):
            p0, p1 = C(CAMP_R, lo + (hi - lo) * k / n), C(CAMP_R, lo + (hi - lo) * (k + 1) / n)
            d.fence_run(p0, p1, 0.9, color=(0.52, 0.4, 0.27), gap=1.8)
            mx, mz = (p0[0] + p1[0]) * 0.5, (p0[1] + p1[1]) * 0.5
            d.solid(mx, mz, math.hypot(p1[0] - p0[0], p1[1] - p0[1]) + 0.1, 0.4, 0.9, zone_lib.along(p1[0] - p0[0], p1[1] - p0[1]))
        for a in (lo, hi):                                   # lampião de estaca em cada mourão de porteira
            q = C(CAMP_R, a)
            d.torch(q, 2.0)
    wq = C(7.8, 112.0)
    d.woodpile(wq, 10.0, 3, 2.2)
    d.solid(wq[0], wq[1], 2.4, 1.4, 1.0, 10.0)
    for q in (C(7.2, 128.0), C(8.2, 127.0), C(7.6, 135.0)):  # barris de mel do Osvaldo
        d.barrel(q, 1.0, color=(0.6, 0.42, 0.24))
        d.cyl("carga", d.m("mel_tampa", HONEY), q, 0.3, 0.3, 0.04, 1.0, 8)
    d.solid(C(7.6, 132.0)[0], C(7.6, 132.0)[1], 2.2, 1.8, 1.1)
    hq = C(7.8, -4.0)                                        # varal de peles do Rui
    hide = d.m("pele_urso", (0.46, 0.33, 0.24))
    wd = d.m("cavalete", (0.4, 0.3, 0.22))
    for sg in (-1, 1):
        d.cyl("armas", wd, (hq[0], hq[1] + sg * 1.2), 0.07, 0.06, 1.9, 0.0, 5)
    d.box("armas", wd, hq, (0.08, 0.08, 2.5), 0.0, 1.8)
    for k in (-0.6, 0.55):
        d.box("armas", hide, (hq[0], hq[1] + k), (0.06, 1.15, 0.9), 0.0, 0.62)
    d.solid(hq[0], hq[1], 0.5, 2.6, 1.9)
    d.cargo(C(7.9, 176.0), 4, 1.1)
    d.solid(C(7.9, 176.0)[0], C(7.9, 176.0)[1], 2.2, 2.2, 1.1)
    for k, a in ((0, GATES["N"] + 27.0), (1, GATES["SO"] - 27.0)):
        q = C(CAMP_R + 1.6, a)
        d.signpost(q, 40.0 + 70.0 * k)
        d.solid(q[0], q[1], 0.5, 0.5, 2.4)
    sg_ = (arrive[0] - 5.4, arrive[1] + 3.0)                 # placa na chegada
    if d.ok(sg_[0], sg_[1], 0.5, road=0.3):
        d.signpost(sg_, 120.0)
        d.solid(sg_[0], sg_[1], 0.5, 0.5, 2.4)

    # Clareira da Colmeia: poças e escorridos de mel, favos caídos, tocos melados (o tronco da colmeia é o monstro `hive`)
    mel_chao = d.m("patch_mel", (0.86, 0.66, 0.26))
    favo = d.m("favo", HONEY)
    cera = d.m("favo_cera", (0.82, 0.56, 0.2))
    toco = d.m("toco_mel", (0.4, 0.29, 0.2))
    rnd = d.rnd
    for k in range(9):
        a, r = rnd.uniform(0, math.tau), rnd.uniform(2.5, 9.5)
        q = (HIVE[0] + math.cos(a) * r, HIVE[1] + 1.5 + math.sin(a) * r)
        d.blob("mel", mel_chao, q, rnd.uniform(0.45, 1.0), 0.0074, 0.3, sx=rnd.uniform(1.0, 1.7), rot=rnd.uniform(0, 180))
    for k in range(7):
        a = math.tau * k / 7 + rnd.uniform(-0.25, 0.25)
        r = rnd.uniform(6.5, 9.8)
        q = (HIVE[0] + math.cos(a) * r, HIVE[1] + 1.5 + math.sin(a) * r)
        if not d.ok(q[0], q[1], 0.8, road=0.6):
            continue
        if k % 2 == 0:                                       # toco com favo em cima
            d.cyl("colmeia", toco, q, 0.62, 0.52, 0.8, 0.0, 7, jitter=0.1)
            d.cyl("colmeia", favo, q, 0.46, 0.2, 0.42, 0.8, 6)
            d.cyl("colmeia", cera, q, 0.56, 0.5, 0.1, 0.74, 6, cap=False)
            d.solid(q[0], q[1], 1.2, 1.2, 1.2)
        else:                                                # favo caído no chão
            for j in range(3):
                d.cyl("mini", favo if j else cera, (q[0] + rnd.uniform(-0.6, 0.6), q[1] + rnd.uniform(-0.6, 0.6)), rnd.uniform(0.22, 0.4), 0.12,
                      rnd.uniform(0.18, 0.3), 0.0, 6, rnd.uniform(0, 60))
    # Toca da Ursa: boca escura no pé do rochedo, lajes em ferradura, ossos e peixes roídos
    out = math.atan2(den_rock[1] - den[1], den_rock[0] - den[0])
    mouth = (den[0] + math.cos(out) * 9.2, den[1] + math.sin(out) * 9.2)
    d.cyl("toca", d.m("toca_boca", (0.1, 0.09, 0.09)), mouth, 2.3, 1.5, 2.2, 0.0, 7, jitter=0.12)
    for sg in (-1.0, -0.55, 0.55, 1.0):
        a = out + sg * 1.25
        q = (den[0] + math.cos(a) * 10.4, den[1] + math.sin(a) * 10.4)
        if d.ok(q[0], q[1], 1.6, road=0.8):
            d.outcrop(q, 2.6, 4, (0.46, 0.43, 0.4), hmul=1.2)
            d.solid(q[0], q[1], 3.6, 3.6, 2.2)
    for k in range(4):
        a = out + math.pi + (k - 1.5) * 0.7
        d.bones((den[0] + math.cos(a) * rnd.uniform(3.5, 7.0), den[1] + math.sin(a) * rnd.uniform(3.5, 7.0)), 4, 1.2, skull=k % 2 == 0)
    # Encosta dos Ursos e clareira dos filhotes: lajes baixas, troncos arranhados
    for c, n, rr in ((SLOPE, 4, 12.0), (CUBS, 2, 8.0)):
        for q in d.spots([(c, rr, n)], r=1.8, spacing=7.0, road=1.2):
            d.outcrop(q, 2.0, 3, (0.48, 0.45, 0.41), hmul=0.8)
            d.solid(q[0], q[1], 2.8, 2.8, 1.4)
    # aprendiz perdido: carrinho quebrado, carga espalhada, lampião aceso
    lq = (LOST[0] - 3.6, LOST[1] + 2.2)
    d.cart(lq, 200.0, broken=True, load=(0.8, 0.7, 0.4))
    d.solid(lq[0], lq[1], 3.0, 1.8, 1.4, 200.0)
    d.cargo((LOST[0] + 1.8, LOST[1] + 3.6), 3, 1.0)
    d.solid(LOST[0] + 1.8, LOST[1] + 3.6, 1.8, 1.8, 1.0)
    d.torch((LOST[0] - 0.4, LOST[1] + 3.6), 1.8)
    # cogumelos (sem brilho) no chão da mata, perto das trilhas: leitura de "mata úmida"
    for q in d.spots([((0, 0), 96, 46)], r=0.5, spacing=6.0, road=0.4, tries=6):
        for j in range(rnd.randint(2, 4)):
            d.mushroom((q[0] + rnd.uniform(-0.7, 0.7), q[1] + rnd.uniform(-0.7, 0.7)), rnd.uniform(0.7, 1.3),
                       cap=[(0.86, 0.36, 0.28), (0.9, 0.72, 0.4), (0.8, 0.74, 0.62)][j % 3], glow=False)
    d.flush()

    print("field_hollow: portal %s chegada %s toca %s rochedo %s" % (portal, arrive, den, den_rock))
    print("field_hollow: npcs %s" % z.data["npcs"])
    print("field_hollow: spawners %s" % [(s["monster_id"], s["pos"], s["radius"], s["count"]) for s in z.data["spawners"]])
    print("field_hollow: pontes %s" % z.data.get("bridges"))
    return z.finish(export, poi=HIVE, ground=GROUND)
