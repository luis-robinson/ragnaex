"""Acabamento das masmorras do Ato III parte 1 (GDD ato3-excesso-45-50 §2.2, §4): Adegas do Banquete, Galeria dos
Espelhos, Conservatório do Coro Ferido e o Coração do Jardim. Chamado pelo build_dungeons (tabela `DRESS`), depois da
rocha e antes do `z.finish`; os salões e ligações vêm de places.DUNGEONS.

Regras de chão (art review 2026-11-13, GDD §4.3/§4.4): tinta de chão (xadrez, anéis, tapetes, manchas) só em tons do
PRÓPRIO chão (`Halls.tones`) ou fosca e dessaturada (vinho); nenhum `glow_*` no chão. Brilho só em chama de vela, cristal
e na coroa. Dentro do raio livre da luta do chefe nada colide: mesas, bancadas e espelhos encostam na parede.

Pilha de planos nos salões (mm): praça 14 · chão do salão 20 · xadrez 21,2-21,8 · manchas/tapete 22,2-22,6 · anéis 23,0 ·
poça fosca 30.

Cada função grava em data["boss_hint"] os pontos da mecânica do chefe (lacaios parados, raio livre), para o WP8.
"""
import math

from mathutils import Vector

import build_lumeria as bl
from act2_dress import Halls, floor_tone_colors
from dress import Dress

CANDLE = (1.0, 0.82, 0.52)
VELVET = (0.52, 0.22, 0.32)
WOOD = (0.5, 0.37, 0.3)
WOOD_D = (0.36, 0.28, 0.26)
GLASS = (0.72, 0.78, 0.86)
RING_Y = 0.0230


def P(c, r, deg):
    return (c[0] + math.cos(math.radians(deg)) * r, c[1] + math.sin(math.radians(deg)) * r)


def tang(a):
    """Rotação de uma peça na borda (ângulo `a` em rad): o x local corre pela parede e a frente (+yb) olha para o centro."""
    return math.degrees(-a) + 90.0


def _floors(z, rooms):
    base = tuple(z.M["road"].diffuse_color[:3])
    for r in rooms.values():
        r.setdefault("floor", base)


def candelabra(d, c, h=1.9, s=1.0):
    gold = d.m("castical", bl.OLD_GOLD)
    fire = d.m("glow_vela", CANDLE)
    d.cyl("luz", gold, c, 0.22 * s, 0.08 * s, 0.14, 0.0, 6)
    d.cyl("luz", gold, c, 0.05 * s, 0.05 * s, h, 0.1, 5)
    for k in range(3):
        q = P(c, 0.28 * s, 120.0 * k + 30.0)
        d.cyl("luz", gold, q, 0.05 * s, 0.09 * s, 0.1, h, 5)
        d.cyl("luz", d.m("vela", (0.95, 0.92, 0.84)), q, 0.04 * s, 0.04 * s, 0.22, h + 0.1, 4)
        d.cyl("luz", fire, q, 0.07 * s, 0.0, 0.26, h + 0.32, 4)


def standing_mirror(d, c, rot, h=2.8, w=1.5, cracked=False, g="espelho"):
    """Espelho de pé: moldura de ouro velho, vidro FOSCO dos dois lados, pé e remate em bico."""
    gold = d.m("moldura", bl.OLD_GOLD)
    glass = d.m("espelho_fosco", GLASS)
    d.box(g, gold, c, (w + 0.3, 0.25, 0.5), rot, 0.0)
    d.box(g, gold, c, (w, h, 0.16), rot, 0.25)
    for s in (-1, 1):
        d.box(g, glass, bl.loc(c, rot, 0.0, s * 0.09), (w - 0.3, h - 0.4, 0.03), rot, 0.45)
        if cracked:
            d.box(g, d.m("espelho_racha", (0.36, 0.38, 0.46)), bl.loc(c, rot, 0.12, s * 0.11), (0.05, h - 0.9, 0.02), rot, 0.7, (0, 14))
            d.box(g, d.m("espelho_racha", (0.36, 0.38, 0.46)), bl.loc(c, rot, -0.2, s * 0.11), (0.04, h * 0.4, 0.02), rot, 1.0, (0, -24))
    d.cyl(g, gold, c, 0.34, 0.0, 0.45, h + 0.25, 4, rot + 45.0)


