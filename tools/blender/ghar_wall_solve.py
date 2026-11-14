"""Busca das poses da Muralha de Escudos do Ghar (act2_bosses.GHAR_SOLVED): braço do escudo, braço do machado e pernas de
cada chave de guard_wall / wall_counter, por FK no rig (o escudo é rígido no forearm.L; os pés ficam em GHAR_FEET).

    blender -b --factory-startup --python tools/blender/ghar_wall_solve.py -- solve     (imprime GHAR_SOLVED para colar)
    blender -b --factory-startup --python tools/blender/ghar_wall_solve.py --           (só o relatório das chaves atuais)

Mudou tronco/quadril de uma chave (GHAR_TORSO, ghar_counter_keys) ou um alvo em T: rode com `solve` e cole o resultado.
O braço do escudo tem duas famílias de solução (FAM_A na guarda, FAM_B do giro em diante); cada chave parte da vizinha
(L_ORDER) para o braço não trocar de família no meio de uma interpolação.
"""
import math
import os
import random
import sys
import tempfile

import bpy
from mathutils import Matrix, Vector, Euler

sys.path.append(os.path.dirname(os.path.abspath(__file__)))
import act2_bosses as ab
import chibi_kit as ck
import mob_kit

mob_kit.build_all(tempfile.mkdtemp(prefix="ghar_wall_"), only=["mob_ghar"])
rig = next(o for o in bpy.context.scene.objects if o.type == "ARMATURE")
B = rig.data.bones
REST = {b.name: b.matrix_local.copy() for b in B}
RINV = {k: m.inverted() for k, m in REST.items()}
PAR = {b.name: (b.parent.name if b.parent else None) for b in B}
ORDER = [b.name for b in B]


def fk(pose, hips):
    M = {}
    for n in ORDER:
        r = pose.get(n, (0, 0, 0))
        L = Euler([math.radians(a) for a in r], "XYZ").to_matrix().to_4x4()
        if n == "hips":
            L = Matrix.Translation(hips) @ L
        p = PAR[n]
        M[n] = (REST[n] @ L) if p is None else (M[p] @ RINV[p] @ REST[n] @ L)
    return M


wrist, elbow = B["forearm.L"].tail_local.copy(), B["forearm.L"].head_local.copy()
s_up = (elbow - wrist).normalized()
f0 = Vector((0.55, -0.83, 0.0))
s_face = (f0 - s_up * f0.dot(s_up)).normalized()
s_c = wrist.lerp(elbow, 0.3) + s_face * (0.066 + 0.085)
print("REST shield c", s_c, "face", s_face, "up", s_up)


def shield(M):
    D = M["forearm.L"] @ RINV["forearm.L"]
    R3 = D.to_3x3()
    return D @ s_c, R3 @ s_face, R3 @ s_up


def arm_cost(pose, hips, tc, tface, tup, verbose=False):
    c, f, u = shield(fk(pose, hips))
    tip = c - u * 0.54
    cost = 3 * (1 - f.dot(tface)) + 3 * (1 - u.dot(tup)) + 25 * (c.x - tc[0]) ** 2 + 12 * (c.y - tc[1]) ** 2 + 40 * (tip.z - tc[2]) ** 2
    if verbose:
        print("   shield c=(%.3f %.3f %.3f) face=(%.2f %.2f %.2f) up=(%.2f %.2f %.2f) tipz=%.3f top=%.3f" % (*c, *f, *u, tip.z, (c + u * 0.6).z))
    return cost


def foot_pts(M, side):
    D = M["foot." + side] @ RINV["foot." + side]
    return D @ B["foot." + side].head_local, D @ B["foot." + side].tail_local


def flat_foot(pose, hips, side):
    best = None
    for fx in range(-90, 61, 2):
        p = dict(pose)
        p["foot." + side] = (fx, 0, 0)
        h, t = foot_pts(fk(p, hips), side)
        e = abs((h.z - t.z) - 0.04)
        if best is None or e < best[0]:
            best = (e, fx, h, t)
    return best


