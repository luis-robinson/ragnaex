"""Costa Partida (field_coast, Lv 30-35): o primeiro chão de Kharzun. Vale fechado por penhascos ao norte e pelo mar
turquesa ao sul (praia de areia clara com espuma). No centro, a Encruzilhada dos Colonos (posto de vigia da Aurora,
batedora guia). POIs: Praia dos Naufrágios (cascos na areia, nagas, a Mãe das Marés), Aldeia Goblin de Palafitas (no
mangue a oeste, com a boca das Grutas Goblin ao norte dela), Falésias dos Ninhos (patamares ao norte, vanguarda orc),
Acampamento dos Ginetes (nordeste; vira fazenda dos colonos em C3) e Santuário Afogado (pedra da Aurora a leste).
Marco: o farol branco com faixas no promontório sudeste (aceso em C2). O portão leste leva a Porto Esperança.
Mangue = rio escuro do norte ao mar, com pontes onde as estradas cruzam.

    set RAGNAEX_ROOT=<projeto ou worktree>
    blender -b --factory-startup --python tools/blender/zones/run_zone.py -- build_field_coast <pasta_png> --export
"""
import math
import random
import act2_dress
import horde
import nature
import places
import sea
import zone_lib
from zone_lib import Zone, box, cyl, cone, disc, mat

ZONE = "field_coast"
SEA_C, SEA_R = (30.0, 200.0), 125.0
PORT_ARRIVE = (-75.8, -27.6)            # chegada em city_port (build_city_port imprime "BACK coast"): garganta oeste do porto
VILLAGE = (-92.0, 22.0)                 # Aldeia Goblin de Palafitas
NESTS = (-15.0, -92.0)                  # Falésias dos Ninhos
BEACH = (-12.0, 70.0)                   # Praia dos Naufrágios
LIGHTHOUSE = (66.0, 88.0)
RIDERS = (72.0, -58.0)
MANGROVE = [(-60.0, -112.0), (-55.0, -80.0), (-45.0, -50.0), (-48.0, -20.0), (-60.0, 10.0), (-62.0, 40.0), (-48.0, 75.0), (-40.0, 104.0)]
GOBLIN_BOSS_Q, RIDERS_Q, LIGHT_Q = "hx_goblin_boss", "hx_riders_camp", "hx_lighthouse"
STEPPE_DEG = -72.0                      # garganta norte-nordeste: passagem para as Estepes de Cinza (abre em C4)
STEPPE_ARRIVE_THERE = (-15.8, 89.9)     # chegada em field_steppe (build_field_steppe: "BACK coast")
WRECKS = [((-24.0, 84.0), 25.0), ((8.0, 79.0), -35.0), ((-44.0, 92.0), 70.0)]      # cascos na praia: (centro, rumo)
MANGROVE_COLS = [(0.2, 0.4, 0.3), (0.24, 0.44, 0.3), (0.18, 0.36, 0.3)]           # copas do mangue (act2_dress acha as árvores pela cor)

PLACES = [
    {"type": "cabin", "id": "naufragos", "pos": (-78.0, 48.0), "face": 300.0, "npc": "castaway_tomas", "roof": (0.5, 0.42, 0.32), "wall": (0.62, 0.52, 0.4)},
    {"type": "cabin", "id": "faroleiro", "pos": (52.0, 60.0), "face": 229.0, "npc": "keeper_ilda", "roof": (0.78, 0.26, 0.22), "wall": (0.9, 0.88, 0.82)},
    {"type": "shrine", "id": "santuario_afogado", "pos": (92.0, 18.0), "npc": "drowned_altar", "ground": (0.56, 0.66, 0.68)},
    {"type": "camp", "id": "ginetes", "pos": RIDERS, "face": 158.0, "mob": "wolf_rider", "count": 4, "cloth": (0.62, 0.2, 0.18), "respawn": 22.0,
     "ground": (0.5, 0.4, 0.3), "when": {"unless": RIDERS_Q}},
    {"type": "dungeon", "id": "grutas_goblin", "dungeon": "dg_goblin"},
]


def polar(z, ang_deg, inset):
    a = math.radians(ang_deg)
    r = z.rim_r(a) - inset
    return (round(math.cos(a) * r, 1), round(math.sin(a) * r, 1))


