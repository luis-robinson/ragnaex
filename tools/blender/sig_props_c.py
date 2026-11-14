"""Marcas das mecânicas-assinatura dos chefes de Kharzun (GDD act2-boss-signatures §3.1, §3.2, §3.4), parte C.
Cada uma sai como GLB estático em assets/models/ (sem textura, < 600 tris, 1 u = 1 m, origem no chão, no centro):

    prop_tide_island       Maré Cheia: ilha de areia SEGURA. Raio de fora 2,5 m; topo seco a ~0,12 m.
    prop_tide_floodring    Maré Cheia: anel de onda em volta da ilha (2,6 m a 3,4 m; z 0,02 a 0,15), crista para dentro.
    prop_grukk_wardrum     Rufar da Turba: tambor de guerra (~1,4 m de boca) em cavalete de toras e presas; frente = -Y.
    prop_vorgul_brand      Marca do Atirador: retícula chapada (raio 1 m, z 0,05) + nó à parte `brand_arrow` (virote no ar).

Materiais: `glow_*` brilham no jogo (convenção do map_builder), `p_*` são cores fixas. Formas e prévia vêm de sig_props_b.

    blender -b --factory-startup --python sig_props_c.py -- [--out=<assets/models>] [--preview=<pasta>] [--only=a,b]
"""
import math
import os
import random
import sys

import bpy
from mathutils import Vector, Matrix

HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
    sys.path.append(HERE)

import chibi_kit as ck
import prop_kit as pk
import sig_props_b as sb

SAND = (1.0, 0.89, 0.6)
SAND_WET = (0.7, 0.57, 0.42)
WATER = (0.3, 0.62, 0.95)
WATER_D = (0.16, 0.38, 0.72)
FOAM = (0.96, 0.99, 1.0)


def MM():
    return {
        # maré
        "sand": ck.mat("p_sand", SAND, 0.95),
        "sand_d": ck.mat("p_sand_d", (0.88, 0.76, 0.52), 0.95),
        "sand_wet": ck.mat("p_sand_wet", SAND_WET, 0.8),
        "foam": ck.mat("glow_mare_espuma", FOAM, 0.5, 0.35),
        "water": ck.mat("glow_mare", WATER, 0.3, 0.3),
        "water_d": ck.mat("p_mare_d", WATER_D, 0.3),
        "coral": ck.mat("p_coral", (0.95, 0.42, 0.45), 0.8),
        "star": ck.mat("p_starfish", (1.0, 0.55, 0.3), 0.8),
        "shell": ck.mat("p_shell", (1.0, 0.8, 0.82), 0.6),
        "shell_d": ck.mat("p_shell_d", (0.62, 0.5, 0.7), 0.6),
        "grass": ck.mat("p_beach_grass", (0.5, 0.7, 0.36), 0.85),
        "pebble": ck.mat("p_pebble", (0.55, 0.56, 0.62), 0.9),
        # tambor
        "wood": ck.mat("p_wood_d", (0.36, 0.24, 0.16), 0.85),
        "wood_l": ck.mat("p_wood", (0.55, 0.38, 0.24), 0.85),
        "hide": ck.mat("p_hide", (0.9, 0.8, 0.6), 0.9),
        "hide_d": ck.mat("p_hide_d", (0.66, 0.5, 0.34), 0.9),
        "red": ck.mat("p_horde_red", sb.HORDE_RED, 0.85),
        "red_d": ck.mat("p_horde_red_d", (0.46, 0.1, 0.1), 0.85),
        "black": ck.mat("p_horde_black", (0.12, 0.1, 0.11), 0.9),
        "iron": ck.mat("p_iron_d", (0.27, 0.26, 0.3), 0.5),
        "bone": ck.mat("p_bone", sb.BONE, 0.85),
        "bone_d": ck.mat("p_bone_d", (0.72, 0.66, 0.55), 0.85),
        # marca
        "brand": ck.mat("glow_brand", (1.0, 0.16, 0.12), 0.5, 0.7),
        "brand_hot": ck.mat("glow_brand_bolt", (1.0, 0.62, 0.25), 0.5, 0.9),
        "brand_dark": ck.mat("p_brand_dark", (0.2, 0.05, 0.06), 0.9),
    }


