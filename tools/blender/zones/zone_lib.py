"""Biblioteca das zonas estilo Erenshor (RagnaEx). Cada build_<zona>.py descreve o layout com dados e chama isto.

Convenções (CLAUDE.md → "Layout de zonas"):
  * coordenadas dos dados = jogo (x, z), -z = norte; Blender (x, y) = jogo (x, -z)
  * visual na Collection Z_<zona> → assets/models/map_<zona>.glb (só a cena RagnaEx_<zona>)
  * sim em data/zones/<zona>.json: obstáculos (hidden = só colisão), props (viram prop_<kind>), spawners,
    NPCs, hangouts, portais, estradas/água (a grama evita)
  * marcadores OB_box_*, SPAWN_mob_*, TRIG_portal_* e câmeras CAM_top/CAM_game/CAM_poi para avaliar
"""
import bpy
import bmesh
import json
import math
import os
import random
from mathutils import Vector

ROOT = os.environ.get("RAGNAEX_ROOT", r"C:/Users/luisf/Desktop/projects/ragnaex").replace("\\", "/")   # worktree: RAGNAEX_ROOT
ROAD_W = 4.2


def B(x, z, y=0.0):
    """jogo (x, z) -> Blender."""
    return Vector((x, -z, y))


def along(dx, dz):
    """Rotação Y do jogo (graus) que alinha o eixo x local com a direção (dx, dz) do jogo."""
    return math.degrees(math.atan2(-dz, dx))


def catmull(pts, spacing=2.0):
    pts = [Vector((p[0], p[1])) for p in pts]
    ext = [pts[0] * 2 - pts[1]] + pts + [pts[-1] * 2 - pts[-2]]
    out = []
    for k in range(1, len(ext) - 2):
        p0, p1, p2, p3 = ext[k - 1], ext[k], ext[k + 1], ext[k + 2]
        n = max(2, int((p2 - p1).length / spacing))
        for s in range(n):
            t = s / n
            out.append(0.5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t * t + (-p0 + 3 * p1 - 3 * p2 + p3) * t ** 3))
    out.append(pts[-1])
    return out


def seg_dist(p, a, b):
    ab = b - a
    t = max(0.0, min(1.0, (p - a).dot(ab) / max(ab.length_squared, 1e-9)))
    return (a + ab * t - p).length


def poly_dist(p, poly):
    return min(seg_dist(p, poly[i], poly[i + 1]) for i in range(len(poly) - 1))


# Giro de cada mapa de fortaleza (graus, horário visto de cima) = rumo do portal de saída na zona-mãe (0 = norte, 90 = leste):
# quem sai do Bastião pelo oeste chega na fortaleza pelo LESTE dela. O desenho de toda fortaleza é "chegada ao sul" (0, 96);
# Zone.apply_turn gira dados e malhas no fim do build. O teste `_check_world_layout` confere saída x chegada de todo portal.
FORT_TURN = {"fort_ghoul": 270.0, "fort_bones": 0.0, "fort_frost": 180.0, "lich_citadel": 42.0,
             "fort_trolls": 270.0, "fort_war": 60.0, "fort_fire": 125.0,
             "kharzun_citadel": 0.0}      # Monte Kharzun sai pelo norte (build_kharzun.py): a cidadela não gira


def turned(p, deg):
    """Ponto do desenho original (x, z) -> depois do giro de `deg` graus (o mesmo de Zone.apply_turn)."""
    a = math.radians(deg)
    return (round(p[0] * math.cos(a) - p[1] * math.sin(a), 2), round(p[0] * math.sin(a) + p[1] * math.cos(a), 2))


def fort_arrive(fid, p=(0.0, 96.0)):
    """Chegada no mapa da fortaleza `fid` (o `target_pos` do portal da zona-mãe), já girada."""
    return turned(p, FORT_TURN.get(fid, 0.0))


BRIDGE_MIN_ANGLE = 60.0       # graus entre estrada e rio no cruzamento (90 = perpendicular). O vão que a sim abre no rio é reto
                              # (atravessado ao rio): em ponte enviesada as bordas do tabuleiro ficam sobre água sólida (run_tests BRIDGE_SQUARE)


def seg_hit(a, b, c, d):
    """Interseção dos segmentos ab e cd (Vector 2D) ou None — a mesma conta de Geometry2D.segment_intersects_segment."""
    r, s = b - a, d - c
    den = r.x * s.y - r.y * s.x
    if abs(den) < 1e-9:
        return None
    t = ((c.x - a.x) * s.y - (c.y - a.y) * s.x) / den
    u = ((c.x - a.x) * r.y - (c.y - a.y) * r.x) / den
    return a + r * t if 0.0 <= t <= 1.0 and 0.0 <= u <= 1.0 else None


def angdiff(a, b):
    return abs((a - b + math.pi) % math.tau - math.pi)


def mat(name, color, rough=0.9):
    m = bpy.data.materials.get(name)
    if m is None:
        m = bpy.data.materials.new(name)
        m.use_nodes = True
    bsdf = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    bsdf.inputs["Base Color"].default_value = (*color, 1.0)
    bsdf.inputs["Roughness"].default_value = rough
    m.diffuse_color = (*color, 1.0)
    return m


