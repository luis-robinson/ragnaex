"""Adereços das assinaturas dos chefes do Ato II (GDD design/gdd/act2-boss-signatures.md §3.5, §3.7, §3.9), lote A:

    prop_ghar_towershield     Muralha de Escudos (Ghar): escudo-torre orc fincado na frente dele (1,6 m x 1 m)
    prop_ghar_shieldwall      a mesma muralha como leque de 3 escudos menores (arco de ~120 graus, raio 1,4 m)
    prop_shazka_decoy_smoke   Sombras Gêmeas (Shazka): redemoinho baixo de fumaça roxa sob as cópias (raio 1,2 m)
    prop_gorbash_shockring    Ondas da Montanha (Gorbash): anel de lascas de rocha (interno 1,0, externo 1,6 na escala 1)
    prop_gorbash_shockshard   um tufo de lascas (1,2 m de largura) para espalhar em anéis de qualquer raio

Tamanho real (metros), origem no centro do chão, frente = -Y no Blender (+Z no Godot, a frente do EntityView).
Cores fixas (nenhum material `tint`): o jogo não recolore. Sem janela:

    blender -b --factory-startup --python tools/blender/sig_props_a.py -- [--only=a,b] [--no_export] [--no_preview]

GLB em assets/models/, prévia 2x2 (2 de lado + 2 no ângulo do jogo, cilindro rosa de 1,7 m) em
production/qa/evidence/sig-props/<nome>_preview.png.
"""
import bpy
import bmesh
import math
import os
import random
import sys
from mathutils import Vector, Matrix

HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
    sys.path.append(HERE)

import chibi_kit as ck
import prop_kit as pk

ROOT = os.path.dirname(os.path.dirname(HERE))
OUT_DIR = os.path.join(ROOT, "assets", "models")
SHOT_DIR = os.path.join(ROOT, "production", "qa", "evidence", "sig-props")
V = Vector


# ---------------------------------------------------------------------------
# materiais (cor fixa; prefixo p_ como no prop_kit)
# ---------------------------------------------------------------------------
def SM():
    return {
        "wood": ck.mat("p_horde_wood", (0.34, 0.225, 0.15), 0.85),
        "wood_d": ck.mat("p_horde_wood_d", (0.23, 0.15, 0.11), 0.85),
        "iron": ck.mat("p_horde_iron", (0.33, 0.33, 0.39), 0.5),
        "red": ck.mat("p_horde_red", (0.82, 0.16, 0.13), 0.7),
        "bone": ck.mat("p_horde_bone", (0.93, 0.88, 0.74), 0.6),
        "bronze": ck.mat("p_horde_bronze", (0.78, 0.55, 0.26), 0.4),
        "smoke": ck.mat("p_shadow_smoke", (0.4, 0.24, 0.68), 0.9),
        "smoke_d": ck.mat("p_shadow_smoke_d", (0.12, 0.07, 0.22), 0.9),
        "smoke_l": ck.mat("p_shadow_smoke_l", (0.68, 0.5, 0.95), 0.8, 0.35),
        "rock": ck.mat("p_shock_rock", (0.56, 0.52, 0.5), 0.95),
        "rock_d": ck.mat("p_shock_rock_d", (0.35, 0.33, 0.38), 0.95),
        "rock_l": ck.mat("p_shock_rock_l", (0.8, 0.75, 0.66), 0.95),
    }


# ---------------------------------------------------------------------------
# formas
# ---------------------------------------------------------------------------
def _obj(name, bm, mats):
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    me = bpy.data.meshes.new(name + "_mesh")
    bm.to_mesh(me)
    bm.free()
    o = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(o)
    for m in mats:
        o.data.materials.append(m)
    return o


