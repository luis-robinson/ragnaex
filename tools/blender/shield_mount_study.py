"""ESTUDO (2026-11-15): montagem rente para os escudos nomeados. Não toca em assets/models nem nas regras do --check.

  blender -b --factory-startup --python tools/blender/shield_mount_study.py -- --out=<pasta de rascunho> [--evid=<pasta das folhas>]
      [--only=<estilo>,...] [--no_render] [--mounts=<json de uma rodada anterior>] [--kit_mounts] [--target_drop=0.22]

O que faz:
  1. mede a montagem atual de cada escudo (folga do antebraço até as costas da placa, quanto do antebraço fica atrás da
     placa, folga até o corpo e toques em idle/run/block_shield, com a mesma regra do shield_mount --check);
  2. procura por estilo a montagem mais rente (mesma rotação da comum; muda só o OFFSET: gap, drop, along) que não toca
     o corpo nos dois sexos;
  3. remonta os kits de paladino e bispo numa pasta de rascunho com a alça soldada na malha do escudo (0 malhas a mais;
     wpn_off_grip e wpn_off_grip_tabuas deixam de existir) e confere de novo com as funções do shield_mount;
  4. fotografa antes/depois (frente, lado, câmera do jogo; idle e guarda) e monta as folhas.
Saída: <out>/study.json, <out>/kit_<classe>_<sexo>.glb, <evid>/shields_NN.png.
"""
import sys, os, math, json, time
import bpy
import numpy as np
from mathutils import Vector, Matrix
from mathutils.bvhtree import BVHTree
from mathutils.geometry import intersect_point_line
R = __file__.replace("\\", "/").rsplit("tools/", 1)[0]
sys.path.append(R + "tools/blender")
import chibi_kit as ck
import shield_kit
import shield_mount as sm

ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []


def P(*a):
    print(*a, flush=True)


def arg(name, default=None):
    for a in ARGS:
        if a.startswith("--%s=" % name):
            return a.split("=", 1)[1]
    return default


OUT = arg("out")
EVID = arg("evid", OUT)
ONLY = arg("only").split(",") if arg("only") else None
WEAR = arg("wear").split(",") if arg("wear") else []
TARGET_DROP = float(arg("target_drop", "0.22"))
LEFT_ARM = ("upper_arm.L", "forearm.L", "hand.L")
STRAP = 0.012                    # espessura da tira entre o braço e as costas da placa
CHECK_FRAMES = (("idle", (1, 25)), ("run", (1, 5, 9, 13)), ("block_shield", (1, 9, 17)))       # iguais ao shield_mount.check
DENSE = (("block_shield", (1, 9, 17, 25)), ("idle", (1, 13, 25)), ("run", (1, 3, 5, 7, 9, 11, 13, 15)))
VIEWS = ("idle_frente", "idle_lado", "idle_jogo", "guarda_frente", "guarda_lado")
CELL = (200, 260)
ORTHO = 2.3


def set_clip(rig, act, name, frame):
    ad = rig.animation_data
    ad.action = act[name]
    try:
        if act[name].slots:
            ad.action_slot = act[name].slots[0]
    except Exception:
        pass
    bpy.context.scene.frame_set(frame)
    bpy.context.view_layer.update()


def rot_of(mount):
    turn, tilt, spin = mount[0], mount[1], mount[2]
    return (Matrix.Rotation(math.radians(turn), 3, "Z") @ Matrix.Rotation(math.radians(tilt), 3, "X")
            @ Matrix.Rotation(math.radians(spin), 3, "Y"))


def np3(m):
    return np.array([list(r) for r in m])


def shield_name(st):
    return "wpn_off_shield" if st == "_comum" else "wpn_off_shield_" + st


def style_of(st):
    return "juramento" if st == "_comum" else st


