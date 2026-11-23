"""Ato III — Lumeria (lendários do nível 50, GDD design/gdd/ato3-lendarios-50.md): motivos comuns dos conjuntos
`<pre>_<b>50` (ACT3_SETS de cada <classe>_sets.py): máscara de porcelana com lágrima pintada, lanterna, fita de seda,
pires empilhados, guizo, frasco, taça e as luvas/botas da família.

Materiais: `tint` (cor do item: marfim-porcelana), `tint2` (destaque da build: seda, fitas, véu, capuz), `tint_glow`
(lágrima, chama das lanternas, líquido dos frascos: GearCatalog pinta por conjunto), e fixos `m_lum_porcelain`,
`m_lum_gold` (ouro velho), `m_lum_glass`, `m_lum_ink` (olhos das máscaras) e `m_lum_silk` (seda negra).
Tudo devolve LISTAS de malhas soltas: quem chama passa por ck._rigid(bs._outward(...), rig, osso).
"""
import math
from mathutils import Vector, Quaternion

IVORY = (0.98, 0.97, 0.94)
OLD_GOLD = (0.69, 0.54, 0.24)
GLASS = (0.74, 0.88, 0.95)
INK = (0.1, 0.08, 0.12)
SILK = (0.1, 0.09, 0.13)


def lum_mats(ck, mats):
    import berserker_sets as bs
    return {"t": mats["tint"], "t2": mats["tint2"], "glow": bs._tint_glow(ck), "porc": ck.mat("m_lum_porcelain", IVORY, 0.35),
            "gold": ck.mat("m_lum_gold", OLD_GOLD, 0.4), "glass": ck.mat("m_lum_glass", GLASS, 0.15, 0.4),
            "ink": ck.mat("m_lum_ink", INK, 0.6), "silk": ck.mat("m_lum_silk", SILK, 0.5),
            "dark": mats["dark"], "metal": mats["metal"], "leather": mats["leather"], "bs": bs}


def place(objs, c, facing=(0, -1, 0)):
    """Leva peças modeladas na origem olhando para -Y (frente do boneco) até c, viradas para facing."""
    f = Vector(facing).normalized()
    q = Quaternion((0, 0, 1), math.pi) if f.y > 0.999 else Vector((0, -1, 0)).rotation_difference(f)
    c = Vector(c)
    for o in objs:
        for v in o.data.vertices:
            v.co = q @ v.co + c
    return objs


