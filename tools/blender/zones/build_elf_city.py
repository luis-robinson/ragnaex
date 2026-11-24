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
from dress import Dress

ZONE = "elf_city"
RING_R = 66.0             # cidade grande: dois anéis de casas, bairros e o exército dentro do muro
TREE_R = 6.0
AERIE = (-48.0, -82.0)    # ninho dos grifos, dentro do forte do Capitão Aerion
GROVE = (70.0, -58.0)
TRAINING = (90.0, 16.0)   # forte da Mestra Ilwen (o campo de treino agora fica no quartel, dentro do muro)
MOONWELL = (-98.0, 20.0)
ELF_TREES = [(0.24, 0.46, 0.36), (0.3, 0.52, 0.4), (0.36, 0.58, 0.44)]
GROVE_TREES = [(0.17, 0.3, 0.2), (0.21, 0.34, 0.22)]
WALL = (0.86, 0.86, 0.78)
ROOF = (0.3, 0.56, 0.5)

PLACES = [
    {"type": "cabin", "id": "cerco", "pos": (36.0, 80.0), "face": 200.0, "npc": "siege_scout", "roof": (0.5, 0.36, 0.26)},
    {"type": "cabin", "id": "desertor", "pos": (-72.0, 80.0), "face": 20.0, "npc": "elf_deserter", "roof": ROOF, "wall": WALL},
    {"type": "camp", "id": "patrulha", "pos": (70.0, 64.0), "face": 140.0, "mob": "elf_warrior", "count": 4, "cloth": (0.36, 0.6, 0.46), "respawn": 22.0},
    {"type": "shrine", "id": "altar_lua", "pos": (-24.0, -100.0), "npc": "moon_altar", "ground": (0.74, 0.76, 0.8)},
    {"type": "dungeon", "id": "coracao", "dungeon": "dg_coracao"},
    # fortes com capitães (chefes com escolta): portão virado para a cidade
    {"type": "fort", "id": "forte_matilha", "pos": (14.0, -90.0), "face": 99.0, "captain": "elf_captain_hunter", "guards": [("elf_archer", 3)]},
    {"type": "fort", "id": "forte_ninho", "pos": AERIE, "face": 60.0, "r": 14.0, "captain": "elf_captain_sky", "guards": [("elf_warrior", 3)],
     "ground": (0.56, 0.54, 0.48)},
    {"type": "fort", "id": "forte_seiva", "pos": TRAINING, "face": 190.0, "captain": "elf_captain_sap", "guards": [("elf_archer", 2), ("elf_warrior", 2)],
     "ground": (0.4, 0.5, 0.32)},
]


# Pontos de evento de estrada (P4 "Patrulha com Prisioneiro", GDD elf-band-living 3.3): (tipo, (x, z), monstro), pontos
# conferidos no jogo pelo pacote LIVING (beira das estradas arco_norte, arco_leste e arco_oeste). Viram data["events"]
# (-> MapDef.road_events); as regras ficam em MapsCatalog.ROAD_EVENTS["elf_city"]["prisoner"] (só `unless: el6_king`).
EVENT_POINTS = [
    ("prisoner", (45.0, -73.2), "elf_warrior"),
    ("prisoner", (84.3, -30.5), "elf_warrior"),
    ("prisoner", (-82.4, 50.9), "elf_warrior"),
]
# Faixa élfica viva (GDD elf-band-living 3.4): o cenário troca com o Rei. Dois lotes com `tag` (MapDef.conquest_vis):
# guerra (`unless: el6_king`) e trégua (`if: el6_king`), no mesmo ponto; nada aqui colide nem entra no JSON.
WAR_TAG, TRUCE_TAG = "elfa_guerra_det", "elfa_tregua_det"
GATE_DEG = [90.0, 0.0, 180.0, -125.0, -55.0, -90.0]   # S (cerco), L (treino), O (poço), NO (grifos), NE (trents), N (Coração)
ELF_GREEN, ELF_SILVER, MOURN_WHITE = (0.2, 0.5, 0.36), (0.84, 0.86, 0.88), (0.95, 0.95, 0.9)
PALE_WOOD = (0.8, 0.76, 0.64)
CAPTIVES = {"forte_matilha": (11.8, -82.8), "forte_ninho": (-44.5, -75.0), "forte_seiva": (83.0, 14.8)}     # = LIVING_NPCS elv_captive_*
# Cochos de seiva: (parada, para que lado da parada fica o cocho). Os coletores (elv_sap_a / elv_sap_b) param FORA dos
# portões leste e noroeste (decisão 2026-11-24: fora da praça, menos bonecos lá); o da Árvore-Mãe é só cenário, no lado
# sudeste, que a câmera vê (entre a lanterna da porta do Coração e a raiz sul).
SAP_STOPS = [((71.1, -0.5), (0.61, -0.79)), ((-37.8, -63.0), (0.95, -0.32)), ((4.8, 14.7), (-0.31, -0.95))]
# Vigília da Viúva Elandra: (centro, raio, onde ela fica). Sudeste da praça (o noroeste fica atrás do tronco na câmera).
VIGIL = ((6.5, 16.0), 2.6, (9.4, 16.3))
ENVOY_TENT = ((-11.5, 17.5), -48.0)           # pedido (-9.4, 15.6): caía na ponta de uma raiz da Árvore-Mãe; o emissário fica em (-7.5, 19.0)
YARD_DUMMIES = [((45.3, -17.9), 20.0), ((46.7, -20.3), -30.0)]     # diante da Recruta Nerys (41, -21.5), fora da rota do aprendiz
YARD_TARGET = ((49.2, -17.2), 60.0)
YARD_RACKS = [((51.4, -26.6), 75.0), ((51.6, -20.4), 105.0), ((37.0, -26.4), 100.0)]
YARD_CRATES = [((47.6, -22.3), 1.0, 20.0), ((48.8, -21.7), 0.9, -15.0), ((47.9, -23.6), 1.0, 40.0)]


