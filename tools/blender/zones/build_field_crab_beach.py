"""Praia dos Caranguejos (field_crab_beach, Lv 3-8): enseada de farm ao sul do Vale de Aldara. O mar entra pelo sul numa
baía redonda; a praia é uma meia-lua de areia clara de ~210 m em volta dela, fechada por falésias de arenito. Chegada
na ponta oeste (garganta de Aldara), com o rancho e o píer quebrado do Pescador Joca logo ali (o "hub": sem muro, sem
cristal); na ponta leste, o Recife do Rei, onde o Caranguejo-Rei sai do mar (spawner com `emerge`). Entre as duas, a
praia inteira é caça: caranguejos na areia molhada, eremitas nas poças de maré, marias-farinha na areia seca e nas dunas.
Por trás, a Trilha das Dunas (coqueiral, Lagoa das Dunas, Areal das Tocas) fecha o laço de farm: praia na ida, dunas
na volta, 1-2 min a pé. Marco: o casco encalhado no meio da baía, visível da praia toda.

GIRO: o desenho abaixo é feito com o mar ao SUL e a chegada a OESTE; no fim o mapa inteiro gira 90 graus (`TURN`,
Zone.apply_turn), porque a saída de Aldara aponta para o sul (rumo 177) e a chegada tem de ficar do lado oposto (norte;
`_check_world_geography`). No jogo: mar a OESTE, chegada e rancho do Joca ao NORTE, Recife do Rei ao SUL, dunas a leste.
Ponto do desenho (x, z) -> jogo (-z, x): é assim que estão os pontos fixos do catálogo (GATHER, AMBIENT_LIFE, tour).

    blender -b --factory-startup --python tools/blender/zones/run_zone.py -- build_field_crab_beach <pasta_png> --export
"""
import math
import random
import importlib
import act2_dress
import nature
import sea
import zone_lib
importlib.reload(zone_lib)
from zone_lib import Zone, cyl, disc, mat
from dress import Dress

ZONE = "field_crab_beach"
SIZE = 220.0
RIM = (99.0, 4.0, 2.5, 1.5)        # raio útil 91-107 m (a regra de borda do _check_zone_layout só conta acerto em r > 95)
GROUND = (0.7, 0.71, 0.46)         # capim de duna = MapDef.ground_color e loading_art.ZONES["field_crab_beach"]["ground"]
SEA_C, SEA_R = (0.0, 58.0), 62.0   # a baía: centro e raio (na sim é um `lake`; o Rei sai dela)
BEACH = 24.0                       # largura da areia (m) a partir da água
GORGE_ANG = 165.0                  # garganta de Aldara (oeste no desenho; norte no jogo, depois do giro)
TURN = 90.0                        # giro do mapa no fim (sentido horário visto de cima)
ALDARA_ARRIVE = (6.7, 113.2)       # chegada em Aldara, na margem sul do lago (= build_city_aldara.BEACH_ARRIVE)
TRAIL_W = 3.0
SAND = sea.SAND
SANDSTONE = (0.74, 0.6, 0.45)
DUNE_GRASS = (0.58, 0.64, 0.36)
PALM_GROVE = (-50.0, -40.0)        # Coqueiral (noroeste)
LAGOON = ((-4.0, -68.0), 8.5)      # Lagoa das Dunas (norte)
BURROWS = (40.0, -52.0)            # Areal das Tocas (nordeste)
KING_DEG = -22.0                   # ponta leste: Recife do Rei (a 20 m+ da falésia: cabem as costelas em volta da arena)


def SP(deg, r):
    """Ponto a `r` m do centro da baía, no rumo `deg` (graus do jogo: -90 = norte, 180 = oeste, 0 = leste)."""
    a = math.radians(deg)
    return (round(SEA_C[0] + math.cos(a) * r, 2), round(SEA_C[1] + math.sin(a) * r, 2))


def shore(deg, off):
    """Ponto a `off` m da linha d'água (positivo = areia, negativo = dentro do mar)."""
    return SP(deg, SEA_R + off)


