"""Lugares pequenos que deixam a zona viva: cabana com NPC, acampamento de monstros, santuário e entrada de dungeon.
Cada zona só declara uma lista de dados (`PLACES` em build_<zona>.py) e chama `places.build(z, PLACES)`; a forma vem daqui.
Funciona com Zone e com o objeto equivalente de Aldara: precisa de data, ob, coll, P, road_polys, rivers e block(c, r).
Chame depois das estradas/rio e antes da vegetação (block reserva o chão; a trilha entra em road_polys).
"""
import math
from mathutils import Vector
from zone_lib import along, box, catmull, cyl, disc, mat, poly_dist, ribbon

TRAIL_W = 2.4
GATE_R = 5.5            # raio do morro da entrada de dungeon

# Vale de Aldara cresceu ~20%: tudo fora da muralha se afasta do centro (a vila não muda). Uma função só, usada
# pela zona, pelas entradas de dungeon dela e pelas chegadas das zonas vizinhas.
ALDARA_KEEP_R = 36.0         # muralha (30) + folga: dentro disto nada se mexe
ALDARA_GROW = 1.2


def grow_aldara(p):
    v = Vector((float(p[0]), float(p[1])))
    r = v.length
    if r <= ALDARA_KEEP_R:
        return (round(v.x, 2), round(v.y, 2))
    k = (ALDARA_KEEP_R + (r - ALDARA_KEEP_R) * ALDARA_GROW) / r
    return (round(v.x * k, 2), round(v.y * k, 2))


