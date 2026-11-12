"""Peças da Horda e da caravana (Ato II, Estepes de Cinza): carroça de lona, estandarte, costela/presa de mamute, fogueira,
tambor de guerra, torre de vigia e ravina. Usado por build_field_steppe.py e build_steppe_forts.py.
Tudo em coordenadas do jogo (x, z); nomes com `tag` no meio para o MapBuilder.apply_conquest achar (conquest_vis).
"""
import math
import bmesh
import zone_lib
from zone_lib import B, _obj, along, box, catmull, cone, cyl, disc, mat, ribbon

HORDE_RED = (0.72, 0.16, 0.13)
AURORA_GOLD = (0.96, 0.9, 0.62)
STAKE_DARK = (0.3, 0.24, 0.2)
BONE = (0.9, 0.87, 0.78)
CANVAS = (0.88, 0.84, 0.72)


def wagon(z, name, c, rot, canvas=CANVAS, solid=True, length=5.2):
    """Carroça coberta: caixa de madeira, lona clara por cima (o que se lê da câmera alta) e quatro rodas escuras."""
    wood = mat("carroca_madeira", (0.46, 0.33, 0.22))
    wheel = mat("carroca_roda", (0.24, 0.19, 0.15))
    cloth = mat("carroca_lona_%d" % int(canvas[0] * 100 + canvas[2] * 10), canvas)
    a = math.radians(rot)
    ux, uz = math.cos(a), -math.sin(a)                 # eixo comprido da carroça no jogo
    vx, vz = -uz, ux
    box(z.coll, z.P + name + "_caixa", c, (length, 1.0, 2.2), rot, wood, 0.6)
    box(z.coll, z.P + name + "_lona", c, (length - 0.5, 1.3, 2.0), rot, cloth, 1.6)
    box(z.coll, z.P + name + "_lona_topo", c, (length - 0.9, 0.5, 1.3), rot, cloth, 2.9)
    for i, (su, sv) in enumerate(((-1, -1), (-1, 1), (1, -1), (1, 1))):
        q = (c[0] + ux * su * (length * 0.32) + vx * sv * 1.25, c[1] + uz * su * (length * 0.32) + vz * sv * 1.25)
        box(z.coll, z.P + name + "_roda_%d" % i, q, (1.3, 1.3, 0.22), rot, wheel, 0.0)
    if solid:
        z.ob("wall", c[0], c[1], (length + 0.2, 3.2, 2.7), rot, visible=False)


def wagon_ring(z, name, c, r, gate_angles, gate_half=4.6, canvases=(CANVAS,)):
    """Muralha de carroças em anel (Posto da Caravana): carroças na tangente, fechadas umas nas outras por estacas baixas;
    vãos nos ângulos dados (rad). A colisão é uma corrente de caixas sem fresta."""
    n = int(math.tau * r / 6.4)
    stake = mat("estaca_posto", (0.56, 0.44, 0.3))
    k = 0
    for i in range(n):
        am = math.tau * (i + 0.5) / n
        if any(zone_lib.angdiff(am, g) * r < gate_half + 1.6 for g in gate_angles):
            continue
        p = (c[0] + math.cos(am) * r, c[1] + math.sin(am) * r)
        rot = along(-math.sin(am), math.cos(am))
        wagon(z, "%s_carroca_%d" % (name, i), p, rot, canvases[k % len(canvases)], solid=False)
        k += 1
        seg = math.tau * r / n + 0.3
        z.ob("wall", p[0], p[1], (seg, 3.2, 2.8), rot, visible=False)
        for s in (-1, 1):                               # estacas cruzadas entre uma carroça e a seguinte
            ae = am + s * math.pi / n
            q = (c[0] + math.cos(ae) * r, c[1] + math.sin(ae) * r)
            cyl(z.coll, z.P + "%s_trava_%d_%d" % (name, i, s), q, 0.3, 0.26, 2.0, stake, 0.0, 6)
    z.block(c, r + 2)


