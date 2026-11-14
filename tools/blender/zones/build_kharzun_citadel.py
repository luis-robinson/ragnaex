"""Cidadela de Kharzun (kharzun_citadel, Lv 44-45): a fortaleza da Horda entalhada no pico, mapa de masmorra
(`parent_map` field_kharzun: sem montaria, bots só com o grupo do jogador). Um laço gera tudo a partir de HALLS/EDGES:
salões redondos de basalto ligados por corredores, rocha sólida entre as alas (build_dungeons._rock_fill).

    chegada (sul, garganta do Portão) -> barbacã -> PÁTIO DE ARMAS (a Ofensiva da Aurora sobe até aqui)
      oeste  Ala do Lobo:  canis -> rampa dos ginetes -> arena de Ulgra Presa-Atroz
      leste  Ala da Pedra: caverna dos trolls -> poças de musgo -> arena de Gorbash Pele-de-Rocha
      nordeste Ala da Forja: fundição (canais de lava) -> arena de Kragmar Martelo-Negro
      norte  antecâmara dos três clãs -> PORTA DO TRONO (fechada até hx_clan_wolf + hx_clan_stone + hx_clan_forge)
             -> sala do trono de Durgash (raide de 5; três soquetes de Estandarte de Clã)
As três alas saem do pátio e valem em qualquer ordem; o trono também sai do pátio (fechar uma ala não fecha nada mais).
A porta é um colisor de estágio (`unless` os três clãs) + duas folhas no GLB (`trono_fechado` / `trono_aberto`); cada clã
caído acende o seu braseiro na antecâmara (`cla_<clã>_vivo` / `cla_<clã>_caido`). Durgash só nasce com a porta aberta.
Dados para os outros pacotes no JSON: `arenas` (centro e raio de cada chefe, soquetes dos estandartes, porta) e `wings`.

    set RAGNAEX_ROOT=<projeto ou worktree>
    blender -b --factory-startup --python tools/blender/zones/run_zone.py -- build_kharzun_citadel <pasta_png ABSOLUTA> --export
    (CITADEL_POI=<patio|lobo|pedra|forja|selo|trono|canis|pocas|fundicao|barbaca> escolhe o alvo da CAM_poi)
"""
import math
import os
import random
from mathutils import Vector

import act2_dress
import build_dungeons as bd
import horde
import places
from act2_dress import P
from dress import Dress
from zone_lib import Zone, box, cyl, cone, disc, mat

ZONE = "kharzun_citadel"
ARRIVE = (0.0, 96.0)                     # chegada (build_kharzun.CITADEL_ARRIVE aponta para cá)
BACK = (0.0, -107.4)                     # volta: diante do Portão da Cidadela em field_kharzun ("BACK citadel" no build_kharzun)
RIM = 116.0
Q_GATE, Q_WARLORD = "hx_citadel_gate", "hx_warlord"
Q_CLANS = ["hx_clan_wolf", "hx_clan_stone", "hx_clan_forge"]

BASALT = (0.3, 0.28, 0.31)
FLOOR = (0.5, 0.46, 0.46)                # cinza claro pisado: o chão lê-se contra a rocha escura
ROCK_TOP = (0.22, 0.21, 0.25)
LAVA = (1.0, 0.46, 0.14)
HORDE_RED = horde.HORDE_RED
BONE = (0.86, 0.8, 0.62)
# cor de cada clã (estandartes, anéis no chão, braseiros da antecâmara)
CLAN = {"wolf": (0.84, 0.86, 0.92), "stone": (0.42, 0.78, 0.5), "forge": (1.0, 0.56, 0.2)}
CLAN_PT = {"wolf": "lobo", "stone": "pedra", "forge": "forja"}
# cor do clã apagada (sem brilho) para a lasca na pedra do soquete: diz qual estandarte vai onde sem pintar o chão da luta
# (lobo: azul-gelo claro com aro escuro por baixo; o cinza-azulado antigo sumia na pedra do soquete vista a 52°).
# Lobo bem mais azul que o tom desejado: a luz do trono (ambiente quente + braseiros de lava) come o azul e o (0.74, 0.85, 0.98)
# saía pêssego no jogo; este sai branco-azulado. Aro marinho mais azul e mais largo (ver CLAN_CHIP_RING_R).
CLAN_CHIP = {"wolf": (0.44, 0.8, 1.0), "stone": (0.4, 0.56, 0.45), "forge": (0.72, 0.45, 0.27)}
CLAN_CHIP_RING = {"wolf": (0.08, 0.2, 0.5)}        # aro escuro em volta da lasca (só onde a lasca é clara como a pedra)
CLAN_CHIP_RING_R = (0.8, 0.76)                     # raio do aro (base, topo); era 0.6/0.57, mal passava da lasca (0.45)
CLAN_Q = {"wolf": "hx_clan_wolf", "stone": "hx_clan_stone", "forge": "hx_clan_forge"}

