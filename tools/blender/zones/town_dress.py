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
# Aldara (2026-11-21): as bancas saíram da praça e foram para a rua do mercado (avenida leste); a praça ficou só com a
# Balança do Trigo. O feirante fica atrás do balcão, a FAIR_KEEP m do centro dele.
FAIR_KEEP = 1.4
MILL_R = 2.1                 # colisor da mó (com os pratos da balança; era 2,5)
MILL_H = 4.0
# o que cada banca vende (cor dos montinhos no balcão): pão, mel, verdura, queijo, peixe, pano, louça, flor
GOODS = [((0.86, 0.66, 0.38), (0.78, 0.56, 0.3)), ((0.93, 0.74, 0.28), (0.8, 0.6, 0.22)), ((0.5, 0.7, 0.38), (0.86, 0.5, 0.36)),
         ((0.95, 0.88, 0.6), (0.9, 0.8, 0.48)), ((0.62, 0.72, 0.8), (0.5, 0.6, 0.7)), ((0.7, 0.55, 0.8), (0.55, 0.72, 0.86)),
         ((0.8, 0.62, 0.5), (0.68, 0.5, 0.4)), ((0.92, 0.62, 0.76), (0.96, 0.9, 0.5))]


def shim(zone, P, coll, data, ob, rim_r, road_polys, rivers, river_w):
    """O que o `Dress` lê de uma `Zone`, para os builds antigos."""
    return types.SimpleNamespace(zone=zone, P=P, coll=coll, data=data, ob=ob, rim_r=rim_r, blocked=[], road_polys=road_polys,
                                 rivers=rivers, river_ws=[river_w] * len(rivers), seas=[])


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


def awning(d, c, rot, col, stripe, w=3.0, front=0.85, back=1.0, h=2.3, ridge=2.8, ridge_at=0.08, strips=6, g="feira"):
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
    """Banca da feira: balcão com mercadoria e o toldo listrado. O lado yb > 0 é o do feirante (fora do anel: o toldo é
    curto atrás para ele aparecer na câmera)."""
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
    """Mó/Balança do Trigo: pedra redonda de 3,5 m, poste e braço de balança de 3,8 m com dois pratos (um de sacos)."""
    stone = d.m("mo_base", (0.82, 0.79, 0.72))
    dark = d.m("mo_pedra", (0.66, 0.63, 0.58))
    groove = d.m("mo_sulco", (0.52, 0.5, 0.47))
    wood = d.m("mo_madeira", (0.5, 0.36, 0.24))
    gold = d.m("mo_bronze", (0.86, 0.7, 0.32))
    d.cyl(g, stone, c, 1.75, 1.67, 0.45, 0.0, 14)
    d.cyl(g, dark, c, 1.45, 1.4, 0.4, 0.45, 14)
    for k in range(8):                                        # sulcos da mó (leitura de cima)
        d.box(g, groove, c, (2.65, 0.03, 0.12), 22.5 * k, 0.85)
    d.cyl(g, wood, c, 0.24, 0.18, 2.5, 0.85, 7)
    d.cyl(g, gold, c, 0.3, 0.3, 0.14, 3.3, 7)
    tilt = 7.0
    d.box(g, wood, c, (3.8, 0.16, 0.2), rot, 3.26, tilt=(0, tilt))
    # feixe de trigo no topo (o símbolo de Aldara)
    wheat = d.m("mo_trigo", (0.93, 0.78, 0.36))
    d.cyl(g, wheat, c, 0.1, 0.3, 0.5, 3.44, 6)
    d.cyl(g, gold, c, 0.14, 0.14, 0.08, 3.6, 6)
    f = Dress._xf(c, rot, (0, tilt))
    for s in (-1, 1):
        tip = f(s * 1.8, 0, 0.08, 3.26)
        pan_y = tip.z - 1.35
        pc = (tip.x, -tip.y)
        d.cyl(g, gold, pc, 0.55, 0.44, 0.1, pan_y, 9)
        for k in range(3):
            a = math.tau * k / 3 + 0.4
            d.tube(g, wood, [(pc[0], tip.z, pc[1]), (pc[0] + math.cos(a) * 0.46, pan_y + 0.1, pc[1] + math.sin(a) * 0.46)], 0.025)
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
        p = (c[0] + math.cos(a) * 1.9, c[1] + math.sin(a) * 1.9)
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


def _frame(pos, rot):
    """(direita, frente) -> jogo (x, z), no referencial de um prédio: a frente (porta) aponta para (sin rot, cos rot)."""
    a = math.radians(rot)
    return lambda r, f: (pos[0] + math.cos(a) * r + math.sin(a) * f, pos[1] - math.sin(a) * r + math.cos(a) * f)


def counter(d, c, rot, col, goods, g="feira", w=2.4):
    """Balcão de loja com toldo curto (o da Botica e o do Tobias): como a banca, o lado de quem atende é yb > 0."""
    f = Dress._xf(c, rot, (0, 0))
    wood = d.m("banca_madeira", (0.6, 0.45, 0.3))
    top = d.m("banca_tampo", (0.76, 0.62, 0.42))
    d.box(g, wood, c, (w, 0.9, 0.8), rot, 0.0)
    d.box(g, top, c, (w + 0.2, 0.07, 0.95), rot, 0.9)
    for i, x in enumerate((-0.8, -0.3, 0.25, 0.75)):
        p = f(x * w / 2.4, -0.05 + 0.1 * (i % 2), 0)
        col_ = goods[i % len(goods)]
        m = d.m("frasco_%d_%d" % (int(col_[0] * 100), int(col_[2] * 100)), col_)
        if i % 2 == 0:
            d.cyl(g, m, (p.x, -p.y), 0.13, 0.1, 0.3, 0.97, 6)
            d.cyl(g, d.m("frasco_rolha", (0.6, 0.46, 0.3)), (p.x, -p.y), 0.05, 0.05, 0.08, 1.27, 5)
        else:
            d.box(g, m, (p.x, -p.y), (0.36, 0.2, 0.3), rot + 10.0 * i, 0.97)
    awning(d, c, rot, col, AWN_STRIPE, w=w + 0.4, front=0.8, back=0.7)