class OneLot(Dress):
    """Lote de conquista num lote só: tudo vai para UMA malha por tipo (objetos, pano, cada brilho), não uma por célula
    de 36 m. As peças são poucas e espalhadas pela cidade inteira: por célula seriam ~25 malhas com sombra por estado."""

    def _bm(self, g, m, x, z):
        return Dress._bm(self, g, m, 0.0, 0.0)

    def _bm_cloth(self, m, x, z):
        return Dress._bm_cloth(self, m, 0.0, 0.0)


def polar(z, ang_deg, inset):
    a = math.radians(ang_deg)
    r = z.rim_r(a) - inset
    return (round(math.cos(a) * r, 1), round(math.sin(a) * r, 1))


def gate_posts():
    """Os dois mastros de cada portão (6 do anel, por fora do muro, e 3 dos fortes): [(ponto, giro do pano)], o pano
    sai para longe do vão."""
    out = []
    for a in GATE_DEG:
        r = math.radians(a)
        u, t = Vector((math.cos(r), math.sin(r))), Vector((-math.sin(r), math.cos(r)))
        for k in (-1, 1):
            out.append((tuple(u * (RING_R + 2.6) + t * 4.7 * k), zone_lib.along(t.x * k, t.y * k)))
    for p in PLACES:
        if p["type"] != "fort":
            continue
        c, d = Vector(p["pos"]), places.direction(p["face"])
        side = Vector((-d.y, d.x))
        for k in (-1, 1):
            out.append((tuple(c + d * (float(p.get("r", 13.0)) + 1.7) + side * 4.5 * k), zone_lib.along(side.x * k, side.y * k)))
    return out


def cage_spots():
    """Jaula de cada forte: ao lado do preso (2,8 m para o lado em que ele já está do eixo do portão), porta para ele."""
    out = []
    for p in PLACES:
        if p["id"] not in CAPTIVES:
            continue
        c, d = Vector(p["pos"]), places.direction(p["face"])
        side = Vector((-d.y, d.x))
        q = Vector(CAPTIVES[p["id"]])
        k = 1.0 if (q - c).dot(side) >= 0.0 else -1.0
        out.append((tuple(q + side * 2.8 * k), zone_lib.along(-side.x * k, -side.y * k)))
    return out


