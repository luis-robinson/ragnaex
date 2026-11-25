"""Acabamento do Viveiro de Seiva (dg_viveiro; Brejo das Teias, GDD brejo-das-teias 3.8-3.9): o berçário élfico de mudas
da Árvore-Mãe sob a raiz. Chamado pelo build_dungeons (tabela `DRESS`), depois da rocha e antes do `z.finish`; os salões
e as ligações vêm de places.DUNGEONS["dg_viveiro"].

Cada salão lê-se de cima pela cor do chão e pelo que há na parede:
  raizes  (Raízes Encharcadas)  madeira úmida escura, raízes grossas que saem da parede, poças FOSCAS, cogumelos âmbar
  estufa  (Estufa das Mudas)    musgo verde, canteiros de mudas em arco, caixilhos de vidro na parede
  tanques (Sala dos Tanques)    pedra élfica cinza-esverdeada, tanques de vidro altos na parede, canos no chão até os 3
                                pousos dos Tanques de Seiva (lacaios `sap_tank`, um spawner por pouso)
  berco   (O Berço)             madeira viva âmbar com anéis de crescimento pintados, raízes rasas no chão (só desenho),
                                tanques partidos na parede; miolo livre (clear_r)

Regras de chão (art review 2026-11-13): tinta de chão só em tons do PRÓPRIO chão; a seiva ACESA (`glow_seiva`, âmbar,
nunca vermelha) fica nos tanques, veios, gotas e em poças pequenas coladas na parede (fora da luta), nunca em anel.

Pilha de planos nos salões (mm): praça 14 · chão do salão 20 · manchas 22,2-22,6 · anéis 23,0 · borda da poça 23,6 ·
poça de seiva 24,0.

Grava data["boss_hint"]: `tanks` = os 3 pousos da Sala dos Tanques, `adds` = os 4 pousos dos tanques-ovo no Berço, `clear_r`.
"""
import math

from mathutils import Vector

from act2_dress import Halls
from act3_dress import P, tang, stains, opposite, _hint, _floors
from dress import Dress

SAP = (0.95, 0.75, 0.3)            # places.DUNGEONS["dg_viveiro"]["glow"]
BARK = (0.36, 0.26, 0.17)
BARK_L = (0.48, 0.36, 0.24)
STONE = (0.5, 0.52, 0.48)          # pedra élfica de raiz
STONE_D = (0.38, 0.4, 0.37)
BRONZE = (0.62, 0.5, 0.3)
GLASS = (0.74, 0.86, 0.8)
LEAF = (0.42, 0.62, 0.34)
LEAF_L = (0.62, 0.78, 0.4)
SOIL = (0.3, 0.24, 0.19)
POOL_Y = 0.0240
TANK_PADS = 3
EGG_R = 7.0                        # = boss_sap_mother.eggs["r"] (monsters_catalog): raio do anel de tanques-ovo no Berço


def _ang(a, b):
    return abs(math.atan2(math.sin(a - b), math.cos(a - b)))


def root(d, a, b, r0=0.5, r1=0.12, lift=0.9, g="raiz", m=None, wob=1.0):
    """Raiz que sai de `a` (grossa, alta) e rasteja até `b` (fina, no chão), ondulando."""
    m = m or d.m("raiz_casca", BARK)
    a, b = Vector(a), Vector(b)
    t = b - a
    n = Vector((-t.y, t.x)).normalized()
    ph = d.rnd.uniform(0, math.tau)
    pts = []
    k = 7
    for i in range(k + 1):
        u = i / k
        q = a + t * u + n * math.sin(u * math.pi * 1.6 + ph) * wob * (0.2 + u) * 0.5
        y = lift * (1.0 - u) ** 2 + r0 * 0.35 * (1.0 - u) + 0.04 + 0.22 * math.sin(u * math.pi * 3.0) ** 2 * (1.0 - u)
        pts.append((q.x, y, q.y))
    d.tube(g, m, pts, r0, r1, 6)


