"""Lumeria, a Festa Eterna (city_lumeria, hub do Ato III parte 1, Lv 45-47): cidade murada em festa há quarenta anos.
GDD design/gdd/ato3-excesso-45-50.md (§2). Muralha circular creme (r = 102) com morros de vinhedo por fora; dentro:

  * OESTE  Bairro dos Lúcidos (hub seguro, murado, r = 28): chão cinza-azulado SEM enfeite, telhado de ardósia, o Sino
           Abafado no meio, cristal e serviços. A garganta de Kharzun chega no portão oeste dele (decisão D2).
  * CENTRO Praça dos Sinos com o Campanário de vidro rosado (marco, 18 m, fora das ruas).
  * NORTE  Mercado das Taças (fonte de taças, bancas) e o portão norte (Vinhas do Perfume, field_perfume).
  * LESTE  Ópera / Palácio do Duque (entrada da Galeria dos Espelhos, dg_mirrors).
  * SUL    Jardim das Fontes de Vinho; a sudeste o portão do Cortejo (field_parade).
  Lugares: Casa do Relojoeiro (cabana), Bairro dos Lúcidos (acampamento), Capela Selada (santuário), Ópera (masmorra).

Leitura de cima: cada bairro tem a cor do telhado (ardósia / rosa / damasco / lilás / menta / manteiga) e do chão; a festa
são as fileiras de lanternas e bandeirolas ao longo das ruas (linhas pontilhadas), palcos, mesas de banquete, máscaras
de porcelana e confete em TONS DO PRÓPRIO CHÃO (anel/mancha saturada no chão é aviso de golpe: nunca aqui).

Tudo que é visual vai em lote pelo `Dress` (célula de 36 m, cor no vértice); a sim recebe só colisores ocultos.
Os mapas vizinhos ainda não existem: field_perfume, field_parade e dg_mirrors saem em data["future_portals"].

Pilha de planos do chão (mm): manchas do calçamento 0,8/1,6/2,4 · relva de fora da muralha 4,6 · chão de bairro
(`Zone.patch`) 6,0 · relva do jardim 7,2 · rua 12 · praça 14 · confete 15,2 · canteiro/tapete 20+.

Estágios (WorldState, só o que muda no cenário; a lista vai em data["stage_tags"], o catálogo liga em conquest_vis):
  lum_acesa_a (até hx3_mirrors) / lum_acesa_b (até hx3_veil): as duas metades das lanternas acesas
  l0_barricada (até hx3_bells) / l1_portao_aberto (depois): portas laterais do Bairro
  l0_palacio_fechado (até hx3_bells): tábuas e correntes na porta da Ópera
  l1_forja_ana (hx3_bells): a forja do Ferreiro Anão no Bairro
  l3_duque (hx3_mirrors): estandartes do Duque na Ópera
  l0_confete (até hx3_veil) / l4_manha (hx3_veil): confete no chão / montes varridos, vassouras e carrinhos

    set RAGNAEX_ROOT=<projeto ou worktree>
    blender -b --factory-startup --python tools/blender/zones/run_zone.py -- build_lumeria <pasta_png> --export
    (LUMERIA_POI=<praca|bairro|mercado|opera|jardim|relojoeiro|capela|portao_n|portao_se|chegada> escolhe o alvo da CAM_poi;
     LUMERIA_CAM=<o mesmo> troca o alvo da CAM_game, que por padrão olha o Bairro)
"""
import math
import os
import random

from mathutils import Vector

import act2_dress
import act3_ready
import nature
import town_dress
import zone_lib
from dress import Dress
from zone_lib import B, Zone, along, mat, poly_dist

PERFUME_ARRIVE = (0.0, 107.7)            # spawn do field_perfume (build_perfume)
PARADE_ARRIVE = (-76.7, -64.4)           # spawn do field_parade (build_parade)
ZONE = "city_lumeria"
WALL_R = 102.0
BC, BR = (-75.0, 0.0), 28.0             # Bairro dos Lúcidos (hub)
B_PLAZA_R = 12.0
PLAZA_R = 22.0                          # Praça dos Sinos
TOWER = (0.0, -6.0)                     # Campanário (marco)
MARKET, MARKET_R = (0.0, -62.0), 16.0
OPERA = (75.0, -4.0)                    # corpo do Palácio/Ópera (a frente olha para oeste)
FORECOURT, FORECOURT_R = (51.0, -4.0), 11.0
GARDEN, GARDEN_R = (4.0, 62.0), 15.0
CLOCK = (52.0, -51.0)                   # Casa do Relojoeiro
CHAPEL = (-27.5, 37.0)                  # Capela Selada (ao norte do anel sudoeste: a porta lacrada olha para a rua e para a câmera)
SE_JUNCTION = (50.0, 40.0)
STAGE_DEG = (-40.0, -140.0)             # palcos da Praça dos Sinos
OPERA_STAGE = (39.5, -15.5)             # palco do largo da Ópera
GATE_W, GATE_N, GATE_SE = 180.0, -90.0, 40.0        # graus do jogo (x = cos, z = sin; -90 = norte)
B_GATES = [(0.0, 3.2), (180.0, 2.6), (-52.0, 2.3), (52.0, 2.3)]      # portões do Bairro (grau em volta de BC, meia-largura m)
KHARZUN_ARRIVE = (96.7, -20.6)          # chegada em field_kharzun (build_kharzun imprime "BACK lumeria")

Q_BELLS, Q_MIRRORS, Q_VEIL = "hx3_bells", "hx3_mirrors", "hx3_veil"
# ids do elenco (MonstersCatalog.ACT3_MOBS)
MOBS = {"reveler": "masked_reveler", "master": "ceremony_master", "chorister": "chorister", "hound": "silk_hound",
        "dancer": "veil_dancer", "reflection": "vain_reflection"}

PAVING = (0.76, 0.69, 0.64)              # calçamento creme (sugestão de MapDef.ground_color)
LUCID = (0.6, 0.66, 0.74)               # chão do Bairro: cinza-azulado
OUTSIDE = (0.5, 0.62, 0.42)
STONE, STONE_D = (0.9, 0.85, 0.76), (0.76, 0.7, 0.62)
LUCID_STONE, LUCID_STONE_D = (0.66, 0.7, 0.77), (0.52, 0.56, 0.64)
WINE = (0.42, 0.2, 0.34)                # vinho fosco das fontes (nunca brilha: não é aviso)
IVORY = (0.96, 0.93, 0.88)
OLD_GOLD = (0.8, 0.68, 0.42)
ROOFS = {
    "lucidos": [(0.42, 0.48, 0.6), (0.48, 0.54, 0.64), (0.38, 0.44, 0.54)],
    "centro": [(0.9, 0.62, 0.66), (0.94, 0.7, 0.72), (0.84, 0.56, 0.62)],
    "norte": [(0.96, 0.76, 0.54), (0.98, 0.82, 0.62), (0.9, 0.68, 0.5)],
    "leste": [(0.72, 0.62, 0.86), (0.8, 0.7, 0.9), (0.64, 0.56, 0.8)],
    "sul": [(0.58, 0.8, 0.7), (0.68, 0.86, 0.76), (0.5, 0.72, 0.64)],
    "oeste": [(0.95, 0.88, 0.62), (0.97, 0.92, 0.72), (0.9, 0.82, 0.56)],
}
WALLS = [(0.95, 0.91, 0.84), (0.92, 0.86, 0.8), (0.9, 0.9, 0.86)]
BUNTING = [(0.98, 0.72, 0.78), (0.74, 0.86, 0.98), (0.99, 0.93, 0.66), (0.78, 0.94, 0.8), (0.84, 0.74, 0.96)]


def H(r, deg, c=(0.0, 0.0)):
    return (round(c[0] + math.cos(math.radians(deg)) * r, 2), round(c[1] + math.sin(math.radians(deg)) * r, 2))


def polar(z, deg, inset):
    a = math.radians(deg)
    r = z.rim_r(a) - inset
    return (round(math.cos(a) * r, 1), round(math.sin(a) * r, 1))


def facing(dx, dz):
    """Rotação (graus) com que o lado +yb local (porta, frente) aponta para a direção (dx, dz) do jogo."""
    return round(math.degrees(math.atan2(-dx, -dz)), 1)


def loc(c, rot, x, yb):
    """Ponto local (x, yb) de uma peça em `c` com rotação `rot` -> jogo (x, z)."""
    p = Dress._xf(c, rot, (0, 0))(x, yb, 0)
    return (p.x, -p.y)


def district(p):
    v = Vector(p)
    if (v - Vector(BC)).length < BR + 1.0:
        return "lucidos"
    if v.length < 36.0:
        return "centro"
    a = math.degrees(math.atan2(v.y, v.x))
    if -135.0 <= a < -45.0:
        return "norte"
    if -45.0 <= a < 45.0:
        return "leste"
    if 45.0 <= a < 135.0:
        return "sul"
    return "oeste"


# ---------------------------------------------------------------------------------------------------------------
# peças
# ---------------------------------------------------------------------------------------------------------------
def ring_wall(z, d, name, c, r, gates, h, thick, col, col_d, seg_len=3.6, skip=None, towers=True, roof=(0.9, 0.62, 0.66)):
    """Muralha de pedra em anel (lote): trechos retos com faixa e ameias, vão em cada portão (grau, meia-largura em m) e
    um torreão baixo de cada lado do vão. `skip(grau)` pula trechos (onde outro muro faz o papel). Colisor por trecho."""
    m, md = d.m("muro_" + name, col), d.m("muro_%s_esc" % name, col_d)
    n = max(16, int(math.tau * r / seg_len))
    seg = math.tau * r / n + 0.1
    for i in range(n):
        am = math.tau * (i + 0.5) / n
        deg = math.degrees(am)
        if any(zone_lib.angdiff(am, math.radians(g)) * r < hw + seg * 0.5 for g, hw in gates):
            continue
        if skip and skip(deg):
            continue
        p = (c[0] + math.cos(am) * r, c[1] + math.sin(am) * r)
        rot = along(-math.sin(am), math.cos(am))
        d.box("muro", m, p, (seg, h, thick), rot, 0.0)
        d.box("muro", md, p, (seg, 0.3, thick + 0.3), rot, h)
        if i % 2 == 0:
            d.box("muro", m, p, (seg * 0.55, 0.5, thick + 0.3), rot, h + 0.3)
        z.ob("wall", p[0], p[1], (seg, h, thick + 0.4), rot, visible=False)
    if towers:
        rm = d.m("muro_%s_teto" % name, roof)
        for g, hw in gates:
            da = math.degrees((hw + 1.5) / r)
            for s in (-1, 1):
                q = H(r, g + s * da, c)
                d.cyl("muro", m, q, 1.5, 1.35, h + 1.6, 0.0, 8)
                d.cyl("muro", md, q, 1.55, 1.55, 0.3, h + 1.6, 8)
                d.cyl("muro", rm, q, 1.75, 0.0, 1.9, h + 1.9, 8)
                z.ob("pillar", q[0], q[1], (3.0, h + 1.6, 3.0), visible=False)


def gate_spur(z, d, deg, hw, col, col_d, h=4.2):
    """Fecha o corredor do portão até a encosta (dois muros radiais): a faixa de relva de fora da muralha não vira rota."""
    a = math.radians(deg)
    r1 = z.rim_r(a) + 5.0
    L = r1 - (WALL_R - 0.8)
    mid = (WALL_R - 0.8 + r1) * 0.5
    m, md = d.m("muro_cidade", col), d.m("muro_cidade_esc", col_d)
    for s in (-1, 1):
        p = (math.cos(a) * mid - math.sin(a) * s * (hw + 0.9), math.sin(a) * mid + math.cos(a) * s * (hw + 0.9))
        rot = along(math.cos(a), math.sin(a))
        d.box("muro", m, p, (L, h, 1.2), rot, 0.0)
        d.box("muro", md, p, (L, 0.3, 1.5), rot, h)
        z.ob("wall", p[0], p[1], (L, h, 1.6), rot, visible=False)


