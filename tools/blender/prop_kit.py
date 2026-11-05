"""Props e construções "esculpidos" (substitui as caixas de build_props): casas enxaimel com telhado
de telhas, árvores de copa em camadas, pedras irregulares, poço, chafariz, postes com lanterna...
Cada prop sai como GLB estático em assets/models/prop_<kind>.glb (o jogo ajusta ao tamanho do obstáculo).
Materiais "tint" (cor do obstáculo) e "roof" (cor do telhado) são recoloridos pelo jogo.

    import prop_kit; prop_kit.build_all(r"<pasta>/ragnaex/assets/models")
"""
import bpy
import bmesh
import importlib
import math
import os
import random
from mathutils import Vector, Matrix, noise

import chibi_kit as ck

importlib.reload(ck)

# ---------------------------------------------------------------------------
# materiais
# ---------------------------------------------------------------------------
def M():
    return {
        "stone": ck.mat("p_stone", (0.78, 0.75, 0.7), 0.9),
        "stone_d": ck.mat("p_stone_d", (0.6, 0.58, 0.55), 0.9),
        "stone_l": ck.mat("p_stone_l", (0.88, 0.85, 0.79), 0.9),
        "plaster": ck.mat("p_plaster", (0.95, 0.9, 0.8), 0.9),
        "wood": ck.mat("p_wood", (0.55, 0.38, 0.24), 0.85),
        "wood_d": ck.mat("p_wood_d", (0.36, 0.24, 0.16), 0.85),
        "wood_l": ck.mat("p_wood_l", (0.72, 0.55, 0.36), 0.85),
        "roof": ck.mat("roof", (0.8, 0.42, 0.34), 0.8),
        "tint": ck.mat("tint", (0.4, 0.66, 0.38), 0.8),
        "tint_l": ck.mat("tint_l", (0.55, 0.78, 0.42), 0.8),
        "leaf_l": ck.mat("p_leaf_l", (0.55, 0.78, 0.42), 0.8),
        "glass": ck.mat("p_glass", (0.35, 0.5, 0.7), 0.2),
        "glow": ck.mat("p_glow", (1.0, 0.82, 0.45), 0.3, 2.0),
        "water": ck.mat("p_water", (0.45, 0.72, 0.92), 0.1, 0.3),
        "moss": ck.mat("p_moss", (0.45, 0.62, 0.34), 0.9),
        "cloth_r": ck.mat("p_cloth_r", (0.85, 0.32, 0.3), 0.85),
        "cloth_w": ck.mat("p_cloth_w", (0.96, 0.92, 0.84), 0.85),
        "flower": ck.mat("p_flower", (1.0, 0.55, 0.65), 0.7),
        "iron": ck.mat("p_iron", (0.3, 0.3, 0.33), 0.5),
    }


def B(name, size, center, mat, bevel=0.03, rot_z=0.0):
    o = ck.box(name, size, (0, 0, 0), mat, bevel)
    if rot_z:
        R = Matrix.Rotation(rot_z, 4, "Z")
        for v in o.data.vertices:
            v.co = R @ v.co
    for v in o.data.vertices:
        v.co += Vector(center)
    return o


def beam(name, a, b, w, mat):
    """Viga de seção quadrada de a até b."""
    a, b = Vector(a), Vector(b)
    o = ck.box(name, (w, w, (b - a).length), (0, 0, 0), mat, w * 0.12)
    rot = Vector((0, 0, 1)).rotation_difference((b - a).normalized()).to_matrix().to_4x4()
    for v in o.data.vertices:
        v.co = rot @ v.co + (a + b) * 0.5
    return o


def lumpy(name, r, center, mat, scale=(1, 1, 1), amp=0.18, seed=0, cuts=4):
    """Esfera irregular (pedra/copa) deformada por ruído."""
    o = ck.quad_sphere(name, 1.0, (0, 0, 0), cuts=cuts)
    off = Vector((seed * 7.1, seed * 3.3, seed * 1.7))
    for v in o.data.vertices:
        n = noise.noise(v.co * 1.6 + off)
        v.co = v.co * (1.0 + n * amp)
        v.co = Vector((v.co.x * r * scale[0], v.co.y * r * scale[1], v.co.z * r * scale[2])) + Vector(center)
    o.data.materials.append(mat)
    ck._smooth(o.data)
    return o


def ring_of_stones(prefix, center, radius, h, n, mat, mat2, z0=0.0, block=(0.32, 0.22)):
    """Anel de blocos (poço, chafariz) com cores alternadas."""
    out = []
    for i in range(n):
        a = math.tau * i / n
        p = Vector(center) + Vector((math.cos(a) * radius, math.sin(a) * radius, z0 + h * 0.5))
        out.append(B("%s%d" % (prefix, i), (block[0], block[1], h), p, mat if i % 2 == 0 else mat2, 0.03, a + math.pi / 2))
    return out


def gable_roof(prefix, w, d, eave_z, ridge_z, overhang, mat, rows=6, thick=0.08):
    """Telhado de duas águas com fileiras de telhas (degraus) e cumeeira."""
    out = []
    hw = w * 0.5 + overhang
    hd = d * 0.5 + overhang
    for side in (-1, 1):
        for r in range(rows):
            t0 = r / rows
            t1 = (r + 1) / rows
            # cada fileira: placa inclinada de y=borda até y=cumeeira
            y0 = side * hd * (1 - t0)
            y1 = side * hd * (1 - t1)
            z0 = eave_z + (ridge_z - eave_z) * t0
            z1 = eave_z + (ridge_z - eave_z) * t1
            bm_ = bmesh.new()
            ext = 0.06 if r < rows - 1 else 0.0
            yy0 = y0 + side * ext
            zz0 = z0 - ext * (ridge_z - eave_z) / hd
            co = [(-hw, yy0, zz0), (hw, yy0, zz0), (hw, y1, z1), (-hw, y1, z1)]
            vs = [bm_.verts.new(c) for c in co]
            bm_.faces.new(vs if side < 0 else list(reversed(vs)))
            o = ck.mesh_from("%s_tile%d_%d" % (prefix, side, r), bm_, mat)
            sol = o.modifiers.new("sol", "SOLIDIFY")
            sol.thickness = thick
            sol.offset = 1.0
            ck._bake(o)
            out.append(o)
    out.append(beam(prefix + "_ridge", (-hw, 0, ridge_z + 0.04), (hw, 0, ridge_z + 0.04), 0.16, mat))
    return out


