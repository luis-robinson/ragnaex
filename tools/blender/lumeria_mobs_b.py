"""Ato III, parte 1 (45-50) — Bailarinos do Véu, Galgos de Seda e o Maestro do Coro (design/gdd/ato3-excesso-45-50.md §3).

  mob_veil_dancer    Bailarino do Véu (46; também a forma Bailarino do Convertido): porcelana fina, SEM braços humanos; dos
                     ombros saem fitas e cada uma segura um leque-lâmina (7 varetas, pontas de ouro) deitado, que é o que a
                     câmera alta vê; saia de fitas em duas camadas (tutu aberto + fitas caídas), laço no alto da cabeça
  mob_first_dancer   Primeiro Bailarino (48, elite; também `dancer_escort` da Vessaline): mais alto, coroa de fitas em pé com
                     aro de ouro, quatro leques abertos em leque nas costas (só visual, osso `chest`), saia de três camadas
  mob_silk_hound     Galgo de Seda (46; também a forma Galgo do Convertido): `mob_kit.quadruped(kind="hound")` -> `hound`.
                     Galgo esguio (peito fundo, barriga recolhida, pernas compridas), máscara lisa SEM olhos com a lágrima
                     pintada, crina de fitas de seda do cangote ao lombo, coleira com guizos, rabo-chicote com borla de fita
  mob_parade_alpha   Galgo Alfa do Cortejo (49, bruto): o mesmo galgo maior (`look={"alpha": k}`, k = tamanho; o comum sai em HOUND_SIZE), arreio dourado (peitoral,
                     cilha, manta, canga de dois chifres com guizos), tirantes de fita soltos para trás (o carro vazio) e
                     penacho na cabeça
  mob_choir_maestro  Maestro do Coro (49, elite): a família da Corista (lumeria_bosses.chorister: mesma túnica lilás, capuz,
                     boca costurada, tubos de órgão) em versão regente: fraque de penas em camadas, dragonas de pena, tubos
                     altos nas costas como gola, penacho, batuta-lança na direita (haste creme, ponta de lança de ouro)

Clipes (os nomes que EntityView.clip_for_skill pede para as skills de cada um):
  bailarinos: idle run attack (= atk_dual_a) cast hit die block + atk_dual_b atk_leap (Salto Leque) atk_charge atk_sweep
              atk_spin atk_throw shout (Véu de Fitas) jump dash. `atk_throw` = o GIRO dos leques (cópia do atk_spin com o
              impacto no quadro 7): "fan" está em EntityView.THROW_IDS, então mob_fan_strikes pede atk_throw sem `clip`.
  galgos:     idle run attack hit die + atk_charge (Investida de Seda) atk_leap atk_throw (Laço de Fita: empina e chicoteia
              a cabeça) shout (uivo). A Mordida Sangrenta cai no `attack` (o bote de quad_combat).
  maestro:    idle (batuta em pé) run attack (= atk_thrust) cast hit die block + atk_thrust (Estocada da Batuta) shout
              (Uníssono) cast_ground (Nota Aguda) cast_channel cast_target cast_shadow atk_sweep jump

    import mob_kit; mob_kit.build_all(r"<abs>/assets/models", only=set(lumeria_mobs_b.BUILDERS))
Prévia e conta de chão sem janela: tools/blender/lumeria_mobs_preview.py -- --module=lumeria_mobs_b --out=<pasta ABSOLUTA>.
Escala sugerida (MonsterDef.scale): Bailarino 1,05 · Primeiro Bailarino 1,2 · Galgo 1,0 · Alfa 1,3 · Maestro 1,25.
"""
import math

import bmesh
import bpy
from mathutils import Vector

import chibi_kit as ck
import lowpoly_lib as lp
import build_monsters as bm
import mob_kit as mk
import act2_bosses
import berserker_sets as bs
import lumeria_kit as lk
import lumeria_mobs as lm
import lumeria_bosses as lb

V = Vector

ROSE = (0.86, 0.6, 0.66)            # fita rosa-pó
ROSE_D = (0.6, 0.34, 0.45)
ROSE_L = (0.96, 0.84, 0.84)
DANCERS = {
    "veil": {"leg": 0.16, "torso": 0.02, "bulk": 0.9, "head": 0.25, "arm": 1.15, "tear": lm.ROSE_TEAR,
             "pal": (ROSE, ROSE_D, ROSE_L)},
    "first": {"leg": 0.25, "torso": 0.05, "bulk": 0.94, "head": 0.255, "arm": 1.3, "tear": lm.ROSE_TEAR,
              "pal": ((0.8, 0.45, 0.55), (0.5, 0.24, 0.36), (0.97, 0.88, 0.8))},
}
DANCER_CLIPS = ("atk_dual_b", "atk_leap", "atk_charge", "atk_sweep", "atk_spin", "atk_throw", "shout", "jump", "dash")
# leques abertos para os lados parado e correndo (os golpes ficam como o kit manda)
DANCER_CARRY = {"upper_arm.R": (0, 0, 30), "upper_arm.L": (0, 0, -30), "forearm.R": (-18, 0, 0), "forearm.L": (-18, 0, 0)}
FAN_THROW_IMPACT = 7                # = EntityView.IMPACT_FRAME["atk_throw"]
MAESTRO = {"leg": 0.19, "torso": 0.05, "arm": 1.26, "head": 0.265, "tear": lm.ROSE_TEAR}
MAESTRO_CLIPS = ("atk_thrust", "shout", "cast_ground", "cast_channel", "cast_target", "cast_shadow", "atk_sweep", "jump")
HOUND_CLIPS = ("atk_charge", "atk_leap", "atk_throw", "shout")


# ---------------------------------------------------------------------------
# Bailarinos do Véu
# ---------------------------------------------------------------------------
def _drop_arms(body):
    """Tira os braços do corpo do kit (vértices que pesam mais nos ossos do braço): o Bailarino não tem braços humanos."""
    names = {g.index: g.name for g in body.vertex_groups}
    arm = lambda n: n.startswith(("upper_arm", "forearm", "hand"))
    kill = set()
    for v in body.data.vertices:
        w = sum(g.weight for g in v.groups if arm(names[g.group]))
        if w > 0.5:
            kill.add(v.index)
    bm_ = bmesh.new()
    bm_.from_mesh(body.data)
    bm_.verts.ensure_lookup_table()
    bmesh.ops.delete(bm_, geom=[bm_.verts[i] for i in kill], context="VERTS")
    bm_.to_mesh(body.data)
    bm_.free()


