"""Ato II, peças que dão cara própria a chefes e formas (usado por mob_kit.humanoid):

- crossbow(base, mats, ...)  besta de verdade (Besteiro Orc, Mestre Besteiro, Besteiro da Luz) no lugar do arco
- posture(rig, offsets)      postura somada a todos os clipes (troll curvado: tronco para a frente, cabeça erguida)
- boss_extras(cid, kind)     peças grandes dos chefes: Mãe das Marés, Agitador-Mor, Rei-da-Rocha, Mestre Besteiro, Ghar
- lich_parts                 Forma de Lich do Necromante (form_lich.glb)

Regra da câmera alta: o que conta é cabeça, ombros e costas; cada chefe ganha uma silhueta que nenhum monstro comum tem.
"""
import math

from mathutils import Vector

import chibi_kit as ck

V = Vector


def cone(name, root, tip, r, material, segs=8):
    return ck.tube(name, root, tip, r, r * 0.08, material, segs)


def _rigid(objs, rig, bone):
    for o in objs:
        ck.skin_rigid(o, rig, bone)


def _top_vertex(prefix):
    import bpy
    best = None
    for o in bpy.context.scene.objects:
        if o.type == "MESH" and o.name.startswith(prefix):
            for v in o.data.vertices:
                if best is None or v.co.z > best.z:
                    best = v.co.copy()
    return best


# ---------------------------------------------------------------------------
# besta
# ---------------------------------------------------------------------------
def crossbow(base, mats, heavy=False, metal=(0.3, 0.3, 0.34), accent=(0.78, 0.14, 0.12)):
    """Besta na mão direita, no eixo das armas do kit (o clipe de tiro é o do mosquete: coronha no ombro).
    heavy = arbalete do Mestre Besteiro: maior, dois arcos de ferro e virote grosso."""
    rig = base["rig"]
    g = V(ck.hand_center(base, ".R"))
    fwd = V((0, -0.55, 0.83)).normalized()
    side = V((1, 0, 0))
    up = fwd.cross(side).normalized() * -1.0
    k = 1.4 if heavy else 1.15
    n = "xb_"
    wood = mats["wood"]
    iron = ck.mat("m_xbow_iron_%d" % int(metal[0] * 100), metal, 0.45)
    red = ck.mat("m_xbow_acc_%d" % int(accent[0] * 100), accent, 0.7)
    steel = mats["metal"]
    cord = ck.mat("m_string", (0.95, 0.95, 0.9))
    if heavy:
        return _arbalest(rig, g, fwd, side, up, k, wood, iron, red, steel, cord)
    parts = [ck.tube(n + "tiller", g - fwd * 0.32 * k, g + fwd * 0.5 * k, 0.05 * k, 0.04 * k, wood, 6),
             ck.tube(n + "butt", g - fwd * 0.4 * k, g - fwd * 0.3 * k, 0.07 * k, 0.055 * k, iron, 6),
             ck.tube(n + "trigger", g + fwd * 0.02 - up * 0.04 * k, g + fwd * 0.1 - up * 0.1 * k, 0.012, 0.012, iron, 4),
             ck.tube(n + "stirrup", g + fwd * 0.5 * k, g + fwd * 0.57 * k, 0.065 * k, 0.065 * k, iron, 8)]
    rail = up * 0.05 * k
    for pi, pz in enumerate((0.44, 0.3) if heavy else (0.44,)):
        span = (0.42 if pi == 0 else 0.32) * k
        c0 = g + fwd * pz * k + rail
        ts = (-1.0, -0.62, -0.22, 0.22, 0.62, 1.0)
        pts = [c0 + side * (t * span) - fwd * (0.17 * k * t * t) for t in ts]
        for i in range(5):
            ra = 0.034 * k * (1.0 - 0.45 * abs(ts[i]))
            rb = 0.034 * k * (1.0 - 0.45 * abs(ts[i + 1]))
            parts.append(ck.tube("%sprod%d_%d" % (n, pi, i), pts[i], pts[i + 1], ra, rb, iron, 6))
        nock = g + fwd * (pz - 0.3) * k + rail
        for i, tip in enumerate((pts[0], pts[-1])):
            parts.append(ck.tube("%sstring%d_%d" % (n, pi, i), tip, nock, 0.007, 0.007, cord, 4))
        parts.append(ck.tube("%slash%d" % (n, pi), c0 - rail * 0.3, c0 + rail * 0.5, 0.055 * k, 0.055 * k, red, 6))
    b0 = g + fwd * 0.14 * k + rail
    b1 = g + fwd * 0.6 * k + rail
    parts += [ck.tube(n + "bolt", b0, b1, 0.016 * k, 0.016 * k, wood, 5),
              cone(n + "bolthead", b1, b1 + fwd * 0.13 * k, 0.034 * k, steel, 5),
              ck.blade(n + "fletch", b0 - fwd * 0.01, b0 + fwd * 0.1 * k, 0.07 * k, 0.012, red, up, 0.4)]
    obj = ck._join(parts, "wpn_main_crossbow")
    ck._smooth(obj.data)
    ck.skin_rigid(obj, rig, "hand.R")
    return obj


def _arbalest(rig, g, fwd, side, up, k, wood, iron, red, steel, cord):
    """Arbalete do Mestre Besteiro. De cima (52 graus) os dois arcos finos e curvos de antes pareciam patas de aranha:
    agora é UM arco de aço claro, grosso e quase reto (3 trechos), coronha larga de madeira clara com soleira de ferro e
    o virote em brasa em cima da calha. A silhueta é um T com um risco aceso no meio."""
    n = "xb_"
    stock = ck.mat("m_xbow_stock", (0.64, 0.45, 0.26), 0.8)
    bow = ck.mat("m_xbow_bow", (0.74, 0.76, 0.82), 0.4)
    hotbolt = ck.mat("m_xbow_hotbolt", (1.0, 0.78, 0.25), 0.3, 2.2)
    rail = up * 0.075 * k
    parts = [ck.tube(n + "tiller", g - fwd * 0.26 * k, g + fwd * 0.52 * k, 0.075 * k, 0.058 * k, stock, 6),
             ck.tube(n + "stock", g - fwd * 0.42 * k, g - fwd * 0.24 * k, 0.095 * k, 0.075 * k, stock, 6),
             ck.tube(n + "butt", g - fwd * 0.46 * k, g - fwd * 0.41 * k, 0.1 * k, 0.1 * k, iron, 6),
             ck.tube(n + "trigger", g + fwd * 0.02 - up * 0.05 * k, g + fwd * 0.1 - up * 0.12 * k, 0.016, 0.016, iron, 4),
             ck.tube(n + "stirrup", g + fwd * 0.52 * k, g + fwd * 0.6 * k, 0.07 * k, 0.07 * k, iron, 8)]
    c0 = g + fwd * 0.46 * k + rail * 0.4
    span = 0.47 * k
    ts = (-1.0, -0.36, 0.36, 1.0)
    pts = [c0 + side * (t * span) - fwd * (0.07 * k * t * t) for t in ts]
    rr = (0.04 * k, 0.066 * k, 0.066 * k, 0.04 * k)
    for i in range(3):
        parts.append(ck.tube("%sprod0_%d" % (n, i), pts[i], pts[i + 1], rr[i], rr[i + 1], bow, 6))
    nock = g + fwd * 0.14 * k + rail
    for i, tip in enumerate((pts[0], pts[-1])):
        parts.append(ck.ball("%sprodcap%d" % (n, i), 0.058 * k, tip, red))
        parts.append(ck.tube("%sstring0_%d" % (n, i), tip, nock, 0.012, 0.012, cord, 4))
    parts.append(ck.tube(n + "lash0", c0 - fwd * 0.05 * k, c0 + fwd * 0.05 * k, 0.095 * k, 0.095 * k, red, 6))
    b0 = nock
    b1 = g + fwd * 0.6 * k + rail
    parts += [ck.tube(n + "bolt", b0, b1, 0.03 * k, 0.03 * k, hotbolt, 5),
              cone(n + "bolthead", b1, b1 + fwd * 0.15 * k, 0.055 * k, steel, 5),
              ck.blade(n + "fletch", b0 - fwd * 0.02, b0 + fwd * 0.13 * k, 0.11 * k, 0.016, red, up, 0.4)]
    obj = ck._join(parts, "wpn_main_crossbow")
    ck._smooth(obj.data)
    ck.skin_rigid(obj, rig, "hand.R")
    return obj