def cage(d, c, rot, opened):
    """Jaula élfica de varas claras (2 x 2,2 x 2 m): estrado, quatro esteios, travessas e grades. A frente (+x local) é a
    porta: fechada com grade e tranca, ou aberta para fora e a jaula vazia."""
    g = "jaula"
    wood = d.m("jaula_casca", (0.44, 0.34, 0.25))
    bar = d.m("jaula_vara", PALE_WOOD)
    a = math.radians(rot)
    L = lambda x, zz: (c[0] + x * math.cos(a) + zz * math.sin(a), c[1] - x * math.sin(a) + zz * math.cos(a))
    d.box(g, wood, c, (2.2, 0.16, 2.2), rot, 0.0)
    for sx in (-1, 1):
        for sz in (-1, 1):
            d.cyl(g, wood, L(sx * 1.0, sz * 1.0), 0.1, 0.08, 2.25, 0.1, 5)
    for y in (0.16, 2.2):
        for sz in (-1, 1):
            d.box(g, wood, L(0.0, sz * 1.0), (2.1, 0.1, 0.1), rot, y)
        for sx in (-1, 1):
            d.box(g, wood, L(sx * 1.0, 0.0), (0.1, 0.1, 2.1), rot, y)
    for i in range(5):                                                             # teto de ripas com vão: de cima ainda lê como jaula
        d.box(g, wood, L(0.0, -0.96 + i * 0.48), (2.3, 0.08, 0.2), rot, 2.3)
    for i in range(1, 6):
        k = -1.0 + i / 3.0
        for sz in (-1, 1):
            d.cyl(g, bar, L(k, sz * 1.0), 0.035, 0.035, 2.05, 0.2, 4)
        d.cyl(g, bar, L(-1.0, k), 0.035, 0.035, 2.05, 0.2, 4)
    if not opened:
        for i in range(1, 6):
            d.cyl(g, bar, L(1.0, -1.0 + i / 3.0), 0.035, 0.035, 2.05, 0.2, 4)
        d.box(g, wood, L(1.02, 0.0), (0.08, 0.12, 2.0), rot, 1.1)                 # tranca atravessada
        d.box(g, d.m("ferro", (0.6, 0.62, 0.66)), L(1.08, 0.55), (0.1, 0.24, 0.2), rot, 1.04)
        st = d.m("alvo_palha", (0.8, 0.68, 0.4))                                   # palha e a cuia do preso
        d.box(g, st, L(-0.3, 0.3), (1.2, 0.1, 1.0), rot + 12.0, 0.16)
        d.cyl(g, wood, L(0.5, -0.55), 0.14, 0.2, 0.14, 0.16, 6)
    else:
        hinge = L(1.0, -1.0)                                                       # a porta gira no esteio e fica escancarada
        da = rot + 115.0
        ra = math.radians(da)
        mid = (hinge[0] + math.cos(ra) * 1.0, hinge[1] - math.sin(ra) * 1.0)
        for y in (0.2, 2.1):
            d.box(g, wood, mid, (2.0, 0.08, 0.08), da, y)
        for i in range(1, 6):
            q = (hinge[0] + math.cos(ra) * i / 3.0, hinge[1] - math.sin(ra) * i / 3.0)
            d.cyl(g, bar, q, 0.035, 0.035, 1.9, 0.2, 4)
        d.box(g, wood, L(1.9, 0.7), (0.08, 0.12, 2.0), rot + 70.0, 0.0)           # a tranca largada no chão


def bow(d, c, rot, lean, g="arcos"):
    """Arco élfico sem corda, de pé e inclinado (dentro de um caixote)."""
    a = math.radians(rot)
    ux, uz = math.cos(a), -math.sin(a)
    pts = []
    for i in range(7):
        t = i / 6.0
        up = 0.25 + 1.7 * t
        out = lean * up + 0.3 * math.sin(math.pi * t)
        pts.append((c[0] + ux * out, up, c[1] + uz * out))
    d.tube(g, d.m("arco_claro", (0.86, 0.8, 0.6)), pts, 0.05, 0.04, 4)


def banner_war(d, c, rot):
    """Estandarte de guerra élfico: mastro claro, pano verde comprido e uma fita de prata do outro lado do mastro."""
    d.flag(c, ELF_GREEN, h=4.8, rot=rot, pole=PALE_WOOD, g="estandarte", tatter=False, w=1.25, drop=2.2)
    sm = d.m("pano_prata", ELF_SILVER)
    d.cloth("estandarte", sm, c, 0.85, 0.95, rot + 180.0, 3.75, 0.08, "swallow", d.m("pano_prata_barra", tuple(k * 0.82 for k in ELF_SILVER)))
    d.cyl("estandarte", d.m("mastro_ponta", ELF_SILVER), c, 0.1, 0.0, 0.38, 4.8, 4)


