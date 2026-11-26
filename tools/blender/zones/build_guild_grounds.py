"""Campo de Caça da Guilda (`guild_grounds`, GDD design/gdd/arena-da-guilda.md §3.2): arena redonda de ~40 m no pátio de
treino da guilda. Quatro portões por onde as levas entram, seis pilares baixos para puxar, círculo de treino pintado.

    blender -b --factory-startup --python tools/blender/zones/run_zone.py -- build_guild_grounds <pasta_png> --export

CONTRATO com a sim (não mude sem combinar; tudo em coordenadas do jogo x, z; -z = norte):
  SPAWN_player_01 (0, 0) · SPAWN_gate_N (0, -20) · SPAWN_gate_E (20, 0) · SPAWN_gate_S (0, 20) · SPAWN_gate_W (-20, 0)
  TRIG_exit (0, 16) raio 1,5 · OB_circle_pillar_01..06 (raio 8-12, fora das linhas dos portões)
  Os mesmos nomes vão em `data["markers"]` do JSON (e `data["arena"]` traz o resumo: raio, portões, saída, pilares) e, como
  vazios, dentro do GLB. O muro é sólido em toda a volta; cada portão é um vão de 5,2 m que dá num nicho de 3,7 m fechado
  no fundo pela grade (colisor): a leva nasce no vão, ninguém sai. A grade de cada portão é uma peça à parte
  (`Z_guild_grounds_portao_<N|E|S|W>_grade`, origem no chão) para o jogo poder levantá-la.

Ângulos deste arquivo: graus do jogo, 0 = leste, 90 = sul, -90 = norte (x = r·cos, z = r·sin).

Pilha de planos do chão (mm): pátio 5,0 · caminhos do pátio 6,4 · areia da arena 8,0 · manchas da areia 10,0/10,8 ·
palha 12,0 · tinta do círculo de treino 14,0 · laje da saída 15,0/16,0. Tinta só em tons do próprio chão (floor_tones):
anel vivo, cheio ou brilhante é dos avisos de golpe.
"""
import math
import random
import bpy
import bmesh
from mathutils import Vector

import act2_dress
import nature
from dress import Dress
from zone_lib import Zone, B, mat, mat_c, disc

ZONE = "guild_grounds"
ARENA_R = 20.0             # chão da arena (contrato: ~40 m de diâmetro)
WALL_IN, WALL_OUT, WALL_H = 20.3, 21.7, 2.2
GATE_HALF = 2.6            # meio vão livre do portão
POST_W = 1.3               # pilar do portão (e parede do nicho)
NICHE_END = 24.6           # fundo do nicho atrás do portão
GRATE_R = 24.0             # grade (portcullis)
YARD_R = 37.0              # pátio de treino
OUTER_R = 38.0             # muralha do conjunto da guilda
GATES = {"N": -90.0, "E": 0.0, "S": 90.0, "W": 180.0}
EXIT = (0.0, 16.0)
EXIT_R = 1.5
# pilares baixos: dois de cada lado das linhas norte e sul, um a nordeste e um a sudoeste (≥ 3,3 m livres das linhas)
PILLARS = [(4.75, -8.23), (-4.75, -8.23), (4.75, 8.23), (-4.75, 8.23), (11.0, -4.0), (-11.0, 4.0)]
PILLAR_D, PILLAR_H = 1.7, 1.75

SAND = (0.80, 0.69, 0.50)
YARD = (0.67, 0.57, 0.42)
PATH = (0.74, 0.65, 0.50)
GRASS = (0.50, 0.66, 0.40)
STONE = (0.76, 0.71, 0.63)
STONE_D = (0.61, 0.56, 0.51)
STONE_L = (0.88, 0.84, 0.75)
WOOD = (0.56, 0.42, 0.28)
WOOD_D = (0.42, 0.31, 0.22)
WOOD_L = (0.70, 0.56, 0.38)
IRON = (0.30, 0.29, 0.32)
BLUE = (0.30, 0.42, 0.72)
GOLD = (0.96, 0.82, 0.44)
CREAM = (0.93, 0.89, 0.78)
ROOF = (0.74, 0.40, 0.33)
ROOF_D = (0.60, 0.31, 0.27)
TREES = [(0.34, 0.56, 0.34), (0.42, 0.62, 0.36), (0.5, 0.66, 0.36), (0.72, 0.6, 0.34)]


def P(r, deg):
    a = math.radians(deg)
    return (r * math.cos(a), r * math.sin(a))


def L(deg, radial, lateral=0.0):
    """Ponto no quadro do rumo `deg`: `radial` m para fora do centro, `lateral` m ao longo da tangente."""
    a = math.radians(deg)
    return (radial * math.cos(a) - lateral * math.sin(a), radial * math.sin(a) + lateral * math.cos(a))


def RR(deg):
    """rot que alinha o x local com o raio."""
    return -deg


def RT(deg):
    """rot que alinha o x local com a tangente."""
    return -deg - 90.0


def gate_gap(deg, r, half):
    """O rumo `deg` cai dentro de algum portão (meio vão `half` m no raio r)?"""
    for g in GATES.values():
        d = abs((deg - g + 180.0) % 360.0 - 180.0)
        if math.radians(d) * r < half:
            return True
    return False


