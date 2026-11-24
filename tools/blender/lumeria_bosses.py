"""Ato III, parte 1 (45-50) — chefes do Excesso (de mundo, de masmorra e a raide) e os lacaios deles (design/gdd/ato3-excesso-45-50.md §3 e §4):

  mob_vindima        Dona Vindima, a Vinha que Bebe (chefe de mundo, 47): cepa gigante em forma de matrona. Saia de folhas
                     roxas em três camadas, TONEL deitado no ventre (a tampa da frente é a boca: o osso `core` abre o
                     queixo e mostra o vinho aceso), tronco de cepa torcida, xale de folhas, máscara de porcelana com a
                     lágrima de vinho, touca de folhas com coque de uvas. Braço +X (`arm_r`) = chicote de vinha; braço -X
                     (`arm_l`) = cacho de uvas na mão. Peças rígidas nos ossos de VINDIMA_BONES (pernas = quadrantes da saia,
                     filhas da RAIZ: o tronco inclina sem enterrar a barra). ~2,65 m no modelo.
  mob_thirsty_vine   Vinha Sedenta (46, parada; também o lacaio `vine_sprout`): cepa retorcida de duas hastes trançadas,
                     folhas roxas, cacho-boca grande na ponta e dois cachos-bocas menores nas gavinhas. Peças rígidas
                     (VINE_BONES). ~1,9 m.
  mob_prima_donna    A Prima-Donna do Palco (chefe de mundo, 48): cantora de pernas compridas, corpete de veludo vinho e
                     gola creme, peruca alta de porcelana com um pássaro no topo, máscara com a lágrima e a boca aberta,
                     leque na mão direita e o VESTIDO-GAIOLA: barras e aros de ouro do cinto ao chão, com pássaros de
                     porcelana pousados nos aros (a barra pesa no osso `tail`, como a cauda da Vessaline: a gaiola fica
                     de pé no chão e estica com o quadril em vez de enterrar). Skinned (corpo do kit, como as Demônias).
  mob_chorister      Corista (46, à distância; também `chorister_echo`): figura de túnica lilás e capuz de ponta caída,
                     máscara com a lágrima e a BOCA COSTURADA, peito aberto com a garganta de tubos de órgão (bocas dos
                     tubos acesas: é o que a câmera alta vê), fitas claras nas costas. Skinned.

  mob_varo           Varo Taça-Cheia, o Anfitrião (dg_cellars, 47): humano OBESO (corpo próprio, VARO["body"]) de casaco e capa
                     vinho, gola de pele creme, guardanapo no pescoço sobre a barriga de colete, peruca creme de rolos com um
                     cacho de uvas de lado, máscara com a lágrima de vinho; garrafão-maça na mão direita (pelo gargalo, cinta
                     de cravos de ouro) e taça cheia na esquerda. Skinned. O `cast_channel` dele é O Banquete (_varo_feast).
  mob_ressoa         Mestra Ressoa, a Regente (dg_conservatory, 49): regente de pernas compridas SEM cabeça: no lugar, um
                     someiro de ouro com 9 tubos de órgão em leque + 4 graves atrás (bocas e topos acesos), a máscara da
                     lágrima pendurada na frente; casaca de veludo com abas, peitilho creme, dragonas, batuta. Skinned.
  mob_organ_pipe     Tubo de Órgão (lacaio parado da Ressoa): coluna de 5 tubos num soco, bocas/topos acesos (`core` = a nota).
  mob_sylvare_echo   O Eco de Amarante (raide, 50): vestido de espelhos SEM corpo (saia de facetas em 3 camadas, corpete vazio,
                     gola de cacos), coroa vazia flutuando sobre o vapor perfumado (`core`) e uma lágrima só; duas luvas
                     vazias (a de +X leva um caco de espelho). Flutua a 0,1 m. Peças rígidas (ECHO_BONES).
  mob_sense_pedestal[_sight|_hearing|_smell|_taste]   Pedestais dos Sentidos (lacaios parados do Eco): coluna de porcelana com
                     prato de luz na cor do sentido e o emblema flutuando (olho, corneta, incensário, taça; sem sufixo = máscara).

Clipes. Rígidos (EntityView._clip toca o nome do kit se o modelo tiver; senão FORM_CLIP): idle run attack cast hit die +
`atk_sweep` (8), e na Vindima também `atk_throw` (7), `cast_ground` (10), `summon` (11), `shout` (7) e os genéricos
`maul pounce slam roar brace` (cópias retimadas: nenhuma skill nova de chefe cai num clipe vazio). Entre parênteses o quadro
do impacto (= EntityView.IMPACT_FRAME). Todo osso tem chave em todo clipe (o Godot não herda pose).
Eco: todos os nomes do kit de chefe (MOB_BOSS_KEEP + jump/dash/block) + os genéricos, a partir de 6 gestos (_echo_clips);
parados (tubo, pedestais): idle run attack cast cast_ground shout hit die.
Skinned: idle run attack cast hit die block + gestos (Prima-Donna, Varo, Ressoa: ck.MOB_BOSS_KEEP + jump/dash; Corista: magias + shout);
o `attack` da Corista é o `shout` (canta de peito aberto), o da Prima-Donna o corte de leque (`atk_1h_a`).

    import mob_kit; mob_kit.build_all(r"<abs>/assets/models", only=set(lumeria_bosses.BUILDERS))
Prévia e conta de chão sem janela: tools/blender/lumeria_mobs_preview.py -- --module=lumeria_bosses ...
"""
import math
import random

import bmesh
import bpy
from mathutils import Vector

import chibi_kit as ck
import mob_kit as mk
import act2_bosses
import berserker_sets as bs
import boss_gestures as bg
import lumeria_kit as lk
import lumeria_mobs as lm

V = Vector
Z0 = (0, 0, 0)

BARK = (0.3, 0.17, 0.18)           # cepa: castanho-vinho
BARK_D = (0.17, 0.09, 0.11)
BARK_L = (0.45, 0.29, 0.27)
LEAF = (0.38, 0.15, 0.44)          # folhas roxas
LEAF_L = (0.57, 0.31, 0.62)
LEAF_D = (0.23, 0.08, 0.29)
GRAPE = (0.3, 0.08, 0.36)
GRAPE_L = (0.5, 0.2, 0.55)
WINE = (0.86, 0.16, 0.34)          # vinho aceso (lágrima, boca do tonel, línguas)
WOOD = (0.5, 0.31, 0.17)           # aduelas do tonel
WOOD_L = (0.68, 0.48, 0.28)        # tampa
TOOTH = (0.95, 0.9, 0.78)
VELVET = (0.5, 0.11, 0.23)         # veludo vinho
VELVET_D = (0.3, 0.07, 0.16)
CREAM = (0.96, 0.91, 0.83)
WIG = (0.93, 0.7, 0.76)             # peruca empoada (rosa-pó claro: separa do rosto de porcelana)
ROSE = (0.86, 0.56, 0.64)
ROBE = (0.55, 0.43, 0.72)           # túnica do coro: lilás (as Veladas são rosa-pó)
ROBE_D = (0.28, 0.18, 0.42)
ROBE_L = (0.93, 0.88, 0.93)
NOTE = (1.0, 0.62, 0.86)           # boca dos tubos / som


# ---------------------------------------------------------------------------
# helpers de malha
# ---------------------------------------------------------------------------
def _cr(pts, sub=3):
    """Catmull-Rom pelos pontos de controle."""
    P = [V(p) for p in pts]
    out = []
    for i in range(len(P) - 1):
        p0, p1, p2, p3 = P[max(i - 1, 0)], P[i], P[i + 1], P[min(i + 2, len(P) - 1)]
        for k in range(sub):
            t = k / sub
            out.append(0.5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t * t + (-p0 + 3 * p1 - 3 * p2 + p3) * t ** 3))
    out.append(P[-1])
    return out


def _sweep(name, pts, radii, material, segs=6, closed=False):
    """Tubo contínuo pelos pontos (sem emendas nas curvas). radii = lista por ponto ou (r0, r1). closed = aro."""
    pts = [V(p) for p in pts]
    n = len(pts)
    if len(radii) == 2 and n != 2:
        radii = [radii[0] + (radii[1] - radii[0]) * i / (n - 1) for i in range(n)]
    bm_ = bmesh.new()
    t0 = (pts[1] - pts[0]).normalized()
    ref = V((0, 0, 1)) if abs(t0.z) < 0.9 else V((1, 0, 0))
    u = (ref - t0 * ref.dot(t0)).normalized()
    rings = []
    for i, p in enumerate(pts):
        a_, b_ = (pts[(i - 1) % n], pts[(i + 1) % n]) if closed else (pts[max(i - 1, 0)], pts[min(i + 1, n - 1)])
        t = (b_ - a_).normalized()
        u = u - t * u.dot(t)
        u = u.normalized() if u.length > 1e-5 else t.orthogonal().normalized()
        w = t.cross(u)
        rings.append([bm_.verts.new(p + (u * math.cos(math.tau * k / segs) + w * math.sin(math.tau * k / segs)) * radii[i]) for k in range(segs)])
    for i in range(n if closed else n - 1):
        ra, rb_ = rings[i], rings[(i + 1) % n]
        for k in range(segs):
            bm_.faces.new((ra[k], ra[(k + 1) % segs], rb_[(k + 1) % segs], rb_[k]))
    if not closed:
        bm_.faces.new(rings[0][::-1])
        bm_.faces.new(rings[-1])
    bmesh.ops.recalc_face_normals(bm_, faces=bm_.faces[:])
    return ck.mesh_from(name, bm_, material)


def _vine(name, pts, r0, r1, material, segs=6, sub=3):
    return _sweep(name, _cr(pts, sub), (r0, r1), material, segs)


def _hoop(name, c, r, thick, material, n=20, segs=5, depth=1.0):
    c = V(c)
    return _sweep(name, [c + V((math.cos(math.tau * k / n) * r, math.sin(math.tau * k / n) * r * depth, 0)) for k in range(n)], [thick] * n, material, segs, True)


def _leaf(name, root, tip, w, material, mid=0.42, thick=0.022):
    root, tip = V(root), V(tip)
    ax = tip - root
    wd = ax.cross(V((0, 0, 1)))
    if wd.length < 1e-3:
        wd = V((1, 0, 0))
    return ck.blade(name, root, tip, w, thick, material, wd, mid)


def _tier(name, n, z0, z1, r0, r1, w, material, phase=0.0, mid=0.5, mats=None):
    """Camada de saia de folhas: n folhas da cintura (r0, z0) à barra (r1, z1). Devolve [(malha, ângulo)]."""
    out = []
    for i in range(n):
        a = math.tau * (i + phase) / n
        dr = V((math.cos(a), math.sin(a), 0))
        tang = V((-math.sin(a), math.cos(a), 0))
        m_ = mats[i % len(mats)] if mats else material
        out.append((ck.blade("%s%d" % (name, i), dr * r0 + V((0, 0, z0)), dr * r1 + V((0, 0, z1)), w, 0.024, m_, tang, mid), a))
    return out


def _grapes(name, top, length, r, mats, seed=0, down=(0, 0, -1)):
    """Cacho de uvas pendurado em `top`: largo no alto, uma uva na ponta. mats = (uva escura, uva clara)."""
    rnd = random.Random(seed)
    top, d = V(top), V(down).normalized()
    s1 = d.orthogonal().normalized()
    s2 = d.cross(s1)
    g = r * 0.4
    rows = max(3, int(round(length / (g * 1.2))))
    out = [mk.blob(name + "_core", 1.0, top + d * length * 0.45, mats[0], (r * 0.62, r * 0.62, length * 0.44), 1)]
    for i in range(rows):
        t = i / (rows - 1)
        rr = r * (1.0 - t) ** 0.7 * (0.6 + 0.4 * min(1.0, t * 4))
        cnt = max(1, int(round(math.tau * rr / (g * 1.55)))) if rr > g * 0.4 else 1
        ph = rnd.random() * math.tau
        for k in range(cnt):
            a = ph + math.tau * k / cnt
            rad = (s1 * math.cos(a) + s2 * math.sin(a)) * max(0.0, rr - g * 0.35) if cnt > 1 else V((0, 0, 0))
            c = top + d * (g * 0.5 + (length - g) * t) + rad + V((rnd.uniform(-1, 1), rnd.uniform(-1, 1), rnd.uniform(-1, 1))) * g * 0.12
            out.append(mk.blob("%s_g%d_%d" % (name, i, k), g * rnd.uniform(0.88, 1.1), c, mats[1] if rnd.random() < 0.38 else mats[0], (1, 1, 1), 1))
    return out


def _maw(name, c, w, h, M, facing=(0, -1, 0), teeth=4):
    """Boca de cacho: fenda escura, língua de vinho acesa e dentes claros em cima e embaixo. Frente = facing."""
    objs = [ck.ball(name + "_in", 1.0, (0, 0, 0), M["ink"], (w * 0.5, w * 0.2, h * 0.5)),
            ck.ball(name + "_tongue", 1.0, (0, -w * 0.1, -h * 0.14), M["wine"], (w * 0.27, w * 0.2, h * 0.2))]
    for i in range(teeth):
        x = (i - (teeth - 1) / 2) * w * 0.84 / teeth
        objs.append(mk.cone("%s_tu%d" % (name, i), (x, -w * 0.15, h * 0.4), (x, -w * 0.24, h * 0.0), w * 0.075, M["tooth"], 5))
        if i < teeth - 1:
            x2 = x + w * 0.42 / teeth
            objs.append(mk.cone("%s_tl%d" % (name, i), (x2, -w * 0.13, -h * 0.42), (x2, -w * 0.22, -h * 0.04), w * 0.07, M["tooth"], 5))
    return lk.place(objs, c, facing)


def _flat(o):
    o["flat"] = True
    return o


class _Parts:
    """Peças rígidas por osso: no fim cada osso vira UMA malha (ck._join) presa ao osso."""

    def __init__(self):
        self.by = {}

    def add(self, bone, *objs):
        for o in objs:
            if isinstance(o, (list, tuple)):
                self.add(bone, *o)
            else:
                self.by.setdefault(bone, []).append(o)

    def finish(self, arm, cid):
        for bone, objs in self.by.items():
            bs._outward(objs)
            for o in objs:
                sm = not o.get("flat", False)
                for p in o.data.polygons:
                    p.use_smooth = sm
            o = ck._join(objs, "%s_%s" % (cid, bone)) if len(objs) > 1 else objs[0]
            mk.lp.attach(o, arm, bone)


# ---------------------------------------------------------------------------
# helpers de clipe (rígidos)
# ---------------------------------------------------------------------------
r, p, limb = bg.r, bg.p, bg.limb


def _up(seq):
    """seq = [(quadro, rot[, loc])] -> chaves de um osso de pé."""
    return [(k[0], k[1], k[2] if len(k) > 2 else Z0) for k in seq]


def _splay(bone, seq):
    """Quadrante da saia (osso de perna pendurado): seq = [(quadro, graus)], > 0 = abre para FORA (radial)."""
    s = -1 if bone.endswith("r") else 1
    f = -1 if bone[4] == "f" else 1
    return [(k[0], (f * k[1] * 0.7, 0, s * k[1] * 0.7), Z0) for k in seq]


def _clip(arm, name, end, keys, loop=False):
    full = {}
    for b in arm.data.bones:
        ks = keys.get(b.name)
        if not ks:
            ks = [(1, Z0, Z0), (end, Z0, Z0)]
        else:
            ks = list(ks)
            if ks[0][0] > 1:
                ks.insert(0, (1, Z0, Z0))
            if ks[-1][0] < end:
                ks.append((end,) + tuple(ks[-1][1:]) if name == "die" else (end, Z0, Z0))
        full[b.name] = ks
    mk.lp.add_action(arm, name, full, end, loop=loop)


def _retime(keys, src, dst):
    """Cópia das chaves com o impacto do quadro src no quadro dst (o preparo estica/encolhe, o resto desloca)."""
    g = lambda f: int(round(1 + (f - 1) * (dst - 1) / float(src - 1))) if f <= src else f + dst - src
    out = {}
    for b, ks in keys.items():
        seen, lst = set(), []
        for k in ks:
            f = g(k[0])
            if f in seen:
                continue
            seen.add(f)
            lst.append((f,) + tuple(k[1:]))
        out[b] = lst
    return out


def _loop(n, step, fn):
    """Chaves de um laço de n quadros: fn(fase) -> (rot, loc); a última chave repete a primeira."""
    out = []
    for f in list(range(1, n, step)) + [n]:
        rot, loc = fn((f - 1) / (n - 1) * math.tau)
        out.append((f, rot, loc))
    return out


# ---------------------------------------------------------------------------
# Dona Vindima, a Vinha que Bebe
# ---------------------------------------------------------------------------
VINDIMA_BONES = {            # root/body/head/core de pé (x = X, y = para cima, z = -Y); braços e pernas pendurados
    "root": ((0, 0, 0), (0, 0, 0.2), None),
    "body": ((0, 0, 0.95), (0, 0, 1.35), "root"),            # cintura: o tonel e o tronco inclinam, a saia fica
    "head": ((0, -0.02, 2.02), (0, -0.02, 2.3), "body"),
    "arm_r": ((0.52, 0, 1.82), (0.52, 0, 1.42), "body"),     # chicote de vinha
    "arm_l": ((-0.52, 0, 1.82), (-0.52, 0, 1.42), "body"),   # cacho de uvas
    "leg_fr": ((0.3, -0.3, 0.95), (0.3, -0.3, 0.6), "root"),
    "leg_fl": ((-0.3, -0.3, 0.95), (-0.3, -0.3, 0.6), "root"),
    "leg_br": ((0.3, 0.3, 0.95), (0.3, 0.3, 0.6), "root"),
    "leg_bl": ((-0.3, 0.3, 0.95), (-0.3, 0.3, 0.6), "root"),
    "core": ((0, -0.57, 0.92), (0, -0.57, 1.12), "body"),    # queixo do tonel: X+ = abre
}
VINDIMA_LEGS = ("leg_fr", "leg_fl", "leg_br", "leg_bl")


