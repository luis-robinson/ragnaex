"""Marcas das mecânicas-assinatura dos chefes de Kharzun (GDD act2-boss-signatures §3.8, §3.10, §3.11), parte B.
Cada uma sai como GLB estático em assets/models/ (1 malha, uma superfície por material, sem textura, < 700 tris):

    prop_kragmar_lavapool      Têmpera na Lava: poça que fica no chão. Raio de fora 2,5 m; lava a z = 0,03.
    prop_durgash_throneaxe     Machado do Trono: machado de guerra de ~3,2 m, cabeça para baixo; origem = ponta no chão.
    prop_ulgra_stampede        Estouro da Matilha: faixa de 3 m (X) x 10 m (Y), galope para -Y; as pontas emendam (dá para repetir).
    prop_horde_warbanner_sig   Estandarte de guerra da Horda (~4,4 m), frente = -Y.

Tamanho real (1 u = 1 m), origem no chão, no centro. Materiais: `glow_*` brilham no jogo (convenção do map_builder),
`tint` é a cor que o jogo pode trocar (setas da faixa, pano do estandarte), `p_*` são cores fixas.

    blender -b --factory-startup --python sig_props_b.py -- [--out=<assets/models>] [--preview=<pasta>] [--only=a,b]
"""
import math
import os
import random
import sys

import bpy
import bmesh
from mathutils import Vector, Matrix

HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
    sys.path.append(HERE)

import chibi_kit as ck
import prop_kit as pk

# paleta de Kharzun (igual a zones/act2_dress.py KH_* e zones/horde.py)
KH_BASALT = (0.3, 0.28, 0.31)
KH_BASALT_TOP = (0.42, 0.4, 0.44)
KH_LAVA = (1.0, 0.46, 0.14)
KH_CORE = (1.0, 0.8, 0.32)
KH_CRUST = (0.2, 0.15, 0.14)
HORDE_RED = (0.72, 0.16, 0.13)
BONE = (0.9, 0.87, 0.78)


def MM():
    """Materiais (não usa prop_kit.M(): lá `tint` nasce verde e o nome fica preso)."""
    return {
        "lava": ck.mat("glow_lava", KH_LAVA, 0.4, 0.5),
        "core": ck.mat("glow_lava_miolo", KH_CORE, 0.4, 0.6),
        "basalt": ck.mat("p_kh_basalt", KH_BASALT, 0.9),
        "basalt_top": ck.mat("p_kh_basalt_top", KH_BASALT_TOP, 0.9),
        "crust": ck.mat("p_kh_crust", KH_CRUST, 0.9),
        "bone": ck.mat("p_bone", BONE, 0.85),
        "bone_d": ck.mat("p_bone_d", (0.72, 0.66, 0.55), 0.85),
        "iron": ck.mat("p_iron_d", (0.27, 0.26, 0.3), 0.5),
        "steel": ck.mat("p_steel", (0.74, 0.75, 0.8), 0.4),
        "wood": ck.mat("p_wood_d", (0.36, 0.24, 0.16), 0.85),
        "red": ck.mat("p_horde_red", HORDE_RED, 0.85),
        "red_d": ck.mat("p_horde_red_d", (0.46, 0.1, 0.1), 0.85),
        "black": ck.mat("p_horde_black", (0.12, 0.1, 0.11), 0.9),
        "gold": ck.mat("glow_trono", (1.0, 0.78, 0.3), 0.4, 0.6),
        "dust": ck.mat("p_dust", (0.86, 0.77, 0.63), 0.95),
        "dust_l": ck.mat("p_dust_l", (0.97, 0.93, 0.84), 0.95),
        "dust_d": ck.mat("p_dust_d", (0.56, 0.44, 0.33), 0.95),
        "paw": ck.mat("p_dust_paw", (0.27, 0.2, 0.17), 0.95),
    }