# ---------------------------------------------------------------------------------------------------------------------
def floor(z, d):
    """Chão: pátio batido, areia da arena, manchas e o círculo de treino em tons da própria areia."""
    z.patch("patio", (0, 0), YARD_R, YARD, y=0.0050)
    z.patch("arena", (0, 0), ARENA_R + 0.5, SAND, y=0.0080)
    rnd = d.rnd
    # caminhos do pátio: de cada portão para fora e uma volta por trás das arquibancadas
    pm = d.m("patch_caminho", PATH)
    for name, g in GATES.items():
        pts = [Vector(L(g, NICHE_END - 0.4 + k * 1.6, math.sin(k * 0.9 + g) * 0.35)) for k in range(9)]
        d.strip("caminho", pm, pts, 4.4, 0.0064, 0.25)
    ring = [Vector(P(31.0 + math.sin(math.radians(a) * 5.0) * 0.5, a)) for a in range(0, 361, 6)]
    d.strip("caminho", pm, ring, 3.2, 0.0064, 0.3)
    # areia: manchas de 2 tons (pisoteio) e desgaste escuro nas bocas dos portões e no meio
    light, dark = tuple(min(1.0, c * 1.05) for c in SAND), tuple(c * 0.93 for c in SAND)      # pisoteio: só valor, sem puxar para o cinza
    tones = [d.m("patch_areia_clara", light), d.m("patch_areia_esc", dark)]
    for i in range(30):
        q = P(rnd.uniform(0.0, ARENA_R - 3.0), rnd.uniform(0, 360))
        d.blob("mancha", tones[i % 2], q, rnd.uniform(1.2, 2.8), 0.0100 + (i % 2) * 0.0008, 0.3, sx=rnd.uniform(1.0, 1.8), rot=rnd.uniform(0, 180))
    for g in GATES.values():
        for k in range(3):
            d.blob("mancha", tones[1], L(g, 18.6 - k * 2.2, rnd.uniform(-0.5, 0.5)), 1.9 - k * 0.45, 0.0108, 0.3, sx=1.3, rot=RR(g))
    # palha solta ao pé dos pilares
    straw = [d.m("patch_palha_a", (0.84, 0.74, 0.5)), d.m("patch_palha_b", (0.76, 0.66, 0.46))]
    for i, (x, zz) in enumerate(PILLARS):
        for k in range(3):
            a = rnd.uniform(0, 360)
            d.blob("palha", straw[(i + k) % 2], (x + math.cos(math.radians(a)) * 1.3, zz + math.sin(math.radians(a)) * 1.3),
                   rnd.uniform(0.5, 0.95), 0.0120, 0.4, sx=rnd.uniform(1.0, 1.6), rot=rnd.uniform(0, 180))
    # círculo de treino: tracejado, dois tons da areia (claro, escuro); nada cheio nem vivo
    t_light, t_dark = act2_dress.floor_tones(d, "arena", SAND, 0.15)
    for r, n, w in ((6.0, 12, 0.34), (15.5, 28, 0.26)):
        for j in range(n):
            a0 = math.tau * j / n + 0.05
            a1 = math.tau * (j + 1) / n - 0.05
            d.arc("treino", (t_light, t_dark)[j % 2], (0, 0), r, a0, a1, w, 0.0140, 0.15, 0.9)
    for k in range(8):                                    # raios curtos entre o miolo e o anel de dentro
        a = k * 45.0 + 22.5
        d.strip("treino", t_dark if k % 2 else t_light, [Vector(P(2.2, a)), Vector(P(3.4, a)), Vector(P(4.6, a))], 0.3, 0.0140)
    for k in range(4):                                    # cruz do meio: quatro losangos curtos
        a = k * 90.0 + 45.0
        d.strip("treino", t_light, [Vector(P(0.35, a)), Vector(P(0.95, a)), Vector(P(1.55, a))], 0.6, 0.0140, taper="point")
    for g in GATES.values():                              # marca de espera diante de cada portão
        for s in (-1, 1):
            d.strip("treino", t_dark, [Vector(L(g, 17.6, s * 0.5)), Vector(L(g, 17.6, s * 1.4)), Vector(L(g, 17.6, s * 2.3))], 0.26, 0.0140)
    # laje da saída: pedra rasa e uma seta para o portão sul (o brilho do portal é do jogo)
    slab_l, slab_d = act2_dress.floor_tone_colors(STONE, 0.08)
    d.blob("saida", d.m("patch_saida_esc", slab_d), EXIT, EXIT_R + 0.25, 0.0150, 0.04, 20)
    d.blob("saida", d.m("patch_saida", slab_l), EXIT, EXIT_R - 0.05, 0.0160, 0.04, 20)
    for k in range(2):
        zz = EXIT[1] - 0.25 + k * 0.6
        d.strip("saida", d.m("patch_saida_esc", slab_d), [Vector((-0.6, zz - 0.3)), Vector((0.0, zz + 0.3)), Vector((0.6, zz - 0.3))], 0.2, 0.0170)