# ---------------------------------------------------------------------------
# formas
# ---------------------------------------------------------------------------
def _up(o):
    """Peça de chão: toda face olha para cima."""
    for p in o.data.polygons:
        if p.normal.z < 0.0:
            p.flip()
    o.data.update()
    return o


def _rings(name, prof, n, mats, idx, fan_z=None):
    """Superfície de revolução facetada. prof(i) = [(r, z), ...] do anel i (de dentro para fora);
    `idx` = material de cada faixa; `fan_z` fecha o miolo com um leque até (0, 0, fan_z) (material 0)."""
    verts, faces, fi = [], [], []
    k = len(prof(0))
    for i in range(n):
        a = math.tau * i / n
        for r, z in prof(i):
            verts.append((math.cos(a) * r, math.sin(a) * r, z))
    for i in range(n):
        a, b = i * k, ((i + 1) % n) * k
        for j in range(k - 1):
            faces.append((a + j, a + j + 1, b + j + 1, b + j))
            fi.append(idx[j])
    if fan_z is not None:
        c = len(verts)
        verts.append((0.0, 0.0, fan_z))
        for i in range(n):
            faces.append((c, i * k, ((i + 1) % n) * k))
            fi.append(0)
    return sb._mesh(name, verts, faces, mats, fi)


def _poly(name, pts, z, mat, c=(0.0, 0.0), rot=0.0):
    """Figura chapada no chão (um n-gono convexo ou quase), virada para cima."""
    ca, sa = math.cos(rot), math.sin(rot)
    verts = [(c[0] + x * ca - y * sa, c[1] + x * sa + y * ca, z) for x, y in pts]
    return _up(sb._mesh(name, verts, [tuple(range(len(pts)))], mat))


def _xform(parts, mtx):
    for o in parts:
        o.data.transform(mtx)
    return parts


# ---------------------------------------------------------------------------
# 1. Mãe das Marés: ilha de areia
# ---------------------------------------------------------------------------
ISLAND_R = 2.5
ISLAND_TOP = 0.12


def _starfish(name, c, r, mat, rot=0.0, z=ISLAND_TOP):
    verts = [(c[0], c[1], z + r * 0.38)]
    for i in range(10):
        a = rot + math.tau * i / 10
        rr = r if i % 2 == 0 else r * 0.42
        verts.append((c[0] + math.cos(a) * rr, c[1] + math.sin(a) * rr, z + (0.0 if i % 2 == 0 else r * 0.12)))
    return sb._mesh(name, verts, [(0, 1 + i, 1 + (i + 1) % 10) for i in range(10)], mat)


def _scallop(name, c, r, m, rot=0.0, z=ISLAND_TOP):
    """Concha em leque: gomos alternando claro/escuro, deitada e meio levantada."""
    verts = [(0.0, -r * 0.35, 0.02)]
    n = 6
    for i in range(n + 1):
        a = math.radians(20.0 + 140.0 * i / n)
        verts.append((math.cos(a) * r, -r * 0.35 + math.sin(a) * r * 1.1, r * (0.42 if i % 2 else 0.3)))
    verts.append((0.0, r * 0.1, r * 0.62))
    top = n + 2
    faces, idx = [], []
    for i in range(n):
        faces.append((top, 1 + i, 2 + i))
        idx.append(i % 2)
    faces += [(0, 1, top), (0, top, n + 1)]
    idx += [1, 1]
    for i in range(n):                                   # saia até a areia
        faces.append((1 + i, top, 2 + i))
    o = sb._mesh(name, verts, faces[:n + 2], [m["shell"], m["shell_d"]], idx)
    o.data.transform(Matrix.Translation((c[0], c[1], z)) @ Matrix.Rotation(rot, 4, "Z"))
    return o