def vindima(cid="mob_vindima"):
    arm = mk.lp.make_armature("rig_" + cid, VINDIMA_BONES)
    m = lambda n, col, rough=0.8, em=0.0: ck.mat("m_%s_%s" % (cid, n), col, rough, em)
    bark, bark_d, bark_l = m("bark", BARK, 0.9), m("bark_d", BARK_D, 0.9), m("bark_l", BARK_L, 0.9)
    leaf, leaf_l, leaf_d = m("leaf", LEAF), m("leaf_l", LEAF_L), m("leaf_d", LEAF_D)
    grape = (m("grape", GRAPE, 0.45), m("grape_l", GRAPE_L, 0.45))
    wood, wood_l = m("wood", WOOD, 0.85), m("wood_l", WOOD_L, 0.85)
    M = {"porc": m("mask", lm.MASK, 0.3), "gold": m("gold", lm.OLD_GOLD, 0.4), "gold2": m("gold2", lm.BRIGHT_GOLD, 0.35), "ink": m("ink", lm.INK, 0.6),
         "glow": m("tear", WINE, 0.3, 2.0), "wine": m("wine", WINE, 0.3, 1.6), "tooth": m("tooth", TOOTH, 0.5)}
    gold, gold2, ink, wine = M["gold"], M["gold2"], M["ink"], M["wine"]
    P = _Parts()

    # ---------------- saia de folhas (raiz + quadrantes nas pernas) ----------------
    P.add("root", _flat(ck.tube("under", (0, 0, 0.05), (0, 0, 1.0), 0.66, 0.34, leaf_d, 14)))
    P.add("root", _sweep("belt", [(math.cos(a) * 0.4, math.sin(a) * 0.4, 1.0 + 0.03 * math.sin(a * 3)) for a in [math.tau * k / 14 for k in range(14)]],
                         [0.06] * 14, bark_d, 6, True))
    for o, _a in _tier("tierA", 10, 1.04, 0.56, 0.36, 0.84, 0.52, None, 0.0, 0.55, (leaf_l, leaf)):
        P.add("root", _flat(o))
    for o, _a in _tier("tierB", 11, 0.86, 0.3, 0.46, 0.86, 0.5, None, 0.5, 0.55, (leaf, leaf_d)):
        P.add("root", _flat(o))
    for o, a in _tier("tierC", 12, 0.72, 0.1, 0.56, 0.9, 0.5, None, 0.5, 0.6, (leaf_d, leaf)):
        sx, sy = (1 if math.cos(a) >= 0 else -1), (1 if math.sin(a) >= 0 else -1)
        P.add("leg_%s%s" % ("b" if sy > 0 else "f", "r" if sx > 0 else "l"), _flat(o))
    for i in range(5):               # cachinhos na barra da camada de cima
        a = math.tau * (i + 0.25) / 5
        P.add("root", _grapes("hemgrape%d" % i, (math.cos(a) * 0.83, math.sin(a) * 0.83, 0.6), 0.24, 0.085, grape, 20 + i))
    for bone, sx, sy in (("leg_fr", 1, -1), ("leg_fl", -1, -1), ("leg_br", 1, 1), ("leg_bl", -1, 1)):      # raízes-pés
        for k, (dx, dy) in enumerate(((0.3, 0.12), (0.12, 0.3))):
            P.add(bone, _vine("%s_root%d" % (bone, k), [(sx * 0.3, sy * 0.3, 0.42), (sx * (0.34 + dx * 0.6), sy * (0.34 + dy * 0.6), 0.16),
                                                        (sx * (0.36 + dx), sy * (0.36 + dy), 0.07)], 0.1, 0.035, bark_d, 6, 2))

    # ---------------- tonel no ventre (eixo em Y) + tronco de cepa ----------------
    zc_ = 1.36
    ys = (-0.56, -0.36, -0.1, 0.16, 0.34)
    rs = (0.4, 0.46, 0.48, 0.45, 0.39)
    P.add("body", _flat(_sweep("barrel", [(0, y, zc_) for y in ys], list(rs), wood, 12)))
    for k, (y, rr) in enumerate(((-0.47, 0.44), (-0.1, 0.495), (0.26, 0.435))):
        P.add("body", _sweep("hoop%d" % k, [(0, y - 0.035, zc_), (0, y + 0.035, zc_)], [rr, rr], gold, 12))
    yf = -0.575                       # tampa da frente = a boca: metade de cima fixa, metade de baixo é o queixo (core)
    arc = lambda a0, a1, n=7, rad=0.37: [(rad * math.cos(a0 + (a1 - a0) * k / n), zc_ + rad * math.sin(a0 + (a1 - a0) * k / n)) for k in range(n + 1)]
    P.add("body", _flat(lm._plate("lid_up", arc(0.0, math.pi), yf, 0.04, wood_l)))
    P.add("core", _flat(lm._plate("lid_lo", arc(math.pi, math.tau), yf, 0.04, wood_l)))
    P.add("body", ck.ball("wine_in", 1.0, (0, yf + 0.07, zc_ - 0.02), wine, (0.34, 0.03, 0.3)))
    P.add("body", ck.ball("gullet", 1.0, (0, yf + 0.05, zc_ - 0.1), ink, (0.2, 0.03, 0.14)))
    for i in range(5):               # dentes de madeira ao longo da emenda
        x = (i - 2) * 0.13
        P.add("body", mk.cone("tooth_u%d" % i, (x, yf - 0.02, zc_ + 0.035), (x, yf - 0.035, zc_ - 0.09), 0.05, M["tooth"], 5))
        if i < 4:
            P.add("core", mk.cone("tooth_l%d" % i, (x + 0.065, yf - 0.02, zc_ - 0.035), (x + 0.065, yf - 0.035, zc_ + 0.07), 0.045, M["tooth"], 5))
    for sx in (-1, 1):                # olhos-nós da tampa: dois batoques de ouro (a "cara" do tonel lê de frente)
        P.add("body", ck.ball("bung%d" % sx, 0.05, (sx * 0.17, yf - 0.02, zc_ + 0.2), gold2, (1, 0.5, 1)))
    P.add("core", ck.tube("spigot", (0, yf - 0.01, zc_ - 0.26), (0, yf - 0.16, zc_ - 0.27), 0.04, 0.03, gold2, 6),
          ck.tube("spigot_key", (0, yf - 0.1, zc_ - 0.25), (0, yf - 0.1, zc_ - 0.16), 0.02, 0.03, gold, 5),
          ck.ball("drip", 0.035, (0, yf - 0.16, zc_ - 0.33), M["glow"], (0.8, 0.8, 1.5)))
    # tronco: duas hastes trançadas que sobem por trás do tonel e abraçam-no por cima
    for k, ph in enumerate((0.0, math.pi)):
        pts = []
        for i in range(8):
            t = i / 7
            a = ph + t * math.tau * 0.9
            rad = 0.17 * (1 - 0.3 * t)
            pts.append((math.cos(a) * rad, 0.12 - 0.1 * t + math.sin(a) * rad, 0.92 + t * 0.98))
        P.add("body", _vine("trunk%d" % k, pts, 0.25, 0.2, bark if k == 0 else bark_l, 8, 2))
    P.add("body", mk.blob("pelvis", 1.0, (0, 0.06, 1.0), bark_d, (0.46, 0.42, 0.16), 2))
    for sx in (-1, 1):
        P.add("body", _vine("grip%d" % sx, [(sx * 0.28, 0.2, 1.5), (sx * 0.36, 0.0, 1.82), (sx * 0.22, -0.3, 1.86), (sx * 0.3, -0.5, 1.62), (sx * 0.4, -0.52, 1.36)],
                            0.075, 0.035, bark_l if sx > 0 else bark, 6))
        P.add("body", _leaf("gripleaf%d" % sx, (sx * 0.34, -0.5, 1.5), (sx * 0.62, -0.62, 1.34), 0.22, leaf_l))
        P.add("body", mk.blob("shoulder%d" % sx, 0.2, (sx * 0.44, 0.02, 1.84), bark, (1.1, 0.95, 0.85), 2))
        P.add("body", mk.blob("bosom%d" % sx, 0.19, (sx * 0.19, -0.2, 1.84), bark_l, (1.0, 0.95, 0.9), 2))
    P.add("body", mk.blob("chest", 1.0, (0, 0.02, 1.84), bark, (0.42, 0.3, 0.2), 2), ck.tube("neck", (0, 0, 1.9), (0, -0.02, 2.08), 0.15, 0.12, bark_l, 8))
    for o, a in _tier("shawl", 10, 2.0, 1.76, 0.16, 0.66, 0.42, None, 0.5, 0.55, (leaf, leaf_l)):       # xale de folhas
        P.add("body", _flat(o))
    P.add("body", _grapes("brooch", (0, -0.36, 1.86), 0.22, 0.08, grape, 7))

    # ---------------- cabeça: nó de cepa, máscara com a lágrima de vinho, touca de folhas, coque de uvas ----------------
    hc = V((0, -0.02, 2.27))
    P.add("head", mk.blob("skull", 0.26, hc, bark_l, (1.0, 0.95, 1.0), 2))
    P.add("head", lk.mask(ck, "mask", hc + V((0, -0.205, -0.02)), 0.235, M, tears=(1,), tear_len=0.6))
    for o, a in _tier("bonnet", 9, hc.z + 0.24, hc.z + 0.06, 0.08, 0.5, 0.36, None, 0.25, 0.55, (leaf_l, leaf)):
        if abs((a + math.pi / 2 + math.pi) % math.tau - math.pi) > 0.5:          # aberta na frente: o rosto fica de fora
            P.add("head", _flat(o))
    P.add("head", _grapes("bun", hc + V((0, 0.1, 0.5)), 0.3, 0.17, grape, 3))
    P.add("head", ck.tube("bun_stem", hc + V((0, 0.08, 0.2)), hc + V((0, 0.1, 0.52)), 0.05, 0.03, bark_d, 6))
    for sx in (-1, 1):                # gavinhas enroladas nas têmporas
        pts = [hc + V((sx * (0.24 + 0.012 * i + 0.07 * math.sin(i * 1.3)), -0.05 + 0.07 * math.cos(i * 1.3), -0.02 - 0.05 * i)) for i in range(8)]
        P.add("head", _vine("curl%d" % sx, pts, 0.03, 0.012, bark_d, 5, 2))

    # ---------------- braço +X: chicote de vinha ----------------
    wp = [(0.5, 0, 1.82), (0.74, -0.02, 1.7), (0.92, -0.06, 1.36), (0.94, -0.12, 0.98), (0.84, -0.2, 0.68), (0.88, -0.32, 0.46), (1.04, -0.42, 0.38), (1.14, -0.4, 0.5)]
    P.add("arm_r", _vine("whip", wp, 0.13, 0.028, bark, 7))
    P.add("arm_r", _vine("whip2", [(0.6, 0.04, 1.74), (0.84, 0.08, 1.5), (0.98, 0.02, 1.16), (0.9, -0.06, 0.86), (0.98, -0.1, 0.7)], 0.05, 0.015, bark_l, 5))
    for k, (pt, d) in enumerate((((0.93, -0.08, 1.3), (0.26, 0.06, 0.06)), ((0.9, -0.16, 0.84), (0.24, -0.1, 0.02)), ((0.95, -0.37, 0.42), (0.12, -0.24, -0.02)))):
        P.add("arm_r", _leaf("whipleaf%d" % k, pt, V(pt) + V(d), 0.19, leaf_l if k % 2 else leaf))
    for k in range(4):               # espinhos
        q = _cr(wp, 3)[6 + k * 4]
        P.add("arm_r", mk.cone("thorn%d" % k, q, q + V((0.1, 0.03 * (-1) ** k, 0.04)), 0.03, bark_d, 5))
    # ---------------- braço -X: cacho de uvas na mão ----------------
    P.add("arm_l", _vine("armL", [(-0.5, 0, 1.82), (-0.74, -0.03, 1.66), (-0.88, -0.1, 1.3), (-0.84, -0.26, 1.06)], 0.14, 0.075, bark_l, 7))
    hand = V((-0.84, -0.28, 1.04))
    for k, d in enumerate(((0.07, -0.06, -0.16), (-0.08, -0.04, -0.16), (0.0, 0.08, -0.15), (0.0, -0.1, -0.12))):
        P.add("arm_l", _vine("finger%d" % k, [hand, hand + V(d) * 0.6 + V((d[0], d[1], 0)) * 0.6, hand + V(d)], 0.04, 0.015, bark_d, 5, 2))
    P.add("arm_l", _grapes("cluster", hand + V((0, 0, -0.07)), 0.56, 0.23, grape, 11))
    P.add("arm_l", _leaf("clusterleaf0", hand + V((0, 0, -0.04)), hand + V((-0.28, -0.1, -0.06)), 0.24, leaf_l),
          _leaf("clusterleaf1", hand + V((0, 0, -0.04)), hand + V((0.18, -0.22, -0.02)), 0.2, leaf))
    P.add("arm_l", mk.blob("elbowleaf", 0.1, (-0.88, -0.06, 1.34), leaf, (1.3, 1.0, 0.5), 1))
    P.finish(arm, cid)
    _vindima_clips(arm)
    return arm