def tun(d, c, rot, r=1.25, L=2.6, g="tonel"):
    """Tonel deitado no berço: o eixo corre no x local de `rot`."""
    wood = d.m("tonel", (0.52, 0.38, 0.32))
    hoop = d.m("tonel_aro", (0.3, 0.27, 0.3))
    y = r + 0.3
    d.cyl(g, wood, bl.loc(c, rot, -L * 0.5, 0.0), r * 0.9, r * 0.9, L, y, 10, rot + 90.0, tilt=(90, 0))
    d.cyl(g, wood, bl.loc(c, rot, -L * 0.32, 0.0), r, r, L * 0.64, y, 10, rot + 90.0, tilt=(90, 0))
    for x in (-L * 0.36, L * 0.3):
        d.cyl(g, hoop, bl.loc(c, rot, x, 0.0), r * 1.03, r * 1.03, 0.12, y, 10, rot + 90.0, tilt=(90, 0))
        d.box(g, d.m("tonel_berco", WOOD_D), bl.loc(c, rot, x + 0.06, 0.0), (0.3, 0.5, r * 1.9), rot, 0.0)
    d.cyl(g, hoop, bl.loc(c, rot, L * 0.5, 0.0), 0.1, 0.06, 0.3, y - r * 0.5, 5, rot + 90.0, tilt=(90, 0))        # torneira


def organ_pipes(d, c, rot, n=5, h0=1.6, h1=3.4, r=0.2, g="orgao"):
    """Fileira de tubos de órgão de ouro velho ao longo do x local, mais altos no meio."""
    gold, gold_d = d.m("orgao_tubo", bl.OLD_GOLD), d.m("orgao_tubo_esc", (0.66, 0.56, 0.36))
    for k in range(n):
        u = (k - (n - 1) * 0.5) / max(1.0, (n - 1) * 0.5)
        q = bl.loc(c, rot, (k - (n - 1) * 0.5) * r * 2.4, 0.0)
        hh = h1 - (h1 - h0) * abs(u)
        d.cyl(g, gold if k % 2 else gold_d, q, r, r, hh, 0.0, 6)
        d.cyl(g, gold_d, q, r * 1.15, r * 0.7, 0.3, hh, 6)
        d.box(g, d.m("orgao_boca", (0.2, 0.17, 0.22)), bl.loc(q, rot, 0.0, r * 0.9), (r * 0.9, 0.24, 0.05), rot, 0.6)


def checker(d, room, dark, step=2.0, frac=0.84):
    """Piso xadrez: só o tom ESCURO do próprio chão em ladrilhos alternados (o claro é o chão do salão)."""
    x0, y0 = room["pos"]
    r = room["r"] * frac
    n = int(r / step) + 1
    for i in range(-n, n + 1):
        for j in range(-n, n + 1):
            if (i + j) % 2 or math.hypot(i * step, j * step) > r - step * 0.6:
                continue
            d.box("xadrez", dark, (x0 + i * step, y0 + j * step), (step, 0.0006, step), 0.0, 0.0212)


def stains(d, h, name, room, n, key, k=0.1, rmin=0.9, rmax=2.4):
    cols = floor_tone_colors(room["floor"], k)
    ms = [d.m("patch_%s_%s_%d" % (key, name, i), c) for i, c in enumerate(cols)]
    x, y = room["pos"]
    for i in range(n):
        q = P((x, y), d.rnd.uniform(1.0, room["r"] * 0.84), d.rnd.uniform(0, 360))
        d.blob(name, ms[i % 2], q, d.rnd.uniform(rmin, rmax), 0.0222 + (i % 2) * 0.0004, 0.4)


def opposite(h, name):
    """Ângulo (rad) do fundo do salão: o lado oposto à média das bocas."""
    ms = h.mouths(name)
    sx, sy = sum(math.cos(m) for m in ms), sum(math.sin(m) for m in ms)
    return math.atan2(-sy, -sx)


def _hint(z, room, boss, **extra):
    x, y = room["pos"]
    hint = {"id": boss, "pos": [round(x, 2), round(y, 2)], "arena_r": round(room["r"], 2)}
    for k, v in extra.items():
        hint[k] = [[round(q[0], 2), round(q[1], 2)] for q in v] if isinstance(v, list) and v and not isinstance(v[0], str) else v
    z.data["boss_hint"] = hint


