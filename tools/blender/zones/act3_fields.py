"""Peças comuns dos dois campos do Ato III parte 1 (Vinhas do Perfume e Avenida do Cortejo; GDD ato3-excesso-45-50 §2):
borda de morros de vinhedo, fileiras de videira em lote, pontos do Festim Sem Fim, conta de vivos e a enchente que prova
que tudo é alcançável a pé (rio com vão só nas pontes, como a sim). As peças da festa (palco, máscara, banquete,
barricada, casa) vêm de build_lumeria: os campos falam a mesma língua da cidade.
"""
import math

from mathutils import Vector

import nature
import zone_lib
from zone_lib import along, poly_dist

SPAWN_MULT = 1.6                     # Balance.SPAWN_COUNT_MULT (count > 1)
ESCORT = {"ceremony_master": 3, "first_dancer": 2, "choir_maestro": 3, "parade_alpha": 2}      # MonsterDef.escort do Ato III
VINE = [(0.5, 0.36, 0.6), (0.44, 0.6, 0.4), (0.56, 0.42, 0.64)]


class _NoOb:
    """`z` de mentira para peça de estágio (lote com tag): a peça entra no lote, o colisor não (enfeite de conquista nunca colide)."""
    def ob(self, *a, **k):
        return None


NO_OB = _NoOb()


def H(r, deg, c=(0.0, 0.0)):
    return (round(c[0] + math.cos(math.radians(deg)) * r, 2), round(c[1] + math.sin(math.radians(deg)) * r, 2))


def polar(z, deg, inset):
    a = math.radians(deg)
    r = z.rim_r(a) - inset
    return (round(math.cos(a) * r, 1), round(math.sin(a) * r, 1))


def vine_hills(z, rock_cols=((0.5, 0.36, 0.6), (0.44, 0.32, 0.54), (0.46, 0.58, 0.4)), boulder=(0.72, 0.68, 0.6)):
    """Borda: anel de morros em patamares com moitas de videira (o mesmo de Lumeria) + corrente de colisão."""
    mats = [z.M["cliff_rock"], z.M["cliff_rock_d"], z.M["cliff_grass"], None]
    nature.mountain_ring(z.coll, z.P + "penhascos", z.rim_r, z.portal_angles, mats, z.ob, seed=z.seed, ledge_trees="bush",
                         tree_cols=list(rock_cols), boulder_col=boulder)
    for i in range(0, 180, 2):
        a = math.tau * (i + 1) / 180
        r0 = z.rim_r(a) + 3.5
        seg = r0 * math.tau / 180 * 2 * 1.25
        z.ob("cliff", math.cos(a) * r0, math.sin(a) * r0, (seg, 6.0, 7.0), along(-math.sin(a), math.cos(a)), visible=False)