def tide_island(m=None):
    """Ilha de areia (raio de fora 2,5 m): borda de espuma branca, talude de areia molhada escura, topo seco claro
    quase plano a 0,12 m com riscos de onda, estrela-do-mar, conchas, coral, seixos e um tufo de capim de praia.
    De cima: disco claro com anel escuro e anel branco = chão seguro contra a água azul."""
    m = m or MM()
    rnd = random.Random(31)
    n = 18
    jit = [rnd.uniform(-0.05, 0.05) for _ in range(n)]
    lap = [0.1 if i % 2 else 0.0 for i in range(n)]       # espuma em gomos: lambe a areia

    def prof(i):
        return [(2.0 + jit[i], ISLAND_TOP), (2.22 + jit[i] * 0.5 + lap[i], 0.05), (ISLAND_R, 0.012)]

    def top(i):
        return [(2.0 + jit[i], ISLAND_TOP)]

    parts = [_up(_rings("talude", prof, n, [m["sand_wet"], m["foam"]], [0, 1])),
             _up(_rings("topo", top, n, [m["sand"]], [], ISLAND_TOP + 0.03))]
    # riscos de onda na areia: crescentes mais escuros (seguem a borda)
    for k, (a0, r, sweep) in enumerate(((0.5, 1.55, 1.1), (2.6, 1.35, 0.9), (4.3, 1.6, 1.2), (3.4, 0.75, 0.8))):
        seg = 4
        verts = []
        for i in range(seg + 1):
            a = a0 + sweep * i / seg
            w = 0.07 * math.sin(math.pi * i / seg) + 0.012
            verts += [(math.cos(a) * (r - w), math.sin(a) * (r - w), ISLAND_TOP + 0.034), (math.cos(a) * (r + w), math.sin(a) * (r + w), ISLAND_TOP + 0.034)]
        parts.append(_up(sb._mesh("risco%d" % k, verts, [(i * 2, i * 2 + 1, i * 2 + 3, i * 2 + 2) for i in range(seg)], m["sand_d"])))
    z = ISLAND_TOP + 0.02
    parts.append(_starfish("estrela", (0.95, -0.85, 0.0), 0.34, m["star"], 0.3, z))
    parts.append(_starfish("estrela_b", (-1.25, 1.0, 0.0), 0.2, m["coral"], 1.1, z))
    parts.append(_scallop("concha_a", (-0.9, -1.1), 0.3, m, 0.5, z))
    parts.append(_scallop("concha_b", (1.2, 0.95), 0.22, m, -2.2, z))
    # búzio: cone deitado
    parts.append(sb._cone("buzio", (-0.2, 1.45, z + 0.1), (0.22, 1.62, z + 0.03), 0.11, m["shell_d"], 5))
    parts.append(sb._cone("buzio_b", (-0.2, 1.45, z + 0.1), (-0.3, 1.41, z + 0.09), 0.11, m["shell"], 5))
    # coral na beira
    cx, cy = -1.75, -0.35
    for k, (dx, dy, h, r) in enumerate(((0.0, 0.0, 0.5, 0.1), (0.2, 0.08, 0.36, 0.08), (-0.14, 0.16, 0.4, 0.08), (0.05, -0.2, 0.3, 0.075))):
        parts.append(sb._cone("coral%d" % k, (cx + dx * 0.5, cy + dy * 0.5, 0.06), (cx + dx * 1.5, cy + dy * 1.5, h), r, m["coral"], 4, r * 0.55))
    # seixos
    for k, (x, y, s) in enumerate(((1.7, -0.2, 0.17), (1.5, 0.05, 0.11), (0.2, -1.7, 0.13))):
        parts.append(sb._plate("seixo%d" % k, sb._blob(70 + k, 5, s, 0.2, 0.8, k * 1.3), z - 0.02, z + s * 0.6, m["pebble"], (x, y), 0.35, 0.2, k))
    # capim de praia
    gx, gy = 0.35, 0.6
    for k in range(6):
        a = math.tau * k / 6 + 0.3
        lean = 0.2 + 0.1 * (k % 2)
        parts.append(sb._cone("capim%d" % k, (gx + math.cos(a) * 0.07, gy + math.sin(a) * 0.07, z - 0.02),
                              (gx + math.cos(a) * lean, gy + math.sin(a) * lean, z + 0.5 - 0.14 * (k % 3)), 0.05, m["grass"], 3))
    return parts


