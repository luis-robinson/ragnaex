"""Chefes de Mundo (GDD design/gdd/momentos-do-mundo.md §3.1): um por faixa, em lugar fixo da zona.

`mob_ancestral_boar` = Javali Ancestral (faixa 1-10, Vale de Aldara). Peças rígidas no rig de quadrúpede do mob_kit
(root, body, head, leg_fr/fl/br/bl, tail; arm_r/arm_l sobram do MOB_BONES e ficam em repouso), uma malha por osso
(`ab_<osso>`). Lombo de musgo com pedras, raízes e cogumelos, presa grande curva do lado esquerdo (+X) e a direita
quebrada, flechas/lança velhas cravadas no couro, olhos âmbar (`glow_*`, energia baixa).

Clipes (24 fps, impacto = EntityView.IMPACT_FRAME): idle, run, attack (5), hit, die, atk_charge (5), slam (8), roar (7),
shout (7, cópia do roar), maul (7), pounce (9), brace (6). TODO osso tem chave em TODO clipe (`_clip`).
Chão: `_ground` roda depois dos clipes; pata que passaria do chão recolhe para dentro do ombro/coxa (até LEG_TUCK) e o que
sobrar sobe a raiz. Tamanho nativo ~ o do mob_boar x1,25 (SIZE); no jogo a sugestão é MonsterDef.scale 3,0.

    mob_kit.build_all(out, only=["mob_ancestral_boar"])
    blender -b --factory-startup --python tools/blender/world_bosses_preview.py -- --out=<pasta ABSOLUTA> [--export=<abs assets/models>] [--ground]
"""
import math
import random

import bmesh
import bpy
from mathutils import Vector
from mathutils.bvhtree import BVHTree

import chibi_kit as ck
import lowpoly_lib as lp
import build_monsters as bm
import mob_kit as mk
import boss_gestures as bg

V = Vector

SIZE = 0.68                 # o javali é desenhado em "unidades de desenho" (lombo a ~1,3) e encolhido inteiro: cernelha a ~0,95
LEG_TUCK = 0.2              # quanto (unidades de desenho) a pata pode recolher para dentro do corpo antes de a raiz subir
DIE_SINK = 0.006
# espinha: anca -> lombo -> meio -> cernelha (ombros pesados) -> pescoço
SPINE = [((0, 0.62, 0.62), 0.3), ((0, 0.3, 0.7), 0.4), ((0, -0.05, 0.78), 0.46), ((0, -0.4, 0.9), 0.53), ((0, -0.7, 0.76), 0.4)]
WIDE = 1.14                 # o tronco é mais largo que alto (lido de cima)
HEAD_K = 1.22               # cabeça chibi: tudo do osso da cabeça cresce em volta de HEAD e avança HEAD_SHIFT
HEAD_SHIFT = (0, -0.03, 0.07)
HEAD = (0, -1.0, 0.64)
BOAR_CLIPS = ("idle", "run", "attack", "hit", "die", "atk_charge", "slam", "roar", "shout", "maul", "pounce", "brace")
IMPACT = {"attack": 5, "atk_charge": 5, "slam": 8, "roar": 7, "shout": 7, "maul": 7, "pounce": 9, "brace": 6}

FUR = (0.54, 0.38, 0.28)
FUR_D = (0.3, 0.2, 0.16)
FUR_L = (0.82, 0.66, 0.5)
GREY = (0.9, 0.82, 0.68)           # pelo velho (costeletas, barbicha)
MOSS = (0.42, 0.6, 0.3)
MOSS_L = (0.66, 0.78, 0.4)
STONE = (0.66, 0.66, 0.64)
STONE_D = (0.48, 0.5, 0.52)
ROOT = (0.5, 0.36, 0.22)
IVORY = (0.95, 0.9, 0.76)
IVORY_D = (0.74, 0.64, 0.48)
HOOF = (0.2, 0.16, 0.15)
NOSE = (0.86, 0.56, 0.54)
AMBER = (1.0, 0.68, 0.18)
WOOD = (0.42, 0.3, 0.2)
FLETCH = (0.86, 0.4, 0.34)
FLETCH2 = (0.92, 0.86, 0.66)
CAP = (0.92, 0.52, 0.42)
PETAL = (0.98, 0.92, 0.6)


# ---------------------------------------------------------------------------
# helpers de malha
# ---------------------------------------------------------------------------
def _rock(name, c, r, material, seed, sq=(1.0, 1.0, 0.72), sub=1):
    rnd = random.Random(seed)
    b = bmesh.new()
    bmesh.ops.create_icosphere(b, subdivisions=sub, radius=r)
    for v in b.verts:
        k = 1.0 + rnd.uniform(-0.2, 0.2)
        v.co = V((v.co.x * sq[0] * k, v.co.y * sq[1] * k, v.co.z * sq[2] * k)) + V(c)
    return ck.mesh_from(name, b, material)


def _shell(name, src, pick, off, material, tuck=0.025):
    """Manta rente ao corpo: as faces de `src` que `pick(centro, normal)` aceita, empurradas `off` para fora; a borda entra no corpo."""
    b = bmesh.new()
    b.from_mesh(src.data)
    b.normal_update()
    drop = [f for f in b.faces if not pick(f.calc_center_median(), f.normal)]
    bmesh.ops.delete(b, geom=drop, context="FACES")
    b.normal_update()
    moves = [(v, v.normal.copy() * (-tuck if v.is_boundary else off)) for v in b.verts]
    for v, d in moves:
        v.co += d
    return ck.mesh_from(name, b, material)


def _chain(name, pts, r0, r1, material, segs=5):
    """Raiz/cicatriz: tubos emendados pelos pontos, afinando de r0 a r1."""
    out = []
    n = len(pts) - 1
    for i in range(n):
        a, b_ = r0 + (r1 - r0) * i / n, r0 + (r1 - r0) * (i + 1) / n
        out.append(ck.tube("%s_%d" % (name, i), pts[i], pts[i + 1], a, b_, material, segs))
        if i:
            out.append(ck.ball("%s_j%d" % (name, i), a * 0.98, pts[i], material))
    return out


