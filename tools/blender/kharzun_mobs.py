"""Ato II, fase 3 — Monte Kharzun (40-45; design/gdd/kharzun-fase3-plan.md §3): os 11 monstros da faixa e a montaria lobo atroz.

Horda (variantes por cima de mob_kit.horde_parts, cada uma com cabeça/ombros próprios para ler de cima):
  mob_goblin_assassin  capuz de ponta + máscara, cachecol verde, duas facas de veneno aceso
  mob_goblin_slayer    Matador: capuz negro com crista vermelha e testeira de osso, capa larga, duas lâminas de fio rubro
  mob_troll_thrower    Lança-Pedras: saco de pedras nas costas, pedregulho na mão, gorro de couro
  mob_troll_brute      Brutamontes: elmo de ferro com chifres e barbatana, ombreiras de cravos, placas nas costas, manoplas
  mob_orc_fire_archer  Arco de Fogo: crista de chamas, aljava em brasa, pote de fogo no cinto, arco de guerra de pontas em brasa, flecha acesa
  mob_orc_warlord      Senhor da Guerra: chifres de touro para a frente, gola de pele, dois estandartes negros nas costas
  mob_clan_guard       Guarda de Clã: corpo "brute", crista atravessada, viseira e escudo-torre
Nativos (peças rígidas em ossos de MOB_BONES, como os bichos de mob_kit):
  mob_dire_wolf        lobo atroz: ombro alto, cernelha de espinhos de pelo, tufos na cara, presas, olho aceso; pintura de guerra, coleira de cravos (_dw_horde)
  mob_dire_wolf_rider  o mesmo lobo com testeira e coleira de cravos + goblin de elmo de chifres, lança, rede e flâmula
  mob_lava_salamander  lagarto baixo de basalto com crista de chamas, guelras acesas e ponta do rabo em brasa
  mob_basalt_golem     golem de colunas hexagonais de basalto nas costas e fendas de lava
Montaria:
  mob_dire_wolf_mount  o lobo atroz selado; pelagem no material "tint" (FormModel.paint). Lombo/sela na altura e largura
                       do cavalo (mob_kit.horse): serve com EntityView.HORSE_SCALE e SADDLE_Y sem mudar nada. Clipes idle/run.

Clipes (EntityView._action_clip; monstro não tem weapon_type, então a skill cai nestes nomes):
  goblin_assassin  atk_charge (Passo Sombrio), atk_sweep = gesto de arremesso (Facas Envenenadas, cone de 7 m)
  goblin_slayer    atk_charge (Passo Sombrio, Execução), shout (Sumir na Fumaça)
  troll_thrower    attack = arremesso, cast_ground = arremesso (Pedregulho), atk_spin = marretada de cima (Pancada)
  troll_brute      shout (Abalo)
  orc_warlord      atk_sweep (Talho), buff_power (Grito de Guerra), shout
  clan_guard       atk_sweep (Talho Orc), block (guarda de escudo)
  dire_wolf(+rider) atk_charge (Investida Atroz), atk_leap (Bote); o ginete tem atk_throw (Rede)
  lava_salamander  cast_fire (Cuspe de Lava)
  basalt_golem     shout = pisão (Pisão de Basalto), cast_ground = punhos no chão (Fendas de Lava)

    import mob_kit; mob_kit.build_all(r"<abs>/assets/models", only=set(kharzun_mobs.BUILDERS))
"""
import math

import bpy
from mathutils import Vector

import chibi_kit as ck
import lowpoly_lib as lp
import build_monsters as bm
import mob_kit as mk

V = Vector
cone = mk.cone
blob = mk.blob

GOBLIN = (0.5, 0.64, 0.3)
ORC = (0.43, 0.53, 0.38)
TROLL = (0.45, 0.55, 0.68)


# ---------------------------------------------------------------------------
# helpers
# ---------------------------------------------------------------------------
def _strip(cid, pats):
    """Tira peças que horde_parts pôs e a variante troca (pelo começo do nome)."""
    for o in list(bpy.context.scene.objects):
        if o.type == "MESH" and any(o.name.startswith(cid + p) for p in pats):
            bpy.data.objects.remove(o, do_unlink=True)


def _rigid(objs, rig, bone):
    for o in objs:
        ck.skin_rigid(o, rig, bone)


def _alias(rig, src, dst, impact, drop=True):
    """Clipe `dst` = cópia de `src` com o impacto no quadro que o jogo espera para `dst` (EntityView.IMPACT_FRAME)."""
    tr = ck._tracks(rig)
    if src not in tr:
        print("kharzun_mobs: falta o clipe", src)
        return
    ck._retimed_copy(rig, src, dst, impact)
    if drop:
        rig.animation_data.nla_tracks.remove(ck._tracks(rig)[src])


def _nudge(rig, clip, keys):
    """Soma graus (XYZ por osso) e deslocamento do quadril ("hips_loc") às chaves que o clipe já tem nos quadros dados:
    ajuste de um clipe só deste modelo, sem mexer no clipe do kit. Nome, duração e quadro do impacto ficam iguais."""
    act = ck._tracks(rig)[clip].strips[0].action
    for fc in ck._fcurves(act):
        path = fc.data_path
        if not path.startswith('pose.bones["'):
            continue
        bone = path.split('"')[1]
        for kp in fc.keyframe_points:
            k = next((v for f, v in keys.items() if abs(kp.co.x - f) < 0.2), None)
            if k is None:
                continue
            if path.endswith("rotation_euler") and bone in k:
                d = math.radians(k[bone][fc.array_index])
            elif path.endswith("location") and bone == "hips" and "hips_loc" in k:
                d = k["hips_loc"][fc.array_index]
            else:
                continue
            kp.co.y += d
            kp.handle_left.y += d
            kp.handle_right.y += d
        fc.update()


# quadros do "attack" do Lança-Pedras (atk_throw com o impacto no 5, chibi_kit.MOB_RETIME): 2,5 = preparo, 4 = meio,
# 5 = solta, 9 = fim do embalo
THROWER_THROW = {
    2.5: {"spine": (-12, -6, 0), "chest": (-8, 0, 0), "upper_arm.L": (-25, 0, 0), "thigh.L": (-10, 0, 0), "hips_loc": (0, -0.04, -0.07)},
    4.0: {"spine": (-10, 0, 0), "upper_arm.R": (-40, 30, -45)},
    5: {"spine": (-20, 0, 0), "upper_arm.R": (-80, 60, -90), "hips_loc": (0, 0.0, 0.03)},          # pedra à frente, na altura do peito
    9: {"spine": (0, 10, 0), "upper_arm.R": (0, 60, -90), "upper_arm.L": (25, 0, -10), "thigh.R": (-12, 0, 0), "shin.R": (10, 0, 0),
        "hips_loc": (0, -0.05, 0.1)},                                                              # braço desce à frente, 0,5 m longe da perna
}


def _dims(base):
    b = base["b"]
    return (base["rig"], b, V(base["head_c"]), b["head"], ck.Z["chest"], ck.Z["waist"], b["chest"] * b["depth"], b["chest"])


# ---------------------------------------------------------------------------
# Assassinos: Assassino Goblin e Matador
# ---------------------------------------------------------------------------
def assassin_parts(cid, slayer=False):
    face = mk.horde_parts(cid, "goblin_slayer" if slayer else "goblin_assassin", GOBLIN)       # só orelhas, nariz e presas

    def add(base, mats):
        face(base, mats)
        rig, b, c, r, zc, zw, back, sw = _dims(base)
        front = -back
        dark = ck.mat("m_%s_hood" % cid, (0.13, 0.11, 0.15) if slayer else (0.2, 0.17, 0.27), 0.85)
        steel = ck.mat("m_%s_steel" % cid, (0.62, 0.64, 0.7), 0.4)
        leather = ck.mat("m_%s_strap2" % cid, (0.3, 0.2, 0.13), 0.85)
        head, body, hips = [], [], []
        # capuz: cobre o alto e a nuca, rosto aberto; ponta caída para trás
        head.append(ck.ball(cid + "_hood", r * 1.1, c + V((0, r * 0.18, r * 0.2)), dark, (1.0, 1.0, 0.8)))
        head.append(cone(cid + "_hoodtip", c + V((0, r * 0.75, r * 0.8)), c + V((0, r * 1.65, r * 0.45)), r * 0.42, dark, 7))
        if not slayer:
            venom_cloth = ck.mat("m_%s_scarf" % cid, (0.34, 0.58, 0.24), 0.8)
            venom = ck.mat("m_%s_venom" % cid, (0.5, 1.0, 0.3), 0.3, 2.2)
            # de cima: faixa verde de veneno costurada no alto do capuz (a cor do papel "assassino"; o Matador tem a crista rubra)
            head.append(ck.ball(cid + "_hoodstripe", r * 1.14, c + V((0, r * 0.18, r * 0.2)), venom_cloth, (0.2, 1.0, 0.8)))
            # máscara de pano na boca e cachecol verde de duas pontas (a marca de cima)
            head.append(ck.tube(cid + "_mask", c + V((0, -r * 0.06, -r * 0.52)), c + V((0, -r * 0.06, -r * 0.14)), r * 0.9, r * 1.03, dark, 14))
            body.append(ck.tube(cid + "_scarf", V((0, 0.01, ck.Z["neck"] - 0.07)), V((0, 0.01, ck.Z["neck"] + 0.03)), sw * 0.86, sw * 0.72, venom_cloth, 12))
            for sx in (-1, 1):
                body.append(ck.blade("%s_scarftail%d" % (cid, sx), V((sx * 0.06, back + 0.02, ck.Z["neck"] - 0.01)), V((sx * 0.3, back + 0.44, zc - 0.12)),
                                     0.2, 0.024, venom_cloth, (1, 0, 0), 0.4))
            # bandoleira de facas no peito e frasco de veneno no cinto
            p0, p1 = V((sw * 0.82, front + 0.0, zc + 0.15)), V((-sw * 0.7, front - 0.01, zw + 0.0))
            body.append(ck.tube(cid + "_bandolier", p0, p1, 0.03, 0.03, leather, 5))
            for i in range(3):
                p = p0.lerp(p1, 0.22 + 0.26 * i) + V((0, -0.035, 0.0))
                body.append(ck.blade("%s_knife%d" % (cid, i), p + V((0, 0, 0.05)), p + V((0, 0, -0.11)), 0.045, 0.014, steel, (1, 0, 0), 0.3))
            hips.append(ck.ball(cid + "_vial", 0.05, V((sw * 0.95, front * 0.4, zw - 0.03)), venom, (1, 1, 1.25)))
            hips.append(ck.tube(cid + "_vialcork", V((sw * 0.95, front * 0.4, zw + 0.03)), V((sw * 0.95, front * 0.4, zw + 0.06)), 0.022, 0.02, leather, 6))
        else:
            red = ck.mat("m_%s_red" % cid, (0.72, 0.1, 0.1), 0.7)
            bone = ck.mat("m_%s_bone" % cid, (0.92, 0.88, 0.76), 0.6)
            iron = ck.mat("m_%s_iron" % cid, (0.24, 0.24, 0.28), 0.45)
            # testeira de osso com dois chifrinhos e crista vermelha de três penas para trás
            head.append(ck.ball(cid + "_browplate", r * 0.6, c + V((0, -r * 0.6, r * 0.5)), bone, (1.25, 0.7, 0.55)))
            for sx in (-1, 1):
                head.append(cone("%s_browhorn%d" % (cid, sx), c + V((sx * r * 0.46, -r * 0.62, r * 0.66)), c + V((sx * r * 0.8, -r * 0.62, r * 1.36)), r * 0.12, bone, 6))
            for i in range(3):
                head.append(ck.blade("%s_crest%d" % (cid, i), c + V((0, r * (-0.25 + i * 0.36), r * 0.98)), c + V((0, r * (0.42 + i * 0.44), r * (1.86 - i * 0.3))),
                                     r * 0.46, r * 0.07, red, (1, 0, 0), 0.5))
            # gola alta, rolo vermelho nos ombros e capa larga rasgada em duas pontas
            body.append(ck.tube(cid + "_collar", V((0, 0.02, ck.Z["neck"] - 0.07)), V((0, 0.05, ck.Z["neck"] + 0.08)), sw * 0.9, sw * 1.2, dark, 12))
            body.append(ck.tube(cid + "_mantle", V((-sw - 0.07, 0.045, zc + 0.17)), V((sw + 0.07, 0.045, zc + 0.17)), 0.075, 0.075, red, 8))
            body.append(ck.blade(cid + "_cape", V((0, back + 0.04, zc + 0.2)), V((0, back + 0.2, ck.Z["knee"] + 0.1)), 0.78, 0.03, dark, (1, 0, 0), 0.28))
            for sx in (-1, 1):
                body.append(ck.blade("%s_capetail%d" % (cid, sx), V((sx * 0.17, back + 0.13, zw + 0.02)), V((sx * 0.25, back + 0.26, ck.Z["knee"] - 0.1)),
                                     0.3, 0.028, dark, (1, 0, 0), 0.35))
                body.append(ck.ball("%s_pauldron%d" % (cid, sx), 0.125, V((sx * (sw + 0.06), 0.0, zc + 0.15)), iron, (1.1, 1.0, 0.7)))
                body.append(cone("%s_pspike%d" % (cid, sx), V((sx * (sw + 0.08), 0, zc + 0.22)), V((sx * (sw + 0.22), 0.02, zc + 0.4)), 0.045, bone, 5))
            hips.append(ck.tube(cid + "_sash", V((0, 0, zw - 0.04)), V((0, 0, zw + 0.04)), sw * 1.04, sw * 1.04, red, 12))
        _rigid(head, rig, "head")
        _rigid(body, rig, "chest")
        _rigid(hips, rig, "hips")
    return add


def assassin_blades(cid, slayer=False):
    """Depois das armas: fio aceso por cima das lâminas do kit (veneno verde nas facas, rubro nas lâminas do Matador)."""
    def add(base, mats):
        rig = base["rig"]
        glow = ck.mat("m_%s_edge" % cid, (1.0, 0.22, 0.15) if slayer else (0.5, 1.0, 0.3), 0.3, 2.4)
        for side in (".R", ".L"):
            g = V(ck.hand_center(base, side))
            if slayer:
                f = V((0, -0.55, 0.83)).normalized()
                o = ck.blade("%s_edge%s" % (cid, side[1]), g + f * 0.16, g + f * 0.93, 0.12, 0.014, glow, (1, 0, 0), 0.62)
            else:
                f = V((0, -1, 0.3)).normalized()
                o = ck.blade("%s_edge%s" % (cid, side[1]), g + f * 0.08, g + f * 0.56, 0.11, 0.016, glow, (1, 0, 0), 0.4)
            ck.skin_rigid(o, rig, "hand" + side)
    return add


def goblin_assassin(cid="mob_goblin_assassin"):
    rig = mk.humanoid(cid, "leather", (0.25, 0.21, 0.32), "dagger", skin=GOBLIN, eye=(0.6, 1.0, 0.3), offhand="dagger", hide_hair=True, head="none",
                      keep=("atk_charge", "atk_throw"), extra=assassin_parts(cid), after=assassin_blades(cid))
    _alias(rig, "atk_throw", "atk_sweep", 8)
    return rig


def goblin_slayer(cid="mob_goblin_slayer"):
    return mk.humanoid(cid, "leather", (0.16, 0.14, 0.18), "sword", skin=(0.44, 0.58, 0.28), eye=(1.0, 0.25, 0.2), offhand="sword", hide_hair=True, head="none",
                       keep=("atk_charge", "shout"), extra=assassin_parts(cid, True), after=assassin_blades(cid, True))


# ---------------------------------------------------------------------------
# Trolls: Lança-Pedras e Brutamontes
# ---------------------------------------------------------------------------
def thrower_parts(cid):
    face = mk.horde_parts(cid, "troll_thrower", TROLL)

    def add(base, mats):
        face(base, mats)
        _strip(cid, ("_backrock",))
        rig, b, c, r, zc, zw, back, sw = _dims(base)
        front = -back
        leather = ck.mat("m_%s_sack" % cid, (0.5, 0.36, 0.2), 0.9)
        leather_d = ck.mat("m_%s_sack2" % cid, (0.32, 0.22, 0.13), 0.9)
        stone = ck.mat("m_%s_basalt" % cid, (0.29, 0.27, 0.34), 0.9)        # basalto de Kharzun: escuro contra o saco claro e a pele azulada
        stone2 = ck.mat("m_%s_basalt2" % cid, (0.19, 0.18, 0.23), 0.9)
        band = ck.mat("m_%s_band" % cid, (0.86, 0.5, 0.16), 0.8)
        bone = ck.mat("m_%s_bone" % cid, (0.92, 0.88, 0.76), 0.6)
        head, body, hips, hand, hand_l = [], [], [], [], []
        # saco de pedras nas costas: bojo, boca amarrada e pedras à mostra
        sc = V((0, back + 0.22, zc + 0.02))
        body.append(ck.ball(cid + "_sack", 0.31, sc, leather, (1.08, 0.86, 1.12)))
        body.append(ck.tube(cid + "_sackrim", sc + V((0, 0, 0.27)), sc + V((0, 0, 0.34)), 0.21, 0.235, leather_d, 10))
        body.append(ck.box(cid + "_sackpatch", (0.16, 0.03, 0.14), sc + V((0.1, 0.262, -0.02)), leather_d, 0.01))
        for i, (x, y, z_, rr) in enumerate(((-0.11, -0.03, 0.38, 0.15), (0.12, 0.0, 0.39, 0.14), (0.0, 0.1, 0.42, 0.15), (0.01, -0.06, 0.52, 0.13))):
            body.append(ck.ball("%s_sackrock%d" % (cid, i), rr, sc + V((x, y, z_)), stone if i % 2 else stone2, (1.1, 0.95, 0.85)))
        for sx in (-1, 1):                  # alças cruzadas no peito
            body.append(ck.tube("%s_sackstrap%d" % (cid, sx), V((sx * sw * 0.78, front + 0.0, zc + 0.2)), V((-sx * sw * 0.62, front - 0.02, zw + 0.03)), 0.036, 0.036, leather_d, 5))
        # gorro de couro com osso atravessado
        head.append(ck.ball(cid + "_cap", r * 1.05, c + V((0, r * 0.06, r * 0.2)), leather, (1.0, 1.0, 0.7)))
        head.append(ck.tube(cid + "_capbone", c + V((-r * 0.5, r * 0.25, r * 0.92)), c + V((r * 0.5, r * 0.25, r * 0.92)), r * 0.09, r * 0.09, bone, 6))
        for sx in (-1, 1):
            head.append(ck.ball("%s_capknob%d" % (cid, sx), r * 0.13, c + V((sx * r * 0.54, r * 0.25, r * 0.92)), bone))
        # faixa laranja no gorro e na boca do saco: a cor de "atira de longe" da faixa 40-45 (o Arco de Fogo tem a chama)
        head.append(ck.tube(cid + "_capband", c + V((0, r * 0.06, r * 0.26)), c + V((0, r * 0.06, r * 0.4)), r * 1.09, r * 1.04, band, 12))
        body.append(ck.tube(cid + "_sackband", sc + V((0, 0, 0.2)), sc + V((0, 0, 0.26)), 0.27, 0.235, band, 10))
        for i in range(3):                  # pedras de reserva no cinto
            a = math.radians(50 + i * 34)
            hips.append(ck.ball("%s_beltrock%d" % (cid, i), 0.075, V((math.sin(a) * sw * 1.12, -math.cos(a) * back * 1.15, zw - 0.01)), stone if i % 2 else stone2, (1, 1, 0.85)))
        # pedregulho na mão direita
        g = V(ck.hand_center(base, ".R"))
        hand.append(ck.ball(cid + "_boulder", 0.24, g + V((-0.06, -0.15, -0.06)), stone, (1.0, 0.95, 0.86)))
        hand.append(ck.ball(cid + "_boulder2", 0.11, g + V((-0.15, -0.22, 0.12)), stone2, (1.0, 0.9, 0.9)))
        gl = V(ck.hand_center(base, ".L"))  # a próxima pedra já na esquerda
        hand_l.append(ck.ball(cid + "_boulderL", 0.19, gl + V((0.05, -0.12, -0.06)), stone2, (1.0, 0.92, 0.88)))
        _rigid(head, rig, "head")
        _rigid(body, rig, "chest")
        _rigid(hips, rig, "hips")
        _rigid(hand, rig, "hand.R")
        _rigid(hand_l, rig, "hand.L")
    return add


def troll_thrower(cid="mob_troll_thrower"):
    rig = mk.humanoid(cid, "leather", (0.42, 0.32, 0.2), None, skin=TROLL, eye=(0.95, 0.8, 0.25), hide_hair=True, head="none", attack="atk_throw",
                      keep=("atk_throw", "atk_2h"), extra=thrower_parts(cid), body="troll", posture=mk.TROLL_STANCE)
    _alias(rig, "atk_throw", "cast_ground", 10)
    _alias(rig, "atk_2h", "atk_spin", 8)
    # arremesso só dele (o "attack" é cópia do atk_throw do kit, impacto no quadro 5): preparo mais fundo, solta com o braço
    # alto e o braço segue descendo por fora da coxa (antes a pose de soltar ficava parada 4 quadros com a pedra na perna)
    _nudge(rig, "attack", THROWER_THROW)
    return rig