def _fan(name, g, d, w, length, n, M, mats, spread=17.0, tip=True):
    """Leque-lâmina: n varetas em leque a partir de g, eixo d, abrindo no sentido w (plano d-w); cada vareta num plano
    próprio (sem z-fight), pontas de lâmina em ouro claro, varetas-guarda de ouro nas bordas e rebite no pivô."""
    g, d = V(g), V(d).normalized()
    w = (V(w) - d * V(w).dot(d)).normalized()
    nrm = d.cross(w).normalized()
    out = []
    half = (n - 1) / 2.0
    wd = 2.0 * length * 0.8 * math.tan(math.radians(spread) * 0.5) * 1.18
    for i in range(n):
        a = math.radians(spread) * (i - half)
        dr = d * math.cos(a) + w * math.sin(a)
        pw = w * math.cos(a) - d * math.sin(a)
        off = nrm * ((i - half) * 0.006)
        out.append(ck.blade("%s_rib%d" % (name, i), g + dr * (length * 0.08) + off, g + dr * length + off, wd, 0.012, mats[i % len(mats)], pw, 0.8))
        if tip:
            out.append(ck.blade("%s_tip%d" % (name, i), g + dr * (length * 0.84) + off * 1.3, g + dr * (length * 1.1) + off * 1.3, wd * 0.62, 0.014,
                                M["gold2"], pw, 0.35))
        if i in (0, n - 1):
            out.append(ck.tube("%s_guard%d" % (name, i), g + off * 1.6, g + dr * (length * 0.86) + off * 1.6, 0.012, 0.008, M["gold"], 4))
    out.append(ck.ball(name + "_pivot", length * 0.07, g, M["gold2"]))
    return out


def dancer(cid, kind):
    cfg = DANCERS[kind]
    saved = lm._stretch(cfg["leg"], cfg["torso"])
    try:
        return _dancer(cid, kind, cfg)
    finally:
        ck.Z.clear()
        ck.Z.update(saved)


def _dancer(cid, kind, cfg):
    base, M, m = lb._feast_base(cid, cfg)
    rig, body, b, j = base["rig"], base["body"], base["b"], base["j"]
    Z = ck.Z
    first = kind == "first"
    pal = cfg["pal"]
    rose, deep, pale = m("veil", pal[0], 0.8), m("veil2", pal[1], 0.8), m("veil3", pal[2], 0.8)
    steel = m("blade", lm.STEEL, 0.3)
    gold, gold2, glow = M["gold"], M["gold2"], M["glow"]
    _drop_arms(body)
    c, r = V(base["head_c"]), b["head"]
    zc, zw, zn, zp, zu = Z["chest"], Z["waist"], Z["neck"], Z["pelvis"], Z["upper"]
    back = b["chest"] * b["depth"]
    head, chest, hips, skinned = [], [], [], []
    upper = {".R": [], ".L": []}
    fore = {".R": [], ".L": []}
    hands = {".R": [], ".L": []}
    shins = {".R": [], ".L": []}

    # ---------------- cabeça: máscara com a lágrima, aro, laço (ou coroa de fitas) e fitas compridas ----------------
    head += lk.mask(ck, cid + "_mask", c + V((0, -r * 0.76, -r * 0.1)), r * 0.74, M, tears=(1,), tear_len=0.55)
    head.append(lm._ring(cid + "_circlet", c.z + r * 0.42, c.z + r * 0.52, r * 0.93, r * 0.88, gold, 1.0, 14, c.y))
    top = c + V((0, r * 0.05, r * 0.98))
    if first:
        head.append(lm._ring(cid + "_crownband", c.z + r * 0.74, c.z + r * 0.86, r * 0.72, r * 0.6, gold2, 1.0, 14, c.y))
        for i in range(7):                             # fitas em pé, dobradas para fora: coroa que se lê de cima
            a = -math.pi / 2 + math.tau * i / 7
            o_ = V((math.cos(a), math.sin(a), 0))
            p0 = c + o_ * r * 0.62 + V((0, 0, r * 0.78))
            hgt = r * (1.0 if i == 0 else 0.78)
            p1 = p0 + o_ * r * 0.42 + V((0, 0, hgt))
            tang = V((-o_.y, o_.x, 0))
            head.append(ck.blade("%s_crown%d" % (cid, i), p0, p1, r * 0.46, 0.018, pale if i % 2 == 0 else rose, tang, 0.6))
            head.append(ck.ball("%s_crowntip%d" % (cid, i), r * 0.075, p1, gold2))
        head += lm._bow(cid + "_crownbow", c + V((0, r * 0.86, r * 0.5)), (0, 1, 0), r * 0.6, rose, gold2, pale)
    else:
        head += lm._bow(cid + "_topbow", top, (0, -0.3, 0), r * 0.62, rose, gold2, pale)
    for i, sx in enumerate((-1, 1) if not first else (-1, 0, 1)):      # fitas da nuca até a cintura/joelho
        end_z = (zw - 0.02) if not first else (Z["knee"] + 0.2 if sx == 0 else zp)
        head.append(lm._veil("%s_streamer%d" % (cid, i), c + V((sx * r * 0.34, r * 0.9, r * 0.2)), V((sx * 0.24, back + 0.34, end_z)),
                             r * 0.42, r * 0.3, pale if sx == 0 else rose, (sx * 0.05, 0.1, 0), 4, 0.4))

    # ---------------- tronco: faixa do peito, gola, ombros com laço (de onde saem as fitas dos leques) ----------------
    chest.append(lm._ring(cid + "_wrap", zc - 0.035, zu + 0.005, b["chest"] * 1.1, b["upper"] * 1.13, rose))
    chest.append(lm._ring(cid + "_collar", zn - 0.035, zn + 0.02, b["neck"] * 1.9, b["neck"] * 1.45, gold, 0.9))
    zb = zp + 0.07
    rb = b["pelvis"] * 1.1
    hips.append(lm._ring(cid + "_belt", zb - 0.02, zb + 0.025, rb * 1.03, rb * 0.98, gold))
    hips.append(ck.ball(cid + "_beltgem", 0.03, V((0, -rb * 0.87, zb - 0.03)), glow, (0.8, 0.6, 1.5)))
    for s, sx in ((".R", -1), (".L", 1)):
        sh, el, wr = V(j["shoulder" + s]), V(j["elbow" + s]), V(j["wrist" + s])
        chest.append(ck.ball("%s_shoulder%s" % (cid, s[1]), b["arm"] * 1.55, sh + V((-sx * 0.012, 0, 0.0)), gold2 if first else gold, (1.0, 1.0, 0.85)))
        chest += lm._bow("%s_shbow%s" % (cid, s[1]), sh + V((sx * 0.035, 0, 0.05)), (sx, 0, 0.2), 0.15 if first else 0.13, pale, gold2, rose)
        for k, (dy, mt) in enumerate(((-0.022, rose), (0.022, pale))):         # o "braço" são duas fitas
            o_ = V((0, dy, 0))
            upper[s].append(lm._band("%s_armrib%s%d" % (cid, s[1], k), [sh + o_ + V((0, 0, -0.03)), sh.lerp(el, 0.5) + o_ * 1.6 + V((sx * 0.012, 0, 0)), el + o_],
                                     (0.05, 0.062, 0.05), 0.012, mt, (0, 1, 0)))
            fore[s].append(lm._band("%s_forerib%s%d" % (cid, s[1], k), [el + o_, el.lerp(wr, 0.5) + o_ * 1.5 + V((sx * 0.01, 0, 0)), wr + o_ * 0.4],
                                    (0.05, 0.056, 0.036), 0.012, mt, (0, 1, 0)))
        fore[s].append(ck.ball("%s_elbowknot%s" % (cid, s[1]), 0.03, el, gold2))
        # leque-lâmina na ponta da fita: deitado (abre no plano horizontal), apontando para a frente e um pouco para fora
        g = V(ck.hand_center(base, s))
        n = "%s_fan%s" % (cid, s[1])
        hands[s] += _fan(n, g, (sx * 0.16, -1.0, -0.2), (sx, 0.0, 0.26), 0.62 if first else 0.56, 7, M, [M["porc"], rose, steel])
        hands[s].append(lm._veil(n + "_tassel", g + V((0, 0.02, -0.01)), g + V((sx * 0.05, 0.1, -0.3)), 0.05, 0.035, pale, (sx * 0.02, 0.03, 0), 3, 0.3))
        an = V(j["ankle" + s])
        shins[s].append(ck.tube("%s_anklet%s" % (cid, s[1]), an + V((0, 0, 0.035)), an + V((0, 0, 0.065)), b["ankle"] * 1.5, b["ankle"] * 1.4, gold, 8))
        kn = V(j["knee" + s])
        for k in range(2):                             # fitas de sapatilha cruzadas na canela
            t = 0.38 + 0.26 * k
            p = kn.lerp(an, t)
            rr = (b["knee"] + (b["ankle"] - b["knee"]) * t) * 1.12
            shins[s].append(ck.tube("%s_lace%s%d" % (cid, s[1], k), p + V((0, 0, 0.012)), p + V((0, 0, -0.012)), rr, rr, rose, 8))
    ck.armor_piece(body, rig, cid + "_slippers", "boots", rose, 0.008, 0.012)

    # ---------------- saia de fitas: tutu aberto (quadril) + fitas caídas (pesos do corpo) ----------------
    zk = Z["knee"]
    hips += lm._petals(cid + "_tutu_a", 7, zb - 0.005, zb - 0.1, rb * 0.98, rb * 2.75, 0.24, rose, phase=0.0, mid=0.62)
    hips += lm._petals(cid + "_tutu_b", 7, zb + 0.008, zb - 0.045, rb * 1.0, rb * 2.35, 0.2, pale, phase=0.5, mid=0.62)
    skinned += lm._petals(cid + "_rib_a", 6, zb - 0.01, zk + 0.02, rb * 0.98, rb * 1.7, 0.12, deep, phase=0.25, mid=0.55)
    skinned += lm._petals(cid + "_rib_b", 6, zb - 0.01, zk + 0.16, rb * 1.0, rb * 1.9, 0.1, pale, phase=0.75, mid=0.55)
    if first:
        hips += lm._petals(cid + "_tutu_c", 9, zb + 0.016, zb + 0.0, rb * 1.02, rb * 1.75, 0.15, gold, phase=0.2, mid=0.6)
        skinned += lm._petals(cid + "_rib_c", 5, zb - 0.01, Z["ankle"] + 0.2, rb * 0.96, rb * 1.5, 0.09, rose, phase=0.5, mid=0.5)
        # quatro leques abertos nas costas (só visual): cauda de pavão atrás dos ombros, lida de frente e de cima
        yb = back + 0.07
        root = V((0, yb, zu - 0.06))
        chest.append(ck.ball(cid + "_backknot", 0.06, root, gold2, (1.2, 0.6, 1.2)))
        for i, a in enumerate((-64, -24, 24, 64)):
            ar = math.radians(a)
            d = V((math.sin(ar), 0.2, math.cos(ar)))
            w = V((math.cos(ar), 0.0, -math.sin(ar)))
            chest += _fan("%s_backfan%d" % (cid, i), root + d * 0.1 + V((0, 0.012 * i, 0)), d, w, 0.56, 5, M, [M["porc"], rose, pale], spread=13.0)

    ck._rigid(bs._outward(head), rig, "head")
    ck._rigid(bs._outward(chest), rig, "chest")
    ck._rigid(bs._outward(hips), rig, "hips")
    for s in (".R", ".L"):
        ck._rigid(bs._outward(upper[s]), rig, "upper_arm" + s)
        ck._rigid(bs._outward(fore[s]), rig, "forearm" + s)
        ck._rigid(bs._outward(hands[s]), rig, "hand" + s)
        ck._rigid(bs._outward(shins[s]), rig, "shin" + s)
    lk.skinned(ck, base, bs._outward(skinned))

    # ---------------- clipes ----------------
    ck.mob_clips(rig, None, "dagger", None, extra_keep=DANCER_CLIPS)          # attack = atk_dual_a (os dois leques)
    ck._retimed_copy(rig, "atk_spin", "atk_throw", FAN_THROW_IMPACT)          # Leques em Três/Quatro Tempos: o giro
    lm._hips_scale(rig, Z["pelvis"] / 0.38)
    act2_bosses.carry(rig, DANCER_CARRY)
    for s in ("R", "L"):
        act2_bosses.clear_ground(rig, {"*": 0.03, "die": -0.1}, "hand." + s, ("%s_fan%s" % (cid, s),), front=True)
    lm._join(cid, rig, cid + "_body")
    return rig