def stilt_village(z):
    """Palafitas no mangue: chão de lama esverdeada, poças, cabanas sobre estacas, totem goblin no meio.
    Em C4 (Agitador-Mor morto) a aldeia vira mista: bandeirolas e barracas de troca aparecem (sem colisão)."""
    disc(z.coll, z.P + "chao_mangue", VILLAGE, 19.0, 0.006, mat("patch_mangue", (0.3, 0.4, 0.3)), 48, 0.15, 4)
    z.data["roads"].append({"kind": "street", "w": 0, "pts": [list(VILLAGE)], "r": 19.0})
    pool = mat("poca_mangue", (0.24, 0.42, 0.4))
    for i in range(6):
        a = math.tau * (i + 0.3) / 6
        disc(z.coll, z.P + "mangue_poca_%d" % i, (VILLAGE[0] + math.cos(a) * 14.5, VILLAGE[1] + math.sin(a) * 14.5), 2.6, 0.012, pool, 14, 0.2, i)
    wood = mat("palafita", (0.44, 0.32, 0.2))
    thatch = mat("palha", (0.64, 0.56, 0.3))
    for i in range(6):
        a = math.tau * (i + 0.5) / 6
        c = (VILLAGE[0] + math.cos(a) * 9.5, VILLAGE[1] + math.sin(a) * 9.5)
        for dx in (-1.2, 1.2):
            for dz in (-1.2, 1.2):
                cyl(z.coll, z.P + "palafita_%d_estaca_%d_%d" % (i, dx > 0, dz > 0), (c[0] + dx, c[1] + dz), 0.18, 0.16, 1.6, wood, 0.0, 6)
        box(z.coll, z.P + "palafita_%d_piso" % i, c, (3.4, 0.2, 3.4), math.degrees(-a), wood, 1.5)
        box(z.coll, z.P + "palafita_%d_cabana" % i, c, (2.8, 1.6, 2.8), math.degrees(-a), mat("palafita_parede", (0.56, 0.42, 0.28)), 1.7)
        cone(z.coll, z.P + "palafita_%d_teto" % i, c, 2.4, 1.8, thatch, 3.3, 8)
        z.ob("pillar", c[0], c[1], (3.4, 3.0, 3.4), visible=False)
    cyl(z.coll, z.P + "palafita_totem", VILLAGE, 0.6, 0.45, 4.2, mat("totem_goblin", (0.6, 0.24, 0.18)), 0.0, 6)
    z.ob("pillar", VILLAGE[0], VILLAGE[1], (1.4, 4.2, 1.4), visible=False)
    for i in range(4):                                   # C4: barracas de troca da Nikki (aparecem com o Agitador-Mor morto)
        a = math.tau * i / 4 + 0.4
        z.ob("stall", VILLAGE[0] + math.cos(a) * 5.0, VILLAGE[1] + math.sin(a) * 5.0, (2.6, 2.2, 1.8), math.degrees(-a) + 90,
             color=[(0.9, 0.7, 0.3), (0.4, 0.7, 0.5)][i % 2], when={"if": GOBLIN_BOSS_Q})
    z.block(VILLAGE, 21.0)


def nest_cliffs(z):
    """Falésias dos Ninhos: patamares de pedra com ninhos de palha e ovos em cima; a vanguarda orc acampa embaixo."""
    straw = mat("ninho", (0.7, 0.58, 0.32))
    egg = mat("ovo", (0.92, 0.9, 0.8))
    for i, (c, r, lv) in enumerate([((-36.0, -101.0), 8.0, 3), ((6.0, -105.0), 7.0, 3), ((-14.0, -112.0), 5.0, 2)]):
        top = z.hill("falesia_%d" % i, c, r, lv, rock="cliff_rock", top="hill_grass", step=2.2)
        disc(z.coll, z.P + "ninho_%d" % i, c, r * 0.35, top + 0.05, straw, 12, 0.25, i)
        for k in range(3):
            a = math.tau * k / 3 + i
            zone_lib.blob(z.coll, z.P + "ninho_%d_ovo_%d" % (i, k), (c[0] + math.cos(a) * 0.9, c[1] + math.sin(a) * 0.9), 0.55, top + 0.45, egg, k, 1.3)
    z.patch("falesias", NESTS, 18.0, (0.6, 0.58, 0.5), grass=True)
    for k in range(3):                                   # fogueiras e estacas da vanguarda orc
        a = math.tau * k / 3 + 0.5
        z.ob("tent", NESTS[0] + 10.0 + math.cos(a) * 6.0, NESTS[1] + 16.0 + math.sin(a) * 6.0, (3.0, 2.2, 3.0), math.degrees(-a), color=(0.5, 0.2, 0.16))