# ---------------------------------------------------------------------------
# props
# ---------------------------------------------------------------------------
def house(m):
    """Casa enxaimel 6x5 (o jogo estica para cada casa). Frente = -Y."""
    w, d = 6.0, 5.0
    wall_h = 2.4
    parts = [B("found", (w + 0.3, d + 0.3, 0.4), (0, 0, 0.2), m["stone_d"], 0.06),
             B("walls", (w, d, wall_h), (0, 0, 0.4 + wall_h / 2), m["plaster"], 0.02)]
    top = 0.4 + wall_h
    # enxaimel: cantos, viga do meio, travessas diagonais
    t = 0.14
    for sx in (-1, 1):
        for sy in (-1, 1):
            parts.append(beam("corner%d%d" % (sx, sy), (sx * w / 2, sy * d / 2, 0.4), (sx * w / 2, sy * d / 2, top), t * 1.3, m["wood_d"]))
    for sy in (-1, 1):
        parts.append(beam("mid_x%d" % sy, (-w / 2, sy * (d / 2 + 0.02), 0.4 + wall_h * 0.5), (w / 2, sy * (d / 2 + 0.02), 0.4 + wall_h * 0.5), t, m["wood_d"]))
        parts.append(beam("top_x%d" % sy, (-w / 2, sy * (d / 2 + 0.02), top - 0.05), (w / 2, sy * (d / 2 + 0.02), top - 0.05), t, m["wood_d"]))
        for i, x in enumerate((-w / 4, w / 4)):
            parts.append(beam("post%d%d" % (sy, i), (x, sy * (d / 2 + 0.02), 0.4), (x, sy * (d / 2 + 0.02), top), t, m["wood_d"]))
    for sx in (-1, 1):
        parts.append(beam("mid_y%d" % sx, (sx * (w / 2 + 0.02), -d / 2, 0.4 + wall_h * 0.5), (sx * (w / 2 + 0.02), d / 2, 0.4 + wall_h * 0.5), t, m["wood_d"]))
        parts.append(beam("brace%d" % sx, (sx * (w / 2 + 0.02), -d / 2 + 0.3, 0.4 + wall_h * 0.5), (sx * (w / 2 + 0.02), 0, top - 0.1), t * 0.9, m["wood_d"]))
        parts.append(beam("brace_b%d" % sx, (sx * (w / 2 + 0.02), d / 2 - 0.3, 0.4 + wall_h * 0.5), (sx * (w / 2 + 0.02), 0, top - 0.1), t * 0.9, m["wood_d"]))
    # porta (frente) com batente e degrau
    fy = -d / 2 - 0.04
    parts += [B("door", (1.0, 0.08, 1.7), (0, fy, 0.4 + 0.85), m["wood"], 0.02),
              B("door_frame_t", (1.25, 0.14, 0.14), (0, fy - 0.02, 0.4 + 1.75), m["wood_d"], 0.02),
              B("door_l", (0.13, 0.14, 1.8), (-0.6, fy - 0.02, 0.4 + 0.9), m["wood_d"], 0.02),
              B("door_r", (0.13, 0.14, 1.8), (0.6, fy - 0.02, 0.4 + 0.9), m["wood_d"], 0.02),
              B("step", (1.5, 0.5, 0.18), (0, fy - 0.28, 0.12), m["stone"], 0.04)]
    for i in range(3):
        parts.append(B("plank%d" % i, (0.02, 0.1, 1.6), (-0.32 + i * 0.32, fy - 0.03, 0.4 + 0.85), m["wood_d"], 0.0))
    parts.append(ck.ball("knob", 0.05, (0.35, fy - 0.08, 0.4 + 0.85), m["iron"]))
    # janelas: frente (2), laterais (1 cada), com floreira
    def window(nm, center, normal):
        c = Vector(center)
        nrm = Vector(normal)
        side = Vector((-nrm.y, nrm.x, 0))
        out = []
        sz_side = (0.9, 0.06) if abs(nrm.y) > 0.5 else (0.06, 0.9)
        out.append(B(nm + "_glass", (sz_side[0], sz_side[1], 0.8), c + nrm * 0.03, m["glass"], 0.0))
        fs = (1.05, 0.12) if abs(nrm.y) > 0.5 else (0.12, 1.05)
        out.append(B(nm + "_top", (fs[0], fs[1], 0.12), c + nrm * 0.06 + Vector((0, 0, 0.46)), m["wood"], 0.02))
        out.append(B(nm + "_sill", (fs[0] * 1.05, fs[1] * 1.4, 0.1), c + nrm * 0.1 + Vector((0, 0, -0.46)), m["wood"], 0.02))
        cs = (0.06, 0.07) if abs(nrm.y) > 0.5 else (0.07, 0.06)
        out.append(B(nm + "_cross_v", (cs[0], cs[1], 0.8), c + nrm * 0.07, m["wood"], 0.0))
        hb = (0.9, 0.07) if abs(nrm.y) > 0.5 else (0.07, 0.9)
        out.append(B(nm + "_cross_h", (hb[0], hb[1], 0.06), c + nrm * 0.07, m["wood"], 0.0))
        # floreira com flores
        bs = (0.95, 0.22) if abs(nrm.y) > 0.5 else (0.22, 0.95)
        box_c = c + nrm * 0.2 + Vector((0, 0, -0.6))
        out.append(B(nm + "_box", (bs[0], bs[1], 0.2), box_c, m["wood_l"], 0.03))
        for k in range(4):
            out.append(ck.ball(nm + "_fl%d" % k, 0.09, box_c + side * (-0.33 + k * 0.22) + Vector((0, 0, 0.14)), m["flower"] if k % 2 == 0 else m["leaf_l"]))
        return out
    wz = 0.4 + wall_h * 0.58
    parts += window("win_fl", (-1.9, -d / 2, wz), (0, -1, 0))
    parts += window("win_fr", (1.9, -d / 2, wz), (0, -1, 0))
    parts += window("win_l", (-w / 2, 0.6, wz), (-1, 0, 0))
    parts += window("win_r", (w / 2, 0.6, wz), (1, 0, 0))
    # oitões (triângulos) + telhado
    ridge = top + 2.3
    for sx in (-1, 1):
        bm_ = bmesh.new()
        vs = [bm_.verts.new(c) for c in [(sx * w / 2, -d / 2, top), (sx * w / 2, d / 2, top), (sx * w / 2, 0, ridge)]]
        bm_.faces.new(vs)
        g = ck.mesh_from("gable%d" % sx, bm_, m["plaster"])
        sol = g.modifiers.new("sol", "SOLIDIFY")
        sol.thickness = 0.1
        ck._bake(g)
        parts.append(g)
        parts.append(beam("gable_beam%d" % sx, (sx * (w / 2 + 0.05), 0, top), (sx * (w / 2 + 0.05), 0, ridge - 0.2), t, m["wood_d"]))
    # o telhado corre ao longo de X (cumeeira em X) -> oitões nas laterais
    parts += _roof_x("roof", w, d, top - 0.05, ridge, 0.5, m["roof"], trim=m["wood_d"])
    # chaminé
    parts += [B("chimney", (0.6, 0.6, 1.8), (w * 0.25, 0.9, ridge - 0.3), m["stone"], 0.05),
              B("chimney_cap", (0.75, 0.75, 0.15), (w * 0.25, 0.9, ridge + 0.65), m["stone_d"], 0.04)]
    return parts


def _roof_x(prefix, w, d, eave_z, ridge_z, overhang, mat, rows=6, trim=None):
    """Telhado com cumeeira ao longo de X (águas para frente/trás): base lisa + telhas."""
    return tiled_roof(prefix, w, d, eave_z, ridge_z, overhang, mat, trim=trim)


