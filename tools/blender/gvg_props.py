"""Objetos de cerco da Guerra de Guildas (GDD design/gdd/guerra-de-guildas.md §3.4; contrato production/session-state/wave6-contract.md §2).

Peças rígidas presas a ossos (estilo mob_kit: uma malha por osso, `<cid>_<osso>`), 24 fps, frente = -Y no Blender (+Z no Godot),
1 u = 1 m (tamanho real: MonsterDef.scale 1,0). TODO osso tem chave de rotação, posição E escala em TODO clipe (`_sclip`).
Ossos todos de pé: eixos locais x = X, y = para cima, z = -Y (frente); rot X+ = a frente desce, rot Y = gira no chão,
rot Z+ = o topo tomba para -X; loc = (x, cima, frente). Nada passa do chão em nenhum quadro (as poses caídas saem de `_settle`).

`mob_siege_ram` = Aríete coberto (~4,5 m com a cabeça de ferro; 2,2 m de alto). Ossos: root, body (chassi, esteios, escudos),
roof (telhado de tábuas e couros + a faixa de pano `tint`), ram (o tronco com a cabeça de carneiro de ferro), rope_f/rope_b
(as cordas, que giram com o balanço do tronco), wheel_f/wheel_b (eixo + duas rodas cada).
Clipes: idle, run (as rodas dão MEIA volta por ciclo de 16 quadros: casa com o chão a ~2,0 m/s, ou ~1,2 m/s no piso de
0,6x do EntityView), attack (recua e bate; impacto no quadro 5 = EntityView.IMPACT_FRAME["attack"]), hit, die (o telhado
escorrega para o lado, os eixos rolam para longe, o tronco cai de bico).

`mob_siege_cannon` = Canhão de rodas (~2,4 m da boca ao fim da conteira). Ossos: root (munição, balde, soquete), body (reparo),
barrel (o tubo, pivô nos munhões), flash (clarão da boca, `glow_muzzle`; só ESCALA: 0,001 em repouso), wheel_r (-X), wheel_l (+X).
Clipes: idle, attack (clarão e coice no quadro 5; o reparo rola para trás e volta), hit, die (rodas tombam, o tubo cai de boca).
A mira é o jogo que gira (o nó inteiro): não há clipe de mira.

`mob_throne_crystal` = Cristal do Trono (~3,6 m): cristal de seis gomos (`glow_crystal` em cima, `glow_crystal_deep` embaixo)
flutuando sobre um pedestal entalhado com quatro garras. Dono = material `tint` (faixa na coluna + quatro passadeiras nos degraus).
Ossos: root (pedestal), body (o cristal inteiro: gira, flutua, pulsa), shard_1..6 (os gomos, filhos de body), orbit (quatro
lascas `glow_crystal_spark` que giram ao contrário) e core (luz do prato, só escala).
Clipes: idle (96 quadros: o cristal gira 120°, que é a simetria dele, então o laço emenda), hit, die (incha, estoura e os seis
gomos caem deitados em volta do pedestal).

`prop_gvg_banner` = Estandarte de guilda (~5 m): mastro, travessa e pano DOBRADO em rabo de andorinha (`tint` = cor da guilda)
com um brasão em forma de escudo e a barra (`tint2`). Sai pelo prop_kit (malha única, sem rig): `PROP_BUILDERS`.

    mob_kit.build_all(out, only=set(gvg_props.BUILDERS))        prop_kit.build_all(out, only=["gvg_banner"])
    blender -b --factory-startup --python tools/blender/gvg_props_preview.py -- --out=<pasta ABSOLUTA> [--export=<abs assets/models>] [--ground]
"""
import math
import random

import bmesh
import bpy
from mathutils import Euler, Matrix, Vector

import chibi_kit as ck
import lowpoly_lib as lp
import world_bosses as wb

V = Vector
Z0 = (0, 0, 0)
ONE = (1, 1, 1)
TINY = (0.001, 0.001, 0.001)
IMPACT = {"attack": 5}             # EntityView.IMPACT_FRAME["attack"]

WOOD = (0.58, 0.42, 0.28)
WOOD_D = (0.4, 0.28, 0.2)
WOOD_L = (0.74, 0.58, 0.4)
IRON = (0.45, 0.45, 0.5)
IRON_D = (0.29, 0.29, 0.34)
HIDE = (0.78, 0.63, 0.44)
HIDE_D = (0.6, 0.44, 0.32)
ROPE = (0.84, 0.74, 0.52)
HORN = (0.95, 0.9, 0.76)
BRONZE = (0.84, 0.64, 0.36)
BRONZE_D = (0.62, 0.44, 0.26)
STONE = (0.8, 0.78, 0.74)
STONE_D = (0.58, 0.58, 0.62)
STONE_L = (0.93, 0.91, 0.85)
GOLD = (0.96, 0.8, 0.4)
TINT = (0.9, 0.86, 0.78)           # o jogo pinta `tint`; sem pintura fica pano cru
TINT2 = (0.96, 0.8, 0.4)
CRYSTAL = (0.62, 0.93, 0.98)
CRYSTAL_DEEP = (0.42, 0.7, 0.96)
SPARK = (0.86, 0.8, 1.0)
MUZZLE = (1.0, 0.74, 0.3)


# ---------------------------------------------------------------------------
# cinemática dos ossos de pé (para achar as poses caídas sem furar o chão)
# ---------------------------------------------------------------------------
B3 = Matrix(((1, 0, 0), (0, 0, -1), (0, 1, 0)))       # local (x, cima, frente) -> mundo (x, -frente, cima)
B4 = B3.to_4x4()


def _W(head, rot=Z0, loc=Z0, sc=ONE, parent=None):
    """Matriz (mundo de repouso -> mundo com pose) de um osso de pé com a cabeça em `head`."""
    local = Matrix.Translation(loc) @ Euler([math.radians(a) for a in rot], "XYZ").to_matrix().to_4x4() @ Matrix.Diagonal((sc[0], sc[1], sc[2], 1.0))
    m = Matrix.Translation(head) @ B4 @ local @ B4.inverted() @ Matrix.Translation(-V(head))
    return parent @ m if parent is not None else m


def _settle(head, pts, rot, loc, margin=0.012, parent=None):
    """`loc` corrigido (só para cima/baixo no mundo) para o ponto mais baixo das peças ficar em z = margin."""
    w = _W(head, rot, loc, ONE, parent)
    d = margin - min((w @ p).z for p in pts)
    p3 = parent.to_3x3() if parent is not None else Matrix.Identity(3)
    dl = B3.inverted() @ (p3.inverted() @ V((0, 0, d)))
    return tuple(V(loc) + dl)


def _local_euler(world_rot):
    """Rotação dada no mundo (Matrix 3x3) -> euler XYZ em graus nos eixos do osso de pé."""
    e = (B3.inverted() @ world_rot @ B3).to_euler("XYZ")
    return tuple(math.degrees(a) for a in e)


# ---------------------------------------------------------------------------
# malhas
# ---------------------------------------------------------------------------
def _sm(o):
    for x in (o if isinstance(o, (list, tuple)) else [o]):
        x["smooth"] = True
    return o


def _beam(name, a, b_, w, h, material, up=(0, 0, 1)):
    """Viga de seção w (de lado) x h (em `up`) de a até b_."""
    a, b_ = V(a), V(b_)
    d = b_ - a
    ln = d.length
    d.normalize()
    side = d.cross(V(up))
    if side.length < 1e-4:
        side = d.cross(V((1, 0, 0)))
    side.normalize()
    u = side.cross(d).normalized()
    c = (a + b_) * 0.5
    b = bmesh.new()
    bmesh.ops.create_cube(b, size=1.0)
    for v in b.verts:
        v.co = c + side * (v.co.x * w) + d * (v.co.y * ln) + u * (v.co.z * h)
    bmesh.ops.recalc_face_normals(b, faces=b.faces[:])
    return ck.mesh_from(name, b, material)


def _annulus(name, c, r0, r1, w, material, segs=12):
    """Aro (anel de seção retangular) em volta do eixo X, centro c."""
    c = V(c)
    b = bmesh.new()
    rings = []
    for i in range(segs):
        a = math.tau * i / segs
        cs, sn = math.cos(a), math.sin(a)
        rings.append([b.verts.new(c + V((sx * w * 0.5, rr * cs, rr * sn))) for rr in (r0, r1) for sx in (-1, 1)])
    for i in range(segs):
        p, q = rings[i], rings[(i + 1) % segs]
        b.faces.new((p[2], p[3], q[3], q[2]))
        b.faces.new((p[0], q[0], q[1], p[1]))
        b.faces.new((p[0], p[2], q[2], q[0]))
        b.faces.new((p[1], q[1], q[3], p[3]))
    bmesh.ops.recalc_face_normals(b, faces=b.faces[:])
    return ck.mesh_from(name, b, material)