def wrecks(z):
    """Praia dos Naufrágios: cascos tombados na areia (meio na água), caixotes e barris espalhados."""
    for i, (c, rot) in enumerate(WRECKS):
        sea.ship(z, "naufragio_%d" % i, c, rot, L=12.0 + i * 2, wreck=True)
        z.ob("wall", c[0], c[1], (12.0 + i * 2, 2.0, 3.4), math.degrees(-math.radians(rot)), visible=False)
    rnd = random.Random(31)
    for i in range(10):
        x, y = BEACH[0] + rnd.uniform(-22, 22), BEACH[1] + rnd.uniform(-6, 6)
        if z.free(x, y, 2.0):
            z.ob("crate" if i % 2 else "barrel", x, y, (1.0, 1.0, 1.0) if i % 2 else (0.8, 1.0, 0.8), rnd.uniform(0, 360))
    for i in range(7):                                   # madeira à deriva e mastro quebrado fincado na areia
        x, y = BEACH[0] + rnd.uniform(-26, 26), BEACH[1] + rnd.uniform(-4, 9)
        if z.free(x, y, 2.5):
            z.ob("log", x, y, (3.2, 0.6, 0.7), rnd.uniform(0, 180), color=(0.62, 0.54, 0.42))
    cyl(z.coll, z.P + "naufragio_mastro_fincado", (BEACH[0] + 6.0, BEACH[1] + 4.0), 0.3, 0.22, 7.0, mat("mastro_velho", (0.4, 0.3, 0.2)), 0.0, 6)
    box(z.coll, z.P + "naufragio_vela_rasgada", (BEACH[0] + 6.6, BEACH[1] + 4.0), (0.08, 2.4, 2.2), 20.0, mat("vela_rasgada", (0.86, 0.82, 0.7)), 3.4)
    z.ob("pillar", BEACH[0] + 6.0, BEACH[1] + 4.0, (0.7, 7.0, 0.7), visible=False)


HUB_R = 20.5                            # paliçada baixa do posto (praça r=17 por dentro)
HUB_GATES = [6.0, 97.0, 188.0, -97.0]   # graus: onde as estradas leste, praia, oeste e norte cruzam o anel


