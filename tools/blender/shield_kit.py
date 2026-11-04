"""Escudos do kit: um modelo por escudo, com volume e silhueta próprios (referências em reference/shields/mmo_notes.md).
Cada modelo tem corpo, relevo e foco em alturas diferentes e pelo menos uma peça que rompe o contorno.
Eixos do escudo: X lateral, Z altura, -Y frente. Os ícones são fotos destes modelos (tools/icons/shield_icons.tscn).
"""
import math
import bpy
import bmesh
from mathutils import Vector


def _mesh(name, verts, faces, material):
    me = bpy.data.meshes.new(name)
    me.from_pydata(verts, [], faces)
    bm = bmesh.new()
    bm.from_mesh(me)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(me)
    bm.free()
    o = bpy.data.objects.new(name, me)
    bpy.context.collection.objects.link(o)
    o.data.materials.append(material)
    return o


def blade(name, a, b, w, t, material, belly=0.35, y=-0.02):
    """Lâmina facetada de `a` até `b` (x, z), para pena, raio, presa e cristal. w = largura, t = espessura."""
    a, b = Vector(a), Vector(b)
    d = b - a
    side = Vector((-d.y, d.x)).normalized()
    m = a + d * belly
    p = lambda v, yy: (v.x, y + yy, v.y)
    verts = [p(a, 0), p(b, 0), p(m + side * w * 0.5, 0), p(m - side * w * 0.5, 0), p(m, -t), p(m, t * 0.6)]
    return _mesh(name, verts, [(0, 2, 4), (2, 1, 4), (1, 3, 4), (3, 0, 4), (2, 0, 5), (1, 2, 5), (3, 1, 5), (0, 3, 5)], material)


def plate(name, outline, front, back, material, ox=0.0, oz=0.0):
    """Placa abaulada a partir do centro: borda em y=0, meio em `front` (frente) e `back` (atrás)."""
    n = len(outline)
    verts = [(ox + x, 0.0, oz + z) for x, z in outline] + [(ox, front, oz), (ox, back, oz)]
    faces = [(i, n, (i + 1) % n) for i in range(n)] + [((i + 1) % n, n + 1, i) for i in range(n)]
    return _mesh(name, verts, faces, material)


def mirror(half, s=1.0, sx=None):
    sx = s if sx is None else sx
    return [(x * sx, z * s) for x, z in half] + [(-x * sx, z * s) for x, z in reversed(half) if x > 0.0001]


def ring(name, c, r, thick, material, segs=14, y=-0.05, tube=None):
    pts = [(c[0] + math.cos(math.tau * i / segs) * r, c[1] + math.sin(math.tau * i / segs) * r) for i in range(segs + 1)]
    return [band(name, pts, thick * 2.6, thick * 1.1, material, y, 1.0)]


def _back(ck, name, mats, h=0.18, dark=None):
    """Braçadeira atrás: de costas o escudo não é uma chapa vazia."""
    dark = dark or ck.mat("m_escudo_breu", (0.03, 0.03, 0.05), 0.8)     # escudo vazado passa a própria cor
    return [ck.box(name + "_alca", (0.05, 0.03, h * 2), (0, 0.05, 0), dark, 0.008),
            ck.box(name + "_alca2", (0.2, 0.025, 0.05), (0, 0.045, 0), dark, 0.008)]


def bastiao(ck, name, mats):
    """Muralha: ameias, torres dos lados e um portão de verdade, com grade, abaixo da linha do elmo."""
    t, t2, gold = mats["tint"], mats["tint2"], mats["trim"]
    S = 0.42
    half = [(0, 1.0), (0.3, 1.0), (0.52, 1.0), (0.6, 0.8), (0.56, -0.5), (0.3, -0.86), (0, -1.0)]
    out = mirror(half, S)
    parts = [plate(name + "_aro", [(x * 1.07, z * 1.04) for x, z in out], -0.03, 0.03, t2),
             plate(name + "_corpo", out, -0.075, 0.02, t)]
    for k in (-1, 1):
        parts.append(ck.box(name + "_contra_%d" % k, (0.09, 0.07, S * 1.5), (k * S * 0.68, -0.05, S * 0.12), gold, 0.012))
        parts.append(blade(name + "_torre_%d" % k, (k * S * 0.68, S * 0.84), (k * S * 0.68, S * 1.3), 0.13, 0.06, t2, 0.2, -0.05))
    for i in range(4):
        parts.append(ck.box("%s_ameia_%d" % (name, i), (0.085, 0.05, 0.085), (S * (-0.45 + i * 0.3), -0.07, S * 0.55), t2, 0.008))
    parts.append(ck.box(name + "_muro", (S * 1.16, 0.04, 0.06), (0, -0.095, S * 0.42), gold, 0.008))
    parts.append(plate(name + "_portao", mirror([(0, 0.36), (0.26, 0.3), (0.36, 0.08), (0.36, -0.62), (0, -0.62)], S), -0.1, -0.03, t2))
    parts.append(plate(name + "_vao", mirror([(0, 0.2), (0.15, 0.14), (0.22, 0.0), (0.22, -0.56), (0, -0.56)], S), -0.118, -0.06, ck.mat("m_escudo_breu", (0.03, 0.03, 0.05), 0.8)))
    for x in (-0.11, 0.0, 0.11):
        parts.append(ck.box("%s_grade_%g" % (name, x), (0.022, 0.02, S * 0.7), (S * x, -0.125, -S * 0.2), gold, 0.002))
    parts.append(gem(name + "_foco", (0, S * 0.3), 0.075, jewel(ck, "azul"), -0.13, 8))
    return parts + _back(ck, name, mats)


