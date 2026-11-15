"""Cenário 3D da tela inicial (título, lista de personagens, criação): acampamento de fogueira na beira de Aldara, ao
entardecer. Um GLB pequeno e próprio (`assets/models/menu_set.glb`), não o mapa de verdade.

    blender -b --factory-startup --python <runner>      # runner: import menu_set; menu_set.build(export=True)
    menu_set.render(<pasta>, "v1")                       # fotos de revisão (`SHOTS`: cada câmera em 16:9 e 21:9; EEVEE, entardecer)

O que sai no GLB (Z para cima aqui, Y para cima no arquivo; o boneco olha para -Y = +Z do Godot):
  malhas   MS_ground (chão), MS_camp (pedestal, acampamento, fogueira, árvores/capim de perto), MS_backdrop (Aldara, mata e
           serra do fundo), MS_flame_a/_b/_c (3 grupos de línguas, filhas do vazio MS_flames, cada uma com a origem
           no próprio pé: dá para tremer a escala de cada uma, ou a do MS_flames inteiro) — uma superfície por material
  vazios   SPOT_pedestal (pé do boneco, em cima do pedestal), LIGHT_fire, LIGHT_lantern, MS_flames (pé do fogo),
           MS_sparks (emissor de fagulhas), CAM_title, CAM_list (lista: os 40% de baixo são chão liso para os cards),
           CAM_create (pedestal no terço esquerdo; extra `subject_yaw` = giro em Y que vira o boneco para a câmera)
           As câmeras são vazios com +Y local = para onde olham e +Z local = cima: no Godot (depois do export Y-up) o
           -Z local do nó é a mira, então `camera.global_transform = no.global_transform` basta. `fov` (vertical, graus),
           `color`/`energy`/`range` vão como extras (metadata do nó no Godot).
Materiais: cor chapada por material (`ms_*`); `glow_*` brilha (brasa, chama, lanterna, janelas de Aldara).
Reaproveita `prop_kit` (caixa/viga/esfera irregular, caixote, barril, tronco, toco, pinheiro, poste) e `zone_lib.catmull`.
"""
import bpy
import bmesh
import math
import os
import random
import sys
from mathutils import Vector, Matrix, noise

HERE = os.path.dirname(os.path.abspath(__file__))
for _p in (HERE, os.path.join(HERE, "zones")):
    if _p not in sys.path:
        sys.path.append(_p)

import chibi_kit as ck
import prop_kit as pk
from zone_lib import catmull

OUT = os.path.normpath(os.path.join(HERE, "..", "..", "assets", "models", "menu_set.glb"))

# ---------------------------------------------------------------------------
# lugares (x, y do Blender; a câmera fica em -Y olhando para +Y, +X = direita da tela)
# ---------------------------------------------------------------------------
PED_R, PED_H = 0.8, 0.25
FIRE = Vector((-2.5, 1.2, 0.0))
CAMP_C = Vector((-0.4, 1.6))                 # centro do chão batido
LAMP = Vector((2.25, 1.7))
TOWN_C = Vector((6.0, 80.0))                 # centro de Aldara (só a fatia sul da muralha aparece)
TOWN_R = 34.0
GATE_A = math.radians(-96.0)
PATH = [(1.2, 4.2), (3.4, 10.5), (1.2, 19.0), (3.6, 29.0), (2.2, 38.0), (2.45, 45.5)]

# câmeras: posição, alvo, fov vertical (o FOV vertical é fixo: em 21:9 aparece mais dos lados)
#   CAM_title   o acampamento inteiro com Aldara ao fundo
#   CAM_list    lista de personagens: acampamento, fogo e pedestal nos 55% de cima; os 40% de baixo são o chão liso da
#               frente (ZONA CALMA), onde ficam os 5 cards
#   CAM_create  criação: o painel ocupa os 43-98% da DIREITA, então o pedestal fica nos 40% da esquerda (centro a ~23%
#               da largura em 16:9, ~30% em 21:9). O quadro é para um boneco de classe de até ~2,4 m (elmo alto, cajado,
#               asas): pés a ~85% da altura do quadro, topo dos 2,4 m a ~11% (folga em cima); o boneco de 1,7 m ocupa
#               ~53% da altura. `subject_yaw` = giro (graus, eixo Y do Godot) que põe o boneco de frente para esta
#               câmera (sai da posição dela, em `build`). `frame_report()` imprime onde caem pés/topo/pedestal.
CAMS = {
    "CAM_title": ((1.3, -9.4, 2.7), (0.2, 6.0, 2.3), 42.0),
    "CAM_list": ((0.4, -8.5, 1.3), (0.2, 0.0, -0.05), 46.0),
    "CAM_create": ((3.47, -3.87, 1.5), (1.27, 0.95, 1.35), 36.0),
}
# chão liso na frente do pedestal (x0, x1, y0, y1): sem capim, flor nem pedra, para os cards da lista e os botões do título
CALM = (-3.6, 4.0, -7.6, -1.3)
SPARKS = (FIRE.x, FIRE.y, 0.78)              # MS_sparks: de onde saem as fagulhas (meio da chama)
# luzes do jogo (cor linear 0-1, energia de OmniLight3D do Godot, alcance em m)
LIGHTS = {
    "LIGHT_fire": ((FIRE.x, FIRE.y, 0.8), (1.0, 0.56, 0.24), 3.2, 11.0),
    "LIGHT_lantern": ((LAMP.x - 0.5, LAMP.y, 1.62), (1.0, 0.8, 0.5), 1.4, 6.0),
}

ROOFS = [(0.78, 0.4, 0.33), (0.45, 0.55, 0.72), (0.8, 0.55, 0.3), (0.5, 0.62, 0.45), (0.55, 0.45, 0.65)]


def M():
    mt = ck.mat
    return {
        "grass": mt("ms_grass", (0.5, 0.66, 0.4), 1.0),
        "grass_l": mt("ms_grass_l", (0.62, 0.74, 0.44), 1.0),
        "grass_d": mt("ms_grass_d", (0.4, 0.57, 0.4), 1.0),
        "blade": mt("ms_blade", (0.46, 0.68, 0.4), 1.0),
        "blade_l": mt("ms_blade_l", (0.68, 0.8, 0.46), 1.0),
        "dirt": mt("ms_dirt", (0.72, 0.6, 0.46), 1.0),
        "dirt_l": mt("ms_dirt_l", (0.8, 0.69, 0.54), 1.0),
        "stone": mt("ms_stone", (0.76, 0.73, 0.7), 1.0),
        "stone_d": mt("ms_stone_d", (0.58, 0.56, 0.56), 1.0),
        "stone_l": mt("ms_stone_l", (0.87, 0.84, 0.78), 1.0),
        "wood": mt("ms_wood", (0.58, 0.41, 0.27), 1.0),
        "wood_d": mt("ms_wood_d", (0.38, 0.26, 0.19), 1.0),
        "wood_l": mt("ms_wood_l", (0.78, 0.62, 0.42), 1.0),
        "bark": mt("ms_bark", (0.5, 0.36, 0.27), 1.0),
        "moss": mt("ms_moss", (0.48, 0.64, 0.36), 1.0),
        "canvas": mt("ms_canvas", (0.93, 0.89, 0.78), 1.0),
        "blue": mt("ms_aldara_blue", (0.3, 0.42, 0.75), 1.0),
        "gold": mt("ms_aldara_gold", (0.96, 0.84, 0.5), 1.0),
        "dark": mt("ms_dark", (0.14, 0.11, 0.13), 1.0),
        "iron": mt("ms_iron", (0.3, 0.3, 0.34), 1.0),
        "sack": mt("ms_sack", (0.78, 0.69, 0.5), 1.0),
        "ash": mt("ms_ash", (0.27, 0.23, 0.23), 1.0),
        "leaf": mt("ms_leaf", (0.42, 0.64, 0.42), 1.0),
        "leaf_l": mt("ms_leaf_l", (0.6, 0.78, 0.46), 1.0),
        "leaf_w": mt("ms_leaf_w", (0.93, 0.62, 0.42), 1.0),       # copa de outono (pêssego)
        "leaf_wl": mt("ms_leaf_wl", (0.98, 0.78, 0.5), 1.0),
        "pine": mt("ms_pine", (0.3, 0.5, 0.44), 1.0),
        "pine_l": mt("ms_pine_l", (0.42, 0.62, 0.48), 1.0),
        "fl_pink": mt("ms_flower_pink", (1.0, 0.6, 0.7), 1.0),
        "fl_white": mt("ms_flower_white", (0.98, 0.96, 0.9), 1.0),
        "fl_yellow": mt("ms_flower_yellow", (1.0, 0.85, 0.36), 1.0),
        "fl_blue": mt("ms_flower_blue", (0.6, 0.7, 0.98), 1.0),
        "wall": mt("ms_town_wall", (0.84, 0.78, 0.66), 1.0),
        "wall_d": mt("ms_town_wall_d", (0.7, 0.64, 0.54), 1.0),
        "plaster": mt("ms_plaster", (0.9, 0.84, 0.72), 1.0),
        "roof": mt("ms_roof", (0.66, 0.34, 0.32), 1.0),
        "far": mt("ms_far_hill", (0.5, 0.47, 0.62), 1.0),
        "far_d": mt("ms_far_tree", (0.36, 0.42, 0.5), 1.0),
        "ember": mt("glow_brasa", (1.0, 0.42, 0.12), 0.6, 1.2),
        "flame": mt("glow_chama", (1.0, 0.5, 0.14), 0.6, 1.0),
        "flame_l": mt("glow_chama_clara", (1.0, 0.86, 0.4), 0.6, 1.1),
        "lantern": mt("glow_lanterna", (1.0, 0.84, 0.5), 0.6, 1.1),
        "window": mt("glow_janela", (1.0, 0.78, 0.42), 0.6, 1.1),
    }


