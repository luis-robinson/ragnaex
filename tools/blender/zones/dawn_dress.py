"""Acabamento de conquista do Ato I (faixa da Aurora 20-30; GDD dawn-band-refactor-proposal §6.2, WP6): os três fortes dos
mortos-vivos, a Cidadela do Lich e o Bastião ganham lotes com `tag` (dress.Dress) que o MapDef.conquest_vis mostra/esconde.
Mesmo padrão dos acampamentos do Ato II (act2_dress.fort): só visual, lotes por célula, NADA com colisor (`Dress.solid` não é
chamado; enfeite de conquista nunca colide) e um sorteio próprio por lote — a dispersão, os obstáculos e os spawners da zona
não mudam. O único dado novo do JSON é `stage_tags` (lista {tag, if/unless}, a mesma convenção dos builds do Ato III), que o
catálogo pode ligar em `conquest_vis`.

Tags (o nome do objeto é `Z_<zona>_det_<tag>_<obj|mini|chao|pano|glow_*>_<cx>_<cz>`; o catálogo procura a tag sem o `_det`):
  fort_ghoul    trevas_ghoul  (unless dw_ghoul_boss)  · aurora_ghoul (if dw_ghoul_boss)
  fort_bones    trevas_bones  (unless dw_bones_boss)  · aurora_bones (if dw_bones_boss)
  fort_frost    trevas_frost  (unless dw_frost_boss)  · aurora_frost (if dw_frost_boss)
  lich_citadel  aurora_lich   (if dw_lich)
  field_ruins   enf_cheia_<front> (unless dw_<front>_boss) · enf_vazia_<front> (if dw_<front>_boss) · obra_anel (if dw_lich)

Cada função entra logo antes do `z.finish` do build, depois de tudo que sorteia do `z`.
"""
import math
from mathutils import Vector

import zone_lib
from dress import Dress

AURORA_BLUE = (0.3, 0.42, 0.72)          # as mesmas do act2_dress (a Aurora é uma só nos dois atos)
AURORA_GOLD = (0.96, 0.9, 0.62)
AURORA_POLE = (0.82, 0.68, 0.48)
LINEN = (0.93, 0.9, 0.82)
BONE = (0.9, 0.87, 0.78)

# por forte: cores do lote das trevas e a quest que vira o forte
# banner/pole = estandarte da noite; glow = fogo frio do braseiro; grime = mancha de chão (tom do próprio chão, mais escuro);
# load = cor do entulho que o sapador desmonta
FORT_LOOK = {
    "fort_ghoul": {"quest": "dw_ghoul_boss", "banner": (0.26, 0.3, 0.12), "pole": (0.72, 0.66, 0.52), "glow": (0.7, 1.0, 0.25),
                   "grime": (0.2, 0.17, 0.11), "load": (0.5, 0.26, 0.22)},
    "fort_bones": {"quest": "dw_bones_boss", "banner": (0.12, 0.11, 0.14), "pole": (0.2, 0.19, 0.22), "glow": (0.62, 0.45, 1.0),
                   "grime": (0.25, 0.24, 0.27), "load": (0.15, 0.14, 0.18)},
    "fort_frost": {"quest": "dw_frost_boss", "banner": (0.34, 0.2, 0.48), "pole": (0.16, 0.18, 0.26), "glow": (0.55, 0.45, 1.0),
                   "grime": (0.5, 0.57, 0.68), "load": (0.24, 0.3, 0.46)},
}
FRONTS = ("ghoul", "bones", "frost")
Q_LICH = "dw_lich"


def tags_of(fid):
    """Tags (sem o `_det`) e a condição de cada uma, na ordem em que o catálogo deve aplicá-las."""
    if fid in FORT_LOOK:
        side, q = fid[5:], FORT_LOOK[fid]["quest"]
        return [{"tag": "trevas_" + side, "unless": q}, {"tag": "aurora_" + side, "if": q}]
    if fid == "lich_citadel":
        return [{"tag": "aurora_lich", "if": Q_LICH}]
    if fid == "field_ruins":
        out = []
        for side in FRONTS:
            q = "dw_%s_boss" % side
            out += [{"tag": "enf_cheia_" + side, "unless": q}, {"tag": "enf_vazia_" + side, "if": q}]
        return out + [{"tag": "obra_anel", "if": Q_LICH}]
    return []


def _stage_tags(z, fid):
    z.data["stage_tags"] = tags_of(fid)


def P(c, r, deg):
    return (c[0] + math.cos(math.radians(deg)) * r, c[1] + math.sin(math.radians(deg)) * r)


def O(c, dx, dz):
    return (c[0] + dx, c[1] + dz)


def pick(probe, cands, r, label, quiet=False, **kw):
    """Primeiro candidato livre (Dress.ok do lote-sonda) e reserva o lugar; None se nenhum serve (log)."""
    for q in cands:
        if probe.ok(q[0], q[1], r, **kw):
            probe.reserve(q[0], q[1], r)
            return q
    if not quiet:
        print("DAWN_DRESS %s: sem lugar para %s" % (probe.z.zone, label))
    return None


