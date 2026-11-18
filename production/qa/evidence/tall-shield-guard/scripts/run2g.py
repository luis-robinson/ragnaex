"""Run 2: pose search on the male paladin kit. Guard variant and run variant of the shield arm that leave the tall
shields free at a close mount (plate 2 cm off the strap). Common body + plate helmet + every paladin set helmet."""
import sys, os, itertools
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from tg_lib import *

OUT = st.arg("out")
t0 = time.time()
base = ck.build_kit("male", None, "paladin")
rig = base["rig"]
act = sm._actions(rig)
joints = {"male": {k: tuple(v) for k, v in base["j"].items()}}
basis = make_basis(base, rig, act)
arm0 = ck._shield_anchor(base)[0]
arm = st.anchor(joints["male"])
n, d_, a_ = (np.array(basis[k]) for k in ("n", "d", "a"))
model, close = {}, {}
for s in TALL:
    if s not in shield_kit.FAMILIES:
        continue
    o = make_shield(base, s, "tg0_" + s)
    Lv, polys, plate = st.local_model(o, ck._shield_mount(s), arm0)
    now = ck._shield_mount(s)
    g, dr, al = st.decompose(now[3], basis)
    air = air_of(Lv, plate, now, joints, basis["arm_r"])
    gap = g - air + st.STRAP + 0.02
    close[s] = (now[0], now[1], now[2], tuple(float(x) for x in gap * n + dr * d_ + al * a_))
    model[s] = (Lv, polys)
body = sm._body()
heads = [o for o in st.set_objs("paladin") if "_head_" in o.name]
keep = set(o.name for o in body + heads)
for o in list(bpy.context.scene.objects):
    if o.type == "MESH" and o.name not in keep:
        bpy.data.objects.remove(o, do_unlink=True)
body = sm._body()
heads = [o for o in bpy.context.scene.objects if o.type == "MESH" and "_head_" in o.name and o.name.startswith("arm_pal")]
P("RUN2 corpo %d elmos %d escudos %d  %.0f s" % (len(body), len(heads), len(model), time.time() - t0))
rig.animation_data.action = None
pbs = rig.pose.bones
n0 = st.rot_of(ck._shield_mount("juramento")) @ Vector((0, -1, 0))
u0 = st.rot_of(ck._shield_mount("juramento")) @ Vector((0, 0, 1))


def snap(pose, hips):
    for bn in ck.POSE_BONES:
        if pbs.get(bn):
            pbs[bn].rotation_mode = "XYZ"
            pbs[bn].rotation_euler = [math.radians(a) for a in pose.get(bn, (0, 0, 0))]
    pbs["hips"].location = hips
    bpy.context.view_layer.update()
    dg = bpy.context.evaluated_depsgraph_get()
    a0 = np.array(rig.matrix_world @ pbs["upper_arm.L"].head)
    a1 = np.array(rig.matrix_world @ pbs["hand.L"].tail)
    ab = a1 - a0

    def away(pts):
        t = (pts - a0) @ ab / ab.dot(ab)
        d = np.linalg.norm(pts - (a0 + t[:, None] * ab), axis=1)
        return ~((t >= -0.05) & (t <= 1.05) & (d < 0.16))

    trees = []
    for group, members in (("corpo", body), ("elmos", heads)):
        allv, polys, cents, b0 = [], [], [], 0
        for o in members:
            e = o.evaluated_get(dg)
            me = e.to_mesh()
            nv = len(me.vertices)
            co = np.empty(nv * 3)
            me.vertices.foreach_get("co", co)
            mw = np.array(e.matrix_world)
            vs = co.reshape(-1, 3) @ mw[:3, :3].T + mw[:3, 3]
            cen = np.empty(len(me.polygons) * 3)
            me.polygons.foreach_get("center", cen)
            cents.append(cen.reshape(-1, 3) @ mw[:3, :3].T + mw[:3, 3])
            polys += [tuple(b0 + k for k in pl.vertices) for pl in me.polygons]
            allv.append(vs)
            b0 += nv
            e.to_mesh_clear()
        vs = np.concatenate(allv)
        trees.append((group, BVHTree.FromPolygons(vs.tolist(), polys), away(np.concatenate(cents))))
    D = sm._bone_delta(rig, "forearm.L")
    return trees, st.np3(D), D


def score(frames):
    """frames = [(trees, Dnp, D)]. Returns (body hits, helmet hits, lowest z, per shield)."""
    bh = hh = 0
    lo = 9.0
    per = {}
    for trees, Dn, _D in frames:
        for s, (Lv, polys) in model.items():
            pts = st.place(Lv, close[s], arm, Dn)
            lo = min(lo, float(pts[:, 2].min()))
            tree = BVHTree.FromPolygons(pts.tolist(), polys)
            for group, bt, outside in trees:
                k = sum(1 for _i, j in tree.overlap(bt) if outside[j])
                if group == "corpo":
                    bh += k
                else:
                    hh += k
                if k:
                    per[s] = per.get(s, 0) + (50 * k if group == "corpo" else k)
    return bh, hh, lo, per


def face(D):
    nn = (D.to_3x3() @ n0).normalized()
    uu = (D.to_3x3() @ u0).normalized()
    c = D @ Vector(arm)
    return (round(math.degrees(math.atan2(nn.x, -nn.y))), round(math.degrees(math.asin(max(-1, min(1, nn.z))))),
            round(math.degrees(math.acos(max(-1, min(1, uu.z))))), [round(x, 2) for x in c])