# salões: pos, r, chão, bichos [(id, n)] (o jogo multiplica n > 1 por Balance.SPAWN_COUNT_MULT; líder traz escolta), chefe
HALLS = {
    "barbaca": {"pos": (0, 72), "r": 10, "floor": (0.42, 0.38, 0.38), "mobs": [("clan_guard", 2)], "mob_off": (0.0, -3.0)},
    "patio": {"pos": (0, 36), "r": 18, "floor": (0.47, 0.42, 0.41), "mobs": [("orc_warlord", 1), ("clan_guard", 3), ("orc_fire_archer", 1)]},
    # Ala do Lobo (oeste): palha e couro
    "canis": {"pos": (-44, 44), "r": 11, "floor": (0.52, 0.44, 0.32), "mobs": [("dire_wolf", 4)], "wing": "wolf"},
    "rampa": {"pos": (-72, 24), "r": 10, "floor": (0.46, 0.4, 0.36), "mobs": [("dire_wolf_rider", 2)], "wing": "wolf"},
    "arena_lobo": {"pos": (-78, -10), "r": 16, "floor": (0.5, 0.47, 0.5), "boss": "boss_ulgra", "wing": "wolf"},
    # Ala da Pedra (leste): musgo e pedregulho
    "caverna": {"pos": (44, 44), "r": 11, "floor": (0.36, 0.44, 0.36), "mobs": [("troll_brute", 1), ("troll_thrower", 1)], "wing": "stone"},
    "pocas": {"pos": (72, 24), "r": 10, "floor": (0.3, 0.42, 0.38), "mobs": [("troll_brute", 1), ("troll_thrower", 1)], "wing": "stone",
              "pool": (0.4, 0.92, 0.72)},
    # arena: pedra cinza com um fio de musgo (era verde vivo: lia como zona de golpe; telegraph-fix 2026-11-13).
    # Cinza-AZULADO de propósito: a luz da cidadela é quente (ambient 0.98/0.74/0.62 + tocha 1.0/0.72/0.42) e o cinza neutro
    # (0.43, 0.45, 0.42) saía bege/marrom no jogo; x luz quente este tom dá cinza frio.
    "arena_pedra": {"pos": (78, -10), "r": 15, "floor": (0.34, 0.45, 0.58), "boss": "boss_gorbash", "wing": "stone"},
    # Ala da Forja (nordeste): ferrugem e lava
    # chão de basalto cinza-quente (era ferrugem/vermelho: o aviso vermelho do chefe sumia; art review 2026-11-13, item 3)
    "fundicao": {"pos": (34, 2), "r": 11, "floor": (0.44, 0.38, 0.35), "mobs": [("lava_salamander", 3), ("orc_fire_archer", 1)], "wing": "forge",
                 "pool": LAVA, "decor": [("anvil", 3, (1.0, 1.0, 0.6), (0.4, 0.4, 0.42)), ("cauldron", 2, (1.1, 1.0, 1.1), (0.3, 0.3, 0.32))]},
    "arena_forja": {"pos": (50, -44), "r": 15, "floor": (0.4, 0.35, 0.34), "boss": "boss_kragmar", "wing": "forge"},
    # trono (norte). Chão do trono: basalto cinza-quente NO JOGO. O (0.37, 0.29, 0.3) saía bordô escuro (medido no tour:
    # 0.37/0.16/0.11) e os avisos carmesim e o ouro do "junte aqui" sumiam nele; a luz do salão come verde e azul, então o
    # albedo é azulado e mais claro (como o da arena de pedra) para dar ~(0.43, 0.34, 0.31) na tela. O tapete segue vinho apagado.
    "selo": {"pos": (0, -6), "r": 9, "floor": (0.42, 0.35, 0.35), "mobs": [("clan_guard", 3)]},
    "trono": {"pos": (0, -54), "r": 22, "floor": (0.43, 0.58, 0.73), "boss": "boss_durgash", "when": {"if": Q_CLANS}},
}
# ligações: (a, b, curva, bando do corredor (id, n) ou None)
EDGES = [
    ("chegada", "barbaca", 0.0, None), ("barbaca", "patio", 0.0, None),
    ("patio", "canis", 0.1, ("dire_wolf", 2)), ("canis", "rampa", -0.12, ("dire_wolf", 2)), ("rampa", "arena_lobo", 0.1, ("dire_wolf_rider", 1)),
    ("patio", "caverna", -0.1, ("troll", 2)), ("caverna", "pocas", 0.12, ("troll_thrower", 1)), ("pocas", "arena_pedra", -0.1, ("troll_brute", 1)),
    ("patio", "fundicao", 0.1, ("lava_salamander", 2)), ("fundicao", "arena_forja", -0.1, ("basalt_golem", 1)),
    ("patio", "selo", 0.0, ("clan_guard", 2)), ("selo", "trono", 0.0, None),
]
DOOR = (0.0, -27.0)                      # porta do trono, no corredor selo -> trono
THRONE = HALLS["trono"]["pos"]
BANNERS = {"wolf": P(THRONE, 11.0, 210.0), "stone": P(THRONE, 11.0, 330.0), "forge": P(THRONE, 11.0, 90.0)}
DAIS = (THRONE[0], THRONE[1] - 15.5)


def _mouths(name, rooms):
    x, y = rooms[name]["pos"]
    out = []
    for a, b, _, _ in EDGES:
        if name in (a, b):
            ox, oy = rooms[b if a == name else a]["pos"]
            out.append(math.atan2(oy - y, ox - x))
    return out