# ---------------------------------------------------------------------------
# 2. Mãe das Marés: anel de onda
# ---------------------------------------------------------------------------
def tide_floodring(m=None):
    """Anel de onda (2,6 m a 3,4 m): crista de espuma branca virada para a ilha (z 0,15), costas de água clara,
    barra de fora escura e recortada, flocos de espuma. Gira/escala à vontade (simétrico em 12 gomos)."""
    m = m or MM()
    n = 24
    rnd = random.Random(12)
    ch = [0.15 if i % 2 == 0 else 0.1 for i in range(n)]
    cr = [2.8 if i % 2 == 0 else 2.72 for i in range(n)]
    out = [3.4 if i % 2 == 0 else 3.22 for i in range(n)]

    def prof(i):
        return [(2.6, 0.02), (cr[i], ch[i]), (3.02, 0.06), (out[i], 0.02)]

    parts = [_up(_rings("onda", prof, n, [m["foam"], m["water"], m["water_d"]], [0, 1, 2]))]
    for k in range(8):
        a = math.tau * (k + 0.5) / 8 + rnd.uniform(-0.1, 0.1)
        r = 3.08 + 0.1 * (k % 2)
        s = 0.11 + 0.04 * (k % 3)
        parts.append(_poly("floco%d" % k, [(s, 0), (0, s * 2.2), (-s, 0), (0, -s * 2.2)], 0.075, m["foam"], (math.cos(a) * r, math.sin(a) * r), a))
    return parts


# ---------------------------------------------------------------------------
# 3. Grukk: tambor de guerra
# ---------------------------------------------------------------------------
def _bone_stick(name, a, b, m):
    a, b = Vector(a), Vector(b)
    d = (b - a).normalized()
    parts = [ck.tube(name, a, b, 0.04, 0.05, m["bone"], 5)]
    parts.append(pk.B(name + "_no_a", (0.13, 0.13, 0.13), a, m["hide_d"], 0.0, 0.6))      # cabeça embrulhada em couro
    parts.append(pk.B(name + "_no_b", (0.16, 0.09, 0.09), b + d * 0.02, m["bone_d"], 0.0, math.atan2(d.y, d.x) + math.pi / 2))
    return parts