res = {}
# ---- guard ------------------------------------------------------------------------------------------------------
g0, gh = ck._shield_guard_pose(0.0)
f = snap(g0, gh)
ref = score([f])
P("RUN2 GUARD base corpo %d elmo %d minz %.2f face %s per %s" % (ref[0], ref[1], ref[2], face(f[2]), ref[3]))
BASE_G = (-60, 22.5, -37.5, -67.5, -15)
rows = []
for ux, uy, uz, fx, roll in itertools.product((-75, -60, -45, -30, -15), (7.5, 22.5, 37.5, 52.5, 67.5), (-67.5, -52.5, -37.5, -22.5, -7.5), (-97.5, -82.5, -67.5, -52.5, -37.5),
                                               (-45, -30, -15, 0, 15, 30)):
    pose = dict(g0)
    pose["upper_arm.L"] = (ux, uy, uz)
    pose["forearm.L"] = ck._rolled((fx, 0, 0), roll)
    for bn in ("upper_arm.L", "forearm.L"):
        pbs[bn].rotation_euler = [math.radians(a) for a in pose[bn]]
    bpy.context.view_layer.update()
    fc = face(sm._bone_delta(rig, "forearm.L"))
    # readable guard: face to the blow (within 35 deg of forward, not looking at the floor or the sky), plate upright
    if abs(fc[0]) > 35 or not (-15 <= fc[1] <= 30) or fc[2] > 25 or fc[3][1] > -0.2:
        continue
    f = snap(pose, gh)
    sc = score([f])
    dist = sum(abs(a - b) for a, b in zip((ux, uy, uz, fx, roll), BASE_G)) / 15.0
    rows.append((50 * sc[0] + sc[1], dist, (ux, uy, uz, fx, roll), sc[0], sc[1], round(sc[2], 2), fc, sc[3]))
rows.sort(key=lambda r: (r[0], r[1]))
P("RUN2 GUARD candidatos %d  %.0f s" % (len(rows), time.time() - t0))
for r in rows[:25]:
    P("RUN2 GUARD score %5d dist %4.1f arm %s corpo %d elmo %d minz %.2f face %s" % r[:7])
res["guard"] = {"base": {"corpo": ref[0], "elmo": ref[1], "minz": ref[2], "per": ref[3]}, "rows": [list(r) for r in rows[:60]]}
json.dump(res, open(os.path.join(OUT, "run2g.json"), "w"), indent=1)
# head/torso presets on the best arms
for r in rows[:6]:
    for tag, over in (("cabeca_atras", {"head": (-12, -4, 0)}), ("tronco_ereto", {"spine": (6, -10, 0), "head": (-8, 0, 0)})):
        pose = dict(g0, **over)
        pose["upper_arm.L"] = r[2][:3]
        pose["forearm.L"] = ck._rolled((r[2][3], 0, 0), r[2][4])
        sc = score([snap(pose, gh)])
        P("RUN2 GUARD+ %s arm %s corpo %d elmo %d minz %.2f" % (tag, r[2], sc[0], sc[1], sc[2]))
for tag, over in (("cabeca_atras", {"head": (-12, -4, 0)}), ("tronco_ereto", {"spine": (6, -10, 0), "head": (-8, 0, 0)})):
    sc = score([snap(dict(g0, **over), gh)])
    P("RUN2 GUARD+ %s arm BASE corpo %d elmo %d minz %.2f" % (tag, sc[0], sc[1], sc[2]))
if '--guard_only' in st.ARGS:
    P('RUN2_END guard only')
    sys.exit(0)
# ---- run --------------------------------------------------------------------------------------------------------
PH = [math.tau * k / 8 for k in range(8)]


def run_pose(ph, A, ux0, uy, uz, f0):
    p, hips = ck._run_pose(ph)
    s, c = math.sin(ph), math.cos(ph)
    p = dict(p)
    p["upper_arm.L"] = (-A * s + ux0, uy, uz)
    p["forearm.L"] = (f0 - 16.0 * A / 46.0 * c, 0, 0)
    return p, hips


BASE_R = (46, -14, -14, 0, -62)
ref = score([snap(*run_pose(ph, *BASE_R)) for ph in PH])
P("RUN2 RUN base corpo %d elmo %d minz %.2f per %s" % ref)
rows = []
for A, ux0, uy, uz, f0 in itertools.product((46, 30, 15, 5), (-14, -26, -38, -50), (-14, 0, 14), (0, -12, -24), (-62, -48, -76)):
    fr = [snap(*run_pose(ph, A, ux0, uy, uz, f0)) for ph in PH[::2]]
    sc = score(fr)
    dist = sum(abs(a - b) for a, b in zip((A, ux0, uy, uz, f0), BASE_R)) / 15.0
    rows.append((50 * sc[0] + sc[1], dist, (A, ux0, uy, uz, f0), sc[0], sc[1], round(sc[2], 2), face(fr[0][2]), sc[3]))
rows.sort(key=lambda r: (r[0], r[1]))
P("RUN2 RUN candidatos %d  %.0f s" % (len(rows), time.time() - t0))
for r in rows[:25]:
    P("RUN2 RUN score %5d dist %4.1f arm %s corpo %d elmo %d minz %.2f face0 %s" % r[:7])
by_dist = sorted(rows, key=lambda r: r[1])
for r in by_dist[:12]:
    P("RUN2 RUN perto score %5d dist %4.1f arm %s corpo %d elmo %d minz %.2f" % r[:6])
res["run"] = {"base": {"corpo": ref[0], "elmo": ref[1], "minz": ref[2], "per": ref[3]}, "rows": [list(r) for r in rows[:60]]}
json.dump(res, open(os.path.join(OUT, "run2.json"), "w"), indent=1)
P("RUN2_END %.0f s" % (time.time() - t0))
