"""Acabamento das zonas do Ato II (Costa Partida, Porto Esperança, Grutas Goblin, Estepes de Cinza e os três acampamentos
de guerra): tudo o que NÃO é layout — variação de chão, beira de estrada, praia, e os adereços de cada lugar. Cada
build_<zona>.py chama a função da sua zona logo antes do `z.finish`. Só visual (lotes do `dress.Dress`), fora os
colisores ocultos de peça grande (`Dress.solid`, sempre depois de `Dress.ok`). Usa Random próprio: a dispersão da zona
(árvores, pedras, spawners) não muda.
"""
import math
from mathutils import Vector

import zone_lib
from dress import Dress

SAND = (0.92, 0.85, 0.62)
WET = (0.8, 0.72, 0.52)
HORDE_RED = (0.72, 0.16, 0.13)
AURORA_BLUE = (0.3, 0.42, 0.72)
AURORA_GOLD = (0.96, 0.9, 0.62)


def P(c, r, deg):
    return (c[0] + math.cos(math.radians(deg)) * r, c[1] + math.sin(math.radians(deg)) * r)


# ----------------------------------------------------------------------------------------------------------------
# praia e mar (Costa e Porto)
# ----------------------------------------------------------------------------------------------------------------
def shoreline(d, c, r, beach, palms=10, boats=3, rocks=10):
    """Borda do mar lida de cima: areia molhada, espuma em gomos, linhas de onda, baixios claros, pedras com espuma,
    conchas, algas, capim de duna na passagem areia/grama e palmeiras no fundo da praia."""
    z = d.z
    rnd = d.rnd
    wet = d.m("patch_areia_molhada", WET)
    foam = d.m("patch_espuma_borda", (0.97, 0.99, 1.0))
    wave = d.m("patch_onda", (0.97, 1.0, 1.0))
    shallow = d.m("patch_baixio", (0.62, 0.95, 0.93))
    ripple = d.m("patch_areia_clara", (0.97, 0.92, 0.72))
    weed = d.m("patch_alga", (0.52, 0.58, 0.36))
    dune = d.m("capim_duna", (0.62, 0.64, 0.34))
    darkrock = d.m("pedra_mar", (0.38, 0.38, 0.4))
    shell = d.m("concha", (0.94, 0.86, 0.8))
    star = d.m("estrela_mar", (0.9, 0.46, 0.36))
    # ângulos do arco de praia dentro do vale
    angs = [a for a in (math.radians(k * 0.5) for k in range(-720, 0))
            if Vector((c[0] + math.cos(a) * (r + 2), c[1] + math.sin(a) * (r + 2))).length < z.rim_r(math.atan2(c[1] + math.sin(a) * (r + 2), c[0] + math.cos(a) * (r + 2))) + 4.0]
    if not angs:
        return
    a0, a1 = min(angs), max(angs)
    d.arc("praia", wet, c, r + 2.9, a0, a1, 3.6, 0.0078, 0.5, 2.0)
    step = 2.6 / r
    a = a0
    while a < a1:                                          # espuma: gomos que entram e saem da linha
        rr = r + 1.2 + rnd.uniform(-0.1, 0.55)
        d.blob("praia", foam, (c[0] + math.cos(a) * rr, c[1] + math.sin(a) * rr), rnd.uniform(0.3, 0.62), 0.0235, 0.25, sx=1.8, rot=math.degrees(-a) + 90)
        a += step * rnd.uniform(0.7, 1.5)
    for k, (dr, w) in enumerate(((2.4, 0.62), (5.6, 0.52), (9.6, 0.44), (14.5, 0.36))):      # ondas: arcos quebrados
        a = a0 + rnd.uniform(0, 0.05)
        while a < a1:
            ln = rnd.uniform(7.0, 18.0) / r
            d.arc("mar", wave, c, r - dr + rnd.uniform(-0.5, 0.5), a, min(a1, a + ln), w, 0.036 + k * 0.0003, 0.3)
            a += ln + rnd.uniform(4.0, 10.0) / r
    a = a0
    while a < a1:                                          # baixios claros e bancos de areia perto da borda
        rr = r - rnd.uniform(3.5, 12.0)
        d.blob("mar", shallow, (c[0] + math.cos(a) * rr, c[1] + math.sin(a) * rr), rnd.uniform(2.0, 4.5), 0.0318, 0.3, sx=1.8, rot=math.degrees(-a) + 90)
        a += rnd.uniform(9.0, 17.0) / r
    a = a0
    while a < a1:                                          # riscos de areia clara (vento) e algas na linha da maré
        rr = r + rnd.uniform(6.0, max(7.0, beach - 2.5))
        q = Vector((c[0] + math.cos(a) * rr, c[1] + math.sin(a) * rr))
        t = Vector((-math.sin(a), math.cos(a)))
        L = rnd.uniform(2.5, 6.0)
        d.strip("praia", ripple, [q - t * L * 0.5, q + Vector((math.cos(a), math.sin(a))) * rnd.uniform(-0.3, 0.3), q + t * L * 0.5], rnd.uniform(0.35, 0.7), 0.0079, 0.3, taper=True)
        if rnd.random() < 0.3:
            rw = r + rnd.uniform(3.6, 5.2)
            d.blob("praia", weed, (c[0] + math.cos(a + 0.01) * rw, c[1] + math.sin(a + 0.01) * rw), rnd.uniform(0.25, 0.55), 0.0082, 0.4, sx=2.4, rot=math.degrees(-a) + 90)
        a += rnd.uniform(2.2, 4.4) / r
    for _ in range(rocks):                                 # pedras no raso com anel de espuma
        a = rnd.uniform(a0, a1)
        rr = r - rnd.uniform(2.0, 9.0)
        p = (c[0] + math.cos(a) * rr, c[1] + math.sin(a) * rr)
        s = rnd.uniform(0.8, 1.7)
        d.blob("mar", foam, p, s * 1.5, 0.0362, 0.3)
        d.rock("marpedra", darkrock, p, s, -0.1, 0.7)
        if rnd.random() < 0.5:
            d.rock("marpedra", darkrock, (p[0] + s * 1.1, p[1] + 0.4), s * 0.5, -0.1, 0.7)
    a = a0
    while a < a1:                                          # conchas, estrelas e seixos na areia
        rr = r + rnd.uniform(3.0, beach - 1.0)
        p = (c[0] + math.cos(a) * rr, c[1] + math.sin(a) * rr)
        if d.ok(p[0], p[1], 0.4, road=0.0, water=0.0):
            d.pebbles("praia3d", shell if rnd.random() < 0.7 else star, p, rnd.randint(2, 4), 0.8, (0.07, 0.14))
        a += rnd.uniform(3.0, 6.0) / r
    a = a0
    while a < a1:                                          # passagem areia -> grama: línguas de areia e capim de duna
        rr = r + beach + rnd.uniform(-1.0, 1.6)
        p = (c[0] + math.cos(a) * rr, c[1] + math.sin(a) * rr)
        d.blob("praia", d.m("patch_areia_mar", SAND), p, rnd.uniform(1.6, 3.6), 0.0046, 0.35, sx=1.6, rot=rnd.uniform(0, 180))
        if d.ok(p[0], p[1], 0.5, road=0.3, water=0.0):
            for _ in range(rnd.randint(2, 5)):
                d.tuft("praia3d", dune, (p[0] + rnd.uniform(-1.2, 1.2), p[1] + rnd.uniform(-1.2, 1.2)), 0.45, rnd.uniform(0.7, 1.1), 6, (0.12, -0.05))
        a += rnd.uniform(2.4, 4.2) / r
    placed = 0
    for _ in range(palms * 12):                            # palmeiras no fundo da praia (tronco sólido)
        if placed >= palms:
            break
        a = rnd.uniform(a0, a1)
        rr = r + rnd.uniform(beach * 0.45, beach + 3.0)
        x, zz = c[0] + math.cos(a) * rr, c[1] + math.sin(a) * rr
        if not d.ok(x, zz, 0.6, road=2.0, water=0.0, blocked=True, tall=True):
            continue
        d.palm((x, zz), rnd.uniform(4.6, 6.0), rnd.uniform(0.08, 0.3), a + math.pi + rnd.uniform(-0.6, 0.6))
        d.solid(x, zz, 0.8, 0.8, 5.0)
        d.reserve(x, zz, 5.0)
        placed += 1
    placed = 0
    for _ in range(boats * 12):                            # botes puxados para a areia
        if placed >= boats:
            break
        a = rnd.uniform(a0, a1)
        rr = r + rnd.uniform(4.5, 8.0)
        x, zz = c[0] + math.cos(a) * rr, c[1] + math.sin(a) * rr
        if not d.ok(x, zz, 2.2, road=1.5, water=0.0, blocked=True):
            continue
        rot = math.degrees(-a) + rnd.uniform(-25, 25)
        d.rowboat((x, zz), rot, 4.2, [(0.5, 0.36, 0.24), (0.36, 0.46, 0.6), (0.62, 0.3, 0.24)][placed % 3], tilt=(rnd.uniform(-8, 8), 0))
        d.solid(x, zz, 3.6, 1.6, 1.0, rot)
        d.reserve(x, zz, 4.0)
        placed += 1


def meadow(d, centers, grass, flowers=((0.95, 0.6, 0.7), (0.98, 0.9, 0.5), (0.96, 0.96, 0.98)), lean=(0.1, 0.04), h=0.9, every=1):
    """Moitas de capim alto com pontos de flor: manchas de cor viva no campo (não bloqueiam)."""
    rnd = d.rnd
    gm = d.m("capim_%d_%d" % (int(grass[0] * 100), int(grass[2] * 100)), grass)
    fms = [d.m("flor_%d_%d" % (int(f[0] * 100), int(f[2] * 100)), f) for f in flowers]
    for k, (x, zz) in enumerate(d.spots(centers, r=0.8, spacing=2.4, road=0.6, blocked=True)):
        for _ in range(rnd.randint(3, 6)):
            p = (x + rnd.uniform(-1.3, 1.3), zz + rnd.uniform(-1.3, 1.3))
            d.tuft("campo", gm, p, 0.5, h * rnd.uniform(0.7, 1.2), 6, lean)
        if fms and k % every == 0:
            fm = fms[rnd.randrange(len(fms))]
            for _ in range(rnd.randint(4, 8)):
                p = (x + rnd.uniform(-1.4, 1.4), zz + rnd.uniform(-1.4, 1.4))
                d.cyl("campo", fm, p, 0.13, 0.0, 0.16, rnd.uniform(0.28, 0.5), 5)
                d.cyl("campo", gm, p, 0.03, 0.03, 0.4, 0.0, 3)


def outcrops(d, centers, color, top=None, r=(1.8, 3.4), hmul=1.0, moss=None):
    """Afloramentos de rocha em manchas (sólidos), longe de estrada e de tudo que é ponto da sim."""
    rnd = d.rnd
    for x, zz in d.spots(centers, r=3.6, spacing=9.0, road=2.5, water=2.5, blocked=True):
        rr = rnd.uniform(*r)
        d.outcrop((x, zz), rr, rnd.randint(3, 5), color, top, hmul=hmul)
        if moss:
            d.blob("afloramento", d.m("patch_musgo_pedra", moss), (x, zz), rr * 1.5, 0.0069, 0.3)
        d.solid(x, zz, rr * 1.5, rr * 1.5, 2.0)
        d.reserve(x, zz, rr + 2.0)


