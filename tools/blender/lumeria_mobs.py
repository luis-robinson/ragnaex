"""Ato III, parte 1 (45-50) — Veladas (design/gdd/ato3-excesso-45-50.md §3.1 e §4): a família demoníaca principal
da Avenida do Cortejo e da Fenda. Uma base de corpo comum (`demoness`: porcelana marfim esguia, pernas compridas, máscara
branca lisa com UMA lágrima pintada, capuz-véu, chifres lisos PARA TRÁS em ouro velho, véus rosa-pó em camadas) com as
variantes em KINDS. Sem asas, sem cauda de demônio, sem chifre para cima/frente: a silhueta é chifre para trás + véus.

  mob_seductress        Sedutora (46): chifres médios, dois véus compridos nas costas, saia de pontas aberta na frente, garras de ouro
  mob_flayer            Açoitadora (47): mais alta, chifres longos, véu-capa de duas camadas, chicote de fitas-lâmina na mão direita
  mob_veil_singer       Cantora do Véu (48): véu do rosto até o peito (a lágrima pintada no véu), chifres curtos, mãos abertas acesas
  mob_thirst_matriarch  Matriarca Velada (49, elite): mais larga, chifres grandes com argolas, coroa de fitas, pires nos ombros,
                        cauda de véus que arrasta no chão
  mob_vessaline         Vessaline (chefe, 50): a mais alta, rosto liso (sem olhos) com a lágrima DOURADA, pente de ouro, vestido
                        inteiro e a cauda de fitas-lâmina (TAIL_LEN m no modelo; com `scale` 1,8 no catálogo = ~6 m no jogo)
  mob_countess          A Condessa Refletida (chefe de dg_mirrors, 49): máscara DUPLA (frente de olhos abertos, costas de olhos
                        fechados), capuz em faixa, espelho oval de pé no alto da cabeça, espelhos nos ombros e no peito, saia-sino
                        de painéis de espelho em moldura de ouro (duas fileiras), florete na mão direita (`attack` = estocada)
  mob_standing_mirror   Espelho de Pé (lacaio parado da Condessa, cobertura): peças rígidas nos ossos de MIRROR_BONES; clipes
                        idle run attack hit die + `crack` (racha, 1 vez) e `idle_cracked` (laço já rachado). Rachado = o que
                        se lê de cima: chapa escura em lascas sobre o vidro (osso `core`), vão preto que aparece também
                        nas costas, cacos claros no chão à frente (osso `floor`), moldura torta e remate pendurado
                        (MIRROR_CROOK); `core` e `floor` ficam em escala ~0 enquanto o espelho está inteiro

Tamanho: como os outros monstros, quem decide é `MonsterDef.scale`; os modelos saem com ~1,75-1,95 m (sugestão de escala no
relatório do WP7: Sedutora 1,0 · Açoitadora 1,05 · Cantora 1,0 · Matriarca 1,3 · Vessaline 1,8).
Pernas compridas: `_stretch` sobe as juntas de chibi_kit.Z só durante a montagem e `_hips_scale` multiplica o deslocamento do
quadril dos clipes pela mesma razão (o ajoelhar da morte chega ao chão).
Cauda/véus no chão: osso `tail` (filho de `root`, na origem). `_tail_anim` cancela a inclinação do `root` (a queda da morte
deitaria a cauda 3 m para dentro do chão) e deixa só o giro em volta do eixo de pé; balanço leve no idle e na corrida.
Clipes: idle run attack cast hit die block + CLIPS[kind] (gestos de skill pelo nome que EntityView._action_clip pede).
No fim as peças viram 2 malhas por modelo (corpo + peças), com os pesos por osso.

    import mob_kit; mob_kit.build_all(r"<abs>/assets/models", only=set(lumeria_mobs.BUILDERS))
Prévia e conta de chão sem janela: tools/blender/lumeria_mobs_preview.py.
"""
import math

import bmesh
import bpy
from mathutils import Euler, Quaternion, Vector

import chibi_kit as ck
import mob_kit as mk
import act2_bosses
import berserker_sets as bs
import lumeria_kit as lk

V = Vector
cone = mk.cone

PORC = (0.93, 0.89, 0.82)          # corpo: marfim quente (o branco puro estoura no toon)
MASK = (0.98, 0.97, 0.94)          # máscara: porcelana branca
OLD_GOLD = (0.69, 0.54, 0.24)
BRIGHT_GOLD = (0.93, 0.76, 0.36)   # argolas, filetes, pontas das lâminas
INK = (0.1, 0.08, 0.12)
STEEL = (0.86, 0.85, 0.9)          # fita-lâmina
ROSE_TEAR = (1.0, 0.45, 0.58)
GOLD_TEAR = (1.0, 0.8, 0.32)
TAIL_LEN = 3.3                     # cauda da Vessaline no modelo (m)

# pal = (véu principal rosa-pó, véu escuro, véu claro)
KINDS = {
    "seductress": {"leg": 0.13, "torso": 0.03, "pal": ((0.82, 0.56, 0.6), (0.6, 0.36, 0.45), (0.94, 0.78, 0.78)),
                   "horn": (1.7, 0.21), "tear": ROSE_TEAR},
    "flayer": {"leg": 0.19, "torso": 0.04, "arm": 1.28, "pal": ((0.66, 0.36, 0.44), (0.46, 0.24, 0.33), (0.88, 0.66, 0.68)),
               "horn": (2.4, 0.22), "tear": ROSE_TEAR},
    "singer": {"leg": 0.12, "torso": 0.03, "pal": ((0.84, 0.62, 0.74), (0.6, 0.4, 0.58), (0.95, 0.85, 0.88)),
               "horn": (0.9, 0.2), "tear": ROSE_TEAR},
    "matriarch": {"leg": 0.14, "torso": 0.05, "bulk": 1.14, "head": 0.29, "pal": ((0.78, 0.48, 0.54), (0.52, 0.27, 0.36), (0.95, 0.8, 0.78)),
                  "horn": (2.4, 0.32), "tear": ROSE_TEAR},
    "vessaline": {"leg": 0.24, "torso": 0.06, "arm": 1.34, "head": 0.27, "pal": ((0.86, 0.6, 0.64), (0.56, 0.3, 0.4), (0.96, 0.84, 0.82)),
                  "horn": (2.3, 0.2), "tear": GOLD_TEAR},
    "countess": {"leg": 0.2, "torso": 0.05, "arm": 1.28, "head": 0.27, "pal": ((0.76, 0.5, 0.58), (0.5, 0.28, 0.4), (0.95, 0.86, 0.86)),
                 "horn": (2.0, 0.23), "tear": ROSE_TEAR},
}
MIRROR = (0.7, 0.84, 0.93)         # vidro de espelho: o único frio da família (lê contra o rosa e o ouro)
MIRROR_LIGHT = (0.9, 0.96, 1.0)
SKILL_SET = ("atk_charge", "atk_leap", "atk_sweep", "atk_claw", "atk_throw", "cast_ground", "cast_target", "cast_shadow", "shout", "jump", "dash")
CLIPS = {
    "seductress": ("atk_charge", "atk_leap", "atk_claw", "jump", "dash", "shout"),
    "flayer": ("atk_sweep", "atk_throw", "atk_charge", "shout"),
    "singer": ("cast_ground", "cast_target", "cast_channel", "cast_shadow", "jump", "shout"),
    "matriarch": ck.MOB_BOSS_KEEP + ("jump", "dash"),
    "vessaline": ck.MOB_BOSS_KEEP + ("jump", "dash"),
    "countess": ck.MOB_BOSS_KEEP + ("jump", "dash"),
}
ATTACK = {"seductress": None, "flayer": "atk_1h_a", "singer": "atk_staff", "matriarch": None, "vessaline": None,     # None = atk_claw
          "countess": "atk_thrust"}
SINGER_CARRY = {"upper_arm.R": (-22, 0, 38), "forearm.R": (-28, 0, 0), "upper_arm.L": (-22, 0, -38), "forearm.L": (-28, 0, 0)}


# ---------------------------------------------------------------------------
# helpers
# ---------------------------------------------------------------------------
def _body(cfg):
    k = cfg.get("bulk", 1.0)
    return dict(shoulder=0.172 * k, hip=0.08 * k, pelvis=0.158 * k, waist=0.104 * k, chest=0.142 * k, upper=0.132 * k,
                arm=0.05, elbow=0.042, wrist=0.036, hand=0.046, thigh=0.078 * k, knee=0.056, ankle=0.046,
                toe=0.058, neck=0.044, depth=0.8, head=cfg.get("head", 0.27), arm_len=cfg.get("arm", 1.2))