def veil_dancer(cid="mob_veil_dancer"):
    return dancer(cid, "veil")


def first_dancer(cid="mob_first_dancer"):
    return dancer(cid, "first")


# ---------------------------------------------------------------------------
# Maestro do Coro
# ---------------------------------------------------------------------------
def choir_maestro(cid="mob_choir_maestro"):
    return lb._stretched(_maestro, cid, MAESTRO)


def _feather_row(name, n, c, r0, r1, z0, z1, w, mats, a0, a1, depth=0.85):
    """Fileira de penas (lâminas) em arco de a0 a a1 (rad; +Y = costas), da raiz (r0, z0) à ponta (r1, z1)."""
    out = []
    for i in range(n):
        a = a0 + (a1 - a0) * (i / max(1, n - 1))
        dr = V((math.cos(a), math.sin(a) * depth, 0))
        tang = V((-math.sin(a), math.cos(a), 0))
        out.append(ck.blade("%s%d" % (name, i), c + dr * r0 + V((0, 0, z0)), c + dr * r1 + V((0, 0, z1)), w, 0.016, mats[i % len(mats)], tang, 0.55))
    return out


def _maestro(cid, cfg):
    base, M, m = lb._feast_base(cid, cfg)
    rig, b, j = base["rig"], base["b"], base["j"]
    Z = ck.Z
    robe, deep, pale = m("robe", lb.ROBE, 0.85), m("robe_d", lb.ROBE_D, 0.85), m("robe_l", lb.ROBE_L, 0.8)
    thread, note, cream = m("thread", lb.VELVET, 0.7), m("note", lb.NOTE, 0.3, 2.0), m("cream", lb.CREAM, 0.6)
    gold, gold2, ink = M["gold"], M["gold2"], M["ink"]
    c, r_ = V(base["head_c"]), b["head"]
    zc, zw, zn, zp, zu = Z["chest"], Z["waist"], Z["neck"], Z["pelvis"], Z["upper"]
    back = b["chest"] * b["depth"]
    front = -back
    head, chest, hips, skinned = [], [], [], []
    arms = {".R": [], ".L": []}
    hands = {".R": [], ".L": []}
    O = V((0, 0, 0))

    # ---------------- cabeça: a máscara de boca costurada e o capuz da Corista; no lugar da ponta caída, penacho ----------------
    s_ = r_ * 0.74
    mc = c + V((0, -r_ * 0.76, -r_ * 0.1))
    head += lk.mask(ck, cid + "_mask", mc, s_, M, tears=(1,), tear_len=0.5)
    zm = -0.5 * s_
    surf = lambda x: -0.34 * s_ * math.sqrt(max(0.0, 1.0 - (x / (0.82 * s_)) ** 2 - (zm / s_) ** 2))
    head.append(ck.tube(cid + "_mouth", mc + V((-0.34 * s_, surf(0.34 * s_) - 0.006, zm)), mc + V((0.34 * s_, surf(0.34 * s_) - 0.006, zm)), 0.009, 0.009, ink, 5))
    for i in range(-2, 3):
        x = i * 0.14 * s_
        d = 0.045 * s_ * (1 if i % 2 else -1)
        head.append(ck.tube("%s_stitch%d" % (cid, i), mc + V((x - d, surf(x) - 0.014, zm + 0.11 * s_)), mc + V((x + d, surf(x) - 0.014, zm - 0.11 * s_)), 0.0095, 0.0095, thread, 4))
    hc = c + V((0, r_ * 0.28, r_ * 0.1))
    head.append(lb._open_cap(cid + "_hood", r_ * 1.13, hc, c, deep, r_ * 0.05))
    head.append(lm._ring(cid + "_hood_trim", c.z + r_ * 0.4, c.z + r_ * 0.52, r_ * 0.98, r_ * 0.94, gold2, 1.0, 14, c.y - r_ * 0.02))
    for i in range(5):                                 # penacho: leque de penas no alto, tombado para trás
        a = (i - 2) * 0.32
        p0 = hc + V((math.sin(a) * r_ * 0.3, r_ * 0.1, r_ * 1.0))
        p1 = p0 + V((math.sin(a) * r_ * 0.95, r_ * 0.75, r_ * (1.15 - 0.16 * abs(i - 2))))
        head.append(ck.blade("%s_plume%d" % (cid, i), p0, p1, r_ * 0.44, 0.018, pale if i % 2 == 0 else robe, (math.cos(a), 0, -math.sin(a) * 0.4), 0.6))
    head.append(ck.ball(cid + "_plume_clasp", r_ * 0.2, hc + V((0, r_ * 0.08, r_ * 1.04)), gold2, (1.3, 0.9, 0.8)))
    head += lm._bow(cid + "_hood_bow", hc + V((0, r_ * 1.02, -r_ * 0.35)), (0, 1, 0), r_ * 0.5, pale, gold2, pale)

    # ---------------- tronco: casaca lilás, garganta de tubos (a da Corista), tubos altos nas costas, dragonas de pena ----------------
    chest.append(lm._ring(cid + "_coat", zw - 0.03, zu + 0.01, b["waist"] * 1.3, b["upper"] * 1.16, deep))
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
    for i in range(-2, 3):                             # gola de tubos nas costas: sobem atrás dos ombros (lida de cima e de costas)
        x = i * 0.085
        zt = zn + 0.2 + 0.1 * abs(i)
        yb = back + 0.06 - 0.012 * abs(i)
        chest.append(lb._flat(ck.tube("%s_bpipe%d" % (cid, i), (x, yb, zc - 0.02), (x, yb + 0.03, zt), 0.036, 0.04, gold if i % 2 else gold2, 6)))
        chest.append(ck.ball("%s_bpipe_top%d" % (cid, i), 1.0, V((x, yb + 0.03, zt + 0.003)), note, (0.034, 0.034, 0.014)))
    chest.append(ck.box(cid + "_bpipe_chest", (0.44, 0.07, 0.06), (0, back + 0.05, zc - 0.02), gold, 0.012))
    for s, sx in ((".R", -1), (".L", 1)):
        sh = V((sx * (b["shoulder"] + 0.015), 0.0, zu + 0.035))
        chest.append(ck.ball("%s_epaulet%s" % (cid, s[1]), 1.0, sh, gold2, (0.11, 0.1, 0.035)))
        a_mid = 0.0 if sx > 0 else math.pi
        chest += _feather_row("%s_epfeather%s" % (cid, s[1]), 5, sh, 0.05, 0.25, 0.0, -0.1, 0.11, [pale, robe], a_mid - 1.15, a_mid + 1.15, 1.0)
        wr, el = V(j["wrist" + s]), V(j["elbow" + s])
        chest.append(ck.tube("%s_sleeve%s" % (cid, s[1]), V(j["shoulder" + s]) + V((0, 0, -0.02)), V(j["shoulder" + s]).lerp(el, 0.45), b["arm"] * 1.45, b["arm"] * 1.3, deep, 8))
        arms[s].append(ck.tube("%s_glove%s" % (cid, s[1]), el.lerp(wr, 0.1), wr.lerp(el, -0.03), b["elbow"] * 1.2, b["wrist"] * 1.28, cream, 8))
        arms[s].append(ck.tube("%s_cuff%s" % (cid, s[1]), el.lerp(wr, 0.02), el.lerp(wr, 0.22), b["elbow"] * 1.5, b["elbow"] * 1.7, gold, 8))
        arms[s] += _feather_row("%s_cufffeather%s" % (cid, s[1]), 4, el.lerp(wr, 0.12), 0.03, 0.12, 0.0, 0.1, 0.07, [pale], a_mid - 1.3, a_mid + 1.3, 1.0)
        hands[s].append(ck.ball("%s_fist%s" % (cid, s[1]), b["hand"] * 1.12, V(ck.hand_center(base, s)), cream, (1, 1, 1.1)))
    zb = zp + 0.07
    rb = b["pelvis"] * 1.1
    hips.append(lm._ring(cid + "_belt", zb - 0.02, zb + 0.03, rb * 1.12, rb * 1.07, gold))
    hips.append(ck.ball(cid + "_beltgem", 0.034, V((0, -rb * 0.95, zb)), M["glow"], (0.8, 0.6, 1.5)))
    # túnica da Corista por baixo (aberta na frente) e o fraque de penas: três fileiras sobrepostas atrás, do cinto à panturrilha
    skinned.append(lm._skirt(cid + "_robe", zw - 0.01, Z["ankle"] + 0.07, b["waist"] * 1.25, rb * 1.7, robe, 16, 0.03))
    skinned.append(lm._skirt(cid + "_peplum", zb + 0.012, zb - 0.14, rb * 1.12, rb * 1.6, deep, 14, 0.04, 0.7))
    lo, hi = math.pi / 2 - 1.25, math.pi / 2 + 1.25        # arco de trás (+Y)
    zk = Z["knee"]
    skinned += _feather_row(cid + "_tail_lo", 7, O, rb * 1.3, rb * 2.35, zb - 0.2, Z["ankle"] + 0.16, 0.2, [deep, robe], lo + 0.25, hi - 0.25)
    skinned += _feather_row(cid + "_tail_mid", 8, O, rb * 1.25, rb * 2.2, zb - 0.1, zk - 0.02, 0.19, [robe, pale], lo + 0.1, hi - 0.1)
    skinned += _feather_row(cid + "_tail_hi", 9, O, rb * 1.18, rb * 1.95, zb - 0.01, zk + 0.22, 0.17, [pale, deep, gold], lo, hi)
    ck.armor_piece(base["body"], rig, cid + "_boots", "boots", ink, 0.012, 0.014)

    # ---------------- batuta-lança (mão direita, em pé como um cajado) ----------------
    g = V(ck.hand_center(base, ".R"))
    up = V((-0.22, -0.12, 1.0)).normalized()
    n = cid + "_baton"
    t0, t1 = g - up * 0.62, g + up * 0.92
    side = up.cross(V((0, 1, 0))).normalized()
    hands[".R"] += [ck.tube(n + "_stick", t0, t1, 0.02, 0.014, cream, 6), ck.ball(n + "_pommel", 0.045, t0, gold2),
                    ck.tube(n + "_grip", g - up * 0.09, g + up * 0.09, 0.028, 0.026, gold, 6),
                    ck.tube(n + "_socket", t1 - up * 0.03, t1 + up * 0.07, 0.03, 0.02, gold, 6),
                    ck.blade(n + "_head", t1 + up * 0.04, t1 + up * 0.42, 0.13, 0.03, gold2, side, 0.3),
                    ck.ball(n + "_note", 0.04, t1 + up * 0.0, note, (1, 1, 1)),
                    lm._veil(n + "_ribbon", t1 - up * 0.02 + V((0, 0.02, 0)), t1 - up * 0.02 + V((0.05, 0.16, -0.36)), 0.07, 0.05, pale, (0.02, 0.04, 0), 3, 0.3)]

    ck._rigid(bs._outward(head), rig, "head")
    ck._rigid(bs._outward(chest), rig, "chest")
    ck._rigid(bs._outward(hips), rig, "hips")
    for s in (".R", ".L"):
        ck._rigid(bs._outward(arms[s]), rig, "forearm" + s)
        ck._rigid(bs._outward(hands[s]), rig, "hand" + s)
    lk.skinned(ck, base, bs._outward(skinned))

    ck.mob_clips(rig, "staff", None, "atk_thrust", extra_keep=MAESTRO_CLIPS)
    lm._hips_scale(rig, Z["pelvis"] / 0.38)
    act2_bosses.clear_ground(rig, {"*": 0.03, "die": -0.1}, "hand.R", (cid + "_baton",), front=True)
    act2_bosses.clear_ground(rig, {"die": -0.02}, "head", (cid + "_plume",))
    lm._join(cid, rig, cid + "_body")
    return rig


