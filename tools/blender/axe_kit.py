"""Machados (redesenho 2026-11-15): um construtor só para o machado comum do kit (chibi_kit.kit_weapon, que também arma os
monstros), os dos conjuntos do Berserker (berserker_sets.build_axe) e os dos chefes (Ghar, Durgash).

Por que existe: os machados antigos liam como porrete (cabeça = bola achatada no kit comum; nos conjuntos, placa de contorno
quase convexo, fio da mesma cor da lâmina, alvado grosso + pele + caveira empilhados no mesmo ponto).
Ver production/qa/axes-redesign-2026-11-15.md.

Construção da cabeça (`blade_parts`), no plano (u = ao longo do cabo, v = para fora, w = espessura):
  - olho estreito no cabo (`eye`), pescoço côncavo que ABRE até as pontas (`flare_*`: 1 = cunha reta, 2-3 = abre só no fim);
  - fio em arco de `-dn` (calcanhar/barba) a `+up` (bico), ápice em `apex`, pontas recuadas `sag_*` (crescente = recuo grande);
  - face (bochecha) fina: `thick` no olho afinando até `thick_bev` na linha do bisel; do bisel ao fio vai a zero;
  - o BISEL é uma faixa larga (`bevel` = fração do alcance) em material claro (`m_metal`, brilho 0,9 no toon) e a face é aço
    escuro fosco (`m_axe_cheek`): é o contraste que diz "lâmina" a 24 m (71 px/m: faixa < 4 cm some).
  - faces planas (sem _smooth) na lâmina; o resto (cabo, anéis) é liso.
Tudo em metros para S = 1; `axe_parts` multiplica por S (uma mão 0,86, duas mãos 1,4).
"""
import math

import bmesh
from mathutils import Vector

CHEEK = (0.38, 0.41, 0.52)        # aço forjado fosco (face da lâmina)
CHEEK_DARK = (0.17, 0.15, 0.22)   # lâmina escura (conjuntos "dark")
# Fio aceso (cfg "glow"): cor PROFUNDA e emissão 1,0. O toon soma base * emission_amount por cima da cor iluminada e o
# bisel é 24% do alcance: com (1.0, 0.25, 0.15) a 2,4 (2,0 no teto do KitModel) a faixa inteira estourava em pêssego claro.
# A emissão dobra a cor: canal forte perto de 1,0 ainda estoura e troca o matiz (laranja virou amarelo-limão, carmim virou
# rosa); os brilhos dos conjuntos ficam com o canal forte em 0,4-0,95 e o fraco <= 0,05. "glow": True usa EDGE_GLOW;
# uma cor (r, g, b) é o brilho próprio do conjunto (berserker_sets.BER_AXES).
EDGE_GLOW = (1.0, 0.16, 0.06)
EDGE_GLOW_ENERGY = 1.0            # degrau de 0,25 (RigidMerge / KitModel._shared_key juntam por valor)

# formas de cabeça (S = 1)
HEADS = {
    # machado comum do kit: largo, simétrico o bastante para ler de qualquer lado
    "broad": dict(eye=0.085, reach=0.40, up=0.25, dn=0.29, apex=0.52, sag_up=0.07, sag_dn=0.08, flare_up=2.0, flare_dn=2.2),
    # barbado: bico curto em cima, barba comprida que desce e faz gancho
    "bearded": dict(eye=0.085, reach=0.41, up=0.17, dn=0.43, apex=0.72, sag_up=0.04, sag_dn=0.13, flare_up=1.5, flare_dn=3.0),
    # crescente: meia-lua, pontas recuadas quase até o cabo
    "crescent": dict(eye=0.07, reach=0.42, up=0.38, dn=0.38, apex=0.5, sag_up=0.2, sag_dn=0.2, flare_up=2.6, flare_dn=2.6),
    # cutelo: placa alta de fio quase reto, canto de cima em ponta
    "cleaver": dict(eye=0.15, reach=0.36, up=0.36, dn=0.36, apex=0.6, sag_up=0.0, sag_dn=0.05, flare_up=1.25, flare_dn=1.6),
    # presa: crescente com dentes no fio
    "fang": dict(eye=0.08, reach=0.42, up=0.33, dn=0.35, apex=0.5, sag_up=0.14, sag_dn=0.15, flare_up=2.3, flare_dn=2.5, teeth=3, tooth=0.075),
    # duplo: duas lâminas espelhadas (borboleta)
    "double": dict(eye=0.075, reach=0.38, up=0.31, dn=0.31, apex=0.5, sag_up=0.13, sag_dn=0.13, flare_up=2.3, flare_dn=2.3),
}
DEFAULT = dict(thick=0.062, thick_bev=0.026, bevel=0.24, rows=9)