HUT = shore(-161.0, 16.5)          # rancho do Joca
JOCA = shore(-165.0, 6.0)          # o Joca fica no pé do píer
PIER_DEG = -168.5
KING = shore(KING_DEG, 9.0)
MID = shore(-88.0, 11.0)           # meio da praia (CAM_poi)
# matilhas: (monstro, rumo em volta da baía, distância da água, raio, quantos no JSON, respawn). O jogo multiplica a
# contagem por Balance.SPAWN_COUNT_MULT (1,6): 5 -> 8 e 3 -> 5. Total no jogo: 40 caranguejos + 15 eremitas + 15 da areia = 70.
PACKS = [
    ("crab", -139.0, 9.0, 8, 5, 12.0), ("crab", -114.0, 8.0, 8, 5, 12.0), ("crab", -89.0, 9.0, 8, 5, 12.0),
    ("crab", -65.0, 8.0, 8, 5, 12.0), ("crab", -44.0, 9.0, 7, 5, 12.0),
    ("crab_hermit", -127.0, 19.0, 6, 3, 12.0), ("crab_hermit", -77.0, 19.0, 6, 3, 12.0),
    ("crab_sand", -102.0, 20.0, 7, 3, 12.0), ("crab_sand", -54.0, 19.5, 7, 3, 12.0),
]
DUNE_PACKS = [("crab_hermit", (LAGOON[0][0] + 3.0, LAGOON[0][1] + 15.5), 6, 3, 12.0), ("crab_sand", BURROWS, 7, 3, 12.0)]
POOLS = [(-127.0, 19.0, 3.4), (-122.0, 15.0, 2.2), (-77.0, 19.0, 3.6), (-82.0, 15.5, 2.0), (-101.0, 6.5, 2.6), (-55.0, 6.0, 2.4),
         (-36.0, 17.0, 2.6), (-146.0, 17.0, 2.2)]      # poças de maré: (rumo, distância da água, raio)


def polar(z, ang_deg, inset):
    a = math.radians(ang_deg)
    r = z.rim_r(a) - inset
    return (round(math.cos(a) * r, 1), round(math.sin(a) * r, 1))


def face_to(x, z, tx, tz):
    return round(math.degrees(math.atan2(tx - x, tz - z)), 1)


def tide_pools(z):
    """Poças de maré na areia: água rasa turquesa (shader de água do jogo, com espuma na borda) e um aro de areia molhada.
    Só visual: dá para atravessar, o caranguejo também."""
    shallow = mat("agua_rasa", (0.5, 0.82, 0.84))
    wet = mat("patch_poca_borda", act2_dress.WET)
    for i, (deg, off, r) in enumerate(POOLS):
        c = shore(deg, off)
        disc(z.coll, z.P + "praia_poca_borda_%d" % i, c, r + 0.55, 0.0096, wet, 16, 0.22, i)
        disc(z.coll, z.P + "praia_poca_%d" % i, c, r, 0.0125, shallow, 16, 0.26, i)


def sea_stacks(z):
    """Farilhões de arenito dentro da baía e o casco encalhado (marco): só visual, ficam na água."""
    rock = mat("farilhao", SANDSTONE)
    top = mat("farilhao_topo", (0.84, 0.72, 0.54))
    for i, (deg, off, r, h) in enumerate(((-118.0, -17.0, 3.4, 7.5), (-124.0, -22.0, 2.0, 4.0), (-52.0, -20.0, 3.0, 6.5),
                                          (-45.0, -15.0, 1.8, 3.5), (-9.0, -12.0, 2.6, 5.5), (-27.0, -21.0, 3.6, 8.5), (-171.0, -26.0, 2.2, 4.5))):
        c = shore(deg, off)
        cyl(z.coll, z.P + "farilhao_%d" % i, c, r, r * 0.72, h, rock, -0.2, 7, 0.18, i)
        cyl(z.coll, z.P + "farilhao_topo_%d" % i, c, r * 0.72, r * 0.5, h * 0.14, top, h - 0.2, 7, 0.18, i)
    sea.ship(z, "naufragio_baia", shore(-86.0, -27.0), 24.0, L=17.0, hull=(0.44, 0.31, 0.21), wreck=True)