def juramento(ck, name, mats):
    """Kite do juramento: a cruz passa do contorno; é silhueta, não desenho."""
    t, t2, gold = mats["tint"], mats["tint2"], mats["trim"]
    S = 0.38
    half = [(0, 0.8), (0.3, 0.84), (0.7, 0.78), (0.74, 0.3), (0.5, -0.32), (0.22, -0.72), (0, -1.05)]
    out = mirror(half, S)
    parts = [plate(name + "_aro", [(x * 1.09, z * 1.06) for x, z in out], -0.03, 0.03, t2),
             plate(name + "_corpo", out, -0.08, 0.02, t),
             ck.box(name + "_cruz_v", (0.085, 0.05, S * 2.5), (0, -0.095, -S * 0.02), gold, 0.014),
             ck.box(name + "_cruz_h", (S * 2.0, 0.05, 0.085), (0, -0.095, S * 0.32), gold, 0.014)]
    for k in (-1, 1):
        parts.append(blade(name + "_ponta_%d" % k, (k * S * 0.98, S * 0.32), (k * S * 1.3, S * 0.32), 0.13, 0.05, gold, 0.2, -0.09))
    parts.append(blade(name + "_ponta_alta", (0, S * 1.2), (0, S * 1.5), 0.13, 0.05, gold, 0.2, -0.09))
    parts.append(gem(name + "_foco", (0, S * 0.32), 0.07, jewel(ck, "azul"), -0.13, 8, 1.1))
    for k in (-1, 1):
        parts.append(scroll(name + "_vol_%d" % k, (k * S * 0.42, -S * 0.1), 0.085, 1.2, 1.3, 0.042, gold, k, -0.07))
    return parts + _back(ck, name, mats)


def asa(ck, name, mats):
    """Asa de verdade: borda de ataque em ouro, penas caindo em paralelo e a outra asa fechada."""
    t, t2, gold = mats["tint"], mats["tint2"], mats["trim"]
    S = 0.36
    half = [(0, 0.86), (0.4, 0.6), (0.46, 0.1), (0.3, -0.5), (0, -1.05)]
    out = mirror(half, S)
    parts = [plate(name + "_aro", [(x * 1.14, z * 1.06) for x, z in out], -0.03, 0.03, gold),
             plate(name + "_corpo", out, -0.09, 0.02, t)]
    edge = [(0.16, 0.62), (0.5, 1.02), (0.9, 1.16), (1.32, 0.98)]
    parts.append(band(name + "_borda", [(x * S, z * S) for x, z in edge], 0.12, 0.05, gold, -0.06, 0.3))
    for i in range(5):
        k = i / 4
        x = S * (0.22 + 1.0 * k)
        z = S * (0.72 + 0.46 * math.sin(k * 3.0))
        ln = S * (1.0 + 0.62 * k + (0.14 if i % 2 else 0.0))
        parts.append(blade("%s_pena_%d" % (name, i), (x, z), (x + S * 0.16, z - ln), 0.27, 0.04, t, 0.62, -0.025 - i * 0.003))
        parts.append(blade("%s_ponta_%d" % (name, i), (x + S * 0.12, z - ln * 0.86), (x + S * 0.16, z - ln * 1.05), 0.07, 0.03, gold, 0.3, -0.05))
    for i in range(3):
        parts.append(blade("%s_fech_%d" % (name, i), (-S * 0.18, S * (0.56 - i * 0.26)), (-S * (0.66 - i * 0.08), S * (-0.14 - i * 0.28)), 0.1, 0.04, t2 if i % 2 else t, 0.6, -0.025))
    parts.append(gem(name + "_foco", (0, S * 0.2), 0.075, jewel(ck, "azul"), -0.11, 6, 1.5))
    return parts + _back(ck, name, mats)


def sol(ck, name, mats):
    """Sol de guerra: raios soltos em volta de um brasão pequeno; os vazios entre os raios é que leem de longe."""
    t, t2, gold = mats["tint"], mats["tint2"], mats["trim"]
    S = 0.2
    hexa = [(math.cos(math.tau * i / 8 + 0.39) * S * 1.3, math.sin(math.tau * i / 8 + 0.39) * S * 1.3) for i in range(8)]
    parts = [plate(name + "_aro", [(x * 1.16, z * 1.16) for x, z in hexa], -0.04, 0.03, gold),
             plate(name + "_corpo", hexa, -0.095, 0.02, t)]
    for i in range(11):
        a = math.radians(90 + (i - 5) * 30)
        d = Vector((math.cos(a), math.sin(a)))
        ln = 2.5 if i % 2 == 0 else 1.9
        if i == 5:
            ln = 2.9
        ln *= 0.72 if d.x < -0.3 else 1.0
        parts.append(blade("%s_raio_%d" % (name, i), d * S * 1.15, d * S * ln, 0.1, 0.05, gold if i % 2 == 0 else t2, 0.28, -0.03))
    for k in (-1, 1):
        parts.append(blade(name + "_cauda_%d" % k, (k * S * 0.24, -S * 1.1), (k * S * 0.9, -S * 3.2), 0.18, 0.07, t, 0.2, -0.03))
        parts.append(blade(name + "_cauda2_%d" % k, (k * S * 0.2, -S * 1.1), (k * S * 0.66, -S * 2.6), 0.08, 0.09, gold, 0.25, -0.05))
    parts.append(gem(name + "_foco", (0, 0), 0.09, jewel(ck, "rubi"), -0.13, 8, 1.0))
    for i in range(4):
        a = math.tau * i / 4 + 0.785
        parts.append(scroll("%s_vol_%d" % (name, i), (math.cos(a) * S * 0.72, math.sin(a) * S * 0.72), 0.06, a, 1.2, 0.036, gold, 1, -0.085))
    for k in (-1, 1):
        parts.append(blade(name + "_cenho_%d" % k, (k * S * 0.06, S * 0.42), (k * S * 0.92, S * 0.92), 0.12, 0.05, gold, 0.3, -0.11))
    return parts + _back(ck, name, mats, 0.14)