DUNGEONS = {
    "dg_gruta": {"zone": "city_aldara", "gate": grow_aldara((86.0, -42.0)), "face": 100.0, "name": "Gruta Gotejante", "seed": 5, "flip": 1,
                 "rooms": [("slime_blue", 8), ("boar", 6), ("slime_blue", 7)], "boss": "slime_king",
                 "rock": (0.34, 0.37, 0.42), "floor": (0.42, 0.45, 0.46), "glow": (0.45, 0.8, 0.95)},
    "dg_ninho": {"zone": "field_forest", "gate": (-70.0, 76.0), "face": 40.0, "name": "Ninho Profundo", "seed": 7, "flip": -1,
                 "rooms": [("spider", 8), ("spider", 8), ("ent", 4)], "boss": "spider_queen",
                 "rock": (0.27, 0.3, 0.27), "floor": (0.36, 0.38, 0.32), "glow": (0.6, 0.95, 0.5)},
    "dg_cripta": {"zone": "field_ruins", "gate": (20.0, -92.0), "face": 90.0, "name": "Cripta de Vel'Thar", "seed": 9, "flip": 1,
                  "rooms": [("skeleton", 8), ("ghost", 7), ("golem", 3)], "boss": "crypt_lord",
                  "rock": (0.3, 0.28, 0.33), "floor": (0.42, 0.4, 0.42), "glow": (0.75, 0.55, 0.95)},
}
# Catacumbas: dungeon ramificada. `layout` = salões + ligações (build_dungeons.build_graph); o selo leva ao Trono, um mapa à parte.
DUNGEONS["dg_catacumbas"] = {
    "zone": "city_aldara", "gate": grow_aldara((84.0, 56.0)), "face": 200.0, "name": "Catacumbas do Conde", "seed": 11,
    "rock": (0.27, 0.26, 0.31), "floor": (0.4, 0.38, 0.42), "glow": (0.55, 0.45, 0.9),
    "layout": {
        "rooms": {
            "vestibulo": {"pos": (0, 20), "r": 12},
            "oeste_1": {"pos": (-30, 18), "r": 10, "mobs": [("zombie", 6)]},
            "oeste_2": {"pos": (-42, -8), "r": 10, "mobs": [("bone_recruit", 5), ("bone_archer", 3)]},
            "oeste_chefe": {"pos": (-24, -36), "r": 13, "boss": "bone_captain"},
            "leste_1": {"pos": (30, 18), "r": 10, "mobs": [("ghoul", 5)]},
            "alcova": {"pos": (30, 42), "r": 6},
            "leste_2": {"pos": (42, -8), "r": 10, "mobs": [("wraith", 4), ("zombie", 4)]},
            "leste_chefe": {"pos": (24, -36), "r": 13, "boss": "wailing_widow"},
            "selo": {"pos": (0, -8), "r": 7, "mobs": [("bone_recruit", 2)]},
        },
        "edges": [("chegada", "vestibulo"), ("vestibulo", "oeste_1"), ("oeste_1", "oeste_2"), ("oeste_2", "oeste_chefe"),
                  ("vestibulo", "leste_1"), ("leste_1", "alcova"), ("leste_1", "leste_2"), ("leste_2", "leste_chefe"), ("vestibulo", "selo")],
        "npcs": {"sister_odete": (-6.0, 24.0, 90.0), "gravedigger_bento": (30.0, 44.0, 180.0)},
        "door": {"target": "dg_catacumbas_trono", "pos": (0.0, -12.0), "label": "Selo do Conde"},
    },
}
DUNGEONS["dg_catacumbas_trono"] = {
    "zone": "dg_catacumbas", "return": (0.0, -6.0), "name": "Trono do Conde", "seed": 13,
    "rock": (0.24, 0.2, 0.28), "floor": (0.38, 0.32, 0.4), "glow": (0.7, 0.3, 0.85),
    "layout": {
        "rooms": {
            "galeria": {"pos": (0, 16), "r": 10, "mobs": [("bone_recruit", 3), ("bone_archer", 2)]},
            "trono": {"pos": (0, -20), "r": 17, "boss": "count_vargo"},
        },
        "edges": [("chegada", "galeria"), ("galeria", "trono")],
    },
}
# Coração da Árvore: a raiz norte da Árvore-Mãe Ancestral (Cidade Élfica) desce ao salão do Rei Élfico.
# Dentro da Árvore-Mãe: a porta é um arco entalhado no tronco, virada para a câmera do jogo (sudeste) (style "tree", sem morro); paredes de casca altas
# com musgo em cima, chão de raiz, seiva brilhando e lanternas élficas.
TREE_ROOT_DECOR = [("log", 4, (2.6, 0.8, 0.9), (0.4, 0.3, 0.2)), ("stump", 3, (1.2, 0.9, 1.2), (0.38, 0.28, 0.2)), ("bush", 3, (1.4, 0.8, 1.4), (0.3, 0.55, 0.35))]
TREE_SAP_DECOR = [("crystal", 4, (0.9, 1.6, 0.9), (0.75, 1.0, 0.5)), ("elf_lantern", 3, (0.6, 2.4, 0.6), None), ("flowers", 3, (1.4, 0.4, 1.4), (0.8, 0.95, 0.6))]
DUNGEONS["dg_coracao"] = {
    "zone": "elf_city", "gate": (6.2, 6.2), "face": 45.0, "style": "tree", "name": "Coração da Árvore", "seed": 17,
    "rock": (0.42, 0.3, 0.2), "floor": (0.5, 0.4, 0.28), "glow": (0.7, 1.0, 0.5), "walls": "bark", "top": (0.3, 0.5, 0.3),
    "layout": {
        "rooms": {
            "raizes": {"pos": (0, 18), "r": 12, "mobs": [("elf_archer", 3), ("elf_warrior", 3)], "floor": (0.46, 0.36, 0.24), "decor": TREE_ROOT_DECOR,
                       "inner": [("log", 3, (3.2, 0.9, 1.0), (0.42, 0.3, 0.2)), ("elf_lantern", 2, (0.6, 2.4, 0.6), None)]},
            "seiva": {"pos": (-26, -8), "r": 10, "mobs": [("trent", 2), ("elf_warden", 1)], "floor": (0.5, 0.56, 0.3), "decor": TREE_SAP_DECOR, "pool": (0.75, 1.0, 0.5)},
            "trono": {"pos": (6, -36), "r": 17, "boss": "elf_king", "floor": (0.56, 0.46, 0.3), "pool": (0.75, 1.0, 0.5),
                      "inner": [("log", 5, (3.6, 1.0, 1.1), (0.4, 0.28, 0.18)), ("crystal", 3, (0.8, 1.4, 0.8), (0.75, 1.0, 0.5))],
                      "decor": [("dead_tree", 6, (1.6, 3.6, 1.6), (0.4, 0.3, 0.2)), ("elf_lantern", 4, (0.6, 2.4, 0.6), None), ("crystal", 3, (0.9, 1.6, 0.9), (0.75, 1.0, 0.5))]},
        },
        "edges": [("chegada", "raizes"), ("raizes", "seiva"), ("seiva", "trono")],
    },
}
MOSS_FLOOR = (0.44, 0.5, 0.34)
MOSS_DECOR = [("rock", 6, (1.5, 0.9, 1.3), (0.42, 0.56, 0.34)), ("bush", 4, (1.6, 0.9, 1.6), (0.34, 0.5, 0.3))]
CRYSTAL_FLOOR = (0.5, 0.54, 0.62)
CRYSTAL_DECOR = [("pillar", 6, (0.55, 2.4, 0.55), (0.45, 0.75, 1.0)), ("rock", 3, (1.3, 0.8, 1.1), (0.55, 0.62, 0.75))]
# Pedreira dos Golens (Floresta, 11-15): acampamento de mineiros no vestíbulo, ala do musgo (oeste) e do cristal (leste),
# cada uma com um guardião; o Veio no fundo leva ao Coração da Pedreira (mapa à parte, abre com os dois guardiões mortos).
DUNGEONS["dg_pedreira"] = {
    "zone": "field_forest", "gate": (-88.0, -42.0), "face": 49.0, "name": "Pedreira dos Golens", "seed": 19,
    "rock": (0.52, 0.42, 0.3), "floor": (0.56, 0.49, 0.38), "glow": (0.45, 0.75, 1.0),
    "layout": {
        "rooms": {
            "vestibulo": {"pos": (0, 20), "r": 12, "floor": (0.6, 0.52, 0.4), "decor": [("tent", 2, (3.2, 2.3, 3.2), (0.62, 0.5, 0.34)), ("crate", 4, (1.0, 1.0, 1.0), None), ("barrel", 3, (0.8, 1.0, 0.8), None)]},
            "musgo_1": {"pos": (-30, 16), "r": 10, "mobs": [("golem_moss", 6)], "floor": MOSS_FLOOR, "decor": MOSS_DECOR},
            "musgo_2": {"pos": (-44, -10), "r": 10, "mobs": [("golem_moss", 3), ("golem_stone", 2)], "floor": MOSS_FLOOR, "decor": MOSS_DECOR},
            "musgo_chefe": {"pos": (-26, -36), "r": 13, "boss": "golem_ancient", "floor": (0.38, 0.5, 0.3), "decor": MOSS_DECOR},
            "cristal_1": {"pos": (30, 16), "r": 10, "mobs": [("golem_shard", 4), ("golem_stone", 1)], "floor": CRYSTAL_FLOOR, "decor": CRYSTAL_DECOR},
            "cristal_2": {"pos": (44, -10), "r": 10, "mobs": [("golem_stone", 3), ("golem_shard", 2)], "floor": CRYSTAL_FLOOR, "decor": CRYSTAL_DECOR},
            "cristal_chefe": {"pos": (26, -36), "r": 13, "boss": "crystal_warden", "floor": (0.44, 0.52, 0.66), "decor": CRYSTAL_DECOR},
            "veio": {"pos": (0, -8), "r": 7, "mobs": [("golem_stone", 2)], "floor": (0.66, 0.46, 0.3)},
        },
        "edges": [("chegada", "vestibulo"), ("vestibulo", "musgo_1"), ("musgo_1", "musgo_2"), ("musgo_2", "musgo_chefe"),
                  ("vestibulo", "cristal_1"), ("cristal_1", "cristal_2"), ("cristal_2", "cristal_chefe"), ("vestibulo", "veio")],
        "npcs": {"miner_tadeu": (-6.0, 24.0, 90.0), "miner_rosa": (6.0, 25.0, 270.0)},
        "door": {"target": "dg_pedreira_coracao", "pos": (0.0, -12.0), "label": "Veio da Montanha"},
    },
}
DUNGEONS["dg_pedreira_coracao"] = {
    "zone": "dg_pedreira", "return": (0.0, -6.0), "name": "Coração da Pedreira", "seed": 23,
    "rock": (0.46, 0.32, 0.24), "floor": (0.52, 0.4, 0.32), "glow": (1.0, 0.6, 0.3),
    "layout": {
        "rooms": {
            "galeria": {"pos": (0, 16), "r": 10, "mobs": [("golem_stone", 2), ("golem_shard", 2)], "floor": (0.56, 0.46, 0.36), "decor": MOSS_DECOR[:1] + CRYSTAL_DECOR[:1]},
            "coracao": {"pos": (0, -20), "r": 17, "boss": "quarry_heart", "floor": (0.66, 0.42, 0.28),
                        "decor": [("pillar", 6, (0.7, 2.6, 0.7), (1.0, 0.6, 0.3)), ("rock", 5, (1.6, 1.0, 1.4), (0.5, 0.36, 0.28))]},
        },
        "edges": [("chegada", "galeria"), ("galeria", "coracao")],
    },
}
DUNGEON_ARRIVE = (0.0, 44.0)   # chegada dentro de toda dungeon; a saída fica em DUNGEON_EXIT
DUNGEON_EXIT = (0.0, 50.0)


