"""Campo dos Juramentos (field_oaths, 24-28; GDD design/gdd/campo-dos-juramentos.md §3.3 e §9): os modelos novos do campo.

Humanoides do kit (malha skinned, clipes de mob_kit.humanoid / chibi_kit.mob_clips):
  mob_oath_sworn     Juramentado: cavaleiro-espectro da Aurora. Placas cinza-azuladas lascadas, elmo de balde com a quina
                     partida e a fenda acesa em azul-frio, toco de pluma, tabardo dourado rasgado (duas tiras de tamanhos
                     diferentes), racha acesa no peitoral, escudo. Clipes: idle run attack cast hit die block + atk_charge/atk_leap
                     (mob_charge: "charge" com preparo 0,6 s cai no atk_leap; o atk_charge fica para preparo curto).
  mob_fallen_bearer  Sir Edran, o Porta-Estandarte Caído (chefe de campo; MonsterDef.scale ~1,4): placas cinza-escuras com
                     filete de ouro, elmo fechado com a crista PARTIDA, meia-capa no ombro esquerdo e o ESTANDARTE enorme na
                     mão direita (mastro = arma; pano dourado dobrado, escurecido e rasgado nas pontas). Clipes de chefe
                     (MOB_BOSS_KEEP): `cast_ground` = fincar o estandarte (Estandarte Fincado), `atk_sweep` = varredura do mastro
                     (Varredura do Mastro; o kit não tem `atk_2h_slash`), `attack` = golpe de duas mãos de cima.
  mob_grave_hauler   Carregador de Covas: corpo "brute" encurvado (postura somada a todos os clipes), capuz de saco, pá grande
                     (attack = golpe de cima, atk_2h), saco de terra nas costas, avental de couro.
(mob_carrion_crow, opcional no pedido, não foi feito: o catálogo segue com o mob_shaman_hawk recolorido.)

    import mob_kit; mob_kit.build_all(r"<abs>/assets/models", only=set(oaths_mobs.BUILDERS))
    blender -b --factory-startup --python tools/blender/lumeria_mobs_preview.py -- --module=oaths_mobs --out=<abs> --ground --export=<abs assets/models>
"""
import bmesh
import bpy
from mathutils import Vector

import chibi_kit as ck
import mob_kit as mk

V = Vector
cone = mk.cone

SPECTRE = (0.66, 0.73, 0.82)        # pele/placas do Juramentado (cinza-azulado pálido; o catálogo pinta por cima pela cor do MonsterDef)
COLD = (0.62, 0.86, 1.0)            # fenda do elmo e racha do peito (acesas)
GOLD = (0.86, 0.7, 0.32)            # pano da Aurora (dourado gasto)
GOLD_D = (0.36, 0.28, 0.16)         # pontas escurecidas do estandarte


def _dims(base):
    b = base["b"]
    return (base["rig"], b, V(base["head_c"]), b["head"], ck.Z["chest"], ck.Z["waist"], b["chest"] * b["depth"], b["chest"])


def _rigid(objs, rig, bone):
    for o in objs:
        ck.skin_rigid(o, rig, bone)


def _drop(prefixes):
    for o in list(bpy.context.scene.objects):
        if o.type == "MESH" and o.name.startswith(prefixes):
            bpy.data.objects.remove(o, do_unlink=True)