def _stretch(leg, torso):
    """Sobe as juntas de chibi_kit.Z (pernas e tronco mais compridos); devolve o Z de antes para repor no fim."""
    saved = dict(ck.Z)
    Z = ck.Z
    Z["knee"] += leg * 0.5
    Z["hip"] += leg
    Z["pelvis"] += leg
    Z["waist"] += leg + torso * 0.35
    Z["chest"] += leg + torso * 0.7
    for k in ("upper", "neck", "neck_top", "head"):
        Z[k] += leg + torso - (0.045 if k in ("neck_top", "head") else 0.0)      # pescoço curto: a cabeça menor não fica num palito
    return saved


def _band(name, pts, widths, thick, material, hint=(1, 0, 0), flat=False):
    """Faixa de pano pelos pontos. flat = deitada (largura na horizontal, acompanha a curva); senão a largura segue hint."""
    pts = [V(p) for p in pts]
    h = V(hint).normalized()
    bm_ = bmesh.new()
    front, backv = [], []
    prev = None
    last = len(pts) - 1
    for i, (p, wd) in enumerate(zip(pts, widths)):
        ax = (pts[min(i + 1, last)] - pts[max(i - 1, 0)]).normalized()
        side = ax.cross(V((0, 0, 1))) if flat else h - ax * h.dot(ax)
        if side.length < 1e-4:
            side = prev.copy() if prev else V((1, 0, 0))
        side.normalize()
        if prev and side.dot(prev) < 0:
            side = -side
        prev = side
        n = ax.cross(side).normalized() * thick * 0.5
        front.append((bm_.verts.new(p - side * wd * 0.5 + n), bm_.verts.new(p + side * wd * 0.5 + n)))
        backv.append((bm_.verts.new(p - side * wd * 0.5 - n), bm_.verts.new(p + side * wd * 0.5 - n)))
    for i in range(last):
        bm_.faces.new((front[i][0], front[i][1], front[i + 1][1], front[i + 1][0]))
        bm_.faces.new((backv[i][0], backv[i + 1][0], backv[i + 1][1], backv[i][1]))
        bm_.faces.new((front[i][0], front[i + 1][0], backv[i + 1][0], backv[i][0]))
        bm_.faces.new((front[i][1], backv[i][1], backv[i + 1][1], front[i + 1][1]))
    bm_.faces.new((front[0][0], backv[0][0], backv[0][1], front[0][1]))
    bm_.faces.new((front[last][0], front[last][1], backv[last][1], backv[last][0]))
    bmesh.ops.recalc_face_normals(bm_, faces=bm_.faces[:])
    return ck.mesh_from(name, bm_, material)


def _veil(name, p0, p1, w0, w1, material, bow=(0, 0.08, 0), n=4, point=0.2, thick=0.014):
    """Véu pendurado de p0 a p1 (largura em X), barriga `bow` no meio e ponta afinada (point = fração da largura no fim)."""
    p0, p1, bow = V(p0), V(p1), V(bow)
    pts, widths = [], []
    for i in range(n + 1):
        t = i / n
        pts.append(p0.lerp(p1, t) + bow * math.sin(math.pi * t))
        widths.append(w0 + (w1 - w0) * t)
    widths[-1] *= point
    return _band(name, pts, widths, thick, material)


def _ring(name, z0, z1, r0, r1, material, depth=0.85, segs=12, y=0.0):
    o = ck.tube(name, (0, 0, z0), (0, 0, z1), r0, r1, material, segs)
    for v in o.data.vertices:
        v.co.y = v.co.y * depth + y
    return o


def _petals(name, n, z0, z1, r0, r1, w, material, skip_front=0.0, phase=0.0, depth=0.85, mid=0.5):
    """Saia de pontas: n véus em folha da cintura (raio r0, altura z0) à barra (r1, z1). skip_front = meia-abertura (rad) na frente."""
    out = []
    for i in range(n):
        a = math.tau * (i + phase) / n
        d = abs((a + math.pi / 2 + math.pi) % math.tau - math.pi)        # distância angular da frente (-Y)
        if d < skip_front:
            continue
        dr = V((math.cos(a), math.sin(a) * depth, 0))
        tang = V((-math.sin(a), math.cos(a), 0))
        out.append(ck.blade("%s%d" % (name, i), dr * r0 + V((0, 0, z0)), dr * r1 + V((0, 0, z1)), w, 0.016, material, tang, mid))
    return out


def _skirt(name, z0, z1, r0, r1, material, segs=14, zig=0.06, gap=0.0, depth=0.85, rows=3, y=0.0):
    """Saia/capa de véu: tubo de quads de (r0, z0) a (r1, z1) com a barra em pontas (zig); gap = meia-abertura (rad) na frente."""
    closed = gap <= 0.0
    cols = segs if closed else segs + 1
    a0, a1 = -math.pi / 2 + gap, -math.pi / 2 + math.tau - gap
    verts, faces = [], []
    for i in range(rows + 1):
        t = i / rows
        rr = r0 + (r1 - r0) * t ** 0.8
        for k in range(cols):
            a = a0 + (a1 - a0) * k / segs
            up = zig * t * t if k % 2 else 0.0
            verts.append((math.cos(a) * rr, math.sin(a) * rr * depth + y, z0 + (z1 - z0) * t + up))
    for i in range(rows):
        for k in range(segs if closed else segs):
            a_, b_ = i * cols + k, i * cols + (k + 1) % cols
            faces.append((a_, b_, b_ + cols, a_ + cols))
    me = bpy.data.meshes.new(name + "_mesh")
    me.from_pydata(verts, [], faces)
    me.update()
    obj = ck._link(bpy.data.objects.new(name, me))
    sol = obj.modifiers.new("sol", "SOLIDIFY")
    sol.thickness = 0.016
    ck._bake(obj)
    obj.data.materials.append(material)
    return obj


def _horn_pts(c, r, sx, length, spread=0.3, rise=0.1):
    p0 = c + V((sx * r * 0.6, r * 0.5, r * 0.9))
    p1 = p0 + V((sx * r * spread * length * 0.5, r * length, -r * rise * length))
    bend = V((sx * r * 0.09 * length, 0, r * 0.1 * length))
    return p0, p1, bend


def _horns(cid, c, r, M, length, r0, rings=0):
    """Chifres lisos para trás (ouro velho), arco suave; rings = argolas de ouro claro ao longo de cada um."""
    out = []
    for sx in (-1, 1):
        p0, p1, bend = _horn_pts(c, r, sx, length)
        out += bs._tusk(ck, "%s_horn%d" % (cid, sx), p0, p1, bend, r * r0, M["gold"], 5, 8)
        out.append(ck.tube("%s_hornbase%d" % (cid, sx), p0 - (p1 - p0).normalized() * r * 0.06, p0 + (p1 - p0).normalized() * r * 0.1,
                           r * r0 * 1.3, r * r0 * 1.25, M["gold2"], 8))
        for k in range(rings):
            t = 0.3 + 0.26 * k
            f = lambda u: p0.lerp(p1, u) + bend * math.sin(math.pi * u)
            p, tg = f(t), (f(t + 0.04) - f(t - 0.04)).normalized()
            dt = 0.022 / max((p1 - p0).length, 0.01)       # faixa chata rente ao chifre (acompanha o afinar), não um aro gordo
            ra, rb_ = r * r0 * (1.0 - t + dt) * 1.07 + 0.003, r * r0 * (1.0 - t - dt) * 1.07 + 0.003
            out.append(ck.tube("%s_hornring%d_%d" % (cid, sx, k), p - tg * 0.022, p + tg * 0.022, ra, rb_, M["gold2"], 8))
    return out


def _bow(name, p, out, size, m_loop, m_knot, m_tail):
    """Laço de fita: duas alças gordas (afinam no nó), nó no meio e duas pontas caídas. `out` = para fora da cabeça; o laço
    deita para fora (a face dele olha para cima: é o que a câmera alta vê)."""
    p, o_ = V(p), V(out).normalized()
    t = V((-o_.y, o_.x, 0)).normalized()
    up = (V((0, 0, 1)) + o_ * 0.9).normalized()
    n = t.cross(up).normalized()
    objs = []
    for sx in (-1, 1):
        lobe = ck.ball("%s_l%d" % (name, sx), 1.0, (0, 0, 0), m_loop)
        for v in lobe.data.vertices:
            x, y, z = v.co
            f = 0.3 + 0.7 * (x + 1.0) * 0.5
            v.co = p + t * (sx * (x + 1.0) * 0.5 * size) + up * (z * size * 0.44 * f) + n * (y * size * 0.15)
        objs.append(lobe)
        objs.append(ck.blade("%s_t%d" % (name, sx), p, p + t * (sx * size * 0.34) + o_ * (size * 0.5) - V((0, 0, size * 0.62)), size * 0.3, 0.016,
                             m_tail, t, 0.6))
    objs.append(ck.ball(name + "_k", size * 0.2, p + up * 0.005, m_knot))
    return objs