def hull(name, pts, mat, cap=None, cap_nz=0.5):
    """Casco convexo facetado; face virada para cima (normal.z > cap_nz) ganha o material `cap`."""
    bm = bmesh.new()
    for p in pts:
        bm.verts.new(p)
    res = bmesh.ops.convex_hull(bm, input=bm.verts)
    junk = list({e for e in res.get("geom_interior", []) + res.get("geom_unused", []) if isinstance(e, bmesh.types.BMVert)})
    if junk:
        bmesh.ops.delete(bm, geom=junk, context="VERTS")
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    if cap:
        for f in bm.faces:
            if f.normal.z > cap_nz:
                f.material_index = 1
    return _obj(name, bm, [mat, cap] if cap else [mat])


def spike(name, base, tip, r, mat, segs=4):
    """Pirâmide de `segs` lados da base até a ponta (sem tampa: a base fica enterrada na peça)."""
    base, tip = V(base), V(tip)
    rot = V((0, 0, 1)).rotation_difference((tip - base).normalized()).to_matrix()
    bm = bmesh.new()
    ring = [bm.verts.new(base + rot @ V((math.cos(i * math.tau / segs + 0.4) * r, math.sin(i * math.tau / segs + 0.4) * r, 0))) for i in range(segs)]
    top = bm.verts.new(tip)
    for i in range(segs):
        bm.faces.new((ring[i], ring[(i + 1) % segs], top))
    return _obj(name, bm, [mat])


def xform(parts, mtx):
    for o in parts:
        o.data.transform(mtx)
    return parts


# ---------------------------------------------------------------------------
# Ghar: escudo-torre
# ---------------------------------------------------------------------------
def _slab(name, xs, sweep, zb, zt, y0, thick, mat, back=True):
    """Tábua curva: estações em x, face da frente em y = sweep(x) + y0 (frente = -Y), de zb(x) a zt(x)."""
    bm = bmesh.new()
    cols = []
    for x in xs:
        y = sweep(x) + y0
        cols.append([bm.verts.new((x, y, zb(x))), bm.verts.new((x, y, zt(x))),
                     bm.verts.new((x, y + thick, zt(x))), bm.verts.new((x, y + thick, zb(x)))])
    for a, b in zip(cols, cols[1:]):
        for k in range(4):
            if back or k != 2:               # ferragem colada na tábua não precisa da face de trás
                bm.faces.new((a[k], a[(k + 1) % 4], b[(k + 1) % 4], b[k]))
    bm.faces.new(cols[0])
    bm.faces.new(cols[-1])
    return _obj(name, bm, [mat])