def _vindima_clips(arm):
    L = VINDIMA_LEGS
    legs = lambda seq, k=1.0: {g: _splay(g, [(f, a * k) for f, a in seq]) for g in L}
    s, c = math.sin, math.cos
    # idle: respira, a boca do tonel entreabre, a saia ondula
    keys = {"body": _loop(48, 4, lambda ph: (r(1.5 * s(ph), 0, 1.5 * s(ph + 0.6)), p(0.02 * (0.5 - 0.5 * c(ph))))),
            "head": _loop(48, 4, lambda ph: (r(3 * s(ph + 0.8), 7 * s(ph + 1.4), 0), Z0)),
            "arm_r": _loop(48, 4, lambda ph: ((-4 * s(ph + 1.0), 0, -(4 + 3 * s(ph + 0.4))), Z0)),
            "arm_l": _loop(48, 4, lambda ph: ((-4 * s(ph + 1.6), 0, 4 + 3 * s(ph + 0.4)), Z0)),
            "core": _loop(48, 4, lambda ph: (r(6 + 6 * s(2 * ph)), Z0))}
    for i, g in enumerate(L):
        fs = -1 if g[4] == "f" else 1
        ss = -1 if g.endswith("r") else 1
        keys[g] = _loop(48, 4, lambda ph, i=i, fs=fs, ss=ss: ((fs * 1.5 * s(ph + i * 1.6), 0, ss * 1.5 * s(ph + i * 1.6)), Z0))
    _clip(arm, "idle", 48, keys, loop=True)
    # run: gingado de matrona, os quadrantes da saia sobem em diagonais
    keys = {"root": _loop(16, 1, lambda ph: (Z0, p(0.035 * abs(s(ph))))),
            "body": _loop(16, 1, lambda ph: (r(6, 5 * s(ph), 4 * c(ph)), Z0)),
            "head": _loop(16, 1, lambda ph: (r(-3, -4 * s(ph), -3 * c(ph)), Z0)),
            "arm_r": _loop(16, 1, lambda ph: ((-14 * c(ph), 0, -6), Z0)),
            "arm_l": _loop(16, 1, lambda ph: ((14 * c(ph), 0, 6), Z0)),
            "core": _loop(16, 1, lambda ph: (r(8 + 5 * s(2 * ph)), Z0))}
    for g, k in (("leg_fr", 1), ("leg_bl", 1), ("leg_fl", -1), ("leg_br", -1)):
        fs = -1 if g[4] == "f" else 1
        ss = -1 if g.endswith("r") else 1
        keys[g] = _loop(16, 1, lambda ph, k=k, fs=fs, ss=ss: ((fs * 0.7 * (4 + 6 * k * s(ph)), 0, ss * 0.7 * (4 + 6 * k * s(ph))), Z0))
    _clip(arm, "run", 16, keys, loop=True)
    # attack (5): chicotada de cima com o braço de vinha
    keys = {"body": _up([(3, r(-10, -14), p(0.03, -0.05)), (5, r(18, 16), p(-0.03, 0.12)), (7, r(15, 18), p(-0.03, 0.1)), (11, r(6, 6), p(0, 0.04))]),
            "head": _up([(3, r(-10)), (5, r(12)), (9, r(6))]),
            "arm_r": limb("arm_r", [(3, -150, 20), (5, -60, -10), (7, -52, -12), (11, -20)]),
            "arm_l": limb("arm_l", [(3, 10, 10), (5, 20, 14), (11, 6)]),
            "core": _up([(3, r(8)), (5, r(28)), (10, r(8))])}
    keys.update(legs([(3, 4), (5, -3), (9, 0)]))
    _clip(arm, "attack", 16, keys)
    # hit
    keys = {"body": _up([(2, r(-12, 0, 6), p(0.02, -0.08)), (5, r(4, 0, -3), p(0, -0.03))]),
            "head": _up([(2, r(-18, 0, 10)), (5, r(6, 0, -4))]),
            "arm_r": limb("arm_r", [(2, -25, 20), (5, 6)]), "arm_l": limb("arm_l", [(2, -25, 20), (5, 6)]),
            "core": _up([(2, r(32)), (6, r(6))])}
    keys.update(legs([(2, 6), (6, -2)]))
    _clip(arm, "hit", 10, keys)
    # cast (10): ergue os dois braços e lança para a frente
    keys = {"body": _up([(4, r(6), p(-0.04)), (8, r(-12), p(0.05)), (10, r(12), p(-0.02, 0.06)), (13, r(10), p(-0.02, 0.05))]),
            "head": _up([(8, r(-20)), (10, r(10)), (14, r(6))]),
            "arm_r": limb("arm_r", [(4, -20, 10), (8, -160, 25), (10, -80, 10), (13, -70, 10)]),
            "arm_l": limb("arm_l", [(4, -20, 10), (8, -160, 25), (10, -80, 10), (13, -70, 10)]),
            "core": _up([(8, r(10)), (10, r(45)), (14, r(30))])}
    keys.update(legs([(8, 5), (10, -2), (14, 0)]))
    _clip(arm, "cast", 20, keys)
    # atk_sweep / slam (8) = Pisada do Lagar: junta a saia, salta e desaba; a saia abre em roda
    stomp = {"root": _up([(3, Z0, p(-0.0)), (6, Z0, p(0.14)), (8, Z0, Z0), (9, Z0, p(0.02)), (10, Z0, Z0)]),
             "body": _up([(3, r(4), p(-0.05)), (6, r(-10), p(0.05, -0.03)), (8, r(16), p(-0.1, 0.08)), (10, r(14, 0, 2), p(-0.09, 0.07)), (13, r(10), p(-0.06, 0.05)),
                          (17, r(3), p(-0.01))]),
             "head": _up([(6, r(-14)), (8, r(16)), (12, r(8))]),
             "arm_r": limb("arm_r", [(3, -30, 20), (6, -150, 40), (8, -50, 60), (10, -46, 58), (14, -20, 25)]),
             "arm_l": limb("arm_l", [(3, -30, 20), (6, -150, 40), (8, -50, 60), (10, -46, 58), (14, -20, 25)]),
             "core": _up([(6, r(10)), (8, r(50)), (12, r(30))])}
    stomp.update(legs([(3, -3), (6, -5), (8, 22), (10, 20), (14, 8)]))
    _clip(arm, "atk_sweep", 22, stomp)
    _clip(arm, "slam", 22, stomp)
    _clip(arm, "pounce", 23, _retime(stomp, 8, 9))
    # atk_throw / maul (7) = Chicote de Vinha: arma atrás e estala longe
    lash = {"body": _up([(3, r(-6, -18), p(0.02, -0.05)), (5, r(-8, -28), p(0.03, -0.07)), (7, r(16, 22), p(-0.04, 0.14)), (9, r(14, 26), p(-0.04, 0.13)),
                         (12, r(8, 10), p(-0.02, 0.06))]),
            "head": _up([(5, r(-8, 10)), (7, r(12, -8)), (12, r(4))]),
            "arm_r": limb("arm_r", [(3, 30, 30), (5, 50, 45), (7, -92, -8), (9, -88, -12), (12, -50, -5), (15, -12)]),
            "arm_l": limb("arm_l", [(5, -20, 15), (7, 15, 20), (12, 5)]),
            "core": _up([(7, r(22)), (12, r(6))])}
    lash.update(legs([(5, 4), (7, -3), (12, 0)]))
    _clip(arm, "atk_throw", 18, lash)
    _clip(arm, "maul", 18, lash)
    # cast_ground (10) = Cachos Maduros: ergue o cacho e arremessa
    keys = {"body": _up([(4, r(4, 10), p(-0.03)), (8, r(-12, 22), p(0.04, -0.05)), (10, r(18, -18), p(-0.04, 0.12)), (13, r(14, -14), p(-0.03, 0.1)), (17, r(4))]),
            "head": _up([(8, r(-18)), (10, r(14)), (15, r(4))]),
            "arm_l": limb("arm_l", [(4, -40, 15), (8, -175, 20), (10, -75, 5), (13, -65, 5), (17, -20)]),
            "arm_r": limb("arm_r", [(8, 20, 25), (10, 10, 30), (17, 5)]),
            "core": _up([(8, r(8)), (10, r(40)), (15, r(15))])}
    keys.update(legs([(8, 5), (10, -3), (14, 0)]))
    _clip(arm, "cast_ground", 22, keys)
    # summon (11) = Brotos Sedentos: curva-se até o chão e ergue os braços chamando
    keys = {"body": _up([(5, r(22), p(-0.1, 0.05)), (8, r(20), p(-0.1, 0.05)), (11, r(-16), p(0.08, -0.03)), (14, r(-14, 0, 3), p(0.08, -0.03)),
                         (17, r(-12, 0, -3), p(0.07, -0.03)), (21, r(-3))]),
            "head": _up([(5, r(18)), (11, r(-28)), (17, r(-24)), (21, r(-4))]),
            "arm_r": limb("arm_r", [(5, -55, 15), (8, -50, 20), (11, -150, 45), (14, -155, 50), (17, -150, 45), (21, -40, 15)]),
            "arm_l": limb("arm_l", [(5, -55, 15), (8, -50, 20), (11, -150, 45), (14, -155, 50), (17, -150, 45), (21, -40, 15)]),
            "core": _up([(8, r(5)), (11, r(55)), (17, r(50)), (22, r(5))])}
    keys.update(legs([(5, -4), (11, 16), (17, 14)]))
    _clip(arm, "summon", 24, keys)
    # shout / roar (7) = Prensa: abre os braços de par em par e fecha o abraço (puxa todos)
    press = {"body": _up([(4, r(-14), p(0.06, -0.04)), (7, r(14), p(-0.04, 0.08)), (10, r(12, 0, 3), p(-0.04, 0.08)), (13, r(13, 0, -3), p(-0.04, 0.08)), (16, r(8), p(-0.02, 0.04))]),
             "head": _up([(4, r(-26)), (7, r(10)), (13, r(8))]),
             "arm_r": limb("arm_r", [(4, -60, 115), (7, -95, -25), (10, -90, -30), (13, -92, -25), (17, -40, 5)]),
             "arm_l": limb("arm_l", [(4, -60, 115), (7, -95, -25), (10, -90, -30), (13, -92, -25), (17, -40, 5)]),
             "core": _up([(4, r(60)), (7, r(65)), (13, r(55)), (18, r(10))])}
    press.update(legs([(4, 14), (7, -5), (13, -4), (18, 0)]))
    _clip(arm, "shout", 22, press)
    _clip(arm, "roar", 22, press)
    # brace (6): encolhe atrás dos braços
    keys = {"body": _up([(6, r(14), p(-0.1)), (12, r(13), p(-0.1))]), "head": _up([(6, r(12)), (12, r(12))]),
            "arm_r": limb("arm_r", [(6, -72, -30), (12, -70, -30)]), "arm_l": limb("arm_l", [(6, -72, -30), (12, -70, -30)])}
    keys.update(legs([(6, -5), (12, -5)]))
    _clip(arm, "brace", 18, keys)
    # die: murcha em pé. O tronco cai para a frente, o queixo do tonel despenca (o vinho escorre) e a saia abre no chão
    keys = {"body": _up([(4, r(-10, 0, -4), p(0.04, -0.04)), (10, r(8, 0, 6), p(-0.04)), (16, r(30, 0, 10), p(-0.14, 0.04)), (20, r(40, 0, 12), p(-0.2, 0.06)),
                         (23, r(37, 0, 12), p(-0.19, 0.06)), (26, r(40, 0, 12), p(-0.2, 0.06))]),
            "head": _up([(4, r(-22)), (10, r(10)), (16, r(28, 0, -10)), (20, r(40, 0, -16))]),
            "arm_r": limb("arm_r", [(4, -60, 40), (10, -20, 10), (16, -30, 18), (20, -42, 24)]),
            "arm_l": limb("arm_l", [(4, -60, 40), (10, -20, 10), (16, -34, 18), (20, -48, 24)]),
            "core": _up([(4, r(40)), (10, r(20)), (16, r(75)), (20, r(88))])}
    keys.update(legs([(4, 6), (10, -4), (16, 18), (20, 26), (23, 23), (26, 26)]))
    _clip(arm, "die", 30, keys)


# ---------------------------------------------------------------------------
# Vinha Sedenta (parada)
# ---------------------------------------------------------------------------
VINE_BONES = {               # root/body/head de pé; gavinhas (arm_*) penduradas
    "root": ((0, 0, 0), (0, 0, 0.2), None),
    "body": ((0, 0, 0.22), (0, 0, 0.62), "root"),
    "head": ((0, -0.12, 1.32), (0, -0.12, 1.57), "body"),
    "arm_r": ((0.2, 0, 1.0), (0.2, 0, 0.7), "body"),
    "arm_l": ((-0.2, 0, 1.0), (-0.2, 0, 0.7), "body"),
}


def thirsty_vine(cid="mob_thirsty_vine"):
    arm = mk.lp.make_armature("rig_" + cid, VINE_BONES)
    m = lambda n, col, rough=0.8, em=0.0: ck.mat("m_%s_%s" % (cid, n), col, rough, em)
    bark, bark_d, bark_l = m("bark", BARK, 0.9), m("bark_d", BARK_D, 0.9), m("bark_l", BARK_L, 0.9)
    leaf, leaf_l, leaf_d = m("leaf", LEAF), m("leaf_l", LEAF_L), m("leaf_d", LEAF_D)
    grape = (m("grape", GRAPE, 0.45), m("grape_l", GRAPE_L, 0.45))
    M = {"ink": m("ink", lm.INK, 0.6), "wine": m("wine", WINE, 0.3, 1.6), "tooth": m("tooth", TOOTH, 0.5)}
    P = _Parts()
    # raízes e toco (não se mexem)
    for i in range(5):
        a = math.tau * (i + 0.3) / 5
        dx, dy = math.cos(a), math.sin(a)
        P.add("root", _vine("root%d" % i, [(dx * 0.08, dy * 0.08, 0.3), (dx * 0.3, dy * 0.3, 0.2), (dx * 0.5, dy * 0.5, 0.09), (dx * 0.66, dy * 0.66, 0.065)], 0.12, 0.035, bark_d, 6, 2))
    P.add("root", mk.blob("stump", 1.0, (0, 0, 0.2), bark_d, (0.27, 0.27, 0.2), 2))
    # cepa: duas hastes trançadas que sobem inclinando para a frente
    for k, ph in enumerate((0.0, math.pi)):
        pts = []
        for i in range(10):
            t = i / 9
            a = ph + t * math.tau * 1.3
            rad = 0.1 * (1 - 0.35 * t)
            pts.append((math.cos(a) * rad, -0.12 * t * t + math.sin(a) * rad, 0.16 + t * 1.2))
        P.add("body", _vine("stock%d" % k, pts, 0.16, 0.1, bark if k == 0 else bark_l, 7, 2))
    for k, (zz, a, w) in enumerate(((0.55, 0.6, 0.26), (0.8, 2.6, 0.24), (1.0, 4.4, 0.22), (0.42, 3.7, 0.2))):
        o = V((math.cos(a), math.sin(a), 0))
        P.add("body", _flat(_leaf("stockleaf%d" % k, o * 0.12 + V((0, 0, zz)), o * 0.46 + V((0, 0, zz - 0.12)), w, leaf if k % 2 else leaf_l)))
    P.add("body", mk.blob("knot", 0.1, (0.08, -0.12, 0.72), bark_d, (1, 1, 0.8), 1))
    # cabeça: pescoço que arqueia para a frente, gola de folhas roxas (o que a câmera alta vê) e o cacho-boca
    nk = [(0, -0.12, 1.3), (0, -0.2, 1.52), (0, -0.36, 1.66), (0, -0.52, 1.62)]
    P.add("head", _vine("neck", nk, 0.11, 0.07, bark_l, 7))
    top = V((0, -0.52, 1.6))
    for i in range(6):
        a = math.tau * (i + 0.5) / 6
        o = V((math.cos(a), math.sin(a), 0))
        P.add("head", _flat(_leaf("crown%d" % i, top + o * 0.05 + V((0, 0, 0.05)), top + o * 0.52 + V((0, 0, -0.1 - 0.08 * abs(math.sin(a)))), 0.36, leaf if i % 2 else leaf_l)))
    P.add("head", _grapes("cluster", top + V((0, 0, 0.02)), 0.66, 0.27, grape, 5))
    P.add("head", _maw("maw", top + V((0, -0.225, -0.27)), 0.36, 0.2, M))
    pts = [top + V((0.1 + 0.02 * i + 0.06 * math.sin(i * 1.4), 0.1 + 0.06 * math.cos(i * 1.4), 0.1 + 0.05 * i)) for i in range(7)]
    P.add("head", _vine("curl", pts, 0.03, 0.01, bark_d, 5, 2))
    # gavinhas: sobem, abrem e pendem com um cacho-boca menor na ponta
    for bone, sx in (("arm_r", 1), ("arm_l", -1)):
        tp = [(sx * 0.2, 0, 1.0), (sx * 0.45, -0.04, 1.3), (sx * 0.72, -0.14, 1.36), (sx * 0.86, -0.26, 1.2)]
        P.add(bone, _vine("tendril%d" % sx, tp, 0.085, 0.05, bark if sx > 0 else bark_l, 6))
        ct = V((sx * 0.86, -0.27, 1.2))
        P.add(bone, _grapes("clus%d" % sx, ct, 0.46, 0.18, grape, 30 + sx))
        P.add(bone, _maw("maw%d" % sx, ct + V((sx * 0.02, -0.155, -0.19)), 0.25, 0.14, M, (sx * 0.2, -1, 0), 3))
        for k, d in enumerate(((sx * 0.3, 0.1, -0.04), (sx * 0.1, -0.3, -0.06), (-sx * 0.22, 0.14, -0.04))):
            P.add(bone, _flat(_leaf("tleaf%d_%d" % (sx, k), ct + V((0, 0, 0.02)), ct + V(d), 0.22, leaf_l if k % 2 else leaf)))
    P.finish(arm, cid)

    s, c = math.sin, math.cos
    keys = {"body": _loop(48, 4, lambda ph: (r(2.5 * s(ph), 0, 3 * s(ph + 0.7)), Z0)),
            "head": _loop(48, 4, lambda ph: (r(5 * s(ph + 0.9), 8 * s(ph + 1.5), 0), Z0)),
            "arm_r": _loop(48, 4, lambda ph: ((-6 * s(ph + 1.0), 0, -4 * s(ph + 0.3)), Z0)),
            "arm_l": _loop(48, 4, lambda ph: ((-6 * s(ph + 2.2), 0, 4 * s(ph + 1.5)), Z0))}
    _clip(arm, "idle", 48, keys, loop=True)
    keys = {"body": _loop(16, 1, lambda ph: (r(4 + 3 * s(2 * ph), 6 * s(ph), 5 * c(ph)), Z0)),
            "head": _loop(16, 1, lambda ph: (r(6 * c(ph), -8 * s(ph), 0), Z0)),
            "arm_r": _loop(16, 1, lambda ph: ((-16 * c(ph), 0, -6), Z0)),
            "arm_l": _loop(16, 1, lambda ph: ((16 * c(ph), 0, 6), Z0))}
    _clip(arm, "run", 16, keys, loop=True)
    # attack (5): recolhe e dá o bote com o cacho-boca
    _clip(arm, "attack", 16, {
        "body": _up([(3, r(-16), Z0), (5, r(26), Z0), (7, r(22, 0, 3), Z0), (11, r(8), Z0)]),
        "head": _up([(3, r(-24)), (5, r(30)), (7, r(24)), (11, r(8))]),
        "arm_r": limb("arm_r", [(3, 20, 25), (5, -50, 10), (8, -40, 8), (12, -10)]),
        "arm_l": limb("arm_l", [(3, 20, 25), (5, -50, 10), (8, -40, 8), (12, -10)])})
    # atk_sweep (8) = Cepa Faminta: as duas gavinhas abrem, lançam-se para a frente e puxam de volta
    _clip(arm, "atk_sweep", 20, {
        "body": _up([(4, r(-12), Z0), (8, r(22), Z0), (10, r(20), Z0), (13, r(-6), Z0), (17, r(-2), Z0)]),
        "head": _up([(4, r(-18)), (8, r(16)), (13, r(-12)), (17, r(-4))]),
        "arm_r": limb("arm_r", [(4, 25, 60), (8, -105, -5), (10, -100, -8), (13, -40, 10), (17, -8)]),
        "arm_l": limb("arm_l", [(4, 25, 60), (8, -105, -5), (10, -100, -8), (13, -40, 10), (17, -8)])})
    # cast (10): empina, abre as gavinhas e desce
    _clip(arm, "cast", 20, {
        "body": _up([(4, r(6), Z0), (8, r(-18), Z0), (10, r(16), Z0), (13, r(13), Z0), (17, r(4), Z0)]),
        "head": _up([(8, r(-32)), (10, r(18)), (14, r(10))]),
        "arm_r": limb("arm_r", [(4, -20, 15), (8, -120, 55), (10, -70, 15), (13, -62, 15), (17, -15)]),
        "arm_l": limb("arm_l", [(4, -20, 15), (8, -120, 55), (10, -70, 15), (13, -62, 15), (17, -15)])})
    _clip(arm, "hit", 10, {
        "body": _up([(2, r(-16, 0, 8), Z0), (5, r(6, 0, -4), Z0)]), "head": _up([(2, r(-24, 0, 12)), (5, r(8, 0, -6))]),
        "arm_r": limb("arm_r", [(2, -30, 25), (5, 8)]), "arm_l": limb("arm_l", [(2, -30, 25), (5, 8)])})
    # die: estremece e murcha, o cacho-boca pende
    _clip(arm, "die", 26, {
        "body": _up([(3, r(-14, 0, -6), Z0), (8, r(10, 0, 8), Z0), (14, r(34, 0, 14), Z0), (18, r(46, 0, 18), Z0), (21, r(43, 0, 18), Z0), (24, r(46, 0, 18), Z0)]),
        "head": _up([(3, r(-26)), (8, r(14)), (14, r(34, 0, -10)), (18, r(44, 0, -14))]),
        "arm_r": limb("arm_r", [(3, -60, 40), (8, -10, 10), (14, -20, -10), (18, -28, -16)]),
        "arm_l": limb("arm_l", [(3, -60, 40), (8, -10, 10), (14, -24, -10), (18, -34, -16)])})
    return arm


# ---------------------------------------------------------------------------
# humanoides (corpo do kit, como as Veladas)
# ---------------------------------------------------------------------------
def _feast_base(cid, cfg):
    ck.BODIES["feast"] = lm._body(cfg)
    base = ck.build_base(cid, "feast", 0.0)
    m = lambda n, col, rough=0.7, em=0.0: ck.mat("m_%s_%s" % (cid, n), col, rough, em)
    M = {"body": m("porc", lm.PORC, 0.4), "porc": m("mask", lm.MASK, 0.3), "gold": m("gold", lm.OLD_GOLD, 0.4), "gold2": m("gold2", lm.BRIGHT_GOLD, 0.35),
         "ink": m("ink", lm.INK, 0.6), "glow": m("tear", cfg["tear"], 0.3, 2.2)}
    for o in list(bpy.context.scene.objects):          # boneca lisa: sem olhos nem cabelo, tudo porcelana
        if o.name.startswith((cid + "_head_", cid + "_hair")):
            bpy.data.objects.remove(o, do_unlink=True)
        elif o.type == "MESH" and o.name in (cid + "_body", cid + "_head"):
            o.data.materials[0] = M["body"]
    return base, M, m


def _stretched(fn, cid, cfg):
    saved = lm._stretch(cfg["leg"], cfg["torso"])
    try:
        return fn(cid, cfg)
    finally:
        ck.Z.clear()
        ck.Z.update(saved)


def _open_cap(name, r_, hc, c, material, cut):
    """Touca/capuz/peruca: esfera maior que a cabeça, recuada e aberta na frente (o rosto todo de fora)."""
    cap = ck.ball(name, r_, hc, material)
    bm_ = bmesh.new()
    bm_.from_mesh(cap.data)
    bmesh.ops.delete(bm_, geom=[f for f in bm_.faces if f.calc_center_median().y < c.y - cut], context="FACES")
    bm_.to_mesh(cap.data)
    bm_.free()
    return cap