def _rock_fill(z):
    """Rocha em tudo que não é chão (é o que sela as alas), em duas malhas: blocos finos (r 4) colados nos salões e
    corredores, como nas masmorras, e blocos largos (r 13) no miolo da montanha, longe de todo chão. O bloco fino que cai
    inteiro dentro de um largo não é criado: a cobertura é a mesma com um terço das peças (GLB e colisores)."""
    import bpy
    from zone_lib import poly_dist
    fine, coarse = [], []
    half = bd.WALKWAY * 0.5 + 0.3
    step, r = 16.8, 13.0
    n = int(RIM / step) + 3
    for row in range(-n, n + 1):
        y = row * step * 0.87
        for col in range(-n, n + 1):
            x = (col + 0.5 * (row % 2)) * step
            # z.free só olha o CENTRO contra as áreas reservadas: o bloco largo confere a própria borda (+2 m de folga,
            # fica atrás dos finos)
            if z.free(x, y, r + half + 2.0) and all((Vector((x, y)) - c).length >= cr + r - 2.0 for c, cr in z.blocked):
                coarse.append((round(x, 1), round(y, 1)))
    step, r = 5.6, 4.0
    n = int(RIM / step) + 3
    inside = lambda x, y: any((x - cx) ** 2 + (y - cy) ** 2 <= 9.0 ** 2 for cx, cy in coarse)
    for row in range(-n, n + 1):
        y = row * step * 0.87
        for col in range(-n, n + 1):
            x = (col + 0.5 * (row % 2)) * step
            if z.free(x, y, r + half) and not inside(x, y):
                fine.append((round(x, 1), round(y, 1)))
    k = int(math.tau * RIM / 5.0)
    for i in range(k):                                       # anel junto à borda (a grade para 3 m antes do penhasco)
        a = math.tau * i / k
        rr = z.rim_r(a) - 1.8
        x, y = math.cos(a) * rr, math.sin(a) * rr
        p = Vector((x, y))
        if any((p - c).length < cr for c, cr in z.blocked) or any(poly_dist(p, poly) <= r + half for poly in z.road_polys.values()):
            continue
        fine.append((round(x, 1), round(y, 1)))
    for i, c in enumerate(coarse):
        z.terrace("macico_%d" % i, c, 13.0, 1)
    for i, c in enumerate(fine):
        z.terrace("parede_%d" % i, c, 4.0, 1)
    objs = [o for o in z.coll.objects if o.name.startswith(z.P + "morro_")]
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.object.join()
    print("CIDADELA paredes: %d finas + %d largas" % (len(fine), len(coarse)))


def _door(z):
    """Porta do trono: dois pilares de basalto (sempre sólidos), colisor de estágio no vão e as folhas (fechada / aberta)."""
    x, y = DOOR
    rock = z.M["cliff_rock"]
    for s in (-1, 1):
        p = (x + s * 4.4, y)
        cyl(z.coll, z.P + "porta_pilar_%d" % s, p, 1.7, 1.4, 6.4, rock, 0.0, 6)
        cone(z.coll, z.P + "porta_pilar_chama_%d" % s, p, 0.7, 1.5, z.M["glow_lava"], 6.4, 6)
        z.ob("pillar", p[0], p[1], (3.2, 6.4, 3.2), visible=False)
    box(z.coll, z.P + "porta_verga", (x, y), (10.4, 1.1, 1.6), 0.0, rock, 5.2)
    z.ob("wall", x, y, (14.0, 6.0, 2.4), 0.0, visible=False, when={"unless": Q_CLANS}, stage_solid=True)
    iron = mat("porta_trono", (0.2, 0.18, 0.2))
    for s in (-1, 1):                                        # fechada: duas folhas de ferro negro com o punho da Horda
        box(z.coll, z.P + "trono_fechado_folha_%d" % s, (x + s * 1.45, y), (2.9, 5.2, 0.5), 0.0, iron)
        box(z.coll, z.P + "trono_fechado_faixa_%d" % s, (x + s * 1.45, y + 0.3), (2.5, 0.5, 0.12), 0.0, mat("glow_selo_trono", (1.0, 0.3, 0.16)), 2.4)
        # aberta: as folhas viradas para dentro, coladas nos pilares
        box(z.coll, z.P + "trono_aberto_folha_%d" % s, (x + s * 2.8, y - 1.6), (2.9, 5.2, 0.5), 90.0, iron)
    z.block(DOOR, 6)


def _throne(z):
    """Estrado de três degraus, o trono de basalto com chifres e dois braseiros de lava; tapete vermelho da porta ao estrado."""
    rock, dark = z.M["cliff_rock"], z.M["cliff_rock_d"]
    for k in range(3):
        cyl(z.coll, z.P + "trono_degrau_%d" % k, DAIS, 6.4 - k * 1.3, 6.2 - k * 1.3, 0.3, dark if k % 2 else rock, k * 0.3, 14)
    box(z.coll, z.P + "trono_assento", (DAIS[0], DAIS[1] - 1.6), (3.0, 1.2, 1.8), 0.0, dark, 0.9)
    box(z.coll, z.P + "trono_encosto", (DAIS[0], DAIS[1] - 2.6), (3.4, 4.6, 0.8), 0.0, rock, 0.9)
    for s in (-1, 1):
        cone(z.coll, z.P + "trono_chifre_%d" % s, (DAIS[0] + s * 1.9, DAIS[1] - 2.6), 0.5, 2.6, mat("osso_trono", BONE), 5.2, 6)
        p = (DAIS[0] + s * 5.0, DAIS[1] + 1.8)
        cyl(z.coll, z.P + "trono_braseiro_%d" % s, p, 0.9, 1.2, 1.3, dark, 0.0, 8)
        cone(z.coll, z.P + "trono_brasa_%d" % s, p, 1.0, 2.0, z.M["glow_lava"], 1.3, 7)
        z.ob("pillar", p[0], p[1], (2.4, 2.6, 2.4), visible=False)
    horde.banner(z, "trono_estandarte", (DAIS[0], DAIS[1] - 4.0), HORDE_RED, 9.0, 0.0)
    z.ob("pillar", DAIS[0], DAIS[1] - 1.6, (7.0, 5.0, 7.0), visible=False)