# ----------------------------------------------------------------------------------------------------------------
# Adegas do Banquete (dg_cellars): tonéis, despensa, lagar e o salão do banquete do Varo Taça-Cheia
# ----------------------------------------------------------------------------------------------------------------
def cellars(z, rooms, edges):
    _floors(z, rooms)
    d = Dress(z, 701)
    rnd = d.rnd
    h = Halls(d, rooms, edges)
    wine = [d.m("patch_vinho_fosco_a", (0.38, 0.26, 0.33)), d.m("patch_vinho_fosco_b", (0.44, 0.3, 0.37))]
    for name, room in rooms.items():
        stains(d, h, name, room, int(room["r"] * 0.7), "umido", 0.05, 0.8, 1.9)
        for (p, a) in h.rim(name, int(room["r"] * 0.7), 0.5, 0.82):          # respingos de vinho (foscos)
            d.blob(name, wine[rnd.randrange(2)], p, rnd.uniform(0.4, 1.1), 0.0226, 0.45)

    def side(q, ang):
        k = rnd.random()
        if k < 0.3:
            candelabra(d, q, 1.8)
        elif k < 0.6:
            d.barrel(q, rnd.uniform(0.9, 1.2), g="adega", color=(0.5, 0.36, 0.3))
            if rnd.random() < 0.5:
                d.barrel((q[0] + 0.9, q[1] + 0.3), 0.85, g="adega", color=(0.46, 0.34, 0.3))
        elif k < 0.82:
            d.crate(q, rnd.uniform(0.8, 1.1), rnd.uniform(0, 90), g="adega")
        else:
            for i in range(3):                               # garrafões no chão
                p = (q[0] + rnd.uniform(-0.5, 0.5), q[1] + rnd.uniform(-0.5, 0.5))
                d.cyl("adega", d.m("garrafa", (0.3, 0.44, 0.36)), p, 0.2, 0.16, 0.5, 0.0, 6)
                d.cyl("adega", d.m("garrafa", (0.3, 0.44, 0.36)), p, 0.07, 0.05, 0.3, 0.5, 5)
    h.corridor(side)
    cx, cy = rooms["chegada"]["pos"]
    for s in (-1, 1):
        candelabra(d, (cx + s * 4.6, cy + 2.0), 2.1, 1.2)
        d.flag((cx + s * 5.4, cy - 3.0), VELVET, 5.0, 90.0, tatter=False, w=1.0, drop=1.8)
    # ---- tonéis: os grandes deitados em volta da parede, de frente para o salão ----
    for j, (p, a) in enumerate(h.rim("toneis", 15, 0.84, 0.88)):
        if not h.put(p, 1.5):
            continue
        if j % 4 == 3:
            candelabra(d, p, 2.0)
            d.solid(p[0], p[1], 0.5, 0.5, 2.0)
        else:
            rot = tang(a) + 90.0                             # eixo do tonel = raio do salão (a tampa olha para dentro)
            tun(d, p, rot, rnd.uniform(1.1, 1.35), 2.6)
            d.solid(p[0], p[1], 2.6, 2.6, 2.6, rot)
    # ---- despensa: prateleiras de garrafas, sacas e caixas ----
    for j, (p, a) in enumerate(h.rim("despensa", 11, 0.8, 0.86)):
        if not h.put(p, 1.2):
            continue
        rot = tang(a)
        if j % 3 == 0:
            d.box("despensa", d.m("estante", WOOD), p, (2.4, 2.2, 0.6), rot, 0.0)
            for row in range(3):
                for k in range(5):
                    q = bl.loc(p, rot, -0.9 + k * 0.45, 0.32)
                    d.cyl("despensa", d.m("garrafa", (0.3, 0.44, 0.36)) if (k + row) % 3 else d.m("garrafa_b", (0.5, 0.3, 0.38)), q, 0.09, 0.05, 0.36, 0.3 + row * 0.66, 5)
            d.solid(p[0], p[1], 2.4, 0.9, 2.2, rot)
        elif j % 3 == 1:
            d.cargo(p, 4, 1.0, g="despensa")
            d.solid(p[0], p[1], 1.9, 1.9, 1.2)
        else:
            d.sack(p, 1.1, g="despensa")
            d.sack((p[0] + 0.7, p[1] + 0.4), 0.9, g="despensa", color=(0.66, 0.58, 0.5))
            d.solid(p[0], p[1], 1.5, 1.5, 0.9)
    # ---- lagar: a prensa de fuso no meio da poça fosca, cestos de uva e tonéis na parede ----
    x, y = rooms["lagar"]["pos"]
    st, wood = d.m("lagar_pedra", (0.56, 0.52, 0.54)), d.m("lagar_madeira", WOOD)
    d.cyl("lagar", st, (x, y), 2.9, 3.0, 0.7, 0.0, 12)
    d.cyl("lagar", d.m("vinho_fosco", bl.WINE), (x, y), 2.6, 2.6, 0.05, 0.68, 12)
    d.cyl("lagar", wood, (x, y), 1.7, 1.7, 0.3, 1.5, 10)
    d.cyl("lagar", d.m("lagar_fuso", WOOD_D), (x, y), 0.3, 0.3, 4.2, 0.7, 6)
    d.box("lagar", wood, (x, y), (6.0, 0.4, 0.5), 30.0, 3.6)
    for s in (-1, 1):
        q = bl.loc((x, y), 30.0, s * 2.8, 0.0)
        d.box("lagar", wood, q, (0.4, 4.2, 0.5), 30.0, 0.0)
    d.solid(x, y, 6.2, 6.2, 3.0)
    grape = d.m("uva", (0.46, 0.3, 0.52))
    for j, (p, a) in enumerate(h.rim("lagar", 13, 0.82, 0.88)):
        if not h.put(p, 1.4):
            continue
        if j % 3 == 0:
            rot = tang(a) + 90.0
            tun(d, p, rot, 1.15, 2.4)
            d.solid(p[0], p[1], 2.4, 2.4, 2.4, rot)
        elif j % 3 == 1:
            for k in range(3):
                q = (p[0] + rnd.uniform(-0.8, 0.8), p[1] + rnd.uniform(-0.8, 0.8))
                d.cyl("lagar", d.m("cesto", (0.66, 0.54, 0.38)), q, 0.4, 0.5, 0.45, 0.0, 7)
                d.rock("lagar", grape, q, 0.42, 0.3, 0.6)
            d.solid(p[0], p[1], 1.8, 1.8, 0.9)
        else:
            candelabra(d, p, 2.0)
            d.solid(p[0], p[1], 0.5, 0.5, 2.0)
    # ---- salão do banquete: miolo livre (a luta); mesas em U na parede, mesa de honra e o cadeirão do Varo no fundo ----
    room = rooms["banquete"]
    x, y = room["pos"]
    r = room["r"]
    tones = h.tones("banquete")
    h.rings("banquete", tones, (0.3, 0.52, 0.72), y=RING_Y, w=0.26)
    back = opposite(h, "banquete")
    hq = P((x, y), r * 0.74, math.degrees(back))
    bl.banquet(z, d, hq, tang(back), 8.0)
    d.reserve(hq[0], hq[1], 4.4)
    tq = P((x, y), r * 0.86, math.degrees(back))
    d.box("trono", d.m("trono_veludo", VELVET), tq, (1.9, 0.9, 1.5), tang(back), 0.0)
    d.box("trono", d.m("trono_veludo", VELVET), bl.loc(tq, tang(back), 0.0, -0.6), (1.9, 3.0, 0.3), tang(back), 0.0)
    d.box("trono", d.m("trono_ouro", bl.OLD_GOLD), bl.loc(tq, tang(back), 0.0, -0.62), (2.2, 0.3, 0.36), tang(back), 3.0)
    for s in (-1, 1):
        d.box("trono", d.m("trono_ouro", bl.OLD_GOLD), bl.loc(tq, tang(back), s * 1.05, 0.0), (0.24, 1.5, 1.5), tang(back), 0.0)
    bl.mask(d, "trono", bl.loc(tq, tang(back), 0.0, -0.42), 3.9, tang(back), 1.3)
    d.solid(tq[0], tq[1], 2.4, 1.8, 3.0, tang(back))
    mouth = h.mouths("banquete")[0]
    for j in range(16):                                      # mesas e castiçais alternados na parede, fora da boca e do fundo
        a = math.tau * (j + 0.5) / 16
        if abs(math.atan2(math.sin(a - back), math.cos(a - back))) < 0.7 or abs(math.atan2(math.sin(a - mouth), math.cos(a - mouth))) < 0.5:
            continue
        p = P((x, y), r * (0.8 if j % 2 == 0 else 0.86), math.degrees(a))
        if j % 2 == 0:
            bl.banquet(z, d, p, tang(a), 5.0)
            d.reserve(p[0], p[1], 2.8)
        else:
            candelabra(d, p, 2.3, 1.3)
            d.solid(p[0], p[1], 0.6, 0.6, 2.2)
            q = P((x, y), r * 0.97, math.degrees(a))
            d.flag(q, VELVET, 5.6, tang(a), tatter=False, w=1.2, drop=2.2)
    _hint(z, room, "boss_varo", clear_r=round(r * 0.66, 1), adds=[P((x, y), r * 0.5, math.degrees(back) + k) for k in (-70.0, 0.0, 70.0)],
          note="F2: 3 reveler_guest nos pontos `adds`; mesas e trono fora de clear_r")
    return d.flush()