def grukk_wardrum(m=None):
    """Tambor de guerra do Agitador-Mor (frente -Y, ~1,8 m no topo das presas): barril de toras com faixa vermelha e
    aros de ferro, inclinado para a frente; couro com o olho vermelho da Horda; cavalete em X de toras, duas presas
    grandes subindo dos lados, caveira na frente e duas nos cavaletes; duas baquetas de osso em cima do couro."""
    m = m or MM()
    n = 10
    drum = []

    def body(i):
        return [(0.58, 0.0), (0.74, 0.34), (0.7, 0.7)]

    drum.append(_rings("corpo", body, n, [m["wood"], m["wood_l"]], [0, 1]))
    for p in drum[0].data.polygons:                    # de fora
        if p.normal.dot(Vector((p.center.x, p.center.y, 0.0))) < 0.0:
            p.flip()
    drum.append(sb._flat("fundo", [(math.cos(-math.tau * i / n) * 0.58, math.sin(-math.tau * i / n) * 0.58) for i in range(n)], 0.0, m["wood"]))

    def band(name, r0, z0, r1, z1, mat):
        o = _rings(name, lambda i: [(r0, z0), (r1, z1)], n, [mat], [0])
        for p in o.data.polygons:
            if p.normal.dot(Vector((p.center.x, p.center.y, 0.0))) < 0.0:
                p.flip()
        return o

    drum.append(band("faixa", 0.735, 0.22, 0.765, 0.4, m["red"]))
    drum.append(band("aro", 0.61, 0.04, 0.65, 0.12, m["iron"]))
    # couro: tampo + saia em pontas
    drum.append(sb._flat("couro", [(math.cos(math.tau * i / n) * 0.76, math.sin(math.tau * i / n) * 0.76) for i in range(n)], 0.73, m["hide"]))
    verts, faces = [], []
    for i in range(n * 2):
        a = math.tau * i / (n * 2)
        r = 0.76 / math.cos(math.pi / n) if i % 2 else 0.76
        r = 0.76 if i % 2 == 0 else 0.76 * math.cos(math.pi / n)
        verts += [(math.cos(a) * r, math.sin(a) * r, 0.73), (math.cos(a) * (r + 0.025), math.sin(a) * (r + 0.025), 0.56 if i % 2 == 0 else 0.44)]
    for i in range(n * 2):
        a, b = i * 2, ((i + 1) % (n * 2)) * 2
        faces.append((a, a + 1, b + 1, b))
    skirt = sb._mesh("couro_saia", verts, faces, m["hide_d"])
    for p in skirt.data.polygons:
        if p.normal.dot(Vector((p.center.x, p.center.y, 0.0))) < 0.0:
            p.flip()
    drum.append(skirt)
    # olho da Horda no couro: amêndoa vermelha, pupila em fenda, 3 cílios em cima e 3 embaixo
    ze = 0.74
    drum.append(_poly("olho", [(-0.56, 0.0), (-0.3, -0.17), (0.0, -0.23), (0.3, -0.17), (0.56, 0.0), (0.3, 0.17), (0.0, 0.23), (-0.3, 0.17)], ze, m["red"], (0, -0.05)))
    drum.append(_poly("pupila", [(0.0, -0.21), (0.075, 0.0), (0.0, 0.21), (-0.075, 0.0)], ze + 0.008, m["black"], (0, -0.05)))
    for k, x in enumerate((-0.26, 0.0, 0.26)):
        drum.append(_poly("cilio_b%d" % k, [(x - 0.075, -0.3 + abs(x) * 0.22), (x + 0.075, -0.3 + abs(x) * 0.22), (x * 1.3, -0.52 + abs(x) * 0.5)], ze, m["red"], (0, -0.05)))
    # baquetas de osso, cruzadas na metade de trás, sobrando para fora da borda
    drum += _bone_stick("baqueta_a", (-0.2, 0.3, 0.8), (0.72, 0.62, 0.8), m)
    drum += _bone_stick("baqueta_b", (0.12, 0.52, 0.86), (-0.74, 0.34, 0.86), m)
    tilt = Matrix.Translation((0.0, 0.05, 0.52)) @ Matrix.Rotation(math.radians(24.0), 4, "X")
    _xform(drum, tilt)
    parts = list(drum)
    # cavalete: X de toras de cada lado + eixo
    for sx in (-1, 1):
        x = sx * 0.86
        parts.append(ck.tube("tora_a%d" % sx, (x, -0.72, 0.06), (x, 0.56, 1.34), 0.075, 0.06, m["wood_l"], 5))
        parts.append(ck.tube("tora_b%d" % sx, (x + sx * 0.1, 0.78, 0.06), (x + sx * 0.1, -0.5, 1.0), 0.075, 0.06, m["wood"], 5))
        # presa grande subindo do topo do cavalete, curvando para dentro
        parts += sb._horn("presa%d" % sx, (x, 0.5, 1.2), (sx * 1.06, 0.52, 1.62), (sx * 0.72, 0.4, 1.9), 0.1, m["bone"])
        # caveira pequena na ponta da tora da frente
        parts += sb._skull("caveira%d" % sx, (x + sx * 0.1, -0.56, 1.1), 0.14, m, -1.0, None, False)
        # trapo vermelho pendurado
        parts.append(sb._slab("trapo%d" % sx, [(sx * 0.9, 1.0), (sx * 1.08, 1.0), (sx * 1.1, 0.5), (sx * 1.0, 0.62), (sx * 0.94, 0.4)], -0.42, -0.39, m["red"]))
    parts.append(ck.tube("eixo", (-0.98, 0.1, 0.72), (0.98, 0.1, 0.72), 0.06, 0.06, m["wood"], 5))
    # caveira grande na frente do barril
    parts += sb._skull("caveira_f", (0.0, -0.84, 0.6), 0.2, m, -1.0, m["red"])
    for sx in (-1, 1):
        parts += sb._horn("caveira_f_presa%d" % sx, (sx * 0.12, -0.9, 0.46), (sx * 0.26, -0.98, 0.5), (sx * 0.3, -1.0, 0.72), 0.05, m["bone_d"], 4)
    return parts