def direction(deg):
    a = math.radians(deg)
    return Vector((math.cos(a), math.sin(a)))


def gate_return(d):
    """Onde o jogador aparece na zona ao sair da dungeon: na frente da boca."""
    if "return" in d:
        return d["return"]
    p = Vector(d["gate"]) + direction(d["face"]) * (7.0 if d.get("style") == "tree" else GATE_R + 5.0)
    return (round(p.x, 1), round(p.y, 1))


def _rot(d):
    return along(-d.y, d.x)        # eixo X do prop na tangente: a frente olha para `d`


def _facing(d):
    return round(math.degrees(math.atan2(d.x, d.y)), 1)


def _ground(s, name, c, r, color):
    disc(s.coll, s.P + "chao_" + name, c, r, 0.006, mat("patch_" + name, color), 28, 0.1, len(name))
    s.data["roads"].append({"kind": "street", "w": 0, "pts": [[c[0], c[1]]], "r": r})


def _nearest_road(s, p):
    return min((q for k, poly in s.road_polys.items() if not k.startswith("trilha_") for q in poly), key=lambda q: (q - p).length)


def _trail(s, name, c, end):
    """Trilha estreita da estrada mais próxima até `end`, curva; kind "trail" não vira ponte na sim.
    Desvia das áreas de `s.avoid` (lago, fazenda, castelo, morros): o meio da curva sai por fora da área; se ainda
    pegar alguma, tenta outros pontos de saída nas estradas (do mais perto ao mais longe)."""
    end = Vector(end)
    avoid = [(Vector(ac), ar) for ac, ar in getattr(s, "avoid", [])]
    starts = sorted((q for k, poly in s.road_polys.items() if not k.startswith("trilha_") for q in poly), key=lambda q: (q - end).length)

    def route(start):
        span = end - start
        mid = start + span * 0.5 + Vector((-span.y, span.x)).normalized() * span.length * 0.14 * (1 if len(name) % 2 else -1)
        for ac, ar in avoid:
            t = max(0.0, min(1.0, (ac - start).dot(span) / max(span.length_squared, 1e-6)))
            near = start + span * t
            if (near - ac).length < ar + TRAIL_W:
                away = near - ac
                if away.length < 0.01:
                    away = Vector((-span.y, span.x))
                mid = ac + away.normalized() * (ar + TRAIL_W + 3.0)
        return catmull([tuple(start), tuple(mid), tuple(end)], 1.6)

    def bad(poly):
        return any((p - ac).length < ar + TRAIL_W * 0.5 for ac, ar in avoid for p in poly)

    poly = route(starts[0])
    for q in starts[:400:6]:
        cand = route(q)
        if not bad(cand) and (q - end).length < (starts[0] - end).length * 2.5 + 12.0:
            poly = cand
            break
    if bad(poly):
        print("PLACE_CONFLICT trilha de %s entra em área sólida" % name)
    for river in s.rivers:
        if any(poly_dist(p, river) < s.river_w * 0.5 for p in poly):
            print("PLACE_CONFLICT trilha de %s entra no rio" % name)
    s.road_polys["trilha_" + name] = poly
    ribbon(s.coll, s.P + "estrada_trilha_" + name, poly, TRAIL_W, 0.012, mat("patch_trilha", (0.6, 0.5, 0.36)))
    s.data["roads"].append({"kind": "trail", "w": TRAIL_W, "pts": [[round(p.x, 2), round(p.y, 2)] for p in poly[::2] + [poly[-1]]]})