def mask(ck, name, c, s, M, facing=(0, -1, 0), kind="oval", tears=(1,), eyes=True, wide=1.0, tall=1.0, tear_len=0.5, rim=True, eye_z=0.16):
    """Máscara de porcelana (meia-altura s) com olhos de tinta e lágrima(s) pintada(s) em tint_glow.
    kind: oval | bird (bico comprido) | wolf (focinho, orelhas, sorriso de ouro) ; tears = lados com lágrima (+1 = esquerda
    do boneco, +X) ; eyes=False = máscara cega (troféu) ; wide/tall esticam o oval ; eye_z = altura dos olhos (fração de s)."""
    V = Vector
    wx, dy, sz = 0.82 * wide * s, 0.34 * s, s * tall
    porc, gold, ink, glow = M["porc"], M["gold"], M["ink"], M["glow"]

    def surf(x, z, lift=0.0):
        k = 1.0 - (x / wx) ** 2 - (z / sz) ** 2
        return -dy * math.sqrt(max(k, 0.0)) - lift

    face = ck.quad_sphere(name + "_face", 1.0, (0, 0, 0), cuts=3)
    for v in face.data.vertices:
        v.co = V((v.co.x * wx, v.co.y * dy, v.co.z * sz))
    face.data.materials.append(porc)
    out = [face]
    if rim:
        out.append(ck.ball(name + "_rim", 1.0, (0, s * 0.05, 0), gold, (wx + s * 0.1, dy * 0.6, sz + s * 0.1)))
    ex, ez = 0.44 * wx, eye_z * sz
    for sx in (-1, 1):
        x = sx * ex
        if eyes:
            out.append(ck.ball(name + "_eye%d" % sx, s * 0.19, (x, surf(x, ez) + s * 0.03, ez), ink, (1.3, 0.5, 0.66)))
        else:                            # olho fechado: um risco de ouro
            out.append(ck.ball(name + "_lid%d" % sx, s * 0.14, (x, surf(x, ez) + s * 0.03, ez), gold, (1.3, 0.5, 0.2)))
        if sx in tears:
            z0 = ez - s * 0.16
            z1 = z0 - s * tear_len
            zm = (z0 + z1) * 0.5
            # lágrima acesa com filete de ouro velho por trás: lê sobre a porcelana branca seja qual for a cor do brilho
            out.append(ck.ball(name + "_tear%d" % sx, s * 0.075, (x, surf(x, zm) + s * 0.0, zm), glow, (0.8, 0.6, tear_len / 0.15)))
            out.append(ck.ball(name + "_drop%d" % sx, s * 0.115, (x, surf(x, z1) + s * 0.0, z1), glow, (1.0, 0.6, 1.25)))
            out.append(ck.ball(name + "_tear_rim%d" % sx, s * 0.075, (x, surf(x, zm) + s * 0.035, zm), gold, (1.5, 0.5, tear_len / 0.15 + 0.3)))
            out.append(ck.ball(name + "_drop_rim%d" % sx, s * 0.115, (x, surf(x, z1) + s * 0.035, z1), gold, (1.4, 0.5, 1.55)))
    if kind == "bird":                   # bico comprido para a frente e para baixo, ponta de ouro; sobrancelha em penas
        b0, b1, b2 = V((0, surf(0, -0.1 * s) + s * 0.1, -0.1 * s)), V((0, -s * 0.95, -s * 0.42)), V((0, -s * 1.5, -s * 0.78))
        out += [ck.tube(name + "_beak0", b0, b1, s * 0.3, s * 0.17, porc, 8), ck.tube(name + "_beak1", b1, b2, s * 0.17, s * 0.012, gold, 8)]
        for sx in (-1, 1):
            out.append(ck.blade(name + "_plume%d" % sx, (sx * wx * 0.55, -dy * 0.3, sz * 0.55), (sx * wx * 1.5, s * 0.25, sz * 1.25), s * 0.5, s * 0.08, porc, (0.3, 0, 1), 0.4))
            out.append(ck.blade(name + "_plume_g%d" % sx, (sx * wx * 0.7, -dy * 0.2, sz * 0.4), (sx * wx * 1.6, s * 0.3, sz * 0.75), s * 0.34, s * 0.07, gold, (0.3, 0, 1), 0.4))
    elif kind == "wolf":                 # focinho, nariz de tinta, orelhas em pé e o sorriso de ouro subindo pelas bochechas
        out += [ck.ball(name + "_snout", 1.0, (0, -s * 0.5, -s * 0.24), porc, (s * 0.4, s * 0.62, s * 0.34)),
                ck.ball(name + "_nose", s * 0.13, (0, -s * 1.1, -s * 0.14), ink, (1.2, 0.8, 0.8)),
                ck.ball(name + "_brow", s * 0.1, (0, surf(0, sz * 0.55) + s * 0.01, sz * 0.55), glow, (0.8, 0.5, 1.5))]
        for sx in (-1, 1):
            out += [ck.blade(name + "_ear%d" % sx, (sx * wx * 0.5, s * 0.02, sz * 0.72), (sx * wx * 1.08, s * 0.2, sz * 2.05), s * 0.72, s * 0.14, porc, (1, 0, 0), 0.35),
                    ck.blade(name + "_ear_in%d" % sx, (sx * wx * 0.55, -s * 0.06, sz * 0.84), (sx * wx * 1.0, s * 0.1, sz * 1.72), s * 0.36, s * 0.12, gold, (1, 0, 0), 0.35),
                    ck.tube(name + "_grin%d" % sx, (sx * s * 0.06, -s * 1.02, -s * 0.36), (sx * s * 0.36, -s * 0.62, -s * 0.34), s * 0.04, s * 0.04, gold, 5),
                    ck.tube(name + "_grin_up%d" % sx, (sx * s * 0.36, -s * 0.62, -s * 0.34), (sx * wx * 0.74, surf(sx * wx * 0.74, -sz * 0.16) - s * 0.02, -sz * 0.16), s * 0.04, s * 0.015, gold, 5)]
    return place(out, c, facing)


