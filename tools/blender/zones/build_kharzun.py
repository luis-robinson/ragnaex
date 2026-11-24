"""Monte Kharzun (field_kharzun, Lv 40-45): a terra da Horda. Vale de basalto e cinza fechado por penhascos escuros; ao
norte a encosta da montanha, com a cidadela entalhada nos ombros da garganta e a Presa de Kharzun (marco) num esporão.
No centro, o Acampamento Avançado da Aurora: estacas claras viradas para a montanha, carroças viradas para as Estepes,
braseiro-marco na praça; cresce por estágio (torres, forja anã, máquinas de cerco, festa).
Um rio de LAVA nasce na encosta noroeste, corta o norte do vale e morre no Lago de Fogo (leste): só se cruza nas três
pontes de basalto (estrada norte, estrada da Forja ao Canil, trilha da encosta). A lava é água para a sim (kind river /
lake no JSON: colide, vão só nas pontes) e `glow_lava` para o jogo (brilha e tremula; `water_tints` pinta o minimapa).
POIs: Minas de Escravos (oeste), Canil dos Lobos Atrozes (leste), Forja Negra (nordeste, além da lava), Salão dos
Matadores (noroeste, boca num paredão: dg_slayers), Portão da Cidadela (norte, barbacã na garganta: kharzun_citadel).
Lugares: Cabana do Xamã Exilado, Posto dos Libertos, Santuário Partido dos Anões, emboscada dos ginetes.
Sul = garganta das Estepes de Cinza (chegada). Leste-nordeste = garganta de Lumeria (Ato III; aberta DEPOIS da zona
aprovada: `east_gorge`, no fim do build, para o resto do mapa sair igual).

    set RAGNAEX_ROOT=<projeto ou worktree>
    blender -b --factory-startup --python tools/blender/zones/run_zone.py -- build_kharzun <pasta_png> --export
    (KHARZUN_POI=<minas|canil|forja|matadores|portao|presa|xama|libertos|santuario|lago|chegada|lumeria> escolhe o alvo da CAM_poi)
"""
import math
import os
import random
import bmesh
import bpy
from mathutils import Vector, noise

import act2_dress
import horde
import nature
import places
import zone_lib
from zone_lib import B, Zone, _obj, along, angdiff, box, catmull, cyl, cone, disc, mat, mat_c, poly_dist, ribbon

ZONE = "field_kharzun"
STEPPE_ARRIVE = (0.0, -102.2)           # chegada em field_steppe (field_steppe.json -> future_portals[0].arrive)
# Mapas de destino que ainda não existem: o portal sai em data["future_portals"] (como o passo de Kharzun nas Estepes) e
# NÃO em data["portals"] (portal para mapa que não existe quebra `_check_portal_arrivals` e a viagem dos bots).
# Os dois mapas já existem (WP6: build_dungeons dg_slayers, build_kharzun_citadel): a lista fica vazia e os portais saem de verdade.
FUTURE_MAPS = ()
# Ato III (design/gdd/ato3-excesso-45-50.md, WP2): garganta a leste-nordeste para Lumeria (id to_city_lumeria; portão do
# catálogo: nível 45 + hx_act2_epilogue). WP5 registrou city_lumeria: LUMERIA_READY = True põe o portal em data["portals"].
LUMERIA_READY = True
LUMERIA_DEG = -12.0                     # entre o Lago de Fogo e o Canil; sai da estrada Forja-Canil em (80, -20)
LUMERIA_ARRIVE = (-96.0, 0.0)           # chegada em city_lumeria (build_lumeria imprime "BACK kharzun")
LUMERIA_ROAD = [(80.0, -20.0), (88.5, -22.8)]
CITADEL_ARRIVE = (0.0, 96.0)            # chegada no mapa da cidadela (desenho "chegada ao sul", como as fortalezas)
HUB_R = 26.0
HUB_GATES = [0.0, 90.0, 180.0, -90.0]   # graus: leste (Canil), sul (Estepes), oeste (Minas), norte (montanha)
GATE_HALF = 4.6
LAVA_W = 9.0

# missões que mudam o cenário (plano 2.4)
Q_MINES, Q_KENNEL, Q_FORGE, Q_SLAYERS, Q_GATE, Q_WARLORD = "hx_mines", "hx_kennel", "hx_black_forge", "hx_slayers", "hx_citadel_gate", "hx_warlord"

# ids do elenco 40-45 (plano §3). O pacote de monstros (WP3) define os ids finais: troque AQUI e refaça o JSON.
MOBS = {
    "assassin": "goblin_assassin", "wolf": "dire_wolf", "rider": "dire_wolf_rider", "thrower": "troll_thrower",
    "fire_archer": "orc_fire_archer", "warlord": "orc_warlord", "slayer": "goblin_slayer", "salamander": "lava_salamander",
    "brute": "troll_brute", "clan_guard": "clan_guard", "golem": "basalt_golem", "dire_mother": "boss_dire_mother",
    # escoltas que já existem (35-38)
    "troll": "troll", "agitator": "goblin_agitator", "warrior": "orc_warrior", "raider": "wolf_raider", "crossbow": "orc_crossbow",
}

MINES = (-80.0, -4.0)
MINE_HILL = (-99.0, -6.0)
KENNEL = (88.0, 10.0)
KENNEL_R = 14.0
FORGE = (56.0, -74.0)
FORGE_R = 14.0
BARBICAN = (0.0, -101.0)
FANG = (33.0, -97.0)                    # Presa de Kharzun (marco)
SHRINE = (-76.0, 38.0)
SHAMAN = (-46.0, 16.0)
FREED = (30.0, 62.0)
AMBUSH = (64.0, 57.0)
FIRE_LAKE = (100.0, -41.0)
FIRE_LAKE_R = 9.0
SW_LAKE = (-60.0, 73.0)
SW_LAKE_R = 10.0
LAVA = [(-60.0, -128.0), (-52.0, -106.0), (-40.0, -86.0), (-28.0, -68.0), (-12.0, -54.0), (10.0, -49.0), (36.0, -50.0), (60.0, -47.0),
        (84.0, -44.0), (98.0, -41.5)]

AURORA_BLUE = (0.36, 0.48, 0.78)
STAKE_AURORA = (0.62, 0.48, 0.32)
BASALT = (0.3, 0.28, 0.31)
BASALT_D = (0.21, 0.2, 0.23)
ASH = (0.5, 0.46, 0.45)
LAVA_COL = (1.0, 0.38, 0.1)             # o jogo mistura amarelo no miolo (Materials.fire): a base vai mais vermelha
CRUST = (0.17, 0.14, 0.14)
CITADEL_DARK = (0.25, 0.23, 0.3)     # coroa das torres / topo da fornalha: ardósia azulada (era 0.17: preto chapado no toon)
GROUND = (0.38, 0.31, 0.31)          # cor do chão no jogo (MapDef.ground_color): basalto quente
TRAIL_COL = (0.6, 0.54, 0.49)        # trilha dos lugares: cinza batida, um tom abaixo da estrada
CHAR = [(0.2, 0.17, 0.16), (0.27, 0.22, 0.2), (0.33, 0.26, 0.22)]

PLACES = [
    {"type": "cabin", "id": "xama", "pos": SHAMAN, "face": -74.0, "npc": "exiled_shaman", "roof": (0.4, 0.3, 0.3), "wall": (0.5, 0.42, 0.36),
     "ground": (0.46, 0.4, 0.36)},
    {"type": "cabin", "id": "libertos", "pos": FREED, "face": -69.0, "npc": "freed_foreman", "roof": (0.56, 0.5, 0.46), "wall": (0.6, 0.56, 0.52),
     "ground": (0.5, 0.46, 0.42)},
    {"type": "shrine", "id": "santuario_anoes", "pos": SHRINE, "npc": "dwarf_runestone", "ground": (0.52, 0.52, 0.56)},
    {"type": "camp", "id": "emboscada", "pos": AMBUSH, "face": 200.0, "mob": MOBS["rider"], "count": 1, "cloth": horde.HORDE_RED, "respawn": 32.0,
     "ground": (0.34, 0.3, 0.29)},
    {"type": "dungeon", "id": "matadores", "dungeon": "dg_slayers"},
]


def polar(z, ang_deg, inset):
    a = math.radians(ang_deg)
    r = z.rim_r(a) - inset
    return (round(math.cos(a) * r, 1), round(math.sin(a) * r, 1))


def H(r, deg, c=(0.0, 0.0)):
    return (round(c[0] + math.cos(math.radians(deg)) * r, 2), round(c[1] + math.sin(math.radians(deg)) * r, 2))


def route_of(*polys, step=7):
    """Rota de marcha (do fim da estrada ao hub): pontos das estradas dadas, de trás para a frente."""
    out = []
    for poly in polys:
        pts = list(reversed(poly))[::step]
        out += [[round(p.x, 1), round(p.y, 1)] for p in pts]
    return out