def _ring(c, r, n, start=0.0, arc=math.tau):
    """Pontos e direções para fora num arco em volta de `c`."""
    for i in range(n):
        a = start + arc * i / n
        d = Vector((math.cos(a), math.sin(a)))
        yield Vector(c) + d * r, d


def cabin(s, p):
    c, d = Vector(p["pos"]), direction(p["face"])
    side = Vector((-d.y, d.x))
    _ground(s, p["id"], p["pos"], 8.0, p.get("ground", (0.56, 0.5, 0.38)))
    s.ob("house", c.x - d.x, c.y - d.y, (6.0, 3.4, 5.0), _rot(d), color=p.get("wall", (0.62, 0.48, 0.34)), roof=p.get("roof", (0.5, 0.36, 0.26)))
    door = c + d * 3.6
    n = c + d * 4.4 + side * 1.4
    s.data["npcs"][p["npc"]] = [round(n.x, 2), round(n.y, 2), _facing(d)]
    for k in (-1, 1):
        q = c + d * 3.0 + side * 3.6 * k
        s.ob("lamp", q.x, q.y, (0.4, 2.6, 0.4))
    # cerca atrás e dos lados; a frente fica aberta
    base = math.atan2(d.y, d.x) + 1.1
    for q, o in _ring(c, 6.8, 7, base, math.tau - 2.2):
        s.ob("fence", q.x, q.y, (2.6, 1.0, 0.3), along(-o.y, o.x), color=(0.5, 0.38, 0.26))
    q = c + d * 1.6 - side * 4.6
    s.ob("crate", q.x, q.y, (1.0, 1.0, 1.0))
    q = c + d * 2.6 - side * 5.2
    s.ob("log", q.x, q.y, (2.4, 0.6, 0.65), _rot(side), color=(0.42, 0.3, 0.2))
    _trail(s, p["id"], c, door + d * 2.0)
    s.block(p["pos"], 9.5)