def _tint(color):
    """Material `tint` (cor que o jogo troca). O nome é um só no arquivo: acerta a cor a cada prop."""
    t = ck.mat("tint", color, 0.85)
    bsdf = next(n for n in t.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    bsdf.inputs["Base Color"].default_value = (*color, 1.0)
    t.diffuse_color = (*color, 1.0)
    return t


# ---------------------------------------------------------------------------
# formas
# ---------------------------------------------------------------------------
def _mesh(name, verts, faces, mats, idx=None, recalc=False):
    """Malha facetada de listas. `mats` = material ou lista; `idx` = material de cada face."""
    bm = bmesh.new()
    vs = [bm.verts.new(v) for v in verts]
    made = []
    for k, f in enumerate(faces):
        try:
            face = bm.faces.new([vs[i] for i in f])
        except ValueError:
            continue
        if idx:
            face.material_index = idx[k]
        made.append(face)
    if recalc:
        bmesh.ops.recalc_face_normals(bm, faces=made)
    mats = mats if isinstance(mats, (list, tuple)) else [mats]
    o = ck.mesh_from(name, bm, mats[0])
    for m in mats[1:]:
        o.data.materials.append(m)
    return o


def _blob(seed, n, r, jitter=0.18, squash=1.0, rot=0.0):
    """Contorno irregular (anti-horário) de n pontas."""
    rnd = random.Random(seed)
    out = []
    for i in range(n):
        a = rot + math.tau * (i + rnd.uniform(-0.22, 0.22)) / n
        rr = r * (1.0 + rnd.uniform(-jitter, jitter))
        out.append((math.cos(a) * rr, math.sin(a) * rr * squash))
    return out


def _flat(name, pts, z, mat, c=(0.0, 0.0)):
    """Polígono deitado (leque), normal para cima."""
    verts = [(c[0], c[1], z)] + [(c[0] + x, c[1] + y, z) for x, y in pts]
    n = len(pts)
    return _mesh(name, verts, [(0, 1 + i, 1 + (i + 1) % n) for i in range(n)], mat)


def _plate(name, pts, z0, z1, mat, c=(0.0, 0.0), inset=0.2, tilt=0.0, seed=0):
    """Placa/pedra: contorno em z0, topo encolhido em z1 (inclinado), sem fundo."""
    rnd = random.Random(seed)
    n = len(pts)
    ta = rnd.uniform(0, math.tau)
    verts = [(c[0] + x, c[1] + y, z0) for x, y in pts]
    for x, y in pts:
        tx, ty = x * (1.0 - inset), y * (1.0 - inset)
        verts.append((c[0] + tx, c[1] + ty, z1 + tilt * (tx * math.cos(ta) + ty * math.sin(ta))))
    verts.append((c[0], c[1], z1))
    faces = [(i, (i + 1) % n, n + (i + 1) % n, n + i) for i in range(n)]
    faces += [(2 * n, n + i, n + (i + 1) % n) for i in range(n)]
    return _mesh(name, verts, faces, mat)


def _cone(name, a, b, r, mat, sides=5, r_tip=0.0):
    """Espinho/presa de a (base) até b (ponta)."""
    a, b = Vector(a), Vector(b)
    q = Vector((0, 0, 1)).rotation_difference((b - a).normalized())
    ring = [a + q @ Vector((math.cos(i * math.tau / sides) * r, math.sin(i * math.tau / sides) * r, 0.0)) for i in range(sides)]
    if r_tip <= 0.0:
        verts = ring + [b]
        faces = [(i, (i + 1) % sides, sides) for i in range(sides)]
    else:
        top = [b + q @ Vector((math.cos(i * math.tau / sides) * r_tip, math.sin(i * math.tau / sides) * r_tip, 0.0)) for i in range(sides)]
        verts = ring + top
        faces = [(i, (i + 1) % sides, sides + (i + 1) % sides, sides + i) for i in range(sides)] + [tuple(range(sides, 2 * sides))]
    return _mesh(name, verts, faces, mat)


def _horn(name, a, mid, b, r, mat, sides=5):
    """Presa curva em dois gomos."""
    return [_cone(name + "_a", a, mid, r, mat, sides, r * 0.62), _cone(name + "_b", mid, b, r * 0.62, mat, sides)]


def _ico(name, r, center, mat, scale=(1, 1, 1), sub=1, cut_z=None, seed=None, amp=0.12):
    """Bola facetada (icosfera); `cut_z` corta o que fica abaixo (nuvem meio enterrada no chão)."""
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=sub, radius=1.0)
    rnd = random.Random(seed) if seed is not None else None
    for v in bm.verts:
        k = 1.0 + (rnd.uniform(-amp, amp) if rnd else 0.0)
        v.co = Vector((v.co.x * r * scale[0] * k, v.co.y * r * scale[1] * k, v.co.z * r * scale[2] * k)) + Vector(center)
    if cut_z is not None:
        dead = [f for f in bm.faces if all(v.co.z <= cut_z + 1e-4 for v in f.verts)]
        bmesh.ops.delete(bm, geom=dead, context="FACES")
        for v in bm.verts:
            v.co.z = max(v.co.z, cut_z)
    return ck.mesh_from(name, bm, mat)


