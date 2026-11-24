"""Ato III — armas DESPERTAS do nível 50 (onda 4, GDD design/gdd/ato3-lendarios-50.md §3.3/§8.1) do Paladino, Berserker e
Bispo. Uma função por estilo `<pre>_<b>50`; cada uma faz TODAS as armas da build (wpn_main_<tipo>_<estilo> e, quando a build
empunha duas, wpn_off_<tipo>_<estilo>), 1 malha por arma, presa à mão. Só no kit extra kit_<classe>_<sexo>_a3.glb
(chibi_kit.A3_WEAPONS, lido de ACT3_WEAPONS de cada <classe>_sets.py); o kit principal não ganha malha.

Empunhadura e tamanho = os das armas do 30/35 da build (mesmo eixo, mesma mão, mesmo alcance: os clipes e a conta de chão do
kit principal foram feitos com elas). Motivos = os do conjunto 50 (lumeria_kit): porcelana, ouro velho, lágrima/chama em
`tint_glow`, lanterna, espelho, guizo, seda em `tint2`. `tint` = cor do item (marfim).

As peças de espada/maça/cetro são modeladas num quadro LOCAL (origem = mão, +Z = ao longo da arma, +X = lado, +Y = costas
da lâmina) e levadas ao lugar no fim (`_finish`); machados e garras usam os construtores de axe_kit / berserker_sets.
"""
import math

from mathutils import Vector

AXIS_1H = (0, -0.55, 0.83)          # eixo das armas de mão do kit (paladin_sets.build_weapon / build_mace)
AXIS_STAFF = (-0.22, -0.12, 1.0)    # cetro em pé, como o cajado (bishop_sets.build_scepter)
Z = Vector((0, 0, 1))
X = Vector((1, 0, 0))
Y = Vector((0, 1, 0))


def _mats(ck, mats):
    import lumeria_kit as lk
    return lk.lum_mats(ck, mats)


def _down(axis):
    """Para onde a gravidade puxa, no quadro local da arma (fitas penduradas)."""
    q = Z.rotation_difference(Vector(axis).normalized())
    return (q.inverted() @ Vector((0, 0, -1))).normalized()


def _finish(ck, base, parts, name, side_tag, axis, flat=()):
    """Normais para fora, quadro local -> mão, 1 malha com o nome dado, peso 1 no osso da mão. flat = peças facetadas."""
    import berserker_sets as bs
    g = Vector(ck.hand_center(base, side_tag))
    q = Z.rotation_difference(Vector(axis).normalized())
    flat_ids = {id(o) for o in flat}
    for o in parts:
        for v in o.data.vertices:
            v.co = q @ v.co + g
        if id(o) not in flat_ids:
            ck._smooth(o.data)
    obj = ck._join(bs._outward(parts), name)
    ck.skin_rigid(obj, base["rig"], "hand" + side_tag)
    return obj


def _ring(ck, name, c, u, v, rad, r, material, n=14, a0=0.0, a1=math.tau):
    """Aro (ou arco de a0 a a1) de raio rad no plano (u, v), feito de tubos."""
    c, u, v = Vector(c), Vector(u), Vector(v)
    out = []
    for i in range(n):
        b0, b1 = a0 + (a1 - a0) * i / n, a0 + (a1 - a0) * (i + 1) / n
        out.append(ck.tube("%s%d" % (name, i), c + (u * math.cos(b0) + v * math.sin(b0)) * rad, c + (u * math.cos(b1) + v * math.sin(b1)) * rad, r, r, material, 6))
    return out


def _tails(ck, name, p, down, material, length, width, spread=0.05, n=2, wdir=(1, 0, 0)):
    """n fitas de seda penduradas de p (caem no sentido da gravidade, abrindo um pouco para os lados)."""
    import lumeria_kit as lk
    p, down = Vector(p), Vector(down)
    w = Vector(wdir)
    out = []
    for i in range(n):
        k = (i - (n - 1) / 2.0)
        end = p + down * length * (1.0 - 0.14 * i) + w * k * spread * 2.2
        out.append(lk.silk(ck, "%s%d" % (name, i), p + w * k * spread * 0.6, end, w, width, width * 1.25, material, w * k * 0.03 + Vector((0, 0.025, 0)), 3))
    return out


def _tear(ck, name, c, s, M, face):
    """Lágrima pintada (filete + gota) em tint_glow na face `face` (+1/-1 no Y local), descendo pelo -Z da arma."""
    c = Vector(c)
    return [ck.ball(name + "_t", s, c + Y * face * 0.004, M["glow"], (0.8, 0.55, 2.3)),
            ck.ball(name + "_d", s * 1.3, c + Y * face * 0.004 - Z * s * 2.6, M["glow"], (1.0, 0.6, 1.25))]


