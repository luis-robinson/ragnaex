"""Resolve a montagem do escudo no antebraço e a pose de guarda, medindo no rig real.

  blender -b --factory-startup --python tools/blender/shield_mount.py              -> SHIELD_TURN/TILT/SPIN/OFFSET (idle)
  blender -b --factory-startup --python tools/blender/shield_mount.py -- --guard   -> braço da guarda (block_shield)
  blender -b --factory-startup --python tools/blender/shield_mount.py -- --check   -> toques fora do braço esquerdo

Montagem: no idle o antebraço atravessa as costas do escudo; escudo de pé, ponta para baixo, face para fora
(um pouco para cima, a câmera é alta), afastado GAP do osso e descido DROP na própria altura (a cabeça chibi é enorme).
O kit é montado no repouso: a pose desejada no idle volta para o repouso pela transformação do osso forearm.L.
"""
import sys, math, itertools
import bpy
from mathutils import Vector, Matrix
from mathutils.bvhtree import BVHTree
from mathutils.geometry import intersect_point_line
R = __file__.replace("\\", "/").rsplit("tools/", 1)[0]
sys.path.append(R + "tools/blender")
import chibi_kit as ck
import shield_kit

FACE = Vector((1.0, -0.2, 0.32))     # direção da face no idle (fora, frente, cima)
GAP = 0.29                            # do eixo do antebraço até o centro do escudo
DROP = 0.32                           # centro abaixo do antebraço, na altura do escudo
GUARD_FACE = Vector((0.15, -0.95, 0.25))     # guarda: face para o golpe
GUARD_CENTER = Vector((0.16, -0.46, 0.5))    # na frente do peito esquerdo, longe da cara (a cabeça chibi avança)
ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []


def _actions(rig):
    act = {t.name: t.strips[0].action for t in rig.animation_data.nla_tracks if t.strips}
    for t in rig.animation_data.nla_tracks:
        t.mute = True
    return act


def _bone_delta(rig, name):
    pb = rig.pose.bones[name]
    return (rig.matrix_world @ pb.matrix) @ (rig.matrix_world @ pb.bone.matrix_local).inverted()


def solve_mount():
    base = ck.build_kit("male")
    rig = base["rig"]
    rig.animation_data.action = _actions(rig)["idle"]
    bpy.context.scene.frame_set(1)
    D = _bone_delta(rig, "forearm.L")
    f = (rig.pose.bones["forearm.L"].matrix.to_3x3() @ Vector((0, 1, 0))).normalized()
    n = (FACE - f * FACE.dot(f)).normalized()
    U = f.cross(n).normalized()
    if U.z < 0:
        U = -U
    s = (-n).cross(U).normalized()
    e = (D.to_3x3().inverted() @ Matrix((s, -n, U)).transposed()).to_euler("YXZ")     # Rz @ Rx @ Ry
    arm = Vector(ck._shield_anchor(base)[0])
    off = D.inverted() @ (D @ arm + n * GAP - U * DROP) - arm
    print("MOUNT SHIELD_TURN = %.1f  SHIELD_TILT = %.1f  SHIELD_SPIN = %.1f  SHIELD_OFFSET = (%.3f, %.3f, %.3f)"
          % (math.degrees(e.z), math.degrees(e.x), math.degrees(e.y), off.x, off.y, off.z))


def _tree(o, dg):
    e = o.evaluated_get(dg)
    me = e.to_mesh()
    vs = [e.matrix_world @ v.co for v in me.vertices]
    return BVHTree.FromPolygons(vs, [tuple(p.vertices) for p in me.polygons]), vs, me


WHERE = {}


def contacts(rig, body, shield):
    """Toques do escudo no corpo, fora do braço esquerdo (onde ele é preso)."""
    dg = bpy.context.evaluated_depsgraph_get()
    t, _, _ = _tree(shield, dg)
    a0 = rig.matrix_world @ rig.pose.bones["upper_arm.L"].head
    a1 = rig.matrix_world @ rig.pose.bones["hand.L"].tail
    hits = 0
    for o in body:
        bt, bvs, me = _tree(o, dg)
        for _, j in t.overlap(bt):
            pc = sum((bvs[k] for k in me.polygons[j].vertices), Vector()) / len(me.polygons[j].vertices)
            q, tt = intersect_point_line(pc, a0, a1)
            if not (-0.05 <= tt <= 1.05 and (pc - q).length < 0.16):
                hits += 1
                WHERE[o.name.split("_")[-1]] = WHERE.get(o.name.split("_")[-1], 0) + 1
    return hits


def _body():
    return [o for o in bpy.context.scene.objects if o.type == "MESH" and (o.name in ("base_body", "base_head")
            or o.name.startswith(("arm_plate_body", "arm_plate_head", "arm_plate_legs")))]