def crossroads(z):
    """Encruzilhada dos Colonos: posto murado da Aurora. Praça de terra larga (cabe grupo + bots), paliçada baixa em anel
    com quatro vãos (um por estrada), torre de vigia encostada no muro, barracas, poço e o estandarte no meio."""
    z.M["pave_encruzilhada"] = mat("pave_encruzilhada", (0.72, 0.62, 0.46))
    z.M["estaca_posto"] = mat("estaca_posto", (0.82, 0.68, 0.48))
    z.patch("posto", (0.0, 0.0), HUB_R + 2.5, (0.64, 0.56, 0.42))
    z.plaza("encruzilhada", (0.0, 0.0), 17.0, "pave_encruzilhada")
    z.ring_wall("posto", (0.0, 0.0), HUB_R, [math.radians(g) for g in HUB_GATES], gate_half=4.6, height=2.2, material="estaca_posto", stakes=True)
    wood = mat("vigia", (0.52, 0.38, 0.24))
    blue = mat("vigia_teto", (0.3, 0.42, 0.72))
    for g in HUB_GATES:                                   # tochas-bandeira nos vãos: de cima, quatro pontos azuis marcam as saídas
        for sgn in (-1, 1):
            a = math.radians(g + sgn * 15.5)
            q = (math.cos(a) * HUB_R, math.sin(a) * HUB_R)
            cyl(z.coll, z.P + "posto_portal_%d_%d" % (int(g), sgn), q, 0.7, 0.6, 3.4, wood, 0.0, 8)
            cone(z.coll, z.P + "posto_portal_teto_%d_%d" % (int(g), sgn), q, 1.1, 1.0, blue, 3.4, 8)
            z.ob("pillar", q[0], q[1], (1.5, 3.4, 1.5), visible=False)
    c = (-10.5, -10.5)
    for dx in (-1.4, 1.4):
        for dz in (-1.4, 1.4):
            cyl(z.coll, z.P + "vigia_poste_%d_%d" % (dx > 0, dz > 0), (c[0] + dx, c[1] + dz), 0.22, 0.2, 6.0, wood, 0.0, 6)
    box(z.coll, z.P + "vigia_plataforma", c, (3.8, 0.3, 3.8), 0.0, wood, 6.0)
    cone(z.coll, z.P + "vigia_teto", c, 2.8, 1.8, blue, 7.6, 4)
    z.ob("pillar", c[0], c[1], (3.6, 6.0, 3.6), visible=False)
    for k, a in enumerate((0.85, 2.4, 5.45)):             # barracas dos colonos encostadas no muro (fora das estradas)
        z.ob("tent", math.cos(a) * 14.5, math.sin(a) * 14.5, (3.2, 2.3, 3.0), math.degrees(-a) - 90, color=[(0.36, 0.48, 0.78), (0.85, 0.8, 0.66)][k % 2])
    z.ob("well", 6.5, 6.5, (1.6, 1.4, 1.6))
    z.ob("crate", 11.0, -9.0, (1.0, 1.0, 1.0))
    z.ob("barrel", 12.2, -7.8, (0.8, 1.0, 0.8))
    z.ob("crate", 9.6, -10.2, (1.0, 1.0, 1.0), 20.0)
    for a in (0.5, 2.05, 3.65, 5.2):
        z.ob("lamp", math.cos(a) * 16.0, math.sin(a) * 16.0, (0.4, 3.0, 0.4))
    cyl(z.coll, z.P + "encruzilhada_mastro", (0.0, 0.0), 0.16, 0.12, 8.0, wood, 0.0, 6)      # estandarte da Aurora: acha-se o posto de longe
    box(z.coll, z.P + "encruzilhada_bandeira", (1.3, 0.0), (2.4, 1.5, 0.06), 0.0, mat("bandeira_aurora", (0.95, 0.88, 0.55)), 6.3)
    disc(z.coll, z.P + "encruzilhada_roseta", (0.0, 0.0), 3.2, 0.018, mat("pave_roseta", (0.9, 0.84, 0.66)), 16)
    z.ob("pillar", 0.0, 0.0, (0.6, 8.0, 0.6), visible=False)
    z.npc("coast_scout", 3.0, -6.0, 200.0)
    z.data["hangouts"] = [[round(math.cos(a) * r, 2), round(math.sin(a) * r, 2)] for a, r in
                          ((0.45, 10.0), (1.25, 9.0), (2.0, 11.5), (2.85, 9.0), (3.6, 11.0), (4.3, 8.5), (5.0, 11.0), (5.8, 9.0), (1.6, 5.0), (4.0, 5.0))]
    z.cam_game = (0.0, 0.0)
    z.block((0.0, 0.0), HUB_R + 3.0)


def mangrove_band(z):
    """Mangue lido de cima: faixa de lama verde-escura dos dois lados do braço de mar (só cor, não colide)."""
    z.M["patch_mangue_faixa"] = mat("patch_mangue_faixa", (0.3, 0.43, 0.25))
    zone_lib.ribbon(z.coll, z.P + "chao_mangue_faixa", zone_lib.catmull(MANGROVE, 2.0), 24.0, 0.005, z.M["patch_mangue_faixa"])


def drowned_shrine(z, c):
    """Santuário Afogado: lajes claras da Aurora meio cobertas por poças rasas turquesa e colunas tombadas (lado oeste;
    o leste fica livre para quem chega do porto)."""
    z.M["pave_santuario"] = mat("pave_santuario", (0.84, 0.84, 0.8))
    shallow = mat("agua_rasa", (0.36, 0.74, 0.8))
    disc(z.coll, z.P + "santuario_laje", c, 7.6, 0.012, z.M["pave_santuario"], 10, 0.1, 3)
    for i, (dx, dy, r) in enumerate(((-11.0, -6.0, 3.6), (-12.5, 4.0, 4.4), (-4.0, 12.0, 3.8), (-5.0, -12.5, 3.0), (4.5, 11.5, 2.6))):
        disc(z.coll, z.P + "santuario_poca_%d" % i, (c[0] + dx, c[1] + dy), r, 0.016, shallow, 14, 0.25, i)
        disc(z.coll, z.P + "santuario_poca_borda_%d" % i, (c[0] + dx, c[1] + dy), r + 0.35, 0.01, mat("espuma_mar", sea.FOAM), 14, 0.25, i)
    for i, (dx, dy, rot) in enumerate(((-15.0, -1.0, 20.0), (-8.5, 9.5, 110.0), (-9.0, -10.5, 65.0))):
        z.ob("ruin", c[0] + dx, c[1] + dy, (2.6, 1.6, 1.0), rot, color=(0.86, 0.85, 0.8))