# ---------------------------------------------------------------------------
# corpo por quadro (árvores BVH guardadas: valem depois de limpar a cena)
# ---------------------------------------------------------------------------
def body_frames(rig, act, objs, sets, frames=DENSE):
    """{(clipe, quadro): ([(grupo, árvore, fora do braço por face, vértices longe do braço, é de conjunto, dono de cada face)], D)}.
    Uma árvore para o corpo comum e uma para todas as peças de conjunto (por peça a busca levava dezenas de minutos)."""
    out = {}
    sleeve = {}                       # por peça de conjunto: faces presas ao braço esquerdo (manga, cotoveleira, ombreira)
    for o in sets:
        dom = [ck.dominant_bone(o, v) in LEFT_ARM for v in o.data.vertices]
        sleeve[o.name] = np.array([sum(dom[k] for k in pl.vertices) * 2 >= len(pl.vertices) for pl in o.data.polygons], dtype=bool)
    for anim, frs in frames:
        for fr in frs:
            set_clip(rig, act, anim, fr)
            dg = bpy.context.evaluated_depsgraph_get()
            a0 = np.array(rig.matrix_world @ rig.pose.bones["upper_arm.L"].head)
            a1 = np.array(rig.matrix_world @ rig.pose.bones["hand.L"].tail)
            ab = a1 - a0

            def away(pts):
                t = (pts - a0) @ ab / ab.dot(ab)
                d = np.linalg.norm(pts - (a0 + t[:, None] * ab), axis=1)
                return ~((t >= -0.05) & (t <= 1.05) & (d < 0.16))

            trees = []
            heads = [o for o in sets if "_head_" in o.name]
            rest = [o for o in sets if "_head_" not in o.name]
            for group, members, is_set in (("corpo", objs, False), ("elmos", heads, True), ("conjuntos", rest, True)):
                allv, polys, owner, cents, soft, base = [], [], [], [], [], 0
                for o in members:
                    e = o.evaluated_get(dg)
                    me = e.to_mesh()
                    n = len(me.vertices)
                    if n and len(me.polygons):
                        co = np.empty(n * 3)
                        me.vertices.foreach_get("co", co)
                        mw = np.array(e.matrix_world)
                        vs = co.reshape(-1, 3) @ mw[:3, :3].T + mw[:3, 3]
                        cen = np.empty(len(me.polygons) * 3)
                        me.polygons.foreach_get("center", cen)
                        cents.append(cen.reshape(-1, 3) @ mw[:3, :3].T + mw[:3, 3])
                        polys += [tuple(base + k for k in pl.vertices) for pl in me.polygons]
                        owner += [o.name] * len(me.polygons)
                        soft.append(sleeve[o.name] if is_set and len(sleeve[o.name]) == len(me.polygons) else np.zeros(len(me.polygons), dtype=bool))
                        allv.append(vs)
                        base += n
                    e.to_mesh_clear()
                if not allv:
                    continue
                vs = np.concatenate(allv)
                far = [] if is_set else [Vector(v) for v in vs[::2][away(vs[::2])]]
                soft = np.concatenate(soft)
                hard = away(np.concatenate(cents))
                trees.append((group, BVHTree.FromPolygons(vs.tolist(), polys), hard & ~soft, far, is_set, owner, hard & soft))
            out[(anim, fr)] = (trees, np3(sm._bone_delta(rig, "forearm.L")))
    return out


def anchor(j):
    return Vector(j["wrist.L"]) * 0.55 + Vector(j["elbow.L"]) * 0.45


def place(Lv, mount, arm, D):
    """Vértices do escudo no mundo: modelo -> repouso (rot, centro) -> pose (osso)."""
    rot = np3(rot_of(mount))
    rest = Lv @ rot.T + (np.array(arm) + np.array(mount[3]))
    return rest @ D[:3, :3].T + D[:3, 3]


def hits_of(tree, bf, where=None):
    """(corpo comum, elmos de conjunto, corpo/pernas de conjunto, manga/cotoveleira/ombreira esquerda de conjunto).
    Os dois primeiros reprovam a montagem. O terceiro pesa na escolha: na guarda o antebraço fica colado no peito e o
    escudo rente entra no peitoral volumoso, escondido atrás da própria placa. O quarto é só contado."""
    out = {"corpo": 0, "elmos": 0, "conjuntos": 0}
    arm = 0
    for group, bt, outside, _far, _is_set, owner, soft in bf[0]:
        for _i, j in tree.overlap(bt):
            if outside[j]:
                out[group] += 1
                if where is not None:
                    where[owner[j]] = where.get(owner[j], 0) + 1
            elif soft[j]:
                arm += 1
    return out["corpo"], out["elmos"], out["conjuntos"], arm


def clearance(tree, bf):
    best = 9.0
    for _name, _bt, _outside, far, _is_set, _owner, _soft in bf[0]:
        for v in far:
            r = tree.find_nearest(v, best)
            if r[0] is not None and r[3] < best:
                best = r[3]
    return best


# ---------------------------------------------------------------------------
# geometria no espaço do escudo (X lateral, Z topo, -Y face; o braço fica em +Y)
# ---------------------------------------------------------------------------
def arm_points(base, mount, n=13, t1=1.25):
    """Pontos do eixo do antebraço (cotovelo -> punho -> meio da mão) no espaço do modelo do escudo."""
    j = base["j"] if isinstance(base, dict) and "j" in base else base
    elbow, wrist = Vector(j["elbow.L"]), Vector(j["wrist.L"])
    arm = wrist * 0.55 + elbow * 0.45
    ri = rot_of(mount).inverted()
    c = arm + Vector(mount[3])
    return [ri @ (elbow + (wrist - elbow) * (t1 * i / (n - 1)) - c) for i in range(n)]