def camp(s, p):
    c = Vector(p["pos"])
    w = p.get("when")                     # acampamento que some com a conquista (tendas sem colisão, spawner calado)
    _ground(s, p["id"], p["pos"], 11.0, p.get("ground", (0.46, 0.38, 0.3)))
    d = direction(p["face"])
    base = math.atan2(d.y, d.x)
    for q, o in _ring(c, 7.5, p.get("tents", 3), base + 0.9, math.tau - 1.8):
        s.ob("tent", q.x, q.y, (3.0, 2.2, 3.0), _rot(-o), color=p.get("cloth", (0.5, 0.3, 0.26)), when=w)
    for q, o in _ring(c, 9.8, 6, base + 1.2, math.tau - 2.4):
        s.ob("crate", q.x, q.y, (0.9, 0.9, 0.9), when=w)
    s.ob("lamp", c.x, c.y, (0.5, 2.0, 0.5), when=w)
    sp = {"monster_id": p["mob"], "pos": [c.x, c.y], "radius": 7.0, "count": p["count"], "respawn": p.get("respawn", 18.0)}
    if w:
        sp.update(w)
    s.data["spawners"].append(sp)
    _trail(s, p["id"], c, c + d * 8.5)
    s.block(p["pos"], 12.5)


def shrine(s, p):
    c = Vector(p["pos"])
    _ground(s, p["id"], p["pos"], 8.5, p.get("ground", (0.62, 0.62, 0.6)))
    d = (_nearest_road(s, c) - c).normalized()
    _trail(s, p["id"], c, c + d * 4.5)
    # o vão do círculo olha para onde a trilha chega de verdade (ela pode sair de outro ponto da estrada)
    poly = s.road_polys["trilha_" + p["id"]]
    entry = min(poly, key=lambda q: abs((q - c).length - 7.5))
    d = (entry - c).normalized()
    for i, (q, o) in enumerate(_ring(c, 6.4, 8, math.atan2(d.y, d.x) + math.pi / 8)):
        s.ob("pillar", q.x, q.y, (0.9, 2.4 + (i % 3) * 0.7, 0.9), color=(0.72, 0.7, 0.66))
    s.data["npcs"][p["npc"]] = [c.x, c.y, _facing(d)]        # a pedra do centro é o próprio NPC (modelo no maps_catalog)
    s.block(p["pos"], 10.0)