def pick_near(probe, c, R, prefs, r, label, step=2.0, first=40, **kw):
    """Como `pick`, mas varre o pátio (grade de `step` m até R do centro) na ordem da distância ao ponto preferido."""
    grid = []
    n = int(R / step)
    for i in range(-n, n + 1):
        for j in range(-n, n + 1):
            if (i * step) ** 2 + (j * step) ** 2 <= R * R:
                grid.append((c[0] + i * step, c[1] + j * step))
    for pref in prefs:
        grid.sort(key=lambda q: (q[0] - pref[0]) ** 2 + (q[1] - pref[1]) ** 2)
        q = pick(probe, grid[:first], r, label, quiet=True, **kw)
        if q:
            return q
    print("DAWN_DRESS %s: sem lugar para %s" % (probe.z.zone, label))
    return None


# ------------------------------------------------------------------------------------------------ peças das trevas
def dark_banner(d, q, look, h=4.6, rot=0.0):
    """Estandarte da noite: mastro (osso/ferro negro), pano rasgado e crânio no topo."""
    d.flag(q, look["banner"], h, rot, pole=look["pole"], tatter=True, w=1.2, drop=1.8)
    d.rock("estandarte", d.m("osso", BONE), q, 0.22, h - 0.05, 0.95)
    for s in (-1, 1):                                                       # chifrinhos de osso
        d.cyl("estandarte", d.m("osso", BONE), (q[0] + s * 0.2, q[1]), 0.06, 0.0, 0.42, h + 0.2, 4, 0.0, (0, s * 35.0))


def carrion_pile(d, q):
    """Monte de carniça do Covil (presos carregam carne para cá): carne amontoada, ossos, ganchos de carne, moscas."""
    rnd = d.rnd
    flesh = [d.m("carne_podre", (0.56, 0.24, 0.22)), d.m("carne_escura", (0.36, 0.16, 0.16)), d.m("couro_podre", (0.46, 0.3, 0.22))]
    d.blob("carnica", d.m("patch_carnica", (0.2, 0.16, 0.09)), q, 3.8, 0.0100, 0.3)
    d.blob("carnica", d.m("glow_bile_poca", (0.62, 0.9, 0.2)), (q[0] + 1.9, q[1] - 1.6), 0.9, 0.0108, 0.3)
    for k in range(13):
        a, r = rnd.uniform(0, math.tau), rnd.uniform(0.0, 2.3)
        d.rock("carnica", flesh[k % 3], (q[0] + math.cos(a) * r, q[1] + math.sin(a) * r), rnd.uniform(0.55, 0.95) * (1.45 if r < 1.0 else 1.0), 0.0, 0.62)
    d.bones((q[0] + 1.6, q[1] + 1.2), 5, 1.6)
    hook = (q[0] - 2.4, q[1] + 0.4)                                         # cavalete de ganchos com pedaços pendurados
    w = d.m("gancho_poste", (0.3, 0.24, 0.2))
    iron = d.m("ferro_escuro", (0.24, 0.22, 0.22))
    for s in (-1, 1):
        d.cyl("carnica", w, (hook[0], hook[1] + s * 1.2), 0.08, 0.07, 2.2, 0.0, 5)
    d.box("carnica", w, hook, (0.1, 0.1, 2.6), 0.0, 2.1)
    for k in (-0.8, 0.0, 0.8):
        d.cyl("carnica", iron, (hook[0], hook[1] + k), 0.02, 0.02, 0.4, 1.7, 4)
        d.rock("carnica", flesh[int(k + 1) % 3], (hook[0], hook[1] + k), 0.3, 1.2, 1.2)
    fly = d.m("mosca", (0.08, 0.08, 0.06))
    for k in range(14):
        a, r = rnd.uniform(0, math.tau), rnd.uniform(0.3, 2.0)
        d.box("carnica", fly, (q[0] + math.cos(a) * r, q[1] + math.sin(a) * r), (0.14, 0.1, 0.14), rnd.uniform(0, 90), rnd.uniform(1.3, 2.4))


def armor_stand(d, q, rot):
    """Cavalete com armadura negra (Fortaleza dos Ossos): poste em T, peitoral, ombreiras, elmo com fenda acesa."""
    black = d.m("armadura_negra", (0.15, 0.14, 0.18))
    black2 = d.m("armadura_negra_borda", (0.28, 0.26, 0.32))
    w = d.m("cavalete_negro", (0.22, 0.2, 0.22))
    a = math.radians(rot)
    ux, uz = math.cos(a), -math.sin(a)
    d.cyl("armaria", w, q, 0.07, 0.06, 1.5, 0.0, 5)
    d.box("armaria", w, q, (1.0, 0.08, 0.08), rot, 1.36)
    d.cyl("armaria", black, q, 0.3, 0.4, 0.62, 0.78, 6, rot)
    d.cyl("armaria", black2, q, 0.41, 0.41, 0.08, 1.36, 6, rot, cap=False)
    for s in (-1, 1):
        d.rock("armaria", black, (q[0] + ux * s * 0.44, q[1] + uz * s * 0.44), 0.2, 1.28, 0.9)
        d.cyl("armaria", d.m("osso", BONE), (q[0] + ux * s * 0.5, q[1] + uz * s * 0.5), 0.07, 0.0, 0.3, 1.55, 4, rot, (0, s * 30.0))
    d.cyl("armaria", black, q, 0.19, 0.17, 0.36, 1.5, 7, rot)
    d.cyl("armaria", black2, q, 0.2, 0.04, 0.2, 1.86, 7, rot)
    d.box("armaria", d.m("glow_fenda", (0.62, 0.45, 1.0)), (q[0] + math.sin(a) * -0.18, q[1] + math.cos(a) * -0.18), (0.22, 0.04, 0.03), rot, 1.66)