def _wheel_solid(name, c, r, w, wood, wood_d, iron):
    """Roda cheia de tábuas com aro de ferro, cubo e duas travessas em cruz (uma por face: o giro se lê)."""
    c = V(c)
    x = V((1, 0, 0))
    out = [ck.tube(name, c - x * (w * 0.5), c + x * (w * 0.5), r * 0.9, r * 0.9, wood, 12),
           _annulus(name + "_rim", c, r * 0.84, r, w * 1.2, iron, 12),
           ck.tube(name + "_hub", c - x * (w * 0.85), c + x * (w * 0.85), r * 0.24, r * 0.2, iron, 8)]
    for k, (sx, ang) in enumerate(((-1, 0.5), (1, 2.07))):
        d = V((0, math.cos(ang), math.sin(ang)))
        out.append(_beam("%s_bat%d" % (name, k), c + x * (sx * w * 0.56) - d * (r * 0.82), c + x * (sx * w * 0.56) + d * (r * 0.82), w * 0.25, r * 0.3, wood_d, x))
    return out


def _wheel_spoked(name, c, r, w, wood, wood_d, iron, spokes=8):
    """Roda de raios (canhão): pina de madeira, aro de ferro fino, cubo e raios."""
    c = V(c)
    x = V((1, 0, 0))
    out = [_annulus(name, c, r * 0.8, r * 0.96, w, wood, 12), _annulus(name + "_tyre", c, r * 0.95, r, w * 1.12, iron, 12),
           ck.tube(name + "_hub", c - x * (w * 1.1), c + x * (w * 1.1), r * 0.24, r * 0.18, wood_d, 8),
           ck.tube(name + "_cap", c - x * (w * 1.35), c + x * (w * 1.35), r * 0.1, r * 0.1, iron, 6)]
    for k in range(spokes):
        ang = math.tau * (k + 0.5) / spokes
        d = V((0, math.cos(ang), math.sin(ang)))
        out.append(_beam("%s_sp%d" % (name, k), c + d * (r * 0.16), c + d * (r * 0.84), r * 0.13, w * 0.55, wood_d, x))
    return out


def _hoop(name, c, r, th, h, material, segs=12):
    """Aro deitado (em volta de Z): anel baixo de seção th x h."""
    c = V(c)
    b = bmesh.new()
    rings = []
    for i in range(segs):
        a = math.tau * i / segs
        cs, sn = math.cos(a), math.sin(a)
        rings.append([b.verts.new(c + V((rr * cs, rr * sn, sz * h * 0.5))) for rr in (r - th, r) for sz in (-1, 1)])
    for i in range(segs):
        p, q = rings[i], rings[(i + 1) % segs]
        b.faces.new((p[2], p[3], q[3], q[2]))
        b.faces.new((p[0], q[0], q[1], p[1]))
        b.faces.new((p[0], p[2], q[2], q[0]))
        b.faces.new((p[1], q[1], q[3], p[3]))
    bmesh.ops.recalc_face_normals(b, faces=b.faces[:])
    return ck.mesh_from(name, b, material)


class _Parts:
    """Peças rígidas por osso: no fim cada osso vira UMA malha presa ao osso. `pts[osso]` = vértices (mundo de repouso)."""

    def __init__(self):
        self.by = {}
        self.pts = {}

    def add(self, bone, *objs):
        for o in objs:
            if isinstance(o, (list, tuple)):
                self.add(bone, *o)
            else:
                self.by.setdefault(bone, []).append(o)

    def finish(self, arm, cid):
        for bone, objs in self.by.items():
            self.pts[bone] = [v.co.copy() for o in objs for v in o.data.vertices]
            wb._outward(objs)
            for o in objs:
                sm = bool(o.get("smooth", False))
                for p in o.data.polygons:
                    p.use_smooth = sm
            o = ck._join(objs, "%s_%s" % (cid, bone)) if len(objs) > 1 else objs[0]
            o.name = "%s_%s" % (cid, bone)
            lp.attach(o, arm, bone)


def _bones(spec):
    """spec = {osso: (cabeça, pai)} -> ossos de pé de 0,2 m."""
    return {n: (tuple(h), (h[0], h[1], h[2] + 0.2), par) for n, (h, par) in spec.items()}


# ---------------------------------------------------------------------------
# clipes
# ---------------------------------------------------------------------------
def r(x=0.0, y=0.0, z=0.0):
    return (x, y, z)


def _k(key):
    """(quadro, rot[, loc[, escala]]) -> chave completa."""
    key = tuple(key)
    return key + ((Z0, Z0, ONE)[len(key) - 1:] if len(key) < 4 else ())


def _sclip(arm, name, end, keys, loop=False):
    """Clipe com rot/loc/escala em TODO osso (o Godot não herda pose de outro clipe). No `die` a última chave segura até o fim."""
    full = {}
    for b in arm.data.bones:
        ks = [_k(k) for k in (keys.get(b.name) or [])]
        if not ks:
            ks = [(1, Z0, Z0, ONE), (end, Z0, Z0, ONE)]
        else:
            if ks[0][0] > 1:
                ks.insert(0, (1, Z0, Z0, ONE))
            if ks[-1][0] < end:
                ks.append((end,) + tuple(ks[-1][1:]) if name == "die" else (end, Z0, Z0, ONE))
        full[b.name] = ks
    lp.add_action(arm, name, full, end, loop=loop)


def _loop(end, step, fn):
    """Chaves de um laço: fn(fase 0..tau, fração 0..1) -> (rot, loc[, escala]) a cada `step` quadros (o último = o primeiro + volta)."""
    fr = list(range(1, end, step)) + [end]
    return [(f,) + tuple(fn((f - 1) / (end - 1) * math.tau, (f - 1) / (end - 1))) for f in fr]


def _sc(seq):
    return [(f, Z0, Z0, (k, k, k)) for f, k in seq]


# ---------------------------------------------------------------------------
# Aríete coberto
# ---------------------------------------------------------------------------
RAM_WHEEL_R = 0.42
RAM_AXLE_Y = 1.15
RAM_LOG_Z = 1.0
RAM_RIDGE_Z = 2.1
RAM_ROPE_Z = 2.03
RAM_ROPE_Y = (-0.6, 0.9)            # onde as cordas seguram o tronco (frente, trás)
RAM_RUN_FRAMES = 17                 # 16 intervalos = meia volta das rodas
RAM_BONES = _bones({
    "root": ((0, 0, 0), None),
    "body": ((0, 0, 0.55), "root"),
    "roof": ((0, 0, RAM_RIDGE_Z), "body"),
    "ram": ((0, 0, RAM_LOG_Z), "body"),
    "rope_f": ((0, RAM_ROPE_Y[0], RAM_ROPE_Z), "roof"),
    "rope_b": ((0, RAM_ROPE_Y[1], RAM_ROPE_Z), "roof"),
    "wheel_f": ((0, -RAM_AXLE_Y, RAM_WHEEL_R), "root"),
    "wheel_b": ((0, RAM_AXLE_Y, RAM_WHEEL_R), "root"),
})


def _ram_horn(name, sx, material):
    """Chifre de carneiro em espiral ao lado da cabeça de ferro."""
    pts, radii = [], []
    for i in range(8):
        t = i / 7
        ang = math.radians(150 - t * 400)
        rad = 0.36 * (1 - 0.6 * t)
        pts.append((sx * (0.2 + 0.3 * t), -2.02 + rad * math.cos(ang) * 0.9 + 0.2, RAM_LOG_Z + 0.04 + rad * math.sin(ang)))
        radii.append(0.135 * (1 - 0.8 * t) + 0.014)
    return wb._horn(name, pts, radii, material, 6)


