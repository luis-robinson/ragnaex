"""Campo da Guerra de Guildas (`gvg_field`, GDD design/gdd/guerra-de-guildas.md §3.3): dois castelos espelhados pelo
centro (norte e sul), campo com rio leste-oeste, duas pontes, ruínas e o reduto da bateria neutra no meio.

    blender -b --factory-startup --python tools/blender/zones/run_zone.py -- build_gvg_field <pasta_png> --export

CONTRATO com a sim (production/session-state/wave6-contract.md §1; não mude sem combinar; jogo x, z; -z = norte).
`<S>` = N ou S; o lado S é o N espelhado pelo centro: (x, z) -> (-x, -z).
  SPAWN_side_N (0, -54) · SPAWN_forward_N (0, -24.5) · TRIG_exit_N (0, -57) raio 1,5
  OBJ_gate_main_N (0, -30) vão 6 m · OBJ_gate_side_N (-38, -40) vão 4 m (os dois portões olham para o campo)
  OBJ_gate_rear_N (24, -51) vão 3 m: poterna dos fundos (EXTRA, fora do contrato; fechada vale como muro)
  OBJ_crystal_N (0, -48) · OBJ_cannon_N_01..04 (-14,-33) (14,-33) (-30,-37) (30,-37)
  OBJ_cannon_hill_01..02 (-6,-4) (6,4) · OBJ_ram_spawn_N_01..02 (-6,-18) (6,-18)
  BANNER_<S>_01..08: ponta do braço de cada mastro neutro (campo "y" = altura, "rot" = para onde o pano sai)
Tudo isso vai em `data["markers"]` (e como vazios dentro do GLB); `data["gvg"]` traz o resumo.
Portões: nós à parte `Z_gvg_field_gate_<main|side|rear>_<S>` (fechado) e `..._broken` (escombros; o JOGO esconde ao
carregar: o glTF não leva visibilidade), origem no chão, no centro do vão. Colisor de cada um: obstáculo oculto de
kind "gate" com "id": "gate_<main|side|rear>_<S>" (o mesmo pos/size/rot está em markers["OB_box_gate_..."]).

A sim é plana: a escada do salão é pintada (degraus de 1,5 cm) entre dois muretes em degrau, e o "morro" é um reduto de
terra (talude em anel com colisor, rampas ao norte e ao sul, miolo andável). O rio são dois trechos (oeste e leste) que
entram por bueiros no talude; cada um só tem vão na ponte (x = -45 e x = 45).

Pilha de planos do chão (mm): manchas do campo 1,8/2,6 · trilhas pintadas 4,2 · terreiro dos portões e calçamento do
pátio 5,0 · piso do reduto 5,6 · detalhe do calçamento 6,4 · estrada 12 (zone_lib) · rio 20 · degraus 20/35/50 · piso
do salão 50 · desenho do piso do salão 56/60 (tons do próprio piso: anel vivo é dos avisos de golpe).
"""
import math
import random
import bpy
import bmesh
from mathutils import Vector

import act2_dress
import nature
import build_guild_grounds as gg
from dress import Dress
from zone_lib import Zone, B, mat, mat_c, along

ZONE = "gvg_field"
RIM_X, RIM_Z = 103.0, 65.0          # meia-largura / meia-altura do vale (borda em "retângulo redondo")
WALL_H, WALL_T = 3.4, 2.2           # muralha: altura do adarve e espessura
MERLON = 0.7
GATE_MAIN = (0.0, -30.0, 6.0)       # centro (x, z) e vão; lado N
GATE_SIDE = (-38.0, -40.0, 4.0)
GATE_REAR = (24.0, -51.0, 3.0)
CRYSTAL = (0.0, -48.0)
SPAWN_SIDE = (0.0, -54.0)
SPAWN_FWD = (0.0, -24.5)
EXIT = (0.0, -57.0)
EXIT_R = 1.5
CANNONS = [(-14.0, -33.0), (14.0, -33.0), (-30.0, -37.0), (30.0, -37.0)]
HILL_CANNONS = [(-6.0, -4.0), (6.0, 4.0)]
RAMS = [(-6.0, -18.0), (6.0, -18.0)]
HALL = (-10.0, 10.0, -51.0, -41.0)  # x0, x1, z0 (fundo), z1 (frente)
STAIR_HALF = 3.0                    # escada: 6 m de vão
STAIR_Z = (-41.0, -38.0)
HILL_R_IN, HILL_R_OUT = 10.4, 12.8  # talude do reduto (colisor entre os dois raios)
RAMP_HALF = 3.0
BRIDGE_X = 45.0
RIVER_W = 7.0

GRASS = (0.46, 0.58, 0.36)          # = ground_color do catálogo (MapsCatalog._gvg_field) e de loading_art.ZONES
GRASS_L = (0.53, 0.65, 0.4)
GRASS_D = (0.41, 0.53, 0.34)
DIRT = (0.74, 0.65, 0.5)
DIRT_D = (0.66, 0.57, 0.44)
# Pedra em valor MÉDIO (2026-11-27). Medido no jogo (sol 1,1 + céu 0,75 + brilho 1,06): peça 3D do lote de cor no
# vértice sai bem mais clara que o número (0,62 -> 0,76 · 0,73 -> 0,84 · 0,80 -> 0,87; canal baixo sobe mais: 0,32 ->
# 0,55, e a cor desbota), enquanto mancha chata de chão (`patch_*`) sai no próprio número. A pedra antiga (0,78 / 0,90)
# estourava em branco, sem os 3 tons. Por isso: peça 3D ~0,15-0,2 ABAIXO do tom que se quer ver e mais saturada; base,
# corpo e capa com degraus largos (o sombreado do toon é fraco: o contraste vem da cor); mancha de chão no tom final.
STONE = (0.42, 0.375, 0.315)
STONE_D = (0.27, 0.24, 0.25)
STONE_L = (0.5, 0.455, 0.37)
STONE_B = (0.345, 0.31, 0.27)        # pedras salientes da cantaria (um tom abaixo do corpo)
SLIT = (0.12, 0.11, 0.14)           # seteira
PAVE = (0.63, 0.6, 0.54)            # mancha (sai como está)
PAVE_HALL = (0.66, 0.62, 0.55)      # tom VISTO do piso do salão: as manchas do desenho usam este
HALL_BOX = (0.5, 0.47, 0.41)        # a laje 3D do salão (sai ~PAVE_HALL)
STEP = (0.5, 0.47, 0.42)            # degrau pintado
SLAB = (0.6, 0.57, 0.52)            # laje da saída (mancha)
RUIN = (0.46, 0.46, 0.4)
RUIN_D = (0.33, 0.33, 0.32)
MOSS = (0.34, 0.48, 0.28)
WOOD = (0.56, 0.42, 0.28)
WOOD_D = (0.42, 0.31, 0.22)
WOOD_L = (0.7, 0.56, 0.38)
IRON = (0.3, 0.29, 0.32)
ROOF = (0.47, 0.52, 0.63)           # só a paleta do Zone (material `roof`, sem uso nas peças)
ROOF_D = (0.38, 0.42, 0.53)
CREAM = (0.93, 0.89, 0.78)
PLASTER = (0.66, 0.58, 0.44)        # reboco das casas e lona das tendas (o creme 0,93 estourava em branco)
# Identidade do lado (as mesmas cores do HUD, GvgUi.SIDE_COLORS, em pastel): telhados, flâmulas, panos das torres do
# portão, barra das tendas e escudos de treino. O estandarte da GUILDA continua vindo do jogo nos mastros neutros.
# `roof`/`paint` são peça 3D (número abaixo do tom visto); `cloth`/`hem` são material de pano (saem como estão).
SIDE_LOOK = {
    "N": {"roof": (0.17, 0.25, 0.46), "roof_d": (0.11, 0.17, 0.34), "paint": (0.16, 0.25, 0.5), "cloth": (0.26, 0.42, 0.76), "hem": (0.92, 0.8, 0.5)},
    "S": {"roof": (0.6, 0.2, 0.14), "roof_d": (0.43, 0.13, 0.11), "paint": (0.6, 0.17, 0.13), "cloth": (0.78, 0.28, 0.24), "hem": (0.92, 0.8, 0.5)},
}
HILL_ROCK = (0.46, 0.41, 0.36)      # talude do reduto e pedras do campo (o ROCK 0,64 fica só nos props do JSON)
HILL_EARTH = (0.42, 0.37, 0.26)
HILL_GRASS = (0.2, 0.4, 0.17)       # encosta de grama do reduto (3D): perto do capim do chão visto no jogo
HILL_GRASS_D = (0.16, 0.34, 0.15)
GABION = (0.5, 0.4, 0.26)
EARTH = (0.6, 0.56, 0.42)
ROCK = (0.64, 0.58, 0.52)
TREES = [(0.34, 0.56, 0.34), (0.42, 0.62, 0.36), (0.5, 0.66, 0.36), (0.62, 0.68, 0.38)]


def rim_r(a):
    """Borda do vale: superelipse 206 x 130 m com ondulação de harmônicos pares (igual dos dois lados do centro)."""
    c, s = abs(math.cos(a)), abs(math.sin(a))
    r = ((c / RIM_X) ** 4 + (s / RIM_Z) ** 4) ** -0.25
    return r + 1.1 * math.sin(4 * a + 1.0) + 0.8 * math.sin(6 * a + 0.4) + 0.5 * math.sin(10 * a)


