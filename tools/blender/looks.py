"""Aparência escolhida na criação de personagem: estilos de cabelo, barba e olhos dentro de cada kit.

Cada variante vira UMA malha (mantém o orçamento de malhas do kit):
  base_hair_<estilo>   material "hair"  (cor do cabelo)
  base_beard_<estilo>  material "beard" (cor da barba)
  base_eyes_<estilo>   material "iris"  (cor dos olhos) + brilho branco
  base_brows_<estilo>  material "hair"  (sobrancelha na cor do cabelo)
  base_mouth_<estilo>  boca (escura + dentes)
  base_marks_<estilo>  marcas no rosto (cicatriz, sardas, pintura de guerra, rubor, tatuagem)
A pele (material "m_skin") é pintada pelo jogo com a cor escolhida.
O jogo liga uma de cada (KitModel.apply_look). Nomes iguais a data/catalog/looks_catalog.gd.
"""
import math
import bpy
import bmesh
from mathutils import Vector

HAIR = ["short", "long", "spiky", "ponytail", "bob", "buzz", "twintails", "braid", "mohawk", "topknot", "messy", "curly"]
BROWS = ["thin", "thick", "angry", "worried"]
MOUTHS = ["smile", "neutral", "open", "fang"]
MARKS = ["scar", "freckles", "warpaint", "blush", "tattoo"]
BEARDS = ["stubble", "mustache", "goatee", "full"]
EYES = ["round", "big", "narrow", "sharp"]


def _shell(ck, name, c, r, cut_front, cut_back, cut_side, material, thick=0.035, keep_below=False, back_limit=None):
    """Casca da cabeça: mantém o que fica acima (ou abaixo, para barba) das linhas de corte."""
    o = ck.quad_sphere(name, r, c, cuts=4)
    bm = bmesh.new()
    bm.from_mesh(o.data)
    kill = []
    for f in bm.faces:
        d = f.calc_center_median() - Vector(c)
        cut = cut_front if d.y < -r * 0.25 else (cut_back if d.y > r * 0.2 else cut_side)
        if keep_below:
            if d.z > cut * r or (back_limit is not None and d.y > back_limit * r):
                kill.append(f)
        elif d.z < cut * r:
            kill.append(f)
    bmesh.ops.delete(bm, geom=kill, context="FACES")
    bm.to_mesh(o.data)
    bm.free()
    sol = o.modifiers.new("sol", "SOLIDIFY")
    sol.thickness = thick
    sol.offset = 1.0
    ck._bake(o)
    o.data.materials.append(material)
    ck._smooth(o.data)
    return o


def _fringe(ck, name, c, r, m, n=3, length=0.45, spread=0.4):
    out = []
    for k in range(n):
        x = (k - (n - 1) / 2) * spread * 2 / max(1, n - 1) if n > 1 else 0.0
        y = -math.sqrt(max(0.0, 1.0 - x * x)) * r * 0.86
        out.append(ck.strand("%s_fringe%d" % (name, k), c + Vector((x * r, y, r * 0.62)), r * length * (0.85 if abs(x) < 0.1 else 1.0), r * 0.62, r * 0.2, m, taper=0.7, lean=(-x * 0.3, -0.25)))
    return out