def siege_ram(cid="mob_siege_ram"):
    arm = lp.make_armature("rig_" + cid, RAM_BONES)
    H = {n: V(b[0]) for n, b in RAM_BONES.items()}
    m = lambda n, col, rough=0.9, em=0.0: ck.mat("m_%s_%s" % (cid, n), col, rough, em)
    wood, wood_d, wood_l = m("wood", WOOD), m("wood_d", WOOD_D), m("wood_l", WOOD_L)
    iron, iron_d, hide, hide_d = m("iron", IRON, 0.6), m("iron_d", IRON_D, 0.6), m("hide", HIDE), m("hide_d", HIDE_D)
    rope, horn = m("rope", ROPE), m("horn", HORN, 0.6)
    tint = ck.mat("tint", TINT, 0.85)
    rnd = random.Random(61)
    P = _Parts()

    # --- chassi, esteios, escudos (body)
    for sx in (-1, 1):
        P.add("body", _beam("sill%d" % sx, (sx * 0.72, 1.8, 0.56), (sx * 0.72, -1.8, 0.56), 0.17, 0.2, wood_d))
        for k, y in enumerate((-1.5, 0.0, 1.5)):
            P.add("body", _beam("post%d_%d" % (sx, k), (sx * 0.72, y, 0.62), (sx * 0.64, y, 1.5), 0.13, 0.13, wood, (0, 1, 0)))
        for k, y in enumerate((-1.72, 1.72)):                       # mãos-francesas em A na frente e atrás
            P.add("body", _beam("brace%d_%d" % (sx, k), (sx * 0.72, y, 0.62), (sx * 0.1, y, 1.98), 0.1, 0.1, wood_d, (0, 1, 0)))
        for k, y in enumerate((-0.75, 0.78)):                       # escudos pendurados nos esteios
            c = V((sx * 0.8, y, 1.02))
            P.add("body", ck.tube("shield%d_%d" % (sx, k), c, c + V((sx * 0.05, 0, 0)), 0.3, 0.28, wood_l, 10),
                  _annulus("shield_rim%d_%d" % (sx, k), c + V((sx * 0.025, 0, 0)), 0.26, 0.31, 0.07, iron, 10),
                  wb._stud("shield_boss%d_%d" % (sx, k), c + V((sx * 0.06, 0, 0)), 0.09, iron_d))
    for k, y in enumerate((-1.7, 0.0, 1.7)):
        P.add("body", _beam("cross%d" % k, (-0.8, y, 0.56), (0.8, y, 0.56), 0.16, 0.16, wood))
        if k != 1:
            P.add("body", _beam("tie%d" % k, (-0.7, y * 0.885, 1.5), (0.7, y * 0.885, 1.5), 0.12, 0.12, wood_d))
    for k, y in enumerate((-0.52, 0.55)):                           # varas de empurrar atravessadas
        P.add("body", ck.tube("push%d" % k, (-1.5, y, 0.74), (1.5, y, 0.74), 0.05, 0.05, wood_l, 6))
    P.add("body", ck.tube("push_back", (-0.95, 1.98, 0.86), (0.95, 1.98, 0.86), 0.05, 0.05, wood_l, 6))
    for sx in (-1, 1):
        P.add("body", _beam("push_arm%d" % sx, (sx * 0.72, 1.7, 0.6), (sx * 0.72, 2.0, 0.88), 0.09, 0.09, wood_d, (1, 0, 0)))

    # --- telhado de tábuas, couros e a faixa da cor do lado (roof)
    P.add("roof", _beam("ridge", (0, 1.98, RAM_RIDGE_Z), (0, -2.02, RAM_RIDGE_Z), 0.16, 0.16, wood_d))
    P.add("roof", ck.tube("ridge_tip", (0, -2.02, RAM_RIDGE_Z), (0, -2.2, RAM_RIDGE_Z + 0.06), 0.09, 0.03, iron, 6))
    tones = (wood, wood_l, wood, wood_d, wood_l, wood, wood_l)
    for sx in (-1, 1):
        d = V((sx * 0.803, 0, -0.596))
        n = V((sx * 0.596, 0, 0.803))
        for k in range(7):
            y = -1.7 + (k + 0.5) * (3.4 / 7)
            ext = rnd.uniform(0.0, 0.13)
            a = V((0, y, RAM_RIDGE_Z + 0.03)) + d * 0.02
            P.add("roof", _beam("plank%d_%d" % (sx, k), a, a + d * (1.31 + ext), 0.465, 0.055, tones[(k + (sx > 0)) % 7], n))
        for k, (y0, w_, col) in enumerate(((-1.62, 1.0, hide), (0.55, 1.05, hide_d) if sx > 0 else (0.62, 0.98, hide))):
            o = wb._cloth("hide%d_%d" % (sx, k), V((0, y0, RAM_RIDGE_Z + 0.02)) + n * 0.085 + d * 0.06, (0, 1, 0), d, w_, 1.02 + 0.1 * k,
                          hide_d if (k + (sx > 0)) % 2 else hide, None, 7 + k * 3 + (sx > 0), 4, 3, 0.03, 0.04, 0.3)
            P.add("roof", _sm(o))
            for j in range(2):                                      # pregos de ferro segurando o couro
                P.add("roof", wb._stud("nail%d_%d_%d" % (sx, k, j), V((0, y0 + 0.12 + j * (w_ - 0.24), RAM_RIDGE_Z)) + n * 0.1 + d * 0.16, 0.04, iron_d))
        # faixa de pano `tint`: desce a água do telhado e pende da beira, rasgada
        P.add("roof", _sm(wb._cloth("band%d" % sx, V((0, -0.33, RAM_RIDGE_Z + 0.03)) + n * 0.09, (0, 1, 0), d, 0.66, 1.4, tint, None, 3 + (sx > 0), 4, 3, 0.03, 0.035, 0.0)))
        eave = V((0, -0.33, RAM_RIDGE_Z + 0.03)) + n * 0.09 + d * 1.39
        P.add("roof", _sm(wb._cloth("band_drop%d" % sx, eave, (0, 1, 0), (sx * 0.12, 0, -1), 0.66, 0.5, tint, None, 5 + (sx > 0), 4, 3, 0.03, 0.05, 0.4)))
    P.add("roof", _sm(wb._cloth("band_cap", (-0.2, -0.33, RAM_RIDGE_Z + 0.115), (0, 1, 0), (1, 0, 0), 0.66, 0.4, tint, None, 2, 4, 2, 0.03, 0.012, 0.0)))
    for k, (p, d_) in enumerate((((0.5, -1.0, 1.9), (0.5, -0.3, 0.8)), ((-0.62, 1.1, 1.82), (-0.6, 0.2, 0.8)), ((0.3, 1.3, 2.0), (0.3, 0.4, 0.9)))):
        P.add("roof", wb._stuck("arrow%d" % k, p, d_, 0.5, 0.018, wood_l, m("fletch", (0.9, 0.42, 0.36))))

    # --- o tronco com a cabeça de carneiro de ferro (ram)
    z = RAM_LOG_Z
    P.add("ram", ck.tube("log", (0, 1.6, z), (0, -1.86, z), 0.2, 0.19, wood_l, 10), ck.tube("log_end", (0, 1.6, z), (0, 1.63, z), 0.17, 0.15, wood, 10))
    for k, y in enumerate((1.45, RAM_ROPE_Y[1], RAM_ROPE_Y[0], -1.45)):
        P.add("ram", ck.tube("log_band%d" % k, (0, y + 0.06, z), (0, y - 0.06, z), 0.222, 0.222, iron, 10))
    P.add("ram", ck.tube("head_cap", (0, -1.74, z), (0, -2.2, z), 0.29, 0.3, iron, 10), ck.tube("head_snout", (0, -2.2, z), (0, -2.62, z - 0.04), 0.3, 0.18, iron, 10),
          ck.tube("head_face", (0, -2.62, z - 0.04), (0, -2.67, z - 0.04), 0.19, 0.15, iron_d, 10),
          ck.tube("head_brow", (-0.24, -2.2, z + 0.24), (0.24, -2.2, z + 0.24), 0.08, 0.08, iron_d, 6),
          ck.tube("head_ring", (0, -1.72, z), (0, -1.8, z), 0.32, 0.32, iron_d, 10))
    for sx in (-1, 1):
        P.add("ram", _sm(_ram_horn("horn%d" % sx, sx, horn)), wb._stud("eye%d" % sx, (sx * 0.2, -2.42, z + 0.14), 0.05, iron_d))

    # --- cordas (giram com o balanço) e os dois eixos
    for bone, y in (("rope_f", RAM_ROPE_Y[0]), ("rope_b", RAM_ROPE_Y[1])):
        for sx in (-1, 1):
            P.add(bone, ck.tube("%s_%d" % (bone, sx), (sx * 0.04, y, RAM_ROPE_Z + 0.05), (sx * 0.19, y, z + 0.12), 0.03, 0.03, rope, 4))
        P.add(bone, ck.tube(bone + "_knot", (0, y - 0.07, RAM_RIDGE_Z), (0, y + 0.07, RAM_RIDGE_Z), 0.13, 0.13, rope, 6))
    for bone, y in (("wheel_f", -RAM_AXLE_Y), ("wheel_b", RAM_AXLE_Y)):
        P.add(bone, ck.tube(bone + "_axle", (-1.12, y, RAM_WHEEL_R), (1.12, y, RAM_WHEEL_R), 0.06, 0.06, iron_d, 6))
        for sx in (-1, 1):
            P.add(bone, _wheel_solid("%s_%d" % (bone, sx), (sx * 0.98, y, RAM_WHEEL_R), RAM_WHEEL_R, 0.14, wood, wood_d, iron))
    P.finish(arm, cid)
    _ram_clips(arm, H, P.pts)
    return arm


