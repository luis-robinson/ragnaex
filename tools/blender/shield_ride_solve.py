"""Guarda montada dos escudos altos (clipe block_ride_tall): procura o braço do escudo que não atravessa a montaria.

  blender -b --factory-startup --python tools/blender/shield_ride_solve.py -- solve [--mount=mob_horse,mob_dire_wolf_mount] [--scan=6000] [--keep=40] [--why]
      procura upper_arm.L / forearm.L (o resto é ck._shield_ride_tall_pose) e imprime os melhores: face o mais para a
      frente possível, placa de pé, sem cruzar o cavalo (idle e galope) nem o corpo do cavaleiro, nos 17 escudos altos
  blender -b --factory-startup --python tools/blender/shield_ride_solve.py -- check [--mount=mob_dire_wolf_mount] [--old]
      confere a pose gravada em ck.SHIELD_RIDE_TALL (ou, com --old, a guarda antiga: block_shield_tall + GUARD_DELTA)

O cavaleiro fica na origem e a montaria é trazida para o espaço dele, quadro a quadro (o boneco acompanha o osso "body" da
montaria, como EntityView._ride_saddle). Números em metros; "folga" = distância do escudo à montaria.
"""
import sys, math, itertools
import bpy
import numpy as np
from mathutils import Vector, Matrix, Euler
from mathutils.bvhtree import BVHTree
R = __file__.replace("\\", "/").rsplit("tools/", 1)[0]
sys.path.append(R + "tools/blender")
import chibi_kit as ck
import shield_kit
import shield_mount as sm

ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
OPT = {a.split("=")[0]: a.split("=")[1] for a in ARGS if a.startswith("--") and "=" in a}
MOUNT = OPT.get("--mount", "mob_horse")
MOUNT_SCALE = 1.75          # EntityView.HORSE_SCALE
SADDLE_Y = 1.06             # EntityView.SADDLE_Y
RIDE_LEGS = {"thigh.L": (-40, 0, -75), "thigh.R": (-40, 0, 75), "shin.L": (30, 0, 50), "shin.R": (30, 0, -50),
             "foot.L": (-10, 0, 0), "foot.R": (-10, 0, 0)}      # pernas abertas na sela (RidePose.POSE; aqui .L abre com -Z)
GUARD_DELTA = {"upper_arm.L": (-34, 0, -16), "forearm.L": (14, 0, 0), "spine": (-9, 0, 0)}     # a guarda montada comum (RidePose)
HARD = ("escama", "pal_g25", "pal_g30", "presa", "suspiros", "asa_negra", "perdao", "pal_t30")     # os que mais pegam: filtram a busca
MIN_GAP = 0.03


def load_mount():
    """Todas as montarias de --mount (a,b): [BVH no espaço do cavaleiro por quadro], rótulos."""
    trees, labels = [], []
    for m in MOUNT.split(","):
        t, lb = load_one(m)
        trees += t
        labels += lb
    return trees, labels


def load_one(mount):
    """Importa a montaria, escala e devolve [BVH no espaço do cavaleiro por quadro (idle e galope)], rótulos."""
    before, acts0 = set(bpy.data.objects), set(bpy.data.actions)
    bpy.ops.import_scene.gltf(filepath=R + "assets/models/%s.glb" % mount)
    new = [o for o in bpy.data.objects if o not in before]
    for o in new:
        if o.parent is None:
            o.matrix_world = Matrix.Scale(MOUNT_SCALE, 4) @ o.matrix_world
    hrig = next(o for o in new if o.type == "ARMATURE")
    meshes = [o for o in new if o.type == "MESH" and o.parent is not None]      # sem pai = esfera de osso do importador
    acts = {a.name.split(".")[0].split("_")[0]: a for a in bpy.data.actions if a not in acts0}
    if hrig.animation_data is None:
        hrig.animation_data_create()
    for t in hrig.animation_data.nla_tracks:
        t.mute = True
    trees, labels = [], []
    body = hrig.pose.bones["body"]
    for clip, n in (("idle", 3), ("run", 6)):
        a = acts.get(clip)
        if a is None:
            print("RIDE montaria sem clipe", clip, sorted(acts))
            continue
        f0, f1 = a.frame_range
        for k in range(n):
            fr = int(round(f0 + (f1 - f0) * k / n))
            sm.set_clip(hrig, {clip: a}, clip, fr)
            dg = bpy.context.evaluated_depsgraph_get()
            d = hrig.matrix_world @ (body.matrix @ body.bone.matrix_local.inverted()) @ hrig.matrix_world.inverted()
            inv = (d @ Matrix.Translation((0, 0, SADDLE_Y))).inverted()
            vs, polys = [], []
            for o in meshes:
                e = o.evaluated_get(dg)
                me = e.to_mesh()
                base = len(vs)
                vs.extend(inv @ (e.matrix_world @ v.co) for v in me.vertices)
                polys.extend(tuple(base + i for i in p.vertices) for p in me.polygons)
                e.to_mesh_clear()
            trees.append(BVHTree.FromPolygons(vs, polys))
            labels.append("%s %s%d" % (mount, clip, fr))
    neck = hrig.pose.bones.get("neck") or hrig.pose.bones.get("head")
    print("RIDE montaria %s: frente em y=%.2f (esperado negativo), %d quadros, clipes %s" % (
        mount, (hrig.matrix_world @ neck.head).y - (hrig.matrix_world @ body.head).y if neck else 0.0, len(trees), sorted(acts)))
    return trees, labels