def banner(z, name, p, color, h=5.0, rot=0.0, pole=(0.3, 0.24, 0.2)):
    """Estandarte: mastro + pano (o pano é o que muda de cor na retomada)."""
    cyl(z.coll, z.P + name + "_mastro", p, 0.14, 0.1, h, mat("mastro_%d" % int(pole[0] * 100), pole), 0.0, 6)
    a = math.radians(rot)
    q = (p[0] + math.cos(a) * 0.9, p[1] - math.sin(a) * 0.9)
    box(z.coll, z.P + name + "_pano", q, (1.7, 2.3, 0.08), rot, mat("pano_%d_%d" % (int(color[0] * 100), int(color[2] * 100)), color), h - 2.6)


def rib(coll, name, base, out_ang, height, curl, r0, r1, material, steps=7, sides=6):
    """Costela/presa: tubo que afina, sobe da base e se curva para dentro (direção oposta a out_ang)."""
    bm = bmesh.new()
    rings = []
    dx, dz = -math.cos(out_ang), -math.sin(out_ang)
    for k in range(steps + 1):
        t = k / steps
        h = height * math.sin(t * math.pi / 2)
        inn = curl * (1.0 - math.cos(t * math.pi / 2))
        cx, cz = base[0] + dx * inn, base[1] + dz * inn
        r = r0 + (r1 - r0) * t
        ty = math.cos(t * math.pi / 2) * height
        th = math.sin(t * math.pi / 2) * curl
        L = math.hypot(ty, th) or 1.0
        ty, th = ty / L, th / L
        ring = []
        for j in range(sides):
            a = math.tau * j / sides
            side = math.cos(a) * r
            nrm = math.sin(a) * r
            ring.append(bm.verts.new(B(cx + (-dz) * side + dx * (nrm * ty), cz + dx * side + dz * (nrm * ty), h - nrm * th)))
        rings.append(ring)
    for k in range(steps):
        for j in range(sides):
            bm.faces.new((rings[k][j], rings[k][(j + 1) % sides], rings[k + 1][(j + 1) % sides], rings[k + 1][j]))
    bm.faces.new(rings[-1])
    bm.normal_update()
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    return _obj(coll, name, bm, material)


def ribcage(z, name, c, ang, n=5, width=3.4, height=4.2, spacing=2.2):
    """Carcaça de mamute: espinha no chão e pares de costelas em arco; passa-se por fora (colisão baixa no meio)."""
    bone = mat("osso_mamute", BONE)
    ux, uz = math.cos(ang), math.sin(ang)
    vx, vz = -uz, ux
    L = (n - 1) * spacing
    box(z.coll, z.P + name + "_espinha", c, (L + 2.0, 0.5, 0.7), along(ux, uz), bone, 0.0)
    for i in range(n):
        t = (i - (n - 1) / 2) * spacing
        k = 1.0 - 0.12 * abs(i - (n - 1) / 2)
        for s in (-1, 1):
            base = (c[0] + ux * t + vx * s * width * k, c[1] + uz * t + vz * s * width * k)
            rib(z.coll, z.P + "%s_costela_%d_%d" % (name, i, s), base, math.atan2(vz * s, vx * s), height * k, width * k * 0.95, 0.34, 0.1, bone)
    z.ob("wall", c[0], c[1], (L + 2.0, 2.0, width * 2 + 0.6), along(ux, uz), visible=False)
    z.block(c, max(L, width * 2) * 0.5 + 3.0)


def skull(z, name, c, ang, s=1.0):
    """Crânio de mamute com duas presas curvas para a frente."""
    bone = mat("osso_mamute", BONE)
    zone_lib.blob(z.coll, z.P + name + "_cranio", c, 1.7 * s, 1.1 * s, bone, 3, 0.8)
    ux, uz = math.cos(ang), math.sin(ang)
    vx, vz = -uz, ux
    for k in (-1, 1):
        base = (c[0] + ux * 1.2 * s + vx * k * 1.0 * s, c[1] + uz * 1.2 * s + vz * k * 1.0 * s)
        rib(z.coll, z.P + "%s_presa_%d" % (name, k), base, ang + math.pi + k * 0.5, 3.4 * s, 2.6 * s, 0.32 * s, 0.06, mat("marfim", (0.96, 0.93, 0.8)))
    z.ob("rock", c[0], c[1], (3.6 * s, 2.2, 3.6 * s), visible=False)
    z.block(c, 4.0 * s)