def vine_rows(d, guide, rows, gap=2.7, seg=3.2, y0=0.0, ok=None, g="vinha", cols=VINE, h=0.78):
    """Fileiras de videira paralelas a uma curva-guia (de cima: faixas paralelas roxas e verdes, com falhas). Só visual,
    baixas (a câmera é alta: nada tapa o boneco). Devolve quantas moitas pôs."""
    ms = [d.m("videira_%d" % i, c) for i, c in enumerate(cols)]
    stake = d.m("videira_estaca", (0.6, 0.5, 0.4))
    poly = zone_lib.catmull(guide, seg)
    n = len(poly)
    count = 0
    for k in range(rows):
        off = (k - (rows - 1) * 0.5) * gap
        pts = []
        for i, p in enumerate(poly):
            t = (poly[min(n - 1, i + 1)] - poly[max(0, i - 1)]).normalized()
            pts.append(p + Vector((-t.y, t.x)) * off)
        for i in range(n - 1):
            if (i + k * 3) % 7 == 6:
                continue                                      # falha: passagem entre as fileiras
            a, b = pts[i], pts[i + 1]
            q = (a + b) * 0.5
            if ok is not None and not ok(q.x, q.y):
                continue
            t = b - a
            rot = along(t.x, t.y)
            m = ms[(i // 2 + k) % len(ms)]
            j = ((i * 7 + k * 5) % 5) * 0.04                  # altura e grossura variam: a fileira não é uma régua
            s0 = a + t * 0.06
            # sebe deitada de seis lados (rot + 90: o eixo do cilindro tombado corre ao longo da fileira)
            d.cyl(g, m, (s0.x, s0.y), 0.4 + j, 0.36 + j * 0.5, t.length * 0.88, y0 + 0.42 + j, 6, rot + 90.0, tilt=(90, 0))
            if (i + k) % 3 == 0:                              # rebento/cacho por cima, na outra cor
                d.box(g, ms[(i + k + 1) % len(ms)], (a.x * 0.35 + b.x * 0.65, a.y * 0.35 + b.y * 0.65), (0.7, 0.26, 0.5), rot + 20.0, y0 + h * 0.86 + j)
            if i % 2 == 0:
                d.cyl(g, stake, (a.x, a.y), 0.06, 0.05, 1.3, y0, 4)
            count += 1
    return count


def live_count(z, extra=0):
    """Vivos com o x1,6 do jogo e as escoltas (GDD §11: campo <= 140)."""
    n = extra
    for s in z.data["spawners"]:
        c = s["count"]
        n += (int(math.ceil(c * SPAWN_MULT)) if c > 1 else 1) + ESCORT.get(s["monster_id"], 0) * (int(math.ceil(c * SPAWN_MULT)) if c > 1 else 1)
    return n


def event_points(z, points, widths, hub=(0.0, 0.0), bosses=()):
    """Pontos do Festim Sem Fim (RoadEventSystem): [(tipo, estrada, fração, lado, monstro)] -> data["events"], à beira da
    estrada. Regras do `_check_road_events`: >= 40 m do hub, >= 25 m de portal/chegada/NPC/chefe, >= 30 m entre si, chão
    livre e seco. Se o ponto pedido não serve, anda pela estrada e troca de margem; sem ponto = EVENT_CONFLICT."""
    data = z.data
    data["events"] = []
    obs = [o for o in data["obstacles"] if o.get("solid", True) and o["kind"] != "cliff"]
    marks = [p["pos"] for p in data["portals"]] + [data["spawn"]]
    for p in data.get("future_portals", []):
        marks += [p["pos"], p["arrive"]]

    def why(q):
        far = lambda c, r: (q - Vector(c[:2])).length >= r
        if (q - Vector(hub)).length < 40.0:
            return "hub"
        if not all(far(m, 25.0) for m in marks):
            return "portal/chegada"
        if not all(far(v, 25.0) for v in data["npcs"].values()):
            return "npc"
        if not all(far(b, 25.0) for b in bosses):
            return "chefe"
        if not all(far(o["pos"], max(o["size"][0], o["size"][2]) * 0.5 + 1.6) for o in obs):
            return "obstaculo"
        if any(poly_dist(q, rv) < z.river_ws[k] * 0.5 + 2.5 for k, rv in enumerate(z.rivers)):
            return "agua"
        if not all(far(w["pos"], w["r"] + 2.5) for w in data["water"] if w.get("kind") == "lake"):
            return "agua"
        if not all(far(e["pos"], 30.0) for e in data["events"]):
            return "outro ponto"
        return ""

    for kind, road, frac, side, mob in points:
        poly = z.road_polys[road]
        off = widths.get(road, zone_lib.ROAD_W) * 0.5 + 1.3
        found, first = None, ""
        for df in (0.0, 0.04, -0.04, 0.08, -0.08, 0.12, -0.12, 0.16, -0.16, 0.2, -0.2):
            for sd in (side, -side):
                i = max(1, min(len(poly) - 2, int((frac + df) * (len(poly) - 1))))
                t = (poly[i + 1] - poly[i - 1]).normalized()
                q = poly[i] + Vector((-t.y, t.x)) * sd * off
                w = why(q)
                if w == "":
                    found = q
                    break
                first = first or w
            if found is not None:
                break
        if found is None:
            print("EVENT_CONFLICT %s em %s: nenhum ponto serve (%s)" % (kind, road, first))
            continue
        data["events"].append({"kind": kind, "pos": [round(found.x, 2), round(found.y, 2)], "mob": mob, "road": road})
    return data["events"]


def walk_check(data, extra=None, step=0.5, pad=0.45, half=130.0):
    """Enchente a partir da chegada numa grade de 0,5 m (colisores = caixas giradas + rio sólido com vão só nas pontes +
    lagos): NPCs, spawners, portais, chegadas, eventos, pontos de bot e POIs têm de ser alcançáveis a pé."""
    N = int(2 * half / step)
    blocked = bytearray(N * N)
    idx = lambda x, z: (int((z + half) / step)) * N + int((x + half) / step)
    for o in data["obstacles"]:
        if not o.get("solid", True):
            continue
        cx, cz = o["pos"]
        sx, sz = o["size"][0] * 0.5 + pad, o["size"][2] * 0.5 + pad
        a = math.radians(o.get("rot", 0.0))
        ca, sa = math.cos(a), math.sin(a)
        R = math.hypot(sx, sz)
        x0, x1 = int((cx - R + half) / step), int((cx + R + half) / step) + 1
        z0, z1 = int((cz - R + half) / step), int((cz + R + half) / step) + 1
        for iz in range(max(0, z0), min(N, z1)):
            for ix in range(max(0, x0), min(N, x1)):
                dx, by = ix * step - half + step * 0.5 - cx, -(iz * step - half + step * 0.5 - cz)
                if abs(dx * ca + by * sa) <= sx and abs(-dx * sa + by * ca) <= sz:
                    blocked[iz * N + ix] = 1
    bridges = data.get("bridges", [])
    for w in data["water"]:
        if w.get("kind") != "river":
            continue
        pts = [Vector(p) for p in w["pts"]]
        hw = w["w"] * 0.5 + pad * 0.5
        for i in range(len(pts) - 1):
            a, b = pts[i], pts[i + 1]
            x0, x1 = int((min(a.x, b.x) - hw + half) / step), int((max(a.x, b.x) + hw + half) / step) + 1
            z0, z1 = int((min(a.y, b.y) - hw + half) / step), int((max(a.y, b.y) + hw + half) / step) + 1
            for iz in range(max(0, z0), min(N, z1)):
                for ix in range(max(0, x0), min(N, x1)):
                    p = Vector((ix * step - half + step * 0.5, iz * step - half + step * 0.5))
                    if zone_lib.seg_dist(p, a, b) > hw:
                        continue
                    on_bridge = False
                    for br in bridges:
                        ra = math.radians(br["rot"])
                        t = Vector((math.cos(ra), -math.sin(ra)))
                        v = p - Vector(br["pos"])
                        if abs(v.dot(t)) <= br["len"] * 0.5 + 1.0 and abs(v.dot(Vector((-t.y, t.x)))) <= br["w"] * 0.5 - 0.6:
                            on_bridge = True
                            break
                    if not on_bridge:
                        blocked[iz * N + ix] = 1
    seen = bytearray(N * N)
    st = [idx(*data["spawn"])]
    seen[st[0]] = 1
    while st:
        i = st.pop()
        for j in (i - 1, i + 1, i - N, i + N):
            if 0 <= j < N * N and not seen[j] and not blocked[j]:
                seen[j] = 1
                st.append(j)
    pts = {"npc:" + k: v[:2] for k, v in data["npcs"].items()}
    pts.update({"poi:" + k: v for k, v in data.get("poi", {}).items()})
    pts.update({"hang%d" % i: h for i, h in enumerate(data["hangouts"])})
    pts.update({"mob%d:%s" % (i, s["monster_id"]): s["pos"] for i, s in enumerate(data["spawners"])})
    pts.update({"event%d" % i: e["pos"] for i, e in enumerate(data.get("events", []))})
    pts.update({"portal:" + p["id"]: p["pos"] for p in data["portals"]})
    pts.update({"future:" + p["id"]: p["arrive"] for p in data.get("future_portals", [])})
    pts.update({"future_pos:" + p["id"]: p["pos"] for p in data.get("future_portals", [])})
    pts.update({"gather%d" % i: gh["pos"] for i, gh in enumerate(data.get("gather_hint", []))})
    pts.update({"boss:" + b["id"]: b["pos"] for b in data.get("world_boss_hint", [])})
    pts.update(extra or {})
    bad = [k for k, v in pts.items() if not seen[idx(v[0], v[1])]]
    print("WALK_CHECK %s: %d pontos, inalcancaveis: %s" % (data["zone"], len(pts), bad or "nenhum"))
    # spawner: quanto do disco é chão alcançável (um bando preso num bolsão é pior que um ponto preso)
    thin = []
    for i, s in enumerate(data["spawners"]):
        r, tot, ok = s["radius"], 0, 0
        for k in range(24):
            for rr in (0.5, 1.0):
                q = (s["pos"][0] + math.cos(math.tau * k / 24) * r * rr, s["pos"][1] + math.sin(math.tau * k / 24) * r * rr)
                tot += 1
                ok += 1 if seen[idx(q[0], q[1])] else 0
        if ok < tot * 0.6:
            thin.append("%d:%s %.0f%%" % (i, s["monster_id"], 100.0 * ok / tot))
    print("WALK_CHECK spawners com menos de 60%% do disco livre: %s" % (thin or "nenhum"))
    return bad