def sap_lamp(d, c, h=2.4, lean=0.0):
    """Luminária do viveiro: haste de raiz curvada com uma gota de seiva acesa pendurada."""
    bark = d.m("raiz_clara", BARK_L)
    dx, dz = math.cos(lean) * 0.6, math.sin(lean) * 0.6
    d.tube("luz", bark, [(c[0], 0.0, c[1]), (c[0] - dx * 0.2, h * 0.55, c[1] - dz * 0.2), (c[0] + dx * 0.3, h, c[1] + dz * 0.3), (c[0] + dx, h * 0.96, c[1] + dz)], 0.12, 0.05, 5)
    q = (c[0] + dx, c[1] + dz)
    glow = d.m("glow_seiva", SAP)
    d.cyl("luz", glow, q, 0.2, 0.06, 0.26, h * 0.96 - 0.5, 5)
    d.cyl("luz", glow, q, 0.06, 0.2, 0.2, h * 0.96 - 0.7, 5)


def sap_tank(d, c, s=1.0, rot=0.0, broken=False, g="tanque"):
    """Tanque de seiva: soco de pedra élfica, coluna de seiva acesa atrás de aros e montantes de bronze, tampa de raiz.
    `broken` = vidro partido: coluna baixa, cacos e o resto da muda seca."""
    st, st_d = d.m("pedra_elfica", STONE), d.m("pedra_elfica_esc", STONE_D)
    br = d.m("bronze_viveiro", BRONZE)
    glass = d.m("vidro_viveiro", GLASS)
    glow = d.m("glow_seiva", SAP)
    h = (0.9 if broken else 2.5) * s
    d.cyl(g, st_d, c, 1.05 * s, 0.95 * s, 0.22, 0.0, 8, rot)
    d.cyl(g, st, c, 0.9 * s, 0.82 * s, 0.26, 0.22, 8, rot)
    d.cyl(g, glow, c, 0.62 * s, 0.62 * s, h, 0.48, 8, rot)
    for k in range(4):
        q = P(c, 0.72 * s, rot + 45.0 + 90.0 * k)
        d.cyl(g, br, q, 0.07 * s, 0.07 * s, h + 0.1, 0.44, 4)
    for y in ((0.48,) if broken else (0.48, 0.48 + h * 0.5, 0.48 + h - 0.12)):
        d.cyl(g, br, c, 0.76 * s, 0.76 * s, 0.12, y, 8, rot)
    if broken:
        for k in range(5):                                   # cacos em pé na borda e no chão
            q = P(c, 0.66 * s, rot + 72.0 * k + 20.0)
            d.cyl(g, glass, q, 0.2 * s, 0.0, d.rnd.uniform(0.5, 1.1) * s, 0.5 + h * 0.6, 3, d.rnd.uniform(0, 120), (d.rnd.uniform(-14, 14), d.rnd.uniform(-14, 14)))
        for k in range(4):
            q = P(c, d.rnd.uniform(1.3, 2.0) * s, d.rnd.uniform(0, 360))
            d.box(g, glass, q, (0.4 * s, 0.03, 0.26 * s), d.rnd.uniform(0, 180), 0.024)
        d.cyl(g, d.m("raiz_casca", BARK), c, 0.14 * s, 0.04 * s, 1.2 * s, 0.48 + h, 5, 0.0, (d.rnd.uniform(-20, 20), d.rnd.uniform(-20, 20)))
    else:
        d.cyl(g, glass, c, 0.68 * s, 0.68 * s, 0.1, 0.48 + h * 0.25, 8, rot)
        d.cyl(g, glass, c, 0.68 * s, 0.68 * s, 0.1, 0.48 + h * 0.75, 8, rot)
        d.cyl(g, d.m("raiz_casca", BARK), c, 0.84 * s, 0.3 * s, 0.34 * s, 0.48 + h, 8, rot)
        d.cyl(g, d.m("raiz_clara", BARK_L), c, 0.3 * s, 0.1 * s, 0.3 * s, 0.82 * s + h + 0.1, 6, rot)
        for k in range(3):                                   # folhas da muda saindo pela tampa
            d.cyl(g, d.m("folha_muda", LEAF_L), c, 0.16 * s, 0.0, 0.7 * s, 0.9 * s + h, 3, 120.0 * k + rot, (34, 0))