# ---------------------------------------------------------------------------
# 4. Vorgul: Marca do Atirador
# ---------------------------------------------------------------------------
BRAND_Z = 0.05


def _arc(name, a0, a1, r0, r1, z, mat, seg=6):
    verts = []
    for i in range(seg + 1):
        a = a0 + (a1 - a0) * i / seg
        verts += [(math.cos(a) * r0, math.sin(a) * r0, z), (math.cos(a) * r1, math.sin(a) * r1, z)]
    return _up(sb._mesh(name, verts, [(i * 2, i * 2 + 1, i * 2 + 3, i * 2 + 2) for i in range(seg)], mat))


def vorgul_brand(m=None):
    """Retícula de besta chapada no chão (raio 1 m, z 0,05; escale X/Z pelo raio da explosão e gire devagar):
    anel vermelho em 4 arcos com contorno escuro, 4 entalhes em cunha nos eixos, anel interno e o glifo do virote
    apontando para -Y. `brand_arrow` (nó à parte, origem no chão): virote de pé apontando para baixo, ponta a 2,0 m."""
    m = m or MM()
    parts = []
    gap = math.radians(9.0)
    for k in range(4):
        a0 = math.pi / 4 + k * math.pi / 2 + gap
        a1 = a0 + math.pi / 2 - 2 * gap
        parts.append(_arc("contorno%d" % k, a0 - 0.03, a1 + 0.03, 0.8, 1.0, BRAND_Z - 0.01, m["brand_dark"]))
        parts.append(_arc("anel%d" % k, a0, a1, 0.85, 0.97, BRAND_Z, m["brand"]))
        # entalhe: cunha apontando para o centro, atravessa o anel
        a = k * math.pi / 2
        parts.append(_poly("entalhe_c%d" % k, [(1.0, -0.17), (1.0, 0.17), (0.5, 0.0)], BRAND_Z, m["brand_dark"], rot=a))
        parts.append(_poly("entalhe%d" % k, [(0.99, -0.11), (0.99, 0.11), (0.58, 0.0)], BRAND_Z + 0.01, m["brand_hot"], rot=a))
        # losango na diagonal (fecha o vão entre os arcos)
        parts.append(_poly("rebite%d" % k, [(0.91, -0.07), (1.0, 0.0), (0.91, 0.07), (0.82, 0.0)], BRAND_Z, m["brand"], rot=a + math.pi / 4))
    parts.append(_arc("miolo", 0.0, math.tau, 0.4, 0.46, BRAND_Z, m["brand"], 16))
    # glifo do virote (aponta para -Y)
    z = BRAND_Z + 0.01
    parts.append(_poly("glifo_haste", [(-0.035, 0.26), (-0.035, -0.12), (0.035, -0.12), (0.035, 0.26)], z, m["brand_hot"]))
    parts.append(_poly("glifo_ponta", [(-0.14, -0.08), (0.0, -0.34), (0.14, -0.08), (0.0, -0.14)], z, m["brand_hot"]))
    for sx in (-1, 1):
        parts.append(_poly("glifo_pena%d" % sx, [(sx * 0.035, 0.12), (sx * 0.14, 0.22), (sx * 0.14, 0.34), (sx * 0.035, 0.24)], z, m["brand_hot"]))
    # virote no ar (nó à parte)
    arrow = [sb._cone("virote_ponta", (0, 0, 2.42), (0, 0, 2.0), 0.17, m["brand_hot"], 4),
             ck.tube("virote_haste", (0, 0, 2.4), (0, 0, 3.0), 0.045, 0.045, m["brand"], 5)]
    fin = [(0.045, 2.72), (0.24, 2.9), (0.24, 3.1), (0.045, 2.98), (-0.045, 2.98), (-0.24, 3.1), (-0.24, 2.9), (-0.045, 2.72)]
    arrow.append(sb._slab("virote_pena_x", fin, -0.015, 0.015, m["brand"]))
    f2 = sb._slab("virote_pena_y", fin, -0.015, 0.015, m["brand"])
    f2.data.transform(Matrix.Rotation(math.pi / 2, 4, "Z"))
    arrow.append(f2)
    for o in arrow:
        o["node"] = "brand_arrow"
        o["pivot"] = (0.0, 0.0, 0.0)
    return parts + arrow


