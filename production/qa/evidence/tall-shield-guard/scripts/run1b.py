"""Run 1b: at the shipped drop/along with the plate touching the arm (+0 / +0.06), what touches what, per clip."""
import sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from tg_lib import *

OUT = st.arg("out")
t0 = time.time()
model, bodyf, joints = {}, {}, {}
basis = None
for cid, sex in KITS:
    base = ck.build_kit(sex, None, cid)
    rig = base["rig"]
    act = sm._actions(rig)
    joints[sex] = {k: tuple(v) for k, v in base["j"].items()}
    if basis is None:
        basis = make_basis(base, rig, act)
    bodyf[(cid, sex)] = st.body_frames(rig, act, sm._body(), st.set_objs(cid))
    if sex == "male":
        arm = ck._shield_anchor(base)[0]
        for s in TALL:
            if s not in model and in_kit(s, cid):
                o = make_shield(base, s, "tg0_" + s)
                model[s] = st.local_model(o, ck._shield_mount(s), arm)
    P("RUN1B kit %s %s %.0f s" % (cid, sex, time.time() - t0))
arms = {sx: st.anchor(j) for sx, j in joints.items()}
n, d_, a_ = (np.array(basis[k]) for k in ("n", "d", "a"))
res = {}
for s in TALL:
    Lv, polys, plate = model[s]
    cid = ck.style_class(s) or "paladin"
    now = ck._shield_mount(s)
    g, dr, al = st.decompose(now[3], basis)
    air = air_of(Lv, plate, now, joints, basis["arm_r"])
    res[s] = {}
    for extra in (0.0, 0.06):
        gap = g - air + st.STRAP + extra
        mount = (now[0], now[1], now[2], tuple(float(x) for x in gap * n + dr * d_ + al * a_))
        row = {}
        for (kc, sex), frames in st.frames_for(s, bodyf):
            for (anim, fr), bf in frames.items():
                tree = BVHTree.FromPolygons(st.place(Lv, mount, arms[sex], bf[1]).tolist(), polys)
                where = {}
                b, h, c, _a = st.hits_of(tree, bf, where)
                k = "%s_%s" % (anim, sex)
                e = row.setdefault(k, {"corpo": 0, "elmo": 0, "conj": 0, "onde": {}})
                e["corpo"] = max(e["corpo"], b)
                e["elmo"] = max(e["elmo"], h)
                e["conj"] = max(e["conj"], c)
                for o, v in where.items():
                    e["onde"][o] = max(e["onde"].get(o, 0), v)
        hm = hit_map(Lv, polys, mount, arms["male"], bodyf[(cid, "male")])
        res[s]["%.2f" % extra] = {"rows": row, "hm": hm}
        for k in sorted(row):
            e = row[k]
            top = sorted(e["onde"].items(), key=lambda kv: -kv[1])[:4]
            P("RUN1B %-10s +%.2f %-20s corpo %4d elmo %4d conj %4d %s" % (s, extra, k, e["corpo"], e["elmo"], e["conj"], top))
        P("RUN1B %-10s +%.2f HM %s" % (s, extra, {k: (v["n"], v["x"], v["z"], v["onde"]) for k, v in hm.items()}))
    pts = st.arm_points(joints["male"], now)
    P("RUN1B %-10s arm z %.2f x %.2f..%.2f  model x %.2f..%.2f z %.2f..%.2f" % (s, pts[0][2], pts[9][0], pts[0][0], Lv[:, 0].min(), Lv[:, 0].max(), Lv[:, 2].min(), Lv[:, 2].max()))
json.dump(res, open(os.path.join(OUT, "run1b.json"), "w"), indent=1)
P("RUN1B_END %.0f s" % (time.time() - t0))
