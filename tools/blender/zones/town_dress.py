"""Identidade das cidades do Ato I (GDD design/gdd/living-towns.md): o centro com função e os quadrantes com ofício.

Tudo em lote pelo `Dress` (poucas malhas por célula de 36 m, cor no vértice). As zonas antigas (Aldara) não usam
`zone_lib.Zone`: `shim()` monta o mínimo que o `Dress` lê. Nada aqui sorteia a sim; os colisores entram pelo `ob` da zona
(ocultos: o visual é a malha do lote) e as posições ficam em `data["town"]["centerpiece"]` para o check `_check_town_identity`.

Regras (GDD 3.1): centro com área de leitura >= 25% da praça, tudo <= 6 m no raio de 20 m do hub, cor própria (nunca a
dos avisos de golpe: nada de vermelho-laranja saturado no chão), assimetria (cada quadrante um ofício).
Coordenadas do jogo (x, z), -z = norte; `rot` em graus = rotação Y do jogo (a mesma do zone_lib.box).
"""
import math
import types

from mathutils import Vector

from dress import Dress

# toldos da feira: 2 tons pastel alternados + listra creme (trigo e céu; longe do vermelho-laranja dos avisos)
AWN_A = (0.95, 0.80, 0.45)
AWN_B = (0.56, 0.72, 0.86)
AWN_STRIPE = (0.97, 0.94, 0.84)
FAIR_R = 7.6                 # raio do anel de bancas (roseta de ~18 m com os toldos)
FAIR_N = 8
MILL_R = 2.5                 # colisor da mó (com os pratos da balança)
MILL_H = 4.0
# o que cada banca vende (cor dos montinhos no balcão): pão, mel, verdura, queijo, peixe, pano, louça, flor
GOODS = [((0.86, 0.66, 0.38), (0.78, 0.56, 0.3)), ((0.93, 0.74, 0.28), (0.8, 0.6, 0.22)), ((0.5, 0.7, 0.38), (0.86, 0.5, 0.36)),
         ((0.95, 0.88, 0.6), (0.9, 0.8, 0.48)), ((0.62, 0.72, 0.8), (0.5, 0.6, 0.7)), ((0.7, 0.55, 0.8), (0.55, 0.72, 0.86)),
         ((0.8, 0.62, 0.5), (0.68, 0.5, 0.4)), ((0.92, 0.62, 0.76), (0.96, 0.9, 0.5))]


def shim(zone, P, coll, data, ob, rim_r, road_polys, rivers, river_w):
    """O que o `Dress` lê de uma `Zone`, para os builds antigos."""
    return types.SimpleNamespace(zone=zone, P=P, coll=coll, data=data, ob=ob, rim_r=rim_r, blocked=[], road_polys=road_polys,
                                 rivers=rivers, river_ws=[river_w] * len(rivers), seas=[])


def fair_stalls(r=FAIR_R, n=FAIR_N):
    """[(x, z, rot, ângulo)] das bancas da roseta: nos meios dos oitavos, as 4 ruas e as 4 diagonais ficam abertas."""
    out = []
    for k in range(n):
        th = math.radians(22.5 + 360.0 / n * k)
        out.append((math.cos(th) * r, math.sin(th) * r, 90.0 - math.degrees(th), th))
    return out


def _slab(d, g, m, c, pts, thick=0.05):
    """Chapa fina fechada por 4 pontos Blender (pano do toldo, tábua): 8 vértices, 6 faces."""
    bm = d._bm(g, m, c[0], c[1])
    up = Vector((0, 0, thick))
    v = [bm.verts.new(p) for p in pts] + [bm.verts.new(p + up) for p in pts]
    for a, b, cc, e in ((0, 1, 2, 3), (7, 6, 5, 4), (0, 4, 5, 1), (1, 5, 6, 2), (2, 6, 7, 3), (3, 7, 4, 0)):
        bm.faces.new((v[a], v[b], v[cc], v[e]))