def tower_shield_parts(m, prefix="ts", W=1.0, H=1.6, simple=False, lean=9.0):
    """Um escudo-torre de pé na origem, face para -Y, ponta de baixo fincada no chão, topo inclinado `lean` graus para trás.
    `simple` = versão da muralha (menos ferragem)."""
    hw = W * 0.5
    T = 0.11 * W
    xs = [-hw, -hw * 0.48, 0.0, hw * 0.48, hw]
    sweep = lambda x: 0.6 * max(0.0, abs(x) - hw * 0.48)            # abas dobradas para trás
    zb = lambda x: -0.04 + 0.2 * H * abs(x) / hw                    # ponta em V fincada
    zt = lambda x: H - 0.07 * H * abs(x) / hw                       # topo em bico suave
    rim = 0.085 * W
    parts = [_slab(prefix + "_board", xs, sweep, zb, zt, 0.0, T, m["wood"]),
             _slab(prefix + "_rim_top", xs, sweep, lambda x: zt(x) - rim * 1.5, lambda x: zt(x) + rim * 0.35, -0.035 * W, T + 0.07 * W, m["iron"]),
             _slab(prefix + "_rim_low", xs, sweep, lambda x: zb(x) - 0.02, lambda x: zb(x) + rim * 1.7, -0.035 * W, T + 0.07 * W, m["iron"])]
    bands = (0.3,) if simple else (0.27, 0.83)
    for i, f in enumerate(bands):
        z = H * f
        parts.append(_slab("%s_band%d" % (prefix, i), xs, sweep, lambda x: z - rim * 0.65, lambda x: z + rim * 0.65, -0.03 * W, 0.03 * W + T * 0.5, m["iron"], False))
        if not simple:
            for sx in (-1, 1):
                x = sx * hw * 0.72
                parts.append(spike("%s_rivet%d_%d" % (prefix, i, sx), (x, sweep(x) - 0.02 * W, z), (x, sweep(x) - 0.1 * W, z), 0.055 * W, m["bronze"]))
    for sx in (-1, 1):                                   # filete de ferro nas bordas
        z0, z1 = zb(hw) + 0.02, zt(hw) - 0.02
        parts.append(pk.B("%s_edge%d" % (prefix, sx), (0.09 * W, T + 0.07 * W, z1 - z0), (sx * hw, sweep(hw) + T * 0.5, (z0 + z1) * 0.5), m["iron"], 0.0))
    # tábua escura do meio (lê as "pranchas" sem linha fina)
    if not simple:
        parts.append(_slab(prefix + "_plank", [-hw * 0.48, 0.0, hw * 0.48], sweep, lambda x: zb(x) + rim * 1.6, lambda x: zt(x) - rim * 1.4, -0.012 * W, 0.02, m["wood_d"], False))
    # olho da Horda: losango vermelho em gema, pupila em fenda
    ez = H * 0.56
    ew, eh = 0.33 * W, 0.2 * W
    parts.append(hull(prefix + "_eye", [(-ew, -0.015 * W, ez), (ew, -0.015 * W, ez), (0, -0.015 * W, ez + eh), (0, -0.015 * W, ez - eh),
                                       (-ew * 0.45, -0.1 * W, ez), (ew * 0.45, -0.1 * W, ez), (0, -0.1 * W, ez + eh * 0.5), (0, -0.1 * W, ez - eh * 0.5)], m["red"]))
    parts.append(hull(prefix + "_pupil", [(-0.045 * W, -0.095 * W, ez), (0.045 * W, -0.095 * W, ez), (0, -0.095 * W, ez + eh * 0.62), (0, -0.095 * W, ez - eh * 0.62),
                                         (0, -0.135 * W, ez)], m["wood_d"]))
    if not simple:                                       # presas de osso subindo dos lados do olho
        for sx in (-1, 1):
            parts.append(spike("%s_tusk%d" % (prefix, sx), (sx * 0.16 * W, -0.02 * W, ez - 0.36 * W), (sx * 0.3 * W, -0.13 * W, ez - 0.08 * W), 0.07 * W, m["bone"]))
    # cravos: três no topo, e nos lados (só no grande)
    for sx in (-1, 0, 1):
        x = sx * hw * 0.62
        parts.append(spike("%s_spike_t%d" % (prefix, sx), (x, sweep(x) + T * 0.5, zt(x) - 0.02), (x, sweep(x) + T * 0.5, zt(x) + (0.3 if sx == 0 else 0.22) * W), 0.085 * W, m["iron"]))
    if not simple:
        for sx in (-1, 1):
            for f in (0.42, 0.68):
                parts.append(spike("%s_spike_s%d_%d" % (prefix, sx, int(f * 100)), (sx * (hw - 0.02), sweep(hw) + T * 0.5, H * f),
                                   (sx * (hw + 0.2 * W), sweep(hw) + T * 0.5 + 0.06 * W, H * f + 0.03), 0.075 * W, m["iron"]))
    return xform(parts, Matrix.Rotation(-math.radians(lean), 4, "X"))


def _foot_chips(prefix, m, spots, seed):
    """Torrões de terra/pedra no pé do escudo fincado."""
    rnd = random.Random(seed)
    out = []
    for i, (x, y, s) in enumerate(spots):
        pts = [(x + rnd.uniform(-1, 1) * s, y + rnd.uniform(-1, 1) * s, 0.0) for _ in range(4)]
        pts += [(x + rnd.uniform(-0.5, 0.5) * s, y + rnd.uniform(-0.5, 0.5) * s, s * rnd.uniform(0.7, 1.1)) for _ in range(2)]
        out.append(hull("%s_chip%d" % (prefix, i), pts, m["rock_d"] if i % 2 else m["rock"]))
    return out