def wreck_dress(d, c, rot, L, i):
    """Casco naufragado (sea.ship wreck): costelas à mostra, mastro partido caído, tábuas e carga espalhadas."""
    rnd = d.rnd
    a = math.radians(rot)
    f = Vector((math.cos(a), math.sin(a)))
    n = Vector((-f.y, f.x))
    rib = d.m("naufragio_costela", (0.36, 0.26, 0.18))
    plank = d.m("naufragio_tabua", (0.5, 0.38, 0.26))
    W = L * 0.14
    for k in range(-3, 4):
        if (k + i) % 4 == 0:
            continue                                         # costela que falta
        p = Vector(c) + f * (k * L * 0.12)
        for s in (-1, 1):
            if rnd.random() < 0.15:
                continue
            b = p + n * s * W
            h = rnd.uniform(2.6, 3.6) * (1.0 - 0.08 * abs(k))
            d.tube("naufragio", rib, [(b.x, 0.3, b.y), (b.x + n.x * s * 0.6, h * 0.5, b.y + n.y * s * 0.6), (b.x + n.x * s * 0.15, h, b.y + n.y * s * 0.15)], 0.16, 0.07, 5)
    m0 = Vector(c) + f * L * 0.1 + n * (W + 1.6)             # mastro caído ao lado, com a verga e um resto de vela
    d.log("naufragio", rib, (m0.x, m0.y), 0.2, L * 0.55, -rot + 28.0, 0.25, 0.12)
    d.box("naufragio", d.m("vela_rasgada", (0.86, 0.82, 0.7)), (m0.x + n.x * 0.8, m0.y + n.y * 0.8), (L * 0.22, 0.05, 1.8), -rot + 28.0, 0.06)
    for _ in range(7):
        q = Vector(c) + f * rnd.uniform(-0.6, 0.6) * L + n * rnd.choice((-1, 1)) * rnd.uniform(W + 1.0, W + 4.5)
        if d.ok(q.x, q.y, 0.6, road=0.2, water=-3.0):
            d.box("naufragio", plank, (q.x, q.y), (rnd.uniform(1.2, 2.4), 0.07, 0.3), rnd.uniform(0, 180), 0.02, (rnd.uniform(-5, 5), 0))
    q = Vector(c) + f * L * 0.62 + n * 1.5
    if d.ok(q.x, q.y, 1.4, road=0.5, water=-3.0):
        d.cargo((q.x, q.y), 4, 1.2, "naufragio3d")


def mangrove_roots(d, colors):
    """Raízes em arco nas árvores do mangue (as de copa verde-escura) e vitórias-régias/limo no braço de mar."""
    z = d.z
    rnd = d.rnd
    root = d.m("raiz_mangue", (0.34, 0.27, 0.2))
    cols = [tuple(round(k, 2) for k in c) for c in colors]
    for o in z.data["obstacles"]:
        if o["kind"] != "tree" or tuple(round(k, 2) for k in o.get("color", ())) not in cols:
            continue
        x, zz = o["pos"]
        for k in range(6):
            a = math.tau * k / 6 + rnd.uniform(-0.3, 0.3)
            L = rnd.uniform(1.0, 1.7)
            d.tube("mangue", root, [(x + math.cos(a) * 0.25, 1.3, zz + math.sin(a) * 0.25), (x + math.cos(a) * L * 0.6, 0.95, zz + math.sin(a) * L * 0.6),
                                    (x + math.cos(a) * L, -0.05, zz + math.sin(a) * L)], 0.11, 0.06, 4)
    pad = d.m("patch_vitoria_regia", (0.4, 0.62, 0.34))
    pad2 = d.m("patch_limo", (0.3, 0.5, 0.36))
    flower = d.m("flor_mangue", (0.98, 0.8, 0.86))
    for k, poly in enumerate(z.rivers):
        w = z.river_ws[k]
        for i in range(2, len(poly) - 2):
            if rnd.random() < 0.55:
                continue
            if any(zone_lib.poly_dist(poly[i], rd) < w * 0.5 + 4.5 for rd in z.road_polys.values()):
                continue                                     # nada debaixo das pontes
            t = (poly[i + 1] - poly[i - 1]).normalized()
            nr = Vector((-t.y, t.x)) * rnd.uniform(-w * 0.36, w * 0.36)
            p = poly[i] + nr
            for j in range(rnd.randint(1, 3)):
                q = (p.x + rnd.uniform(-0.8, 0.8), p.y + rnd.uniform(-0.8, 0.8))
                d.blob("mangue", pad if j else pad2, q, rnd.uniform(0.35, 0.7), 0.0245, 0.12, 9)
                if rnd.random() < 0.25:
                    d.cyl("mangue3d", flower, q, 0.14, 0.0, 0.16, 0.03, 5)


# ----------------------------------------------------------------------------------------------------------------
# Costa Partida
# ----------------------------------------------------------------------------------------------------------------
def coast(z, sea_c, sea_r, village, nests, beach, lighthouse, shrine, hub_r, hub_gates, wrecks, mangrove_cols):
    d = Dress(z, 131)
    rnd = d.rnd
    # ---- chão: campo em três tons, beira de estrada, mata mais escura ao norte ----
    d.mottle([("campo_claro", (0.6, 0.71, 0.43)), ("campo_escuro", (0.47, 0.6, 0.37)), ("campo_seco", (0.6, 0.68, 0.42))],
             [((0, -10), 112, 130)], rmin=3.0, rmax=8.5)
    d.mottle([("mata_sombra", (0.43, 0.56, 0.35))], [((0, -62), 50, 26), ((70, -22), 30, 12), ((-90, -60), 26, 10)], y=0.0054, rmin=5.0, rmax=11.0, group="mata")
    d.road_edges((0.58, 0.54, 0.4))
    d.roadside(d.m("seixo_estrada", (0.62, 0.58, 0.5)), d.m("capim_beira", (0.5, 0.62, 0.34)), every=6.0, lean=(0.1, 0.04))
    d.reserve(4.0, 68.0, 15.0)          # arena da Mãe das Marés: nada de palmeira nem bote no meio da luta
    shoreline(d, sea_c, sea_r, 18.0, palms=14, boats=4, rocks=14)
    # ---- Encruzilhada: carga, feno, carroça, cavalete de armas e alvos, flâmulas nos vãos, placas nas saídas ----
    for a, r, n in ((0.2, 13.5, 5), (3.0, 14.0, 6), (4.45, 13.0, 4)):
        p = (math.cos(a) * r, math.sin(a) * r)
        if d.ok(p[0], p[1], 1.6, road=0.4):
            d.cargo(p, n, 1.4)
            d.solid(p[0], p[1], 2.6, 2.6, 1.2)
    for p, rot in (((13.0, 8.5), 30.0), ((-13.5, 6.0), 110.0)):
        if d.ok(p[0], p[1], 1.6, road=0.4):
            d.cart(p, rot, load=(0.86, 0.8, 0.66))
            d.solid(p[0], p[1], 3.0, 1.8, 1.4, rot)
    for p in ((-6.5, 13.5), (-8.0, 14.6), (-5.4, 15.2)):
        if d.ok(p[0], p[1], 0.7, road=0.3):
            d.hay(p)
            d.solid(p[0], p[1], 1.3, 1.3, 1.2)
    if d.ok(8.5, -14.0, 1.2, road=0.3):
        d.weapon_rack((8.5, -14.0), 35.0)
        d.solid(8.5, -14.0, 2.4, 0.8, 1.6, 35.0)
    for p in ((13.6, -12.4), (15.2, -10.2)):
        if d.ok(p[0], p[1], 0.6, road=0.3):
            d.target(p, 130.0)
            d.solid(p[0], p[1], 0.9, 0.9, 1.6)
    for g in hub_gates:
        for sgn in (-1, 1):
            q = P((0, 0), hub_r + 0.2, g + sgn * 24.0)
            d.flag(q, AURORA_BLUE, 5.2, -g + 90.0, (0.82, 0.68, 0.48), w=1.1, drop=1.7)
            q2 = P((0, 0), hub_r + 5.5, g + sgn * 13.0)
            if sgn > 0 and d.ok(q2[0], q2[1], 0.5, road=0.3):
                d.signpost(q2, -g + 30.0)
                d.solid(q2[0], q2[1], 0.5, 0.5, 2.4)
            q3 = P((0, 0), hub_r + 3.0, g - sgn * 11.5)
            if d.ok(q3[0], q3[1], 0.5, road=0.2):
                d.torch(q3, 2.4)
                d.solid(q3[0], q3[1], 0.4, 0.4, 2.4)
    for k in range(10):                                     # anel de pedras claras em volta da roseta
        q = P((0, 0), 4.3, k * 36.0)
        d.blob("posto", d.m("patch_posto_pedra", (0.86, 0.8, 0.66)), q, 0.55, 0.0185, 0.15, 8)
    # ---- Praia dos Naufrágios ----
    for i, (c, rot) in enumerate(wrecks):
        wreck_dress(d, c, rot, 12.0 + i * 2, i)
    for p, rot in (((-70.0, 52.0), 20.0), ((-84.0, 44.0), 100.0), ((46.0, 54.0), 60.0)):      # redes e peixe no varal (cabanas)
        if d.ok(p[0], p[1], 2.2, road=0.6):
            d.net_rack(p, rot)
            d.solid(p[0], p[1], 4.2, 0.6, 2.0, rot)
            q = (p[0] + 3.0, p[1] + 2.4)
            if d.ok(q[0], q[1], 1.4, road=0.4):
                d.fish_rack(q, rot + 70.0)
                d.solid(q[0], q[1], 2.6, 0.5, 1.7, rot + 70.0)
    # ---- Aldeia de Palafitas: passarelas, tochas, flâmulas rasgadas, totens, ossos, botes nas poças ----
    for i in range(6):
        a = math.tau * (i + 0.5) / 6
        hut = (village[0] + math.cos(a) * 9.5, village[1] + math.sin(a) * 9.5)
        inner = (village[0] + math.cos(a) * 2.2, village[1] + math.sin(a) * 2.2)
        d.planks([(village[0] + math.cos(a) * 7.4, village[1] + math.sin(a) * 7.4), (village[0] + math.cos(a + 0.12) * 4.8, village[1] + math.sin(a + 0.12) * 4.8), inner], 1.3, 0.05)
        a2 = math.tau * (i + 1.5) / 6
        d.planks([P(hut, 2.4, math.degrees(a) + 100.0), P(village, 11.2, math.degrees((a + a2) / 2)), P((village[0] + math.cos(a2) * 9.5, village[1] + math.sin(a2) * 9.5), 2.4, math.degrees(a2) - 100.0)], 1.0, 0.05, color=(0.46, 0.36, 0.24))
        d.flag(P(hut, 2.3, math.degrees(a) + 45.0), [HORDE_RED, (0.86, 0.6, 0.2)][i % 2], 5.2, math.degrees(-a), (0.4, 0.3, 0.2), w=0.9, drop=1.5)
        q = P(hut, 3.1, math.degrees(a) + 180.0 + 38.0)
        if d.ok(q[0], q[1], 0.4, road=0.2, water=0.2):
            d.torch(q, 2.0)
            d.solid(q[0], q[1], 0.4, 0.4, 2.0)
    for k in range(4):
        q = P(village, 3.4, 45.0 + k * 90.0)
        if d.ok(q[0], q[1], 0.5, road=0.2):
            d.totem(q, 3.0, k * 40.0, ((0.6, 0.24, 0.18), (0.84, 0.62, 0.24), (0.3, 0.5, 0.36)))
            d.solid(q[0], q[1], 0.9, 0.9, 3.0)
    for k in range(5):
        q = P(village, rnd.uniform(12.0, 17.0), rnd.uniform(0, 360))
        if d.ok(q[0], q[1], 1.0, road=0.5, water=0.3):
            d.bones(q, rnd.randint(3, 5), 1.0)
    for i in (1, 4):
        a = math.tau * (i + 0.3) / 6
        d.rowboat((village[0] + math.cos(a) * 14.5, village[1] + math.sin(a) * 14.5), i * 50.0, 3.4, (0.44, 0.34, 0.22))
    for i in range(3):
        q = P(village, 16.0, 30.0 + i * 120.0)
        if d.ok(q[0], q[1], 1.4, road=0.5, water=0.3):
            d.fish_rack(q, i * 60.0)
            d.solid(q[0], q[1], 2.6, 0.5, 1.7, i * 60.0)
    mangrove_roots(d, mangrove_cols)
    d.mottle([("lama_mangue", (0.36, 0.42, 0.3)), ("lama_clara", (0.44, 0.5, 0.34))], [((-56, -92), 12, 5), ((-50, -64), 12, 6), ((-50, -32), 11, 5),
             ((-58, 24), 12, 6), ((-52, 58), 12, 6), ((-42, 90), 10, 4)], y=0.0056, rmin=2.0, rmax=4.5, group="mangue")
    # ---- Falésias dos Ninhos: agulhas de rocha, penas e ossos; a vanguarda orc com barricadas e estandartes ----
    outcrops(d, [((-15, -92), 24, 9)], (0.62, 0.58, 0.52), r=(1.6, 2.8), hmul=2.4)
    for k in range(8):
        q = P(nests, rnd.uniform(6.0, 20.0), rnd.uniform(0, 360))
        if d.ok(q[0], q[1], 1.0, road=0.5):
            d.bones(q, rnd.randint(2, 4), 1.1, skull=k % 2 == 0)
    camp = (nests[0] + 10.0, nests[1] + 16.0)
    for k, deg in enumerate((200.0, 250.0, 300.0, 340.0)):
        q = P(camp, 10.5, deg)
        if d.ok(q[0], q[1], 2.0, road=1.0):
            d.spikes(q, -deg + 90.0, 3.8)
            d.solid(q[0], q[1], 3.8, 1.0, 1.2, -deg + 90.0)
    for k, deg in enumerate((30.0, 150.0)):
        q = P(camp, 8.6, deg)
        if d.ok(q[0], q[1], 0.5, road=0.5):
            d.flag(q, HORDE_RED, 5.6, 0.0)
            d.solid(q[0], q[1], 0.4, 0.4, 5.0)
    if d.ok(camp[0], camp[1], 1.0, road=0.5):
        d.brazier(camp, 1.3)
        d.solid(camp[0], camp[1], 1.4, 1.4, 1.4)
    # ---- Farol: pedras no mar em volta do promontório e um caminho de lajes ----
    stone = d.m("pedra_mar", (0.38, 0.38, 0.4))
    for k in range(9):
        q = P(lighthouse, rnd.uniform(11.5, 15.0), 20.0 + k * 22.0 + rnd.uniform(-6, 6))
        if (Vector(q) - Vector(sea_c)).length < sea_r - 1.0:
            s = rnd.uniform(0.9, 1.8)
            d.blob("mar", d.m("patch_espuma_borda", (0.97, 0.99, 1.0)), q, s * 1.5, 0.0362, 0.3)
            d.rock("marpedra", stone, q, s, -0.1, 0.75)
    # ---- Santuário Afogado: colunas de pé, anel de runa, vitórias-régias nas poças ----
    for k, deg in enumerate((20.0, 80.0, 250.0, 310.0)):
        q = P(shrine, 9.4, deg)
        if d.ok(q[0], q[1], 0.7, road=0.6):
            d.standing_stone(q, rnd.uniform(3.0, 4.4), (0.86, 0.85, 0.8), (0.5, 0.86, 0.95), lean=3.0)
            d.solid(q[0], q[1], 1.1, 1.1, 3.0)
    rune = d.m("glow_runa_santuario", (0.5, 0.86, 0.95))
    for k in range(12):
        a = math.tau * k / 12
        d.arc("santuario", rune, shrine, 5.4, a + 0.06, a + math.tau / 12 - 0.06, 0.22, 0.02, 0.0, 0.8)
    for dx, dy, r in ((-11.0, -6.0, 3.6), (-12.5, 4.0, 4.4), (-4.0, 12.0, 3.8), (-5.0, -12.5, 3.0), (4.5, 11.5, 2.6)):
        for _ in range(4):
            q = (shrine[0] + dx + rnd.uniform(-r, r) * 0.6, shrine[1] + dy + rnd.uniform(-r, r) * 0.6)
            d.blob("santuario", d.m("patch_vitoria_regia", (0.4, 0.62, 0.34)), q, rnd.uniform(0.3, 0.55), 0.0175, 0.1, 9)
    setpieces(d, [((36, -24), 44, 3), ((-24, 32), 26, 1), ((-92, -52), 24, 1), ((64, 40), 22, 1), ((-20, -50), 30, 1)], ("circle", "fisher", "wreck", "circle", "ruin"),
              spacing=30.0, stone=(0.86, 0.85, 0.8), rune=(0.5, 0.86, 0.95))
    # ---- campo: afloramentos com musgo, capim alto com flores (cravo-da-praia) ----
    outcrops(d, [((40, -20), 40, 6), ((-20, 34), 26, 3), ((-96, -30), 22, 3), ((70, 44), 18, 2)], (0.66, 0.62, 0.56), moss=(0.44, 0.58, 0.36))
    meadow(d, [((30, -30), 50, 26), ((-26, 30), 28, 12), ((60, 30), 26, 10), ((-84, -64), 26, 8), ((0, -60), 46, 16)], (0.46, 0.64, 0.32), every=2)
    # ---- vida da praia (por ultimo, sem colisor): varas de pescar fincadas na areia molhada, viradas para o mar ----
    for x in (38.0, 47.0, 54.0, -22.0, -4.0):
        zz = sea_c[1] - math.sqrt(max(0.0, sea_r * sea_r - (x - sea_c[0]) ** 2)) - 1.2
        if d.ok(x, zz, 0.8, road=0.4, water=0.0):
            d.fishing_pole((x, zz), zone_lib.along(sea_c[0] - x, sea_c[1] - zz), 3.6, 0.0)
    return d.flush()


