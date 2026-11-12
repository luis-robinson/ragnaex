"""Mar e costa (Ato II): o mar é um círculo enorme com o centro fora do vale. Na sim é um `lake` (sólido, contorno
liso pela colisão circular); no visual, areia, espuma, água turquesa e água funda. O anel de penhascos continua
fechando o vale por baixo (colisores `cliff`), mas a malha da montanha afunda onde o mar passa e os patamares/pedras
de lá somem: de cima a borda vira praia. Também: navio (casco + mastros + velas), cais de tábuas e o farol.
"""
import math
import bpy
from mathutils import Vector
from zone_lib import B, box, cyl, cone, disc, mat

SAND = (0.92, 0.85, 0.62)
FOAM = (0.95, 0.98, 1.0)
SEA = (0.32, 0.74, 0.8)
DEEP = (0.2, 0.52, 0.66)


def emissive(name, color, strength=4.0):
    m = mat(name, color)
    bsdf = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    for key in ("Emission Color", "Emission"):
        if key in bsdf.inputs:
            bsdf.inputs[key].default_value = (*color, 1.0)
            break
    if "Emission Strength" in bsdf.inputs:
        bsdf.inputs["Emission Strength"].default_value = strength
    return m


def sea(z, c, r, beach=14.0, name="mar"):
    """Desenha o mar (centro `c`, raio `r`) e registra a água sólida. Chame antes de estradas/lugares (bloqueia)."""
    disc(z.coll, z.P + "areia_" + name, c, r + beach, 0.004, mat("patch_areia_" + name, SAND), 240, 0.015, 3)
    disc(z.coll, z.P + "espuma_" + name, c, r + 1.3, 0.022, mat("espuma_" + name, FOAM), 240, 0.004, 5)
    disc(z.coll, z.P + "agua_" + name, c, r, 0.03, mat("agua_" + name, SEA), 240, 0.0, 7)
    if r > 30.0:
        disc(z.coll, z.P + "agua_funda_" + name, c, r - 22.0, 0.034, mat("agua_funda_" + name, DEEP), 200, 0.03, 9)
    else:                                  # enseada pequena: o fundo é só o miolo
        disc(z.coll, z.P + "agua_funda_" + name, c, r * 0.55, 0.034, mat("agua_funda_" + name, DEEP), 48, 0.05, 9)
    z.data["water"].append({"kind": "lake", "pos": [round(c[0], 2), round(c[1], 2)], "r": r, "shore": beach})
    z.block(c, r + 3.0)
    z.seas = getattr(z, "seas", []) + [(Vector(c), r)]


def sink_cliffs(z, margin=16.0):
    """Depois de z.cliffs(): afunda a montanha dentro do mar e tira árvores/pedras de patamar de lá."""
    seas = getattr(z, "seas", [])
    if not seas:
        return
    o = bpy.data.objects.get(z.P + "penhascos")
    if o is not None:
        for v in o.data.vertices:
            p = Vector((v.co.x, -v.co.y))
            k = 1.0
            for c, r in seas:
                d = (p - c).length - r
                k = min(k, max(0.0, min(1.0, (d - margin) / 18.0)))
            if k < 1.0:
                v.co.z = v.co.z * k - (0.6 if k <= 0.0 else 0.0)
    inside = lambda q: any((Vector(q) - c).length < r + margin * 0.5 for c, r in seas)
    z.data["obstacles"] = [ob for ob in z.data["obstacles"]
                           if not (ob.get("visible", True) and ob["kind"] in ("rock", "dead_tree", "pine", "tree") and inside(ob["pos"]))]