def _tuft(name, a, b_, r, material, segs=6):
    """Tufo de pelo rombudo (cone de ponta grossa): lê como pelo, não como espinho."""
    return ck.tube(name, a, b_, r, r * 0.3, material, segs)


def _perp(d):
    d = V(d).normalized()
    u = d.cross(V((0, 0, 1)))
    if u.length < 0.2:
        u = d.cross(V((1, 0, 0)))
    u.normalize()
    return d, u, d.cross(u).normalized()


def _stuck(name, p, d, length, r, wood, fletch=None, cloth=None, broken=False):
    """Flecha/lança velha cravada em p, saindo na direção d. fletch = material da pena; cloth = trapo pendurado (lança)."""
    d, u, w = _perp(d)
    p = V(p)
    end = p + d * length
    out = [ck.tube(name, p - d * 0.06, end, r, r * 0.92, wood, 6)]
    if broken:                                     # haste partida: lasca torta na ponta
        out.append(ck.tube(name + "_snap", end, end + d * (r * 3.0) + u * (r * 2.2), r * 0.9, r * 0.15, wood, 5))
    if fletch:
        for i, side in enumerate((u, w)):
            out.append(ck.blade("%s_f%d" % (name, i), p + d * (length * 0.55), end + d * 0.004, r * 7.5, r * 0.7, fletch, side, 0.72))
        out.append(ck.tube(name + "_nock", end - d * 0.004, end + d * 0.02, r * 1.25, r * 1.1, wood, 6))
    if cloth:
        a = p + d * (length * 0.62)
        out.append(ck.tube(name + "_wrap", a - d * 0.04, a + d * 0.04, r * 1.5, r * 1.5, cloth, 6))
        hang = a + u * 0.03
        out.append(ck.blade(name + "_rag", hang, hang + V((u.x * 0.12, u.y * 0.12, -0.26)), 0.13, 0.016, cloth, d, 0.4))
        out.append(ck.blade(name + "_rag2", hang, hang + V((-u.x * 0.05 + w.x * 0.08, -u.y * 0.05 + w.y * 0.08, -0.18)), 0.09, 0.016, cloth, d, 0.5))
    return out