def sap_pool(d, c, r, floor_dark, g="poca"):
    """Poça de seiva acesa (pequena, colada na parede) com a borda escura do próprio chão por baixo."""
    d.blob(g, floor_dark, c, r * 1.3, POOL_Y - 0.0004, 0.3)
    d.blob(g, d.m("glow_seiva", SAP), c, r, POOL_Y, 0.28)


def planter(d, c, rot, L=3.0, g="canteiro"):
    """Canteiro de mudas: caixa baixa de casca, terra e uma fileira de mudas (duas folhas e o broto âmbar)."""
    d.box(g, d.m("canteiro", BARK_L), c, (L, 0.42, 1.1), rot, 0.0)
    d.box(g, d.m("canteiro_terra", SOIL), c, (L - 0.24, 0.06, 0.86), rot, 0.4)
    a = math.radians(rot)
    n = max(2, int(L / 0.7))
    for i in range(n):
        u = (i + 0.5) / n - 0.5
        q = (c[0] + math.cos(a) * u * (L - 0.5), c[1] - math.sin(a) * u * (L - 0.5))
        hh = d.rnd.uniform(0.3, 0.6)
        d.cyl(g, d.m("muda_caule", LEAF), q, 0.05, 0.03, hh, 0.44, 4)
        for k in (0, 1):
            d.cyl(g, d.m("folha_muda", LEAF_L), q, 0.14, 0.0, 0.34, 0.44 + hh, 3, rot + 180.0 * k + 30.0, (48, 0))
        if i % 2 == 0:
            d.cyl(g, d.m("glow_seiva", SAP), q, 0.07, 0.0, 0.16, 0.5 + hh, 4)


def glass_frame(d, c, rot, w=2.4, h=2.0, g="caixilho"):
    """Caixilho de estufa encostado na parede: moldura de bronze e painéis de vidro inclinados."""
    br, glass = d.m("bronze_viveiro", BRONZE), d.m("vidro_viveiro", GLASS)
    d.box(g, br, c, (w, 0.14, 0.5), rot, 0.0)
    d.box(g, glass, c, (w - 0.2, h, 0.06), rot, 0.14, (-16, 0))
    for k in (-1, 0, 1):
        q = (c[0] + math.cos(math.radians(rot)) * k * (w * 0.5 - 0.06), c[1] - math.sin(math.radians(rot)) * k * (w * 0.5 - 0.06))
        d.box(g, br, q, (0.1, h + 0.1, 0.1), rot, 0.1, (-16, 0))


