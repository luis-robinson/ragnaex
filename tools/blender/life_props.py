"""Vida dos mapas: o que um NPC carrega ou puxa (só apresentação, EntityView._attach_carry; `carry` em MapsCatalog.LIVING_NPCS).
Tamanho real (não é esticado pelo jogo): 1 u = 1 m, origem = onde o boneco pisa, frente do boneco = -Y.

    carry_crate / carry_sack / carry_log / carry_rock   carga no ombro direito (-X), já na altura do ombro
    cart                                                carroça de caravana puxada pelos varais, atrás do boneco (+Y)
"""
import math

from mathutils import Vector

import chibi_kit as ck

SHOULDER = Vector((-0.4, 0.02, 1.02))        # em cima do ombro direito, encostado na cabeça


def _B(name, size, center, mat, bevel=0.02):
    o = ck.box(name, size, (0, 0, 0), mat, bevel)
    for v in o.data.vertices:
        v.co += Vector(center)
    return o


def carry_crate(m):
    c = SHOULDER + Vector((0, 0, 0.2))
    parts = [_B("box", (0.46, 0.56, 0.4), c, m["wood"], 0.02), _B("lid", (0.49, 0.59, 0.05), c + Vector((0, 0, 0.2)), m["wood_l"], 0.01)]
    for sy in (-1, 1):
        parts.append(_B("band%d" % sy, (0.5, 0.06, 0.42), c + Vector((0, sy * 0.2, 0)), m["wood_d"], 0.01))
    parts.append(ck.tube("rope", c + Vector((-0.24, 0, -0.2)), c + Vector((-0.24, 0, 0.22)), 0.02, 0.02, m["cloth_w"], 4))
    return parts


def carry_sack(m):
    c = SHOULDER + Vector((0, 0.05, 0.16))
    sack = ck.mat("p_sack", (0.78, 0.68, 0.48), 0.9)
    parts = [ck.ball("sack", 0.26, c, sack, (0.95, 1.5, 0.8)),
             ck.ball("sack_low", 0.22, c + Vector((0, 0.34, -0.1)), sack, (0.95, 1.0, 0.9)),
             ck.tube("neck", c + Vector((0, -0.36, 0.02)), c + Vector((0, -0.5, 0.08)), 0.07, 0.11, sack, 6),
             ck.tube("tie", c + Vector((0, -0.37, 0.02)), c + Vector((0, -0.4, 0.03)), 0.085, 0.085, m["wood_d"], 6)]
    return parts


def carry_log(m):
    c = SHOULDER + Vector((0.03, 0.1, 0.1))
    parts = [ck.tube("stake", c + Vector((0, 0.95, -0.1)), c + Vector((0, -0.85, 0.12)), 0.1, 0.09, m["wood"], 7),
             ck.tube("tip", c + Vector((0, -0.85, 0.12)), c + Vector((0, -1.12, 0.15)), 0.09, 0.01, m["wood_l"], 7),
             ck.tube("cut", c + Vector((0, 0.95, -0.1)), c + Vector((0, 0.97, -0.1)), 0.085, 0.08, m["wood_l"], 7)]
    return parts


def carry_rock(m):
    import prop_kit
    c = SHOULDER + Vector((0, 0.02, 0.2))
    return [prop_kit.lumpy("rock", 0.25, c, m["stone_d"], (1.0, 1.15, 0.85), 0.16, 5, 2),
            ck.tube("strap", c + Vector((-0.27, 0, -0.1)), c + Vector((0.2, 0, -0.22)), 0.03, 0.03, m["wood_d"], 4)]