def presa(ck, name, mats):
    """Fera: crânio longo, chifres, mandíbula aberta e presas; o miolo é vazado."""
    t, t2, gold = mats["tint"], mats["tint2"], mats["trim"]
    S = 0.36
    half = [(0, 0.8), (0.24, 0.74), (0.52, 0.42), (0.58, 0.06), (0.4, -0.3), (0.3, -0.44), (0.14, -0.5), (0, -0.4)]
    out = mirror(half, S)
    parts = [plate(name + "_aro", [(x * 1.08, z * 1.07) for x, z in out], -0.03, 0.03, t2),
             plate(name + "_corpo", out, -0.1, 0.02, t)]
    for k in (-1, 1):
        parts.append(blade(name + "_chifre_a%d" % k, (k * S * 0.48, S * 0.56), (k * S * 1.02, S * 1.12), 0.15, 0.06, t2, 0.25))
        parts.append(blade(name + "_chifre_b%d" % k, (k * S * 1.0, S * 1.08), (k * S * 0.84, S * 1.62), 0.09, 0.04, t2, 0.15))
        parts.append(gem(name + "_olho_%d" % k, (k * S * 0.28, S * 0.22), 0.05, jewel(ck, "rubi"), -0.1, 6, 0.7))
        for j, (x, ln) in enumerate(((0.42, 0.56), (0.25, 0.8))):
            parts.append(blade("%s_presa_%d_%d" % (name, k, j), (k * S * x, -S * 0.34), (k * S * x * 0.88, -S * (0.34 + ln)), 0.075, 0.035, gold, 0.2, -0.05))
        parts.append(blade(name + "_queixo_%d" % k, (k * S * 0.36, -S * 0.52), (k * S * 0.12, -S * 1.42), 0.12, 0.05, t, 0.2))
    parts.append(blade(name + "_focinho", (0, S * 0.78), (0, -S * 0.2), 0.16, 0.08, t2, 0.45, -0.075))
    return parts + _back(ck, name, mats)


def relicario(ck, name, mats):
    """Relicário: a cruz é o corpo, com auréola em cima e lanterna de luz pendurada no centro."""
    t, t2, gold = mats["tint"], mats["tint2"], mats["trim"]
    S = 0.44
    half = [(0, 1.0), (0.2, 1.0), (0.22, 0.46), (0.74, 0.5), (0.8, 0.26), (0.24, 0.1), (0.28, -0.7), (0, -1.08)]
    out = mirror(half, S)
    parts = [plate(name + "_aro", [(x * 1.08, z * 1.05) for x, z in out], -0.03, 0.03, gold),
             plate(name + "_corpo", out, -0.075, 0.02, t)]
    parts += ring(name + "_aureola", (0, S * 1.05), S * 0.3, 0.014, gold, 16, -0.015, ck.tube)
    parts += ring(name + "_lanterna", (0, S * 0.32), S * 0.3, 0.014, gold, 12, -0.085, ck.tube)
    parts.append(gem(name + "_foco", (0, S * 0.32), 0.075, jewel(ck, "branco"), -0.1, 8, 1.3))
    for k in (-1, 1):
        parts.append(scroll(name + "_vol_%d" % k, (k * S * 0.55, S * 0.34), 0.06, 0.0, 1.2, 0.036, gold, k, -0.07))
    for k in (-1, 1):
        parts.append(blade(name + "_haste_%d" % k, (k * S * 0.76, S * 0.5), (k * S * (1.12 if k > 0 else 0.86), S * 0.62), 0.09, 0.04, t2, 0.25))
    parts.append(blade(name + "_ponta", (0, -S * 1.0), (0, -S * 1.46), 0.1, 0.05, gold, 0.25))
    return parts + _back(ck, name, mats)


def prisma(ck, name, mats):
    """Prisma: feixe de cristais soltos, sem placa nenhuma à vista; gelo vivo preso numa garra."""
    t, t2, gold = mats["tint"], mats["tint2"], mats["trim"]
    S = 0.5
    shards = [(0, 0, 0, 1.15, 0.26, 0.13), (-0.06, 0.05, -0.42, 0.98, 0.2, 0.09), (0.06, 0.05, 0.42, 1.04, 0.2, 0.09),
              (-0.1, -0.05, -0.8, 0.7, 0.15, 0.07), (0.1, -0.05, 0.84, 0.74, 0.15, 0.07), (-0.08, -0.14, -2.5, 0.72, 0.15, 0.07),
              (0.08, -0.14, 2.5, 0.66, 0.14, 0.07), (0, -0.2, 3.14, 1.0, 0.22, 0.11)]
    parts = [plate(name + "_nucleo", [(math.cos(math.tau * i / 6) * S * 0.24, math.sin(math.tau * i / 6) * S * 0.3) for i in range(6)], -0.06, 0.02, t)]
    for i, (x, z, a, ln, w, th) in enumerate(shards):
        b = (S * x, S * z)
        parts.append(blade("%s_cristal_%d" % (name, i), b, (b[0] + math.sin(a) * S * ln, b[1] + math.cos(a) * S * ln), w, th, t2 if i % 3 == 1 else t, 0.3, -0.02))
    for k in (-1, 1):
        parts.append(blade(name + "_garra_%d" % k, (k * S * 0.5, -S * 0.1), (k * S * 0.12, S * 0.3), 0.08, 0.04, gold, 0.3, -0.1))
    parts.append(gem(name + "_foco", (0, -S * 0.02), 0.075, jewel(ck, "ciano"), -0.12, 8, 1.1))
    return parts + _back(ck, name, mats, 0.1, t)