# ---------------------------------------------------------------------------
# postura
# ---------------------------------------------------------------------------
TROLL_POSTURE = {"spine": (15, 0, 0), "chest": (13, 0, 0), "neck": (-8, 0, 0), "head": (-17, 0, 0),
                 "upper_arm.R": (-4, 0, 0), "forearm.R": (24, 0, 0), "upper_arm.L": (-22, 0, 0)}     # braço da arma mais solto: a marreta desce do rosto
TROLL_HIPS = (0.0, 0.05, -0.02)        # quadril um pouco para trás e para baixo: o peso do tronco fica sobre os pés


def posture(rig, offsets, hips=None, only=None):
    """Soma `offsets` (graus XYZ por osso) a TODOS os clipes do rig: a postura vale parado, correndo e golpeando.
    Ossos sem curva num clipe ficam como estão. `hips` = deslocamento somado ao quadril.
    `only` = nomes de clipe: a soma vale só neles (braço da arma no idle/corrida de um chefe; golpes ficam iguais)."""
    ad = rig.animation_data
    if ad is None:
        return
    for t in ad.nla_tracks:
        if only is not None and t.name not in only:
            continue
        act = t.strips[0].action
        for fc in ck._fcurves(act):
            path = fc.data_path
            if not path.startswith('pose.bones["'):
                continue
            bone = path.split('"')[1]
            if path.endswith("rotation_euler") and bone in offsets:
                d = math.radians(offsets[bone][fc.array_index])
            elif path.endswith("location") and bone == "hips" and hips:
                d = hips[fc.array_index]
            else:
                continue
            if abs(d) < 1e-6:
                continue
            for kp in fc.keyframe_points:
                kp.co.y += d
                kp.handle_left.y += d
                kp.handle_right.y += d
            fc.update()


def carry(rig, offsets, clips=("idle", "run")):
    """Jeito de levar a arma SÓ parado e correndo (graus XYZ somados por osso): tira a arma da frente da cabeça/rosto, que
    é a identidade do chefe na câmera alta. Golpes, magias, tranco e morte ficam como estão. Devolve o rig."""
    posture(rig, offsets, only=clips)
    return rig


# braço da arma mais baixo: o martelo de Kragmar fica na altura do ombro (tapava o elmo-bigorna visto de trás) e o arbalete
# de Vorgul desce para a cintura (tapava o rosto de frente)
KRAGMAR_CARRY = {"upper_arm.R": (22, 0, 0), "forearm.R": (12, 0, 0)}
VORGUL_CARRY = {"upper_arm.R": (25, 0, 0)}


def clear_ground(rig, clip, bone, prefixes, margin=0.03, step=3.0, front=False):
    """Tira do chão uma peça rígida (arma, escudo) nos clipes SÓ deste modelo: em cada quadro em que as malhas `prefixes`
    descem abaixo de `margin`, gira `bone` em volta da própria junta (eixo horizontal, o menor giro que livra o chão) e grava
    a chave. Nome, duração e os outros ossos do clipe não mudam. Chamar depois de mob_clips/posture.
    `clip` = nome, lista de nomes ou {nome: margem}; a chave "*" vale para todos os outros clipes do rig (no "die" o corpo
    afunda uns 0,2 m na queda: a margem dele é negativa, a arma só não pode passar do corpo).
    front=True (arma na mão): a peça sobe sempre pela FRENTE do boneco (a postura de troll deixa a marreta apontando para
    baixo e para trás; o menor giro a deitava atrás dele); o "die" fica com o menor giro."""
    if isinstance(clip, str):
        clip = {clip: margin}
    elif not isinstance(clip, dict):
        clip = {c: margin for c in clip}
    todo = {c: m for c, m in clip.items() if c != "*"}
    if "*" in clip:
        for name in ck._tracks(rig):
            todo.setdefault(name, clip["*"])
    for name, m in todo.items():
        _clear_ground_clip(rig, name, bone, prefixes, m, step, front and name != "die")
    return rig


def _clear_ground_clip(rig, clip, bone, prefixes, margin, step, front=False):
    import bpy
    import numpy as np
    from mathutils import Matrix
    ad = rig.animation_data
    tracks = ck._tracks(rig)
    if clip not in tracks:
        print("clear_ground: falta o clipe", clip)
        return rig
    act = tracks[clip].strips[0].action
    objs = [o for o in bpy.context.scene.objects if o.type == "MESH" and o.name.startswith(tuple(prefixes))]
    pb = rig.pose.bones[bone]
    sc = bpy.context.scene
    muted = [(t, t.mute) for t in ad.nla_tracks]
    for t, _m in muted:
        t.mute = True
    ad.action = act
    try:
        if act.slots:
            ad.action_slot = act.slots[0]
    except Exception:
        pass

    def lowest():
        bpy.context.view_layer.update()
        dg = bpy.context.evaluated_depsgraph_get()
        best = (1e9, None)
        for o in objs:
            e = o.evaluated_get(dg)
            me = e.to_mesh()
            co = np.empty(len(me.vertices) * 3, dtype=np.float32)
            me.vertices.foreach_get("co", co)
            e.to_mesh_clear()
            mw = np.array(e.matrix_world)
            w = co.reshape(-1, 3) @ mw[:3, :3].T + mw[:3, 3]
            i = int(w[:, 2].argmin())
            if w[i, 2] < best[0]:
                best = (float(w[i, 2]), V([float(x) for x in w[i]]))
        return best

    quat = pb.rotation_mode == "QUATERNION"
    path = "rotation_quaternion" if quat else "rotation_euler"
    inv = rig.matrix_world.inverted()
    fixed = []
    for _pass in range(3):          # a chave de um quadro mexe na curva dos vizinhos: repassa
        for f in range(1, int(round(act.frame_range[1])) + 1):
            sc.frame_set(f)
            z, pt = lowest()
            if z >= margin - 0.005:
                continue
            old = pb.rotation_quaternion.copy() if quat else pb.rotation_euler.copy()
            m0 = pb.matrix.copy()
            piv = m0.to_translation()
            arm = inv @ pt - piv
            axis = V((-1, 0, 0)) if front else arm.cross(V((0, 0, 1)))     # -X: o que aponta para baixo sobe para -Y (frente)
            if axis.length < 1e-4:
                continue
            axis.normalize()
            side = arm.cross(V((0, 0, 1)))
            axes = [(axis, 180.0)] + ([(side.normalized(), 120.0)] if front and side.length > 1e-4 else [])   # pela frente não deu: menor giro
            turn = lambda ax, deg: Matrix.Translation(piv) @ Matrix.Rotation(math.radians(deg), 4, ax) @ Matrix.Translation(-piv) @ m0
            best = (z, axis, 0.0)
            for ax, top in axes:
                a = 0.0
                while z < margin and a < (top if front else 120.0):
                    a += step
                    pb.matrix = turn(ax, a)
                    z, _pt = lowest()
                    if z > best[0]:
                        best = (z, ax, a)
                if z >= margin:
                    break
            if z < margin:                      # não livrou: fica o giro que mais levantou
                a = best[2]
                pb.matrix = turn(best[1], a)
                bpy.context.view_layer.update()
            if quat:
                if pb.rotation_quaternion.dot(old) < 0:
                    pb.rotation_quaternion.negate()
            else:
                pb.rotation_euler = pb.matrix_basis.to_euler("XYZ", old)
            pb.keyframe_insert(path, frame=f)
            fixed.append((f, round(a)))
    if fixed:
        print("clear_ground", rig.name, clip, bone, fixed)
    ad.action = None
    for t, m in muted:
        t.mute = m
    ck._reset_pose(rig)
    return rig


# ---------------------------------------------------------------------------
# chefes
# ---------------------------------------------------------------------------
KING_STONE = ((0.37, 0.34, 0.32), (0.21, 0.22, 0.28))     # pedra do Rei-da-Rocha (média, ardósia); mob_kit.horde_parts cria os materiais primeiro


def _xf(objs, mtx):
    for o in objs:
        o.data.transform(mtx)
    return objs