CHORISTER = {"leg": 0.08, "torso": 0.03, "head": 0.27, "tear": lm.ROSE_TEAR}
CHORISTER_CLIPS = ("cast_ground", "cast_target", "cast_channel", "cast_shadow", "shout")
PRIMA = {"leg": 0.22, "torso": 0.06, "arm": 1.3, "head": 0.27, "tear": lm.ROSE_TEAR}
PRIMA_CAGE_R = 0.6                 # raio da barra da gaiola (m no modelo)
PRIMA_CARRY = {"upper_arm.R": (-18, 0, 12), "forearm.R": (-58, 0, 0)}      # leque erguido à frente do corpete (só idle/run)


def chorister(cid="mob_chorister"):
    return _stretched(_chorister, cid, CHORISTER)


def _chorister(cid, cfg):
    base, M, m = _feast_base(cid, cfg)
    rig, b, j = base["rig"], base["b"], base["j"]
    Z = ck.Z
    robe, deep, pale = m("robe", ROBE, 0.85), m("robe_d", ROBE_D, 0.85), m("robe_l", ROBE_L, 0.8)
    thread, note = m("thread", VELVET, 0.7), m("note", NOTE, 0.3, 2.0)
    gold, gold2, ink = M["gold"], M["gold2"], M["ink"]
    c, r_ = V(base["head_c"]), b["head"]
    zc, zw, zn, zp, zu = Z["chest"], Z["waist"], Z["neck"], Z["pelvis"], Z["upper"]
    back = b["chest"] * b["depth"]
    front = -back
    head, chest, hips, skinned = [], [], [], []
    arms = {".R": [], ".L": []}

    # ---------------- cabeça: máscara de boca costurada, capuz de ponta caída, fitas ----------------
    s_ = r_ * 0.74
    mc = c + V((0, -r_ * 0.76, -r_ * 0.1))
    head += lk.mask(ck, cid + "_mask", mc, s_, M, tears=(1,), tear_len=0.5)
    zm = -0.5 * s_
    surf = lambda x: -0.34 * s_ * math.sqrt(max(0.0, 1.0 - (x / (0.82 * s_)) ** 2 - (zm / s_) ** 2))
    head.append(ck.tube(cid + "_mouth", mc + V((-0.34 * s_, surf(0.34 * s_) - 0.006, zm)), mc + V((0.34 * s_, surf(0.34 * s_) - 0.006, zm)), 0.009, 0.009, ink, 5))
    for i in range(-2, 3):           # pontos da costura (em X alternado)
        x = i * 0.14 * s_
        d = 0.045 * s_ * (1 if i % 2 else -1)
        head.append(ck.tube("%s_stitch%d" % (cid, i), mc + V((x - d, surf(x) - 0.014, zm + 0.11 * s_)), mc + V((x + d, surf(x) - 0.014, zm - 0.11 * s_)), 0.0095, 0.0095, thread, 4))
    hc = c + V((0, r_ * 0.28, r_ * 0.1))
    head.append(_open_cap(cid + "_hood", r_ * 1.13, hc, c, robe, r_ * 0.05))
    head += bs._tusk(ck, cid + "_hood_peak", hc + V((0, r_ * 0.05, r_ * 0.5)), hc + V((0, r_ * 1.75, r_ * 0.95)), V((0, 0, r_ * 0.5)), r_ * 0.84, robe, 5, 8)
    head.append(lm._ring(cid + "_hood_trim", c.z + r_ * 0.4, c.z + r_ * 0.5, r_ * 0.97, r_ * 0.94, gold, 1.0, 14, c.y - r_ * 0.02))
    head += lm._bow(cid + "_hood_bow", hc + V((0, r_ * 1.02, -r_ * 0.35)), (0, 1, 0), r_ * 0.5, pale, gold2, pale)
    for sx in (-1, 1):
        head.append(lm._veil("%s_ribbon%d" % (cid, sx), hc + V((sx * r_ * 0.2, r_ * 1.05, -r_ * 0.45)), V((sx * 0.2, back + 0.3, Z["knee"] + 0.16)),
                             r_ * 0.36, r_ * 0.3, pale, (sx * 0.04, 0.08, 0), 4, 0.5))

    # ---------------- tronco: túnica, capinha aberta na frente e a garganta de tubos de órgão ----------------
    chest.append(lm._ring(cid + "_robe_top", zw - 0.03, zu + 0.01, b["waist"] * 1.3, b["upper"] * 1.16, robe))
    chest.append(lm._skirt(cid + "_capelet", zu + 0.075, zc + 0.015, b["neck"] * 1.5, b["shoulder"] + 0.09, deep, 12, 0.04, 0.62, 0.8, 2))
    chest.append(lm._ring(cid + "_collar", zn - 0.035, zn + 0.02, b["neck"] * 1.9, b["neck"] * 1.45, gold, 0.9))
    yp = front - 0.05
    z0p = zc - 0.07
    chest.append(ck.box(cid + "_pipe_back", (0.36, 0.03, zu + 0.05 - z0p), (0, front - 0.012, (zu + 0.05 + z0p) * 0.5), ink, 0.008))
    chest.append(ck.box(cid + "_pipe_chest", (0.39, 0.095, 0.055), (0, yp + 0.005, z0p), gold, 0.012))
    for i in range(-3, 4):
        x = i * 0.05
        z1 = zu + 0.05 + 0.05 * abs(i)
        chest.append(ck.tube("%s_pipe%d" % (cid, i), (x, yp, z0p), (x, yp - 0.006 * abs(i), z1), 0.026, 0.024, gold2 if i % 2 == 0 else gold, 6))
        chest.append(ck.ball("%s_pipe_top%d" % (cid, i), 0.022, (x, yp - 0.006 * abs(i), z1 + 0.002), note, (1.0, 1.0, 0.55)))
        chest.append(ck.ball("%s_pipe_lip%d" % (cid, i), 0.013, (x, yp - 0.02, z0p + 0.075), ink, (1.2, 0.6, 0.7)))
    zb = zp + 0.07
    rb = b["pelvis"] * 1.1
    hips.append(lm._ring(cid + "_belt", zb - 0.02, zb + 0.025, rb * 1.12, rb * 1.07, gold))
    hips.append(ck.ball(cid + "_beltgem", 0.03, V((0, -rb * 0.95, zb - 0.03)), M["glow"], (0.8, 0.6, 1.5)))
    skinned.append(lm._skirt(cid + "_robe", zw - 0.01, Z["ankle"] + 0.05, b["waist"] * 1.25, rb * 1.8, robe, 16, 0.03))
    skinned.append(lm._skirt(cid + "_robe_out", zb + 0.01, Z["knee"] + 0.03, rb * 1.1, rb * 1.72, deep, 16, 0.08, 0.5))
    for s, sx in ((".R", -1), (".L", 1)):              # mangas-sino com punho de ouro
        wr, el = V(j["wrist" + s]), V(j["elbow" + s])
        arms[s].append(ck.tube("%s_sleeve%s" % (cid, s[1]), el.lerp(wr, 0.05), wr + V((0, 0, -0.01)), b["elbow"] * 1.5, b["wrist"] * 2.9, robe, 10))
        arms[s].append(ck.tube("%s_cuff%s" % (cid, s[1]), wr + V((0, 0, 0.012)), wr + V((0, 0, -0.016)), b["wrist"] * 3.0, b["wrist"] * 3.0, gold, 10))
        arms[s].append(lm._veil("%s_drape%s" % (cid, s[1]), wr + V((sx * 0.03, 0.05, 0.0)), wr + V((sx * 0.07, 0.13, -0.3)), 0.12, 0.17, deep, (sx * 0.02, 0.03, 0), 3, 0.25))

    ck._rigid(bs._outward(head), rig, "head")
    ck._rigid(bs._outward(chest), rig, "chest")
    ck._rigid(bs._outward(hips), rig, "hips")
    for s in (".R", ".L"):
        ck._rigid(bs._outward(arms[s]), rig, "forearm" + s)
    lk.skinned(ck, base, bs._outward(skinned))

    ck.mob_clips(rig, None, None, "shout", extra_keep=CHORISTER_CLIPS)
    lm._hips_scale(rig, Z["pelvis"] / 0.38)
    act2_bosses.clear_ground(rig, {"die": -0.02}, "head", (cid + "_hood_peak",))
    lm._join(cid, rig, cid + "_body")
    return rig


def prima_donna(cid="mob_prima_donna"):
    return _stretched(_prima_donna, cid, PRIMA)


def _bird(name, pos, facing, s, M, wing):
    """Pássaro de porcelana (meia-altura ~s) pousado em pos, olhando para facing: bico e cauda de ouro, olho de tinta e a lágrima."""
    objs = [ck.ball(name + "_body", 1.0, (0, 0, s * 0.62), M["porc"], (s * 0.62, s * 0.95, s * 0.66)),
            ck.ball(name + "_head", s * 0.46, (0, -s * 0.62, s * 1.22), M["porc"]),
            mk.cone(name + "_beak", (0, -s * 0.98, s * 1.22), (0, -s * 1.5, s * 1.14), s * 0.15, M["gold2"], 5),
            ck.blade(name + "_tail", (0, s * 0.7, s * 0.66), (0, s * 1.9, s * 0.36), s * 0.62, s * 0.1, M["gold"], (1, 0, 0), 0.35),
            ck.ball(name + "_breast", 1.0, (0, -s * 0.5, s * 0.5), wing, (s * 0.4, s * 0.4, s * 0.36))]
    for sx in (-1, 1):
        objs += [ck.blade("%s_wing%d" % (name, sx), (sx * s * 0.52, -s * 0.36, s * 0.86), (sx * s * 0.74, s * 1.1, s * 0.58), s * 0.7, s * 0.12, wing, (0, 0.25, 1), 0.4),
                 ck.ball("%s_eye%d" % (name, sx), s * 0.1, (sx * s * 0.36, -s * 0.84, s * 1.3), M["ink"]),
                 ck.ball("%s_tear%d" % (name, sx), s * 0.075, (sx * s * 0.4, -s * 0.84, s * 1.12), M["glow"], (0.7, 0.7, 1.7))]
    return lk.place(objs, pos, facing)


def _prima_donna(cid, cfg):
    base, M, m = _feast_base(cid, cfg)
    rig, b, j = base["rig"], base["b"], base["j"]
    Z = ck.Z
    velvet, velvet_d, cream, rose = m("velvet", VELVET, 0.85), m("velvet_d", VELVET_D, 0.85), m("cream", CREAM, 0.6), m("rose", ROSE, 0.8)
    wig = m("wig", WIG, 0.7)
    gold, gold2, ink, glow = M["gold"], M["gold2"], M["ink"], M["glow"]
    lm._add_tail_bone(rig)
    c, r_ = V(base["head_c"]), b["head"]
    zc, zw, zn, zp, zu = Z["chest"], Z["waist"], Z["neck"], Z["pelvis"], Z["upper"]
    sw = b["chest"]
    back = sw * b["depth"]
    front = -back
    head, chest, hips, skinned, cage = [], [], [], [], []
    arms = {".R": [], ".L": []}
    hands = {".R": [], ".L": []}
    shins = {".R": [], ".L": []}

    # ---------------- cabeça: máscara de boca aberta, peruca alta de porcelana, pássaro no topo ----------------
    s_ = r_ * 0.74
    mc = c + V((0, -r_ * 0.76, -r_ * 0.1))
    head += lk.mask(ck, cid + "_mask", mc, s_, M, tears=(1,), tear_len=0.7)
    head.append(ck.ball(cid + "_mouth", 1.0, mc + V((0, -0.29 * s_, -0.52 * s_)), ink, (0.15 * s_, 0.06 * s_, 0.2 * s_)))
    hc = c + V((0, r_ * 0.26, r_ * 0.1))
    head.append(_open_cap(cid + "_wig", r_ * 1.13, hc, c, wig, r_ * 0.05))
    head.append(ck.ball(cid + "_wig_roll", 1.0, c + V((0, -r_ * 0.42, r_ * 0.98)), wig, (r_ * 0.86, r_ * 0.4, r_ * 0.36)))
    tiers = ((0.92, 0.82, 0.0), (1.56, 0.6, -0.04), (2.04, 0.4, -0.08))
    for k, (dz, rr, dy) in enumerate(tiers):
        head.append(ck.ball("%s_wig_tier%d" % (cid, k), r_ * rr, hc + V((0, r_ * dy, r_ * dz)), wig, (1.0, 0.92, 0.9)))
    head.append(lm._ring(cid + "_wig_band", hc.z + r_ * 1.2, hc.z + r_ * 1.32, r_ * 0.62, r_ * 0.56, gold2, 1.0, 12, hc.y - r_ * 0.02))
    head += lm._bow(cid + "_wig_bow", hc + V((0, -r_ * 0.64, r_ * 1.3)), (0, -1, 0), r_ * 0.62, velvet, gold2, velvet)
    for sx in (-1, 1):                # cachos de lado e um cacho comprido até o ombro
        head.append(ck.ball("%s_wig_curl%d" % (cid, sx), r_ * 0.42, c + V((sx * r_ * 1.02, r_ * 0.2, -r_ * 0.1)), wig))
        head += bs._tusk(ck, "%s_wig_lock%d" % (cid, sx), c + V((sx * r_ * 1.0, r_ * 0.3, -r_ * 0.3)), c + V((sx * r_ * 0.96, r_ * 0.36, -r_ * 1.5)),
                         V((sx * r_ * 0.14, 0, 0)), r_ * 0.26, wig, 4, 7)
        head.append(lm._veil("%s_wig_ribbon%d" % (cid, sx), hc + V((sx * r_ * 0.3, r_ * 1.0, r_ * 0.2)), V((sx * 0.3, back + 0.34, zw + 0.05)), r_ * 0.4, r_ * 0.3, rose,
                             (sx * 0.04, 0.09, 0), 4, 0.5))
    top = hc + V((0, r_ * tiers[2][2], r_ * (tiers[2][0] + tiers[2][1] * 0.82)))
    head += _bird(cid + "_topbird", top, (0.25, -1, 0), 0.09, M, velvet)

    # ---------------- tronco: corpete de veludo, gola creme, mangas bufantes, luvas compridas ----------------
    chest.append(lm._ring(cid + "_bodice", zw - 0.03, zu + 0.005, b["waist"] * 1.18, b["upper"] * 1.14, velvet))
    chest.append(lm._ring(cid + "_neckline", zu - 0.012, zu + 0.03, b["upper"] * 1.17, b["upper"] * 1.1, cream))
    chest.append(lm._ring(cid + "_ruff", zn - 0.03, zn + 0.075, b["neck"] * 1.5, b["neck"] * 2.7, cream, 0.9))
    chest.append(lm._ring(cid + "_collar", zn - 0.04, zn - 0.005, b["neck"] * 2.0, b["neck"] * 1.6, gold, 0.9))
    for k in range(3):                # laços do corpete (creme sobre o vinho)
        chest.append(ck.ball("%s_lace%d" % (cid, k), 1.0, V((0, front - 0.022, zc - 0.05 + k * 0.05)), cream, (0.055, 0.02, 0.014)))
    chest.append(ck.blade(cid + "_brooch", V((0, front - 0.03, zu + 0.03)), V((0, front - 0.035, zu - 0.07)), 0.09, 0.02, gold2, (1, 0, 0), 0.4))
    for s, sx in ((".R", -1), (".L", 1)):
        chest.append(ck.ball("%s_puff%s" % (cid, s[1]), 0.105, V((sx * (b["shoulder"] + 0.02), 0.0, zu + 0.01)), velvet, (1.05, 1.0, 0.9)))
        chest.append(ck.ball("%s_puff_bow%s" % (cid, s[1]), 0.04, V((sx * (b["shoulder"] + 0.085), -0.02, zu + 0.05)), rose))
        wr, el = V(j["wrist" + s]), V(j["elbow" + s])
        arms[s].append(ck.tube("%s_glove%s" % (cid, s[1]), el.lerp(wr, -0.12), wr.lerp(el, -0.03), b["elbow"] * 1.22, b["wrist"] * 1.28, cream, 8))
        arms[s].append(ck.tube("%s_bracelet%s" % (cid, s[1]), wr.lerp(el, 0.2), wr.lerp(el, 0.04), b["wrist"] * 1.5, b["wrist"] * 1.62, gold, 8))
        hands[s].append(ck.ball("%s_fist%s" % (cid, s[1]), b["hand"] * 1.12, V(ck.hand_center(base, s)), cream, (1, 1, 1.1)))
        an = V(j["ankle" + s])
        shins[s].append(ck.tube("%s_anklet%s" % (cid, s[1]), an + V((0, 0, 0.035)), an + V((0, 0, 0.065)), b["ankle"] * 1.5, b["ankle"] * 1.4, gold, 8))
    zb = zp + 0.07
    rb = b["pelvis"] * 1.1
    hips.append(lm._ring(cid + "_belt", zb - 0.02, zb + 0.03, rb * 1.06, rb * 1.0, gold))
    hips.append(ck.ball(cid + "_beltgem", 0.034, V((0, -rb * 0.9, zb - 0.03)), glow, (0.8, 0.6, 1.5)))
    skinned.append(lm._skirt(cid + "_under", zb, Z["ankle"] + 0.1, rb, rb * 1.5, velvet_d, 14, 0.04))
    skinned.append(lm._skirt(cid + "_peplum", zb + 0.012, zb - 0.16, rb * 1.1, rb * 1.9, rose, 16, 0.07))

    # ---------------- vestido-gaiola: barras e aros de ouro do cinto ao chão, pássaros nos aros ----------------
    R, r_top, z_top, z_hem = PRIMA_CAGE_R, rb * 1.12, zb - 0.03, 0.045
    prof = lambda t: (r_top + (R - r_top) * math.sin(t * math.pi * 0.5) ** 0.75, z_top + (z_hem - z_top) * t)
    nb = 12
    for i in range(nb):
        a = math.tau * (i + 0.5) / nb
        pts = []
        for k in range(8):
            rr, zz = prof(k / 7)
            pts.append((math.cos(a) * rr, math.sin(a) * rr, zz))
        cage.append(_sweep("%s_cage_bar%d" % (cid, i), pts, [0.017] * 8, gold2, 5))
    hoops = (0.34, 0.66, 1.0)
    for k, t in enumerate(hoops):
        rr, zz = prof(t)
        cage.append(_hoop("%s_cage_hoop%d" % (cid, k), (0, 0, zz), rr, 0.03 if t == 1.0 else 0.02, gold, 24))
    cage.append(_hoop(cid + "_cage_top", (0, 0, z_top), r_top, 0.022, gold, 16))
    for k, (t, ang, s_b, wing) in enumerate(((0.66, -90, 0.11, rose), (0.66, 35, 0.1, velvet), (0.66, 150, 0.1, rose), (0.34, -25, 0.09, velvet), (0.34, 205, 0.09, rose),
                                              (0.34, 95, 0.09, velvet))):
        rr, zz = prof(t)
        a = math.radians(ang)
        o = V((math.cos(a), math.sin(a), 0))
        cage += _bird("%s_cage_bird%d" % (cid, k), o * (rr - s_b * 1.15) + V((0, 0, zz + 0.012)), o, s_b, M, wing)
    for sx in (-1, 1):                # laços onde a gaiola prende no cinto
        hips += lm._bow("%s_cage_bow%d" % (cid, sx), V((sx * rb * 1.0, -rb * 0.45, zb - 0.01)), (sx, -0.5, 0), 0.13, rose, gold2, rose)

    # ---------------- leque (mão direita) ----------------
    g = V(ck.hand_center(base, ".R"))
    h0, h1 = g + V((0, 0.05, 0.0)), g + V((0, -0.06, 0.0))
    fwd, u = V((0, -1, 0)), V((0.34, 0, 0.94)).normalized()
    nrm = fwd.cross(u)
    hands[".R"] += [ck.tube(cid + "_fan_grip", h0, h1, 0.02, 0.018, gold, 6), ck.ball(cid + "_fan_rivet", 0.034, h1, gold2)]
    for i in range(7):
        a = math.radians(-52 + i * 112 / 6)
        d = fwd * math.cos(a) + u * math.sin(a)
        hands[".R"].append(ck.blade("%s_fan_leaf%d" % (cid, i), h1 + nrm * (i - 3) * 0.004, h1 + d * 0.36 + nrm * (i - 3) * 0.004, 0.125, 0.012,
                                    rose if i % 2 == 0 else cream, d.cross(nrm), 0.72))
        hands[".R"].append(ck.tube("%s_fan_rib%d" % (cid, i), h1 + nrm * ((i - 3) * 0.004 + 0.008), h1 + d * 0.38 + nrm * ((i - 3) * 0.004 + 0.008), 0.008, 0.006, gold2, 4))

    ck._rigid(bs._outward(head), rig, "head")
    ck._rigid(bs._outward(chest), rig, "chest")
    ck._rigid(bs._outward(hips), rig, "hips")
    for s in (".R", ".L"):
        ck._rigid(bs._outward(arms[s]), rig, "forearm" + s)
        ck._rigid(bs._outward(hands[s]), rig, "hand" + s)
        ck._rigid(bs._outward(shins[s]), rig, "shin" + s)
    lk.skinned(ck, base, bs._outward(skinned))
    for o in bs._outward(cage):
        lm._skin_grad(o, rig, 0.1, z_top - 0.02)

    ck.mob_clips(rig, None, None, "atk_1h_a", extra_keep=ck.MOB_BOSS_KEEP + ("jump", "dash"))
    lm._hips_scale(rig, Z["pelvis"] / 0.38)
    act2_bosses.carry(rig, PRIMA_CARRY)
    act2_bosses.clear_ground(rig, {"*": 0.03, "die": -0.1}, "hand.R", (cid + "_fan",), front=True)
    lm._tail_anim(rig)
    lm._join(cid, rig, cid + "_body")
    return rig