def tiled_roof(prefix, w, d, eave_z, ridge_z, overhang, mat, tile=(0.48, 0.4), trim=None, seed=11):
    """Telhado de telhas: cada telha é uma placa chanfrada, fileiras desencontradas e levemente
    tortas (cada fileira sobrepõe a de baixo, o que desenha as linhas de sombra), cumeeira e
    tábuas de beiral (trim) nas bordas dos oitões."""
    rnd = random.Random(seed)
    out = gable_roof(prefix + "_under", w, d, eave_z, ridge_z, overhang, mat, rows=1, thick=0.06)
    hw = w * 0.5 + overhang
    hd = d * 0.5 + overhang
    for side in (-1, 1):
        eave = Vector((0, side * hd, eave_z))
        top = Vector((0, 0, ridge_z))
        up = (top - eave).normalized()
        length = (top - eave).length
        nrm = Vector((1, 0, 0)).cross(up) * (-side)   # para fora do telhado
        if nrm.z < 0:
            nrm = -nrm
        rows = int(length / (tile[1] * 0.78)) + 1
        cols = int((2 * hw) / tile[0]) + 1
        for r in range(rows):
            s = r * tile[1] * 0.78
            for c in range(cols + 1):
                x = -hw + (c + (0.5 if r % 2 else 0.0)) * tile[0]
                if x - tile[0] * 0.5 > hw or x + tile[0] * 0.5 < -hw:
                    continue
                x0, x1 = max(x - tile[0] * 0.47, -hw), min(x + tile[0] * 0.47, hw)
                if x1 - x0 < 0.1:
                    continue
                center = eave + up * (s + tile[1] * 0.5) + nrm * 0.1
                o = ck.box("%s_t%d_%d_%d" % (prefix, side, r, c), (x1 - x0, tile[1], 0.06), (0, 0, 0), mat, 0.018)
                # base local: X = largura, Y = descida do telhado, Z = normal (+ leve torção)
                tilt = rnd.uniform(-0.05, 0.05)
                basis = Matrix((Vector((1, 0, 0)), up, nrm)).transposed() @ Matrix.Rotation(tilt, 3, "Z") @ Matrix.Rotation(-0.07, 3, "X")
                for v in o.data.vertices:
                    v.co = basis @ v.co + center + Vector(((x0 + x1) * 0.5, 0, 0))
                out.append(o)
    out.append(ck.tube(prefix + "_ridge", (-hw - 0.05, 0, ridge_z + 0.09), (hw + 0.05, 0, ridge_z + 0.09), 0.13, 0.13, mat, 10))
    if trim is not None:
        for sx in (-1, 1):
            for side in (-1, 1):
                a = Vector((sx * (hw + 0.02), side * (hd + 0.02), eave_z + 0.02))
                b = Vector((sx * (hw + 0.02), 0, ridge_z + 0.02))
                out.append(beam("%s_verge%d%d" % (prefix, sx, side), a, b, 0.12, trim))
    return out


def tree(m, seed=1):
    rnd = random.Random(seed)
    parts = []
    # tronco com raízes (Skin) e dois galhos
    me = bpy.data.meshes.new("trunk_mesh")
    pts = [((0, 0, 0.0), 0.32), ((0, 0, 0.9), 0.22), ((0.05, 0, 2.0), 0.17), ((0.5, 0.1, 2.5), 0.08), ((-0.45, -0.1, 2.4), 0.08)]
    edges = [(0, 1), (1, 2), (2, 3), (2, 4)]
    for i in range(4):
        a = math.tau * i / 4 + 0.4
        pts.append(((math.cos(a) * 0.55, math.sin(a) * 0.55, 0.0), 0.08))
        edges.append((0, len(pts) - 1))
    me.from_pydata([p for p, _ in pts], edges, [])
    trunk = ck._link(bpy.data.objects.new("trunk", me))
    sk = trunk.modifiers.new("skin", "SKIN")
    sk.branch_smoothing = 0.8
    for i, (_p, r) in enumerate(pts):
        me.skin_vertices[0].data[i].radius = (r, r)
        me.skin_vertices[0].data[i].use_root = i == 0
    trunk.modifiers.new("sub", "SUBSURF").levels = 2
    ck._bake(trunk)
    trunk.data.materials.append(m["wood_d"])
    ck._smooth(trunk.data)
    parts.append(trunk)
    # copa: aglomerado de "nuvens" de folhas (cor do obstáculo) com realces claros por cima
    blobs = [((0, 0, 3.0), 1.15), ((0.75, 0.3, 2.65), 0.8), ((-0.7, -0.25, 2.7), 0.85), ((0.25, -0.75, 2.6), 0.75),
             ((-0.2, 0.8, 2.65), 0.78), ((0.1, 0.1, 3.75), 0.75)]
    for i, (c, r) in enumerate(blobs):
        parts.append(lumpy("leaf%d" % i, r, c, m["tint"], (1, 1, 0.85), 0.22, seed * 10 + i))
    for i, (c, r) in enumerate(blobs[:4]):
        cc = Vector(c) + Vector((rnd.uniform(-0.2, 0.2), rnd.uniform(-0.2, 0.2), r * 0.55))
        parts.append(lumpy("leaf_hi%d" % i, r * 0.55, cc, m["tint_l"], (1, 1, 0.6), 0.2, seed * 20 + i))
    return parts


def rock(m, seed=3):
    parts = [lumpy("rock", 0.8, (0, 0, 0.35), m["tint"], (1.0, 0.85, 0.62), 0.32, seed),
             lumpy("rock2", 0.35, (0.75, -0.35, 0.14), m["tint"], (1, 0.9, 0.6), 0.3, seed + 1),
             lumpy("rock3", 0.22, (-0.7, 0.4, 0.08), m["stone_d"], (1, 1, 0.6), 0.3, seed + 2),
             lumpy("moss", 0.55, (0.05, 0.1, 0.75), m["moss"], (1.1, 0.9, 0.22), 0.3, seed + 3)]
    return parts


def pillar(m):
    parts = [B("plinth", (1.2, 1.2, 0.3), (0, 0, 0.15), m["stone_d"], 0.05),
             ck.tube("base_ring", (0, 0, 0.3), (0, 0, 0.5), 0.55, 0.5, m["stone"], 16)]
    # fuste com caneluras (cilindros finos em volta)
    parts.append(ck.tube("shaft", (0, 0, 0.5), (0, 0, 3.2), 0.4, 0.36, m["tint"], 16))
    for i in range(12):
        a = math.tau * i / 12
        parts.append(ck.tube("flute%d" % i, (math.cos(a) * 0.39, math.sin(a) * 0.39, 0.55), (math.cos(a) * 0.35, math.sin(a) * 0.35, 3.15), 0.05, 0.045, m["tint_l"], 6))
    parts += [ck.tube("cap_ring", (0, 0, 3.2), (0, 0, 3.35), 0.42, 0.55, m["stone"], 16),
              B("abacus", (1.2, 1.2, 0.25), (0, 0, 3.47), m["stone_d"], 0.05)]
    return parts


def wall(m, seed=5):
    """Muro de pedra 4 x 2.5 x 1.2 (ao longo de X) com blocos irregulares e topo de laje."""
    rnd = random.Random(seed)
    parts = []
    rows, h = 5, 2.2
    rh = h / rows
    for r in range(rows):
        x = -2.0 - (0.4 if r % 2 else 0.0)
        i = 0
        while x < 2.0:
            bw = rnd.uniform(0.6, 1.0)
            x1 = min(x + bw, 2.0)
            x0 = max(x, -2.0)
            if x1 - x0 > 0.15:
                mat = [m["tint"], m["stone_d"], m["stone"]][rnd.randrange(3)]
                parts.append(B("blk%d_%d" % (r, i), (x1 - x0 - 0.05, 1.1 - rnd.uniform(0, 0.08), rh - 0.05),
                               ((x0 + x1) / 2, rnd.uniform(-0.03, 0.03), r * rh + rh / 2), mat, 0.05))
            x += bw
            i += 1
    parts.append(B("cap", (4.05, 1.25, 0.25), (0, 0, h + 0.12), m["stone_d"], 0.06))
    parts.append(lumpy("moss_a", 0.5, (-1.1, 0.2, h + 0.25), m["moss"], (1.4, 0.8, 0.25), 0.3, seed))
    return parts


