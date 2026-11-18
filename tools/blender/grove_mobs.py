"""Bosque dos Xamãs (14-18): xamãs, formas espirituais, bichos invocados e o Arquidruida.

    mob_shaman_shifter  Xamã Metamorfo: crânio de urso com pele de lobo, penas, colar de osso, pintura verde/ocre, totem curto
    mob_shaman_caller   Xamã Invocador: galhada, manto comprido, gola de folhas, tambor na cintura, cajado-chocalho
    mob_shaman_bear     forma de urso (quadruped "bear" pintado: cangote maior, faixas turquesa/brancas, olhos acesos)
    mob_shaman_wolf     forma de lobo (pelo azul-fantasma, faixas, penas na juba)
    mob_shaman_hawk     forma de gavião (voa: rig da vespa; asas abertas em leque de penas)
    mob_rabbit          coelho (corrida aos pulos); modelado em tamanho dobrado: MonsterDef.scale ~0,5
    mob_deer            cervo esguio de galhada curta
    mob_archdruid       Arquidruida (chefe): coroa de galhada com folhas, manto de musgo e casca, cajado vivo com semente acesa

Humanoides saem de mob_kit.humanoid (kit chibi); bichos de mob_kit.quadruped (gancho `rider`) ou de peças rígidas.
Registro: mob_kit.build_all junta BUILDERS; HUMANOIDS exportam por ck.export_glb.

    import mob_kit; mob_kit.build_all(r"<abs>/assets/models", only=set(grove_mobs.BUILDERS))
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

# paleta da tribo (a mesma em todos os modelos)
BONE = (0.93, 0.89, 0.78)
GREEN = (0.34, 0.6, 0.32)          # pintura / folha
OCHRE = (0.84, 0.62, 0.24)
TEAL = (0.28, 0.8, 0.7)            # pintura de espírito
WHITE = (0.96, 0.96, 0.92)
PELT = (0.44, 0.4, 0.38)
WOOD = (0.42, 0.28, 0.17)
MOSS = (0.3, 0.46, 0.22)
BARK = (0.36, 0.27, 0.19)
LEAF = (0.46, 0.68, 0.28)
SKIN = (0.8, 0.62, 0.46)
GLOW = (0.35, 1.0, 0.8)


def _mats(cid):
    m = lambda n, c, r=0.8, e=0.0: ck.mat("m_%s_%s" % (cid, n), c, r, e)
    return {"bone": m("bone", BONE, 0.6), "green": m("green", GREEN), "ochre": m("ochre", OCHRE), "teal": m("teal", TEAL),
            "white": m("white", WHITE), "pelt": m("pelt", PELT, 0.9), "wood": m("wood", WOOD), "moss": m("moss", MOSS, 0.9),
            "bark": m("bark", BARK, 0.9), "leaf": m("leaf", LEAF), "dark": m("dark", (0.16, 0.12, 0.1)),
            "glow": ck.mat("glow_%s_spirit" % cid, GLOW, 0.3, 2.6)}


def _rigid(objs, rig, bone):
    for o in objs:
        ck.skin_rigid(o, rig, bone)


def _antler(cid, c, r, sx, k, mat, tines=2):
    """Galhada de um lado: haste em 2 lances + pontas (para a frente, para fora, para trás). Larga: lê de cima."""
    n = "%s_antler%d" % (cid, sx)
    h0 = c + V((sx * r * 0.5, r * 0.05, r * 0.78))
    h1 = h0 + V((sx * r * 0.45, r * 0.1, r * 0.55)) * k
    h2 = h1 + V((sx * r * 0.3, -r * 0.05, r * 0.7)) * k
    tine = lambda nm, a, d, rr: ck.tube(n + nm, a, a + d * k, r * rr, r * rr * 0.4, mat, 6)       # ponta rombuda: a de cone sumia no contorno
    out = [ck.tube(n + "a", h0, h1, r * 0.17, r * 0.14, mat, 6), ck.tube(n + "b", h1, h2, r * 0.14, r * 0.1, mat, 6),
           ck.ball(n + "j", r * 0.145, h1, mat),
           tine("tip", h2, V((sx * r * 0.05, -r * 0.1, r * 0.42)), 0.1),
           tine("t1", h1, V((-sx * r * 0.05, -r * 0.55, r * 0.42)), 0.12),
           tine("t2", h1.lerp(h2, 0.5), V((sx * r * 0.52, r * 0.1, r * 0.25)), 0.11)]
    if tines >= 3:
        out.append(tine("t3", h2, V((sx * r * 0.45, r * 0.15, r * 0.18)), 0.09))
        out.append(tine("t4", h1, V((sx * r * 0.05, r * 0.55, r * 0.3)), 0.11))
    return out, (h1, h2)


def _necklace(cid, body, sw, front, zc, m_a, m_b, teeth=True):
    for i in range(7):
        a = math.radians(-66 + i * 22)
        p = V((math.sin(a) * sw * 0.92, front - 0.025 - 0.05 * math.cos(a), zc + 0.15 - 0.08 * math.cos(a)))
        if teeth and i % 2 == 0:
            body.append(cone("%s_tooth%d" % (cid, i), p + V((0, 0, 0.03)), p + V((0, -0.02, -0.11)), 0.035, m_a, 5))
        else:
            body.append(ck.ball("%s_bead%d" % (cid, i), 0.045, p, m_b))


def shaman_parts(cid, kind):
    """kind: shifter | caller | archdruid. O que se lê de cima é a cabeça e os ombros."""
    def add(base, mats):
        rig, b, j = base["rig"], base["b"], base["j"]
        c, r = V(base["head_c"]), b["head"]
        zc, zw = ck.Z["chest"], ck.Z["waist"]
        back, sw = b["chest"] * b["depth"], b["chest"]
        front = -back
        M = _mats(cid)
        if kind == "archdruid":
            M["moss"] = ck.mat("m_%s_moss2" % cid, (0.2, 0.36, 0.17), 0.9)
        head, body, hips = [], [], []
        arms = {".R": [], ".L": []}
        fore = {".R": [], ".L": []}

        if kind == "shifter":
            # crânio de urso por cima da testa (focinho para a frente, órbitas escuras, dentes) + pele de lobo caindo nas costas
            head.append(ck.ball(cid + "_skull", r * 1.1, c + V((0, r * 0.06, r * 0.3)), M["bone"], (1.05, 1.08, 0.58)))
            head.append(ck.ball(cid + "_skullsnout", r * 0.36, c + V((0, -r * 1.0, r * 0.52)), M["bone"], (0.85, 1.3, 0.6)))
            head.append(ck.ball(cid + "_skullnose", r * 0.1, c + V((0, -r * 1.42, r * 0.6)), M["dark"], (1.2, 0.6, 0.7)))
            for sx in (-1, 1):
                head.append(ck.ball("%s_socket%d" % (cid, sx), r * 0.15, c + V((sx * r * 0.4, -r * 0.84, r * 0.6)), M["dark"], (1.0, 0.7, 0.8)))
                head.append(cone("%s_fang%d" % (cid, sx), c + V((sx * r * 0.16, -r * 1.3, r * 0.42)), c + V((sx * r * 0.17, -r * 1.34, r * 0.1)), r * 0.07, M["bone"], 5))
                head.append(cone("%s_peltear%d" % (cid, sx), c + V((sx * r * 0.62, r * 0.3, r * 0.7)), c + V((sx * r * 0.86, r * 0.42, r * 1.22)), r * 0.22, M["pelt"], 6))
                # pintura no rosto: dois riscos verdes por bochecha
                for q in range(2):
                    head.append(ck.ball("%s_cheek%d_%d" % (cid, sx, q), r * 0.1, c + V((sx * r * 0.52, -r * 0.85, -r * (0.12 + 0.2 * q))), M["green"], (1.7, 0.4, 0.45)))
            head.append(ck.ball(cid + "_pelthood", r * 0.98, c + V((0, r * 0.5, -r * 0.05)), M["pelt"], (1.12, 0.75, 1.05)))
            for i, (sx, col) in enumerate(((-1, "teal"), (0, "white"), (1, "ochre"))):          # penas em leque atrás do crânio
                head.append(ck.blade("%s_feather%d" % (cid, i), c + V((sx * r * 0.25, r * 0.55, r * 0.75)), c + V((sx * r * 0.7, r * 1.0, r * (1.75 if sx == 0 else 1.5))),
                                     r * 0.34, r * 0.06, M[col], (1, 0, 0), 0.55))
            body.append(ck.ball(cid + "_peltcape", 0.25, V((0, back + 0.02, zc + 0.17)), M["pelt"], (1.55, 0.75, 0.7)))
            body.append(ck.blade(cid + "_pelttail", V((0, back + 0.07, zc + 0.12)), V((0, back + 0.16, zw - 0.24)), 0.3, 0.07, M["pelt"], (1, 0, 0), 0.4))
            _necklace(cid, body, sw, front, zc, M["bone"], M["teal"])
            for s in (".R", ".L"):
                sh, el, wr = V(j["shoulder" + s]), V(j["elbow" + s]), V(j["wrist" + s])
                arms[s].append(ck.tube("%s_band%s" % (cid, s[1]), sh.lerp(el, 0.42), sh.lerp(el, 0.6), b["arm"] * 1.32, b["arm"] * 1.28, M["green"], 8))
                arms[s].append(ck.tube("%s_band2%s" % (cid, s[1]), sh.lerp(el, 0.72), sh.lerp(el, 0.82), b["arm"] * 1.25, b["arm"] * 1.22, M["ochre"], 8))
                fore[s].append(ck.tube("%s_wrap%s" % (cid, s[1]), el.lerp(wr, 0.45), el.lerp(wr, 0.95), b["elbow"] * 1.3, b["wrist"] * 1.45, M["bone"], 8))
        elif kind == "caller":
            # capuz de pano com galhada, pingentes de pena, gola de folhas, tambor na cintura
            head.append(ck.ball(cid + "_hood", r * 1.09, c + V((0, r * 0.1, r * 0.22)), M["moss"], (1.04, 1.06, 0.8)))
            head.append(ck.ball(cid + "_hoodband", r * 1.0, c + V((0, r * 0.02, r * 0.5)), M["ochre"], (1.08, 1.1, 0.2)))
            for sx in (-1, 1):
                objs, (h1, h2) = _antler(cid, c, r, sx, 1.0, M["bone"], 2)
                head += objs
                for q, (hp, col) in enumerate(((h1, "teal"), (h2, "white"))):
                    head.append(ck.blade("%s_dangle%d_%d" % (cid, sx, q), hp + V((0, 0.01, -0.01)), hp + V((sx * 0.02, 0.04, -r * 0.42)), r * 0.16, r * 0.04, M[col], (1, 0, 0), 0.5))
                head.append(ck.ball("%s_cheek%d" % (cid, sx), r * 0.11, c + V((sx * r * 0.52, -r * 0.85, -r * 0.2)), M["ochre"], (1.7, 0.4, 0.5)))
            for i in range(9):
                a = math.tau * i / 9 + 0.35
                d = V((math.cos(a), math.sin(a), 0))
                body.append(ck.blade("%s_collar%d" % (cid, i), V((d.x * 0.08, d.y * 0.06, zc + 0.24)), V((d.x * 0.42, d.y * 0.33, zc + 0.08)),
                                     0.24, 0.035, M["leaf"] if i % 2 else M["green"], (-d.y, d.x, 0), 0.6))
            _necklace(cid, body, sw, front, zc, M["bone"], M["ochre"], teeth=False)
            dc = V((sw + 0.07, -0.03, zw - 0.07))                       # tambor no lado esquerdo (+X)
            hips.append(ck.tube(cid + "_drum", dc + V((-0.06, 0, 0)), dc + V((0.07, 0, 0)), 0.14, 0.14, M["wood"], 10))
            hips.append(ck.tube(cid + "_drumskin", dc + V((0.07, 0, 0)), dc + V((0.085, 0, 0)), 0.145, 0.13, M["bone"], 10))
            hips.append(ck.ball(cid + "_drummark", 0.05, dc + V((0.09, 0, 0)), M["teal"], (0.3, 1, 1)))
            hips.append(ck.tube(cid + "_drumstrap", dc + V((0, 0, 0.1)), V((-sw * 0.5, front - 0.02, zc + 0.12)), 0.02, 0.02, M["wood"], 4))
        else:
            # Arquidruida: coroa de galhada com folhas, cabelo/barba de musgo claro, ombreiras de casca, capa de folhas
            k = 1.3
            head.append(ck.ball(cid + "_mosscap", r * 1.1, c + V((0, r * 0.1, r * 0.25)), M["moss"], (1.05, 1.08, 0.64)))
            head.append(ck.tube(cid + "_crownband", c + V((0, r * 0.03, r * 0.46)), c + V((0, r * 0.03, r * 0.64)), r * 1.0, r * 0.93, M["bark"], 12))
            head.append(ck.ball(cid + "_browgem", r * 0.13, c + V((0, -r * 0.95, r * 0.56)), M["glow"], (1.0, 0.5, 1.3)))
            for sx in (-1, 1):
                objs, (h1, h2) = _antler(cid, c, r, sx, k, M["bone"], 3)
                head += objs
                for q, p in enumerate((h1 + V((sx * 0.02, 0, 0.08)), h2 + V((0, 0, 0.1)), h1.lerp(h2, 0.5) + V((sx * r * 0.5 * k, 0.03, r * 0.3 * k)),
                                       h1 + V((0, -r * 0.5 * k, r * 0.42 * k)))):
                    head.append(ck.ball("%s_antleaf%d_%d" % (cid, sx, q), r * 0.2, p, M["leaf"] if q % 2 else M["green"], (1.15, 1.0, 0.8)))
                head.append(ck.ball("%s_brow%d" % (cid, sx), r * 0.14, c + V((sx * r * 0.36, -r * 0.93, r * 0.3)), M["white"], (1.6, 0.5, 0.5)))
            beard = ck.mat("m_%s_beard" % cid, (0.82, 0.88, 0.72), 0.8)
            head.append(ck.tube(cid + "_beard", c + V((0, -r * 0.78, -r * 0.55)), c + V((0, -r * 0.86, -r * 1.45)), r * 0.3, r * 0.05, beard, 8))
            head.append(ck.ball(cid + "_beardknot", r * 0.13, c + V((0, -r * 0.85, -r * 1.12)), M["teal"], (1.1, 1.0, 0.6)))
            head.append(ck.ball(cid + "_hairback", r * 0.9, c + V((0, r * 0.55, -r * 0.3)), beard, (1.05, 0.7, 1.2)))
            for sx in (-1, 1):
                sh = V((sx * (b["shoulder"] + 0.05), 0.01, zc + 0.2))
                body.append(ck.ball("%s_barkpad%d" % (cid, sx), 0.23, sh, M["bark"], (1.25, 1.1, 0.72)))
                body.append(ck.ball("%s_barkpad%db" % (cid, sx), 0.15, sh + V((sx * 0.16, 0.04, -0.08)), M["wood"], (1.0, 1.0, 0.8)))
                body.append(ck.ball("%s_padmoss%d" % (cid, sx), 0.17, sh + V((0, 0.03, 0.13)), M["moss"], (1.2, 1.0, 0.4)))
                for q in range(3):
                    a = math.radians(-40 + q * 40)
                    body.append(ck.blade("%s_padleaf%d_%d" % (cid, sx, q), sh + V((0, 0, 0.14)), sh + V((sx * 0.32 * math.cos(a), 0.3 * math.sin(a), 0.2)),
                                         0.16, 0.03, M["leaf"] if q % 2 == 0 else M["green"], (-math.sin(a), sx * math.cos(a), 0), 0.55))
                body.append(ck.ball("%s_shroom%d" % (cid, sx), 0.07, sh + V((sx * 0.1, -0.13, 0.12)), M["ochre"], (1.2, 1.2, 0.55)))
            body.append(ck.blade(cid + "_cape", V((0, back + 0.05, zc + 0.24)), V((0, back + 0.34, 0.12)), 0.86, 0.07, M["moss"], (1, 0, 0), 0.6))
            for i in range(7):
                t = 0.14 + 0.12 * i
                x = (((i * 37) % 7) / 6.0 - 0.5) * 0.5
                p = V((x, back + 0.07 + 0.29 * t, zc + 0.24 - (zc + 0.12) * t))
                body.append(ck.blade("%s_capeleaf%d" % (cid, i), p + V((0, 0.03, 0.03)), p + V((x * 0.3, 0.1, -0.2)), 0.2, 0.03,
                                     (M["leaf"], M["green"], M["ochre"])[i % 3], (1, 0, 0), 0.5))
            # placas de casca no peito com a semente acesa no meio
            for i, (x, z_, rr) in enumerate(((-0.12, zc + 0.05, 0.13), (0.12, zc + 0.05, 0.13), (0.0, zw + 0.08, 0.15))):
                body.append(ck.ball("%s_plate%d" % (cid, i), rr, V((x, front - 0.03, z_)), M["bark"] if i < 2 else M["wood"], (1.0, 0.4, 1.0)))
            body.append(ck.ball(cid + "_heartseed", 0.06, V((0, front - 0.085, zc + 0.08)), M["glow"], (1, 0.5, 1.2)))
            for s in (".R", ".L"):
                el, wr = V(j["elbow" + s]), V(j["wrist" + s])
                fore[s].append(ck.tube("%s_bracer%s" % (cid, s[1]), el.lerp(wr, 0.25), wr, b["elbow"] * 1.5, b["wrist"] * 1.65, M["bark"], 7))
                fore[s].append(ck.ball("%s_bracermoss%s" % (cid, s[1]), b["elbow"] * 1.2, el.lerp(wr, 0.3), M["moss"], (1.2, 1.2, 0.6)))
        _rigid(head, rig, "head")
        _rigid(body, rig, "chest")
        _rigid(hips, rig, "hips")
        for s in arms:
            _rigid(arms[s], rig, "upper_arm" + s)
            _rigid(fore[s], rig, "forearm" + s)
    return add


def shaman_staff(cid, kind):
    """Depois das armas: a ponta do cajado do kit vira totem (shifter), chocalho (caller) ou galho vivo com semente (archdruid)."""
    def add(base, mats):
        M = _mats(cid)
        top = mk.act2_bosses._top_vertex("wpn_main_staff")
        if top is None:
            return
        o = top + V((0, 0, -0.085))                 # centro do orbe do kit (fica coberto)
        parts = []
        if kind == "shifter":
            # totem entalhado: bloco de madeira com cara pintada, asas de pena e crânio pequeno em cima
            parts.append(ck.box(cid + "_totem", (0.2, 0.2, 0.34), o + V((0, 0, 0.02)), M["wood"], 0.02))
            parts.append(ck.box(cid + "_totembrow", (0.24, 0.24, 0.06), o + V((0, 0, 0.1)), M["green"], 0.01))
            parts.append(ck.box(cid + "_totemmouth", (0.22, 0.22, 0.05), o + V((0, 0, -0.08)), M["ochre"], 0.01))
            for sx in (-1, 1):
                parts.append(ck.ball("%s_totemeye%d" % (cid, sx), 0.035, o + V((sx * 0.055, -0.1, 0.03)), M["glow"], (1, 0.5, 1)))
                parts.append(ck.blade("%s_totemwing%d" % (cid, sx), o + V((sx * 0.09, 0, 0.02)), o + V((sx * 0.36, 0.02, 0.16)), 0.16, 0.03,
                                      M["teal"] if sx > 0 else M["white"], (0, 0, 1), 0.5))
            parts.append(ck.ball(cid + "_totemskull", 0.09, o + V((0, 0, 0.26)), M["bone"], (1.0, 1.1, 0.9)))
            for sx in (-1, 1):
                parts.append(cone("%s_totemhorn%d" % (cid, sx), o + V((sx * 0.06, 0, 0.3)), o + V((sx * 0.17, 0, 0.44)), 0.035, M["bone"], 5))
        elif kind == "caller":
            # chocalho: cabaça com faixa, coroa de penas e contas penduradas
            parts.append(ck.ball(cid + "_gourd", 0.14, o + V((0, 0, 0.03)), M["ochre"], (1.0, 1.0, 1.15)))
            parts.append(ck.tube(cid + "_gourdband", o + V((0, 0, 0.0)), o + V((0, 0, 0.06)), 0.147, 0.147, M["green"], 10))
            parts.append(ck.ball(cid + "_gourdtop", 0.05, o + V((0, 0, 0.2)), M["wood"]))
            for i in range(5):
                a = math.tau * i / 5
                d = V((math.cos(a), math.sin(a), 0))
                parts.append(ck.blade("%s_rfeather%d" % (cid, i), o + d * 0.05 + V((0, 0, 0.17)), o + d * 0.26 + V((0, 0, 0.36)), 0.11, 0.025,
                                      (M["teal"], M["white"], M["green"])[i % 3], (-d.y, d.x, 0), 0.55))
            for sx in (-1, 1):
                parts.append(ck.tube("%s_rcord%d" % (cid, sx), o + V((sx * 0.13, 0, -0.04)), o + V((sx * 0.17, 0, -0.26)), 0.008, 0.008, M["bone"], 4))
                parts.append(ck.ball("%s_rcharm%d" % (cid, sx), 0.04, o + V((sx * 0.17, 0, -0.29)), M["bone"]))
        else:
            # galho vivo: voluta em volta da semente acesa, folhas e raízes enroladas no cabo
            cc = o + V((0, 0, 0.14))
            parts.append(ck.ball(cid + "_seed", 0.115, cc, M["glow"], (1.0, 1.0, 1.2)))
            n = 9
            pts = []
            for i in range(n + 1):
                a = math.radians(-120 + 330 * i / n)
                rr = 0.24 - 0.006 * i
                pts.append(cc + V((math.sin(a) * rr, 0, -math.cos(a) * rr)))
            pts[0] = o + V((0, 0, -0.12))
            for i in range(n):
                w0, w1 = 0.05 - 0.0035 * i, 0.05 - 0.0035 * (i + 1)
                parts.append(ck.tube("%s_crook%d" % (cid, i), pts[i], pts[i + 1], w0, w1, M["wood"], 6))
                parts.append(ck.ball("%s_crookj%d" % (cid, i), w1 * 1.02, pts[i + 1], M["wood"]))
            for i, q in enumerate((2, 4, 6, 8)):
                p = pts[q]
                dv = (p - cc).normalized()
                parts.append(ck.blade("%s_stleaf%d" % (cid, i), p, p + dv * 0.2 + V((0, 0.06 if i % 2 else -0.06, 0)), 0.13, 0.025,
                                      M["leaf"] if i % 2 else M["green"], (0, 1, 0), 0.5))
            for i in range(3):
                p0 = o + V((0, 0, -0.2 - 0.2 * i))
                parts.append(ck.tube("%s_root%d" % (cid, i), p0 + V((0.035, 0, 0)), p0 + V((-0.035, 0.0, -0.1)), 0.022, 0.016, M["moss"], 5))
        _rigid(parts, base["rig"], "hand.R")
    return add


def shaman_shifter(cid="mob_shaman_shifter"):
    return mk.humanoid(cid, "leather", (0.62, 0.46, 0.24), "staff", skin=SKIN, hide_hair=True, head="none", keep=("shout",),
                       extra=shaman_parts(cid, "shifter"), after=shaman_staff(cid, "shifter"))


def shaman_caller(cid="mob_shaman_caller"):
    return mk.humanoid(cid, "cloth", (0.3, 0.47, 0.29), "staff", skin=SKIN, hide_hair=True, head="none", sex="female", keep=("summon",),
                       extra=shaman_parts(cid, "caller"), after=shaman_staff(cid, "caller"))


def archdruid(cid="mob_archdruid"):
    rig = mk.humanoid(cid, "cloth", (0.4, 0.31, 0.2), "staff", skin=(0.74, 0.64, 0.5), eye=(0.5, 1.0, 0.65), hide_hair=True, head="none",
                      body="brute", extra=shaman_parts(cid, "archdruid"), after=shaman_staff(cid, "archdruid"))
    # a voluta do cajado entrava no chão nos gestos de chefe (summon, cast_ground, queda)
    return mk.act2_bosses.clear_ground(rig, {"*": 0.0, "die": -0.2}, "hand.R", ("wpn_main_", cid + "_seed", cid + "_crook", cid + "_stleaf"), front=True)


# ---------------------------------------------------------------------------
# formas espirituais: urso e lobo (quadruped + pintura), gavião
# ---------------------------------------------------------------------------
def _arc(parts, name, y, cz, rx, rz, a0, a1, rad, mat, n=7, bone="body"):
    """Faixa pintada por cima do lombo: arco de elipse (rx, rz) no plano XZ em y, de a0 a a1 graus a partir do topo."""
    pts = []
    for i in range(n + 1):
        a = math.radians(a0 + (a1 - a0) * i / n)
        pts.append(V((rx * math.sin(a), y, cz + rz * math.cos(a))))
    for i in range(n):
        d = (pts[i + 1] - pts[i]).normalized() * rad * 0.4
        parts.append((ck.tube("%s_%d" % (name, i), pts[i] - d, pts[i + 1] + d, rad, rad, mat, 5), bone))


def spirit_paint(cid, kind):
    """Gancho `rider` de mob_kit.quadruped: pintura tribal, olhos acesos, contas e penas."""
    def add(parts, hip):
        M = _mats(cid)
        fur = bpy.data.materials["m_%s_fur" % cid]
        for o, _b in parts:                               # olhos acesos (sem o brilho branco)
            if "_eye" in o.name:
                o.data.materials[0] = M["glow"]
        if kind == "bear":
            bulk = 1.45
            hc = V((0, -0.8, hip + 0.28))
            # cangote maior + ombros
            parts.append((blob("hump", 0.3, (0, -0.3, hip + 0.32), fur, (1.45, 1.05, 0.7)), "body"))
            for sx in (-1, 1):
                parts.append((blob("shoulder%d" % sx, 0.24, (sx * 0.3, -0.36, hip + 0.14), fur, (0.9, 1.1, 1.0)), "body"))
            for dy, col in ((-0.13, "teal"), (0.1, "white")):
                f = math.sqrt(1 - (dy / 0.315) ** 2)
                _arc(parts, "humpstripe%d" % (dy > 0), -0.3 + dy, hip + 0.32, 0.445 * f, 0.22 * f, -62, 62, 0.036, M[col])
            _arc(parts, "stripe_a", 0.14, hip + 0.06, 0.34, 0.34, -68, 68, 0.036, M["teal"])
            _arc(parts, "stripe_b", 0.36, hip + 0.03, 0.31, 0.31, -64, 64, 0.034, M["white"])
            # máscara branca no alto da cabeça + runa acesa na testa
            parts.append((blob("mask", 0.21, hc + V((0, -0.04, 0.17)), M["white"], (1.0, 1.15, 0.52), 2), "head"))
            parts.append((blob("rune", 0.055, hc + V((0, -0.2, 0.235)), M["glow"], (1.0, 1.3, 0.6), 1), "head"))
            for sx in (-1, 1):
                parts.append((ck.tube("maskline%d" % sx, hc + V((sx * 0.13, -0.24, 0.16)), hc + V((sx * 0.19, -0.3, -0.02)), 0.028, 0.02, M["teal"], 5), "head"))
                for q, col in enumerate(("white", "teal")):
                    parts.append((ck.blade("feather%d_%d" % (sx, q), hc + V((sx * 0.2, 0.12, 0.16)), hc + V((sx * (0.3 + 0.1 * q), 0.5 - 0.08 * q, 0.24 + 0.08 * q)),
                                           0.1, 0.03, M[col], (0, 0, 1), 0.55), "head"))
            nr, nz = 0.29, hip + 0.17
            for i in range(9):                            # colar de contas no pescoço
                a = math.radians(-120 + 30 * i)
                parts.append((blob("bead%d" % i, 0.055, (nr * math.sin(a), -0.58, nz + nr * math.cos(a)), M["bone"] if i % 2 else M["teal"], (1, 1, 1), 1), "body"))
        else:
            hc = V((0, -0.74, hip + 0.28))
            _arc(parts, "manestripe", -0.5, hip + 0.18, 0.285, 0.25, -60, 60, 0.03, M["white"])
            _arc(parts, "stripe_a", -0.12, hip + 0.07, 0.245, 0.245, -66, 66, 0.03, M["teal"])
            _arc(parts, "stripe_b", 0.1, hip + 0.06, 0.24, 0.24, -66, 66, 0.028, M["white"])
            _arc(parts, "stripe_c", 0.3, hip + 0.035, 0.22, 0.22, -62, 62, 0.028, M["teal"])
            parts.append((blob("rune", 0.045, hc + V((0, -0.13, 0.17)), M["glow"], (1.0, 1.4, 0.6), 1), "head"))
            for sx in (-1, 1):
                parts.append((ck.tube("faceline%d" % sx, hc + V((sx * 0.09, -0.18, 0.13)), hc + V((sx * 0.15, -0.26, -0.02)), 0.022, 0.016, M["teal"], 5), "head"))
                for q, col in enumerate(("teal", "white")):
                    parts.append((ck.blade("feather%d_%d" % (sx, q), V((sx * 0.14, -0.44, hip + 0.38)), V((sx * (0.3 + 0.08 * q), -0.12 + 0.1 * q, hip + 0.6 - 0.08 * q)),
                                           0.11, 0.025, M[col], (0, 0, 1), 0.55), "body"))
            parts.append((blob("tail_band", 0.112, (0, 0.72, hip + 0.155), M["teal"], (1.0, 0.35, 1.0), 2), "body"))
            parts.append((blob("tail_bead", 0.04, (0, 0.72, hip + 0.28), M["bone"], (1, 1, 1), 1), "body"))
    return add


def shaman_bear(cid="mob_shaman_bear"):
    return mk.quadruped(cid, (0.5, 0.37, 0.26), (0.25, 0.18, 0.13), (0.86, 0.74, 0.55), "bear", rider=spirit_paint(cid, "bear"))


def shaman_wolf(cid="mob_shaman_wolf"):
    return mk.quadruped(cid, (0.7, 0.8, 0.9), (0.34, 0.47, 0.62), (0.95, 0.97, 1.0), "wolf", rider=spirit_paint(cid, "wolf"))


def shaman_hawk(cid="mob_shaman_hawk"):
    """Gavião-espírito (~2 m de ponta a ponta, paira a ~1,2 m). Rig da vespa: asas em arm_r/arm_l (giro Z = bate), cauda em leque
    no osso `tail`, garras em leg_fr/leg_fl. Clipes: idle (paira), run (plana inclinado), attack (empina e bate as asas para a
    frente, impacto no 5), cast (o mesmo sem avançar, mais alto), hit, die (cai de costas)."""
    zc = 1.2
    C = V((0, 0, zc))
    P = lambda x, y, z: C + V((x, y, z))
    bones = mk.pivots(body=(0, 0, zc - 0.1), head=tuple(P(0, -0.26, 0.08)), arm_r=tuple(P(0.12, -0.05, 0.08)), arm_l=tuple(P(-0.12, -0.05, 0.08)),
                      leg_fr=tuple(P(0.07, 0.05, -0.12)), leg_fl=tuple(P(-0.07, 0.05, -0.12)), leg_br=tuple(P(0.07, 0.12, -0.12)), leg_bl=tuple(P(-0.07, 0.12, -0.12)))
    bones["tail"] = (tuple(P(0, 0.22, -0.02)), tuple(P(0, 0.6, -0.02)), "body")
    arm = lp.make_armature("rig_" + cid, bones)
    M = _mats(cid)
    m = ck.mat("m_%s_fur" % cid, (0.68, 0.79, 0.9), 0.8)
    md = ck.mat("m_%s_dark" % cid, (0.3, 0.42, 0.58), 0.8)
    ml = ck.mat("m_%s_light" % cid, (0.96, 0.97, 1.0), 0.8)
    beak = ck.mat("m_%s_beak" % cid, (0.96, 0.76, 0.3), 0.5)
    parts = [(mk.skin_body("torso", [(P(0, 0.24, -0.03), 0.09), (P(0, 0.02, 0.0), 0.17), (P(0, -0.2, 0.05), 0.15)], [(0, 1), (1, 2)], m), "body"),
             (blob("chest", 0.15, P(0, -0.1, -0.07), ml, (0.95, 1.4, 0.75)), "body"),
             (blob("skull", 0.165, P(0, -0.37, 0.13), ml, (1.0, 1.05, 0.95)), "head"),
             (blob("cap", 0.13, P(0, -0.33, 0.21), m, (1.1, 1.2, 0.5), 2), "head"),
             (cone("beak", P(0, -0.48, 0.11), P(0, -0.7, 0.05), 0.07, beak, 6), "head"),
             (cone("beak_hook", P(0, -0.66, 0.07), P(0, -0.7, -0.05), 0.03, beak, 5), "head"),
             (blob("rune", 0.04, P(0, -0.44, 0.27), M["glow"], (1.0, 1.4, 0.6), 1), "head")]
    for sx in (-1, 1):
        parts.append((blob("%s_eye%d" % (cid, sx), 0.042, P(sx * 0.115, -0.47, 0.16), M["glow"], (0.7, 1.0, 1.1), 1), "head"))
        parts.append((ck.blade("crest%d" % sx, P(sx * 0.06, -0.26, 0.24), P(sx * 0.16, -0.02, 0.36), 0.1, 0.025, M["teal"], (1, 0, 0), 0.5), "head"))
    for i in range(7):                                  # colar de contas
        a = math.radians(-90 + 30 * i)
        parts.append((blob("bead%d" % i, 0.036, P(0.15 * math.sin(a), -0.25, 0.06 + 0.15 * math.cos(a)), M["bone"] if i % 2 else M["teal"], (1, 1, 1), 1), "body"))
    # asas: osso da frente em 2 lances + leque de penas para trás (primárias escuras na ponta), faixa turquesa e marca acesa
    for sx in (-1, 1):
        bone = "arm_r" if sx > 0 else "arm_l"
        r0, el, tip = P(sx * 0.12, -0.05, 0.08), P(sx * 0.52, -0.16, 0.15), P(sx * 1.04, -0.04, 0.1)
        parts.append((ck.tube("wingarm%da" % sx, r0, el, 0.06, 0.045, m, 6), bone))
        parts.append((ck.tube("wingarm%db" % sx, el, tip, 0.045, 0.02, m, 6), bone))
        parts.append((blob("covert%d" % sx, 0.2, r0.lerp(el, 0.55) + V((0, 0.12, 0.0)), m, (1.35, 1.0, 0.22), 2), bone))
        nf = 9
        for i in range(nf):
            t = i / (nf - 1.0)
            root = (r0.lerp(el, t / 0.45) if t < 0.45 else el.lerp(tip, (t - 0.45) / 0.55)) + V((0, 0.0, -0.015))
            out = sx * (0.02 + 0.3 * t * t)
            ln = 0.36 + 0.16 * math.sin(math.pi * min(1.0, t * 1.15)) - 0.1 * t * t
            ftip = root + V((out, ln, -0.03 - 0.02 * t))
            mat_f = md if i >= nf - 3 else (ml if i % 2 else m)
            parts.append((ck.blade("wfeather%d_%d" % (sx, i), root, ftip, 0.17, 0.02, mat_f, (1, -sx * 0.5 * t, 0), 0.5), bone))
        parts.append((ck.tube("wstripe%d" % sx, el + V((sx * 0.02, 0.05, 0.02)), el + V((sx * 0.1, 0.38, 0.0)), 0.026, 0.02, M["teal"], 5), bone))
        parts.append((ck.tube("wstripe%db" % sx, r0.lerp(el, 0.5) + V((0, 0.04, 0.045)), r0.lerp(el, 0.5) + V((sx * 0.03, 0.36, 0.01)), 0.024, 0.018, M["white"], 5), bone))
        parts.append((blob("wmark%d" % sx, 0.04, el.lerp(tip, 0.55) + V((0, 0.06, 0.02)), M["glow"], (1.3, 1.3, 0.5), 1), bone))
        # garras recolhidas
        lb = "leg_fr" if sx > 0 else "leg_fl"
        a, b_ = P(sx * 0.07, 0.05, -0.12), P(sx * 0.08, -0.02, -0.27)
        parts.append((ck.tube("shank%d" % sx, a, b_, 0.04, 0.026, beak, 5), lb))
        for q, dx in enumerate((-0.04, 0.0, 0.04)):
            parts.append((cone("claw%d_%d" % (sx, q), b_, b_ + V((dx, -0.09, -0.07)), 0.022, md, 4), lb))
    for i in range(5):                                  # cauda em leque
        a = math.radians(-36 + 18 * i)
        parts.append((ck.blade("fan%d" % i, P(0, 0.22, -0.02), P(math.sin(a) * 0.42, 0.24 + math.cos(a) * 0.44, -0.05), 0.15, 0.02,
                               (md, ml, m, ml, md)[i], (math.cos(a), -math.sin(a), 0), 0.6), "tail"))
    parts.append((ck.tube("fanband", P(-0.13, 0.45, -0.035), P(0.13, 0.45, -0.035), 0.024, 0.024, M["teal"], 5), "tail"))
    mk.finish(arm, parts)

    z = (0, 0, 0)
    tau = math.tau
    r = lambda x=0.0, y=0.0, zz=0.0: (x, y, zz)
    p = lambda up=0.0, fwd=0.0: (0, up, fwd)

    def wings(keys, seq):
        """seq = [(quadro, graus para cima)]"""
        keys["arm_r"] = [(f, (0, 0, -a), z) for f, a in seq]
        keys["arm_l"] = [(f, (0, 0, a), z) for f, a in seq]
        return keys

    def beat(keys, n, amp, mid, period, phase=0.5):
        return wings(keys, [(f, mid + amp * math.sin(tau * (f - 1) / period + phase)) for f in range(1, n + 1)])

    legs = ("leg_fr", "leg_fl")
    # idle: paira com batidas largas (2 por laço), o corpo sobe quando a asa desce
    n = 25
    idle = {b: [] for b in ("body", "head", "tail") + legs}
    for f in range(1, n + 1, 2):
        ph = (f - 1) / (n - 1) * tau
        idle["body"].append((f, (-8 + 3 * math.sin(2 * ph), 0, 2 * math.sin(ph)), (0, 0.07 * math.sin(2 * ph - 1.2), 0)))
        idle["head"].append((f, (8 + 2 * math.sin(ph + 1.0), 0, 12 * math.sin(ph + 1.6)), z))
        idle["tail"].append((f, (-10 + 8 * math.sin(2 * ph - 0.6), 0, 5 * math.sin(ph)), z))
        for i, b in enumerate(legs):
            idle[b].append((f, (8 * math.sin(ph + i * 1.2), 0, 0), z))
    lp.add_action(arm, "idle", beat(idle, n, 30.0, 4.0, 12), n)
    # run: plana inclinado para a frente, batidas curtas, cauda esticada
    n = 17
    run = {b: [] for b in ("body", "head", "tail") + legs}
    for f in range(1, n + 1, 2):
        ph = (f - 1) / (n - 1) * tau
        run["body"].append((f, (16 + 3 * math.cos(ph), 0, 6 * math.sin(ph)), (0, 0.05 * math.sin(2 * ph), 0)))
        run["head"].append((f, (-12 - 2 * math.cos(ph), 0, -4 * math.sin(ph)), z))
        run["tail"].append((f, (6 + 4 * math.sin(ph - 1.0), 0, 6 * math.sin(ph + 0.5)), z))
        for i, b in enumerate(legs):
            run[b].append((f, (30 + 5 * math.sin(ph + i), 0, 0), z))
    lp.add_action(arm, "run", beat(run, n, 24.0, 8.0, 8), n)
    # attack / cast: empina com as asas altas, joga as duas para a frente e para baixo no quadro 5, segura a rajada e volta
    for name, fwd, up in (("attack", 0.22, 0.1), ("cast", 0.0, 0.2)):
        e = 18
        keys = {
            "body": [(1, z, z), (3, r(-30), p(up, -0.12)), (5, r(-4), p(up * 0.4, fwd)), (8, r(-8), p(up * 0.5, fwd * 0.8)), (12, r(-18), p(up * 0.7, fwd * 0.3)), (15, r(-6), p(0.03, 0)), (e, z, z)],
            "head": [(1, z, z), (3, r(-16), z), (5, r(22), z), (8, r(16), z), (12, r(4), z), (e, z, z)],
            "tail": [(1, z, z), (3, r(24), z), (5, r(-30), z), (8, r(-22), z), (12, r(-4), z), (e, z, z)],
        }
        for b in legs:
            keys[b] = [(1, z, z), (3, r(-30), z), (5, r(-70), z), (8, r(-60), z), (13, r(-10), z), (e, z, z)]
        wings(keys, [(1, 18), (3, 58), (5, -42), (7, -36), (9, 40), (11, -30), (13, 30), (15, 6), (e, 18)])
        lp.add_action(arm, name, keys, e, loop=False)
    hit = {
        "body": [(1, z, z), (2, r(-20, 0, 14), p(0.03, -0.15)), (5, r(8, 0, -8), p(-0.03, -0.07)), (8, r(-2), p(0, -0.02)), (10, z, z)],
        "head": [(1, z, z), (2, r(-24, 0, 16), z), (5, r(8, 0, -8), z), (10, z, z)],
        "tail": [(1, z, z), (2, r(28), z), (5, r(-14, 0, 10), z), (10, z, z)],
    }
    for b in legs:
        hit[b] = [(1, z, z), (2, r(-30), z), (5, r(10), z), (10, z, z)]
    lp.add_action(arm, "hit", wings(hit, [(1, 18), (2, 50), (4, 10), (6, 36), (8, 8), (10, 18)]), 10, loop=False)
    # die: as asas travam abertas, gira de lado e cai de barriga; quica e as asas arriam no chão
    drop = -(zc - 0.24)
    e = 26
    die = {
        "root": [(1, z, z), (4, z, (0, 0.08, 0)), (12, z, (0, drop, 0)), (15, z, (0, drop + 0.08, 0)), (18, z, (0, drop, 0)), (e, z, (0, drop, 0))],
        "body": [(1, z, z), (4, r(-24, 0, 30), z), (8, r(10, 60, -20), z), (12, r(14, 110, 0), z), (15, r(8, 118, 0), z), (18, r(12, 122, 0), z), (e, r(12, 122, 0), z)],
        "head": [(1, z, z), (4, r(-26), z), (12, r(24, 0, 14), z), (18, r(30, 0, 20), z), (e, r(30, 0, 20), z)],
        "tail": [(1, z, z), (4, r(22), z), (12, r(-16), z), (15, r(10), z), (18, r(2), z), (e, r(4), z)],
    }
    for b in legs:
        die[b] = [(1, z, z), (4, r(-24), z), (12, r(34), z), (18, r(48), z), (e, r(46), z)]
    lp.add_action(arm, "die", wings(die, [(1, 18), (4, 52), (8, 44), (12, 10), (15, 22), (18, 4), (22, 0), (e, 0)]), e, loop=False)
    return arm


# ---------------------------------------------------------------------------
# bichos invocados: coelho e cervo
# ---------------------------------------------------------------------------
def rabbit(cid="mob_rabbit"):
    """Coelho, modelado em tamanho dobrado (~0,95 m de comprido) para os clipes de quadrúpede valerem: MonsterDef.scale ~0,5.
    Corrida aos pulos (as duas patas de trás juntas)."""
    hip = 0.3
    bones = mk.pivots(head=(0, -0.3, 0.5), leg_fr=(0.12, -0.24, 0.3), leg_fl=(-0.12, -0.24, 0.3), leg_br=(0.17, 0.2, 0.3), leg_bl=(-0.17, 0.2, 0.3))
    bones["tail"] = ((0, 0.42, hip + 0.06), (0, 0.62, hip + 0.12), "body")
    arm = lp.make_armature("rig_" + cid, bones)
    m = ck.mat("m_%s_fur" % cid, (0.8, 0.67, 0.52), 0.8)
    ml = ck.mat("m_%s_light" % cid, (0.98, 0.95, 0.9), 0.8)
    mp = ck.mat("m_%s_pink" % cid, (0.96, 0.66, 0.66), 0.7)
    m_eye, m_white = mk.base_mats()
    parts = [(mk.skin_body("torso", [((0, 0.26, hip + 0.02), 0.25), ((0, 0.0, hip + 0.04), 0.24), ((0, -0.22, hip + 0.1), 0.19)], [(0, 1), (1, 2)], m), "body"),
             (blob("belly", 0.2, (0, -0.02, hip - 0.1), ml, (0.9, 1.7, 0.6)), "body"),
             (blob("chestfluff", 0.14, (0, -0.33, hip + 0.06), ml, (1.1, 0.8, 1.0)), "body")]
    hc = V((0, -0.42, hip + 0.33))
    parts.append((blob("skull", 0.27, hc, m, (1.0, 0.95, 0.9)), "head"))
    parts.append((blob("muzzle", 0.12, hc + V((0, -0.2, -0.08)), ml, (1.25, 0.8, 0.75)), "head"))
    parts.append((blob("nose", 0.04, hc + V((0, -0.3, -0.03)), mp, (1.2, 0.8, 0.8), 1), "head"))
    parts += [(o, "head") for o in mk.eyes(cid, [hc + V((sx * 0.14, -0.21, 0.05)) for sx in (-1, 1)], 0.06, m_eye, m_white)]
    for sx in (-1, 1):
        e0, e1 = hc + V((sx * 0.1, 0.06, 0.2)), hc + V((sx * 0.2, 0.2, 0.78))
        parts.append((ck.blade("ear%d" % sx, e0, e1, 0.17, 0.06, m, (1, 0, 0), 0.5), "head"))
        parts.append((ck.blade("earin%d" % sx, e0 + V((0, -0.025, 0.06)), e1 + V((0, -0.03, -0.08)), 0.09, 0.03, mp, (1, 0, 0), 0.5), "head"))
        parts.append((blob("cheek%d" % sx, 0.1, hc + V((sx * 0.17, -0.12, -0.1)), ml, (1.0, 0.9, 0.8), 2), "head"))
        # patas da frente curtas; coxa redonda e pé comprido atrás
        top, foot = V((sx * 0.12, -0.24, hip)), V((sx * 0.13, -0.3, 0.06))
        fb, bb = ("leg_fr", "leg_br") if sx > 0 else ("leg_fl", "leg_bl")
        parts.append((ck.tube("leg_" + fb, top, foot, 0.065, 0.055, m, 7), fb))
        parts.append((blob("paw_" + fb, 0.07, foot + V((0, -0.03, -0.01)), ml, (1, 1.3, 0.7), 2), fb))
        parts.append((blob("haunch_" + bb, 0.2, (sx * 0.17, 0.2, hip - 0.04), m, (0.75, 1.15, 1.0)), bb))
        parts.append((blob("foot_" + bb, 0.1, (sx * 0.2, 0.06, 0.055), ml, (0.75, 2.2, 0.55), 2), bb))
    parts.append((blob("fur_tail", 0.12, (0, 0.5, hip + 0.1), ml), "tail"))
    mk.finish(arm, parts)
    bm.mob_actions(arm, quadruped=True)
    mk.quad_motion(arm, "wolf")
    mk.quad_combat(arm, "wolf")
    mk._drop_clips(arm, ("run",))
    n = 12
    run = {b: [] for b in ("body", "head", "tail", "leg_fr", "leg_fl", "leg_br", "leg_bl")}
    for f in range(1, n + 1):
        ph = (f - 1) / (n - 1) * math.tau
        run["body"].append((f, (-13 * math.sin(ph + 0.6), 0, 0), (0, 0.24 * (0.5 - 0.5 * math.cos(ph)), 0)))
        run["head"].append((f, (9 * math.sin(ph + 0.6) + 3, 0, 0), (0, 0, 0)))
        run["leg_br"].append((f, (52 * math.sin(ph + 0.9), 0, 0), (0, 0, 0)))
        run["leg_bl"].append((f, (52 * math.sin(ph + 0.8), 0, 0), (0, 0, 0)))
        run["leg_fr"].append((f, (-44 * math.sin(ph - 0.3), 0, 0), (0, 0, 0)))
        run["leg_fl"].append((f, (-44 * math.sin(ph - 0.45), 0, 0), (0, 0, 0)))
        run["tail"].append((f, (14 * math.sin(ph - 1.0), 0, 0), (0, 0, 0)))
    lp.add_action(arm, "run", run, n)
    return arm


def deer(cid="mob_deer"):
    """Cervo esguio: pernas finas e compridas, pescoço erguido, galhada curta, pintas claras no lombo, rabo branco."""
    hip = 0.74
    bones = mk.pivots(body=(0, 0, 0.6), head=(0, -0.4, hip + 0.14), leg_fr=(0.11, -0.3, hip), leg_fl=(-0.11, -0.3, hip),
                      leg_br=(0.11, 0.34, hip), leg_bl=(-0.11, 0.34, hip))
    bones["tail"] = ((0, 0.5, hip + 0.1), (0, 0.68, hip + 0.16), "body")
    arm = lp.make_armature("rig_" + cid, bones)
    m = ck.mat("m_%s_fur" % cid, (0.76, 0.53, 0.33), 0.8)
    md = ck.mat("m_%s_dark" % cid, (0.33, 0.23, 0.16), 0.8)
    ml = ck.mat("m_%s_light" % cid, (0.97, 0.92, 0.8), 0.8)
    m_horn = ck.mat("m_%s_antler" % cid, BONE, 0.5)
    m_eye, m_white = mk.base_mats()
    parts = [(mk.skin_body("torso", [((0, 0.4, hip + 0.03), 0.17), ((0, 0.05, hip + 0.03), 0.185), ((0, -0.3, hip + 0.07), 0.19)], [(0, 1), (1, 2)], m), "body"),
             (blob("belly", 0.15, (0, 0.02, hip - 0.07), ml, (0.85, 2.2, 0.6)), "body"),
             (blob("chestfluff", 0.13, (0, -0.42, hip + 0.04), ml, (1.0, 0.7, 1.2)), "body")]
    for i, (x, y) in enumerate(((0.08, -0.2), (-0.09, -0.05), (0.07, 0.1), (-0.07, 0.25), (0.1, 0.36), (-0.02, -0.32), (0.0, 0.42))):
        parts.append((blob("spot%d" % i, 0.04, (x, y, hip + 0.03 + math.sqrt(max(0.0, 0.18 ** 2 - x * x))), ml, (1, 1, 0.4), 1), "body"))
    hc = V((0, -0.7, hip + 0.6))
    parts.append((ck.tube("neck", (0, -0.38, hip + 0.1), hc + V((0, 0.06, -0.06)), 0.12, 0.085, m, 8), "head"))
    parts.append((blob("skull", 0.15, hc, m, (0.92, 1.05, 0.92)), "head"))
    parts.append((blob("muzzle", 0.09, hc + V((0, -0.17, -0.05)), ml, (0.75, 1.25, 0.75)), "head"))
    parts.append((blob("nose", 0.035, hc + V((0, -0.28, -0.03)), md, (1.2, 0.8, 0.9), 1), "head"))
    parts += [(o, "head") for o in mk.eyes(cid, [hc + V((sx * 0.085, -0.12, 0.03)) for sx in (-1, 1)], 0.042, m_eye, m_white)]
    for sx in (-1, 1):
        parts.append((ck.blade("ear%d" % sx, hc + V((sx * 0.1, 0.04, 0.08)), hc + V((sx * 0.3, 0.1, 0.17)), 0.11, 0.03, m, (0, 1, 0), 0.45), "head"))
        h0 = hc + V((sx * 0.06, 0.03, 0.12))
        h1 = h0 + V((sx * 0.1, 0.06, 0.22))
        parts.append((ck.tube("antler%da" % sx, h0, h1, 0.03, 0.024, m_horn, 5), "head"))
        parts.append((cone("antler%db" % sx, h1, h1 + V((sx * 0.1, -0.06, 0.2)), 0.024, m_horn, 5), "head"))
        parts.append((cone("antler%dc" % sx, h1, h1 + V((-sx * 0.02, 0.13, 0.13)), 0.022, m_horn, 5), "head"))
        parts.append((cone("antler%dd" % sx, h0.lerp(h1, 0.5), h0.lerp(h1, 0.5) + V((sx * 0.02, -0.13, 0.08)), 0.02, m_horn, 5), "head"))
        for bone, sy in ((("leg_fr" if sx > 0 else "leg_fl"), -1), (("leg_br" if sx > 0 else "leg_bl"), 1)):
            top = V((sx * 0.11, sy * 0.32 + (0.02 if sy < 0 else 0), hip))
            knee = V((sx * 0.115, sy * 0.33 + (0.04 if sy > 0 else 0.0), hip * 0.5))
            hoof = V((sx * 0.12, sy * 0.33, 0.05))
            parts.append((ck.tube("thigh_" + bone, top, knee, 0.075, 0.042, m, 7), bone))
            parts.append((ck.tube("shin_" + bone, knee, hoof, 0.042, 0.034, m, 6), bone))
            parts.append((blob("hoof_" + bone, 0.05, hoof + V((0, -0.01, -0.005)), md, (1, 1.2, 0.9), 1), bone))
    parts.append((blob("fur_tail", 0.07, (0, 0.56, hip + 0.1), m, (0.9, 1.3, 0.9), 2), "tail"))
    parts.append((blob("fur_tailw", 0.06, (0, 0.6, hip + 0.07), ml, (0.9, 1.2, 0.9), 2), "tail"))
    mk.finish(arm, parts)
    bm.mob_actions(arm, quadruped=True)
    mk.quad_motion(arm, "wolf")
    mk.quad_combat(arm, "wolf")
    return arm


BUILDERS = {
    "mob_shaman_shifter": shaman_shifter,
    "mob_shaman_caller": shaman_caller,
    "mob_shaman_bear": shaman_bear,
    "mob_shaman_wolf": shaman_wolf,
    "mob_shaman_hawk": shaman_hawk,
    "mob_rabbit": rabbit,
    "mob_deer": deer,
    "mob_archdruid": archdruid,
}
HUMANOIDS = {"mob_shaman_shifter", "mob_shaman_caller", "mob_archdruid"}
