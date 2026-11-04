"""Vegetação e detalhes de chão fora da vila (campo, floresta, montanha, pântano) — comum às zonas.

Tudo vira obstáculo/prop nos dados da sim (o jogo instancia assets/models/prop_<kind>.glb):
  tree / pine / dead_tree   árvores (sólidas; o tronco é o obstáculo)
  bush / flowers / reeds    moita, canteiro de flores, juncos (não bloqueiam)
  log / stump               tronco caído e toco (baixos, sólidos)
Cada função recebe `ob(kind, x, z, size, rot=..., solid=..., color=...)` e um `free(x, z, margin)` da zona,
e usa o próprio Random — não mexe na sequência aleatória do layout (estradas, POIs e spawners ficam iguais).
"""
import math
import random

from mathutils import Vector

MIN_TREE_H = 3.8          # m: nada de "arvorezinha" (personagem ≈ 1,7 m)
ROAD_W = 4.2

FLOWER_COLS = [(0.95, 0.5, 0.65), (0.72, 0.52, 0.92), (0.92, 0.38, 0.32), (0.98, 0.8, 0.35)]
BUSH_COLS = [(0.3, 0.52, 0.3), (0.38, 0.6, 0.32), (0.44, 0.64, 0.34)]
PINE_COLS = [(0.18, 0.38, 0.28), (0.22, 0.44, 0.3), (0.26, 0.48, 0.32)]
REED_COLS = [(0.42, 0.58, 0.3), (0.5, 0.6, 0.32)]
BARK_COLS = [(0.45, 0.33, 0.22), (0.5, 0.38, 0.26)]


BANK_KINDS = ("tree", "pine", "dead_tree", "rock", "stump", "log")


def poly_dist(p, poly):
    best = 1e9
    for i in range(len(poly) - 1):
        a, b = poly[i], poly[i + 1]
        ab = b - a
        t = max(0.0, min(1.0, (p - a).dot(ab) / max(ab.length_squared, 1e-9)))
        best = min(best, (p - (a + ab * t)).length)
    return best


def scatter(ob, free, rnd, kind, centers, size, colors, solid=True, margin=3.0, spacing=2.5, scale=(0.9, 1.3),
            rotate=True, placed=None, avoid=None):
    """Manchas: centers = [((x, z), raio, quantidade)]. `avoid` = obstáculos já postos (não encosta neles).
    Devolve as posições usadas."""
    placed = placed if placed is not None else []
    near = [(Vector(o["pos"]), max(o["size"][0], o["size"][2]) * 0.5) for o in (avoid or []) if o.get("visible", True)]
    out = []
    for (cx, cz), cr, cnt in centers:
        k = 0
        for _ in range(cnt * 6):
            if k >= cnt:
                break
            a = rnd.uniform(0, math.tau)
            r = cr * math.sqrt(rnd.random())
            x, z = cx + math.cos(a) * r, cz + math.sin(a) * r
            p = Vector((x, z))
            if not free(x, z, margin) or any((p - q).length < spacing for q in placed):
                continue
            if any((p - q).length < r + spacing * 0.6 for q, r in near):
                continue
            s = rnd.uniform(*scale)
            ob(kind, x, z, (size[0] * s, size[1] * s, size[2] * s), rnd.uniform(0, 360) if rotate else 0.0,
               solid=solid, color=colors[rnd.randrange(len(colors))])
            placed.append(p)
            out.append(p)
            k += 1
    return out


def shore(ob, rnd, rivers, lakes, roads, river_w, colors=REED_COLS, every=4.0, keep=0.6, blocked=()):
    """Juncos nas margens (dentro da faixa rasa andável), com falhas; nunca na boca de uma ponte/estrada."""
    def ok(p):
        if any(poly_dist(p, rd) < ROAD_W * 0.5 + 3.0 for rd in roads):
            return False
        return all((p - Vector(c)).length > r for c, r in blocked)
    for poly in rivers:
        acc = 0.0
        for i in range(1, len(poly) - 1):
            acc += (poly[i] - poly[i - 1]).length
            if acc < every:
                continue
            acc = 0.0
            if rnd.random() > keep:
                continue
            t = (poly[i + 1] - poly[i - 1]).normalized()
            n = Vector((-t.y, t.x)) * (1 if rnd.random() < 0.5 else -1)
            p = poly[i] + n * (river_w * 0.5 + rnd.uniform(0.3, 1.1))
            if ok(p):
                s = rnd.uniform(0.85, 1.35)
                ob("reeds", p.x, p.y, (1.2 * s, 1.25 * s, 1.2 * s), rnd.uniform(0, 360), solid=False, color=colors[rnd.randrange(len(colors))])
    for (cx, cz), r in lakes:
        n = int(math.tau * r / 3.2)
        for i in range(n):
            if rnd.random() > keep:
                continue
            a = math.tau * i / n + rnd.uniform(-0.05, 0.05)
            p = Vector((cx, cz)) + Vector((math.cos(a), math.sin(a))) * (r + rnd.uniform(0.2, 1.0))
            if ok(p):
                s = rnd.uniform(0.85, 1.4)
                ob("reeds", p.x, p.y, (1.2 * s, 1.25 * s, 1.2 * s), rnd.uniform(0, 360), solid=False, color=colors[rnd.randrange(len(colors))])