ONE = (1, 1, 1)
NIL = (0.001, 0.001, 0.001)
SKIN = (0.92, 0.66, 0.58)           # Varo: pele corada de vinho
CAPE = (0.66, 0.13, 0.27)           # capa do Varo: vinho mais vivo que o casaco
WIG_C = (0.95, 0.91, 0.83)          # peruca empoada creme
BOTTLE = (0.13, 0.2, 0.16)          # vidro do garrafão (verde-garrafa escuro: separa do veludo)
VAPOR = (0.95, 0.7, 0.9)            # vapor perfumado do Eco
VAPOR_L = (1.0, 0.88, 0.97)
SENSE_GLOW = {"": lm.ROSE_TEAR, "sight": (0.75, 0.88, 1.0), "hearing": NOTE, "smell": (0.72, 0.5, 0.95), "taste": WINE}


def _base(cid, cfg):
    """_feast_base com corpo próprio (cfg["body"]): Varo é o único gordo da família."""
    ck.BODIES["feast"] = cfg.get("body") or lm._body(cfg)
    base = ck.build_base(cid, "feast", 0.0)
    m = lambda n, col, rough=0.7, em=0.0: ck.mat("m_%s_%s" % (cid, n), col, rough, em)
    M = {"body": m("porc", lm.PORC, 0.4), "porc": m("mask", lm.MASK, 0.3), "gold": m("gold", lm.OLD_GOLD, 0.4), "gold2": m("gold2", lm.BRIGHT_GOLD, 0.35),
         "ink": m("ink", lm.INK, 0.6), "glow": m("tear", cfg["tear"], 0.3, 2.2)}
    for o in list(bpy.context.scene.objects):
        if o.name.startswith((cid + "_head_", cid + "_hair")):
            bpy.data.objects.remove(o, do_unlink=True)
        elif o.type == "MESH" and o.name in (cid + "_body", cid + "_head"):
            o.data.materials[0] = M["body"]
    return base, M, m


def _sclip(arm, name, end, keys, loop=False):
    """Clipe de peças rígidas com ESCALA: todo osso ganha chave (rot, loc, escala) em todo clipe (o Godot não herda)."""
    full = {}
    for b in arm.data.bones:
        ks = [k if len(k) > 3 else tuple(k) + (ONE,) for k in (keys.get(b.name) or [])]
        if not ks:
            ks = [(1, Z0, Z0, ONE), (end, Z0, Z0, ONE)]
        else:
            if ks[0][0] > 1:
                ks.insert(0, (1, Z0, Z0, ONE))
            if ks[-1][0] < end:
                ks.append((end,) + tuple(ks[-1][1:]) if name == "die" else (end, Z0, Z0, ONE))
        full[b.name] = ks
    mk.lp.add_action(arm, name, full, end, loop=loop)


def _sc(seq):
    """[(quadro, escala)] -> chaves de escala uniforme de um osso parado."""
    return [(f, Z0, Z0, (s, s, s)) for f, s in seq]


# ---------------------------------------------------------------------------
# Varo Taça-Cheia, o Anfitrião (dg_cellars, 47)
# ---------------------------------------------------------------------------
VARO = {"leg": 0.0, "torso": 0.04, "tear": WINE,
        "body": dict(shoulder=0.285, hip=0.115, pelvis=0.27, waist=0.3, chest=0.27, upper=0.21, arm=0.078, elbow=0.068, wrist=0.054, hand=0.062,
                     thigh=0.115, knee=0.082, ankle=0.066, toe=0.078, neck=0.08, depth=0.95, head=0.31, arm_len=1.08)}
VARO_CARRY = {"upper_arm.R": (22, 0, 0), "forearm.R": (14, 0, 0)}      # garrafão mais baixo: não tapa a máscara (só idle/run)
VARO_FEAST_IMPACT = 14              # = EntityView.IMPACT_FRAME["cast_channel"]: a taça chega à boca


def varo(cid="mob_varo"):
    return _stretched(_varo, cid, VARO)


def _varo(cid, cfg):
    base, M, m = _base(cid, cfg)
    rig, b, j = base["rig"], base["b"], base["j"]
    Z = ck.Z
    coat, coat_d, cape_m, cream = m("velvet", VELVET, 0.85), m("velvet_d", VELVET_D, 0.85), m("cape", CAPE, 0.85), m("cream", CREAM, 0.6)
    skin, wig, glass, leaf = m("skin", SKIN, 0.7), m("wig", WIG_C, 0.7), m("bottle", BOTTLE, 0.25), m("leaf", LEAF_L, 0.8)
    grape = (m("grape", GRAPE, 0.45), m("grape_l", GRAPE_L, 0.45))
    gold, gold2, ink = M["gold"], M["gold2"], M["ink"]
    bpy.data.objects[cid + "_body"].data.materials[0] = coat
    for o in bpy.context.scene.objects:
        if o.name == cid + "_head":
            o.data.materials[0] = skin
    c, r_ = V(base["head_c"]), b["head"]
    zc, zw, zn, zp, zu = Z["chest"], Z["waist"], Z["neck"], Z["pelvis"], Z["upper"]
    front = -b["upper"] * b["depth"]
    head, chest, spine, hips, skinned = [], [], [], [], []
    arms = {".R": [], ".L": []}
    hands = {".R": [], ".L": []}

    # ---------------- cabeça: máscara com a lágrima de vinho, papada, peruca creme de rolos, cacho de uvas de lado ----------------
    s_ = r_ * 0.7
    mc = c + V((0, -r_ * 0.78, -r_ * 0.04))
    head += lk.mask(ck, cid + "_mask", mc, s_, M, tears=(1,), tear_len=0.6)
    head.append(ck.ball(cid + "_grin", 1.0, mc + V((0, -0.3 * s_, -0.52 * s_)), ink, (0.3 * s_, 0.06 * s_, 0.085 * s_)))
    head.append(ck.ball(cid + "_jowl", 1.0, c + V((0, -r_ * 0.46, -r_ * 0.84)), skin, (r_ * 0.74, r_ * 0.52, r_ * 0.3)))
    hc = c + V((0, r_ * 0.24, r_ * 0.1))
    head.append(_open_cap(cid + "_wig", r_ * 1.1, hc, c, wig, r_ * 0.05))
    for sx in (-1, 1):
        for k in range(3):
            head.append(ck.ball("%s_wig_roll%d_%d" % (cid, sx, k), r_ * (0.34 - 0.04 * k), c + V((sx * r_ * (1.02 + 0.02 * k), r_ * 0.12, r_ * (0.3 - 0.4 * k))),
                                wig, (1.0, 1.3, 0.8)))
    head += lm._bow(cid + "_wig_bow", hc + V((0, r_ * 1.05, -r_ * 0.5)), (0, 1, 0), r_ * 0.55, cape_m, gold2, cape_m)
    head.append(ck.ball(cid + "_wig_tail", 1.0, hc + V((0, r_ * 1.02, -r_ * 0.98)), wig, (r_ * 0.22, r_ * 0.2, r_ * 0.4)))
    gt = hc + V((r_ * 0.25, -r_ * 0.1, r_ * 1.14))
    head += _grapes(cid + "_hat_grapes", gt, r_ * 0.95, r_ * 0.42, grape, 4, (0.8, 0.15, -0.5))
    for k, (dx, dy) in enumerate(((-0.95, -0.25), (-0.5, 0.75), (0.0, -0.95))):
        head.append(_leaf("%s_hat_leaf%d" % (cid, k), gt, gt + V((dx * r_ * 0.8, dy * r_ * 0.8, r_ * 0.06)), r_ * 0.6, leaf))

    # ---------------- tronco: barriga de colete, guardanapo no pescoço, gola de pele, capa ----------------
    bc, br = V((0, -0.17, zw + 0.045)), (0.335, 0.3, 0.275)
    spine.append(ck.ball(cid + "_belly", 1.0, bc, coat_d, br))
    for k, dz in enumerate((0.0, -0.1, -0.19)):
        y = bc.y - br[1] * math.sqrt(1.0 - (dz / br[2]) ** 2)
        spine.append(ck.ball("%s_button%d" % (cid, k), 0.028, V((0, y - 0.004, bc.z + dz)), gold2, (1, 0.6, 1)))
    chest.append(ck.blade(cid + "_napkin", V((0, front - 0.075, zn - 0.01)), V((0, bc.y - br[1] - 0.035, bc.z + 0.07)), 0.4, 0.02, cream, (1, 0, 0), 0.3))
    chest.append(ck.ball(cid + "_napkin_knot", 0.05, V((0, front - 0.07, zn - 0.02)), cream, (1.5, 0.8, 0.8)))
    chest.append(lm._ring(cid + "_fur", zu + 0.055, zu + 0.12, b["neck"] * 2.7, b["neck"] * 2.0, cream, 0.92, 14))
    for sx in (-1, 1):
        chest.append(ck.ball("%s_clasp%d" % (cid, sx), 0.04, V((sx * 0.15, front - 0.03, zu + 0.05)), gold2))
        chest.append(ck.ball("%s_puff%d" % (cid, sx), 0.125, V((sx * (b["shoulder"] + 0.01), 0.0, zu + 0.02)), cape_m, (1.1, 1.0, 0.85)))
    skinned.append(lm._skirt(cid + "_mantle", zu + 0.075, zc + 0.02, b["neck"] * 1.8, b["shoulder"] + 0.11, cape_m, 14, 0.03, 0.55, 0.92, 2))
    skinned.append(lm._skirt(cid + "_cape", zu + 0.01, Z["knee"] + 0.01, b["shoulder"] + 0.04, b["shoulder"] + 0.29, cape_m, 14, 0.05, 1.2, 0.95, 4))
    zb = zp + 0.055
    rb = b["pelvis"] * 1.04
    hips.append(lm._ring(cid + "_belt", zb - 0.025, zb + 0.03, rb * 1.02, rb * 1.02, gold, 0.95, 14))
    hips.append(ck.box(cid + "_buckle", (0.11, 0.035, 0.085), V((0, -rb * 0.97, zb)), gold2, 0.01))
    ck.armor_piece(base["body"], rig, cid + "_breeches", "legs", coat_d, 0.012, 0.014)
    ck.armor_piece(base["body"], rig, cid + "_shoes", "boots", ink, 0.012, 0.014)
    for s, sx in ((".R", -1), (".L", 1)):
        wr, el = V(j["wrist" + s]), V(j["elbow" + s])
        arms[s].append(ck.tube("%s_cuff%s" % (cid, s[1]), el.lerp(wr, 0.7), wr + V((0, 0, -0.012)), b["wrist"] * 1.5, b["wrist"] * 2.4, cream, 10))
        hands[s].append(ck.ball("%s_fist%s" % (cid, s[1]), b["hand"] * 1.15, V(ck.hand_center(base, s)), skin, (1, 1, 1.1)))

    # ---------------- garrafão-maça (mão direita, pelo gargalo) e taça (mão esquerda) ----------------
    g = V(ck.hand_center(base, ".R"))
    fwd = V((0, -0.55, 0.83)).normalized()
    P = lambda t: g + fwd * t
    n = cid + "_bottle"
    hands[".R"] += [ck.tube(n + "_neck", P(-0.1), P(0.22), 0.042, 0.052, glass, 8), ck.tube(n + "_foil", P(-0.15), P(-0.02), 0.052, 0.05, gold2, 8),
                    ck.ball(n + "_cork", 0.052, P(-0.16), gold),
                    _flat(ck.tube(n + "_shoulder", P(0.22), P(0.38), 0.052, 0.19, glass, 10)), _flat(ck.tube(n + "_body", P(0.38), P(0.88), 0.19, 0.2, glass, 10)),
                    _flat(ck.tube(n + "_punt", P(0.88), P(0.93), 0.2, 0.14, glass, 10)),
                    ck.tube(n + "_label", P(0.5), P(0.72), 0.198, 0.202, cream, 10), ck.tube(n + "_band0", P(0.4), P(0.45), 0.2, 0.2, gold, 10),
                    ck.tube(n + "_band1", P(0.79), P(0.86), 0.212, 0.212, gold, 10)]
    u = fwd.cross(V((1, 0, 0))).normalized()
    for k in range(6):
        a = math.tau * k / 6
        d = V((1, 0, 0)) * math.cos(a) + u * math.sin(a)
        hands[".R"].append(mk.cone("%s_stud%d" % (n, k), P(0.825) + d * 0.19, P(0.825) + d * 0.31, 0.045, gold2, 5))
    hands[".R"].append(ck.ball(n + "_seal", 0.045, P(0.61) + V((0, -0.83, -0.55)).normalized() * 0.2, M["glow"], (1, 0.5, 1.4)))
    g2 = V(ck.hand_center(base, ".L"))
    hands[".L"] += lk.goblet(ck, cid + "_goblet", g2 + V((0, 0, 0.21)), 0.15, M)

    ck._rigid(bs._outward(head), rig, "head")
    ck._rigid(bs._outward(chest), rig, "chest")
    ck._rigid(bs._outward(spine), rig, "spine")
    ck._rigid(bs._outward(hips), rig, "hips")
    for s in (".R", ".L"):
        ck._rigid(bs._outward(arms[s]), rig, "forearm" + s)
        ck._rigid(bs._outward(hands[s]), rig, "hand" + s)
    lk.skinned(ck, base, bs._outward(skinned))

    ck.mob_clips(rig, "mace", None, None, extra_keep=ck.MOB_BOSS_KEEP + ("jump", "dash"))
    _varo_feast(rig)
    lm._hips_scale(rig, Z["pelvis"] / 0.38)
    act2_bosses.carry(rig, VARO_CARRY)
    act2_bosses.clear_ground(rig, {"*": 0.03, "die": -0.1}, "hand.R", (cid + "_bottle",), front=True)
    act2_bosses.clear_ground(rig, {"*": 0.02, "die": -0.1}, "hand.L", (cid + "_goblet",))
    lm._join(cid, rig, cid + "_body")
    return rig


def _varo_feast(rig):
    """O Banquete: troca o `cast_channel` do kit (EntityView.ACTIVE_LOOP: repete na fase ativa de 4 s). Ergue a taça num
    brinde, leva à boca no quadro VARO_FEAST_IMPACT e bebe em goles (a barriga sobe e desce), limpa a boca e volta."""
    R = dict(ck.READY)
    legs = {"thigh.R": (-14, 0, 6), "shin.R": (16, 0, 0), "thigh.L": (-4, 0, -6), "shin.L": (10, 0, 0)}
    toast = dict(R, **legs, **{"upper_arm.L": (160, 60, 30), "forearm.L": (-15, 0, 0), "spine": (-6, 0, 0), "chest": (-4, 0, 0), "head": (-10, 0, 0),
                               "upper_arm.R": (-20, 10, 10), "forearm.R": (-25, 0, 0)})
    toast2 = dict(toast, **{"upper_arm.L": (165, 50, 22), "spine": (-8, 0, 3)})
    drink = dict(R, **legs, **{"upper_arm.L": (-85, 30, -30), "forearm.L": (-105, 0, 0), "spine": (-10, 0, 0), "chest": (-4, 0, 0), "head": (-12, 0, 0),
                               "upper_arm.R": (-12, 10, 14), "forearm.R": (-20, 0, 0)})
    gulp = dict(drink, **{"forearm.L": (-116, 0, 0), "spine": (-14, 0, 0), "chest": (-2, 0, 0)})
    wipe = dict(R, **{"upper_arm.L": (-80, 30, -30), "forearm.L": (-70, 0, 0), "spine": (8, 0, 0), "head": (6, 0, 0)})
    ck._pose_action(rig, "cast_channel", [(1, R, None), (5, toast, (0, 0.02, 0)), (9, toast2, (0, 0.03, 0)), (VARO_FEAST_IMPACT, drink, (0, -0.02, 0)),
                                          (18, gulp, (0, -0.045, 0)), (22, drink, (0, -0.02, 0)), (26, gulp, (0, -0.045, 0)), (30, drink, (0, -0.02, 0)),
                                          (34, gulp, (0, -0.045, 0)), (38, wipe, (0, -0.02, 0)), (44, R, None)], 44)