def viveiro(z, rooms, edges):
    _floors(z, rooms)
    d = Dress(z, 811)
    rnd = d.rnd
    h = Halls(d, rooms, edges)
    T = {name: h.tones(name, 0.12) for name in rooms}
    bark, bark_l = d.m("raiz_casca", BARK), d.m("raiz_clara", BARK_L)
    glow = d.m("glow_seiva", SAP)
    for name, room in rooms.items():                         # manchas em tons do chão e raízes finas coladas na parede
        stains(d, h, name, room, int(room["r"] * (0.4 if name == "berco" else 0.8)), "viv", 0.06, 0.9, 2.0)
        for (p, a) in h.rim(name, int(room["r"] * 1.1), 0.98, 1.06, 0.4):
            q = P(room["pos"], room["r"] * rnd.uniform(0.84, 0.93), math.degrees(a) + rnd.uniform(-9, 9))
            root(d, p, q, rnd.uniform(0.28, 0.42), 0.08, rnd.uniform(1.2, 2.2), m=bark if rnd.random() < 0.6 else bark_l, wob=0.6)

    def side(q, ang):
        k = rnd.random()
        if k < 0.34:
            sap_lamp(d, q, rnd.uniform(2.1, 2.6), ang + math.pi * 0.5)
        elif k < 0.6:
            for _ in range(rnd.randint(2, 4)):
                d.mushroom((q[0] + rnd.uniform(-0.5, 0.5), q[1] + rnd.uniform(-0.5, 0.5)), rnd.uniform(0.6, 1.1), (0.96, 0.78, 0.36))
        elif k < 0.84:
            t = (math.cos(ang), math.sin(ang))
            root(d, (q[0] - t[0] * 1.6, q[1] - t[1] * 1.6), (q[0] + t[0] * 1.6, q[1] + t[1] * 1.6), 0.3, 0.1, 0.5, wob=0.5)
        else:
            sap_tank(d, q, 0.55, rnd.uniform(0, 90), g="tanque_mini")
    h.corridor(side, every=3.2)
    cx, cy = rooms["chegada"]["pos"]
    for s in (-1, 1):                                        # chegada: arco de raízes sobre a saída e duas luminárias
        sap_lamp(d, (cx + s * 4.6, cy + 1.5), 2.8, math.pi * (0.5 + 0.5 * s))
        d.tube("arco", bark, [(cx + s * 3.4, 0.0, cy + 6.6), (cx + s * 3.0, 1.8, cy + 6.3), (cx + s * 1.8, 3.4, cy + 6.1), (cx - s * 0.4, 4.0, cy + 6.0)], 0.5, 0.16, 6)
        d.tube("arco", glow, [(cx + s * 3.3, 0.3, cy + 6.2), (cx + s * 2.9, 1.8, cy + 5.92), (cx + s * 1.8, 3.3, cy + 5.74)], 0.09, 0.04, 4)

    # ---- Raízes Encharcadas: raízes grossas saindo da parede até o meio do salão (colidem só junto à parede), poças
    #      foscas escuras, cogumelos âmbar e gotas de seiva em duas raízes ----
    room = rooms["raizes"]
    x, y = room["pos"]
    r = room["r"]
    wet = [d.m("patch_raizes_agua_a", (0.27, 0.27, 0.24)), d.m("patch_raizes_agua_b", (0.33, 0.32, 0.27))]
    for i in range(9):
        q = P((x, y), rnd.uniform(1.5, r * 0.78), rnd.uniform(0, 360))
        d.blob("raizes", wet[i % 2], q, rnd.uniform(1.0, 2.3), 0.0222 + (i % 2) * 0.0004, 0.35, sx=rnd.uniform(1.0, 1.5), rot=rnd.uniform(0, 180))
    for j, (p, a) in enumerate(h.rim("raizes", 9, 0.98, 1.02, 0.55)):
        q = P((x, y), r * rnd.uniform(0.5, 0.62), math.degrees(a) + rnd.uniform(-14, 14))
        root(d, p, q, rnd.uniform(0.7, 0.95), 0.14, rnd.uniform(1.6, 2.6), wob=1.6)
        s = P((x, y), r * 0.88, math.degrees(a))
        d.solid(s[0], s[1], 2.0, 2.0, 1.6)
        if j % 3 == 0:
            sap_pool(d, P((x, y), r * 0.86, math.degrees(a) + 11.0), 0.7, T["raizes"][1])
    for (p, a) in h.rim("raizes", 12, 0.72, 0.86, 0.5):
        if h.put(p, 0.5):
            for _ in range(rnd.randint(2, 4)):
                d.mushroom((p[0] + rnd.uniform(-0.6, 0.6), p[1] + rnd.uniform(-0.6, 0.6)), rnd.uniform(0.6, 1.3), (0.96, 0.78, 0.36))

    # ---- Estufa das Mudas: canteiros em dois arcos (o de dentro baixo e sem colisor fica fora do miolo), caixilhos de
    #      vidro e luminárias na parede ----
    room = rooms["estufa"]
    x, y = room["pos"]
    r = room["r"]
    back = opposite(h, "estufa")
    for j, (p, a) in enumerate(h.rim("estufa", 12, 0.82, 0.86, 0.5)):
        if not h.put(p, 1.2):
            continue
        if j % 3 == 2:
            sap_lamp(d, p, 2.6, a + math.pi)
            d.solid(p[0], p[1], 0.5, 0.5, 2.0)
        else:
            planter(d, p, tang(a), 3.2)
            d.solid(p[0], p[1], 3.2, 1.2, 0.9, tang(a))
    for (p, a) in h.rim("estufa", 14, 0.99, 1.03, 0.45):
        glass_frame(d, p, tang(a), rnd.uniform(2.2, 2.8), rnd.uniform(1.8, 2.6))
    soil = d.m("patch_estufa_terra", (0.33, 0.33, 0.24))
    for k in (-1, 1):                                        # dois canteiros de chão (terra pintada + mudas miúdas) no fundo
        for i in range(3):
            aa = back + k * (0.42 + 0.34 * i)
            q = P((x, y), r * 0.6, math.degrees(aa))
            d.blob("estufa", soil, q, 1.25, 0.0226, 0.12, 14, sx=1.5, rot=tang(aa))
            for _ in range(5):
                s = (q[0] + rnd.uniform(-1.3, 1.3), q[1] + rnd.uniform(-0.8, 0.8))
                d.tuft("mini", d.m("folha_muda", LEAF_L), s, 0.22, 0.5, 3, w=0.07)
    bq = P((x, y), r * 0.84, math.degrees(back))            # a muda premiada no fundo: tanque inteiro entre dois caixilhos
    sap_tank(d, bq, 1.5, math.degrees(back))
    d.solid(bq[0], bq[1], 3.0, 3.0, 3.4)

    # ---- Sala dos Tanques: tanques altos na parede, canos de bronze no chão até os 3 pousos (lacaios `sap_tank`) ----
    room = rooms["tanques"]
    x, y = room["pos"]
    r = room["r"]
    tones = T["tanques"]
    back = opposite(h, "tanques")
    ms = h.mouths("tanques")
    wall = []
    for j, (p, a) in enumerate(h.rim("tanques", 13, 0.86, 0.9, 0.5)):
        if not h.put(p, 1.6):
            continue
        sap_tank(d, p, rnd.uniform(1.5, 1.8), math.degrees(a))
        d.solid(p[0], p[1], 3.2, 3.2, 3.6)
        wall.append((p, a))
        if j % 4 == 1:
            sap_pool(d, P((x, y), r * 0.76, math.degrees(a) + 6.0), 0.6, tones[1])
    pads = []
    for k in range(TANK_PADS):                               # o triângulo dos pousos, girado para longe das bocas
        best = max((min(_ang(back + math.tau * (k / TANK_PADS) + off, m) for m in ms), off) for off in (0.0, 0.26, -0.26, 0.52, -0.52))[1]
        pads.append(P((x, y), r * 0.5, math.degrees(back + math.tau * k / TANK_PADS + best)))
    pipe = d.m("bronze_viveiro", BRONZE)
    for q in pads:
        d.blob("pouso", tones[1], q, 1.9, 0.0228, 0.03, 20)
        d.blob("pouso", tones[0], q, 1.25, 0.0232, 0.03, 16)
        if wall:                                             # cano raso (só desenho) do pouso ao tanque de parede mais perto
            w, _ = min(wall, key=lambda t: (t[0][0] - q[0]) ** 2 + (t[0][1] - q[1]) ** 2)
            v = Vector((w[0] - q[0], w[1] - q[1]))
            n = Vector((-v.y, v.x)).normalized() * 0.5
            pts = [(q[0] + v.x * u + n.x * math.sin(u * math.pi), 0.07, q[1] + v.y * u + n.y * math.sin(u * math.pi)) for u in (0.2, 0.4, 0.6, 0.8, 0.94)]
            d.tube("cano", pipe, pts, 0.11, 0.11, 5)
            d.tube("cano", glow, [(a_[0], 0.17, a_[2]) for a_ in pts], 0.035, 0.035, 3)
        z.spawner("sap_tank", round(q[0], 2), round(q[1], 2), 0.5, 1, 30.0)
    h.rings("tanques", tones, (0.3,), y=0.0230, w=0.2)

    # ---- O Berço: anéis de crescimento em tons do chão, raízes rasas no chão (desenho), tanques partidos e raízes
    #      grossas na parede; seiva acesa só em poças pequenas na borda ----
    room = rooms["berco"]
    x, y = room["pos"]
    r = room["r"]
    tones = T["berco"]
    back = opposite(h, "berco")
    ms = h.mouths("berco")
    h.rings("berco", tones, (0.16, 0.3, 0.44, 0.58, 0.72, 0.86), y=0.0230, w=0.24)
    flat = d.m("raiz_rasa", (0.44, 0.33, 0.21))
    for k in range(9):                                       # raízes rasas: do pé da Muda-Mãe até a parede (não colidem)
        aa = math.tau * (k + 0.5) / 9 + rnd.uniform(-0.12, 0.12)
        ph = rnd.uniform(0, math.tau)
        pts = []
        for i in range(13):
            u = 0.12 + 0.9 * i / 12
            ab = aa + 0.16 * math.sin(u * 5.0 + ph) * (0.4 + u)
            pts.append((x + math.cos(ab) * r * u, 0.03 + 0.05 * (1.0 - u), y + math.sin(ab) * r * u))
        d.tube("raiz_rasa", flat, pts, 0.24, 0.07, 5)
    for j, (p, a) in enumerate(h.rim("berco", 16, 0.9, 0.93, 0.42)):
        if not h.put(p, 1.2):
            continue
        if j % 2 == 0:
            sap_tank(d, p, rnd.uniform(1.6, 1.9), math.degrees(a), broken=(j % 4 == 0))
            d.solid(p[0], p[1], 3.2, 3.2, 2.6)
            if j % 4 == 0:
                sap_pool(d, P((x, y), r * 0.86, math.degrees(a) + 5.0), 0.8, tones[1])
        else:
            q = P((x, y), r * 0.82, math.degrees(a) + rnd.uniform(-6, 6))
            root(d, P((x, y), r * 1.03, math.degrees(a)), q, rnd.uniform(0.8, 1.1), 0.2, rnd.uniform(2.4, 3.4), wob=1.0)
            d.solid(p[0], p[1], 1.8, 1.8, 2.0)
    for k in range(7):                                       # a raiz-mãe no fundo: feixe alto na parede com veios de seiva
        aa = back + (k - 3) * 0.1
        p0 = P((x, y), r * 1.06, math.degrees(aa))
        top = 5.4 - abs(k - 3) * 0.7
        d.tube("raiz_mae", bark if k % 2 else bark_l, [(p0[0], 0.0, p0[1]), (p0[0], top * 0.6, p0[1]), (p0[0] + math.cos(aa) * 0.6, top, p0[1] + math.sin(aa) * 0.6)], 0.7, 0.3, 6)
        if k % 2 == 0:
            q0 = P((x, y), r * 1.02, math.degrees(aa) + 1.6)
            d.tube("raiz_mae", glow, [(q0[0], 0.3, q0[1]), (q0[0], top * 0.55, q0[1]), (q0[0], top * 0.86, q0[1])], 0.09, 0.04, 4)
    # os 4 Tanques de Seiva que a Muda-Mãe repõe (MonsterDef.eggs: MobSystem.ensure_eggs, anel de EGG_R m, ângulo 0,3 rad +
    # i * 90 graus em volta do ponto de nascer): um pouso pintado em tons do chão debaixo de cada um
    adds = [P((x, y), EGG_R, math.degrees(0.3) + 90.0 * k) for k in range(4)]
    for q in adds:
        d.blob("pouso", tones[1], q, 1.5, 0.0234, 0.03, 18)
        d.blob("pouso", tones[0], q, 0.95, 0.0237, 0.03, 14)
    tr = rooms["tanques"]
    _hint(z, room, "boss_sap_mother", clear_r=round(r * 0.8, 1), adds=adds, add_r=EGG_R, tanks=pads, tanks_room=[list(tr["pos"])], tanks_r=round(tr["r"], 2),
          note="tanks: 3 sap_tank parados na Sala dos Tanques (um spawner por pouso, raio 0.5); adds: os 4 pousos dos tanques-ovo "
               "da Muda-Mae (MonsterDef.eggs r 7, angulo 0.3 rad + i*90); nenhum colisor dentro de clear_r")
    return d.flush()


DRESS = {"dg_viveiro": viveiro}