def _plate(name, pts, y, thick, material):
    """Chapa no plano XZ (contorno pts = [(x, z)], convexo), espessura em Y."""
    bm_ = bmesh.new()
    f = [bm_.verts.new((x, y - thick * 0.5, z)) for x, z in pts]
    b = [bm_.verts.new((x, y + thick * 0.5, z)) for x, z in pts]
    n = len(pts)
    bm_.faces.new(f)
    bm_.faces.new(b[::-1])
    for i in range(n):
        bm_.faces.new((f[i], b[i], b[(i + 1) % n], f[(i + 1) % n]))
    bmesh.ops.recalc_face_normals(bm_, faces=bm_.faces[:])
    return ck.mesh_from(name, bm_, material)


def _floor_plate(name, pts, z, thick, material):
    """Chapa deitada no chão (contorno pts = [(x, y)], convexo), de z a z + thick."""
    bm_ = bmesh.new()
    lo = [bm_.verts.new((x, y, z)) for x, y in pts]
    hi = [bm_.verts.new((x, y, z + thick)) for x, y in pts]
    n = len(pts)
    bm_.faces.new(lo)
    bm_.faces.new(hi[::-1])
    for i in range(n):
        bm_.faces.new((lo[i], hi[i], hi[(i + 1) % n], lo[(i + 1) % n]))
    bmesh.ops.recalc_face_normals(bm_, faces=bm_.faces[:])
    return ck.mesh_from(name, bm_, material)


def _add_tail_bone(rig):
    bpy.context.view_layer.objects.active = rig
    bpy.ops.object.mode_set(mode="EDIT")
    eb = rig.data.edit_bones
    t = eb.new("tail")
    t.head, t.tail, t.roll = (0, 0, 0), (0, 0, 0.12), 0.0
    t.parent = eb["root"]
    bpy.ops.object.mode_set(mode="OBJECT")


def _hips_scale(rig, k):
    for t in rig.animation_data.nla_tracks:
        for fc in ck._fcurves(t.strips[0].action):
            if fc.data_path == 'pose.bones["hips"].location':
                for kp in fc.keyframe_points:
                    kp.co.y *= k
                    kp.handle_left.y *= k
                    kp.handle_right.y *= k
                fc.update()


def _tail_anim(rig):
    """Osso `tail`: cancela a inclinação do `root` em todo clipe (fica só o giro em pé) e balança de leve parado/correndo."""
    ad = rig.animation_data
    pb = rig.pose.bones["tail"]
    pb.rotation_mode = "QUATERNION"
    for t in ad.nla_tracks:
        act = t.strips[0].action
        end = int(round(act.frame_range[1]))
        rc = {fc.array_index: fc for fc in ck._fcurves(act) if fc.data_path == 'pose.bones["root"].rotation_euler'}
        ad.action = act
        if getattr(ad, "action_slot", None) is None and getattr(act, "slots", None):
            ad.action_slot = act.slots[0]
        sway = {"idle": 2.5, "run": 5.0}.get(t.name, 0.0)
        tilted = any(abs(kp.co.y) > 1e-4 for i, fc in rc.items() if i != 1 for kp in fc.keyframe_points)
        frames = range(1, end + 1) if tilted else (sorted(set(list(range(1, end, 3)) + [end])) if sway else (1, end))
        prev = None
        for f in frames:
            q = Euler([rc[i].evaluate(f) if i in rc else 0.0 for i in range(3)], "XYZ").to_quaternion()
            tw = Quaternion((q.w, 0.0, q.y, 0.0))
            tw = tw.normalized() if tw.magnitude > 1e-4 else Quaternion()
            out = q.inverted() @ tw
            if sway:
                out = out @ Quaternion((0, 1, 0), math.radians(sway) * math.sin(math.tau * (f - 1) / max(1, end - 1)))
            if prev is not None and prev.dot(out) < 0:
                out.negate()
            prev = out.copy()
            pb.rotation_quaternion = out
            pb.keyframe_insert("rotation_quaternion", frame=f)
        ad.action = None
    pb.rotation_quaternion = (1, 0, 0, 0)


def _join(cid, rig, keep):
    """Todas as peças (menos o corpo) numa malha só, com os grupos de osso (bpy join junta por nome)."""
    objs = [o for o in rig.children if o.type == "MESH" and o.name != keep]
    if len(objs) < 2:
        return
    for o in bpy.context.scene.objects:
        o.select_set(False)
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    with bpy.context.temp_override(active_object=objs[0], object=objs[0], selected_objects=objs, selected_editable_objects=objs):
        bpy.ops.object.join()
    objs[0].name = cid + "_parts"


# ---------------------------------------------------------------------------
# a base comum + variantes
# ---------------------------------------------------------------------------
def demoness(cid, kind):
    cfg = KINDS[kind]
    saved = _stretch(cfg["leg"], cfg["torso"])
    try:
        return _demoness(cid, kind, cfg)
    finally:
        ck.Z.clear()
        ck.Z.update(saved)