def brazier_on(d, c, y0, s=1.0):
    """Braseiro baixo em cima do muro/pilar (o Dress.brazier só pousa no chão)."""
    iron = d.m("braseiro", (0.22, 0.2, 0.2))
    d.cyl("tocha", iron, c, 0.12 * s, 0.12 * s, 0.3 * s, y0, 5)
    d.cyl("tocha", iron, c, 0.3 * s, 0.5 * s, 0.32 * s, y0 + 0.3 * s, 8)
    d.cyl("tocha", d.m("glow_brasa", (1.0, 0.56, 0.2)), c, 0.4 * s, 0.0, 0.75 * s, y0 + 0.56 * s, 6)


def crest(d, c, rot, y0, s=1.0, g="brasao"):
    """Brasão da guilda: escudo azul de borda dourada com um sol/estrela dourado no meio (em pé, de frente para `rot`+90)."""
    d.cyl(g, d.m("brasao_ouro", GOLD), c, 0.62 * s, 0.62 * s, 0.1, y0, 8, rot, tilt=(90, 0))
    d.cyl(g, d.m("brasao_azul", BLUE), c, 0.5 * s, 0.5 * s, 0.14, y0, 8, rot, tilt=(90, 0))
    d.cyl(g, d.m("brasao_ouro", GOLD), c, 0.2 * s, 0.2 * s, 0.18, y0, 4, rot, tilt=(90, 0))


def arena_wall(z, d):
    """Muro baixo da arena (2,2 m: a câmera de cima vê a luta), contrafortes com braseiro, flâmulas na face de dentro."""
    stone, dark, cap = d.m("muro", STONE), d.m("muro_esc", STONE_D), d.m("muro_capa", STONE_L)
    rm = (WALL_IN + WALL_OUT) * 0.5
    thick = WALL_OUT - WALL_IN
    blue, gold = d.m("pano_guilda_azul", BLUE), d.m("pano_guilda_ouro", GOLD)
    blue_h, gold_h = d.m("pano_guilda_azul_barra", tuple(k * 0.8 for k in BLUE)), d.m("pano_guilda_ouro_barra", tuple(k * 0.8 for k in GOLD))
    a_post = math.degrees(math.asin((GATE_HALF + POST_W) / rm))        # onde o muro encosta no pilar do portão
    k = 0
    for g in sorted(GATES.values()):
        a0, a1 = g + a_post, g + 90.0 - a_post
        n = 14
        step = (a1 - a0) / n
        for i in range(n):
            am = a0 + step * (i + 0.5)
            seg = math.radians(step) * WALL_OUT + 0.06
            d.box("muro", dark, P(rm, am), (seg, 0.5, thick + 0.3), RT(am), 0.0)                 # rodapé
            d.box("muro", stone, P(rm, am), (seg, WALL_H - 0.25, thick), RT(am), 0.0)
            d.box("muro", cap, P(rm, am), (seg, 0.25, thick + 0.24), RT(am), WALL_H - 0.25)      # capa clara (lê de cima)
            if i % 2 == 0:                                                                       # ameias baixas, do lado de fora
                d.box("muro", stone, P(WALL_OUT - 0.3, am), (seg * 0.62, 0.42, 0.5), RT(am), WALL_H)
        # colisor: o arco inteiro, com sobra para dentro do pilar do portão
        c0, c1 = g + a_post - 2.2, g + 90.0 - a_post + 2.2
        m = 16
        cs = (c1 - c0) / m
        for i in range(m):
            am = c0 + cs * (i + 0.5)
            z.ob("wall", *P(rm + 0.1, am), (math.radians(cs) * (WALL_OUT + 0.4) + 0.3, WALL_H, thick + 0.4), RT(am), visible=False)
        # contrafortes com braseiro (3 por quadrante) e flâmulas entre eles
        mid = g + 45.0
        for j, off in enumerate((-22.0, 0.0, 22.0)):
            am = mid + off
            d.box("muro", stone, P(rm + 0.15, am), (1.3, WALL_H + 0.35, thick + 0.7), RT(am), 0.0)
            d.box("muro", cap, P(rm + 0.15, am), (1.5, 0.22, thick + 0.9), RT(am), WALL_H + 0.35)
            brazier_on(d, P(rm + 0.15, am), WALL_H + 0.57, 0.95)
        for j, off in enumerate((-33.0, -11.0, 11.0, 33.0)):
            am = mid + off
            w = 1.25
            c = L(am, WALL_IN - 0.07, -w * 0.5)
            cm, hm = ((blue, gold_h), (gold, blue_h))[(j + k) % 2]
            d.box("muro", d.m("ferro_esc", IRON), L(am, WALL_IN - 0.06, 0.0), (w + 0.3, 0.07, 0.07), RT(am), WALL_H - 0.36)
            d.cloth("flamula", cm, c, w, 1.35, RT(am) + 180.0, WALL_H - 0.36 - 1.35, 0.0, "swallow", hm)
        k += 1