def gaia(ck, name, mats):
    """Gaia: folha viva com nervura em relevo e raízes que sobram para fora."""
    t, t2, gold = mats["tint"], mats["tint2"], mats["trim"]
    S = 0.38
    half = [(0, 1.1), (0.22, 0.72), (0.5, 0.3), (0.58, -0.1), (0.4, -0.56), (0.14, -0.84), (0, -0.96)]
    out = mirror(half, S)
    parts = [plate(name + "_aro", [(x * 1.09, z * 1.06) for x, z in out], -0.03, 0.03, gold),
             plate(name + "_corpo", out, -0.085, 0.02, t),
             blade(name + "_talo", (0, -S * 1.5), (0, S * 0.98), 0.07, 0.05, gold, 0.3, -0.085)]
    for i in range(4):
        z = S * (-0.5 + i * 0.36)
        for k in (-1, 1):
            parts.append(blade("%s_nerv_%d_%d" % (name, k, i), (0, z), (k * S * (0.52 - i * 0.05), z + S * 0.28), 0.03, 0.025, gold, 0.3, -0.083))
    for k in (-1, 1):
        parts.append(blade(name + "_folha_%d" % k, (k * S * 0.26, S * 0.6), (k * S * 0.62, S * 0.92), 0.1, 0.04, t2, 0.5))
        parts.append(blade(name + "_raiz_a%d" % k, (k * S * 0.2, -S * 0.8), (k * S * 0.74, -S * 1.28), 0.08, 0.04, gold, 0.25))
        parts.append(blade(name + "_raiz_b%d" % k, (k * S * 0.36, -S * 0.5), (k * S * 1.0, -S * 0.84), 0.07, 0.035, gold, 0.25))
    parts.append(gem(name + "_foco", (0, S * 0.05), 0.075, jewel(ck, "rubi"), -0.11, 6, 1.5))
    return parts + _back(ck, name, mats)



JEWELS = {"azul": (0.01, 0.06, 0.75), "rubi": (0.62, 0.0, 0.02), "verde": (0.0, 0.42, 0.1), "violeta": (0.2, 0.02, 0.62),
          "ambar": (0.85, 0.22, 0.0), "ciano": (0.05, 0.6, 0.8), "branco": (0.75, 0.8, 0.9)}


def jewel(ck, color):
    """Joia de cor fixa: não recebe a cor do item, é o foco que puxa o olho."""
    return ck.mat("m_joia_" + color, JEWELS[color], 0.2, 0.12)


def band(name, pts, w, t, material, y=-0.06, end=0.25):
    """Fita curva com espessura (filigrana, costela, serpente). Afina até `end` da largura."""
    pts = [Vector(p) for p in pts]
    rings = []
    n = len(pts)
    for i, p in enumerate(pts):
        d = (pts[min(i + 1, n - 1)] - pts[max(i - 1, 0)]).normalized()
        side = Vector((-d.y, d.x))
        k = 1.0 + (end - 1.0) * (i / max(1, n - 1))
        hw = w * 0.5 * k
        rings.append([(p.x + side.x * hw, y, p.y + side.y * hw), (p.x, y - t, p.y), (p.x - side.x * hw, y, p.y - side.y * hw), (p.x, y + t * 0.3, p.y)])
    verts = [v for r in rings for v in r]
    faces = [(0, 1, 2, 3)]
    for i in range(n - 1):
        for j in range(4):
            a, b = i * 4 + j, i * 4 + (j + 1) % 4
            faces.append((a, b, b + 4, a + 4))
    faces.append(tuple((n - 1) * 4 + j for j in (3, 2, 1, 0)))
    return _mesh(name, verts, faces, material)


def spiral(c, r0, r1, a0, turns, n=14, flip=1):
    """Pontos de uma voluta: de raio r0 até r1."""
    out = []
    for i in range(n):
        k = i / (n - 1)
        a = a0 + flip * turns * math.tau * k
        r = r0 + (r1 - r0) * k
        out.append((c[0] + math.cos(a) * r, c[1] + math.sin(a) * r))
    return out


def scroll(name, c, r, a0, turns, w, material, flip=1, y=-0.08):
    return band(name, spiral(c, r, r * 0.16, a0, turns, 14, flip), w, 0.018, material, y)


def gem(name, c, r, material, y=-0.1, sides=6, tall=1.3, depth=0.07):
    """Gema lapidada virada para a frente."""
    ring = [(c[0] + math.sin(math.tau * i / sides) * r, y, c[1] + math.cos(math.tau * i / sides) * r * tall) for i in range(sides)]
    verts = ring + [(c[0], y - depth, c[1]), (c[0], y + depth * 0.4, c[1])]
    faces = [(i, (i + 1) % sides, sides) for i in range(sides)] + [((i + 1) % sides, i, sides + 1) for i in range(sides)]
    return _mesh(name, verts, faces, material)


def rib(name, z, half_w, droop, h, material, y=-0.06, end=0.5):
    """Costela: uma fita do meio para cada lado, caindo nas pontas."""
    pts = [(-half_w, z - droop), (-half_w * 0.5, z - droop * 0.2), (0, z + droop * 0.1), (half_w * 0.5, z - droop * 0.2), (half_w, z - droop)]
    return band(name, pts, h, 0.03, material, y, end)


def _pair(fn, name, *a):
    return [fn(name + "_d", *a, 1), fn(name + "_e", *a, -1)]


def tabuas(ck, name, mats):
    """Escudo de recruta: tábuas de alturas diferentes presas por duas cintas de ferro. Honesto e grande."""
    wood, iron, gold = mats["tint"], mats["metal"], mats["tint2"]
    S = 0.42
    parts = []
    for i, (x, top, bot) in enumerate(((-0.48, 0.84, -0.8), (-0.24, 0.98, -0.94), (0, 1.06, -1.04), (0.24, 0.94, -0.96), (0.48, 0.8, -0.78))):
        parts.append(ck.box("%s_tabua_%d" % (name, i), (S * 0.23, 0.035, S * (top - bot)), (S * x, -0.03 - 0.004 * (i % 2), S * (top + bot) * 0.5), wood, 0.01))
    for z in (0.5, -0.5):
        parts.append(ck.box("%s_cinta_%g" % (name, z), (S * 1.32, 0.03, 0.065), (0, -0.058, S * z), iron, 0.008))
        for x in (-0.54, -0.18, 0.18, 0.54):
            parts.append(ck.ball("%s_rebite_%g_%g" % (name, z, x), 0.02, (S * x, -0.08, S * z), gold, (1, 0.6, 1)))
    parts.append(ck.ball(name + "_foco", 0.07, (0, -0.07, 0), iron, (1, 0.55, 1)))
    return parts + _back(ck, name, mats)


