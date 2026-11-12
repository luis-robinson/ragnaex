"""Ato II, peças que dão cara própria a chefes e formas (usado por mob_kit.humanoid):

- crossbow(base, mats, ...)  besta de verdade (Besteiro Orc, Mestre Besteiro, Besteiro da Luz) no lugar do arco
- posture(rig, offsets)      postura somada a todos os clipes (troll curvado: tronco para a frente, cabeça erguida)
- boss_extras(cid, kind)     peças grandes dos chefes: Mãe das Marés, Agitador-Mor, Rei-da-Rocha, Mestre Besteiro, Ghar
- lich_parts                 Forma de Lich do Necromante (form_lich.glb)

Regra da câmera alta: o que conta é cabeça, ombros e costas; cada chefe ganha uma silhueta que nenhum monstro comum tem.
"""
import math

from mathutils import Vector

import chibi_kit as ck

V = Vector


def cone(name, root, tip, r, material, segs=8):
    return ck.tube(name, root, tip, r, r * 0.08, material, segs)


def _rigid(objs, rig, bone):
    for o in objs:
        ck.skin_rigid(o, rig, bone)


def _top_vertex(prefix):
    import bpy
    best = None
    for o in bpy.context.scene.objects:
        if o.type == "MESH" and o.name.startswith(prefix):
            for v in o.data.vertices:
                if best is None or v.co.z > best.z:
                    best = v.co.copy()
    return best


# ---------------------------------------------------------------------------
# besta
# ---------------------------------------------------------------------------
def crossbow(base, mats, heavy=False, metal=(0.3, 0.3, 0.34), accent=(0.78, 0.14, 0.12)):
    """Besta na mão direita, no eixo das armas do kit (o clipe de tiro é o do mosquete: coronha no ombro).
    heavy = arbalete do Mestre Besteiro: maior, dois arcos de ferro e virote grosso."""
    rig = base["rig"]
    g = V(ck.hand_center(base, ".R"))
    fwd = V((0, -0.55, 0.83)).normalized()
    side = V((1, 0, 0))
    up = fwd.cross(side).normalized() * -1.0
    k = 1.4 if heavy else 1.15
    n = "xb_"
    wood = mats["wood"]
    iron = ck.mat("m_xbow_iron_%d" % int(metal[0] * 100), metal, 0.45)
    red = ck.mat("m_xbow_acc_%d" % int(accent[0] * 100), accent, 0.7)
    steel = mats["metal"]
    cord = ck.mat("m_string", (0.95, 0.95, 0.9))
    parts = [ck.tube(n + "tiller", g - fwd * 0.32 * k, g + fwd * 0.5 * k, 0.05 * k, 0.04 * k, wood, 6),
             ck.tube(n + "butt", g - fwd * 0.4 * k, g - fwd * 0.3 * k, 0.07 * k, 0.055 * k, iron, 6),
             ck.tube(n + "trigger", g + fwd * 0.02 - up * 0.04 * k, g + fwd * 0.1 - up * 0.1 * k, 0.012, 0.012, iron, 4),
             ck.tube(n + "stirrup", g + fwd * 0.5 * k, g + fwd * 0.57 * k, 0.065 * k, 0.065 * k, iron, 8)]
    rail = up * 0.05 * k
    for pi, pz in enumerate((0.44, 0.3) if heavy else (0.44,)):
        span = (0.42 if pi == 0 else 0.32) * k
        c0 = g + fwd * pz * k + rail
        ts = (-1.0, -0.62, -0.22, 0.22, 0.62, 1.0)
        pts = [c0 + side * (t * span) - fwd * (0.17 * k * t * t) for t in ts]
        for i in range(5):
            ra = 0.034 * k * (1.0 - 0.45 * abs(ts[i]))
            rb = 0.034 * k * (1.0 - 0.45 * abs(ts[i + 1]))
            parts.append(ck.tube("%sprod%d_%d" % (n, pi, i), pts[i], pts[i + 1], ra, rb, iron, 6))
        nock = g + fwd * (pz - 0.3) * k + rail
        for i, tip in enumerate((pts[0], pts[-1])):
            parts.append(ck.tube("%sstring%d_%d" % (n, pi, i), tip, nock, 0.007, 0.007, cord, 4))
        parts.append(ck.tube("%slash%d" % (n, pi), c0 - rail * 0.3, c0 + rail * 0.5, 0.055 * k, 0.055 * k, red, 6))
    b0 = g + fwd * 0.14 * k + rail
    b1 = g + fwd * 0.6 * k + rail
    parts += [ck.tube(n + "bolt", b0, b1, 0.016 * k, 0.016 * k, wood, 5),
              cone(n + "bolthead", b1, b1 + fwd * 0.13 * k, 0.034 * k, steel, 5),
              ck.blade(n + "fletch", b0 - fwd * 0.01, b0 + fwd * 0.1 * k, 0.07 * k, 0.012, red, up, 0.4)]
    obj = ck._join(parts, "wpn_main_crossbow")
    ck._smooth(obj.data)
    ck.skin_rigid(obj, rig, "hand.R")
    return obj


