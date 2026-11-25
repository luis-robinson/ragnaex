"""Campo dos Juramentos (field_oaths, Lv 24-28): campo opcional a sudeste do Bastião da Aurora, do outro lado da vala da
Escavação da Vera (GDD design/gdd/campo-dos-juramentos.md). O velho campo de batalha onde a Ordem da Aurora se partiu.
Garganta única a noroeste (volta para o Bastião), o Acampamento da Vigília no centro (amigo: tendas brancas da Aurora,
fogueira, cavalete com o sino rachado; sem muro, sem cristal), o Córrego das Cinzas cortando o sul (duas pontes) e cinco
pontos: Cemitério dos Cavaleiros (oeste, fileiras de lápides e o Túmulo de Vorhag), Ruas Afundadas (nordeste, calçamento
e colunas de Vel'Thar), Vala dos Cavadores (sudoeste, lugar `camp` do Culto), Colina do Estandarte (sudeste, arena do
Sir Edran) e o Zigurate do Arquivo (leste, entrada RESERVADA: `places.DUNGEONS["dg_archive"]`). Marco: o Estandarte
Partido (mastro da Aurora quebrado no morro, a noroeste do acampamento).

    blender -b --factory-startup --python tools/blender/zones/run_zone.py -- build_field_oaths <pasta_png> --export
    OATHS_CAM=vigilia|cemiterio|ruas|vala|colina|zigurate|chegada|estandarte  (só a foto de revisão CAM_game; padrão = a Vigília)
"""
import math
import os
import random
import importlib
import nature
import places
import zone_lib
importlib.reload(zone_lib)
from zone_lib import Zone, Vector
from dress import Dress

ZONE = "field_oaths"
SIZE = 220.0
RIM = (99.0, 4.0, 2.5, 1.5)        # raio útil ~91-107 m (como o Brejo)
SEED = 116                         # com esta semente a garganta NO cai em (-58.2, -69.4) / chegada (-53.1, -63.2)
GROUND = (0.52, 0.52, 0.44)        # = MapDef.ground_color e loading_art.ZONES["field_oaths"]["ground"] (capim seco cinza)
GORGE_ANG = -130.0                 # garganta do Bastião (noroeste)
BASTION_ARRIVE = (44.8, 100.7)     # chegada no Bastião (build_field_ruins: polar(66, 15))
HUB = (0.0, 0.0)                   # Acampamento da Vigília
HUB_R = 12.0
EXITS = {"NO": -135.0, "NE": -45.0, "SE": 45.0, "S": 115.0, "O": 172.0}       # saídas das estradas (graus do jogo)
CEM = (-76.0, 6.0)                 # Cemitério dos Cavaleiros
TOMB = (-85.5, -6.0)               # Túmulo de Vorhag (mausoléu, porta para o sul = a alameda)
RUAS = (54.0, -52.0)               # Ruas Afundadas
RUAS_AXIS = 30.0                   # rumo da rua antiga (graus do jogo)
VALA = (-44.0, 62.0)               # Vala dos Cavadores (lugar `camp`)
JUNCTION = (-36.0, 54.0)           # largo da Vala: S, arco oeste e arco sul se encontram
COLINA = (50.0, 64.0)              # Colina do Estandarte (arena do Sir Edran)
COLINA_R = 15.0
LANDMARK = (-34.0, -14.0)          # o Estandarte Partido
GATHER = [(54.0, -60.0), (70.0, -14.0), (-60.0, 24.0)]      # MapsCatalog.GATHER["field_oaths"] (GDD 3.7)
RIVER = [(104, 36), (72, 36), (46, 42), (14, 54), (-10, 70), (-30, 104)]   # Córrego das Cinzas (pedido: (70, 42)/(44, 48);
RIVER_W = 4.5                                                               # 6 m ao norte deixava a água a 15 m da arena)
DEAD_TREES = [(0.42, 0.38, 0.32), (0.5, 0.45, 0.36)]          # = build_field_ruins.DEAD_TREES
DEAD_COLS = [(0.42, 0.36, 0.3), (0.5, 0.44, 0.36), (0.36, 0.33, 0.3)]
STONE = (0.74, 0.73, 0.68)         # lápides
GOLD = (0.86, 0.7, 0.32)           # pano da Aurora (dourado gasto)
GOLD_D = (0.5, 0.4, 0.22)
BLUE = (0.3, 0.4, 0.66)            # azul da Aurora (desbotado)
# pano CAÍDO no chão: fosco e puxado para o cinza (amarelo/azul cheio no chão lê como aviso de golpe, FxManager.DANGER*)
DROP_GOLD, DROP_GOLD_D = (0.64, 0.56, 0.4), (0.46, 0.4, 0.3)
DROP_BLUE, DROP_BLUE_D = (0.4, 0.44, 0.52), (0.3, 0.33, 0.4)
PLACES = [
    {"type": "cabin", "id": "sineiro", "pos": (-62.0, -38.0), "face": -20.0, "npc": "oaths_bellringer",
     "roof": (0.34, 0.34, 0.38), "wall": (0.62, 0.6, 0.56), "ground": (0.5, 0.48, 0.42)},
    {"type": "cabin", "id": "corveira", "pos": (20.0, -80.0), "face": 70.0, "npc": "oaths_crowkeeper",
     "roof": (0.24, 0.24, 0.28), "wall": (0.5, 0.44, 0.38), "ground": (0.48, 0.46, 0.4)},
    {"type": "shrine", "id": "pedra_nomes", "pos": (-16.0, -60.0), "npc": "oaths_stone", "ground": (0.58, 0.58, 0.54)},
    {"type": "camp", "id": "vala", "pos": VALA, "face": -45.0, "mob": "night_digger", "count": 3, "ground": (0.36, 0.3, 0.24),
     "cloth": (0.2, 0.18, 0.22)},
    {"type": "dungeon", "id": "arquivo", "dungeon": "dg_archive"},
]
# (monstro, x, z, raio, quantos, respawn) — GDD 9 "Spawners" (sem `when`: o Campo fica povoado depois da conquista)
SPAWNERS = [
    ("oath_sworn", -73.0, 6.0, 7, 4, 20.0), ("oath_sworn", -48.0, 16.0, 6, 4, 20.0),
    ("oath_archer", -76.0, 27.0, 5, 3, 22.0), ("oath_archer", 68.0, 52.0, 4, 2, 22.0),
    ("vel_shade", 55.0, -53.0, 8, 3, 22.0), ("vel_shade", 65.0, 3.0, 5, 3, 22.0),
    ("carrion_crow", 42.0, -64.0, 7, 4, 16.0), ("carrion_crow", -54.0, -16.0, 6, 3, 16.0),
    ("grave_hauler", -27.0, 64.0, 5, 2, 26.0), ("grave_hauler", -82.0, 2.5, 3, 2, 30.0),
]
PATROL = [(-33.0, 58.0), (-24.0, 72.0), (-8.0, 83.0), (-24.0, 72.0)]       # ronda de Cavadores no arco sul