def ship(z, name, c, rot, L=16.0, hull=(0.42, 0.28, 0.18), sail=(0.95, 0.92, 0.82), wreck=False, tag=""):
    """Navio low-poly: casco (3 caixas afinando), convés, 2 mastros com velas. `wreck` = inclinado e sem velas."""
    P = z.P + tag + name
    a = math.radians(rot)
    f = Vector((math.cos(a), math.sin(a)))
    hm = mat("casco_" + name, hull)
    dark = mat("casco_esc_" + name, tuple(x * 0.7 for x in hull))
    sm = mat("vela_" + name, sail)
    rot_d = math.degrees(-a)
    y0 = -0.5 if wreck else 0.0
    box(z.coll, P + "_casco", c, (L, 2.4, L * 0.28), rot_d, hm, y0)
    for s in (-1, 1):
        q = Vector(c) + f * s * L * 0.5
        box(z.coll, P + "_ponta_%d" % s, tuple(q), (L * 0.2, 2.2, L * 0.18), rot_d, hm, y0 + 0.1)
    box(z.coll, P + "_conves", c, (L * 0.92, 0.2, L * 0.24), rot_d, dark, y0 + 2.4)
    box(z.coll, P + "_popa", tuple(Vector(c) - f * L * 0.38), (L * 0.2, 1.6, L * 0.26), rot_d, dark, y0 + 2.5)
    masts = [0.18, -0.12] if not wreck else [0.1]
    for i, t in enumerate(masts):
        q = Vector(c) + f * L * t
        h = (L * 0.75 if i == 0 else L * 0.6) * (0.55 if wreck else 1.0)
        cyl(z.coll, P + "_mastro_%d" % i, tuple(q), 0.22, 0.16, h, dark, y0 + 2.4, 6)
        if not wreck:
            box(z.coll, P + "_vela_%d" % i, tuple(q), (0.25, h * 0.55, L * 0.26), rot_d, sm, y0 + 2.4 + h * 0.3)


def pier(z, name, a, b, w=3.2, wood=(0.55, 0.4, 0.26)):
    """Cais de tábuas de `a` a `b` (sobre a água; só visual) com estacas."""
    a, b = Vector(a), Vector(b)
    t = b - a
    L = t.length
    rot = math.degrees(-math.atan2(t.y, t.x))
    m = mat("tabua_" + name, wood)
    md = mat("estaca_" + name, tuple(x * 0.7 for x in wood))
    mid = (a + b) * 0.5
    box(z.coll, z.P + "cais_" + name, tuple(mid), (L, 0.25, w), rot, m, 0.45)
    n = Vector((-t.y, t.x)).normalized()
    k = max(2, int(L / 3.0))
    for i in range(k + 1):
        q = a + t * (i / k)
        for s in (-1, 1):
            cyl(z.coll, z.P + "cais_%s_estaca_%d_%d" % (name, i, s), tuple(q + n * s * (w * 0.5)), 0.2, 0.18, 1.4, md, -0.3, 6)


def lighthouse(z, c, tag="farol", H=16.0):
    """Farol branco com faixas vermelhas sobre um rochedo. Lanterna em duas versões: `<tag>_apagado` (vidro escuro) e
    `<tag>_luz` (vidro aceso + halo) — o jogo mostra uma ou outra pelo MapDef.conquest_vis."""
    top = z.hill(tag + "_rochedo", c, 9.0, 2, rock="cliff_rock", top="hill_grass", step=2.2)
    white = mat("farol_branco", (0.96, 0.95, 0.92))
    red = mat("farol_vermelho", (0.82, 0.22, 0.2))
    cyl(z.coll, z.P + tag + "_torre", c, 3.0, 2.0, H, white, top, 14)
    for i in range(3):
        y = top + H * (0.2 + 0.27 * i)
        cyl(z.coll, z.P + tag + "_faixa_%d" % i, c, 2.75 - 0.2 * i, 2.62 - 0.2 * i, H * 0.1, red, y, 14)
    cyl(z.coll, z.P + tag + "_varanda", c, 2.7, 2.7, 0.35, red, top + H, 14)
    cyl(z.coll, z.P + tag + "_apagado_vidro", c, 1.6, 1.6, 2.2, mat("vidro_escuro", (0.18, 0.22, 0.28)), top + H + 0.35, 10)
    cyl(z.coll, z.P + tag + "_luz_vidro", c, 1.62, 1.62, 2.2, emissive("farol_aceso", (1.0, 0.86, 0.45)), top + H + 0.35, 10)
    disc(z.coll, z.P + tag + "_luz_halo", c, 3.6, top + H + 1.4, emissive("farol_halo", (1.0, 0.95, 0.7), 2.0), 24)
    cone(z.coll, z.P + tag + "_teto", c, 2.2, 2.4, red, top + H + 2.55, 12)
    return top + H