def black_ice(d, q, n=5, spread=1.6, hmax=2.3):
    """Espinhos de gelo negro (Torre do Mago): cones escuros tortos e uma lasca acesa no meio."""
    rnd = d.rnd
    cols = [d.m("gelo_negro", (0.12, 0.15, 0.24)), d.m("gelo_negro_claro", (0.24, 0.3, 0.46))]
    d.blob("gelo_negro", d.m("patch_gelo_sujo", (0.52, 0.6, 0.72)), q, spread + 0.9, 0.0100, 0.3)
    for k in range(n):
        a, r = rnd.uniform(0, math.tau), rnd.uniform(0.0, spread)
        h = rnd.uniform(0.9, hmax) * (1.0 if r < spread * 0.6 else 0.7)
        d.cyl("gelo_negro", cols[k % 2], (q[0] + math.cos(a) * r, q[1] + math.sin(a) * r), rnd.uniform(0.28, 0.45), 0.0, h, -0.1, 5,
              rnd.uniform(0, 90), (rnd.uniform(-18, 18), rnd.uniform(-18, 18)))
    d.cyl("gelo_negro", d.m("glow_gelo_negro", (0.55, 0.45, 1.0)), q, 0.14, 0.0, 0.9, 0.0, 4, 0.0, (6, -4))


def skull_pole(d, q, h=2.2):
    d.cyl("trofeu", d.m("estaca_caveira", (0.3, 0.24, 0.2)), q, 0.08, 0.06, h, 0.0, 5, 0.0, (d.rnd.uniform(-6, 6), d.rnd.uniform(-6, 6)))
    d.rock("trofeu", d.m("osso", BONE), q, 0.24, h - 0.1, 0.9)


# ------------------------------------------------------------------------------------------------ peças da Aurora
def aurora_banner(d, q, h=4.6, rot=0.0):
    d.flag(q, AURORA_BLUE, h, rot, pole=AURORA_POLE, tatter=False, w=1.2, drop=1.8)
    d.cyl("estandarte", d.m("ouro_aurora", AURORA_GOLD), q, 0.16, 0.0, 0.36, h, 5)
    d.box("estandarte", d.m("ouro_aurora", AURORA_GOLD), q, (0.7, 0.08, 0.08), rot, h - 0.2)


def sapper_bench(d, q, rot, load=BONE):
    """Bancada do sapador: mesa com ferramentas, cavalete com tábua serrada, pilha de tábuas, carroça com o entulho
    desmontado (`load` = cor do que o forte tinha de mau) e caixotes."""
    a = math.radians(rot)
    ux, uz = math.cos(a), -math.sin(a)
    vx, vz = math.sin(a), math.cos(a)
    w = d.m("bancada", (0.6, 0.46, 0.3))
    w2 = d.m("bancada_tampo", (0.74, 0.6, 0.4))
    iron = d.m("ferro", (0.6, 0.62, 0.66))
    for sl in (-1, 1):
        for sd in (-1, 1):
            d.cyl("sapador", w, (q[0] + ux * sl * 0.9 + vx * sd * 0.36, q[1] + uz * sl * 0.9 + vz * sd * 0.36), 0.06, 0.06, 0.86, 0.0, 4)
    d.box("sapador", w2, q, (2.1, 0.1, 0.9), rot, 0.86)
    d.box("sapador", iron, (q[0] + ux * 0.4, q[1] + uz * 0.4), (0.7, 0.04, 0.16), rot + 12.0, 0.96)          # serrote
    d.box("sapador", w, (q[0] - ux * 0.5, q[1] - uz * 0.5), (0.08, 0.08, 0.5), rot + 70.0, 0.96)              # cabo do martelo
    d.box("sapador", iron, (q[0] - ux * 0.5 + vx * 0.22, q[1] - uz * 0.5 + vz * 0.22), (0.24, 0.12, 0.12), rot + 70.0, 0.96)
    s = (q[0] + vx * 1.8, q[1] + vz * 1.8)                                   # cavalete de serrar com tábua
    for sl in (-1, 1):
        d.cyl("sapador", w, (s[0] + ux * sl * 0.5, s[1] + uz * sl * 0.5), 0.05, 0.05, 0.7, 0.0, 4, rot, (0, sl * 14.0))
    d.box("sapador", w2, s, (2.4, 0.08, 0.3), rot, 0.7)
    p = (q[0] - vx * 1.6 + ux * 0.4, q[1] - vz * 1.6 + uz * 0.4)            # tábuas novas empilhadas
    for k in range(4):
        d.box("sapador", w2, (p[0] + vx * (k % 2) * 0.05, p[1] + vz * (k % 2) * 0.05), (2.6, 0.08, 0.32), rot + (k % 2) * 3.0, k * 0.085)
    d.awning((q[0] + vx * 0.4, q[1] + vz * 0.4), 4.2, 3.4, rot, AURORA_BLUE, 2.4, g="sapador", stripes=AURORA_GOLD)
    d.cart((q[0] + ux * 3.4, q[1] + uz * 3.4), rot + 90.0, load=load)
    for k in range(2):
        d.crate((q[0] - ux * 2.2 + vx * (k - 0.5) * 1.1, q[1] - uz * 2.2 + vz * (k - 0.5) * 1.1), 0.8, rot + k * 20.0)