def ghar_towershield(m):
    """Escudo-torre da Muralha de Escudos: 1,6 m de altura, 1 m de largura, fincado; origem no pé do escudo, face para -Y.
    No jogo: pôr em chefe + frente x ~0,9 m, virado para a frente do chefe."""
    parts = tower_shield_parts(m, "ts", 1.0, 1.6)
    parts += _foot_chips("ts", m, [(-0.34, -0.16, 0.13), (0.3, -0.18, 0.11), (0.05, 0.3, 0.12)], 3)
    return parts


def ghar_shieldwall(m, radius=1.4, spread=44.0):
    """Leque de 3 escudos menores em volta do chefe: origem = pé do chefe, o do meio em -Y (frente), os outros a +-`spread` graus,
    todos a `radius` m e virados para fora. Cobre ~120 graus (o arco de `Combat.in_guard_arc`)."""
    parts = []
    for i, (deg, s) in enumerate(((-spread, 0.74), (0.0, 0.86), (spread, 0.74))):
        sh = tower_shield_parts(m, "sw%d" % i, 1.0, 1.6, simple=True, lean=11.0)
        mtx = Matrix.Rotation(math.radians(deg), 4, "Z") @ Matrix.Translation((0, -radius, 0)) @ Matrix.Scale(s, 4)
        parts += xform(sh, mtx)
    return parts


# ---------------------------------------------------------------------------
# Shazka: fumaça de sombra das cópias
# ---------------------------------------------------------------------------
def _swirl_arm(name, a0, sweep, r0, r1, w_max, h_max, mat, segs=7, z0=0.03):
    """Vírgula de fumaça (tomoe): cabeça gorda em (r0, a0) e cauda que afina girando `sweep` rad até r1. Seção em telhado."""
    bm = bmesh.new()
    rows = []
    for i in range(segs + 1):
        t = i / segs
        a = a0 + sweep * t
        r = r0 + (r1 - r0) * t ** 0.8
        k = (0.62 + 0.38 * t / 0.25) if t < 0.25 else 0.2 + 0.8 * (1.0 - (t - 0.25) / 0.75) ** 0.9
        w = w_max * max(k, 0.0)
        h = z0 + h_max * max(k, 0.0) ** 0.8
        c, s = math.cos(a), math.sin(a)
        if i == segs:                        # ponta rombuda (nada de fio fino)
            rows.append([bm.verts.new((c * r, s * r, z0 + h_max * 0.12))])
        else:
            rows.append([bm.verts.new((c * (r - w), s * (r - w), z0)), bm.verts.new((c * (r + w * 0.1), s * (r + w * 0.1), h)),
                         bm.verts.new((c * (r + w), s * (r + w), z0))])
    for a, b in zip(rows, rows[1:]):
        if len(b) == 1:
            bm.faces.new((a[0], a[1], b[0]))
            bm.faces.new((a[1], a[2], b[0]))
        else:
            bm.faces.new((a[0], a[1], b[1], b[0]))
            bm.faces.new((a[1], a[2], b[2], b[1]))
    bm.faces.new(rows[0])
    return _obj(name, bm, [mat])


def _puff(name, center, rx, ry, rz, mat, rnd, n=9):
    pts = []
    for i in range(n):
        a = i * math.tau / (n - 2) + rnd.uniform(-0.3, 0.3)
        if i < n - 2:
            zz = rnd.uniform(-0.1, 0.45)
            k = math.sqrt(max(0.0, 1.0 - zz * zz)) * rnd.uniform(0.85, 1.0)
            pts.append((center[0] + math.cos(a) * rx * k, center[1] + math.sin(a) * ry * k, max(0.02, center[2] + zz * rz)))
        else:
            pts.append((center[0] + rnd.uniform(-0.3, 0.3) * rx, center[1] + rnd.uniform(-0.3, 0.3) * ry, center[2] + rz * rnd.uniform(0.85, 1.0)))
    return hull(name, pts, mat)


