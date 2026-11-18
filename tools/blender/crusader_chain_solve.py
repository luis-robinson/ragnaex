"""Poses da sequência de duas mãos do Golpe do Cruzado (clipes atk_2h_chain_a/b/c do kit do Paladino).

    blender -b --factory-startup --python tools/blender/crusader_chain_solve.py           (resolve e grava crusader_chain_data.py)
    blender -b --factory-startup --python tools/blender/crusader_chain_solve.py -- --dry  (só o relatório, não grava)

O desenho de cada chave fica AQUI (CLIPS): tronco/quadril à mão, e alvos para o resto, resolvidos por FK no rig do kit:
  mão direita no punho (ponto dado no espaço do peito: o giro do tronco leva a arma junto), lâmina apontando `dir` (mundo),
  mão esquerda no mesmo cabo (GRIP_L abaixo da direita), pés plantados nos alvos do chão.
O resultado (pose inteira por chave, por sexo: a largura do ombro muda) vai para crusader_chain_data.py, lido por
chibi_kit.animate_crusader. Mudou uma chave ou um alvo: rode de novo e refaça os kits do Paladino.

Tempo (não muda a sim): cada clipe entra com o preparo que EntityView._strike_step dá (0,16 s / 0,21 s / 0,24 s), então os
impactos ficam nos quadros 5 / 6 / 7 (chibi_kit.IMPACT = EntityView.IMPACT_FRAME) e os clipes tocam perto de 1x.
O clipe b começa na pose em que o a está quando ele entra (acompanhamento do corte), e o c na do b.
"""
import math
import os
import sys

import bpy
from mathutils import Matrix, Vector, Euler

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.append(HERE)
import chibi_kit as ck

ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
GRIP_L = 0.12            # mão esquerda: metros abaixo da direita no cabo (lado do pomo)
REACH = 1.2              # ponta da arma mais comprida (montante 1,18 / malho 1,2) a partir da mão
HEAD_C = Vector((0, 0, 1.32))
HEAD_R = 0.40            # a lâmina e as mãos passam por fora da cabeça


def az(phi, el=0.0):
    """Direção da lâmina: phi = azimute em graus (0 = frente, + = direita do personagem), el = elevação."""
    p, e = math.radians(phi), math.radians(el)
    return Vector((-math.sin(p) * math.cos(e), -math.cos(p) * math.cos(e), math.sin(e)))


def body(yaw=0.0, pitch=6.0, hips_yaw=0.0, head=(-4, 0, 0), chest_pitch=0.0):
    """Tronco: yaw somado de spine+chest (+ = peito para a ESQUERDA), 70% na coluna."""
    return {"hips": (0, hips_yaw, 0), "spine": (pitch, yaw * 0.7, 0), "chest": (chest_pitch, yaw * 0.3, 0), "head": head}