def tide_pools(z):
    """Praia lida de cima: poças de maré turquesa e pedras escuras na areia, entre os cascos."""
    shallow = mat("agua_rasa", (0.5, 0.82, 0.84))
    for i, x in enumerate((-58.0, -36.0, -8.0, 20.0, 42.0, 84.0)):
        y = SEA_C[1] - math.sqrt(SEA_R ** 2 - (x - SEA_C[0]) ** 2) - 6.0 - (i % 2) * 3.0
        disc(z.coll, z.P + "praia_poca_%d" % i, (x, y), 2.4 + (i % 3) * 0.6, 0.012, shallow, 12, 0.3, i)
        z.ob("rock", x + 3.4, y + 0.8, (1.5, 0.8, 1.3), i * 40.0, color=(0.46, 0.44, 0.42))


def steppe_passage(z, portal, arrive):
    """Passagem para as Estepes (C4): estrada do caminho dos ginetes até a garganta norte-nordeste. Entra DEPOIS da
    vegetação (a dispersão da Costa não muda): o que ficou em cima da estrada/chegada sai da lista. Antes do
    Agitador-Mor cair, estacas e estandartes da Horda fecham a boca (o portão de verdade é MapsCatalog.PORTAL_GATES)."""
    poly = z.road("estepes", [(25.0, -52.0), (29.0, -65.0), (27.5, -76.0), arrive, portal], end_clearing=False)
    z.portal("to_field_steppe", portal, "field_steppe", STEPPE_ARRIVE_THERE, "Estepes de Cinza (Lv 35-40)")
    soft = ("tree", "pine", "dead_tree", "rock", "bush", "reeds", "log", "stump", "flowers")
    P = zone_lib.Vector

    def clear(o):
        if o["kind"] not in soft or not o.get("visible", True) or o.get("y"):
            return False
        q = P(o["pos"])
        return zone_lib.poly_dist(q, poly) < 4.6 + max(o["size"][0], o["size"][2]) * 0.5 or (q - P(arrive)).length < 7.0
    z.data["obstacles"][:] = [o for o in z.data["obstacles"] if not clear(o)]
    bc = (27.8, -74.0)                                     # barricada atravessada na estrada, antes da chegada
    for k, off in enumerate((-5.5, 5.5)):
        q = (bc[0] + off, bc[1])
        horde.banner(z, "passo_estepes_fechado_%d" % k, q, horde.HORDE_RED, 6.0, 0.0)
        horde.banner(z, "passo_estepes_aberto_%d" % k, q, horde.AURORA_GOLD, 6.0, 0.0, pole=(0.82, 0.68, 0.48))
        z.ob("pillar", q[0], q[1], (0.6, 6.0, 0.6), visible=False)
    for k, off in enumerate((-2.6, 0.0, 2.6)):
        z.ob("fence", bc[0] + off, bc[1], (2.8, 1.5, 0.5), 0.0, color=horde.STAKE_DARK, when={"unless": GOBLIN_BOSS_Q})