def shazka_decoy_smoke(m, seed=5):
    """Redemoinho baixo de fumaça de sombra (raio 1,2 m, 0,4 m de altura) para ficar SOB as cópias de Shazka (a verdadeira
    mantém a sombra normal). De cima: mancha roxa escura com três vírgulas claras girando e tufos lilás.
    Origem no centro do chão; girar o nó no eixo Y do Godot dá o redemoinho."""
    rnd = random.Random(seed)
    parts = []
    # poça escura de borda recortada, levemente abaulada
    bm = bmesh.new()
    n = 12
    ring = []
    for i in range(n):
        a = i * math.tau / n
        r = (1.17 if i % 2 == 0 else 0.92) * rnd.uniform(0.96, 1.02)
        ring.append(bm.verts.new((math.cos(a) * r, math.sin(a) * r, 0.02)))
    mid = bm.verts.new((0, 0, 0.1))
    for i in range(n):
        bm.faces.new((ring[i], ring[(i + 1) % n], mid))
    parts.append(_obj("smoke_pool", bm, [m["smoke_d"]]))
    for i in range(3):                                   # três vírgulas grandes: cabeça perto do centro, cauda na borda
        a = i * math.tau / 3 + 0.3
        parts.append(_swirl_arm("smoke_arm%d" % i, a, 2.7, 0.5, 1.02, 0.22, 0.26, m["smoke"], 6))
        # crista clara por cima da vírgula (o que desenha o giro visto de cima) e um tufo na cabeça
        parts.append(_swirl_arm("smoke_crest%d" % i, a + 0.12, 2.1, 0.5, 0.92, 0.1, 0.37, m["smoke_l"], 5, 0.12))
        parts.append(_puff("smoke_puff%d" % i, (math.cos(a - 0.05) * 0.5, math.sin(a - 0.05) * 0.5, 0.2), 0.2, 0.2, 0.2, m["smoke_l"], rnd, 8))
    return parts


# ---------------------------------------------------------------------------
# Gorbash: anel de lascas
# ---------------------------------------------------------------------------
def _shard(name, m, rnd, o, u, v, lu, lv, h, big, lim=None):
    """Laje de rocha erguida em o (x, y) no referencial u (para fora) / v (ao longo do anel): bloco grosso de base larga
    (2 lu de espessura, 2 lv de largura), topo cortado em rampa (um canto a `h`, o outro mais baixo) e tombado para fora.
    `big` = laje clara com capa; senão laje baixa e escura. `lim` = (min, max) do deslocamento em u (cabe na largura do anel)."""
    o, u, v = V((o[0], o[1], 0)), V((u[0], u[1], 0)), V((v[0], v[1], 0))
    yaw = rnd.uniform(-0.3, 0.3)                           # cada laje gira um pouco: não ficam todas na tangente
    u2 = u * math.cos(yaw) + v * math.sin(yaw)
    v2 = v * math.cos(yaw) - u * math.sin(yaw)

    def P(du, dv, z):
        p = u2 * du + v2 * dv
        if lim:
            r = p.dot(u)
            p += u * (min(max(r, lim[0]), lim[1]) - r)
        return o + p + V((0, 0, z))
    j = lambda k=0.12: rnd.uniform(1.0 - k, 1.0 + k)
    base = [P(-lu * j(), -lv * j(), 0), P(-lu * j(), lv * j(), 0), P(lu * j(), lv * j(), 0), P(lu * j(), -lv * j(), 0)]
    lean = h * math.tan(math.radians(rnd.uniform(11.0, 20.0)))        # a onda empurra para fora
    sv = rnd.choice((-1, 1))                                          # lado alto da rampa do topo
    tu, tv = lu * rnd.uniform(0.62, 0.74), lv * rnd.uniform(0.7, 0.82)
    low = h * rnd.uniform(0.64, 0.8)
    top = [P(lean - tu, -sv * tv, low), P(lean + tu, -sv * tv, low * rnd.uniform(0.86, 0.96)),
           P(lean - tu * 0.9, sv * tv * 0.95, h * rnd.uniform(0.9, 0.97)), P(lean + tu, sv * tv, h)]
    if big:
        return hull(name, base + top, m["rock"], m["rock_l"], 0.45)
    return hull(name, base + top, m["rock_d"], m["rock"], 0.45)