def solve_leg(pose, hips, side, target):
    tgt = Vector((target[0], target[1], 0.07))

    def ev(v):
        p = dict(pose)
        p["thigh." + side] = (v[0], 0, v[1])
        p["shin." + side] = (v[2], 0, 0)
        a, _t = foot_pts(fk(p, hips), side)
        return (a - tgt).length_squared + (1e-6 * v[2] if v[2] >= 0 else 1.0)
    best = None
    for tx in range(-100, 61, 10):
        for tz in range(-50, 51, 10):
            for sx in range(0, 131, 10):
                c = ev((tx, tz, sx))
                if best is None or c < best[0]:
                    best = (c, [tx, tz, sx])
    c, v = best
    step = 5.0
    while step > 0.2:
        imp = False
        for i in range(3):
            for d in (-step, step):
                w = list(v)
                w[i] += d
                cw = ev(w)
                if cw < c - 1e-9:
                    v, c, imp = w, cw, True
        if not imp:
            step *= 0.5
    p = dict(pose)
    p["thigh." + side] = (round(v[0], 1), 0, round(v[1], 1))
    p["shin." + side] = (round(v[2], 1), 0, 0)
    e, fx, h, t = flat_foot(p, hips, side)
    return {"thigh." + side: p["thigh." + side], "shin." + side: p["shin." + side], "foot." + side: (fx, 0, 0)}, math.sqrt(c), h, t


mode = sys.argv[sys.argv.index("--") + 1:]
axe_up = Vector((0, -0.25, 1)).normalized()
axe_fw = Vector((0, -1, 0))
axe_fw = (axe_fw - axe_up * axe_fw.dot(axe_up)).normalized()
gr = (B["hand.R"].head_local + B["hand.R"].tail_local) / 2


def axe(M):
    D = M["hand.R"] @ RINV["hand.R"]
    R3 = D.to_3x3()
    return D @ gr, R3 @ axe_up, R3 @ axe_fw


def climb(ev, v, step=10.0, lo=0.4):
    v = list(v)
    c = ev(v)
    while step > lo:
        imp = False
        for i in range(len(v)):
            for d in (-step, step):
                w = list(v)
                w[i] += d
                cw = ev(w)
                if cw < c - 1e-7:
                    v, c, imp = w, cw, True
        if not imp:
            step *= 0.5
    return c, v


def seeded_left(body, hips, tc, tface, tup, seed):
    def ev(v):
        p = dict(body)
        p["upper_arm.L"] = (v[0], v[1], v[2])
        p["forearm.L"] = ck._rolled((v[3], 0, 0), v[4])
        return arm_cost(p, hips, tc, tface, tup)
    c, v = climb(ev, seed)
    return c, [round(x, 1) for x in v]


def seeded_right(body, hips, tpos, tdir, tfw, seed):
    tpos, tdir, tfw = Vector(tpos), Vector(tdir).normalized(), Vector(tfw).normalized()

    def ev(v):
        p = dict(body)
        p["upper_arm.R"] = tuple(v[0:3])
        p["forearm.R"] = (v[3], 0, 0)
        p["hand.R"] = tuple(v[4:7])
        g, u, f = axe(fk(p, hips))
        return (30 * (g - tpos).length_squared + 2 * (1 - u.dot(tdir)) + 0.6 * (1 - f.dot(tfw)) + (0 if -120 <= v[3] <= -10 else 1)
                + 1e-6 * (v[0] ** 2 + v[1] ** 2 + v[2] ** 2) + 4e-6 * (v[3] + 55) ** 2)
    c, v = climb(ev, seed, 10.0, 0.5)
    return c, [round(x) for x in v]