def lantern(ck, name, c, s, M, hang=None, segs=6):
    """Lanterna (meia-altura s) centrada em c: chama em tint_glow dentro de gaiola de ouro velho. hang = ponto de onde pende."""
    V = Vector
    c = V(c)
    gold = M["gold"]
    out = [ck.ball(name + "_flame", s * 0.6, c, M["glow"], (1, 1, 1.3)),
           ck.tube(name + "_cap", c + V((0, 0, s * 0.72)), c + V((0, 0, s * 1.25)), s * 0.78, s * 0.14, gold, segs),
           ck.tube(name + "_base", c + V((0, 0, -s * 0.98)), c + V((0, 0, -s * 0.74)), s * 0.5, s * 0.74, gold, segs),
           ck.ball(name + "_knob", s * 0.17, c + V((0, 0, s * 1.33)), gold)]
    for k in range(4):
        a = math.tau * (k + 0.5) / 4
        o = V((math.cos(a) * s * 0.66, math.sin(a) * s * 0.66, 0))
        out.append(ck.tube(name + "_post%d" % k, c + o + V((0, 0, -s * 0.76)), c + o + V((0, 0, s * 0.76)), s * 0.07, s * 0.07, gold, 4))
    if hang is not None:
        out.append(ck.tube(name + "_hang", V(hang), c + V((0, 0, s * 1.4)), max(s * 0.06, 0.006), max(s * 0.06, 0.006), gold, 4))
    return out


def silk(ck, name, p0, p1, wdir, w0, w1, material, sway=(0, 0, 0), n=4, thick=0.014, bs=None):
    """Fita de seda de p0 a p1 (n trechos), ondulando por sway no meio; largura de w0 a w1 no sentido wdir."""
    import berserker_sets as _bs
    p0, p1, sway = Vector(p0), Vector(p1), Vector(sway)
    pts, widths = [], []
    for i in range(n + 1):
        k = i / n
        pts.append(p0.lerp(p1, k) + sway * math.sin(math.pi * k * 1.5))
        widths.append(w0 + (w1 - w0) * k)
    return _bs._ribbon(ck, name, pts, wdir, widths, thick, material)


def saucers(ck, name, c, r, n, M, step=0.045, shrink=0.2, tilt=(0, 0, 1), mats=None):
    """Pires empilhados (ombreira): n discos que abrem para cima, do maior (embaixo) ao menor, com filete de ouro."""
    V = Vector
    c = V(c)
    up = V(tilt).normalized()
    out = []
    for k in range(n):
        rk = r * (1.0 - shrink * k)
        base = c + up * (k * step)
        m_ = (mats or [M["porc"], M["t"]])[k % 2]
        out += [ck.tube(name + "_dish%d" % k, base, base + up * step * 0.66, rk * 0.7, rk, m_, 12),
                ck.tube(name + "_lip%d" % k, base + up * step * 0.36, base + up * step * 0.56, rk * 1.045, rk * 1.045, M["gold"], 12)]
    return out


def bell(ck, name, c, s, M):
    """Guizo de ouro."""
    c = Vector(c)
    return [ck.ball(name, s, c, M["gold"]), ck.ball(name + "_slit", s * 0.4, c + Vector((0, -s * 0.72, -s * 0.5)), M["ink"], (1.6, 0.6, 0.5))]


