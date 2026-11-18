"""Run 3: final measurement and sheets. Options per tall shield:
  antes = shipped mount, shipped clips
  A     = guard variant (block_shield_tall), mount searched again
  A+    = guard variant + run variant (run_shield_tall), mount searched again
  B     = trimmed plate (elbow-side top corner or whole top), shipped clips, mount searched again
Same search rule as shield_mount_study.search (weights untouched)."""
import sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from tg_lib import *

OUT = st.arg("out")
EVID = st.arg("evid", OUT)
ONLY = st.arg("only").split(",") if st.arg("only") else TALL
RENDER = "--no_render" not in st.ARGS
POSES = json.load(open(os.path.join(OUT, "poses.json")))
t0 = time.time()
GA = POSES["guard"]
RA = POSES["run"]


def guard_tall(ph):
    p, hips = ck._shield_guard_pose(ph)
    s = math.sin(ph)
    p = dict(p, **{k: tuple(v) for k, v in POSES.get("guard_over", {}).items()})
    p["upper_arm.L"] = (GA[0] + 2 * s, GA[1], GA[2])
    p["forearm.L"] = ck._rolled((GA[3], 0, 0), GA[4])
    return p, hips


def run_tall(ph):
    p, hips = ck._run_pose(ph)
    s, c = math.sin(ph), math.cos(ph)
    p = dict(p)
    p["upper_arm.L"] = (-RA[0] * s + RA[1], RA[2], RA[3])
    p["forearm.L"] = (RA[4] - 16.0 * RA[0] / 46.0 * c, 0, 0)
    return p, hips


def sstep(t):
    t = max(0.0, min(1.0, t))
    return t * t * (3 - 2 * t)


def make_trim(mode, k, xe, drop):
    """Model space (x along the forearm, + = elbow side; z up the plate; the arm line is z = drop).
    canto: pulls the elbow-side top corner towards the elbow; topo: lowers everything above the arm."""
    za = drop + 0.09
    xc = xe + 0.06

    def canto(co):
        x, z = co.x, co.z
        if x > xc:
            co.x = xc + (x - xc) * (1 - (1 - k) * sstep((z - (drop - 0.10)) / 0.15))
        if z > za:
            co.z = za + (z - za) * (1 - (1 - k) * sstep((x - (xe - 0.10)) / 0.15))
        return co

    def topo(co):
        if co.z > za:
            co.z = za + (co.z - za) * k
        return co

    return canto if mode == "canto" else topo


TRIMS = [("canto", 0.7), ("canto", 0.4), ("canto", 0.15), ("topo", 0.7), ("topo", 0.4), ("topo", 0.15)]


def area_of(Lv, plate, step=0.01):
    tree = BVHTree.FromPolygons(Lv.tolist(), plate)
    x0, x1, z0, z1 = Lv[:, 0].min(), Lv[:, 0].max(), Lv[:, 2].min(), Lv[:, 2].max()
    nhit = 0
    for i in range(int((x1 - x0) / step) + 1):
        for j in range(int((z1 - z0) / step) + 1):
            nhit += tree.ray_cast(Vector((x0 + i * step, 2.0, z0 + j * step)), Vector((0, -1, 0)))[0] is not None
    return nhit * step * step


FRAMES = st.DENSE + (("block_shield_tall", (1, 9, 17, 25)), ("run_shield_tall", (1, 3, 5, 7, 9, 11, 13, 15)))
SETS = {"antes": ("idle", "run", "block_shield"), "A": ("idle", "run", "block_shield_tall"), "A+": ("idle", "run_shield_tall", "block_shield_tall"),
        "B": ("idle", "run", "block_shield")}
model, trimmed, bodyf, joints, shipped_arm = {}, {}, {}, {}, {}
basis = None
data = {"poses": POSES, "kits": {}, "styles": {}}


def prep(cid, sex, out_dir=None):
    base = ck.build_kit(sex, out_dir, cid)
    rig = base["rig"]
    ck._cycle(rig, "block_shield_tall", 32, guard_tall, step=4)
    ck._cycle(rig, "run_shield_tall", 16, run_tall, step=1)
    return base, rig, sm._actions(rig)