def _tri(d, g, m, c, pts, thick=0.04, n=None):
    """Prisma triangular fino (dente da barra do toldo, empena do celeiro); `n` = direção da espessura (Blender)."""
    bm = d._bm(g, m, c[0], c[1])
    off = n if n is not None else Vector((0, 0, thick))
    v = [bm.verts.new(p) for p in pts] + [bm.verts.new(p + off) for p in pts]
    bm.faces.new((v[0], v[1], v[2]))
    bm.faces.new((v[5], v[4], v[3]))
    for a, b in ((0, 1), (1, 2), (2, 0)):
        bm.faces.new((v[a], v[b], v[b + 3], v[a + 3]))


def awning(d, c, rot, col, stripe, w=3.0, front=1.0, back=1.6, h=2.3, ridge=2.95, ridge_at=0.3, strips=6, g="feira"):
    """Toldo de duas águas com listras e barra em dentes (pano dobrado, nunca placa chata): `front` = quanto avança para o
    lado do freguês (yb < 0), `back` para o lado do feirante; a cumeeira corre ao longo do balcão."""
    f = Dress._xf(c, rot, (0, 0))
    wood = d.m("toldo_poste", (0.44, 0.32, 0.22))
    for sx in (-1, 1):
        for yb in (-front + 0.08, back - 0.08):
            p = f(sx * (w * 0.5 - 0.08), yb, 0)
            d.cyl(g, wood, (p.x, -p.y), 0.07, 0.07, h + 0.05, 0.0, 5)
        p = f(sx * (w * 0.5 - 0.08), ridge_at, 0)          # travessa da cumeeira
    a = d.m("pano_toldo_%d_%d" % (int(col[0] * 100), int(col[2] * 100)), col)
    b = d.m("pano_toldo_%d_%d" % (int(stripe[0] * 100), int(stripe[2] * 100)), stripe)
    sw = w / strips
    for i in range(strips):
        x0, x1 = -w * 0.5 + i * sw, -w * 0.5 + (i + 1) * sw
        m = a if i % 2 == 0 else b
        sag = 0.06 * math.sin(math.pi * (i + 0.5) / strips)          # o pano cede no meio do vão
        _slab(d, g, m, c, [f(x0, ridge_at, ridge), f(x1, ridge_at, ridge), f(x1, -front, h - sag), f(x0, -front, h - sag)])
        _slab(d, g, m, c, [f(x0, ridge_at, ridge), f(x1, ridge_at, ridge), f(x1, back, h - sag), f(x0, back, h - sag)])
        # barra em dentes na frente (lado do freguês)
        n = f(0, -0.04, 0) - f(0, 0, 0)
        _tri(d, g, m, c, [f(x0, -front, h - sag + 0.03), f(x1, -front, h - sag + 0.03), f((x0 + x1) * 0.5, -front, h - sag - 0.3)], n=n)


def stall(d, c, rot, col, goods, g="feira"):
    """Banca da feira: balcão com mercadoria e o toldo listrado. O lado yb > 0 (dentro da roseta) é o do feirante."""
    f = Dress._xf(c, rot, (0, 0))
    wood = d.m("banca_madeira", (0.6, 0.45, 0.3))
    top = d.m("banca_tampo", (0.76, 0.62, 0.42))
    d.box(g, wood, c, (2.6, 0.9, 0.9), rot, 0.0)
    d.box(g, top, c, (2.8, 0.07, 1.05), rot, 0.9)
    ga = d.m("merc_%d_%d" % (int(goods[0][0] * 100), int(goods[0][1] * 100)), goods[0])
    gb = d.m("merc_%d_%d" % (int(goods[1][0] * 100), int(goods[1][1] * 100)), goods[1])
    for i, x in enumerate((-0.95, -0.35, 0.3, 0.9)):
        p = f(x, -0.08 + 0.12 * (i % 2), 0)
        if i % 2 == 0:
            d.cyl(g, ga, (p.x, -p.y), 0.26, 0.14, 0.26, 0.97, 7)
        else:
            d.box(g, gb, (p.x, -p.y), (0.42, 0.2, 0.36), rot + 12.0 * i, 0.97)
    p = f(1.55, 0.5, 0)                                      # cesto ao lado do feirante
    d.cyl(g, d.m("cesto", (0.78, 0.62, 0.36)), (p.x, -p.y), 0.26, 0.34, 0.42, 0.0, 8)
    awning(d, c, rot, col, AWN_STRIPE)