def ferro(ck, name, mats):
    """Escudo de ferro: heráldico, com aro rebitado, nervura central e faixa em chevron."""
    t, t2, gold, iron = mats["tint"], mats["tint2"], mats["trim"], mats["metal"]
    S = 0.4
    half = [(0, 0.9), (0.4, 0.92), (0.72, 0.84), (0.7, 0.2), (0.52, -0.4), (0.26, -0.8), (0, -1.02)]
    out = mirror(half, S)
    parts = [plate(name + "_aro", [(x * 1.08, z * 1.05) for x, z in out], -0.03, 0.03, iron), plate(name + "_corpo", out, -0.08, 0.02, t)]
    parts.append(rib(name + "_chevron", S * 0.12, S * 0.5, S * 0.34, 0.075, gold, -0.09, 1.0))
    parts.append(ck.box(name + "_nervura", (0.03, 0.04, S * 1.84), (0, -0.095, -S * 0.04), gold, 0.01))
    for i, (x, z) in enumerate(((0.58, 0.72), (0.58, 0.2), (0.4, -0.3), (0.2, -0.66))):
        for k in (-1, 1):
            parts.append(ck.ball("%s_rebite_%d_%d" % (name, i, k), 0.022, (k * S * x, -0.04, S * z), gold, (1, 0.6, 1)))
    parts.append(gem(name + "_foco", (0, S * 0.5), 0.055, jewel(ck, "rubi")))
    return parts + _back(ck, name, mats)


def ossario(ck, name, mats):
    """Ossário: caixa torácica vazada presa numa coluna, com um crânio pequeno no alto."""
    t, t2 = mats["tint"], mats["tint2"]
    S = 0.42
    parts = [band(name + "_coluna", [(0, S * 1.0), (0.02, S * 0.2), (-0.02, -S * 0.5), (0, -S * 1.2)], 0.09, 0.05, t, -0.05, 0.3)]
    for i in range(6):
        z = S * (0.68 - i * 0.3)
        w = S * (0.74 - abs(i - 2) * 0.09)
        for k in (-1, 1):
            parts.append(band("%s_costela_%d_%d" % (name, i, k), [(0, z), (k * w * 0.55, z + 0.02), (k * w, z - 0.07), (k * w * 1.04, z - 0.15)], 0.075, 0.03, t, -0.045, 0.4))
    parts.append(ck.ball(name + "_cranio", 0.135, (0, -0.1, S * 0.74), t, (1, 0.75, 1.05)))
    for k in (-1, 1):
        parts.append(gem(name + "_olho_%d" % k, (k * 0.055, S * 0.76), 0.03, jewel(ck, "verde"), -0.195, 6, 1.1, 0.03))
    return parts + _back(ck, name, mats, 0.1, t)


def escama(ck, name, mats):
    """Dracônico: fileiras de escamas sobrepostas, olho e chifres para trás."""
    t, t2, gold = mats["tint"], mats["tint2"], mats["trim"]
    S = 0.42
    half = [(0, 0.86), (0.36, 0.82), (0.6, 0.4), (0.56, -0.2), (0.3, -0.72), (0, -1.1)]
    out = mirror(half, S)
    parts = [plate(name + "_base", out, -0.05, 0.02, t2)]
    for r, (z, n, w) in enumerate(((0.72, 3, 0.34), (0.4, 4, 0.33), (0.08, 4, 0.31), (-0.24, 3, 0.3), (-0.54, 2, 0.26))):
        for c in range(n):
            x = (c - (n - 1) / 2) * w
            parts.append(blade("%s_escama_%d_%d" % (name, r, c), (S * x, S * (z + 0.24)), (S * x, S * (z - 0.34)), S * w * 1.05, 0.05, t if r % 2 else t2, 0.32, -0.06 - r * 0.002))
    parts.append(band(name + "_espinha", [(0, S * 0.86), (0, 0), (0, -S * 1.12)], 0.07, 0.05, gold, -0.095, 0.4))
    for k in (-1, 1):
        parts.append(band(name + "_chifre_%d" % k, [(k * S * 0.5, S * 0.56), (k * S * 0.74, S * 0.92), (k * S * 0.86, S * 1.2), (k * S * 0.72, S * 1.28)], 0.12, 0.05, gold, -0.04, 0.12))
        parts.append(blade(name + "_cauda_%d" % k, (k * S * 0.08, -S * 0.98), (k * S * 0.36, -S * 1.5), 0.11, 0.05, gold, 0.25))
    parts.append(gem(name + "_foco", (0, S * 0.5), 0.075, jewel(ck, "ciano"), -0.115, 8, 1.5))
    return parts + _back(ck, name, mats)