def PM(m, **over):
    """Dicionário com as chaves que o prop_kit espera, pintado com as cores do cenário."""
    d = {"stone": m["stone"], "stone_d": m["stone_d"], "stone_l": m["stone_l"], "plaster": m["plaster"], "wood": m["wood"],
         "wood_d": m["wood_d"], "wood_l": m["wood_l"], "roof": m["roof"], "tint": m["bark"], "tint_l": m["leaf_l"],
         "leaf_l": m["leaf_l"], "glass": m["dark"], "glow": m["lantern"], "water": m["blue"], "moss": m["moss"],
         "cloth_r": m["blue"], "cloth_w": m["canvas"], "flower": m["fl_pink"], "iron": m["iron"]}
    d.update(over)
    return d


# ---------------------------------------------------------------------------
# ajudantes
# ---------------------------------------------------------------------------
def xf(parts, loc=(0, 0, 0), rot=0.0, s=1.0):
    """Gira (graus, em Z), escala e desloca as peças (direto nos vértices)."""
    mtx = Matrix.Translation(Vector(loc)) @ Matrix.Rotation(math.radians(rot), 4, "Z") @ Matrix.Scale(s, 4)
    for o in parts:
        o.data.transform(mtx)
    return parts


def blob(name, c, r, z, mat, segs=14, jitter=0.22, seed=0, sx=1.0, rot=0.0):
    """Mancha de chão: polígono irregular em leque."""
    bm = bmesh.new()
    ca, sa = math.cos(math.radians(rot)), math.sin(math.radians(rot))
    ctr = bm.verts.new((c[0], c[1], z))
    ring = []
    for i in range(segs):
        a = math.tau * i / segs
        k = r * (1.0 + jitter * noise.noise(Vector((math.cos(a) * 1.3 + seed * 3.7, math.sin(a) * 1.3, seed * 1.9))) * 2.0)
        x, y = math.cos(a) * k * sx, math.sin(a) * k
        ring.append(bm.verts.new((c[0] + x * ca - y * sa, c[1] + x * sa + y * ca, z)))
    for i in range(segs):
        bm.faces.new((ctr, ring[i], ring[(i + 1) % segs]))
    return ck.mesh_from(name, bm, mat)


def strip(name, pts, w, z, mat, taper=0.0):
    """Faixa de chão ao longo de `pts` (trilha)."""
    bm = bmesh.new()
    rows = []
    for i, p in enumerate(pts):
        a = pts[max(0, i - 1)]
        b = pts[min(len(pts) - 1, i + 1)]
        t = (Vector(b) - Vector(a)).normalized()
        n = Vector((-t.y, t.x))
        k = w * 0.5 * (1.0 - taper * i / (len(pts) - 1)) * (1.0 + 0.16 * math.sin(i * 1.7))
        rows.append((bm.verts.new((p[0] - n.x * k, p[1] - n.y * k, z)), bm.verts.new((p[0] + n.x * k, p[1] + n.y * k, z))))
    for i in range(len(rows) - 1):
        bm.faces.new((rows[i][1], rows[i][0], rows[i + 1][0], rows[i + 1][1]))
    return ck.mesh_from(name, bm, mat)


def prism_roof(name, w, d, eave, ridge, mat):
    """Telhado de duas águas (cumeeira ao longo de X), fechado."""
    hw, hd = w * 0.5, d * 0.5
    bm = bmesh.new()
    v = [bm.verts.new(c) for c in [(-hw, -hd, eave), (hw, -hd, eave), (hw, hd, eave), (-hw, hd, eave), (-hw, 0, ridge), (hw, 0, ridge)]]
    for f in ((0, 1, 5, 4), (2, 3, 4, 5), (0, 4, 3), (1, 2, 5), (3, 2, 1, 0)):
        bm.faces.new([v[i] for i in f])
    return ck.mesh_from(name, bm, mat)


def sheet(name, poly, mat, y=0.0, thick=0.03):
    """Pano em pé no plano XZ (frente em -Y) com as duas faces."""
    bm = bmesh.new()
    f = [bm.verts.new((x, y - thick * 0.5, z)) for x, z in poly]
    b = [bm.verts.new((x, y + thick * 0.5, z)) for x, z in poly]
    bm.faces.new(f)
    bm.faces.new(list(reversed(b)))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    for face in bm.faces:                    # frente olha para -Y, costas para +Y
        if (face.normal.y > 0) != (face.calc_center_median().y > y):
            face.normal_flip()
    return ck.mesh_from(name, bm, mat)


class Batch:
    """Miudeza (capim, flores) direto em poucas malhas: uma por material."""

    def __init__(self):
        self.bm = {}

    def _b(self, mat):
        if mat.name not in self.bm:
            self.bm[mat.name] = (bmesh.new(), mat)
        return self.bm[mat.name][0]

    def blade(self, mat, base, tip, w):
        bm = self._b(mat)
        t = bm.verts.new(tip)
        vs = [bm.verts.new((base[0] + math.cos(a) * w, base[1] + math.sin(a) * w, base[2])) for a in (0.5, 2.6, 4.7)]
        for i in range(3):
            bm.faces.new((vs[i], vs[(i + 1) % 3], t))

    def tuft(self, rnd, mat, c, r=0.22, h=0.42, n=6, lean=(0.0, 0.0)):
        for _ in range(n):
            a, d = rnd.uniform(0, math.tau), r * rnd.random()
            x, y = c[0] + math.cos(a) * d, c[1] + math.sin(a) * d
            hh = h * rnd.uniform(0.6, 1.15)
            self.blade(mat, (x, y, 0.0), (x + math.cos(a) * hh * 0.35 + lean[0], y + math.sin(a) * hh * 0.35 + lean[1], hh), 0.045)

    def flower(self, rnd, stem, petal, c, h=0.34):
        x, y = c
        self.blade(stem, (x, y, 0.0), (x + rnd.uniform(-0.04, 0.04), y + rnd.uniform(-0.04, 0.04), h), 0.022)
        bm = self._b(petal)
        r = rnd.uniform(0.07, 0.1)
        top, bot = bm.verts.new((x, y, h + r * 0.75)), bm.verts.new((x, y, h - r * 0.3))
        ring = [bm.verts.new((x + math.cos(a) * r, y + math.sin(a) * r, h + r * 0.15)) for a in (0.3, 1.87, 3.44, 5.01)]
        for i in range(4):
            bm.faces.new((ring[i], ring[(i + 1) % 4], top))
            bm.faces.new((ring[(i + 1) % 4], ring[i], bot))

    def objects(self):
        return [ck.mesh_from("batch_" + k, bm, mat) for k, (bm, mat) in self.bm.items()]