# ---------------------------------------------------------------------------
# Galgos de Seda (peças rígidas no rig de quadrúpede do mob_kit)
# ---------------------------------------------------------------------------
HIP = 0.74
SPINE = [((0, 0.5, HIP), 0.12), ((0, 0.2, HIP + 0.07), 0.105), ((0, -0.2, HIP - 0.05), 0.19), ((0, -0.4, HIP + 0.02), 0.15),
         ((0, -0.56, HIP + 0.22), 0.08), ((0, -0.67, HIP + 0.38), 0.068)]
HOUND_SIZE = 0.85                   # o galgo comum sai com o lombo a ~0,65 m (escala 1,0 no catálogo)
LEAN = 0.7                          # o corpo é mais alto que largo
HOUND_HEAD = (0, -0.76, HIP + 0.43)


def _top(y):
    """Altura da linha de cima do corpo (lombo, cernelha, cangote) em y."""
    pts = sorted(((p[1], p[2] + r_) for p, r_ in SPINE))
    if y <= pts[0][0]:
        return pts[0][1]
    for (y0, z0), (y1, z1) in zip(pts, pts[1:]):
        if y <= y1:
            return z0 + (z1 - z0) * (y - y0) / (y1 - y0)
    return pts[-1][1]


def _hoop(name, y0, y1, zc_, r0, r1, material, segs=12):
    """Cinta em volta do corpo (eixo Y), achatada como o tronco."""
    o = ck.tube(name, (0, y0, zc_), (0, y1, zc_), r0, r1, material, segs)
    for v in o.data.vertices:
        v.co.x *= LEAN + 0.06
    return o