def joca_camp(z, d):
    """Rancho do Pescador Joca: palafita de tábuas com teto de palha, píer quebrado (o resto são estacas soltas no mar),
    redes e peixe no varal, bote na areia, fogo de chão e a vara fincada na ponta do píer."""
    rnd = d.rnd
    hx, hz = HUT
    rot = zone_lib.along(SEA_C[0] - hx, SEA_C[1] - hz) + 90.0      # a porta olha para o mar
    wood = d.m("rancho_tabua", (0.58, 0.43, 0.28))
    dark = d.m("rancho_estaca", (0.4, 0.29, 0.2))
    thatch = d.m("rancho_palha", (0.6, 0.42, 0.2))            # palha queimada de sol: bem mais escura que a areia (de cima o teto é o rancho)
    thatch2 = d.m("rancho_palha_esc", (0.45, 0.3, 0.16))
    for sx in (-1.7, 1.7):
        for sz in (-1.4, 1.4):
            a = math.radians(rot)
            q = (hx + sx * math.cos(a) + sz * math.sin(a), hz - sx * math.sin(a) + sz * math.cos(a))
            d.cyl("rancho", dark, q, 0.16, 0.14, 1.0, 0.0, 5)
    d.box("rancho", dark, HUT, (4.4, 0.18, 3.8), rot, 0.9)
    d.box("rancho", wood, HUT, (3.8, 2.0, 3.2), rot, 1.08)
    d.cyl("rancho", thatch2, HUT, 3.5, 2.1, 0.9, 2.95, 4, rot + 45.0)          # palha em duas águas: saia escura, miolo claro, cumeeira
    d.cyl("rancho", thatch, HUT, 2.3, 0.0, 1.5, 3.8, 4, rot + 45.0)
    d.cyl("rancho", dark, HUT, 0.16, 0.12, 0.5, 5.2, 5)
    d.box("rancho", d.m("rancho_janela", (0.3, 0.42, 0.5)), (hx - math.cos(math.radians(rot)) * 1.92, hz + math.sin(math.radians(rot)) * 1.92), (0.08, 0.7, 0.9), rot, 1.9)
    a = math.radians(rot)
    door = (hx + math.sin(a) * 1.62, hz + math.cos(a) * 1.62)
    d.box("rancho", d.m("rancho_porta", (0.26, 0.19, 0.15)), door, (1.0, 1.5, 0.08), rot, 1.1)
    d.planks([(hx + math.sin(a) * 2.0, hz + math.cos(a) * 2.0), (hx + math.sin(a) * 3.6, hz + math.cos(a) * 3.6)], 1.2, 0.5, color=(0.52, 0.4, 0.27))
    d.solid(hx, hz, 4.6, 4.0, 3.2, rot)
    # píer: o trecho inteiro sai de sea.pier (no build); aqui as tábuas tortas da ponta quebrada e as estacas órfãs
    for k, off in enumerate((-19.5, -23.0, -26.5, -30.5)):
        for s in (-1, 1):
            q = SP(PIER_DEG + s * 1.5, SEA_R + off)
            d.cyl("pier", dark, q, 0.2, 0.17, rnd.uniform(0.7, 1.6), -0.3, 6, tilt=(rnd.uniform(-8, 8), rnd.uniform(-8, 8)))
    d.box("pier", wood, shore(PIER_DEG, -17.6), (2.2, 0.16, 2.6), zone_lib.along(SEA_C[0] - hx, SEA_C[1] - hz), 0.34, tilt=(0, -11))
    d.fishing_pole(shore(PIER_DEG + 0.8, -14.2), zone_lib.along(SEA_C[0] - JOCA[0], SEA_C[1] - JOCA[1]) + 35.0, 3.4, 0.7, water_y=0.05)
    for p, r_, kind in ((shore(-158.0, 9.0), 62.0, "net"), (shore(-153.5, 13.0), 20.0, "fish"), (shore(-156.0, 20.5), 100.0, "net")):
        if kind == "net":
            d.net_rack(p, r_)
            d.solid(p[0], p[1], 4.2, 0.6, 2.0, r_)
        else:
            d.fish_rack(p, r_)
            d.solid(p[0], p[1], 2.6, 0.5, 1.7, r_)
    bq = shore(-172.0, 4.5)
    d.rowboat(bq, zone_lib.along(SEA_C[0] - bq[0], SEA_C[1] - bq[1]) + 20.0, 4.4, (0.36, 0.5, 0.62), tilt=(6, 0))
    d.solid(bq[0], bq[1], 3.8, 1.6, 1.0, zone_lib.along(SEA_C[0] - bq[0], SEA_C[1] - bq[1]) + 20.0)
    fire = shore(-163.5, 11.5)
    d.cookfire(fire, 1.0, 40.0)
    d.solid(fire[0], fire[1], 2.2, 2.2, 1.3)
    cq = (hx - 3.6, hz - 2.4)
    d.cargo(cq, 4, 1.2)
    d.solid(cq[0], cq[1], 2.4, 2.4, 1.1)
    for q in ((hx + 3.4, hz - 2.6), (hx + 4.3, hz - 1.8)):
        d.barrel(q, 1.0, color=(0.55, 0.4, 0.26))
    d.solid(hx + 3.85, hz - 2.2, 1.9, 1.5, 1.1)
    d.torch(shore(-166.5, 9.0), 2.2)
    # covos de caranguejo empilhados, boias em estacas e a flâmula azul do rancho (acha-se o Joca de longe)
    trap = d.m("covo", (0.62, 0.5, 0.34))
    trap_d = d.m("covo_esc", (0.4, 0.3, 0.2))
    for k, q in enumerate((shore(-160.0, 4.0), shore(-158.6, 4.6), shore(-159.4, 5.6))):
        d.box("covo", trap, q, (1.0, 0.6, 0.8), 20.0 + k * 31.0, 0.0)
        d.box("covo", trap_d, q, (1.06, 0.08, 0.86), 20.0 + k * 31.0, 0.6)
    d.box("covo", trap, shore(-159.3, 4.7), (1.0, 0.6, 0.8), 64.0, 0.68)
    d.solid(shore(-159.3, 4.7)[0], shore(-159.3, 4.7)[1], 2.6, 2.2, 1.3)
    for k, q in enumerate((shore(-171.0, 9.0), shore(-150.5, 5.0), shore(-147.5, 18.5))):
        d.cyl("boia", dark, q, 0.09, 0.07, 1.5, 0.0, 5)
        d.cyl("boia", d.m("boia", (0.86, 0.36, 0.22)) if k % 2 == 0 else d.m("boia_azul", (0.3, 0.5, 0.74)), q, 0.26, 0.2, 0.34, 1.5, 7)
        d.cyl("boia", d.m("boia_branca", (0.95, 0.95, 0.92)), q, 0.2, 0.0, 0.2, 1.84, 7)
    fq = (hx - 2.9, hz + 2.6)
    d.flag(fq, (0.3, 0.5, 0.74), 5.6, 30.0, (0.4, 0.29, 0.2), w=1.2, drop=1.8)
    d.solid(fq[0], fq[1], 0.4, 0.4, 5.0)
    return fire