FAM_A = [-71.9, -25.0, 13.1, 70.6, 18.1]       # guarda: braço à frente, antebraço para baixo (escudo de pé na frente do corpo)
FAM_B = [-12.0, 0.0, -14.0, -40.0, 0.0]        # braço natural (o da guarda do kit): do giro em diante
# alvos por chave: escudo (centro x, y, z da ponta de baixo), face, cima | mao direita, direcao do cabo, fio da lamina
T = {
    "guard": (((0.1, -0.5, 0.025), (0, -1, 0.05), (0, -0.04, 1)), ((-0.42, -0.12, 0.8), (-0.35, 0.2, 0.92), (0, -1, 0))),
    "coil": (((0.1, -0.38, 0.035), (0, -1, 0.1), (0, 0.1, 1)), ((-0.5, 0.02, 0.98), (-0.5, 0.42, 0.76), (0, -0.85, 0.5))),
    "bash": (((0.06, -0.74, 0.13), (0, -1, -0.12), (0, -0.16, 1)), ((-0.54, 0.0, 1.02), (-0.45, 0.38, 0.8), (0, -0.9, 0.4))),
    "swing1": (((0.28, -0.52, 0.12), (0.3, -0.95, -0.05), (0.15, -0.05, 1)), ((-0.5, -0.08, 1.0), (-0.45, 0.1, 0.89), (0, -0.99, 0.1))),
    "swing2": (((0.4, -0.5, 0.1), (0.4, -0.9, -0.08), (0.2, 0.0, 0.97)), ((-0.38, -0.32, 0.92), (-0.15, -0.7, 0.7), (0, -0.7, -0.7))),
    "chop": (((0.52, -0.46, 0.07), (0.5, -0.86, -0.12), (0.3, 0.05, 0.95)), ((-0.1, -0.4, 0.62), (0.05, -0.95, -0.3), (0, 0.3, -0.95))),
    "follow": (((0.53, -0.45, 0.065), (0.52, -0.85, -0.12), (0.32, 0.05, 0.94)), ((-0.09, -0.4, 0.615), (0.06, -0.95, -0.31), (0, 0.31, -0.95))),
    "lift": (((0.52, -0.4, 0.12), (0.5, -0.85, 0.1), (0.25, 0.2, 0.94)), ((-0.2, -0.38, 0.62), (0, -0.9, 0.4), (0, -0.4, -0.9))),
    "recover": (((0.46, -0.2, 0.26), (0.4, -0.7, 0.5), (-0.03, 0.5, 0.85)), ((-0.27, -0.3, 0.56), (-0.08, -0.6, 0.8), (0.3, -0.75, -0.55))),
}
# ordem de solução do braço do escudo: (chave, semente = família ou outra chave já resolvida)
L_ORDER = [("guard", FAM_A), ("coil", "guard"), ("bash", "coil"), ("chop", FAM_B), ("swing2", "chop"), ("swing1", "swing2"),
           ("follow", "chop"), ("lift", "follow"), ("recover", "lift")]
KEYS = {n: (f, dict(pose), hips) for f, n, pose, hips in ab.ghar_counter_keys()}
solved = {n: {} for n in KEYS if n in T}
if "solve" in mode:
    vL = {}
    for n, seed in L_ORDER:
        f, pose, hips = KEYS[n]
        tc, tface, tup = T[n][0]
        c, v = seeded_left(pose, hips, tc, Vector(tface).normalized(), Vector(tup).normalized(), vL[seed] if isinstance(seed, str) else seed)
        vL[n] = v
        solved[n].update({"upper_arm.L": tuple(v[:3]), "forearm.L": tuple(round(x, 1) for x in ck._rolled((v[3], 0, 0), v[4]))})
        print("LARM %s cost %.4f fore=%.1f roll=%.1f" % (n, c, v[3], v[4]))
    prevR = [-85, 26, 28, -11, 53, 51, -39]      # machado erguido ao lado da cabeça (achado por busca aleatória)
    for n in [k for k in KEYS if k in T]:
        f, pose, hips = KEYS[n]
        tp, td, tf = T[n][1]
        c, v = seeded_right(pose, hips, tp, td, tf, prevR)
        prevR = v
        solved[n].update({"upper_arm.R": tuple(v[:3]), "forearm.R": (v[3], 0, 0), "hand.R": tuple(v[4:7])})
        print("RARM %s cost %.4f" % (n, c))
        pose.update(solved[n])
        for side in ("L", "R"):
            d, err, h, t = solve_leg(pose, hips, side, ab.GHAR_FEET[side])
            solved[n].update(d)
            if err > 0.012:
                print("  leg", n, side, "err %.3f" % err)
for n, (f, pose, hips) in KEYS.items():
    pose = dict(pose, **solved.get(n, {}))
    M = fk(pose, hips)
    c, fa, u = shield(M)
    hc = (M["head"] @ RINV["head"]) @ Vector((0, 0, 1.31))
    g, au, af = axe(M)
    ah = g + au * 0.66
    print("KEY %2d %-8s shield c=(%.2f %.2f %.2f) face=(%.2f %.2f %.2f) up=(%.2f %.2f %.2f) tipz=%.2f | head=(%.2f %.2f %.2f)" % (f, n, *c, *fa, *u, (c - u * 0.54).z, *hc))
    print("      axe hand=(%.2f %.2f %.2f) head=(%.2f %.2f %.2f) dir=(%.2f %.2f %.2f) fio=(%.2f %.2f %.2f) edge_z=%.2f" % (*g, *ah, *au, *af, (ah + af * 0.44).z))
if "solve" in mode:
    print("GHAR_SOLVED = {")
    for n, d in solved.items():
        print("    \"%s\": {%s}," % (n, ", ".join("\"%s\": %s" % (k, tuple(int(x) if float(x).is_integer() else x for x in v)) for k, v in d.items())))
    print("}")