def hound(cid, fur=lm.PORC, dark=ROSE, light=ROSE_L, look=None):
    """Galgo de Seda. look = {"alpha": k}: Galgo Alfa do Cortejo (k vezes maior, arreio dourado, tirantes, penacho)."""
    look = look or {}
    k = float(look.get("alpha", HOUND_SIZE))
    alpha = "alpha" in look
    S = lambda p: tuple(x * k for x in p)
    bones = mk.pivots(body=S((0, 0, 0.5)), head=S((0, -0.64, HIP + 0.36)),
                      leg_fr=S((0.11, -0.34, HIP - 0.1)), leg_fl=S((-0.11, -0.34, HIP - 0.1)),
                      leg_br=S((0.11, 0.38, HIP - 0.08)), leg_bl=S((-0.11, 0.38, HIP - 0.08)))
    th = S((0, 0.56, HIP + 0.0))
    arm = lp.make_armature("rig_" + cid, dict(bones, tail=(th, (th[0], th[1] + 0.38, th[2] + 0.06), "body")))
    m = lambda n, col, rough=0.7, em=0.0: ck.mat("m_%s_%s" % (cid, n), col, rough, em)
    porc, mask_m, rose, deep, pale = m("porc", fur, 0.45), m("mask", lm.MASK, 0.3), m("silk", dark, 0.8), m("silk2", ROSE_D, 0.8), m("silk3", light, 0.8)
    gold, gold2, ink, glow = m("gold", lm.OLD_GOLD, 0.4), m("gold2", lm.BRIGHT_GOLD, 0.35), m("ink", lm.INK, 0.6), m("tear", lm.ROSE_TEAR, 0.3, 2.2)
    M = {"gold": gold2, "ink": ink}
    parts = []
    add = lambda o, bone: parts.append((o, bone))

    # ---------------- tronco: anca, lombo recolhido, peito fundo, pescoço comprido ----------------
    body = mk.skin_body("body", SPINE, [(i, i + 1) for i in range(len(SPINE) - 1)], porc)
    for v in body.data.vertices:
        v.co.x *= LEAN
    add(body, "body")
    add(mk.blob("chestkeel", 0.13, (0, -0.3, HIP - 0.17), porc, (0.62, 1.3, 0.75)), "body")

    # ---------------- cabeça: crânio estreito e a máscara lisa sem olhos (focinho comprido), lágrima do lado esquerdo ----------------
    hc = V(HOUND_HEAD)
    add(mk.blob("skull", 0.105, hc, porc, (0.82, 1.15, 0.9)), "head")
    mlen = 0.28
    msk = mk.blob("mask", 0.115, hc + V((0, -0.05, 0.005)), mask_m, (0.8, 1.0, 0.82))
    for v in msk.data.vertices:
        d = hc.y - 0.05 - v.co.y
        if d > 0:                                      # a metade da frente estica num focinho que afina e cai um pouco
            t = min(1.0, d / 0.115)
            kk = 1.0 - 0.52 * t ** 1.3
            v.co.x *= kk
            v.co.z = hc.z + (v.co.z - hc.z) * kk - 0.07 * t * t
            v.co.y = hc.y - 0.05 - t * mlen * (0.75 + 0.25 * t)
    add(msk, "head")
    add(mk.blob("mask_rim", 0.118, hc + V((0, 0.03, 0.0)), gold, (0.86, 0.3, 0.93)), "head")
    tip = hc + V((0, -0.05 - mlen, -0.068))
    add(ck.ball("nose", 0.022, tip + V((0, -0.004, 0.006)), gold2, (1.0, 0.8, 0.8)), "head")
    for sx in (-1, 1):                                 # risco da boca (tinta) e orelhas de fita deitadas para trás
        add(ck.tube("mouth%d" % sx, tip + V((sx * 0.016, 0.02, -0.02)), tip + V((sx * 0.05, 0.2, -0.015)), 0.006, 0.006, ink, 4), "head")
        add(ck.blade("ear%d" % sx, hc + V((sx * 0.06, 0.03, 0.07)), hc + V((sx * 0.17, 0.33, 0.06)), 0.11, 0.016, rose, (0, 0.3, 1), 0.5), "head")
        add(ck.blade("ear_in%d" % sx, hc + V((sx * 0.068, 0.05, 0.07)), hc + V((sx * 0.172, 0.27, 0.062)), 0.06, 0.02, pale, (0, 0.3, 1), 0.5), "head")
    tx, ty, tz = 0.066, hc.y - 0.2, hc.z - 0.005        # a lágrima pintada (lado esquerdo do bicho = +X)
    add(ck.ball("tear", 0.016, (tx, ty, tz), glow, (0.5, 0.9, 2.4)), "head")
    add(ck.ball("tear_drop", 0.024, (tx - 0.004, ty - 0.004, tz - 0.05), glow, (0.5, 1.0, 1.25)), "head")
    add(ck.ball("tear_rim", 0.024, (tx - 0.008, ty - 0.004, tz - 0.05), gold, (0.5, 1.25, 1.5)), "head")

    # ---------------- crina de seda: fitas do cangote ao lombo, caindo dos dois lados + fileira de cima ----------------
    n_st = 9 if alpha else 8
    for i in range(n_st):
        y = -0.62 + i * 0.105
        zt = _top(y) - 0.012
        mt = (rose, pale, deep)[i % 3]
        ln = (1.15 if alpha else 1.0) * (1.0 - 0.07 * i)
        for sx in (-1, 1):
            pts = [V((sx * 0.012, y, zt)), V((sx * 0.085, y + 0.04, zt - 0.02 * ln)), V((sx * 0.15, y + 0.11, zt - 0.14 * ln)), V((sx * 0.17, y + 0.2, zt - 0.3 * ln)),
                   V((sx * 0.15, y + 0.27, zt - 0.44 * ln))]
            add(lm._band("mane%d_%d" % (i, sx), pts, (0.06, 0.08, 0.085, 0.07, 0.02), 0.014, mt, (0, 1, 0)), "body")
        if i % 2 == 0:
            pts = [V((0, y, zt)), V((0, y + 0.1, _top(y + 0.1) + 0.045)), V((0, y + 0.24, _top(y + 0.24) + 0.04)), V((0, y + 0.36, _top(y + 0.36) + 0.012))]
            add(lm._band("crest%d" % i, pts, (0.07, 0.1, 0.085, 0.03), 0.014, (pale, rose, deep)[i % 3], flat=True), "body")
    for sx in (-1, 1):                                 # topete: duas fitas da nuca
        add(lm._band("forelock%d" % sx, [hc + V((sx * 0.02, 0.08, 0.085)), hc + V((sx * 0.08, 0.24, 0.1)), hc + V((sx * 0.1, 0.42, -0.02))],
                     (0.06, 0.075, 0.025), 0.014, pale, flat=True), "head")

    # ---------------- coleira com guizos ----------------
    n0, n1 = V(SPINE[4][0]), V(SPINE[5][0])
    ax = (n1 - n0).normalized()
    cc = n0.lerp(n1, 0.15)
    col = ck.tube("collar", cc - ax * 0.03, cc + ax * 0.03, 0.098, 0.09, gold, 12)
    for v in col.data.vertices:
        v.co.x *= LEAN + 0.08
    add(col, "body")
    for i, bx in enumerate((-1, 0, 1) if not alpha else (-2, -1, 0, 1, 2)):
        a = bx * 0.5
        p = cc + V((math.sin(a) * 0.075, -math.cos(a) * 0.07 - 0.02, -0.075 - 0.02 * (bx == 0)))
        for o in lk.bell(ck, "bell%d" % i, p, 0.034, M):
            add(o, "body")

    # ---------------- pernas compridas (cada uma rígida no seu osso): ombro/coxa, canela fina, pata de ouro ----------------
    for bone, sx, front in (("leg_fr", 1, True), ("leg_fl", -1, True), ("leg_br", 1, False), ("leg_bl", -1, False)):
        x = sx * 0.105
        if front:
            top, elb, wr, paw = V((x, -0.33, HIP - 0.08)), V((x, -0.31, 0.4)), V((x, -0.35, 0.16)), V((x, -0.37, 0.045))
            add(mk.blob("shoulder_" + bone, 0.1, top + V((0, 0, -0.03)), porc, (0.55, 0.95, 1.45)), bone)
            add(ck.tube("leg0_" + bone, top + V((0, 0, -0.1)), elb, 0.05, 0.036, porc, 8), bone)
            add(ck.tube("leg1_" + bone, elb, wr, 0.036, 0.028, porc, 8), bone)
            add(ck.tube("leg2_" + bone, wr, paw + V((0, 0.01, 0.01)), 0.028, 0.03, porc, 8), bone)
            add(ck.tube("anklet_" + bone, wr + V((0, 0, 0.03)), wr + V((0, 0, -0.01)), 0.038, 0.038, gold, 8), bone)
        else:
            top, stf, hock, paw = V((x, 0.38, HIP - 0.06)), V((x, 0.27, 0.43)), V((x, 0.5, 0.25)), V((x, 0.47, 0.045))
            add(mk.blob("haunch_" + bone, 0.125, top + V((0, -0.02, -0.04)), porc, (0.56, 1.05, 1.4)), bone)
            add(ck.tube("leg0_" + bone, top + V((0, -0.03, -0.12)), stf, 0.062, 0.042, porc, 8), bone)
            add(ck.tube("leg1_" + bone, stf, hock, 0.042, 0.03, porc, 8), bone)
            add(ck.ball("hock_" + bone, 0.033, hock, porc), bone)
            add(ck.tube("leg2_" + bone, hock, paw + V((0, 0.01, 0.01)), 0.03, 0.03, porc, 8), bone)
            add(ck.tube("anklet_" + bone, hock.lerp(paw, 0.55), hock.lerp(paw, 0.75), 0.04, 0.04, gold, 8), bone)
        add(mk.blob("paw_" + bone, 0.045, paw + V((0, -0.02, 0.0)), gold2, (0.9, 1.45, 0.75)), bone)

    # ---------------- rabo-chicote com borla de fitas ----------------
    tp = [((0, 0.54, HIP + 0.0), 0.04), ((0, 0.7, HIP - 0.1), 0.03), ((0, 0.84, HIP - 0.19), 0.024), ((0, 0.96, HIP - 0.2), 0.019), ((0, 1.04, HIP - 0.13), 0.015)]
    add(mk.skin_body("whip", tp, [(0, 1), (1, 2), (2, 3), (3, 4)], porc), "tail")
    te = V(tp[-1][0])
    add(ck.ball("whip_ring", 0.026, te, gold2), "tail")
    for i, (dx, mt) in enumerate(((-0.07, rose), (0.0, pale), (0.07, deep))):
        add(lm._band("whip_silk%d" % i, [te, te + V((dx * 0.6, 0.09, 0.02)), te + V((dx, 0.19, -0.03)), te + V((dx * 1.2, 0.27, -0.12))],
                     (0.05, 0.075, 0.065, 0.02), 0.014, mt, flat=True), "tail")

    if alpha:
        _alpha_harness(add, M, gold, gold2, rose, deep, pale, glow, hc)

    objs = [o for o, _b in parts]
    bs._outward(objs)
    if k != 1.0:
        for o in objs:
            for v in o.data.vertices:
                v.co *= k
    by_bone = {}                                       # uma malha por osso (75-110 peças soltas viravam um nó cada no GLB)
    for o, bone in parts:
        by_bone.setdefault(bone, []).append(o)
    parts = [(ck._join(objs_, "hound_" + bone), bone) for bone, objs_ in by_bone.items()]
    mk.finish(arm, parts)
    bm.mob_actions(arm, quadruped=True)
    mk.quad_motion(arm, "hound")
    mk.quad_combat(arm, "hound")
    _hound_gestures(arm)
    _plant(arm, HOUND_CLIPS + ("attack", "hit"))
    return arm