def polar(z, ang_deg, inset):
    a = math.radians(ang_deg)
    r = z.rim_r(a) - inset
    return (round(math.cos(a) * r, 1), round(math.sin(a) * r, 1))


def face_to(x, z, tx, tz):
    return round(math.degrees(math.atan2(tx - x, tz - z)), 1)


def door_rot(c, t):
    """Giro de uma peça em `t` com a frente (eixo +yb do Dress) virada para `c`."""
    return math.degrees(math.atan2(-(c[0] - t[0]), -(c[1] - t[1])))


def local(c, rot):
    """Função (lx, ly) -> ponto do jogo no referencial de uma peça do Dress em `c` com giro `rot` (ly = frente)."""
    a = math.radians(rot)
    ca, sa = math.cos(a), math.sin(a)
    return lambda lx, ly: (c[0] + lx * ca - ly * sa, c[1] - lx * sa - ly * ca)


def wall_box(z, c, sx, sz, h, rot=0.0):
    """Colisor oculto em caixa (o `pillar` do Dress.solid vira círculo)."""
    z.ob("wall", c[0], c[1], (sx, h, sz), rot, visible=False)


# ---------------------------------------------------------------------------------------------------------------
# peças do Campo (todas em lote, pelo Dress)
# ---------------------------------------------------------------------------------------------------------------
def headstone(d, c, rot, h, rnd, stone, dark):
    """Lápide de cavaleiro: laje com topo em arco, inclinada às vezes; terra da cova à frente."""
    t = (rnd.uniform(-9, 9), rnd.uniform(-5, 5)) if rnd.random() < 0.4 else (0, 0)
    d.box("lapide", stone, c, (1.15, h, 0.32), rot, 0.0, t)
    d.cyl("lapide", stone, c, 0.58, 0.58, 0.32, h - 0.3, 8, rot, tilt=(90 + t[0], t[1]))
    P = local(c, rot)
    d.box("cova", dark, P(0.0, 1.3), (1.0, 0.04, 1.9), rot, 0.0)


def helm_stake(d, c, rnd, steel, wood):
    """Elmo da Aurora espetado numa estaca (o cavaleiro sem cova)."""
    lean = (rnd.uniform(-8, 8), rnd.uniform(-8, 8))
    d.cyl("elmo", wood, c, 0.07, 0.05, 1.5, 0.0, 5, 0.0, tilt=lean)
    top = (c[0] + math.sin(math.radians(lean[1])) * 1.45, c[1])
    d.cyl("elmo", steel, top, 0.26, 0.24, 0.32, 1.25, 7)
    d.cyl("elmo", steel, top, 0.24, 0.05, 0.16, 1.57, 7)
    d.box("elmo", d.m("elmo_fenda", (0.12, 0.12, 0.14)), (top[0], top[1] + 0.25), (0.3, 0.05, 0.04), 0.0, 1.38)


def mausoleum(z, d, c, rot):
    """Túmulo de Vorhag: casa de pedra pequena, telhado em cunha, colunas na porta, porta ARROMBADA (laje caída na frente)."""
    body = d.m("mausoleu", (0.6, 0.6, 0.6))
    trim = d.m("mausoleu_friso", (0.74, 0.73, 0.7))
    roof = d.m("mausoleu_teto", (0.3, 0.3, 0.34))
    P = local(c, rot)
    d.box("mausoleu", trim, c, (5.6, 0.4, 5.0), rot, 0.0)
    d.box("mausoleu", body, c, (5.0, 3.0, 4.4), rot, 0.4)
    d.box("mausoleu", trim, c, (5.4, 0.3, 4.8), rot, 3.4)
    d.cyl("mausoleu", roof, c, 3.9, 0.3, 1.8, 3.7, 4, rot + 45.0)
    d.box("mausoleu", d.m("tenda_boca", (0.12, 0.1, 0.1)), P(0.0, 2.22), (1.5, 2.3, 0.08), rot, 0.4)
    for sx in (-1, 1):
        d.cyl("mausoleu", trim, P(sx * 1.2, 2.5), 0.24, 0.22, 3.0, 0.4, 7)
    d.box("mausoleu", body, P(0.4, 3.6), (1.5, 0.16, 2.3), rot + 14.0, 0.05, tilt=(4, 6))       # a porta, no chão
    d.box("mausoleu", trim, P(0.0, 2.4), (3.0, 0.28, 0.5), rot, 3.0)
    for k in range(3):                                                                          # sol da Aurora apagado no frontão
        d.box("mausoleu", d.m("mausoleu_sol", (0.66, 0.58, 0.4)), P(-0.5 + k * 0.5, 2.43), (0.3, 0.3, 0.04), rot + 45.0, 3.55)
    wall_box(z, c, 5.6, 5.0, 3.8, rot)
    d.reserve(c[0], c[1], 3.4)


def bell_gantry(z, d, c, rot):
    """Cavalete do sino rachado (marco do hub, 4 m): dois pés em A, travessa, sino de bronze com a rachadura escura."""
    wood = d.m("cavalete_sino", (0.4, 0.3, 0.2))
    bronze = d.m("sino_bronze", (0.62, 0.5, 0.3))
    P = local(c, rot)
    for sx in (-1, 1):
        for sy in (-1, 1):
            d.cyl("sino", wood, P(sx * 1.5, sy * 0.45), 0.12, 0.1, 3.9, 0.0, 5, rot, tilt=(-sy * 7.0, 0))
    p0, p1 = P(-1.8, 0.0), P(1.8, 0.0)
    d.tube("sino", wood, [(p0[0], 3.75, p0[1]), (p1[0], 3.8, p1[1])], 0.13, 0.12, 6)            # travessa
    d.cyl("sino", bronze, c, 0.34, 0.34, 0.12, 3.05, 8)                    # coroa
    d.cyl("sino", bronze, c, 0.82, 0.42, 1.1, 2.0, 9)                      # corpo (boca para baixo)
    d.cyl("sino", d.m("sino_boca", (0.2, 0.16, 0.12)), c, 0.8, 0.8, 0.04, 1.98, 9)
    d.box("sino", d.m("sino_racha", (0.14, 0.11, 0.08)), P(0.0, 0.66), (0.08, 0.9, 0.06), rot, 2.1, tilt=(0, 12))
    r0, r1 = P(0.3, 0.0), P(0.75, 0.35)
    d.tube("sino", d.m("corda", (0.66, 0.58, 0.44)), [(r0[0], 2.1, r0[1]), (r1[0], 1.0, r1[1])], 0.03, 0.03, 4)   # corda
    d.solid(c[0], c[1], 3.4, 1.4, 3.8, rot)
    wall_box(z, c, 3.4, 1.2, 3.8, rot)