def table_set(d, c, g="taverna"):
    """Mesa de barril com tampo redondo e três banquinhos (terraço da taverna)."""
    wood = d.m("taverna_madeira", (0.56, 0.4, 0.26))
    top = d.m("taverna_tampo", (0.72, 0.56, 0.36))
    d.barrel(c, 1.0, g=g)
    d.cyl(g, top, c, 0.7, 0.7, 0.07, 1.0, 10)
    d.cyl(g, d.m("taverna_caneca", (0.8, 0.74, 0.6)), (c[0] + 0.25, c[1] - 0.1), 0.09, 0.09, 0.16, 1.07, 6)
    for k in range(3):
        a = math.tau * k / 3 + 0.5
        d.cyl(g, wood, (c[0] + math.cos(a) * 1.15, c[1] + math.sin(a) * 1.15), 0.22, 0.2, 0.45, 0.0, 7)


def aldara(z, lay):
    """A vila de Aldara (2026-11-21): praça da Balança do Trigo no meio e um bairro por lado. `lay` vem do build
    (prédios, avenidas, pátio, celeiro...). Aqui ficam os adereços de cada bairro, os colisores deles, e os POSTOS de quem
    atende: cada NPC de serviço fica do lado de fora, na porta/balcão do prédio dele.
    Devolve o resumo gravado em data["town"]["centerpiece"] (o MapsCatalog espelha à mão o que é dele; há check)."""
    d = Dress(z, seed=71)
    ob = z.ob
    spot = lay["spot"]
    B_ = lay["buildings"]
    posts, clear, doors = {}, [], {}

    def post(nid, p, facing):
        posts[nid] = [round(p[0], 2), round(p[1], 2), round(facing, 1)]

    for bid in ("elder", "smithy", "botica", "tavern", "home"):      # casas que abrem (MapsCatalog.INTERIORS): porta e saída livres
        doors[bid] = [list(spot(bid, 0.0, 0.9)), list(spot(bid, 0.0, 2.8))]
        clear.extend([spot(bid, 0.0, 0.9), spot(bid, 0.0, 2.8)])

    # ------------------------------------------------------------------ praça: a Balança do Trigo e chão livre
    floor = (0.72, 0.68, 0.6)
    t1 = d.m("patch_feira_a", tuple(k * 0.93 for k in floor))
    t2 = d.m("patch_feira_b", (0.78, 0.72, 0.6))
    d.blob("feira", t2, (0, 0), lay["plaza_r"] - 1.6, 0.0172, 0.05)
    d.blob("feira", t1, (0, 0), 3.0, 0.0180, 0.08)
    mill(d)
    ob("pillar", 0.0, 0.0, (MILL_R * 2, MILL_H, MILL_R * 2), visible=False)
    for a in (45.0, 135.0, 225.0, 315.0):                             # bancos na borda (não colidem)
        p = (math.cos(math.radians(a)) * (lay["plaza_r"] - 0.9), math.sin(math.radians(a)) * (lay["plaza_r"] - 0.9))
        ob("bench", p[0], p[1], (1.6, 0.5, 0.5), 90.0 - a, solid=False)
    crystal = (-6.4, 5.2)                                             # Cristal de Retorno (MapsCatalog.CRYSTALS)
    clear.append(crystal)
    post("board", (4.8, -10.8), -24.0)                                # Quadro de Avisos, na boca da avenida norte

    # ------------------------------------------------------------------ N: Casa do Ancião, pátio de treino, Quartel, Fundador
    post("elder", spot("elder", -2.4, 1.2), B_["elder"]["rot"])
    for r_ in (2.2, 2.8):                                             # vasos de flor junto à porta do Ancião
        p = spot("elder", r_, 0.45)
        d.cyl("anciao", d.m("vaso", (0.72, 0.5, 0.38)), p, 0.2, 0.26, 0.34, 0.0, 7)
        d.tuft("anciao", d.m("vaso_flor", (0.72, 0.56, 0.86)), p, 0.2, 0.5, 5)
    yx, yz, yr = lay["yard"]
    earth = d.m("patch_treino_pisado", (0.66, 0.54, 0.4))
    d.blob("treino", earth, (yx, yz), yr - 1.6, 0.0172, 0.12)
    dummies = [(round(yx + 2.2, 2), round(yz + 0.2, 2)), (round(yx - 0.6, 2), round(yz - 2.2, 2)), (round(yx - 2.6, 2), round(yz + 0.8, 2))]
    clear.extend(dummies)
    ring = [(yx + math.cos(math.radians(a)) * yr, yz + math.sin(math.radians(a)) * yr) for a in range(150, 351, 25)]      # cerca: oeste e norte (aberto para a avenida e a praça)
    for i in range(len(ring) - 1):
        d.fence_run(ring[i], ring[i + 1], 1.0, "treino", gap=1.3)
        m_ = ((ring[i][0] + ring[i + 1][0]) * 0.5, (ring[i][1] + ring[i + 1][1]) * 0.5)
        ob("fence", m_[0], m_[1], (yr * math.radians(25.0) + 0.1, 1.0, 0.3), -(150.0 + 25.0 * i + 12.5) - 90.0, visible=False)
    d.target((yx + 1.6, yz - yr + 1.1), 0.0, "treino")
    d.target((yx - 2.9, yz - yr + 1.9), 30.0, "treino")
    d.weapon_rack((yx - yr + 1.0, yz - 1.6), 90.0, "treino")
    ob("crate", yx - yr + 1.0, yz - 1.6, (0.6, 1.5, 2.4), 0.0, visible=False)
    trainer = (round(yx + 3.6, 2), round(yz + 3.6, 2))                # Mestra de Skills (MapsCatalog.TRAINERS): na beira do pátio, do lado da avenida
    clear.append(trainer)
    qrot = B_["quartel"]["rot"]
    post("captain", spot("quartel", -1.9, 1.1), qrot)
    blue = (0.3, 0.42, 0.75)
    for r_ in (-5.5, 5.5):
        d.flag(spot("quartel", r_, 0.2), blue, h=4.4, rot=qrot, tatter=False, w=1.1, drop=1.6)
    p = spot("quartel", 3.2, 0.55)
    d.weapon_rack(p, qrot, "quartel")
    ob("crate", p[0], p[1], (2.4, 1.5, 0.6), qrot, visible=False)
    p = spot("quartel", -3.9, 0.6)
    d.barrel(p, 1.0, g="quartel")
    d.crate((p[0] + 0.2, p[1] - 0.9), 0.8, 12.0, g="quartel")
    # Pátio do Fundador: a estátua é o NPC `founder_statue`; aqui o pedestal, o canteiro de trigo, bancos e flores
    fdx, fdz = lay["founder"]
    d.cyl("fundador", d.m("fundador_base", (0.8, 0.78, 0.74)), (fdx, fdz), 1.25, 1.1, 0.35, 0.0, 10)
    for i in range(6):
        a = math.tau * i / 6 + 0.3
        d.tuft("fundador", d.m("fundador_trigo", (0.9, 0.76, 0.36)), (fdx + math.cos(a) * 1.9, fdz + math.sin(a) * 1.9), 0.3, 0.6, 5)
    for s_ in (-1, 1):
        ob("bench", fdx + 2.9 * s_, fdz + 1.6, (1.6, 0.5, 0.5), 90.0 - 25.0 * s_, solid=False)
    ob("flowers", fdx + 2.6, fdz - 2.0, (1.6, 0.45, 1.6), solid=False, color=(0.92, 0.8, 0.4))
    ob("flowers", fdx - 2.6, fdz - 1.8, (1.6, 0.45, 1.6), solid=False, color=(0.72, 0.56, 0.86))

    # ------------------------------------------------------------------ L: Mercado (rua de bancas, loja do Tobias, Relicária, Armazém)
    av_e = lay["avenues"]["E"]
    az = lambda x: min(av_e, key=lambda q: abs(q.x - x)).y
    stalls, keeper_posts, front_posts = [], [], []
    for k, (x, side, goods) in enumerate(lay["stalls"]):
        zz = az(x) + side * lay["stall_off"]
        rot = 0.0 if side < 0 else 180.0                              # o freguês fica do lado da avenida
        stall(d, (x, zz), rot, AWN_A if k % 2 == 0 else AWN_B, GOODS[goods % len(GOODS)])
        ob("stall", x, zz, (2.7, 1.6, 0.95), rot, visible=False)
        stalls.append([round(x, 2), round(zz, 2), rot])
        # fila do sul: o feirante fica atrás do balcão (a câmera olha do sul e o vê); fila do norte: atrás ele sumia
        # debaixo do toldo, então fica na ponta leste do balcão
        keeper_posts.append([round(x, 2), round(zz + FAIR_KEEP, 2)] if side > 0 else [round(x + 2.2, 2), round(zz - 0.3, 2)])
        front_posts.append([round(x, 2), round(zz - side * 2.0, 2)])
    clear.extend(keeper_posts)
    # loja do Tobias: balcão com toldo dourado na frente (ele atende atrás do balcão, de costas para a loja), placa, carga
    tc = spot("tobias", 1.6, 2.3)
    counter(d, tc, 0.0, (0.93, 0.7, 0.3), [(0.8, 0.3, 0.3), (0.86, 0.66, 0.38), (0.4, 0.56, 0.84), (0.74, 0.62, 0.42)], g="feira", w=2.6)
    ob("stall", tc[0], tc[1], (2.8, 1.6, 0.9), 0.0, visible=False)
    stalls.append([round(tc[0], 2), round(tc[1], 2), 0.0])
    post("merchant", spot("tobias", 4.0, 2.2), -15.0)                  # na ponta do balcão (atrás dele o toldo o escondia da câmera)
    front_posts.append([round(tc[0], 2), round(tc[1] + 1.9, 2)])
    d.signpost(spot("tobias", -3.0, 1.3), 20.0, n=1)
    p = spot("tobias", -2.3, 0.75)
    d.cargo(p, 5, 1.1, g="feira")
    ob("crate", p[0], p[1], (2.4, 1.3, 1.5), 0.0, visible=False)
    d.rug(spot("tobias", 1.6, 4.0), 2.6, 1.3, 0.0, (0.62, 0.3, 0.3), (0.9, 0.8, 0.5), g="feira")
    # Relicária da Iara: pedestais com cristais dourados acesos, flâmulas roxas e degrau claro
    rrot = B_["relic"]["rot"]
    post("relic", spot("relic", -2.1, 1.0), rrot)
    step = d.m("reliquia_degrau", (0.88, 0.86, 0.8))
    d.box("reliquia", step, spot("relic", 0.0, 0.45), (2.6, 0.16, 0.9), rrot, 0.0)
    for r_ in (2.2, 3.4):
        p = spot("relic", r_, 0.7 if r_ < 3.0 else 0.2)
        d.cyl("reliquia", step, p, 0.42, 0.36, 0.7, 0.0, 8)
        gm = d.m("glow_reliquia", (1.0, 0.82, 0.4))
        d.cyl("reliquia", gm, p, 0.2, 0.13, 0.55, 0.7, 5)
        d.cyl("reliquia", gm, p, 0.13, 0.0, 0.3, 1.25, 5)
        ob("pillar", p[0], p[1], (0.9, 1.4, 0.9), visible=False)
    for r_ in (-3.6, 3.9):
        d.flag(spot("relic", r_, -0.4), (0.56, 0.4, 0.72), h=4.4, rot=rrot, tatter=False, w=1.0, drop=1.7)
    # Armazém do Nilo (guarda-volumes): pilhas de carga dos dois lados da porta, carroça de mão ao lado
    arot = B_["armazem"]["rot"]
    post("storage", spot("armazem", 2.3, 1.0), arot)
    p = spot("armazem", -2.5, 0.7)
    d.cargo(p, 6, 1.0, g="armazem")
    ob("crate", p[0], p[1], (2.2, 1.4, 1.3), arot, visible=False)
    carts = []
    p = spot("armazem", 5.5, -1.6)                                    # do lado sul (o lado norte fica livre: é a boca da avenida leste)
    d.cart(p, arot + 90.0, load=(0.8, 0.7, 0.46))
    ob("crate", p[0], p[1], (2.0, 1.3, 4.4), arot, visible=False)
    carts.append([round(p[0], 2), round(p[1], 2), round(arot + 90.0, 1)])
    # Jardim do Poço (canto sudeste do miolo): o poço, duas árvores, bancos e flores
    wx, wz = lay["well"]
    d.blob("jardim", d.m("patch_jardim", (0.44, 0.62, 0.37)), (wx, wz), 5.6, 0.0172, 0.16)
    ob("well", wx + 0.4, wz - 0.4, (1.6, 1.4, 1.6))
    ob("tree", wx - 3.0, wz + 2.6, (1.6, 3.7, 1.6), color=(0.40, 0.66, 0.38))
    ob("tree", wx + 3.6, wz - 2.6, (1.6, 3.8, 1.6), color=(0.30, 0.52, 0.34))
    ob("bench", wx - 1.8, wz - 2.4, (1.6, 0.5, 0.5), 20.0, solid=False)
    ob("bench", wx + 2.4, wz + 1.8, (1.6, 0.5, 0.5), 110.0, solid=False)
    ob("flowers", wx + 1.2, wz + 3.2, (1.6, 0.45, 1.6), solid=False, color=(0.92, 0.62, 0.76))
    ob("flowers", wx - 3.4, wz - 1.2, (1.5, 0.45, 1.5), solid=False, color=(0.96, 0.9, 0.5))

    # ------------------------------------------------------------------ O: Ofícios (Ferraria do Brom e Botica da Lyra)
    # Ferraria: a casa É a Oficina (interior); ao lado, a fornalha com chaminé e o telheiro de ardósia com a bigorna na frente
    srot = B_["smithy"]["rot"]
    sf = _frame(B_["smithy"]["pos"], srot)
    half = B_["smithy"]["size"][2] * 0.5
    stone = d.m("forja_pedra", (0.56, 0.54, 0.54))
    stone_d = d.m("forja_pedra_esc", (0.42, 0.41, 0.43))
    fc = sf(5.6, half - 2.0)                                          # fornalha, recuada ao lado da casa
    d.box("forja", stone, fc, (2.6, 1.7, 2.0), srot, 0.0)
    d.box("forja", stone_d, fc, (2.9, 0.18, 2.3), srot, 1.7)
    ch = sf(5.6, half - 2.35)
    d.cyl("forja", stone, ch, 0.62, 0.48, 1.9, 1.88, 7)
    d.cyl("forja", stone_d, ch, 0.56, 0.56, 0.14, 3.78, 7)
    d.box("forja", d.m("glow_brasa", (1.0, 0.56, 0.2)), sf(5.6, half - 0.98), (1.1, 0.6, 0.12), srot, 0.45)
    ob("crate", fc[0], fc[1], (2.9, 3.9, 2.3), srot, visible=False)
    slate = d.m("forja_telha", (0.4, 0.42, 0.5))
    wood = d.m("forja_madeira", (0.44, 0.32, 0.22))
    rc = sf(5.4, half + 0.9)                                          # telheiro: 4 postes, cai para a frente
    rf = Dress._xf(rc, srot, (0, 0))
    for sx in (-1, 1):
        for sy in (-1, 1):
            p = rf(sx * 2.0, sy * 1.3, 0)
            d.cyl("forja", wood, (p.x, -p.y), 0.1, 0.1, 3.0 if sy > 0 else 2.6, 0.0, 5)
    _slab(d, "forja", slate, rc, [rf(-2.3, 1.6, 3.05), rf(2.3, 1.6, 3.05), rf(2.3, -1.6, 2.6), rf(-2.3, -1.6, 2.6)], 0.1)
    an = sf(5.0, half + 1.5)                                          # bigorna no toco, na frente
    d.cyl("forja", wood, an, 0.36, 0.33, 0.5, 0.0, 8)
    iron = d.m("forja_ferro", (0.26, 0.26, 0.3))
    d.box("forja", iron, an, (0.78, 0.2, 0.3), srot + 20.0, 0.5)
    d.box("forja", iron, an, (0.4, 0.16, 0.24), srot + 20.0, 0.7)
    ob("pillar", an[0], an[1], (0.9, 0.9, 0.9), visible=False)
    post("smith", sf(2.6, half + 2.6), srot + 12.0)                   # Brom, ao lado da bigorna, de frente para a rua
    cp = sf(7.9, half + 0.3)                                          # monte de carvão
    coal = d.m("forja_carvao", (0.2, 0.2, 0.23))
    for i in range(6):
        a = math.tau * i / 6
        d.rock("forja", coal, (cp[0] + math.cos(a) * 0.5, cp[1] + math.sin(a) * 0.5), 0.36, 0.0, 0.8)
    d.rock("forja", coal, cp, 0.5, 0.2, 0.9)
    ob("pillar", cp[0], cp[1], (1.9, 0.9, 1.9), visible=False)
    wp = sf(-4.5, half - 0.6)                                         # lenha encostada do outro lado da casa
    for i in range(5):
        d.log("forja", d.m("forja_lenha", (0.56, 0.4, 0.26)), (wp[0] + (i % 3 - 1) * 0.36, wp[1]), 0.17, 1.7, srot + 90.0, y=0.17 + 0.3 * (i // 3))
    ob("crate", wp[0], wp[1], (1.3, 0.8, 1.9), srot, visible=False)
    bq = sf(7.0, half + 2.7)
    d.barrel(bq, 1.0, g="forja", color=(0.5, 0.42, 0.36))             # tina de têmpera
    ob("pillar", bq[0], bq[1], (0.9, 1.0, 0.9), visible=False)
    p = sf(-2.3, half + 0.45)
    d.weapon_rack(p, srot, g="forja")
    ob("crate", p[0], p[1], (2.4, 1.5, 0.6), srot, visible=False)
    # Botica: balcão de frascos com toldo verde (a Lyra atende atrás dele), caldeirão no tripé, canteiro de ervas e varal
    brot = B_["botica"]["rot"]
    bc_ = spot("botica", 2.9, 2.0)
    counter(d, bc_, brot, (0.5, 0.74, 0.52), [(0.4, 0.8, 0.5), (0.62, 0.42, 0.8), (0.86, 0.6, 0.3), (0.4, 0.62, 0.86)], g="botica")
    ob("stall", bc_[0], bc_[1], (2.6, 1.6, 0.9), brot, visible=False)
    post("alchemist", spot("botica", 1.0, 1.9), brot)                 # na ponta sul do balcão, ao lado da porta (fora do toldo)
    front_botica = spot("botica", 1.0, 3.6)
    cq = spot("botica", -2.6, 1.5)
    ironc = d.m("caldeirao", (0.24, 0.23, 0.25))
    for k in range(3):
        a = math.tau * k / 3
        d.tube("botica", ironc, [(cq[0] + math.cos(a) * 0.7, 0.0, cq[1] + math.sin(a) * 0.7), (cq[0], 1.7, cq[1])], 0.04)
    d.cyl("botica", ironc, cq, 0.34, 0.5, 0.5, 0.45, 9)
    d.cyl("botica", d.m("glow_pocao", (0.4, 0.9, 0.5)), cq, 0.44, 0.44, 0.04, 0.9, 9)
    ob("pillar", cq[0], cq[1], (1.2, 1.7, 1.2), visible=False)
    bf = _frame(B_["botica"]["pos"], brot)
    gc = bf(-4.7, 1.9)                                                # canteiro de ervas, do lado sul da casa
    soil = d.m("patch_canteiro", (0.46, 0.38, 0.3))
    gf = _frame(gc, brot)
    d.box("botica", soil, gc, (2.6, 0.02, 3.6), brot, 0.02)
    herb = [d.m("erva_a", (0.36, 0.62, 0.36)), d.m("erva_b", (0.5, 0.72, 0.42)), d.m("erva_flor", (0.72, 0.56, 0.86)), d.m("erva_azul", (0.45, 0.62, 0.9))]
    for i in range(3):
        for j in range(5):
            d.tuft("botica", herb[(i * 2 + j) % 4], gf(-0.85 + 0.85 * i, -1.4 + 0.7 * j), 0.22, 0.5, 5)
    fr = [gf(-1.5, -2.0), gf(1.5, -2.0), gf(1.5, 2.0), gf(-1.5, 2.0), gf(-1.5, -2.0)]
    for i in range(4):
        d.fence_run(fr[i], fr[i + 1], 0.6, "botica", gap=1.0)
    ob("crate", gc[0], gc[1], (3.1, 0.7, 4.1), brot, visible=False)

    # ------------------------------------------------------------------ S: Taverna, celeiro e cercado, casas de morar
    trot = B_["tavern"]["rot"]
    tables = [spot("tavern", -3.0, 2.3), spot("tavern", 2.9, 2.2), spot("tavern", -3.4, 3.9)]
    for p in tables:
        table_set(d, p)
        ob("pillar", p[0], p[1], (1.4, 1.1, 1.4), visible=False)
    p = spot("tavern", 3.7, 0.5)
    d.barrel(p, 1.1, g="taverna")
    d.barrel((p[0] + 0.5, p[1] + 0.7), 1.0, g="taverna")
    ob("crate", p[0] + 0.2, p[1] + 0.3, (1.5, 1.1, 1.6), trot, visible=False)
    d.signpost(spot("tavern", -1.6, 0.5), trot + 90.0, g="taverna", n=1)
    d.torch(spot("tavern", 1.5, 0.35), 2.3, g="taverna")
    # Celeiro e Carroças: a porta olha para a avenida sul (a carroça da colheita para na frente)
    bx, bz, bface = lay["barn"]
    bc = (bx, bz)
    planks = d.m("celeiro_tabua", (0.62, 0.46, 0.33))
    straw = d.m("celeiro_palha", (0.88, 0.76, 0.44))
    gable(d, "celeiro", planks, straw, bc, 7.6, 5.0, 2.5, 4.0, bface, door=(0.36, 0.27, 0.2))
    ob("crate", bc[0], bc[1], (7.6, 4.0, 5.0), bface, visible=False)
    ba = math.radians(bface)
    bin_ = Vector((-math.sin(ba), -math.cos(ba)))                     # para onde a porta olha
    bside = Vector((-bin_.y, bin_.x))
    yard2 = d.m("patch_celeiro_chao", (0.76, 0.68, 0.5))              # palha pisada na frente da porta
    d.blob("celeiro", yard2, (bc[0] + bin_.x * 4.4, bc[1] + bin_.y * 4.4), 3.6, 0.0188, 0.2)
    for i, (u, v) in enumerate(((3.1, 3.0), (3.1, 4.1), (3.2, -3.4))):
        d.hay((bc[0] + bin_.x * u + bside.x * v, bc[1] + bin_.y * u + bside.y * v), 1.0, "celeiro")
    hs = (bc[0] + bin_.x * 3.1 + bside.x * 3.55, bc[1] + bin_.y * 3.1 + bside.y * 3.55)
    ob("crate", hs[0], hs[1], (1.5, 1.4, 2.6), bface, visible=False)
    cart_stop = (round(bc[0] + bin_.x * 5.6, 2), round(bc[1] + bin_.y * 5.6, 2))      # onde a Carroça da Colheita para (LIVING_NPCS)
    clear.append(cart_stop)
    pcx, pcz, pr = lay["pen"]
    pc = (pcx, pcz)
    d.blob("celeiro", yard2, pc, pr + 0.2, 0.0188, 0.1)
    ring = [(pc[0] + math.cos(math.tau * i / 8) * pr, pc[1] + math.sin(math.tau * i / 8) * pr) for i in range(9)]
    for i in range(8):
        d.fence_run(ring[i], ring[i + 1], 0.9, "celeiro", gap=1.9)
    d.hay((pc[0] + 0.5, pc[1] - 0.6), 0.8, "celeiro")
    d.box("celeiro", planks, (pc[0] - 0.8, pc[1] + 0.7), (1.3, 0.3, 0.45), 30.0, 0.0)      # cocho
    ob("pillar", pc[0], pc[1], (pr * 2 + 0.3, 1.0, pr * 2 + 0.3), visible=False)
    # casas de morar: canteiros de flor na frente, varais e árvores nos vãos entre as casas do sul
    bloom = [(0.92, 0.8, 0.4), (0.92, 0.62, 0.76), (0.72, 0.56, 0.86), (0.96, 0.9, 0.5)]
    homes = lay["homes"]
    for k, (hp, hrot, w) in enumerate(homes):
        hf = _frame(hp, hrot)
        if hp[1] > 8.0:                                               # bairro residencial (sul): jardim na frente
            q = hf(-w * 0.5 + 0.9, 2.5 + 0.75)
            ob("flowers", q[0], q[1], (1.3, 0.45, 1.3), solid=False, color=bloom[k % 4])
            q = hf(w * 0.5 - 0.8, 2.5 + 0.7)
            d.cyl("casas", d.m("vaso", (0.72, 0.5, 0.38)), q, 0.2, 0.26, 0.34, 0.0, 7)
            d.tuft("casas", d.m("vaso_flor_%d" % (k % 4), bloom[(k + 1) % 4]), q, 0.2, 0.5, 5)
    gaps = []
    for k in range(len(homes) - 1):
        (pa, _, wa), (pb, _, wb) = homes[k], homes[k + 1]
        if pa[1] > 8.0 and pb[1] > 8.0 and (Vector(pa) - Vector(pb)).length < 10.5:
            gaps.append((Vector(pa) + Vector(pb)) * 0.5)
    for k, g_ in enumerate(gaps):
        out = g_.normalized()
        tan = Vector((-out.y, out.x))
        if k % 2 == 0:
            q = g_ + out * 1.2
            ob("tree", q.x, q.y, (1.6, 3.8, 1.6), color=(0.40, 0.66, 0.38) if k % 4 == 0 else (0.30, 0.52, 0.34))
        else:
            a_, b_ = g_ + out * 0.9 - tan * 1.25, g_ + out * 0.9 + tan * 1.25
            d.laundry((a_.x, a_.y), (b_.x, b_.y), 2.3, "casas")
    for q in ((-17.2, -18.6), (18.0, -20.8)):                         # árvores nos cantos do miolo (noroeste e nordeste)
        ob("tree", q[0], q[1], (1.6, 3.8, 1.6), color=(0.30, 0.52, 0.34))
    pol = lambda deg, r: (math.cos(math.radians(deg)) * r, math.sin(math.radians(deg)) * r)
    for k, q in enumerate((pol(-69.0, 36.4), pol(-62.5, 34.6), pol(159.5, 35.2), pol(203.0, 35.0), (-9.6, 12.6), pol(248.0, 35.6), pol(21.5, 36.0))):
        ob("tree", q[0], q[1], (1.6 + 0.1 * (k % 3), 3.8 + 0.2 * (k % 3), 1.6 + 0.1 * (k % 3)), color=(0.40, 0.66, 0.38) if k % 2 else (0.30, 0.52, 0.34))
    # horta do celeiro (lote vazio a oeste do portão sul): leiras de terra com verdura e um espantalho
    hc = pol(111.0, 35.2)
    hrot = math.degrees(math.atan2(-hc[0], -hc[1]))
    hf = _frame(hc, hrot)
    d.box("horta", d.m("patch_canteiro", (0.46, 0.38, 0.3)), hc, (4.6, 0.02, 3.2), hrot, 0.02)
    veg = [d.m("horta_a", (0.36, 0.62, 0.36)), d.m("horta_b", (0.56, 0.72, 0.4)), d.m("horta_c", (0.86, 0.56, 0.3))]
    for i in range(6):
        for j in range(4):
            d.tuft("horta", veg[(i + j) % 3], hf(-1.9 + 0.76 * i, -1.1 + 0.74 * j), 0.2, 0.42, 5)
    fr = [hf(-2.5, -1.8), hf(2.5, -1.8), hf(2.5, 1.8), hf(-2.5, 1.8), hf(-2.5, -1.8)]
    for i in range(4):
        d.fence_run(fr[i], fr[i + 1], 0.6, "horta", gap=1.1)
    ob("crate", hc[0], hc[1], (5.1, 0.7, 3.7), hrot, visible=False)
    d.scarecrow(hf(0.0, 0.0), hrot, g="horta")

    # relvado: manchas de dois tons (só aparecem onde não há rua nem chão de bairro por cima)
    lawn = [d.m("patch_relva_a", (0.45, 0.63, 0.37)), d.m("patch_relva_b", (0.55, 0.71, 0.43))]
    for k in range(34):
        a = math.radians(k * 137.5)
        r_ = 13.0 + (k * 7.3) % 26.0
        d.blob("relva", lawn[k % 2], (math.cos(a) * r_, math.sin(a) * r_), 2.2 + (k % 4) * 0.7, 0.0078 + 0.0005 * (k % 2), 0.22)

    d.flush()
    # pontos de bot: miolo aberto da praça, bocas das avenidas, mercado, terraço da taverna, forja, botica, pátio, jardim
    hang = [[3.6, 3.6], [-3.6, 3.6], [-3.6, -3.6], [3.6, -3.6], [0.0, 7.4], [7.4, 0.6], [-7.4, -0.8], [0.0, -7.4], [6.6, 6.2], [-6.4, -6.2],
            [0.0, 10.8], [15.4, 0.4], [21.4, 1.2], [27.2, -0.6], [2.6, 18.6], [-16.2, -3.2], [-13.6, 5.6], [-4.4, -12.6],
            [wx - 0.6, wz + 1.8], [0.4, 27.4], [-1.2, -26.6], [-26.4, 0.8]]
    views = {"praca": (0.0, 2.0), "norte": (-6.0, -25.0), "mercado": (21.0, -3.0), "sul": (0.0, 24.0), "oficios": (-19.0, -1.0)}
    return {"kind": "balanca_do_trigo", "mill": [0.0, 0.0], "mill_r": MILL_R, "height": MILL_H, "plaza_r": lay["plaza_r"],
            "stalls": stalls, "keeper_posts": keeper_posts, "front_posts": front_posts + [[round(front_botica[0], 2), round(front_botica[1], 2)]],
            "carts": carts, "cart_stop": list(cart_stop),
            "forge": [round(an[0], 2), round(an[1], 2)], "chimney": [round(ch[0], 2), round(ch[1], 2)],
            "barn": [round(bc[0], 2), round(bc[1], 2)], "pen": [round(pc[0], 2), round(pc[1], 2), pr],
            "founder": [round(fdx, 2), round(fdz, 2)], "well": [round(wx + 0.4, 2), round(wz - 0.4, 2)],
            "yard": [yx, yz, yr], "dummies": [list(q) for q in dummies], "trainer": list(trainer), "crystal": list(crystal),
            "buildings": {k: [v["pos"][0], v["pos"][1], v["rot"]] for k, v in B_.items()}, "doors": doors,
            "posts": posts, "clear": [[round(q[0], 2), round(q[1], 2)] for q in clear], "hangouts": [[round(h[0], 2), round(h[1], 2)] for h in hang],
            "views": views, "max_height": 4.4}


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


# Faixa élfica viva (GDD elf-band-living 3.4): o Posto esvazia depois do Rei. Dois lotes com `tag` (MapDef.conquest_vis de
# field_forest): guerra (`unless: el6_king`) = esteiras de dormir em volta das 4 carroças + a carroça do Simão; paz
# (`if: el6_king`) = só as esteiras de quem ficou (Dalva e Bento, a família do mercado) e, no lugar da carroça que partiu,
# a carga que ela deixou (mesma pegada: o colisor oculto fica no lote neutro e vale para os dois). Nada aqui colide.
POSTO_WAR, POSTO_PEACE = "posto_guerra_det", "posto_paz_det"
POSTO_LEAVER = 3             # índice em WAGON_DEG: a carroça do canto nordeste (lado da garganta) vai embora
WAGON_DRAWS = 32             # sorteios que uma carroça gasta no lote (4 rodas x 8 lados do `cyl`)
# esteiras por carroça: (raio, ângulo) a partir do centro, atrás da roda de carroças e fora das ruas, dos NPCs de serviço,
# dos bonecos de treino, da bigorna e das bancas; a esteira fica deitada no raio, cabeça para fora
POSTO_BEDS = (((9.2, 63.0), (9.6, 33.0)), ((8.9, 127.0), (8.9, 154.0)), ((8.6, -112.0), (9.2, -155.0)), ((9.0, -45.0), (8.8, -19.0)))
POSTO_BEDS_PEACE = ((0, 0), (1, 0), (1, 1))          # (carroça, esteira) que continuam depois do Rei
BED_COLS = (((0.62, 0.32, 0.27), (0.86, 0.8, 0.66)), ((0.4, 0.48, 0.6), (0.82, 0.8, 0.72)), ((0.74, 0.6, 0.36), (0.5, 0.36, 0.26)),
            ((0.44, 0.54, 0.4), (0.84, 0.78, 0.6)))


class _OneLot(Dress):
    """Lote de conquista pequeno: tudo numa malha por tipo (o centro do Posto cai no canto de 4 células de 36 m)."""

    def _bm(self, g, m, x, z):
        return Dress._bm(self, g, m, 0.0, 0.0)

    def _bm_cloth(self, m, x, z):
        return Dress._bm_cloth(self, m, 0.0, 0.0)


def bedroll(d, c, rot, k=0, bundle=False, g="esteira"):
    """Esteira de dormir de refugiado: manta de lã com listra, rolo de travesseiro na cabeça e, às vezes, a trouxa ao lado.
    1,75 x 0,72 m, rente ao chão (de cima: retângulo de cor surrada). `rot` = ao longo da esteira (cabeça em +x)."""
    col, stripe = BED_COLS[k % len(BED_COLS)]
    wool = d.m("esteira_la_%d" % k, col)
    band = d.m("esteira_listra_%d" % k, stripe)
    a = math.radians(rot)
    ux, uz = math.cos(a), -math.sin(a)
    at = lambda t, s=0.0: (c[0] + ux * t - uz * s, c[1] + uz * t + ux * s)
    d.box(g, d.m("esteira_palha", (0.7, 0.62, 0.42)), c, (1.85, 0.04, 0.8), rot, 0.0)
    d.box(g, wool, at(-0.12), (1.5, 0.07, 0.72), rot, 0.03)
    for t in (-0.62, 0.3):
        d.box(g, band, at(t), (0.16, 0.075, 0.73), rot, 0.03)
    d.log(g, band, at(0.74), 0.11, 0.62, rot + 90.0)
    if bundle:
        d.sack(at(0.5, 0.72), 0.7, g, color=(0.66, 0.58, 0.44))
        d.box(g, wool, at(-0.3, 0.66), (0.5, 0.16, 0.34), rot + 20.0, 0.0)


def left_cargo(d, c, rot, canvas, g="carga"):
    """O que a carroça que partiu deixou para o Posto, na pegada dela (3,3 x 1,9 m): caixotes, barril, sacos e a lona dobrada."""
    a = math.radians(rot)
    ux, uz = math.cos(a), -math.sin(a)
    at = lambda t, s=0.0: (c[0] + ux * t - uz * s, c[1] + uz * t + ux * s)
    d.crate(at(-1.05, 0.15), 1.0, rot + 6.0, 0.0, g)
    d.crate(at(-0.05, -0.3), 0.9, rot - 10.0, 0.0, g)
    d.crate(at(-0.95, 0.1), 0.6, rot + 30.0, 1.0, g)
    d.barrel(at(1.05, 0.35), 1.05, 0.0, g)
    d.sack(at(0.95, -0.5), 1.1, g)
    d.sack(at(0.1, 0.55), 1.0, g)
    d.sack(at(-0.3, 0.62), 0.8, g, color=(0.66, 0.58, 0.44))
    lona = d.m("pano_lona_%d" % int(canvas[0] * 100), canvas)
    d.box(g, lona, at(-0.05, -0.3), (0.8, 0.14, 0.6), rot + 4.0, 0.9)
    d.box(g, d.m("pano_lona_costura", tuple(k * 0.86 for k in canvas)), at(-0.05, -0.3), (0.82, 0.05, 0.2), rot + 4.0, 1.04)


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
    war, peace = _OneLot(z, seed=84, tag=POSTO_WAR), _OneLot(z, seed=85, tag=POSTO_PEACE)
    for i, a in enumerate(WAGON_DEG):
        c = H(WAGON_R, a)
        rot = -a - 90.0                     # ao longo da tangente
        canvas = ((0.9, 0.87, 0.78), (0.86, 0.82, 0.7))[i % 2]
        if i == POSTO_LEAVER:               # a carroça que parte depois do Rei: lote de guerra; o neutro gasta os mesmos sorteios
            wagon(war, c, rot, canvas=canvas)
            for _ in range(WAGON_DRAWS):
                d.rnd.random()
            left_cargo(peace, c, rot, canvas)
        else:
            wagon(d, c, rot, canvas=canvas)
        z.ob("crate", c[0], c[1], (3.3, 2.1, 1.9), rot, visible=False)
        wagons.append([round(c[0], 2), round(c[1], 2), round(rot, 1)])
        for k, (br, ba) in enumerate(POSTO_BEDS[i]):          # esteiras: cheias na guerra, só as de quem ficou na paz
            bedroll(war, H(br, ba), -ba, i * 2 + k, bundle=(k == 0))
            if (i, k) in POSTO_BEDS_PEACE:
                bedroll(peace, H(br, ba), -ba, i * 2 + k, bundle=(k == 0))
    war.flush()
    peace.flush()
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