def coluna(ck, name, mats):
    """Defensor antigo: frontão de templo em cima, duas colunas, uma joia só e cauda partida."""
    t, t2, gold = mats["tint"], mats["tint2"], mats["trim"]
    S = 0.42
    half = [(0, 0.86), (0.56, 0.86), (0.5, 0.5), (0.42, 0), (0.5, -0.6), (0.56, -0.96), (0, -0.9)]
    out = mirror(half, S)
    parts = [plate(name + "_corpo", out, -0.07, 0.02, t),
             plate(name + "_fronte", mirror([(0, 0.46), (0.8, 0.0), (0.8, -0.1), (0, -0.1)], S), -0.05, 0.02, gold, 0.0, S * 0.94),
             plate(name + "_timpano", mirror([(0, 0.3), (0.5, 0.02), (0, 0.02)], S), -0.075, -0.03, t, 0.0, S * 0.94),
             band(name + "_espinha", [(0, S * 0.84), (0, 0), (0, -S * 1.22)], 0.06, 0.04, gold, -0.085, 0.3)]
    for k in (-1, 1):
        parts.append(band(name + "_col_%d" % k, [(k * S * 0.6, S * 0.86), (k * S * 0.5, S * 0.42), (k * S * 0.44, 0), (k * S * 0.5, -S * 0.5), (k * S * 0.6, -S * 0.96)], 0.11, 0.06, gold, -0.04, 1.0))
        parts.append(blade(name + "_cauda_%d" % k, (k * S * 0.32, -S * 0.92), (k * S * 0.46, -S * 1.52), 0.14, 0.05, gold, 0.25))
        parts.append(scroll(name + "_vol_%d" % k, (k * S * 0.24, S * 0.52), 0.075, 0.0, 1.2, 0.042, gold, k))
    parts += ring(name + "_anel", (0, 0), S * 0.3, 0.016, gold, 14, -0.1, ck.tube)
    parts.append(gem(name + "_gema", (0, 0), 0.1, jewel(ck, "azul"), -0.115, 8, 1.2))
    return parts + _back(ck, name, mats)


def perdao(ck, name, mats):
    """Perdão: losango de joia com a cruz de ouro por cima e asas pequenas; é a peça mais luminosa do clérigo."""
    t, t2, gold = mats["tint"], mats["tint2"], mats["trim"]
    S = 0.44
    dia = [(0, 1.0), (0.62, 0.1), (0, -1.0), (-0.62, 0.1)]
    out = [(x * S, z * S) for x, z in dia]
    parts = [plate(name + "_aro", [(x * 1.14, z * 1.08) for x, z in out], -0.03, 0.03, gold), plate(name + "_corpo", out, -0.075, 0.02, t),
             plate(name + "_miolo", [(x * 0.62, z * 0.62 - 0.0) for x, z in out], -0.095, -0.03, t2)]
    for i, (a, b, w) in enumerate((((0, 0.3), (0, 1.24), 0.12), ((0, -0.3), (0, -1.5), 0.13), ((0.26, 0.1), (1.12, 0.1), 0.1), ((-0.26, 0.1), (-1.12, 0.1), 0.1))):
        parts.append(blade("%s_cruz_%d" % (name, i), (a[0] * S, a[1] * S), (b[0] * S, b[1] * S), w, 0.05, gold, 0.28, -0.085))
    for k in (-1, 1):
        for j in range(3):
            parts.append(blade("%s_asa_%d_%d" % (name, k, j), (k * S * 0.34, S * (0.42 - j * 0.1)), (k * S * (1.06 - j * 0.16) * (1.0 if k > 0 else 0.7), S * (0.92 - j * 0.3)), 0.075, 0.03, gold, 0.4))
    parts += ring(name + "_anel", (0, S * 0.1), S * 0.3, 0.012, gold, 14, -0.1, ck.tube)
    parts.append(gem(name + "_foco", (0, S * 0.1), 0.09, jewel(ck, "ciano"), -0.12, 8, 1.2))
    return parts + _back(ck, name, mats)


def veredito(ck, name, mats):
    """Veredito: X de lâminas largas no centro e finas nas pontas, disco de ouro e um raio cruzando o núcleo."""
    t, t2, gold = mats["tint"], mats["tint2"], mats["trim"]
    S = 0.46
    parts = []
    for i, (x, z) in enumerate(((0.86, 1.0), (-0.86, 1.0), (0.86, -1.0), (-0.86, -1.0))):
        parts.append(blade("%s_braco_%d" % (name, i), (0, 0), (x * S, z * S), 0.44, 0.1, t, 0.3, -0.05))
        parts.append(blade("%s_filete_%d" % (name, i), (x * S * 0.3, z * S * 0.3), (x * S * 0.86, z * S * 0.86), 0.05, 0.05, gold, 0.3, -0.1))
        parts.append(blade("%s_ponta_%d" % (name, i), (x * S * 0.86, z * S * 0.86), (x * S * (1.3 if x > 0 else 0.95), z * S * 1.36), 0.16, 0.05, gold, 0.25, -0.05))
    disc = [(math.cos(math.tau * i / 12) * S * 0.6, math.sin(math.tau * i / 12) * S * 0.6) for i in range(12)]
    parts.append(plate(name + "_aro", [(x * 1.12, z * 1.12) for x, z in disc], -0.09, -0.02, gold))
    parts.append(plate(name + "_disco", disc, -0.115, -0.03, t))
    parts.append(band(name + "_raio", [(S * 0.36, S * 0.96), (-S * 0.24, S * 0.26), (S * 0.26, S * 0.08), (-S * 0.26, -S * 0.34), (S * 0.14, -S * 0.2), (-S * 0.34, -S * 1.24)], 0.12, 0.03, gold, -0.13, 0.25))
    parts.append(gem(name + "_foco", (0, 0), 0.085, jewel(ck, "ciano"), -0.15, 8, 1.1))
    return parts + _back(ck, name, mats)