def gate(z, d, name, g):
    """Portão: dois pilares, verga em arco com o brasão, nicho de 3,7 m e a grade no fundo (peça à parte + colisor)."""
    stone, dark, cap = d.m("muro", STONE), d.m("muro_esc", STONE_D), d.m("muro_capa", STONE_L)
    wood = d.m("portao_madeira", WOOD_D)
    rm = (WALL_IN + WALL_OUT) * 0.5
    lat = GATE_HALF + POST_W * 0.5
    for s in (-1, 1):
        c = L(g, rm + 0.1, s * lat)
        d.box("portao", dark, c, (2.3, 0.6, POST_W + 0.3), RR(g), 0.0)
        d.box("portao", stone, c, (2.0, 4.3, POST_W), RR(g), 0.0)
        d.box("portao", cap, c, (2.3, 0.26, POST_W + 0.3), RR(g), 4.3)
        d.cyl("portao", d.m("telha", ROOF), c, 1.05, 0.0, 0.8, 4.56, 4, RR(g) + 45.0)
        z.ob("wall", *c, (2.4, 4.3, POST_W + 0.1), RR(g), visible=False)
        # parede do nicho (mais baixa) e o colisor dela
        n0, n1 = WALL_OUT + 0.3, NICHE_END
        cn = L(g, (n0 + n1) * 0.5, s * lat)
        d.box("portao", stone, cn, (n1 - n0, 2.9, POST_W - 0.2), RR(g), 0.0)
        d.box("portao", cap, cn, (n1 - n0 + 0.1, 0.22, POST_W), RR(g), 2.9)
        z.ob("wall", *cn, (n1 - n0 + 0.4, 2.9, POST_W), RR(g), visible=False)
        # pilar do fundo, onde a grade corre
        cb = L(g, GRATE_R, s * lat)
        d.box("portao", stone, cb, (1.2, 3.9, POST_W), RR(g), 0.0)
        d.box("portao", cap, cb, (1.4, 0.24, POST_W + 0.2), RR(g), 3.9)
        brazier_on(d, cb, 4.14, 0.9)
        # mísula do arco
        d.box("portao", stone, L(g, rm + 0.1, s * (GATE_HALF - 0.35)), (1.5, 0.5, 0.7), RR(g), 3.25, tilt=(0, 0))
    # verga da frente (3,6 m livres embaixo) com o brasão para dentro da arena; trave do fundo em madeira
    d.box("portao", stone, L(g, rm + 0.1), (1.5, 0.75, GATE_HALF * 2 + 0.2), RR(g), 3.7)
    d.box("portao", cap, L(g, rm + 0.1), (1.8, 0.2, GATE_HALF * 2 + 0.6), RR(g), 4.45)
    crest(d, L(g, rm - 0.72), RT(g), 4.1, 0.9)
    d.box("portao", wood, L(g, GRATE_R), (0.7, 0.5, GATE_HALF * 2 + 0.3), RR(g), 3.45)
    z.ob("wall", *L(g, GRATE_R + 0.25), (GATE_HALF * 2 + POST_W * 2 + 0.4, 3.4, 1.0), RT(g), visible=False)
    # chão do nicho: laje escura (a boca de onde a leva sai)
    d.box("portao", d.m("patch_nicho", act2_dress.floor_tone_colors(STONE_D, 0.1)[1]), L(g, (WALL_IN + GRATE_R) * 0.5 + 0.2),
          (GRATE_R - WALL_IN + 0.6, 0.004, GATE_HALF * 2 + 0.1), RR(g), 0.0118)
    grate(z, name, g)


def grate(z, name, g):
    """Grade de ferro (portcullis) como objeto próprio, origem no chão do portão: o jogo pode subi-la."""
    bm = bmesh.new()
    a = math.radians(RT(g))
    ca, sa = math.cos(a), math.sin(a)

    def add(cx, y0, sx, h, sz):
        v = []
        for up in (y0, y0 + h):
            for ux, uz in ((-1, -1), (1, -1), (1, 1), (-1, 1)):
                lx, lz = cx + ux * sx * 0.5, uz * sz * 0.5
                v.append(bm.verts.new((lx * ca - lz * sa, lx * sa + lz * ca, up)))
        for f in ((0, 1, 2, 3), (7, 6, 5, 4), (0, 4, 5, 1), (1, 5, 6, 2), (2, 6, 7, 3), (3, 7, 4, 0)):
            bm.faces.new([v[i] for i in f])

    w = GATE_HALF * 2
    for i in range(8):                                    # barras em pé, com a ponta rente ao chão
        add(-w * 0.5 + w * (i + 0.5) / 8, 0.05, 0.13, 3.35, 0.13)
    for y in (0.55, 1.4, 2.25, 3.1):                      # travessas
        add(0.0, y, w, 0.16, 0.09)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    me = bpy.data.meshes.new("grade_mesh")
    bm.to_mesh(me)
    bm.free()
    me.materials.append(mat_c("ferro_grade", IRON))
    o = bpy.data.objects.new(z.P + "portao_%s_grade" % name, me)
    o.location = B(*L(g, GRATE_R))
    z.coll.objects.link(o)


def pillars(z, d):
    """Pilares baixos de pedra (1,75 m): cobertura para puxar a leva em volta. Faixa de pano da guilda em cada um."""
    stone, dark, cap = d.m("muro", STONE), d.m("muro_esc", STONE_D), d.m("muro_capa", STONE_L)
    for i, (x, zz) in enumerate(PILLARS):
        r = PILLAR_D * 0.5
        d.cyl("pilar", dark, (x, zz), r + 0.12, r + 0.04, 0.28, 0.0, 8, 22.5)
        d.cyl("pilar", stone, (x, zz), r - 0.1, r - 0.16, 1.2, 0.28, 8, 22.5)
        d.cyl("pilar", d.m("pano_pilar_azul" if i % 2 == 0 else "pano_pilar_ouro", BLUE if i % 2 == 0 else GOLD), (x, zz), r - 0.09, r - 0.11, 0.2, 0.95, 8, 22.5, cap=False)
        d.cyl("pilar", cap, (x, zz), r - 0.02, r + 0.04, 0.27, 1.48, 8, 22.5)
        z.ob("pillar", x, zz, (PILLAR_D, PILLAR_H, PILLAR_D), visible=False)