def _dress(z, rooms):
    d = Dress(z, 613)
    rnd = d.rnd
    h = act2_dress.Halls(d, rooms, EDGES)
    lava = d.m("glow_lava", LAVA)
    for name in rooms:
        h.basalt(name, 0.7)
        for (p, a) in h.rim(name, int(rooms[name]["r"] * 0.8), 0.8, 0.92):
            d.pebbles("gruta", d.m("seixo_cidadela", (0.34, 0.31, 0.34)), p, rnd.randint(3, 5), 1.0, (0.12, 0.3))

    def side(q, ang):
        k = rnd.random()
        if k < 0.45:
            d.torch(q, 2.4)
        elif k < 0.7:
            act2_dress.basalt_columns(d, q, 3, 0.7, (0.6, 1.8))
        elif k < 0.85:
            d.bones(q, 3, 0.7)
        else:
            d.blob("corredor", lava, q, 0.3, 0.0234, 0.2, 7)
    h.corridor(side, every=4.0)

    def rimset(name, n, fn, k0=0.88, k1=0.95):
        for j, (p, a) in enumerate(h.rim(name, n, k0, k1)):
            if h.put(p):
                fn(j, p, a)

    def flag(p, a, col, hh=5.4):
        d.flag(p, col, hh, math.degrees(-a) + 90.0, w=1.1, drop=1.9)
        d.solid(p[0], p[1], 0.4, 0.4, 4.0)

    def brazier(p, s=1.2, fire="glow_brasa", col=(1.0, 0.56, 0.2)):
        d.brazier(p, s, fire=fire, color=col)
        d.solid(p[0], p[1], 1.2, 1.2, 1.4)

    def rack(p, a):
        d.weapon_rack(p, math.degrees(-a) + 90.0)
        d.solid(p[0], p[1], 2.4, 0.8, 1.6, math.degrees(-a) + 90.0)

    def cracks(name, n, k0=0.2, k1=0.8, w=0.26, ember=True):
        """Rachaduras do centro para fora. ember=False (arena de chefe): só a fenda, em dois tons escuros do chão, sem
        lava pintada (lava que não queima no meio da luta confunde com a poça de verdade do chefe)."""
        x, y = rooms[name]["pos"]
        r = rooms[name]["r"]
        soot = d.m("patch_fuligem", (0.26, 0.2, 0.18))
        if not ember:
            fl = rooms[name]["floor"]
            soot = d.m("patch_fenda_" + name, tuple(c * 0.84 for c in fl))
            core = d.m("patch_fenda_miolo_" + name, tuple(c * 0.68 for c in fl))
        for k in range(n):
            a = math.tau * k / n + rnd.uniform(-0.2, 0.2)
            L = r * (k1 - k0) * rnd.uniform(0.6, 1.0)
            pts = [Vector((x + math.cos(a) * r * k0, y + math.sin(a) * r * k0))]
            for j in range(1, 5):
                aa = a + rnd.uniform(-0.22, 0.22)
                pts.append(Vector((x + math.cos(aa) * (r * k0 + L * j / 4), y + math.sin(aa) * (r * k0 + L * j / 4))))
            d.strip(name, soot, pts, w * 3.4 if ember else w * 2.2, 0.0222, 0.4, taper=True)
            d.strip(name, lava if ember else core, pts, w if ember else w * 0.6, 0.0232, 0.3, taper=True)

    def mottle(name, tones, n, rmin=1.0, rmax=2.4, k=0.84):
        x, y = rooms[name]["pos"]
        ms = [d.m("patch_%s_%d" % (name, i), c) for i, c in enumerate(tones)]
        for i in range(n):
            q = P((x, y), rnd.uniform(1.0, rooms[name]["r"] * k), rnd.uniform(0, 360))
            d.blob(name, ms[i % len(ms)], q, rnd.uniform(rmin, rmax), 0.0222 + (i % 2) * 0.0004, 0.4)

    # ---- chegada: cavalos de frisa da Aurora virados para dentro e tochas ----
    cx, cy = rooms["chegada"]["pos"]
    for s in (-1, 1):
        d.torch((cx + s * 4.8, cy + 1.5), 2.4)
        q = (cx + s * 5.0, cy - 4.5)
        if h.put(q, 1.6):
            d.spikes(q, 0.0, 3.4, color=(0.56, 0.44, 0.3))
            d.solid(q[0], q[1], 3.4, 1.0, 1.2)
    # ---- barbacã: estacas da Horda, flâmulas vermelhas, cavaletes ----
    rimset("barbaca", 12, lambda j, p, a: flag(p, a, HORDE_RED) if j % 3 == 0 else (rack(p, a) if j % 3 == 1 else brazier(p)))
    mottle("barbaca", [(0.36, 0.33, 0.34), (0.47, 0.42, 0.41)], 8)
    # ---- pátio de armas: o punho da Horda pintado no chão, bonecos de treino, tendas, tambores, carga ----
    x, y = rooms["patio"]["pos"]
    r = rooms["patio"]["r"]
    mottle("patio", [(0.44, 0.4, 0.39), (0.5, 0.45, 0.43)], 18, 1.4, 3.0)
    # tinta de arena em tons do próprio chão (art review 2026-11-13, item 1: vermelho/osso vivos liam como aviso de golpe)
    patio_t = h.tones("patio")
    h.rings("patio", patio_t, (0.42, 0.62), w=0.28)
    for j in range(8):
        a = j * 45.0 + 22.5
        d.strip("patio", patio_t[1], [Vector(P((x, y), r * 0.45, a)), Vector(P((x, y), r * 0.52, a + 4)), Vector(P((x, y), r * 0.59, a))], 0.34, 0.0228, 0.2, taper=True)
    for k, deg in enumerate((200.0, 215.0, 230.0, 310.0, 325.0, 340.0)):          # bonecos de treino (norte do pátio, dos dois lados)
        q = P((x, y), r * 0.72, deg)
        if h.put(q, 0.7, 0.8):
            d.drill_post(q, -deg, shield=HORDE_RED)
            d.solid(q[0], q[1], 0.9, 0.9, 1.8)

    def patio_rim(j, p, a):
        k = j % 5
        if k == 0:
            flag(p, a, HORDE_RED, 6.2)
        elif k == 1:
            d.tent_hide(p, math.degrees(-a) - 90.0, 1.0)
            d.solid(p[0], p[1], 2.6, 2.6, 2.2)
        elif k == 2:
            d.cargo(p, 4, 1.0)
            d.solid(p[0], p[1], 2.2, 2.2, 1.3)
        elif k == 3:
            d.drum(p, rnd.uniform(0.8, 1.1))
            d.solid(p[0], p[1], 1.8, 1.8, 1.2)
        else:
            rack(p, a)
    rimset("patio", 24, patio_rim, 0.86, 0.93)
    # ---- Ala do Lobo: canis (cercados, jaulas, palha, ossos), rampa (selas e lanças), arena (anéis cinza, crânios) ----
    wolf = CLAN["wolf"]
    x, y = rooms["canis"]["pos"]
    r = rooms["canis"]["r"]
    mottle("canis", [(0.72, 0.6, 0.36), (0.6, 0.5, 0.32)], 16)
    for k in range(4):                                       # cercados em leque no fundo (sem colisão: baixos, o lobo pula)
        a0 = 150.0 + k * 40.0
        if any(abs(math.atan2(math.sin(math.radians(a0 + 20.0) - m), math.cos(math.radians(a0 + 20.0) - m))) < 0.6 for m in h.mouths("canis")):
            continue
        d.fence_run(P((x, y), r * 0.5, a0), P((x, y), r * 0.92, a0), 1.1, color=(0.36, 0.28, 0.22))
        d.fence_run(P((x, y), r * 0.5, a0), P((x, y), r * 0.5, a0 + 34.0), 1.1, color=(0.36, 0.28, 0.22))
        d.bones(P((x, y), r * 0.72, a0 + 18.0), 4, 0.9)

    def kennel_rim(j, p, a):
        if j % 3 == 0:
            act2_dress._cage(d, p, math.degrees(-a) + 90.0)
            d.solid(p[0], p[1], 2.8, 2.8, 2.4)
        elif j % 3 == 1:
            d.hay(p, rnd.uniform(0.9, 1.3))
            d.solid(p[0], p[1], 1.4, 1.4, 1.0)
        else:
            flag(p, a, wolf)
    rimset("canis", 14, kennel_rim)
    mottle("rampa", [(0.4, 0.35, 0.32), (0.52, 0.46, 0.4)], 10)
    rimset("rampa", 12, lambda j, p, a: rack(p, a) if j % 3 == 0 else (flag(p, a, wolf) if j % 3 == 1 else d.spikes(p, math.degrees(-a) + 90.0, 3.0)))
    h.rings("arena_lobo", h.tones("arena_lobo"), (0.32, 0.52, 0.72), w=0.26)
    rimset("arena_lobo", 20, lambda j, p, a: flag(p, a, wolf, 6.0) if j % 4 == 0 else (brazier(p) if j % 4 == 2 else d.bones(p, 6, 1.0)), 0.9, 0.96)
    # ---- Ala da Pedra: caverna (estalagmites, pedregulhos, musgo), poças (musgo que brilha, cogumelos), arena (menires) ----
    stone = CLAN["stone"]
    moss = [(0.28, 0.4, 0.3), (0.42, 0.54, 0.38)]
    moss_arena = [(0.29, 0.385, 0.5), (0.4, 0.53, 0.685)]      # = chão (0.34, 0.45, 0.58) x 0.86 / x 1.18, MESMA proporção de canais: com mais verde que o chão lia sálvia/verde-escuro no jogo
    # (frio como o chão: sob a luz quente lia oliva) arena do chefe: musgo apagado, quase tom do chão (nunca verde de aviso)
    # Rocha da ARENA de pedra: fria e um pouco mais clara que o chão (0.34, 0.45, 0.58); o cinza neutro das grutas lia bege/quente
    # contra o piso frio sob a luz quente (cor no jogo ~ albedo x (0.98, 0.74, 0.62)). Só cor: mesmos sorteios e geometria.
    rock_arena = {"stalag": (0.39, 0.5, 0.64), "menhir": (0.46, 0.57, 0.71), "slab": (0.41, 0.52, 0.66), "slab_top": (0.5, 0.62, 0.75)}
    for name in ("caverna", "pocas", "arena_pedra"):
        mottle(name, moss if name != "arena_pedra" else moss_arena, 14 if name != "arena_pedra" else 20, 1.0, 2.6)
        for (p, a) in h.rim(name, int(rooms[name]["r"] * 1.1), 0.93, 1.03):
            d.stalagmite(p, rnd.uniform(1.4, 3.2), rnd.uniform(0.5, 0.9), rock_arena["stalag"] if name == "arena_pedra" else (0.36, 0.38, 0.36))

    def cave_rim(j, p, a):
        if j % 3 == 0:
            d.outcrop(p, rnd.uniform(1.2, 1.8), 4, (0.4, 0.42, 0.4), top=(0.4, 0.56, 0.4))
            d.solid(p[0], p[1], 2.4, 2.4, 1.6)
        elif j % 3 == 1:
            d.bones(p, 6, 1.0)
        else:
            for _ in range(rnd.randint(2, 4)):
                d.mushroom((p[0] + rnd.uniform(-0.6, 0.6), p[1] + rnd.uniform(-0.6, 0.6)), rnd.uniform(0.8, 1.6), (0.45, 0.95, 0.7))
    rimset("caverna", 14, cave_rim, 0.82, 0.92)
    x, y = rooms["pocas"]["pos"]
    r = rooms["pocas"]["r"]
    glow_moss = d.m("glow_musgo", (0.4, 0.92, 0.72))
    for i in range(9):
        q = P((x, y), rnd.uniform(r * 0.4, r * 0.82), i * 40.0 + rnd.uniform(-10, 10))
        d.blob("pocas", d.m("patch_poca_borda", (0.2, 0.32, 0.28)), q, rnd.uniform(1.0, 1.7), 0.0226, 0.35)
        d.blob("pocas", glow_moss, q, rnd.uniform(0.5, 1.0), 0.0236, 0.3, 9)
    rimset("pocas", 12, cave_rim, 0.84, 0.93)
    h.rings("arena_pedra", h.tones("arena_pedra"), (0.34, 0.56), w=0.26)        # a runa que brilha fica nos menires da borda

    def stone_rim(j, p, a):
        if j % 2 == 0:
            d.standing_stone(p, rnd.uniform(3.0, 4.2), rock_arena["menhir"], rune=(0.45, 0.95, 0.6))
            d.solid(p[0], p[1], 1.2, 1.2, 3.4)
        elif j % 4 == 1:
            flag(p, a, stone, 6.0)
        else:
            d.outcrop(p, 1.4, 3, rock_arena["slab"], top=rock_arena["slab_top"])
            d.solid(p[0], p[1], 2.0, 2.0, 1.4)
    rimset("arena_pedra", 18, stone_rim, 0.9, 0.96)
    # ---- Ala da Forja: fundição (rachaduras de lava, carvão, canal na borda), arena (anel de lava, raios, bigornas) ----
    forge = CLAN["forge"]
    cracks("fundicao", 9)
    x, y = rooms["fundicao"]["pos"]
    r = rooms["fundicao"]["r"]
    coal = d.m("carvao_kh", act2_dress.KH_COAL)
    for (p, a) in h.rim("fundicao", 12, 0.86, 0.95):
        d.pebbles("forja3d", coal, p, 7, 0.9, (0.2, 0.42))
        d.blob("fundicao", lava, p, 0.32, 0.0236, 0.2, 7)
    rimset("fundicao", 10, lambda j, p, a: brazier(p, 1.2, "glow_lava", LAVA) if j % 2 else flag(p, a, forge), 0.9, 0.96)
    x, y = rooms["arena_forja"]["pos"]
    r = rooms["arena_forja"]["r"]
    ms = h.mouths("arena_forja")
    forja_t = h.tones("arena_forja")
    groove = d.m("patch_calha_forja", tuple(c * 0.78 for c in rooms["arena_forja"]["floor"]))
    for k in range(24):                                      # calha em anel junto à borda (pintada: não colide), aberta diante da boca:
        a0 = math.tau * k / 24                               # sulco escuro; brasa fina só em 1 gomo de cada 3 (nunca um anel de lava)
        if any(abs(math.atan2(math.sin(a0 + 0.13 - m), math.cos(a0 + 0.13 - m))) < 0.36 for m in ms):
            continue
        d.arc("arena_forja", groove, (x, y), r * 0.8, a0, a0 + math.tau / 24, 0.9, 0.0222, 0.3, 1.2)
        d.arc("arena_forja", lava if k % 3 == 0 else forja_t[1], (x, y), r * 0.8, a0, a0 + math.tau / 24, 0.2, 0.0232, 0.3, 1.2)
    cracks("arena_forja", 10, 0.18, 0.62, 0.3, ember=False)
    h.rings("arena_forja", forja_t, (0.34,), w=0.26)
    rimset("arena_forja", 18, lambda j, p, a: brazier(p, 1.4, "glow_lava", LAVA) if j % 3 == 0 else (flag(p, a, forge, 6.0) if j % 3 == 1 else d.pebbles("forja3d", coal, p, 8, 1.0, (0.2, 0.46))),
           0.9, 0.96)
    # ---- antecâmara: tapete vermelho até a porta, guardas de pedra (colunas), flâmulas ----
    x, y = rooms["selo"]["pos"]
    r = rooms["selo"]["r"]
    d.rug((x, y - 2.0), 3.2, 11.0, 0.0, (0.42, 0.22, 0.22), (0.5, 0.29, 0.27))
    h.rings("selo", h.tones("selo"), (0.7,), w=0.24)
    rimset("selo", 10, lambda j, p, a: flag(p, a, HORDE_RED, 6.0) if j % 2 else brazier(p))
    # ---- sala do trono: tapete da porta ao estrado, anéis, raios, soquetes dos três estandartes, crânios, braseiros ----
    x, y = THRONE
    r = rooms["trono"]["r"]
    mottle("trono", [(0.38, 0.515, 0.645), (0.475, 0.64, 0.8)], 22, 1.4, 3.2)      # = chão x 0.885 / x 1.1, mesma proporção de canais
    d.rug((x, y + 12.5), 3.6, 15.0, 0.0, (0.42, 0.22, 0.22), (0.5, 0.29, 0.27))       # vinho apagado: faixa vermelha viva lia como aviso em linha
    trono_t = h.tones("trono")
    h.rings("trono", trono_t, (0.26, 0.44, 0.84), w=0.28)
    for j in range(12):
        a = j * 30.0 + 15.0
        d.strip("trono", trono_t[1], [Vector(P((x, y), r * 0.5, a)), Vector(P((x, y), r * 0.6, a + 3)), Vector(P((x, y), r * 0.7, a))],
                0.4, 0.0228, 0.2, taper=True)
    # soquete do Estandarte de Clã: anel de bronze velho sem brilho + pedra furada. Era da cor do clã e aceso (verde/branco/
    # laranja): no chão da luta lia como aviso de golpe. A cor do clã fica no estandarte e nos braseiros da antecâmara.
    cm = d.m("patch_soquete_anel", (0.5, 0.41, 0.34))
    for clan, q in BANNERS.items():
        for k in range(6):
            a0 = math.tau * k / 6
            d.arc("trono", cm, q, 2.4, a0 + 0.08, a0 + math.tau / 6 - 0.08, 0.3, 0.0236, 0.1, 0.7)
        d.blob("trono", d.m("patch_soquete", (0.18, 0.14, 0.15)), q, 1.2, 0.0232, 0.15, 10)
        d.cyl("trono3d", d.m("soquete_pedra", (0.3, 0.28, 0.31)), q, 0.5, 0.42, 0.16, 0.0, 6)
        # lasca do clã na PEDRA (3D, fosca; nada no chão): tampo com o furo + três cunhas em volta, na cor apagada do clã.
        # O `cyl` sorteia mesmo sem jitter: guarda e devolve o estado do Random (dispersão e JSON da zona não mudam).
        st = d.rnd.getstate()
        chip = d.m("soquete_cla_" + CLAN_PT[clan], CLAN_CHIP[clan])
        if clan in CLAN_CHIP_RING:
            d.cyl("trono3d", d.m("soquete_aro_" + CLAN_PT[clan], CLAN_CHIP_RING[clan]), q, CLAN_CHIP_RING_R[0], CLAN_CHIP_RING_R[1], 0.05, 0.13, 6)
        d.cyl("trono3d", chip, q, 0.45, 0.37, 0.08, 0.16, 6)
        d.cyl("trono3d", d.m("soquete_furo", (0.13, 0.11, 0.13)), q, 0.17, 0.15, 0.03, 0.24, 6)
        for k in range(3):
            d.cyl("trono3d", chip, P(q, 0.72, 30.0 + 120.0 * k), 0.25, 0.13, 0.3, 0.0, 4, rot=-(30.0 + 120.0 * k) + 45.0)
        d.rnd.setstate(st)

    def throne_rim(j, p, a):
        if math.hypot(p[0] - DAIS[0], p[1] - DAIS[1]) < 9.0:
            return
        k = j % 4
        if k == 0:
            brazier(p, 1.5, "glow_lava", LAVA)
        elif k == 1:
            flag(p, a, HORDE_RED, 6.6)
        elif k == 2:
            d.totem(p, rnd.uniform(3.6, 4.4), math.degrees(-a) + 90.0)
            d.solid(p[0], p[1], 0.9, 0.9, 3.4)
        else:
            d.bones(p, 7, 1.1)
    rimset("trono", 28, throne_rim, 0.9, 0.96)
    total = d.flush()
    # ---- braseiros dos clãs na antecâmara (um por clã, dos lados e por cima da porta): apagado antes, aceso com o clã caído ----
    spots = {"wolf": (DOOR[0] - 7.0, DOOR[1] + 9.5), "stone": (DOOR[0] + 7.0, DOOR[1] + 9.5), "forge": (DOOR[0], DOOR[1] + 0.2)}
    for i, (clan, q) in enumerate(spots.items()):
        top = clan == "forge"
        if not top:
            z.ob("pillar", q[0], q[1], (1.6, 2.4, 1.6), visible=False)
        for tag, when, lit in (("cla_%s_vivo" % CLAN_PT[clan], {"unless": CLAN_Q[clan]}, False), ("cla_%s_caido" % CLAN_PT[clan], {"if": CLAN_Q[clan]}, True)):
            dd = Dress(z, 631 + i, tag, when)
            y0 = 6.3 if top else 0.0
            dd.cyl("cla", dd.m("cla_base", (0.24, 0.22, 0.25)), q, 0.7, 0.9, 1.2, y0, 8)
            if lit:
                dd.cyl("cla", dd.m("glow_cla_" + CLAN_PT[clan], CLAN[clan]), q, 0.75, 0.0, 1.9, y0 + 1.2, 6)
                # o clarão no chão era uma mancha de 1,6 m na cor do clã (uma verde): lia como aviso. Fica só um anel fino de
                # brasa em tom de chão colado ao pé do braseiro; o de cima da porta não pinta o chão (a chama basta).
                if not top:
                    for k in range(4):
                        a0 = math.tau * k / 4 + 0.4
                        dd.arc("cla", dd.m("patch_cla_brasa", (0.58, 0.42, 0.33)), q, 1.0, a0 + 0.12, a0 + math.tau / 4 - 0.12, 0.2, 0.0238, 0.1, 0.5)
            else:
                dd.cyl("cla", dd.m("cla_cinza", (0.26, 0.24, 0.29)), q, 0.6, 0.3, 0.3, y0 + 1.2, 6)
            dd.cloth("cla", dd.m("pano_cla_" + CLAN_PT[clan], CLAN[clan] if not lit else (0.3, 0.28, 0.3)), (q[0] - 0.5, q[1] + 0.95), 1.0, 1.5, 0.0, 4.6 if top else 0.05)
            total += dd.flush()
    return total