def _plant(arm, clips):
    """Patas no chão nos golpes: o rig tem pernas de um osso só, então agachar/empinar enterra as patas. Em cada quadro em que
    alguma peça (fora o rabo) desce de z = 0, o corpo sobe o que falta (chave em `body` loc Y); nomes e tempos não mudam."""
    ad = arm.animation_data
    pb = arm.pose.bones["body"]
    objs = [o for o in arm.children if o.type == "MESH" and o.parent_bone != "tail"]
    tracks = {t.name: t for t in ad.nla_tracks}
    for t in ad.nla_tracks:
        t.mute = True
    for name in clips:
        act = tracks[name].strips[0].action
        ad.action = act
        if getattr(ad, "action_slot", None) is None and getattr(act, "slots", None):
            ad.action_slot = act.slots[0]
        fix = {}
        for f in range(1, int(round(act.frame_range[1])) + 1):
            bpy.context.scene.frame_set(f)
            bpy.context.view_layer.update()
            low = min((o.matrix_world @ v.co).z for o in objs for v in o.data.vertices)
            fix[f] = (pb.location.y, max(0.0, -low))
        if max(d for _y, d in fix.values()) > 0.004:
            for f, (y, d) in fix.items():
                pb.location.y = y + d
                pb.keyframe_insert("location", index=1, frame=f)
        ad.action = None
    for t in ad.nla_tracks:
        t.mute = False
    for b in arm.pose.bones:
        b.rotation_euler = (0, 0, 0)
        b.location = (0, 0, 0)
    bpy.context.scene.frame_set(1)