def mill(d, c=(0.0, 0.0), rot=20.0, g="mo"):
    """Mó/Balança do Trigo: pedra redonda de 4 m, poste e braço de balança de 4,5 m com dois pratos (um de sacos)."""
    stone = d.m("mo_base", (0.82, 0.79, 0.72))
    dark = d.m("mo_pedra", (0.66, 0.63, 0.58))
    groove = d.m("mo_sulco", (0.52, 0.5, 0.47))
    wood = d.m("mo_madeira", (0.5, 0.36, 0.24))
    gold = d.m("mo_bronze", (0.86, 0.7, 0.32))
    d.cyl(g, stone, c, 2.1, 2.0, 0.45, 0.0, 14)
    d.cyl(g, dark, c, 1.75, 1.7, 0.4, 0.45, 14)
    for k in range(8):                                        # sulcos da mó (leitura de cima)
        d.box(g, groove, c, (3.2, 0.03, 0.12), 22.5 * k, 0.85)
    d.cyl(g, wood, c, 0.24, 0.18, 2.5, 0.85, 7)
    d.cyl(g, gold, c, 0.3, 0.3, 0.14, 3.3, 7)
    tilt = 7.0
    d.box(g, wood, c, (4.5, 0.16, 0.2), rot, 3.26, tilt=(0, tilt))
    # feixe de trigo no topo (o símbolo de Aldara)
    wheat = d.m("mo_trigo", (0.93, 0.78, 0.36))
    d.cyl(g, wheat, c, 0.1, 0.3, 0.5, 3.44, 6)
    d.cyl(g, gold, c, 0.14, 0.14, 0.08, 3.6, 6)
    f = Dress._xf(c, rot, (0, tilt))
    for s in (-1, 1):
        tip = f(s * 2.15, 0, 0.08, 3.26)
        pan_y = tip.z - 1.35
        pc = (tip.x, -tip.y)
        d.cyl(g, gold, pc, 0.62, 0.5, 0.1, pan_y, 9)
        for k in range(3):
            a = math.tau * k / 3 + 0.4
            d.tube(g, wood, [(pc[0], tip.z, pc[1]), (pc[0] + math.cos(a) * 0.52, pan_y + 0.1, pc[1] + math.sin(a) * 0.52)], 0.025)
        if pan_y < 1.95:                                      # o prato baixo leva os sacos; o alto, os pesos de ferro
            for k in range(3):
                a = math.tau * k / 3
                d.rock(g, d.m("saco_74", (0.74, 0.66, 0.48)), (pc[0] + math.cos(a) * 0.24, pc[1] + math.sin(a) * 0.24), 0.26, pan_y + 0.1, 0.8)
        else:
            iron = d.m("mo_peso", (0.3, 0.3, 0.34))
            d.cyl(g, iron, (pc[0] - 0.15, pc[1]), 0.2, 0.16, 0.3, pan_y + 0.1, 6)
            d.cyl(g, iron, (pc[0] + 0.2, pc[1] + 0.1), 0.14, 0.11, 0.22, pan_y + 0.1, 6)
    # sacos e cestos encostados na base
    for k, a in enumerate((0.5, 1.3, 2.9, 3.6, 4.4, 5.6)):
        p = (c[0] + math.cos(a) * 2.25, c[1] + math.sin(a) * 2.25)
        if k % 3 == 2:
            d.cyl(g, d.m("cesto", (0.78, 0.62, 0.36)), p, 0.28, 0.36, 0.4, 0.0, 8)
            d.cyl(g, wheat, p, 0.3, 0.2, 0.16, 0.4, 7)
        else:
            d.sack(p, 1.0, g)