def cot(d, q, rot, wounded=None):
    """Catre de campanha (lona sobre armação); `wounded` = cor da túnica de quem está deitado (atadura com mancha)."""
    w = d.m("catre", (0.5, 0.38, 0.26))
    a = math.radians(rot)
    ux, uz = math.cos(a), -math.sin(a)
    for sl in (-1, 1):
        for sd in (-1, 1):
            d.cyl("enfermaria", w, (q[0] + ux * sl * 0.85 + math.sin(a) * sd * 0.3, q[1] + uz * sl * 0.85 + math.cos(a) * sd * 0.3), 0.04, 0.04, 0.42, 0.0, 4)
    d.box("enfermaria", d.m("lona_catre", LINEN), q, (1.9, 0.08, 0.72), rot, 0.42)
    d.box("enfermaria", d.m("travesseiro", (0.98, 0.96, 0.9)), (q[0] + ux * 0.72, q[1] + uz * 0.72), (0.36, 0.1, 0.5), rot, 0.5)
    if wounded:
        d.cyl("enfermaria", d.m("ferido_%d" % int(wounded[2] * 100), wounded), (q[0] - ux * 0.75, q[1] - uz * 0.75), 0.22, 0.2, 1.3, 0.62, 6, rot, (0, 90))
        d.rock("enfermaria", d.m("pele", (0.88, 0.7, 0.56)), (q[0] + ux * 0.72, q[1] + uz * 0.72), 0.18, 0.5, 1.0)
        d.box("enfermaria", d.m("atadura", (0.98, 0.98, 0.95)), (q[0] - ux * 0.1, q[1] - uz * 0.1), (0.3, 0.46, 0.5), rot, 0.5)
        d.box("enfermaria", d.m("atadura_sangue", (0.7, 0.16, 0.14)), (q[0] - ux * 0.1, q[1] - uz * 0.1), (0.14, 0.04, 0.2), rot, 0.97)


def bedroll(d, q, rot, tunic):
    """Esteira no chão com um ferido (enfermaria cheia)."""
    a = math.radians(rot)
    ux, uz = math.cos(a), -math.sin(a)
    d.box("enfermaria", d.m("esteira", (0.78, 0.7, 0.54)), q, (2.0, 0.06, 0.8), rot, 0.0)
    d.cyl("enfermaria", d.m("ferido_%d" % int(tunic[2] * 100), tunic), (q[0] - ux * 0.8, q[1] - uz * 0.8), 0.22, 0.2, 1.3, 0.26, 6, rot, (0, 90))
    d.rock("enfermaria", d.m("pele", (0.88, 0.7, 0.56)), (q[0] + ux * 0.7, q[1] + uz * 0.7), 0.18, 0.1, 1.0)
    d.box("enfermaria", d.m("atadura_sangue", (0.7, 0.16, 0.14)), (q[0] - ux * 0.2, q[1] - uz * 0.2), (0.16, 0.04, 0.2), rot, 0.48)


def soldier_table(d, q, rot):
    """Mesa de soldado (enfermaria vazia: o portão comemora): mesa de tábua, barril de cerveja, canecas e dois bancos."""
    a = math.radians(rot)
    ux, uz = math.cos(a), -math.sin(a)
    vx, vz = math.sin(a), math.cos(a)
    w = d.m("bancada", (0.6, 0.46, 0.3))
    w2 = d.m("bancada_tampo", (0.74, 0.6, 0.4))
    for sl in (-1, 1):
        for sd in (-1, 1):
            d.cyl("festa", w, (q[0] + ux * sl * 0.6 + vx * sd * 0.3, q[1] + uz * sl * 0.6 + vz * sd * 0.3), 0.05, 0.05, 0.72, 0.0, 4)
    d.box("festa", w2, q, (1.5, 0.08, 0.8), rot, 0.72)
    for k in range(4):
        d.cyl("festa", d.m("caneca", (0.86, 0.8, 0.66)), (q[0] + ux * (k - 1.5) * 0.34, q[1] + uz * (k - 1.5) * 0.34 + (k % 2) * 0.15), 0.07, 0.07, 0.16, 0.8, 6)
    for sd in (-1, 1):
        d.box("festa", w, (q[0] + vx * sd * 0.85, q[1] + vz * sd * 0.85), (1.4, 0.08, 0.32), rot, 0.42)
    d.barrel((q[0] + ux * 1.35, q[1] + uz * 1.35), 1.0)
    d.rug((q[0], q[1]), 2.6, 2.4, rot, AURORA_BLUE, AURORA_GOLD, g="festa")


