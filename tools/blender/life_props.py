"""Vida dos mapas: o que um NPC carrega ou puxa (só apresentação, EntityView._attach_carry; `carry` em MapsCatalog.LIVING_NPCS).
Tamanho real (não é esticado pelo jogo): 1 u = 1 m, origem = onde o boneco pisa, frente do boneco = -Y.

    carry_crate / carry_sack / carry_log / carry_rock   carga no ombro direito (-X), já na altura do ombro
    cart                                                carroça de caravana puxada pelos varais, atrás do boneco (+Y)
    cart_draft                                          a mesma carroça com varais compridos, arreio e cabresto para um animal
                                                        de tiro (o jogo põe o `mob_horse` entre os varais: CarryPose.DRAFT);
                                                        o boneco anda ao lado, à direita do bicho, com o cabresto na mão esquerda
    hen                                                 galinha de Aldara (AmbientLife, um MultiMesh por bando): UMA malha, UM material,
                                                        cor no vértice (COLOR_0, sRGB cru), bico para -Y, pés em z = 0
"""
import math

import bpy
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
    y0, y1 = 0.95, 2.75                     # a caixa fica atrás do boneco
    parts = _cart(m, y0, y1)
    # rodas e eixo saem no nó `wheels` do GLB, com a origem no eixo: o jogo as gira pela distância andada (CarryPose.WHEELS)
    axle = (0.0, (y0 + y1) * 0.5 + 0.1, WHEEL_R)
    for o in parts:
        if o.name.split(".")[0].startswith(WHEEL_PARTS):
            o["node"], o["pivot"] = "wheels", axle
    return parts


# Animal de tiro (espelhado em CarryPose.DRAFT, game/entities/carry_pose.gd): onde o bicho pisa em relação ao boneco
# (+X = esquerda do boneco, +Y = atrás) e a escala do mob_horse (mob_kit.horse, HIP 0,58) entre os varais.
DRAFT_X, DRAFT_Y, DRAFT_SCALE = 0.95, 0.6, 1.5
DRAFT_SHAFT = 2.2                           # comprimento do varal (m): da caixa até o ombro do animal


def cart_draft(m):
    """Carroça de tiro: a caixa da caravana atrás do animal, varais de 2,2 m pelos flancos, coleira, cilha, retranca e o
    cabresto que cai do focinho até a mão esquerda do boneco. Tudo numa malha só (o bicho é do jogo)."""
    S = DRAFT_SCALE
    h = 0.58 * S                            # altura do quadril do cavalo na escala de tiro
    y0 = DRAFT_Y + 0.9 * S + 0.05           # a caixa começa atrás do rabo
    parts = _cart(m, y0, y0 + 1.8, hand=False)
    for o in parts:                         # a caixa sai centrada no boneco: vai para trás do animal
        for v in o.data.vertices:
            v.co.x += DRAFT_X
    strap = ck.mat("p_harness", (0.3, 0.2, 0.14), 0.8)
    rope = ck.mat("p_rope", (0.8, 0.7, 0.5), 0.9)
    P = lambda x, y, z: Vector((DRAFT_X + x, DRAFT_Y + y, z))
    tip_y = y0 + 0.1 - DRAFT_Y - DRAFT_SHAFT            # ponta do varal: passa do ombro do animal
    for sx in (-1, 1):
        a, b = P(sx * 0.5, y0 + 0.1 - DRAFT_Y, 0.66), P(sx * 0.4, tip_y, h + 0.1)
        parts.append(ck.tube("shaft%d" % sx, a, b, 0.045, 0.035, m["wood_d"], 5))
        parts.append(ck.tube("shaft_cap%d" % sx, b, b + Vector((0, -0.07, 0.0)), 0.05, 0.03, m["iron"], 5))
        parts.append(ck.tube("trace%d" % sx, b + Vector((0, 0.1, 0)), P(sx * 0.25, -0.6, h + 0.2), 0.02, 0.02, strap, 4))
    # coleira: anel inclinado na base do pescoço
    ring = [P(math.cos(math.tau * k / 8) * 0.27, -0.6 - math.sin(math.tau * k / 8) * 0.08, h + 0.2 + math.sin(math.tau * k / 8) * 0.33) for k in range(8)]
    for k in range(8):
        parts.append(ck.tube("collar%d" % k, ring[k], ring[(k + 1) % 8], 0.05, 0.05, strap, 5))
    # cilha por cima do lombo (na frente da sela) e retranca por trás da garupa, de varal a varal
    for name, pts in (("girth", [(-0.4, -0.38, h + 0.1), (-0.27, -0.38, h + 0.34), (0.0, -0.38, h + 0.5), (0.27, -0.38, h + 0.34), (0.4, -0.38, h + 0.1)]),
                      ("breech", [(-0.42, 0.3, h + 0.02), (-0.34, 0.72, h + 0.12), (0.0, 0.86, h + 0.16), (0.34, 0.72, h + 0.12), (0.42, 0.3, h + 0.02)])):
        for k in range(len(pts) - 1):
            parts.append(ck.tube("%s%d" % (name, k), P(*pts[k]), P(*pts[k + 1]), 0.022, 0.022, strap, 4))
    # cabresto: do focinho, com barriga, até a mão esquerda do boneco
    lead = [P(-0.1, -0.98 * S, h + 0.44 * S), Vector((0.62, -0.62, 0.98)), Vector((0.46, -0.34, 0.8)), Vector((LEAD_HAND))]
    for k in range(len(lead) - 1):
        parts.append(ck.tube("lead%d" % k, lead[k], lead[k + 1], 0.016, 0.016, rope, 4))
    # nós do GLB (prop_kit.export_scene lê `node`/`pivot`/`under`): o arreio e o cabresto ficam na malha principal (presos
    # ao bicho); a carroça é o nó `cart`, com a origem onde o animal pisa (o jogo a deixa atrasar na curva em torno dele), e
    # as rodas com o eixo são o nó `wheels`, filho dela, com a origem no eixo (o jogo as gira pela distância andada).
    axle = (DRAFT_X, y0 + 0.9 + 0.1, WHEEL_R)
    for o in parts:
        nm = o.name.split(".")[0]
        if nm.startswith(RIG_PARTS):
            continue
        if nm.startswith(WHEEL_PARTS):
            o["node"], o["pivot"], o["under"] = "wheels", axle, "cart"
        else:
            o["node"], o["pivot"] = "cart", (DRAFT_X, DRAFT_Y, 0.0)
    return parts