def vial(ck, name, top, s, M):
    """Frasco de vidro pendurado em top: líquido aceso (tint_glow) embaixo, rolha de ouro."""
    V = Vector
    top = V(top)
    return [ck.tube(name + "_glass", top + V((0, 0, -s * 2.3)), top + V((0, 0, -s * 0.5)), s * 0.9, s * 0.62, M["glass"], 6),
            ck.ball(name + "_liquid", s * 0.98, top + V((0, 0, -s * 2.2)), M["glow"], (1, 1, 0.95)),
            ck.tube(name + "_neck", top + V((0, 0, -s * 0.5)), top, s * 0.4, s * 0.4, M["gold"], 6)]


def goblet(ck, name, top, s, M):
    """Taça de ouro pendurada de boca para cima em top (ponto da borda)."""
    V = Vector
    c = V(top) + V((0, 0, -s * 1.0))
    return [ck.tube(name + "_cup", c, c + V((0, 0, s * 1.0)), s * 0.3, s * 0.75, M["gold"], 8),
            ck.tube(name + "_stem", c + V((0, 0, -s * 0.8)), c, s * 0.14, s * 0.14, M["gold"], 5),
            ck.tube(name + "_foot", c + V((0, 0, -s * 0.95)), c + V((0, 0, -s * 0.78)), s * 0.55, s * 0.2, M["gold"], 8),
            ck.ball(name + "_wine", s * 0.6, c + V((0, 0, s * 0.92)), M["glow"], (1, 1, 0.3))]