def banner_truce(d, c, rot):
    """O mesmo mastro, sem o estandarte: fita branca de luto a meio mastro e o pano verde dobrado ao pé."""
    d.cyl("estandarte", d.m("mastro_fl_80", PALE_WOOD), c, 0.09, 0.06, 4.8, 0.0, 5)
    wm = d.m("pano_luto", MOURN_WHITE)
    d.cloth("estandarte", wm, c, 0.5, 1.5, rot, 1.7, 0.08, "swallow", d.m("pano_luto_barra", tuple(k * 0.86 for k in MOURN_WHITE)))
    a = math.radians(rot)
    q = (c[0] + math.cos(a) * 0.75, c[1] - math.sin(a) * 0.75)
    gm = d.m("pano_dobrado", ELF_GREEN)
    d.box("estandarte", gm, q, (0.8, 0.14, 0.55), rot + 14.0, 0.0)
    d.box("estandarte", d.m("pano_dobrado_esc", tuple(k * 0.82 for k in ELF_GREEN)), q, (0.72, 0.12, 0.5), rot + 4.0, 0.14)
    d.box("estandarte", gm, q, (0.62, 0.1, 0.42), rot + 20.0, 0.26)
    d.box("estandarte", d.m("pano_prata_fita", ELF_SILVER), q, (0.12, 0.38, 0.6), rot + 14.0, 0.0)


def sap_station(d, stop, side):
    """Coleta de seiva: cocho de casca com a seiva acesa e baldes em volta, a 1,7 m da parada para o lado `side` (a
    parada do coletor fica livre)."""
    v = Vector(stop)
    u = -Vector(side).normalized()
    t = Vector((-u.y, u.x))
    c = v - u * 1.7
    rot = zone_lib.along(t.x, t.y)
    wood = d.m("cocho", (0.46, 0.36, 0.26))
    sap = d.m("glow_seiva", (0.78, 1.0, 0.6))
    d.box("seiva", wood, tuple(c), (2.2, 0.5, 0.8), rot, 0.12)
    for k in (-1, 1):
        d.box("seiva", wood, tuple(c + t * 0.8 * k), (0.2, 0.3, 0.9), rot, 0.0)
    d.box("seiva", sap, tuple(c), (1.96, 0.05, 0.56), rot, 0.6)
    for dt, du, full in ((1.7, 0.2, True), (-1.75, -0.1, True), (-2.3, 0.75, False), (1.2, 1.0, False)):
        q = tuple(c + t * dt + u * du)
        d.cyl("seiva", d.m("balde", (0.66, 0.54, 0.36)), q, 0.2, 0.26, 0.42, 0.0, 7)
        d.cyl("seiva", d.m("balde_aro", (0.5, 0.52, 0.56)), q, 0.27, 0.27, 0.06, 0.3, 7, cap=False)
        if full:
            d.cyl("seiva", sap, q, 0.22, 0.22, 0.03, 0.4, 7)
    d.tube("seiva", wood, [(c.x - u.x * 0.2, 1.5, c.y - u.y * 0.2), (c.x - u.x * 0.1, 1.0, c.y - u.y * 0.1), (c.x, 0.7, c.y)], 0.06, 0.04, 4)   # bica


def vigil(d, c, r, widow):
    """Vigília de luto: flores brancas e lanternas baixas em roda (peças soltas, nada pintado no chão), um apoio no
    meio com o manto do rei dobrado. Pula o que cairia dentro de uma raiz da Árvore-Mãe ou em cima da viúva."""
    leaf = d.m("vigilia_folha", (0.36, 0.56, 0.36))
    white = d.m("vigilia_flor", MOURN_WHITE)
    post = d.m("vigilia_haste", PALE_WOOD)
    light = d.m("glow_vela", (1.0, 0.95, 0.78))
    roots = [math.tau * i / 10 + 0.2 for i in range(10)]

    def in_root(q):
        for a in roots:
            u = Vector((math.cos(a), math.sin(a)))
            along, lat = q.dot(u), abs(q.x * u.y - q.y * u.x)
            if TREE_R * 0.8 < along < TREE_R * 3.1 and lat < 1.5:
                return True
        return False

    n = 14
    for i in range(n):
        a = math.tau * i / n
        q = Vector((c[0] + math.cos(a) * r, c[1] + math.sin(a) * r))
        if in_root(q) or (q - Vector(widow)).length < 1.0:
            continue
        if i % 2 == 0:                                     # lanterna baixa: pé, copo aceso, chapéu
            d.cyl("vigilia", post, tuple(q), 0.1, 0.06, 0.34, 0.0, 5)
            d.cyl("vigilia", light, tuple(q), 0.13, 0.16, 0.24, 0.34, 6)
            d.cyl("vigilia", post, tuple(q), 0.24, 0.0, 0.16, 0.58, 6)
        else:                                              # maço de flores brancas
            d.tuft("vigilia", leaf, tuple(q), 0.4, 0.42, 5)
            for k in range(5):
                b = a + math.tau * k / 5
                f = (q.x + math.cos(b) * 0.24, q.y + math.sin(b) * 0.24)
                d.cyl("vigilia", white, f, 0.0, 0.11, 0.1, 0.3 + 0.06 * (k % 2), 5)
    d.cyl("vigilia", post, c, 0.42, 0.34, 0.5, 0.0, 6)     # apoio de madeira clara
    d.box("vigilia", d.m("pano_dobrado", ELF_GREEN), c, (0.6, 0.12, 0.44), 30.0, 0.5)
    d.box("vigilia", d.m("pano_prata_fita", ELF_SILVER), c, (0.12, 0.14, 0.46), 30.0, 0.5)
    d.cyl("vigilia", light, (c[0] + 0.05, c[1] - 0.05), 0.1, 0.12, 0.2, 0.64, 6)