def mat_c(name, color, rough=0.9):
    """`mat` para nome montado com parte dos canais da cor (ex.: pano_<r>_<b>): se o nome já existe com OUTRA cor, a nova
    ganha nome próprio (`_g<verde>`) em vez de repintar a antiga (o `mat` repinta: a última cor valia para todas)."""
    base, k = name, 0
    while True:
        m = bpy.data.materials.get(name)
        if m is None or all(abs(m.diffuse_color[i] - color[i]) < 1e-4 for i in range(3)):
            return mat(name, color, rough)
        name = "%s_g%d" % (base, int(color[1] * 100)) if k == 0 else "%s_g%d_%d" % (base, int(color[1] * 100), k)
        k += 1


# ---------------------------------------------------------------------------
# geometria (tudo em coordenadas do jogo)
# ---------------------------------------------------------------------------
def _obj(coll, name, bm, material):
    me = bpy.data.meshes.new(name + "_mesh")
    bm.to_mesh(me)
    bm.free()
    o = bpy.data.objects.new(name, me)
    coll.objects.link(o)
    for m in (material if isinstance(material, list) else [material]):
        me.materials.append(m)
    return o


def ribbon(coll, name, poly, w, y, material):
    bm = bmesh.new()
    left, right = [], []
    for i, p in enumerate(poly):
        a = poly[max(0, i - 1)]
        b = poly[min(len(poly) - 1, i + 1)]
        t = (b - a).normalized()
        n = Vector((-t.y, t.x))
        left.append(bm.verts.new(B(p.x + n.x * w / 2, p.y + n.y * w / 2, y)))
        right.append(bm.verts.new(B(p.x - n.x * w / 2, p.y - n.y * w / 2, y)))
    for i in range(len(poly) - 1):
        bm.faces.new((left[i], right[i], right[i + 1], left[i + 1]))
    bm.normal_update()
    for f in bm.faces:
        if f.normal.z < 0:
            f.normal_flip()
    return _obj(coll, name, bm, material)


def disc(coll, name, c, r, y, material, segs=48, jitter=0.0, seed=0):
    rnd = random.Random(seed)
    bm = bmesh.new()
    center = bm.verts.new(B(c[0], c[1], y))
    ring = []
    # borda orgânica e suave (soma de senos), com segmentos curtos: sem quinas visíveis de perto
    ph = [rnd.uniform(0, math.tau) for _ in range(3)]
    if jitter > 0:
        segs = max(segs, min(240, int(r * 9)))
    for i in range(segs):
        a = math.tau * i / segs
        rr = r * (1.0 + jitter * (0.6 * math.sin(3 * a + ph[0]) + 0.3 * math.sin(5 * a + ph[1]) + 0.18 * math.sin(9 * a + ph[2])))
        ring.append(bm.verts.new(B(c[0] + math.cos(a) * rr, c[1] + math.sin(a) * rr, y)))
    for i in range(segs):
        bm.faces.new((center, ring[i], ring[(i + 1) % segs]))
    bm.normal_update()
    for f in bm.faces:
        if f.normal.z < 0:
            f.normal_flip()
    return _obj(coll, name, bm, material)


def box(coll, name, c, size, rot_deg, material, y0=0.0):
    """Caixa: centro (x,z), tamanho (x, altura, z), rotação Y do jogo (graus) = rotação Z do Blender."""
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    a = math.radians(rot_deg)
    for v in bm.verts:
        x, yb, zb = v.co.x * size[0], v.co.y * size[2], (v.co.z + 0.5) * size[1]
        rx = x * math.cos(a) - yb * math.sin(a)
        ry = x * math.sin(a) + yb * math.cos(a)
        v.co = Vector((c[0] + rx, -c[1] + ry, y0 + zb))
    return _obj(coll, name, bm, material)


def cyl(coll, name, c, r_bot, r_top, h, material, y0=0.0, segs=12, jitter=0.0, seed=0):
    rnd = random.Random(seed)
    bm = bmesh.new()
    bot, top = [], []
    for i in range(segs):
        a = math.tau * i / segs
        j = 1.0 + rnd.uniform(-jitter, jitter)
        bot.append(bm.verts.new(B(c[0] + math.cos(a) * r_bot * j, c[1] + math.sin(a) * r_bot * j, y0)))
        top.append(bm.verts.new(B(c[0] + math.cos(a) * r_top * j, c[1] + math.sin(a) * r_top * j, y0 + h)))
    for i in range(segs):
        bm.faces.new((bot[i], bot[(i + 1) % segs], top[(i + 1) % segs], top[i]))
    if r_top > 0.01:
        bm.faces.new(top)
    bm.normal_update()
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    return _obj(coll, name, bm, material)


def cone(coll, name, c, r, h, material, y0, segs=10):
    bm = bmesh.new()
    tip = bm.verts.new(B(c[0], c[1], y0 + h))
    ring = [bm.verts.new(B(c[0] + math.cos(math.tau * i / segs) * r, c[1] + math.sin(math.tau * i / segs) * r, y0)) for i in range(segs)]
    for i in range(segs):
        bm.faces.new((ring[i], ring[(i + 1) % segs], tip))
    bm.faces.new(list(reversed(ring)))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    return _obj(coll, name, bm, material)


def blob(coll, name, c, r, y, material, seed=0, squash=0.8):
    """Copa/rocha facetada (icosfera deformada)."""
    rnd = random.Random(seed)
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=2, radius=r)
    for v in bm.verts:
        v.co *= 1.0 + rnd.uniform(-0.12, 0.12)
        v.co.z *= squash
        v.co += B(c[0], c[1], y)
    return _obj(coll, name, bm, material)