def tower_shield(cid, W=0.56, H=0.9):
    """Escudo-torre da Horda no desenho do prop_ghar_towershield (sig_props_a.tower_shield_parts: tábua com abas dobradas,
    ferragem, olho vermelho em losango, presas de osso, cravos), em peças do kit. Local: centro na origem, face para -Y."""
    from mathutils import Matrix
    wood = ck.mat("m_%s_tswood" % cid, (0.34, 0.225, 0.15), 0.85)
    wood_d = ck.mat("m_%s_tswood_d" % cid, (0.23, 0.15, 0.11), 0.85)
    iron = ck.mat("m_%s_tsiron" % cid, (0.33, 0.33, 0.39), 0.5)
    red = ck.mat("m_%s_tsred" % cid, (0.82, 0.16, 0.13), 0.7)
    bone = ck.mat("m_%s_tsbone" % cid, (0.93, 0.88, 0.74), 0.6)
    n = cid + "_ts_"
    T = 0.1 * W
    cw, ww = W * 0.52, W * 0.3
    parts = [ck.box(n + "board", (cw, T, H * 0.84), (0, 0, 0), wood),
             ck.box(n + "rim_top", (cw, T * 1.7, H * 0.1), (0, 0, H * 0.42), iron),
             ck.box(n + "rim_low", (cw, T * 1.7, H * 0.08), (0, 0, -H * 0.4), iron),
             ck.blade(n + "point", (0, 0, -H * 0.42), (0, 0, -H * 0.6), cw, T * 1.7, iron, (1, 0, 0), 0.06),
             ck.box(n + "plank", (cw * 0.34, T * 0.5, H * 0.72), (0, -T * 0.4, 0), wood_d)]
    for i, f in enumerate((-0.25, 0.3)):
        parts.append(ck.box("%sband%d" % (n, i), (cw, T * 1.4, H * 0.055), (0, 0, H * f), iron))
    for sx in (-1, 1):                      # abas dobradas para trás, mais curtas embaixo (o pé em V)
        wing = [ck.box("%swing%d" % (n, sx), (ww, T, H * 0.74), (sx * ww * 0.5, 0, H * 0.04), wood),
                ck.box("%swingtop%d" % (n, sx), (ww, T * 1.7, H * 0.09), (sx * ww * 0.5, 0, H * 0.39), iron),
                ck.box("%swinglow%d" % (n, sx), (ww, T * 1.7, H * 0.08), (sx * ww * 0.5, 0, -H * 0.31), iron),
                ck.box("%swingedge%d" % (n, sx), (W * 0.09, T * 1.7, H * 0.74), (sx * ww, 0, H * 0.04), iron)]
        for f in (-0.08, 0.2):
            wing.append(cone("%ssidespike%d_%d" % (n, sx, int(f * 100 + 50)), (sx * ww, 0, H * f), (sx * (ww + 0.2 * W), 0, H * f + 0.02), 0.07 * W, iron, 5))
        wing.append(cone("%stopspike%d" % (n, sx), (sx * ww * 0.5, 0, H * 0.42), (sx * ww * 0.5, 0, H * 0.42 + 0.24 * W), 0.085 * W, iron, 5))
        _xf(wing, Matrix.Translation((sx * cw * 0.5, 0, 0)) @ Matrix.Rotation(math.radians(-32 * sx), 4, "Z"))
        parts += wing
    parts.append(cone(n + "topspike0", (0, 0, H * 0.45), (0, 0, H * 0.45 + 0.34 * W), 0.095 * W, iron, 5))
    ez, ew, eh = H * 0.04, 0.34 * W, 0.2 * W   # olho da Horda: losango vermelho, pupila em fenda
    for sx in (-1, 1):
        parts.append(ck.blade("%seye%d" % (n, sx), (0, -T * 0.75, ez), (sx * ew, -T * 0.75, ez), eh * 2.0, 0.05 * W, red, (0, 0, 1), 0.04))
        parts.append(cone("%stusk%d" % (n, sx), (sx * 0.15 * W, -T * 0.5, ez - 0.4 * W), (sx * 0.3 * W, -T * 0.5 - 0.13 * W, ez - 0.1 * W), 0.07 * W, bone, 5))
    parts.append(ck.blade(n + "pupil", (0, -T * 0.75 - 0.03 * W, ez - eh * 0.7), (0, -T * 0.75 - 0.03 * W, ez + eh * 0.7), 0.09 * W, 0.03 * W, wood_d, (1, 0, 0), 0.5))
    return parts