# ---------------------------------------------------------------------------
# Mestra Ressoa, a Regente (dg_conservatory, 49)
# ---------------------------------------------------------------------------
RESSOA = {"leg": 0.2, "torso": 0.06, "arm": 1.3, "head": 0.25, "tear": NOTE}
RESSOA_CARRY = {"upper_arm.R": (-16, 0, 10), "forearm.R": (-46, 0, 0)}       # batuta erguida à frente (só idle/run)


def ressoa(cid="mob_ressoa"):
    return _stretched(_ressoa, cid, RESSOA)


def _ressoa(cid, cfg):
    base, M, m = _base(cid, cfg)
    rig, b, j = base["rig"], base["b"], base["j"]
    Z = ck.Z
    velvet, velvet_d, cream, rose = m("velvet", VELVET, 0.85), m("velvet_d", VELVET_D, 0.85), m("cream", CREAM, 0.6), m("rose", ROSE, 0.8)
    note = m("note", NOTE, 0.3, 2.0)
    gold, gold2, ink, glow = M["gold"], M["gold2"], M["ink"], M["glow"]
    for o in list(bpy.context.scene.objects):          # sem cabeça: no lugar dela, os tubos
        if o.name == cid + "_head":
            bpy.data.objects.remove(o, do_unlink=True)
    c, r_ = V(base["head_c"]), b["head"]
    zc, zw, zn, zp, zu = Z["chest"], Z["waist"], Z["neck"], Z["pelvis"], Z["upper"]
    back = b["chest"] * b["depth"]
    front = -back
    head, chest, hips, skinned = [], [], [], []
    arms = {".R": [], ".L": []}
    hands = {".R": [], ".L": []}
    shins = {".R": [], ".L": []}

    # ---------------- cabeça de tubos de órgão: someiro de ouro, 9 tubos em leque, bocas e topos acesos, máscara pendurada ----------------
    z0 = c.z - r_ * 0.78
    head.append(lm._ring(cid + "_chest_lo", z0 - r_ * 0.3, z0, r_ * 0.55, r_ * 1.02, gold, 0.72, 12))
    head.append(lm._ring(cid + "_chest_hi", z0, z0 + r_ * 0.3, r_ * 1.08, r_ * 1.08, gold2, 0.72, 12))
    head.append(ck.ball(cid + "_chest_top", 1.0, V((0, 0, z0 + r_ * 0.3)), ink, (r_ * 1.02, r_ * 0.7, 0.012)))
    zt = z0 + r_ * 0.3
    for i in range(-4, 5):
        x = i * r_ * 0.215
        y = -r_ * 0.3 + r_ * 0.07 * abs(i)
        h = r_ * (3.3 - 0.36 * abs(i))
        rr = r_ * (0.115 - 0.006 * abs(i))
        head.append(_flat(ck.tube("%s_pipe%d" % (cid, i), (x, y, zt - 0.01), (x, y, zt + h), rr, rr * 1.05, gold2 if i % 2 == 0 else gold, 6)))
        head.append(ck.ball("%s_pipe_top%d" % (cid, i), 1.0, V((x, y, zt + h + 0.004)), note, (rr * 0.92, rr * 0.92, rr * 0.4)))
        head.append(ck.ball("%s_pipe_lip%d" % (cid, i), 1.0, V((x, y - rr * 0.95, zt + r_ * 0.62)), ink, (rr * 0.7, rr * 0.3, rr * 0.5)))
        head.append(ck.ball("%s_pipe_glow%d" % (cid, i), 1.0, V((x, y - rr * 1.0, zt + r_ * 0.5)), note, (rr * 0.6, rr * 0.25, rr * 0.22)))
    for k, (x, h) in enumerate(((-0.62, 2.1), (-0.22, 2.75), (0.22, 2.55), (0.62, 1.9))):      # fileira de trás: tubos graves
        head.append(_flat(ck.tube("%s_bass%d" % (cid, k), (x * r_, r_ * 0.34, zt - 0.01), (x * r_, r_ * 0.34, zt + h * r_), r_ * 0.15, r_ * 0.16, gold, 6)))
        head.append(ck.ball("%s_bass_top%d" % (cid, k), 1.0, V((x * r_, r_ * 0.34, zt + h * r_ + 0.004)), ink, (r_ * 0.13, r_ * 0.13, r_ * 0.04)))
    s_ = r_ * 0.62
    head += lk.mask(ck, cid + "_mask", V((0, -r_ * 0.86, z0 + r_ * 0.2)), s_, M, tears=(1,), tear_len=0.6)
    head.append(ck.tube(cid + "_mask_hang", V((0, -r_ * 0.7, z0 + r_ * 0.2 + s_)), V((0, -r_ * 0.42, zt + r_ * 0.9)), 0.008, 0.008, gold, 4))
    head += lm._bow(cid + "_bow", V((0, r_ * 0.8, z0 + r_ * 0.1)), (0, 1, 0), r_ * 0.6, rose, gold2, rose)
    for sx in (-1, 1):
        head.append(lm._veil("%s_ribbon%d" % (cid, sx), V((sx * r_ * 0.25, r_ * 0.8, z0)), V((sx * 0.26, back + 0.3, zw - 0.05)), r_ * 0.4, r_ * 0.3, rose,
                             (sx * 0.04, 0.09, 0), 4, 0.5))

    # ---------------- tronco: casaca de veludo, peitilho creme, dragonas de ouro, abas compridas, luvas brancas ----------------
    chest.append(lm._ring(cid + "_coat", zw - 0.03, zu + 0.005, b["waist"] * 1.2, b["upper"] * 1.15, velvet))
    chest.append(ck.blade(cid + "_shirt", V((0, front - 0.03, zu + 0.02)), V((0, -b["waist"] * 0.85 - 0.03, zw - 0.01)), 0.17, 0.02, cream, (1, 0, 0), 0.25))
    for k in range(3):
        chest.append(ck.ball("%s_stud%d" % (cid, k), 0.014, V((0, front - 0.045 + 0.012 * k, zu - 0.03 - k * 0.06)), gold2))
    chest.append(lm._ring(cid + "_cravat", zn - 0.035, zn + 0.06, b["neck"] * 1.5, b["neck"] * 2.5, cream, 0.9))
    chest.append(lm._ring(cid + "_collar", zn - 0.045, zn - 0.01, b["neck"] * 2.0, b["neck"] * 1.6, gold, 0.9))
    for s, sx in ((".R", -1), (".L", 1)):
        sh = V((sx * (b["shoulder"] + 0.015), 0.0, zu + 0.03))
        chest.append(ck.ball("%s_epaulet%s" % (cid, s[1]), 1.0, sh, gold2, (0.115, 0.1, 0.035)))
        for k in range(5):
            a = math.pi * (k / 4 - 0.5)
            o = V((sx * math.cos(a) * 0.105, math.sin(a) * 0.09, 0))
            chest.append(ck.tube("%s_fringe%s%d" % (cid, s[1], k), sh + o, sh + o * 1.12 + V((0, 0, -0.085)), 0.014, 0.01, gold, 4))
        wr, el = V(j["wrist" + s]), V(j["elbow" + s])
        chest.append(ck.tube("%s_sleeve%s" % (cid, s[1]), V(j["shoulder" + s]) + V((0, 0, -0.02)), V(j["shoulder" + s]).lerp(el, 0.45), b["arm"] * 1.45, b["arm"] * 1.3, velvet, 8))
        arms[s].append(ck.tube("%s_glove%s" % (cid, s[1]), el.lerp(wr, 0.1), wr.lerp(el, -0.03), b["elbow"] * 1.2, b["wrist"] * 1.28, cream, 8))
        arms[s].append(ck.tube("%s_cuff%s" % (cid, s[1]), el.lerp(wr, 0.02), el.lerp(wr, 0.2), b["elbow"] * 1.5, b["elbow"] * 1.6, gold, 8))
        hands[s].append(ck.ball("%s_fist%s" % (cid, s[1]), b["hand"] * 1.12, V(ck.hand_center(base, s)), cream, (1, 1, 1.1)))
        an = V(j["ankle" + s])
        shins[s].append(ck.tube("%s_anklet%s" % (cid, s[1]), an + V((0, 0, 0.05)), an + V((0, 0, 0.085)), b["ankle"] * 1.55, b["ankle"] * 1.45, gold, 8))
    zb = zp + 0.07
    rb = b["pelvis"] * 1.1
    hips.append(lm._ring(cid + "_belt", zb - 0.02, zb + 0.03, rb * 1.08, rb * 1.02, gold))
    hips.append(ck.ball(cid + "_beltgem", 0.034, V((0, -rb * 0.92, zb)), glow, (0.8, 0.6, 1.5)))
    skinned.append(lm._skirt(cid + "_peplum", zb + 0.012, zb - 0.13, rb * 1.1, rb * 1.55, velvet, 14, 0.03, 0.75))
    for sx in (-1, 1):                # abas da casaca até a panturrilha, forro rosa
        p0 = V((sx * 0.085, back + 0.03, zb - 0.02))
        p1 = V((sx * 0.2, back + 0.3, Z["knee"] - 0.02))
        skinned.append(lm._veil("%s_tail%d" % (cid, sx), p0, p1, 0.17, 0.2, velvet, (sx * 0.03, 0.09, 0), 5, 0.25, 0.018))
        skinned.append(lm._veil("%s_tail_in%d" % (cid, sx), p0 + V((0, -0.016, -0.03)), p1 + V((0, -0.02, 0.06)), 0.12, 0.14, rose, (sx * 0.03, 0.085, 0), 5, 0.25))
    ck.armor_piece(base["body"], rig, cid + "_boots", "boots", ink, 0.012, 0.014)

    # ---------------- batuta (mão direita) ----------------
    g = V(ck.hand_center(base, ".R"))
    fwd = V((0, -0.55, 0.83)).normalized()
    n = cid + "_baton"
    hands[".R"] += [ck.tube(n + "_grip", g - fwd * 0.08, g + fwd * 0.07, 0.026, 0.02, gold, 6), ck.ball(n + "_pommel", 0.036, g - fwd * 0.09, gold2),
                    ck.tube(n + "_stick", g + fwd * 0.07, g + fwd * 0.78, 0.016, 0.008, cream, 5), ck.ball(n + "_tip", 0.032, g + fwd * 0.79, note, (1, 1, 1))]

    ck._rigid(bs._outward(head), rig, "head")
    ck._rigid(bs._outward(chest), rig, "chest")
    ck._rigid(bs._outward(hips), rig, "hips")
    for s in (".R", ".L"):
        ck._rigid(bs._outward(arms[s]), rig, "forearm" + s)
        ck._rigid(bs._outward(hands[s]), rig, "hand" + s)
        ck._rigid(bs._outward(shins[s]), rig, "shin" + s)
    lk.skinned(ck, base, bs._outward(skinned))

    ck.mob_clips(rig, None, None, "atk_thrust", extra_keep=ck.MOB_BOSS_KEEP + ("jump", "dash", "atk_thrust"))
    lm._hips_scale(rig, Z["pelvis"] / 0.38)
    act2_bosses.carry(rig, RESSOA_CARRY)
    act2_bosses.clear_ground(rig, {"*": 0.03, "die": -0.1}, "hand.R", (cid + "_baton",), front=True)
    lm._join(cid, rig, cid + "_body")
    return rig


# ---------------------------------------------------------------------------
# Tubo de Órgão (lacaio parado da Ressoa)
# ---------------------------------------------------------------------------
PIPE_BONES = {               # todos de pé (x = X, y = para cima, z = -Y)
    "root": ((0, 0, 0), (0, 0, 0.2), None),                   # soco e someiro: nunca se mexem
    "body": ((0, 0, 0.42), (0, 0, 0.8), "root"),              # tubo grande + os dois graves de trás
    "head": ((0, -0.2, 1.5), (0, -0.2, 1.7), "body"),         # máscara pendurada
    "arm_r": ((0.37, -0.04, 0.42), (0.37, -0.04, 0.8), "root"),
    "arm_l": ((-0.37, -0.04, 0.42), (-0.37, -0.04, 0.8), "root"),
    "core": ((0, -0.2, 0.84), (0, -0.2, 1.0), "body"),        # boca acesa do tubo grande (escala = a nota)
}


def organ_pipe(cid="mob_organ_pipe"):
    """Coluna de tubos de órgão (~2,35 m): soco de madeira-vinho, um tubo grande com a máscara da lágrima, dois tubos de lado
    e dois graves atrás; bocas e topos acesos (a câmera alta vê os discos de luz). Frente = -Y."""
    arm = mk.lp.make_armature("rig_" + cid, PIPE_BONES)
    m = lambda n, col, rough=0.7, em=0.0: ck.mat("m_%s_%s" % (cid, n), col, rough, em)
    M = {"porc": m("mask", lm.MASK, 0.3), "gold": m("gold", lm.OLD_GOLD, 0.4), "gold2": m("gold2", lm.BRIGHT_GOLD, 0.35), "ink": m("ink", lm.INK, 0.6),
         "glow": m("glow_note", NOTE, 0.3, 2.2)}
    gold, gold2, ink, note = M["gold"], M["gold2"], M["ink"], M["glow"]
    wood, rose = m("wood", VELVET_D, 0.85), m("rose", ROSE, 0.8)
    P = _Parts()
    P.add("root", _flat(ck.tube("plinth", (0, 0, 0), (0, 0, 0.2), 0.66, 0.6, wood, 8)), _flat(ck.tube("chest", (0, 0, 0.2), (0, 0, 0.42), 0.54, 0.54, wood, 8)),
          _hoop("plinth_trim", (0, 0, 0.2), 0.6, 0.03, gold, 16), _hoop("chest_trim", (0, 0, 0.42), 0.54, 0.03, gold2, 16))

    def pipe(bone, name, x, y, rr, h, mat_, mouth=True):
        P.add(bone, _flat(ck.tube(name + "_foot", (x, y, 0.4), (x, y, 0.4 + rr * 1.5), rr * 0.45, rr, mat_, 10)),
              _flat(ck.tube(name, (x, y, 0.4 + rr * 1.5), (x, y, h), rr, rr * 1.04, mat_, 10)),
              ck.ball(name + "_bore", 1.0, (x, y, h + 0.004), ink, (rr * 0.9, rr * 0.9, 0.012)),
              ck.ball(name + "_top", 1.0, (x, y, h + 0.012), note, (rr * 0.66, rr * 0.66, 0.02)))
        if mouth:
            zm = 0.4 + rr * 1.5 + rr * 0.9
            P.add(bone, ck.ball(name + "_lip", 1.0, (x, y - rr * 0.98, zm + rr * 0.35), ink, (rr * 0.62, rr * 0.16, rr * 0.34)),
                  ck.ball(name + "_lip_up", 1.0, (x, y - rr * 1.0, zm + rr * 0.72), gold if mat_ is gold2 else gold2, (rr * 0.7, rr * 0.14, rr * 0.1)))
            return (x, y - rr * 1.02, zm + rr * 0.2)
        return None

    mm = pipe("body", "main", 0, 0, 0.2, 2.3, gold2)
    P.add("core", ck.ball("main_glow", 1.0, mm, note, (0.105, 0.03, 0.045)))
    for bone, sx, h in (("arm_r", 1, 1.78), ("arm_l", -1, 1.5)):
        q = pipe(bone, "side%d" % sx, sx * 0.37, -0.04, 0.13, h, gold)
        P.add(bone, ck.ball("side_glow%d" % sx, 1.0, q, note, (0.07, 0.022, 0.03)))
    for k, (x, h) in enumerate(((0.2, 2.0), (-0.2, 1.72))):
        pipe("body", "bass%d" % k, x, 0.3, 0.115, h, gold, False)
    P.add("body", lm._ring("ribbon", 1.14, 1.24, 0.213, 0.213, rose, 1.0, 10))
    P.add("body", lm._bow("ribbon_bow", V((0.12, -0.19, 1.19)), (0.4, -1, 0), 0.2, rose, gold2, rose))
    P.add("head", lk.mask(ck, "mask", V((0, -0.235, 1.62)), 0.16, M, tears=(1,), tear_len=0.6))
    P.finish(arm, cid)

    s = math.sin
    sway = lambda a: _loop(48, 4, lambda ph: (r(a * s(ph), 0, a * 0.6 * s(ph + 0.8)), Z0))
    _sclip(arm, "idle", 48, {"body": sway(0.5), "core": [(f, Z0, Z0, (1 + 0.14 * s((f - 1) / 47 * math.tau * 2),) * 3) for f in list(range(1, 48, 4)) + [48]]}, loop=True)
    _sclip(arm, "run", 16, {}, loop=True)
    # nota (10): o tubo incha e solta; os de lado saltam; a boca acende
    bounce = lambda h_: [(6, Z0, (0, -0.02, 0)), (10, Z0, (0, h_, 0)), (13, Z0, (0, -0.01, 0)), (16, Z0, Z0)]
    blow = {"body": [(6, Z0, Z0, (1.05, 0.94, 1.05)), (10, Z0, Z0, (0.95, 1.1, 0.95)), (13, Z0, Z0, (1.02, 0.98, 1.02)), (17, Z0, Z0, ONE)],
            "arm_r": bounce(0.14), "arm_l": bounce(0.2), "head": [(10, r(-14), Z0), (14, r(6), Z0), (18, Z0, Z0)],
            "core": _sc([(6, 0.5), (10, 2.6), (14, 1.5), (20, 1.0)])}
    _sclip(arm, "cast_ground", 22, blow)
    _sclip(arm, "cast", 22, blow)
    _sclip(arm, "shout", 19, _retime(blow, 10, 7))
    _sclip(arm, "attack", 17, _retime(blow, 10, 5))
    _sclip(arm, "hit", 10, {"body": [(2, r(-7, 0, 4), Z0), (5, r(4, 0, -3), Z0), (8, r(-1.5), Z0)],
                            "arm_r": [(2, r(0, 0, -7), Z0), (5, r(0, 0, 4), Z0)], "arm_l": [(2, r(0, 0, 7), Z0), (5, r(0, 0, -4), Z0)],
                            "head": [(2, r(-16), Z0), (5, r(8), Z0)], "core": _sc([(2, 0.4), (6, 1.0)])})
    # die: a nota desafina e apaga; os tubos de lado tombam para fora, o grande entorta, a máscara cai
    _sclip(arm, "die", 28, {
        "body": [(3, r(4), Z0), (8, r(-6, 0, 3), Z0), (14, r(-13, 0, 7), (0, -0.03, 0)), (18, r(-12, 0, 6), (0, -0.03, 0)), (22, r(-13, 0, 7), (0, -0.03, 0))],
        "arm_r": [(3, r(0, 0, 3), Z0), (9, r(0, 0, -30), Z0), (15, r(4, 0, -78), (0.1, -0.02, 0)), (18, r(4, 0, -74), (0.1, -0.02, 0)), (21, r(4, 0, -78), (0.1, -0.02, 0))],
        "arm_l": [(5, r(0, 0, -3), Z0), (12, r(0, 0, 34), Z0), (18, r(-5, 0, 80), (-0.1, -0.02, 0)), (21, r(-5, 0, 76), (-0.1, -0.02, 0)), (24, r(-5, 0, 80), (-0.1, -0.02, 0))],
        "head": [(4, r(-10), Z0), (10, r(30), (0, -0.5, 0.12)), (15, r(84, 0, 12), (0, -1.36, 0.3)), (17, r(80, 0, 12), (0, -1.33, 0.3)), (19, r(84, 0, 12), (0, -1.36, 0.3))],
        "core": _sc([(3, 2.2), (8, 0.6), (12, 1.4), (17, 0.001)])})
    return arm