def broken_column(d, c, rnd, stone, stone_d, h=None):
    h = h if h is not None else rnd.uniform(1.4, 3.6)
    d.cyl("coluna", stone_d, c, 0.72, 0.72, 0.35, 0.0, 8)
    d.cyl("coluna", stone, c, 0.48, 0.45, h, 0.35, 8, rnd.uniform(0, 45))
    d.cyl("coluna", stone, c, 0.47, 0.3, 0.3, 0.35 + h, 5, rnd.uniform(0, 45), tilt=(rnd.uniform(-20, 20), rnd.uniform(-20, 20)))


def fallen_arch(z, d, c, rot, stone, stone_d):
    """Arco caído das Ruas: dois pés de pedra, a verga partida no chão entre eles."""
    P = local(c, rot)
    for sx in (-1, 1):
        d.box("arco", stone, P(sx * 2.2, 0.0), (0.9, 2.6 if sx < 0 else 1.6, 0.9), rot, 0.0)
        d.box("arco", stone_d, P(sx * 2.2, 0.0), (1.1, 0.3, 1.1), rot, 2.6 if sx < 0 else 1.6)
    d.box("arco", stone, P(0.6, 1.1), (3.2, 0.7, 0.8), rot + 18.0, 0.0, tilt=(0, 8))
    d.box("arco", stone_d, P(-1.3, -1.0), (1.4, 0.5, 0.7), rot - 30.0, 0.0)
    wall_box(z, c, 5.4, 1.2, 2.0, rot)


def fallen_banner(d, c, rot, rnd, pole, cloth, hem):
    """Estandarte caído (sem colisão): mastro deitado e o pano largado no chão, dobrado."""
    a = math.radians(rot)
    L = rnd.uniform(3.6, 4.6)
    p0 = (c[0] - math.cos(a) * L * 0.5, c[1] - math.sin(a) * L * 0.5)
    p1 = (c[0] + math.cos(a) * L * 0.5, c[1] + math.sin(a) * L * 0.5)
    d.tube("estandarte", pole, [(p0[0], 0.08, p0[1]), (p1[0], 0.12, p1[1])], 0.07, 0.06, 5)
    q = (p1[0] - math.cos(a) * 0.9 + math.sin(a) * 0.8, p1[1] - math.sin(a) * 0.9 - math.cos(a) * 0.8)
    d.blob("estandarte_pano", cloth, q, rnd.uniform(0.9, 1.2), 0.03, 0.25, sx=1.5, rot=-rot)
    d.blob("estandarte_pano", hem, (q[0] + 0.3, q[1] + 0.2), 0.6, 0.034, 0.3, sx=1.4, rot=-rot + 20)


def grave_pit(d, c, rot, rnd):
    """Cova aberta do Culto: buraco escuro, monte de terra ao lado e uma pá espetada."""
    dirt = d.m("vala_terra", (0.4, 0.32, 0.24))
    P = local(c, rot)
    d.box("cova_aberta", d.m("vala_buraco", (0.1, 0.08, 0.07)), c, (1.2, 0.03, 2.2), rot, 0.0)
    d.box("cova_aberta", dirt, c, (1.5, 0.12, 2.5), rot, -0.08)
    d.rock("cova_aberta", dirt, P(1.6, 0.2), 0.75, 0.0, 0.55, sx=1.6, rot=rot + 90.0)
    w = d.m("pa_cabo", (0.44, 0.32, 0.2))
    s = d.m("pa_ferro", (0.42, 0.42, 0.44))
    q = P(1.3, -1.2)
    lean = (rnd.uniform(-14, 14), rnd.uniform(-14, 14))
    d.cyl("cova_aberta", w, q, 0.04, 0.04, 1.5, 0.0, 4, rot, tilt=lean)
    d.box("cova_aberta", s, q, (0.3, 0.45, 0.06), rot, -0.2, tilt=lean)


def broken_standard(z, d, c, rnd):
    """O Estandarte Partido (marco): morro sólido, mastro da Aurora de 18 m quebrado no alto, a metade de cima despencada
    morro abaixo, travessa e pano dourado rasgado (dobrado, nunca placa) pendurado no toco. Peça alta: d.tall()."""
    top = z.hill("estandarte", c, 6.0, 2, rock="cliff_rock", top="hill_grass")
    pole = d.m("mastro_aurora", (0.5, 0.42, 0.32))
    ferro = d.m("mastro_ferro", (0.36, 0.36, 0.4))
    lean = Vector((-0.55, 0.83)).normalized()           # inclina para o sudoeste (a câmera do jogo vê de lado)
    H, tilt = 14.0, math.radians(8.0)
    b = Vector(c)
    brk = b + lean * H * math.sin(tilt)
    brk_y = top + H * math.cos(tilt)
    d.tall(c)
    d.tube("marco", pole, [(b.x, top - 0.2, b.y), (brk.x, brk_y, brk.y)], 0.36, 0.26, 7)
    d.tube("marco", ferro, [(b.x, top - 0.1, b.y), (b.x + lean.x * 0.1, top + 1.0, b.y + lean.y * 0.1)], 0.46, 0.44, 7)
    side = Vector((-lean.y, lean.x))
    bar_y = brk_y - 1.6
    bar_c = b + lean * (H - 1.6) * math.sin(tilt)
    p0, p1 = bar_c - side * 1.7, bar_c + side * 1.7
    d.tube("marco", pole, [(p0.x, bar_y, p0.y), (p1.x, bar_y + 0.15, p1.y)], 0.12, 0.1, 5)
    for k, (w, drop, x0) in enumerate(((3.0, 5.2, -1.5),)):
        rot = math.degrees(math.atan2(-side.y, side.x))
        d.cloth("marco_pano", d.m("pano_aurora", GOLD), (bar_c.x, bar_c.y), w, drop, rot, bar_y - drop, x0, "teeth", d.m("pano_aurora_barra", GOLD_D))
    sol = d.m("pano_sol", (0.94, 0.86, 0.6))
    d.cyl("marco_pano", sol, (bar_c.x, bar_c.y), 0.5, 0.5, 0.03, bar_y - 2.2, 8, 0.0, tilt=(90, math.degrees(math.atan2(side.x, side.y))))
    # a metade de cima, despencada do toco até o pé do morro
    end = b - side * 7.5 + lean * 4.0
    d.tube("marco", pole, [(brk.x, brk_y - 0.2, brk.y), (end.x, 0.35, end.y)], 0.24, 0.2, 6)
    d.cyl("marco", d.m("mastro_ponta", (0.82, 0.68, 0.36)), (end.x, end.y), 0.28, 0.0, 0.7, 0.1, 5, 0.0, tilt=(70, 0))
    d.tall()
    d.solid(end.x, end.y, 1.0, 1.0, 1.0)
    for k in range(5):                                   # lascas do mastro e pano rasgado ao pé do morro
        a = rnd.uniform(0, math.tau)
        q = (c[0] + math.cos(a) * 7.4, c[1] + math.sin(a) * 7.4)
        if d.ok(q[0], q[1], 0.4, road=0.6):
            d.blob("marco_pano", d.m("pano_caido_1", DROP_GOLD) if k % 2 else d.m("pano_caido_barra_1", DROP_GOLD_D), q, 0.5, 0.03, 0.3, sx=1.7, rot=rnd.uniform(0, 180))