def brute_parts(cid):
    face = mk.horde_parts(cid, "troll_brute", (0.4, 0.48, 0.62))

    def add(base, mats):
        face(base, mats)
        _strip(cid, ("_rock", "_backrock"))
        rig, b, c, r, zc, zw, back, sw = _dims(base)
        front = -back
        j = base["j"]
        iron = ck.mat("m_%s_iron2" % cid, (0.3, 0.31, 0.36), 0.42)
        iron_d = ck.mat("m_%s_iron3" % cid, (0.19, 0.19, 0.23), 0.5)
        red = ck.mat("m_%s_red2" % cid, (0.74, 0.14, 0.1), 0.7)
        head, body, arms = [], [], {".R": [], ".L": []}
        # elmo de ferro: casquete, aba, nasal, barbatana de frente para trás e dois chifres curtos
        head.append(ck.ball(cid + "_helm", r * 1.09, c + V((0, r * 0.05, r * 0.22)), iron, (1.0, 1.0, 0.74)))
        head.append(ck.tube(cid + "_helmrim", c + V((0, 0, r * 0.2)), c + V((0, 0, r * 0.32)), r * 1.13, r * 1.11, iron_d, 14))
        head.append(ck.box(cid + "_nasal", (r * 0.2, r * 0.1, r * 0.5), c + V((0, -r * 1.07, r * 0.28)), iron_d, 0.01))
        head.append(ck.blade(cid + "_helmfin", c + V((0, -r * 0.8, r * 0.98)), c + V((0, r * 1.0, r * 0.92)), r * 0.72, r * 0.1, iron_d, (0, 0, 1), 0.4))
        for sx in (-1, 1):
            head.append(cone("%s_helmhorn%d" % (cid, sx), c + V((sx * r * 0.9, 0, r * 0.52)), c + V((sx * r * 1.55, -r * 0.12, r * 0.95)), r * 0.19, iron_d, 6))
        # ombreiras em duas camadas com cravos, cinta no peito, placa na barriga, placas de ferro na espinha
        for sx in (-1, 1):
            body.append(ck.ball("%s_pauldron%d" % (cid, sx), 0.25, V((sx * (sw + 0.07), 0.0, zc + 0.2)), iron, (1.2, 1.1, 0.72)))
            body.append(ck.ball("%s_pauldron%db" % (cid, sx), 0.2, V((sx * (sw + 0.19), 0.0, zc + 0.09)), iron_d, (1.05, 1.05, 0.6)))
            for k, (dx, dy) in enumerate(((0.02, -0.12), (0.1, 0.0), (0.02, 0.12))):
                p = V((sx * (sw + 0.07 + dx), dy, zc + 0.33))
                body.append(cone("%s_pspike%d_%d" % (cid, sx, k), p, p + V((sx * (0.06 + dx), dy * 0.6, 0.2)), 0.055, iron_d, 5))
        body.append(ck.tube(cid + "_chestband", V((0, 0, zc - 0.03)), V((0, 0, zc + 0.09)), sw * 1.1, sw * 1.1, iron_d, 12))
        body.append(ck.ball(cid + "_bellyplate", 0.21, V((0, front - 0.035, zw + 0.09)), iron, (1.0, 0.42, 0.95)))
        body.append(ck.ball(cid + "_bellymark", 0.075, V((0, front - 0.115, zw + 0.1)), red, (1.2, 0.4, 0.8)))
        for k in range(4):
            t = k / 3
            z0 = zw + 0.08 + t * (zc + 0.2 - zw)
            body.append(ck.blade("%s_spine%d" % (cid, k), V((0, back + 0.0, z0)), V((0, back + 0.26 - 0.04 * abs(k - 2), z0 + 0.12)), 0.2, 0.05, iron_d if k % 2 else iron, (0, 0, 1), 0.45))
        for s in (".R", ".L"):              # manoplas
            e, w = V(j["elbow" + s]), V(j["wrist" + s])
            arms[s].append(ck.tube("%s_gauntlet%s" % (cid, s[1]), e.lerp(w, 0.3), w, b["elbow"] * 1.5, b["wrist"] * 1.6, iron, 8))
            arms[s].append(ck.tube("%s_gauntletrim%s" % (cid, s[1]), e.lerp(w, 0.24), e.lerp(w, 0.36), b["elbow"] * 1.72, b["elbow"] * 1.72, iron_d, 8))
        _rigid(head, rig, "head")
        _rigid(body, rig, "chest")
        for s in arms:
            _rigid(arms[s], rig, "forearm" + s)
    return add


def troll_brute(cid="mob_troll_brute"):
    rig = mk.humanoid(cid, "plate", (0.3, 0.31, 0.36), "mace2h", skin=(0.4, 0.48, 0.62), eye=(1.0, 0.6, 0.18), hide_hair=True, head="none",
                      keep=("shout",), extra=brute_parts(cid), body="troll", posture=mk.TROLL_STANCE)
    return mk.act2_bosses.clear_ground(rig, mk.TROLL_MAUL_CLEAR, "hand.R", ("wpn_main_",), front=True)      # postura de troll + golpe de cima: a marreta entrava 0,8 m no chão


# ---------------------------------------------------------------------------
# Orcs: Arco de Fogo, Senhor da Guerra, Guarda de Clã
# ---------------------------------------------------------------------------
def _fire_mats(cid):
    return ck.mat("m_%s_ember" % cid, (1.0, 0.42, 0.08), 0.4, 2.2), ck.mat("m_%s_hot" % cid, (1.0, 0.8, 0.25), 0.4, 3.0)


def fire_archer_parts(cid):
    face = mk.horde_parts(cid, "orc_archer", ORC)           # capuz, alça e aljava com penas vermelhas

    def add(base, mats):
        face(base, mats)
        _strip(cid, ("_topknot", "_hood"))
        rig, b, c, r, zc, zw, back, sw = _dims(base)
        ember, hot = _fire_mats(cid)
        soot = ck.mat("m_%s_soot" % cid, (0.2, 0.15, 0.13), 0.85)
        iron = ck.mat("m_%s_iron2" % cid, (0.26, 0.26, 0.3), 0.45)
        leather = ck.mat("m_%s_strap2" % cid, (0.3, 0.2, 0.13), 0.85)
        head, body, hips = [], [], []
        # capuz de fuligem, testeira de ferro e crista de chamas do rosto à nuca
        head.append(ck.ball(cid + "_hood", r * 1.1, c + V((0, r * 0.18, r * 0.2)), soot, (1.0, 1.0, 0.8)))
        head.append(ck.tube(cid + "_browband", c + V((0, r * 0.1, r * 0.22)), c + V((0, r * 0.1, r * 0.36)), r * 1.13, r * 1.11, iron, 14))
        for i in range(5):          # línguas gordas (cone): de cima a lâmina fina sumia
            p = c + V((0, r * (-0.72 + i * 0.4), r * (0.82 + 0.1 * math.sin(i * 0.8))))
            tip = p + V((0, r * 0.55, r * (1.55 - 0.14 * i)))
            head.append(cone("%s_flame%d" % (cid, i), p, tip, r * 0.36, ember, 6))
            head.append(cone("%s_flamecore%d" % (cid, i), p + V((0, -r * 0.1, r * 0.05)), p.lerp(tip, 0.6) + V((0, -r * 0.12, 0)), r * 0.24, hot, 5))
        # brasas na boca da aljava
        q1 = V((0.2, back + 0.1, zc + 0.24))
        body.append(ck.ball(cid + "_quiverglow", 0.085, q1 + V((0, 0, 0.0)), hot, (1, 1, 0.6)))
        for k in range(3):
            p = q1 + V(((k - 1) * 0.05, 0.02 * (k % 2), 0.02))
            body.append(cone("%s_quiverflame%d" % (cid, k), p, p + V(((k - 1) * 0.04, 0.03, 0.2 + 0.05 * (k % 2))), 0.045, ember if k % 2 else hot, 6))
        # ombreira de couro no ombro do arco com três penas em brasa
        sh = V((-(sw + 0.05), 0.0, zc + 0.14))
        body.append(ck.ball(cid + "_pauldron", 0.15, sh, leather, (1.15, 1.05, 0.7)))
        for k in range(3):
            a = math.radians(-40 + k * 40)
            body.append(ck.blade("%s_emberfeather%d" % (cid, k), sh + V((0, 0, 0.06)), sh + V((-0.2 * math.cos(a), 0.2 * math.sin(a), 0.2)), 0.1, 0.02,
                                 ember if k % 2 else hot, (math.sin(a), math.cos(a), 0), 0.5))
        # pote de fogo no cinto
        pp = V((-sw * 1.0, 0.03, zw - 0.15))
        hips.append(ck.tube(cid + "_firepot", pp, pp + V((0, 0, 0.13)), 0.075, 0.09, iron, 8))
        hips.append(ck.ball(cid + "_firepotglow", 0.08, pp + V((0, 0, 0.14)), hot, (1, 1, 0.55)))
        hips.append(cone(cid + "_firepotflame", pp + V((0, 0, 0.15)), pp + V((0, 0.02, 0.3)), 0.05, ember, 6))
        _rigid(head, rig, "head")
        _rigid(body, rig, "chest")
        _rigid(hips, rig, "hips")
    return add


def fire_arrow(cid):
    """Depois do arco: troca o arco fino do kit por um arco de guerra recurvo (grosso, mais longo, pontas enroladas em
    brasa: o papel de atirador tem de aparecer a 52 graus) e põe a flecha acesa na mão do arco."""
    def add(base, mats):
        ember, hot = _fire_mats(cid)
        horn = ck.mat("m_%s_bowhorn" % cid, (0.2, 0.14, 0.11), 0.7)
        iron = ck.mat("m_%s_iron2" % cid, (0.26, 0.26, 0.3), 0.45)
        old = bpy.data.objects.get("wpn_main_bow")
        if old:
            bpy.data.objects.remove(old, do_unlink=True)
        g = V(ck.hand_center(base, ".L"))
        H, D = 0.62, 0.17                      # meia altura e barriga (kit: 0,45 / 0,12)
        ts = [i / 4 - 1 for i in range(9)]
        pts = [g + V((0.0, -D * (1 - t * t) + 0.02 - 0.09 * max(0.0, abs(t) - 0.75) / 0.25, t * H)) for t in ts]   # pontas recurvas
        rad = [0.05 - 0.02 * abs(t) for t in ts]
        bow = [ck.tube("limb%d" % i, pts[i], pts[i + 1], rad[i], rad[i + 1], horn, 6) for i in range(8)]
        bow.append(ck.tube("grip", pts[4] + V((0, 0, -0.08)), pts[4] + V((0, 0, 0.08)), 0.058, 0.058, iron, 6))
        bow.append(ck.tube("string", pts[0], pts[-1], 0.008, 0.008, ck.mat("m_string", (0.95, 0.95, 0.9)), 4))
        for k, i in enumerate((2, 6)):         # amarras em brasa no meio de cada pá
            bow.append(ck.tube("limbwrap%d" % k, pts[i].lerp(pts[i - 1], 0.25), pts[i].lerp(pts[i + 1], 0.25), 0.056, 0.056, ember, 6))
        for k, i in enumerate((0, 8)):         # pontas do arco enroladas em brasa
            sz = -1 if i == 0 else 1
            bow.append(ck.ball("tipwrap%d" % k, 0.07, pts[i], ember, (1, 1, 1.2)))
            bow.append(cone("tipflame%d" % k, pts[i], pts[i] + V((0, 0.05, 0.26 if sz > 0 else 0.16)), 0.062, hot, 6))
        obj = ck._join(bow, "wpn_main_bow")
        ck._smooth(obj.data)
        ck.skin_rigid(obj, base["rig"], "hand.L")
        parts = [ck.tube(cid + "_arrow", g + V((0, 0.3, 0.0)), g + V((0, -0.44, 0.0)), 0.018, 0.018, mats["wood"], 5),
                 cone(cid + "_arrowhead", g + V((0, -0.4, 0.0)), g + V((0, -0.62, 0.0)), 0.06, hot, 6),
                 cone(cid + "_arrowflame", g + V((0, -0.47, 0.01)), g + V((0, -0.4, 0.32)), 0.085, ember, 6),
                 cone(cid + "_arrowflamecore", g + V((0, -0.5, 0.01)), g + V((0, -0.46, 0.19)), 0.055, hot, 5)]
        _rigid(parts, base["rig"], "hand.L")
    return add


def orc_fire_archer(cid="mob_orc_fire_archer"):
    return mk.humanoid(cid, "leather", (0.36, 0.2, 0.14), "bow", skin=ORC, eye=(1.0, 0.6, 0.15), hide_hair=True, head="none",
                       extra=fire_archer_parts(cid), after=fire_arrow(cid))


def warlord_parts(cid):
    face = mk.horde_parts(cid, "orc_warrior", ORC)          # elmo de ferro com aba vermelha, duas ombreiras de cravo, alça

    def add(base, mats):
        face(base, mats)
        _strip(cid, ("_helmspike",))
        rig, b, c, r, zc, zw, back, sw = _dims(base)
        front = -back
        horn = ck.mat("m_%s_horn" % cid, (0.93, 0.89, 0.76), 0.55)
        fur = ck.mat("m_%s_fur" % cid, (0.3, 0.24, 0.2), 0.95)
        fur2 = ck.mat("m_%s_fur2" % cid, (0.46, 0.4, 0.34), 0.95)
        black = ck.mat("m_%s_flag" % cid, (0.1, 0.09, 0.11), 0.8)
        red = ck.mat("m_%s_red2" % cid, (0.8, 0.14, 0.12), 0.7)
        wood = ck.mat("m_%s_wood2" % cid, (0.42, 0.3, 0.2), 0.8)
        head, body, hips = [], [], []
        # chifres de touro que saem do lado do elmo e viram para a frente; rabo de crina negra no alto
        for sx in (-1, 1):
            h0 = c + V((sx * r * 0.82, -r * 0.05, r * 0.58))
            h1 = h0 + V((sx * r * 0.55, -r * 0.2, r * 0.18))
            head.append(ck.tube("%s_horn%da" % (cid, sx), h0, h1, r * 0.19, r * 0.15, horn, 7))
            head.append(cone("%s_horn%db" % (cid, sx), h1, h1 + V((sx * r * 0.02, -r * 0.62, r * 0.42)), r * 0.15, horn, 7))
        head.append(ck.blade(cid + "_helmtail", c + V((0, r * 0.2, r * 1.0)), c + V((0, r * 1.6, r * 0.25)), r * 0.42, r * 0.12, black, (1, 0, 0), 0.4))
        head.append(ck.ball(cid + "_helmknot", r * 0.2, c + V((0, r * 0.2, r * 1.0)), red))
        # gola de pele de ombro a ombro pelas costas
        n = 7
        for i in range(n):
            a = math.radians(-100 + i * 200 / (n - 1))
            p = V((math.sin(a) * (sw + 0.09), 0.02 + math.cos(a) * (back + 0.07), zc + 0.2))
            body.append(ck.ball("%s_fur%d" % (cid, i), 0.115, p, fur if i % 2 else fur2, (1.0, 1.0, 0.78)))
        # dois estandartes negros nas costas (mastros abertos em V, flâmula com a presa da Horda e ponta vermelha)
        for sx in (-1, 1):
            p0 = V((sx * 0.1, back + 0.06, zw + 0.04))
            p1 = V((sx * 0.46, back + 0.34, c.z + r * 1.2))
            body.append(ck.tube("%s_pole%d" % (cid, sx), p0, p1, 0.026, 0.022, wood, 6))
            body.append(cone("%s_poletip%d" % (cid, sx), p1, p1 + V((sx * 0.03, 0.02, 0.13)), 0.04, horn, 5))
            f0, f1 = p1 + V((0, 0.02, -0.04)), p1 + V((sx * 0.03, 0.09, -0.6))
            body.append(ck.blade("%s_flag%d" % (cid, sx), f0, f1, 0.27, 0.024, black, (1, 0, 0), 0.3))
            body.append(ck.blade("%s_flagtip%d" % (cid, sx), f0.lerp(f1, 0.72) + V((0, 0.012, 0)), f1 + V((0, 0.02, -0.07)), 0.13, 0.022, red, (1, 0, 0), 0.3))
            body.append(ck.ball("%s_flagtusk%d" % (cid, sx), 0.06, f0.lerp(f1, 0.33) + V((0, 0.02, 0)), horn, (1.0, 0.35, 1.2)))
        # caveira no cinto
        hips.append(ck.ball(cid + "_beltskull", 0.08, V((0, front - 0.055, zw - 0.03)), horn, (1.0, 0.7, 1.0)))
        for sx in (-1, 1):
            hips.append(cone("%s_belttusk%d" % (cid, sx), V((sx * 0.05, front - 0.09, zw - 0.07)), V((sx * 0.1, front - 0.12, zw + 0.03)), 0.022, horn, 5))
        _rigid(head, rig, "head")
        _rigid(body, rig, "chest")
        _rigid(hips, rig, "hips")
    return add


def orc_warlord(cid="mob_orc_warlord"):
    return mk.humanoid(cid, "plate", (0.21, 0.2, 0.24), "axe2h", skin=ORC, eye=(1.0, 0.45, 0.15), hide_hair=True, head="none",
                       keep=("atk_sweep", "buff_power", "shout"), extra=warlord_parts(cid))


def guard_parts(cid):
    face = mk.horde_parts(cid, "orc_warrior", (0.4, 0.5, 0.36))

    def add(base, mats):
        face(base, mats)
        _strip(cid, ("_helmspike",))
        rig, b, c, r, zc, zw, back, sw = _dims(base)
        iron = ck.mat("m_%s_iron2" % cid, (0.27, 0.27, 0.31), 0.45)
        bronze = ck.mat("m_%s_bronze" % cid, (0.72, 0.5, 0.24), 0.4)
        red = ck.mat("m_%s_red2" % cid, (0.78, 0.14, 0.12), 0.7)
        head, body = [], []
        # viseira sobre a testa, guardas de bochecha e crista atravessada (de orelha a orelha) com base de bronze
        head.append(ck.ball(cid + "_visor", r * 0.72, c + V((0, -r * 0.5, r * 0.44)), iron, (1.25, 0.8, 0.5)))
        for sx in (-1, 1):
            head.append(ck.ball("%s_cheek%d" % (cid, sx), r * 0.36, c + V((sx * r * 0.8, -r * 0.45, -r * 0.22)), iron, (0.5, 0.9, 1.15)))
        # casco de bronze por cima do elmo de ferro (de cima: bronze + vermelho = elite da cidadela; o Guerreiro é ferro liso)
        head.append(ck.ball(cid + "_helmcap", r * 1.1, c + V((0, r * 0.04, r * 0.36)), bronze, (1.0, 1.0, 0.62)))
        head.append(ck.tube(cid + "_crestbase", c + V((-r * 0.9, r * 0.05, r * 0.98)), c + V((r * 0.9, r * 0.05, r * 0.98)), r * 0.14, r * 0.14, iron, 6))
        head.append(ck.blade(cid + "_crest", c + V((-r * 1.3, r * 0.05, r * 0.86)), c + V((r * 1.3, r * 0.05, r * 0.86)), r * 0.5, r * 0.14, red, (0, 0, 1), 0.5))
        for i, x in enumerate((-0.92, -0.46, 0.0, 0.46, 0.92)):     # leque de cinco penas rubras, a do meio mais alta
            hgt = 1.0 - abs(x) * 0.42
            head.append(ck.blade("%s_crestfan%d" % (cid, i), c + V((x * r * 0.9, r * 0.05, r * 0.95)), c + V((x * r * 1.5, r * 0.12, r * (1.0 + hgt * 0.95))),
                                 r * 0.5, r * 0.12, red, (1, 0, 0), 0.5))
        # gorjal e placa de bronze no peito
        body.append(ck.tube(cid + "_gorget", V((0, 0, ck.Z["neck"] - 0.08)), V((0, 0, ck.Z["neck"] + 0.05)), sw * 0.82, sw * 0.62, iron, 12))
        body.append(ck.ball(cid + "_chestmark", 0.085, V((0, -back - 0.05, zc + 0.06)), bronze, (1.0, 0.4, 1.0)))
        for k in range(3):                  # placas nas costas
            z0 = zw + 0.1 + k * 0.12
            body.append(ck.box("%s_backplate%d" % (cid, k), (sw * 1.5 - k * 0.04, 0.05, 0.1), (0, back + 0.045, z0), iron if k % 2 else bronze, 0.01))
        for sx in (-1, 1):                  # ombreiras de bronze em duas lâminas sobre as de ferro
            body.append(ck.ball("%s_gpauldron%d" % (cid, sx), 0.17, V((sx * (sw + 0.08), 0.0, zc + 0.22)), bronze, (1.1, 1.1, 0.62)))
            body.append(ck.ball("%s_gpauldron%db" % (cid, sx), 0.13, V((sx * (sw + 0.17), 0.0, zc + 0.13)), iron, (1.0, 1.15, 0.55)))
        # insígnia de clã nas costas (marca de elite vista de cima e por trás): haste de ferro, travessa e flâmula rubra de
        # duas pontas com as presas da Horda em bronze. Era um disco de bronze com um olho rubro acima da crista: de frente
        # lia como uma segunda cabeça flutuando (art review 19). A haste desce um pouco e o pano pende ATRÁS da crista.
        p0 = V((0, back + 0.08, zw + 0.1))
        p1 = V((0, back + 0.32, c.z + r * 1.42))
        body.append(ck.tube(cid + "_sigpole", p0, p1, 0.034, 0.03, iron, 6))
        body.append(ck.tube(cid + "_sigbar", p1 + V((-0.27, 0, -0.02)), p1 + V((0.27, 0, -0.02)), 0.028, 0.028, iron, 6))
        body.append(cone(cid + "_sigtip", p1 + V((0, 0, 0.0)), p1 + V((0, 0, 0.2)), 0.05, iron, 5))
        body.append(ck.box(cid + "_sigcloth", (0.46, 0.024, 0.36), p1 + V((0, 0.02, -0.22)), red))
        body.append(ck.box(cid + "_sigtrim", (0.5, 0.034, 0.06), p1 + V((0, 0.02, -0.06)), bronze))
        for sx in (-1, 1):
            body.append(ck.blade("%s_sigribbon%d" % (cid, sx), p1 + V((sx * 0.115, 0.02, -0.38)), p1 + V((sx * 0.15, 0.05, -0.64)), 0.2, 0.022, red, (1, 0, 0), 0.25))
            for sy in (-1, 1):              # presas nas duas faces do pano
                body.append(cone("%s_sigfang%d_%d" % (cid, sx, sy), p1 + V((sx * 0.1, 0.02 + sy * 0.02, -0.13)), p1 + V((sx * 0.05, 0.02 + sy * 0.02, -0.36)), 0.045, bronze, 5))
        _rigid(head, rig, "head")
        _rigid(body, rig, "chest")
    return add