def _hilt(ck, n, M, G, wraps, grip_m):
    out = [ck.tube(n + "grip", -Z * G, Z * G, 0.026, 0.026, grip_m, 8)]
    for k in range(wraps):
        z = -G + (k + 0.5) * (2 * G) / wraps
        out.append(ck.tube(n + "wrap%d" % k, Z * (z - 0.008), Z * (z + 0.008), 0.03, 0.03, M["gold"], 8))
    return out


def _shaft_1h(ck, n, M, material, top=0.46):
    """Cabo da maça de uma mão (medidas de paladin_sets.build_mace): pomo, três voltas de ouro, gola."""
    out = [ck.tube(n + "shaft", -Z * 0.13, Z * top, 0.03, 0.028, material, 8), ck.ball(n + "pommel", 0.045, -Z * 0.15, M["gold"]),
           ck.tube(n + "collar", Z * 0.38, Z * 0.43, 0.05, 0.05, M["gold"], 10)]
    for k in range(3):
        out.append(ck.tube(n + "wrap%d" % k, Z * (-0.08 + k * 0.07), Z * (-0.06 + k * 0.07), 0.034, 0.034, M["gold"], 8))
    return out


# ---------------------------------------------------------------------------
# Paladino
# ---------------------------------------------------------------------------
def pal_g50(ck, base, mats, style="pal_g50"):
    """Guardião — Vigília da Lágrima Dourada. Espada (Lâmina Justa Desperta): guarda de pires empilhados, pomo-lanterna aceso,
    lâmina com filete de porcelana e UMA lágrima. Maça (Baluarte Desperto): cabeça-lanterna entre flanges de porcelana sobre pires."""
    import lumeria_kit as lk
    import paladin_sets as ps
    M = _mats(ck, mats)
    t, t2, gold, glow, metal = M["t"], M["t2"], M["gold"], M["glow"], M["metal"]
    dn = _down(AXIS_1H)
    O = Vector((0, 0, 0))
    n = "w_%s_s_" % style
    G = 0.09
    p = [ps._blade(ck, n + "blade", O, Z, X, G + 0.03, 0.62, 0.056, 0.047, 0.14, 0.016, 0.0, metal)]
    for sg in (-1, 1):                   # filete de porcelana na base da lâmina e a lágrima que escorre dele
        p.append(ps._blade(ck, n + "inlay%d" % sg, Y * sg * 0.013, Z, X, G + 0.06, 0.3, 0.03, 0.02, 0.06, 0.005, 0.0, t))
        p.append(ps._blade(ck, n + "core%d" % sg, Y * sg * 0.014, Z, X, G + 0.42, 0.24, 0.012, 0.007, 0.05, 0.004, 0.0, glow))
        p.append(ck.ball(n + "drop%d" % sg, 0.026, Z * (G + 0.4) + Y * sg * 0.012, glow, (1.0, 0.55, 1.35)))
    p += lk.saucers(ck, n + "guard", Z * (G - 0.005), 0.125, 2, M, 0.04, 0.3)          # pires: o maior embaixo, abrindo para a lâmina
    p += _hilt(ck, n, M, G, 3, t2)
    p += lk.lantern(ck, n + "pom", -Z * (G + 0.075), 0.05, M)
    p += _tails(ck, n + "rib", Z * (G - 0.02) + Y * 0.02, dn, t2, 0.24, 0.05, 0.06)
    out = [_finish(ck, base, p, "wpn_main_sword_%s" % style, ".R", AXIS_1H)]
    # maça-lanterna
    n = "w_%s_m_" % style
    hc = Z * 0.56
    p = _shaft_1h(ck, n, M, t2, 0.44)
    p += lk.saucers(ck, n + "dish", Z * 0.375, 0.105, 2, M, 0.036, 0.26)
    p += [ck.ball(n + "flame", 0.088, hc, glow, (1, 1, 1.3)),
          ck.tube(n + "roof", hc + Z * 0.12, hc + Z * 0.2, 0.115, 0.03, gold, 10),
          ck.tube(n + "roof_rim", hc + Z * 0.105, hc + Z * 0.13, 0.122, 0.122, t, 10),
          ck.ball(n + "knob", 0.034, hc + Z * 0.225, glow, (1, 1, 1.3))]
    for k in range(6):
        a = math.tau * k / 6
        p.append(ck._flange(n + "flange%d" % k, hc, Z, X * math.cos(a) + Y * math.sin(a), 0.19, 0.27, 0.03, t))
    p += _tails(ck, n + "rib", Z * 0.385, dn, t2, 0.2, 0.045, 0.05)
    out.append(_finish(ck, base, p, "wpn_main_mace_%s" % style, ".R", AXIS_1H))
    return out