# pés (x, y, altura do tornozelo): guarda de duas mãos, base mais aberta que a do kit
FR, FL = (-0.13, -0.07, 0.07), (0.13, 0.09, 0.07)
FEET = (FR, FL)
STEP_AIR = ((-0.12, -0.2, 0.12), FL)            # pé direito no ar, entrando
STEP_IN = ((-0.11, -0.34, 0.07), (0.13, 0.03, 0.09))      # passo à frente do 3º golpe; o pé de trás vem junto, calcanhar no ar
G_HAND, G_DIR = (-0.03, -0.25, 0.63), az(14, 55)          # guarda: arma na frente, ponta para cima
GUARD = (body(), (0, -0.025, 0), G_HAND, G_DIR, FEET)
# acompanhamento do corte (a) = começo do revés (b); acompanhamento do revés (b) = começo do golpe de cima (c)
A_FOLLOW = (body(40, 10, 12), (0, -0.04, 0.05), (0.03, -0.25, 0.72), az(-104, 4), FEET)
B_FOLLOW = (body(-40, 10, -12), (0, -0.04, 0.06), (-0.2, -0.17, 0.72), az(108, 2), FEET)
CRASH = (body(4, 22, 4, chest_pitch=6), (0, -0.15, 0.2), (-0.03, -0.27, 0.66), az(2, -16), STEP_IN)
# clipe -> (quadro final, [(quadro, tronco, quadril (x, cima, frente), mão no espaço do peito, direção da lâmina, pés)])
CLIPS = {
    # corte largo da direita para a esquerda
    "atk_2h_chain_a": (14, [
        (1, *GUARD),
        (3, body(-40, 4, -12), (0, -0.03, -0.04), (-0.2, -0.17, 0.74), az(122, 14), FEET),
        (4, body(-14, 8, -4), (0, -0.04, 0.01), (-0.15, -0.24, 0.72), az(64, 6), FEET),
        (5, body(18, 12, 6), (0, -0.05, 0.06), (-0.04, -0.28, 0.71), az(4, 0), FEET),
        (6, body(34, 11, 10), (0, -0.05, 0.06), (0.01, -0.27, 0.71), az(-58, 2), FEET),
        (7, *A_FOLLOW),
        (9, body(40, 9, 12), (0, -0.04, 0.04), (0.03, -0.24, 0.72), az(-112, 6), FEET),
        (14, *GUARD),
    ]),
    # revés da esquerda para a direita
    "atk_2h_chain_b": (15, [
        (1, *A_FOLLOW),
        (3, body(40, 5, 14), (0, -0.03, 0.0), (0.03, -0.23, 0.77), az(-126, 18), FEET),
        (5, body(16, 9, 5), (0, -0.04, 0.04), (0.01, -0.27, 0.73), az(-62, 6), FEET),
        (6, body(-14, 12, -5), (0, -0.05, 0.08), (-0.05, -0.28, 0.7), az(-2, -3), FEET),
        (7, body(-32, 11, -10), (0, -0.05, 0.08), (-0.13, -0.24, 0.71), az(60, 0), FEET),
        (8, *B_FOLLOW),
        (10, body(-40, 9, -12), (0, -0.04, 0.05), (-0.21, -0.16, 0.73), az(116, 5), FEET),
        (15, *GUARD),
    ]),
    # golpe de cima: sobe a arma pelo lado direito, passo à frente e desce com o corpo todo (o crítico)
    "atk_2h_chain_c": (19, [
        (1, *B_FOLLOW),
        (3, body(-26, -2, -8), (0, 0.0, 0.0), (-0.14, -0.22, 0.9), az(140, 58), FEET),
        (5, body(-10, -14, -3, head=(-8, 0, 0)), (0, 0.015, -0.03), (-0.08, -0.25, 1.03), Vector((-0.12, 0.42, 0.9)).normalized(), STEP_AIR),
        # 6: a arma ainda no alto (peso suspenso) com o pé já entrando; desce inteira do 6 para o 7 (o trecho mais rápido = de cima)
        (6, body(-4, -6, -1, head=(-6, 0, 0)), (0, 0.0, 0.05), (-0.07, -0.27, 1.02), Vector((-0.06, -0.12, 0.99)).normalized(), ((-0.11, -0.3, 0.1), FL)),
        (7, *CRASH),
        (8, body(4, 26, 4, chest_pitch=6), (0, -0.18, 0.21), (-0.03, -0.27, 0.65), az(2, -20), STEP_IN),
        (11, body(4, 23, 4, chest_pitch=6), (0, -0.16, 0.2), (-0.03, -0.27, 0.66), az(2, -16), STEP_IN),
        (15, body(2, 12, 2), (0, -0.07, 0.08), (-0.05, -0.26, 0.63), az(14, 22), ((-0.12, -0.18, 0.07), FL)),
        (19, *GUARD),
    ]),
}
SEED_R = [-55, 20, -20, -70, 40, 60, -40]
SEED_L = [-60, -30, 30, -70]


def setup(sex):
    ck.clear()
    base = ck.build_base("base", sex, 0.0, ck.KIT_HAIR, "hair")
    B = base["rig"].data.bones
    S = {"B": B, "REST": {b.name: b.matrix_local.copy() for b in B}, "PAR": {b.name: (b.parent.name if b.parent else None) for b in B},
         "ORDER": [b.name for b in B], "gr": ck.hand_center(base, ".R"), "gl": ck.hand_center(base, ".L")}
    S["RINV"] = {k: m.inverted() for k, m in S["REST"].items()}
    return S


def fk(S, pose, hips, only=None):
    M = {}
    REST, RINV, PAR = S["REST"], S["RINV"], S["PAR"]
    for n in S["ORDER"]:
        if only and n not in only:
            continue
        r = pose.get(n, (0, 0, 0))
        L = Euler([math.radians(a) for a in r], "XYZ").to_matrix().to_4x4()
        if n == "hips":
            L = Matrix.Translation(hips) @ L
        p = PAR[n]
        M[n] = (REST[n] @ L) if p is None else (M[p] @ RINV[p] @ REST[n] @ L)
    return M


TRUNK = ("root", "hips", "spine", "chest", "neck", "head")
CH_R = TRUNK + ("upper_arm.R", "forearm.R", "hand.R")
CH_L = TRUNK + ("upper_arm.L", "forearm.L", "hand.L")
FWD = Vector((0, -0.55, 0.83)).normalized()        # eixo da arma na pose de descanso (kit_weapon)
SIDE = Vector((1, 0, 0))                           # faces do malho