def tower_shield(cid):
    """Depois das armas: troca o escudo do kit pelo escudo-torre (tábua alta ferrada, cravos em cima, olho da Horda)."""
    def add(base, mats):
        g = V(ck.hand_center(base, ".R"))
        for o in list(bpy.context.scene.objects):
            if o.name.startswith("wpn_off_"):
                bpy.data.objects.remove(o, do_unlink=True)
            elif o.name.startswith("wpn_main_"):        # o machado de uma mão some no corpo "brute": 1,5x em volta da mão
                gl = o.matrix_world.inverted() @ g
                for vert in o.data.vertices:
                    vert.co = gl + (vert.co - gl) * 1.5
        wood = ck.mat("m_%s_shieldwood" % cid, (0.34, 0.24, 0.16), 0.85)
        iron = ck.mat("m_%s_iron2" % cid, (0.27, 0.27, 0.31), 0.45)
        bronze = ck.mat("m_%s_bronze" % cid, (0.72, 0.5, 0.24), 0.4)
        red = ck.mat("m_%s_red2" % cid, (0.78, 0.14, 0.12), 0.7)
        w, hgt = 0.6, 0.98
        parts = [ck.box("ts_board", (w, 0.07, hgt), (0, 0, 0), wood, 0.02),
                 ck.box("ts_rimtop", (w + 0.05, 0.1, 0.09), (0, 0, hgt * 0.5 - 0.03), iron, 0.012),
                 ck.box("ts_rimlow", (w + 0.05, 0.1, 0.09), (0, 0, -hgt * 0.5 + 0.03), iron, 0.012),
                 ck.box("ts_band", (0.1, 0.095, hgt - 0.1), (0, -0.004, 0), iron, 0.01),
                 ck.box("ts_cross", (w, 0.09, 0.08), (0, -0.004, 0.17), iron, 0.01),
                 ck.ball("ts_boss", 0.12, (0, -0.06, 0.17), bronze, (1.0, 0.55, 1.0)),
                 ck.ball("ts_eye", 0.1, (0, -0.05, -0.2), red, (1.5, 0.3, 0.75)),
                 ck.ball("ts_pupil", 0.04, (0, -0.075, -0.2), iron, (0.6, 0.4, 1.3))]
        for sx in (-1, 0, 1):
            parts.append(cone("ts_spike%d" % sx, (sx * 0.22, 0, hgt * 0.5), (sx * 0.22, 0, hgt * 0.5 + (0.2 if sx == 0 else 0.15)), 0.045, iron, 5))
        for sx in (-1, 1):
            for sz in (-1, 1):
                parts.append(ck.ball("ts_rivet%d_%d" % (sx, sz), 0.03, (sx * 0.2, -0.04, sz * 0.32 + 0.0), bronze))
        obj = ck._join(parts, "wpn_off_shield")
        rot = ck._shield_rot().to_4x4()
        cen = ck._shield_anchor(base)[1]
        for vert in obj.data.vertices:
            vert.co = rot @ (vert.co + V((0, 0, 0.16))) + cen     # 0,16: a quina de baixo não raspa o chão parado/andando
        ck._smooth(obj.data)
        ck.skin_rigid(obj, base["rig"], "forearm.L")
    return add


def clan_guard(cid="mob_clan_guard"):
    rig = mk.humanoid(cid, "plate", (0.5, 0.34, 0.2), "axe", skin=(0.4, 0.5, 0.36), eye=(1.0, 0.4, 0.15), offhand="shield", hide_hair=True, head="none",
                      keep=("atk_sweep",), extra=guard_parts(cid), after=tower_shield(cid), body="brute")
    # no golpe largo (e correndo, lançando, em guarda) o braço do escudo desce: a quina do escudo-torre afundava no chão (só neste modelo)
    return mk.act2_bosses.clear_ground(rig, {"atk_sweep": 0.01, "run": 0.0, "cast": 0.0, "block": 0.0, "die": -0.2}, "forearm.L", ("wpn_off_shield",))


# ---------------------------------------------------------------------------
# Lobo atroz: bicho, com ginete, montaria
# ---------------------------------------------------------------------------
DW_HIP = 0.56          # lombo na altura do cavalo (mob_kit.HIP 0,58): a mesma sela/escala servem
DW_MOUNT_FWD = 0.12    # montaria: o lobo inteiro vai 0,12 para a frente e a sela fica na origem (o jogo senta o boneco em
                       # y = 0): o cavaleiro cai no lombo, atrás da juba, em vez de colado no pescoço (art review r2, item 6)
DW_SADDLE_PARTS = ("dw_blanket", "dw_saddle", "dw_cantle", "dw_girth", "dw_pommel")


def _dw_top(y, h):
    """Altura do dorso do lobo atroz em y (para pousar espinhos de pelo, sela e ginete)."""
    pts = ((-0.6, h + 0.4), (-0.3, h + 0.35), (0.1, h + 0.21), (0.46, h + 0.16))
    if y <= pts[0][0]:
        return pts[0][1]
    for (y0, z0), (y1, z1) in zip(pts, pts[1:]):
        if y <= y1:
            return z0 + (z1 - z0) * (y - y0) / (y1 - y0)
    return pts[-1][1]