def pal_c50(ck, base, mats, style="pal_c50"):
    """Cruzado — Cortejo do Juízo Claro. Montante (Julgamento Desperto): espelho redondo na guarda, barbatanas de porcelana,
    lâmina com a quebra em diagonal filetada de ouro. Malho (Baluarte Desperto): tonel de porcelana com um espelho em cada face."""
    import lumeria_kit as lk
    import paladin_sets as ps
    M = _mats(ck, mats)
    t, t2, gold, glow, metal, porc = M["t"], M["t2"], M["gold"], M["glow"], M["metal"], M["porc"]
    dn = _down(AXIS_1H)
    O = Vector((0, 0, 0))
    n = "w_%s_s_" % style
    G = 0.2
    st = G + 0.03
    p = [ps._blade(ck, n + "blade", O, Z, X, st, 0.95, 0.087, 0.075, 0.2, 0.016, 0.0, metal)]
    gc = Z * (G + 0.015)
    for sg in (-1, 1):
        fy = Y * sg
        p.append(ps._blade(ck, n + "ricasso%d" % sg, fy * 0.013, Z, X, st + 0.07, 0.26, 0.06, 0.04, 0.09, 0.006, 0.0, t))     # meia-máscara: porcelana na base
        p.append(ck.tube(n + "seam%d" % sg, Vector((-0.07, sg * 0.02, st + 0.2)), Vector((0.07, sg * 0.02, st + 0.44)), 0.009, 0.009, gold, 5))    # a quebra em diagonal
        p.append(ps._blade(ck, n + "core%d" % sg, fy * 0.014, Z, X, st + 0.46, 0.44, 0.013, 0.008, 0.07, 0.004, 0.0, glow))
        p += lk.mirror(ck, n + "mirror%d" % sg, gc + fy * 0.03, 0.09, M, (0, sg, 0), 0, sg < 0)
    p.append(ck.tube(n + "guard", gc - X * 0.25, gc + X * 0.25, 0.024, 0.02, gold, 8))
    for sx in (-1, 1):                   # barbatanas (as ombreiras do conjunto) subindo ao lado da lâmina
        p += [ck.blade(n + "fin%d" % sx, gc + X * sx * 0.1, gc + X * sx * 0.3 + Z * 0.17, 0.085, 0.018, porc, (0, 0, 1), 0.4),
              ck.ball(n + "guard_end%d" % sx, 0.034, gc + X * sx * 0.26, t2)]
    p += _hilt(ck, n, M, G, 5, t2)
    pp = -Z * (G + 0.04)
    p += [ck.ball(n + "pommel", 0.04, pp, gold)] + _ring(ck, n + "pring", pp - Z * 0.05, X, Z, 0.04, 0.012, gold, 10)
    p += _tails(ck, n + "rib", pp - Z * 0.06, dn, t2, 0.11, 0.055, 0.05)       # fitas curtas: com 0,17 roçavam o chão no atk_leap
    out = [_finish(ck, base, p, "wpn_main_sword2h_%s" % style, ".R", AXIS_1H)]
    # malho de espelhos (medidas do mace2h de paladin_sets.build_mace)
    n = "w_%s_m_" % style
    hc = Z * 0.98
    p = [ck.tube(n + "shaft", -Z * 0.34, Z * 0.88, 0.033, 0.03, t2, 8), ck.tube(n + "butt", -Z * 0.42, -Z * 0.33, 0.045, 0.04, gold, 8),
         ck.tube(n + "collar", Z * 0.8, Z * 0.88, 0.055, 0.055, gold, 10),
         ck.tube(n + "head", hc - X * 0.22, hc + X * 0.22, 0.14, 0.14, t, 10),
         ck.tube(n + "top", hc + Z * 0.12, hc + Z * 0.3, 0.055, 0.004, gold, 8)]
    for k in range(4):
        p.append(ck.tube(n + "wrap%d" % k, Z * (-0.26 + k * 0.12), Z * (-0.235 + k * 0.12), 0.038, 0.038, gold, 8))
    for sx in (-1, 1):
        fc = hc + X * sx * 0.25
        p += [ck.tube(n + "face%d" % sx, hc + X * sx * 0.22, fc, 0.136, 0.118, metal, 10),
              ck.tube(n + "band%d" % sx, hc + X * sx * 0.1, hc + X * sx * 0.16, 0.15, 0.15, gold, 10)]
        p += lk.mirror(ck, n + "mirror%d" % sx, fc + X * sx * 0.012, 0.1, M, (sx, 0, 0))
    for sg in (-1, 1):                   # faces largas (o que a câmera alta vê): medalhão de ouro com a lágrima
        fc = hc + Y * sg * 0.135
        p.append(ck.ball(n + "plate%d" % sg, 1.0, fc, gold, (0.075, 0.022, 0.1)))
        p += _tear(ck, n + "tear%d" % sg, fc + Y * sg * 0.02 + Z * 0.035, 0.024, M, sg)
    p += _tails(ck, n + "rib", Z * 0.81 + Y * 0.03, dn, t2, 0.3, 0.06, 0.06)
    out.append(_finish(ck, base, p, "wpn_main_mace2h_%s" % style, ".R", AXIS_1H))
    return out