def _ram_clips(arm, H, pts):
    L = RAM_ROPE_Z - RAM_LOG_Z

    def swing(f, d):
        """tronco d metros à frente (pêndulo nas cordas): chaves (tronco, corda)."""
        th = math.asin(max(-0.95, min(0.95, d / L)))
        return (f, Z0, (0, L * (1 - math.cos(th)), d)), (f, r(-math.degrees(th)), Z0)

    def sway(seq):
        ks = [swing(f, d) for f, d in seq]
        return [k[0] for k in ks], [k[1] for k in ks]

    s = math.sin
    # idle: o tronco balança de leve nas cordas
    fr = list(range(1, 48, 4)) + [48]
    lg, rp = sway([(f, 0.05 * s((f - 1) / 47 * math.tau)) for f in fr])
    _sclip(arm, "idle", 48, {"ram": lg, "rope_f": rp, "rope_b": rp, "roof": _loop(48, 8, lambda ph, t: (r(0, 0, 0.35 * s(ph)), Z0))}, loop=True)
    # run: meia volta das rodas (linear), chassi treme, tronco atrasa
    E = RAM_RUN_FRAMES
    fr = list(range(1, E, 2)) + [E]
    spin = [(f, r(180.0 * (f - 1) / (E - 1)), Z0) for f in fr]
    lg, rp = sway([(f, -0.1 * s((f - 1) / (E - 1) * math.tau + 0.6)) for f in fr])
    _sclip(arm, "run", E, {"wheel_f": spin, "wheel_b": spin, "ram": lg, "rope_f": rp, "rope_b": rp,
                           "body": _loop(E, 2, lambda ph, t: (r(0.5 * s(ph), 0, 0.7 * s(2 * ph)), (0, 0.012 * abs(s(2 * ph)), 0))),
                           "roof": _loop(E, 2, lambda ph, t: (r(0, 0, 0.9 * s(2 * ph + 1.0)), Z0))}, loop=True)
    # attack: recua, bate no quadro 5, quica e assenta
    lg, rp = sway([(1, 0.0), (3, -0.62), (5, 0.66), (7, 0.44), (11, -0.2), (15, 0.07), (20, 0.0)])
    lurch = lambda k: [(3, r(-0.8 * k), (0, 0, -0.03)), (5, r(1.8 * k), (0, 0, 0.07)), (8, r(-0.6 * k), (0, 0, 0.02)), (13, Z0, Z0)]
    roll = [(3, r(-4), (0, 0, -0.03)), (5, r(9.5), (0, 0, 0.07)), (8, r(2.7), (0, 0, 0.02)), (13, Z0, Z0)]
    _sclip(arm, "attack", 20, {"ram": lg, "rope_f": rp, "rope_b": rp, "body": lurch(1.0), "wheel_f": roll, "wheel_b": roll,
                               "roof": [(5, r(0, 0, 0), Z0), (6, r(-1.6, 0, 1.2), (0, 0.02, 0)), (9, r(0.8, 0, -0.7), Z0), (13, Z0, Z0)]})
    # hit: tranco de lado, telhado chacoalha, tronco balança
    lg, rp = sway([(1, 0.0), (3, -0.16), (6, 0.1), (10, 0.0)])
    _sclip(arm, "hit", 10, {"ram": lg, "rope_f": rp, "rope_b": rp,
                            "body": [(2, r(-1.2, 0, 3.2), (0.03, 0, -0.05)), (5, r(0.6, 0, -1.6), (-0.01, 0, 0.01)), (8, r(0, 0, 0.5), Z0)],
                            "roof": [(2, r(0, 0, 3.5), (0, 0.03, 0)), (5, r(0, 0, -2.2), Z0), (8, r(0, 0, 0.8), Z0)],
                            "wheel_f": [(2, r(-3), Z0), (6, Z0, Z0)], "wheel_b": [(2, r(-3), Z0), (6, Z0, Z0)]})
    # die: os eixos rolam para longe, o chassi desaba torto, o telhado escorrega para +X e o tronco cai de bico
    body_r = r(-3, 5, 11)
    body_l = _settle(H["body"], pts["body"], body_r, (0.06, 0, -0.08), 0.015)
    wbody = _W(H["body"], body_r, body_l)
    roof_r = r(4, 16, -9)
    roof_l = _settle(H["roof"], pts["roof"], roof_r, (1.25, 0, -0.15), 0.015, wbody)
    wroof = _W(H["roof"], roof_r, roof_l, ONE, wbody)
    ram_r = r(11, -7, 4)
    ram_l = _settle(H["ram"], pts["ram"], ram_r, (-0.12, 0, 0.3), 0.015, wbody)
    rope = {}
    for bone, ang in (("rope_f", 84), ("rope_b", -84)):
        rope[bone] = (r(ang), _settle(H[bone], pts[bone], r(ang), Z0, 0.02, wroof) if min((_W(H[bone], r(ang), Z0, ONE, wroof) @ p).z for p in pts[bone]) < 0.02 else Z0)
    up = lambda l, d: (l[0], l[1] + d, l[2])
    mid = lambda l, k: tuple(x * k for x in l)
    _sclip(arm, "die", 38, {
        "body": [(3, r(1.5, 0, -2.5), (0, 0.02, 0)), (6, r(-1, 1, 3), Z0), (12, body_r, body_l), (14, r(-2, 5, 9), up(body_l, 0.05)), (17, body_r, body_l)],
        "roof": [(6, r(0, 0, 2), (0, 0.04, 0)), (11, r(2, 6, -14), up(mid(roof_l, 0.45), 0.3)), (17, roof_r, roof_l), (19, r(4, 16, -6), up(roof_l, 0.08)), (22, roof_r, roof_l)],
        "ram": [(6, r(0, 0, 0), (0, 0, 0.1)), (10, r(4, -3, 2), mid(ram_l, 0.4)), (14, ram_r, ram_l), (16, r(8.5, -7, 4), up(ram_l, 0.07)), (19, ram_r, ram_l)],
        "rope_f": [(6, Z0, Z0), (12, r(50), mid(rope["rope_f"][1], 0.5)), (17, rope["rope_f"][0], rope["rope_f"][1])],
        "rope_b": [(6, Z0, Z0), (12, r(-50), mid(rope["rope_b"][1], 0.5)), (17, rope["rope_b"][0], rope["rope_b"][1])],
        "wheel_f": [(4, Z0, Z0), (12, r(70, 10, 0), (0.08, 0, 0.5)), (20, r(123, 24, 0), (0.2, 0, 0.9)), (24, r(118, 24, 0), (0.2, 0, 0.86)), (28, r(121, 24, 0), (0.2, 0, 0.88))],
        "wheel_b": [(5, Z0, Z0), (14, r(-50, -9, 0), (-0.06, 0, -0.37)), (22, r(-87, -17, 0), (-0.12, 0, -0.64)), (26, r(-83, -17, 0), (-0.12, 0, -0.61)), (30, r(-85, -17, 0), (-0.12, 0, -0.62))]})