# ----------------------------------------------------------------------------------------------------------------
# Porto Esperança
# ----------------------------------------------------------------------------------------------------------------
def port(z, sea_c, sea_r, town_c, town_r, plaza_r, gates, gate_half, farm, shipyard_c, beacon_c, beacon_root, post_c, ship_c, ship_rot, ship_L, piers):
    d = Dress(z, 211)
    rnd = d.rnd
    H = lambda r, a: P(town_c, r, a)
    avs = tuple(n for n in z.road_polys if n.startswith("av_"))
    d.mottle([("campo_claro", (0.6, 0.71, 0.43)), ("campo_escuro", (0.47, 0.6, 0.37)), ("campo_seco", (0.6, 0.68, 0.42))], [((0, -20), 96, 90)], rmin=3.0, rmax=8.0)
    d.mottle([("mata_sombra", (0.43, 0.56, 0.35))], [((0, -62), 36, 18), ((-70, -40), 24, 10), ((72, 8), 20, 8)], y=0.0054, rmin=5.0, rmax=10.0, group="mata")
    d.road_edges((0.58, 0.54, 0.4), skip=avs)
    d.roadside(d.m("seixo_estrada", (0.62, 0.58, 0.5)), d.m("capim_beira", (0.5, 0.62, 0.34)), every=6.0, lean=(0.1, 0.04), skip=avs)
    shoreline(d, sea_c, sea_r, 12.0, palms=9, boats=4, rocks=9)
    # ---- praça: anéis de laje clara e raios (rosa dos ventos) no calçamento ----
    ring = d.m("patch_praca_anel", (0.9, 0.82, 0.66))
    ring2 = d.m("patch_praca_raio", (0.8, 0.7, 0.54))
    for rr, w, n in ((7.2, 0.3, 24), (15.6, 0.3, 40), (plaza_r - 0.6, 0.45, 56)):
        for k in range(n):
            a = math.tau * k / n
            d.arc("praca", ring if k % 2 else ring2, town_c, rr, a + 0.012, a + math.tau / n - 0.012, w, 0.0162, 0.0, 0.7)
    # ---- casas: entre uma e outra, lenha/carga/barris junto à paliçada; varais de roupa; canteiros na frente ----
    houses = sorted([o for o in z.data["obstacles"] if o["kind"] == "house" and (Vector(o["pos"]) - Vector(town_c)).length < town_r],
                    key=lambda o: math.atan2(o["pos"][1] - town_c[1], o["pos"][0] - town_c[0]))
    bed = [d.m("patch_canteiro", (0.42, 0.34, 0.24)), d.m("flor_95_70", (0.95, 0.6, 0.7)), d.m("flor_98_50", (0.98, 0.9, 0.5)), d.m("capim_46_32", (0.46, 0.64, 0.32))]
    for i, o in enumerate(houses):
        nx = houses[(i + 1) % len(houses)]
        a0 = math.degrees(math.atan2(o["pos"][1] - town_c[1], o["pos"][0] - town_c[0]))
        a1 = math.degrees(math.atan2(nx["pos"][1] - town_c[1], nx["pos"][0] - town_c[0]))
        gap = (a1 - a0) % 360.0
        ra = (Vector(o["pos"]) - Vector(town_c)).length
        q = H(ra - 3.7, a0 + 5.0)                           # canteiro com flores na frente da casa (a taverna tem porta: fica sem)
        if o["size"][0] < 6.0:
            d.blob("casas", bed[0], q, 1.0, 0.0159, 0.2, sx=1.6, rot=-a0 + 90.0)
        for _ in range(5 if o["size"][0] < 6.0 else 0):
            qq = (q[0] + rnd.uniform(-1.1, 1.1), q[1] + rnd.uniform(-0.6, 0.6))
            d.tuft("casas3d", bed[3], qq, 0.25, 0.4, 4)
            d.cyl("casas3d", bed[1 + i % 2], qq, 0.12, 0.0, 0.14, 0.34, 5)
        if gap > 34.0 or gap < 8.0:
            continue
        mid = a0 + gap * 0.5
        q = H(33.4, mid)
        if d.ok(q[0], q[1], 1.2, road=1.0):
            if i % 3 == 0:
                d.woodpile(q, -mid, 3, 2.2)
            elif i % 3 == 1:
                d.cargo(q, 4, 0.9)
            else:
                d.barrel(q, 1.1)
                d.barrel((q[0] + 0.9, q[1] + 0.3), 1.0)
                d.sack((q[0] - 0.5, q[1] + 0.9))
            d.solid(q[0], q[1], 2.2, 2.2, 1.4)
        if i % 2 == 0:
            d.laundry(H(ra + 0.4, a0 + gap * 0.24), H(ra + 0.4, a0 + gap * 0.76), 2.5)
    # ---- portões: flâmulas da Aurora nas torres; mercado: tapetes sob as barracas ----
    for g in gates:
        for sgn in (-1, 1):
            d.flag(H(town_r + 0.3, g + sgn * gate_half), [AURORA_BLUE, AURORA_GOLD][(int(g) // 90) % 2], 8.6, -g + 90.0, (0.82, 0.68, 0.48), w=1.4, drop=2.2, tatter=False)
    for o in z.data["obstacles"]:
        if o["kind"] == "stall":
            d.rug(o["pos"], 3.8, 2.8, o["rot"], [(0.74, 0.3, 0.26), (0.3, 0.44, 0.7), (0.86, 0.7, 0.3)][int(abs(o["pos"][0])) % 3], (0.92, 0.86, 0.7))
    # ---- cais: guindastes, carga no largo e nos píeres, cabeços de amarração, redes, bancas de peixe com toldo ----
    for c, rot in (((7.6, 62.6), 60.0), ((-13.4, 58.6), 120.0)):
        if d.ok(c[0], c[1], 1.4, road=0.6, water=-1.0):
            d.crane(c, rot)
            d.solid(c[0], c[1], 1.8, 1.8, 6.0)
            d.reserve(c[0], c[1], 3.5)
    wood = d.m("cais_cabeco", (0.36, 0.27, 0.19))
    rope = d.m("corda", (0.78, 0.7, 0.5))
    for a, b in piers:
        a, b = Vector(a), Vector(b)
        t = (b - a).normalized()
        nr = Vector((-t.y, t.x))
        L = (b - a).length
        k = 6.0
        while k < L - 1.0:
            for s in (-1, 1):
                q = a + t * k + nr * s * 1.35
                d.cyl("cais", wood, (q.x, q.y), 0.17, 0.2, 0.55, 0.7, 6)
                d.cyl("cais", rope, (q.x, q.y), 0.24, 0.24, 0.14, 0.82, 6, cap=False)
            if int(k) % 12 == 0:
                q = a + t * (k + 2.5) + nr * rnd.choice((-0.6, 0.6))
                d.crate((q.x, q.y), 0.9, rnd.uniform(0, 60), 0.7, "cais")
                d.barrel((q.x + 0.9, q.y + 0.2), 0.95, 0.7, "cais")
            k += 6.0
        e = b - t * 1.2
        d.crate((e.x, e.y), 1.0, 20.0, 0.7, "cais")
        d.crate((e.x + 0.2, e.y - 1.1), 0.8, 50.0, 0.7, "cais")
        d.sack((e.x - 0.8, e.y - 0.4), 1.1, "cais")
    for c, n in (((-5.5, 49.5), 5), ((6.5, 51.0), 6)):
        if d.ok(c[0], c[1], 1.6, road=0.6):
            d.cargo(c, n, 1.4)
            d.solid(c[0], c[1], 2.8, 2.8, 1.3)
    for c, rot, col in (((20.0, 52.0), 10.0, (0.3, 0.5, 0.74)), ((27.0, 50.5), -8.0, (0.8, 0.34, 0.28)), ((-24.0, 49.0), 8.0, (0.92, 0.74, 0.3))):
        if d.ok(c[0], c[1], 2.2, road=0.8):
            d.awning(c, 3.6, 2.8, rot, col, 2.4, stripes=(0.95, 0.93, 0.86))
            d.box("mercado", d.m("banca_peixe", (0.56, 0.42, 0.28)), c, (2.8, 0.9, 1.2), rot, 0.0)
            for k in (-0.9, 0.0, 0.9):
                d.box("mercado", d.m("peixe_fresco", (0.62, 0.74, 0.82)), (c[0] + k, c[1]), (0.6, 0.12, 0.8), rot, 0.9)
            d.solid(c[0], c[1], 3.6, 2.6, 2.4, rot)
            d.reserve(c[0], c[1], 3.4)
    for c, rot in (((34.0, 60.0), 20.0), ((-28.0, 60.5), -12.0), ((40.0, 50.0), 80.0)):
        if d.ok(c[0], c[1], 2.2, road=0.8, water=0.0):
            d.net_rack(c, rot)
            d.solid(c[0], c[1], 4.2, 0.6, 2.0, rot)
    d.ship_rig(ship_c, ship_rot, ship_L)
    buoy = d.m("boia", (0.86, 0.36, 0.22))
    buoy2 = d.m("boia_branca", (0.95, 0.95, 0.92))
    foam = d.m("patch_espuma_borda", (0.97, 0.99, 1.0))
    for k in range(9):                                     # boias no canal de entrada e botes de pesca ancorados
        a = math.radians(-128.0 + k * 9.5)
        rr = sea_r - 24.0 - (k % 3) * 9.0
        q = (sea_c[0] + math.cos(a) * rr, sea_c[1] + math.sin(a) * rr)
        if any(abs(q[0] - p[0][0]) < 4.0 and q[1] < p[1][1] + 6.0 for p in piers) or (Vector(q) - Vector(ship_c)).length < ship_L:
            continue
        d.cyl("mar3d", buoy, q, 0.34, 0.2, 0.7, 0.0, 6)
        d.cyl("mar3d", buoy2, q, 0.2, 0.1, 0.35, 0.7, 6)
        d.blob("mar", foam, q, 0.75, 0.0362, 0.2)
    for c, rot, col in (((-30.0, 78.0), 30.0, (0.36, 0.46, 0.6)), ((33.0, 80.0), 110.0, (0.62, 0.3, 0.24)), ((2.0, 88.0), 70.0, (0.5, 0.36, 0.24))):
        d.rowboat(c, rot, 4.4, col, y0=-0.12)
        d.blob("mar", foam, c, 2.4, 0.0362, 0.2, sx=1.5, rot=rot)
    # ---- quebra-mar: mais pedras e espuma ----
    stone = d.m("pedra_mar", (0.38, 0.38, 0.4))
    br, bc = Vector(beacon_root), Vector(beacon_c)
    for k in range(14):
        t = k / 13.0
        q = br + (bc - br) * t + Vector((rnd.uniform(-3.4, 3.4), rnd.uniform(-1.0, 1.0)))
        d.rock("marpedra", stone, (q.x, q.y), rnd.uniform(0.8, 1.6), -0.1, 0.7)
        if (q - Vector(sea_c)).length < sea_r:
            d.blob("mar", foam, (q.x, q.y), 1.9, 0.0361, 0.3)
    # ---- hortas: leiras e fileiras verdes, espantalho, feno; estaleiro: toras, tábuas, barris de piche ----
    soil = d.m("patch_leira", (0.4, 0.31, 0.22))
    crop = [d.m("hortalica", (0.36, 0.62, 0.3)), d.m("hortalica_c", (0.62, 0.72, 0.34))]
    for i, (dx, dy) in enumerate(((2.0, -9.0), (8.0, 6.0), (-5.0, 9.0))):
        q = (farm[0] + dx, farm[1] + dy)
        for row in range(-3, 4):
            y = q[1] + row * 1.25
            hw = math.sqrt(max(0.5, 4.9 ** 2 - (row * 1.25) ** 2))
            d.strip("horta", soil, [Vector((q[0] - hw, y)), Vector((q[0], y + 0.15)), Vector((q[0] + hw, y))], 0.62, 0.0072, 0.2)
            x = q[0] - hw + 0.6
            while x < q[0] + hw - 0.4:
                d.cyl("horta3d", crop[(row + i) % 2], (x, y + rnd.uniform(-0.1, 0.1)), 0.24, 0.05, 0.34, 0.0, 5)
                x += 0.95
    p = (farm[0] + 5.0, farm[1] - 2.0)
    if d.ok(p[0], p[1], 0.6, road=0.5):
        d.scarecrow(p, 30.0)
        d.solid(p[0], p[1], 0.5, 0.5, 2.3)
    for p in ((farm[0] - 12.0, farm[1] + 4.0), (farm[0] - 13.4, farm[1] + 5.2), (farm[0] - 11.4, farm[1] + 5.8)):
        if d.ok(p[0], p[1], 0.8, road=0.5):
            d.hay(p)
            d.solid(p[0], p[1], 1.3, 1.3, 1.2)
    sy = shipyard_c
    for p, rot in (((sy[0] - 9.0, sy[1] - 6.5), 20.0), ((sy[0] + 9.5, sy[1] - 3.5), 110.0)):
        if d.ok(p[0], p[1], 1.6, road=0.6, water=0.0):
            d.woodpile(p, rot, 4, 3.4, color=(0.66, 0.5, 0.32))
            d.solid(p[0], p[1], 3.4, 2.2, 1.4, rot)
    for k in range(9):
        q = (sy[0] + rnd.uniform(-11, 11), sy[1] + rnd.uniform(-9, 9))
        if d.ok(q[0], q[1], 0.7, road=0.3, water=0.0):
            d.box("estaleiro3d", d.m("tabua_66", (0.66, 0.5, 0.32)), q, (rnd.uniform(1.6, 2.8), 0.07, 0.3), rnd.uniform(0, 180), 0.02)
    for p in ((sy[0] + 6.0, sy[1] + 7.5), (sy[0] + 7.2, sy[1] + 6.6)):
        if d.ok(p[0], p[1], 0.6, road=0.3, water=0.0):
            d.barrel(p, 1.1, color=(0.2, 0.18, 0.18))
            d.solid(p[0], p[1], 0.9, 0.9, 1.1)
    # ---- posto da garganta: tochas, flâmula e cavalos de frisa do lado da garganta ----
    for k, deg in enumerate((-150.0, -100.0, -60.0)):
        q = P(post_c, 9.5, deg)
        if d.ok(q[0], q[1], 2.0, road=1.2):
            d.spikes(q, -deg + 90.0, 3.6, color=(0.5, 0.38, 0.26))
            d.solid(q[0], q[1], 3.6, 1.0, 1.2, -deg + 90.0)
    for q in (P(post_c, 4.0, 40.0), P(post_c, 4.0, 200.0)):
        if d.ok(q[0], q[1], 0.4, road=0.3):
            d.torch(q, 2.4)
            d.solid(q[0], q[1], 0.4, 0.4, 2.4)
    d.flag(P(post_c, 2.6, 135.0), AURORA_BLUE, 8.2, 0.0, (0.82, 0.68, 0.48), w=1.3, drop=2.0, tatter=False)
    # ---- campo ----
    setpieces(d, [((34, -66), 22, 1), ((-36, -70), 22, 1), ((74, 30), 14, 1), ((-80, -28), 14, 1)], ("circle", "wreck", "fisher", "ruin"), spacing=30.0,
              stone=(0.86, 0.85, 0.8), rune=(0.5, 0.86, 0.95))
    outcrops(d, [((40, -44), 26, 3), ((-40, -66), 24, 3), ((76, 12), 16, 2), ((-84, -16), 14, 2)], (0.66, 0.62, 0.56), moss=(0.44, 0.58, 0.36))
    meadow(d, [((0, -62), 40, 20), ((-66, -36), 26, 10), ((70, 6), 22, 8), ((-76, 30), 16, 6), ((60, -44), 20, 6)], (0.46, 0.64, 0.32), every=2)
    # ---- vida do cais (por último: não mexe no sorteio de cima; sem colisor): varas de pescar nos píeres, peixe no varal ----
    for (px, pz), (dx, dz) in (((15.1, 69.5), (1, 0)), ((12.9, 79.0), (-1, 0)), ((14.0, 91.2), (0, 1)), ((-6.9, 71.0), (1, 0)), ((-6.9, 82.0), (1, 0)), ((-8.0, 95.2), (0, 1))):
        d.fishing_pole((px, pz), zone_lib.along(dx, dz), 3.2, 0.7)
    for q, rot in (((19.5, 60.5), 12.0), ((-14.5, 58.0), -8.0), ((30.0, 55.5), 30.0)):
        if d.ok(q[0], q[1], 1.6, road=0.8, water=0.0):
            d.fish_rack(q, rot, "pesca")
    return d.flush()


# ----------------------------------------------------------------------------------------------------------------
# Estepes de Cinza
# ----------------------------------------------------------------------------------------------------------------
WIND = (0.17, 0.05)            # empurrão das pontas do capim (vento de oeste)
STEPPE_GRASS = (0.74, 0.58, 0.24)
MESA_ROCK = (0.56, 0.4, 0.3)


def dry_ground(d, tones, n, r=108, streaks=110, streak_col=(0.84, 0.74, 0.46), ruts=(0.42, 0.37, 0.31), edge=(0.5, 0.44, 0.35), c=(0, 0)):
    """Chão de estepe: manchas em três tons, riscos claros de vento todos no mesmo rumo, acostamento pisado e sulcos de roda."""
    rnd = d.rnd
    d.mottle(tones, [(c, r, n)], rmin=3.0, rmax=9.0)
    sm = d.m("patch_risco_vento", streak_col)
    wd = Vector((1.0, 0.3)).normalized()
    for _ in range(streaks):
        a, rr = rnd.uniform(0, math.tau), r * math.sqrt(rnd.random())
        p = Vector((c[0] + math.cos(a) * rr, c[1] + math.sin(a) * rr))
        if p.length > d.z.rim_r(math.atan2(p.y, p.x)) - 3.0:
            continue
        L = rnd.uniform(4.0, 11.0)
        side = Vector((-wd.y, wd.x)) * rnd.uniform(-0.5, 0.5)
        d.strip("vento", sm, [p - wd * L * 0.5, p + side, p + wd * L * 0.5], rnd.uniform(0.22, 0.5), 0.0062, 0.3, taper=True)
    if edge:
        d.road_edges(edge, extra=1.3)
    if ruts:
        rm = d.m("patch_sulco", ruts)
        for name, poly in d.z.road_polys.items():
            if len(poly) < 4:
                continue
            for s in (-0.85, 0.85):
                pts = []
                for i, p in enumerate(poly):
                    t = (poly[min(len(poly) - 1, i + 1)] - poly[max(0, i - 1)]).normalized()
                    pts.append(p + Vector((-t.y, t.x)) * s)
                i = rnd.randint(0, 4)
                while i < len(pts) - 3:                      # trechos de 5-12 m com falhas
                    n = rnd.randint(4, 8)
                    d.strip("sulco", rm, pts[i:i + n], 0.2, 0.0125, 0.4, taper=True)
                    i += n + rnd.randint(2, 5)


def steppe(z, hub_r, hub_gates, fronts, camp_r, graveyard, deserters, totem, shrine, fort_q):
    d = Dress(z, 307)
    rnd = d.rnd
    dry_ground(d, [("estepe_ouro", (0.82, 0.68, 0.36)), ("estepe_queimado", (0.62, 0.5, 0.3)), ("estepe_palha", (0.78, 0.7, 0.44))], 150)
    d.roadside(d.m("seixo_estepe", (0.56, 0.48, 0.42)), d.m("capim_estepe", STEPPE_GRASS), every=5.0, lean=WIND, tuft_h=1.0)
    meadow(d, [((0, 0), 108, 150)], STEPPE_GRASS, flowers=((0.86, 0.36, 0.2), ), lean=WIND, h=1.25, every=5)
    outcrops(d, [((0, 0), 104, 16), ((-90, -6), 22, 4), ((40, -84), 20, 3)], MESA_ROCK, (0.74, 0.58, 0.4), r=(1.8, 3.6), hmul=1.3)
    outcrops(d, [((84, -84), 16, 2), ((-80, 96), 14, 2), ((96, 60), 14, 2), ((-104, -56), 12, 2)], MESA_ROCK, (0.74, 0.58, 0.4), r=(2.2, 3.2), hmul=2.6)
    # ---- rio: bancos de cascalho e pedras de vau (visual) ----
    grav = d.m("patch_cascalho", (0.66, 0.64, 0.6))
    rk = d.m("pedra_rio", (0.5, 0.5, 0.52))
    for k, poly in enumerate(z.rivers):
        w = z.river_ws[k]
        for i in range(2, len(poly) - 2, 2):
            t = (poly[i + 1] - poly[i - 1]).normalized()
            nr = Vector((-t.y, t.x))
            s = 1 if rnd.random() < 0.5 else -1
            p = poly[i] + nr * s * (w * 0.5 + rnd.uniform(0.2, 1.4))
            d.blob("rio", grav, (p.x, p.y), rnd.uniform(1.2, 2.6), 0.0086, 0.3, sx=1.8, rot=zone_lib.along(t.x, t.y))
            if rnd.random() < 0.35 and all(zone_lib.poly_dist(poly[i], rd) > w * 0.5 + 5.0 for rd in z.road_polys.values()):
                q = poly[i] + nr * rnd.uniform(-w * 0.3, w * 0.3)
                d.rock("rio3d", rk, (q.x, q.y), rnd.uniform(0.5, 1.0), -0.15, 0.5)
                d.blob("rio", d.m("patch_espuma_rio", (0.86, 0.9, 0.94)), (q.x + t.x * 0.8, q.y + t.y * 0.8), 0.9, 0.0215, 0.3, sx=1.8, rot=zone_lib.along(t.x, t.y))
    # ---- Posto da Caravana: tapetes, carga, feno, flâmulas nas carroças, pedras em roda da fogueira ----
    for k in range(12):
        q = P((0, 0), 3.4, k * 30.0 + 15.0)
        d.blob("posto", d.m("patch_posto_pedra", (0.5, 0.46, 0.42)), q, 0.36, 0.0185, 0.2, 7)
    for o in list(z.data["obstacles"]):
        dist = math.hypot(*o["pos"])
        if dist > hub_r or not o.get("visible", True):
            continue
        if o["kind"] == "stall":
            d.rug(o["pos"], 4.2, 3.0, o["rot"], (0.74, 0.3, 0.26), (0.94, 0.84, 0.6))
        elif o["kind"] == "tent":
            ang = math.atan2(o["pos"][1], o["pos"][0])
            q = (o["pos"][0] - math.cos(ang) * 2.9, o["pos"][1] - math.sin(ang) * 2.9)
            d.rug(q, 2.6, 1.8, math.degrees(-ang) + 90.0, [(0.3, 0.44, 0.7), (0.78, 0.5, 0.24), (0.5, 0.3, 0.5)][int(abs(o["pos"][0])) % 3], (0.94, 0.86, 0.66))
    for deg, n in ((22.0, 5), (100.0, 4), (162.0, 5), (-100.0, 4), (-20.0, 4), (-158.0, 3)):
        q = P((0, 0), 17.3, deg)
        if d.ok(q[0], q[1], 1.3, road=0.8):
            d.cargo(q, n, 1.2)
            d.solid(q[0], q[1], 2.4, 2.4, 1.3)
    for q in (P((0, 0), 16.8, 200.0), P((0, 0), 17.4, 207.0), P((0, 0), 16.4, -30.0)):
        if d.ok(q[0], q[1], 0.8, road=0.6):
            d.hay(q)
            d.solid(q[0], q[1], 1.3, 1.3, 1.2)
    n = int(math.tau * hub_r / 6.4)
    for i in range(0, n, 2):                               # flâmulas coloridas nas carroças do anel (lê-se o posto de longe)
        am = math.tau * (i + 0.5) / n
        if any(zone_lib.angdiff(am, math.radians(g)) * hub_r < 4.6 + 1.6 for g in hub_gates):
            continue
        q = (math.cos(am) * (hub_r + 1.7), math.sin(am) * (hub_r + 1.7))
        d.flag(q, [AURORA_BLUE, AURORA_GOLD, (0.86, 0.5, 0.26)][(i // 2) % 3], 5.6, math.degrees(-am), (0.5, 0.38, 0.26), w=1.0, drop=1.5)
    # ---- frentes: totens da Horda aos pares, cavalos de frisa e carroça queimada ----
    for side, f in fronts.items():
        hd = d            # peça com colisor não pode ser de conquista (teste): totens e frisas ficam como restos
        c, g = f["c"], f["deg"]
        ga = math.radians(g)
        for dist, off in ((camp_r + 9.0, 5.2), (camp_r + 22.0, 4.8)):
            for s in (-1, 1):
                q = (c[0] - math.cos(ga) * dist - math.sin(ga) * off * s, c[1] - math.sin(ga) * dist + math.cos(ga) * off * s)
                if hd.ok(q[0], q[1], 0.6, road=0.6):
                    hd.totem(q, rnd.uniform(3.8, 4.8), -g + 90.0)
                    hd.solid(q[0], q[1], 0.9, 0.9, 4.0)
        for k, (dist, off, rot) in enumerate(((camp_r + 4.5, 7.5, 60.0), (camp_r + 4.5, -7.5, -60.0), (camp_r + 14.0, 8.5, 80.0), (camp_r + 14.0, -8.5, -80.0))):
            q = (c[0] - math.cos(ga) * dist - math.sin(ga) * off, c[1] - math.sin(ga) * dist + math.cos(ga) * off)
            if hd.ok(q[0], q[1], 2.0, road=1.2):
                hd.spikes(q, -g + rot, 3.8)
                hd.solid(q[0], q[1], 3.8, 1.0, 1.2, -g + rot)
        for k, deg in enumerate((35.0, 145.0)):
            q = P(c, 5.0, g + deg)
            if hd.ok(q[0], q[1], 1.0, road=0.8):
                hd.weapon_rack(q, -(g + deg))
                hd.solid(q[0], q[1], 2.4, 0.8, 1.6, -(g + deg))
        q = (c[0] - math.cos(ga) * (camp_r + 30.0) - math.sin(ga) * 6.0, c[1] - math.sin(ga) * (camp_r + 30.0) + math.cos(ga) * 6.0)
        if d.ok(q[0], q[1], 2.4, road=1.0):
            d.blob("queimado", d.m("patch_queimado", (0.24, 0.21, 0.2)), q, 3.4, 0.0074, 0.3)
            d.cart(q, rnd.uniform(0, 180), broken=True, color=(0.2, 0.17, 0.16))
            d.solid(q[0], q[1], 3.0, 2.2, 1.4)
            d.cargo((q[0] + 2.6, q[1] + 1.4), 3, 1.2)
    fire = fronts.get("fire")
    if fire:                                                 # flechas de fogo: chão chamuscado e flechas fincadas em volta
        c = fire["c"]
        arrow = d.m("flecha", (0.3, 0.24, 0.2))
        tipm = d.m("glow_flecha", (1.0, 0.5, 0.16))
        for _ in range(26):
            q = P(c, rnd.uniform(camp_r + 3.0, camp_r + 20.0), rnd.uniform(0, 360))
            d.blob("queimado", d.m("patch_queimado", (0.24, 0.21, 0.2)), q, rnd.uniform(0.7, 1.8), 0.0074, 0.35)
            if d.ok(q[0], q[1], 0.3, road=0.2):
                ti = (rnd.uniform(-30, 30), rnd.uniform(-30, 30))
                d.cyl("flechas", arrow, q, 0.035, 0.035, 1.1, 0.0, 4, 0.0, ti)
                d.cyl("flechas", tipm, q, 0.09, 0.0, 0.22, 0.0, 4, 0.0, ti)
    tr = fronts.get("trolls")
    if tr:                                                   # trolls: pedregulhos e ossos roídos
        outcrops(d, [(tr["c"], camp_r + 16.0, 5)], (0.5, 0.48, 0.48), r=(1.6, 2.6), hmul=1.0)
        for _ in range(8):
            q = P(tr["c"], rnd.uniform(camp_r + 3.0, camp_r + 18.0), rnd.uniform(0, 360))
            if d.ok(q[0], q[1], 1.0, road=0.5):
                d.bones(q, rnd.randint(3, 5), 1.2)
    setpieces(d, [((0, 0), 104, 12)], ("bonefield", "ruin", "circle", "wreck", "camp", "bonefield", "crater"), spacing=30.0, stone=(0.6, 0.5, 0.42))
    for k in range(14):                                      # ossadas e marcos pelo campo
        for x, zz in d.spots([((0, 0), 100, 1)], r=1.2, spacing=1.0, road=1.0, blocked=True):
            if k % 3 == 0:
                d.cairn((x, zz), rnd.uniform(0.9, 1.4), (0.6, 0.5, 0.42))
                d.solid(x, zz, 1.0, 1.0, 1.2)
            else:
                d.bones((x, zz), rnd.randint(3, 6), 1.4)
    # ---- Totem dos Ventos: círculo de menires com runa de vento; Cemitério: lascas de marfim; Desertores: lenha ----
    for k in range(7):
        q = P(shrine, 9.0, 20.0 + k * 51.4)
        if d.ok(q[0], q[1], 0.8, road=0.8):
            d.standing_stone(q, rnd.uniform(2.6, 4.0), (0.6, 0.5, 0.42), (0.5, 0.9, 0.9))
            d.solid(q[0], q[1], 1.1, 1.1, 3.0)
    ivory = d.m("marfim", (0.96, 0.93, 0.8))
    for _ in range(30):
        q = P(graveyard, rnd.uniform(3.0, 24.0), rnd.uniform(0, 360))
        if d.ok(q[0], q[1], 0.5, road=0.3):
            d.pebbles("mamutes", ivory, q, rnd.randint(2, 4), 0.9, (0.1, 0.24))
            if rnd.random() < 0.3:
                d.bones(q, 3, 1.0, skull=False)
    q = (deserters[0] - 6.0, deserters[1] - 2.0)
    if d.ok(q[0], q[1], 1.4, road=0.6):
        d.woodpile(q, 40.0, 3, 2.2)
        d.solid(q[0], q[1], 2.4, 1.6, 1.2, 40.0)
    return d.flush()


# ----------------------------------------------------------------------------------------------------------------
# acampamentos de guerra (fort_trolls / fort_fire / fort_war) — desenho com a chegada ao sul; o apply_turn gira depois
# ----------------------------------------------------------------------------------------------------------------
FORT_LOOK = {      # tons do chão = o `ground` do acampamento (MapsCatalog) um pouco acima/abaixo: manchas que não gritam
    "fort_trolls": {"tones": [("toca_claro", (0.65, 0.6, 0.51)), ("toca_escuro", (0.54, 0.5, 0.43)), ("toca_musgo", (0.58, 0.57, 0.44))],
                    "edge": (0.4, 0.37, 0.35), "ruts": None, "rock": (0.5, 0.48, 0.48), "grass": (0.62, 0.58, 0.36)},
    "fort_fire": {"tones": [("fogo_cinza", (0.5, 0.45, 0.4)), ("fogo_carvao", (0.37, 0.33, 0.3)), ("fogo_brasa", (0.46, 0.39, 0.34))],
                  "edge": (0.27, 0.24, 0.23), "ruts": (0.22, 0.2, 0.2), "rock": (0.36, 0.33, 0.32), "grass": (0.56, 0.46, 0.28)},
    "fort_war": {"tones": [("guerra_ouro", (0.72, 0.58, 0.4)), ("guerra_pisado", (0.6, 0.47, 0.33)), ("guerra_palha", (0.7, 0.57, 0.4))],
                 "edge": (0.44, 0.34, 0.27), "ruts": (0.4, 0.31, 0.25), "rock": MESA_ROCK, "grass": STEPPE_GRASS},
}


def fort(z, fid, c, R, gate_pt, arrive, posts, quest):
    look = FORT_LOOK[fid]
    d = Dress(z, 401 + len(fid) * 3 + int(look["edge"][0] * 100))
    hd = d        # o que tem corpo (tenda, totem, frisa, tambor) é neutro: peça de conquista não pode colidir (teste)
    fl = Dress(z, 409 + int(look["edge"][0] * 100), tag="estandarte_horda_det")      # só pano e troféu: somem na retomada
    ad = Dress(z, 419, tag="estandarte_aurora_det")                                  # pano da Aurora: aparece na retomada
    rnd = d.rnd
    dry_ground(d, look["tones"], 120, r=108, streaks=60 if fid != "fort_fire" else 0, ruts=look["ruts"], edge=look["edge"],
               streak_col=tuple(min(1.0, k * 1.1) for k in look["tones"][0][1]))      # risco de vento no tom do chão de cada acampamento
    d.roadside(d.m("seixo_%s" % fid, look["rock"]), d.m("capim_%s" % fid, look["grass"]), every=5.0, lean=WIND, tuft_h=0.9)
    meadow(d, [((0, 30), 100, 70)], look["grass"], flowers=(), lean=WIND, h=1.1)
    outcrops(d, [((0, 30), 100, 12)], look["rock"], r=(1.8, 3.4), hmul=1.5 if fid == "fort_trolls" else 1.1)
    poly = z.road_polys["subida"]
    # ---- chegada: par de totens e braseiros; estrada: tochas alternadas, cavalos de frisa, caveiras em estaca ----
    for s in (-1, 1):
        q = (arrive[0] + s * 6.0, arrive[1] - 5.0)
        if hd.ok(q[0], q[1], 0.6, road=0.4):
            hd.totem(q, 4.6, 0.0)
            hd.solid(q[0], q[1], 0.9, 0.9, 4.0)
        q = (arrive[0] + s * 7.5, arrive[1] + 2.0)
        if d.ok(q[0], q[1], 0.6, road=0.4):
            d.brazier(q, 1.2)
            d.solid(q[0], q[1], 1.2, 1.2, 1.4)
    acc, k = 0.0, 0
    for i in range(2, len(poly) - 3):
        acc += (poly[i] - poly[i - 1]).length
        if acc < 13.0:
            continue
        acc = 0.0
        k += 1
        t = (poly[i + 1] - poly[i - 1]).normalized()
        nr = Vector((-t.y, t.x)) * (1 if k % 2 else -1)
        q = poly[i] + nr * (zone_lib.ROAD_W * 0.5 + 1.5)
        if (q - Vector(c)).length < R + 3.0:
            continue
        if d.ok(q.x, q.y, 0.5, road=0.5):
            d.torch((q.x, q.y), 2.6)
            d.solid(q.x, q.y, 0.4, 0.4, 2.6)
        q2 = poly[i] - nr * (zone_lib.ROAD_W * 0.5 + 3.4)
        if k % 2 == 0 and hd.ok(q2.x, q2.y, 2.0, road=1.0):
            rot = zone_lib.along(t.x, t.y) + 90.0 + rnd.uniform(-20, 20)
            hd.spikes((q2.x, q2.y), rot, 3.6)
            hd.solid(q2.x, q2.y, 3.6, 1.0, 1.2, rot)
        elif k % 2 == 1 and hd.ok(q2.x, q2.y, 0.5, road=0.6):
            pole = hd.m("estaca_caveira", (0.3, 0.24, 0.2))
            hd.cyl("caveira", pole, (q2.x, q2.y), 0.08, 0.06, 2.6, 0.0, 5, 0.0, (rnd.uniform(-6, 6), rnd.uniform(-6, 6)))
            hd.rock("caveira", hd.m("osso", (0.9, 0.87, 0.78)), (q2.x, q2.y), 0.26, 2.5, 0.9)
            hd.solid(q2.x, q2.y, 0.4, 0.4, 2.6)
    # ---- portão: pórtico de toras com travessa, crânio com chifres (Horda) / pano azul (Aurora) e dois braseiros ----
    wood = d.m("portico", (0.34, 0.27, 0.22) if fid != "fort_trolls" else (0.42, 0.4, 0.4))
    for s in (-1, 1):
        d.cyl("portico", wood, (gate_pt[0] + s * 4.5, gate_pt[1]), 0.5, 0.42, 6.4, 0.0, 7)
        d.cyl("portico", wood, (gate_pt[0] + s * 4.5, gate_pt[1]), 0.5, 0.0, 1.0, 6.4, 7)
        q = (gate_pt[0] + s * 6.6, gate_pt[1] + 4.2)
        if d.ok(q[0], q[1], 0.7, road=0.4):
            d.brazier(q, 1.4)
            d.solid(q[0], q[1], 1.3, 1.3, 1.5)
    d.box("portico", wood, gate_pt, (10.4, 0.6, 0.6), 0.0, 5.2)
    d.box("portico", wood, gate_pt, (11.4, 0.4, 0.5), 0.0, 5.9)
    bone = fl.m("osso", (0.9, 0.87, 0.78))
    fl.rock("portico", bone, (gate_pt[0], gate_pt[1] + 0.3), 0.75, 5.5, 0.9)
    for s in (-1, 1):
        fl.tube("portico", bone, [(gate_pt[0] + s * 0.6, 6.3, gate_pt[1] + 0.3), (gate_pt[0] + s * 1.7, 6.5, gate_pt[1] + 0.3), (gate_pt[0] + s * 2.3, 7.6, gate_pt[1] + 0.3)], 0.2, 0.03, 5)
    ad.box("portico", ad.m("pano_fl_30_72", AURORA_BLUE), (gate_pt[0], gate_pt[1] + 0.35), (2.4, 2.4, 0.08), 0.0, 2.9)
    ad.box("portico", ad.m("pano_fl_96_62", AURORA_GOLD), (gate_pt[0], gate_pt[1] + 0.42), (1.0, 1.0, 0.06), 0.0, 3.7)
    # ---- pátio: tendas de couro junto ao muro, cavaletes, estandartes; depois da retomada: carga e carroça da Aurora ----
    for k, deg in enumerate((205.0, 235.0, 305.0, 335.0, 160.0, 20.0)):
        q = P(c, R - 5.4, deg)
        if hd.ok(q[0], q[1], 2.2, road=1.0):
            hd.tent_hide(q, -deg - 90.0, rnd.uniform(1.0, 1.25), [(0.62, 0.48, 0.36), (0.5, 0.38, 0.3)][k % 2])
            hd.solid(q[0], q[1], 3.4, 3.4, 2.4)
            hd.reserve(q[0], q[1], 3.2)
    for k, deg in enumerate((184.0, 356.0, 60.0, 120.0)):
        q = P(c, R - 3.2, deg)
        if hd.ok(q[0], q[1], 1.2, road=0.8):
            if k < 2:
                hd.weapon_rack(q, -deg + 90.0)
                hd.solid(q[0], q[1], 2.4, 0.8, 1.6, -deg + 90.0)
            else:
                fl.flag(q, HORDE_RED, 6.4, 0.0)
                ad.flag(q, AURORA_BLUE, 6.4, 0.0, (0.82, 0.68, 0.48), tatter=False)
                d.solid(q[0], q[1], 0.4, 0.4, 5.0)
    # ---- postos avançados: frisa e braseiro; campo: ossadas e marcos ----
    for i, p in enumerate(posts):
        for k, deg in enumerate((70.0, 110.0)):
            q = P(p, 10.5, deg)
            if hd.ok(q[0], q[1], 2.0, road=1.0):
                hd.spikes(q, -deg + 90.0, 3.4)
                hd.solid(q[0], q[1], 3.4, 1.0, 1.2, -deg + 90.0)
        q = P(p, 4.6, 200.0)
        if d.ok(q[0], q[1], 0.6, road=0.4):
            d.brazier(q, 1.0)
            d.solid(q[0], q[1], 1.0, 1.0, 1.3)
    kinds = {"fort_fire": ("crater", "ruin", "wreck", "camp", "crater", "bonefield"), "fort_war": ("camp", "ruin", "circle", "wreck", "bonefield"),
             "fort_trolls": ("bonefield", "circle", "ruin", "bonefield", "wreck")}[fid]
    setpieces(d, [((-56, 6), 40, 4), ((58, 14), 40, 4), ((0, 62), 40, 2), ((-64, -52), 30, 2), ((64, -56), 30, 2), ((0, -84), 26, 1)], kinds,
              stone=look["rock"], rune=(1.0, 0.5, 0.2) if fid == "fort_fire" else (0.5, 0.9, 0.9))
    for k in range(16):
        for x, zz in d.spots([((0, 34), 96, 1)], r=1.2, spacing=1.0, road=1.0, blocked=True):
            if k % 4 == 0:
                d.cairn((x, zz), rnd.uniform(0.9, 1.4), look["rock"])
                d.solid(x, zz, 1.0, 1.0, 1.2)
            else:
                d.bones((x, zz), rnd.randint(3, 6), 1.4)
    # ---- o que cada acampamento tem de seu ----
    if fid == "fort_fire":
        arrow = d.m("flecha", (0.3, 0.24, 0.2))
        tipm = d.m("glow_flecha", (1.0, 0.5, 0.16))
        burnt = d.m("patch_queimado", (0.2, 0.18, 0.18))
        ember = d.m("glow_brasa_chao", (1.0, 0.45, 0.14))
        for _ in range(70):
            q = (rnd.uniform(-70, 70), rnd.uniform(-10, 92))
            if (Vector(q) - Vector(c)).length < R + 2.0:
                continue
            d.blob("queimado", burnt, q, rnd.uniform(0.8, 2.6), 0.0074, 0.35)
            if rnd.random() < 0.35:
                d.blob("queimado", ember, (q[0] + rnd.uniform(-0.4, 0.4), q[1] + rnd.uniform(-0.4, 0.4)), rnd.uniform(0.15, 0.4), 0.0079, 0.3, 7)
            if d.ok(q[0], q[1], 0.3, road=0.2):
                ti = (rnd.uniform(-30, 30), rnd.uniform(-30, 30))
                d.cyl("flechas", arrow, q, 0.035, 0.035, 1.1, 0.0, 4, 0.0, ti)
                d.cyl("flechas", tipm, q, 0.09, 0.0, 0.22, 0.0, 4, 0.0, ti)
        for k, deg in enumerate((140.0, 40.0)):
            q = P(c, R - 7.0, deg)
            if hd.ok(q[0], q[1], 1.0, road=0.8):
                hd.target(q, -deg + 90.0)
                hd.target((q[0] + 1.6, q[1] + 0.6), -deg + 90.0)
                hd.solid(q[0] + 0.8, q[1] + 0.3, 2.6, 1.0, 1.6)
        for k, q in enumerate(((-9.0, 80.0), (9.0, 52.0), (-8.0, 22.0))):        # barris de piche junto à estrada
            if hd.ok(q[0], q[1], 1.2, road=0.8):
                for j in range(3):
                    hd.barrel((q[0] + (j - 1) * 0.9, q[1] + (j % 2) * 0.6), 1.05, color=(0.2, 0.18, 0.18))
                hd.solid(q[0], q[1], 2.8, 1.6, 1.1)
    elif fid == "fort_war":
        for k, deg in enumerate((30.0, 150.0, 210.0, 330.0)):                    # arquibancada de toras em volta da arena
            q = P(c, 16.4, deg)
            if hd.ok(q[0], q[1], 1.6, road=0.8):
                for row in range(2):
                    qq = P(c, 16.4 + row * 1.1, deg)
                    hd.log("arena", hd.m("tora_56", (0.56, 0.42, 0.28)), qq, 0.3, 4.6, -deg + 90.0, 0.3 + row * 0.5)
                hd.solid(q[0], q[1], 4.6, 2.0, 1.2, -deg + 90.0)
        for k, deg in enumerate((60.0, 120.0, 240.0, 300.0)):                    # troféus: totens com crânio
            q = P(c, 14.6, deg)
            if hd.ok(q[0], q[1], 0.5, road=0.6):
                hd.totem(q, 3.6, -deg, ((0.72, 0.16, 0.13), (0.3, 0.24, 0.2), (0.84, 0.62, 0.24)))
                hd.solid(q[0], q[1], 0.9, 0.9, 3.4)
        for k, q in enumerate(((-11.0, 6.0), (11.0, 6.0), (-15.0, 40.0), (17.0, 70.0))):
            if hd.ok(q[0], q[1], 1.0, road=0.8):
                hd.drum(q, 1.0)
                hd.solid(q[0], q[1], 2.0, 2.0, 1.2)
        ring = d.m("patch_arena_risco", (0.78, 0.2, 0.16))
        for k in range(10):
            a = math.tau * k / 10
            d.arc("arena", ring, c, 9.0, a + 0.05, a + math.tau / 10 - 0.05, 0.4, 0.0155, 0.2, 1.0)
        d.arc("arena", ring, c, 3.0, 0.0, math.tau - 0.01, 0.3, 0.0155, 0.2, 0.8)
    else:
        outcrops(d, [((0, 50), 60, 8)], (0.5, 0.48, 0.48), r=(2.0, 3.6), hmul=1.8)
        for _ in range(14):
            q = P(c, rnd.uniform(6.0, R - 3.0), rnd.uniform(0, 360))
            if d.ok(q[0], q[1], 1.0, road=0.8):
                d.bones(q, rnd.randint(4, 7), 1.4)
        for k, deg in enumerate((225.0, 315.0)):                                  # espeto de assar sobre o braseiro
            q = P(c, 12.0, deg)
            if hd.ok(q[0], q[1], 1.4, road=0.8):
                hd.brazier(q, 1.6)
                hd.log("espeto", hd.m("tora_56", (0.56, 0.42, 0.28)), q, 0.08, 3.4, 20.0, 2.3)
                hd.rock("espeto", hd.m("carne", (0.66, 0.3, 0.26)), q, 0.5, 1.9, 0.7)
                hd.solid(q[0], q[1], 1.6, 1.6, 1.6)
        mouth = (c[0], c[1] - 9.4)
        for k in range(7):                                                        # dentes de pedra na boca da toca
            x = mouth[0] - 2.7 + k * 0.9
            hh = 0.9 + (k % 2) * 0.4
            d.cyl("toca", d.m("dente_toca", (0.7, 0.68, 0.64)), (x, mouth[1] + 1.25), 0.3, 0.0, -hh, 3.6, 5)
    # ---- vida do acampamento (por último, sem colisor): bonecos de treino, fogo de cozinha; retomado, andaime da Aurora ----
    drill = {"fort_war": (168.0, 176.0, 192.0), "fort_fire": (172.0, 180.0, 190.0), "fort_trolls": (150.0, 158.0, 166.0)}[fid]
    n_ok = 0
    for deg in drill + (198.0, 144.0, 136.0):
        q = P(c, R - 8.2, deg)
        if n_ok < 3 and d.ok(q[0], q[1], 1.0, road=0.8):
            d.drill_post(q, -deg + (90.0 if n_ok % 2 else 60.0), shield=HORDE_RED if n_ok != 1 else (0.3, 0.26, 0.22))
            d.reserve(q[0], q[1], 1.4)
            n_ok += 1
    n_ok = 0
    for deg in (18.0, 348.0, 32.0, 336.0, 4.0):
        q = P(c, R - 9.0, deg)
        if n_ok < 2 and d.ok(q[0], q[1], 1.8, road=0.8):
            d.cookfire(q, 1.0 if n_ok == 0 else 0.85, -deg + 90.0, fire="glow_brasa" if fid != "fort_trolls" else "glow_brasa")
            d.reserve(q[0], q[1], 2.4)
            n_ok += 1
    for deg, L in ((63.0, 5.2), (118.0, 4.4)):                                   # andaimes por dentro do muro, dos dois lados do portão
        q = P(c, R - (3.0 if fid == "fort_trolls" else 1.6), deg)
        ad.scaffold(q, -deg + 90.0, L, 4.2)
    return d.flush() + fl.flush() + ad.flush()


# ----------------------------------------------------------------------------------------------------------------
# Grutas Goblin
# ----------------------------------------------------------------------------------------------------------------
def goblin(z, rooms, edges):
    d = Dress(z, 503)
    rnd = d.rnd

    def mouths(name):
        x, y = rooms[name]["pos"]
        out = []
        for a, b in edges:
            if name in (a, b):
                ox, oy = rooms[b if a == name else a]["pos"]
                out.append(math.atan2(oy - y, ox - x))
        return out

    def rim_spots(name, n, k0=0.9, k1=0.99, gap=0.5):
        x, y = rooms[name]["pos"]
        r = rooms[name]["r"]
        ms = mouths(name)
        out = []
        for i in range(n):
            a = math.tau * (i + rnd.uniform(0.2, 0.8)) / n
            if any(abs(math.atan2(math.sin(a - m), math.cos(a - m))) < gap for m in ms):
                continue
            rr = r * rnd.uniform(k0, k1)
            out.append(((x + math.cos(a) * rr, y + math.sin(a) * rr), a))
        return out

    rock = (0.36, 0.34, 0.26)
    # ---- todos os salões: estalagmites na borda e pedrinhas; corredores: cogumelos que brilham, cristais, ossos ----
    for name, room in rooms.items():
        for (p, a) in rim_spots(name, int(room["r"] * 2.2), 0.97, 1.07):
            d.stalagmite(p, rnd.uniform(1.4, 3.4), rnd.uniform(0.5, 0.95), tuple(k * rnd.uniform(1.0, 1.3) for k in rock))
            if rnd.random() < 0.5:
                d.stalagmite((p[0] + rnd.uniform(-0.9, 0.9), p[1] + rnd.uniform(-0.9, 0.9)), rnd.uniform(0.7, 1.4), 0.4, rock)
        for (p, a) in rim_spots(name, int(room["r"] * 1.2), 0.8, 0.93):
            d.pebbles("gruta", d.m("seixo_gruta", (0.44, 0.42, 0.34)), p, rnd.randint(3, 6), 1.0, (0.12, 0.3))
    caps = [(0.4, 0.9, 0.7), (0.5, 0.8, 1.0), (0.9, 0.7, 0.36)]
    for name, poly in z.road_polys.items():
        w = 6.75
        acc = 0.0
        for i in range(2, len(poly) - 2):
            acc += (poly[i] - poly[i - 1]).length
            if acc < 3.2:
                continue
            acc = 0.0
            t = (poly[i + 1] - poly[i - 1]).normalized()
            nr = Vector((-t.y, t.x)) * (1 if rnd.random() < 0.5 else -1)
            q = poly[i] + nr * (w * 0.5 - rnd.uniform(0.1, 0.5))
            if any((q - Vector(r["pos"])).length < r["r"] + 0.5 for r in rooms.values()):
                continue
            k = rnd.random()
            if k < 0.5:
                for _ in range(rnd.randint(2, 4)):
                    d.mushroom((q.x + rnd.uniform(-0.5, 0.5), q.y + rnd.uniform(-0.5, 0.5)), rnd.uniform(0.6, 1.3), caps[int(abs(q.x)) % 2])
                d.blob("gruta", d.m("patch_musgo_gruta", (0.3, 0.42, 0.3)), (q.x, q.y), 1.3, 0.0212, 0.3)
            elif k < 0.7:
                d.crystal((q.x, q.y), rnd.uniform(0.6, 1.0), (0.95, 0.5, 0.3))
            elif k < 0.85:
                d.stalagmite((q.x, q.y), rnd.uniform(0.8, 1.6), 0.4, rock)
            else:
                d.bones((q.x, q.y), 3, 0.7)
    # ---- chegada: tochas ----
    cx, cy = rooms["chegada"]["pos"]
    for s in (-1, 1):
        d.torch((cx + s * 4.6, cy + 2.0), 2.4)
    # ---- lamaçal: poças de lama, passarela de tábuas até as bocas, cogumelos e juncos ----
    x, y = rooms["lamacal"]["pos"]
    r = rooms["lamacal"]["r"]
    mud = [d.m("patch_lama_esc", (0.24, 0.34, 0.26)), d.m("patch_lama_clara", (0.36, 0.5, 0.36)), d.m("glow_lodo", (0.36, 0.62, 0.5))]
    for i in range(16):
        q = P((x, y), rnd.uniform(3.0, r * 0.84), rnd.uniform(0, 360))
        d.blob("lamacal", mud[i % 2], q, rnd.uniform(0.9, 2.4), 0.0225 + (i % 2) * 0.0004, 0.35)
        if i % 5 == 0:
            d.blob("lamacal", mud[2], q, 0.35, 0.0235, 0.2, 8)
    for m in mouths("lamacal"):
        d.planks([(x + math.cos(m) * r * 0.96, y + math.sin(m) * r * 0.96), (x + math.cos(m + 0.25) * r * 0.6, y + math.sin(m + 0.25) * r * 0.6),
                  (x + math.cos(m) * r * 0.3, y + math.sin(m) * r * 0.3)], 1.5, 0.03, color=(0.42, 0.34, 0.22))
    for (p, a) in rim_spots("lamacal", 16, 0.86, 0.95):
        for _ in range(rnd.randint(2, 4)):
            d.mushroom((p[0] + rnd.uniform(-0.6, 0.6), p[1] + rnd.uniform(-0.6, 0.6)), rnd.uniform(0.7, 1.5), caps[0])
        d.tuft("lamacal3d", d.m("junco_gruta", (0.36, 0.5, 0.26)), p, 0.5, 1.1, 6)
    # ---- forja: rachaduras de lava saindo da poça, carvão, braseiros e cavaletes na borda ----
    x, y = rooms["forja"]["pos"]
    r = rooms["forja"]["r"]
    lava = d.m("glow_lava", (1.0, 0.46, 0.14))
    soot = d.m("patch_fuligem", (0.26, 0.2, 0.18))
    for k in range(9):
        a = math.tau * k / 9 + rnd.uniform(-0.2, 0.2)
        L = r * rnd.uniform(0.4, 0.8)
        pts = [Vector((x + math.cos(a) * r * 0.2, y + math.sin(a) * r * 0.2))]
        for j in range(1, 5):
            aa = a + rnd.uniform(-0.25, 0.25)
            pts.append(Vector((x + math.cos(aa) * (r * 0.2 + L * j / 4), y + math.sin(aa) * (r * 0.2 + L * j / 4))))
        d.strip("forja", soot, pts, 0.9, 0.0222, 0.4, taper=True)
        d.strip("forja", lava, pts, 0.26, 0.0232, 0.3, taper=True)
    coal = d.m("carvao", (0.16, 0.15, 0.16))
    for (p, a) in rim_spots("forja", 10, 0.86, 0.95):
        k = rnd.random()
        if k < 0.4:
            d.pebbles("forja3d", coal, p, 7, 0.9, (0.2, 0.42))
            d.blob("forja", lava, p, 0.3, 0.0236, 0.2, 7)
        elif not d.ok(p[0], p[1], 0.8, road=0.2):
            continue
        elif k < 0.7:
            d.brazier(p, 1.1, fire="glow_lava", color=(1.0, 0.46, 0.14))
            d.solid(p[0], p[1], 1.1, 1.1, 1.4)
        else:
            d.weapon_rack(p, math.degrees(-a) + 90.0)
            d.solid(p[0], p[1], 2.4, 0.8, 1.6, math.degrees(-a) + 90.0)
    # ---- tambores: anéis pintados no chão, tambores e flâmulas na borda ----
    x, y = rooms["tambores"]["pos"]
    r = rooms["tambores"]["r"]
    paint = [d.m("patch_tinta_osso", (0.86, 0.8, 0.62)), d.m("patch_tinta_sangue", (0.7, 0.2, 0.2))]
    for k, rr in enumerate((r * 0.36, r * 0.52, r * 0.7)):
        n = 8 + k * 4
        for j in range(n):
            a = math.tau * j / n
            d.arc("tambores", paint[(k + j) % 2], (x, y), rr, a + 0.04, a + math.tau / n - 0.04, 0.34, 0.0225, 0.25, 0.9)
    for j, (p, a) in enumerate(rim_spots("tambores", 12, 0.88, 0.95)):
        if not d.ok(p[0], p[1], 0.8, road=0.2):
            continue
        if j % 2:
            d.drum(p, rnd.uniform(0.7, 1.1))
            d.solid(p[0], p[1], 1.8, 1.8, 1.2)
        else:
            d.solid(p[0], p[1], 0.4, 0.4, 4.0)
            d.flag(p, [HORDE_RED, (0.86, 0.6, 0.2)][j % 4 // 2], 4.6, math.degrees(-a) + 90.0, w=0.9, drop=1.5)
    # ---- selo: círculo de runas em brasa, raios, totens, crânios e braseiros ----
    x, y = rooms["selo"]["pos"]
    r = rooms["selo"]["r"]
    rune = d.m("glow_runa_selo", (1.0, 0.4, 0.16))
    blood = d.m("patch_tinta_sangue", (0.7, 0.2, 0.2))
    for rr, n, w in ((r * 0.34, 10, 0.3), (r * 0.56, 14, 0.36)):
        for j in range(n):
            a = math.tau * j / n
            d.arc("selo", rune, (x, y), rr, a + 0.05, a + math.tau / n - 0.05, w, 0.0232, 0.15, 0.8)
    for j in range(10):
        a = math.degrees(math.tau * j / 10 + 0.1)
        d.strip("selo", blood if j % 2 else rune, [Vector(P((x, y), r * 0.37, a)), Vector(P((x, y), r * 0.45, a + 3)), Vector(P((x, y), r * 0.53, a))],
                0.4 if j % 2 else 0.2, 0.0228, 0.2, taper=True)
    for j, (p, a) in enumerate(rim_spots("selo", 16, 0.89, 0.95)):
        k = j % 4
        if not d.ok(p[0], p[1], 0.8, road=0.2):
            continue
        if k == 0:
            d.totem(p, rnd.uniform(3.4, 4.4), math.degrees(-a) + 90.0)
            d.solid(p[0], p[1], 0.9, 0.9, 3.4)
        elif k == 1:
            d.brazier(p, 1.3)
            d.solid(p[0], p[1], 1.2, 1.2, 1.4)
        elif k == 2:
            d.flag(p, HORDE_RED, 5.4, math.degrees(-a) + 90.0, w=1.1, drop=1.8)
            d.solid(p[0], p[1], 0.4, 0.4, 4.0)
        else:
            d.bones(p, 6, 1.0)
    # ---- mina dos cativos (por último, sem colisor): trilho do Lamaçal à Forja com vagonetes nas pontas, picaretas e
    #      montes de pedra brilhante na beira dos salões onde eles cavam ----
    track = [(-5.0, 24.6), (-9.0, 23.4), (-18.0, 19.4), (-26.0, 13.4), (-29.0, 9.8)]
    d.rails(track)
    d.ore_cart(track[0], zone_lib.along(track[1][0] - track[0][0], track[1][1] - track[0][1]))
    d.ore_cart(track[-1], zone_lib.along(track[-1][0] - track[-2][0], track[-1][1] - track[-2][1]), full=False)
    mid = Vector(track[2]).lerp(Vector(track[3]), 0.5)
    d.ore_cart((mid.x, mid.y), zone_lib.along(track[3][0] - track[2][0], track[3][1] - track[2][1]))
    for name, n in (("lamacal", 9), ("forja", 8), ("tambores", 8)):
        for j, (p, a) in enumerate(rim_spots(name, n, 0.8, 0.9)):
            if not d.ok(p[0], p[1], 1.0, road=0.2):
                continue
            if j % 3 == 0:
                d.ore_pile(p, rnd.randint(4, 6))
                d.pickaxe((p[0] - math.cos(a) * 0.9, p[1] - math.sin(a) * 0.9), math.degrees(-a))
            elif j % 3 == 1:
                d.pickaxe(p, math.degrees(-a))
                d.pickaxe((p[0] + 0.5, p[1] + 0.3), math.degrees(-a) + 25.0, lean=30.0)
                d.crate((p[0] - math.sin(a) * 0.9, p[1] + math.cos(a) * 0.9), 0.7, rnd.uniform(0, 60), 0.0, "mina")
            else:
                d.ore_pile(p, 3)
    return d.flush()


# ----------------------------------------------------------------------------------------------------------------
# conjuntos pequenos para os vazios do mapa (nada de campo liso entre uma estrada e a borda)
# ----------------------------------------------------------------------------------------------------------------
def setpiece(d, kind, c, rot, stone=(0.6, 0.5, 0.42), rune=(0.5, 0.9, 0.9)):
    """Um conjunto de ~6 m de raio em volta de `c`: acampamento largado, carroça tombada, ossada grande, círculo de
    menires, resto de paliçada, cratera queimada, pouso de pescador. Peça com corpo ganha colisor."""
    rnd = d.rnd
    x, z = c
    if kind == "camp":
        for k, deg in enumerate((rot + 20.0, rot + 150.0)):
            q = P(c, 3.6, deg)
            d.tent_hide(q, -deg - 90.0, rnd.uniform(0.95, 1.15), [(0.56, 0.44, 0.34), (0.48, 0.4, 0.34)][k], trim=(0.4, 0.3, 0.26))
            d.solid(q[0], q[1], 3.2, 3.2, 2.4)
        d.blob("conjunto", d.m("patch_pisado_conj", (0.4, 0.36, 0.32)), c, 3.2, 0.0073, 0.3)
        d.brazier(c, 1.1)
        d.solid(x, z, 1.1, 1.1, 1.3)
        q = P(c, 4.2, rot + 265.0)
        d.weapon_rack(q, -rot)
        d.solid(q[0], q[1], 2.4, 0.8, 1.6, -rot)
        d.bones(P(c, 5.0, rot + 80.0), 4, 1.0)
    elif kind == "wreck":
        d.blob("conjunto", d.m("patch_queimado", (0.24, 0.21, 0.2)), c, 3.6, 0.0074, 0.3)
        d.cart(c, rot, broken=True, color=(0.24, 0.2, 0.18))
        d.solid(x, z, 3.0, 2.2, 1.4, rot)
        d.cargo(P(c, 3.2, rot + 40.0), 4, 1.3)
        d.pebbles("mini", d.m("carvao", (0.16, 0.15, 0.16)), P(c, 2.4, rot + 200.0), 6, 1.2, (0.15, 0.32))
    elif kind == "bonefield":
        bone = d.m("osso", (0.9, 0.87, 0.78))
        a = math.radians(rot)
        ux, uz = math.cos(a), math.sin(a)
        d.log("conjunto", bone, c, 0.24, 7.0, -rot, 0.2, 0.12)
        for i in range(5):
            t = (i - 2) * 1.4
            k = 1.0 - 0.13 * abs(i - 2)
            for s in (-1, 1):
                b0 = (x + ux * t - uz * s * 0.3, z + uz * t + ux * s * 0.3)
                d.tube("conjunto", bone, [(b0[0], 0.2, b0[1]), (b0[0] - uz * s * 2.0 * k, 2.2 * k, b0[1] + ux * s * 2.0 * k),
                                          (b0[0] - uz * s * 1.2 * k, 3.4 * k, b0[1] + ux * s * 1.2 * k)], 0.2, 0.06, 5)
        hd = (x + ux * 4.6, z + uz * 4.6)
        d.rock("conjunto", bone, hd, 1.0, 0.0, 0.8)
        for s in (-1, 1):
            d.tube("conjunto", bone, [(hd[0] - uz * s * 0.7, 0.5, hd[1] + ux * s * 0.7), (hd[0] + ux * 1.6 - uz * s * 1.2, 0.9, hd[1] + uz * 1.6 + ux * s * 1.2),
                                      (hd[0] + ux * 2.4 - uz * s * 0.6, 2.0, hd[1] + uz * 2.4 + ux * s * 0.6)], 0.2, 0.04, 5)
        d.solid(x, z, 7.0, 3.6, 2.0, -rot)
        d.solid(hd[0], hd[1], 2.0, 2.0, 1.6)
        d.bones(P(c, 5.0, rot + 120.0), 5, 1.4)
    elif kind == "circle":
        d.blob("conjunto", d.m("patch_circulo", tuple(k * 0.86 for k in stone)), c, 5.6, 0.0073, 0.2)
        for k in range(7):
            q = P(c, 4.6, rot + k * 51.4)
            if k == 3:
                d.log("conjunto", d.m("menir_%d" % int(stone[0] * 100), stone), q, 0.5, 3.0, rot + 30.0, 0.4)      # um menir tombado
                d.solid(q[0], q[1], 3.0, 1.0, 1.0, rot + 30.0)
                continue
            d.standing_stone(q, rnd.uniform(2.4, 3.8), stone, rune if k % 2 == 0 else None)
            d.solid(q[0], q[1], 1.1, 1.1, 3.0)
        d.cairn(c, 1.5, stone)
        d.solid(x, z, 1.4, 1.4, 1.4)
    elif kind == "ruin":
        wood = d.m("ruina_estaca", (0.34, 0.28, 0.23))
        for k in range(9):
            if k in (3, 6):
                continue
            q = P(c, 5.0, rot + k * 17.0)
            h = rnd.uniform(1.2, 3.4)
            ti = (rnd.uniform(-10, 10), rnd.uniform(-10, 10))
            d.cyl("conjunto", wood, q, 0.36, 0.33, h, 0.0, 6, 0.0, ti)
            d.cyl("conjunto", wood, q, 0.36, 0.0, 0.6, h, 6, 0.0, ti)
            d.solid(q[0], q[1], 0.9, 0.9, 2.0)
        q = P(c, 2.0, rot + 70.0)
        d.spikes(q, -rot + 20.0, 3.6)
        d.solid(q[0], q[1], 3.6, 1.0, 1.2, -rot + 20.0)
        d.log("conjunto", wood, P(c, 3.4, rot + 200.0), 0.3, 3.2, rot * 0.5, 0.3)
        d.bones(P(c, 1.5, rot + 250.0), 4, 1.0)
    elif kind == "crater":
        d.blob("conjunto", d.m("patch_queimado", (0.24, 0.21, 0.2)), c, 4.6, 0.0074, 0.3)
        d.blob("conjunto", d.m("patch_cratera", (0.15, 0.13, 0.13)), c, 2.6, 0.0077, 0.25)
        ember = d.m("glow_brasa_chao", (1.0, 0.45, 0.14))
        for _ in range(7):
            d.blob("conjunto", ember, P(c, rnd.uniform(0.3, 2.2), rnd.uniform(0, 360)), rnd.uniform(0.15, 0.4), 0.008, 0.3, 7)
        rk = d.m("carvao", (0.16, 0.15, 0.16))
        for k in range(8):
            d.rock("conjunto", rk, P(c, rnd.uniform(2.6, 3.6), k * 45.0 + rnd.uniform(-12, 12)), rnd.uniform(0.35, 0.8), -0.1, 0.7)
        d.solid(x, z, 1.6, 1.6, 0.8)
    elif kind == "fisher":
        d.blob("conjunto", d.m("patch_pisado_praia", (0.72, 0.66, 0.5)), c, 4.4, 0.0073, 0.3)
        d.net_rack(P(c, 2.6, rot), rot + 90.0)
        q = P(c, 2.6, rot)
        d.solid(q[0], q[1], 0.6, 4.2, 2.0, rot)
        q = P(c, 2.8, rot + 150.0)
        d.fish_rack(q, rot + 60.0)
        d.solid(q[0], q[1], 2.6, 0.5, 1.7, rot + 60.0)
        q = P(c, 3.2, rot + 250.0)
        d.rowboat(q, rot + 30.0, 4.0, (0.36, 0.46, 0.6), tilt=(10, 0))
        d.solid(q[0], q[1], 3.6, 1.6, 1.0, rot + 30.0)
        d.brazier(c, 0.9)
        d.solid(x, z, 1.0, 1.0, 1.2)
        d.cargo(P(c, 4.4, rot + 300.0), 3, 0.9)


def setpieces(d, centers, kinds, spacing=26.0, **kw):
    """Espalha conjuntos (um tipo de cada vez, em rodízio) pelos vazios: longe de estrada, POI, spawner e uns dos outros."""
    n = 0
    for x, z in d.spots(centers, r=7.0, spacing=spacing, road=3.0, water=3.0, blocked=True, tall=True, tries=30):
        setpiece(d, kinds[n % len(kinds)], (x, z), d.rnd.uniform(0, 360), **kw)
        d.reserve(x, z, 8.0)
        n += 1
    return n