class Rider:
    def __init__(self, sex="male", cid="paladin"):
        self.base = ck.build_kit(sex, None, cid)
        self.rig = self.base["rig"]
        self.act = sm._actions(self.rig)
        self.rig.animation_data.action = None
        self.pbs = self.rig.pose.bones
        self.shields = {}
        for st in shield_kit.TALL:
            o = bpy.data.objects.get("wpn_off_shield_" + st)
            if o:
                self.shields[st] = (o, [v.co.copy() for v in o.data.vertices], [tuple(p.vertices) for p in o.data.polygons])
        self.body = sm._body()

    def pose(self, pose):
        for bn in ck.POSE_BONES:
            pb = self.pbs.get(bn)
            if pb:
                pb.rotation_mode = "XYZ"
                pb.rotation_euler = [math.radians(a) for a in pose.get(bn, (0, 0, 0))]
        for bn, e in RIDE_LEGS.items():          # Godot: Quaternion.from_euler (YXZ) = modo ZXY do Blender
            self.pbs[bn].rotation_mode = "ZXY"
            self.pbs[bn].rotation_euler = [math.radians(a) for a in e]
        self.pbs["hips"].location = (0, 0, 0)
        bpy.context.view_layer.update()

    def arm(self, ua, fa):
        """Delta do antebraço (pose x repouso^-1) para o braço dado, por cinemática direta (sem atualizar a cena)."""
        u, f = self.pbs["upper_arm.L"], self.pbs["forearm.L"]
        mu = self._par @ (u.parent.bone.matrix_local.inverted() @ u.bone.matrix_local) @ Euler([math.radians(a) for a in ua], "XYZ").to_matrix().to_4x4()
        mf = mu @ (u.bone.matrix_local.inverted() @ f.bone.matrix_local) @ Euler([math.radians(a) for a in fa], "XYZ").to_matrix().to_4x4()
        return mf @ f.bone.matrix_local.inverted()

    def ready(self, pose):
        self.pose(pose)
        self._par = self.pbs["upper_arm.L"].parent.matrix.copy()
        d = self.arm(pose["upper_arm.L"], pose["forearm.L"])
        err = max(abs(a - b) for ra, rb in zip(d, sm._bone_delta(self.rig, "forearm.L")) for a, b in zip(ra, rb))
        assert err < 1e-3, "cinemática direta difere da cena: %g" % err

    def clear(self, d, trees, styles):
        """(cruzamentos com a montaria, menor folga) dos escudos `styles` com o antebraço em d, no pior quadro."""
        hits, gap = 0, 9.0
        for st in styles:
            _o, vs, polys = self.shields[st]
            pts = [d @ v for v in vs]
            t = BVHTree.FromPolygons(pts, polys)
            for ht in trees:
                hits += len(t.overlap(ht))
                if hits:
                    return hits, 0.0
                for p in pts[::3]:
                    near = ht.find_nearest(p, gap)
                    if near[0] is not None:
                        gap = min(gap, near[3])
        return hits, gap

    def touches(self, pose):
        """Toques de cada escudo alto no corpo do cavaleiro (fora do braço esquerdo), com a pose inteira na cena."""
        self.pose(pose)
        out = {}
        for st, (o, _v, _p) in self.shields.items():
            h = sm.contacts(self.rig, self.body, o)
            if h:
                out[st] = h
        sm.WHERE.clear()
        return out


def face_of(rider, d):
    rot = ck._shield_rot("suspiros").to_3x3()
    n = (d.to_3x3() @ (rot @ Vector((0, -1, 0)))).normalized()
    u = (d.to_3x3() @ (rot @ Vector((0, 0, 1)))).normalized()
    return n, u