def back_probe(tree, pts, arm_r):
    """(folga mínima braço->costas, fração do braço atrás da placa, y mais alto das costas sob o braço)."""
    gaps, top = [], -9.0
    up = Vector((0, 0, 1))
    for p in pts:
        hit = False
        for dz in (-0.7 * arm_r, 0.0, 0.7 * arm_r):
            o = Vector((p.x, 2.0, p.z + dz))
            r = tree.ray_cast(o, Vector((0, -1, 0)))
            if r[0] is not None:
                hit = True
                top = max(top, r[0].y)
                gaps.append(p.y - r[0].y - arm_r)
        if not hit:
            gaps.append(None)
    seen = [g for g in gaps if g is not None]
    return (min(seen) if seen else None), top, seen


def cover_of(tree, pts):
    n = 0
    for p in pts:
        r = tree.ray_cast(Vector((p.x, 2.0, p.z)), Vector((0, -1, 0)))
        n += r[0] is not None
    return n / len(pts)


def strap_out(tree, pts, r=0.115):
    """Quantos pontos da borda da tira (antebraço entre 30% e 75%) ficam fora da placa vista de frente: a tira aparece
    por cima do escudo e no ícone (foto de frente)."""
    n = 0
    for p in pts[3:8]:
        for dz in (-r, r):
            n += tree.ray_cast(Vector((p.x, 2.0, p.z + dz)), Vector((0, -1, 0)))[0] is None
    return n


def near_of(Lv, pts, arm_r):
    a, b = np.array(pts[0]), np.array(pts[-1])
    ab = b - a
    t = np.clip((Lv - a) @ ab / ab.dot(ab), 0, 1)
    d = np.linalg.norm(Lv - (a + t[:, None] * ab), axis=1)
    return float(d.min()) - arm_r


def local_model(obj, mount, arm):
    """Malha do kit (já no repouso, com contorno) de volta ao espaço do modelo do escudo.
    Devolve (vértices, faces, faces da placa): a placa não conta a braçadeira escura das costas (m_escudo_breu) nem o contorno."""
    co = np.empty(len(obj.data.vertices) * 3)
    obj.data.vertices.foreach_get("co", co)
    co = co.reshape(-1, 3)
    rot = np3(rot_of(mount))
    Lv = (co - (np.array(arm) + np.array(mount[3]))) @ rot       # rot^-1 = rot^T
    polys = [tuple(p.vertices) for p in obj.data.polygons]
    skip = [i for i, m in enumerate(obj.data.materials) if m and m.name in ("m_escudo_breu", "m_contorno")]
    plate = [tuple(p.vertices) for p in obj.data.polygons if p.material_index not in skip]
    return Lv, polys, plate