def infirmary(d, q, rot, n=3, full=True, stripes=AURORA_BLUE):
    """Canto de enfermaria: toldo de lona com listras, catres (com feridos se `full`), bacia, baldes e ataduras; vazia =
    catres sem ninguém e a roupa lavada no varal."""
    a = math.radians(rot)
    ux, uz = math.cos(a), -math.sin(a)
    vx, vz = math.sin(a), math.cos(a)
    d.awning(q, n * 1.15 + 0.6, 3.0, rot, LINEN, 2.3, g="enfermaria", stripes=stripes)
    tunics = [(0.36, 0.42, 0.6), (0.52, 0.46, 0.36), (0.42, 0.5, 0.66)]
    for k in range(n):
        t = (k - (n - 1) * 0.5) * 1.15
        cot(d, (q[0] + ux * t, q[1] + uz * t), rot + 90.0, tunics[k % 3] if full else None)
    b = (q[0] + vx * 2.2 + ux * 1.2, q[1] + vz * 2.2 + uz * 1.2)
    d.cyl("enfermaria", d.m("bacia", (0.7, 0.62, 0.5)), b, 0.4, 0.46, 0.22, 0.0, 8)
    d.cyl("enfermaria", d.m("agua_bacia", (0.62, 0.74, 0.86)), b, 0.4, 0.4, 0.02, 0.2, 8)
    d.cyl("enfermaria", d.m("balde", (0.5, 0.4, 0.3)), (b[0] - ux * 0.8, b[1] - uz * 0.8), 0.2, 0.25, 0.36, 0.0, 7)
    if full:
        for k in range(3):                                                  # ataduras sujas no cesto e no chão
            d.rock("enfermaria", d.m("atadura", (0.98, 0.98, 0.95)), (b[0] - ux * (1.6 + k * 0.4), b[1] - uz * (1.6 + k * 0.4) + 0.2), 0.2, 0.0, 0.6)
        d.rock("enfermaria", d.m("atadura_sangue", (0.7, 0.16, 0.14)), (b[0] - ux * 1.8, b[1] - uz * 1.8), 0.14, 0.12, 0.6)
        mat = (q[0] - vx * 2.3, q[1] - vz * 2.3)                            # maca no chão com mais um
        d.box("enfermaria", d.m("lona_catre", LINEN), mat, (1.9, 0.06, 0.66), rot, 0.0)
        d.cyl("enfermaria", d.m("ferido_60", (0.52, 0.46, 0.36)), (mat[0] - ux * 0.75, mat[1] - uz * 0.75), 0.22, 0.2, 1.3, 0.24, 6, rot - 90.0, (0, 90))
        d.rock("enfermaria", d.m("pele", (0.88, 0.7, 0.56)), (mat[0] + ux * 0.72, mat[1] + uz * 0.72), 0.18, 0.08, 1.0)
    else:
        for k in range(2):                                                  # catres sobrando, dobrados e empilhados
            d.box("enfermaria", d.m("catre", (0.5, 0.38, 0.26)), (q[0] - vx * 2.4, q[1] - vz * 2.4), (1.9, 0.12, 0.3), rot + k * 4.0, k * 0.13)
        p0 = (q[0] - vx * 2.4 - ux * 2.4, q[1] - vz * 2.4 - uz * 2.4)
        p1 = (q[0] - vx * 2.4 + ux * 2.4, q[1] - vz * 2.4 + uz * 2.4)
        d.laundry(p0, p1, 1.8, g="enfermaria", cols=(LINEN, (0.98, 0.98, 0.95), AURORA_BLUE, LINEN))