def build_bridges(zone, coll, P, road_polys, rivers, widths, wood, out, roads=()):
    """O trabalho de Zone.bridges, para quem monta a zona sem a classe (build_city_aldara): um tabuleiro por cruzamento
    de verdade estrada x rio, na corda da estrada; cada um entra em `out` (o "bridges" do JSON)."""
    sim_pts = lambda poly: poly[::2] + [poly[-1]]          # o que vai para o JSON (road()/river())
    for name, poly in road_polys.items():
        if name.startswith("trilha_") and name not in roads:
            continue                                       # trilha de lugar (places._trail, kind "trail") não abre vão na sim;
                                                           # estrada de verdade com esse nome (Zone.road, kind "road") abre
        rp = sim_pts(poly)
        for k, rv in enumerate(rivers):
            w = widths[k]
            wp = sim_pts(rv)
            hits = []
            for i in range(len(wp) - 1):
                for j in range(len(rp) - 1):
                    h = seg_hit(wp[i], wp[i + 1], rp[j], rp[j + 1])
                    if h is not None and all((h - q).length > 1.0 for q, _ in hits):
                        hits.append((h, (wp[i + 1] - wp[i]).normalized()))
            for n, (h, rdir) in enumerate(hits):
                # corda da estrada sobre a faixa de água (+ margem), em volta do cruzamento
                i0 = min(range(len(poly)), key=lambda i: (poly[i] - h).length)
                lo = hi = i0
                while lo > 0 and poly_dist(poly[lo], rv) < w * 0.5 + 1.2:
                    lo -= 1
                while hi < len(poly) - 1 and poly_dist(poly[hi], rv) < w * 0.5 + 1.2:
                    hi += 1
                if hi == lo:
                    lo, hi = max(lo - 1, 0), min(hi + 1, len(poly) - 1)
                t = (poly[hi] - poly[lo]).normalized()
                cross = math.degrees(math.acos(min(1.0, abs(t.dot(rdir)))))      # 90 = perpendicular ao rio
                if cross < BRIDGE_MIN_ANGLE:
                    print("BRIDGE_CONFLICT %s: estrada %s cruza o rio a %.0f graus em (%.1f, %.1f) (mínimo %.0f)"
                          % (zone, name, cross, h.x, h.y, BRIDGE_MIN_ANGLE))
                ang = along(t.x, t.y)
                L = min(w / max(math.sin(math.radians(cross)), 0.5), w * 1.5) + 5.0
                tag = "%s_%d" % (name, k) if n == 0 else "%s_%d_%d" % (name, k, n)
                box(coll, P + "ponte_" + tag, (h.x, h.y), (L, 0.08, ROAD_W + 0.6), ang, wood, 0.03)
                for sx in (-1, 1):
                    side = Vector((t.y, -t.x)) * (ROAD_W / 2 + 0.2) * sx
                    box(coll, P + "corrimao_%s_%d" % (tag, sx), (h.x + side.x, h.y + side.y), (L, 0.14, 0.18), ang, wood, 0.75)
                    for j in range(-2, 3):
                        av = t * j * (L - 1.0) / 4
                        box(coll, P + "poste_%s_%d_%d" % (tag, sx, j), (h.x + side.x + av.x, h.y + side.y + av.y), (0.22, 0.85, 0.22), ang, wood, 0.0)
                out.append({"pos": [round(h.x, 2), round(h.y, 2)], "rot": round(ang, 1), "len": round(L, 2), "w": ROAD_W + 0.6,
                            "road": name, "cross": round(cross, 1)})
            # estrada dentro da água longe de qualquer ponte: não cruza (ou encosta antes de cruzar)
            for q in poly:
                if poly_dist(q, rv) < w * 0.5 - 0.5 and all((q - h).length > w + 4.0 for h, _ in hits):
                    print("BRIDGE_CONFLICT %s: estrada %s entra no rio sem ponte em (%.1f, %.1f)" % (zone, name, q.x, q.y))
                    break