def hair(ck, b, c, style, m):
    r = b["head"] * 1.07
    c = Vector(c)
    n = "base_hair_" + style
    p = []
    if style == "short":
        p.append(_shell(ck, n + "_cap", c, r, 0.35, -0.62, -0.3, m))
        for sx in (-1, 1):
            p.append(ck.strand(n + "_side%d" % sx, c + Vector((sx * r * 0.9, -r * 0.1, r * 0.2)), r * 0.55, r * 0.2, r * 0.22, m))
        p += _fringe(ck, n, c, r, m)
    elif style == "long":
        p.append(_shell(ck, n + "_cap", c, r, 0.35, -0.95, -0.55, m))
        p.append(ck.strand(n + "_back", c + Vector((0, r * 0.72, -r * 0.1)), r * 1.15, r * 1.3, r * 0.42, m, taper=0.4, lean=(0.0, 0.12)))
        for sx in (-1, 1):
            p.append(ck.strand(n + "_lock%d" % sx, c + Vector((sx * r * 0.86, -r * 0.2, r * 0.25)), r * 1.15, r * 0.24, r * 0.24, m, lean=(sx * 0.06, 0.0)))
        p += _fringe(ck, n, c, r, m)
    elif style == "spiky":                     # pontas para cima e para trás
        p.append(_shell(ck, n + "_cap", c, r, 0.4, -0.55, -0.25, m))
        for k in range(9):
            a = math.pi * (0.15 + 0.7 * (k % 5) / 4) + (0 if k < 5 else math.pi * 0.08)
            row = 0 if k < 5 else 1
            root = c + Vector((math.cos(a) * r * 0.55, r * (0.1 + 0.35 * row), r * (0.8 - 0.15 * row)))
            p.append(ck.tube("%s_spike%d" % (n, k), root, root + Vector((math.cos(a) * r * 0.35, r * (0.35 + 0.2 * row), r * 0.55)), r * 0.24, r * 0.02, m, 6))
        p += _fringe(ck, n, c, r, m, n=4, length=0.5, spread=0.5)
    elif style == "ponytail":                  # preso atrás, rabo caindo
        p.append(_shell(ck, n + "_cap", c, r, 0.35, -0.5, -0.35, m))
        tie = c + Vector((0, r * 0.95, r * 0.3))
        p.append(ck.ball(n + "_tie", r * 0.16, tie, m))
        p.append(ck.strand(n + "_tail", tie + Vector((0, r * 0.08, 0)), r * 1.3, r * 0.42, r * 0.36, m, taper=0.3, lean=(0.0, 0.35)))
        p += _fringe(ck, n, c, r, m, n=2, length=0.45, spread=0.45)
    elif style == "bob":                       # corte reto na altura do queixo
        p.append(_shell(ck, n + "_cap", c, r * 1.02, 0.3, -0.8, -0.75, m))
        p += _fringe(ck, n, c, r, m, n=5, length=0.42, spread=0.55)
    elif style == "buzz":                      # raspado: casca rente, sem franja
        p.append(_shell(ck, n + "_cap", c, b["head"] * 1.02, 0.45, -0.55, -0.25, m, thick=0.015))
    elif style == "twintails":                 # duas mechas presas no alto, caindo dos lados
        p.append(_shell(ck, n + "_cap", c, r, 0.35, -0.6, -0.35, m))
        for sx in (-1, 1):
            tie = c + Vector((sx * r * 0.85, r * 0.25, r * 0.55))
            p.append(ck.ball("%s_tie%d" % (n, sx), r * 0.13, tie, m))
            p.append(ck.strand("%s_tail%d" % (n, sx), tie + Vector((sx * r * 0.08, 0, 0)), r * 1.25, r * 0.36, r * 0.3, m, taper=0.3, lean=(sx * 0.35, 0.1)))
        p += _fringe(ck, n, c, r, m, n=3, length=0.48, spread=0.45)
    elif style == "braid":                     # trança única descendo pelas costas
        p.append(_shell(ck, n + "_cap", c, r, 0.35, -0.7, -0.4, m))
        q = c + Vector((0, r * 0.95, -r * 0.2))
        for k in range(6):
            p.append(ck.ball("%s_knot%d" % (n, k), r * (0.2 - k * 0.018), q + Vector((((k % 2) - 0.5) * r * 0.06, r * 0.08 * k, -r * 0.22 * k)), m, (1, 0.9, 1.15)))
        p += _fringe(ck, n, c, r, m)
    elif style == "mohawk":                    # laterais raspadas, crista no meio
        p.append(_shell(ck, n + "_cap", c, b["head"] * 1.02, 0.45, -0.55, -0.25, m, thick=0.012))
        for k in range(7):
            a = math.pi * (0.2 + 0.6 * k / 6)
            root = c + Vector((0, -math.cos(a) * r * 0.85, math.sin(a) * r * 0.9))
            tip = root + Vector((0, -math.cos(a) * r * 0.25, math.sin(a) * r * 0.45))
            p.append(ck.blade("%s_crest%d" % (n, k), root, tip, r * 0.42, 0.04, m, (0, math.sin(a), math.cos(a)), 0.4))
    elif style == "topknot":                   # coque no alto da cabeça
        p.append(_shell(ck, n + "_cap", c, r, 0.4, -0.5, -0.3, m))
        p.append(ck.ball(n + "_bun", r * 0.32, c + Vector((0, r * 0.15, r * 1.1)), m))
        p.append(ck.tube(n + "_band", c + Vector((0, r * 0.12, r * 0.88)), c + Vector((0, r * 0.14, r * 0.95)), r * 0.2, r * 0.2, m, 12))
        p += _fringe(ck, n, c, r, m, n=2, length=0.4, spread=0.35)
    elif style == "messy":                     # tufos em todas as direções
        p.append(_shell(ck, n + "_cap", c, r, 0.32, -0.62, -0.3, m))
        for k in range(10):
            a = math.tau * k / 10
            el = 0.45 + 0.25 * ((k * 7) % 3) / 2
            d = Vector((math.cos(a) * math.cos(el), math.sin(a) * math.cos(el), math.sin(el)))
            if d.y < -0.6:
                continue
            root = c + d * r * 0.95
            p.append(ck.tube("%s_tuft%d" % (n, k), root, root + d * r * 0.35 + Vector((0, 0, r * 0.08)), r * 0.16, r * 0.02, m, 6))
        p += _fringe(ck, n, c, r, m, n=4, length=0.55, spread=0.5)
    elif style == "curly":                     # cachos: volume redondo de bolinhas
        p.append(_shell(ck, n + "_cap", c, r * 1.05, 0.3, -0.75, -0.45, m))
        for k in range(16):
            a = math.tau * k / 16
            for row, (el, rad) in enumerate(((0.15, 1.1), (0.6, 1.0))):
                d = Vector((math.cos(a) * math.cos(el), math.sin(a) * math.cos(el), math.sin(el)))
                if d.y < -0.45 and row == 0:
                    continue
                p.append(ck.ball("%s_curl%d_%d" % (n, k, row), r * 0.22, c + d * r * rad, m))
        p.append(ck.ball(n + "_top", r * 0.3, c + Vector((0, 0, r * 1.05)), m))
    return p