def pal_t50(ck, base, mats, style="pal_t50"):
    """Templário — Sentença de Ouro Velho. Martelo-lanterna (Penitência Desperta, a assinatura da onda 4): o bloco do martelo é
    uma lanterna acesa em gaiola de ouro, faces de bater de aço com espelhinho, auréola de 5 lanterninhas no alto.
    Espada (Baluarte Desperto): guarda reta com uma lanterna em cada ponta e espelhinho no cruzamento."""
    import lumeria_kit as lk
    import paladin_sets as ps
    M = _mats(ck, mats)
    t, t2, gold, glow, metal, glass = M["t"], M["t2"], M["gold"], M["glow"], M["metal"], M["glass"]
    dn = _down(AXIS_1H)
    O = Vector((0, 0, 0))
    L, H, D = ps.HAMMER_L, ps.HAMMER_H, ps.HAMMER_D
    n = "w_%s_m_" % style
    hc = Z * 0.56
    p = _shaft_1h(ck, n, M, t2)
    flat = [ps._block(ck, n + "flame", hc, X, Y, Z, L * 0.94, D * 0.86, H * 0.86, glow, 0.012),         # miolo aceso
            ps._block(ck, n + "strap", hc, X, Y, Z, 0.02, D * 1.02, H * 1.02, gold, 0.006)]               # cinta do meio: duas janelas por face
    for sv in (-1, 1):                   # gaiola: quatro longarinas de ouro nas quinas
        for sw in (-1, 1):
            p.append(ck.tube(n + "post%d%d" % (sv > 0, sw > 0), hc - X * L + Y * sv * D * 0.92 + Z * sw * H * 0.92, hc + X * L + Y * sv * D * 0.92 + Z * sw * H * 0.92, 0.02, 0.02, gold, 6))
    p.append(ck.tube(n + "socket", hc - Z * (H + 0.05), hc - Z * (H - 0.01), 0.05, 0.064, gold, 8))
    for sx in (-1, 1):                   # faces de bater: cinta, tronco de aço que alarga, lábio de ouro, espelhinho
        d = X * sx
        flat += [ps._block(ck, n + "band%d" % sx, hc + d * (L - 0.005), d, Y, Z, 0.022, D * 1.1, H * 1.1, gold, 0.008),
                 ps._block(ck, n + "face%d" % sx, hc + d * (L + 0.05), d, Y, Z, 0.04, D * 0.96, H * 0.96, metal, 0.012, 1.2),
                 ps._block(ck, n + "lip%d" % sx, hc + d * (L + 0.1), d, Y, Z, 0.014, D * 1.2, H * 1.2, gold, 0.008)]
        p += lk.mirror(ck, n + "mirror%d" % sx, hc + d * (L + 0.118), 0.062, M, (sx, 0, 0))
    top = hc + Z * H
    p += [ck.tube(n + "roof", top - Z * 0.005, top + Z * 0.075, 0.105, 0.03, t, 4), ck.ball(n + "knob", 0.03, top + Z * 0.09, gold)]
    p += _ring(ck, n + "halo", top - Z * 0.03, X, Z, 0.19, 0.012, gold, 10, math.radians(18), math.radians(162))     # auréola em pé (arco)
    for k in range(5):
        a = math.radians(26 + k * 32)
        p.append(ck.ball(n + "halo_l%d" % k, 0.027, top - Z * 0.03 + (X * math.cos(a) + Z * math.sin(a)) * 0.19, glow, (1, 1, 1.25)))
    p += _tails(ck, n + "veil", Z * 0.4 + Y * 0.03, dn, t2, 0.24, 0.06, 0.05)
    out = [_finish(ck, base, p + flat, "wpn_main_mace_%s" % style, ".R", AXIS_1H, flat)]
    # espada da sentença
    n = "w_%s_s_" % style
    G = 0.09
    gc = Z * (G + 0.015)
    p = [ps._blade(ck, n + "blade", O, Z, X, G + 0.03, 0.62, 0.06, 0.05, 0.16, 0.016, 0.0, metal),
         ck.tube(n + "guard", gc - X * 0.2, gc + X * 0.2, 0.022, 0.022, gold, 8)]
    for sg in (-1, 1):
        p.append(ps._blade(ck, n + "core%d" % sg, Y * sg * 0.014, Z, X, G + 0.16, 0.5, 0.015, 0.009, 0.07, 0.004, 0.0, glow))
        p += lk.mirror(ck, n + "mirror%d" % sg, gc + Y * sg * 0.028, 0.052, M, (0, sg, 0))
    for sx in (-1, 1):
        p += lk.lantern(ck, n + "lan%d" % sx, gc + X * sx * 0.235 + Z * 0.01, 0.042, M)
    p += _hilt(ck, n, M, G, 3, t2)
    pp = -Z * (G + 0.04)
    p += [ck.ball(n + "pommel", 0.04, pp, gold), ck.ball(n + "pommel_gem", 0.027, pp - Z * 0.032, glow, (1, 1, 1.3))]
    p += _tails(ck, n + "veil", pp + Y * 0.02, dn, t2, 0.22, 0.05, 0.04)
    out.append(_finish(ck, base, p, "wpn_main_sword_%s" % style, ".R", AXIS_1H))
    return out