class Side:
    """Desenha um castelo: tudo é dado nas coordenadas do castelo NORTE; sign = -1 espelha pelo centro (o do sul)."""

    def __init__(self, z, d, name):
        self.z, self.d, self.name = z, d, name
        self.k = 1.0 if name == "N" else -1.0
        self.rnd = d.rnd
        self.look = SIDE_LOOK[name]

    def side_m(self, key):
        """Cor do lado (`roof`, `roof_d`, `cloth`, `hem`) com nome próprio por castelo."""
        return self.d.m({"roof": "telha", "roof_d": "telha_esc", "cloth": "pano_lado", "hem": "pano_lado_barra"}[key] + "_" + self.name, self.look[key])

    def P(self, c):
        return (c[0] * self.k, c[1] * self.k)

    def R(self, rot):
        return rot if self.k > 0 else rot + 180.0

    def m(self, name, color):
        return self.d.m(name, color)

    def box(self, g, m, c, size, rot=0.0, y0=0.0, tilt=(0, 0)):
        self.d.box(g, m, self.P(c), size, self.R(rot), y0, tilt)

    def cyl(self, g, m, c, r0, r1, h, y0=0.0, segs=6, rot=0.0, tilt=(0, 0), jitter=0.0, cap=True):
        self.d.cyl(g, m, self.P(c), r0, r1, h, y0, segs, self.R(rot), tilt, jitter, cap)

    def cloth(self, g, m, c, w, drop, rot, y0, x0=0.0, tail="swallow", hem=None):
        self.d.cloth(g, m, self.P(c), w, drop, self.R(rot), y0, x0, tail, hem)

    def blob(self, g, m, c, r, y=0.0072, jitter=0.2, segs=None, sx=1.0, rot=0.0):
        self.d.blob(g, m, self.P(c), r, y, jitter, segs, sx, self.R(rot))

    def strip(self, g, m, pts, w, y=0.0074, wvar=0.0, taper=False):
        self.d.strip(g, m, [Vector(self.P(p)) for p in pts], w, y, wvar, taper)

    def rect(self, g, m, x0, x1, z0, z1, y):
        zm = (z0 + z1) * 0.5
        self.strip(g, m, [(x0, zm), (x1, zm)], abs(z1 - z0), y)

    def rock(self, g, m, c, r, y=0.0, squash=0.7, sx=1.0, rot=0.0, sub=1):
        self.d.rock(g, m, self.P(c), r, y, squash, sx, self.R(rot), sub)

    def ob(self, kind, x, zz, size, rot=0.0, **kw):
        p = self.P((x, zz))
        return self.z.ob(kind, p[0], p[1], size, self.R(rot) if rot else 0.0, **kw)

    def street(self, x, zz, r):
        p = self.P((x, zz))
        self.z.data["roads"].append({"kind": "street", "w": 0, "pts": [[round(p[0], 2), round(p[1], 2)]], "r": r})

    # adereços do Dress que só precisam de ponto (+ giro)
    def brazier(self, c, s=1.0):
        self.d.brazier(self.P(c), s)

    def torch(self, c, h=2.2):
        self.d.torch(self.P(c), h)

    def barrel(self, c, s=1.0):
        self.d.barrel(self.P(c), s)

    def crate(self, c, s=1.0, rot=0.0, y0=0.0):
        self.d.crate(self.P(c), s, self.R(rot), y0)

    def cargo(self, c, n=5, spread=1.6):
        self.d.cargo(self.P(c), n, spread)

    def hay(self, c, s=1.0):
        self.d.hay(self.P(c), s)

    def weapon_rack(self, c, rot):
        self.d.weapon_rack(self.P(c), self.R(rot))

    def cart(self, c, rot, **kw):
        self.d.cart(self.P(c), self.R(rot), **kw)

    def drill_post(self, c, rot, **kw):
        self.d.drill_post(self.P(c), self.R(rot), **kw)


# ---------------------------------------------------------------------------------------------------------------------
# peças do castelo
def masonry(s, a, t, nr, s0, s1, h, thick, rot):
    """Cantaria de um pano de muro: cordão a 58% da altura e pedras salientes (3 cm) nas duas faces, em fiadas
    desencontradas. Só caixas e conta fixa (nada de sorteio: a dispersão da zona não muda). Quebra a face lisa, que no
    toon caía inteira num tom só."""
    blk, cap = s.m("muro_pedra", STONE_B), s.m("muro_capa", STONE_L)
    ln = s1 - s0
    c = a + t * (s0 + s1) * 0.5
    s.box("muro", cap, c, (ln + 0.02, 0.14, thick + 0.14), rot, h * 0.58)
    n = max(1, int(ln / 1.9))
    for i in range(n):
        for row, (y, w) in enumerate(((0.62, 0.9), (h * 0.58 + 0.36, 0.7))):
            k = (i * 7 + row * 3 + int(abs(a.x) + abs(a.y))) % 5
            if k in (1, 4):
                continue
            u = s0 + ln * (i + 0.5 + (0.28 if row else -0.12)) / n
            if u - w * 0.5 < s0 + 0.1 or u + w * 0.5 > s1 - 0.1:
                continue
            s.box("muro", blk, a + t * u, (w, 0.42, thick + 0.06), rot, y + 0.12 * (k % 2))


def slits(s, c, half, h, y=None):
    """Seteiras nas quatro faces de uma torre quadrada (caixas escuras rasas)."""
    m = s.m("seteira", SLIT)
    y = h * 0.6 if y is None else y
    for dx, dz in ((0, -1), (1, 0), (0, 1), (-1, 0)):
        q = (c[0] + dx * (half - 0.02), c[1] + dz * (half - 0.02))
        s.box("torre", m, q, (0.22 if dx == 0 else 0.1, 0.95, 0.1 if dx == 0 else 0.22), 0.0, y)


def wall_run(s, a, b, lows=(), h=WALL_H, merlons=True, centre=(0.0, -42.0), collide=True, thick=WALL_T):
    """Pano de muralha de `a` a `b` (centro do muro). `lows` = pontos (x, z) onde o muro baixa a 1,4 m num trecho de
    4 m (canhoneira: o canhão do contrato fica logo atrás e atira por cima). Ameias do lado de fora (longe de `centre`)."""
    stone, dark, cap = s.m("muro", STONE), s.m("muro_esc", STONE_D), s.m("muro_capa", STONE_L)
    a, b = Vector(a), Vector(b)
    L = (b - a).length
    t = (b - a) / L
    rot = along(t.x, t.y)
    nr = Vector((-t.y, t.x))
    if nr.dot((a + b) * 0.5 - Vector(centre)) < 0:
        nr = -nr
    cuts = sorted((max(0.0, (Vector(p) - a).dot(t) - 2.0), min(L, (Vector(p) - a).dot(t) + 2.0)) for p in lows)
    parts, pos = [], 0.0
    for s0, s1 in cuts:
        if s0 - pos > 0.05:
            parts.append((pos, s0, False))
        parts.append((s0, s1, True))
        pos = s1
    if L - pos > 0.05:
        parts.append((pos, L, False))
    for s0, s1, low in parts:
        c = a + t * (s0 + s1) * 0.5
        ln = s1 - s0
        hh = 1.4 if low else h
        s.box("muro", dark, c, (ln + 0.02, 0.5, thick + 0.3), rot, 0.0)
        s.box("muro", stone, c, (ln + 0.02, hh, thick), rot, 0.0)
        s.box("muro", cap, c, (ln + 0.02, 0.22, thick + (0.0 if low else 0.24)), rot, hh)
        if not low and hh >= 2.5 and ln > 1.2:
            masonry(s, a, t, nr, s0, s1, hh, thick, rot)
        if low:                                     # canhoneira: duas bochechas em degrau fecham o corte
            for e in (s0, s1):
                q = a + t * e
                s.box("muro", stone, q, (0.5, (h + 1.4) * 0.5, thick + 0.1), rot, 0.0)
            continue
        if merlons and ln > 0.8:
            n = max(1, int(round(ln / 2.0)))
            for i in range(n):
                q = a + t * (s0 + ln * (i + 0.5) / n) + nr * (thick * 0.5 - 0.22)
                s.box("muro", stone, q, (ln / n * 0.56, MERLON, 0.5), rot, h + 0.22)
            for i in range(n):                      # guarda baixa do lado de dentro (lê o adarve de cima)
                q = a + t * (s0 + ln * (i + 0.5) / n) - nr * (thick * 0.5 - 0.12)
                s.box("muro", dark, q, (ln / n + 0.02, 0.26, 0.24), rot, h + 0.22)
    if collide:
        c = (a + b) * 0.5
        s.ob("wall", c.x, c.y, (L + 0.3, h, thick + 0.2), rot, visible=False)


def bastion(s, c, half, h, pole=None, solid=True, drape=False):
    """Torre quadrada baixa, aberta em cima (ameias nos quatro lados)."""
    stone, dark, cap = s.m("muro", STONE), s.m("muro_esc", STONE_D), s.m("muro_capa", STONE_L)
    w = half * 2
    s.box("torre", dark, c, (w + 0.4, 0.7, w + 0.4), 0.0, 0.0)
    s.box("torre", stone, c, (w, h, w), 0.0, 0.0)
    s.box("torre", cap, c, (w + 0.3, 0.24, w + 0.3), 0.0, h)
    s.box("torre", cap, c, (w + 0.14, 0.14, w + 0.14), 0.0, h * 0.5)                 # cordão
    blk = s.m("muro_pedra", STONE_B)
    for dx, dz in ((-1, -1), (1, -1), (1, 1), (-1, 1)):                              # cunhais: pedras de canto alternadas
        for k in range(int((h - 0.9) / 0.9)):
            if k % 2 == 0:
                s.box("torre", blk, (c[0] + dx * (half - 0.2), c[1] + dz * (half - 0.2)), (0.46, 0.4, 0.46), 0.0, 0.8 + k * 0.9)
    slits(s, c, half, h, h * 0.5 + 0.5)
    if drape:                                                                        # pano do lado, na face que olha o campo
        s.cloth("pano", s.side_m("cloth"), (c[0] - 0.8, c[1] + half + 0.07), 1.6, min(2.6, h * 0.46), 0.0, h - 0.25, 0.0, "swallow", s.side_m("hem"))
    for dx, dz in ((-1, -1), (1, -1), (1, 1), (-1, 1)):
        s.box("torre", stone, (c[0] + dx * (half - 0.3), c[1] + dz * (half - 0.3)), (0.9, MERLON, 0.9), 0.0, h + 0.24)
    for dx, dz in ((0, -1), (1, 0), (0, 1), (-1, 0)):
        s.box("torre", stone, (c[0] + dx * (half - 0.22), c[1] + dz * (half - 0.22)), (1.0 if dx == 0 else 0.5, MERLON * 0.8, 0.5 if dx == 0 else 1.0), 0.0, h + 0.24)
    if solid:
        s.ob("wall", c[0], c[1], (w + 0.2, h, w + 0.2), 0.0, visible=False)