def gable(d, g, wall, roof, c, L, W, h, ridge, rot, over=0.35, door=None):
    """Galpão baixo de duas águas: corpo L x W (L no x local), beiral em `h`, cumeeira em `ridge` ao longo de L."""
    f = Dress._xf(c, rot, (0, 0))
    d.box(g, wall, c, (L, h, W), rot, 0.0)
    for s in (-1, 1):                                         # empenas
        n = f(s * 0.08, 0, 0) - f(0, 0, 0)
        _tri(d, g, wall, c, [f(s * (L * 0.5 - 0.04), -W * 0.5, h), f(s * (L * 0.5 - 0.04), W * 0.5, h), f(s * (L * 0.5 - 0.04), 0, ridge - 0.05)], n=n)
    hl, hw = L * 0.5 + over, W * 0.5 + over
    drop = (ridge - h) * over / (W * 0.5)
    for s in (-1, 1):
        _slab(d, g, roof, c, [f(-hl, 0, ridge), f(hl, 0, ridge), f(hl, s * hw, h - drop), f(-hl, s * hw, h - drop)], 0.12)
    if door:
        dm = d.m("celeiro_porta", door)
        p = f(0, W * 0.5 + 0.03, 0)
        d.box(g, dm, (p.x, -p.y), (2.6, min(h - 0.2, 2.4), 0.1), rot, 0.0)