# ----------------------------------------------------------------------------------------------------------------
# Galeria dos Espelhos (dg_mirrors): foyer, galeria longa, camarins, ateliê e o Salão Espelhado da Condessa
# ----------------------------------------------------------------------------------------------------------------
def mirrors(z, rooms, edges):
    _floors(z, rooms)
    d = Dress(z, 703)
    rnd = d.rnd
    h = Halls(d, rooms, edges)
    T = {name: h.tones(name, 0.12) for name in rooms}
    for name, room in rooms.items():
        if name != "chegada":
            checker(d, room, T[name][1])

    def side(q, ang):
        if rnd.random() < 0.6:
            standing_mirror(d, q, math.degrees(-ang), rnd.uniform(2.4, 2.9), 1.3, rnd.random() < 0.25)
        else:
            candelabra(d, q, 1.9)
    h.corridor(side, every=3.0)
    cx, cy = rooms["chegada"]["pos"]
    for s in (-1, 1):
        candelabra(d, (cx + s * 4.6, cy + 2.0), 2.1, 1.2)
        d.flag((cx + s * 5.4, cy - 3.0), (0.86, 0.74, 0.92), 5.0, 90.0, tatter=False, w=1.0, drop=1.8)
    # ---- foyer: espelhos e castiçais em volta, tapete redondo em tom do chão ----
    x, y = rooms["foyer"]["pos"]
    tones = T["foyer"]
    d.blob("foyer", tones[0], (x, y), 4.2, 0.0224, 0.04, 40)
    h.rings("foyer", tones, (0.36,), y=RING_Y, w=0.22)
    for j, (p, a) in enumerate(h.rim("foyer", 14, 0.84, 0.88)):
        if not h.put(p, 1.0):
            continue
        if j % 2 == 0:
            standing_mirror(d, p, tang(a), 3.0, 1.7, j % 6 == 4)
            d.solid(p[0], p[1], 1.9, 0.7, 3.0, tang(a))
        else:
            candelabra(d, p, 2.2, 1.2)
            d.solid(p[0], p[1], 0.5, 0.5, 2.0)
    # ---- galeria longa: passadeira em tom do chão no eixo, espelhos altos na parede ----
    x, y = rooms["galeria"]["pos"]
    r = rooms["galeria"]["r"]
    tones = T["galeria"]
    d.strip("galeria", tones[0], [Vector((x, y - r * 0.84)), Vector((x, y)), Vector((x, y + r * 0.84))], 3.2, 0.0224)
    d.strip("galeria", tones[0], [Vector((x - r * 0.84, y)), Vector((x, y)), Vector((x + r * 0.84, y))], 3.2, 0.0226)
    for j, (p, a) in enumerate(h.rim("galeria", 18, 0.86, 0.9, 0.42)):
        if not h.put(p, 1.0):
            continue
        standing_mirror(d, p, tang(a), 3.2, 1.8, j % 5 == 2)
        d.solid(p[0], p[1], 2.0, 0.7, 3.0, tang(a))
    # ---- camarins: penteadeiras, biombos e araras de fantasias ----
    for j, (p, a) in enumerate(h.rim("camarins", 12, 0.8, 0.86)):
        if not h.put(p, 1.2):
            continue
        rot = tang(a)
        if j % 3 == 0:                                       # penteadeira com espelho oval e banquinho
            d.box("camarim", d.m("penteadeira", (0.86, 0.8, 0.78)), p, (1.7, 0.8, 0.6), rot, 0.0)
            d.cyl("camarim", d.m("moldura", bl.OLD_GOLD), bl.loc(p, rot, 0.0, -0.2), 0.55, 0.55, 0.08, 1.45, 8, rot, tilt=(90, 0))
            d.cyl("camarim", d.m("espelho_fosco", GLASS), bl.loc(p, rot, 0.0, -0.14), 0.44, 0.44, 0.04, 1.45, 8, rot, tilt=(90, 0))
            d.cyl("camarim", d.m("banquinho", VELVET), bl.loc(p, rot, 0.2, 0.9), 0.26, 0.22, 0.45, 0.0, 6)
            d.solid(p[0], p[1], 1.8, 1.0, 1.4, rot)
        elif j % 3 == 1:                                     # biombo de três folhas
            for k in (-1, 0, 1):
                col = bl.BUNTING[(j + k) % len(bl.BUNTING)]
                d.box("camarim", d.m("biombo_%d_%d" % (int(col[0] * 100), int(col[2] * 100)), col), bl.loc(p, rot, k * 0.95, 0.2 * abs(k)), (1.0, 2.1, 0.07), rot + k * 24.0, 0.05)
            d.solid(p[0], p[1], 2.8, 0.8, 2.0, rot)
        else:                                                # arara de fantasias
            a0, a1 = bl.loc(p, rot, -1.1, 0.0), bl.loc(p, rot, 1.1, 0.0)
            for q in (a0, a1):
                d.cyl("camarim", d.m("arara", WOOD_D), q, 0.05, 0.05, 1.8, 0.0, 4)
            d.tube("camarim", d.m("arara", WOOD_D), [(a0[0], 1.8, a0[1]), (a1[0], 1.8, a1[1])], 0.04, 0.04, 4)
            for k in range(4):
                col = bl.BUNTING[(j + k) % len(bl.BUNTING)]
                d.cloth("camarim", d.m("pano_fantasia_%d_%d" % (int(col[0] * 100), int(col[2] * 100)), col), bl.loc(p, rot, -1.0 + k * 0.52, 0.0), 0.46, 1.3, rot, 0.45, 0.0, "swallow")
            d.solid(p[0], p[1], 2.4, 0.7, 1.8, rot)
    # ---- ateliê das molduras: molduras vazias encostadas, cavaletes e caixas ----
    wall = d.m("moldura_fundo", (0.5, 0.45, 0.5))
    for j, (p, a) in enumerate(h.rim("atelie", 12, 0.8, 0.86)):
        if not h.put(p, 1.2):
            continue
        rot = tang(a)
        if j % 3 != 2:
            for k in range(2):
                q = bl.loc(p, rot, -0.6 + k * 1.1, -0.2 * k)
                w, hh = rnd.uniform(1.1, 1.6), rnd.uniform(1.5, 2.3)
                d.box("atelie", d.m("moldura", bl.OLD_GOLD), q, (w, hh, 0.1), rot + rnd.uniform(-8, 8), 0.0, (-10, 0))
                d.box("atelie", wall, bl.loc(q, rot, 0.0, 0.05), (w - 0.3, hh - 0.3, 0.1), rot, 0.15, (-10, 0))
            d.solid(p[0], p[1], 2.4, 0.9, 2.0, rot)
        else:
            d.cargo(p, 3, 0.9, g="atelie")
            d.solid(p[0], p[1], 1.8, 1.8, 1.2)
    # ---- Salão Espelhado: sem cobertura fixa. Espelhos altos NA parede (só desenho), anéis em tons do chão e os três
    #      "pousos" pintados onde a Condessa ergue os Espelhos de Pé (cobertura 2,5 m) ----
    room = rooms["salao"]
    x, y = room["pos"]
    r = room["r"]
    tones = T["salao"]
    h.rings("salao", tones, (0.26, 0.5, 0.74), y=RING_Y, w=0.26)
    for j, (p, a) in enumerate(h.rim("salao", 30, 1.0, 1.03, 0.4)):
        standing_mirror(d, p, tang(a), 4.4, 2.1, j % 3 == 1, g="salao")
    for j, (p, a) in enumerate(h.rim("salao", 10, 0.92, 0.95, 0.5)):
        candelabra(d, p, 2.4, 1.3)
        d.solid(p[0], p[1], 0.5, 0.5, 2.2)
    mouth = math.degrees(h.mouths("salao")[0])
    pads = [P((x, y), r * 0.46, mouth + k) for k in (60.0, 180.0, 300.0)]
    for q in pads:
        d.blob("pouso", tones[1], q, 1.7, 0.0224, 0.03, 20, sx=1.25, rot=rnd.uniform(0, 180))
        d.blob("pouso", tones[0], q, 1.0, 0.0227, 0.03, 16, sx=1.25)
    _hint(z, room, "boss_countess", clear_r=round(r * 0.9, 1), cover=pads, cover_r=2.5,
          note="Olhar Que Julga: 3 standing_mirror nos pontos `cover`; nenhum colisor fixo dentro de clear_r")
    return d.flush()