# ---------------------------------------------------------------------------
# Canhão de rodas
# ---------------------------------------------------------------------------
CAN_WHEEL_R = 0.42
CAN_B0 = V((0, 0.42, 0.8))          # culatra
CAN_B1 = V((0, -1.26, 0.98))        # boca
CAN_TRUN = 0.62                     # munhões (m ao longo do tubo)
CAN_DIR = (CAN_B1 - CAN_B0).normalized()
CAN_LEN = (CAN_B1 - CAN_B0).length
CAN_PIVOT = CAN_B0 + CAN_DIR * CAN_TRUN
CAN_BONES = _bones({
    "root": ((0, 0, 0), None),
    "body": ((0, 0, CAN_WHEEL_R), "root"),
    "barrel": (tuple(CAN_PIVOT), "body"),
    "flash": (tuple(CAN_B0 + CAN_DIR * (CAN_LEN + 0.03)), "barrel"),
    "wheel_r": ((-0.56, 0, CAN_WHEEL_R), "root"),
    "wheel_l": ((0.56, 0, CAN_WHEEL_R), "root"),
})


def siege_cannon(cid="mob_siege_cannon"):
    arm = lp.make_armature("rig_" + cid, CAN_BONES)
    H = {n: V(b[0]) for n, b in CAN_BONES.items()}
    m = lambda n, col, rough=0.9, em=0.0: ck.mat("m_%s_%s" % (cid, n), col, rough, em)
    wood, wood_d, wood_l = m("wood", WOOD), m("wood_d", WOOD_D), m("wood_l", WOOD_L)
    iron, iron_d, bronze, bronze_d = m("iron", IRON, 0.6), m("iron_d", IRON_D, 0.6), m("bronze", BRONZE, 0.5), m("bronze_d", BRONZE_D, 0.5)
    rope, bore = m("rope", ROPE), m("bore", (0.12, 0.1, 0.12), 0.8)
    glow = ck.mat("glow_muzzle", MUZZLE, 0.4, 1.75)
    tint = ck.mat("tint", TINT, 0.85)
    P = _Parts()
    at = lambda t: CAN_B0 + CAN_DIR * t

    # --- tubo de bronze com cintas de ferro (barrel)
    P.add("barrel", ck.tube("tube_a", at(0.0), at(0.52), 0.2, 0.19, bronze, 10), ck.tube("tube_b", at(0.5), at(1.46), 0.185, 0.145, bronze, 10),
          ck.tube("muzzle", at(1.44), at(CAN_LEN), 0.165, 0.2, bronze, 10), ck.tube("lip", at(CAN_LEN - 0.03), at(CAN_LEN + 0.02), 0.21, 0.2, bronze_d, 10),
          ck.tube("bore", at(CAN_LEN + 0.018), at(CAN_LEN + 0.024), 0.13, 0.13, bore, 10),
          ck.tube("breech", at(-0.06), at(0.02), 0.17, 0.215, bronze_d, 10), ck.tube("neck", at(-0.16), at(-0.05), 0.07, 0.1, bronze_d, 6),
          _sm(ck.ball("knob", 0.1, at(-0.22), bronze_d)))
    for k, (t, rr, ln) in enumerate(((0.06, 0.225, 0.08), (0.5, 0.212, 0.07), (1.0, 0.185, 0.06), (1.42, 0.178, 0.06))):
        P.add("barrel", ck.tube("ring%d" % k, at(t - ln * 0.5), at(t + ln * 0.5), rr, rr * 0.985, iron, 10))
    P.add("barrel", ck.tube("trunnion", CAN_PIVOT + V((-0.4, 0, 0)), CAN_PIVOT + V((0.4, 0, 0)), 0.065, 0.065, iron_d, 8),
          ck.tube("touch", at(0.12) + V((0, 0, 0.19)), at(0.12) + V((0, 0, 0.26)), 0.03, 0.04, iron_d, 5))
    # pano `tint` amarrado atrás dos munhões, com duas pontas caídas
    P.add("barrel", ck.tube("wrap", at(0.17), at(0.45), 0.212, 0.205, tint, 10))
    for k, sx in enumerate((-1, 1)):
        P.add("barrel", _sm(wb._cloth("wrap_tail%d" % k, at(0.24) + V((sx * 0.2, 0, 0.04)), (0, -1, 0.1), (sx * 0.25, 0, -1), 0.14, 0.34 + 0.08 * k, tint, None, 4 + k, 2, 3, 0.025, 0.03, 0.3)))

    # --- clarão da boca (flash): estrela de cones, só escala
    f0 = at(CAN_LEN + 0.03)
    P.add("flash", ck.tube("flash_core", f0, f0 + CAN_DIR * 0.75, 0.2, 0.02, glow, 8), wb._stud("flash_ball", f0 + CAN_DIR * 0.08, 0.24, glow, sub=1))
    _d, fu, fw = wb._perp(CAN_DIR)
    for k in range(6):
        a = math.tau * k / 6 + 0.3
        side = fu * math.cos(a) + fw * math.sin(a)
        ln = 0.5 if k % 2 else 0.36
        P.add("flash", ck.tube("flash_ray%d" % k, f0 + CAN_DIR * 0.04, f0 + CAN_DIR * (0.1 + ln * 0.45) + side * ln, 0.1, 0.012, glow, 5))

    # --- reparo: duas falcas, conteira até o chão, eixo (body)
    for sx in (-1, 1):
        P.add("body", _beam("cheek%d" % sx, (sx * 0.3, -0.52, 0.64), (sx * 0.3, 0.42, 0.6), 0.1, 0.3, wood, (0, 0, 1)),
              _beam("cheek_top%d" % sx, (sx * 0.3, -0.42, 0.8), (sx * 0.3, 0.05, 0.8), 0.1, 0.12, wood),
              _beam("trail%d" % sx, (sx * 0.28, 0.3, 0.56), (sx * 0.13, 1.22, 0.115), 0.1, 0.2, wood),
              _beam("cheek_iron%d" % sx, (sx * 0.3, -0.36, 0.875), (sx * 0.3, -0.04, 0.875), 0.115, 0.035, iron),
              wb._stud("bolt%d" % sx, (sx * 0.36, 0.2, 0.62), 0.04, iron_d), wb._stud("bolt_b%d" % sx, (sx * 0.36, -0.4, 0.62), 0.04, iron_d))
    P.add("body", _beam("transom", (-0.3, 0.3, 0.56), (0.3, 0.3, 0.56), 0.12, 0.2, wood_d), _beam("transom_f", (-0.3, -0.44, 0.58), (0.3, -0.44, 0.58), 0.1, 0.16, wood_d),
          _beam("trail_end", (-0.2, 1.2, 0.12), (0.2, 1.2, 0.12), 0.14, 0.17, wood_d), _annulus("trail_ring", (0, 1.34, 0.12), 0.05, 0.09, 0.035, iron, 8),
          _beam("axle_bed", (-0.42, 0, 0.44), (0.42, 0, 0.44), 0.16, 0.14, wood_d),
          ck.tube("axle", (-0.7, 0, CAN_WHEEL_R), (0.7, 0, CAN_WHEEL_R), 0.045, 0.045, iron_d, 6),
          _beam("wedge", (0, 0.3, 0.7), (0, 0.02, 0.72), 0.2, 0.08, wood_l))
    for bone, sx in (("wheel_r", -1), ("wheel_l", 1)):
        P.add(bone, _wheel_spoked(bone, (sx * 0.56, 0, CAN_WHEEL_R), CAN_WHEEL_R, 0.1, wood, wood_d, iron))

    # --- munição, balde e soquete (root)
    for k, (x, y, zz) in enumerate(((0.78, 0.72, 0.12), (1.0, 0.76, 0.12), (0.9, 0.93, 0.12), (0.89, 0.8, 0.295))):
        P.add("root", wb._stud("ball%d" % k, (x, y, zz), 0.115, iron_d, sub=2))
    P.add("root", ck.tube("bucket", (-0.85, 0.75, 0.0), (-0.85, 0.75, 0.3), 0.14, 0.17, wood, 8), ck.tube("bucket_band", (-0.85, 0.75, 0.2), (-0.85, 0.75, 0.25), 0.172, 0.176, iron, 8),
          ck.tube("bucket_water", (-0.85, 0.75, 0.27), (-0.85, 0.75, 0.275), 0.15, 0.15, m("water", (0.5, 0.74, 0.9), 0.3), 8),
          ck.tube("rammer", (-0.72, 1.35, 0.045), (-1.05, -0.35, 0.045), 0.03, 0.03, wood_l, 5),
          ck.tube("rammer_head", (-1.05, -0.35, 0.07), (-1.09, -0.57, 0.07), 0.07, 0.07, rope, 6))
    P.finish(arm, cid)
    _cannon_clips(arm, H, P.pts)
    return arm