def measure_arm_r(base):
    """Raio do antebraço vestido (manopla de placa): vértices cujo osso dominante é o forearm.L, entre 15% e 95% do osso."""
    j = base["j"]
    elbow, wrist = Vector(j["elbow.L"]), Vector(j["wrist.L"])
    best = 0.0
    for name in ("base_body", "arm_plate_gloves_gloves", "arm_plate_body_all"):
        o = bpy.data.objects.get(name)
        if not o:
            continue
        ds = []
        for v in o.data.vertices:
            if ck.dominant_bone(o, v) != "forearm.L":
                continue
            q, t = intersect_point_line(v.co, elbow, wrist)
            if 0.15 <= t <= 0.95:
                ds.append((v.co - q).length)
        if ds:
            best = max(best, max(ds))
            P("STUDY raio do antebraço em %s: max %.3f mediana %.3f (%d vértices)" % (name, max(ds), sorted(ds)[len(ds) // 2], len(ds)))
    return round(best, 3)


# ---------------------------------------------------------------------------
# fotos
# ---------------------------------------------------------------------------
SHOW = ("base_body", "base_head", "base_eyes_round", "base_mouth_neutral", "arm_plate_body_all", "arm_plate_legs_legs",
        "arm_plate_gloves_gloves", "arm_plate_boots_boots", "arm_plate_head_all", "wpn_main_sword")


def render_setup():
    sc = bpy.context.scene
    try:
        sc.render.engine = "BLENDER_EEVEE"
    except TypeError as e:
        P("STUDY engine", e)
    sc.render.resolution_x, sc.render.resolution_y = CELL
    sc.render.resolution_percentage = 100
    sc.render.image_settings.file_format = "PNG"
    sc.render.film_transparent = False
    try:
        sc.view_settings.view_transform = "Standard"
        sc.eevee.taa_render_samples = 12
    except Exception as e:
        P("STUDY view", e)
    w = bpy.data.worlds.get("W_study") or bpy.data.worlds.new("W_study")
    w.use_nodes = True
    bg = next(n for n in w.node_tree.nodes if n.type == "BACKGROUND")
    bg.inputs[0].default_value = (0.2, 0.23, 0.28, 1)
    bg.inputs[1].default_value = 1.0
    sc.world = w
    sun = bpy.data.objects.new("study_sun", bpy.data.lights.new("study_sun", "SUN"))
    sun.data.energy = 1.6
    sun.rotation_euler = (math.radians(48), 0, math.radians(35))
    sc.collection.objects.link(sun)
    cam = bpy.data.objects.new("study_cam", bpy.data.cameras.new("study_cam"))
    cam.data.type = "ORTHO"
    cam.data.ortho_scale = ORTHO
    sc.collection.objects.link(cam)
    sc.camera = cam
    cu = bpy.data.curves.new("study_txt", "FONT")
    cu.size = 0.085
    txt = bpy.data.objects.new("study_txt", cu)
    cu.materials.append(ck.mat("m_study_label", (1.0, 1.0, 1.0), 1.0, 1.0))
    sc.collection.objects.link(txt)
    txt.parent = cam
    txt.location = (-0.5 * ORTHO * CELL[0] / CELL[1] + 0.03, 0.5 * ORTHO - 0.1, -1.0)
    return cam, txt


def aim(cam, view):
    tgt = Vector((0.2, -0.1, 0.84))
    if view.endswith("frente"):
        d = Vector((0, -1, 0))
    elif view.endswith("lado"):
        d = Vector((1, 0, 0))                   # lado esquerdo do boneco (o do escudo)
    else:
        p, y = math.radians(52), math.radians(45)
        d = Vector((math.sin(y) * math.cos(p), -math.cos(y) * math.cos(p), math.sin(p)))
    cam.location = tgt + d * 6.0
    cam.rotation_euler = (-d).to_track_quat("-Z", "Y").to_euler()


PAINT = {"tint": (0.36, 0.5, 0.78), "tint2": (0.16, 0.24, 0.46)}       # só para a foto (no jogo é a cor do item)


def paint(on, keep={}):
    """Cor de foto nos materiais do item e contorno só de costas; devolve tudo ao sair (os GLB de rascunho não mudam)."""
    for name, col in PAINT.items():
        m = bpy.data.materials.get(name)
        if not m:
            continue
        inp = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED").inputs["Base Color"]
        if on:
            keep[name] = tuple(inp.default_value)
            inp.default_value = (*col, 1.0)
        elif name in keep:
            inp.default_value = keep[name]
    m = bpy.data.materials.get("m_contorno")
    if m:
        m.use_backface_culling = on


def render_cells(rig, act, styles, tag, cam, txt, folder):
    sc = bpy.context.scene
    paint(True)
    os.makedirs(folder, exist_ok=True)
    show = set(SHOW)
    worn = [o.name for o in sc.objects if WEAR and o.type == "MESH" and any(o.name.startswith("arm_%s_" % w) for w in WEAR)]
    if worn:                          # --wear=<estilo de conjunto>: veste o conjunto no lugar da placa comum (calça comum fica)
        show -= {"arm_plate_body_all", "arm_plate_gloves_gloves", "arm_plate_boots_boots", "arm_plate_head_all"}
        show |= set(worn)
    for o in sc.objects:
        if o.type == "MESH":
            o.hide_render = o.name not in show
    for view in VIEWS:
        set_clip(rig, act, "idle" if view.startswith("idle") else "block_shield", 1 if view.startswith("idle") else 9)
        aim(cam, view)
        for st in styles:
            shown = [bpy.data.objects[shield_name(st)]]
            if tag == "antes":
                shown.append(bpy.data.objects.get("wpn_off_grip_" + st) or bpy.data.objects["wpn_off_grip"])
            for o in shown:
                o.hide_render = False
            txt.data.body = "%s\n%s %s" % (st, tag.upper(), view.replace("_", " "))
            sc.render.filepath = os.path.join(folder, "%s_%s_%s.png" % (st, tag, view))
            bpy.ops.render.render(write_still=True)
            for o in shown:
                o.hide_render = True
    paint(False)


def load_px(path):
    img = bpy.data.images.load(path)
    w, h = img.size
    a = np.empty(w * h * 4, dtype=np.float32)
    img.pixels.foreach_get(a)
    bpy.data.images.remove(img)
    return a.reshape(h, w, 4)


def sheets(styles, folder, evid, rows=6):
    os.makedirs(evid, exist_ok=True)
    cols = [(v, t) for v in VIEWS for t in ("antes", "depois")]
    cw, chh = CELL
    out = []
    for page in range(0, len(styles), rows):
        chunk = styles[page:page + rows]
        sheet = np.ones((len(chunk) * chh, len(cols) * cw, 4), dtype=np.float32)
        for r, st in enumerate(chunk):
            for c, (v, t) in enumerate(cols):
                p = os.path.join(folder, "%s_%s_%s.png" % (st, t, v))
                if os.path.exists(p):
                    y0 = (len(chunk) - 1 - r) * chh
                    sheet[y0:y0 + chh, c * cw:(c + 1) * cw] = load_px(p)
        img = bpy.data.images.new("sheet", sheet.shape[1], sheet.shape[0], alpha=False)
        img.pixels.foreach_set(sheet.ravel())
        path = os.path.join(evid, "shields_%02d.png" % (page // rows + 1))
        img.filepath_raw = path
        img.file_format = "PNG"
        img.save()
        bpy.data.images.remove(img)
        out.append(path)
        P("STUDY folha", path, chunk)
    return out


# ---------------------------------------------------------------------------
# montagem antiga (até 2026-11-15), para medir e fotografar o "antes" depois que o kit mudou:
# escudo afastado 0,29 m do antebraço e 0,32 m abaixo dele, suporte comum de duas hastes (wpn_off_grip) e, só no escudo
# de recruta, montagem rente com alça própria (wpn_off_grip_tabuas)
# ---------------------------------------------------------------------------
LEGACY_MOUNTS = {"tabuas": (78.9, 1.8, -88.3, (0.160, 0.193, -0.010))}


def legacy_shield(base, style, name, mats, close=True):
    gold = dict(mats, trim=ck.mat("m_escudo_ouro", (0.95, 0.66, 0.16), 0.32))
    obj = ck._join(shield_kit.FAMILIES[style](ck, name, gold), name)
    rot = ck._shield_rot(style).to_4x4()
    c = ck._shield_anchor(base, style)[1]
    inner = shield_kit.INNER.get(style, 1.0)
    for vert in obj.data.vertices:
        co = vert.co * ck.SHIELD_SCALE * shield_kit.SIZES.get(style, 1.0)
        co.x *= inner if co.x < 0.0 else 1.0
        vert.co = rot @ co + c
    shield_kit.hull(obj, ck.SHIELD_OUTLINE, ck.mat("m_contorno", (0.12, 0.1, 0.16), 0.9))
    ck.skin_rigid(obj, base["rig"], "forearm.L")
    return obj


def legacy_grips(base):
    mats = ck._kit_mats()
    arm, c = ck._shield_anchor(base)
    ouro = ck.mat("m_escudo_ouro", (0.95, 0.66, 0.16), 0.32)
    wrist, elbow = Vector(base["j"]["wrist.L"]), Vector(base["j"]["elbow.L"])
    n = (ck._shield_rot() @ Vector((0, -1, 0))).normalized()
    back = arm + n * ((c - arm).dot(n) - 0.04)
    along = (wrist - elbow).normalized()
    parts = [ck.tube("grip_faixa", arm + (wrist - arm) * 0.5, arm + (elbow - arm) * 0.5, 0.088, 0.092, ouro, 10)]
    for k in (-1, 1):
        parts.append(ck.tube("grip_haste_%d" % k, arm + along * k * 0.07, back + along * k * 0.09, 0.045, 0.035, ouro, 6))
    obj = ck._join(parts, "wpn_off_grip")
    shield_kit.hull(obj, ck.SHIELD_OUTLINE, ck.mat("m_contorno", (0.12, 0.1, 0.16), 0.9))
    ck.skin_rigid(obj, base["rig"], "forearm.L")
    arm, c = ck._shield_anchor(base, "tabuas")
    n = (ck._shield_rot("tabuas") @ Vector((0, -1, 0))).normalized()
    back = arm + n * ((c - arm).dot(n) + 0.01)
    parts = [ck.tube("strap_faixa", arm + (wrist - arm) * 0.45, arm + (elbow - arm) * 0.45, 0.086, 0.09, mats["leather"], 10)]
    for k in (-1, 1):
        parts.append(ck.tube("strap_calco_%d" % k, arm + along * k * 0.06, back + along * k * 0.06, 0.04, 0.045, mats["metal"], 6))
    obj = ck._join(parts, "wpn_off_grip_tabuas")
    shield_kit.hull(obj, ck.SHIELD_OUTLINE, ck.mat("m_contorno", (0.12, 0.1, 0.16), 0.9))
    ck.skin_rigid(obj, base["rig"], "forearm.L")


# ---------------------------------------------------------------------------
# estudo
# ---------------------------------------------------------------------------
def kit_styles(cid):
    sts = [st for st in shield_kit.FAMILIES if bpy.data.objects.get("wpn_off_shield_" + st)]
    return sts + (["_comum"] if bpy.data.objects.get("wpn_off_shield") else [])


def set_objs(cid):
    pre = "arm_%s" % ck.CLASS_PREFIX[cid]
    return [o for o in bpy.context.scene.objects if o.type == "MESH" and o.name.startswith(pre)
            and o.name.split("_")[-2] in ("body", "head", "legs")]


def rule_check(rig, act, styles):
    """A regra do shield_mount.check, por estilo: {estilo: {clipe: pior}}."""
    body = sm._body()
    out = {st: {} for st in styles}
    for anim, frs in CHECK_FRAMES:
        for fr in frs:
            set_clip(rig, act, anim, fr)
            for st in styles:
                out[st][anim] = max(out[st].get(anim, 0), sm.contacts(rig, body, bpy.data.objects[shield_name(st)]))
    sm.WHERE.clear()
    return out


def face_angles(rig, act, mount):
    """Para onde a face aponta em cada clipe: (graus para fora a partir da frente, graus para cima)."""
    out = {}
    n0 = rot_of(mount) @ Vector((0, -1, 0))
    for anim, fr in (("idle", 1), ("run", 5), ("block_shield", 9)):
        set_clip(rig, act, anim, fr)
        n = (sm._bone_delta(rig, "forearm.L").to_3x3() @ n0).normalized()
        out[anim] = (round(math.degrees(math.atan2(n.x, -n.y))), round(math.degrees(math.asin(max(-1, min(1, n.z))))))
    return out


def main():
    t0 = time.time()
    os.makedirs(OUT, exist_ok=True)
    cells = os.path.join(OUT, "cells")
    data = {"styles": {}, "kits": {}}
    model, bodyf, joints = {}, {}, {}
    basis = None
    old = {}
    arms = lambda: {sx: anchor(jj) for sx, jj in joints.items()}
    do_render = "--no_render" not in ARGS
    order = []
    # ---- fase 1: kits atuais ------------------------------------------------------------------------------------
    joined = True                                            # o kit solda a alça no escudo (ck.SHIELD_STRAP_JOINED)
    new_mounts, new_shield = dict(ck.SHIELD_MOUNTS), ck.kit_shield
    for cid, sex in (("paladin", "male"), ("bishop", "male"), ("paladin", "female"), ("bishop", "female")):
        if joined:                                           # "antes" = a montagem antiga, refeita aqui
            ck.SHIELD_MOUNTS.clear()
            ck.SHIELD_MOUNTS.update(LEGACY_MOUNTS)
            ck.kit_shield = legacy_shield
        try:
            base = ck.build_kit(sex, None, cid)
            if joined:
                legacy_grips(base)
        finally:
            if joined:
                ck.kit_shield = new_shield
        rig = base["rig"]
        act = sm._actions(rig)
        joints[sex] = {k: tuple(v) for k, v in base["j"].items()}
        arm = ck._shield_anchor(base)[0]
        nmesh = sum(1 for o in bpy.context.scene.objects if o.type == "MESH")
        data["kits"]["%s_%s_antes" % (cid, sex)] = nmesh
        bodyf[(cid, sex)] = body_frames(rig, act, sm._body(), set_objs(cid))
        if sex == "female":
            P("STUDY fase 1 %s %s: %d malhas, %.0f s" % (cid, sex, nmesh, time.time() - t0))
            continue
        if basis is None:
            set_clip(rig, act, "idle", 1)
            gen = sm.solve(base, rig)
            P("STUDY montagem comum resolvida aqui: %s (kit: %s)" % (gen, (ck.SHIELD_TURN, ck.SHIELD_TILT, ck.SHIELD_SPIN, ck.SHIELD_OFFSET)))
            basis = {"rot": gen[:3], "n": sm.solve(base, rig, gap=1.0, drop=0.0)[3], "d": sm.solve(base, rig, gap=0.0, drop=1.0)[3],
                     "a": sm.solve(base, rig, gap=0.0, drop=0.0, along=1.0)[3], "arm_r": measure_arm_r(base)}
        styles = [st for st in kit_styles(cid) if st not in model and (ONLY is None or st in ONLY)]
        rule = rule_check(rig, act, styles)
        for st in styles:
            mount = ck._shield_mount(style_of(st))
            obj = bpy.data.objects[shield_name(st)]
            model[st] = local_model(obj, mount, arm) + (cid,)
            order.append(st)
            data["styles"][st] = {"kit": cid, "regra_antes": rule[st], "face": face_angles(rig, act, mount), "verts": len(model[st][0]),
                                  "alt": round(float(model[st][0][:, 2].max() - model[st][0][:, 2].min()), 3),
                                  "larg": round(float(model[st][0][:, 0].max() - model[st][0][:, 0].min()), 3)}
            old[st] = mount
        if do_render and styles:
            cam, txt = render_setup()
            render_cells(rig, act, styles, "antes", cam, txt, cells)
        P("STUDY fase 1 %s %s: %d malhas, %d estilos, %.0f s" % (cid, sex, nmesh, len(styles), time.time() - t0))
    for st in order:
        Lv, polys, plate, _cid = model[st]
        data["styles"][st]["antes"] = describe(st, Lv, polys, plate, old[st], joints, basis, bodyf, arms())
    if joined:
        ck.SHIELD_MOUNTS.clear()
        ck.SHIELD_MOUNTS.update(new_mounts)
    json.dump(data, open(os.path.join(OUT, "study.json"), "w"), indent=1)
    # ---- fase 2: procura ----------------------------------------------------------------------------------------
    mounts = {}
    if arg("mounts"):
        mounts = {k: (v[0], v[1], v[2], tuple(v[3])) for k, v in json.load(open(arg("mounts")))["mounts"].items()}
    if "--kit_mounts" in ARGS:                               # confere as montagens que já estão no chibi_kit, sem procurar
        mounts = {st: ck._shield_mount(style_of(st)) for st in order}
        for st in order:
            data["styles"][st]["busca"] = "do kit"
    for st in order:
        if st in mounts:
            continue
        if st == "tabuas":
            mounts[st] = LEGACY_MOUNTS["tabuas"]             # já decidida; só a alça passa para dentro da malha
            data["styles"][st]["busca"] = "mantida (shield-fix)"
            continue
        if st in mounts:
            continue
        if st == "_comum" and "juramento" in mounts:
            mounts[st] = mounts["juramento"]
            data["styles"][st]["busca"] = "= juramento"
            continue
        Lv, polys, plate, _cid = model[st]
        mounts[st], data["styles"][st]["busca"] = search(st, Lv, polys, plate, basis, joints, bodyf, arms())
        P("STUDY busca %-10s %s -> %s" % (st, data["styles"][st]["busca"], mounts[st]))
    data["mounts"] = mounts
    data["basis"] = basis
    json.dump(data, open(os.path.join(OUT, "study.json"), "w"), indent=1)
    P("STUDY fase 2: %.0f s" % (time.time() - t0))
    # ---- fase 3: kits de rascunho (montagem rente + alça soldada) ---------------------------------------------------
    old_mounts = dict(ck.SHIELD_MOUNTS)
    for st, m in mounts.items():
        if st == "_comum":
            continue
        ck.SHIELD_MOUNTS[st] = m
    if "_comum" in mounts and "juramento" not in mounts:
        ck.SHIELD_MOUNTS["juramento"] = mounts["_comum"]
    try:
        for cid, sex in (("paladin", "male"), ("bishop", "male"), ("paladin", "female"), ("bishop", "female")):
            base = ck.build_kit(sex, OUT, cid)
            rig = base["rig"]
            act = sm._actions(rig)
            arm = ck._shield_anchor(base)[0]
            nmesh = sum(1 for o in bpy.context.scene.objects if o.type == "MESH")
            data["kits"]["%s_%s_depois" % (cid, sex)] = nmesh
            styles = [st for st in kit_styles(cid) if st in data["styles"] and (ONLY is None or st in ONLY)]
            rule = rule_check(rig, act, styles)
            for st in styles:
                s = data["styles"][st]
                s.setdefault("regra_depois", {})["%s_%s" % (cid, sex)] = rule[st]
            if sex == "male":
                mine = [st for st in styles if data["styles"][st]["kit"] == cid]
                for st in mine:
                    mount = ck._shield_mount(style_of(st))
                    Lv, polys, _plate = local_model(bpy.data.objects[shield_name(st)], mount, arm)
                    s = data["styles"][st]
                    s["depois"] = describe(st, Lv, polys, model[st][2], mount, joints, basis, bodyf, arms(), plate_v=model[st][0])
                    s["verts_depois"] = len(Lv)
                if do_render and mine:
                    cam, txt = render_setup()
                    render_cells(rig, act, mine, "depois", cam, txt, cells)
            P("STUDY fase 3 %s %s: %d malhas, %.0f s" % (cid, sex, nmesh, time.time() - t0))
    finally:
        ck.SHIELD_MOUNTS.clear()
        ck.SHIELD_MOUNTS.update(old_mounts)
    json.dump(data, open(os.path.join(OUT, "study.json"), "w"), indent=1)
    if do_render:
        data["sheets"] = sheets(order, cells, EVID)
        json.dump(data, open(os.path.join(OUT, "study.json"), "w"), indent=1)
    P("STUDY fim: %.0f s" % (time.time() - t0))


def decompose(off, basis):
    A = np.array([basis["n"], basis["d"], basis["a"]]).T
    g, d, a = np.linalg.solve(A, np.array(off))
    return round(float(g), 3), round(float(d), 3), round(float(a), 3)


def frames_for(st, bodyf):
    """Corpos contra os quais o estilo é conferido: escudo comum = os dois kits; de conjunto = o kit da classe."""
    cid = ck.style_class(style_of(st))
    return [(k, v) for k, v in bodyf.items() if cid is None or k[0] == cid]


def describe(st, Lv, polys, plate, mount, joints, basis, bodyf, arm, plate_v=None):
    """Números de uma montagem. plate = faces da placa (sem braçadeira/alça/contorno), para a folga até as costas dela."""
    arm_r = basis["arm_r"]
    pts = arm_points(joints["male"], mount)
    pv = Lv if plate_v is None else plate_v
    ptree = BVHTree.FromPolygons(pv.tolist(), plate)
    air, _top, _seen = back_probe(ptree, pts, arm_r)
    out = {"mount": [mount[0], mount[1], mount[2], list(mount[3])],
           "gda": decompose(mount[3], basis) if max(abs(mount[i] - basis["rot"][i]) for i in range(3)) < 0.5 else None,
           "ar": None if air is None else round(air, 3), "cobre": round(cover_of(ptree, pts[:11]), 2),
           "perto": round(near_of(pv, pts[:11], arm_r), 3), "tira_fora": strap_out(ptree, pts), "folga": {}, "toques": {}, "elmo": {}, "conj": {}, "manga": {}, "onde": {}}
    for (cid, sex), frames in frames_for(st, bodyf):
        for (anim, fr), bf in frames.items():
            tree = BVHTree.FromPolygons(place(Lv, mount, arm[sex], bf[1]).tolist(), polys)
            key = "%s_%s" % (anim, sex)
            b, h, c, a = hits_of(tree, bf, out["onde"])
            out["elmo"][key] = max(out["elmo"].get(key, 0), h)
            out["toques"][key] = max(out["toques"].get(key, 0), b)
            out["conj"][key] = max(out["conj"].get(key, 0), c)
            out["manga"][key] = max(out["manga"].get(key, 0), a)
            if sex == "male":
                out["folga"][anim] = round(min(out["folga"].get(anim, 9.0), clearance(tree, bf)), 3)
    return out


SOFT_WEIGHT = 5e-5              # custo por toque em peitoral/saia de conjunto (2000 toques = 0,1 m de drop fora do alvo)
HELM_WEIGHT = 3e-4              # custo por toque em elmo de conjunto (chifre, crista: aparece de cima)


def search(st, Lv, polys, plate, basis, joints, bodyf, arm):
    """Montagem mais rente. Reprova: toque no corpo comum (a regra do shield_mount --check, aqui em quadros densos).
    Prefere as que também não tocam o corpo feminino; entre elas a de menor custo: gap além do encostado, drop longe do
    alvo, deslocamento ao longo do braço, toques em elmo e em peitoral/saia de conjunto (na guarda o antebraço fica
    colado no peito: o escudo rente entra no peitoral volumoso, escondido atrás da própria placa).
    Mesma rotação da comum; muda gap/drop/along."""
    arm_r = basis["arm_r"]
    ptree = BVHTree.FromPolygons(Lv.tolist(), plate)
    rot = tuple(basis["rot"])
    n, d_, a_ = (np.array(basis[k]) for k in ("n", "d", "a"))
    cands = []
    for drop in (0.10, 0.14, 0.18, 0.22, 0.26, 0.30, 0.34):
        for along in (0.0, 0.04, 0.08):
            m0 = (rot[0], rot[1], rot[2], tuple(1.0 * n + drop * d_ + along * a_))       # gap provisório de 1 m: só para achar as costas
            pts = arm_points(joints["male"], m0)
            if cover_of(ptree, pts[:11]) < 0.7:
                continue
            _air, top, seen = back_probe(ptree, pts, arm_r)
            if not seen:
                continue
            touch = top + arm_r + STRAP                     # no espaço do modelo o braço fica em y = gap
            peek = 0.06 * strap_out(ptree, pts)             # tira aparecendo por cima da placa: custa como 1 cm de gap por ponto
            for extra in (0.0, 0.02, 0.04, 0.06, 0.08, 0.10, 0.12, 0.15, 0.18):
                cost = 6.0 * extra + 0.5 * abs(drop - TARGET_DROP) + 0.5 * abs(along) + peek      # o que se vê flutuar é o gap
                cands.append((cost, round(touch + extra, 3), drop, along, extra))
    cands.sort()
    frames = [(sex, bf) for (cid, sex), fs in frames_for(st, bodyf) for bf in fs.values()]
    frames.sort(key=lambda f: f[0] != "male")                # corpo masculino primeiro: é o que reprova
    best = None                                              # (camada, custo total, montagem, texto)
    for cost, gap, drop, along, extra in cands:
        if best is not None and best[0] == 0 and cost >= best[1]:
            break                                            # daqui em diante nem com zero toques ganha
        off = tuple(round(float(x), 3) for x in gap * n + drop * d_ + along * a_)
        mount = (rot[0], rot[1], rot[2], off)
        male = female = helm = soft = 0
        for i, (sex, bf) in enumerate(frames):
            tree = BVHTree.FromPolygons(place(Lv, mount, arm[sex], bf[1]).tolist(), polys)
            b, h, c, _a = hits_of(tree, bf)
            helm += h
            soft += c
            if sex == "male":
                male += b
            else:
                female += b
            if male or (female and best is not None and best[0] == 0):
                frames.insert(0, frames.pop(i))              # o quadro que reprova vai para a frente da fila
                break
        if male:
            continue                                         # toca o corpo comum: fora (é a regra do --check)
        tier = 1 if female else 0
        total = cost + SOFT_WEIGHT * soft + HELM_WEIGHT * helm + 1e-3 * (male + female)
        txt = "gap %.3f drop %.2f along %.2f extra %.2f | corpo m %d f %d, elmo %d, conj %d" % (gap, drop, along, extra, male, female, helm, soft)
        if best is None or (tier, total) < (best[0], best[1]):
            best = (tier, total, mount, ("" if tier == 0 else "SO HOMEM: ") + txt)
    if best is None:
        return ck._shield_mount(style_of(st)), "SEM CANDIDATO: fica a atual"
    return best[2], best[3]




if __name__ == "__main__":
    main()
    P("SHIELD_STUDY_END")