def dungeon(s, p):
    g = DUNGEONS[p["dungeon"]]
    if g.get("style") == "tree":
        return _tree_door(s, p, g)
    c, d = Vector(g["gate"]), direction(g["face"])
    side = Vector((-d.y, d.x))
    name = s.P + "dungeon_" + p["id"]
    rock = mat("rock_" + p["dungeon"], g["rock"])
    _ground(s, p["id"], tuple(c + d * (GATE_R + 3.0)), 5.5, (0.42, 0.38, 0.34))
    cyl(s.coll, name + "_morro", tuple(c), GATE_R + 1.4, GATE_R * 0.8, 2.6, rock, segs=12, jitter=0.25, seed=3)
    cyl(s.coll, name + "_topo", tuple(c - d), GATE_R * 0.85, GATE_R * 0.35, 3.6, rock, y0=2.6, segs=10, jitter=0.3, seed=5)
    mouth = c + d * (GATE_R + 0.4)
    box(s.coll, name + "_boca", tuple(mouth), (4.0, 1.4, 3.0), _rot(d), mat("dungeon_boca", (0.03, 0.03, 0.05)))
    box(s.coll, name + "_verga", tuple(mouth + d * 0.3), (5.6, 1.2, 0.9), _rot(d), rock, y0=3.0)
    box(s.coll, name + "_brilho", tuple(mouth + d * 0.75), (3.2, 0.1, 2.4), _rot(d), mat("glow_" + p["dungeon"], g["glow"]), y0=0.05)
    for k in (-1, 1):
        q = mouth + d * 0.8 + side * 2.6 * k
        s.ob("pillar", q.x, q.y, (0.9, 3.2, 0.9), color=(0.6, 0.58, 0.56))
        q = mouth + d * 3.2 + side * 3.6 * k
        s.ob("lamp", q.x, q.y, (0.4, 2.8, 0.4))
    s.ob("hill", c.x, c.y, ((GATE_R + 0.6) * 2, 5.0, (GATE_R + 0.6) * 2), visible=False)
    portal = c + d * (GATE_R + 1.6)
    s.data["portals"].append({"id": "to_" + p["dungeon"], "pos": [round(portal.x, 2), round(portal.y, 2)], "radius": 2.0,
                              "target_map": p["dungeon"], "target_pos": list(DUNGEON_ARRIVE), "label": g["name"]})
    _trail(s, p["id"], c, c + d * (GATE_R + 5.0))
    s.block(tuple(c), GATE_R + 5.0)
    s.block(tuple(c + d * (GATE_R + 3.0)), 6.0)


def _tree_door(s, p, g):
    """Porta entalhada no tronco de uma árvore gigante: o tronco já é sólido e o chão em volta já é praça,
    então sem morro, sem trilha e sem colina oculta. Arco escuro com moldura de casca, raízes dos lados,
    arco élfico e lanternas na frente, poça de seiva no chão."""
    c, d = Vector(g["gate"]), direction(g["face"])
    side = Vector((-d.y, d.x))
    name = s.P + "dungeon_" + p["id"]
    bark = mat("bark_" + p["dungeon"], (0.34, 0.24, 0.16))
    bark_l = mat("bark_l_" + p["dungeon"], (0.5, 0.38, 0.26))
    glow = mat("glow_" + p["dungeon"], g["glow"])
    box(s.coll, name + "_boca", tuple(c + d * 0.15), (3.4, 1.2, 4.2), _rot(d), mat("dungeon_boca", (0.03, 0.03, 0.05)))
    for k in (-1, 1):                                        # moldura: duas colunas de casca e raízes que abraçam a porta
        q = c + d * 0.45 + side * 2.15 * k
        cyl(s.coll, name + "_coluna_%d" % k, tuple(q), 0.55, 0.45, 5.2, bark_l, segs=8, jitter=0.12, seed=7 + k)
        for j in range(3):
            r0 = c + side * (2.6 + j * 0.9) * k
            box(s.coll, name + "_raiz_%d_%d" % (k, j), tuple(r0 + d * (1.2 + j * 0.8)), (0.9, 2.6 + j * 0.6, 1.0 - j * 0.15),
                _rot(d) + 0.25 * k, bark, y0=0.0)
    box(s.coll, name + "_verga", tuple(c + d * 0.5), (5.2, 1.0, 0.9), _rot(d), bark_l, y0=4.6)
    for i in range(5):                                       # runas de seiva no arco
        q = c + d * 1.0 + side * (i - 2) * 0.85
        box(s.coll, name + "_runa_%d" % i, tuple(q), (0.32, 0.08, 0.32), _rot(d), glow, y0=4.85)
    disc(s.coll, name + "_seiva", tuple(c + d * 2.4), 2.2, 0.02, glow, 20, 0.15, 3)
    s.ob("elf_arch", (c + d * 2.0).x, (c + d * 2.0).y, (5.6, 4.6, 1.0), math.degrees(_rot(d)), solid=False)
    for k in (-1, 1):
        q = c + d * 3.4 + side * 3.4 * k
        s.ob("elf_lantern", q.x, q.y, (0.6, 2.6, 0.6))
    portal = c + d * 1.8
    s.data["portals"].append({"id": "to_" + p["dungeon"], "pos": [round(portal.x, 2), round(portal.y, 2)], "radius": 2.0,
                              "target_map": p["dungeon"], "target_pos": list(DUNGEON_ARRIVE), "label": g["name"]})