# ---------------------------------------------------------------------------
# zona
# ---------------------------------------------------------------------------
class Zone:
    def __init__(self, zone, size=260.0, rim=(116.0, 7.0, 4.0, 2.5), seed=1, spawn=(0.0, 0.0), palette=None):
        self.zone = zone
        self.P = "Z_%s_" % zone
        self.size = size
        self.rim = rim
        self.rnd = random.Random(seed)
        self.seed = seed
        if bpy.context.window is None:          # blender -b (headless): usa a cena ativa
            sc = bpy.context.scene
            sc.name = "RagnaEx_" + zone
        else:
            sc = bpy.data.scenes.get("RagnaEx_" + zone) or bpy.data.scenes.new("RagnaEx_" + zone)
            bpy.context.window.scene = sc
        self.sc = sc
        c = bpy.data.collections.get("Z_" + zone)
        if c is None:
            c = bpy.data.collections.new("Z_" + zone)
        if c.name not in sc.collection.children:
            sc.collection.children.link(c)
        self.coll = c
        for o in list(c.objects) + [o for o in sc.objects if o.name.startswith(("OB_", "SPAWN_", "TRIG_", "CAM_", "PV_"))]:
            bpy.data.objects.remove(o, do_unlink=True)
        for m in list(bpy.data.meshes):
            if m.users == 0:
                bpy.data.meshes.remove(m)
        pal = {
            "road": (0.7, 0.6, 0.46), "street": (0.72, 0.68, 0.6), "water": (0.38, 0.66, 0.88),
            "cliff_rock": (0.4, 0.37, 0.36), "cliff_rock_d": (0.31, 0.29, 0.29), "snow": (0.93, 0.95, 0.98),
            "cliff_grass": (0.36, 0.56, 0.32), "hill_grass": (0.46, 0.66, 0.38),
            "town_wall": (0.84, 0.78, 0.66), "town_wall_d": (0.7, 0.64, 0.54), "roof": (0.62, 0.32, 0.3),
            "wood": (0.5, 0.35, 0.22), "banner": (0.3, 0.42, 0.75), "bark": (0.42, 0.3, 0.2), "leaf": (0.26, 0.46, 0.3),
            "stone_ruin": (0.66, 0.64, 0.6),
        }
        pal.update(palette or {})
        self.M = {k: mat(k, v) for k, v in pal.items()}
        self.data = {"zone": zone, "size": [size, size], "spawn": list(spawn),
                     "town": {"center": [0.0, 0.0], "radius": 0.0, "gates": []},
                     "obstacles": [], "portals": [], "spawners": [], "npcs": {}, "hangouts": [], "roads": [], "water": []}
        self.road_polys = {}
        self.real_roads = set()      # nomes passados por road() (kind "road"): as trilhas dos lugares não entram
        self.rivers = []
        self.river_ws = []           # largura de cada rio (bridges)
        self.blocked = []          # (centro, raio) onde não nasce árvore/pedra
        self.portal_angles = []
        self.turn = FORT_TURN.get(zone, 0.0)      # giro do mapa inteiro no fim (apply_turn)

    # --- dados da sim ---
    def ob(self, kind, x, z, size, rot=0.0, visible=True, solid=True, color=None, roof=None, y=None, when=None, stage_solid=False):
        d = {"kind": kind, "pos": [round(x, 2), round(z, 2)], "size": [round(s, 2) for s in size], "rot": round(rot, 1),
             "visible": visible, "solid": solid}
        if when:                          # conquista (WorldState): só aparece antes/depois de uma quest; sem colisão,
            d["solid"] = bool(stage_solid)    # a não ser com stage_solid (colisor que só vale naquele estágio: MapGeometry.sync_stage)
            d.update(when)
        if y is not None:
            d["y"] = y                     # altura visual (árvore no patamar da montanha); a sim é plana
        if color:
            d["color"] = list(color)
        if roof:
            d["roof"] = list(roof)
        self.data["obstacles"].append(d)
        return d

    def water_tint(self, material):
        """A água deste material aparece no jogo na cor da paleta da zona (sem o azul padrão): MapDef.water_tints.
        Chame antes do river()/lake() que usa o material."""
        c = self.M[material].diffuse_color
        self.data.setdefault("water_tints", {})[material] = [round(c[0], 3), round(c[1], 3), round(c[2], 3)]

    def rim_r(self, a):
        base, a3, a5, a9 = self.rim
        s = self.seed
        return base + a3 * math.sin(3 * a + 1.0 + s) + a5 * math.sin(5 * a + 2.0 + s * 0.7) + a9 * math.sin(9 * a + s * 1.3)

    def block(self, c, r):
        self.blocked.append((Vector(c), r))

    def free(self, x, z, margin=4.5, hub_r=0.0):
        p = Vector((x, z))
        if p.length < hub_r or p.length > self.rim_r(math.atan2(z, x)) - 3:
            return False
        for c, r in self.blocked:
            if (p - c).length < r:
                return False
        return all(poly_dist(p, poly) > margin for poly in list(self.road_polys.values()) + self.rivers)

    # --- estradas e água ---
    def road(self, name, pts, w=ROAD_W, material="road", end_clearing=True):
        poly = catmull(pts, 1.6)
        self.road_polys[name] = poly
        self.real_roads.add(name)
        ribbon(self.coll, self.P + "estrada_" + name, poly, w, 0.012, self.M[material])
        self.data["roads"].append({"kind": "road", "w": w, "pts": [[round(p.x, 2), round(p.y, 2)] for p in poly[::2] + [poly[-1]]]})
        end = poly[-1]
        if end_clearing:
            disc(self.coll, self.P + "estrada_fim_" + name, (end.x, end.y), w * 1.1, 0.011, self.M[material], 20, 0.12, len(name))
        # pontas arredondadas e irregulares (a fita acabava num corte reto): um borrão de terra em cada ponta
        for tag, q in (("ini", poly[0]), ("ponta", end)):
            if tag == "ponta" and end_clearing:
                continue
            disc(self.coll, self.P + "estrada_%s_%s" % (tag, name), (q.x, q.y), w * 0.58, 0.0115, self.M[material], 16, 0.14, len(name) + 3)
        return poly

    def arrival(self, pos, toward=None, r=6.5, material="road", name="chegada"):
        """Largo de chegada: a estrada nasce num terreiro irregular (não num corte reto) e uma trilha curta liga o
        terreiro ao portal `toward`. Só visual + grama fora (a estrada da sim não muda)."""
        m = self.M[material]
        disc(self.coll, self.P + "largo_" + name, pos, r, 0.0118, m, 40, 0.16, len(name) + 5)
        disc(self.coll, self.P + "largo_" + name + "_b", (pos[0] + r * 0.45, pos[1] - r * 0.3), r * 0.62, 0.0117, m, 24, 0.2, len(name) + 9)
        disc(self.coll, self.P + "largo_" + name + "_c", (pos[0] - r * 0.5, pos[1] + r * 0.2), r * 0.55, 0.0116, m, 24, 0.2, len(name) + 2)
        self.data["roads"].append({"kind": "street", "w": 0, "pts": [[round(pos[0], 2), round(pos[1], 2)]], "r": round(r, 2)})
        if toward is not None:
            a, b = Vector(pos), Vector(toward)
            mid = (a + b) * 0.5 + Vector((-(b - a).y, (b - a).x)) * 0.12
            ribbon(self.coll, self.P + "largo_" + name + "_trilha", catmull([tuple(a), tuple(mid), tuple(b)], 1.4), ROAD_W * 0.9, 0.0119, m)
            disc(self.coll, self.P + "largo_" + name + "_portal", toward, ROAD_W * 0.95, 0.0114, m, 20, 0.16, len(name) + 1)

    def plaza(self, name, c, r, material="street"):
        disc(self.coll, self.P + "praca_" + name, c, r, 0.014, self.M[material], 40, 0.05, len(name))
        self.data["roads"].append({"kind": "street", "w": 0, "pts": [[c[0], c[1]]], "r": r})

    def patch(self, name, c, r, color, paved=False, grass=False, y=None):
        """Mancha de chão com cor própria (lê a região de cima). Material "pave_*" vira calçamento no jogo,
        "patch_*" vira chão pintado; grass=False tira a grama ali."""
        mname = ("pave_" if paved else "patch_") + name
        if mname not in self.M:
            self.M[mname] = mat(mname, color)
        if y is None:        # camadas por tamanho: mancha grande por baixo da pequena (duas no mesmo plano brigam: faixas em leque)
            y = 0.0045 if r >= 80 else (0.0052 if r >= 40 else (0.006 if r >= 12 else 0.0068))
        disc(self.coll, self.P + "chao_" + name, c, r, y, self.M[mname], 36, 0.1, len(name))
        if not grass:
            self.data["roads"].append({"kind": "street", "w": 0, "pts": [[c[0], c[1]]], "r": r})
        return mname

    def terrace(self, name, c, r, levels, rock="cliff_rock", top="hill_grass"):
        """Patamar baixo (relevo visto de cima): sólido, 1.4 m por nível."""
        return self.hill(name, c, r, levels, rock, top, step=1.4)

    def river(self, pts, w=7.0, material="water"):
        poly = catmull(pts, 2.0)
        self.rivers.append(poly)
        ribbon(self.coll, self.P + "agua_rio_%d" % len(self.rivers), poly, w, 0.02, self.M[material])
        ribbon(self.coll, self.P + "margem_rio_%d" % len(self.rivers), poly, w + 2.4, 0.008, self.M["road"])
        self.data["water"].append({"kind": "river", "w": w, "pts": [[round(p.x, 2), round(p.y, 2)] for p in poly[::2] + [poly[-1]]]})
        if material in self.data.get("water_tints", {}):      # cor própria da zona (water_tint): o minimapa acha pelo material
            self.data["water"][-1]["material"] = material
        self.river_w = w
        self.river_ws.append(w)
        return poly

    def lake(self, name, c, r, material="water", solid=True):
        disc(self.coll, self.P + "agua_" + name, c, r, 0.025, self.M[material], 40, 0.07, len(name))
        disc(self.coll, self.P + "margem_" + name, c, r + 2.2, 0.009, self.M["road"], 40, 0.07, len(name))
        self.data["water"].append({"kind": "lake", "pos": list(c), "r": r})
        if material in self.data.get("water_tints", {}):
            self.data["water"][-1]["material"] = material
        if solid:
            self.ob("water", c[0], c[1], (2 * (r - 1.2), 1.0, 2 * (r - 1.2)), visible=False)
        self.block(c, r + 3)

    def bridges(self):
        """Ponte (tabuleiro rente ao chão + corrimão baixo) em CADA ponto onde uma estrada cruza um rio.

        O ponto é o mesmo em que a sim abre o vão do rio (MapGeometry.water_crossings: interseção das polilinhas
        exportadas no JSON), não "o primeiro ponto da estrada perto da água": estrada que encosta no rio antes de
        cruzar ganhava a ponte no lugar errado (ao longo da água) e o cruzamento de verdade ficava sem ponte, com o vão
        aberto. O tabuleiro segue a corda da estrada sobre a água (não a tangente de 2 pontos, que entorta na curva).
        Guarda cada ponte em data["bridges"] (pos, rot, len, w, road) para o teste `_check_bridges` e avisa
        BRIDGE_CONFLICT quando a estrada cruza raso demais (< BRIDGE_MIN_ANGLE) ou entra na água sem cruzar."""
        out = self.data.setdefault("bridges", [])
        widths = [self.river_ws[k] if k < len(self.river_ws) else self.river_w for k in range(len(self.rivers))]
        build_bridges(self.zone, self.coll, self.P, self.road_polys, self.rivers, widths, self.M["wood"], out, self.real_roads)

    # --- relevo ---
    def hill(self, name, c, r, levels, rock="cliff_rock", top="hill_grass", step=1.8):
        y0 = 0.0
        for l in range(levels):
            rr = r * (1.0 - 0.28 * l)
            cyl(self.coll, self.P + "morro_%s_%d" % (name, l), c, rr * 1.06, rr, step, self.M[rock], y0, 11, 0.12, len(name) * 10 + l)
            disc(self.coll, self.P + "morro_grama_%s_%d" % (name, l), c, rr * 0.97, y0 + step + 0.01, self.M[top], 11, 0.12, len(name) * 10 + l)
            y0 += step
        self.ob("hill", c[0], c[1], (2 * r, y0, 2 * r), visible=False)
        self.block(c, r + 2)
        return y0

    def cliffs(self, rock="cliff_rock", top="cliff_grass", hmin=18.0, hvar=10.0, snow=True):
        """Anel de montanhas (nature.mountain_ring) + corrente de colisão; gargantas baixas onde há portal."""
        import nature
        steps = 180
        mats = [self.M[rock], self.M.get(rock + "_d") or self.M["cliff_rock_d"], self.M[top], self.M["snow"] if snow else None]
        nature.mountain_ring(self.coll, self.P + "penhascos", self.rim_r, self.portal_angles, mats, self.ob, seed=self.seed,
                             tree_cols=nature.PINE_COLS if snow else [(0.42, 0.36, 0.3), (0.5, 0.44, 0.36)],
                             ledge_trees="pine" if snow else "dead_tree",
                             boulder_col=tuple(self.M[rock].diffuse_color[:3]))
        for i in range(0, steps, 2):
            a = math.tau * (i + 1) / steps
            r0 = self.rim_r(a) + 3.5
            seg = r0 * math.tau / steps * 2 * 1.25
            self.ob("cliff", math.cos(a) * r0, math.sin(a) * r0, (seg, 6.0, 7.0), along(-math.sin(a), math.cos(a)), visible=False)

    # --- construções ---
    def ring_wall(self, name, c, r, gate_angles, gate_half=3.5, height=3.0, thick=1.0, material="wood", stakes=False, towers=0):
        """Muro circular (paliçada de estacas ou muralha) com portões abertos nos ângulos dados (rad, do jogo)."""
        n = max(16, int(math.tau * r / 2.2))
        for i in range(n):
            am = math.tau * (i + 0.5) / n
            if any(angdiff(am, g) * r < gate_half + 0.4 for g in gate_angles):
                continue
            p = (c[0] + math.cos(am) * r, c[1] + math.sin(am) * r)
            seg = math.tau * r / n + 0.12
            rot = along(-math.sin(am), math.cos(am))
            if stakes:
                for k in (-0.25, 0.25):
                    q = (p[0] - math.sin(am) * seg * k, p[1] + math.cos(am) * seg * k)
                    h = height * (0.85 + 0.3 * ((i * 7 + int(k * 4)) % 5) / 5)
                    cyl(self.coll, self.P + "%s_estaca_%d_%d" % (name, i, int(k * 4)), q, 0.42, 0.42, h, self.M[material], 0.0, 6)
                    cone(self.coll, self.P + "%s_ponta_%d_%d" % (name, i, int(k * 4)), q, 0.44, 0.7, self.M[material], h, 6)
            else:
                box(self.coll, self.P + "%s_muro_%d" % (name, i), p, (seg, height, thick), rot, self.M[material], 0.0)
            self.ob("wall", p[0], p[1], (seg, height, thick + 0.4), rot, visible=False)
        for k in range(towers):
            a = math.tau * (k + 0.5) / towers
            p = (c[0] + math.cos(a) * r, c[1] + math.sin(a) * r)
            if any(angdiff(a, g) * r < gate_half + 3 for g in gate_angles):
                continue
            cyl(self.coll, self.P + "%s_torre_%d" % (name, k), p, 1.8, 1.6, height + 3.0, self.M[material], 0.0, 8)
            cone(self.coll, self.P + "%s_teto_%d" % (name, k), p, 2.2, 2.2, self.M["roof"], height + 3.0, 8)
            self.ob("pillar", p[0], p[1], (3.6, height + 3, 3.6), visible=False)
        self.block(c, r + 2)

    def giant_tree(self, name, c, trunk_r=3.2, height=22.0):
        """Landmark: árvore colossal (tronco + copas facetadas)."""
        cyl(self.coll, self.P + name + "_tronco", c, trunk_r * 1.5, trunk_r, height * 0.6, self.M["bark"], 0.0, 10, 0.1, 1)
        for i in range(6):
            a = math.tau * i / 6
            rt = (c[0] + math.cos(a) * trunk_r * 1.6, c[1] + math.sin(a) * trunk_r * 1.6)
            box(self.coll, self.P + name + "_raiz_%d" % i, rt, (trunk_r * 2.0, 1.2, 1.2), math.degrees(-a), self.M["bark"], 0.0)
        rnd = random.Random(len(name))
        for i in range(7):
            a = math.tau * i / 7
            off = 0.0 if i == 0 else trunk_r * 2.4
            blob(self.coll, self.P + name + "_copa_%d" % i, (c[0] + math.cos(a) * off, c[1] + math.sin(a) * off),
                 trunk_r * (3.0 if i == 0 else 2.2), height * (0.85 if i == 0 else 0.68) + rnd.uniform(-1, 1), self.M["leaf"], i, 0.75)
        self.ob("pillar", c[0], c[1], (trunk_r * 3.2, height, trunk_r * 3.2), visible=False)
        self.block(c, trunk_r * 4)

    # --- conteúdo ---
    def portal(self, pid, pos, target_map, target_pos, label):
        self.data["portals"].append({"id": pid, "pos": list(pos), "radius": 2.0, "target_map": target_map,
                                     "target_pos": list(target_pos), "label": label})
        self.portal_angles.append(math.atan2(pos[1], pos[0]))
        self.block(pos, 7)

    def spawner(self, mid, x, z, r, n, respawn, route=None, when=None):
        d = {"monster_id": mid, "pos": [x, z], "radius": r, "count": n, "respawn": respawn}
        if when:                      # conquista (WorldState): {"if": quest} / {"unless": quest}
            d.update(when)
        if route:                     # ronda do líder (MonsterBrain): pontos [x, z]
            d["route"] = [[round(p[0], 2), round(p[1], 2)] for p in route]
        self.data["spawners"].append(d)

    def npc(self, nid, x, z, face_deg):
        self.data["npcs"][nid] = [x, z, face_deg]

    def scatter(self, kind, centers, n, size, colors, margin=4.5, spacing=3.2, hub_r=0.0, scale=(0.9, 1.4)):
        """Espalha props (árvore/pedra/ruína) em manchas: centers = [((x,z), raio, quantidade)]."""
        placed = []
        for (cx, cz), cr, cnt in centers:
            k = 0
            for _ in range(cnt * 5):
                if k >= cnt:
                    break
                a = self.rnd.uniform(0, math.tau)
                r = cr * math.sqrt(self.rnd.random())
                x, z = cx + math.cos(a) * r, cz + math.sin(a) * r
                if not self.free(x, z, margin, hub_r) or any((Vector((x, z)) - q).length < spacing for q in placed):
                    continue
                s = self.rnd.uniform(*scale)
                self.ob(kind, x, z, (size[0] * s, size[1] * s, size[2] * s), self.rnd.uniform(0, 360) if kind != "tree" else 0.0,
                        color=colors[self.rnd.randrange(len(colors))])
                placed.append(Vector((x, z)))
                k += 1
        return placed

    def rim_belt(self, n, size, colors, depth=(4, 10), kind="tree"):
        """Cinturão de árvores/pedras junto aos penhascos (esconde a base da borda)."""
        for i in range(n):
            a = math.tau * i / n + self.rnd.uniform(-0.01, 0.01)
            r = self.rim_r(a) - self.rnd.uniform(*depth)
            x, z = math.cos(a) * r, math.sin(a) * r
            if self.free(x, z, 5.0):
                s = self.rnd.uniform(1.1, 1.7)
                self.ob(kind, x, z, (size[0] * s, size[1] * s, size[2] * s), color=colors[self.rnd.randrange(len(colors))])

    # --- final ---
    def markers(self, poi):
        sc = self.sc
        for i, o in enumerate(self.data["obstacles"]):
            if not o["visible"]:
                e = bpy.data.objects.new("OB_box_%s_%03d" % (o["kind"], i), None)
                e.empty_display_type = "CUBE"
                e.location = B(o["pos"][0], o["pos"][1], o["size"][1] / 2)
                e.scale = (o["size"][0] / 2, o["size"][2] / 2, o["size"][1] / 2)
                e.rotation_euler = (0, 0, math.radians(o["rot"]))
                sc.collection.objects.link(e)
        for s in self.data["spawners"]:
            e = bpy.data.objects.new("SPAWN_mob_%s" % s["monster_id"], None)
            e.empty_display_type = "CIRCLE"
            e.empty_display_size = s["radius"]
            e.location = B(s["pos"][0], s["pos"][1], 0.2)
            sc.collection.objects.link(e)
        for p in self.data["portals"]:
            e = bpy.data.objects.new("TRIG_portal_%s" % p["target_map"], None)
            e.empty_display_type = "SPHERE"
            e.empty_display_size = 2.0
            e.location = B(p["pos"][0], p["pos"][1], 1.0)
            sc.collection.objects.link(e)
        cam_top = bpy.data.cameras.new("CAM_top")
        cam_top.type = "ORTHO"
        cam_top.ortho_scale = self.size + 10
        o = bpy.data.objects.new("CAM_top", cam_top)
        o.location = (0, 0, 200)
        sc.collection.objects.link(o)
        for name, (tx, tz) in (("CAM_game", tuple(getattr(self, "cam_game", self.data["spawn"]))), ("CAM_poi", poi)):
            cd = bpy.data.cameras.new(name)
            cd.lens_unit = "FOV"
            cd.angle = math.radians(56)
            cd.clip_start = 2.0            # só a foto: com 0,1 m o z-buffer do Workbench lista camadas de chão a < 0,4 mm (falso z-fight)
            co = bpy.data.objects.new(name, cd)
            tgt = B(tx, tz, 0.8)
            co.location = tgt + Vector((0, -math.cos(math.radians(52)) * 24, math.sin(math.radians(52)) * 24))
            co.rotation_euler = (math.radians(38), 0, 0)
            sc.collection.objects.link(co)
        sc.camera = o
        sc.render.resolution_x = 900
        sc.render.resolution_y = 900

    def preview(self, ground=(0.55, 0.74, 0.42)):
        """Proxies só para avaliar no Blender (chão, props, spawners) — não exportados."""
        pc = bpy.data.collections.get("PREVIEW_" + self.zone)
        if pc is None:
            pc = bpy.data.collections.new("PREVIEW_" + self.zone)
            self.sc.collection.children.link(pc)
        elif pc.name not in self.sc.collection.children:
            self.sc.collection.children.link(pc)
        for o in list(pc.objects):
            bpy.data.objects.remove(o, do_unlink=True)
        disc(pc, "PV_chao", (0, 0), self.size / 2 + 5, -0.01, mat("pv_ground_" + self.zone, ground), 96)
        tm = {}
        for i, o in enumerate(self.data["obstacles"]):
            if not o["visible"]:
                continue
            x, z = o["pos"]
            sx, sy, sz = o["size"]
            col = tuple(o.get("color", (0.6, 0.6, 0.6)))
            key = (o["kind"], col)
            if key not in tm:
                tm[key] = mat("pv_%s_%s_%d" % (self.zone, o["kind"], len(tm)), col)
            if o["kind"] == "tree":
                cone(pc, "PV_tc%d" % i, (x, z), sx * 1.3, sy * 1.1, tm[key], sy * 0.35, 8)
            elif o["kind"] == "house":
                box(pc, "PV_h%d" % i, (x, z), (sx, sy, sz), o["rot"], tm[key])
            else:
                box(pc, "PV_o%d" % i, (x, z), (sx, sy, sz), o["rot"], tm[key])
        red = mat("pv_spawn", (0.9, 0.3, 0.3))
        for s in self.data["spawners"] if os.environ.get("ZONE_PV_SPAWN", "1") != "0" else []:      # ZONE_PV_SPAWN=0: foto sem os discos
            disc(pc, "PV_sp", s["pos"], s["radius"], 0.03, red, 16)

    def apply_turn(self, poi):
        """Gira o mapa inteiro `self.turn` graus no sentido horário visto de cima (norte = -z): dados da sim e malhas.

        Os mapas de fortaleza são desenhados com a chegada ao sul; o mundo pede que a chegada fique do lado de onde o
        jogador saiu na zona-mãe (saiu pelo oeste -> chega pelo leste). `turn` = rumo do portal de saída na zona-mãe
        (0 = norte, 90 = leste) e é gravado no JSON (`"turn"`), para quem tem ponto fixo no desenho original (tour, testes).
        `target_pos` dos portais fica como está (é ponto de OUTRO mapa)."""
        deg = float(getattr(self, "turn", 0.0)) % 360.0
        self.data["turn"] = round(deg, 1)
        if deg == 0.0:
            return poi
        a = math.radians(deg)
        ca, sa = math.cos(a), math.sin(a)

        def rp(p):
            return [round(p[0] * ca - p[1] * sa, 2), round(p[0] * sa + p[1] * ca, 2)]

        def yaw(r):
            return round((float(r) - deg + 180.0) % 360.0 - 180.0, 1)

        POINT = ("pos", "from", "target", "spawn", "center", "arrive")
        LISTS = ("route", "pts", "hangouts", "gates")

        def walk(v, key=""):
            if isinstance(v, dict):
                for k in list(v.keys()):
                    x = v[k]
                    if k in POINT and isinstance(x, (list, tuple)) and len(x) == 2:
                        v[k] = rp(x)
                    elif k in LISTS and isinstance(x, list):
                        v[k] = [rp(q) for q in x]
                    elif k == "emerge" and isinstance(x, (list, tuple)) and len(x) == 3:
                        v[k] = rp(x[:2]) + [x[2]]
                    elif k == "rot" and isinstance(x, (int, float)):
                        v[k] = yaw(x)
                    elif k == "npcs" and isinstance(x, dict):
                        for nid, q in x.items():
                            x[nid] = rp(q[:2]) + [yaw(q[2])]
                    elif k != "target_pos":
                        walk(x, k)
            elif isinstance(v, list):
                for x in v:
                    walk(x, key)

        walk(self.data)
        from mathutils import Matrix
        R = Matrix.Rotation(-a, 4, "Z")           # Blender (x, y) = jogo (x, -z): horário no jogo = -a em Z
        for o in self.coll.objects:
            if o.parent is None:
                o.matrix_world = R @ o.matrix_world
        if hasattr(self, "cam_game"):
            self.cam_game = tuple(rp(self.cam_game))
        return tuple(rp(poi))

    def finish(self, export=False, poi=(0.0, 0.0), ground=(0.55, 0.74, 0.42)):
        poi = self.apply_turn(poi)
        self.markers(poi)
        self.preview(ground)
        if export:
            os.makedirs(ROOT + "/data/zones", exist_ok=True)
            with open(ROOT + "/data/zones/%s.json" % self.zone, "w", encoding="utf-8") as f:
                json.dump(self.data, f, ensure_ascii=False, indent=1)
            bpy.ops.object.select_all(action="DESELECT")
            for o in self.coll.objects:
                o.select_set(True)
            kw = {}
            if "export_vertex_color" in bpy.ops.export_scene.gltf.get_rna_type().properties:
                kw["export_vertex_color"] = "ACTIVE"       # lotes do dress.py: a cor de cada peça vai no vértice (COLOR_0)
            bpy.ops.export_scene.gltf(filepath=ROOT + "/assets/models/map_%s.glb" % self.zone, export_format="GLB",
                                      use_selection=True, use_active_scene=True, export_apply=True, export_animations=False,
                                      export_yup=True, export_materials="EXPORT", **kw)
            print("exportado: map_%s.glb + data/zones/%s.json" % (self.zone, self.zone))
        return self.data