def well(m):
    parts = [B("base", (1.9, 1.9, 0.12), (0, 0, 0.06), m["stone_d"], 0.03)]
    parts += ring_of_stones("ring_a", (0, 0, 0), 0.72, 0.38, 14, m["tint"], m["stone_d"], 0.1)
    parts += ring_of_stones("ring_b", (0, 0, 0), 0.72, 0.38, 14, m["stone_d"], m["tint"], 0.48)
    parts.append(ck.tube("water", (0, 0, 0.55), (0, 0, 0.6), 0.6, 0.6, m["water"], 16))
    for sx in (-1, 1):
        parts.append(beam("post%d" % sx, (sx * 0.8, 0, 0.1), (sx * 0.8, 0, 2.0), 0.13, m["wood"]))
    parts.append(beam("axle", (-0.9, 0, 1.55), (0.9, 0, 1.55), 0.09, m["wood_d"]))
    parts.append(ck.tube("rope", (0.1, 0, 1.55), (0.1, 0, 0.95), 0.02, 0.02, m["wood_l"], 6))
    parts.append(ck.tube("bucket", (0.1, 0, 0.75), (0.1, 0, 0.98), 0.14, 0.17, m["wood_l"], 10))
    parts += tiled_roof("wroof", 1.9, 1.2, 1.9, 2.55, 0.15, m["roof"], tile=(0.3, 0.26), trim=m["wood_d"])
    return parts


def fountain(m):
    parts = [B("plaza", (3.6, 3.6, 0.1), (0, 0, 0.05), m["stone_d"], 0.03)]
    parts += ring_of_stones("basin", (0, 0, 0), 1.55, 0.5, 22, m["tint"], m["stone"], 0.1, (0.48, 0.3))
    parts.append(ck.tube("water", (0, 0, 0.35), (0, 0, 0.45), 1.42, 1.42, m["water"], 24))
    parts += [ck.tube("pedestal", (0, 0, 0.4), (0, 0, 1.3), 0.28, 0.2, m["stone"], 12),
              ck.tube("bowl", (0, 0, 1.25), (0, 0, 1.5), 0.25, 0.7, m["tint"], 16),
              ck.tube("bowl_water", (0, 0, 1.45), (0, 0, 1.5), 0.62, 0.62, m["water"], 16),
              ck.tube("spire", (0, 0, 1.5), (0, 0, 2.0), 0.12, 0.08, m["stone"], 10),
              ck.ball("top", 0.13, (0, 0, 2.05), m["stone_l"])]
    # filetes de água caindo da tigela
    for i in range(6):
        a = math.tau * i / 6
        p0 = Vector((math.cos(a) * 0.68, math.sin(a) * 0.68, 1.48))
        p1 = Vector((math.cos(a) * 0.95, math.sin(a) * 0.95, 0.45))
        parts.append(ck.tube("stream%d" % i, p0, p1, 0.04, 0.07, m["water"], 6))
    return parts


def lamp(m):
    parts = [B("stone", (0.5, 0.5, 0.35), (0, 0, 0.17), m["stone_d"], 0.05),
             beam("post", (0, 0, 0.3), (0, 0, 2.8), 0.16, m["wood_d"]),
             beam("arm", (0, 0, 2.6), (0.6, 0, 2.6), 0.1, m["wood_d"]),
             beam("brace", (0, 0, 2.2), (0.4, 0, 2.6), 0.07, m["wood_d"]),
             ck.tube("hook", (0.55, 0, 2.6), (0.55, 0, 2.4), 0.015, 0.015, m["iron"], 6)]
    lc = Vector((0.55, 0, 2.15))
    parts += [B("lantern_top", (0.32, 0.32, 0.08), lc + Vector((0, 0, 0.22)), m["iron"], 0.02),
              B("lantern_bot", (0.28, 0.28, 0.06), lc + Vector((0, 0, -0.2)), m["iron"], 0.02),
              B("lantern_glow", (0.22, 0.22, 0.34), lc, m["glow"], 0.02)]
    for sx in (-1, 1):
        for sy in (-1, 1):
            parts.append(B("bar%d%d" % (sx, sy), (0.035, 0.035, 0.42), lc + Vector((sx * 0.13, sy * 0.13, 0)), m["iron"], 0.0))
    parts.append(ck.tube("lantern_cap", lc + Vector((0, 0, 0.26)), lc + Vector((0, 0, 0.38)), 0.17, 0.04, m["iron"], 8))
    return parts


def stall(m):
    """Barraca de feira 2.4 x 1.6 x 1.4 (ao longo de X): balcão, postes e toldo listrado."""
    parts = [B("counter", (2.4, 1.0, 0.9), (0, 0.1, 0.45), m["wood"], 0.04),
             B("counter_top", (2.55, 1.15, 0.1), (0, 0.1, 0.92), m["wood_l"], 0.03)]
    for i in range(5):
        parts.append(B("cplank%d" % i, (0.03, 0.04, 0.8), (-1.0 + i * 0.5, -0.41, 0.45), m["wood_d"], 0.0))
    for sx in (-1, 1):
        for sy in (-1, 1):
            parts.append(beam("pole%d%d" % (sx, sy), (sx * 1.15, sy * 0.55 + 0.1, 0.9), (sx * 1.15, sy * 0.55 + 0.1, 2.3 if sy > 0 else 2.0), 0.08, m["wood_d"]))
    # toldo listrado (inclinado pra frente)
    n = 8
    for i in range(n):
        x0 = -1.35 + i * 2.7 / n
        bm_ = bmesh.new()
        vs = [bm_.verts.new(c) for c in [(x0, -0.75, 1.95), (x0 + 2.7 / n, -0.75, 1.95), (x0 + 2.7 / n, 0.75, 2.35), (x0, 0.75, 2.35)]]
        bm_.faces.new(vs)
        o = ck.mesh_from("awn%d" % i, bm_, m["cloth_r"] if i % 2 == 0 else m["cloth_w"])
        sol = o.modifiers.new("sol", "SOLIDIFY")
        sol.thickness = 0.04
        ck._bake(o)
        parts.append(o)
        # franja recortada
        parts.append(ck.tube("fringe%d" % i, (x0 + 2.7 / n * 0.5, -0.76, 1.95), (x0 + 2.7 / n * 0.5, -0.78, 1.8), 0.13, 0.02, m["cloth_r"] if i % 2 == 0 else m["cloth_w"], 4))
    # mercadorias
    for i, (x, mat) in enumerate([(-0.8, "flower"), (-0.3, "leaf_l"), (0.25, "glow"), (0.75, "cloth_r")]):
        parts.append(B("basket%d" % i, (0.38, 0.38, 0.14), (x, 0.0, 1.03), m["wood_l"], 0.03))
        for k in range(3):
            parts.append(ck.ball("good%d_%d" % (i, k), 0.08, (x - 0.08 + k * 0.08, 0.0 + (k % 2) * 0.06, 1.15), m[mat] if mat != "glow" else m["wood_l"]))
    return parts