def beard(ck, b, c, style, m):
    """Barba abaixo da boca (os olhos ficam um pouco abaixo do centro da cabeça; a boca perto de -0.5r)."""
    r = b["head"]
    c = Vector(c)
    n = "base_beard_" + style
    p = []
    if style == "stubble":                     # sombra fina só na frente do queixo
        p.append(_shell(ck, n + "_jaw", c, r * 1.01, -0.64, -0.64, -0.6, m, thick=0.006, keep_below=True, back_limit=-0.3))
    if style == "full":                        # mechas ao longo da mandíbula, mais longas no queixo
        for k in range(9):
            a = math.radians(-80 + 160 * k / 8)
            root = c + Vector((math.sin(a) * r * 0.88, -math.cos(a) * r * 0.82, -r * 0.42))
            ln = r * (0.3 + 0.35 * math.cos(a))
            p.append(ck.strand("%s_lock%d" % (n, k), root, ln, r * 0.32, r * 0.22, m, taper=0.55, lean=(math.sin(a) * 0.15, -math.cos(a) * 0.25)))
    if style in ("mustache", "full", "goatee"):
        for sx in (-1, 1):
            p.append(ck.strand("%s_stache%d" % (n, sx), c + Vector((sx * r * 0.1, -r * 0.97, -r * 0.5)), r * 0.28, r * 0.22, r * 0.09, m, taper=0.4, lean=(sx * 1.1, 0.0)))
    if style == "goatee":
        p.append(ck.strand(n + "_chin", c + Vector((0, -r * 0.86, -r * 0.7)), r * 0.38, r * 0.22, r * 0.18, m, taper=0.4, lean=(0.0, -0.15)))
    return p


def eyes(ck, b, c, style, m_iris, m_white):
    c = Vector(c)
    n = "base_eyes_" + style
    p = []
    size = {"round": 0.06, "big": 0.072, "narrow": 0.06, "sharp": 0.058}[style]
    sz = {"round": 1.35, "big": 1.45, "narrow": 0.75, "sharp": 1.0}[style]
    for sx in (-1, 1):
        e = ck.quad_sphere("%s_e%d" % (n, sx), size, (0, 0, 0), cuts=2)
        tilt = math.radians(14 * sx) if style == "sharp" else 0.0
        for v in e.data.vertices:
            x, y, z = v.co.x * 0.85, v.co.y * 0.35, v.co.z * sz
            x, z = x * math.cos(tilt) - z * math.sin(tilt), x * math.sin(tilt) + z * math.cos(tilt)
            v.co = Vector((x, y, z)) + c + Vector((sx * 0.13, -b["head"] * 0.9, -0.04 - (0.01 if style == "narrow" else 0.0)))
        e.data.materials.append(m_iris)
        p.append(e)
        hl = ck.quad_sphere("%s_hl%d" % (n, sx), 0.018 if style != "big" else 0.024, c + Vector((sx * 0.13 + 0.02, -b["head"] * 0.93, 0.0 if style != "narrow" else -0.03)), cuts=1)
        hl.data.materials.append(m_white)
        p.append(hl)
        if style == "sharp":                   # cílio de cima inclinado
            p.append(ck.blade("%s_lash%d" % (n, sx), c + Vector((sx * 0.07, -b["head"] * 0.93, 0.03 - sx * 0.0)),
                              c + Vector((sx * 0.2, -b["head"] * 0.86, 0.06)), 0.025, 0.01, m_iris, (0, 0, 1), 0.5))
    return p