def _mat(ck, name, color, rough=0.5, emission=0.0):
    return ck.mat(name, color, rough, emission)


def _obox(ck, name, c, u, v, w, su, sv, sw, material, taper=1.0):
    """Caixa orientada (su ao longo de u...). taper < 1 estreita a face +v (alvado em cunha)."""
    bm = bmesh.new()
    vs = []
    for a in (-0.5, 0.5):
        for b in (-0.5, 0.5):
            for d in (-0.5, 0.5):
                k = taper if b > 0 else 1.0
                vs.append(bm.verts.new(c + u * a * su * k + v * b * sv + w * d * sw * k))
    for f in ((0, 1, 3, 2), (4, 6, 7, 5), (0, 4, 5, 1), (2, 3, 7, 6), (0, 2, 6, 4), (1, 5, 7, 3)):
        bm.faces.new([vs[i] for i in f])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    return ck.mesh_from(name, bm, material)


def edge_curve(p, t):
    """Ponto do fio (u, v) em t ∈ [0, 1] (0 = calcanhar/barba, 1 = bico)."""
    apex = p["apex"]
    if t >= apex:
        k, sag = (t - apex) / max(1e-6, 1.0 - apex), p["sag_up"]
    else:
        k, sag = (apex - t) / max(1e-6, apex), p["sag_dn"]
    v = p["reach"] - sag * k * k
    if p.get("teeth"):                       # dentes: pontas em t = i / teeth, vales entre elas
        v -= p["tooth"] * abs(math.sin(math.pi * p["teeth"] * t)) * (1.0 - 0.35 * k)
    return -p["dn"] + (p["up"] + p["dn"]) * t, v