for cid, sex in KITS:
    first = basis is None
    base, rig, act = prep(cid, sex, os.path.join(OUT, "kit_base") if first else None)
    joints[sex] = {k: tuple(v) for k, v in base["j"].items()}
    if first:
        basis = make_basis(base, rig, act)
        p1 = os.path.join(OUT, "kit_base", "kit_paladin_male.glb")
        p2 = os.path.join(OUT, "kit_paladin_male_2clips.glb")
        ck.export_glb(rig, p2)
        data["kits"] = {"glb_base": os.path.getsize(p1), "glb_2clips": os.path.getsize(p2),
                        "meshes": sum(1 for o in bpy.context.scene.objects if o.type == "MESH")}
        P("RUN3 kit size base %d  +2 clips %d  (+%d bytes)" % (data["kits"]["glb_base"], data["kits"]["glb_2clips"], data["kits"]["glb_2clips"] - data["kits"]["glb_base"]))
    bodyf[(cid, sex)] = st.body_frames(rig, act, sm._body(), st.set_objs(cid), FRAMES)
    if sex == "male":
        arm = ck._shield_anchor(base)[0]
        for s in ONLY:
            if s in model or not in_kit(s, cid):
                continue
            now = ck._shield_mount(s)
            o = make_shield(base, s, "tg0_" + s)
            model[s] = st.local_model(o, now, arm)
            pts = st.arm_points(joints["male"], now)
            shipped_arm[s] = (float(pts[0].x), float(pts[0].z))          # elbow x, arm line z (= drop)
            for mode, k in TRIMS:
                o = make_shield(base, s, "tgt_%s_%s_%d" % (s, mode, k * 100), trim=make_trim(mode, k, *shipped_arm[s]))
                trimmed[(s, mode, k)] = st.local_model(o, now, arm)
    P("RUN3 kit %s %s %.0f s" % (cid, sex, time.time() - t0))
arms = {sx: st.anchor(j) for sx, j in joints.items()}
data["basis"] = basis


def tup(m):
    return (m[0], m[1], m[2], tuple(m[3]))


def report(s, Lv, polys, plate, mount, clips, plate_v=None):
    d = st.describe(s, Lv, polys, plate, mount, joints, basis, sub_frames(bodyf, clips), arms, plate_v=plate_v)
    cid = ck.style_class(s) or "paladin"
    d["minz"] = min_z(Lv, mount, arms["male"], sub_frames(bodyf, clips)[(cid, "male")])
    d.pop("onde", None)
    return d


for s in ONLY:
    Lv, polys, plate = model[s]
    r = data["styles"][s] = {"alt": round(float(Lv[:, 2].max() - Lv[:, 2].min()), 3), "larg": round(float(Lv[:, 0].max() - Lv[:, 0].min()), 3),
                             "area": round(area_of(Lv, plate), 4), "arm": shipped_arm[s]}
    now = ck._shield_mount(s)
    r["antes"] = report(s, Lv, polys, plate, now, SETS["antes"])
    m, txt = st.search(s, Lv, polys, plate, basis, joints, sub_frames(bodyf, SETS["antes"]), arms)
    r["controle"] = dict(report(s, Lv, polys, plate, m, SETS["antes"]), busca=txt)
    for tag in ("A", "A+"):
        m, txt = st.search(s, Lv, polys, plate, basis, joints, sub_frames(bodyf, SETS[tag]), arms)
        r[tag] = dict(report(s, Lv, polys, plate, m, SETS[tag]), busca=txt)
        P("RUN3 %-10s %-3s ar %.3f (antes %.3f, controle %.3f) %s" % (s, tag, r[tag]["ar"], r["antes"]["ar"], r["controle"]["ar"], txt))
    r["trims"] = []
    for mode, k in TRIMS:
        tLv, tpolys, tplate = trimmed[(s, mode, k)]
        m, txt = st.search(s, tLv, tpolys, tplate, basis, joints, sub_frames(bodyf, SETS["B"]), arms)
        e = {"mode": mode, "k": k, "mount": [m[0], m[1], m[2], list(m[3])], "ar": round(air_of(tLv, tplate, m, joints, basis["arm_r"]), 3), "busca": txt,
             "area": round(area_of(tLv, tplate), 4), "alt": round(float(tLv[:, 2].max() - tLv[:, 2].min()), 3),
             "larg": round(float(tLv[:, 0].max() - tLv[:, 0].min()), 3)}
        e["perda"] = round(1 - e["area"] / r["area"], 3)
        r["trims"].append(e)
        P("RUN3 %-10s B %-5s %.2f ar %.3f perda %.0f%% alt %.2f larg %.2f %s" % (s, mode, k, e["ar"], 100 * e["perda"], e["alt"], e["larg"], txt))
    # B escolhido: o corte mais leve que chega a rente (<= 0.06); sem isso, o de menor ar (empate: menor perda)
    ok = sorted((e for e in r["trims"] if e["ar"] <= 0.06), key=lambda e: e["perda"])
    pick = ok[0] if ok else sorted(r["trims"], key=lambda e: (e["ar"], e["perda"]))[0]
    tLv, tpolys, tplate = trimmed[(s, pick["mode"], pick["k"])]
    r["B"] = dict(report(s, tLv, tpolys, tplate, tup(pick["mount"]), SETS["B"]), busca=pick["busca"], mode=pick["mode"], k=pick["k"], perda=pick["perda"],
                  alt=pick["alt"], larg=pick["larg"])
    P("RUN3 %-10s B escolhido %s %.2f ar %.3f perda %.0f%%" % (s, pick["mode"], pick["k"], r["B"]["ar"], 100 * pick["perda"]))
    json.dump(data, open(os.path.join(OUT, "run3.json"), "w"), indent=1)