# ------------------------------------------------------------------------------------------------ fortes do Ato I
def fort(z, fid, c, R, gate_pt):
    """Lote das trevas (some na retomada) e lote da Aurora (aparece) num forte do Ato I. Sem colisor. Os dois dividem os
    mesmos pontos: estandartes em anel por dentro do muro, braseiros do portão, três "lugares do mal" que viram lugares de
    trabalho da Aurora (bancada do sapador, suprimentos, pátio de treino) e, só da Aurora, enfermaria e fogo de cozinha."""
    look = FORT_LOOK[fid]
    side = fid[5:]
    dk = Dress(z, 601 + len(fid) * 5, tag="trevas_%s_det" % side)
    au = Dress(z, 613 + len(fid) * 5, tag="aurora_%s_det" % side)
    probe = Dress(z, 631)                       # só sonda (ok/reserve): não desenha
    if fid == "fort_frost":                     # picos de gelo do marco não têm colisor no JSON: reservados à mão
        for i in range(6):
            a = math.tau * i / 6
            probe.reserve(c[0] + math.cos(a) * 12, c[1] + 4 + math.sin(a) * 12, 1.6)
    # ---- estandartes: anel por dentro do muro (o portão fica em +z, 90 graus) e um par por fora do portão ----
    flags = []
    for off in (24.0, -24.0, 55.0, -55.0, 95.0, -95.0, 135.0, -135.0, 180.0):
        deg = 90.0 + off
        for rr in (R - 4.5, R - 6.5, R - 8.5):
            q = P(c, rr, deg)
            if probe.ok(q[0], q[1], 0.5, road=0.4):
                probe.reserve(q[0], q[1], 1.0)
                flags.append((q, -deg))
                break
    for s in (-1, 1):
        q = (gate_pt[0] + s * 7.0, gate_pt[1] + 4.0)
        if probe.ok(q[0], q[1], 0.5, road=0.4):
            probe.reserve(q[0], q[1], 1.0)
            flags.append((q, 0.0 if s < 0 else 180.0))
    for q, rot in flags:
        dark_banner(dk, q, look, 4.6, rot)
        aurora_banner(au, q, 4.6, rot)
    # ---- braseiros por dentro do portão: fogo frio da noite -> fogo quente da Aurora ----
    nb = 0
    for s in (-1, 1):
        q = pick(probe, [O(c, s * 9.0, R - 3.5), O(c, s * 8.0, R - 6.0), O(c, s * 10.5, R - 5.0), O(c, s * 4.0, R - 7.5)], 0.7,
                 "braseiro do portão", road=0.3)
        if q:
            dk.brazier(q, 1.1, fire="glow_" + side + "_noite", color=look["glow"])
            au.brazier(q, 1.1)
            nb += 1
    # ---- chão: sujeira da noite / esteiras da Aurora ----
    grime = dk.m("patch_" + side + "_sujo", look["grime"])
    for k in range(12):
        q = P(c, dk.rnd.uniform(4.0, R - 5.0), dk.rnd.uniform(0, 360))
        if probe.ok(q[0], q[1], 1.5, road=0.3):
            dk.blob("sujeira", grime, q, dk.rnd.uniform(2.2, 4.0), 0.0092, 0.35)
    # ---- três lugares do mal -> três lugares de trabalho ----
    prefs = [[O(c, -9.0, 12.0)], [O(c, 1.0, 13.0), O(c, 12.0, -16.0)], [O(c, -14.0, -9.0), O(c, -18.0, 4.0)]]
    evil = []
    for k, pr in enumerate(prefs):
        q = pick_near(probe, c, R - 5.0, pr, 2.8, "lugar %d" % k)
        if q:
            evil.append(q)
    for k, q in enumerate(evil):
        if fid == "fort_ghoul":
            carrion_pile(dk, q)
        elif fid == "fort_bones":
            for j in range(4):                                              # fileira de armaduras negras
                armor_stand(dk, (q[0] - 2.1 + j * 1.4, q[1] - 0.6 + (j % 2) * 0.3), 0.0)
            dk.weapon_rack((q[0], q[1] + 1.8), 0.0)
            dk.bones((q[0] + 2.4, q[1] + 1.6), 4, 1.0)
        else:
            black_ice(dk, q, 9, 2.2, 2.9)
        if k == 0:
            sapper_bench(au, q, 20.0, look["load"])
        elif k == 1:
            au.awning(q, 4.4, 3.6, 15.0, (0.86, 0.8, 0.64), 2.4, g="suprimento", stripes=AURORA_BLUE)
            au.cargo(q, 7, 1.8)
            au.cargo((q[0] + 2.2, q[1] - 1.0), 4, 1.0)
            au.rug((q[0] - 1.5, q[1] + 1.5), 2.2, 1.6, 15.0, AURORA_BLUE, AURORA_GOLD, g="suprimento")
        else:
            au.drill_post((q[0] - 1.2, q[1]), 0.0, shield=AURORA_BLUE, boss=AURORA_GOLD, crest=AURORA_GOLD)
            au.drill_post((q[0] + 1.2, q[1] + 0.4), 20.0, shield=(0.88, 0.84, 0.7), boss=AURORA_GOLD, crest=AURORA_BLUE)
            au.weapon_rack((q[0], q[1] + 2.0), 0.0)
    # troféus de crânio (só da noite) junto do portão e no pátio
    for q in ((gate_pt[0] - 4.5, gate_pt[1] + 7.0), (gate_pt[0] + 4.5, gate_pt[1] + 7.0), O(c, -6.0, 4.0), O(c, 6.0, -2.0), O(c, -3.0, 20.0)):
        if probe.ok(q[0], q[1], 0.4, road=0.3):
            probe.reserve(q[0], q[1], 0.6)
            skull_pole(dk, q, 2.4)
    # ---- Aurora: enfermaria e fogo de cozinha em lugares próprios ----
    inf = pick_near(probe, c, R - 5.0, [O(c, -17.0, 12.0), O(c, 6.0, 18.0)], 2.8, "enfermaria")
    fire = pick_near(probe, c, R - 5.0, [O(c, 6.0, 6.0), O(c, 14.0, -4.0)], 2.0, "fogo de cozinha")
    if inf:
        au.rug(inf, 5.6, 3.6, 90.0, (0.86, 0.8, 0.64), LINEN, g="enfermaria")
        infirmary(au, inf, 90.0, 3, True)
    if fire:
        # lareira de pedra por baixo: a cinza do cookfire (8,2 mm) cairia no plano do pátio calçado da Torre (8,2 mm)
        au.slab("cozinha", au.m("lareira", (0.5, 0.47, 0.45)), au.m("lareira_topo", (0.42, 0.4, 0.4)), fire, 1.25, 0.05)
        au.cookfire(fire, 1.0, 30.0)
        au.barrel((fire[0] + 2.2, fire[1] - 0.6), 1.0)
        au.sack((fire[0] + 2.0, fire[1] + 0.6), 1.1)
    print("DAWN_DRESS %s: estandartes %d, braseiros %d, lugares %s, enfermaria %s, fogo %s" % (fid, len(flags), nb, evil, inf, fire))
    _stage_tags(z, fid)
    return dk.flush() + au.flush()