WHEEL_R = 0.52                              # raio da roda (m): espelhado em CarryPose.DRAFT `wheel_r`
WHEEL_PARTS = ("wheel", "hub", "spoke", "axle")
RIG_PARTS = ("trace", "collar", "girth", "breech", "lead")


LEAD_HAND = (0.4, -0.2, 0.86)               # mão esquerda na pose "lead" do CarryPose (medida no jogo)


def _cart(m, y0, y1, hand=True):
    canvas = ck.mat("p_canvas", (0.9, 0.84, 0.68), 0.9)
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
        if hand:
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


# --- galinha (bicho de enfeite, AmbientLife) -------------------------------------------------------------------------------
# Cores sRGB, gravadas cruas no COLOR_0 (como os lotes do zones/dress.py: quem lineariza é o material do jogo).
HEN_COL = {"body": (0.961, 0.922, 0.824), "wing": (0.890, 0.831, 0.706), "tail": (0.840, 0.770, 0.630), "red": (0.851, 0.251, 0.227),
           "beak": (0.910, 0.639, 0.227), "eye": (0.13, 0.10, 0.10)}


class _Soup:
    """Faces soltas com uma cor cada (sem vértice dividido entre peças): vira UMA malha facetada com a cor no canto da face."""

    def __init__(self):
        self.v, self.f, self.c = [], [], []

    def face(self, pts, col, inside):
        """`inside` = ponto de dentro da peça: decide o lado da normal."""
        pts = [Vector(p) for p in pts]
        n = (pts[1] - pts[0]).cross(pts[2] - pts[0])
        if n.length < 1e-9:
            return
        mid = sum(pts, Vector()) / len(pts)
        if n.dot(mid - Vector(inside)) < 0:
            pts.reverse()
        i = len(self.v)
        self.v.extend(pts)
        self.f.append(list(range(i, i + len(pts))))
        self.c.append(col)

    def lathe(self, rings, n, cols, tilt=0.0, phase=90.0):
        """Casca de anéis elípticos ao longo de um eixo no plano YZ (`tilt` graus: 0 = +Y, 90 = +Z).
        rings = [(y, z, rx, rv)]; raio 0 = ponta. cols = uma cor por faixa (ou uma só)."""
        a = math.radians(tilt)
        up = Vector((0.0, -math.sin(a), math.cos(a)))
        loops = []
        for y, z, rx, rv in rings:
            c = Vector((0.0, y, z))
            if rx <= 0:
                loops.append([c])
            else:
                loops.append([c + Vector((rx * math.cos(math.radians(phase + 360.0 * k / n)), 0, 0)) + up * (rv * math.sin(math.radians(phase + 360.0 * k / n)))
                              for k in range(n)])
        inside = sum((Vector((0.0, r[0], r[1])) for r in rings), Vector()) / len(rings)
        for i in range(len(loops) - 1):
            la, lb = loops[i], loops[i + 1]
            col = cols[i] if isinstance(cols, list) else cols
            for k in range(n):
                k2 = (k + 1) % n
                if len(la) == 1:
                    self.face([la[0], lb[k], lb[k2]], col, inside)
                elif len(lb) == 1:
                    self.face([la[k], la[k2], lb[0]], col, inside)
                else:
                    self.face([la[k], la[k2], lb[k2], lb[k]], col, inside)

    def cone(self, base, tip, col):
        """Pirâmide sem tampa: polígono `base` (escondido dentro de outra peça) até a ponta."""
        base = [Vector(p) for p in base]
        inside = sum(base, Vector()) / len(base)
        for k in range(len(base)):
            self.face([base[k], base[(k + 1) % len(base)], tip], col, inside)

    def mirror_x(self, start):
        """Copia espelhadas em X as faces criadas desde `start` (índice em self.f)."""
        for fi in range(start, len(self.f)):
            pts = [Vector((-self.v[i].x, self.v[i].y, self.v[i].z)) for i in reversed(self.f[fi])]
            i = len(self.v)
            self.v.extend(pts)
            self.f.append(list(range(i, i + len(pts))))
            self.c.append(self.c[fi])

    def to_object(self, name, mat):
        me = bpy.data.meshes.new(name + "_mesh")
        me.from_pydata([tuple(p) for p in self.v], [], self.f)
        att = me.color_attributes.new("Col", "FLOAT_COLOR", "CORNER")
        vals = []
        for poly in me.polygons:
            vals.extend((*self.c[poly.index], 1.0) * poly.loop_total)
        att.data.foreach_set("color", vals)
        me.color_attributes.active_color = att
        me.color_attributes.render_color_index = 0
        me.materials.append(mat)
        me.update()
        return ck._link(bpy.data.objects.new(name, me))