def _rubble(name, m, rnd, o, u, v, lu, lv, h, small=False):
    """Pedregulho: bloco baixo de topo chato. `small` = caco de 6 pontos."""
    o, u, v = V((o[0], o[1], 0)), V((u[0], u[1], 0)), V((v[0], v[1], 0))
    pts = []
    nb, nt = (4, 2) if small else (5, 3)
    for i in range(nb):
        a = i * math.tau / nb + rnd.uniform(-0.3, 0.3)
        pts.append(o + u * math.cos(a) * lu + v * math.sin(a) * lv)
    for i in range(nt):
        a = i * math.tau / nt + rnd.uniform(-0.4, 0.4)
        pts.append(o + u * math.cos(a) * lu * 0.6 + v * math.sin(a) * lv * 0.6 + V((0, 0, h * rnd.uniform(0.75, 1.0))))
    return hull(name, pts, m["rock"] if small else m["rock_d"])


def gorbash_shockring(m, seed=11, n=11, inner=1.0, outer=1.6):
    """Anel de lajes de rocha erguidas das Ondas da Montanha: na escala 1 ocupa de `inner` (1,0) a `outer` (1,6) m, lajes de 0,3 a 0,7 m
    tombadas para fora, com pedregulhos e cacos entre elas. Escalar em X/Z (Godot) abre o anel; a altura (Y) pode ficar em 1.
    Origem no centro do anel, no chão."""
    rnd = random.Random(seed)
    mid, half = (inner + outer) * 0.5, (outer - inner) * 0.5
    parts = []
    for i in range(n):
        a = (i + rnd.uniform(-0.16, 0.16)) * math.tau / n
        u, v = (math.cos(a), math.sin(a)), (-math.sin(a), math.cos(a))
        off = rnd.uniform(-0.07, 0.03)
        parts.append(_shard("ring_big%d" % i, m, rnd, (u[0] * (mid + off), u[1] * (mid + off)), u, v, rnd.uniform(0.15, 0.19), rnd.uniform(0.22, 0.29),
                            rnd.uniform(0.5, 0.7), True, (-half - off + 0.02, half - off - 0.02)))
        a2 = (i + 0.5 + rnd.uniform(-0.1, 0.1)) * math.tau / n
        u, v = (math.cos(a2), math.sin(a2)), (-math.sin(a2), math.cos(a2))
        r2 = mid + (0.1 if i % 2 else -0.12)
        parts.append(_shard("ring_small%d" % i, m, rnd, (u[0] * r2, u[1] * r2), u, v, 0.12, rnd.uniform(0.15, 0.2), rnd.uniform(0.28, 0.4), False,
                            (inner + 0.02 - r2, outer - 0.02 - r2)))
        r3 = mid - (0.14 if i % 2 else -0.16)
        parts.append(_rubble("ring_rub%d" % i, m, rnd, (u[0] * r3, u[1] * r3), u, v, 0.12, 0.16, 0.17))
        a3 = (i + rnd.uniform(-0.22, 0.22)) * math.tau / n                    # caco solto na frente ou atrás da laje grande
        u, v = (math.cos(a3), math.sin(a3)), (-math.sin(a3), math.cos(a3))
        r4 = (outer - 0.09) if i % 3 else (inner + 0.09)
        parts.append(_rubble("ring_chip%d" % i, m, rnd, (u[0] * r4, u[1] * r4), u, v, 0.07, 0.09, 0.11, True))
    return parts