# ---------------------------------------------------------------------------
# peças
# ---------------------------------------------------------------------------
def pedestal(m):
    """Pedestal redondo (1,6 m x 0,25 m): soleira e anel de blocos de pedra, tampo de tábuas; o boneco pisa em z = PED_H."""
    parts = [ck.tube("ped_base", (0, 0, 0), (0, 0, 0.09), PED_R + 0.07, PED_R + 0.03, m["stone_d"], 16)]
    parts += pk.ring_of_stones("ped_bloco", (0, 0, 0), PED_R - 0.13, 0.15, 12, m["stone"], m["stone_l"], 0.07, (0.4, 0.26))
    parts.append(ck.tube("ped_miolo", (0, 0, 0.05), (0, 0, PED_H - 0.03), PED_R - 0.12, PED_R - 0.12, m["wood_d"], 16))
    parts.append(ck.tube("ped_tampo", (0, 0, PED_H - 0.04), (0, 0, PED_H), PED_R - 0.1, PED_R - 0.13, m["wood_l"], 16))
    # aro de ferro e tachas: lê de cima sem brigar com os pés
    parts.append(ck.tube("ped_aro", (0, 0, PED_H - 0.05), (0, 0, PED_H - 0.015), PED_R - 0.085, PED_R - 0.085, m["iron"], 16))
    for i in range(8):
        a = math.tau * (i + 0.5) / 8
        parts.append(ck.tube("ped_tacha%d" % i, (math.cos(a) * 0.58, math.sin(a) * 0.58, PED_H - 0.01),
                             (math.cos(a) * 0.58, math.sin(a) * 0.58, PED_H + 0.012), 0.035, 0.025, m["gold"], 6))
    return parts


def campfire(m, seed=3):
    """Fogueira (na origem): anel de pedras, cinza, lenha em cone e brasa. Devolve (peças fixas, línguas), cada língua =
    [base, ponta, pé]."""
    rnd = random.Random(seed)
    parts = [ck.tube("fogo_cinza", (0, 0, 0.0), (0, 0, 0.04), 0.6, 0.52, m["ash"], 10)]
    for i in range(9):
        a = math.tau * i / 9 + rnd.uniform(-0.1, 0.1)
        r = rnd.uniform(0.15, 0.21)
        parts.append(pk.lumpy("fogo_pedra%d" % i, r, (math.cos(a) * 0.66, math.sin(a) * 0.66, r * 0.55),
                              m["stone"] if i % 3 else m["stone_d"], (1.1, 1.0, 0.75), 0.25, seed + i, cuts=2))
    for i in range(5):
        a = math.tau * i / 5 + 0.3
        parts.append(ck.tube("fogo_lenha%d" % i, (math.cos(a) * 0.5, math.sin(a) * 0.5, 0.07), (-math.cos(a) * 0.06, -math.sin(a) * 0.06, 0.5),
                             0.085, 0.06, m["wood_d"] if i % 2 else m["bark"], 6))
    parts.append(pk.lumpy("fogo_brasa", 0.34, (0, 0, 0.09), m["ember"], (1, 1, 0.3), 0.3, seed + 20, cuts=2))
    for i in range(6):
        a, d = rnd.uniform(0, math.tau), rnd.uniform(0.2, 0.46)
        parts.append(pk.B("fogo_tico%d" % i, (0.09, 0.07, 0.06), (math.cos(a) * d, math.sin(a) * d, 0.07), m["ember"], 0.0, a))
    flames = []                              # uma lista de peças por língua
    # línguas laranja em volta de uma alta; o miolo claro fica do lado das câmeras (-Y), senão some dentro da laranja
    for i, (x, y, r, h, mat) in enumerate([(0.0, 0.04, 0.27, 1.1, "flame"), (-0.24, 0.06, 0.17, 0.72, "flame"), (0.23, 0.0, 0.16, 0.62, "flame"),
                                           (0.04, 0.24, 0.16, 0.66, "flame"), (-0.1, -0.2, 0.15, 0.5, "flame"),
                                           (0.03, -0.17, 0.17, 0.7, "flame_l"), (-0.17, -0.12, 0.09, 0.4, "flame_l"), (0.17, -0.15, 0.08, 0.34, "flame_l")]):
        z0 = 0.14
        flames.append([ck.tube("chama_b%d" % i, (x, y, z0), (x, y, z0 + h * 0.34), r * 0.55, r, m[mat], 6),
                       ck.tube("chama_t%d" % i, (x, y, z0 + h * 0.34), (x + r * 0.25, y + r * 0.1, z0 + h), r, 0.01, m[mat], 6),
                       (x, y, z0)])
    return parts, flames


# as 8 línguas em 3 malhas (filhas de MS_flames), cada uma com a origem no próprio pé: o jogo treme a escala de cada uma
FLAME_GROUPS = (("MS_flame_a", (0, 5)), ("MS_flame_b", (1, 4, 6)), ("MS_flame_c", (2, 3, 7)))


def pavilion(m, s=1.0):
    """Pavilhão de campanha de Aldara (o mesmo desenho do `Dress.tent_aurora`): lona creme, beiral e coifa azuis, flâmula
    dourada. A porta olha para -Y."""
    t = ck.tube
    parts = [t("pav_parede", (0, 0, 0), (0, 0, 1.15), 1.5, 1.5, m["canvas"], 10),
             t("pav_beiral", (0, 0, 1.0), (0, 0, 1.34), 1.86, 1.5, m["blue"], 10),
             t("pav_teto", (0, 0, 1.34), (0, 0, 2.84), 1.5, 0.16, m["canvas"], 10),
             t("pav_coifa", (0, 0, 2.36), (0, 0, 2.9), 0.64, 0.17, m["blue"], 10),
             t("pav_mastro", (0, 0, 2.84), (0, 0, 3.8), 0.05, 0.04, m["wood_l"], 5),
             t("pav_ponta", (0, 0, 3.74), (0, 0, 4.0), 0.12, 0.0, m["gold"], 5),
             sheet("pav_flamula", [(0.04, 3.7), (0.72, 3.56), (0.04, 3.36)], m["gold"]),
             pk.B("pav_boca", (0.86, 0.16, 1.0), (0, -1.43, 0.5), m["dark"], 0.0)]
    for k in (-1, 1):
        parts.append(pk.B("pav_aba%d" % k, (0.28, 0.08, 1.05), (k * 0.54, -1.5, 0.525), m["blue"], 0.0, math.radians(k * 24.0)))
        parts.append(ck.tube("pav_corda%d" % k, (k * 1.7, -0.6, 1.1), (k * 2.5, -1.0, 0.0), 0.02, 0.02, m["wood_l"], 4))
        parts.append(ck.tube("pav_estaca%d" % k, (k * 2.5, -1.0, 0.0), (k * 2.56, -1.03, 0.22), 0.04, 0.03, m["wood_d"], 5))
    return xf(parts, s=s)