def vcol_mat(name="life_vcol"):
    """Material branco único que lê a cor do vértice (o gama é só para a foto no Blender: o glTF leva o COLOR_0 cru)."""
    m = bpy.data.materials.get(name)
    if m:
        return m
    m = ck.mat(name, (1.0, 1.0, 1.0), 1.0)
    nt = m.node_tree
    bsdf = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
    att = nt.nodes.new("ShaderNodeVertexColor")
    att.layer_name = "Col"
    gam = nt.nodes.new("ShaderNodeGamma")
    gam.inputs[1].default_value = 2.2
    nt.links.new(att.outputs[0], gam.inputs[0])
    nt.links.new(gam.outputs[0], bsdf.inputs["Base Color"])
    return m


def _hen_feather(s, root, tip, wide, thick):
    """Pena do rabo: fuso de 4 lados da raiz (dentro do corpo) até a ponta, metade de cima mais escura."""
    root, tip = Vector(root), Vector(tip)
    d = (tip - root).normalized()
    side = d.cross(Vector((0, 0, 1))).normalized()
    up = side.cross(d).normalized()
    a, b = root.lerp(tip, 0.45), root.lerp(tip, 0.82)
    loops = [[c + side * (w * sx) + up * (t * sy) for sx, sy in ((1, 0), (0, 1), (-1, 0), (0, -1))]
             for c, w, t in ((root, wide * 0.7, thick * 0.8), (a, wide, thick), (b, wide * 0.8, thick * 0.8))]
    inside = root.lerp(tip, 0.5)
    for i, col in ((0, HEN_COL["body"]), (1, HEN_COL["tail"])):
        for k in range(4):
            s.face([loops[i][k], loops[i][(k + 1) % 4], loops[i + 1][(k + 1) % 4], loops[i + 1][k]], col, inside)
    for k in range(4):
        s.face([loops[2][k], loops[2][(k + 1) % 4], tip], HEN_COL["tail"], inside)