def serpente(ck, name, mats):
    """Serpente: tábua escura e recortada com uma cobra de ouro em S, cabeça com olho de joia e cauda partida."""
    t, t2, gold = mats["tint"], mats["tint2"], mats["trim"]
    S = 0.44
    half = [(0, 0.86), (0.36, 0.84), (0.42, 0.5), (0.3, 0.3), (0.42, 0.06), (0.3, -0.2), (0.4, -0.5), (0.28, -0.9), (0, -1.0)]
    out = mirror(half, S)
    parts = [plate(name + "_aro", [(x * 1.1, z * 1.04) for x, z in out], -0.03, 0.03, t2), plate(name + "_corpo", out, -0.07, 0.02, t)]
    body = [(0.2, 0.42), (0.3, 0.24), (0.3, 0.06), (0.14, -0.06), (-0.08, -0.12), (-0.26, -0.24), (-0.3, -0.42), (-0.18, -0.58), (0.0, -0.68), (0.1, -0.84), (0.02, -1.08)]
    parts.append(band(name + "_cobra", [(x * S, z * S) for x, z in body], 0.17, 0.06, gold, -0.08, 0.3))
    parts.append(blade(name + "_cabeca", (S * 0.2, S * 0.26), (S * 0.2, S * 1.0), 0.22, 0.09, gold, 0.34, -0.1))
    for i, (x, z, tx, tz) in enumerate(((0.34, 0.12, 0.47, 0.22), (0.04, -0.02, 0.14, 0.15), (-0.27, -0.28, -0.42, -0.16), (-0.2, -0.54, -0.36, -0.6))):
        parts.append(blade("%s_crista_%d" % (name, i), (x * S, z * S), (tx * S, tz * S), 0.11, 0.05, gold, 0.25, -0.07))
    for k in (-1, 1):
        parts.append(blade(name + "_membrana_%d" % k, (k * S * 0.34, S * 0.72), (k * S * (1.1 if k > 0 else 0.7), S * 1.02), 0.3, 0.04, t2, 0.4))
        parts.append(blade(name + "_nervo_%d" % k, (k * S * 0.34, S * 0.72), (k * S * (1.16 if k > 0 else 0.74), S * 1.06), 0.05, 0.04, gold, 0.3, -0.045))
    parts.append(gem(name + "_foco", (S * 0.2, S * 0.54), 0.045, jewel(ck, "rubi"), -0.205, 6, 1.1, 0.03))
    parts.append(gem(name + "_olho", (S * 0.2, S * 0.56), 0.068, jewel(ck, "rubi"), -0.17, 6, 1.0, 0.05))
    for k in (-1, 1):
        parts.append(blade(name + "_cauda_%d" % k, (S * 0.02, -S * 1.0), (k * S * 0.34, -S * 1.5), 0.09, 0.04, gold, 0.25))
        parts.append(blade(name + "_presa_%d" % k, (S * (0.2 + k * 0.1), S * 0.68), (S * (0.2 + k * 0.3), S * 1.14), 0.08, 0.035, gold, 0.25))
    return parts + _back(ck, name, mats)


def cruel(ck, name, mats):
    """Crueldade: sem placa. Coroa de lâminas caindo em leque, coluna vertebral e um olho aceso."""
    t, t2, gold = mats["tint"], mats["tint2"], mats["trim"]
    S = 0.46
    parts = []
    for i, (bx, tx, tz, w) in enumerate(((-0.12, -0.2, -1.32, 0.17), (0.12, 0.2, -1.32, 0.17), (-0.3, -0.62, -1.06, 0.16), (0.3, 0.62, -1.06, 0.16), (-0.42, -0.72, -0.62, 0.14), (0.42, 0.98, -0.62, 0.14))):
        parts.append(blade("%s_lamina_%d" % (name, i), (S * bx, S * 0.34), (S * tx, S * tz), w, 0.06, t, 0.2, -0.03))
        parts.append(blade("%s_gume_%d" % (name, i), (S * bx * 0.9, S * 0.1), (S * tx * 0.92, S * tz * 0.72), w * 0.36, 0.05, t2, 0.25, -0.075))
    for i, (bx, tx, tz) in enumerate(((0, 0, 1.28), (-0.2, -0.46, 1.08), (0.2, 0.46, 1.08), (-0.38, -0.68, 0.72), (0.38, 0.92, 0.72))):
        parts.append(blade("%s_coroa_%d" % (name, i), (S * bx, S * 0.34), (S * tx, S * tz), 0.1, 0.05, gold if i == 0 else t, 0.2, -0.04))
    parts.append(plate(name + "_nucleo", mirror([(0, 0.6), (0.34, 0.4), (0.4, 0.06), (0.16, -0.2), (0, -0.3)], S), -0.1, 0.02, t))
    for i in range(4):
        parts.append(rib("%s_vert_%d" % (name, i), -S * (0.24 + i * 0.2), S * (0.2 - i * 0.03), 0.02, 0.035, gold, -0.08, 1.0))
    parts.append(gem(name + "_foco", (0, S * 0.3), 0.085, jewel(ck, "rubi"), -0.12, 6, 0.8))
    return parts + _back(ck, name, mats)


def asa_negra(ck, name, mats):
    """Asa negra: abdômen de anéis, volutas de ouro nos dois lados e asas curtas de lâmina."""
    t, t2, gold = mats["tint"], mats["tint2"], mats["trim"]
    S = 0.46
    parts = [plate(name + "_fundo", mirror([(0, 0.86), (0.4, 0.74), (0.56, 0.2), (0.4, -0.5), (0, -1.1)], S), -0.05, 0.02, t)]
    for i in range(7):
        z = S * (0.56 - i * 0.26)
        w = S * (0.54 - i * 0.05)
        parts.append(rib("%s_anel_%d" % (name, i), z, w, 0.05, 0.14, gold if i % 3 == 0 else t2, -0.07, 0.45))
    for k in (-1, 1):
        parts.append(blade(name + "_cauda_%d" % k, (k * S * 0.05, -S * 1.06), (k * S * 0.3, -S * 1.66), 0.1, 0.05, gold, 0.25))
    parts.append(band(name + "_coluna", [(0, S * 0.84), (0, -S * 0.2), (0, -S * 1.2)], 0.04, 0.04, gold, -0.085, 0.3))
    for k in (-1, 1):
        parts.append(scroll(name + "_vol_a%d" % k, (k * S * 0.66, S * 0.66), 0.15, 2.4 if k > 0 else 0.7, 1.4, 0.05, gold, k, -0.05))
        parts.append(scroll(name + "_vol_b%d" % k, (k * S * 0.5, -S * 0.2), 0.12, 2.2 if k > 0 else 0.9, 1.4, 0.046, gold, -k, -0.09))
        for j, (tx, tz) in enumerate(((1.18, 1.16), (1.32, 0.66), (1.2, 0.16))):
            parts.append(blade("%s_pena_%d_%d" % (name, k, j), (k * S * 0.36, S * (0.56 - j * 0.2)), (k * S * tx * (1.22 if k > 0 else 0.46), S * tz), 0.21, 0.05, t, 0.4, -0.02))
        parts.append(band(name + "_elo_%d" % k, [(k * S * 0.34, S * 0.5), (k * S * 0.6, S * 0.62)], 0.05, 0.03, gold, -0.06, 0.8))
    parts.append(gem(name + "_foco", (0, S * 0.66), 0.09, jewel(ck, "verde"), -0.12, 6, 1.5))
    return parts + _back(ck, name, mats)