def limbs(ck, base, mats, P, M, kind, bells=False, ribbon=0.0, mirror=False, boots_m=None, fist_m=None):
    """Luvas e botas. kind: plate (manopla, cotoveleira-pires, joelheira de porcelana com lágrima) | cloth (manga larga com
    punho de ouro) | leather (braçadeira com duas cintas). bells = guizo no punho e no tornozelo; ribbon = comprimento das
    duas fitas (tint2) que caem do punho; mirror = placa de vidro-espelho no dorso da braçadeira."""
    V = Vector
    rig, body, b, j = base["rig"], base["body"], base["b"], base["j"]
    t, t2, gold, porc, glow, bs = M["t"], M["t2"], M["gold"], M["porc"], M["glow"], M["bs"]
    for s, sx in ((".R", -1), (".L", 1)):
        tag = s.replace(".", "_")
        el, wr = V(j["elbow" + s]), V(j["wrist" + s])
        if kind == "plate":
            g = [ck.tube(P + "gloves_cuff" + tag, el.lerp(wr, 0.2), wr + V((0, 0, 0.01)), 0.086, 0.12, t, 12),
                 ck.tube(P + "gloves_rim" + tag, wr + V((0, 0, 0.0)), wr + V((0, 0, 0.03)), 0.128, 0.128, gold, 12),
                 ck.tube(P + "gloves_saucer" + tag, el + V((sx * 0.02, 0.02, -0.035)), el + V((sx * 0.02, 0.02, 0.015)), 0.07, 0.12, porc, 10),
                 ck.tube(P + "gloves_saucer_lip" + tag, el + V((sx * 0.02, 0.02, 0.012)), el + V((sx * 0.02, 0.02, 0.026)), 0.124, 0.124, gold, 10),
                 ck.ball(P + "gloves_tear" + tag, 0.024, el.lerp(wr, 0.62) + V((sx * 0.112, -0.02, 0)), glow, (0.6, 1.0, 1.7))]
        elif kind == "cloth":
            g = [ck.tube(P + "gloves_sleeve" + tag, el.lerp(wr, 0.2), wr + V((0, 0, -0.012)), 0.074, 0.114, t, 12),
                 ck.tube(P + "gloves_cuff" + tag, wr + V((0, 0, 0.012)), wr + V((0, 0, -0.02)), 0.119, 0.119, gold, 12),
                 ck.ball(P + "gloves_tear" + tag, 0.02, el.lerp(wr, 0.7) + V((sx * 0.1, -0.02, 0)), glow, (0.6, 1.0, 1.6))]
        else:
            g = [ck.tube(P + "gloves_bracer" + tag, el.lerp(wr, 0.22), wr + V((0, 0, 0.005)), 0.07, 0.084, t, 10),
                 ck.tube(P + "gloves_band0" + tag, el.lerp(wr, 0.26), el.lerp(wr, 0.38), 0.08, 0.082, gold, 10),
                 ck.tube(P + "gloves_band1" + tag, el.lerp(wr, 0.84), el.lerp(wr, 0.97), 0.088, 0.09, gold, 10)]
        if mirror:
            g += [ck.box(P + "gloves_mirror" + tag, (0.02, 0.1, 0.12), el.lerp(wr, 0.58) + V((sx * 0.092, 0, 0)), M["glass"], 0.01),
                  ck.box(P + "gloves_mirror_frame" + tag, (0.016, 0.125, 0.145), el.lerp(wr, 0.58) + V((sx * 0.084, 0, 0)), gold, 0.01)]
        if bells:
            g += bell(ck, P + "gloves_bell" + tag, wr + V((sx * 0.105, -0.01, 0.02)), 0.032, M)
        if ribbon > 0:
            for i, sy in enumerate((-1, 1)):
                p0 = wr + V((sx * 0.09, sy * 0.035, 0.03))
                p1 = p0 + V((sx * 0.09 * ribbon, sy * 0.07 * ribbon + 0.03, -0.3 * ribbon - i * 0.05))
                g.append(silk(ck, P + "gloves_ribbon%d%s" % (i, tag), p0, p1, (1, sy * 0.6, 0), 0.075, 0.1, t2, (sx * 0.03, 0, 0), 3, 0.012))
        ck._rigid(bs._outward(g), rig, "forearm" + s)
        hc = V(ck.hand_center(base, s))
        fm = fist_m or (t if kind == "plate" else (porc if kind == "cloth" else M["leather"]))
        fist = [ck.ball(P + "gloves_fist" + tag, b["hand"] * (1.42 if kind == "plate" else 1.18), hc, fm, (1, 1, 1.1))]
        if kind == "plate":
            fist.append(ck.box(P + "gloves_knuckle" + tag, (0.085, 0.03, 0.03), hc + V((sx * 0.01, -0.066, 0.025)), gold, 0.008))
        ck._rigid(fist, rig, "hand" + s)
    ck.armor_piece(body, rig, P + "boots_shell", "boots", boots_m or t, 0.026 if kind == "plate" else 0.02, 0.015)
    for s, sx in ((".R", -1), (".L", 1)):
        tag = s.replace(".", "_")
        kn, an = V(j["knee" + s]), V(j["ankle" + s])
        k = [ck.tube(P + "boots_cuff" + tag, an + V((0, 0, 0.06)), an + V((0, 0, 0.096)), 0.09, 0.096, gold, 12)]
        if kind == "plate":              # joelheira: pires de porcelana de frente, com a lágrima no meio
            k += [ck.tube(P + "boots_knee" + tag, kn + V((0, -0.062, 0.01)), kn + V((0, -0.105, 0.01)), 0.086, 0.05, porc, 10),
                  ck.tube(P + "boots_knee_lip" + tag, kn + V((0, -0.058, 0.01)), kn + V((0, -0.07, 0.01)), 0.092, 0.092, gold, 10),
                  ck.ball(P + "boots_knee_tear" + tag, 0.024, kn + V((0, -0.11, 0.0)), glow, (0.7, 0.6, 1.5))]
        else:
            k.append(ck.ball(P + "boots_tear" + tag, 0.02, an + V((0, -0.088, 0.075)), glow, (0.7, 0.6, 1.5)))
        if bells:
            k += bell(ck, P + "boots_bell" + tag, an + V((sx * 0.1, 0.0, 0.085)), 0.03, M)
        ck._rigid(bs._outward(k), rig, "shin" + s)


def skinned(ck, base, objs):
    """Peça comprida de pano que cruza ossos (véu, estola, tiras até o pé): pesos do corpo, como as saias."""
    for o in objs:
        ck._smooth(o.data)
        ck.transfer_weights(o, base["body"], base["rig"])
    return objs
