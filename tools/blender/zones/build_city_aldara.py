"""Vale de Aldara (city_aldara): zona estilo Erenshor vista pela câmera alta do RagnaEx.
Vila murada circular no hub + Campina (POIs de caça) no mesmo vale, borda de penhascos, rio, lago, castelo na colina.

Rodar no Blender (MCP):
    import sys; sys.path.append(r"C:/Users/luisf/Desktop/projects/ragnaex/tools/blender")
    sys.path.append(r"C:/Users/luisf/Desktop/projects/ragnaex/tools/blender/zones")
    import build_city_aldara as z; z.build(export=True)

Saídas:
  assets/models/map_city_aldara.glb   visual (terreno da borda, estradas, água, muralha, castelo, pontes, morros)
  data/zones/city_aldara.json         dados da sim: colisão (OB), props (casas/árvores/pedras... viram prop_<kind>),
                                      spawners, posições de NPC, hangouts, portais, estradas/água (grama evita)
Coordenadas do JSON = jogo (x, z), -z = norte (topo da tela). Blender (x, y) = jogo (x, -z).
Só a cena "RagnaEx_city_aldara" é tocada (nada do arquivo aberto do usuário).
"""
import bpy
import bmesh
import json
import math
import types
import os
import random
from mathutils import Vector

import nature
import places
import town_dress
import zone_lib

ZONE = "city_aldara"
P = "Z_%s_" % ZONE
ROOT = zone_lib.ROOT          # RAGNAEX_ROOT (worktree) ou o projeto
SIZE = 300.0                  # vale ~20% maior (places.grow_aldara): era 260
TOWN_R = 42.0                 # raio da muralha (2026-11-21: era 30; a vila ganhou bairros, o vale lá fora não mudou)
OLD_TOWN_R = 30.0             # o raio antigo: o sorteio da vegetação e os pontos de evento continuam a ser feitos com ele
GATE_HALF = 4.0               # meia largura do portão (m)
GATE_ROADS = ("N", "E", "S", "W")      # cada portão fica onde a estrada de sempre cruza a muralha nova (as estradas não mudaram)
ROAD_W = 4.2
G = places.grow_aldara         # (x, z) do layout antigo -> vale crescido (a vila fica igual)
LAKE = (G((6.0, 80.0)), 16.0)          # lago maior; na margem sul, a garganta da Praia dos Caranguejos (field_crab_beach)
CASTLE = (G((47.0, -51.0)), 13.0)      # afastado 3 m: as três estradas param no pé da colina, não dentro

# POIs (centro, nome) — a 60–120 m do hub
POIS = {k: G(v) for k, v in {
    "lago": (6.0, 66.0),
    "bosque": (80.0, 12.0),
    "colinas": (-6.0, -84.0),
    "clareira": (-84.0, 24.0),
    "fazenda": (-58.0, 64.0),
}.items()}
POIS["praia"] = (LAKE[0][0], LAKE[0][1] + LAKE[1] + 7.0)      # margem sul do lago: areal na boca da garganta da Praia (os caranguejos e o Rei mudaram para field_crab_beach em 2026-11-21)
PORTALS = {
    "to_forest": {"pos": G((104.0, -34.0)), "target_map": "field_forest", "target_pos": (-106.5, 9.3), "label": "Floresta (Lv 10-20)"},
    "to_ruins": {"pos": G((-104.0, -32.0)), "target_map": "field_ruins", "target_pos": (99.5, -5.2), "label": "Ruínas (Lv 20-30)"},
    # garganta sul-sudoeste (rumo 206 graus), depois da fazenda e do marco: Mata dos Zumbidos (build_field_hollow)
    "to_field_hollow": {"pos": (-54.8, 112.4), "target_map": "field_hollow", "target_pos": (33.6, -75.5), "label": "Mata dos Zumbidos (Lv 4-8)"},
    # garganta sul (rumo 177 graus), atrás do areal da margem sul do lago: Praia dos Caranguejos (build_field_crab_beach)
    "to_field_crab_beach": {"pos": (6.9, 121.2), "target_map": "field_crab_beach", "target_pos": (-20.9, -77.9), "label": "Praia dos Caranguejos (Lv 3-8)"},
}
HOLLOW_ARRIVE = (-51.5, 105.6)     # onde chega quem volta da Mata (= build_field_hollow.ALDARA_ARRIVE)
BEACH_ARRIVE = (6.7, 113.2)        # onde chega quem volta da Praia (= build_field_crab_beach.ALDARA_ARRIVE)
# estradas (game x,z) — catmull-rom, nunca reta. O primeiro ponto das quatro primeiras é o portão ANTIGO (raio 30): a
# polilinha inteira continua a ser a que a vegetação, os lugares e os eventos enxergam (o JSON de fora da muralha sai igual
# ao de antes); a estrada de verdade começa no portão novo, que fica onde ela cruza o raio TOWN_R.
ROADS_BASE = [
    ("N", [(0, -30), (5, -44), (-6, -58), (-3, -72)]),
    ("E", [(30, 0), (46, -7), (60, 6), (74, 10), (88, -4), (98, -22), (104, -34)]),
    ("S", [(0, 30), (-6, 42), (6, 52), (5, 62)]),
    ("W", [(-30, 0), (-42, 7), (-54, 4), (-66, 14), (-80, 22), (-93, 6), (-100, -16), (-104, -32)]),
    ("SW", [(-80, 22), (-74, 42), (-62, 58)]),
    ("castelo", [(5, -44), (18, -52), (30, -50)]),
    ("lago_fazenda", [(5, 62), (-8, 62), (-18, 72), (-30, 74), (-48, 64)]),      # sai do fim da estrada S; cruza o rio de frente (>= 60 graus), junto da foz
    ("colinas_castelo", [(-3, -72), (10, -70), (22, -62), (30, -50)]),
    ("castelo_bosque", [(30, -50), (34, -36), (50, -32), (68, -24), (84, -10), (88, -4)]),
]
ROADS = [(n, [G(q) for q in pts]) for n, pts in ROADS_BASE]
# trilha da Mata: sai do fim da estrada da fazenda (lago_fazenda), cobre o começo da trilha do marco (que continua saindo para
# oeste), passa a leste do marco e entra na garganta (já em metros do vale crescido).
# LATE = o que entrou depois do sorteio da vegetação estar aprovado: a dispersão, os lugares (places) e os pontos de evento são
# calculados SEM estes nomes (o JSON sai igual ao de antes, fora o que é novo) e o passe de estradas do fim limpa o caminho.
ROADS.append(("mata", [G((-48.0, 64.0)), (-47.7, 77.1), (-44.4, 82.6), (-45.6, 90.0), (-49.0, 97.5), HOLLOW_ARRIVE, PORTALS["to_field_hollow"]["pos"]]))
# trilha da Praia: sai da trilha da eremita (a leste do lago), contorna a margem leste e cruza o areal até a garganta sul
ROADS.append(("praia", [(32.16, 79.32), (29.0, 86.0), (26.8, 93.0), (22.5, 100.5), (15.5, 108.5), BEACH_ARRIVE, PORTALS["to_field_crab_beach"]["pos"]]))
LATE_ROADS = ("mata", "praia")
LATE_PORTALS = ("to_field_hollow", "to_field_crab_beach")
LATE_SPOTS = [(HOLLOW_ARRIVE, 5.0), (PORTALS["to_field_hollow"]["pos"], 7.0), (BEACH_ARRIVE, 5.0), (PORTALS["to_field_crab_beach"]["pos"], 7.0)]      # (centro, raio) sem árvore/pedra/moita
RIVER = [G(q) for q in [(-70, -122), (-64, -86), (-57, -46), (-52, -8), (-48, 30), (-30, 60), (-8, 74)]]
RIVER_W = 7.0
PLACES = [
    {"type": "cabin", "id": "lenhador", "pos": G((-88.0, -56.0)), "face": 150.0, "npc": "woodcutter_nils", "roof": (0.5, 0.34, 0.24)},
    {"type": "cabin", "id": "eremita", "pos": G((52.0, 88.0)), "face": 150.0, "npc": "hermit_ines", "roof": (0.38, 0.5, 0.4)},
    {"type": "camp", "id": "covil", "pos": G((-24.0, -56.0)), "face": 20.0, "mob": "wolf", "count": 4, "cloth": (0.46, 0.38, 0.3)},
    {"type": "shrine", "id": "marco", "pos": G((-60.0, 84.0)), "npc": "stone_marker", "ground": (0.56, 0.56, 0.56)},
    {"type": "dungeon", "id": "gruta", "dungeon": "dg_gruta"},
    {"type": "dungeon", "id": "catacumbas", "dungeon": "dg_catacumbas"},
]
# os dois morros que ficavam a 36-43 m do centro (dentro da muralha nova) saíram do mapa; a vegetação ainda desvia do
# lugar deles (HILLS_GONE: o sorteio é o de antes)
HILLS_GONE = (G((28.0, -22.0)), G((-24.0, 34.0)))
HILLS = [(G(c), r, n) for c, r, n in [((-24.0, -86.0), 8.0, 2), ((14.0, -100.0), 7.0, 2), ((-50.0, -100.0), 9.0, 3),   # (centro, raio, patamares)
         # patamares baixos pela campina (relevo visto de cima; longe de estradas, rio e spawners)
         ((56.0, 44.0), 8.0, 2), ((-74.0, -34.0), 7.0, 2),
         ((74.0, -64.0), 8.0, 2), ((-32.0, 96.0), 7.0, 1), ((30.0, 40.0), 6.0, 1)]]
TOWER_RUIN = G((-30.0, -100.0))
# ---------------------------------------------------------------------------------------------------------------------
# A VILA (2026-11-21, "cidade de verdade"): praça da Balança do Trigo no meio, quatro avenidas curvas até os portões, a Rua da
# Ronda (anel) e um bairro por lado: Quartel e pátio de treino (N), Mercado (L), casas, Taverna e celeiro (S), Ofícios (O).
# Cada NPC de serviço atende do lado de FORA, na porta/balcão do prédio dele. Tudo em metros do jogo (x, z), -z = norte.
# rot = giro Y do jogo; a frente (porta) aponta para (sin rot, cos rot): 0 = sul (para a câmera), 90 = leste, -90 = oeste.
# ---------------------------------------------------------------------------------------------------------------------
PLAZA_R = 11.0
RING_R = 30.0                 # Rua da Ronda
AVENUES = {                   # da boca da praça para fora; o build acrescenta a chegada ao portão e o portão
    "N": [(0.0, -9.0), (1.6, -19.0), (1.2, -29.0)],
    "E": [(9.0, 0.0), (19.0, 1.2), (29.0, -0.6)],
    "S": [(0.0, 9.0), (-1.6, 19.0), (-1.2, 29.0)],
    "W": [(-9.0, 0.0), (-19.0, 1.6), (-29.0, 1.2)],
}
AVENUE_W = 4.6
RING_W = 3.4