def cart(m):
    """Carroça de duas rodas da caravana: caixa de tábuas, toldo de lona em arcos, carga e dois varais até as mãos."""
    canvas = ck.mat("p_canvas", (0.9, 0.84, 0.68), 0.9)
    y0, y1 = 0.95, 2.75                     # a caixa fica atrás do boneco
    yc = (y0 + y1) * 0.5
    parts = [_B("bed", (1.2, y1 - y0, 0.1), (0, yc, 0.62), m["wood"], 0.02)]
    for sx in (-1, 1):
        parts.append(_B("side%d" % sx, (0.07, y1 - y0, 0.42), (sx * 0.6, yc, 0.86), m["wood"], 0.02))
        parts.append(_B("rail%d" % sx, (0.09, y1 - y0 + 0.06, 0.07), (sx * 0.6, yc, 1.08), m["wood_d"], 0.01))
        # roda: aro, cubo e raios
        wc = Vector((sx * 0.72, yc + 0.1, 0.52))
        parts.append(ck.tube("wheel%d" % sx, wc - Vector((0.045, 0, 0)), wc + Vector((0.045, 0, 0)), 0.52, 0.52, m["wood_d"], 12))
        parts.append(ck.tube("hub%d" % sx, wc - Vector((0.09, 0, 0)), wc + Vector((0.09, 0, 0)), 0.13, 0.11, m["iron"], 8))
        for k in range(4):
            a = math.pi * k / 4
            d = Vector((0, math.cos(a), math.sin(a))) * 0.46
            parts.append(ck.tube("spoke%d_%d" % (sx, k), wc + Vector((sx * 0.05, 0, 0)) - d, wc + Vector((sx * 0.05, 0, 0)) + d, 0.03, 0.03, m["wood_l"], 4))
        # varal: do canto da caixa até a mão
        parts.append(ck.tube("shaft%d" % sx, Vector((sx * 0.5, y0 + 0.1, 0.66)), Vector((sx * 0.34, 0.02, 0.72)), 0.04, 0.035, m["wood_d"], 5))
    parts.append(ck.tube("axle", Vector((-0.72, yc + 0.1, 0.52)), Vector((0.72, yc + 0.1, 0.52)), 0.045, 0.045, m["iron"], 6))
    for sy in (y0, y1):
        parts.append(_B("end%d" % int(sy * 10), (1.2, 0.07, 0.42), (0, sy, 0.86), m["wood"], 0.02))
    # toldo: três arcos e a lona por cima (gomos)
    for i, y in enumerate((y0 + 0.2, yc, y1 - 0.2)):
        pts = [Vector((math.cos(math.pi * k / 6) * 0.62, y, 1.08 + math.sin(math.pi * k / 6) * 0.72)) for k in range(7)]
        for k in range(6):
            parts.append(ck.tube("hoop%d_%d" % (i, k), pts[k], pts[k + 1], 0.028, 0.028, m["wood_l"], 4))
    for k in range(6):
        a0, a1 = math.pi * k / 6, math.pi * (k + 1) / 6
        mid = (a0 + a1) * 0.5
        o = ck.box("canvas%d" % k, (0.36, y1 - y0 - 0.25, 0.035), (0, 0, 0), canvas, 0.008)
        rot = __import__("mathutils").Matrix.Rotation(mid - math.pi * 0.5, 4, "Y")
        for v in o.data.vertices:
            v.co = rot @ v.co + Vector((math.cos(mid) * 0.66, yc, 1.08 + math.sin(mid) * 0.76))
        parts.append(o)
    # carga à mostra atrás: caixote, barril e saco
    parts.append(_B("load_crate", (0.5, 0.5, 0.45), (-0.22, y1 - 0.35, 0.9), m["wood_l"], 0.02))
    parts.append(ck.tube("load_barrel", Vector((0.25, y1 - 0.32, 0.67)), Vector((0.25, y1 - 0.32, 1.22)), 0.22, 0.22, m["wood_d"], 9))
    parts.append(ck.ball("load_sack", 0.22, (0.0, y0 + 0.35, 0.86), ck.mat("p_sack", (0.78, 0.68, 0.48), 0.9), (1.4, 1.0, 0.8)))
    parts.append(ck.tube("lantern", Vector((0.6, y0 + 0.02, 1.2)), Vector((0.6, y0 + 0.02, 1.42)), 0.07, 0.07, m["glow"], 6))
    return parts


BUILDERS = {"carry_crate": carry_crate, "carry_sack": carry_sack, "carry_log": carry_log, "carry_rock": carry_rock, "cart": cart}