def _cannon_clips(arm, H, pts):
    s = math.sin
    R = CAN_WHEEL_R
    off = [(1, Z0, Z0, TINY), (2, Z0, Z0, TINY)]
    _sclip(arm, "idle", 48, {"barrel": _loop(48, 8, lambda ph, t: (r(0.5 * s(ph)), Z0)), "flash": [(1, Z0, Z0, TINY), (48, Z0, Z0, TINY)]}, loop=True)
    # attack: mergulha de leve, dispara no quadro 5 (clarão + coice), o reparo rola para trás e volta
    back = lambda d: (0, 0, -d)
    turn = lambda d: r(-math.degrees(d / R))
    roll = [(1, 0.0), (4, -0.015), (5, 0.03), (7, 0.24), (9, 0.27), (15, 0.12), (22, 0.0)]
    _sclip(arm, "attack", 22, {
        "body": [(f, Z0, back(d)) for f, d in roll],
        "wheel_r": [(f, turn(d), back(d)) for f, d in roll], "wheel_l": [(f, turn(d), back(d)) for f, d in roll],
        "barrel": [(1, Z0, Z0), (4, r(1.6), (0, 0, 0.02)), (5, r(-2), (0, 0, -0.05)), (7, r(-8.5), (0, 0, -0.13)), (10, r(-3), (0, 0, -0.05)), (14, r(0.8), Z0), (19, Z0, Z0)],
        "flash": [(1, Z0, Z0, TINY), (4, Z0, Z0, TINY), (5, Z0, Z0, (1.45, 1.45, 1.45)), (6, r(0, 0, 25), Z0, (1.15, 1.15, 1.15)), (8, r(0, 0, 40), Z0, (0.5, 0.5, 0.5)),
                  (10, Z0, Z0, TINY), (22, Z0, Z0, TINY)]})
    _sclip(arm, "hit", 10, {"body": [(2, r(0, 3, 3), (0.02, 0, -0.04)), (5, r(0, -1.5, -1.5), Z0), (8, Z0, Z0)],
                            "barrel": [(2, r(3.5), Z0), (5, r(-1.8), Z0), (8, r(0.5), Z0)],
                            "wheel_r": [(2, r(-5), (0, 0, -0.04)), (6, Z0, Z0)], "wheel_l": [(2, r(-5), (0, 0, -0.04)), (6, Z0, Z0)],
                            "flash": off + [(10, Z0, Z0, TINY)]})
    # die: as rodas tombam para fora, o reparo desaba e o tubo cai de boca
    body_r = r(5, 6, -7)
    body_l = _settle(H["body"], pts["body"], body_r, (0, 0, -0.05), 0.015)
    wbody = _W(H["body"], body_r, body_l)
    bar_r = r(15, -14, 6)
    bar_l = _settle(H["barrel"], pts["barrel"], bar_r, (0.1, 0, 0.3), 0.015, wbody)
    wr_r, wl_r = r(0, 14, 86), r(0, -22, -84)
    wr_l = _settle(H["wheel_r"], pts["wheel_r"], wr_r, (-0.4, 0, 0.05), 0.015)
    wl_l = _settle(H["wheel_l"], pts["wheel_l"], wl_r, (0.5, 0, 0.3), 0.015)
    up = lambda l, d: (l[0], l[1] + d, l[2])
    mid = lambda l, k: tuple(x * k for x in l)
    _sclip(arm, "die", 32, {
        "body": [(3, r(1.5, 0, 1.5), (0, 0.03, 0)), (6, r(1, 2, -2), (0, 0.01, 0)), (12, body_r, body_l), (14, r(4, 6, -5), up(body_l, 0.04)), (17, body_r, body_l)],
        "barrel": [(6, r(-3), Z0), (11, r(6, -6, 2), mid(bar_l, 0.45)), (16, bar_r, bar_l), (18, r(12, -14, 6), up(bar_l, 0.06)), (21, bar_r, bar_l)],
        "wheel_r": [(4, Z0, Z0), (9, r(0, 6, 34), (-0.2, 0.07, 0.02)), (14, wr_r, wr_l), (16, r(0, 14, 80), up(wr_l, 0.05)), (19, wr_r, wr_l)],
        "wheel_l": [(6, Z0, Z0), (12, r(0, -10, -36), (0.25, 0.07, 0.14)), (18, wl_r, wl_l), (20, r(0, -22, -78), up(wl_l, 0.05)), (23, wl_r, wl_l)],
        "flash": [(1, Z0, Z0, TINY), (32, Z0, Z0, TINY)]})


# ---------------------------------------------------------------------------
# Cristal do Trono
# ---------------------------------------------------------------------------
CRY_C = V((0, 0, 2.3))             # centro do cristal
CRY_RE = 0.6                       # raio no equador
CRY_UP = (0.6, 0.5, 1.25)          # ombro de cima (z, raio) e ponta
CRY_DN = (-0.42, 0.42, -0.95)
CRY_IDLE = 96                      # 4 s: gira 120° (a simetria dos gomos)
CRY_ORBIT_R = 1.2


def _wedge(name, k, upper, material):
    """Um gomo do cristal: dois lados do hexágono, do equador até a ponta. Malha fechada."""
    zs, rs, za = CRY_UP if upper else CRY_DN
    a0 = math.radians(60 * (2 * k + (0 if upper else 1)))
    b = bmesh.new()
    ring = lambda zz, rr: [b.verts.new(CRY_C + V((rr * math.cos(a0 + math.radians(60 * i)), rr * math.sin(a0 + math.radians(60 * i)), zz))) for i in range(3)]
    e, sh = ring(0.0, CRY_RE), ring(zs, rs)
    c0, ap = b.verts.new(CRY_C), b.verts.new(CRY_C + V((0, 0, za)))
    for i in range(2):
        b.faces.new((e[i], e[i + 1], sh[i + 1], sh[i]))
        b.faces.new((sh[i], sh[i + 1], ap))
    b.faces.new((c0, e[0], sh[0], ap))
    b.faces.new((c0, ap, sh[2], e[2]))
    b.faces.new((c0, e[2], e[1], e[0]))
    bmesh.ops.recalc_face_normals(b, faces=b.faces[:])
    o = ck.mesh_from(name, b, material)
    cen = sum((v.co for v in o.data.vertices), V()) / len(o.data.vertices)
    return o, cen, a0 + math.radians(60)


def _runner(name, ang, prof, w, material, thick=0.03):
    """Passadeira de pano que desce os degraus na direção `ang`: perfil [(raio, z)], com uma onda de lado (nunca chapada)."""
    ca, sa = math.cos(ang), math.sin(ang)
    b = bmesh.new()
    rows = []
    for i, (rr, zz) in enumerate(prof):
        row = []
        for j in range(4):
            u = j / 3 - 0.5
            lift = 0.022 * math.sin(i * 1.9 + j * 2.4 + ang * 3.0) + 0.034
            side = u * w * (1.0 + 0.1 * math.sin(i * 1.3 + ang))
            for t in (thick, 0.0):
                row.append(b.verts.new((rr * ca - side * sa, rr * sa + side * ca, zz + lift + t)))
        rows.append(row)
    k = lambda i, j, t: rows[i][j * 2 + t]
    n = len(prof)
    for i in range(n - 1):
        for j in range(3):
            b.faces.new((k(i, j, 0), k(i, j + 1, 0), k(i + 1, j + 1, 0), k(i + 1, j, 0)))
            b.faces.new((k(i, j, 1), k(i + 1, j, 1), k(i + 1, j + 1, 1), k(i, j + 1, 1)))
        b.faces.new((k(i, 0, 0), k(i + 1, 0, 0), k(i + 1, 0, 1), k(i, 0, 1)))
        b.faces.new((k(i, 3, 0), k(i, 3, 1), k(i + 1, 3, 1), k(i + 1, 3, 0)))
    for j in range(3):
        b.faces.new((k(0, j, 0), k(0, j, 1), k(0, j + 1, 1), k(0, j + 1, 0)))
        b.faces.new((k(n - 1, j, 0), k(n - 1, j + 1, 0), k(n - 1, j + 1, 1), k(n - 1, j, 1)))
    bmesh.ops.recalc_face_normals(b, faces=b.faces[:])
    return ck.mesh_from(name, b, material)