def climb(ev, v, step=16.0, lo=0.4):
    v = list(v)
    c = ev(v)
    while step > lo:
        imp = False
        for i in range(len(v)):
            for d in (-step, step):
                w = list(v)
                w[i] += d
                cw = ev(w)
                if cw < c - 1e-8:
                    v, c, imp = w, cw, True
        if not imp:
            step *= 0.5
    return c, v


def seg_dist(a, b, p):
    ab = b - a
    t = max(0.0, min(1.0, (p - a).dot(ab) / ab.length_squared))
    return (a + ab * t - p).length


def weapon(S, M):
    D = M["hand.R"] @ S["RINV"]["hand.R"]
    R3 = D.to_3x3()
    return D @ S["gr"], R3 @ FWD, R3 @ SIDE


def solve_key(S, key, seed_r, seed_l, tangent):
    frame, bd, hips, hand_c, tdir, feet = key
    pose = ck._tame(dict(bd), ck.READY)
    pose = {k: v for k, v in pose.items()}
    for k in ("thigh.R", "shin.R", "foot.R", "thigh.L", "shin.L", "foot.L"):
        pose[k] = (0, 0, 0)
    M0 = fk(S, pose, hips, TRUNK)
    tpos = (M0["chest"] @ S["RINV"]["chest"]) @ Vector(hand_c)
    head_c = (M0["head"] @ S["RINV"]["head"]) @ HEAD_C
    tdir = Vector(tdir).normalized()

    def ev_r(v):
        p = dict(pose)
        p["upper_arm.R"], p["forearm.R"], p["hand.R"] = tuple(v[0:3]), (v[3], 0, 0), tuple(v[4:7])
        g, u, s = weapon(S, fk(S, p, hips, CH_R))
        c = 40 * (g - tpos).length_squared + 2.5 * (1 - u.dot(tdir)) + (0 if -125 <= v[3] <= -8 else 1)
        if tangent is not None:
            c += 0.15 * (1 - abs(s.dot(tangent)))
        c += 6 * max(0.0, HEAD_R - seg_dist(g, g + u * REACH, head_c)) ** 2
        return c + 6e-6 * sum((a - b) ** 2 for a, b in zip(v, seed_r))
    cr, vr = climb(ev_r, seed_r)
    vr = [round(x, 1) for x in vr]
    pose["upper_arm.R"], pose["forearm.R"], pose["hand.R"] = tuple(vr[0:3]), (vr[3], 0, 0), tuple(vr[4:7])
    g, u, s = weapon(S, fk(S, pose, hips, CH_R))
    tl = g - u * GRIP_L

    def ev_l(v):
        p = dict(pose)
        p["upper_arm.L"], p["forearm.L"] = tuple(v[0:3]), (v[3], 0, 0)
        ML = fk(S, p, hips, CH_L)
        hl = (ML["hand.L"] @ S["RINV"]["hand.L"]) @ S["gl"]
        return 40 * (hl - tl).length_squared + (0 if -125 <= v[3] <= -8 else 1) + 3e-6 * sum((a - b) ** 2 for a, b in zip(v, seed_l))
    cl, vl = climb(ev_l, seed_l)
    vl = [round(x, 1) for x in vl]
    pose["upper_arm.L"], pose["forearm.L"] = tuple(vl[0:3]), (vl[3], 0, 0)
    ML = fk(S, pose, hips, CH_L)
    hl = (ML["hand.L"] @ S["RINV"]["hand.L"]) @ S["gl"]
    # mão esquerda: palma virada como a direita (só aparência; a arma é da direita)
    pose["hand.L"] = (pose["hand.R"][0], -pose["hand.R"][1], -pose["hand.R"][2])
    foot_err = []
    for side, tgt in (("R", feet[0]), ("L", feet[1])):
        tv = Vector(tgt)
        B = S["B"]

        def ev_leg(v):
            p = dict(pose)
            p["thigh." + side], p["shin." + side] = (v[0], 0, v[1]), (v[2], 0, 0)
            Mg = fk(S, p, hips, ("root", "hips", "thigh." + side, "shin." + side, "foot." + side))
            a = (Mg["foot." + side] @ S["RINV"]["foot." + side]) @ B["foot." + side].head_local
            return (a - tv).length_squared + (0 if v[2] >= 0 else 1.0) + 1e-7 * v[2]
        best = None
        for tx in range(-100, 61, 20):
            for tz in range(-40, 41, 20):
                for sx in range(0, 131, 26):
                    c = ev_leg((tx, tz, sx))
                    if best is None or c < best[0]:
                        best = (c, [tx, tz, sx])
        c, v = climb(ev_leg, best[1], 10.0, 0.2)
        pose["thigh." + side], pose["shin." + side] = (round(v[0], 1), 0, round(v[1], 1)), (round(v[2], 1), 0, 0)
        # pé chato no chão (no ar: ponta um pouco para baixo)
        bestf = None
        for fx in range(-90, 61, 2):
            p = dict(pose)
            p["foot." + side] = (fx, 0, 0)
            Mg = fk(S, p, hips, ("root", "hips", "thigh." + side, "shin." + side, "foot." + side))
            D = Mg["foot." + side] @ S["RINV"]["foot." + side]
            h, t = D @ B["foot." + side].head_local, D @ B["foot." + side].tail_local
            e = abs((h.z - t.z) - (0.04 if tgt[2] <= 0.075 else 0.07))
            if bestf is None or e < bestf[0]:
                bestf = (e, fx)
        pose["foot." + side] = (bestf[1], 0, 0)
        foot_err.append(math.sqrt(max(c, 0.0)))
    info = {"r_pos": (g - tpos).length, "r_dir": math.degrees(math.acos(max(-1, min(1, u.dot(tdir))))), "l_grip": (hl - tl).length,
            "tip_z": (g + u * REACH).z, "hand": g, "dir": u, "head_gap": seg_dist(g, g + u * REACH, head_c), "feet": foot_err}
    return pose, vr, vl, info