def boss_extras(cid, kind):
    """Peças de chefe por cima de horde_parts (rodam DEPOIS da arma: algumas vestem a arma)."""
    def add(base, mats):
        rig, b = base["rig"], base["b"]
        c, r = V(base["head_c"]), b["head"]
        zc, zw = ck.Z["chest"], ck.Z["waist"]
        back, front = b["chest"] * b["depth"], -b["chest"] * b["depth"]
        sw = b["chest"]
        bone = ck.mat("m_%s_bossbone" % cid, (0.93, 0.89, 0.76), 0.6)
        iron = ck.mat("m_%s_bossiron" % cid, (0.26, 0.26, 0.3), 0.45)
        red = ck.mat("m_%s_bossred" % cid, (0.8, 0.14, 0.12), 0.7)
        head, body, hips, hand = [], [], [], []

        def skull(name, p, s, mat_eye):
            out = [ck.ball(name, s, p, bone, (1.0, 1.0, 0.95)),
                   ck.ball(name + "_jaw", s * 0.6, p + V((0, -s * 0.35, -s * 0.75)), bone, (1.0, 0.9, 0.7))]
            for sx in (-1, 1):
                out.append(ck.ball("%s_eye%d" % (name, sx), s * 0.24, p + V((sx * s * 0.38, -s * 0.82, s * 0.05)), mat_eye))
            return out

        dark = ck.mat("m_%s_bossdark" % cid, (0.1, 0.08, 0.1), 0.7)
        if kind == "tide_mother":
            coral = ck.mat("m_%s_coral" % cid, (0.98, 0.45, 0.42), 0.5)
            coral2 = ck.mat("m_%s_coral2" % cid, (1.0, 0.66, 0.5), 0.5)
            pearl = ck.mat("m_%s_pearl" % cid, (0.95, 0.97, 1.0), 0.2, 0.9)
            water = ck.mat("m_%s_water" % cid, (0.45, 0.9, 1.0), 0.2, 1.4)
            shell = ck.mat("m_%s_shell" % cid, (0.98, 0.84, 0.8), 0.45)
            fin = ck.mat("m_%s_fin" % cid, (0.2, 0.55, 0.65), 0.6)
            for sx in (-1, 1):                  # galhada de coral: tronco, dois galhos e pontas
                p0 = c + V((sx * r * 0.55, r * 0.1, r * 0.7))
                p1 = p0 + V((sx * r * 0.55, r * 0.1, r * 0.75))
                p2 = p1 + V((sx * r * 0.5, 0, r * 0.7))
                head.append(ck.tube("%s_antler%d_a" % (cid, sx), p0, p1, r * 0.17, r * 0.13, coral, 6))
                head.append(cone("%s_antler%d_b" % (cid, sx), p1, p2, r * 0.13, coral, 6))
                head.append(cone("%s_antler%d_c" % (cid, sx), p1, p1 + V((-sx * r * 0.15, -r * 0.1, r * 0.75)), r * 0.11, coral2, 6))
                head.append(cone("%s_antler%d_d" % (cid, sx), p0.lerp(p1, 0.5), p0.lerp(p1, 0.5) + V((sx * r * 0.6, r * 0.25, r * 0.1)), r * 0.1, coral2, 6))
                head.append(ck.ball("%s_antlerpearl%d" % (cid, sx), r * 0.11, p2 + V((0, 0, r * 0.05)), pearl))
                # ombreiras de concha (leque de gomos) por cima das escamas
                sc = V((sx * (sw + 0.07), 0.0, zc + 0.17))
                for i in range(5):
                    a = math.radians(-60 + i * 30)
                    tip = sc + V((sx * 0.2 * math.cos(a) + sx * 0.04, 0.2 * math.sin(a), 0.12 - 0.05 * abs(i - 2)))
                    body.append(ck.blade("%s_shell%d_%d" % (cid, sx, i), sc, tip, 0.13, 0.03, shell if i % 2 else coral2, (-math.sin(a) * sx, math.cos(a), 0), 0.7))
            head.append(ck.ball(cid + "_browpearl", r * 0.16, c + V((0, -r * 0.93, r * 0.45)), pearl))
            for i in range(4):                  # barbatana dorsal em leque nas costas
                z = zc + 0.2 - i * 0.13
                body.append(ck.blade("%s_dorsal%d" % (cid, i), V((0, back + 0.02, z)), V((0, back + 0.34 - i * 0.04, z + 0.16)), 0.2, 0.03, fin, (0, 0, 1), 0.5))
            top = _top_vertex("wpn_main_staff")  # o cajado vira tridente de coral com a pérola das marés
            if top is not None:
                for i in (-1, 0, 1):
                    hand.append(cone("%s_prong%d" % (cid, i), top + V((i * 0.07, 0, -0.03)), top + V((i * 0.16, 0, 0.3 if i else 0.4)), 0.035, coral, 6))
                hand.append(ck.tube(cid + "_prongbar", top + V((-0.13, 0, -0.02)), top + V((0.13, 0, -0.02)), 0.03, 0.03, coral2, 6))
                hand.append(ck.ball(cid + "_tideorb", 0.11, top + V((0, 0, 0.02)), water))
        elif kind == "agitator_lord":
            wood = ck.mat("m_%s_bosswood" % cid, (0.42, 0.3, 0.2), 0.8)
            fire = ck.mat("m_%s_eyefire" % cid, (1.0, 0.5, 0.15), 0.3, 2.0)
            for sx in (-1, 1):                  # dois totens de caveira com flâmula saindo do tambor das costas
                p0 = V((sx * 0.2, back + 0.2, zc - 0.1))
                p1 = V((sx * 0.38, back + 0.3, zc + 0.95))
                body.append(ck.tube("%s_totem%d" % (cid, sx), p0, p1, 0.03, 0.025, wood, 6))
                body += skull("%s_totemskull%d" % (cid, sx), p1 + V((0, 0, 0.08)), 0.1, fire)
                body.append(ck.blade("%s_totemflag%d" % (cid, sx), p1 + V((0, 0.02, -0.05)), p1 + V((sx * 0.06, 0.1, -0.5)), 0.2, 0.02, red, (1, 0, 0), 0.35))
                for k in range(2):
                    body.append(cone("%s_totemrib%d_%d" % (cid, sx, k), p0.lerp(p1, 0.55 + 0.2 * k), p0.lerp(p1, 0.55 + 0.2 * k) + V((sx * 0.16, 0.02, 0.05)), 0.025, bone, 5))
                # ombreira de caveira
                body += skull("%s_shskull%d" % (cid, sx), V((sx * (sw + 0.07), -0.02, zc + 0.17)), 0.11, dark)
            # máscara de caveira de bicho na testa, com chifres
            head.append(ck.ball(cid + "_mask", r * 0.62, c + V((0, -r * 0.55, r * 0.52)), bone, (1.25, 0.8, 0.6)))
            for sx in (-1, 1):
                head.append(ck.ball("%s_maskeye%d" % (cid, sx), r * 0.13, c + V((sx * r * 0.3, -r * 0.98, r * 0.5)), dark))
                h0 = c + V((sx * r * 0.6, -r * 0.3, r * 0.75))
                h1 = h0 + V((sx * r * 0.55, -r * 0.1, r * 0.35))
                head.append(ck.tube("%s_maskhorn%da" % (cid, sx), h0, h1, r * 0.15, r * 0.12, bone, 6))
                head.append(cone("%s_maskhorn%db" % (cid, sx), h1, h1 + V((sx * r * 0.1, -r * 0.35, r * 0.6)), r * 0.12, bone, 6))
            body.append(ck.ball(cid + "_belly", 0.2, V((0, front - 0.02, zw + 0.03)), ck.mat("m_%s_bellyskin" % cid, (0.5, 0.64, 0.3), 0.7), (1.05, 0.8, 0.9)))
            for i in range(5):                  # colar de presas
                a = math.radians(-50 + i * 25)
                p = V((math.sin(a) * sw * 0.8, front - 0.03 - 0.03 * math.cos(a), zc + 0.1 - 0.05 * math.cos(a)))
                body.append(cone("%s_fang%d" % (cid, i), p, p + V((0, -0.02, -0.1)), 0.025, bone, 5))
        elif kind == "troll_king":
            # paleta funda (no toon ele saía lavado): pedra média escura e ardósia; a pedra clara `pale` fica só de realce
            stone = ck.mat("m_%s_stone" % cid, KING_STONE[0], 0.9)
            stone2 = ck.mat("m_%s_stone2" % cid, KING_STONE[1], 0.9)
            rune = ck.mat("m_%s_rune" % cid, (1.0, 0.4, 0.06), 0.3, 2.0)
            moss = ck.mat("m_%s_moss" % cid, (0.3, 0.46, 0.18), 0.9)
            import bpy
            hide = ck.mat("m_%s_hide" % cid, (0.42, 0.2, 0.15), 0.9)      # a gola do kit (tint2, quase branca) vira couro escuro
            for o in bpy.context.scene.objects:
                if o.type == "MESH" and o.name.startswith("arm_leather_body_mantle"):
                    o.data.materials[0] = hide
            # laje de pedra nas costas, rachada de runas acesas (a "montanha" que ele carrega)
            for i in range(3):
                z0 = zw + 0.02 + i * 0.1
                body.append(ck.blade("%s_slab%d" % (cid, i), V(((i - 1) * 0.2, back + 0.1, z0)), V(((i - 1) * 0.3, back + 0.3, zc + 0.5 + (0.22 if i == 1 else 0.0))), 0.3, 0.12, stone if i % 2 else stone2, (1, 0, 0), 0.5))
                body.append(ck.tube("%s_rune%d" % (cid, i), V(((i - 1) * 0.22, back + 0.24, zc - 0.02)), V(((i - 1) * 0.27, back + 0.33, zc + 0.3)), 0.022, 0.012, rune, 4))
            for sx in (-1, 1):                  # musgo nos ombros e punhos de pedra
                body.append(ck.ball("%s_moss%d" % (cid, sx), 0.15, V((sx * (sw + 0.02), 0.06, zc + 0.24)), moss, (1.3, 1.0, 0.5)))
            body.append(ck.ball(cid + "_runecore", 0.07, V((0, front - 0.03, zc + 0.03)), rune, (1, 0.5, 1)))
            for i in range(7):                  # colar de caveiras/pedras
                a = math.radians(-66 + i * 22)
                p = V((math.sin(a) * sw * 0.9, front - 0.02 - 0.05 * math.cos(a), zc + 0.13 - 0.07 * math.cos(a)))
                body.append(ck.ball("%s_bead%d" % (cid, i), 0.05 if i % 2 else 0.065, p, bone if i % 2 else stone2))
            for sx in (-1, 1):                  # chifres de carneiro de pedra
                h0 = c + V((sx * r * 0.82, r * 0.1, r * 0.35))
                pts = [h0]
                for k in range(1, 5):
                    a = k / 4 * math.pi * 0.95
                    pts.append(h0 + V((sx * r * (0.25 + 0.3 * math.sin(a)), r * (0.55 * math.sin(a) * 0.4 - 0.25 * (1 - math.cos(a))), r * (0.4 * math.sin(a) - 0.25 * (1 - math.cos(a))))))
                for k in range(4):
                    head.append(ck.tube("%s_ram%d_%d" % (cid, sx, k), pts[k], pts[k + 1], r * (0.24 - k * 0.045), r * (0.2 - k * 0.045), stone2 if k % 2 else stone, 6))
            # "EU SOU A MONTANHA": pico de três lajes atrás da coroa (a cabeça é o que a câmera alta mais vê), runa acesa na
            # testa e no pico; a pedra clara é a do prop_avalanche_stone
            pale = ck.mat("m_%s_stonepale" % cid, (0.78, 0.78, 0.82), 0.9)
            for i in (-1, 0, 1):
                p0 = c + V((i * r * 0.5, r * 0.5, r * 0.45))
                p1 = c + V((i * r * 0.95, r * (1.0 if i else 0.85), r * (1.55 if i else 2.15)))
                head.append(ck.blade("%s_peak%d" % (cid, i), p0, p1, r * (0.6 if i else 0.8), r * 0.3, stone2 if i else pale, (1, 0, 0), 0.4))
            head.append(ck.tube(cid + "_peakrune", c + V((0, r * 0.83, r * 1.0)), c + V((0, r * 1.02, r * 1.75)), r * 0.07, r * 0.03, rune, 4))
            head.append(ck.ball(cid + "_browrune", r * 0.2, c + V((0, -r * 0.86, r * 0.62)), rune, (0.8, 0.5, 1.2)))
            def rock(name, rr, at, m, scale):   # pedra facetada (sem suavizar), como o prop_avalanche_stone
                o = ck.ball(name, rr, at, m, scale)
                for pl in o.data.polygons:
                    pl.use_smooth = False
                return o

            for sx, rr in ((1, 0.2), (-1, 0.165)):   # um pedregulho inteiro em cada ombro (o esquerdo maior), com runa acesa
                sp = V((sx * (sw + 0.13), 0.03, zc + 0.3))
                body.append(rock("%s_boulder%d" % (cid, sx), rr, sp, pale if sx > 0 else stone, (1.1, 1.0, 0.88)))
                body.append(ck.ball("%s_boulderrune%d" % (cid, sx), rr * 0.3, sp + V((sx * rr * 0.15, -rr * 0.72, rr * 0.45)), rune, (1.0, 0.6, 1.3)))
                body.append(cone("%s_bouldertip%d" % (cid, sx), sp + V((sx * rr * 0.4, 0, rr * 0.5)), sp + V((sx * rr * 1.0, 0.02, rr * 1.7)), rr * 0.45, stone2, 5))
            # a marreta do kit vira um pedregulho cravado no cabo: a arma de quem arremessa a montanha
            g = V(ck.hand_center(base, ".R"))
            fwd = V((0, -0.55, 0.83)).normalized()
            hc = g + fwd * 0.94
            hand.append(rock(cid + "_maulrock", 0.27, hc, pale, (1.2, 0.98, 0.9)))
            hand.append(rock(cid + "_maulrock_a", 0.17, hc + V((0.21, 0.07, 0.11)), stone2, (1.0, 0.85, 1.0)))
            hand.append(rock(cid + "_maulrock_b", 0.16, hc + V((-0.23, -0.08, 0.03)), stone, (1.0, 0.9, 0.8)))
            hand.append(rock(cid + "_maulrock_c", 0.13, hc + V((0.06, 0.2, -0.1)), stone2, (1.1, 0.8, 0.9)))
            for k, (d, ln) in enumerate(((fwd, 0.5), (V((0.8, -0.3, 0.5)).normalized(), 0.42), (V((-0.75, 0.35, 0.55)).normalized(), 0.4), (V((-0.3, -0.9, -0.3)).normalized(), 0.38))):
                hand.append(cone("%s_maulshard%d" % (cid, k), hc + d * 0.1, hc + d * ln, 0.13, stone2 if k % 2 else stone, 4))
            crack = [hc + V((-0.2, -0.2, 0.13)), hc + V((-0.06, -0.265, 0.02)), hc + V((0.07, -0.25, 0.1)), hc + V((0.2, -0.2, -0.04))]
            for k in range(3):                  # racha de runa na face da pedra
                hand.append(ck.tube("%s_maulrune%d" % (cid, k), crack[k], crack[k + 1], 0.028, 0.028, rune, 4))
            hand.append(ck.tube(cid + "_maulrope", hc - fwd * 0.3, hc - fwd * 0.2, 0.075, 0.11, ck.mat("m_%s_rope" % cid, (0.5, 0.38, 0.22), 0.9), 7))
        elif kind == "crossbow_master":
            wood = ck.mat("m_%s_bosswood" % cid, (0.42, 0.3, 0.2), 0.8)
            lens = ck.mat("m_%s_lens" % cid, (1.0, 0.75, 0.3), 0.2, 2.0)
            # pavês de cerco nas costas: tábua alta com ferragem e o olho vermelho da Horda
            p0, p1 = V((0, back + 0.2, ck.Z["knee"] + 0.02)), V((0, back + 0.26, zc + 0.52))
            body.append(ck.blade(cid + "_pavise", p0, p1, 0.62, 0.05, wood, (1, 0, 0), 0.72))
            body.append(ck.blade(cid + "_pavise_rim", p0 + V((0, 0.03, 0.1)), p1 + V((0, 0.03, -0.1)), 0.2, 0.03, iron, (1, 0, 0), 0.6))
            body.append(ck.ball(cid + "_pavise_eye", 0.09, V((0, back + 0.29, zc + 0.12)), red, (1.2, 0.4, 0.8)))
            for sx in (-1, 1):
                body.append(cone("%s_pavise_spike%d" % (cid, sx), p1 + V((sx * 0.14, 0, -0.14)), p1 + V((sx * 0.2, 0.02, 0.12)), 0.04, iron, 5))
            # luneta de mira no olho direito e viseira de ferro
            e = c + V((-r * 0.38, -r * 0.92, -r * 0.1))
            head.append(ck.tube(cid + "_scope", e + V((0, r * 0.15, 0)), e + V((0, -r * 0.5, 0)), r * 0.2, r * 0.24, iron, 8))
            head.append(ck.ball(cid + "_scopelens", r * 0.2, e + V((0, -r * 0.5, 0)), lens, (1, 0.35, 1)))
            head.append(ck.tube(cid + "_scopestrap", c + V((0, 0, -r * 0.05)), c + V((0, 0, r * 0.07)), r * 1.03, r * 1.03, ck.mat("m_%s_bossstrap" % cid, (0.3, 0.2, 0.12), 0.85), 14))
            for i in range(6):                  # bandoleira de virotes no peito
                t = i / 5
                p = V((sw * (0.75 - 1.45 * t), front - 0.05, zc + 0.14 - 0.3 * t))
                body.append(ck.tube("%s_bandolier%d" % (cid, i), p + V((0, 0, -0.06)), p + V((0, 0, 0.07)), 0.018, 0.018, wood, 4))
                body.append(cone("%s_bandotip%d" % (cid, i), p + V((0, 0, 0.07)), p + V((0, 0, 0.12)), 0.026, iron, 4))
            # chapéu de ferro de aba larga com filete vermelho e crista de crina de frente a trás: de cima nenhum orc tem
            # esta cabeça (o elmo comum é uma cúpula lisa)
            mark = ck.mat("m_%s_mark" % cid, (1.0, 0.22, 0.14), 0.4, 1.6)
            ember = ck.mat("m_%s_ember" % cid, (1.0, 0.6, 0.15), 0.3, 2.4)
            hz = c + V((0, r * 0.04, r * 0.2))
            head.append(ck.tube(cid + "_brim", hz + V((0, 0, -r * 0.02)), hz + V((0, 0, r * 0.26)), r * 1.34, r * 1.0, iron, 14))
            head.append(ck.tube(cid + "_brimedge", hz + V((0, 0, -r * 0.07)), hz + V((0, 0, -r * 0.01)), r * 1.36, r * 1.36, red, 14))
            for i in range(6):
                y = r * (-0.72 + i * 0.3)
                zs = r * (0.2 + 0.79 * math.sqrt(max(0.05, 1.0 - (y / (r * 1.07)) ** 2)))
                tall = r * (0.62 + 0.22 * math.sin(math.pi * (i + 0.5) / 6))
                head.append(ck.blade("%s_crest%d" % (cid, i), c + V((0, y, zs - r * 0.12)), c + V((0, y + r * 0.2, zs + tall)), r * 0.46, r * 0.13, red, (0, 1, 0), 0.5))
            head.append(ck.box(cid + "_crestridge", (r * 0.14, r * 1.7, r * 0.1), c + V((0, r * 0.04, r * 0.98)), iron))
            for k in (-1, 1):                   # rabo da crina caindo pelas costas do elmo
                head.append(ck.blade("%s_cresttail%d" % (cid, k), c + V((k * r * 0.08, r * 0.95, r * 0.55)), c + V((k * r * 0.2, r * 1.75, -r * 0.45)), r * 0.34, r * 0.08, red, (1, 0, 0), 0.4))
            for sx in (-1, 1):                  # segunda placa de ombro, vermelha, por baixo da de ferro
                body.append(ck.ball("%s_pauldron2_%d" % (cid, sx), 0.2, V((sx * (sw + 0.11), 0.0, zc + 0.08)), red, (1.1, 1.1, 0.5)))
            # Marca do Atirador: a retícula vermelha da skill pintada no pavês (lida de costas) ...
            mc = V((0, back + 0.285, zc + 0.12))
            body.append(ck.tube(cid + "_markring", mc, mc + V((0, 0.012, 0)), 0.21, 0.21, mark, 14))
            body.append(ck.tube(cid + "_markhole", mc, mc + V((0, 0.02, 0)), 0.15, 0.15, wood, 14))
            for k in range(4):
                d = V((math.cos(k * math.pi / 2), 0, math.sin(k * math.pi / 2)))
                body.append(ck.box("%s_marktick%d" % (cid, k), (0.045 + 0.1 * abs(d.x), 0.03, 0.045 + 0.1 * abs(d.z)), mc + d * 0.235 + V((0, 0.012, 0)), mark))
            # ... e o virote de fogo armado no arbalete (as contas são as de crossbow(heavy=True))
            g = V(ck.hand_center(base, ".R"))
            fwd = V((0, -0.55, 0.83)).normalized()
            upv = fwd.cross(V((1, 0, 0))).normalized() * -1.0
            tip = g + fwd * 0.6 * 1.4 + upv * 0.075 * 1.4 + fwd * 0.1
            hand.append(ck.ball(cid + "_firebolt", 0.075, tip, ember, (1, 1, 1)))
            for k in range(3):
                a = math.tau * k / 3
                d = V((math.cos(a), 0, 0)) * 0.05 + upv * math.sin(a) * 0.05
                hand.append(cone("%s_fireflame%d" % (cid, k), tip + d, tip + d * 1.8 - fwd * 0.2 + V((0, 0, 0.06)), 0.04, mark if k else ember, 4))
            # barril de pólvora no quadril esquerdo, pavio aceso (Barris de Pólvora)
            kc = V((sw + 0.1, 0.02, zw - 0.04))
            hips.append(ck.tube(cid + "_keg", kc + V((0, -0.11, 0)), kc + V((0, 0.11, 0)), 0.095, 0.095, wood, 8))
            for k in (-1, 1):
                hips.append(ck.tube("%s_kegband%d" % (cid, k), kc + V((0, k * 0.07 - 0.012, 0)), kc + V((0, k * 0.07 + 0.012, 0)), 0.102, 0.102, red, 8))
            hips.append(ck.tube(cid + "_kegfuse", kc + V((0, 0, 0.09)), kc + V((0.04, -0.02, 0.19)), 0.012, 0.012, dark, 4))
            hips.append(ck.ball(cid + "_kegspark", 0.03, kc + V((0.04, -0.02, 0.2)), ember))
        elif kind == "ghar":
            fur = ck.mat("m_%s_fur" % cid, (0.34, 0.28, 0.24), 0.95)
            fur2 = ck.mat("m_%s_fur2" % cid, (0.5, 0.44, 0.38), 0.95)
            fire = ck.mat("m_%s_eyefire" % cid, (1.0, 0.4, 0.12), 0.3, 2.0)
            n = 9                              # manto de pele de lobo: gola de tufos de ombro a ombro pelas costas
            for i in range(n):
                a = math.radians(-100 + i * 200 / (n - 1))
                p = V((math.sin(a) * (sw + 0.1), 0.02 + math.cos(a) * (back + 0.07), zc + 0.2))
                body.append(ck.ball("%s_fur%d" % (cid, i), 0.12, p, fur if i % 2 else fur2, (1.0, 1.0, 0.8)))
                body.append(cone("%s_furtip%d" % (cid, i), p, p + V((math.sin(a) * 0.12, math.cos(a) * 0.12, -0.2)), 0.07, fur if i % 2 else fur2, 5))
            # cabeça do lobo no ombro esquerdo (troféu), olhos acesos
            wp = V((sw + 0.14, -0.04, zc + 0.3))
            body.append(ck.ball(cid + "_wolfhead", 0.13, wp, fur, (1.0, 1.15, 0.9)))
            body.append(cone(cid + "_wolfsnout", wp + V((0, -0.08, -0.02)), wp + V((0.02, -0.3, -0.06)), 0.08, fur2, 6))
            for sx in (-1, 1):
                body.append(cone("%s_wolfear%d" % (cid, sx), wp + V((sx * 0.07, 0.02, 0.08)), wp + V((sx * 0.1, 0.05, 0.22)), 0.04, fur, 4))
                body.append(ck.ball("%s_wolfeye%d" % (cid, sx), 0.022, wp + V((sx * 0.06, -0.12, 0.03)), fire))
            for i in range(3):                  # caveiras de troféu no cinto
                hips.extend(skull("%s_trophy%d" % (cid, i), V(((i - 1) * 0.17, front - 0.06 + 0.03 * abs(i - 1), zw - 0.06)), 0.07, dark))
            hips.append(ck.tube(cid + "_warbelt", V((0, 0, zw - 0.04)), V((0, 0, zw + 0.05)), sw * 1.1, sw * 1.1, iron, 12))
            # o cinto é um tubo sem tampa, mais largo que a cintura: visto de cima/de costas (e na corrida, com o tronco
            # inclinado) aparecia o vão entre ele e o corpo. Dois chanfros fecham o vão em cima e embaixo.
            hips.append(ck.tube(cid + "_warbelt_top", V((0, 0, zw + 0.05)), V((0, 0, zw + 0.1)), sw * 1.1, sw * 0.8, iron, 12))
            hips.append(ck.tube(cid + "_warbelt_low", V((0, 0, zw - 0.09)), V((0, 0, zw - 0.04)), sw * 0.86, sw * 1.1, iron, 12))
            for sx in (-1, 1):                  # presas de javali do elmo, mais largas que os chifres
                t0 = c + V((sx * r * 0.7, -r * 0.6, -r * 0.15))
                head.append(cone("%s_boartusk%d" % (cid, sx), t0, t0 + V((sx * r * 0.45, -r * 0.5, r * 0.55)), r * 0.13, bone, 6))
            head.append(ck.blade(cid + "_helmcrest", c + V((0, -r * 0.5, r * 1.0)), c + V((0, r * 1.0, r * 1.35)), r * 0.5, r * 0.09, red, (0, 0, 1), 0.55))
            # olho da Horda na testa do elmo (o mesmo losango do escudo) e anéis vermelhos nos chifres
            for sx in (-1, 1):
                head.append(ck.blade("%s_helmeye%d" % (cid, sx), c + V((0, -r * 1.0, r * 0.62)), c + V((sx * r * 0.36, -r * 0.9, r * 0.62)), r * 0.36, r * 0.1, red, (0, 0, 1), 0.04))
                h0 = c + V((sx * r * 0.85, 0, r * 0.55))
                head.append(ck.tube("%s_hornring%d" % (cid, sx), h0 + V((sx * r * 0.2, 0, r * 0.09)), h0 + V((sx * r * 0.34, 0, r * 0.155)), r * 0.2, r * 0.19, red, 7))
            head.append(ck.blade(cid + "_helmpupil", c + V((0, -r * 1.04, r * 0.46)), c + V((0, -r * 1.04, r * 0.78)), r * 0.09, r * 0.06, dark, (1, 0, 0), 0.5))
            # o machado de guerra (duas lâminas, a de trás menor, e espigão) é o do kit com a cabeça GHAR_AXE (mob_kit: axe=)
            # Muralha de Escudos: escudo-torre no antebraço esquerdo (pendurado ao lado do corpo no idle), o mesmo do prop
            from mathutils import Matrix
            wrist, elbow = V(base["j"]["wrist.L"]), V(base["j"]["elbow.L"])
            s_up = (elbow - wrist).normalized()
            f0 = V((0.55, -0.83, 0.0))
            s_face = (f0 - s_up * f0.dot(s_up)).normalized()
            s_right = (-s_face).cross(s_up).normalized()
            s_c = wrist.lerp(elbow, 0.3) + s_face * (b["wrist"] + 0.085)
            mtx = Matrix.Translation(s_c) @ Matrix((s_right, -s_face, s_up)).transposed().to_4x4()
            shield = ck._join(_xf(tower_shield(cid), mtx), cid + "_towershield")
            ck.skin_rigid(shield, rig, "forearm.L")
        _rigid(head, rig, "head")
        _rigid(body, rig, "chest")
        _rigid(hips, rig, "hips")
        _rigid(hand, rig, "hand.R")
    return add