def _demoness(cid, kind, cfg):
    ck.BODIES["thirst"] = _body(cfg)
    base = ck.build_base(cid, "thirst", 0.0)
    rig, body, b, j = base["rig"], base["body"], base["b"], base["j"]
    Z = ck.Z
    m = lambda n, col, rough=0.7, em=0.0: ck.mat("m_%s_%s" % (cid, n), col, rough, em)
    pal = cfg["pal"]
    M = {"body": m("porc", PORC, 0.4), "porc": m("mask", MASK, 0.3), "gold": m("gold", OLD_GOLD, 0.4), "gold2": m("gold2", BRIGHT_GOLD, 0.35),
         "ink": m("ink", INK, 0.6), "glow": m("tear", cfg["tear"], 0.3, 2.2), "rose": m("veil", pal[0], 0.8), "deep": m("veil2", pal[1], 0.8),
         "pale": m("veil3", pal[2], 0.8), "steel": m("blade", STEEL, 0.3)}
    rose, deep, pale, gold, gold2, glow = M["rose"], M["deep"], M["pale"], M["gold"], M["gold2"], M["glow"]
    for o in list(bpy.context.scene.objects):          # boneca lisa: sem olhos nem cabelo, tudo porcelana
        if o.name.startswith((cid + "_head_", cid + "_hair")):
            bpy.data.objects.remove(o, do_unlink=True)
        elif o.type == "MESH" and o.name in (cid + "_body", cid + "_head"):
            o.data.materials[0] = M["body"]
    tailed = kind in ("matriarch", "vessaline")
    if tailed:
        _add_tail_bone(rig)

    c, r = V(base["head_c"]), b["head"]
    zc, zw, zn, zp, zu = Z["chest"], Z["waist"], Z["neck"], Z["pelvis"], Z["upper"]
    sw = b["chest"]
    back = b["chest"] * b["depth"]
    front = -back
    head, chest, hips, skinned = [], [], [], []
    arms = {".R": [], ".L": []}
    hands = {".R": [], ".L": []}
    shins = {".R": [], ".L": []}

    # ---------------- cabeça: máscara, capuz-véu, chifres ----------------
    boss = kind == "vessaline"
    mk_ = lk.mask(ck, cid + "_mask", c + V((0, -r * 0.76, -r * 0.1)), r * 0.74, M, tears=(1,), eyes=not boss,
                  tear_len=0.85 if boss else 0.55, wide=0.96 if boss else 1.0, tall=1.08 if boss else 1.0)
    if boss:                                           # rosto liso: nem o risco dos olhos
        for o in [o for o in mk_ if "_lid" in o.name]:
            mk_.remove(o)
            bpy.data.objects.remove(o, do_unlink=True)
    head += mk_
    twin = kind == "countess"                          # máscara dupla: o capuz vira uma faixa (aberto na frente E atrás)
    hc = c + (V((0, 0, r * 0.1)) if twin else V((0, r * 0.28, r * 0.1)))      # capuz-véu: touca maior que a cabeça, recuada (rosto todo de fora)
    hood = ck.ball(cid + "_hood", r * (1.1 if twin else 1.12), hc, deep if kind == "flayer" else rose)
    bm_ = bmesh.new()                                  # aberta na frente: sem a costura serrilhada de duas esferas que se cruzam
    bm_.from_mesh(hood.data)
    bmesh.ops.delete(bm_, geom=[f for f in bm_.faces if f.calc_center_median().y < c.y - r * (0.4 if twin else 0.05)
                                or (twin and f.calc_center_median().y > c.y + r * 0.4)], context="FACES")
    bm_.to_mesh(hood.data)
    bm_.free()
    head.append(hood)
    head.append(_ring(cid + "_circlet", c.z + r * 0.4, c.z + r * 0.5, r * 0.96, r * 0.93, gold, 1.0, 14, c.y - r * 0.02))
    hl, hr = cfg["horn"]
    head += _horns(cid, c, r, M, hl, hr, {"matriarch": 2, "vessaline": 1, "countess": 1}.get(kind, 0))

    # ---------------- tronco: faixa do peito, gola e cinto de ouro com a lágrima ----------------
    chest.append(_ring(cid + "_wrap", zc - 0.035, zu + 0.005, b["chest"] * 1.1, b["upper"] * 1.13, rose))
    chest.append(_ring(cid + "_collar", zn - 0.035, zn + 0.02, b["neck"] * 1.9, b["neck"] * 1.45, gold, 0.9))
    zb = zp + 0.07                                     # cinto baixo, onde o quadril alarga
    rb = b["pelvis"] * 1.1
    hips.append(_ring(cid + "_belt", zb - 0.02, zb + 0.025, rb * 1.03, rb * 0.98, gold))
    hips.append(ck.ball(cid + "_beltgem", 0.03, V((0, -rb * 0.87, zb - 0.03)), glow, (0.8, 0.6, 1.5)))
    for s, sx in ((".R", -1), (".L", 1)):
        wr, el = V(j["wrist" + s]), V(j["elbow" + s])
        arms[s].append(ck.tube("%s_bracelet%s" % (cid, s[1]), wr.lerp(el, 0.22), wr.lerp(el, 0.02), b["wrist"] * 1.45, b["wrist"] * 1.6, gold, 8))
        an = V(j["ankle" + s])
        shins[s].append(ck.tube("%s_anklet%s" % (cid, s[1]), an + V((0, 0, 0.035)), an + V((0, 0, 0.065)), b["ankle"] * 1.5, b["ankle"] * 1.4, gold, 8))

    # ---------------- variantes ----------------
    if kind == "seductress":
        # dois véus compridos que saem do capuz e um curto no meio; capinha de pontas nos ombros
        for sx in (-1, 1):
            head.append(_veil("%s_veil%d" % (cid, sx), c + V((sx * r * 0.5, r * 1.2, -r * 0.42)), V((sx * 0.3, back + 0.42, Z["knee"] + 0.12)),
                              r * 0.8, r * 0.55, pale, (sx * 0.05, 0.1, 0)))
        head.append(_veil(cid + "_veilmid", c + V((0, r * 1.3, -r * 0.36)), V((0, back + 0.3, zw - 0.02)), r * 1.2, r * 0.8, rose, (0, 0.07, 0)))
        chest.append(_skirt(cid + "_capelet", zu + 0.075, zc + 0.0, b["neck"] * 1.5, b["shoulder"] + 0.1, deep, 12, 0.05, 0.0, 0.8, 2))
        skinned.append(_skirt(cid + "_skirt_in", zb, Z["knee"] - 0.04, rb, rb * 1.7, pale, 14, 0.07, 0.55))
        skinned.append(_skirt(cid + "_skirt_out", zb + 0.01, Z["knee"] + 0.12, rb * 1.05, rb * 1.75, rose, 14, 0.07, 0.8))
        for s, sx in ((".R", -1), (".L", 1)):          # garras de ouro
            tip = V(j["hand_tip" + s])
            for i in (-1, 0, 1):
                hands[s].append(cone("%s_claw%s%d" % (cid, s[1], i), tip + V((0, i * 0.024, 0.0)), tip + V((sx * 0.01, i * 0.034 - 0.035, -0.12)), 0.017, gold2, 5))
    elif kind == "flayer":
        # véu-capa em duas camadas (a de fora mais curta e escura), fecho de ouro nos ombros
        chest.append(_veil(cid + "_cape_in", V((0, back + 0.03, zu + 0.05)), V((0, back + 0.4, Z["knee"] - 0.02)), sw * 2.5, sw * 4.6, pale, (0, 0.06, 0), 5, 0.3))
        chest.append(_veil(cid + "_cape_out", V((0, back + 0.05, zu + 0.07)), V((0, back + 0.34, zp + 0.02)), sw * 2.8, sw * 4.4, deep, (0, 0.07, 0), 4, 0.35))
        for sx in (-1, 1):
            chest.append(_veil("%s_cape_tail%d" % (cid, sx), V((sx * sw * 1.0, back + 0.06, zu + 0.04)), V((sx * (sw + 0.28), back + 0.3, Z["knee"] + 0.1)),
                               sw * 1.1, sw * 1.3, rose, (sx * 0.04, 0.06, 0), 4, 0.15))
            chest.append(ck.ball("%s_clasp%d" % (cid, sx), 0.05, V((sx * (b["shoulder"] - 0.01), 0.01, zu + 0.06)), gold2, (1.1, 1.0, 0.7)))
        skinned.append(_skirt(cid + "_skirt_in", zb, Z["knee"] + 0.0, rb, rb * 1.55, rose, 14, 0.07, 0.35))
        skinned.append(_skirt(cid + "_skirt_out", zb + 0.01, Z["knee"] + 0.17, rb * 1.05, rb * 1.6, deep, 14, 0.06, 0.6))
        # chicote de fitas-lâmina (mão direita): cabo de ouro e três fitas de aço deitadas em arco, ponta de lâmina
        g = V(ck.hand_center(base, ".R"))
        h0 = g + V((0, 0.07, 0.0))
        h1 = g + V((0, -0.2, 0.02))
        hands[".R"] += [ck.tube(cid + "_whip_grip", h0, h1, 0.024, 0.02, gold, 6), ck.ball(cid + "_whip_pommel", 0.036, h0, gold2),
                        ck.tube(cid + "_whip_neck", h1, h1 + V((0, -0.05, 0.005)), 0.034, 0.02, gold2, 6)]
        path = ((0, 0, 0), (-0.04, -0.3, 0.04), (-0.24, -0.56, 0.06), (-0.55, -0.64, 0.04), (-0.82, -0.46, 0.0), (-0.94, -0.14, -0.04))
        for i, (k, dz) in enumerate(((1.0, 0.0), (0.78, 0.06), (1.18, -0.05))):
            pts = [h1 + V((x * k, y * k, z_ + dz * (n_ / 5.0))) for n_, (x, y, z_) in enumerate(path)]
            hands[".R"].append(_band("%s_whip_ribbon%d" % (cid, i), pts, (0.05, 0.08, 0.085, 0.075, 0.06, 0.045), 0.014, M["steel"] if i != 1 else rose, flat=True))
            d = (pts[-1] - pts[-2]).normalized()
            hands[".R"].append(ck.blade("%s_whip_tip%d" % (cid, i), pts[-1] - d * 0.02, pts[-1] + d * 0.2, 0.085, 0.014, gold2, d.cross(V((0, 0, 1))), 0.3))
    elif kind == "singer":
        # véu do rosto: do aro da testa até o peito, com a lágrima pintada no pano; dois véus de ombro e mangas de véu
        v0, v1 = c + V((0, -r * 1.08, r * 0.42)), V((0, front - 0.13, zc + 0.0))
        head.append(_veil(cid + "_faceveil", v0, v1, r * 1.45, r * 1.0, rose, (0, -0.035, 0), 5, 0.3))
        head.append(ck.tube(cid + "_veilbar", v0 + V((-r * 0.75, 0.01, 0.0)), v0 + V((r * 0.75, 0.01, 0.0)), 0.02, 0.02, gold2, 6))
        tp = v0.lerp(v1, 0.36) + V((r * 0.3, -0.05, 0))
        head += [ck.ball(cid + "_veiltear", 0.028, tp, glow, (0.8, 0.5, 2.6)), ck.ball(cid + "_veildrop", 0.042, tp + V((0, -0.004, -0.085)), glow, (1.0, 0.5, 1.3))]
        for sx in (-1, 1):
            head.append(_veil("%s_veil%d" % (cid, sx), c + V((sx * r * 0.55, r * 1.2, -r * 0.42)), V((sx * 0.22, back + 0.3, zp)), r * 0.75, r * 0.5, rose, (sx * 0.04, 0.08, 0)))
        head.append(_veil(cid + "_veilmid", c + V((0, r * 1.3, -r * 0.36)), V((0, back + 0.36, Z["knee"] + 0.1)), r * 1.1, r * 0.9, pale, (0, 0.09, 0), 5))
        for s, sx in ((".R", -1), (".L", 1)):
            wr = V(j["wrist" + s])
            arms[s].append(_veil("%s_sleeve%s" % (cid, s[1]), wr + V((sx * 0.02, 0.03, 0.05)), wr + V((sx * 0.07, 0.12, -0.3)), 0.1, 0.16, rose, (sx * 0.02, 0.03, 0), 3, 0.2))
            hands[s].append(ck.ball("%s_note%s" % (cid, s[1]), 0.04, V(j["hand_tip" + s]) + V((0, -0.035, -0.02)), glow))
        skinned.append(_skirt(cid + "_skirt_in", zb, Z["ankle"] + 0.13, rb, rb * 1.5, pale, 16, 0.06))
        skinned.append(_skirt(cid + "_skirt_out", zb + 0.01, Z["knee"] + 0.04, rb * 1.05, rb * 1.62, rose, 16, 0.08))
    elif kind == "matriarch":
        # coroa de fitas (laços em volta do alto da cabeça), pires nos ombros, saia de três camadas, cauda de véus no chão
        for i in range(5):                             # laços de fita (alças redondas + nó de ouro), não pontas: 1 na frente, 4 em volta
            a = -math.pi / 2 + math.tau * i / 5
            o_ = V((math.cos(a), math.sin(a), 0))
            p = hc + o_ * r * 0.76 + V((0, 0, r * 0.9))
            head += _bow("%s_crown%d" % (cid, i), p, o_, r * (0.5 if i == 0 else 0.42), pale if i % 2 == 0 else rose, gold2, deep)
        head.append(_ring(cid + "_crownband", hc.z + r * 0.84, hc.z + r * 0.93, r * 0.76, r * 0.66, gold2, 1.0, 14, hc.y))
        head += _bow(cid + "_crowntop", hc + V((0, 0, r * 1.16)), (0, -1, 0), r * 0.46, rose, gold2, pale)
        head.append(_veil(cid + "_veilmid", c + V((0, r * 1.3, -r * 0.36)), V((0, back + 0.34, zp)), r * 1.5, r * 1.3, pale, (0, 0.08, 0), 4, 0.5))
        LM = dict(M, t=rose)
        for sx in (-1, 1):
            chest += lk.saucers(ck, "%s_saucer%d" % (cid, sx), V((sx * (b["shoulder"] + 0.01), 0.0, zu + 0.035)), 0.135, 3, LM, 0.04, 0.22, (sx * 0.3, 0, 1),
                                [M["porc"], rose])
        chest.append(_veil(cid + "_cape", V((0, back + 0.04, zu + 0.04)), V((0, back + 0.36, zp - 0.04)), sw * 2.6, sw * 4.2, deep, (0, 0.06, 0), 4, 0.4))
        for s, sx in ((".R", -1), (".L", 1)):
            wr = V(j["wrist" + s])
            arms[s].append(_veil("%s_sleeve%s" % (cid, s[1]), wr + V((sx * 0.02, 0.03, 0.06)), wr + V((sx * 0.08, 0.14, -0.3)), 0.11, 0.18, pale, (sx * 0.02, 0.03, 0), 3, 0.2))
            tip = V(j["hand_tip" + s])
            for i in (-1, 0, 1):
                hands[s].append(cone("%s_claw%s%d" % (cid, s[1], i), tip + V((0, i * 0.024, 0.0)), tip + V((sx * 0.01, i * 0.034 - 0.035, -0.12)), 0.018, gold2, 5))
        skinned.append(_skirt(cid + "_skirt_in", zb, Z["ankle"] + 0.13, rb, rb * 1.55, pale, 16, 0.06))
        skinned.append(_skirt(cid + "_skirt_mid", zb + 0.005, Z["knee"] - 0.01, rb * 1.04, rb * 1.72, rose, 16, 0.09))
        skinned.append(_skirt(cid + "_skirt_out", zb + 0.01, zp - 0.1, rb * 1.08, rb * 1.62, deep, 16, 0.08))
        _train(cid, rig, M, back, zb, 1.5, ((-0.42, pale, 0.86), (0.0, rose, 1.0), (0.42, pale, 0.86)), 0.46, 0.34, blades=False)
    elif kind == "countess":
        mir, mir2 = m("mirror", MIRROR, 0.15), m("mirror2", MIRROR_LIGHT, 0.15)
        # máscara das costas (olhos fechados em risco de ouro, a lágrima do outro lado), espelho oval de pé no alto, véus dos lados
        mb = lk.mask(ck, cid + "_maskb", c + V((0, r * 0.76, -r * 0.1)), r * 0.74, M, facing=(0, 1, 0), tears=(1,), eyes=False)
        for o in mb:                                   # olhos fechados em tinta: o risco de ouro some na porcelana
            if "_lid" in o.name:
                o.data.materials[0] = M["ink"]
        head += mb
        top = hc + V((0, 0, r * 1.48))
        head += [ck.ball(cid + "_crest_frame", 1.0, top, gold2, (r * 0.4, 0.022, r * 0.52)),
                 ck.ball(cid + "_crest_glass", 1.0, top, mir, (r * 0.31, 0.034, r * 0.43)),
                 ck.tube(cid + "_crest_stem", hc + V((0, 0, r * 0.95)), hc + V((0, 0, r * 1.1)), r * 0.16, r * 0.1, gold, 6)]
        for sx in (-1, 1):
            head.append(_veil("%s_veil%d" % (cid, sx), c + V((sx * r * 0.86, r * 0.62, -r * 0.62)), V((sx * 0.2, back + 0.3, Z["knee"] + 0.14)),
                              r * 0.5, r * 0.36, pale, (sx * 0.03, 0.08, 0)))
            sp = V((sx * (b["shoulder"] + 0.015), 0.0, zu + 0.06))          # ombreira: espelho oval deitado, virado para cima
            chest += [ck.ball("%s_pauld%d" % (cid, sx), 1.0, sp, gold2, (0.125, 0.105, 0.03)),
                      ck.ball("%s_pauld_glass%d" % (cid, sx), 1.0, sp + V((0, 0, 0.014)), mir if sx < 0 else mir2, (0.095, 0.078, 0.028))]
        chest.append(_ring(cid + "_ruff", zn - 0.03, zn + 0.075, b["neck"] * 1.5, b["neck"] * 2.5, pale, 0.9))
        chest += [ck.blade(cid + "_brooch", V((0, front - 0.035, zu + 0.03)), V((0, front - 0.04, zc - 0.09)), 0.17, 0.024, gold2, (1, 0, 0), 0.4),
                  ck.blade(cid + "_brooch_glass", V((0, front - 0.05, zu + 0.005)), V((0, front - 0.055, zc - 0.06)), 0.115, 0.024, mir2, (1, 0, 0), 0.4)]
        # saia-sino: anágua escura, duas fileiras de painéis de espelho em moldura de ouro (em tijolo), barra de pontas por cima
        z1s, r1s = Z["ankle"] + 0.15, rb * 2.15
        skinned.append(_skirt(cid + "_skirt_in", zb, z1s, rb, r1s, deep, 16, 0.04))

        def sk(a, t, off):
            rr = rb + (r1s - rb) * t ** 0.8 + off
            return V((math.cos(a) * rr, math.sin(a) * rr * 0.85, zb + (z1s - zb) * t))

        for row, (t0, t1, n_, ph) in enumerate(((0.16, 0.52, 8, 0.0), (0.56, 0.98, 8, 0.5))):
            for i in range(n_):
                a = -math.pi / 2 + math.tau * (i + ph) / n_
                tang = (-math.sin(a), math.cos(a), 0)
                wd = lambda t: math.tau * (rb + (r1s - rb) * t ** 0.8) / n_
                tm = (t0 + t1) * 0.5
                skinned.append(_band("%s_panel%d_%d" % (cid, row, i), [sk(a, t0, 0.018), sk(a, tm, 0.024), sk(a, t1, 0.018)],
                                     [wd(t0) * 0.86, wd(tm) * 0.9, wd(t1) * 0.86], 0.02, gold, tang))
                ta, tb = t0 + (t1 - t0) * 0.12, t1 - (t1 - t0) * 0.12
                skinned.append(_band("%s_glass%d_%d" % (cid, row, i), [sk(a, ta, 0.03), sk(a, tm, 0.036), sk(a, tb, 0.03)],
                                     [wd(ta) * 0.62, wd(tm) * 0.66, wd(tb) * 0.62], 0.016, mir if (i + row) % 2 else mir2, tang))
        skinned.append(_skirt(cid + "_skirt_out", zb + 0.01, zb - 0.085, rb * 1.1, rb * 1.5, rose, 16, 0.06))
        # florete (mão direita): copo e arco de ouro, lâmina fina e comprida; garras de ouro na esquerda
        g = V(ck.hand_center(base, ".R"))
        h0, h1 = g + V((0, 0.085, 0.0)), g + V((0, -0.07, 0.0))
        hands[".R"] += [ck.tube(cid + "_foil_grip", h0, h1, 0.022, 0.02, gold, 6), ck.ball(cid + "_foil_pommel", 0.036, h0, gold2),
                        ck.ball(cid + "_foil_cup", 0.085, h1 + V((0, -0.01, 0)), gold2, (1.0, 0.5, 1.0)),
                        ck.tube(cid + "_foil_bow", h1 + V((0, -0.02, -0.075)), h0 + V((0, 0.0, -0.03)), 0.012, 0.012, gold2, 4),
                        ck.blade(cid + "_foil_blade", h1 + V((0, -0.03, 0)), h1 + V((0, -1.02, 0.0)), 0.06, 0.026, M["steel"], (1, 0, 0), 0.1),
                        ck.ball(cid + "_foil_tip", 0.024, h1 + V((0, -1.02, 0.0)), glow)]
        tip = V(j["hand_tip.L"])
        for i in (-1, 0, 1):
            hands[".L"].append(cone("%s_clawL%d" % (cid, i), tip + V((0, i * 0.024, 0.0)), tip + V((0.01, i * 0.034 - 0.035, -0.12)), 0.017, gold2, 5))
    else:                                              # vessaline
        # pente de ouro atrás da cabeça, gola alta, mangas de véu, vestido inteiro e a cauda de fitas-lâmina
        for i in range(5):
            a = (i - 2) * 0.3
            p = hc + V((math.sin(a) * r * 0.55, r * 0.6, r * 0.8))
            head.append(ck.blade("%s_comb%d" % (cid, i), p, p + V((math.sin(a) * r * 0.85, r * 0.8, r * (0.42 - 0.07 * abs(i - 2)))), r * 0.3, 0.016, gold2, (math.cos(a), 0, -math.sin(a) * 0.3), 0.55))
        head.append(_veil(cid + "_veilmid", c + V((0, r * 1.3, -r * 0.36)), V((0, back + 0.4, zp + 0.02)), r * 1.5, r * 1.2, pale, (0, 0.09, 0), 5, 0.4))
        for sx in (-1, 1):
            head.append(_veil("%s_veil%d" % (cid, sx), c + V((sx * r * 0.55, r * 1.2, -r * 0.42)), V((sx * 0.34, back + 0.36, zw)), r * 0.7, r * 0.5, rose, (sx * 0.05, 0.08, 0)))
            chest.append(ck.blade("%s_collarfan%d" % (cid, sx), V((sx * sw * 0.5, back * 0.5, zn - 0.02)), V((sx * (sw + 0.16), back + 0.1, zn + 0.2)), 0.2, 0.016, gold, (0, 1, 0.2), 0.5))
        for s, sx in ((".R", -1), (".L", 1)):
            wr = V(j["wrist" + s])
            arms[s].append(_veil("%s_sleeve%s" % (cid, s[1]), wr + V((sx * 0.02, 0.03, 0.07)), wr + V((sx * 0.1, 0.16, -0.38)), 0.11, 0.2, pale, (sx * 0.02, 0.03, 0), 3, 0.2))
            tip = V(j["hand_tip" + s])
            for i in (-1, 0, 1):
                hands[s].append(cone("%s_claw%s%d" % (cid, s[1], i), tip + V((0, i * 0.024, 0.0)), tip + V((sx * 0.01, i * 0.034 - 0.04, -0.14)), 0.017, gold2, 5))
        skinned.append(_skirt(cid + "_skirt_in", zb, Z["ankle"] + 0.13, rb, rb * 1.6, pale, 16, 0.05))
        skinned.append(_skirt(cid + "_skirt_mid", zb + 0.005, Z["knee"] + 0.05, rb * 1.04, rb * 1.78, rose, 16, 0.1))
        skinned.append(_skirt(cid + "_skirt_out", zb + 0.01, zp - 0.1, rb * 1.08, rb * 1.6, gold, 16, 0.1))
        spec = []
        for i in range(7):
            u = (i - 3) / 3.0
            spec.append((u * 0.62, M["steel"] if i % 2 == 0 else rose, 1.0 - 0.3 * abs(u)))
        _train(cid, rig, M, back, zb, TAIL_LEN, spec, 0.24, 0.12, blades=True)

    # ---------------- pesos ----------------
    ck._rigid(bs._outward(head), rig, "head")
    ck._rigid(bs._outward(chest), rig, "chest")
    ck._rigid(bs._outward(hips), rig, "hips")
    for s in (".R", ".L"):
        ck._rigid(bs._outward(arms[s]), rig, "forearm" + s)
        ck._rigid(bs._outward(hands[s]), rig, "hand" + s)
        ck._rigid(bs._outward(shins[s]), rig, "shin" + s)
    lk.skinned(ck, base, bs._outward(skinned))

    # ---------------- clipes ----------------
    ck.mob_clips(rig, None, None, ATTACK[kind], boss=kind in ("matriarch", "vessaline") and False, extra_keep=CLIPS[kind])
    _hips_scale(rig, Z["pelvis"] / 0.38)
    if kind == "singer":
        act2_bosses.carry(rig, SINGER_CARRY)
    if kind == "flayer":
        act2_bosses.clear_ground(rig, {"*": 0.03, "die": -0.1}, "hand.R", (cid + "_whip",), front=True)
    if kind == "countess":
        act2_bosses.clear_ground(rig, {"*": 0.03, "die": -0.1}, "hand.R", (cid + "_foil",), front=True)
    act2_bosses.clear_ground(rig, {"die": -0.02}, "head", (cid + "_horn",))
    if tailed:
        _tail_anim(rig)
    _join(cid, rig, cid + "_body")
    return rig