def stands(d):
    """Arquibancadas de madeira nos quatro quadrantes, por fora do muro: três degraus, panos nos assentos, flâmulas atrás."""
    wood, dark, light = d.m("arq_madeira", WOOD), d.m("arq_madeira_esc", WOOD_D), d.m("arq_tabua", WOOD_L)
    cloths = [d.m("arq_pano_azul", BLUE), d.m("arq_pano_ouro", GOLD), d.m("arq_pano_creme", CREAM), d.m("arq_pano_rosa", (0.86, 0.5, 0.48))]
    rnd = d.rnd
    for qi, mid in enumerate((-45.0, 45.0, 135.0, 225.0)):
        span, n = 26.0, 7
        for t in range(4):
            r = 23.5 + t * 1.25
            h = 0.55 + t * 0.6
            for i in range(n):
                am = mid - span + (2 * span) * (i + 0.5) / n
                seg = math.radians(2 * span / n) * (r + 0.6) + 0.04
                d.box("arquibancada", wood if (i + t) % 2 else dark, P(r, am), (seg, h, 1.25), RT(am), 0.0)
                d.box("arquibancada", light, P(r, am), (seg, 0.09, 1.1), RT(am), h)
                if rnd.random() < 0.42:
                    d.box("arquibancada", cloths[rnd.randrange(4)], P(r - 0.1, am), (seg * 0.55, 0.05, 0.8), RT(am), h + 0.09)
        rb = 23.5 + 4 * 1.25 - 0.45
        for i in range(n + 1):                                # guarda-corpo atrás
            am = mid - span + (2 * span) * i / n
            d.cyl("arquibancada", dark, P(rb, am), 0.09, 0.08, 3.35, 0.0, 5)
        for i in range(n):
            am = mid - span + (2 * span) * (i + 0.5) / n
            d.box("arquibancada", dark, P(rb, am), (math.radians(2 * span / n) * rb, 0.1, 0.08), RT(am), 3.15)
        for j, off in enumerate((-span - 3.0, 0.0, span + 3.0)):      # flâmulas da guilda: pontas e meio
            col = (BLUE, GOLD)[(j + qi) % 2]
            d.flag(P(29.0 if off == 0.0 else 26.2, mid + off), col, 5.4 if off == 0.0 else 4.6, RT(mid + off), pole=WOOD_D, tatter=False, w=1.3, drop=1.9)


def roof(d, c, sx, sz, rot, y0, pitch=34.0, color=ROOF, dark=ROOF_D):
    """Telhado de duas águas (cumeeira no x local) sobre uma caixa sx x sz com o topo em y0."""
    a = math.radians(rot)
    t = math.radians(pitch)
    Ls = (sz * 0.5 + 0.5) / math.cos(t)
    rise = math.tan(t) * sz * 0.5
    cm, dm = d.m("telha", color), d.m("telha_esc", dark)
    for s in (-1, 1):
        off = s * (sz * 0.25 + 0.12)
        q = (c[0] - off * math.sin(a) * -1.0 * -1.0, c[1] + off * math.cos(a))
        q = (c[0] + off * math.sin(a), c[1] + off * math.cos(a))
        d.box("telhado", cm, q, (sx + 0.8, 0.22, Ls), rot, y0 + rise * 0.5 - 0.1, tilt=(s * pitch, 0))
    d.box("telhado", dm, c, (sx + 1.0, 0.3, 0.5), rot, y0 + rise - 0.05)
    for e in (-1, 1):                                         # empenas: degraus de caixa
        for k in range(3):
            w = sz * (1.0 - (k + 0.5) / 3.0)
            q = (c[0] + e * (sx * 0.5 - 0.2) * math.cos(a), c[1] - e * (sx * 0.5 - 0.2) * math.sin(a))
            d.box("telhado", d.m("casa_parede", CREAM), q, (0.4, rise / 3.0 + 0.02, w), rot, y0 + rise * k / 3.0)


def house(d, c, sx, sz, rot, h, timber=True):
    wall, base, beam = d.m("casa_parede", CREAM), d.m("muro_esc", STONE_D), d.m("arq_madeira_esc", WOOD_D)
    d.box("casa", base, c, (sx + 0.2, 0.9, sz + 0.2), rot, 0.0)
    d.box("casa", wall, c, (sx, h, sz), rot, 0.0)
    if timber:
        d.box("casa", beam, c, (sx + 0.12, 0.22, sz + 0.12), rot, h * 0.52)
        d.box("casa", beam, c, (sx + 0.12, 0.22, sz + 0.12), rot, h - 0.22)
    roof(d, c, sx, sz, rot, h)