# ----------------------------------------------------------------------------------------------------------------
# Conservatório do Coro Ferido (dg_conservatory, opcional): átrio, duas alas e a sala de concerto da Mestra Ressoa
# ----------------------------------------------------------------------------------------------------------------
def _benches(d, h, name, room, rows=((0.78, 0.45), (0.87, 0.9)), skip=None):
    """Bancadas em arco encostadas na parede (dois degraus), fora das bocas; colisor um por lance."""
    x, y = room["pos"]
    r = room["r"]
    ms = h.mouths(name)
    wood, cush = d.m("bancada", WOOD), d.m("bancada_almofada", (0.56, 0.44, 0.62))
    n = max(8, int(math.tau * r * rows[0][0] / 2.6))
    for i in range(n):
        a = math.tau * (i + 0.5) / n
        if any(abs(math.atan2(math.sin(a - m), math.cos(a - m))) < 0.55 for m in ms) or (skip and skip(a)):
            continue
        for k, (f, hh) in enumerate(rows):
            p = P((x, y), r * f, math.degrees(a))
            L = math.tau * r * f / n * 0.94
            d.box("bancada", wood, p, (L, hh, 0.9), tang(a), 0.0)
            if (i + k) % 3:
                d.box("bancada", cush, p, (L * 0.8, 0.08, 0.6), tang(a), hh)
        p = P((x, y), r * (rows[0][0] + rows[-1][0]) * 0.5, math.degrees(a))
        d.solid(p[0], p[1], math.tau * r * 0.82 / n, r * (rows[-1][0] - rows[0][0]) + 1.0, 1.0, tang(a))