def _alpha_harness(add, M, gold, gold2, rose, deep, pale, glow, hc):
    """Arreio do Galgo Alfa: peitoral, cilha e sobrecilha de ouro, manta rosa com filete, canga de dois chifres com guizos,
    tirantes de fita soltos para trás (puxava o carro alegórico) e penacho de fitas na cabeça."""
    zc_ = HIP - 0.05
    add(_hoop("girth", -0.25, -0.17, zc_, 0.2, 0.2, gold), "body")
    add(_hoop("girth2", 0.14, 0.2, HIP + 0.065, 0.118, 0.115, gold), "body")
    add(mk.blob("breastplate", 0.13, (0, -0.47, HIP - 0.02), gold2, (0.8, 0.5, 1.1)), "body")
    add(ck.ball("breastgem", 0.035, (0, -0.535, HIP - 0.0), glow, (0.9, 0.6, 1.4)), "body")
    # manta: faixa por cima do lombo, de um lado ao outro
    for nm, y0, wd, mt, lift in (("pad", -0.02, 0.36, deep, 0.012), ("pad_trim", -0.02, 0.42, gold, 0.004)):
        pts = []
        for i in range(7):
            a = math.pi * (i / 6.0)
            rr = 0.155
            pts.append(V((math.cos(a) * rr * (LEAN + 0.12), y0, HIP + 0.02 + math.sin(a) * (rr + lift) - 0.06 * (i in (0, 6)))))
        add(lm._band(nm, pts, [wd] * 7, 0.016, mt, (0, 1, 0)), "body")
    for sx in (-1, 1):
        # canga: dois chifres de ouro que sobem da cernelha, guizo na ponta
        p0 = V((sx * 0.09, -0.3, _top(-0.3) - 0.03))
        p1 = p0 + V((sx * 0.16, 0.06, 0.3))
        for o in bs._tusk(ck, "hame%d" % sx, p0, p1, V((sx * 0.06, 0, 0.0)), 0.034, gold2, 4, 6):
            add(o, "body")
        for o in lk.bell(ck, "hamebell%d" % sx, p1 + V((0, 0, -0.01)), 0.04, M):
            add(o, "body")
        # argola da cilha e o tirante de fita que cai para trás e arrasta um pouco
        rg = V((sx * 0.155, -0.2, zc_ - 0.02))
        add(ck.tube("tracering%d" % sx, rg + V((-sx * 0.01, 0, 0)), rg + V((sx * 0.02, 0, 0)), 0.04, 0.04, gold2, 8), "body")
        pts = [rg, rg + V((sx * 0.05, 0.28, -0.07)), rg + V((sx * 0.08, 0.6, -0.1)), rg + V((sx * 0.1, 0.88, -0.17)), rg + V((sx * 0.13, 1.1, -0.3))]
        add(lm._band("trace%d" % sx, pts, (0.06, 0.075, 0.075, 0.07, 0.05), 0.014, rose if sx < 0 else pale, (0, 0, 1)), "body")
        add(ck.ball("tracehook%d" % sx, 0.035, pts[-1], gold2), "body")
    # penacho: três fitas em pé no alto da cabeça
    for i, (dx, hh, mt) in enumerate(((-0.05, 0.26, rose), (0.0, 0.36, pale), (0.05, 0.26, deep))):
        p0 = hc + V((dx * 0.4, 0.04, 0.08))
        add(ck.blade("crestplume%d" % i, p0, p0 + V((dx, 0.14, hh)), 0.1, 0.016, mt, (1, 0, 0), 0.55), "head")
    add(ck.ball("crestclasp", 0.035, hc + V((0, 0.035, 0.095)), gold2), "head")
    add(ck.blade("browplate", hc + V((0, -0.02, 0.092)), hc + V((0, -0.22, 0.06)), 0.075, 0.014, gold2, (1, 0, 0), 0.3), "head")