def _skin_grad(obj, rig, z_lo, z_hi):
    """Pesos em rampa pela altura: no alto segue o quadril, no chão o osso `tail` (o pano estica entre os dois)."""
    ck._smooth(obj.data)
    gh, gt = obj.vertex_groups.new(name="hips"), obj.vertex_groups.new(name="tail")
    for v in obj.data.vertices:
        w = min(1.0, max(0.0, (v.co.z - z_lo) / (z_hi - z_lo)))
        if w > 0.001:
            gh.add([v.index], w, "REPLACE")
        if w < 0.999:
            gt.add([v.index], 1.0 - w, "REPLACE")
    obj.parent = rig
    obj.modifiers.new("rig", "ARMATURE").object = rig


def _train(cid, rig, M, back, zb, length, spec, w0, w1, blades):
    """Cauda que arrasta no chão. spec = [(ângulo em rad a partir de +Y, material, fração do comprimento)]. Cada fita desce
    do cinto ao chão e segue deitada; o trecho deitado pesa no osso `tail` (não tomba com o corpo na morte) e a descida
    vai em rampa do quadril ao `tail` (_skin_grad): agachar estica o pano em vez de enterrá-lo."""
    n = len(spec)
    out = []
    for i, (ang, mat_, frac) in enumerate(spec):
        d = V((math.sin(ang), math.cos(ang), 0))
        side = V((d.y, -d.x, 0))
        zg = 0.03 + 0.012 * ((i * 3) % n)              # cada fita no seu plano: sem z-fight onde se cruzam
        L = length * frac
        pts = [V((math.sin(ang) * 0.08, back + 0.04, zb - 0.02)), d * 0.36 + V((0, 0.06, zb * 0.5)), d * 0.62 + V((0, 0, zg + 0.07))]
        widths = [w0 * 0.5, w0 * 0.8, w0]
        segs = max(4, int(L / 0.35))
        ph = i * 1.9
        for k in range(segs + 1):
            t = k / segs
            dist = 0.85 + t * (L - 0.85)
            lat = (0.05 + 0.035 * L) * math.sin(t * math.tau * 1.15 + ph) * min(1.0, t * 3)
            pts.append(d * dist + side * lat + V((0, 0, zg)))
            widths.append(w0 + (w1 - w0) * t)
        out.append(_band("%s_train%d" % (cid, i), pts, widths, 0.014, mat_, flat=True))
        e = (pts[-1] - pts[-2]).normalized()
        if blades:                                     # ponta de lâmina em ouro e um filete de ouro no dorso
            out.append(ck.blade("%s_trainblade%d" % (cid, i), pts[-1] - e * 0.03, pts[-1] + e * 0.42, w1 * 2.4, 0.016, M["gold2"], e.cross(V((0, 0, 1))), 0.35))
            out.append(_band("%s_trainedge%d" % (cid, i), [p + V((0, 0, 0.012)) for p in pts], [w * 0.22 for w in widths], 0.008, M["gold"], flat=True))
        else:
            out.append(ck.ball("%s_trainend%d" % (cid, i), w1 * 0.5, pts[-1], mat_, (1.0, 1.0, 0.06)))
    for o in bs._outward(out):
        _skin_grad(o, rig, 0.12, zb - 0.05)