def perch(d, c, rot, rnd):
    """Poleiro da Corveira: poste com duas travessas e penas pretas penduradas em fios."""
    w = d.m("poleiro", (0.38, 0.3, 0.22))
    pena = d.m("pena_corvo", (0.12, 0.12, 0.16))
    d.cyl("poleiro", w, c, 0.1, 0.08, 3.0, 0.0, 5)
    P = local(c, rot)
    for k, hh in enumerate((2.0, 2.8)):
        p0, p1 = P(-1.0 + 0.2 * k, 0.0), P(1.0 - 0.2 * k, 0.0)
        d.tube("poleiro", w, [(p0[0], hh, p0[1]), (p1[0], hh + 0.05, p1[1])], 0.05, 0.05, 4)
        for j in range(3):
            q = P(-0.7 + 0.7 * j + 0.1 * k, 0.0)
            d.tube("poleiro", d.m("fio", (0.6, 0.56, 0.48)), [(q[0], hh, q[1]), (q[0], hh - 0.5, q[1])], 0.012, 0.012, 3)
            d.box("poleiro", pena, q, (0.12, 0.34, 0.04), rot + rnd.uniform(-30, 30), hh - 0.85)


def audit(z, arena):
    """Confere as regras do pedido que o build não garante sozinho; cada problema sai numa linha OATHS_AUDIT."""
    obs = z.data["obstacles"]
    solids = [(Vector(o["pos"]), max(o["size"][0], o["size"][2]) * 0.5, o) for o in obs
              if o.get("solid", True) and o["kind"] not in ("cliff", "water") and not o.get("y")]
    bad = 0

    def near(p, skip=None):
        return min((((p - q).length - r, o) for q, r, o in solids if o is not skip and (o["kind"] != "lamp" or (p - q).length > 0.1)), key=lambda v: v[0])

    for name, poly in z.road_polys.items():
        w = (places.TRAIL_W if name.startswith("trilha_") else next((r["w"] for r in z.data["roads"] if r.get("kind") == "road"), 4.0)) * 0.5
        for q, r, o in solids:
            if o["kind"] in ("hill", "wall") and name.startswith("trilha_"):
                continue                 # a trilha de um lugar acaba na boca/porta dele
            dd = zone_lib.poly_dist(q, poly) - r
            if dd < min(w, 1.5) + 0.2:
                print("OATHS_AUDIT sólido %s %s a %.1f m do eixo da estrada %s" % (o["kind"], o["pos"], dd, name))
                bad += 1
    for s in z.data["spawners"]:
        dd, o = near(Vector(s["pos"]))
        if dd < 3.0:
            print("OATHS_AUDIT spawner %s %s a %.1f m de %s %s" % (s["monster_id"], s["pos"], dd, o["kind"], o["pos"]))
            bad += 1
        if any(zone_lib.poly_dist(Vector(s["pos"]), rv) < RIVER_W * 0.5 + 1.0 for rv in z.rivers):
            print("OATHS_AUDIT spawner %s %s dentro de rio" % (s["monster_id"], s["pos"]))
            bad += 1
        for p in z.data["portals"]:
            if (Vector(s["pos"]) - Vector(p["pos"])).length < 8.0:
                print("OATHS_AUDIT spawner %s a < 8 m do portal" % s["monster_id"])
                bad += 1
        if math.hypot(*s["pos"]) < 40.0 and s["monster_id"] != "fallen_bearer":
            print("OATHS_AUDIT spawner %s %s a < 40 m do centro" % (s["monster_id"], s["pos"]))
            bad += 1
    ids = list(z.data["npcs"].items())
    for i, (nid, v) in enumerate(ids):
        dd, o = near(Vector(v[:2]))
        if dd < 1.0:
            print("OATHS_AUDIT NPC %s a %.1f m de %s %s" % (nid, dd, o["kind"], o["pos"]))
            bad += 1
        for nid2, v2 in ids[i + 1:]:
            if (Vector(v[:2]) - Vector(v2[:2])).length < 2.5:
                print("OATHS_AUDIT NPCs %s e %s colados" % (nid, nid2))
                bad += 1
    for h in z.data["hangouts"]:
        dd, o = near(Vector(h))
        if dd < 0.8:
            print("OATHS_AUDIT ponto de bot %s a %.1f m de %s" % (h, dd, o["kind"]))
            bad += 1
    for g in GATHER:
        dd, o = near(Vector(g))
        if dd < 1.0:
            print("OATHS_AUDIT colheita %s com sólido a %.1f m" % (g, dd))
            bad += 1
        rd = min(zone_lib.poly_dist(Vector(g), p) for k, p in z.road_polys.items() if not k.startswith("trilha_"))
        wd = min(zone_lib.poly_dist(Vector(g), rv) for rv in z.rivers)
        n = sum(1 for q, r, o in solids if (q - Vector(g)).length - r < 9.0)
        print("field_oaths: colheita %s: estrada a %.1f m, água a %.1f m, %d sólidos a < 9 m" % (g, rd, wd, n))
        if rd < 7.5 or wd < 8.0:
            print("OATHS_AUDIT colheita %s perto de estrada/água" % (g,))
            bad += 1
    for q, r, o in solids:
        if (q - Vector(arena[0])).length - r < arena[1]:
            print("OATHS_AUDIT sólido %s %s dentro da arena" % (o["kind"], o["pos"]))
            bad += 1
    lm = Vector(LANDMARK)
    for name, poly in z.road_polys.items():
        if not name.startswith("trilha_") and zone_lib.poly_dist(lm, poly) < 14.0:
            print("OATHS_AUDIT marco a < 14 m da estrada %s" % name)
            bad += 1
    print("field_oaths: auditoria %s (%d problemas; %d sólidos, %d obstáculos)" % ("ok" if bad == 0 else "COM PROBLEMAS", bad, len(solids), len(obs)))