def round_tower(s, c, r, h, roof=3.0, segs=10):
    """Torre redonda com chapéu de ardósia (o telhado que se lê de cima). Só longe dos portões e da escada."""
    stone, dark, cap = s.m("muro", STONE), s.m("muro_esc", STONE_D), s.m("muro_capa", STONE_L)
    s.cyl("torre", dark, c, r + 0.3, r + 0.15, 0.8, 0.0, segs, 18.0)
    s.cyl("torre", stone, c, r, r - 0.12, h, 0.0, segs, 18.0)
    s.cyl("torre", cap, c, r + 0.22, r + 0.22, 0.3, h, segs, 18.0)
    if roof > 0:
        s.cyl("torre", s.side_m("roof"), c, r + 0.5, 0.0, roof, h + 0.3, segs, 18.0)
        s.cyl("torre", s.side_m("roof_d"), c, r + 0.62, r + 0.4, 0.22, h + 0.24, segs, 18.0, cap=False)
        s.cyl("torre", s.m("mastro", WOOD_D), c, 0.07, 0.05, 1.9, h + 0.3 + roof - 0.2, 4)
        s.cloth("pendao", s.side_m("cloth"), c, 1.5, 0.75, 0.0, h + roof + 1.1, 0.05, "swallow", s.side_m("hem"))
    st = s.d.rnd.getstate()                         # peças novas de cilindro: devolve o sorteio (a dispersão não muda)
    s.cyl("torre", cap, c, r + 0.1, r + 0.1, 0.14, h * 0.55, segs, 18.0)
    s.d.rnd.setstate(st)
    for i in range(4):
        an = math.radians(45.0 + 90.0 * i)
        s.box("torre", s.m("seteira", SLIT), (c[0] + math.cos(an) * (r - 0.1), c[1] + math.sin(an) * (r - 0.1)), (0.2, 0.9, 0.2), -math.degrees(an), h * 0.55 + 0.5)
    s.ob("pillar", c[0], c[1], (2 * r, h, 2 * r), 0.0, visible=False)


def pole(s, banners, c, y0, h, rot, arm=1.1):
    """Mastro neutro com braço: o jogo pendura o estandarte da guilda na ponta do braço (vazio BANNER_<S>_NN)."""
    wood, gold = s.m("mastro", WOOD_D), s.m("mastro_ponta", (0.9, 0.8, 0.5))
    s.cyl("mastro", wood, c, 0.11, 0.08, h, y0, 5)
    s.cyl("mastro", gold, c, 0.15, 0.0, 0.34, y0 + h, 5)
    a = math.radians(rot)
    q = (c[0] + math.cos(a) * arm * 0.5, c[1] - math.sin(a) * arm * 0.5)
    s.box("mastro", wood, q, (arm, 0.09, 0.09), rot, y0 + h - 0.32)
    p = s.P(c)
    banners.append({"pos": [round(p[0], 2), round(p[1], 2)], "y": round(y0 + h - 0.32, 2), "rot": round(s.R(rot) % 360.0, 1)})


def roof(s, c, sx, sz, rot, y0, pitch):
    """Telhado de duas águas (o do build_guild_grounds.roof) nas cores do lado e com a empena no reboco da casa."""
    a = math.radians(rot)
    t = math.radians(pitch)
    Ls = (sz * 0.5 + 0.5) / math.cos(t)
    rise = math.tan(t) * sz * 0.5
    cm, dm = s.side_m("roof"), s.side_m("roof_d")
    for e in (-1, 1):
        off = e * (sz * 0.25 + 0.12)
        q = (c[0] + off * math.sin(a), c[1] + off * math.cos(a))
        s.box("telhado", cm, q, (sx + 0.8, 0.22, Ls), rot, y0 + rise * 0.5 - 0.1, tilt=(e * pitch, 0))
    s.box("telhado", dm, c, (sx + 1.0, 0.3, 0.5), rot, y0 + rise - 0.05)
    for e in (-1, 1):
        for k in range(3):
            w = sz * (1.0 - (k + 0.5) / 3.0)
            q = (c[0] + e * (sx * 0.5 - 0.2) * math.cos(a), c[1] - e * (sx * 0.5 - 0.2) * math.sin(a))
            s.box("telhado", s.m("casa_reboco", PLASTER), q, (0.4, rise / 3.0 + 0.02, w), rot, y0 + rise * k / 3.0)


def house(s, c, sx, sz, rot, h):
    wall, base, beam = s.m("casa_reboco", PLASTER), s.m("muro_esc", STONE_D), s.m("viga", WOOD_D)
    s.box("casa", base, c, (sx + 0.2, 0.9, sz + 0.2), rot, 0.0)
    s.box("casa", wall, c, (sx, h, sz), rot, 0.0)
    s.box("casa", beam, c, (sx + 0.12, 0.2, sz + 0.12), rot, h * 0.52)
    s.box("casa", beam, c, (sx + 0.12, 0.2, sz + 0.12), rot, h - 0.2)
    roof(s, c, sx, sz, rot, h, 32.0)
    s.ob("wall", c[0], c[1], (sx + 0.3, h, sz + 0.3), rot, visible=False)


def emplacement(s, c, face):
    """Praça do canhão (o canhão é entidade da sim): laje, cesto de balas e gabiões baixos dos lados. face = para onde atira."""
    pave = s.m("patch_canhao", act2_dress.floor_tone_colors(PAVE, 0.1)[1])
    s.blob("canhao", pave, c, 1.9, 0.0064, 0.08, 14)
    a = math.radians(face)
    fx, fz = math.cos(a), -math.sin(a)
    for e in (-1, 1):
        q = (c[0] - fz * e * 2.0, c[1] + fx * e * 2.0)
        s.cyl("canhao", s.m("gabiao", GABION), q, 0.5, 0.46, 0.8, 0.0, 7)
        s.cyl("canhao", s.m("gabiao_terra", HILL_EARTH), q, 0.42, 0.3, 0.16, 0.8, 7)
    q = (c[0] - fx * 1.5 - fz * 1.0, c[1] - fz * 1.5 + fx * 1.0)
    for i, (dx, dz, yy) in enumerate(((0, 0, 0), (0.3, 0, 0), (0.15, 0.26, 0), (0.15, 0.09, 0.22))):
        s.rock("canhao", s.m("bala", IRON), (q[0] + dx, q[1] + dz), 0.15, yy - 0.02, 1.0)


# ---------------------------------------------------------------------------------------------------------------------
class Mini:
    """Malha própria (portão): caixas num quadro local com a origem no chão, no centro do vão."""

    def __init__(self):
        self.bm = bmesh.new()
        self.mats = []

    def box(self, m, c, size, rot=0.0, y0=0.0, tilt=(0, 0)):
        if m not in self.mats:
            self.mats.append(m)
        f = Dress._xf(c, rot, tilt)
        hx, hz, h = size[0] * 0.5, size[2] * 0.5, size[1]
        v = [self.bm.verts.new(f(sx * hx, sz * hz, up, y0)) for up in (0, h) for sx, sz in ((-1, -1), (1, -1), (1, 1), (-1, 1))]
        for a, b, cc, dd in ((0, 1, 2, 3), (7, 6, 5, 4), (0, 4, 5, 1), (1, 5, 6, 2), (2, 6, 7, 3), (3, 7, 4, 0)):
            self.bm.faces.new((v[a], v[b], v[cc], v[dd])).material_index = self.mats.index(m)

    def obj(self, z, name, pos, turn):
        bmesh.ops.recalc_face_normals(self.bm, faces=self.bm.faces[:])
        me = bpy.data.meshes.new(name + "_mesh")
        self.bm.to_mesh(me)
        self.bm.free()
        for m in self.mats:
            me.materials.append(m)
        o = bpy.data.objects.new(name, me)
        o.location = B(pos[0], pos[1])
        o.rotation_euler = (0, 0, math.radians(turn))
        z.coll.objects.link(o)
        return o