def polar(deg, r):
    return (round(math.cos(math.radians(deg)) * r, 2), round(math.sin(math.radians(deg)) * r, 2))


def facing_center(p):
    return round(math.degrees(math.atan2(-p[0], -p[1])), 1)


C_WALL = (0.86, 0.8, 0.68)
C_STONE = (0.8, 0.79, 0.76)
# id -> pos, tamanho (largura, altura, fundo), rot (None = de frente para a praça), parede, telhado
BUILDINGS = {
    # --- praça / norte ---
    "elder": {"pos": (9.6, -18.8), "size": (6.2, 3.6, 5.6), "rot": -12.0, "wall": (0.88, 0.83, 0.72), "roof": (0.55, 0.45, 0.65)},
    "quartel": {"pos": polar(-101.0, 36.0), "size": (8.6, 4.2, 5.4), "rot": None, "wall": C_STONE, "roof": (0.36, 0.46, 0.66)},
    # --- mercado (leste) ---
    "tobias": {"pos": (18.5, -14.3), "size": (7.0, 3.6, 5.4), "rot": 0.0, "wall": (0.9, 0.84, 0.68), "roof": (0.88, 0.66, 0.3)},
    "relic": {"pos": polar(-33.0, 36.0), "size": (6.0, 4.0, 5.2), "rot": None, "wall": (0.92, 0.9, 0.84), "roof": (0.32, 0.58, 0.62)},
    "armazem": {"pos": polar(11.0, 35.6), "size": (7.4, 3.8, 5.2), "rot": None, "wall": (0.74, 0.62, 0.46), "roof": (0.56, 0.42, 0.3)},
    # --- sul: taverna e casas ---
    "tavern": {"pos": (10.2, 20.3), "size": (8.5, 4.2, 6.4), "rot": -65.0, "wall": (0.88, 0.8, 0.66), "roof": (0.7, 0.36, 0.3)},
    # --- ofícios (oeste) ---
    "smithy": {"pos": (-20.5, -11.8), "size": (6.6, 3.8, 5.6), "rot": 0.0, "wall": (0.74, 0.72, 0.7), "roof": (0.36, 0.38, 0.46)},
    "botica": {"pos": (-21.5, 9.5), "size": (6.4, 3.6, 5.4), "rot": 75.0, "wall": (0.86, 0.86, 0.74), "roof": (0.42, 0.62, 0.45)},
    "home": {"pos": polar(191.0, 35.6), "size": (6.2, 3.4, 5.0), "rot": None, "wall": C_WALL, "roof": (0.8, 0.55, 0.3)},
}
# casas de morar: (ângulo do lote, largura, telhado). Sul = bairro residencial (telhados de barro); o resto, poucas.
ROOFS_HOME = [(0.78, 0.45, 0.36), (0.8, 0.56, 0.36), (0.72, 0.5, 0.42), (0.82, 0.62, 0.42)]
HOMES = [(31.0, 5.8), (45.0, 6.4), (59.0, 5.8), (76.0, 5.6), (121.0, 5.8), (135.0, 6.4), (149.0, 5.8),      # SE, S, SO
         (213.0, 5.8), (236.0, 5.8)]                                                                          # NO
HOME_R = 35.8
YARD = (-9.8, -20.5, 5.5)         # pátio de treino (centro, raio): bonecos de MapsCatalog.TRAINING_DUMMIES, Mestra de Skills na beira
PEN = (-15.6, 16.4, 2.5)          # cercado das galinhas (MapsCatalog.AMBIENT_LIFE)
BARN = (-11.5, 20.5, 233.0)       # celeiro (centro, giro: a porta olha para a avenida sul)
FOUNDER = polar(-50.0, 35.8)      # Pátio do Fundador, a nordeste (entre a Casa do Ancião e a Relicária)
WELL_GARDEN = (20.0, 15.0)        # Jardim do Poço (canto sudeste do miolo)
# bancas do mercado, ao longo da avenida leste: (x, lado: -1 norte / +1 sul, mercadoria). A do Tobias é o balcão da loja dele.
STALLS = [(13.4, -1, 2), (24.6, -1, 3), (16.8, 1, 0), (22.4, 1, 4), (28.0, 1, 7)]
STALL_OFF = 5.3               # distância do balcão ao eixo da avenida
# Pontos de evento de estrada: (tipo, estrada, fração do comprimento, desvio lateral m, monstro). E1 "Lobos no Lavrador":
# colinas do norte e estrada da fazenda. Viram SPAWN_event_<tipo>_NN e data["events"]; MapsCatalog.ROAD_EVENTS dá as regras.
EVENT_POINTS = [
    ("wolves", "N", 0.72, 7.0, "wolf"),
    ("wolves", "colinas_castelo", 0.38, -7.0, "wolf"),
    ("wolves", "lago_fazenda", 0.5, 7.0, "wolf"),
    ("wolves", "SW", 0.55, -7.0, "wolf"),
]
# decoração que some se cair numa estrada/trilha (cerca vira portão, pedra sai do caminho)
ROAD_DECOR = ("rock", "fence", "crate", "log", "tree", "pine", "bush", "flowers", "stump", "reeds", "dead_tree")


# ---------------------------------------------------------------------------
# utilidades
# ---------------------------------------------------------------------------
def B(x, z, y=0.0):
    """jogo (x, z) -> Blender."""
    return Vector((x, -z, y))


def rim_r(a):
    """Raio da borda do vale no ângulo a (rad) — orgânico, nunca círculo perfeito (crescido como o resto do vale)."""
    r = 116.0 + 7.0 * math.sin(3 * a + 1.0) + 4.0 * math.sin(5 * a + 2.0) + 2.5 * math.sin(9 * a)
    return places.ALDARA_KEEP_R + (r - places.ALDARA_KEEP_R) * places.ALDARA_GROW


def catmull(pts, spacing=2.0):
    pts = [Vector((p[0], p[1])) for p in pts]
    ext = [pts[0] * 2 - pts[1]] + pts + [pts[-1] * 2 - pts[-2]]
    out = []
    for k in range(1, len(ext) - 2):
        p0, p1, p2, p3 = ext[k - 1], ext[k], ext[k + 1], ext[k + 2]
        n = max(2, int((p2 - p1).length / spacing))
        for s in range(n):
            t = s / n
            out.append(0.5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t * t + (-p0 + 3 * p1 - 3 * p2 + p3) * t ** 3))
    out.append(pts[-1])
    return out


def along(dx, dz):
    """Rotação Y do jogo (graus) que alinha o eixo x local com a direção (dx, dz) do jogo."""
    return math.degrees(math.atan2(-dz, dx))


def seg_dist(p, a, b):
    ab = b - a
    t = max(0.0, min(1.0, (p - a).dot(ab) / max(ab.length_squared, 1e-9)))
    return (a + ab * t - p).length


def poly_dist(p, poly):
    return min(seg_dist(p, poly[i], poly[i + 1]) for i in range(len(poly) - 1))


def mat(name, color, rough=0.9, emission=0.0):
    m = bpy.data.materials.get(name)
    if m is None:
        m = bpy.data.materials.new(name)
        m.use_nodes = True
    bsdf = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    bsdf.inputs["Base Color"].default_value = (*color, 1.0)
    bsdf.inputs["Roughness"].default_value = rough
    if emission > 0:
        bsdf.inputs["Emission Color"].default_value = (*color, 1.0)
        bsdf.inputs["Emission Strength"].default_value = emission
    m.diffuse_color = (*color, 1.0)
    return m


def MATS():
    return {
        "road": mat("road", (0.7, 0.6, 0.46)),          # o jogo troca por terra batida (ground shader)
        "street": mat("street", (0.72, 0.68, 0.6)),     # o jogo troca por paralelepípedo
        "water": mat("water", (0.38, 0.66, 0.88), 0.1),  # o jogo troca pelo shader de água
        "rock": mat("cliff_rock", (0.42, 0.39, 0.37)),
        "rock_d": mat("cliff_rock_d", (0.32, 0.3, 0.3)),
        "snow": mat("snow", (0.93, 0.95, 0.98)),
        "cliff_grass": mat("cliff_grass", (0.36, 0.56, 0.32)),
        "hill_grass": mat("hill_grass", (0.46, 0.66, 0.38)),
        "wall": mat("town_wall", (0.84, 0.78, 0.66)),
        "wall_d": mat("town_wall_d", (0.7, 0.64, 0.54)),
        "roof": mat("roof", (0.62, 0.32, 0.3)),
        "wood": mat("wood", (0.5, 0.35, 0.22)),
        "banner": mat("banner", (0.3, 0.42, 0.75)),
        "gold": mat("gold", (0.92, 0.75, 0.35), 0.4),
    }


def scene():
    if bpy.context.window is None:          # blender -b (headless): usa a cena ativa
        sc = bpy.context.scene
        sc.name = "RagnaEx_" + ZONE
        return sc
    sc = bpy.data.scenes.get("RagnaEx_" + ZONE) or bpy.data.scenes.new("RagnaEx_" + ZONE)
    bpy.context.window.scene = sc
    return sc


def collection(sc):
    c = bpy.data.collections.get("Z_" + ZONE)
    if c is None:
        c = bpy.data.collections.new("Z_" + ZONE)
    if c.name not in sc.collection.children:
        sc.collection.children.link(c)
    return c


def clear(sc, coll):
    for o in list(coll.objects) + [o for o in sc.objects if o.name.startswith(("OB_", "SPAWN_", "TRIG_", "CAM_"))]:
        bpy.data.objects.remove(o, do_unlink=True)
    for m in list(bpy.data.meshes):
        if m.users == 0:
            bpy.data.meshes.remove(m)


def obj(coll, name, bm, material, smooth=False):
    me = bpy.data.meshes.new(name + "_mesh")
    bm.to_mesh(me)
    bm.free()
    o = bpy.data.objects.new(name, me)
    coll.objects.link(o)
    if isinstance(material, list):
        for m in material:
            me.materials.append(m)
    else:
        me.materials.append(material)
    for p in me.polygons:
        p.use_smooth = smooth
    return o