def conservatory(z, rooms, edges):
    _floors(z, rooms)
    d = Dress(z, 705)
    rnd = d.rnd
    h = Halls(d, rooms, edges)
    T = {name: h.tones(name, 0.1) for name in rooms}
    for name, room in rooms.items():
        if name != "chegada":
            h.rings(name, T[name], (0.34, 0.5, 0.66), y=RING_Y, w=0.16)       # pauta: linhas finas em tons do chão

    def side(q, ang):
        if rnd.random() < 0.55:
            organ_pipes(d, q, math.degrees(-ang), rnd.randint(3, 5), 1.0, rnd.uniform(1.8, 2.8), 0.16)
        else:
            candelabra(d, q, 1.9)
    h.corridor(side, every=3.2)
    cx, cy = rooms["chegada"]["pos"]
    for s in (-1, 1):
        organ_pipes(d, (cx + s * 5.0, cy + 1.0), 90.0, 5, 1.6, 3.4, 0.2)
        candelabra(d, (cx + s * 4.2, cy - 3.0), 2.1, 1.2)
    for name in ("atrio", "ala_oeste", "ala_leste"):
        _benches(d, h, name, rooms[name])
        for j, (p, a) in enumerate(h.rim(name, 9, 0.97, 1.02, 0.5)):
            organ_pipes(d, p, tang(a), 5, 1.8, rnd.uniform(3.0, 4.4), 0.2)
    # ala oeste: harpas; ala leste: estantes de partitura
    x, y = rooms["ala_oeste"]["pos"]
    gold = d.m("orgao_tubo", bl.OLD_GOLD)
    for k in range(4):
        q = P((x, y), rooms["ala_oeste"]["r"] * 0.62, 45.0 + 90.0 * k)
        if not h.put(q, 0.9, 0.4):
            continue
        d.tube("harpa", gold, [(q[0] - 0.5, 0.1, q[1]), (q[0] - 0.4, 2.0, q[1]), (q[0] + 0.5, 1.6, q[1]), (q[0] + 0.55, 0.1, q[1])], 0.07, 0.06, 5)
        for i in range(5):
            d.box("harpa", d.m("harpa_corda", (0.9, 0.88, 0.8)), (q[0] - 0.3 + i * 0.18, q[1]), (0.02, 1.7 - i * 0.1, 0.02), 0.0, 0.12)
        d.box("harpa", gold, q, (1.3, 0.14, 0.4), 0.0, 0.0)
        d.solid(q[0], q[1], 1.3, 0.6, 2.0)
    x, y = rooms["ala_leste"]["pos"]
    for k in range(5):
        q = P((x, y), rooms["ala_leste"]["r"] * 0.6, 20.0 + 72.0 * k)
        if not h.put(q, 0.6, 0.4):
            continue
        d.cyl("estante", d.m("arara", WOOD_D), q, 0.04, 0.04, 1.3, 0.0, 4)
        d.box("estante", d.m("partitura", (0.92, 0.9, 0.84)), q, (0.6, 0.45, 0.04), 72.0 * k, 1.2, (-24, 0))
    # ---- sala de concerto: o órgão grande no fundo (na parede), bancadas no lado das bocas, estrado pintado no centro ----
    room = rooms["concerto"]
    x, y = room["pos"]
    r = room["r"]
    back = opposite(h, "concerto")
    tones = T["concerto"]
    d.blob("estrado", tones[0], (x, y), 3.4, 0.0224, 0.02, 32)
    near_back = lambda a: abs(math.atan2(math.sin(a - back), math.cos(a - back))) < 1.25
    _benches(d, h, "concerto", room, rows=((0.84, 0.45), (0.91, 0.9)), skip=near_back)
    n = 23
    for k in range(n):                                       # o órgão: tubos em V invertido ao longo da parede do fundo
        u = (k - (n - 1) * 0.5) / ((n - 1) * 0.5)
        a = back + u * 1.1
        p = P((x, y), r * 1.0, math.degrees(a))
        hh = 7.2 - 4.4 * abs(u)
        d.cyl("orgao", d.m("orgao_tubo", bl.OLD_GOLD) if k % 2 else d.m("orgao_tubo_esc", (0.66, 0.56, 0.36)), p, 0.34, 0.34, hh, 0.0, 6)
        d.cyl("orgao", d.m("orgao_tubo_esc", (0.66, 0.56, 0.36)), p, 0.4, 0.22, 0.4, hh, 6)
    cq = P((x, y), r * 0.9, math.degrees(back))
    d.box("orgao", d.m("orgao_console", WOOD_D), cq, (3.6, 1.3, 1.2), tang(back), 0.0)
    d.box("orgao", d.m("orgao_teclas", (0.94, 0.92, 0.86)), bl.loc(cq, tang(back), 0.0, 0.5), (3.0, 0.1, 0.4), tang(back), 1.0, (12, 0))
    bl.mask(d, "orgao", P((x, y), r * 0.96, math.degrees(back)), 5.4, tang(back), 1.6)
    d.solid(cq[0], cq[1], 3.6, 1.4, 1.4, tang(back))
    adds = [P((x, y), r * 0.55, math.degrees(back) + k) for k in (-135.0, -45.0, 45.0, 135.0)]
    for q in adds:
        d.blob("pouso", tones[1], q, 1.3, 0.0224, 0.03, 16)
    _hint(z, room, "boss_ressoa", clear_r=round(r * 0.8, 1), adds=adds, note="F2: 4 organ_pipe (lacaios parados) nos pontos `adds`")
    return d.flush()