def old_pose():
    """A guarda montada antiga: block_shield_tall com o GUARD_DELTA somado (aproximação em Euler XYZ do giro do Godot)."""
    p, _h = ck._shield_guard_tall_pose(0.0)
    p = dict(p)
    for bn, dlt in GUARD_DELTA.items():
        q = Euler([math.radians(a) for a in p.get(bn, (0, 0, 0))], "XYZ").to_quaternion()
        dq = Euler([math.radians(a) for a in dlt], "XYZ").to_quaternion()      # giro no eixo do osso em repouso = antes da pose
        p[bn] = tuple(math.degrees(a) for a in (dq @ q).to_euler("XYZ"))
    return p


def report(rider, trees, labels, pose, tag):
    rider.ready(pose)
    d = rider.arm(pose["upper_arm.L"], pose["forearm.L"])
    n, u = face_of(rider, d)
    worst_gap, crossing = 9.0, {}
    for st in rider.shields:
        per = 0
        for ht, lb in zip(trees, labels):
            h, g = rider.clear(d, [ht], [st])
            per += h
            worst_gap = min(worst_gap, g)
        if per:
            crossing[st] = per
    touch = rider.touches(pose)
    print("RIDE %s face=(%.2f, %.2f, %.2f) topo_z=%.2f cruzam a montaria=%d %s folga=%.3f toques no corpo=%s" % (
        tag, n.x, n.y, n.z, u.z, len(crossing), crossing, worst_gap if not crossing else 0.0, touch or 0), flush=True)
    return len(crossing), touch


def solve():
    trees, labels = load_mount()
    rider = Rider()
    base, _h = ck._shield_ride_tall_pose(0.0)
    rider.ready(base)
    rng = lambda a, b, s: [a + i * s for i in range(int(round((b - a) / s)) + 1)]
    cands = []
    for ux, uy, uz in itertools.product(rng(-40, 5, 7.5), rng(-30, 30, 10), rng(-100, -25, 12.5)):
        for fx, roll in itertools.product(rng(-95, -35, 10), rng(-75, 15, 15)):
            ua, fa = (ux, uy, uz), ck._rolled((fx, 0, 0), roll)
            d = rider.arm(ua, fa)
            n, u = face_of(rider, d)
            if u.z < 0.78 or n.z < -0.25 or n.z > 0.5 or n.y > 0.1 or n.x < -0.2:
                continue
            cands.append((-n.y + 0.3 * u.z, ua, (fx, roll), fa, d))
    cands.sort(key=lambda c: -c[0])
    print("RIDE candidatos de pé e para a frente/lado: %d" % len(cands), flush=True)
    quick = trees[0::3] + trees[4::9]
    ok = []
    hard = [st for st in HARD if st in rider.shields]
    for i, c in enumerate(cands[:int(OPT.get("--scan", "6000"))]):
        h, g = rider.clear(c[4], quick, hard)
        if h == 0 and g >= MIN_GAP:
            ok.append((c, g))
            if len(ok) >= int(OPT.get("--keep", "40")):
                break
    print("RIDE livres da montaria (6 escudos difíceis): %d" % len(ok), flush=True)
    good = []
    for c, g in ok:
        h, g2 = rider.clear(c[4], trees, list(rider.shields))
        if h or g2 < MIN_GAP:
            bad = [st for st in rider.shields if rider.clear(c[4], trees, [st])[0]]
            if "--why" in ARGS:
                print("RIDE fora upper_arm.L=%s forearm.L=(%s, %s): cruzam %s folga=%.3f" % (c[1], c[2][0], c[2][1], bad, g2), flush=True)
            continue
        pose = dict(base, **{"upper_arm.L": c[1], "forearm.L": c[3]})
        touch = rider.touches(pose)
        n, u = face_of(rider, c[4])
        good.append((sum(touch.values()), -c[0], c, g2, touch, n, u))
        print("RIDE cand toques=%d nota=%.2f upper_arm.L=%s forearm.L=_rolled((%s, 0, 0), %s) face=(%.2f, %.2f, %.2f) topo_z=%.2f folga=%.3f %s" % (
            sum(touch.values()), c[0], c[1], c[2][0], c[2][1], n.x, n.y, n.z, u.z, g2, touch), flush=True)
    good.sort(key=lambda r: (r[0], r[1]))
    for r in good[:8]:
        c = r[2]
        print("RIDE MELHOR toques=%d nota=%.2f upper_arm.L=%s forearm.L=_rolled((%s, 0, 0), %s) folga=%.3f" % (r[0], c[0], c[1], c[2][0], c[2][1], r[3]))


def check():
    trees, labels = load_mount()
    for sex in ("male", "female"):
        rider = Rider(sex)
        if "--old" in ARGS:
            report(rider, trees, labels, old_pose(), "antiga %s" % sex)
        else:
            report(rider, trees, labels, ck._shield_ride_tall_pose(0.0)[0], "block_ride_tall %s" % sex)


if __name__ == "__main__":
    (solve if "solve" in ARGS else check)()
    print("SHIELD_RIDE_END")