# ---------------------------------------------------------------------------
# Berserker
# ---------------------------------------------------------------------------
def _axe(ck, base, mats, name, cfg, hand, big, extra):
    """Machado pelo axe_kit (mesma empunhadura dos conjuntos) + peças do tema. extra(n, g, fwd, out, side, hc, S) devolve
    (lisas, facetadas) em coordenadas do mundo; a bochecha da lâmina troca de material por cfg["cheek"]."""
    import axe_kit
    import berserker_sets as bs
    side_tag = ".R" if hand == "main" else ".L"
    g = Vector(ck.hand_center(base, side_tag))
    fwd = Vector(AXIS_1H).normalized()
    side = Vector((1, 0, 0))
    out = -fwd.cross(side).normalized()
    n = "ax_%s_" % name
    parts = axe_kit.axe_parts(ck, n, g, fwd, out, side, mats, cfg, big)
    if cfg.get("cheek") is not None:
        for o in parts:
            if o.name.endswith("cheek") or o.name.endswith("nape"):
                o.data.materials[0] = cfg["cheek"]
    S = cfg.get("S", 1.4 if big else 0.86)
    hc = g + fwd * (cfg.get("shaft", 0.95 if big else 0.54) - 0.06)
    smooth, flat = extra(n, g, fwd, out, side, hc, S)
    for o in smooth:
        ck._smooth(o.data)
    obj = ck._join(parts + bs._outward(smooth + flat), name)
    ck.skin_rigid(obj, base["rig"], "hand" + side_tag)
    return obj


def ber_g50(ck, base, mats, style="ber_g50"):
    """Carniceiro — Banquete das Fitas Rubras. Par de machados (Frenesi Desperto): lâmina de porcelana com o fio em dentes
    (o sorriso rasgado da máscara) aceso, filete de ouro do sorriso na face, taça de vidro no topo e fitas rubras compridas
    presas ao cabo."""
    import lumeria_kit as lk
    M = _mats(ck, mats)
    t2, gold, glass, glow = M["t2"], M["gold"], M["glass"], M["glow"]
    cfg = {"type": "axe", "head": "fang", "glow": "tint", "back": True, "cheek": M["t"], "colors": {"trim": lk.OLD_GOLD}}
    out = []
    for hand in ("main", "off"):
        def extra(n, g, fwd, o, side, hc, S):
            sm = []
            for sg in (-1, 1):           # sorriso de ouro na face: arco de canto a canto, por cima da porcelana
                pts = [hc + fwd * (0.2 - k * 0.1) * S + o * (0.17 + 0.1 * math.sin(math.pi * k / 4.0)) * S + side * sg * 0.03 * S for k in range(5)]
                for k in range(4):
                    sm.append(ck.tube(n + "grin%d_%d" % (sg > 0, k), pts[k], pts[k + 1], 0.012, 0.012, gold, 5))
            top = hc + fwd * (0.1 * S)   # taça de vidro com vinho aceso no topo do olho
            sm += [ck.tube(n + "cup", top, top + fwd * 0.09, 0.03, 0.062, glass, 8), ck.ball(n + "wine", 0.05, top + fwd * 0.085, glow, (1, 1, 0.5))]
            for k in range(2):           # voltas de seda no cabo
                z = 0.2 + k * 0.1
                sm.append(ck.tube(n + "silk%d" % k, g + fwd * z, g + fwd * (z + 0.045), 0.034, 0.034, t2, 8))
            tie = g - fwd * 0.15         # fitas rubras no pé do cabo e uma na gola da cabeça
            for i, (dx, ln) in enumerate(((-0.07, 0.22), (0.08, 0.17))):      # eram 0,36/0,30: varriam o chão no atk_flurry / atk_finisher
                sm.append(lk.silk(ck, n + "rib%d" % i, tie, tie + Vector((dx, 0.06, -ln)), (1, 0.3, 0), 0.05, 0.07, t2, (0, 0.035, 0), 4))
            neck = hc - fwd * (0.16 * S) - o * 0.03
            sm.append(lk.silk(ck, n + "rib_head", neck, neck + Vector((0.03, 0.09, -0.26)), (1, 0.3, 0), 0.045, 0.06, t2, (0, 0.03, 0), 3))
            return sm, []
        out.append(_axe(ck, base, mats, ("wpn_main_axe_%s" if hand == "main" else "wpn_off_axe_%s") % style, cfg, hand, False, extra))
    return out


