"""Acabamento visual das zonas do Ato II: detalhe de chão e adereços em LOTE.

Tudo que se pede a um `Dress` vai para poucas malhas (uma por grupo x célula de 36 m x material), não um objeto por peça:
centenas de pedrinhas, tufos e tábuas custam um punhado de draw calls e saem de vista por distância (set_vis_range).
Nada daqui muda a sim, a não ser `solid()` (colisor oculto para peça grande) — e só onde `ok()` deixa: longe de estrada,
rio, portal, chegada, NPC, ponto de bot e do que já é sólido.

Materiais (o jogo decide pelo nome, MapBuilder._zone_materials):
  patch_*   chão pintado na cor exata do Blender, sem sombra nem contorno (manchas, espuma, riscos)
  glow_*    brilha (brasa, cogumelo, runa), sem sombra
  bandeira_* pano dobrado do `cloth()`/`flag()`: toon de pano (terminador largo, MapBuilder._cloth_material); a cor vai
            no MATERIAL (um por cor), não no vértice, numa malha `det_[<tag>_]pano_<cx>_<cz>` por célula
  outros    toon com contorno e sombra
Nome dos objetos: `Z_<zona>_det_<grupo>_<cx>_<cz>_<material>` — nunca use num grupo/material um pedaço de nome que o
MapDef.conquest_vis procura (estandarte_horda, limpo_, andaime, navio2_, farol_luz...).
Coordenadas do jogo (x, z), y para cima; `rot` em graus = rotação Y do jogo (a mesma convenção de zone_lib.box).
"""
import math
import random
import bmesh
import bpy
from mathutils import Vector, noise

import zone_lib
from zone_lib import B, catmull, mat, mat_c, poly_dist

CELL = 36.0
# grupos de miudeza (capim, seixo, flor, osso): malha própria por célula, SEM sombra (cada malha com sombra custa um
# draw por cascata do sol; a sombra de um tufo não se vê)
MINI = ("campo", "beira3d", "praia3d", "ossos", "mamutes", "gruta", "flechas", "casas3d", "horta3d", "mangue3d", "rio3d",
        "forja3d", "lamacal3d", "estaleiro3d", "cogumelo", "mini")


class _Buf:
    """Lote de uma célula: vértices, faces e a cor de cada face (a API imita o pouco de bmesh que as primitivas usam)."""

    class _V:
        def __init__(self, b):
            self.b = b

        def new(self, co):
            self.b.v.append((co[0], co[1], co[2]))
            return len(self.b.v) - 1

    class _F:
        def __init__(self, b):
            self.b = b

        def new(self, idx):
            self.b.f.append(tuple(idx))
            self.b.c.append(self.b.col)
            self.b.mt.append(self.b.mat)

    def __init__(self):
        self.v, self.f, self.c, self.mt = [], [], [], []
        self.col = (1.0, 1.0, 1.0)
        self.mat = None              # nome da cor da face (só o lote de pano usa: um material por cor)
        self.verts = _Buf._V(self)
        self.faces = _Buf._F(self)