def ridge_tent(m):
    """Barraca de cumeeira pequena (dorme um): lona creme, frente aberta escura, barra azul."""
    L, W, H = 1.3, 1.05, 1.5
    parts = []
    for sy in (-1, 1):
        bm = bmesh.new()
        vs = [bm.verts.new(c) for c in [(-L, sy * W, 0.02), (L, sy * W, 0.02), (L, 0, H), (-L, 0, H)]]
        bm.faces.new(vs if sy < 0 else list(reversed(vs)))
        o = ck.mesh_from("bar_lona%d" % sy, bm, m["canvas"])
        o.modifiers.new("sol", "SOLIDIFY").thickness = 0.05
        parts.append(ck._bake(o))
        bm = bmesh.new()
        vs = [bm.verts.new(c) for c in [(-L - 0.02, sy * (W + 0.03), 0.0), (L + 0.02, sy * (W + 0.03), 0.0),
                                        (L + 0.02, sy * (W - 0.14), 0.25), (-L - 0.02, sy * (W - 0.14), 0.25)]]
        bm.faces.new(vs if sy < 0 else list(reversed(vs)))
        o = ck.mesh_from("bar_barra%d" % sy, bm, m["blue"])
        o.modifiers.new("sol", "SOLIDIFY").thickness = 0.04
        parts.append(ck._bake(o))
    for sx, mat in ((-1, "dark"), (1, "canvas")):
        bm = bmesh.new()
        vs = [bm.verts.new(c) for c in [(sx * (L - 0.03), -W * 0.9, 0.02), (sx * (L - 0.03), W * 0.9, 0.02), (sx * (L - 0.03), 0, H - 0.12)]]
        bm.faces.new(vs if sx > 0 else list(reversed(vs)))
        parts.append(ck.mesh_from("bar_fundo%d" % sx, bm, m[mat]))
        parts.append(pk.beam("bar_pau%d" % sx, (sx * (L + 0.02), 0, 0), (sx * (L + 0.02), 0, H + 0.14), 0.07, m["wood_d"]))
    parts.append(pk.beam("bar_cume", (-L - 0.08, 0, H + 0.02), (L + 0.08, 0, H + 0.02), 0.06, m["wood_d"]))
    return parts


def banner(m, h=4.3):
    """Estandarte de Aldara: mastro, travessa e pano azul de cauda de andorinha com o sol dourado. Frente em -Y."""
    top = h - 0.35
    parts = [ck.tube("est_mastro", (0, 0, 0), (0, 0, h), 0.07, 0.05, m["wood_d"], 6),
             ck.tube("est_pe", (0, 0, 0), (0, 0, 0.22), 0.2, 0.14, m["stone_d"], 6),
             pk.beam("est_travessa", (-0.62, -0.06, top), (0.62, -0.06, top), 0.07, m["wood_d"]),
             ck.tube("est_ponta", (0, 0, h), (0, 0, h + 0.3), 0.1, 0.0, m["gold"], 5)]
    y = -0.1
    parts.append(sheet("est_pano", [(-0.5, top), (0.5, top), (0.5, top - 2.0), (0.0, top - 1.62), (-0.5, top - 2.0)], m["blue"], y))
    parts.append(sheet("est_faixa", [(-0.52, top + 0.02), (0.52, top + 0.02), (0.52, top - 0.22), (-0.52, top - 0.22)], m["gold"], y, 0.05))
    cz = top - 0.85
    for k, r in ((0.0, 0.25), (math.pi / 4, 0.25)):          # sol de oito pontas = dois quadrados
        parts.append(sheet("est_sol%d" % int(k * 10), [(math.cos(k + i * math.pi / 2) * r, cz + math.sin(k + i * math.pi / 2) * r) for i in range(4)],
                           m["gold"], y, 0.06))
    parts.append(sheet("est_barra", [(-0.5, top - 1.3), (0.5, top - 1.3), (0.5, top - 1.42), (-0.5, top - 1.42)], m["gold"], y, 0.05))
    return parts


def leafy(m, seed, leaf="leaf", hi="leaf_l", cuts=3):
    """Árvore de copa em nuvens (versão leve da `prop_kit.tree`): tronco em tubos, 6 bolhas + 3 realces."""
    rnd = random.Random(seed)
    parts = [ck.tube("arv_tronco", (0, 0, 0), (0.05, 0, 2.1), 0.3, 0.17, m["bark"], 7),
             ck.tube("arv_galho_a", (0.04, 0, 1.7), (0.55, 0.1, 2.6), 0.11, 0.06, m["bark"], 5),
             ck.tube("arv_galho_b", (0.04, 0, 1.6), (-0.5, -0.12, 2.5), 0.11, 0.06, m["bark"], 5)]
    for i in range(4):
        a = math.tau * i / 4 + 0.4
        parts.append(ck.tube("arv_raiz%d" % i, (0, 0, 0.3), (math.cos(a) * 0.6, math.sin(a) * 0.6, 0.0), 0.13, 0.05, m["bark"], 5))
    blobs = [((0, 0, 3.0), 1.15), ((0.75, 0.3, 2.65), 0.8), ((-0.7, -0.25, 2.7), 0.85), ((0.25, -0.75, 2.6), 0.75),
             ((-0.2, 0.8, 2.65), 0.78), ((0.1, 0.1, 3.75), 0.75)]
    for i, (c, r) in enumerate(blobs):
        parts.append(pk.lumpy("arv_copa%d" % i, r, c, m[leaf], (1, 1, 0.85), 0.22, seed * 10 + i, cuts))
    for i, (c, r) in enumerate(blobs[:3]):
        cc = Vector(c) + Vector((rnd.uniform(-0.2, 0.2), rnd.uniform(-0.2, 0.2), r * 0.55))
        parts.append(pk.lumpy("arv_luz%d" % i, r * 0.55, cc, m[hi], (1, 1, 0.6), 0.2, seed * 20 + i, 2))
    return parts


def shrub(m, seed, flower="fl_pink"):
    rnd = random.Random(seed)
    parts = []
    for i, (c, r) in enumerate([((-0.12, 0, 0.42), 0.62), ((0.45, 0.1, 0.34), 0.46)]):
        parts.append(pk.lumpy("moita%d" % i, r, c, m["leaf"], (1, 1, 0.8), 0.22, seed * 10 + i, 2))
    parts.append(pk.lumpy("moita_luz", 0.34, (0.05, -0.05, 0.74), m["leaf_l"], (1, 1, 0.55), 0.2, seed * 30, 2))
    for i in range(4):
        a, d = rnd.uniform(0, math.tau), rnd.uniform(0.25, 0.55)
        parts.append(pk.B("moita_flor%d" % i, (0.11, 0.11, 0.09), (math.cos(a) * d, math.sin(a) * d, 0.78 - d * 0.35), m[flower], 0.0, a))
    return parts


def sacks(m, seed=2):
    return [pk.lumpy("saco_a", 0.34, (0, 0, 0.24), m["sack"], (1.0, 0.8, 0.72), 0.2, seed, 2),
            pk.lumpy("saco_b", 0.3, (0.5, 0.16, 0.2), m["sack"], (1.0, 0.85, 0.7), 0.2, seed + 1, 2),
            pk.lumpy("saco_c", 0.27, (0.22, 0.05, 0.6), m["sack"], (1.1, 0.8, 0.6), 0.2, seed + 2, 2)]