def build(export=False):
    pal = {"leaf": (0.4, 0.44, 0.34), "cliff_grass": (0.48, 0.5, 0.4), "hill_grass": (0.5, 0.52, 0.42),
           "cliff_rock": (0.52, 0.5, 0.48), "cliff_rock_d": (0.42, 0.4, 0.38), "road": (0.62, 0.56, 0.45),
           "water_dark": (0.24, 0.27, 0.3), "wood": (0.44, 0.34, 0.24), "stone_ruin": (0.7, 0.68, 0.62)}
    z = Zone(ZONE, size=SIZE, rim=RIM, seed=SEED, palette=pal)
    z.trail_color = (0.56, 0.5, 0.4)
    H = lambda r, a: (HUB[0] + math.cos(math.radians(a)) * r, HUB[1] + math.sin(math.radians(a)) * r)
    A = lambda r, a: (COLINA[0] + math.cos(math.radians(a)) * r, COLINA[1] + math.sin(math.radians(a)) * r)
    portal = polar(z, GORGE_ANG, 7)
    arrive = polar(z, GORGE_ANG, 15)
    z.data["spawn"] = list(arrive)
    z.data["arrive_from_field_ruins"] = list(arrive)
    z.data["town"] = {"center": [HUB[0], HUB[1]], "radius": 0.0, "gates": []}
    cams = {"cemiterio": CEM, "ruas": RUAS, "vala": VALA, "colina": COLINA, "zigurate": (74.0, 6.0), "chegada": arrive,
            "estandarte": (LANDMARK[0], LANDMARK[1] + 8.0)}
    z.cam_game = cams.get(os.environ.get("OATHS_CAM", ""), HUB)          # só a foto de revisão
    z.portal("to_field_ruins", portal, "field_ruins", BASTION_ARRIVE, "Bastião da Aurora")
    z.block(arrive, 6)

    # ---------- chão por região (lido de cima). Pilha (mm): manchas do campo 0,8/1,6/2,4 < cinza queimado 3,4
    #            < manchas Zone.patch 5,2/6,0 (= chão dos lugares) < anéis da arena 7,4/7,8 < acostamento 9,8
    #            < trilha de lugar 10,8 < estrada 12 ----------
    z.patch("clareira", HUB, 20.0, (0.56, 0.55, 0.46), grass=True)
    z.patch("vigilia", HUB, HUB_R + 0.5, (0.6, 0.54, 0.42), y=0.0068)
    z.patch("cemiterio", CEM, 20.0, (0.46, 0.5, 0.42), grass=True)
    z.patch("ruas", RUAS, 20.0, (0.7, 0.66, 0.56))
    z.patch("vala", VALA, 15.0, (0.36, 0.3, 0.24), y=0.0052)          # por baixo do chão do acampamento (lugar `camp`, 6,0 mm)
    z.patch("colina", COLINA, COLINA_R + 1.0, (0.58, 0.52, 0.42))

    # ---------- água: Córrego das Cinzas (nasce atrás do zigurate, some na borda sudoeste) ----------
    z.river(RIVER, w=RIVER_W, material="water_dark")

    # ---------- estradas (curvas; dois anéis, um ramo até a porta selada do Arquivo) ----------
    e = lambda k: H(HUB_R - 1.0, EXITS[k])
    J = JUNCTION
    z.road("NO", [portal, arrive, (-40, -46), (-24, -26), e("NO")], w=4.0, end_clearing=False)
    z.road("O", [e("O"), (-32, 7), (-50, 4), (-63, 6)], w=4.0, end_clearing=False)
    z.road("NE", [e("NE"), (22, -24), (38, -40), (48, -47)], w=4.0, end_clearing=False)
    z.road("S", [e("S"), (-16, 28), (-28, 44), J], w=4.0, end_clearing=False)
    z.road("SE", [e("SE"), (24, 20), (37, 35), (44, 46), A(COLINA_R - 2.5, -112.0)], w=4.0, end_clearing=False)
    z.road("arco_leste", [(48, -47), (62, -38), (74, -26), (80, -12), (74, -3)], w=3.0, end_clearing=False)
    z.road("arco_sul", [J, (-26, 70), (-14, 80), (10, 85), (30, 80), A(COLINA_R - 2.5, 158.0)], w=3.0, end_clearing=False)
    z.road("arco_oeste", [(-63, 6), (-54, 16), (-50, 30), (-50, 44), J], w=3.0, end_clearing=False)
    z.arrival(arrive, toward=portal, r=6.0)
    z.bridges()

    # ---------- relevo: patamares baixos de pedra cinza (só onde cabem) e o marco ----------
    n_t = 0
    for c, r, lv in [((-84, -46), 6, 2), ((86, 40), 6, 2), ((40, -86), 5, 1), ((-84, 40), 6, 2), ((16, 100), 5, 1),
                     ((86, -48), 5, 2), ((-20, -84), 5, 1), ((22, -50), 4, 1), ((-12, 44), 4, 1), ((-70, 80), 5, 2)]:
        if math.hypot(*c) + r > z.rim_r(math.atan2(c[1], c[0])) - 5.0 or not z.free(c[0], c[1], r + 5.0):
            continue
        if any(math.hypot(c[0] - s[1], c[1] - s[2]) < r + s[3] + 2.0 for s in SPAWNERS) or any(math.hypot(c[0] - g[0], c[1] - g[1]) < r + 10.0 for g in GATHER):
            continue
        if any(math.hypot(c[0] - p["pos"][0], c[1] - p["pos"][1]) < r + 16.0 for p in PLACES if "pos" in p):
            continue
        z.terrace("pedra_%d" % n_t, c, r, lv, top="cliff_grass")
        n_t += 1
    z.cliffs(snow=False)

    z.avoid = [(COLINA, COLINA_R), (LANDMARK, 8.0), (CEM, 15.0)]
    places.build(z, PLACES)

    # ---------- vegetação: campo aberto e seco; árvores mortas em bosques baixos entre os lugares ----------
    for c, r in ((HUB, 22.0), (CEM, 19.0), (RUAS, 19.0), (COLINA, COLINA_R + 4.5), (J, 5.0), (LANDMARK, 10.0), (TOMB, 5.0)):
        z.block(c, r)
    for g in GATHER:
        z.block(g, 9.5)
    for s in SPAWNERS:
        z.block((s[1], s[2]), 5.2)
    for q in PATROL:
        z.block(q, 3.0)
    z.scatter("tree", [((-30, -70), 18, 14), ((-86, -24), 12, 8), ((84, -30), 12, 8), ((10, -44), 12, 7), ((-62, 36), 10, 6),
                       ((80, 66), 12, 8), ((-8, 100), 12, 8), ((-74, 64), 12, 6), ((30, 6), 10, 5), ((60, 20), 10, 5)],
              0, (1.5, 3.3, 1.5), DEAD_TREES, margin=4.0, spacing=4.2, scale=(0.9, 1.4))
    z.scatter("tree", [((0, 0), 104, 70)], 0, (1.5, 3.3, 1.5), DEAD_TREES, margin=4.6, spacing=5.0, scale=(0.8, 1.2))
    z.rim_belt(130, (1.5, 3.3, 1.5), DEAD_TREES)
    z.scatter("rock", [((0, 0), 100, 36)], 0, (1.4, 0.9, 1.2), [(0.6, 0.58, 0.54)], margin=3.5, spacing=3.0, scale=(0.7, 1.5))
    z.scatter("ruin", [((0, 0), 98, 12), (RUAS, 30, 6)], 0, (2.4, 1.6, 0.7), [(0.7, 0.68, 0.62)], margin=4.0, spacing=5.0, scale=(0.7, 1.3))

    nrnd = random.Random(117)
    obs = z.data["obstacles"]
    fr = lambda x, zz, m: z.free(x, zz, m)
    nature.fix_trees(obs, nrnd, dead=True, dead_cols=DEAD_COLS)
    nature.scatter(z.ob, fr, nrnd, "bush", [((0, 0), 100, 50)], (1.6, 0.85, 1.6), [(0.44, 0.46, 0.32), (0.5, 0.5, 0.34)],
                   solid=False, margin=2.6, spacing=3.0, avoid=obs)
    nature.woodland_floor(z.ob, fr, nrnd, [((-30, -70), 18, 5), ((0, 0), 98, 12)], bark=[(0.42, 0.38, 0.33), (0.36, 0.33, 0.3)], avoid=obs)
    nature.clear_banks(obs, z.rivers, [], z.river_w)
    nature.shore(z.ob, nrnd, z.rivers, [], list(z.road_polys.values()), z.river_w, colors=[(0.4, 0.44, 0.32), (0.46, 0.46, 0.36)],
                 keep=0.6, blocked=[(COLINA, COLINA_R + 1.0)])

    # ---------- NPCs e pontos de bot (nomes/papéis: world-builder, MapsCatalog.PLACE_NPCS["field_oaths"]) ----------
    fire, bell = (0.0, 2.0), (0.0, -7.0)
    guide, merchant, malcom = (-3.8, 4.6), (2.6, 10.0), (0.0, -3.9)
    z.npc("oaths_guide", guide[0], guide[1], face_to(guide[0], guide[1], *fire))
    z.npc("oaths_merchant", merchant[0], merchant[1], face_to(merchant[0], merchant[1], *HUB))
    z.npc("oaths_malcom", malcom[0], malcom[1], face_to(malcom[0], malcom[1], *bell))
    z.data["hangouts"] = [[round(q[0], 2), round(q[1], 2)] for q in (H(6.0, -150.0), H(6.5, -30.0), H(7.0, 20.0), H(6.5, 60.0),
                                                                    H(7.5, 140.0), H(6.0, 178.0), H(8.5, -118.0), H(8.0, -62.0))]

    # ---------- monstros (ids do world-builder; GDD 3.3) ----------
    for mid, x, zz, r, n, resp in SPAWNERS:
        z.spawner(mid, x, zz, r, n, resp)
    z.spawner("night_digger", PATROL[0][0], PATROL[0][1], 2, 2, 60.0, route=PATROL)
    z.spawner("fallen_bearer", COLINA[0], COLINA[1], 2, 1, 180.0)

    # ---------- acabamento (dress.py) ----------
    d = Dress(z, 523)
    rnd = d.rnd
    for s in z.data["spawners"]:                              # folga de 3 m de todo sólido em volta de cada ponto de spawn
        d.reserve(s["pos"][0], s["pos"][1], 2.6)
    d.mottle([("campo_seco", (0.5, 0.5, 0.42)), ("campo_palha", (0.56, 0.55, 0.45)), ("campo_cinza", (0.47, 0.48, 0.41))],
             [((0, 0), 102, 170)], y=0.0008, rmin=3.0, rmax=8.5, step=0.0008)
    d.mottle([("campo_queimado", (0.42, 0.4, 0.35))], [((-30, -70), 18, 6), ((84, -30), 12, 4), ((80, 66), 12, 4), ((-8, 100), 12, 4),
                                                       ((10, -44), 12, 4), ((-74, 64), 12, 4)], y=0.0034, rmin=4.0, rmax=8.0, group="queimado")
    d.road_edges((0.5, 0.47, 0.38), extra=-0.2, wvar=0.45)
    d.roadside(d.m("seixo_campo", (0.6, 0.58, 0.54)), d.m("capim_campo", (0.54, 0.54, 0.4)), every=5.5)

    # Acampamento da Vigília: 5 tendas brancas da Aurora em arco, fogueira, cavalete com o sino rachado, carroça-banca
    bell_gantry(z, d, bell, 0.0)
    d.cookfire(fire, 1.0, 10.0)
    d.solid(fire[0], fire[1], 2.2, 2.2, 1.2)
    for a in (-112.0, -68.0, 0.0, 145.0, 198.0):
        t = H(15.5, a)
        d.tent_aurora(t, door_rot(HUB, t), 1.25, trim=BLUE, gold=GOLD)
        d.solid(t[0], t[1], 4.4, 4.4, 3.4)
    cart = H(13.2, 80.0)
    d.cart(cart, -80.0 + 90.0, load=(0.62, 0.56, 0.44))
    d.solid(cart[0], cart[1], 3.0, 3.0, 1.4)
    for q in (H(14.2, 95.0), H(14.6, 66.0)):
        d.sack(q, 1.0)
    d.barrel(H(12.6, 99.0), 0.9)
    for a in (-90.0, 172.0 - 30.0, 30.0):                     # carga da Vigília entre as tendas (fora das saídas)
        q = H(18.6, a)
        if d.ok(q[0], q[1], 1.2, road=0.6):
            d.cargo(q, 4, 1.0)
            d.solid(q[0], q[1], 2.0, 2.0, 1.1)
    for a in (-20.0, 160.0):
        q = H(17.5, a)
        if d.ok(q[0], q[1], 0.9, road=0.6):
            d.hay(q, 1.0)
            d.solid(q[0], q[1], 1.6, 1.6, 1.2)
    for a in (EXITS["NO"] + 18.0, EXITS["NE"] - 18.0, EXITS["SE"] + 18.0, EXITS["S"] - 18.0, EXITS["O"] + 18.0):
        d.torch(H(HUB_R + 0.9, a), 2.0)
    sq = H(14.5, EXITS["NO"] - 22.0)
    d.signpost(sq, 40.0, n=3)
    d.solid(sq[0], sq[1], 0.5, 0.5, 2.4)
    d.weapon_rack(H(10.2, -150.0), door_rot(HUB, H(10.2, -150.0)))
    d.solid(*H(10.2, -150.0), 2.0, 0.6, 1.5)
    seat = d.m("toco_banco", (0.42, 0.33, 0.24))
    for a in (40.0, 140.0, 220.0, 320.0):
        q = (fire[0] + math.cos(math.radians(a)) * 2.6, fire[1] + math.sin(math.radians(a)) * 2.6)
        d.cyl("vigilia", seat, q, 0.27, 0.24, 0.42, 0.0, 7)

    # garganta NO: dois tocos de coluna da Aurora e a placa
    stone, stone_d = d.m("pedra_velthar", (0.72, 0.68, 0.58)), d.m("pedra_velthar_esc", (0.56, 0.53, 0.46))
    to_p = Vector(portal) - Vector(arrive)
    sd = Vector((-to_p.y, to_p.x)).normalized()
    for k in (-1, 1):
        q = Vector(arrive) + sd * 6.6 * k + to_p.normalized() * 1.5
        if d.ok(q.x, q.y, 0.8, road=0.4):
            broken_column(d, (q.x, q.y), rnd, stone, stone_d, h=1.6 + 0.8 * (k > 0))
            d.solid(q.x, q.y, 1.5, 1.5, 2.4)

    # Cemitério dos Cavaleiros: colunas de lápides (ruas de 4 m entre elas), elmos em estacas, Túmulo de Vorhag
    mausoleum(z, d, TOMB, 180.0)
    tomb_stone = d.m("lapide", STONE)
    cova = d.m("lapide_cova", (0.36, 0.33, 0.27))
    steel, stake = d.m("elmo_aco", (0.62, 0.64, 0.68)), d.m("estaca", (0.4, 0.31, 0.22))
    n_st = 0
    for x in (-88.0, -83.5, -79.0, -74.5, -70.0, -65.5):
        for block in ((-9.5, -7.1, -4.7, -2.3), (14.0, 16.4, 18.8, 21.2)):
            run = []
            for zz in block:
                if d.ok(x, zz, 0.75, road=1.2, rim=2.0) and math.hypot(x - TOMB[0], zz - TOMB[1]) > 4.2:
                    run.append(zz)
            for zz in run:
                headstone(d, (x, zz), -90.0, rnd.uniform(1.05, 1.5), rnd, tomb_stone, cova)
                d.reserve(x, zz, 0.75)
                n_st += 1
            if run:                                           # uma caixa por fileira (vãos de 1 m entre lápides não passam)
                wall_box(z, (x, (run[0] + run[-1]) * 0.5), 0.7, run[-1] - run[0] + 1.3, 1.6)
    for q in d.spots([((CEM[0] + 2.0, 1.0), 12, 7), ((CEM[0] + 2.0, 11.0), 12, 7)], r=0.4, spacing=3.0, road=0.8, tries=12):
        helm_stake(d, q, rnd, steel, stake)
    print("field_oaths: cemitério com %d lápides" % n_st)

    # Ruas Afundadas: calçamento de Vel'Thar em retalhos ao longo da rua antiga, colunas quebradas nas duas calçadas,
    # arcos caídos, cacos de cerâmica
    ax = Vector((math.cos(math.radians(RUAS_AXIS)), math.sin(math.radians(RUAS_AXIS))))
    nx = Vector((-ax.y, ax.x))
    slab_a, slab_b = d.m("laje_velthar", (0.74, 0.7, 0.6)), d.m("laje_velthar_b", (0.66, 0.62, 0.52))
    for i in range(-7, 8):
        for j in range(-2, 3):
            if rnd.random() < 0.35:
                continue
            q = Vector(RUAS) + ax * (i * 2.2 + rnd.uniform(-0.3, 0.3)) + nx * (j * 2.0 + rnd.uniform(-0.2, 0.2))
            if not d.ok(q.x, q.y, 0.9, road=-1.0, water=0.5):
                continue
            d.box("calcamento", slab_a if (i + j) % 2 else slab_b, (q.x, q.y), (2.0, 0.08, 1.8), -RUAS_AXIS + rnd.uniform(-6, 6), -0.02,
                  tilt=(rnd.uniform(-3, 3), rnd.uniform(-3, 3)))
    for i in range(-3, 4):
        for s in (-1, 1):
            q = Vector(RUAS) + ax * (i * 5.0 + 1.2 * s) + nx * 7.0 * s
            if (i + s) % 3 == 0 or not d.ok(q.x, q.y, 0.8, road=0.8):
                continue
            broken_column(d, (q.x, q.y), rnd, stone, stone_d)
            d.solid(q.x, q.y, 1.5, 1.5, 3.0)
    for q, ro in ((Vector(RUAS) + ax * 13.0 - nx * 3.0, -RUAS_AXIS + 70.0), (Vector(RUAS) - ax * 12.0 + nx * 4.0, -RUAS_AXIS - 60.0)):
        if d.ok(q.x, q.y, 2.8, road=0.8):
            fallen_arch(z, d, (q.x, q.y), ro, stone, stone_d)
            d.reserve(q.x, q.y, 2.8)
    shard = d.m("caco_ceramica", (0.72, 0.5, 0.36))
    for q in d.spots([(RUAS, 16, 18)], r=0.3, spacing=2.0, road=0.2, tries=8):
        d.rock("caco", shard, q, rnd.uniform(0.15, 0.3), 0.0, 0.35, sx=1.6, rot=rnd.uniform(0, 180))

    # Vala dos Cavadores: covas abertas, montes de terra, pás, carroça de ossos (o lugar `camp` já pôs tendas e caixotes)
    for q in d.spots([(VALA, 6.5, 5)], r=1.6, spacing=3.6, road=0.4, tries=20):
        if math.hypot(q[0] - VALA[0], q[1] - VALA[1]) < 4.2:
            continue                                          # o miolo fica para o bando (spawner no centro)
        grave_pit(d, q, rnd.uniform(0, 180), rnd)
        d.solid(q[0], q[1], 1.6, 1.6, 0.6)
    V = lambda r, a: (VALA[0] + math.cos(math.radians(a)) * r, VALA[1] + math.sin(math.radians(a)) * r)
    cq = V(10.5, 110.0)
    if d.ok(cq[0], cq[1], 1.6, road=0.6):
        d.cart(cq, 30.0, color=(0.3, 0.24, 0.2), load=(0.84, 0.8, 0.7))
        d.bones((cq[0] + 1.6, cq[1] + 1.0), 5, 1.4)
        d.solid(cq[0], cq[1], 3.0, 3.0, 1.4)
    for a in (150.0, 200.0, 250.0):
        q = V(12.5, a)
        if d.ok(q[0], q[1], 0.5, road=0.8):
            d.flag(q, (0.22, 0.18, 0.26), h=3.6, rot=a, pole=(0.24, 0.2, 0.18))
    for q in d.spots([(VALA, 13, 5)], r=0.5, spacing=3.0, road=0.5, tries=10):
        d.bones(q, 3, 1.0, skull=rnd.random() < 0.5)

    # Colina do Estandarte: arena limpa; anéis no tom do próprio chão e estandartes caídos só por FORA do círculo
    t1, t2 = d.m("patch_colina_a", (0.55, 0.5, 0.41)), d.m("patch_colina_b", (0.62, 0.56, 0.46))
    d.arc("arena", t1, COLINA, COLINA_R - 3.0, 0.0, math.tau, 1.2, y=0.0074, wvar=0.3)
    d.arc("arena", t2, COLINA, COLINA_R - 8.5, 0.0, math.tau, 0.8, y=0.0078, wvar=0.3)
    pole_m = d.m("mastro_caido", (0.46, 0.38, 0.28))
    for k in range(14):
        a = 360.0 * k / 14 + rnd.uniform(-6, 6)
        q = A(COLINA_R + 2.0 + rnd.uniform(0.0, 1.6), a)
        if not d.ok(q[0], q[1], 1.2, road=0.8, water=0.8):
            continue
        if k % 3 == 0:
            d.flag(q, GOLD if k % 2 else BLUE, h=4.2, rot=a + 90.0, pole=(0.46, 0.38, 0.28))
        else:
            fallen_banner(d, q, a + 90.0 + rnd.uniform(-30, 30), rnd, pole_m, d.m("pano_caido_%d" % (k % 2), DROP_GOLD if k % 2 else DROP_BLUE),
                          d.m("pano_caido_barra_%d" % (k % 2), DROP_GOLD_D if k % 2 else DROP_BLUE_D))
    for q in d.spots([(COLINA, COLINA_R + 6.0, 10)], r=0.4, spacing=3.0, road=0.5, water=0.6, tries=8):
        if math.hypot(q[0] - COLINA[0], q[1] - COLINA[1]) > COLINA_R + 1.0:
            helm_stake(d, q, rnd, steel, stake)

    # Cabana do Sineiro: torre do sino caída atrás da capela; Choupana da Corveira: poleiros com penas
    sin = PLACES[0]
    sdir = Vector((math.cos(math.radians(sin["face"])), math.sin(math.radians(sin["face"]))))
    tq = Vector(sin["pos"]) - sdir * 10.5 + Vector((-sdir.y, sdir.x)) * 2.0
    if d.ok(tq.x, tq.y, 2.0, road=0.6):
        ro = math.degrees(math.atan2(-sdir.y, sdir.x)) + 35.0
        d.box("torre_caida", stone, (tq.x, tq.y), (6.4, 1.6, 1.8), ro, 0.0, tilt=(0, 4))
        d.box("torre_caida", d.m("telhado_torre", (0.34, 0.34, 0.38)), local((tq.x, tq.y), ro)(3.8, 0.0), (1.8, 1.2, 2.0), ro + 12.0, 0.0, tilt=(0, 20))
        bq = local((tq.x, tq.y), ro)(-1.2, 1.9)
        d.cyl("torre_caida", d.m("sino_bronze", (0.62, 0.5, 0.3)), bq, 0.5, 0.3, 0.8, 0.1, 8, 0.0, tilt=(70, 0))
        wall_box(z, (tq.x, tq.y), 6.4, 1.8, 1.6, ro)
    cor = PLACES[1]
    cdir = Vector((math.cos(math.radians(cor["face"])), math.sin(math.radians(cor["face"]))))
    for k, off in enumerate((-50.0, 50.0, 150.0)):
        a = math.radians(cor["face"] + 180.0 + off)
        q = (cor["pos"][0] + math.cos(a) * 9.0, cor["pos"][1] + math.sin(a) * 9.0)
        if d.ok(q[0], q[1], 1.0, road=0.6):
            perch(d, q, rnd.uniform(0, 180), rnd)
            d.solid(q[0], q[1], 0.6, 0.6, 3.0)

    # Estandarte Partido (marco) e o resto do campo: elmos e estandartes caídos espalhados, ossos, tufos de capim seco
    broken_standard(z, d, LANDMARK, rnd)
    for q in d.spots([((0, 0), 96, 8)], r=1.0, spacing=16.0, road=1.0, blocked=True, tries=8):
        fallen_banner(d, q, rnd.uniform(0, 180), rnd, pole_m, d.m("pano_caido_1", DROP_GOLD), d.m("pano_caido_barra_1", DROP_GOLD_D))
    for q in d.spots([((0, 0), 96, 14)], r=0.4, spacing=10.0, road=0.8, blocked=True, tries=8):
        helm_stake(d, q, rnd, steel, stake)
    for q in d.spots([((0, 0), 96, 18)], r=0.5, spacing=8.0, road=0.5, blocked=True, tries=6):
        d.bones(q, 3, 1.0, skull=rnd.random() < 0.4)
    grass, grass2 = d.m("capim_seco", (0.6, 0.58, 0.44)), d.m("capim_seco_b", (0.52, 0.52, 0.4))
    for q in d.spots([((0, 0), 98, 120)], r=0.5, spacing=3.8, road=0.3, blocked=True, tries=5):
        for j in range(rnd.randint(2, 4)):
            d.tuft("mini", grass if j % 2 else grass2, (q[0] + rnd.uniform(-0.8, 0.8), q[1] + rnd.uniform(-0.8, 0.8)), 0.55, 0.8, 6, w=0.12)
    for q in d.spots([((0, 0), 96, 14)], r=2.0, spacing=16.0, road=1.5, blocked=True):
        d.outcrop(q, 1.8, 3, (0.56, 0.54, 0.5), top=(0.48, 0.5, 0.4), hmul=0.6)
        d.solid(q[0], q[1], 2.8, 2.8, 1.2)
    d.flush()

    audit(z, (COLINA, COLINA_R))
    print("field_oaths: portal %s chegada %s (chegada no Bastião %s)" % (portal, arrive, BASTION_ARRIVE))
    print("field_oaths: lugares %s" % [(p["id"], p["type"], p["pos"], round(math.hypot(*p["pos"]), 1)) for p in z.data["places"]])
    print("field_oaths: portais futuros %s" % z.data.get("future_portals"))
    print("field_oaths: npcs %s" % z.data["npcs"])
    print("field_oaths: spawners (%d vivos) %s" % (sum(s["count"] for s in z.data["spawners"]),
                                                  [(s["monster_id"], s["pos"], s["radius"], s["count"]) for s in z.data["spawners"]]))
    print("field_oaths: pontes %s" % z.data.get("bridges"))
    return z.finish(export, poi=COLINA, ground=GROUND)