# ---------------------------------------------------------------------------------------------------------------
# lava
# ---------------------------------------------------------------------------------------------------------------
def lava_river(z, pts, w):
    """Rio de lava: para a sim é um rio (colide; vão onde uma estrada cruza); crosta escura nas margens."""
    poly = z.river(pts, w=w, material="glow_lava")
    z.data["water"][-1]["lava"] = True
    ribbon(z.coll, z.P + "lava_crosta_%d" % len(z.rivers), poly, w + 3.6, 0.0092, z.M["patch_lava_crosta"])      # acima da margem do rio (0.008): 1 mm de folga, sem briga
    for p in poly[::2]:                                    # sem grama na crosta
        z.data["roads"].append({"kind": "street", "w": 0, "pts": [[round(p.x, 2), round(p.y, 2)]], "r": round(w * 0.5 + 2.0, 2)})
    return poly


def lava_lake(z, name, c, r):
    z.lake(name, c, r, material="glow_lava")
    z.data["water"][-1]["lava"] = True
    disc(z.coll, z.P + "lava_crosta_" + name, c, r + 2.6, 0.0102, z.M["patch_lava_crosta"], 40, 0.09, len(name) + 2)
    z.data["roads"].append({"kind": "street", "w": 0, "pts": [[c[0], c[1]]], "r": r + 2.6})