def big_shells(d, spots):
    """Conchas grandes meio enterradas (búzios de 1 m): cones em espiral creme e rosa, leitura de praia vista de cima."""
    rnd = d.rnd
    cream = d.m("buzio", (0.96, 0.9, 0.78))
    pink = d.m("buzio_rosa", (0.96, 0.72, 0.66))
    band = d.m("buzio_faixa", (0.8, 0.58, 0.42))
    for k, (x, zz) in enumerate(spots):
        rot = rnd.uniform(0, 360)
        s = rnd.uniform(0.7, 1.15)
        ti = (rnd.uniform(48, 66), rnd.uniform(-10, 10))
        d.cyl("buzio", cream if k % 3 else pink, (x, zz), 0.62 * s, 0.0, 1.5 * s, 0.05, 7, rot, ti)
        d.cyl("buzio", band, (x, zz), 0.66 * s, 0.5 * s, 0.14 * s, 0.05, 7, rot, ti, cap=False)
        d.cyl("buzio", band, (x, zz), 0.42 * s, 0.3 * s, 0.1 * s, 0.05 + 0.5 * s, 7, rot, ti, cap=False)


def kings_reef(z, d):
    """Recife do Rei (ponta leste): costelas de leviatã fincadas em meia-lua em volta da arena (abertas para a praia),
    lajes escuras de recife no raso com espuma, corais e conchas grandes. Nada sólido dentro da arena."""
    rnd = d.rnd
    bone = d.m("costela", (0.93, 0.9, 0.8))
    kx, kz = KING
    out = math.atan2(kz - SEA_C[1], kx - SEA_C[0])        # do mar para a terra
    for k, da in enumerate((-78.0, -50.0, -22.0, 22.0, 50.0, 78.0)):
        a = out + math.radians(da)
        r = 13.4
        base = (kx + math.cos(a) * r, kz + math.sin(a) * r)
        if not d.ok(base[0], base[1], 0.6, road=0.4, water=0.3):
            continue
        h = 5.6 - abs(da) * 0.02
        pts = [(base[0], 0.0, base[1]), (base[0] + math.cos(a) * 0.5, h * 0.55, base[1] + math.sin(a) * 0.5),
               (base[0] - math.cos(a) * 0.5, h * 0.92, base[1] - math.sin(a) * 0.5), (base[0] - math.cos(a) * 2.2, h, base[1] - math.sin(a) * 2.2)]
        d.tube("costela", bone, pts, 0.42, 0.13, 6)
        d.solid(base[0], base[1], 0.8, 0.8, 3.0)
    # arena: areia batida e úmida (tom do próprio chão), crânio do leviatã no fundo, do lado da terra
    d.blob("praia", d.m("patch_areia_molhada", act2_dress.WET), KING, 10.5, 0.0086, 0.16)
    d.blob("praia", d.m("patch_arena_clara", (0.88, 0.81, 0.6)), KING, 6.5, 0.009, 0.2)
    sk = (kx + math.cos(out) * 15.2, kz + math.sin(out) * 15.2)
    if d.ok(sk[0], sk[1], 1.6, road=0.4, water=0.3):
        srot = zone_lib.along(kx - sk[0], kz - sk[1])
        d.rock("costela", bone, sk, 1.7, 0.0, 0.7, sx=1.5, rot=srot, sub=2)
        d.rock("costela", bone, (sk[0] + (kx - sk[0]) * 0.16, sk[1] + (kz - sk[1]) * 0.16), 1.0, 0.0, 0.6, sx=1.6, rot=srot, sub=2)
        for sgn in (-1, 1):
            a2 = out + math.pi / 2 * sgn
            hq = (sk[0] + math.cos(a2) * 1.5, sk[1] + math.sin(a2) * 1.5)
            d.tube("costela", bone, [(hq[0], 1.0, hq[1]), (hq[0] + math.cos(a2) * 1.3, 2.0, hq[1] + math.sin(a2) * 1.3),
                                     (hq[0] + math.cos(a2) * 1.5, 3.2, hq[1] + math.sin(a2) * 1.5)], 0.3, 0.05, 5)
        d.solid(sk[0], sk[1], 4.4, 3.0, 2.2, srot)
    reef = d.m("pedra_recife", (0.36, 0.37, 0.42))
    reef_top = d.m("pedra_recife_topo", (0.5, 0.52, 0.56))
    foam = d.m("patch_espuma_borda", (0.97, 0.99, 1.0))
    coral = [d.m("coral_rosa", (0.96, 0.55, 0.56)), d.m("coral_laranja", (0.98, 0.68, 0.4)), d.m("coral_lilas", (0.74, 0.6, 0.9))]
    for k in range(13):
        deg = KING_DEG + rnd.uniform(-17.0, 15.0)
        q = shore(deg, -rnd.uniform(2.5, 13.0))
        if math.hypot(q[0], q[1]) > z.rim_r(math.atan2(q[1], q[0])) - 1.0:
            continue
        s = rnd.uniform(1.2, 2.6)
        d.blob("mar", foam, q, s * 1.45, 0.0362, 0.3)
        d.slab("recife", reef, reef_top, q, s, rnd.uniform(0.3, 0.7), 0.25, rnd.uniform(1.0, 1.5), rnd.uniform(0, 180), 0.0)
        if k % 2 == 0:
            for j in range(3):
                d.cyl("recife", coral[(k + j) % 3], (q[0] + rnd.uniform(-s, s) * 0.5, q[1] + rnd.uniform(-s, s) * 0.5), 0.16, 0.05,
                      rnd.uniform(0.5, 0.9), 0.3, 5, rnd.uniform(0, 90), (rnd.uniform(-14, 14), rnd.uniform(-14, 14)))
    big_shells(d, [(kx + math.cos(out + t) * 11.0, kz + math.sin(out + t) * 11.0) for t in (-0.25, 0.62)])