def yard(z, d):
    """Pátio de treino por fora do muro (só visual: ninguém chega lá): pátio do brasão ao norte, estande de tiro,
    bonecos, armeiro, tendas, tochas; muralha do conjunto com torres e a sede da guilda ao norte."""
    rnd = d.rnd
    stone, dark, cap = d.m("muro", STONE), d.m("muro_esc", STONE_D), d.m("muro_capa", STONE_L)
    # ---- pátio do brasão (norte): estrado de pedra, mastro com o estandarte, brasão em pé, braseiros ----
    cx, cz = P(31.0, -90.0)
    d.cyl("brasao", dark, (cx, cz), 3.6, 3.4, 0.22, 0.0, 12)
    d.cyl("brasao", cap, (cx, cz), 2.7, 2.6, 0.2, 0.22, 12)
    d.cyl("brasao", d.m("mastro_guilda", WOOD_D), (cx, cz), 0.16, 0.11, 7.2, 0.42, 6)
    d.cyl("brasao", d.m("brasao_ouro", GOLD), (cx, cz), 0.22, 0.0, 0.5, 7.62, 5)
    d.cloth("flamula", d.m("pano_guilda_azul", BLUE), (cx, cz), 2.3, 3.4, 0.0, 3.9, 0.1, "swallow", d.m("pano_guilda_ouro_barra", tuple(k * 0.8 for k in GOLD)))
    d.box("brasao", d.m("arq_madeira_esc", WOOD_D), (cx, cz + 2.2), (1.6, 1.5, 0.14), 0.0, 0.42, tilt=(-12, 0))
    crest(d, (cx, cz + 2.38), 0.0, 1.35, 1.0)
    for s in (-1, 1):
        d.brazier((cx + s * 2.9, cz + 1.6), 1.15)
        d.weapon_rack((cx + s * 5.6, cz - 0.4), 90.0 - s * 20.0)
    # ---- nordeste: estande de tiro (alvos em fila, fardos, cerca) ----
    for k in range(5):
        a = -66.0 + k * 9.0
        d.target(P(34.6, a), RT(a))
        if k % 2 == 0:
            d.hay(P(35.5, a + 4.0), 0.9)
    d.fence_run(P(30.2, -70.0), P(30.2, -50.0), 0.9, color=WOOD)
    d.fence_run(P(30.2, -50.0), P(30.2, -24.0), 0.9, color=WOOD)
    for k in range(3):
        d.weapon_rack(P(29.3, -62.0 + k * 13.0), RT(-62.0 + k * 13.0))
    # ---- sudeste: roda de bonecos de treino num cercado de palha ----
    sx_, sz_ = P(31.5, 45.0)
    d.blob("treino", d.m("patch_palha_a", (0.84, 0.74, 0.5)), (sx_, sz_), 4.4, 0.0072, 0.12)
    for k in range(6):
        q = (sx_ + math.cos(math.radians(k * 60.0)) * 2.6, sz_ + math.sin(math.radians(k * 60.0)) * 2.6)
        d.drill_post(q, k * 60.0 + 30.0, shield=(BLUE, GOLD)[k % 2], boss=GOLD if k % 2 == 0 else BLUE, crest=GOLD)
    for k in range(10):
        a0, a1 = k * 36.0, (k + 1) * 36.0
        if k in (6, 7):
            continue
        d.fence_run((sx_ + math.cos(math.radians(a0)) * 4.6, sz_ + math.sin(math.radians(a0)) * 4.6),
                    (sx_ + math.cos(math.radians(a1)) * 4.6, sz_ + math.sin(math.radians(a1)) * 4.6), 0.9, color=WOOD)
    d.weapon_rack(P(33.8, 22.0), RT(22.0))
    d.weapon_rack(P(33.8, 68.0), RT(68.0))
    d.cargo(P(34.0, 28.0), 5, 1.4)
    # ---- sudoeste: acampamento (pavilhões, fogueira, carga) ----
    for k, (r, a, s) in enumerate(((31.0, 122.0, 1.1), (33.4, 140.0, 0.95), (30.6, 156.0, 1.05))):
        d.tent_aurora(P(r, a), RR(a) + 90.0, s, trim=BLUE if k != 1 else (0.76, 0.42, 0.4), gold=GOLD)
    d.cookfire(P(29.4, 139.0), 1.0, 20.0)
    d.cargo(P(34.4, 112.0), 6, 1.6)
    d.hay(P(34.6, 160.0), 1.0)
    d.hay(P(35.2, 164.5), 0.85)
    # ---- noroeste: armeiro (toldo, bancada, cavaletes, carroça) ----
    ax, az = P(32.0, 225.0)
    d.awning((ax, az), 5.2, 3.4, RT(225.0), BLUE, 2.7, stripes=CREAM)
    d.box("armeiro", d.m("arq_madeira", WOOD), (ax, az), (3.6, 0.9, 1.0), RT(225.0), 0.0)
    d.box("armeiro", d.m("ferro_esc", IRON), P(30.6, 229.0), (0.7, 0.55, 0.4), RT(229.0), 0.0)        # bigorna
    d.cyl("armeiro", d.m("arq_madeira_esc", WOOD_D), P(30.6, 229.0), 0.42, 0.46, 0.5, 0.0, 7)
    for k in range(3):
        d.weapon_rack(P(34.6, 205.0 + k * 9.0), RT(205.0 + k * 9.0))
    d.cart(P(31.2, 246.0), 30.0, color=WOOD)
    d.cargo(P(34.4, 240.0), 5, 1.5)
    for a in (198.0, 252.0):
        d.barrel(P(29.6, a), 1.0)
        d.barrel(P(30.3, a + 1.6), 0.9)
    # ---- tochas do pátio: ao lado dos caminhos e na volta ----
    for g in GATES.values():
        for s in (-1, 1):
            d.torch(L(g, 27.6, s * 3.0), 2.5)
            d.torch(L(g, 34.6, s * 3.0), 2.5)
    for a in (-22.0, 22.0, 68.0, 112.0, 158.0, 202.0, 248.0, 292.0):
        d.torch(P(29.0, a), 2.4)
    # ---- muralha do conjunto (r 38): só visual; porta grande ao sul, torres de telhado vermelho ----
    n = 84
    for i in range(n):
        am = 360.0 * (i + 0.5) / n
        if abs((am - 90.0 + 180.0) % 360.0 - 180.0) < 6.5:
            continue
        seg = math.tau * (OUTER_R + 0.5) / n + 0.05
        d.box("muralha", dark, P(OUTER_R, am), (seg, 0.7, 1.4), RT(am), 0.0)
        d.box("muralha", stone, P(OUTER_R, am), (seg, 3.3, 1.1), RT(am), 0.0)
        d.box("muralha", cap, P(OUTER_R, am), (seg, 0.22, 1.3), RT(am), 3.3)
        if i % 2 == 0:
            d.box("muralha", stone, P(OUTER_R + 0.35, am), (seg * 0.6, 0.5, 0.45), RT(am), 3.52)
    for k in range(8):
        am = 22.5 + 45.0 * k
        c = P(OUTER_R + 0.2, am)
        d.cyl("muralha", stone, c, 2.1, 1.9, 5.6, 0.0, 8, 22.5)
        d.cyl("muralha", cap, c, 2.15, 2.15, 0.3, 5.6, 8, 22.5)
        d.cyl("muralha", d.m("telha", ROOF), c, 2.5, 0.0, 2.6, 5.9, 8, 22.5)
        if k % 2 == 0:
            d.cloth("flamula", d.m("pano_guilda_azul", BLUE), L(am, OUTER_R - 1.95, -0.55), 1.1, 2.2, RT(am) + 180.0, 2.6, 0.0, "swallow",
                    d.m("pano_guilda_ouro_barra", tuple(q * 0.8 for q in GOLD)))
    for s in (-1, 1):                                         # porta do conjunto (sul): dois pilares e a verga
        c = L(90.0, OUTER_R, s * 4.3)
        d.box("muralha", stone, c, (1.8, 5.0, 1.8), 0.0, 0.0)
        d.cyl("muralha", d.m("telha", ROOF), c, 1.6, 0.0, 1.4, 5.0, 4, 45.0)
        d.flag((c[0] + s * 1.6, c[1] + 1.6), GOLD if s > 0 else BLUE, 6.0, 90.0, pole=WOOD_D, tatter=False)
    d.box("muralha", d.m("arq_madeira_esc", WOOD_D), L(90.0, OUTER_R), (0.7, 0.6, 7.0), RR(90.0), 4.1)
    crest(d, L(90.0, OUTER_R - 0.5), RT(90.0), 4.4, 1.1)
    d.strip("caminho", d.m("patch_caminho", PATH), [Vector((math.sin(k * 0.7) * 0.8, 36.0 + k * 2.2)) for k in range(8)], 4.6, 0.0064, 0.25)
    # ---- sede da guilda (norte, por fora da muralha): salão comprido + duas alas; longe, alta sem tapar nada ----
    house(d, (0.0, -45.2), 20.0, 8.0, 0.0, 6.2)
    house(d, (-13.0, -42.6), 7.0, 6.0, 28.0, 4.6)
    house(d, (13.0, -42.6), 7.0, 6.0, -28.0, 4.6)
    d.cyl("casa", stone, (0.0, -45.2), 2.6, 2.4, 10.5, 0.0, 8, 22.5)                # torre do sino no meio do salão
    d.cyl("casa", d.m("telha", ROOF), (0.0, -45.2), 3.1, 0.0, 3.6, 10.5, 8, 22.5)
    d.cloth("flamula", d.m("pano_guilda_azul", BLUE), (-1.6, -40.95), 3.2, 4.2, 0.0, 1.6, 0.0, "swallow", d.m("pano_guilda_ouro_barra", tuple(q * 0.8 for q in GOLD)))
    crest(d, (0.0, -40.85), 0.0, 4.3, 1.5)
    # casinhas por fora (leste/oeste): telhados que fecham o quadro quando a câmera olha de lado
    for (a, r, sx, sz, h) in ((-28.0, 45.5, 7.0, 5.5, 4.0), (30.0, 45.0, 6.5, 5.0, 3.8), (152.0, 45.2, 7.0, 5.5, 4.0), (208.0, 45.5, 6.5, 5.0, 3.8)):
        house(d, P(r, a), sx, sz, RT(a), h)