# ---------------------------------------------------------------------------
# postura
# ---------------------------------------------------------------------------
TROLL_POSTURE = {"spine": (15, 0, 0), "chest": (13, 0, 0), "neck": (-8, 0, 0), "head": (-17, 0, 0),
                 "upper_arm.R": (-4, 0, 0), "forearm.R": (24, 0, 0), "upper_arm.L": (-22, 0, 0)}     # braço da arma mais solto: a marreta desce do rosto
TROLL_HIPS = (0.0, 0.05, -0.02)        # quadril um pouco para trás e para baixo: o peso do tronco fica sobre os pés


def posture(rig, offsets, hips=None):
    """Soma `offsets` (graus XYZ por osso) a TODOS os clipes do rig: a postura vale parado, correndo e golpeando.
    Ossos sem curva num clipe ficam como estão. `hips` = deslocamento somado ao quadril."""
    ad = rig.animation_data
    if ad is None:
        return
    for t in ad.nla_tracks:
        act = t.strips[0].action
        for fc in ck._fcurves(act):
            path = fc.data_path
            if not path.startswith('pose.bones["'):
                continue
            bone = path.split('"')[1]
            if path.endswith("rotation_euler") and bone in offsets:
                d = math.radians(offsets[bone][fc.array_index])
            elif path.endswith("location") and bone == "hips" and hips:
                d = hips[fc.array_index]
            else:
                continue
            if abs(d) < 1e-6:
                continue
            for kp in fc.keyframe_points:
                kp.co.y += d
                kp.handle_left.y += d
                kp.handle_right.y += d
            fc.update()