# ---------------------------------------------------------------------------
# Pedestais dos Sentidos (lacaios parados do Eco)
# ---------------------------------------------------------------------------
PED_BONES = {
    "root": ((0, 0, 0), (0, 0, 0.2), None),                   # degraus e coluna
    "body": ((0, 0, 1.2), (0, 0, 1.45), "root"),              # capitel + prato
    "head": ((0, 0, 1.82), (0, 0, 2.02), "body"),             # emblema do sentido, flutuando sobre o prato
    "core": ((0, 0, 1.42), (0, 0, 1.6), "body"),              # luz do prato (escala = pulso)
}


def sense_pedestal(cid="mob_sense_pedestal", kind=""):
    """Pedestal de porcelana (~2,1 m) com um prato de luz na cor do sentido e o emblema flutuando em cima:
    sight = olho que chora, hearing = corneta de gramofone, smell = incensário, taste = taça cheia, "" = máscara."""
    arm = mk.lp.make_armature("rig_" + cid, PED_BONES)
    m = lambda n, col, rough=0.7, em=0.0: ck.mat("m_%s_%s" % (cid, n), col, rough, em)
    col = SENSE_GLOW[kind]
    M = {"porc": m("mask", lm.MASK, 0.3), "gold": m("gold", lm.OLD_GOLD, 0.4), "gold2": m("gold2", lm.BRIGHT_GOLD, 0.35), "ink": m("ink", lm.INK, 0.6),
         "glow": m("glow_sense", col, 0.3, 2.2)}
    gold, gold2, ink, glow, porc = M["gold"], M["gold2"], M["ink"], M["glow"], m("porc", lm.PORC, 0.4)
    cloth = m("ribbon", tuple(0.35 + 0.5 * x for x in col), 0.8)
    P = _Parts()
    P.add("root", _flat(ck.tube("step0", (0, 0, 0), (0, 0, 0.13), 0.56, 0.52, gold, 8)), _flat(ck.tube("step1", (0, 0, 0.13), (0, 0, 0.27), 0.43, 0.39, porc, 8)),
          _flat(ck.tube("column", (0, 0, 0.27), (0, 0, 1.2), 0.21, 0.17, porc, 10)), _hoop("base_ring", (0, 0, 0.3), 0.225, 0.035, gold2, 14),
          _hoop("neck_ring", (0, 0, 1.17), 0.185, 0.03, gold2, 14))
    P.add("root", _sweep("spiral", [(math.cos(t * 4.2 + 1.0) * (0.225 - 0.035 * t), math.sin(t * 4.2 + 1.0) * (0.225 - 0.035 * t), 0.36 + t * 0.76) for t in [k / 14 for k in range(15)]],
                         [0.032] * 15, cloth, 5))
    P.add("body", _flat(ck.tube("capital", (0, 0, 1.2), (0, 0, 1.32), 0.19, 0.33, gold2, 10)), _flat(ck.tube("dish", (0, 0, 1.32), (0, 0, 1.41), 0.33, 0.47, porc, 12)),
          _hoop("dish_lip", (0, 0, 1.41), 0.47, 0.026, gold, 18))
    P.add("core", ck.ball("light", 1.0, (0, 0, 1.415), glow, (0.4, 0.4, 0.025)))
    for k in range(3):               # lágrimas de luz escorrendo do prato
        a = math.tau * (k + 0.3) / 3
        P.add("body", ck.ball("drip%d" % k, 0.035, (math.cos(a) * 0.46, math.sin(a) * 0.46, 1.33), glow, (0.8, 0.8, 1.9)))
    hc = V((0, 0, 1.9))
    if kind == "sight":
        P.add("head", ck.ball("eye", 0.21, hc, M["porc"]), ck.ball("iris", 1.0, hc + V((0, -0.185, 0)), glow, (0.115, 0.05, 0.115)),
              ck.ball("pupil", 1.0, hc + V((0, -0.215, 0)), ink, (0.055, 0.03, 0.055)), ck.ball("tear", 0.04, hc + V((0.06, -0.17, -0.2)), glow, (0.8, 0.7, 2.0)),
              _hoop("lid", hc, 0.225, 0.022, gold, 16, 5, 0.0001))
        for k in range(5):
            a = math.radians(50 + k * 20)
            P.add("head", ck.blade("lash%d" % k, hc + V((math.cos(a) * 0.21, -0.03, math.sin(a) * 0.21)), hc + V((math.cos(a) * 0.36, -0.06, math.sin(a) * 0.36)), 0.06, 0.016,
                                   gold2, (-math.sin(a), 0, math.cos(a)), 0.3))
    elif kind == "hearing":
        P.add("head", _flat(ck.tube("horn", hc + V((0, 0.16, -0.16)), hc + V((0, -0.2, 0.12)), 0.035, 0.27, gold2, 10)),
              ck.tube("horn_neck", hc + V((0, 0.16, -0.16)), hc + V((0, 0.2, -0.3)), 0.035, 0.05, gold, 6),
              lk.place([ck.ball("horn_bore", 1.0, (0, 0, 0), ink, (0.235, 0.02, 0.235))], hc + V((0, -0.203, 0.122)), (0, -0.79, 0.61)),
              ck.ball("horn_note", 0.06, hc + V((0, -0.26, 0.17)), glow), ck.ball("horn_note2", 0.04, hc + V((0.12, -0.36, 0.3)), glow))
    elif kind == "smell":
        P.add("head", lk.lantern(ck, "censer", hc + V((0, 0, -0.04)), 0.17, M))
        for k, (dx, dy, dz, rr) in enumerate(((0.02, -0.02, 0.26, 0.085), (-0.07, 0.03, 0.4, 0.065), (0.06, 0.02, 0.52, 0.045))):
            P.add("head", mk.blob("fume%d" % k, rr, hc + V((dx, dy, dz)), glow, (1, 1, 1.15), 1))
    elif kind == "taste":
        P.add("head", lk.goblet(ck, "goblet", hc + V((0, 0, 0.2)), 0.3, M))
    else:
        P.add("head", lk.mask(ck, "mask", hc + V((0, -0.03, 0)), 0.2, M, tears=(1,), tear_len=0.6))
    P.finish(arm, cid)

    s = math.sin
    bob = lambda amp, yaw: _loop(48, 4, lambda ph: (r(0, yaw * s(ph), 0), (0, amp * s(2 * ph), 0)))
    _sclip(arm, "idle", 48, {"head": bob(0.035, 14), "core": [(f, Z0, Z0, (1 + 0.1 * s((f - 1) / 47 * math.tau * 2),) * 3) for f in list(range(1, 48, 4)) + [48]]}, loop=True)
    _sclip(arm, "run", 16, {}, loop=True)
    pulse = {"head": [(5, r(8), (0, -0.05, 0)), (10, r(-10), (0, 0.2, 0)), (14, r(-4), (0, 0.14, 0)), (20, Z0, Z0)],
             "body": [(5, Z0, Z0, (1.04, 0.95, 1.04)), (10, Z0, Z0, (0.97, 1.06, 0.97)), (15, Z0, Z0, ONE)],
             "core": _sc([(5, 0.6), (10, 1.5), (14, 1.25), (20, 1.0)])}
    _sclip(arm, "cast_ground", 22, pulse)
    _sclip(arm, "cast", 22, pulse)
    _sclip(arm, "shout", 19, _retime(pulse, 10, 7))
    _sclip(arm, "attack", 17, _retime(pulse, 10, 5))
    _sclip(arm, "hit", 10, {"body": [(2, r(-6, 0, 4), Z0), (5, r(3, 0, -2), Z0)], "head": [(2, r(-14, 0, 8), (0, 0.06, 0)), (5, r(6, 0, -4), Z0)],
                            "core": _sc([(2, 0.5), (6, 1.0)])})
    _sclip(arm, "die", 26, {
        "body": [(3, r(5), Z0), (8, r(-8, 0, 5), Z0), (14, r(-16, 0, 10), (0, -0.02, 0)), (17, r(-14, 0, 9), (0, -0.02, 0)), (20, r(-16, 0, 10), (0, -0.02, 0))],
        "head": [(4, r(0, 30, 0), (0, 0.12, 0)), (9, r(20, 80, 10), (0, -0.1, 0)), (13, r(50, 120, 20), (0, -0.33, 0.05)), (15, r(46, 124, 20), (0, -0.3, 0.05)),
                 (17, r(50, 120, 20), (0, -0.33, 0.05))],
        "core": _sc([(3, 1.6), (8, 0.5), (11, 1.1), (16, 0.001)])})
    return arm


# ---------------------------------------------------------------------------
# O Eco de Amarante (raide, rift_heart, 50): vestido de espelhos SEM corpo sob uma coroa vazia
# ---------------------------------------------------------------------------
ECHO_BONES = {
    "root": ((0, 0, 0), (0, 0, 0.2), None),                   # só sobe/desce e gira (flutua)
    "body": ((0, 0, 1.3), (0, 0, 1.6), "root"),               # corpete, gola de cacos, saia de cima: inclina na cintura
    "head": ((0, 0, 2.2), (0, 0, 2.45), "body"),              # a coroa vazia
    "core": ((0, -0.02, 2.0), (0, -0.02, 2.2), "body"),       # vapor perfumado onde seria o rosto (escala = pulso)
    "arm_r": ((0.46, 0, 1.6), (0.46, 0, 1.25), "body"),       # luva vazia +X com o caco de espelho
    "arm_l": ((-0.46, 0, 1.6), (-0.46, 0, 1.25), "body"),     # luva vazia -X
    "leg_fr": ((0.3, -0.3, 0.72), (0.3, -0.3, 0.42), "body"),  # quadrantes da saia de baixo (abrem em roda)
    "leg_fl": ((-0.3, -0.3, 0.72), (-0.3, -0.3, 0.42), "body"),
    "leg_br": ((0.3, 0.3, 0.72), (0.3, 0.3, 0.42), "body"),
    "leg_bl": ((-0.3, 0.3, 0.72), (-0.3, 0.3, 0.42), "body"),
}
ECHO_LEGS = ("leg_fr", "leg_fl", "leg_br", "leg_bl")
ECHO_TIERS = ((1.32, 0.2), (1.02, 0.45), (0.66, 0.64), (0.3, 0.77))      # (z, raio) da cintura à barra: o vestido flutua a 0,1 m
ECHO_COUNTS = (8, 10, 12)


def _facet(name, a0, a1, ra, za, rb, zb, material, thick=0.03, inset=0.08):
    """Faceta de espelho: trapézio plano entre os ângulos a0..a1, de (ra, za) a (rb, zb), recuado nas bordas (o ouro aparece)."""
    da = (a1 - a0) * inset
    a0, a1 = a0 + da, a1 - da
    t = inset * 0.7
    ra2, za2, rb2, zb2 = ra + (rb - ra) * t, za + (zb - za) * t, rb - (rb - ra) * t, zb - (zb - za) * t
    Pn = lambda a, rr, zz: V((math.cos(a) * rr, math.sin(a) * rr, zz))
    q = [Pn(a0, ra2, za2), Pn(a1, ra2, za2), Pn(a1, rb2, zb2), Pn(a0, rb2, zb2)]
    nrm = (q[1] - q[0]).cross(q[3] - q[0]).normalized()
    mid = (q[0] + q[1] + q[2] + q[3]) / 4
    if nrm.dot(V((mid.x, mid.y, 0))) < 0:
        nrm = -nrm
    bm_ = bmesh.new()
    f = [bm_.verts.new(v) for v in q]
    b_ = [bm_.verts.new(v - nrm * thick) for v in q]
    bm_.faces.new(f)
    bm_.faces.new(b_[::-1])
    for i in range(4):
        bm_.faces.new((f[i], b_[i], b_[(i + 1) % 4], f[(i + 1) % 4]))
    bmesh.ops.recalc_face_normals(bm_, faces=bm_.faces[:])
    return _flat(ck.mesh_from(name, bm_, material))


def sylvare_echo(cid="mob_sylvare_echo"):
    arm = mk.lp.make_armature("rig_" + cid, ECHO_BONES)
    m = lambda n, col, rough=0.7, em=0.0: ck.mat("m_%s_%s" % (cid, n), col, rough, em)
    gold, gold2, ink = m("gold", lm.OLD_GOLD, 0.4), m("gold2", lm.BRIGHT_GOLD, 0.35), m("ink", lm.INK, 0.6)
    mir, mir2, mir3 = m("mirror", lm.MIRROR, 0.15), m("mirror2", lm.MIRROR_LIGHT, 0.15), m("mirror3", (0.86, 0.72, 0.84), 0.15)
    rose, rose_d, cream = m("rose", ROSE, 0.8), m("rose_d", (0.6, 0.36, 0.46), 0.8), m("cream", CREAM, 0.6)
    vap, vap2, tear = m("glow_vapor", VAPOR, 0.5, 1.5), m("glow_vapor2", VAPOR_L, 0.5, 2.0), m("glow_tear", lm.GOLD_TEAR, 0.3, 2.2)
    P = _Parts()
    rnd = random.Random(50)

    # ---------------- saia de espelhos em três camadas ----------------
    for k in range(3):
        (za, ra), (zb, rb) = ECHO_TIERS[k], ECHO_TIERS[k + 1]
        n = ECHO_COUNTS[k]
        ca = math.cos(math.pi / n)
        if k < 2:
            P.add("body", _flat(ck.tube("under%d" % k, (0, 0, za), (0, 0, zb), ra * ca - 0.02, rb * ca - 0.02, gold, n * 2)))
        else:
            P.add("body", _flat(ck.tube("under2", (0, 0, za), (0, 0, zb + 0.1), ra * ca - 0.03, rb * 0.86, ink, 12)))
        for i in range(n):
            a0, a1 = math.tau * (i + 0.5 * k) / n, math.tau * (i + 1 + 0.5 * k) / n
            am = (a0 + a1) * 0.5
            mat_ = (mir, mir2, mir, mir3)[(i + k) % 4] if rnd.random() < 0.85 else mir2
            bone = "body"
            if k == 2:
                bone = "leg_%s%s" % ("b" if math.sin(am) > 0 else "f", "r" if math.cos(am) > 0 else "l")
                o = V((math.cos(am), math.sin(am), 0))
                tg = V((-math.sin(am), math.cos(am), 0))
                P.add(bone, _flat(ck.blade("hem%d" % i, o * (rb * ca) + V((0, 0, zb + 0.02)), o * (rb * ca + 0.03) + V((0, 0, 0.1 + 0.05 * (i % 2))), rb * math.tau / n * 0.62, 0.025,
                                           mir2 if i % 2 else mir, tg, 0.3)))
                P.add(bone, _facet("frame2_%d" % i, a0, a1, ra - 0.012, za, rb - 0.012, zb, gold, 0.02, 0.01))
            P.add(bone, _facet("facet%d_%d" % (k, i), a0, a1, ra, za, rb, zb, mat_))
    P.add("body", _hoop("ridge0", (0, 0, 1.02), 0.455, 0.028, gold2, 20), _hoop("ridge1", (0, 0, 0.67), 0.645, 0.03, gold2, 24))

    # ---------------- corpete vazio, gola de cacos, laços ----------------
    P.add("body", lm._ring("bodice", 1.3, 1.74, 0.2, 0.31, rose, 0.8, 12), _hoop("waist", (0, 0, 1.31), 0.215, 0.03, gold2, 16, 5, 0.8),
          _hoop("neckline", (0, 0, 1.74), 0.31, 0.026, gold, 18, 5, 0.8), ck.ball("hollow", 1.0, (0, 0, 1.742), ink, (0.285, 0.225, 0.02)))
    P.add("body", _flat(ck.blade("heart", (0, -0.262, 1.72), (0, -0.19, 1.36), 0.27, 0.03, mir2, (1, 0, 0), 0.32)),
          _flat(ck.blade("heart_rim", (0, -0.25, 1.75), (0, -0.175, 1.32), 0.33, 0.03, gold, (1, 0, 0), 0.32)))
    for i in range(9):
        a = math.radians(-90 + 62 + i * 236 / 8)
        o = V((math.cos(a), math.sin(a) * 0.8, 0))
        tg = V((-math.sin(a), math.cos(a) * 0.8, 0)).normalized()
        up = 0.3 + 0.16 * max(0.0, math.sin(a)) + (0.05 if i % 2 else 0.0)
        P.add("body", _flat(ck.blade("collar%d" % i, o * 0.3 + V((0, 0, 1.73)), o * (0.5 + 0.06 * max(0.0, math.sin(a))) + V((0, 0, 1.73 + up)), 0.21, 0.022, mir2 if i % 2 else mir, tg, 0.4)))
    for sx in (-1, 1):
        P.add("body", ck.ball("puff%d" % sx, 0.125, (sx * 0.37, 0.0, 1.7), rose_d, (1.1, 1.0, 0.85)))
        P.add("body", lm._veil("ribbon%d" % sx, V((sx * 0.13, 0.25, 1.74)), V((sx * 0.34, 0.86, 0.5)), 0.2, 0.15, rose, (sx * 0.05, 0.12, 0), 5, 0.3))
    P.add("body", lm._bow("back_bow", V((0, 0.27, 1.6)), (0, 1, 0), 0.34, rose_d, gold2, rose_d))

    # ---------------- vapor onde seria o rosto + uma lágrima só ----------------
    fc = V((0, -0.02, 2.04))
    P.add("core", mk.blob("vapor", 0.2, fc, vap, (1.0, 0.85, 1.05), 2))
    for k, (dx, dy, dz, rr, mm) in enumerate(((0.14, 0.02, 0.06, 0.12, vap2), (-0.13, 0.05, -0.02, 0.13, vap), (0.03, 0.1, 0.17, 0.12, vap), (-0.05, -0.06, 0.24, 0.09, vap2),
                                              (0.06, 0.02, 0.4, 0.075, vap), (-0.03, 0.06, 0.55, 0.05, vap2), (0.0, 0.2, -0.12, 0.1, vap))):
        P.add("core", mk.blob("wisp%d" % k, rr, fc + V((dx, dy, dz)), mm, (1, 1, 1.1), 1))
    P.add("core", ck.ball("tear", 0.034, fc + V((0.09, -0.17, -0.2)), tear, (0.8, 0.7, 2.2)))

    # ---------------- coroa vazia ----------------
    zc_ = 2.3
    P.add("head", _hoop("crown_lo", (0, 0, zc_), 0.28, 0.024, gold2, 20), _hoop("crown_hi", (0, 0, zc_ + 0.09), 0.285, 0.02, gold2, 20))
    for i in range(12):
        a = math.tau * i / 12
        o = V((math.cos(a), math.sin(a), 0))
        P.add("head", ck.tube("crown_bar%d" % i, o * 0.28 + V((0, 0, zc_)), o * 0.285 + V((0, 0, zc_ + 0.09)), 0.014, 0.014, gold, 4))
        if i % 2 == 0:
            hgt = 0.34 if i % 4 == 0 else 0.22
            tg = V((-math.sin(a), math.cos(a), 0))
            P.add("head", ck.blade("crown_point%d" % i, o * 0.285 + V((0, 0, zc_ + 0.08)), o * 0.33 + V((0, 0, zc_ + 0.09 + hgt)), 0.12, 0.022, gold2, tg, 0.3))
            P.add("head", ck.ball("crown_gem%d" % i, 0.034, o * 0.3 + V((0, 0, zc_ + 0.045)), mir2 if i % 4 else tear))

    # ---------------- luvas vazias; a de +X leva o caco de espelho ----------------
    for bone, sx in (("arm_r", 1), ("arm_l", -1)):
        top, wr = V((sx * 0.5, 0.0, 1.5)), V((sx * 0.56, -0.13, 1.1))
        fist = wr + (wr - top).normalized() * 0.07
        P.add(bone, ck.tube("glove%d" % sx, top, wr, 0.085, 0.06, cream, 8), ck.ball("glove_in%d" % sx, 1.0, top + V((0, 0, 0.004)), ink, (0.078, 0.078, 0.014)),
              ck.tube("glove_rim%d" % sx, top + (wr - top) * 0.0, top + (wr - top) * 0.06, 0.095, 0.092, gold, 8),
              ck.tube("bracelet%d" % sx, top.lerp(wr, 0.86), top.lerp(wr, 0.96), 0.072, 0.07, gold2, 8), ck.ball("fist%d" % sx, 0.085, fist, cream, (1, 1, 1.1)))
        if sx > 0:
            fwd = V((0, -0.62, 0.78)).normalized()
            P.add(bone, ck.tube("shard_grip", fist - fwd * 0.1, fist + fwd * 0.1, 0.026, 0.026, gold, 6),
                  _flat(ck.blade("shard", fist + fwd * 0.08, fist + fwd * 0.95, 0.2, 0.03, mir2, (1, 0, 0), 0.3)),
                  _flat(ck.blade("shard_rim", fist + fwd * 0.06, fist + fwd * 0.6, 0.1, 0.045, gold2, (1, 0, 0), 0.3)))
        else:
            P.add(bone, mk.blob("palm_vapor", 0.07, fist + V((0, -0.06, 0.14)), vap2, (1, 1, 1.2), 1), mk.blob("palm_vapor2", 0.045, fist + V((0.02, -0.04, 0.27)), vap, (1, 1, 1.2), 1))
    P.finish(arm, cid)
    _echo_clips(arm)
    return arm