def _face_y(b, x, z, out=0.01):
    """Superfície da frente do rosto (elipsoide da cabeça: 1.04 × 0.96 × 0.92 do raio)."""
    r = b["head"]
    k = 1.0 - (x / (1.04 * r)) ** 2 - (z / (0.92 * r)) ** 2
    return -0.96 * r * math.sqrt(max(0.05, k)) - out


def brows(ck, b, c, style, m):
    c = Vector(c)
    n = "base_brows_" + style
    p = []
    for sx in (-1, 1):
        x0, x1 = sx * 0.07, sx * 0.19
        z0, z1 = {"thin": (0.075, 0.075), "thick": (0.075, 0.08), "angry": (0.06, 0.1), "worried": (0.1, 0.065)}[style]
        w = 0.025 if style == "thin" else 0.045
        a = c + Vector((x0, _face_y(b, x0, z0, 0.012), z0))
        e = c + Vector((x1, _face_y(b, x1, z1, 0.012), z1))
        p.append(ck.blade("%s_%d" % (n, sx), a, e, w, 0.012, m, (0, 0, 1), 0.5))
    return p


def mouth(ck, b, c, style, m_mouth, m_teeth):
    c = Vector(c)
    n = "base_mouth_" + style
    z = -0.19
    p = []
    if style == "smile":                       # curva para cima
        for k in range(5):
            x = (k - 2) * 0.022
            zz = z + 0.004 * abs(k - 2) ** 1.6
            p.append(ck.ball("%s_%d" % (n, k), 0.011, c + Vector((x, _face_y(b, x, zz, 0.006), zz)), m_mouth, (1.3, 0.6, 0.8)))
    elif style == "neutral":
        p.append(ck.tube(n + "_line", c + Vector((-0.035, _face_y(b, -0.035, z, 0.006), z)), c + Vector((0.035, _face_y(b, 0.035, z, 0.006), z)), 0.008, 0.008, m_mouth, 6))
    elif style == "open":                      # boca aberta ("O" de surpresa / grito de guerra)
        p.append(ck.ball(n + "_o", 0.028, c + Vector((0, _face_y(b, 0, z, 0.0), z)), m_mouth, (1.0, 0.4, 1.2)))
    elif style == "fang":                      # sorriso com caninos
        for k in range(5):
            x = (k - 2) * 0.022
            zz = z + 0.004 * abs(k - 2) ** 1.6
            p.append(ck.ball("%s_%d" % (n, k), 0.011, c + Vector((x, _face_y(b, x, zz, 0.006), zz)), m_mouth, (1.3, 0.6, 0.8)))
        for sx in (-1, 1):
            x = sx * 0.025
            top = c + Vector((x, _face_y(b, x, z, 0.008), z + 0.002))
            p.append(ck.tube("%s_fang%d" % (n, sx), top, top + Vector((0, -0.002, -0.028)), 0.008, 0.001, m_teeth, 5))
    return p


