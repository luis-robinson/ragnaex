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
def shoreline(d, c, r, beach, palms=10, boats=3, rocks=10, tongue_y=0.0046):
    """Borda do mar lida de cima: areia molhada, espuma em gomos, linhas de onda, baixios claros, pedras com espuma,
    conchas, algas, capim de duna na passagem areia/grama e palmeiras no fundo da praia.
    `tongue_y`: altura das línguas de areia na passagem areia/grama (a areia do mar fica a 4,0 mm: a língua pode ir por cima
    ou por baixo dela, desde que a 0,5 mm+ e longe das outras camadas que cruzam a praia)."""
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
        d.blob("praia", d.m("patch_areia_mar", SAND), p, rnd.uniform(1.6, 3.6), tongue_y, 0.35, sx=1.6, rot=rnd.uniform(0, 180))
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
    # pilha (mm): campo 0,8/1,6/2,4 < mata 3,2 (não chega à praia) e línguas de areia 3,4 < areia do mar 4,0 (sea.py) < faixa
    # do mangue 4,6 (build_field_coast.mangrove_band) < lama 5,2/5,6 < manchas e lugares 6,0. Entre a areia e os 6,0 mm só
    # cabem 3 camadas: 0,6 mm onde a sobreposição é grande (areia/faixa, faixa/lama; com 0,4 listrava na foto) e 0,4 mm onde
    # é pouca (os dois tons de lama entre si e a lama sob os lugares), não 0,8.
    # Antes: campo 4,8/5,0/5,2, mata 5,4/5,6/5,8 e lama 5,6/5,8/6,0 (0,2 mm e planos repetidos entre mata, lama e lugares)
    d.mottle([("campo_claro", (0.6, 0.71, 0.43)), ("campo_escuro", (0.47, 0.6, 0.37)), ("campo_seco", (0.6, 0.68, 0.42))],
             [((0, -10), 112, 130)], y=0.0008, rmin=3.0, rmax=8.5, step=0.0008)
    d.mottle([("mata_sombra", (0.43, 0.56, 0.35))], [((0, -62), 50, 26), ((70, -22), 30, 12), ((-90, -60), 26, 10)], y=0.0032, rmin=5.0, rmax=11.0, group="mata")
    d.road_edges((0.58, 0.54, 0.4))
    d.roadside(d.m("seixo_estrada", (0.62, 0.58, 0.5)), d.m("capim_beira", (0.5, 0.62, 0.34)), every=6.0, lean=(0.1, 0.04))
    d.reserve(4.0, 68.0, 15.0)          # arena da Mãe das Marés: nada de palmeira nem bote no meio da luta
    shoreline(d, sea_c, sea_r, 18.0, palms=14, boats=4, rocks=14, tongue_y=0.0034)
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
             ((-58, 24), 12, 6), ((-52, 58), 12, 6), ((-42, 90), 10, 4)], y=0.0052, rmin=2.0, rmax=4.5, group="mangue",
             step=0.0004)       # 2 tons = 2 planos, entre a faixa do mangue (4,6) e as manchas/lugares (6,0)
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
# vara de pescar da praia (candidatos; a primeira que couber): espelhada em MapsCatalog (port_vil_fisher_c fica 0,9 m atrás dela)
PORT_SHORE_POLE = ((-13.0, 66.4), (-15.0, 66.2), (-3.5, 66.6))


def port(z, sea_c, sea_r, town_c, town_r, plaza_r, gates, gate_half, farm, shipyard_c, beacon_c, beacon_root, post_c, ship_c, ship_rot, ship_L, piers):
    d = Dress(z, 211)
    rnd = d.rnd
    H = lambda r, a: P(town_c, r, a)
    avs = tuple(n for n in z.road_polys if n.startswith("av_"))
    # pilha (mm), como na Costa: campo 0,8/1,6/2,4 < mata 3,2 < areia do mar 4,0 < manchas e lugares 6,0+
    d.mottle([("campo_claro", (0.6, 0.71, 0.43)), ("campo_escuro", (0.47, 0.6, 0.37)), ("campo_seco", (0.6, 0.68, 0.42))], [((0, -20), 96, 90)],
             y=0.0008, rmin=3.0, rmax=8.0, step=0.0008)
    d.mottle([("mata_sombra", (0.43, 0.56, 0.35))], [((0, -62), 36, 18), ((-70, -40), 24, 10), ((72, 8), 20, 8)], y=0.0032, rmin=5.0, rmax=10.0, group="mata")
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
    # vara de pescar na AREIA, do lado do píer oeste (PORT_SHORE_POLE): o pescador dela fica em chão seco, a um passo de quem
    # chega pela praia (os dos píeres só se alcançam com `reach`). Sem colisor; a boia cai na água, além da linha da praia.
    for q in PORT_SHORE_POLE:
        if d.ok(q[0], q[1], 0.5, road=0.3, water=0.0):
            d.fishing_pole(q, zone_lib.along(sea_c[0] - q[0], sea_c[1] - q[1]), 3.4, 0.0)
            print("PORT_SHORE_POLE %.1f %.1f rot %.1f" % (q[0], q[1], zone_lib.along(sea_c[0] - q[0], sea_c[1] - q[1])))
            break
    return d.flush()


# ----------------------------------------------------------------------------------------------------------------
# Estepes de Cinza
# ----------------------------------------------------------------------------------------------------------------
WIND = (0.17, 0.05)            # empurrão das pontas do capim (vento de oeste)
STEPPE_GRASS = (0.74, 0.58, 0.24)
MESA_ROCK = (0.56, 0.4, 0.3)


def dry_ground(d, tones, n, r=108, streaks=110, streak_col=(0.84, 0.74, 0.46), ruts=(0.42, 0.37, 0.31), edge=(0.5, 0.44, 0.35), c=(0, 0), streak_soft=False,
               mottle_y=0.0018, mottle_step=0.0008, streak_y=0.0042):
    """Chão de estepe: manchas em três tons, riscos claros de vento todos no mesmo rumo, acostamento pisado e sulcos de roda.
    `streak_soft`: o risco vira uma língua de cinza soprada (arco suave de 9 pontos, mais larga no meio, as duas pontas em
    bico). O risco padrão é uma fita de 3 pontos com as pontas cortadas retas: some no capim claro da estepe, mas no chão
    escuro e aberto de Kharzun lia-se como ripa reta de ponta quadrada. Gasta os mesmos sorteios do `d.rnd` (a sim não muda).
    `mottle_y`/`mottle_step`/`streak_y`: alturas das manchas (3 planos) e dos riscos; planos a 0,2 mm brigam (faixas).
    Padrão (Estepes e acampamentos): manchas 1,8/2,6/3,4 mm e risco 4,2 mm, tudo abaixo do chão limpo das frentes (5,0),
    das manchas `Zone.patch` e do chão dos lugares (6,0+). Antes: 4,8/5,0/5,2 e risco 6,2 (por cima dos lugares, a 0,2 mm)."""
    rnd = d.rnd
    d.mottle(tones, [(c, r, n)], y=mottle_y, rmin=3.0, rmax=9.0, step=mottle_step)
    sm = d.m("patch_risco_vento", streak_col)
    wd = Vector((1.0, 0.3)).normalized()
    for _ in range(streaks):
        a, rr = rnd.uniform(0, math.tau), r * math.sqrt(rnd.random())
        p = Vector((c[0] + math.cos(a) * rr, c[1] + math.sin(a) * rr))
        if p.length > d.z.rim_r(math.atan2(p.y, p.x)) - 3.0:
            continue
        L = rnd.uniform(4.0, 11.0)
        side = Vector((-wd.y, wd.x)) * rnd.uniform(-0.5, 0.5)
        w = rnd.uniform(0.22, 0.5)
        if streak_soft:
            a0, ctrl, a1 = p - wd * L * 0.5, p + side * 4.0, p + wd * L * 0.5          # Bézier: barriga de até 1 m no meio
            pts = [a0 * (1 - t) ** 2 + ctrl * 2 * t * (1 - t) + a1 * t ** 2 for t in (k / 8 for k in range(9))]
            d.strip("vento", sm, pts, w * 1.7, streak_y, 0.3, taper="point")
        else:
            d.strip("vento", sm, [p - wd * L * 0.5, p + side, p + wd * L * 0.5], w, streak_y, 0.3, taper=True)
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
    dry_ground(d, [("estepe_ouro", (0.82, 0.68, 0.36)), ("estepe_queimado", (0.62, 0.5, 0.3)), ("estepe_palha", (0.78, 0.7, 0.44))], 150,
               streak_soft=True)
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
                    "edge": (0.4, 0.35, 0.3), "ruts": None, "rock": (0.5, 0.48, 0.48), "grass": (0.62, 0.58, 0.36)},
    "fort_fire": {"tones": [("fogo_cinza", (0.5, 0.45, 0.4)), ("fogo_carvao", (0.37, 0.33, 0.3)), ("fogo_brasa", (0.46, 0.39, 0.34))],
                  "edge": (0.27, 0.24, 0.23), "ruts": (0.22, 0.2, 0.2), "rock": (0.36, 0.33, 0.32), "grass": (0.56, 0.46, 0.28)},
    "fort_war": {"tones": [("guerra_ouro", (0.72, 0.58, 0.4)), ("guerra_pisado", (0.6, 0.47, 0.33)), ("guerra_palha", (0.7, 0.57, 0.4))],
                 "edge": (0.44, 0.34, 0.27), "ruts": (0.4, 0.31, 0.25), "rock": MESA_ROCK, "grass": STEPPE_GRASS},
}


# bonecos de treino do pátio: candidatos (recuo do muro em m, ângulo em graus), espelhados em run_tests FORT_DRILL. Na Toca
# os pedregulhos e as jaulas tomam o anel de 8,2 m: os bonecos vão para o meio do pátio, do lado da fogueira do espeto.
FORT_DRILL_INSET = 8.2
FORT_DRILL = {
    "fort_war": ((8.2, 168.0), (8.2, 176.0), (8.2, 192.0)),
    "fort_fire": ((8.2, 172.0), (8.2, 180.0), (8.2, 190.0)),
    "fort_trolls": ((12.0, 196.0), (12.0, 206.0), (12.0, 216.0), (8.2, 150.0), (8.2, 158.0), (8.2, 166.0)),
}