# ---------------------------------------------------------------------------
# Ghar: Muralha de Escudos (design/gdd/act2-boss-signatures.md 3.5): dois clipes só dele, por cima dos do kit
#   guard_wall    laço de 28 quadros (1,17 s): agachado de pernas abertas, escudo-torre fincado à frente, machado erguido atrás da borda
#   wall_counter  23 quadros (0,92 s): recolhe, pancada de escudo, machado de cima para baixo (impacto no quadro GHAR_COUNTER_IMPACT)
# Braço do escudo e pernas achados por busca no rig (o escudo é rígido no forearm.L; os pés ficam onde a guarda os plantou).
# ---------------------------------------------------------------------------
GHAR_COUNTER_IMPACT = 10        # quadro (base 1) do machado no chão: (10 - 1) / 24 = 0,375 s
GHAR_FEET = {"L": (0.2, -0.08), "R": (-0.21, 0.08)}        # tornozelos plantados (x, y); o esquerdo (do escudo) à frente
GHAR_GUARD_HIPS = (0.0, -0.08, -0.02)                      # quadril: (lado, cima, frente) -> baixo e um pouco para trás
GHAR_TORSO = {      # tronco e cabeça de cada chave; braços e pernas em GHAR_SOLVED
    "guard": {"spine": (2, -22, 0), "chest": (-2, -16, 0), "neck": (0, 6, 0), "head": (-2, 30, 0)},
    "coil": {"spine": (-4, -8, 0), "chest": (-4, -6, 0), "neck": (0, 2, 0), "head": (4, 10, 0)},
    "bash": {"spine": (14, -22, 0), "chest": (6, -12, 0), "neck": (0, 6, 0), "head": (-16, 26, 0)},
    "swing1": {"spine": (17, -11, 0), "chest": (6, -6, 0), "neck": (0, 3, 0), "head": (-17, 13, 0)},
    "swing2": {"spine": (21, 0, 0), "chest": (6, 0, 0), "neck": (0, 1, 0), "head": (-19, -1, 0)},
    "chop": {"spine": (24, 10, 0), "chest": (6, 6, 0), "neck": (0, -2, 0), "head": (-20, -14, 0)},
    "follow": {"spine": (26, 13, 0), "chest": (7, 7, 0), "neck": (0, -2, 0), "head": (-22, -18, 0)},
    "lift": {"spine": (19, 9, 0), "chest": (5, 4, 0), "neck": (0, -1, 0), "head": (-16, -12, 0)},
    "recover": {"spine": (11, 4, 0), "chest": (2, 2, 0), "head": (-8, -5, 0)},
}
GHAR_SOLVED = {
    "guard": {"upper_arm.L": (-71.9, -25, 13.1), "forearm.L": (71.5, 5.9, 17.1), "upper_arm.R": (-85, 26, 29), "forearm.R": (-11, 0, 0), "hand.R": (52, 52, -40),
              "thigh.L": (-50.6, 0, -27.2), "shin.L": (53.1, 0, 0), "foot.L": (0, 0, 0), "thigh.R": (-13.8, 0, 30.3), "shin.R": (60.3, 0, 0), "foot.R": (-42, 0, 0)},
    "coil": {"upper_arm.L": (-70, 8.1, 12.5), "forearm.L": (71, 3.9, 11.2), "upper_arm.R": (-98, 74, 14), "forearm.R": (-10, 0, 0), "hand.R": (64, 68, -52),
             "thigh.L": (-59.1, 0, -29.7), "shin.L": (48.8, 0, 0), "foot.L": (14, 0, 0), "thigh.R": (-31.9, 0, 33.1), "shin.R": (77.8, 0, 0), "foot.R": (-40, 0, 0)},
    "bash": {"upper_arm.L": (-125, -23.8, 19.4), "forearm.L": (104.1, -5.2, 20), "upper_arm.R": (-86, 96, 30), "forearm.R": (-10, 0, 0), "hand.R": (-7, 53, -128),
             "thigh.L": (-33.8, 0, -25.3), "shin.L": (54.7, 0, 0), "foot.L": (-18, 0, 0), "thigh.R": (27.5, 0, 28.1), "shin.R": (1.9, 0, 0), "foot.R": (-26, 0, 0)},
    "swing1": {"upper_arm.L": (-39.6, 36.3, -146.5), "forearm.L": (-79.3, 8.6, 141.4), "upper_arm.R": (-88, 112, 30), "forearm.R": (-10, 0, 0), "hand.R": (7, 67, -138),
               "thigh.L": (-37.8, 0, -26.6), "shin.L": (62.5, 0, 0), "foot.L": (-22, 0, 0), "thigh.R": (20, 0, 29.4), "shin.R": (19.7, 0, 0), "foot.R": (-36, 0, 0)},
    "swing2": {"upper_arm.L": (-40.2, 34.4, -139), "forearm.L": (-86.1, 4.8, 128.9), "upper_arm.R": (-93, 91, 30), "forearm.R": (-34, 0, 0), "hand.R": (-2, 110, -172),
               "thigh.L": (-40.6, 0, -27.5), "shin.L": (68.1, 0, 0), "foot.L": (-24, 0, 0), "thigh.R": (12.8, 0, 30.6), "shin.R": (36.2, 0, 0), "foot.R": (-44, 0, 0)},
    "chop": {"upper_arm.L": (-40.8, 34.4, -129), "forearm.L": (-89.5, 1.1, 115.6), "upper_arm.R": (-64, 7, 30), "forearm.R": (-80, 0, 0), "hand.R": (32, 174, -127),
             "thigh.L": (-44.4, 0, -29.1), "shin.L": (75, 0, 0), "foot.L": (-26, 0, 0), "thigh.R": (10.6, 0, 32.2), "shin.R": (43.1, 0, 0), "foot.R": (-50, 0, 0)},
    "follow": {"upper_arm.L": (-40.8, 29.4, -130.9), "forearm.L": (-89.7, 0.5, 116.8), "upper_arm.R": (-61, 8, 28), "forearm.R": (-91, 0, 0), "hand.R": (35, 183, -127),
               "thigh.L": (-45.9, 0, -29.7), "shin.L": (77.8, 0, 0), "foot.L": (-28, 0, 0), "thigh.R": (10, 0, 32.8), "shin.R": (45.6, 0, 0), "foot.R": (-50, 0, 0)},
    "lift": {"upper_arm.L": (-40.8, 39.4, -120.9), "forearm.L": (-92.4, -7.1, 108.9), "upper_arm.R": (-41, 14, 29), "forearm.R": (-90, 0, 0), "hand.R": (-8, 166, -142),
             "thigh.L": (-40, 0, -26.6), "shin.L": (61.6, 0, 0), "foot.L": (-18, 0, 0), "thigh.R": (15, 0, 29.4), "shin.R": (26.2, 0, 0), "foot.R": (-38, 0, 0)},
    "recover": {"upper_arm.L": (4.2, 36.9, -49), "forearm.L": (-74.1, -17, 45.7), "upper_arm.R": (-24, 2, 20), "forearm.R": (-65, 0, 0), "hand.R": (-86, 149, -176),
                "thigh.L": (-20, 0, -22.5), "shin.L": (11.9, 0, 0), "foot.L": (10, 0, 0), "thigh.R": (19.7, 0, 25), "shin.R": (0, 0, 0), "foot.R": (-18, 0, 0)},
}