class Dress:
    def __init__(self, z, seed=1, tag="", when=None):
        """tag = pedaço de nome para o MapDef.conquest_vis (ex.: "estandarte_horda": some na retomada); when = a mesma
        condição ({"unless": quest} / {"if": quest}) para os colisores deste lote."""
        self.z = z
        self.tag = tag
        self.when = when
        self.rnd = random.Random(seed * 7919 + 13)
        self.bufs = {}
        self.colors = {}
        self._dups = set()           # cores que colidiram no nome (m())
        self._solid = None
        self._tall = None            # lote da peça alta em construção (tall())
        self._talls = 0

    # ------------------------------------------------------------------ infra
    def m(self, name, color):
        """Registra a cor `name` e devolve o nome. A cor vai no vértice (sRGB, como se vê no jogo): todas as cores de uma
        célula dividem UMA malha e um material (`det_vcol` / `det_vcol_chao`); só `glow_*` vira material próprio."""
        col = tuple(color[:3])
        # os ajudantes montam `name` com parte dos canais (ex.: laje_<r>_<b>): duas cores que só diferem no canal que ficou
        # de fora davam o mesmo nome e a 2ª sumia (tampo musgoso igual ao corpo). Cor diferente = nome próprio; o nome
        # de quem não colide não muda, e o prefixo (`glow_`, `patch_`) fica.
        base, k = name, 0
        while self.colors.setdefault(name, col) != col:
            name = "%s_g%d" % (base, int(col[1] * 100)) if k == 0 else "%s_g%d_%d" % (base, int(col[1] * 100), k)
            k += 1
        if name != base and base not in self._dups:          # um aviso por nome (cor sorteada por peça repete muito)
            self._dups.add(base)
            print("DRESS_COR %s: '%s' ja era %s, %s virou '%s'" % (self.z.zone, base, self.colors[base], col, name))
        return name

    def tall(self, c=None):
        """Peça alta (copa que tapa o boneco): `tall(c)` abre uma malha só dela, com a origem no pé; `tall()` fecha.
        O jogo a deixa translúcida quando fica entre a câmera e o jogador (MapBuilder: nome `det_alto`)."""
        if c is None:
            self._tall = None
            return
        self._talls += 1
        self._tall = self.bufs[("alto", self._talls, 0)] = _Buf()
        self._tall.origin = (c[0], -c[1], 0.0)

    def _bm(self, g, m, x, z):
        if self._tall is not None:
            self._tall.col = self.colors[m]
            return self._tall
        # o grupo `g` é só leitura do código: junta-se tudo da célula (chão sem sombra à parte do resto; brilho à parte)
        kind = m if m.startswith("glow_") else ("chao" if m.startswith("patch_") else ("mini" if g in MINI else "obj"))
        key = (kind, int(math.floor(x / CELL)), int(math.floor(z / CELL)))
        b = self.bufs.get(key)
        if b is None:
            b = self.bufs[key] = _Buf()
        b.col = self.colors[m]
        return b

    def _bm_cloth(self, m, x, z):
        """Lote do pano (cloth/flag): malha própria por célula, um material `bandeira_<cor>` por cor. O jogo dá o toon de
        pano pelo nome do material; no lote `det_vcol` a bandeira saía com o toon comum, chapada. Não sorteia."""
        if self._tall is not None:
            self._tall.col = self.colors[m]
            return self._tall
        key = ("pano", int(math.floor(x / CELL)), int(math.floor(z / CELL)))
        b = self.bufs.get(key)
        if b is None:
            b = self.bufs[key] = _Buf()
        b.col = self.colors[m]
        b.mat = m
        return b

    def flush(self):
        """Cria os objetos (chame uma vez, antes do z.finish)."""
        n = 0
        for (kind, cx, cz), b in self.bufs.items():
            if not b.f:
                continue
            me = bpy.data.meshes.new("det_mesh")
            org = getattr(b, "origin", None)
            me.from_pydata([(v[0] - org[0], v[1] - org[1], v[2]) for v in b.v] if org else b.v, [], b.f)
            bm = bmesh.new()
            bm.from_mesh(me)
            bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
            for f in bm.faces:                               # peça chata (mancha, risco, tapete): sempre de cara para cima
                if f.normal.z < -0.98:
                    f.normal_flip()
            bm.to_mesh(me)
            bm.free()
            if kind.startswith("glow_"):
                me.materials.append(mat(kind, self.colors[kind]))
            elif kind == "pano":
                # o jogo usa a cor do material como veio do glTF (sem linearizar, como no horde.cloth); para a bandeira
                # sair do MESMO tom que tinha no lote de cor no vértice, o material leva a cor escolhida já linearizada
                lin = lambda v: v / 12.92 if v <= 0.04045 else ((v + 0.055) / 1.055) ** 2.4
                slots = {}
                for poly in me.polygons:
                    nm = b.mt[poly.index]
                    if nm not in slots:
                        slots[nm] = len(me.materials)
                        me.materials.append(mat_c("bandeira_" + nm, tuple(lin(k) for k in self.colors[nm])))
                    poly.material_index = slots[nm]
            else:
                # a cor escolhida é sRGB e vai crua no COLOR_0: o toon (vcol_srgb) lineariza. Medido no jogo: mancha de
                # chão (0.86, 0.80, 0.66) aparece (0.85, 0.82, 0.72); gravar o valor linear escurece tudo.
                att = me.color_attributes.new("Col", "FLOAT_COLOR", "CORNER")
                vals = []
                for poly in me.polygons:
                    c = b.c[poly.index]
                    vals.extend((c[0], c[1], c[2], 0.0 if kind == "chao" else 0.08) * poly.loop_total)
                att.data.foreach_set("color", vals)
                me.color_attributes.active_color = att
                me.color_attributes.render_color_index = 0
                me.materials.append(mat({"chao": "det_vcol_chao", "mini": "det_vcol_mini"}.get(kind, "det_vcol"), (1.0, 1.0, 1.0)))
            o = bpy.data.objects.new("%sdet_%s%s_%d_%d" % (self.z.P, self.tag + "_" if self.tag else "", kind, cx, cz), me)
            if org:
                o.location = org
            self.z.coll.objects.link(o)
            n += 1
        self.bufs = {}
        print("dress %s%s: %d malhas" % (self.z.zone, " [" + self.tag + "]" if self.tag else "", n))
        return n

    @staticmethod
    def _xf(c, rot, tilt):
        """Função local (x, yb, up) -> Blender. tilt = (graus em torno do x local, graus em torno do y local)."""
        a = math.radians(rot)
        ca, sa = math.cos(a), math.sin(a)
        tx, ty = math.radians(tilt[0]), math.radians(tilt[1])
        ctx, stx, cty, sty = math.cos(tx), math.sin(tx), math.cos(ty), math.sin(ty)

        def f(x, yb, up, y0=0.0):
            yb, up = yb * ctx - up * stx, yb * stx + up * ctx        # em torno do x local
            x, up = x * cty + up * sty, -x * sty + up * cty           # em torno do y local
            return Vector((c[0] + x * ca - yb * sa, -c[1] + x * sa + yb * ca, y0 + up))
        return f

    # ------------------------------------------------------------------ onde pode
    def _solids(self):
        if self._solid is None:
            d = self.z.data
            pts = [(Vector(o["pos"]), max(o["size"][0], o["size"][2]) * 0.5) for o in d["obstacles"]
                   if o["kind"] not in ("cliff",) and (o.get("solid", True) or o.get("visible", True))]
            pts += [(Vector(p["pos"]), 5.0) for p in d["portals"]]
            pts += [(Vector(v[:2]), 2.2) for v in d["npcs"].values()]
            pts += [(Vector(h), 2.0) for h in d["hangouts"]]
            pts += [(Vector(d["spawn"]), 5.0)]
            pts += [(Vector(s["pos"]), 1.5) for s in d["spawners"]]
            self._solid = pts
        return self._solid

    def ok(self, x, z, r=0.6, road=1.0, blocked=False, water=1.0, rim=3.0, tall=False):
        """Livre para pôr uma peça de raio `r`? `road`/`water` = folga da borda da estrada/água; `blocked` respeita os
        z.block (POIs); rim = folga do penhasco; `tall` = peça alta (copa, mastro): fica fora da área de luta de todo
        spawner e longe da estrada (a câmera é alta: o que é alto tapa o boneco)."""
        zz = self.z
        p = Vector((x, z))
        if tall:
            road = max(road, 4.0)
            if any((p - Vector(s["pos"])).length < s["radius"] + 2.0 + r for s in zz.data["spawners"]):
                return False
        if p.length > zz.rim_r(math.atan2(z, x)) - rim - r:
            return False
        if blocked and any((p - c).length < cr + r for c, cr in zz.blocked):
            return False
        for poly in zz.road_polys.values():
            if poly_dist(p, poly) < zone_lib.ROAD_W * 0.5 + road + r:
                return False
        for k, poly in enumerate(zz.rivers):
            if poly_dist(p, poly) < zz.river_ws[k] * 0.5 + water + r:
                return False
        for c, sr in getattr(zz, "seas", []):
            if (p - c).length < sr + water + r:
                return False
        for w in zz.data["water"]:
            if w.get("kind") == "lake" and "shore" not in w and (p - Vector(w["pos"])).length < w["r"] + water + r:
                return False
        return all((p - q).length > qr + r for q, qr in self._solids())

    def solid(self, x, z, sx, sz, h=2.0, rot=0.0):
        """Colisor oculto para uma peça grande (entra também na lista do ok(): nada nasce em cima)."""
        if self.when:
            return        # enfeite de conquista nunca colide (o teste só aceita colisor de estágio no Porto): use um lote neutro
        self.z.ob("pillar", x, z, (sx, h, sz), rot, visible=False)
        self._solids().append((Vector((x, z)), max(sx, sz) * 0.5))

    def reserve(self, x, z, r):
        self._solids().append((Vector((x, z)), r))

    def spots(self, centers, n=None, r=0.6, spacing=3.0, tries=10, **kw):
        """Pontos livres em manchas: centers = [((x, z), raio, quantos)]."""
        out = []
        for (cx, cz), cr, cnt in centers:
            k = 0
            for _ in range(cnt * tries):
                if k >= cnt:
                    break
                a = self.rnd.uniform(0, math.tau)
                rr = cr * math.sqrt(self.rnd.random())
                x, z = cx + math.cos(a) * rr, cz + math.sin(a) * rr
                if not self.ok(x, z, r, **kw) or any((q[0] - x) ** 2 + (q[1] - z) ** 2 < spacing * spacing for q in out):
                    continue
                out.append((x, z))
                k += 1
        return out

    # ------------------------------------------------------------------ primitivas chatas (chão)
    def blob(self, g, m, c, r, y=0.0072, jitter=0.2, segs=None, sx=1.0, rot=0.0):
        """Mancha orgânica no chão (soma de senos na borda); sx alonga no eixo x local."""
        bm = self._bm(g, m, c[0], c[1])
        rnd = self.rnd
        segs = segs or max(12, min(72, int(r * 8)))
        ph = [rnd.uniform(0, math.tau) for _ in range(3)]
        f = self._xf(c, rot, (0, 0))
        cv = bm.verts.new(f(0, 0, y))
        ring = []
        for i in range(segs):
            a = math.tau * i / segs
            rr = r * (1.0 + jitter * (0.6 * math.sin(2 * a + ph[0]) + 0.35 * math.sin(3 * a + ph[1]) + 0.25 * math.sin(5 * a + ph[2])))
            ring.append(bm.verts.new(f(math.cos(a) * rr * sx, math.sin(a) * rr, y)))
        for i in range(segs):
            bm.faces.new((cv, ring[i], ring[(i + 1) % segs]))

    def strip(self, g, m, pts, w, y=0.0074, wvar=0.0, taper=False):
        """Fita no chão ao longo de `pts` (Vector 2D do jogo); wvar = irregularidade da largura (0..1); taper afina as pontas
        (True: a ponta fica com ~1/3 a 1/2 da largura, corte reto; "point": fecha em bico, para risco solto no chão aberto)."""
        if len(pts) < 2:
            return
        bm = self._bm(g, m, pts[len(pts) // 2].x, pts[len(pts) // 2].y)
        ph = self.rnd.uniform(0, 50)
        L, R = [], []
        n = len(pts)
        for i, p in enumerate(pts):
            a, b = pts[max(0, i - 1)], pts[min(n - 1, i + 1)]
            t = (b - a)
            if t.length < 1e-6:
                t = Vector((1, 0))
            t.normalize()
            nr = Vector((-t.y, t.x))
            k = 1.0
            if taper == "point":
                k = max(0.03, math.sin(math.pi * i / (n - 1)) ** 0.85)
            elif taper:
                k = math.sin(math.pi * (i + 0.35) / (n - 0.3)) ** 0.6
            wl = w * 0.5 * k * (1.0 + wvar * noise.noise(Vector((p.x * 0.21 + ph, p.y * 0.21, 1.0))))
            wr = w * 0.5 * k * (1.0 + wvar * noise.noise(Vector((p.x * 0.21, p.y * 0.21 + ph, 7.0))))
            L.append(bm.verts.new(B(p.x + nr.x * wl, p.y + nr.y * wl, y)))
            R.append(bm.verts.new(B(p.x - nr.x * wr, p.y - nr.y * wr, y)))
        for i in range(n - 1):
            bm.faces.new((L[i], R[i], R[i + 1], L[i + 1]))

    def arc(self, g, m, c, r, a0, a1, w, y=0.036, wvar=0.3, step=2.5):
        """Arco de fita (onda, espuma) em volta de `c`."""
        n = max(3, int(abs(a1 - a0) * r / step))
        pts = [Vector((c[0] + math.cos(a0 + (a1 - a0) * i / n) * r, c[1] + math.sin(a0 + (a1 - a0) * i / n) * r)) for i in range(n + 1)]
        self.strip(g, m, pts, w, y, wvar, taper=True)

    # ------------------------------------------------------------------ primitivas 3D
    def box(self, g, m, c, size, rot=0.0, y0=0.0, tilt=(0, 0)):
        """Caixa: centro (x, z), tamanho (x, altura, z)."""
        bm = self._bm(g, m, c[0], c[1])
        f = self._xf(c, rot, tilt)
        hx, hz, h = size[0] * 0.5, size[2] * 0.5, size[1]
        v = [bm.verts.new(f(sx * hx, sz * hz, up, y0)) for up in (0, h) for sx, sz in ((-1, -1), (1, -1), (1, 1), (-1, 1))]
        for a, b, cc, d in ((0, 1, 2, 3), (7, 6, 5, 4), (0, 4, 5, 1), (1, 5, 6, 2), (2, 6, 7, 3), (3, 7, 4, 0)):
            bm.faces.new((v[a], v[b], v[cc], v[d]))

    def cyl(self, g, m, c, r0, r1, h, y0=0.0, segs=6, rot=0.0, tilt=(0, 0), jitter=0.0, cap=True):
        """Tronco de cone (r0 embaixo, r1 em cima); r1 ~ 0 vira cone."""
        bm = self._bm(g, m, c[0], c[1])
        f = self._xf(c, rot, tilt)
        rnd = self.rnd
        js = [1.0 + rnd.uniform(-jitter, jitter) for _ in range(segs)]
        bot = [bm.verts.new(f(math.cos(math.tau * i / segs) * r0 * js[i], math.sin(math.tau * i / segs) * r0 * js[i], 0, y0)) for i in range(segs)]
        if r1 < 0.02:
            tip = bm.verts.new(f(0, 0, h, y0))
            for i in range(segs):
                bm.faces.new((bot[i], bot[(i + 1) % segs], tip))
        else:
            top = [bm.verts.new(f(math.cos(math.tau * i / segs) * r1 * js[i], math.sin(math.tau * i / segs) * r1 * js[i], h, y0)) for i in range(segs)]
            for i in range(segs):
                bm.faces.new((bot[i], bot[(i + 1) % segs], top[(i + 1) % segs], top[i]))
            if cap:
                bm.faces.new(top)

    def rock(self, g, m, c, r, y=0.0, squash=0.7, sx=1.0, rot=0.0, sub=1):
        """Pedra facetada (icosfera deformada), meio enterrada."""
        bm = self._bm(g, m, c[0], c[1])
        rnd = self.rnd
        tmp = bmesh.new()
        bmesh.ops.create_icosphere(tmp, subdivisions=sub, radius=1.0)
        f = self._xf(c, rot, (0, 0))
        vs = {}
        for v in tmp.verts:
            k = r * (1.0 + rnd.uniform(-0.2, 0.2))
            vs[v.index] = bm.verts.new(f(v.co.x * k * sx, v.co.y * k, max(-0.05, v.co.z * k * squash + r * squash * 0.55), y))
        for fa in tmp.faces:
            bm.faces.new([vs[v.index] for v in fa.verts])
        tmp.free()

    def tuft(self, g, m, c, r=0.5, h=0.9, n=5, lean=(0.0, 0.0), w=0.09):
        """Tufo de capim: n lâminas (pirâmides finas de 3 lados) abertas em leque; lean = (dx, dz) empurra as pontas (vento)."""
        bm = self._bm(g, m, c[0], c[1])
        rnd = self.rnd
        for _ in range(n):
            a = rnd.uniform(0, math.tau)
            d = rnd.uniform(0.0, r)
            bx, bz = c[0] + math.cos(a) * d * 0.5, c[1] + math.sin(a) * d * 0.5
            hh = h * rnd.uniform(0.6, 1.15)
            tx, tz = bx + math.cos(a) * d * 0.7 + lean[0] * hh, bz + math.sin(a) * d * 0.7 + lean[1] * hh
            base = [bm.verts.new(B(bx + math.cos(a + k * 2.094) * w, bz + math.sin(a + k * 2.094) * w, 0.0)) for k in range(3)]
            tip = bm.verts.new(B(tx, tz, hh))
            for k in range(3):
                bm.faces.new((base[k], base[(k + 1) % 3], tip))

    def tube(self, g, m, pts, r0, r1=None, sides=5):
        """Tubo que afina ao longo de pontos 3D do jogo [(x, y_up, z)]: raiz, corda, costela, galho."""
        r1 = r0 if r1 is None else r1
        bm = self._bm(g, m, pts[0][0], pts[0][2])
        P = [Vector((p[0], -p[2], p[1])) for p in pts]
        rings = []
        n = len(P)
        for i, p in enumerate(P):
            t = (P[min(n - 1, i + 1)] - P[max(0, i - 1)]).normalized()
            up = Vector((0, 0, 1)) if abs(t.z) < 0.9 else Vector((1, 0, 0))
            u = t.cross(up).normalized()
            v = t.cross(u).normalized()
            r = r0 + (r1 - r0) * i / (n - 1)
            rings.append([bm.verts.new(p + (u * math.cos(math.tau * k / sides) + v * math.sin(math.tau * k / sides)) * r) for k in range(sides)])
        for i in range(n - 1):
            for k in range(sides):
                bm.faces.new((rings[i][k], rings[i][(k + 1) % sides], rings[i + 1][(k + 1) % sides], rings[i + 1][k]))
        bm.faces.new(rings[-1])
        bm.faces.new(list(reversed(rings[0])))

    # ------------------------------------------------------------------ chão: camadas comuns
    def road_edges(self, color, extra=1.5, wvar=0.45, skip=()):
        """Acostamento irregular sob cada estrada (uma faixa mais larga noutro tom): a estrada deixa de ser fita de régua."""
        m = self.m("patch_acostamento", color)
        for name, poly in self.z.road_polys.items():
            if name in skip or len(poly) < 3:
                continue
            self.strip("beira", m, poly, zone_lib.ROAD_W + extra, 0.0098, wvar)
            for q in (poly[0], poly[-1]):                    # pontas redondas (a faixa acabava num corte reto)
                self.blob("beira", m, (q.x, q.y), (zone_lib.ROAD_W + extra) * 0.56, 0.0097, 0.14)

    def mottle(self, tones, centers, y=0.0008, rmin=3.0, rmax=9.0, group="mancha", step=0.0008):
        """Manchas largas de 2-3 tons no campo (ficam por baixo de estrada e manchas de região): o chão deixa de ser liso.
        tones = [(nome, cor)], centers = [((x, z), raio, quantas)]. `step` = degrau de altura entre os tons (cada tom no seu
        plano, até 3; 0,2 mm some na foto do Blender e fica no limite do z-buffer: use 0,8 mm). 1 tom = 1 plano, 2 tons = 2
        planos (com 1-2 tons o rodízio de 3 planos punha o mesmo tom em alturas diferentes, coladas nas camadas vizinhas).
        Confira a pilha da zona: tudo abaixo das manchas `Zone.patch` (4,5-6,8 mm) e do chão dos lugares (6,0 mm)."""
        ms = [self.m("patch_" + n, c) for n, c in tones]
        planes = min(3, len(ms))
        rnd = self.rnd
        for (cx, cz), cr, cnt in centers:
            for i in range(cnt):
                a = rnd.uniform(0, math.tau)
                rr = cr * math.sqrt(rnd.random())
                x, z = cx + math.cos(a) * rr, cz + math.sin(a) * rr
                if Vector((x, z)).length > self.z.rim_r(math.atan2(z, x)) - 2.0:
                    continue
                r = rnd.uniform(rmin, rmax)
                self.blob(group, ms[i % len(ms)], (x, z), r, y + step * (i % planes), 0.28, sx=rnd.uniform(1.0, 1.9), rot=rnd.uniform(0, 180))

    def pebbles(self, g, m, c, n=5, spread=1.2, r=(0.12, 0.3)):
        for _ in range(n):
            a, d = self.rnd.uniform(0, math.tau), self.rnd.uniform(0, spread)
            self.rock("mini", m, (c[0] + math.cos(a) * d, c[1] + math.sin(a) * d), self.rnd.uniform(*r), 0.0, 0.6, sub=1)

    def roadside(self, stone, grass=None, every=7.0, lean=(0.0, 0.0), skip=(), tuft_h=0.8):
        """Pedrinhas e tufos na beira das estradas (dos dois lados, com falhas)."""
        rnd = self.rnd
        for name, poly in self.z.road_polys.items():
            if name in skip:
                continue
            acc = rnd.uniform(0, every)
            for i in range(1, len(poly) - 1):
                acc += (poly[i] - poly[i - 1]).length
                if acc < every:
                    continue
                acc = rnd.uniform(-every * 0.4, 0)
                t = (poly[i + 1] - poly[i - 1]).normalized()
                nr = Vector((-t.y, t.x)) * (1 if rnd.random() < 0.5 else -1)
                p = poly[i] + nr * (zone_lib.ROAD_W * 0.5 + rnd.uniform(0.5, 1.5))
                if not self.ok(p.x, p.y, 0.5, road=0.2, water=0.6):
                    continue
                if grass and rnd.random() < 0.55:
                    for _ in range(rnd.randint(2, 4)):
                        self.tuft("beira3d", grass, (p.x + rnd.uniform(-0.8, 0.8), p.y + rnd.uniform(-0.8, 0.8)), 0.4, tuft_h, 5, lean)
                else:
                    self.pebbles("beira3d", stone, (p.x, p.y), rnd.randint(3, 6), 0.9)

    # ------------------------------------------------------------------ adereços (cada um = poucas faces no lote)
    def crate(self, c, s=1.0, rot=0.0, y0=0.0, g="carga"):
        w = self.m("caixote", (0.62, 0.47, 0.3))
        d = self.m("caixote_esc", (0.42, 0.3, 0.2))
        self.box(g, w, c, (s, s, s), rot, y0)
        self.box(g, d, c, (s * 1.04, s * 0.12, s * 1.04), rot, y0 + s * 0.44)

    def barrel(self, c, s=1.0, y0=0.0, g="carga", color=(0.55, 0.38, 0.24)):
        w = self.m("barril_%d" % int(color[0] * 100), color)
        d = self.m("barril_aro", (0.3, 0.28, 0.28))
        self.cyl(g, w, c, 0.36 * s, 0.4 * s, 0.5 * s, y0, 8)
        self.cyl(g, w, c, 0.4 * s, 0.34 * s, 0.5 * s, y0 + 0.5 * s, 8)
        self.cyl(g, d, c, 0.42 * s, 0.42 * s, 0.1 * s, y0 + 0.45 * s, 8, cap=False)

    def sack(self, c, s=1.0, g="carga", color=(0.74, 0.66, 0.48)):
        self.rock(g, self.m("saco_%d" % int(color[0] * 100), color), c, 0.42 * s, 0.0, 0.75, sub=1)

    def cargo(self, c, n=5, spread=1.6, g="carga"):
        """Pilha de carga: caixotes (alguns empilhados), barris e sacos."""
        rnd = self.rnd
        for i in range(n):
            a, d = rnd.uniform(0, math.tau), rnd.uniform(0.2, spread)
            p = (c[0] + math.cos(a) * d, c[1] + math.sin(a) * d)
            k = rnd.random()
            if k < 0.45:
                s = rnd.uniform(0.8, 1.1)
                self.crate(p, s, rnd.uniform(0, 90), 0.0, g)
                if rnd.random() < 0.4:
                    self.crate((p[0] + 0.1, p[1] - 0.1), s * 0.75, rnd.uniform(0, 90), s, g)
            elif k < 0.8:
                self.barrel(p, rnd.uniform(0.9, 1.15), 0.0, g)
            else:
                self.sack(p, rnd.uniform(0.9, 1.3), g)

    def rug(self, c, sx, sz, rot, col, trim, g="tapete"):
        """Tapete/pano no chão: de cima é uma mancha de cor viva (mercado, tenda)."""
        self.box(g, self.m("patch_tapete_%d_%d" % (int(col[0] * 100), int(col[2] * 100)), col), c, (sx, 0.02, sz), rot, 0.02)
        self.box(g, self.m("patch_tapete_%d_%d" % (int(trim[0] * 100), int(trim[2] * 100)), trim), c, (sx * 0.72, 0.02, sz * 0.62), rot, 0.03)

    def awning(self, c, sx, sz, rot, col, h=2.6, g="toldo", stripes=None):
        """Toldo sobre 4 postes: pano inclinado (cor viva de cima)."""
        wood = self.m("toldo_poste", (0.44, 0.32, 0.22))
        a = math.radians(rot)
        for ux in (-1, 1):
            for uz in (-1, 1):
                lx, lz = ux * sx * 0.46, uz * sz * 0.46
                p = (c[0] + lx * math.cos(a) + lz * math.sin(a), c[1] - lx * math.sin(a) + lz * math.cos(a))
                self.cyl(g, wood, p, 0.07, 0.07, h + (0.35 if uz > 0 else 0.0), 0.0, 5)
        cm = self.m("pano_toldo_%d_%d" % (int(col[0] * 100), int(col[2] * 100)), col)
        self.box(g, cm, c, (sx, 0.08, sz), rot, h + 0.1, tilt=(8.0, 0))
        if stripes:
            sm = self.m("pano_toldo_%d_%d" % (int(stripes[0] * 100), int(stripes[2] * 100)), stripes)
            for k in (-0.3, 0.0, 0.3):
                lx = k * sx
                p = (c[0] + lx * math.cos(a), c[1] - lx * math.sin(a))
                self.box(g, sm, p, (sx * 0.12, 0.085, sz * 1.01), rot, h + 0.105, tilt=(8.0, 0))

    def flag(self, c, col, h=5.0, rot=0.0, pole=(0.36, 0.28, 0.22), g="flamula", tatter=True, w=1.3, drop=1.9):
        """Flâmula: mastro fino e pano (com a barra rasgada em dentes se tatter)."""
        self.cyl(g, self.m("mastro_fl_%d" % int(pole[0] * 100), pole), c, 0.09, 0.06, h, 0.0, 5)
        cm = self.m("pano_fl_%d_%d" % (int(col[0] * 100), int(col[2] * 100)), col)
        hm = self.m("pano_fl_%d_%d_barra" % (int(col[0] * 100), int(col[2] * 100)), tuple(k * 0.8 for k in col))
        if tatter:                                           # barra em dentes: desce 0,5 m abaixo do pano, como os cones de antes
            self.cloth(g, cm, c, w, drop + 0.5, rot, h - drop - 0.6, 0.08, "teeth", hm)
            for _ in range(12):                              # os 3 dentes eram cones com sorteio: gasta os mesmos 12 (a sim da zona não muda)
                self.rnd.random()
        else:
            self.cloth(g, cm, c, w, drop, rot, h - drop - 0.1, 0.08, "swallow", hm)

    def cloth(self, g, m, c, w, drop, rot, y0, x0=0.0, tail="swallow", hem=None):
        """Pano dobrado (horde.cloth_mesh) pendurado em `c`, saindo na direção de `rot`; `hem` = cor da barra. Não sorteia."""
        import horde
        verts, faces, nh = horde.cloth_mesh(w, drop, tail)
        bm = self._bm_cloth(m, c[0], c[1])
        f = self._xf(c, rot, (0, 0))
        vs = [bm.verts.new(f(x0 + x, yb, up, y0)) for x, yb, up in verts]
        if hem is not None:
            bm = self._bm_cloth(hem, c[0], c[1])
        for fa in faces[:nh]:
            bm.faces.new([vs[i] for i in fa])
        bm = self._bm_cloth(m, c[0], c[1])
        for fa in faces[nh:]:
            bm.faces.new([vs[i] for i in fa])

    def slab(self, g, side, top, c, r, h=0.16, jitter=0.2, sx=1.0, rot=0.0, y=0.0, inset=0.82):
        """Placa de rocha baixa (crosta boiando na lava): contorno orgânico como o `blob` (gasta os mesmos 3 sorteios),
        mas com borda escura em talude e tampo mais claro: tem volume para o toon, não lê como buraco."""
        rnd = self.rnd
        ph = [rnd.uniform(0, math.tau) for _ in range(3)]
        segs = max(8, min(14, int(r * 8)))
        f = self._xf(c, rot, (0, 0))
        bm = self._bm(g, side, c[0], c[1])
        bot, up = [], []
        for i in range(segs):
            a = math.tau * i / segs
            rr = r * (1.0 + jitter * (0.6 * math.sin(2 * a + ph[0]) + 0.35 * math.sin(3 * a + ph[1]) + 0.25 * math.sin(5 * a + ph[2])))
            bot.append(bm.verts.new(f(math.cos(a) * rr * sx, math.sin(a) * rr, 0.0, y)))
            up.append(bm.verts.new(f(math.cos(a) * rr * sx * inset, math.sin(a) * rr * inset, h, y)))
        for i in range(segs):
            bm.faces.new((bot[i], bot[(i + 1) % segs], up[(i + 1) % segs], up[i]))
        bm = self._bm(g, top, c[0], c[1])
        bm.faces.new(up)

    def torch(self, c, h=2.2, g="tocha", fire="glow_brasa"):
        self.cyl(g, self.m("tocha_haste", (0.3, 0.24, 0.2)), c, 0.09, 0.07, h, 0.0, 5)
        self.cyl(g, self.m("tocha_copa", (0.22, 0.2, 0.2)), c, 0.12, 0.26, 0.3, h, 6)
        self.cyl(g, self.m(fire, (1.0, 0.56, 0.2)), c, 0.2, 0.0, 0.55, h + 0.28, 5)

    def brazier(self, c, s=1.0, g="tocha", fire="glow_brasa", color=(1.0, 0.56, 0.2)):
        iron = self.m("braseiro", (0.22, 0.2, 0.2))
        for k in range(3):
            a = math.tau * k / 3
            self.cyl(g, iron, (c[0] + math.cos(a) * 0.4 * s, c[1] + math.sin(a) * 0.4 * s), 0.06, 0.06, 0.9 * s, 0.0, 4)
        self.cyl(g, iron, c, 0.4 * s, 0.62 * s, 0.4 * s, 0.8 * s, 8)
        self.cyl(g, self.m(fire, color), c, 0.5 * s, 0.0, 0.9 * s, 1.15 * s, 6)

    def fence_run(self, a, b, h=1.0, g="cerca", color=(0.5, 0.38, 0.26), gap=2.2, sag=0.0):
        """Cerca de estacas e duas travessas entre dois pontos."""
        w = self.m("cerca_%d" % int(color[0] * 100), color)
        a, b = Vector(a), Vector(b)
        L = (b - a).length
        n = max(1, int(L / gap))
        rot = zone_lib.along((b - a).x, (b - a).y)
        for i in range(n + 1):
            p = a + (b - a) * (i / n)
            self.cyl(g, w, (p.x, p.y), 0.09, 0.08, h * self.rnd.uniform(0.95, 1.15), 0.0, 5, tilt=(self.rnd.uniform(-4, 4), self.rnd.uniform(-4, 4)))
        mid = (a + b) * 0.5
        for yy in (0.45, 0.8):
            self.box(g, w, (mid.x, mid.y), (L, 0.09, 0.07), rot, h * yy)

    def log(self, g, m, c, r, L, rot, y=None, r1=None):
        """Tora deitada, centrada em `c`, ao longo de `rot`."""
        a = math.radians(rot)
        st = (c[0] - math.cos(a) * L * 0.5, c[1] + math.sin(a) * L * 0.5)
        self.cyl(g, m, st, r, r if r1 is None else r1, L, r if y is None else y, 6, rot, tilt=(0, 90))

    def spikes(self, c, rot, L=3.6, g="barricada", color=(0.3, 0.24, 0.2)):
        """Cavalo de frisa: tora deitada com estacas cruzadas afiadas."""
        w = self.m("frisa_%d" % int(color[0] * 100), color)
        tip = self.m("frisa_ponta", (0.72, 0.62, 0.46))
        a = math.radians(rot)
        ux, uz = math.cos(a), -math.sin(a)
        vx, vz = -math.sin(a), -math.cos(a)
        self.log(g, w, c, 0.16, L, rot, 0.55)
        n = max(2, int(L / 0.7))
        for i in range(n):
            t = ((i + 0.5) / n - 0.5) * L
            p = (c[0] + ux * t, c[1] + uz * t)
            for s in (-1, 1):
                self.cyl(g, w, (p[0] + vx * 0.43 * s, p[1] + vz * 0.43 * s), 0.07, 0.05, 1.5, 0.0, 4, rot, tilt=(38.0 * s, 0))
                self.cyl(g, tip, (p[0] - vx * 0.49 * s, p[1] - vz * 0.49 * s), 0.06, 0.0, 0.4, 1.18, 4, rot, tilt=(38.0 * s, 0))

    def bones(self, c, n=4, spread=1.5, g="ossos", skull=True):
        b = self.m("osso", (0.9, 0.87, 0.78))
        rnd = self.rnd
        for _ in range(n):
            a, d = rnd.uniform(0, math.tau), rnd.uniform(0.2, spread)
            p = (c[0] + math.cos(a) * d, c[1] + math.sin(a) * d)
            L = rnd.uniform(0.6, 1.3)
            self.cyl(g, b, p, 0.05, 0.05, L * 0.8, 0.06, 5, rnd.uniform(0, 360), tilt=(0, 90))
        if skull:
            self.rock(g, b, c, 0.22, 0.0, 0.85, sub=1)

    def rowboat(self, c, rot, L=4.0, color=(0.5, 0.36, 0.24), g="barco", y0=0.0, tilt=(0, 0)):
        """Bote: casco em fuso (pontas afiladas), oco por dentro (fundo escuro abaixo da borda), dois bancos e remos."""
        hm = self.m("bote_%d_%d" % (int(color[0] * 100), int(color[2] * 100)), color)
        dk = self.m("bote_esc_%d" % int(color[0] * 100), tuple(x * 0.6 for x in color))
        f = self._xf(c, rot, tilt)
        W, H = L * 0.21, L * 0.14
        st = [-1.0, -0.8, -0.45, 0.0, 0.45, 0.8, 1.0]
        hw = [0.0 if abs(t) >= 1.0 else W * (1.0 - abs(t) ** 2.4) for t in st]
        topc = {(i, sgn): f(t * L * 0.5, sgn * hw[i], H + abs(t) ** 3 * H * 0.5, y0) for i, t in enumerate(st) for sgn in (-1, 1)}
        bm = self._bm(g, hm, c[0], c[1])
        top = {k: bm.verts.new(v) for k, v in topc.items()}
        bot = {(i, sgn): bm.verts.new(f(t * L * 0.42, sgn * hw[i] * 0.5, 0.0, y0)) for i, t in enumerate(st) for sgn in (-1, 1)}
        for i in range(len(st) - 1):
            for sgn in (-1, 1):
                bm.faces.new((top[(i, sgn)], top[(i + 1, sgn)], bot[(i + 1, sgn)], bot[(i, sgn)]))
            bm.faces.new((bot[(i, -1)], bot[(i + 1, -1)], bot[(i + 1, 1)], bot[(i, 1)]))
        bd = self._bm(g, dk, c[0], c[1])
        top2 = {k: bd.verts.new(v) for k, v in topc.items()}
        inner = {(i, sgn): bd.verts.new(f(t * L * 0.47, sgn * hw[i] * 0.82, H * 0.5, y0)) for i, t in enumerate(st) for sgn in (-1, 1)}
        for i in range(len(st) - 1):
            bd.faces.new((inner[(i, -1)], inner[(i + 1, -1)], inner[(i + 1, 1)], inner[(i, 1)]))
            for sgn in (-1, 1):                              # parede de dentro (da borda ao fundo)
                bd.faces.new((top2[(i, sgn)], top2[(i + 1, sgn)], inner[(i + 1, sgn)], inner[(i, sgn)]))
        a = math.radians(rot)
        for k in (-0.17, 0.17):
            p = (c[0] + math.cos(a) * k * L, c[1] - math.sin(a) * k * L)
            self.box(g, hm, p, (L * 0.07, 0.05, W * 1.7), rot, y0 + H * 0.8, tilt)
        self.box(g, hm, c, (L * 0.62, 0.05, 0.07), rot + 24.0, y0 + H * 1.05, tilt)

    def net_rack(self, c, rot, L=4.0, g="rede"):
        """Rede de pesca secando num varal: dois postes, travessa e o pano da rede com boias."""
        w = self.m("varal", (0.46, 0.34, 0.22))
        net = self.m("rede_pesca", (0.72, 0.68, 0.5))
        buoy = self.m("boia", (0.86, 0.36, 0.22))
        a = math.radians(rot)
        for s in (-1, 1):
            p = (c[0] + math.cos(a) * s * L * 0.5, c[1] - math.sin(a) * s * L * 0.5)
            self.cyl(g, w, p, 0.08, 0.07, 2.0, 0.0, 5)
        self.box(g, w, c, (L + 0.3, 0.08, 0.08), rot, 1.9)
        self.box(g, net, c, (L * 0.9, 1.5, 0.05), rot, 0.4, tilt=(12, 0))
        for k in (-0.3, 0.0, 0.3):
            p = (c[0] + math.cos(a) * k * L, c[1] - math.sin(a) * k * L)
            self.cyl(g, buoy, p, 0.13, 0.13, 0.22, 0.42, 6)

    def fish_rack(self, c, rot, g="rede"):
        w = self.m("varal", (0.46, 0.34, 0.22))
        fish = self.m("peixe_seco", (0.78, 0.6, 0.46))
        a = math.radians(rot)
        for s in (-1, 1):
            p = (c[0] + math.cos(a) * s * 1.2, c[1] - math.sin(a) * s * 1.2)
            self.cyl(g, w, p, 0.07, 0.06, 1.7, 0.0, 5)
        self.box(g, w, c, (2.7, 0.07, 0.07), rot, 1.6)
        for k in (-0.8, -0.4, 0.0, 0.4, 0.8):
            p = (c[0] + math.cos(a) * k, c[1] - math.sin(a) * k)
            self.box(g, fish, p, (0.16, 0.5, 0.06), rot, 1.05)

    def palm(self, c, h=6.0, lean=0.0, lean_dir=0.0, g="palmeira"):
        """Palmeira: tronco curvo em anéis e uma estrela de folhas caídas (de cima: uma roseta verde-viva)."""
        self.tall(c)
        tr = self.m("palmeira_tronco", (0.56, 0.44, 0.3))
        # folha inclinada pega sol e céu em cheio e sai bem mais clara que a cor do vértice (medido no jogo): tons fundos
        lf = self.m("palmeira_folha", (0.1, 0.3, 0.12))
        lf2 = self.m("palmeira_folha_c", (0.15, 0.38, 0.14))
        dx, dz = math.cos(lean_dir) * lean, math.sin(lean_dir) * lean
        pts = [(c[0] + dx * (t ** 1.7) * h, t * h, c[1] + dz * (t ** 1.7) * h) for t in (0.0, 0.25, 0.5, 0.75, 1.0)]
        self.tube(g, tr, pts, 0.3, 0.17, 6)
        top = pts[-1]
        a0 = self.rnd.uniform(0, 1)
        for tier, (n, Lk, droop, rise) in enumerate(((9, 0.4, 0.5, 0.12), (6, 0.27, 0.12, 0.3))):
            for i in range(n):
                a = a0 + tier * 0.4 + math.tau * i / n + self.rnd.uniform(-0.12, 0.12)
                L = h * Lk * self.rnd.uniform(0.85, 1.1)
                m = lf if (i + tier) % 2 else lf2
                tip = (top[0] + math.cos(a) * L, top[1] - L * droop, top[2] + math.sin(a) * L)
                mid = (top[0] + math.cos(a) * L * 0.5, top[1] + L * rise, top[2] + math.sin(a) * L * 0.5)
                bm = self._bm(g, m, c[0], c[1])
                nx, nz = -math.sin(a) * L * 0.13, math.cos(a) * L * 0.13
                v0 = bm.verts.new(B(top[0], top[2], top[1] + 0.1))
                v1 = bm.verts.new(B(mid[0] + nx, mid[2] + nz, mid[1] - 0.1))
                v2 = bm.verts.new(B(tip[0], tip[2], tip[1]))
                v3 = bm.verts.new(B(mid[0] - nx, mid[2] - nz, mid[1] - 0.1))
                vm = bm.verts.new(B(mid[0], mid[2], mid[1] + 0.12))
                for fa in ((v0, v1, vm), (v1, v2, vm), (v2, v3, vm), (v3, v0, vm), (v0, v3, v1), (v1, v3, v2)):
                    bm.faces.new(fa)
        self.rock(g, self.m("coco", (0.42, 0.3, 0.2)), (top[0], top[2]), 0.3, top[1] - 0.5, 0.9, sub=1)
        self.tall()

    def outcrop(self, c, r=3.0, n=4, color=(0.58, 0.5, 0.44), top=None, g="afloramento", hmul=1.0):
        """Afloramento: lajes inclinadas e empilhadas (silhueta de rocha sedimentar), com tampo mais claro."""
        rk = self.m("laje_%d_%d" % (int(color[0] * 100), int(color[2] * 100)), color)
        tp = top or tuple(min(1.0, x * 1.16) for x in color)
        tk = self.m("laje_%d_%d" % (int(tp[0] * 100), int(tp[2] * 100)), tp)
        rnd = self.rnd
        rot0 = rnd.uniform(0, 180)
        for i in range(n):
            a, d = rnd.uniform(0, math.tau), rnd.uniform(0, r * 0.55)
            p = (c[0] + math.cos(a) * d, c[1] + math.sin(a) * d)
            s = r * rnd.uniform(0.45, 0.8)
            h = s * rnd.uniform(0.5, 0.95) * hmul
            ti = (rnd.uniform(-12, 12), rnd.uniform(6, 16))
            self.cyl(g, rk, p, s, s * 0.82, h, -0.15, 6, rot0 + rnd.uniform(-20, 20), ti, jitter=0.2)
            self.cyl(g, tk, p, s * 0.82, s * 0.7, h * 0.16, -0.15 + h, 6, rot0 + rnd.uniform(-20, 20), ti, jitter=0.2)
        self.pebbles(g, rk, c, 6, r * 1.2, (0.2, 0.5))

    def standing_stone(self, c, h=3.2, color=(0.56, 0.52, 0.5), rune=None, g="menir", lean=6.0):
        s = self.m("menir_%d" % int(color[0] * 100), color)
        rot = self.rnd.uniform(0, 180)
        ti = (self.rnd.uniform(-lean, lean), self.rnd.uniform(-lean, lean))
        self.cyl(g, s, c, 0.62, 0.42, h, -0.1, 5, rot, ti, jitter=0.15)
        if rune:
            self.box(g, self.m("glow_runa_%d" % int(rune[2] * 100), rune), c, (0.5, 0.5, 0.06), rot + 20, h * 0.5, ti)

    def cairn(self, c, s=1.0, color=(0.6, 0.56, 0.5), g="menir"):
        m = self.m("marco_%d" % int(color[0] * 100), color)
        y = 0.0
        for k, r in enumerate((0.6, 0.48, 0.36, 0.24)):
            self.rock(g, m, (c[0] + self.rnd.uniform(-0.08, 0.08), c[1] + self.rnd.uniform(-0.08, 0.08)), r * s, y - r * s * 0.25, 0.6, sub=1)
            y += r * s * 0.62

    def totem(self, c, h=4.2, rot=0.0, cols=((0.6, 0.2, 0.16), (0.88, 0.84, 0.72), (0.84, 0.62, 0.24)), g="totem", horns=True):
        """Totem orc: toras pintadas empilhadas, asas/chifres, caveira no topo."""
        ms = [self.m("totem_%d_%d" % (int(k[0] * 100), int(k[2] * 100)), k) for k in cols]
        seg = h / 4
        for i in range(4):
            self.cyl(g, ms[i % len(ms)], c, 0.42 - i * 0.03, 0.4 - i * 0.03, seg, i * seg, 6, rot + i * 15)
        self.box(g, ms[0], c, (2.6, 0.3, 0.22), rot, h * 0.62)
        self.box(g, ms[2], c, (0.5, 0.36, 0.36), rot, h * 0.3)
        bone = self.m("osso", (0.9, 0.87, 0.78))
        self.rock(g, bone, c, 0.36, h - 0.1, 0.9, sub=1)
        if horns:
            a = math.radians(rot)
            for s in (-1, 1):
                p0 = (c[0] + math.cos(a) * s * 0.3, h + 0.15, c[1] - math.sin(a) * s * 0.3)
                p1 = (c[0] + math.cos(a) * s * 0.75, h + 0.3, c[1] - math.sin(a) * s * 0.75)
                p2 = (c[0] + math.cos(a) * s * 0.95, h + 0.8, c[1] - math.sin(a) * s * 0.95)
                self.tube(g, bone, [p0, p1, p2], 0.1, 0.02, 4)

    def weapon_rack(self, c, rot, g="armas"):
        w = self.m("cavalete", (0.4, 0.3, 0.22))
        iron = self.m("ferro", (0.6, 0.62, 0.66))
        a = math.radians(rot)
        for s in (-1, 1):
            p = (c[0] + math.cos(a) * s * 1.0, c[1] - math.sin(a) * s * 1.0)
            self.cyl(g, w, p, 0.08, 0.07, 1.5, 0.0, 5)
        self.box(g, w, c, (2.3, 0.08, 0.08), rot, 1.3)
        self.box(g, w, c, (2.3, 0.08, 0.08), rot, 0.5)
        for k in (-0.7, -0.25, 0.2, 0.65):
            p = (c[0] + math.cos(a) * k, c[1] - math.sin(a) * k)
            self.cyl(g, w, p, 0.035, 0.035, 2.1, 0.0, 4, rot, tilt=(10, 0))
            self.cyl(g, iron, (p[0] + math.sin(a) * 0.36, p[1] + math.cos(a) * 0.36), 0.09, 0.0, 0.45, 2.05, 4, rot, tilt=(10, 0))

    def target(self, c, rot, g="armas"):
        """Alvo de palha num tripé, com flechas."""
        self.cyl(g, self.m("cavalete", (0.4, 0.3, 0.22)), c, 0.07, 0.07, 1.3, 0.0, 5)
        self.cyl(g, self.m("alvo_palha", (0.8, 0.68, 0.4)), c, 0.62, 0.62, 0.22, 1.15, 10, rot, tilt=(90, 0))
        self.cyl(g, self.m("alvo_miolo", (0.74, 0.2, 0.16)), c, 0.26, 0.26, 0.26, 1.15, 8, rot, tilt=(90, 0))

    def cart(self, c, rot, g="carroca", broken=False, color=(0.5, 0.37, 0.25), load=None):
        """Carroça de mão/caravana; `broken` = tombada e sem uma roda (queimada se color escuro)."""
        w = self.m("carreta_%d" % int(color[0] * 100), color)
        wh = self.m("carreta_roda", (0.26, 0.2, 0.16))
        ti = (16, 9) if broken else (0, 0)
        a = math.radians(rot)
        self.box(g, w, c, (2.8, 0.22, 1.6), rot, 0.62, ti)
        for s in (-1, 1):
            off = (c[0] + math.sin(a) * s * 0.84, c[1] + math.cos(a) * s * 0.84)
            self.box(g, w, off, (2.8, 0.5, 0.08), rot, 0.8, ti)
            if not (broken and s > 0):
                self.cyl(g, wh, (off[0] + math.sin(a) * s * 0.1, off[1] + math.cos(a) * s * 0.1), 0.56, 0.56, 0.12, 0.56, 8, rot, tilt=(90, 0))
        for s in (-1, 1):
            p = (c[0] + math.cos(a) * 2.2 + math.sin(a) * s * 0.5, c[1] - math.sin(a) * 2.2 + math.cos(a) * s * 0.5)
            self.box(g, w, p, (1.8, 0.08, 0.08), rot, 0.62, ti)
        if broken:
            self.cyl(g, wh, (c[0] + 1.6, c[1] + 1.3), 0.56, 0.56, 0.12, 0.02, 8)
        if load:
            self.box(g, self.m("carga_lona_%d" % int(load[0] * 100), load), c, (2.2, 0.7, 1.3), rot, 0.84, ti)

    def hay(self, c, s=1.0, g="feno"):
        self.cyl(g, self.m("feno", (0.86, 0.74, 0.4)), c, 0.7 * s, 0.7 * s, 1.1 * s, 0.7 * s, 9, self.rnd.uniform(0, 180), tilt=(90, 0))

    def signpost(self, c, rot, g="placa", n=2):
        w = self.m("placa_poste", (0.44, 0.32, 0.22))
        b = self.m("placa_tabua", (0.74, 0.62, 0.42))
        self.cyl(g, w, c, 0.09, 0.08, 2.4, 0.0, 5)
        for i in range(n):
            self.box(g, b, c, (1.3, 0.32, 0.07), rot + i * 70.0, 1.9 - i * 0.42)

    def stalagmite(self, c, h=2.0, r=0.6, color=(0.4, 0.36, 0.3), g="estalagmite"):
        self.cyl(g, self.m("estalag_%d" % int(color[0] * 100), color), c, r, 0.0, h, -0.1, 6, self.rnd.uniform(0, 60),
                 (self.rnd.uniform(-5, 5), self.rnd.uniform(-5, 5)), jitter=0.18)

    def mushroom(self, c, s=1.0, cap=(0.5, 0.9, 0.8), g="cogumelo", glow=True):
        self.cyl(g, self.m("cogumelo_pe", (0.84, 0.8, 0.7)), c, 0.1 * s, 0.07 * s, 0.5 * s, 0.0, 5)
        name = ("glow_cog_%d_%d" if glow else "cog_%d_%d") % (int(cap[0] * 100), int(cap[2] * 100))
        self.cyl(g, self.m(name, cap), c, 0.36 * s, 0.08 * s, 0.24 * s, 0.46 * s, 7)

    def crystal(self, c, s=1.0, color=(0.5, 0.8, 1.0), g="cristal", n=3):
        m = self.m("glow_cristal_%d_%d" % (int(color[0] * 100), int(color[2] * 100)), color)
        for i in range(n):
            a = self.rnd.uniform(0, math.tau)
            p = (c[0] + math.cos(a) * 0.3 * s * (i > 0), c[1] + math.sin(a) * 0.3 * s * (i > 0))
            hh = s * (1.5 if i == 0 else self.rnd.uniform(0.6, 1.0))
            self.cyl(g, m, p, 0.24 * s, 0.14 * s, hh * 0.7, 0.0, 5, self.rnd.uniform(0, 70), (self.rnd.uniform(-16, 16) * (i > 0), self.rnd.uniform(-16, 16) * (i > 0)))
            self.cyl(g, m, p, 0.14 * s, 0.0, hh * 0.3, hh * 0.7, 5, 0, (0, 0))

    def planks(self, pts, w=1.5, y=0.08, g="passarela", color=(0.52, 0.4, 0.27), step=0.55):
        """Passarela de tábuas atravessadas ao longo de um caminho (visual: fica rente ao chão)."""
        m = self.m("tabua_%d" % int(color[0] * 100), color)
        m2 = self.m("tabua_%d" % int(color[0] * 86), tuple(x * 0.86 for x in color))
        poly = catmull(pts, step)
        for i in range(0, len(poly) - 1):
            t = poly[i + 1] - poly[i]
            if t.length < 1e-4:
                continue
            self.box(g, m if i % 3 else m2, (poly[i].x, poly[i].y), (step * 0.86, 0.07, w * self.rnd.uniform(0.9, 1.08)),
                     zone_lib.along(t.x, t.y) + self.rnd.uniform(-4, 4), y)

    def drum(self, c, r=0.8, g="tambor", color=(0.72, 0.16, 0.13)):
        self.cyl(g, self.m("tambor_c_%d" % int(color[0] * 100), color), c, r, r * 0.88, r * 1.1, 0.0, 9)
        self.cyl(g, self.m("tambor_pele", (0.9, 0.8, 0.58)), c, r * 0.9, r * 0.9, 0.05, r * 1.1, 9)

    def tent_hide(self, c, rot, s=1.0, color=(0.6, 0.46, 0.34), g="tenda", trim=(0.72, 0.16, 0.13)):
        """Tenda orc de couro: cone baixo sobre varas que cruzam no topo, com faixa pintada."""
        cm = self.m("couro_%d_%d" % (int(color[0] * 100), int(color[2] * 100)), color)
        self.cyl(g, cm, c, 1.9 * s, 0.25 * s, 2.5 * s, 0.0, 8, rot)
        self.cyl(g, self.m("couro_faixa_%d" % int(trim[0] * 100), trim), c, 1.93 * s, 1.5 * s, 0.6 * s, 0.25 * s, 8, rot, cap=False)
        wood = self.m("tenda_vara", (0.36, 0.28, 0.2))
        for k in range(3):
            self.cyl(g, wood, c, 0.05, 0.04, 3.4 * s, 0.0, 4, rot + k * 60, tilt=(14, 0))
        a = math.radians(rot)
        self.box(g, self.m("tenda_boca", (0.12, 0.1, 0.1)), (c[0] - math.sin(a) * 1.5 * s, c[1] - math.cos(a) * 1.5 * s), (0.9 * s, 1.3 * s, 0.5 * s), rot, 0.0, tilt=(-28, 0))

    def tent_aurora(self, c, rot, s=1.0, color=(0.93, 0.89, 0.78), trim=(0.3, 0.42, 0.72), gold=(0.96, 0.9, 0.62), g="tenda"):
        """Pavilhão de campanha da Aurora: parede redonda de lona, teto em cone com barra azul, mastro com flâmula dourada.
        Cabe no mesmo chão (e no mesmo colisor) da tenda de couro orc: é a peça que entra no lugar dela na retomada."""
        cm = self.m("lona_%d_%d" % (int(color[0] * 100), int(color[2] * 100)), color)
        tm = self.m("lona_barra_%d_%d" % (int(trim[0] * 100), int(trim[2] * 100)), trim)
        gm = self.m("lona_ouro_%d" % int(gold[0] * 100), gold)
        self.cyl(g, cm, c, 1.5 * s, 1.5 * s, 1.15 * s, 0.0, 8, rot, cap=False)
        self.cyl(g, tm, c, 1.86 * s, 1.5 * s, 0.34 * s, 1.0 * s, 8, rot, cap=False)          # beiral azul (lê de cima)
        self.cyl(g, cm, c, 1.5 * s, 0.16 * s, 1.5 * s, 1.34 * s, 8, rot)
        self.cyl(g, tm, c, 0.62 * s, 0.16 * s, 0.52 * s, 2.36 * s, 8, rot)                  # coifa azul
        self.cyl(g, self.m("mastro_fl_82", (0.82, 0.68, 0.48)), c, 0.05, 0.04, 0.9 * s, 2.84 * s, 4)
        self.cyl(g, gm, c, 0.13 * s, 0.0, 0.26 * s, 3.7 * s, 4)
        a = math.radians(rot)
        dx, dz = -math.sin(a), -math.cos(a)                                                  # a porta olha para o pátio
        self.box(g, gm, (c[0] + math.cos(a) * 0.32 * s, c[1] - math.sin(a) * 0.32 * s), (0.6 * s, 0.3 * s, 0.04), rot, 3.3 * s)
        self.box(g, self.m("tenda_boca", (0.12, 0.1, 0.1)), (c[0] + dx * 1.42 * s, c[1] + dz * 1.42 * s), (0.8 * s, 1.0 * s, 0.14 * s), rot, 0.0)
        for k in (-1, 1):                                                                    # abas da porta, abertas
            q = (c[0] + dx * 1.5 * s + math.cos(a) * k * 0.52 * s, c[1] + dz * 1.5 * s - math.sin(a) * k * 0.52 * s)
            self.box(g, tm, q, (0.26 * s, 1.05 * s, 0.08 * s), rot + k * 24.0, 0.0)

    def woodpile(self, c, rot, n=3, L=2.4, g="lenha", color=(0.56, 0.42, 0.28)):
        """Pilha de toras (pirâmide deitada)."""
        m = self.m("tora_%d" % int(color[0] * 100), color)
        a = math.radians(rot)
        vx, vz = -math.sin(a), -math.cos(a)
        for row in range(n):
            for k in range(n - row):
                off = (k - (n - row - 1) * 0.5) * 0.46
                self.log(g, m, (c[0] + vx * off, c[1] + vz * off), 0.22, L * self.rnd.uniform(0.92, 1.05), rot, 0.22 + row * 0.4)

    def crane(self, c, rot, h=7.0, reach=5.0, g="guindaste", load=True):
        """Guindaste de cais: poste, lança inclinada com escora, corda e um caixote pendurado."""
        w = self.m("guindaste", (0.42, 0.31, 0.21))
        rope = self.m("corda", (0.78, 0.7, 0.5))
        a = math.radians(rot)
        ux, uz = math.cos(a), -math.sin(a)
        self.box(g, w, c, (1.8, 0.35, 1.8), rot, 0.0)
        self.cyl(g, w, c, 0.26, 0.2, h, 0.3, 6)
        tip = (c[0] + ux * reach, h + 1.6, c[1] + uz * reach)
        self.tube(g, w, [(c[0] - ux * 1.2, h - 0.6, c[1] - uz * 1.2), (c[0], h + 0.2, c[1]), tip], 0.17, 0.12, 5)
        self.tube(g, w, [(c[0], h * 0.55, c[1]), (c[0] + ux * reach * 0.55, h + 0.75, c[1] + uz * reach * 0.55)], 0.1, 0.1, 4)
        self.tube(g, rope, [tip, (tip[0], 2.6 if load else 4.0, tip[2])], 0.04, 0.04, 4)
        if load:
            self.crate((tip[0], tip[2]), 1.1, rot + 20.0, 1.5, g)

    def ship_rig(self, c, rot, L, flag=(0.3, 0.42, 0.72), flag2=(0.96, 0.9, 0.62), stripe=(0.86, 0.8, 0.62), g="navio"):
        """Aparelho de um navio do sea.ship (rumo `rot` na convenção de lá): gurupés, cesto da gávea, flâmulas, cordame, faixa
        clara no casco, leme e lanterna de popa."""
        a = math.radians(rot)
        fx, fz = math.cos(a), math.sin(a)
        w = self.m("navio_madeira", (0.34, 0.24, 0.17))
        rope = self.m("corda", (0.78, 0.7, 0.5))
        self.box(g, self.m("navio_faixa_%d" % int(stripe[0] * 100), stripe), c, (L * 1.005, 0.32, L * 0.286), -rot, 1.5)
        bow = (c[0] + fx * L * 0.6, c[1] + fz * L * 0.6)
        self.tube(g, w, [(bow[0] - fx * 1.0, 2.5, bow[1] - fz * 1.0), (bow[0] + fx * 1.6, 3.4, bow[1] + fz * 1.6), (bow[0] + fx * 3.6, 4.6, bow[1] + fz * 3.6)], 0.16, 0.07, 5)
        tops = []
        for i, t in enumerate((0.18, -0.12)):
            q = (c[0] + fx * L * t, c[1] + fz * L * t)
            h = L * 0.75 if i == 0 else L * 0.6
            top = 2.4 + h
            tops.append((q, top))
            self.cyl(g, w, q, 0.5, 0.62, 0.5, 2.4 + h * 0.78, 8)
            self.box(g, w, q, (0.14, 0.14, L * 0.3), -rot, 2.4 + h * 0.3 - 0.1)
            self.box(g, w, q, (0.14, 0.14, L * 0.24), -rot, 2.4 + h * 0.85)
            fm = self.m("pano_fl_%d_%d" % (int((flag if i == 0 else flag2)[0] * 100), int((flag if i == 0 else flag2)[2] * 100)), flag if i == 0 else flag2)
            self.cloth(g, fm, q, 1.5, 0.8, 180.0 - rot, top - 0.9, 0.0, None)
        (q0, t0), (q1, t1) = tops
        stern = (c[0] - fx * L * 0.5, c[1] - fz * L * 0.5)
        for pa, pb in (((q0[0], t0, q0[1]), (bow[0] + fx * 3.4, 4.5, bow[1] + fz * 3.4)), ((q0[0], t0 - 0.5, q0[1]), (q1[0], t1 - 0.5, q1[1])), ((q1[0], t1, q1[1]), (stern[0], 4.2, stern[1]))):
            self.tube(g, rope, [pa, pb], 0.035, 0.035, 3)
        for s in (-1, 1):
            side = (-fz * s * L * 0.135, fx * s * L * 0.135)
            for (q, t) in tops:
                self.tube(g, rope, [(q[0], t * 0.82, q[1]), (q[0] + side[0], 2.5, q[1] + side[1])], 0.03, 0.03, 3)
        self.box(g, w, (stern[0] - fx * 0.5, stern[1] - fz * 0.5), (0.9, 2.2, 0.16), -rot, -0.4)
        self.cyl(g, self.m("glow_lanterna", (1.0, 0.82, 0.45)), (stern[0] - fx * 0.2, stern[1] - fz * 0.2), 0.22, 0.22, 0.4, 4.3, 6)

    def scarecrow(self, c, rot=0.0, g="espantalho"):
        w = self.m("espantalho_pau", (0.42, 0.32, 0.22))
        self.cyl(g, w, c, 0.07, 0.06, 2.3, 0.0, 5)
        self.box(g, w, c, (1.8, 0.08, 0.08), rot, 1.6)
        self.box(g, self.m("espantalho_roupa", (0.5, 0.36, 0.56)), c, (1.0, 0.8, 0.3), rot, 1.0)
        self.rock(g, self.m("feno", (0.86, 0.74, 0.4)), c, 0.3, 1.9, 0.9)
        self.cyl(g, self.m("espantalho_chapeu", (0.34, 0.26, 0.2)), c, 0.5, 0.12, 0.4, 2.3, 7)

    def laundry(self, a, b, h=2.5, g="varal", cols=((0.9, 0.9, 0.86), (0.5, 0.66, 0.86), (0.9, 0.56, 0.5), (0.94, 0.82, 0.5))):
        """Varal de roupa entre dois pontos: corda em barriga e panos coloridos (de cima: uma fila de cores)."""
        a, b = Vector(a), Vector(b)
        rope = self.m("corda", (0.78, 0.7, 0.5))
        w = self.m("varal", (0.46, 0.34, 0.22))
        for p in (a, b):
            self.cyl(g, w, (p.x, p.y), 0.07, 0.06, h + 0.1, 0.0, 5)
        mid = (a + b) * 0.5
        self.tube(g, rope, [(a.x, h, a.y), (mid.x, h - 0.25, mid.y), (b.x, h, b.y)], 0.03, 0.03, 3)
        rot = zone_lib.along((b - a).x, (b - a).y)
        n = max(2, int((b - a).length / 1.1))
        for i in range(n):
            t = (i + 0.5) / n
            p = a + (b - a) * t
            c = cols[(i * 3 + int(a.x)) % len(cols)]
            self.box(g, self.m("pano_varal_%d_%d" % (int(c[0] * 100), int(c[2] * 100)), c), (p.x, p.y), (0.7, 0.9, 0.05), rot, h - 1.05 - 0.2 * math.sin(math.pi * t))

    # ------------------------------------------------------------------ vida dos mapas (pesca, treino, cozinha, obra, mina)
    def fishing_pole(self, c, rot, L=3.4, y0=0.0, g="pesca", water_y=0.05):
        """Vara de pescar fincada num apoio, apontando para `rot` (para a água): vara em arco, linha até a boia, balde de
        peixe e um banquinho. y0 = altura do piso (píer)."""
        w = self.m("vara_pesca", (0.56, 0.44, 0.26))
        d = self.m("vara_apoio", (0.36, 0.27, 0.19))
        a = math.radians(rot)
        ux, uz = math.cos(a), -math.sin(a)
        self.cyl(g, d, c, 0.07, 0.06, 0.55, y0, 5)
        pts = [(c[0] - ux * 0.5, y0 + 0.25, c[1] - uz * 0.5), (c[0], y0 + 0.62, c[1]),
               (c[0] + ux * L * 0.5, y0 + 1.75, c[1] + uz * L * 0.5), (c[0] + ux * L * 0.85, y0 + 2.2, c[1] + uz * L * 0.85),
               (c[0] + ux * L, y0 + 2.15, c[1] + uz * L)]
        self.tube(g, w, pts, 0.045, 0.014, 4)
        tip = pts[-1]
        fl = (c[0] + ux * (L + 0.5), water_y, c[1] + uz * (L + 0.5))
        self.tube(g, self.m("linha_pesca", (0.93, 0.93, 0.9)), [tip, (fl[0], fl[1] + 0.25, fl[2])], 0.012, 0.012, 3)
        self.cyl(g, self.m("boia", (0.86, 0.36, 0.22)), (fl[0], fl[2]), 0.09, 0.09, 0.12, water_y, 6)
        self.cyl(g, self.m("boia_branca", (0.95, 0.95, 0.92)), (fl[0], fl[2]), 0.07, 0.0, 0.14, water_y + 0.12, 6)
        b = (c[0] + uz * 0.75, c[1] - ux * 0.75)                 # balde com peixe, ao lado
        self.cyl(g, self.m("balde", (0.5, 0.4, 0.3)), b, 0.2, 0.26, 0.36, y0, 7)
        self.cyl(g, self.m("peixe_fresco", (0.62, 0.74, 0.82)), b, 0.2, 0.05, 0.12, y0 + 0.34, 6)
        s = (c[0] - uz * 0.8 - ux * 0.3, c[1] + ux * 0.8 - uz * 0.3)
        self.cyl(g, d, s, 0.24, 0.2, 0.4, y0, 6)                 # banquinho de toco

    def drill_post(self, c, rot, g="treino", shield=(0.72, 0.16, 0.13), boss=None, crest=None):
        """Boneco de treino: poste com travessa, tronco de palha amarrado, balde na cabeça e um escudo velho no braço.
        `boss` = cor do umbigo do escudo (padrão ferro); `crest` = cor de uma faixa no peito e de um penacho no balde
        (o boneco da Aurora: escudo azul, umbigo e faixa dourados). Gasta 56 sorteios do lote sem `crest`."""
        w = self.m("cavalete", (0.4, 0.3, 0.22))
        straw = self.m("alvo_palha", (0.8, 0.68, 0.4))
        rope = self.m("corda", (0.78, 0.7, 0.5))
        iron = self.m("ferro", (0.6, 0.62, 0.66))
        a = math.radians(rot)
        ux, uz = math.cos(a), -math.sin(a)
        self.cyl(g, w, c, 0.13, 0.11, 2.0, 0.0, 6)
        self.box(g, w, c, (1.0, 0.1, 0.16), rot, 0.0)
        self.box(g, w, c, (0.16, 0.1, 1.0), rot, 0.0)
        self.box(g, w, c, (1.7, 0.12, 0.12), rot, 1.42)
        self.cyl(g, straw, c, 0.3, 0.36, 0.8, 0.72, 8)
        for yy in (0.88, 1.3):
            self.cyl(g, rope, c, 0.37, 0.37, 0.07, yy, 8, cap=False)
        self.cyl(g, iron, c, 0.26, 0.22, 0.34, 1.98, 8)
        e = (c[0] + ux * 0.86, c[1] + uz * 0.86)
        self.cyl(g, self.m("escudo_treino_%d" % int(shield[0] * 100), shield), e, 0.42, 0.42, 0.08, 1.42, 8, rot, tilt=(90, 0))
        self.cyl(g, iron if boss is None else self.m("escudo_umbigo_%d" % int(boss[0] * 100), boss), e, 0.12, 0.05, 0.14, 1.42, 6, rot, tilt=(90, 0))
        e2 = (c[0] - ux * 0.8, c[1] - uz * 0.8)
        self.cyl(g, w, e2, 0.04, 0.04, 1.0, 0.45, 4)             # espada de pau pendurada
        if crest is not None:
            cm = self.m("treino_faixa_%d_%d" % (int(crest[0] * 100), int(crest[2] * 100)), crest)
            self.cyl(g, cm, c, 0.385, 0.385, 0.16, 1.05, 8, cap=False)          # faixa no peito
            self.cyl(g, cm, c, 0.08, 0.0, 0.42, 2.32, 5)                        # penacho no balde

    def cookfire(self, c, s=1.0, rot=0.0, g="cozinha", fire="glow_brasa"):
        """Fogo de cozinha do acampamento: roda de pedras, brasa, lenha, duas forquilhas com travessa e panela pendurada,
        toco de sentar e tigelas."""
        stone = self.m("fogo_pedra", (0.5, 0.47, 0.45))
        w = self.m("cavalete", (0.4, 0.3, 0.22))
        iron = self.m("braseiro", (0.22, 0.2, 0.2))
        a = math.radians(rot)
        ux, uz = math.cos(a), -math.sin(a)
        for k in range(8):
            t = math.tau * k / 8
            self.rock(g, stone, (c[0] + math.cos(t) * 0.72 * s, c[1] + math.sin(t) * 0.72 * s), 0.2 * s, 0.0, 0.7)
        self.blob(g, self.m("patch_cinza_fogo", (0.24, 0.22, 0.22)), c, 1.0 * s, 0.0082, 0.25, 9)
        for k in range(3):
            self.log(g, w, c, 0.07 * s, 1.0 * s, rot + k * 60.0, 0.1)
        self.cyl(g, self.m(fire, (1.0, 0.56, 0.2)), c, 0.36 * s, 0.0, 0.6 * s, 0.12, 6)
        for sg in (-1, 1):
            p = (c[0] + ux * sg * 1.05 * s, c[1] + uz * sg * 1.05 * s)
            self.cyl(g, w, p, 0.07, 0.06, 1.55 * s, 0.0, 5)
        self.box(g, w, c, (2.3 * s, 0.07, 0.07), rot, 1.42 * s)
        self.cyl(g, iron, c, 0.02, 0.02, 0.42 * s, 0.98 * s, 4)
        self.cyl(g, iron, c, 0.28 * s, 0.36 * s, 0.36 * s, 0.62 * s, 8)
        self.cyl(g, self.m("ensopado", (0.72, 0.5, 0.26)), c, 0.33 * s, 0.33 * s, 0.03, 0.96 * s, 8)
        q = (c[0] - uz * 1.5 * s, c[1] + ux * 1.5 * s)
        self.cyl(g, w, q, 0.28, 0.24, 0.42, 0.0, 7)
        q2 = (c[0] + uz * 1.4 * s + ux * 0.5, c[1] - ux * 1.4 * s + uz * 0.5)
        for k in range(3):
            self.cyl(g, self.m("tigela", (0.8, 0.7, 0.52)), q2, 0.2 - k * 0.012, 0.24 - k * 0.012, 0.07, k * 0.075, 7)

    def scaffold(self, c, rot, L=5.0, h=4.4, g="andaime", cloth=(0.3, 0.42, 0.72), depth=1.3):
        """Andaime de obra encostado num muro (ao longo de `rot`): quatro montantes, dois pisos de tábuas, travas em X,
        escada de mão, tábuas e balde no chão, pano da cor de quem conserta."""
        w = self.m("andaime", (0.62, 0.48, 0.3))
        w2 = self.m("andaime_tabua", (0.74, 0.6, 0.4))
        a = math.radians(rot)
        ux, uz = math.cos(a), -math.sin(a)
        vx, vz = math.sin(a), math.cos(a)
        for sl in (-1, 1):
            for sd in (-1, 1):
                p = (c[0] + ux * sl * L * 0.5 + vx * sd * depth * 0.5, c[1] + uz * sl * L * 0.5 + vz * sd * depth * 0.5)
                self.cyl(g, w, p, 0.085, 0.075, h + 0.5, 0.0, 5)
        for yy in (h * 0.5, h):
            self.box(g, w2, c, (L + 0.5, 0.09, depth + 0.25), rot, yy)
            self.box(g, w, c, (L + 0.2, 0.1, 0.1), rot, yy - 0.12)
        for sd in (-1, 1):
            p0 = (c[0] - ux * L * 0.5 + vx * sd * depth * 0.5, c[1] - uz * L * 0.5 + vz * sd * depth * 0.5)
            p1 = (c[0] + ux * L * 0.5 + vx * sd * depth * 0.5, c[1] + uz * L * 0.5 + vz * sd * depth * 0.5)
            self.tube(g, w, [(p0[0], 0.2, p0[1]), (p1[0], h * 0.5 - 0.15, p1[1])], 0.05, 0.05, 4)
            self.tube(g, w, [(p1[0], h * 0.5 + 0.15, p1[1]), (p0[0], h - 0.15, p0[1])], 0.05, 0.05, 4)
        lx, lz = c[0] + ux * (L * 0.5 + 0.55), c[1] + uz * (L * 0.5 + 0.55)       # escada de mão na ponta
        for sd in (-1, 1):
            b0 = (lx + vx * sd * 0.28 + ux * 0.9, 0.0, lz + vz * sd * 0.28 + uz * 0.9)
            b1 = (lx + vx * sd * 0.28 - ux * 0.3, h + 0.5, lz + vz * sd * 0.28 - uz * 0.3)
            self.tube(g, w, [b0, b1], 0.05, 0.05, 4)
        n = int(h / 0.5)
        for k in range(1, n + 1):
            t = k / (n + 1)
            self.box(g, w, (lx + ux * (0.9 - 1.2 * t), lz + uz * (0.9 - 1.2 * t)), (0.07, 0.06, 0.62), rot, (h + 0.5) * t)
        self.box(g, self.m("pano_obra_%d_%d" % (int(cloth[0] * 100), int(cloth[2] * 100)), cloth), (c[0] + vx * (depth * 0.5 + 0.1), c[1] + vz * (depth * 0.5 + 0.1)), (L * 0.5, 1.3, 0.05), rot, h - 1.35)
        q = (c[0] + vx * (depth * 0.5 + 1.0) - ux * 0.8, c[1] + vz * (depth * 0.5 + 1.0) - uz * 0.8)
        for k in range(3):
            self.box(g, w2, (q[0] + vx * k * 0.06, q[1] + vz * k * 0.06), (2.6, 0.07, 0.3), rot + k * 4.0, k * 0.075)
        self.cyl(g, self.m("balde", (0.5, 0.4, 0.3)), (q[0] + ux * 2.0, q[1] + uz * 2.0), 0.2, 0.26, 0.36, 0.0, 7)

    def ore_cart(self, c, rot, g="mina", ore=(0.86, 0.72, 0.36), full=True):
        """Vagonete de minério: caçamba de tábuas com cinta de ferro, quatro rodas e pedra brilhante até a boca."""
        w = self.m("vagonete", (0.44, 0.32, 0.22))
        iron = self.m("braseiro", (0.22, 0.2, 0.2))
        a = math.radians(rot)
        ux, uz = math.cos(a), -math.sin(a)
        vx, vz = math.sin(a), math.cos(a)
        self.box(g, iron, c, (1.5, 0.1, 0.7), rot, 0.26)
        self.box(g, w, c, (1.6, 0.62, 1.0), rot, 0.36)
        self.box(g, iron, c, (1.66, 0.09, 1.06), rot, 0.9)
        self.box(g, iron, c, (0.12, 0.66, 1.05), rot, 0.34)
        for sl in (-1, 1):
            for sd in (-1, 1):
                p = (c[0] + ux * sl * 0.5 + vx * sd * 0.5, c[1] + uz * sl * 0.5 + vz * sd * 0.5)
                self.cyl(g, iron, p, 0.24, 0.24, 0.1, 0.24, 8, rot, tilt=(90, 0))
        if full:
            om = self.m("minerio_%d" % int(ore[0] * 100), ore)
            gl = self.m("glow_minerio", (1.0, 0.86, 0.4))
            for k in range(5):
                p = (c[0] + ux * (k - 2) * 0.28, c[1] + uz * (k - 2) * 0.28)
                self.rock(g, gl if k == 2 else om, p, 0.24 if k % 2 else 0.3, 0.86, 0.75)

    def rails(self, pts, g="mina", gauge=0.5):
        """Trilho de mina por uma linha de pontos (x, z): dormentes de madeira e dois trilhos de ferro."""
        w = self.m("dormente", (0.36, 0.27, 0.2))
        iron = self.m("trilho", (0.4, 0.4, 0.44))
        for i in range(len(pts) - 1):
            a, b = Vector(pts[i]), Vector(pts[i + 1])
            L = (b - a).length
            if L < 0.2:
                continue
            rot = zone_lib.along((b - a).x, (b - a).y)
            mid = (a + b) * 0.5
            t = (b - a).normalized()
            nr = Vector((-t.y, t.x))
            for sd in (-1, 1):
                q = mid + nr * sd * gauge
                self.box(g, iron, (q.x, q.y), (L + 0.05, 0.08, 0.08), rot, 0.09)
            k = 0.3
            while k < L:
                q = a + t * k
                self.box(g, w, (q.x, q.y), (0.2, 0.09, gauge * 2 + 0.5), rot, 0.0)
                k += 0.75

    def pickaxe(self, c, rot, g="mina", lean=24.0):
        """Picareta encostada (cabo inclinado, cabeça de ferro em arco)."""
        w = self.m("cavalete", (0.4, 0.3, 0.22))
        iron = self.m("ferro", (0.6, 0.62, 0.66))
        a = math.radians(rot)
        ux, uz = math.cos(a), -math.sin(a)
        vx, vz = math.sin(a), math.cos(a)
        sl, cl = math.sin(math.radians(lean)), math.cos(math.radians(lean))
        top = (c[0] + ux * 1.25 * sl, 1.25 * cl, c[1] + uz * 1.25 * sl)
        self.tube(g, w, [(c[0], 0.0, c[1]), top], 0.045, 0.04, 4)
        self.tube(g, iron, [(top[0] - vx * 0.5, top[1] - 0.2, top[2] - vz * 0.5), (top[0] - vx * 0.2, top[1] + 0.02, top[2] - vz * 0.2), (top[0], top[1] + 0.06, top[2]),
                            (top[0] + vx * 0.2, top[1] + 0.02, top[2] + vz * 0.2), (top[0] + vx * 0.5, top[1] - 0.2, top[2] + vz * 0.5)], 0.03, 0.03, 4)

    def ore_pile(self, c, n=5, g="mina", ore=(0.86, 0.72, 0.36), rock=(0.42, 0.38, 0.34)):
        """Monte de pedra tirada da parede, com uns veios que brilham."""
        om = self.m("minerio_%d" % int(ore[0] * 100), ore)
        rm = self.m("entulho_%d" % int(rock[0] * 100), rock)
        gl = self.m("glow_minerio", (1.0, 0.86, 0.4))
        rnd = self.rnd
        for k in range(n):
            t, dd = rnd.uniform(0, math.tau), rnd.uniform(0.0, 0.9)
            self.rock(g, gl if k == 0 else (om if k % 2 else rm), (c[0] + math.cos(t) * dd, c[1] + math.sin(t) * dd), rnd.uniform(0.22, 0.42), 0.0, 0.7)