def driftwood(d, n=16):
    rnd = d.rnd
    grey = d.m("madeira_deriva", (0.7, 0.64, 0.54))
    for _ in range(n * 6):
        if n <= 0:
            break
        q = shore(rnd.uniform(-158.0, -20.0), rnd.uniform(2.5, BEACH - 3.0))
        if not d.ok(q[0], q[1], 1.4, road=0.6, water=0.0):
            continue
        rot = rnd.uniform(0, 180)
        L = rnd.uniform(1.8, 3.4)
        d.log("deriva", grey, q, rnd.uniform(0.13, 0.22), L, rot, r1=0.09)
        if rnd.random() < 0.5:
            d.log("deriva", grey, (q[0] + rnd.uniform(-0.6, 0.6), q[1] + rnd.uniform(-0.6, 0.6)), 0.09, L * 0.6, rot + rnd.uniform(40, 100), r1=0.05)
        d.reserve(q[0], q[1], 2.0)
        n -= 1


def build(export=False):
    z = Zone(ZONE, size=SIZE, rim=RIM, seed=21, palette={
        "road": (0.83, 0.74, 0.54), "cliff_rock": SANDSTONE, "cliff_rock_d": (0.6, 0.48, 0.37), "cliff_grass": (0.6, 0.66, 0.4),
        "hill_grass": (0.9, 0.84, 0.62), "duna": (0.84, 0.76, 0.55), "wood": (0.55, 0.41, 0.27), "water": (0.4, 0.72, 0.8),
    })
    portal = polar(z, GORGE_ANG, 7)
    arrive = polar(z, GORGE_ANG, 15)
    z.data["spawn"] = list(arrive)
    z.turn = TURN
    z.portal("to_town", portal, "city_aldara", ALDARA_ARRIVE, "Vale de Aldara")
    z.block(arrive, 7.5)
    z.cam_game = shore(-160.0, 10.0)

    # ---------- o mar (baía) e a areia; hub do Joca na ponta oeste ----------
    sea.sea(z, SEA_C, SEA_R, beach=BEACH)
    hub = shore(-162.0, 12.0)
    z.patch("rancho", hub, 10.5, (0.86, 0.78, 0.57), y=0.0064)
    z.data["town"] = {"center": [hub[0], hub[1]], "radius": 0.0, "gates": []}
    a, b = shore(PIER_DEG, 1.5), shore(PIER_DEG, -16.5)
    sea.pier(z, "joca", a, b, w=2.6, wood=(0.58, 0.43, 0.28))
    tide_pools(z)
    sea_stacks(z)

    # ---------- chão das dunas (lido de cima): areal das tocas, coqueiral, lagoa ----------
    z.patch("areal", BURROWS, 13.0, (0.9, 0.83, 0.6))
    z.patch("coqueiral", PALM_GROVE, 14.0, (0.78, 0.76, 0.5), grass=True)
    z.patch("lagoa", LAGOON[0], LAGOON[1] + 7.0, (0.84, 0.79, 0.56), y=0.0052)
    z.lake("lagoa_dunas", LAGOON[0], LAGOON[1], material="water")

    # ---------- trilhas: a das Dunas fecha o laço por trás; três descidas até a areia ----------
    east_end = shore(-34.0, 20.0)
    z.road("dunas", [arrive, (-70.0, 4.0), (-58.0, -20.0), (-40.0, -40.0), (-22.0, -50.0), (0.0, -49.0), (20.0, -46.0), (40.0, -36.0),
                     (57.0, -18.0), (65.0, -3.0), east_end], w=TRAIL_W, end_clearing=False)
    z.road("rancho", [arrive, shore(-155.0, 21.0), shore(-151.0, 13.0)], w=TRAIL_W)
    z.road("descida_oeste", [(-40.0, -40.0), (-38.0, -26.0), shore(-119.0, BEACH - 1.0)], w=TRAIL_W)
    z.road("descida_meio", [(0.0, -49.0), (4.0, -38.0), shore(-88.0, BEACH - 1.0)], w=TRAIL_W)
    z.road("descida_leste", [(40.0, -36.0), (36.0, -24.0), shore(-58.0, BEACH - 1.0)], w=TRAIL_W)
    z.road("lagoa", [(-22.0, -50.0), (-17.0, -58.0), (LAGOON[0][0] - 9.0, LAGOON[0][1] + 6.0)], w=TRAIL_W)
    z.arrival(arrive, toward=portal, r=6.0)

    # ---------- relevo: dunas altas (sólidas, de areia) entre a praia e a trilha e junto das falésias ----------
    for i, (c, r, lv) in enumerate([((-64.0, -44.0), 7.0, 2), ((-34.0, -70.0), 7.5, 2), ((22.0, -72.0), 8.0, 2), ((58.0, -52.0), 6.5, 2),
                                    ((78.0, -24.0), 6.0, 1), ((-20.0, -34.0), 5.0, 1), ((19.0, -32.0), 5.0, 1), ((-80.0, -8.0), 5.5, 2)]):
        z.terrace("duna_%d" % i, c, r, lv, rock="duna", top="hill_grass")
    z.cliffs(snow=False)
    sea.sink_cliffs(z)

    # ---------- vegetação: moitas de restinga e pedras de arenito; as palmeiras vêm no acabamento ----------
    for c, r in ((hub, 13.0), (KING, 14.0), (BURROWS, 11.0), (PALM_GROVE, 4.0)):
        z.block(c, r)
    for mid, deg, off, r, n, resp in PACKS:
        z.block(shore(deg, off), r * 0.6)
    obs = z.data["obstacles"]
    z.scatter("rock", [((0, -50), 60, 16), ((-70, -20), 20, 5), ((70, -20), 20, 5)], 0, (1.5, 1.0, 1.3), [SANDSTONE, (0.66, 0.54, 0.42)],
              margin=3.2, spacing=3.0, scale=(0.8, 1.7))
    z.rim_belt(70, (1.6, 1.1, 1.4), [SANDSTONE, (0.66, 0.54, 0.42)], kind="rock")
    nrnd = random.Random(77)
    inland = lambda x, zz, m: z.free(x, zz, m) and math.hypot(x - SEA_C[0], zz - SEA_C[1]) > SEA_R + BEACH + 1.5
    nature.scatter(z.ob, inland, nrnd, "bush", [((0, -55), 62, 70), ((-72, -10), 22, 14), ((74, -12), 20, 12)], (1.7, 0.9, 1.7),
                   [(0.42, 0.56, 0.32), (0.5, 0.6, 0.34), (0.36, 0.5, 0.3)], solid=False, margin=2.4, spacing=2.8, avoid=obs)
    nature.scatter(z.ob, inland, nrnd, "flowers", [((0, -55), 60, 26)], (1.5, 0.45, 1.5), [(0.98, 0.9, 0.5), (0.96, 0.62, 0.66), (0.97, 0.97, 0.94)],
                   solid=False, margin=2.2, spacing=3.6, avoid=obs)
    nature.clear_banks(obs, z.rivers, [LAGOON], 0.0)
    nature.shore(z.ob, nrnd, z.rivers, [LAGOON], list(z.road_polys.values()), 0.0)

    # ---------- NPC e pontos de bot (nome e falas em MapsCatalog.BEACH_NPCS) ----------
    z.npc("beach_fisher", JOCA[0], JOCA[1], face_to(JOCA[0], JOCA[1], hub[0], hub[1] - 4.0))
    z.data["hangouts"] = [[round(q[0], 2), round(q[1], 2)] for q in (shore(-159.0, 6.5), shore(-166.0, 14.0), shore(-157.0, 15.5),
                                                                    shore(-169.0, 9.5), shore(-152.0, 9.0), shore(-163.0, 19.0))]

    # ---------- monstros ----------
    for mid, deg, off, r, n, resp in PACKS:
        q = shore(deg, off)
        z.spawner(mid, q[0], q[1], r, n, resp)
    for mid, q, r, n, resp in DUNE_PACKS:
        z.spawner(mid, round(q[0], 2), round(q[1], 2), r, n, resp)
    z.data["spawners"].append({"monster_id": "crab_king", "pos": [KING[0], KING[1]], "radius": 2, "count": 1, "respawn": 150.0,
                               "emerge": [SEA_C[0], SEA_C[1], SEA_R]})      # sai do mar e anda até a arena

    # ---------- acabamento (dress.py) ----------
    # pilha (mm): dunas 0,8/1,6/2,4 < areia do mar 4,0 (sea.py) < línguas de areia 4,6 < lagoa 5,2 < manchas Zone.patch 6,0/6,4/6,8
    # < areia molhada e riscos 7,8-8,2 < aro das poças 9,6 < acostamento 9,8 < trilha 12 < poças 12,5
    d = Dress(z, 331)
    rnd = d.rnd
    d.mottle([("duna_clara", (0.82, 0.78, 0.53)), ("duna_capim", (0.61, 0.66, 0.4)), ("duna_seca", (0.76, 0.73, 0.48))],
             [((0, -48), 80, 120)], y=0.0008, rmin=3.0, rmax=8.5, step=0.0008)
    d.road_edges((0.76, 0.68, 0.5), extra=-0.3, wvar=0.4)
    d.roadside(d.m("seixo_trilha", (0.72, 0.64, 0.52)), d.m("capim_duna", (0.62, 0.64, 0.34)), every=5.0, lean=(0.12, -0.05))
    d.reserve(KING[0], KING[1], 12.0)          # arena do Rei: nada de palmeira nem bote no meio da luta
    for mid, deg, off, r, n, resp in PACKS:    # e folga no miolo de cada matilha
        q = shore(deg, off)
        d.reserve(q[0], q[1], 2.5)
    joca_camp(z, d)
    pier_a, pier_b = zone_lib.Vector(shore(PIER_DEG, 2.0)), zone_lib.Vector(shore(PIER_DEG, -32.0))
    act2_dress.shoreline(d, SEA_C, SEA_R, BEACH, palms=18, boats=2, rocks=20, tongue_y=0.0046, shallows=False,
                         rock_ok=lambda p: zone_lib.seg_dist(zone_lib.Vector(p), pier_a, pier_b) > 4.5)      # nada de pedra atravessando o píer
    kings_reef(z, d)
    driftwood(d)
    big_shells(d, [q for q in (shore(rnd.uniform(-150.0, -28.0), rnd.uniform(9.0, BEACH - 2.0)) for _ in range(40))
                   if d.ok(q[0], q[1], 1.0, road=0.5, water=0.0)][:10])
    # pedras de poça: lajes baixas e escuras ao lado de cada poça de maré (os eremitas moram ali)
    for i, (deg, off, r) in enumerate(POOLS):
        q = shore(deg + (r + 1.6) / (SEA_R + off) * 57.3, off + 0.6)
        if d.ok(q[0], q[1], 1.2, road=0.5, water=0.0):
            d.outcrop(q, 1.3, 3, (0.5, 0.48, 0.47), hmul=0.7)
            d.solid(q[0], q[1], 1.9, 1.9, 1.2)
    # Coqueiral: palmeiras juntas (troncos sólidos), cocos no chão
    placed = 0
    for _ in range(260):
        if placed >= 16:
            break
        a_, r_ = rnd.uniform(0, math.tau), 15.0 * math.sqrt(rnd.random())
        q = (PALM_GROVE[0] + math.cos(a_) * r_, PALM_GROVE[1] + math.sin(a_) * r_)
        if not d.ok(q[0], q[1], 0.6, road=1.6, tall=True):
            continue
        d.palm(q, rnd.uniform(5.0, 6.6), rnd.uniform(0.06, 0.26), rnd.uniform(0, math.tau))
        d.solid(q[0], q[1], 0.8, 0.8, 5.0)
        d.reserve(q[0], q[1], 4.2)
        placed += 1
    coco = d.m("coco", (0.42, 0.3, 0.2))
    for q in d.spots([(PALM_GROVE, 14.0, 12)], r=0.4, spacing=2.0, road=0.4):
        d.pebbles("praia3d", coco, q, rnd.randint(1, 3), 0.7, (0.14, 0.2))
    # palmeiras soltas pelas dunas e em volta da lagoa
    placed = 0
    for _ in range(400):
        if placed >= 14:
            break
        a_, r_ = rnd.uniform(0, math.tau), 70.0 * math.sqrt(rnd.random())
        q = (math.cos(a_) * r_, -52.0 + math.sin(a_) * r_ * 0.6)
        if math.hypot(q[0] - SEA_C[0], q[1] - SEA_C[1]) < SEA_R + BEACH + 3.0 or not d.ok(q[0], q[1], 0.6, road=2.0, blocked=True, tall=True):
            continue
        d.palm(q, rnd.uniform(4.6, 6.2), rnd.uniform(0.08, 0.3), rnd.uniform(0, math.tau))
        d.solid(q[0], q[1], 0.8, 0.8, 5.0)
        d.reserve(q[0], q[1], 6.0)
        placed += 1
    # Areal das Tocas: bocas de toca (areia escura com montinho ao lado) em volta das marias-farinha
    hole = d.m("patch_toca", (0.56, 0.47, 0.34))
    mound = d.m("monte_areia", (0.93, 0.87, 0.66))
    for k in range(14):
        a_, r_ = rnd.uniform(0, math.tau), rnd.uniform(2.0, 11.5)
        q = (BURROWS[0] + math.cos(a_) * r_, BURROWS[1] + math.sin(a_) * r_)
        d.blob("toca", hole, q, rnd.uniform(0.3, 0.5), 0.0074, 0.15)
        d.rock("mini", mound, (q[0] + 0.6, q[1] + 0.25), rnd.uniform(0.35, 0.6), -0.08, 0.45)
    # capim de duna alto (com flor de restinga) por toda a faixa de trás
    act2_dress.meadow(d, [((0, -56), 60, 46), ((-70, -12), 20, 8), ((72, -14), 20, 8)], DUNE_GRASS,
                      flowers=((0.98, 0.9, 0.5), (0.96, 0.62, 0.66), (0.97, 0.97, 0.94)), lean=(0.12, -0.05), h=0.95, every=2)
    act2_dress.outcrops(d, [((0, -62), 52, 5), ((-74, -22), 16, 2), ((72, -30), 16, 2)], SANDSTONE, top=(0.86, 0.74, 0.56), r=(1.6, 2.8))
    sg = (arrive[0] + 5.0, arrive[1] - 4.6)                  # placa na chegada
    if d.ok(sg[0], sg[1], 0.5, road=0.3):
        d.signpost(sg, 60.0)
        d.solid(sg[0], sg[1], 0.5, 0.5, 2.4)
    d.flush()

    print("field_crab_beach (desenho, antes do giro): portal %s chegada %s rancho %s joca %s rei %s" % (portal, arrive, HUT, JOCA, KING))
    print("BACK aldara (chegada no jogo, depois do giro): (%.1f, %.1f)" % (-arrive[1], arrive[0]))
    print("field_crab_beach: spawners %s" % [(s["monster_id"], s["pos"], s["radius"], s["count"]) for s in z.data["spawners"]])
    print("field_crab_beach: meio %s areal %s lagoa %s coqueiral %s" % (MID, BURROWS, LAGOON, PALM_GROVE))
    return z.finish(export, poi=MID, ground=GROUND)