def gorbash_shockshard(m, seed=4):
    """Tufo de lascas (1,2 m ao longo de X, 0,6 m de fundo, para fora = -Y): peça solta para o jogo espalhar em anéis de
    qualquer raio/largura sem deformar (MultiMesh ao longo do anel). Origem no centro do chão."""
    rnd = random.Random(seed)
    u, v = (0.0, -1.0), (1.0, 0.0)
    parts = [_shard("shard_big", m, rnd, (0.0, 0.0), u, v, 0.22, 0.27, 0.68, True),
             _shard("shard_big2", m, rnd, (0.42, 0.06), u, v, 0.17, 0.2, 0.48, True),
             _shard("shard_small", m, rnd, (-0.4, -0.05), u, v, 0.14, 0.16, 0.4, False),
             _rubble("shard_rub0", m, rnd, (-0.2, 0.16), u, v, 0.15, 0.2, 0.16),
             _rubble("shard_rub1", m, rnd, (0.24, -0.2), u, v, 0.13, 0.2, 0.14)]
    return parts


BUILDERS = {"ghar_towershield": ghar_towershield, "ghar_shieldwall": ghar_shieldwall, "shazka_decoy_smoke": shazka_decoy_smoke,
            "gorbash_shockring": gorbash_shockring, "gorbash_shockshard": gorbash_shockshard}
# onde fica o boneco de escala na prévia (o chefe/cópia): atrás do escudo, no centro dos outros
SCALE_AT = {"ghar_towershield": (0.0, 0.95), "gorbash_shockshard": (0.0, 1.3)}
TRI_MAX = 600


def build(kind):
    """Monta um adereço na cena ativa (limpa antes: só para cena vazia/sem janela). Devolve as peças."""
    ck.clear()
    return BUILDERS[kind](SM())


def tris_of(obj):
    return sum(len(p.vertices) - 2 for p in obj.data.polygons)