def clear_banks(obs, rivers, lakes, river_w, gap=2.0):
    """Tira o que é sólido e fecha a margem: sempre sobra um corredor de `gap` m entre a água e o obstáculo (bot não
    entra em bolsão). Não usa rnd, então o resto da zona não muda. Rochas com "y" são do anel de montanhas: ficam."""
    def near(o):
        p = Vector(o["pos"])
        r = max(o["size"][0], o["size"][2]) * 0.5 + gap
        return (any(poly_dist(p, poly) < river_w * 0.5 + r for poly in rivers)
                or any((p - Vector(c)).length < lake_r + r for c, lake_r in lakes))
    obs[:] = [o for o in obs if not (o["kind"] in BANK_KINDS and o.get("solid", True) and not o.get("y") and near(o))]


def fix_trees(obs, rnd, pine_frac=0.0, pine_cols=PINE_COLS, dead=False, dead_cols=None, region=None):
    """Pós-processo das árvores já postas: altura mínima, parte vira pinheiro (floresta/montanha) ou tudo vira
    árvore seca (ruínas). `region(x, z) -> bool` limita onde vira pinheiro."""
    for o in obs:
        if o["kind"] not in ("tree", "pine", "dead_tree") or not o.get("solid", True):
            continue
        sx, sy, sz = o["size"]
        if sy < MIN_TREE_H:
            k = MIN_TREE_H / sy * rnd.uniform(1.0, 1.12)
            o["size"] = [round(sx * k, 2), round(sy * k, 2), round(sz * k, 2)]
        x, z = o["pos"]
        if dead:
            o["kind"] = "dead_tree"
            if dead_cols:
                o["color"] = list(dead_cols[rnd.randrange(len(dead_cols))])
        elif o["kind"] == "tree" and rnd.random() < pine_frac and (region is None or region(x, z)):
            o["kind"] = "pine"
            o["size"] = [round(o["size"][0] * 1.15, 2), round(o["size"][1] * 1.2, 2), round(o["size"][2] * 1.15, 2)]
            o["color"] = list(pine_cols[rnd.randrange(len(pine_cols))])