BUILDERS = {"tide_island": tide_island, "tide_floodring": tide_floodring, "grukk_wardrum": grukk_wardrum, "vorgul_brand": vorgul_brand}
TRI_MAX = 600


def build(kind):
    """Monta um prop na cena ativa (LIMPA a cena antes: só em arquivo vazio / -b --factory-startup)."""
    ck.clear()
    return BUILDERS[kind](MM())


def build_all(out_dir, only=None):
    os.makedirs(out_dir, exist_ok=True)
    for kind in BUILDERS:
        if only and kind not in only:
            continue
        build(kind)
        path = os.path.join(out_dir, "prop_%s.glb" % kind)
        pk.export_scene(path, "prop_" + kind, kind)
        ob = [o for o in bpy.context.scene.objects if o.type == "MESH"]
        lo = [min((o.matrix_world @ v.co)[k] for o in ob for v in o.data.vertices) for k in range(3)]
        hi = [max((o.matrix_world @ v.co)[k] for o in ob for v in o.data.vertices) for k in range(3)]
        tris = sb._tris(ob)
        print("SIG_PROP %s tris=%d%s kb=%.1f mesh=%s mats=%s bbox=%s..%s" % (
            path, tris, " OVER_BUDGET" if tris >= TRI_MAX else "", os.path.getsize(path) / 1024.0,
            ["%s:%d" % (o.name, sb._tris([o])) for o in ob], sorted({mt.name for o in ob for mt in o.data.materials}),
            [round(x, 2) for x in lo], [round(x, 2) for x in hi]))
    print("sig props c done")


# ---------------------------------------------------------------------------
# prévia 2x2 (igual à de sig_props_b): duas no ângulo do jogo (52°) em cima, duas de lado embaixo; cilindro rosa de 1,7 m
# ---------------------------------------------------------------------------
VIEWS = ((0.0, 6.0), (62.0, 14.0), (45.0, 52.0), (225.0, 52.0))
GROUND = {"tide_island": (0.22, 0.47, 0.72), "tide_floodring": (0.25, 0.3, 0.38), "grukk_wardrum": (0.6, 0.5, 0.4), "vorgul_brand": (0.42, 0.33, 0.3)}


def _context(kind):
    """Vizinhança só da prévia (não vai para o GLB)."""
    if kind == "tide_floodring":
        sb._flat("prev_ilha", [(math.cos(math.tau * i / 18) * 2.5, math.sin(math.tau * i / 18) * 2.5) for i in range(18)], 0.1, ck.mat("prev_sand", SAND, 0.95))