def seductress(cid="mob_seductress"):
    return demoness(cid, "seductress")


def flayer(cid="mob_flayer"):
    return demoness(cid, "flayer")


def veil_singer(cid="mob_veil_singer"):
    return demoness(cid, "singer")


def thirst_matriarch(cid="mob_thirst_matriarch"):
    return demoness(cid, "matriarch")


def vessaline(cid="mob_vessaline"):
    return demoness(cid, "vessaline")


def countess(cid="mob_countess"):
    return demoness(cid, "countess")


# ---------------------------------------------------------------------------
# Espelho de Pé (lacaio parado da Condessa: a cobertura do Olhar Que Julga)
# ---------------------------------------------------------------------------
MIRROR_BONES = {            # ossos todos de pé (eixos locais: x = X, y = para cima, z = -Y), nomes de MOB_BONES + "core"
    "root": ((0, 0, 0), (0, 0, 0.2), None),                 # cavalete: pés, montantes e pinos; nunca se mexe
    "body": ((0, 0, 1.15), (0, 0, 1.5), "root"),            # moldura + fundo: bascula nos pinos (espelho de cavalete)
    "head": ((0, 0, 2.0), (0, 0, 2.25), "body"),            # remate: mascarazinha com a lágrima e chifres para trás
    "arm_r": ((0, 0, 1.6), (0, 0, 1.9), "body"),            # vidro de cima (cai no die)
    "arm_l": ((0, 0, 0.8), (0, 0, 1.1), "body"),            # vidro de baixo
    "core": ((0, 0.02, 1.2), (0, 0.02, 1.45), "body"),      # vidro rachado (chapa escura em lascas): escala ~0 = espelho inteiro
    "floor": ((0.06, -0.03, 1.2), (0.06, -0.03, 1.45), "root"),   # cacos no chão: nascem no ponto do impacto (escala ~0) e caem
}
MIRROR_TILT = -7.0          # graus: o espelho descansa um pouco deitado para trás (a câmera alta vê o vidro)
MIRROR_DULL = [(0.11, 0.12, 0.18), (0.17, 0.19, 0.27), (0.24, 0.27, 0.36)]     # vidro rachado: ardósia fria, bem abaixo do MIRROR
MIRROR_HOLE = (9, 10)       # lascas que faltam (índices do leque de standing_mirror): vão preto no canto de cima e no lado -X (o véu fica em +X)
MIRROR_KEPT = (13,)         # lascas que ainda espelham (claro contra o escuro: lê como vidro partido, não como espelho apagado)
MIRROR_CROOK = ((-9, 0, 3), (10, 0, 26))       # rachado: a moldura fica mais deitada e torta; o remate pende de lado
MIRROR_SHARDS = [           # cacos no chão: (x, y, raio, lados, giro)
    (-0.08, -0.5, 0.2, 4, 0.3), (0.3, -0.62, 0.17, 3, 1.1), (-0.4, -0.7, 0.16, 4, 2.0), (0.08, -0.86, 0.19, 3, 0.7),
    (0.52, -0.95, 0.13, 4, 1.6), (-0.3, -1.08, 0.15, 3, 2.6), (-0.66, -0.98, 0.11, 3, 0.2), (0.26, -1.22, 0.12, 4, 0.9),
    (0.74, -0.6, 0.1, 3, 2.2), (-0.72, -0.45, 0.1, 3, 1.4), (-0.02, -1.36, 0.09, 3, 0.5)]