def crate(m):
    parts = [B("box", (1.0, 1.0, 1.0), (0, 0, 0.5), m["wood"], 0.03)]
    for sy in (-1, 1):
        for z in (0.06, 0.94):
            parts.append(B("rim%d_%s" % (sy, z), (1.04, 0.06, 0.12), (0, sy * 0.51, z), m["wood_d"], 0.01))
        parts.append(beam("diag%d" % sy, (-0.45, sy * 0.52, 0.1), (0.45, sy * 0.52, 0.9), 0.1, m["wood_d"]))
    for sx in (-1, 1):
        for z in (0.06, 0.94):
            parts.append(B("rimx%d_%s" % (sx, z), (0.06, 1.04, 0.12), (sx * 0.51, 0, z), m["wood_d"], 0.01))
        parts.append(beam("diagx%d" % sx, (sx * 0.52, -0.45, 0.1), (sx * 0.52, 0.45, 0.9), 0.1, m["wood_d"]))
    parts.append(B("lid", (1.04, 1.04, 0.06), (0, 0, 1.0), m["wood_l"], 0.02))
    return parts


def tent(m):
    parts = []
    for sy in (-1, 1):
        bm_ = bmesh.new()
        vs = [bm_.verts.new(c) for c in [(-1.6, sy * 1.25, 0.02), (1.6, sy * 1.25, 0.02), (1.6, 0, 1.9), (-1.6, 0, 1.9)]]
        bm_.faces.new(vs if sy < 0 else list(reversed(vs)))
        o = ck.mesh_from("canvas%d" % sy, bm_, m["cloth_w"])
        sol = o.modifiers.new("sol", "SOLIDIFY")
        sol.thickness = 0.05
        ck._bake(o)
        parts.append(o)
    for sx in (-1, 1):
        parts.append(beam("pole%d" % sx, (sx * 1.65, 0, 0), (sx * 1.65, 0, 2.1), 0.08, m["wood_d"]))
        bm_ = bmesh.new()
        vs = [bm_.verts.new(c) for c in [(sx * 1.6, -1.25, 0.02), (sx * 1.6, 1.25, 0.02), (sx * 1.6, 0, 1.9)]]
        bm_.faces.new(vs)
        back = ck.mesh_from("end%d" % sx, bm_, m["cloth_r"] if sx > 0 else m["cloth_w"])
        parts.append(back)
    parts.append(beam("ridge", (-1.7, 0, 1.92), (1.7, 0, 1.92), 0.07, m["wood_d"]))
    for sy in (-1, 1):
        parts.append(ck.tube("stake%d" % sy, (0, sy * 1.6, 0.25), (0, sy * 1.25, 0.0), 0.03, 0.02, m["wood_d"], 6))
    return parts


def ruin(m, seed=9):
    rnd = random.Random(seed)
    parts = []
    rows = 6
    for r in range(rows):
        x = -2.0 - (0.35 if r % 2 else 0.0)
        i = 0
        while x < 2.0:
            bw = rnd.uniform(0.55, 0.9)
            x1 = min(x + bw, 2.0)
            x0 = max(x, -2.0)
            # topo quebrado: some blocos altos faltam
            top_ok = r < 2 or rnd.random() > (r - 1) * 0.22 * (1.0 + abs((x0 + x1) / 2) * 0.3)
            if x1 - x0 > 0.15 and top_ok:
                parts.append(B("blk%d_%d" % (r, i), (x1 - x0 - 0.06, 0.9, 0.4), ((x0 + x1) / 2, 0, r * 0.42 + 0.2),
                               m["tint"] if (r + i) % 3 else m["stone_d"], 0.06))
            x += bw
            i += 1
    for i in range(4):
        parts.append(B("fallen%d" % i, (rnd.uniform(0.4, 0.7), 0.5, 0.35), (rnd.uniform(-1.8, 1.8), rnd.uniform(-1.0, -0.6), 0.17),
                       m["stone_d"], 0.06, rnd.uniform(0, 1.5)))
    parts.append(lumpy("moss_r", 0.6, (0.6, 0.25, 0.85), m["moss"], (1.6, 0.6, 0.6), 0.35, seed))
    parts.append(lumpy("moss_r2", 0.4, (-1.2, -0.2, 0.1), m["moss"], (1.3, 1.0, 0.3), 0.35, seed + 1))
    return parts


def statue(m):
    """Pedestal + guerreiro chibi de pedra (corpo do kit, armadura de placa e espada erguida)."""
    parts = [B("ped", (1.2, 1.2, 0.6), (0, 0, 0.3), m["stone_d"], 0.06),
             B("ped_top", (1.35, 1.35, 0.14), (0, 0, 0.66), m["stone"], 0.04),
             B("plaque", (0.6, 0.04, 0.25), (0, -0.61, 0.32), m["iron"], 0.01)]
    base = ck.build_base("st", "male", 0.0, (0.5, 0.5, 0.5))
    mats = ck._kit_mats()
    ck.kit_piece(base, "plate", "body", "torso", {"push": 0.022, "flare": 0.12}, mats)
    ck.kit_piece(base, "plate", "body", "skirt", {"bottom": ck.Z["knee"] + 0.07, "flare": 1.35}, mats)
    ck.kit_piece(base, "plate", "body", "pauldrons", {}, mats)
    ck.kit_head(base, "plate", mats)
    ck.kit_weapon(base, "sword", "main", mats)
    ck.kit_weapon(base, "shield", "off", mats)
    # vira pedra: aplica o rig (pose de repouso), tira o esqueleto e põe tudo no material de pedra
    rig = base["rig"]
    figure = []
    for o in list(bpy.context.scene.objects):
        if o.type == "MESH" and o.parent == rig:
            o.modifiers.clear()
            o.parent = None
            o.data.materials.clear()
            o.data.materials.append(m["tint"])
            for v in o.data.vertices:
                v.co = v.co * 1.25 + Vector((0, 0, 0.73))
            figure.append(o)
    bpy.data.objects.remove(rig, do_unlink=True)
    return parts + figure


def fence(m):
    parts = []
    for i, x in enumerate((-1.9, -0.95, 0.0, 0.95, 1.9)):
        parts.append(B("post%d" % i, (0.14, 0.14, 1.1), (x, 0, 0.55), m["wood_d"], 0.03))
        parts.append(ck.tube("tip%d" % i, (x, 0, 1.1), (x, 0, 1.22), 0.1, 0.02, m["wood_d"], 4))
    for z in (0.4, 0.82):
        parts.append(B("rail_%s" % z, (4.0, 0.08, 0.14), (0, 0.06, z), m["wood"], 0.02))
    return parts


def bench(m):
    parts = []
    for i in range(3):
        parts.append(B("seat%d" % i, (2.0, 0.16, 0.07), (0, -0.18 + i * 0.18, 0.48), m["wood_l"], 0.02))
    for i in range(2):
        parts.append(B("back%d" % i, (2.0, 0.07, 0.14), (0, 0.24, 0.72 + i * 0.22), m["wood_l"], 0.02))
    for sx in (-1, 1):
        parts += [B("leg_f%d" % sx, (0.12, 0.12, 0.48), (sx * 0.85, -0.2, 0.24), m["wood_d"], 0.02),
                  B("leg_b%d" % sx, (0.12, 0.12, 1.05), (sx * 0.85, 0.26, 0.52), m["wood_d"], 0.02),
                  B("arm%d" % sx, (0.1, 0.55, 0.08), (sx * 0.95, 0.02, 0.68), m["wood"], 0.02)]
    return parts


# ---------------------------------------------------------------------------
# natureza fora da vila (campo, floresta, montanha, pântano)
# ---------------------------------------------------------------------------
def cone_tier(name, r, z0, h, mat, segs=9, seed=0):
    """Saia de pinheiro: cone de base serrilhada, levemente torto."""
    rnd = random.Random(seed)
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=segs, radius1=r, radius2=0.02, depth=h)
    for v in bm.verts:
        if v.co.z < 0:
            k = 1.0 + rnd.uniform(-0.12, 0.12)
            v.co.x *= k
            v.co.y *= k
            v.co.z += rnd.uniform(-0.12, 0.06)
        v.co.z += z0 + h * 0.5
    return ck.mesh_from(name, bm, mat)