# ---------------------------------------------------------------------------
# Javali Ancestral
# ---------------------------------------------------------------------------
def ancestral_boar(cid="mob_ancestral_boar"):
    K = SIZE
    S = lambda p: tuple(x * K for x in p)
    bones = mk.pivots(body=S((0, 0.4, 0.62)), head=S((0, -0.74, 0.8)),
                      leg_fr=S((0.37, -0.42, 0.64)), leg_fl=S((-0.37, -0.42, 0.64)),
                      leg_br=S((0.34, 0.48, 0.64)), leg_bl=S((-0.34, 0.48, 0.64)))
    th = S((0, 0.84, 0.7))
    arm = lp.make_armature("rig_" + cid, dict(bones, tail=(th, (th[0], th[1] + 0.38, th[2] + 0.06), "body")))
    m = lambda n, col, rough=0.85, em=0.0: ck.mat("m_%s_%s" % (cid, n), col, rough, em)
    fur, dark, light, grey = m("fur", FUR), m("dark", FUR_D), m("light", FUR_L), m("grey", GREY)
    moss, moss2 = m("moss", MOSS, 0.95), m("moss2", MOSS_L, 0.95)
    stone, stone2, root = m("stone", STONE, 0.9), m("stone2", STONE_D, 0.9), m("root", ROOT, 0.9)
    ivory, ivory2, hoof, nose = m("ivory", IVORY, 0.5), m("ivory2", IVORY_D, 0.6), m("hoof", HOOF, 0.6), m("nose", NOSE, 0.6)
    wood, fletch, fletch2 = m("wood", WOOD, 0.9), m("fletch", FLETCH, 0.9), m("fletch2", FLETCH2, 0.9)
    cap, petal, scar = m("cap", CAP, 0.7), m("petal", PETAL, 0.8), m("scar", (0.84, 0.62, 0.56), 0.8)
    eye_d = m("socket", (0.12, 0.08, 0.08), 0.5)
    glow = ck.mat("glow_%s_eye" % cid, AMBER, 0.3, 1.3)
    parts, flat = [], set()

    def add(o, bone, faceted=False):
        for x in (o if isinstance(o, (list, tuple)) else [o]):
            parts.append((x, bone))
            if faceted:
                flat.add(x.name)

    # ---------------- tronco ----------------
    body = mk.skin_body("body", SPINE, [(i, i + 1) for i in range(len(SPINE) - 1)], fur)
    for v in body.data.vertices:
        v.co.x *= WIDE
    add(body, "body")
    tb = bmesh.new()
    tb.from_mesh(body.data)
    bvh = BVHTree.FromBMesh(tb)

    def cast(o, d):
        hit = bvh.ray_cast(V(o), V(d).normalized())
        return (hit[0], hit[1]) if hit[0] is not None else (None, None)

    def top(x, y, lift=0.0):
        p, n = cast((x, y, 5), (0, 0, -1))
        if p is None:
            p, n = V((x, y, 0.9)), V((0, 0, 1))
        return p + n * lift, n

    def flank(sx, y, z, lift=0.0):
        p, n = cast((sx * 3, y, z), (-sx, 0, 0))
        if p is None:
            p, n = V((sx * 0.3, y, z)), V((sx, 0, 0))
        return p + n * lift, n

    add(mk.blob("belly", 0.36, (0, -0.06, 0.44), light, (0.95, 1.9, 0.5)), "body")
    add(mk.blob("chest", 0.3, (0, -0.74, 0.52), light, (1.05, 0.8, 0.85)), "body")

    # ---------------- manta de musgo no lombo (duas camadas) + tufos ----------------
    def moss_pick(c, n):
        edge = 0.34 + 0.2 * math.sin(c.y * 8.5 + 0.7) * math.cos(c.x * 6.0) + 0.1 * math.sin(c.y * 21.0)
        return n.z > edge and -0.5 < c.y < 0.96

    def moss2_pick(c, n):
        return n.z > 0.72 + 0.14 * math.sin(c.y * 11.0 + c.x * 9.0) and -0.3 < c.y < 0.8 and (math.sin(c.y * 6.3 + 1.0) > -0.25)

    add(_shell("moss", body, moss_pick, 0.035, moss), "body")
    add(_shell("moss_hi", body, moss2_pick, 0.06, moss2), "body")
    for i, (x, y, r_, mt) in enumerate(((0.4, -0.3, 0.15, moss), (-0.44, -0.2, 0.14, moss), (0.42, 0.14, 0.13, moss), (-0.38, 0.34, 0.14, moss),
                                        (0.26, 0.6, 0.12, moss), (-0.14, -0.02, 0.12, moss2), (0.2, 0.36, 0.1, moss2), (-0.24, 0.66, 0.11, moss),
                                        (0.3, -0.06, 0.1, moss2), (-0.3, 0.1, 0.09, moss2))):
        p, n = top(x, y, 0.01)
        add(mk.blob("mosstuft%d" % i, r_, p, mt, (1.15, 1.25, 0.5), 2), "body")
    # barbas de musgo que escorrem pelo flanco (franja lida de lado e na câmera alta)
    for i, (sx, y, z, ln) in enumerate(((1, -0.24, 0.92, 0.24), (1, 0.1, 0.86, 0.2), (1, 0.42, 0.8, 0.22), (-1, -0.12, 0.9, 0.22), (-1, 0.22, 0.84, 0.24),
                                        (-1, 0.52, 0.76, 0.18))):
        p, n = flank(sx, y, z, -0.01)
        add(ck.blade("mossdrip%d" % i, p, p + V((sx * 0.04, 0.02, -ln)), 0.17, 0.035, moss, (0, 1, 0), 0.35), "body")

    # ---------------- pedras, raízes, cogumelos, brotos ----------------
    for i, (x, y, r_, mt, sub) in enumerate(((0.08, 0.26, 0.17, stone, 2), (-0.22, 0.48, 0.11, stone2, 1), (0.3, 0.0, 0.1, stone2, 1), (-0.12, -0.12, 0.08, stone, 1),
                                             (0.2, 0.56, 0.08, stone, 1), (-0.34, 0.12, 0.09, stone, 1))):
        p, n = top(x, y)
        add(_rock("stone%d" % i, p + n * (r_ * 0.25), r_, mt, 11 + i * 7, sub=sub), "body", True)
    # raízes grossas: saem do nó no alto da cernelha e descem pelos dois lados do lombo
    for i, path in enumerate((((0.06, -0.36), (0.26, -0.24), (0.42, -0.04), (0.5, 0.2), (0.48, 0.42)),
                              ((-0.04, -0.34), (-0.2, -0.16), (-0.3, 0.02), (-0.44, 0.26), (-0.46, 0.5)))):
        pts = [top(x, y, 0.02)[0] for x, y in path]
        add(_chain("root%d" % i, pts, 0.055, 0.02, root, 6), "body")
    knot, _n = top(0.02, -0.34, 0.03)
    add(ck.ball("rootknot", 0.075, knot, root, (1.2, 1.2, 0.8)), "body")
    # broto com duas folhas no nó das raízes
    st = knot + V((0.03, 0.05, 0.24))
    add(ck.tube("sprout", knot, st, 0.024, 0.014, root, 5), "body")
    add(ck.blade("leaf0", st, st + V((0.2, 0.05, 0.1)), 0.13, 0.02, moss2, (0, 1, 0), 0.5), "body")
    add(ck.blade("leaf1", st, st + V((-0.14, 0.14, 0.12)), 0.11, 0.02, moss2, (1, 1, 0), 0.5), "body")
    for i, (x, y, h, r_) in enumerate(((-0.36, -0.04, 0.1, 0.07), (-0.28, -0.1, 0.07, 0.05), (0.36, 0.38, 0.08, 0.06))):
        p, n = top(x, y)
        add(ck.tube("shroom%d" % i, p - n * 0.02, p + n * h, 0.022, 0.018, light, 5), "body")
        add(ck.ball("shroomcap%d" % i, r_, p + n * h, cap, (1.0, 1.0, 0.62)), "body")
    for i, (x, y) in enumerate(((0.3, 0.22), (-0.14, 0.6), (0.1, -0.1), (-0.4, 0.3), (0.06, 0.74))):
        p, n = top(x, y, 0.06)
        add(ck.ball("flower%d" % i, 0.032, p, petal), "body")

    # ---------------- crina: tufos grossos de cerdas escuras, da nuca à cernelha (moicano lido de cima e de lado) ----------------
    for i in range(6):
        y = -1.02 + i * 0.15
        p, n = top(0, y, -0.06)
        hgt = (0.2, 0.28, 0.34, 0.32, 0.26, 0.18)[i]
        add(_tuft("bristle%d" % i, p, p + V((0, 0.14, hgt)), 0.13, dark, 7), "body")
        if i in (1, 2, 3, 4):
            for sx in (-1, 1):
                q, n = top(sx * 0.15, y + 0.07, -0.05)
                add(_tuft("bristle%d_%d" % (i, sx), q, q + V((sx * 0.07, 0.12, hgt * 0.62)), 0.1, dark, 6), "body")
    # ombros pesados: massa de pelo escuro por cima do ombro, tufos rombudos, juba clara do peito
    for sx in (-1, 1):
        add(mk.blob("shoulderfur%d" % sx, 0.24, (sx * 0.42, -0.46, 0.8), dark, (0.7, 1.1, 1.05), 2), "body")
        for j in range(3):
            a = V((sx * (0.47 - j * 0.02), -0.56 + j * 0.15, 0.7 - j * 0.02))
            add(_tuft("shouldertuft%d_%d" % (sx, j), a, a + V((sx * 0.06, 0.06, -0.2)), 0.09, dark), "body")
    for i, (x, z) in enumerate(((-0.17, 0.42), (0.0, 0.38), (0.17, 0.42))):
        add(_tuft("dewlap%d" % i, (x, -0.86, z + 0.12), (x * 1.1, -0.84, z - 0.1), 0.1, light), "body")
    # cicatrizes de garra no flanco direito (-X)
    for i in range(3):
        a, _n = flank(-1, 0.02 + i * 0.11, 0.9 - i * 0.02, 0.004)
        b_, _n = flank(-1, 0.18 + i * 0.11, 0.6 - i * 0.02, 0.004)
        mid, _n = flank(-1, 0.1 + i * 0.11, 0.75 - i * 0.02, 0.01)
        add(_chain("scar%d" % i, [a, mid, b_], 0.026, 0.012, scar, 4), "body")

    # ---------------- flechas e lança de caçadas antigas ----------------
    p, n = top(-0.26, -0.4)
    add(_stuck("spear", p, (-0.38, 0.4, 0.84), 0.66, 0.028, wood, cloth=fletch, broken=True), "body")
    p, n = top(0.36, 0.1)
    add(_stuck("arrow0", p, (0.45, 0.25, 0.86), 0.36, 0.016, wood, fletch), "body")
    p, n = top(0.18, 0.66)
    add(_stuck("arrow1", p, (0.2, 0.55, 0.8), 0.32, 0.016, wood, fletch2), "body")
    p, n = flank(-1, 0.5, 0.78)
    add(_stuck("arrow2", p, (-0.8, 0.3, 0.52), 0.32, 0.016, wood, fletch), "body")
    p, n = top(0.36, -0.46)
    add(_stuck("arrow3", p, (0.5, -0.2, 0.84), 0.15, 0.017, wood, broken=True), "body")
    p, n = flank(1, 0.44, 0.7)
    add(_stuck("arrow4", p, (0.85, 0.4, 0.34), 0.3, 0.016, wood, fletch2), "body")

    # ---------------- cabeça (desenhada em volta de HEAD; cresce HEAD_K no fim) ----------------
    hc = V(HEAD)
    n_head = len(parts)
    add(mk.blob("skull", 0.31, hc, fur, (0.98, 1.0, 0.9)), "head")
    snout = mk.skin_body("snout", [((0, -1.08, 0.6), 0.25), ((0, -1.32, 0.55), 0.21), ((0, -1.52, 0.52), 0.17)], [(0, 1), (1, 2)], fur, sub=1)
    add(snout, "head")
    ny = min(v.co.y for v in snout.data.vertices)
    nz = 0.52
    add(ck.tube("nose", (0, ny + 0.04, nz), (0, ny - 0.05, nz - 0.005), 0.15, 0.14, nose, 10), "head")
    for sx in (-1, 1):
        add(ck.ball("nostril%d" % sx, 0.032, (sx * 0.06, ny - 0.05, nz + 0.01), eye_d, (1, 0.4, 1.4)), "head")
    add(mk.blob("jaw", 0.16, (0, -1.28, 0.43), light, (0.95, 1.7, 0.6), 2), "head")
    # sobrancelhas pesadas, olhos âmbar fundos
    for sx in (-1, 1):
        e = hc + V((sx * 0.2, -0.235, 0.06))
        add(ck.ball("socket%d" % sx, 0.07, e, eye_d, (0.8, 0.7, 1.0)), "head")
        add(ck.ball("eye%d" % sx, 0.045, e + V((sx * 0.022, -0.035, 0.0)), glow, (0.9, 0.8, 1.0)), "head")
        add(mk.blob("brow%d" % sx, 0.11, hc + V((sx * 0.19, -0.22, 0.17)), dark, (1.15, 1.05, 0.5), 2), "head")
        # costeletas claras (o bicho é velho): dois tufos rombudos de cada lado
        for j in range(2):
            a = hc + V((sx * 0.25, -0.04 + j * 0.12, -0.06 - j * 0.02))
            add(ck.tube("whisker%d_%d" % (sx, j), a, a + V((sx * 0.1, 0.09, -0.11)), 0.1, 0.05, grey, 6), "head")
    add(ck.blade("ear1", hc + V((0.2, 0.06, 0.18)), hc + V((0.46, 0.2, 0.4)), 0.22, 0.05, dark, (0, 1, 0.3), 0.45), "head")
    add(ck.blade("ear1_in", hc + V((0.22, 0.04, 0.2)), hc + V((0.4, 0.15, 0.36)), 0.11, 0.05, nose, (0, 1, 0.3), 0.45), "head")
    # orelha direita rasgada: duas pontas curtas
    add(ck.blade("ear-1a", hc + V((-0.2, 0.06, 0.18)), hc + V((-0.38, 0.1, 0.36)), 0.12, 0.05, dark, (0, 1, 0.3), 0.45), "head")
    add(ck.blade("ear-1b", hc + V((-0.21, 0.1, 0.17)), hc + V((-0.36, 0.26, 0.26)), 0.11, 0.05, dark, (0, 1, 0.3), 0.45), "head")
    for i, x in enumerate((-0.06, 0.06)):                      # barbicha curta
        add(_tuft("beard%d" % i, (x, -1.16, 0.4), (x * 1.3, -1.12, 0.29), 0.07, grey), "head")
    # presa grande curva (esquerda do bicho, +X): sai do lado do focinho, abre, sobe e volta para trás
    tusk = [((0.1, -1.36, 0.49), 0.09), ((0.33, -1.47, 0.46), 0.088), ((0.52, -1.51, 0.6), 0.072), ((0.61, -1.42, 0.82), 0.05), ((0.56, -1.24, 1.0), 0.02)]
    add(mk.skin_body("tusk_big", tusk, [(i, i + 1) for i in range(len(tusk) - 1)], ivory, sub=1), "head")
    add(ck.tube("tusk_gum1", (0.14, -1.38, 0.485), (0.27, -1.445, 0.47), 0.112, 0.105, ivory2, 8), "head")
    a, b_ = V(tusk[2][0]), V(tusk[3][0])
    add(ck.tube("tusk_band", a.lerp(b_, 0.25), a.lerp(b_, 0.45), 0.072, 0.066, ivory2, 8), "head")
    # presa direita quebrada: toco curto com a quebra em lascas
    add(ck.tube("tusk_stub", (-0.1, -1.36, 0.49), (-0.31, -1.47, 0.48), 0.088, 0.075, ivory, 8), "head")
    add(ck.tube("tusk_gum-1", (-0.14, -1.38, 0.485), (-0.25, -1.44, 0.48), 0.112, 0.105, ivory2, 8), "head")
    add(ck.tube("tusk_chip", (-0.3, -1.465, 0.455), (-0.39, -1.51, 0.56), 0.05, 0.008, ivory, 4), "head", True)
    add(ck.tube("tusk_chip2", (-0.3, -1.465, 0.5), (-0.36, -1.5, 0.43), 0.04, 0.008, ivory2, 4), "head", True)
    # presa de cima (amoladeira) só do lado da presa grande
    add(_tuft("whetter", (0.15, -1.36, 0.62), (0.26, -1.4, 0.76), 0.055, ivory2), "head")
    for o, _b in parts[n_head:]:
        for v in o.data.vertices:
            v.co = hc + (v.co - hc) * HEAD_K + V(HEAD_SHIFT)

    # ---------------- pernas grossas e curtas ----------------
    for bone, sx, front in (("leg_fr", 1, True), ("leg_fl", -1, True), ("leg_br", 1, False), ("leg_bl", -1, False)):
        if front:
            x, y = sx * 0.38, -0.42
            add(mk.blob("shoulder_" + bone, 0.22, (x, y, 0.56), fur, (0.82, 1.0, 1.25), 2), bone)
            r0, r1 = 0.165, 0.135
        else:
            x, y = sx * 0.35, 0.5
            add(mk.blob("haunch_" + bone, 0.25, (x - sx * 0.02, y - 0.04, 0.58), fur, (0.74, 1.0, 1.15), 2), bone)
            r0, r1 = 0.155, 0.128
        add(ck.tube("leg_" + bone, (x, y, 0.5), (x + sx * 0.01, y - 0.02, 0.13), r0, r1, fur, 8), bone)
        for j in range(4):                                     # tufo de pelo escuro acima do casco
            a = math.tau * (j + 0.5) / 4
            c = V((x + sx * 0.01 + math.cos(a) * r1 * 0.8, y - 0.02 + math.sin(a) * r1 * 0.8, 0.25))
            add(_tuft("fetlock%d_%s" % (j, bone), c, c + V((math.cos(a) * 0.05, math.sin(a) * 0.05, -0.14)), 0.075, dark), bone)
        add(ck.tube("hoof_" + bone, (x + sx * 0.01, y - 0.04, 0.14), (x + sx * 0.01, y - 0.04, 0.0), r1 * 0.98, r1 * 1.16, hoof, 8), bone, True)

    # ---------------- rabo fino com tufo ----------------
    tp = [((0, 0.72, 0.72), 0.06), ((0, 1.02, 0.67), 0.042), ((0, 1.13, 0.52), 0.03), ((0, 1.13, 0.4), 0.026)]
    add(mk.skin_body("whip", tp, [(0, 1), (1, 2), (2, 3)], fur, sub=1), "tail")
    add(mk.blob("whip_tuft", 0.07, (0, 1.14, 0.32), dark, (0.8, 0.9, 1.5), 2), "tail")
    tb.free()

    objs = [o for o, _b in parts]
    for o in objs:
        if o.name not in flat:
            ck._smooth(o.data)
    _outward(objs)
    for o in objs:
        for v in o.data.vertices:
            v.co *= K
    by_bone = {}
    for o, bone in parts:
        by_bone.setdefault(bone, []).append(o)
    for bone, objs_ in by_bone.items():
        lp.attach(ck._join(objs_, "ab_" + bone), arm, bone)
    _boar_clips(arm, K)
    legs = ("leg_fr", "leg_fl", "leg_br", "leg_bl")
    _ground(arm, [c for c in BOAR_CLIPS if c != "die"], legs, LEG_TUCK * K)
    _ground(arm, ["die"], (), 0.0, DIE_SINK, head=False)
    return arm