def suspiros(ck, name, mats):
    """Muro dos Suspiros: costelas de ouro empilhadas em forma de vaso, coroa e joia."""
    t, t2, gold = mats["tint"], mats["tint2"], mats["trim"]
    S = 0.46
    widths = [0.5, 0.64, 0.7, 0.66, 0.58, 0.48, 0.36, 0.24]
    parts = [plate(name + "_fundo", mirror([(0, 0.92), (0.4, 0.86), (0.54, 0.2), (0.34, -0.7), (0, -1.02)], S), -0.04, 0.02, t2)]
    for i, w in enumerate(widths):
        z = S * (0.84 - i * 0.25)
        parts.append(rib("%s_costela_%d" % (name, i), z, S * w, S * 0.13, 0.095, t2 if i % 3 == 2 else gold, -0.05, 0.3))
    parts.append(band(name + "_espinha", [(0, S * 1.02), (0, S * 0.1), (0, -S * 1.24)], 0.085, 0.05, gold, -0.085, 0.3))
    for k in (-1, 1):
        parts.append(blade(name + "_coroa_%d" % k, (k * S * 0.26, S * 0.94), (k * S * 0.58, S * 1.34), 0.09, 0.04, gold, 0.25))
    parts.append(blade(name + "_coroa_m", (0, S * 1.0), (0, S * 1.46), 0.1, 0.04, gold, 0.25))
    for k in (-1, 1):
        parts.append(blade(name + "_cauda_%d" % k, (k * S * 0.08, -S * 1.1), (k * S * 0.34, -S * 1.6), 0.09, 0.04, gold, 0.25))
    for i, (z, ln) in enumerate(((0.66, 1.34), (0.34, 1.46), (0.02, 1.3))):
        parts.append(blade("%s_flanco_d%d" % (name, i), (S * 0.5, S * z), (S * ln, S * (z + 0.3)), 0.2, 0.06, t, 0.32, -0.02))
    for i, (z, ln) in enumerate(((0.56, 0.6), (0.22, 0.62))):
        parts.append(blade("%s_flanco_e%d" % (name, i), (-S * 0.5, S * z), (-S * ln, S * (z + 0.22)), 0.16, 0.05, t, 0.32, -0.02))
    parts.append(gem(name + "_foco", (0, S * 0.34), 0.09, jewel(ck, "ciano"), -0.125, 8, 1.3))
    return parts + _back(ck, name, mats)

## giro no plano do escudo: quem tem topo ou ponta alta afasta mais da cabeça e do braço
## tamanho por nível: o escudo de fim de jogo se impõe pela massa, não só pelo detalhe
SIZES = {"tabuas": 0.9, "ferro": 0.92, "coluna": 0.94, "ossario": 0.95, "gaia": 0.96, "perdao": 1.0, "veredito": 0.9, "serpente": 0.96,
         "asa": 1.06, "cruel": 1.06, "sol": 1.06, "asa_negra": 0.98, "suspiros": 0.98, "presa": 0.92, "relicario": 0.95, "escama": 0.95}
## lado do braço mais curto (só X negativo): tira o contato com ombreira e peitoral sem perder o tamanho do escudo
INNER = {"veredito": 0.75, "asa_negra": 0.6, "presa": 0.8, "suspiros": 0.85}


def hull(obj, width, material):
    """Contorno soldado: cópia invertida da malha, inflada pela normal média de cada posição.
    O contorno do shader abre as peças facetadas em traços soltos; aqui cada canto anda junto."""
    me = obj.data
    bm = bmesh.new()
    bm.from_mesh(me)
    bm.normal_update()
    key = lambda v: (round(v.co.x, 3), round(v.co.y, 3), round(v.co.z, 3))
    avg = {}
    for f in bm.faces:
        for v in f.verts:
            avg[key(v)] = avg.get(key(v), Vector()) + f.normal * f.calc_area()
    idx = len(me.materials)
    me.materials.append(material)
    copies = {}
    for f in list(bm.faces):
        vs = []
        for v in f.verts:
            if v not in copies:
                n = avg[key(v)]
                copies[v] = bm.verts.new(v.co + (n.normalized() if n.length > 1e-9 else Vector()) * width)
            vs.append(copies[v])
        if len(set(vs)) == len(vs):
            nf = bm.faces.new(list(reversed(vs)))
            nf.material_index = idx
    bm.to_mesh(me)
    bm.free()


FAMILIES = {"bastiao": bastiao, "juramento": juramento, "asa": asa, "sol": sol, "presa": presa, "relicario": relicario, "prisma": prisma, "gaia": gaia,
            "tabuas": tabuas, "ferro": ferro, "ossario": ossario, "escama": escama, "coluna": coluna, "perdao": perdao, "veredito": veredito,
            "serpente": serpente, "cruel": cruel, "asa_negra": asa_negra, "suspiros": suspiros}