def fort(z, fid, c, R, gate_pt, arrive, posts, quest):
    look = FORT_LOOK[fid]
    d = Dress(z, 401 + len(fid) * 3 + int(look["edge"][0] * 100))
    hd = d        # o que tem corpo (totem, frisa, tambor; da tenda, só o colisor) é neutro: peça de conquista não pode colidir (teste)
    fl = Dress(z, 409 + int(look["edge"][0] * 100), tag="estandarte_horda_det")      # só pano e troféu: somem na retomada
    ad = Dress(z, 419, tag="estandarte_aurora_det")                                  # pano da Aurora: aparece na retomada
    rnd = d.rnd
    dry_ground(d, look["tones"], 120, r=108, streaks=60 if fid != "fort_fire" else 0, ruts=look["ruts"], edge=look["edge"],
               streak_col=tuple(min(1.0, k * 1.1) for k in look["tones"][0][1]), streak_soft=True)      # risco de vento no tom do chão de cada acampamento
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
            # a tenda de couro é da Horda (some na retomada) e o pavilhão da Aurora entra no mesmo chão; o colisor é um só,
            # neutro, e vale para as duas. As 28 voltas gastam o sorteio que a tenda gastava no lote neutro (o cyl sorteia
            # por gomo mesmo sem jitter): o resto do acabamento, e os colisores dele, saem iguais aos de antes.
            sc = rnd.uniform(1.0, 1.25)
            for _ in range(28):
                rnd.random()
            fl.tent_hide(q, 90.0 - deg, sc, [(0.62, 0.48, 0.36), (0.5, 0.38, 0.3)][k % 2])
            ad.tent_aurora(q, 90.0 - deg, sc * 0.96)          # as duas com a boca para o pátio
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
    drill = FORT_DRILL[fid] + tuple((FORT_DRILL_INSET, deg) for deg in (198.0, 144.0, 136.0))
    n_ok = 0
    for inset, deg in drill:
        q = P(c, R - inset, deg)
        if n_ok < 3 and d.ok(q[0], q[1], 1.0, road=0.8):
            # boneco de treino com escudo da Horda some na retomada; no mesmo ponto entra o da Aurora (escudo azul, umbigo e
            # faixa dourados). Sem colisor (só reserva). As 56 voltas gastam o sorteio que o boneco gastava no lote neutro.
            for _ in range(56):
                rnd.random()
            rot = -deg + (90.0 if n_ok % 2 else 60.0)
            fl.drill_post(q, rot, shield=HORDE_RED if n_ok != 1 else (0.3, 0.26, 0.22))
            ad.drill_post(q, rot, shield=AURORA_BLUE if n_ok != 1 else (0.88, 0.84, 0.7), boss=AURORA_GOLD, crest=AURORA_GOLD if n_ok != 1 else AURORA_BLUE)
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
    fort_far(d, fid, c, R, look)
    return d.flush() + fl.flush() + ad.flush()


# o que sobra nos quadrantes longe da estrada de cada acampamento (rodízio): restos baixos, sem corpo
FAR_KINDS = {"fort_trolls": ("midden", "tracks", "fire", "midden", "skirmish", "tracks"),
             "fort_fire": ("scorch", "skirmish", "fire", "scorch", "tracks", "skirmish"),
             "fort_war": ("skirmish", "wheel", "fire", "tracks", "skirmish", "wheel")}
FAR_ROAD = 20.0                # m da estrada: aquém disso a beira de estrada e os conjuntos já enchem o chão
FAR_SPACING = 13.0             # m entre um resto e outro
FAR_MAX = 60


def fort_far(d, fid, c, R, look):
    """Quadrantes longe da estrada (atrás e dos lados do acampamento): fogueiras apagadas, restos de escaramuça, rastros,
    monturos de osso. Tudo baixo e SEM colisor nem reserva nova de sim (o JSON da zona não muda); entra no lote neutro por
    último, depois de tudo que sorteia posição de colisor. Só nasce onde `Dress.ok` deixa (fora de pedra, árvore, água)."""
    z, rnd = d.z, d.rnd
    kinds = FAR_KINDS[fid]
    cv = Vector(c)
    sites = []
    for _ in range(1400):
        if len(sites) >= FAR_MAX:
            break
        a, rr = rnd.uniform(0, math.tau), 104.0 * math.sqrt(rnd.random())
        p = Vector((math.cos(a) * rr, math.sin(a) * rr))
        if (p - cv).length < R + 7.0 or any((p - q).length < FAR_SPACING for q in sites):
            continue
        if any(zone_lib.poly_dist(p, poly) < FAR_ROAD for poly in z.road_polys.values()):
            continue
        if not d.ok(p.x, p.y, 2.4, road=2.0, water=2.0, rim=5.0):
            continue
        sites.append(p)
    for k, p in enumerate(sites):
        far_piece(d, kinds[k % len(kinds)], (p.x, p.y), rnd.uniform(0, 360), look)
        d.reserve(p.x, p.y, 3.0)
    print("FORT_FAR %s %d" % (fid, len(sites)))
    return len(sites)