def check():
    """Escudos moram nos kits das classes que os empunham (ck.SHIELD_CLASSES): confere cada um no kit dele."""
    seen = set()
    for cid in ck.SHIELD_CLASSES:
        base = ck.build_kit("male", None, cid)
        rig = base["rig"]
        act = _actions(rig)
        body = _body()
        styles = [st for st in shield_kit.FAMILIES if st not in seen and bpy.data.objects.get("wpn_off_shield_" + st)]
        seen.update(styles)
        for anim, frames in (("idle", (1, 25)), ("run", (1, 5, 9, 13)), ("block_shield", (1, 9, 17))):
            rig.animation_data.action = act[anim]
            per = {}
            for fr in frames:
                bpy.context.scene.frame_set(fr)
                for st in styles:
                    per[st] = max(per.get(st, 0), contacts(rig, body, bpy.data.objects["wpn_off_shield_" + st]))
            print("CHECK %-9s %-12s pior=%d %s onde=%s" % (cid, anim, max(per.values() or [0]), {k: v for k, v in per.items() if v}, dict(WHERE)))
            WHERE.clear()
    missing = [st for st in shield_kit.FAMILIES if st not in seen]
    print("CHECK escudos sem kit: %s" % (missing or "nenhum"))


def guard():
    """Busca upper_arm.L / forearm.L (com o resto da guarda atual) pela face e posição desejadas, sem tocar tronco/cabeça."""
    base = ck.build_kit("male")
    rig = base["rig"]
    _actions(rig)
    rig.animation_data.action = None
    pose, _ = ck._shield_guard_pose(0.0)
    pbs = rig.pose.bones
    for bn in ck.POSE_BONES:
        if pbs.get(bn):
            pbs[bn].rotation_mode = "XYZ"
            pbs[bn].rotation_euler = [math.radians(a) for a in pose.get(bn, (0, 0, 0))]
    rot = (Matrix.Rotation(math.radians(ck.SHIELD_TURN), 3, "Z") @ Matrix.Rotation(math.radians(ck.SHIELD_TILT), 3, "X")
           @ Matrix.Rotation(math.radians(ck.SHIELD_SPIN), 3, "Y"))
    n_rest, u_rest, c_rest = rot @ Vector((0, -1, 0)), rot @ Vector((0, 0, 1)), ck._shield_anchor(base)[1]
    gf = GUARD_FACE.normalized()
    res = []
    rng = lambda a, b, s: [a + i * s for i in range(int(round((b - a) / s)) + 1)]
    for ux, uy, uz in itertools.product(rng(-75, 0, 7.5), rng(0, 67.5, 7.5), rng(-67.5, 7.5, 7.5)):
        pbs["upper_arm.L"].rotation_euler = [math.radians(ux), math.radians(uy), math.radians(uz)]
        for fx, roll in itertools.product(rng(-112.5, -30, 7.5), rng(-45, 30, 7.5)):
            pbs["forearm.L"].rotation_euler = [math.radians(a) for a in ck._rolled((fx, 0, 0), roll)]
            bpy.context.view_layer.update()
            D = _bone_delta(rig, "forearm.L")
            n, u, c = (D.to_3x3() @ n_rest).normalized(), (D.to_3x3() @ u_rest).normalized(), D @ c_rest
            up = Vector((0, 0, 1))
            ud = (up - n * up.dot(n)).normalized()
            sc = math.acos(max(-1, min(1, n.dot(gf)))) + 0.6 * math.acos(max(-1, min(1, u.dot(ud)))) + 4.0 * (c - GUARD_CENTER).length
            res.append((sc, (ux, uy, uz), (fx, roll), tuple(round(x, 2) for x in n)))
    res.sort(key=lambda r: r[0])
    body = _body()
    big = [bpy.data.objects["wpn_off_shield_" + st] for st in ("juramento", "asa_negra", "suspiros")]
    found = []
    for r in res[:800]:
        pbs["upper_arm.L"].rotation_euler = [math.radians(a) for a in r[1]]
        pbs["forearm.L"].rotation_euler = [math.radians(a) for a in ck._rolled((r[2][0], 0, 0), r[2][1])]
        bpy.context.view_layer.update()
        hits = [contacts(rig, body, o) for o in big]
        found.append((hits[0] * 10 + hits[1] + hits[2], r))     # o escudo comum pesa mais que os dois gigantes
    found.sort(key=lambda h: (h[0], h[1][0]))
    for h, r in found[:6]:
        print("GUARD toques=%d score=%.3f upper_arm.L=%s forearm.L=_rolled((%s, 0, 0), %s) face=%s" % (h, r[0], r[1], r[2][0], r[2][1], r[3]))


if "--guard" in ARGS:
    guard()
elif "--check" in ARGS:
    check()
else:
    solve_mount()
print("SHIELD_MOUNT_END")