def _echo_clips(arm):
    """Flutua: o `root` só sobe, desce e avança; a inclinação fica no `body` (cintura) e sempre com o root erguido, para a
    barra não varar o chão. Nomes = os do kit (EntityView._clip) + os genéricos (maul pounce slam roar brace)."""
    L = ECHO_LEGS
    s, c = math.sin, math.cos
    legs = lambda seq: {g: _splay(g, seq) for g in L}
    both = lambda seq: {"arm_r": limb("arm_r", seq), "arm_l": limb("arm_l", seq)}
    up = lambda seq: [(k[0], Z0, p(*k[1:])) for k in seq]                    # root: [(quadro, cima, frente)]

    def clip(name, end, keys, loop=False):
        _sclip(arm, name, end, keys, loop)

    def many(names, end, keys, src):
        for nm, dst in names:
            clip(nm, end + dst - src, keys if dst == src else _retime(keys, src, dst))

    # idle: paira, o vapor pulsa, a coroa gira devagar de um lado ao outro, a saia respira
    keys = {"root": _loop(48, 4, lambda ph: (Z0, p(0.05 + 0.05 * s(ph)))),
            "body": _loop(48, 4, lambda ph: (r(1.5 * s(ph + 0.5), 3 * s(ph), 1.2 * s(ph + 1.1)), Z0)),
            "head": _loop(48, 4, lambda ph: (r(3 * s(ph + 0.7), 22 * s(ph), 2 * c(ph)), p(0.025 * s(ph + 1.5)))),
            "core": [(f, Z0, Z0, (1 + 0.1 * s((f - 1) / 47 * math.tau * 2),) * 3) for f in list(range(1, 48, 4)) + [48]],
            "arm_r": _loop(48, 4, lambda ph: ((-8 - 5 * s(ph + 1.0), 0, -(5 + 4 * s(ph + 0.4))), (0, -0.03 * s(ph + 0.8), 0))),
            "arm_l": _loop(48, 4, lambda ph: ((-8 - 5 * s(ph + 2.2), 0, 5 + 4 * s(ph + 1.6)), (0, -0.03 * s(ph + 2.0), 0)))}
    for i, g in enumerate(L):
        fs, ss = (-1 if g[4] == "f" else 1), (-1 if g.endswith("r") else 1)
        keys[g] = _loop(48, 4, lambda ph, i=i, fs=fs, ss=ss: ((fs * 0.7 * (2 + 2.5 * s(ph + i * 1.6)), 0, ss * 0.7 * (2 + 2.5 * s(ph + i * 1.6))), Z0))
    clip("idle", 48, keys, loop=True)
    # run: desliza inclinada, a saia fica para trás, as luvas seguem
    keys = {"root": _loop(16, 2, lambda ph: (Z0, p(0.16 + 0.03 * s(ph)))),
            "body": _loop(16, 2, lambda ph: (r(9 + 1.5 * s(ph), 0, 2 * c(ph)), Z0)),
            "head": _loop(16, 2, lambda ph: (r(-5, 0, -2 * c(ph)), Z0)),
            "arm_r": _loop(16, 2, lambda ph: ((22 + 6 * s(ph), 0, -10), Z0)), "arm_l": _loop(16, 2, lambda ph: ((22 + 6 * s(ph + 1.2), 0, 10), Z0))}
    for g in L:
        k_ = 12 if g[4] == "b" else 5
        fs, ss = (-1 if g[4] == "f" else 1), (-1 if g.endswith("r") else 1)
        keys[g] = _loop(16, 2, lambda ph, k_=k_, fs=fs, ss=ss: ((fs * 0.7 * (k_ + 3 * s(ph)), 0, ss * 0.7 * (k_ + 3 * s(ph))), Z0))
    clip("run", 16, keys, loop=True)
    # corte de caco (5): arma a luva do espelho no alto e risca em diagonal
    slash = {"root": up([(3, 0.1, -0.06), (5, 0.12, 0.16), (8, 0.1, 0.12), (12, 0.04, 0.03)]),
             "body": _up([(3, r(-5, -22)), (5, r(9, 26)), (8, r(8, 20)), (12, r(3, 5))]),
             "head": _up([(3, r(-8, 10)), (5, r(8, -12)), (10, r(3))]),
             "arm_r": limb("arm_r", [(3, -135, 30), (5, -48, -22), (8, -40, -26), (12, -14)]),
             "arm_l": limb("arm_l", [(3, 12, 26), (5, 26, 32), (12, 5)]),
             "core": _sc([(3, 0.9), (5, 1.3), (10, 1.0)])}
    slash.update(legs([(3, 3), (5, 11), (9, 3)]))
    many((("attack", 5), ("atk_claw", 6), ("atk_throw", 7), ("maul", 7)), 16, slash, 5)
    # lampejo (5): recolhe e dispara esticada para a frente atrás do caco
    lunge = {"root": up([(3, 0.12, -0.16), (5, 0.24, 0.5), (8, 0.24, 0.46), (12, 0.14, 0.2), (16, 0.04, 0.05)]),
             "body": _up([(3, r(-8)), (5, r(15, 8)), (8, r(14, 8)), (12, r(6)), (16, r(1))]),
             "head": _up([(3, r(10)), (5, r(-12)), (12, r(-3))]),
             "arm_r": limb("arm_r", [(3, 30, 20), (5, -100, 0), (8, -96, 0), (12, -40), (16, -8)]),
             "arm_l": limb("arm_l", [(3, -20, 20), (5, 42, 26), (8, 38, 26), (14, 5)]),
             "core": _sc([(3, 0.8), (5, 1.2), (12, 1.0)])}
    lunge.update(legs([(3, -4), (5, 17), (8, 15), (13, 4)]))
    many((("atk_charge", 5), ("pounce", 9), ("atk_leap", 12)), 20, lunge, 5)
    clip("dash", 12, {"root": up([(3, 0.2, 0.3), (9, 0.2, 0.3)]), "body": _up([(3, r(15)), (9, r(15))]), "head": _up([(3, r(-10)), (9, r(-10))]),
                      "arm_r": limb("arm_r", [(3, 40, 20), (9, 40, 20)]), "arm_l": limb("arm_l", [(3, 40, 20), (9, 40, 20)]), **legs([(3, 16), (9, 16)])})
    clip("jump", 14, {"root": up([(3, -0.02, 0), (7, 0.5, 0), (11, 0.1, 0)]), "body": _up([(3, r(5)), (7, r(-6)), (11, r(3))]),
                      **both([(3, -10, 5), (7, -60, 50), (11, -15, 10)]), **legs([(3, -4), (7, 16), (11, 2)])})
    # magia no chão (10): sobe com as duas luvas no alto e desce de uma vez
    cg = {"root": up([(5, 0.22, 0), (8, 0.32, 0), (10, 0.08, 0.05), (14, 0.07, 0.05), (18, 0.04, 0.02)]),
          "body": _up([(5, r(-8)), (8, r(-10)), (10, r(9)), (14, r(8)), (18, r(3))]),
          "head": _up([(8, r(-15)), (10, r(12)), (16, r(4))]),
          "core": _sc([(5, 1.2), (8, 1.6), (10, 0.8), (16, 1.0)])}
    cg.update(both([(5, -150, 30), (8, -165, 25), (10, -62, 10), (14, -56, 10), (18, -20)]))
    cg.update(legs([(5, -4), (8, -6), (10, 22), (14, 17), (18, 5)]))
    many((("cast", 10), ("cast_ground", 10), ("summon", 11), ("slam", 8), ("cast_nature", 9)), 22, cg, 10)
    # o perfume fala (7): o vapor incha, as luvas abrem de par em par, a coroa sobe e treme
    sh = {"root": up([(4, 0.02, 0), (7, 0.26, 0), (13, 0.26, 0), (18, 0.08, 0)]),
          "body": _up([(4, r(8)), (7, r(-10)), (10, r(-9, 0, 3)), (13, r(-10, 0, -3)), (18, r(-3))]),
          "head": [(4, r(10), p(-0.02)), (7, r(-16, 20), p(0.12)), (10, r(-14, -20, 4), p(0.14)), (13, r(-16, 20, -4), p(0.12)), (18, r(-4), p(0.02))],
          "core": _sc([(4, 0.8), (7, 1.45), (10, 1.6), (13, 1.45), (18, 1.15)])}
    sh.update(both([(4, -30, -10), (7, -50, 110), (10, -54, 118), (13, -48, 110), (17, -20, 30)]))
    sh.update(legs([(4, -5), (7, 18), (10, 23), (13, 18), (18, 4)]))
    many((("shout", 7), ("roar", 7), ("cast_bolt", 7), ("cast_fire", 8), ("cast_ice", 8), ("cast_holy", 8), ("cast_shadow", 8), ("cast_target", 8),
          ("buff_focus", 8), ("cast_channel", 14)), 22, sh, 7)
    # giro (8): o vestido roda inteiro, a saia abre em roda
    spin = {"root": [(1, Z0, Z0), (4, r(0, -40), p(0.1)), (8, r(0, 150), p(0.18)), (12, r(0, 330), p(0.16)), (15, r(0, 372), p(0.08)), (19, r(0, 360), p(0.02)), (24, r(0, 360), Z0)],
            "body": _up([(4, r(4)), (8, r(6)), (12, r(5)), (19, r(1))]),
            "head": [(8, r(-6), p(0.06)), (14, r(-4), p(0.05)), (20, Z0, Z0)],
            "arm_r": limb("arm_r", [(4, -20, 30), (8, -72, 84), (12, -70, 86), (15, -60, 60), (20, -12, 8)]),
            "arm_l": limb("arm_l", [(4, -20, 30), (8, -60, 80), (12, -58, 82), (15, -40, 50), (20, -8, 6)]),
            "core": _sc([(4, 0.9), (8, 1.3), (15, 1.1), (22, 1.0)])}
    spin.update(legs([(4, -3), (8, 30), (12, 30), (16, 16), (21, 2)]))
    clip("atk_spin", 24, spin)
    clip("atk_sweep", 24, spin)
    # guarda (6): as luvas cruzam à frente, a saia fecha, o vapor recolhe
    br = {"root": up([(6, 0.02, -0.04), (12, 0.02, -0.04)]), "body": _up([(6, r(7)), (12, r(6))]), "head": _up([(6, r(10)), (12, r(10))]),
          "core": _sc([(6, 0.7), (12, 0.72), (16, 1.0)])}
    br.update(both([(6, -78, -34), (12, -76, -34), (15, -30, -10)]))
    br.update(legs([(6, -7), (12, -7)]))
    many((("brace", 6), ("buff_guard", 6), ("block", 8)), 18, br, 6)
    # tranco
    hit = {"root": up([(2, 0.03, -0.1), (5, 0.03, -0.04)]), "body": _up([(2, r(-9, 0, 5)), (5, r(4, 0, -3))]),
           "head": [(2, r(-16, 0, 10), p(0.05)), (5, r(6, 0, -4), Z0)], "core": _sc([(2, 0.6), (6, 1.0)])}
    hit.update(both([(2, -28, 22), (5, 6)]))
    hit.update(legs([(2, 9), (6, -2)]))
    clip("hit", 10, hit)
    # die: o vapor ferve e some; a coroa despenca dentro da gola, as luvas caem, o vestido desaba em roda no chão
    die = {"root": up([(4, 0.12, -0.04), (10, 0.2, 0), (16, 0.04, 0), (21, -0.3, 0), (24, -0.27, 0), (27, -0.3, 0)]),
           "body": _up([(4, r(-8, 0, -4)), (10, r(5, 0, 5)), (16, r(-4, 0, 9)), (21, r(-7, 0, 12)), (24, r(-6, 0, 11)), (27, r(-7, 0, 12))]),
           "head": [(4, r(-14, 10), p(0.1)), (10, r(8, 40, 6), p(0.16)), (14, r(20, 70, 14), p(-0.1)), (19, r(34, 110, 30), p(-0.5, 0.02)), (22, r(30, 116, 30), p(-0.47, 0.02)),
                    (25, r(34, 110, 30), p(-0.5, 0.02))],
           "core": _sc([(4, 1.6), (8, 2.3), (12, 1.5), (17, 0.4), (20, 0.001)]),
           "arm_r": [(4, (-70, 0, -50), Z0), (10, (-30, 0, -20), Z0), (16, (10, 0, -30), (0, 0.4, 0)), (21, (60, 0, -62), (0, 0.72, 0)), (24, (56, 0, -60), (0, 0.7, 0)),
                     (27, (60, 0, -62), (0, 0.72, 0))],
           "arm_l": [(4, (-70, 0, 50), Z0), (10, (-30, 0, 20), Z0), (17, (-20, 0, 40), (0, 0.45, 0)), (22, (-50, 0, 70), (0, 0.78, 0)), (25, (-46, 0, 68), (0, 0.76, 0)),
                     (28, (-50, 0, 70), (0, 0.78, 0))]}
    die.update(legs([(4, 6), (10, -3), (16, 14), (21, 40), (24, 37), (27, 40)]))
    clip("die", 32, die)


BUILDERS = {
    "mob_prima_donna": prima_donna,
    "mob_chorister": chorister,
    "mob_varo": varo,
    "mob_ressoa": ressoa,
}
HUMANOIDS = set(BUILDERS)          # skinned (ck.export_glb); os de baixo são de peças rígidas (lp.export_glb)
BUILDERS["mob_vindima"] = vindima
BUILDERS["mob_thirsty_vine"] = thirsty_vine
BUILDERS["mob_organ_pipe"] = organ_pipe
BUILDERS["mob_sylvare_echo"] = sylvare_echo
BUILDERS["mob_sense_pedestal"] = sense_pedestal
for _k in ("sight", "hearing", "smell", "taste"):
    BUILDERS["mob_sense_pedestal_" + _k] = (lambda k=_k: sense_pedestal("mob_sense_pedestal_" + k, k))