def living_dress(z):
    """Lotes da faixa élfica viva. Random próprio (Dress), nenhum colisor, nada em z.data: o JSON não muda."""
    posts = gate_posts()
    cages = cage_spots()
    # neutro: bonecos de treino e um alvo na beira do pátio do Quartel, para a recruta (só enfeite, não é TRAINING_DUMMIES)
    d = Dress(z, 31)
    for c, rot in YARD_DUMMIES:
        d.drill_post(c, rot, shield=ROOF, boss=ELF_SILVER)
    d.target(*YARD_TARGET)
    d.flush()
    # guerra (some com o Rei)
    w = OneLot(z, 32, tag=WAR_TAG, when={"unless": "el6_king"})
    for c, rot in posts:
        banner_war(w, c, rot)
    for c, rot in YARD_RACKS:
        w.weapon_rack(c, rot)
    for stop, side in SAP_STOPS:
        sap_station(w, stop, side)
    for c, rot in cages:
        cage(w, c, rot, False)
    w.flush()
    # trégua (aparece com o Rei)
    t = OneLot(z, 33, tag=TRUCE_TAG, when={"if": "el6_king"})
    for c, rot in posts:
        banner_truce(t, c, rot)
    vigil(t, *VIGIL)
    for c, s, rot in YARD_CRATES:                          # caixotes de arcos entregues
        t.crate(c, s, rot, g="arcos")
        for k in range(3):
            bow(t, (c[0] + (k - 1) * 0.24 * s, c[1] + (k % 2) * 0.2 - 0.1), rot + 60.0 * k, 0.16 + 0.05 * k)
    for c, rot in cages:
        cage(t, c, rot, True)
    t.tent_aurora(ENVOY_TENT[0], ENVOY_TENT[1], 1.0)       # barraca do emissário humano (lona clara, barra azul da Aurora)
    a = math.radians(ENVOY_TENT[1])
    t.crate((ENVOY_TENT[0][0] + math.cos(a) * 2.5, ENVOY_TENT[0][1] - math.sin(a) * 2.5), 0.8, ENVOY_TENT[1] + 15.0)
    t.flush()