def preview(kind, out_png, res=(880, 660)):
    import numpy as np
    parts = build(kind)
    _context(kind)
    sc = bpy.context.scene
    lo = Vector([min((o.matrix_world @ v.co)[k] for o in parts for v in o.data.vertices) for k in range(3)])
    hi = Vector([max((o.matrix_world @ v.co)[k] for o in parts for v in o.data.vertices) for k in range(3)])
    pink = ck.mat("prev_pink", (1.0, 0.45, 0.75), 0.9)
    ck.tube("prev_scale", (hi.x + 0.6, 0, 0), (hi.x + 0.6, 0, 1.7), 0.3, 0.3, pink, 12)
    pk.B("prev_ground", (60, 60, 0.02), (0, 0, -0.012), ck.mat("prev_ground_%s" % kind, GROUND[kind], 0.9), 0.0)
    hi.x += 0.9
    hi.z = max(hi.z, 1.7)
    center = (lo + hi) * 0.5
    size = (hi - lo).length
    cam = bpy.data.objects.new("prev_cam", bpy.data.cameras.new("prev_cam"))
    sc.collection.objects.link(cam)
    cam.data.lens = 50
    sc.camera = cam
    try:
        sc.render.engine = "BLENDER_EEVEE"
    except TypeError:
        sc.render.engine = "BLENDER_EEVEE_NEXT"
    sun = bpy.data.objects.new("prev_sun", bpy.data.lights.new("prev_sun", "SUN"))
    sc.collection.objects.link(sun)
    sun.data.energy = 1.7
    sun.data.angle = 0.05
    sun.rotation_euler = (math.radians(42), 0.0, math.radians(-35))
    world = bpy.data.worlds.new("prev_world")
    world.use_nodes = True
    bg = next(n for n in world.node_tree.nodes if n.type == "BACKGROUND")
    bg.inputs[0].default_value = (0.75, 0.78, 0.9, 1.0)
    bg.inputs[1].default_value = 0.4
    sc.world = world
    sc.view_settings.view_transform = "Standard"
    sc.render.resolution_x, sc.render.resolution_y = res
    sc.render.resolution_percentage = 100
    sc.render.image_settings.file_format = "PNG"
    for mt in bpy.data.materials:                      # como no jogo: face de costas não aparece (pega normal virada)
        mt.use_backface_culling = True
    tiles = []
    for i, (yaw, el) in enumerate(VIEWS):
        ya, ea = math.radians(yaw), math.radians(el)
        d = Vector((math.sin(ya) * math.cos(ea), -math.cos(ya) * math.cos(ea), math.sin(ea)))
        cam.location = center + d * (size * 1.25 + 1.0)
        cam.rotation_euler = (-d).to_track_quat("-Z", "Y").to_euler()
        tmp = out_png[:-4] + "_v%d.png" % i
        sc.render.filepath = tmp
        bpy.ops.render.render(write_still=True)
        img = bpy.data.images.load(tmp)
        px = np.empty(res[0] * res[1] * 4, dtype=np.float32)
        img.pixels.foreach_get(px)
        tiles.append(px.reshape(res[1], res[0], 4))
        bpy.data.images.remove(img)
        os.remove(tmp)
    sheet = np.concatenate([np.concatenate([tiles[2], tiles[3]], axis=1), np.concatenate([tiles[0], tiles[1]], axis=1)], axis=0)
    out = bpy.data.images.new("prev_sheet", res[0] * 2, res[1] * 2)
    out.pixels.foreach_set(sheet.ravel())
    out.filepath_raw = out_png
    out.file_format = "PNG"
    out.save()
    bpy.data.images.remove(out)
    print("SIG_PREVIEW %s tris=%d" % (out_png, sb._tris(parts)))


def preview_all(out_dir, only=None):
    os.makedirs(out_dir, exist_ok=True)
    for kind in BUILDERS:
        if only and kind not in only:
            continue
        preview(kind, os.path.join(out_dir, "prop_%s_preview.png" % kind))
    ck.clear()


if __name__ == "__main__":
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    opt = dict(a[2:].split("=", 1) for a in argv if a.startswith("--") and "=" in a)
    only = opt["only"].split(",") if opt.get("only") else None
    if "preview" in opt:
        preview_all(opt["preview"], only)
    if "out" in opt or "preview" not in opt:
        build_all(opt.get("out", os.path.normpath(os.path.join(HERE, "..", "..", "assets", "models"))), only)
