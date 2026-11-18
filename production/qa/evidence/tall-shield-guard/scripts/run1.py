"""Run 1: diagnostics. What binds each tall shield (idle / run / guard) and where it touches at a close mount."""
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
    P("RUN1 kit %s %s %.0f s" % (cid, sex, time.time() - t0))
arms = {sx: st.anchor(j) for sx, j in joints.items()}
res = {"basis": basis, "joints": joints, "styles": {}}
for s in TALL:
    Lv, polys, plate = model[s]
    cid = ck.style_class(s) or "paladin"
    r = res["styles"][s] = {"alt": round(float(Lv[:, 2].max() - Lv[:, 2].min()), 3), "larg": round(float(Lv[:, 0].max() - Lv[:, 0].min()), 3)}
    now = ck._shield_mount(s)
    r["now"] = {"mount": list(now), "air": round(air_of(Lv, plate, now, joints, basis["arm_r"]), 3), "gda": st.decompose(now[3], basis),
                "minz": min_z(Lv, now, arms["male"], bodyf[(cid, "male")])}
    for tag, clips in (("all", ("idle", "run", "block_shield")), ("no_guard", ("idle", "run")), ("guard", ("block_shield",)),
                       ("idle", ("idle",)), ("run", ("run",))):
        m, txt = st.search(s, Lv, polys, plate, basis, joints, sub_frames(bodyf, clips), arms)
        r[tag] = {"mount": list(m), "air": round(air_of(Lv, plate, m, joints, basis["arm_r"]), 3), "txt": txt, "gda": st.decompose(m[3], basis)}
        P("RUN1 %-10s %-9s air %.3f %s" % (s, tag, r[tag]["air"], txt))
    close = tuple(r["no_guard"]["mount"])
    close = (close[0], close[1], close[2], tuple(close[3]))
    r["hits_close"] = hit_map(Lv, polys, close, arms["male"], bodyf[(cid, "male")])
    pts = st.arm_points(joints["male"], close)
    r["arm_model"] = {"elbow": [round(x, 3) for x in pts[0]], "wrist": [round(x, 3) for x in pts[9]]}
    P("RUN1 %-10s hits@no_guard %s arm %s" % (s, {k: (v["n"], v["x"], v["z"], v["onde"]) for k, v in r["hits_close"].items()}, r["arm_model"]))
    json.dump(res, open(os.path.join(OUT, "run1.json"), "w"), indent=1)
P("RUN1_END %.0f s" % (time.time() - t0))