def aldara(m):
    """Fatia sul da muralha de Aldara vista do campo: muro com ameias, torres de teto cônico, portão com estandarte, telhados
    por cima do muro e o castelo na colina (as medidas vêm do `build_city_aldara`)."""
    parts = []
    step = math.radians(6.0)
    seg = 2 * TOWN_R * math.sin(step / 2) + 0.12
    a0, n = math.radians(-162.0), 24

    def at(a, r=TOWN_R):
        return Vector((TOWN_C.x + math.cos(a) * r, TOWN_C.y + math.sin(a) * r))

    for i in range(n):
        a = a0 + step * (i + 0.5)
        if abs(a - GATE_A) < step * 0.7:
            continue
        c = at(a)
        parts.append(pk.B("muro%d" % i, (seg, 1.5, 3.6), (c.x, c.y, 1.8), m["wall"], 0.0, a + math.pi / 2))
        parts.append(pk.B("muro_pe%d" % i, (seg, 1.7, 0.5), (c.x, c.y, 0.25), m["wall_d"], 0.0, a + math.pi / 2))
        for k in (-1, 1):
            q = at(a + k * step * 0.25, TOWN_R + 0.4)
            parts.append(pk.B("ameia%d_%d" % (i, k), (seg * 0.3, 0.7, 0.6), (q.x, q.y, 3.9), m["wall_d"], 0.0, a + math.pi / 2))
    # torres (a cada 24°) com janela acesa virada para o campo
    for k in range(6):
        a = a0 + math.radians(6.0 + 24.0 * k)
        if abs(a - GATE_A) < math.radians(9.0):
            continue
        c = at(a, TOWN_R + 0.3)
        parts += tower(m, "torre%d" % k, c, 2.6, 6.5, a, 12)
    # portão: duas torres, arco e estandarte
    g = at(GATE_A)
    tx = Vector((-math.sin(GATE_A), math.cos(GATE_A)))
    for s in (-1, 1):
        c = Vector((g.x, g.y)) + tx * s * 4.3 + Vector((math.cos(GATE_A), math.sin(GATE_A))) * 0.4
        parts += tower(m, "portao%d" % s, c, 2.0, 7.6, GATE_A, 10)
    parts.append(pk.B("portao_arco", (7.0, 1.8, 1.8), (g.x, g.y, 5.2 + 0.9), m["wall_d"], 0.0, GATE_A + math.pi / 2))
    parts.append(pk.B("portao_vao", (4.6, 1.2, 5.2), (g.x, g.y + 0.5, 2.6), m["dark"], 0.0, GATE_A + math.pi / 2))
    out = Vector((math.cos(GATE_A), math.sin(GATE_A)))
    parts.append(pk.B("portao_pano", (1.5, 0.1, 2.3), (g.x + out.x * 1.0, g.y + out.y * 1.0, 5.6), m["blue"], 0.0, GATE_A + math.pi / 2))
    parts.append(pk.B("portao_pano_ouro", (1.56, 0.12, 0.3), (g.x + out.x * 1.02, g.y + out.y * 1.02, 6.55), m["gold"], 0.0, GATE_A + math.pi / 2))
    # casas atrás do muro: só os telhados e um pedaço de parede aparecem
    rnd = random.Random(5)
    for k in range(11):
        a = math.radians(-150.0 + 11.5 * k + rnd.uniform(-2, 2))
        c = at(a, TOWN_R - rnd.uniform(5.5, 10.5))
        w, d, hh = rnd.uniform(5.0, 6.6), rnd.uniform(4.2, 5.0), rnd.uniform(4.6, 6.2)
        rz = math.degrees(a) + 90.0 + rnd.uniform(-12, 12)
        rm = ck.mat("ms_roof_%d" % (k % len(ROOFS)), ROOFS[k % len(ROOFS)], 1.0)
        house = [pk.B("casa%d" % k, (w, d, hh), (0, 0, hh * 0.5), m["plaster"], 0.0),
                 prism_roof("casa_teto%d" % k, w + 0.7, d + 0.7, hh, hh + 2.5, rm),
                 pk.B("casa_chamine%d" % k, (0.6, 0.6, 1.6), (w * 0.28, 0.5, hh + 1.9), m["wall_d"], 0.0)]
        if k % 2 == 0:
            house.append(pk.B("casa_janela%d" % k, (0.9, 0.12, 0.9), (0.6, -d * 0.5 - 0.02, hh - 1.0), m["window"], 0.0))
        parts += xf(house, (c.x, c.y, 0), rz)
    # castelo na colina
    kc = Vector((TOWN_C.x + 13.0, TOWN_C.y + 2.0))
    top = 5.0
    parts.append(pk.lumpy("castelo_morro", 13.0, (kc.x, kc.y, 0.0), m["grass_d"], (1.2, 1.0, 0.46), 0.16, 4, 3))
    parts.append(pk.B("castelo_base", (11.0, 9.0, 3.0), (kc.x, kc.y, top + 0.3), m["wall_d"], 0.0, math.radians(12)))
    keep = [pk.B("castelo_torreao", (6.0, 6.0, 9.0), (0, 0, 4.5), m["wall"], 0.0),
            pk.B("castelo_topo", (6.8, 6.8, 0.8), (0, 0, 9.2), m["wall_d"], 0.0),
            prism_roof("castelo_teto", 6.2, 6.2, 9.6, 12.4, m["roof"]),
            pk.B("castelo_janela_a", (0.8, 0.12, 1.3), (-1.2, -3.02, 6.4), m["window"], 0.0),
            pk.B("castelo_janela_b", (0.8, 0.12, 1.3), (1.2, -3.02, 6.4), m["window"], 0.0),
            pk.B("castelo_janela_c", (0.8, 0.12, 1.3), (0.0, -3.02, 3.6), m["window"], 0.0),
            ck.tube("castelo_mastro", (0, 0, 12.3), (0, 0, 15.2), 0.09, 0.06, m["wood_d"], 5),
            sheet("castelo_bandeira", [(0.06, 15.1), (2.2, 14.6), (0.06, 13.7)], m["blue"], 0.0, 0.06)]
    for i, (sx, sy) in enumerate(((-1, -1), (1, -1), (1, 1), (-1, 1))):
        keep.append(ck.tube("castelo_torre%d" % i, (sx * 4.6, sy * 3.6, -1.5), (sx * 4.6, sy * 3.6, 11.0), 1.6, 1.4, m["wall"], 10))
        keep.append(ck.tube("castelo_cone%d" % i, (sx * 4.6, sy * 3.6, 11.0), (sx * 4.6, sy * 3.6, 14.6), 1.95, 0.02, m["roof"], 10))
        keep.append(ck.tube("castelo_aro%d" % i, (sx * 4.6, sy * 3.6, 10.5), (sx * 4.6, sy * 3.6, 11.05), 1.7, 1.7, m["wall_d"], 10))
    parts += xf(keep, (kc.x, kc.y, top), 12.0)
    return parts


def tower(m, name, c, r, h, a, segs):
    out = Vector((math.cos(a), math.sin(a)))
    parts = [ck.tube(name, (c.x, c.y, 0), (c.x, c.y, h), r, r - 0.2, m["wall"], segs),
             ck.tube(name + "_borda", (c.x, c.y, h - 0.1), (c.x, c.y, h + 0.6), r + 0.1, r + 0.1, m["wall_d"], segs),
             ck.tube(name + "_teto", (c.x, c.y, h + 0.6), (c.x, c.y, h + 0.6 + r * 1.3), r + 0.4, 0.02, m["roof"], segs),
             pk.B(name + "_janela", (0.7, 0.3, 1.1), (c.x + out.x * (r - 0.18), c.y + out.y * (r - 0.18), h - 1.7), m["window"], 0.0, a + math.pi / 2)]
    return parts