def _hound_gestures(arm):
    """Gestos de skill dos galgos (eixos do rig: corpo loc Y = cima, Z = frente, X- = empina; pernas X- = para a frente;
    cabeça X- = sobe; rabo X+ = sobe). Impacto nos quadros de EntityView.IMPACT_FRAME.
    atk_charge = Investida de Seda (5): agacha e dispara rente ao chão; atk_leap (12): salto alto e bote na queda;
    atk_throw = Laço de Fita (7): empina, joga a cabeça para trás e chicoteia para a frente; shout: senta e uiva."""
    mk._drop_clips(arm, HOUND_CLIPS)
    z = (0, 0, 0)
    r = lambda x=0.0, y=0.0, zz=0.0: (x, y, zz)
    p = lambda up=0.0, fwd=0.0: (0, up, fwd)
    e = 16
    lp.add_action(arm, "atk_charge", {
        "body": [(1, z, z), (3, r(8), p(-0.09, -0.1)), (5, r(-4), p(0.03, 0.3)), (8, r(-2), p(0.02, 0.26)), (11, r(5), p(-0.02, 0.12)), (14, r(1), p(0, 0.03)), (e, z, z)],
        "head": [(1, z, z), (3, r(14), z), (5, r(-8), z), (7, r(16, 0, 10), z), (9, r(14, 0, -8), z), (12, r(2), z), (e, z, z)],
        "leg_fr": [(1, z, z), (3, r(22), z), (5, r(-62), z), (8, r(-50), z), (11, r(-8), z), (e, z, z)],
        "leg_fl": [(1, z, z), (3, r(18), z), (5, r(-54), z), (8, r(-44), z), (11, r(-4), z), (e, z, z)],
        "leg_br": [(1, z, z), (3, r(-24), z), (5, r(54), z), (8, r(44), z), (11, r(-8), z), (e, z, z)],
        "leg_bl": [(1, z, z), (3, r(-24), z), (5, r(48), z), (8, r(38), z), (11, r(-6), z), (e, z, z)],
        "tail": [(1, z, z), (3, r(18), z), (5, r(-22), z), (8, r(-16, 0, 8), z), (11, r(10), z), (e, z, z)],
    }, e, loop=False)
    e = 22
    lp.add_action(arm, "atk_leap", {
        "body": [(1, z, z), (5, r(12), p(-0.11, -0.12)), (8, r(-22), p(0.34, 0.1)), (10, r(-6), p(0.42, 0.2)), (12, r(16), p(0.04, 0.26)), (15, r(8), p(-0.03, 0.16)), (19, r(1), p(0, 0.04)),
                 (e, z, z)],
        "head": [(1, z, z), (5, r(16), z), (8, r(-22), z), (10, r(-6), z), (12, r(26), z), (14, r(18, 0, 12), z), (16, r(16, 0, -10), z), (19, r(2), z), (e, z, z)],
        "leg_fr": [(1, z, z), (5, r(24), z), (8, r(-66), z), (10, r(-72), z), (12, r(-18), z), (15, r(-6), z), (e, z, z)],
        "leg_fl": [(1, z, z), (5, r(20), z), (8, r(-58), z), (10, r(-64), z), (12, r(-14), z), (15, r(-4), z), (e, z, z)],
        "leg_br": [(1, z, z), (5, r(-28), z), (8, r(50), z), (10, r(58), z), (12, r(-12), z), (15, r(-4), z), (e, z, z)],
        "leg_bl": [(1, z, z), (5, r(-28), z), (8, r(44), z), (10, r(52), z), (12, r(-10), z), (15, r(-2), z), (e, z, z)],
        "tail": [(1, z, z), (5, r(20), z), (8, r(-30), z), (10, r(-24), z), (12, r(16, 0, 10), z), (16, r(4, 0, -8), z), (e, z, z)],
    }, e, loop=False)
    e = 20
    lp.add_action(arm, "atk_throw", {
        "body": [(1, z, z), (4, r(-20), p(0.1, -0.08)), (6, r(-22), p(0.12, -0.09)), (7, r(6), p(0.0, 0.12)), (10, r(5), p(0.0, 0.1)), (15, r(1), p(0, 0.02)), (e, z, z)],
        "head": [(1, z, z), (4, r(-34, 0, 22), z), (6, r(-38, 0, 26), z), (7, r(24, 0, -18), z), (10, r(18, 0, -10), z), (15, r(2), z), (e, z, z)],
        "leg_fr": [(1, z, z), (4, r(-44), z), (6, r(-48), z), (7, r(-6), z), (10, r(-4), z), (e, z, z)],
        "leg_fl": [(1, z, z), (4, r(-34), z), (6, r(-38), z), (7, r(-4), z), (10, r(-2), z), (e, z, z)],
        "leg_br": [(1, z, z), (4, r(16), z), (7, r(-6), z), (11, r(-2), z), (e, z, z)],
        "leg_bl": [(1, z, z), (4, r(16), z), (7, r(-6), z), (11, r(-2), z), (e, z, z)],
        "tail": [(1, z, z), (4, r(40, 0, -20), z), (7, r(16, 0, 30), z), (10, r(8, 0, -14), z), (15, r(0, 0, 6), z), (e, z, z)],
    }, e, loop=False)
    e = 26
    lp.add_action(arm, "shout", {
        "body": [(1, z, z), (6, r(-12), p(0.0, -0.06)), (10, r(-14), p(0.0, -0.07)), (19, r(-12), p(0.0, -0.06)), (23, r(-3), p(0, -0.01)), (e, z, z)],
        "head": [(1, z, z), (6, r(-46), z), (10, r(-52, 0, 6), z), (13, r(-50, 0, -6), z), (16, r(-52, 0, 5), z), (19, r(-46, 0, -4), z), (23, r(-8), z), (e, z, z)],
        "leg_fr": [(1, z, z), (6, r(14), z), (19, r(14), z), (23, r(3), z), (e, z, z)],
        "leg_fl": [(1, z, z), (6, r(14), z), (19, r(14), z), (23, r(3), z), (e, z, z)],
        "leg_br": [(1, z, z), (6, r(18), z), (19, r(18), z), (23, r(4), z), (e, z, z)],
        "leg_bl": [(1, z, z), (6, r(18), z), (19, r(18), z), (23, r(4), z), (e, z, z)],
        "tail": [(1, z, z), (6, r(40), z), (11, r(44, 0, 14), z), (15, r(40, 0, -14), z), (19, r(38, 0, 8), z), (23, r(8), z), (e, z, z)],
    }, e, loop=False)


def silk_hound(cid="mob_silk_hound"):
    return mk.quadruped(cid, lm.PORC, ROSE, ROSE_L, "hound")


def parade_alpha(cid="mob_parade_alpha"):
    return mk.quadruped(cid, (0.95, 0.9, 0.8), (0.78, 0.46, 0.54), (0.97, 0.88, 0.8), "hound", look={"alpha": 1.1})


BUILDERS = {
    "mob_veil_dancer": veil_dancer,
    "mob_first_dancer": first_dancer,
    "mob_choir_maestro": choir_maestro,
}
HUMANOIDS = set(BUILDERS)          # skinned (ck.export_glb); os galgos são de peças rígidas (lp.export_glb)
BUILDERS["mob_silk_hound"] = silk_hound
BUILDERS["mob_parade_alpha"] = parade_alpha