def _ghar_key(name):
    return dict(GHAR_TORSO[name], **{"hand.L": (0, 0, 0)}, **GHAR_SOLVED.get(name, {}))


def _ghar_guard_pose(ph):
    """Respiração/escora: o tronco sobe e desce 1-2 graus e o braço do escudo desfaz o giro (o escudo fica fincado);
    o machado balança atrás da borda."""
    s, s2 = math.sin(ph), math.sin(ph + 0.9)
    g = _ghar_key("guard")
    p = dict(g)
    p["spine"] = ck._add(g["spine"], (1.0 * s, 0, 0))
    p["chest"] = ck._add(g["chest"], (1.4 * s2, 0, 0))
    p["head"] = ck._add(g["head"], (-1.2 * s2, 1.5 * s, 0))
    if "upper_arm.L" in g:
        p["upper_arm.L"] = ck._add(g["upper_arm.L"], (-(1.0 * s + 1.4 * s2), 0, 0))
        p["upper_arm.R"] = ck._add(g["upper_arm.R"], (2.5 * s2, 0, 1.5 * s))
        p["forearm.R"] = ck._add(g["forearm.R"], (-3.0 * math.sin(ph + 1.5), 0, 0))
    return p, GHAR_GUARD_HIPS


def ghar_counter_keys():
    """[(quadro, nome, pose, quadril)] do contragolpe: guarda -> recolhe -> pancada de escudo -> machado no chão (o escudo abre para a esquerda) -> ergue -> volta à guarda do kit."""
    return [(1, "guard", _ghar_guard_pose(0.0)[0], GHAR_GUARD_HIPS),
            (4, "coil", _ghar_key("coil"), (0.0, -0.1, -0.06)),
            (7, "bash", _ghar_key("bash"), (0.0, -0.06, 0.05)),
            (8, "swing1", _ghar_key("swing1"), (0.0, -0.07, 0.05)),
            (9, "swing2", _ghar_key("swing2"), (0.0, -0.08, 0.05)),
            (GHAR_COUNTER_IMPACT, "chop", _ghar_key("chop"), (0.0, -0.09, 0.05)),
            (13, "follow", _ghar_key("follow"), (0.0, -0.095, 0.05)),
            (16, "lift", _ghar_key("lift"), (0.0, -0.07, 0.04)),
            (20, "recover", _ghar_key("recover"), (0.0, -0.03, 0.015)),
            (23, "ready", dict(ck.READY), (0.0, 0.0, 0.0))]