# ---------------------------------------------------------------------------
# montagem
# ---------------------------------------------------------------------------
def build(export=False, path=OUT):
    """Monta o cenário na cena ativa (que precisa estar vazia ou ser a de fábrica: `ck.clear()` limpa a cena)."""
    if bpy.data.filepath:
        raise RuntimeError("menu_set: use um arquivo novo/vazio (aberto: %s)" % bpy.data.filepath)
    ck.clear()
    m = M()
    pm = PM(m)
    rnd = random.Random(1107)
    G = {k: [] for k in ("ground", "pedestal", "camp", "fire", "nature", "aldara", "far")}
    keep_out = []                             # (x, y, raio): onde capim/flor não nasce

    def put(group, parts, loc=(0, 0, 0), rot=0.0, s=1.0, r=0.0):
        G[group] += xf(parts, (loc[0], loc[1], loc[2] if len(loc) > 2 else 0.0), rot, s)
        if r > 0:
            keep_out.append((loc[0], loc[1], r))

    # ---------- chão ----------
    bm = bmesh.new()
    gc = Vector((0.0, 34.0))
    rings = []
    radii = [0.0, 8.0, 18.0, 34.0, 60.0, 100.0, 150.0]
    for k, rr in enumerate(radii):
        zz = 0.0 if rr < 70 else -0.02 * (rr - 70)
        rings.append([bm.verts.new((gc.x + math.cos(math.tau * i / 28) * rr, gc.y + math.sin(math.tau * i / 28) * rr, zz))
                      for i in range(28 if k else 1)])
    for i in range(28):
        bm.faces.new((rings[0][0], rings[1][i], rings[1][(i + 1) % 28]))
        for k in range(1, len(rings) - 1):
            bm.faces.new((rings[k][i], rings[k + 1][i], rings[k + 1][(i + 1) % 28], rings[k][(i + 1) % 28]))
    G["ground"].append(ck.mesh_from("chao", bm, m["grass"]))
    for i in range(16):                       # manchas de capim claro/escuro
        a, d = rnd.uniform(0, math.tau), rnd.uniform(5.0, 30.0)
        c = (CAMP_C.x + math.cos(a) * d, CAMP_C.y + 6.0 + math.sin(a) * d * 0.9)
        G["ground"].append(blob("mancha%d" % i, c, rnd.uniform(2.2, 5.5), 0.006 + 0.001 * (i % 3), m["grass_l" if i % 2 else "grass_d"],
                                10, 0.2, i, rnd.uniform(1.0, 1.8), rnd.uniform(0, 180)))
    G["ground"].append(blob("terra", CAMP_C, 4.3, 0.012, m["dirt"], 18, 0.16, 3, 1.25, 8.0))
    G["ground"].append(blob("terra_fogo", (FIRE.x + 0.4, FIRE.y - 0.1), 2.3, 0.018, m["dirt_l"], 12, 0.14, 5, 1.2))
    G["ground"].append(blob("terra_ped", (0.2, -0.1), 1.9, 0.019, m["dirt_l"], 12, 0.12, 9))
    trail = catmull(PATH, 2.0)
    G["ground"].append(strip("trilha", trail, 2.5, 0.011, m["dirt"]))
    G["ground"].append(strip("trilha_meio", trail, 1.1, 0.016, m["dirt_l"]))

    # ---------- pedestal + fogo ----------
    put("pedestal", pedestal(m), r=1.0)
    for i in range(7):                        # musgo e seixos no pé do pedestal
        a = math.tau * i / 7 + 0.35
        put("pedestal", [pk.lumpy("ped_musgo%d" % i, 0.13 + 0.03 * (i % 3), (math.cos(a) * 0.93, math.sin(a) * 0.93, 0.03),
                                  m["moss" if i % 2 else "stone_d"], (1.2, 1.0, 0.55), 0.3, i, 2)])
    fixed, flames = campfire(m)
    put("fire", fixed, FIRE, r=1.3)

    # ---------- acampamento ----------
    bark = PM(m, tint=m["bark"])
    put("camp", pk.log(bark, 10), (FIRE.x - 0.5, FIRE.y + 2.15), -10.0, 0.82, r=1.4)         # bancos de tronco em volta do fogo
    put("camp", pk.log(bark, 12), (FIRE.x - 2.2, FIRE.y - 0.25), 78.0, 0.74, r=1.3)
    put("camp", pk.stump(bark, 12), (FIRE.x + 1.75, FIRE.y + 1.75), 20.0, 0.72, r=0.7)
    put("camp", pavilion(m, 1.12), (4.7, 5.6), math.degrees(math.atan2(-5.6 + 0.6, -4.7 - 0.8)) + 90.0, r=3.0)
    put("camp", ridge_tent(m), (-6.4, 4.6), 138.0, r=2.2)
    put("camp", pk.crate(pm), (2.75, 3.55), 14.0, 0.72, r=0.7)
    put("camp", pk.crate(pm), (3.6, 3.2), -8.0, 0.62, r=0.6)
    put("camp", pk.crate(pm), (2.85, 3.5, 0.74), 38.0, 0.5)
    put("camp", pk.barrel(pm), (2.1, 4.2), 0.0, 0.78, r=0.5)
    put("camp", sacks(m), (3.55, 2.35), 30.0, 1.0, r=0.6)
    put("camp", sacks(m, 6), (-5.1, 3.4), 200.0, 0.9, r=0.6)
    put("camp", pk.crate(pm), (-4.75, 4.15), 6.0, 0.58, r=0.5)
    put("camp", banner(m), (6.9, 2.5), -16.0, r=0.4)
    put("camp", banner(m, 3.7), (-4.3, 5.9), 16.0, r=0.4)
    put("camp", pk.lamp(pm), (LAMP.x, LAMP.y), 180.0, 0.92, r=0.4)
    # lenha empilhada ao lado do banco
    for i, (dx, dz) in enumerate(((-0.22, 0.13), (0.22, 0.13), (0.0, 0.5))):
        put("camp", [ck.tube("lenha%d" % i, (-0.55, dx, dz), (0.55, dx, dz), 0.2, 0.19, m["bark"], 7),
                     ck.tube("lenha_p%d" % i, (0.55, dx, dz), (0.57, dx, dz), 0.16, 0.16, m["wood_l"], 7)], (-0.75, 4.0), 70.0)
    keep_out.append((-0.75, 4.0, 0.9))

    # ---------- natureza de perto ----------
    put("nature", leafy(m, 3), (-7.6, 8.6), 20.0, 1.55, r=1.2)
    put("nature", leafy(m, 5, "leaf_w", "leaf_wl"), (8.6, 9.6), 100.0, 1.4, r=1.2)
    put("nature", leafy(m, 7, cuts=2), (-10.5, 2.5), 60.0, 1.25, r=1.2)
    put("nature", leafy(m, 9, "leaf_w", "leaf_wl", 2), (-13.5, 12.0), 10.0, 1.3, r=1.2)
    put("nature", leafy(m, 11, cuts=2), (11.0, 3.2), 200.0, 1.2, r=1.2)
    put("nature", leafy(m, 13, cuts=2), (13.5, 15.0), 140.0, 1.5, r=1.2)
    pine_m = PM(m, tint=m["pine"], tint_l=m["pine_l"])
    for i, (x, y, s) in enumerate([(-10.2, 11.5, 1.5), (-12.6, 7.0, 1.25), (-5.6, 12.6, 1.2), (10.6, 12.8, 1.45), (12.8, 8.0, 1.2),
                                   (7.0, 14.6, 1.15), (-16.0, 16.0, 1.6), (16.5, 19.0, 1.6), (-8.6, 17.5, 1.35), (10.2, 20.5, 1.35)]):
        put("nature", pk.pine(pine_m, 4 + i), (x, y), i * 47.0, s, r=1.0)
    # laterais (21:9 mostra ~8 graus a mais de cada lado): pinheiros, barraca, carga e pedras fecham as bordas
    for i, (x, y, s) in enumerate([(-14.6, 4.4, 1.35), (-17.5, 9.5, 1.5), (15.2, 5.8, 1.4), (14.4, 0.6, 1.2), (18.0, 11.5, 1.55)]):
        put("nature", pk.pine(pine_m, 30 + i), (x, y), i * 71.0, s, r=1.0)
    put("camp", ridge_tent(m), (10.3, 5.4), 52.0, 0.92, r=2.1)
    put("camp", pk.crate(pm), (9.0, 3.7), 24.0, 0.6, r=0.5)
    put("camp", pk.barrel(pm), (-8.3, 2.4), 0.0, 0.74, r=0.5)
    put("camp", pk.crate(pm), (-9.0, 2.9), -18.0, 0.62, r=0.5)
    for i, (x, y, r_) in enumerate([(-9.6, -0.4, 0.6), (-11.3, 0.5, 0.42), (9.2, -0.6, 0.56), (11.0, 0.3, 0.4)]):
        put("nature", [pk.lumpy("pedra_l%d" % i, r_, (0, 0, r_ * 0.45), m["stone_d" if i % 2 else "stone"], (1.25, 0.95, 0.72), 0.3, 80 + i, 2)],
            (x, y), i * 55.0, r=r_)
    for i, (x, y, s, fl) in enumerate([(-3.9, 6.6, 1.0, "fl_pink"), (6.9, 3.0, 0.9, "fl_white"), (-8.1, 1.2, 1.1, "fl_yellow"),
                                       (5.0, -1.6, 0.85, "fl_pink"), (-4.4, -2.2, 0.9, "fl_blue"), (1.4, 8.4, 0.9, "fl_yellow"),
                                       (8.3, 6.2, 1.0, "fl_pink"), (-9.6, 6.0, 1.0, "fl_white")]):
        put("nature", shrub(m, 20 + i, fl), (x, y), i * 61.0, s, r=0.9)
    for i, (x, y, r_) in enumerate([(5.9, 1.2, 0.5), (-6.4, 0.2, 0.42), (4.7, -3.1, 0.36), (-4.0, -3.4, 0.44), (0.6, 6.6, 0.4), (-8.9, 3.9, 0.55)]):
        put("nature", [pk.lumpy("pedra%d" % i, r_, (0, 0, r_ * 0.45), m["stone" if i % 2 else "stone_d"], (1.2, 0.95, 0.7), 0.3, 40 + i, 2),
                       pk.lumpy("pedra_m%d" % i, r_ * 0.5, (r_ * 0.2, 0.05, r_ * 0.82), m["moss"], (1.2, 1.0, 0.3), 0.3, 50 + i, 2)], (x, y), i * 70.0, r=r_)

    # capim e flores: nada no chão batido, na trilha nem embaixo das peças
    def free(x, y, pad=0.0):
        if CALM[0] < x < CALM[1] and CALM[2] < y < CALM[3]:
            return False
        dx, dy = (x - CAMP_C.x) / 1.25, y - CAMP_C.y
        if dx * dx + dy * dy < (4.2 + pad) ** 2:
            return False
        if any((x - kx) ** 2 + (y - ky) ** 2 < (kr + pad) ** 2 for kx, ky, kr in keep_out):
            return False
        return all((Vector((x, y)) - p).length > 1.7 + pad for p in trail)

    bt = Batch()
    cols = ["fl_pink", "fl_white", "fl_yellow", "fl_blue"]
    n_t = n_f = 0
    for i in range(1400):
        a = rnd.uniform(0, math.tau)
        d = 3.9 + 15.0 * rnd.random() ** 1.6                   # mais cheio perto do acampamento
        x, y = CAMP_C.x + math.cos(a) * d * 1.15, CAMP_C.y + math.sin(a) * d
        if y < -8.6 or not free(x, y):
            continue
        near = d < 9.0 or y < -1.0
        if rnd.random() < (0.11 if near else 0.05):
            for _ in range(rnd.randint(2, 3)):
                bt.flower(rnd, m["blade"], m[cols[(i // 7) % 4]], (x + rnd.uniform(-0.35, 0.35), y + rnd.uniform(-0.35, 0.35)), rnd.uniform(0.26, 0.42))
                n_f += 1
        if n_t < 280:
            bt.tuft(rnd, m["blade_l" if i % 3 == 0 else "blade"], (x, y), 0.24, rnd.uniform(0.3, 0.55) * (1.25 if near else 1.0), 5 if near else 3)
            n_t += 1
    G["nature"] += bt.objects()

    # ---------- Aldara + fundo ----------
    G["aldara"] += aldara(m)
    far_pine = PM(m, tint=m["far_d"], tint_l=m["pine"])
    for i in range(16):                       # mata dos dois lados do portão (fecha as pontas do muro)
        side = -1 if i % 2 else 1
        x = TOWN_C.x - 3.0 + side * rnd.uniform(13.0, 40.0)
        y = rnd.uniform(26.0, 45.0) - abs(x - TOWN_C.x) * 0.12
        put("far", pk.pine(far_pine, 60 + i), (x, y), i * 53.0, rnd.uniform(1.5, 2.3))
    for i, (x, y) in enumerate([(-50.0, 37.0), (-62.0, 30.0), (52.0, 36.0), (64.0, 29.0)]):
        put("far", pk.pine(far_pine, 90 + i), (x, y), i * 67.0, 2.0 + 0.15 * (i % 3))
    for i, (x, y, r_, sx) in enumerate([(-178.0, 35.0, 32.0, 1.3), (182.0, 50.0, 32.0, 1.3)]):      # serra dos lados (fecha o horizonte)
        G["far"].append(pk.lumpy("serra_l%d" % i, r_, (x, y, -3.0), m["far"], (sx, 1.6, 0.5), 0.2, 76 + i, 2))
    for i, (x, y, r_, sx) in enumerate([(-95.0, 150.0, 40.0, 1.8), (-20.0, 170.0, 46.0, 1.6), (70.0, 160.0, 42.0, 1.9), (140.0, 130.0, 36.0, 1.6),
                                        (-150.0, 110.0, 34.0, 1.5)]):
        G["far"].append(pk.lumpy("serra%d" % i, r_, (x, y, -3.0), m["far"], (sx, 1.0, 0.5 + 0.08 * (i % 3)), 0.2, 70 + i, 2))

    # ---------- juntar: uma malha por grupo (uma superfície por material) ----------
    # (poucas malhas e poucas superfícies: perto = MS_camp, fundo = MS_backdrop; chão e chamas à parte)
    for name, keys in (("ground", ("ground",)), ("camp", ("pedestal", "camp", "fire", "nature")), ("backdrop", ("aldara", "far"))):
        parts = [o for k in keys for o in G[k]]
        for o in parts:
            if o.modifiers:
                ck._bake(o)
        ck._join(parts, "MS_" + name)
    # chamas: MS_flames = vazio no pé do fogo (tremer a escala dele ainda treme tudo), com 3 malhas filhas
    root = bpy.data.objects.new("MS_flames", None)
    root.empty_display_size = 0.3
    bpy.context.scene.collection.objects.link(root)
    root.location = FIRE
    for name, idx in FLAME_GROUPS:
        foot = Vector(flames[idx[0]][2])
        o = ck._join([p for i in idx for p in flames[i][:2]], name)
        o.data.transform(Matrix.Translation(-foot))
        o.parent = root
        o.location = foot
        o.visible_shadow = False

    # ---------- vazios ----------
    def empty(name, loc, mtx=None, **props):
        e = bpy.data.objects.new(name, None)
        e.empty_display_size = 0.4
        e.empty_display_type = "ARROWS"
        bpy.context.scene.collection.objects.link(e)
        e.matrix_world = (Matrix.Translation(Vector(loc)) @ mtx) if mtx is not None else Matrix.Translation(Vector(loc))
        for key, val in props.items():
            e[key] = val
        return e

    empty("SPOT_pedestal", (0, 0, PED_H))
    for name, (pos, look, fov) in CAMS.items():
        f = (Vector(look) - Vector(pos)).normalized()
        r = f.cross(Vector((0, 0, 1))).normalized()
        u = r.cross(f)
        empty(name, pos, Matrix((r, f, u)).transposed().to_4x4(), fov=fov, look_at=list(look))
    bpy.data.objects["CAM_create"]["subject_yaw"] = round(math.degrees(math.atan2(CAMS["CAM_create"][0][0], -CAMS["CAM_create"][0][1])), 1)
    for name, (pos, col, energy, rng) in LIGHTS.items():
        empty(name, pos, color=list(col), energy=energy, range=rng)
    empty("MS_sparks", SPARKS)
    bpy.context.view_layer.update()

    stats()
    if export:
        export_glb(path)
    return G


def stats():
    tot = 0
    n = 0
    surf = 0
    for o in bpy.context.scene.objects:
        if o.type != "MESH":
            continue
        t = sum(len(p.vertices) - 2 for p in o.data.polygons)
        tot += t
        n += 1
        k = len({p.material_index for p in o.data.polygons})
        surf += k
        print("MENU_SET %-12s tris=%5d superficies=%d" % (o.name, t, k))
    print("MENU_SET total: %d malhas, %d tris, %d superficies, %d materiais, vazios: %s" % (
        n, tot, surf, len({mt.name for o in bpy.context.scene.objects if o.type == "MESH" for mt in o.data.materials}),
        ", ".join(sorted(o.name for o in bpy.context.scene.objects if o.type == "EMPTY"))))
    return n, tot


def export_glb(path=OUT):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    ck.deselect_everything()
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=False, use_active_scene=True, export_apply=True,
                              export_animations=False, export_yup=True, export_materials="EXPORT", export_extras=True,
                              export_cameras=False)
    print("MENU_SET export: %s (%d KB)" % (path, os.path.getsize(path) // 1024))


# ---------------------------------------------------------------------------
# fotos de revisão (não entram no GLB: chame DEPOIS do export)
# ---------------------------------------------------------------------------
# o que o jogo precisa imitar: céu, sol baixo e ambiente do entardecer
DUSK = {
    "sky_top": (0.17, 0.17, 0.4), "sky_mid": (0.62, 0.4, 0.58), "sky_horizon": (1.0, 0.66, 0.44),
    "sun_color": (1.0, 0.62, 0.5), "sun_energy": 2.6, "sun_dir_from": (-0.55, 0.75, 0.36),      # de onde vem (Blender)
    "ambient": (0.5, 0.45, 0.66),
}


def frame_report(name="CAM_create", top=2.4):
    """Onde caem na tela (fração: x da esquerda, y de cima) os pés, o topo de um boneco de `top` m e as bordas do
    pedestal, em 16:9 e 21:9. Só conta (não mexe na cena)."""
    pos, look, fov = CAMS[name]
    pos = Vector(pos)
    f = (Vector(look) - pos).normalized()
    r = f.cross(Vector((0, 0, 1))).normalized()
    u = r.cross(f)
    t = math.tan(math.radians(fov) * 0.5)
    for label, asp in (("16:9", 16.0 / 9.0), ("21:9", 2560.0 / 1080.0)):
        def at(p):
            d = Vector(p) - pos
            return 0.5 + d.dot(r) / d.dot(f) / (t * asp) * 0.5, 0.5 - d.dot(u) / d.dot(f) / t * 0.5
        feet, head = at((0, 0, PED_H)), at((0, 0, PED_H + top))
        xs = [at((r * PED_R * k).xyz + Vector((0, 0, PED_H)))[0] for k in (-1.0, 1.0)]
        print("MENU_SET %s %s: pes x=%.3f y=%.3f, topo %.1f m y=%.3f, 1.7 m y=%.3f, pedestal x=%.3f..%.3f, dist=%.2f m"
              % (name, label, feet[0], feet[1], top, head[1], at((0, 0, PED_H + 1.7))[1], xs[0], xs[1], (pos - Vector((0, 0, PED_H))).length))


def _dummy(h=1.7):
    """Boneco de medida (1,7 m, chibi) em cima do pedestal, só para a foto. `h` > 1,7: ganha um cajado até `h` m (à
    direita dele = esquerda da tela) e uma crista no elmo, como um boneco de classe alto."""
    if h > 1.7:
        iron = ck.mat("pv_iron", (0.62, 0.62, 0.7), 1.0)
        gem = ck.mat("pv_gem", (0.5, 0.8, 1.0), 1.0)
        yaw = math.atan2(CAMS["CAM_create"][0][0], -CAMS["CAM_create"][0][1])      # o boneco vira para a CAM_create
        sx, sy = -math.cos(yaw) * 0.52, -math.sin(yaw) * 0.52                       # a mão direita dele (-X local)
        return _dummy() + [ck.tube("pv_cajado", (sx, sy, PED_H), (sx, sy, PED_H + h - 0.16), 0.035, 0.035, iron, 6),
                           ck.ball("pv_cajado_gema", 0.16, (sx, sy, PED_H + h - 0.16), gem),
                           ck.tube("pv_crista", (0, 0, PED_H + 1.6), (0, 0, PED_H + 2.05), 0.16, 0.02, iron, 6)]
    skin = ck.mat("pv_skin", (0.98, 0.84, 0.74), 1.0)
    cloth = ck.mat("pv_cloth", (0.72, 0.36, 0.36), 1.0)
    hair = ck.mat("pv_hair", (0.42, 0.3, 0.26), 1.0)
    z = PED_H
    return [ck.tube("pv_pernas", (0, 0, z), (0, 0, z + 0.45), 0.2, 0.22, hair, 8),
            ck.tube("pv_corpo", (0, 0, z + 0.42), (0, 0, z + 1.0), 0.3, 0.2, cloth, 8),
            ck.ball("pv_cabeca", 0.36, (0, 0, z + 1.3), skin),
            ck.ball("pv_cabelo", 0.39, (0, 0.05, z + 1.36), hair, (1, 1, 0.9)),
            pk.B("pv_bracos", (0.86, 0.16, 0.16), (0, 0, z + 0.85), cloth, 0.04)]


# fotos padrão: (câmera, (largura, altura), sufixo, com boneco de medida?)
SHOTS = (("CAM_title", (1280, 720), "", False), ("CAM_title", (2560, 1080), "_21x9", False),
         ("CAM_list", (1280, 720), "", True), ("CAM_list", (2560, 1080), "_21x9", True),
         ("CAM_create", (1280, 720), "", True), ("CAM_create", (2560, 1080), "_21x9", True))


def render(out_dir, tag="v1", shots=SHOTS, doll_h=1.7):
    """Uma foto por entrada de `shots`; devolve os caminhos. `doll_h` = altura do boneco de medida (ver `_dummy`)."""
    sc = bpy.context.scene
    os.makedirs(out_dir, exist_ok=True)
    for eng in ("BLENDER_EEVEE", "BLENDER_EEVEE_NEXT"):
        try:
            sc.render.engine = eng
            break
        except TypeError:
            pass
    try:
        sc.view_settings.view_transform = "Standard"
    except TypeError as e:
        print("view:", e)
    # céu em degradê (horizonte laranja -> lilás -> azul)
    w = bpy.data.worlds.new("pv_dusk")
    w.use_nodes = True
    nt = w.node_tree
    bg = next(n for n in nt.nodes if n.type == "BACKGROUND")
    tc = nt.nodes.new("ShaderNodeTexCoord")
    sep = nt.nodes.new("ShaderNodeSeparateXYZ")
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    mr = nt.nodes.new("ShaderNodeMapRange")
    mr.inputs[1].default_value, mr.inputs[2].default_value = 0.0, 0.3
    nt.links.new(tc.outputs["Generated"], sep.inputs[0])
    nt.links.new(sep.outputs[2], mr.inputs[0])
    nt.links.new(mr.outputs[0], ramp.inputs[0])
    nt.links.new(ramp.outputs[0], bg.inputs[0])
    el = ramp.color_ramp.elements
    el[0].position, el[0].color = 0.0, (*DUSK["sky_horizon"], 1)
    el[1].position, el[1].color = 1.0, (*DUSK["sky_top"], 1)
    mid = el.new(0.4)
    mid.color = (*DUSK["sky_mid"], 1)
    bg.inputs[1].default_value = 0.55
    sc.world = w
    extra = []

    def light(name, kind, loc, col, energy, **kw):
        ld = bpy.data.lights.new(name, kind)
        ld.color, ld.energy = col, energy
        for k, v in kw.items():
            setattr(ld, k, v)
        o = bpy.data.objects.new(name, ld)
        sc.collection.objects.link(o)
        o.location = loc
        extra.append(o)
        return o

    sun = light("pv_sun", "SUN", (0, 0, 20), DUSK["sun_color"], DUSK["sun_energy"])
    d = Vector(DUSK["sun_dir_from"]).normalized()
    sun.rotation_euler = d.to_track_quat("Z", "Y").to_euler()
    for name, (pos, col, energy, rng) in LIGHTS.items():
        light("pv_" + name, "POINT", pos, col, energy * 95.0, shadow_soft_size=0.25)
    doll = _dummy(doll_h)                     # (as chamas já saem sem sombra: a luz fica dentro delas)
    extra += doll
    sc.render.image_settings.file_format = "PNG"
    out = []
    for name, size, suffix, with_doll in shots:
        fov = CAMS[name][2]
        sc.render.resolution_x, sc.render.resolution_y = size
        for o in doll:
            o.hide_render = not with_doll
        cd = bpy.data.cameras.new("pv_" + name)
        cd.sensor_fit = "VERTICAL"
        cd.angle_y = math.radians(fov)
        cd.clip_end = 600.0
        co = bpy.data.objects.new("pv_" + name, cd)
        sc.collection.objects.link(co)
        e = bpy.data.objects[name].matrix_world              # o vazio: +Y = mira, +Z = cima -> câmera do Blender: -Z = mira
        co.matrix_world = e @ Matrix.Rotation(math.radians(90.0), 4, "X")
        extra.append(co)
        sc.camera = co
        sc.render.filepath = os.path.join(out_dir, "menu_set_%s_%s%s.png" % (tag, name, suffix))
        bpy.ops.render.render(write_still=True)
        print("MENU_SET render:", sc.render.filepath)
        out.append(sc.render.filepath)
    for o in extra:
        bpy.data.objects.remove(o, do_unlink=True)
    return out