def campfire(z, name, c, r=1.3, solid=True):
    """Fogueira: pedras em roda, brasa laranja (de cima é um ponto quente que marca o meio do acampamento)."""
    disc(z.coll, z.P + name + "_cinza", c, r * 1.7, 0.016, mat("cinza_fogueira", (0.26, 0.24, 0.23)), 14, 0.2, 2)
    cyl(z.coll, z.P + name + "_brasa", c, r * 0.7, 0.15, 1.1, mat("glow_brasa", (1.0, 0.56, 0.2)), 0.0, 7)
    stone = mat("pedra_fogueira", (0.46, 0.44, 0.42))
    for i in range(7):
        a = math.tau * i / 7
        box(z.coll, z.P + "%s_pedra_%d" % (name, i), (c[0] + math.cos(a) * r, c[1] + math.sin(a) * r), (0.6, 0.4, 0.5), math.degrees(-a), stone, 0.0)
    if solid:
        z.ob("rock", c[0], c[1], (r * 2.2, 1.0, r * 2.2), visible=False)


def drum(z, name, c, r=1.3):
    """Tambor de guerra: corpo vermelho, pele clara em cima."""
    cyl(z.coll, z.P + name + "_corpo", c, r, r * 0.9, 1.3, mat("tambor_corpo", HORDE_RED), 0.0, 10)
    disc(z.coll, z.P + name + "_pele", c, r * 0.86, 1.32, mat("tambor_pele", (0.9, 0.8, 0.58)), 10)
    z.ob("pillar", c[0], c[1], (r * 2, 1.3, r * 2), visible=False)


def watchtower(z, name, c, roof, h=6.0):
    """Torre de vigia de estacas com teto (cor = de quem é o acampamento)."""
    wood = mat("torre_horda", STAKE_DARK)
    for dx in (-1.3, 1.3):
        for dz in (-1.3, 1.3):
            cyl(z.coll, z.P + "%s_poste_%d_%d" % (name, dx > 0, dz > 0), (c[0] + dx, c[1] + dz), 0.22, 0.2, h, wood, 0.0, 6)
    box(z.coll, z.P + name + "_plataforma", c, (3.6, 0.3, 3.6), 0.0, wood, h)
    cone(z.coll, z.P + name + "_teto", c, 2.7, 1.7, mat("teto_%d_%d" % (int(roof[0] * 100), int(roof[2] * 100)), roof), h + 1.5, 4)
    z.ob("pillar", c[0], c[1], (3.4, h, 3.4), visible=False)


def ravine(z, name, pts, w=5.0):
    """Ravina: fenda escura no chão (sólida, não se atravessa), borda de pedra clara. Fica fora das estradas."""
    poly = catmull(pts, 2.0)
    ribbon(z.coll, z.P + "ravina_borda_" + name, poly, w + 2.6, 0.007, mat("patch_ravina_borda", (0.5, 0.44, 0.38)))
    ribbon(z.coll, z.P + "ravina_" + name, poly, w, 0.018, mat("chasm", (0.1, 0.08, 0.09)))
    for p in poly[::2]:                                   # sem grama na fenda (manchas de chão, não estrada)
        z.data["roads"].append({"kind": "street", "w": 0, "pts": [[round(p.x, 2), round(p.y, 2)]], "r": round(w * 0.5 + 1.3, 2)})
    for i in range(0, len(poly) - 1, 2):
        a, b = poly[i], poly[min(i + 2, len(poly) - 1)]
        m = (a + b) * 0.5
        d = b - a
        if d.length < 0.1:
            continue
        z.ob("cliff", m.x, m.y, (d.length + 1.0, 1.0, w - 0.6), along(d.x, d.y), visible=False)
        z.block((m.x, m.y), w * 0.5 + 3.0)