def far_piece(d, kind, c, rot, look):
    """Um resto de ~3 m de raio, baixo (ninguém fica tapado) e sem corpo: o boneco passa por cima. Geometria magra de
    propósito (são dezenas por mapa): osso/haste = prisma de 3 lados sem tampa, pedra = toco de 4 lados."""
    rnd = d.rnd
    bone = d.m("osso", (0.9, 0.87, 0.78))
    char = d.m("carvao", (0.16, 0.15, 0.16))
    wood = d.m("resto_madeira", (0.36, 0.29, 0.23))
    stone = d.m("resto_pedra", look["rock"])
    grass = d.m("capim_resto_%d" % int(look["grass"][0] * 100), look["grass"])
    free = lambda q, r=0.3: d.ok(q[0], q[1], r, road=0.6, water=0.8)

    def stick(g, m, q, r, L, deg, y=0.06, segs=3, cap=False):       # vara deitada, centrada em q (como Dress.log, mais magra)
        a = math.radians(deg)
        st = (q[0] - math.cos(a) * L * 0.5, q[1] + math.sin(a) * L * 0.5)
        d.cyl(g, m, st, r, r, L, y, segs, deg, tilt=(0, 90), cap=cap)

    def pebble(m, q, r):                                            # pedra: toco facetado de 4 lados
        d.cyl("mini", m, q, r, r * 0.55, r * 0.8, 0.0, 4, rnd.uniform(0, 90))

    def bones(q, n, spread, skull=True):
        for _ in range(n):
            a, dd = rnd.uniform(0, math.tau), rnd.uniform(0.2, spread)
            stick("ossos", bone, (q[0] + math.cos(a) * dd, q[1] + math.sin(a) * dd), 0.055, rnd.uniform(0.5, 1.1), rnd.uniform(0, 360))
        if skull:
            d.rock("ossos", bone, q, 0.22, 0.0, 0.85, sub=1)

    if kind == "fire":                                  # fogueira apagada: cinza, roda de pedras, tições, toras de sentar
        d.blob("resto", d.m("patch_pisado_resto", tuple(k * 0.8 for k in look["tones"][1][1])), c, 2.9, 0.0071, 0.3, 14)
        d.blob("resto", d.m("patch_cinza_resto", (0.24, 0.22, 0.21)), c, 1.0, 0.0078, 0.25, 9)
        for k in range(6):
            pebble(stone, P(c, 0.95, rot + k * 60.0 + rnd.uniform(-10, 10)), rnd.uniform(0.18, 0.28))
        for k in range(3):
            stick("resto", char, P(c, 0.2, rot + k * 120.0), 0.07, rnd.uniform(0.9, 1.3), rot + k * 61.0, 0.1)
        for k, deg in enumerate((rot + 30.0, rot + 170.0, rot + 265.0)[:rnd.randint(2, 3)]):
            q = P(c, 2.1, deg)
            if free(q, 0.9):
                stick("resto", wood, q, 0.2, rnd.uniform(1.5, 2.1), -deg + 90.0, 0.17, 5, True)
        q = P(c, 2.6, rot + 100.0)
        if free(q, 0.8):
            bones(q, 3, 0.7, False)
    elif kind == "skirmish":                            # escaramuça velha: flechas cravadas, escudo rachado, lança partida, ossos
        d.blob("resto", d.m("patch_mancha_resto", tuple(k * 0.72 for k in look["tones"][1][1])), c, 1.8, 0.0071, 0.35, 11)
        arrow = d.m("flecha", (0.3, 0.24, 0.2))
        feather = d.m("flecha_pena", (0.74, 0.7, 0.62))
        for _ in range(rnd.randint(5, 8)):
            q = (c[0] + rnd.uniform(-2.8, 2.8), c[1] + rnd.uniform(-2.8, 2.8))
            if not free(q, 0.2):
                continue
            ti = (rnd.uniform(-34, 34), rnd.uniform(-34, 34))
            d.cyl("flechas", arrow, q, 0.035, 0.035, 0.8, 0.0, 3, 0.0, ti, cap=False)
            tx, ty = math.radians(ti[0]), math.radians(ti[1])      # a pena acompanha a haste inclinada (o y0 do cyl não inclina)
            fq = (q[0] + 0.62 * math.cos(tx) * math.sin(ty), q[1] + 0.62 * math.sin(tx))
            d.cyl("flechas", feather, fq, 0.08, 0.03, 0.2, 0.62 * math.cos(tx) * math.cos(ty), 3, 0.0, ti)
        q = P(c, 1.4, rot)
        sh = d.m("resto_escudo_%d" % (int(rot) % 2), [(0.44, 0.2, 0.17), (0.34, 0.3, 0.27)][int(rot) % 2])
        d.cyl("resto", sh, q, 0.5, 0.5, 0.07, 0.03, 7, rot, tilt=(rnd.uniform(4, 14), 0))
        d.cyl("resto", d.m("ferro_velho", (0.42, 0.42, 0.45)), q, 0.14, 0.0, 0.16, 0.08, 4, rot)
        q = P(c, 1.9, rot + 150.0)
        stick("resto", wood, q, 0.04, 2.3, rot + 40.0, 0.05)
        d.cyl("resto", d.m("ferro_velho", (0.42, 0.42, 0.45)), P(q, 1.25, -(rot + 40.0)), 0.07, 0.0, 0.36, 0.05, 3, rot + 40.0, tilt=(0, 90))
        for k in range(2):
            q = P(c, rnd.uniform(1.6, 2.8), rot + 230.0 + k * 70.0)
            if free(q, 0.8):
                bones(q, rnd.randint(3, 4), 0.8, k == 0)
    elif kind == "tracks":                              # rastro: pegadas em duas fileiras numa curva longa, capim amassado
        dark = d.m("patch_pegada", tuple(k * 0.74 for k in look["tones"][1][1]))
        a = math.radians(rot)
        big = rnd.random() < 0.5
        step, r0 = (2.3, 0.5) if big else (1.3, 0.26)
        bend = rnd.uniform(-0.035, 0.035)
        q = Vector(c) - Vector((math.cos(a), math.sin(a))) * 11.0
        for k in range(int(22.0 / step)):
            a += bend * step
            fw = Vector((math.cos(a), math.sin(a)))
            q = q + fw * step
            s = 1 if k % 2 else -1
            f = q + Vector((-fw.y, fw.x)) * s * r0 * 1.5
            if not free((f.x, f.y), r0):
                continue
            d.blob("resto", dark, (f.x, f.y), r0, 0.0072, 0.12, 7, 1.5, -math.degrees(a))
            if big:                                     # três dedos na frente (pé de troll / pata de fera)
                for t in (-1, 0, 1):
                    toe = f + fw * r0 * 1.35 + Vector((-fw.y, fw.x)) * t * r0 * 0.6
                    d.blob("resto", dark, (toe.x, toe.y), r0 * 0.3, 0.0072, 0.1, 4)
        for _ in range(2):
            q2 = (c[0] + rnd.uniform(-3.0, 3.0), c[1] + rnd.uniform(-3.0, 3.0))
            if free(q2, 0.5):
                d.tuft("campo", grass, q2, 0.6, 0.5, 5, (0.5, 0.2))
    elif kind == "midden":                              # monturo de troll: ossada roída, costelas baixas, pedras e musgo
        d.blob("resto", d.m("patch_musgo_resto", (0.5, 0.52, 0.38)), c, 2.6, 0.0071, 0.35, 13)
        bones(c, 8, 1.7)
        bones(P(c, 1.4, rot + 200.0), 4, 0.9, False)
        a = math.radians(rot)
        ux, uz = math.cos(a), math.sin(a)
        for i in range(3):                              # costelas até 0,8 m
            t = (i - 1.0) * 0.6
            for s in (-1, 1):
                b0 = (c[0] + ux * t, c[1] + uz * t)
                d.tube("ossos", bone, [(b0[0] - uz * s * 0.1, 0.1, b0[1] + ux * s * 0.1), (b0[0] - uz * s * 0.7, 0.62, b0[1] + ux * s * 0.7),
                                       (b0[0] - uz * s * 0.45, 0.85, b0[1] + ux * s * 0.45)], 0.07, 0.025, 3)
        stick("ossos", bone, c, 0.08, 2.2, -rot, 0.09)
        for k in range(3):
            pebble(stone, P(c, rnd.uniform(1.6, 2.6), rot + 60.0 + k * 25.0), rnd.uniform(0.2, 0.36))
        pebble(d.m("carne", (0.66, 0.3, 0.26)), P(c, 0.9, rot + 300.0), 0.3)
    elif kind == "scorch":                              # chão queimado: mancha de carvão, brasas, flechas de fogo, toco em brasa
        d.blob("resto", d.m("patch_queimado", (0.2, 0.18, 0.18)), c, rnd.uniform(2.2, 3.2), 0.0074, 0.35, 14)
        ember = d.m("glow_brasa_chao", (1.0, 0.45, 0.14))
        arrow = d.m("flecha", (0.3, 0.24, 0.2))
        tipm = d.m("glow_flecha", (1.0, 0.5, 0.16))
        for _ in range(4):
            q = (c[0] + rnd.uniform(-2.0, 2.0), c[1] + rnd.uniform(-2.0, 2.0))
            d.blob("resto", ember, q, rnd.uniform(0.15, 0.36), 0.0079, 0.3, 5)
        for _ in range(rnd.randint(4, 6)):
            q = (c[0] + rnd.uniform(-3.0, 3.0), c[1] + rnd.uniform(-3.0, 3.0))
            if not free(q, 0.2):
                continue
            ti = (rnd.uniform(-30, 30), rnd.uniform(-30, 30))
            d.cyl("flechas", arrow, q, 0.04, 0.04, 1.0, 0.0, 3, 0.0, ti, cap=False)
            d.cyl("flechas", tipm, q, 0.09, 0.0, 0.22, 0.0, 3, 0.0, ti)
        d.cyl("resto", char, c, 0.3, 0.22, 0.45, 0.0, 5, rot, jitter=0.15)
        for k in range(3):
            pebble(char, P(c, rnd.uniform(1.0, 2.2), rot + 110.0 + k * 30.0), rnd.uniform(0.14, 0.26))
        stick("resto", char, P(c, 1.7, rot + 300.0), 0.13, 1.9, rot, 0.11, 4, True)
    elif kind == "wheel":                               # carga perdida: roda quebrada deitada, tábuas, sulcos de carroça
        rut = d.m("patch_sulco_resto", tuple(k * 0.78 for k in look["tones"][1][1]))
        a = math.radians(rot)
        fw = Vector((math.cos(a), math.sin(a)))
        nr = Vector((-fw.y, fw.x))
        for s in (-0.8, 0.8):
            pts = [Vector(c) + nr * s + fw * t for t in (-7.0, -3.5, 0.0, 3.5)]
            if all(free((q.x, q.y), 0.3) for q in pts):
                d.strip("resto", rut, pts, 0.24, 0.0072, 0.4, taper=True)
        q = P(c, 1.2, rot + 60.0)
        for k in range(8):                              # aro em gomos + raios, deitado
            a0 = math.tau * k / 8
            if k == 5:
                continue                                # gomo que falta
            m0 = (q[0] + math.cos(a0 + 0.39) * 0.62, q[1] + math.sin(a0 + 0.39) * 0.62)
            stick("resto", wood, m0, 0.07, 0.52, -math.degrees(a0 + 0.39) + 90.0, 0.07, 4)
            if k % 2 == 0:
                stick("resto", wood, (q[0] + math.cos(a0) * 0.3, q[1] + math.sin(a0) * 0.3), 0.04, 0.6, -math.degrees(a0), 0.07)
        d.cyl("resto", d.m("ferro_velho", (0.42, 0.42, 0.45)), q, 0.13, 0.1, 0.16, 0.0, 5)
        for k in range(3):
            pq = P(c, rnd.uniform(1.4, 2.6), rot + 180.0 + k * 55.0)
            if free(pq, 0.6):
                d.box("resto", wood, pq, (rnd.uniform(0.9, 1.5), 0.05, 0.22), rnd.uniform(0, 180), 0.02)
        q = P(c, 2.3, rot + 290.0)
        if free(q, 0.6):
            d.sack(q, 0.9)
    for _ in range(2):                                  # capim e seixos em volta: o resto não fica num chão pelado
        q = (c[0] + rnd.uniform(-4.5, 4.5), c[1] + rnd.uniform(-4.5, 4.5))
        if free(q, 0.5):
            d.tuft("campo", grass, q, 0.5, rnd.uniform(0.6, 1.0), 4, WIND)
    q = (c[0] + rnd.uniform(-3.5, 3.5), c[1] + rnd.uniform(-3.5, 3.5))
    if free(q, 0.6):
        for k in range(2):
            pebble(stone, (q[0] + rnd.uniform(-0.6, 0.6), q[1] + rnd.uniform(-0.6, 0.6)), rnd.uniform(0.14, 0.26))


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
    paint = list(floor_tones(d, "tambores", rooms["tambores"]["floor"]))     # tinta em tons do chão (não lê como aviso)
    for k, rr in enumerate((r * 0.36, r * 0.52, r * 0.7)):
        n = 8 + k * 4
        for j in range(n):
            a = math.tau * j / n
            d.arc("tambores", paint[(k + j) % 2], (x, y), rr, a + 0.04, a + math.tau / n - 0.04, 0.24, 0.0225, 0.25, 0.9)
    for j, (p, a) in enumerate(rim_spots("tambores", 12, 0.88, 0.95)):
        if not d.ok(p[0], p[1], 0.8, road=0.2):
            continue
        if j % 2:
            d.drum(p, rnd.uniform(0.7, 1.1))
            d.solid(p[0], p[1], 1.8, 1.8, 1.2)
        else:
            d.solid(p[0], p[1], 0.4, 0.4, 4.0)
            d.flag(p, [HORDE_RED, (0.86, 0.6, 0.2)][j % 4 // 2], 4.6, math.degrees(-a) + 90.0, w=0.9, drop=1.5)
    # ---- selo: círculo de runas e raios entalhados (tons do chão: brasa e vermelho no chão são do aviso de golpe),
    #      totens, crânios e braseiros na borda ----
    x, y = rooms["selo"]["pos"]
    r = rooms["selo"]["r"]
    rune, blood = floor_tones(d, "selo", rooms["selo"]["floor"])
    for rr, n, w in ((r * 0.34, 10, 0.22), (r * 0.56, 14, 0.26)):
        for j in range(n):
            a = math.tau * j / n
            d.arc("selo", rune, (x, y), rr, a + 0.05, a + math.tau / n - 0.05, w, 0.0232, 0.15, 0.8)
    for j in range(10):
        a = math.degrees(math.tau * j / 10 + 0.1)
        d.strip("selo", blood if j % 2 else rune, [Vector(P((x, y), r * 0.37, a)), Vector(P((x, y), r * 0.45, a + 3)), Vector(P((x, y), r * 0.53, a))],
                0.3 if j % 2 else 0.2, 0.0228, 0.2, taper=True)
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


# ----------------------------------------------------------------------------------------------------------------
# Monte Kharzun (field_kharzun, 40-45): basalto, cinza e lava. Chamado por build_kharzun.py antes do z.finish.
# Peças de estágio (K0-K4) saem em lotes com `tag` (MapDef.conquest_vis); o colisor delas é fixo e vem ANTES, por
# z.ob(..., visible=False): o que muda com a missão é só o que se vê em cima do mesmo chão.
# ----------------------------------------------------------------------------------------------------------------
KH_BASALT = (0.3, 0.28, 0.31)
KH_BASALT_TOP = (0.42, 0.4, 0.44)
KH_BASALT_DARK = (0.31, 0.29, 0.38)    # basalto dos Matadores (era 0.24/0.22/0.28: preto chapado na masmorra escura)
KH_LAVA = (1.0, 0.46, 0.14)
KH_CORE = (1.0, 0.8, 0.32)
KH_CRUST = (0.31, 0.27, 0.33)          # placa de crosta na lava: ardósia (era 0.2/0.15/0.14 chapado: lia como buraco; art review 2026-11-13, item 9)
KH_CRUST_TOP = (0.45, 0.4, 0.46)
KH_COAL = (0.27, 0.25, 0.32)           # carvão/escória do monte: o mais escuro que ainda mostra os 3 tons do toon
KH_NIGHT = (0.3, 0.2, 0.4)             # pano dos Matadores


def basalt_columns(d, c, n=6, r=1.6, h=(1.2, 3.4), color=KH_BASALT, g="basalto"):
    """Feixe de colunas hexagonais de basalto (mais altas no meio), tampo mais claro: lê-se de cima como favo escuro."""
    rk = d.m("basalto_%d" % int(color[0] * 100), color)
    tp = d.m("basalto_topo_%d" % int(color[0] * 100), tuple(min(1.0, k * 1.35) for k in color))
    rnd = d.rnd
    for i in range(n):
        a, dd = rnd.uniform(0, math.tau), (0.0 if i == 0 else rnd.uniform(0.3, r))
        p = (c[0] + math.cos(a) * dd, c[1] + math.sin(a) * dd)
        hh = rnd.uniform(*h) * (1.0 - 0.55 * dd / max(r, 0.1))
        rr = rnd.uniform(0.45, 0.72)
        rot = rnd.uniform(0, 60)
        d.cyl(g, rk, p, rr, rr, hh, -0.1, 6, rot)
        d.cyl(g, tp, p, rr * 0.96, rr * 0.9, 0.07, hh - 0.1, 6, rot)


def lava_detail(d, w, lakes):
    """Vida da lava: miolo claro que serpenteia, placas de crosta boiando, rachaduras em brasa saindo das margens,
    chão chamuscado. Tudo chato (não colide: quem fecha a lava é o rio/lago da sim)."""
    z = d.z
    rnd = d.rnd
    crust = d.m("lava_placa", KH_CRUST)                      # placa com volume (Dress.slab): borda em talude + tampo claro
    crust_top = d.m("lava_placa_topo", KH_CRUST_TOP)
    core = d.m("glow_lava_miolo", KH_CORE)
    crack = d.m("glow_lava", KH_LAVA)
    burnt = d.m("patch_chamuscado", (0.24, 0.2, 0.2))
    roads = [poly for name, poly in z.road_polys.items() if not name.startswith("trilha_")]
    far = lambda p, m: all(zone_lib.poly_dist(p, rd) > m for rd in roads)

    def cracks(p, out, n=1):
        for _ in range(n):
            a = math.atan2(out.y, out.x) + rnd.uniform(-0.7, 0.7)
            L = rnd.uniform(2.5, 6.5)
            pts = [p]
            for k in range(1, 5):
                a += rnd.uniform(-0.45, 0.45)
                pts.append(pts[-1] + Vector((math.cos(a), math.sin(a))) * L / 4)
            if far(pts[-1], 4.0) and far(pts[2], 4.0):
                d.strip("lava", crack, pts, rnd.uniform(0.22, 0.4), 0.0112, 0.3, taper=True)
                if rnd.random() < 0.5:
                    d.blob("lava", burnt, (pts[2].x, pts[2].y), rnd.uniform(1.2, 2.4), 0.0076, 0.35)

    heat = d.m("patch_lava_calor", (0.52, 0.25, 0.2))
    for k, poly in enumerate(z.rivers):
        n = len(poly)
        d.strip("lava", heat, poly, w + 9.0, 0.0071, 0.5)
        nrm = []
        for i in range(n):
            t = (poly[min(n - 1, i + 1)] - poly[max(0, i - 1)]).normalized()
            nrm.append((t, Vector((-t.y, t.x))))
        i = 1
        while i < n - 4:                                     # miolo claro em trechos, serpenteando
            m = rnd.randint(6, 12)
            pts = [poly[j] + nrm[j][1] * math.sin(j * 0.55 + k) * w * 0.2 for j in range(i, min(n - 1, i + m))]
            d.strip("lava", core, pts, w * rnd.uniform(0.16, 0.26), 0.0206, 0.5, taper=True)
            i += m + rnd.randint(1, 3)
        for i in range(1, n - 1):
            t, nr = nrm[i]
            if far(poly[i], w * 0.5 + 3.5):
                for _ in range(1):
                    if rnd.random() < 0.45:
                        q = poly[i] + nr * rnd.uniform(-w * 0.38, w * 0.38) + t * rnd.uniform(-0.8, 0.8)
                        d.slab("mini", crust, crust_top, (q.x, q.y), rnd.uniform(0.4, 0.95), 0.14, 0.3, sx=rnd.uniform(1.0, 2.2), rot=zone_lib.along(t.x, t.y), y=0.012)
            if i % 2 == 0 and far(poly[i], w * 0.5 + 5.0):
                s = 1 if rnd.random() < 0.5 else -1
                cracks(poly[i] + nr * s * (w * 0.5 - 0.3), nr * s, 1)
    for c, r in lakes:
        d.blob("lava", heat, c, r + 6.5, 0.0071, 0.2)
        d.blob("lava", core, c, r * 0.5, 0.0256, 0.3)
        for _ in range(int(r * 0.9)):
            a, rr = rnd.uniform(0, math.tau), r * rnd.uniform(0.3, 0.9)
            d.slab("mini", crust, crust_top, (c[0] + math.cos(a) * rr, c[1] + math.sin(a) * rr), rnd.uniform(0.5, 1.4), 0.16, 0.3, sx=rnd.uniform(1.0, 2.0), rot=math.degrees(-a) + 90.0, y=0.012)
        for i in range(int(r * 1.2)):
            a = math.tau * i / int(r * 1.2) + rnd.uniform(-0.2, 0.2)
            o = Vector((math.cos(a), math.sin(a)))
            cracks(Vector(c) + o * (r - 0.3), o, 1)


def _watchtower(d, c, h=6.4, roof=AURORA_BLUE, g="torre"):
    w = d.m("torre_aurora", (0.62, 0.48, 0.32))
    w2 = d.m("torre_aurora_tabua", (0.74, 0.6, 0.4))
    for dx in (-1.3, 1.3):
        for dz in (-1.3, 1.3):
            d.cyl(g, w, (c[0] + dx, c[1] + dz), 0.2, 0.18, h, 0.0, 6)
    d.box(g, w2, c, (3.5, 0.25, 3.5), 0.0, h)
    for k in range(4):
        q = P(c, 1.7, k * 90.0)
        d.box(g, w, q, (0.14, 0.9, 3.5), k * 90.0, h + 0.25)
    for dx in (-1.3, 1.3):
        for dz in (-1.3, 1.3):
            d.cyl(g, w, (c[0] + dx, c[1] + dz), 0.12, 0.12, 2.0, h + 0.25, 5)
    d.cyl(g, d.m("torre_teto_%d" % int(roof[2] * 100), roof), c, 2.7, 0.1, 1.8, h + 2.25, 4, 45.0)
    d.cyl(g, d.m("lona_ouro_96", AURORA_GOLD), c, 0.16, 0.0, 0.5, h + 4.05, 4)
    for k, yy in enumerate((1.6, 3.6)):                      # travas em X (lado da frente)
        d.tube(g, w, [(c[0] - 1.3, yy - 1.2, c[1] + 1.3), (c[0] + 1.3, yy + 1.2, c[1] + 1.3)], 0.06, 0.06, 4)
        d.tube(g, w, [(c[0] + 1.3, yy - 1.2, c[1] + 1.3), (c[0] - 1.3, yy + 1.2, c[1] + 1.3)], 0.06, 0.06, 4)


def _catapult(d, c, rot, g="cerco"):
    """Catapulta da Aurora: chassi de toras com quatro rodas, cavalete, braço armado com a colher, contrapeso azul."""
    w = d.m("cerco_madeira", (0.56, 0.42, 0.28))
    iron = d.m("ferro", (0.6, 0.62, 0.66))
    a = math.radians(rot)
    ux, uz = math.cos(a), -math.sin(a)
    vx, vz = math.sin(a), math.cos(a)
    for s in (-1, 1):
        d.log(g, w, (c[0] + vx * s * 1.0, c[1] + vz * s * 1.0), 0.2, 4.0, rot, 0.6)
        for e in (-1, 1):
            p = (c[0] + ux * e * 1.4 + vx * s * 1.35, c[1] + uz * e * 1.4 + vz * s * 1.35)
            d.cyl(g, d.m("carreta_roda", (0.26, 0.2, 0.16)), p, 0.6, 0.6, 0.16, 0.6, 8, rot, tilt=(90, 0))
        d.tube(g, w, [(c[0] + vx * s * 1.0 - ux * 0.9, 0.7, c[1] + vz * s * 1.0 - uz * 0.9), (c[0] + vx * s * 0.6, 3.2, c[1] + vz * s * 0.6)], 0.14, 0.12, 5)
        d.tube(g, w, [(c[0] + vx * s * 1.0 + ux * 0.9, 0.7, c[1] + vz * s * 1.0 + uz * 0.9), (c[0] + vx * s * 0.6, 3.2, c[1] + vz * s * 0.6)], 0.14, 0.12, 5)
    d.tube(g, w, [(c[0] - vx * 0.7, 3.2, c[1] - vz * 0.7), (c[0] + vx * 0.7, 3.2, c[1] + vz * 0.7)], 0.13, 0.13, 5)
    d.tube(g, w, [(c[0] + ux * 1.2, 4.2, c[1] + uz * 1.2), (c[0], 3.2, c[1]), (c[0] - ux * 2.6, 1.3, c[1] - uz * 2.6)], 0.15, 0.1, 5)
    d.cyl(g, iron, (c[0] - ux * 2.7, c[1] - uz * 2.7), 0.2, 0.42, 0.3, 1.1, 7)
    d.box(g, d.m("cerco_contrapeso", AURORA_BLUE), (c[0] + ux * 1.3, c[1] + uz * 1.3), (0.9, 1.0, 0.9), rot, 3.5)
    d.rock(g, d.m("cerco_pedra", (0.5, 0.48, 0.5)), (c[0] - ux * 2.7, c[1] - uz * 2.7), 0.3, 1.3, 0.9)


def _ram(d, c, rot, g="cerco"):
    """Aríete coberto: telhado de duas águas com couro azul, tora de cabeça de ferro pendurada, quatro rodas."""
    w = d.m("cerco_madeira", (0.56, 0.42, 0.28))
    a = math.radians(rot)
    ux, uz = math.cos(a), -math.sin(a)
    vx, vz = math.sin(a), math.cos(a)
    for s in (-1, 1):
        for e in (-1, 1):
            p = (c[0] + ux * e * 2.0 + vx * s * 0.95, c[1] + uz * e * 2.0 + vz * s * 0.95)
            d.cyl(g, w, p, 0.12, 0.11, 2.2, 0.0, 5)
            d.cyl(g, d.m("carreta_roda", (0.26, 0.2, 0.16)), (p[0] + vx * s * 0.2, p[1] + vz * s * 0.2), 0.55, 0.55, 0.14, 0.55, 8, rot, tilt=(90, 0))
        d.box(g, d.m("cerco_couro", AURORA_BLUE), (c[0] + vx * s * 0.55, c[1] + vz * s * 0.55), (5.0, 0.1, 1.5), rot, 2.5, tilt=(-s * 32.0, 0))
    d.log(g, w, c, 0.1, 5.0, rot, 3.0)
    d.log(g, d.m("cerco_tora", (0.44, 0.32, 0.22)), (c[0] + ux * 0.5, c[1] + uz * 0.5), 0.3, 5.6, rot, 1.2)
    d.cyl(g, d.m("ferro", (0.6, 0.62, 0.66)), (c[0] + ux * 3.3, c[1] + uz * 3.3), 0.36, 0.2, 0.7, 1.2, 6, rot, tilt=(0, 90))


def _cage(d, c, rot, open_door=False, g="jaula"):
    """Jaula de ferro (2,6 m): quatro cantos, tampo, grades; aberta = a frente no chão."""
    iron = d.m("jaula_ferro", (0.28, 0.27, 0.3))
    S, Hh = 1.3, 2.4
    a = math.radians(rot)
    ux, uz = math.cos(a), -math.sin(a)
    vx, vz = math.sin(a), math.cos(a)
    for s in (-1, 1):
        for e in (-1, 1):
            d.cyl(g, iron, (c[0] + ux * e * S + vx * s * S, c[1] + uz * e * S + vz * s * S), 0.1, 0.1, Hh, 0.0, 4)
    d.box(g, iron, c, (2 * S + 0.2, 0.12, 2 * S + 0.2), rot, Hh)
    d.box(g, d.m("jaula_chao", (0.36, 0.3, 0.26)), c, (2 * S, 0.08, 2 * S), rot, 0.0)
    for side in range(4):
        if open_door and side == 0:
            continue
        for k in (-0.6, -0.2, 0.2, 0.6):
            if side == 0:
                p = (c[0] + ux * k * 2 * S * 0.5 * 1.6 + vx * S, c[1] + uz * k * 2 * S * 0.5 * 1.6 + vz * S)
            elif side == 1:
                p = (c[0] + ux * k * 2 * S * 0.5 * 1.6 - vx * S, c[1] + uz * k * 2 * S * 0.5 * 1.6 - vz * S)
            elif side == 2:
                p = (c[0] + ux * S + vx * k * 2 * S * 0.5 * 1.6, c[1] + uz * S + vz * k * 2 * S * 0.5 * 1.6)
            else:
                p = (c[0] - ux * S + vx * k * 2 * S * 0.5 * 1.6, c[1] - uz * S + vz * k * 2 * S * 0.5 * 1.6)
            d.cyl(g, iron, p, 0.045, 0.045, Hh, 0.0, 4)
    if open_door:
        q = (c[0] + vx * (S + 1.5), c[1] + vz * (S + 1.5))
        d.box(g, iron, q, (2 * S, 0.08, 2.2), rot, 0.02)
        d.box(g, d.m("jaula_corrente", (0.5, 0.5, 0.54)), (q[0] + ux * 0.6, q[1] + uz * 0.6), (0.9, 0.06, 0.14), rot + 30.0, 0.1)


def kharzun(z, k):
    q_ = k["q"]
    d = Dress(z, 409)
    rnd = d.rnd
    hub_r = k["hub_r"]
    lots = []                  # (tag, when, função) desenhados no fim, cada um no seu lote de estágio

    # ---- colisores fixos das peças de estágio (antes de tudo: o d.ok() já os vê) ----
    towers = [P((0, 0), hub_r + 3.2, deg) for deg in (-90.0 - 21.0, -90.0 + 21.0, -21.0, 21.0)]
    for q in towers:
        z.ob("pillar", q[0], q[1], (3.4, 6.0, 3.4), visible=False)
    dwarf = P((0, 0), 20.0, -73.0)
    z.ob("pillar", dwarf[0], dwarf[1], (3.2, 2.4, 2.6), visible=False)
    sg = k["siege"]
    siege = [((sg[0] + 5.2, sg[1] - 1.5), 20.0, (4.4, 2.0, 3.4)), ((sg[0] - 5.2, sg[1] - 2.0), -30.0, (4.4, 2.0, 3.4)), ((sg[0] + 0.5, sg[1] + 5.6), 0.0, (6.0, 2.0, 2.6))]
    for c, rot, size in siege:
        z.ob("wall", c[0], c[1], size, rot, visible=False)
    mc = k["mines"]
    cages = [((mc[0] - 3.0, mc[1] - 12.8), 0.0), ((mc[0] + 2.8, mc[1] - 13.8), 0.0), ((mc[0] - 8.0, mc[1] + 12.8), 180.0)]
    for c, rot in cages:
        z.ob("wall", c[0], c[1], (2.9, 2.4, 2.9), rot, visible=False)
    fr = k["freed"]
    freed_tents = [P(fr, 11.5, deg) for deg in (20.0, 95.0, 160.0)]
    for q in freed_tents:
        z.ob("pillar", q[0], q[1], (3.2, 2.6, 3.2), visible=False)

    # ---- chão: basalto, cinza e ferrugem; riscos de cinza soprada; acostamento e sulcos ----
    dry_ground(d, [("kh_basalto", (0.29, 0.25, 0.28)), ("kh_cinza", (0.5, 0.44, 0.42)), ("kh_ferrugem", (0.5, 0.33, 0.28))], 170, streaks=90,
               streak_col=(0.6, 0.56, 0.54), ruts=(0.46, 0.42, 0.4), edge=(0.52, 0.47, 0.44), streak_soft=True,
               # manchas a 3,0/3,8/4,6 mm e risco a 6,4 mm: os três tons ficavam a 0,2 mm um do outro (4,8/5,0/5,2) e o risco a
               # 0,2 mm do chão dos lugares (6,0): faixas listradas no Santuário dos Anões (art review 2026-11-13, item 13)
               mottle_y=0.0030, mottle_step=0.0008, streak_y=0.0064)
    d.roadside(d.m("seixo_basalto", (0.26, 0.25, 0.28)), d.m("capim_cinza", (0.52, 0.42, 0.34)), every=6.0, tuft_h=0.7)
    lava_detail(d, k["lava_w"], k["lakes"])

    # ---- pontes de basalto: quatro pilones com runa de brasa em cada uma ----
    for b in z.data.get("bridges", []):
        a = math.radians(b["rot"])
        t = Vector((math.cos(a), -math.sin(a)))
        nr = Vector((-t.y, t.x))
        for s in (-1, 1):
            for e in (-1, 1):
                p = Vector(b["pos"]) + t * e * (b["len"] * 0.5 - 0.4) + nr * s * (b["w"] * 0.5 + 0.75)
                d.cyl("ponte", d.m("basalto_30", KH_BASALT), (p.x, p.y), 0.62, 0.5, 2.5, 0.0, 6)
                d.cyl("ponte", d.m("basalto_topo_30", KH_BASALT_TOP), (p.x, p.y), 0.66, 0.66, 0.2, 2.5, 6)
                d.cyl("ponte", d.m("glow_lava", KH_LAVA), (p.x, p.y), 0.34, 0.0, 0.7, 2.7, 5)
                d.solid(p.x, p.y, 1.1, 1.1, 2.6)

    # ---- hub: tapetes, tendas da Aurora, treino, carga, tochas, flâmulas nas carroças ----
    for o in list(z.data["obstacles"]):
        if math.hypot(*o["pos"]) > hub_r or not o.get("visible", True):
            continue
        if o["kind"] == "stall":
            d.rug(o["pos"], 4.2, 3.0, o["rot"], (0.74, 0.3, 0.26), (0.94, 0.84, 0.6))
        elif o["kind"] == "tent":
            ang = math.atan2(o["pos"][1], o["pos"][0])
            q = (o["pos"][0] - math.cos(ang) * 2.9, o["pos"][1] - math.sin(ang) * 2.9)
            d.rug(q, 2.6, 1.8, math.degrees(-ang) + 90.0, (0.3, 0.44, 0.7), (0.94, 0.86, 0.66))
    for kk in range(12):
        d.blob("hub", d.m("patch_hub_pedra", (0.46, 0.43, 0.42)), P((0, 0), 4.3, kk * 30.0 + 15.0), 0.4, 0.0185, 0.2, 7)
    n = 0
    for deg in (-22.0, -163.0, 73.0, 110.0, -112.0, 24.0, 150.0):
        q = P((0, 0), 21.0, deg)
        if n < 4 and d.ok(q[0], q[1], 2.0, road=0.5):
            d.tent_aurora(q, 90.0 - deg, 1.05)
            d.solid(q[0], q[1], 3.3, 3.3, 2.6)
            d.rug(P((0, 0), 18.0, deg), 2.4, 1.6, -deg + 90.0, (0.3, 0.44, 0.7), (0.94, 0.86, 0.66))
            n += 1
    for deg in (199.0, 208.0, 217.0):                        # bonecos de treino da Aurora (lado oeste)
        q = P((0, 0), 19.5, deg)
        if d.ok(q[0], q[1], 0.7, road=0.5):
            d.drill_post(q, -deg, shield=AURORA_BLUE, boss=AURORA_GOLD, crest=AURORA_GOLD)
            d.solid(q[0], q[1], 0.9, 0.9, 1.8)
    for deg in (-62.0, -118.0):
        q = P((0, 0), 22.0, deg)
        if d.ok(q[0], q[1], 1.2, road=0.5):
            d.weapon_rack(q, -deg + 90.0)
            d.solid(q[0], q[1], 2.4, 0.8, 1.6, -deg + 90.0)
    for deg, cnt in ((14.0, 5), (46.0, 4), (136.0, 5), (-30.0, 4), (-146.0, 4), (66.0, 3)):
        q = P((0, 0), 21.5, deg)
        if d.ok(q[0], q[1], 1.3, road=0.6):
            d.cargo(q, cnt, 1.2)
            d.solid(q[0], q[1], 2.4, 2.4, 1.3)
    q = P((0, 0), 10.5, 122.0)
    if d.ok(q[0], q[1], 1.2, road=0.4):
        d.cookfire(q, 1.0, 30.0)
        d.solid(q[0], q[1], 1.6, 1.6, 1.2)
    for i in range(0, 360, 15):                              # tochas por dentro das estacas (arco norte)
        if math.sin(math.radians(i)) > 0.3 or any(zone_lib.angdiff(math.radians(i), math.radians(g)) * hub_r < k["gate_half"] + 1.5 for g in k["gates"]):
            continue
        d.torch(P((0, 0), hub_r - 1.5, float(i)), 2.4)
    nw = int(math.tau * hub_r / 6.4)
    for i in range(nw):                                      # flâmulas nas carroças do arco sul
        am = math.tau * (i + 0.5) / nw
        if math.sin(am) < 0.4 or i % 2 or any(zone_lib.angdiff(am, math.radians(g)) * hub_r < k["gate_half"] + 3.4 for g in k["gates"]):
            continue
        q = (math.cos(am) * (hub_r + 1.7), math.sin(am) * (hub_r + 1.7))
        d.flag(q, [AURORA_BLUE, AURORA_GOLD, (0.86, 0.5, 0.26)][(i // 2) % 3], 5.6, math.degrees(-am), (0.5, 0.38, 0.26), w=1.0, drop=1.5)
    for s in (-1, 1):                                        # cavalos de frisa por fora dos vãos norte e leste
        for g in (-90.0, 0.0):
            q = P((0, 0), hub_r + 7.0, g + s * 17.0)
            if d.ok(q[0], q[1], 2.0, road=1.0):
                d.spikes(q, -g + 90.0, 3.8, color=(0.56, 0.44, 0.3))
                d.solid(q[0], q[1], 3.8, 1.0, 1.2, -g + 90.0)

    # K0 -> K1: obra vira torre; lote vazio vira a forja anã
    def k0(dd):
        for q in towers:
            dd.woodpile(q, rnd.uniform(0, 180), 3, 2.6)
            for kk in range(2):
                dd.cyl("obra", dd.m("torre_aurora", (0.62, 0.48, 0.32)), (q[0] - 1.2 + kk * 2.4, q[1] + 1.2), 0.2, 0.18, 2.2 + kk * 1.2, 0.0, 6)
        dd.cargo(dwarf, 4, 1.0, "obra")
        for q in freed_tents:                                # posto dos libertos antes de K1: casebres anões caídos
            dd.outcrop(q, 1.7, 4, (0.5, 0.48, 0.5), g="obra", hmul=0.7)

    def k1_towers(dd):
        for q in towers:
            _watchtower(dd, q)

    def k1_dwarves(dd):
        st = dd.m("anao_pedra", (0.56, 0.56, 0.6))
        ang = math.degrees(math.atan2(dwarf[1], dwarf[0]))
        rot = -ang + 90.0
        dd.box("anoes", st, dwarf, (2.6, 1.7, 1.9), rot, 0.0)
        dd.box("anoes", dd.m("glow_brasa", (1.0, 0.56, 0.2)), P(dwarf, 0.9, ang + 180.0), (1.2, 0.7, 0.2), rot, 0.35)
        dd.cyl("anoes", st, P(dwarf, 0.5, ang), 0.5, 0.4, 2.0, 1.7, 6)
        dd.cyl("anoes", dd.m("glow_brasa", (1.0, 0.56, 0.2)), P(dwarf, 0.5, ang), 0.3, 0.0, 0.7, 3.7, 5)
        a2 = P(dwarf, 2.6, ang + 150.0)
        dd.box("anoes", dd.m("ferro", (0.6, 0.62, 0.66)), a2, (0.9, 0.3, 0.4), rot + 20.0, 0.6)
        dd.cyl("anoes", dd.m("cavalete", (0.4, 0.3, 0.22)), a2, 0.3, 0.26, 0.6, 0.0, 6)
        dd.flag(P(dwarf, 2.4, ang - 60.0), (0.5, 0.56, 0.7), 4.4, rot, (0.4, 0.4, 0.44), tatter=False, w=1.0, drop=1.6)

    def k1_freed(dd):
        for i, q in enumerate(freed_tents):
            ang = math.degrees(math.atan2(q[1] - fr[1], q[0] - fr[0]))
            dd.tent_aurora(q, 90.0 - ang, 0.95, color=(0.84, 0.8, 0.72), trim=(0.44, 0.5, 0.62))
        dd.cookfire(P(fr, 8.0, 60.0), 0.9, 20.0)
        dd.cargo(P(fr, 9.5, 130.0), 4, 1.1)
        dd.laundry(P(fr, 13.5, 35.0), P(fr, 13.5, 75.0), 2.4)

    lots += [("k0_obra", {"unless": q_["mines"]}, k0), ("k1_torre", {"if": q_["mines"]}, k1_towers), ("k1_anoes", {"if": q_["mines"]}, k1_dwarves),
             ("k1_libertos", {"if": q_["mines"]}, k1_freed)]

    # K2: madeira empilhada vira máquinas de cerco
    def k2_wood(dd):
        for c, rot, size in siege:
            dd.woodpile(c, rot, 3, 3.4)
            dd.blob("obra", dd.m("patch_serragem", (0.66, 0.56, 0.42)), c, 2.6, 0.0075, 0.3)

    def k2_siege(dd):
        _catapult(dd, siege[0][0], siege[0][1])
        _catapult(dd, siege[1][0], siege[1][1])
        _ram(dd, siege[2][0], siege[2][1])
        for s in (-1, 1):
            dd.flag((sg[0] + s * 8.5, sg[1] + 3.0), AURORA_GOLD, 5.4, 90.0, (0.82, 0.68, 0.48), tatter=False)

    lots += [("k2_madeira", {"unless": q_["gate"]}, k2_wood), ("k2_cerco", {"if": q_["gate"]}, k2_siege)]

    # K4: festa (varais de bandeirolas em volta do braseiro, tapetes, barris)
    def k4(dd):
        fest = ((0.96, 0.9, 0.62), (0.36, 0.48, 0.78), (0.9, 0.5, 0.4), (0.96, 0.96, 0.92))
        for i in range(4):
            dd.laundry(P((0, 0), 11.0, 45.0 + i * 90.0), P((0, 0), 11.0, 135.0 + i * 90.0), 3.6, cols=fest)
        for deg in (60.0, 120.0, 240.0, 300.0):
            dd.rug(P((0, 0), 8.6, deg), 2.6, 1.6, -deg + 90.0, (0.82, 0.3, 0.26), (0.96, 0.9, 0.62))
            dd.barrel(P((0, 0), 10.2, deg + 8.0), 1.0, 0.0, "festa")

    lots.append(("k4_festa", {"if": q_["warlord"]}, k4))

    # ---- Minas de Escravos: trilhos, vagonetes, minério, picaretas, tenda dos capatazes, frisas ----
    mouth = k["mouth"]
    rail = zone_lib.catmull([(mouth[0] + 1.4, mouth[1]), (mc[0] - 9.0, mc[1] - 2.5), (mc[0] - 4.0, mc[1] - 5.5), (mc[0] - 1.0, mc[1] - 8.0)], 1.5)
    d.rails([(p.x, p.y) for p in rail])
    for i, t in enumerate((0.3, 0.72)):
        p = rail[int(len(rail) * t)]
        nx = rail[min(len(rail) - 1, int(len(rail) * t) + 1)]
        d.ore_cart((p.x, p.y), zone_lib.along((nx - p).x, (nx - p).y), full=i == 0)
    for q in ((mc[0] + 2.5, mc[1] - 8.5), (mc[0] - 12.0, mc[1] + 5.5), (mc[0] - 6.5, mc[1] - 9.0)):
        if d.ok(q[0], q[1], 1.0, road=0.5):
            d.ore_pile(q, 6)
            d.solid(q[0], q[1], 1.9, 1.9, 1.0)
            d.pickaxe((q[0] + 1.3, q[1] + 0.4), rnd.uniform(0, 360))
    for q, deg in (((mc[0] + 8.5, mc[1] + 12.5), 230.0), ((mc[0] + 3.0, mc[1] + 14.5), 260.0)):
        if d.ok(q[0], q[1], 2.0, road=0.8):
            d.tent_hide(q, 90.0 - deg, 1.05)
            d.solid(q[0], q[1], 3.2, 3.2, 2.4)
    for q, rot in (((mc[0] + 14.5, mc[1] + 4.0), 80.0), ((mc[0] + 14.0, mc[1] - 9.0), 100.0)):
        if d.ok(q[0], q[1], 2.0, road=1.0):
            d.spikes(q, rot, 3.6)
            d.solid(q[0], q[1], 1.0, 3.6, 1.2, rot + 90.0)
    for q in ((mc[0] + 4.5, mc[1] - 16.0), (mc[0] - 14.0, mc[1] + 13.0)):
        if d.ok(q[0], q[1], 0.7, road=0.6):
            d.totem(q, rnd.uniform(3.8, 4.6), rnd.uniform(0, 180))
            d.solid(q[0], q[1], 0.9, 0.9, 4.0)

    def cages_closed(dd):
        for c, rot in cages:
            _cage(dd, c, rot, False)

    def cages_open(dd):
        for c, rot in cages:
            _cage(dd, c, rot, True)

    lots += [("k1_jaula_fechada", {"unless": q_["mines"]}, cages_closed), ("k1_jaula_aberta", {"if": q_["mines"]}, cages_open)]

    # ---- Canil: dois currais, ninhos com ovos, ossadas, cocho ----
    kc, kr = k["kennel"], k["kennel_r"]
    straw = d.m("patch_palha", (0.7, 0.58, 0.34))
    egg = d.m("ovo_lobo", (0.86, 0.84, 0.78))
    for deg in (-135.0, 135.0):
        pc = P(kc, 8.0, deg)
        cs = [(pc[0] + sx * 3.0, pc[1] + sz * 3.0) for sx, sz in ((-1, -1), (1, -1), (1, 1), (-1, 1))]
        for i in range(4):
            a, b = cs[i], cs[(i + 1) % 4]
            if i == (1 if deg < 0 else 0):
                continue                                     # lado aberto virado para o meio
            d.fence_run(a, b, 1.5, color=(0.3, 0.24, 0.2), gap=1.2)
            m = ((a[0] + b[0]) * 0.5, (a[1] + b[1]) * 0.5)
            z.ob("wall", m[0], m[1], (6.2, 1.5, 0.5), zone_lib.along(b[0] - a[0], b[1] - a[1]), visible=False)      # caixa fina (d.solid vira círculo)
            d.reserve(m[0], m[1], 3.2)
        d.blob("canil", straw, pc, 2.2, 0.0078, 0.3)
        d.bones((pc[0] + 0.8, pc[1] - 0.6), 4, 1.3)
    for q in (P(kc, 8.5, -42.0), P(kc, 10.5, 62.0), P(kc, 5.5, -70.0)):       # ninhos
        d.blob("canil", straw, q, 1.5, 0.0078, 0.3)
        for kk in range(3):
            d.rock("mini", egg, P(q, 0.5, kk * 120.0 + 20.0), 0.26, 0.0, 1.1)
    d.log("canil", d.m("cocho", (0.34, 0.26, 0.2)), P(kc, 4.6, 160.0), 0.34, 3.0, 20.0, 0.34)
    for _ in range(10):
        q = P(kc, rnd.uniform(kr + 2.0, kr + 12.0), rnd.uniform(0, 360))
        if d.ok(q[0], q[1], 1.0, road=0.5):
            d.bones(q, rnd.randint(3, 6), 1.3)

    # ---- Forja Negra: calha de lava da poça à fornalha, carvão, escória, cavaletes de armas ----
    fc, frr = k["forge"], k["forge_r"]
    gutter = d.m("patch_calha", (0.14, 0.13, 0.15))
    lv = d.m("glow_lava", KH_LAVA)
    pool = Vector((fc[0] - 7.5, fc[1] - 6.5))
    ch = zone_lib.catmull([(pool.x + 2.6, pool.y - 0.6), (fc[0] - 3.0, fc[1] - 8.8), (fc[0] - 0.9, fc[1] - 8.2)], 0.9)
    d.strip("forja", gutter, ch, 1.0, 0.0205)
    d.strip("forja", lv, ch, 0.42, 0.0215)
    coal = d.m("carvao_kh", KH_COAL)
    for q in (P(fc, 9.5, 75.0), P(fc, 10.0, 118.0), P(fc, 9.5, -20.0)):
        if d.ok(q[0], q[1], 1.2, road=0.6):
            for kk in range(6):
                d.rock("forja3d", coal, P(q, rnd.uniform(0, 1.0), kk * 60.0), rnd.uniform(0.3, 0.6), 0.0, 0.8)
            d.blob("forja", d.m("glow_brasa_chao", (1.0, 0.45, 0.14)), q, 0.35, 0.3, 0.3, 7)
            d.solid(q[0], q[1], 2.0, 2.0, 1.0)
    for q, rot in ((P(fc, 9.0, 150.0), 60.0), (P(fc, 6.5, 95.0), 0.0)):
        if d.ok(q[0], q[1], 1.2, road=0.6):
            d.weapon_rack(q, rot)
            d.solid(q[0], q[1], 2.4, 0.8, 1.6, rot)
    for _ in range(9):                                       # escória fora do anel
        q = P(fc, rnd.uniform(frr + 2.5, frr + 12.0), rnd.uniform(0, 360))
        if d.ok(q[0], q[1], 1.6, road=1.0):
            d.outcrop(q, rnd.uniform(1.0, 1.6), 3, (0.3, 0.28, 0.34), (0.44, 0.4, 0.45), hmul=0.7)      # escória: ardósia (era quase preta)
            d.blob("forja", d.m("glow_brasa_chao", (1.0, 0.45, 0.14)), q, 0.3, 0.012, 0.3, 7)
            d.solid(q[0], q[1], 2.0, 2.0, 1.0)

    # ---- Portão da Cidadela: braseiros de lava, frisas, totens de caveira ----
    bc = k["barbican"]
    for s in (-1, 1):
        q = (bc[0] + s * 4.9, bc[1] + 4.6)
        d.brazier(q, 1.3, fire="glow_lava", color=KH_LAVA)
        d.solid(q[0], q[1], 1.2, 1.2, 1.4)
        for q, rot in (((bc[0] + s * 8.5, bc[1] + 12.0), s * 25.0), ((bc[0] + s * 7.5, bc[1] + 19.0), -s * 20.0)):
            if d.ok(q[0], q[1], 2.0, road=1.0):
                d.spikes(q, rot, 3.8)
                d.solid(q[0], q[1], 3.8, 1.0, 1.2, rot)
        q = (bc[0] + s * 11.5, bc[1] + 15.5)
        if d.ok(q[0], q[1], 0.7, road=0.8):
            d.totem(q, 4.8, 90.0)
            d.solid(q[0], q[1], 0.9, 0.9, 4.0)
    for kk in range(8):                                      # colunas de basalto ao pé da Presa
        q = P(k["fang"], 14.0, kk * 45.0 + 10.0)
        if d.ok(q[0], q[1], 1.8, road=1.5):
            basalt_columns(d, q, 5, 1.3, (1.6, 4.0))
            d.solid(q[0], q[1], 2.8, 2.8, 2.5)

    # ---- Salão dos Matadores: panos escuros na trilha, bonecos de treino esfaqueados ----
    sl = k["slayers"]
    for kk, (dx, dz) in enumerate(((5.0, -4.0), (-4.0, 5.0), (9.0, 1.0), (1.0, 9.0))):
        q = (sl[0] + dx, sl[1] + dz)
        if d.ok(q[0], q[1], 0.6, road=0.5):
            d.flag(q, KH_NIGHT, 5.2, 45.0 + kk * 90.0, (0.2, 0.18, 0.22), w=1.1, drop=2.2)
            d.solid(q[0], q[1], 0.6, 0.6, 4.0)
    for kk, (dx, dz) in enumerate(((12.0, -6.0), (14.5, -3.0), (-6.0, 12.0))):
        q = (sl[0] + dx, sl[1] + dz)
        if d.ok(q[0], q[1], 0.8, road=0.6):
            d.drill_post(q, rnd.uniform(0, 360), shield=KH_NIGHT)
            d.solid(q[0], q[1], 0.9, 0.9, 1.8)

    # ---- Santuário Partido dos Anões: menires de runa azul (dois tombados), laje rachada ----
    sh = k["shrine"]
    dw = (0.56, 0.56, 0.62)
    d.blob("santuario", d.m("patch_laje_ana", (0.6, 0.6, 0.66)), sh, 3.4, 0.0079, 0.12, 8)
    # a racha passa NA FRENTE da pedra rúnica (o NPC fica no centro: por baixo dele a fenda fina virava dois riscos pretos soltos):
    # borda lascada larga em tom médio + miolo escuro, pontas em bico, um ramo. Só a 1ª fita gasta sorteio (json igual).
    crack = [Vector((sh[0] + dx, sh[1] + dz)) for dx, dz in ((-2.9, -0.2), (-1.9, 1.0), (-1.1, 0.8), (-0.3, 1.6), (0.6, 1.35), (1.4, 2.0), (2.2, 1.9))]
    branch = [Vector((sh[0] + dx, sh[1] + dz)) for dx, dz in ((-0.3, 1.6), (-0.65, 2.2), (-0.3, 2.75))]
    chip, core = d.m("patch_racha_borda", (0.44, 0.44, 0.5)), d.m("patch_racha", (0.22, 0.22, 0.27))
    d.strip("santuario", chip, crack, 0.7, 0.0084, 0.5, taper="point")
    keep = d.rnd.getstate()
    d.strip("santuario", chip, branch, 0.5, 0.0084, 0.5, taper="point")
    d.strip("santuario", core, crack, 0.26, 0.0089, 0.4, taper="point")
    d.strip("santuario", core, branch, 0.18, 0.0089, 0.4, taper="point")
    d.rnd.setstate(keep)
    for kk in range(6):
        q = P(sh, 11.0, 15.0 + kk * 60.0)
        if not d.ok(q[0], q[1], 0.9, road=0.8):
            continue
        if kk % 3 == 2:
            d.log("santuario", d.m("menir_56", dw), q, 0.5, 3.2, rnd.uniform(0, 180), 0.4)
            d.solid(q[0], q[1], 3.2, 1.0, 1.0)
        else:
            d.standing_stone(q, rnd.uniform(2.8, 4.2), dw, (0.5, 0.75, 1.0))
            d.solid(q[0], q[1], 1.1, 1.1, 3.0)

    # ---- Cabana do Xamã Exilado: totem desbotado, ossos, marco; chegada: placa, carroça de suprimento ----
    sm = k["shaman"]
    for q, what in ((P(sm, 10.5, 150.0), "totem"), (P(sm, 10.5, 30.0), "cairn"), (P(sm, 11.0, 210.0), "bones")):
        if d.ok(q[0], q[1], 0.8, road=0.6):
            if what == "totem":
                d.totem(q, 4.0, 30.0, cols=((0.44, 0.36, 0.34), (0.8, 0.78, 0.7), (0.5, 0.56, 0.44)))
                d.solid(q[0], q[1], 0.9, 0.9, 4.0)
            elif what == "cairn":
                d.cairn(q, 1.3, (0.4, 0.38, 0.4))
                d.solid(q[0], q[1], 1.0, 1.0, 1.2)
            else:
                d.bones(q, 5, 1.2)
    sp = z.data["spawn"]
    for q, what in (((sp[0] + 6.5, sp[1] - 3.0), "cart"), ((sp[0] - 5.5, sp[1] - 5.0), "sign")):
        if d.ok(q[0], q[1], 1.6, road=0.6):
            if what == "cart":
                d.cart(q, 70.0, load=(0.88, 0.84, 0.72))
                d.solid(q[0], q[1], 2.2, 3.2, 1.4)
            else:
                d.signpost(q, 20.0, n=3)
                d.solid(q[0], q[1], 0.5, 0.5, 2.0)
    for q in ((4.0 + 4.5, 44.0 + 3.0), (-40.0 - 3.0, -5.0 + 4.5), (-1.0 + 5.0, -63.0 + 3.0), (-4.0 - 5.0, 64.0 + 3.0)):   # placas nas bifurcações
        if d.ok(q[0], q[1], 0.5, road=0.5):
            d.signpost(q, rnd.uniform(0, 90))
            d.solid(q[0], q[1], 0.5, 0.5, 2.0)

    # ---- campo: afloramentos e feixes de basalto, ossadas, conjuntos ----
    outcrops(d, [((0, 0), 104, 12), ((-88, -12), 24, 4), ((30, -90), 26, 4)], KH_BASALT, KH_BASALT_TOP, r=(1.8, 3.4), hmul=1.5)
    for x, zz in d.spots([((0, 0), 104, 20), ((10, -84), 38, 8), ((84, -66), 20, 4), ((-56, 70), 22, 5)], r=2.6, spacing=11.0, road=2.2, water=1.6, blocked=True):
        basalt_columns(d, (x, zz), rnd.randint(5, 9), rnd.uniform(1.3, 2.0), (1.4, 4.2))
        d.solid(x, zz, 3.2, 3.2, 2.5)
        d.reserve(x, zz, 3.4)
    setpieces(d, [((0, 0), 104, 10)], ("crater", "bonefield", "ruin", "crater", "camp", "circle"), spacing=30.0, stone=(0.36, 0.34, 0.38), rune=(1.0, 0.5, 0.2))
    for kk in range(14):
        for x, zz in d.spots([((0, 0), 100, 1)], r=1.2, spacing=1.0, road=1.0, blocked=True):
            if kk % 3 == 0:
                d.cairn((x, zz), rnd.uniform(0.9, 1.4), (0.36, 0.34, 0.38))
                d.solid(x, zz, 1.0, 1.0, 1.2)
            else:
                d.bones((x, zz), rnd.randint(3, 6), 1.4)
    total = d.flush()
    for i, (tag, when, fn) in enumerate(lots):
        dd = Dress(z, 421 + i * 2, tag, when)
        fn(dd)
        total += dd.flush()
    return total


# ----------------------------------------------------------------------------------------------------------------
# masmorras de Kharzun (Salão dos Matadores e a Cidadela): salões redondos ligados por corredor (layout de dados)
# ----------------------------------------------------------------------------------------------------------------
KH_SHADOW = (0.7, 0.35, 0.9)           # chama roxa dos Matadores
KH_POISON = (0.55, 0.95, 0.4)


def floor_tones(d, key, floor, k=0.13):
    """Tinta de chão de arena (anéis, raios): dois tons do PRÓPRIO chão (claro, escuro), a ±k de valor e puxados para o
    cinza. Cor viva, anel cheio e brilho no chão ficam só para os avisos de golpe (art review 2026-11-13, item 1)."""
    light, dark = floor_tone_colors(floor, k)
    return (d.m("patch_tom_%s_claro" % key, light), d.m("patch_tom_%s_esc" % key, dark))


def floor_tone_colors(floor, k=0.13):
    """(claro, escuro) em cor: os dois tons de floor_tones, para quem pinta por cor (Dress.rug) e não por material."""
    g = sum(floor[:3]) / 3.0
    base = [c * 0.8 + g * 0.2 for c in floor[:3]]
    return tuple(min(1.0, c * (1.0 + k)) for c in base), tuple(c * (1.0 - k) for c in base)


class Halls:
    """Ajuda a vestir salões redondos: bocas (rumo de cada corredor), pontos na borda longe das bocas, anéis pintados."""

    def __init__(self, d, rooms, edges):
        self.d, self.rooms, self.edges = d, rooms, edges

    def mouths(self, name):
        x, y = self.rooms[name]["pos"]
        out = []
        for e in self.edges:
            a, b = e[0], e[1]
            if name in (a, b):
                ox, oy = self.rooms[b if a == name else a]["pos"]
                out.append(math.atan2(oy - y, ox - x))
        return out

    def rim(self, name, n, k0=0.88, k1=0.95, gap=0.5):
        """[(ponto, ângulo)] na borda do salão (fração k0..k1 do raio), fora das bocas."""
        x, y = self.rooms[name]["pos"]
        r = self.rooms[name]["r"]
        ms = self.mouths(name)
        rnd = self.d.rnd
        out = []
        for i in range(n):
            a = math.tau * (i + rnd.uniform(0.25, 0.75)) / n
            if any(abs(math.atan2(math.sin(a - m), math.cos(a - m))) < gap for m in ms):
                continue
            rr = r * rnd.uniform(k0, k1)
            out.append(((x + math.cos(a) * rr, y + math.sin(a) * rr), a))
        return out

    def rings(self, name, mats, fracs, y=0.0226, w=0.34, group="anel"):
        """Anéis tracejados pintados no chão (arena, selo): mats alterna por traço."""
        x, y0 = self.rooms[name]["pos"]
        r = self.rooms[name]["r"]
        for k, f in enumerate(fracs):
            n = 8 + k * 4
            for j in range(n):
                a = math.tau * j / n
                self.d.arc(group, mats[(k + j) % len(mats)], (x, y0), r * f, a + 0.04, a + math.tau / n - 0.04, w, y, 0.2, 0.9)

    def tones(self, name, k=0.13):
        """[claro, escuro] do chão do salão (floor_tones): a tinta de arena nunca usa a cor dos avisos."""
        return list(floor_tones(self.d, name, self.rooms[name]["floor"], k))

    def basalt(self, name, per_m=1.9, color=KH_BASALT):
        """Feixes de basalto colados na parede (por fora do chão do salão): a borda deixa de ser um círculo liso."""
        rnd = self.d.rnd
        for (p, a) in self.rim(name, int(self.rooms[name]["r"] * per_m), 0.98, 1.08, 0.42):
            basalt_columns(self.d, p, rnd.randint(3, 6), rnd.uniform(0.9, 1.5), (1.0, 3.2), color)

    def put(self, p, r=0.8, road=0.2):
        return self.d.ok(p[0], p[1], r, road=road)

    def corridor(self, fn, every=3.4, w=6.75):
        """Chama fn(q, rumo) em pontos alternados da beira de cada corredor, fora dos salões."""
        rnd = self.d.rnd
        for name, poly in self.d.z.road_polys.items():
            acc = 0.0
            for i in range(2, len(poly) - 2):
                acc += (poly[i] - poly[i - 1]).length
                if acc < every:
                    continue
                acc = 0.0
                t = (poly[i + 1] - poly[i - 1]).normalized()
                s = 1 if rnd.random() < 0.5 else -1
                q = poly[i] + Vector((-t.y, t.x)) * s * (w * 0.5 - rnd.uniform(0.1, 0.5))
                if any((q - Vector(r["pos"])).length < r["r"] + 0.5 for r in self.rooms.values()):
                    continue
                fn((q.x, q.y), math.atan2(t.y, t.x))


def slayers(z, rooms, edges):
    """Salão dos Matadores: roxo-noite e chama roxa. Vestíbulo com panos e fumaça, galeria com bonecos de treino e alvos,
    cripta com caldeirões e cogumelos de veneno, arena do Mestre com anéis pintados, lâminas fincadas e braseiros."""
    d = Dress(z, 547)
    rnd = d.rnd
    h = Halls(d, rooms, edges)
    night = KH_NIGHT
    shadow = d.m("glow_sombra", KH_SHADOW)
    for name in rooms:
        h.basalt(name, 1.7, KH_BASALT_DARK)
        for (p, a) in h.rim(name, int(rooms[name]["r"] * 0.9), 0.8, 0.92):
            d.pebbles("gruta", d.m("seixo_matadores", (0.3, 0.27, 0.33)), p, rnd.randint(3, 5), 1.0, (0.12, 0.28))

    def side(q, ang):
        k = rnd.random()
        if k < 0.35:
            d.torch(q, 2.3, fire="glow_sombra")
        elif k < 0.6:
            for _ in range(rnd.randint(2, 4)):
                d.mushroom((q[0] + rnd.uniform(-0.5, 0.5), q[1] + rnd.uniform(-0.5, 0.5)), rnd.uniform(0.6, 1.2), (0.7, 0.4, 0.95))
        elif k < 0.8:
            basalt_columns(d, q, 3, 0.7, (0.6, 1.6), KH_BASALT_DARK)
        else:
            d.bones(q, 3, 0.7)
    h.corridor(side)
    cx, cy = rooms["chegada"]["pos"]
    for s in (-1, 1):
        d.torch((cx + s * 4.6, cy + 2.0), 2.4, fire="glow_sombra")
        d.flag((cx + s * 5.4, cy - 3.0), night, 5.0, 90.0, w=1.0, drop=1.8)
    # ---- vestíbulo: tapetes em tons do chão (roxo vivo no chão é dos avisos de controle: art review r2, item 3),
    #      manchas de fumaça, flâmulas dos Matadores e cavaletes de facas ----
    x, y = rooms["vestibulo"]["pos"]
    r = rooms["vestibulo"]["r"]
    smoke = [d.m("patch_fumaca_a", (0.24, 0.21, 0.3)), d.m("patch_fumaca_b", (0.36, 0.3, 0.44))]
    for i in range(14):
        q = P((x, y), rnd.uniform(2.0, r * 0.82), rnd.uniform(0, 360))
        d.blob("vestibulo", smoke[i % 2], q, rnd.uniform(1.2, 2.8), 0.0222 + (i % 2) * 0.0004, 0.4)
    rug_light, rug_dark = floor_tone_colors(rooms["vestibulo"]["floor"])
    for deg in (40.0, 140.0, 220.0, 320.0):
        q = P((x, y), r * 0.5, deg)
        d.rug(q, 3.4, 2.2, -deg, rug_dark, rug_light)
    for j, (p, a) in enumerate(h.rim("vestibulo", 14)):
        if not h.put(p):
            continue
        if j % 3 == 0:
            d.flag(p, night, 5.2, math.degrees(-a) + 90.0, w=1.1, drop=2.0)
            d.solid(p[0], p[1], 0.4, 0.4, 4.0)
        elif j % 3 == 1:
            d.brazier(p, 1.1, fire="glow_sombra", color=KH_SHADOW)
            d.solid(p[0], p[1], 1.1, 1.1, 1.4)
        else:
            d.weapon_rack(p, math.degrees(-a) + 90.0)
            d.solid(p[0], p[1], 2.4, 0.8, 1.6, math.degrees(-a) + 90.0)
    # ---- galeria de treino: roda de bonecos no meio, alvos e cavaletes na borda, palha no chão, círculo de luta ----
    x, y = rooms["galeria"]["pos"]
    r = rooms["galeria"]["r"]
    straw = [d.m("patch_palha_a", (0.72, 0.6, 0.36)), d.m("patch_palha_b", (0.6, 0.5, 0.32))]
    for i in range(18):
        q = P((x, y), rnd.uniform(1.0, r * 0.84), rnd.uniform(0, 360))
        d.blob("galeria", straw[i % 2], q, rnd.uniform(1.0, 2.2), 0.0222 + (i % 2) * 0.0004, 0.4)
    h.rings("galeria", h.tones("galeria"), (0.3,), w=0.22)
    for k in range(7):
        q = P((x, y), r * 0.56, k * 360.0 / 7 + 12.0)
        if h.put(q, 0.7, 0.6):
            d.drill_post(q, -(k * 360.0 / 7 + 12.0), shield=night, boss=KH_SHADOW)
            d.solid(q[0], q[1], 0.9, 0.9, 1.8)
    for j, (p, a) in enumerate(h.rim("galeria", 16)):
        if not h.put(p):
            continue
        if j % 3 == 0:
            d.target(p, math.degrees(-a) + 90.0)
            d.solid(p[0], p[1], 1.0, 1.0, 1.6)
        elif j % 3 == 1:
            d.weapon_rack(p, math.degrees(-a) + 90.0)
            d.solid(p[0], p[1], 2.4, 0.8, 1.6, math.degrees(-a) + 90.0)
        else:
            d.hay(p, rnd.uniform(0.9, 1.3))
            d.solid(p[0], p[1], 1.4, 1.4, 1.0)
    # ---- cripta de venenos: poças verdes, cogumelos que brilham, cristais, barris e a mesa do alquimista ----
    x, y = rooms["venenos"]["pos"]
    r = rooms["venenos"]["r"]
    ooze = [d.m("patch_veneno_esc", (0.2, 0.34, 0.24)), d.m("patch_veneno", (0.34, 0.56, 0.32)), d.m("glow_veneno", KH_POISON)]
    for i in range(14):
        q = P((x, y), rnd.uniform(3.0, r * 0.84), rnd.uniform(0, 360))
        d.blob("venenos", ooze[i % 2], q, rnd.uniform(0.8, 2.0), 0.0222 + (i % 2) * 0.0004, 0.35)
        if i % 4 == 0:
            d.blob("venenos", ooze[2], q, 0.4, 0.0234, 0.2, 8)
    for j, (p, a) in enumerate(h.rim("venenos", 14, 0.84, 0.95)):
        if j % 3 == 0:
            for _ in range(rnd.randint(3, 5)):
                d.mushroom((p[0] + rnd.uniform(-0.7, 0.7), p[1] + rnd.uniform(-0.7, 0.7)), rnd.uniform(0.7, 1.5), (0.5, 0.95, 0.45))
        elif j % 3 == 1:
            d.crystal(p, rnd.uniform(0.7, 1.1), KH_POISON)
        elif h.put(p, 1.0):
            d.cargo(p, 3, 0.8)
            d.solid(p[0], p[1], 1.8, 1.8, 1.2)
    # ---- arena do Mestre: anéis e raios em tons do chão (roxo vivo no chão é dos avisos do Shazka), lâminas fincadas
    #      num círculo, braseiros roxos, panos ----
    x, y = rooms["mestre"]["pos"]
    r = rooms["mestre"]["r"]
    tones = h.tones("mestre")
    h.rings("mestre", tones, (0.3, 0.5, 0.7), w=0.24)
    blood = tones[1]
    for j in range(12):
        a = j * 30.0 + 8.0
        d.strip("mestre", blood, [Vector(P((x, y), r * 0.33, a)), Vector(P((x, y), r * 0.41, a + 3)), Vector(P((x, y), r * 0.48, a))], 0.3, 0.0228, 0.2, taper=True)
    iron = d.m("ferro", (0.6, 0.62, 0.66))
    for j in range(16):                                      # lâminas fincadas (baixas: não tapam a luta, não colidem)
        q = P((x, y), r * 0.78, j * 22.5 + 5.0)
        d.cyl("mestre3d", iron, q, 0.07, 0.0, 0.9, 0.0, 4, rnd.uniform(0, 90), (rnd.uniform(-14, 14), rnd.uniform(-14, 14)))
    for j, (p, a) in enumerate(h.rim("mestre", 18, 0.9, 0.96)):
        if not h.put(p):
            continue
        if j % 3 == 0:
            d.brazier(p, 1.3, fire="glow_sombra", color=KH_SHADOW)
            d.solid(p[0], p[1], 1.2, 1.2, 1.4)
        elif j % 3 == 1:
            d.flag(p, night, 5.6, math.degrees(-a) + 90.0, w=1.2, drop=2.2)
            d.solid(p[0], p[1], 0.4, 0.4, 4.0)
        else:
            d.bones(p, 5, 0.9)
    return d.flush()