def dire_wolf(cid="mob_dire_wolf", rider=False, mount=False, mother=False, chief=False):
    """mother = Presa-de-Cinza (chefe): juba e espinhos de cinza, cicatrizes, olho cego, presas longas, lanças quebradas
    no lombo. chief = Ulgra Presa-Atroz montada (_dw_chief) num lobo negro de guerra."""
    h = DW_HIP
    rider = rider or chief
    fy = -DW_MOUNT_FWD if mount else 0.0          # os pivôs andam junto com as peças (mesma direção e tamanho dos ossos)
    bones = mk.pivots(head=(0, -0.56 + fy, h + 0.2), leg_fr=(0.2, -0.38 + fy, h - 0.04), leg_fl=(-0.2, -0.38 + fy, h - 0.04),
                      leg_br=(0.2, 0.4 + fy, h - 0.04), leg_bl=(-0.2, 0.4 + fy, h - 0.04))
    bones["tail"] = ((0, 0.52 + fy, h + 0.1), (0, 0.92 + fy, h + 0.16), "body")
    seat = V((0, 0.02, h + 0.34))
    net_sh = seat + (V((0.25, -0.02, 0.46)) if chief else V((0.18, -0.02, 0.32)))
    if rider:
        bones["rider"] = (tuple(seat), tuple(seat + V((0, 0, 0.6))), "body")
        bones["rider_arm"] = (tuple(net_sh), tuple(net_sh + V((0, 0, -0.3))), "rider")
    arm = lp.make_armature("rig_" + cid, bones)
    fur = ck.mat("tint" if mount else "m_%s_fur" % cid, (0.2, 0.19, 0.21) if chief else (0.3, 0.29, 0.31) if rider else (0.38, 0.36, 0.37) if mother else (0.44, 0.44, 0.48), 0.85)
    if mount:                 # "tint" pode já existir no arquivo (cavalo): a pelagem padrão é a do lobo
        bsdf = next(n for n in fur.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
        bsdf.inputs["Base Color"].default_value = (0.44, 0.44, 0.48, 1.0)
    dark = ck.mat("m_%s_dark" % cid, (0.17, 0.16, 0.19), 0.85)
    light = ck.mat("m_%s_light" % cid, (0.74, 0.73, 0.72), 0.85)
    mane = ck.mat("m_%s_ash" % cid, (0.86, 0.84, 0.8), 0.85) if mother else dark
    fang = ck.mat("m_%s_fang" % cid, (0.96, 0.93, 0.82), 0.5)
    m_eye, m_white = mk.base_mats()
    glow = ck.mat("m_%s_eyeglow" % cid, (1.0, 0.36, 0.1) if mother else (1.0, 0.7, 0.15), 0.3, 2.6)
    parts = []
    # tronco: garupa estreita, peito fundo e ombro alto
    k = 1.0 if mount else 1.16          # a montaria fica na largura do cavalo; o bicho é mais encorpado
    pts = [((0, 0.46, h + 0.0), 0.17 * k), ((0, 0.1, h + 0.0), 0.19 * k), ((0, -0.3, h + 0.07), 0.26 * k), ((0, -0.58, h + 0.24), 0.17 * k)]
    parts.append((mk.skin_body("dw_trunk", pts, [(0, 1), (1, 2), (2, 3)], fur), "body"))
    parts.append((blob("dw_belly", 0.18 * k, (0, -0.06, h - 0.13), light, (0.85, 2.0, 0.6)), "body"))
    if mount:                 # juba baixa e curta: de cima ela não pode tapar o tronco de quem monta
        parts.append((blob("dw_mane", 0.21, (0, -0.52, h + 0.2), mane, (1.2, 0.9, 0.95)), "body"))
    else:
        parts.append((blob("dw_mane", 0.3 if mother else 0.27, (0, -0.5, h + 0.24), mane, (1.15, 0.9, 1.0)), "body"))
    for sx in (-1, 1):
        parts.append((blob("dw_shoulder%d" % sx, 0.16 * k, (sx * 0.2, -0.36, h + 0.0), fur, (0.8, 1.15, 1.45)), "body"))
        parts.append((blob("dw_haunch%d" % sx, 0.16 * k, (sx * 0.17, 0.38, h - 0.04), fur, (0.8, 1.25, 1.45)), "body"))
    # cernelha: espinhos de pelo escuro do pescoço à garupa (montado: fica livre o lugar da sela)
    for i, y in enumerate((-0.66, -0.53, -0.4, -0.27, -0.12, 0.04, 0.2, 0.36)):
        if (mount or rider) and -0.3 < y < 0.3:
            continue
        hgt = (0.24 - 0.016 * i * (1.6 if i > 3 else 1.0)) * (1.4 if mother else 0.55 if mount else 1.0)
        z0 = _dw_top(y, h) - (0.1 if mount else 0.05)
        parts.append((cone("dw_hackle%d" % i, (0, y, z0), (0, y + 0.1, z0 + hgt), 0.085, mane, 6), "body"))
    # cabeça larga: tufos na cara, focinho comprido, queixo escuro, presas
    hc = V((0, -0.82, h + 0.36))
    parts.append((blob("dw_skull", 0.23, hc, fur, (1.0, 1.05, 0.9)), "head"))
    parts.append((blob("dw_snout", 0.15, hc + V((0, -0.24, -0.05)), light, (0.68, 1.15, 0.6)), "head"))
    parts.append((blob("dw_jaw", 0.11, hc + V((0, -0.2, -0.14)), dark, (0.66, 1.1, 0.42)), "head"))
    parts.append((blob("dw_nose", 0.05, hc + V((0, -0.4, -0.02)), dark), "head"))
    parts.append((blob("dw_brow", 0.12, hc + V((0, -0.14, 0.13)), dark, (1.5, 0.7, 0.4)), "head"))
    for sx in (-1, 1):
        parts.append((cone("dw_ear%d" % sx, hc + V((sx * 0.12, 0.04, 0.14)), hc + V((sx * 0.2, 0.1, 0.44)), 0.075, fur, 6), "head"))
        parts.append((cone("dw_earin%d" % sx, hc + V((sx * 0.125, 0.02, 0.17)), hc + V((sx * 0.19, 0.075, 0.38)), 0.04, dark, 5), "head"))
        for k in range(2):
            parts.append((cone("dw_cheek%d_%d" % (sx, k), hc + V((sx * 0.16, 0.02 + 0.07 * k, -0.04 - 0.05 * k)),
                               hc + V((sx * (0.38 - 0.06 * k), 0.14 + 0.1 * k, -0.1 - 0.08 * k)), 0.08, fur if k else light, 6), "head"))
        parts.append((cone("dw_fang%d" % sx, hc + V((sx * 0.065, -0.33, -0.09)), hc + V((sx * 0.07, -0.35, -0.21)), 0.024, fang, 5), "head"))
        if not mount:
            parts.append((blob("dw_eye%d" % sx, 0.052 if mother else 0.04, hc + V((sx * 0.105, -0.185, 0.06)), glow, (0.9, 0.5, 0.8)), "head"))
    if mount:
        parts += [(o, "head") for o in mk.eyes("dw", [hc + V((sx * 0.105, -0.185, 0.06)) for sx in (-1, 1)], 0.045, m_eye, m_white)]
    # pernas grossas e patas escuras
    for bone, sx, sy in (("leg_fr", 1, -1), ("leg_fl", -1, -1), ("leg_br", 1, 1), ("leg_bl", -1, 1)):
        top = V((sx * 0.19, sy * 0.38, h - 0.02))
        foot = V((sx * 0.21, sy * 0.4 - 0.02, 0.08))
        parts.append((ck.tube("dw_leg_" + bone[4:], top, foot, 0.12, 0.085, fur, 8), bone))
        parts.append((blob("dw_paw_" + bone[4:], 0.105, foot + V((0, -0.03, -0.015)), dark, (1.0, 1.3, 0.62)), bone))
    # rabo cheio
    tpts = [((0, 0.44, h + 0.08), 0.11), ((0, 0.66, h + 0.14), 0.115), ((0, 0.82, h + 0.13), 0.12), ((0, 0.96, h + 0.06), 0.09), ((0, 1.05, h - 0.01), 0.05)]
    parts.append((mk.skin_body("fur_tail", tpts, [(0, 1), (1, 2), (2, 3), (3, 4)], fur), "tail"))
    parts.append((blob("fur_tailtip", 0.06, (0, 1.04, h + 0.0), dark, (0.95, 1.2, 0.95)), "tail"))
    if rider or mount:
        _dw_saddle(cid, parts, h, rider)
    if chief:
        _dw_chief(cid, parts, h, seat, net_sh, hc)
    elif rider:
        _dw_rider(cid, parts, h, seat, net_sh, hc)
    if mother:
        _dw_mother(cid, parts, h, hc, mane, fang, m_white)
    if not (rider or mount or mother):
        _dw_horde(cid, parts, h, hc)
    if mount:
        for o, _bone in parts:
            if not o.name.startswith(DW_SADDLE_PARTS):
                for v in o.data.vertices:
                    v.co.y -= DW_MOUNT_FWD
    mk.finish(arm, parts)
    bm.mob_actions(arm, quadruped=True)
    mk.quad_motion(arm, "wolf")
    if mount:
        mk._drop_clips(arm, ("attack", "hit", "die"))
    else:
        mk.quad_combat(arm, "wolf")
        _dw_gestures(arm, rider)
    return arm


def _dw_horde(cid, parts, h, hc):
    """Só o lobo atroz comum (matilha da Horda; os chefes e os montados não passam aqui): pintura de guerra em brasa no
    lombo, na testa e no focinho, coleira de ferro com cravos por cima da juba e cicatriz de garra na anca."""
    paint = ck.mat("m_%s_paint" % cid, (0.88, 0.2, 0.08), 0.8, 0.35)
    iron = ck.mat("m_%s_iron" % cid, (0.3, 0.3, 0.34), 0.45)
    steel = ck.mat("m_%s_steel" % cid, (0.78, 0.78, 0.82), 0.4)
    scar = ck.mat("m_%s_scar" % cid, (0.9, 0.6, 0.56), 0.8)
    # três faixas em V no lombo, entre os espinhos de pelo
    for i, y in enumerate((-0.195, -0.04, 0.12)):
        zc = h + (0.07 * (0.1 - y) / 0.4 if y < 0.1 else 0.0)
        rr = _dw_top(y, h) - zc - 0.01           # meio afundada: lê como tinta, não como corda
        for sx in (-1, 1):
            prev = None
            for j, deg in enumerate((10, 28, 46, 64, 82)):
                a = math.radians(deg)
                p = V((sx * rr * math.sin(a), y + 0.1 * math.sin(a), zc + rr * math.cos(a)))
                if prev:
                    parts.append((ck.tube("dw_paint%d_%d_%d" % (i, sx, j), prev, p, 0.036, 0.036 if j < 4 else 0.018, paint, 6), "body"))
                prev = p
    # testa e focinho
    parts.append((blob("dw_paintskull", 0.2, hc + V((0, 0.03, 0.05)), paint, (0.4, 1.0, 0.9), cuts=2), "head"))
    parts.append((blob("dw_paintsnout", 0.15, hc + V((0, -0.25, -0.03)), paint, (0.26, 1.1, 0.62), cuts=2), "head"))
    # coleira de ferro por cima da juba, cinco cravos claros
    cc = V((0, -0.47, h + 0.24))
    ring = [cc + V((0.325 * math.sin(math.radians(d)), 0, 0.285 * math.cos(math.radians(d)))) for d in range(-125, 126, 25)]
    for k in range(len(ring) - 1):
        parts.append((ck.tube("dw_band%d" % k, ring[k], ring[k + 1], 0.04, 0.04, iron, 6), "body"))
    for k, d in enumerate((-100, -50, 0, 50, 100)):
        if d == 0:
            continue            # no alto fica o espinho de pelo
        a = math.radians(d)
        dv = V((math.sin(a), 0, math.cos(a)))
        p = cc + V((0.325 * dv.x, 0, 0.285 * dv.z))
        parts.append((cone("dw_stud%d" % k, p, p + dv * 0.19, 0.05, steel, 5), "body"))
    # cicatriz de garra na anca esquerda
    hx, hy, hz = 0.16 * 1.16 * 0.8, 0.16 * 1.16 * 1.25, 0.16 * 1.16 * 1.45        # raios de dw_haunch
    for k in range(3):
        pp = []
        for el, dy in ((62, -0.07), (40, -0.03), (16, 0.02)):
            y = dy + 0.075 * (k - 1)
            f = math.sqrt(1 - (y / hy) ** 2) * 1.01
            e = math.radians(el)
            pp.append(V((-0.17 - hx * math.cos(e) * f, 0.38 + y, h - 0.04 + hz * math.sin(e) * f)))
        parts.append((ck.tube("dw_scar%d_a" % k, pp[0], pp[1], 0.012, 0.02, scar, 4), "body"))
        parts.append((ck.tube("dw_scar%d_b" % k, pp[1], pp[2], 0.02, 0.008, scar, 4), "body"))


def _dw_saddle(cid, parts, h, rider):
    leather = ck.mat("m_%s_saddle" % cid, (0.32, 0.2, 0.12), 0.75)
    blanket = ck.mat("m_%s_blanket" % cid, (0.62, 0.14, 0.12) if rider else (0.36, 0.3, 0.26), 0.85)
    bone = ck.mat("m_%s_bone" % cid, (0.93, 0.89, 0.76), 0.55)
    parts.append((blob("dw_blanket", 0.21, (0, 0.0, h + 0.2), blanket, (0.97, 1.2, 0.44)), "body"))
    parts.append((blob("dw_saddle", 0.15, (0, 0.0, h + 0.275), leather, (0.85, 1.05, 0.4)), "body"))
    parts.append((blob("dw_cantle", 0.1, (0, 0.13, h + 0.32), leather, (1.1, 0.35, 0.55)), "body"))
    for sx in (-1, 1):
        parts.append((ck.tube("dw_girth%d" % sx, (sx * 0.165, -0.03, h + 0.24), (sx * 0.19, -0.03, h - 0.06), 0.014, 0.014, leather, 5), "body"))
        if not rider:           # montaria: duas presas de troféu no cabeçote e pele sobre a manta
            parts.append((cone("dw_pommel%d" % sx, (sx * 0.035, -0.15, h + 0.3), (sx * 0.09, -0.2, h + 0.42), 0.022, bone, 5), "body"))


def _dw_rider(cid, parts, h, seat, net_sh, hc):
    """Ginete do Lobo Atroz: goblin maior que o Saqueador, elmo de chifres, lança com flâmula, rede no braço solto
    (osso rider_arm) e estandarte nas costas; o lobo leva testeira de ferro com cravo e coleira de cravos."""
    skin = ck.mat("m_%s_rskin" % cid, (0.48, 0.62, 0.3), 0.7)
    cloth = ck.mat("m_%s_rcloth" % cid, (0.5, 0.14, 0.11), 0.8)
    wood = ck.mat("m_%s_rwood" % cid, (0.42, 0.3, 0.2), 0.8)
    iron = ck.mat("m_%s_riron" % cid, (0.3, 0.3, 0.34), 0.45)
    steel = ck.mat("m_%s_rsteel" % cid, (0.72, 0.72, 0.76), 0.4)
    horn = ck.mat("m_%s_rtooth" % cid, (0.95, 0.92, 0.78), 0.5)
    net = ck.mat("m_%s_net" % cid, (0.82, 0.74, 0.5), 0.9)
    m_eye, m_white = mk.base_mats()
    R = "rider"
    parts.append((blob("rd_torso", 0.17, seat + V((0, -0.02, 0.2)), cloth, (1.0, 0.85, 1.15)), R))
    rh = seat + V((0, -0.07, 0.52))
    parts.append((blob("rd_skull", 0.19, rh, skin, (1.0, 0.95, 0.95)), R))
    parts.append((blob("rd_helm", 0.2, rh + V((0, 0.01, 0.06)), iron, (1.03, 1.03, 0.7)), R))
    parts.append((cone("rd_nose", rh + V((0, -0.16, -0.01)), rh + V((0, -0.27, -0.04)), 0.035, skin, 6), R))
    for sx in (-1, 1):
        parts.append((ck.blade("rd_ear%d" % sx, rh + V((sx * 0.15, 0, 0.0)), rh + V((sx * 0.37, 0.05, 0.1)), 0.12, 0.014, skin, (0, 0, 1), 0.35), R))
        parts.append((cone("rd_tusk%d" % sx, rh + V((sx * 0.06, -0.15, -0.08)), rh + V((sx * 0.075, -0.19, 0.0)), 0.018, horn, 5), R))
        parts.append((cone("rd_helmhorn%d" % sx, rh + V((sx * 0.15, 0, 0.13)), rh + V((sx * 0.33, -0.03, 0.34)), 0.045, horn, 6), R))
        parts.append((ck.tube("rd_leg%d" % sx, seat + V((sx * 0.13, 0, 0.02)), seat + V((sx * 0.25, -0.08, -0.24)), 0.05, 0.042, cloth, 6), R))
        parts.append((cone("rd_shspike%d" % sx, seat + V((sx * 0.16, 0, 0.3)), seat + V((sx * 0.3, 0.02, 0.44)), 0.04, horn, 5), R))
    parts += [(o, R) for o in mk.eyes("rd", [rh + V((sx * 0.07, -0.165, 0.0)) for sx in (-1, 1)], 0.034, m_eye, m_white)]
    # braço da lança (parado) e lança com flâmula
    parts.append((ck.tube("rd_armlance", seat + V((-0.16, -0.02, 0.28)), seat + V((-0.25, -0.26, 0.2)), 0.042, 0.036, skin, 6), R))
    l0, l1 = seat + V((-0.27, 0.52, 0.1)), seat + V((-0.27, -1.2, 0.36))
    parts.append((ck.tube("rd_lance", l0, l1, 0.022, 0.022, wood, 6), R))
    parts.append((cone("rd_lancehead", l1, l1 + (l1 - l0).normalized() * 0.22, 0.05, steel, 6), R))
    pf = l0.lerp(l1, 0.86)
    parts.append((ck.blade("rd_pennant", pf, pf + V((0, 0.34, -0.14)), 0.17, 0.014, cloth, (0, 0, 1), 0.3), R))
    # braço da rede (osso próprio: arremessa)
    hand = net_sh + V((0.07, -0.07, -0.25))
    parts.append((ck.tube("rd_armnet", net_sh, hand, 0.042, 0.036, skin, 6), "rider_arm"))
    parts.append((blob("rd_net", 0.13, hand + V((0.02, -0.03, -0.07)), net, (1.1, 0.85, 1.0)), "rider_arm"))
    for k in range(3):
        a = math.tau * k / 3
        parts.append((blob("rd_netweight%d" % k, 0.035, hand + V((0.02 + 0.11 * math.cos(a), -0.03 + 0.09 * math.sin(a), -0.16)), iron), "rider_arm"))
    # estandarte nas costas
    b0, b1 = seat + V((0, 0.17, 0.1)), seat + V((0, 0.34, 1.12))
    parts.append((ck.tube("rd_pole", b0, b1, 0.02, 0.018, wood, 6), R))
    parts.append((cone("rd_poletip", b1, b1 + V((0, 0.02, 0.1)), 0.035, horn, 5), R))
    parts.append((ck.blade("rd_banner", b1 + V((0, 0.012, -0.03)), b1 + V((0, 0.1, -0.52)), 0.3, 0.02, cloth, (1, 0, 0), 0.3), R))
    parts.append((blob("rd_bannermark", 0.055, b1 + V((0, 0.05, -0.2)), horn, (1.0, 0.35, 1.2)), R))
    # lobo de guerra: testeira com cravo e coleira de cravos
    parts.append((blob("dw_chamfron", 0.16, hc + V((0, -0.1, 0.11)), iron, (0.95, 1.35, 0.45)), "head"))
    parts.append((cone("dw_chamspike", hc + V((0, -0.14, 0.15)), hc + V((0, -0.3, 0.36)), 0.045, steel, 5), "head"))
    cc = V((0, -0.5, h + 0.22))
    for k in range(7):
        a = math.radians(-105 + k * 35)
        d = V((math.sin(a), 0.1, math.cos(a)))
        parts.append((cone("dw_collar%d" % k, cc + d * 0.2, cc + d * 0.4, 0.045, iron, 5), "body"))


def _dw_mother(cid, parts, h, hc, ash, fang, white):
    """Presa-de-Cinza: cicatrizes no flanco e na cara, olho esquerdo cego, presas longas, tufo de cinza no rabo e
    duas lanças quebradas cravadas no lombo (com trapo vermelho)."""
    scar = ck.mat("m_%s_scar" % cid, (0.72, 0.2, 0.2), 0.8)
    soot = ck.mat("m_%s_soot" % cid, (0.13, 0.12, 0.14), 0.9)
    ember = ck.mat("m_%s_ember" % cid, (1.0, 0.42, 0.08), 0.4, 2.2)
    wood = ck.mat("m_%s_wood" % cid, (0.42, 0.3, 0.2), 0.8)
    red = ck.mat("m_%s_rag" % cid, (0.7, 0.14, 0.12), 0.8)
    for i in range(3):
        y = -0.2 + i * 0.1
        parts.append((ck.blade("dw_scar%d" % i, (0.245, y, h + 0.24), (0.275, y + 0.09, h - 0.02), 0.035, 0.03, scar, (0, 1, 0), 0.5), "body"))
        parts.append((ck.blade("dw_scarb%d" % i, (-0.2, 0.22 + i * 0.08, h + 0.2), (-0.235, 0.3 + i * 0.08, h + 0.0), 0.03, 0.03, scar, (0, 1, 0), 0.5), "body"))
    parts.append((ck.blade("dw_facescar", hc + V((-0.16, -0.14, 0.2)), hc + V((-0.1, -0.31, -0.03)), 0.035, 0.03, scar, (1, 0, 0), 0.5), "head"))
    parts.append((blob("dw_blindeye", 0.045, hc + V((-0.105, -0.195, 0.06)), white, (0.9, 0.5, 0.8)), "head"))
    for sx in (-1, 1):
        # Presa-de-Cinza: presas de sabre de ponta de fuligem, abertas para fora (passam do queixo: aparecem de cima)
        f0, f1 = hc + V((sx * 0.1, -0.29, -0.07)), hc + V((sx * 0.16, -0.4, -0.4))
        parts.append((cone("dw_longfang%d" % sx, f0, f1, 0.05, fang, 5), "head"))
        parts.append((cone("dw_fangsoot%d" % sx, f0.lerp(f1, 0.74), f1 + (f1 - f0) * 0.03, 0.02, soot, 5), "head"))
        parts.append((cone("dw_ruff%d" % sx, hc + V((sx * 0.14, 0.1, 0.0)), hc + V((sx * 0.46, 0.34, -0.02)), 0.12, ash, 6), "head"))
    # crista de cinza entre as orelhas (a "coroa" da matriarca)
    for k in range(3):
        parts.append((cone("dw_crest%d" % k, hc + V((0, 0.0 + k * 0.1, 0.14)), hc + V((0, 0.12 + k * 0.14, 0.46 - k * 0.05)), 0.085, ash, 5), "head"))
    # juba de leoa: coroa de mechas de cinza em volta do pescoço, pontas de fuligem
    nc = V((0, -0.5, h + 0.24))
    for k in range(9):
        a = math.radians(-120 + k * 30)
        dd = V((math.sin(a), 0.42, math.cos(a))).normalized()
        r0, r1 = nc + dd * 0.16, nc + dd * (0.54 if k % 2 else 0.44)
        parts.append((cone("dw_lionmane%d" % k, r0, r1, 0.18, ash, 6), "body"))
        if k in (0, 2, 6, 8):          # fuligem só nas mechas de lado (no alto ela virava um buraco escuro na juba)
            parts.append((cone("dw_manetip%d" % k, r0.lerp(r1, 0.62), r1 + dd * 0.04, 0.085, soot, 5), "body"))
    # brasa viva nas costas: a cinza ainda queima entre os espinhos da cernelha
    for k, y in enumerate((-0.33, -0.05, 0.12, 0.28)):
        parts.append((blob("dw_coal%d" % k, 0.05, (0, y, _dw_top(y, h)), ember, (1.5, 1.1, 0.5)), "body"))
    parts.append((blob("fur_tailash", 0.15, (0, 1.0, h + 0.03), ash, (0.95, 1.35, 0.95)), "tail"))
    parts.append((cone("fur_tailsoot", (0, 1.06, h + 0.02), (0, 1.3, h - 0.06), 0.09, soot, 6), "tail"))
    for i, (p0, p1) in enumerate((((0.07, 0.16, 0.2), (0.24, 0.42, 0.72)), ((-0.08, -0.06, 0.24), (-0.3, 0.06, 0.7)), ((0.1, 0.34, 0.18), (-0.1, 0.62, 0.62)))):
        a, b_ = V((p0[0], p0[1], h + p0[2])), V((p1[0], p1[1], h + p1[2]))
        parts.append((ck.tube("dw_spear%d" % i, a, b_, 0.024, 0.024, wood, 5), "body"))
        parts.append((ck.blade("dw_spearrag%d" % i, b_.lerp(a, 0.12), b_.lerp(a, 0.12) + V((0.04, 0.26, -0.2)), 0.15, 0.016, red, (1, 0, 0), 0.4), "body"))


def _dw_chief(cid, parts, h, seat, sh, hc):
    """Ulgra Presa-Atroz: orc grande de capuz de pele de lobo (focinho e orelhas do bicho sobre a testa), manto de pele,
    tranças, glaive de osso, corrente com gancho no braço solto (osso rider_arm) e o estandarte do Clã do Lobo nas costas;
    o lobo negro leva testeira, coleira de cravos e pintura de guerra vermelha."""
    skin = ck.mat("m_%s_rskin" % cid, (0.43, 0.53, 0.38), 0.7)
    cloth = ck.mat("m_%s_rcloth" % cid, (0.32, 0.2, 0.15), 0.85)
    pelt = ck.mat("m_%s_pelt" % cid, (0.9, 0.87, 0.8), 0.95)          # pele de lobo BRANCO sobre o lobo negro: lê de cima
    pelt_d = ck.mat("m_%s_pelt2" % cid, (0.52, 0.49, 0.47), 0.95)
    wood = ck.mat("m_%s_rwood" % cid, (0.36, 0.26, 0.18), 0.8)
    iron = ck.mat("m_%s_riron" % cid, (0.28, 0.28, 0.32), 0.45)
    bone = ck.mat("m_%s_rtooth" % cid, (0.95, 0.92, 0.8), 0.5)
    red = ck.mat("m_%s_rred" % cid, (0.76, 0.13, 0.11), 0.7)
    hair = ck.mat("m_%s_rhair" % cid, (0.1, 0.09, 0.09), 0.8)
    glow = ck.mat("m_%s_reye" % cid, (1.0, 0.3, 0.15), 0.3, 2.4)
    m_eye, m_white = mk.base_mats()
    R = "rider"
    parts.append((blob("rd_torso", 0.24, seat + V((0, -0.02, 0.28)), cloth, (1.05, 0.85, 1.15)), R))
    for i in range(7):                      # manto de pele em volta dos ombros
        a = math.radians(-110 + i * 220 / 6)
        parts.append((blob("rd_mantle%d" % i, 0.115, seat + V((math.sin(a) * 0.27, 0.0 + math.cos(a) * 0.2, 0.46)), pelt if i % 2 else pelt_d, (1, 1, 0.8)), R))
    rh = seat + V((0, -0.08, 0.74))
    parts.append((blob("rd_skull", 0.24, rh, skin, (1.0, 0.95, 0.95)), R))
    parts.append((blob("rd_hood", 0.3, rh + V((0, 0.06, 0.07)), pelt, (1.06, 1.08, 0.82)), R))
    parts.append((cone("rd_hoodsnout", rh + V((0, -0.14, 0.2)), rh + V((0, -0.52, 0.1)), 0.125, pelt, 6), R))
    parts.append((blob("rd_hoodnose", 0.045, rh + V((0, -0.5, 0.1)), hair), R))
    parts.append((ck.blade("rd_hoodpaint", rh + V((0, 0.3, 0.24)), rh + V((0, -0.34, 0.27)), 0.11, 0.05, red, (1, 0, 0), 0.5), R))     # risca de guerra do focinho à nuca
    for k in range(5):                      # juba eriçada da pele na nuca (a coroa dela, vista de cima)
        a = math.radians(-64 + k * 32)
        parts.append((cone("rd_hoodruff%d" % k, rh + V((math.sin(a) * 0.2, 0.2, 0.12)), rh + V((math.sin(a) * 0.5, 0.5 + 0.1 * math.cos(a), 0.06 + 0.22 * math.cos(a))), 0.1, pelt if k % 2 else pelt_d, 5), R))
    parts.append((ck.blade("rd_peltback", rh + V((0, 0.26, -0.02)), seat + V((0, 0.4, -0.06)), 0.5, 0.05, pelt, (1, 0, 0), 0.3), R))            # a pele desce pelas costas
    parts.append((cone("rd_pelttail", seat + V((0, 0.36, 0.0)), seat + V((0.06, 0.62, -0.22)), 0.07, pelt_d, 5), R))
    for sx in (-1, 1):
        parts.append((cone("rd_hoodear%d" % sx, rh + V((sx * 0.16, 0.04, 0.2)), rh + V((sx * 0.32, 0.1, 0.52)), 0.12, pelt, 5), R))
        parts.append((cone("rd_hoodearin%d" % sx, rh + V((sx * 0.165, 0.005, 0.22)), rh + V((sx * 0.305, 0.07, 0.46)), 0.065, red, 4), R))
        parts.append((blob("rd_hoodeye%d" % sx, 0.045, rh + V((sx * 0.1, -0.27, 0.22)), glow), R))
        # Presa-Atroz: uma presa gigante em cada ombro, curvada para cima e para fora
        f0 = seat + V((sx * 0.3, 0.02, 0.44))
        f1 = f0 + V((sx * 0.24, -0.04, 0.2))
        parts.append((ck.tube("rd_shfang%da" % sx, f0, f1, 0.1, 0.075, bone, 6), R))
        parts.append((cone("rd_shfang%db" % sx, f1, f1 + V((sx * 0.1, -0.1, 0.34)), 0.075, bone, 6), R))
        parts.append((ck.tube("rd_shfangband%d" % sx, f0.lerp(f1, 0.1), f0.lerp(f1, 0.4), 0.108, 0.1, red, 6), R))
        parts.append((cone("rd_tusk%d" % sx, rh + V((sx * 0.09, -0.19, -0.11)), rh + V((sx * 0.115, -0.26, 0.03)), 0.032, bone, 5), R))
        parts.append((ck.tube("rd_braid%d" % sx, rh + V((sx * 0.21, 0.02, -0.04)), rh + V((sx * 0.27, 0.0, -0.42)), 0.04, 0.03, hair, 6), R))
        parts.append((blob("rd_braidring%d" % sx, 0.045, rh + V((sx * 0.265, 0.0, -0.36)), red), R))
        parts.append((ck.tube("rd_leg%d" % sx, seat + V((sx * 0.17, 0, 0.03)), seat + V((sx * 0.31, -0.1, -0.3)), 0.07, 0.06, cloth, 6), R))
        parts.append((blob("rd_boot%d" % sx, 0.075, seat + V((sx * 0.32, -0.13, -0.33)), pelt_d, (0.9, 1.4, 0.8)), R))
    parts += [(o, R) for o in mk.eyes("rd", [rh + V((sx * 0.09, -0.215, 0.0)) for sx in (-1, 1)], 0.04, m_eye, m_white)]
    # glaive de osso no braço parado
    parts.append((ck.tube("rd_armglaive", seat + V((-0.24, -0.02, 0.42)), seat + V((-0.35, -0.3, 0.3)), 0.06, 0.05, skin, 6), R))
    l0, l1 = seat + V((-0.37, 0.66, 0.1)), seat + V((-0.37, -1.25, 0.48))
    d = (l1 - l0).normalized()
    parts.append((ck.tube("rd_glaive", l0, l1, 0.028, 0.028, wood, 6), R))
    parts.append((ck.blade("rd_glaiveblade", l1 - d * 0.06, l1 + d * 0.74, 0.36, 0.04, bone, (1, 0, 0.25), 0.34), R))        # lâmina deitada: larga vista de cima
    parts.append((ck.blade("rd_glaivefuller", l1 + d * 0.02, l1 + d * 0.5, 0.1, 0.05, red, (1, 0, 0.25), 0.4), R))
    parts.append((cone("rd_glaivehook", l1 + d * 0.1, l1 + d * 0.02 + V((-0.26, 0, -0.04)), 0.06, bone, 5), R))
    parts.append((ck.blade("rd_glaivetassel", l1 - d * 0.1, l1 - d * 0.1 + V((0, 0.26, -0.3)), 0.16, 0.02, red, (1, 0, 0), 0.4), R))
    # braço da corrente (osso próprio): elos enrolados e gancho
    hand = sh + V((0.1, -0.08, -0.36))
    parts.append((ck.tube("rd_armchain", sh, hand, 0.06, 0.05, skin, 6), "rider_arm"))
    for k in range(6):
        a = math.tau * k / 6
        parts.append((blob("rd_chain%d" % k, 0.04, hand + V((0.02, 0.1 * math.cos(a), -0.1 + 0.1 * math.sin(a))), iron), "rider_arm"))
    parts.append((ck.tube("rd_hookshank", hand + V((0.02, -0.08, -0.14)), hand + V((0.02, -0.14, -0.3)), 0.022, 0.022, iron, 5), "rider_arm"))
    parts.append((cone("rd_hook", hand + V((0.02, -0.14, -0.3)), hand + V((0.02, -0.28, -0.2)), 0.035, iron, 5), "rider_arm"))
    # estandarte do Clã do Lobo nas costas
    # o mastro saía de dentro da pele das costas e a juba do capuz (até y 0.6, z 1.0) furava o mastro e a ponta do pano
    # (art review 18): nasce atrás da pele, no arção de trás, e tomba mais para trás; o pano fica todo depois da juba
    b0, b1 = seat + V((0, 0.46, 0.0)), seat + V((0, 0.88, 1.6))
    parts.append((ck.tube("rd_pole", b0, b1, 0.026, 0.022, wood, 6), R))
    parts.append((ck.tube("rd_bar", b1 + V((-0.26, 0, -0.06)), b1 + V((0.26, 0, -0.06)), 0.018, 0.018, wood, 5), R))
    parts.append((ck.box("rd_banner", (0.5, 0.024, 0.56), b1 + V((0, 0.035, -0.36)), hair), R))            # pano negro de borda vermelha, as duas presas do clã
    parts.append((ck.box("rd_bannertrim", (0.56, 0.018, 0.07), b1 + V((0, 0.035, -0.11)), red), R))
    parts.append((ck.blade("rd_bannertail", b1 + V((0, 0.035, -0.6)), b1 + V((0, 0.06, -0.92)), 0.5, 0.02, red, (1, 0, 0), 0.25), R))
    for sx in (-1, 1):
        for sy in (-1, 1):
            parts.append((cone("rd_bannerfang%d_%d" % (sx, sy), b1 + V((sx * 0.1, 0.035 + sy * 0.022, -0.2)), b1 + V((sx * 0.05, 0.035 + sy * 0.022, -0.54)), 0.055, bone, 5), R))
        parts.append((blob("rd_bartuft%d" % sx, 0.06, b1 + V((sx * 0.28, 0, -0.08)), pelt, (1, 1, 1.4)), R))
    parts.append((blob("rd_poleskull", 0.08, b1 + V((0, 0, 0.05)), bone, (1.0, 1.1, 0.9)), R))
    parts.append((cone("rd_polesnout", b1 + V((0, -0.04, 0.04)), b1 + V((0, -0.22, 0.0)), 0.05, bone, 5), R))
    # lobo de guerra
    parts.append((blob("dw_chamfron", 0.17, hc + V((0, -0.1, 0.11)), iron, (0.95, 1.35, 0.45)), "head"))
    parts.append((cone("dw_chamspike", hc + V((0, -0.14, 0.15)), hc + V((0, -0.34, 0.4)), 0.05, bone, 5), "head"))
    cc = V((0, -0.5, h + 0.22))
    for k in range(7):
        a = math.radians(-105 + k * 35)
        dd = V((math.sin(a), 0.1, math.cos(a)))
        parts.append((cone("dw_collar%d" % k, cc + dd * 0.22, cc + dd * 0.46, 0.05, bone if k % 2 else iron, 5), "body"))
    for sx in (-1, 1):
        for k in range(2):
            parts.append((ck.blade("dw_warpaint%d_%d" % (sx, k), (sx * 0.2, 0.32 + k * 0.1, h + 0.2), (sx * 0.24, 0.4 + k * 0.1, h - 0.02), 0.04, 0.03, red, (0, 1, 0), 0.5), "body"))
    # garupa de guerra: três costelas de osso atravessadas e a ponta do rabo pintada (o lobo dela não é um lobo de ginete)
    for k, y in enumerate((0.3, 0.42, 0.54)):
        z = _dw_top(y, h)
        for sx in (-1, 1):
            parts.append((cone("dw_crupper%d_%d" % (k, sx), (sx * 0.02, y, z + 0.04), (sx * (0.3 - 0.03 * k), y + 0.05, z - 0.06), 0.05, bone, 5), "body"))
    for sx in (-1, 1):                      # pintura de guerra na testeira (duas riscas em V)
        parts.append((ck.blade("dw_champaint%d" % sx, hc + V((sx * 0.13, 0.02, 0.185)), hc + V((sx * 0.03, -0.3, 0.14)), 0.07, 0.03, red, (1, 0, 0), 0.4), "head"))
    parts.append((blob("fur_tailpaint", 0.085, (0, 1.0, h + 0.03), red, (0.95, 1.3, 0.95)), "tail"))


def _dw_gestures(arm, rider):
    """atk_charge = Investida Atroz (agacha e dispara, impacto no quadro 5); atk_leap = Bote (salto alto, impacto no 12);
    ginete: atk_throw = Rede (o braço solto gira por cima da cabeça e solta à frente, impacto no 7)."""
    z = (0, 0, 0)
    r = lambda x=0.0, y=0.0, zz=0.0: (x, y, zz)
    p = lambda up=0.0, fwd=0.0: (0, up, fwd)
    e = 18
    keys = {
        "body": [(1, z, z), (3, r(10), p(-0.07, -0.1)), (5, r(-10), p(0.1, 0.42)), (8, r(6), p(0.0, 0.3)), (12, r(2), p(0, 0.1)), (e, z, z)],
        "head": [(1, z, z), (3, r(12), z), (5, r(-14), z), (7, r(20, 0, 10), z), (9, r(18, 0, -10), z), (12, r(4), z), (e, z, z)],
        "leg_fr": [(1, z, z), (3, r(16), z), (5, r(-56), z), (8, r(-20), z), (12, r(4), z), (e, z, z)],
        "leg_fl": [(1, z, z), (3, r(14), z), (5, r(-48), z), (8, r(-16), z), (12, r(2), z), (e, z, z)],
        "leg_br": [(1, z, z), (3, r(-18), z), (5, r(44), z), (8, r(14), z), (12, r(-2), z), (e, z, z)],
        "leg_bl": [(1, z, z), (3, r(-18), z), (5, r(40), z), (8, r(12), z), (12, r(-2), z), (e, z, z)],
        "tail": [(1, z, z), (3, r(14), z), (5, r(-24), z), (8, r(10, 0, 8), z), (12, r(0, 0, -6), z), (e, z, z)],
    }
    if rider:
        keys["rider"] = [(1, z, z), (3, r(-8), z), (5, r(22), z), (8, r(14), z), (12, r(4), z), (e, z, z)]
    lp.add_action(arm, "atk_charge", keys, e, loop=False)
    e = 22
    keys = {
        "body": [(1, z, z), (5, r(14), p(-0.1, -0.12)), (8, r(-22), p(0.26, 0.24)), (10, r(-6), p(0.32, 0.44)), (12, r(16), p(0.0, 0.5)), (15, r(8), p(-0.02, 0.3)),
                 (18, r(2), p(0, 0.1)), (e, z, z)],
        "head": [(1, z, z), (5, r(14), z), (8, r(-22), z), (10, r(-10), z), (12, r(26), z), (14, r(18, 0, 12), z), (16, r(16, 0, -10), z), (19, r(4), z), (e, z, z)],
        "leg_fr": [(1, z, z), (5, r(22), z), (8, r(-62), z), (10, r(-70), z), (12, r(-12), z), (15, r(6), z), (e, z, z)],
        "leg_fl": [(1, z, z), (5, r(20), z), (8, r(-54), z), (10, r(-62), z), (12, r(-8), z), (15, r(4), z), (e, z, z)],
        "leg_br": [(1, z, z), (5, r(-24), z), (8, r(48), z), (10, r(38), z), (12, r(-10), z), (15, r(-4), z), (e, z, z)],
        "leg_bl": [(1, z, z), (5, r(-24), z), (8, r(44), z), (10, r(34), z), (12, r(-8), z), (15, r(-2), z), (e, z, z)],
        "tail": [(1, z, z), (5, r(16), z), (8, r(-28), z), (12, r(18), z), (16, r(4, 0, 8), z), (e, z, z)],
    }
    if rider:
        keys["rider"] = [(1, z, z), (5, r(10), z), (8, r(-12), z), (12, r(20), z), (16, r(6), z), (e, z, z)]
    lp.add_action(arm, "atk_leap", keys, e, loop=False)
    if rider:
        e = 20
        lp.add_action(arm, "atk_throw", {
            "body": [(1, z, z), (4, r(-4), p(0.0, -0.05)), (7, r(4), p(0.0, 0.06)), (11, r(2), p(0, 0.03)), (e, z, z)],
            "head": [(1, z, z), (4, r(-8), z), (7, r(8), z), (e, z, z)],
            "rider": [(1, z, z), (4, r(-16, 0, -8), z), (7, r(22, 0, 6), z), (11, r(10), z), (e, z, z)],
            "rider_arm": [(1, z, z), (3, r(-150, 0, -20), z), (5, r(-205, 0, -10), z), (7, r(-75, 0, 10), z), (10, r(-50), z), (14, r(-14), z), (e, z, z)],
            "tail": [(1, z, z), (4, r(10), z), (7, r(-10), z), (e, z, z)],
        }, e, loop=False)

    # uivo (clipe "shout", impacto no quadro 7): senta nas patas de trás, cabeça para o céu, sacode
    e = 26
    keys = {
        "body": [(1, z, z), (4, r(-12), p(0.04, -0.05)), (7, r(-18), p(0.08, -0.08)), (16, r(-17), p(0.07, -0.08)), (21, r(-4), p(0.01, -0.02)), (e, z, z)],
        "head": [(1, z, z), (4, r(-30), z), (7, r(-52), z), (10, r(-50, 0, 8), z), (13, r(-52, 0, -8), z), (16, r(-48, 0, 5), z), (21, r(-10), z), (e, z, z)],
        "leg_fr": [(1, z, z), (7, r(-12), z), (16, r(-12), z), (e, z, z)],
        "leg_fl": [(1, z, z), (7, r(-10), z), (16, r(-10), z), (e, z, z)],
        "leg_br": [(1, z, z), (7, r(14), z), (16, r(14), z), (e, z, z)],
        "leg_bl": [(1, z, z), (7, r(14), z), (16, r(14), z), (e, z, z)],
        "tail": [(1, z, z), (7, r(-26), z), (12, r(-26, 0, 12), z), (16, r(-24, 0, -12), z), (e, z, z)],
    }
    if rider:
        keys["rider"] = [(1, z, z), (7, r(-10), z), (16, r(-10), z), (e, z, z)]
        keys["rider_arm"] = [(1, z, z), (7, r(-170, 0, -12), z), (16, r(-165, 0, -12), z), (21, r(-40), z), (e, z, z)]
    lp.add_action(arm, "shout", keys, e, loop=False)
    if rider:
        # chamado (clipe "summon", impacto no 11): o lobo uiva e quem monta ergue o braço e gira a corrente/rede
        e = 26
        lp.add_action(arm, "summon", {
            "body": [(1, z, z), (6, r(-10), p(0.03, -0.04)), (11, r(-14), p(0.05, -0.06)), (18, r(-12), p(0.04, -0.05)), (e, z, z)],
            "head": [(1, z, z), (6, r(-30), z), (11, r(-48, 0, 8), z), (15, r(-46, 0, -8), z), (19, r(-30), z), (e, z, z)],
            "rider": [(1, z, z), (6, r(-8, 0, -6), z), (11, r(-12, 0, 6), z), (18, r(-8), z), (e, z, z)],
            "rider_arm": [(1, z, z), (5, r(-150, 0, -20), z), (8, r(-185, 0, 20), z), (11, r(-170, 0, -20), z), (14, r(-185, 0, 20), z), (18, r(-150), z), (22, r(-30), z), (e, z, z)],
            "tail": [(1, z, z), (11, r(-22, 0, 10), z), (18, r(-20, 0, -10), z), (e, z, z)],
        }, e, loop=False)
        # chuva de lanças / pisão (clipe "cast_ground", impacto no 10): o lobo empina e desce as patas no chão
        e = 24
        lp.add_action(arm, "cast_ground", {
            "body": [(1, z, z), (6, r(-24), p(0.16, -0.08)), (8, r(-26), p(0.18, -0.08)), (10, r(10), p(-0.03, 0.1)), (14, r(7), p(-0.02, 0.07)), (e, z, z)],
            "head": [(1, z, z), (6, r(-22), z), (10, r(20), z), (14, r(10), z), (e, z, z)],
            "leg_fr": [(1, z, z), (6, r(-58), z), (8, r(-62), z), (10, r(16), z), (14, r(8), z), (e, z, z)],
            "leg_fl": [(1, z, z), (6, r(-52), z), (8, r(-56), z), (10, r(14), z), (14, r(6), z), (e, z, z)],
            "leg_br": [(1, z, z), (6, r(18), z), (10, r(-6), z), (e, z, z)],
            "leg_bl": [(1, z, z), (6, r(18), z), (10, r(-6), z), (e, z, z)],
            "rider": [(1, z, z), (6, r(16), z), (10, r(18), z), (14, r(8), z), (e, z, z)],
            "rider_arm": [(1, z, z), (6, r(-175, 0, -10), z), (8, r(-185, 0, -10), z), (10, r(-60), z), (14, r(-40), z), (e, z, z)],
            "tail": [(1, z, z), (6, r(-24), z), (10, r(16), z), (e, z, z)],
        }, e, loop=False)


# ---------------------------------------------------------------------------
# Salamandra de Lava
# ---------------------------------------------------------------------------
def lava_salamander(cid="mob_lava_salamander"):
    h = 0.26
    bones = mk.pivots(head=(0, -0.5, h + 0.04), leg_fr=(0.17, -0.3, h), leg_fl=(-0.17, -0.3, h), leg_br=(0.17, 0.34, h), leg_bl=(-0.17, 0.34, h))
    bones["tail"] = ((0, 0.5, h), (0, 0.88, h - 0.02), "body")
    bones["tail2"] = ((0, 0.88, h - 0.02), (0, 1.26, h - 0.06), "tail")
    arm = lp.make_armature("rig_" + cid, bones)
    hide = ck.mat("m_%s_hide" % cid, (0.24, 0.17, 0.16), 0.7)
    hide_d = ck.mat("m_%s_hide2" % cid, (0.13, 0.1, 0.11), 0.75)
    ember = ck.mat("m_%s_ember" % cid, (1.0, 0.42, 0.08), 0.4, 2.2)
    hot = ck.mat("m_%s_hot" % cid, (1.0, 0.8, 0.25), 0.4, 3.0)
    parts = []
    pts = [((0, 0.5, h), 0.13), ((0, 0.14, h + 0.01), 0.19), ((0, -0.26, h + 0.02), 0.19), ((0, -0.5, h + 0.04), 0.14)]
    trunk = mk.skin_body("sal_trunk", pts, [(0, 1), (1, 2), (2, 3)], hide)
    for v in trunk.data.vertices:           # achatado e largo: lagarto que rasteja
        v.co.z = h + (v.co.z - h) * 0.8
        v.co.x *= 1.2
    parts.append((trunk, "body"))
    parts.append((blob("sal_belly", 0.16, (0, -0.02, h - 0.09), ember, (0.95, 2.3, 0.45)), "body"))
    # cabeça em cunha: boca acesa, olhos saltados, três guelras em brasa de cada lado
    hc = V((0, -0.72, h + 0.08))
    parts.append((blob("sal_skull", 0.2, hc, hide, (1.08, 1.2, 0.62)), "head"))
    parts.append((blob("sal_snout", 0.14, hc + V((0, -0.21, -0.02)), hide, (0.98, 1.1, 0.55)), "head"))
    parts.append((blob("sal_mouth", 0.14, hc + V((0, -0.17, -0.075)), hot, (1.02, 1.3, 0.22)), "head"))
    for sx in (-1, 1):
        parts.append((blob("sal_eye%d" % sx, 0.06, hc + V((sx * 0.13, -0.07, 0.1)), hot), "head"))
        parts.append((blob("sal_pupil%d" % sx, 0.028, hc + V((sx * 0.15, -0.115, 0.115)), hide_d, (0.6, 0.6, 1.3)), "head"))
        parts.append((blob("sal_nostril%d" % sx, 0.02, hc + V((sx * 0.05, -0.34, 0.03)), hide_d), "head"))
        for k in range(3):
            g0 = hc + V((sx * 0.15, 0.08 + 0.03 * k, 0.02 + 0.03 * k))
            parts.append((cone("sal_gill%d_%d" % (sx, k), g0, g0 + V((sx * (0.26 - 0.04 * k), 0.14 + 0.05 * k, 0.02 + 0.1 * k)), 0.06, hot if k == 1 else ember, 6), "head"))
    # crista de chamas no dorso e manchas de lava
    for i in range(7):
        y = -0.42 + i * 0.14
        hgt = 0.2 + 0.07 * (i % 2) - 0.012 * i
        parts.append((cone("sal_crest%d" % i, (0, y, h + 0.12), (0, y + 0.08, h + 0.13 + hgt), 0.075, hot if i % 2 else ember, 6), "body"))
    for i, (x, y) in enumerate(((0.13, -0.3), (-0.14, -0.14), (0.15, 0.04), (-0.13, 0.2), (0.1, 0.36), (-0.09, -0.4))):
        parts.append((blob("sal_spot%d" % i, 0.05, (x, y, h + 0.115), hot, (1.0, 1.5, 0.3)), "body"))
    # pernas abertas para os lados: braço, canela e pé de três dedos
    for bone, sx, sy in (("leg_fr", 1, -1), ("leg_fl", -1, -1), ("leg_br", 1, 1), ("leg_bl", -1, 1)):
        y = sy * 0.32 + (0.02 if sy > 0 else 0.0)
        sh, el, ft = V((sx * 0.16, y, h)), V((sx * 0.4, y - 0.02, h + 0.05)), V((sx * 0.45, y - 0.1, 0.05))
        n = bone[4:]
        parts.append((ck.tube("sal_arm_" + n, sh, el, 0.08, 0.062, hide, 7), bone))
        parts.append((ck.tube("sal_shin_" + n, el, ft, 0.062, 0.048, hide, 7), bone))
        parts.append((blob("sal_knee_" + n, 0.066, el, hide), bone))
        parts.append((blob("sal_foot_" + n, 0.075, ft + V((0, -0.02, -0.01)), hide_d, (1.2, 1.4, 0.5)), bone))
        for k in (-1, 0, 1):
            parts.append((cone("sal_toe_%s_%d" % (n, k), ft + V((0, -0.05, -0.02)), ft + V((sx * 0.03 + k * 0.06, -0.17, -0.035)), 0.026, hide_d, 5), bone))
    # rabo em dois ossos, ponta em brasa
    t0, t1, t2 = V((0, 0.44, h)), V((0, 0.88, h - 0.02)), V((0, 1.22, h - 0.06))
    parts.append((ck.tube("sal_tailbase", t0, t1, 0.125, 0.085, hide, 8), "tail"))
    for k in range(2):
        y = 0.58 + k * 0.16
        parts.append((cone("sal_tailcrest%d" % k, (0, y, h + 0.07 - 0.02 * k), (0, y + 0.07, h + 0.22 - 0.03 * k), 0.055, ember if k else hot, 6), "tail"))
    parts.append((ck.tube("sal_tailend", t1, t2, 0.085, 0.045, hide, 8), "tail2"))
    parts.append((blob("sal_tailember", 0.085, t2 + V((0, 0.03, 0.01)), hot, (1.0, 1.2, 1.0)), "tail2"))
    parts.append((cone("sal_tailflame", t2 + V((0, 0.03, 0.03)), t2 + V((0, 0.14, 0.26)), 0.07, ember, 6), "tail2"))
    mk.finish(arm, parts)
    bm.mob_actions(arm, quadruped=True)
    mk.quad_combat(arm, "wolf")             # mordida, tranco e morte de quadrúpede (usa body, head, pernas e tail)
    _sal_motion(arm)
    return arm


def _sal_motion(arm):
    """idle (respira, o rabo ondula, olha em volta), run (rasteja em diagonais: o tronco serpenteia e o rabo compensa) e
    cast_fire (Cuspe de Lava: ergue a cabeça, enche, projeta e segura o jorro; impacto no quadro 8).
    Rig: corpo Y = giro, loc Y = cima; cabeça Z = olha para o lado, X = baixa; rabo Z = balança; perna X- = para a frente."""
    mk._drop_clips(arm, ("idle", "run"))
    tau = math.tau
    z = (0, 0, 0)
    n = 48
    k = {b: [] for b in ("body", "head", "tail", "tail2")}
    for f in range(1, n + 1, 3):
        ph = (f - 1) / (n - 1) * tau
        k["body"].append((f, (0, 1.5 * math.sin(ph), 0), (0, 0.012 * (0.5 - 0.5 * math.cos(2 * ph)), 0)))
        k["head"].append((f, (3 * math.sin(2 * ph), 0, 12 * math.sin(ph)), z))
        k["tail"].append((f, (0, 0, 10 * math.sin(ph + 0.5)), z))
        k["tail2"].append((f, (0, 0, 16 * math.sin(ph - 0.4)), z))
    for b in k:
        k[b].append((n, k[b][0][1], k[b][0][2]))
    lp.add_action(arm, "idle", k, n)
    n = 16
    k = {b: [] for b in ("body", "head", "tail", "tail2", "leg_fr", "leg_fl", "leg_br", "leg_bl")}
    for f in range(1, n + 1):
        ph = (f - 1) / (n - 1) * tau
        s = math.sin(ph)
        k["body"].append((f, (0, 7 * s, 0), (0, 0.015 * abs(math.cos(ph)), 0)))
        k["head"].append((f, (2, 0, -6 * s), z))
        k["tail"].append((f, (0, 0, -14 * math.sin(ph - 0.7)), z))
        k["tail2"].append((f, (0, 0, -22 * math.sin(ph - 1.5)), z))
        for b, d in (("leg_fr", 1), ("leg_bl", 1), ("leg_fl", -1), ("leg_br", -1)):
            k[b].append((f, (-36 * d * s, 0, 0), (0, 0.03 * max(0.0, d * math.cos(ph)), 0)))
    lp.add_action(arm, "run", k, n)
    r = lambda x=0.0, y=0.0, zz=0.0: (x, y, zz)
    p = lambda up=0.0, fwd=0.0: (0, up, fwd)
    e = 22
    lp.add_action(arm, "cast_fire", {
        "body": [(1, z, z), (4, r(-10), p(0.05, -0.08)), (6, r(-12), p(0.06, -0.1)), (8, r(6), p(0.0, 0.12)), (15, r(5), p(0.0, 0.1)), (e, z, z)],
        "head": [(1, z, z), (4, r(-30), z), (6, r(-36), z), (8, r(16), z), (10, r(14, 0, 12), z), (12, r(14, 0, -12), z), (15, r(12), z), (e, z, z)],
        "leg_fr": [(1, z, z), (4, r(-14), z), (8, r(-4), z), (e, z, z)],
        "leg_fl": [(1, z, z), (4, r(-10), z), (8, r(-4), z), (e, z, z)],
        "tail": [(1, z, z), (4, r(-10, 0, 14), z), (8, r(8, 0, -10), z), (15, r(4, 0, 8), z), (e, z, z)],
        "tail2": [(1, z, z), (4, r(-24, 0, 20), z), (8, r(10, 0, -16), z), (15, r(6, 0, 12), z), (e, z, z)],
    }, e, loop=False)


# ---------------------------------------------------------------------------
# Golem de Basalto
# ---------------------------------------------------------------------------
def basalt_golem(cid="mob_basalt_golem", forge=False):
    """forge = Golem de Forja (lacaio do Kragmar): ferro escuro cintado, chaminé e cadinho de metal derretido no lugar
    das colunas de basalto."""
    arm = lp.make_armature("rig_" + cid, mk.pivots(arm_r=(0.62, 0, 1.3), arm_l=(-0.62, 0, 1.3), leg_fr=(0.25, 0, 0.44), leg_fl=(-0.25, 0, 0.44),
                                                    head=(0, -0.08, 1.4)))
    basalt = ck.mat("m_%s_basalt" % cid, (0.32, 0.29, 0.28) if forge else (0.23, 0.22, 0.26), 0.6 if forge else 0.9)
    basalt_d = ck.mat("m_%s_basalt2" % cid, (0.18, 0.16, 0.17) if forge else (0.14, 0.13, 0.17), 0.6 if forge else 0.9)
    lava = ck.mat("m_%s_lava" % cid, (1.0, 0.42, 0.08), 0.4, 2.6)
    hot = ck.mat("m_%s_hot" % cid, (1.0, 0.8, 0.25), 0.4, 3.0)
    parts = [(ck.box("bg_torso", (0.96, 0.66, 0.74), (0, 0, 1.0), basalt, 0.1), "body"),
             (ck.box("bg_belly", (0.62, 0.52, 0.38), (0, 0.02, 0.55), basalt_d, 0.09), "body"),
             (blob("bg_core", 0.14, (0, -0.33, 1.04), hot, (1.0, 0.6, 1.0)), "body"),
             (ck.box("bg_skull", (0.42, 0.38, 0.3), (0, -0.12, 1.52), basalt_d, 0.07), "head"),
             (ck.box("bg_mouth", (0.2, 0.04, 0.045), (0, -0.305, 1.44), lava), "head")]

    def crack(name, pts, bone, rad=0.028):
        for i in range(len(pts) - 1):
            parts.append((ck.tube("%s_%d" % (name, i), pts[i], pts[i + 1], rad, rad * 0.8, lava, 4), bone))

    fy = -0.335
    crack("bg_crack_a", [(-0.06, fy, 1.13), (-0.2, fy, 1.24), (-0.34, fy, 1.2), (-0.42, fy, 1.3)], "body")
    crack("bg_crack_b", [(0.07, fy, 1.12), (0.22, fy, 1.2), (0.3, fy, 1.32)], "body")
    crack("bg_crack_c", [(0.03, fy, 0.94), (0.14, fy, 0.82), (0.08, -0.25, 0.7), (0.16, -0.25, 0.56)], "body")
    crack("bg_crack_d", [(-0.08, fy, 0.95), (-0.2, fy, 0.86), (-0.16, -0.25, 0.68)], "body")
    crack("bg_crack_back", [(0.0, 0.335, 1.28), (0.1, 0.335, 1.1), (-0.04, 0.335, 0.92), (0.06, 0.28, 0.72)], "body", 0.032)
    for sx in (-1, 1):
        parts.append((blob("bg_eye%d" % sx, 0.047, (sx * 0.09, -0.305, 1.54), hot), "head"))
        bone = "arm_r" if sx > 0 else "arm_l"
        parts.append((ck.box("bg_shoulder%d" % sx, (0.4, 0.42, 0.36), (sx * 0.64, 0, 1.2), basalt_d, 0.08), bone))
        parts.append((ck.box("bg_forearm%d" % sx, (0.32, 0.34, 0.5), (sx * 0.7, -0.04, 0.8), basalt, 0.08), bone))
        parts.append((ck.box("bg_fist%d" % sx, (0.4, 0.4, 0.32), (sx * 0.72, -0.06, 0.46), basalt_d, 0.08), bone))
        ox = sx * 0.865
        crack("bg_armcrack%d" % sx, [(ox, -0.12, 1.0), (ox, 0.04, 0.82), (ox, -0.06, 0.62)], bone)
        parts.append((ck.box("bg_knuckle%d" % sx, (0.3, 0.03, 0.05), (sx * 0.72, -0.262, 0.44), lava), bone))
        leg = "leg_fr" if sx > 0 else "leg_fl"
        parts.append((ck.box("bg_leg%d" % sx, (0.32, 0.34, 0.44), (sx * 0.25, 0, 0.22), basalt_d, 0.08), leg))
        crack("bg_legcrack%d" % sx, [(sx * 0.2, -0.175, 0.38), (sx * 0.3, -0.175, 0.24), (sx * 0.24, -0.175, 0.1)], leg, 0.024)
    # colunas hexagonais de basalto nas costas e sobre os ombros (presas ao tronco); as mais altas com tampa de lava
    cols = ((-0.32, 0.3, 1.64, 0.14), (-0.1, 0.38, 1.9, 0.15), (0.13, 0.36, 1.76, 0.14), (0.33, 0.28, 1.6, 0.13), (0.0, 0.2, 1.52, 0.12),
            (-0.44, 0.04, 1.56, 0.12), (0.44, 0.04, 1.6, 0.12), (-0.5, 0.2, 1.46, 0.1), (0.5, 0.2, 1.44, 0.1))
    for i, (x, y, top, rr) in enumerate(() if forge else cols):
        parts.append((ck.tube("bg_column%d" % i, (x, y, 0.95), (x, y, top), rr, rr * 0.96, basalt if i % 2 else basalt_d, 6), "body"))
        if i in (1, 2, 6):
            parts.append((ck.tube("bg_columncap%d" % i, (x, y, top - 0.01), (x, y, top + 0.02), rr * 0.74, rr * 0.7, hot if i == 1 else lava, 6), "body"))
    if forge:
        band = ck.mat("m_%s_band" % cid, (0.5, 0.42, 0.34), 0.45)
        for k, zz in enumerate((0.84, 1.22)):
            parts.append((ck.box("bg_band%d" % k, (1.0, 0.7, 0.08), (0, 0, zz), band, 0.01), "body"))
        parts.append((ck.tube("bg_chimney", (0.24, 0.26, 1.3), (0.26, 0.3, 1.86), 0.12, 0.14, basalt_d, 7), "body"))
        parts.append((ck.tube("bg_chimneyglow", (0.26, 0.3, 1.85), (0.26, 0.3, 1.88), 0.11, 0.1, hot, 7), "body"))
        parts.append((ck.tube("bg_crucible", (-0.26, 0.2, 1.3), (-0.28, 0.22, 1.62), 0.17, 0.25, band, 8), "body"))
        parts.append((ck.tube("bg_melt", (-0.28, 0.22, 1.6), (-0.28, 0.22, 1.635), 0.22, 0.21, lava, 8), "body"))
        parts.append((blob("bg_drip", 0.05, (-0.42, 0.1, 1.5), hot, (1, 1, 1.6)), "body"))
    mk.finish(arm, parts)
    bm.mob_actions(arm)
    z = (0, 0, 0)
    r = lambda x=0.0, y=0.0, zz=0.0: (x, y, zz)
    p = lambda up=0.0, fwd=0.0: (0, up, fwd)
    # Pisão de Basalto (clipe "shout", impacto no quadro 7): ergue os punhos e a perna direita e desce tudo de uma vez
    e = 22
    lp.add_action(arm, "shout", {
        "body": [(1, z, z), (4, r(-12, 0, -4), p(0.1, -0.03)), (7, r(10), p(-0.07, 0.04)), (10, r(7), p(-0.05, 0.03)), (16, r(2), p(-0.01)), (e, z, z)],
        "head": [(1, z, z), (4, r(-16), z), (7, r(14), z), (11, r(6), z), (e, z, z)],
        "arm_r": [(1, z, z), (4, r(-150, 0, -14), z), (7, r(-22), z), (10, r(-14), z), (e, z, z)],
        "arm_l": [(1, z, z), (4, r(-150, 0, 14), z), (7, r(-22), z), (10, r(-14), z), (e, z, z)],
        "leg_fr": [(1, z, z), (4, r(-58), (0, 0.06, 0)), (7, r(2), z), (e, z, z)],
        "leg_fl": [(1, z, z), (4, r(6), z), (7, z, z), (e, z, z)],
    }, e, loop=False)
    # Fendas de Lava (clipe "cast_ground", impacto no quadro 10): junta os punhos no alto e crava os dois no chão
    e = 24
    lp.add_action(arm, "cast_ground", {
        "body": [(1, z, z), (6, r(-14), p(0.08, -0.04)), (8, r(-16), p(0.1, -0.05)), (10, r(30), p(-0.16, 0.12)), (15, r(28), p(-0.15, 0.11)), (20, r(8), p(-0.03, 0.02)), (e, z, z)],
        "head": [(1, z, z), (6, r(-18), z), (10, r(-10), z), (15, r(-14), z), (e, z, z)],
        "arm_r": [(1, z, z), (6, r(-165, 0, 16), z), (8, r(-172, 0, 18), z), (10, r(-58, 0, 12), z), (15, r(-54, 0, 12), z), (20, r(-16), z), (e, z, z)],
        "arm_l": [(1, z, z), (6, r(-165, 0, -16), z), (8, r(-172, 0, -18), z), (10, r(-58, 0, -12), z), (15, r(-54, 0, -12), z), (20, r(-16), z), (e, z, z)],
        "leg_fr": [(1, z, z), (10, r(-14), z), (15, r(-14), z), (e, z, z)],
        "leg_fl": [(1, z, z), (10, r(-14), z), (15, r(-14), z), (e, z, z)],
    }, e, loop=False)
    return arm


# ---------------------------------------------------------------------------
# nome do GLB -> construtor; HUMANOIDS saem por chibi_kit.export_glb (malha skinned), o resto por lowpoly_lib.export_glb
# ---------------------------------------------------------------------------
BUILDERS = {
    "mob_goblin_assassin": goblin_assassin,
    "mob_goblin_slayer": goblin_slayer,
    "mob_troll_thrower": troll_thrower,
    "mob_troll_brute": troll_brute,
    "mob_orc_fire_archer": orc_fire_archer,
    "mob_orc_warlord": orc_warlord,
    "mob_clan_guard": clan_guard,
    "mob_dire_wolf": lambda: dire_wolf("mob_dire_wolf"),
    "mob_dire_wolf_rider": lambda: dire_wolf("mob_dire_wolf_rider", rider=True),
    "mob_dire_wolf_mount": lambda: dire_wolf("mob_dire_wolf_mount", mount=True),
    "mob_lava_salamander": lava_salamander,
    "mob_basalt_golem": basalt_golem,
}
HUMANOIDS = {"mob_goblin_assassin", "mob_goblin_slayer", "mob_troll_thrower", "mob_troll_brute", "mob_orc_fire_archer", "mob_orc_warlord", "mob_clan_guard"}


# ===========================================================================
# WP4 parte 2 — chefes de Kharzun (plano §4), lacaios próprios e os três Estandartes de Clã
#   mob_dire_mother   Presa-de-Cinza: lobo atroz de juba de cinza, cicatrizes, olho cego, lanças quebradas no lombo
#   mob_shazka        Mestre Matador: rosto e nuca de máscara de osso, leque de cinco lâminas nas costas, capa
#   mob_ulgra         Ulgra Presa-Atroz: orc de capuz de pele de lobo montada, glaive, corrente com gancho, estandarte
#   mob_gorbash       Gorbash Pele-de-Rocha: troll xamã de placas de pedra, musgo, monólito de runas nas costas, cajado-totem
#   mob_kragmar       Kragmar Martelo-Negro: orc ferreiro de máscara de solda, fornalha nas costas, avental, martelo em brasa
#   mob_durgash       Durgash: coroa de chifres, ombreiras de caveira, capa, mastro alto com o estandarte dos três clãs
#   mob_stone_shaman  Xamã-Pedra (lacaio de Gorbash); mob_forge_golem Golem de Forja (lacaio de Kragmar)
#   mob_clan_banner_<wolf|stone|forge>  estandartes fincados do Durgash (~1,9 u; escala 1,6 no catálogo = 3 m)
# Clipes: humanoides são BOSS_HUMANOIDS (guardam MOB_BOSS_KEEP: atk_sweep, atk_charge, atk_throw, cast_ground, summon,
# shout...); Shazka guarda também atk_thrust. Lobos: shout = uivo; montados: summon e cast_ground.
# ===========================================================================
import act2_bosses

mk.BOSS_HUMANOIDS.update({"mob_shazka", "mob_gorbash", "mob_kragmar", "mob_durgash"})


def _farthest(prefix, origin):
    """Ponta da arma do kit (vértice mais longe da mão)."""
    best, bd = None, -1.0
    for o in bpy.context.scene.objects:
        if o.type == "MESH" and o.name.startswith(prefix):
            for v in o.data.vertices:
                d = (v.co - origin).length
                if d > bd:
                    best, bd = v.co.copy(), d
    return best


# ---------------------------------------------------------------------------
# Mestre Matador Shazka
# ---------------------------------------------------------------------------
def shazka_parts(cid):
    slayer = assassin_parts(cid, True)

    def add(base, mats):
        slayer(base, mats)
        rig, b, c, r, zc, zw, back, sw = _dims(base)
        front = -back
        bone = ck.mat("m_%s_bone" % cid, (0.92, 0.88, 0.76), 0.6)
        dark = ck.mat("m_%s_maskdark" % cid, (0.08, 0.07, 0.09), 0.7)
        steel = ck.mat("m_%s_steel" % cid, (0.66, 0.68, 0.74), 0.4)
        red = ck.mat("m_%s_red" % cid, (0.72, 0.1, 0.1), 0.7)
        gold = ck.mat("m_%s_gold" % cid, (0.88, 0.68, 0.26), 0.4)
        head, body, hips = [], [], []
        # máscara de osso fechando a boca (com a testeira do Matador vira caveira inteira) e uma segunda máscara na nuca
        head.append(ck.tube(cid + "_jawmask", c + V((0, -r * 0.1, -r * 0.56)), c + V((0, -r * 0.1, -r * 0.12)), r * 0.86, r * 1.03, bone, 14))
        for k in range(4):
            x = (k - 1.5) * r * 0.2
            head.append(ck.box("%s_jawslit%d" % (cid, k), (r * 0.06, r * 0.06, r * 0.26), c + V((x, -r * 1.02, -r * 0.34)), dark))
        bm_c = c + V((0, r * 1.02, -r * 0.12))
        head.append(ck.ball(cid + "_backmask", r * 0.6, bm_c, bone, (0.95, 0.4, 1.05)))
        for sx in (-1, 1):
            head.append(ck.ball("%s_backmaskeye%d" % (cid, sx), r * 0.13, bm_c + V((sx * r * 0.22, r * 0.2, r * 0.12)), dark, (1.2, 0.5, 0.8)))
            head.append(ck.blade("%s_crestside%d" % (cid, sx), c + V((sx * r * 0.3, r * 0.0, r * 0.95)), c + V((sx * r * 0.62, r * 0.75, r * 1.75)), r * 0.4, r * 0.07, gold, (1, 0, 0), 0.5))
        head.append(ck.box(cid + "_backmaskmouth", (r * 0.34, r * 0.06, r * 0.07), bm_c + V((0, r * 0.23, -r * 0.24)), dark))
        # leque de cinco lâminas embainhadas nas costas (por fora da capa): a marca dele vista de cima
        p = V((0, back + 0.27, zc + 0.02))
        for i in range(-2, 3):
            a = math.radians(i * 33)
            d = V((math.sin(a), 0.12, math.cos(a))).normalized()
            body.append(ck.tube("%s_fanhilt%d" % (cid, i), p - d * 0.02, p + d * 0.14, 0.022, 0.022, dark, 5))
            body.append(ck.box("%s_fanguard%d" % (cid, i), (0.1, 0.03, 0.03), p + d * 0.15, gold, 0.005))
            body.append(ck.blade("%s_fanblade%d" % (cid, i), p + d * 0.16, p + d * (0.86 - 0.06 * abs(i)), 0.085, 0.018, steel, (math.cos(a), 0, -math.sin(a)), 0.7))
        body.append(ck.ball(cid + "_fanhub", 0.075, p, gold, (1.0, 0.6, 1.0)))
        # capa mais longa de barra vermelha, máscaras de troféu no cinto
        body.append(ck.blade(cid + "_capelong", V((0, back + 0.07, zc + 0.16)), V((0, back + 0.24, ck.Z["ankle"] + 0.1)), 0.86, 0.03, red, (1, 0, 0), 0.2))
        for sx in (-1, 1):
            m = V((sx * sw * 0.8, front - 0.03, zw - 0.07))
            hips.append(ck.ball("%s_trophymask%d" % (cid, sx), 0.075, m, bone, (0.9, 0.45, 1.1)))
            for ex in (-1, 1):
                hips.append(ck.ball("%s_trophyeye%d_%d" % (cid, sx, ex), 0.017, m + V((ex * 0.028, -0.034, 0.015)), dark))
        _rigid(head, rig, "head")
        _rigid(body, rig, "chest")
        _rigid(hips, rig, "hips")
    return add


def shazka_blades(cid):
    """Depois das armas: a lâmina direita de fio rubro (execução), a esquerda de veneno."""
    def add(base, mats):
        f = V((0, -0.55, 0.83)).normalized()
        for side, col in ((".R", (1.0, 0.22, 0.15)), (".L", (0.5, 1.0, 0.3))):
            g = V(ck.hand_center(base, side))
            glow = ck.mat("m_%s_edge%s" % (cid, side[1]), col, 0.3, 2.4)
            ck.skin_rigid(ck.blade("%s_edge%s" % (cid, side[1]), g + f * 0.16, g + f * 1.0, 0.13, 0.014, glow, (1, 0, 0), 0.62), base["rig"], "hand" + side)
    return add


def shazka(cid="mob_shazka"):
    return mk.humanoid(cid, "leather", (0.12, 0.1, 0.13), "sword", skin=(0.4, 0.54, 0.27), eye=(1.0, 0.2, 0.15), offhand="sword", hide_hair=True, head="none",
                       keep=("atk_thrust",), extra=shazka_parts(cid), after=shazka_blades(cid))


# ---------------------------------------------------------------------------
# Gorbash Pele-de-Rocha e o Xamã-Pedra
# ---------------------------------------------------------------------------
# Albedo AZULADO de propósito (como o chão da arena dele em zones/build_kharzun_citadel.py): Gorbash só aparece na Cidadela,
# colado na tocha do jogador (1.0/0.72/0.42, energia 7) sobre o ambiente quente. Medido no tour (08_arena_pedra) a tela dá
# ~albedo x (1.45, 0.71, 0.42): a ardósia (0.26, 0.29, 0.39) saía bege/taupe e o musgo (0.27, 0.47, 0.19) limão. Com estes
# tons ele cai em cinza-ardósia com musgo verde-petróleo no jogo; na luz neutra (lineup) lê azul-aço, sem ficar preto.
GORBASH_SKIN = (0.15, 0.34, 0.48)
GORBASH_STONE = ((0.12, 0.24, 0.46), (0.07, 0.13, 0.26), (0.05, 0.3, 0.26))     # pedra, pedra escura, musgo
# Xamã-Pedra (lacaio, mesma arena e mesma tocha): a mesma compensação, um degrau mais claro que o chefe
SHAMAN_SKIN = (0.22, 0.46, 0.66)
SHAMAN_STONE = ((0.2, 0.36, 0.62), (0.12, 0.22, 0.42), (0.09, 0.4, 0.34))


def _stone_mats(cid, boss=False):
    """Pedra, pedra escura, musgo e runa. boss (Gorbash): ardósia fria e escura com musgo fundo e runa mais acesa. A pedra
    cinza médio (0.5) com musgo claro saía creme com limão no jogo (luz quente + faixa clara do toon): o chefe lia como um
    borrão claro, sem contraste de valor (art review 14). O Xamã-Pedra (lacaio) fica mais claro que ele de propósito."""
    pal = GORBASH_STONE if boss else SHAMAN_STONE
    out = (ck.mat("m_%s_stone" % cid, pal[0], 0.9), ck.mat("m_%s_stone2" % cid, pal[1], 0.9),
           ck.mat("m_%s_moss" % cid, pal[2], 0.9), ck.mat("m_%s_rune" % cid, (0.35, 1.0, 0.8), 0.3, 3.2 if boss else 2.4))
    # mob_kit.horde_parts("troll") já criou m_<cid>_stone/_stone2/_moss com o cinza claro do troll comum e ck.mat
    # devolve o material que existe sem repintar: sem isto a cor daqui não valia
    for m, col in zip(out, pal):
        bsdf = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
        bsdf.inputs["Base Color"].default_value = (*col, 1.0)
        m.diffuse_color = (*col, 1.0)
    return out


def gorbash_parts(cid, shaman=False):
    skin = SHAMAN_SKIN if shaman else GORBASH_SKIN
    face = mk.horde_parts(cid, "troll_whelp" if shaman else "troll", skin)

    def add(base, mats):
        face(base, mats)
        _strip(cid, ("_backrock",) if shaman else ("_backrock", "_rock"))
        rig, b, c, r, zc, zw, back, sw = _dims(base)
        front = -back
        j = base["j"]
        stone, stone2, moss, rune = _stone_mats(cid, not shaman)
        bone = ck.mat("m_%s_bone" % cid, (0.92, 0.88, 0.76), 0.6)
        head, body, arms = [], [], {".R": [], ".L": []}
        # capa de pedra na cabeça com musgo e runa na testa
        head.append(ck.ball(cid + "_stonecap", r * 1.1, c + V((0, r * 0.08, r * 0.26)), moss if shaman else stone, (1.05, 1.05, 0.6)))
        head.append(ck.ball(cid + "_browrune", r * 0.14, c + V((0, -r * 0.93, r * 0.56)), rune, (1.0, 0.5, 1.3)))
        if shaman:
            head.append(cone(cid + "_caphorn", c + V((0, r * 0.2, r * 0.8)), c + V((0, r * 0.5, r * 1.5)), r * 0.22, stone2, 5))
            body.append(ck.blade(cid + "_backstone", V((0, back + 0.06, zw + 0.02)), V((0, back + 0.2, zc + 0.36)), 0.3, 0.1, stone2, (1, 0, 0), 0.5))
            body.append(ck.tube(cid + "_backrune", V((0, back + 0.17, zc - 0.06)), V((0, back + 0.22, zc + 0.2)), 0.022, 0.012, rune, 4))
        else:
            head.append(ck.ball(cid + "_capmoss", r * 0.7, c + V((r * 0.12, r * 0.22, r * 0.76)), moss, (1.3, 1.1, 0.32)))
            for sx in (-1, 1):              # chifres de pedra: saem de lado e sobem
                h0 = c + V((sx * r * 0.86, r * 0.1, r * 0.5))
                h1 = h0 + V((sx * r * 0.6, 0, r * 0.05))
                head.append(ck.tube("%s_stonehorn%da" % (cid, sx), h0, h1, r * 0.24, r * 0.2, stone2, 6))
                head.append(cone("%s_stonehorn%db" % (cid, sx), h1, h1 + V((sx * r * 0.12, -r * 0.05, r * 0.85)), r * 0.2, stone, 6))
            # pele de rocha: lajes no peito, pedregulhos musgosos nos ombros, monólito de runas nas costas
            for i, (x, z_, rr) in enumerate(((-0.13, zc + 0.06, 0.14), (0.13, zc + 0.06, 0.14), (0.0, zw + 0.1, 0.17))):
                body.append(ck.ball("%s_plate%d" % (cid, i), rr, V((x, front - 0.035, z_)), stone if i % 2 else stone2, (1.0, 0.4, 1.0)))
            body.append(ck.ball(cid + "_runecore", 0.065, V((0, front - 0.085, zc + 0.07)), rune, (1, 0.5, 1)))
            for sx in (-1, 1):
                sh = V((sx * (sw + 0.1), 0.02, zc + 0.2))
                body.append(ck.ball("%s_boulder%d" % (cid, sx), 0.28, sh, stone, (1.15, 1.05, 0.8)))
                body.append(ck.ball("%s_boulder%db" % (cid, sx), 0.17, sh + V((sx * 0.17, 0.05, -0.08)), stone2, (1.0, 1.0, 0.8)))
                body.append(ck.ball("%s_bouldermoss%d" % (cid, sx), 0.2, sh + V((0, 0.03, 0.16)), moss, (1.2, 1.0, 0.35)))
            m0, m1 = V((0, back + 0.14, zw - 0.06)), V((0, back + 0.34, c.z + r * 1.6))
            body.append(ck.blade(cid + "_monolith", m0, m1, 0.56, 0.18, stone2, (1, 0, 0), 0.45))
            body.append(ck.ball(cid + "_monolithmoss", 0.16, m1 + V((0, -0.02, -0.12)), moss, (1.2, 1.0, 0.5)))
            for k in range(3):
                q = m0.lerp(m1, 0.3 + 0.2 * k) + V((0, 0.1, 0))
                body.append(ck.tube("%s_monorune%d" % (cid, k), q + V((-0.1, 0, -0.03)), q + V((0.1, 0, 0.05 if k % 2 else -0.05)), 0.026, 0.02, rune, 4))
                body.append(ck.tube("%s_monorune%db" % (cid, k), q + V((0, 0, -0.07)), q + V((0, 0, 0.07)), 0.022, 0.018, rune, 4))
            for s in (".R", ".L"):          # braçadeiras de pedra
                e, w = V(j["elbow" + s]), V(j["wrist" + s])
                arms[s].append(ck.tube("%s_bracer%s" % (cid, s[1]), e.lerp(w, 0.2), w, b["elbow"] * 1.6, b["wrist"] * 1.7, stone, 6))
        for i in range(7):                  # colar de contas de pedra e osso
            a = math.radians(-66 + i * 22)
            p = V((math.sin(a) * sw * 0.9, front - 0.02 - 0.05 * math.cos(a), zc + 0.15 - 0.07 * math.cos(a)))
            body.append(ck.ball("%s_bead%d" % (cid, i), 0.045 if i % 2 else 0.06, p, bone if i % 2 else stone2))
        _rigid(head, rig, "head")
        _rigid(body, rig, "chest")
        for s in arms:
            _rigid(arms[s], rig, "forearm" + s)
    return add


def totem_staff(cid, big=True):
    """Depois das armas: o cajado vira totem de pedra (cabeça de rocha com anel de runa, musgo e amuletos de osso)."""
    def add(base, mats):
        stone, stone2, moss, rune = _stone_mats(cid, big)
        bone = ck.mat("m_%s_bone" % cid, (0.92, 0.88, 0.76), 0.6)
        top = act2_bosses._top_vertex("wpn_main_staff")
        if top is None:
            return
        k = 1.0 if big else 0.7
        parts = [ck.ball(cid + "_totemhead", 0.17 * k, top + V((0, 0, 0.0)), stone, (1.0, 1.0, 0.9)),
                 ck.tube(cid + "_totemring", top + V((0, 0, -0.03 * k)), top + V((0, 0, 0.03 * k)), 0.19 * k, 0.19 * k, rune, 8),
                 ck.ball(cid + "_totemmoss", 0.1 * k, top + V((0.02, 0.02, 0.13 * k)), moss, (1.2, 1.1, 0.5)),
                 cone(cid + "_totemspike", top + V((0, 0, 0.1 * k)), top + V((0, 0, 0.36 * k)), 0.06 * k, stone2, 5)]
        for sx in (-1, 1):
            parts.append(ck.tube("%s_totemcord%d" % (cid, sx), top + V((sx * 0.16 * k, 0, -0.04)), top + V((sx * 0.19 * k, 0, -0.24 * k)), 0.008, 0.008, bone, 4))
            parts.append(cone("%s_totemcharm%d" % (cid, sx), top + V((sx * 0.19 * k, 0, -0.24 * k)), top + V((sx * 0.2 * k, 0, -0.38 * k)), 0.028 * k, bone, 5))
        _rigid(parts, base["rig"], "hand.R")
    return add


def gorbash(cid="mob_gorbash"):
    rig = mk.humanoid(cid, "leather", (0.25, 0.24, 0.2), "staff", skin=GORBASH_SKIN, eye=(0.4, 1.0, 0.8), hide_hair=True, head="none", attack="atk_1h_a",
                      extra=gorbash_parts(cid), after=totem_staff(cid), body="troll", posture=mk.TROLL_STANCE)
    # postura de troll: o totem entrava até 0,5 m no chão nos gestos de chefe (golpes, magias, queda)
    return mk.act2_bosses.clear_ground(rig, {"*": 0.0, "die": -0.2}, "hand.R", ("wpn_main_", cid + "_totem"), front=True)


def stone_shaman(cid="mob_stone_shaman"):
    rig = mk.humanoid(cid, "leather", (0.36, 0.42, 0.34), "staff", skin=SHAMAN_SKIN, eye=(0.4, 1.0, 0.8), hide_hair=True, head="none",
                      keep=("shout",), extra=gorbash_parts(cid, True), after=totem_staff(cid, False), body="troll", posture=mk.TROLL_STANCE)
    return mk.act2_bosses.clear_ground(rig, {"cast": 0.0}, "hand.R", ("wpn_main_", cid + "_totem"), front=True)


# ---------------------------------------------------------------------------
# Kragmar Martelo-Negro
# ---------------------------------------------------------------------------
def kragmar_parts(cid):
    face = mk.horde_parts(cid, "orc_warrior", (0.38, 0.46, 0.34))

    def add(base, mats):
        # ferro do elmo/ombreiras de horde_parts em ardósia clara (criado antes: ck.mat devolve o que já existe); o corpo
        # quase preto perdia o contorno e as faixas do toon
        ck.mat("m_%s_iron" % cid, (0.46, 0.48, 0.55), 0.45)
        face(base, mats)
        _strip(cid, ("_helmspike",))
        rig, b, c, r, zc, zw, back, sw = _dims(base)
        front = -back
        j = base["j"]
        ember, hot = _fire_mats(cid)
        iron = ck.mat("m_%s_iron2" % cid, (0.42, 0.44, 0.5), 0.45)
        iron_d = ck.mat("m_%s_iron3" % cid, (0.27, 0.29, 0.35), 0.5)
        leather = ck.mat("m_%s_apron" % cid, (0.52, 0.34, 0.19), 0.9)
        brass = ck.mat("m_%s_brass" % cid, (0.78, 0.56, 0.24), 0.4)
        head, body, hips, arms = [], [], [], {".R": [], ".L": []}
        # máscara de solda (chapa no rosto com fenda acesa) e duas chaminés no elmo
        head.append(ck.ball(cid + "_weldmask", r * 0.82, c + V((0, -r * 0.4, r * 0.02)), iron_d, (1.15, 0.8, 1.0)))
        head.append(ck.box(cid + "_weldslit", (r * 0.95, r * 0.1, r * 0.15), c + V((0, -r * 1.02, r * 0.1)), hot))
        for k in range(3):
            head.append(ck.ball("%s_weldrivet%d" % (cid, k), r * 0.07, c + V(((k - 1) * r * 0.42, -r * 0.98, -r * 0.3)), brass))
        for sx in (-1, 1):
            s0 = c + V((sx * r * 0.52, r * 0.3, r * 0.74))
            s1 = s0 + V((sx * r * 0.1, r * 0.12, r * 0.78))
            head.append(ck.tube("%s_stack%d" % (cid, sx), s0, s1, r * 0.2, r * 0.25, iron_d, 7))
            head.append(ck.tube("%s_stackrim%d" % (cid, sx), s0.lerp(s1, 0.78), s0.lerp(s1, 0.94), r * 0.28, r * 0.28, brass, 7))
            head.append(ck.ball("%s_stackglow%d" % (cid, sx), r * 0.22, s1, hot, (1, 1, 0.5)))
            head.append(cone("%s_stackflame%d" % (cid, sx), s1, s1 + V((sx * r * 0.06, r * 0.14, r * 0.62)), r * 0.19, ember, 5))
        # elmo-bigorna: crista de bigorna de latão do alto da testa à nuca, com a fenda do metal em brasa por cima
        # (de cima a cabeça era um domo escuro liso: agora tem um risco de fogo no meio)
        head.append(ck.box(cid + "_anvilcrest", (r * 0.36, r * 1.2, r * 0.36), c + V((0, r * 0.1, r * 0.85)), brass, r * 0.05))
        head.append(ck.box(cid + "_anvilhot", (r * 0.17, r * 1.04, r * 0.1), c + V((0, r * 0.1, r * 1.03)), hot))
        head.append(cone(cid + "_anvilhorn", c + V((0, -r * 0.42, r * 0.86)), c + V((0, -r * 1.05, r * 0.62)), r * 0.18, brass, 6))
        for sx in (-1, 1):                  # respiros acesos nos lados do domo
            for k in range(2):
                head.append(ck.box("%s_vent%d_%d" % (cid, sx, k), (r * 0.1, r * 0.34, r * 0.09), c + V((sx * (r * 0.5 + k * r * 0.24), -r * 0.34, r * (0.9 - k * 0.22))), ember))
        # fornalha nas costas: caixa de ferro com grade acesa, brasas em cima e dois canos
        fc = V((0, back + 0.18, zc + 0.02))
        body.append(ck.box(cid + "_furnace", (0.44, 0.28, 0.48), fc, iron_d, 0.03))
        body.append(ck.box(cid + "_furnacegrate", (0.28, 0.03, 0.22), fc + V((0, 0.14, -0.04)), hot))
        for k in (-1, 0, 1):
            body.append(ck.box("%s_furnacebar%d" % (cid, k), (0.03, 0.045, 0.24), fc + V((k * 0.08, 0.145, -0.04)), iron))
        body.append(ck.ball(cid + "_coals", 0.15, fc + V((0, 0, 0.25)), ember, (1.25, 0.8, 0.5)))
        body.append(cone(cid + "_coalflame", fc + V((0, 0, 0.28)), fc + V((0, 0.04, 0.52)), 0.08, hot, 6))
        for sx in (-1, 1):
            q0, q1 = fc + V((sx * 0.19, 0.04, 0.2)), V((sx * 0.36, back + 0.34, c.z + r * 0.75))
            body.append(ck.tube("%s_pipe%d" % (cid, sx), q0, q1, 0.05, 0.06, iron, 6))
            body.append(ck.ball("%s_pipeglow%d" % (cid, sx), 0.05, q1, ember, (1, 1, 0.5)))
            sh = V((sx * (sw + 0.07), 0.0, zc + 0.19))
            body.append(ck.ball("%s_pauldron%db" % (cid, sx), 0.25, sh, iron, (1.2, 1.1, 0.72)))
            # ombreira-cadinho: aro de latão e o metal derretido por cima (laranja de cima), bico de bigorna para fora
            body.append(ck.tube("%s_crucible%d" % (cid, sx), sh + V((0, 0, 0.1)), sh + V((0, 0, 0.2)), 0.2, 0.22, brass, 8))
            body.append(ck.ball("%s_melt%d" % (cid, sx), 0.185, sh + V((0, 0, 0.2)), ember, (1, 1, 0.3)))
            body.append(cone("%s_shhorn%d" % (cid, sx), sh + V((sx * 0.2, 0, 0.02)), sh + V((sx * 0.5, 0, 0.1)), 0.1, iron_d, 6))
            for k in range(3):
                a = math.radians(-50 + k * 50)
                body.append(ck.ball("%s_hotrivet%d_%d" % (cid, sx, k), 0.045, sh + V((sx * 0.27 * math.cos(a), 0.25 * math.sin(a), 0.0)), hot))
        # avental de couro e ferramentas no cinto
        body.append(ck.blade(cid + "_apron", V((0, front - 0.035, zc + 0.12)), V((0, front - 0.1, ck.Z["knee"] + 0.0)), 0.46, 0.03, leather, (1, 0, 0), 0.3))
        hips.append(ck.tube(cid + "_tongs", V((sw * 1.0, 0.0, zw - 0.02)), V((sw * 1.08, 0.02, zw - 0.3)), 0.02, 0.015, iron, 5))
        hips.append(ck.box(cid + "_smallhammer", (0.07, 0.12, 0.07), (-sw * 1.05, 0.0, zw - 0.24), iron, 0.01))
        hips.append(ck.tube(cid + "_smallhammerhaft", V((-sw * 1.05, 0.0, zw - 0.0)), V((-sw * 1.05, 0.0, zw - 0.24)), 0.016, 0.016, leather, 5))
        for s in (".R", ".L"):              # manoplas; a do martelo com cintas em brasa
            e, w = V(j["elbow" + s]), V(j["wrist" + s])
            arms[s].append(ck.tube("%s_gauntlet%s" % (cid, s[1]), e.lerp(w, 0.25), w, b["elbow"] * 1.55, b["wrist"] * 1.65, iron, 8))
            arms[s].append(ck.tube("%s_gauntletband%s" % (cid, s[1]), e.lerp(w, 0.45), e.lerp(w, 0.6), b["elbow"] * 1.7, b["elbow"] * 1.7, hot if s == ".R" else brass, 8))
        _rigid(head, rig, "head")
        _rigid(body, rig, "chest")
        _rigid(hips, rig, "hips")
        for s in arms:
            _rigid(arms[s], rig, "forearm" + s)
    return add


def forge_hammer(cid):
    """Depois das armas: a marreta do kit ganha a cabeça em brasa (bloco quente, faíscas)."""
    def add(base, mats):
        ember, hot = _fire_mats(cid)
        g = V(ck.hand_center(base, ".R"))
        top = _farthest("wpn_main_mace2h", g)
        if top is None:
            return
        d = (top - g).normalized()
        hc = top - d * 0.14
        # Martelo-Negro: bloco de ferro negro atravessado no cabo (cobre a cabeça da marreta do kit), as duas faces de
        # bater em brasa, cinta de latão e a rachadura acesa por cima
        black = ck.mat("m_%s_blackiron" % cid, (0.22, 0.23, 0.29), 0.5)
        brass = ck.mat("m_%s_brass" % cid, (0.78, 0.56, 0.24), 0.4)
        side = d.cross(V((0, 1, 0)))
        side = (side if side.length > 0.2 else d.cross(V((1, 0, 0)))).normalized()
        up = side.cross(d).normalized()
        L, W = 0.3, 0.35                       # meia-largura do bloco, lado da seção
        parts = []
        blk = ck.tube(cid + "_hammerblock", hc - side * L, hc + side * L, W * 0.62, W * 0.62, black, 4)
        parts.append(blk)
        for sx in (-1, 1):
            parts.append(ck.tube("%s_hammerface%d" % (cid, sx), hc + side * sx * L, hc + side * sx * (L + 0.07), W * 0.7, W * 0.6, ember, 4))
            parts.append(ck.ball("%s_hammercore%d" % (cid, sx), 0.13, hc + side * sx * (L + 0.07), hot, (1, 1, 1)))
            parts.append(ck.tube("%s_hammerband%d" % (cid, sx), hc + side * sx * (L - 0.14), hc + side * sx * (L - 0.06), W * 0.68, W * 0.68, brass, 4))
        parts.append(ck.tube(cid + "_hammercrack", hc + d * (W * 0.44) - side * (L * 0.7), hc + d * (W * 0.44) + side * (L * 0.7), 0.05, 0.05, hot, 4))
        parts.append(cone(cid + "_hammerspike", hc + d * (W * 0.4), hc + d * (W * 0.4 + 0.3), 0.09, black, 5))
        for k in range(3):
            a = math.tau * k / 3
            sp = hc + side * L * (1 if k % 2 else -1)
            parts.append(cone("%s_hammerspark%d" % (cid, k), sp, sp + side * (0.3 if k % 2 else -0.3) + up * 0.22 * math.cos(a) + d * 0.22 * math.sin(a), 0.035, hot, 4))
        _rigid(parts, base["rig"], "hand.R")
    return add


def kragmar(cid="mob_kragmar"):
    rig = mk.humanoid(cid, "plate", (0.34, 0.36, 0.43), "mace2h", skin=(0.38, 0.46, 0.34), eye=(1.0, 0.55, 0.15), hide_hair=True, head="none",
                      extra=kragmar_parts(cid), after=forge_hammer(cid), body="brute")
    return mk.act2_bosses.carry(rig, mk.act2_bosses.KRAGMAR_CARRY)


# ---------------------------------------------------------------------------
# Durgash, o Grão-Senhor da Guerra
# ---------------------------------------------------------------------------
CLAN_COLORS = {"wolf": (0.6, 0.57, 0.53), "stone": (0.38, 0.5, 0.6), "forge": (0.95, 0.45, 0.12)}


def durgash_parts(cid):
    face = mk.horde_parts(cid, "orc_warrior", (0.36, 0.45, 0.3))

    def add(base, mats):
        face(base, mats)
        _strip(cid, ("_helmspike", "_pspike"))
        rig, b, c, r, zc, zw, back, sw = _dims(base)
        front = -back
        j = base["j"]
        gold = ck.mat("m_%s_gold" % cid, (0.92, 0.7, 0.26), 0.35)
        horn = ck.mat("m_%s_horn" % cid, (0.93, 0.89, 0.76), 0.55)
        red = ck.mat("m_%s_red2" % cid, (0.7, 0.1, 0.09), 0.7)
        black = ck.mat("m_%s_flag" % cid, (0.1, 0.09, 0.11), 0.8)
        fur = ck.mat("m_%s_fur" % cid, (0.22, 0.18, 0.16), 0.95)
        fur2 = ck.mat("m_%s_fur2" % cid, (0.38, 0.32, 0.28), 0.95)
        iron = ck.mat("m_%s_iron2" % cid, (0.24, 0.24, 0.28), 0.45)
        wood = ck.mat("m_%s_wood2" % cid, (0.36, 0.26, 0.18), 0.8)
        fire = ck.mat("m_%s_jewel" % cid, (1.0, 0.3, 0.12), 0.3, 2.4)
        head, body, hips, arms = [], [], [], {".R": [], ".L": []}
        # coroa de chifres: aro de ouro, dois chifres enormes, quatro menores em volta, ponta de ouro e joia na testa
        head.append(ck.tube(cid + "_crownband", c + V((0, r * 0.04, r * 0.3)), c + V((0, r * 0.04, r * 0.48)), r * 1.15, r * 1.12, gold, 14))
        for sx in (-1, 1):
            h0 = c + V((sx * r * 0.86, 0, r * 0.56))
            h1 = h0 + V((sx * r * 0.75, 0, r * 0.3))
            head.append(ck.tube("%s_horn%da" % (cid, sx), h0, h1, r * 0.25, r * 0.2, horn, 7))
            head.append(cone("%s_horn%db" % (cid, sx), h1, h1 + V((sx * r * 0.22, -r * 0.18, r * 0.95)), r * 0.2, horn, 7))
            head.append(ck.tube("%s_hornring%d" % (cid, sx), h0.lerp(h1, 0.35), h0.lerp(h1, 0.55), r * 0.25, r * 0.24, gold, 8))
            for ang in (38, 142):
                a = math.radians(ang)
                d = V((sx * math.sin(a), -math.cos(a), 0))
                head.append(cone("%s_crownhorn%d_%d" % (cid, sx, ang), c + d * r * 0.82 + V((0, 0, r * 0.62)), c + d * r * 1.12 + V((0, 0, r * 1.42)), r * 0.14, horn, 6))
        head.append(cone(cid + "_crownspike", c + V((0, 0, r * 0.95)), c + V((0, 0, r * 1.6)), r * 0.15, gold, 6))
        head.append(ck.ball(cid + "_crownjewel", r * 0.15, c + V((0, -r * 1.12, r * 0.4)), fire, (1.0, 0.5, 1.2)))
        head.append(ck.blade(cid + "_crowntail", c + V((0, r * 0.3, r * 1.0)), c + V((0, r * 1.7, r * 0.1)), r * 0.5, r * 0.12, red, (1, 0, 0), 0.4))
        # ombreiras de três camadas com caveira e cravos de chifre; gola de pele e capa
        for sx in (-1, 1):
            sh = V((sx * (sw + 0.08), 0.0, zc + 0.2))
            body.append(ck.ball("%s_pauldron%db" % (cid, sx), 0.27, sh, iron, (1.2, 1.1, 0.72)))
            body.append(ck.ball("%s_pauldron%dc" % (cid, sx), 0.21, sh + V((sx * 0.14, 0, -0.1)), gold, (1.05, 1.05, 0.55)))
            body.append(ck.ball("%s_shskull%d" % (cid, sx), 0.095, sh + V((sx * 0.05, -0.2, 0.03)), horn, (1.0, 0.8, 1.0)))
            for k, (dx, dy) in enumerate(((0.0, -0.1), (0.12, 0.02), (0.0, 0.14))):
                p = sh + V((sx * dx, dy, 0.13))
                body.append(cone("%s_pspike%d_%d" % (cid, sx, k), p, p + V((sx * (0.08 + dx), dy * 0.5, 0.24)), 0.055, horn, 5))
        n = 9
        for i in range(n):
            a = math.radians(-100 + i * 200 / (n - 1))
            p = V((math.sin(a) * (sw + 0.1), 0.02 + math.cos(a) * (back + 0.08), zc + 0.21))
            body.append(ck.ball("%s_fur%d" % (cid, i), 0.125, p, fur if i % 2 else fur2, (1.0, 1.0, 0.8)))
        body.append(ck.blade(cid + "_cape", V((0, back + 0.06, zc + 0.2)), V((0, back + 0.3, ck.Z["ankle"] + 0.04)), 0.98, 0.035, red, (1, 0, 0), 0.22))
        for sx in (-1, 1):
            body.append(ck.blade("%s_capetail%d" % (cid, sx), V((sx * 0.22, back + 0.16, zw)), V((sx * 0.36, back + 0.36, ck.Z["ankle"] + 0.0)), 0.36, 0.03, red, (1, 0, 0), 0.3))
        body.append(ck.ball(cid + "_chestskull", 0.1, V((0, front - 0.06, zc + 0.07)), gold, (1.0, 0.45, 1.05)))
        # mastro alto nas costas: travessa com o estandarte negro de borda de ouro e uma flâmula de cada clã
        p0, p1 = V((0, back + 0.1, zw)), V((0, c.y + r * 1.9, c.z + r * 2.5))
        body.append(ck.tube(cid + "_pole", p0, p1, 0.034, 0.028, wood, 6))
        body.append(cone(cid + "_poletip", p1, p1 + V((0, 0.03, 0.2)), 0.05, gold, 6))
        bar = p1 + V((0, 0, -0.07))
        body.append(ck.tube(cid + "_bannerbar", bar + V((-0.4, 0, 0)), bar + V((0.4, 0, 0)), 0.024, 0.024, wood, 5))
        by = bar.y + 0.04
        body.append(ck.box(cid + "_banner", (0.6, 0.026, 0.7), (0, by, bar.z - 0.36), black))
        body.append(ck.box(cid + "_bannertop", (0.64, 0.034, 0.06), (0, by, bar.z - 0.04), gold))
        for sx in (-1, 1):
            body.append(ck.box("%s_bannerside%d" % (cid, sx), (0.035, 0.034, 0.7), (sx * 0.3, by, bar.z - 0.36), gold))
            body.append(ck.blade("%s_bannertail%d" % (cid, sx), V((sx * 0.15, by, bar.z - 0.7)), V((sx * 0.18, by, bar.z - 0.95)), 0.3, 0.026, black, (1, 0, 0), 0.05))
            body.append(ck.ball("%s_barskull%d" % (cid, sx), 0.06, bar + V((sx * 0.43, 0, 0)), horn))
        for yy in (by + 0.016, by - 0.016):
            body.append(ck.ball("%s_bannerskull%d" % (cid, int(yy > by)), 0.11, V((0, yy, bar.z - 0.3)), horn, (1.0, 0.3, 1.1)))
            for sx in (-1, 1):
                body.append(cone("%s_bannerhorn%d_%d" % (cid, sx, int(yy > by)), V((sx * 0.09, yy, bar.z - 0.24)), V((sx * 0.22, yy, bar.z - 0.12)), 0.035, horn, 5))
        for k, clan in enumerate(("wolf", "stone", "forge")):
            x = (k - 1) * 0.4
            m = ck.mat("m_%s_clan_%s" % (cid, clan), CLAN_COLORS[clan], 0.8, 1.6 if clan == "forge" else 0.0)
            z1 = bar.z + (0.02 if k != 1 else 0.12)
            body.append(ck.blade("%s_pennant_%s" % (cid, clan), V((x, bar.y - 0.03, z1)), V((x, bar.y - 0.05, z1 - 0.34)), 0.13, 0.02, m, (1, 0, 0), 0.25))
        # cinturão de ouro com caveiras e a corrente enrolada no quadril
        hips.append(ck.tube(cid + "_warbelt", V((0, 0, zw - 0.05)), V((0, 0, zw + 0.06)), sw * 1.12, sw * 1.12, gold, 12))
        hips.append(ck.tube(cid + "_warbelt_top", V((0, 0, zw + 0.06)), V((0, 0, zw + 0.11)), sw * 1.12, sw * 0.8, gold, 12))
        hips.append(ck.tube(cid + "_warbelt_low", V((0, 0, zw - 0.1)), V((0, 0, zw - 0.05)), sw * 0.86, sw * 1.12, gold, 12))
        for i in range(3):
            hips.append(ck.ball("%s_trophy%d" % (cid, i), 0.07, V(((i - 1) * 0.17, front - 0.07 + 0.03 * abs(i - 1), zw - 0.07)), horn, (1.0, 0.8, 1.0)))
        for k in range(6):
            a = math.tau * k / 6
            hips.append(ck.ball("%s_chain%d" % (cid, k), 0.04, V((-sw * 1.14, 0.02 + 0.09 * math.cos(a), zw - 0.16 + 0.09 * math.sin(a))), iron))
        hips.append(cone(cid + "_chainhook", V((-sw * 1.14, 0.02, zw - 0.25)), V((-sw * 1.2, -0.06, zw - 0.4)), 0.035, iron, 5))
        for s in (".R", ".L"):
            e, w = V(j["elbow" + s]), V(j["wrist" + s])
            arms[s].append(ck.tube("%s_bracer%s" % (cid, s[1]), e.lerp(w, 0.25), w, b["elbow"] * 1.55, b["wrist"] * 1.65, gold, 8))
        _rigid(head, rig, "head")
        _rigid(body, rig, "chest")
        _rigid(hips, rig, "hips")
        for s in arms:
            _rigid(arms[s], rig, "forearm" + s)
    return add


# Machado do Durgash (axe_kit): duplo de guerra com espigão, guarnição de ouro e cinta vermelha
DURGASH_AXE = {"head": "double", "spike": True, "gem": True, "S": 1.3, "shaft": 0.72, "butt": 0.14,
               "colors": {"trim": (0.92, 0.7, 0.26), "tint2": (0.62, 0.1, 0.08)}}


def durgash(cid="mob_durgash"):
    return mk.humanoid(cid, "plate", (0.34, 0.1, 0.09), "axe2h", skin=(0.36, 0.45, 0.3), eye=(1.0, 0.35, 0.1), hide_hair=True, head="none",
                       extra=durgash_parts(cid), axe=DURGASH_AXE, body="brute")


# ---------------------------------------------------------------------------
# Estandartes de Clã (lacaios parados do Durgash): pano no osso "head" (balança), mastro e base no "body"
# ---------------------------------------------------------------------------
def clan_banner(cid, clan):
    arm = lp.make_armature("rig_" + cid, mk.pivots(head=(0, 0, 1.66)))
    wood = ck.mat("m_%s_wood" % cid, (0.36, 0.26, 0.18), 0.8)
    iron = ck.mat("m_%s_iron" % cid, (0.24, 0.24, 0.28), 0.45)
    bone = ck.mat("m_%s_bone" % cid, (0.93, 0.89, 0.76), 0.6)
    stone = ck.mat("m_%s_stone" % cid, (0.46, 0.46, 0.48), 0.9)
    cloth = ck.mat("m_%s_cloth" % cid, {"wolf": (0.5, 0.46, 0.42), "stone": (0.34, 0.45, 0.55), "forge": (0.13, 0.11, 0.12)}[clan], 0.85)
    accent = {"wolf": ck.mat("m_%s_acc" % cid, (0.95, 0.93, 0.86), 0.6),
              "stone": ck.mat("m_%s_acc" % cid, (0.35, 1.0, 0.8), 0.3, 2.4),
              "forge": ck.mat("m_%s_acc" % cid, (1.0, 0.5, 0.1), 0.3, 2.6)}[clan]
    B, H = "body", "head"
    parts = []
    for k in range(5):                      # base de pedras em volta do mastro fincado
        a = math.tau * k / 5
        parts.append((ck.ball("bn_base%d" % k, 0.14 + 0.02 * (k % 2), (math.cos(a) * 0.2, math.sin(a) * 0.2, 0.08), stone, (1, 1, 0.7)), B))
    parts.append((ck.tube("bn_pole", (0, 0, 0), (0, 0, 1.9), 0.05, 0.04, wood, 7), B))
    parts.append((ck.tube("bn_bar", (-0.44, 0, 1.66), (0.44, 0, 1.66), 0.03, 0.03, wood, 6), B))
    for k in range(2):
        parts.append((ck.tube("bn_band%d" % k, (0, 0, 0.5 + k * 0.6), (0, 0, 0.56 + k * 0.6), 0.058, 0.058, iron, 7), B))
    cy = -0.08
    parts.append((ck.box("bn_cloth", (0.74, 0.035, 0.84), (0, cy, 1.21), cloth), H))
    parts.append((ck.box("bn_trim", (0.78, 0.045, 0.07), (0, cy, 1.6), accent), H))
    for sx in (-1, 1):
        parts.append((ck.blade("bn_tail%d" % sx, (sx * 0.185, cy, 0.8), (sx * 0.2, cy, 0.5), 0.37, 0.035, cloth, (1, 0, 0), 0.05), H))
    for f, yy in enumerate((cy - 0.022, cy + 0.022)):          # emblema nas duas faces do pano
        if clan == "wolf":                  # duas presas e três riscos de garra
            for sx in (-1, 1):
                parts.append((cone("bn_fang%d_%d" % (sx, f), (sx * 0.1, yy, 1.42), (sx * 0.06, yy, 1.08), 0.06, accent, 5), H))
            for k in (-1, 0, 1):
                parts.append((ck.blade("bn_claw%d_%d" % (k, f), (k * 0.11 - 0.05, yy, 1.02), (k * 0.11 + 0.05, yy, 0.86), 0.035, 0.012, iron, (1, 0, 0), 0.5), H))
        elif clan == "stone":               # anel de pedra com a runa acesa
            parts.append((ck.tube("bn_ring_%d" % f, (0, yy - 0.006, 1.24), (0, yy + 0.006, 1.24), 0.21, 0.21, stone, 6), H))
            parts.append((ck.tube("bn_rune_%d" % f, (0, yy * 1.12, 1.1), (0, yy * 1.12, 1.38), 0.03, 0.03, accent, 4), H))
            parts.append((ck.tube("bn_runeb_%d" % f, (-0.09, yy * 1.12, 1.29), (0.09, yy * 1.12, 1.19), 0.026, 0.026, accent, 4), H))
        else:                               # martelo em brasa
            parts.append((ck.box("bn_hammer_%d" % f, (0.3, 0.02, 0.15), (0, yy, 1.34), accent), H))
            parts.append((ck.tube("bn_haft_%d" % f, (0, yy, 0.98), (0, yy, 1.3), 0.026, 0.026, accent, 4), H))
    top = V((0, 0, 1.9))
    if clan == "wolf":                      # caveira de lobo no topo, tufos de pele nas pontas da travessa
        fur = ck.mat("m_%s_fur" % cid, (0.34, 0.31, 0.3), 0.95)
        parts.append((ck.ball("bn_skull", 0.11, top + V((0, 0, 0.06)), bone, (1.0, 1.1, 0.9)), B))
        parts.append((cone("bn_snout", top + V((0, -0.06, 0.04)), top + V((0, -0.3, -0.02)), 0.07, bone, 6), B))
        for sx in (-1, 1):
            parts.append((cone("bn_skullear%d" % sx, top + V((sx * 0.06, 0.02, 0.13)), top + V((sx * 0.1, 0.05, 0.3)), 0.035, bone, 4), B))
            parts.append((ck.ball("bn_tuft%d" % sx, 0.09, (sx * 0.46, 0, 1.62), fur, (1, 1, 1.3)), B))
            parts.append((cone("bn_tufttip%d" % sx, (sx * 0.46, 0, 1.58), (sx * 0.48, 0, 1.36), 0.06, fur, 5), B))
    elif clan == "stone":                   # menir no topo com musgo, pedras nas pontas
        moss = ck.mat("m_%s_moss" % cid, (0.4, 0.56, 0.3), 0.9)
        parts.append((ck.tube("bn_menhir", top + V((0, 0, -0.04)), top + V((0, 0, 0.3)), 0.11, 0.07, stone, 6), B))
        parts.append((ck.ball("bn_menhirmoss", 0.09, top + V((0.02, 0, 0.3)), moss, (1.2, 1.1, 0.5)), B))
        parts.append((ck.ball("bn_menhirrune", 0.04, top + V((0, -0.095, 0.12)), accent), B))
        for sx in (-1, 1):
            parts.append((ck.ball("bn_endstone%d" % sx, 0.085, (sx * 0.46, 0, 1.66), stone, (1, 1, 0.85)), B))
    else:                                   # braseiro no topo, correntes com brasa nas pontas
        hot = ck.mat("m_%s_hot" % cid, (1.0, 0.8, 0.25), 0.4, 3.0)
        parts.append((ck.tube("bn_brazier", top + V((0, 0, -0.02)), top + V((0, 0, 0.12)), 0.08, 0.15, iron, 8), B))
        parts.append((ck.ball("bn_coals", 0.13, top + V((0, 0, 0.13)), accent, (1, 1, 0.5)), B))
        for k in range(3):
            a = math.tau * k / 3
            p = top + V((math.cos(a) * 0.05, math.sin(a) * 0.05, 0.14))
            parts.append((cone("bn_flame%d" % k, p, p + V((math.cos(a) * 0.04, math.sin(a) * 0.04, 0.24 + 0.06 * (k % 2))), 0.055, hot if k % 2 else accent, 6), B))
        for sx in (-1, 1):
            parts.append((ck.tube("bn_chain%d" % sx, (sx * 0.44, 0, 1.66), (sx * 0.44, 0, 1.42), 0.012, 0.012, iron, 4), B))
            parts.append((ck.ball("bn_ember%d" % sx, 0.05, (sx * 0.44, 0, 1.38), accent), B))
    mk.finish(arm, parts)
    z = (0, 0, 0)
    r = lambda x=0.0, y=0.0, zz=0.0: (x, y, zz)
    tau = math.tau
    n = 48
    k = {"head": [], "body": []}
    for f in range(1, n + 1, 3):
        ph = (f - 1) / (n - 1) * tau
        k["head"].append((f, (5 * math.sin(ph) + 2, 0, 2.5 * math.sin(2 * ph + 0.6)), z))
        k["body"].append((f, (0.6 * math.sin(ph + 0.4), 0, 0.6 * math.sin(ph)), z))
    for b in k:
        k[b].append((n, k[b][0][1], k[b][0][2]))
    lp.add_action(arm, "idle", k, n)
    lp.add_action(arm, "hit", {"body": [(1, z, z), (2, r(-7, 0, 5), z), (5, r(4, 0, -3), z), (7, r(-1.5), z), (10, z, z)],
                               "head": [(1, z, z), (3, r(-16), z), (6, r(12), z), (10, z, z)]}, 10, loop=False)
    lp.add_action(arm, "die", {"root": [(1, z, z), (5, r(-6), z), (14, r(80, 0, 14), (0, 0.03, 0)), (17, r(74, 0, 14), (0, 0.03, 0)), (20, r(80, 0, 14), (0, 0.03, 0)), (24, r(80, 0, 14), (0, 0.03, 0))],
                               "head": [(1, z, z), (5, r(-14), z), (14, r(30), z), (18, r(12), z), (24, r(18), z)]}, 24, loop=False)
    for name, imp in (("attack", 5), ("shout", 7), ("cast", 10)):     # pulso da aura/skill: o pano estala no quadro do impacto
        e = imp + 12
        lp.add_action(arm, name, {"body": [(1, z, z), (imp - 2, r(-3), (0, 0.05, 0)), (imp, r(2), (0, -0.01, 0)), (imp + 4, z, z), (e, z, z)],
                                  "head": [(1, z, z), (imp - 2, r(-24), z), (imp, r(22), z), (imp + 3, r(-10), z), (imp + 7, r(5), z), (e, z, z)]}, e, loop=False)
    return arm


BUILDERS.update({
    "mob_dire_mother": lambda: dire_wolf("mob_dire_mother", mother=True),
    "mob_ulgra": lambda: dire_wolf("mob_ulgra", chief=True),
    "mob_shazka": shazka,
    "mob_gorbash": gorbash,
    "mob_kragmar": kragmar,
    "mob_durgash": durgash,
    "mob_stone_shaman": stone_shaman,
    "mob_forge_golem": lambda: basalt_golem("mob_forge_golem", forge=True),
    "mob_clan_banner_wolf": lambda: clan_banner("mob_clan_banner_wolf", "wolf"),
    "mob_clan_banner_stone": lambda: clan_banner("mob_clan_banner_stone", "stone"),
    "mob_clan_banner_forge": lambda: clan_banner("mob_clan_banner_forge", "forge"),
})
HUMANOIDS.update({"mob_shazka", "mob_gorbash", "mob_kragmar", "mob_durgash", "mob_stone_shaman"})