def fort(s, p):
    """Forte élfico (Cidade Élfica): paliçada de casca com torres e um portão virado para a estrada (`face`),
    cabanas encostadas no fundo, lanternas no portão. Spawners: o capitão no centro (chefe com escolta,
    MonsterDef.escort) e os soldados (`guards` = [(monstro, n)]) em volta."""
    c = Vector(p["pos"])
    d = direction(p["face"])
    R = float(p.get("r", 13.0))
    gate = math.atan2(d.y, d.x)
    _ground(s, p["id"], p["pos"], R - 0.6, p.get("ground", (0.5, 0.46, 0.34)))
    s.ring_wall("forte_" + p["id"], tuple(c), R, [gate], gate_half=3.2, height=3.6, thick=1.2, material="bark", stakes=True, towers=4)
    for q, o in _ring(c, R - 4.6, 3, gate + math.pi - 0.9, 1.8):
        s.ob("elf_hut", q.x, q.y, (3.6, 4.4, 3.6), _rot(-o), color=(0.86, 0.86, 0.78), roof=p.get("roof", (0.3, 0.56, 0.5)))
    for k in (-1, 1):
        side = Vector((-d.y, d.x))
        q = c + d * (R - 1.6) + side * 4.2 * k
        s.ob("elf_lantern", q.x, q.y, (0.6, 2.8, 0.6))
    s.data["spawners"].append({"monster_id": p["captain"], "pos": [c.x, c.y], "radius": 2.0, "count": 1, "respawn": p.get("captain_respawn", 180.0)})
    for mob, n in p.get("guards", []):
        s.data["spawners"].append({"monster_id": mob, "pos": [c.x, c.y], "radius": R - 4.0, "count": n, "respawn": 25.0})
    _trail(s, p["id"], c, c + d * (R + 4.0))
    s.block(p["pos"], R + 3.0)


KINDS = {"fort": fort, "cabin": cabin, "camp": camp, "shrine": shrine, "dungeon": dungeon}


def build(s, places):
    s.data.setdefault("places", [])
    for p in places:
        pos = p.get("pos") or DUNGEONS[p["dungeon"]]["gate"]
        for name, poly in s.road_polys.items():
            if not name.startswith("trilha_") and poly_dist(Vector(pos), poly) < 7.0:
                print("PLACE_CONFLICT %s colado na estrada %s" % (p["id"], name))
        for river in s.rivers:
            if poly_dist(Vector(pos), river) < s.river_w * 0.5 + 8.0:
                print("PLACE_CONFLICT %s colado no rio" % p["id"])
        KINDS[p["type"]](s, p)
        rec = {"id": p["id"], "type": p["type"], "pos": [pos[0], pos[1]]}
        if p.get("dungeon") and DUNGEONS[p["dungeon"]].get("style"):
            rec["style"] = DUNGEONS[p["dungeon"]]["style"]      # porta na árvore: fica no centro (teste de distância não vale)
        s.data["places"].append(rec)