def house(z, d, c, rot, L, W, h, wall, roof, name="casa", extra=True):
    """Casa de duas águas (lote) + colisor oculto com a cor do telhado (minimapa)."""
    wm = d.m("parede_%d_%d" % (int(wall[0] * 100), int(wall[2] * 100)), wall)
    rm = d.m("telha_%d_%d_%d" % (int(roof[0] * 100), int(roof[1] * 100), int(roof[2] * 100)), roof)
    town_dress.gable(d, name, wm, rm, c, L, W, h, h + 1.3, rot, door=(0.46, 0.34, 0.3))
    if extra:
        q = loc(c, rot, L * 0.26, -W * 0.14)                 # chaminé
        d.box(name, d.m("chamine", (0.74, 0.68, 0.62)), q, (0.6, 1.2, 0.6), rot, h + 0.4)
        for sx in (-0.3, 0.3):                               # janelas da frente
            q = loc(c, rot, L * sx, W * 0.5 + 0.03)
            d.box(name, d.m("janela", (0.42, 0.5, 0.62)), q, (0.8, 0.9, 0.08), rot, 1.3)
    z.ob("house", c[0], c[1], (L, h + 1.2, W), rot, visible=False, color=wall, roof=roof)


def mask(d, g, c, y, rot, s=1.0, tear=(0.86, 0.5, 0.62)):
    """Máscara de porcelana lisa com uma única lágrima pintada (o emblema do Excesso): oval em pé, de frente para +yb."""
    f = Dress._xf(c, rot, (0, 0))
    bm = d._bm(g, d.m("mascara_marfim", IVORY), c[0], c[1])
    n = 10
    front, back = [], []
    for i in range(n):
        a = math.tau * i / n
        x, u = math.cos(a) * 0.56 * s, math.sin(a) * 0.74 * s * (1.0 if math.sin(a) > 0 else 1.18)
        front.append(bm.verts.new(f(x * 0.9, 0.14 * s, u, y)))
        back.append(bm.verts.new(f(x, 0.0, u, y)))
    bm.faces.new(front)
    bm.faces.new(list(reversed(back)))
    for i in range(n):
        bm.faces.new((back[i], back[(i + 1) % n], front[(i + 1) % n], front[i]))
    dark = d.m("mascara_olho", (0.2, 0.16, 0.22))
    for sx in (-1, 1):
        q = loc(c, rot, sx * 0.22 * s, 0.15 * s)
        d.box(g, dark, q, (0.24 * s, 0.09 * s, 0.05), rot, y + 0.12 * s)
    q = loc(c, rot, -0.24 * s, 0.15 * s)
    d.box(g, d.m("mascara_lagrima", tear), q, (0.09 * s, 0.26 * s, 0.05), rot, y - 0.22 * s)


def stage(z, d, c, rot, curtain=(0.52, 0.22, 0.32)):
    """Palco baixo de rua: tablado, moldura com cortinas de veludo dobradas e a máscara no alto. A frente é +yb."""
    wood = d.m("palco_madeira", (0.66, 0.5, 0.36))
    trim = d.m("palco_filete", OLD_GOLD)
    d.box("palco", wood, c, (7.0, 0.7, 4.4), rot, 0.0)
    d.box("palco", trim, loc(c, rot, 0.0, 2.2), (7.1, 0.16, 0.12), rot, 0.6)
    d.box("palco", wood, loc(c, rot, 0.0, 2.75), (2.2, 0.35, 1.1), rot, 0.0)          # degrau
    for sx in (-3.3, 3.3):
        d.box("palco", wood, loc(c, rot, sx, -1.9), (0.28, 4.0, 0.28), rot, 0.7)
    d.box("palco", trim, loc(c, rot, 0.0, -1.9), (7.0, 0.36, 0.34), rot, 4.5)
    cm = d.m("pano_palco_%d" % int(curtain[0] * 100), curtain)
    hm = d.m("pano_palco_%d_barra" % int(curtain[0] * 100), tuple(k * 0.8 for k in curtain))
    d.cloth("palco", cm, loc(c, rot, -3.15, -1.75), 1.7, 3.6, rot, 0.85, 0.0, None, hm)
    d.cloth("palco", cm, loc(c, rot, 3.15, -1.75), 1.7, 3.6, rot + 180.0, 0.85, 0.0, None, hm)
    back = d.m("pano_palco_fundo", (0.9, 0.82, 0.86))
    d.cloth("palco", back, loc(c, rot, -1.5, -2.0), 3.0, 3.2, rot, 1.2, 0.0, "swallow", None)
    mask(d, "palco", loc(c, rot, 0.0, -1.72), 5.5, rot, 1.25)
    z.ob("wall", c[0], c[1], (7.0, 1.2, 4.4), rot, visible=False)