def ribbon(coll, name, poly, w, y, material, shape=None):
    """Faixa (estrada/rio) ao longo de uma polilinha do jogo. `shape(i)` -> (desvio lateral em m, fator da largura) no
    ponto i: só a malha ondula, a polilinha (que vai para o JSON da sim) fica como está."""
    bm = bmesh.new()
    left, right = [], []
    for i, p in enumerate(poly):
        a = poly[max(0, i - 1)]
        b = poly[min(len(poly) - 1, i + 1)]
        t = (b - a).normalized()
        n = Vector((-t.y, t.x))
        off, wm = shape(i) if shape else (0.0, 1.0)
        p = p + n * off
        hw = w / 2 * wm
        left.append(bm.verts.new(B(p.x + n.x * hw, p.y + n.y * hw, y)))
        right.append(bm.verts.new(B(p.x - n.x * hw, p.y - n.y * hw, y)))
    for i in range(len(poly) - 1):
        bm.faces.new((left[i], right[i], right[i + 1], left[i + 1]))
    bm.normal_update()
    for f in bm.faces:
        if f.normal.z < 0:
            f.normal_flip()
    return obj(coll, name, bm, material)


def disc(coll, name, c, r, y, material, segs=48, jitter=0.0, seed=0):
    rnd = random.Random(seed)
    bm = bmesh.new()
    center = bm.verts.new(B(c[0], c[1], y))
    ring = []
    # borda orgânica e suave (soma de senos), com segmentos curtos: sem quinas visíveis de perto
    ph = [rnd.uniform(0, math.tau) for _ in range(3)]
    if jitter > 0:
        segs = max(segs, min(180, int(r * 4)))
    for i in range(segs):
        a = math.tau * i / segs
        rr = r * (1.0 + jitter * (0.6 * math.sin(3 * a + ph[0]) + 0.3 * math.sin(5 * a + ph[1]) + 0.18 * math.sin(9 * a + ph[2])))
        ring.append(bm.verts.new(B(c[0] + math.cos(a) * rr, c[1] + math.sin(a) * rr, y)))
    for i in range(segs):
        bm.faces.new((center, ring[i], ring[(i + 1) % segs]))
    bm.normal_update()
    for f in bm.faces:
        if f.normal.z < 0:
            f.normal_flip()
    return obj(coll, name, bm, material)


def box(coll, name, c, size, rot_deg, material, y0=0.0):
    """Caixa no jogo: centro (x,z), tamanho (largura x, altura, profundidade z), rotação em Y do jogo (graus)."""
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    a = math.radians(rot_deg)
    for v in bm.verts:
        x, yb, zb = v.co.x * size[0], v.co.y * size[2], (v.co.z + 0.5) * size[1]
        # rotação do jogo em Y = rotação do Blender em Z (mesmo sinal)
        rx = x * math.cos(a) - yb * math.sin(a)
        ry = x * math.sin(a) + yb * math.cos(a)
        v.co = Vector((c[0] + rx, -c[1] + ry, y0 + zb))
    return obj(coll, name, bm, material)


def cyl(coll, name, c, r_bot, r_top, h, material, y0=0.0, segs=12, jitter=0.0, seed=0):
    rnd = random.Random(seed)
    bm = bmesh.new()
    bot, top = [], []
    for i in range(segs):
        a = math.tau * i / segs
        j = 1.0 + rnd.uniform(-jitter, jitter)
        bot.append(bm.verts.new(B(c[0] + math.cos(a) * r_bot * j, c[1] + math.sin(a) * r_bot * j, y0)))
        top.append(bm.verts.new(B(c[0] + math.cos(a) * r_top * j, c[1] + math.sin(a) * r_top * j, y0 + h)))
    for i in range(segs):
        bm.faces.new((bot[i], bot[(i + 1) % segs], top[(i + 1) % segs], top[i]))
    if r_top > 0.01:
        bm.faces.new(top)
    bm.normal_update()
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    return obj(coll, name, bm, material)


def cone(coll, name, c, r, h, material, y0, segs=10):
    bm = bmesh.new()
    tip = bm.verts.new(B(c[0], c[1], y0 + h))
    ring = [bm.verts.new(B(c[0] + math.cos(math.tau * i / segs) * r, c[1] + math.sin(math.tau * i / segs) * r, y0)) for i in range(segs)]
    for i in range(segs):
        bm.faces.new((ring[i], ring[(i + 1) % segs], tip))
    bm.faces.new(list(reversed(ring)))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    return obj(coll, name, bm, material)


def preview(sc, data, M):
    """Proxies só para avaliar no Blender (chão, casas, árvores, pedras) — não exportados."""
    pc = bpy.data.collections.get("PREVIEW_" + ZONE)
    if pc is None:
        pc = bpy.data.collections.new("PREVIEW_" + ZONE)
        sc.collection.children.link(pc)
    for o in list(pc.objects):
        bpy.data.objects.remove(o, do_unlink=True)
    g = mat("pv_grass", (0.55, 0.74, 0.42))
    disc(pc, "PV_chao", (0, 0), 135, -0.01, g, 96)
    tm = {}
    for i, o in enumerate(data["obstacles"]):
        if not o["visible"]:
            continue
        x, z = o["pos"]
        sx, sy, sz = o["size"]
        col = tuple(o.get("color", (0.6, 0.6, 0.6)))
        key = (o["kind"], col)
        if key not in tm:
            tm[key] = mat("pv_%s_%d" % (o["kind"], len(tm)), col)
        if o["kind"] == "tree":
            cyl(pc, "PV_t%d" % i, (x, z), 0.25, 0.25, sy * 0.4, M["wood"], 0.0, 6)
            cone(pc, "PV_tc%d" % i, (x, z), sx * 1.3, sy * 1.1, tm[key], sy * 0.35, 8)
        elif o["kind"] == "house":
            box(pc, "PV_h%d" % i, (x, z), (sx, sy, sz), o["rot"], tm[key])
            rk = ("roof", tuple(o.get("roof", (0.7, 0.3, 0.3))))
            if rk not in tm:
                tm[rk] = mat("pv_roof_%d" % len(tm), rk[1])
            box(pc, "PV_hr%d" % i, (x, z), (sx + 0.6, sy * 0.6, sz + 0.6), o["rot"], tm[rk], sy)
        else:
            box(pc, "PV_o%d" % i, (x, z), (sx, sy, sz), o["rot"], tm[key])
    for s in data["spawners"]:
        disc(pc, "PV_sp", s["pos"], s["radius"], 0.03, mat("pv_spawn", (0.9, 0.3, 0.3)), 16)