def hen(m):
    """Galinha de ~0,40 x 0,26 x 0,36 m. Lida de cima (câmera a 52°): corpo redondo, leque do rabo, crista vermelha."""
    C = HEN_COL
    s = _Soup()
    # corpo: gota deitada, peito cheio na frente (-Y), garupa que sobe para o rabo
    body = [(-0.140, 0.160, 0, 0), (-0.112, 0.160, 0.074, 0.062), (-0.055, 0.158, 0.110, 0.086), (0.015, 0.160, 0.114, 0.088),
            (0.080, 0.176, 0.084, 0.068), (0.125, 0.200, 0, 0)]
    s.lathe(body, 8, C["body"])

    def skin(y, z, out):
        """Ponto no lado +X do corpo (elipse interpolada entre os anéis), `out` m para fora (negativo = enterrado)."""
        i = max(k for k in range(len(body) - 1) if body[k][0] <= y)
        t = (y - body[i][0]) / (body[i + 1][0] - body[i][0])
        zc, rx, rv = (body[i][j] + (body[i + 1][j] - body[i][j]) * t for j in (1, 2, 3))
        return (rx * math.sqrt(max(0.0, 1.0 - ((z - zc) / rv) ** 2)) * 0.94 + out, y, z)

    # pescoço + cabeça (uma casca só, aberta dentro do corpo); cabeça um pouco grande, à moda chibi
    s.lathe([(-0.076, 0.205, 0.064, 0.058), (-0.100, 0.256, 0.048, 0.046), (-0.110, 0.288, 0.060, 0.060), (-0.113, 0.316, 0.047, 0.048),
             (-0.114, 0.334, 0, 0)], 6, C["body"], tilt=100.0)
    # crista: três gomos, o do meio mais alto (é o que mais aparece de cima)
    for y, top, hw in ((-0.150, 0.348, 0.018), (-0.116, 0.362, 0.021), (-0.082, 0.346, 0.018)):
        s.cone([(-hw, y - 0.021, 0.314), (hw, y - 0.021, 0.314), (hw, y + 0.021, 0.314), (-hw, y + 0.021, 0.314)], (0, y + 0.004, top), C["red"])
    # bico e barbela
    s.cone([(-0.024, -0.154, 0.306), (0.024, -0.154, 0.306), (0.024, -0.154, 0.278), (-0.024, -0.154, 0.278)], (0, -0.202, 0.286), C["beak"])
    s.cone([(-0.017, -0.176, 0.280), (0.017, -0.176, 0.280), (0.017, -0.144, 0.280), (-0.017, -0.144, 0.280)], (0, -0.164, 0.228), C["red"])
    half = len(s.f)
    # olho: losango baixo no lado da cabeça
    s.cone([(0.036, -0.140, 0.314), (0.036, -0.152, 0.303), (0.036, -0.140, 0.292), (0.036, -0.128, 0.303)], (0.054, -0.140, 0.303), C["eye"])
    # asa: escama em gota colada no lado (a borda nasce enterrada na pele do corpo), ponta para trás
    ring = [skin(y, z, -0.004) for y, z in ((-0.088, 0.170), (-0.055, 0.222), (0.025, 0.228), (0.106, 0.192), (0.035, 0.108), (-0.050, 0.104))]
    mid = [skin(-0.045, 0.166, 0.024), skin(0.030, 0.168, 0.027)]
    inside = (0.03, 0.0, 0.168)
    s.face([ring[0], ring[1], mid[0]], C["wing"], inside)
    s.face([ring[1], ring[2], mid[1], mid[0]], C["wing"], inside)
    s.face([ring[2], ring[3], mid[1]], C["wing"], inside)
    s.face([ring[3], ring[4], mid[1]], C["wing"], inside)
    s.face([ring[4], ring[5], mid[0], mid[1]], C["wing"], inside)
    s.face([ring[5], ring[0], mid[0]], C["wing"], inside)
    # pena lateral do rabo (a do meio vem depois, sem espelho)
    _hen_feather(s, (0.030, 0.085, 0.215), (0.062, 0.178, 0.305), 0.030, 0.020)
    # perna e pé
    leg = [Vector((0.045 + 0.011 * math.cos(math.radians(45 + 90 * k)), 0.012 + 0.011 * math.sin(math.radians(45 + 90 * k)), 0.0)) for k in range(4)]
    for k in range(4):
        a, b = leg[k], leg[(k + 1) % 4]
        s.face([a, b, b + Vector((0, 0, 0.095)), a + Vector((0, 0, 0.095))], C["beak"], (0.045, 0.012, 0.04))
    s.cone([(0.014, -0.040, 0.0), (0.076, -0.040, 0.0), (0.045, 0.034, 0.0)], (0.045, 0.008, 0.020), C["beak"])
    s.mirror_x(half)
    _hen_feather(s, (0.0, 0.090, 0.225), (0.0, 0.200, 0.338), 0.032, 0.022)
    return [s.to_object("hen", vcol_mat())]


BUILDERS = {"carry_crate": carry_crate, "carry_sack": carry_sack, "carry_log": carry_log, "carry_rock": carry_rock, "cart": cart, "cart_draft": cart_draft, "hen": hen}
