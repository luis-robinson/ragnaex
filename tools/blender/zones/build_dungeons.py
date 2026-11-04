"""Dungeons (mapas compartilhados pequenos): uma única forma, gerada por loop para cada entrada de places.DUNGEONS.
Chegada ao sul, três salões ligados por corredor curvo entre paredões, salão do chefe ao norte.
Com `layout` em places.DUNGEONS a forma é outra (build_graph): salões e ligações por dados, rocha sólida entre as alas.

    import sys; sys.path += [r"C:/Users/luisf/Desktop/projects/ragnaex/tools/blender/zones"]
    import build_dungeons as z; z.build(export=True)
"""
import math
import random
import bpy
from mathutils import Vector
import places
from zone_lib import Zone, poly_dist

SCALE = 1.25           # dungeons maiores para grupos: salões, distâncias e corredores (a chegada/saída não muda)
ROOMS = [(-20 * SCALE, 22 * SCALE), (20 * SCALE, 2 * SCALE), (-14 * SCALE, -18 * SCALE)]
BOSS_ROOM = (8 * SCALE, -40 * SCALE)
ROOM_R = 11.0 * SCALE
BOSS_R = 13.0 * SCALE
WALKWAY = 5.0 * 1.15
CORRIDOR_PACK_N = 2     # bando de corredor (x Balance.SPAWN_COUNT_MULT_DUNGEON no jogo)
CORRIDOR_PACK_R = 3.0
MAP_SIZE = 200.0       # era 170: cabe o vale maior
RIM_R = 76.0           # era 62


def _scaled_layout(L):
    """Cópia do layout com posições e raios dos salões, NPCs e selo multiplicados por SCALE (chegada fica onde está)."""
    out = dict(L)
    out["rooms"] = {k: dict(v, pos=(v["pos"][0] * SCALE, v["pos"][1] * SCALE), r=v["r"] * SCALE) for k, v in L["rooms"].items()}
    out["npcs"] = {k: (x * SCALE, y * SCALE, f) for k, (x, y, f) in L.get("npcs", {}).items()}
    if "door" in L:
        out["door"] = dict(L["door"], pos=(L["door"]["pos"][0] * SCALE, L["door"]["pos"][1] * SCALE))
    return out