# ---------------------------------------------------------------------------
# construção
# ---------------------------------------------------------------------------
def build(export=False):
    random.seed(7)
    sc = scene()
    coll = collection(sc)
    clear(sc, coll)
    M = MATS()
    data = {"zone": ZONE, "size": [SIZE, SIZE], "spawn": [0.0, 10.4],        # na boca da rua sul, fora da roseta da feira (dentro dela os bots se enroscavam nas bancas)
            "town": {"center": [0.0, 0.0], "radius": TOWN_R, "gates": []},
            "obstacles": [], "portals": [], "spawners": [], "npcs": {}, "hangouts": [], "roads": [], "water": []}
    obs = data["obstacles"]
    town_obs = []                 # tudo que é da vila: entra na frente de `obs` no fim (a vegetação não o enxerga, como antes)
    sink = [obs]

    def ob(kind, x, z, size, rot=0.0, visible=True, solid=True, color=None, roof=None, y=None, when=None, stage_solid=False):
        d = {"kind": kind, "pos": [round(x, 2), round(z, 2)], "size": [round(s, 2) for s in size], "rot": round(rot, 1),
             "visible": visible, "solid": solid}
        if when:                          # como Zone.ob (places.py passa `when` nos acampamentos de conquista)
            d["solid"] = bool(stage_solid)
            d.update(when)
        if y is not None:
            d["y"] = y
        if color:
            d["color"] = list(color)
        if roof:
            d["roof"] = list(roof)
        sink[0].append(d)

    # ---------- estradas e rio (polilinhas) ----------
    # legacy_polys = as polilinhas de antes da muralha crescer (saem do portão antigo, raio 30): é com elas que a vegetação,
    # os lugares e os pontos de evento são sorteados. road_polys = as estradas de verdade (malha, JSON, limpeza do caminho).
    legacy_polys = {name: catmull(pts, 1.6) for name, pts in ROADS}
    road_polys = {}

    gates = {}                # nome -> (ponto na muralha, direção para fora)
    for name, legacy in legacy_polys.items():
        if name not in GATE_ROADS:
            road_polys[name] = legacy
            continue
        i0 = next(i for i, q in enumerate(legacy) if q.length > TOWN_R)
        a_, b_ = legacy[i0 - 1], legacy[i0]
        g = a_.lerp(b_, (TOWN_R - a_.length) / (b_.length - a_.length))
        g = g.normalized() * TOWN_R
        gates[name] = (g, (b_ - a_).normalized())
        # os pontos que vão para o JSON são um sim, um não (poly[::2]): a parte de fora continua caindo nos mesmos
        road_polys[name] = [g] + legacy[i0 + (1 - i0 % 2):]
    late_roads = []          # entram no fim de data["roads"] (a ordem das antigas não muda)
    for name, poly in road_polys.items():
        end = poly[-1]
        to_portal = any((end - Vector(pp["pos"])).length <= 6 for pp in PORTALS.values())
        shape = None
        if to_portal:
            # os últimos ~40 m até o portal são quase colineares: de cima lia-se uma régua larga de ponta quadrada. Só a
            # MALHA ganha margem irregular (largura +-16%, desvio de até 0,5 m que zera nas duas pontas do trecho); a
            # polilinha da sim (data["roads"]: grama, minimapa, limpeza da estrada) não muda.
            k0 = max(0, len(poly) - 27)

            def shape(i, k0=k0, n=len(poly), ph=float(len(name))):
                if i < k0:
                    return 0.0, 1.0
                t = (i - k0) / (n - 1 - k0)
                env = math.sin(math.pi * t) ** 0.7
                return 0.5 * env * math.sin(t * 9.0 + ph), 1.0 + 0.16 * env * math.sin(t * 15.0 + ph * 1.7)
        ribbon(coll, P + "estrada_" + name, poly, ROAD_W, 0.012, M["road"], shape)
        (late_roads if name in LATE_ROADS else data["roads"]).append({"kind": "road", "w": ROAD_W, "pts": [[round(p.x, 2), round(p.y, 2)] for p in poly[::2] + [poly[-1]]]})
        # fim de estrada sem portal/vila: clareira de terra redonda (nunca termina em quina)
        if end.length > TOWN_R + 2 and not to_portal:
            disc(coll, P + "estrada_fim_" + name, (end.x, end.y), ROAD_W * 1.1, 0.011, M["road"], 20, 0.12, len(name))
        elif to_portal:
            # no portal a fita acabava num corte reto que sobrava atrás do anel: terreiro irregular sob o portal (só visual,
            # como o `largo_*_portal` do Zone.arrival) e um borrão menor de lado, para a boca não ficar redonda de compasso
            back = (end - poly[-4]).normalized()
            side = Vector((-back.y, back.x))
            disc(coll, P + "estrada_ponta_" + name, (end.x, end.y), ROAD_W * 0.95, 0.0114, M["road"], 20, 0.16, len(name) + 1)
            q = end - back * 2.6 + side * 1.5
            disc(coll, P + "estrada_ponta_" + name + "_b", (q.x, q.y), ROAD_W * 0.6, 0.0113, M["road"], 16, 0.2, len(name) + 4)
    river = catmull(RIVER, 2.0)
    ribbon(coll, P + "agua_rio", river, RIVER_W, 0.02, M["water"])
    ribbon(coll, P + "margem_rio", river, RIVER_W + 2.4, 0.008, M["road"])
    data["water"].append({"kind": "river", "w": RIVER_W, "pts": [[round(p.x, 2), round(p.y, 2)] for p in river[::2] + [river[-1]]]})
    (lx, lz), lr = LAKE
    disc(coll, P + "agua_lago", (lx, lz), lr, 0.025, M["water"], 40, 0.06, 3)
    disc(coll, P + "margem_lago", (lx, lz), lr + 2.2, 0.009, M["road"], 40, 0.06, 3)
    data["water"].append({"kind": "lake", "pos": [lx, lz], "r": lr})
    ob("water", lx, lz, (2 * (lr - 1.2), 1.0, 2 * (lr - 1.2)), visible=False)     # lago: sólido (rio é raso, dá pra atravessar)

    # pontes: um tabuleiro em cada cruzamento de verdade estrada x rio (o mesmo ponto do vão da sim), gravado em
    # data["bridges"] para o teste `_check_bridges` (zone_lib.build_bridges, o mesmo das zonas feitas com Zone)
    data["bridges"] = []
    zone_lib.build_bridges(ZONE, coll, P, road_polys, [river], [RIVER_W], M["wood"], data["bridges"])

    # ======================================================================================
    # VILA MURADA (hub): praça, avenidas, Rua da Ronda, muralha, prédios dos bairros
    # ======================================================================================
    sink[0] = town_obs

    def oval(name, c, rx, rz, rot, color, paved=False, y=0.010, jitter=0.07):
        """Mancha de bairro (material pave_*/patch_*: no jogo vira calçamento ou chão pintado nessa cor)."""
        m = mat(("pave_" if paved else "patch_") + name, color)
        rnd_ = random.Random(len(name) * 31 + int(abs(c[0]) * 7))
        ph = [rnd_.uniform(0, math.tau) for _ in range(3)]
        bm = bmesh.new()
        a_ = math.radians(rot)
        cv = bm.verts.new(B(c[0], c[1], y))
        ring = []
        segs = 44
        for i in range(segs):
            t = math.tau * i / segs
            k = 1.0 + jitter * (0.6 * math.sin(3 * t + ph[0]) + 0.3 * math.sin(5 * t + ph[1]) + 0.18 * math.sin(8 * t + ph[2]))
            ux, uz = math.cos(t) * rx * k, math.sin(t) * rz * k
            ring.append(bm.verts.new(B(c[0] + ux * math.cos(a_) + uz * math.sin(a_), c[1] - ux * math.sin(a_) + uz * math.cos(a_), y)))
        for i in range(segs):
            bm.faces.new((cv, ring[i], ring[(i + 1) % segs]))
        bm.normal_update()
        for f in bm.faces:
            if f.normal.z < 0:
                f.normal_flip()
        obj(coll, P + "chao_" + name, bm, m)

    # chão: relvado dentro da muralha (as ruas de pedra se leem por contraste), praça e ruas calçadas
    disc(coll, P + "chao_vila", (0, 0), TOWN_R - 0.6, 0.006, mat("patch_vila_relva", (0.5, 0.67, 0.4)), 72)
    disc(coll, P + "praca", (0, 0), PLAZA_R, 0.014, M["street"], 48)
    data["roads"].append({"kind": "street", "w": 0, "pts": [[0, 0]], "r": PLAZA_R})
    avenues = {}
    gate_angles = []
    for gname, (g, gdir) in gates.items():
        gate_angles.append(math.atan2(g.y, g.x))
        data["town"]["gates"].append([round(g.x, 2), round(g.y, 2)])
        ctrl = AVENUES[gname] + [tuple(g - gdir * 4.5 - g.normalized() * 0.4), tuple(g), tuple(g + gdir * 4.5)]
        poly = catmull(ctrl, 1.2)
        avenues[gname] = poly
        ribbon(coll, P + "rua_" + gname, poly, AVENUE_W, 0.016, M["street"])
        inside = [q for q in poly if q.length <= TOWN_R + 0.01]
        data["roads"].append({"kind": "street", "w": AVENUE_W, "pts": [[round(q.x, 2), round(q.y, 2)] for q in inside[::3] + [inside[-1]]]})
    ring_poly = [Vector((math.cos(math.tau * i / 96) * RING_R, math.sin(math.tau * i / 96) * RING_R)) for i in range(97)]
    # só a MALHA da ronda ondula e abre em largos (bocas das avenidas, frente do Quartel, da Relicária e do Armazém): de cima
    # um anel de compasso lia-se como pista; a polilinha do JSON continua o círculo
    wide = gate_angles + [math.atan2(BUILDINGS[k]["pos"][1], BUILDINGS[k]["pos"][0]) for k in ("quartel", "relic", "armazem", "home")]

    def ring_shape(i):
        a = math.tau * i / 96
        bump = max(math.exp(-((((a - w + math.pi) % math.tau) - math.pi) / 0.16) ** 2) for w in wide)
        return 0.35 * math.sin(3 * a + 1.0) + 0.2 * math.sin(7 * a), 1.0 + 0.45 * bump + 0.08 * math.sin(5 * a + 2.0)
    ribbon(coll, P + "rua_anel", ring_poly, RING_W, 0.016, M["street"], ring_shape)
    data["roads"].append({"kind": "street", "w": RING_W, "pts": [[round(q.x, 2), round(q.y, 2)] for q in ring_poly[::3]]})

    def near_gate(a):
        return min(abs((a - g + math.pi) % math.tau - math.pi) for g in gate_angles) * TOWN_R < GATE_HALF + 0.5

    # muralha: segmentos + ameias, torres, portões
    nseg = 96
    for i in range(nseg):
        a0 = math.tau * i / nseg
        a1 = math.tau * (i + 1) / nseg
        am = (a0 + a1) / 2
        if near_gate(am):
            continue
        c = (math.cos(am) * TOWN_R, math.sin(am) * TOWN_R)
        seg_len = TOWN_R * (a1 - a0) + 0.15
        rot = along(-math.sin(am), math.cos(am))     # tangente
        box(coll, P + "muro_%02d" % i, c, (seg_len, 3.6, 1.5), rot, M["wall"], 0.0)
        if i % 2 == 0:
            box(coll, P + "ameia_%02d" % i, (c[0] * 1.012, c[1] * 1.012), (seg_len * 0.55, 0.7, 0.6), rot, M["wall_d"], 3.6)
        ob("wall", c[0], c[1], (seg_len, 3.6, 1.6), rot, visible=False)
    for k in range(8):
        a = math.tau * (k + 0.5) / 8
        c = (math.cos(a) * TOWN_R, math.sin(a) * TOWN_R)
        cyl(coll, P + "torre_%d" % k, c, 2.6, 2.4, 6.5, M["wall"], 0.0, 12)
        cyl(coll, P + "torre_borda_%d" % k, c, 2.9, 2.9, 0.6, M["wall_d"], 6.5, 12)
        cone(coll, P + "torre_teto_%d" % k, c, 3.1, 3.2, M["roof"], 7.1, 12)
        ob("pillar", c[0], c[1], (5.2, 6.5, 5.2), visible=False)
    for gname, (g, gdir) in gates.items():
        gx, gz = g.x, g.y
        ga = math.atan2(gz, gx)
        side = Vector((-math.sin(ga), math.cos(ga)))
        for s in (-1, 1):
            c = (gx + side.x * (GATE_HALF + 1.4) * s, gz + side.y * (GATE_HALF + 1.4) * s)
            cyl(coll, P + "portao_torre_%s_%d" % (gname, s), c, 2.0, 1.8, 7.5, M["wall"], 0.0, 10)
            cone(coll, P + "portao_teto_%s_%d" % (gname, s), c, 2.4, 2.6, M["roof"], 7.5, 10)
            ob("pillar", c[0], c[1], (4.0, 7.5, 4.0), visible=False)
        rot = along(side.x, side.y)
        box(coll, P + "portao_arco_" + gname, (gx, gz), (2 * GATE_HALF + 2.0, 1.1, 1.8), rot, M["wall_d"], 5.2)
        box(coll, P + "estandarte_" + gname, (gx * 1.03, gz * 1.03), (1.4, 2.2, 0.08), rot, M["banner"], 3.0)

    # prédios dos bairros (cada um com parede e telhado próprios: o bairro se lê de cima pela cor) e casas de morar
    town = {"buildings": {}, "homes": [], "avenues": avenues}
    for bid, b in BUILDINGS.items():
        rot = facing_center(b["pos"]) if b["rot"] is None else b["rot"]
        ob("house", b["pos"][0], b["pos"][1], b["size"], rot, color=b["wall"], roof=b["roof"])
        town["buildings"][bid] = {"pos": b["pos"], "size": b["size"], "rot": rot}
    for k, (deg, w) in enumerate(HOMES):
        hp = polar(deg, HOME_R)
        rot = facing_center(hp)
        ob("house", hp[0], hp[1], (w, 3.2 + (k % 3) * 0.3, 5.0), rot, color=C_WALL, roof=ROOFS_HOME[k % len(ROOFS_HOME)])
        town["homes"].append((hp, rot, w))

    def spot(bid, right, out):
        """Ponto diante do prédio `bid`: `right` m para a direita de quem olha da porta para fora, `out` m da parede da frente."""
        b = town["buildings"][bid]
        a_ = math.radians(b["rot"])
        d_ = b["size"][2] * 0.5 + out
        return (round(b["pos"][0] + math.cos(a_) * right + math.sin(a_) * d_, 2), round(b["pos"][1] - math.sin(a_) * right + math.cos(a_) * d_, 2))
    town["spot"] = spot

    # chão dos bairros (acima do relvado 6 mm, abaixo da praça 14 mm e das ruas 16 mm; os lotes do town_dress ficam em 17+)
    oval("mercado", (20.6, 0.2), 11.6, 8.8, 0.0, (0.84, 0.75, 0.52))
    oval("mercado_loja", (19.0, -10.2), 6.2, 3.4, 0.0, (0.84, 0.75, 0.52), y=0.0104)
    oval("forja", (-18.2, -8.6), 8.4, 6.4, 0.0, (0.5, 0.49, 0.5), paved=True)
    oval("botica", (-17.6, 8.6), 4.6, 4.4, 0.0, (0.72, 0.76, 0.64), paved=True)
    oval("treino", YARD[:2], YARD[2] + 0.4, YARD[2] + 0.4, 0.0, (0.72, 0.6, 0.44), jitter=0.04)
    oval("quartel", spot("quartel", 0.0, 2.2), 6.0, 2.6, town["buildings"]["quartel"]["rot"], (0.66, 0.66, 0.7), paved=True)
    oval("taverna", spot("tavern", 0.0, 2.6), 5.0, 3.0, town["buildings"]["tavern"]["rot"], (0.76, 0.64, 0.46))
    oval("anciao", spot("elder", 0.0, 1.6), 4.4, 2.2, town["buildings"]["elder"]["rot"], (0.8, 0.77, 0.7), paved=True)
    oval("fundador", FOUNDER, 4.4, 4.0, 0.0, (0.82, 0.79, 0.72), paved=True, jitter=0.04)
    oval("reliquia", spot("relic", 0.0, 1.8), 4.2, 2.2, town["buildings"]["relic"]["rot"], (0.78, 0.76, 0.84), paved=True)
    oval("armazem", spot("armazem", 0.0, 1.8), 4.8, 2.2, town["buildings"]["armazem"]["rot"], (0.74, 0.66, 0.5))

    # praça da Balança do Trigo, mercado, forja, botica, quartel, taverna, celeiro, jardins: lotes do town_dress (cor no vértice)
    lay = {"yard": YARD, "pen": PEN, "barn": BARN, "founder": FOUNDER, "well": WELL_GARDEN, "stalls": STALLS,
           "stall_off": STALL_OFF, "plaza_r": PLAZA_R, "ring_r": RING_R, "ring_w": RING_W, "avenue_w": AVENUE_W, "town_r": TOWN_R}
    lay.update(town)
    lay["gates"] = {k: (tuple(g), tuple(gd_)) for k, (g, gd_) in gates.items()}
    centerpiece = town_dress.aldara(town_dress.shim(ZONE, P, coll, data, ob, rim_r, road_polys, [river], RIVER_W), lay)
    data["town"]["centerpiece"] = centerpiece
    data["fx"] = [{"kind": "smoke_low", "pos": centerpiece["chimney"]}]      # fumaça da chaminé da forja (SiegeFx: só visual)

    # lampiões: nos dois lados das avenidas e pela Rua da Ronda, fora de portas, balcões e postos
    keep_clear = [Vector(v[:2]) for v in centerpiece["posts"].values()] + [Vector(q) for q in centerpiece["clear"]]

    def lamp_ok(p):
        if any((p - q).length < 2.2 for q in keep_clear):
            return False
        for o in town_obs:
            if o["solid"] and (p - Vector(o["pos"])).length < max(o["size"][0], o["size"][2]) * 0.5 + 0.9:
                return False
        return True
    for gname, poly in avenues.items():
        n_ = len(poly)
        for f, sg in ((0.16, 1), (0.34, -1), (0.52, 1), (0.7, -1), (0.84, 1)):
            i = int(f * (n_ - 1))
            t = (poly[i + 1] - poly[i - 1]).normalized()
            lp = poly[i] + Vector((-t.y, t.x)) * sg * (AVENUE_W * 0.5 + 0.7)
            if lp.length < TOWN_R - 3 and abs(lp.length - RING_R) > RING_W * 0.5 + 1.2 and lamp_ok(lp):
                ob("lamp", lp.x, lp.y, (0.4, 3.0, 0.4))
                keep_clear.append(lp)
    for k in range(16):
        a = math.radians(11.25 + 22.5 * k)
        lp = Vector((math.cos(a), math.sin(a))) * (RING_R - RING_W * 0.5 - 0.6)
        if lamp_ok(lp):
            ob("lamp", lp.x, lp.y, (0.4, 3.0, 0.4))
            keep_clear.append(lp)
    sink[0] = obs

    # conferência da vila: posto, porta, ponto de bot ou banca encostado num colisor aparece no log como TOWN_CONFLICT
    ROUND = ("tree", "rock", "pillar", "well", "fountain", "lamp", "statue", "pine", "dead_tree", "stump", "hill")

    def clearance(p):
        best = 1e9
        for o in town_obs:
            if not o["solid"]:
                continue
            v = p - Vector(o["pos"])
            sx, sz = o["size"][0], o["size"][2]
            if o["kind"] in ROUND:
                dd = v.length - max(sx, sz) * 0.5
            else:
                a_ = math.radians(o["rot"])
                lx = v.x * math.cos(a_) - v.y * math.sin(a_)
                lz = v.x * math.sin(a_) + v.y * math.cos(a_)
                qx, qz = abs(lx) - sx * 0.5, abs(lz) - sz * 0.5
                dd = math.hypot(max(qx, 0.0), max(qz, 0.0)) if (qx > 0 or qz > 0) else max(qx, qz)
            best = min(best, dd)
        return best
    probes = [("posto " + k, v[:2], 0.5) for k, v in centerpiece["posts"].items()]
    probes += [("livre %d" % i, q, 0.55) for i, q in enumerate(centerpiece["clear"])]
    probes += [("bot %d" % i, q, 0.7) for i, q in enumerate(centerpiece["hangouts"])]
    probes += [("fregues %d" % i, q, 0.5) for i, q in enumerate(centerpiece["front_posts"])]
    for label, q, need in probes:
        c_ = clearance(Vector(q))
        if c_ < need:
            print("TOWN_CONFLICT %s (%.2f, %.2f): folga %.2f m (pede %.2f)" % (label, q[0], q[1], c_, need))

    # ---------- castelo na colina (landmark NE) ----------
    (cx, cz), cr = CASTLE
    for lvl, (r, h) in enumerate(((cr, 2.2), (cr * 0.78, 2.0), (cr * 0.56, 1.8))):
        y0 = sum(hh for _, hh in ((cr, 2.2), (cr * 0.78, 2.0), (cr * 0.56, 1.8))[:lvl])
        cyl(coll, P + "castelo_patamar_%d" % lvl, (cx, cz), r * 1.04, r, h, M["rock"], y0, 14, 0.06, lvl)
        disc(coll, P + "castelo_grama_%d" % lvl, (cx, cz), r * 0.98, y0 + h + 0.01, M["hill_grass"], 14, 0.06, lvl)
    top = 6.0
    box(coll, P + "castelo_torreao", (cx, cz), (6.0, 9.0, 6.0), 15, M["wall"], top)
    box(coll, P + "castelo_torreao_topo", (cx, cz), (6.8, 0.8, 6.8), 15, M["wall_d"], top + 9.0)
    for i in range(4):
        a = math.radians(15 + 45 + 90 * i)
        c = (cx + math.cos(a) * 5.2, cz + math.sin(a) * 5.2)
        cyl(coll, P + "castelo_torre_%d" % i, c, 1.5, 1.4, 11.0, M["wall"], top, 10)
        cone(coll, P + "castelo_teto_%d" % i, c, 1.9, 3.4, M["roof"], top + 11.0, 10)
    box(coll, P + "castelo_bandeira", (cx, cz), (0.08, 1.4, 2.0), 15, M["banner"], top + 10.5)
    ob("hill", cx, cz, (2 * cr, 6.0, 2 * cr), visible=False)

    # ---------- morros em patamares + torre em ruínas (colinas dos lobos) ----------
    for i, ((hx, hz), hr, lv) in enumerate(HILLS):
        y0 = 0.0
        for l in range(lv):
            r = hr * (1.0 - 0.28 * l)
            cyl(coll, P + "morro_%d_%d" % (i, l), (hx, hz), r * 1.06, r, 1.8, M["rock"], y0, 11, 0.12, i * 10 + l)
            disc(coll, P + "morro_grama_%d_%d" % (i, l), (hx, hz), r * 0.97, y0 + 1.81, M["hill_grass"], 11, 0.12, i * 10 + l)
            y0 += 1.8
        ob("hill", hx, hz, (2 * hr, y0, 2 * hr), visible=False)
    tx, tz = TOWER_RUIN
    cyl(coll, P + "torre_ruina", (tx, tz), 3.0, 2.7, 9.0, M["wall_d"], 0.0, 12)
    for i in range(6):
        a = math.tau * i / 6
        box(coll, P + "torre_ruina_ameia_%d" % i, (tx + math.cos(a) * 2.5, tz + math.sin(a) * 2.5), (1.0, 1.2 + (i % 3) * 0.8, 0.8), math.degrees(a), M["wall_d"], 9.0)
    ob("pillar", tx, tz, (6.0, 9.0, 6.0), visible=False)

    # ---------- borda do vale: anel de penhascos facetados (gargantas nos portais) ----------
    portal_angles = [math.atan2(p["pos"][1], p["pos"][0]) for pid, p in PORTALS.items() if pid not in LATE_PORTALS]
    late_angles = [math.atan2(PORTALS[pid]["pos"][1], PORTALS[pid]["pos"][0]) for pid in LATE_PORTALS]

    def in_gorge(a, width=0.07):
        return any(abs((a - pa + math.pi) % math.tau - math.pi) < width for pa in portal_angles + late_angles)

    steps = 180
    nature.mountain_ring(coll, P + "penhascos", rim_r, portal_angles, [M["rock"], M["rock_d"], M["cliff_grass"], M["snow"]],
                         ob, seed=5, boulder_col=(0.48, 0.45, 0.43), late_gorges=late_angles)
    # colisão da borda: corrente de caixas logo fora do andável (inclusive atrás dos portais)
    for i in range(0, steps, 2):
        a = math.tau * (i + 1) / steps
        r0 = rim_r(a) + 3.5
        seg = r0 * math.tau / steps * 2 * 1.25
        rot = along(-math.sin(a), math.cos(a))
        ob("cliff", math.cos(a) * r0, math.sin(a) * r0, (seg, 6.0, 7.0), rot, visible=False)

    # ---------- portais ----------
    def add_portal(pid):
        p = PORTALS[pid]
        data["portals"].append({"id": pid, "pos": list(p["pos"]), "radius": 2.0, "target_map": p["target_map"],
                                "target_pos": list(p["target_pos"]), "label": p["label"]})
    for pid in PORTALS:
        if pid not in LATE_PORTALS:
            add_portal(pid)

    # ---------- vegetação e pedras (props do jogo) ----------
    # lugares (places.py) e chegadas das outras zonas reservam o chão antes da vegetação
    spots = [(Vector(G((-98.3, -30.2))), 4.0), (Vector(G((98.3, -32.1))), 4.0)]
    fxz = POIS["fazenda"]
    avoid = [(LAKE[0], LAKE[1] + 3.0), (fxz, 18.5), (CASTLE[0], CASTLE[1] + 2.0)]       # fazenda inteira, com o moinho (15 m) + [(c, r + 1.5) for c, r, _ in HILLS]
    # trail_ok: a trilha do marco sai do fim da estrada lago_fazenda (já dentro do círculo da fazenda) e chega 5 cm dentro da
    # margem; contorna cercas, feno e moinho sem tocar em nada sólido (conferido em production/qa/evidence/trails-all)
    early_polys = {k: v for k, v in legacy_polys.items() if k not in LATE_ROADS}
    places.build(types.SimpleNamespace(data=data, ob=ob, coll=coll, P=P, road_polys=early_polys, rivers=[river], river_w=RIVER_W,
                                       avoid=avoid, block=lambda c, r: spots.append((Vector(c), r)), trail_ok={"marco"}), PLACES)
    road_polys.update({k: v for k, v in early_polys.items() if k not in road_polys})      # as trilhas dos lugares
    veg_polys = {k: legacy_polys.get(k, v) for k, v in road_polys.items()}      # o que a vegetação enxerga (ordem igual)
    for pid in LATE_PORTALS:
        add_portal(pid)
    blocked_polys = [v for k, v in veg_polys.items() if k not in LATE_ROADS] + [river]

    def free(x, z, margin):
        p = Vector((x, z))
        if p.length < OLD_TOWN_R + 6 or p.length > rim_r(math.atan2(z, x)) - 3:
            return False
        if any((p - Vector(h)).length < 9.0 for h in HILLS_GONE):
            return False
        if (p - Vector(LAKE[0])).length < LAKE[1] + 3 or (p - Vector(CASTLE[0])).length < CASTLE[1] + 2:
            return False
        for (hx, hz), hr, _ in HILLS:
            if (p - Vector((hx, hz))).length < hr + 2:
                return False
        if (p - Vector(TOWER_RUIN)).length < 5 or any((p - c).length < r for c, r in spots):
            return False
        for pid, pp in PORTALS.items():
            if pid not in LATE_PORTALS and (p - Vector(pp["pos"])).length < 7:
                return False
        return all(poly_dist(p, poly) > margin for poly in blocked_polys)

    rnd = random.Random(11)
    trees = 0
    # bosque dos javalis (leste) e floresta do noroeste: densos; resto: esparso; cinturão junto à borda
    zones = [(G(c), r * 1.2, int(n * 1.4)) for c, r, n in [((80, 12), 26, 70), ((-62, -64), 30, 60), ((40, 70), 18, 18), ((-90, 60), 16, 16)]]
    for (zx, zz), zr, n in zones:
        for _ in range(n * 4):
            if trees > 600:
                break
            a = rnd.uniform(0, math.tau)
            r = zr * math.sqrt(rnd.random())
            x, z = zx + math.cos(a) * r, zz + math.sin(a) * r
            if free(x, z, 4.5) and all((Vector((x, z)) - Vector(o["pos"])).length > 3.2 for o in obs[-40:] if o["kind"] == "tree"):
                s = rnd.uniform(0.9, 1.5)
                ob("tree", x, z, (1.6 * s, 3.5 * s, 1.6 * s), color=(0.30, 0.52, 0.34) if rnd.random() < 0.45 else (0.40, 0.66, 0.38))
                trees += 1
    for i in range(170):     # cinturão de árvores junto aos penhascos
        a = math.tau * i / 170 + rnd.uniform(-0.01, 0.01)
        r = rim_r(a) - rnd.uniform(4, 10)
        x, z = math.cos(a) * r, math.sin(a) * r
        if free(x, z, 5.0):
            s = rnd.uniform(1.1, 1.7)
            ob("tree", x, z, (1.6 * s, 3.5 * s, 1.6 * s), color=(0.30, 0.52, 0.34))
    for _ in range(72):      # árvores soltas pelo campo
        x, z = rnd.uniform(-126, 126), rnd.uniform(-126, 126)
        if free(x, z, 5.0):
            s = rnd.uniform(0.8, 1.2)
            ob("tree", x, z, (1.6 * s, 3.5 * s, 1.6 * s), color=(0.40, 0.66, 0.38))
    for _ in range(65):      # pedras (mais nas colinas)
        if rnd.random() < 0.5:
            x, z = POIS["colinas"][0] + rnd.uniform(-36, 36), POIS["colinas"][1] + rnd.uniform(-24, 24)
        else:
            x, z = rnd.uniform(-120, 120), rnd.uniform(-120, 120)
        if free(x, z, 3.5):
            s = rnd.uniform(0.7, 1.5)
            ob("rock", x, z, (1.4 * s, 0.9 * s, 1.2 * s), color=(0.62, 0.6, 0.58))
    # clareira do rei javali: anel de pedras
    ccx, ccz = POIS["clareira"]
    for a in range(0, 360, 36):       # anel de pedras; o passe de estradas no fim tira as que caem no caminho
        ob("rock", ccx + math.cos(math.radians(a)) * 12, ccz + math.sin(math.radians(a)) * 12, (1.8, 1.3, 1.6), color=(0.62, 0.6, 0.58))
    # fazenda abandonada: cercas e caixas
    fx, fz = POIS["fazenda"]
    for i in range(-3, 4):
        ob("fence", fx + i * 2.4, fz - 9, (2.4, 1.0, 0.3))
        ob("fence", fx + i * 2.4, fz + 9, (2.4, 1.0, 0.3))
    for i in range(-3, 3):
        ob("fence", fx - 9, fz + i * 2.4 + 1.2, (0.3, 1.0, 2.4))
    ob("tent", fx + 2, fz + 1, (3.2, 2.2, 3.2), 30, color=(0.6, 0.45, 0.3))
    ob("crate", fx - 4, fz + 3, (1.0, 1.0, 1.0))
    ob("crate", fx - 2.8, fz + 4.5, (1.0, 1.0, 1.0))
    # acampamento do guarda da estrada (sul)
    gtx, gtz = G((-9.0, 50.0))
    ob("tent", gtx, gtz, (3.0, 2.0, 3.0), 200, color=(0.45, 0.5, 0.7))

    # ======================================================================================
    # DETALHE (passe 2, layout aprovado): cor de chão por região, vila mais viva, marcos e vegetação baixa.
    # Nada aqui muda estradas, POIs ou spawners.
    # ======================================================================================
    def patch(name, c, r, color, paved=False, grass=False, jitter=0.12):
        """Mancha de chão (material pave_*/patch_* vira chão pintado no jogo); grass=False tira a grama."""
        m = mat(("pave_" if paved else "patch_") + name, color)
        disc(coll, P + "chao_" + name, c, r, 0.006, m, 36, jitter, len(name))
        if not grass:
            data["roads"].append({"kind": "street", "w": 0, "pts": [[c[0], c[1]]], "r": r})

    patch("trigal", (fx - 1, fz), 8.2, (0.86, 0.76, 0.42), jitter=0.04)       # dentro da cerca da fazenda
    patch("mata_leste", POIS["bosque"], 27, (0.33, 0.5, 0.31), grass=True)
    patch("mata_leste_borda", POIS["bosque"], 32, (0.36, 0.53, 0.33), grass=True, jitter=0.18)
    patch("mata_noroeste", G((-62, -64)), 36, (0.31, 0.48, 0.3), grass=True)
    patch("colinas", POIS["colinas"], 31, (0.56, 0.6, 0.44), grass=True)
    patch("flores", G((34, 56)), 12, (0.66, 0.76, 0.48), grass=True)
    patch("praia", POIS["praia"], 11, (0.86, 0.8, 0.6), jitter=0.16)         # areal da margem sul: boca da garganta da Praia dos Caranguejos
    patch("clareira", (ccx, ccz), 10.5, (0.62, 0.52, 0.36))
    m_hay = mat("hay", (0.8, 0.64, 0.3))
    m_wheat = mat("wheat", (0.78, 0.66, 0.3))
    m_fire = mat("fire", (1.0, 0.6, 0.2))
    m_stone = mat("cliff_rock_d", (0.5, 0.44, 0.38))

    # --- fazenda: fileiras de trigo, medas de feno e moinho (marco do sudoeste) ---
    # fileiras de tufos de trigo (uma malha só): cones baixos levemente tortos, a cada 0,55 m
    bm = bmesh.new()
    rw = random.Random(4)
    for i in range(-6, 7):
        x = fx - 1 + i * 1.15
        zz = fz - 6.6
        while zz < fz + 6.6:
            c = B(x + rw.uniform(-0.12, 0.12), zz, 0.0)
            h = rw.uniform(0.45, 0.65)
            lean = Vector((rw.uniform(-0.08, 0.08), rw.uniform(-0.08, 0.08), 0))
            tip = bm.verts.new(c + Vector((0, 0, h)) + lean)
            ring = [bm.verts.new(c + Vector((math.cos(a) * 0.2, math.sin(a) * 0.2, 0))) for a in (0.3, 1.87, 3.44, 5.01)]
            for j in range(4):
                bm.faces.new((ring[j], ring[(j + 1) % 4], tip))
            zz += 0.55
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    obj(coll, P + "trigo", bm, m_wheat)
    for k, (hx, hz) in enumerate(((fx + 5.5, fz + 6.5), (fx + 5.5, fz - 6.0))):
        cyl(coll, P + "feno_%d" % k, (hx, hz), 1.0, 1.0, 1.0, m_hay, 0.0, 10)
        cone(coll, P + "feno_topo_%d" % k, (hx, hz), 1.05, 0.7, m_hay, 1.0, 10)
        ob("pillar", hx, hz, (2.0, 1.7, 2.0), visible=False)
    mx, mz = fx - 15.0, fz + 2.0
    cyl(coll, P + "moinho_torre", (mx, mz), 2.4, 1.7, 7.5, M["wall"], 0.0, 10)
    cone(coll, P + "moinho_teto", (mx, mz), 2.1, 2.2, M["roof"], 7.5, 10)
    # pás em X, no plano vertical do lado leste da torre (viradas pra estrada/vila)
    hub = B(mx + 2.0, mz, 7.0)
    bm = bmesh.new()
    for k in range(4):
        a = math.radians(45 + 90 * k)
        u = Vector((0.0, math.cos(a), math.sin(a)))          # ao longo da pá (plano YZ do Blender)
        w = Vector((0.0, -math.sin(a), math.cos(a))) * 0.45  # meia largura
        quad = [hub + u * 0.4 - w, hub + u * 4.4 - w, hub + u * 4.4 + w, hub + u * 0.4 + w]
        vs = [bm.verts.new(v) for v in quad] + [bm.verts.new(v + Vector((0.08, 0, 0))) for v in quad]
        bm.faces.new(vs[:4])
        bm.faces.new(list(reversed(vs[4:])))
        for j in range(4):
            bm.faces.new((vs[j], vs[(j + 1) % 4], vs[4 + (j + 1) % 4], vs[4 + j]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    obj(coll, P + "moinho_pas", bm, M["wood"])
    cyl(coll, P + "moinho_eixo", (mx + 1.6, mz), 0.35, 0.35, 0.6, M["wood"], 6.7, 8)
    ob("pillar", mx, mz, (4.6, 7.5, 4.6), visible=False)

    # --- lago: píer de madeira na margem norte (visual; a água é sólida na sim) ---
    pier_a = Vector((LAKE[0][0] + 3.0, LAKE[0][1] - LAKE[1] - 2.5))      # da margem norte para dentro d'água
    pier_b = Vector((LAKE[0][0] + 1.5, LAKE[0][1] - LAKE[1] + 5.5))
    d = pier_b - pier_a
    pc = (pier_a + pier_b) * 0.5
    box(coll, P + "pier", (pc.x, pc.y), (d.length, 0.18, 1.8), along(d.x, d.y), M["wood"], 0.12)
    for k in range(4):
        q = pier_a + d * (k / 3.0)
        for sx in (-1, 1):
            side = Vector((-d.y, d.x)).normalized() * 0.85 * sx
            cyl(coll, P + "pier_poste_%d_%d" % (k, sx), (q.x + side.x, q.y + side.y), 0.12, 0.12, 0.7, M["wood"], -0.2, 6)

    # --- fogueira do guarda da estrada ---
    fcx, fcz = G((-7.0, 46.0))
    for k in range(7):
        a = math.tau * k / 7
        box(coll, P + "fogueira_pedra_%d" % k, (fcx + math.cos(a) * 0.75, fcz + math.sin(a) * 0.75), (0.32, 0.22, 0.28), math.degrees(a), m_stone, 0.0)
    for k in range(3):
        box(coll, P + "fogueira_lenha_%d" % k, (fcx, fcz), (1.0, 0.16, 0.16), 60 * k, M["wood"], 0.05)
    cone(coll, P + "fogueira_fogo", (fcx, fcz), 0.35, 0.8, m_fire, 0.12, 7)

    # --- placas nos cruzamentos (poste + duas tábuas apontando os caminhos) ---
    for k, (sx_, sz_, r1, r2) in enumerate([G((x, z)) + (a, b) for x, z, a, b in ((-76.5, 26.5, 20, 160), (26.0, -46.0, 10, 200),
                                            (91.5, -7.5, 120, -30), (2.5, 58.0, 170, 20))]):
        cyl(coll, P + "placa_poste_%d" % k, (sx_, sz_), 0.1, 0.09, 2.3, M["wood"], 0.0, 6)
        box(coll, P + "placa_tabua_a_%d" % k, (sx_, sz_), (1.1, 0.26, 0.06), r1, M["wood"], 1.85)
        box(coll, P + "placa_tabua_b_%d" % k, (sx_, sz_), (1.0, 0.24, 0.06), r2, M["wood"], 1.5)
    for k, (sx_, sz_, r1, r2) in enumerate([(7.6, -51.0, -60, 100)]):      # bifurcação N / castelo (a placa ficava onde hoje é a torre do portão)
        cyl(coll, P + "placa_poste_n%d" % k, (sx_, sz_), 0.1, 0.09, 2.3, M["wood"], 0.0, 6)
        box(coll, P + "placa_tabua_a_n%d" % k, (sx_, sz_), (1.1, 0.26, 0.06), r1, M["wood"], 1.85)
        box(coll, P + "placa_tabua_b_n%d" % k, (sx_, sz_), (1.0, 0.24, 0.06), r2, M["wood"], 1.5)

    # --- vegetação baixa: arbustos na beira das estradas (não bloqueiam) e pedras no pé dos penhascos ---
    bushes = 0
    for name, poly in veg_polys.items():
        if name in LATE_ROADS:
            continue
        for i in range(4, len(poly) - 4, 6):
            q = poly[i]
            t = (poly[i + 1] - poly[i - 1]).normalized()
            nrm = Vector((-t.y, t.x)) * (1 if rnd.random() < 0.5 else -1)
            pos = q + nrm * rnd.uniform(3.8, 5.5)
            if free(pos.x, pos.y, 3.4) and all((pos - Vector(o["pos"])).length > 2.2 for o in obs[-30:]):
                s = rnd.uniform(0.45, 0.65) / 0.55
                ob("bush", pos.x, pos.y, (1.7 * s, 0.95 * s, 1.7 * s), solid=False,
                   color=(0.36, 0.6, 0.34) if rnd.random() < 0.5 else (0.44, 0.66, 0.36))
                bushes += 1
    for i in range(70):
        a = math.tau * i / 70 + rnd.uniform(-0.02, 0.02)
        r = rim_r(a) - rnd.uniform(2.5, 5.0)
        x, z = math.cos(a) * r, math.sin(a) * r
        if free(x, z, 3.0) and rnd.random() < 0.7:
            s = rnd.uniform(1.0, 2.2)
            ob("rock", x, z, (1.4 * s, 1.0 * s, 1.2 * s), color=(0.58, 0.54, 0.5))

    # --- natureza (passe 3): pinheiros nas colinas, flores na campina, moitas, troncos/tocos nos bosques, juncos ---
    nrnd = random.Random(31)
    nature.fix_trees(obs, nrnd, pine_frac=0.75, region=lambda x, z: z < -60 or (x < -40 and z < -40))
    nature.scatter(ob, free, nrnd, "pine", [(POIS["colinas"], 41, 36), (G((-62, -64)), 31, 14), (G((70, -84)), 24, 11)],
                   (1.9, 4.6, 1.9), nature.PINE_COLS, margin=4.2, spacing=3.6, scale=(0.95, 1.35), rotate=False, avoid=obs)
    nature.scatter(ob, free, nrnd, "flowers", [(POIS["lago"], 36, 20), (POIS["clareira"], 26, 11), (G((0, 44)), 48, 22),
                   (G((-40, -30)), 36, 14), (G((50, -12)), 31, 14), (G((-30, 60)), 29, 11), (G((40, 70)), 26, 11)],
                   (1.6, 0.45, 1.6), nature.FLOWER_COLS, solid=False, margin=2.6, spacing=4.0, scale=(0.8, 1.4), avoid=obs)
    nature.scatter(ob, free, nrnd, "bush", [((0, 0), 126, 78), (POIS["bosque"], 31, 20), (G((-62, -64)), 34, 17)],
                   (1.7, 0.95, 1.7), nature.BUSH_COLS, solid=False, margin=2.8, spacing=3.0, scale=(0.8, 1.3), avoid=obs)
    nature.woodland_floor(ob, free, nrnd, [(POIS["bosque"], 29, 34), (G((-62, -64)), 31, 34), (G((40, 70)), 19, 13)], avoid=obs)
    nature.clear_banks(obs, [river], [LAKE], RIVER_W)
    # sem a trilha da Praia (entrou depois): os juncos do lago saem do mesmo sorteio de antes; o passe de estradas tira os que caem nela
    nature.shore(ob, nrnd, [river], [LAKE], [v for k, v in road_polys.items() if k != "praia"], RIVER_W)

    # estradas que entraram depois (LATE_ROADS): moitas na beira com sorteio próprio, depois de todos os passes acima
    lrnd = random.Random(97)
    for name in LATE_ROADS:
        poly = road_polys[name]
        for i in range(4, len(poly) - 4, 6):
            t = (poly[i + 1] - poly[i - 1]).normalized()
            pos = poly[i] + Vector((-t.y, t.x)) * (1 if lrnd.random() < 0.5 else -1) * lrnd.uniform(3.8, 5.5)
            s = lrnd.uniform(0.45, 0.65) / 0.55
            col = (0.36, 0.6, 0.34) if lrnd.random() < 0.5 else (0.44, 0.66, 0.36)
            if (free(pos.x, pos.y, 3.4) and all(poly_dist(pos, road_polys[n]) > 3.4 for n in LATE_ROADS)
                    and all((pos - Vector(c)).length > r for c, r in LATE_SPOTS)
                    and all((pos - Vector(o["pos"])).length > 2.2 for o in obs if o["visible"] and abs(o["pos"][0] - pos.x) < 4)):
                ob("bush", pos.x, pos.y, (1.7 * s, 0.95 * s, 1.7 * s), solid=False, color=col)

    # ---------- spawners, NPCs, hangouts ----------
    def sp(mid, x, z, r, n, respawn):
        data["spawners"].append({"monster_id": mid, "pos": [x, z], "radius": r, "count": n, "respawn": respawn})
    lx, lz = LAKE[0]
    for q, r, n in (((-20.0, 88.0), 8, 6), ((28.0, 64.0), 8, 6), ((18.0, 48.0), 7, 5), ((-38.0, 40.0), 8, 5), ((44.0, 30.0), 8, 5)):
        sp("slime", *G(q), r, n, 10.0)
    sp("slime_blue", lx + 26, lz + 12, 7, 5, 14.0)
    sp("slime_blue", fx + 4, fz - 2, 7, 4, 14.0)
    sp("slime_blue", *G((-70.0, 40.0)), 7, 4, 14.0)
    bx, bz = POIS["bosque"]
    sp("boar", bx - 9, bz - 7, 9, 5, 16.0)
    sp("boar", bx + 9, bz + 16, 8, 5, 16.0)
    sp("boar", bx + 20, bz - 14, 8, 4, 16.0)
    sp("boar_brute", bx, bz + 2, 2, 1, 90.0)          # mini-chefe nível 5 no meio do bosque (1º conjunto lendário)
    wx, wz = POIS["colinas"]
    sp("wolf", wx + 5, wz + 12, 10, 5, 18.0)
    sp("wolf", wx + 30, wz - 2, 9, 5, 18.0)
    sp("wolf", wx - 26, wz + 6, 9, 4, 18.0)
    sp("boar_king", ccx, ccz, 2, 1, 120.0)
    # os caranguejos e o Caranguejo-Rei da margem sul mudaram para a Praia dos Caranguejos (field_crab_beach, 2026-11-21):
    # aqui ficou o areal com a garganta (portal to_field_crab_beach)

    def face_to(x, z, tx, tz):
        return round(math.degrees(math.atan2(tx - x, tz - z)), 1)
    for nid, v in centerpiece["posts"].items():          # serviços: na porta/balcão do prédio de cada um (town_dress)
        data["npcs"][nid] = [v[0], v[1], v[2]]
    data["npcs"]["founder_statue"] = [FOUNDER[0], FOUNDER[1], face_to(FOUNDER[0], FOUNDER[1], 0.0, 0.0)]
    for gname, (g, gdir) in gates.items():               # guardas: do lado de fora de cada portão, junto da torre, olhando para fora
        out = g.normalized()
        q = g + out * 2.6 - Vector((-out.y, out.x)) * 4.6
        data["npcs"]["guard_" + gname.lower()] = [round(q.x, 2), round(q.y, 2), face_to(q.x, q.y, q.x * 2, q.y * 2)]
    mg = G((-5.0, 47.0))
    data["npcs"]["meadow_guard"] = [mg[0], mg[1], face_to(mg[0], mg[1], mg[0] * 2, mg[1] * 2)]
    data["hangouts"] = [list(h) for h in centerpiece["hangouts"]]

    # ---------- pontos de evento de estrada (RoadEventSystem, GDD living-towns 3.5): à beira da estrada, fora do hub ----------
    data["events"] = []
    def event_why(q):
        """Motivo de um ponto de evento não servir ("" = serve): GDD 3.5 regra 3."""
        far = lambda c, r: (q - Vector(c)).length >= r
        if q.length < 40.0:
            return "hub"
        if not free(q.x, q.y, ROAD_W * 0.5 + 0.6):
            return "estrada/agua/morro"
        if not all(far(pp["pos"], 25.0) for pp in PORTALS.values()) or not all(far(c, 25.0) for c, _ in spots[:2]):
            return "portal/chegada"
        if not all(far(v[:2], 25.0) for v in data["npcs"].values()):
            return "npc"
        if not all(far(s_["pos"], 25.0) for s_ in data["spawners"] if s_["count"] == 1):
            return "chefe"
        if not all(far(o["pos"], max(o["size"][0], o["size"][2]) * 0.5 + 1.6) for o in obs if o["solid"] and o["kind"] != "cliff"):
            return "obstaculo"
        if not all(far(e_["pos"], 30.0) for e_ in data["events"]):
            return "outro ponto"
        return ""

    for kind, road, frac, side, mob in EVENT_POINTS:
        poly = legacy_polys[road]
        found, why = None, ""
        # o ponto pedido primeiro; se não servir, anda pela estrada (até 20% para cada lado) e troca de margem
        for df in (0.0, 0.04, -0.04, 0.08, -0.08, 0.12, -0.12, 0.16, -0.16, 0.2, -0.2):
            for sd in (side, -side, side * 1.3, -side * 1.3):
                i = max(1, min(len(poly) - 2, int((frac + df) * (len(poly) - 1))))
                t = (poly[i + 1] - poly[i - 1]).normalized()
                q = poly[i] + Vector((-t.y, t.x)) * sd
                w = event_why(q)
                if w == "":
                    found = q
                    break
                why = why or w
            if found is not None:
                break
        if found is None:
            print("EVENT_CONFLICT %s em %s: nenhum ponto serve (%s)" % (kind, road, why))
            continue
        data["events"].append({"kind": kind, "pos": [round(found.x, 2), round(found.y, 2)], "mob": mob, "road": road})

    # ---------- passe de estradas: decoração que cai no caminho sai; spawner que pega a estrada se afasta ----------
    lanes = [(poly, (places.TRAIL_W if name.startswith("trilha_") else ROAD_W) * 0.5) for name, poly in road_polys.items()]
    before = len(obs)
    def on_lane(o):
        if o["kind"] not in ROAD_DECOR or not o["visible"]:
            return False
        p = Vector(o["pos"])
        half = (max(o["size"][0], o["size"][2]) if o["kind"] == "fence" else (o["size"][0] + o["size"][2]) * 0.5) * 0.5
        if not o.get("y") and any((p - Vector(c)).length < r + half for c, r in LATE_SPOTS):
            return True                   # chegada e portal que entraram depois do sorteio (LATE_*)
        return any(poly_dist(p, poly) < hw + half for poly, hw in lanes)
    obs[:] = [o for o in obs if not on_lane(o)]
    print("estradas limpas: %d objetos tirados do caminho" % (before - len(obs)))
    for s_ in data["spawners"]:
        p = Vector(s_["pos"])
        for _ in range(24):
            hit = min(((poly_dist(p, poly) - hw, poly) for poly, hw in lanes), key=lambda t: t[0])
            if hit[0] > s_["radius"] * 0.6 or s_["radius"] <= 2:
                break
            q = min(hit[1], key=lambda v: (v - p).length)
            p = p + (p - q).normalized() * 1.0
        s_["pos"] = [round(p.x, 2), round(p.y, 2)]

    # a vegetação foi sorteada com a vila antiga (raio 30): o que caiu na faixa da muralha nova sai, e a vila entra na frente
    VEG = ("tree", "pine", "bush", "flowers", "rock", "stump", "log", "reeds", "dead_tree")
    before = len(obs)
    obs[:] = [o for o in obs if not (o["kind"] in VEG and Vector(o["pos"]).length < TOWN_R + 4.5)]
    print("muralha nova: %d objetos de vegetacao tirados da faixa" % (before - len(obs)))
    obs[:] = town_obs + obs

    # ---------- marcadores no Blender (convenção do CLAUDE.md) ----------
    for i, o in enumerate(obs):
        if not o["visible"]:
            e = bpy.data.objects.new("OB_box_%s_%03d" % (o["kind"], i), None)
            e.empty_display_type = "CUBE"
            e.location = B(o["pos"][0], o["pos"][1], o["size"][1] / 2)
            e.scale = (o["size"][0] / 2, o["size"][2] / 2, o["size"][1] / 2)
            e.rotation_euler = (0, 0, math.radians(o["rot"]))
            sc.collection.objects.link(e)
    data["roads"].extend(late_roads)
    for s in data["spawners"]:
        e = bpy.data.objects.new("SPAWN_mob_%s" % s["monster_id"], None)
        e.empty_display_type = "CIRCLE"
        e.empty_display_size = s["radius"]
        e.location = B(s["pos"][0], s["pos"][1], 0.2)
        sc.collection.objects.link(e)
    for i, ev in enumerate(data["events"]):
        e = bpy.data.objects.new("SPAWN_event_%s_%02d" % (ev["kind"], i + 1), None)
        e.empty_display_type = "CONE"
        e.location = B(ev["pos"][0], ev["pos"][1], 0.2)
        sc.collection.objects.link(e)
    for pid, p in PORTALS.items():
        e = bpy.data.objects.new("TRIG_portal_%s" % p["target_map"], None)
        e.empty_display_type = "SPHERE"
        e.empty_display_size = 2.0
        e.location = B(p["pos"][0], p["pos"][1], 1.0)
        sc.collection.objects.link(e)

    # câmeras de avaliação
    cam_top = bpy.data.cameras.new("CAM_top")
    cam_top.type = "ORTHO"
    cam_top.ortho_scale = 310
    o = bpy.data.objects.new("CAM_top", cam_top)
    o.location = (0, 0, 200)
    sc.collection.objects.link(o)
    cam_town = bpy.data.cameras.new("CAM_town")
    cam_town.type = "ORTHO"
    cam_town.ortho_scale = 2 * TOWN_R + 14
    o2 = bpy.data.objects.new("CAM_town", cam_town)
    o2.location = (0, 0, 200)
    sc.collection.objects.link(o2)
    views = [("CAM_game", (0.0, 4.0)), ("CAM_poi", POIS["lago"])] + [("CAM_d_" + k, v) for k, v in centerpiece["views"].items()]
    for name, (tx, tz) in views:
        cd = bpy.data.cameras.new(name)
        cd.lens_unit = "FOV"
        cd.angle = math.radians(35 * 1.6)
        co = bpy.data.objects.new(name, cd)
        pitch = math.radians(52)
        dist = 15.0 * 1.6
        tgt = B(tx, tz, 0.8)
        co.location = tgt + Vector((0, -math.cos(pitch) * dist, math.sin(pitch) * dist))
        co.rotation_euler = (math.radians(90 - 52), 0, 0)
        sc.collection.objects.link(co)
    sc.camera = o

    preview(sc, data, M)
    if export:
        os.makedirs(ROOT + "/data/zones", exist_ok=True)
        with open(ROOT + "/data/zones/%s.json" % ZONE, "w", encoding="utf-8") as f:
            json.dump(data, f, ensure_ascii=False, indent=1)
        bpy.ops.object.select_all(action="DESELECT")
        for ob_ in coll.objects:
            ob_.select_set(True)
        kw = {}
        if "export_vertex_color" in bpy.ops.export_scene.gltf.get_rna_type().properties:
            kw["export_vertex_color"] = "ACTIVE"       # lotes do dress.py (town_dress): a cor de cada peça vai no vértice (COLOR_0)
        bpy.ops.export_scene.gltf(filepath=ROOT + "/assets/models/map_%s.glb" % ZONE, export_format="GLB", use_selection=True, use_active_scene=True,
                                  export_apply=True, export_animations=False, export_yup=True, export_materials="EXPORT", **kw)
        print("exportado: map_%s.glb + data/zones/%s.json" % (ZONE, ZONE))
    return data