def pine(m, seed=4):
    rnd = random.Random(seed)
    parts = [ck.tube("trunk", (0, 0, 0), (0, 0, 1.6), 0.24, 0.16, m["wood_d"], 8)]
    tiers = [(1.45, 0.9, 1.6), (1.15, 1.75, 1.4), (0.85, 2.55, 1.2), (0.55, 3.25, 1.0)]
    for i, (r, z0, h) in enumerate(tiers):
        parts.append(cone_tier("tier%d" % i, r, z0, h, m["tint"], 9, seed * 10 + i))
        # realce claro no lado do sol
        hi = cone_tier("tier_hi%d" % i, r * 0.55, z0 + h * 0.35, h * 0.55, m["tint_l"], 7, seed * 20 + i)
        for v in hi.data.vertices:
            v.co.x += r * 0.28
            v.co.y -= r * 0.18
        parts.append(hi)
    for i in range(3):
        a = math.tau * i / 3 + rnd.uniform(-0.3, 0.3)
        parts.append(ck.tube("root%d" % i, (0, 0, 0.25), (math.cos(a) * 0.55, math.sin(a) * 0.55, 0.0), 0.12, 0.05, m["wood_d"], 6))
    return parts


def bush(m, seed=6):
    """Moita baixa (0,9 m): bolhas de folhas da cor do obstáculo, realces claros e umas flores."""
    rnd = random.Random(seed)
    parts = []
    blobs = [((0, 0, 0.45), 0.62), ((0.55, 0.15, 0.35), 0.45), ((-0.5, -0.1, 0.36), 0.48), ((0.1, 0.5, 0.33), 0.42),
             ((-0.05, -0.5, 0.32), 0.4)]
    for i, (c, r) in enumerate(blobs):
        parts.append(lumpy("leaf%d" % i, r, c, m["tint"], (1, 1, 0.8), 0.22, seed * 10 + i))
        parts.append(lumpy("leaf_hi%d" % i, r * 0.5, (c[0] + 0.08, c[1] - 0.06, c[2] + r * 0.55), m["tint_l"], (1, 1, 0.6), 0.2, seed * 30 + i))
    for i in range(5):
        a = rnd.uniform(0, math.tau)
        rr = rnd.uniform(0.3, 0.6)
        parts.append(ck.ball("flor%d" % i, 0.07, (math.cos(a) * rr, math.sin(a) * rr, 0.75 + rnd.uniform(-0.1, 0.05)), m["flower"]))
    return parts


def dead_tree(m, seed=8):
    """Árvore seca (ruínas/pântano): tronco torto com galhos nus, cor do obstáculo."""
    me = bpy.data.meshes.new("dead_mesh")
    pts = [((0, 0, 0.0), 0.3), ((0.1, 0, 1.1), 0.2), ((-0.1, 0.05, 2.1), 0.15), ((0.15, -0.05, 3.1), 0.09),
           ((0.9, 0.2, 2.2), 0.07), ((1.3, 0.25, 2.9), 0.04), ((-0.8, -0.3, 2.7), 0.06), ((-1.1, -0.2, 3.3), 0.035),
           ((0.6, -0.6, 3.4), 0.04), ((-0.4, 0.7, 1.7), 0.06), ((-0.75, 1.0, 2.1), 0.03)]
    edges = [(0, 1), (1, 2), (2, 3), (1, 4), (4, 5), (2, 6), (6, 7), (3, 8), (1, 9), (9, 10)]
    for i in range(4):
        a = math.tau * i / 4 + 0.6
        pts.append(((math.cos(a) * 0.6, math.sin(a) * 0.6, 0.0), 0.09))
        edges.append((0, len(pts) - 1))
    me.from_pydata([p for p, _ in pts], edges, [])
    o = ck._link(bpy.data.objects.new("dead", me))
    sk = o.modifiers.new("skin", "SKIN")
    sk.branch_smoothing = 0.7
    for i, (_p, r) in enumerate(pts):
        me.skin_vertices[0].data[i].radius = (r, r)
        me.skin_vertices[0].data[i].use_root = i == 0
    o.modifiers.new("sub", "SUBSURF").levels = 1
    ck._bake(o)
    o.data.materials.append(m["tint"])
    ck._smooth(o.data)
    return [o]


def log(m, seed=10):
    """Tronco caído ao longo de X (3 m): casca da cor do obstáculo, pontas claras, musgo e um cogumelo."""
    parts = [ck.tube("log", (-1.5, 0, 0.32), (1.5, 0, 0.3), 0.32, 0.28, m["tint"], 10)]
    parts.append(ck.tube("end_a", (-1.52, 0, 0.32), (-1.48, 0, 0.32), 0.27, 0.27, m["wood_l"], 10))
    parts.append(ck.tube("end_b", (1.48, 0, 0.3), (1.52, 0, 0.3), 0.24, 0.24, m["wood_l"], 10))
    parts.append(ck.tube("branch", (0.4, 0, 0.45), (0.9, 0.45, 0.85), 0.1, 0.04, m["tint"], 6))
    parts.append(lumpy("moss", 0.4, (-0.4, 0.0, 0.55), m["moss"], (2.0, 0.8, 0.3), 0.3, seed))
    parts.append(lumpy("mush", 0.1, (0.9, -0.3, 0.12), m["cloth_r"], (1, 1, 0.5), 0.1, seed + 1))
    return parts


def stump(m, seed=12):
    parts = [ck.tube("stump", (0, 0, 0), (0, 0, 0.6), 0.45, 0.38, m["tint"], 10),
             ck.tube("top", (0, 0, 0.6), (0, 0, 0.64), 0.34, 0.34, m["wood_l"], 10)]
    for i in range(4):
        a = math.tau * i / 4 + 0.3
        parts.append(ck.tube("root%d" % i, (0, 0, 0.2), (math.cos(a) * 0.75, math.sin(a) * 0.75, 0.0), 0.16, 0.05, m["tint"], 6))
    parts.append(lumpy("moss", 0.25, (0.25, 0.1, 0.4), m["moss"], (1, 1, 0.5), 0.3, seed))
    return parts


def flowers(m, seed=14):
    """Canteiro de flores do campo (1,6 m, não bloqueia): tufos verdes + flores da cor do obstáculo, brancas e amarelas."""
    rnd = random.Random(seed)
    parts = []
    white = ck.mat("p_flower_w", (0.98, 0.96, 0.9), 0.7)
    yellow = ck.mat("p_flower_y", (1.0, 0.85, 0.3), 0.7)
    for i in range(18):
        a = rnd.uniform(0, math.tau)
        r = 0.8 * math.sqrt(rnd.random())
        x, y = math.cos(a) * r, math.sin(a) * r
        h = rnd.uniform(0.22, 0.42)
        parts.append(ck.tube("stem%d" % i, (x, y, 0), (x, y, h), 0.025, 0.015, m["moss"], 4))
        col = [m["tint"], m["tint"], white, yellow][i % 4]
        parts.append(ck.ball("petal%d" % i, rnd.uniform(0.07, 0.1), (x, y, h + 0.03), col, (1, 1, 0.6)))
    for i in range(5):
        a = rnd.uniform(0, math.tau)
        parts.append(lumpy("tuft%d" % i, 0.2, (math.cos(a) * 0.5, math.sin(a) * 0.5, 0.06), m["moss"], (1, 1, 0.5), 0.3, seed + i))
    return parts