def lava_fall(z, name, pts, w):
    """Lava descendo a encosta (fora do andável): fita inclinada por pontos (x, z, altura)."""
    bm = bmesh.new()
    L, R = [], []
    n = len(pts)
    for i, p in enumerate(pts):
        a, b = pts[max(0, i - 1)], pts[min(n - 1, i + 1)]
        t = Vector((b[0] - a[0], b[1] - a[1])).normalized()
        nr = Vector((-t.y, t.x)) * (w * 0.5 * (0.55 + 0.45 * i / (n - 1)))
        L.append(bm.verts.new(B(p[0] + nr.x, p[1] + nr.y, p[2])))
        R.append(bm.verts.new(B(p[0] - nr.x, p[1] - nr.y, p[2])))
    for i in range(n - 1):
        bm.faces.new((L[i], R[i], R[i + 1], L[i + 1]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    return _obj(z.coll, z.P + "lava_queda_" + name, bm, z.M["glow_lava"])


def crag(z, name, c, r, h, seed=1, rings=7, segs=14, lava=0.0, flat=0.12, grass=False):
    """Pico facetado de basalto (anéis empilhados com ruído). `lava` = fração de faces baixas que viram veio de lava;
    `flat` = raio do topo (fração de r): onde pousa uma torre. Só visual (fica fora do andável)."""
    rnd = random.Random(seed)
    bm = bmesh.new()
    rows = []
    for j in range(rings + 1):
        t = j / rings
        rr = r * (flat + (1.0 - flat) * (1.0 - t) ** 1.25)
        y = h * (t ** 0.85)
        row = []
        for i in range(segs):
            a = math.tau * (i + 0.5 * (j % 2)) / segs
            k = 1.0 + (0.0 if j == rings else 0.2 * noise.noise(Vector((math.cos(a) * 2.2 + seed, math.sin(a) * 2.2, j * 0.8))))
            row.append(bm.verts.new(B(c[0] + math.cos(a) * rr * k, c[1] + math.sin(a) * rr * k, y * (1.0 + rnd.uniform(-0.04, 0.04) * (j < rings)))))
        rows.append(row)
    for j in range(rings):
        for i in range(segs):
            a, b = rows[j][i], rows[j][(i + 1) % segs]
            d, e = rows[j + 1][i], rows[j + 1][(i + 1) % segs]
            if j % 2:
                bm.faces.new((a, b, e))
                bm.faces.new((a, e, d))
            else:
                bm.faces.new((a, b, d))
                bm.faces.new((b, e, d))
    bm.faces.new(rows[-1])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    for f in bm.faces:
        cc = f.calc_center_median()
        nz = noise.noise(Vector((cc.x * 0.07 + seed, cc.y * 0.07, cc.z * 0.2)))
        f.material_index = 1 if nz > 0.05 else 0
        if grass and f.normal.z > 0.85:
            f.material_index = 2
        elif lava > 0.0 and h * 0.08 < cc.z < h * 0.7 and rnd.random() < lava * 2.5 and nz < 0.02:
            f.material_index = 3
    return _obj(z.coll, z.P + "pico_" + name, bm, [z.M["cliff_rock"], z.M["cliff_rock_d"], z.M["cliff_grass"], z.M["glow_lava"]])


def keep_tower(z, name, c, y0, r, h, roof=None, glow=True, horns=False, segs=8):
    """Torre da cidadela: fuste escuro que afina, coroa de ameias, fendas de lava, telhado em agulha (vermelho da Horda)."""
    stone = mat("cidadela_pedra", (0.24, 0.22, 0.26))
    dark = mat("cidadela_pedra_d", CITADEL_DARK)
    cyl(z.coll, z.P + name + "_fuste", c, r, r * 0.84, h, stone, y0, segs)
    cyl(z.coll, z.P + name + "_coroa", c, r * 1.02, r * 1.08, h * 0.1, dark, y0 + h, segs)
    for i in range(segs):
        if i % 2:
            continue
        a = math.tau * (i + 0.5) / segs
        box(z.coll, z.P + "%s_ameia_%d" % (name, i), (c[0] + math.cos(a) * r * 0.98, c[1] + math.sin(a) * r * 0.98), (r * 0.5, h * 0.07, r * 0.3),
            math.degrees(-a) + 90.0, dark, y0 + h * 1.1)
    if glow:
        gm = z.M["glow_lava"]
        for k in range(4):
            a = math.tau * k / 4 + 0.6
            box(z.coll, z.P + "%s_fenda_%d" % (name, k), (c[0] + math.cos(a) * r * 0.9, c[1] + math.sin(a) * r * 0.9), (r * 0.22, h * 0.16, r * 0.14),
                math.degrees(-a) + 90.0, gm, y0 + h * (0.5 + 0.12 * (k % 2)))
    if roof:
        cone(z.coll, z.P + name + "_agulha", c, r * 0.96, h * 0.42, mat_c("cidadela_teto_%d" % int(roof[0] * 100), roof), y0 + h * 1.1, segs)
    if horns:
        bone = mat("presa_osso", (0.86, 0.82, 0.72))
        for k in range(4):
            a = math.tau * k / 4 + math.pi / 4
            base = (c[0] + math.cos(a) * r * 1.5, c[1] + math.sin(a) * r * 1.5)
            horde.rib(z.coll, z.P + "%s_chifre_%d" % (name, k), base, a, h * 0.62, r * 0.7, r * 0.34, 0.08, bone)
    return y0 + h * 1.1


# ---------------------------------------------------------------------------------------------------------------
# hub: Acampamento Avançado da Aurora
# ---------------------------------------------------------------------------------------------------------------
def camp_wall(z):
    """Anel do acampamento: carroças no arco sul (a caravana que chegou), estacas claras no resto (de frente para a
    montanha). As estacas preenchem tudo que as carroças não cobrem, menos os quatro vãos: a colisão não tem fresta."""
    gates = [math.radians(g) for g in HUB_GATES]
    c = (0.0, 0.0)
    nw = int(math.tau * HUB_R / 6.4)
    wagons = []
    k = 0
    for i in range(nw):
        am = math.tau * (i + 0.5) / nw
        if math.sin(am) < 0.4 or any(angdiff(am, g) * HUB_R < GATE_HALF + 3.4 for g in gates):
            continue
        p = (math.cos(am) * HUB_R, math.sin(am) * HUB_R)
        rot = along(-math.sin(am), math.cos(am))
        horde.wagon(z, "hub_carroca_%d" % i, p, rot, [horde.CANVAS, (0.8, 0.74, 0.6), (0.9, 0.86, 0.78)][k % 3], solid=False)
        z.ob("wall", p[0], p[1], (6.6, 3.2, 2.8), rot, visible=False)
        wagons.append(am)
        k += 1
    stake = z.M["estaca_aurora"]
    n = max(16, int(math.tau * HUB_R / 2.2))
    for i in range(n):
        am = math.tau * (i + 0.5) / n
        if any(angdiff(am, g) * HUB_R < GATE_HALF + 0.4 for g in gates) or any(angdiff(am, w) * HUB_R < 3.0 for w in wagons):
            continue
        p = (math.cos(am) * HUB_R, math.sin(am) * HUB_R)
        seg = math.tau * HUB_R / n + 0.12
        rot = along(-math.sin(am), math.cos(am))
        for kk in (-0.25, 0.25):
            q = (p[0] - math.sin(am) * seg * kk, p[1] + math.cos(am) * seg * kk)
            h = 3.0 * (0.85 + 0.3 * ((i * 7 + int(kk * 4)) % 5) / 5)
            cyl(z.coll, z.P + "hub_estaca_%d_%d" % (i, int(kk * 4)), q, 0.42, 0.42, h, stake, 0.0, 6)
            cone(z.coll, z.P + "hub_ponta_%d_%d" % (i, int(kk * 4)), q, 0.44, 0.7, stake, h, 6)
        z.ob("wall", p[0], p[1], (seg, 3.0, 1.4), rot, visible=False)
    z.block(c, HUB_R + 2)


def flame(coll, name, c, r, h, material, y0, lean=(0.0, 0.0), segs=6):
    """Língua de chama: fuso facetado (barriga baixa, a 1/6 da altura, e ponta comprida e fina), a ponta tomba `lean` (x, z) metros.
    Sem sorteio: não mexe na dispersão da zona."""
    bm = bmesh.new()
    prof = ((0.0, 0.5), (0.17, 1.0), (0.42, 0.74), (0.68, 0.36), (0.86, 0.14))
    rings = []
    for i, (t, k) in enumerate(prof):
        ox, oz = lean[0] * t * t, lean[1] * t * t
        rings.append([bm.verts.new(B(c[0] + ox + math.cos(math.tau * (j + 0.5 * i) / segs) * r * k, c[1] + oz + math.sin(math.tau * (j + 0.5 * i) / segs) * r * k, y0 + h * t))
                      for j in range(segs)])
    tip = bm.verts.new(B(c[0] + lean[0], c[1] + lean[1], y0 + h))
    for a, b in zip(rings, rings[1:]):                    # anéis girados meio gomo: faces em triângulos (chama facetada)
        for j in range(segs):
            bm.faces.new((a[j], a[(j + 1) % segs], b[j]))
            bm.faces.new((a[(j + 1) % segs], b[(j + 1) % segs], b[j]))
    for j in range(segs):
        bm.faces.new((rings[-1][j], rings[-1][(j + 1) % segs], tip))
    bm.faces.new(list(reversed(rings[0])))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    return _obj(coll, name, bm, material)


def aurora_camp(z):
    z.M["patch_hub_terra"] = mat("patch_hub_terra", (0.72, 0.63, 0.5))
    z.patch("hub", (0.0, 0.0), HUB_R + 5.0, (0.6, 0.52, 0.43))
    z.plaza("hub", (0.0, 0.0), HUB_R - 2.5, "patch_hub_terra")
    camp_wall(z)
    z.data["town"] = {"center": [0.0, 0.0], "radius": HUB_R, "gates": [list(H(HUB_R, g)) for g in HUB_GATES]}
    for g in HUB_GATES:                                   # mastros azuis e lampiões nos quatro vãos
        for sgn in (-1, 1):
            q = H(HUB_R, g + sgn * 12.4)
            horde.banner(z, "hub_vao_%d_%d" % (int(g), sgn), q, AURORA_BLUE, 4.8, -g + 90.0)
            z.ob("pillar", q[0], q[1], (0.7, 4.8, 0.7), visible=False)
            lq = H(HUB_R - 3.2, g + sgn * 12.0)
            z.ob("lamp", lq[0], lq[1], (0.4, 3.0, 0.4))
    # braseiro-marco no meio da praça: dois degraus de pedra, taça de ferro com aro, leito de carvão e chama em línguas
    # (art review 15: era um cone liso de 3 m sobre pedestal claro, 5,9 m ao todo: lia como peça sem acabar e tapava quem
    # passava atrás). Agora 4,7 m: miolo claro alto, línguas laranja tortas em volta, brasa rubra no leito. Só visual:
    # o colisor é o mesmo e nada aqui gasta sorteio da zona.
    stone = mat("braseiro_pedra", (0.58, 0.55, 0.54))
    iron = mat("braseiro", (0.22, 0.2, 0.2))
    cyl(z.coll, z.P + "hub_braseiro_degrau", (0.0, 0.0), 2.6, 2.45, 0.35, mat("braseiro_pedra2", (0.43, 0.4, 0.41)), 0.0, 10)
    cyl(z.coll, z.P + "hub_braseiro_base", (0.0, 0.0), 2.05, 1.85, 0.35, stone, 0.35, 10)
    cyl(z.coll, z.P + "hub_braseiro_pe", (0.0, 0.0), 0.75, 0.55, 0.75, iron, 0.7, 8)
    cyl(z.coll, z.P + "hub_braseiro_taca", (0.0, 0.0), 0.8, 1.7, 0.65, iron, 1.45, 10)
    cyl(z.coll, z.P + "hub_braseiro_aro", (0.0, 0.0), 1.84, 1.84, 0.16, mat("braseiro_aro", (0.5, 0.36, 0.22)), 2.04, 10)
    cyl(z.coll, z.P + "hub_braseiro_carvao", (0.0, 0.0), 1.62, 1.5, 0.1, mat("braseiro_carvao", (0.15, 0.12, 0.12)), 2.14, 10)
    ember = mat("glow_brasa_fundo", (0.98, 0.34, 0.1))
    for k in range(7):                                    # brasas no leito, entre as línguas
        a = math.tau * (k + 0.5) / 7
        box(z.coll, z.P + "hub_braseiro_brasa_%d" % k, (math.cos(a) * 1.22, math.sin(a) * 1.22), (0.34, 0.14, 0.26), math.degrees(-a) + 20.0 * (k % 3), ember, 2.2)
    flame(z.coll, z.P + "hub_braseiro_chama", (0.0, 0.0), 0.74, 2.5, mat("glow_brasa_miolo", (1.0, 0.8, 0.36)), 2.2, (0.3, 0.16), 7)
    hot = mat("glow_brasa", (1.0, 0.56, 0.2))
    for k in range(5):                                    # línguas: saem da borda do leito e tombam para fora, alturas alternadas
        a = math.tau * k / 5 + 0.3
        ux, uz = math.cos(a), math.sin(a)
        hgt = (1.9, 1.3, 1.7, 1.2, 1.5)[k]
        flame(z.coll, z.P + "hub_braseiro_lingua_%d" % k, (ux * 0.8, uz * 0.8), 0.5, hgt, hot, 2.2, (ux * 0.5 - uz * 0.16, uz * 0.5 + ux * 0.16), 6)
    for k in range(5):                                    # línguas rubras baixas nos vãos (a base da chama é mais escura que o miolo)
        a = math.tau * (k + 0.5) / 5 + 0.3
        ux, uz = math.cos(a), math.sin(a)
        flame(z.coll, z.P + "hub_braseiro_rubra_%d" % k, (ux * 1.05, uz * 1.05), 0.32, 0.85, ember, 2.2, (ux * 0.26 + uz * 0.1, uz * 0.26 - ux * 0.1), 5)
    z.ob("pillar", 0.0, 0.0, (4.6, 3.0, 4.6), visible=False)
    cyl(z.coll, z.P + "hub_mastro", (4.2, -4.2), 0.18, 0.12, 9.5, mat("vigia", (0.52, 0.38, 0.24)), 0.0, 6)
    horde.cloth(z.coll, z.P + "hub_bandeira", (4.2, -4.2), 2.6, 1.7, 0.0, mat("bandeira_aurora", horde.AURORA_GOLD), 7.6, tail=None)
    z.ob("pillar", 4.2, -4.2, (0.7, 9.5, 0.7), visible=False)
    # nordeste: forja de campo da Aurora
    horde.wagon(z, "hub_forja", H(19.0, -45.0), 45.0, (0.5, 0.36, 0.3), length=4.6)
    z.ob("anvil", *H(13.5, -37.0), (1.0, 0.9, 0.6), 30.0)
    z.ob("barrel", *H(14.5, -55.0), (0.8, 1.0, 0.8))
    # sudeste: mercado
    for i, a in enumerate((30.0, 58.0)):
        z.ob("stall", *H(17.0, a), (3.0, 2.4, 2.0), -a + 90.0, color=[(0.82, 0.7, 0.36), (0.36, 0.5, 0.74)][i])
    # sudoeste: depósito + lugar do cristal
    horde.wagon(z, "hub_deposito", H(19.0, 128.0), -128.0 + 90.0, (0.74, 0.7, 0.6), length=4.6)
    for k, a in enumerate((112.0, 119.0, 142.0)):
        z.ob("crate", *H(14.5 + (k % 2) * 1.2, a), (1.0, 1.0, 1.0), k * 25.0)
    # noroeste: alquimia
    z.ob("tent", *H(19.0, -135.0), (3.2, 2.3, 3.0), 135.0 - 90.0, color=(0.5, 0.74, 0.6))
    z.ob("cauldron", *H(13.5, -124.0), (1.1, 1.0, 1.1))
    z.ob("well", *H(13.0, -152.0), (1.6, 1.4, 1.6))
    for k, a in enumerate((35.0, 145.0, 215.0, 325.0)):      # troncos-banco em volta do braseiro
        p = H(5.6, a)
        z.ob("log", p[0], p[1], (2.6, 0.6, 0.65), -a + 90.0, color=(0.46, 0.34, 0.24))
    z.npc("kharzun_commander", 3.0, 7.0, 0.0)
    z.npc("kharzun_smith", *H(11.0, -44.0), 140.0)
    z.npc("kharzun_merchant", *H(12.5, 44.0), -135.0)
    z.npc("kharzun_storage", *H(12.5, 126.0), -50.0)
    z.npc("kharzun_alchemist", *H(11.0, -132.0), 50.0)
    z.npc("kharzun_board", *H(15.5, 104.0), 180.0)             # quadro de caçadas
    z.npc("masters_herald", *H(10.5, 168.0), 90.0)             # Arauto dos Mestres (D7)
    z.npc("dwarf_smith", *H(15.5, -70.0), 160.0)               # K1 (hx_mines)
    z.npc("kharzun_arms_merchant", *H(13.0, 16.0), -100.0)     # K1c (hx_black_forge)
    z.npc("kharzun_siege_engineer", *H(34.0, -63.0), 150.0)    # K2 (hx_citadel_gate), no pátio das máquinas
    z.npc("kharzun_orc_surrendered_a", *H(9.0, 76.0), 180.0)   # K4 (hx_warlord)
    z.npc("kharzun_orc_surrendered_b", *H(10.5, 86.0), 180.0)
    for i, g in enumerate((-90.0, 0.0, 180.0)):           # sentinelas: norte e leste recebem o Contra-ataque; oeste olha as Minas
        for k, (role, off) in enumerate((("knight", -2.6), ("spearman", 2.6), ("crossbow", 0.0))):
            px, pz = H(HUB_R - (4.2 if role != "crossbow" else 7.4), g)
            a = math.radians(g)
            z.npc("kharzun_g_%s_%d" % (role, i * 3 + k), round(px - math.sin(a) * off, 2), round(pz + math.cos(a) * off, 2), 180.0)
    for i, g in enumerate((-90.0, 0.0)):                  # libertos no muro (K1): dois em cada vão atacado
        for k, off in enumerate((-6.6, 6.6)):               # por fora do vão, ao pé das torres novas
            px, pz = H(HUB_R + 2.6, g)
            a = math.radians(g)
            z.npc("kharzun_f_spearman_%d" % (i * 2 + k), round(px - math.sin(a) * off, 2), round(pz + math.cos(a) * off, 2), 180.0)
    z.data["hangouts"] = [list(H(r, a)) for r, a in ((7.5, 20.0), (7.5, 150.0), (8.0, -110.0), (8.5, 80.0), (15.0, 8.0), (15.0, 84.0),
                                                      (15.5, 172.0), (15.5, -82.0), (20.0, 76.0), (20.0, -14.0), (20.0, 100.0), (20.5, -100.0))]
    z.data["crystal_hint"] = list(H(14.0, 156.0))
    z.cam_game = (0.0, 0.0)
    z.block((0.0, 0.0), HUB_R + 6.0)
    z.block(H(34.0, -63.0), 7.0)                           # pátio das máquinas de cerco (fora do muro, lado norte-leste)


# ---------------------------------------------------------------------------------------------------------------
# POIs
# ---------------------------------------------------------------------------------------------------------------
def slave_mines(z):
    """Minas de Escravos: morro de basalto com a boca escorada virada para o pátio, torre de vigia, estandartes; as
    jaulas, os trilhos e o minério vêm do acabamento."""
    c = MINES
    z.patch("minas", c, 18.0, (0.5, 0.36, 0.27))
    z.hill("mina", MINE_HILL, 10.0, 3, rock="cliff_rock", top="cliff_grass", step=2.3)
    mouth = (MINE_HILL[0] + 10.2, MINE_HILL[1] + 0.8)
    wood = mat("mina_escora", (0.44, 0.32, 0.22))
    box(z.coll, z.P + "mina_boca", mouth, (1.6, 3.2, 4.4), 0.0, mat("dungeon_boca", (0.03, 0.03, 0.05)), 0.0)
    for s in (-1, 1):
        box(z.coll, z.P + "mina_escora_%d" % (s > 0), (mouth[0] + 0.7, mouth[1] + s * 2.5), (0.6, 3.6, 0.6), 0.0, wood, 0.0)
    box(z.coll, z.P + "mina_verga", (mouth[0] + 0.7, mouth[1]), (0.7, 0.6, 6.2), 0.0, wood, 3.4)
    z.ob("wall", mouth[0], mouth[1], (2.0, 3.6, 6.0), 0.0, visible=False)
    horde.watchtower(z, "mina_torre", (c[0] + 9.0, c[1] - 11.0), horde.HORDE_RED)
    for k, (dx, dz) in enumerate(((11.0, 6.5), (11.0, -5.0))):       # estandartes na chegada da estrada
        p = (c[0] + dx, c[1] + dz)
        horde.banner(z, "k1_minas_horda_%d" % k, p, horde.HORDE_RED, 6.0, 90.0)
        horde.banner(z, "k1_minas_aurora_%d" % k, p, horde.AURORA_GOLD, 6.0, 90.0, pole=(0.82, 0.68, 0.48))
        z.ob("pillar", p[0], p[1], (0.6, 6.0, 0.6), visible=False)
    horde.campfire(z, "minas_fogueira", (c[0] - 4.0, c[1] + 6.5), 1.2)
    for k, (dx, dz) in enumerate(((-3.0, -9.5), (2.5, -10.5), (-8.0, 9.5))):   # escravos (TALK em hx_mines; depois vão para o posto)
        z.npc("mine_slave_%s" % "abc"[k], c[0] + dx, c[1] + dz, 180.0)
    z.block(c, 17.0)
    return mouth


def dire_kennel(z):
    """Canil dos Lobos Atrozes: anel de estacas escuras com três vãos (as três estradas), chão de terra revirada."""
    c = KENNEL
    z.patch("canil", c, KENNEL_R + 7.0, (0.56, 0.46, 0.3))
    z.data["roads"].append({"kind": "street", "w": 0, "pts": [list(c)], "r": KENNEL_R - 1.0})
    gates = [math.radians(g) for g in (180.0, -90.0, 90.0)]
    z.ring_wall("canil", c, KENNEL_R, gates, gate_half=3.8, height=2.8, material="estaca_horda", stakes=True)
    for k, g in enumerate((180.0, -90.0, 90.0)):
        for s in (-1, 1):
            p = H(KENNEL_R + 0.5, g + s * 21.0, c)
            horde.banner(z, "k1b_canil_horda_%d_%d" % (k, s > 0), p, horde.HORDE_RED, 6.0, -g + 90.0)
            horde.banner(z, "k1b_canil_aurora_%d_%d" % (k, s > 0), p, horde.AURORA_GOLD, 6.0, -g + 90.0, pole=(0.82, 0.68, 0.48))
            z.ob("pillar", p[0], p[1], (0.6, 6.0, 0.6), visible=False)
    horde.skull(z, "canil_cranio", H(9.0, 40.0, c), math.radians(200.0), 0.9, low=True)      # arena da Mãe-Loba: baixo, não tapa a luta
    z.block(c, KENNEL_R + 6.0)


def black_forge(z):
    """Forja Negra: anel de estacas com dois vãos, a fornalha de pedra com chaminés acesas, poça de lava canalizada."""
    c = FORGE
    z.patch("forja", c, FORGE_R + 7.0, (0.22, 0.2, 0.23))
    z.data["roads"].append({"kind": "street", "w": 0, "pts": [list(c)], "r": FORGE_R - 1.0})
    z.ring_wall("forja", c, FORGE_R, [math.radians(180.0), math.radians(40.0)], gate_half=3.8, height=3.0, material="estaca_horda", stakes=True)
    for k, g in enumerate((180.0, 40.0)):
        for s in (-1, 1):
            p = H(FORGE_R + 0.5, g + s * 21.0, c)
            horde.banner(z, "k1c_forja_horda_%d_%d" % (k, s > 0), p, horde.HORDE_RED, 6.0, -g + 90.0)
            horde.banner(z, "k1c_forja_aurora_%d_%d" % (k, s > 0), p, horde.AURORA_GOLD, 6.0, -g + 90.0, pole=(0.82, 0.68, 0.48))
            z.ob("pillar", p[0], p[1], (0.6, 6.0, 0.6), visible=False)
    stone = mat("forja_pedra", (0.26, 0.24, 0.27))
    iron = mat("braseiro", (0.22, 0.2, 0.2))
    f = (c[0] + 3.0, c[1] - 8.6)                            # fornalha no fundo norte
    box(z.coll, z.P + "forja_fornalha", f, (7.6, 3.4, 4.4), 0.0, stone, 0.0)
    box(z.coll, z.P + "forja_fornalha_topo", f, (5.6, 1.2, 3.4), 0.0, mat("forja_pedra_d", CITADEL_DARK), 3.4)
    box(z.coll, z.P + "forja_boca", (f[0], f[1] + 2.25), (3.0, 1.6, 0.3), 0.0, z.M["glow_lava"], 0.3)
    for k, dx in enumerate((-2.6, 2.6)):
        q = (f[0] + dx, f[1] - 0.6)
        cyl(z.coll, z.P + "forja_chamine_%d" % k, q, 0.95, 0.7, 5.6, stone, 3.4, 8)
        cyl(z.coll, z.P + "forja_chamine_fogo_%d" % k, q, 0.6, 0.1, 1.6, mat("glow_brasa", (1.0, 0.56, 0.2)), 9.0, 6)
    z.ob("wall", f[0], f[1], (7.8, 6.0, 4.6), 0.0, visible=False)
    pool = (c[0] - 7.5, c[1] - 6.5)
    lava_lake(z, "forja", pool, 3.0)
    for k, (dx, dz, rot) in enumerate(((-2.0, -4.0, 20.0), (5.0, 5.5, -30.0), (-5.5, 6.0, 70.0))):
        z.ob("anvil", c[0] + dx, c[1] + dz, (1.0, 0.9, 0.6), rot, color=(0.3, 0.3, 0.33))
    cyl(z.coll, z.P + "forja_tina", (c[0] + 8.0, c[1] - 3.0), 0.9, 1.0, 0.9, iron, 0.0, 8)
    z.ob("pillar", c[0] + 8.0, c[1] - 3.0, (2.0, 1.0, 2.0), visible=False)
    z.npc("forge_dwarf_a", c[0] - 1.0, c[1] - 5.0, 180.0)      # K1c: anões trabalham na forja retomada
    z.npc("forge_dwarf_b", c[0] + 6.0, c[1] + 3.5, 90.0)
    z.block(c, FORGE_R + 6.0)


def citadel_gate(z, portal):
    """Portão da Cidadela: barbacã na garganta (duas torres, muralha que se fecha na encosta), portão de ferro fechado
    até K2 (só visual: quem tranca é o PORTAL_GATES) e arrombado depois; atrás, os ombros da montanha com a cidadela."""
    c = BARBICAN
    z.patch("portao", (c[0], c[1] + 9.0), 16.0, (0.4, 0.22, 0.24))
    stone = mat("cidadela_pedra", (0.24, 0.22, 0.26))
    dark = mat("cidadela_pedra_d", CITADEL_DARK)
    for s in (-1, 1):
        t = (c[0] + s * 8.6, c[1])
        keep_tower(z, "portao_torre_%d" % (s > 0), t, 0.0, 3.3, 13.0, roof=horde.HORDE_RED)
        z.ob("pillar", t[0], t[1], (6.8, 14.0, 6.8), visible=False)
        pts = [(t[0] + s * 2.8, t[1] - 1.0), (c[0] + s * 18.0, c[1] - 6.0), (c[0] + s * 25.0, c[1] - 16.0)]
        for k in range(2):
            a, b = Vector(pts[k]), Vector(pts[k + 1])
            m = (a + b) * 0.5
            L = (b - a).length + 1.2
            rot = along((b - a).x, (b - a).y)
            box(z.coll, z.P + "portao_muro_%d_%d" % (s > 0, k), (m.x, m.y), (L, 7.0, 2.2), rot, stone, 0.0)
            box(z.coll, z.P + "portao_muro_topo_%d_%d" % (s > 0, k), (m.x, m.y), (L, 0.9, 2.8), rot, dark, 7.0)
            z.ob("wall", m.x, m.y, (L, 7.0, 2.6), rot, visible=False)
        p = (c[0] + s * 6.0, c[1] + 6.5)
        horde.banner(z, "k2_portao_horda_%d" % (s > 0), p, horde.HORDE_RED, 7.5, 0.0)
        horde.banner(z, "k2_portao_aurora_%d" % (s > 0), p, horde.AURORA_GOLD, 7.5, 0.0, pole=(0.82, 0.68, 0.48))
        z.ob("pillar", p[0], p[1], (0.6, 7.5, 0.6), visible=False)
    box(z.coll, z.P + "portao_verga", c, (11.0, 2.6, 2.6), 0.0, dark, 9.0)
    iron = mat("portao_ferro", (0.2, 0.19, 0.22))
    box(z.coll, z.P + "k2_portao_fechado_folha", c, (10.6, 9.0, 0.8), 0.0, iron, 0.0)
    box(z.coll, z.P + "k2_portao_fechado_selo", (c[0], c[1] + 0.5), (3.0, 3.0, 0.2), 0.0, mat("pano_72_13", horde.HORDE_RED), 4.0)
    for s in (-1, 1):                                       # arrombado: as duas folhas abertas para dentro
        box(z.coll, z.P + "k2_portao_aberto_folha_%d" % (s > 0), (c[0] + s * 5.4, c[1] - 2.6), (0.8, 9.0, 5.2), s * 14.0, iron, 0.0)
    # cidadela nos ombros da garganta e o pico atrás (só visual, fora do andável)
    for s in (-1, 1):
        sc = (s * 30.0, portal[1] - 22.0)
        crag(z, "ombro_%d" % (s > 0), sc, 22.0, 30.0, seed=7 + s, lava=0.08, flat=0.3)
        top = keep_tower(z, "cidadela_torre_%d" % (s > 0), sc, 30.0, 4.6, 17.0, roof=horde.HORDE_RED)
        for k, (dx, dz) in enumerate(((-5.5, 4.0), (5.5, 4.0))):
            keep_tower(z, "cidadela_torreta_%d_%d" % (s > 0, k), (sc[0] + dx, sc[1] + dz), 25.0, 2.2, 11.0, roof=(0.4, 0.14, 0.14), glow=False, segs=6)
    crag(z, "kharzun", (0.0, portal[1] - 58.0), 52.0, 82.0, seed=3, rings=9, segs=18, lava=0.16, flat=0.16)
    box(z.coll, z.P + "cidadela_muralha", (0.0, portal[1] - 22.0), (46.0, 5.0, 3.0), 0.0, stone, 24.0)
    z.block((c[0], c[1] + 6.0), 14.0)


def kharzun_fang(z):
    """Marco: a Presa de Kharzun, torre de vigia da cidadela num esporão de basalto entre o Portão e a Forja. Fuste negro
    com quatro presas de osso, fendas de lava e um farol de brasa no topo (~38 m)."""
    top = z.hill("presa", FANG, 11.5, 3, rock="cliff_rock", top="cliff_grass", step=2.6)
    y = keep_tower(z, "presa_torre", FANG, top, 5.2, 25.0, roof=None, horns=True)
    cyl(z.coll, z.P + "presa_farol", FANG, 3.4, 0.2, 7.0, mat("glow_brasa", (1.0, 0.56, 0.2)), y + 0.4, 7)
    for k in range(3):                                      # panos vermelhos compridos (leem-se de cima como três riscos)
        a = math.tau * k / 3 + 0.4
        q = (FANG[0] + math.cos(a) * 5.3, FANG[1] + math.sin(a) * 5.3)
        box(z.coll, z.P + "presa_pano_%d" % k, q, (3.0, 11.0, 0.14), math.degrees(-a) + 90.0, mat("pano_72_13", horde.HORDE_RED), top + 9.0)
    return y + 6.4


def east_gorge(z):
    """Garganta de Lumeria (Ato III), aberta depois da zona aprovada: roda no FIM do build, quando a dispersão e o
    acabamento já sortearam tudo, para o resto do mapa sair byte a byte igual. Faz a estrada (ramal da Forja-Canil), o
    largo de chegada e dois postes com as lanternas que nunca apagam ("a noite que anda"); tira do corredor o que a
    dispersão pôs lá (obstáculos do JSON e peças 3D dos lotes do acabamento) e grava o portal em future_portals."""
    out, inn = polar(z, LUMERIA_DEG, 7), polar(z, LUMERIA_DEG, 16)
    poly = z.road("lumeria", LUMERIA_ROAD + [inn, out], end_clearing=False)
    z.arrival(inn, out, r=5.0, name="chegada_lumeria")
    core = poly[3:]                                           # os 2 primeiros pontos ficam em cima da estrada da Forja

    def near(p, r):
        v = Vector(p)
        return poly_dist(v, core) < zone_lib.ROAD_W * 0.5 + 1.4 + r or (v - Vector(inn)).length < 6.5 + r

    gone = [o for o in z.data["obstacles"] if o["kind"] in ("tree", "dead_tree", "rock", "bush", "stump", "crystal", "pillar")
            and o.get("y", 0.0) < 0.5 and near(o["pos"], max(o["size"][0], o["size"][2]) * 0.5)]
    for o in gone:
        z.data["obstacles"].remove(o)
    print("GARGANTA lumeria: %d obstaculos tirados do corredor: %s" % (len(gone), [(o["kind"], o["pos"]) for o in gone]))
    cut = 0
    for ob in z.coll.objects:                                 # peças 3D do acabamento (lotes por célula) caídas no corredor
        if "_det_" not in ob.name or "_chao_" in ob.name or ob.type != "MESH":
            continue
        ox, oy = ob.location.x, ob.location.y
        bm = bmesh.new()
        bm.from_mesh(ob.data)
        seen, kill = set(), []
        for f0 in bm.faces:
            if f0.index in seen:
                continue
            isl, st = [], [f0]
            seen.add(f0.index)
            while st:
                f = st.pop()
                isl.append(f)
                for e in f.edges:
                    for g in e.link_faces:
                        if g.index not in seen:
                            seen.add(g.index)
                            st.append(g)
            vs = {v for f in isl for v in f.verts}
            cx, cy = sum(v.co.x for v in vs) / len(vs) + ox, sum(v.co.y for v in vs) / len(vs) + oy
            if max(v.co.z for v in vs) > 0.06 and near((cx, -cy), 0.3):
                kill += isl
        if kill:
            cut += 1
            bmesh.ops.delete(bm, geom=kill, context="FACES")
            bm.to_mesh(ob.data)
        bm.free()
    print("GARGANTA lumeria: %d lotes do acabamento aparados" % cut)
    # as lanternas de Lumeria: dois postes claros na boca da garganta, lanterna rosa acesa e uma fita desbotada
    a = math.radians(LUMERIA_DEG)
    side = (-math.sin(a), math.cos(a))
    post, glow = mat("lumeria_poste", (0.84, 0.78, 0.72)), mat("glow_lanterna_rosa", (1.0, 0.68, 0.78))
    for k, sgn in enumerate((-1, 1)):
        q = (inn[0] + side[0] * sgn * 4.6 + math.cos(a) * 4.0, inn[1] + side[1] * sgn * 4.6 + math.sin(a) * 4.0)
        cyl(z.coll, z.P + "lumeria_poste_%d" % k, q, 0.14, 0.09, 4.6, post, 0.0, 6)
        box(z.coll, z.P + "lumeria_lanterna_%d" % k, q, (0.5, 0.6, 0.5), 45.0, glow, 4.5)
        cone(z.coll, z.P + "lumeria_tampa_%d" % k, q, 0.4, 0.3, post, 5.1, 4)
        horde.cloth(z.coll, z.P + "lumeria_fita_%d" % k, q, 0.7, 2.6, 90.0 - LUMERIA_DEG + 180.0 * k, mat("bandeira_lumeria", (0.9, 0.7, 0.76)), 1.7, tail="swallow")
        z.ob("pillar", q[0], q[1], (0.6, 4.6, 0.6), visible=False)
    z.data["poi"]["garganta_lumeria"] = list(inn)
    print("BACK lumeria (target_pos do portal de Lumeria para Kharzun)", inn)
    if LUMERIA_READY:                                         # o mapa existe (WP5): portal de verdade
        z.portal("to_city_lumeria", out, "city_lumeria", LUMERIA_ARRIVE, "Lumeria, a Festa Eterna (Lv 45-47)")
        return None
    return {"id": "to_city_lumeria", "pos": list(out), "arrive": list(inn), "target_map": "city_lumeria", "target_pos": list(LUMERIA_ARRIVE),
            "label": "Lumeria, a Festa Eterna (Lv 45-47)", "level": 45, "quest": "hx_act2_epilogue"}


# Spawners cujo centro caía dentro de um sólido (sim.is_walkable falso): (monstro, centro do build, centro certo).
# Mudam só no FIM do build (move_spawners), depois do acabamento: ele reserva o chão em volta dos spawners e, com o
# centro trocado antes, sorteava outra zona. Assim o JSON muda só nestas três entradas e o GLB sai byte a byte igual.
SPAWN_MOVES = [
    ("dire_wolf_rider", (64.0, 57.0), (62.0, 56.0)),      # emboscada: o centro é o lampião do acampamento; 2 m para o lado da trilha
    ("goblin_agitator", (-84.0, 2.0), (-81.0, 2.0)),      # Minas: dentro da fogueira (-84, 2.5); 3 m ao lado
    ("basalt_golem", (-86.0, 66.0), (-86.0, 64.0)),       # encostava numa árvore queimada (-85.7, 67.8)
]


def move_spawners(z):
    for mid, old, new in SPAWN_MOVES:
        hit = [s for s in z.data["spawners"] if s["monster_id"] == mid and tuple(s["pos"]) == old]
        if len(hit) != 1:
            print("SPAWN_MOVE_MISS %s em %s: %d spawners" % (mid, old, len(hit)))
            continue
        hit[0]["pos"] = list(new)
        near = [o for o in z.data["obstacles"] if o.get("solid", True) and o.get("y", 0.0) < 0.5
                and math.hypot(o["pos"][0] - new[0], o["pos"][1] - new[1]) < max(o["size"][0], o["size"][2]) * 0.71 + 0.6]
        if near:
            print("SPAWN_MOVE_WARN %s em %s: sólido perto %s" % (mid, new, [(o["kind"], o["pos"]) for o in near]))


# ---------------------------------------------------------------------------------------------------------------
def check_spawners(z):
    """Aviso (não erro) para spawner fora das regras dos testes: 40-120 m do hub, dentro da borda, fora da lava e de morro."""
    hills = [(Vector(o["pos"]), o["size"][0] * 0.5) for o in z.data["obstacles"] if o["kind"] == "hill"]
    for s in z.data["spawners"]:
        p = Vector(s["pos"])
        why = []
        if not 40.0 < p.length < 120.0:
            why.append("a %.0f m do hub" % p.length)
        if p.length > z.rim_r(math.atan2(p.y, p.x)) - 5.0:
            why.append("na borda")
        if any(poly_dist(p, rv) < z.river_ws[k] * 0.5 + 1.5 for k, rv in enumerate(z.rivers)):
            why.append("na lava")
        if any((p - Vector(w["pos"])).length < w["r"] + 1.0 for w in z.data["water"] if w["kind"] == "lake"):
            why.append("no lago de lava")
        if any((p - c).length < r + 1.0 for c, r in hills):
            why.append("num morro")
        if why:
            print("SPAWN_WARN %s em (%.0f, %.0f): %s" % (s["monster_id"], p.x, p.y, ", ".join(why)))


def build(export=False):
    z = Zone(ZONE, seed=31, palette={
        "road": (0.68, 0.63, 0.58), "street": (0.66, 0.6, 0.54), "water": LAVA_COL,
        "cliff_rock": BASALT, "cliff_rock_d": BASALT_D, "cliff_grass": (0.4, 0.36, 0.36), "hill_grass": (0.44, 0.4, 0.39),
        "leaf": (0.3, 0.24, 0.22), "wood": (0.33, 0.31, 0.35),            # "wood" = tabuleiro das pontes: basalto
        "estaca_horda": horde.STAKE_DARK, "estaca_aurora": STAKE_AURORA, "glow_lava": LAVA_COL, "patch_lava_crosta": CRUST,
    })
    z.water_tint("glow_lava")
    portal = polar(z, 90, 7)                 # sul: as Estepes saem pelo norte, a chegada aqui fica no rumo oposto
    arrive = polar(z, 90, 16)
    z.data["spawn"] = list(arrive)
    z.portal("to_field_steppe", portal, "field_steppe", STEPPE_ARRIVE, "Estepes de Cinza (Lv 35-40)")
    print("BACK steppe (target_pos de to_field_kharzun)", arrive)
    cit_out, cit_in = polar(z, -90, 8), polar(z, -90, 16)
    z.portal("to_kharzun_citadel", cit_out, "kharzun_citadel", zone_lib.fort_arrive("kharzun_citadel", CITADEL_ARRIVE), "Cidadela de Kharzun (Lv 44-45)")
    print("BACK citadel (volta da cidadela)", cit_in)
    aurora_camp(z)

    # ---------- estradas (todas curvas; laços entre POIs) ----------
    kc, fc = KENNEL, FORGE
    r_sul = z.road("sul", [(0.0, HUB_R - 1.0), (4.0, 44.0), (-4.0, 64.0), (3.0, 82.0), arrive, portal], end_clearing=False)
    r_norte = z.road("norte", [(0.0, -HUB_R + 1.0), (0.5, -38.0), (2.4, -51.0), (4.0, -63.0), (3.5, -77.0), (2.0, -88.0), (BARBICAN[0], BARBICAN[1] + 6.0),
                               BARBICAN, cit_in, cit_out], end_clearing=False)
    r_oeste = z.road("oeste", [(-HUB_R + 1.0, 0.0), (-40.0, -5.0), (-56.0, -10.0), (-70.0, -7.0), MINES])
    r_leste = z.road("leste", [(HUB_R - 1.0, 0.0), (40.0, 3.0), (56.0, 0.0), (68.0, 8.0), H(KENNEL_R + 2.0, 180.0, kc), kc], end_clearing=False)
    z.road("matadores", [(-40.0, -5.0), (-46.0, -22.0), (-54.0, -40.0), (-60.0, -55.0)], end_clearing=False)
    z.road("encosta", [(-60.0, -55.0), (-55.0, -64.0), (-46.0, -70.0), (-34.5, -77.7), (-23.0, -85.4), (-10.0, -89.0), (2.0, -88.0)], end_clearing=False)
    r_forja = z.road("forja", [(-1.0, -63.0), (14.0, -69.0), (30.0, -75.0), H(FORGE_R + 2.0, 180.0, fc), fc, H(FORGE_R + 2.0, 40.0, fc), (70.5, -56.0),
                               (72.0, -45.6), (73.5, -35.0), (80.0, -20.0), (87.0, -10.0), H(KENNEL_R + 2.0, -90.0, kc), kc], end_clearing=False)
    z.road("sudeste", [kc, H(KENNEL_R + 2.0, 90.0, kc), (84.0, 34.0), (72.0, 42.0), (54.0, 43.0), (36.0, 47.0), (18.0, 42.0), (4.0, 44.0)], end_clearing=False)
    z.road("sudoeste", [MINES, (-76.0, 10.0), (-65.0, 22.0), (-56.0, 32.0), (-42.0, 40.0), (-28.0, 52.0), (-14.0, 60.0), (-4.0, 64.0)], end_clearing=False)
    z.arrival(arrive, portal)
    lava_river(z, LAVA, LAVA_W)
    z.bridges()
    lava_lake(z, "fogo", FIRE_LAKE, FIRE_LAKE_R)
    lava_lake(z, "caldeira", SW_LAKE, SW_LAKE_R)
    crag(z, "nascente", (-60.5, -130.0), 10.0, 16.0, seed=17, lava=0.3, flat=0.2)        # boca da nascente, além da borda
    lava_fall(z, "nascente", [(-60.0, -127.5, 13.0), (-58.6, -123.5, 6.0), (-57.4, -120.0, 2.2), (-56.6, -117.6, 0.05)], LAVA_W * 0.9)

    # ---------- investidas (K0: duas frentes) e a marcha do aríete (K2) ----------
    in_hub = lambda p: math.hypot(p[0], p[1]) > HUB_R + 2.0
    rt_k = [p for p in route_of(r_leste) if in_hub(p) and math.hypot(p[0] - kc[0], p[1] - kc[1]) > KENNEL_R + 2.0]
    rt_c = [p for p in route_of(r_norte) if in_hub(p) and p[1] > BARBICAN[1] + 8.0]
    z.data["raids"] = [
        {"side": "kennel", "from": list(H(KENNEL_R + 4.0, 180.0, kc)), "route": rt_k + [list(H(HUB_R, 0.0))], "target": [0.0, 0.0], "radius": HUB_R - 6.0, "unless": Q_KENNEL},
        {"side": "citadel", "from": [BARBICAN[0], BARBICAN[1] + 9.0], "route": rt_c + [list(H(HUB_R, -90.0))], "target": [0.0, 0.0], "radius": HUB_R - 6.0, "unless": Q_GATE},
    ]
    z.data["assaults"] = [{"id": "ariete", "from": list(H(HUB_R + 3.0, -90.0)), "route": list(reversed(rt_c)), "target": [BARBICAN[0], BARBICAN[1] + 9.0], "radius": 5.0}]

    # ---------- POIs e marco ----------
    mouth = slave_mines(z)
    dire_kennel(z)
    black_forge(z)
    citadel_gate(z, cit_out)
    top = kharzun_fang(z)
    print("presa topo %.1f m" % top)

    # ---------- relevo: mesas e colunas de basalto, fendas ----------
    for i, (deg, inset, r, lv) in enumerate([(157.0, 12.0, 8.0, 3), (33.0, 12.0, 8.0, 3), (108.0, 13.0, 6.5, 2), (78.0, 13.0, 7.0, 2), (-101.0, 11.0, 7.0, 3)]):
        z.hill("mesa_%d" % i, polar(z, deg, inset), r, lv, rock="cliff_rock", top="cliff_grass", step=2.4)
    for i, (c, r, lv) in enumerate([((26.0, 22.0), 5.0, 1), ((-22.0, 28.0), 5.5, 1), ((54.0, 20.0), 5.5, 2), ((-22.0, -30.0), 5.0, 1), ((-64.0, -28.0), 6.0, 2),
                                     ((30.0, -26.0), 5.5, 2), ((-36.0, 76.0), 5.5, 1), ((60.0, 80.0), 6.0, 2)]):
        z.terrace("afloramento_%d" % i, c, r, lv, top="cliff_grass")
    horde.ravine(z, "sul", [polar(z, 62.0, 2), (52.0, 80.0), (44.0, 72.0), (46.0, 62.0)], 4.5)
    horde.ravine(z, "oeste", [polar(z, 196.0, 2), (-100.0, 22.0), (-92.0, 18.0), (-90.0, 26.0)], 4.5)
    for i, (c, r) in enumerate([((-34.0, 20.0), 9.0), ((34.0, -24.0), 9.0), ((22.0, 66.0), 10.0), ((-18.0, 84.0), 11.0), ((76.0, 56.0), 10.0), ((-58.0, -22.0), 8.0),
                                 ((96.0, 36.0), 9.0), ((-90.0, 60.0), 10.0), ((-78.0, -44.0), 9.0), ((18.0, -72.0), 8.0), ((-14.0, -100.0), 9.0), ((84.0, -70.0), 9.0)]):
        z.patch("cinza_%d" % i, c, r, [(0.5, 0.46, 0.45), (0.45, 0.41, 0.4)][i % 2])
    for i, (c, r) in enumerate([((40.0, -62.0), 9.0), ((-20.0, -66.0), 8.0), ((86.0, -56.0), 9.0), ((-48.0, 62.0), 8.0), ((66.0, -34.0), 8.0), ((-58.0, -92.0), 8.0)]):
        z.patch("brasa_%d" % i, c, r, [(0.42, 0.26, 0.23), (0.38, 0.25, 0.24)][i % 2])       # chão avermelhado perto da lava

    sl = places.gate_return(places.DUNGEONS["dg_slayers"])
    z.patch("matadores", sl, 14.0, (0.31, 0.25, 0.37), y=0.0056)      # chão arroxeado diante do Salão
    z.late_gorges.append(math.radians(LUMERIA_DEG))        # garganta de Lumeria: a encosta baixa ali, o sorteio do anel não muda
    z.cliffs(snow=False)
    prnd = random.Random(53)
    for i, deg in enumerate(range(-156, -22, 12)):          # encosta norte: picos com veios de lava além da borda (só visual)
        if abs(deg + 90) < 22:
            continue
        a = math.radians(deg)
        rr = z.rim_r(a) + prnd.uniform(24.0, 32.0)
        crag(z, "encosta_%d" % i, (math.cos(a) * rr, math.sin(a) * rr), prnd.uniform(15.0, 21.0), prnd.uniform(32.0, 50.0), seed=60 + i, lava=0.14, flat=0.1)
    z.trail_color = TRAIL_COL          # trilha dos lugares na cinza do monte (a areia padrão destoa do basalto)
    places.build(z, PLACES)

    # ---------- vegetação: árvores queimadas, pedras de basalto, moitas de cinza, cristais de brasa ----------
    obs = z.data["obstacles"]
    z.scatter("tree", [((0, 0), 108, 30), ((-60, 50), 26, 8), ((50, 70), 26, 8), ((-80, -40), 22, 6)], 0, (1.8, 4.0, 1.8), CHAR, margin=4.8, spacing=7.0, hub_r=HUB_R + 8.0)
    z.rim_belt(56, (1.8, 4.0, 1.8), CHAR)
    z.scatter("rock", [((0, 0), 108, 70), ((0, -84), 40, 16), ((-90, 0), 26, 10), ((90, -20), 26, 10)], 0, (1.5, 1.1, 1.3), [(0.3, 0.28, 0.31), (0.24, 0.23, 0.26), (0.36, 0.33, 0.35)],
              margin=3.6, spacing=3.2, hub_r=HUB_R + 7.0, scale=(0.7, 1.9))
    nrnd = random.Random(131)
    dry = lambda x, zz, m: z.free(x, zz, m, HUB_R + 5.0)
    # nada (nem moita, que não é sólida) nasce dentro da lava: margem medida da beira, não do eixo
    free = lambda x, zz, m: dry(x, zz, m) and all(poly_dist(Vector((x, zz)), rv) > LAVA_W * 0.5 + 1.8 for rv in z.rivers)
    nature.fix_trees(obs, nrnd, dead=True, dead_cols=CHAR)
    nature.scatter(z.ob, free, nrnd, "bush", [((0, 0), 106, 70)], (1.6, 0.85, 1.6), [(0.46, 0.36, 0.32), (0.4, 0.34, 0.32), (0.52, 0.42, 0.36)],
                   solid=False, margin=2.6, spacing=3.4, avoid=obs)
    nature.scatter(z.ob, free, nrnd, "stump", [((0, 0), 104, 24)], (1.1, 0.8, 1.1), CHAR, margin=3.2, spacing=5.0, avoid=obs)
    lava_spots = [((p.x, p.y), 9.0, 2) for p in z.rivers[0][6:-2:6]] + [(FIRE_LAKE, FIRE_LAKE_R + 8.0, 5), (SW_LAKE, SW_LAKE_R + 8.0, 6)]
    nature.scatter(z.ob, free, nrnd, "crystal", lava_spots, (0.9, 1.5, 0.9), [(1.0, 0.55, 0.25), (1.0, 0.7, 0.3)], margin=3.4, spacing=4.0, avoid=obs)
    lakes = [(FIRE_LAKE, FIRE_LAKE_R), (SW_LAKE, SW_LAKE_R)]
    nature.clear_banks(obs, z.rivers, lakes, LAVA_W)

    # ---------- monstros (plano §3; ids em MOBS) ----------
    # Teto de vivos (plano §8: <= 140 no campo). O jogo multiplica count > 1 por Balance.SPAWN_COUNT_MULT (1,6: 2 -> 3, 3 -> 5)
    # e cada líder traz a escolta (2, em geral): um Lança-Pedras = 3 vivos. Conta antes de engordar um spawner.
    M = MOBS
    b_mines, b_kennel, b_forge, b_slay, b_gate = {"unless": Q_MINES}, {"unless": Q_KENNEL}, {"unless": Q_FORGE}, {"unless": Q_SLAYERS}, {"unless": Q_GATE}
    sp = z.spawner
    # 40-41 sopé, sul e Minas
    sp(M["wolf"], -30.0, 86.0, 10, 2, 24.0)
    sp(M["wolf"], 34.0, 84.0, 10, 2, 24.0)
    sp(M["wolf"], 62.0, 28.0, 9, 2, 24.0)
    sp(M["wolf"], -40.0, 58.0, 9, 2, 24.0)
    sp(M["assassin"], 12.0, 66.0, 7, 2, 30.0, when=b_slay)          # emboscadas nas estradas (param em K1d)
    sp(M["assassin"], 46.0, -8.0, 7, 2, 30.0, when=b_slay)
    sp(M["assassin"], -52.0, 2.0, 7, 2, 30.0, when=b_slay)
    sp(M["assassin"], -24.0, -44.0, 8, 2, 26.0)
    sp(M["assassin"], -72.0, 20.0, 8, 2, 26.0)
    sp(M["warrior"], MINES[0] + 1.0, MINES[1] - 1.0, 9, 3, 22.0, when=b_mines)      # capatazes e a guarda das Minas
    sp(M["agitator"], MINES[0] - 4.0, MINES[1] + 6.0, 3, 1, 90.0, when=b_mines)
    sp(M["troll"], -74.0, -24.0, 7, 1, 28.0)
    sp(M["thrower"], -92.0, -30.0, 7, 1, 30.0)
    sp(M["thrower"], -64.0, -17.0, 6, 1, 30.0, when=b_mines)
    # 41-42 Canil e estradas do leste
    sp(M["rider"], kc[0] - 2.0, kc[1], 9, 2, 28.0, when=b_kennel)
    sp(M["wolf"], kc[0] + 2.0, kc[1] + 2.0, 10, 3, 22.0, when=b_kennel)
    sp(M["dire_mother"], kc[0] + 7.0, kc[1] + 3.0, 2, 1, 300.0, when=b_kennel)
    sp(M["rider"], 60.0, -18.0, 8, 1, 30.0)
    sp(M["wolf"], 100.0, 40.0, 9, 2, 24.0)
    sp(M["thrower"], 74.0, 62.0, 7, 1, 30.0)
    sp(M["agitator"], 40.0, 28.0, 3, 1, 90.0)
    # 42-43 Forja Negra, norte da lava, Salão dos Matadores
    sp(M["fire_archer"], fc[0], fc[1] + 2.0, 9, 2, 24.0, when=b_forge)
    sp(M["warlord"], fc[0] + 1.0, fc[1] - 2.0, 3, 1, 120.0, when=b_forge)
    sp(M["fire_archer"], 24.0, -62.0, 8, 1, 24.0)
    sp(M["warlord"], -12.0, -72.0, 5, 1, 120.0)
    sp(M["salamander"], 86.0, -58.0, 8, 2, 24.0)
    sp(M["salamander"], 42.0, -60.0, 7, 2, 24.0)
    sp(M["salamander"], -58.0, -90.0, 7, 2, 24.0)
    sp(M["salamander"], -46.0, 70.0, 7, 2, 24.0)
    sp(M["slayer"], -72.0, -48.0, 7, 2, 60.0)
    sp(M["slayer"], -24.0, -98.0, 6, 1, 60.0)
    sp(M["assassin"], -50.0, -50.0, 7, 1, 26.0)
    # 43-45 encosta, Portão, raros
    sp(M["brute"], -42.0, -104.0, 7, 1, 90.0)
    sp(M["brute"], 17.0, -101.0, 6, 1, 90.0)
    sp(M["clan_guard"], BARBICAN[0], BARBICAN[1] + 10.0, 7, 4, 30.0, when=b_gate)
    sp(M["clan_guard"], 46.0, -90.0, 6, 2, 30.0)
    sp(M["golem"], 77.0, -70.0, 5, 1, 240.0)
    sp(M["golem"], -86.0, 66.0, 5, 1, 240.0)
    check_spawners(z)

    # ---------- dados para a integração (WP5): estágios, quem aparece quando, colheita ----------
    z.data["stage_tags"] = [
        {"tag": "k1_minas_horda", "unless": Q_MINES}, {"tag": "k1_minas_aurora", "if": Q_MINES},
        {"tag": "k1_jaula_fechada", "unless": Q_MINES}, {"tag": "k1_jaula_aberta", "if": Q_MINES},
        {"tag": "k0_obra", "unless": Q_MINES}, {"tag": "k1_torre", "if": Q_MINES}, {"tag": "k1_anoes", "if": Q_MINES}, {"tag": "k1_libertos", "if": Q_MINES},
        {"tag": "k1b_canil_horda", "unless": Q_KENNEL}, {"tag": "k1b_canil_aurora", "if": Q_KENNEL},
        {"tag": "k1c_forja_horda", "unless": Q_FORGE}, {"tag": "k1c_forja_aurora", "if": Q_FORGE},
        {"tag": "k2_portao_horda", "unless": Q_GATE}, {"tag": "k2_portao_aurora", "if": Q_GATE},
        {"tag": "k2_portao_fechado", "unless": Q_GATE}, {"tag": "k2_portao_aberto", "if": Q_GATE},
        {"tag": "k2_madeira", "unless": Q_GATE}, {"tag": "k2_cerco", "if": Q_GATE},
        {"tag": "k4_festa", "if": Q_WARLORD},
    ]
    z.data["stage_npcs"] = {
        "mine_slave_a": {"unless": Q_MINES}, "mine_slave_b": {"unless": Q_MINES}, "mine_slave_c": {"unless": Q_MINES},
        "dwarf_smith": {"if": Q_MINES}, "kharzun_f_spearman_0": {"if": Q_MINES}, "kharzun_f_spearman_1": {"if": Q_MINES},
        "kharzun_f_spearman_2": {"if": Q_MINES}, "kharzun_f_spearman_3": {"if": Q_MINES},
        "kharzun_arms_merchant": {"if": Q_FORGE}, "forge_dwarf_a": {"if": Q_FORGE}, "forge_dwarf_b": {"if": Q_FORGE},
        "kharzun_siege_engineer": {"if": Q_GATE}, "kharzun_orc_surrendered_a": {"if": Q_WARLORD}, "kharzun_orc_surrendered_b": {"if": Q_WARLORD},
    }
    z.data["gather_hint"] = [
        {"item": "minério (Aço Anão / Basalto Rúnico)", "shape": "ore", "pos": [MINES[0] - 6.0, MINES[1] - 2.0], "radius": 12.0, "count": 6},
        {"item": "Basalto Rúnico", "shape": "ore", "pos": [SHRINE[0] + 2.0, SHRINE[1] + 14.0], "radius": 9.0, "count": 4},
        {"item": "Erva de Cinza", "shape": "herb", "pos": [SHAMAN[0] + 4.0, SHAMAN[1] + 16.0], "radius": 12.0, "count": 6},
        {"item": "Ovo do Lobo Atroz", "shape": "shell", "pos": [KENNEL[0] + 4.0, KENNEL[1] + 6.0], "radius": 7.0, "count": 4, "if": Q_KENNEL},
        {"item": "Brasa de Kharzun", "shape": "star", "pos": [FORGE[0] + 16.0, FORGE[1] + 22.0], "radius": 9.0, "count": 4, "if": Q_FORGE},
        {"item": "inscrições (Ecos da Noite)", "shape": "relic", "pos": [MINES[0] - 9.0, MINES[1] + 9.0], "radius": 4.0, "count": 2},
        {"item": "caixas de suprimento", "shape": "crate", "pos": [FREED[0] + 8.0, FREED[1] + 2.0], "radius": 7.0, "count": 4},
    ]
    z.data["poi"] = {"hub": [0.0, 0.0], "minas": list(MINES), "canil": list(KENNEL), "forja": list(FORGE), "portao": [BARBICAN[0], BARBICAN[1] + 8.0],
                     "matadores": list(places.gate_return(places.DUNGEONS["dg_slayers"])), "presa": list(FANG), "lago_de_fogo": list(FIRE_LAKE),
                     "caldeira": list(SW_LAKE), "mina_boca": [round(mouth[0], 1), round(mouth[1], 1)]}
    z.data["monster_ids"] = dict(MOBS)

    act2_dress.kharzun(z, {
        "hub_r": HUB_R, "gates": HUB_GATES, "gate_half": GATE_HALF, "mines": MINES, "mouth": mouth, "kennel": KENNEL, "kennel_r": KENNEL_R,
        "forge": FORGE, "forge_r": FORGE_R, "barbican": BARBICAN, "fang": FANG, "shrine": SHRINE, "shaman": SHAMAN, "freed": FREED,
        "slayers": places.gate_return(places.DUNGEONS["dg_slayers"]), "lakes": lakes, "lava_w": LAVA_W, "siege": H(34.0, -63.0),
        "q": {"mines": Q_MINES, "kennel": Q_KENNEL, "forge": Q_FORGE, "slayers": Q_SLAYERS, "gate": Q_GATE, "warlord": Q_WARLORD},
    })
    # só agora (o acabamento reserva o chão em volta de todo portal, os futuros também)
    future = [dict(p, arrive=list(cit_in) if p["target_map"] == "kharzun_citadel" else list(places.gate_return(places.DUNGEONS["dg_slayers"])))
              for p in z.data["portals"] if p["target_map"] in FUTURE_MAPS]
    z.data["portals"] = [p for p in z.data["portals"] if p["target_map"] not in FUTURE_MAPS]
    gorge = east_gorge(z)
    move_spawners(z)
    if gorge:
        future.append(gorge)
    z.data["future_portals"] = future
    g = places.DUNGEONS["dg_slayers"]["gate"]
    poi = {"minas": MINES, "canil": KENNEL, "forja": FORGE, "matadores": (g[0] + 9.0, g[1] + 9.0), "portao": (BARBICAN[0], BARBICAN[1] + 9.0),
           "presa": (FANG[0] - 6.0, FANG[1] + 10.0), "xama": SHAMAN, "libertos": FREED, "santuario": SHRINE, "lago": (FIRE_LAKE[0] - 12.0, FIRE_LAKE[1] + 6.0),
           "chegada": arrive, "ponte": (1.5, -46.0),
           "lumeria": tuple(z.data["poi"]["garganta_lumeria"])}[os.environ.get("KHARZUN_POI", "forja")]
    return z.finish(export, poi=poi, ground=GROUND)