P("RUN3 medidas %.0f s" % (time.time() - t0))

# ---- fotos --------------------------------------------------------------------------------------------------------
VARS = ("antes", "A", "A+", "B")
VIEWS = (("guarda_frente", "G", 9), ("guarda_lado", "G", 9), ("guarda_jogo", "G", 9), ("corrida_lado", "R", 5), ("corrida_jogo", "R", 5), ("idle_jogo", "I", 1))
CLIP = {("G", "antes"): "block_shield", ("G", "B"): "block_shield", ("G", "A"): "block_shield_tall", ("G", "A+"): "block_shield_tall",
        ("R", "antes"): "run", ("R", "B"): "run", ("R", "A"): "run", ("R", "A+"): "run_shield_tall"}


def render_kit(cid, styles, cells):
    base, rig, act = prep(cid, "male")
    objs = {}
    for s in styles:
        r = data["styles"][s]
        objs[(s, "antes")] = bpy.data.objects["wpn_off_shield_" + s]
        for tag in ("A", "A+"):
            objs[(s, tag)] = make_shield(base, s, "tg%s_%s" % (tag.replace("+", "p"), s), mount=tup(r[tag]["mount"]), strap=True)
        objs[(s, "B")] = make_shield(base, s, "tgB_" + s, mount=tup(r["B"]["mount"]), strap=True,
                                     trim=make_trim(r["B"]["mode"], r["B"]["k"], *r["arm"]))
    cam, txt = st.render_setup()
    sc = bpy.context.scene
    st.paint(True)
    os.makedirs(cells, exist_ok=True)
    for o in sc.objects:
        if o.type == "MESH":
            o.hide_render = o.name not in st.SHOW
    for view, kind, fr in VIEWS:
        st.aim(cam, view)
        for v in VARS:
            st.set_clip(rig, act, CLIP.get((kind, v), "idle"), fr)
            for s in styles:
                o = objs[(s, v)]
                o.hide_render = False
                txt.data.body = "%s\n%s %s\nar %.3f" % (s, v.upper(), view.replace("_", " "), data["styles"][s][v]["ar"])
                sc.render.filepath = os.path.join(cells, "%s_%s_%s.png" % (s, v.replace("+", "p"), view))
                bpy.ops.render.render(write_still=True)
                o.hide_render = True
    st.paint(False)


def sheets(styles, cells, evid, name, views, rows=6):
    os.makedirs(evid, exist_ok=True)
    cols = [(vw, v) for vw in views for v in VARS]
    cw, chh = st.CELL
    for page in range(0, len(styles), rows):
        chunk = styles[page:page + rows]
        sheet = np.ones((len(chunk) * chh, len(cols) * cw, 4), dtype=np.float32)
        for ri, s in enumerate(chunk):
            for c, (vw, v) in enumerate(cols):
                p = os.path.join(cells, "%s_%s_%s.png" % (s, v.replace("+", "p"), vw))
                if os.path.exists(p):
                    y0 = (len(chunk) - 1 - ri) * chh
                    sheet[y0:y0 + chh, c * cw:(c + 1) * cw] = st.load_px(p)
        img = bpy.data.images.new("sheet", sheet.shape[1], sheet.shape[0], alpha=False)
        img.pixels.foreach_set(sheet.ravel())
        path = os.path.join(evid, "%s_%02d.png" % (name, page // rows + 1))
        img.filepath_raw = path
        img.file_format = "PNG"
        img.save()
        bpy.data.images.remove(img)
        P("RUN3 folha", path, chunk)


if RENDER:
    cells = os.path.join(OUT, "cells")
    for cid in ("paladin", "bishop"):
        mine = [s for s in ONLY if (ck.style_class(s) or "paladin") == cid]
        if mine:
            render_kit(cid, mine, cells)
            P("RUN3 fotos %s %.0f s" % (cid, time.time() - t0))
    sheets(ONLY, cells, EVID, "guarda", ("guarda_frente", "guarda_lado", "guarda_jogo"))
    sheets(ONLY, cells, EVID, "corrida_idle", ("corrida_lado", "corrida_jogo", "idle_jogo"))
P("RUN3_END %.0f s" % (time.time() - t0))