def reeds(m, seed=16):
    """Juncos da beira da água (1,3 m, não bloqueiam): folhas finas da cor do obstáculo e taboas marrons."""
    rnd = random.Random(seed)
    parts = []
    for i in range(16):
        a = rnd.uniform(0, math.tau)
        r = 0.55 * math.sqrt(rnd.random())
        x, y = math.cos(a) * r, math.sin(a) * r
        h = rnd.uniform(0.8, 1.3)
        lx, ly = rnd.uniform(-0.18, 0.18), rnd.uniform(-0.18, 0.18)
        parts.append(ck.tube("blade%d" % i, (x, y, 0), (x + lx, y + ly, h), 0.04, 0.008, m["tint"], 4))
        if i % 4 == 0:
            parts.append(ck.tube("cat%d" % i, (x + lx * 0.8, y + ly * 0.8, h * 0.8), (x + lx * 0.9, y + ly * 0.9, h * 0.95),
                                 0.05, 0.05, m["wood_d"], 6))
    return parts


# ---------------------------------------------------------------------------
# Móveis dos interiores (casas de Aldara). Compridos ao longo de X; "tint" = cor do obstáculo.
# ---------------------------------------------------------------------------
def iwall(m):
    """Parede de dentro (4 x 3 x 0.3): reboco com rodapé e vigas de madeira."""
    parts = [B("plaster", (4.0, 0.3, 2.6), (0, 0, 1.5), m["plaster"], 0.02),
             B("base", (4.04, 0.36, 0.4), (0, 0, 0.2), m["wood_d"], 0.02),
             B("top", (4.04, 0.36, 0.2), (0, 0, 2.9), m["wood_d"], 0.02)]
    for x in (-1.9, 0.0, 1.9):
        parts.append(B("post%d" % int(x * 10), (0.18, 0.36, 2.6), (x, 0, 1.5), m["wood_d"], 0.02))
    return parts


def table(m):
    """Mesa de taverna (2 x 1 m) com caneca e prato."""
    parts = [B("top", (2.0, 1.0, 0.1), (0, 0, 0.78), m["wood_l"], 0.03)]
    for sx in (-1, 1):
        for sy in (-1, 1):
            parts.append(B("leg%d%d" % (sx, sy), (0.1, 0.1, 0.74), (sx * 0.85, sy * 0.38, 0.37), m["wood"], 0.02))
    parts.append(ck.tube("mug", (0.5, 0.1, 0.83), (0.5, 0.1, 1.0), 0.07, 0.07, m["wood_d"], 8))
    parts.append(ck.tube("plate", (-0.4, -0.1, 0.83), (-0.4, -0.1, 0.86), 0.18, 0.18, m["cloth_w"], 10))
    parts.append(ck.ball("bread", 0.09, (-0.4, -0.1, 0.92), m["wood_l"], (1.2, 0.8, 0.6)))
    return parts


def stool(m):
    """Banquinho redondo."""
    parts = [ck.tube("seat", (0, 0, 0.42), (0, 0, 0.5), 0.24, 0.24, m["wood_l"], 10)]
    for i in range(3):
        a = math.tau * i / 3
        parts.append(ck.tube("leg%d" % i, (math.cos(a) * 0.17, math.sin(a) * 0.17, 0.0), (math.cos(a) * 0.12, math.sin(a) * 0.12, 0.42), 0.035, 0.035, m["wood"], 5))
    return parts


def bed(m):
    """Cama (2 x 1 m, ao longo de X): estrado, colchão, coberta na cor do obstáculo e travesseiro."""
    return [B("frame", (2.0, 1.0, 0.35), (0, 0, 0.25), m["wood"], 0.03),
            B("head", (0.12, 1.0, 0.9), (-0.98, 0, 0.45), m["wood_d"], 0.03),
            B("mattress", (1.85, 0.9, 0.16), (0.04, 0, 0.5), m["cloth_w"], 0.05),
            B("blanket", (1.2, 0.94, 0.12), (0.35, 0, 0.6), m["tint"], 0.05),
            B("pillow", (0.4, 0.6, 0.12), (-0.68, 0, 0.62), m["cloth_w"], 0.06)]


def counter(m):
    """Balcão (3 x 0.8 x 1.1) com tampo claro e garrafas."""
    parts = [B("body", (3.0, 0.8, 1.0), (0, 0, 0.5), m["wood"], 0.03),
             B("top", (3.1, 0.9, 0.1), (0, 0, 1.05), m["wood_l"], 0.03)]
    for i in range(4):
        parts.append(B("panel%d" % i, (0.6, 0.04, 0.6), (-1.1 + i * 0.73, -0.42, 0.5), m["wood_d"], 0.02))
    for i, x in enumerate((-1.0, -0.7, 0.9)):
        parts.append(ck.tube("bottle%d" % i, (x, 0.1, 1.1), (x, 0.1, 1.4), 0.06, 0.04, m["glass"] if i != 1 else m["tint"], 6))
    return parts


def shelf(m):
    """Estante (2 x 0.5 x 2.2) com potes e livros na cor do obstáculo."""
    parts = [B("back", (2.0, 0.08, 2.2), (0, 0.21, 1.1), m["wood_d"], 0.02)]
    for sx in (-1, 1):
        parts.append(B("side%d" % sx, (0.08, 0.5, 2.2), (sx * 0.96, 0, 1.1), m["wood"], 0.02))
    for k, z in enumerate((0.05, 0.75, 1.45, 2.15)):
        parts.append(B("board%d" % k, (2.0, 0.5, 0.06), (0, 0, z), m["wood"], 0.02))
    for k, z in enumerate((0.1, 0.8, 1.5)):
        for i in range(5):
            x = -0.75 + i * 0.36
            if (i + k) % 3 == 0:
                parts.append(ck.tube("pot%d%d" % (k, i), (x, 0, z), (x, 0, z + 0.3), 0.11, 0.09, m["tint"] if i % 2 else m["stone_l"], 8))
            else:
                parts.append(B("book%d%d" % (k, i), (0.12, 0.34, 0.44), (x, 0, z + 0.22), m["tint"] if i % 2 else m["cloth_r"], 0.01))
    return parts


def fireplace(m):
    """Lareira de pedra (2 x 0.8 x 2.6) com fogo aceso (brilha)."""
    parts = [B("base", (2.2, 0.9, 0.3), (0, 0, 0.15), m["stone_d"], 0.04),
             B("left", (0.45, 0.8, 1.4), (-0.78, 0, 1.0), m["stone"], 0.05),
             B("right", (0.45, 0.8, 1.4), (0.78, 0, 1.0), m["stone"], 0.05),
             B("mantel", (2.3, 0.95, 0.22), (0, -0.02, 1.8), m["wood_d"], 0.03),
             B("chimney", (1.4, 0.7, 0.9), (0, 0.05, 2.35), m["stone"], 0.05),
             B("back", (1.1, 0.12, 1.4), (0, 0.33, 1.0), m["stone_d"], 0.02)]
    parts.append(ck.tube("log_a", (-0.4, -0.05, 0.38), (0.4, 0.05, 0.38), 0.09, 0.09, m["wood"], 6))
    parts.append(ck.tube("log_b", (-0.35, 0.1, 0.42), (0.35, -0.1, 0.46), 0.08, 0.08, m["wood_d"], 6))
    for i, (x, h) in enumerate(((-0.18, 0.5), (0.12, 0.62), (0.0, 0.42))):
        parts.append(ck.ball("flame%d" % i, 0.16, (x, -0.05, 0.45 + h * 0.4), m["glow"], (0.8, 0.8, 1.6)))
    return parts


