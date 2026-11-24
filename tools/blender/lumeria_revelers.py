"""Ato III, parte 1 (45-50) — Foliões, Reflexo e Incensário (design/gdd/ato3-excesso-45-50.md §3, coluna "Conceito de modelo").
Humanos do Festim em veludo vinho + creme (a máscara de porcelana com UMA lágrima pintada é o que os une aos demônios):

  mob_reveler          Folião Mascarado (45; também o Convidado do Banquete de Varo): gibão listrado vinho/creme, calça de
                       arlequim (uma perna de cada cor), boina com laço e fitas, máscara de MEIA-LUA no lado direito do rosto
                       (o outro olho é humano), taça de ouro na mão direita (`attack` = pancada de taça, `atk_throw` = arremesso)
  mob_convert          Convertido (47; só a forma humana, o ShiftSystem troca o modelo): curvado, máscara inteira RACHADA com as
                       rachaduras e os olhos acesos (material `glow_rose`), braço esquerdo já de porcelana com garras de ouro,
                       fitas rosa enroladas nos membros, rachaduras subindo pelo peito
  mob_ceremony_master  Mestre de Cerimônias (47, elite): alto e gordo, casaca vinho com colete creme e botões de ouro, pires
                       nos ombros, cartola enrolada em fitas com laços no topo, bigode de ouro na máscara, bastão com aro de
                       sinos na mão direita (idle de cajado: bastão em pé)
  mob_vain_reflection  Reflexo Vaidoso (48): figura CHATA de espelho (peças rígidas, flutua): vestido = moldura dourada em sino
                       com o vidro dentro e a silhueta escura de quem olha, corpete e cabeça ovais de espelho (sem olhos, só a
                       lágrima), braços = cacos compridos; fundo de madeira escura atrás. Vidro: `m_*_mirror` metálico liso.
  mob_living_censer    Incensário Vivo (47, bruto): turíbulo de bronze do tamanho de um homem (peças rígidas, flutua): bojo com
                       a máscara da lágrima, tampa furada com brasas `glow_lilac`, três correntes até a argola de cima, duas
                       correntes com pesos como PERNAS, dois turíbulos pequenos nas correntes dos lados (braços), fumaça lilás

Clipes (o que EntityView.clip_for_skill pede para as skills de cada um):
  reveler: idle run attack cast hit die block + atk_throw (mob_goblet_throw) shout jump dash
  convert: idle run attack cast (gesto da metamorfose: EntityView.shift_gesture) hit die block + shout atk_claw
  ceremony_master: idle run attack cast hit die block + atk_sweep (mob_bell_staff) shout (mob_toast_rally) buff_focus cast_ground
  vain_reflection: idle run attack hit die + shout (mob_mirror_fade: gira de perfil = some) atk_charge (mob_mirror_lunge) dash
  living_censer: idle run attack hit die + atk_spin (mob_censer_swing) cast_ground (mob_sweet_smoke: abre a tampa e despeja)
Escala sugerida (MonsterDef.scale): reveler 1,0 · convert 1,0 · ceremony_master 1,25 · vain_reflection 1,05 · living_censer 1,15.

    import mob_kit; mob_kit.build_all(r"<abs>/assets/models", only=set(lumeria_revelers.BUILDERS))
Prévia e conta de chão sem janela: tools/blender/lumeria_mobs_preview.py -- --module=lumeria_revelers --out=<pasta ABSOLUTA>.
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
import lumeria_mobs as lm

V = Vector
cone = mk.cone

WINE = (0.3, 0.045, 0.1)             # veludo vinho
WINE_DEEP = (0.17, 0.035, 0.08)
CREAM = (0.95, 0.88, 0.74)
ROSE = (0.86, 0.56, 0.62)          # fitas rosa-pó
PORC = (0.93, 0.89, 0.82)
MASK = (0.98, 0.97, 0.94)
OLD_GOLD = (0.69, 0.54, 0.24)
BRIGHT_GOLD = (0.93, 0.76, 0.36)
INK = (0.1, 0.08, 0.12)
ROSE_TEAR = (1.0, 0.45, 0.58)
BRONZE = (0.62, 0.43, 0.22)
BRONZE_DARK = (0.4, 0.27, 0.16)
LILAC = (0.76, 0.64, 0.94)
LILAC_GLOW = (0.8, 0.55, 1.0)
MIRROR = (0.7, 0.84, 0.93)
MIRROR_LIGHT = (0.9, 0.96, 1.0)
SHADE = (0.3, 0.37, 0.55)          # a silhueta de quem olha, dentro do vidro
WOOD = (0.3, 0.16, 0.2)

KINDS = {
    "reveler": {"leg": 0.07, "torso": 0.02, "hair": (0.3, 0.18, 0.14),
                "body": dict(shoulder=0.2, hip=0.085, pelvis=0.16, waist=0.14, chest=0.172, upper=0.16, arm=0.062, elbow=0.054, wrist=0.046,
                             hand=0.054, thigh=0.084, knee=0.066, ankle=0.058, toe=0.066, neck=0.058, depth=0.8, head=0.31, arm_len=1.08)},
    "convert": {"leg": 0.11, "torso": 0.03, "hair": (0.52, 0.44, 0.44),
                "body": dict(shoulder=0.185, hip=0.082, pelvis=0.15, waist=0.118, chest=0.156, upper=0.146, arm=0.054, elbow=0.046, wrist=0.04,
                             hand=0.05, thigh=0.078, knee=0.058, ankle=0.05, toe=0.06, neck=0.05, depth=0.8, head=0.3, arm_len=1.2)},
    "master": {"leg": 0.1, "torso": 0.1, "hair": (0.2, 0.14, 0.14),
               "body": dict(shoulder=0.255, hip=0.115, pelvis=0.25, waist=0.275, chest=0.25, upper=0.205, arm=0.088, elbow=0.074, wrist=0.06,
                            hand=0.068, thigh=0.115, knee=0.084, ankle=0.07, toe=0.078, neck=0.078, depth=0.96, head=0.33, arm_len=1.1)},
}
CLIPS = {
    "reveler": ("atk_throw", "shout", "jump", "dash"),
    "convert": ("shout", "atk_claw"),
    "master": ("atk_sweep", "shout", "buff_focus", "cast_ground"),
}
# Convertido curvado (soma em todo clipe): coluna/cabeça +X = para a frente, membros -X = para a frente
CONVERT_POSTURE = {"spine": (13, 0, 0), "chest": (9, 0, 0), "neck": (-6, 0, 0), "head": (-8, 0, 7),
                   "upper_arm.R": (-12, 0, 0), "upper_arm.L": (-16, 0, 0), "forearm.L": (-14, 0, 0)}


def _mat(cid):
    return lambda n, col, rough=0.7, em=0.0: ck.mat("m_%s_%s" % (cid, n), col, rough, em)


def _mirror_mat(name, col):
    """Vidro de espelho: metálico e liso (o toon do jogo lê a cor; no Blender/GLB fica refletivo)."""
    m = ck.mat(name, col, 0.08)
    bsdf = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    bsdf.inputs["Metallic"].default_value = 1.0
    return m


def _split_x(obj, material):
    """Arlequim: as faces do lado +X da peça passam para `material`."""
    obj.data.materials.append(material)
    for p in obj.data.polygons:
        if p.center.x > 0:
            p.material_index = 1
    return obj


def _keep_faces(obj, test):
    bm_ = bmesh.new()
    bm_.from_mesh(obj.data)
    bmesh.ops.delete(bm_, geom=[f for f in bm_.faces if not test(f.calc_center_median())], context="FACES")
    bmesh.ops.delete(bm_, geom=[v for v in bm_.verts if not v.link_faces], context="VERTS")
    bm_.to_mesh(obj.data)
    bm_.free()
    return obj


def _crescent(name, c, r, material, grow=0.0, lift=1.17, side=-1, thick=0.03):
    """Máscara de meia-lua no rosto (lado `side` do boneco: -1 = direita, -X): arco de fora com raio R em volta de um centro
    deslocado, largura que some nas pontas, embrulhada na esfera da cabeça (pontas passam um pouco da testa e do queixo)."""
    ox, R, W, fm, n = -side * 0.25 * r, 1.05 * r + grow, 0.78 * r + 2 * grow, math.radians(80), 10
    rr = r * lift
    verts, faces = [], []
    for i in range(n + 1):
        f = -fm + 2 * fm * i / n
        w = max(W * max(math.cos(f / fm * math.pi / 2), 0.0) ** 0.8, 0.03 * r)
        for k in range(3):
            d = R - w * k / 2
            x, z = ox + side * d * math.cos(f), d * math.sin(f)
            y = -math.sqrt(max(rr * rr - x * x - z * z, (0.5 * rr) ** 2))
            verts.append((c.x + x, c.y + y, c.z + z))
    for i in range(n):
        for k in range(2):
            a = i * 3 + k
            faces.append((a, a + 1, a + 4, a + 3))
    me = bpy.data.meshes.new(name + "_mesh")
    me.from_pydata(verts, [], faces)
    me.update()
    obj = ck._link(bpy.data.objects.new(name, me))
    sol = obj.modifiers.new("sol", "SOLIDIFY")
    sol.thickness = thick
    ck._bake(obj)
    obj.data.materials.append(material)
    return obj


def _face_y(c, r, x, z, lift=1.17):
    rr = r * lift
    return c.y - math.sqrt(max(rr * rr - x * x - z * z, (0.5 * rr) ** 2))


def _stripes(cid, b, Z, material, n=12, skip=0.2):
    """Listras do gibão: faixas de pé em volta do tronco (fora dos lados, onde ficam os braços)."""
    out = []
    zs = (Z["waist"] - 0.05, (Z["waist"] + Z["chest"]) * 0.5, Z["chest"], Z["upper"] - 0.03)
    rs = (b["waist"] * 1.04, (b["waist"] + b["chest"]) * 0.52, b["chest"] * 1.03, b["upper"] * 1.02)
    for i in range(n):
        a = math.tau * (i + 0.5) / n
        if abs(math.cos(a)) > 1.0 - skip:
            continue
        tang = (-math.sin(a), math.cos(a), 0)
        pts = [V((math.cos(a) * (rr + 0.05), math.sin(a) * (rr + 0.05) * b["depth"], z)) for z, rr in zip(zs, rs)]
        out.append(lm._band("%s_stripe%d" % (cid, i), pts, [0.05, 0.055, 0.06, 0.05], 0.012, material, tang))
    return out


def _chain(name, p0, p1, material, link=0.085, w=0.06, t=0.022, material2=None):
    """Corrente de elos chatos (caixas alternadas a 90 graus) de p0 a p1."""
    p0, p1 = V(p0), V(p1)
    d = p1 - p0
    n = max(2, int(round(d.length / (link * 0.72))))
    q = V((0, 0, 1)).rotation_difference(d.normalized())
    out = []
    for i in range(n):
        c = p0 + d * ((i + 0.5) / n)
        o = ck.box("%s_%d" % (name, i), (w, t, link) if i % 2 == 0 else (t, w, link), (0, 0, 0), material2 if (material2 and i % 2) else material)
        for v in o.data.vertices:
            v.co = q @ v.co + c
        out.append(o)
    return out


def _add_full(arm, name, keys, end, loop=True, scaled=()):
    """lp.add_action com TODOS os ossos gravados (osso sem chave num clipe herdava a pose do último clipe criado: a queda
    do `die` vazava para os outros). Ossos de `scaled` ganham também a escala 1."""
    z = (0, 0, 0)
    for b_ in arm.data.bones.keys():
        if b_ not in keys:
            keys[b_] = [(1, z, z, (1, 1, 1)), (end, z, z, (1, 1, 1))] if b_ in scaled else [(1, z, z), (end, z, z)]
    mk.lp.add_action(arm, name, keys, end, loop=loop)


def _rest(arm):
    for pb in arm.pose.bones:
        pb.rotation_euler = (0, 0, 0)
        pb.location = (0, 0, 0)
        pb.scale = (1, 1, 1)
    if arm.animation_data:
        arm.animation_data.action = None
    return arm


# ---------------------------------------------------------------------------
# humanos do Festim: Folião, Convertido, Mestre de Cerimônias
# ---------------------------------------------------------------------------
def human(cid, kind):
    cfg = KINDS[kind]
    saved = lm._stretch(cfg["leg"], cfg["torso"])
    try:
        return _human(cid, kind, cfg)
    finally:
        ck.Z.clear()
        ck.Z.update(saved)


def _human(cid, kind, cfg):
    ck.BODIES["festim"] = cfg["body"]
    base = ck.build_base(cid, "festim", 0.0, cfg["hair"])
    rig, body, b, j = base["rig"], base["body"], base["b"], base["j"]
    Z = ck.Z
    m = _mat(cid)
    glow = ck.mat("glow_rose", ROSE_TEAR, 0.3, 1.5)
    M = {"porc": m("mask", MASK, 0.3), "gold": m("gold", OLD_GOLD, 0.4), "gold2": m("gold2", BRIGHT_GOLD, 0.35), "ink": m("ink", INK, 0.6),
         "glow": glow, "t": m("wine", WINE, 0.85)}
    wine, deep, cream, rose = M["t"], m("wine2", WINE_DEEP, 0.85), m("cream", CREAM, 0.8), m("ribbon", ROSE, 0.8)
    gold, gold2, porc = M["gold"], M["gold2"], M["porc"]
    c, r = V(base["head_c"]), b["head"]
    zc, zw, zn, zp, zu = Z["chest"], Z["waist"], Z["neck"], Z["pelvis"], Z["upper"]
    back = b["chest"] * b["depth"]
    front = -back
    head, chest, spine, hips, skinned = [], [], [], [], []
    arms = {".R": [], ".L": []}
    uppers = {".R": [], ".L": []}
    hands = {".R": [], ".L": []}
    shins = {".R": [], ".L": []}
    feet = {".R": [], ".L": []}

    # ---------------- roupa conformada ao corpo ----------------
    coat = wine if kind != "convert" else m("faded", (0.3, 0.1, 0.16), 0.9)
    ck.armor_piece(body, rig, cid + "_doublet", "torso", coat, 0.02, 0.016, 0.12)
    hose = ck.armor_piece(body, rig, cid + "_hose", "legs", cream if kind != "master" else deep, 0.012, 0.012)
    if kind == "reveler":
        _split_x(hose, wine)
    ck.armor_piece(body, rig, cid + "_boots", "boots", deep, 0.02, 0.015)
    if kind == "convert":              # o braço esquerdo já virou porcelana
        g = ck.armor_piece(body, rig, cid + "_porcarm", "gloves", m("porc", PORC, 0.4), 0.012, 0.012)
        _keep_faces(g, lambda p: p.x > 0)
    else:
        ck.armor_piece(body, rig, cid + "_gloves", "gloves", cream, 0.012, 0.012)
    for s, sx in ((".R", -1), (".L", 1)):
        sh, el, wr = V(j["shoulder" + s]), V(j["elbow" + s]), V(j["wrist" + s])
        tag = s[1]
        if kind == "convert" and sx > 0:
            continue
        uppers[s].append(ck.ball("%s_puff%s" % (cid, tag), b["arm"] * 1.75, sh.lerp(el, 0.3), coat, (1.0, 1.0, 1.15)))
        uppers[s].append(ck.tube("%s_puffband%s" % (cid, tag), sh.lerp(el, 0.72), sh.lerp(el, 0.86), b["arm"] * 1.3, b["arm"] * 1.25, gold, 8))
        if kind != "convert":
            arms[s].append(ck.tube("%s_sleeve%s" % (cid, tag), el.lerp(wr, 0.1), wr.lerp(el, 0.12), b["elbow"] * 1.25, b["wrist"] * 1.75, cream if kind == "reveler" else wine, 8))
            arms[s].append(ck.tube("%s_cuff%s" % (cid, tag), wr.lerp(el, 0.14), wr.lerp(el, 0.02), b["wrist"] * 1.85, b["wrist"] * 1.95, gold, 8))
    chest.append(lm._ring(cid + "_ruff", zn - 0.035, zn + 0.05, b["neck"] * 1.5, b["neck"] * (2.9 if kind == "master" else 2.5), cream if kind != "convert" else rose, 0.9))

    if kind == "reveler":
        skinned += _stripes(cid, b, Z, cream)
        skinned.append(lm._skirt(cid + "_peplum", zw - 0.03, zp - 0.07, b["waist"] * 1.18, b["pelvis"] * 1.55, wine, 12, 0.05))
        hips.append(lm._ring(cid + "_belt", zw - 0.05, zw - 0.005, b["waist"] * 1.24, b["waist"] * 1.22, gold))
        # meia-lua: porcelana com filete de ouro por trás, olho de tinta e a lágrima acesa
        head.append(_crescent(cid + "_moon", c, r, porc))
        head.append(_crescent(cid + "_moon_rim", c, r, gold, 0.025, 1.145, thick=0.02))
        ex = -0.42 * r
        head += [ck.ball(cid + "_moon_eye", r * 0.15, V((c.x + ex, _face_y(c, r, ex, 0.0) - 0.012, c.z)), M["ink"], (1.3, 0.5, 0.66)),
                 ck.ball(cid + "_moon_tear", r * 0.06, V((c.x + ex, _face_y(c, r, ex, -0.3 * r) - 0.012, c.z - 0.3 * r)), glow, (0.8, 0.6, 2.4)),
                 ck.ball(cid + "_moon_drop", r * 0.095, V((c.x + ex, _face_y(c, r, ex, -0.5 * r) - 0.014, c.z - 0.5 * r)), glow, (1.0, 0.6, 1.25))]
        # boina caída para o lado sem máscara, laço e duas fitas compridas atrás
        bc = c + V((r * 0.2, r * 0.08, r * 0.98))
        head += [ck.ball(cid + "_cap", r * 0.95, bc, wine, (1.12, 1.12, 0.46)),
                 ck.ball(cid + "_capband", r * 0.74, bc + V((-r * 0.1, 0, -r * 0.2)), cream, (1.1, 1.1, 0.26)),
                 ck.ball(cid + "_capknob", r * 0.13, bc + V((0, 0, r * 0.36)), gold2)]
        head += lm._bow(cid + "_capbow", bc + V((r * 0.82, -r * 0.1, r * 0.02)), (1, -0.2, 0), r * 0.5, rose, gold2, cream)
        for i, (sx, mt) in enumerate(((-0.25, rose), (0.3, cream))):
            head.append(lm._veil("%s_capribbon%d" % (cid, i), bc + V((sx * r, r * 0.86, -r * 0.1)), V((sx * 0.5, back + 0.3, zc - 0.02 - 0.1 * i)),
                                 r * 0.3, r * 0.22, mt, (sx * 0.1, 0.1, 0), 4, 0.35))
        # taça de ouro (mão direita), de pé no punho: o vinho é o brilho rosa
        g = V(ck.hand_center(base, ".R"))
        s_ = 0.125
        hands[".R"] += lk.goblet(ck, cid + "_goblet", g + V((-0.01, -0.035, s_ * 1.45)), s_, M)
        wl = V(j["wrist.L"])
        for i, mt in enumerate((rose, cream)):
            arms[".L"].append(lm._veil("%s_wristribbon%d" % (cid, i), wl + V((0.03, 0.03 * (i * 2 - 1), 0.02)), wl + V((0.1 + 0.05 * i, 0.1 * (i * 2 - 1), -0.26)),
                                       0.06, 0.05, mt, (0.03, 0, 0), 3, 0.3))
        for s, sx in ((".R", -1), (".L", 1)):          # sapato de bico com guizo
            toe = V(j["toe" + s])
            feet[s].append(cone("%s_toe%s" % (cid, s[1]), toe + V((0, 0.0, 0.035)), toe + V((0, -0.15, 0.1)), 0.042, deep if sx < 0 else wine, 6))
            feet[s] += lk.bell(ck, "%s_toebell%s" % (cid, s[1]), toe + V((0, -0.155, 0.11)), 0.03, M)
    elif kind == "convert":
        # máscara inteira rachada: olhos e rachaduras acesos (`glow_rose`)
        s_ = r * 0.8
        mc = c + V((0, -r * 0.93, -r * 0.08))
        head += lk.mask(ck, cid + "_mask", mc, s_, dict(M, ink=glow), tears=(1,))
        wx, dy = 0.82 * s_, 0.34 * s_

        def surf(x, z):
            k = 1.0 - (x * s_ / wx) ** 2 - z ** 2
            return mc + V((x * s_, -dy * math.sqrt(max(k, 0.0)) - 0.012, z * s_))

        cracks = (((-0.34, 0.3), (-0.18, 0.52), (-0.36, 0.74), (-0.2, 0.93)),
                  ((0.02, 0.02), (0.2, -0.26), (0.06, -0.52), (0.26, -0.82)),
                  ((-0.3, 0.0), (-0.56, -0.22), (-0.44, -0.5)),
                  ((0.2, -0.26), (0.5, -0.3)), ((-0.18, 0.52), (0.1, 0.62), (0.2, 0.86)))
        for i, path in enumerate(cracks):
            for k in range(len(path) - 1):
                head.append(ck.tube("%s_crack%d_%d" % (cid, i, k), surf(*path[k]), surf(*path[k + 1]), 0.009, 0.006, glow, 4))
        head.append(ck.ball(cid + "_chip", s_ * 0.2, surf(0.42, -0.62) + V((0, 0.012, 0)), glow, (1.0, 0.35, 1.2)))      # lasca que falta
        head.append(lm._veil(cid + "_masktie", c + V((r * 0.3, r * 0.95, 0.0)), V((0.28, back + 0.34, zw + 0.02)), r * 0.3, r * 0.2, rose, (0.06, 0.1, 0), 4, 0.3))
        # porcelana subindo pelo pescoço e rachaduras no peito
        chest.append(lm._ring(cid + "_porcneck", zn - 0.02, zn + 0.075, b["neck"] * 1.22, b["neck"] * 1.16, m("porc", PORC, 0.4), 0.9))
        y0 = front - 0.03
        for i, (pa, pb) in enumerate((((0.02, zu - 0.01), (0.07, zc + 0.05)), ((0.07, zc + 0.05), (0.02, zc - 0.03)), ((0.07, zc + 0.05), (0.13, zc + 0.02)),
                                      ((-0.05, zu - 0.03), (-0.09, zc + 0.03)))):
            chest.append(ck.tube("%s_vein%d" % (cid, i), V((pa[0], y0, pa[1])), V((pb[0], y0, pb[1])), 0.014, 0.009, glow, 4))
        # fitas enroladas nos membros; garras de ouro na mão de porcelana
        for s, sx in ((".R", -1), (".L", 1)):
            el, wr, kn, an = V(j["elbow" + s]), V(j["wrist" + s]), V(j["knee" + s]), V(j["ankle" + s])
            for k in range(3):
                t0 = 0.18 + 0.27 * k
                arms[s].append(ck.tube("%s_wrap%s%d" % (cid, s[1], k), el.lerp(wr, t0) + V((0, 0, 0.012)), el.lerp(wr, t0 + 0.13) - V((0, 0, 0.012)),
                                       b["elbow"] * 1.42, b["wrist"] * 1.6, rose, 8))
            for k in range(2):
                t0 = 0.2 + 0.36 * k
                shins[s].append(ck.tube("%s_legwrap%s%d" % (cid, s[1], k), kn.lerp(an, t0), kn.lerp(an, t0 + 0.2), b["knee"] * 1.45, b["ankle"] * 1.6, rose, 8))
            arms[s].append(lm._veil("%s_looseribbon%s" % (cid, s[1]), wr + V((sx * 0.03, 0.03, 0.03)), wr + V((sx * 0.1, 0.12, -0.3)), 0.07, 0.05, rose, (sx * 0.03, 0.02, 0), 3, 0.25))
        tip = V(j["hand_tip.L"])
        for i in (-1, 0, 1):
            hands[".L"].append(cone("%s_claw%d" % (cid, i), tip + V((0, i * 0.024, 0.0)), tip + V((0.01, i * 0.034 - 0.035, -0.12)), 0.017, gold2, 5))
        skinned.append(lm._skirt(cid + "_rags", zw - 0.03, zp - 0.12, b["waist"] * 1.2, b["pelvis"] * 1.5, coat, 12, 0.09, 0.5))
        hips.append(lm._ring(cid + "_sash", zw - 0.05, zw + 0.0, b["waist"] * 1.26, b["waist"] * 1.24, rose))
    else:                              # master
        # colete creme na barriga com botões de ouro, casaca de abas, pires nos ombros
        vest = ck.armor_piece(body, rig, cid + "_vest", "torso", cream, 0.04, 0.014)
        _keep_faces(vest, lambda p: p.y < -0.05 and abs(p.x) < b["chest"] * 0.62 and Z["pelvis"] + 0.02 < p.z < zu - 0.03)
        spine.append(ck.ball(cid + "_belly", 1.0, V((0, -b["waist"] * b["depth"] * 0.62, zw + 0.0)), cream, (b["waist"] * 0.82, b["waist"] * 0.62, 0.2)))
        for i in range(4):
            z = zw - 0.1 + 0.115 * i
            rr = (b["waist"] if i < 2 else (b["waist"] + b["chest"]) * 0.5) * b["depth"]
            spine.append(ck.ball("%s_button%d" % (cid, i), 0.032, V((0, -b["waist"] * b["depth"] * (1.2 if i in (1, 2) else 1.08) - 0.02, z)), gold2))
        for sx in (-1, 1):
            hips.append(lm._veil("%s_tail%d" % (cid, sx), V((sx * 0.11, b["pelvis"] * b["depth"] + 0.04, zw - 0.02)), V((sx * 0.2, back + 0.36, Z["knee"] + 0.1)),
                                 0.26, 0.2, wine, (sx * 0.03, 0.08, 0), 4, 0.35))
            chest += lk.saucers(ck, "%s_saucer%d" % (cid, sx), V((sx * (b["shoulder"] + 0.02), 0.0, zu + 0.05)), 0.15, 2, M, 0.045, 0.24, (sx * 0.3, 0, 1), [porc, cream])
        hips.append(lm._ring(cid + "_belt", zw - 0.16, zw - 0.11, b["pelvis"] * 1.16, b["pelvis"] * 1.14, gold, b["depth"]))
        hips.append(ck.box(cid + "_buckle", (0.1, 0.03, 0.08), V((0, -b["pelvis"] * b["depth"] * 1.14 - 0.02, zw - 0.135)), gold2, 0.01))
        # máscara larga com a lágrima e o bigode de ouro
        s_ = r * 0.8
        mc = c + V((0, -r * 0.93, -r * 0.08))
        head += lk.mask(ck, cid + "_mask", mc, s_, M, tears=(1,), wide=1.12)
        for sx in (-1, 1):
            p0 = mc + V((sx * s_ * 0.06, -s_ * 0.36, -s_ * 0.36))
            head += bs._tusk(ck, "%s_moustache%d" % (cid, sx), p0, p0 + V((sx * s_ * 0.62, s_ * 0.1, s_ * 0.16)), V((0, -s_ * 0.05, -s_ * 0.16)), s_ * 0.085, gold2, 4, 6)
        # cartola de fitas: aba, copa que abre para cima, faixa de ouro, espiral rosa/creme, laços no topo e fitas caídas atrás
        hz = c.z + r * 0.6
        hc = V((0, r * 0.04, hz))
        rc0, rc1, hh = r * 0.78, r * 0.9, r * 1.35
        head += [ck.tube(cid + "_hatbrim", hc, hc + V((0, 0, 0.035)), r * 1.3, r * 1.3, deep, 16),
                 ck.tube(cid + "_hatcrown", hc + V((0, 0, 0.03)), hc + V((0, 0, hh)), rc0, rc1, wine, 14),
                 ck.tube(cid + "_hatband", hc + V((0, 0, 0.035)), hc + V((0, 0, 0.11)), rc0 * 1.04, rc0 * 1.045, gold, 14)]
        for k, mt in enumerate((rose, cream)):
            pts, n_ = [], 22
            for i in range(n_ + 1):
                t = i / n_
                a = math.tau * (1.5 * t + 0.5 * k)
                rr = (rc0 + (rc1 - rc0) * (0.12 + 0.8 * t)) + 0.014
                pts.append(hc + V((math.cos(a) * rr, math.sin(a) * rr, hh * (0.14 + 0.8 * t))))
            head.append(lm._band("%s_hatspiral%d" % (cid, k), pts, [0.075] * len(pts), 0.012, mt, (0, 0, 1)))
        top = hc + V((0, 0, hh))
        for i in range(4):
            a = -math.pi / 2 + math.tau * i / 4
            o_ = V((math.cos(a), math.sin(a), 0))
            head += lm._bow("%s_hatbow%d" % (cid, i), top + o_ * rc1 * 0.62 + V((0, 0, 0.03)), o_, r * 0.5, rose if i % 2 == 0 else cream, gold2, cream if i % 2 == 0 else rose)
        head.append(ck.ball(cid + "_hattop", r * 0.2, top + V((0, 0, 0.07)), gold2))
        for i, (sx, mt) in enumerate(((-0.4, rose), (0.0, cream), (0.4, rose))):
            head.append(lm._veil("%s_hatribbon%d" % (cid, i), top + V((sx * r, rc1 * 0.9, -0.02)), V((sx * 1.3 * r, back + 0.42, zu + 0.08 - 0.06 * abs(i - 1))),
                                 r * 0.36, r * 0.26, mt, (sx * 0.05, 0.16, 0), 5, 0.35))
        # bastão de sinos (mão direita), como o cajado do kit: inclinado para fora; aro de ouro com cinco sinos e fitas
        g = V(ck.hand_center(base, ".R"))
        up = V((-0.22, -0.12, 1.0)).normalized()
        sd = (V((1, 0, 0)) - up * up.x).normalized()
        bot, tp = g - up * 0.56, g + up * 0.98
        P = cid + "_staff"
        st = [ck.tube(P + "_shaft", bot, tp, 0.028, 0.03, m("wood", WOOD, 0.7), 6), ck.ball(P + "_ferrule", 0.04, bot, gold),
              ck.tube(P + "_grip", g - up * 0.1, g + up * 0.1, 0.036, 0.036, gold, 6), ck.tube(P + "_cap", tp, tp + up * 0.07, 0.05, 0.036, gold2, 8)]
        rc_, rad = tp + up * 0.25, 0.19
        ring = [rc_ + (sd * math.cos(math.tau * k / 10) + up * math.sin(math.tau * k / 10)) * rad for k in range(10)]
        for k in range(10):
            st.append(ck.tube("%s_ring%d" % (P, k), ring[k], ring[(k + 1) % 10], 0.024, 0.024, gold2, 5))
            st.append(ck.ball("%s_ringj%d" % (P, k), 0.026, ring[k], gold2))
        for k, a in enumerate((-150, -120, -90, -60, -30)):
            p = rc_ + (sd * math.cos(math.radians(a)) + up * math.sin(math.radians(a))) * rad
            hang = p - up * (0.07 + 0.03 * (k % 2))
            st.append(ck.tube("%s_bellhang%d" % (P, k), p, hang, 0.008, 0.008, gold, 4))
            st += lk.bell(ck, "%s_bell%d" % (P, k), hang - up * 0.04, 0.05, M)
        st.append(ck.ball(P + "_finial", 0.045, rc_ + up * (rad + 0.03), glow))
        for i, mt in enumerate((rose, cream)):
            st.append(lm._veil("%s_ribbon%d" % (P, i), tp + up * 0.04 + sd * (0.03 * (i * 2 - 1)), tp - up * 0.34 + sd * (0.12 * (i * 2 - 1)) + V((0, 0.06, 0)),
                               0.07, 0.05, mt, (0, 0.04, 0), 3, 0.3))
        hands[".R"] += st

    # ---------------- pesos ----------------
    ck._rigid(bs._outward(head), rig, "head")
    ck._rigid(bs._outward(chest), rig, "chest")
    ck._rigid(bs._outward(spine), rig, "spine")
    ck._rigid(bs._outward(hips), rig, "hips")
    for s in (".R", ".L"):
        ck._rigid(bs._outward(uppers[s]), rig, "upper_arm" + s)
        ck._rigid(bs._outward(arms[s]), rig, "forearm" + s)
        ck._rigid(bs._outward(hands[s]), rig, "hand" + s)
        ck._rigid(bs._outward(shins[s]), rig, "shin" + s)
        ck._rigid(bs._outward(feet[s]), rig, "foot" + s)
    lk.skinned(ck, base, bs._outward(skinned))

    # ---------------- clipes ----------------
    if kind == "master":
        ck.mob_clips(rig, "staff", None, None, extra_keep=CLIPS[kind])
    else:
        ck.mob_clips(rig, None, None, "atk_1h_a" if kind == "reveler" else None, extra_keep=CLIPS[kind])
    lm._hips_scale(rig, Z["pelvis"] / 0.38)
    if kind == "convert":
        act2_bosses.posture(rig, CONVERT_POSTURE)
    if kind == "reveler":
        act2_bosses.clear_ground(rig, {"*": 0.02, "die": -0.1}, "hand.R", (cid + "_goblet",), front=True)
    if kind == "master":
        act2_bosses.clear_ground(rig, {"*": 0.02, "die": -0.1}, "hand.R", (cid + "_staff",), front=True)
        act2_bosses.clear_ground(rig, {"die": -0.02}, "head", (cid + "_hat",))
    lm._join(cid, rig, cid + "_body")
    return rig


def reveler(cid="mob_reveler"):
    return human(cid, "reveler")


def convert(cid="mob_convert"):
    return human(cid, "convert")


def ceremony_master(cid="mob_ceremony_master"):
    return human(cid, "master")


# ---------------------------------------------------------------------------
# Reflexo Vaidoso: figura chata de espelho (peças rígidas)
# ---------------------------------------------------------------------------
# ossos de pé (eixos locais: x = X, y = para cima, z = -Y): rot X+ = tomba para a frente, Y = gira em pé, loc = (x, cima, frente)
REFLECT_BONES = {
    "root": ((0, 0, 0), (0, 0, 0.2), None),
    "body": ((0, 0, 0.95), (0, 0, 1.2), "root"),             # moldura-vestido + corpete + fundo
    "glass": ((0, 0, 0.95), (0, 0, 1.2), "root"),            # vidro do vestido com a silhueta: MESMO pivô do `body` e filho da
                                                             # raiz; fora do die leva as chaves do `body` (anda junto), no die cai sozinho
    "head": ((0, 0, 1.52), (0, 0, 1.77), "body"),
    "arm_r": ((-0.3, 0, 1.4), (-0.3, 0, 1.65), "body"),      # direita do boneco = -X
    "arm_l": ((0.3, 0, 1.4), (0.3, 0, 1.65), "body"),
}


def vain_reflection(cid="mob_vain_reflection"):
    arm = mk.lp.make_armature("rig_" + cid, REFLECT_BONES)
    m = _mat(cid)
    M = {"porc": m("mask", MASK, 0.3), "gold": m("gold", OLD_GOLD, 0.4), "gold2": m("gold2", BRIGHT_GOLD, 0.35), "ink": m("ink", INK, 0.6),
         "glow": m("tear", ROSE_TEAR, 0.3, 2.2)}
    gold, gold2, glow = M["gold"], M["gold2"], M["glow"]
    mir, mir2 = _mirror_mat("m_%s_mirror" % cid, MIRROR), _mirror_mat("m_%s_mirror2" % cid, MIRROR_LIGHT)
    shade, wood, veil = m("shade", SHADE, 0.5), m("back", WOOD, 0.8), m("veil", ROSE, 0.8)
    parts = []
    P = lm._plate
    # ---- vestido: moldura em sino (barra em arco), vidro dentro, silhueta de quem olha ----
    hem = [(-0.5, 0.36), (-0.36, 0.25), (-0.18, 0.19), (0.0, 0.17), (0.18, 0.19), (0.36, 0.25), (0.5, 0.36)]
    waist = [(0.15, 1.06), (-0.15, 1.06)]
    dress = hem + waist
    parts.append((P("glass", dress, 0.0, 0.03, mir), "glass"))
    parts.append((P("backboard", [(x * 0.97, z) for x, z in dress], 0.04, 0.03, wood), "body"))
    for i in range(len(dress)):
        (xa, za), (xb, zb) = dress[i], dress[(i + 1) % len(dress)]
        parts.append((ck.tube("frame%d" % i, (xa, 0.01, za), (xb, 0.01, zb), 0.05, 0.05, gold, 6), "body"))
        parts.append((ck.ball("frame_j%d" % i, 0.058 if 0 < i < 6 else 0.08, (xa, 0.01, za), gold2 if i in (0, 3, 6) else gold), "body"))
    parts.append((cone("hem_tip", (0, 0.01, 0.17), (0, 0.01, 0.045), 0.06, gold2, 6), "body"))
    for sx in (-1, 1):                 # festões de ouro da cintura à barra (as "dobras" do vestido) e fitas nos cantos
        parts.append((ck.tube("swag%d" % sx, (sx * 0.08, -0.02, 1.02), (sx * 0.27, -0.02, 0.24), 0.02, 0.02, gold, 4), "body"))
        parts.append((lm._veil("hemribbon%d" % sx, V((sx * 0.5, 0.03, 0.36)), V((sx * 0.56, 0.1, 0.1)), 0.09, 0.06, veil, (sx * 0.02, 0.03, 0), 3, 0.3), "body"))
    # silhueta de quem olha (o jogo pinta `m_<cid>_shade` com a cor da classe do alvo): chibi GRANDE e saltado do vidro
    # (frente em y -0,047; o vidro acaba em -0,015 e os festões em -0,04). Pequena e a 1 cm do vidro ela mal se lia
    # da câmera de 52 graus. Cabeça = disco chato de 12 lados; corpo = trapézio com ombros.
    sy, st = -0.04, 0.014
    parts.append((P("shade_body", [(-0.21, 0.24), (0.21, 0.24), (0.2, 0.3), (0.13, 0.62), (-0.13, 0.62), (-0.2, 0.3)], sy, st, shade), "glass"))
    parts.append((P("shade_head", [(math.cos(math.tau * k / 12) * 0.165, 0.79 + math.sin(math.tau * k / 12) * 0.165) for k in range(12)], sy, st, shade), "glass"))
    parts.append((P("glint_a", [(-0.34, 0.42), (-0.25, 0.42), (-0.1, 0.92), (-0.17, 0.92)], -0.017, 0.008, mir2), "glass"))
    parts.append((P("glint_b", [(0.22, 0.34), (0.28, 0.34), (0.36, 0.56), (0.31, 0.56)], -0.017, 0.008, mir2), "glass"))
    # ---- corpete: vidro estreito da cintura aos ombros, moldura dos lados, cinto e ombros de ouro, véu num ombro ----
    bod = [(-0.15, 1.06), (0.15, 1.06), (0.27, 1.42), (-0.27, 1.42)]
    parts.append((P("bodice", bod, 0.0, 0.03, mir2), "body"))
    parts.append((P("bodice_back", bod, 0.04, 0.03, wood), "body"))
    for i in range(4):
        (xa, za), (xb, zb) = bod[i], bod[(i + 1) % 4]
        parts.append((ck.tube("bframe%d" % i, (xa, 0.01, za), (xb, 0.01, zb), 0.04, 0.04, gold, 6), "body"))
    parts.append((ck.ball("waistgem", 0.06, (0, -0.03, 1.06), glow, (1.0, 0.5, 1.2)), "body"))
    for sx in (-1, 1):
        parts.append((ck.ball("shoulder%d" % sx, 0.09, (sx * 0.29, 0.01, 1.42), gold2), "body"))
    parts.append((ck.tube("neck", (0, 0.01, 1.42), (0, 0.01, 1.55), 0.05, 0.04, gold, 6), "body"))
    parts.append((lm._veil("drape", V((0.27, 0.06, 1.44)), V((0.42, 0.26, 0.7)), 0.24, 0.16, veil, (0.05, 0.08, 0), 4, 0.3), "body"))
    for k, (za, zb) in enumerate(((0.45, 0.95), (1.12, 1.36))):      # travessas de ouro no fundo (quem olha por trás)
        parts.append((ck.tube("brace%d" % k, (-0.12, 0.062, za), (0.12, 0.062, zb), 0.018, 0.018, gold, 4), "body"))
        parts.append((ck.tube("brace_b%d" % k, (0.12, 0.062, za), (-0.12, 0.062, zb), 0.018, 0.018, gold, 4), "body"))
    # ---- cabeça: oval de espelho sem olhos, só a lágrima; remate de moldura no alto ----
    hc = V((0, 0, 1.76))
    parts += [(ck.ball("face", 1.0, hc, mir, (0.2, 0.035, 0.245)), "head"),
              (ck.ball("face_rim", 1.0, hc + V((0, 0.022, 0)), gold, (0.238, 0.03, 0.283)), "head"),
              (ck.ball("face_back", 1.0, hc + V((0, 0.04, 0)), wood, (0.2, 0.025, 0.245)), "head"),
              (ck.ball("tear", 0.022, hc + V((0.08, -0.036, -0.03)), glow, (0.8, 0.5, 3.0)), "head"),
              (ck.ball("tear_drop", 0.034, hc + V((0.08, -0.034, -0.11)), glow, (1.0, 0.5, 1.3)), "head"),
              (P("face_glint", [(-0.12, 1.78), (-0.07, 1.78), (-0.02, 1.92), (-0.06, 1.92)], -0.036, 0.008, mir2), "head")]
    for i in range(5):                 # remate: leque de folhas de ouro, a do meio mais alta
        a = (i - 2) * 0.42
        p0 = hc + V((math.sin(a) * 0.14, 0.02, 0.2 + 0.05 * math.cos(a)))
        parts.append((ck.blade("crest%d" % i, p0, p0 + V((math.sin(a) * 0.17, 0.0, 0.2 - 0.035 * abs(i - 2))), 0.1, 0.03, gold2 if i % 2 == 0 else gold,
                               (math.cos(a), 0, -math.sin(a)), 0.5), "head"))
    parts.append((ck.ball("crest_gem", 0.045, hc + V((0, 0.0, 0.275)), glow), "head"))
    # ---- braços: cacos compridos de espelho com dorso de ouro ----
    for s, sx in (("arm_r", -1), ("arm_l", 1)):
        p0, p1 = V((sx * 0.31, -0.005, 1.4)), V((sx * 0.56, -0.02, 0.56))
        parts += [(ck.blade(s + "_shard", p0, p1, 0.15, 0.03, mir, (1, 0, 0.3 * sx), 0.3), s),
                  (ck.blade(s + "_shard_back", p0 + V((0, 0.022, 0)), p1.lerp(p0, 0.06) + V((0, 0.022, 0)), 0.18, 0.02, gold, (1, 0, 0.3 * sx), 0.3), s),
                  (ck.ball(s + "_cuff", 0.05, p0.lerp(p1, 0.3) + V((0, 0.005, 0)), gold2, (1.5, 0.9, 0.7)), s)]
    for obj, bone in parts:
        round_ = obj.name.startswith(("frame_j", "shoulder", "waistgem", "tear", "crest_gem", "face", "drape", "hemribbon")) or "_cuff" in obj.name
        for p in obj.data.polygons:
            p.use_smooth = round_ and not obj.name.startswith("face_glint")
        mk.lp.attach(bs._outward([obj])[0], arm, bone)

    z = (0, 0, 0)

    def add(a_, name, keys, end, loop=True):
        keys.setdefault("glass", list(keys["body"]))
        _add_full(a_, name, keys, end, loop)

    r = lambda x=0.0, y=0.0, zz=0.0: (x, y, zz)
    p = lambda up=0.0, fwd=0.0: (0, up, fwd)
    tau = math.tau
    # idle: boia e vira devagar de um lado para o outro (o vidro pisca para a câmera)
    n, idle = 64, {b: [] for b in ("body", "head", "arm_r", "arm_l")}
    for f in list(range(1, n, 3)) + [n]:
        ph = (f - 1) / (n - 1) * tau
        idle["body"].append((f, r(1.5 * math.sin(ph), 9 * math.sin(ph), 0), p(0.035 * (0.5 - 0.5 * math.cos(ph)))))
        idle["head"].append((f, r(0, 0, 4 * math.sin(ph + 0.9)), z))
        idle["arm_r"].append((f, r(4 * math.sin(ph + 0.5), 0, -4 - 3 * math.sin(ph)), z))
        idle["arm_l"].append((f, r(4 * math.sin(ph + 1.1), 0, 4 + 3 * math.sin(ph)), z))
    add(arm, "idle", idle, n)
    # run: desliza inclinado, rebola em pé, braços para trás
    n, run = 16, {b: [] for b in ("body", "head", "arm_r", "arm_l")}
    for f in range(1, n + 1):
        ph = (f - 1) / (n - 1) * tau
        s_ = math.sin(ph)
        run["body"].append((f, r(15 + 2 * math.cos(2 * ph), 12 * s_, 3 * s_), p(0.03 + 0.03 * math.sin(2 * ph))))
        run["head"].append((f, r(-8, -6 * s_, 0), z))
        run["arm_r"].append((f, r(30 + 8 * s_, 0, -14), z))
        run["arm_l"].append((f, r(30 - 8 * s_, 0, 14), z))
    add(arm, "run", run, n)
    still = lambda end: {}
    # attack: recolhe o caco direito por cima e corta para a frente (impacto no quadro 5)
    add(arm, "attack", dict(still(16),
        body=[(1, z, z), (3, r(-10, 24, 0), p(0.05, -0.08)), (5, r(18, -22, 0), p(-0.02, 0.2)), (7, r(15, -26, 0), p(-0.02, 0.18)), (11, r(6, -8, 0), p(0, 0.06)), (16, z, z)],
        head=[(1, z, z), (3, r(-8, 0, 6), z), (5, r(10, 0, -6), z), (11, r(3), z), (16, z, z)],
        arm_r=[(1, z, z), (3, r(-165, 0, -20), z), (5, r(-62, 0, 10), z), (7, r(-48, 0, 14), z), (11, r(-14, 0, 0), z), (16, z, z)],
        arm_l=[(1, z, z), (3, r(20, 0, 22), z), (5, r(34, 0, 30), z), (11, r(10, 0, 8), z), (16, z, z)]), 16, loop=False)
    add(arm, "hit", dict(still(10),
        body=[(1, z, z), (2, r(-15, -14, 5), p(0.03, -0.1)), (5, r(5, 6, -3), p(0, -0.04)), (10, z, z)],
        head=[(1, z, z), (2, r(-18, 0, 10), z), (5, r(6, 0, -5), z), (10, z, z)],
        arm_r=[(1, z, z), (2, r(-30, 0, -30), z), (6, r(6), z), (10, z, z)],
        arm_l=[(1, z, z), (2, r(-30, 0, 30), z), (6, r(6), z), (10, z, z)]), 10, loop=False)
    # shout (Sumir no Espelho): abre os braços e dá uma volta inteira em pé: de perfil o espelho é um risco
    add(arm, "shout", dict(still(20),
        body=[(1, z, z), (4, r(-6, -30, 0), p(0.08)), (8, r(0, 120, 0), p(0.14)), (12, r(0, 270, 0), p(0.1)), (16, r(2, 372, 0), p(0.02)), (20, r(0, 360, 0), z)],
        head=[(1, z, z), (4, r(-10), z), (12, r(6), z), (20, z, z)],
        arm_r=[(1, z, z), (4, r(0, 0, -20), z), (9, r(0, 0, -78), z), (14, r(0, 0, -60), z), (20, z, z)],
        arm_l=[(1, z, z), (4, r(0, 0, 20), z), (9, r(0, 0, 78), z), (14, r(0, 0, 60), z), (20, z, z)]), 20, loop=False)
    # atk_charge (Lampejo do Espelho): recolhe e estoca com os dois cacos para a frente
    lunge_b, lunge_a = (r(32, 0, 0), p(-0.04, 0.34)), r(-100, 0, 0)
    add(arm, "atk_charge", dict(still(18),
        body=[(1, z, z), (4, r(-14, 0, 0), p(0.06, -0.14)), (7, lunge_b[0], lunge_b[1]), (11, r(28), p(-0.04, 0.3)), (15, r(8), p(0, 0.08)), (18, z, z)],
        head=[(1, z, z), (4, r(10), z), (7, r(-26), z), (11, r(-22), z), (18, z, z)],
        arm_r=[(1, z, z), (4, r(40, 0, -24), z), (7, r(-104, 0, 12), z), (11, r(-98, 0, 10), z), (15, r(-30), z), (18, z, z)],
        arm_l=[(1, z, z), (4, r(40, 0, 24), z), (7, r(-104, 0, -12), z), (11, r(-98, 0, -10), z), (15, r(-30), z), (18, z, z)]), 18, loop=False)
    add(arm, "dash", dict(still(8), body=[(1, lunge_b[0], lunge_b[1]), (8, lunge_b[0], lunge_b[1])], head=[(1, r(-26), z), (8, r(-26), z)],
                          arm_r=[(1, r(-104, 0, 12), z), (8, r(-104, 0, 12), z)], arm_l=[(1, r(-104, 0, -12), z), (8, r(-104, 0, -12), z)]), 8)
    # die: o vidro do vestido cai para a frente e deita no chão; a moldura vazia balança, tomba de costas e fica deitada
    add(arm, "die", {
        "glass": [(1, z, z), (3, r(6), p(0.02, 0.03)), (8, r(50), p(-0.4, 0.2)), (12, r(88), p(-0.9, 0.3)), (14, r(90), p(-0.925, 0.32)), (26, r(90), p(-0.925, 0.32))],
        "body": [(1, z, z), (4, r(-10, 0, 4), p(0.05, -0.05)), (9, r(8, 0, -6), z), (13, r(-12, 0, 5), z), (19, r(-85), p(-0.86, -0.1)), (21, r(-79), p(-0.84, -0.1)),
                 (23, r(-85), p(-0.86, -0.1)), (26, r(-85), p(-0.86, -0.1))],
        "head": [(1, z, z), (4, r(-16, 0, 8), z), (9, r(12, 0, -10), z), (20, r(0, 0, 14), z), (26, r(0, 0, 14), z)],
        "arm_r": [(1, z, z), (4, r(-30, 0, -40), z), (12, r(0, 0, -20), z), (20, r(0, 0, -62), z), (26, r(0, 0, -62), z)],
        "arm_l": [(1, z, z), (4, r(-30, 0, 40), z), (12, r(0, 0, 20), z), (20, r(0, 0, 55), z), (26, r(0, 0, 55), z)],
    }, 26, loop=False)
    return _rest(arm)


# ---------------------------------------------------------------------------
# Incensário Vivo: turíbulo de bronze que flutua (peças rígidas)
# ---------------------------------------------------------------------------
CENSER_BONES = {
    "root": ((0, 0, 0), (0, 0, 0.2), None),
    "body": ((0, 0, 2.02), (0, 0, 2.27), "root"),            # pivô na argola de cima: o turíbulo balança como pêndulo
    "head": ((0, 0.3, 1.2), (0, 0.3, 1.45), "body"),         # tampa: dobradiça atrás (X- = abre)
    "arm_r": ((-0.5, 0, 1.02), (-0.5, 0, 1.27), "body"),     # correntes dos lados com os turíbulos pequenos
    "arm_l": ((0.5, 0, 1.02), (0.5, 0, 1.27), "body"),
    "leg_r": ((-0.15, 0, 0.6), (-0.15, 0, 0.85), "body"),    # correntes-pernas
    "leg_l": ((0.15, 0, 0.6), (0.15, 0, 0.85), "body"),
    "hang": ((0, 0, 1.2), (0, 0, 1.45), "body"),             # três correntes até a argola (encolhem no die)
    "smoke_a": ((0, 0, 1.7), (0, 0, 1.95), "body"),
    "smoke_b": ((0, 0, 1.95), (0, 0, 2.2), "body"),
}


def living_censer(cid="mob_living_censer"):
    arm = mk.lp.make_armature("rig_" + cid, CENSER_BONES)
    m = _mat(cid)
    M = {"porc": m("mask", MASK, 0.3), "gold": m("gold", OLD_GOLD, 0.4), "gold2": m("gold2", BRIGHT_GOLD, 0.35), "ink": m("ink", INK, 0.6),
         "glow": m("tear", ROSE_TEAR, 0.3, 2.2)}
    gold, gold2 = M["gold"], M["gold2"]
    bronze, dark = m("bronze", BRONZE, 0.45), m("bronze2", BRONZE_DARK, 0.5)
    ember = ck.mat("glow_lilac", LILAC_GLOW, 0.3, 1.3)
    smoke, smoke2 = m("smoke", LILAC, 1.0), m("smoke2", (0.86, 0.78, 0.97), 1.0)
    parts = []
    T = ck.tube
    # ---- bojo: pé, taça, faixa de ouro, máscara da lágrima na frente ----
    zb = 0.98
    parts += [(T("foot", (0, 0, 0.56), (0, 0, 0.64), 0.24, 0.13, bronze, 10), "body"),
              (T("foot_lip", (0, 0, 0.545), (0, 0, 0.575), 0.25, 0.25, gold, 10), "body"),
              (T("stem", (0, 0, 0.62), (0, 0, 0.72), 0.12, 0.2, dark, 8), "body"),
              (ck.ball("bowl", 1.0, (0, 0, zb), bronze, (0.44, 0.44, 0.37)), "body"),
              (T("band", (0, 0, zb + 0.07), (0, 0, zb + 0.17), 0.445, 0.42, gold, 14), "body"),
              (T("band_lip", (0, 0, zb + 0.16), (0, 0, zb + 0.2), 0.43, 0.43, gold2, 14), "body")]
    for k in range(8):                 # gomos em relevo no bojo
        a = math.tau * (k + 0.5) / 8
        if abs(a - math.pi * 1.5) < 0.5:
            continue                   # a frente é da máscara
        d = V((math.cos(a), math.sin(a), 0))
        parts.append((ck.ball("rib%d" % k, 1.0, d * 0.38 + V((0, 0, zb - 0.08)), dark, (0.07, 0.07, 0.2)), "body"))
    for o in lk.mask(ck, "cmask", V((0, -0.44, zb + 0.0)), 0.19, M, tears=(1,)):
        parts.append((o, "body"))
    # ---- tampa furada (head): cúpula com brasas, chaminé e coroa ----
    zl = zb + 0.18
    parts += [(ck.ball("lid", 1.0, (0, 0, zl), dark, (0.4, 0.4, 0.44)), "head"),
              (T("chimney", (0, 0, zl + 0.4), (0, 0, zl + 0.56), 0.13, 0.09, bronze, 8), "head"),
              (T("chimney_lip", (0, 0, zl + 0.54), (0, 0, zl + 0.585), 0.115, 0.125, gold2, 8), "head"),
              (ck.ball("chimney_glow", 0.08, (0, 0, zl + 0.56), ember, (1, 1, 0.5)), "head")]
    for row, (th, n_, rr) in enumerate(((62, 8, 0.075), (34, 5, 0.06))):       # brasas: janelas acesas na cúpula
        for k in range(n_):
            a = math.tau * (k + 0.5 * row) / n_
            t = math.radians(th)
            pos = V((0.4 * math.sin(t) * math.cos(a), 0.4 * math.sin(t) * math.sin(a), zl + 0.44 * math.cos(t)))
            parts.append((ck.ball("ember%d_%d" % (row, k), rr, pos * 1.0 + V((0, 0, 0)), ember, (1, 1, 1)), "head"))
    # ---- suspensão (hang): três correntes da boca do bojo à argola de cima ----
    hub = V((0, 0, 2.02))
    for k in range(3):
        a = math.pi / 2 + math.tau * k / 3
        p0 = V((math.cos(a) * 0.43, math.sin(a) * 0.43, zb + 0.2))
        parts.append((ck.ball("lug%d" % k, 0.05, p0, gold2), "body"))
        for o in _chain("hang%d" % k, p0, hub - V((0, 0, 0.03)), gold, 0.09, 0.05, 0.02):
            parts.append((o, "hang"))
    parts.append((ck.ball("hub", 0.07, hub, gold2), "hang"))
    for k in range(8):
        a0, a1 = math.tau * k / 8, math.tau * (k + 1) / 8
        parts.append((T("ring%d" % k, hub + V((math.cos(a0) * 0.12, 0, 0.14 + math.sin(a0) * 0.12)), hub + V((math.cos(a1) * 0.12, 0, 0.14 + math.sin(a1) * 0.12)),
                        0.024, 0.024, gold2, 5), "hang"))
    # ---- pernas: correntes grossas do pé ao chão, com pesos em gota ----
    for s, sx in (("leg_r", -1), ("leg_l", 1)):
        x = sx * 0.15
        for o in _chain(s + "_chain", (x, 0, 0.57), (x, 0, 0.2), bronze, 0.11, 0.085, 0.03, dark):
            parts.append((o, s))
        parts += [(ck.ball(s + "_weight", 0.075, (x, 0, 0.13), bronze, (1, 1, 1.35)), s), (T(s + "_weight_cap", (x, 0, 0.19), (x, 0, 0.22), 0.05, 0.035, gold, 6), s),
                  (cone(s + "_weight_tip", (x, 0, 0.05), (x, 0, 0.015), 0.03, gold2, 5), s)]
    # ---- braços: alça de ouro no bojo, corrente e um turíbulo pequeno aceso ----
    for s, sx in (("arm_r", -1), ("arm_l", 1)):
        x = sx * 0.5
        parts += [(ck.ball(s + "_lug", 0.065, (sx * 0.44, 0, zb + 0.04), gold2, (1.3, 0.8, 0.8)), "body"),
                  (ck.ball(s + "_pod", 0.11, (x, 0, 0.5), bronze, (1, 1, 0.95)), s), (ck.ball(s + "_pod_glow", 0.075, (x, 0, 0.575), ember, (1, 1, 0.6)), s),
                  (T(s + "_pod_band", (x, 0, 0.52), (x, 0, 0.56), 0.112, 0.105, gold, 8), s), (cone(s + "_pod_tip", (x, 0, 0.41), (x, 0, 0.33), 0.04, gold2, 5), s)]
        for o in _chain(s + "_chain", (x, 0, zb + 0.03), (x, 0, 0.62), gold, 0.085, 0.055, 0.022):
            parts.append((o, s))
    # ---- fumaça lilás ----
    parts += [(ck.ball("puff0", 0.13, (0.0, 0, 1.78), smoke, (1, 1, 0.9)), "smoke_a"), (ck.ball("puff1", 0.17, (0.08, 0.03, 1.95), smoke2, (1.1, 1, 0.9)), "smoke_a"),
              (ck.ball("puff2", 0.15, (-0.09, -0.02, 2.13), smoke, (1.1, 1, 0.85)), "smoke_b"), (ck.ball("puff3", 0.11, (0.04, 0.04, 2.3), smoke2), "smoke_b"),
              (ck.ball("puff4", 0.07, (-0.04, 0.0, 2.42), smoke), "smoke_b")]
    for obj, bone in parts:
        flat = "_chain" in obj.name or obj.name.startswith("hang")
        for p_ in obj.data.polygons:
            p_.use_smooth = not flat
        mk.lp.attach(bs._outward([obj])[0], arm, bone)

    z, one, nil = (0, 0, 0), (1, 1, 1), (0.001, 0.001, 0.001)
    add = lambda a_, name, keys, end, loop=True: _add_full(a_, name, keys, end, loop, ("hang", "smoke_a", "smoke_b"))
    r = lambda x=0.0, y=0.0, zz=0.0: (x, y, zz)
    p = lambda up=0.0, fwd=0.0: (0, up, fwd)
    sc = lambda k: (k, k, k)
    tau = math.tau
    ALL = ("body", "head", "arm_r", "arm_l", "leg_r", "leg_l", "hang", "smoke_a", "smoke_b")

    def base(end, smoke_k=1.0):
        d = {b_: [(1, z, z), (end, z, z)] for b_ in ("head", "arm_r", "arm_l", "leg_r", "leg_l")}
        for b_ in ("hang", "smoke_a", "smoke_b"):
            d[b_] = [(1, z, z, sc(smoke_k) if b_ != "hang" else one), (end, z, z, sc(smoke_k) if b_ != "hang" else one)]
        return d

    # idle: pêndulo lento, correntes atrasadas, tampa respira, fumaça sobe e engorda
    n, idle = 64, {b_: [] for b_ in ALL}
    for f in list(range(1, n, 3)) + [n]:
        ph = (f - 1) / (n - 1) * tau
        s_, s2 = math.sin(ph), math.sin(2 * ph)
        idle["body"].append((f, r(1.2 * s2, 0, 3.5 * s_), p(0.03 * (0.5 - 0.5 * math.cos(ph)))))
        idle["head"].append((f, r(-3 - 3 * s2), z))
        idle["arm_r"].append((f, r(3 * s2, 0, -5 * math.sin(ph - 0.7)), z))
        idle["arm_l"].append((f, r(-3 * s2, 0, -5 * math.sin(ph - 0.7)), z))
        idle["leg_r"].append((f, r(4 * s2, 0, -6 * math.sin(ph - 0.9)), z))
        idle["leg_l"].append((f, r(-4 * s2, 0, -6 * math.sin(ph - 0.9)), z))
        idle["hang"].append((f, z, z, one))
        idle["smoke_a"].append((f, r(0, 20 * s_, 0), p(0.04 * s2), sc(1.0 + 0.14 * s2)))
        idle["smoke_b"].append((f, r(0, -30 * s_, 0), p(0.06 * math.sin(2 * ph - 1.0)), sc(1.0 + 0.2 * math.sin(2 * ph - 1.0))))
    add(arm, "idle", idle, n)
    # run: inclina e balança; as correntes-pernas "andam" alternadas; a fumaça fica para trás
    n, run = 24, {b_: [] for b_ in ALL}
    for f in range(1, n + 1):
        ph = (f - 1) / (n - 1) * tau
        s_, c_ = math.sin(ph), math.cos(ph)
        run["body"].append((f, r(9 + 2 * math.cos(2 * ph), 0, 5 * s_), p(0.03 + 0.03 * math.sin(2 * ph))))
        run["head"].append((f, r(-4 - 4 * abs(s_)), z))
        run["arm_r"].append((f, r(8 - 18 * c_, 0, -6), z))
        run["arm_l"].append((f, r(8 + 18 * c_, 0, 6), z))
        run["leg_r"].append((f, r(-9 + 30 * c_, 0, -5 * s_), z))
        run["leg_l"].append((f, r(-9 - 30 * c_, 0, -5 * s_), z))
        run["hang"].append((f, z, z, one))
        run["smoke_a"].append((f, r(-22), p(0, -0.1), sc(0.9)))
        run["smoke_b"].append((f, r(-34), p(-0.04, -0.24), sc(0.8 + 0.06 * s_)))
    add(arm, "run", run, n)
    # attack: gira o turíbulo da direita para trás e bate à frente (impacto no quadro 5)
    add(arm, "attack", dict(base(16),
        body=[(1, z, z), (3, r(-8, 16, 0), p(0.05, -0.06)), (5, r(15, -18, 0), p(-0.02, 0.16)), (7, r(13, -20, 0), p(-0.02, 0.14)), (11, r(5, -6, 0), p(0, 0.05)), (16, z, z)],
        head=[(1, z, z), (3, r(-16), z), (5, r(2), z), (7, r(-8), z), (16, z, z)],
        arm_r=[(1, z, z), (3, r(70, 0, -18), z), (5, r(-98, 0, 6), z), (7, r(-84, 0, 8), z), (11, r(-24), z), (14, r(8), z), (16, z, z)],
        arm_l=[(1, z, z), (3, r(-20, 0, 12), z), (5, r(30, 0, 20), z), (11, r(8), z), (16, z, z)],
        leg_r=[(1, z, z), (3, r(-14), z), (5, r(26), z), (11, r(-8), z), (16, z, z)],
        leg_l=[(1, z, z), (3, r(-10), z), (5, r(20), z), (11, r(-6), z), (16, z, z)]), 16, loop=False)
    # atk_spin (Balanço do Turíbulo): gira em pé com os dois turíbulos abertos pela força
    add(arm, "atk_spin", dict(base(24),
        body=[(1, z, z), (5, r(0, -45, 0), p(0.06)), (9, r(4, 60, 0), p(0.1)), (13, r(4, 200, 0), p(0.1)), (17, r(2, 330, 0), p(0.06)), (21, r(0, 368, 0), z), (24, r(0, 360, 0), z)],
        head=[(1, z, z), (5, r(-10), z), (13, r(-18), z), (21, r(2), z), (24, z, z)],
        arm_r=[(1, z, z), (5, r(0, 0, -30), z), (9, r(0, 0, -80), z), (17, r(0, 0, -76), z), (21, r(0, 0, -20), z), (24, z, z)],
        arm_l=[(1, z, z), (5, r(0, 0, 30), z), (9, r(0, 0, 80), z), (17, r(0, 0, 76), z), (21, r(0, 0, 20), z), (24, z, z)],
        leg_r=[(1, z, z), (9, r(0, 0, -38), z), (17, r(0, 0, -34), z), (24, z, z)],
        leg_l=[(1, z, z), (9, r(0, 0, 38), z), (17, r(0, 0, 34), z), (24, z, z)]), 24, loop=False)
    # cast_ground (Fumo Doce): sobe, abre a tampa e despeja a fumaça para a frente
    cg = base(22)
    cg.update(body=[(1, z, z), (5, r(-8), p(0.1, -0.04)), (10, r(24), p(0.04, 0.1)), (15, r(22), p(0.03, 0.09)), (22, z, z)],
              head=[(1, z, z), (5, r(-10), z), (10, r(-58), z), (15, r(-52), z), (19, r(4), z), (22, z, z)],
              arm_r=[(1, z, z), (5, r(0, 0, -30), z), (10, r(-20, 0, -16), z), (22, z, z)],
              arm_l=[(1, z, z), (5, r(0, 0, 30), z), (10, r(-20, 0, 16), z), (22, z, z)],
              smoke_a=[(1, z, z, one), (5, z, z, sc(0.7)), (10, r(40), p(-0.1, 0.3), sc(1.7)), (15, r(46), p(-0.16, 0.42), sc(1.9)), (22, z, z, one)],
              smoke_b=[(1, z, z, one), (5, z, z, sc(0.6)), (10, r(70), p(-0.3, 0.6), sc(1.6)), (15, r(78), p(-0.42, 0.8), sc(2.0)), (22, z, z, one)])
    add(arm, "cast_ground", cg, 22, loop=False)
    add(arm, "hit", dict(base(10),
        body=[(1, z, z), (2, r(-14, 0, 6), p(0.03, -0.08)), (5, r(7, 0, -4), p(0, 0.02)), (8, r(-3), z), (10, z, z)],
        head=[(1, z, z), (2, r(-34), z), (4, r(4), z), (6, r(-12), z), (10, z, z)],
        arm_r=[(1, z, z), (2, r(-26, 0, -24), z), (6, r(10), z), (10, z, z)],
        arm_l=[(1, z, z), (2, r(-26, 0, 24), z), (6, r(10), z), (10, z, z)],
        leg_r=[(1, z, z), (2, r(-22), z), (6, r(8), z), (10, z, z)],
        leg_l=[(1, z, z), (2, r(-22), z), (6, r(8), z), (10, z, z)]), 10, loop=False)
    # die: a fumaça some, o turíbulo despenca no pé, as correntes afrouxam, a tampa pula e fica caída aberta
    dn = -0.54
    add(arm, "die", {
        "root": [(1, z, z), (5, z, (0, 0.06, 0)), (11, z, (0, dn, 0)), (13, z, (0, dn + 0.05, 0)), (15, z, (0, dn, 0)), (28, z, (0, dn, 0))],
        "body": [(1, z, z), (5, r(-6, 0, 4), z), (11, r(4, 0, -3), z), (16, r(3, 0, 9), z), (22, r(3, 0, 12), z), (28, r(3, 0, 12), z)],
        "head": [(1, z, z), (5, r(-6), z), (11, r(-30), z), (14, r(-74), z), (18, r(-96), z), (21, r(-88), z), (24, r(-96), z), (28, r(-96), z)],
        "hang": [(1, z, z, one), (9, z, z, one), (14, r(0, 0, 10), z, (1, 0.5, 1)), (20, r(0, 0, 24), (0, -0.04, 0), (1, 0.16, 1)), (28, r(0, 0, 24), (0, -0.04, 0), (1, 0.16, 1))],
        "arm_r": [(1, z, z), (5, r(-10, 0, -20), z), (11, r(0, 0, -30), z), (15, r(0, 0, -64), z), (28, r(0, 0, -64), z)],
        "arm_l": [(1, z, z), (5, r(-10, 0, 20), z), (11, r(0, 0, 30), z), (15, r(0, 0, 52), z), (28, r(0, 0, 52), z)],
        "leg_r": [(1, z, z), (5, r(-10), z), (11, r(20, 0, -70), z), (14, r(30, 0, -84), z), (28, r(30, 0, -84), z)],
        "leg_l": [(1, z, z), (5, r(-10), z), (11, r(-25, 0, 72), z), (14, r(-35, 0, 86), z), (28, r(-35, 0, 86), z)],
        "smoke_a": [(1, z, z, one), (6, z, p(0.1), sc(1.3)), (14, z, p(0.4), nil), (28, z, p(0.4), nil)],
        "smoke_b": [(1, z, z, one), (6, z, p(0.14), sc(1.4)), (16, z, p(0.5), nil), (28, z, p(0.5), nil)],
    }, 28, loop=False)
    return _rest(arm)


BUILDERS = {
    "mob_reveler": reveler,
    "mob_convert": convert,
    "mob_ceremony_master": ceremony_master,
}
HUMANOIDS = set(BUILDERS)          # skinned (ck.export_glb); o que entra depois daqui é de peças rígidas (lp.export_glb)
BUILDERS["mob_vain_reflection"] = vain_reflection
BUILDERS["mob_living_censer"] = living_censer