def build(export=False):
    z = Zone(ZONE, seed=13, palette={
        "road": (0.76, 0.66, 0.5), "street": (0.82, 0.76, 0.62), "water_dark": (0.22, 0.38, 0.36),
        "cliff_rock": (0.6, 0.56, 0.5), "cliff_rock_d": (0.48, 0.45, 0.4), "cliff_grass": (0.5, 0.62, 0.38),
        "hill_grass": (0.54, 0.66, 0.4), "leaf": (0.36, 0.58, 0.34),
    })
    portal = polar(z, 8, 7)
    arrive = polar(z, 8, 16)
    z.data["spawn"] = list(arrive)
    z.portal("coast_to_port", portal, "city_port", PORT_ARRIVE, "Porto Esperança")  # id próprio: o portão "to_city_port" é só o cais do Bastião
    print("BACK port", arrive)
    st_portal, st_arrive = polar(z, STEPPE_DEG, 7), polar(z, STEPPE_DEG, 16)
    z.portal_angles.append(math.atan2(st_portal[1], st_portal[0]))        # garganta aberta no anel; a estrada entra no fim
    print("BACK steppe", st_arrive)
    sea.sea(z, SEA_C, SEA_R, beach=18.0)
    mangrove_band(z)
    crossroads(z)

    # ---------- estradas: encruzilhada -> portão leste, falésias, aldeia, praia; costa liga praia/aldeia e praia/farol ----------
    z.road("leste", [(9.0, 0.0), (35.0, 6.0), (62.0, 2.0), (88.0, 8.0), arrive, portal], end_clearing=False)
    z.road("norte", [(0.0, -9.0), (-6.0, -35.0), (-2.0, -58.0), (-10.0, -76.0)])
    z.road("ginetes", [(-4.0, -42.0), (25.0, -52.0), (52.0, -50.0)])
    z.road("oeste", [(-9.0, 0.0), (-26.0, -6.0), (-42.0, -6.0), (-60.0, -12.0), (-70.0, -4.0), (-72.0, 8.0), (-80.0, 14.0)])   # cruza o mangue de frente
    z.road("grutas", [(-72.0, 8.0), (-76.0, -6.0), (-74.0, -20.0)])
    z.road("praia", [(0.0, 9.0), (-6.0, 35.0), (-12.0, 58.0)])
    z.road("costa", [(-12.0, 58.0), (-34.0, 52.0), (-50.0, 40.0), (-72.0, 38.0), (-80.0, 28.0)])                      # idem (ponte reta)
    z.road("farol", [(35.0, 6.0), (46.0, 26.0), (38.0, 44.0)])
    z.road("praia_leste", [(-12.0, 58.0), (10.0, 52.0), (30.0, 48.0), (38.0, 44.0)])
    z.water_tint("water_dark")          # mangue verde-escuro no jogo (sem isso a água da zona puxa para o azul)
    z.river(MANGROVE, w=6.0, material="water_dark")
    z.bridges()

    stilt_village(z)
    nest_cliffs(z)
    wrecks(z)
    top = sea.lighthouse(z, LIGHTHOUSE)
    print("farol topo", top)
    z.patch("praia", BEACH, 16.0, sea.SAND)
    z.patch("santuario_agua", (92.0, 18.0), 17.0, (0.5, 0.62, 0.62))     # sem grama: lajes e poças
    tide_pools(z)

    # ---------- C3: no lugar do acampamento dos ginetes, a fazenda dos colonos (cercas e plantação, sem colisão) ----------
    farm = {"if": RIDERS_Q}
    for i in range(10):
        a = math.tau * i / 10
        z.ob("fence", RIDERS[0] + math.cos(a) * 12.5, RIDERS[1] + math.sin(a) * 12.5, (3.6, 1.0, 0.3), math.degrees(-a) + 90, color=(0.6, 0.46, 0.3), when=farm)
    for i in range(12):
        a = math.tau * i / 12 + 0.2
        r = 4.0 + (i % 3) * 2.2
        z.ob("flowers", RIDERS[0] + math.cos(a) * r, RIDERS[1] + math.sin(a) * r, (2.2, 0.6, 2.2), color=[(0.86, 0.78, 0.36), (0.5, 0.72, 0.32)][i % 2], when=farm)
    z.ob("house", RIDERS[0] - 6.0, RIDERS[1] - 6.0, (5.0, 3.2, 4.4), 30.0, color=(0.86, 0.8, 0.66), roof=(0.3, 0.42, 0.72), when=farm)

    z.cliffs(snow=False)
    places.build(z, PLACES)
    drowned_shrine(z, (92.0, 18.0))
    sea.sink_cliffs(z)

    # ---------- vegetação: mata costeira ao norte, moitas na restinga, juncos no mangue ----------
    obs = z.data["obstacles"]
    z.scatter("tree", [((0, -60), 60, 40), ((70, -20), 35, 14), ((-90, -60), 30, 14), ((40, 30), 20, 6)], 0, (2.0, 4.4, 2.0),
              [(0.32, 0.56, 0.34), (0.4, 0.62, 0.34), (0.3, 0.5, 0.36)], margin=4.6, spacing=5.0, hub_r=HUB_R + 6.0)
    z.rim_belt(110, (2.0, 4.4, 2.0), [(0.3, 0.5, 0.32), (0.36, 0.56, 0.34)])
    z.scatter("rock", [((0, 0), 108, 40)], 0, (1.4, 0.9, 1.2), [(0.66, 0.62, 0.56)], margin=3.5, spacing=3.0, hub_r=HUB_R + 6.0, scale=(0.7, 1.6))
    nrnd = random.Random(53)
    fr = lambda x, zz, m: z.free(x, zz, m, HUB_R + 4.0)
    nature.fix_trees(obs, nrnd, pine_frac=0.25)
    # mangue: copas baixas verde-escuras dos dois lados do braço de mar (as margens ficam livres: clear_banks)
    nature.scatter(z.ob, fr, nrnd, "tree", [((-56, -92), 12, 5), ((-50, -64), 12, 6), ((-50, -32), 11, 5), ((-58, 24), 12, 6), ((-52, 58), 12, 6), ((-42, 90), 10, 4)],
                   (2.6, 4.0, 2.6), MANGROVE_COLS, margin=4.2, spacing=4.4, scale=(0.95, 1.25), avoid=obs)
    nature.scatter(z.ob, fr, nrnd, "bush", [((0, 0), 105, 50), ((-10, 40), 40, 20)], (1.6, 0.85, 1.6), [(0.42, 0.56, 0.32), (0.5, 0.6, 0.34)],
                   solid=False, margin=2.6, spacing=3.0, avoid=obs)
    nature.scatter(z.ob, fr, nrnd, "reeds", [(VILLAGE, 24, 18), ((-60, 30), 20, 10)], (1.3, 1.3, 1.3), nature.REED_COLS, solid=False, margin=1.5, spacing=2.2, avoid=obs)
    nature.woodland_floor(z.ob, fr, nrnd, [((0, -60), 50, 14), ((70, -20), 30, 6)], avoid=obs)
    nature.clear_banks(obs, z.rivers, [], z.river_w)
    nature.shore(z.ob, nrnd, z.rivers, [], list(z.road_polys.values()), z.river_w, keep=0.8)

    steppe_passage(z, st_portal, st_arrive)

    # ---------- monstros (ids do contrato; o jogo troca pelos STAND_INS enquanto o pacote de monstros não chega) ----------
    gob = {"unless": GOBLIN_BOSS_Q}
    rid = {"unless": RIDERS_Q}
    z.spawner("goblin_lancer", -96.0, 26.0, 9, 6, 18.0, when=gob)
    z.spawner("goblin_impaler", -102.0, 4.0, 7, 3, 22.0, when=gob)
    z.spawner("goblin_agitator", -88.0, 32.0, 2, 1, 90.0, when=gob)
    z.spawner("goblin_lancer", -64.0, -58.0, 8, 4, 18.0, when=gob)
    z.spawner("wolf_rider", 40.0, -76.0, 8, 4, 20.0, when=rid)
    z.spawner("wolf_rider", 92.0, -30.0, 8, 3, 20.0, when=rid)
    z.spawner("wolf_raider", 60.0, -86.0, 7, 2, 26.0, when=rid)
    z.spawner("wolf_rider", 60.0, -30.0, 6, 2, 30.0, when={"if": RIDERS_Q})     # C3: só uma patrulha pequena
    z.spawner("orc_recruit", -8.0, -80.0, 8, 4, 20.0)
    z.spawner("orc_recruit", 24.0, -80.0, 7, 3, 20.0)
    z.spawner("naga_tide", -32.0, 70.0, 8, 5, 18.0)
    z.spawner("naga_tide", 26.0, 64.0, 7, 4, 18.0)
    z.spawner("naga_warrior", 76.0, 38.0, 7, 3, 22.0)
    z.spawner("naga_warrior", 86.0, 52.0, 6, 3, 22.0)
    z.spawner("boss_tide_mother", 4.0, 68.0, 2, 1, 240.0)
    act2_dress.coast(z, SEA_C, SEA_R, VILLAGE, NESTS, BEACH, LIGHTHOUSE, (92.0, 18.0), HUB_R, HUB_GATES, WRECKS, MANGROVE_COLS)
    return z.finish(export, poi=BEACH, ground=(0.56, 0.66, 0.42))