# ---------------------------------------------------------------------------
# chefes
# ---------------------------------------------------------------------------
def boss_extras(cid, kind):
    """Peças de chefe por cima de horde_parts (rodam DEPOIS da arma: algumas vestem a arma)."""
    def add(base, mats):
        rig, b = base["rig"], base["b"]
        c, r = V(base["head_c"]), b["head"]
        zc, zw = ck.Z["chest"], ck.Z["waist"]
        back, front = b["chest"] * b["depth"], -b["chest"] * b["depth"]
        sw = b["chest"]
        bone = ck.mat("m_%s_bossbone" % cid, (0.93, 0.89, 0.76), 0.6)
        iron = ck.mat("m_%s_bossiron" % cid, (0.26, 0.26, 0.3), 0.45)
        red = ck.mat("m_%s_bossred" % cid, (0.8, 0.14, 0.12), 0.7)
        head, body, hips, hand = [], [], [], []

        def skull(name, p, s, mat_eye):
            out = [ck.ball(name, s, p, bone, (1.0, 1.0, 0.95)),
                   ck.ball(name + "_jaw", s * 0.6, p + V((0, -s * 0.35, -s * 0.75)), bone, (1.0, 0.9, 0.7))]
            for sx in (-1, 1):
                out.append(ck.ball("%s_eye%d" % (name, sx), s * 0.24, p + V((sx * s * 0.38, -s * 0.82, s * 0.05)), mat_eye))
            return out

        dark = ck.mat("m_%s_bossdark" % cid, (0.1, 0.08, 0.1), 0.7)
        if kind == "tide_mother":
            coral = ck.mat("m_%s_coral" % cid, (0.98, 0.45, 0.42), 0.5)
            coral2 = ck.mat("m_%s_coral2" % cid, (1.0, 0.66, 0.5), 0.5)
            pearl = ck.mat("m_%s_pearl" % cid, (0.95, 0.97, 1.0), 0.2, 0.9)
            water = ck.mat("m_%s_water" % cid, (0.45, 0.9, 1.0), 0.2, 1.4)
            shell = ck.mat("m_%s_shell" % cid, (0.98, 0.84, 0.8), 0.45)
            fin = ck.mat("m_%s_fin" % cid, (0.2, 0.55, 0.65), 0.6)
            for sx in (-1, 1):                  # galhada de coral: tronco, dois galhos e pontas
                p0 = c + V((sx * r * 0.55, r * 0.1, r * 0.7))
                p1 = p0 + V((sx * r * 0.55, r * 0.1, r * 0.75))
                p2 = p1 + V((sx * r * 0.5, 0, r * 0.7))
                head.append(ck.tube("%s_antler%d_a" % (cid, sx), p0, p1, r * 0.17, r * 0.13, coral, 6))
                head.append(cone("%s_antler%d_b" % (cid, sx), p1, p2, r * 0.13, coral, 6))
                head.append(cone("%s_antler%d_c" % (cid, sx), p1, p1 + V((-sx * r * 0.15, -r * 0.1, r * 0.75)), r * 0.11, coral2, 6))
                head.append(cone("%s_antler%d_d" % (cid, sx), p0.lerp(p1, 0.5), p0.lerp(p1, 0.5) + V((sx * r * 0.6, r * 0.25, r * 0.1)), r * 0.1, coral2, 6))
                head.append(ck.ball("%s_antlerpearl%d" % (cid, sx), r * 0.11, p2 + V((0, 0, r * 0.05)), pearl))
                # ombreiras de concha (leque de gomos) por cima das escamas
                sc = V((sx * (sw + 0.07), 0.0, zc + 0.17))
                for i in range(5):
                    a = math.radians(-60 + i * 30)
                    tip = sc + V((sx * 0.2 * math.cos(a) + sx * 0.04, 0.2 * math.sin(a), 0.12 - 0.05 * abs(i - 2)))
                    body.append(ck.blade("%s_shell%d_%d" % (cid, sx, i), sc, tip, 0.13, 0.03, shell if i % 2 else coral2, (-math.sin(a) * sx, math.cos(a), 0), 0.7))
            head.append(ck.ball(cid + "_browpearl", r * 0.16, c + V((0, -r * 0.93, r * 0.45)), pearl))
            for i in range(4):                  # barbatana dorsal em leque nas costas
                z = zc + 0.2 - i * 0.13
                body.append(ck.blade("%s_dorsal%d" % (cid, i), V((0, back + 0.02, z)), V((0, back + 0.34 - i * 0.04, z + 0.16)), 0.2, 0.03, fin, (0, 0, 1), 0.5))
            top = _top_vertex("wpn_main_staff")  # o cajado vira tridente de coral com a pérola das marés
            if top is not None:
                for i in (-1, 0, 1):
                    hand.append(cone("%s_prong%d" % (cid, i), top + V((i * 0.07, 0, -0.03)), top + V((i * 0.16, 0, 0.3 if i else 0.4)), 0.035, coral, 6))
                hand.append(ck.tube(cid + "_prongbar", top + V((-0.13, 0, -0.02)), top + V((0.13, 0, -0.02)), 0.03, 0.03, coral2, 6))
                hand.append(ck.ball(cid + "_tideorb", 0.11, top + V((0, 0, 0.02)), water))
        elif kind == "agitator_lord":
            wood = ck.mat("m_%s_bosswood" % cid, (0.42, 0.3, 0.2), 0.8)
            fire = ck.mat("m_%s_eyefire" % cid, (1.0, 0.5, 0.15), 0.3, 2.0)
            for sx in (-1, 1):                  # dois totens de caveira com flâmula saindo do tambor das costas
                p0 = V((sx * 0.2, back + 0.2, zc - 0.1))
                p1 = V((sx * 0.38, back + 0.3, zc + 0.95))
                body.append(ck.tube("%s_totem%d" % (cid, sx), p0, p1, 0.03, 0.025, wood, 6))
                body += skull("%s_totemskull%d" % (cid, sx), p1 + V((0, 0, 0.08)), 0.1, fire)
                body.append(ck.blade("%s_totemflag%d" % (cid, sx), p1 + V((0, 0.02, -0.05)), p1 + V((sx * 0.06, 0.1, -0.5)), 0.2, 0.02, red, (1, 0, 0), 0.35))
                for k in range(2):
                    body.append(cone("%s_totemrib%d_%d" % (cid, sx, k), p0.lerp(p1, 0.55 + 0.2 * k), p0.lerp(p1, 0.55 + 0.2 * k) + V((sx * 0.16, 0.02, 0.05)), 0.025, bone, 5))
                # ombreira de caveira
                body += skull("%s_shskull%d" % (cid, sx), V((sx * (sw + 0.07), -0.02, zc + 0.17)), 0.11, dark)
            # máscara de caveira de bicho na testa, com chifres
            head.append(ck.ball(cid + "_mask", r * 0.62, c + V((0, -r * 0.55, r * 0.52)), bone, (1.25, 0.8, 0.6)))
            for sx in (-1, 1):
                head.append(ck.ball("%s_maskeye%d" % (cid, sx), r * 0.13, c + V((sx * r * 0.3, -r * 0.98, r * 0.5)), dark))
                h0 = c + V((sx * r * 0.6, -r * 0.3, r * 0.75))
                h1 = h0 + V((sx * r * 0.55, -r * 0.1, r * 0.35))
                head.append(ck.tube("%s_maskhorn%da" % (cid, sx), h0, h1, r * 0.15, r * 0.12, bone, 6))
                head.append(cone("%s_maskhorn%db" % (cid, sx), h1, h1 + V((sx * r * 0.1, -r * 0.35, r * 0.6)), r * 0.12, bone, 6))
            body.append(ck.ball(cid + "_belly", 0.2, V((0, front - 0.02, zw + 0.03)), ck.mat("m_%s_bellyskin" % cid, (0.5, 0.64, 0.3), 0.7), (1.05, 0.8, 0.9)))
            for i in range(5):                  # colar de presas
                a = math.radians(-50 + i * 25)
                p = V((math.sin(a) * sw * 0.8, front - 0.03 - 0.03 * math.cos(a), zc + 0.1 - 0.05 * math.cos(a)))
                body.append(cone("%s_fang%d" % (cid, i), p, p + V((0, -0.02, -0.1)), 0.025, bone, 5))
        elif kind == "troll_king":
            stone = ck.mat("m_%s_stone" % cid, (0.52, 0.5, 0.48), 0.9)
            stone2 = ck.mat("m_%s_stone2" % cid, (0.4, 0.4, 0.42), 0.9)
            rune = ck.mat("m_%s_rune" % cid, (1.0, 0.6, 0.2), 0.3, 2.2)
            moss = ck.mat("m_%s_moss" % cid, (0.42, 0.52, 0.3), 0.9)
            # laje de pedra nas costas, rachada de runas acesas (a "montanha" que ele carrega)
            for i in range(3):
                z0 = zw + 0.02 + i * 0.1
                body.append(ck.blade("%s_slab%d" % (cid, i), V(((i - 1) * 0.2, back + 0.1, z0)), V(((i - 1) * 0.3, back + 0.3, zc + 0.5 + (0.22 if i == 1 else 0.0))), 0.3, 0.12, stone if i % 2 else stone2, (1, 0, 0), 0.5))
                body.append(ck.tube("%s_rune%d" % (cid, i), V(((i - 1) * 0.22, back + 0.24, zc - 0.02)), V(((i - 1) * 0.27, back + 0.33, zc + 0.3)), 0.022, 0.012, rune, 4))
            for sx in (-1, 1):                  # musgo nos ombros e punhos de pedra
                body.append(ck.ball("%s_moss%d" % (cid, sx), 0.15, V((sx * (sw + 0.02), 0.06, zc + 0.24)), moss, (1.3, 1.0, 0.5)))
            body.append(ck.ball(cid + "_runecore", 0.07, V((0, front - 0.03, zc + 0.03)), rune, (1, 0.5, 1)))
            for i in range(7):                  # colar de caveiras/pedras
                a = math.radians(-66 + i * 22)
                p = V((math.sin(a) * sw * 0.9, front - 0.02 - 0.05 * math.cos(a), zc + 0.13 - 0.07 * math.cos(a)))
                body.append(ck.ball("%s_bead%d" % (cid, i), 0.05 if i % 2 else 0.065, p, bone if i % 2 else stone2))
            for sx in (-1, 1):                  # chifres de carneiro de pedra
                h0 = c + V((sx * r * 0.82, r * 0.1, r * 0.35))
                pts = [h0]
                for k in range(1, 5):
                    a = k / 4 * math.pi * 0.95
                    pts.append(h0 + V((sx * r * (0.25 + 0.3 * math.sin(a)), r * (0.55 * math.sin(a) * 0.4 - 0.25 * (1 - math.cos(a))), r * (0.4 * math.sin(a) - 0.25 * (1 - math.cos(a))))))
                for k in range(4):
                    head.append(ck.tube("%s_ram%d_%d" % (cid, sx, k), pts[k], pts[k + 1], r * (0.24 - k * 0.045), r * (0.2 - k * 0.045), stone2 if k % 2 else stone, 6))
        elif kind == "crossbow_master":
            wood = ck.mat("m_%s_bosswood" % cid, (0.42, 0.3, 0.2), 0.8)
            lens = ck.mat("m_%s_lens" % cid, (1.0, 0.75, 0.3), 0.2, 2.0)
            # pavês de cerco nas costas: tábua alta com ferragem e o olho vermelho da Horda
            p0, p1 = V((0, back + 0.2, ck.Z["knee"] + 0.02)), V((0, back + 0.26, zc + 0.52))
            body.append(ck.blade(cid + "_pavise", p0, p1, 0.62, 0.05, wood, (1, 0, 0), 0.72))
            body.append(ck.blade(cid + "_pavise_rim", p0 + V((0, 0.03, 0.1)), p1 + V((0, 0.03, -0.1)), 0.2, 0.03, iron, (1, 0, 0), 0.6))
            body.append(ck.ball(cid + "_pavise_eye", 0.09, V((0, back + 0.29, zc + 0.12)), red, (1.2, 0.4, 0.8)))
            for sx in (-1, 1):
                body.append(cone("%s_pavise_spike%d" % (cid, sx), p1 + V((sx * 0.14, 0, -0.14)), p1 + V((sx * 0.2, 0.02, 0.12)), 0.04, iron, 5))
            # luneta de mira no olho direito e viseira de ferro
            e = c + V((-r * 0.38, -r * 0.92, -r * 0.1))
            head.append(ck.tube(cid + "_scope", e + V((0, r * 0.15, 0)), e + V((0, -r * 0.5, 0)), r * 0.2, r * 0.24, iron, 8))
            head.append(ck.ball(cid + "_scopelens", r * 0.2, e + V((0, -r * 0.5, 0)), lens, (1, 0.35, 1)))
            head.append(ck.tube(cid + "_scopestrap", c + V((0, 0, -r * 0.05)), c + V((0, 0, r * 0.07)), r * 1.03, r * 1.03, ck.mat("m_%s_bossstrap" % cid, (0.3, 0.2, 0.12), 0.85), 14))
            for i in range(6):                  # bandoleira de virotes no peito
                t = i / 5
                p = V((sw * (0.75 - 1.45 * t), front - 0.05, zc + 0.14 - 0.3 * t))
                body.append(ck.tube("%s_bandolier%d" % (cid, i), p + V((0, 0, -0.06)), p + V((0, 0, 0.07)), 0.018, 0.018, wood, 4))
                body.append(cone("%s_bandotip%d" % (cid, i), p + V((0, 0, 0.07)), p + V((0, 0, 0.12)), 0.026, iron, 4))
        elif kind == "ghar":
            fur = ck.mat("m_%s_fur" % cid, (0.34, 0.28, 0.24), 0.95)
            fur2 = ck.mat("m_%s_fur2" % cid, (0.5, 0.44, 0.38), 0.95)
            fire = ck.mat("m_%s_eyefire" % cid, (1.0, 0.4, 0.12), 0.3, 2.0)
            n = 9                              # manto de pele de lobo: gola de tufos de ombro a ombro pelas costas
            for i in range(n):
                a = math.radians(-100 + i * 200 / (n - 1))
                p = V((math.sin(a) * (sw + 0.1), 0.02 + math.cos(a) * (back + 0.07), zc + 0.2))
                body.append(ck.ball("%s_fur%d" % (cid, i), 0.12, p, fur if i % 2 else fur2, (1.0, 1.0, 0.8)))
                body.append(cone("%s_furtip%d" % (cid, i), p, p + V((math.sin(a) * 0.12, math.cos(a) * 0.12, -0.2)), 0.07, fur if i % 2 else fur2, 5))
            # cabeça do lobo no ombro esquerdo (troféu), olhos acesos
            wp = V((sw + 0.14, -0.04, zc + 0.3))
            body.append(ck.ball(cid + "_wolfhead", 0.13, wp, fur, (1.0, 1.15, 0.9)))
            body.append(cone(cid + "_wolfsnout", wp + V((0, -0.08, -0.02)), wp + V((0.02, -0.3, -0.06)), 0.08, fur2, 6))
            for sx in (-1, 1):
                body.append(cone("%s_wolfear%d" % (cid, sx), wp + V((sx * 0.07, 0.02, 0.08)), wp + V((sx * 0.1, 0.05, 0.22)), 0.04, fur, 4))
                body.append(ck.ball("%s_wolfeye%d" % (cid, sx), 0.022, wp + V((sx * 0.06, -0.12, 0.03)), fire))
            for i in range(3):                  # caveiras de troféu no cinto
                hips.extend(skull("%s_trophy%d" % (cid, i), V(((i - 1) * 0.17, front - 0.06 + 0.03 * abs(i - 1), zw - 0.06)), 0.07, dark))
            hips.append(ck.tube(cid + "_warbelt", V((0, 0, zw - 0.04)), V((0, 0, zw + 0.05)), sw * 1.1, sw * 1.1, iron, 12))
            for sx in (-1, 1):                  # presas de javali do elmo, mais largas que os chifres
                t0 = c + V((sx * r * 0.7, -r * 0.6, -r * 0.15))
                head.append(cone("%s_boartusk%d" % (cid, sx), t0, t0 + V((sx * r * 0.45, -r * 0.5, r * 0.55)), r * 0.13, bone, 6))
            head.append(ck.blade(cid + "_helmcrest", c + V((0, -r * 0.5, r * 1.0)), c + V((0, r * 1.0, r * 1.35)), r * 0.5, r * 0.09, red, (0, 0, 1), 0.55))
        _rigid(head, rig, "head")
        _rigid(body, rig, "chest")
        _rigid(hips, rig, "hips")
        _rigid(hand, rig, "hand.R")
    return add