def gate_nodes(z, s, kind, centre, width, h):
    """Portão fechado (duas folhas de tábuas com ferragens e tranca) e o quebrado (folhas no chão, lascas nos cantos, meio
    livre). Os dois têm a origem no chão no centro do vão; no castelo sul o nó gira 180 graus."""
    wood = [mat_c("portao_madeira", WOOD), mat_c("portao_madeira_esc", WOOD_D), mat_c("portao_madeira_clara", WOOD_L)]
    iron = mat_c("portao_ferro", IRON)
    half = width * 0.5
    name = "gate_%s_%s" % (kind, s.name)
    g = Mini()
    n = max(4, int(round(width / 0.5)))
    for i in range(n):
        x = -half + width * (i + 0.5) / n
        top = h - 0.25 * abs(x) / half
        g.box(wood[(i * 2 + (i // 3)) % 3], (x, 0.0), (width / n - 0.03, top, 0.34), 0.0, 0.04)
    for y in (0.5, h * 0.5, h - 0.75):
        for e in (-1, 1):
            g.box(iron, (e * half * 0.5, 0.0), (half - 0.16, 0.2, 0.44), 0.0, y)
    g.box(wood[1], (0.0, 0.26), (width * 0.72, 0.3, 0.26), 0.0, h * 0.42)          # tranca (do lado de dentro)
    g.box(iron, (0.0, 0.0), (0.14, h - 0.3, 0.46), 0.0, 0.04)                       # batente do meio
    for e in (-1, 1):
        for y in (0.9, h - 1.1):
            g.box(iron, (e * 0.5, -0.2), (0.3, 0.3, 0.1), 0.0, y)                   # aldravas
    g.obj(z, z.P + name, s.P(centre), 0.0 if s.k > 0 else 180.0)
    b = Mini()
    rnd = random.Random(len(name) * 31 + int(width * 7))
    # uma folha caída para dentro (deitada, rente ao chão), a outra em pedaços encostados no canto
    b.box(wood[0], (-half * 0.52, 2.3), (half * 0.9, 0.12, h * 0.8), rnd.uniform(-14, 14), 0.02, (rnd.uniform(-3, 3), rnd.uniform(-3, 3)))
    b.box(iron, (-half * 0.52, 2.3), (half * 0.94, 0.14, 0.2), rnd.uniform(-14, 14), 0.03)
    for i in range(3):
        b.box(wood[i % 3], (half - 0.3 - i * 0.24, 0.1 + i * 0.2), (0.4, h * (0.8 - i * 0.2), 0.3), rnd.uniform(-10, 10), 0.0, (rnd.uniform(-10, 10), -18.0 - i * 9.0))
    b.box(wood[1], (-half + 0.3, -0.1), (0.42, h * 0.55, 0.3), 6.0, 0.0, (8.0, 14.0))
    for i in range(12):                                                              # lascas e pedras: longe do meio
        e = -1 if i % 2 else 1
        x = e * rnd.uniform(half * 0.45, half + 0.6)
        zz = rnd.uniform(-2.6, 3.2)
        if i % 3 == 0:
            b.box(mat_c("portao_pedra", STONE_D), (x, zz), (rnd.uniform(0.3, 0.6), rnd.uniform(0.18, 0.36), rnd.uniform(0.3, 0.5)), rnd.uniform(0, 90), 0.0, (rnd.uniform(-12, 12), rnd.uniform(-12, 12)))
        else:
            b.box(wood[i % 3], (x, zz), (rnd.uniform(0.8, 1.6), 0.09, 0.2), rnd.uniform(0, 180), 0.02, (0, rnd.uniform(-6, 6)))
    b.box(iron, (half * 0.3, 1.5), (half * 0.7, 0.07, 0.16), 35.0, 0.02)
    o = b.obj(z, z.P + name + "_broken", s.P(centre), 0.0 if s.k > 0 else 180.0)
    o["gvg_hidden"] = True
    p = s.P(centre)
    col = z.ob("gate", p[0], p[1], (width + 0.4, h, WALL_T + 0.2), 0.0, visible=False)
    col["id"] = name
    return name, col


# ---------------------------------------------------------------------------------------------------------------------
def castle(z, d, name, out):
    s = Side(z, d, name)
    stone, dark, cap = s.m("muro", STONE), s.m("muro_esc", STONE_D), s.m("muro_capa", STONE_L)
    banners = []
    gx, gz, gw = GATE_MAIN
    # ---- chão: calçamento do pátio, terreiro diante do portão, grama fora ----
    pave = s.m("patch_patio", PAVE)
    p_l, p_d = act2_dress.floor_tone_colors(PAVE, 0.07)
    pl, pd = s.m("patch_patio_claro", p_l), s.m("patch_patio_esc", p_d)
    s.rect("patio", pave, -33.0, 37.0, -50.0, -35.0, 0.0050)
    s.rect("patio", pave, -19.6, 19.6, -35.0, -31.0, 0.0050)
    s.rect("patio", pave, -43.0, -33.0, -50.0, -41.0, 0.0050)
    s.rect("patio", pave, gx - 3.0, gx + 3.0, -31.0, -28.6, 0.0050)                 # soleira do portão principal
    s.rect("patio", pave, -40.0, -36.0, -41.0, -38.6, 0.0050)
    for x, zz, r in ((-24, -43, 9.5), (-6, -40, 9.5), (12, -40, 9.5), (28, -43, 9.5), (-38, -45.5, 5.5), (0, -47, 7.5), (0, -33.5, 4.5), (-14, -33.5, 4.0), (14, -33.5, 4.0), (-28, -37.5, 3.6), (30, -37.5, 3.6), (22, -47.5, 4.0), (-17, -47.5, 4.0)):
        s.street(x, zz, r)
    rnd = d.rnd
    for i in range(34):                                     # lajes soltas de 2 tons no pátio
        x, zz = rnd.uniform(-32.0, 36.0), rnd.uniform(-49.5, -35.5)
        if HALL[0] - 1.5 < x < HALL[1] + 1.5 and zz < STAIR_Z[1] + 0.5:
            continue
        s.blob("patio", (pl, pd)[i % 2], (x, zz), rnd.uniform(0.7, 1.5), 0.0064, 0.1, 6, sx=rnd.uniform(1.0, 1.6), rot=rnd.choice((0.0, 90.0)))
    # caminho gasto do portão à escada e ao portão lateral
    s.strip("patio", pd, [(gx, -31.0), (0.0, -34.5), (0.0, STAIR_Z[1])], 3.4, 0.0064, 0.2)
    s.strip("patio", pd, [(-38.0, -41.2), (-37.0, -44.5), (-28.0, -44.0), (-14.0, -38.5), (-3.5, -36.5)], 2.6, 0.0064, 0.25)
    dirt = s.m("patch_terreiro", DIRT)
    s.blob("terreiro", dirt, (0.0, -22.5), 8.6, 0.0050, 0.12, sx=1.7)
    s.blob("terreiro", s.m("patch_terreiro_esc", DIRT_D), (0.0, -27.0), 3.6, 0.0056, 0.14, sx=1.3)
    s.street(0.0, -23.0, 9.0)
    s.street(-9.0, -22.0, 6.0)
    s.street(9.0, -22.0, 6.0)
    s.blob("terreiro", dirt, (-38.0, -36.0), 4.2, 0.0050, 0.14, sx=1.2)
    s.street(-38.0, -36.5, 4.4)
    # ---- muralha da frente + portão principal ----
    wall_run(s, (-19.4, -30.0), (-7.0, -30.0), lows=[CANNONS[0]])
    wall_run(s, (7.0, -30.0), (19.4, -30.0), lows=[CANNONS[1]])
    for e in (-1, 1):                                       # torres do portão: 5,6 m, abertas em cima, sem verga (nada sobre o vão)
        bastion(s, (e * 5.0, -30.0), 2.0, 5.2, drape=True)
        s.box("portao", dark, (e * 3.05, -30.0), (0.3, 3.6, 1.2), 0.0, 0.0)          # batente
        s.torch((e * 4.2, -27.5), 2.4)
        pole(s, banners, (e * 5.0, -30.0), 5.44, 2.6, 90.0 - e * 90.0)
        bastion(s, (e * 22.0, -32.0), 2.6, 4.6, drape=True)
        pole(s, banners, (e * 22.0, -32.0), 4.84, 2.4, 90.0 - e * 90.0)
    out["gates"]["main_" + name] = gate_nodes(z, s, "main", (gx, gz), gw, 3.5)
    # ---- alas (recuadas 4 m) ----
    wall_run(s, (-32.3, -34.0), (-24.6, -34.0), lows=[(-30.0, -34.0)])
    wall_run(s, (24.6, -34.0), (35.2, -34.0), lows=[(30.0, -34.0)])
    bastion(s, (-34.0, -34.0), 1.7, 4.2)
    round_tower(s, (38.0, -34.0), 2.9, 6.6, 3.2)
    wall_run(s, (38.0, -48.3), (38.0, -36.8))
    # ---- recuo do portão lateral (olha para o campo, 6 m atrás da ala) ----
    sx_, sz_, sw = GATE_SIDE
    wall_run(s, (-34.0, -41.1), (-34.0, -35.6))
    wall_run(s, (-42.3, -40.0), (-40.9, -40.0), merlons=False)
    for x in (sx_ - sw * 0.5 - 0.55, sx_ + sw * 0.5 + 0.5):
        s.box("portao", dark, (x, -40.0), (1.3, 0.6, WALL_T + 0.5), 0.0, 0.0)
        s.box("portao", stone, (x, -40.0), (1.1, 4.0, WALL_T + 0.3), 0.0, 0.0)
        s.box("portao", cap, (x, -40.0), (1.3, 0.24, WALL_T + 0.5), 0.0, 4.0)
        s.ob("wall", x, -40.0, (1.2, 4.0, WALL_T + 0.3), 0.0, visible=False)
        s.torch((x, -38.2), 2.2)
    bastion(s, (-44.0, -40.0), 1.8, 4.2)
    out["gates"]["side_" + name] = gate_nodes(z, s, "side", (sx_, sz_), sw, 3.0)
    wall_run(s, (-44.0, -48.4), (-44.0, -41.7))
    # ---- fundos + poterna ----
    rx, rz, rw = GATE_REAR
    wall_run(s, (-41.4, -51.0), (rx - rw * 0.5, -51.0), h=3.0)
    wall_run(s, (rx + rw * 0.5, -51.0), (35.3, -51.0), h=3.0)
    round_tower(s, (38.0, -51.0), 2.7, 5.4, 2.8)
    round_tower(s, (-44.0, -51.0), 2.7, 5.4, 2.8)
    out["gates"]["rear_" + name] = gate_nodes(z, s, "rear", (rx, rz), rw, 2.7)
    # ---- salão do trono: aberto em cima (a câmera vê o Cristal), paredes baixas, colunas ----
    hx0, hx1, hz0, hz1 = HALL
    hall_m = s.m("salao_piso", HALL_BOX)
    s.box("salao", hall_m, ((hx0 + hx1) * 0.5, (hz0 + hz1) * 0.5 + 0.55), (hx1 - hx0 - 1.0, 0.05, hz1 - hz0 - 1.1), 0.0, 0.0)
    t_l, t_d = act2_dress.floor_tone_colors(PAVE_HALL, 0.1)
    tl, td = s.m("patch_salao_claro", t_l), s.m("patch_salao_esc", t_d)
    s.strip("salao", td, [(0.0, hz1 - 0.2), (0.0, CRYSTAL[1] + 2.6)], 3.0, 0.056)            # passadeira (tom do piso)
    s.strip("salao", tl, [(0.0, hz1 - 0.2), (0.0, CRYSTAL[1] + 2.6)], 2.2, 0.060)
    for j in range(12):                                     # anel tracejado em volta do Cristal, 2 tons do piso
        a0 = math.tau * j / 12 + 0.06
        a1 = math.tau * (j + 1) / 12 - 0.06
        pts = [Vector(s.P((CRYSTAL[0] + math.cos(a0 + (a1 - a0) * k / 4) * 3.3, CRYSTAL[1] + math.sin(a0 + (a1 - a0) * k / 4) * 3.3))) for k in range(5)]
        d.strip("salao", (tl, td)[j % 2], pts, 0.34, 0.060)
    s.cyl("salao", dark, CRYSTAL, 2.3, 2.2, 0.06, 0.05, 12)                                    # estrado raso do Cristal
    s.cyl("salao", cap, CRYSTAL, 1.8, 1.7, 0.05, 0.11, 12)
    for e in (-1, 1):
        # paredes laterais (2,6 m) e a frente em balaustrada (1,5 m), vão de 6 m na escada
        wall_run(s, (e * 10.0, hz0 + 1.1), (e * 10.0, hz1 + 0.5), h=2.6, merlons=False, centre=(0.0, -46.0), thick=1.0)
        a, b = (e * STAIR_HALF, hz1), (e * 10.5, hz1)
        c = ((a[0] + b[0]) * 0.5, hz1)
        ln = abs(b[0] - a[0])
        s.box("salao", dark, c, (ln, 0.4, 1.1), 0.0, 0.0)
        s.box("salao", stone, c, (ln, 1.5, 0.8), 0.0, 0.0)
        s.box("salao", cap, c, (ln + 0.1, 0.2, 1.0), 0.0, 1.5)
        s.ob("wall", c[0], c[1], (ln + 0.2, 1.5, 1.0), 0.0, visible=False)
        for k, x in enumerate((STAIR_HALF + 0.6, 6.6, 10.0)):   # colunas da frente
            s.cyl("salao", stone, (e * x, hz1), 0.5, 0.42, 3.4, 0.0, 8, 22.5)
            s.cyl("salao", cap, (e * x, hz1), 0.62, 0.62, 0.24, 3.4, 8, 22.5)
        pole(s, banners, (e * (STAIR_HALF + 0.6), hz1), 3.64, 2.4, 90.0 - e * 90.0)
        for zc in (-44.5, -48.5):                               # colunas de dentro (cobertura para quem segura o salão)
            s.cyl("salao", dark, (e * 6.4, zc), 0.66, 0.6, 0.3, 0.05, 8, 22.5)
            s.cyl("salao", stone, (e * 6.4, zc), 0.5, 0.44, 3.0, 0.35, 8, 22.5)
            s.cyl("salao", cap, (e * 6.4, zc), 0.64, 0.64, 0.24, 3.35, 8, 22.5)
            s.ob("pillar", e * 6.4, zc, (1.2, 3.4, 1.2), 0.0, visible=False)
        # torreões dos cantos do fundo (telhado que se lê de cima; atrás do Cristal para a câmera do norte)
        s.cyl("torre", stone, (e * 10.0, hz0), 1.5, 1.4, 5.6, 0.0, 8, 22.5)
        s.cyl("torre", cap, (e * 10.0, hz0), 1.7, 1.7, 0.26, 5.6, 8, 22.5)
        s.cyl("torre", s.side_m("roof"), (e * 10.0, hz0), 2.0, 0.0, 2.6, 5.86, 8, 22.5)
        s.ob("pillar", e * 10.0, hz0, (3.0, 5.6, 3.0), 0.0, visible=False)
        pole(s, banners, (e * 4.6, hz0 + 0.9), 3.0, 2.6, 90.0 - e * 90.0, 1.2)
        s.brazier((e * 8.2, -42.6), 1.1)
        # ---- escada: muretes em degrau (o vão de 6 m é o gargalo) ----
        for k in range(3):
            zc = STAIR_Z[0] + 0.5 + k
            hh = 1.5 - k * 0.45
            q = (e * (STAIR_HALF + 0.6), zc)
            s.box("escada", stone, q, (1.2, hh, 1.02), 0.0, 0.0)
            s.box("escada", cap, q, (1.3, 0.16, 1.06), 0.0, hh)
        s.ob("wall", e * (STAIR_HALF + 0.6), (STAIR_Z[0] + STAIR_Z[1]) * 0.5, (1.2, 1.5, 3.0), 0.0, visible=False)
        s.brazier((e * (STAIR_HALF + 0.6), STAIR_Z[1] + 0.8), 1.0)
    # parede do fundo do salão: um pouco mais alta que o muro, com nicho atrás do Cristal
    s.box("salao", stone, (0.0, hz0 + 0.3), (17.0, 3.6, 0.5), 0.0, 0.0)
    s.box("salao", cap, (0.0, hz0 + 0.3), (17.2, 0.22, 0.7), 0.0, 3.6)
    s.box("salao", dark, (0.0, hz0 + 0.62), (4.4, 3.0, 0.3), 0.0, 0.0)
    for k in range(3):                                      # degraus pintados: cada um 1,5 cm acima do outro
        zc = STAIR_Z[1] - 0.5 - k
        s.box("escada", s.m("degrau", STEP), (0.0, zc), (STAIR_HALF * 2, 0.02 + k * 0.015, 1.0), 0.0, 0.0)
        s.rect("escada", s.m("patch_degrau_esc", act2_dress.floor_tone_colors(PAVE_HALL, 0.12)[1]), -STAIR_HALF, STAIR_HALF, zc + 0.38, zc + 0.5, 0.021 + k * 0.015)
    s.street(0.0, -39.5, 3.6)
    # ---- canhões da muralha: praça de cada um ----
    for i, c in enumerate(CANNONS):
        emplacement(s, c, 270.0)
    # ---- pátio: casas baixas encostadas no muro (telhados), treino, carga ----
    house(s, (33.6, -43.6), 5.0, 8.0, 0.0, 2.9)             # caserna (leste)
    house(s, (-26.0, -48.0), 9.0, 3.6, 0.0, 2.7)            # arsenal (fundos, oeste)
    house(s, (16.6, -48.2), 6.0, 3.2, 0.0, 2.6)             # estábulo (fundos, leste)
    s.weapon_rack((-20.0, -45.2), 0.0)
    s.weapon_rack((-23.5, -45.2), 0.0)
    for k in range(3):
        s.drill_post((24.0 + k * 2.4, -38.6), 90.0, shield=s.look["paint"], boss=IRON)
    s.cargo((-30.5, -37.6), 4, 1.2)
    s.cargo((29.6, -47.0), 5, 1.4)
    s.hay((13.2, -45.6), 1.0)
    s.hay((14.4, -45.2), 0.85)
    s.barrel((-17.6, -32.2), 1.0)
    s.barrel((-18.3, -33.0), 0.9)
    s.barrel((18.0, -32.4), 1.0)
    s.cart((-39.5, -46.8), 70.0, color=WOOD)
    for c in ((-12.0, -36.4), (12.0, -36.4), (-33.0, -44.0), (30.0, -40.0)):
        s.torch(c, 2.4)
    # ---- fundos: largo do renascer, laje da saída ----
    s.blob("terreiro", dirt, SPAWN_SIDE, 5.2, 0.0050, 0.12, sx=1.9)
    s.street(SPAWN_SIDE[0], SPAWN_SIDE[1] - 1.0, 6.5)
    s.street(-8.0, SPAWN_SIDE[1], 5.0)
    s.street(8.0, SPAWN_SIDE[1], 5.0)
    slab_l, slab_d = act2_dress.floor_tone_colors(SLAB, 0.08)
    s.blob("saida", s.m("patch_saida_esc", slab_d), EXIT, EXIT_R + 0.25, 0.0060, 0.04, 20)
    s.blob("saida", s.m("patch_saida", slab_l), EXIT, EXIT_R - 0.05, 0.0068, 0.04, 20)
    for e in (-1, 1):
        s.d.tent_aurora(s.P((e * 9.5, -56.2)), s.R(90.0 + e * 16.0), 0.95, color=PLASTER, trim=s.look["paint"], gold=(0.8, 0.66, 0.36))
        s.torch((e * 4.0, -53.0), 2.4)
    s.cargo((14.5, -55.0), 4, 1.2)
    # trilhas pintadas: dos fundos pelos dois flancos até a frente
    tr = s.m("patch_trilha", DIRT)
    s.strip("trilha", tr, [(4.0, -54.5), (22.0, -55.5), (40.0, -53.0), (45.5, -43.0), (43.0, -30.0), (36.0, -21.0), (24.0, -20.5)], 2.6, 0.0042, 0.35, taper=True)
    s.strip("trilha", tr, [(-4.0, -54.5), (-24.0, -55.5), (-45.0, -54.5), (-50.5, -45.0), (-48.0, -37.0)], 2.6, 0.0042, 0.35, taper=True)
    out["banners"][name] = banners


def hill(z, d, out):
    """Reduto da bateria neutra: talude em anel (colisor), rampas ao norte e ao sul, miolo calçado e andável."""
    earth, rock, rock_l = d.m("talude_terra", HILL_EARTH), d.m("talude_pedra", HILL_ROCK), d.m("talude_capa", tuple(min(1.0, c * 1.12) for c in HILL_ROCK))
    grass = d.m("talude_grama", HILL_GRASS_D)
    rm = (HILL_R_IN + HILL_R_OUT) * 0.5
    gap = math.degrees(math.asin((RAMP_HALF + 0.3) / rm))
    n = 40
    rnd = d.rnd
    for i in range(n):
        am = 360.0 * (i + 0.5) / n
        if min(abs((am - g + 180.0) % 360.0 - 180.0) for g in (90.0, 270.0)) < gap + 180.0 / n - 1.0:
            continue
        seg = math.tau * (HILL_R_OUT + 1.2) / n + 0.1
        p = lambda r: (r * math.cos(math.radians(am)), r * math.sin(math.radians(am)))
        hh = 1.25 + 0.35 * math.sin(i * 1.7)
        d.box("reduto", earth, p(rm + 0.5), (seg * 0.96, 1.0, 2.3), -am - 90.0, 0.0)
        d.box("reduto", rock, p(rm - 0.35), (seg * 0.86, hh, 1.5), -am - 90.0, 0.0)
        d.box("reduto", rock_l, p(rm - 0.35), (seg * 0.8, 0.18, 1.3), -am - 90.0, hh)
        if i % 3 == 0:
            d.cyl("reduto", d.m("gabiao", GABION), p(rm + 0.4), 0.55, 0.5, 0.8, 1.0, 7)
        if i % 4 == 1:
            d.rock("reduto", rock, p(HILL_R_OUT + 2.2 + rnd.uniform(0, 1.0)), rnd.uniform(0.5, 0.9), 0.0, 0.7)
    # encosta de grama por fora (o "morro"): rampa de 0 a 1 m em 3,8 m, aberta nas rampas e nos bueiros
    slope = d.m("talude_encosta", HILL_GRASS)
    r_top, r_bot, y_top, m2 = HILL_R_OUT + 0.5, HILL_R_OUT + 4.3, 1.0, 56
    for i in range(m2):
        a0, a1 = math.tau * i / m2, math.tau * (i + 1) / m2
        am = (a0 + a1) * 0.5
        if abs(math.cos(am)) * r_top < RAMP_HALF + 1.5 or abs(math.sin(am)) * r_top < RIVER_W * 0.5 + 1.3:
            continue
        bm = d._bm("reduto", slope, math.cos(am) * r_bot, math.sin(am) * r_bot)
        k = 1.0 + 0.05 * math.sin(i * 2.1)
        q = [bm.verts.new(B(math.cos(a) * r, math.sin(a) * r, y)) for a, r, y in
             ((a0, r_bot * k, 0.0), (a1, r_bot * k, 0.0), (a1, r_top, y_top), (a0, r_top, y_top), (a0, r_top, 0.0), (a1, r_top, 0.0))]
        bm.faces.new((q[0], q[1], q[2], q[3]))
        bm.faces.new((q[0], q[3], q[4]))
        bm.faces.new((q[1], q[5], q[2]))
        bm = d._bm("reduto", grass, math.cos(am) * r_bot, math.sin(am) * r_bot)
        q = [bm.verts.new(B(math.cos(a) * r, math.sin(a) * r, y_top)) for a, r in ((a0, r_top), (a1, r_top), (a1, rm + 0.3), (a0, rm + 0.3))]
        bm.faces.new(q)
    # colisor do anel: arcos entre as rampas
    for g0 in (90.0, 270.0):
        a0, a1 = g0 + gap, g0 + 180.0 - gap
        m = 14
        cs = (a1 - a0) / m
        for i in range(m):
            am = a0 + cs * (i + 0.5)
            z.ob("wall", rm * math.cos(math.radians(am)), rm * math.sin(math.radians(am)),
                 (math.radians(cs) * HILL_R_OUT + 0.4, 1.6, HILL_R_OUT - HILL_R_IN), -am - 90.0, visible=False)
    # rampas: pilares de pedra e tocha de cada lado, terra batida no vão
    for g0, e in ((270.0, -1), (90.0, 1)):
        for sd in (-1, 1):
            c = (sd * (RAMP_HALF + 0.75), e * rm)
            d.box("reduto", rock, c, (1.3, 2.0, HILL_R_OUT - HILL_R_IN + 0.5), 0.0, 0.0)
            d.box("reduto", rock_l, c, (1.45, 0.2, HILL_R_OUT - HILL_R_IN + 0.7), 0.0, 2.0)
            z.ob("wall", c[0], c[1], (1.4, 2.0, HILL_R_OUT - HILL_R_IN + 0.4), 0.0, visible=False)
            d.torch((sd * (RAMP_HALF + 0.75), e * (HILL_R_OUT + 1.0)), 2.3)
        d.strip("reduto", d.m("patch_rampa", DIRT_D), [Vector((0.0, e * (HILL_R_IN - 1.5))), Vector((0.0, e * rm)), Vector((0.0, e * (HILL_R_OUT + 3.4)))], RAMP_HALF * 2 - 0.2, 0.0060, 0.12)
    # miolo: piso de pedra, canal coberto do rio (lajes com grelhas), praças dos dois canhões
    floor_c = (0.7, 0.67, 0.6)
    d.blob("reduto", d.m("patch_reduto", floor_c), (0.0, 0.0), HILL_R_IN + 0.2, 0.0056, 0.02, 40)
    f_l, f_d = act2_dress.floor_tone_colors(floor_c, 0.08)
    fl, fd = d.m("patch_reduto_claro", f_l), d.m("patch_reduto_esc", f_d)
    d.strip("reduto", fd, [Vector((-HILL_R_IN, 0.0)), Vector((HILL_R_IN, 0.0))], 3.4, 0.0064)
    for k in range(-4, 5):
        d.strip("reduto", fl, [Vector((k * 2.2 - 0.95, 0.0)), Vector((k * 2.2 + 0.95, 0.0))], 2.9, 0.0072)
    water = d.m("patch_grelha", (0.36, 0.56, 0.72))
    for x in (-5.5, 0.0, 5.5):
        d.strip("reduto", water, [Vector((x - 0.6, 0.0)), Vector((x + 0.6, 0.0))], 1.3, 0.0080)
        for j in range(-2, 3):
            d.box("reduto", d.m("ferro_esc", IRON), (x + j * 0.26, 0.0), (0.07, 0.05, 1.36), 0.0, 0.0)
    for e in (-1, 1):                                       # bueiros: boca escura por onde o rio entra/sai do talude
        d.box("reduto", d.m("bueiro", (0.2, 0.22, 0.28)), (e * (HILL_R_OUT + 0.5), 0.0), (1.6, 1.0, 3.4), 0.0, 0.0)
        d.box("reduto", rock_l, (e * (HILL_R_OUT + 0.4), 0.0), (2.2, 0.4, 4.6), 0.0, 1.0)
        for sd in (-1, 1):
            d.box("reduto", rock, (e * (HILL_R_OUT + 0.5), sd * 2.1), (2.0, 1.5, 0.9), 0.0, 0.0)
    side_n = Side(z, d, "N")
    for c, face in ((HILL_CANNONS[0], 270.0), (HILL_CANNONS[1], 90.0)):
        emplacement(side_n, c, face)
    banners = []
    for i, (c, rot) in enumerate((((-7.6, 4.6), 0.0), ((7.6, -4.6), 180.0))):   # dois mastros neutros: quem toma o reduto
        pole(side_n, banners, c, 0.0, 4.6, rot, 1.2)
    d.cargo((3.4, -6.6), 4, 1.1)
    d.cargo((-3.4, 6.6), 4, 1.1)
    z.data["roads"].append({"kind": "street", "w": 0, "pts": [[0.0, 0.0]], "r": HILL_R_OUT + 1.6})
    out["banners"]["hill"] = banners


def ruin_wall(z, d, c, ln, rot, h, broken=0.5):
    """Toco de muro em ruína (cobertura): corpo em 2-3 degraus, tampo musgoso, pedras caídas. Colisor de caixa."""
    rnd = d.rnd
    body, dark, moss = d.m("ruina", RUIN), d.m("ruina_esc", RUIN_D), d.m("ruina_musgo", MOSS)
    a = math.radians(rot)
    ux, uz = math.cos(a), -math.sin(a)
    n = max(2, int(round(ln / 1.5)))
    d.box("ruina", dark, c, (ln + 0.3, 0.4, 1.4), rot, 0.0)
    for i in range(n):
        t = (i + 0.5) / n - 0.5
        hh = h * (1.0 - broken * abs(math.sin(i * 2.3 + c[0])) * (0.4 + 0.6 * (i / max(1, n - 1))))
        q = (c[0] + ux * t * ln, c[1] + uz * t * ln)
        d.box("ruina", body, q, (ln / n + 0.02, hh, 1.0), rot, 0.0)
        d.box("ruina", moss if i % 2 else dark, q, (ln / n * 0.9, 0.12, 0.84), rot, hh)
    for i in range(3):
        q = (c[0] + ux * rnd.uniform(-0.6, 0.6) * ln + rnd.uniform(-1.3, 1.3), c[1] + uz * rnd.uniform(-0.6, 0.6) * ln + rnd.uniform(-1.3, 1.3))
        d.rock("ruina", body, q, rnd.uniform(0.22, 0.42), 0.0, 0.6)
    z.ob("wall", c[0], c[1], (ln + 0.2, h, 1.2), rot, visible=False)


def ruin_column(z, d, c, h):
    body, dark = d.m("ruina", RUIN), d.m("ruina_esc", RUIN_D)
    d.cyl("ruina", dark, c, 0.75, 0.68, 0.35, 0.0, 8, 22.5)
    d.cyl("ruina", body, c, 0.5, 0.45, h, 0.35, 8, 22.5)
    if h > 2.4:
        d.cyl("ruina", dark, c, 0.66, 0.66, 0.26, 0.35 + h, 8, 22.5)
    z.ob("pillar", c[0], c[1], (1.3, h + 0.35, 1.3), 0.0, visible=False)


# ruínas da metade norte (a do sul é o espelho pelo centro): (tipo, x, z, comprimento ou altura, giro, altura)
RUINS = [
    ("w", -23.0, -12.5, 5.0, 0.0, 2.2), ("w", -25.8, -10.0, 3.8, 90.0, 1.6), ("c", -19.5, -9.6, 2.9, 0, 0),
    ("w", 20.0, -12.0, 4.6, 20.0, 2.0), ("w", 24.5, -9.0, 3.4, 110.0, 1.5), ("c", 17.2, -8.2, 1.4, 0, 0),
    ("w", -36.2, -7.6, 3.6, 80.0, 1.6), ("w", -55.0, -7.4, 4.2, 100.0, 1.7),
    ("w", 36.2, -7.6, 3.6, 100.0, 1.6), ("w", 55.0, -7.4, 4.2, 80.0, 1.7),
    ("w", -67.0, -17.0, 5.4, 15.0, 2.3), ("w", -70.6, -13.6, 3.6, 105.0, 1.7), ("c", -63.0, -13.0, 3.1, 0, 0), ("c", -66.5, -10.4, 1.2, 0, 0),
    ("w", 63.0, -18.0, 6.0, -15.0, 2.2), ("w", 68.4, -14.0, 3.8, 60.0, 1.5), ("c", 60.4, -13.2, 2.6, 0, 0),
    ("w", 78.0, -3.2 - 6.5, 4.4, 5.0, 1.6), ("w", -80.0, -9.5, 4.4, -5.0, 1.6),
]


def field(z, d, out):
    rnd = d.rnd
    # manchas largas do campo (2 tons) e estrada
    d.mottle([("campo_claro", GRASS_L), ("campo_esc", GRASS_D)], [((0, 0), 95.0, 150)], y=0.0018, rmin=3.0, rmax=8.0, step=0.0008)
    d.road_edges(DIRT_D, 1.3, 0.4)
    d.roadside(d.m("seixo", (0.7, 0.67, 0.6)), d.m("capim", (0.44, 0.62, 0.36)), 6.0)
    # trilha do meio: do terreiro de cada portão à rampa do reduto
    tr = d.m("patch_trilha", DIRT)
    for e in (-1, 1):
        d.strip("trilha", tr, [Vector((0.0, e * 16.5)), Vector((0.6 * e, e * 19.0)), Vector((0.0, e * 22.0))], 3.0, 0.0042, 0.3)
    # ruínas (e o espelho)
    for kind, x, zz, a, rot, h in RUINS:
        for e in (1, -1):
            if kind == "w":
                ruin_wall(z, d, (x * e, zz * e), a, rot, h)
            else:
                ruin_column(z, d, (x * e, zz * e), a)
    # piso velho das ruínas maiores: lajes soltas no tom da pedra, baixas
    slab = d.m("patch_ruina_piso", (0.66, 0.67, 0.56))
    for c in ((-23.0, -11.0), (21.5, -10.5), (-66.5, -14.0), (64.0, -15.5)):
        for e in (1, -1):
            for k in range(5):
                d.blob("ruina", slab, (c[0] * e + rnd.uniform(-3, 3), c[1] * e + rnd.uniform(-2.4, 2.4)), rnd.uniform(0.6, 1.2), 0.0042, 0.12, 6, sx=1.3, rot=rnd.choice((0.0, 90.0)))
    # pontes: cabeceiras de pedra e tochas
    for bx in (-BRIDGE_X, BRIDGE_X):
        for e in (-1, 1):
            for sd in (-1, 1):
                c = (bx + sd * 3.0, e * 6.4)
                d.box("ponte", d.m("ruina_esc", RUIN_D), c, (1.0, 0.4, 1.0), 0.0, 0.0)
                d.box("ponte", d.m("muro", STONE), c, (0.8, 1.3, 0.8), 0.0, 0.0)
                d.box("ponte", d.m("muro_capa", STONE_L), c, (0.95, 0.16, 0.95), 0.0, 1.3)
                z.ob("pillar", c[0], c[1], (0.9, 1.4, 0.9), 0.0, visible=False)
            d.torch((bx + 3.0, e * 7.6), 2.3)
    # pedras e flores no campo aberto
    stone_m = d.m("pedra_campo", HILL_ROCK)
    for p in d.spots([((0, 0), 96.0, 46)], r=1.0, spacing=9.0, road=2.5, water=2.0, blocked=True):
        d.rock("campo3d", stone_m, p, rnd.uniform(0.35, 0.8), 0.0, 0.62, sx=rnd.uniform(1.0, 1.5), rot=rnd.uniform(0, 180))
        d.pebbles("campo3d", stone_m, p, 3, 1.3)
    cols = [d.m("flor_branca", (0.96, 0.95, 0.88)), d.m("flor_amarela", (0.98, 0.86, 0.46)), d.m("flor_lilas", (0.78, 0.68, 0.92))]
    for i, p in enumerate(d.spots([((0, 0), 96.0, 90)], r=0.8, spacing=6.0, road=1.0, water=1.0, blocked=True)):
        for _ in range(rnd.randint(3, 6)):
            q = (p[0] + rnd.uniform(-1.2, 1.2), p[1] + rnd.uniform(-1.2, 1.2))
            d.tuft("campo", d.m("capim", (0.44, 0.62, 0.36)), q, 0.3, 0.55, 4)
            d.cyl("campo", cols[i % 3], q, 0.11, 0.0, 0.16, 0.42, 4)
    # juncos e pedras na margem do rio (fora das pontes)
    reed = d.m("junco", (0.5, 0.64, 0.38))
    for poly in z.rivers:
        for i in range(2, len(poly) - 2, 3):
            p = poly[i]
            if abs(abs(p.x) - BRIDGE_X) < 7.0 or abs(p.x) < HILL_R_OUT + 3.0 or abs(p.x) > 96.0:
                continue
            e = 1 if (i // 3) % 2 else -1
            q = (p.x + rnd.uniform(-0.8, 0.8), p.y + e * (RIVER_W * 0.5 + 0.5))
            d.tuft("rio3d", reed, q, 0.5, 1.1, 6)
            if i % 2 == 0:
                d.rock("rio3d", stone_m, (q[0] + 0.9, q[1] + e * 0.4), rnd.uniform(0.25, 0.5), 0.0, 0.6)
    # estacas diante das rampas do reduto (só visual, baixas)
    for e in (-1, 1):
        for sd in (-1, 1):
            d.spikes((sd * 13.5, e * 19.6), sd * e * 24.0, 3.0)


# aríete 01 do norte (pela ponte oeste); o 02 é o espelho em x
RAM_ROUTE = [(-6.0, -18.0), (-10.0, -22.4), (-15.0, -22.6), (-33.0, -16.0), (-41.5, -11.5), (-45.0, -9.0), (-45.0, 0.0), (-45.0, 9.0), (-41.5, 11.5),
             (-33.0, 16.0), (-15.0, 22.6), (-5.0, 24.6), (0.0, 26.6)]


def in_castle(x, zz, pad=0.0):
    """Dentro (ou colado) de um dos castelos, do largo dos fundos ou do terreiro do portão?"""
    for e in (1, -1):
        px, pz = x * e, zz * e
        if -47.0 - pad < px < 41.5 + pad and -53.0 - pad < pz < -28.0 + pad:
            return True
        if abs(px) < 16.0 + pad and -62.0 < pz < -50.0:
            return True
        if abs(px) < 16.0 + pad and -30.0 < pz < -14.0 + pad:
            return True
    return False


def markers(z, out):
    """Vazios do contrato, DENTRO da Collection da zona (saem no GLB com o nome) e espelhados em data["markers"]."""
    mk = {}

    def put(name, pos, kind="PLAIN_AXES", size=1.0, y=0.0, extra=None):
        e = bpy.data.objects.new(name, None)
        e.empty_display_type = kind
        e.empty_display_size = size
        e.location = B(pos[0], pos[1], y)
        if extra and "rot" in extra:
            e.rotation_euler = (0, 0, math.radians(extra["rot"]))      # estandarte: o x local aponta para onde o pano sai
        z.coll.objects.link(e)
        mk[name] = dict({"pos": [round(pos[0], 2), round(pos[1], 2)]}, **(extra or {}))

    for name, k in (("N", 1.0), ("S", -1.0)):
        P = lambda c: (c[0] * k, c[1] * k)
        put("SPAWN_side_" + name, P(SPAWN_SIDE), "ARROWS", 1.5, extra={"dir": [0.0, k]})
        put("SPAWN_forward_" + name, P(SPAWN_FWD), "ARROWS", 1.5, extra={"dir": [0.0, -k]})
        put("TRIG_exit_" + name, P(EXIT), "SPHERE", EXIT_R, extra={"radius": EXIT_R})
        for kind, g in (("main", GATE_MAIN), ("side", GATE_SIDE), ("rear", GATE_REAR)):
            gname, col = out["gates"]["%s_%s" % (kind, name)]
            extra = {"width": g[2], "node": z.P + gname, "node_broken": z.P + gname + "_broken", "collider": "OB_box_" + gname, "dir": [0.0, k if kind != "rear" else -k]}
            if kind == "rear":
                extra["extra"] = True
            put("OBJ_gate_%s_%s" % (kind, name), P(g[:2]), "CUBE", 1.0, extra=extra)
            e = bpy.data.objects.new("OB_box_" + gname, None)
            e.empty_display_type = "CUBE"
            e.location = B(col["pos"][0], col["pos"][1], col["size"][1] / 2)
            e.scale = (col["size"][0] / 2, col["size"][2] / 2, col["size"][1] / 2)
            z.coll.objects.link(e)
            mk["OB_box_" + gname] = {"pos": list(col["pos"]), "size": list(col["size"]), "rot": col["rot"], "id": gname}
        put("OBJ_crystal_" + name, P(CRYSTAL), "SPHERE", 1.2)
        for i, c in enumerate(CANNONS):
            put("OBJ_cannon_%s_%02d" % (name, i + 1), P(c), "CONE", 0.8, extra={"dir": [0.0, k]})
        for i, c in enumerate(RAMS):
            put("OBJ_ram_spawn_%s_%02d" % (name, i + 1), P(c), "ARROWS", 1.2, extra={"dir": [0.0, k]})
        for i, b in enumerate(out["banners"][name]):
            put("BANNER_%s_%02d" % (name, i + 1), b["pos"], "SINGLE_ARROW", 0.8, b["y"], extra={"y": b["y"], "rot": b["rot"]})
    for i, c in enumerate(HILL_CANNONS):
        put("OBJ_cannon_hill_%02d" % (i + 1), c, "CONE", 0.8, extra={"dir": [0.0, -1.0 if i == 0 else 1.0]})
    for i, b in enumerate(out["banners"]["hill"]):
        put("BANNER_hill_%02d" % (i + 1), b["pos"], "SINGLE_ARROW", 0.8, b["y"], extra={"y": b["y"], "rot": b["rot"]})
    z.data["markers"] = mk
    pos = lambda n: mk[n]["pos"]
    z.data["gvg"] = {
        "sides": {s: {
            "spawn": pos("SPAWN_side_" + s), "forward": pos("SPAWN_forward_" + s),
            "exit": {"pos": pos("TRIG_exit_" + s), "radius": EXIT_R},
            "crystal": pos("OBJ_crystal_" + s),
            "gates": {k: {"pos": pos("OBJ_gate_%s_%s" % (k, s)), "width": mk["OBJ_gate_%s_%s" % (k, s)]["width"],
                          "node": mk["OBJ_gate_%s_%s" % (k, s)]["node"], "node_broken": mk["OBJ_gate_%s_%s" % (k, s)]["node_broken"],
                          "collider": mk["OB_box_gate_%s_%s" % (k, s)]} for k in ("main", "side", "rear")},
            "cannons": [pos("OBJ_cannon_%s_%02d" % (s, i + 1)) for i in range(4)],
            "rams": [pos("OBJ_ram_spawn_%s_%02d" % (s, i + 1)) for i in range(2)],
            "stair": {"pos": [0.0, round((STAIR_Z[0] + STAIR_Z[1]) * 0.5 * (1 if s == "N" else -1), 2)], "width": STAIR_HALF * 2},
            "hall": [HALL[0], HALL[1], HALL[2], HALL[3]] if s == "N" else [-HALL[1], -HALL[0], -HALL[3], -HALL[2]],
            "banners": [n for n in sorted(mk) if n.startswith("BANNER_%s_" % s)],
        } for s in ("N", "S")},
        "hill": {"center": [0.0, 0.0], "radius_in": HILL_R_IN, "radius_out": HILL_R_OUT, "ramps": [[0.0, -(HILL_R_IN + HILL_R_OUT) * 0.5], [0.0, (HILL_R_IN + HILL_R_OUT) * 0.5]],
                 "ramp_width": RAMP_HALF * 2, "cannons": [pos("OBJ_cannon_hill_01"), pos("OBJ_cannon_hill_02")],
                 "banners": ["BANNER_hill_01", "BANNER_hill_02"]},
        "bridges": [[-BRIDGE_X, 0.0], [BRIDGE_X, 0.0]],
        # estrada de cada aríete (MapsCatalog.gvg_ram_route): do ponto de saída, pela estrada, até diante do portão
        # principal inimigo. ram_01 do norte vai pela ponte oeste, ram_02 pela leste; os do sul são o espelho pelo centro.
        "ram_routes": {"ram_%02d_%s" % (i + 1, s): [[round(x * ex * k, 2), round(zz * k, 2)] for x, zz in RAM_ROUTE]
                       for s, k in (("N", 1.0), ("S", -1.0)) for i, ex in enumerate((1.0, -1.0))},
        "bounds": [-RIM_X, RIM_X, -RIM_Z, RIM_Z],
    }


def border(z):
    """Anel de montanhas na borda em retângulo redondo + corrente de colisão seguindo a curva (o Zone.cliffs supõe um
    círculo: num vale comprido as caixas tangentes ao círculo deixavam fresta)."""
    mats = [z.M["cliff_rock"], z.M["cliff_rock_d"], z.M["cliff_grass"], None]
    nature.mountain_ring(z.coll, z.P + "penhascos", z.rim_r, [], mats, z.ob, seed=z.seed, tree_cols=nature.PINE_COLS,
                         ledge_trees="pine", boulder_col=tuple(z.M["cliff_rock"].diffuse_color[:3]))
    steps = 150
    pts = [Vector((math.cos(math.tau * i / steps) * z.rim_r(math.tau * i / steps), math.sin(math.tau * i / steps) * z.rim_r(math.tau * i / steps))) for i in range(steps)]
    for i in range(steps):
        a, b = pts[i], pts[(i + 1) % steps]
        t = (b - a).normalized()
        nr = Vector((t.y, -t.x))
        mid = (a + b) * 0.5
        if nr.dot(mid) < 0:
            nr = -nr
        c = mid + nr * 3.5
        z.ob("cliff", c.x, c.y, ((b - a).length * 1.3 + 0.4, 6.0, 7.0), along(t.x, t.y), visible=False)


def build(export=False, only=None):
    z = Zone(ZONE, size=216.0, rim=(100.0, 0.0, 0.0, 0.0), seed=57, spawn=(SPAWN_SIDE[0], -SPAWN_SIDE[1]), palette={
        "road": DIRT, "street": (0.78, 0.76, 0.72), "cliff_rock": (0.66, 0.6, 0.55), "cliff_rock_d": (0.54, 0.48, 0.45),
        "cliff_grass": GRASS_D, "hill_grass": GRASS_L, "wood": WOOD, "roof": ROOF, "water": (0.42, 0.68, 0.86),
    })
    z.rim_r = rim_r
    d = Dress(z, 57)
    z.cam_game = (GATE_MAIN[0], GATE_MAIN[1])
    out = {"gates": {}, "banners": {}}
    # ---- rio: dois trechos, espelhados pelo centro; cada um some num bueiro do reduto ----
    west = [(-110.0, 6.0), (-90.0, 4.5), (-70.0, -1.5), (-BRIDGE_X - 8.0, -0.6), (-BRIDGE_X, 0.0), (-BRIDGE_X + 8.0, 0.6), (-27.0, 2.2), (-HILL_R_OUT - 2.5, 0.2), (-HILL_R_OUT + 1.2, 0.0)]
    z.river(west, RIVER_W)
    z.river([(-x, -zz) for x, zz in west], RIVER_W)
    # ---- estradas (kind road: abrem o vão do rio na ponte). Caminho do aríete: terreiro -> ponte -> portão inimigo ----
    half = [(0.0, -24.5), (-15.0, -22.6), (-33.0, -16.0), (-43.0, -8.0), (-BRIDGE_X, 0.0)]
    for name, e in (("oeste", 1.0), ("leste", -1.0)):
        pts = [(x * e, zz) for x, zz in half] + [(x * e, -zz) for x, zz in reversed(half[:-1])]
        z.road(name, pts, end_clearing=False)
    # do portão lateral de cada castelo à estrada da ponte do lado dele
    lat = [(-38.0, -37.5), (-39.5, -31.0), (-46.0, -22.0), (-46.5, -13.0), (-44.2, -8.6)]
    z.road("lateral_n", lat, w=3.4, end_clearing=False)
    z.road("lateral_s", [(-x, -zz) for x, zz in lat], w=3.4, end_clearing=False)
    z.bridges()
    # ---- castelos, reduto, campo ----
    castle(z, d, "N", out)
    castle(z, d, "S", out)
    hill(z, d, out)
    z.block((0.0, 0.0), HILL_R_OUT + 6.0)
    for e in (1, -1):
        for c, r in (((-24.0, -41.0), 22.0), ((0.0, -41.0), 22.0), ((22.0, -41.0), 22.0), ((0.0, -22.0), 12.0), ((0.0, -56.0), 13.0), ((-38.0, -34.0), 8.0)):
            z.block((c[0] * e, c[1] * e), r)
    for kind, x, zz, a, rot, h in RUINS:
        for e in (1, -1):
            z.block((x * e, zz * e), 3.5)
    field(z, d, out)
    d.flush()
    # ---- borda natural e bosque nos flancos (props do jogo); a metade sul é o espelho da norte ----
    border(z)
    nrnd = random.Random(61)
    obs = z.data["obstacles"]
    n0 = len(obs)
    free = lambda x, zz, m: zz < -5.0 and z.free(x, zz, m, 0.0) and not in_castle(x, zz, 4.0)
    nature.scatter(z.ob, free, nrnd, "tree", [((-82.0, -38.0), 20.0, 20), ((80.0, -40.0), 20.0, 20), ((-86.0, -14.0), 10.0, 5),
                                              ((88.0, -16.0), 10.0, 5), ((58.0, -52.0), 9.0, 4), ((-62.0, -54.0), 8.0, 4), ((48.0, -24.0), 4.0, 1)],
                   (1.8, 4.2, 1.8), TREES, margin=4.5, spacing=4.2, rotate=False)
    nature.scatter(z.ob, free, nrnd, "rock", [((-74.0, -28.0), 22.0, 6), ((74.0, -30.0), 22.0, 6)], (1.6, 1.2, 1.4), [ROCK, tuple(c * 0.9 for c in ROCK)],
                   margin=4.0, spacing=6.0, avoid=obs)
    nature.scatter(z.ob, free, nrnd, "bush", [((-80.0, -32.0), 24.0, 16), ((80.0, -34.0), 24.0, 16), ((-30.0, -16.0), 12.0, 3), ((32.0, -17.0), 12.0, 3)],
                   (1.5, 0.8, 1.5), nature.BUSH_COLS, solid=False, margin=3.0, spacing=3.0, avoid=obs)
    for o in list(obs[n0:]):
        m = dict(o)
        m["pos"] = [-o["pos"][0], -o["pos"][1]]
        m["size"] = list(o["size"])
        if "color" in o:
            m["color"] = list(o["color"])
        obs.append(m)
    nature.fix_trees(obs, nrnd, pine_frac=0.2)
    nature.clear_banks(obs, z.rivers, [], RIVER_W)
    markers(z, out)
    z.data["hangouts"] = []
    data = z.finish(export, poi=(0.0, 0.0), ground=GRASS)
    data["size"] = [216.0, 140.0]
    if export:                                      # o Zone grava size quadrado: regrava com o retângulo de verdade
        import json
        from zone_lib import ROOT
        with open(ROOT + "/data/zones/%s.json" % ZONE, "w", encoding="utf-8") as f:
            json.dump(data, f, ensure_ascii=False, indent=1)
    # depois do export: o portão quebrado some das fotos (no jogo quem esconde é o código, pelo nome `_broken`)
    for o in z.coll.objects:
        if o.get("gvg_hidden"):
            o.hide_render = True
            o.hide_viewport = True
    extra_views(z)
    tris = 0
    for o in z.coll.objects:
        if o.type == "MESH":
            tris += sum(len(p.vertices) - 2 for p in o.data.polygons)
    print("gvg_field: %d objetos, %d triangulos, %d colisores, %d props" % (
        len(z.coll.objects), tris, sum(1 for o in data["obstacles"] if not o["visible"]), sum(1 for o in data["obstacles"] if o["visible"])))
    return data


def extra_views(z):
    """Câmeras a mais do loop (escada do norte, portão lateral, portão do sul visto por dentro, fundos) e marcas de
    prévia (canhões, Cristal, aríetes, renascer) na Collection PREVIEW, que não é exportada."""
    for name, (tx, tz) in (("CAM_stair", (0.0, -41.0)), ("CAM_side", (GATE_SIDE[0], GATE_SIDE[1])), ("CAM_gate_s", (0.0, 30.0)),
                           ("CAM_stair_s", (0.0, 41.0)), ("CAM_rear", (0.0, -53.0)), ("CAM_bridge", (-BRIDGE_X, 0.0))):
        cd = bpy.data.cameras.new(name)
        cd.lens_unit = "FOV"
        cd.angle = math.radians(56)
        cd.clip_start = 2.0
        co = bpy.data.objects.new(name, cd)
        co.location = B(tx, tz, 0.8) + Vector((0, -math.cos(math.radians(52)) * 24, math.sin(math.radians(52)) * 24))
        co.rotation_euler = (math.radians(38), 0, 0)
        z.sc.collection.objects.link(co)
    pc = bpy.data.collections.get("PREVIEW_" + z.zone)
    if pc is None:
        return
    import zone_lib
    cols = {"OBJ_cannon": ((0.2, 0.2, 0.24), (1.6, 1.1, 1.0)), "OBJ_crystal": ((0.5, 0.85, 1.0), (1.6, 3.5, 1.6)), "OBJ_ram": ((0.5, 0.36, 0.22), (2.2, 2.0, 4.0)),
            "SPAWN_side": ((0.95, 0.9, 0.4), (1.0, 1.7, 1.0)), "SPAWN_forward": ((0.95, 0.6, 0.3), (1.0, 1.7, 1.0)), "BANNER": ((0.85, 0.3, 0.3), (0.2, 1.8, 1.0))}
    for name, mk in z.data["markers"].items():
        for pre, (col, size) in cols.items():
            if name.startswith(pre):
                y0 = mk.get("y", 0.0) - (size[1] if pre == "BANNER" else 0.0)
                zone_lib.box(pc, "PV_" + name, mk["pos"], size, mk.get("rot", 0.0), mat("pv_gvg_" + pre, col), y0)