# Machado do Ghar (axe_kit): duplo com a lâmina de trás menor e espigão, cinta vermelha da Horda. As medidas seguem o machado
# antigo (cabeça a 0,66 m da mão, fio a 0,44 m do cabo): as poses da Muralha (GHAR_SOLVED) foram resolvidas com elas.
GHAR_AXE = {"head": "double", "back_scale": 0.7, "spike": True, "S": 1.15, "shaft": 0.72, "butt": 0.14,
            "colors": {"tint2": (0.62, 0.1, 0.08), "trim": (0.2, 0.2, 0.24)}}


def ghar_wall_clips(rig):
    """guard_wall + wall_counter no rig do Ghar (depois de mob_clips: os clipes do kit ficam como estão)."""
    ck._cycle(rig, "guard_wall", 28, _ghar_guard_pose, step=2)
    ck._pose_action(rig, "wall_counter", [(f, p, h) for f, _n, p, h in ghar_counter_keys()], 23, base={})
    # a lâmina nova (axe_kit) é ~3 cm mais alta que a antiga: no golpe a ponta de baixo roçava o chão
    return clear_ground(rig, {"wall_counter": 0.0}, "hand.R", ("wpn_main_",))


# ---------------------------------------------------------------------------
# Forma de Lich (Necromante ascendido, nível 45)
# ---------------------------------------------------------------------------
def lich_parts(base, mats):
    """Capuz fundo com coroa de lascas de gelo flutuando, costelas à mostra com o filactério aceso no peito,
    caveiras nos ombros com chama espectral e manto em tiras. Cor: azul-gelo (tema "ice" da forma)."""
    rig, b = base["rig"], base["b"]
    c, r = V(base["head_c"]), b["head"]
    zc, zw = ck.Z["chest"], ck.Z["waist"]
    back, front = b["chest"] * b["depth"], -b["chest"] * b["depth"]
    sw = b["chest"]
    hood = ck.mat("m_lichf_hood", (0.1, 0.14, 0.24), 0.85)
    trim = ck.mat("m_lichf_trim", (0.35, 0.6, 0.8), 0.5)
    bone = ck.mat("m_lichf_bone", (0.9, 0.9, 0.84), 0.6)
    ice = ck.mat("m_lichf_ice", (0.7, 0.92, 1.0), 0.15, 0.9)
    glow = ck.mat("m_lichf_glow", (0.45, 0.9, 1.0), 0.3, 2.6)
    dark = ck.mat("m_lichf_dark", (0.05, 0.06, 0.1), 0.8)
    head, body, hips = [], [], []
    # capuz: casca recuada (o rosto de caveira fica à mostra) e ponta caída para trás
    head.append(ck.ball("lichf_hood", r * 1.17, c + V((0, r * 0.2, r * 0.12)), hood, (1.0, 1.05, 1.0)))
    head.append(ck.tube("lichf_hoodtip", c + V((0, r * 0.7, r * 0.85)), c + V((0, r * 1.5, r * 0.35)), r * 0.5, r * 0.06, hood, 8))
    for sx in (-1, 1):                          # órbitas escuras atrás dos olhos acesos e maçãs do rosto
        head.append(ck.ball("lichf_socket%d" % sx, r * 0.26, c + V((sx * 0.13, -r * 0.8, -0.04)), dark, (1.0, 0.5, 1.2)))
    for i in range(5):                          # dentes
        head.append(ck.ball("lichf_tooth%d" % i, r * 0.07, c + V(((i - 2) * r * 0.13, -r * (0.86 - 0.02 * abs(i - 2)), -r * 0.52)), bone, (0.8, 0.6, 1.3)))
    n = 8                                       # coroa de lascas de gelo flutuando acima do capuz
    for i in range(n):
        a = math.tau * i / n + 0.2
        root = c + V((math.cos(a) * r * 0.78, r * 0.2 + math.sin(a) * r * 0.78, r * (1.32 + 0.06 * (i % 2))))
        tall = r * (1.0 if i % 2 == 0 else 0.62)
        head.append(ck.blade("lichf_shard%d" % i, root + V((0, 0, -tall * 0.35)), root + V((math.cos(a) * r * 0.2, math.sin(a) * r * 0.2, tall)), r * 0.26, r * 0.08, ice, (-math.sin(a), math.cos(a), 0), 0.3))
    head.append(ck.tube("lichf_halo", c + V((0, r * 0.2, r * 1.3)), c + V((0, r * 0.2, r * 1.36)), r * 0.8, r * 0.8, glow, 18))
    # peito: costelas sobre o fundo escuro e o filactério
    body.append(ck.ball("lichf_chestvoid", 0.15, V((0, front + 0.02, zc + 0.0)), dark, (1.0, 0.55, 1.1)))
    body.append(ck.tube("lichf_sternum", V((0, front - 0.065, zc + 0.13)), V((0, front - 0.065, zc - 0.13)), 0.022, 0.018, bone, 5))
    for k in range(3):
        z = zc + 0.1 - k * 0.085
        for sx in (-1, 1):
            body.append(ck.tube("lichf_rib%d_%d" % (k, sx), V((sx * 0.015, front - 0.065, z)), V((sx * sw * (0.82 - 0.08 * k), front * 0.55, z - 0.035)), 0.022, 0.014, bone, 5))
    body.append(ck.ball("lichf_phylactery", 0.065, V((0, front - 0.035, zc - 0.01)), glow))
    for sx in (-1, 1):                          # ombreira de caveira com chama espectral
        sp = V((sx * (sw + 0.08), 0.0, zc + 0.18))
        body.append(ck.ball("lichf_shskull%d" % sx, 0.13, sp, bone, (1.05, 1.0, 0.92)))
        body.append(ck.ball("lichf_shjaw%d" % sx, 0.08, sp + V((sx * 0.04, -0.05, -0.1)), bone, (1.0, 0.9, 0.7)))
        for e in (-1, 1):
            body.append(ck.ball("lichf_sheye%d_%d" % (sx, e), 0.032, sp + V((sx * 0.05 + e * 0.045, -0.105, 0.01)), glow))
        for k in range(3):
            body.append(ck.blade("lichf_flame%d_%d" % (sx, k), sp + V(((k - 1) * 0.05, 0.03, 0.08)), sp + V((sx * 0.04 + (k - 1) * 0.1, 0.1, 0.42 - 0.1 * abs(k - 1))), 0.11, 0.03, glow if k == 1 else ice, (1, 0, 0), 0.35))
    for i in range(5):                          # manto em tiras rasgadas, comprimentos desiguais
        x = (i - 2) * 0.13
        ln = (0.06, 0.2, 0.02, 0.24, 0.1)[i]
        body.append(ck.blade("lichf_cape%d" % i, V((x * 0.7, back + 0.03, zc + 0.17)), V((x * 1.5, back + 0.22 + 0.03 * (i % 2), ck.Z["ankle"] + ln)), 0.2, 0.03, hood, (1, 0, 0), 0.6))
    for i in range(6):                          # gola de espinhos de gelo
        a = math.pi * (0.1 + 0.8 * i / 5)
        body.append(cone("lichf_collar%d" % i, V((math.cos(a) * 0.2, back * 0.4 + math.sin(a) * 0.08, zc + 0.2)), V((math.cos(a) * 0.34, back * 0.4 + math.sin(a) * 0.2, zc + 0.46)), 0.045, ice, 5))
    hips.append(ck.tube("lichf_sash", V((0, 0, zw - 0.03)), V((0, 0, zw + 0.04)), b["waist"] * 1.25, b["waist"] * 1.25, trim, 12))
    for i in range(3):                          # correntes com amuletos na cintura
        hips.append(ck.ball("lichf_charm%d" % i, 0.04, V(((i - 1) * 0.12, -b["waist"] * b["depth"] - 0.07, zw - 0.09 - 0.03 * (i == 1))), glow if i == 1 else bone))
    _rigid(head, rig, "head")
    _rigid(body, rig, "chest")
    _rigid(hips, rig, "hips")
