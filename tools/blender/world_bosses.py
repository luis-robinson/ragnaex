"""Chefes de Mundo (GDD design/gdd/momentos-do-mundo.md §3.1): um por faixa, em lugar fixo da zona.

`mob_ancestral_boar` = Javali Ancestral (faixa 1-10, Vale de Aldara). Peças rígidas no rig de quadrúpede do mob_kit
(root, body, head, leg_fr/fl/br/bl, tail; arm_r/arm_l sobram do MOB_BONES e ficam em repouso), uma malha por osso
(`ab_<osso>`). Lombo de musgo com pedras, raízes e cogumelos, presa grande curva do lado esquerdo (+X) e a direita
quebrada, flechas/lança velhas cravadas no couro, olhos âmbar (`glow_*`, energia baixa).

Clipes (24 fps, impacto = EntityView.IMPACT_FRAME): idle, run, attack (5), hit, die, atk_charge (5), slam (8), roar (7),
shout (7, cópia do roar), maul (7), pounce (9), brace (6). TODO osso tem chave em TODO clipe (`_clip`).
Chão: `_ground` roda depois dos clipes; pata que passaria do chão recolhe para dentro do ombro/coxa (até LEG_TUCK) e o que
sobrar sobe a raiz. Tamanho nativo ~ o do mob_boar x1,25 (SIZE); no jogo a sugestão é MonsterDef.scale 3,0.

`mob_ancient_elk` = Alce Ancião de chifres de cristal (faixa 10-20, floresta élfica). Mesmo rig de quadrúpede, mais o osso
`antler` (filho da cabeça): 8 malhas `ae_<osso>`. A cabeça gira na BASE do pescoço (pescoço e juba vão no osso `head`); os
chifres de cristal (`glow_*_crystal` verde-água, `glow_*_crystal2` lilás, emissão ELK_GLOW) só mudam de ESCALA: pulsam no
idle, abrem no urro e estouram no `cast_ground`. Por isso os clipes dele usam `_eclip` (toda chave leva escala). Juba, barba e
peitoral de pelo verde-musgo claro (`_lock`), casca nos ombros, cipó, fitas, pingentes e varal de bandeirolas nos chifres.
Clipes: os do javali + `cast_ground` (10). No `die` tomba de lado e a cabeça fica de pé, chifres para cima (ELK_DIE_HEAD).
Tamanho nativo: cernelha ~1,15, chifres até 2,14, envergadura dos chifres 1,93; sugestão MonsterDef.scale 3,0.

`mob_ruins_basilisk` = Basilisco das Ruínas (faixa 20-30, Ruínas / Aurora). Lagarto baixo e comprido de quatro patas abertas: rig de
quadrúpede + `tail2` (filho de `tail`: o rabo dobra), `jaw` (filho da cabeça, X- abre) e `gaze` (filho da cabeça): 10 malhas
`rb_<osso>`. Ruínas no lombo (coluna de pé, tambor caído, capitel, duas lajes com runas apagadas, cabeça de estátua), tambor de
coluna enfiado no rabo e clava de entulho na ponta, coroa de espinhos de pedra na nuca. Olhos (`glow_*_eye`, ouro pálido) e
papo (`glow_*_throat`) ficam no osso `gaze`, que só muda de ESCALA: incham no `cast_ground` (olhar petrificante) e murcham no
`die`. `slam` = batida do rabo (8). `_tail_ground` roda antes do `_ground`: o rabo encosta no chão em vez de erguer a raiz.
Tamanho nativo: 2,75 de comprido, 1,14 de largo, lombo ~0,55, coluna 0,86; sugestão MonsterDef.scale 3,0.

`mob_war_rhino` = Rinoceronte de Guerra da Horda (faixa 30-40, Estepe / Porto Esperança). Rig de quadrúpede + `jaw` (filho da
cabeça, X- abre) e `banner` (filho do corpo: o mastro do estandarte, que sacode no urro e atrasa na corrida): 10 malhas
`wr_<osso>`. Couro cinza-pardo, chifre grande com ponteira de ferro tosco e um segundo menor, testeira e ombreiras de ferro
rebitado com cravos, coleira de cravos, plataforma de guerra de madeira sobre manta vermelha, estandarte rasgado (pano DOBRADO,
`_cloth`), tambores de guerra no flanco +X, feixe de lanças no -X, correntes, pintura de guerra ocre. Olhos `glow_*_eye` (brasa).
Paleta da Horda de act2_bosses/kharzun_mobs/zones.horde. Clipes: os do alce; `atk_charge` = investida de chifre baixo, `slam` =
empina e bate as duas patas da frente, `roar` = berro (estandarte sacode), `cast_ground` = cava o chão e bufa, `maul` = chifrada
de lado. Tamanho nativo e sugestão de MonsterDef.scale: ver production/session-state/agent-world-boss-rinoceronte.md.

`mob_iron_wolf_king` = Lobo-Rei de Ferro (faixa 40-45, Monte Kharzun). Rig de quadrúpede + `jaw` (filho da cabeça, X- abre),
`tail2` (filho de `tail`: o rabo cheio dobra), `chain` (filho do corpo: a corrente solta da coleira partida balança) e `flare`
(filho do corpo: as runas GRANDES das ombreiras e do lombo, que só mudam de ESCALA; em IW_FLARE_REST ficam dentro das chapas,
aparecem no `roar` e acendem no `cast_ground`, o uivo que chama a matilha): 11 malhas `iw_<osso>`. Pelo cinza-azulado, juba
branco-geada, armadura anã de ferro claro com rebites de latão (elmo-máscara com crista, ombreiras em três lâminas, lâminas no
lombo, chapas na anca, braçadeiras, ponteiras nas garras, aro no rabo), costuras e runas `glow_*_rune` em brasa fraca, olhos
`glow_*_eye` azul-gelo, espada anã e virotes cravados. `slam` = salta e desaba nas patas da frente, `maul` = patada, `pounce` =
bote com mordida, `atk_charge` = investida mordendo. Tamanho e escala: production/session-state/agent-world-boss-lobo-rei.md.

    mob_kit.build_all(out, only=["mob_ancestral_boar"])      # ou ["mob_ancient_elk"], ["mob_ruins_basilisk"], ["mob_war_rhino"]
    blender -b --factory-startup --python tools/blender/world_bosses_preview.py -- --out=<pasta ABSOLUTA> [--export=<abs assets/models>] [--ground]
"""
import math
import random

import bmesh
import bpy
from mathutils import Vector
from mathutils.bvhtree import BVHTree

import chibi_kit as ck
import lowpoly_lib as lp
import build_monsters as bm
import mob_kit as mk
import boss_gestures as bg

V = Vector

SIZE = 0.68                 # o javali é desenhado em "unidades de desenho" (lombo a ~1,3) e encolhido inteiro: cernelha a ~0,95
LEG_TUCK = 0.2              # quanto (unidades de desenho) a pata pode recolher para dentro do corpo antes de a raiz subir
DIE_SINK = 0.006
# espinha: anca -> lombo -> meio -> cernelha (ombros pesados) -> pescoço
SPINE = [((0, 0.62, 0.62), 0.3), ((0, 0.3, 0.7), 0.4), ((0, -0.05, 0.78), 0.46), ((0, -0.4, 0.9), 0.53), ((0, -0.7, 0.76), 0.4)]
WIDE = 1.14                 # o tronco é mais largo que alto (lido de cima)
HEAD_K = 1.22               # cabeça chibi: tudo do osso da cabeça cresce em volta de HEAD e avança HEAD_SHIFT
HEAD_SHIFT = (0, -0.03, 0.07)
HEAD = (0, -1.0, 0.64)
BOAR_CLIPS = ("idle", "run", "attack", "hit", "die", "atk_charge", "slam", "roar", "shout", "maul", "pounce", "brace")
IMPACT = {"attack": 5, "atk_charge": 5, "slam": 8, "roar": 7, "shout": 7, "maul": 7, "pounce": 9, "brace": 6}

FUR = (0.54, 0.38, 0.28)
FUR_D = (0.3, 0.2, 0.16)
FUR_L = (0.82, 0.66, 0.5)
GREY = (0.9, 0.82, 0.68)           # pelo velho (costeletas, barbicha)
MOSS = (0.42, 0.6, 0.3)
MOSS_L = (0.66, 0.78, 0.4)
STONE = (0.66, 0.66, 0.64)
STONE_D = (0.48, 0.5, 0.52)
ROOT = (0.5, 0.36, 0.22)
IVORY = (0.95, 0.9, 0.76)
IVORY_D = (0.74, 0.64, 0.48)
HOOF = (0.2, 0.16, 0.15)
NOSE = (0.86, 0.56, 0.54)
AMBER = (1.0, 0.68, 0.18)
WOOD = (0.42, 0.3, 0.2)
FLETCH = (0.86, 0.4, 0.34)
FLETCH2 = (0.92, 0.86, 0.66)
CAP = (0.92, 0.52, 0.42)
PETAL = (0.98, 0.92, 0.6)


# ---------------------------------------------------------------------------
# helpers de malha
# ---------------------------------------------------------------------------
def _rock(name, c, r, material, seed, sq=(1.0, 1.0, 0.72), sub=1):
    rnd = random.Random(seed)
    b = bmesh.new()
    bmesh.ops.create_icosphere(b, subdivisions=sub, radius=r)
    for v in b.verts:
        k = 1.0 + rnd.uniform(-0.2, 0.2)
        v.co = V((v.co.x * sq[0] * k, v.co.y * sq[1] * k, v.co.z * sq[2] * k)) + V(c)
    return ck.mesh_from(name, b, material)


def _shell(name, src, pick, off, material, tuck=0.025):
    """Manta rente ao corpo: as faces de `src` que `pick(centro, normal)` aceita, empurradas `off` para fora; a borda entra no corpo."""
    b = bmesh.new()
    b.from_mesh(src.data)
    b.normal_update()
    drop = [f for f in b.faces if not pick(f.calc_center_median(), f.normal)]
    bmesh.ops.delete(b, geom=drop, context="FACES")
    b.normal_update()
    moves = [(v, v.normal.copy() * (-tuck if v.is_boundary else off)) for v in b.verts]
    for v, d in moves:
        v.co += d
    return ck.mesh_from(name, b, material)


def _chain(name, pts, r0, r1, material, segs=5):
    """Raiz/cicatriz: tubos emendados pelos pontos, afinando de r0 a r1."""
    out = []
    n = len(pts) - 1
    for i in range(n):
        a, b_ = r0 + (r1 - r0) * i / n, r0 + (r1 - r0) * (i + 1) / n
        out.append(ck.tube("%s_%d" % (name, i), pts[i], pts[i + 1], a, b_, material, segs))
        if i:
            out.append(ck.ball("%s_j%d" % (name, i), a * 0.98, pts[i], material))
    return out


def _tuft(name, a, b_, r, material, segs=6):
    """Tufo de pelo rombudo (cone de ponta grossa): lê como pelo, não como espinho."""
    return ck.tube(name, a, b_, r, r * 0.3, material, segs)


def _perp(d):
    d = V(d).normalized()
    u = d.cross(V((0, 0, 1)))
    if u.length < 0.2:
        u = d.cross(V((1, 0, 0)))
    u.normalize()
    return d, u, d.cross(u).normalized()


def _stuck(name, p, d, length, r, wood, fletch=None, cloth=None, broken=False):
    """Flecha/lança velha cravada em p, saindo na direção d. fletch = material da pena; cloth = trapo pendurado (lança)."""
    d, u, w = _perp(d)
    p = V(p)
    end = p + d * length
    out = [ck.tube(name, p - d * 0.06, end, r, r * 0.92, wood, 6)]
    if broken:                                     # haste partida: lasca torta na ponta
        out.append(ck.tube(name + "_snap", end, end + d * (r * 3.0) + u * (r * 2.2), r * 0.9, r * 0.15, wood, 5))
    if fletch:
        for i, side in enumerate((u, w)):
            out.append(ck.blade("%s_f%d" % (name, i), p + d * (length * 0.55), end + d * 0.004, r * 7.5, r * 0.7, fletch, side, 0.72))
        out.append(ck.tube(name + "_nock", end - d * 0.004, end + d * 0.02, r * 1.25, r * 1.1, wood, 6))
    if cloth:
        a = p + d * (length * 0.62)
        out.append(ck.tube(name + "_wrap", a - d * 0.04, a + d * 0.04, r * 1.5, r * 1.5, cloth, 6))
        hang = a + u * 0.03
        out.append(ck.blade(name + "_rag", hang, hang + V((u.x * 0.12, u.y * 0.12, -0.26)), 0.13, 0.016, cloth, d, 0.4))
        out.append(ck.blade(name + "_rag2", hang, hang + V((-u.x * 0.05 + w.x * 0.08, -u.y * 0.05 + w.y * 0.08, -0.18)), 0.09, 0.016, cloth, d, 0.5))
    return out


# ---------------------------------------------------------------------------
# Javali Ancestral
# ---------------------------------------------------------------------------
def ancestral_boar(cid="mob_ancestral_boar"):
    K = SIZE
    S = lambda p: tuple(x * K for x in p)
    bones = mk.pivots(body=S((0, 0.4, 0.62)), head=S((0, -0.74, 0.8)),
                      leg_fr=S((0.37, -0.42, 0.64)), leg_fl=S((-0.37, -0.42, 0.64)),
                      leg_br=S((0.34, 0.48, 0.64)), leg_bl=S((-0.34, 0.48, 0.64)))
    th = S((0, 0.84, 0.7))
    arm = lp.make_armature("rig_" + cid, dict(bones, tail=(th, (th[0], th[1] + 0.38, th[2] + 0.06), "body")))
    m = lambda n, col, rough=0.85, em=0.0: ck.mat("m_%s_%s" % (cid, n), col, rough, em)
    fur, dark, light, grey = m("fur", FUR), m("dark", FUR_D), m("light", FUR_L), m("grey", GREY)
    moss, moss2 = m("moss", MOSS, 0.95), m("moss2", MOSS_L, 0.95)
    stone, stone2, root = m("stone", STONE, 0.9), m("stone2", STONE_D, 0.9), m("root", ROOT, 0.9)
    ivory, ivory2, hoof, nose = m("ivory", IVORY, 0.5), m("ivory2", IVORY_D, 0.6), m("hoof", HOOF, 0.6), m("nose", NOSE, 0.6)
    wood, fletch, fletch2 = m("wood", WOOD, 0.9), m("fletch", FLETCH, 0.9), m("fletch2", FLETCH2, 0.9)
    cap, petal, scar = m("cap", CAP, 0.7), m("petal", PETAL, 0.8), m("scar", (0.84, 0.62, 0.56), 0.8)
    eye_d = m("socket", (0.12, 0.08, 0.08), 0.5)
    glow = ck.mat("glow_%s_eye" % cid, AMBER, 0.3, 1.3)
    parts, flat = [], set()

    def add(o, bone, faceted=False):
        for x in (o if isinstance(o, (list, tuple)) else [o]):
            parts.append((x, bone))
            if faceted:
                flat.add(x.name)

    # ---------------- tronco ----------------
    body = mk.skin_body("body", SPINE, [(i, i + 1) for i in range(len(SPINE) - 1)], fur)
    for v in body.data.vertices:
        v.co.x *= WIDE
    add(body, "body")
    tb = bmesh.new()
    tb.from_mesh(body.data)
    bvh = BVHTree.FromBMesh(tb)

    def cast(o, d):
        hit = bvh.ray_cast(V(o), V(d).normalized())
        return (hit[0], hit[1]) if hit[0] is not None else (None, None)

    def top(x, y, lift=0.0):
        p, n = cast((x, y, 5), (0, 0, -1))
        if p is None:
            p, n = V((x, y, 0.9)), V((0, 0, 1))
        return p + n * lift, n

    def flank(sx, y, z, lift=0.0):
        p, n = cast((sx * 3, y, z), (-sx, 0, 0))
        if p is None:
            p, n = V((sx * 0.3, y, z)), V((sx, 0, 0))
        return p + n * lift, n

    add(mk.blob("belly", 0.36, (0, -0.06, 0.44), light, (0.95, 1.9, 0.5)), "body")
    add(mk.blob("chest", 0.3, (0, -0.74, 0.52), light, (1.05, 0.8, 0.85)), "body")

    # ---------------- manta de musgo no lombo (duas camadas) + tufos ----------------
    def moss_pick(c, n):
        edge = 0.34 + 0.2 * math.sin(c.y * 8.5 + 0.7) * math.cos(c.x * 6.0) + 0.1 * math.sin(c.y * 21.0)
        return n.z > edge and -0.5 < c.y < 0.96

    def moss2_pick(c, n):
        return n.z > 0.72 + 0.14 * math.sin(c.y * 11.0 + c.x * 9.0) and -0.3 < c.y < 0.8 and (math.sin(c.y * 6.3 + 1.0) > -0.25)

    add(_shell("moss", body, moss_pick, 0.035, moss), "body")
    add(_shell("moss_hi", body, moss2_pick, 0.06, moss2), "body")
    for i, (x, y, r_, mt) in enumerate(((0.4, -0.3, 0.15, moss), (-0.44, -0.2, 0.14, moss), (0.42, 0.14, 0.13, moss), (-0.38, 0.34, 0.14, moss),
                                        (0.26, 0.6, 0.12, moss), (-0.14, -0.02, 0.12, moss2), (0.2, 0.36, 0.1, moss2), (-0.24, 0.66, 0.11, moss),
                                        (0.3, -0.06, 0.1, moss2), (-0.3, 0.1, 0.09, moss2))):
        p, n = top(x, y, 0.01)
        add(mk.blob("mosstuft%d" % i, r_, p, mt, (1.15, 1.25, 0.5), 2), "body")
    # barbas de musgo que escorrem pelo flanco (franja lida de lado e na câmera alta)
    for i, (sx, y, z, ln) in enumerate(((1, -0.24, 0.92, 0.24), (1, 0.1, 0.86, 0.2), (1, 0.42, 0.8, 0.22), (-1, -0.12, 0.9, 0.22), (-1, 0.22, 0.84, 0.24),
                                        (-1, 0.52, 0.76, 0.18))):
        p, n = flank(sx, y, z, -0.01)
        add(ck.blade("mossdrip%d" % i, p, p + V((sx * 0.04, 0.02, -ln)), 0.17, 0.035, moss, (0, 1, 0), 0.35), "body")

    # ---------------- pedras, raízes, cogumelos, brotos ----------------
    for i, (x, y, r_, mt, sub) in enumerate(((0.08, 0.26, 0.17, stone, 2), (-0.22, 0.48, 0.11, stone2, 1), (0.3, 0.0, 0.1, stone2, 1), (-0.12, -0.12, 0.08, stone, 1),
                                             (0.2, 0.56, 0.08, stone, 1), (-0.34, 0.12, 0.09, stone, 1))):
        p, n = top(x, y)
        add(_rock("stone%d" % i, p + n * (r_ * 0.25), r_, mt, 11 + i * 7, sub=sub), "body", True)
    # raízes grossas: saem do nó no alto da cernelha e descem pelos dois lados do lombo
    for i, path in enumerate((((0.06, -0.36), (0.26, -0.24), (0.42, -0.04), (0.5, 0.2), (0.48, 0.42)),
                              ((-0.04, -0.34), (-0.2, -0.16), (-0.3, 0.02), (-0.44, 0.26), (-0.46, 0.5)))):
        pts = [top(x, y, 0.02)[0] for x, y in path]
        add(_chain("root%d" % i, pts, 0.055, 0.02, root, 6), "body")
    knot, _n = top(0.02, -0.34, 0.03)
    add(ck.ball("rootknot", 0.075, knot, root, (1.2, 1.2, 0.8)), "body")
    # broto com duas folhas no nó das raízes
    st = knot + V((0.03, 0.05, 0.24))
    add(ck.tube("sprout", knot, st, 0.024, 0.014, root, 5), "body")
    add(ck.blade("leaf0", st, st + V((0.2, 0.05, 0.1)), 0.13, 0.02, moss2, (0, 1, 0), 0.5), "body")
    add(ck.blade("leaf1", st, st + V((-0.14, 0.14, 0.12)), 0.11, 0.02, moss2, (1, 1, 0), 0.5), "body")
    for i, (x, y, h, r_) in enumerate(((-0.36, -0.04, 0.1, 0.07), (-0.28, -0.1, 0.07, 0.05), (0.36, 0.38, 0.08, 0.06))):
        p, n = top(x, y)
        add(ck.tube("shroom%d" % i, p - n * 0.02, p + n * h, 0.022, 0.018, light, 5), "body")
        add(ck.ball("shroomcap%d" % i, r_, p + n * h, cap, (1.0, 1.0, 0.62)), "body")
    for i, (x, y) in enumerate(((0.3, 0.22), (-0.14, 0.6), (0.1, -0.1), (-0.4, 0.3), (0.06, 0.74))):
        p, n = top(x, y, 0.06)
        add(ck.ball("flower%d" % i, 0.032, p, petal), "body")

    # ---------------- crina: tufos grossos de cerdas escuras, da nuca à cernelha (moicano lido de cima e de lado) ----------------
    for i in range(6):
        y = -1.02 + i * 0.15
        p, n = top(0, y, -0.06)
        hgt = (0.2, 0.28, 0.34, 0.32, 0.26, 0.18)[i]
        add(_tuft("bristle%d" % i, p, p + V((0, 0.14, hgt)), 0.13, dark, 7), "body")
        if i in (1, 2, 3, 4):
            for sx in (-1, 1):
                q, n = top(sx * 0.15, y + 0.07, -0.05)
                add(_tuft("bristle%d_%d" % (i, sx), q, q + V((sx * 0.07, 0.12, hgt * 0.62)), 0.1, dark, 6), "body")
    # ombros pesados: massa de pelo escuro por cima do ombro, tufos rombudos, juba clara do peito
    for sx in (-1, 1):
        add(mk.blob("shoulderfur%d" % sx, 0.24, (sx * 0.42, -0.46, 0.8), dark, (0.7, 1.1, 1.05), 2), "body")
        for j in range(3):
            a = V((sx * (0.47 - j * 0.02), -0.56 + j * 0.15, 0.7 - j * 0.02))
            add(_tuft("shouldertuft%d_%d" % (sx, j), a, a + V((sx * 0.06, 0.06, -0.2)), 0.09, dark), "body")
    for i, (x, z) in enumerate(((-0.17, 0.42), (0.0, 0.38), (0.17, 0.42))):
        add(_tuft("dewlap%d" % i, (x, -0.86, z + 0.12), (x * 1.1, -0.84, z - 0.1), 0.1, light), "body")
    # cicatrizes de garra no flanco direito (-X)
    for i in range(3):
        a, _n = flank(-1, 0.02 + i * 0.11, 0.9 - i * 0.02, 0.004)
        b_, _n = flank(-1, 0.18 + i * 0.11, 0.6 - i * 0.02, 0.004)
        mid, _n = flank(-1, 0.1 + i * 0.11, 0.75 - i * 0.02, 0.01)
        add(_chain("scar%d" % i, [a, mid, b_], 0.026, 0.012, scar, 4), "body")

    # ---------------- flechas e lança de caçadas antigas ----------------
    p, n = top(-0.26, -0.4)
    add(_stuck("spear", p, (-0.38, 0.4, 0.84), 0.66, 0.028, wood, cloth=fletch, broken=True), "body")
    p, n = top(0.36, 0.1)
    add(_stuck("arrow0", p, (0.45, 0.25, 0.86), 0.36, 0.016, wood, fletch), "body")
    p, n = top(0.18, 0.66)
    add(_stuck("arrow1", p, (0.2, 0.55, 0.8), 0.32, 0.016, wood, fletch2), "body")
    p, n = flank(-1, 0.5, 0.78)
    add(_stuck("arrow2", p, (-0.8, 0.3, 0.52), 0.32, 0.016, wood, fletch), "body")
    p, n = top(0.36, -0.46)
    add(_stuck("arrow3", p, (0.5, -0.2, 0.84), 0.15, 0.017, wood, broken=True), "body")
    p, n = flank(1, 0.44, 0.7)
    add(_stuck("arrow4", p, (0.85, 0.4, 0.34), 0.3, 0.016, wood, fletch2), "body")

    # ---------------- cabeça (desenhada em volta de HEAD; cresce HEAD_K no fim) ----------------
    hc = V(HEAD)
    n_head = len(parts)
    add(mk.blob("skull", 0.31, hc, fur, (0.98, 1.0, 0.9)), "head")
    snout = mk.skin_body("snout", [((0, -1.08, 0.6), 0.25), ((0, -1.32, 0.55), 0.21), ((0, -1.52, 0.52), 0.17)], [(0, 1), (1, 2)], fur, sub=1)
    add(snout, "head")
    ny = min(v.co.y for v in snout.data.vertices)
    nz = 0.52
    add(ck.tube("nose", (0, ny + 0.04, nz), (0, ny - 0.05, nz - 0.005), 0.15, 0.14, nose, 10), "head")
    for sx in (-1, 1):
        add(ck.ball("nostril%d" % sx, 0.032, (sx * 0.06, ny - 0.05, nz + 0.01), eye_d, (1, 0.4, 1.4)), "head")
    add(mk.blob("jaw", 0.16, (0, -1.28, 0.43), light, (0.95, 1.7, 0.6), 2), "head")
    # sobrancelhas pesadas, olhos âmbar fundos
    for sx in (-1, 1):
        e = hc + V((sx * 0.2, -0.235, 0.06))
        add(ck.ball("socket%d" % sx, 0.07, e, eye_d, (0.8, 0.7, 1.0)), "head")
        add(ck.ball("eye%d" % sx, 0.045, e + V((sx * 0.022, -0.035, 0.0)), glow, (0.9, 0.8, 1.0)), "head")
        add(mk.blob("brow%d" % sx, 0.11, hc + V((sx * 0.19, -0.22, 0.17)), dark, (1.15, 1.05, 0.5), 2), "head")
        # costeletas claras (o bicho é velho): dois tufos rombudos de cada lado
        for j in range(2):
            a = hc + V((sx * 0.25, -0.04 + j * 0.12, -0.06 - j * 0.02))
            add(ck.tube("whisker%d_%d" % (sx, j), a, a + V((sx * 0.1, 0.09, -0.11)), 0.1, 0.05, grey, 6), "head")
    add(ck.blade("ear1", hc + V((0.2, 0.06, 0.18)), hc + V((0.46, 0.2, 0.4)), 0.22, 0.05, dark, (0, 1, 0.3), 0.45), "head")
    add(ck.blade("ear1_in", hc + V((0.22, 0.04, 0.2)), hc + V((0.4, 0.15, 0.36)), 0.11, 0.05, nose, (0, 1, 0.3), 0.45), "head")
    # orelha direita rasgada: duas pontas curtas
    add(ck.blade("ear-1a", hc + V((-0.2, 0.06, 0.18)), hc + V((-0.38, 0.1, 0.36)), 0.12, 0.05, dark, (0, 1, 0.3), 0.45), "head")
    add(ck.blade("ear-1b", hc + V((-0.21, 0.1, 0.17)), hc + V((-0.36, 0.26, 0.26)), 0.11, 0.05, dark, (0, 1, 0.3), 0.45), "head")
    for i, x in enumerate((-0.06, 0.06)):                      # barbicha curta
        add(_tuft("beard%d" % i, (x, -1.16, 0.4), (x * 1.3, -1.12, 0.29), 0.07, grey), "head")
    # presa grande curva (esquerda do bicho, +X): sai do lado do focinho, abre, sobe e volta para trás
    tusk = [((0.1, -1.36, 0.49), 0.09), ((0.33, -1.47, 0.46), 0.088), ((0.52, -1.51, 0.6), 0.072), ((0.61, -1.42, 0.82), 0.05), ((0.56, -1.24, 1.0), 0.02)]
    add(mk.skin_body("tusk_big", tusk, [(i, i + 1) for i in range(len(tusk) - 1)], ivory, sub=1), "head")
    add(ck.tube("tusk_gum1", (0.14, -1.38, 0.485), (0.27, -1.445, 0.47), 0.112, 0.105, ivory2, 8), "head")
    a, b_ = V(tusk[2][0]), V(tusk[3][0])
    add(ck.tube("tusk_band", a.lerp(b_, 0.25), a.lerp(b_, 0.45), 0.072, 0.066, ivory2, 8), "head")
    # presa direita quebrada: toco curto com a quebra em lascas
    add(ck.tube("tusk_stub", (-0.1, -1.36, 0.49), (-0.31, -1.47, 0.48), 0.088, 0.075, ivory, 8), "head")
    add(ck.tube("tusk_gum-1", (-0.14, -1.38, 0.485), (-0.25, -1.44, 0.48), 0.112, 0.105, ivory2, 8), "head")
    add(ck.tube("tusk_chip", (-0.3, -1.465, 0.455), (-0.39, -1.51, 0.56), 0.05, 0.008, ivory, 4), "head", True)
    add(ck.tube("tusk_chip2", (-0.3, -1.465, 0.5), (-0.36, -1.5, 0.43), 0.04, 0.008, ivory2, 4), "head", True)
    # presa de cima (amoladeira) só do lado da presa grande
    add(_tuft("whetter", (0.15, -1.36, 0.62), (0.26, -1.4, 0.76), 0.055, ivory2), "head")
    for o, _b in parts[n_head:]:
        for v in o.data.vertices:
            v.co = hc + (v.co - hc) * HEAD_K + V(HEAD_SHIFT)

    # ---------------- pernas grossas e curtas ----------------
    for bone, sx, front in (("leg_fr", 1, True), ("leg_fl", -1, True), ("leg_br", 1, False), ("leg_bl", -1, False)):
        if front:
            x, y = sx * 0.38, -0.42
            add(mk.blob("shoulder_" + bone, 0.22, (x, y, 0.56), fur, (0.82, 1.0, 1.25), 2), bone)
            r0, r1 = 0.165, 0.135
        else:
            x, y = sx * 0.35, 0.5
            add(mk.blob("haunch_" + bone, 0.25, (x - sx * 0.02, y - 0.04, 0.58), fur, (0.74, 1.0, 1.15), 2), bone)
            r0, r1 = 0.155, 0.128
        add(ck.tube("leg_" + bone, (x, y, 0.5), (x + sx * 0.01, y - 0.02, 0.13), r0, r1, fur, 8), bone)
        for j in range(4):                                     # tufo de pelo escuro acima do casco
            a = math.tau * (j + 0.5) / 4
            c = V((x + sx * 0.01 + math.cos(a) * r1 * 0.8, y - 0.02 + math.sin(a) * r1 * 0.8, 0.25))
            add(_tuft("fetlock%d_%s" % (j, bone), c, c + V((math.cos(a) * 0.05, math.sin(a) * 0.05, -0.14)), 0.075, dark), bone)
        add(ck.tube("hoof_" + bone, (x + sx * 0.01, y - 0.04, 0.14), (x + sx * 0.01, y - 0.04, 0.0), r1 * 0.98, r1 * 1.16, hoof, 8), bone, True)

    # ---------------- rabo fino com tufo ----------------
    tp = [((0, 0.72, 0.72), 0.06), ((0, 1.02, 0.67), 0.042), ((0, 1.13, 0.52), 0.03), ((0, 1.13, 0.4), 0.026)]
    add(mk.skin_body("whip", tp, [(0, 1), (1, 2), (2, 3)], fur, sub=1), "tail")
    add(mk.blob("whip_tuft", 0.07, (0, 1.14, 0.32), dark, (0.8, 0.9, 1.5), 2), "tail")
    tb.free()

    objs = [o for o, _b in parts]
    for o in objs:
        if o.name not in flat:
            ck._smooth(o.data)
    _outward(objs)
    for o in objs:
        for v in o.data.vertices:
            v.co *= K
    by_bone = {}
    for o, bone in parts:
        by_bone.setdefault(bone, []).append(o)
    for bone, objs_ in by_bone.items():
        lp.attach(ck._join(objs_, "ab_" + bone), arm, bone)
    _boar_clips(arm, K)
    legs = ("leg_fr", "leg_fl", "leg_br", "leg_bl")
    _ground(arm, [c for c in BOAR_CLIPS if c != "die"], legs, LEG_TUCK * K)
    _ground(arm, ["die"], (), 0.0, DIE_SINK, head=False)
    return arm


# ---------------------------------------------------------------------------
# Alce Ancião de chifres de cristal
# ---------------------------------------------------------------------------
ELK_SIZE = 0.6             # unidades de desenho -> nativo: cernelha a ~1,15, ponta dos chifres a ~2,0
ELK_TUCK = 0.3
ELK_SPINE = [((0, 0.92, 1.22), 0.33), ((0, 0.5, 1.28), 0.42), ((0, 0.0, 1.3), 0.45), ((0, -0.5, 1.36), 0.5), ((0, -0.85, 1.38), 0.4)]
ELK_NECK = [((0, -0.7, 1.42), 0.36), ((0, -1.0, 1.85), 0.3), ((0, -1.28, 2.2), 0.27)]
ELK_HEAD = (0, -1.45, 2.05)         # a cabeça é desenhada aqui e sobe ELK_HEAD_LIFT (pescoço erguido)
ELK_HEAD_LIFT = (0, 0.07, 0.23)
ELK_CLIPS = ("idle", "run", "attack", "hit", "die", "atk_charge", "slam", "roar", "shout", "maul", "pounce", "brace", "cast_ground")
ELK_IMPACT = {"attack": 5, "atk_charge": 5, "slam": 8, "roar": 7, "shout": 7, "maul": 7, "pounce": 9, "brace": 6, "cast_ground": 10}
ELK_GLOW = 1.0             # emissão do cristal (degraus de 0,25: EntityView.mob_glow)

E_FUR = (0.66, 0.5, 0.36)
E_FUR_D = (0.42, 0.3, 0.25)
E_FUR_L = (0.95, 0.88, 0.74)
E_MANE = (0.52, 0.72, 0.5)          # juba/barba de pelo verde-musgo claro
E_MANE_L = (0.7, 0.84, 0.58)
E_MANE_D = (0.38, 0.58, 0.42)
E_BARK = (0.5, 0.4, 0.32)
E_BARK_D = (0.36, 0.28, 0.24)
E_LICHEN = (0.78, 0.86, 0.6)
E_TEAL = (0.5, 0.88, 0.84)
E_LILAC = (0.72, 0.62, 0.98)
E_EYE = (0.4, 0.95, 0.8)
E_BONE = (0.9, 0.84, 0.72)
E_VINE = (0.4, 0.62, 0.34)
E_LEAF = (0.6, 0.8, 0.4)
E_ROSE = (0.92, 0.42, 0.5)
E_CREAM = (0.98, 0.93, 0.76)
E_SKY = (0.4, 0.62, 0.92)
E_GOLD = (0.96, 0.8, 0.36)
E_ONE = (1, 1, 1)


def _crystal(name, a, b_, r0, r1, material, segs=5, tip=0.24, spin=0.0):
    """Prisma de cristal facetado de a até b_, com as duas pontas em bico (as emendas viram quinas, sem esfera na junta)."""
    a, b_ = V(a), V(b_)
    d, u, w = _perp(b_ - a)
    ln = (b_ - a).length
    b = bmesh.new()
    ring = lambda c, r: [b.verts.new(c + (u * math.cos(spin + math.tau * i / segs) + w * math.sin(spin + math.tau * i / segs)) * r) for i in range(segs)]
    r_a, r_b = ring(a, r0), ring(a + d * (ln * (1.0 - tip)), r1)
    base, apex = b.verts.new(a - d * (r0 * 0.7)), b.verts.new(b_)
    for i in range(segs):
        j = (i + 1) % segs
        b.faces.new((r_a[i], r_a[j], r_b[j], r_b[i]))
        b.faces.new((r_b[i], r_b[j], apex))
        b.faces.new((r_a[j], r_a[i], base))
    return ck.mesh_from(name, b, material)


def _lock(name, a, b_, r, material, segs=6):
    """Mecha de pelo comprido, de ponta bem rombuda (o `_tuft` do javali lia como espeto em pelo longo)."""
    return ck.tube(name, a, b_, r, r * 0.52, material, segs)


def _vine(name, pts, r, material, segs=4):
    return [ck.tube("%s_%d" % (name, i), pts[i], V(pts[i]).lerp(V(pts[i + 1]), 1.06), r, r, material, segs) for i in range(len(pts) - 1)]


def ancient_elk(cid="mob_ancient_elk"):
    K = ELK_SIZE
    S = lambda p: tuple(x * K for x in p)
    rnd = random.Random(52)
    bones = mk.pivots(body=S((0, 0.75, 1.15)), head=S((0, -0.72, 1.45)),
                      leg_fr=S((0.33, -0.5, 1.15)), leg_fl=S((-0.33, -0.5, 1.15)),
                      leg_br=S((0.31, 0.75, 1.15)), leg_bl=S((-0.31, 0.75, 1.15)))
    th, ah = S((0, 0.86, 1.36)), S(V((0, -1.4, 2.28)) + V(ELK_HEAD_LIFT))
    arm = lp.make_armature("rig_" + cid, dict(bones, tail=(th, (th[0], th[1] + 0.3, th[2] + 0.04), "body"),
                                              antler=(ah, (ah[0], ah[1], ah[2] + 0.3), "head")))
    m = lambda n, col, rough=0.85, em=0.0: ck.mat("m_%s_%s" % (cid, n), col, rough, em)
    fur, dark, light = m("fur", E_FUR), m("dark", E_FUR_D), m("light", E_FUR_L)
    mane, mane2, mane3 = m("mane", E_MANE, 0.95), m("mane2", E_MANE_L, 0.95), m("mane3", E_MANE_D, 0.95)
    bark, bark2, lichen = m("bark", E_BARK, 0.95), m("bark2", E_BARK_D, 0.95), m("lichen", E_LICHEN, 0.95)
    bone, hoof, nose = m("bone", E_BONE, 0.6), m("hoof", (0.24, 0.2, 0.2), 0.6), m("nose", (0.3, 0.22, 0.22), 0.5)
    vine, leaf = m("vine", E_VINE, 0.9), m("leaf", E_LEAF, 0.9)
    rose, cream, sky, gold = m("rose", E_ROSE, 0.8), m("cream", E_CREAM, 0.8), m("sky", E_SKY, 0.8), m("gold", E_GOLD, 0.4)
    teal = ck.mat("glow_%s_crystal" % cid, E_TEAL, 0.3, ELK_GLOW)
    lilac = ck.mat("glow_%s_crystal2" % cid, E_LILAC, 0.3, ELK_GLOW)
    glow = ck.mat("glow_%s_eye" % cid, E_EYE, 0.3, 1.0)
    parts, flat = [], set()

    def add(o, bone_, faceted=False):
        for x in (o if isinstance(o, (list, tuple)) else [o]):
            parts.append((x, bone_))
            if faceted:
                flat.add(x.name)

    # ---------------- tronco ----------------
    body = mk.skin_body("body", ELK_SPINE, [(i, i + 1) for i in range(len(ELK_SPINE) - 1)], fur)
    add(body, "body")
    tb = bmesh.new()
    tb.from_mesh(body.data)
    bvh = BVHTree.FromBMesh(tb)

    def cast(o, d):
        hit = bvh.ray_cast(V(o), V(d).normalized())
        return (hit[0], hit[1]) if hit[0] is not None else (None, None)

    def top(x, y, lift=0.0):
        p, n = cast((x, y, 6), (0, 0, -1))
        if p is None:
            p, n = V((x, y, 1.7)), V((0, 0, 1))
        return p + n * lift, n

    def flank(sx, y, z, lift=0.0):
        p, n = cast((sx * 3, y, z), (-sx, 0, 0))
        if p is None:
            p, n = V((sx * 0.4, y, z)), V((sx, 0, 0))
        return p + n * lift, n

    def front(x, z, lift=0.0):
        p, n = cast((x, -5, z), (0, 1, 0))
        if p is None:
            p, n = V((x, -1.1, z)), V((0, -1, 0))
        return p + n * lift, n

    add(mk.blob("belly", 0.38, (0, 0.0, 0.98), light, (0.92, 2.1, 0.5)), "body")
    # garupa clara (espelho de cervo) e faixa escura no lombo
    add(_shell("rump", body, lambda c, n: c.y > 0.6 and n.y > 0.35 and c.z > 0.95, 0.02, light), "body")
    add(_shell("dorsal", body, lambda c, n: n.z > 0.86 + 0.05 * math.sin(c.y * 14.0) and -0.2 < c.y < 1.0, 0.02, dark), "body")
    for i, (x, y) in enumerate(((0.24, 0.46), (-0.3, 0.44), (0.34, 0.3), (-0.22, 0.24), (0.3, 0.1), (-0.36, 0.02), (0.14, 0.36), (-0.12, 0.5), (0.4, 0.42), (-0.42, 0.26))):
        p, n = cast((x, y, 6), (0, 0, -1))
        if p is None:
            continue
        add(ck.ball("spot%d" % i, 0.065, p, light, (1.0, 1.15, 0.22)), "body")

    # ---------------- capa de juba sobre a cernelha + tufos (pelo verde-musgo claro) ----------------
    def cape_pick(c, n):
        edge = 0.1 + 0.25 * math.sin(c.y * 9.0 + 0.4) * math.cos(c.x * 7.0)
        return n.z > 0.4 + edge and c.y < -0.3 + 0.12 * math.sin(c.x * 11.0)

    add(_shell("cape", body, cape_pick, 0.05, mane), "body")
    add(_shell("cape_hi", body, lambda c, n: n.z > 0.62 and c.y < -0.42, 0.085, mane2), "body")
    for i in range(6):                                         # crista da cernelha, penteada para trás
        y = -1.0 + i * 0.17
        p, n = top(0, y, -0.05)
        hgt = (0.2, 0.26, 0.3, 0.27, 0.22, 0.15)[i]
        add(_lock("crest%d" % i, p, p + V((0, 0.2, hgt)), 0.14, (mane2, mane)[i % 2], 7), "body")
        for sx in (-1, 1):
            q, n = top(sx * 0.2, y + 0.08, -0.04)
            add(_lock("crest%d_%d" % (i, sx), q, q + V((sx * 0.1, 0.18, hgt * 0.55)), 0.12, (mane, mane3)[i % 2], 6), "body")
    for i, (sx, y, z, ln) in enumerate(((1, -0.5, 1.62, 0.3), (1, -0.72, 1.5, 0.34), (1, -0.32, 1.66, 0.24), (-1, -0.5, 1.62, 0.3), (-1, -0.72, 1.5, 0.34),
                                        (-1, -0.32, 1.66, 0.24))):
        p, n = flank(sx, y, z, -0.01)                          # franja da capa que escorre pelo ombro
        add(_lock("capedrip%d" % i, p, p + V((sx * 0.07, 0.05, -ln)), 0.12, (mane, mane3, mane2)[i % 3], 6), "body")
    # peitoral: barba de pelo comprido no peito, em três fileiras
    for j in range(3):
        for i in range(-2, 3):
            if j == 2 and abs(i) == 2:
                continue
            x, zz = i * 0.17, 1.42 - j * 0.17
            p, n = front(x, zz, -0.03)
            add(_lock("bib%d_%d" % (j, i), p, p + V((x * 0.25, -0.1 + j * 0.03, -0.34 - 0.05 * (2 - abs(i)))), 0.15, (mane, mane2, mane3)[(i + j) % 3], 6), "body")

    # ---------------- casca nos ombros: placas rachadas, líquen e cristais miúdos ----------------
    def bark_pick(c, n):
        edge = 0.28 + 0.1 * math.sin(c.y * 13.0 + c.z * 9.0)
        return abs(n.x) > edge and -0.92 < c.y < -0.08 + 0.1 * math.sin(c.z * 12.0) and 1.02 < c.z < 1.84 and n.z < 0.78

    add(_shell("bark", body, bark_pick, 0.03, bark), "body", True)
    for sx in (-1, 1):
        for i, (y, zz, r_) in enumerate(((-0.66, 1.5, 0.15), (-0.42, 1.58, 0.14), (-0.56, 1.28, 0.15), (-0.28, 1.36, 0.13), (-0.76, 1.24, 0.11), (-0.18, 1.56, 0.1))):
            p, n = flank(sx, y, zz)
            add(_rock("plate%d_%d" % (sx, i), p + n * 0.01, r_, (bark2, bark)[i % 2], 31 + i * 5 + sx, (0.32, 0.85, 1.2)), "body", True)
        for i, (y, zz) in enumerate(((-0.5, 1.44), (-0.34, 1.22), (-0.7, 1.38))):
            p, n = flank(sx, y, zz, 0.035)
            add(ck.ball("lichen%d_%d" % (sx, i), 0.055, p, lichen, (0.3, 1.1, 1.0)), "body")
        for i, (x, y, ln, mt) in enumerate(((0.36, -0.52, 0.3, teal), (0.44, -0.36, 0.2, lilac), (0.3, -0.7, 0.18, lilac))):
            p, n = top(sx * x, y, -0.03)                       # cristais que brotam da casca
            add(_crystal("shard%d_%d" % (sx, i), p, p + V((sx * 0.5, 0.25 - i * 0.2, 1.0)).normalized() * ln, ln * 0.24, ln * 0.2, mt, 5), "body", True)

    # ---------------- pescoço e cabeça (osso head; o pivô fica na base do pescoço) ----------------
    hc = V(ELK_HEAD)
    neck = mk.skin_body("neck", ELK_NECK, [(0, 1), (1, 2)], dark, sub=1)
    add(neck, "head")
    add(_shell("neckmane", neck, lambda c, n: c.z < ELK_NECK[2][0][2] + 0.02 and c.y > ELK_NECK[2][0][1] - 0.06, 0.045, mane), "head")
    n0, n2 = V(ELK_NECK[0][0]), V(ELK_NECK[2][0])
    nd = (n2 - n0).normalized()
    nu = V((1, 0, 0))
    nw = nd.cross(nu).normalized()                             # aponta para baixo/frente (garganta)
    k = 0
    for ti, t in enumerate((0.2, 0.5, 0.8)):
        c = n0.lerp(n2, t)
        r_ = 0.36 + (0.27 - 0.36) * t
        for a_ in (-150, -100, -50, 0, 50, 100, 150):   # 0 = garganta, ±180 = nuca
            a = math.radians(a_ + (ti % 2) * 18)
            out = nu * math.sin(a) + nw * math.cos(a)
            p = c + out * (r_ * 0.86)
            ln = 0.3 + 0.14 * math.cos(a) + rnd.uniform(-0.03, 0.03)
            add(_lock("ruff%d" % k, p, p + out * 0.1 + V((0, 0.1, -ln)), 0.15, (mane, mane2, mane3)[k % 3], 6), "head")
            k += 1
    for i, t in enumerate((0.2, 0.45, 0.7, 0.92)):             # crista da nuca
        c = n0.lerp(n2, t) - nw * (0.3 - 0.06 * t)
        add(_lock("nape%d" % i, c, c + V((0, 0.22, 0.22)), 0.13, (mane2, mane)[i % 2], 7), "head")
    n_head = len(parts)
    add(mk.blob("skull", 0.3, hc, fur, (0.95, 1.05, 0.92)), "head")
    muzzle = mk.skin_body("muzzle", [((0, -1.55, 2.0), 0.24), ((0, -1.86, 1.86), 0.19), ((0, -2.08, 1.77), 0.16)], [(0, 1), (1, 2)], fur, sub=1)
    add(muzzle, "head")
    my = min(v.co.y for v in muzzle.data.vertices)
    add(mk.blob("muzzle_tip", 0.175, (0, my + 0.13, 1.75), light, (1.0, 0.95, 0.9), 2), "head")
    add(ck.ball("nose", 0.1, (0, my + 0.0, 1.8), nose, (1.15, 0.7, 0.75)), "head")
    add(mk.blob("jaw", 0.15, (0, -1.78, 1.74), light, (0.9, 1.8, 0.6), 2), "head")
    add(mk.blob("blaze", 0.1, hc + V((0, -0.2, 0.2)), light, (0.7, 1.5, 0.5), 2), "head")           # mancha clara na testa
    gem = hc + V((0, -0.3, 0.2))
    add(_crystal("browgem", gem + V((0, 0.03, -0.09)), gem + V((0, -0.05, 0.11)), 0.055, 0.05, teal, 4, 0.5), "head", True)
    for sx in (-1, 1):
        e = hc + V((sx * 0.235, -0.17, 0.05))
        add(ck.ball("eye%d" % sx, 0.072, e, glow, (0.7, 1.0, 1.1)), "head")
        add(mk.blob("brow%d" % sx, 0.1, e + V((-sx * 0.03, 0.0, 0.105)), dark, (0.9, 1.3, 0.4), 2), "head")
        ear0 = hc + V((sx * 0.22, 0.14, 0.1))
        add(ck.blade("ear%d" % sx, ear0, ear0 + V((sx * 0.46, 0.12, 0.06)), 0.24, 0.05, fur, (0, 0.5, 1), 0.5), "head")
        add(ck.blade("ear_in%d" % sx, ear0 + V((sx * 0.03, -0.03, 0)), ear0 + V((sx * 0.38, 0.07, 0.05)), 0.12, 0.05, light, (0, 0.5, 1), 0.5), "head")
        for j in range(2):                                     # costeletas de musgo
            a = hc + V((sx * 0.23, 0.0 + j * 0.13, -0.12))
            add(_lock("cheek%d_%d" % (sx, j), a, a + V((sx * 0.1, 0.1, -0.24)), 0.11, (mane2, mane)[j], 6), "head")
    for i, (x, y, ln) in enumerate(((0.0, -1.78, 0.46), (-0.09, -1.66, 0.4), (0.09, -1.66, 0.4), (0.0, -1.54, 0.5), (-0.1, -1.44, 0.38), (0.1, -1.44, 0.38))):
        add(_lock("beard%d" % i, (x, y, 1.74 - (i > 2) * 0.03), (x * 1.5, y + 0.07, 1.74 - ln), 0.1, (mane2, mane, mane3)[i % 3], 6), "head")

    # ---------------- chifres de cristal (osso antler: abre/pulsa por escala) ----------------
    for sx in (-1, 1):
        P = [V((sx * 0.17, -1.38, 2.3)), V((sx * 0.5, -1.3, 2.56)), V((sx * 0.92, -1.12, 2.78)), V((sx * 1.26, -0.82, 2.98)), V((sx * 1.4, -0.46, 3.14))]
        add(ck.tube("pedicle%d" % sx, P[0] - V((sx * 0.06, 0, 0.12)), P[0].lerp(P[1], 0.3), 0.13, 0.12, bone, 7), "antler")
        add(ck.tube("burr%d" % sx, P[0].lerp(P[1], 0.22), P[0].lerp(P[1], 0.36), 0.16, 0.14, bone, 7), "antler", True)
        rad = (0.14, 0.13, 0.115, 0.095, 0.03)
        for i in range(4):
            add(_crystal("beam%d_%d" % (sx, i), P[i].lerp(P[i + 1], 0.12 if i == 0 else 0.0), P[i + 1].lerp(P[i], -0.12), rad[i], rad[i + 1] if i < 3 else 0.06, teal, 6,
                         0.2 if i < 3 else 0.45, i * 0.5), "antler", True)
        tines = (                                               # (de onde sai, cotovelo, ponta, raio)
            (P[0].lerp(P[1], 0.62), V((sx * 0.4, -1.78, 2.5)), V((sx * 0.5, -2.04, 2.78)), 0.085),      # galho da testa, para a frente
            (P[1].lerp(P[2], 0.6), V((sx * 0.88, -1.48, 2.94)), V((sx * 1.0, -1.66, 3.2)), 0.08),
            (P[2].lerp(P[3], 0.55), V((sx * 1.3, -1.12, 3.1)), V((sx * 1.5, -1.24, 3.34)), 0.075),
            (P[3], V((sx * 1.52, -0.8, 3.06)), V((sx * 1.72, -0.72, 3.26)), 0.065),                     # ponta de fora
            (P[2], V((sx * 0.9, -0.84, 2.98)), V((sx * 0.84, -0.6, 3.2)), 0.07),                        # galho de trás
        )
        for i, (a, el, tip, r_) in enumerate(tines):
            if sx == -1 and i == 3:                            # o direito perdeu a ponta de fora: toco quebrado
                add(_crystal("tine%d_%d" % (sx, i), a, a.lerp(el, 0.7), r_, r_ * 0.9, teal, 5, 0.18), "antler", True)
                continue
            add(_crystal("tine%d_%da" % (sx, i), a, el.lerp(a, -0.1), r_, r_ * 0.86, teal, 5, 0.18, 0.4), "antler", True)
            add(_crystal("tine%d_%db" % (sx, i), el, tip, r_ * 0.86, r_ * 0.5, lilac, 5, 0.5, 0.9), "antler", True)
        add(_crystal("tip%d" % sx, P[3].lerp(P[4], 0.45), P[4] + (P[4] - P[3]).normalized() * 0.1, 0.07, 0.05, lilac, 5, 0.6), "antler", True)
        # lascas miúdas nas forquilhas
        for i, (c, d) in enumerate(((P[1], (sx * 0.2, 0.3, 1)), (P[2], (sx * 0.4, -0.3, 1)), (P[3], (-sx * 0.3, 0.3, 1)), (P[0].lerp(P[1], 0.5), (-sx * 0.5, 0.2, 1)),
                                    (P[1].lerp(P[2], 0.5), (sx * 0.1, 0.5, 0.9)), (P[2].lerp(P[3], 0.4), (-sx * 0.2, 0.5, 1)))):
            ln = 0.2 - 0.02 * i
            add(_crystal("chip%d_%d" % (sx, i), c, c + V(d).normalized() * ln, 0.05, 0.04, (lilac, teal)[i % 2], 4, 0.55), "antler", True)
        # cipó enrolado na haste, com folhas
        pts = []
        for i in range(11):
            t = i / 10.0 * 2.7
            s0 = min(2, int(t))
            c = P[s0].lerp(P[s0 + 1], t - s0)
            d, u, w = _perp(P[s0 + 1] - P[s0])
            a = i * 1.9
            pts.append(c + (u * math.cos(a) + w * math.sin(a)) * (rad[s0] + 0.03))
        add(_vine("vine%d" % sx, pts, 0.022, vine), "antler")
        for i in (2, 4, 6, 8, 10):
            q = pts[i]
            d = V((sx * rnd.uniform(-0.6, 0.9), rnd.uniform(-0.8, 0.8), 0.7)).normalized()
            add(ck.blade("vleaf%d_%d" % (sx, i), q, q + d * 0.19, 0.11, 0.016, leaf, (d.y, -d.x, 0.1), 0.5), "antler")
        # fitas élficas amarradas (oferendas): nó + duas pontas caídas; contas e pingentes
        ties = ((tines[1][1], rose, 0.52), (tines[2][1], sky, 0.44), (P[3].lerp(P[4], 0.3), cream, 0.5), (tines[0][1], cream if sx > 0 else rose, 0.36),
                (tines[4][1], sky if sx > 0 else cream, 0.4))
        for i, (q, mt, ln) in enumerate(ties):
            add(ck.tube("knot%d_%d" % (sx, i), q + V((0, 0, 0.05)), q - V((0, 0, 0.05)), 0.078, 0.078, mt, 6), "antler")
            for j, (dx, dy, kk) in enumerate(((0.07, 0.05, 1.0), (-0.05, 0.1, 0.72))):
                a = q - V((0, 0, 0.06))
                add(ck.blade("ribbon%d_%d_%d" % (sx, i, j), a, a + V((sx * dx, dy, -ln * kk)), 0.12, 0.014, mt, (1, 0.5 - j, 0), 0.75), "antler")
        for i, (q, ln, mt) in enumerate(((P[1].lerp(P[2], 0.3), 0.3, gold), (P[2].lerp(P[3], 0.85), 0.26, lilac), (tines[3][1], 0.22, gold))):
            if sx == -1 and i == 2:
                continue
            e = q + V((0, 0, -ln))
            add(ck.tube("thread%d_%d" % (sx, i), q, e, 0.01, 0.01, cream, 3), "antler")
            add(_crystal("charm%d_%d" % (sx, i), e + V((0, 0, 0.03)), e + V((0, 0, -0.13)), 0.045, 0.04, mt, 4, 0.6), "antler", True)
    # varal de bandeirolas entre os dois chifres (lido de cima)
    ga, gb = V((-0.92, -1.12, 2.78)), V((0.92, -1.12, 2.78))
    gp = []
    for i in range(9):
        t = i / 8.0
        sag = 4 * t * (1 - t)
        gp.append(ga.lerp(gb, t) + V((0, 0.2 * sag, -0.36 * sag)))
    add(_vine("garland", gp, 0.014, cream, 3), "antler")
    for i in range(1, 8):
        q = gp[i]
        add(ck.blade("pennant%d" % i, q + V((0, 0, 0.01)), q + V((0, 0.03, -0.27)), 0.2, 0.014, (rose, cream, sky)[i % 3], (1, 0, 0), 0.12), "antler")

    for o, _b in parts[n_head:]:
        for v in o.data.vertices:
            v.co += V(ELK_HEAD_LIFT)

    # ---------------- pernas compridas ----------------
    for bone_, sx, fr in (("leg_fr", 1, True), ("leg_fl", -1, True), ("leg_br", 1, False), ("leg_bl", -1, False)):
        if fr:
            x, y = sx * 0.34, -0.5
            add(mk.blob("shoulder_" + bone_, 0.25, (x, y, 1.08), fur, (0.8, 1.0, 1.35), 2), bone_)
            knee, foot = V((x, y - 0.02, 0.6)), V((x, y, 0.15))
            add(ck.tube("upper_" + bone_, (x, y, 1.02), knee, 0.16, 0.105, fur, 8), bone_)
            for j, (dy, zz, r_) in enumerate(((-0.1, 1.24, 0.13), (0.1, 1.14, 0.12), (-0.04, 0.98, 0.11))):       # casca que desce pelo ombro
                add(_rock("legbark%d_%s" % (j, bone_), (x + sx * 0.17, y + dy, zz), r_, (bark, bark2)[j % 2], 71 + j * 3 + sx, (0.4, 0.9, 1.2)), bone_, True)
            add(ck.ball("leglichen_" + bone_, 0.05, (x + sx * 0.2, y + 0.04, 1.3), lichen, (0.4, 1.1, 1.0)), bone_)
        else:
            x, y = sx * 0.32, 0.74
            add(mk.blob("haunch_" + bone_, 0.3, (x - sx * 0.02, y - 0.02, 1.1), fur, (0.74, 1.05, 1.25), 2), bone_)
            knee, foot = V((x, y + 0.2, 0.64)), V((x, y + 0.1, 0.15))
            add(ck.tube("upper_" + bone_, (x, y + 0.02, 0.98), knee, 0.175, 0.105, fur, 8), bone_)
        add(ck.ball("knee_" + bone_, 0.112, knee, fur), bone_)
        add(ck.tube("cannon_" + bone_, knee, foot, 0.098, 0.082, dark, 8), bone_)
        for j in range(4):                                     # tufo de musgo acima do casco
            a = math.tau * (j + 0.5) / 4
            c = V((foot.x + math.cos(a) * 0.07, foot.y + math.sin(a) * 0.07, 0.32))
            add(_lock("fetlock%d_%s" % (j, bone_), c, c + V((math.cos(a) * 0.06, math.sin(a) * 0.06, -0.2)), 0.085, (mane, mane2)[j % 2]), bone_)
        add(ck.tube("hoof_" + bone_, (foot.x, foot.y - 0.02, 0.17), (foot.x, foot.y - 0.03, 0.0), 0.09, 0.118, hoof, 8), bone_, True)

    # ---------------- rabo curto ----------------
    tp = [((0, 0.8, 1.4), 0.11), ((0, 1.02, 1.36), 0.09), ((0, 1.12, 1.2), 0.055)]
    add(mk.skin_body("scut", tp, [(0, 1), (1, 2)], light, sub=1), "tail")
    add(_lock("scut_top", (0, 0.84, 1.47), (0, 1.08, 1.4), 0.09, dark), "tail")
    tb.free()

    objs = [o for o, _b in parts]
    for o in objs:
        if o.name not in flat:
            ck._smooth(o.data)
    _outward(objs)
    for o in objs:
        for v in o.data.vertices:
            v.co *= K
    by_bone = {}
    for o, bone_ in parts:
        by_bone.setdefault(bone_, []).append(o)
    for bone_, objs_ in by_bone.items():
        lp.attach(ck._join(objs_, "ae_" + bone_), arm, bone_)
    _elk_clips(arm, K)
    legs = ("leg_fr", "leg_fl", "leg_br", "leg_bl")
    _ground(arm, [c for c in ELK_CLIPS if c != "die"], legs, ELK_TUCK * K, heads=("head", "antler"))
    # die: primeiro a raiz assenta o corpo de lado, depois a cabeça (que fica de pé, com os chifres para cima) ergue o que sobrar
    _ground(arm, ["die"], (), 0.0, DIE_SINK, head=False, only=("body", "tail") + legs)
    _ground(arm, ["die"], (), 0.0, DIE_SINK, heads=("head", "antler"))
    return arm


def _eclip(arm, name, keys, end, loop=False):
    """Como `_clip`, mas TODA chave leva escala (o osso `antler` abre por escala; osso sem faixa de escala herdaria a do clipe anterior)."""
    z = (0, 0, 0)
    full = {}
    for b_ in arm.data.bones.keys():
        ks = keys.get(b_) or [(1, z, z), (end, z, z)]
        full[b_] = [tuple(k) if len(k) > 3 else tuple(k) + (E_ONE,) for k in ks]
    lp.add_action(arm, name, full, end, loop=loop)


def _elk_clips(arm, K):
    """Mesmos eixos do javali (ver `_boar_clips`); a cabeça gira na BASE do pescoço (X+ = abaixa os chifres para a frente) e o
    osso `antler` (filho da cabeça) só muda de escala: os chifres abrem no urro e pulsam no `cast_ground`."""
    z = (0, 0, 0)
    r = lambda x=0.0, y=0.0, zz=0.0: (x, y, zz)
    p = lambda up=0.0, fwd=0.0: (0, up * K, fwd * K)
    sc = lambda seq: [(f, z, z, (s, s, s)) for f, s in seq]
    tau = math.tau
    legs = ("leg_fr", "leg_fl", "leg_br", "leg_bl")

    def planted(body, extra=None):
        return {g: bg.plant(body, g, (extra or {}).get(g, ())) for g in legs}

    # ---- idle: respira, olha devagar para os lados, abana o rabo; o cristal pulsa de leve ----
    n = 48
    k = {b_: [] for b_ in ("body", "head", "tail", "leg_fr", "leg_fl", "antler")}
    for f in list(range(1, n, 3)) + [n]:
        a = (f - 1) / (n - 1) * tau
        k["body"].append((f, r(1.2 * math.sin(a)), p(0.02 * (0.5 - 0.5 * math.cos(a)))))
        k["head"].append((f, r(2 + 3 * math.sin(a + 0.6), 0, 6 * math.sin(a)), z))
        k["tail"].append((f, r(6, 0, 16 * math.sin(2 * a)), z))
        k["leg_fr"].append((f, r(-1.2 * math.sin(a)), z))
        k["leg_fl"].append((f, r(-1.2 * math.sin(a)), z))
        s = 1.0 + 0.025 * (0.5 - 0.5 * math.cos(2 * a))
        k["antler"].append((f, z, z, (s, s, s)))
    _eclip(arm, "idle", k, n, loop=True)

    # ---- run: galope largo, cabeça à frente ----
    n = 16
    k = {b_: [] for b_ in ("body", "head", "tail") + legs}
    for f in range(1, n + 1):
        a = (f - 1) / (n - 1) * tau
        k["body"].append((f, r(-4 * math.cos(a), 0, 2 * math.sin(a)), p(0.1 * (0.5 + 0.5 * math.sin(a)))))
        k["head"].append((f, r(4 * math.cos(a) + 9, 0, -1.5 * math.sin(a)), z))
        k["leg_fr"].append((f, r(-27 * math.sin(a) + 4 * math.cos(a)), z))
        k["leg_fl"].append((f, r(-27 * math.sin(a - 0.5) + 4 * math.cos(a)), z))
        k["leg_br"].append((f, r(24 * math.sin(a + 0.25) + 4 * math.cos(a)), z))
        k["leg_bl"].append((f, r(24 * math.sin(a - 0.25) + 4 * math.cos(a)), z))
        k["tail"].append((f, r(30 + 10 * math.sin(a - 1.2), 0, 5 * math.sin(a + 0.6)), z))
    _eclip(arm, "run", k, n, loop=True)

    # ---- attack (5): abaixa os chifres e engancha para cima e para o lado ----
    e = 16
    _eclip(arm, "attack", {
        "body": [(1, z, z), (3, r(5), p(-0.03, -0.12)), (5, r(-6), p(0.03, 0.26)), (8, r(-4), p(0.02, 0.2)), (11, r(1), p(0, 0.06)), (e, z, z)],
        "head": [(1, z, z), (3, r(36, 0, 10), z), (5, r(-14, 0, -14), z), (8, r(-8, 0, -6), z), (11, r(2, 0, 3), z), (e, z, z)],
        "leg_fr": [(1, z, z), (3, r(6), z), (5, r(-16), z), (8, r(-10), z), (12, r(-3), z), (e, z, z)],
        "leg_fl": [(1, z, z), (3, r(5), z), (5, r(-11), z), (8, r(-7), z), (12, r(-2), z), (e, z, z)],
        "leg_br": [(1, z, z), (3, r(-12), z), (5, r(22), z), (8, r(15), z), (12, r(3), z), (e, z, z)],
        "leg_bl": [(1, z, z), (3, r(-12), z), (5, r(19), z), (8, r(12), z), (12, r(2), z), (e, z, z)],
        "tail": [(1, z, z), (3, r(14), z), (5, r(40), z), (9, r(20, 0, 12), z), (e, z, z)],
        "antler": sc([(1, 1), (3, 0.97), (5, 1.1), (9, 1.03), (e, 1)]),
    }, e)

    # ---- hit: tranco para trás, cabeça vira ----
    body = [(1, z, z), (2, r(-5, 0, 4), p(0.01, -0.09)), (5, r(3, 0, -2), p(0, -0.04)), (7, r(-1), p(0, -0.015)), (10, z, z)]
    k = planted(body, {"leg_fr": [(2, -9), (5, 4)], "leg_fl": [(2, -6), (5, 3)], "leg_br": [(2, 7), (5, -3)], "leg_bl": [(2, 5), (5, -3)]})
    k.update({"body": body, "head": [(1, z, z), (2, r(-18, 0, 16), z), (5, r(8, 0, -8), z), (7, r(-2), z), (10, z, z)],
              "tail": [(1, z, z), (2, r(34), z), (5, r(16, 0, 8), z), (10, z, z)],
              "antler": sc([(1, 1), (2, 0.95), (5, 1.02), (10, 1)])})
    _eclip(arm, "hit", k, 10)

    # ---- atk_charge (5): cava, abaixa os chifres à frente e dispara; no fim joga a cabeça para cima ----
    e = 20
    _eclip(arm, "atk_charge", {
        "body": [(1, z, z), (3, r(7), p(-0.03, -0.2)), (5, r(6), p(0.0, 0.5)), (8, r(4), p(0.02, 0.54)), (10, r(-9), p(0.04, 0.42)), (13, r(-3), p(0.01, 0.18)),
                 (17, r(1), p(0, 0.03)), (e, z, z)],
        "head": [(1, z, z), (3, r(44), z), (5, r(50), z), (8, r(46), z), (10, r(-20, 0, -10), z), (13, r(-6, 0, 5), z), (17, r(2), z), (e, z, z)],
        "leg_fr": [(1, z, z), (3, r(12), z), (5, r(-40), z), (8, r(-30), z), (10, r(4), z), (13, r(5), z), (e, z, z)],
        "leg_fl": [(1, z, z), (3, r(8), z), (5, r(-33), z), (8, r(-24), z), (10, r(7), z), (13, r(3), z), (e, z, z)],
        "leg_br": [(1, z, z), (3, r(-20), z), (5, r(34), z), (8, r(26), z), (10, r(12), z), (13, r(-2), z), (e, z, z)],
        "leg_bl": [(1, z, z), (3, r(-20), z), (5, r(29), z), (8, r(21), z), (10, r(10), z), (13, r(0), z), (e, z, z)],
        "tail": [(1, z, z), (3, r(24), z), (5, r(50), z), (8, r(44, 0, 8), z), (10, r(16, 0, -10), z), (14, r(6), z), (e, z, z)],
        "antler": sc([(1, 1), (3, 1.04), (5, 1.12), (8, 1.1), (11, 1.02), (e, 1)]),
    }, e)

    # ---- slam (8): empina alto, bate os cascos no ar e desaba com os dois; afunda, quica e assenta ----
    e = 24
    _eclip(arm, "slam", {
        "body": [(1, z, z), (3, r(5), p(-0.04)), (5, r(-40), p(0.03, -0.05)), (6, r(-46), p(0.04, -0.06)), (8, r(8), p(-0.03, 0.12)), (10, r(4), p(0.0, 0.1)),
                 (12, r(7), p(-0.02, 0.08)), (15, r(2), p(0, 0.03)), (20, r(-1), z), (e, z, z)],
        "head": [(1, z, z), (3, r(12), z), (5, r(-4), z), (6, r(6), z), (8, r(26), z), (10, r(14, 0, 5), z), (12, r(14, 0, -5), z), (16, r(3), z), (e, z, z)],
        "leg_fr": [(1, z, z), (3, r(6), z), (5, r(-56), z), (6, r(-34), z), (7, r(-30), z), (8, r(-8), z), (10, r(-4), z), (12, r(-7), z), (15, r(-2), z), (e, z, z)],
        "leg_fl": [(1, z, z), (3, r(6), z), (5, r(-30), z), (6, r(-58), z), (7, r(-28), z), (8, r(-8), z), (10, r(-4), z), (12, r(-7), z), (15, r(-2), z), (e, z, z)],
        "leg_br": [(1, z, z), (3, r(-5), z), (5, r(40), z), (6, r(46), z), (8, r(-8), z), (10, r(-4), z), (12, r(-7), z), (15, r(-2), z), (e, z, z)],
        "leg_bl": [(1, z, z), (3, r(-5), z), (5, r(40), z), (6, r(46), z), (8, r(-8), z), (10, r(-4), z), (12, r(-7), z), (15, r(-2), z), (e, z, z)],
        "tail": [(1, z, z), (4, r(40), z), (6, r(60), z), (8, r(-6), z), (12, r(10, 0, 10), z), (16, r(2, 0, -6), z), (e, z, z)],
        "antler": sc([(1, 1), (6, 1.0), (8, 1.12), (12, 1.04), (e, 1)]),
    }, e)

    # ---- roar / shout (7): recolhe, crava as patas, berra de cabeça erguida; os chifres abrem e tremem ----
    e = 24
    body = [(1, z, z), (4, r(6), p(-0.03, -0.04)), (7, r(-9), p(0.02, 0.02)), (9, r(-8, 0, 2), p(0.02, 0.02)), (11, r(-9, 0, -2), p(0.02, 0.02)),
            (13, r(-8, 0, 2), p(0.02, 0.02)), (16, r(-6), p(0.01, 0.01)), (20, r(2), z), (e, z, z)]
    k = planted(body, {"leg_fr": [(4, 0, 3), (7, 0, 9), (16, 0, 9), (20, 0, 2)], "leg_fl": [(4, 0, 3), (7, 0, 9), (16, 0, 9), (20, 0, 2)]})
    k.update({"body": body,
              "head": [(1, z, z), (4, r(26), z), (7, r(-32, 0, 8), z), (9, r(-30, 0, -8), z), (11, r(-32, 0, 8), z), (13, r(-30, 0, -6), z), (16, r(-20), z),
                       (20, r(4), z), (e, z, z)],
              "tail": [(1, z, z), (4, r(-4), z), (7, r(46, 0, 12), z), (9, r(46, 0, -12), z), (11, r(46, 0, 12), z), (13, r(40, 0, -8), z), (17, r(14), z), (e, z, z)],
              "antler": sc([(1, 1), (4, 0.94), (7, 1.22), (9, 1.14), (11, 1.22), (13, 1.14), (16, 1.12), (20, 1.0), (e, 1)])})
    for name in ("roar", "shout"):
        _eclip(arm, name, {b_: list(v) for b_, v in k.items()}, e)

    # ---- maul (7): recolhe os chifres para um lado e varre cruzando a frente ----
    e = 18
    body = [(1, z, z), (3, r(4, -10), p(-0.02, -0.05)), (5, r(6, -16), p(-0.02, -0.08)), (7, r(2, 15), p(0.02, 0.16)), (9, r(1, 18), p(0.02, 0.14)),
            (12, r(0, 7), p(0, 0.05)), (e, z, z)]
    k = planted(body, {"leg_fr": [(5, 8), (7, -11), (9, -8), (12, -2)], "leg_fl": [(5, -5), (7, -6), (9, -5)], "leg_br": [(5, -6), (7, 9), (9, 6)],
                       "leg_bl": [(5, -6), (7, 8), (9, 5)]})
    k.update({"body": body,
              "head": [(1, z, z), (3, r(16, 0, -18), z), (5, r(28, 0, -32), z), (7, r(18, 0, 32), z), (9, r(8, 0, 38), z), (12, r(0, 0, 10), z), (e, z, z)],
              "tail": [(1, z, z), (5, r(12, 0, -18), z), (7, r(30, 0, 22), z), (11, r(8, 0, -8), z), (e, z, z)],
              "antler": sc([(1, 1), (5, 0.97), (7, 1.1), (10, 1.03), (e, 1)])})
    _eclip(arm, "maul", k, e)

    # ---- pounce (9): agacha, salta para a frente e cai nos cascos da frente ----
    e = 20
    _eclip(arm, "pounce", {
        "body": [(1, z, z), (3, r(4), p(-0.05, -0.06)), (5, r(7), p(-0.09, -0.12)), (7, r(-14), p(0.4, 0.3)), (8, r(-3), p(0.38, 0.46)), (9, r(9), p(0.0, 0.52)),
                 (11, r(6), p(-0.04, 0.42)), (13, r(3), p(-0.02, 0.26)), (17, r(-1), p(0, 0.05)), (e, z, z)],
        "head": [(1, z, z), (5, r(14), z), (7, r(-10), z), (9, r(30), z), (11, r(16), z), (14, r(4), z), (e, z, z)],
        "leg_fr": [(1, z, z), (5, r(14), z), (7, r(-48), z), (8, r(-34), z), (9, r(-9), z), (11, r(-6), z), (13, r(-3), z), (e, z, z)],
        "leg_fl": [(1, z, z), (5, r(14), z), (7, r(-40), z), (8, r(-28), z), (9, r(-9), z), (11, r(-6), z), (13, r(-3), z), (e, z, z)],
        "leg_br": [(1, z, z), (5, r(-24), z), (7, r(42), z), (8, r(34), z), (9, r(-9), z), (11, r(-6), z), (13, r(-3), z), (e, z, z)],
        "leg_bl": [(1, z, z), (5, r(-24), z), (7, r(36), z), (8, r(30), z), (9, r(-9), z), (11, r(-6), z), (13, r(-3), z), (e, z, z)],
        "tail": [(1, z, z), (5, r(-8), z), (7, r(50), z), (9, r(10), z), (13, r(8, 0, 8), z), (e, z, z)],
        "antler": sc([(1, 1), (7, 1.0), (9, 1.1), (13, 1.02), (e, 1)]),
    }, e)

    # ---- brace (6): crava as patas abertas, abaixa o corpo e põe os chifres à frente como um muro ----
    e = 18
    body = [(1, z, z), (3, r(-3), p(0.02)), (6, r(5), p(-0.1, 0.04)), (9, r(4), p(-0.085, 0.04)), (12, r(5), p(-0.1, 0.04)), (15, r(2), p(-0.02, 0.01)), (e, z, z)]
    spread = [(6, 0, 9), (12, 0, 9)]
    k = planted(body, {g: spread for g in legs})
    k.update({"body": body, "head": [(1, z, z), (3, r(-8), z), (6, r(34), z), (9, r(30), z), (12, r(34), z), (15, r(8), z), (e, z, z)],
              "tail": [(1, z, z), (6, r(-8), z), (12, r(-6), z), (e, z, z)],
              "antler": sc([(1, 1), (6, 1.08), (9, 1.05), (12, 1.08), (e, 1)])})
    _eclip(arm, "brace", k, e)

    # ---- cast_ground (10): ergue a cabeça, baixa os chifres até quase o chão e o cristal estoura em luz (erupção de cristais) ----
    e = 24
    body = [(1, z, z), (4, r(-4), p(0.02, -0.03)), (8, r(5), p(-0.04, 0.03)), (10, r(9), p(-0.08, 0.06)), (12, r(8), p(-0.07, 0.06)), (14, r(9), p(-0.08, 0.06)),
            (18, r(3), p(-0.02, 0.02)), (e, z, z)]
    k = planted(body, {"leg_fr": [(8, 0, 4), (10, 0, 9), (14, 0, 9), (18, 0, 3)], "leg_fl": [(8, 0, 4), (10, 0, 9), (14, 0, 9), (18, 0, 3)]})
    k.update({"body": body,
              "head": [(1, z, z), (4, r(-18), z), (8, r(34), z), (10, r(56), z), (12, r(52), z), (14, r(56), z), (18, r(22), z), (e, z, z)],
              "tail": [(1, z, z), (4, r(10), z), (10, r(44), z), (14, r(40, 0, 10), z), (18, r(12), z), (e, z, z)],
              "antler": sc([(1, 1), (4, 1.0), (8, 0.92), (10, 1.26), (12, 1.14), (14, 1.24), (18, 1.08), (e, 1)])})
    _eclip(arm, "cast_ground", k, e)

    # ---- die: empina com o golpe, os joelhos da frente cedem, tomba de lado; a cabeça fica de pé no chão, chifres para cima, e o cristal apaga ----
    s = 1.4
    f = lambda x: int(round(1 + (x - 1) * s))
    e = f(24)
    roll = -84
    hx, hy, hz = ELK_DIE_HEAD
    _eclip(arm, "die", {
        "body": [(1, z, z), (f(4), r(-10), p(0.02, -0.05)), (f(9), r(8), p(-0.08, 0.02)), (f(14), r(2), p(-0.02)), (e, r(2), p(-0.02))],
        "head": [(1, z, z), (f(4), r(-28, 0, 8), z), (f(9), r(24), z), (f(14), r(hx, hy, hz), z), (f(17), r(hx - 9, hy, hz), z), (f(20), r(hx, hy, hz), z), (e, r(hx, hy, hz), z)],
        "leg_fr": [(1, z, z), (f(4), r(-14), z), (f(9), r(26), z), (f(14), r(-16), z), (f(17), r(-23), z), (e, r(-16), z)],
        "leg_fl": [(1, z, z), (f(4), r(-10), z), (f(9), r(22), z), (f(14), r(-8), z), (f(17), r(-13), z), (e, r(-8), z)],
        "leg_br": [(1, z, z), (f(4), r(7), z), (f(9), r(-14), z), (f(14), r(13), z), (f(17), r(20), z), (e, r(13), z)],
        "leg_bl": [(1, z, z), (f(4), r(7), z), (f(9), r(-14), z), (f(14), r(22), z), (f(17), r(27), z), (e, r(22), z)],
        "tail": [(1, z, z), (f(4), r(30), z), (f(9), r(-10), z), (f(14), r(6, 0, 10), z), (f(17), r(10, 0, 18), z), (e, r(4, 0, 12), z)],
        "root": [(1, z, z), (f(9), z, z), (f(14), r(0, 0, roll), z), (f(17), r(0, 0, roll + 7), z), (f(20), r(0, 0, roll), z), (e, r(0, 0, roll), z)],
        "antler": sc([(1, 1), (f(4), 1.1), (f(9), 1.0), (f(14), 0.94), (e, 0.9)]),
    }, e)


ELK_DIE_HEAD = (30, 80, 0)          # pose da cabeça tombada (X abaixa, Y rola de volta, Z vira): acertada nas fotos




# ---------------------------------------------------------------------------
# Basilisco das Ruínas
# ---------------------------------------------------------------------------
BAS_SIZE = 0.42            # unidades de desenho -> nativo: ~2,7 de comprido, lombo a ~0,55, coluna das costas a ~0,85
BAS_TUCK = 0.3
BAS_SPINE = [((0, 0.95, 0.72), 0.44), ((0, 0.45, 0.78), 0.54), ((0, -0.1, 0.8), 0.58), ((0, -0.65, 0.78), 0.54), ((0, -1.05, 0.74), 0.46)]
BAS_WIDE, BAS_FLAT = 1.25, 0.88     # tronco largo e baixo (lagarto lido de cima)
BAS_CLIPS = ("idle", "run", "attack", "hit", "die", "atk_charge", "slam", "roar", "shout", "maul", "pounce", "brace", "cast_ground")
BAS_IMPACT = {"attack": 5, "atk_charge": 5, "slam": 8, "roar": 7, "shout": 7, "maul": 7, "pounce": 9, "brace": 6, "cast_ground": 10}
BAS_GLOW_EYE = 1.0         # olhos (degraus de 0,25: EntityView.mob_glow)
BAS_GLOW_THROAT = 0.75     # papo: mais fraco que os olhos

B_SCALE = (0.46, 0.5, 0.5)        # escama cinza-pedra puxada para o azul (o bicho é frio, a ruína é quente)
B_SCALE_D = (0.31, 0.35, 0.4)
B_BELLY = (0.8, 0.8, 0.7)
B_RUIN = (0.84, 0.75, 0.58)         # pedra clara das ruínas
B_RUIN_D = (0.6, 0.51, 0.42)
B_RUNE = (0.3, 0.56, 0.62)          # runa apagada (não brilha)
B_SPIKE = (0.66, 0.66, 0.68)
B_MOSS = (0.38, 0.58, 0.3)
B_MOSS_L = (0.6, 0.74, 0.34)
B_DUST = (0.74, 0.7, 0.6)
B_IVORY = (0.96, 0.92, 0.8)
B_MOUTH = (0.74, 0.4, 0.46)
B_PUPIL = (0.16, 0.12, 0.1)
B_EYE = (1.0, 0.88, 0.5)            # ouro pálido
B_THROAT = (0.98, 0.92, 0.62)


def _sq(o, c, s):
    """Achata/alarga a malha em volta de c."""
    c = V(c)
    for v in o.data.vertices:
        d = v.co - c
        v.co = c + V((d.x * s[0], d.y * s[1], d.z * s[2]))
    return o


def _place(objs, rot, loc):
    """Peças modeladas na origem -> giradas (graus XYZ) e levadas a loc."""
    from mathutils import Euler
    mt = Euler([math.radians(a) for a in rot], "XYZ").to_matrix()
    for o in objs:
        for v in o.data.vertices:
            v.co = mt @ v.co + V(loc)
    return objs


def _drum(name, a, b_, r, stone, band, segs=10):
    """Tambor de coluna: cilindro facetado com um filete em cada ponta."""
    a, b_ = V(a), V(b_)
    d = (b_ - a).normalized()
    out = [ck.tube(name, a, b_, r, r, stone, segs)]
    for i, c in enumerate((a + d * 0.05, b_ - d * 0.05)):
        out.append(ck.tube("%s_band%d" % (name, i), c - d * 0.03, c + d * 0.03, r * 1.07, r * 1.07, band, segs))
    return out


def _stele(name, w, ln, th, stone, rune, seed, rows=2, cols=3):
    """Laje entalhada deitada (face de cima = +Z): moldura rasa e runas apagadas em relevo baixo."""
    rnd = random.Random(seed)
    out = [ck.box(name, (w, ln, th), (0, 0, 0), stone, th * 0.2)]
    zt = th * 0.5 + 0.004
    bar = lambda i, sx, sy, cx, cy: out.append(ck.box("%s_r%d" % (name, i), (sx, sy, 0.014), (cx, cy, zt), rune))
    n = 0
    for sy in (-1, 1):                                          # filetes da moldura
        bar(n, w * 0.78, 0.022, 0, sy * ln * 0.41)
        n += 1
    g = min(w * 0.8 / cols, ln * 0.66 / rows)
    for j in range(rows):
        for i in range(cols):
            cx, cy = (i - (cols - 1) * 0.5) * g, (j - (rows - 1) * 0.5) * g * 1.12
            kind = rnd.randrange(4)
            s = g * 0.62
            t = g * 0.17
            if kind == 0:                                       # T
                bar(n, s, t, cx, cy + s * 0.4); bar(n + 1, t, s, cx, cy - s * 0.1)
            elif kind == 1:                                     # dois traços
                bar(n, t, s, cx - s * 0.3, cy); bar(n + 1, t, s, cx + s * 0.3, cy)
            elif kind == 2:                                     # canto
                bar(n, s, t, cx, cy - s * 0.4); bar(n + 1, t, s, cx - s * 0.4, cy)
            else:                                               # cruz
                bar(n, s, t, cx, cy); bar(n + 1, t, s, cx, cy)
            n += 2
    return out


def _statue_head(name, r, marble, dark):
    """Cabeça de estátua (olha para -Y, topo +Z): rosto liso, sobrancelha reta, cabelo em touca e toco do pescoço."""
    out = [mk.blob(name, r, (0, 0, 0), marble, (0.9, 1.0, 1.14), 2)]
    out.append(mk.blob(name + "_hair", r * 1.03, (0, r * 0.16, r * 0.26), dark, (0.95, 1.0, 0.98), 2))
    out.append(ck.box(name + "_brow", (r * 1.2, r * 0.2, r * 0.13), (0, -r * 0.88, r * 0.3), marble, r * 0.03))
    out.append(ck.tube(name + "_nose", (0, -r * 0.98, r * 0.24), (0, -r * 1.12, -r * 0.2), r * 0.07, r * 0.13, marble, 4))
    for sx in (-1, 1):
        out.append(ck.ball("%s_eye%d" % (name, sx), r * 0.14, (sx * r * 0.36, -r * 0.84, r * 0.1), dark, (1.0, 0.4, 0.6)))
    out.append(ck.box(name + "_lip", (r * 0.42, r * 0.1, r * 0.06), (0, -r * 0.9, -r * 0.52), dark))
    out.append(ck.tube(name + "_neck", (0, r * 0.08, -r * 0.8), (0, r * 0.16, -r * 1.5), r * 0.52, r * 0.46, marble, 7))
    return out


def ruins_basilisk(cid="mob_ruins_basilisk"):
    K = BAS_SIZE
    S = lambda p: tuple(x * K for x in p)
    rnd = random.Random(77)
    bones = mk.pivots(body=S((0, 0.9, 0.72)), head=S((0, -1.2, 0.78)),
                      leg_fr=S((0.55, -0.85, 0.62)), leg_fl=S((-0.55, -0.85, 0.62)),
                      leg_br=S((0.55, 0.75, 0.62)), leg_bl=S((-0.55, 0.75, 0.62)))
    t1, t2, jw, gz = S((0, 1.05, 0.68)), S((0, 2.25, 0.44)), S((0, -1.45, 0.6)), S((0, -1.85, 0.8))
    arm = lp.make_armature("rig_" + cid, dict(bones, tail=(t1, (t1[0], t1[1] + 0.3, t1[2] + 0.04), "body"),
                                              tail2=(t2, (t2[0], t2[1] + 0.3, t2[2] + 0.04), "tail"),
                                              jaw=(jw, (jw[0], jw[1] - 0.3, jw[2]), "head"),
                                              gaze=(gz, (gz[0], gz[1], gz[2] + 0.3), "head")))
    m = lambda n, col, rough=0.85, em=0.0: ck.mat("m_%s_%s" % (cid, n), col, rough, em)
    scale_, dark, light = m("scale", B_SCALE), m("dark", B_SCALE_D), m("belly", B_BELLY)
    ruin, ruin2, rune, spike = m("ruin", B_RUIN, 0.95), m("ruin2", B_RUIN_D, 0.95), m("rune", B_RUNE, 0.8), m("spike", B_SPIKE, 0.8)
    moss, moss2, dust = m("moss", B_MOSS, 0.95), m("moss2", B_MOSS_L, 0.95), m("dust", B_DUST, 0.95)
    ivory, mouth, pupil = m("ivory", B_IVORY, 0.5), m("mouth", B_MOUTH, 0.7), m("pupil", B_PUPIL, 0.4)
    eye = ck.mat("glow_%s_eye" % cid, B_EYE, 0.3, BAS_GLOW_EYE)
    throat = ck.mat("glow_%s_throat" % cid, B_THROAT, 0.4, BAS_GLOW_THROAT)
    parts, flat = [], set()

    def add(o, bone_, faceted=False):
        for x in (o if isinstance(o, (list, tuple)) else [o]):
            parts.append((x, bone_))
            if faceted:
                flat.add(x.name)

    # ---------------- tronco ----------------
    body = mk.skin_body("body", BAS_SPINE, [(i, i + 1) for i in range(len(BAS_SPINE) - 1)], scale_)
    _sq(body, (0, 0, 0.76), (BAS_WIDE, 1, BAS_FLAT))
    add(body, "body")
    tb = bmesh.new()
    tb.from_mesh(body.data)
    bvh = BVHTree.FromBMesh(tb)

    def top(x, y, lift=0.0):
        hit = bvh.ray_cast(V((x, y, 6)), V((0, 0, -1)))
        p, n = (hit[0], hit[1]) if hit[0] is not None else (V((x, y, 1.2)), V((0, 0, 1)))
        return p + n * lift, n

    def flank(sx, y, z, lift=0.0):
        hit = bvh.ray_cast(V((sx * 4, y, z)), V((-sx, 0, 0)))
        p, n = (hit[0], hit[1]) if hit[0] is not None else (V((sx * 0.6, y, z)), V((sx, 0, 0)))
        return p + n * lift, n

    add(mk.blob("belly", 0.5, (0, -0.05, 0.47), light, (1.2, 2.5, 0.5)), "body")
    add(_shell("dorsal", body, lambda c, n: n.z > 0.74 + 0.1 * math.sin(c.y * 11.0), 0.02, dark), "body")
    add(_shell("dust", body, lambda c, n: 0.05 < n.z < 0.7 and math.sin(c.y * 6.3 + abs(c.x) * 4.0 + 0.8) > 0.42, 0.024, dust), "body")
    add(_shell("moss", body, lambda c, n: n.z > 0.5 and math.sin(c.y * 4.6 + 2.0) * math.cos(c.x * 3.2 + 0.5) > 0.36, 0.045, moss), "body")
    # escudos de pedra em duas fileiras no alto dos flancos
    for sx in (-1, 1):
        for i in range(7):
            y = -0.98 + i * 0.32
            p, n = top(sx * (0.56 + 0.05 * math.sin(i * 1.3)), y + (0.08 if sx > 0 else 0.0), 0.0)
            add(_rock("scute%d_%d" % (sx, i), p, 0.15 - 0.012 * abs(i - 3), (dark, spike)[i % 2], 11 + i * 3 + sx, (1.0, 1.3, 0.42)), "body", True)
        for i, (y, zz) in enumerate(((-0.5, 0.62), (0.0, 0.56), (0.5, 0.6))):                         # placas baixas no flanco
            p, n = flank(sx, y, zz)
            add(_rock("plate%d_%d" % (sx, i), p, 0.13, dark, 41 + i * 5 + sx, (0.4, 1.3, 1.0)), "body", True)
    for i, (y, ln) in enumerate(((-1.08, 0.26), (-0.9, 0.32), (0.98, 0.3), (1.14, 0.24))):         # espinhos da espinha onde não há ruína
        p, n = top(0, y, -0.04)
        add(_crystal("dspike%d" % i, p, p + V((0, 0.12, 1)).normalized() * ln, 0.1, 0.075, spike, 5, 0.6), "body", True)

    # ---------------- ruínas que cresceram no lombo ----------------
    # coluna de pé (dois tambores desencontrados, topo partido) atrás dos ombros
    p, n = top(-0.12, -0.5)
    ax = V((-0.1, 0.16, 1)).normalized()
    a0 = p - ax * 0.14
    a1 = a0 + ax * 0.46
    add(_drum("col0", a0, a1, 0.28, ruin, ruin2), "body", True)
    a1b = a1 + V((0.04, -0.03, 0))
    a2 = a1b + (ax + V((0.06, 0.02, 0))).normalized() * 0.38
    add(_drum("col1", a1b, a2, 0.25, ruin, ruin2), "body", True)
    add(_rock("coltop", a2 + V((0.03, 0, 0.02)), 0.21, ruin2, 5, (1.0, 1.0, 0.5)), "body", True)
    add(mk.blob("colmoss", 0.16, a2 + V((-0.08, 0.06, 0.07)), moss2, (1.1, 1.0, 0.5), 2), "body")
    add(mk.blob("colmoss2", 0.2, p + V((0.24, 0.12, 0.0)), moss, (1.2, 1.1, 0.5), 2), "body")
    # tambor caído, meio enterrado, no flanco esquerdo
    p, n = top(-0.46, 0.12)
    d = V((0.28, 1, 0.06)).normalized()
    add(_drum("fallen", p - d * 0.24 + V((0, 0, 0.06)), p + d * 0.24 + V((0, 0, 0.06)), 0.21, ruin, ruin2), "body", True)
    # capitel tombado no ombro direito
    p, n = top(0.42, -0.74)
    cap = [ck.box("capital", (0.48, 0.48, 0.11), (0, 0, 0), ruin, 0.02), ck.tube("capital_ech", (0, 0, -0.04), (0, 0, -0.24), 0.22, 0.16, ruin2, 8)]
    add(_place(cap, (24, -30, 15), p + V((0, 0, 0.14))), "body", True)
    # laje grande entalhada, deitada no meio do lombo com as runas para cima
    p, n = top(0.24, 0.22)
    add(_place(_stele("stele", 0.66, 0.9, 0.12, ruin, rune, 3, 3, 3), (-12, 12, -20), p + V((0, 0, 0.1))), "body", True)
    # laje menor fincada na anca esquerda
    p, n = top(-0.3, 0.74)
    add(_place(_stele("stele2", 0.42, 0.56, 0.1, ruin, rune, 9, 2, 2), (58, 0, 24), p + V((0, 0, 0.14))), "body", True)
    # cabeça de estátua tombada na anca direita
    p, n = top(0.4, 0.84)
    add(_place(_statue_head("statue", 0.29, ruin, ruin2), (-62, 24, -30), p + V((0.02, 0, 0.13))), "body")
    for i, (x, y, r_, mt) in enumerate(((0.12, -0.2, 0.12, ruin2), (-0.2, 0.42, 0.11, ruin), (0.6, 0.5, 0.1, ruin2), (-0.56, -0.3, 0.1, ruin), (0.1, 0.84, 0.1, ruin2),
                                        (-0.62, 0.5, 0.09, ruin2), (0.62, -0.2, 0.1, ruin), (-0.3, -0.86, 0.09, ruin2))):
        p, n = top(x, y, 0.02)                                 # entulho
        add(_rock("rubble%d" % i, p, r_, mt, 60 + i * 7), "body", True)
    for i, (x, y, r_, mt) in enumerate(((0.5, 0.1, 0.15, moss), (-0.14, 0.14, 0.13, moss2), (0.56, 0.74, 0.12, moss), (-0.5, 0.42, 0.13, moss2), (0.3, -0.42, 0.12, moss),
                                        (-0.54, -0.62, 0.12, moss), (0.0, 0.64, 0.11, moss2))):
        p, n = top(x, y, 0.02)                                 # almofadas de musgo entre as pedras
        add(mk.blob("mosspad%d" % i, r_, p, mt, (1.2, 1.2, 0.5), 2), "body")

    # ---------------- pescoço, crânio, coroa (osso head) ----------------
    neck = mk.skin_body("neck", [((0, -0.95, 0.76), 0.42), ((0, -1.3, 0.8), 0.42), ((0, -1.6, 0.84), 0.42)], [(0, 1), (1, 2)], scale_, sub=1)
    add(_sq(neck, (0, 0, 0.8), (1.18, 1, 0.9)), "head")
    skull = mk.skin_body("skull", [((0, -1.6, 0.92), 0.46), ((0, -2.0, 0.9), 0.44), ((0, -2.4, 0.8), 0.32), ((0, -2.64, 0.74), 0.2)], [(0, 1), (1, 2), (2, 3)], scale_, sub=2)
    add(_sq(skull, (0, -2.0, 0.9), (1.25, 1, 0.72)), "head")
    add(_shell("skullcap", skull, lambda c, n: n.z > 0.62 + 0.1 * math.sin(c.y * 14.0) and c.y > -2.5, 0.018, dark), "head")
    add(mk.blob("palate", 0.26, (0, -2.02, 0.62), mouth, (1.2, 1.6, 0.2), 2), "head")
    wid = lambda y: 0.55 + (0.4 - 0.55) * (-1.9 - y) / 0.5 if y > -2.4 else 0.4 + (0.2 - 0.4) * (-2.4 - y) / 0.3
    for sx in (-1, 1):
        for i, y in enumerate((-1.96, -2.14, -2.32, -2.5, -2.66)):                                    # dentes de cima
            x = sx * (wid(y) - 0.07)
            ln = 0.15 if i != 3 else 0.22
            add(ck.tube("tooth%d_%d" % (sx, i), (x, y, 0.66), (x * 1.02, y - 0.01, 0.66 - ln), 0.05, 0.008, ivory, 4), "head", True)
        add(ck.ball("nostril%d" % sx, 0.02, (sx * 0.09, -2.76, 0.83), dark, (1, 1, 0.6)), "head")
        e = V((sx * 0.46, -1.94, 1.08))
        out = V((sx * 0.75, -0.3, 0.55)).normalized()
        add(ck.ball("eye%d" % sx, 0.23, e, eye), "gaze")
        pu = ck.ball("pupil%d" % sx, 0.16, (0, 0, 0), pupil, (0.3, 0.42, 1.0))          # fenda vertical, deitada na córnea
        q = V((1, 0, 0)).rotation_difference(out)
        for v in pu.data.vertices:
            v.co = q @ v.co + e + out * 0.19
        add(pu, "gaze")
        add(mk.blob("brow%d" % sx, 0.16, e + V((-sx * 0.06, 0.16, 0.19)), dark, (0.9, 1.2, 0.36), 2), "head")
        add(_rock("ridge%d" % sx, e + V((-sx * 0.07, -0.05, 0.2)), 0.16, dark, 100 + sx, (1.3, 1.6, 0.36)), "head", True)
        add(_crystal("browhorn%d" % sx, e + V((-sx * 0.04, 0.24, 0.16)), e + V((sx * 0.14, 0.56, 0.42)), 0.085, 0.06, spike, 5, 0.6), "head", True)
        for j, (y, zz, ln) in enumerate(((-1.62, 0.7, 0.34), (-1.5, 0.56, 0.26))):                      # espinhos da bochecha, para trás e para fora
            b0 = V((sx * 0.5, y, zz))
            add(_crystal("cheek%d_%d" % (sx, j), b0, b0 + V((sx * 0.8, 0.5, 0.1)).normalized() * ln, 0.09, 0.06, spike, 5, 0.6), "head", True)
        add(mk.blob("pouch%d" % sx, 0.17, (sx * 0.5, -1.42, 0.62), throat, (0.8, 1.2, 1.0), 2), "gaze")      # bolsas do papo que aparecem de cima
    # coroa: leque de espinhos de pedra na nuca, o do meio mais alto; aro de pedra na base
    for i, a_ in enumerate((-66, -44, -22, 0, 22, 44, 66)):
        a = math.radians(a_)
        b0 = V((math.sin(a) * 0.5, -1.56, 0.92 + math.cos(a) * 0.27))
        ln = 0.56 - 0.2 * abs(a_) / 66.0 - (0.08 if i % 2 else 0.0)
        tip = b0 + V((math.sin(a) * 0.72, 0.4, math.cos(a) * 0.72 + 0.25)).normalized() * ln
        add(_crystal("crown%d" % i, b0 - (tip - b0) * 0.2, tip, 0.12, 0.085, (spike, ruin)[i % 2], 5, 0.55, i * 0.7), "head", True)
        add(_rock("crownbase%d" % i, b0 + V((0, 0.02, 0.0)), 0.11, ruin2, 90 + i, (1.0, 1.0, 0.7)), "head", True)
    for i, (x, y) in enumerate(((0, -1.86), (-0.16, -2.06), (0.16, -2.06), (0, -2.26))):               # botões de pedra no alto do focinho
        add(_rock("knob%d" % i, (x, y, 1.21 - 0.3 * (-1.86 - y)), 0.075, spike, 120 + i, (1.0, 1.2, 0.6)), "head", True)
    add(mk.blob("neckmoss", 0.2, (0.2, -1.28, 1.14), moss, (1.2, 1.3, 0.4), 2), "head")
    add(mk.blob("neckdust", 0.18, (-0.24, -1.2, 1.12), dust, (1.2, 1.3, 0.4), 2), "head")

    # ---------------- mandíbula (osso jaw) e papo/olhos (osso gaze: incham por escala) ----------------
    jaw = mk.skin_body("jaw", [((0, -1.5, 0.5), 0.3), ((0, -2.0, 0.5), 0.3), ((0, -2.5, 0.52), 0.2)], [(0, 1), (1, 2)], light, sub=1)
    add(_sq(jaw, (0, -2.0, 0.5), (1.3, 1, 0.6)), "jaw")
    add(mk.blob("tongue", 0.25, (0, -2.0, 0.63), mouth, (1.15, 1.6, 0.22), 2), "jaw")
    for sx in (-1, 1):
        for i, y in enumerate((-2.05, -2.23, -2.41, -2.58)):
            x = sx * (wid(y) - 0.13)
            add(ck.tube("ltooth%d_%d" % (sx, i), (x, y, 0.62), (x, y, 0.75), 0.045, 0.008, ivory, 4), "jaw", True)
        add(_rock("jawscute%d" % sx, (sx * 0.36, -1.9, 0.36), 0.1, dark, 130 + sx, (0.5, 1.4, 0.8)), "jaw", True)
    add(mk.blob("throat", 0.32, (0, -1.5, 0.44), throat, (1.2, 1.25, 0.75), 2), "gaze")

    # ---------------- patas abertas de lagarto ----------------
    for bone_, sx, fr in (("leg_fr", 1, True), ("leg_fl", -1, True), ("leg_br", 1, False), ("leg_bl", -1, False)):
        y0, kk = (-0.85, 1.0) if fr else (0.75, 1.14)
        sh = V((sx * 0.6, y0, 0.64))
        el = V((sx * 1.04, y0 + (0.12 if fr else -0.14), 0.62))
        an = V((sx * 1.12, y0 + (-0.08 if fr else 0.04), 0.16))
        add(mk.blob("shoulder_" + bone_, 0.3 * kk, sh, scale_, (1.0, 1.1, 0.95), 2), bone_)
        add(ck.tube("upper_" + bone_, sh, el, 0.23 * kk, 0.19 * kk, scale_, 8), bone_)
        add(ck.ball("elbow_" + bone_, 0.2 * kk, el, scale_), bone_)
        add(ck.tube("lower_" + bone_, el, an, 0.18 * kk, 0.15 * kk, dark, 8), bone_)
        foot = V((an.x + sx * 0.03, an.y - 0.14, 0.09 * kk + 0.003))
        add(mk.blob("foot_" + bone_, 0.2 * kk, foot, dark, (1.05, 1.35, 0.45), 2), bone_)
        for j, a_ in enumerate((-32, 0, 32)):
            a = math.radians(a_ + sx * 12)
            c0 = foot + V((math.sin(a) * 0.12, -math.cos(a) * 0.2, 0.0))
            add(ck.tube("claw%d_%s" % (j, bone_), c0, c0 + V((math.sin(a) * 0.14, -math.cos(a) * 0.2, -0.075)), 0.07, 0.012, ivory, 5), bone_, True)
        add(_rock("legscute_" + bone_, sh + V((sx * 0.1, 0, 0.24 * kk)), 0.18 * kk, spike, 150 + sx + fr * 3, (1.1, 1.2, 0.4)), bone_, True)
        add(_rock("elbowscute_" + bone_, el + V((sx * 0.12, 0, 0.1)), 0.13 * kk, dark, 160 + sx + fr * 3, (0.6, 1.1, 1.0)), bone_, True)
        if (sx > 0) == fr:
            add(mk.blob("legmoss_" + bone_, 0.13, sh + V((sx * 0.02, 0.1, 0.3 * kk)), moss2, (1.2, 1.2, 0.45), 2), bone_)

    # ---------------- rabo grosso em dois ossos, com um tambor de coluna enfiado e a ponta em clava de entulho ----------------
    ta = mk.skin_body("tail", [((0, 0.95, 0.72), 0.46), ((0, 1.5, 0.64), 0.43), ((0, 2.3, 0.48), 0.36)], [(0, 1), (1, 2)], scale_, sub=2)
    add(_sq(ta, (0, 0, 0.6), (1.12, 1, 1)), "tail")
    add(mk.blob("tailjoint", 0.37, (0, 2.26, 0.48), scale_, (1.1, 1, 1), 2), "tail")
    tz = lambda y: 0.72 + (0.48 - 0.72) * (y - 0.95) / 1.35 if y < 2.3 else 0.48 + (0.34 - 0.48) * (y - 2.3) / 1.0
    tr = lambda y: 0.46 + (0.36 - 0.46) * (y - 0.95) / 1.35 if y < 2.3 else 0.36 + (0.2 - 0.36) * (y - 2.3) / 1.0
    for i, y in enumerate((1.3, 1.56, 2.2, 2.46, 2.72, 2.96, 3.16)):
        b0 = V((0, y, tz(y) + tr(y) * 0.8))
        ln = 0.3 - 0.025 * i
        add(_crystal("tspike%d" % i, b0, b0 + V((0, 0.2, 1)).normalized() * ln, 0.095 - 0.006 * i, 0.07 - 0.005 * i, spike, 5, 0.6), "tail" if y < 2.3 else "tail2", True)
    add(_shell("taildust", ta, lambda c, n: n.z > 0.2 and math.sin(c.y * 7.0 + 1.0) > 0.5, 0.022, dust), "tail")
    add(_drum("tailring", (0, 1.74, 0.6), (0, 2.04, 0.55), 0.5, ruin, ruin2), "tail", True)
    add(mk.blob("ringmoss", 0.16, (0.14, 1.84, 1.08), moss, (1.3, 1.1, 0.4), 2), "tail")
    tc = mk.skin_body("tail2", [((0, 2.2, 0.49), 0.36), ((0, 2.8, 0.4), 0.28), ((0, 3.3, 0.34), 0.2)], [(0, 1), (1, 2)], scale_, sub=1)
    add(_sq(tc, (0, 0, 0.4), (1.1, 1, 1)), "tail2")
    add(_rock("club0", (0, 3.4, 0.34), 0.26, ruin2, 201, (1.0, 1.0, 0.85)), "tail2", True)
    add(_rock("club1", (0.16, 3.3, 0.4), 0.16, ruin, 202), "tail2", True)
    add(_rock("club2", (-0.17, 3.34, 0.36), 0.17, ruin, 203), "tail2", True)
    for i, dd in enumerate(((0.9, 0.5, 0.3), (-0.9, 0.5, 0.3), (0, 0.9, 0.5), (0.5, 0.2, 0.9), (-0.5, 0.3, 0.85))):
        c0 = V((0, 3.4, 0.36))
        add(_crystal("clubspike%d" % i, c0 + V(dd).normalized() * 0.12, c0 + V(dd).normalized() * 0.42, 0.08, 0.06, spike, 5, 0.6), "tail2", True)
    tb.free()

    objs = [o for o, _b in parts]
    for o in objs:
        if o.name not in flat:
            ck._smooth(o.data)
    _outward(objs)
    for o in objs:
        for v in o.data.vertices:
            v.co *= K
    by_bone = {}
    for o, bone_ in parts:
        by_bone.setdefault(bone_, []).append(o)
    for bone_, objs_ in by_bone.items():
        lp.attach(ck._join(objs_, "rb_" + bone_), arm, bone_)
    _bas_clips(arm, K)
    legs = ("leg_fr", "leg_fl", "leg_br", "leg_bl")
    heads = ("head", "jaw", "gaze")
    _tail_ground(arm, BAS_CLIPS)
    _ground(arm, [c for c in BAS_CLIPS if c != "die"], legs, BAS_TUCK * K, heads=heads)
    _ground(arm, ["die"], legs, BAS_TUCK * K, DIE_SINK, heads=heads)
    return arm


def _tail_ground(arm, clips, bones=("tail", "tail2"), report=True):
    """Rabo comprido rente ao chão: quadro a quadro, o osso cuja malha passaria do chão sobe de 1° em 1° (X+ = sobe), da base para
    a ponta, antes do `_ground` (senão a batida do rabo levantava o bicho inteiro pela raiz)."""
    import numpy as np
    ad = arm.animation_data
    sc = bpy.context.scene
    meshes = {o.parent_bone: o for o in arm.children if o.type == "MESH"}
    co = {}
    for b_ in bones:
        o = meshes[b_]
        a = np.empty(len(o.data.vertices) * 3, dtype=np.float64)
        o.data.vertices.foreach_get("co", a)
        co[b_] = np.concatenate([a.reshape(-1, 3), np.ones((len(o.data.vertices), 1))], axis=1)
    low = lambda b_: float((co[b_] @ np.array(meshes[b_].matrix_world)[2]).min())
    tracks = {t.name: t for t in ad.nla_tracks}
    for t in ad.nla_tracks:
        t.mute = True
    for name in clips:
        act = tracks[name].strips[0].action
        ad.action = act
        if getattr(ad, "action_slot", None) is None and getattr(act, "slots", None):
            ad.action_slot = act.slots[0]
        worst = 0
        for f in range(1, int(round(act.frame_range[1])) + 1):
            sc.frame_set(f)
            bpy.context.view_layer.update()
            for b_ in bones:
                pb = arm.pose.bones[b_]
                for _i in range(70):
                    if low(b_) >= 0.0:
                        break
                    pb.rotation_euler.x += math.radians(1.0)
                    bpy.context.view_layer.update()
                    worst = max(worst, _i + 1)
                pb.keyframe_insert("rotation_euler", frame=f)
        if report:
            print("TAILFIX %-11s rabo sobe até %d°" % (name, worst))
        ad.action = None
    for t in ad.nla_tracks:
        t.mute = False
    for b_ in arm.pose.bones:
        b_.rotation_euler = (0, 0, 0)
        b_.location = (0, 0, 0)
        b_.scale = (1, 1, 1)
    sc.frame_set(1)


def _bas_clips(arm, K):
    """Eixos (medidos): corpo X+ = focinho desce, Y+ = focinho vai para +X, Z = rola, loc (0, cima, frente), gira em volta da anca;
    cabeça X+ = desce, Z+ = focinho para -X; mandíbula X- = ABRE; rabo/rabo2 X+ = sobe, Z+ = ponta para -X; patas pelo `bg.limb`
    (quadro, x, abre, giro): x- e giro- = pata para a frente (o giro varre rente ao chão, andar de lagarto), abre+ = levanta para fora.
    O osso `gaze` (olhos, pupilas, papo e bolsas) só muda de ESCALA: incha no olhar petrificante (`_eclip`: toda chave leva escala)."""
    z = (0, 0, 0)
    r = lambda x=0.0, y=0.0, zz=0.0: (x, y, zz)
    p = lambda up=0.0, fwd=0.0: (0, up * K, fwd * K)
    sc = lambda seq: [(f, z, z, (s, s, s)) for f, s in seq]
    jw = lambda seq: [(f, (-a, 0, 0), z) for f, a in seq]           # graus de boca ABERTA
    tau = math.tau
    sin, cos = math.sin, math.cos
    legs = ("leg_fr", "leg_fl", "leg_br", "leg_bl")

    def planted(body, extra=None):
        return {g: bg.plant(body, g, (extra or {}).get(g, ())) for g in legs}

    def step(seq):
        """{pata: [(quadro, x, abre, giro)]} -> chaves"""
        return {g: bg.limb(g, [(1, 0)] + list(v)) for g, v in seq.items()}

    # ---- idle: respira, olha devagar para os lados, o rabo varre o chão; os olhos pulsam ----
    n = 48
    k = {b_: [] for b_ in ("body", "head", "jaw", "tail", "tail2", "gaze")}
    for f in list(range(1, n, 3)) + [n]:
        a = (f - 1) / (n - 1) * tau
        k["body"].append((f, r(0, 1.2 * sin(a)), p(0.02 * (0.5 - 0.5 * cos(a)))))
        k["head"].append((f, r(1.5 * sin(a + 0.6), 0, 7 * sin(a)), z))
        k["jaw"].append((f, r(-2 - 2 * sin(a + 0.6)), z))
        k["tail"].append((f, r(0, 0, 9 * sin(a + 0.5)), z))
        k["tail2"].append((f, r(0, 0, 14 * sin(a - 0.4)), z))
        s = 1.0 + 0.05 * (0.5 - 0.5 * cos(2 * a))
        k["gaze"].append((f, z, z, (s, s, s)))
    _eclip(arm, "idle", k, n, loop=True)

    # ---- run: andar de lagarto (pares em diagonal), o tronco serpenteia e o rabo segue em onda ----
    n = 16
    k = {b_: [] for b_ in ("body", "head", "jaw", "tail", "tail2") + legs}
    ph = {"leg_fr": 0.0, "leg_bl": 0.0, "leg_fl": math.pi, "leg_br": math.pi}
    for f in range(1, n + 1):
        a = (f - 1) / (n - 1) * tau
        k["body"].append((f, r(0, -6 * sin(a), 1.5 * cos(a)), p(0.03 * (0.5 + 0.5 * cos(2 * a)))))
        k["head"].append((f, r(2, 0, -5 * sin(a)), z))
        k["jaw"].append((f, r(-3), z))
        k["tail"].append((f, r(3, 0, 14 * sin(a - 1.0)), z))
        k["tail2"].append((f, r(2, 0, 20 * sin(a - 2.0)), z))
        for g in legs:
            b = a + ph[g]
            k[g].append(bg.limb(g, [(f, -14 * sin(b), 12 * max(0.0, cos(b)), -22 * sin(b))])[0])
    _eclip(arm, "run", k, n, loop=True)

    # ---- attack (5): recolhe a cabeça de boca aberta e dá o bote, a mandíbula fecha no impacto ----
    e = 16
    k = step({"leg_fr": [(3, 8, 0, 8), (5, -12, 4, -14), (8, -8, 0, -10), (12, -2), (e, 0)], "leg_fl": [(3, 6, 0, 6), (5, 12, 0, 12), (8, 8, 0, 8), (12, 2), (e, 0)],
              "leg_br": [(3, -6, 0, -6), (5, 14, 0, 14), (8, 10, 0, 10), (12, 2), (e, 0)], "leg_bl": [(3, -6, 0, -6), (5, 12, 0, 12), (8, 8, 0, 8), (12, 2), (e, 0)]})
    k.update({
        "body": [(1, z, z), (3, r(-2, 5), p(0.0, -0.16)), (5, r(2, -5), p(0.0, 0.32)), (8, r(1, -3), p(0, 0.26)), (12, r(0), p(0, 0.06)), (e, z, z)],
        "head": [(1, z, z), (3, r(-16, 0, -12), z), (5, r(8, 0, 10), z), (8, r(4, 0, 6), z), (12, r(0), z), (e, z, z)],
        "jaw": jw([(1, 0), (3, 34), (4, 40), (5, 2), (8, 6), (12, 2), (e, 0)]),
        "tail": [(1, z, z), (3, r(4, 0, 12), z), (5, r(10, 0, -14), z), (9, r(4, 0, 6), z), (e, z, z)],
        "tail2": [(1, z, z), (3, r(4, 0, 18), z), (5, r(12, 0, -8), z), (9, r(4, 0, -12), z), (e, z, z)],
        "gaze": sc([(1, 1), (3, 1.08), (5, 1.0), (e, 1)]),
    })
    _eclip(arm, "attack", k, e)

    # ---- hit: tranco para trás, cabeça vira de boca entreaberta ----
    body = [(1, z, z), (2, r(-3, 4, 3), p(0.01, -0.12)), (5, r(1, -2, -1), p(0, -0.05)), (7, r(0), p(0, -0.02)), (10, z, z)]
    k = planted(body, {"leg_fr": [(2, -8, 0, -8), (5, 3)], "leg_fl": [(2, -6, 0, -6), (5, 2)], "leg_br": [(2, -6, 0, -6), (5, 2)], "leg_bl": [(2, -5, 0, -5), (5, 2)]})
    k.update({"body": body, "head": [(1, z, z), (2, r(-14, 0, 16), z), (5, r(5, 0, -7), z), (7, r(-1), z), (10, z, z)],
              "jaw": jw([(1, 0), (2, 16), (5, 6), (10, 0)]),
              "tail": [(1, z, z), (2, r(10, 0, -10), z), (5, r(4, 0, 8), z), (10, z, z)],
              "tail2": [(1, z, z), (2, r(14, 0, -16), z), (5, r(4, 0, 12), z), (10, z, z)],
              "gaze": sc([(1, 1), (2, 0.9), (5, 1.04), (10, 1)])})
    _eclip(arm, "hit", k, 10)

    # ---- atk_charge (5): agacha, recua e dispara rente ao chão de boca aberta; fecha no fim e sacode a cabeça ----
    e = 20
    k = step({"leg_fr": [(3, 10, 0, 12), (5, -16, 8, -22), (8, 14, 0, 18), (10, -8, 6, -10), (13, 4), (e, 0)],
              "leg_fl": [(3, 8, 0, 10), (5, 14, 0, 18), (8, -16, 8, -22), (10, 8, 0, 10), (13, 3), (e, 0)],
              "leg_br": [(3, -8, 0, -10), (5, 16, 0, 20), (8, -12, 8, -16), (10, 10, 0, 12), (13, 2), (e, 0)],
              "leg_bl": [(3, -8, 0, -10), (5, -12, 8, -16), (8, 16, 0, 20), (10, 8, 0, 10), (13, 2), (e, 0)]})
    k.update({
        "body": [(1, z, z), (3, r(3, 4), p(-0.06, -0.26)), (5, r(2, -5), p(-0.05, 0.62)), (8, r(1, 5), p(-0.03, 0.72)), (10, r(-3, -3), p(0.0, 0.56)), (13, r(-1), p(0, 0.24)),
                 (17, r(0), p(0, 0.04)), (e, z, z)],
        "head": [(1, z, z), (3, r(6), z), (5, r(-2, 0, 5), z), (8, r(0, 0, -5), z), (10, r(-16, 0, -12), z), (13, r(-4, 0, 8), z), (17, r(1), z), (e, z, z)],
        "jaw": jw([(1, 0), (3, 4), (5, 30), (8, 34), (9, 4), (10, 2), (13, 8), (e, 0)]),
        "tail": [(1, z, z), (3, r(2, 0, -10), z), (5, r(10, 0, 12), z), (8, r(10, 0, -14), z), (10, r(6, 0, 10), z), (14, r(2, 0, -4), z), (e, z, z)],
        "tail2": [(1, z, z), (3, r(2, 0, -16), z), (5, r(8, 0, -6), z), (8, r(8, 0, 16), z), (10, r(6, 0, -14), z), (14, r(2, 0, 8), z), (e, z, z)],
        "gaze": sc([(1, 1), (3, 0.95), (5, 1.1), (8, 1.1), (11, 1.0), (e, 1)]),
    })
    _eclip(arm, "atk_charge", k, e)

    # ---- slam (8): torce o tronco, ergue o rabo enrolado para um lado e desce a clava no chão cruzando para o outro; quica e assenta ----
    e = 24
    body = [(1, z, z), (3, r(3, 7), p(-0.03, -0.04)), (5, r(5, 13), p(-0.02, -0.07)), (6, r(6, 15), p(0.0, -0.07)), (8, r(-2, -9), p(-0.07, 0.06)), (10, r(0, -6), p(-0.02, 0.04)),
            (12, r(-1, -7), p(-0.045, 0.04)), (16, r(0, -2), p(0, 0.01)), (20, z, z), (e, z, z)]
    k = planted(body, {g: [(8, 0, 8), (12, 0, 6), (16, 0, 1)] for g in legs})
    k.update({"body": body,
              "head": [(1, z, z), (3, r(2, 0, 8), z), (5, r(-4, 0, 24), z), (6, r(-6, 0, 28), z), (8, r(8, 0, -12), z), (10, r(4, 0, -6), z), (12, r(6, 0, -8), z), (16, r(1), z), (e, z, z)],
              "jaw": jw([(1, 0), (5, 10), (6, 14), (8, 30), (10, 22), (12, 26), (16, 6), (e, 0)]),
              "tail": [(1, z, z), (3, r(14, 0, 8), z), (5, r(40, 0, 20), z), (6, r(48, 0, 24), z), (8, r(-8, 0, -20), z), (10, r(9, 0, -16), z), (12, r(-4, 0, -17), z),
                       (16, r(0, 0, -6), z), (20, z, z), (e, z, z)],
              "tail2": [(1, z, z), (3, r(18, 0, 10), z), (5, r(46, 0, 22), z), (6, r(54, 0, 26), z), (8, r(-10, 0, -24), z), (10, r(12, 0, -18), z), (12, r(-4, 0, -20), z),
                        (16, r(0, 0, -8), z), (20, z, z), (e, z, z)],
              "gaze": sc([(1, 1), (6, 1.06), (8, 1.14), (12, 1.04), (e, 1)])})
    _eclip(arm, "slam", k, e)

    # ---- roar / shout (7): recolhe, crava as patas e ruge de boca escancarada, sacudindo a cabeça; o rabo chicoteia ----
    e = 24
    body = [(1, z, z), (4, r(3), p(-0.04, -0.06)), (7, r(-7), p(0.01, 0.04)), (9, r(-6, 2), p(0.01, 0.04)), (11, r(-7, -2), p(0.01, 0.04)),
            (13, r(-6, 2), p(0.01, 0.04)), (16, r(-4), p(0.0, 0.02)), (20, r(1), z), (e, z, z)]
    k = planted(body, {"leg_fr": [(4, 0, 2), (7, -6, 10, -8), (16, -6, 10, -8), (20, 0, 2)], "leg_fl": [(4, 0, 2), (7, -6, 10, -8), (16, -6, 10, -8), (20, 0, 2)]})
    k.update({"body": body,
              "head": [(1, z, z), (4, r(14), z), (7, r(-20, 0, 8), z), (9, r(-18, 0, -8), z), (11, r(-20, 0, 8), z), (13, r(-18, 0, -6), z), (16, r(-10), z), (20, r(3), z), (e, z, z)],
              "jaw": jw([(1, 0), (4, 0), (7, 46), (9, 40), (11, 46), (13, 40), (16, 30), (20, 6), (e, 0)]),
              "tail": [(1, z, z), (4, r(2, 0, -8), z), (7, r(16, 0, 18), z), (9, r(16, 0, -18), z), (11, r(16, 0, 18), z), (13, r(14, 0, -14), z), (17, r(4), z), (e, z, z)],
              "tail2": [(1, z, z), (4, r(2, 0, -12), z), (7, r(18, 0, -10), z), (9, r(18, 0, 22), z), (11, r(18, 0, -22), z), (13, r(14, 0, 18), z), (17, r(4), z), (e, z, z)],
              "gaze": sc([(1, 1), (4, 0.94), (7, 1.2), (9, 1.14), (11, 1.2), (13, 1.14), (16, 1.1), (20, 1.0), (e, 1)])})
    for name in ("roar", "shout"):
        _eclip(arm, name, {b_: list(v) for b_, v in k.items()}, e)

    # ---- maul (7): recolhe a cabeça para um lado e varre a frente com a mordida, o tronco acompanha ----
    e = 18
    body = [(1, z, z), (3, r(1, -7), p(-0.02, -0.06)), (5, r(2, -11), p(-0.02, -0.1)), (7, r(0, 12), p(0.0, 0.2)), (9, r(0, 14), p(0.0, 0.18)), (12, r(0, 5), p(0, 0.06)), (e, z, z)]
    k = planted(body, {"leg_fr": [(5, 6, 0, 8), (7, -10, 4, -12), (9, -8, 0, -9), (12, -2)], "leg_fl": [(5, -4, 0, -4), (7, 8, 0, 10), (9, 6, 0, 8)],
                       "leg_br": [(5, -3, 0, -4), (7, 8, 0, 9), (9, 6, 0, 7)], "leg_bl": [(5, -3, 0, -4), (7, 7, 0, 8), (9, 5, 0, 6)]})
    k.update({"body": body,
              "head": [(1, z, z), (3, r(-4, 0, 16), z), (5, r(-8, 10, 30), z), (7, r(4, -10, -30), z), (9, r(4, -6, -36), z), (12, r(0, 0, -10), z), (e, z, z)],
              "jaw": jw([(1, 0), (3, 20), (5, 38), (6, 40), (7, 2), (9, 4), (12, 6), (e, 0)]),
              "tail": [(1, z, z), (5, r(6, 0, 14), z), (7, r(10, 0, -18), z), (11, r(4, 0, 6), z), (e, z, z)],
              "tail2": [(1, z, z), (5, r(6, 0, 20), z), (7, r(10, 0, -10), z), (9, r(8, 0, -24), z), (13, r(2, 0, 8), z), (e, z, z)],
              "gaze": sc([(1, 1), (5, 1.08), (7, 1.0), (e, 1)])})
    _eclip(arm, "maul", k, e)

    # ---- pounce (9): agacha, dá um salto baixo para a frente e cai mordendo ----
    e = 20
    k = step({"leg_fr": [(5, 10, 0, 10), (7, -30, 14, -20), (8, -24, 10, -16), (9, -6, 0, -8), (11, -4, 0, -5), (13, -2), (e, 0)],
              "leg_fl": [(5, 10, 0, 10), (7, -26, 14, -18), (8, -20, 10, -14), (9, -6, 0, -8), (11, -4, 0, -5), (13, -2), (e, 0)],
              "leg_br": [(5, -12, 0, -12), (7, 30, 6, 20), (8, 24, 8, 14), (9, -6, 0, -6), (11, -4, 0, -4), (13, -2), (e, 0)],
              "leg_bl": [(5, -12, 0, -12), (7, 26, 6, 18), (8, 20, 8, 12), (9, -6, 0, -6), (11, -4, 0, -4), (13, -2), (e, 0)]})
    k.update({
        "body": [(1, z, z), (3, r(2), p(-0.05, -0.08)), (5, r(3), p(-0.08, -0.16)), (7, r(-7), p(0.3, 0.3)), (8, r(-1), p(0.28, 0.5)), (9, r(4), p(0.0, 0.58)),
                 (11, r(2), p(-0.04, 0.46)), (13, r(1), p(-0.02, 0.28)), (17, r(0), p(0, 0.05)), (e, z, z)],
        "head": [(1, z, z), (5, r(8), z), (7, r(-14), z), (9, r(12), z), (11, r(6), z), (14, r(2), z), (e, z, z)],
        "jaw": jw([(1, 0), (5, 6), (7, 36), (8, 40), (9, 2), (11, 6), (14, 2), (e, 0)]),
        "tail": [(1, z, z), (5, r(-2, 0, 8), z), (7, r(20, 0, -6), z), (9, r(4, 0, 6), z), (13, r(2, 0, -6), z), (e, z, z)],
        "tail2": [(1, z, z), (5, r(0, 0, 12), z), (7, r(22, 0, -10), z), (9, r(6, 0, 10), z), (13, r(2, 0, -8), z), (e, z, z)],
        "gaze": sc([(1, 1), (7, 1.1), (9, 1.0), (e, 1)]),
    })
    _eclip(arm, "pounce", k, e)

    # ---- brace (6): achata no chão de patas abertas, coroa para a frente e o rabo enrola pelo lado como um muro ----
    e = 18
    body = [(1, z, z), (3, r(-2), p(0.02)), (6, r(2), p(-0.13, 0.03)), (9, r(1.5), p(-0.11, 0.03)), (12, r(2), p(-0.13, 0.03)), (15, r(1), p(-0.03, 0.01)), (e, z, z)]
    spread = [(6, 0, 16), (12, 0, 16)]
    k = planted(body, {g: spread for g in legs})
    k.update({"body": body, "head": [(1, z, z), (3, r(-6), z), (6, r(14, 0, -6), z), (9, r(12, 0, -6), z), (12, r(14, 0, -6), z), (15, r(4), z), (e, z, z)],
              "jaw": jw([(1, 0), (6, 0), (e, 0)]),
              "tail": [(1, z, z), (6, r(0, 0, 34), z), (9, r(0, 0, 31), z), (12, r(0, 0, 34), z), (15, r(0, 0, 10), z), (e, z, z)],
              "tail2": [(1, z, z), (6, r(0, 0, 48), z), (9, r(0, 0, 44), z), (12, r(0, 0, 48), z), (15, r(0, 0, 16), z), (e, z, z)],
              "gaze": sc([(1, 1), (6, 0.9), (12, 0.9), (e, 1)])})
    _eclip(arm, "brace", k, e)

    # ---- cast_ground (10): abaixa, empina a frente com a cabeça para trás e despeja o olhar petrificante: boca escancarada, olhos e papo incham ----
    e = 24
    body = [(1, z, z), (4, r(3), p(-0.05, -0.06)), (8, r(-22), p(0.0, -0.03)), (10, r(-25), p(0.02, 0.05)), (12, r(-24), p(0.02, 0.05)), (14, r(-25), p(0.02, 0.05)),
            (18, r(-8), p(0, 0.02)), (21, r(1), z), (e, z, z)]
    k = planted(body, {"leg_fr": [(8, -16, 12, -6), (10, -26, 20, -10), (14, -24, 20, -10), (18, -8, 6)], "leg_fl": [(8, -14, 12, -6), (10, -22, 20, -10), (14, -24, 20, -10), (18, -8, 6)]})
    k.update({"body": body,
              "head": [(1, z, z), (4, r(12), z), (8, r(-30), z), (10, r(12), z), (12, r(2, 0, 4), z), (14, r(6, 0, -4), z), (18, r(6), z), (21, r(2), z), (e, z, z)],
              "jaw": jw([(1, 0), (4, 0), (8, 12), (10, 44), (12, 38), (14, 44), (18, 14), (e, 0)]),
              "tail": [(1, z, z), (4, r(4, 0, -8), z), (8, r(0, 0, 10), z), (10, r(0, 0, -12), z), (14, r(0, 0, 10), z), (18, r(0, 0, -4), z), (e, z, z)],
              "tail2": [(1, z, z), (4, r(4, 0, -12), z), (8, r(0, 0, 16), z), (10, r(0, 0, 10), z), (14, r(0, 0, -16), z), (18, r(0, 0, 6), z), (e, z, z)],
              "gaze": sc([(1, 1), (4, 0.9), (8, 1.1), (10, 1.36), (12, 1.24), (14, 1.34), (18, 1.1), (e, 1)])})
    _eclip(arm, "cast_ground", k, e)

    # ---- die: empina com o golpe e grita, desaba de barriga com as patas abertas e a cabeça caída de lado; olhos e papo apagam ----
    s = 1.4
    f = lambda x: int(round(1 + (x - 1) * s))
    e = f(24)
    roll = -10
    k = step({"leg_fr": [(f(4), -18, 12, -8), (f(9), 6, 20, 10), (f(14), 10, 30, 26), (e, 10, 30, 26)],
              "leg_fl": [(f(4), -14, 12, -6), (f(9), 4, 22, -6), (f(14), -6, 34, -22), (e, -6, 34, -22)],
              "leg_br": [(f(4), 4, 4), (f(9), 6, 20, 12), (f(14), 12, 30, 30), (e, 12, 30, 30)],
              "leg_bl": [(f(4), 4, 4), (f(9), 4, 22, 8), (f(14), 8, 34, 22), (e, 8, 34, 22)]})
    k.update({
        "body": [(1, z, z), (f(4), r(-13), p(0.02, -0.08)), (f(9), r(3), p(-0.14, 0.03)), (f(14), r(1, -4), p(-0.26)), (f(17), r(0, -4), p(-0.22)), (f(20), r(1, -4), p(-0.26)), (e, r(1, -4), p(-0.26))],
        "head": [(1, z, z), (f(4), r(-26, 0, 10), z), (f(9), r(10), z), (f(14), r(14, 24, 26), z), (f(17), r(8, 24, 26), z), (f(20), r(14, 24, 26), z), (e, r(14, 24, 26), z)],
        "jaw": jw([(1, 0), (f(4), 40), (f(9), 12), (f(14), 24), (f(17), 30), (e, 20)]),
        "tail": [(1, z, z), (f(4), r(20, 0, -10), z), (f(9), r(0, 0, 8), z), (f(14), r(0, 0, 20), z), (e, r(0, 0, 20), z)],
        "tail2": [(1, z, z), (f(4), r(24, 0, -16), z), (f(9), r(4, 0, -10), z), (f(14), r(0, 0, 28), z), (f(18), r(0, 0, 36), z), (e, r(0, 0, 36), z)],
        "root": [(1, z, z), (f(9), z, z), (f(14), r(0, 0, roll), z), (f(17), r(0, 0, roll + 3), z), (f(20), r(0, 0, roll), z), (e, r(0, 0, roll), z)],
        "gaze": sc([(1, 1), (f(4), 1.25), (f(9), 0.95), (f(14), 0.7), (e, 0.5)]),
    })
    _eclip(arm, "die", k, e)


def _outward(objs):
    for o in objs:
        b = bmesh.new()
        b.from_mesh(o.data)
        bmesh.ops.recalc_face_normals(b, faces=b.faces[:])
        b.to_mesh(o.data)
        b.free()


# ---------------------------------------------------------------------------
# clipes
# ---------------------------------------------------------------------------
def _clip(arm, name, keys, end, loop=False):
    """lp.add_action com TODOS os ossos gravados (osso sem chave herdava a pose do último clipe criado)."""
    z = (0, 0, 0)
    for b_ in arm.data.bones.keys():
        if b_ not in keys:
            keys[b_] = [(1, z, z), (end, z, z)]
    lp.add_action(arm, name, keys, end, loop=loop)


def _boar_clips(arm, K):
    """Eixos do rig: corpo X+ = focinho desce (X- empina), Y = gira, Z = rola, loc (0, cima, frente); pernas X- = casco para a
    frente, Z = abre; cabeça X+ = desce, Z = vira; rabo X+ = sobe. O corpo gira em volta da anca (empinar não tira as patas
    de trás do chão)."""
    z = (0, 0, 0)
    r = lambda x=0.0, y=0.0, zz=0.0: (x, y, zz)
    p = lambda up=0.0, fwd=0.0: (0, up * K, fwd * K)
    tau = math.tau
    legs = ("leg_fr", "leg_fl", "leg_br", "leg_bl")

    def planted(body, extra=None):
        """as quatro patas desfazem a inclinação do corpo; extra = {osso: [(quadro, x, abre)]}"""
        return {g: bg.plant(body, g, (extra or {}).get(g, ())) for g in legs}

    # ---- idle: respira fundo, olha devagar para os lados, abana o rabo ----
    n = 48
    k = {b_: [] for b_ in ("body", "head", "tail", "leg_fr", "leg_fl")}
    for f in list(range(1, n, 3)) + [n]:
        a = (f - 1) / (n - 1) * tau
        k["body"].append((f, r(1.4 * math.sin(a)), p(0.022 * (0.5 - 0.5 * math.cos(a)))))
        k["head"].append((f, r(3 + 3 * math.sin(a + 0.6), 0, 7 * math.sin(a)), z))
        k["tail"].append((f, r(4, 0, 12 * math.sin(2 * a)), z))
        k["leg_fr"].append((f, r(-1.4 * math.sin(a)), z))
        k["leg_fl"].append((f, r(-1.4 * math.sin(a)), z))
    _clip(arm, "idle", k, n, loop=True)

    # ---- run: galope pesado (pares da frente e de trás opostos), corpo rola e a cabeça compensa ----
    n = 16
    k = {b_: [] for b_ in ("body", "head", "tail") + legs}
    for f in range(1, n + 1):
        a = (f - 1) / (n - 1) * tau
        k["body"].append((f, r(-4.5 * math.cos(a), 0, 3.5 * math.sin(a)), p(0.07 * (0.5 + 0.5 * math.sin(a)))))
        k["head"].append((f, r(3.5 * math.cos(a) + 6, 0, -2 * math.sin(a)), z))
        k["leg_fr"].append((f, r(-32 * math.sin(a) + 4.5 * math.cos(a)), z))
        k["leg_fl"].append((f, r(-32 * math.sin(a - 0.5) + 4.5 * math.cos(a)), z))
        k["leg_br"].append((f, r(28 * math.sin(a + 0.25) + 4.5 * math.cos(a)), z))
        k["leg_bl"].append((f, r(28 * math.sin(a - 0.25) + 4.5 * math.cos(a)), z))
        k["tail"].append((f, r(14 + 10 * math.sin(a - 1.2), 0, 6 * math.sin(a + 0.6)), z))
    _clip(arm, "run", k, n, loop=True)

    # ---- attack (5): abaixa a cabeça e joga a presa grande para cima e para o lado ----
    e = 16
    _clip(arm, "attack", {
        "body": [(1, z, z), (3, r(6), p(-0.03, -0.1)), (5, r(-8), p(0.03, 0.24)), (8, r(-5), p(0.02, 0.18)), (11, r(2), p(0, 0.06)), (e, z, z)],
        "head": [(1, z, z), (3, r(16, 0, 12), z), (5, r(-30, 0, -16), z), (8, r(-18, 0, -8), z), (11, r(-4, 0, 4), z), (e, z, z)],
        "leg_fr": [(1, z, z), (3, r(8), z), (5, r(-20), z), (8, r(-12), z), (12, r(-4), z), (e, z, z)],
        "leg_fl": [(1, z, z), (3, r(6), z), (5, r(-14), z), (8, r(-9), z), (12, r(-2), z), (e, z, z)],
        "leg_br": [(1, z, z), (3, r(-16), z), (5, r(30), z), (8, r(20), z), (12, r(4), z), (e, z, z)],
        "leg_bl": [(1, z, z), (3, r(-16), z), (5, r(26), z), (8, r(16), z), (12, r(2), z), (e, z, z)],
        "tail": [(1, z, z), (3, r(12), z), (5, r(-14), z), (9, r(8, 0, 12), z), (e, z, z)],
    }, e)

    # ---- hit: tranco para trás, cabeça vira, rabo encolhe ----
    body = [(1, z, z), (2, r(-6, 0, 5), p(0.01, -0.08)), (5, r(3, 0, -2), p(0, -0.04)), (7, r(-1), p(0, -0.015)), (10, z, z)]
    k = planted(body, {"leg_fr": [(2, -10), (5, 4)], "leg_fl": [(2, -7), (5, 3)], "leg_br": [(2, 8), (5, -3)], "leg_bl": [(2, 6), (5, -3)]})
    k.update({"body": body, "head": [(1, z, z), (2, r(-20, 0, 16), z), (5, r(8, 0, -8), z), (7, r(-2), z), (10, z, z)],
              "tail": [(1, z, z), (2, r(-24), z), (5, r(-12, 0, 8), z), (10, z, z)]})
    _clip(arm, "hit", k, 10)

    # ---- atk_charge (5): cava, recua de cabeça baixa e dispara rente ao chão com as presas na frente; no fim joga a cabeça ----
    e = 20
    _clip(arm, "atk_charge", {
        "body": [(1, z, z), (3, r(9), p(-0.03, -0.18)), (5, r(7), p(0.0, 0.44)), (8, r(5), p(0.02, 0.48)), (10, r(-10), p(0.04, 0.38)), (13, r(-3), p(0.01, 0.17)),
                 (17, r(1), p(0, 0.03)), (e, z, z)],
        "head": [(1, z, z), (3, r(20), z), (5, r(16), z), (8, r(14), z), (10, r(-30, 0, -14), z), (13, r(-10, 0, 6), z), (17, r(2), z), (e, z, z)],
        "leg_fr": [(1, z, z), (3, r(14), z), (5, r(-50), z), (8, r(-38), z), (10, r(4), z), (13, r(6), z), (e, z, z)],
        "leg_fl": [(1, z, z), (3, r(10), z), (5, r(-42), z), (8, r(-30), z), (10, r(8), z), (13, r(4), z), (e, z, z)],
        "leg_br": [(1, z, z), (3, r(-26), z), (5, r(42), z), (8, r(32), z), (10, r(14), z), (13, r(-2), z), (e, z, z)],
        "leg_bl": [(1, z, z), (3, r(-26), z), (5, r(36), z), (8, r(26), z), (10, r(12), z), (13, r(0), z), (e, z, z)],
        "tail": [(1, z, z), (3, r(22), z), (5, r(-22), z), (8, r(-18, 0, 8), z), (10, r(16, 0, -10), z), (14, r(6), z), (e, z, z)],
    }, e)

    # ---- slam (8): empina nas patas de trás e desaba com os dois cascos da frente; o corpo afunda, quica e assenta ----
    e = 24
    _clip(arm, "slam", {
        "body": [(1, z, z), (3, r(6), p(-0.03)), (5, r(-36), p(0.03, -0.04)), (6, r(-40), p(0.04, -0.05)), (8, r(9), p(-0.02, 0.1)), (10, r(5), p(0.0, 0.08)),
                 (12, r(8), p(-0.02, 0.07)), (15, r(2), p(0, 0.03)), (20, r(-1), z), (e, z, z)],
        "head": [(1, z, z), (3, r(10), z), (5, r(-8), z), (6, r(-4), z), (8, r(20), z), (10, r(12, 0, 5), z), (12, r(12, 0, -5), z), (16, r(3), z), (e, z, z)],
        "leg_fr": [(1, z, z), (3, r(8), z), (5, r(-48), z), (6, r(-56), z), (7, r(-30), z), (8, r(-9), z), (10, r(-5), z), (12, r(-8), z), (15, r(-2), z), (e, z, z)],
        "leg_fl": [(1, z, z), (3, r(8), z), (5, r(-40), z), (6, r(-50), z), (7, r(-26), z), (8, r(-9), z), (10, r(-5), z), (12, r(-8), z), (15, r(-2), z), (e, z, z)],
        "leg_br": [(1, z, z), (3, r(-6), z), (5, r(36), z), (6, r(40), z), (8, r(-9), z), (10, r(-5), z), (12, r(-8), z), (15, r(-2), z), (e, z, z)],
        "leg_bl": [(1, z, z), (3, r(-6), z), (5, r(36), z), (6, r(40), z), (8, r(-9), z), (10, r(-5), z), (12, r(-8), z), (15, r(-2), z), (e, z, z)],
        "tail": [(1, z, z), (4, r(50), z), (5, r(80), z), (6, r(84), z), (8, r(-10), z), (12, r(8, 0, 10), z), (16, r(2, 0, -6), z), (e, z, z)],
    }, e)

    # ---- roar / shout (7): recolhe, crava as patas abertas, joga a cabeça para cima e sacode ----
    e = 24
    body = [(1, z, z), (4, r(7), p(-0.03, -0.04)), (7, r(-11), p(0.02, 0.02)), (9, r(-10, 0, 3), p(0.02, 0.02)), (11, r(-11, 0, -3), p(0.02, 0.02)),
            (13, r(-10, 0, 2), p(0.02, 0.02)), (16, r(-8), p(0.01, 0.01)), (20, r(2), z), (e, z, z)]
    k = planted(body, {"leg_fr": [(4, 0, 4), (7, 0, 12), (16, 0, 12), (20, 0, 3)], "leg_fl": [(4, 0, 4), (7, 0, 12), (16, 0, 12), (20, 0, 3)]})
    k.update({"body": body,
              "head": [(1, z, z), (4, r(20), z), (7, r(-36, 0, 10), z), (9, r(-34, 0, -10), z), (11, r(-36, 0, 10), z), (13, r(-34, 0, -8), z), (16, r(-24), z),
                       (20, r(4), z), (e, z, z)],
              "tail": [(1, z, z), (4, r(-6), z), (7, r(34, 0, 14), z), (9, r(34, 0, -14), z), (11, r(34, 0, 14), z), (13, r(30, 0, -10), z), (17, r(12), z), (e, z, z)]})
    for name in ("roar", "shout"):
        _clip(arm, name, {b_: list(v) for b_, v in k.items()}, e)

    # ---- maul (7): gira o tronco, recolhe a cabeça para um lado e varre com a presa grande cruzando a frente ----
    e = 18
    body = [(1, z, z), (3, r(4, -12), p(-0.02, -0.05)), (5, r(6, -20), p(-0.02, -0.08)), (7, r(-5, 18), p(0.02, 0.16)), (9, r(-4, 22), p(0.02, 0.14)),
            (12, r(0, 8), p(0, 0.05)), (e, z, z)]
    k = planted(body, {"leg_fr": [(5, 10), (7, -14), (9, -10), (12, -3)], "leg_fl": [(5, -6), (7, -8), (9, -6)], "leg_br": [(5, -8), (7, 12), (9, 8)],
                       "leg_bl": [(5, -8), (7, 10), (9, 6)]})
    k.update({"body": body,
              "head": [(1, z, z), (3, r(10, 0, -16), z), (5, r(16, 0, -28), z), (7, r(-18, 0, 30), z), (9, r(-12, 0, 34), z), (12, r(-2, 0, 10), z), (e, z, z)],
              "tail": [(1, z, z), (5, r(10, 0, -18), z), (7, r(-8, 0, 22), z), (11, r(6, 0, -8), z), (e, z, z)]})
    _clip(arm, "maul", k, e)

    # ---- pounce (9): agacha, salta para a frente e cai nos cascos da frente ----
    e = 20
    _clip(arm, "pounce", {
        "body": [(1, z, z), (3, r(5), p(-0.04, -0.06)), (5, r(8), p(-0.07, -0.12)), (7, r(-16), p(0.32, 0.26)), (8, r(-4), p(0.3, 0.4)), (9, r(10), p(0.0, 0.46)),
                 (11, r(7), p(-0.03, 0.38)), (13, r(4), p(-0.02, 0.24)), (17, r(-1), p(0, 0.05)), (e, z, z)],
        "head": [(1, z, z), (5, r(12), z), (7, r(-14), z), (9, r(20), z), (11, r(12), z), (14, r(4), z), (e, z, z)],
        "leg_fr": [(1, z, z), (5, r(18), z), (7, r(-58), z), (8, r(-40), z), (9, r(-10), z), (11, r(-7), z), (13, r(-4), z), (e, z, z)],
        "leg_fl": [(1, z, z), (5, r(18), z), (7, r(-50), z), (8, r(-34), z), (9, r(-10), z), (11, r(-7), z), (13, r(-4), z), (e, z, z)],
        "leg_br": [(1, z, z), (5, r(-30), z), (7, r(50), z), (8, r(40), z), (9, r(-10), z), (11, r(-7), z), (13, r(-4), z), (e, z, z)],
        "leg_bl": [(1, z, z), (5, r(-30), z), (7, r(44), z), (8, r(36), z), (9, r(-10), z), (11, r(-7), z), (13, r(-4), z), (e, z, z)],
        "tail": [(1, z, z), (5, r(-12), z), (7, r(26), z), (9, r(-16), z), (13, r(6, 0, 8), z), (e, z, z)],
    }, e)

    # ---- brace (6): crava as patas abertas, abaixa o corpo e a cabeça entre os ombros, respira pesado ----
    e = 18
    body = [(1, z, z), (3, r(-3), p(0.02)), (6, r(6), p(-0.1, 0.04)), (9, r(5), p(-0.085, 0.04)), (12, r(6), p(-0.1, 0.04)), (15, r(2), p(-0.02, 0.01)), (e, z, z)]
    spread = [(6, 0, 12), (12, 0, 12)]
    k = planted(body, {g: spread for g in legs})
    k.update({"body": body, "head": [(1, z, z), (3, r(-8), z), (6, r(18), z), (9, r(15), z), (12, r(18), z), (15, r(4), z), (e, z, z)],
              "tail": [(1, z, z), (6, r(-18), z), (12, r(-16), z), (e, z, z)]})
    _clip(arm, "brace", k, e)

    # ---- die: empina com o golpe, os joelhos da frente cedem, tomba de lado (a presa grande e o musgo ficam para cima) e quica ----
    s = 1.4
    f = lambda x: int(round(1 + (x - 1) * s))
    e = f(24)
    roll = -84
    _clip(arm, "die", {
        "body": [(1, z, z), (f(4), r(-10), p(0.02, -0.05)), (f(9), r(9), p(-0.06, 0.02)), (f(14), r(3), p(-0.02)), (e, r(3), p(-0.02))],
        "head": [(1, z, z), (f(4), r(-30, 0, 8), z), (f(9), r(20), z), (f(14), r(6, 0, 14), z), (f(17), r(-4, 0, 8), z), (f(20), r(6, 0, 14), z), (e, r(6, 0, 14), z)],
        "leg_fr": [(1, z, z), (f(4), r(-16), z), (f(9), r(30), z), (f(14), r(-20), z), (f(17), r(-28), z), (e, r(-20), z)],
        "leg_fl": [(1, z, z), (f(4), r(-12), z), (f(9), r(26), z), (f(14), r(-10), z), (f(17), r(-16), z), (e, r(-10), z)],
        "leg_br": [(1, z, z), (f(4), r(8), z), (f(9), r(-16), z), (f(14), r(16), z), (f(17), r(24), z), (e, r(16), z)],
        "leg_bl": [(1, z, z), (f(4), r(8), z), (f(9), r(-16), z), (f(14), r(26), z), (f(17), r(32), z), (e, r(26), z)],
        "tail": [(1, z, z), (f(4), r(-22), z), (f(9), r(-28), z), (f(14), r(6, 0, 10), z), (f(17), r(10, 0, 18), z), (e, r(4, 0, 12), z)],
        "root": [(1, z, z), (f(9), z, z), (f(14), r(0, 0, roll), z), (f(17), r(0, 0, roll + 7), z), (f(20), r(0, 0, roll), z), (e, r(0, 0, roll), z)],
    }, e)


# ---------------------------------------------------------------------------
# chão
# ---------------------------------------------------------------------------
def _ground(arm, clips, legs, tuck, sink=0.0, head=True, report=True, heads=("head",), only=None):
    """Nada abaixo do chão, quadro a quadro, sem mexer em duração nem impacto. 1) cada pata de `legs` que passaria do chão
    recolhe na vertical para dentro do corpo (até `tuck`); 2) cabeça (presas, barbicha) que passaria do chão ergue o focinho de
    1,5° em 1,5°; 3) o que ainda sobrar abaixo de -sink sobe a raiz (loc Y = cima,
    vale mesmo com a raiz tombada no `die`). Grava uma chave por quadro nesses canais.
    heads = malhas que contam como cabeça no passo 2 (o alce soma os chifres); only = ossos medidos no passo 3 (None = todos)."""
    import numpy as np
    ad = arm.animation_data
    sc = bpy.context.scene
    meshes = {o.parent_bone: o for o in arm.children if o.type == "MESH"}
    co = {}
    for bone, o in meshes.items():
        a = np.empty(len(o.data.vertices) * 3, dtype=np.float64)
        o.data.vertices.foreach_get("co", a)
        co[bone] = np.concatenate([a.reshape(-1, 3), np.ones((len(o.data.vertices), 1))], axis=1)

    def low(bone):
        mw = np.array(meshes[bone].matrix_world)
        return float((co[bone] @ mw[2]).min())

    tracks = {t.name: t for t in ad.nla_tracks}
    for t in ad.nla_tracks:
        t.mute = True
    root = arm.pose.bones["root"]
    for name in clips:
        act = tracks[name].strips[0].action
        ad.action = act
        if getattr(ad, "action_slot", None) is None and getattr(act, "slots", None):
            ad.action_slot = act.slots[0]
        worst_leg, worst_root, worst_head = 0.0, 0.0, 0.0
        for f in range(1, int(round(act.frame_range[1])) + 1):
            sc.frame_set(f)
            bpy.context.view_layer.update()
            for g in legs:
                pb = arm.pose.bones[g]
                d = min(max(0.0, -low(g)), tuck)
                if d > 0.0:
                    par = pb.parent
                    mrot = arm.matrix_world.to_3x3() @ par.matrix.to_3x3() @ par.bone.matrix_local.to_3x3().inverted() @ pb.bone.matrix_local.to_3x3()
                    pb.location = pb.location + mrot.inverted() @ V((0, 0, d))
                    worst_leg = max(worst_leg, d)
                pb.keyframe_insert("location", frame=f)
            bpy.context.view_layer.update()
            if head:
                hb = arm.pose.bones["head"]
                for _i in range(40):
                    if min(low(h) for h in heads) >= 0.0:
                        break
                    hb.rotation_euler.x -= math.radians(1.5)
                    bpy.context.view_layer.update()
                    worst_head = max(worst_head, 1.5 * (_i + 1))
                hb.keyframe_insert("rotation_euler", frame=f)
            d = max(0.0, -min(low(b_) for b_ in meshes if only is None or b_ in only) - sink)
            root.location.y += d
            worst_root = max(worst_root, d)
            root.keyframe_insert("location", frame=f)
        if report:
            print("GROUNDFIX %-11s pata recolhe até %.3f, cabeça ergue até %.1f°, raiz sobe até %.3f" % (name, worst_leg, worst_head, worst_root))
        ad.action = None
    for t in ad.nla_tracks:
        t.mute = False
    for b_ in arm.pose.bones:
        b_.rotation_euler = (0, 0, 0)
        b_.location = (0, 0, 0)
        b_.scale = (1, 1, 1)
    sc.frame_set(1)


# ---------------------------------------------------------------------------
# Rinoceronte de Guerra da Horda
# ---------------------------------------------------------------------------
RHINO_SIZE = 0.58          # unidades de desenho -> nativo: ~2,2 de comprido, cernelha ~1,0, plataforma ~1,2, ponta do estandarte ~1,9
RHINO_TUCK = 0.3
RHINO_SPINE = [((0, 0.9, 1.12), 0.42), ((0, 0.48, 1.16), 0.54), ((0, 0.0, 1.14), 0.56), ((0, -0.48, 1.22), 0.6), ((0, -0.88, 1.08), 0.46)]
RHINO_WIDE = 1.16
RHINO_HEAD = (0, -1.3, 0.95)        # a cabeça (e a mandíbula) cresce RHINO_HEAD_K em volta daqui
RHINO_HEAD_K = 1.24
RHINO_HEAD_SHIFT = (0, 0.0, 0.1)
RHINO_CLIPS = ("idle", "run", "attack", "hit", "die", "atk_charge", "slam", "roar", "shout", "maul", "pounce", "brace", "cast_ground")
RHINO_IMPACT = {"attack": 5, "atk_charge": 5, "slam": 8, "roar": 7, "shout": 7, "maul": 7, "pounce": 9, "brace": 6, "cast_ground": 10}
RHINO_GLOW = 1.0           # olhos em brasa (degraus de 0,25: EntityView.mob_glow)
RHINO_DIE_ROLL = -84       # tomba para o lado das lanças: os tambores e o pano ficam para cima

R_HIDE = (0.63, 0.54, 0.47)          # couro cinza-pardo
R_HIDE_D = (0.43, 0.35, 0.32)
R_HIDE_L = (0.8, 0.73, 0.64)
R_HORN = (0.95, 0.9, 0.76)
R_HORN_D = (0.72, 0.62, 0.48)
R_IRON = (0.42, 0.42, 0.47)         # ferro da Horda (act2_bosses/kharzun_mobs usam 0,3; aqui um tom acima: a chapa é grande e lia preta)
R_IRON_D = (0.25, 0.25, 0.3)
R_STEEL = (0.8, 0.8, 0.84)
R_RED = (0.74, 0.2, 0.16)           # vermelho da Horda (zones/horde.HORDE_RED)
R_RED_D = (0.5, 0.12, 0.12)
R_PAINT = (0.86, 0.36, 0.2)         # tinta de guerra ocre-vermelha
R_WOOD = (0.46, 0.33, 0.22)
R_LEATHER = (0.32, 0.22, 0.17)
R_CANVAS = (0.88, 0.84, 0.72)       # pele dos tambores (zones/horde.CANVAS)
R_MOUTH = (0.7, 0.36, 0.38)
R_EMBER = (1.0, 0.5, 0.16)


def _caster(obj):
    """(bvh, cast): cast(origem, direção) -> (ponto, normal) na malha do objeto, ou (None, None)."""
    b = bmesh.new()
    b.from_mesh(obj.data)
    bvh = BVHTree.FromBMesh(b)
    b.free()

    def cast(o, d):
        hit = bvh.ray_cast(V(o), V(d).normalized())
        return (hit[0], hit[1]) if hit[0] is not None else (None, None)
    return cast


def _cloth(name, origin, ux, down, w, drop, material, hem=None, seed=1, nx=6, ny=4, thick=0.03, amp=None, torn=0.3):
    """Pano DOBRADO (nunca placa chata: regra do projeto, zones/horde.cloth_mesh): grade em onda, mais solta na barra, com
    espessura (casca fechada: o contorno pega). Pendurado de `origin` ao longo de `ux` (largura w) e caindo em `down` (drop).
    A barra é rasgada (cada coluna acaba numa altura sorteada, até `torn` do drop); `hem` = material da fileira de baixo."""
    rnd = random.Random(seed)
    origin, ux, down = V(origin), V(ux).normalized(), V(down).normalized()
    nrm = ux.cross(down).normalized()
    amp = min(w, drop) * 0.13 if amp is None else amp
    cut = [drop * rnd.uniform(0.0, torn) * (1.6 if j % 3 == 1 else 0.6) for j in range(nx + 1)]
    b = bmesh.new()
    vs = []
    for i in range(ny + 1):
        t = i / ny                                  # 0 = barra, 1 = presa na travessa
        for j in range(nx + 1):
            u = j / nx
            yb = amp * math.sin(u * math.pi * 1.7 + 0.6 + seed) * (0.25 + 0.75 * (1.0 - t)) + amp * 0.7 * (u - 0.4) * (1.0 - t) ** 2
            dn = (drop - cut[j]) * (1.0 - t)
            for s in (0.5, -0.5):
                vs.append(b.verts.new(origin + ux * (u * w) + down * dn + nrm * (yb + thick * s)))
    k = lambda i, j, s: vs[(i * (nx + 1) + j) * 2 + s]
    for i in range(ny):
        for j in range(nx):
            for f in (b.faces.new((k(i, j, 0), k(i, j + 1, 0), k(i + 1, j + 1, 0), k(i + 1, j, 0))),
                      b.faces.new((k(i, j, 1), k(i + 1, j, 1), k(i + 1, j + 1, 1), k(i, j + 1, 1)))):
                f.material_index = 1 if (hem is not None and i == 0) else 0
    for j in range(nx):
        b.faces.new((k(0, j, 0), k(0, j, 1), k(0, j + 1, 1), k(0, j + 1, 0)))
        b.faces.new((k(ny, j, 0), k(ny, j + 1, 0), k(ny, j + 1, 1), k(ny, j, 1)))
    for i in range(ny):
        b.faces.new((k(i, 0, 0), k(i + 1, 0, 0), k(i + 1, 0, 1), k(i, 0, 1)))
        b.faces.new((k(i, nx, 0), k(i, nx, 1), k(i + 1, nx, 1), k(i + 1, nx, 0)))
    bmesh.ops.recalc_face_normals(b, faces=b.faces[:])
    o = ck.mesh_from(name, b, material)
    if hem is not None:
        o.data.materials.append(hem)
    return o


def _stud(name, p, r, material, sq=(1.0, 1.0, 1.0), sub=1):
    """Rebite/elo/unha barato: icosfera (20 tris com sub=1, 80 com sub=2) no lugar da esfera de quads (108)."""
    b = bmesh.new()
    bmesh.ops.create_icosphere(b, subdivisions=sub, radius=r)
    p = V(p)
    for v in b.verts:
        v.co = V((v.co.x * sq[0], v.co.y * sq[1], v.co.z * sq[2])) + p
    return ck.mesh_from(name, b, material)


def _strap(name, pts, r0, r1, material, segs=5):
    """Faixa/dobra/tinta rente ao couro: tubos pelos pontos, cada um passando um pouco do seguinte (sem bola nas emendas)."""
    out = []
    n = len(pts) - 1
    for i in range(n):
        a, b_ = V(pts[i]), V(pts[i + 1])
        ext = (b_ - a) * (0.12 if i < n - 1 else 0.0)
        out.append(ck.tube("%s_%d" % (name, i), a, b_ + ext, r0 + (r1 - r0) * i / n, r0 + (r1 - r0) * (i + 1) / n, material, segs))
    return out


def _horn(name, pts, radii, material, segs=8):
    """Chifre/presa curva numa malha só: anéis ao longo dos pontos com os raios dados, tampas nas pontas (sem emenda aparente)."""
    pts = [V(q) for q in pts]
    n = len(pts) - 1
    b = bmesh.new()
    rings, u = [], None
    for i, q in enumerate(pts):
        t = (pts[min(i + 1, n)] - pts[max(i - 1, 0)]).normalized()
        if u is None:
            _d, u, w = _perp(t)
        else:
            u = (u - t * u.dot(t)).normalized()
            w = t.cross(u)
        rings.append([b.verts.new(q + (u * math.cos(math.tau * j / segs) + w * math.sin(math.tau * j / segs)) * radii[i]) for j in range(segs)])
    for i in range(n):
        for j in range(segs):
            b.faces.new((rings[i][j], rings[i][(j + 1) % segs], rings[i + 1][(j + 1) % segs], rings[i + 1][j]))
    b.faces.new(list(reversed(rings[0])))
    b.faces.new(rings[n])
    bmesh.ops.recalc_face_normals(b, faces=b.faces[:])
    return ck.mesh_from(name, b, material)


def _ring(name, c, axis, r, th, material, n=10, segs=5, arc=(0.0, 360.0)):
    """Aro (ou arco) de tubos em volta de `axis`, centro c, raio r, grossura th."""
    d, u, w = _perp(axis)
    c = V(c)
    out, prev = [], None
    for i in range(n + 1):
        a = math.radians(arc[0] + (arc[1] - arc[0]) * i / n)
        q = c + u * (math.cos(a) * r) + w * (math.sin(a) * r)
        if prev is not None:
            out.append(ck.tube("%s_%d" % (name, i), prev, q, th, th, material, segs))
        prev = q
    return out


def _war_drum(name, c, axis, r, ln, wood, skin, band, lace):
    """Tambor de guerra: casco de madeira, duas peles claras, aros de ferro e amarração em zigue-zague."""
    d, u, w = _perp(axis)
    c = V(c)
    a, b_ = c - d * (ln * 0.5), c + d * (ln * 0.5)
    out = [ck.tube(name, a, b_, r * 0.94, r * 0.94, wood, 10),
           ck.tube(name + "_belly", c - d * (ln * 0.2), c + d * (ln * 0.2), r * 1.04, r * 1.04, wood, 10)]
    for i, e in enumerate((a, b_)):
        s = -1 if i == 0 else 1
        out.append(ck.tube("%s_skin%d" % (name, i), e, e + d * (s * 0.035), r * 1.0, r * 0.9, skin, 10))
        out.append(ck.tube("%s_rim%d" % (name, i), e - d * (s * 0.05), e + d * (s * 0.012), r * 1.1, r * 1.1, band, 10))
    for i in range(6):                                      # amarração: seis cordas em zigue-zague
        a0, a1 = math.tau * i / 6, math.tau * (i + 0.5) / 6
        p0 = a + (u * math.cos(a0) + w * math.sin(a0)) * (r * 1.09)
        p1 = b_ + (u * math.cos(a1) + w * math.sin(a1)) * (r * 1.09)
        out.append(ck.tube("%s_lace%d" % (name, i), p0, p1, 0.016, 0.016, lace, 3))
    return out


def war_rhino(cid="mob_war_rhino"):
    K = RHINO_SIZE
    S = lambda p: tuple(x * K for x in p)
    hc = V(RHINO_HEAD)
    hs = lambda p: hc + (V(p) - hc) * RHINO_HEAD_K + V(RHINO_HEAD_SHIFT)          # a cabeça é desenhada e depois cresce em volta de hc
    bones = mk.pivots(body=S((0, 0.6, 1.0)), head=S((0, -0.86, 1.08)),
                      leg_fr=S((0.44, -0.5, 1.0)), leg_fl=S((-0.44, -0.5, 1.0)),
                      leg_br=S((0.42, 0.58, 1.0)), leg_bl=S((-0.42, 0.58, 1.0)))
    th, jw = S((0, 1.2, 1.26)), S(hs((0, -1.22, 0.82)))
    BANNER = V((0.0, 0.74, 1.72))                            # pé do mastro (corrigido para o piso da plataforma mais abaixo)
    bn = S(BANNER)
    arm = lp.make_armature("rig_" + cid, dict(bones, tail=(th, (th[0], th[1] + 0.3, th[2] + 0.04), "body"),
                                              jaw=(jw, (jw[0], jw[1] - 0.3, jw[2]), "head"),
                                              banner=(bn, (bn[0], bn[1], bn[2] + 0.3), "body")))
    m = lambda n, col, rough=0.85, em=0.0: ck.mat("m_%s_%s" % (cid, n), col, rough, em)
    hide, dark, light = m("hide", R_HIDE), m("dark", R_HIDE_D), m("light", R_HIDE_L)
    horn, horn2 = m("horn", R_HORN, 0.5), m("horn2", R_HORN_D, 0.6)
    iron, iron2, steel = m("iron", R_IRON, 0.45), m("iron2", R_IRON_D, 0.45), m("steel", R_STEEL, 0.4)
    red, red2, paint = m("red", R_RED, 0.9), m("red2", R_RED_D, 0.9), m("paint", R_PAINT, 0.8)
    wood, leather, canvas = m("wood", R_WOOD, 0.9), m("leather", R_LEATHER, 0.85), m("canvas", R_CANVAS, 0.8)
    socket, mouth = m("socket", (0.13, 0.09, 0.09), 0.5), m("mouth", R_MOUTH, 0.7)
    glow = ck.mat("glow_%s_eye" % cid, R_EMBER, 0.3, RHINO_GLOW)
    parts, flat = [], set()

    def add(o, bone, faceted=False):
        for x in (o if isinstance(o, (list, tuple)) else [o]):
            parts.append((x, bone))
            if faceted:
                flat.add(x.name)

    # ---------------- tronco ----------------
    body = mk.skin_body("body", RHINO_SPINE, [(i, i + 1) for i in range(len(RHINO_SPINE) - 1)], hide)
    for v in body.data.vertices:
        v.co.x *= RHINO_WIDE
    add(body, "body")
    cast = _caster(body)

    def top(x, y, lift=0.0):
        p, n = cast((x, y, 5), (0, 0, -1))
        if p is None:
            p, n = V((x, y, 1.6)), V((0, 0, 1))
        return p + n * lift, n

    def flank(sx, y, z, lift=0.0):
        p, n = cast((sx * 3, y, z), (-sx, 0, 0))
        if p is None:
            p, n = V((sx * 0.5, y, z)), V((sx, 0, 0))
        return p + n * lift, n

    def surf(y, deg, lift=0.0, zc=1.14):
        """ponto do couro na fatia y, a `deg` graus do alto (0 = lombo, 90 = flanco +X, 180 = barriga)"""
        a = math.radians(deg)
        d = V((math.sin(a), 0, math.cos(a)))
        p, n = cast((0, y, zc), d)
        if p is None:
            p, n = V((0, y, zc)) + d * 0.5, d
        return p + n * lift, n

    add(mk.blob("belly", 0.44, (0, 0.05, 0.84), light, (1.05, 2.0, 0.6)), "body")
    add(mk.blob("chest", 0.36, (0, -0.86, 0.86), light, (1.1, 0.8, 0.9), 2), "body")
    # dobras do couro (o rinoceronte tem a pele em "placas"): atrás do ombro e antes da anca, do meio do flanco para baixo
    for i, y in enumerate((-0.16, 0.72)):
        for sx in (-1, 1):
            pts = [surf(y + 0.03 * math.sin(d * 0.05), sx * d, -0.012)[0] for d in (62, 84, 106, 128, 150)]
            add(_strap("fold%d_%d" % (i, sx), pts, 0.05, 0.04, dark, 5), "body")

    # ---------------- chapas de ferro rebitadas nos ombros (duas camadas) + crista de cravos ----------------
    def plate_pick(c, n):
        edge = -0.2 + 0.12 * math.sin(c.y * 13.0)
        return n.z > edge and -0.74 < c.y < -0.2

    def pauldron_pick(c, n):
        return -0.62 < c.y < -0.3 and abs(c.x) > 0.3 and n.z > 0.02

    add(_shell("plate", body, plate_pick, 0.045, iron), "body")
    add(_shell("pauldron", body, pauldron_pick, 0.1, iron2, 0.01), "body")
    for sx in (-1, 1):
        for i, (y, d) in enumerate(((-0.68, 30), (-0.68, 62), (-0.68, 92), (-0.26, 30), (-0.26, 62), (-0.26, 92), (-0.47, 98))):   # rebites
            p, n = surf(y, sx * d, 0.05)
            add(_stud("rivet%d_%d" % (sx, i), p, 0.045, steel), "body", True)
        for i, (y, d, ln) in enumerate(((-0.56, 52, 0.26), (-0.38, 64, 0.32))):                                    # cravos da ombreira
            p, n = surf(y, sx * d, 0.09)
            add(mk.cone("spike%d_%d" % (sx, i), p, p + (n + V((0, 0, 0.25))).normalized() * (ln * (1.2 if sx > 0 else 1.0)), 0.075, steel, 6), "body", True)
    for i, y in enumerate((-0.6, -0.36)):                                                                                     # crista
        p, n = top(0, y, 0.03)
        add(mk.cone("crest%d" % i, p, p + V((0, 0.06, (0.2, 0.26)[i])), 0.07, steel, 6), "body", True)

    # ---------------- coleira de ferro com cravos ----------------
    cy = -0.84
    ring = [surf(cy, d, 0.05)[0] for d in range(0, 361, 30)]
    for i in range(len(ring) - 1):
        add(ck.tube("collar%d" % i, ring[i], ring[i + 1], 0.085, 0.085, iron2, 6), "body")
    for i, d in enumerate((-112, -56, 0, 56, 112)):
        p, n = surf(cy, d, 0.1)
        add(mk.cone("collarspike%d" % i, p, p + (n + V((0, -0.3, 0))).normalized() * 0.3, 0.07, steel, 6), "body", True)

    # ---------------- manta, cilhas e plataforma de guerra ----------------
    def blanket_pick(c, n):
        return n.z > 0.1 + 0.07 * math.sin(c.y * 17.0) and -0.14 < c.y < 0.84

    add(_shell("blanket", body, blanket_pick, 0.035, red), "body")
    for sx in (-1, 1):                                       # barra em dentes, um tom abaixo
        for i in range(5):
            y = -0.04 + i * 0.2
            p, n = surf(y, sx * 86, 0.02)
            add(ck.blade("hem%d_%d" % (sx, i), p + V((0, 0, 0.1)), p + V((sx * 0.03, 0, -0.2)), 0.2, 0.03, red2, (0, 1, 0), 0.3), "body")
    for i, y in enumerate((-0.02, 0.62)):                    # cilhas de couro por baixo da barriga
        pts = [surf(y, d, 0.02)[0] for d in range(80, 281, 25)]
        for j in range(len(pts) - 1):
            add(ck.tube("girth%d_%d" % (i, j), pts[j], pts[j + 1], 0.055, 0.055, leather, 5), "body")
        for sx in (-1, 1):
            p, n = surf(y, sx * 80, 0.03)
            add(_stud("buckle%d_%d" % (i, sx), p, 0.065, steel, (0.6, 1.0, 1.0)), "body", True)
    zt = max(top(x, y)[0].z for x in (-0.3, 0, 0.3) for y in (0.0, 0.3, 0.6)) + 0.07       # piso da plataforma
    HW, Y0, Y1 = 0.56, -0.1, 0.8
    for i, y in enumerate((Y0 + 0.08, Y1 - 0.08)):           # travessas
        add(ck.tube("beam%d" % i, (-HW - 0.06, y, zt - 0.02), (HW + 0.06, y, zt - 0.02), 0.055, 0.055, wood, 6), "body")
    for i in range(4):                                       # tábuas (cada uma um pouco torta)
        x = -HW + (i + 0.5) * (2 * HW / 4)
        o = ck.box("plank%d" % i, (2 * HW / 4 - 0.03, Y1 - Y0 + (0.06 if i % 2 else 0.0), 0.06), (x, (Y0 + Y1) * 0.5 + (0.02 if i % 2 else -0.02), zt + 0.05 + 0.008 * (i % 2)), wood)
        add(o, "body", True)
    rail = zt + 0.42
    posts = [(-HW, Y0), (HW, Y0), (-HW, Y1), (HW, Y1)]
    for i, (x, y) in enumerate(posts):
        add(ck.tube("post%d" % i, (x, y, zt), (x, y, rail + 0.08), 0.05, 0.045, wood, 6), "body")
        add(mk.cone("postspike%d" % i, (x, y, rail + 0.06), (x * 1.12, y + (0.06 if y > 0.3 else -0.06), rail + 0.3), 0.05, horn, 5), "body", True)
        add(ck.tube("postband%d" % i, (x, y, rail - 0.04), (x, y, rail + 0.03), 0.065, 0.065, iron2, 6), "body")
    for i, (a, b_) in enumerate(((0, 2), (1, 3), (2, 3))):   # guarda dos lados e de trás (a frente fica aberta)
        add(ck.tube("rail%d" % i, (posts[a][0], posts[a][1], rail), (posts[b_][0], posts[b_][1], rail), 0.04, 0.04, wood, 6), "body")
    for sx in (-1, 1):                                       # pranchas de proteção dos lados, com chapa e rebites
        o = ck.box("side%d" % sx, (0.05, (Y1 - Y0) * 0.86, 0.26), (sx * HW, (Y0 + Y1) * 0.5, zt + 0.22), wood)
        add(o, "body", True)
        add(ck.box("sideplate%d" % sx, (0.03, 0.34, 0.2), (sx * (HW + 0.035), (Y0 + Y1) * 0.5 + sx * 0.12, zt + 0.22), iron), "body", True)
        for j, (dy, dz) in enumerate(((-0.13, 0.06), (0.13, 0.06), (-0.13, -0.06), (0.13, -0.06))):
            add(_stud("siderivet%d_%d" % (sx, j), (sx * (HW + 0.055), (Y0 + Y1) * 0.5 + sx * 0.12 + dy, zt + 0.22 + dz), 0.035, steel), "body", True)
    # carga em cima do piso (o que a câmera alta mais vê): baú de guerra, rolo de lona e três caveiras
    add(ck.box("chest", (0.4, 0.3, 0.24), (-0.22, Y0 + 0.3, zt + 0.2), wood), "body", True)
    add(ck.box("chestlid", (0.44, 0.34, 0.07), (-0.22, Y0 + 0.3, zt + 0.34), leather), "body", True)
    for i, dx in enumerate((-0.12, 0.12)):
        add(ck.box("cheststrap%d" % i, (0.06, 0.36, 0.31), (-0.22 + dx, Y0 + 0.3, zt + 0.23), iron), "body", True)
    add(ck.tube("bedroll", (0.06, Y0 + 0.2, zt + 0.2), (0.46, Y0 + 0.3, zt + 0.2), 0.12, 0.12, canvas, 8), "body")
    for i, t in enumerate((0.25, 0.75)):
        c = V((0.06, Y0 + 0.2, zt + 0.2)).lerp(V((0.46, Y0 + 0.3, zt + 0.2)), t)
        add(ck.tube("bedrollstrap%d" % i, c - V((0.03, 0.007, 0)), c + V((0.03, 0.007, 0)), 0.128, 0.128, leather, 8), "body")
    for i, (x, y, r_) in enumerate(((0.3, Y0 + 0.56, 0.1), (0.14, Y0 + 0.62, 0.085), (0.26, Y0 + 0.7, 0.07))):
        add(_stud("pileskull%d" % i, (x, y, zt + 0.08 + r_ * 0.85), r_, horn, (1.0, 1.1, 0.9), 2), "body")
        add(_stud("pileskulleye%d" % i, (x - 0.03, y - r_ * 0.9, zt + 0.08 + r_ * 0.95), r_ * 0.3, socket), "body", True)
    # presas de mamute presas na frente da plataforma (troféu da Horda)
    for sx in (-1, 1):
        pts = [V((sx * (HW - 0.04), Y0 + 0.02, zt + 0.08)), V((sx * (HW + 0.1), Y0 - 0.2, zt + 0.16)), V((sx * (HW + 0.12), Y0 - 0.36, zt + 0.36)), V((sx * (HW + 0.02), Y0 - 0.4, zt + 0.6))]
        add(_horn("trophy%d" % sx, pts, (0.08, 0.072, 0.05, 0.01), horn, 6), "body")
        add(ck.tube("trophyband%d" % sx, pts[0].lerp(pts[1], 0.2), pts[0].lerp(pts[1], 0.6), 0.085, 0.085, iron2, 6), "body")

    # ---------------- correntes: da coleira até os postes da frente ----------------
    for sx in (-1, 1):
        a, _n = surf(cy, sx * 40, 0.1)
        b_ = V((sx * HW, Y0, zt + 0.2))
        pts = []
        for i in range(7):
            t = i / 6
            q = a.lerp(b_, t)
            q.z = max(q.z - 0.22 * math.sin(t * math.pi), top(q.x, q.y)[0].z + 0.11)
            pts.append(q)
        for i in range(6):
            add(ck.tube("chain%d_%d" % (sx, i), pts[i], pts[i + 1], 0.035, 0.035, iron2, 4), "body", True)
            add(_stud("chainlink%d_%d" % (sx, i), pts[i + 1], 0.055, iron, (1, 1, 0.7)), "body", True)

    # ---------------- tambores de guerra (lado +X) ----------------
    for i, (y, r_) in enumerate(((0.14, 0.24), (0.58, 0.2))):
        p, n = flank(1, y, zt - 0.3)
        c = p + V((0.2, 0, 0.02 - i * 0.04))
        ax = V((0.8, 0.0, 0.6))
        add(_war_drum("drum%d" % i, c, ax, r_, 0.34 - i * 0.04, wood, canvas, iron2, leather), "body")
        add(ck.tube("drumstrap%d" % i, (HW, y, rail), c + V((0, 0, r_ * 0.9)), 0.03, 0.03, leather, 4), "body")
        add(ck.tube("drumstrap%db" % i, (HW, y, zt), c + V((-0.1, 0, r_ * 0.2)), 0.03, 0.03, leather, 4), "body")
    p, n = flank(1, 0.36, zt - 0.3)
    mal = p + V((0.3, 0, 0.3))                                # baqueta de osso enfiada entre os dois
    add(ck.tube("mallet", mal, mal + V((0.1, 0.02, -0.5)), 0.03, 0.03, horn2, 5), "body")
    add(_stud("mallethead", mal + V((-0.01, 0, 0.03)), 0.075, leather, sub=2), "body")

    # ---------------- feixe de lanças (lado -X) ----------------
    p, n = flank(-1, 0.3, zt - 0.3)
    sp0 = p + V((-0.16, 0, 0.0))
    sd = V((-0.1, -1.0, 0.16)).normalized()
    for i, (du, dz, ln, back) in enumerate(((0.0, 0.0, 1.0, 0.75), (-0.07, 0.07, 0.92, 0.7), (0.02, 0.12, 1.08, 0.72), (-0.06, -0.06, 0.86, 0.8))):
        a = sp0 + V((du, 0, dz)) - sd * back
        b_ = sp0 + V((du, 0, dz)) + sd * ln
        add(ck.tube("spear%d" % i, a, b_, 0.028, 0.028, wood, 5), "body")
        add(ck.blade("spearhead%d" % i, b_ - sd * 0.02, b_ + sd * 0.3, 0.14, 0.035, steel, (0.3, 0, 1), 0.3), "body", True)
        add(ck.tube("spearsock%d" % i, b_ - sd * 0.1, b_ + sd * 0.02, 0.04, 0.035, iron2, 5), "body")
    for i, t in enumerate((-0.42, 0.3)):                     # correias do feixe
        c = sp0 + V((-0.03, 0, 0.03)) + sd * t
        add(ck.tube("spearstrap%d" % i, c - sd * 0.05, c + sd * 0.05, 0.15, 0.15, leather, 7), "body")
        add(ck.tube("spearhang%d" % i, c + V((0, 0, 0.1)), V((-HW, c.y, zt + 0.04)), 0.03, 0.03, leather, 4), "body")
    add(_cloth("spearrag", sp0 + sd * 0.72 + V((0, 0.07, 0.1)), (0, -1, 0), (-0.25, 0, -1), 0.16, 0.36, red, red2, seed=5, nx=2, ny=3, thick=0.025), "body")

    # ---------------- pintura de guerra ocre-vermelha: três faixas na garupa ----------------
    def back(x, z_, lift=0.0):
        p, n = cast((x, 4, z_), (0, -1, 0))
        if p is None:
            p, n = V((x, 1.2, z_)), V((0, 1, 0))
        return p + n * lift

    for i, z0 in enumerate((1.5, 1.3, 1.1)):                 # três divisas na garupa, lidas por trás e de cima
        for sx in (-1, 1):
            pts = [back(sx * x, z0 - x * 0.55, -0.006) for x in (0.03, 0.15, 0.27, 0.39, 0.5)[:5 - i]]
            add(_strap("paint%d_%d" % (i, sx), pts, 0.05, 0.032, paint, 5), "body")
    for sx in (-1, 1):                                       # e duas riscas descendo do ombro, por baixo da chapa
        for i, y in enumerate((-0.6, -0.42)):
            pts = [surf(y, sx * d, -0.02)[0] for d in (104, 122, 140)]
            add(_strap("paintsh%d_%d" % (sx, i), pts, 0.045, 0.028, paint, 5), "body")

    # ---------------- estandarte rasgado da Horda (osso banner: sacode no urro) ----------------
    base = V((BANNER.x, BANNER.y, zt + 0.06))
    tip = base + V((0, 0.1, 1.56))
    pole_d = (tip - base).normalized()
    add(ck.tube("pole", base - V((0, 0, 0.1)), tip, 0.045, 0.035, wood, 6), "banner")
    for i, t in enumerate((0.12, 0.5)):
        c = base.lerp(tip, t)
        add(ck.tube("poleband%d" % i, c - pole_d * 0.035, c + pole_d * 0.035, 0.058, 0.055, iron2, 6), "banner")
    bar_c = base.lerp(tip, 0.9)
    bx = V((1, 0.32, 0)).normalized()                         # travessa girada: o pano lê de frente e de lado
    BW = 0.52
    add(ck.tube("bar", bar_c - bx * (BW + 0.06), bar_c + bx * (BW + 0.06), 0.03, 0.03, wood, 6), "banner")
    for s in (-1, 1):
        add(_stud("barend%d" % s, bar_c + bx * (s * (BW + 0.07)), 0.055, horn, sub=1), "banner", True)
    co = bar_c - bx * BW + V((0, 0, -0.02))
    add(_cloth("flag", co, bx, (0, 0.06, -1), BW * 2, 1.02, red, red2, seed=3, nx=6, ny=4, thick=0.035, amp=0.14, torn=0.34), "banner")
    add(ck.tube("flagtrim", co + V((0, 0, 0.0)), co + bx * (BW * 2), 0.042, 0.042, red2, 5), "banner")
    fn = bx.cross(V((0, 0.06, -1)).normalized()).normalized()
    for s in (-1, 1):                                        # emblema nas duas faces: chifre de rinoceronte e dois riscos
        o = bar_c + V((0, 0, -0.32)) + fn * (s * 0.085)
        add(ck.blade("emblem%d" % s, o + bx * 0.16 - V((0, 0, 0.18)), o - bx * 0.1 + V((0, 0, 0.17)), 0.2, 0.02, canvas, bx - V((0, 0, 0.6)), 0.3), "banner", True)
        for j in (0, 1):
            q = o - bx * (0.2 - j * 0.42) - V((0, 0, 0.3))
            add(ck.blade("emblemcut%d_%d" % (s, j), q + V((0, 0, 0.08)), q - V((0, 0, 0.1)) + bx * 0.06, 0.06, 0.02, canvas, bx, 0.5), "banner", True)
    # caveira com chifres no topo e duas tiras compridas rasgadas para trás
    add(ck.ball("skull", 0.1, tip + V((0, 0, 0.07)), horn, (1.0, 1.1, 0.95)), "banner")
    add(ck.ball("skulljaw", 0.06, tip + V((0, -0.07, 0.0)), horn2, (1.0, 1.0, 0.8)), "banner")
    for s in (-1, 1):
        add(_stud("skulleye%d" % s, tip + V((s * 0.04, -0.085, 0.09)), 0.03, socket), "banner", True)
        add(mk.cone("skullhorn%d" % s, tip + V((s * 0.07, 0, 0.1)), tip + V((s * 0.26, 0.04, 0.3)), 0.045, horn2, 5), "banner", True)
    add(_cloth("streamer0", tip + V((-0.05, 0.03, -0.04)), (0, 0.2, -1), (0.2, 1, -0.55), 0.14, 0.7, red, red2, seed=7, nx=2, ny=5, thick=0.025, amp=0.05), "banner")
    add(_cloth("streamer1", tip + V((0.05, 0.03, -0.1)), (0, 0.2, -1), (-0.25, 1, -0.9), 0.12, 0.5, red2, None, seed=9, nx=2, ny=4, thick=0.025, amp=0.045), "banner")

    # ---------------- cabeça (osso head; cresce RHINO_HEAD_K no fim, junto com a mandíbula) ----------------
    n_head = len(parts)
    hpts = [((0, -0.96, 1.06), 0.42), ((0, -1.3, 1.0), 0.4), ((0, -1.62, 0.9), 0.33), ((0, -1.88, 0.84), 0.3)]
    skull = mk.skin_body("skull", hpts, [(0, 1), (1, 2), (2, 3)], hide, sub=2)
    for v in skull.data.vertices:
        v.co.x *= 1.12
    add(skull, "head")
    hcast = _caster(skull)

    def htop(x, y, lift=0.0):
        p, n = hcast((x, y, 5), (0, 0, -1))
        if p is None:
            p, n = V((x, y, 1.2)), V((0, 0, 1))
        return p + n * lift, n

    def hside(sx, y, z, lift=0.0):
        p, n = hcast((sx * 3, y, z), (-sx, 0, 0))
        if p is None:
            p, n = V((sx * 0.3, y, z)), V((sx, 0, 0))
        return p + n * lift, n

    # testeira de ferro rebitada (entre os dois chifres e as orelhas) e faixa do focinho
    def chanfron_pick(c, n):
        return n.z > 0.38 and -1.5 < c.y < -1.0

    add(_shell("chanfron", skull, chanfron_pick, 0.045, iron), "head")
    for sx in (-1, 1):
        for i, y in enumerate((-1.08, -1.42)):
            p, n = htop(sx * 0.2, y, 0.05)
            add(_stud("hrivet%d_%d" % (sx, i), p, 0.045, steel), "head", True)
        p, n = htop(sx * 0.24, -1.24, 0.04)                   # cravo da sobrancelha
        add(mk.cone("browspike%d" % sx, p, p + V((sx * 0.12, -0.06, 0.2)), 0.06, steel, 5), "head", True)
    for sx in (-1, 1):                                       # duas riscas de tinta de guerra por cima da testeira
        pts = [htop(sx * (0.09 + 0.05 * i), -1.4 + i * 0.13, 0.04)[0] for i in range(4)]
        add(_strap("platepaint%d" % sx, pts, 0.04, 0.03, paint, 5), "head")
    # chifre grande da frente: curvo, com ponteira de ferro tosco, aro na base e duas talas
    hp = [V((0, -1.72, 0.98)), V((0, -1.9, 1.16)), V((0, -2.03, 1.38)), V((0, -2.11, 1.6)), V((0, -2.15, 1.8)), V((0, -2.13, 1.98))]
    hr = (0.21, 0.185, 0.155, 0.12, 0.085, 0.04)
    add(_horn("bighorn", hp, hr, horn, 8), "head")
    add(ck.tube("hornbase", hp[0] + V((0, 0.03, -0.04)), hp[0].lerp(hp[1], 0.35), 0.245, 0.225, iron2, 8), "head")
    cap_a = hp[3].lerp(hp[4], 0.1)
    add(_horn("horncap", [cap_a, hp[4], hp[5], hp[5] + V((0, 0.05, 0.16))], (0.134, 0.104, 0.058, 0.006), iron, 8), "head", True)
    hd = (hp[4] - hp[3]).normalized()
    add(ck.tube("horncapband", cap_a - hd * 0.03, cap_a + hd * 0.045, 0.15, 0.144, iron2, 8), "head")
    hd = (hp[2] - hp[1]).normalized()
    add(ck.tube("hornband", hp[1].lerp(hp[2], 0.35) - hd * 0.035, hp[1].lerp(hp[2], 0.35) + hd * 0.035, 0.186, 0.178, iron2, 8), "head")
    for i, sx in enumerate((-1, 1)):                          # rebites da ponteira
        add(_stud("caprivet%d" % i, hp[4] + V((sx * 0.1, 0, -0.03)), 0.035, steel), "head", True)
    # segundo chifre, menor, com um lascado
    h2 = [V((0, -1.46, 1.08)), V((0, -1.52, 1.3)), V((0, -1.52, 1.5))]
    add(_horn("horn2", h2, (0.13, 0.1, 0.02), horn, 7), "head")
    add(ck.tube("horn2base", h2[0], h2[0].lerp(h2[1], 0.35), 0.15, 0.135, iron2, 7), "head")
    add(ck.tube("horn2chip", h2[1] + V((0.06, 0, 0.0)), h2[1] + V((0.12, 0.02, 0.1)), 0.04, 0.008, horn2, 4), "head", True)
    # olhos pequenos e raivosos em brasa, fundos sob a dobra da sobrancelha
    for sx in (-1, 1):
        e, n = hside(sx, -1.3, 1.04)
        add(_stud("socket%d" % sx, e - n * 0.01, 0.08, socket, (0.7, 1.1, 0.9), 2), "head")
        add(_stud("eye%d" % sx, e + n * 0.04 + V((0, -0.01, 0)), 0.05, glow, sub=2), "head")
        add(_stud("brow%d" % sx, e + n * 0.03 + V((0, -0.02, 0.095)), 0.11, dark, (0.8, 1.5, 0.42), 2), "head")
        # pintura de guerra na bochecha: dois riscos
        for j in range(2):
            a, _n = hside(sx, -1.2 + j * 0.13, 0.98, -0.01)
            b_, _n = hside(sx, -1.1 + j * 0.13, 0.8, -0.01)
            add(ck.tube("cheekpaint%d_%d" % (sx, j), a, b_, 0.04, 0.028, paint, 5), "head")
        # narinas e ruga do focinho
        p, n = hcast((sx * 0.15, -3, 0.9), (0, 1, 0))
        add(_stud("nostril%d" % sx, (p if p is not None else V((sx * 0.15, -2.06, 0.9))), 0.05, socket, (1.0, 0.5, 0.7)), "head", True)
    # orelhas: a esquerda (+X) inteira com argola de ferro, a direita rasgada em duas pontas
    add(ck.tube("ear1", (0.3, -1.1, 1.22), (0.54, -1.02, 1.54), 0.12, 0.05, hide, 6), "head")
    add(_stud("ear1in", (0.43, -1.11, 1.4), 0.06, dark, (0.8, 0.5, 1.5)), "head")
    add(_ring("earring", (0.56, -1.02, 1.42), (0, 1, 0), 0.06, 0.016, steel, 6, 4), "head")
    add(ck.tube("ear-1a", (-0.3, -1.1, 1.22), (-0.46, -1.08, 1.48), 0.12, 0.035, hide, 6), "head")
    add(ck.tube("ear-1b", (-0.32, -1.04, 1.22), (-0.54, -0.96, 1.38), 0.09, 0.03, hide, 5), "head")
    # lábio de cima largo e céu da boca
    add(mk.blob("lip", 0.2, (0, -1.93, 0.76), light, (1.3, 0.7, 0.6), 2), "head")
    add(mk.blob("palate", 0.2, (0, -1.62, 0.74), mouth, (1.1, 1.7, 0.3), 2), "head")
    # mandíbula (osso jaw, X- abre)
    jaw = mk.skin_body("jawbone", [((0, -1.26, 0.78), 0.24), ((0, -1.6, 0.69), 0.24), ((0, -1.86, 0.67), 0.2)], [(0, 1), (1, 2)], light, sub=1)
    add(_sq(jaw, (0, -1.6, 0.7), (1.25, 1, 0.62)), "jaw")
    add(mk.blob("tongue", 0.17, (0, -1.64, 0.75), mouth, (1.0, 1.7, 0.25), 2), "jaw")
    for o, _b in parts[n_head:]:
        for v in o.data.vertices:
            v.co = hs(v.co)

    # ---------------- pernas de coluna: cotovelo/joelho em dobra, pé largo com três unhas ----------------
    for bone_, sx, front in (("leg_fr", 1, True), ("leg_fl", -1, True), ("leg_br", 1, False), ("leg_bl", -1, False)):
        if front:
            x, y = sx * 0.45, -0.5
            add(mk.blob("shoulder_" + bone_, 0.3, (x, y, 0.9), hide, (0.8, 1.0, 1.3), 2), bone_)
            r0, r1 = 0.24, 0.2
        else:
            x, y = sx * 0.43, 0.6
            add(mk.blob("haunch_" + bone_, 0.34, (x - sx * 0.03, y - 0.04, 0.94), hide, (0.74, 1.05, 1.2), 2), bone_)
            r0, r1 = 0.23, 0.195
        add(ck.tube("leg_" + bone_, (x, y, 0.8), (x, y - 0.02, 0.2), r0, r1, hide, 8), bone_)
        add(ck.tube("knee_" + bone_, (x, y - 0.01, 0.5), (x, y - 0.01, 0.42), r1 * 1.16, r1 * 1.12, dark, 8), bone_)
        add(ck.tube("foot_" + bone_, (x, y - 0.04, 0.22), (x, y - 0.04, 0.0), r1 * 1.0, r1 * 1.24, dark, 8), bone_, True)
        for j, a in enumerate((-0.7, 0.0, 0.7)):             # unhas
            c = V((x + math.sin(a) * r1 * 1.15, y - 0.04 - math.cos(a) * r1 * 1.15, 0.065))
            add(_stud("nail%d_%s" % (j, bone_), c, 0.07, horn2, (1.0, 0.8, 0.93)), bone_, True)
        if front:                                            # braçadeira de ferro com cravos
            add(ck.tube("greave_" + bone_, (x, y - 0.01, 0.78), (x, y - 0.015, 0.58), r0 * 1.1, r0 * 1.04, iron, 8), bone_, True)
            for j in (0, 2):
                a = math.radians(-90 + (j - 1) * 40)
                d = V((math.cos(a) * 0.5 + sx * 0.6, math.sin(a), 0)).normalized()
                c = V((x, y - 0.01, 0.68)) + d * (r0 * 1.02)
                add(mk.cone("greavespike%d_%s" % (j, bone_), c, c + d * 0.16, 0.05, steel, 5), bone_, True)
        else:                                                # duas faixas de tinta na coxa
            for j, z_ in enumerate((0.72, 0.6)):
                add(ck.tube("legpaint%d_%s" % (j, bone_), (x, y, z_), (x, y - 0.003, z_ - 0.05), r0 * 1.0 + 0.012 - j * 0.008, r0 * 1.0 + 0.008 - j * 0.008, paint, 8), bone_)

    # ---------------- rabo fino com tufo ----------------
    tp = [((0, 1.16, 1.3), 0.075), ((0, 1.38, 1.22), 0.05), ((0, 1.46, 1.0), 0.035), ((0, 1.46, 0.8), 0.03)]
    add(mk.skin_body("whip", tp, [(0, 1), (1, 2), (2, 3)], hide, sub=1), "tail")
    add(mk.blob("whip_tuft", 0.08, (0, 1.47, 0.7), dark, (0.8, 0.9, 1.6), 2), "tail")

    objs = [o for o, _b in parts]
    for o in objs:
        if o.name not in flat:
            ck._smooth(o.data)
    _outward(objs)
    for o in objs:
        for v in o.data.vertices:
            v.co *= K
    by_bone = {}
    for o, bone_ in parts:
        by_bone.setdefault(bone_, []).append(o)
    for bone_, objs_ in by_bone.items():
        lp.attach(ck._join(objs_, "wr_" + bone_), arm, bone_)
    _rhino_clips(arm, K)
    legs = ("leg_fr", "leg_fl", "leg_br", "leg_bl")
    heads = ("head", "jaw")
    _ground(arm, [c for c in RHINO_CLIPS if c != "die"], legs, RHINO_TUCK * K, heads=heads)
    _ground(arm, ["die"], (), 0.0, DIE_SINK, head=False)
    return arm


def _rhino_clips(arm, K):
    """Mesmos eixos do javali (ver `_boar_clips`): corpo X+ = focinho desce, gira em volta da anca; cabeça X+ = abaixa o chifre
    (com ~35° o chifre grande aponta para a frente), Z = vira; mandíbula X- = ABRE; rabo X+ = sobe. O osso `banner` (mastro do
    estandarte, filho do corpo, aponta para cima): X = tomba para a frente/trás, Z = para os lados; sacode no urro e atrasa na corrida.
    Toda chave leva escala (`_eclip`)."""
    z = (0, 0, 0)
    r = lambda x=0.0, y=0.0, zz=0.0: (x, y, zz)
    p = lambda up=0.0, fwd=0.0: (0, up * K, fwd * K)
    jw = lambda seq: [(f, (-a, 0, 0), z) for f, a in seq]           # graus de boca ABERTA
    bn = lambda seq: [(f, (a, 0, b_), z) for f, a, b_ in seq]       # estandarte: (quadro, frente/trás, lado)
    tau = math.tau
    sin, cos = math.sin, math.cos
    legs = ("leg_fr", "leg_fl", "leg_br", "leg_bl")

    def planted(body, extra=None):
        return {g: bg.plant(body, g, (extra or {}).get(g, ())) for g in legs}

    def shake(f0, f1, amp, base=0.0):
        """estandarte sacudindo de f0 a f1 (um vai e vem a cada 2 quadros)"""
        return [(f, base + amp * (0.5 if i % 2 else -0.5), amp * (1 if i % 2 else -1)) for i, f in enumerate(range(f0, f1 + 1, 2))]

    # ---- idle: respira fundo, balança a cabeça pesada, abana o rabo; o estandarte oscila devagar ----
    n = 48
    k = {b_: [] for b_ in ("body", "head", "jaw", "tail", "leg_fr", "leg_fl", "banner")}
    for f in list(range(1, n, 3)) + [n]:
        a = (f - 1) / (n - 1) * tau
        k["body"].append((f, r(1.2 * sin(a)), p(0.02 * (0.5 - 0.5 * cos(a)))))
        k["head"].append((f, r(4 + 3 * sin(a + 0.6), 0, 5 * sin(a)), z))
        k["jaw"].append((f, r(-2 - 2 * sin(a + 0.6)), z))
        k["tail"].append((f, r(4, 0, 14 * sin(2 * a)), z))
        k["leg_fr"].append((f, r(-1.2 * sin(a)), z))
        k["leg_fl"].append((f, r(-1.2 * sin(a)), z))
        k["banner"].append((f, r(2 * sin(a + 1.0), 0, 3 * sin(a)), z))
    _eclip(arm, "idle", k, n, loop=True)

    # ---- run: galope pesado de cabeça baixa; o estandarte atrasa ----
    n = 16
    k = {b_: [] for b_ in ("body", "head", "jaw", "tail", "banner") + legs}
    for f in range(1, n + 1):
        a = (f - 1) / (n - 1) * tau
        k["body"].append((f, r(-3.5 * cos(a), 0, 2.5 * sin(a)), p(0.06 * (0.5 + 0.5 * sin(a)))))
        k["head"].append((f, r(3 * cos(a) + 12, 0, -2 * sin(a)), z))
        k["jaw"].append((f, r(-4), z))
        k["leg_fr"].append((f, r(-28 * sin(a) + 3.5 * cos(a)), z))
        k["leg_fl"].append((f, r(-28 * sin(a - 0.5) + 3.5 * cos(a)), z))
        k["leg_br"].append((f, r(25 * sin(a + 0.25) + 3.5 * cos(a)), z))
        k["leg_bl"].append((f, r(25 * sin(a - 0.25) + 3.5 * cos(a)), z))
        k["tail"].append((f, r(18 + 10 * sin(a - 1.2), 0, 6 * sin(a + 0.6)), z))
        k["banner"].append((f, r(-7 + 5 * sin(a - 1.0), 0, 5 * sin(a + 0.4)), z))
    _eclip(arm, "run", k, n, loop=True)

    # ---- attack (5): abaixa o chifre e crava para cima e para a frente ----
    e = 16
    _eclip(arm, "attack", {
        "body": [(1, z, z), (3, r(7), p(-0.03, -0.1)), (5, r(-8), p(0.03, 0.26)), (8, r(-5), p(0.02, 0.2)), (11, r(2), p(0, 0.06)), (e, z, z)],
        "head": [(1, z, z), (3, r(22, 0, 6), z), (5, r(-26, 0, -6), z), (8, r(-16), z), (11, r(-2), z), (e, z, z)],
        "jaw": jw([(1, 0), (3, 4), (5, 16), (8, 10), (e, 0)]),
        "leg_fr": [(1, z, z), (3, r(8), z), (5, r(-20), z), (8, r(-12), z), (12, r(-4), z), (e, z, z)],
        "leg_fl": [(1, z, z), (3, r(6), z), (5, r(-14), z), (8, r(-9), z), (12, r(-2), z), (e, z, z)],
        "leg_br": [(1, z, z), (3, r(-14), z), (5, r(28), z), (8, r(18), z), (12, r(4), z), (e, z, z)],
        "leg_bl": [(1, z, z), (3, r(-14), z), (5, r(24), z), (8, r(15), z), (12, r(2), z), (e, z, z)],
        "tail": [(1, z, z), (3, r(12), z), (5, r(-14), z), (9, r(8, 0, 12), z), (e, z, z)],
        "banner": bn([(1, 0, 0), (3, 6, 0), (5, -10, 3), (8, 6, -3), (11, -3, 2), (e, 0, 0)]),
    }, e)

    # ---- hit: tranco para trás, cabeça vira, estandarte chicoteia ----
    body = [(1, z, z), (2, r(-5, 0, 4), p(0.01, -0.07)), (5, r(3, 0, -2), p(0, -0.035)), (7, r(-1), p(0, -0.012)), (10, z, z)]
    k = planted(body, {"leg_fr": [(2, -9), (5, 4)], "leg_fl": [(2, -6), (5, 3)], "leg_br": [(2, 7), (5, -3)], "leg_bl": [(2, 5), (5, -3)]})
    k.update({"body": body, "head": [(1, z, z), (2, r(-18, 0, 14), z), (5, r(8, 0, -7), z), (7, r(-2), z), (10, z, z)],
              "jaw": jw([(1, 0), (2, 18), (5, 6), (10, 0)]),
              "tail": [(1, z, z), (2, r(-24), z), (5, r(-12, 0, 8), z), (10, z, z)],
              "banner": bn([(1, 0, 0), (2, 12, -8), (4, -8, 6), (6, 5, -4), (8, -2, 2), (10, 0, 0)])})
    _eclip(arm, "hit", k, 10)

    # ---- atk_charge (5): cava, recua de chifre baixo e dispara atropelando; no fim joga a cabeça para cima ----
    e = 20
    _eclip(arm, "atk_charge", {
        "body": [(1, z, z), (3, r(5), p(-0.02, -0.2)), (5, r(4), p(0.02, 0.46)), (8, r(3), p(0.03, 0.52)), (10, r(-9), p(0.04, 0.42)), (13, r(-3), p(0.01, 0.18)),
                 (17, r(1), p(0, 0.03)), (e, z, z)],
        "head": [(1, z, z), (3, r(24), z), (5, r(24), z), (8, r(22), z), (10, r(-28, 0, -8), z), (13, r(-10, 0, 4), z), (17, r(2), z), (e, z, z)],
        "jaw": jw([(1, 0), (3, 6), (5, 4), (8, 4), (10, 22), (13, 10), (e, 0)]),
        "leg_fr": [(1, z, z), (3, r(14), z), (5, r(-46), z), (8, r(-36), z), (10, r(4), z), (13, r(6), z), (e, z, z)],
        "leg_fl": [(1, z, z), (3, r(10), z), (5, r(-38), z), (8, r(-28), z), (10, r(8), z), (13, r(4), z), (e, z, z)],
        "leg_br": [(1, z, z), (3, r(-24), z), (5, r(40), z), (8, r(30), z), (10, r(14), z), (13, r(-2), z), (e, z, z)],
        "leg_bl": [(1, z, z), (3, r(-24), z), (5, r(34), z), (8, r(25), z), (10, r(12), z), (13, r(0), z), (e, z, z)],
        "tail": [(1, z, z), (3, r(22), z), (5, r(40), z), (8, r(36, 0, 8), z), (10, r(16, 0, -10), z), (14, r(6), z), (e, z, z)],
        "banner": bn([(1, 0, 0), (3, 10, 0), (5, -18, 3), (8, -14, -4), (10, 10, 4), (13, -5, -3), (17, 2, 0), (e, 0, 0)]),
    }, e)

    # ---- slam (8): empina nas patas de trás e desaba com as duas patas da frente; o corpo afunda, quica e assenta ----
    e = 24
    _eclip(arm, "slam", {
        "body": [(1, z, z), (3, r(6), p(-0.03)), (5, r(-32), p(0.03, -0.04)), (6, r(-36), p(0.04, -0.05)), (8, r(9), p(-0.03, 0.1)), (10, r(5), p(0.0, 0.08)),
                 (12, r(8), p(-0.02, 0.07)), (15, r(2), p(0, 0.03)), (20, r(-1), z), (e, z, z)],
        "head": [(1, z, z), (3, r(12), z), (5, r(-6), z), (6, r(-2), z), (8, r(16), z), (10, r(10, 0, 4), z), (12, r(10, 0, -4), z), (16, r(3), z), (e, z, z)],
        "jaw": jw([(1, 0), (5, 14), (6, 20), (8, 4), (12, 8), (e, 0)]),
        "leg_fr": [(1, z, z), (3, r(8), z), (5, r(-46), z), (6, r(-54), z), (7, r(-28), z), (8, r(-9), z), (10, r(-5), z), (12, r(-8), z), (15, r(-2), z), (e, z, z)],
        "leg_fl": [(1, z, z), (3, r(8), z), (5, r(-38), z), (6, r(-48), z), (7, r(-24), z), (8, r(-9), z), (10, r(-5), z), (12, r(-8), z), (15, r(-2), z), (e, z, z)],
        "leg_br": [(1, z, z), (3, r(-6), z), (5, r(32), z), (6, r(36), z), (8, r(-9), z), (10, r(-5), z), (12, r(-8), z), (15, r(-2), z), (e, z, z)],
        "leg_bl": [(1, z, z), (3, r(-6), z), (5, r(32), z), (6, r(36), z), (8, r(-9), z), (10, r(-5), z), (12, r(-8), z), (15, r(-2), z), (e, z, z)],
        "tail": [(1, z, z), (4, r(40), z), (5, r(60), z), (6, r(64), z), (8, r(-10), z), (12, r(8, 0, 10), z), (16, r(2, 0, -6), z), (e, z, z)],
        "banner": bn([(1, 0, 0), (3, -4, 0), (5, 14, 0), (6, 16, 2), (8, -20, -3), (10, 12, 4), (12, -8, -3), (15, 4, 2), (20, -1, 0), (e, 0, 0)]),
    }, e)

    # ---- roar / shout (7): recolhe, crava as patas abertas, berra de boca aberta para o alto; o estandarte sacode ----
    e = 24
    body = [(1, z, z), (4, r(7), p(-0.03, -0.04)), (7, r(-10), p(0.02, 0.02)), (9, r(-9, 0, 2.5), p(0.02, 0.02)), (11, r(-10, 0, -2.5), p(0.02, 0.02)),
            (13, r(-9, 0, 2), p(0.02, 0.02)), (16, r(-7), p(0.01, 0.01)), (20, r(2), z), (e, z, z)]
    k = planted(body, {"leg_fr": [(4, 0, 4), (7, 0, 10), (16, 0, 10), (20, 0, 3)], "leg_fl": [(4, 0, 4), (7, 0, 10), (16, 0, 10), (20, 0, 3)]})
    k.update({"body": body,
              "head": [(1, z, z), (4, r(22), z), (7, r(-30, 0, 8), z), (9, r(-28, 0, -8), z), (11, r(-30, 0, 8), z), (13, r(-28, 0, -6), z), (16, r(-20), z),
                       (20, r(4), z), (e, z, z)],
              "jaw": jw([(1, 0), (4, 0), (7, 44), (9, 38), (11, 44), (13, 38), (16, 28), (20, 6), (e, 0)]),
              "tail": [(1, z, z), (4, r(-6), z), (7, r(34, 0, 14), z), (9, r(34, 0, -14), z), (11, r(34, 0, 14), z), (13, r(30, 0, -10), z), (17, r(12), z), (e, z, z)],
              "banner": bn([(1, 0, 0), (4, -5, 0)] + shake(7, 17, 14) + [(20, 3, -3), (e, 0, 0)])})
    for name in ("roar", "shout"):
        _eclip(arm, name, {b_: list(v) for b_, v in k.items()}, e)

    # ---- maul (7): recolhe a cabeça para um lado e joga o chifre de lado, cruzando a frente ----
    e = 18
    body = [(1, z, z), (3, r(4, -10), p(-0.02, -0.05)), (5, r(6, -18), p(-0.02, -0.08)), (7, r(-4, 16), p(0.02, 0.16)), (9, r(-3, 20), p(0.02, 0.14)),
            (12, r(0, 7), p(0, 0.05)), (e, z, z)]
    k = planted(body, {"leg_fr": [(5, 10), (7, -14), (9, -10), (12, -3)], "leg_fl": [(5, -6), (7, -8), (9, -6)], "leg_br": [(5, -8), (7, 12), (9, 8)],
                       "leg_bl": [(5, -8), (7, 10), (9, 6)]})
    k.update({"body": body,
              "head": [(1, z, z), (3, r(12, 0, -16), z), (5, r(16, 0, -30), z), (7, r(-6, 0, 34), z), (9, r(-10, 0, 38), z), (12, r(-2, 0, 10), z), (e, z, z)],
              "jaw": jw([(1, 0), (5, 4), (7, 18), (9, 12), (e, 0)]),
              "tail": [(1, z, z), (5, r(10, 0, -18), z), (7, r(-8, 0, 22), z), (11, r(6, 0, -8), z), (e, z, z)],
              "banner": bn([(1, 0, 0), (5, 3, 8), (7, -4, -14), (9, 2, 10), (12, -1, -5), (15, 0, 2), (e, 0, 0)])})
    _eclip(arm, "maul", k, e)

    # ---- pounce (9): agacha, salta curto para a frente e cai nas patas da frente ----
    e = 20
    _eclip(arm, "pounce", {
        "body": [(1, z, z), (3, r(5), p(-0.04, -0.06)), (5, r(8), p(-0.07, -0.12)), (7, r(-14), p(0.26, 0.26)), (8, r(-4), p(0.25, 0.4)), (9, r(10), p(0.0, 0.46)),
                 (11, r(7), p(-0.03, 0.38)), (13, r(4), p(-0.02, 0.24)), (17, r(-1), p(0, 0.05)), (e, z, z)],
        "head": [(1, z, z), (5, r(14), z), (7, r(-12), z), (9, r(16), z), (11, r(10), z), (14, r(4), z), (e, z, z)],
        "jaw": jw([(1, 0), (7, 16), (9, 4), (e, 0)]),
        "leg_fr": [(1, z, z), (5, r(18), z), (7, r(-54), z), (8, r(-38), z), (9, r(-10), z), (11, r(-7), z), (13, r(-4), z), (e, z, z)],
        "leg_fl": [(1, z, z), (5, r(18), z), (7, r(-46), z), (8, r(-32), z), (9, r(-10), z), (11, r(-7), z), (13, r(-4), z), (e, z, z)],
        "leg_br": [(1, z, z), (5, r(-28), z), (7, r(46), z), (8, r(38), z), (9, r(-10), z), (11, r(-7), z), (13, r(-4), z), (e, z, z)],
        "leg_bl": [(1, z, z), (5, r(-28), z), (7, r(40), z), (8, r(34), z), (9, r(-10), z), (11, r(-7), z), (13, r(-4), z), (e, z, z)],
        "tail": [(1, z, z), (5, r(-12), z), (7, r(26), z), (9, r(-16), z), (13, r(6, 0, 8), z), (e, z, z)],
        "banner": bn([(1, 0, 0), (5, 5, 0), (7, 12, 0), (9, -18, 3), (11, 10, -3), (13, -6, 2), (17, 2, 0), (e, 0, 0)]),
    }, e)

    # ---- brace (6): crava as patas abertas, abaixa o corpo e põe o chifre à frente ----
    e = 18
    body = [(1, z, z), (3, r(-3), p(0.02)), (6, r(6), p(-0.1, 0.04)), (9, r(5), p(-0.085, 0.04)), (12, r(6), p(-0.1, 0.04)), (15, r(2), p(-0.02, 0.01)), (e, z, z)]
    spread = [(6, 0, 10), (12, 0, 10)]
    k = planted(body, {g: spread for g in legs})
    k.update({"body": body, "head": [(1, z, z), (3, r(-8), z), (6, r(18), z), (9, r(15), z), (12, r(18), z), (15, r(6), z), (e, z, z)],
              "jaw": jw([(1, 0), (6, 0), (e, 0)]),
              "tail": [(1, z, z), (6, r(-18), z), (12, r(-16), z), (e, z, z)],
              "banner": bn([(1, 0, 0), (3, 4, 0), (6, -7, 2), (9, -3, -2), (12, -6, 1), (15, -1, 0), (e, 0, 0)])})
    _eclip(arm, "brace", k, e)

    # ---- cast_ground (10): cava o chão duas vezes com a pata direita, de cabeça baixa, e bate a pata bufando (aviso do tremor) ----
    e = 24
    body = [(1, z, z), (3, r(4), p(-0.03, 0.0)), (6, r(5), p(-0.04, 0.0)), (8, r(-4), p(0.02, -0.04)), (10, r(5), p(-0.07, 0.05)), (12, r(4), p(-0.05, 0.04)),
            (14, r(5), p(-0.07, 0.05)), (18, r(2), p(-0.02, 0.01)), (e, z, z)]
    k = planted(body, {"leg_fr": [(2, -30), (4, 16), (5, -30), (7, 16), (8, -40), (10, 0), (14, 0)],
                       "leg_fl": [(8, 0, 3), (10, 0, 8), (14, 0, 8), (18, 0, 2)]})
    k.update({"body": body,
              "head": [(1, z, z), (3, r(18, 0, 5), z), (6, r(20, 0, -5), z), (8, r(4), z), (10, r(22), z), (12, r(16), z), (14, r(20), z), (18, r(8), z), (e, z, z)],
              "jaw": jw([(1, 0), (4, 6), (8, 2), (10, 24), (12, 12), (14, 20), (18, 4), (e, 0)]),
              "tail": [(1, z, z), (3, r(20, 0, 14), z), (6, r(20, 0, -14), z), (8, r(40), z), (10, r(-10), z), (14, r(10, 0, 8), z), (e, z, z)],
              "banner": bn([(1, 0, 0), (3, 3, 2), (6, 3, -2), (8, 8, 0)] + shake(10, 16, 10) + [(19, 2, -1), (e, 0, 0)])})
    _eclip(arm, "cast_ground", k, e)

    # ---- die: empina com o golpe, os joelhos da frente cedem, tomba de lado e quica; o mastro cede e a boca abre ----
    s = 1.4
    f = lambda x: int(round(1 + (x - 1) * s))
    e = f(24)
    roll = RHINO_DIE_ROLL
    _eclip(arm, "die", {
        "body": [(1, z, z), (f(4), r(-9), p(0.02, -0.05)), (f(9), r(9), p(-0.06, 0.02)), (f(14), r(3), p(-0.02)), (e, r(3), p(-0.02))],
        "head": [(1, z, z), (f(4), r(-26, 0, 8), z), (f(9), r(22), z), (f(14), r(8, 0, 12), z), (f(17), r(0, 0, 7), z), (f(20), r(8, 0, 12), z), (e, r(8, 0, 12), z)],
        "jaw": jw([(1, 0), (f(4), 30), (f(9), 8), (f(14), 22), (e, 18)]),
        "leg_fr": [(1, z, z), (f(4), r(-16), z), (f(9), r(30), z), (f(14), r(-18), z), (f(17), r(-25), z), (e, r(-18), z)],
        "leg_fl": [(1, z, z), (f(4), r(-12), z), (f(9), r(26), z), (f(14), r(-9), z), (f(17), r(-14), z), (e, r(-9), z)],
        "leg_br": [(1, z, z), (f(4), r(8), z), (f(9), r(-16), z), (f(14), r(14), z), (f(17), r(21), z), (e, r(14), z)],
        "leg_bl": [(1, z, z), (f(4), r(8), z), (f(9), r(-16), z), (f(14), r(23), z), (f(17), r(28), z), (e, r(23), z)],
        "tail": [(1, z, z), (f(4), r(-22), z), (f(9), r(-28), z), (f(14), r(6, 0, 10), z), (f(17), r(10, 0, 18), z), (e, r(4, 0, 12), z)],
        "banner": bn([(1, 0, 0), (f(4), 12, 0), (f(9), -14, 4), (f(14), 6, 20), (f(17), 3, 12), (f(20), 6, 24), (e, 6, 24)]),
        "root": [(1, z, z), (f(9), z, z), (f(14), r(0, 0, roll), z), (f(17), r(0, 0, roll + 7), z), (f(20), r(0, 0, roll), z), (e, r(0, 0, roll), z)],
    }, e)


# ---------------------------------------------------------------------------
# Lobo-Rei de Ferro
# ---------------------------------------------------------------------------
IW_SIZE = 0.56             # unidades de desenho -> nativo: ver production/session-state/agent-world-boss-lobo-rei.md
IW_TUCK = 0.3
# espinha: anca -> lombo -> meio -> peito fundo/cernelha alta -> base do pescoço -> pescoço
IW_SPINE = [((0, 1.0, 1.42), 0.34), ((0, 0.55, 1.44), 0.38), ((0, 0.08, 1.46), 0.42), ((0, -0.42, 1.54), 0.54), ((0, -0.82, 1.66), 0.5), ((0, -1.14, 1.94), 0.4)]
IW_WIDE = 1.06
IW_HEAD = (0, -1.5, 2.0)             # a cabeça (e a mandíbula) cresce IW_HEAD_K em volta daqui
IW_HEAD_K = 1.32
IW_HEAD_SHIFT = (0, -0.06, 0.14)
IW_CHAIN = (0.5, -1.0, 1.52)         # onde a corrente solta pende da coleira partida (osso chain)
IW_FLARE = (0, -0.2, 1.45)           # pivô das runas grandes (osso flare): só mudam de ESCALA
IW_FLARE_REST = 0.8                  # encolhidas ficam dentro das chapas; 1,0 = acesas por cima da armadura
IW_CLIPS = ("idle", "run", "attack", "hit", "die", "atk_charge", "slam", "roar", "shout", "maul", "pounce", "brace", "cast_ground")
IW_IMPACT = {"attack": 5, "atk_charge": 5, "slam": 8, "roar": 7, "shout": 7, "maul": 7, "pounce": 9, "brace": 6, "cast_ground": 10}
IW_GLOW_EYE = 1.0          # olhos azul-gelo (degraus de 0,25: EntityView.mob_glow)
IW_GLOW_RUNE = 0.5         # runas anãs em brasa: fracas
IW_DIE_ROLL = -84          # tomba para -X: a corrente e a coleira partida ficam para cima

IW_FUR = (0.19, 0.24, 0.39)          # pelo cinza-azulado
IW_FUR_D = (0.12, 0.14, 0.25)
IW_FUR_L = (0.56, 0.63, 0.78)
IW_MANE = (0.97, 0.99, 1.0)          # juba branco-geada
IW_MANE_D = (0.7, 0.8, 0.93)
IW_IRON = (0.45, 0.46, 0.53)         # ferro anão em tom médio: entre o pelo azul-escuro e a juba branca
IW_IRON_D = (0.31, 0.32, 0.4) 
IW_STEEL = (0.82, 0.84, 0.88)
IW_BRASS = (0.8, 0.68, 0.44)         # latão dos rebites e filetes: a marca da forja anã
IW_FANG = (0.97, 0.94, 0.84)
IW_BLACK = (0.13, 0.13, 0.17)
IW_MOUTH = (0.74, 0.38, 0.44)
IW_WOOD = (0.46, 0.34, 0.25)
IW_EYE = (0.62, 0.9, 1.0)
IW_EMBER = (1.0, 0.36, 0.08)

# runas anãs angulosas: traços (u, v) em [-1, 1]
IW_GLYPHS = {
    "tyr": (((0, -1), (0, 1)), ((0, 1), (-0.7, 0.25)), ((0, 1), (0.7, 0.25))),
    "fe": (((-0.3, -1), (-0.3, 1)), ((-0.3, 0.15), (0.6, 0.95)), ((-0.3, -0.5), (0.6, 0.3))),
    "ur": (((-0.55, -1), (-0.55, 1)), ((-0.55, 1), (0.55, 0.3)), ((0.55, 0.3), (0.55, -1))),
    "odal": (((0, 1), (0.65, 0.2)), ((0.65, 0.2), (-0.65, -1)), ((0, 1), (-0.65, 0.2)), ((-0.65, 0.2), (0.65, -1))),
    "thorn": (((-0.3, -1), (-0.3, 1)), ((-0.3, 0.7), (0.5, 0.1)), ((0.5, 0.1), (-0.3, -0.5))),
}


def _iw_rune(name, p, n, up, size, glyph, r, material, cast=None, lift=0.02):
    """Runa de traços (tubos) no plano tangente em p; com `cast` cada ponta assenta na superfície."""
    n = V(n).normalized()
    t1 = V(up) - n * V(up).dot(n)
    t1 = t1.normalized() if t1.length > 1e-4 else _perp(n)[1]
    t2 = n.cross(t1)
    p = V(p)

    def at(uv):
        q = p + t2 * (uv[0] * size * 0.5) + t1 * (uv[1] * size * 0.5)
        if cast is not None:
            h, hn = cast(q + n * 0.4, -n)
            if h is not None and (h - q).length < 0.5:
                return h + hn * lift
        return q + n * lift

    out = []
    for i, (a, b_) in enumerate(IW_GLYPHS[glyph]):
        qa, qb = at(a), at(b_)
        ext = (qb - qa).normalized() * (r * 0.6)
        out.append(ck.tube("%s_%d" % (name, i), qa - ext, qb + ext, r, r, material, 4))
    return out


def iron_wolf_king(cid="mob_iron_wolf_king"):
    K = IW_SIZE
    S = lambda p: tuple(x * K for x in p)
    hc = V(IW_HEAD)
    hs = lambda p: hc + (V(p) - hc) * IW_HEAD_K + V(IW_HEAD_SHIFT)
    bones = mk.pivots(body=S((0, 0.9, 1.4)), head=S((0, -1.05, 1.78)),
                      leg_fr=S((0.42, -0.55, 1.4)), leg_fl=S((-0.42, -0.55, 1.4)),
                      leg_br=S((0.4, 0.9, 1.4)), leg_bl=S((-0.4, 0.9, 1.4)))
    t1, t2, jw = S((0, 1.2, 1.5)), S((0, 1.88, 1.58)), S(hs((0, -1.52, 1.8)))
    cp, fp = S(IW_CHAIN), S(IW_FLARE)
    arm = lp.make_armature("rig_" + cid, dict(bones, tail=(t1, (t1[0], t1[1] + 0.3, t1[2] + 0.04), "body"),
                                              tail2=(t2, (t2[0], t2[1] + 0.3, t2[2] + 0.04), "tail"),
                                              jaw=(jw, (jw[0], jw[1] - 0.3, jw[2]), "head"),
                                              chain=(cp, (cp[0], cp[1], cp[2] + 0.3), "body"),
                                              flare=(fp, (fp[0], fp[1], fp[2] + 0.3), "body")))
    m = lambda n, col, rough=0.85, em=0.0: ck.mat("m_%s_%s" % (cid, n), col, rough, em)
    fur, dark, light = m("fur", IW_FUR), m("dark", IW_FUR_D), m("light", IW_FUR_L)
    mane, mane2 = m("mane", IW_MANE, 0.9), m("mane2", IW_MANE_D, 0.9)
    iron, iron2, steel, brass = m("iron", IW_IRON, 0.45), m("iron2", IW_IRON_D, 0.45), m("steel", IW_STEEL, 0.4), m("brass", IW_BRASS, 0.45)
    fang, black, mouth, wood = m("fang", IW_FANG, 0.5), m("black", IW_BLACK, 0.5), m("mouth", IW_MOUTH, 0.7), m("wood", IW_WOOD, 0.9)
    eye = ck.mat("glow_%s_eye" % cid, IW_EYE, 0.3, IW_GLOW_EYE)
    rune = ck.mat("glow_%s_rune" % cid, IW_EMBER, 0.4, IW_GLOW_RUNE)
    parts, flat = [], set()
    fluff = lambda name, a, b_, r_, mt: ck.tube(name, a, b_, r_, r_ * 0.34, mt, 5)      # mecha de juba: base grossa, ponta fina

    def add(o, bone, faceted=False):
        for x in (o if isinstance(o, (list, tuple)) else [o]):
            parts.append((x, bone))
            if faceted:
                flat.add(x.name)

    # ---------------- tronco ----------------
    body = mk.skin_body("body", IW_SPINE, [(i, i + 1) for i in range(len(IW_SPINE) - 1)], fur)
    for v in body.data.vertices:
        v.co.x *= IW_WIDE
    add(body, "body")
    cast = _caster(body)

    def axis_z(y):
        pts = sorted((q[1], q[2]) for q, _r in IW_SPINE)
        if y <= pts[0][0]:
            return pts[0][1]
        for (y0, z0), (y1, z1) in zip(pts, pts[1:]):
            if y0 <= y <= y1:
                return z0 + (z1 - z0) * (y - y0) / (y1 - y0)
        return pts[-1][1]

    def top(x, y, lift=0.0):
        p, n = cast((x, y, 5), (0, 0, -1))
        if p is None:
            p, n = V((x, y, 2.0)), V((0, 0, 1))
        return p + n * lift, n

    def flank(sx, y, z, lift=0.0):
        p, n = cast((sx * 3, y, z), (-sx, 0, 0))
        if p is None:
            p, n = V((sx * 0.5, y, z)), V((sx, 0, 0))
        return p + n * lift, n

    def surf(y, deg, lift=0.0):
        """ponto do pelo na fatia y, a `deg` graus do alto (0 = lombo, 90 = flanco +X, 180 = barriga)"""
        a = math.radians(deg)
        d = V((math.sin(a), 0, math.cos(a)))
        o = V((0, y, axis_z(y)))
        p, n = cast(o + d * 3.0, -d)
        if p is None:
            p, n = o + d * 0.45, d
        return p + n * lift, n

    add(mk.blob("belly", 0.36, (0, 0.12, 1.2), light, (0.95, 2.3, 0.6)), "body")
    add(mk.blob("chest", 0.44, (0, -0.86, 1.3), light, (1.0, 0.85, 0.95), 2), "body")

    # ---------------- lâminas de ferro do lombo (quatro, sobrepostas) com costuras em brasa entre elas ----------------
    LAMES = ((-0.62, -0.3), (-0.26, 0.06), (0.1, 0.42), (0.46, 0.76))
    for i, (y0, y1) in enumerate(LAMES):
        def lame_pick(c, n, y0=y0, y1=y1, i=i):
            return y0 < c.y < y1 and n.z > 0.5 - 0.06 * i
        add(_shell("lame%d" % i, body, lame_pick, 0.07 - 0.008 * i, iron if i % 2 == 0 else iron2, 0.02), "body")
        ym = (y0 + y1) * 0.5
        for sx in (-1, 1):
            for j, y in enumerate((y0 + 0.07, y1 - 0.07)):
                p, n = surf(y, sx * (38 - 3 * i), 0.085 - 0.008 * i)
                add(_stud("lamerivet%d_%d_%d" % (i, sx, j), p, 0.04, brass), "body", True)
    for i, y in enumerate((-0.28, 0.08, 0.44)):                # costuras: fio de brasa no vão entre duas lâminas
        for sx in (-1, 1):
            pts = [surf(y, sx * d, 0.03)[0] for d in (9, 22, 35, 48)]
            add(_strap("seam%d_%d" % (i, sx), pts, 0.03, 0.022, rune, 4), "body")
    for i, y in enumerate((-0.64, -0.28, 0.08, 0.44, 0.78)):   # crista de pelo branco saindo pelos vãos
        p, n = top(0, y, -0.04)
        ln = 0.42 - 0.05 * i
        add(fluff("hackle%d" % i, p, p + V((0, 0.24, ln)), 0.15, mane), "body")

    # ---------------- ombreiras em três lâminas (ferro anão, rebites de latão, cravo) ----------------
    PAULD = (((0.44, -0.46, 1.86), 0.42, (0.95, 1.12, 0.52), iron), ((0.62, -0.46, 1.62), 0.4, (0.72, 1.06, 0.6), iron2), ((0.7, -0.45, 1.36), 0.34, (0.6, 0.98, 0.62), iron))
    pcast = {}
    for sx in (-1, 1):
        for i, (c, r_, sq, mt) in enumerate(PAULD):
            o = mk.blob("pauld%d_%d" % (sx, i), r_, (sx * c[0], c[1], c[2]), mt, sq, 2)
            add(o, "body", True)
            pcast[(sx, i)] = _caster(o)
        # costura em brasa por baixo da borda de cada lâmina
        for i in (1, 2):
            c0, r0, s0, _m = PAULD[i - 1]
            pts = []
            for y in (-0.76, -0.61, -0.46, -0.31, -0.16):
                zz = c0[2]
                for _k in range(40):
                    h, hn = pcast[(sx, i)]((sx * 3, y, zz), (-sx, 0, 0))
                    if h is not None:
                        d = V(((h.x - sx * c0[0]) / (r0 * s0[0]), (h.y - c0[1]) / (r0 * s0[1]), (h.z - c0[2]) / (r0 * s0[2])))
                        if d.length > 1.06:
                            pts.append(h + hn * 0.012)
                            break
                    zz -= 0.02
            if len(pts) > 1:
                add(_strap("pseam%d_%d" % (sx, i), pts, 0.028, 0.028, rune, 4), "body")
        # rebites na borda da lâmina de cima e um cravo
        for j, y in enumerate((-0.78, -0.46, -0.14)):
            h, hn = pcast[(sx, 0)]((sx * (PAULD[0][0][0] + 0.26), y, 5), (0, 0, -1))
            if h is not None:
                add(_stud("pauldrivet%d_%d" % (sx, j), h + hn * 0.015, 0.045, brass), "body", True)
        h, hn = pcast[(sx, 1)]((sx * 3, -0.46, 1.62), (-sx, 0, 0))
        add(mk.cone("pauldspike%d" % sx, h - hn * 0.03, h + (hn * 0.5 + V((0, 0, 1.0))).normalized() * 0.26, 0.09, steel, 6), "body", True)
        # runa pequena e fixa na lâmina de baixo
        h, hn = pcast[(sx, 2)]((sx * 3, -0.45, 1.34), (-sx, 0, 0))
        add(_iw_rune("pauldrune%d" % sx, h, hn, (0, 0, 1), 0.24, "thorn" if sx > 0 else "fe", 0.022, rune, pcast[(sx, 2)], 0.012), "body")
        # runa GRANDE na lâmina de cima (osso flare: acende no uivo que chama a matilha)
        h, hn = pcast[(sx, 0)]((sx * 0.42, -0.46, 5), (0, 0, -1))
        add(_iw_rune("flarepauld%d" % sx, h, hn, (0, -1, 0), 0.5, "tyr" if sx > 0 else "odal", 0.05, rune, pcast[(sx, 0)], 0.03), "flare")
    for i, (y, g) in enumerate(((-0.1, "ur"), (0.6, "fe"))):   # runas grandes no lombo (lâminas 1 e 3), uma de cada lado da crista
        for sx in (-1, 1):
            p, n = top(sx * 0.2, y, 0.1)
            add(_iw_rune("flareback%d_%d" % (i, sx), p, n, (0, -1, 0), 0.3, g if sx > 0 else "thorn", 0.042, rune, None, 0.0), "flare")

    # ---------------- coleira de ferro partida (falta um pedaço no alto do lado +X) e corrente solta ----------------
    cy = -1.0
    degs = list(range(64, 361 + 18, 22))
    ring = [surf(cy, d, 0.07)[0] for d in degs]
    for i in range(len(ring) - 1):
        add(ck.tube("collar%d" % i, ring[i], ring[i + 1], 0.1, 0.1, iron2, 6), "body", True)
    for i, d in enumerate((100, 150, 210, 260, 310, 350)):
        p, n = surf(cy, d, 0.15)
        add(_stud("collarstud%d" % i, p, 0.05, brass), "body", True)
    for i, d in enumerate((degs[0], degs[-1])):                # pontas torcidas do aro partido
        p, n = surf(cy, d, 0.07)
        s = 1 if i == 0 else -1
        add(mk.cone("collarbreak%d" % i, p, p + n * 0.16 + V((-s * 0.06, -0.05, 0.1)), 0.1, iron2, 5), "body", True)
    ca = V(IW_CHAIN)
    p, n = surf(cy, 112, 0.1)
    add(_ring("chainloop", p + n * 0.03, (0, 1, 0), 0.09, 0.03, iron, 6, 4), "body", True)
    add(ck.tube("chainstem", p, ca, 0.03, 0.03, iron, 4), "body", True)
    for i in range(7):                                       # elos alternados, pendendo
        c = ca + V((0.012 * i, 0, -0.06 - 0.125 * i))
        add(_ring("link%d" % i, c, (1, 0, 0) if i % 2 else (0, 1, 0), 0.08, 0.026, iron if i % 2 else iron2, 5, 4), "chain", True)
    ce = ca + V((0.085, 0, -0.06 - 0.125 * 7))
    add(ck.box("shackle", (0.07, 0.2, 0.18), ce, iron2), "chain", True)       # grilhão arrancado na ponta
    add(_stud("shacklerivet", ce + V((0.04, 0, 0.02)), 0.04, brass), "chain", True)
    # corrente atravessada no flanco -X, da ombreira à última lâmina
    a, b_ = V((-0.86, -0.3, 1.34)), top(-0.34, 0.62, 0.08)[0]
    pts = []
    for i in range(8):
        t = i / 7
        q = a.lerp(b_, t)
        q.z -= 0.2 * math.sin(t * math.pi)
        p, n = flank(-1, q.y, q.z, 0.07)
        if p is not None and abs(p.x) > abs(q.x):
            q = p
        pts.append(q)
    for i in range(7):
        add(ck.tube("drape%d" % i, pts[i], pts[i + 1], 0.028, 0.028, iron2, 4), "body", True)
        add(_stud("drapelink%d" % i, pts[i + 1], 0.05, iron, (1, 1, 0.7)), "body", True)

    # ---------------- juba branco-geada: duas fileiras de mechas atrás da coleira, peitilho ----------------
    add(mk.blob("ruff", 0.56, (0, -0.86, 1.76), mane, (1.1, 0.6, 1.06), 2), "body")
    for i, d in enumerate(range(-140, 141, 20)):
        p, n = surf(-0.92, d + 6 * math.sin(i * 1.9), -0.06)
        tip = p + (n * 0.75 + V((0, 0.8, 0.2))).normalized() * (0.6 + 0.16 * math.sin(i * 2.3))
        add(fluff("ruffa%d" % i, p, tip, 0.22, mane), "body")
    for i, d in enumerate(range(-150, 151, 25)):
        if abs(d) < 20:
            continue
        p, n = surf(-0.72, d, -0.05)
        tip = p + (n * 0.6 + V((0, 0.9, 0.05))).normalized() * (0.5 + 0.12 * math.sin(i * 1.7))
        add(fluff("ruffb%d" % i, p, tip, 0.2, mane2), "body")
    for i, x in enumerate((-0.26, 0.0, 0.26)):               # peitilho
        add(fluff("bib%d" % i, (x, -1.14, 1.56), (x * 1.3, -1.3 + abs(x) * 0.3, 0.92 + abs(x) * 0.4), 0.24, mane), "body")

    # ---------------- troféus de guerra: espada anã cravada no lombo, dois virotes na garupa, cicatriz de garra ----------------
    p, n = top(0.2, 0.26, -0.02)
    sd = V((0.3, 0.25, 1.0)).normalized()
    add(ck.blade("swordblade", p - sd * 0.1, p + sd * 0.3, 0.13, 0.035, steel, (0, 1, 0), 0.5), "body", True)
    add(ck.box("swordguard", (0.07, 0.3, 0.06), p + sd * 0.3, brass), "body", True)
    add(ck.tube("swordgrip", p + sd * 0.3, p + sd * 0.52, 0.035, 0.035, wood, 5), "body")
    add(_stud("swordpommel", p + sd * 0.55, 0.055, brass), "body", True)
    for i, (x, y, d) in enumerate(((-0.24, 0.9, (-0.5, 0.4, 1.0)), (-0.1, 1.08, (-0.2, 0.7, 1.0)))):
        p, n = top(x, y, -0.02)
        add(_stuck("bolt%d" % i, p, d, 0.34, 0.022, wood, brass), "body")
    for i in range(3):                                       # três riscos de garra no flanco +X
        pts = [surf(0.62 + 0.11 * i + 0.05 * j, 58 + 14 * j, -0.012)[0] for j in range(4)]
        add(_strap("scar%d" % i, pts, 0.03, 0.02, mouth, 4), "body")

    # ---------------- cabeça (osso head; cresce IW_HEAD_K no fim, junto com a mandíbula) ----------------
    n_head = len(parts)
    cran = mk.blob("cranium", 0.44, (0, -1.45, 2.02), fur, (1.05, 1.0, 0.9), 3)
    add(cran, "head")
    snout = mk.skin_body("snout", [((0, -1.72, 1.98), 0.25), ((0, -2.05, 1.94), 0.2), ((0, -2.44, 1.92), 0.17)], [(0, 1), (1, 2)], fur, sub=2)
    _sq(snout, (0, -2.0, 2.0), (1.15, 1, 0.8))
    add(snout, "head")
    ccast, scast = _caster(cran), _caster(snout)

    def htop(x, y, lift=0.0):
        best = None
        for c_ in (ccast, scast):
            p, n = c_((x, y, 5), (0, 0, -1))
            if p is not None and (best is None or p.z > best[0].z):
                best = (p, n)
        if best is None:
            best = (V((x, y, 2.2)), V((0, 0, 1)))
        return best[0] + best[1] * lift, best[1]

    eyes = []
    for sx in (-1, 1):
        e, n = ccast((sx * 3, -1.74, 2.08), (-sx, 0, 0))
        eyes.append((sx, e, n))

    # elmo-máscara rebitado: calota no crânio (com furos nos olhos) e chapa no focinho
    def helm_pick(c, n):
        return n.z > -0.05 and c.y < -1.16 and all((c - e).length > 0.15 for _s, e, _n in eyes)

    def muzzle_pick(c, n):
        return n.z > 0.2 and -2.3 < c.y < -1.7

    add(_shell("helm", cran, helm_pick, 0.055, iron), "head")
    add(_shell("muzzle", snout, muzzle_pick, 0.045, iron2), "head")
    for i, y in enumerate((-1.96, -2.24)):                    # cintas de latão por cima do focinho
        pts = []
        for d in (-80, -50, -20, 20, 50, 80):
            a = math.radians(d)
            dv = V((math.sin(a), 0, math.cos(a)))
            p, n = scast(V((0, y, 1.96)) + dv * 2.0, -dv)
            pts.append(p + n * 0.05)
        add(_strap("muzzleband%d" % i, pts, 0.035, 0.035, brass, 5), "head")
    for sx in (-1, 1):
        for i, (x, y) in enumerate(((0.3, -1.32), (0.36, -1.62), (0.14, -1.86))):       # rebites do elmo
            p, n = htop(sx * x, y, 0.06)
            add(_stud("helmrivet%d_%d" % (sx, i), p, 0.04, brass), "head", True)
        # guarda da bochecha
        add(ck.blade("cheekguard%d" % sx, (sx * 0.47, -1.5, 2.1), (sx * 0.43, -1.84, 1.62), 0.34, 0.05, iron, (0, 1, 0.4), 0.4), "head", True)
        add(_stud("cheekrivet%d" % sx, (sx * 0.5, -1.6, 1.96), 0.04, brass), "head", True)
        # runa fixa na testa, de cada lado da crista
        p, n = htop(sx * 0.2, -1.5, 0.0)
        add(_iw_rune("helmrune%d" % sx, p, n, (0, -1, 0), 0.2, "ur" if sx > 0 else "tyr", 0.022, rune, None, 0.07), "head")
    # crista de lâminas do focinho à nuca, com filete de latão
    crest = ((-2.14, 0.1), (-1.9, 0.17), (-1.66, 0.32), (-1.42, 0.46), (-1.2, 0.38))
    roots = []
    for i, (y, hgt) in enumerate(crest):
        p, n = htop(0, y, 0.0)
        roots.append(p + V((0, 0, 0.03)))
        add(ck.blade("crest%d" % i, p - V((0, 0, 0.04)), p + V((0, 0.16, hgt)), 0.27, 0.07, steel, (0, 1, 0), 0.38), "head", True)
    add(_strap("crestridge", roots, 0.045, 0.045, brass, 5), "head")
    # olhos azul-gelo, fundos sob a aba do elmo
    for sx, e, n in eyes:
        add(_stud("socket%d" % sx, e - n * 0.02, 0.1, black, (0.8, 1.1, 0.9), 2), "head")
        add(_stud("eye%d" % sx, e + n * 0.035 + V((0, -0.01, 0)), 0.068, eye, (0.8, 1.15, 0.8), 2), "head")
        add(_stud("brow%d" % sx, e + n * 0.03 + V((0, 0.0, 0.1)), 0.12, iron2, (0.7, 1.6, 0.4), 2), "head", True)
    p, n = scast((0, -4, 1.97), (0, 1, 0))
    add(_stud("nose", p + V((0, 0.02, 0.02)), 0.095, black, (1.2, 0.9, 0.85), 2), "head")
    # orelhas saindo do elmo: a +X inteira, a -X rasgada em duas pontas
    add(mk.cone("ear1", (0.27, -1.3, 2.3), (0.44, -1.2, 2.9), 0.16, fur, 6), "head")
    add(mk.cone("ear1in", (0.275, -1.35, 2.34), (0.42, -1.25, 2.78), 0.09, dark, 5), "head")
    add(mk.cone("ear-1a", (-0.27, -1.3, 2.3), (-0.38, -1.24, 2.7), 0.15, fur, 6), "head")
    add(mk.cone("ear-1b", (-0.3, -1.22, 2.3), (-0.5, -1.1, 2.62), 0.1, fur, 5), "head")
    for sx in (-1, 1):                                       # aro de latão na base da orelha
        add(ck.tube("earband%d" % sx, (sx * 0.28, -1.3, 2.34), (sx * 0.3, -1.29, 2.42), 0.165, 0.15, brass, 6), "head")
        for j in range(3):                                   # costeletas brancas
            a = V((sx * 0.36, -1.36 + 0.06 * j, 1.92 - 0.1 * j))
            add(fluff("cheek%d_%d" % (sx, j), a, a + V((sx * (0.4 - 0.07 * j), 0.28 + 0.05 * j, -0.06 - 0.18 * j)), 0.18, mane), "head")
        # presas de cima e dentes de lado
        add(mk.cone("fang%d" % sx, (sx * 0.15, -2.3, 1.84), (sx * 0.165, -2.34, 1.57), 0.062, fang, 6), "head")
        for j, y in enumerate((-2.1, -1.94)):
            add(mk.cone("tooth%d_%d" % (sx, j), (sx * 0.2, y, 1.82), (sx * 0.21, y - 0.01, 1.68), 0.04, fang, 4), "head", True)
    add(mk.blob("palate", 0.17, (0, -2.02, 1.81), mouth, (1.1, 1.9, 0.25), 2), "head")
    # mandíbula (osso jaw, X- abre)
    jaw = mk.skin_body("jawbone", [((0, -1.55, 1.74), 0.19), ((0, -1.95, 1.71), 0.17), ((0, -2.27, 1.72), 0.13)], [(0, 1), (1, 2)], light, sub=1)
    add(_sq(jaw, (0, -1.9, 1.72), (1.2, 1, 0.6)), "jaw")
    add(mk.blob("tongue", 0.14, (0, -2.0, 1.8), mouth, (0.9, 1.9, 0.25), 2), "jaw")
    for sx in (-1, 1):
        add(mk.cone("jawfang%d" % sx, (sx * 0.1, -2.2, 1.76), (sx * 0.105, -2.22, 1.98), 0.048, fang, 5), "jaw")
    add(_lock("chin", (0, -1.8, 1.66), (0, -1.62, 1.4), 0.11, mane2), "jaw")
    for o, _b in parts[n_head:]:
        for v in o.data.vertices:
            v.co = hs(v.co)

    # ---------------- pernas: dobra do jarrete, patas grandes, garras com ponteira de ferro ----------------
    for bone_, sx, front in (("leg_fr", 1, True), ("leg_fl", -1, True), ("leg_br", 1, False), ("leg_bl", -1, False)):
        if front:
            x, py = sx * 0.43, -0.64
            add(mk.blob("shoulder_" + bone_, 0.3, (x, -0.55, 1.3), fur, (0.75, 1.0, 1.3), 2), bone_)
            add(ck.tube("upper_" + bone_, (x, -0.55, 1.25), (x, -0.47, 0.74), 0.21, 0.17, fur, 8), bone_)
            add(_stud("elbow_" + bone_, (x, -0.47, 0.76), 0.175, fur, sub=2), bone_)
            add(ck.tube("lower_" + bone_, (x, -0.47, 0.78), (x, -0.56, 0.15), 0.16, 0.13, fur, 8), bone_)
            add(_lock("feather_" + bone_, (x, -0.38, 0.84), (x, -0.16, 0.62), 0.11, mane2), bone_)
            # braçadeira de ferro com filetes de latão e um aro de brasa
            add(ck.tube("bracer_" + bone_, (x, -0.495, 0.64), (x, -0.545, 0.3), 0.195, 0.165, iron, 8), bone_, True)
            add(ck.tube("bracera_" + bone_, (x, -0.49, 0.67), (x, -0.497, 0.61), 0.21, 0.205, brass, 8), bone_)
            add(ck.tube("bracerb_" + bone_, (x, -0.54, 0.33), (x, -0.547, 0.28), 0.18, 0.175, brass, 8), bone_)
            add(ck.tube("bracerrune_" + bone_, (x, -0.515, 0.5), (x, -0.521, 0.455), 0.19, 0.186, rune, 8), bone_)
        else:
            x, py = sx * 0.41, 0.82
            add(mk.blob("haunch_" + bone_, 0.36, (x - sx * 0.03, 0.86, 1.28), fur, (0.72, 1.1, 1.25), 2), bone_)
            add(ck.tube("thigh_" + bone_, (x, 0.84, 1.2), (x, 0.62, 0.78), 0.22, 0.16, fur, 8), bone_)
            add(_stud("knee_" + bone_, (x, 0.62, 0.79), 0.165, fur, sub=2), bone_)
            add(ck.tube("shank_" + bone_, (x, 0.62, 0.8), (x, 1.0, 0.46), 0.15, 0.12, fur, 8), bone_)
            add(_stud("hock_" + bone_, (x, 1.0, 0.46), 0.125, fur, sub=2), bone_)
            add(ck.tube("meta_" + bone_, (x, 1.0, 0.48), (x, 0.9, 0.12), 0.12, 0.115, fur, 8), bone_)
            # chapa da anca com rebites e uma runa fixa
            pc = (x + sx * 0.1, 0.86, 1.36)
            plate = mk.blob("hipplate_" + bone_, 0.3, pc, iron2, (0.52, 0.98, 0.92), 2)
            add(plate, bone_, True)
            hcast_ = _caster(plate)
            h, hn = hcast_((sx * 3, 0.86, 1.36), (-sx, 0, 0))
            add(_iw_rune("hiprune_" + bone_, h, hn, (0, 0, 1), 0.26, "odal" if sx > 0 else "ur", 0.022, rune, hcast_, 0.012), bone_)
            for j, (dy, dz) in enumerate(((-0.2, 0.14), (0.2, 0.14), (-0.2, -0.14), (0.2, -0.14))):
                h, hn = hcast_((sx * 3, 0.86 + dy, 1.36 + dz), (-sx, 0, 0))
                add(_stud("hiprivet%d_%s" % (j, bone_), h + hn * 0.01, 0.036, brass), bone_, True)
        add(mk.blob("paw_" + bone_, 0.19, (x, py, 0.112), dark, (1.0, 1.35, 0.58), 2), bone_)
        for j, a in enumerate((-0.6, 0.0, 0.6)):             # garras: ponteira de ferro e ponta de aço
            c = V((x + math.sin(a) * 0.15, py - 0.15 - math.cos(a) * 0.08, 0.1))
            tip = c + V((math.sin(a) * 0.06, -0.17, -0.098))
            add(ck.tube("clawcap%d_%s" % (j, bone_), c + V((0, 0.05, 0.01)), c.lerp(tip, 0.4), 0.06, 0.05, iron2, 5), bone_, True)
            add(mk.cone("claw%d_%s" % (j, bone_), c.lerp(tip, 0.3), tip, 0.048, steel, 5), bone_, True)

    # ---------------- rabo cheio, em dois ossos, com aro de ferro ----------------
    tp1 = [((0, 1.18, 1.5), 0.2), ((0, 1.55, 1.58), 0.29), ((0, 1.95, 1.6), 0.36)]
    tp2 = [((0, 1.84, 1.6), 0.35), ((0, 2.22, 1.54), 0.4), ((0, 2.6, 1.42), 0.32), ((0, 2.92, 1.28), 0.14)]
    add(mk.skin_body("brush1", tp1, [(0, 1), (1, 2)], fur, sub=1), "tail")
    add(mk.skin_body("brush2", tp2, [(0, 1), (1, 2), (2, 3)], fur, sub=1), "tail2")
    for i, (y, zz, r_) in enumerate(((1.95, 1.6, 0.36), (2.25, 1.54, 0.4), (2.55, 1.44, 0.33))):        # tufos em volta
        for j in range(5):
            a = math.tau * (j + 0.5 * i) / 5
            d = V((math.cos(a), 0, math.sin(a)))
            b0 = V((0, y, zz)) + d * (r_ * 0.62)
            add(fluff("brushlock%d_%d" % (i, j), b0, b0 + d * (r_ * 0.6) + V((0, 0.42, -0.05)), 0.17, dark if i < 2 else mane), "tail2")
    add(fluff("brushtip", (0, 2.66, 1.38), (0, 3.16, 1.1), 0.27, mane), "tail2")
    rc = V((0, 1.5, 1.57))
    add(_ring("tailring", rc, (0, 1, 0.12), 0.33, 0.065, iron, 10, 5), "tail", True)
    for j in range(4):
        a = math.tau * (j + 0.5) / 4
        add(_stud("tailstud%d" % j, rc + V((math.cos(a) * 0.39, 0, math.sin(a) * 0.39)), 0.045, brass), "tail", True)
    add(_ring("taillink", rc + V((0, 0, -0.45)), (1, 0, 0), 0.08, 0.026, iron2, 6, 4), "tail", True)

    objs = [o for o, _b in parts]
    for o in objs:
        if o.name not in flat:
            ck._smooth(o.data)
    _outward(objs)
    for o in objs:
        for v in o.data.vertices:
            v.co *= K
    by_bone = {}
    for o, bone_ in parts:
        by_bone.setdefault(bone_, []).append(o)
    for bone_, objs_ in by_bone.items():
        lp.attach(ck._join(objs_, "iw_" + bone_), arm, bone_)
    _iw_clips(arm, K)
    legs = ("leg_fr", "leg_fl", "leg_br", "leg_bl")
    live = [c for c in IW_CLIPS if c != "die"]
    _tail_ground(arm, live, ("tail", "tail2"))
    _ground(arm, live, legs, IW_TUCK * K, heads=("head", "jaw"))
    _ground(arm, ["die"], (), 0.0, DIE_SINK, head=False)
    return arm


def _iw_clips(arm, K):
    """Mesmos eixos do javali (ver `_boar_clips`): corpo X+ = focinho desce, gira em volta da anca; cabeça X+ = abaixa, X- = ergue
    (uivo), Z = vira; mandíbula X- = ABRE; rabo/rabo2 X+ = sobe, Z = abana. `chain` (corrente solta, filha do corpo): X = balança
    para a frente/trás, Z = para os lados. `flare` (runas grandes) só muda de ESCALA: IW_FLARE_REST = escondidas dentro das chapas,
    1,0 = acesas. Toda chave leva escala (`_eclip`)."""
    z = (0, 0, 0)
    r = lambda x=0.0, y=0.0, zz=0.0: (x, y, zz)
    p = lambda up=0.0, fwd=0.0: (0, up * K, fwd * K)
    jw = lambda seq: [(f, (-a, 0, 0), z) for f, a in seq]           # graus de boca ABERTA
    ch = lambda seq: [(f, (a, 0, b_), z) for f, a, b_ in seq]       # corrente: (quadro, frente/trás, lado)
    fl = lambda seq: [(f, z, z, (s, s, s)) for f, s in seq]         # runas grandes: (quadro, escala)
    F0 = IW_FLARE_REST
    tau = math.tau
    sin, cos = math.sin, math.cos
    legs = ("leg_fr", "leg_fl", "leg_br", "leg_bl")

    def clip(name, keys, end, loop=False):
        if "flare" not in keys:
            keys["flare"] = fl([(1, F0), (end, F0)])
        _eclip(arm, name, keys, end, loop)

    def lin(seq, f):
        if f <= seq[0][0]:
            return seq[0][1]
        for a, b_ in zip(seq, seq[1:]):
            if a[0] <= f <= b_[0]:
                return a[1] + (b_[1] - a[1]) * (f - a[0]) / float(b_[0] - a[0])
        return seq[-1][1]

    def planted(body, extra=None, drop=None):
        """patas que seguem o corpo (bg.plant); drop = [(quadro, quanto)] estica as patas da FRENTE para baixo (corpo empinado no uivo)"""
        k = {g: bg.plant(body, g, (extra or {}).get(g, ())) for g in legs}
        if drop:
            for g in ("leg_fr", "leg_fl"):
                fr = sorted({q[0] for q in k[g]} | {q[0] for q in drop})
                k[g] = [(f, bg._at(k[g], f, 1), tuple(a + b_ for a, b_ in zip(bg._at(k[g], f, 2), (0, lin(drop, f) * K, 0)))) for f in fr]
        return k

    def shake(f0, f1, amp, base=0.0):
        return [(f, base + amp * (0.5 if i % 2 else -0.5), amp * (1 if i % 2 else -1)) for i, f in enumerate(range(f0, f1 + 1, 2))]

    # ---- idle: respira, ofega de boca entreaberta, olha de um lado para o outro, abana o rabo devagar ----
    n = 48
    k = {b_: [] for b_ in ("body", "head", "jaw", "tail", "tail2", "leg_fr", "leg_fl", "chain")}
    for f in list(range(1, n, 3)) + [n]:
        a = (f - 1) / (n - 1) * tau
        k["body"].append((f, r(1.5 * sin(a)), p(0.025 * (0.5 - 0.5 * cos(a)))))
        k["head"].append((f, r(3 + 3 * sin(a + 0.6), 0, 7 * sin(a)), z))
        k["jaw"].append((f, r(-4 - 3 * sin(2 * a)), z))
        k["tail"].append((f, r(-6 + 4 * sin(a), 0, 12 * sin(2 * a)), z))
        k["tail2"].append((f, r(-4, 0, 16 * sin(2 * a - 0.9)), z))
        k["leg_fr"].append((f, r(-1.5 * sin(a)), z))
        k["leg_fl"].append((f, r(-1.5 * sin(a)), z))
        k["chain"].append((f, r(3 * sin(a + 1.0), 0, 4 * sin(2 * a)), z))
    clip("idle", k, n, loop=True)

    # ---- run: galope de lobo, corpo ondulando, rabo estendido, corrente para trás ----
    n = 16
    k = {b_: [] for b_ in ("body", "head", "jaw", "tail", "tail2", "chain") + legs}
    for f in range(1, n + 1):
        a = (f - 1) / (n - 1) * tau
        k["body"].append((f, r(-6 * cos(a), 0, 2 * sin(a)), p(0.1 * (0.5 + 0.5 * sin(a)))))
        k["head"].append((f, r(5 * cos(a) + 6, 0, -2 * sin(a)), z))
        k["jaw"].append((f, r(-10 - 6 * sin(a)), z))
        k["leg_fr"].append((f, r(-36 * sin(a) + 6 * cos(a)), z))
        k["leg_fl"].append((f, r(-36 * sin(a - 0.45) + 6 * cos(a)), z))
        k["leg_br"].append((f, r(34 * sin(a + 0.3) + 6 * cos(a)), z))
        k["leg_bl"].append((f, r(34 * sin(a - 0.15) + 6 * cos(a)), z))
        k["tail"].append((f, r(10 + 8 * sin(a - 1.2), 0, 5 * sin(a + 0.6)), z))
        k["tail2"].append((f, r(6 + 10 * sin(a - 2.0), 0, 6 * sin(a)), z))
        k["chain"].append((f, r(12 + 8 * sin(a - 1.0), 0, 6 * sin(a + 0.4)), z))
    clip("run", k, n, loop=True)

    # ---- attack (5): recolhe de boca aberta e fecha a mordida para a frente ----
    e = 16
    clip("attack", {
        "body": [(1, z, z), (3, r(4), p(-0.04, -0.14)), (5, r(2), p(0.0, 0.34)), (8, r(1), p(0, 0.24)), (12, z, p(0, 0.06)), (e, z, z)],
        "head": [(1, z, z), (3, r(-16, 0, 5), z), (4, r(-10), z), (5, r(12, 0, -3), z), (8, r(6), z), (12, r(1), z), (e, z, z)],
        "jaw": jw([(1, 0), (3, 38), (4, 46), (5, 4), (7, 0), (e, 0)]),
        "leg_fr": [(1, z, z), (3, r(10), z), (5, r(-24), z), (8, r(-16), z), (12, r(-4), z), (e, z, z)],
        "leg_fl": [(1, z, z), (3, r(8), z), (5, r(-18), z), (8, r(-12), z), (12, r(-3), z), (e, z, z)],
        "leg_br": [(1, z, z), (3, r(-12), z), (5, r(26), z), (8, r(18), z), (12, r(4), z), (e, z, z)],
        "leg_bl": [(1, z, z), (3, r(-12), z), (5, r(22), z), (8, r(15), z), (12, r(3), z), (e, z, z)],
        "tail": [(1, z, z), (3, r(14), z), (5, r(-10), z), (9, r(6, 0, 10), z), (e, z, z)],
        "tail2": [(1, z, z), (3, r(10), z), (5, r(-14), z), (9, r(8, 0, 14), z), (e, z, z)],
        "chain": ch([(1, 0, 0), (3, -8, 0), (5, 14, 3), (8, -6, -3), (11, 3, 2), (e, 0, 0)]),
    }, e)

    # ---- hit: tranco para trás, cabeça vira, ganido ----
    body = [(1, z, z), (2, r(-5, 0, 4), p(0.01, -0.09)), (5, r(3, 0, -2), p(0, -0.04)), (7, r(-1), p(0, -0.012)), (10, z, z)]
    k = planted(body, {"leg_fr": [(2, -10), (5, 4)], "leg_fl": [(2, -7), (5, 3)], "leg_br": [(2, 8), (5, -3)], "leg_bl": [(2, 6), (5, -3)]})
    k.update({"body": body, "head": [(1, z, z), (2, r(-16, 0, 16), z), (5, r(8, 0, -7), z), (7, r(-2), z), (10, z, z)],
              "jaw": jw([(1, 0), (2, 26), (5, 8), (10, 0)]),
              "tail": [(1, z, z), (2, r(-20), z), (5, r(-10, 0, 8), z), (10, z, z)],
              "tail2": [(1, z, z), (2, r(-24), z), (5, r(-14, 0, 12), z), (10, z, z)],
              "chain": ch([(1, 0, 0), (2, -14, -8), (4, 9, 6), (6, -5, -4), (8, 2, 2), (10, 0, 0)])})
    clip("hit", k, 10)

    # ---- atk_charge (5): recua, dispara de boca aberta, crava a mordida e corre sacudindo a presa ----
    e = 20
    clip("atk_charge", {
        "body": [(1, z, z), (3, r(6), p(-0.06, -0.22)), (5, r(-2), p(0.06, 0.52)), (7, r(3), p(0.02, 0.6)), (9, r(-3), p(0.05, 0.56)), (11, r(4), p(0.01, 0.44)),
                 (14, r(1), p(0, 0.2)), (17, z, p(0, 0.04)), (e, z, z)],
        "head": [(1, z, z), (3, r(-12), z), (4, r(-18), z), (5, r(8), z), (7, r(14, 0, 12), z), (9, r(10, 0, -14), z), (11, r(12, 0, 9), z), (14, r(4), z), (e, z, z)],
        "jaw": jw([(1, 0), (3, 30), (4, 50), (5, 6), (7, 2), (9, 4), (11, 2), (e, 0)]),
        "leg_fr": [(1, z, z), (3, r(16), z), (5, r(-48), z), (7, r(10), z), (9, r(-30), z), (11, r(6), z), (14, r(2), z), (e, z, z)],
        "leg_fl": [(1, z, z), (3, r(12), z), (5, r(-40), z), (7, r(-20), z), (9, r(12), z), (11, r(-14), z), (14, z, z), (e, z, z)],
        "leg_br": [(1, z, z), (3, r(-26), z), (5, r(42), z), (7, r(-10), z), (9, r(30), z), (11, r(-4), z), (14, r(-2), z), (e, z, z)],
        "leg_bl": [(1, z, z), (3, r(-26), z), (5, r(36), z), (7, r(20), z), (9, r(-8), z), (11, r(14), z), (14, z, z), (e, z, z)],
        "tail": [(1, z, z), (3, r(24), z), (5, r(30), z), (9, r(22, 0, 8), z), (12, r(10, 0, -8), z), (16, r(3), z), (e, z, z)],
        "tail2": [(1, z, z), (3, r(14), z), (5, r(24), z), (9, r(20, 0, 12), z), (12, r(12, 0, -12), z), (16, r(4), z), (e, z, z)],
        "chain": ch([(1, 0, 0), (3, -10, 0), (5, 22, 3), (8, 16, -4), (11, -8, 4), (14, 4, -2), (17, 0, 0), (e, 0, 0)]),
    }, e)

    # ---- slam (8): agacha, salta e desaba nas duas patas da frente; a garupa chega depois ----
    e = 24
    clip("slam", {
        "body": [(1, z, z), (3, r(8), p(-0.1, -0.06)), (5, r(-24), p(0.34, 0.1)), (6, r(-16), p(0.46, 0.2)), (7, r(4), p(0.26, 0.28)), (8, r(14), p(-0.06, 0.32)),
                 (10, r(9), p(-0.02, 0.3)), (12, r(11), p(-0.05, 0.28)), (15, r(4), p(-0.01, 0.16)), (20, r(-1), p(0, 0.03)), (e, z, z)],
        "head": [(1, z, z), (3, r(10), z), (5, r(-20), z), (6, r(-10), z), (8, r(18), z), (10, r(4, 0, 5), z), (12, r(8, 0, -4), z), (16, r(2), z), (e, z, z)],
        "jaw": jw([(1, 0), (3, 6), (5, 30), (6, 36), (8, 8), (10, 22), (12, 10), (e, 0)]),
        "leg_fr": [(1, z, z), (3, r(10), z), (5, r(-50), z), (6, r(-58), z), (7, r(-34), z), (8, r(-22), z), (10, r(-13), z), (12, r(-13), z), (15, r(-4), z), (e, z, z)],
        "leg_fl": [(1, z, z), (3, r(10), z), (5, r(-42), z), (6, r(-52), z), (7, r(-30), z), (8, r(-22), z), (10, r(-13), z), (12, r(-13), z), (15, r(-4), z), (e, z, z)],
        "leg_br": [(1, z, z), (3, r(-16), z), (5, r(40), z), (6, r(44), z), (7, r(24), z), (8, r(4), z), (10, r(-9), z), (12, r(-11), z), (15, r(-4), z), (e, z, z)],
        "leg_bl": [(1, z, z), (3, r(-16), z), (5, r(36), z), (6, r(40), z), (7, r(20), z), (8, r(2), z), (10, r(-9), z), (12, r(-11), z), (15, r(-4), z), (e, z, z)],
        "tail": [(1, z, z), (3, r(-10), z), (5, r(30), z), (6, r(40), z), (8, r(-16), z), (12, r(8, 0, 10), z), (16, r(2, 0, -6), z), (e, z, z)],
        "tail2": [(1, z, z), (3, r(-8), z), (5, r(18), z), (6, r(32), z), (8, r(-24), z), (10, r(-10), z), (12, r(10, 0, 12), z), (16, r(2, 0, -8), z), (e, z, z)],
        "chain": ch([(1, 0, 0), (3, 4, 0), (5, -16, 0), (6, -10, 2), (8, 24, -3), (10, -12, 4), (12, 8, -3), (15, -4, 2), (20, 1, 0), (e, 0, 0)]),
    }, e)

    # ---- roar / shout (7): uivo, focinho para o céu; as runas grandes começam a aparecer ----
    e = 24
    body = [(1, z, z), (4, r(6), p(-0.05, -0.04)), (7, r(-8), p(-0.05, -0.03)), (9, r(-9, 0, 2), p(-0.05, -0.03)), (11, r(-8, 0, -2), p(-0.05, -0.03)),
            (13, r(-9, 0, 2), p(-0.05, -0.03)), (16, r(-6), p(-0.03, -0.01)), (20, r(1), z), (e, z, z)]
    k = planted(body, {"leg_fr": [(4, 0, 3), (7, -4, 8), (16, -4, 8), (20, 0, 2)], "leg_fl": [(4, 0, 3), (7, -4, 8), (16, -4, 8), (20, 0, 2)]},
                drop=[(1, 0), (4, 0), (7, 0.12), (16, 0.1), (20, 0), (e, 0)])
    k.update({"body": body,
              "head": [(1, z, z), (4, r(20), z), (6, r(-28), z), (7, r(-58, 0, 4), z), (9, r(-62, 0, -4), z), (11, r(-60, 0, 5), z), (13, r(-62, 0, -4), z),
                       (16, r(-46), z), (20, r(4), z), (e, z, z)],
              "jaw": jw([(1, 0), (4, 0), (6, 20), (7, 30), (9, 34), (11, 28), (13, 34), (16, 24), (20, 4), (e, 0)]),
              "tail": [(1, z, z), (4, r(-8), z), (7, r(30, 0, 8), z), (11, r(34, 0, -8), z), (13, r(32, 0, 6), z), (17, r(12), z), (e, z, z)],
              "tail2": [(1, z, z), (4, r(-6), z), (7, r(18), z), (11, r(24, 0, -12), z), (13, r(22, 0, 10), z), (17, r(8), z), (e, z, z)],
              "chain": ch([(1, 0, 0), (4, -4, 0)] + shake(7, 17, 8) + [(20, 2, -2), (e, 0, 0)]),
              "flare": fl([(1, F0), (6, F0), (8, 0.9), (13, 0.9), (18, F0), (e, F0)])})
    for name in ("roar", "shout"):
        clip(name, {b_: list(v) for b_, v in k.items()}, e)

    # ---- maul (7): ergue a pata da frente (+X) e rasga de lado, cruzando a frente ----
    e = 18
    body = [(1, z, z), (3, r(-4, -6), p(0.03, -0.05)), (5, r(-9, -12), p(0.05, -0.08)), (7, r(5, 12), p(-0.03, 0.14)), (9, r(6, 16), p(-0.04, 0.12)),
            (12, r(1, 6), p(0, 0.04)), (e, z, z)]
    k = planted(body, {"leg_fr": [(3, -30, 12), (5, -72, 30), (7, -40, -16), (9, -22, -20), (12, -6, -4)], "leg_fl": [(5, 4), (7, -8), (9, -6)],
                       "leg_br": [(5, -6), (7, 12), (9, 8)], "leg_bl": [(5, -6), (7, 10), (9, 6)]})
    k.update({"body": body,
              "head": [(1, z, z), (3, r(-6, 0, -10), z), (5, r(-10, 0, -16), z), (7, r(10, 0, 14), z), (9, r(8, 0, 18), z), (12, r(2, 0, 5), z), (e, z, z)],
              "jaw": jw([(1, 0), (5, 24), (7, 34), (9, 16), (e, 0)]),
              "tail": [(1, z, z), (5, r(12, 0, -18), z), (7, r(-6, 0, 22), z), (11, r(6, 0, -8), z), (e, z, z)],
              "tail2": [(1, z, z), (5, r(8, 0, -14), z), (7, r(0, 0, -6), z), (9, r(-6, 0, 24), z), (13, r(4, 0, -8), z), (e, z, z)],
              "chain": ch([(1, 0, 0), (5, -6, 8), (7, 10, -14), (9, -4, 10), (12, 2, -5), (15, 0, 2), (e, 0, 0)])})
    clip("maul", k, e)

    # ---- pounce (9): agacha, salta esticado de boca aberta e fecha a mordida ao cair ----
    e = 20
    clip("pounce", {
        "body": [(1, z, z), (3, r(6), p(-0.08, -0.1)), (5, r(10), p(-0.14, -0.18)), (7, r(-16), p(0.4, 0.3)), (8, r(-6), p(0.4, 0.5)), (9, r(10), p(0.02, 0.62)),
                 (11, r(7), p(-0.03, 0.5)), (13, r(4), p(-0.02, 0.3)), (17, r(-1), p(0, 0.06)), (e, z, z)],
        "head": [(1, z, z), (5, r(12), z), (7, r(-18), z), (8, r(-14), z), (9, r(14), z), (11, r(10, 0, 8), z), (13, r(6, 0, -6), z), (16, r(2), z), (e, z, z)],
        "jaw": jw([(1, 0), (5, 4), (7, 44), (8, 50), (9, 4), (11, 2), (e, 0)]),
        "leg_fr": [(1, z, z), (5, r(20), z), (7, r(-58), z), (8, r(-46), z), (9, r(-14), z), (11, r(-9), z), (13, r(-5), z), (e, z, z)],
        "leg_fl": [(1, z, z), (5, r(20), z), (7, r(-50), z), (8, r(-40), z), (9, r(-14), z), (11, r(-9), z), (13, r(-5), z), (e, z, z)],
        "leg_br": [(1, z, z), (5, r(-30), z), (7, r(48), z), (8, r(42), z), (9, r(-8), z), (11, r(-7), z), (13, r(-4), z), (e, z, z)],
        "leg_bl": [(1, z, z), (5, r(-30), z), (7, r(42), z), (8, r(36), z), (9, r(-8), z), (11, r(-7), z), (13, r(-4), z), (e, z, z)],
        "tail": [(1, z, z), (5, r(-12), z), (7, r(26), z), (9, r(-14), z), (13, r(6, 0, 8), z), (e, z, z)],
        "tail2": [(1, z, z), (5, r(-10), z), (7, r(16), z), (8, r(24), z), (9, r(-20), z), (13, r(8, 0, 12), z), (e, z, z)],
        "chain": ch([(1, 0, 0), (5, 6, 0), (7, -18, 0), (9, 22, 3), (11, -10, -3), (13, 6, 2), (17, -2, 0), (e, 0, 0)]),
    }, e)

    # ---- brace (6): crava as patas abertas, abaixa o corpo e a cabeça, rosna ----
    e = 18
    body = [(1, z, z), (3, r(-3), p(0.02)), (6, r(7), p(-0.14, 0.04)), (9, r(6), p(-0.12, 0.04)), (12, r(7), p(-0.14, 0.04)), (15, r(2), p(-0.03, 0.01)), (e, z, z)]
    spread = [(6, 0, 10), (12, 0, 10)]
    k = planted(body, {g: spread for g in legs})
    k.update({"body": body, "head": [(1, z, z), (3, r(-8), z), (6, r(10), z), (9, r(8, 0, 4), z), (12, r(10, 0, -4), z), (15, r(4), z), (e, z, z)],
              "jaw": jw([(1, 0), (6, 14), (9, 10), (12, 14), (e, 0)]),
              "tail": [(1, z, z), (6, r(-16), z), (12, r(-14), z), (e, z, z)],
              "tail2": [(1, z, z), (6, r(-14), z), (12, r(-12, 0, 6), z), (e, z, z)],
              "chain": ch([(1, 0, 0), (3, 4, 0), (6, -8, 2), (9, -3, -2), (12, -6, 1), (15, -1, 0), (e, 0, 0)])})
    clip("brace", k, e)

    # ---- cast_ground (10): abaixa e inspira, joga o focinho para o céu e uiva longo chamando a matilha; as runas acendem ----
    e = 24
    body = [(1, z, z), (3, r(8), p(-0.1, 0.0)), (6, r(10), p(-0.14, 0.02)), (8, r(-5), p(-0.06, -0.03)), (10, r(-11), p(-0.07, -0.05)), (12, r(-10, 0, 2), p(-0.07, -0.05)),
            (14, r(-11, 0, -2), p(-0.07, -0.05)), (16, r(-10, 0, 2), p(-0.07, -0.05)), (19, r(-4), p(-0.03, -0.02)), (e, z, z)]
    front = [(8, -3, 4), (10, -5, 10), (16, -5, 10), (19, -2, 3)]
    k = planted(body, {"leg_fr": front, "leg_fl": front, "leg_br": [(10, 0, 5), (16, 0, 5)], "leg_bl": [(10, 0, 5), (16, 0, 5)]},
                drop=[(1, 0), (8, 0.04), (10, 0.16), (16, 0.15), (19, 0.04), (e, 0)])
    k.update({"body": body,
              "head": [(1, z, z), (3, r(20, 0, 6), z), (6, r(26, 0, -6), z), (8, r(-20), z), (10, r(-62), z), (12, r(-64, 0, 5), z), (14, r(-62, 0, -5), z),
                       (16, r(-64, 0, 4), z), (19, r(-20), z), (e, z, z)],
              "jaw": jw([(1, 0), (3, 6), (6, 10), (8, 20), (10, 34), (12, 30), (14, 36), (16, 30), (19, 10), (e, 0)]),
              "tail": [(1, z, z), (3, r(-10), z), (6, r(-14), z), (8, r(20), z), (10, r(40), z), (13, r(42, 0, 8), z), (16, r(40, 0, -8), z), (20, r(10), z), (e, z, z)],
              "tail2": [(1, z, z), (3, r(-8), z), (6, r(-12), z), (8, r(8), z), (10, r(22), z), (13, r(26, 0, 12), z), (16, r(24, 0, -12), z), (20, r(8), z), (e, z, z)],
              "chain": ch([(1, 0, 0), (3, 4, 2), (6, 6, -2), (8, -8, 0)] + shake(10, 16, 9) + [(19, 2, -1), (e, 0, 0)]),
              "flare": fl([(1, F0), (6, 0.86), (8, 0.94), (10, 1.04), (12, 0.98), (14, 1.04), (16, 0.98), (19, 0.9), (e, F0)])})
    clip("cast_ground", k, e)

    # ---- die: cambaleia com o golpe, os joelhos da frente cedem, tomba de lado e quica; as runas se apagam ----
    s = 1.4
    f = lambda x: int(round(1 + (x - 1) * s))
    e = f(24)
    roll = IW_DIE_ROLL
    clip("die", {
        "body": [(1, z, z), (f(4), r(-9), p(0.02, -0.05)), (f(9), r(9), p(-0.06, 0.02)), (f(14), r(3), p(-0.02)), (e, r(3), p(-0.02))],
        "head": [(1, z, z), (f(4), r(-30, 0, 8), z), (f(9), r(22), z), (f(14), r(8, 0, 12), z), (f(17), r(0, 0, 7), z), (f(20), r(8, 0, 12), z), (e, r(8, 0, 12), z)],
        "jaw": jw([(1, 0), (f(4), 36), (f(9), 8), (f(14), 24), (e, 18)]),
        "leg_fr": [(1, z, z), (f(4), r(-16), z), (f(9), r(30), z), (f(14), r(-18), z), (f(17), r(-25), z), (e, r(-18), z)],
        "leg_fl": [(1, z, z), (f(4), r(-12), z), (f(9), r(26), z), (f(14), r(-9), z), (f(17), r(-14), z), (e, r(-9), z)],
        "leg_br": [(1, z, z), (f(4), r(8), z), (f(9), r(-16), z), (f(14), r(14), z), (f(17), r(21), z), (e, r(14), z)],
        "leg_bl": [(1, z, z), (f(4), r(8), z), (f(9), r(-16), z), (f(14), r(23), z), (f(17), r(28), z), (e, r(23), z)],
        "tail": [(1, z, z), (f(4), r(-18), z), (f(9), r(-22), z), (f(14), r(4, 0, 10), z), (f(17), r(8, 0, 16), z), (e, r(2, 0, 10), z)],
        "tail2": [(1, z, z), (f(4), r(-14), z), (f(9), r(-24), z), (f(14), r(-6, 0, 14), z), (f(17), r(6, 0, 22), z), (e, r(-4, 0, 16), z)],
        "chain": ch([(1, 0, 0), (f(4), -12, 0), (f(9), 14, 4), (f(14), -6, 20), (f(17), -3, 12), (f(20), -6, 24), (e, -6, 24)]),
        "flare": fl([(1, F0), (f(4), 0.92), (f(9), F0), (f(14), 0.7), (e, 0.5)]),
        "root": [(1, z, z), (f(9), z, z), (f(14), r(0, 0, roll), z), (f(17), r(0, 0, roll + 7), z), (f(20), r(0, 0, roll), z), (e, r(0, 0, roll), z)],
    }, e)


# ---------------------------------------------------------------------------
# Gamo de Porcelana da Festa (faixa 45-50, Lumeria)
# ---------------------------------------------------------------------------
PS_SIZE = 0.56             # unidades de desenho -> nativo: lombo ~1,05, cabeça ~1,75, ponta dos chifres ~2,3
PS_TUCK = 0.3
PS_SPINE = [((0, 0.9, 1.5), 0.27), ((0, 0.5, 1.52), 0.34), ((0, 0.0, 1.5), 0.34), ((0, -0.48, 1.54), 0.4), ((0, -0.8, 1.6), 0.32)]
PS_NECK = [((0, -0.72, 1.66), 0.27), ((0, -1.04, 2.08), 0.165), ((0, -1.0, 2.5), 0.125), ((0, -1.16, 2.86), 0.135)]
PS_HEAD = (0, -1.3, 2.92)
PS_AXIS_Z = 1.52           # eixo do tronco: os veios de ouro acesos (osso `seam`) entram/saem em volta dele
PS_SEAM_IN = 0.8           # em repouso o veio aceso fica recolhido dentro da porcelana (escala radial)
PS_FLARE = 1.3             # escala radial do osso `seam` com o veio todo para fora (1/PS_SEAM_IN + folga)
PS_HANG = 0.9              # quanto as lanternas desfazem a inclinação de corpo + cabeça (1 = sempre a prumo)
PS_CLIPS = ("idle", "run", "attack", "hit", "die", "atk_charge", "slam", "roar", "shout", "maul", "pounce", "brace", "cast_ground")
PS_IMPACT = {"attack": 5, "atk_charge": 5, "slam": 8, "roar": 7, "shout": 7, "maul": 7, "pounce": 9, "brace": 6, "cast_ground": 10}
PS_LANTERNS = ("lantern_a", "lantern_b", "lantern_c")
PS_GLOW = 1.0              # lanternas, lágrima e veios acesos (degraus de 0,25: EntityView.mob_glow)
PS_DIE_ROLL = -84
PS_DIE_HEAD = (24, 80, 0)

PS_PORC = (0.94, 0.92, 0.88)          # corpo: porcelana um tom abaixo do branco (o branco puro estoura no toon)
PS_PORC_D = (0.8, 0.82, 0.86)         # sombra fria da louça (barriga, parte de dentro das pernas)
PS_MASK = (0.99, 0.98, 0.96)
PS_INK = (0.2, 0.34, 0.74)            # azul-cobalto da pintura
PS_INK_L = (0.56, 0.7, 0.93)          # aguada azul
PS_BLACK = (0.1, 0.08, 0.12)          # olhos da máscara (lumeria_kit.INK)
PS_GOLD = (0.74, 0.5, 0.17)           # ouro velho (kintsugi, cascos)
PS_GOLD_L = (0.92, 0.7, 0.28)          # ouro claro (guizos, filigrana)
PS_ROSE = (0.9, 0.46, 0.56)           # seda da festa
PS_ROSE_D = (0.68, 0.28, 0.42)
PS_JADE = (0.56, 0.82, 0.74)
PS_GLASS = (0.74, 0.88, 0.95)
PS_LANT = (1.0, 0.7, 0.34)             # papel aceso (quente)
PS_LANT2 = (1.0, 0.5, 0.56)          # lanterninhas rosadas
PS_TEAR = (1.0, 0.45, 0.58)
PS_SEAM = (1.0, 0.66, 0.2)


def _ps_spiral(c, u, w, r0, r1, a0, a1, n):
    """Pontos de uma voluta em volta de c no plano (u, w): raio r0 -> r1, ângulo a0 -> a1 (graus)."""
    c, u, w = V(c), V(u).normalized(), V(w).normalized()
    out = []
    for i in range(n + 1):
        t = i / n
        a = math.radians(a0 + (a1 - a0) * t)
        out.append(c + (u * math.cos(a) + w * math.sin(a)) * (r0 + (r1 - r0) * t))
    return out


def _ps_taper(name, pts, r0, r1, material, segs=5):
    n = len(pts) - 1
    return _horn(name, pts, [r0 + (r1 - r0) * i / n for i in range(n + 1)], material, segs)


def _ps_lantern(name, hook, drop, s, paper, gold, silk, tassel=0.0, hoops=True, segs=8):
    """Lanterna de papel (meia-altura s) pendurada de `hook` por um fio de `drop`: bojo facetado aceso, tampas de ouro e borla de seda."""
    hook = V(hook)
    c = hook - V((0, 0, drop + s))
    zs = (-1.0, -0.62, 0.0, 0.62, 1.0)
    rs = (0.5, 0.88, 1.0, 0.88, 0.5)
    out = [_horn(name + "_paper", [c + V((0, 0, zz * s)) for zz in zs], [rr * s * 0.86 for rr in rs], paper, segs),
           ck.tube(name + "_cap", c + V((0, 0, s * 0.94)), c + V((0, 0, s * 1.16)), s * 0.5, s * 0.3, gold, 6),
           ck.tube(name + "_base", c - V((0, 0, s * 1.14)), c - V((0, 0, s * 0.94)), s * 0.34, s * 0.5, gold, 6),
           ck.tube(name + "_string", hook, c + V((0, 0, s * 1.1)), 0.012, 0.012, gold, 3)]
    for zz in ((-0.4, 0.4) if hoops else ()):      # aros finos do papel
        out.append(ck.tube("%s_hoop%d" % (name, zz > 0), c + V((0, 0, zz * s - 0.012)), c + V((0, 0, zz * s + 0.012)), s * 0.84, s * 0.84, gold, 8))
    if tassel > 0.0:
        t0 = c - V((0, 0, s * 1.1))
        out.append(ck.tube(name + "_tassel_k", t0, t0 - V((0, 0, tassel * 0.25)), 0.014, 0.014, gold, 3))
        out.append(ck.tube(name + "_tassel", t0 - V((0, 0, tassel * 0.2)), t0 - V((0, 0, tassel)), s * 0.1, s * 0.3, silk, 5))
    return out


def porcelain_stag(cid="mob_porcelain_stag"):
    """Gamo de Porcelana da Festa (Chefe de Mundo 45-50, Lumeria). Peças rígidas, uma malha por osso (`ps_<osso>`): rig de
    quadrúpede + `tail`, `antler` (filho da cabeça), `lantern_a/b/c` (filhos de `antler`: as três lanternas grandes de papel,
    balançam e acendem por escala) e `seam` (filho do corpo: os veios de kintsugi ACESOS, recolhidos dentro da louça em repouso;
    escala radial PS_FLARE os põe para fora no `slam`, `hit`, `die`...). Louça branca com pintura azul-cobalto, veios de ouro,
    máscara oval de festa com lágrima acesa (lumeria_kit.mask), chifres em lira com renda de ouro, fitas de seda e lanterninhas,
    manta e arreio de seda com guizos, espelho no peito, joelhos em esfera e cascos dourados.
    Clipes: PS_CLIPS (impactos em PS_IMPACT); `atk_charge` = investida com os chifres deitados, `slam` = empina e bate os cascos
    (veios acendem), `roar`/`shout` = sacode a cabeça em silêncio (lanternas voam), `cast_ground` = reverência (lanternas acendem),
    `maul` = varrida de chifres, `die` = tomba dura como estatueta. Nativo: 1,4 x 1,8 x 2,35 de altura; sugestão MonsterDef.scale 2,8-3,0."""
    import lumeria_kit as lk
    K = PS_SIZE
    S = lambda p: tuple(x * K for x in p)
    rnd = random.Random(77)
    hc = V(PS_HEAD)
    fd = V((0, -0.82, -0.57)).normalized()          # para onde aponta o focinho
    fn = V((0, -0.57, 0.82)).normalized()           # normal do rosto (para cima e para a frente): a máscara olha a câmera alta
    bones = mk.pivots(body=S((0, 0.8, 1.4)), head=S((0, -0.74, 1.68)),
                      leg_fr=S((0.26, -0.5, 1.4)), leg_fl=S((-0.26, -0.5, 1.4)),
                      leg_br=S((0.24, 0.78, 1.4)), leg_bl=S((-0.24, 0.78, 1.4)))
    # chifres (lira inclinada para trás): haste por P, mesma dos dois lados
    AP = lambda sx: [V((sx * 0.12, -1.2, 3.08)), V((sx * 0.46, -1.08, 3.38)), V((sx * 0.82, -0.92, 3.66)), V((sx * 0.96, -0.78, 3.98))]
    HOOK = {}                                       # ponto de onde cada lanterna grande pende
    for sx in (-1, 1):
        P = AP(sx)
        arm_pts = [P[2], P[2] + V((sx * 0.26, 0.0, 0.1))]
        c = arm_pts[1] + V((0, 0, -0.14))
        HOOK[sx] = _ps_spiral(c, (sx, 0, 0), (0, 0, 1), 0.14, 0.1, 90, -90, 6)[-1]
    GA, GB = AP(-1)[3] + V((0, 0.0, 0.06)), AP(1)[3] + V((0, 0.0, 0.06))
    gar = []
    for i in range(9):
        t = i / 8.0
        sag = 4 * t * (1 - t)
        gar.append(GA.lerp(GB, t) + V((0, 0.1 * sag, -0.34 * sag)))
    HOOK[0] = gar[4].copy()
    hd = V((0, -0.4, 0.2)).normalized() * 0.3       # mesma direção do osso `head`: os eixos das lanternas são os da cabeça
    th, ah, sp = S((0, 0.98, 1.62)), S((0, -1.2, 3.1)), S((0, 0.0, PS_AXIS_Z))
    extra = dict(tail=(th, (th[0], th[1] + 0.3, th[2] + 0.04), "body"),
                 antler=(ah, (ah[0], ah[1], ah[2] + 0.3), "head"),
                 seam=(sp, (sp[0], sp[1] + 0.3, sp[2]), "body"))
    for bone_, key in (("lantern_a", 1), ("lantern_b", -1), ("lantern_c", 0)):
        h = S(HOOK[key])
        extra[bone_] = (h, (h[0] + hd.x, h[1] + hd.y, h[2] + hd.z), "antler")
    arm = lp.make_armature("rig_" + cid, dict(bones, **extra))
    m = lambda n, col, rough=0.85, em=0.0: ck.mat("m_%s_%s" % (cid, n), col, rough, em)
    porc, porc2, maskm = m("porc", PS_PORC, 0.35), m("porc2", PS_PORC_D, 0.35), m("mask", PS_MASK, 0.3)
    ink, ink2, black = m("ink", PS_INK, 0.5), m("ink2", PS_INK_L, 0.5), m("black", PS_BLACK, 0.6)
    gold, gold2 = m("gold", PS_GOLD, 0.4), m("gold2", PS_GOLD_L, 0.35)
    rose, rose2, jade = m("silk", PS_ROSE, 0.7), m("silk2", PS_ROSE_D, 0.7), m("jade", PS_JADE, 0.7)
    glass = m("glass", PS_GLASS, 0.15, 0.4)
    paper = ck.mat("glow_%s_lantern" % cid, PS_LANT, 0.5, PS_GLOW)
    paper2 = ck.mat("glow_%s_lantern2" % cid, PS_LANT2, 0.5, PS_GLOW)
    tear = ck.mat("glow_%s_tear" % cid, PS_TEAR, 0.3, PS_GLOW)
    seamg = ck.mat("glow_%s_seam" % cid, PS_SEAM, 0.3, PS_GLOW)
    M = {"porc": maskm, "gold": gold, "ink": black, "glow": tear, "glass": glass}
    parts, flat = [], set()

    def add(o, bone_, faceted=False):
        for x in (o if isinstance(o, (list, tuple)) else [o]):
            parts.append((x, bone_))
            if faceted:
                flat.add(x.name)

    # ---------------- tronco esguio de louça ----------------
    body = mk.skin_body("body", PS_SPINE, [(i, i + 1) for i in range(len(PS_SPINE) - 1)], porc)
    add(body, "body")
    cast = _caster(body)

    def around(y, a_deg, lift=0.0):
        """ponto do tronco na fatia y, no ângulo a (0 = flanco +X, 90 = lombo, 180 = flanco -X, 270 = barriga)"""
        a = math.radians(a_deg)
        ax = V((0, y, PS_AXIS_Z))
        o = ax + V((math.cos(a), 0, math.sin(a))) * 3
        p, n = cast(o, ax - o)
        if p is None:
            n = V((math.cos(a), 0, math.sin(a)))
            p = ax + n * 0.34
        return p + n * lift, n

    def onto(q, n, lift=0.0):
        p, n2 = cast(V(q) + V(n) * 0.3, -V(n))
        return (p + n2 * lift, n2) if p is not None else (V(q), V(n))

    def dot(name, p, n, r_, material):
        return _stud(name, V(p) - V(n) * (r_ * 0.5), r_, material)

    def rosette(name, y, a_deg, r_, petals=5, mat_=None, core=None):
        """flor pintada: pétalas de tinta em volta de um miolo de ouro, rente à louça"""
        p, n = around(y, a_deg)
        _d, u, w = _perp(n)
        out = []
        for k_ in range(petals):
            a = math.tau * k_ / petals + 0.3
            q, qn = onto(p + (u * math.cos(a) + w * math.sin(a)) * r_, n)
            out.append(dot("%s_p%d" % (name, k_), q, qn, r_ * 0.62, mat_ or ink))
        out.append(dot(name + "_c", p + n * 0.012, n, r_ * 0.5, core or gold2))
        return out

    def crack(ctrl, seed):
        r2 = random.Random(seed)
        out = []
        for i in range(len(ctrl) - 1):
            (y0, a0), (y1, a1) = ctrl[i], ctrl[i + 1]
            for j in range(2):
                t = j / 2.0
                first = i == 0 and j == 0
                out.append((y0 + (y1 - y0) * t + (0 if first else r2.uniform(-0.035, 0.035)), a0 + (a1 - a0) * t + (0 if first else r2.uniform(-7, 7))))
        out.append(ctrl[-1])
        return out

    add(mk.blob("belly", 0.3, (0, -0.05, 1.3), porc2, (0.88, 2.4, 0.5), 2), "body")
    # garupa mergulhada em aguada azul, de borda recortada, com bolinhas brancas
    add(_shell("glaze", body, lambda c, n: c.y > 0.62 + 0.07 * math.sin(math.atan2(c.z - PS_AXIS_Z, c.x) * 6.0), 0.012, ink2), "body")
    for i, a_ in enumerate(range(-10, 200, 30)):                # filete escuro na borda da aguada
        p, n = around(0.58 + 0.07 * math.sin(math.radians(a_) * 6.0), a_)
        add(dot("glazerim%d" % i, p, n, 0.05, ink), "body", True)
    # flores e ramos pintados (azul-cobalto, miolo de ouro)
    for i, (y, a_, r_) in enumerate(((-0.62, 26, 0.11), (-0.62, 154, 0.11), (0.62, 40, 0.085), (0.62, 140, 0.085), (-0.56, 92, 0.085))):
        add(rosette("rose%d" % i, y, a_, r_), "body", True)
    for sx in (-1, 1):
        A = lambda a_: 90 - sx * (90 - a_)                      # espelha o ângulo
        vine = [around(y, A(a_), 0.004)[0] for y, a_ in ((-0.3, 16), (-0.16, 2), (0.0, 14), (0.14, 0), (0.28, 12), (0.42, -2), (0.52, 12))]
        add(_strap("vine%d" % sx, vine, 0.034, 0.026, ink, 4), "body")
        for i, (y, a_) in enumerate(((-0.16, -12), (0.0, 26), (0.14, -14), (0.28, 24), (0.42, -16))):
            p, n = around(y, A(a_))
            add(dot("leaf%d_%d" % (sx, i), p, n, 0.06, (ink2, ink)[i % 2]), "body", True)

    # ---------------- kintsugi: veios de ouro (fixos) e o mesmo veio aceso por baixo (osso seam) ----------------
    CRACKS = (([(-0.66, 14), (-0.52, 52), (-0.4, 78), (-0.34, 108), (-0.3, 140)], 3),
              ([(-0.52, 52), (-0.4, 36), (-0.3, 22)], 4),
              ([(0.5, 162), (0.6, 120), (0.7, 88), (0.84, 58)], 5),
              ([(0.6, 120), (0.5, 104)], 6),
              ([(-0.2, -22), (-0.04, -2), (0.12, -16), (0.3, 2), (0.44, -18)], 7),
              ([(0.02, 196), (0.16, 178), (0.34, 190)], 8),
              ([(0.92, 34), (0.8, 16), (0.7, 28)], 9))
    seam_objs = []
    for i, (ctrl, seed) in enumerate(CRACKS):
        ya = crack(ctrl, seed)
        add(_strap("crack%d" % i, [around(y, a_, 0.006)[0] for y, a_ in ya], 0.028, 0.016, gold, 4), "body")
        if i in (0, 1, 2, 4):
            seam_objs += _strap("seam%d" % i, [around(y, a_, 0.016)[0] for y, a_ in ya], 0.058, 0.044, seamg, 4)
    for o in seam_objs:
        for v in o.data.vertices:
            v.co.x *= PS_SEAM_IN
            v.co.z = PS_AXIS_Z + (v.co.z - PS_AXIS_Z) * PS_SEAM_IN
    add(seam_objs, "seam", True)

    # ---------------- manta de seda e arreio com guizos ----------------
    def saddle(name, y0, y1, a0, lift, material, ny=6, na=6, wave=7.0):
        """manta: grade rente ao lombo de y0 a y1, descendo até o ângulo a0 de cada lado (barra em ondas), borda metida na louça"""
        b = bmesh.new()
        rows = []
        for i in range(ny + 1):
            y = y0 + (y1 - y0) * i / ny
            lo = a0 + wave * math.cos(i * math.pi)
            rows.append([b.verts.new(around(y, lo + (180 - 2 * lo) * j / na, lift)[0]) for j in range(na + 1)])
        for i in range(ny):
            for j in range(na):
                b.faces.new((rows[i][j], rows[i][j + 1], rows[i + 1][j + 1], rows[i + 1][j]))
        edge = [rows[0][j] for j in range(na + 1)] + [rows[i][na] for i in range(1, ny + 1)] + [rows[ny][j] for j in range(na - 1, -1, -1)] + [rows[i][0] for i in range(ny - 1, 0, -1)]
        inner = [b.verts.new(v.co + (V((0, v.co.y, PS_AXIS_Z)) - v.co).normalized() * (lift + 0.03)) for v in edge]
        for i in range(len(edge)):
            j = (i + 1) % len(edge)
            b.faces.new((edge[i], edge[j], inner[j], inner[i]))
        bmesh.ops.recalc_face_normals(b, faces=b.faces[:])
        return ck.mesh_from(name, b, material)

    add(saddle("drape_trim", -0.25, 0.45, 27, 0.02, gold2), "body")
    add(saddle("drape", -0.2, 0.4, 34, 0.034, rose), "body")
    for i, (y, a_) in enumerate(((-0.25, 20), (0.45, 20), (-0.25, 160), (0.45, 160))):
        p, n = around(y, a_, 0.03)
        add(ck.tube("drapetassel%d" % i, p - V((0, 0, 0.02)), p + n * 0.03 - V((0, 0, 0.24)), 0.02, 0.05, (jade, rose2)[i % 2], 5), "body")
    for gi, (gy, mt) in enumerate(((-0.36, rose2), (0.56, rose2))):          # cilhas de seda
        ring = [around(gy, a_, 0.012)[0] for a_ in range(0, 361, 36)]
        add(_strap("girth%d" % gi, ring, 0.03, 0.03, mt, 4), "body")
        for i, a_ in enumerate((35, 90, 145)):
            p, n = around(gy, a_, 0.055)
            add(_stud("girthbell%d_%d" % (gi, i), p, 0.048, gold2), "body", True)
    # peitoral: faixa em volta do peito com três guizos grandes e um espelho redondo
    breast = []
    for t_ in range(-90, 91, 20):
        a = math.radians(t_)
        o = V((math.sin(a) * 3, -0.5 - math.cos(a) * 3, 1.38))
        p, n = cast(o, V((0, -0.5, 1.38)) - o)
        if p is not None:
            breast.append((p + n * 0.014, n, t_))
    add(_strap("breast", [b_[0] for b_ in breast], 0.036, 0.036, rose2, 5), "body")
    for i, (p, n, t_) in enumerate(breast):
        if t_ in (-30, 30, -70, 70):
            q = p + n * 0.05 - V((0, 0, 0.07))
            add(_stud("bell%d" % i, q, 0.06, gold2, sub=2), "body")
    pc, nc = next((b_[0], b_[1]) for b_ in breast if b_[2] == -10 or b_[2] == 10)
    pc = V((0, pc.y - 0.02, pc.z - 0.2))
    add(ck.tube("mirror_chain", pc + V((0, 0.03, 0.2)), pc + V((0, 0, 0.1)), 0.014, 0.014, gold2, 4), "body")
    add(lk.place([ck.ball("mirror_glass", 1.0, (0, -0.012, 0), glass, (0.15, 0.03, 0.15)), ck.tube("mirror_frame", (0, 0.0, 0), (0, 0.03, 0), 0.18, 0.18, gold2, 10)], pc, (0, -1, 0.15)), "body")

    # ---------------- pescoço de cisne e cabeça pequena (osso head; o pivô fica na base do pescoço) ----------------
    neck = mk.skin_body("neck", PS_NECK, [(0, 1), (1, 2), (2, 3)], porc, sub=1)
    add(neck, "head")
    ncast = _caster(neck)

    def nside(sx, y, z_, lift=0.0):
        p, n = ncast((sx * 3, y, z_), (-sx, 0, 0))
        if p is None:
            p, n = V((sx * 0.18, y, z_)), V((sx, 0, 0))
        return p + n * lift, n

    def nring(c_, d_, lift):
        d_, u, w = _perp(d_)
        out = []
        for i in range(9):
            a = math.tau * i / 8
            o = V(c_) + (u * math.cos(a) + w * math.sin(a)) * 2
            q, n = ncast(o, V(c_) - o)
            out.append(q + n * lift if q is not None else V(c_))
        return out

    for i, (t0, t, mt) in enumerate(((0, 0.5, ink), (1, 0.55, gold))):       # colares pintados no pescoço
        c_ = V(PS_NECK[t0][0]).lerp(V(PS_NECK[t0 + 1][0]), t)
        add(_strap("neckband%d" % i, nring(c_, V(PS_NECK[t0 + 1][0]) - V(PS_NECK[t0][0]), 0.008), 0.024, 0.024, mt, 4), "head")
    nck = [nside(1, y, z_, 0.006)[0] for y, z_ in ((-0.86, 1.98), (-0.98, 2.12), (-1.0, 2.3), (-1.04, 2.44), (-0.99, 2.6))]
    add(_strap("neckcrack", nck, 0.024, 0.014, gold, 4), "head")
    nck = [nside(-1, y, z_, 0.006)[0] for y, z_ in ((-1.02, 2.56), (-1.06, 2.7), (-1.12, 2.8))]
    add(_strap("neckcrack2", nck, 0.024, 0.014, gold, 4), "head")
    add(mk.blob("skull", 0.22, hc, porc, (0.95, 1.12, 0.95), 2), "head")
    muzzle = mk.skin_body("muzzle", [(tuple(hc + fd * 0.06), 0.18), (tuple(hc + fd * 0.38), 0.13), (tuple(hc + fd * 0.64), 0.1)], [(0, 1), (1, 2)], porc, sub=1)
    add(muzzle, "head")
    tipd = max((v.co - hc).dot(fd) for v in muzzle.data.vertices)
    add(_stud("nose", hc + fd * (tipd - 0.01) + fn * 0.02, 0.06, gold, (1.15, 0.8, 0.8), 2), "head")
    for sx in (-1, 1):
        e0 = hc + V((sx * 0.14, 0.1, 0.06))
        e1 = e0 + V((sx * 0.4, 0.2, 0.1))
        add(ck.blade("ear%d" % sx, e0, e1, 0.2, 0.045, porc, (0, 0.5, 1), 0.5), "head")
        add(ck.blade("ear_in%d" % sx, e0 + V((sx * 0.04, -0.03, 0)), e0.lerp(e1, 0.84) + V((0, -0.03, 0)), 0.1, 0.045, ink2, (0, 0.5, 1), 0.5), "head")
        add(_stud("eartip%d" % sx, e1, 0.03, gold2), "head", True)
    # máscara de festa: oval de porcelana, olhos de tinta, lágrima acesa do lado +X, veio de ouro atravessando
    MS = 0.3
    mc = hc + fd * 0.2 + fn * 0.14
    mask = lk.mask(ck, "mask", (0, 0, 0), MS, M, kind="oval", tears=(1,), wide=0.95, tall=1.4, tear_len=0.55)
    wx, dy, sz = 0.82 * 0.95 * MS, 0.34 * MS, MS * 1.4
    msurf = lambda x, z_, lift=0.0: V((x, -dy * math.sqrt(max(1.0 - (x / wx) ** 2 - (z_ / sz) ** 2, 0.0)) - lift, z_))
    mk_pts = [msurf(x, z_, 0.004) for x, z_ in ((-0.6 * wx, 0.72 * sz), (-0.3 * wx, 0.5 * sz), (-0.36 * wx, 0.2 * sz), (-0.1 * wx, -0.06 * sz), (-0.22 * wx, -0.36 * sz), (0.02 * wx, -0.62 * sz), (-0.06 * wx, -0.9 * sz))]
    mask += _strap("maskcrack", mk_pts, 0.012, 0.008, gold2, 4)
    mask += _strap("maskcrack2", [msurf(x, z_, 0.004) for x, z_ in ((-0.36 * wx, 0.2 * sz), (-0.62 * wx, 0.06 * sz), (-0.8 * wx, -0.12 * sz))], 0.01, 0.007, gold2, 4)
    for i, (x, z_) in enumerate(((-0.36, 0.6), (0.0, 0.72), (0.36, 0.6), (-0.6, 0.42), (0.6, 0.42))):       # diadema pintado na testa
        mask.append(_stud("maskdot%d" % i, msurf(x * wx, z_ * sz, -0.004), 0.022 if x else 0.03, ink if x else tear, sub=1))
    mask += _strap("masklip", [msurf(x * wx, -0.6 * sz, 0.002) for x in (-0.3, -0.1, 0.1, 0.3)], 0.011, 0.011, ink, 4)
    add(lk.place(mask, mc, fn), "head")
    for i, sx in enumerate((-1, 1)):                            # fitas que amarram a máscara, caindo atrás das orelhas
        k0 = mc + V((sx * wx * 0.95, 0.06, 0.04))
        add(lk.silk(ck, "masktie%d" % i, k0, k0 + V((sx * 0.14, 0.34, -0.42)), (0, 0.4, 1), 0.07, 0.1, rose, (sx * 0.04, 0.04, 0), 4, 0.016), "head")

    # ---------------- chifres de renda (osso antler) ----------------
    for sx in (-1, 1):
        P = AP(sx)
        add(ck.tube("pedicle%d" % sx, P[0] - V((sx * 0.04, 0.02, 0.14)), P[0].lerp(P[1], 0.2), 0.085, 0.075, porc, 7), "antler")
        add(ck.tube("burr%d" % sx, P[0].lerp(P[1], 0.12), P[0].lerp(P[1], 0.26), 0.1, 0.09, gold, 7), "antler", True)
        top = _ps_spiral(P[3] - V((sx * 0.22, 0, 0)), (sx, 0, 0), (0, 0, 1), 0.22, 0.07, 0, 310, 7)
        add(_ps_taper("beam%d" % sx, P[:3] + top, 0.075, 0.022, porc, 6), "antler")
        add(_stud("beamtip%d" % sx, top[-1], 0.042, gold2), "antler", True)
        for i, t in enumerate((0.5, 1.5, 2.4)):                # anéis de ouro na haste (emendas de kintsugi)
            s0 = int(t)
            c_ = P[s0].lerp(P[s0 + 1], t - s0)
            d_ = (P[s0 + 1] - P[s0]).normalized()
            r_ = 0.075 - 0.012 * t
            add(ck.tube("beamband%d_%d" % (sx, i), c_ - d_ * 0.025, c_ + d_ * 0.025, r_ + 0.012, r_ + 0.008, gold, 6), "antler", True)
        # galho da testa: para a frente, fecha em voluta
        a0 = P[0].lerp(P[1], 0.55)
        m1 = a0 + V((sx * 0.1, -0.3, 0.08))
        brow = [a0, a0.lerp(m1, 0.5) + V((0, 0, -0.02))] + _ps_spiral(m1 + V((0, 0, 0.16)), (0, -1, 0), (0, 0, 1), 0.16, 0.05, -90, 230, 6)
        add(_ps_taper("brow%d" % sx, brow, 0.05, 0.016, porc, 5), "antler")
        add(_stud("browtip%d" % sx, brow[-1], 0.03, gold2), "antler", True)
        # braço de fora: gancho em voluta de onde pende a lanterna grande
        a1 = P[2] + V((sx * 0.26, 0.0, 0.1))
        hook = [P[2].lerp(P[1], 0.1), P[2].lerp(a1, 0.55) + V((0, 0, 0.03))] + _ps_spiral(a1 + V((0, 0, -0.14)), (sx, 0, 0), (0, 0, 1), 0.14, 0.1, 90, -90, 6)
        add(_ps_taper("hook%d" % sx, hook, 0.045, 0.022, porc, 5), "antler")
        add(_stud("hooktip%d" % sx, hook[-1], 0.034, gold2), "antler", True)
        # galho de trás: sobe para trás e fecha em voluta
        a2 = P[2].lerp(P[3], 0.5)
        m2 = a2 + V((sx * 0.06, 0.3, 0.06))
        back = [a2, a2.lerp(m2, 0.5) + V((0, 0, -0.02))] + _ps_spiral(m2 + V((0, 0, 0.14)), (0, 1, 0), (0, 0, 1), 0.14, 0.045, -90, 230, 6)
        add(_ps_taper("back%d" % sx, back, 0.045, 0.015, porc, 5), "antler")
        add(_stud("backtip%d" % sx, back[-1], 0.028, gold2), "antler", True)
        # renda: arco de ouro por dentro da lira, com raios e contas
        ctrl = V((sx * 0.2, -0.98, 3.74))
        arc = [(P[1] * (1 - t) ** 2 + ctrl * (2 * t * (1 - t)) + top[3] * t ** 2) for t in (0.0, 0.2, 0.4, 0.6, 0.8, 1.0)]
        add(_ps_taper("lace%d" % sx, arc, 0.024, 0.018, gold2, 4), "antler")
        for i, (q, t) in enumerate(zip(arc[1:5], (1.25, 1.6, 2.0, 2.5))):
            s0 = min(2, int(t))
            b_ = P[s0].lerp(P[min(s0 + 1, 3)], t - s0)
            add(ck.tube("spoke%d_%d" % (sx, i), q, b_, 0.015, 0.015, gold2, 3), "antler")
            add(_stud("lacebead%d_%d" % (sx, i), q, 0.03, (gold2, maskm)[i % 2]), "antler", True)
            if i < 3:                                          # recorte em arquinhos entre os raios
                mid = q.lerp(arc[i + 2], 0.5) + (ctrl - b_).normalized() * 0.07
                add(_ps_taper("scallop%d_%d" % (sx, i), [q, mid, arc[i + 2]], 0.014, 0.014, gold2, 3), "antler")
        # laços de seda com duas pontas caídas
        for i, (q, mt, ln) in enumerate(((top[2], rose, 0.62), (brow[4], jade, 0.4), (P[1].lerp(P[2], 0.5), jade, 0.46))):
            add(_stud("knot%d_%d" % (sx, i), q, 0.05, mt, (1.2, 1.0, 0.8)), "antler", True)
            for j, (dx, dy_, kk) in enumerate(((0.1, 0.08, 1.0), (-0.04, 0.14, 0.7))):
                add(lk.silk(ck, "ribbon%d_%d_%d" % (sx, i, j), q, q + V((sx * dx, dy_, -ln * kk)), (1, 0.4 - j, 0), 0.07, 0.1, mt, (sx * 0.05, 0.03 * (1 - 2 * j), 0), 3, 0.016), "antler")
        # lanterninha rosada, presa curta no galho de trás (não balança)
        add(_ps_lantern("mini%d" % sx, back[3], 0.07, 0.09, paper2, gold2, rose2, 0.12, hoops=False, segs=6), "antler", True)
        # lanterna grande de papel no gancho (osso próprio: balança e acende)
        bone_ = "lantern_a" if sx > 0 else "lantern_b"
        add(_ps_lantern("lant%d" % sx, HOOK[sx], 0.1, 0.19, paper, gold2, rose, 0.3), bone_, True)
        for j in (0, 1):
            q = HOOK[sx] - V((0, 0, 0.1 + 0.19 * 2.1))
            add(lk.silk(ck, "lantrib%d_%d" % (sx, j), q, q + V(((j - 0.5) * 0.16, 0.05, -0.36 - j * 0.08)), (0.3, 1, 0), 0.05, 0.075, (jade, rose2)[j], ((j - 0.5) * 0.06, 0, 0), 3, 0.014), bone_)
    # cordão entre os dois chifres com contas e guizos; a lanterna do meio pende dele
    add(_vine("garland", gar, 0.013, gold2, 3), "antler")
    for i in (1, 2, 3, 5, 6, 7):
        if i != 2 and i != 6:
            add(_stud("garbell%d" % i, gar[i] - V((0, 0, 0.05)), 0.042, gold2), "antler", True)
        else:
            add(_ps_lantern("garmini%d" % i, gar[i], 0.04, 0.08, paper2, gold2, rose2, 0.1, hoops=False, segs=6), "antler", True)
    add(_ps_lantern("lantc", HOOK[0], 0.08, 0.22, paper, gold2, rose, 0.34), "lantern_c", True)
    for j in (0, 1):
        q = HOOK[0] - V((0, 0, 0.08 + 0.22 * 2.1))
        add(lk.silk(ck, "lantcrib%d" % j, q, q + V(((j - 0.5) * 0.2, 0.06, -0.4 - j * 0.06)), (0.3, 1, 0), 0.055, 0.08, (rose2, jade)[j], ((j - 0.5) * 0.06, 0, 0), 3, 0.014), "lantern_c")

    # ---------------- pernas finas de boneca, joelhos em esfera de ouro, cascos dourados ----------------
    for bone_, sx, fr in (("leg_fr", 1, True), ("leg_fl", -1, True), ("leg_br", 1, False), ("leg_bl", -1, False)):
        if fr:
            x, y = sx * 0.27, -0.5
            add(mk.blob("shoulder_" + bone_, 0.19, (x, y, 1.38), porc, (0.78, 1.0, 1.4), 2), bone_)
            up0, knee, foot = V((x, y, 1.3)), V((x, y - 0.02, 0.74)), V((x, y, 0.16))
            add(ck.tube("upper_" + bone_, up0, knee, 0.115, 0.07, porc, 8), bone_)
        else:
            x, y = sx * 0.25, 0.78
            add(mk.blob("haunch_" + bone_, 0.22, (x - sx * 0.02, y - 0.04, 1.4), porc, (0.7, 1.05, 1.3), 2), bone_)
            up0, knee, foot = V((x, y, 1.26)), V((x, y + 0.22, 0.8)), V((x, y + 0.1, 0.16))
            add(ck.tube("upper_" + bone_, up0, knee, 0.13, 0.072, porc, 8), bone_)
            add(dot("haunchdot_" + bone_, V((x + sx * 0.15, y - 0.04, 1.44)), V((sx, 0, 0)), 0.06, ink), bone_, True)
        add(_stud("knee_" + bone_, knee, 0.082, gold, sub=2), bone_)
        add(ck.tube("cannon_" + bone_, knee, foot, 0.062, 0.05, porc, 8), bone_)
        d_ = (knee - up0).normalized()
        for j, (t, mt) in enumerate(((0.36, ink),)):              # faixas pintadas na coxa
            c_ = up0.lerp(knee, t)
            r_ = 0.115 + (0.07 - 0.115) * t + 0.006
            add(ck.tube("band%d_%s" % (j, bone_), c_ - d_ * 0.022, c_ + d_ * 0.022, r_ + 0.004, r_, mt, 8), bone_)
        d_ = (foot - knee).normalized()
        c_ = knee.lerp(foot, 0.7)
        add(ck.tube("sock_" + bone_, c_, foot + V((0, 0, 0.02)), 0.058, 0.058, ink, 8), bone_)
        add(ck.tube("sockrim_" + bone_, c_ - d_ * 0.03, c_ + d_ * 0.01, 0.064, 0.062, gold2, 8), bone_)
        add(ck.tube("hoof_" + bone_, (foot.x, foot.y - 0.015, 0.18), (foot.x, foot.y - 0.03, 0.0), 0.062, 0.092, gold, 7), bone_, True)
    lc = [V((-0.27 - 0.1, -0.52, 1.2)), V((-0.27 - 0.094, -0.47, 1.08)), V((-0.27 - 0.088, -0.54, 0.98)), V((-0.27 - 0.076, -0.5, 0.86))]
    add(_strap("legcrack", lc, 0.018, 0.012, gold, 4), "leg_fl")

    # ---------------- rabo curto arrebitado com laço ----------------
    add(_ps_taper("scut", [V((0, 0.96, 1.6)), V((0, 1.12, 1.68)), V((0, 1.22, 1.82))], 0.085, 0.045, porc, 7), "tail")
    add(_stud("scut_tip", V((0, 1.23, 1.84)), 0.05, gold2), "tail", True)
    add(_stud("bow_knot", V((0, 1.06, 1.72)), 0.05, rose, (1.0, 0.8, 1.0)), "tail", True)
    for sx in (-1, 1):
        add(ck.blade("bow%d" % sx, V((0, 1.06, 1.72)), V((sx * 0.22, 1.1, 1.8)), 0.15, 0.03, rose, (0, 0.3, 1), 0.6), "tail")
        add(lk.silk(ck, "bowtail%d" % sx, V((sx * 0.02, 1.08, 1.7)), V((sx * 0.12, 1.2, 1.34)), (1, 0, 0), 0.06, 0.085, rose2, (sx * 0.03, 0.03, 0), 3, 0.014), "tail")

    objs = [o for o, _b in parts]
    for o in objs:
        if o.name not in flat:
            ck._smooth(o.data)
    _outward(objs)
    for o in objs:
        for v in o.data.vertices:
            v.co *= K
    by_bone = {}
    for o, bone_ in parts:
        by_bone.setdefault(bone_, []).append(o)
    for bone_, objs_ in by_bone.items():
        lp.attach(ck._join(objs_, "ps_" + bone_), arm, bone_)
    _ps_clips(arm, K)
    legs = ("leg_fr", "leg_fl", "leg_br", "leg_bl")
    heads = ("head", "antler") + PS_LANTERNS
    _ground(arm, [c for c in PS_CLIPS if c != "die"], legs, PS_TUCK * K, heads=heads)
    _ground(arm, ["die"], (), 0.0, DIE_SINK, head=False, only=("body", "tail", "seam") + legs)
    _ground(arm, ["die"], (), 0.0, DIE_SINK, heads=heads)
    return arm


def _ps_clips(arm, K):
    """Mesmos eixos do javali/alce: corpo X+ = focinho desce (gira em volta da anca), loc (0, cima, frente); cabeça (pivô na
    BASE do pescoço) X+ = abaixa os chifres para a frente, Z = vira, Y = rola; pernas X- = casco para a frente. Ossos próprios:
    `lantern_a/b/c` (filhos de `antler`, com os eixos da cabeça): X = balança para a frente/trás, Y = para os lados, escala =
    acende; `hang` desfaz neles a inclinação de corpo + cabeça (pendem a prumo) e soma o balanço. `seam` (filho do corpo): só
    escala radial (s, 1, s): 1 = veio aceso recolhido na louça, PS_FLARE = todo para fora. Toda chave leva escala (`_eclip`)."""
    z = (0, 0, 0)
    r = lambda x=0.0, y=0.0, zz=0.0: (x, y, zz)
    p = lambda up=0.0, fwd=0.0: (0, up * K, fwd * K)
    sc = lambda seq: [(f, z, z, (s, s, s)) for f, s in seq]
    sm = lambda seq: [(f, z, z, (1.0 + (PS_FLARE - 1.0) * s, 1.0, 1.0 + (PS_FLARE - 1.0) * s)) for f, s in seq]      # s = 0..1 de veio aceso
    tau = math.tau
    sin, cos = math.sin, math.cos
    legs = ("leg_fr", "leg_fl", "leg_br", "leg_bl")

    def planted(body, extra=None):
        return {g: bg.plant(body, g, (extra or {}).get(g, ())) for g in legs}

    def lin(seq, f, n):
        """valor linear de [(quadro, v1..vn)] no quadro f"""
        if not seq:
            return (0.0,) * n if n > 1 else (1.0,)
        if f <= seq[0][0]:
            return seq[0][1:]
        for a, b_ in zip(seq, seq[1:]):
            if a[0] <= f <= b_[0]:
                t = (f - a[0]) / float(b_[0] - a[0])
                return tuple(a[i] + (b_[i] - a[i]) * t for i in range(1, n + 1))
        return seq[-1][1:]

    def hang(k, sw=(), fl=(), gain=(1.0, 1.0, 1.25)):
        """chaves das três lanternas: a prumo (desfaz corpo + cabeça), mais balanço sw = [(quadro, frente, lado)] e brilho fl = [(quadro, escala)]"""
        body, head = k["body"], k["head"]
        frames = sorted({q[0] for q in body} | {q[0] for q in head} | {q[0] for q in sw} | {q[0] for q in fl})
        for i, g in enumerate(PS_LANTERNS):
            ks = []
            for f in frames:
                tilt = bg._at(body, f, 1)[0] + bg._at(head, f, 1)[0]
                roll = bg._at(head, f, 1)[1]
                fore, side = lin(sw, f, 2)
                s = lin(fl, f, 1)[0] if fl else 1.0
                ks.append((f, (-tilt * PS_HANG + fore * gain[i], -roll * PS_HANG + side * gain[i] * (1.0 if i < 2 else -0.8), 0.0), z, (s, s, s)))
            k[g] = ks
        return k

    def swing(f0, f1, amp, step=2, fore=0.35):
        """balanço que morre: vai e vem de lado a cada `step` quadros, de amp até zero"""
        out, n = [], max(1, (f1 - f0) // step)
        for i in range(n + 1):
            a = amp * (1.0 - i / float(n)) * (1 if i % 2 == 0 else -1)
            out.append((f0 + i * step, a * fore, a))
        return out

    # ---- idle: respira, a cabeça passeia devagar; as lanternas oscilam atrasadas e pulsam ----
    n = 48
    k = {b_: [] for b_ in ("body", "head", "tail", "leg_fr", "leg_fl", "antler", "seam")}
    sw, fl = [], []
    for f in list(range(1, n, 3)) + [n]:
        a = (f - 1) / (n - 1) * tau
        k["body"].append((f, r(1.0 * sin(a)), p(0.015 * (0.5 - 0.5 * cos(a)))))
        k["head"].append((f, r(1.5 + 2.5 * sin(a + 0.6), 3 * sin(a), 5 * sin(a)), z))
        k["tail"].append((f, r(4, 0, 14 * sin(2 * a)), z))
        k["leg_fr"].append((f, r(-1.0 * sin(a)), z))
        k["leg_fl"].append((f, r(-1.0 * sin(a)), z))
        k["antler"].append((f, z, z, E_ONE))
        k["seam"].append((f, z, z, E_ONE))
        sw.append((f, 3 * sin(a - 0.9), 5 * sin(a - 1.2)))
        fl.append((f, 1.0 + 0.05 * (0.5 - 0.5 * cos(2 * a))))
    _eclip(arm, "idle", hang(k, sw, fl), n, loop=True)

    # ---- run: galope leve e alto (salta mais do que corre), pescoço erguido; as lanternas ficam para trás ----
    n = 16
    k = {b_: [] for b_ in ("body", "head", "tail") + legs}
    sw = []
    for f in range(1, n + 1):
        a = (f - 1) / (n - 1) * tau
        k["body"].append((f, r(-5 * cos(a), 0, 1.5 * sin(a)), p(0.16 * (0.5 + 0.5 * sin(a)))))
        k["head"].append((f, r(5 * cos(a) + 5, 0, -1.5 * sin(a)), z))
        k["leg_fr"].append((f, r(-30 * sin(a) + 4 * cos(a)), z))
        k["leg_fl"].append((f, r(-30 * sin(a - 0.4) + 4 * cos(a)), z))
        k["leg_br"].append((f, r(27 * sin(a + 0.2) + 4 * cos(a)), z))
        k["leg_bl"].append((f, r(27 * sin(a - 0.2) + 4 * cos(a)), z))
        k["tail"].append((f, r(34 + 10 * sin(a - 1.2), 0, 5 * sin(a + 0.6)), z))
        sw.append((f, -14 + 9 * sin(a - 1.0), 6 * sin(a + 0.4)))
    _eclip(arm, "run", hang(k, sw), n, loop=True)

    # ---- attack (5): estocada curta dos chifres para baixo e gancho para cima ----
    e = 16
    k = {
        "body": [(1, z, z), (3, r(4), p(-0.02, -0.1)), (5, r(-5), p(0.03, 0.24)), (8, r(-3), p(0.02, 0.18)), (11, r(1), p(0, 0.05)), (e, z, z)],
        "head": [(1, z, z), (3, r(40, 0, 8), z), (5, r(-12, 0, -12), z), (8, r(-7, 0, -5), z), (11, r(2, 0, 3), z), (e, z, z)],
        "leg_fr": [(1, z, z), (3, r(6), z), (5, r(-18), z), (8, r(-11), z), (12, r(-3), z), (e, z, z)],
        "leg_fl": [(1, z, z), (3, r(5), z), (5, r(-12), z), (8, r(-7), z), (12, r(-2), z), (e, z, z)],
        "leg_br": [(1, z, z), (3, r(-10), z), (5, r(20), z), (8, r(14), z), (12, r(3), z), (e, z, z)],
        "leg_bl": [(1, z, z), (3, r(-10), z), (5, r(17), z), (8, r(11), z), (12, r(2), z), (e, z, z)],
        "tail": [(1, z, z), (3, r(14), z), (5, r(44), z), (9, r(20, 0, 12), z), (e, z, z)],
        "seam": sm([(1, 0), (4, 0), (5, 0.5), (9, 0.15), (e, 0)]),
    }
    _eclip(arm, "attack", hang(k, [(1, 0, 0), (3, 10, 0), (5, -22, 6), (8, 12, -5), (11, -6, 3), (14, 2, -1), (e, 0, 0)]), e)

    # ---- hit: a louça estala; tranco para trás, a cabeça vira, os veios piscam ----
    body = [(1, z, z), (2, r(-5, 0, 4), p(0.01, -0.09)), (5, r(3, 0, -2), p(0, -0.04)), (7, r(-1), p(0, -0.015)), (10, z, z)]
    k = planted(body, {"leg_fr": [(2, -9), (5, 4)], "leg_fl": [(2, -6), (5, 3)], "leg_br": [(2, 7), (5, -3)], "leg_bl": [(2, 5), (5, -3)]})
    k.update({"body": body, "head": [(1, z, z), (2, r(-16, 6, 16), z), (5, r(7, -3, -8), z), (7, r(-2), z), (10, z, z)],
              "tail": [(1, z, z), (2, r(34), z), (5, r(16, 0, 8), z), (10, z, z)],
              "seam": sm([(1, 0), (2, 1.0), (5, 0.35), (8, 0.0), (10, 0)])})
    _eclip(arm, "hit", hang(k, [(1, 0, 0), (2, 14, -12), (4, -9, 9), (6, 5, -5), (8, -2, 2), (10, 0, 0)]), 10)

    # ---- atk_charge (5): recolhe um passo, deita os chifres como lanças e desliza comprido e baixo; termina erguendo a cabeça num floreio ----
    e = 20
    k = {
        "body": [(1, z, z), (3, r(5), p(-0.02, -0.22)), (5, r(5), p(0.0, 0.56)), (8, r(3), p(0.03, 0.62)), (10, r(-8), p(0.05, 0.46)), (13, r(-3), p(0.01, 0.2)),
                 (17, r(1), p(0, 0.03)), (e, z, z)],
        "head": [(1, z, z), (3, r(34), z), (5, r(46), z), (8, r(43), z), (10, r(-16, 0, -10), z), (13, r(-8, 0, 6), z), (17, r(2), z), (e, z, z)],
        "leg_fr": [(1, z, z), (3, r(12), z), (5, r(-34), z), (8, r(-26), z), (10, r(4), z), (13, r(5), z), (e, z, z)],
        "leg_fl": [(1, z, z), (3, r(8), z), (5, r(-26), z), (8, r(-19), z), (10, r(7), z), (13, r(3), z), (e, z, z)],
        "leg_br": [(1, z, z), (3, r(-20), z), (5, r(30), z), (8, r(23), z), (10, r(12), z), (13, r(-2), z), (e, z, z)],
        "leg_bl": [(1, z, z), (3, r(-20), z), (5, r(25), z), (8, r(18), z), (10, r(10), z), (13, r(0), z), (e, z, z)],
        "tail": [(1, z, z), (3, r(24), z), (5, r(54), z), (8, r(46, 0, 8), z), (10, r(16, 0, -10), z), (14, r(6), z), (e, z, z)],
        "antler": sc([(1, 1), (3, 1.0), (5, 1.08), (8, 1.06), (11, 1.0), (e, 1)]),
        "seam": sm([(1, 0), (3, 0.2), (5, 0.7), (8, 0.5), (11, 0.1), (e, 0)]),
    }
    _eclip(arm, "atk_charge", hang(k, [(1, 0, 0), (3, 14, 0), (5, -30, 4), (8, -24, -4), (10, 20, 6), (13, -12, -5), (16, 6, 3), (18, -2, 0), (e, 0, 0)]), e)

    # ---- slam (8): empina alto, os cascos dourados batem no ar e descem juntos; no impacto os veios de ouro acendem inteiros ----
    e = 24
    k = {
        "body": [(1, z, z), (3, r(5), p(-0.04)), (5, r(-44), p(0.03, -0.05)), (6, r(-50), p(0.04, -0.06)), (8, r(7), p(-0.03, 0.14)), (10, r(3), p(0.0, 0.12)),
                 (12, r(6), p(-0.02, 0.09)), (15, r(2), p(0, 0.03)), (20, r(-1), z), (e, z, z)],
        "head": [(1, z, z), (3, r(12), z), (5, r(16), z), (6, r(24), z), (8, r(20), z), (10, r(10, 0, 5), z), (12, r(12, 0, -5), z), (16, r(3), z), (e, z, z)],
        "leg_fr": [(1, z, z), (3, r(6), z), (5, r(-64), z), (6, r(-36), z), (7, r(-30), z), (8, r(-7), z), (10, r(-3), z), (12, r(-6), z), (15, r(-2), z), (e, z, z)],
        "leg_fl": [(1, z, z), (3, r(6), z), (5, r(-32), z), (6, r(-66), z), (7, r(-28), z), (8, r(-7), z), (10, r(-3), z), (12, r(-6), z), (15, r(-2), z), (e, z, z)],
        "leg_br": [(1, z, z), (3, r(-5), z), (5, r(44), z), (6, r(50), z), (8, r(-7), z), (10, r(-3), z), (12, r(-6), z), (15, r(-2), z), (e, z, z)],
        "leg_bl": [(1, z, z), (3, r(-5), z), (5, r(44), z), (6, r(50), z), (8, r(-7), z), (10, r(-3), z), (12, r(-6), z), (15, r(-2), z), (e, z, z)],
        "tail": [(1, z, z), (4, r(40), z), (6, r(60), z), (8, r(-6), z), (12, r(10, 0, 10), z), (16, r(2, 0, -6), z), (e, z, z)],
        "seam": sm([(1, 0), (5, 0.1), (7, 0.3), (8, 1.0), (10, 0.8), (12, 1.0), (16, 0.5), (21, 0.0), (e, 0)]),
    }
    _eclip(arm, "slam", hang(k, [(1, 0, 0), (5, 10, 0), (6, 4, 0), (8, -26, 5), (10, 16, -5), (12, -10, 4), (15, 6, -3), (18, -3, 1), (21, 1, 0), (e, 0, 0)],
                             [(1, 1), (7, 1), (8, 1.15), (12, 1.05), (e, 1)]), e)

    # ---- roar / shout (7): sem voz; recolhe e sacode a cabeça de lado num toque de guizos, as lanternas voam de um lado para o outro ----
    e = 24
    body = [(1, z, z), (4, r(5), p(-0.03, -0.04)), (7, r(-7), p(0.02, 0.02)), (9, r(-6, 0, 3), p(0.02, 0.02)), (11, r(-7, 0, -3), p(0.02, 0.02)),
            (13, r(-6, 0, 3), p(0.02, 0.02)), (16, r(-4), p(0.01, 0.01)), (20, r(2), z), (e, z, z)]
    k = planted(body, {"leg_fr": [(4, 0, 2), (7, 0, 6), (16, 0, 6), (20, 0, 2)], "leg_fl": [(4, 0, 2), (7, 0, 6), (16, 0, 6), (20, 0, 2)]})
    k.update({"body": body,
              "head": [(1, z, z), (4, r(24, 0, 0), z), (7, r(-22, 22, 10), z), (9, r(-18, -24, -10), z), (11, r(-22, 22, 10), z), (13, r(-18, -20, -8), z),
                       (15, r(-16, 12, 4), z), (17, r(-10, -5), z), (20, r(3), z), (e, z, z)],
              "tail": [(1, z, z), (4, r(-4), z), (7, r(46, 0, 12), z), (9, r(46, 0, -12), z), (11, r(46, 0, 12), z), (13, r(40, 0, -8), z), (17, r(14), z), (e, z, z)],
              "antler": sc([(1, 1), (4, 0.97), (7, 1.08), (9, 1.04), (11, 1.08), (13, 1.04), (16, 1.02), (20, 1.0), (e, 1)]),
              "seam": sm([(1, 0), (6, 0), (7, 0.4), (13, 0.3), (17, 0.0), (e, 0)])})
    k = hang(k, [(1, 0, 0), (4, 8, 0), (7, -18, -34), (9, -6, 38), (11, -8, -38), (13, -4, 34), (15, 0, -24), (17, 0, 16), (19, 0, -9), (21, 0, 4), (e, 0, 0)],
             [(1, 1), (6, 1), (7, 1.18), (9, 1.06), (11, 1.18), (13, 1.06), (15, 1.12), (18, 1), (e, 1)])
    for name in ("roar", "shout"):
        _eclip(arm, name, {b_: list(v) for b_, v in k.items()}, e)

    # ---- maul (7): recolhe os chifres para um lado e varre cruzando a frente ----
    e = 18
    body = [(1, z, z), (3, r(4, -10), p(-0.02, -0.05)), (5, r(6, -16), p(-0.02, -0.08)), (7, r(2, 15), p(0.02, 0.18)), (9, r(1, 18), p(0.02, 0.16)),
            (12, r(0, 7), p(0, 0.05)), (e, z, z)]
    k = planted(body, {"leg_fr": [(5, 8), (7, -11), (9, -8), (12, -2)], "leg_fl": [(5, -5), (7, -6), (9, -5)], "leg_br": [(5, -6), (7, 9), (9, 6)],
                       "leg_bl": [(5, -6), (7, 8), (9, 5)]})
    k.update({"body": body,
              "head": [(1, z, z), (3, r(18, 0, -20), z), (5, r(34, 0, -36), z), (7, r(26, 0, 34), z), (9, r(12, 0, 42), z), (12, r(0, 0, 10), z), (e, z, z)],
              "tail": [(1, z, z), (5, r(12, 0, -18), z), (7, r(30, 0, 22), z), (11, r(8, 0, -8), z), (e, z, z)],
              "seam": sm([(1, 0), (6, 0), (7, 0.5), (10, 0.15), (e, 0)])})
    _eclip(arm, "maul", hang(k, [(1, 0, 0), (3, 0, 10), (5, 4, 18), (7, -8, -34), (9, 0, 24), (11, 0, -14), (13, 0, 8), (15, 0, -3), (e, 0, 0)]), e)

    # ---- pounce (9): agacha, salta longe e cai nos cascos da frente ----
    e = 20
    k = {
        "body": [(1, z, z), (3, r(4), p(-0.05, -0.06)), (5, r(7), p(-0.09, -0.12)), (7, r(-16), p(0.5, 0.3)), (8, r(-3), p(0.48, 0.5)), (9, r(9), p(0.0, 0.58)),
                 (11, r(6), p(-0.04, 0.46)), (13, r(3), p(-0.02, 0.28)), (17, r(-1), p(0, 0.05)), (e, z, z)],
        "head": [(1, z, z), (5, r(14), z), (7, r(-6), z), (9, r(34), z), (11, r(16), z), (14, r(4), z), (e, z, z)],
        "leg_fr": [(1, z, z), (5, r(14), z), (7, r(-52), z), (8, r(-36), z), (9, r(-9), z), (11, r(-6), z), (13, r(-3), z), (e, z, z)],
        "leg_fl": [(1, z, z), (5, r(14), z), (7, r(-42), z), (8, r(-28), z), (9, r(-9), z), (11, r(-6), z), (13, r(-3), z), (e, z, z)],
        "leg_br": [(1, z, z), (5, r(-24), z), (7, r(46), z), (8, r(36), z), (9, r(-9), z), (11, r(-6), z), (13, r(-3), z), (e, z, z)],
        "leg_bl": [(1, z, z), (5, r(-24), z), (7, r(38), z), (8, r(30), z), (9, r(-9), z), (11, r(-6), z), (13, r(-3), z), (e, z, z)],
        "tail": [(1, z, z), (5, r(-8), z), (7, r(50), z), (9, r(10), z), (13, r(8, 0, 8), z), (e, z, z)],
        "seam": sm([(1, 0), (8, 0), (9, 0.8), (12, 0.3), (16, 0.0), (e, 0)]),
    }
    _eclip(arm, "pounce", hang(k, [(1, 0, 0), (5, 6, 0), (7, -20, 0), (9, -28, 4), (11, 18, -4), (13, -10, 3), (16, 4, -1), (e, 0, 0)]), e)

    # ---- brace (6): crava as patas abertas, abaixa o corpo e põe a renda dos chifres à frente como um biombo ----
    e = 18
    body = [(1, z, z), (3, r(-3), p(0.02)), (6, r(5), p(-0.1, 0.04)), (9, r(4), p(-0.085, 0.04)), (12, r(5), p(-0.1, 0.04)), (15, r(2), p(-0.02, 0.01)), (e, z, z)]
    spread = [(6, 0, 8), (12, 0, 8)]
    k = planted(body, {g: spread for g in legs})
    k.update({"body": body, "head": [(1, z, z), (3, r(-8), z), (6, r(40), z), (9, r(36), z), (12, r(40), z), (15, r(8), z), (e, z, z)],
              "tail": [(1, z, z), (6, r(-8), z), (12, r(-6), z), (e, z, z)],
              "antler": sc([(1, 1), (6, 1.06), (9, 1.04), (12, 1.06), (e, 1)]),
              "seam": sm([(1, 0), (5, 0.1), (6, 0.6), (9, 0.4), (12, 0.6), (15, 0.1), (e, 0)])})
    _eclip(arm, "brace", hang(k, [(1, 0, 0), (3, -4, 0), (6, 12, 4), (9, -6, -3), (12, 4, 2), (15, -2, 0), (e, 0, 0)]), e)

    # ---- cast_ground (10): reverência de baile: uma pata à frente, a outra atrás, a cabeça desce devagar e as lanternas acendem de uma vez ----
    e = 24
    body = [(1, z, z), (4, r(-4), p(0.02, -0.03)), (8, r(8), p(-0.03, 0.02)), (10, r(13), p(-0.05, 0.03)), (12, r(12), p(-0.045, 0.03)), (14, r(13), p(-0.05, 0.03)),
            (18, r(4), p(-0.02, 0.01)), (e, z, z)]
    k = planted(body, {"leg_fr": [(4, -8), (8, -30), (10, -36), (14, -36), (18, -14)], "leg_fl": [(4, 4), (8, 20), (10, 26), (14, 26), (18, 8)]})
    k.update({"body": body,
              "head": [(1, z, z), (4, r(-16), z), (8, r(24), z), (10, r(36), z), (12, r(33), z), (14, r(36), z), (18, r(16), z), (e, z, z)],
              "tail": [(1, z, z), (4, r(10), z), (10, r(44), z), (14, r(40, 0, 10), z), (18, r(12), z), (e, z, z)],
              "antler": sc([(1, 1), (8, 1.0), (10, 1.08), (12, 1.04), (14, 1.08), (18, 1.02), (e, 1)]),
              "seam": sm([(1, 0), (8, 0.1), (10, 0.9), (12, 0.6), (14, 0.9), (18, 0.2), (e, 0)])})
    _eclip(arm, "cast_ground", hang(k, [(1, 0, 0), (4, -6, 0), (8, 8, 0), (10, 0, 0), (14, 0, 0), (17, -8, 3), (20, 4, -2), (e, 0, 0)],
                                    [(1, 1), (4, 1.0), (8, 0.82), (10, 1.55), (12, 1.3), (14, 1.5), (18, 1.15), (e, 1)]), e)

    # ---- die: a louça estala (veios acesos), fica dura como estatueta e tomba de lado; as lanternas apagam ----
    s = 1.4
    f = lambda x: int(round(1 + (x - 1) * s))
    e = f(24)
    roll = PS_DIE_ROLL
    hx, hy, hz = PS_DIE_HEAD
    k = {
        "body": [(1, z, z), (f(4), r(-9), p(0.02, -0.05)), (f(9), r(5), p(-0.04, 0.02)), (f(14), r(2), p(-0.02)), (e, r(2), p(-0.02))],
        "head": [(1, z, z), (f(4), r(-24, 0, 8), z), (f(9), r(18), z), (f(14), r(hx, hy, hz), z), (f(17), r(hx - 8, hy, hz), z), (f(20), r(hx, hy, hz), z), (e, r(hx, hy, hz), z)],
        "leg_fr": [(1, z, z), (f(4), r(-12), z), (f(9), r(10), z), (f(14), r(-12), z), (f(17), r(-17), z), (e, r(-12), z)],
        "leg_fl": [(1, z, z), (f(4), r(-9), z), (f(9), r(8), z), (f(14), r(-5), z), (f(17), r(-9), z), (e, r(-5), z)],
        "leg_br": [(1, z, z), (f(4), r(6), z), (f(9), r(-6), z), (f(14), r(9), z), (f(17), r(14), z), (e, r(9), z)],
        "leg_bl": [(1, z, z), (f(4), r(6), z), (f(9), r(-6), z), (f(14), r(16), z), (f(17), r(20), z), (e, r(16), z)],
        "tail": [(1, z, z), (f(4), r(30), z), (f(9), r(-10), z), (f(14), r(6, 0, 10), z), (f(17), r(10, 0, 18), z), (e, r(4, 0, 12), z)],
        "root": [(1, z, z), (f(9), z, z), (f(14), r(0, 0, roll), z), (f(17), r(0, 0, roll + 6), z), (f(20), r(0, 0, roll), z), (e, r(0, 0, roll), z)],
        "seam": sm([(1, 0), (f(4), 1.0), (f(9), 0.6), (f(14), 1.0), (f(18), 0.5), (e, 0.0)]),
    }
    k = hang(k, [(1, 0, 0), (f(4), 12, 0), (f(9), -10, 0), (f(14), 0, 0), (e, 0, 0)], [(1, 1), (f(4), 1.15), (f(9), 1.0), (f(14), 0.8), (f(18), 0.6), (e, 0.5)])
    _eclip(arm, "die", k, e)
# --- fim do Gamo de Porcelana ---


BUILDERS = {
    "mob_ancestral_boar": ancestral_boar,
    "mob_ancient_elk": ancient_elk,
    "mob_ruins_basilisk": ruins_basilisk,
    "mob_war_rhino": war_rhino,
    "mob_iron_wolf_king": iron_wolf_king,
    "mob_porcelain_stag": porcelain_stag,
}
HUMANOIDS = set()                   # todos de peças rígidas (lp.export_glb)