# ----------------------------------------------------------------------------------------------------------------
# O Coração do Jardim (rift_heart, raide): limiar e a arena do Eco de Sylvaré
# ----------------------------------------------------------------------------------------------------------------
PETALS = [(0.96, 0.78, 0.84), (0.98, 0.9, 0.92), (0.86, 0.76, 0.94)]


def petal(d, p, a, hh, col, lean=24.0, g="petala"):
    d.cyl(g, d.m("petala_%d_%d" % (int(col[0] * 100), int(col[2] * 100)), col), p, 1.25, 0.0, hh, 0.0, 4, tang(a) + 45.0, (lean * 0.7, lean * 0.7))


def heart(z, rooms, edges):
    _floors(z, rooms)
    d = Dress(z, 707)
    rnd = d.rnd
    h = Halls(d, rooms, edges)
    T = {name: h.tones(name, 0.09) for name in rooms}
    for name, room in rooms.items():                        # espelho fosco: lascas largas em dois tons do próprio chão
        x, y = room["pos"]
        tones = T[name]
        for i in range(int(room["r"] * 2.2)):
            q = P((x, y), rnd.uniform(0.5, room["r"] * 0.84), rnd.uniform(0, 360))
            d.blob(name, tones[i % 2], q, rnd.uniform(1.2, 3.0), 0.0222 + (i % 2) * 0.0004, 0.12, rnd.randint(4, 6), sx=rnd.uniform(1.0, 1.6), rot=rnd.uniform(0, 180))
        for j, (p, a) in enumerate(h.rim(name, int(room["r"] * 1.9), 1.0, 1.04, 0.36)):      # borda de pétalas (na parede)
            petal(d, p, a, rnd.uniform(2.4, 3.6), PETALS[j % 3])
        for j, (p, a) in enumerate(h.rim(name, int(room["r"] * 1.3), 1.1, 1.16, 0.3)):
            petal(d, p, a, rnd.uniform(3.6, 5.0), PETALS[(j + 1) % 3], 30.0)

    def side(q, ang):
        if rnd.random() < 0.5:
            d.crystal(q, rnd.uniform(0.7, 1.1), (0.96, 0.86, 0.94))
        else:
            petal(d, q, ang, rnd.uniform(1.2, 2.0), PETALS[rnd.randrange(3)], 10.0)
    h.corridor(side, every=2.8)
    cx, cy = rooms["chegada"]["pos"]
    for s in (-1, 1):
        d.crystal((cx + s * 4.8, cy + 1.5), 1.4, (0.96, 0.86, 0.94))
    room = rooms["coracao"]
    x, y = room["pos"]
    r = room["r"]
    tones = T["coracao"]
    h.rings("coracao", tones, (0.3, 0.6, 0.88), y=RING_Y, w=0.3)
    back = opposite(h, "coracao")
    ped = [P((x, y), r * 0.6, math.degrees(back) + k) for k in (45.0, 135.0, 225.0, 315.0)]
    for q in ped:                                            # pousos dos 4 pedestais dos Sentidos (o lacaio é o pedestal)
        d.blob("pouso", tones[1], q, 2.0, 0.0224, 0.03, 20)
        d.blob("pouso", tones[0], q, 1.3, 0.0227, 0.03, 16)
    # a Coroa Vazia sobre o vestido de espelhos, no fundo (na parede: fora da luta)
    kq = P((x, y), r * 1.08, math.degrees(back))
    gold = d.m("coroa_ouro", bl.OLD_GOLD)
    for k in range(10):
        q = P(kq, 1.8, 36.0 * k)
        d.box("coroa", gold, q, (1.2, 0.5, 0.2), -36.0 * k + 90.0, 7.2)
        d.cyl("coroa", d.m("glow_coroa", (0.98, 0.92, 0.98)), q, 0.26, 0.0, 1.5, 7.7, 4)
    for k in range(7):                                       # o vestido: tiras de espelho fosco penduradas
        q = P(kq, 1.5, 180.0 + math.degrees(back) - 75.0 + 25.0 * k)
        d.cloth("coroa", d.m("pano_espelho", (0.82, 0.86, 0.92)), q, 0.8, 5.0 - abs(k - 3) * 0.5, tang(back), 2.0 + abs(k - 3) * 0.5, -0.4, "teeth")
    islands = [P((x, y), r * 0.5, math.degrees(back) + k) for k in (0.0, 120.0, 240.0)]
    _hint(z, room, "boss_sylvare_echo", clear_r=round(r * 0.96, 1), pedestals=ped, islands=islands, island_r=4.0,
          senses=["sense_sight", "sense_hearing", "sense_smell", "sense_taste"],
          note="F2: 4 pedestais (lacaios parados) em `pedestals`; F3: ilhas seguras (R-A invert) sugeridas em `islands`")
    return d.flush()


DRESS = {"dg_cellars": cellars, "dg_mirrors": mirrors, "dg_conservatory": conservatory, "rift_heart": heart}