def _outward(objs):
    for o in objs:
        b = bmesh.new()
        b.from_mesh(o.data)
        bmesh.ops.recalc_face_normals(b, faces=b.faces[:])
        b.to_mesh(o.data)
        b.free()


# ---------------------------------------------------------------------------
# clipes
# ---------------------------------------------------------------------------
def _clip(arm, name, keys, end, loop=False):
    """lp.add_action com TODOS os ossos gravados (osso sem chave herdava a pose do último clipe criado)."""
    z = (0, 0, 0)
    for b_ in arm.data.bones.keys():
        if b_ not in keys:
            keys[b_] = [(1, z, z), (end, z, z)]
    lp.add_action(arm, name, keys, end, loop=loop)


def _boar_clips(arm, K):
    """Eixos do rig: corpo X+ = focinho desce (X- empina), Y = gira, Z = rola, loc (0, cima, frente); pernas X- = casco para a
    frente, Z = abre; cabeça X+ = desce, Z = vira; rabo X+ = sobe. O corpo gira em volta da anca (empinar não tira as patas
    de trás do chão)."""
    z = (0, 0, 0)
    r = lambda x=0.0, y=0.0, zz=0.0: (x, y, zz)
    p = lambda up=0.0, fwd=0.0: (0, up * K, fwd * K)
    tau = math.tau
    legs = ("leg_fr", "leg_fl", "leg_br", "leg_bl")

    def planted(body, extra=None):
        """as quatro patas desfazem a inclinação do corpo; extra = {osso: [(quadro, x, abre)]}"""
        return {g: bg.plant(body, g, (extra or {}).get(g, ())) for g in legs}

    # ---- idle: respira fundo, olha devagar para os lados, abana o rabo ----
    n = 48
    k = {b_: [] for b_ in ("body", "head", "tail", "leg_fr", "leg_fl")}
    for f in list(range(1, n, 3)) + [n]:
        a = (f - 1) / (n - 1) * tau
        k["body"].append((f, r(1.4 * math.sin(a)), p(0.022 * (0.5 - 0.5 * math.cos(a)))))
        k["head"].append((f, r(3 + 3 * math.sin(a + 0.6), 0, 7 * math.sin(a)), z))
        k["tail"].append((f, r(4, 0, 12 * math.sin(2 * a)), z))
        k["leg_fr"].append((f, r(-1.4 * math.sin(a)), z))
        k["leg_fl"].append((f, r(-1.4 * math.sin(a)), z))
    _clip(arm, "idle", k, n, loop=True)

    # ---- run: galope pesado (pares da frente e de trás opostos), corpo rola e a cabeça compensa ----
    n = 16
    k = {b_: [] for b_ in ("body", "head", "tail") + legs}
    for f in range(1, n + 1):
        a = (f - 1) / (n - 1) * tau
        k["body"].append((f, r(-4.5 * math.cos(a), 0, 3.5 * math.sin(a)), p(0.07 * (0.5 + 0.5 * math.sin(a)))))
        k["head"].append((f, r(3.5 * math.cos(a) + 6, 0, -2 * math.sin(a)), z))
        k["leg_fr"].append((f, r(-32 * math.sin(a) + 4.5 * math.cos(a)), z))
        k["leg_fl"].append((f, r(-32 * math.sin(a - 0.5) + 4.5 * math.cos(a)), z))
        k["leg_br"].append((f, r(28 * math.sin(a + 0.25) + 4.5 * math.cos(a)), z))
        k["leg_bl"].append((f, r(28 * math.sin(a - 0.25) + 4.5 * math.cos(a)), z))
        k["tail"].append((f, r(14 + 10 * math.sin(a - 1.2), 0, 6 * math.sin(a + 0.6)), z))
    _clip(arm, "run", k, n, loop=True)

    # ---- attack (5): abaixa a cabeça e joga a presa grande para cima e para o lado ----
    e = 16
    _clip(arm, "attack", {
        "body": [(1, z, z), (3, r(6), p(-0.03, -0.1)), (5, r(-8), p(0.03, 0.24)), (8, r(-5), p(0.02, 0.18)), (11, r(2), p(0, 0.06)), (e, z, z)],
        "head": [(1, z, z), (3, r(16, 0, 12), z), (5, r(-30, 0, -16), z), (8, r(-18, 0, -8), z), (11, r(-4, 0, 4), z), (e, z, z)],
        "leg_fr": [(1, z, z), (3, r(8), z), (5, r(-20), z), (8, r(-12), z), (12, r(-4), z), (e, z, z)],
        "leg_fl": [(1, z, z), (3, r(6), z), (5, r(-14), z), (8, r(-9), z), (12, r(-2), z), (e, z, z)],
        "leg_br": [(1, z, z), (3, r(-16), z), (5, r(30), z), (8, r(20), z), (12, r(4), z), (e, z, z)],
        "leg_bl": [(1, z, z), (3, r(-16), z), (5, r(26), z), (8, r(16), z), (12, r(2), z), (e, z, z)],
        "tail": [(1, z, z), (3, r(12), z), (5, r(-14), z), (9, r(8, 0, 12), z), (e, z, z)],
    }, e)

    # ---- hit: tranco para trás, cabeça vira, rabo encolhe ----
    body = [(1, z, z), (2, r(-6, 0, 5), p(0.01, -0.08)), (5, r(3, 0, -2), p(0, -0.04)), (7, r(-1), p(0, -0.015)), (10, z, z)]
    k = planted(body, {"leg_fr": [(2, -10), (5, 4)], "leg_fl": [(2, -7), (5, 3)], "leg_br": [(2, 8), (5, -3)], "leg_bl": [(2, 6), (5, -3)]})
    k.update({"body": body, "head": [(1, z, z), (2, r(-20, 0, 16), z), (5, r(8, 0, -8), z), (7, r(-2), z), (10, z, z)],
              "tail": [(1, z, z), (2, r(-24), z), (5, r(-12, 0, 8), z), (10, z, z)]})
    _clip(arm, "hit", k, 10)

    # ---- atk_charge (5): cava, recua de cabeça baixa e dispara rente ao chão com as presas na frente; no fim joga a cabeça ----
    e = 20
    _clip(arm, "atk_charge", {
        "body": [(1, z, z), (3, r(9), p(-0.03, -0.18)), (5, r(7), p(0.0, 0.44)), (8, r(5), p(0.02, 0.48)), (10, r(-10), p(0.04, 0.38)), (13, r(-3), p(0.01, 0.17)),
                 (17, r(1), p(0, 0.03)), (e, z, z)],
        "head": [(1, z, z), (3, r(20), z), (5, r(16), z), (8, r(14), z), (10, r(-30, 0, -14), z), (13, r(-10, 0, 6), z), (17, r(2), z), (e, z, z)],
        "leg_fr": [(1, z, z), (3, r(14), z), (5, r(-50), z), (8, r(-38), z), (10, r(4), z), (13, r(6), z), (e, z, z)],
        "leg_fl": [(1, z, z), (3, r(10), z), (5, r(-42), z), (8, r(-30), z), (10, r(8), z), (13, r(4), z), (e, z, z)],
        "leg_br": [(1, z, z), (3, r(-26), z), (5, r(42), z), (8, r(32), z), (10, r(14), z), (13, r(-2), z), (e, z, z)],
        "leg_bl": [(1, z, z), (3, r(-26), z), (5, r(36), z), (8, r(26), z), (10, r(12), z), (13, r(0), z), (e, z, z)],
        "tail": [(1, z, z), (3, r(22), z), (5, r(-22), z), (8, r(-18, 0, 8), z), (10, r(16, 0, -10), z), (14, r(6), z), (e, z, z)],
    }, e)

    # ---- slam (8): empina nas patas de trás e desaba com os dois cascos da frente; o corpo afunda, quica e assenta ----
    e = 24
    _clip(arm, "slam", {
        "body": [(1, z, z), (3, r(6), p(-0.03)), (5, r(-36), p(0.03, -0.04)), (6, r(-40), p(0.04, -0.05)), (8, r(9), p(-0.02, 0.1)), (10, r(5), p(0.0, 0.08)),
                 (12, r(8), p(-0.02, 0.07)), (15, r(2), p(0, 0.03)), (20, r(-1), z), (e, z, z)],
        "head": [(1, z, z), (3, r(10), z), (5, r(-8), z), (6, r(-4), z), (8, r(20), z), (10, r(12, 0, 5), z), (12, r(12, 0, -5), z), (16, r(3), z), (e, z, z)],
        "leg_fr": [(1, z, z), (3, r(8), z), (5, r(-48), z), (6, r(-56), z), (7, r(-30), z), (8, r(-9), z), (10, r(-5), z), (12, r(-8), z), (15, r(-2), z), (e, z, z)],
        "leg_fl": [(1, z, z), (3, r(8), z), (5, r(-40), z), (6, r(-50), z), (7, r(-26), z), (8, r(-9), z), (10, r(-5), z), (12, r(-8), z), (15, r(-2), z), (e, z, z)],
        "leg_br": [(1, z, z), (3, r(-6), z), (5, r(36), z), (6, r(40), z), (8, r(-9), z), (10, r(-5), z), (12, r(-8), z), (15, r(-2), z), (e, z, z)],
        "leg_bl": [(1, z, z), (3, r(-6), z), (5, r(36), z), (6, r(40), z), (8, r(-9), z), (10, r(-5), z), (12, r(-8), z), (15, r(-2), z), (e, z, z)],
        "tail": [(1, z, z), (4, r(50), z), (5, r(80), z), (6, r(84), z), (8, r(-10), z), (12, r(8, 0, 10), z), (16, r(2, 0, -6), z), (e, z, z)],
    }, e)

    # ---- roar / shout (7): recolhe, crava as patas abertas, joga a cabeça para cima e sacode ----
    e = 24
    body = [(1, z, z), (4, r(7), p(-0.03, -0.04)), (7, r(-11), p(0.02, 0.02)), (9, r(-10, 0, 3), p(0.02, 0.02)), (11, r(-11, 0, -3), p(0.02, 0.02)),
            (13, r(-10, 0, 2), p(0.02, 0.02)), (16, r(-8), p(0.01, 0.01)), (20, r(2), z), (e, z, z)]
    k = planted(body, {"leg_fr": [(4, 0, 4), (7, 0, 12), (16, 0, 12), (20, 0, 3)], "leg_fl": [(4, 0, 4), (7, 0, 12), (16, 0, 12), (20, 0, 3)]})
    k.update({"body": body,
              "head": [(1, z, z), (4, r(20), z), (7, r(-36, 0, 10), z), (9, r(-34, 0, -10), z), (11, r(-36, 0, 10), z), (13, r(-34, 0, -8), z), (16, r(-24), z),
                       (20, r(4), z), (e, z, z)],
              "tail": [(1, z, z), (4, r(-6), z), (7, r(34, 0, 14), z), (9, r(34, 0, -14), z), (11, r(34, 0, 14), z), (13, r(30, 0, -10), z), (17, r(12), z), (e, z, z)]})
    for name in ("roar", "shout"):
        _clip(arm, name, {b_: list(v) for b_, v in k.items()}, e)

    # ---- maul (7): gira o tronco, recolhe a cabeça para um lado e varre com a presa grande cruzando a frente ----
    e = 18
    body = [(1, z, z), (3, r(4, -12), p(-0.02, -0.05)), (5, r(6, -20), p(-0.02, -0.08)), (7, r(-5, 18), p(0.02, 0.16)), (9, r(-4, 22), p(0.02, 0.14)),
            (12, r(0, 8), p(0, 0.05)), (e, z, z)]
    k = planted(body, {"leg_fr": [(5, 10), (7, -14), (9, -10), (12, -3)], "leg_fl": [(5, -6), (7, -8), (9, -6)], "leg_br": [(5, -8), (7, 12), (9, 8)],
                       "leg_bl": [(5, -8), (7, 10), (9, 6)]})
    k.update({"body": body,
              "head": [(1, z, z), (3, r(10, 0, -16), z), (5, r(16, 0, -28), z), (7, r(-18, 0, 30), z), (9, r(-12, 0, 34), z), (12, r(-2, 0, 10), z), (e, z, z)],
              "tail": [(1, z, z), (5, r(10, 0, -18), z), (7, r(-8, 0, 22), z), (11, r(6, 0, -8), z), (e, z, z)]})
    _clip(arm, "maul", k, e)

    # ---- pounce (9): agacha, salta para a frente e cai nos cascos da frente ----
    e = 20
    _clip(arm, "pounce", {
        "body": [(1, z, z), (3, r(5), p(-0.04, -0.06)), (5, r(8), p(-0.07, -0.12)), (7, r(-16), p(0.32, 0.26)), (8, r(-4), p(0.3, 0.4)), (9, r(10), p(0.0, 0.46)),
                 (11, r(7), p(-0.03, 0.38)), (13, r(4), p(-0.02, 0.24)), (17, r(-1), p(0, 0.05)), (e, z, z)],
        "head": [(1, z, z), (5, r(12), z), (7, r(-14), z), (9, r(20), z), (11, r(12), z), (14, r(4), z), (e, z, z)],
        "leg_fr": [(1, z, z), (5, r(18), z), (7, r(-58), z), (8, r(-40), z), (9, r(-10), z), (11, r(-7), z), (13, r(-4), z), (e, z, z)],
        "leg_fl": [(1, z, z), (5, r(18), z), (7, r(-50), z), (8, r(-34), z), (9, r(-10), z), (11, r(-7), z), (13, r(-4), z), (e, z, z)],
        "leg_br": [(1, z, z), (5, r(-30), z), (7, r(50), z), (8, r(40), z), (9, r(-10), z), (11, r(-7), z), (13, r(-4), z), (e, z, z)],
        "leg_bl": [(1, z, z), (5, r(-30), z), (7, r(44), z), (8, r(36), z), (9, r(-10), z), (11, r(-7), z), (13, r(-4), z), (e, z, z)],
        "tail": [(1, z, z), (5, r(-12), z), (7, r(26), z), (9, r(-16), z), (13, r(6, 0, 8), z), (e, z, z)],
    }, e)

    # ---- brace (6): crava as patas abertas, abaixa o corpo e a cabeça entre os ombros, respira pesado ----
    e = 18
    body = [(1, z, z), (3, r(-3), p(0.02)), (6, r(6), p(-0.1, 0.04)), (9, r(5), p(-0.085, 0.04)), (12, r(6), p(-0.1, 0.04)), (15, r(2), p(-0.02, 0.01)), (e, z, z)]
    spread = [(6, 0, 12), (12, 0, 12)]
    k = planted(body, {g: spread for g in legs})
    k.update({"body": body, "head": [(1, z, z), (3, r(-8), z), (6, r(18), z), (9, r(15), z), (12, r(18), z), (15, r(4), z), (e, z, z)],
              "tail": [(1, z, z), (6, r(-18), z), (12, r(-16), z), (e, z, z)]})
    _clip(arm, "brace", k, e)

    # ---- die: empina com o golpe, os joelhos da frente cedem, tomba de lado (a presa grande e o musgo ficam para cima) e quica ----
    s = 1.4
    f = lambda x: int(round(1 + (x - 1) * s))
    e = f(24)
    roll = -84
    _clip(arm, "die", {
        "body": [(1, z, z), (f(4), r(-10), p(0.02, -0.05)), (f(9), r(9), p(-0.06, 0.02)), (f(14), r(3), p(-0.02)), (e, r(3), p(-0.02))],
        "head": [(1, z, z), (f(4), r(-30, 0, 8), z), (f(9), r(20), z), (f(14), r(6, 0, 14), z), (f(17), r(-4, 0, 8), z), (f(20), r(6, 0, 14), z), (e, r(6, 0, 14), z)],
        "leg_fr": [(1, z, z), (f(4), r(-16), z), (f(9), r(30), z), (f(14), r(-20), z), (f(17), r(-28), z), (e, r(-20), z)],
        "leg_fl": [(1, z, z), (f(4), r(-12), z), (f(9), r(26), z), (f(14), r(-10), z), (f(17), r(-16), z), (e, r(-10), z)],
        "leg_br": [(1, z, z), (f(4), r(8), z), (f(9), r(-16), z), (f(14), r(16), z), (f(17), r(24), z), (e, r(16), z)],
        "leg_bl": [(1, z, z), (f(4), r(8), z), (f(9), r(-16), z), (f(14), r(26), z), (f(17), r(32), z), (e, r(26), z)],
        "tail": [(1, z, z), (f(4), r(-22), z), (f(9), r(-28), z), (f(14), r(6, 0, 10), z), (f(17), r(10, 0, 18), z), (e, r(4, 0, 12), z)],
        "root": [(1, z, z), (f(9), z, z), (f(14), r(0, 0, roll), z), (f(17), r(0, 0, roll + 7), z), (f(20), r(0, 0, roll), z), (e, r(0, 0, roll), z)],
    }, e)