def aldara(z):
    """Feira do Trigo (centro), Pátio da Forja do Brom (NE), Celeiro e Carroças (S), Pátio do Fundador (N).
    Devolve o resumo gravado em data["town"]["centerpiece"]."""
    d = Dress(z, seed=71)
    ob = z.ob
    # --- chão: terra batida da feira em tons do próprio calçamento (acima da praça y 14 mm e das ruas 16 mm) ---
    floor = (0.72, 0.68, 0.6)
    t1 = d.m("patch_feira_a", tuple(k * 0.93 for k in floor))
    t2 = d.m("patch_feira_b", (0.78, 0.72, 0.6))
    d.blob("feira", t2, (0, 0), 10.6, 0.0172, 0.05)
    d.blob("feira", t1, (0, 0), 3.5, 0.0180, 0.08)

    # --- Feira do Trigo ---
    mill(d)
    ob("pillar", 0.0, 0.0, (MILL_R * 2, MILL_H, MILL_R * 2), visible=False)
    stalls = fair_stalls()
    for k, (x, zz, rot, th) in enumerate(stalls):
        stall(d, (x, zz), rot, AWN_A if k % 2 == 0 else AWN_B, GOODS[k % len(GOODS)])
        ob("stall", x, zz, (2.7, 1.6, 0.95), rot, visible=False)
    # duas carroças paradas descarregando, na borda da feira (fora das ruas radiais)
    carts = [((5.6, 12.5), 168.0), ((-12.8, -4.6), 68.0)]
    for (cx, cz), rot in carts:
        d.cart((cx, cz), rot, load=(0.8, 0.7, 0.46))
        a = math.radians(rot)
        ob("crate", cx + math.cos(a) * 0.7, cz - math.sin(a) * 0.7, (4.4, 1.3, 1.9), rot, visible=False)
        for i, (dx, dz) in enumerate(((-0.4, 1.7), (0.6, 1.9), (-1.3, 1.5))):
            p = (cx + dx * math.cos(a) + dz * math.sin(a), cz - dx * math.sin(a) + dz * math.cos(a))
            d.sack(p, 0.9 + 0.1 * i, "feira")

    # --- NE: Pátio da Forja do Brom (no lugar da casa do anel interno): pedra escura, fornalha, bigorna, lenha e carvão ---
    fx, fz = 9.4, -9.4
    out = Vector((fx, fz)).normalized()                      # para fora da praça
    side = Vector((-out.y, out.x))
    face = math.degrees(math.atan2(-fx, -fz))                # frente (+z do modelo) para a praça, como as casas
    yard = d.m("patch_forja_chao", (0.6, 0.57, 0.53))
    d.blob("forja", yard, (fx, fz), 5.0, 0.0188, 0.1)
    stone = d.m("forja_pedra", (0.56, 0.54, 0.54))
    stone_d = d.m("forja_pedra_esc", (0.42, 0.41, 0.43))
    fc = (fx + out.x * 2.6, fz + out.y * 2.6)                # fornalha no fundo do pátio
    d.box("forja", stone, fc, (2.6, 1.7, 2.0), face, 0.0)
    d.box("forja", stone_d, fc, (2.9, 0.18, 2.3), face, 1.7)
    ch = (fc[0] + out.x * 0.35, fc[1] + out.y * 0.35)
    d.cyl("forja", stone, ch, 0.62, 0.48, 1.9, 1.88, 7)
    d.cyl("forja", stone_d, ch, 0.56, 0.56, 0.14, 3.78, 7)
    mouth = (fc[0] - out.x * 1.02, fc[1] - out.y * 1.02)
    d.box("forja", d.m("glow_brasa", (1.0, 0.56, 0.2)), mouth, (1.1, 0.6, 0.12), face, 0.45)
    ob("crate", fc[0], fc[1], (2.9, 3.9, 2.3), face, visible=False)
    # telheiro de ardósia sobre a bigorna (4 postes, 3,1 m)
    slate = d.m("forja_telha", (0.4, 0.42, 0.5))
    rc = (fx + out.x * 0.2, fz + out.y * 0.2)
    rf = Dress._xf(rc, face, (0, 0))
    wood = d.m("forja_madeira", (0.44, 0.32, 0.22))
    for sx in (-1, 1):
        for sy in (-1, 1):
            p = rf(sx * 2.0, sy * 1.3, 0)
            d.cyl("forja", wood, (p.x, -p.y), 0.1, 0.1, 2.6 if sy > 0 else 3.0, 0.0, 5)
    _slab(d, "forja", slate, rc, [rf(-2.3, 1.6, 2.6), rf(2.3, 1.6, 2.6), rf(2.3, -1.6, 3.05), rf(-2.3, -1.6, 3.05)], 0.1)
    an = (fx - out.x * 0.9, fz - out.y * 0.9)                # bigorna no toco
    d.cyl("forja", wood, an, 0.36, 0.33, 0.5, 0.0, 8)
    iron = d.m("forja_ferro", (0.26, 0.26, 0.3))
    d.box("forja", iron, an, (0.78, 0.2, 0.3), face + 20.0, 0.5)
    d.box("forja", iron, an, (0.4, 0.16, 0.24), face + 20.0, 0.7)
    ob("pillar", an[0], an[1], (0.9, 0.9, 0.9), visible=False)
    wp = (fx + side.x * 3.4 + out.x * 1.2, fz + side.y * 3.4 + out.y * 1.2)      # pilha de lenha
    for i in range(5):
        d.log("forja", d.m("forja_lenha", (0.56, 0.4, 0.26)), (wp[0] + out.x * (i % 3 - 1) * 0.36, wp[1] + out.y * (i % 3 - 1) * 0.36),
              0.17, 1.7, face, y=0.17 + 0.3 * (i // 3))
    ob("crate", wp[0], wp[1], (1.9, 0.8, 1.3), face, visible=False)
    cp = (fx - side.x * 3.3 + out.x * 1.4, fz - side.y * 3.3 + out.y * 1.4)      # monte de carvão
    coal = d.m("forja_carvao", (0.2, 0.2, 0.23))
    for i in range(6):
        a = math.tau * i / 6
        d.rock("forja", coal, (cp[0] + math.cos(a) * 0.5, cp[1] + math.sin(a) * 0.5), 0.36, 0.0, 0.8)
    d.rock("forja", coal, cp, 0.5, 0.2, 0.9)
    ob("pillar", cp[0], cp[1], (1.9, 0.9, 1.9), visible=False)
    d.barrel((fx - side.x * 2.2 - out.x * 1.6, fz - side.y * 2.2 - out.y * 1.6), 1.0, g="forja", color=(0.5, 0.42, 0.36))      # tina de têmpera
    d.weapon_rack((fx + side.x * 2.5 - out.x * 1.3, fz + side.y * 2.5 - out.y * 1.3), face + 90.0, g="forja")

    # --- S: Celeiro e Carroças (no lugar de duas casas do anel externo, a oeste do portão sul) ---
    ba = math.radians(113.0)
    bc = (math.cos(ba) * 25.2, math.sin(ba) * 25.2)
    bface = math.degrees(math.atan2(-bc[0], -bc[1]))
    planks = d.m("celeiro_tabua", (0.62, 0.46, 0.33))
    straw = d.m("celeiro_palha", (0.88, 0.76, 0.44))
    gable(d, "celeiro", planks, straw, bc, 7.6, 5.0, 2.5, 4.0, bface, door=(0.36, 0.27, 0.2))
    ob("crate", bc[0], bc[1], (7.6, 4.0, 5.0), bface, visible=False)
    bin_ = Vector((-bc[0], -bc[1])).normalized()             # do celeiro para a praça
    bside = Vector((-bin_.y, bin_.x))
    yard2 = d.m("patch_celeiro_chao", (0.76, 0.68, 0.5))     # palha pisada na frente da porta
    d.blob("celeiro", yard2, (bc[0] + bin_.x * 3.6, bc[1] + bin_.y * 3.6), 3.4, 0.0188, 0.2)
    for i, (u, v) in enumerate(((3.1, 3.0), (3.1, 4.2), (-3.4, 3.1))):
        d.hay((bc[0] + bin_.x * u + bside.x * v * (1 if i < 2 else 0.9), bc[1] + bin_.y * u + bside.y * v * (1 if i < 2 else 0.9)), 1.0, "celeiro")
    # cercado das galinhas (um colisor redondo: ninguém atravessa a cerca)
    pa = math.radians(129.5)
    pc = (math.cos(pa) * 24.6, math.sin(pa) * 24.6)
    pr = 2.5
    d.blob("celeiro", yard2, pc, pr + 0.2, 0.0188, 0.1)
    ring = [(pc[0] + math.cos(math.tau * i / 8) * pr, pc[1] + math.sin(math.tau * i / 8) * pr) for i in range(9)]
    for i in range(8):
        d.fence_run(ring[i], ring[i + 1], 0.9, "celeiro", gap=1.9)
    d.hay((pc[0] + 0.5, pc[1] - 0.6), 0.8, "celeiro")
    d.box("celeiro", planks, (pc[0] - 0.8, pc[1] + 0.7), (1.3, 0.3, 0.45), 30.0, 0.0)      # cocho
    ob("pillar", pc[0], pc[1], (pr * 2 + 0.3, 1.0, pr * 2 + 0.3), visible=False)

    # --- N: Pátio do Fundador (no lugar de uma casa do anel externo, a leste do portão norte) ---
    sa = math.radians(286.0)
    sc = (math.cos(sa) * 25.0, math.sin(sa) * 25.0)
    pale = d.m("patch_fundador_chao", (0.8, 0.77, 0.7))
    d.blob("fundador", pale, sc, 3.8, 0.0188, 0.08)
    d.cyl("fundador", d.m("fundador_base", (0.8, 0.78, 0.74)), sc, 1.25, 1.1, 0.35, 0.0, 10)
    for i in range(6):                                        # canteiro de trigo em volta do pedestal
        a = math.tau * i / 6 + 0.3
        d.tuft("fundador", d.m("fundador_trigo", (0.9, 0.76, 0.36)), (sc[0] + math.cos(a) * 1.9, sc[1] + math.sin(a) * 1.9), 0.3, 0.6, 5)

    d.flush()
    return {"kind": "feira_do_trigo", "mill": [0.0, 0.0], "mill_r": MILL_R, "height": MILL_H, "stall_r": FAIR_R,
            "stalls": [[round(x, 2), round(zz, 2), round(rot, 1)] for x, zz, rot, _ in stalls],
            "carts": [[c[0], c[1], rot] for c, rot in carts],
            "forge": [fx, fz], "barn": [round(bc[0], 2), round(bc[1], 2)], "pen": [round(pc[0], 2), round(pc[1], 2), pr],
            "founder": [round(sc[0], 2), round(sc[1], 2)], "max_height": 4.0}


# ---------------------------------------------------------------------------------------------------------------------
# Posto dos Caçadores (field_forest): Fogueira Comunal + roda de carroças dos refugiados + varal de peles + Trompa do Cerco
# ---------------------------------------------------------------------------------------------------------------------
WAGON_R = 6.8                # raio da roda de carroças em volta da fogueira
WAGON_DEG = (50.0, 140.0, -130.0, -40.0)      # nos quatro cantos: as quatro ruas dos portões ficam abertas
FIRE_R = 2.5                 # anel de pedras da fogueira (5 m)


def wagon(d, c, rot, canvas=(0.9, 0.87, 0.78), g="carroca"):
    """Carroça de refugiado parada, coberta de lona em arco (de cima: retângulo claro). 3,2 x 1,7 m, sem varais."""
    f = Dress._xf(c, rot, (0, 0))
    wood = d.m("refugio_madeira", (0.5, 0.38, 0.27))
    wheel = d.m("carreta_roda", (0.26, 0.2, 0.16))
    cloth = d.m("pano_lona_%d" % int(canvas[0] * 100), canvas)
    seam = d.m("pano_lona_costura", tuple(k * 0.86 for k in canvas))
    d.box(g, wood, c, (3.2, 0.2, 1.6), rot, 0.62)
    for s in (-1, 1):
        p = f(0, s * 0.82, 0)
        d.box(g, wood, (p.x, -p.y), (3.2, 0.42, 0.08), rot, 0.8)
        for x in (-1.0, 1.0):
            q = f(x, s * 0.92, 0)
            d.cyl(g, wheel, (q.x, -q.y), 0.56, 0.56, 0.12, 0.56, 8, rot, tilt=(90, 0))
    # lona em arco: 5 gomos ao longo da carroça, cada um com 6 panos (dobra em cada aro)
    n, segs, r, base = 5, 6, 0.86, 1.2
    for i in range(n):
        x0, x1 = -1.6 + 3.2 * i / n, -1.6 + 3.2 * (i + 1) / n
        for k in range(segs):
            a0, a1 = math.pi * k / segs, math.pi * (k + 1) / segs
            bulge = 1.0 + (0.05 if i % 2 == 0 else 0.0)
            _slab(d, g, cloth if (i + k) % 5 else seam, c,
                  [f(x0, math.cos(a0) * r, base + math.sin(a0) * r * bulge), f(x1, math.cos(a0) * r, base + math.sin(a0) * r * bulge),
                   f(x1, math.cos(a1) * r, base + math.sin(a1) * r * bulge), f(x0, math.cos(a1) * r, base + math.sin(a1) * r * bulge)], 0.04)
    d.box(g, wood, c, (3.2, 0.4, 0.06), rot, 0.8)


def posto(z, hub):
    """Centro do Posto: fogueira grande com o caldeirão da Bia, roda de 4 carroças de lona, varais de peles (SO) e a Trompa
    do Cerco junto ao portão norte. Devolve o resumo gravado em data["town"]["centerpiece"]."""
    d = Dress(z, seed=83)
    hx, hz = hub
    H = lambda r, a: (hx + math.cos(math.radians(a)) * r, hz + math.sin(math.radians(a)) * r)
    # --- fogueira comunal: anel de pedras de 5 m, lenha em pirâmide, chama (prop de fogo: a cor quente é do fogo, não do chão) ---
    ash = d.m("patch_fogueira_cinza", (0.42, 0.38, 0.34))
    d.blob("fogueira", ash, hub, FIRE_R - 0.3, 0.0205, 0.12)
    stone = d.m("fogueira_pedra", (0.58, 0.55, 0.52))
    for k in range(14):
        a = math.tau * k / 14
        d.rock("fogueira", stone, (hx + math.cos(a) * FIRE_R, hz + math.sin(a) * FIRE_R), 0.42, 0.0, 0.75)
    wood = d.m("fogueira_lenha", (0.4, 0.29, 0.2))
    for k in range(5):
        a = 36.0 + 72.0 * k
        q = H(0.55, a)
        d.cyl("fogueira", wood, q, 0.14, 0.11, 1.9, 0.05, 6, -a, tilt=(0, 58))
    fire = d.m("glow_brasa", (1.0, 0.56, 0.2))
    d.cyl("fogueira", fire, hub, 0.95, 0.0, 2.3, 0.2, 7)
    for k in range(3):
        d.cyl("fogueira", fire, H(0.6, 120.0 * k + 20.0), 0.45, 0.0, 1.3, 0.15, 6)
    z.ob("pillar", hx, hz, (3.6, 2.4, 3.6), visible=False)
    # caldeirão da Bia num tripé, na beira do anel (lado sul, virado para as casas dos refugiados)
    cq = H(FIRE_R + 0.9, 135.0)
    iron = d.m("caldeirao", (0.24, 0.23, 0.25))
    for k in range(3):
        a = math.tau * k / 3
        d.tube("fogueira", iron, [(cq[0] + math.cos(a) * 0.7, 0.0, cq[1] + math.sin(a) * 0.7), (cq[0], 1.7, cq[1])], 0.04)
    d.cyl("fogueira", iron, cq, 0.34, 0.5, 0.5, 0.45, 9)
    d.cyl("fogueira", d.m("caldeirao_sopa", (0.62, 0.5, 0.3)), cq, 0.44, 0.44, 0.04, 0.9, 9)
    z.ob("pillar", cq[0], cq[1], (1.2, 1.7, 1.2), visible=False)
    # troncos de sentar em volta do fogo (não colidem)
    for a in (10.0, 190.0, 250.0, 310.0):
        q = H(FIRE_R + 1.15, a)
        d.log("fogueira", wood, q, 0.24, 1.7, 90.0 - a)
    # --- roda de carroças dos refugiados ---
    wagons = []
    for i, a in enumerate(WAGON_DEG):
        c = H(WAGON_R, a)
        rot = -a - 90.0                     # ao longo da tangente
        wagon(d, c, rot, canvas=((0.9, 0.87, 0.78), (0.86, 0.82, 0.7))[i % 2])
        z.ob("crate", c[0], c[1], (3.3, 2.1, 1.9), rot, visible=False)
        wagons.append([round(c[0], 2), round(c[1], 2), round(rot, 1)])
    # --- varais de peles (SO, na frente das casas): moldura e couros ocre, sem colisor ---
    hide = [d.m("pele_a", (0.74, 0.58, 0.36)), d.m("pele_b", (0.66, 0.5, 0.32)), d.m("pele_c", (0.8, 0.68, 0.48))]
    pole = d.m("varal_pau", (0.44, 0.33, 0.24))
    racks = []
    for i, (r, a) in enumerate(((13.2, 127.0), (13.2, 153.0))):
        c = H(r, a)
        rot = -a - 90.0
        f = Dress._xf(c, rot, (0, 0))
        for sx in (-1.3, 1.3):
            p = f(sx, 0, 0)
            d.cyl("varal", pole, (p.x, -p.y), 0.07, 0.06, 2.0, 0.0, 5)
        d.box("varal", pole, c, (2.8, 0.07, 0.07), rot, 1.95)
        for k, sx in enumerate((-0.85, 0.0, 0.85)):          # couros esticados, inclinados (lê de cima como retângulos ocre)
            _slab(d, "varal", hide[(i + k) % 3], c, [f(sx - 0.36, -0.05, 1.9), f(sx + 0.36, -0.05, 1.9), f(sx + 0.3, 0.62, 0.75), f(sx - 0.3, 0.62, 0.75)], 0.04)
        racks.append([round(c[0], 2), round(c[1], 2)])
    # --- Trompa do Cerco: chifre grande num cavalete, junto ao portão norte (de onde vêm os elfos) ---
    hq = H(19.0, -77.0)
    for sx in (-0.45, 0.45):
        d.cyl("trompa", pole, (hq[0] + sx, hq[1]), 0.08, 0.07, 1.5, 0.0, 5, tilt=(0, 12.0 if sx < 0 else -12.0))
    bone = d.m("trompa_chifre", (0.9, 0.86, 0.74))
    d.tube("trompa", bone, [(hq[0] - 0.9, 1.35, hq[1]), (hq[0] - 0.3, 1.5, hq[1]), (hq[0] + 0.4, 1.75, hq[1]), (hq[0] + 0.9, 2.2, hq[1])], 0.09, 0.3, 7)
    d.cyl("trompa", d.m("trompa_aro", (0.8, 0.62, 0.3)), (hq[0] - 0.3, hq[1]), 0.15, 0.15, 0.08, 1.46, 7, tilt=(0, 78))
    d.flush()
    return {"kind": "fogueira_comunal", "fire": [hx, hz], "fire_r": FIRE_R, "wagon_r": WAGON_R, "wagons": wagons, "racks": racks,
            "horn": [round(hq[0], 2), round(hq[1], 2)], "max_height": 2.6}