def ber_e50(ck, base, mats, style="ber_e50"):
    """Executor — Lâmina do Último Brinde (assinatura da onda 4): cutelo enorme com a FACE DE ESPELHO (vidro) em moldura de
    ouro, fio aceso, máscara de porcelana com a lágrima na nuca da lâmina, corrente com duas taças e borla de seda negra."""
    import lumeria_kit as lk
    import paladin_sets as ps
    M = _mats(ck, mats)
    gold, glass, glow, porc = M["gold"], M["glass"], M["glow"], M["porc"]
    cfg = {"type": "axe2h", "head": "cleaver", "glow": "tint", "poll": True, "tassel": True, "cheek": glass, "S": 1.45, "colors": {"trim": lk.OLD_GOLD}}

    def extra(n, g, fwd, o, side, hc, S):
        sm = []
        for sg in (-1, 1):               # moldura de ouro: cantos de cima e de baixo e a linha do bisel
            off = side * sg * 0.022 * S
            a0, a1 = hc + fwd * 0.16 * S + o * 0.03 * S, hc + fwd * 0.345 * S + o * 0.265 * S
            b0, b1 = hc - fwd * 0.16 * S + o * 0.03 * S, hc - fwd * 0.33 * S + o * 0.255 * S
            sm += [ck.tube(n + "frame_a%d" % (sg > 0), a0 + off, a1 + off * 0.7, 0.014, 0.011, gold, 5),
                   ck.tube(n + "frame_b%d" % (sg > 0), b0 + off, b1 + off * 0.7, 0.014, 0.011, gold, 5),
                   ck.tube(n + "frame_c%d" % (sg > 0), a1 + off * 0.7, b1 + off * 0.7, 0.01, 0.01, gold, 5)]
            # lágrima de ouro aceso escorrendo pelo espelho
            tc = hc + fwd * 0.12 * S + o * 0.15 * S + side * sg * 0.03 * S
            sm += [ck.tube(n + "tear%d" % (sg > 0), tc, tc - fwd * 0.2 * S, 0.012, 0.016, glow, 5), ck.ball(n + "drop%d" % (sg > 0), 0.03, tc - fwd * 0.22 * S, glow)]
        pc = hc - o * 0.17 * S           # máscara de porcelana na nuca (sobre o martelo de trás), olhando para trás
        sm += [ck.ball(n + "mask", 1.0, pc, porc, (0.085, 0.06, 0.1)), ck.ball(n + "mask_rim", 1.0, pc + o * 0.015, gold, (0.095, 0.05, 0.11))]
        sm += ps._chain(ck, n + "chain", hc - o * 0.12 * S - fwd * 0.1 * S, hc - fwd * 0.42 * S - o * 0.02, 0.07, gold, 6, 0.012)
        for k, q in enumerate((0.4, 0.75)):
            at = (hc - o * 0.12 * S - fwd * 0.1 * S).lerp(hc - fwd * 0.42 * S - o * 0.02, q) + Vector((0, 0.01, -0.06))
            sm += lk.goblet(ck, n + "cup%d" % k, at, 0.045, M)
        return sm, []
    return [_axe(ck, base, mats, "wpn_main_axe2h_%s" % style, cfg, "main", True, extra)]


def ber_m50(ck, base, mats, style="ber_m50"):
    """Punhos — Dança dos Mil Guizos. Par de garras (Punho Vingativo Desperto): manopla de porcelana em cara de raposa
    (orelhas, marca acesa na testa), quatro lâminas com a base acesa, pulseira de guizos e fita de seda no punho."""
    import lumeria_kit as lk
    import berserker_sets as bs
    M = _mats(ck, mats)
    t, t2, gold, glow, porc = M["t"], M["t2"], M["gold"], M["glow"], M["porc"]
    cfg = {"blades": 4, "len": 0.56, "curve": 0.2, "glow": "tint"}
    out = []
    j = base["j"]
    for hand, side_tag in (("main", ".R"), ("off", ".L")):
        g = Vector(ck.hand_center(base, side_tag))
        axis = Vector(j["hand_tip" + side_tag]) - Vector(j["wrist" + side_tag])
        n = "c_%s_%s_" % (style, hand)
        parts = bs.claw_parts(ck, n, g, mats, cfg, t, M["metal"], axis)
        punch = axis.normalized()
        grip = Vector((0, -0.55, 0.83))
        grip = (grip - punch * grip.dot(punch)).normalized()
        up = grip.cross(punch).normalized()
        top = g + punch * 0.01 + up * 0.1
        for sg in (-1, 1):               # orelhas de raposa nas costas da mão, miolo de seda
            root = top + grip * sg * 0.055 - punch * 0.05
            parts += [ck.blade(n + "ear%d" % sg, root, root + up * 0.13 + grip * sg * 0.03 - punch * 0.04, 0.085, 0.022, porc, tuple(grip), 0.35),
                      ck.blade(n + "ear_in%d" % sg, root + punch * 0.012 + up * 0.012, root + up * 0.1 + grip * sg * 0.024 - punch * 0.02, 0.045, 0.02, t2, tuple(grip), 0.35)]
        parts += [ck.ball(n + "brow", 0.024, top + punch * 0.05 + up * 0.012, glow, (1, 1, 1)),
                  ck.ball(n + "nose", 0.022, top + punch * 0.11 - up * 0.02, M["ink"])]
        cuff = g - punch * 0.09
        for k in range(5):               # pulseira de guizos em volta do punho
            a = math.tau * k / 5 + 0.3
            parts.append(ck.ball(n + "bell%d" % k, 0.03, cuff + (grip * math.cos(a) + up * math.sin(a)) * 0.095, gold))
        parts.append(ck.tube(n + "cuff_silk", cuff - punch * 0.05, cuff - punch * 0.02, 0.08, 0.08, t2, 10))
        tie = cuff - up * 0.07
        parts.append(lk.silk(ck, n + "rib", tie, tie + Vector((0, 0.05, -0.26)), tuple(grip), 0.05, 0.075, t2, (0, 0.03, 0), 3))
        obj = ck._join(bs._outward(parts), ("wpn_main_claw_%s" if hand == "main" else "wpn_off_claw_%s") % style)
        ck._smooth(obj.data)
        ck.skin_rigid(obj, base["rig"], "hand" + side_tag)
        out.append(obj)
    return out