def event_points(z):
    """data["events"] nos pontos pedidos; EVENT_CONFLICT se um deles quebrar as regras do _check_road_events."""
    data = z.data
    data["events"] = []
    for kind, pos, mob in EVENT_POINTS:
        q = Vector(pos)
        far = lambda c, r: (q - Vector(c[:2])).length >= r
        why = ""
        if q.length < 40.0:
            why = "hub"
        elif not all(far(p["pos"], 25.0) for p in data["portals"]) or not far(data["spawn"], 25.0):
            why = "portal/chegada"
        elif not all(far(v, 25.0) for v in data["npcs"].values()):
            why = "npc"
        elif not all(far(o["pos"], max(o["size"][0], o["size"][2]) * 0.5 + 0.6) for o in data["obstacles"] if o.get("solid", True) and o["kind"] != "cliff"):
            why = "obstaculo"
        elif not all(far(e["pos"], 30.0) for e in data["events"]):
            why = "outro ponto"
        if why:
            print("EVENT_CONFLICT %s em %s: %s" % (kind, pos, why))
        data["events"].append({"kind": kind, "pos": [round(q.x, 2), round(q.y, 2)], "mob": mob})


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
    gate_deg = GATE_DEG
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
    z.road("anel_externo", [H(42.0, 360.0 * k / 30) for k in range(31)], w=3.2, material="road", end_clearing=False)     # rondas
    face = lambda a: round(math.degrees(math.atan2(-math.cos(math.radians(a)), -math.sin(math.radians(a)))), 1)
    near_gate = lambda a, tol: any(abs((a - g + 180.0) % 360.0 - 180.0) < tol for g in gate_deg)
    in_arc = lambda a, lo, hi: lo <= ((a + 180.0) % 360.0 - 180.0) <= hi
    # ---------- bairros (cor de chão própria, lê de cima) ----------
    MARKET, BARRACKS, GARDEN = H(50.0, 45.0), H(50.0, -28.0), H(50.0, 135.0)
    z.patch("mercado", MARKET, 11.0, (0.74, 0.68, 0.52))
    z.patch("quartel", BARRACKS, 12.0, (0.6, 0.52, 0.4))
    z.patch("jardim", GARDEN, 12.0, (0.5, 0.7, 0.42), grass=True)
    for i in range(8):                                    # mercado: barracas em anel e lanternas no meio
        a = math.tau * i / 8
        z.ob("stall", MARKET[0] + math.cos(a) * 7.5, MARKET[1] + math.sin(a) * 7.5, (3.0, 2.4, 2.0), math.degrees(-a) + 90.0,
             color=[(0.55, 0.8, 0.6), (0.85, 0.75, 0.45), (0.6, 0.7, 0.9), (0.85, 0.6, 0.7)][i % 4])
    z.ob("elf_lantern", MARKET[0], MARKET[1], (1.2, 3.4, 0.5))
    for i in range(6):                                    # quartel: bonecos de treino, cercas e alojamentos
        a = math.tau * i / 6
        z.ob("pillar", BARRACKS[0] + math.cos(a) * 6.0, BARRACKS[1] + math.sin(a) * 6.0, (0.5, 1.9, 0.5), color=(0.7, 0.55, 0.36))
    for k in (-1, 1):
        z.ob("fence", BARRACKS[0] + 9.5 * k, BARRACKS[1], (5.0, 1.2, 0.4), 90.0)
    for a in (-40.0, -16.0):
        z.ob("elf_hut", *H(59.0, a), (4.4, 5.0, 4.4), face(a), color=WALL, roof=(0.42, 0.5, 0.36))
    z.lake("lago_jardim", GARDEN, 4.5, "water")           # jardins: lago pequeno com flores e lanternas
    for i in range(6):
        a = math.tau * (i + 0.5) / 6
        z.ob("flowers", GARDEN[0] + math.cos(a) * 7.5, GARDEN[1] + math.sin(a) * 7.5, (2.2, 0.5, 2.2), solid=False,
             color=[(0.95, 0.75, 0.85), (0.75, 0.6, 0.95), (0.95, 0.9, 0.55)][i % 3])
        if i % 2 == 0:
            z.ob("elf_lantern", GARDEN[0] + math.cos(a) * 9.5, GARDEN[1] + math.sin(a) * 9.5, (1.0, 3.0, 0.5))
    districts = [(Vector(MARKET), 12.5), (Vector(BARRACKS), 13.5), (Vector(GARDEN), 12.5)]
    # ---------- casas: dois anéis, casas-árvore e cabanas (prop_elf_treehouse / prop_elf_hut), de frente para a praça ----------
    for ring_r, n, big in ((34.0, 20, True), (53.0, 30, False)):
        for i in range(n):
            a = 360.0 * (i + 0.5) / n
            if near_gate(a, 8.0 if ring_r < 40 else 6.5):
                continue
            q = Vector(H(ring_r, a))
            if any((q - dc).length < dr + 3.0 for dc, dr in districts):
                continue
            if i % 3 == 0 or (big and i % 2 == 0):
                z.ob("elf_treehouse", q.x, q.y, (5.6, 13.0, 5.6), face(a), color=WALL, roof=ROOF)
            else:
                z.ob("elf_hut", q.x, q.y, (3.8, 4.6, 3.8), face(a), color=WALL, roof=[ROOF, (0.36, 0.6, 0.5), (0.42, 0.52, 0.36)][i % 3])
    for i in range(16):
        a = 360.0 * i / 16
        if not near_gate(a, 8.0):
            z.ob("elf_lantern", *H(23.6, a), (1.2, 3.4, 0.5), face(a) + 90.0)
    for i in range(12):
        a = 360.0 * (i + 0.5) / 12
        if not near_gate(a, 7.0):
            z.ob("elf_lantern", *H(45.2, a), (1.0, 3.0, 0.5), face(a) + 90.0)
    # mata dentro da cidade: árvores, arbustos e flores entre as casas (longe das ruas, das casas e dos bairros)
    rin = random.Random(77)
    houses = [(Vector(o["pos"]), max(o["size"][0], o["size"][2]) * 0.5 + 1.6) for o in z.data["obstacles"] if o["kind"].startswith("elf_") and o.get("solid", True)]
    paths = [poly for k, poly in z.road_polys.items() if k.startswith("av_") or k.startswith("anel")]
    placed = []
    for kind, n, size, cols, solid in (("tree", 26, (1.7, 4.6, 1.7), [(0.26, 0.5, 0.3), (0.32, 0.56, 0.34)], True),
                                       ("bush", 60, (1.6, 0.9, 1.6), [(0.3, 0.52, 0.32), (0.38, 0.6, 0.36)], False),
                                       ("flowers", 50, (1.5, 0.45, 1.5), [(0.85, 0.95, 1.0), (0.95, 0.85, 0.5), (0.75, 0.6, 0.95)], False)):
        k = 0
        for _ in range(n * 30):
            if k >= n:
                break
            a = rin.uniform(0, math.tau)
            r = rin.uniform(21.0, RING_R - 3.2)
            q = Vector((math.cos(a) * r, math.sin(a) * r))
            if any((q - hc).length < hr + (1.4 if solid else 0.6) for hc, hr in houses):
                continue
            if any((q - dc).length < dr for dc, dr in districts):
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
    z.data["hangouts"] = [list(arrive), [10.0, 80.0], [-8.0, 70.0], [30.0, 72.0], list(H(70.0, 90.0)), [-93.0, 5.0], [76.0, 34.0]]      # o do poço: largo ao norte dele, em chão seco

    # ---------- estradas (curvas; os portões ligam os POIs e há arcos entre eles) ----------
    gS, gE, gW, gNW, gNE, gN = (H(RING_R, a) for a in gate_deg)
    z.road("S", [gS, (8, 58), (-6, 76), (2, 90), arrive, portal], end_clearing=False)
    z.road("L", [gE, (72.0, 4.0), (73.0, 10.0)])                                     # forte da Seiva (portão a oeste)
    z.road("O", [gW, (-74, 0.5), (-82, 2.0), (MOONWELL[0] + 5, MOONWELL[1] - 12)])   # cruza o riacho de frente (ponte) e chega ao poço pelo norte
    z.road("NO", [gNW, (-40.0, -60.0), (-41.0, -64.0)])                              # forte do Ninho
    z.road("NE", [gNE, (42, -58), (56, -58), (GROVE[0] - 8, GROVE[1] + 2)])
    z.road("N", [gN, (6.0, -70.0), (10.0, -74.0)])                                   # forte da Matilha
    z.road("arco_norte", [(10.0, -74.0), (28, -78), (44, -74), (GROVE[0] - 8, GROVE[1] + 2)])
    z.road("arco_leste", [(GROVE[0] + 4, GROVE[1] + 10), (84, -32), (84, -10)])
    z.road("arco_sul", [(74, 36), (64, 56), (40, 70), (-6, 76)], end_clearing=False)
    # margem oeste do riacho (a ~10 m da água, nunca por cima dela), passa entre o riacho e a cabana do desertor e só então cruza, de frente
    z.road("arco_oeste", [(MOONWELL[0] + 8, MOONWELL[1] + 12), (-84, 48), (-75, 62), (-65, 78), (-61, 86), (-45, 81), (-28, 83), (-6, 76)], end_clearing=False)

    # ---------- água: riacho a oeste (pontes nas estradas) e o poço da lua ----------
    z.river([(-30, -128), (-56, -106), (-76, -70), (-81, -32), (-81, 0), (-77, 34), (-62, 68), (-46, 98), (-40, 128)], w=5.5)     # por fora do muro
    z.lake("poco_lua", MOONWELL, 10.0, "water_dark")
    z.bridges()

    # ---------- POIs ----------
    for i in range(5):                                                     # ninhos (anéis de galhos) dentro do forte do Aerion
        a = math.tau * i / 5 + 0.4
        p = (AERIE[0] + math.cos(a) * 6.0, AERIE[1] + math.sin(a) * 6.0)
        z.ob("log", p[0], p[1], (2.0, 0.5, 2.0), math.degrees(a), solid=False, color=(0.6, 0.5, 0.34))
    z.patch("bosque", GROVE, 18.0, (0.22, 0.32, 0.22), grass=True)        # chão escuro do bosque dos trents
    for i in range(6):                                                     # colunas brancas em volta do poço
        a = math.tau * (i + 0.5) / 6
        z.ob("pillar", MOONWELL[0] + math.cos(a) * 13.5, MOONWELL[1] + math.sin(a) * 13.5, (0.9, 3.6, 0.9), color=WALL)

    # ---------- relevo ----------
    z.hill("colina_se", (90, 80), 9, 2)
    z.hill("colina_n", (30, -104), 8, 2)
    for i, (c, r, lv) in enumerate([((-96, -26), 7, 2), ((96, -60), 6, 2), ((-30, 104), 6, 1), ((60, 100), 6, 1)]):
        z.terrace("afloramento_%d" % i, c, r, lv, top="cliff_grass")
    z.cliffs()

    z.avoid = [(MOONWELL, 13.0), ((0.0, 0.0), RING_R + 2.0)]
    places.build(z, PLACES)

    # ---------- vegetação ----------
    z.block((0, 0), RING_R + 9)
    z.block(AERIE, 17)
    z.block(TRAINING, 16)
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
    nature.woodland_floor(z.ob, fr, nrnd, [(GROVE, 20, 14), ((-20, -70), 22, 10), ((60, 70), 20, 10), ((0, 0), 104, 30)], avoid=obs)
    nature.clear_banks(obs, z.rivers, [(MOONWELL, 10.0)], z.river_w)
    nature.shore(z.ob, nrnd, z.rivers, [(MOONWELL, 10.0)], list(z.road_polys.values()), z.river_w)

    # ---------- monstros: o exército da cidade ----------
    # esquadrões: Sargento Élfico com 3 guerreiros de escolta (MonsterDef.escort) fazendo ronda pelas ruas
    outer = [list(H(42.0, a)) for a in range(0, 360, 30)]
    squads = [outer, outer[6:] + outer[:6], [list(H(29.0, a)) for a in range(15, 375, 30)],
              [list(BARRACKS), list(H(42.0, 15.0)), list(MARKET), list(H(42.0, 100.0)), list(GARDEN), list(H(42.0, 190.0)), list(H(42.0, -100.0))],
              [list(H(40.0, -90.0)), list(H(29.0, -45.0)), list(H(40.0, 0.0)), list(H(29.0, 45.0)), list(H(40.0, 90.0)), list(H(29.0, 135.0)), list(H(40.0, 180.0)), list(H(29.0, -135.0))]]
    for route in squads:
        z.spawner("elf_sergeant", round(route[0][0], 1), round(route[0][1], 1), 2, 1, 60.0, route=route)
    for a in (-150.0, -30.0, 30.0, 150.0):                                 # arqueiros nos postos de vigia, junto ao muro
        x, zz = H(RING_R - 7.0, a)
        z.spawner("elf_archer", round(x, 1), round(zz, 1), 3, 2, 22.0)
    for a in (90.0, 0.0):                                                  # guarda nos portões sul e leste
        x, zz = H(RING_R - 6.0, a)
        z.spawner("elf_warrior", round(x, 1), round(zz, 1), 3, 2, 22.0)
    z.spawner("elf_warden", 17.0, 10.0, 3, 2, 60.0)                       # guardam a porta do Coração, no tronco (sudeste)
    z.spawner("griffin", AERIE[0] - 4, AERIE[1] - 2, 6, 2, 26.0)          # grifos soltos no ninho (o capitão traz os dele)
    z.spawner("trent", GROVE[0], GROVE[1], 12, 4, 30.0)
    z.spawner("elf_archer", MOONWELL[0] + 8, MOONWELL[1] + 20, 6, 3, 22.0)      # margem oeste do riacho, ao sul do poço (antes caía na água)
    z.spawner("elf_lynx", -24.0, -76.0, 9, 4, 18.0)
    event_points(z)
    living_dress(z)
    return z.finish(export, poi=AERIE, ground=(0.4, 0.58, 0.42))