def woodland_floor(ob, free, rnd, centers, bark=BARK_COLS, avoid=None):
    """Chão de mata: troncos caídos e tocos (baixos, sólidos) em volta dos bosques."""
    scatter(ob, free, rnd, "log", [(c, r, max(2, n // 3)) for c, r, n in centers], (3.0, 0.65, 0.7), bark,
            solid=True, margin=3.4, spacing=5.0, scale=(0.8, 1.25), avoid=avoid)
    scatter(ob, free, rnd, "stump", centers, (1.0, 0.65, 1.0), bark, solid=True, margin=3.0, spacing=4.0, scale=(0.8, 1.3), avoid=avoid)


# ---------------------------------------------------------------------------
# borda: anel de montanhas (penhascos com patamares, picos com neve, pinheiros nos patamares)
# ---------------------------------------------------------------------------
def B(x, z, y=0.0):
    return Vector((x, -z, y))


PROFILE = [(0, 0.0), (1.2, 0.07), (2.4, 0.13), (3.6, 0.2), (4.8, 0.25), (7.0, 0.27), (8.6, 0.36), (10.4, 0.45),
           (12.2, 0.53), (15.5, 0.56), (18.5, 0.74), (24, 1.0), (31, 0.86), (42, 0.72), (64, 0.5)]
PEAK = 11
LEDGE_D = (4.8, 12.2)       # início dos dois patamares


def mountain_ring(coll, name, rim_r, portal_angles, mats, ob, seed=1, snow_line=27.0, steps=240,
                  ledge_trees="pine", tree_cols=PINE_COLS, boulder_col=(0.5, 0.48, 0.48), gorge=0.07):
    """Anel facetado (triângulos, ruído por vértice). mats = [rocha, rocha escura, grama, neve ou None].
    Patamares a ~30% e ~55% da altura ganham grama e árvores (props com "y"); pedras grandes no pé.
    Os primeiros 8 m depois do andável ficam baixos: a câmera a 52° não esbarra na encosta."""
    import bmesh
    import bpy
    from mathutils import noise
    rnd = random.Random(seed + 5)
    bm = bmesh.new()
    rows = []
    # (distância a partir da borda, fração da altura). Pé fino e irregular (é o que a câmera vê de perto);
    # patamares = pares quase planos (índices LEDGE); pico no índice PEAK
    prof = PROFILE
    heights = []
    ledges = []
    for i in range(steps):
        a = math.tau * i / steps
        r0 = rim_r(a)
        g = any(abs((a - pa + math.pi) % math.tau - math.pi) < gorge for pa in portal_angles)
        h = (19.0 + 10.0 * abs(math.sin(a * 4 + 1 + seed)) + rnd.uniform(0, 5)) * (0.18 if g else 1.0)
        peak = 1.0 + 0.5 * max(0.0, math.sin(a * 11 + 0.5 + seed)) + rnd.uniform(0, 0.3)
        heights.append(h)
        row = []
        for j, (d, f) in enumerate(prof):
            nz = noise.noise(Vector((math.cos(a) * 9, math.sin(a) * 9, j * 0.9 + seed)))
            rr = r0 + d + nz * (1.1 if j < 6 else 1.8)
            hh = h * f * (peak if j == PEAK else 1.0) * (1.0 + (0.0 if j < 1 else nz * 0.18))
            if j == 0:
                hh = 0.0
            row.append(bm.verts.new(B(math.cos(a) * rr, math.sin(a) * rr, hh)))
        rows.append(row)
        if not g and i % 3 == 0:
            ledges.append((a, r0, h))
    for i in range(steps):
        r1, r2 = rows[i], rows[(i + 1) % steps]
        for j in range(len(prof) - 1):
            # quads divididos em diagonais alternadas: facetas de rocha
            if (i + j) % 2:
                bm.faces.new((r1[j], r2[j], r2[j + 1]))
                bm.faces.new((r1[j], r2[j + 1], r1[j + 1]))
            else:
                bm.faces.new((r1[j], r2[j], r1[j + 1]))
                bm.faces.new((r2[j], r2[j + 1], r1[j + 1]))
    bm.normal_update()
    rock, rock_d, grass, snow = mats
    for f in bm.faces:
        if f.normal.z < 0:
            f.normal_flip()
        c = f.calc_center_median()
        if snow is not None and c.z > snow_line * (1.0 + 0.1 * noise.noise(c * 0.15)) and f.normal.z > 0.35:
            f.material_index = 3
        elif f.normal.z > 0.8 and c.z < snow_line * 0.8:
            f.material_index = 2
        else:
            f.material_index = 1 if noise.noise(Vector((c.x * 0.08, c.y * 0.08, c.z * 0.25))) > 0.05 else 0
    me = bpy.data.meshes.new(name + "_mesh")
    bm.to_mesh(me)
    bm.free()
    o = bpy.data.objects.new(name, me)
    coll.objects.link(o)
    for m in (rock, rock_d, grass, snow if snow is not None else grass):
        me.materials.append(m)
    def ground(a, d):
        """Altura da encosta a `d` m da borda no ângulo `a` (perfil sem ruído)."""
        h = heights[int(round(a / math.tau * steps)) % steps]
        for k in range(len(prof) - 1):
            d0, f0 = prof[k]
            d1, f1 = prof[k + 1]
            if d <= d1:
                return h * (f0 + (f1 - f0) * max(0.0, d - d0) / (d1 - d0))
        return h * prof[-1][1]

    # árvores nos patamares (props com "y")
    for a, r0, h in ledges:
        for d in (LEDGE_D[0] + 0.6, LEDGE_D[1] + 1.2):
            if rnd.random() < 0.55:
                dd = d + rnd.uniform(-0.8, 0.8)
                aa = a + rnd.uniform(-0.01, 0.01)
                s = rnd.uniform(0.9, 1.4)
                ob(ledge_trees, math.cos(aa) * (r0 + dd), math.sin(aa) * (r0 + dd), (1.9 * s, 4.6 * s, 1.9 * s), 0.0, solid=False,
                   color=tree_cols[rnd.randrange(len(tree_cols))], y=round(max(0.0, ground(aa, dd) - 0.3), 2))
    # saia de pedras: blocos grandes (com contorno) meio enterrados no pé e no 1º patamar — é o que a câmera vê.
    # As do pé ficam na beirada do andável e são sólidas (a borda vira pedra, não uma parede lisa).
    for i in range(steps):
        a = math.tau * (i + rnd.uniform(0, 1)) / steps
        if any(abs((a - pa + math.pi) % math.tau - math.pi) < gorge * 0.8 for pa in portal_angles):
            continue
        r0 = rim_r(a)
        if rnd.random() < 0.85:
            d = rnd.uniform(-0.9, 1.2)
            s = rnd.uniform(1.5, 3.0)
            ob("rock", math.cos(a) * (r0 + d), math.sin(a) * (r0 + d), (1.4 * s, 1.15 * s, 1.2 * s), rnd.uniform(0, 360),
               solid=d < 0.3, color=boulder_col if rnd.random() < 0.6 else tuple(c * 0.85 for c in boulder_col),
               y=round(max(0.0, ground(a, d) - 0.35 * 1.15 * s), 2))
        if rnd.random() < 0.5:
            d = rnd.uniform(2.6, LEDGE_D[0] + 1.0)
            s = rnd.uniform(1.6, 3.0)
            ob("rock", math.cos(a) * (r0 + d), math.sin(a) * (r0 + d), (1.4 * s, 1.1 * s, 1.2 * s), rnd.uniform(0, 360), solid=False,
               color=tuple(c * 0.92 for c in boulder_col), y=round(max(0.0, ground(a, d) - 0.4 * 1.1 * s), 2))
    return o