def markers(z):
    """Vazios do contrato, DENTRO da Collection da zona (saem no GLB com o nome) e espelhados em data["markers"]."""
    out = {}

    def put(name, pos, kind="PLAIN_AXES", size=1.0, y=0.0, extra=None):
        e = bpy.data.objects.new(name, None)
        e.empty_display_type = kind
        e.empty_display_size = size
        e.location = B(pos[0], pos[1], y)
        z.coll.objects.link(e)
        out[name] = dict({"pos": [round(pos[0], 2), round(pos[1], 2)]}, **(extra or {}))

    put("SPAWN_player_01", (0.0, 0.0))
    for name, g in GATES.items():
        p = P(ARENA_R, g)
        put("SPAWN_gate_" + name, p, "ARROWS", 1.5, extra={"dir": [round(-math.cos(math.radians(g)), 3), round(-math.sin(math.radians(g)), 3)]})
    put("TRIG_exit", EXIT, "SPHERE", EXIT_R, extra={"radius": EXIT_R})
    for i, (x, zz) in enumerate(PILLARS):
        put("OB_circle_pillar_%02d" % (i + 1), (x, zz), "CIRCLE", PILLAR_D * 0.5, extra={"radius": PILLAR_D * 0.5, "height": PILLAR_H})
    z.data["markers"] = out
    z.data["arena"] = {
        "center": [0.0, 0.0], "radius": ARENA_R, "wall_inner": WALL_IN,
        "gates": {k: out["SPAWN_gate_" + k]["pos"] for k in GATES},
        "gate_half": GATE_HALF, "niche_depth": round(GRATE_R - 0.25 - WALL_IN, 2),
        "exit": {"pos": list(EXIT), "radius": EXIT_R},
        "pillars": [[x, zz, PILLAR_D * 0.5] for x, zz in PILLARS],
        "grates": {k: z.P + "portao_%s_grade" % k for k in GATES},
    }