def _slab(name, pts, y0, y1, mat):
    """Chapa de pé: contorno no plano XZ (lista de (x, z)), de y0 a y1."""
    bm = bmesh.new()
    front = [bm.verts.new((x, y0, z)) for x, z in pts]
    back = [bm.verts.new((x, y1, z)) for x, z in pts]
    n = len(pts)
    bm.faces.new(front)
    bm.faces.new(back[::-1])
    for i in range(n):
        bm.faces.new((front[i], back[i], back[(i + 1) % n], front[(i + 1) % n]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    return ck.mesh_from(name, bm, mat)


def _decal(name, pts, y, sgn, mat):
    """Figura chapada no plano XZ (uma face só), virada para o lado `sgn` em Y."""
    bm = bmesh.new()
    f = bm.faces.new([bm.verts.new((x, y, z)) for x, z in pts])
    if (f.normal.y > 0) != (sgn > 0):
        f.normal_flip()
    return ck.mesh_from(name, bm, mat)


def _skull(prefix, c, r, m, face=-1.0, eyes=None, jaw=True):
    """Caveira chibi: crânio facetado, queixo em bloco, olhos fundos. `face` = lado do rosto em Y."""
    c = Vector(c)
    parts = [_ico(prefix + "_cranio", r, c, m["bone"], (1.0, 0.92, 0.95))]
    if jaw:
        parts.append(pk.B(prefix + "_queixo", (r * 1.05, r * 0.9, r * 0.6), c + Vector((0, face * r * 0.2, -r * 0.85)), m["bone_d"], 0.0))
    em = eyes or m["black"]
    for sx in (-1, 1):
        parts.append(pk.B(prefix + "_olho%d" % sx, (r * 0.42, r * 0.2, r * 0.42), c + Vector((sx * r * 0.4, face * r * 0.8, -r * 0.05)), em, 0.0))
    return parts


# ---------------------------------------------------------------------------
# 1. Kragmar: poça de lava
# ---------------------------------------------------------------------------
LAVA_Z = 0.03


def kragmar_lavapool(m=None):
    """Poça de lava que fica (raio de fora 2,5 m): disco laranja com miolo claro, borda de basalto em gomos,
    placas de crosta esfriando e bolhas. De cima: anel escuro + laranja + amarelo, lê até em chão vermelho."""
    m = m or MM()
    rnd = random.Random(44)
    parts = [_flat("lava", _blob(3, 12, 2.2, 0.03), LAVA_Z, m["lava"])]
    # miolo quente: duas manchas claras fora do centro
    parts.append(_flat("miolo_a", _blob(5, 9, 1.25, 0.16, 0.8, 0.4), LAVA_Z + 0.012, m["core"], (-0.25, 0.2)))
    parts.append(_flat("miolo_b", _blob(8, 6, 0.48, 0.14), LAVA_Z + 0.012, m["core"], (1.15, -0.95)))
    # borda: anel em gomos (dentro queimado, fora basalto), crista de altura irregular
    n = 14
    verts, faces, idx = [], [], []
    for i in range(n):
        a = math.tau * i / n
        ca, sa = math.cos(a), math.sin(a)
        r_in = 1.92 + rnd.uniform(-0.1, 0.08)
        r_top = 2.2 + rnd.uniform(-0.05, 0.06)
        h = 0.3 + rnd.uniform(-0.1, 0.16)
        verts += [(ca * r_in, sa * r_in, 0.0), (ca * r_top, sa * r_top, h), (ca * 2.5, sa * 2.5, 0.0)]
    for i in range(n):
        a, b = i * 3, ((i + 1) % n) * 3
        faces += [(a, b, b + 1, a + 1), (a + 1, b + 1, b + 2, a + 2)]
        idx += [0, 1]
    parts.append(_mesh("borda", verts, faces, [m["crust"], m["basalt"]], idx))
    # pedras claras sentadas na crista (quebra o anel perfeito)
    for k, a in enumerate((0.35, 1.5, 2.75, 3.9, 5.2)):
        r = 2.2 + rnd.uniform(-0.05, 0.05)
        parts.append(_plate("pedra%d" % k, _blob(20 + k, 5, 0.36 + 0.07 * (k % 2), 0.2, 0.8, a), 0.12, 0.5 + 0.08 * (k % 3), m["basalt_top"],
                            (math.cos(a) * r, math.sin(a) * r), 0.3, 0.25, k))
    # placas de crosta boiando: escuras com a borda de cima mais clara
    for k, (a, r, s) in enumerate(((0.9, 1.25, 0.5), (2.3, 1.35, 0.42), (3.5, 0.9, 0.36), (4.5, 1.4, 0.52), (5.75, 0.75, 0.34))):
        c = (math.cos(a) * r, math.sin(a) * r)
        pts = _blob(40 + k, 5 + k % 2, s, 0.22, 0.85, a)
        parts.append(_plate("crosta%d" % k, pts, LAVA_Z, LAVA_Z + 0.09, m["crust"], c, 0.18, 0.08, k))
        parts.append(_flat("crosta_topo%d" % k, [(x * 0.6, y * 0.6) for x, y in pts], LAVA_Z + 0.1, m["basalt"], c))
    # bolhas
    for k, (x, y, r) in enumerate(((-0.3, -0.75, 0.2), (0.45, 0.55, 0.15), (-1.0, 0.45, 0.13))):
        parts.append(_cone("bolha%d" % k, (x, y, LAVA_Z), (x, y, LAVA_Z + r * 0.7), r, m["core"], 6, r * 0.45))
    return parts


# ---------------------------------------------------------------------------
# 2. Durgash: Machado do Trono
# ---------------------------------------------------------------------------
def _axe_blade(name, sx, cz, m):
    """Lâmina da família nova (axe_kit.blade_parts, cabeça "double" como a do machado do Durgash, kharzun_mobs.DURGASH_AXE):
    olho estreito, leque até o fio, face de ferro escuro e bisel largo de aço claro. Plano XZ, cabeça para baixo.
    Escala 3,03: o fio fica a 1,15 m do cabo, como antes (a caixa do prop não muda em X). 6 fileiras: o prop tem teto de tris."""
    import axe_kit
    shape = dict(axe_kit.HEADS["double"], rows=6)
    return axe_kit.blade_parts(ck, name + "_", Vector((0, 0, cz)), Vector((0, 0, -1)), Vector((sx, 0, 0)), Vector((0, 1, 0)), 3.03, shape,
                               m["iron"], m["steel"])


def durgash_throneaxe(m=None):
    """Machado de guerra gigante de cabeça para baixo (~3,2 m): ponta de ferro no chão (origem), duas lâminas em
    crescente (±X), caveira com olhos dourados na cabeça, presas de osso, cabo com faixas e duas flâmulas vermelhas."""
    m = m or MM()
    cz = 1.0
    parts = [_cone("ponta", (0, 0, cz - 0.28), (0, 0, 0.0), 0.15, m["iron"], 4),
             pk.B("cabeca", (0.3, 0.3, 0.62), (0, 0, cz), m["iron"], 0.04)]
    for sx in (-1, 1):
        parts += _axe_blade("lamina%d" % sx, sx, cz, m)
        # runa dourada na lâmina (dos dois lados)
        for sy in (-1, 1):
            parts.append(_slab("runa%d_%d" % (sx, sy), [(sx * 0.36, cz - 0.26), (sx * 0.66, cz), (sx * 0.36, cz + 0.26), (sx * 0.5, cz)],
                               sy * 0.075, sy * 0.095, m["gold"]))
        # presa de osso saindo de cima da cabeça
        parts += _horn("presa%d" % sx, (sx * 0.1, 0, cz + 0.28), (sx * 0.36, 0, cz + 0.5), (sx * 0.42, 0, cz + 0.9), 0.085, m["bone"])
    for sy in (-1, 1):
        parts += _skull("caveira%d" % sy, (0, sy * 0.2, cz + 0.06), 0.19, m, float(sy), m["gold"])
    # cabo
    parts.append(ck.tube("cabo", (0, 0, cz + 0.3), (0, 0, 3.0), 0.085, 0.07, m["wood"], 6))
    for k, z in enumerate((1.46, 2.14, 2.96)):
        parts.append(ck.tube("anel%d" % k, (0, 0, z - 0.06), (0, 0, z + 0.06), 0.115, 0.115, m["iron"], 6))
    parts.append(ck.tube("faixa", (0, 0, 2.3), (0, 0, 2.8), 0.095, 0.09, m["red"], 6))
    # pomo: garra de osso
    parts.append(_cone("pomo", (0, 0, 3.0), (0, 0, 3.25), 0.1, m["bone"], 5))
    for sx in (-1, 1):
        parts += _horn("pomo_presa%d" % sx, (sx * 0.06, 0, 2.98), (sx * 0.26, 0, 3.02), (sx * 0.34, 0, 3.24), 0.06, m["bone"], 4)
    # flâmulas presas ao anel do meio, caindo para os lados
    for sx in (-1, 1):
        pts = [(sx * 0.1, 2.2), (sx * 0.42, 2.14), (sx * 0.74, 1.74), (sx * 0.86, 1.22), (sx * 0.68, 1.42), (sx * 0.56, 1.2), (sx * 0.36, 1.72)]
        parts.append(_slab("flamula%d" % sx, pts, -0.02, 0.02, m["red"]))
        parts.append(_slab("flamula_b%d" % sx, [(sx * 0.1, 2.12), (sx * 0.2, 2.1), (sx * 0.3, 1.9), (sx * 0.22, 1.62), (sx * 0.14, 1.78)], 0.05, 0.08, m["red_d"]))
    return parts


# ---------------------------------------------------------------------------
# 3. Ulgra: faixa do Estouro da Matilha
# ---------------------------------------------------------------------------
LANE_W, LANE_L = 3.0, 10.0


def _paw(name, c, s, mat, z):
    """Pegada de lobo apontando para -Y: almofada + 4 dedos."""
    parts = [_flat(name + "_palma", [(s * x, s * y) for x, y in ((0.0, 0.26), (-0.3, 0.12), (-0.26, -0.14), (0.0, -0.24), (0.26, -0.14), (0.3, 0.12))], z, mat, c)]
    for k, (x, y) in enumerate(((-0.36, -0.3), (-0.13, -0.5), (0.13, -0.5), (0.36, -0.3))):
        parts.append(_flat(name + "_dedo%d" % k, [(s * 0.1, 0.0), (0.0, s * 0.14), (-s * 0.1, 0.0), (0.0, -s * 0.16)], z, mat, (c[0] + s * x, c[1] + s * y)))
    return parts


def ulgra_stampede(m=None):
    """Faixa do estouro: 3 m (X) x 10 m (Y), galope para -Y. Chão pisado, 3 setas (`tint`), pegadas de lobo
    e nuvens baixas de poeira nas duas beiras. Pontas retas em y = ±5: emenda se for repetida."""
    m = m or MM()
    tint = _tint((1.0, 0.82, 0.5))
    rnd = random.Random(8)
    hw, hl = LANE_W * 0.5, LANE_L * 0.5
    # chão pisado, beira serrilhada
    rows = 11
    verts, faces = [], []
    for i in range(rows):
        y = -hl + LANE_L * i / (rows - 1)
        e = 0.0 if i in (0, rows - 1) else rnd.uniform(-0.12, 0.12)
        w = hw - 0.2 + (0.12 if i % 2 else -0.06)
        verts += [(-w + e, y, 0.02), (w + e * 0.5, y, 0.02)]
    for i in range(rows - 1):
        faces.append((i * 2, i * 2 + 1, i * 2 + 3, i * 2 + 2))
    parts = [_mesh("chao", verts, faces, m["dust_d"])]
    # setas
    for k, y in enumerate((3.35, 0.0, -3.35)):
        parts.append(_mesh("seta%d" % k, [(0, y - 1.0, 0.035), (1.0, y + 0.25, 0.035), (1.0, y + 0.85, 0.035), (0, y - 0.35, 0.035),
                                         (-1.0, y + 0.85, 0.035), (-1.0, y + 0.25, 0.035)], [(0, 1, 2, 3), (0, 3, 4, 5)], tint))
    # pegadas entre as setas
    for k, (x, y) in enumerate(((-0.5, 4.3), (0.5, 2.0), (-0.5, 1.2), (0.5, -1.3), (-0.5, -2.1), (0.5, -4.5))):
        parts += _paw("pata%d" % k, (x, y), 0.85, m["paw"], 0.045)
    # poeira: tufos baixos e redondos (sombreado liso) nas beiras; cada tufo = bola grande + bola menor atrás (+Y)
    for sx in (-1, 1):
        for i in range(7):
            y = -hl + 0.75 + i * 1.42 + (0.35 if sx > 0 else -0.2) * (i % 2)
            y = max(-hl + 0.55, min(hl - 1.0, y))
            r = 0.4 + 0.08 * ((i + (sx > 0)) % 3)
            x = sx * (hw - 0.36)
            puff = [_ico("poeira%d_%d" % (sx, i), r, (x, y, 0.1), m["dust_l"], (0.82, 1.0, 0.8), 1, 0.0, 100 + i + 10 * sx, 0.06),
                    _ico("poeira_b%d_%d" % (sx, i), r * 0.66, (x - sx * 0.12, y + r * 0.95, 0.05), m["dust"], (0.9, 1.1, 0.8), 1, 0.0, 200 + i + 10 * sx, 0.06)]
            for o in puff:
                ck._smooth(o.data)
            parts += puff
    return parts


# ---------------------------------------------------------------------------
# 4. Estandarte de guerra da Horda
# ---------------------------------------------------------------------------
def _emblem(prefix, y, sgn, m, eye):
    """Caveira com presas, chapada, para o pano (rosto para o lado `sgn` em Y)."""
    cz = 2.86
    parts = [_decal(prefix + "_cranio", [(0.38 * math.cos(a), cz + 0.32 * math.sin(a)) for a in [math.tau * i / 8 + math.tau / 16 for i in range(8)]], y, sgn, m["black"]),
             _decal(prefix + "_queixo", [(-0.2, cz - 0.5), (0.2, cz - 0.5), (0.24, cz - 0.24), (-0.24, cz - 0.24)], y, sgn, m["black"])]
    for sx in (-1, 1):
        parts.append(_decal(prefix + "_presa%d" % sx, [(sx * 0.2, cz - 0.46), (sx * 0.34, cz - 0.5), (sx * 0.46, cz - 0.08), (sx * 0.34, cz - 0.24)], y, sgn, m["black"]))
        parts.append(_decal(prefix + "_olho%d" % sx, [(sx * 0.06, cz - 0.02), (sx * 0.17, cz + 0.1), (sx * 0.29, cz + 0.04), (sx * 0.2, cz - 0.1)],
                            y + sgn * 0.008, sgn, eye))
    return parts


def horde_warbanner_sig(m=None):
    """Estandarte de guerra (~4,4 m, frente -Y): mastro em base de pedras, travessa com presas de osso, pano
    vermelho (`tint`) em rabo de andorinha com a caveira preta da Horda, caveira de chifres no topo e ponta de lança."""
    m = m or MM()
    tint = _tint(HORDE_RED)
    parts = []
    # base
    for k, a in enumerate((0.3, 1.9, 3.4, 4.8)):
        parts.append(_plate("base%d" % k, _blob(60 + k, 5, 0.3 + 0.05 * (k % 2), 0.2, 0.85, a), 0.0, 0.3 + 0.12 * (k % 2),
                            m["basalt"] if k % 2 else m["basalt_top"], (math.cos(a) * 0.3, math.sin(a) * 0.3), 0.3, 0.3, k))
    parts += _skull("base_caveira", (0.32, -0.42, 0.2), 0.17, m, -1.0)
    # mastro
    parts.append(ck.tube("mastro", (0, 0, 0), (0, 0, 4.0), 0.09, 0.065, m["wood"], 6))
    parts.append(ck.tube("anel", (0, 0, 3.5), (0, 0, 3.66), 0.1, 0.1, m["iron"], 6))
    parts.append(_cone("lanca", (0, 0, 4.0), (0, 0, 4.45), 0.12, m["iron"], 4))
    # travessa na frente do mastro, com presas subindo nas pontas
    yb = -0.13
    parts.append(ck.tube("travessa", (-0.92, yb, 3.58), (0.92, yb, 3.58), 0.06, 0.06, m["wood"], 6))
    for sx in (-1, 1):
        parts += _horn("presa%d" % sx, (sx * 0.84, yb, 3.58), (sx * 1.08, yb, 3.7), (sx * 1.14, yb, 4.08), 0.09, m["bone"])
        # tira rasgada e osso pendurado em cada ponta
        parts.append(_slab("tira%d" % sx, [(sx * 0.8, 3.54), (sx * 0.96, 3.54), (sx * 1.0, 2.95), (sx * 0.9, 3.1), (sx * 0.84, 2.8)], yb - 0.015, yb + 0.015, m["red_d"]))
        parts.append(ck.tube("osso%d" % sx, (sx * 0.9, yb - 0.05, 2.72), (sx * 0.9, yb - 0.05, 2.38), 0.035, 0.05, m["bone"], 4))
    # pano: reto na área do emblema, rabos jogados para a frente
    xs = (-0.74, -0.37, 0.0, 0.37, 0.74)
    zs = (3.56, 2.95, 2.25, 1.75)
    low = (1.3, 1.55, 2.0, 1.55, 1.3)
    yrow = (0.0, 0.0, -0.03, -0.16)
    bm = bmesh.new()
    grid = []
    for j, z in enumerate(zs):
        grid.append([bm.verts.new((x, yb - 0.02 + yrow[j] - (0.05 if j == 3 and i in (0, 4) else 0.0), low[i] if j == 3 else z)) for i, x in enumerate(xs)])
    fs = []
    for j in range(len(zs) - 1):
        for i in range(len(xs) - 1):
            fs.append(bm.faces.new((grid[j][i], grid[j + 1][i], grid[j + 1][i + 1], grid[j][i + 1])))
    bmesh.ops.recalc_face_normals(bm, faces=fs)
    bmesh.ops.solidify(bm, geom=fs, thickness=0.03)
    cloth = ck.mesh_from("pano", bm, tint)
    parts.append(cloth)
    ys = [v.co.y for v in cloth.data.vertices if v.co.z > 2.2]
    y_front, y_back = min(ys), max(ys)
    parts.append(pk.B("bainha", (1.54, y_back - y_front + 0.03, 0.16), (0, (y_front + y_back) * 0.5, 3.5), m["black"], 0.0))
    parts += _emblem("emb_f", y_front - 0.008, -1.0, m, tint)
    parts += _emblem("emb_t", y_back + 0.008, 1.0, m, tint)
    # caveira de chifres no topo, olhando para a frente
    parts += _skull("topo", (0, -0.14, 3.86), 0.2, m, -1.0)
    for sx in (-1, 1):
        parts += _horn("chifre%d" % sx, (sx * 0.14, -0.12, 3.92), (sx * 0.42, -0.12, 3.98), (sx * 0.52, -0.12, 4.3), 0.075, m["bone_d"])
    return parts


BUILDERS = {"kragmar_lavapool": kragmar_lavapool, "durgash_throneaxe": durgash_throneaxe,
            "ulgra_stampede": ulgra_stampede, "horde_warbanner_sig": horde_warbanner_sig}
TRI_MAX = 700


def _tris(objs):
    return sum(len(p.vertices) - 2 for o in objs for p in o.data.polygons)


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
        lo = [min(v.co[k] for o in ob for v in o.data.vertices) for k in range(3)]
        hi = [max(v.co[k] for o in ob for v in o.data.vertices) for k in range(3)]
        tris = _tris(ob)
        print("SIG_PROP %s tris=%d%s mesh=%s mats=%s bbox=%s..%s" % (
            path, tris, " OVER_BUDGET" if tris >= TRI_MAX else "", [o.name for o in ob], [mt.name for o in ob for mt in o.data.materials],
            [round(x, 2) for x in lo], [round(x, 2) for x in hi]))
    print("sig props b done")


# ---------------------------------------------------------------------------
# prévia 2x2: duas de lado + duas no ângulo do jogo (52°), cilindro rosa de 1,7 m de escala
# ---------------------------------------------------------------------------
VIEWS = ((0.0, 6.0), (62.0, 14.0), (45.0, 52.0), (225.0, 52.0))       # (giro em volta, elevação); giro 0 = de frente (-Y)
GROUND = {"kragmar_lavapool": (0.5, 0.17, 0.1)}                        # o chão da fundição é vermelho


def preview(kind, out_png, res=(880, 660)):
    import numpy as np
    parts = build(kind)
    sc = bpy.context.scene
    lo = Vector([min((o.matrix_world @ v.co)[k] for o in parts for v in o.data.vertices) for k in range(3)])
    hi = Vector([max((o.matrix_world @ v.co)[k] for o in parts for v in o.data.vertices) for k in range(3)])
    pink = ck.mat("prev_pink", (1.0, 0.45, 0.75), 0.9)
    ck.tube("prev_scale", (hi.x + 0.6, 0, 0), (hi.x + 0.6, 0, 1.7), 0.3, 0.3, pink, 12)
    gname = "prev_ground_%s" % kind
    pk.B("prev_ground", (60, 60, 0.02), (0, 0, -0.012), ck.mat(gname, GROUND.get(kind, KH_BASALT_TOP), 0.9), 0.0)
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
    print("SIG_PREVIEW %s tris=%d" % (out_png, _tris(parts)))


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