def marks(ck, b, c, style, mats):
    c = Vector(c)
    n = "base_marks_" + style
    p = []
    if style == "scar":                        # risco na diagonal sobre o olho esquerdo
        for k in range(4):
            t0, t1 = k / 4, (k + 1) / 4
            x0, z0 = 0.06 + 0.12 * t0, 0.09 - 0.2 * t0
            x1, z1 = 0.06 + 0.12 * t1, 0.09 - 0.2 * t1
            p.append(ck.tube("%s_%d" % (n, k), c + Vector((x0, _face_y(b, x0, z0, 0.004), z0)), c + Vector((x1, _face_y(b, x1, z1, 0.004), z1)), 0.008, 0.008, mats["scar"], 5))
    elif style == "freckles":
        for sx in (-1, 1):
            for k, (dx, dz) in enumerate(((0.0, 0.0), (0.03, 0.012), (0.018, -0.022), (0.05, -0.008), (-0.02, -0.015))):
                x, z = sx * (0.14 + dx), -0.12 + dz
                p.append(ck.ball("%s_%d_%d" % (n, sx, k), 0.007, c + Vector((x, _face_y(b, x, z, 0.002), z)), mats["freckle"], (1, 0.4, 1)))
    elif style == "warpaint":                  # duas faixas sob cada olho
        for sx in (-1, 1):
            for k in range(2):
                z = -0.12 - k * 0.03
                a = c + Vector((sx * 0.08, _face_y(b, sx * 0.08, z, 0.004), z))
                e = c + Vector((sx * 0.2, _face_y(b, sx * 0.2, z - 0.01, 0.004), z - 0.01))
                p.append(ck.blade("%s_%d_%d" % (n, sx, k), a, e, 0.018, 0.006, mats["paint"], (0, 0, 1), 0.5))
    elif style == "blush":
        for sx in (-1, 1):
            x, z = sx * 0.16, -0.12
            p.append(ck.ball("%s_%d" % (n, sx), 0.035, c + Vector((x, _face_y(b, x, z, -0.006), z)), mats["blush"], (1.2, 0.3, 0.7)))
    elif style == "tattoo":                    # marca tribal na testa
        z0 = 0.16
        p.append(ck.ball(n + "_dot", 0.016, c + Vector((0, _face_y(b, 0, z0, 0.003), z0)), mats["paint"], (1, 0.4, 1)))
        for sx in (-1, 1):
            a = c + Vector((sx * 0.02, _face_y(b, sx * 0.02, z0, 0.003), z0))
            e = c + Vector((sx * 0.09, _face_y(b, sx * 0.09, z0 + 0.04, 0.003), z0 + 0.04))
            p.append(ck.blade("%s_wing%d" % (n, sx), a, e, 0.02, 0.006, mats["paint"], (0, 0, 1), 0.35))
    return p


def build_looks(ck, base):
    """Troca o cabelo/olhos únicos do corpo por todas as variantes (uma malha cada, presas na cabeça)."""
    for o in list(bpy.context.scene.objects):
        if o.type == "MESH" and (o.name.startswith("base_hair") or o.name.startswith("base_head_eye") or o.name.startswith("base_head_hl")):
            bpy.data.objects.remove(o, do_unlink=True)
    m_hair = ck.mat("hair", ck.KIT_HAIR, 0.7)
    m_beard = ck.mat("beard", ck.KIT_HAIR, 0.8)
    m_iris = ck.mat("iris", (0.12, 0.09, 0.16), 0.3)
    m_white = ck.mat("m_white", (1, 1, 1), 0.3, 0.5)
    b, c, rig = base["b"], base["head_c"], base["rig"]
    groups = [("base_hair_" + s, hair(ck, b, c, s, m_hair)) for s in HAIR]
    groups += [("base_beard_" + s, beard(ck, b, c, s, m_beard)) for s in BEARDS]
    groups += [("base_eyes_" + s, eyes(ck, b, c, s, m_iris, m_white)) for s in EYES]
    groups += [("base_brows_" + s, brows(ck, b, c, s, m_hair)) for s in BROWS]
    m_mouth = ck.mat("m_mouth", (0.42, 0.14, 0.16), 0.6)
    groups += [("base_mouth_" + s, mouth(ck, b, c, s, m_mouth, m_white)) for s in MOUTHS]
    mk = {"scar": ck.mat("m_mark_scar", (0.78, 0.48, 0.44), 0.7), "freckle": ck.mat("m_mark_freckle", (0.62, 0.36, 0.24), 0.8),
          "paint": ck.mat("mark", (0.25, 0.4, 0.85), 0.6), "blush": ck.mat("m_mark_blush", (1.0, 0.55, 0.6), 0.9)}
    groups += [("base_marks_" + s, marks(ck, b, c, s, mk)) for s in MARKS]
    for name, parts in groups:
        obj = ck._join(parts, name)
        ck._smooth(obj.data)
        ck.skin_rigid(obj, rig, "head")