def banquet(z, d, c, rot, L=6.0):
    """Mesa de banquete de rua: toalha clara, taças e travessas, banquinhos (alguns tombados)."""
    wood = d.m("mesa_madeira", (0.56, 0.42, 0.3))
    d.box("banquete", wood, c, (L, 0.78, 1.3), rot, 0.0)
    d.box("banquete", d.m("mesa_toalha", (0.96, 0.92, 0.86)), c, (L + 0.2, 0.06, 1.5), rot, 0.78)
    d.box("banquete", d.m("mesa_caminho", (0.86, 0.7, 0.76)), c, (L + 0.24, 0.02, 0.5), rot, 0.84)
    cup, dish = d.m("taca", OLD_GOLD), d.m("travessa", (0.82, 0.8, 0.84))
    food = [d.m("comida_a", (0.72, 0.42, 0.5)), d.m("comida_b", (0.9, 0.78, 0.5)), d.m("comida_c", (0.6, 0.74, 0.5))]
    n = int(L / 0.9)
    for i in range(n):
        x = -L * 0.5 + 0.5 + i * (L - 1.0) / max(1, n - 1)
        q = loc(c, rot, x, 0.38 if i % 2 else -0.38)
        d.cyl("banquete", cup, q, 0.05, 0.11, 0.26, 0.86, 6)
        if i % 2 == 0:
            q = loc(c, rot, x, 0.0)
            d.cyl("banquete", dish, q, 0.3, 0.34, 0.05, 0.86, 8)
            d.rock("banquete", food[(i // 2) % 3], q, 0.2, 0.9, 0.7)
    for i in range(n - 1):
        x = -L * 0.5 + 0.9 + i * (L - 1.8) / max(1, n - 2)
        for s in (-1, 1):
            q = loc(c, rot, x + 0.2 * s, s * 1.15)
            if (i + s) % 4 == 0:                             # banquinho tombado
                d.cyl("banquete", wood, q, 0.2, 0.2, 0.44, 0.2, 6, rot, tilt=(90, 0))
            else:
                d.cyl("banquete", wood, q, 0.2, 0.18, 0.44, 0.0, 6)
    z.ob("crate", c[0], c[1], (L, 0.9, 1.4), rot, visible=False)


def barricade(z, d, c, rot, L=3.4, collide=True):
    """Barricada de móveis dos Lúcidos: mesa virada, armário, cadeiras, colchão, barril e tábuas cruzadas."""
    wood = d.m("barricada_madeira", (0.5, 0.4, 0.34))
    dark = d.m("barricada_escura", (0.36, 0.3, 0.3))
    d.box("barricada", wood, loc(c, rot, -L * 0.22, 0.0), (1.9, 1.3, 0.14), rot, 0.0, tilt=(-14, 0))     # tampo de mesa de pé
    d.box("barricada", dark, loc(c, rot, L * 0.28, -0.1), (1.0, 2.0, 0.6), rot + 8.0, 0.0)                  # armário
    d.box("barricada", d.m("barricada_colchao", (0.8, 0.82, 0.86)), loc(c, rot, 0.1, 0.5), (1.7, 0.3, 0.8), rot - 12.0, 0.55, tilt=(0, 9))
    for k, (x, yb) in enumerate(((-L * 0.42, 0.5), (L * 0.05, -0.55), (L * 0.46, 0.45))):                   # cadeiras
        q = loc(c, rot, x, yb)
        d.box("barricada", wood, q, (0.5, 0.5, 0.5), rot + 25.0 * k, 0.0)
        d.box("barricada", wood, q, (0.5, 0.6, 0.08), rot + 25.0 * k, 0.5, tilt=(10, 0))
    d.barrel(loc(c, rot, -L * 0.5, -0.3), 0.9, g="barricada", color=(0.48, 0.4, 0.36))
    p0, p1 = loc(c, rot, -L * 0.5, 0.2), loc(c, rot, L * 0.5, -0.1)
    d.tube("barricada", dark, [(p0[0], 0.2, p0[1]), (p1[0], 1.7, p1[1])], 0.07, 0.07, 4)
    d.tube("barricada", dark, [(p0[0], 1.6, p0[1]), (p1[0], 0.3, p1[1])], 0.07, 0.07, 4)
    if collide:
        z.ob("wall", c[0], c[1], (L, 1.8, 1.5), rot, visible=False)


def goblet_fountain(z, d, c):
    """Fonte das Taças (Mercado): bacia de pedra com vinho fosco e três andares de taças de ouro velho (4,4 m)."""
    st, std = d.m("fonte_pedra", STONE), d.m("fonte_pedra_esc", STONE_D)
    gold = d.m("taca", OLD_GOLD)
    wine = d.m("vinho_fosco", WINE)
    d.cyl("fonte", std, c, 3.4, 3.3, 0.3, 0.0, 14)
    d.cyl("fonte", st, c, 3.1, 3.2, 0.6, 0.3, 14)
    d.cyl("fonte", wine, c, 2.9, 2.9, 0.06, 0.78, 14)
    d.cyl("fonte", st, c, 0.5, 0.36, 3.2, 0.3, 8)
    for tier, (r, y, n, s) in enumerate(((1.7, 1.2, 8, 1.0), (1.05, 2.2, 6, 0.85), (0.5, 3.1, 4, 0.7))):
        d.cyl("fonte", std, c, r + 0.2, r + 0.3, 0.12, y, 10)
        for k in range(n):
            q = H(r, 360.0 * k / n + tier * 20.0, c)
            d.cyl("fonte", gold, q, 0.07 * s, 0.07 * s, 0.22 * s, y + 0.12, 5)
            d.cyl("fonte", gold, q, 0.09 * s, 0.26 * s, 0.34 * s, y + 0.12 + 0.22 * s, 6)
    d.cyl("fonte", gold, c, 0.12, 0.12, 0.3, 3.5, 6)
    d.cyl("fonte", gold, c, 0.16, 0.5, 0.6, 3.8, 8)
    z.ob("pillar", c[0], c[1], (6.8, 4.4, 6.8), visible=False)


def wine_fountain(z, d, c, s=1.0, top="mask"):
    """Fonte de vinho do Jardim: bacia baixa, vinho fosco, pedestal com máscara (ou jarro) de onde o vinho escorre."""
    st, std = d.m("fonte_pedra", STONE), d.m("fonte_pedra_esc", STONE_D)
    wine = d.m("vinho_fosco", WINE)
    d.cyl("fonte", st, c, 2.6 * s, 2.7 * s, 0.55, 0.0, 12)
    d.cyl("fonte", wine, c, 2.4 * s, 2.4 * s, 0.05, 0.5, 12)
    d.cyl("fonte", std, c, 0.6 * s, 0.45 * s, 1.5 * s, 0.0, 8)
    d.cyl("fonte", st, c, 0.95 * s, 1.1 * s, 0.2, 1.5 * s, 10)
    d.cyl("fonte", wine, c, 0.9 * s, 0.9 * s, 0.04, 1.5 * s + 0.2, 10)
    if top == "mask":
        mask(d, "fonte", (c[0], c[1] - 0.05), 1.5 * s + 1.1, 180.0, 0.9 * s)
    else:
        d.cyl("fonte", d.m("taca", OLD_GOLD), c, 0.2 * s, 0.5 * s, 0.9 * s, 1.5 * s + 0.2, 8)
    for k in range(3):                                       # fios de vinho caindo na bacia
        q = H(1.0 * s, 120.0 * k + 30.0, c)
        d.box("fonte", wine, q, (0.1, 1.5 * s - 0.4, 0.1), 0.0, 0.5)
    z.ob("pillar", c[0], c[1], (5.4 * s, 2.6, 5.4 * s), visible=False)


def campanario(z, d, c):
    """Marco: o Campanário de vidro rosado (18,3 m). Base de pedra creme, fuste de vidro rosa com nervuras e relógio parado,
    sineira aberta com os sinos de bronze, agulha rosa. Peça alta (`det_alto`: o jogo a deixa translúcida na frente do boneco)."""
    d.tall(c)
    st, std = d.m("torre_pedra", STONE), d.m("torre_pedra_esc", STONE_D)
    glass, glass_d = d.m("torre_vidro_rosa", (0.97, 0.72, 0.78)), d.m("torre_vidro_rosa_esc", (0.88, 0.58, 0.68))
    bronze = d.m("torre_bronze", (0.72, 0.56, 0.34))
    d.cyl("torre", std, c, 3.9, 3.7, 0.5, 0.0, 8, 22.5)
    d.cyl("torre", st, c, 3.4, 3.0, 3.6, 0.5, 8, 22.5)
    d.cyl("torre", std, c, 3.2, 3.2, 0.35, 4.1, 8, 22.5)
    d.cyl("torre", glass, c, 2.6, 2.3, 7.6, 4.45, 8, 22.5)
    for k in range(4):                                       # faixas mais escuras do vitral
        d.cyl("torre", glass_d, c, 2.6 - 0.08 * k - 0.04, 2.6 - 0.08 * k - 0.1, 0.22, 5.4 + 1.9 * k, 8, 22.5)
    for k in range(8):                                       # nervuras de pedra nas quinas
        q = H(2.5, 45.0 * k + 22.5, c)
        d.box("torre", st, q, (0.34, 7.6, 0.34), -(45.0 * k + 22.5), 4.45, tilt=(0, 0))
    for k in range(4):                                       # relógio parado nas quatro faces
        a = 90.0 * k
        q = H(2.5, a, c)
        rot = facing(math.cos(math.radians(a)), math.sin(math.radians(a)))
        d.cyl("torre", d.m("torre_relogio", IVORY), q, 0.95, 0.95, 0.12, 9.6, 10, rot, tilt=(90, 0))
        d.box("torre", std, loc(q, rot, 0.0, 0.14), (0.08, 0.7, 0.05), rot, 9.6, tilt=(0, 0))
        d.box("torre", std, loc(q, rot, 0.22, 0.14), (0.5, 0.08, 0.05), rot, 9.56)
    d.cyl("torre", std, c, 2.7, 2.9, 0.4, 12.05, 8, 22.5)
    for k in range(8):                                       # sineira: oito colunas
        q = H(2.35, 45.0 * k + 22.5, c)
        d.cyl("torre", st, q, 0.26, 0.22, 2.5, 12.45, 6)
    d.cyl("torre", bronze, c, 1.15, 0.5, 1.2, 12.9, 8)                                 # o sino grande
    for k in range(4):
        q = H(1.5, 90.0 * k + 45.0, c)
        d.cyl("torre", bronze, q, 0.42, 0.2, 0.55, 13.5, 6)
    d.cyl("torre", std, c, 2.9, 3.1, 0.4, 14.95, 8, 22.5)
    d.cyl("torre", d.m("torre_agulha", (0.92, 0.6, 0.68)), c, 2.8, 0.0, 3.0, 15.35, 8, 22.5)
    d.cyl("torre", d.m("taca", OLD_GOLD), c, 0.22, 0.22, 0.5, 17.9, 6)
    for k, col in enumerate((BUNTING[0], BUNTING[2], BUNTING[4], BUNTING[1])):         # fitas compridas da sineira até quase o chão
        a = 90.0 * k + 45.0
        q = H(3.05, a, c)
        cm = d.m("pano_fita_%d_%d" % (int(col[0] * 100), int(col[2] * 100)), col)
        d.cloth("torre", cm, q, 0.9, 8.4, -a + 90.0, 3.6, -0.45, "swallow", None)
    d.tall()
    z.ob("pillar", c[0], c[1], (7.6, 18.0, 7.6), visible=False)


def opera(z, d, d_closed, d_duke, c):
    """Ópera / Palácio do Duque: corpo lilás claro com cúpula verde-água, pórtico de seis colunas virado para oeste (o
    largo), duas alas baixas. A porta é a entrada da Galeria dos Espelhos; fechada com tábuas e correntes até hx3_bells."""
    rot = facing(-1.0, 0.0)
    wall, wall_d = d.m("opera_parede", (0.9, 0.85, 0.92)), d.m("opera_parede_esc", (0.76, 0.7, 0.82))
    teal = d.m("opera_cupula", (0.54, 0.78, 0.74))
    teal_d = d.m("opera_cupula_esc", (0.42, 0.66, 0.64))
    d.tall(c)
    d.box("opera", wall, c, (20.0, 7.0, 12.0), rot, 0.0)
    d.box("opera", wall_d, c, (20.6, 0.5, 12.6), rot, 7.0)
    d.box("opera", wall, c, (13.0, 1.4, 9.0), rot, 7.5)
    d.cyl("opera", teal_d, c, 4.9, 4.7, 0.9, 8.9, 12)
    d.cyl("opera", teal, c, 4.6, 3.3, 1.6, 9.8, 12)
    d.cyl("opera", teal, c, 3.3, 1.4, 1.1, 11.4, 12)
    d.cyl("opera", teal_d, c, 1.4, 0.0, 0.9, 12.5, 12)
    d.cyl("opera", d.m("taca", OLD_GOLD), c, 0.16, 0.16, 0.9, 13.2, 6)
    for i in range(6):                                       # pórtico
        q = loc(c, rot, -6.25 + 2.5 * i, 8.2)
        d.cyl("opera", wall, q, 0.46, 0.4, 5.2, 0.6, 8)
    d.box("opera", wall_d, loc(c, rot, 0.0, 7.3), (14.6, 0.6, 3.0), rot, 5.8)
    f = Dress._xf(loc(c, rot, 0.0, 8.7), rot, (0, 0))
    town_dress._tri(d, "opera", wall, c, [f(-7.3, 0, 6.4), f(7.3, 0, 6.4), f(0, 0, 8.4)], n=f(0, -2.6, 0) - f(0, 0, 0))
    mask(d, "opera", loc(c, rot, 0.0, 8.74), 7.2, rot, 1.1)
    for i in range(3):                                       # escadaria
        d.box("opera", wall_d, loc(c, rot, 0.0, 7.6 + 0.9 * i), (14.8 - 0.0 * i, 0.6 - 0.2 * i, 3.4 - 0.2 * i), rot, 0.0)
    d.box("opera", d.m("opera_porta", (0.16, 0.13, 0.2)), loc(c, rot, 0.0, 6.04), (3.0, 4.2, 0.12), rot, 0.6)
    for s in (-1, 1):                                        # alas
        q = loc(c, rot, s * 13.4, -1.0)
        d.box("opera", wall, q, (6.8, 5.0, 8.0), rot, 0.0)
        d.box("opera", wall_d, q, (7.2, 0.4, 8.4), rot, 5.0)
        d.cyl("opera", teal, q, 4.6, 0.0, 2.4, 5.4, 4, rot + 45.0)
    d.tall()
    z.ob("house", c[0], c[1], (20.0, 9.0, 12.0), rot, visible=False, color=(0.9, 0.85, 0.92), roof=(0.54, 0.78, 0.74))
    for s in (-1, 1):
        q = loc(c, rot, s * 13.4, -1.0)
        z.ob("house", q[0], q[1], (6.8, 6.0, 8.0), rot, visible=False, color=(0.9, 0.85, 0.92), roof=(0.54, 0.78, 0.74))
        q = loc(c, rot, s * 6.0, 8.0)                        # pórtico: só as pontas colidem (a porta fica livre)
        z.ob("wall", q[0], q[1], (3.4, 5.0, 3.6), rot, visible=False)
    door = loc(c, rot, 0.0, 6.9)
    front = loc(c, rot, 0.0, 12.6)
    # fechado (L0): tábuas cruzadas, corrente e um selo de porcelana na porta
    plank = d_closed.m("palacio_tabua", (0.5, 0.4, 0.34))
    for k, (x0, y0, x1, y1) in enumerate(((-1.5, 1.0, 1.5, 3.8), (-1.5, 3.8, 1.5, 1.0), (-1.5, 2.4, 1.5, 2.5))):
        a, b = loc(c, rot, x0, 6.2), loc(c, rot, x1, 6.2)
        d_closed.tube("palacio", plank, [(a[0], y0, a[1]), (b[0], y1, b[1])], 0.13, 0.13, 4)
    mask(d_closed, "palacio", loc(c, rot, 0.0, 6.3), 2.5, rot, 0.6)
    # L3 (Duque libertado): dois estandartes verde-água e ouro nas alas
    for s in (-1, 1):
        q = loc(c, rot, s * 9.0, 9.4)
        d_duke.flag(q, (0.5, 0.76, 0.72), h=6.0, rot=rot, tatter=False, w=1.4, drop=2.6, pole=(0.8, 0.68, 0.42))
    return rot, door, front


def chapel(z, d, c, rot):
    """Capela Selada da Aurora (santuário): nave branca de telhado azul, sineira sem sino, a porta lacrada com tábuas e o
    selo dourado; cerca baixa de túmulos em volta."""
    wall = d.m("capela_parede", (0.93, 0.93, 0.96))
    roof = d.m("capela_telha", (0.42, 0.54, 0.8))
    town_dress.gable(d, "capela", wall, roof, c, 5.6, 8.6, 3.8, 6.0, rot)
    q = loc(c, rot, 0.0, 3.4)
    d.box("capela", wall, q, (1.6, 2.2, 1.6), rot, 5.2)
    d.cyl("capela", roof, q, 1.5, 0.0, 1.6, 7.4, 4, rot + 45.0)
    door = loc(c, rot, 0.0, 4.34)
    d.box("capela", d.m("capela_porta", (0.4, 0.32, 0.3)), door, (1.7, 2.6, 0.1), rot, 0.0)
    plank = d.m("capela_tabua", (0.56, 0.46, 0.38))
    for y0, y1 in ((0.5, 2.3), (2.3, 0.5)):
        a, b = loc(c, rot, -1.0, 4.46), loc(c, rot, 1.0, 4.46)
        d.tube("capela", plank, [(a[0], y0, a[1]), (b[0], y1, b[1])], 0.1, 0.1, 4)
    d.cyl("capela", d.m("capela_selo", (0.94, 0.84, 0.5)), loc(c, rot, 0.0, 4.5), 0.34, 0.34, 0.08, 1.4, 8, rot, tilt=(90, 0))
    z.ob("house", c[0], c[1], (5.6, 5.0, 8.6), rot, visible=False, color=(0.93, 0.93, 0.96), roof=(0.42, 0.54, 0.8))
    stone = d.m("capela_lapide", (0.78, 0.78, 0.82))
    for k, (x, yb) in enumerate(((-5.2, -2.0), (-5.6, 0.6), (-5.0, 3.0), (5.2, -1.6), (5.5, 1.4))):
        q = loc(c, rot, x, yb)
        d.box("capela", stone, q, (0.7, 0.9 + 0.15 * (k % 2), 0.2), rot + 8.0 * (k % 3 - 1), 0.0)
    for s in (-1, 1):
        a, b = loc(c, rot, s * 6.8, -4.6), loc(c, rot, s * 6.8, 4.8)
        d.fence_run(a, b, 0.8, "capela", color=(0.7, 0.7, 0.74), gap=1.9)
    return loc(c, rot, 1.8, 6.2), loc(c, rot, 0.0, 7.6)


def clock_house(z, d, c, rot):
    """Casa do Relojoeiro (cabana): casa de telhado cobre com uma torrinha de relógio (6,4 m) e engrenagens na parede."""
    wall = (0.93, 0.88, 0.78)
    roofc = (0.62, 0.74, 0.66)
    house(z, d, c, rot, 7.0, 5.6, 3.2, wall, roofc, name="relojoeiro")
    t = loc(c, rot, 4.6, 0.6)
    wm, rm = d.m("relojoeiro_torre", (0.88, 0.82, 0.72)), d.m("relojoeiro_telha", roofc)
    d.box("relojoeiro", wm, t, (2.2, 5.0, 2.2), rot, 0.0)
    d.cyl("relojoeiro", rm, t, 1.9, 0.0, 1.5, 5.0, 4, rot + 45.0)
    d.cyl("relojoeiro", d.m("torre_relogio", IVORY), loc(t, rot, 0.0, 1.12), 0.8, 0.8, 0.1, 3.9, 10, rot, tilt=(90, 0))
    dark = d.m("relojoeiro_ferro", (0.3, 0.28, 0.32))
    d.box("relojoeiro", dark, loc(t, rot, 0.0, 1.22), (0.07, 0.6, 0.04), rot, 3.9)
    d.box("relojoeiro", dark, loc(t, rot, 0.18, 1.22), (0.42, 0.07, 0.04), rot, 3.87)
    z.ob("pillar", t[0], t[1], (2.3, 5.0, 2.3), visible=False)
    brass = d.m("relojoeiro_latao", (0.82, 0.68, 0.36))
    for k, (x, r) in enumerate(((-2.6, 0.5), (-1.9, 0.34), (-3.1, 0.3))):                # engrenagens encostadas
        q = loc(c, rot, x, 3.0 + 0.1 * k)
        d.cyl("relojoeiro", brass, q, r, r, 0.1, r + 0.02, 8, rot, tilt=(78, 0))
    d.signpost(loc(c, rot, 2.2, 4.2), rot, n=1)
    return loc(c, rot, -0.6, 4.0), loc(c, rot, 0.0, 6.0)


def muffled_bell(z, d, c):
    """Centro do Bairro: o Sino Abafado. Os Lúcidos tiraram o sino da própria capela e o enrolaram em lona para não
    ouvir a festa: cavalete de madeira (3,6 m), sino embrulhado, cordas, e a mesa comum ao lado. Nada passa de 4 m."""
    wood = d.m("sino_madeira", (0.44, 0.38, 0.36))
    d.cyl("sino", d.m("sino_base", LUCID_STONE), c, 2.3, 2.2, 0.3, 0.0, 10)
    for s in (-1, 1):
        for t in (-1, 1):
            q0, q1 = (c[0] + s * 1.5, c[1] + t * 0.8), (c[0] + s * 1.05, c[1])
            d.tube("sino", wood, [(q0[0], 0.3, q0[1]), (q1[0], 3.5, q1[1])], 0.12, 0.1, 5)
    d.tube("sino", wood, [(c[0] - 1.3, 3.5, c[1]), (c[0] + 1.3, 3.5, c[1])], 0.13, 0.13, 5)
    canvas = d.m("sino_lona", (0.82, 0.84, 0.88))
    d.cyl("sino", canvas, c, 1.0, 0.5, 1.5, 1.7, 8)
    d.cyl("sino", canvas, c, 0.5, 0.2, 0.3, 3.2, 8)
    rope = d.m("sino_corda", (0.62, 0.56, 0.46))
    for y in (2.0, 2.5, 2.9):
        r = 1.0 - (y - 1.7) * 0.33 + 0.03
        d.cyl("sino", rope, c, r, r - 0.03, 0.08, y, 8, cap=False)
    z.ob("pillar", c[0], c[1], (3.6, 3.6, 3.6), visible=False)


def lucid_life(z, d):
    """Vida sóbria do Bairro (sem enfeite de festa): roda de lajes em tons do próprio chão em volta do Sino (a leitura do
    centro: 6,2 m de 12), mesa comum, tendas de abrigo, varais, mantimentos e canteiros de horta junto às casas."""
    light, dark = act2_dress.floor_tone_colors((0.7, 0.75, 0.82), 0.1)
    d.blob("roda", d.m("patch_roda_esc", dark), BC, 6.2, 0.0172, 0.03)
    d.blob("roda", d.m("patch_roda_clara", light), BC, 4.3, 0.018, 0.03)
    slab = d.m("patch_roda_raio", tuple(k * 0.94 for k in dark))
    for k in range(8):                                       # raios de laje (tons do chão, foscos)
        q = H(5.25, 45.0 * k + 22.5, BC)
        d.box("roda", slab, q, (1.7, 0.012, 0.5), -(45.0 * k + 22.5), 0.0186)
    wood = d.m("lucido_madeira", (0.5, 0.46, 0.46))
    cloth = d.m("lucido_toalha", (0.86, 0.88, 0.92))
    tq = H(8.6, 96.0, BC)                                     # mesa comum (onde a Irmã Celeste reparte o pão)
    d.box("mesa", wood, tq, (4.2, 0.76, 1.2), 8.0, 0.0)
    d.box("mesa", cloth, tq, (3.2, 0.05, 1.3), 8.0, 0.76)
    for k in range(4):
        for sgn in (-1, 1):
            q = loc(tq, 8.0, -1.5 + k * 1.0, sgn * 1.05)
            d.cyl("mesa", wood, q, 0.2, 0.18, 0.42, 0.0, 6)
        q = loc(tq, 8.0, -1.4 + k * 0.95, 0.1 * (k % 2))
        d.cyl("mesa", d.m("lucido_tigela", (0.72, 0.7, 0.68)), q, 0.1, 0.17, 0.12, 0.81, 6)
    z.ob("crate", tq[0], tq[1], (4.2, 0.9, 1.3), 8.0, visible=False)
    for r, a in ((17.0, 152.0), (17.2, 207.0), (17.4, -150.0)):      # tendas de abrigo dos que chegaram
        q = H(r, a, BC)
        d.tent_aurora(q, facing(-math.cos(math.radians(a)), -math.sin(math.radians(a))), 0.95, color=(0.88, 0.9, 0.93), trim=(0.42, 0.52, 0.72), gold=(0.8, 0.82, 0.88))
        z.ob("pillar", q[0], q[1], (2.9, 2.6, 2.9), visible=False)
    sober = ((0.9, 0.9, 0.92), (0.56, 0.66, 0.82), (0.74, 0.78, 0.84), (0.62, 0.64, 0.72))
    for a0, a1 in ((64.0, 78.0), (-78.0, -64.0), (116.0, 128.0)):
        d.laundry(H(18.6, a0, BC), H(18.6, a1, BC), 2.3, "varal", cols=sober)
    d.cargo(H(14.0, 222.0, BC), 6, 1.2, g="mantimento")
    d.cargo(H(18.8, 30.0, BC), 4, 1.0, g="mantimento")
    for q in (H(14.0, 222.0, BC), H(18.8, 30.0, BC)):
        z.ob("crate", q[0], q[1], (2.4, 1.3, 2.0), 0.0, visible=False)
    soil = d.m("patch_canteiro", (0.46, 0.4, 0.38))
    veg = [d.m("horta_a", (0.4, 0.6, 0.42)), d.m("horta_b", (0.54, 0.7, 0.46))]
    for a in (-18.0, 18.0, 78.0, -78.0, 122.0, -122.0, 162.0, -162.0):      # canteiros entre o anel de serviços e as casas
        q = H(18.9, a + 9.0, BC)
        rot = -(a + 9.0) + 90.0
        d.box("horta", soil, q, (2.4, 0.02, 1.2), rot, 0.02)
        for i in range(4):
            for j in range(2):
                d.tuft("mini", veg[(i + j) % 2], loc(q, rot, -0.9 + 0.6 * i, -0.3 + 0.6 * j), 0.16, 0.4, 4)
    d.barrel(H(16.0, 92.0, BC), 1.0, g="mantimento", color=(0.46, 0.44, 0.46))


def maypole(z, dn, dA, dB, c, y_top, r, n=8, r0=2.6, sag=1.6):
    """Cordões de lanternas e bandeirolas do alto do Campanário até postes na borda da praça (de cima: uma estrela pontilhada)."""
    pole = dn.m("festa_poste", (0.86, 0.8, 0.74))
    cord = dn.m("festa_cordao", (0.5, 0.42, 0.4))
    dim = dn.m("lanterna_apagada", (0.84, 0.78, 0.72))
    gA, gB = dA.m("glow_lanterna_ambar", (1.0, 0.84, 0.55)), dB.m("glow_lanterna_rosa", (1.0, 0.68, 0.78))
    pens = [dn.m("bandeirola_%d" % i, col) for i, col in enumerate(BUNTING)]
    k = 0
    for i in range(n):
        a = 360.0 * (i + 0.5) / n
        p1 = Vector(H(r, a))
        v = (p1 - Vector(c))
        p0 = Vector(c) + v.normalized() * r0
        dn.cyl("lanterna", pole, (p1.x, p1.y), 0.11, 0.07, 4.4, 0.0, 5)
        pts = []
        for j in range(9):
            t = j / 8.0
            q = p0.lerp(p1, t)
            y = y_top + (4.4 - y_top) * t - sag * math.sin(math.pi * t)
            pts.append((q.x, y, q.y))
        dn.tube("lanterna", cord, pts, 0.03, 0.03, 3)
        tv = v.normalized()
        fold = Vector((-tv.y, tv.x)) * 0.07
        for j in range(1, 8):
            x, y, zz = pts[j]
            if j % 2:
                dn.box("lanterna", dim, (x, zz), (0.3, 0.38, 0.3), 45.0, y - 0.42)
                (dA if k % 2 == 0 else dB).box("lanterna", gA if k % 2 == 0 else gB, (x, zz), (0.42, 0.46, 0.42), 45.0, y - 0.46)
                k += 1
            else:
                for u in (-0.5, 0.0, 0.5):
                    town_dress._tri(dn, "lanterna", pens[(i + j + int(u * 2)) % len(pens)], (x, zz),
                                    [B(x + tv.x * (u - 0.2), zz + tv.y * (u - 0.2), y), B(x + tv.x * (u + 0.2), zz + tv.y * (u + 0.2), y),
                                     B(x + tv.x * u + fold.x * 2.0, zz + tv.y * u + fold.y * 2.0, y - 0.48)], n=B(fold.x, fold.y, 0.0) * 0.5)


# ---------------------------------------------------------------------------------------------------------------
# festa: lanternas, bandeirolas, confete
# ---------------------------------------------------------------------------------------------------------------
def festoon(z, dn, dA, dB, widths, lots, rnd):
    """Fileiras de lanternas dos dois lados de cada rua (poste a cada 8 m, cordão em catenária, 3 lanternas por vão) e, a
    cada 3 postes, um varal de bandeirolas dobradas atravessando a rua. Dentro do Bairro dos Lúcidos não há nada.
    A lanterna apagada mora no lote neutro; a acesa (um pouco maior, `glow_*`) em dois lotes de estágio alternados."""
    pole = dn.m("festa_poste", (0.86, 0.8, 0.74))
    cord = dn.m("festa_cordao", (0.5, 0.42, 0.4))
    dim = dn.m("lanterna_apagada", (0.84, 0.78, 0.72))
    cap = dn.m("lanterna_tampa", OLD_GOLD)
    gA = dA.m("glow_lanterna_ambar", (1.0, 0.84, 0.55))
    gB = dB.m("glow_lanterna_rosa", (1.0, 0.68, 0.78))
    pens = [dn.m("bandeirola_%d" % i, c) for i, c in enumerate(BUNTING)]
    bc = Vector(BC)
    count = [0, 0]

    def ok(p):
        if p.length > WALL_R - 3.0 or (p - bc).length < BR + 2.5:
            return False
        for name, poly in z.road_polys.items():
            if poly_dist(p, poly) < widths[name] * 0.5 + 0.35:
                return False
        return all((p - c).length > r for c, r in lots)

    def lantern(p, y, k):
        dn.box("lanterna", dim, (p.x, p.y), (0.26, 0.34, 0.26), 45.0, y - 0.4)
        dn.cyl("lanterna", cap, (p.x, p.y), 0.18, 0.05, 0.1, y - 0.06, 4)
        (dA if k % 2 == 0 else dB).box("lanterna", gA if k % 2 == 0 else gB, (p.x, p.y), (0.36, 0.4, 0.36), 45.0, y - 0.43)
        count[k % 2] += 1

    k = 0
    for name, poly in z.road_polys.items():
        w = widths[name]
        tops = {-1: [], 1: []}
        for i in range(2, len(poly) - 2, 5):
            a, b = poly[i - 1], poly[i + 1]
            t = (b - a).normalized()
            n = Vector((-t.y, t.x))
            for s in (-1, 1):
                p = poly[i] + n * s * (w * 0.5 + 0.75)
                if not ok(p):
                    tops[s].append(None)
                    continue
                dn.cyl("lanterna", pole, (p.x, p.y), 0.09, 0.06, 3.5, 0.0, 5)
                dn.cyl("lanterna", cap, (p.x, p.y), 0.12, 0.0, 0.25, 3.5, 5)
                tops[s].append(p)
        for s in (-1, 1):                                    # cordões ao longo da rua
            row = tops[s]
            for j in range(len(row) - 1):
                p0, p1 = row[j], row[j + 1]
                if p0 is None or p1 is None or (p1 - p0).length > 11.0:
                    continue
                mid = (p0 + p1) * 0.5
                dn.tube("lanterna", cord, [(p0.x, 3.45, p0.y), (mid.x, 3.0, mid.y), (p1.x, 3.45, p1.y)], 0.025, 0.025, 3)
                for tt in (0.2, 0.4, 0.6, 0.8):
                    q = p0.lerp(p1, tt)
                    lantern(q, 3.45 - 0.45 * (1.0 - (2.0 * tt - 1.0) ** 2), k)
                    k += 1
        for j in range(1, len(tops[1]), 3):                  # bandeirolas atravessando a rua
            p0, p1 = tops[-1][j], tops[1][j]
            if p0 is None or p1 is None:
                continue
            mid = (p0 + p1) * 0.5
            dn.tube("lanterna", cord, [(p0.x, 3.5, p0.y), (mid.x, 3.15, mid.y), (p1.x, 3.5, p1.y)], 0.02, 0.02, 3)
            t = (p1 - p0).normalized()
            fold = Vector((-t.y, t.x)) * 0.07
            np_ = max(3, int((p1 - p0).length / 0.75))
            for i in range(1, np_):
                tt = i / np_
                q = p0.lerp(p1, tt)
                y = 3.5 - 0.35 * (1.0 - (2.0 * tt - 1.0) ** 2)
                m = pens[(i + j) % len(pens)]
                sg = 1.0 if i % 2 else -1.0
                town_dress._tri(dn, "lanterna", m, (q.x, q.y),
                                [B(q.x - t.x * 0.24, q.y - t.y * 0.24, y), B(q.x + t.x * 0.24, q.y + t.y * 0.24, y),
                                 B(q.x + fold.x * sg * 2.0, q.y + fold.y * sg * 2.0, y - 0.5)], n=B(fold.x, fold.y, 0.0) * 0.5)
    print("lanternas: %d ambar (lum_acesa_a) + %d rosa (lum_acesa_b)" % (count[0], count[1]))


def confetti(z, d, d_morning, widths, plazas, rnd):
    """Confete no chão das ruas e praças de festa, em TRÊS TONS DO PRÓPRIO CHÃO (nunca cor viva: mancha saturada no chão é
    aviso de golpe). Quadradinhos de 4 vértices, sem sombra. Em L4 somem e ficam os montes varridos (lote da manhã)."""
    light, dark = act2_dress.floor_tone_colors(PAVING, 0.14)
    mid = tuple((a + b) * 0.5 + 0.02 for a, b in zip(light, PAVING))
    tones = [d.m("patch_confete_claro", light), d.m("patch_confete_esc", dark), d.m("patch_confete_meio", mid)]
    bc = Vector(BC)

    def quad(p, k):
        if (p - bc).length < BR + 1.5 or p.length > WALL_R - 2.0:
            return
        bm = d._bm("confete", tones[k % 3], p.x, p.y)
        s = rnd.uniform(0.07, 0.15)
        a = rnd.uniform(0, math.tau)
        vs = [bm.verts.new(B(p.x + math.cos(a + math.pi * 0.5 * i) * s, p.y + math.sin(a + math.pi * 0.5 * i) * s, 0.0152)) for i in range(4)]
        bm.faces.new(vs)

    k = 0
    for name, poly in z.road_polys.items():
        w = widths[name]
        for i in range(len(poly) - 1):
            t = (poly[i + 1] - poly[i])
            n = Vector((-t.y, t.x)).normalized()
            for _ in range(4):
                quad(poly[i] + t * rnd.random() + n * rnd.uniform(-w * 0.55, w * 0.55), k)
                k += 1
    for c, r in plazas:
        for _ in range(int(r * r * 0.5)):
            a, rr = rnd.uniform(0, math.tau), r * math.sqrt(rnd.random())
            quad(Vector((c[0] + math.cos(a) * rr, c[1] + math.sin(a) * rr)), k)
            k += 1
    print("confete: %d" % k)
    # L4, Manhã em Lumeria: montes varridos nos mesmos tons, vassouras encostadas e carrinhos de mão
    pile = [d_morning.m("monte_confete_a", dark), d_morning.m("monte_confete_b", mid)]
    wood = d_morning.m("vassoura_cabo", (0.6, 0.48, 0.34))
    straw = d_morning.m("vassoura_palha", (0.86, 0.76, 0.5))
    j = 0
    for name, poly in z.road_polys.items():
        w = widths[name]
        for i in range(6, len(poly) - 4, 14):
            t = (poly[i + 1] - poly[i]).normalized()
            n = Vector((-t.y, t.x))
            p = poly[i] + n * (w * 0.5 - 0.5) * (1 if j % 2 else -1)
            if (p - bc).length < BR + 2.0 or p.length > WALL_R - 3.0:
                continue
            d_morning.cyl("manha", pile[j % 2], (p.x, p.y), 0.55, 0.0, 0.34, 0.0, 7)
            d_morning.cyl("manha", pile[(j + 1) % 2], (p.x + 0.5, p.y + 0.3), 0.36, 0.0, 0.22, 0.0, 6)
            d_morning.tube("manha", wood, [(p.x - 0.5, 0.05, p.y - 0.2), (p.x - 0.75, 1.5, p.y - 0.35)], 0.03, 0.03, 4)
            d_morning.cyl("manha", straw, (p.x - 0.48, p.y - 0.19), 0.16, 0.05, 0.3, 0.0, 5)
            if j % 3 == 0:
                q = poly[i] - n * (w * 0.5 - 1.2) * (1 if j % 2 else -1)
                d_morning.cart((q.x, q.y), math.degrees(math.atan2(-t.y, t.x)), g="manha", load=dark)
            j += 1


# ---------------------------------------------------------------------------------------------------------------
# casas
# ---------------------------------------------------------------------------------------------------------------
class City:
    """Loteamento: casas de frente para a rua, encostadas na muralha e miolo de quadra. Guarda o que já está ocupado."""

    def __init__(self, z, d, widths, keep):
        self.z, self.d, self.widths = z, d, widths
        self.keep = [(Vector(c), r) for c, r in keep]       # (centro, raio) onde não nasce casa
        self.lots = []                                      # (centro, raio) de cada casa
        self.n = 0

    def free(self, c, rad, own=None):
        v = Vector(c)
        if v.length > WALL_R - 2.4 - rad * 0.8 or (v - Vector(BC)).length < BR + 2.4 + rad * 0.8:
            return False
        for q, r in self.keep:
            if (v - q).length < r + rad * 0.8:
                return False
        for name, poly in self.z.road_polys.items():
            if name != own and poly_dist(v, poly) < self.widths[name] * 0.5 + rad * 0.86 + 0.6:
                return False
        return all((v - q).length > (r + rad) * 0.9 for q, r in self.lots)

    def add(self, c, rot, L, W, h):
        roofs = ROOFS[district(c)]
        k = self.n
        house(self.z, self.d, c, rot, L, W, h, WALLS[k % 3], roofs[(k * 7 + k // 3) % 3])
        self.lots.append((Vector(c), math.hypot(L, W) * 0.5))
        self.n += 1

    def along_roads(self, rnd):
        for name, poly in self.z.road_polys.items():
            w = self.widths[name]
            for s in (-1, 1):
                acc = 3.0
                L = rnd.choice((6.2, 7.0, 7.8))
                for i in range(1, len(poly) - 1):
                    acc += (poly[i] - poly[i - 1]).length
                    if acc < L + 1.3:
                        continue
                    t = (poly[i + 1] - poly[i - 1]).normalized()
                    n = Vector((-t.y, t.x)) * s
                    W = rnd.choice((5.0, 5.6))
                    # casa do lado SUL da rua fica entre a câmera (52 graus, olhando do sul) e quem anda: recua até 3,6 m
                    # (telhado de 4 m tapa ~3,1 m de chão atrás dele); do lado norte basta a calçada
                    gap = 1.5 + 2.1 * max(0.0, n.y)
                    c = poly[i] + n * (w * 0.5 + gap + W * 0.5)
                    rad = math.hypot(L, W) * 0.5
                    if self.free((c.x, c.y), rad, own=name) and poly_dist(c, poly) > w * 0.5 + gap - 0.2 + W * 0.5:
                        self.add((c.x, c.y), facing(-n.x, -n.y), L, W, rnd.choice((2.5, 2.7, 2.9)))
                        acc = 0.0
                        L = rnd.choice((6.2, 7.0, 7.8))

    def wall_ring(self, rnd):
        r = WALL_R - 5.6
        n = int(math.tau * r / 9.0)
        for i in range(n):
            a = math.tau * (i + 0.5) / n
            c = (math.cos(a) * r, math.sin(a) * r)
            L, W = 6.8, 5.0
            if self.free(c, math.hypot(L, W) * 0.5 - 0.9):
                self.add(c, facing(-math.cos(a), -math.sin(a)), L, W, rnd.choice((2.7, 3.0)))

    def infill(self, rnd, tries=900):
        polys = list(self.z.road_polys.items())
        for _ in range(tries):
            a, rr = rnd.uniform(0, math.tau), (WALL_R - 8.0) * math.sqrt(rnd.random())
            c = Vector((math.cos(a) * rr, math.sin(a) * rr))
            L, W = rnd.choice((5.8, 6.6)), 5.0
            rad = math.hypot(L, W) * 0.5
            if not self.free((c.x, c.y), rad + 0.5):
                continue
            best, bd = None, 1e9                             # a porta olha para a rua mais perto
            for name, poly in polys:
                for q in poly[::2]:
                    dd = (q - c).length
                    if dd < bd:
                        bd, best = dd, q
            v = (best - c).normalized()
            self.add((c.x, c.y), facing(v.x, v.y), L, W, rnd.choice((2.5, 2.8)))


# ---------------------------------------------------------------------------------------------------------------
def build(export=False):
    z = Zone(ZONE, size=260.0, rim=(116.0, 3.0, 2.0, 1.5), seed=47, palette={
        "road": (0.95, 0.9, 0.8), "street": (0.92, 0.86, 0.8), "cliff_rock": (0.6, 0.66, 0.46), "cliff_rock_d": (0.5, 0.57, 0.42),
        "cliff_grass": (0.56, 0.7, 0.44), "hill_grass": (0.56, 0.7, 0.46), "leaf": (0.4, 0.6, 0.4),
    })
    rnd = random.Random(4711)
    dn = Dress(z, seed=101)
    dA = Dress(z, seed=102, tag="lum_acesa_a")
    dB = Dress(z, seed=103, tag="lum_acesa_b")
    d_bar = Dress(z, seed=104, tag="l0_barricada")
    d_open = Dress(z, seed=105, tag="l1_portao_aberto")
    d_pal = Dress(z, seed=106, tag="l0_palacio_fechado")
    d_dwarf = Dress(z, seed=107, tag="l1_forja_ana")
    d_conf = Dress(z, seed=108, tag="l0_confete")
    d_morn = Dress(z, seed=109, tag="l4_manha")
    d_duke = Dress(z, seed=110, tag="l3_duque")
    widths = {}

    def road(name, pts, w=4.2):
        widths[name] = w
        return z.road(name, pts, w=w, end_clearing=False)

    # ---------- portões e passagens ----------
    w_out, w_in = polar(z, GATE_W, 6), (BC[0] - BR + 7.0, 0.0)          # garganta de Kharzun; chegada dentro do Bairro
    n_out, n_in = polar(z, GATE_N, 6), H(WALL_R - 8.0, GATE_N)
    se_out, se_in = polar(z, GATE_SE, 6), H(WALL_R - 8.0, GATE_SE)
    z.portal("to_field_kharzun", w_out, "field_kharzun", KHARZUN_ARRIVE, "Monte Kharzun (Lv 40-45)")
    print("BACK kharzun (target_pos do portal de Kharzun para Lumeria)", w_in)
    # WP5: field_perfume e field_parade existem; portal de verdade (chegada = spawn do campo). O do Cortejo ganha o portão
    # do catálogo (nível 47 + hx3_bells, MapsCatalog.PORTAL_GATES)
    z.portal("to_field_perfume", n_out, "field_perfume", PERFUME_ARRIVE, "Vinhas do Perfume (Lv 45-47)")
    z.portal("to_field_parade", se_out, "field_parade", PARADE_ARRIVE, "Avenida do Cortejo (Lv 47-49)")
    z.data["spawn"] = list(w_in)
    z.cam_game = {"praca": (0.0, 4.0), "mercado": MARKET, "opera": FORECOURT, "jardim": GARDEN}.get(os.environ.get("LUMERIA_CAM", ""), BC)

    # ---------- chão ----------
    z.data["roads"].append({"kind": "street", "w": 0, "pts": [[0.0, 0.0]], "r": WALL_R + 1.0})      # cidade calçada: sem capim dentro da muralha
    ring = [Vector((math.cos(math.tau * i / 96) * 113.0, math.sin(math.tau * i / 96) * 113.0)) for i in range(97)]
    dn.strip("fora", dn.m("patch_relva_fora", OUTSIDE), ring, 24.0, 0.0046)
    tones = act2_dress.floor_tone_colors(PAVING, 0.035)
    dn.mottle([("calcada_clara", tones[0]), ("calcada_esc", tones[1]), ("calcada_rosada", (0.79, 0.7, 0.67))], [((0, 0), 98, 120)], y=0.0008, rmin=2.5, rmax=5.0)
    z.patch("lucidos", BC, BR + 1.2, LUCID)
    z.patch("mercado", MARKET, 27.0, (0.92, 0.82, 0.7))
    z.patch("opera", (60.0, -4.0), 27.0, (0.82, 0.76, 0.86))
    z.patch("jardim", GARDEN, 25.0, (0.56, 0.72, 0.5), grass=True, y=0.0072)
    for name, c, r, col in (("pave_praca_sinos", (0.0, 0.0), PLAZA_R, (0.93, 0.84, 0.82)), ("pave_praca_lucidos", BC, B_PLAZA_R, (0.7, 0.75, 0.82)),
                            ("pave_mercado", MARKET, MARKET_R, (0.95, 0.88, 0.76)), ("pave_largo_opera", FORECOURT, FORECOURT_R, (0.88, 0.83, 0.92)),
                            ("pave_jardim", GARDEN, GARDEN_R, (0.9, 0.86, 0.74))):
        z.M[name] = mat(name, col)
        z.plaza(name[5:], c, r, name)

    # ---------- ruas (todas curvas; os anéis fecham a volta: Bairro -> Mercado -> Ópera -> Cortejo -> Jardim -> Bairro) ----------
    g_ne, g_se = H(BR, -52.0, BC), H(BR, 52.0, BC)
    road("chegada", [w_out, (BC[0] - BR - 0.5, 0.4), (BC[0] - BR + 7.0, -0.4), (BC[0] - B_PLAZA_R + 0.5, 0.0)])
    road("lucidos_l", [(BC[0] + B_PLAZA_R - 0.5, 0.0), (BC[0] + 20.0, 1.0), (BC[0] + BR, 0.0), (-40.0, -1.8), (-31.0, 1.6), (-PLAZA_R + 0.5, 0.0)], w=5.0)
    road("anel_no", [H(B_PLAZA_R - 0.5, -52.0, BC), g_ne, (-50.0, -33.0), (-38.0, -45.0), (-25.0, -55.0), (-MARKET_R + 0.5, -62.0)])
    road("anel_so", [H(B_PLAZA_R - 0.5, 52.0, BC), g_se, (-50.0, 33.0), (-37.0, 44.0), (-24.0, 53.0), (GARDEN[0] - GARDEN_R + 0.5, 61.0)])
    road("norte", [(3.0, -PLAZA_R + 0.4), (5.5, -31.0), (0.5, -40.0), (0.0, MARKET[1] + MARKET_R - 0.5)], w=5.0)
    road("portao_n", [(0.0, MARKET[1] - MARKET_R + 0.5), (-3.0, -85.0), (0.0, -93.0), H(WALL_R, GATE_N), n_out], w=5.0)
    road("leste", [(PLAZA_R - 0.5, 0.0), (28.5, -2.6), (34.5, 0.6), (FORECOURT[0] - FORECOURT_R + 0.5, -3.4)], w=5.0)
    road("sul", [(-2.0, PLAZA_R - 0.4), (-4.5, 31.0), (1.5, 40.0), (4.0, GARDEN[1] - GARDEN_R + 0.5)], w=5.0)
    road("anel_ne", [(MARKET_R - 0.5, -62.0), (27.0, -56.0), (38.0, -43.0), (46.0, -29.0), (50.0, -20.0), (FORECOURT[0], FORECOURT[1] - FORECOURT_R + 0.5)])
    road("anel_se", [(FORECOURT[0], FORECOURT[1] + FORECOURT_R - 0.5), (55.0, 17.0), (54.0, 29.0), SE_JUNCTION, (40.0, 51.0), (29.0, 59.0),
                     (GARDEN[0] + GARDEN_R - 0.5, 62.5)])
    road("portao_se", [SE_JUNCTION, (59.0, 48.5), (68.0, 57.0), H(WALL_R, GATE_SE), se_out], w=5.0)
    road("relojoeiro", [(38.0, -43.0), (44.0, -47.0), (48.5, -48.5)], w=3.0)
    road("capela", [(-33.4, 46.6), (-32.4, 44.6), (-31.6, 43.0)], w=3.0)

    dn.road_edges((0.66, 0.59, 0.56), extra=2.0, wvar=0.12, skip=("chegada",))      # meio-fio: a rua clara destaca do calçamento das quadras

    # ---------- muralhas ----------
    in_bairro = lambda deg: (Vector(H(WALL_R, deg)) - Vector(BC)).length < BR + 0.6
    ring_wall(z, dn, "cidade", (0.0, 0.0), WALL_R, [(GATE_N, 3.6), (GATE_SE, 3.6)], 4.4, 1.6, STONE, STONE_D, seg_len=4.0, skip=in_bairro)
    ring_wall(z, dn, "lucidos", BC, BR, B_GATES, 3.4, 1.2, LUCID_STONE, LUCID_STONE_D, seg_len=2.6, roof=ROOFS["lucidos"][0])
    gate_spur(z, dn, GATE_N, 3.6, STONE, STONE_D)
    gate_spur(z, dn, GATE_SE, 3.6, STONE, STONE_D)
    gate_spur(z, dn, GATE_W, 2.6, STONE, STONE_D)
    z.block((0.0, 0.0), WALL_R + 1.5)                         # nada da dispersão nasce dentro da cidade

    # ---------- Bairro dos Lúcidos (hub): sem enfeite, ardósia, o Sino Abafado, serviços em roda ----------
    muffled_bell(z, dn, BC)
    k = 0
    for i in range(14):
        a = 360.0 * (i + 0.5) / 14
        if any(abs((a - g + 180.0) % 360.0 - 180.0) < (17.0 if hw > 3.0 else 14.0) for g, hw in B_GATES):
            continue
        c = H(BR - 5.4, a, BC)
        house(z, dn, c, facing(-math.cos(math.radians(a)), -math.sin(math.radians(a))), 6.2, 4.6, 2.7, (0.84, 0.86, 0.9), ROOFS["lucidos"][k % 3])
        k += 1
    for a in (40.0, 140.0, 220.0, 320.0):
        z.ob("lamp", *H(B_PLAZA_R + 0.8, a, BC), (0.4, 3.0, 0.4))
    for a in (100.0, 260.0):
        z.ob("bench", *H(B_PLAZA_R + 1.6, a, BC), (1.8, 0.8, 0.6), -a, solid=False)
    z.ob("well", *H(15.5, 98.0, BC), (1.6, 1.4, 1.6))
    lucid_life(z, dn)
    # barricadas: o portão leste fica aberto em chicana (duas pilhas por fora); as portas laterais têm pilhas dos dois lados
    # (sempre) e, até os sinos calarem, uma carroça tombada e mais móveis ao lado do vão (só visual: a passagem é a mesma)
    for g, hw in B_GATES:
        if g == 180.0:
            continue
        for s in (-1, 1):
            q = H(BR + 2.2, g + s * math.degrees((hw + 2.4) / BR), BC)
            barricade(z, dn, q, -g + 90.0 + s * 14.0, 3.4)
        if g != 0.0:
            q = H(BR + 5.2, g + math.degrees((hw + 3.6) / BR), BC)
            d_bar.cart(q, -g + 30.0, g="barricada", broken=True, color=(0.46, 0.38, 0.34))
            barricade(z, d_bar, H(BR + 4.8, g - math.degrees((hw + 3.4) / BR), BC), -g + 70.0, 3.0, collide=False)
            for s in (-1, 1):                                # L1: flâmulas azuis dos Lúcidos nas portas abertas
                d_open.flag(H(BR + 1.2, g + s * math.degrees((hw + 0.9) / BR), BC), (0.46, 0.58, 0.82), h=4.6, rot=-g + 90.0, tatter=False, w=1.0, drop=1.7,
                            pole=(0.7, 0.72, 0.78))
    # serviços (ids do GDD §2.2; o catálogo é do WP5). Anel de dentro r = 8-9, de frente para o Sino.
    fc = lambda a: facing(-math.cos(math.radians(a)), -math.sin(math.radians(a)))
    for nid, r, a in (("sister_celeste", 5.2, 70.0), ("lumeria_smith", 9.2, -28.0), ("lumeria_alchemist", 9.2, 28.0), ("lumeria_merchant", 9.2, 152.0),
                      ("lumeria_storage", 9.2, 208.0), ("lumeria_board", 10.4, -92.0), ("lumeria_relic", 9.8, -122.0), ("lumeria_masters_herald", 10.4, 104.0),
                      ("lumeria_dwarf_smith", 16.4, -100.0)):
        x, zz = H(r, a, BC)
        z.npc(nid, x, zz, fc(a))
    crystal = H(7.6, -62.0, BC)
    trainer = H(15.2, 128.0, BC)
    # adereços sóbrios dos postos (lote neutro) e a forja do anão (L1)
    q = H(11.6, -28.0, BC)
    z.ob("anvil", q[0], q[1], (1.0, 0.9, 0.6), 30.0)
    q = H(11.8, 28.0, BC)
    z.ob("cauldron", q[0], q[1], (1.1, 1.0, 1.1))
    q = H(11.8, 152.0, BC)
    z.ob("stall", q[0], q[1], (2.8, 2.2, 1.8), fc(152.0), color=(0.56, 0.64, 0.78))
    for i, a in enumerate((200.0, 208.0, 216.0)):
        q = H(12.0, a, BC)
        z.ob("crate", q[0], q[1], (1.0, 1.0, 1.0), i * 25.0)
    fq = H(19.0, -100.0, BC)
    stone = d_dwarf.m("forja_ana_pedra", (0.5, 0.5, 0.56))
    d_dwarf.box("forja_ana", stone, fq, (2.4, 1.6, 1.8), 10.0, 0.0)
    d_dwarf.cyl("forja_ana", stone, (fq[0] - 0.5, fq[1] - 0.3), 0.5, 0.4, 1.6, 1.6, 6)
    d_dwarf.box("forja_ana", d_dwarf.m("glow_brasa", (1.0, 0.56, 0.2)), (fq[0] + 0.1, fq[1] + 0.93), (1.0, 0.5, 0.1), 10.0, 0.4)
    aq = H(16.6, -108.0, BC)
    d_dwarf.cyl("forja_ana", d_dwarf.m("forja_ana_toco", (0.44, 0.34, 0.26)), aq, 0.34, 0.32, 0.5, 0.0, 8)
    d_dwarf.box("forja_ana", d_dwarf.m("forja_ana_ferro", (0.28, 0.28, 0.32)), aq, (0.78, 0.22, 0.3), 30.0, 0.5)
    z.ob("pillar", fq[0], fq[1], (2.6, 2.0, 2.0), visible=False)       # reservado desde L0 (um colisor só, vale para os dois estágios)
    # sentinelas dos Lúcidos nos portões (fighter no catálogo)
    gi = 0
    for g, hw in B_GATES:
        for s in ((-1, 1) if g in (0.0, 180.0) else (1,)):
            x, zz = H(BR - 2.6, g + s * math.degrees((hw + 1.4) / BR), BC) if g in (0.0, 180.0) else H(BR - 5.0, g + math.degrees(1.3 / BR), BC)
            z.npc("lumeria_g_%s_%d" % ("spearman" if gi % 2 == 0 else "crossbow", gi), x, zz, fc(g) + 180.0)
            gi += 1
    z.data["town"] = {"center": list(BC), "radius": BR, "gates": [list(H(BR, g, BC)) for g, _hw in B_GATES]}
    z.data["hangouts"] = [list(H(r, a, BC)) for r, a in ((6.6, 0.0), (6.8, 125.0), (6.6, 180.0), (7.0, 250.0), (7.2, 310.0), (13.6, 60.0), (13.6, 180.0),
                                                           (13.8, -60.0), (14.2, 120.0), (14.0, 240.0), (14.4, 0.0), (17.5, 75.0), (17.5, -75.0), (18.5, 170.0))]

    # ---------- Praça dos Sinos e o Campanário ----------
    campanario(z, dn, TOWER)
    maypole(z, dn, dA, dB, TOWER, 12.2, PLAZA_R - 1.2)
    for a in STAGE_DEG:                                       # palcos no arco norte da praça: a frente olha para o sul (para a câmera)
        stage(z, dn, H(PLAZA_R + 5.2, a), facing(-math.cos(math.radians(a)), -math.sin(math.radians(a))))
    for a in (118.0, 62.0):
        q = H(PLAZA_R - 2.6, a)
        banquet(z, dn, q, -a, 6.0)
    for a in (60.0, 120.0, 200.0, 340.0):
        z.ob("bench", *H(PLAZA_R - 1.0, a), (1.8, 0.8, 0.6), -a, solid=False)
    for a, off in ((180.0, 13.0), (-82.0, 14.0), (0.0, -13.0), (95.0, 14.0), (180.0, -13.0), (0.0, 13.0)):      # máscaras em mastro nas bocas das avenidas
        q = H(PLAZA_R + 0.8, a + off)
        dn.cyl("mascara", dn.m("festa_poste", (0.86, 0.8, 0.74)), q, 0.1, 0.07, 3.6, 0.0, 5)
        mask(dn, "mascara", q, 4.3, facing(math.cos(math.radians(a + off)), math.sin(math.radians(a + off)) + 0.6), 1.15)

    # ---------- Mercado das Taças (norte) ----------
    goblet_fountain(z, dn, MARKET)
    maypole(z, dn, dA, dB, MARKET, 5.4, MARKET_R - 1.0, n=6, r0=0.3, sag=0.5)
    for i in range(8):
        a = 22.5 + 45.0 * i
        if abs((a + 90.0 + 180.0) % 360.0 - 180.0) < 30.0 or abs((a - 90.0 + 180.0) % 360.0 - 180.0) < 30.0:
            continue
        q = H(MARKET_R - 3.6, a, MARKET)
        rot = facing(math.cos(math.radians(a)), math.sin(math.radians(a)))       # o feirante fica por fora, o freguês na praça
        town_dress.stall(dn, q, rot, (BUNTING[i % 5]), town_dress.GOODS[i % len(town_dress.GOODS)])
        z.ob("stall", q[0], q[1], (2.7, 1.6, 0.95), rot, visible=False)
    banquet(z, dn, H(8.5, 200.0, MARKET), 20.0, 5.0)
    banquet(z, dn, H(8.5, 20.0, MARKET), 20.0, 5.0)
    stage(z, dn, (-21.0, -74.0), facing(0.8, 0.6))

    # ---------- Ópera / Palácio do Duque (leste) ----------
    orot, odoor, ofront = opera(z, dn, d_pal, d_duke, OPERA)
    for s in (-1, 1):
        q = (FORECOURT[0] + 5.0, FORECOURT[1] + s * 8.2)
        dn.flag(q, BUNTING[4], h=5.6, rot=90.0, tatter=False, w=1.2, drop=2.2, pole=OLD_GOLD)
    stage(z, dn, OPERA_STAGE, facing(0.5, 0.86))
    banquet(z, dn, (FORECOURT[0] - 3.0, FORECOURT[1] + 6.8), -8.0, 5.0)
    lt, dk = act2_dress.floor_tone_colors((0.88, 0.83, 0.92), 0.1)      # passadeira até a escadaria, em tons do próprio largo
    dn.rug((FORECOURT[0] + 6.5, FORECOURT[1]), 13.0, 3.0, 0.0, dk, lt, g="opera")
    for sgn in (-1, 1):                                       # urnas de porcelana ladeando a passadeira
        for x in (1.5, 7.5):
            q = (FORECOURT[0] + x, FORECOURT[1] + sgn * 2.6)
            dn.cyl("opera", dn.m("fonte_pedra", STONE), q, 0.36, 0.3, 0.7, 0.0, 6)
            dn.cyl("opera", dn.m("mascara_marfim", IVORY), q, 0.2, 0.42, 0.6, 0.7, 8)
            dn.tuft("mini", dn.m("urna_flor", (0.9, 0.66, 0.78)), q, 0.3, 0.6, 5)

    # ---------- Jardim das Fontes de Vinho (sul) ----------
    wine_fountain(z, dn, GARDEN, 1.25, top="jar")
    for k, a in enumerate((35.0, 155.0, 270.0)):
        wine_fountain(z, dn, H(GARDEN_R + 4.6, a + 8.0, GARDEN), 0.9)
    hedge, hedge_d = dn.m("sebe", (0.36, 0.56, 0.4)), dn.m("sebe_esc", (0.3, 0.48, 0.36))
    for k in range(12):                                       # sebes baixas em arco, com vãos largos (não é labirinto)
        a = 30.0 * k + 15.0
        if k % 3 == 0 or abs((a - 185.0 + 180.0) % 360.0 - 180.0) < 22.0 or abs((a + 90.0 + 180.0) % 360.0 - 180.0) < 22.0 or abs((a - 0.0 + 180.0) % 360.0 - 180.0) < 20.0:
            continue
        q = H(GARDEN_R + 1.4, a, GARDEN)
        rot = along(-math.sin(math.radians(a)), math.cos(math.radians(a)))
        dn.box("sebe", hedge, q, (5.6, 1.2, 1.0), rot, 0.0)
        dn.box("sebe", hedge_d, q, (5.2, 0.16, 0.8), rot, 1.2)
        z.ob("fence", q[0], q[1], (5.6, 1.2, 1.1), rot, visible=False)
    bloom = [(0.94, 0.66, 0.78), (0.98, 0.92, 0.6), (0.8, 0.7, 0.94), (0.96, 0.96, 0.98)]
    for k in range(10):
        q = H(GARDEN_R + 6.5 + (k % 2) * 2.0, 36.0 * k + 12.0, GARDEN)
        z.ob("flowers", q[0], q[1], (1.8, 0.5, 1.8), solid=False, color=bloom[k % 4])
    for k, a in enumerate((70.0, 110.0, 215.0, 325.0)):
        q = H(GARDEN_R + 7.5, a, GARDEN)
        z.ob("tree", q[0], q[1], (1.7, 4.0, 1.7), color=(0.4, 0.64, 0.42) if k % 2 else (0.34, 0.56, 0.4))
    stage(z, dn, H(GARDEN_R + 9.5, 300.0, GARDEN), facing(-0.5, 0.86))

    # ---------- lugares: Casa do Relojoeiro (cabana), Capela Selada (santuário) ----------
    crot = facing(-0.9, 0.44)
    clock_npc, clock_front = clock_house(z, dn, CLOCK, crot)
    z.npc("clockmaker", round(clock_npc[0], 2), round(clock_npc[1], 2), crot)
    hrot = facing(-0.57, 0.82)
    chapel_npc, chapel_front = chapel(z, dn, CHAPEL, hrot)
    z.npc("sealed_chapel", round(chapel_npc[0], 2), round(chapel_npc[1], 2), hrot)
    z.npc("duke_lumeria", round(ofront[0] + 2.0, 2), round(ofront[1] + 3.0, 2), orot)       # L3: o Duque libertado, no pórtico
    z.data["places"] = [
        {"id": "relojoeiro", "type": "cabin", "pos": list(CLOCK), "npc": "clockmaker"},
        {"id": "lucidos", "type": "camp", "pos": list(BC)},
        {"id": "capela_selada", "type": "shrine", "pos": list(CHAPEL), "npc": "sealed_chapel"},
        {"id": "opera", "type": "dungeon", "pos": [round(ofront[0], 2), round(ofront[1], 2)], "dungeon": "dg_mirrors"},
    ]

    # ---------- portões da cidade: arcos de fitas e máscaras ----------
    for g in (GATE_N, GATE_SE):
        a = math.radians(g)
        for s in (-1, 1):
            q = H(WALL_R - 3.0, g + s * math.degrees(5.6 / WALL_R))
            dn.flag(q, BUNTING[0 if s > 0 else 2], h=6.0, rot=-g + 90.0, tatter=False, w=1.3, drop=2.6, pole=OLD_GOLD)
        mask(dn, "portao", H(WALL_R - 1.0, g + math.degrees(5.3 / WALL_R)), 4.9, facing(-math.cos(a), -math.sin(a)), 1.2)

    # ---------- casas: frente de rua, encostadas na muralha, miolo ----------
    keep = [((0.0, 0.0), PLAZA_R + 2.0), (MARKET, MARKET_R + 2.5), (FORECOURT, FORECOURT_R + 2.0), (OPERA, 17.0), (GARDEN, GARDEN_R + 11.0),
            (CLOCK, 8.5), (clock_front, 3.0), (CHAPEL, 9.5), (chapel_front, 3.5), (SE_JUNCTION, 4.0),
            (H(PLAZA_R + 5.2, STAGE_DEG[0]), 6.0), (H(PLAZA_R + 5.2, STAGE_DEG[1]), 6.0), ((-21.0, -74.0), 6.0), (OPERA_STAGE, 6.0),
            (H(GARDEN_R + 9.5, 300.0, GARDEN), 6.0), (n_in, 6.0), (se_in, 6.0), (H(WALL_R, GATE_N), 7.0), (H(WALL_R, GATE_SE), 7.0)]
    keep += [(H(BR + 4.0, g, BC), 9.0) for g, _hw in B_GATES if g != 180.0]
    city = City(z, dn, widths, keep)
    city.along_roads(rnd)
    city.wall_ring(rnd)
    city.infill(rnd)
    print("casas: %d" % city.n)

    # ---------- festa ----------
    lots = [(c, r * 0.72) for c, r in city.lots] + [(Vector(c), r * 0.8) for c, r in keep[5:17]]
    festoon(z, dn, dA, dB, widths, lots, rnd)
    confetti(z, d_conf, d_morn, widths, [((0.0, 0.0), PLAZA_R), (MARKET, MARKET_R), (FORECOURT, FORECOURT_R), (GARDEN, GARDEN_R)], rnd)

    # ---------- borda: morros de vinhedo (encosta em patamares, fileiras de videira roxa) ----------
    mats = [z.M["cliff_rock"], z.M["cliff_rock_d"], z.M["cliff_grass"], None]
    nature.mountain_ring(z.coll, z.P + "penhascos", z.rim_r, z.portal_angles, mats, z.ob, seed=z.seed, ledge_trees="bush",
                         tree_cols=[(0.5, 0.36, 0.6), (0.44, 0.32, 0.54), (0.46, 0.58, 0.4)], boulder_col=(0.72, 0.68, 0.6))
    for i in range(0, 180, 2):
        a = math.tau * (i + 1) / 180
        r0 = z.rim_r(a) + 3.5
        seg = r0 * math.tau / 180 * 2 * 1.25
        z.ob("cliff", math.cos(a) * r0, math.sin(a) * r0, (seg, 6.0, 7.0), along(-math.sin(a), math.cos(a)), visible=False)
    vine = [dn.m("videira_roxa", (0.5, 0.36, 0.6)), dn.m("videira_verde", (0.44, 0.6, 0.4))]
    stake = dn.m("videira_estaca", (0.6, 0.5, 0.4))
    for row, rr in enumerate((WALL_R + 3.4, WALL_R + 5.8, WALL_R + 8.2, WALL_R + 10.6)):      # fileiras de videira (leem de cima como faixas paralelas)
        n = int(math.tau * rr / 3.2)
        for i in range(n):
            a = math.tau * (i + 0.5) / n
            if rr > z.rim_r(a) - 2.2 or any(zone_lib.angdiff(a, math.radians(g)) * rr < 8.0 for g in (GATE_N, GATE_SE, GATE_W)) or i % 9 == 8:
                continue
            q = (math.cos(a) * rr, math.sin(a) * rr)
            dn.box("vinha", vine[(i // 3 + row) % 2], q, (3.0, 0.9, 0.7), along(-math.sin(a), math.cos(a)), 0.25)
            dn.cyl("vinha", stake, q, 0.06, 0.05, 1.3, 0.0, 4)
    for i in range(72):                                       # ciprestes e videiras na faixa de fora da muralha
        a = math.tau * i / 72 + rnd.uniform(-0.02, 0.02)
        r = z.rim_r(a) - rnd.uniform(0.6, 1.8)
        x, zz = math.cos(a) * r, math.sin(a) * r
        if any(zone_lib.angdiff(a, math.radians(g)) * r < 9.0 for g in (GATE_N, GATE_SE, GATE_W)) or i % 3:
            continue
        z.ob("tree", x, zz, (1.5, 4.4, 1.5), color=(0.3, 0.5, 0.36))

    # ---------- foliões (L0: bairros de fora; em bando, não espalhados. Teto do GDD §11: <= 110 vivos) ----------
    # O jogo multiplica count > 1 por Balance.SPAWN_COUNT_MULT (1,6) e o Mestre traz 3 de escolta: conta antes de engordar.
    M = MOBS
    b_bells, b_mirrors = {"unless": Q_BELLS}, {"unless": Q_MIRRORS}
    sp = z.spawner
    sp(M["master"], 0.0, 9.0, 5, 1, 240.0, when=b_bells)               # o Mestre de Cerimônias do campanário (hx3_bells)
    sp(M["reveler"], -12.0, 11.0, 7, 3, 24.0)
    sp(M["reveler"], 14.0, 9.0, 7, 3, 24.0)
    sp(M["reveler"], -8.0, -58.0, 7, 3, 24.0, when=b_bells)            # Mercado das Taças: dormem quando os sinos calam
    sp(M["reveler"], 9.0, -67.0, 7, 3, 24.0, when=b_bells)
    sp(M["reveler"], -2.0, -86.0, 6, 2, 24.0, when=b_bells)
    sp(M["reveler"], -36.0, -48.0, 6, 2, 24.0, when=b_bells)
    sp(M["reveler"], 46.0, -4.0, 8, 3, 24.0)                           # largo da Ópera
    sp(M["master"], 54.0, 3.0, 5, 1, 180.0)
    sp(M["chorister"], 52.0, -12.0, 6, 2, 26.0)
    sp(M["reveler"], 44.0, -30.0, 6, 2, 24.0)
    sp(M["reveler"], 55.0, 24.0, 6, 2, 24.0)
    sp(M["reveler"], 48.0, 42.0, 7, 3, 24.0)                           # encruzilhada do Cortejo
    sp(M["hound"], 66.0, 54.0, 6, 2, 26.0)
    sp(M["reveler"], -4.0, 60.0, 7, 3, 24.0, when=b_mirrors)           # Jardim das Fontes: somem em L3
    sp(M["reveler"], 13.0, 66.0, 7, 3, 24.0, when=b_mirrors)
    sp(M["chorister"], 4.0, 75.0, 6, 2, 26.0, when=b_mirrors)
    sp(M["reveler"], -38.0, 42.0, 6, 2, 24.0)
    live = sum((int(math.ceil(s["count"] * 1.6)) if s["count"] > 1 else 1) + (3 if s["monster_id"] == M["master"] else 0) for s in z.data["spawners"])
    print("vivos em L0 (com escolta e x1,6): %d" % live)

    # ---------- dados para a integração (WP5) ----------
    z.data["future_portals"] = [
        {"id": "to_dg_mirrors", "pos": [round(odoor[0], 2), round(odoor[1], 2)], "arrive": [round(ofront[0], 2), round(ofront[1], 2)],
         "target_map": "dg_mirrors", "label": "Galeria dos Espelhos (Lv 48-49)", "if": Q_BELLS},
    ]
    z.data["stage_tags"] = [
        {"tag": "lum_acesa_a", "unless": Q_MIRRORS}, {"tag": "lum_acesa_b", "unless": Q_VEIL},
        {"tag": "l0_barricada", "unless": Q_BELLS}, {"tag": "l1_portao_aberto", "if": Q_BELLS},
        {"tag": "l0_palacio_fechado", "unless": Q_BELLS}, {"tag": "l1_forja_ana", "if": Q_BELLS},
        {"tag": "l3_duque", "if": Q_MIRRORS}, {"tag": "l0_confete", "unless": Q_VEIL}, {"tag": "l4_manha", "if": Q_VEIL},
    ]
    z.data["stage_npcs"] = {"lumeria_dwarf_smith": {"if": Q_BELLS}, "lumeria_masters_herald": {"if": Q_BELLS}, "duke_lumeria": {"if": Q_MIRRORS}}
    z.data["crystal_hint"] = list(crystal)
    z.data["trainer_hint"] = list(trainer)
    z.data["town"]["centerpiece"] = {"kind": "sino_abafado", "bell": list(BC), "max_height": 3.7, "plaza_r": B_PLAZA_R, "crystal": list(crystal),
                                     "trainer": list(trainer)}
    z.data["poi"] = {"bairro": list(BC), "praca": [0.0, 0.0], "campanario": list(TOWER), "mercado": list(MARKET), "opera": list(FORECOURT),
                     "jardim": list(GARDEN), "relojoeiro": [round(clock_front[0], 2), round(clock_front[1], 2)],
                     "capela": [round(chapel_front[0], 2), round(chapel_front[1], 2)], "portao_n": list(n_in), "portao_se": list(se_in), "chegada": list(w_in)}
    z.data["monster_ids"] = dict(MOBS)
    # Ronda do Festim (MOB_PATROLS): a volta dos anéis, do Mercado ao Jardim pelo leste
    ronda = [p for name in ("anel_ne", "anel_se") for p in z.road_polys[name][::6]]
    z.data["patrol_hint"] = [{"id": "ronda_festim", "mob": M["reveler"], "route": [[round(p.x, 1), round(p.y, 1)] for p in ronda], "unless": "hx3_veil_open"}]
    # Festim Sem Fim (RoadEventSystem): pontos na beira das ruas de fora, >= 40 m do Bairro e >= 30 m entre si
    z.data["events"] = []
    for kind, name, frac, side, mob in (("forced_dance", "anel_se", 0.3, 1, M["dancer"]), ("banquet", "norte", 0.5, -1, M["reveler"]),
                                        ("choir_corner", "anel_ne", 0.45, 1, M["chorister"]), ("mirror_girl", "sul", 0.55, 1, M["reflection"]),
                                        ("banquet", "portao_se", 0.3, -1, M["reveler"])):
        poly = z.road_polys[name]
        i = max(1, min(len(poly) - 2, int(len(poly) * frac)))
        t = (poly[i + 1] - poly[i - 1]).normalized()
        p = poly[i] + Vector((-t.y, t.x)) * side * (widths[name] * 0.5 - 0.9)
        z.data["events"].append({"kind": kind, "pos": [round(p.x, 2), round(p.y, 2)], "mob": mob, "road": name})
    z.data["gather_hint"] = [
        {"item": "Fita do Festim", "shape": "crate", "pos": [SE_JUNCTION[0] - 6.0, SE_JUNCTION[1] + 4.0], "radius": 9.0, "count": 4},
        {"item": "Porcelana Chorosa", "shape": "relic", "pos": [MARKET[0] + 10.0, MARKET[1] + 9.0], "radius": 6.0, "count": 2},
        {"item": "engrenagens (O Relojoeiro)", "shape": "ore", "pos": [MARKET[0] - 9.0, MARKET[1] - 8.0], "radius": 6.0, "count": 3},
    ]
    z.data["ground_hint"] = {"ground_color": list(PAVING), "note": "calcamento creme; o Bairro e os largos pintam por cima"}

    act3_ready.promote(z.data)       # future_portals de mapa já registrado viram portal (act3_ready.READY)
    for d in (dn, dA, dB, d_bar, d_open, d_pal, d_dwarf, d_conf, d_morn, d_duke):
        d.flush()
    poi = {"praca": (0.0, 4.0), "bairro": BC, "mercado": MARKET, "opera": FORECOURT, "jardim": GARDEN, "relojoeiro": clock_front, "capela": chapel_front,
           "portao_n": n_in, "portao_se": se_in, "chegada": w_in}[os.environ.get("LUMERIA_POI", "praca")]
    return z.finish(export, poi=poi, ground=PAVING)