def standing_mirror(cid="mob_standing_mirror"):
    """Espelho de cavalete (~2,3 m): moldura em arco de ouro velho, vidro frio em duas peças (a emenda é a rachadura maior),
    remate com a máscara da lágrima e chifres para trás, véu rosa caído num canto. Frente = -Y."""
    arm = mk.lp.make_armature("rig_" + cid, MIRROR_BONES)
    m = lambda n, col, rough=0.7, em=0.0: ck.mat("m_%s_%s" % (cid, n), col, rough, em)
    M = {"porc": m("mask", MASK, 0.3), "gold": m("gold", OLD_GOLD, 0.4), "gold2": m("gold2", BRIGHT_GOLD, 0.35), "ink": m("ink", INK, 0.6),
         "glow": m("tear", ROSE_TEAR, 0.3, 2.2)}
    gold, gold2 = M["gold"], M["gold2"]
    mir, mir2 = m("mirror", MIRROR, 0.15), m("mirror2", MIRROR_LIGHT, 0.15)
    backm, veil = m("back", (0.5, 0.28, 0.4), 0.8), m("veil", (0.82, 0.56, 0.6), 0.8)
    parts = []                      # (objeto, osso)
    w, z0, z1, hh = 0.42, 0.4, 1.55, 0.46
    arch = [(w * math.cos(math.pi * k / 8), z1 + hh * math.sin(math.pi * k / 8)) for k in range(9)]       # de +X a -X
    zl, zr = 1.0, 1.32              # a emenda dos dois vidros (rachadura maior)
    # cavalete (root)
    for sx in (-1, 1):
        x = sx * (w + 0.1)
        parts += [(ck.tube("foot%d" % sx, (x, -0.36, 0.07), (x, 0.4, 0.07), 0.06, 0.06, gold, 6), "root"),
                  (ck.ball("foot_a%d" % sx, 0.075, (x, -0.36, 0.08), gold2), "root"), (ck.ball("foot_b%d" % sx, 0.075, (x, 0.4, 0.08), gold2), "root"),
                  (ck.tube("post%d" % sx, (x, 0.02, 0.05), (x, 0.02, 1.2), 0.045, 0.038, gold, 6), "root"),
                  (ck.ball("pin%d" % sx, 0.07, (x, 0.02, 1.2), gold2), "root"),
                  (ck.tube("axle%d" % sx, (x, 0.02, 1.15), (sx * w, 0.02, 1.15), 0.03, 0.03, gold2, 5), "root")]
    parts.append((ck.tube("stretcher", (-(w + 0.1), 0.22, 0.12), (w + 0.1, 0.22, 0.12), 0.035, 0.035, gold, 5), "root"))
    # moldura + fundo (body)
    outline = [(w, z0)] + arch + [(-w, z0)]
    for i in range(len(outline)):
        (xa, za), (xb, zb_) = outline[i], outline[(i + 1) % len(outline)]
        parts.append((ck.tube("frame%d" % i, (xa, 0, za), (xb, 0, zb_), 0.06, 0.06, gold, 6), "body"))
        parts.append((ck.ball("frame_j%d" % i, 0.062, (xa, 0, za), gold), "body"))
    parts.append((_plate("backboard", [(-w, z0), (w, z0)] + arch, 0.035, 0.03, backm), "body"))
    for sx in (-1, 1):
        parts.append((ck.ball("corner%d" % sx, 0.085, (sx * w, -0.01, z0), gold2), "body"))
    parts.append((_veil("drape", V((0.26, 0.07, z1 + hh * 0.86)), V((w + 0.1, 0.3, 0.75)), 0.34, 0.26, veil, (0.1, 0.06, 0), 4, 0.3), "body"))
    # vidro em duas peças + brilhos
    parts.append((_plate("glass_lo", [(-w, z0), (w, z0), (w, zr), (-w, zl)], 0.0, 0.03, mir), "arm_l"))
    parts.append((_plate("glass_hi", [(-w, zl), (w, zr)] + arch, 0.0, 0.03, mir), "arm_r"))
    parts.append((_plate("glint_hi", [(-0.26, 1.42), (-0.16, 1.42), (0.06, 1.86), (-0.04, 1.86)], -0.014, 0.012, mir2), "arm_r"))
    parts.append((_plate("glint_lo", [(0.08, 0.56), (0.2, 0.56), (0.34, 0.94), (0.22, 0.94)], -0.014, 0.012, mir2), "arm_l"))
    # estado rachado (core + floor; escala ~0 = espelho inteiro). De cima (52 graus, 24 m) risco fino some: o que se lê é o
    # vidro claro virar chapa ESCURA em lascas, um vão preto que atravessa até as costas e os cacos claros no chão à frente.
    ink = M["ink"]
    dull = [m("dull%d" % i, c, 0.6) for i, c in enumerate(MIRROR_DULL)]
    hit = (0.06, 1.2)
    rim = [(w, z0), (w, 1.0)] + arch + [(-w, 0.95), (-w, z0), (-0.1, z0)]
    for i in range(len(rim)):
        pa, pb = rim[i], rim[(i + 1) % len(rim)]
        hole = i in MIRROR_HOLE
        mat_ = ink if hole else (mir if i in MIRROR_KEPT else dull[(i * 2 + i // 3) % len(dull)])
        parts.append((_plate("facet%d" % i, [hit, pa, pb], -0.03, 0.012, mat_), "core"))
        if hole:                    # o mesmo vão nas costas (quem olha por trás também vê o furo)
            parts.append((_plate("facet_back%d" % i, [hit, pa, pb], 0.058, 0.012, ink), "core"))
        if i % 2 == 0 or hole:      # fraturas: fio claro na frente, risco escuro no fundo de madeira
            parts.append((ck.tube("crack%d" % i, (hit[0], -0.04, hit[1]), (pa[0], -0.04, pa[1]), 0.02, 0.012, mir2, 4), "core"))
            parts.append((ck.tube("crack_back%d" % i, (hit[0], 0.056, hit[1]), (pa[0], 0.056, pa[1]), 0.018, 0.012, ink, 4), "core"))
    for i, (cx, cy, r, n, a0) in enumerate(MIRROR_SHARDS):          # cacos deitados no chão, à frente (-Y)
        pts = [(cx + r * (0.65 + 0.35 * ((k * 7 + i * 3) % 4) / 3.0) * math.cos(a0 + math.tau * k / n),
                cy + r * (0.65 + 0.35 * ((k * 5 + i) % 3) / 2.0) * math.sin(a0 + math.tau * k / n)) for k in range(n)]
        parts.append((_floor_plate("shard%d" % i, pts, 0.012 + 0.005 * i, 0.02, mir2 if i % 3 else mir), "floor"))
    # remate (head)
    cc = V((0, 0.0, z1 + hh + 0.13))
    for o in lk.mask(ck, "crest_mask", cc + V((0, -0.06, 0)), 0.13, M, tears=(1,)) + _horns("crest", cc + V((0, 0.0, -0.06)), 0.15, M, 1.7, 0.25):
        parts.append((o, "head"))
    parts.append((ck.ball("crest_boss", 0.13, cc + V((0, 0.02, 0)), gold2, (1.25, 0.6, 1.25)), "head"))
    # descanso deitado para trás, em volta dos pinos
    rot = Euler((math.radians(MIRROR_TILT), 0, 0)).to_matrix()
    piv = V((0, 0.02, 1.15))
    for obj, bone in parts:
        if bone not in ("root", "floor"):
            for v in obj.data.vertices:
                v.co = piv + rot @ (v.co - piv)
        flat = bone != "head" and not obj.name.startswith(("foot_", "pin", "corner", "frame_j", "drape"))
        for p in obj.data.polygons:
            p.use_smooth = not flat
        mk.lp.attach(obj, arm, bone)

    # clipes. rot X+ = tomba para a frente (-Y); loc = (x, para cima, -Y). `core`/`floor` têm escala em TODO clipe (nada a herdar).
    z, one, nil = (0, 0, 0), (1, 1, 1), (0.001, 0.001, 0.001)
    add = mk.lp.add_action
    still = lambda end, sc: {"head": [(1, z, z), (end, z, z)], "arm_r": [(1, z, z), (end, z, z)], "arm_l": [(1, z, z), (end, z, z)],
                             "core": [(1, z, z, sc), (end, z, z, sc)], "floor": [(1, z, z, sc), (end, z, z, sc)]}
    sway = [(1, z, z), (16, (0.7, 0, 0), z), (32, z, z), (48, (-0.7, 0, 0), z), (64, z, z)]
    (bx, by, bz), (hx, hy, hz) = MIRROR_CROOK
    crook = [(f, (bx + d, by, bz), z) for f, d in ((1, 0), (16, 0.6), (32, 0), (48, -0.6), (64, 0))]         # torta e mais deitada
    droop = [(f, (hx, hy, hz + d), z) for f, d in ((1, 0), (20, 2.5), (40, 0), (52, -1.5), (64, 0))]         # remate pendurado
    add(arm, "idle", dict(still(64, nil), body=sway), 64)
    add(arm, "idle_cracked", dict(still(64, one), body=crook, head=droop), 64)
    add(arm, "run", dict(still(32, nil), body=[(1, z, z), (32, z, z)]), 32)
    add(arm, "attack", dict(still(14, nil), body=[(1, z, z), (14, z, z)]), 14, loop=False)
    swing = [(1, (-10, 0, 0), z), (4, (8, 0, 0), z), (8, (-5, 0, 0), z), (12, (2.5, 0, 0), z), (16, z, z)]      # bascula nos pinos e amortece
    add(arm, "hit", dict(still(16, nil), body=swing, head=[(1, (6, 0, 0), z), (4, (-8, 0, 3), z), (8, (5, 0, -2), z), (16, z, z)]), 16, loop=False)
    # crack: tranco, o vidro escurece de uma vez, os cacos saltam do impacto e caem no chão; acaba na pose do idle_cracked
    add(arm, "crack", dict(still(14, one),
                           body=[(1, z, z), (2, (-8, 0, 0), z), (4, (6, 0, 1), z), (7, (bx - 4, 0, bz + 1), z), (10, (bx + 1.5, 0, bz), z), (14, (bx, by, bz), z)],
                           head=[(1, z, z), (3, (-6, 0, -6), z), (6, (hx + 4, 0, hz + 10), z), (10, (hx, 0, hz - 4), z), (14, (hx, hy, hz), z)],
                           core=[(1, z, z, nil), (2, z, z, (0.6, 0.6, 0.6)), (3, z, z, (1.06, 1.06, 1.06)), (5, z, z, one), (14, z, z, one)],
                           floor=[(1, z, z, nil), (2, z, z, nil), (5, z, (0, 0.25, 0), (0.55, 0.55, 0.55)), (8, z, z, (1.04, 1.0, 1.04)), (10, z, z, one), (14, z, z, one)]),
        14, loop=False)
    # die: o vidro estilhaça e cai em duas peças para a frente; a moldura balança vazia e fica torta
    add(arm, "die", {
        "body": [(1, z, z), (3, (-12, 0, 0), z), (7, (9, 0, 0), z), (12, (-7, 0, 2), z), (17, (-11, 0, 3), z), (22, (-10, 0, 3), z)],
        "head": [(1, z, z), (5, (-10, 0, 4), z), (12, (8, 0, 10), z), (22, (6, 0, 14), z)],
        "arm_r": [(1, z, z), (3, (4, 0, 0), (0, 0, 0.03)), (8, (38, 0, 8), (0.04, -0.5, 0.3)), (13, (80, 0, 16), (0.08, -1.3, 0.62)),
                  (15, (84, 0, 18), (0.08, -1.36, 0.66)), (22, (84, 0, 18), (0.08, -1.36, 0.66))],
        "arm_l": [(1, z, z), (3, (3, 0, 0), (0, 0, 0.03)), (7, (30, 0, -6), (-0.03, -0.25, 0.22)), (11, (78, 0, -14), (-0.06, -0.56, 0.42)),
                  (13, (84, 0, -16), (-0.06, -0.6, 0.44)), (22, (84, 0, -16), (-0.06, -0.6, 0.44))],
        "core": [(1, z, z, one), (3, z, z, one), (6, z, z, nil), (22, z, z, nil)],
        "floor": [(1, z, z, nil), (9, z, z, nil), (13, z, z, one), (22, z, z, one)],
    }, 22, loop=False)
    return arm


BUILDERS = {
    "mob_seductress": seductress,
    "mob_flayer": flayer,
    "mob_veil_singer": veil_singer,
    "mob_thirst_matriarch": thirst_matriarch,
    "mob_vessaline": vessaline,
    "mob_countess": countess,
}
HUMANOIDS = set(BUILDERS)          # skinned (ck.export_glb); o que entra depois daqui é de peças rígidas (lp.export_glb)
BUILDERS["mob_standing_mirror"] = standing_mirror