def _cloth(name, top_a, top_b, drop, material, folds=4, depth=0.04, teeth=3, tooth=0.12, down=(0, 0, -1), out=(0, -1, 0)):
    """Pano dobrado pendurado entre `top_a` e `top_b`: colunas em zigue-zague (dobras para `out`), barra de baixo em dentes
    (rasgado). Uma face dupla (duas camadas finas) para ler dos dois lados no toon."""
    a, b = V(top_a), V(top_b)
    dn, ou = V(down).normalized(), V(out).normalized()
    bm = bmesh.new()
    cols = folds * 2 + 1
    rows = []
    for k in range(cols):
        t = k / (cols - 1)
        off = ou * (depth if k % 2 else -depth)
        top = a + (b - a) * t + off
        tooth_k = (k % max(1, (cols - 1) // teeth) == 0)
        bot = top + dn * (drop + (tooth if tooth_k else -tooth * 0.4))
        rows.append((top, top + dn * drop * 0.55 + off * 0.4, bot))
    for layer, sgn in ((0, 1.0), (1, -1.0)):
        vs = [[bm.verts.new(p + ou * 0.006 * sgn) for p in col] for col in rows]
        for k in range(cols - 1):
            for j in range(2):
                f = (vs[k][j], vs[k + 1][j], vs[k + 1][j + 1], vs[k][j + 1])
                bm.faces.new(f if sgn > 0 else tuple(reversed(f)))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    return ck.mesh_from(name, bm, material)


# ---------------------------------------------------------------------------
# Juramentado
# ---------------------------------------------------------------------------
def sworn_parts(cid):
    def add(base, mats):
        rig, b, c, r, zc, zw, back, sw = _dims(base)
        front = -back
        steel = ck.mat("m_%s_steel" % cid, (0.7, 0.75, 0.82), 0.4)
        steel_d = ck.mat("m_%s_steel_d" % cid, (0.48, 0.52, 0.6), 0.5)
        dark = ck.mat("m_%s_dark" % cid, (0.08, 0.09, 0.12), 0.6)
        cold = ck.mat("m_%s_glow" % cid, COLD, 0.3, 2.2)
        gold = ck.mat("m_%s_gold" % cid, GOLD, 0.6)
        gold_d = ck.mat("m_%s_gold_d" % cid, (0.58, 0.46, 0.24), 0.7)
        head, body = [], []
        # elmo de balde com a quina esquerda de cima partida (lasca escura), fenda acesa, cruz de ouro gasto e o toco da pluma
        head.append(ck.tube(cid + "_bucket", c + V((0, 0, -r * 0.55)), c + V((0, 0, r * 0.72)), r * 1.12, r * 1.05, steel, 14))
        head.append(ck.ball(cid + "_dome", r * 1.05, c + V((0, 0, r * 0.7)), steel, (1, 1, 0.42)))
        head.append(ck.ball(cid + "_chip", r * 0.34, c + V((r * 0.78, -r * 0.5, r * 0.82)), steel_d, (0.9, 0.7, 0.5)))
        head.append(ck.tube(cid + "_slit", c + V((-r * 0.6, -r * 1.1, r * 0.12)), c + V((r * 0.6, -r * 1.1, r * 0.12)), r * 0.075, r * 0.075, cold, 6))
        head.append(ck.tube(cid + "_cross", c + V((0, -r * 1.12, -r * 0.42)), c + V((0, -r * 1.12, r * 0.02)), r * 0.06, r * 0.06, gold_d, 4))
        head.append(ck.tube(cid + "_rim", c + V((0, 0, -r * 0.6)), c + V((0, 0, -r * 0.45)), r * 1.18, r * 1.16, steel_d, 14))
        for k in range(3):                    # o que sobrou da pluma: três penas curtas tombadas para trás
            head.append(ck.blade("%s_plume%d" % (cid, k), c + V(((k - 1) * r * 0.18, r * 0.1, r * 1.08)),
                                 c + V(((k - 1) * r * 0.42, r * (0.95 - 0.15 * abs(k - 1)), r * 1.12)), r * 0.24, r * 0.05, gold_d, (1, 0, 0), 0.4))
        # tabardo dourado rasgado: a tira da frente desce até o joelho, a de trás acaba na cintura; pontas em dente
        for k, (x0, z1, w) in enumerate(((-0.06, ck.Z["knee"] + 0.08, 0.2), (0.09, ck.Z["knee"] + 0.22, 0.14))):
            body.append(ck.blade("%s_tabard%d" % (cid, k), V((x0, front - 0.035, zc + 0.12)), V((x0 + 0.02, front - 0.06, z1)), w, 0.02, gold, (1, 0, 0), 0.3))
        body.append(ck.blade(cid + "_tabard_back", V((0, back + 0.035, zc + 0.12)), V((0.03, back + 0.06, zw - 0.02)), 0.22, 0.02, gold, (1, 0, 0), 0.3))
        body.append(ck.ball(cid + "_sun", 0.06, V((-0.04, front - 0.07, zc - 0.02)), gold_d, (1, 0.4, 1)))
        # racha acesa no peitoral e ombreira direita lascada (a esquerda fica inteira)
        body.append(ck.blade(cid + "_crack", V((0.06, front - 0.05, zc + 0.14)), V((0.13, front - 0.05, zc - 0.08)), 0.05, 0.012, cold, (1, 0, 0), 0.45))
        for sx, k in ((-1, 0.8), (1, 1.0)):
            body.append(ck.ball("%s_pauldron%d" % (cid, sx), 0.15 * k, V((sx * (sw + 0.06), 0.0, zc + 0.16)), steel, (1.1, 1.05, 0.6)))
        body.append(ck.ball(cid + "_pauldron_chip", 0.07, V((-(sw + 0.1), -0.04, zc + 0.2)), dark, (1.0, 1.0, 0.6)))
        _rigid(head, rig, "head")
        _rigid(body, rig, "chest")
    return add


def sworn_shield(cid):
    """Depois das armas: troca o escudo de monstro do kit (escuro, de cravos) por um escudo da Aurora em gota, de aço
    pálido com a borda lascada e o sol gasto, no mesmo ponto e giro do escudo do kit."""
    def add(base, mats):
        _drop(("wpn_off_",))
        steel = ck.mat("m_%s_steel" % cid, (0.7, 0.75, 0.82), 0.4)
        steel_d = ck.mat("m_%s_steel_d" % cid, (0.48, 0.52, 0.6), 0.5)
        gold_d = ck.mat("m_%s_gold_d" % cid, (0.58, 0.46, 0.24), 0.7)
        dark = ck.mat("m_%s_dark" % cid, (0.08, 0.09, 0.12), 0.6)
        w, hgt = 0.44, 0.56
        parts = [ck.box("sh_top", (w, 0.05, hgt * 0.55), (0, 0, hgt * 0.2), steel, 0.015),
                 ck.blade("sh_point", (0, 0, -hgt * 0.06), (0, 0, -hgt * 0.5), w, 0.05, steel, (1, 0, 0), 0.05),
                 ck.box("sh_rim", (w + 0.04, 0.07, 0.05), (0, 0, hgt * 0.47), steel_d, 0.01),
                 ck.box("sh_band", (0.06, 0.065, hgt * 0.85), (0, -0.004, 0.0), gold_d, 0.008),
                 ck.box("sh_cross", (w - 0.04, 0.065, 0.06), (0, -0.004, hgt * 0.18), gold_d, 0.008),
                 ck.ball("sh_sun", 0.07, (0, -0.04, hgt * 0.18), gold_d, (1.0, 0.45, 1.0)),
                 ck.ball("sh_chip", 0.07, (w * 0.46, -0.01, hgt * 0.42), dark, (1.0, 0.8, 0.8))]
        obj = ck._join(parts, "wpn_off_shield")
        rot = ck._shield_rot().to_4x4()
        cen = ck._shield_anchor(base)[1]
        for vert in obj.data.vertices:
            vert.co = rot @ (vert.co + V((0, 0, 0.1))) + cen
        ck._smooth(obj.data)
        ck.skin_rigid(obj, base["rig"], "forearm.L")
    return add


def oath_sworn(cid="mob_oath_sworn"):
    rig = mk.humanoid(cid, "plate", SPECTRE, "sword", skin=SPECTRE, eye=COLD, offhand="shield", hide_hair=True, head="none",
                      keep=("atk_charge", "atk_leap"), extra=sworn_parts(cid), after=sworn_shield(cid))
    # o escudo do kit de monstro (montagem afastada) desce 0,28 m abaixo do chão parado, correndo e em guarda; a espada no salto
    mk.act2_bosses.clear_ground(rig, {"*": 0.03, "die": -0.2}, "forearm.L", ("wpn_off_shield",))
    return mk.act2_bosses.clear_ground(rig, {"*": 0.03, "die": -0.2}, "hand.R", ("wpn_main_",), front=True)


# ---------------------------------------------------------------------------
# Sir Edran, o Porta-Estandarte Caído
# ---------------------------------------------------------------------------
def bearer_parts(cid):
    def add(base, mats):
        rig, b, c, r, zc, zw, back, sw = _dims(base)
        front = -back
        iron = ck.mat("m_%s_iron" % cid, (0.36, 0.36, 0.4), 0.4)
        iron_d = ck.mat("m_%s_iron_d" % cid, (0.22, 0.22, 0.26), 0.5)
        gold = ck.mat("m_%s_gold" % cid, (0.82, 0.64, 0.3), 0.45)
        dark = ck.mat("m_%s_dark" % cid, (0.06, 0.06, 0.08), 0.6)
        ember = ck.mat("m_%s_glow" % cid, (0.95, 0.62, 0.3), 0.3, 1.8)
        cape = ck.mat("m_%s_cape" % cid, (0.24, 0.22, 0.3), 0.8)
        head, body = [], []
        # elmo fechado com bico, fenda em brasa fosca e a crista PARTIDA (metade de pé, metade caída para o lado)
        head.append(ck.tube(cid + "_helm", c + V((0, 0, -r * 0.6)), c + V((0, 0, r * 0.65)), r * 1.14, r * 1.06, iron, 14))
        head.append(ck.ball(cid + "_dome", r * 1.07, c + V((0, 0, r * 0.62)), iron, (1, 1.05, 0.55)))
        head.append(ck.ball(cid + "_beak", r * 0.5, c + V((0, -r * 0.95, -r * 0.08)), iron, (0.75, 0.6, 0.9)))
        head.append(ck.tube(cid + "_slit", c + V((-r * 0.62, -r * 1.12, r * 0.18)), c + V((r * 0.62, -r * 1.12, r * 0.18)), r * 0.07, r * 0.07, ember, 6))
        head.append(ck.tube(cid + "_band", c + V((0, 0, r * 0.3)), c + V((0, 0, r * 0.42)), r * 1.17, r * 1.15, gold, 14))
        head.append(ck.blade(cid + "_crest", c + V((0, -r * 0.7, r * 1.15)), c + V((0, r * 0.15, r * 1.75)), r * 0.62, r * 0.1, gold, (0, 1, 0), 0.5))
        head.append(ck.blade(cid + "_crest_fallen", c + V((r * 0.2, r * 0.3, r * 1.3)), c + V((r * 1.15, r * 1.0, r * 0.95)), r * 0.5, r * 0.1, gold, (0, 1, 0.4), 0.5))
        head.append(ck.box(cid + "_crest_break", (r * 0.14, r * 0.3, r * 0.12), c + V((0, r * 0.18, r * 1.62)), dark))
        # gorjal, ombreiras de ferro com filete de ouro, sol apagado no peito, meia-capa no ombro esquerdo
        body.append(ck.tube(cid + "_gorget", V((0, 0, ck.Z["neck"] - 0.08)), V((0, 0, ck.Z["neck"] + 0.05)), sw * 0.86, sw * 0.64, iron, 12))
        for sx in (-1, 1):
            body.append(ck.ball("%s_pauldron%d" % (cid, sx), 0.19, V((sx * (sw + 0.08), 0.0, zc + 0.2)), iron, (1.1, 1.1, 0.62)))
            body.append(ck.tube("%s_pauldron_rim%d" % (cid, sx), V((sx * (sw + 0.08), 0.0, zc + 0.12)), V((sx * (sw + 0.08), 0.0, zc + 0.16)), 0.2, 0.2, gold, 12))
        body.append(ck.tube(cid + "_sun", V((0, front - 0.05, zc - 0.02)), V((0, front - 0.08, zc - 0.02)), 0.1, 0.1, gold, 12))
        body.append(ck.ball(cid + "_sun_core", 0.05, V((0, front - 0.09, zc - 0.02)), dark, (1, 0.5, 1)))
        body.append(ck.blade(cid + "_cape", V((sw * 0.7, back + 0.05, zc + 0.18)), V((sw * 0.9, back + 0.16, ck.Z["knee"] + 0.12)), 0.34, 0.025, cape, (1, 0, 0), 0.3))
        body.append(ck.blade(cid + "_cape_tear", V((sw * 1.0, back + 0.1, zc - 0.05)), V((sw * 1.15, back + 0.2, ck.Z["knee"] + 0.28)), 0.14, 0.02, cape, (1, 0, 0), 0.35))
        body.append(ck.blade(cid + "_tabard", V((0, front - 0.04, zw + 0.04)), V((0.02, front - 0.06, ck.Z["knee"] + 0.05)), 0.24, 0.02, iron_d, (1, 0, 0), 0.3))
        _rigid(head, rig, "head")
        _rigid(body, rig, "chest")
    return add


def bearer_banner(cid):
    """Depois das armas: o cajado do kit vira o mastro do estandarte (mesma mão, mesmo eixo, ~2,35 m), com ponta de lança
    dourada, travessa e o pano dourado dobrado, mais escuro e rasgado na barra."""
    def add(base, mats):
        _drop(("wpn_main_",))
        g = V(ck.hand_center(base, ".R"))
        up = V((-0.22, -0.12, 1.0)).normalized()          # o mesmo eixo do cajado do kit (.R: sx = -1)
        wood = ck.mat("m_%s_pole" % cid, (0.34, 0.27, 0.2), 0.8)
        gold = ck.mat("m_%s_gold" % cid, (0.82, 0.64, 0.3), 0.45)
        cloth = ck.mat("m_%s_banner" % cid, GOLD, 0.8)
        cloth_d = ck.mat("m_%s_banner_d" % cid, GOLD_D, 0.85)
        low, top = g - up * 0.32, g + up * 2.0
        side = V((1, 0, 0))
        parts = [ck.tube("pole", low, top, 0.034, 0.03, wood, 6),
                 ck.tube("ferrule", low - up * 0.04, low + up * 0.08, 0.04, 0.038, gold, 6),
                 ck.tube("bar", top - up * 0.16 - side * 0.42, top - up * 0.16 + side * 0.42, 0.024, 0.024, wood, 5),
                 ck.blade("spear", top, top + up * 0.32, 0.11, 0.03, gold, (1, 0, 0), 0.35)]
        for sx in (-1, 1):
            parts.append(ck.ball("bar_knob%d" % sx, 0.04, top - up * 0.16 + side * 0.44 * sx, gold))
        bar_c = top - up * 0.18
        parts.append(_cloth("banner", bar_c - side * 0.4, bar_c + side * 0.4, 0.62, cloth, folds=3, depth=0.035, teeth=3, tooth=0.0))
        parts.append(_cloth("banner_hem", bar_c - side * 0.4 - V((0, 0, 0.6)), bar_c + side * 0.4 - V((0, 0, 0.6)), 0.3, cloth_d, folds=3,
                            depth=0.035, teeth=3, tooth=0.14))
        parts.append(ck.tube("banner_sun", bar_c - V((0, 0, 0.3)) + V((0, -0.05, 0)), bar_c - V((0, 0, 0.3)) + V((0, -0.07, 0)), 0.13, 0.13,
                             ck.mat("m_%s_sun" % cid, (0.96, 0.88, 0.62), 0.5), 12))
        obj = ck._join(parts, "wpn_main_staff")
        ck._smooth(obj.data)
        ck.skin_rigid(obj, base["rig"], "hand.R")
    return add


def fallen_bearer(cid="mob_fallen_bearer"):
    rig = mk.humanoid(cid, "plate", (0.32, 0.31, 0.34), "staff", skin=(0.5, 0.5, 0.52), eye=(0.95, 0.62, 0.3), hide_hair=True, head="none",
                      attack="atk_2h", extra=bearer_parts(cid), after=bearer_banner(cid))
    # o mastro de 2,3 m passa do chão em golpes e na queda: gira a mão pela frente só nos quadros em que fura (clipes só deste modelo)
    return mk.act2_bosses.clear_ground(rig, {"*": 0.03, "die": -0.2}, "hand.R", ("wpn_main_",), front=True)


# ---------------------------------------------------------------------------
# Carregador de Covas
# ---------------------------------------------------------------------------
HAULER_POSTURE = {"spine": (14, 0, 0), "chest": (10, 0, 0), "neck": (-8, 0, 0), "head": (-16, 0, 0)}
HAULER_HIPS = (0.0, 0.04, -0.02)


def hauler_parts(cid):
    def add(base, mats):
        rig, b, c, r, zc, zw, back, sw = _dims(base)
        front = -back
        sackm = ck.mat("m_%s_sack" % cid, (0.46, 0.38, 0.28), 0.9)
        sack_d = ck.mat("m_%s_sack_d" % cid, (0.32, 0.26, 0.2), 0.9)
        dirt = ck.mat("m_%s_dirt" % cid, (0.3, 0.24, 0.18), 1.0)
        rope = ck.mat("m_%s_rope" % cid, (0.62, 0.52, 0.36), 0.9)
        leather = ck.mat("m_%s_apron" % cid, (0.36, 0.25, 0.18), 0.8)
        glow = ck.mat("m_%s_eyeglow" % cid, (0.95, 0.72, 0.36), 0.3, 1.6)
        dark = ck.mat("m_%s_dark" % cid, (0.05, 0.04, 0.04), 0.6)
        head, body = [], []
        # capuz de saco com a ponta caída para trás, cara na sombra e dois olhos acesos
        head.append(ck.ball(cid + "_hood", r * 1.22, c + V((0, r * 0.14, r * 0.12)), sackm, (1.0, 1.05, 1.02)))
        head.append(cone(cid + "_hood_tip", c + V((0, r * 0.7, r * 0.7)), c + V((0, r * 1.7, r * 0.1)), r * 0.42, sackm, 6))
        head.append(ck.ball(cid + "_face", r * 0.7, c + V((0, -r * 1.0, -r * 0.08)), dark, (1.0, 0.22, 0.85)))
        for sx in (-1, 1):
            head.append(ck.ball("%s_eye%d" % (cid, sx), r * 0.11, c + V((sx * r * 0.28, -r * 1.16, r * 0.0)), glow, (1.0, 0.5, 1.0)))
        head.append(ck.tube(cid + "_hood_cord", c + V((0, 0, -r * 0.62)), c + V((0, 0, -r * 0.5)), r * 1.1, r * 1.08, rope, 10))
        # saco de terra nas costas preso por corda, terra caindo da boca do saco; avental de couro na frente
        sc = V((0, back + 0.2, zc + 0.02))
        body.append(ck.ball(cid + "_backsack", 0.2, sc, sackm, (1.15, 0.85, 1.2)))
        body.append(ck.tube(cid + "_backsack_neck", sc + V((0, 0, 0.24)), sc + V((0, 0, 0.36)), 0.08, 0.11, sack_d, 7))
        body.append(ck.ball(cid + "_backsack_dirt", 0.1, sc + V((0, 0, 0.38)), dirt, (1.2, 1.2, 0.6)))
        body.append(ck.tube(cid + "_strap", V((sw * 0.8, front - 0.02, zc + 0.2)), V((-sw * 0.6, front - 0.03, zw - 0.02)), 0.022, 0.022, rope, 5))
        body.append(ck.blade(cid + "_apron", V((0, front - 0.04, zw + 0.06)), V((0, front - 0.06, ck.Z["knee"] + 0.06)), 0.34, 0.025, leather, (1, 0, 0), 0.25))
        for sx in (-1, 1):
            body.append(ck.ball("%s_dirtpatch%d" % (cid, sx), 0.06, V((sx * 0.08, front - 0.07, zw - 0.12 + sx * 0.05)), dirt, (1.2, 0.3, 1.0)))
        _rigid(head, rig, "head")
        _rigid(body, rig, "chest")
    return add


def hauler_shovel(cid):
    """Depois das armas: a marreta do kit (mace2h) vira uma pá grande de coveiro (mesma mão e eixo)."""
    def add(base, mats):
        _drop(("wpn_main_",))
        g = V(ck.hand_center(base, ".R"))
        fwd = V((0, -0.55, 0.83)).normalized()
        wood = ck.mat("m_%s_handle" % cid, (0.42, 0.32, 0.22), 0.8)
        iron = ck.mat("m_%s_spade" % cid, (0.4, 0.4, 0.42), 0.45)
        rust = ck.mat("m_%s_rust" % cid, (0.46, 0.3, 0.2), 0.8)
        dirt = ck.mat("m_%s_dirt" % cid, (0.3, 0.24, 0.18), 1.0)
        tip0 = g + fwd * 0.78
        parts = [ck.tube("handle", g - fwd * 0.3, tip0, 0.028, 0.028, wood, 6),
                 ck.tube("grip", g - fwd * 0.36, g - fwd * 0.28, 0.06, 0.06, wood, 6),
                 ck.tube("socket", tip0 - fwd * 0.06, tip0 + fwd * 0.05, 0.035, 0.05, rust, 6),
                 ck.blade("spade", tip0, tip0 + fwd * 0.44, 0.34, 0.035, iron, (1, 0, 0), 0.62),
                 ck.blade("spade_dirt", tip0 + fwd * 0.18 - V((0, 0.02, 0)), tip0 + fwd * 0.4 - V((0, 0.02, 0)), 0.2, 0.03, dirt, (1, 0, 0), 0.5)]
        obj = ck._join(parts, "wpn_main_mace2h")
        ck._smooth(obj.data)
        ck.skin_rigid(obj, base["rig"], "hand.R")
    return add


def grave_hauler(cid="mob_grave_hauler"):
    rig = mk.humanoid(cid, "leather", (0.3, 0.26, 0.25), "mace2h", skin=(0.6, 0.55, 0.5), eye=(0.95, 0.72, 0.36), hide_hair=True, head="none",
                      body="brute", attack="atk_2h", extra=hauler_parts(cid), after=hauler_shovel(cid))
    mk.act2_bosses.posture(rig, HAULER_POSTURE, HAULER_HIPS)
    return mk.act2_bosses.clear_ground(rig, {"*": 0.03, "die": -0.2}, "hand.R", ("wpn_main_",), front=True)


# Sir Edran é chefe de campo: guarda os gestos de chefe (MOB_BOSS_KEEP: cast_ground, atk_sweep, atk_charge, summon, shout...)
mk.BOSS_HUMANOIDS.add("mob_fallen_bearer")

# nome do GLB -> construtor; HUMANOIDS saem por chibi_kit.export_glb (malha skinned)
BUILDERS = {
    "mob_oath_sworn": oath_sworn,
    "mob_fallen_bearer": fallen_bearer,
    "mob_grave_hauler": grave_hauler,
}
HUMANOIDS = set(BUILDERS)