def build(export=False):
    z = Zone(ZONE, seed=35, palette={
        "road": FLOOR, "street": FLOOR, "cliff_rock": BASALT, "cliff_rock_d": (0.21, 0.2, 0.23), "cliff_grass": (0.36, 0.33, 0.36),
        "hill_grass": ROCK_TOP, "wood": (0.33, 0.31, 0.35), "glow_lava": LAVA,
    })
    a90 = math.radians(90.0)
    portal = (0.0, round(z.rim_r(a90) - 7.0, 1))
    z.data["spawn"] = list(ARRIVE)
    z.portal("out_field_kharzun", portal, "field_kharzun", BACK, "Monte Kharzun")
    print("CIDADELA portal de volta", portal, "chegada", ARRIVE)
    rooms = {k: dict(v) for k, v in HALLS.items()}
    rooms["chegada"] = {"pos": ARRIVE, "r": 8}
    for i, (a, b, bend, pack) in enumerate(EDGES):
        (ax, ay), (bx, by) = rooms[a]["pos"], rooms[b]["pos"]
        mid = ((ax + bx) / 2 + (by - ay) * bend, (ay + by) / 2 - (bx - ax) * bend)
        z.road("corredor_%d" % i, [(ax, ay), mid, (bx, by)], w=bd.WALKWAY + 1.0, end_clearing=False)
        if pack:
            z.spawner(pack[0], round(mid[0], 1), round(mid[1], 1), bd.CORRIDOR_PACK_R, pack[1], 30.0)
    z.road("garganta", [ARRIVE, (0.0, (ARRIVE[1] + portal[1]) * 0.5), portal], w=bd.WALKWAY + 1.0, end_clearing=False)
    arenas = {}
    for name, room in rooms.items():
        x, y = room["pos"]
        z.plaza(name, (x, y), room["r"], "road")
        bd._room_dress(z, name, room, rooms, [(a, b) for a, b, _, _ in EDGES])
        z.block((x, y), room["r"] + 4.3)
        for mob, n in room.get("mobs", []):
            ox, oy = room.get("mob_off", (0.0, 0.0))
            z.spawner(mob, x + ox, y + oy, room["r"] - 3.0, n, 30.0)
        if "boss" in room:
            z.spawner(room["boss"], x, y, 2, 1, 300.0, when=room.get("when"))
            arenas[room["boss"]] = {"pos": [x, y], "r": room["r"], "hall": name}
            ms = _mouths(name, rooms)
            for q, o in places._ring((x, y), room["r"] - 1.2, 8, 0.4):
                ang = math.atan2(o.y, o.x)
                if any(abs(math.atan2(math.sin(ang - m), math.cos(ang - m))) < 0.4 for m in ms) or (name == "trono" and (q - Vector(DAIS)).length < 9.0):
                    continue
                z.ob("pillar", q.x, q.y, (1.0, 3.6, 1.0), color=tuple(c * 1.25 for c in BASALT))
    _door(z)
    _throne(z)
    arenas["boss_durgash"].update({"banners": {k: [round(v[0], 1), round(v[1], 1)] for k, v in BANNERS.items()}, "door": list(DOOR), "dais": list(DAIS)})
    z.data["arenas"] = arenas
    # alas: a boca (meio do 1º corredor, onde o teste fecha a ala) e o chefe
    z.data["wings"] = {}
    for a, b, bend, _ in EDGES:
        if a == "patio" and rooms[b].get("wing"):
            (ax, ay), (bx, by) = rooms[a]["pos"], rooms[b]["pos"]
            w = rooms[b]["wing"]
            boss = next(r for r in rooms.values() if r.get("wing") == w and "boss" in r)
            z.data["wings"][w] = {"mouth": [round((ax + bx) / 2 + (by - ay) * bend, 1), round((ay + by) / 2 - (bx - ax) * bend, 1)],
                                  "boss": boss["boss"], "quest": CLAN_Q[w], "halls": [k for k, r in rooms.items() if r.get("wing") == w]}
    z.data["throne"] = {"door": list(DOOR), "quests": list(Q_CLANS), "boss": "boss_durgash"}
    # Ofensiva da Aurora (K2..K4): sobe da chegada, atravessa a barbacã e briga no pátio (apoio, não limpeza)
    pat = rooms["patio"]["pos"]
    z.data["assaults"] = [{"id": "aurora", "from": [ARRIVE[0], ARRIVE[1] - 4.0], "route": [[0.0, 84.0], [0.0, 72.0], [0.0, 58.0]],
                           "target": [pat[0], pat[1] + 6.0], "radius": 12.0}]
    z.data["hangouts"] = [[ARRIVE[0] + dx, ARRIVE[1] - 3.0] for dx in (-4, 0, 4)]
    z.data["town"] = {"center": list(pat), "radius": 0.0, "gates": [[0.0, 58.0]]}
    z.cliffs(snow=False)
    _rock_fill(z)
    total = _dress(z, rooms)
    print("CIDADELA malhas de acabamento", total, "spawners", len(z.data["spawners"]))
    z.cam_game = rooms["patio"]["pos"]
    poi = {"patio": (0, 40), "lobo": rooms["arena_lobo"]["pos"], "pedra": rooms["arena_pedra"]["pos"], "forja": rooms["arena_forja"]["pos"],
           "selo": (0, -14), "trono": (0, -50), "canis": rooms["canis"]["pos"], "pocas": rooms["pocas"]["pos"], "fundicao": rooms["fundicao"]["pos"],
           "barbaca": rooms["barbaca"]["pos"]}[os.environ.get("CITADEL_POI", "trono")]
    out = z.finish(export, poi=poi, ground=FLOOR)
    shots = os.environ.get("CITADEL_SHOTS")                  # pasta ABSOLUTA: uma foto da câmera do jogo em cada salão
    if shots:
        import bpy
        import render_views
        from zone_lib import B
        cam = bpy.data.objects["CAM_poi"]
        for name, room in rooms.items():
            tgt = B(room["pos"][0], room["pos"][1], 0.8)
            cam.location = tgt + Vector((0, -math.cos(math.radians(52)) * 24, math.sin(math.radians(52)) * 24))
            render_views.render(shots, "sala_" + name, cams=("CAM_poi",), size=640)
    return out