def citadel(z, c, R, gate_pt, throne, city_gate=(0.0, 73.0)):
    """Cidadela do Lich depois do dw_lich: posto da Aurora (estandartes nos portões e nas colunas do trono, velas em volta
    do estrado, lugar da carroça de suprimento do Intendente na praça). Um lote só, `if dw_lich`, sem colisor."""
    au = Dress(z, 641, tag="aurora_lich_det")
    probe = Dress(z, 643)                         # só sonda (ok/reserve): não desenha
    flags = []
    for s in (-1, 1):
        for q in ((gate_pt[0] + s * 8.6, gate_pt[1] + 3.0), (gate_pt[0] + s * 9.0, gate_pt[1] - 3.5),
                  (city_gate[0] + s * 11.0, city_gate[1] - 1.0), (city_gate[0] + s * 11.5, city_gate[1] + 3.0)):
            if probe.ok(q[0], q[1], 0.5, road=0.4):
                probe.reserve(q[0], q[1], 0.8)
                flags.append((q, 0.0 if s < 0 else 180.0))
    for q, rot in flags:
        aurora_banner(au, q, 5.0, rot)
    # colunas do trono: pano azul e dourado pendurado por fora de cada uma (a chama de almas em cima continua: só some no jogo
    # se o catálogo quiser; aqui é acréscimo)
    for i in range(8):
        a = math.tau * i / 8
        p = (throne[0] + math.cos(a) * 9.85, throne[1] + math.sin(a) * 9.85)
        rot = zone_lib.along(-math.sin(a), math.cos(a))
        au.cloth("coluna", au.m("pano_col_azul", AURORA_BLUE), p, 1.1, 2.6, rot, 3.2, 0.0, "swallow", au.m("pano_col_ouro", AURORA_GOLD))
    # velas no estrado (em trios, fora da boca virada para o portão) e pano dourado no trono
    wax = au.m("vela", (0.95, 0.92, 0.82))
    flame = au.m("glow_vela", (1.0, 0.82, 0.42))
    k = 0
    for i in range(14):
        a = math.tau * (i + 0.5) / 14
        if abs(((a - math.pi / 2) + math.pi) % math.tau - math.pi) < 0.5:
            continue
        for j in range(3):
            aa = a + (j - 1) * 0.06
            rr = 6.35 + (j % 2) * 0.35
            p = (throne[0] + math.cos(aa) * rr, throne[1] + math.sin(aa) * rr)
            h = 0.45 + ((i + j) % 3) * 0.2
            au.cyl("velas", wax, p, 0.12, 0.12, h, 0.0, 6)
            au.cyl("velas", flame, p, 0.1, 0.0, 0.26, h + 0.02, 4)
            k += 1
    au.box("trono", au.m("pano_trono", LINEN), (throne[0], throne[1] - 1.0), (2.0, 0.06, 2.2), 0.0, 0.92, (-12, 0))
    au.box("trono", au.m("pano_trono_ouro", AURORA_GOLD), (throne[0], throne[1] - 0.2), (0.5, 0.06, 2.0), 0.0, 0.95, (-12, 0))
    for i in range(4):                                                      # estandartes da Aurora no estrado, entre as colunas
        a = math.tau * (i + 0.5) / 4 + math.pi / 8
        aurora_banner(au, (throne[0] + math.cos(a) * 7.6, throne[1] + math.sin(a) * 7.6), 5.2, -math.degrees(a))
    for i in range(10):                                                     # oferendas: flores brancas e douradas junto às velas
        a = math.tau * (i + 0.25) / 10
        if abs(((a - math.pi / 2) + math.pi) % math.tau - math.pi) < 0.5:
            continue
        p = (throne[0] + math.cos(a) * 7.0, throne[1] + math.sin(a) * 7.0)
        au.rock("velas", au.m("flor_branca", (0.97, 0.96, 0.9)) if i % 2 else au.m("flor_ouro", AURORA_GOLD), p, 0.22, 0.0, 0.6)
    # carroça de suprimento do Intendente (lugar para a Clara) com carga em volta
    q = pick(probe, [O(c, -14.0, 18.0), O(c, -18.0, 14.0), O(c, 14.0, 20.0), O(c, -20.0, -2.0)], 3.0, "carroça de suprimento")
    if q:
        au.cart(q, 70.0, load=AURORA_BLUE)
        au.awning((q[0] + 2.4, q[1] - 1.2), 4.0, 3.4, 70.0, (0.86, 0.8, 0.64), 2.4, g="suprimento", stripes=AURORA_BLUE)
        au.cargo((q[0] + 2.4, q[1] - 1.2), 7, 1.6)
        aurora_banner(au, (q[0] - 2.2, q[1] + 1.8), 4.0, 90.0)
    f = pick(probe, [O(c, -6.0, 16.0), O(c, 4.0, 18.0), O(c, -20.0, 6.0)], 2.2, "fogo da cidadela")
    if f:
        au.cookfire(f, 1.0, 20.0)
    print("DAWN_DRESS lich_citadel: estandartes %d, velas %d, carroça %s, fogo %s" % (len(flags), k, q, f))
    _stage_tags(z, "lich_citadel")
    return au.flush()