def build_one(did, g, export):
    f = g["flip"]
    z = Zone(did, size=MAP_SIZE, rim=(RIM_R, 3.0, 2.0, 1.5), seed=g["seed"], spawn=places.DUNGEON_ARRIVE, palette={
        "cliff_rock": g["rock"], "cliff_rock_d": tuple(c * 0.75 for c in g["rock"]), "cliff_grass": tuple(c * 1.1 for c in g["rock"]),
        "hill_grass": tuple(c * 1.2 for c in g["rock"]), "road": g["floor"], "street": g["floor"],
    })
    rnd = random.Random(g["seed"])
    rooms = [(x * f, y) for x, y in ROOMS]
    boss = (BOSS_ROOM[0] * f, BOSS_ROOM[1])
    z.data["portals"].append({"id": "to_" + g["zone"], "pos": list(places.DUNGEON_EXIT), "radius": 2.0, "target_map": g["zone"],
                              "target_pos": list(places.gate_return(g)), "label": "Saída"})
    z.block(places.DUNGEON_EXIT, 7)
    z.plaza("entrada", places.DUNGEON_ARRIVE, 8.0, "road")
    path = [places.DUNGEON_ARRIVE] + rooms + [boss]
    for i, ((ax, ay), (bx, by)) in enumerate(zip(path, path[1:])):
        mid = ((ax + bx) / 2 + (by - ay) * 0.18, (ay + by) / 2 - (bx - ax) * 0.18)
        z.road("corredor_%d" % i, [(ax, ay), mid, (bx, by)], w=WALKWAY, end_clearing=False)
        # bando no meio do corredor (o maior ficou longo): bicho do salão seguinte; o 1º corredor (da chegada) fica livre
        if i >= 1:
            mob = g["rooms"][min(i, len(g["rooms"]) - 1)][0]
            z.spawner(mob, mid[0], mid[1], CORRIDOR_PACK_R, CORRIDOR_PACK_N, 30.0)
    for i, ((x, y), (mob, n)) in enumerate(zip(rooms, g["rooms"])):
        z.plaza("salao_%d" % i, (x, y), ROOM_R, "road")
        z.block((x, y), ROOM_R + 2)
        z.spawner(mob, x, y, ROOM_R - 3.0, n, 30.0)
    z.plaza("chefe", boss, BOSS_R, "road")
    z.block(boss, BOSS_R + 2)
    z.spawner(g["boss"], boss[0], boss[1], 2, 1, 240.0)
    z.ob("statue", boss[0], boss[1] - 9.0, (1.8, 3.0, 1.8), color=g["glow"])
    for q, _ in places._ring(boss, BOSS_R - 1.2, 8, 0.4):
        z.ob("pillar", q.x, q.y, (1.0, 3.6, 1.0), color=tuple(c * 1.25 for c in g["rock"]))
    # paredões entre os salões: o que não é chão vira rocha, formando corredores
    z.cliffs(snow=False)
    terraces = 0
    for _ in range(600):
        a = rnd.uniform(0, math.tau)
        r = (RIM_R - 4.0) * math.sqrt(rnd.random())
        x, y = math.cos(a) * r, math.sin(a) * r
        size = rnd.uniform(5.0, 8.0)
        if z.free(x, y, size + 3.5) and terraces < 40:
            z.terrace("paredao_%d" % terraces, (round(x, 1), round(y, 1)), round(size, 1), rnd.choice((2, 3)))
            z.block((x, y), size + 1.0)
            terraces += 1
    # tochas com a cor da dungeon ao longo do caminho e pedras soltas
    for name, poly in z.road_polys.items():
        for i in range(6, len(poly) - 4, 11):
            p, t = poly[i], (poly[i + 1] - poly[i]).normalized()
            q = p + Vector((-t.y, t.x)) * (WALKWAY * 0.5 + 0.8) * (1 if i % 2 else -1)
            z.ob("lamp", q.x, q.y, (0.4, 2.4, 0.4))
    z.scatter("rock", [((0, 0), RIM_R - 6.0, 45)], 0, (1.4, 0.9, 1.2), [tuple(c * 1.3 for c in g["rock"])], margin=3.5, spacing=3.0, scale=(0.8, 1.7))
    z.data["hangouts"] = []
    print("dungeon", did, "paredoes:", terraces)
    return z.finish(export, poi=boss, ground=g["floor"])


def _rock_fill(z, did):
    """Preenche com rocha tudo que não é chão: é isso que sela as alas. Grade hexagonal cheia (círculos se sobrepõem)."""
    step, r = 5.6, 4.0
    spots = []
    n = int(RIM_R / step) + 3             # cobre até a borda (sem anel de chão solto entre a rocha e o penhasco)
    for row in range(-n, n + 1):
        y = row * step * 0.87
        for col in range(-n, n + 1):
            x = (col + 0.5 * (row % 2)) * step
            if z.free(x, y, r + WALKWAY * 0.5 + 0.3):
                spots.append((round(x, 1), round(y, 1)))
    # anel junto à borda: a grade para 3 m antes do penhasco (e a borda ondula), sobrava um corredor em volta do mapa
    # que ligava as alas. Rocha em toda a volta, menos onde há chão de verdade (salão, corredor).
    k = int(math.tau * RIM_R / 3.2)
    for i in range(k):
        a = math.tau * i / k
        rr = z.rim_r(a) - 1.8
        x, y = math.cos(a) * rr, math.sin(a) * rr
        p = Vector((x, y))
        if any((p - c).length < cr for c, cr in z.blocked) or any(poly_dist(p, poly) <= r + WALKWAY * 0.5 + 0.3 for poly in z.road_polys.values()):
            continue
        spots.append((round(x, 1), round(y, 1)))
    for i, c in enumerate(spots):
        z.terrace("parede_%d" % i, c, r, 1)
    # uma malha só por material: centenas de objetos virariam centenas de draw calls
    objs = [o for o in z.coll.objects if o.name.startswith(z.P + "morro_")]
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.object.join()
    print("dungeon", did, "paredes:", len(spots))