# ---------------------------------------------------------------------------
# Forma de Lich (Necromante ascendido, nível 45)
# ---------------------------------------------------------------------------
def lich_parts(base, mats):
    """Capuz fundo com coroa de lascas de gelo flutuando, costelas à mostra com o filactério aceso no peito,
    caveiras nos ombros com chama espectral e manto em tiras. Cor: azul-gelo (tema "ice" da forma)."""
    rig, b = base["rig"], base["b"]
    c, r = V(base["head_c"]), b["head"]
    zc, zw = ck.Z["chest"], ck.Z["waist"]
    back, front = b["chest"] * b["depth"], -b["chest"] * b["depth"]
    sw = b["chest"]
    hood = ck.mat("m_lichf_hood", (0.1, 0.14, 0.24), 0.85)
    trim = ck.mat("m_lichf_trim", (0.35, 0.6, 0.8), 0.5)
    bone = ck.mat("m_lichf_bone", (0.9, 0.9, 0.84), 0.6)
    ice = ck.mat("m_lichf_ice", (0.7, 0.92, 1.0), 0.15, 0.9)
    glow = ck.mat("m_lichf_glow", (0.45, 0.9, 1.0), 0.3, 2.6)
    dark = ck.mat("m_lichf_dark", (0.05, 0.06, 0.1), 0.8)
    head, body, hips = [], [], []
    # capuz: casca recuada (o rosto de caveira fica à mostra) e ponta caída para trás
    head.append(ck.ball("lichf_hood", r * 1.17, c + V((0, r * 0.2, r * 0.12)), hood, (1.0, 1.05, 1.0)))
    head.append(ck.tube("lichf_hoodtip", c + V((0, r * 0.7, r * 0.85)), c + V((0, r * 1.5, r * 0.35)), r * 0.5, r * 0.06, hood, 8))
    for sx in (-1, 1):                          # órbitas escuras atrás dos olhos acesos e maçãs do rosto
        head.append(ck.ball("lichf_socket%d" % sx, r * 0.26, c + V((sx * 0.13, -r * 0.8, -0.04)), dark, (1.0, 0.5, 1.2)))
    for i in range(5):                          # dentes
        head.append(ck.ball("lichf_tooth%d" % i, r * 0.07, c + V(((i - 2) * r * 0.13, -r * (0.86 - 0.02 * abs(i - 2)), -r * 0.52)), bone, (0.8, 0.6, 1.3)))
    n = 8                                       # coroa de lascas de gelo flutuando acima do capuz
    for i in range(n):
        a = math.tau * i / n + 0.2
        root = c + V((math.cos(a) * r * 0.78, r * 0.2 + math.sin(a) * r * 0.78, r * (1.32 + 0.06 * (i % 2))))
        tall = r * (1.0 if i % 2 == 0 else 0.62)
        head.append(ck.blade("lichf_shard%d" % i, root + V((0, 0, -tall * 0.35)), root + V((math.cos(a) * r * 0.2, math.sin(a) * r * 0.2, tall)), r * 0.26, r * 0.08, ice, (-math.sin(a), math.cos(a), 0), 0.3))
    head.append(ck.tube("lichf_halo", c + V((0, r * 0.2, r * 1.3)), c + V((0, r * 0.2, r * 1.36)), r * 0.8, r * 0.8, glow, 18))
    # peito: costelas sobre o fundo escuro e o filactério
    body.append(ck.ball("lichf_chestvoid", 0.15, V((0, front + 0.02, zc + 0.0)), dark, (1.0, 0.55, 1.1)))
    body.append(ck.tube("lichf_sternum", V((0, front - 0.065, zc + 0.13)), V((0, front - 0.065, zc - 0.13)), 0.022, 0.018, bone, 5))
    for k in range(3):
        z = zc + 0.1 - k * 0.085
        for sx in (-1, 1):
            body.append(ck.tube("lichf_rib%d_%d" % (k, sx), V((sx * 0.015, front - 0.065, z)), V((sx * sw * (0.82 - 0.08 * k), front * 0.55, z - 0.035)), 0.022, 0.014, bone, 5))
    body.append(ck.ball("lichf_phylactery", 0.065, V((0, front - 0.035, zc - 0.01)), glow))
    for sx in (-1, 1):                          # ombreira de caveira com chama espectral
        sp = V((sx * (sw + 0.08), 0.0, zc + 0.18))
        body.append(ck.ball("lichf_shskull%d" % sx, 0.13, sp, bone, (1.05, 1.0, 0.92)))
        body.append(ck.ball("lichf_shjaw%d" % sx, 0.08, sp + V((sx * 0.04, -0.05, -0.1)), bone, (1.0, 0.9, 0.7)))
        for e in (-1, 1):
            body.append(ck.ball("lichf_sheye%d_%d" % (sx, e), 0.032, sp + V((sx * 0.05 + e * 0.045, -0.105, 0.01)), glow))
        for k in range(3):
            body.append(ck.blade("lichf_flame%d_%d" % (sx, k), sp + V(((k - 1) * 0.05, 0.03, 0.08)), sp + V((sx * 0.04 + (k - 1) * 0.1, 0.1, 0.42 - 0.1 * abs(k - 1))), 0.11, 0.03, glow if k == 1 else ice, (1, 0, 0), 0.35))
    for i in range(5):                          # manto em tiras rasgadas, comprimentos desiguais
        x = (i - 2) * 0.13
        ln = (0.06, 0.2, 0.02, 0.24, 0.1)[i]
        body.append(ck.blade("lichf_cape%d" % i, V((x * 0.7, back + 0.03, zc + 0.17)), V((x * 1.5, back + 0.22 + 0.03 * (i % 2), ck.Z["ankle"] + ln)), 0.2, 0.03, hood, (1, 0, 0), 0.6))
    for i in range(6):                          # gola de espinhos de gelo
        a = math.pi * (0.1 + 0.8 * i / 5)
        body.append(cone("lichf_collar%d" % i, V((math.cos(a) * 0.2, back * 0.4 + math.sin(a) * 0.08, zc + 0.2)), V((math.cos(a) * 0.34, back * 0.4 + math.sin(a) * 0.2, zc + 0.46)), 0.045, ice, 5))
    hips.append(ck.tube("lichf_sash", V((0, 0, zw - 0.03)), V((0, 0, zw + 0.04)), b["waist"] * 1.25, b["waist"] * 1.25, trim, 12))
    for i in range(3):                          # correntes com amuletos na cintura
        hips.append(ck.ball("lichf_charm%d" % i, 0.04, V(((i - 1) * 0.12, -b["waist"] * b["depth"] - 0.07, zw - 0.09 - 0.03 * (i == 1))), glow if i == 1 else bone))
    _rigid(head, rig, "head")
    _rigid(body, rig, "chest")
    _rigid(hips, rig, "hips")