# ---------------------------------------------------------------------------
# chão
# ---------------------------------------------------------------------------
def _ground(arm, clips, legs, tuck, sink=0.0, head=True, report=True):
    """Nada abaixo do chão, quadro a quadro, sem mexer em duração nem impacto. 1) cada pata de `legs` que passaria do chão
    recolhe na vertical para dentro do corpo (até `tuck`); 2) cabeça (presas, barbicha) que passaria do chão ergue o focinho de
    1,5° em 1,5°; 3) o que ainda sobrar abaixo de -sink sobe a raiz (loc Y = cima,
    vale mesmo com a raiz tombada no `die`). Grava uma chave por quadro nesses canais."""
    import numpy as np
    ad = arm.animation_data
    sc = bpy.context.scene
    meshes = {o.parent_bone: o for o in arm.children if o.type == "MESH"}
    co = {}
    for bone, o in meshes.items():
        a = np.empty(len(o.data.vertices) * 3, dtype=np.float64)
        o.data.vertices.foreach_get("co", a)
        co[bone] = np.concatenate([a.reshape(-1, 3), np.ones((len(o.data.vertices), 1))], axis=1)

    def low(bone):
        mw = np.array(meshes[bone].matrix_world)
        return float((co[bone] @ mw[2]).min())

    tracks = {t.name: t for t in ad.nla_tracks}
    for t in ad.nla_tracks:
        t.mute = True
    root = arm.pose.bones["root"]
    for name in clips:
        act = tracks[name].strips[0].action
        ad.action = act
        if getattr(ad, "action_slot", None) is None and getattr(act, "slots", None):
            ad.action_slot = act.slots[0]
        worst_leg, worst_root, worst_head = 0.0, 0.0, 0.0
        for f in range(1, int(round(act.frame_range[1])) + 1):
            sc.frame_set(f)
            bpy.context.view_layer.update()
            for g in legs:
                pb = arm.pose.bones[g]
                d = min(max(0.0, -low(g)), tuck)
                if d > 0.0:
                    par = pb.parent
                    mrot = arm.matrix_world.to_3x3() @ par.matrix.to_3x3() @ par.bone.matrix_local.to_3x3().inverted() @ pb.bone.matrix_local.to_3x3()
                    pb.location = pb.location + mrot.inverted() @ V((0, 0, d))
                    worst_leg = max(worst_leg, d)
                pb.keyframe_insert("location", frame=f)
            bpy.context.view_layer.update()
            if head:
                hb = arm.pose.bones["head"]
                for _i in range(40):
                    if low("head") >= 0.0:
                        break
                    hb.rotation_euler.x -= math.radians(1.5)
                    bpy.context.view_layer.update()
                    worst_head = max(worst_head, 1.5 * (_i + 1))
                hb.keyframe_insert("rotation_euler", frame=f)
            d = max(0.0, -min(low(b_) for b_ in meshes) - sink)
            root.location.y += d
            worst_root = max(worst_root, d)
            root.keyframe_insert("location", frame=f)
        if report:
            print("GROUNDFIX %-11s pata recolhe até %.3f, cabeça ergue até %.1f°, raiz sobe até %.3f" % (name, worst_leg, worst_head, worst_root))
        ad.action = None
    for t in ad.nla_tracks:
        t.mute = False
    for b_ in arm.pose.bones:
        b_.rotation_euler = (0, 0, 0)
        b_.location = (0, 0, 0)
    sc.frame_set(1)


BUILDERS = {
    "mob_ancestral_boar": ancestral_boar,
}
HUMANOIDS = set()                   # todos de peças rígidas (lp.export_glb)