def build_graph(did, g, export):
    """Dungeon ramificada: salões e ligações vêm de `g["layout"]`. Um mapa pode terminar num selo (portal para o próximo)."""
    L = _scaled_layout(g["layout"])
    z = Zone(did, size=MAP_SIZE, rim=(RIM_R, 3.0, 2.0, 1.5), seed=g["seed"], spawn=places.DUNGEON_ARRIVE, palette={
        "cliff_rock": g["rock"], "cliff_rock_d": tuple(c * 0.75 for c in g["rock"]), "cliff_grass": tuple(c * 1.1 for c in g["rock"]),
        "hill_grass": tuple(c * 1.2 for c in g["rock"]), "road": g["floor"], "street": g["floor"],
    })
    rooms = dict(L["rooms"])
    rooms["chegada"] = {"pos": places.DUNGEON_ARRIVE, "r": 8}
    # "out_": a volta nunca herda o portão da ida (PORTAL_GATES é por id)
    z.data["portals"].append({"id": "out_" + g["zone"], "pos": list(places.DUNGEON_EXIT), "radius": 2.0, "target_map": g["zone"],
                              "target_pos": list(places.gate_return(g)), "label": "Saída"})
    z.block(places.DUNGEON_EXIT, 7)
    for i, (a, b) in enumerate(L["edges"]):
        (ax, ay), (bx, by) = rooms[a]["pos"], rooms[b]["pos"]
        bend = 0.14 if i % 2 else -0.14
        mid = ((ax + bx) / 2 + (by - ay) * bend, (ay + by) / 2 - (bx - ax) * bend)
        z.road("corredor_%d" % i, [(ax, ay), mid, (bx, by)], w=WALKWAY + 1.0, end_clearing=False)
        # bando no meio do corredor: bicho de um dos salões das pontas; corredor que sai da chegada fica livre
        if "chegada" in (a, b) or "vestibulo" in (a, b):
            continue
        mobs = rooms[b].get("mobs") or rooms[a].get("mobs")
        if mobs:
            z.spawner(mobs[i % len(mobs)][0], mid[0], mid[1], CORRIDOR_PACK_R, CORRIDOR_PACK_N, 30.0)
    for name, room in rooms.items():
        x, y = room["pos"]
        z.plaza(name, (x, y), room["r"], "road")
        z.block((x, y), room["r"] + 4.3)          # raio do salão + raio da rocha: a parede encosta na borda
        for mob, n in room.get("mobs", []):
            z.spawner(mob, x, y, room["r"] - 3.0, n, 30.0)
        if "boss" in room:
            z.spawner(room["boss"], x, y, 2, 1, 240.0)
            z.ob("statue", x, y - room["r"] + 3.5, (1.8, 3.0, 1.8), color=g["glow"])
            for q, _ in places._ring((x, y), room["r"] - 1.2, 8, 0.4):
                z.ob("pillar", q.x, q.y, (1.0, 3.6, 1.0), color=tuple(c * 1.25 for c in g["rock"]))
    for nid, (x, y, face) in L.get("npcs", {}).items():
        z.npc(nid, x, y, face)
    door = L.get("door")
    if door:
        x, y = door["pos"]
        z.data["portals"].append({"id": "to_" + door["target"], "pos": [x, y], "radius": 2.0, "target_map": door["target"],
                                  "target_pos": list(places.DUNGEON_ARRIVE), "label": door["label"]})
        z.block(door["pos"], 5)
        for k in (-1, 1):
            z.ob("pillar", x + 3.0 * k, y - 0.5, (1.1, 4.2, 1.1), color=g["glow"])
    z.cliffs(snow=False)
    _rock_fill(z, did)
    for name, poly in z.road_polys.items():
        for i in range(4, len(poly) - 3, 9):
            p, t = poly[i], (poly[i + 1] - poly[i]).normalized()
            q = p + Vector((-t.y, t.x)) * (WALKWAY * 0.5 + 0.1) * (1 if i % 2 else -1)
            if all((q - Vector(r["pos"])).length > r["r"] + 1.0 for r in rooms.values()):     # postes só nos corredores
                z.ob("lamp", q.x, q.y, (0.4, 2.4, 0.4))
    z.data["hangouts"] = []
    boss_pos = next(r["pos"] for r in L["rooms"].values() if "boss" in r)
    return z.finish(export, poi=boss_pos, ground=g["floor"])


def build(export=False, only=None):
    for did, g in places.DUNGEONS.items():
        if only and did not in only:
            continue
        (build_graph if "layout" in g else build_one)(did, g, export)