def blade_parts(ck, name, hc, u, v, w, S, shape, m_cheek, m_edge):
    """Uma lâmina: [face (aço escuro, plana), bisel (fio claro)]. hc = centro da cabeça no eixo do cabo."""
    p = dict(DEFAULT)
    p.update(shape)
    rows = p["rows"] if not p.get("teeth") else 4 * p["teeth"] + 1
    sb = 1.0 - p["bevel"]
    cols = [0.0, 0.34, 0.68, sb]
    grid = []                                   # grid[r][c] = (ponto no plano, meia espessura)
    for r in range(rows):
        t = r / (rows - 1)
        ue, ve = edge_curve(p, t)
        u0 = -p["eye"] + 2.0 * p["eye"] * t
        fl = p["flare_dn"] + (p["flare_up"] - p["flare_dn"]) * t
        thin = 1.0 - 0.45 * abs(2.0 * t - 1.0) ** 2            # bico e calcanhar mais finos que o meio
        line = []
        for s in cols + [1.0]:
            pu = u0 + (ue - u0) * (s ** fl)
            h = (p["thick"] + (p["thick_bev"] - p["thick"]) * (s / sb)) * 0.5 * thin if s < 1.0 else 0.0
            line.append((hc + (u * pu + v * (ve * s)) * S, h * S))
        grid.append(line)
    nc = len(cols)
    # face
    bm = bmesh.new()
    f = [[bm.verts.new(pt + w * h) for pt, h in line[:nc]] for line in grid]
    k = [[bm.verts.new(pt - w * h) for pt, h in line[:nc]] for line in grid]
    for r in range(rows - 1):
        for c in range(nc - 1):
            bm.faces.new((f[r][c], f[r][c + 1], f[r + 1][c + 1], f[r + 1][c]))
            bm.faces.new((k[r][c], k[r + 1][c], k[r + 1][c + 1], k[r][c + 1]))
    for c in range(nc - 1):                     # bordas de baixo e de cima
        bm.faces.new((f[0][c], k[0][c], k[0][c + 1], f[0][c + 1]))
        bm.faces.new((f[-1][c], f[-1][c + 1], k[-1][c + 1], k[-1][c]))
    for r in range(rows - 1):                   # fundo (dentro do alvado)
        bm.faces.new((f[r][0], f[r + 1][0], k[r + 1][0], k[r][0]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    cheek = ck.mesh_from(name + "cheek", bm, m_cheek)
    # bisel
    bm = bmesh.new()
    a = [bm.verts.new(line[nc - 1][0] + w * line[nc - 1][1]) for line in grid]
    b = [bm.verts.new(line[nc - 1][0] - w * line[nc - 1][1]) for line in grid]
    e = [bm.verts.new(line[nc][0]) for line in grid]
    for r in range(rows - 1):
        bm.faces.new((a[r], e[r], e[r + 1], a[r + 1]))
        bm.faces.new((b[r], b[r + 1], e[r + 1], e[r]))
    bm.faces.new((a[0], b[0], e[0]))
    bm.faces.new((a[-1], e[-1], b[-1]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    bevel = ck.mesh_from(name + "bevel", bm, m_edge)
    return [cheek, bevel]


def axe_parts(ck, n, g, fwd, out, side, mats, cfg, big):
    """Peças de um machado inteiro com a empunhadura em g. cfg: head + motivos (spike, back, fur, skull, gem, glow = fio aceso: True ou cor, dark,
    tassel, poll = martelo atrás, langet = talas no cabo (padrão liga), S = escala própria, shaft/butt = cabo acima/abaixo
    da mão, back_scale = tamanho da 2ª lâmina do duplo, colors = {"trim"|"tint"|"tint2": cor} só deste machado)."""
    V = Vector
    if cfg.get("colors"):
        mats = dict(mats)
        for key, col in cfg["colors"].items():
            mats[key] = _mat(ck, "m_axe_%02x%02x%02x" % tuple(int(c * 255) for c in col), col, 0.5)
    t, t2, gold, wood = mats["tint"], mats["tint2"], mats["trim"], mats["wood"]
    m_edge = mats["metal"]
    if cfg.get("glow"):
        gc = EDGE_GLOW if cfg["glow"] is True else tuple(cfg["glow"])
        m_edge = _mat(ck, "m_axe_glow_%02x%02x%02x" % tuple(int(round(c * 255)) for c in gc), gc, 0.3, EDGE_GLOW_ENERGY)
    m_cheek = _mat(ck, "m_axe_cheek_dark", CHEEK_DARK, 0.5) if cfg.get("dark") else _mat(ck, "m_axe_cheek", CHEEK, 0.5)
    S = cfg.get("S", 1.4 if big else 0.86)
    shaft = cfg.get("shaft", 0.95 if big else 0.54)
    lo = cfg.get("butt", 0.34 if big else 0.13)                  # cabo abaixo da mão
    r = 0.03 if big else 0.025
    hc = g + fwd * (shaft - 0.06)
    shape = HEADS[cfg["head"]]
    eye = shape["eye"] * S
    smooth = []                                  # peças redondas (lisas); a lâmina fica facetada
    smooth.append(ck.tube(n + "shaft", g - fwd * lo, hc + fwd * (eye + 0.03 * S), r * 1.08, r * 0.92, wood, 8))
    smooth.append(ck.tube(n + "butt", g - fwd * (lo + 0.05), g - fwd * (lo - 0.01), r * 1.7, r * 1.25, gold, 8))
    # empunhadura: uma luva de couro só + dois anéis (antes: 3-4 discos soltos, lia como cabo de porrete)
    gl = 0.2 if big else 0.13
    smooth.append(ck.tube(n + "grip", g - fwd * gl * 0.6, g + fwd * gl * 0.5, r * 1.22, r * 1.22, mats["leather"], 8))
    for z in (-gl * 0.6, gl * 0.5):
        smooth.append(ck.tube(n + "ring%d" % (z > 0), g + fwd * (z - 0.012), g + fwd * (z + 0.012), r * 1.5, r * 1.5, t2, 8))
    flat = []
    sides = (1, -1) if cfg["head"] == "double" else (1,)
    for sg in sides:
        flat += blade_parts(ck, n + "b%d_" % (sg > 0), hc, fwd, out * sg, side, S * (cfg.get("back_scale", 1.0) if sg < 0 else 1.0), shape, m_cheek, m_edge)
    # olho/alvado: caixa em cunha na cor do item, cintas de metal em cima e embaixo
    flat.append(_obox(ck, n + "eye", hc, fwd, out, side, eye * 2.3, 0.105 * S, 0.105 * S, t, 0.86))
    for sg in (-1, 1):
        smooth.append(ck.tube(n + "collar%d" % (sg > 0), hc + fwd * sg * eye * 1.15 - fwd * 0.014 * S, hc + fwd * sg * eye * 1.15 + fwd * 0.014 * S,
                              r * 1.75, r * 1.75, gold, 8))
    if cfg.get("langet", True):                  # talas: tiras de metal descendo pelo cabo (lê "haste de machado", não "cabo de clava")
        ll = 0.2 * S
        for sg in (-1, 1):
            flat.append(_obox(ck, n + "langet%d" % (sg > 0), hc - fwd * (eye * 1.15 + ll * 0.5) + side * sg * r * 1.0, fwd, out, side,
                              ll, r * 1.3, 0.012, mats["metal"]))
    back = hc - out * 0.05 * S
    if cfg["head"] != "double":
        if cfg.get("back"):                      # cravo de guerra atrás (4 lados)
            smooth.append(ck.tube(n + "back", back, hc - out * 0.3 * S, 0.05 * S, 0.004, mats["metal"], 4))
        elif cfg.get("poll"):                    # cabeça de martelo atrás
            flat.append(_obox(ck, n + "poll", hc - out * 0.1 * S, fwd, out, side, eye * 1.5, 0.1 * S, 0.09 * S, mats["metal"]))
        else:                                    # nuca curta
            flat.append(_obox(ck, n + "nape", hc - out * 0.065 * S, fwd, out, side, eye * 1.6, 0.05 * S, 0.075 * S, m_cheek, 0.8))
    if cfg.get("spike"):                         # ponta de lança no topo
        top = hc + fwd * (eye * 1.15)
        smooth.append(ck.tube(n + "spike", top, top + fwd * 0.26 * S, 0.042 * S, 0.004, mats["metal"], 4))
    if cfg.get("fur"):
        import berserker_sets as bs
        fz = hc - fwd * (eye * 1.15 + 0.2 * S + 0.02)
        smooth.append(ck.tube(n + "fur", fz - fwd * 0.07 * S, fz, r * 1.9, r * 2.1, ck.mat("m_ber_fur_brown", bs.FUR["brown"], 0.95), 8))
    if cfg.get("skull"):                         # caveira no topo do olho, do lado oposto ao fio (não tapa a lâmina)
        import berserker_sets as bs
        smooth.append(ck.ball(n + "skull", 0.05 * S, hc - out * 0.1 * S + fwd * 0.0, ck.mat("m_ber_bone", bs.BONE, 0.7), (1, 0.9, 1.05)))
    if cfg.get("gem"):
        for sg in (-1, 1):
            smooth.append(ck.ball(n + "gem%d" % (sg > 0), 0.034 * S, hc + side * sg * 0.05 * S, t2, (0.55, 1, 1)))
    if cfg.get("tassel"):
        smooth.append(ck.blade(n + "tassel", hc - fwd * (eye + 0.05) - out * 0.03, hc - fwd * (eye + 0.05) - out * 0.1 - fwd * 0.16, 0.045, 0.012, t2, side, 0.25))
    for o in smooth:
        ck._smooth(o.data)
    return smooth + flat


def build(ck, base, mats, name, cfg, hand, big, fwd=None):
    """Machado na mão (main = direita, off = esquerda), 1 malha com o nome dado."""
    V = Vector
    side_tag = ".R" if hand == "main" else ".L"
    g = V(ck.hand_center(base, side_tag))
    fwd = (fwd or V((0, -0.55, 0.83))).normalized()
    side = V((1, 0, 0))
    out = -fwd.cross(side).normalized()          # a lâmina aponta para a frente do boneco
    obj = ck._join(axe_parts(ck, "ax_%s_" % name, g, fwd, out, side, mats, cfg, big), name)
    ck.skin_rigid(obj, base["rig"], "hand" + side_tag)
    return obj


# kit comum (e monstros, por chibi_kit.kit_weapon): o de duas mãos é mais curto que os dos conjuntos (cabeça a 0,66 m da mão,
# como antes) e tem cravo atrás
COMMON = {"axe": {"head": "broad"}, "axe2h": {"head": "broad", "back": True, "S": 1.2, "shaft": 0.72, "butt": 0.14}}
COMMON_2H_AXIS = (0, -0.25, 1)      # o machado de duas mãos comum fica mais em pé que os dos conjuntos


def kit_axe(ck, base, mats, wtype, hand, cfg=None):
    """Machado comum do kit: wpn_<main|off>_<axe|axe2h>. cfg troca a cabeça (chefes: act2_bosses.GHAR_AXE, kharzun_mobs.DURGASH_AXE)."""
    big = wtype == "axe2h"
    return build(ck, base, mats, "wpn_%s_%s" % (hand, wtype), cfg or COMMON[wtype], hand, big, Vector(COMMON_2H_AXIS) if big else None)