# ---------------------------------------------------------------------------
# Bispo
# ---------------------------------------------------------------------------
def bis_s50(ck, base, mats, style="bis_s50"):
    """Sacerdote — Lanterna da Última Vigília. Maça (Égide Desperta): lanterna grande de vidro e ouro entre quatro aletas de
    porcelana, coroa de 5 luzes no telhado, asinhas de vidro na gola e véu de seda no pomo."""
    import lumeria_kit as lk
    M = _mats(ck, mats)
    t, t2, gold, glow, glass = M["t"], M["t2"], M["gold"], M["glow"], M["glass"]
    dn = _down(AXIS_1H)
    n = "w_%s_m_" % style
    hc = Z * 0.56
    p = _shaft_1h(ck, n, M, t, 0.44)
    p += lk.lantern(ck, n + "lan", hc, 0.125, M)
    p.append(ck.tube(n + "glass", hc - Z * 0.09, hc + Z * 0.09, 0.07, 0.07, glass, 8))
    for k in range(4):                   # aletas de porcelana (lê "maça") entre os montantes da gaiola
        a = math.tau * k / 4
        p.append(ck._flange(n + "flange%d" % k, hc, Z, X * math.cos(a) + Y * math.sin(a), 0.175, 0.2, 0.028, t))
    crown = hc + Z * 0.1
    p += _ring(ck, n + "crown", crown, X, Y, 0.115, 0.011, gold, 10)
    for k in range(5):                   # coroa de 5 luzes
        a = math.tau * k / 5 + 0.3
        d = X * math.cos(a) + Y * math.sin(a)
        p += [ck.ball(n + "light%d" % k, 0.026, crown + d * 0.115 + Z * 0.035, glow, (1, 1, 1.3)), ck.tube(n + "stem%d" % k, crown + d * 0.115, crown + d * 0.115 + Z * 0.02, 0.012, 0.012, gold, 5)]
    for sx in (-1, 1):                   # asinhas de vidro na gola
        for k in range(2):
            p.append(ck.blade(n + "wing%d_%d" % (sx, k), Z * 0.4 + X * sx * 0.03, Z * (0.36 - k * 0.07) + X * sx * (0.19 - k * 0.04), 0.065, 0.016, glass, (0, 1, 0)))
    p += _tails(ck, n + "veil", -Z * 0.17 + Y * 0.02, dn, t2, 0.24, 0.055, 0.04)
    return [_finish(ck, base, p, "wpn_main_mace_%s" % style, ".R", AXIS_1H)]