def tangents(keys):
    """Direção em que a ponta anda em cada chave (para a face do malho ir na frente)."""
    out = []
    for i, k in enumerate(keys):
        a = Vector(keys[max(0, i - 1)][4])
        b = Vector(keys[min(len(keys) - 1, i + 1)][4])
        d = b - a
        out.append(d.normalized() if d.length > 0.2 else None)
    return out


def run():
    data = {}
    worst = 0.0
    for sex in ("male", "female"):
        S = setup(sex)
        data[sex] = {}
        # a guarda resolvida primeiro e usada como semente (braços sempre na mesma família). Chave repetida (a guarda no
        # começo/fim, o acompanhamento de um clipe = o começo do seguinte) reusa a MESMA solução: sem emenda entre clipes
        done = {}
        gkey = tuple(id(x) for x in GUARD)
        done[gkey] = solve_key(S, (0, *GUARD), SEED_R, SEED_L, None)
        for clip, (end, keys) in CLIPS.items():
            sr, sl = done[gkey][1], done[gkey][2]
            out = []
            tg = tangents(keys)
            prev_q = None
            for i, key in enumerate(keys):
                kid = tuple(id(x) for x in key[1:])
                if kid not in done:
                    done[kid] = solve_key(S, key, sr, sl, tg[i])
                pose, sr, sl, info = done[kid]
                pose = dict(pose)
                q = Euler([math.radians(a) for a in pose["hand.R"]], "XYZ").to_quaternion()
                turn = 0.0
                if prev_q is not None:
                    turn = math.degrees(2.0 * math.acos(min(1.0, abs(prev_q[1].dot(q))))) / max(1, key[0] - prev_q[0])
                prev_q = (key[0], q)
                worst = max(worst, info["l_grip"], info["r_pos"])
                print("%s %-15s f%-2d mao=(%.2f %.2f %.2f) dir=(%.2f %.2f %.2f) errR=%.3f dirR=%.1f gripL=%.3f ponta_z=%.2f cabeca=%.2f pes=%.3f/%.3f giro_mao=%.0f/q" % (
                    sex[0], clip, key[0], *info["hand"], *info["dir"], info["r_pos"], info["r_dir"], info["l_grip"], info["tip_z"], info["head_gap"], *info["feet"], turn))
                out.append((key[0], pose, tuple(key[2])))
            data[sex][clip] = (end, out)
    print("PIOR erro de mão: %.3f m" % worst)
    if "--dry" in ARGS:
        return
    lines = ['"""GERADO por crusader_chain_solve.py: poses resolvidas da sequência de duas mãos do Golpe do Cruzado. Não edite à mão."""',
             "# sexo -> clipe -> (quadro final, [(quadro, pose, quadril)])", "SOLVED = {"]
    for sex, clips in data.items():
        lines.append('    "%s": {' % sex)
        for clip, (end, out) in clips.items():
            lines.append('        "%s": (%d, [' % (clip, end))
            for f, pose, hips in out:
                body_s = ", ".join('"%s": (%s)' % (k, ", ".join("%g" % round(x, 1) for x in pose[k])) for k in ck.POSE_BONES if k in pose)
                lines.append("            (%d, {%s}, (%s))," % (f, body_s, ", ".join("%g" % x for x in hips)))
            lines.append("        ]),")
        lines.append("    },")
    lines.append("}")
    with open(os.path.join(HERE, "crusader_chain_data.py"), "w", encoding="utf-8", newline="\n") as fh:
        fh.write("\n".join(lines) + "\n")
    print("gravado crusader_chain_data.py")


run()