# ------------------------------------------------------------------------------------------------ Bastião
def bastion(z, fronts, ring_r):
    """Bastião: enfermaria por portão de front (cheia enquanto o forte daquele lado resiste; vazia depois) e, depois do
    dw_lich, obras no anel (andaimes por fora da muralha, pedra cortada, cocho de argamassa). Sem colisor."""
    H = lambda r, a: (math.cos(math.radians(a)) * r, math.sin(math.radians(a)) * r)
    probe = Dress(z, 651)
    fires = {"ghoul": (-40.0, 6.0), "bones": (6.0, -40.0), "frost": (-6.0, 40.0)}     # build_field_ruins.SIEGE_FIRES (Chamas)
    total = 0
    for side in FRONTS:
        g = fronts[side]["deg"]
        lat = Vector((-math.sin(math.radians(g)), math.cos(math.radians(g))))
        fire = Vector(fires[side])
        cands = []                     # pátio de dentro do portão, ao lado da avenida (entre os dois anéis de rua)
        for k in range(23):
            r = 33.0 + k * 0.5
            for j in range(16):
                tt = 4.5 + j * 0.5
                for sgn in (1, -1):
                    p = Vector(H(r, g)) + lat * sgn * tt
                    # o lado longe das Chamas primeiro, depois perto de r 39 e da avenida
                    cands.append(((p.x, p.y), (-round((p - fire).length / 6.0), abs(r - 39.0) + abs(tt - 7.0))))
        cands.sort(key=lambda e: e[1])
        q, n = None, 3
        for rr, n in ((2.6, 3), (2.1, 2), (1.8, 2)):                         # portão apertado (oeste: casas a 10 graus) = 2 catres
            q = pick(probe, [e[0] for e in cands], rr, "enfermaria %s" % side, quiet=True, road=0.6)
            if q:
                break
        if not q:
            print("DAWN_DRESS field_ruins: sem lugar para enfermaria %s" % side)
            continue
        rot = zone_lib.along(-math.sin(math.radians(g)), math.cos(math.radians(g)))    # catres em fila de lado (ao longo do muro)
        full = Dress(z, 661 + len(side), tag="enf_cheia_%s_det" % side)
        empty = Dress(z, 671 + len(side), tag="enf_vazia_%s_det" % side)
        infirmary(full, q, rot, n, True)
        infirmary(empty, q, rot, n, False)
        # em volta: cheia = mais feridos em esteiras no chão e a flâmula branca da enfermaria; vazia = mesa de soldado
        # (barril, canecas, bancos: o portão comemora) e as esteiras enroladas
        ax = Vector(q).dot(Vector(H(1.0, g)))                                # ponto da avenida na altura da enfermaria
        mid = ((q[0] + H(ax, g)[0]) * 0.5, (q[1] + H(ax, g)[1]) * 0.5)         # as esteiras vão para o lado aberto (avenida)
        ex = [pick_near(probe, mid, 7.0, [mid], 1.1, "esteira %s" % side, step=1.0, first=160, road=0.4) for _ in range(2)]
        hp = pick_near(probe, q, 6.0, [q], 0.4, "flamula %s" % side, step=1.0, first=120, road=0.4)
        for k, e in enumerate(ex):
            if not e:
                continue
            bedroll(full, e, rot + 90.0 * k, (0.42, 0.5, 0.66) if k else (0.52, 0.46, 0.36))
            if k == 0:
                soldier_table(empty, e, rot)
            else:
                for j in range(3):
                    empty.cyl("enfermaria", empty.m("esteira_rolo", (0.72, 0.64, 0.5)), (e[0] + j * 0.1, e[1] + j * 0.05), 0.2, 0.2, 0.9, 0.2 + j * 0.36, 6, rot + j * 8.0, (0, 90))
        if hp:
            full.flag(hp, (0.96, 0.95, 0.9), 3.4, rot, pole=AURORA_POLE, tatter=False, w=0.9, drop=1.3)
            full.cyl("enfermaria", full.m("ouro_aurora", AURORA_GOLD), hp, 0.12, 0.0, 0.3, 3.4, 5)
        print("DAWN_DRESS field_ruins: enfermaria %s em (%.1f, %.1f)" % (side, q[0], q[1]))
        total += full.flush() + empty.flush()
    # ---- obras no anel (depois do Lich): por fora da muralha, entre as torres, longe de estrada e portão ----
    ob = Dress(z, 681, tag="obra_anel_det")
    n = 0
    roads = list(z.road_polys.values())
    degs = []
    for deg in (30.0, 60.0, 120.0, 150.0, 210.0, 240.0, 300.0, 330.0):
        if n >= 6:
            break
        q = H(ring_r + 2.9, deg)
        # o colisor da muralha (caixas com raio de envoltória) recusaria tudo encostado nela: aqui só estrada, portal e
        # o lugar da pedra cortada (mais para fora) passam pelo ok()
        if any(zone_lib.poly_dist(Vector(q), poly) < zone_lib.ROAD_W * 0.5 + 4.5 for poly in roads):
            continue
        if not probe.ok(*H(ring_r + 5.6, deg), 1.4, road=1.5):
            continue
        probe.reserve(q[0], q[1], 3.2)
        rot = -90.0 - deg                                                   # ao longo do muro, pano do lado da pedra
        ob.scaffold(q, rot, 5.0, 4.0, g="obra", cloth=AURORA_BLUE)
        for s in (-1, 1):                                                   # panos da Aurora na face de fora do muro, dos lados
            wq = H(ring_r + 1.0, deg + s * 5.5)
            ob.cloth("obra", ob.m("pano_obra_azul", AURORA_BLUE), wq, 1.3, 2.2, zone_lib.along(-math.sin(math.radians(deg)), math.cos(math.radians(deg))),
                     1.9, 0.0, "swallow", ob.m("pano_obra_ouro", AURORA_GOLD))
        out = H(ring_r + 5.6, deg + 3.0)
        stone = ob.m("pedra_cortada", (0.86, 0.84, 0.78))
        for k in range(5):                                                  # pilha de pedra cortada
            ob.box("obra", stone, (out[0] + (k % 3) * 0.75 - 0.75, out[1] + (k // 3) * 0.7), (0.7, 0.45, 0.5), -deg + k * 4.0, (k // 3) * 0.45)
        tr = H(ring_r + 5.2, deg - 4.0)
        ob.box("obra", ob.m("cocho", (0.5, 0.38, 0.26)), tr, (1.4, 0.32, 0.7), -deg, 0.0)
        ob.box("obra", ob.m("argamassa", (0.9, 0.88, 0.84)), tr, (1.25, 0.02, 0.58), -deg, 0.31)
        n += 1
        degs.append(deg)
    print("DAWN_DRESS field_ruins: obras no anel %d %s" % (n, degs))
    _stage_tags(z, "field_ruins")
    return total + ob.flush()