def build(export=False, only=None):
    z = Zone(ZONE, size=120.0, rim=(53.0, 1.6, 1.0, 0.6), seed=41, spawn=(0.0, 0.0), palette={
        "road": PATH, "street": STONE, "cliff_rock": (0.66, 0.56, 0.5), "cliff_rock_d": (0.52, 0.43, 0.4),
        "cliff_grass": GRASS, "hill_grass": (0.58, 0.7, 0.42), "wood": WOOD, "banner": BLUE, "roof": ROOF,
    })
    d = Dress(z, 41)
    z.cam_game = (0.0, 0.0)
    floor(z, d)
    arena_wall(z, d)
    for name, g in GATES.items():
        gate(z, d, name, g)
    pillars(z, d)
    stands(d)
    yard(z, d)
    d.flush()
    # borda natural: anel de morros baixos e bosque entre a muralha e a encosta (props do jogo: árvore, moita, pedra)
    z.cliffs(snow=False)
    z.block((0, 0), OUTER_R + 3.0)
    for c, r in (((0.0, -45.2), 13.0), ((-13.0, -42.6), 6.5), ((13.0, -42.6), 6.5), ((0.0, 46.0), 5.0)):
        z.block(c, r)
    for (a, r) in ((-28.0, 45.5), (30.0, 45.0), (152.0, 45.2), (208.0, 45.5)):
        z.block(P(r, a), 6.0)
    z.scatter("tree", [((0, 0), 51.0, 70)], 0, (1.8, 4.2, 1.8), TREES, margin=2.5, spacing=3.8)
    nrnd = random.Random(46)
    obs = z.data["obstacles"]
    nature.fix_trees(obs, nrnd, pine_frac=0.25)
    for o in obs:                                 # patamares da encosta: pinheiro verde no lugar da árvore seca do anel sem neve
        if o["kind"] == "dead_tree":
            o["kind"] = "pine"
            o["color"] = list(nature.PINE_COLS[nrnd.randrange(len(nature.PINE_COLS))])
    nature.scatter(z.ob, lambda x, zz, m: z.free(x, zz, m, 0.0), nrnd, "bush", [((0, 0), 51.0, 40)], (1.5, 0.8, 1.5),
                   nature.BUSH_COLS, solid=False, margin=1.5, spacing=2.6, avoid=obs)
    markers(z)
    z.data["hangouts"] = []
    data = z.finish(export, poi=(0.0, -15.0), ground=GRASS)
    # os vazios OB_box_pillar_NNN que o Zone.markers cria para os 6 pilares somem: o nome do contrato é OB_circle_pillar_NN
    for o in list(z.sc.collection.objects):
        if o.name.startswith("OB_box_pillar_"):
            bpy.data.objects.remove(o, do_unlink=True)
    cd = bpy.data.cameras.new("CAM_exit")          # 4ª foto do loop: a saída, com o muro sul entre a câmera e o chão
    cd.lens_unit = "FOV"
    cd.angle = math.radians(56)
    cd.clip_start = 2.0
    co = bpy.data.objects.new("CAM_exit", cd)
    co.location = B(EXIT[0], EXIT[1], 0.8) + Vector((0, -math.cos(math.radians(52)) * 24, math.sin(math.radians(52)) * 24))
    co.rotation_euler = (math.radians(38), 0, 0)
    z.sc.collection.objects.link(co)
    tris = 0
    for o in z.coll.objects:
        if o.type == "MESH":
            tris += sum(len(p.vertices) - 2 for p in o.data.polygons)
    print("guild_grounds: %d objetos, %d triangulos, %d colisores" % (len(z.coll.objects), tris, sum(1 for o in data["obstacles"] if not o["visible"])))
    return data
