"""Folga da Aldeia dos Xamãs a partir de data/zones/field_grove.json (mesma regra de colisor do MapGeometry).

    python village_measure.py <json> <cx> <cz> <raio> [entradas "x,z;x,z;..."] [alvos "x,z;..."]

Imprime: nº de sólidos no disco, pares com vão entre 0,3 e 4,0 m (passagem estreita), e o gargalo (largura da passagem
mais larga que liga cada entrada ao centro/alvos: maior d tal que um disco de diâmetro d passa).
"""
import json
import math
import sys

CIRCLE = {"tree", "rock", "pillar", "well", "fountain", "lamp", "statue", "pine", "dead_tree", "stump", "hill"}


def load(path):
    d = json.load(open(path, encoding="utf-8"))
    cols = []
    for o in d["obstacles"]:
        if not o.get("solid", True) or o["kind"] in ("water",):
            continue
        sx, sz = o["size"][0], o["size"][2]
        cols.append({"circle": o["kind"] in CIRCLE, "x": o["pos"][0], "z": o["pos"][1], "cr": max(sx, sz) * 0.5,
                     "hx": sx * 0.5, "hz": sz * 0.5, "rot": math.radians(o.get("rot", 0.0)), "kind": o["kind"]})
    return d, cols


def dist(c, x, z):
    """Distância de (x, z) à borda do colisor (negativa dentro)."""
    dx, dz = x - c["x"], z - c["z"]
    if c["circle"]:
        return math.hypot(dx, dz) - c["cr"]
    cs, sn = math.cos(c["rot"]), math.sin(c["rot"])
    lx, lz = abs(dx * cs - dz * sn) - c["hx"], abs(dx * sn + dz * cs) - c["hz"]
    return math.hypot(max(lx, 0.0), max(lz, 0.0)) + min(max(lx, lz), 0.0)


def main():
    path, cx, cz, R = sys.argv[1], float(sys.argv[2]), float(sys.argv[3]), float(sys.argv[4])
    pts = lambda s: [tuple(float(v) for v in q.split(",")) for q in s.split(";") if q]
    entries = pts(sys.argv[5]) if len(sys.argv) > 5 else []
    targets = pts(sys.argv[6]) if len(sys.argv) > 6 else [(cx, cz)]
    d, cols = load(path)
    near = [c for c in cols if math.hypot(c["x"] - cx, c["z"] - cz) < R + 12.0]
    inside = [c for c in near if math.hypot(c["x"] - cx, c["z"] - cz) - (c["cr"] if c["circle"] else 0.0) < R]
    print("solidos no disco r=%.1f: %d  (%s)" % (R, len(inside), ", ".join("%s %d" % (k, sum(1 for c in inside if c["kind"] == k))
                                                                         for k in sorted({c["kind"] for c in inside}))))
    # pares estreitos (só círculos: tudo na aldeia é círculo)
    narrow = []
    for i, a in enumerate(inside):
        for b in near:
            if b is a or (b in inside and id(b) < id(a)):
                continue
            g = math.hypot(a["x"] - b["x"], a["z"] - b["z"]) - a["cr"] - b["cr"]
            if 0.3 < g < 4.0:
                dd = math.hypot(a["x"] - b["x"], a["z"] - b["z"])
                t = (a["cr"] + g * 0.5) / dd
                mx, mz = a["x"] + (b["x"] - a["x"]) * t, a["z"] + (b["z"] - a["z"]) * t
                if min(dist(c, mx, mz) for c in near) > 0.05:      # meio do vao livre (senao e a mesma peca: fila de circulos)
                    narrow.append((g, a, b))
    narrow.sort(key=lambda t: t[0])
    print("pares com vao 0,3-4,0 m: %d   (< 0,9 m = nao passa: %d; 0,9-2 m: %d; 2-3 m: %d; 3-4 m: %d)" % (
        len(narrow), sum(1 for t in narrow if t[0] < 0.9), sum(1 for t in narrow if 0.9 <= t[0] < 2), sum(1 for t in narrow if 2 <= t[0] < 3),
        sum(1 for t in narrow if t[0] >= 3)))
    for g, a, b in narrow[:14]:
        print("   %.2f m  %s(%.1f,%.1f r%.2f) - %s(%.1f,%.1f r%.2f)" % (g, a["kind"], a["x"], a["z"], a["cr"], b["kind"], b["x"], b["z"], b["cr"]))
    # mapa de folga numa grade
    step = 0.25
    n = int((R + 8.0) * 2 / step) + 1
    x0, z0 = cx - (R + 8.0), cz - (R + 8.0)
    clr = [[0.0] * n for _ in range(n)]
    for j in range(n):
        z = z0 + j * step
        for i in range(n):
            x = x0 + i * step
            clr[j][i] = min((dist(c, x, z) for c in near), default=99.0)
    free = [(i, j) for j in range(n) for i in range(n) if math.hypot(x0 + i * step - cx, z0 + j * step - cz) < R and clr[j][i] > 0.45]
    tot = sum(1 for j in range(n) for i in range(n) if math.hypot(x0 + i * step - cx, z0 + j * step - cz) < R)
    print("chao andavel (raio 0,45) no disco: %.0f m2 de %.0f m2 (%.0f%%); com folga >= 2 m (corredor de 4 m): %.0f m2; >= 2,5 m: %.0f m2" % (
        len(free) * step * step, tot * step * step, 100.0 * len(free) / tot,
        sum(1 for i, j in free if clr[j][i] >= 2.0) * step * step, sum(1 for i, j in free if clr[j][i] >= 2.5) * step * step))

    def cell(p):
        return (int(round((p[0] - x0) / step)), int(round((p[1] - z0) / step)))

    def snap(p):
        """Célula livre mais folgada a até 2 m do ponto."""
        ci, cj = cell(p)
        best = None
        for dj in range(-8, 9):
            for di in range(-8, 9):
                i, j = ci + di, cj + dj
                if 0 <= i < n and 0 <= j < n and (best is None or clr[j][i] > clr[best[1]][best[0]]):
                    best = (i, j)
        return best

    def widest(a, b):
        """Largura do gargalo no melhor caminho a→b (caminho de máxima folga mínima; busca binária + flood)."""
        lo, hi = 0.0, min(clr[a[1]][a[0]], clr[b[1]][b[0]])
        for _ in range(12):
            mid = (lo + hi) * 0.5
            seen = {a}
            stack = [a]
            ok = False
            while stack:
                i, j = stack.pop()
                if (i, j) == b:
                    ok = True
                    break
                for di, dj in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    q = (i + di, j + dj)
                    if 0 <= q[0] < n and 0 <= q[1] < n and q not in seen and clr[q[1]][q[0]] >= mid:
                        seen.add(q)
                        stack.append(q)
            if ok:
                lo = mid
            else:
                hi = mid
        return lo * 2.0

    worst = 99.0
    for e in entries:
        for t in targets:
            w = widest(snap(e), snap(t))
            worst = min(worst, w)
            print("   entrada (%.1f, %.1f) -> alvo (%.1f, %.1f): gargalo %.2f m" % (e[0], e[1], t[0], t[1], w))
    if entries:
        print("GARGALO (pior entrada->alvo): %.2f m" % worst)


main()