def barrel(m):
    """Barril em pé com aros de ferro."""
    parts = [ck.tube("body_lo", (0, 0, 0.0), (0, 0, 0.5), 0.34, 0.4, m["wood"], 12),
             ck.tube("body_hi", (0, 0, 0.5), (0, 0, 1.0), 0.4, 0.34, m["wood"], 12),
             ck.tube("lid", (0, 0, 1.0), (0, 0, 1.03), 0.32, 0.32, m["wood_l"], 12)]
    for z, r in ((0.12, 0.36), (0.5, 0.41), (0.88, 0.36)):
        parts.append(ck.tube("hoop%d" % int(z * 100), (0, 0, z - 0.03), (0, 0, z + 0.03), r + 0.015, r + 0.015, m["iron"], 12))
    return parts


def rug(m):
    """Tapete (3 x 2 m, não bloqueia): cor do obstáculo com borda clara e franja."""
    parts = [B("rug", (3.0, 2.0, 0.03), (0, 0, 0.015), m["tint"], 0.0),
             B("inner", (2.4, 1.4, 0.035), (0, 0, 0.02), m["tint_l"], 0.0),
             B("center", (1.0, 0.6, 0.04), (0, 0, 0.025), m["cloth_w"], 0.0)]
    for sx in (-1, 1):
        for i in range(8):
            parts.append(B("fringe%d%d" % (sx, i), (0.12, 0.05, 0.01), (sx * 1.55, -0.85 + i * 0.24, 0.01), m["cloth_w"], 0.0))
    return parts


def anvil(m):
    """Bigorna sobre um toco."""
    return [ck.tube("stump", (0, 0, 0), (0, 0, 0.5), 0.32, 0.28, m["wood"], 10),
            B("waist", (0.3, 0.22, 0.25), (0, 0, 0.62), m["iron"], 0.03),
            B("face", (0.8, 0.3, 0.16), (0.05, 0, 0.82), m["iron"], 0.03),
            ck.tube("horn", (0.45, 0, 0.82), (0.75, 0, 0.84), 0.1, 0.02, m["iron"], 8),
            ck.tube("hammer", (-0.25, 0.08, 0.92), (0.05, 0.08, 0.92), 0.025, 0.025, m["wood_d"], 5),
            B("hammer_head", (0.08, 0.16, 0.08), (0.08, 0.08, 0.92), m["iron"], 0.01)]


def cauldron(m):
    """Caldeirão de ferro com poção borbulhando (cor do obstáculo, brilha um pouco)."""
    parts = [ck.ball("pot", 0.55, (0, 0, 0.5), m["iron"], (1, 1, 0.8)),
             ck.tube("rim", (0, 0, 0.82), (0, 0, 0.9), 0.48, 0.5, m["iron"], 14),
             ck.tube("brew", (0, 0, 0.84), (0, 0, 0.86), 0.44, 0.44, m["tint"], 14)]
    for i in range(3):
        a = math.tau * i / 3
        parts.append(ck.tube("leg%d" % i, (math.cos(a) * 0.35, math.sin(a) * 0.35, 0.25), (math.cos(a) * 0.42, math.sin(a) * 0.42, 0.0), 0.05, 0.04, m["iron"], 5))
        parts.append(ck.ball("bub%d" % i, 0.07, (math.cos(a + 0.5) * 0.2, math.sin(a + 0.5) * 0.2, 0.9), m["tint_l"]))
    return parts


def door(m):
    """Porta de saída na parede (1.4 x 0.3 x 2.2) com batente e soleira."""
    return [B("frame_t", (1.6, 0.34, 0.2), (0, 0, 2.2), m["wood_d"], 0.02),
            B("frame_l", (0.18, 0.34, 2.2), (-0.72, 0, 1.1), m["wood_d"], 0.02),
            B("frame_r", (0.18, 0.34, 2.2), (0.72, 0, 1.1), m["wood_d"], 0.02),
            B("door", (1.24, 0.1, 2.05), (0, 0.08, 1.03), m["wood"], 0.02),
            B("sill", (1.6, 0.5, 0.06), (0, -0.12, 0.03), m["stone"], 0.02),
            ck.ball("knob", 0.05, (0.4, -0.02, 1.0), m["iron"])]


BUILDERS = {"house": house, "tree": tree, "rock": rock, "pillar": pillar, "wall": wall, "well": well,
            "fountain": fountain, "lamp": lamp, "stall": stall, "crate": crate, "tent": tent, "ruin": ruin,
            "statue": statue, "fence": fence, "bench": bench, "pine": pine, "bush": bush, "dead_tree": dead_tree,
            "log": log, "stump": stump, "flowers": flowers, "reeds": reeds,
            "iwall": iwall, "table": table, "stool": stool, "bed": bed, "counter": counter, "shelf": shelf,
            "fireplace": fireplace, "barrel": barrel, "rug": rug, "anvil": anvil, "cauldron": cauldron, "door": door}
import elf_props                       # arquitetura élfica (Cidade Élfica): casa-árvore, casulo, lanterna, portal
importlib.reload(elf_props)
BUILDERS.update(elf_props.BUILDERS)


def build(kind):
    """Monta um prop na cena (limpa antes). Devolve as peças."""
    ck.clear()
    return BUILDERS[kind](M())


def export_scene(path, name="prop", kind=""):
    """Junta tudo num único mesh (uma superfície por material = poucas draw calls no jogo) e exporta."""
    meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    for o in meshes:
        if o.modifiers:
            ck._bake(o)
        if o.matrix_world != Matrix.Identity(4):
            o.data.transform(o.matrix_world)
            o.matrix_world = Matrix.Identity(4)
    joined = ck._join(meshes, name)
    for o in list(bpy.context.scene.objects):
        if o != joined:
            bpy.data.objects.remove(o, do_unlink=True)
    _decimate(kind)
    bpy.ops.object.select_all(action="DESELECT")
    joined.select_set(True)
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=True, export_apply=True,
                              export_animations=False, export_yup=True, export_materials="EXPORT")


# teto de triângulos dos props que se repetem centenas de vezes no mapa (o toon facetado aguenta bem a redução)
TRI_BUDGET = {"tree": 1300, "bush": 700, "rock": 450, "flowers": 900, "house": 7000, "pine": 400, "dead_tree": 700, "reeds": 300}


def _decimate(kind):
    budget = TRI_BUDGET.get(kind)
    obj = next((o for o in bpy.context.scene.objects if o.type == "MESH"), None)
    if not budget or obj is None:
        return
    tris = sum(len(p.vertices) - 2 for p in obj.data.polygons)
    if tris <= budget:
        return
    mod = obj.modifiers.new("dec", "DECIMATE")
    mod.ratio = budget / tris
    mod.use_collapse_triangulate = True
    ck._bake(obj)
    print("PROP_DECIMATE %s %d -> %d" % (kind, tris, len(obj.data.polygons)))


def build_all(out_dir, only=None):
    os.makedirs(out_dir, exist_ok=True)
    for kind in BUILDERS:
        if only and kind not in only:
            continue
        build(kind)
        export_scene(os.path.join(out_dir, "prop_%s.glb" % kind), "prop_" + kind, kind)
    print("props done")