# ---------------------------------------------------------------------------
# prévia 2x2
# ---------------------------------------------------------------------------
def preview(kind, path, res=560):
    """2 vistas de lado + 2 no ângulo do jogo (52 graus, yaw 45 e 225), chão claro e cilindro rosa de 1,7 m."""
    import numpy as np
    sc = bpy.context.scene
    obj = next(o for o in sc.objects if o.type == "MESH")
    xs = [abs(c) for v in obj.data.vertices for c in (v.co.x, v.co.y)]
    ext = max(max(xs), 1.0)
    extra = []
    gm = ck.mat("pv_ground", (0.5, 0.58, 0.38), 1.0)
    extra.append(pk.B("pv_ground", (40, 40, 0.1), (0, 0, -0.05), gm, 0.0))
    at = SCALE_AT.get(kind, (0.0, 0.0))
    extra.append(ck.tube("pv_scale", (at[0], at[1], 0), (at[0], at[1], 1.7), 0.25, 0.25, ck.mat("pv_pink", (1.0, 0.45, 0.7), 1.0), 12))
    sun = bpy.data.objects.new("pv_sun", bpy.data.lights.new("pv_sun", "SUN"))
    sun.data.energy = 2.2
    sun.rotation_euler = (math.radians(48), 0, math.radians(-35))
    sc.collection.objects.link(sun)
    extra.append(sun)
    world = bpy.data.worlds.new("pv_world")
    world.use_nodes = True
    bg = next(n for n in world.node_tree.nodes if n.type == "BACKGROUND")
    bg.inputs[0].default_value = (0.8, 0.85, 0.95, 1.0)
    bg.inputs[1].default_value = 0.35
    sc.world = world
    cam = bpy.data.objects.new("pv_cam", bpy.data.cameras.new("pv_cam"))
    cam.data.type = "ORTHO"
    sc.collection.objects.link(cam)
    extra.append(cam)
    sc.camera = cam
    for eng in ("BLENDER_EEVEE", "BLENDER_EEVEE_NEXT", "BLENDER_WORKBENCH"):
        try:
            sc.render.engine = eng
            break
        except TypeError:
            continue
    sc.render.resolution_x = sc.render.resolution_y = res
    sc.render.film_transparent = False
    sc.view_settings.view_transform = "Standard"
    span = max(ext * 2.0 + 0.9, 2.6)
    views = [(8.0, 180.0, "frente"), (8.0, 100.0, "lado"), (52.0, 135.0, "jogo 45"), (52.0, -45.0, "jogo 225")]
    tiles = []
    os.makedirs(os.path.dirname(path), exist_ok=True)
    for i, (elev, yaw, _n) in enumerate(views):
        e, y = math.radians(elev), math.radians(yaw)
        # yaw 180 = câmera em -Y olhando a frente do adereço
        d = V((math.sin(y) * math.cos(e), math.cos(y) * math.cos(e), math.sin(e)))
        tgt = V((0, at[1] * 0.4, 0.75 if elev < 30 else 0.45))
        cam.location = tgt + d * 20.0
        cam.rotation_euler = (-d).to_track_quat("-Z", "Y").to_euler()
        cam.data.ortho_scale = span
        tmp = path[:-4] + "_t%d.png" % i
        sc.render.filepath = tmp
        bpy.ops.render.render(write_still=True)
        img = bpy.data.images.load(tmp)
        px = np.array(img.pixels[:], dtype=np.float32).reshape(res, res, 4)
        tiles.append(px)
        bpy.data.images.remove(img)
        os.remove(tmp)
    sheet = np.concatenate([np.concatenate(tiles[2:], axis=1), np.concatenate(tiles[:2], axis=1)], axis=0)   # linha 0 da imagem = base
    out = bpy.data.images.new("pv_sheet", res * 2, res * 2, alpha=True)
    out.pixels = sheet.ravel().tolist()
    out.filepath_raw = path
    out.file_format = "PNG"
    out.save()
    bpy.data.images.remove(out)
    for o in extra:
        bpy.data.objects.remove(o, do_unlink=True)
    print("SIG_PREVIEW", path)


def build_all(out_dir=OUT_DIR, only=None, export=True, shots=SHOT_DIR):
    """Gera prop_<nome>.glb de cada adereço (e a prévia, se `shots`)."""
    os.makedirs(out_dir, exist_ok=True)
    for kind in BUILDERS:
        if only and kind not in only:
            continue
        build(kind)
        name = "prop_" + kind
        path = os.path.join(out_dir, name + ".glb")
        if export:
            pk.export_scene(path, name, kind)
        else:
            ck._join([o for o in bpy.context.scene.objects if o.type == "MESH"], name)
        obj = next(o for o in bpy.context.scene.objects if o.type == "MESH")
        lo = [min(v.co[k] for v in obj.data.vertices) for k in range(3)]
        hi = [max(v.co[k] for v in obj.data.vertices) for k in range(3)]
        t = tris_of(obj)
        print("SIG_PROP %s tris=%d%s mats=%s min=(%.2f %.2f %.2f) max=(%.2f %.2f %.2f)" % (
            name, t, " OVER_BUDGET" if t >= TRI_MAX else "", ",".join(mt.name for mt in obj.data.materials), *lo, *hi))
        if shots:
            preview(kind, os.path.join(shots, name + "_preview.png"))
    print("sig props A done")


if __name__ == "__main__":
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    only = None
    for a in argv:
        if a.startswith("--only="):
            only = a[7:].split(",")
    build_all(OUT_DIR, only, "--no_export" not in argv, None if "--no_preview" in argv else SHOT_DIR)