def bis_i50(ck, base, mats, style="bis_i50"):
    """Iluminado — Espelho do Meio-Dia. Cetro (Castigo Sagrado Desperto): espelho redondo em pé com raios de sol (ouro e luz
    alternados), cristal facetado de mitra no alto e fitas douradas na gola."""
    import lumeria_kit as lk
    M = _mats(ck, mats)
    t, t2, gold, glow, glass = M["t"], M["t2"], M["gold"], M["glow"], M["glass"]
    dn = _down(AXIS_STAFF)
    n = "s_%s_" % style
    ln = 1.3
    top = Z * (ln * 0.58)
    p = [ck.tube(n + "shaft", -Z * (ln * 0.42), top, 0.027, 0.031, t, 8), ck.tube(n + "foot", -Z * (ln * 0.47), -Z * (ln * 0.41), 0.012, 0.04, gold, 8),
         ck.tube(n + "collar", top, top + Z * 0.06, 0.05, 0.075, gold, 10)]
    for k in range(4):
        z = ln * (-0.3 + k * 0.24)
        p.append(ck.tube(n + "ring%d" % k, Z * z, Z * (z + 0.035), 0.041, 0.041, gold if k % 2 else t2, 10))
    hc = top + Z * 0.22
    for sg in (-1, 1):
        p += lk.mirror(ck, n + "mirror%d" % sg, hc + Y * sg * 0.012, 0.135, M, (0, sg, 0))
    for k in range(12):                  # raios de sol em volta do espelho (menos os que desceriam pelo cabo)
        a = math.tau * k / 12
        d = X * math.cos(a) + Z * math.sin(a)
        if d.z < -0.6:
            continue
        p.append(ck.blade(n + "ray%d" % k, hc + d * 0.15, hc + d * (0.3 if k % 2 == 0 else 0.23), 0.065, 0.02, glow if k % 2 == 0 else gold, Y.cross(d), 0.35))
    flat = [ck.tube(n + "crystal", hc + Z * 0.14, hc + Z * 0.33, 0.055, 0.004, glass, 4),      # cristal de mitra, facetado
            ck.tube(n + "crystal_b", hc + Z * 0.1, hc + Z * 0.14, 0.03, 0.055, glass, 4)]
    p += _tails(ck, n + "rib", top + Z * 0.02 + Y * 0.03, dn, t2, 0.3, 0.05, 0.06)
    return [_finish(ck, base, p + flat, "wpn_main_scepter_%s" % style, ".R", AXIS_STAFF, flat)]


def bis_b50(ck, base, mats, style="bis_b50"):
    """Clérigo de Batalha — Hino da Taça Partida. Maça (Mão que Cura Desperta): cabeça em taça de porcelana remendada com ouro
    (rachaduras de kintsugi, uma acesa), vinho aceso na boca, quatro aletas de aço, sinos e flâmula de seda (o estandarte)."""
    import lumeria_kit as lk
    M = _mats(ck, mats)
    t, t2, gold, glow, metal = M["t"], M["t2"], M["gold"], M["glow"], M["metal"]
    dn = _down(AXIS_1H)
    n = "w_%s_m_" % style
    hc = Z * 0.56
    z0, z1, r0, r1 = -0.1, 0.14, 0.062, 0.15

    def surf(a, z, lift=0.006):          # ponto na parede da taça
        r = r0 + (r1 - r0) * (z - z0) / (z1 - z0) + lift
        return hc + Z * z + (X * math.cos(a) + Y * math.sin(a)) * r

    p = _shaft_1h(ck, n, M, t2, 0.44)
    p += [ck.tube(n + "stem", Z * 0.42, hc + Z * z0, 0.045, 0.062, gold, 8), ck.ball(n + "knot", 0.058, Z * 0.435, gold, (1, 1, 0.7)),
          ck.tube(n + "bowl", hc + Z * z0, hc + Z * z1, r0, r1, t, 12),
          ck.tube(n + "lip", hc + Z * (z1 - 0.012), hc + Z * (z1 + 0.012), r1 + 0.008, r1 + 0.008, gold, 12),
          ck.ball(n + "wine", 1.0, hc + Z * (z1 - 0.005), glow, (r1 * 0.93, r1 * 0.93, 0.035))]
    for k in range(4):                   # aletas de aço saindo por baixo da taça
        a = math.tau * k / 4 + math.pi / 4
        d = X * math.cos(a) + Y * math.sin(a)
        p.append(ck._flange(n + "flange%d" % k, hc - Z * 0.03, Z, d, 0.185, 0.2, 0.028, metal))
    cracks = (((-0.12, -0.08), (0.14, -0.01), (-0.1, 0.06), (0.12, 0.13)), ((1.45, -0.08), (1.72, 0.0), (1.48, 0.07), (1.7, 0.13)),
              ((3.0, -0.07), (3.28, 0.02), (3.05, 0.13)), ((4.6, -0.08), (4.85, -0.01), (4.6, 0.06), (4.84, 0.13)))
    for ci, cr in enumerate(cracks):     # kintsugi entre as aletas: ouro nos lados, acesa na frente e nas costas (o que a câmera alta vê)
        m_ = glow if ci % 2 else gold
        for k in range(len(cr) - 1):
            p.append(ck.tube(n + "crack%d_%d" % (ci, k), surf(*cr[k]), surf(*cr[k + 1]), 0.013, 0.013, m_, 5))
    for sx in (-1, 1):                   # sinos pendurados na borda
        at = hc + Z * (z1 - 0.07) + X * sx * (r1 + 0.045)
        p += lk.bell(ck, n + "bell%d" % sx, at, 0.032, M)
        p.append(ck.tube(n + "bell_h%d" % sx, hc + Z * z1 + X * sx * r1, at, 0.007, 0.007, gold, 4))
    p += _tails(ck, n + "flag", Z * 0.4 + Y * 0.03, dn, t2, 0.28, 0.075, 0.02, 1)
    return [_finish(ck, base, p, "wpn_main_mace_%s" % style, ".R", AXIS_1H)]