def throne_crystal(cid="mob_throne_crystal"):
    m = lambda n, col, rough=0.9, em=0.0: ck.mat("m_%s_%s" % (cid, n), col, rough, em)
    stone, stone_d, stone_l, gold = m("stone", STONE), m("stone_d", STONE_D), m("stone_l", STONE_L), m("gold", GOLD, 0.45)
    g_up, g_dn = ck.mat("glow_crystal", CRYSTAL, 0.3, 1.0), ck.mat("glow_crystal_deep", CRYSTAL_DEEP, 0.3, 0.75)
    g_sp = ck.mat("glow_crystal_spark", SPARK, 0.3, 1.25)
    tint = ck.mat("tint", TINT, 0.85)
    P = _Parts()
    spec = {"root": ((0, 0, 0), None), "body": (tuple(CRY_C), "root"), "orbit": (tuple(CRY_C), "root"), "core": ((0, 0, 1.1), "root")}
    shards = []
    for k in range(3):
        for upper in (True, False):
            i = len(shards) + 1
            o, cen, ang = _wedge("shard%d" % i, k, upper, g_up if upper else g_dn)
            spec["shard_%d" % i] = (tuple(cen), "body")
            P.add("shard_%d" % i, o)
            shards.append(("shard_%d" % i, cen, ang, upper))
    bones = _bones(spec)
    arm = lp.make_armature("rig_" + cid, bones)
    H = {n: V(b[0]) for n, b in bones.items()}

    # --- pedestal entalhado (root)
    P.add("root", ck.tube("base", (0, 0, 0), (0, 0, 0.22), 1.08, 1.02, stone, 8), ck.tube("step", (0, 0, 0.22), (0, 0, 0.42), 0.84, 0.79, stone_l, 8),
          ck.tube("column", (0, 0, 0.42), (0, 0, 0.9), 0.5, 0.4, stone, 10), ck.tube("capital", (0, 0, 0.9), (0, 0, 1.06), 0.42, 0.8, stone_l, 10),
          ck.tube("dish", (0, 0, 1.06), (0, 0, 1.1), 0.8, 0.74, stone_d, 10),
          _hoop("dish_rim", (0, 0, 1.08), 0.84, 0.07, 0.07, gold, 12), _hoop("foot_ring", (0, 0, 0.45), 0.54, 0.06, 0.07, gold, 12))
    for k in range(8):                                             # entalhes: losangos de ouro no degrau e nichos escuros na base
        a = math.tau * (k + 0.5) / 8
        ca, sa = math.cos(a), math.sin(a)
        if k % 2:
            P.add("root", _beam("niche%d" % k, (ca * 0.9, sa * 0.9, 0.04), (ca * 0.9, sa * 0.9, 0.18), 0.34, 0.22, stone_d, (ca, sa, 0)),
                  wb._stud("gem%d" % k, (ca * 0.755, sa * 0.755, 0.32), 0.07, gold, (1, 1, 1.4)))
        a2 = math.tau * k / 8
        P.add("root", _beam("flute%d" % k, (math.cos(a2) * 0.475, math.sin(a2) * 0.475, 0.5), (math.cos(a2) * 0.405, math.sin(a2) * 0.405, 0.86), 0.07, 0.05, stone_d, (math.cos(a2), math.sin(a2), 0)))
    for k in range(4):                                             # garras que seguram o ar em volta do cristal
        a = math.tau * (k + 0.5) / 4
        ca, sa = math.cos(a), math.sin(a)
        pr = ((0.66, 1.02), (0.98, 1.2), (1.1, 1.5), (0.98, 1.8), (0.8, 2.0))
        P.add("root", _sm(wb._horn("claw%d" % k, [(ca * rr, sa * rr, zz) for rr, zz in pr], (0.14, 0.13, 0.1, 0.07, 0.025), stone_l, 6)),
              ck.tube("claw_band%d" % k, (ca * 1.085, sa * 1.085, 1.38), (ca * 1.1, sa * 1.1, 1.5), 0.125, 0.12, gold, 6))
    # --- cor do dono (`tint`): faixa na coluna + quatro passadeiras descendo os degraus
    P.add("root", ck.tube("sash", (0, 0, 0.6), (0, 0, 0.74), 0.475, 0.455, tint, 10))
    prof = ((0.5, 0.425), (0.72, 0.425), (0.845, 0.41), (0.87, 0.24), (1.0, 0.225), (1.085, 0.2), (1.12, 0.03), (1.42, 0.0))
    for k in range(4):
        P.add("root", _sm(_runner("runner%d" % k, math.tau * k / 4, prof, 0.5, tint)))
        a = math.tau * k / 4
        P.add("root", wb._stud("runner_pin%d" % k, (math.cos(a) * 0.62, math.sin(a) * 0.62, 0.47), 0.055, gold))
    # --- luz do prato (core) e as lascas que giram (orbit)
    P.add("core", ck.tube("light", (0, 0, 1.1), (0, 0, 1.125), 0.62, 0.5, g_sp, 10))
    for k in range(4):
        a = math.tau * (k + 0.5) / 4 + 0.4
        zz = CRY_C.z + (0.38 if k % 2 else -0.3)
        c = V((math.cos(a) * CRY_ORBIT_R, math.sin(a) * CRY_ORBIT_R, zz))
        P.add("orbit", wb._crystal("spark%d" % k, c - V((0, 0, 0.32)), c + V((0, 0, 0.4)), 0.15, 0.13, g_sp, 4, 0.45, a))
    P.finish(arm, cid)
    _crystal_clips(arm, H, P.pts, shards)
    return arm


def _crystal_clips(arm, H, pts, shards):
    s = math.sin
    E = CRY_IDLE
    keys = {"body": _loop(E, 4, lambda ph, t: (r(0, 120.0 * t, 0), (0, 0.06 * s(ph), 0), (1 + 0.025 * s(2 * ph),) * 3)),
            "orbit": _loop(E, 4, lambda ph, t: (r(0, -90.0 * t, 0), (0, 0.05 * s(ph + 1.2), 0))),
            "core": _loop(E, 4, lambda ph, t: (Z0, Z0, (1 + 0.14 * s(2 * ph),) * 3))}
    _sclip(arm, "idle", E, keys, loop=True)
    # hit: o cristal encolhe e inclina, os gomos abrem uma fresta e fecham, a luz do prato estoura
    keys = {"body": [(1, Z0, Z0, ONE), (2, r(6, 0, -5), (0, -0.07, 0), (0.94, 0.94, 0.94)), (5, r(-3, 0, 2.5), (0, 0.04, 0), (1.03, 1.03, 1.03)), (9, r(1, 0, -1), Z0, ONE), (12, Z0, Z0, ONE)],
            "orbit": [(2, r(0, -8, 0), (0, 0.1, 0)), (6, r(0, 3, 0), (0, -0.03, 0)), (12, Z0, Z0)],
            "core": _sc([(1, 1.0), (2, 1.7), (6, 0.8), (12, 1.0)])}
    for name, cen, ang, upper in shards:
        out = (math.cos(ang) * 0.07, 0.035 if upper else -0.035, -math.sin(ang) * 0.07)
        keys[name] = [(1, Z0, Z0), (2, Z0, out), (4, Z0, tuple(x * 0.6 for x in out)), (7, Z0, Z0)]
    _sclip(arm, "hit", 12, keys)
    # die: incha, estoura no quadro 5 e os seis gomos caem deitados em volta do pedestal
    keys = {"body": [(1, Z0, Z0, ONE), (2, r(3, 0, -3), Z0, (1.05, 1.05, 1.05)), (3, r(-3, 0, 3), Z0, (1.1, 1.1, 1.1)), (4, r(2, 0, -2), Z0, (1.15, 1.15, 1.15)), (5, Z0, Z0, ONE)],
            "orbit": [(1, Z0, Z0, ONE), (4, r(0, -20, 0), Z0, (1.25, 1.25, 1.25)), (7, r(0, -60, 0), (0, -0.3, 0), (0.5, 0.5, 0.5)), (9, r(0, -80, 0), (0, -0.5, 0), TINY)],
            "core": _sc([(1, 1.0), (4, 2.0), (7, 1.2), (13, 0.001)])}
    rnd = random.Random(17)
    for i, (name, cen, ang, upper) in enumerate(shards):
        rad = V((math.cos(ang), math.sin(ang), 0))
        tang = V((-math.sin(ang), math.cos(ang), 0))
        tip = math.radians((104 if upper else -66) + rnd.uniform(-6, 6))            # a ponta tomba para fora (de cima) / o gomo de baixo deita de costas
        world = Matrix.Rotation(math.radians(rnd.uniform(-35, 35)), 3, "Z") @ Matrix.Rotation(tip, 3, tang)
        rot = _local_euler(world)
        dist = (1.95 if upper else 1.5) + rnd.uniform(-0.1, 0.15)
        target = rad * dist + tang * rnd.uniform(-0.25, 0.25)
        loc = _settle(H[name], pts[name], rot, (target.x - cen.x, 0.0, -(target.y - cen.y)), 0.015)
        f0 = 5 + (i % 3)
        fl = f0 + (13 if upper else 11)
        ks = [(f0 - 1, Z0, Z0) if f0 > 2 else (1, Z0, Z0)]
        n = 4
        for j in range(1, n + 1):
            t = j / n
            y = loc[1] * t * t + (0.75 if upper else 0.35) * 4 * t * (1 - t) * (1 - t)
            ks.append((f0 + round((fl - f0) * t), tuple(a * min(1.0, t * 1.15) for a in rot), (loc[0] * t, y, loc[2] * t)))
        ks[-1] = (fl, rot, loc)
        ks.append((fl + 2, tuple(a * 0.97 for a in rot), (loc[0] * 1.03, loc[1] + 0.09, loc[2] * 1.03)))
        ks.append((fl + 5, rot, (loc[0] * 1.05, loc[1], loc[2] * 1.05)))
        keys[name] = ks
    _sclip(arm, "die", 40, keys)


# ---------------------------------------------------------------------------
# Estandarte de guilda (prop)
# ---------------------------------------------------------------------------
BAN_W, BAN_DROP, BAN_TOP, BAN_Y = 1.3, 2.75, 4.2, -0.24


def _ban_surface(u, t):
    """Ponto do meio do pano: u 0..1 de lado, t 0 (barra) .. 1 (travessa). Dobras mais soltas embaixo."""
    amp = 0.15
    yb = amp * math.sin(u * math.pi * 2.6 + 0.6) * (0.4 + 0.6 * (1.0 - t)) + amp * 0.45 * math.sin(t * 5.0 + u * 2.0) * (1.0 - t) + amp * 0.8 * (u - 0.5) * (1.0 - t) ** 2
    bot = BAN_DROP * 0.2 * (1.0 - abs(2.0 * u - 1.0))            # rabo de andorinha
    return V(((u - 0.5) * BAN_W, BAN_Y + yb, BAN_TOP - BAN_DROP + bot + (BAN_DROP - bot) * t))


def _gonfalon(name, material, hem, nx=8, ny=7, thick=0.035):
    b = bmesh.new()
    vs = []
    for i in range(ny + 1):
        for j in range(nx + 1):
            p = _ban_surface(j / nx, i / ny)
            for sgn in (-0.5, 0.5):
                vs.append(b.verts.new(p + V((0, thick * sgn, 0))))
    k = lambda i, j, sd: vs[(i * (nx + 1) + j) * 2 + sd]
    for i in range(ny):
        for j in range(nx):
            for f in (b.faces.new((k(i, j, 0), k(i, j + 1, 0), k(i + 1, j + 1, 0), k(i + 1, j, 0))),
                      b.faces.new((k(i, j, 1), k(i + 1, j, 1), k(i + 1, j + 1, 1), k(i, j + 1, 1)))):
                f.material_index = 1 if i == 0 else 0
    for j in range(nx):
        b.faces.new((k(0, j, 0), k(0, j, 1), k(0, j + 1, 1), k(0, j + 1, 0))).material_index = 1
        b.faces.new((k(ny, j, 0), k(ny, j + 1, 0), k(ny, j + 1, 1), k(ny, j, 1)))
    for i in range(ny):
        b.faces.new((k(i, 0, 0), k(i + 1, 0, 0), k(i + 1, 0, 1), k(i, 0, 1))).material_index = 1 if i == 0 else 0
        b.faces.new((k(i, nx, 0), k(i, nx, 1), k(i + 1, nx, 1), k(i + 1, nx, 0))).material_index = 1 if i == 0 else 0
    bmesh.ops.recalc_face_normals(b, faces=b.faces[:])
    o = ck.mesh_from(name, b, material)
    o.data.materials.append(hem)
    return o


def _crest(name, material, side, off=0.045):
    """Brasão em forma de escudo, colado nas dobras do pano (frente side=-1, costas side=+1)."""
    rows = ((0.0, 0.25), (0.2, 0.26), (0.45, 0.25), (0.62, 0.21), (0.78, 0.15), (0.9, 0.08), (1.0, 0.012))     # (descida 0..1, meia largura em u)
    t_top, t_bot = 0.86, 0.4
    b = bmesh.new()
    grid = []
    for sdn, hw in rows:
        t = t_top + (t_bot - t_top) * sdn
        grid.append([b.verts.new(_ban_surface(0.5 + hw * (j / 2 - 1.0), t) + V((0, side * off, 0))) for j in range(5)])
    for i in range(len(rows) - 1):
        for j in range(4):
            b.faces.new((grid[i][j], grid[i][j + 1], grid[i + 1][j + 1], grid[i + 1][j]))
    bmesh.ops.recalc_face_normals(b, faces=b.faces[:])
    for f in b.faces:                                              # a face olha para fora do pano
        if f.normal.y * side < 0:
            f.normal_flip()
    return ck.mesh_from(name, b, material)


def gvg_banner(m):
    """Estandarte de guilda em tamanho real (~5 m), pé em z = 0, frente do pano = -Y. `tint` = pano, `tint2` = brasão e barra."""
    tint = m["tint"]
    tint2 = ck.mat("tint2", TINT2, 0.8)
    wood, wood_d = ck.mat("p_gvg_pole", WOOD_D, 0.85), ck.mat("p_gvg_pole_d", (0.3, 0.21, 0.16), 0.85)
    gold, stone, stone_d = ck.mat("p_gvg_gold", GOLD, 0.45), m["stone"], m["stone_d"]
    parts = [ck.tube("base", (0, 0, 0), (0, 0, 0.24), 0.46, 0.4, stone_d, 6), ck.tube("base2", (0, 0, 0.24), (0, 0, 0.44), 0.3, 0.25, stone, 6),
             ck.tube("collar", (0, 0, 0.44), (0, 0, 0.54), 0.12, 0.1, gold, 6),
             ck.tube("pole", (0, 0, 0.3), (0, 0, 4.62), 0.075, 0.055, wood, 6),
             ck.tube("bar", (-0.78, BAN_Y + 0.02, BAN_TOP + 0.03), (0.78, BAN_Y + 0.02, BAN_TOP + 0.03), 0.045, 0.045, wood_d, 6),
             ck.tube("bar_arm", (0, 0.02, BAN_TOP + 0.03), (0, BAN_Y, BAN_TOP + 0.03), 0.04, 0.04, wood_d, 5),
             ck.tube("cap", (0, 0, 4.58), (0, 0, 4.68), 0.09, 0.07, gold, 6),
             wb._crystal("finial", (0, 0, 4.68), (0, 0, 5.08), 0.1, 0.085, gold, 4, 0.6)]
    for sx in (-1, 1):
        parts.append(wb._stud("bar_end%d" % sx, (sx * 0.8, BAN_Y + 0.02, BAN_TOP + 0.03), 0.075, gold))
        parts.append(ck.tube("cord%d" % sx, (0, 0, 4.56), (sx * 0.7, BAN_Y + 0.02, BAN_TOP + 0.06), 0.014, 0.014, gold, 3))
        parts.append(ck.tube("tassel%d" % sx, (sx * 0.74, BAN_Y + 0.02, BAN_TOP - 0.02), (sx * 0.74, BAN_Y + 0.03, BAN_TOP - 0.3), 0.02, 0.05, gold, 5))
    parts.append(_gonfalon("cloth", tint, tint2))
    parts.append(_crest("crest_f", tint2, -1))
    parts.append(_crest("crest_b", tint2, 1))
    for o in parts[-3:]:
        for p in o.data.polygons:
            p.use_smooth = True
    return parts


BUILDERS = {"mob_siege_ram": siege_ram, "mob_siege_cannon": siege_cannon, "mob_throne_crystal": throne_crystal}
PROP_BUILDERS = {"gvg_banner": gvg_banner}
