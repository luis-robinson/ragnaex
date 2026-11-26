"""Montarias dos prêmios MVP (GDD mvp-premios, contrato production/session-state/wave5-contract.md §B): primas menores,
mansas e seladas dos Chefes de Mundo, no molde do `mob_horse` (escala EntityView.HORSE_SCALE, sela na mesma altura e
largura, frente em -Y no Blender = +Z no jogo, osso `body` leva a sela, pelagem no material `tint`, 2ª tinta `tint2`).
Barda = nós de malha `barding_iron_<parte>` e `barding_<kind>_<parte>` (o jogo esconde todos e liga os do estilo escolhido).

Dois blocos independentes (cada um só usa os próprios nomes):
  parte A (prefixos _ma_/_wb_/_fe_/_rl_): mob_mount_war_boar, mob_mount_forest_elk, mob_mount_ruins_lizard + barda do cavalo
  parte B: mob_mount_armored_rhino, mob_mount_iron_wolf, mob_mount_porcelain_stag

    import mob_kit; mob_kit.build_all(out, only=["mob_mount_war_boar", ...])
"""
BUILDERS = {}


# ===========================================================================
# parte B: Rinoceronte Couraçado, Lobo de Ferro Couraçado, Gamo de Porcelana (prefixos _mb_ comuns, _ar_, _iw2_, _ps2_)
# ---------------------------------------------------------------------------
# Notas: production/session-state/agent-mounts-b.md. Os três têm o lombo/sela do cavalo (mob_kit.HIP) e saem com UMA malha
# por osso (`<pre>_<osso>`) + as bardas `barding_<estilo>_<parte>` (uma malha cada, no osso da parte). Tintas: `tint` =
# pelagem/couro/porcelana; `tint2` = manta e flâmula (rinoceronte), juba de geada (lobo), pintura de cobalto (gamo).
# MVP_MOUNT_BARDING (variável de ambiente, só para prévias): "all" (padrão) | "none" | "<estilo>" = quais bardas exportar.
# ===========================================================================
import math as _mb_math
import os as _mb_os
import bpy as _mb_bpy
import bmesh as _mb_bmesh
from mathutils import Vector as _mbV
import chibi_kit as _mb_ck
import lowpoly_lib as _mb_lp
import mob_kit as _mb_mk
import world_bosses as _mb_wb
import kharzun_mobs as _mb_kz

MB_SADDLE_H = 0.58             # mob_kit.HIP: a sela dos três fica onde a do cavalo fica
MB_IRON = (0.56, 0.57, 0.63)   # barda genérica: ferro claro
MB_RIVET = (0.86, 0.86, 0.9)


def _mb_barding():
    return _mb_os.environ.get("MVP_MOUNT_BARDING", "all")


def _mb_mat(name, color, rough=0.8, emission=0.0):
    """ck.mat devolve o material que já existir com o nome (tint/tint2 de outro bicho): a cor é sempre regravada."""
    m = _mb_ck.mat(name, color, rough, emission)
    bsdf = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    bsdf.inputs["Base Color"].default_value = (*color, 1.0)
    bsdf.inputs["Roughness"].default_value = rough
    if emission > 0:
        bsdf.inputs["Emission Color"].default_value = (*color, 1.0)
        bsdf.inputs["Emission Strength"].default_value = emission
    m.diffuse_color = (*color, 1.0)
    return m


def _mb_blob(name, r, center, material, scale=(1, 1, 1), cuts=2):
    """mk.blob com 54 quads por padrão (o de 96 só onde a peça é grande ou vira chapa)."""
    return _mb_mk.blob(name, r, center, material, scale, cuts)


def _mb_thin(obj, ratio):
    """Menos triângulos numa peça pronta (Decimate aplicado): as peças herdadas do lobo atroz vêm com Subsurf 2."""
    mod = obj.modifiers.new("thin", "DECIMATE")
    mod.ratio = ratio
    _mb_ck._bake(obj)
    return obj


def _mb_arc(c, rx, rz, a0, a1, n, dy=0.0):
    """Pontos de um arco de elipse no plano XZ em volta de c (ângulo 0 = topo, 90 = +X); dy = quanto o arco deita em Y."""
    c = _mbV(c)
    out = []
    for i in range(n + 1):
        a = _mb_math.radians(a0 + (a1 - a0) * i / n)
        out.append(c + _mbV((rx * _mb_math.sin(a), dy * _mb_math.sin(a) ** 2, rz * _mb_math.cos(a))))
    return out


def _mb_band(name, c, rx, rz, th, material, a0=-180.0, a1=180.0, n=12, segs=5, dy=0.0):
    return _mb_wb._strap(name, _mb_arc(c, rx, rz, a0, a1, n, dy), th, th, material, segs)


def _mb_rivets(name, shell, step, r, material, lift=0.004, limit=6):
    """Rebites na 2ª fileira de vértices de uma casca (_shell): a borda entra no corpo, a fileira seguinte fica à vista."""
    b = _mb_bmesh.new()
    b.from_mesh(shell.data)
    b.normal_update()
    edge = {v for v in b.verts if v.is_boundary}
    ring = set()
    for f in b.faces:
        if any(v in edge for v in f.verts):
            ring.update(v for v in f.verts if v not in edge)
    picked = []
    for v in sorted(ring, key=lambda q: (round(q.co.y, 3), round(q.co.x, 3), round(q.co.z, 3))):
        if all((v.co - q).length >= step for q, _n in picked):
            picked.append((v.co.copy(), v.normal.copy()))
        if len(picked) >= limit:
            break
    b.free()
    return [_mb_wb._stud("%s_%d" % (name, i), p + n * lift, r, material, sub=1) for i, (p, n) in enumerate(picked)]


def _mb_plate(name, srcs, pick, off, material, rivet=None, step=0.1, r=0.016):
    """Chapas rentes: casca de cada malha de `srcs` onde pick(centro, normal) aceita (+ rebites na 2ª fileira)."""
    out = []
    for i, src in enumerate(srcs):
        sh = _mb_wb._shell("%s_%d" % (name, i), src, pick, off, material)
        if len(sh.data.polygons) == 0:
            _mb_bpy.data.objects.remove(sh, do_unlink=True)
            continue
        if rivet is not None:
            out += _mb_rivets("%s_rv%d" % (name, i), sh, step, r, rivet)
        out.append(sh)
    return out


def _mb_saddle(pre, parts, blanket, leather, trim, hs=MB_SADDLE_H):
    """A sela do cavalo (mesmas medidas: EntityView.SADDLE_Y e a pose de RideLegs contam com ela)."""
    blob, ck = _mb_mk.blob, _mb_ck
    parts.append((blob(pre + "_blanket", 0.2, (0, -0.02, hs + 0.19), blanket, (0.92, 1.15, 0.45)), "body"))
    parts.append((blob(pre + "_saddle", 0.15, (0, -0.02, hs + 0.27), leather, (0.85, 1.05, 0.4)), "body"))
    parts.append((blob(pre + "_cantle", 0.1, (0, 0.11, hs + 0.32), leather, (1.1, 0.35, 0.55)), "body"))
    parts.append((ck.ball(pre + "_pommel", 0.03, (0, -0.15, hs + 0.34), trim), "body"))
    for sx in (-1, 1):
        parts.append((ck.tube("%s_strap%d" % (pre, sx), (sx * 0.16, -0.04, hs + 0.24), (sx * 0.19, -0.04, hs + 0.0), 0.012, 0.012, leather, 5), "body"))
        parts.append((ck.tube("%s_stirrup%d" % (pre, sx), (sx * 0.19, -0.07, hs - 0.01), (sx * 0.19, -0.01, hs - 0.01), 0.022, 0.022, trim, 6), "body"))
        for sy in (-1, 1):          # borlas nos cantos da manta
            parts.append((ck.tube("%s_tassel%d_%d" % (pre, sx, sy), (sx * 0.175, -0.02 + sy * 0.17, hs + 0.14), (sx * 0.185, -0.02 + sy * 0.18, hs + 0.05), 0.012, 0.024, trim, 5), "body"))


def _mb_finish(arm, pre, parts, bard):
    """Uma malha por osso (`<pre>_<osso>`) + uma por peça de barda (`barding_<estilo>_<parte>`), presas aos ossos."""
    want = _mb_barding()
    arm.data.pose_position = "REST"         # o lobo chega aqui já com clipes: prender com o osso posado deslocava a malha
    _mb_bpy.context.view_layer.update()
    groups = {}
    for o, bone in parts:
        groups.setdefault(bone, []).append(o)
    out = [(_mb_ck._join(objs, "%s_%s" % (pre, bone)), bone) for bone, objs in groups.items()]
    for name, (objs, bone) in bard.items():
        style = name.rsplit("_", 1)[0]
        if want == "none" or (want != "all" and style != want):
            for o in objs:
                _mb_bpy.data.objects.remove(o, do_unlink=True)
            continue
        out.append((_mb_ck._join(objs, name), bone))
    _mb_mk.finish(arm, out)
    arm.data.pose_position = "POSE"
    _mb_bpy.context.view_layer.update()


def _mb_use(arm, track):
    ad = arm.animation_data
    act = track.strips[0].action
    ad.action = act
    slot = getattr(track.strips[0], "action_slot", None)
    if hasattr(ad, "action_slot"):
        if slot is not None:
            ad.action_slot = slot
        elif ad.action_slot is None and getattr(act, "slots", None):
            ad.action_slot = act.slots[0]
    return act


def _mb_fcurves(arm, act):
    if hasattr(act, "fcurves"):
        return list(act.fcurves)
    out = []
    slot = arm.animation_data.action_slot
    for layer in act.layers:
        for strip in layer.strips:
            bag = strip.channelbag(slot) if slot is not None else None
            if bag is not None:
                out += list(bag.fcurves)
    return out


def _mb_key_all(arm):
    """Todo osso gravado em todo clipe (osso sem chave herda a pose do clipe anterior no jogo)."""
    ad = arm.animation_data
    for t in ad.nla_tracks:
        t.mute = True
    for t in ad.nla_tracks:
        act = _mb_use(arm, t)
        have = {fc.data_path.split('"')[1] for fc in _mb_fcurves(arm, act) if fc.data_path.startswith("pose.bones")}
        end = int(round(act.frame_range[1]))
        for pb in arm.pose.bones:
            if pb.name in have:
                continue
            pb.rotation_mode = "XYZ"
            pb.rotation_euler = (0, 0, 0)
            pb.location = (0, 0, 0)
            for f in (1, end):
                pb.keyframe_insert("rotation_euler", frame=f)
                pb.keyframe_insert("location", frame=f)
        ad.action = None
    for t in ad.nla_tracks:
        t.mute = False


def _mb_ground(arm, tag, margin=0.0):
    """Nada abaixo do chão: quadro a quadro, o que passar de z = 0 sobe a raiz (loc Y = cima). Imprime o pior de cada clipe."""
    import numpy as np
    ad = arm.animation_data
    sc = _mb_bpy.context.scene
    meshes = [o for o in arm.children if o.type == "MESH"]
    co = []
    for o in meshes:
        a = np.empty(len(o.data.vertices) * 3, dtype=np.float64)
        o.data.vertices.foreach_get("co", a)
        co.append(np.concatenate([a.reshape(-1, 3), np.ones((len(o.data.vertices), 1))], axis=1))
    for t in ad.nla_tracks:
        t.mute = True
    root = arm.pose.bones["root"]
    for t in ad.nla_tracks:
        act = _mb_use(arm, t)
        worst = 0.0
        for f in range(1, int(round(act.frame_range[1])) + 1):
            sc.frame_set(f)
            _mb_bpy.context.view_layer.update()
            low = min(float((c @ np.array(o.matrix_world)[2]).min()) for o, c in zip(meshes, co))
            d = max(0.0, margin - low)
            root.location.y += d
            worst = max(worst, d)
            root.keyframe_insert("location", frame=f)
        print("MB_GROUND %s %-5s raiz sobe até %.3f" % (tag, t.name, worst))
        ad.action = None
    for t in ad.nla_tracks:
        t.mute = False
    for pb in arm.pose.bones:
        pb.rotation_euler = (0, 0, 0)
        pb.location = (0, 0, 0)
        pb.scale = (1, 1, 1)
    sc.frame_set(1)


# ---------------------------------------------------------------------------
# Rinoceronte Couraçado (primo manso do Rinoceronte de Guerra): rig MOB_BONES + rabo, passo pesado (quad_motion "boar")
# ---------------------------------------------------------------------------
AR_H = 0.56
AR_HIDE = (0.63, 0.54, 0.47)
AR_HIDE_D = (0.4, 0.33, 0.3)
AR_HORN = (0.95, 0.9, 0.76)
AR_RED = (0.74, 0.2, 0.16)
AR_IRON = (0.33, 0.33, 0.38)
AR_LEATHER = (0.34, 0.23, 0.16)


def _ar_mount(cid="mob_mount_armored_rhino"):
    """Rinoceronte Couraçado: tronco fundo e baixo com a corcova à frente da sela, cabeça baixa de chifre grande, patas de
    coluna. Barda temática: chapas rebitadas da Horda (ferro escuro, tinta vermelha, cravos) + haste com flâmula na garupa."""
    mk, ck, wb, V = _mb_mk, _mb_ck, _mb_wb, _mbV
    blob, cone = _mb_blob, mk.cone
    h = AR_H
    bones = mk.pivots(head=(0, -0.6, h + 0.1), leg_fr=(0.18, -0.49, h - 0.06), leg_fl=(-0.18, -0.49, h - 0.06),
                      leg_br=(0.19, 0.4, h - 0.06), leg_bl=(-0.19, 0.4, h - 0.06))
    bones["tail"] = ((0, 0.6, h + 0.12), (0, 0.74, h - 0.1), "body")
    arm = _mb_lp.make_armature("rig_" + cid, bones)
    hide = _mb_mat("tint", AR_HIDE, 0.85)
    cloth = _mb_mat("tint2", AR_RED, 0.85)
    dark = _mb_mat("m_ar_hide_d", AR_HIDE_D, 0.85)
    horn = _mb_mat("m_ar_horn", AR_HORN, 0.5)
    leather = _mb_mat("m_ar_leather", AR_LEATHER, 0.75)
    iron = _mb_mat("m_ar_iron", AR_IRON, 0.45)
    red = _mb_mat("m_ar_red", AR_RED, 0.8)
    b_iron = _mb_mat("m_bard_iron", MB_IRON, 0.4)
    b_rivet = _mb_mat("m_bard_rivet", MB_RIVET, 0.35)
    m_eye, m_white = mk.base_mats()
    parts, bard = [], {}
    # tronco: garupa larga, barriga funda, corcova do ombro à frente da sela
    pts = [((0, 0.5, h + 0.03), (0.2, 0.21)), ((0, 0.12, h + 0.03), (0.215, 0.245)), ((0, -0.34, h + 0.07), (0.23, 0.27)), ((0, -0.62, h + 0.06), (0.2, 0.22))]
    trunk = mk.skin_body("ar_trunk", pts, [(0, 1), (1, 2), (2, 3)], hide, sub=1)
    hump = blob("ar_hump", 0.2, (0, -0.44, h + 0.17), hide, (0.95, 1.0, 0.8), 3)
    rump = blob("ar_rump", 0.21, (0, 0.44, h + 0.06), hide, (1.0, 0.9, 1.05), 3)
    neck = blob("ar_neck", 0.2, (0, -0.66, h + 0.08), hide, (1.0, 1.0, 1.05))
    parts += [(trunk, "body"), (hump, "body"), (rump, "body"), (neck, "body"),
              (blob("ar_belly", 0.2, (0, -0.02, h - 0.13), hide, (0.9, 2.0, 0.6)), "body")]
    sh, ha = {}, {}
    for sx in (-1, 1):
        sh[sx] = blob("ar_shoulder%d" % sx, 0.16, (sx * 0.185, -0.49, h - 0.02), hide, (0.8, 1.1, 1.45))
        ha[sx] = blob("ar_haunch%d" % sx, 0.18, (sx * 0.19, 0.4, h - 0.03), hide, (0.8, 1.2, 1.4))
        parts += [(sh[sx], "body"), (ha[sx], "body")]
    # dobras do couro (leem como as placas naturais do rinoceronte)
    for i, (y, rx, rz, zc) in enumerate(((-0.52, 0.225, 0.25, h + 0.07), (0.3, 0.215, 0.235, h + 0.04))):
        parts += [(o, "body") for o in _mb_band("ar_fold%d" % i, (0, y, zc), rx, rz, 0.022, dark, -115, 115, 10)]
    # cabeça baixa: crânio largo, focinho quadrado, chifre grande + chifre pequeno
    hc = V((0, -0.84, h + 0.1))
    skull = blob("ar_skull", 0.2, hc, hide, (0.95, 1.15, 0.95), 3)
    snout = blob("ar_snout", 0.16, hc + V((0, -0.27, -0.07)), hide, (0.9, 1.3, 0.85))
    parts += [(skull, "head"), (snout, "head"),
              (blob("ar_lip", 0.12, hc + V((0, -0.29, -0.16)), dark, (0.9, 1.25, 0.5)), "head"),
              (wb._horn("ar_horn", [hc + V((0, -0.4, -0.02)), hc + V((0, -0.47, 0.13)), hc + V((0, -0.47, 0.28)), hc + V((0, -0.42, 0.4))],
                        [0.08, 0.062, 0.04, 0.008], horn), "head"),
              (cone("ar_horn2", hc + V((0, -0.2, 0.08)), hc + V((0, -0.21, 0.25)), 0.055, horn, 7), "head"),
              (blob("ar_brow", 0.1, hc + V((0, -0.1, 0.13)), hide, (1.6, 0.8, 0.45)), "head")]
    for sx in (-1, 1):
        parts.append((cone("ar_ear%d" % sx, hc + V((sx * 0.13, 0.1, 0.12)), hc + V((sx * 0.23, 0.15, 0.3)), 0.06, hide, 6), "head"))
        parts.append((cone("ar_earin%d" % sx, hc + V((sx * 0.14, 0.085, 0.14)), hc + V((sx * 0.22, 0.125, 0.27)), 0.035, dark, 5), "head"))
        parts.append((wb._stud("ar_nostril%d" % sx, hc + V((sx * 0.06, -0.47, -0.06)), 0.02, dark), "head"))
    parts += [(o, "head") for o in mk.eyes("ar", [hc + V((sx * 0.16, -0.12, 0.05)) for sx in (-1, 1)], 0.036, m_eye, m_white)]
    # patas de coluna, três unhas
    for bone, sx, sy in (("leg_fr", 1, -1), ("leg_fl", -1, -1), ("leg_br", 1, 1), ("leg_bl", -1, 1)):
        top = V((sx * 0.19, 0.4, h - 0.04)) if sy > 0 else V((sx * 0.18, -0.49, h - 0.04))
        foot = V((sx * 0.2, 0.4, 0.09)) if sy > 0 else V((sx * 0.185, -0.49, 0.09))
        parts.append((ck.tube("ar_leg_" + bone[4:], top, foot, 0.125, 0.112, hide, 8), bone))
        parts.append((blob("ar_foot_" + bone[4:], 0.13, foot + V((0, -0.02, -0.01)), hide, (1.0, 1.12, 0.6)), bone))
        parts.append((blob("ar_knee_" + bone[4:], 0.075, top.lerp(foot, 0.5) + V((0, -0.09, 0)), dark, (1.2, 0.6, 0.7), 2), bone))
        for k in (-1, 0, 1):
            parts.append((wb._stud("ar_toe_%s%d" % (bone[4:], k), foot + V((k * 0.07, -0.15 + abs(k) * 0.03, -0.045)), 0.034, horn, (1.0, 1.0, 1.0)), bone))
    # rabo fino com tufo
    parts.append((ck.tube("ar_tail", (0, 0.6, h + 0.14), (0, 0.72, h - 0.1), 0.035, 0.022, hide, 6), "tail"))
    parts.append((blob("ar_tailtuft", 0.05, (0, 0.73, h - 0.14), dark, (0.8, 0.8, 1.4), 2), "tail"))
    # arreio: sela do cavalo com manta `tint2`, barrigueira, cabeçada e rédeas
    _mb_saddle("ar", parts, cloth, leather, horn)
    parts += [(o, "body") for o in _mb_band("ar_girth", (0, -0.04, h + 0.03), 0.225, 0.255, 0.016, leather, 60, 300, 12)]
    parts += [(o, "head") for o in _mb_band("ar_noseband", hc + V((0, -0.3, -0.08)), 0.15, 0.15, 0.014, leather, -180, 180, 10)]
    for sx in (-1, 1):
        parts.append((ck.tube("ar_cheek%d" % sx, hc + V((sx * 0.15, -0.3, -0.06)), hc + V((sx * 0.185, 0.02, 0.08)), 0.012, 0.012, leather, 4), "head"))
        parts.append((wb._stud("ar_bit%d" % sx, hc + V((sx * 0.155, -0.3, -0.07)), 0.026, horn), "head"))
        parts += [(o, "body") for o in wb._strap("ar_rein%d" % sx, [(sx * 0.19, -0.72, h + 0.2), (sx * 0.12, -0.44, h + 0.32), (sx * 0.035, -0.15, MB_SADDLE_H + 0.335)], 0.009, 0.009, leather, 4)]
    # ---- barda genérica de ferro: testeira, peitoral, garupeira
    bard["barding_iron_head"] = (
        _mb_plate("ar_bi_chanf", [skull], lambda c, n: n.z > 0.3 and abs(c.x) < 0.13 and c.y < hc.y + 0.12, 0.03, b_iron, b_rivet, 0.09) +
        _mb_plate("ar_bi_nose", [snout], lambda c, n: n.z > 0.45 and abs(c.x) < 0.1 and c.y > hc.y - 0.38, 0.028, b_iron, b_rivet, 0.09) +
        [ck.tube("ar_bi_ridge", hc + V((0, -0.26, 0.085)), hc + V((0, 0.06, 0.2)), 0.02, 0.02, b_rivet, 5)], "head")
    bard["barding_iron_chest"] = (
        _mb_plate("ar_bi_peyt", [sh[-1], sh[1]], lambda c, n: n.y < -0.2 and c.z > h - 0.2, 0.026, b_iron, b_rivet, 0.1) +
        _mb_plate("ar_bi_peytn", [neck], lambda c, n: n.z < 0.35 and c.z < h + 0.12 and n.y < 0.2, 0.028, b_iron, b_rivet, 0.11) +
        _mb_band("ar_bi_peytrim", (0, -0.6, h + 0.06), 0.225, 0.25, 0.018, b_rivet, 95, 265, 8), "body")
    bard["barding_iron_rump"] = (
        _mb_plate("ar_bi_crup", [rump], lambda c, n: (n.z > 0.15 or n.y > 0.5) and c.z > h - 0.02, 0.03, b_iron, b_rivet, 0.11) +
        _mb_plate("ar_bi_cruph", [ha[-1], ha[1]], lambda c, n: abs(n.x) > 0.35 and c.z > h - 0.06, 0.03, b_iron, b_rivet, 0.11) +
        _mb_band("ar_bi_cruprim", (0, 0.27, h + 0.04), 0.225, 0.245, 0.018, b_rivet, -100, 100, 8), "body")
    # ---- barda da Horda: chapas escuras rebitadas com faixa vermelha, cravos, haste com flâmula
    kind = "barding_armored_rhino"
    hd = _mb_plate("ar_bh_face", [skull], lambda c, n: n.z > 0.05 and c.y < hc.y + 0.14 and n.y < 0.6, 0.032, iron, b_rivet, 0.085)
    hd += _mb_plate("ar_bh_nose", [snout], lambda c, n: n.z > 0.3 and c.y > hc.y - 0.36, 0.03, iron, b_rivet, 0.09)
    hd += _mb_band("ar_bh_hornring", hc + V((0, -0.43, 0.035)), 0.085, 0.085, 0.02, iron, -180, 180, 8)
    hd.append(ck.tube("ar_bh_stripe", hc + V((0, -0.3, 0.075)), hc + V((0, 0.08, 0.215)), 0.034, 0.03, red, 5))
    for sx in (-1, 1):
        hd.append(cone("ar_bh_cheekspike%d" % sx, hc + V((sx * 0.17, -0.02, 0.1)), hc + V((sx * 0.27, -0.06, 0.2)), 0.04, b_rivet, 5))
    bard[kind + "_head"] = (hd, "head")
    bd = _mb_plate("ar_bh_hump", [hump], lambda c, n: n.z > 0.25, 0.03, iron, b_rivet, 0.1)
    bd += _mb_plate("ar_bh_sh", [sh[-1], sh[1]], lambda c, n: abs(n.x) > 0.2 and c.z > h - 0.12, 0.026, iron, b_rivet, 0.095)
    bd += _mb_plate("ar_bh_rump", [rump], lambda c, n: n.z > 0.3 and c.z > h + 0.02, 0.03, iron, b_rivet, 0.1)
    bd += _mb_plate("ar_bh_ha", [ha[-1], ha[1]], lambda c, n: abs(n.x) > 0.3 and c.z > h - 0.1, 0.034, iron, b_rivet, 0.095)
    bd += _mb_band("ar_bh_stripe_f", (0, -0.46, h + 0.17), 0.2, 0.2, 0.026, red, -62, 62, 8)
    bd += _mb_band("ar_bh_stripe_b", (0, 0.44, h + 0.06), 0.225, 0.26, 0.026, red, -58, 58, 8)
    for sx in (-1, 1):
        bd.append(cone("ar_bh_shspike%d" % sx, (sx * 0.1, -0.5, h + 0.3), (sx * 0.15, -0.56, h + 0.43), 0.04, b_rivet, 5))     # cravos no alto da corcova: por fora do ombro passa o escudo alto
        bd.append(cone("ar_bh_haspike%d" % sx, (sx * 0.31, 0.42, h + 0.1), (sx * 0.39, 0.46, h + 0.19), 0.04, b_rivet, 5))
    p0, p1 = V((0, 0.5, h + 0.2)), V((0, 0.56, h + 0.86))
    bd.append(ck.tube("ar_bh_pole", p0, p1, 0.02, 0.016, leather, 6))
    bd.append(cone("ar_bh_poletip", p1, p1 + V((0, 0.01, 0.1)), 0.03, b_rivet, 5))
    bd.append(ck.tube("ar_bh_bar", p1 + V((-0.13, 0, -0.03)), p1 + V((0.13, 0, -0.03)), 0.013, 0.013, leather, 5))
    bd.append(blob("ar_bh_polefoot", 0.05, p0, iron, (1.0, 1.0, 0.6), 2))
    bd.append(wb._cloth("ar_bh_banner", p1 + V((-0.11, 0.012, -0.04)), (1, 0, 0), (0, 0.12, -1), 0.22, 0.32, cloth, hem=red, seed=5, nx=4, ny=3, thick=0.014))
    bd.append(wb._stud("ar_bh_bannermark", p1 + V((0, 0.0, -0.16)), 0.04, horn, (1.0, 0.5, 1.3), 2))
    bard[kind + "_body"] = (bd, "body")
    _mb_finish(arm, "ar", parts, bard)
    _mb_mk.bm.mob_actions(arm, quadruped=True)
    mk.quad_motion(arm, "boar")
    mk._drop_clips(arm, ("attack", "hit", "die"))
    _mb_key_all(arm)
    _mb_ground(arm, cid)
    return arm


# ---------------------------------------------------------------------------
# Lobo de Ferro Couraçado (primo manso do Lobo-Rei de Ferro): a anatomia é a do mob_dire_wolf_mount (kharzun_mobs.dire_wolf)
# ---------------------------------------------------------------------------
IW2_FUR = (0.3, 0.36, 0.54)
IW2_DARK = (0.14, 0.16, 0.27)
IW2_LIGHT = (0.62, 0.69, 0.84)
IW2_MANE = (0.94, 0.97, 1.0)
IW2_IRON = (0.36, 0.37, 0.45)
IW2_BRASS = (0.82, 0.68, 0.4)
IW2_BLANKET = (0.5, 0.2, 0.15)
IW2_EMBER = (1.0, 0.42, 0.1)
IW2_GLOW = 0.5              # runas em brasa: fracas (degraus de 0,25: EntityView.mob_glow)


def _iw2_mount(cid="mob_mount_iron_wolf"):
    """Lobo de Ferro Couraçado: o lobo atroz de montaria com pelo cinza-azulado, juba de geada (`tint2`), coleira anã de
    ferro e latão com um elo de corrente. Barda temática: elmo-máscara anão com runa + ombreiras rúnicas (brasa fraca)."""
    mk, ck, wb, kz, V = _mb_mk, _mb_ck, _mb_wb, _mb_kz, _mbV
    blob, cone = _mb_blob, mk.cone
    arm = kz.dire_wolf(cid, mount=True)
    h, fy = kz.DW_HIP, -kz.DW_MOUNT_FWD
    _mb_mat("tint", IW2_FUR, 0.85)
    mane = _mb_mat("tint2", IW2_MANE, 0.85)
    _mb_mat("m_%s_dark" % cid, IW2_DARK, 0.85)
    _mb_mat("m_%s_light" % cid, IW2_LIGHT, 0.85)
    _mb_mat("m_%s_blanket" % cid, IW2_BLANKET, 0.85)
    iron = _mb_mat("m_iw2_iron", IW2_IRON, 0.45)
    brass = _mb_mat("m_iw2_brass", IW2_BRASS, 0.4)
    rune = _mb_mat("glow_iw2_rune", IW2_EMBER, 0.4, IW2_GLOW)
    b_iron = _mb_mat("m_bard_iron", MB_IRON, 0.4)
    b_rivet = _mb_mat("m_bard_rivet", MB_RIVET, 0.35)
    S = {o.name: o for o in arm.children if o.type == "MESH"}
    for name, o in S.items():               # o lobo atroz tem ~6,5 mil triângulos: aqui sobra para a barda
        tris = sum(len(q.vertices) - 2 for q in o.data.polygons)
        if name in ("dw_trunk", "fur_tail"):
            _mb_thin(o, 0.5 if name == "dw_trunk" else 0.3)
        elif tris >= 150 and not name.startswith(("dw_eye", "dw_hl")):
            _mb_thin(o, 0.6)
    for name, o in S.items():
        if name == "dw_mane" or name.startswith("dw_hackle"):
            o.data.materials[0] = mane
        elif name.startswith("dw_pommel"):
            o.data.materials[0] = brass
    parts = [(o, o.parent_bone) for o in S.values()]
    bard = {}
    hc = V((0, -0.82 + fy, h + 0.36))
    skull, snout, trunk = S["dw_skull"], S["dw_snout"], S["dw_trunk"]
    sh = {sx: S["dw_shoulder%d" % sx] for sx in (-1, 1)}
    ha = {sx: S["dw_haunch%d" % sx] for sx in (-1, 1)}
    # juba de geada: tufos no peito e atrás das bochechas (baixos: não tapam quem monta)
    for sx in (-1, 1):
        for k, (y, z, ln) in enumerate(((-0.6, 0.12, 0.2), (-0.52, 0.02, 0.18), (-0.66, -0.02, 0.17))):
            a = V((sx * 0.16, y + fy + 0.12, h + z))
            parts.append((wb._tuft("iw2_ruff%d_%d" % (sx, k), a, a + V((sx * ln * 0.75, 0.06, -ln * 0.6)), 0.085, mane), "body"))
    parts.append((blob("iw2_bib", 0.15, (0, -0.56 + fy, h - 0.02), mane, (1.0, 0.8, 1.2)), "body"))
    parts.append((blob("iw2_tailtip", 0.075, (0, 1.0 + fy, h + 0.02), mane, (0.95, 1.3, 0.95)), "tail"))
    # coleira anã: aro de ferro com rebites de latão e um elo de corrente partida
    cc = V((0, -0.5 + fy, h + 0.2))
    parts += [(o, "body") for o in _mb_band("iw2_collar", cc, 0.245, 0.26, 0.03, iron, -180, 180, 14, 6)]
    for k, d in enumerate((-130, -80, -35, 35, 80, 130)):
        a = _mb_math.radians(d)
        parts.append((wb._stud("iw2_collarstud%d" % k, cc + V((0.27 * _mb_math.sin(a), -0.012, 0.285 * _mb_math.cos(a))), 0.028, brass), "body"))
    parts += [(o, "body") for o in wb._ring("iw2_link", cc + V((0, -0.05, -0.31)), (1, 0, 0), 0.04, 0.012, brass, 6, 4)]
    # cabeçada e rédeas
    parts += [(o, "head") for o in _mb_band("iw2_noseband", hc + V((0, -0.2, -0.07)), 0.108, 0.125, 0.012, iron, -180, 180, 10)]
    for sx in (-1, 1):
        parts.append((ck.tube("iw2_cheekstrap%d" % sx, hc + V((sx * 0.108, -0.2, -0.05)), hc + V((sx * 0.215, 0.03, 0.06)), 0.011, 0.011, iron, 4), "head"))
        parts.append((wb._stud("iw2_bit%d" % sx, hc + V((sx * 0.112, -0.2, -0.07)), 0.022, brass), "head"))
        parts += [(o, "body") for o in wb._strap("iw2_rein%d" % sx, [cc + V((sx * 0.2, 0.0, 0.1)), (sx * 0.11, -0.36, h + 0.33), (sx * 0.035, -0.17, h + 0.36)], 0.009, 0.009, iron, 4)]
    # manta com cantos de latão
    for sx in (-1, 1):
        for sy in (-1, 1):
            parts.append((wb._stud("iw2_blanketstud%d_%d" % (sx, sy), (sx * 0.185, sy * 0.17, h + 0.16), 0.022, brass), "body"))
    # ---- barda genérica de ferro
    bard["barding_iron_head"] = (
        _mb_plate("iw2_bi_chanf", [skull], lambda c, n: n.z > 0.35 and abs(c.x) < 0.12 and c.y < hc.y + 0.1, 0.03, b_iron, b_rivet, 0.09) +
        _mb_plate("iw2_bi_nose", [snout], lambda c, n: n.z > 0.5 and abs(c.x) < 0.08 and c.y > hc.y - 0.36, 0.026, b_iron, b_rivet, 0.09) +
        [ck.tube("iw2_bi_ridge", hc + V((0, -0.3, 0.055)), hc + V((0, 0.02, 0.24)), 0.018, 0.018, b_rivet, 5)], "head")
    bard["barding_iron_chest"] = (
        _mb_plate("iw2_bi_peyt", [sh[-1], sh[1]], lambda c, n: n.y < -0.15 and c.z > h - 0.2, 0.03, b_iron, b_rivet, 0.1) +
        [blob("iw2_bi_peytc", 0.15, (0, -0.56 + fy, h - 0.03), b_iron, (1.25, 0.72, 1.15), 2)] +
        [wb._stud("iw2_bi_peytstud%d" % k, (x, -0.67 + fy, h - 0.03 + z), 0.02, b_rivet) for k, (x, z) in enumerate(((-0.1, 0.08), (0.1, 0.08), (0, -0.08), (0, 0.02)))], "body")
    bard["barding_iron_rump"] = (
        _mb_plate("iw2_bi_crup", [trunk], lambda c, n: c.y > 0.2 + fy and n.z > 0.1 and c.y < 0.5 + fy, 0.028, b_iron, b_rivet, 0.11) +
        _mb_plate("iw2_bi_cruph", [ha[-1], ha[1]], lambda c, n: abs(n.x) > 0.3 and c.z > h - 0.08, 0.03, b_iron, b_rivet, 0.1), "body")
    # ---- barda anã: elmo-máscara rúnico + ombreiras (runas em brasa fraca)
    kind = "barding_iron_wolf"
    mask = _mb_wb._shell("iw2_bw_mask", skull, lambda c, n: (n.z > -0.05 or n.y < -0.5) and c.y < hc.y + 0.13 and c.z > hc.z - 0.1, 0.034, iron)
    hd = [mask] + _mb_rivets("iw2_bw_maskrv", mask, 0.085, 0.017, brass)
    hd += _mb_plate("iw2_bw_nasal", [snout], lambda c, n: n.z > 0.35 and c.y > hc.y - 0.37, 0.028, iron, brass, 0.085, 0.015)
    hd += _mb_band("iw2_bw_brow", hc + V((0, -0.17, 0.02)), 0.2, 0.17, 0.024, brass, -70, 70, 8)
    hd.append(ck.tube("iw2_bw_crest", hc + V((0, -0.2, 0.2)), hc + V((0, 0.14, 0.24)), 0.03, 0.022, brass, 5))
    hd += wb._iw_rune("iw2_bw_rune", hc + V((0, -0.06, 0.3)), (0, -0.45, 1), (0, -1, 0.3), 0.15, "tyr", 0.014, rune, wb._caster(mask), 0.012)
    for sx in (-1, 1):
        hd.append(blob("iw2_bw_cheek%d" % sx, 0.11, hc + V((sx * 0.2, -0.08, -0.06)), iron, (0.4, 1.1, 0.9), 2))
        hd.append(wb._stud("iw2_bw_cheekstud%d" % sx, hc + V((sx * 0.245, -0.08, -0.06)), 0.022, brass))
    bard[kind + "_head"] = (hd, "head")
    bd = []
    for sx in (-1, 1):
        pl = _mb_wb._shell("iw2_bw_pauld%d" % sx, sh[sx], lambda c, n, sx=sx: n.x * sx > 0.15 and c.z > h - 0.08, 0.028, iron)
        bd += [pl] + _mb_rivets("iw2_bw_pauldrv%d" % sx, pl, 0.09, 0.017, brass)
        top = V((sx * 0.21, -0.4 + fy, h + 0.2))
        bd.append(blob("iw2_bw_pauldcap%d" % sx, 0.11, top, iron, (0.75, 1.1, 0.5), 2))
        bd.append(ck.tube("iw2_bw_pauldridge%d" % sx, top + V((0, -0.11, 0.03)), top + V((0, 0.1, 0.03)), 0.02, 0.02, brass, 5))
        bd += wb._iw_rune("iw2_bw_prune%d" % sx, (sx * 0.33, -0.37 + fy, h - 0.0), (sx, 0, 0.15), (0, 0, 1), 0.15, "odal" if sx > 0 else "thorn", 0.013, rune, wb._caster(pl), 0.012)
    bd.append(blob("iw2_bw_medal", 0.06, cc + V((0, -0.1, -0.33)), iron, (1.0, 0.4, 1.0), 2))
    bd += wb._iw_rune("iw2_bw_mrune", cc + V((0, -0.126, -0.33)), (0, -1, 0), (0, 0, 1), 0.07, "fe", 0.009, rune)
    bard[kind + "_body"] = (bd, "body")
    _mb_finish(arm, "iw2", parts, bard)
    _mb_key_all(arm)
    _mb_ground(arm, cid)
    return arm


# ---------------------------------------------------------------------------
# Gamo de Porcelana (primo manso do Gamo de Porcelana da Festa): rig e clipes do cavalo (mob_kit.horse_bones/horse_actions)
# ---------------------------------------------------------------------------
PS2_PORC = (0.94, 0.92, 0.88)
PS2_INK = (0.2, 0.34, 0.74)
PS2_GOLD = (0.88, 0.66, 0.26)
PS2_BONE = (0.86, 0.8, 0.72)
PS2_SILK = (0.9, 0.46, 0.56)
PS2_LANT = (1.0, 0.7, 0.34)
PS2_GLOW = 1.0


def _ps2_vein(name, cast, pts, axis_z, r, material, lift=0.004):
    """Veio de ouro (kintsugi) rente à louça: cada ponto é lançado de fora para o eixo do tronco e assenta na superfície."""
    out = []
    for q in pts:
        q = _mbV(q)
        tgt = _mbV((0, q.y, axis_z))
        p, n = cast(q, tgt - q)
        if p is not None:
            out.append(p + n * lift)
    return _mb_wb._strap(name, out, r, r * 0.6, material, 4) if len(out) > 1 else []


PS2_TINES = ((1, (0.25, -0.8, 0.55), 0.14), (2, (0.7, -0.1, 0.7), 0.17), (3, (0.45, 0.5, 0.75), 0.15))     # (ponto da haste, direção, comprimento)


def _ps2_beam(hc, sx):
    return [hc + _mbV(q) for q in ((sx * 0.05, 0.03, 0.08), (sx * 0.13, 0.1, 0.2), (sx * 0.26, 0.13, 0.31), (sx * 0.33, 0.07, 0.44), (sx * 0.3, -0.04, 0.54))]


def _ps2_mount(cid="mob_mount_porcelain_stag"):
    """Gamo de Porcelana: cervo esguio de louça (`tint`) com pintura de cobalto (`tint2`), veios de ouro, cascos dourados e
    galhada clara. Barda temática: filigrana de ouro (kintsugi) no corpo e na testa + lanterninhas de papel na galhada."""
    mk, ck, wb, V = _mb_mk, _mb_ck, _mb_wb, _mbV
    blob, cone = _mb_blob, mk.cone
    h = mk.HIP
    arm = _mb_lp.make_armature("rig_" + cid, mk.horse_bones())
    porc = _mb_mat("tint", PS2_PORC, 0.5)
    ink = _mb_mat("tint2", PS2_INK, 0.6)
    gold = _mb_mat("m_ps2_gold", PS2_GOLD, 0.4)
    bone = _mb_mat("m_ps2_bone", PS2_BONE, 0.6)
    silk = _mb_mat("m_ps2_silk", PS2_SILK, 0.8)
    leather = _mb_mat("m_ps2_leather", (0.42, 0.24, 0.22), 0.7)
    lant = _mb_mat("glow_ps2_lantern", PS2_LANT, 0.5, PS2_GLOW)
    b_iron = _mb_mat("m_bard_iron", MB_IRON, 0.4)
    b_rivet = _mb_mat("m_bard_rivet", MB_RIVET, 0.35)
    m_eye, m_white = mk.base_mats()
    parts, bard = [], {}
    pts = [((0, 0.42, h + 0.1), (0.125, 0.15)), ((0, 0.1, h + 0.1), (0.135, 0.165)), ((0, -0.24, h + 0.1), (0.145, 0.18)), ((0, -0.4, h + 0.13), (0.115, 0.15))]
    barrel = mk.skin_body("ps2_barrel", pts, [(0, 1), (1, 2), (2, 3)], porc, sub=1)
    chest = blob("ps2_chest", 0.145, (0, -0.38, h + 0.07), porc, (0.95, 0.9, 1.15))
    rump = blob("ps2_rump", 0.155, (0, 0.38, h + 0.14), porc, (1.0, 1.0, 0.95))
    parts += [(barrel, "body"), (chest, "body"), (rump, "body"),
              (blob("ps2_belly", 0.13, (0, 0.0, h + 0.0), porc, (0.85, 2.0, 0.6)), "body")]
    # pescoço fino e alto, peitilho de louça
    n0, n1 = V((0, -0.42, h + 0.16)), V((0, -0.56, h + 0.54))
    neck = ck.tube("ps2_neck", n0, n1, 0.1, 0.066, porc, 10)
    parts += [(neck, "neck"), (blob("ps2_neckbase", 0.115, n0 + V((0, 0.02, 0.02)), porc, (0.95, 1.1, 1.0)), "neck"),
              (blob("ps2_bib", 0.085, n0 + V((0, -0.1, 0.05)), porc, (0.9, 0.8, 1.3), 2), "neck")]
    for k, t in enumerate((0.3, 0.62)):                     # faixas pintadas no pescoço
        c = n0.lerp(n1, t)
        rr = 0.1 + (0.066 - 0.1) * t + 0.004
        parts.append((ck.tube("ps2_neckink%d" % k, c - (n1 - n0).normalized() * 0.014, c + (n1 - n0).normalized() * 0.014, rr, rr, ink, 10), "neck"))
    # cabeça de cervo: crânio pequeno, focinho fino, nariz de ouro, orelhas largas, flor pintada na testa
    hc = V((0, -0.66, h + 0.6))
    skull = blob("ps2_skull", 0.105, hc, porc, (0.88, 1.0, 0.95))
    snout = blob("ps2_snout", 0.08, hc + V((0, -0.14, -0.05)), porc, (0.78, 1.45, 0.8))
    parts += [(skull, "head"), (snout, "head"),
              (wb._stud("ps2_nose", hc + V((0, -0.25, -0.035)), 0.03, gold, (1.1, 0.8, 0.8), 2), "head"),
              (blob("ps2_flower", 0.036, hc + V((0, -0.06, 0.092)), ink, (1.0, 1.0, 0.3), 2), "head")]
    for k in range(5):
        a = _mb_math.tau * k / 5
        parts.append((wb._stud("ps2_petal%d" % k, hc + V((0.042 * _mb_math.sin(a), -0.06 - 0.042 * _mb_math.cos(a), 0.094 - 0.012 * _mb_math.cos(a))), 0.017, ink, (1.0, 1.0, 0.4)), "head"))
    for sx in (-1, 1):
        parts.append((ck.blade("ps2_ear%d" % sx, hc + V((sx * 0.07, 0.05, 0.05)), hc + V((sx * 0.24, 0.1, 0.13)), 0.1, 0.03, porc, (0, 1, 0.5), 0.45), "head"))
        parts.append((ck.blade("ps2_earin%d" % sx, hc + V((sx * 0.09, 0.04, 0.06)), hc + V((sx * 0.21, 0.08, 0.125)), 0.055, 0.034, ink, (0, 1, 0.5), 0.45), "head"))
        # galhada: haste que abre para fora e volta para a frente em arco, três pontas para cima
        beam = _ps2_beam(hc, sx)
        parts.append((wb._horn("ps2_beam%d" % sx, beam, [0.036, 0.033, 0.029, 0.024, 0.008], bone, 6), "head"))
        for k, (i, d, ln) in enumerate(PS2_TINES):
            parts.append((cone("ps2_tine%d_%d" % (sx, k), beam[i], beam[i] + V((sx * d[0], d[1], d[2])).normalized() * ln, 0.024, bone, 5), "head"))
    parts += [(o, "head") for o in mk.eyes("ps2", [hc + V((sx * 0.08, -0.045, 0.02)) for sx in (-1, 1)], 0.03, m_eye, m_white)]
    # rabo curto de cervo
    parts.append((ck.tube("ps2_taildock", V((0, 0.5, h + 0.2)), V((0, 0.6, h + 0.1)), 0.04, 0.035, porc, 6), "tail"))
    parts.append((blob("ps2_tailtuft", 0.05, (0, 0.62, h + 0.07), porc, (0.8, 0.8, 1.3), 2), "tail2"))
    parts.append((wb._stud("ps2_tailtip", (0, 0.625, h + 0.015), 0.03, ink, (1, 1, 1), 2), "tail2"))
    # pernas finas: meias pintadas e cascos de ouro
    for bname, (x, yt, yk, zk, yh, front) in mk.HORSE_LEGS.items():
        top, knee, foot = V((x, yt, h + 0.02)), V((x, yk, zk)), V((x, yh, 0.0))
        fet = V((x, yh, 0.1))
        if front:
            parts.append((blob("ps2_shoulder_" + bname, 0.075, top + V((0, 0.0, -0.04)), porc, (0.8, 1.0, 1.3)), bname))
            parts.append((ck.tube("ps2_arm_" + bname, top, knee, 0.062, 0.038, porc, 8), bname))
        else:
            hb = blob("ps2_haunch_" + bname, 0.105, top + V((0, -0.02, -0.06)), porc, (0.75, 1.1, 1.3))
            parts.append((hb, bname))
            sgn = 1 if x > 0 else -1
            parts += [(o, bname) for o in _mb_plate("ps2_ink_" + bname, [hb], lambda c, n, sgn=sgn: n.x * sgn > 0.7, 0.005, ink)]
            parts.append((ck.tube("ps2_gaskin_" + bname, top + V((0, 0.0, -0.08)), knee, 0.068, 0.036, porc, 8), bname))
        lo = bname + "_lo"
        parts.append((blob("ps2_knee_" + bname, 0.041, knee, porc, (1, 1, 1), 2), lo))
        parts.append((ck.tube("ps2_cannon_" + bname, knee, fet, 0.034, 0.03, porc, 8), lo))
        parts.append((ck.tube("ps2_sock_" + bname, fet + V((0, 0, 0.1)), fet + V((0, 0, 0.0)), 0.034, 0.04, ink, 8), lo))
        parts.append((ck.tube("ps2_hoof_" + bname, fet - V((0, 0, 0.0)), foot, 0.04, 0.054, gold, 8), lo))
    # pintura de cobalto: ondas na anca e no ombro (discos rentes)
    parts += [(o, "body") for o in _mb_plate("ps2_ink_rump", [rump], lambda c, n: n.z > 0.62 or (n.y > 0.72 and c.z > h + 0.1), 0.005, ink)]
    parts += [(o, "body") for o in _mb_plate("ps2_ink_chest", [chest], lambda c, n: n.y < -0.55 and abs(c.z - (h + 0.07)) < 0.07, 0.005, ink)]
    # veios de ouro (poucos na base: a louça já foi remendada)
    cast_b = wb._caster(barrel)
    for sx in (-1, 1):
        parts += [(o, "body") for o in _ps2_vein("ps2_vein_a%d" % sx, cast_b, [(sx * 0.5, 0.08, h + 0.3), (sx * 0.5, 0.11, h + 0.2), (sx * 0.5, 0.06, h + 0.1), (sx * 0.5, 0.1, h - 0.0)], h + 0.1, 0.008, gold)]
        parts += [(o, "body") for o in _ps2_vein("ps2_vein_b%d" % sx, cast_b, [(sx * 0.5, -0.2, h + 0.26), (sx * 0.5, -0.16, h + 0.16), (sx * 0.5, -0.21, h + 0.06)], h + 0.1, 0.008, gold)]
    # arreio: sela do cavalo com manta de seda, cabeçada e rédeas douradas
    _mb_saddle("ps2", parts, silk, leather, gold)
    parts += [(o, "head") for o in _mb_band("ps2_noseband", hc + V((0, -0.17, -0.055)), 0.066, 0.068, 0.009, gold, -180, 180, 8, 4)]
    for sx in (-1, 1):
        parts.append((ck.tube("ps2_cheekstrap%d" % sx, hc + V((sx * 0.064, -0.17, -0.05)), hc + V((sx * 0.092, 0.02, 0.04)), 0.008, 0.008, gold, 4), "head"))
        parts += [(o, "neck") for o in wb._strap("ps2_rein%d" % sx, [n1 + V((sx * 0.075, 0.0, -0.03)), (sx * 0.1, -0.36, h + 0.45), (sx * 0.035, -0.16, h + 0.345)], 0.008, 0.008, gold, 4)]
    # ---- barda genérica de ferro: testeira, colar de lâminas, peitoral, garupeira
    bard["barding_iron_head"] = (
        _mb_plate("ps2_bi_chanf", [skull], lambda c, n: n.z > 0.3 and abs(c.x) < 0.07 and c.y < hc.y + 0.06, 0.02, b_iron, b_rivet, 0.06, 0.011) +
        _mb_plate("ps2_bi_nose", [snout], lambda c, n: n.z > 0.45 and abs(c.x) < 0.05 and c.y > hc.y - 0.24, 0.018, b_iron, b_rivet, 0.07, 0.011) +
        [ck.tube("ps2_bi_ridge", hc + V((0, -0.2, 0.03)), hc + V((0, 0.02, 0.115)), 0.012, 0.012, b_rivet, 5)], "head")
    ax = (n1 - n0).normalized()
    crinet = []
    for k, t in enumerate((0.14, 0.4, 0.66)):
        c = n0.lerp(n1, t)
        rr = 0.1 + (0.066 - 0.1) * t
        crinet.append(ck.tube("ps2_bi_crinet%d" % k, c - ax * 0.055, c + ax * 0.055, rr + 0.03, rr + 0.012, b_iron, 10))
        crinet.append(wb._stud("ps2_bi_crinetstud%d" % k, c - ax * 0.03 + V((0, -1, -0.37)).normalized() * (rr + 0.026), 0.014, b_rivet))
    bard["barding_iron_neck"] = (crinet, "neck")
    bard["barding_iron_chest"] = (
        _mb_plate("ps2_bi_peyt", [chest], lambda c, n: n.y < -0.1 and c.z < h + 0.2, 0.024, b_iron, b_rivet, 0.085, 0.013) +
        _mb_band("ps2_bi_peytrim", (0, -0.34, h + 0.08), 0.15, 0.18, 0.013, b_rivet, 100, 260, 8), "body")
    bard["barding_iron_rump"] = (
        _mb_plate("ps2_bi_crup", [rump], lambda c, n: (n.z > 0.1 or n.y > 0.55) and c.y > 0.27, 0.024, b_iron, b_rivet, 0.085, 0.013) +
        _mb_band("ps2_bi_cruprim", (0, 0.26, h + 0.1), 0.142, 0.172, 0.013, b_rivet, -105, 105, 8), "body")
    # ---- barda de festa: filigrana de ouro (kintsugi) + lanterninhas de papel na galhada
    kind = "barding_porcelain_stag"
    hd = []
    for sx in (-1, 1):
        beam = _ps2_beam(hc, sx)
        for k, (i, t) in enumerate(((0, 0.55), (1, 0.6), (2, 0.6))):          # anéis de ouro na haste
            c = beam[i].lerp(beam[i + 1], t)
            d = (beam[i + 1] - beam[i]).normalized()
            hd.append(ck.tube("ps2_bp_beamring%d_%d" % (sx, k), c - d * 0.014, c + d * 0.014, 0.036 - 0.004 * k, 0.036 - 0.004 * k, gold, 6))
        for k, (j, s) in enumerate(((1, 0.052), (2, 0.044))):
            i, d, ln = PS2_TINES[j]
            tip = beam[i] + V((sx * d[0], d[1], d[2])).normalized() * (ln * 0.8) + V((sx * 0.03, 0, 0))
            hd += wb._ps_lantern("ps2_bp_lant%d_%d" % (sx, k), tip, 0.035, s, lant, gold, silk, tassel=0.05, hoops=False, segs=6)
    hd += _mb_band("ps2_bp_diadem", hc + V((0, -0.035, 0.0)), 0.1, 0.107, 0.01, gold, -62, 62, 8, 4)
    hd.append(wb._stud("ps2_bp_tear", hc + V((0, -0.098, 0.062)), 0.02, lant, (0.8, 0.8, 1.3), 2))
    cast_s = wb._caster(skull)
    for sx in (-1, 1):
        hd += _ps2_vein("ps2_bp_facevein%d" % sx, cast_s, [hc + V((sx * 0.3, -0.02, 0.1)), hc + V((sx * 0.3, -0.07, 0.03)), hc + V((sx * 0.3, -0.04, -0.05))], hc.z, 0.006, gold)
    bard[kind + "_head"] = (hd, "head")
    nk = []
    c = n0.lerp(n1, 0.16)
    nk.append(ck.tube("ps2_bp_collar", c - ax * 0.022, c + ax * 0.022, 0.108, 0.104, gold, 10))
    for k, a in enumerate((-60, -20, 20, 60)):
        ar = _mb_math.radians(a)
        p = c + V((0.108 * _mb_math.sin(ar), -0.1 * _mb_math.cos(ar), -0.045 * _mb_math.cos(ar) - 0.02))
        nk.append(wb._stud("ps2_bp_bell%d" % k, p, 0.022, gold, (1.0, 1.0, 1.1), 2))
    nk.append(ck.tube("ps2_bp_tassel", c + V((0, -0.1, -0.06)), c + V((0, -0.11, -0.17)), 0.012, 0.03, silk, 5))
    bard[kind + "_neck"] = (nk, "neck")
    bd = []
    cast_r, cast_c = wb._caster(rump), wb._caster(chest)
    cast_rb = lambda o, d: cast_r(o, d) if cast_r(o, d)[0] is not None else cast_b(o, d)
    for sx in (-1, 1):
        # volutas de filigrana no flanco da frente e de trás + veios que sobem ao lombo
        for k, (cy, cz, r0, a0, a1) in enumerate(((-0.25, 0.1, 0.085, 200, -160), (0.3, 0.12, 0.095, -20, 340))):
            sp = wb._ps_spiral((sx * 0.5, cy, h + cz), (0, 1, 0), (0, 0, 1), r0, 0.012, a0, a1, 9)
            bd += _ps2_vein("ps2_bp_scroll%d_%d" % (sx, k), cast_b if k == 0 else cast_rb, sp, h + 0.1, 0.009, gold)
        bd += _ps2_vein("ps2_bp_vein_c%d" % sx, cast_b, [(sx * 0.5, 0.22, h + 0.24), (sx * 0.5, 0.26, h + 0.14), (sx * 0.5, 0.2, h + 0.05), (sx * 0.5, 0.24, h - 0.03)], h + 0.1, 0.008, gold)
        bd += _ps2_vein("ps2_bp_vein_d%d" % sx, cast_c, [(sx * 0.5, -0.4, h + 0.2), (sx * 0.5, -0.44, h + 0.1), (sx * 0.5, -0.4, h + 0.0)], h + 0.07, 0.008, gold)
        for sy in (-1, 1):                                  # guizos de ouro nos cantos da manta
            bd.append(wb._stud("ps2_bp_jingle%d_%d" % (sx, sy), (sx * 0.188, -0.02 + sy * 0.185, h + 0.035), 0.024, gold, (1, 1, 1), 2))
    bd += _mb_band("ps2_bp_breast", (0, -0.36, h + 0.09), 0.148, 0.185, 0.011, gold, 110, 250, 8, 4)
    bd.append(wb._stud("ps2_bp_breastgem", (0, -0.52, h + 0.03), 0.026, lant, (1.0, 0.7, 1.2), 2))
    bd += _mb_band("ps2_bp_crupper", (0, 0.3, h + 0.12), 0.145, 0.165, 0.011, gold, -100, 100, 8, 4)
    bard[kind + "_body"] = (bd, "body")
    _mb_finish(arm, "ps2", parts, bard)
    mk.horse_actions(arm)
    _mb_key_all(arm)
    _mb_ground(arm, cid)
    return arm


BUILDERS.update({
    "mob_mount_armored_rhino": _ar_mount,
    "mob_mount_iron_wolf": _iw2_mount,
    "mob_mount_porcelain_stag": _ps2_mount,
})


# =====================================================================================================================
# PARTE A — Javali de Guerra (_wb_), Alce do Bosque (_fe_), Lagarto das Ruínas (_rl_) + barda de ferro do cavalo
# Helpers comuns da parte A: _ma_*. Notas: production/session-state/agent-mounts-a.md
#
# Molde: ossos do cavalo (root, body, neck, head, tail, tail2, leg_<fr|fl|br|bl> + _lo), clipes idle/walk/run com TODOS
# os ossos gravados e nenhum quadro abaixo do chão (_ma_ground sobe a raiz o que faltar). A sela é a do cavalo, no mesmo
# lugar (y = -0,02, topo em HIP + 0,33): EntityView.SADDLE_Y serve sem mudar.
# Barda: nós `barding_iron_<head|chest|rump>` e `barding_<kind>_<head|body>`; o GLB os leva visíveis (glTF não guarda
# "escondido"): o jogo esconde por nome ao carregar.
# =====================================================================================================================
import math
import random

import bmesh
import bpy
from mathutils import Vector, Matrix
from mathutils.bvhtree import BVHTree

import chibi_kit as ck
import lowpoly_lib as lp
import mob_kit as mk

_MA_IRON = (0.5, 0.52, 0.58)
_MA_LEGS = ("leg_fr", "leg_fl", "leg_br", "leg_bl")


def _ma_mat(name, color, rough=0.85, emission=0.0, force=False):
    """ck.mat; force = a cor é regravada ("tint"/"tint2" podem já existir no arquivo com a cor de outro bicho)."""
    m = ck.mat(name, color, rough, emission)
    if force:
        bsdf = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
        bsdf.inputs["Base Color"].default_value = (*color, 1.0)
        m.diffuse_color = (*color, 1.0)
    return m


def _ma_sweep(name, pts, radii, material, segs=8):
    """Tubo contínuo pelos pontos; raio r ou (meia largura, meia altura) por anel; pontas fechadas."""
    pts = [Vector(q) for q in pts]
    n = len(pts) - 1
    b = bmesh.new()
    rows, u = [], None
    for i, q in enumerate(pts):
        t = (pts[min(i + 1, n)] - pts[max(i - 1, 0)]).normalized()
        if u is None:
            u = Vector((0, 1, 0)) if abs(t.x) > 0.9 else Vector((1, 0, 0))
        u = (u - t * u.dot(t)).normalized()
        w = t.cross(u)
        r = radii[i]
        rx, rz = r if isinstance(r, tuple) else (r, r)
        rows.append([b.verts.new(q + u * (math.cos(math.tau * j / segs) * rx) + w * (math.sin(math.tau * j / segs) * rz)) for j in range(segs)])
    for i in range(n):
        for j in range(segs):
            b.faces.new((rows[i][j], rows[i][(j + 1) % segs], rows[i + 1][(j + 1) % segs], rows[i + 1][j]))
    b.faces.new(list(reversed(rows[0])))
    b.faces.new(rows[n])
    bmesh.ops.recalc_face_normals(b, faces=b.faces[:])
    return ck.mesh_from(name, b, material)


def _ma_stud(name, p, r, material, sq=(1.0, 1.0, 1.0), sub=0):
    """Rebite/botão/almofada barato: octaedro (sub=0, 8 triângulos) ou icosfera."""
    b = bmesh.new()
    if sub == 0:
        vs = [b.verts.new(Vector(c) * r) for c in ((1, 0, 0), (-1, 0, 0), (0, 1, 0), (0, -1, 0), (0, 0, 1), (0, 0, -1))]
        for i, j, k in ((0, 2, 4), (2, 1, 4), (1, 3, 4), (3, 0, 4), (2, 0, 5), (1, 2, 5), (3, 1, 5), (0, 3, 5)):
            b.faces.new((vs[i], vs[j], vs[k]))
    else:
        bmesh.ops.create_icosphere(b, subdivisions=sub, radius=r)
    p = Vector(p)
    for v in b.verts:
        v.co = Vector((v.co.x * sq[0], v.co.y * sq[1], v.co.z * sq[2])) + p
    return ck.mesh_from(name, b, material)


def _ma_pad(name, p, n, r, material, flat=0.4, sub=1):
    """Almofada (musgo) deitada na superfície: icosfera achatada ao longo da normal n."""
    b = bmesh.new()
    bmesh.ops.create_icosphere(b, subdivisions=sub, radius=r)
    p, n = Vector(p), Vector(n).normalized()
    for v in b.verts:
        v.co = p + v.co - n * (v.co.dot(n) * (1.0 - flat))
    return ck.mesh_from(name, b, material)


def _ma_crystal(name, a, b_, r, material, segs=5):
    """Cristal facetado de a até a ponta b_ (cintura a 55% do caminho)."""
    a, b_ = Vector(a), Vector(b_)
    d = (b_ - a).normalized()
    u = d.cross(Vector((0, 0, 1)))
    if u.length < 0.2:
        u = d.cross(Vector((1, 0, 0)))
    u.normalize()
    w = d.cross(u)
    b = bmesh.new()
    mid = a.lerp(b_, 0.55)
    ring = [b.verts.new(mid + (u * math.cos(math.tau * i / segs) + w * math.sin(math.tau * i / segs)) * r) for i in range(segs)]
    base, apex = b.verts.new(a), b.verts.new(b_)
    for i in range(segs):
        j = (i + 1) % segs
        b.faces.new((ring[i], ring[j], apex))
        b.faces.new((ring[j], ring[i], base))
    bmesh.ops.recalc_face_normals(b, faces=b.faces[:])
    return ck.mesh_from(name, b, material)


def _ma_ribbon(name, pts, width, material, wdir=(1, 0, 0), th=0.012, taper=1.0):
    """Fita dobrada (nunca placa chata): faixa com espessura pelos pontos, largura no sentido wdir."""
    pts = [Vector(q) for q in pts]
    n = len(pts) - 1
    b = bmesh.new()
    rows = []
    for i, q in enumerate(pts):
        t = (pts[min(i + 1, n)] - pts[max(i - 1, 0)]).normalized()
        wd = Vector(wdir)
        wd = (wd - t * wd.dot(t)).normalized()
        nn = t.cross(wd)
        hw = width * 0.5 * (1.0 + (taper - 1.0) * i / n)
        rows.append([b.verts.new(q + wd * hw + nn * th * 0.5), b.verts.new(q - wd * hw + nn * th * 0.5),
                     b.verts.new(q - wd * hw - nn * th * 0.5), b.verts.new(q + wd * hw - nn * th * 0.5)])
    for i in range(n):
        for j in range(4):
            b.faces.new((rows[i][j], rows[i][(j + 1) % 4], rows[i + 1][(j + 1) % 4], rows[i + 1][j]))
    b.faces.new(list(reversed(rows[0])))
    b.faces.new(rows[n])
    bmesh.ops.recalc_face_normals(b, faces=b.faces[:])
    return ck.mesh_from(name, b, material)


def _ma_arc(name, c, r, a0, a1, th, material, n=8, segs=5, axis="y"):
    """Arco de tubos em volta do eixo Y (ou X) com centro c; r = raio ou (rx, rz); ângulo 0 = para cima, em graus."""
    c = Vector(c)
    rx, rz = r if isinstance(r, tuple) else (r, r)
    out, prev = [], None
    for i in range(n + 1):
        a = math.radians(a0 + (a1 - a0) * i / n)
        q = c + (Vector((rx * math.sin(a), 0, rz * math.cos(a))) if axis == "y" else Vector((0, rx * math.sin(a), rz * math.cos(a))))
        if prev is not None:
            out.append(ck.tube("%s_%d" % (name, i), prev, prev.lerp(q, 1.08), th, th, material, segs))
        prev = q
    return out


def _ma_bvh(objs):
    b = bmesh.new()
    for o in objs:
        b.from_mesh(o.data)
    bvh = BVHTree.FromBMesh(b)
    b.free()
    return bvh


def _ma_plate(name, bvh, a, b_, span, material, off=0.022, nt=5, na=8, up=(0, 0, 1), skirt=0.03, reach=0.9):
    """Chapa rente ao corpo: grade (t pelo eixo a->b_, ângulo em volta dele; 0 = `up`) projetada por raios de fora para o
    eixo e afastada `off`; a borda ganha uma saia que entra `skirt` (lê como espessura). span(t) -> (ang0, ang1) em graus.
    Devolve (objeto, pontos da grade, normais da grade)."""
    a, b_ = Vector(a), Vector(b_)
    d = (b_ - a).normalized()
    w = Vector(up)
    w = (w - d * w.dot(d)).normalized()
    u = d.cross(w)
    b = bmesh.new()
    grid, nrm, vs = [], [], []
    for i in range(nt + 1):
        t = i / nt
        c = a.lerp(b_, t)
        a0, a1 = span(t)
        gp, gn, gv = [], [], []
        for j in range(na + 1):
            ang = math.radians(a0 + (a1 - a0) * j / na)
            out = w * math.cos(ang) + u * math.sin(ang)
            hit = bvh.ray_cast(c + out * reach, -out, reach)
            p = (hit[0] if hit[0] is not None else c + out * 0.04) + out * off
            gp.append(p)
            gn.append(out)
            gv.append(b.verts.new(p))
        grid.append(gp)
        nrm.append(gn)
        vs.append(gv)
    faces = []
    for i in range(nt):
        for j in range(na):
            faces.append(b.faces.new((vs[i][j], vs[i][j + 1], vs[i + 1][j + 1], vs[i + 1][j])))
    border = [(i, 0) for i in range(nt + 1)] + [(nt, j) for j in range(1, na + 1)] + [(i, na) for i in range(nt - 1, -1, -1)] + [(0, j) for j in range(na - 1, 0, -1)]
    inner = [b.verts.new(grid[i][j] - nrm[i][j] * (off + skirt)) for i, j in border]
    for k in range(len(border)):
        k2 = (k + 1) % len(border)
        i, j = border[k]
        i2, j2 = border[k2]
        b.faces.new((vs[i][j], vs[i2][j2], inner[k2], inner[k]))
    bmesh.ops.recalc_face_normals(b, faces=b.faces[:])
    b.normal_update()
    mid = faces[len(faces) // 2]
    if mid.normal.dot(nrm[nt // 2][na // 2]) < 0:
        bmesh.ops.reverse_faces(b, faces=b.faces[:])
    return ck.mesh_from(name, b, material), grid, nrm


def _ma_rivets(name, grid, nrm, picks, r, material, lift=0.002):
    return [_ma_stud("%s_%d" % (name, k), grid[i][j] + nrm[i][j] * lift, r, material) for k, (i, j) in enumerate(picks)]


def _ma_strokes(name, grid, nrm, strokes, r, material, lift=0.004):
    """Runas/filetes: traços (tubos finos) entre pontos da grade de uma chapa."""
    out = []
    for k, ((i, j), (i2, j2)) in enumerate(strokes):
        out.append(ck.tube("%s_%d" % (name, k), grid[i][j] + nrm[i][j] * lift, grid[i2][j2] + nrm[i2][j2] * lift, r, r, material, 4))
    return out


def _ma_edge(nt, na, corners=True, step=2):
    """Pontos da borda de uma grade (para rebites), um a cada `step`."""
    pts = [(i, 0) for i in range(0, nt + 1, step)] + [(i, na) for i in range(0, nt + 1, step)]
    pts += [(0, j) for j in range(step, na, step)] + [(nt, j) for j in range(step, na, step)]
    return pts


def _ma_flat(objs):
    for o in objs if isinstance(objs, (list, tuple)) else [objs]:
        o["ma_flat"] = True
    return objs


class _MaBard:
    """Junta as peças de barda por nó (1 malha por nó `barding_<estilo>_<parte>`, num osso só)."""

    def __init__(self):
        self.nodes = {}

    def add(self, node, bone, objs):
        objs = objs if isinstance(objs, (list, tuple)) else [objs]
        self.nodes.setdefault(node, (bone, []))[1].extend(objs)

    def parts(self):
        out = []
        for node, (bone, objs) in self.nodes.items():
            for o in objs:
                flat = bool(o.get("ma_flat"))
                for p in o.data.polygons:
                    p.use_smooth = not flat
            j = ck._join(objs, node)
            j["ma_keep_shading"] = True
            out.append((j, bone))
        return out


def _ma_finish(arm, parts):
    for o, bone in parts:
        if not o.get("ma_keep_shading"):
            flat = bool(o.get("ma_flat"))
            for p in o.data.polygons:
                p.use_smooth = not flat
        for key in ("ma_flat", "ma_keep_shading"):
            if key in o:
                del o[key]
        lp.attach(o, arm, bone)


def _ma_bones(h, neck, head, tail, legs):
    """neck/head = (cabeça, ponta); tail = (p0, p1, p2); legs = {osso: (topo, joelho, pé)}."""
    b = {"root": ((0, 0, 0), (0, 0, 0.2), None), "body": ((0, 0, h), (0, 0, h + 0.3), "root"),
         "neck": (tuple(neck[0]), tuple(neck[1]), "body"), "head": (tuple(head[0]), tuple(head[1]), "neck"),
         "tail": (tuple(tail[0]), tuple(tail[1]), "body"), "tail2": (tuple(tail[1]), tuple(tail[2]), "tail")}
    for bone, (top, knee, foot) in legs.items():
        b[bone] = (tuple(top), tuple(knee), "body")
        b[bone + "_lo"] = (tuple(knee), tuple(foot), bone)
    return b


def _ma_saddle(pre, parts, bvh, h, leather, blanket, trim, wide=1.0, girth=0.19, cloth=(-0.27, 0.24, 78.0)):
    """A sela do cavalo, no mesmo lugar e tamanho (o jogo senta o boneco nela), + manta de pano rente ao lombo."""
    blob = mk.blob
    parts.append((blob(pre + "pad", 0.2, (0, -0.02, h + 0.19), blanket, (0.92 * wide, 1.15, 0.45), 2), "body"))
    parts.append((blob(pre + "saddle", 0.15, (0, -0.02, h + 0.27), leather, (0.85, 1.05, 0.4)), "body"))
    parts.append((blob(pre + "cantle", 0.1, (0, 0.11, h + 0.32), leather, (1.1, 0.35, 0.55), 2), "body"))
    parts.append((ck.ball(pre + "horn", 0.03, (0, -0.15, h + 0.34), trim), "body"))
    y0, y1, ang = cloth
    edge = lambda t: ang + 9.0 * math.cos(t * math.pi * 2.0)            # barra em onda: cantos mais compridos
    cl, grid, nrm = _ma_plate(pre + "cloth", bvh, (0, y0, h + 0.08), (0, y1, h + 0.08), lambda t: (-edge(t), edge(t)), blanket, off=0.012, nt=4, na=10, skirt=0.012)
    parts.append((cl, "body"))
    for k, (i, j) in enumerate(((0, 0), (4, 0), (0, 10), (4, 10))):   # borlas nos cantos
        parts.append((_ma_stud("%stassel%d" % (pre, k), grid[i][j] + nrm[i][j] * 0.004, 0.02, trim, (1, 1, 1.3)), "body"))
    for k, j in enumerate((0, 10)):                                     # filete na barra
        for i in range(4):
            parts.append((ck.tube("%shem%d_%d" % (pre, k, i), grid[i][j] + nrm[i][j] * 0.003, grid[i + 1][j] + nrm[i + 1][j] * 0.003, 0.009, 0.009, trim, 3), "body"))
    for sx in (-1, 1):
        parts.append((ck.tube("%sstrap%d" % (pre, sx), (sx * 0.16, -0.04, h + 0.24), (sx * girth, -0.04, h + 0.0), 0.012, 0.012, leather, 5), "body"))
        parts.append((ck.tube("%sstirrup%d" % (pre, sx), (sx * girth, -0.07, h - 0.01), (sx * girth, -0.01, h - 0.01), 0.022, 0.022, trim, 6), "body"))


def _ma_reins(pre, parts, pts, leather, trim, h, r=0.009):
    """Rédeas: da argola do freio (pts[0], ao lado da boca) pelos pontos do lado +X (espelhados) até o cabeçote da sela.
    O 1º trecho vai no osso do pescoço, o resto no corpo (passa por fora do ombro e sobe pela cernelha)."""
    for sx in (-1, 1):
        path = [Vector((sx * q[0], q[1], q[2])) for q in pts] + [Vector((sx * 0.035, -0.19, h + 0.345))]
        for k in range(len(path) - 1):
            parts.append((ck.tube("%srein%d_%d" % (pre, sx, k), path[k], path[k].lerp(path[k + 1], 1.03), r, r, leather, 4), "neck" if k == 0 else "body"))
        parts.append((_ma_stud("%sbit%d" % (pre, sx), path[0], 0.02, trim, sub=1), "head"))


# ---------------------------------------------------------------------------
# clipes (idle, walk, run): poses em eixos do esqueleto -> ossos; chão conferido quadro a quadro
# ---------------------------------------------------------------------------
def _ma_frames(G):
    """{clipe: [ {osso: ((pitch, yaw, roll) em graus nos eixos X/Z/Y do esqueleto, (x, y, z) de deslocamento)} por quadro ]}.
    pitch > 0: perna para trás, pescoço/cabeça abaixam, frente do corpo desce, rabo sobe."""
    tau = math.tau
    z = (0.0, 0.0, 0.0)
    legs = G["legs"]                   # osso -> (dianteira?, lado +1/-1)
    out = {}
    I = G["idle"]
    n = 72
    fr = []
    for f in range(n + 1):
        t = f / n
        s1, s2 = math.sin(tau * t), math.sin(tau * t * 2)
        P = {"root": (z, (0, 0, I.get("breath", 0.006) * s2)),
             "body": ((0.8 * s2, 0, 0), z),
             "neck": ((I.get("neck_p", 5.0) * s1 + I.get("neck_p0", 2.0), I.get("neck_y", 2.5) * math.sin(tau * t + 1.0), 0), z),
             "head": ((I.get("head_p", -4.0) * math.sin(tau * t * I.get("head_f", 1) + 0.6), I.get("head_y", 4.0) * s1, 0), z),
             "tail": ((0, I.get("tail_y", 14.0) * math.sin(tau * t * I.get("tail_f", 3)), 0), z),
             "tail2": ((0, I.get("tail2_y", 18.0) * math.sin(tau * t * I.get("tail_f", 3) - 0.9), 0), z)}
        for bone in legs:
            P[bone] = (z, z)
            P[bone + "_lo"] = (z, z)
        if I.get("rest_leg"):            # troca o peso de uma pata de trás (como o cavalo)
            P[I["rest_leg"]] = ((-4.0, 0, 0), z)
            P[I["rest_leg"] + "_lo"] = ((-10.0, 0, 0), z)
        fr.append(P)
    out["idle"] = fr
    for name in ("walk", "run"):
        n, phases, duty, amp, flex, bob, pitch, nod = G[name]
        sway, twist, hock = G.get("sway", {}).get(name, 0.0), G.get("twist", 0.0), G.get("hock", 0.8)
        fr = []
        for f in range(n + 1):
            t = f / n
            P = {}
            for bone, ph in phases.items():
                front, side = legs[bone]
                a, k = mk._gait_leg((t - ph) % 1.0, duty, amp * (1.0 if front else 0.9), flex)
                P[bone] = ((a, side * twist * a / amp, 0), z)
                P[bone + "_lo"] = ((k if front else -k * hock, 0, 0), z)
            sw = sway * math.sin(tau * t)
            if name == "run" and G.get("gallop", True):
                up = bob * math.sin(tau * (t - 0.3))
                bp = pitch * math.sin(tau * (t - 0.05))
                P["root"] = (z, (0, 0, up))
                P["body"] = ((bp, sw, 0), z)
                P["neck"] = ((-0.9 * bp + nod * math.sin(tau * (t - 0.2)) + G.get("run_neck", 8.0), -0.6 * sw, 0), z)
                P["head"] = ((-0.5 * nod * math.sin(tau * (t - 0.2)) + G.get("run_head", -6.0), -0.3 * sw, 0), z)
                P["tail"] = ((G.get("run_tail", 14.0) + 5.0 * math.sin(tau * t), -1.2 * sway * math.sin(tau * t - 0.6), 0), z)
                P["tail2"] = ((G.get("run_tail", 14.0) * 0.6 + 8.0 * math.sin(tau * t - 1.2), 4.0 * math.sin(tau * t) - 1.5 * sway * math.sin(tau * t - 1.4), 0), z)
            else:                        # passo/trote: o corpo sobe 2x por passada, o pescoço acena junto
                P["root"] = (z, (0, 0, bob * math.cos(tau * t * 2)))
                P["body"] = ((0, sw, pitch * math.sin(tau * t)), z)
                P["neck"] = ((nod * math.sin(tau * t * 2) + 3.0, -0.6 * sw, 0), z)
                P["head"] = ((-0.5 * nod * math.sin(tau * t * 2), -0.3 * sw, 0), z)
                wag = 8.0 if not sway else 0.0
                P["tail"] = ((0, wag * math.sin(tau * t) - 1.2 * sway * math.sin(tau * t - 0.6), 0), z)
                P["tail2"] = ((0, wag * 1.25 * math.sin(tau * t - 0.8) - 1.5 * sway * math.sin(tau * t - 1.4), 0), z)
            fr.append(P)
        out[name] = fr
    return out


def _ma_local(arm):
    """osso -> função (rot, loc) em eixos do esqueleto -> (euler XYZ em graus, loc) nos eixos do osso."""
    mats = {b.name: b.matrix_local.to_3x3() for b in arm.data.bones}
    inv = {k: m.inverted() for k, m in mats.items()}

    def conv(bone, rot, loc):
        p, y, r = rot
        R = Matrix.Rotation(math.radians(y), 3, "Z") @ Matrix.Rotation(math.radians(r), 3, "Y") @ Matrix.Rotation(math.radians(p), 3, "X")
        e = (inv[bone] @ R @ mats[bone]).to_euler("XYZ")
        return tuple(math.degrees(v) for v in e), tuple(inv[bone] @ Vector(loc))
    return conv


def _ma_ground(arm, frames, conv, drop=None, margin=0.0015, report=True):
    """Nenhum quadro abaixo do chão: mede o ponto mais baixo de todas as malhas em cada quadro e sobe a raiz o que faltar.
    drop = {clipe: quanto a raiz pode DESCER quando tudo ficou no ar} (o passo assenta as patas)."""
    import numpy as np
    drop = drop or {}
    meshes = []
    for o in arm.children:
        if o.type != "MESH":
            continue
        co = np.empty(len(o.data.vertices) * 3)
        o.data.vertices.foreach_get("co", co)
        meshes.append((o, co.reshape(-1, 3)))
    for pb in arm.pose.bones:
        pb.rotation_mode = "XYZ"
    worst = {}
    for clip, fr in frames.items():
        low = 0.0
        for P in fr:
            for bone, (rot, loc) in P.items():
                e, l = conv(bone, rot, loc)
                pb = arm.pose.bones[bone]
                pb.rotation_euler = [math.radians(v) for v in e]
                pb.location = l
            bpy.context.view_layer.update()
            zmin = 1e9
            for o, co in meshes:
                m = o.matrix_world
                zmin = min(zmin, float((co @ np.array(m[2][:3]) + m[2][3]).min()))
            low = min(low, zmin)
            lift = -zmin if zmin < 0 else -min(zmin, drop.get(clip, 0.0))
            if zmin < 0:
                lift += margin
            rot, loc = P["root"]
            P["root"] = (rot, (loc[0], loc[1], loc[2] + lift))
        worst[clip] = low
    for pb in arm.pose.bones:
        pb.rotation_euler = (0, 0, 0)
        pb.location = (0, 0, 0)
    bpy.context.view_layer.update()
    if report:
        print("MA_GROUND %s: mais baixo antes da correção %s" % (arm.name, {k: round(v, 4) for k, v in worst.items()}))


def _ma_clips(arm, G):
    conv = _ma_local(arm)
    frames = _ma_frames(G)
    _ma_ground(arm, frames, conv, G.get("drop"))
    bones = list(arm.data.bones.keys())
    for clip, fr in frames.items():
        keys = {b: [] for b in bones}
        for f, P in enumerate(fr):
            for b in bones:
                rot, loc = P.get(b, ((0, 0, 0), (0, 0, 0)))
                e, l = conv(b, rot, loc)
                keys[b].append((f + 1, e, l))
        lp.add_action(arm, clip, keys, len(fr))


_MA_GALLOP = {"leg_bl": 0.0, "leg_br": 0.1, "leg_fl": 0.42, "leg_fr": 0.52}
_MA_WALK = {"leg_bl": 0.0, "leg_fl": 0.25, "leg_br": 0.5, "leg_fr": 0.75}
_MA_TROT = {"leg_bl": 0.0, "leg_fr": 0.0, "leg_br": 0.5, "leg_fl": 0.5}
_MA_LEG_SIDES = {"leg_fr": (True, 1), "leg_fl": (True, -1), "leg_br": (False, 1), "leg_bl": (False, -1)}


# ---------------------------------------------------------------------------
# barda de ferro (genérica): testeira, peitoral e garupeira rebitados, moldados em cada corpo
# ---------------------------------------------------------------------------
def _ma_iron(pre):
    return _ma_mat("m_%s_iron" % pre, _MA_IRON, 0.45)


def _ma_chanfron(bard, pre, bvh, a, b_, half0, half1, iron, dark, rivet, up=(0, 0, 1), nt=4, na=6, off=0.02, spike=None):
    """Testeira: chapa da testa ao focinho (meio ângulo half0 -> half1), nervura no meio e rebites na borda."""
    pl, grid, nrm = _ma_plate(pre + "chanfron", bvh, a, b_, lambda t: (-(half0 + (half1 - half0) * t), half0 + (half1 - half0) * t), iron, off=off, nt=nt, na=na, up=up, skirt=0.02)
    objs = [pl]
    mid = na // 2
    for i in range(nt):
        objs.append(ck.tube("%schan_rib%d" % (pre, i), grid[i][mid] + nrm[i][mid] * 0.004, grid[i + 1][mid] + nrm[i + 1][mid] * 0.004, 0.014, 0.012, dark, 3))
    objs += _ma_flat(_ma_rivets(pre + "chan_rv", grid, nrm, [(i, j) for i in range(0, nt + 1, 2) for j in (0, na)], 0.013, rivet))
    if spike:
        p = grid[0][mid] + nrm[0][mid] * 0.002
        objs.append(_ma_flat(mk.cone(pre + "chan_spike", p, p + Vector(spike), 0.026, rivet, 5)))
    bard.add("barding_iron_head", "head", objs)
    return grid, nrm


def _ma_peytral(bard, pre, bvh, y0, y1, zc, top, low0, low1, iron, dark, rivet, nt=4, na=7, off=0.024):
    """Peitoral: duas abas (uma de cada lado, de `top` graus até embaixo) que se encontram sob o peito na frente."""
    objs = []
    for sx in (-1, 1):
        span = lambda t, sx=sx: (sx * top, sx * (low0 + (low1 - low0) * t ** 0.7))
        pl, grid, nrm = _ma_plate("%speytral%d" % (pre, sx), bvh, (0, y0, zc), (0, y1, zc), span, iron, off=off, nt=nt, na=na, skirt=0.024)
        objs.append(pl)
        for j in range(na):                # filete na borda de trás
            objs.append(ck.tube("%spey_rim%d_%d" % (pre, sx, j), grid[nt][j] + nrm[nt][j] * 0.003, grid[nt][j + 1] + nrm[nt][j + 1] * 0.003, 0.013, 0.013, dark, 3))
        objs += _ma_flat(_ma_rivets("%spey_rv%d" % (pre, sx), grid, nrm, [(i, 0) for i in range(nt + 1)] + [(nt - 1, j) for j in range(2, na, 2)] + [(1, j) for j in range(2, na, 2)], 0.014, rivet))
    bard.add("barding_iron_chest", "body", objs)


def _ma_crupper(bard, pre, bvh, y0, y1, zc, half0, half1, iron, dark, rivet, nt=4, na=10, off=0.024, wave=7.0):
    """Garupeira: chapa sobre a garupa, barra recortada em ondas, espinha no meio e rebites."""
    span = lambda t: (-(half0 + (half1 - half0) * t + wave * math.cos(t * math.pi * 2)), half0 + (half1 - half0) * t + wave * math.cos(t * math.pi * 2))
    pl, grid, nrm = _ma_plate(pre + "crupper", bvh, (0, y0, zc), (0, y1, zc), span, iron, off=off, nt=nt, na=na, skirt=0.024)
    objs = [pl]
    mid = na // 2
    for i in range(nt):
        objs.append(ck.tube("%scru_rib%d" % (pre, i), grid[i][mid] + nrm[i][mid] * 0.004, grid[i + 1][mid] + nrm[i + 1][mid] * 0.004, 0.015, 0.013, dark, 3))
    for j in range(na):                    # filete na borda da frente (junto da sela)
        objs.append(ck.tube("%scru_rim%d" % (pre, j), grid[0][j] + nrm[0][j] * 0.003, grid[0][j + 1] + nrm[0][j + 1] * 0.003, 0.012, 0.012, dark, 3))
    objs += _ma_flat(_ma_rivets(pre + "cru_rv", grid, nrm, [(i, j) for i in range(nt + 1) for j in (0, na)] + [(nt, j) for j in range(2, na - 1, 2)] + [(2, 2), (2, na - 2)], 0.014, rivet))
    bard.add("barding_iron_rump", "body", objs)


# ---------------------------------------------------------------------------
# Javali de Guerra (primo manso do Javali Ancestral): atarracado, cabeçorra, presas, crista de cerdas (tint2)
# ---------------------------------------------------------------------------
_WB_COAT = (0.56, 0.4, 0.29)
_WB_BRISTLE = (0.27, 0.19, 0.15)
_WB_LIGHT = (0.84, 0.7, 0.55)
_WB_DARK = (0.2, 0.16, 0.15)
_WB_IVORY = (0.96, 0.92, 0.8)
_WB_NOSE = (0.9, 0.6, 0.58)
_WB_LEATHER = (0.36, 0.22, 0.14)
_WB_BLANKET = (0.3, 0.5, 0.34)
_WB_GOLD = (0.9, 0.72, 0.32)
_WB_HIDE = (0.47, 0.42, 0.33)
_WB_MOSS = (0.45, 0.66, 0.3)


def _wb_mount(cid="mob_mount_war_boar"):
    h = mk.HIP
    V = Vector
    blob = mk.blob
    legs = {}
    for bone, (front, sx) in _MA_LEG_SIDES.items():
        if front:
            legs[bone] = ((sx * 0.14, -0.31, 0.45), (sx * 0.14, -0.32, 0.22), (sx * 0.14, -0.32, 0.0))
        else:
            legs[bone] = ((sx * 0.14, 0.31, 0.47), (sx * 0.14, 0.36, 0.23), (sx * 0.14, 0.335, 0.0))
    arm = lp.make_armature("rig_" + cid, _ma_bones(h, ((0, -0.44, 0.62), (0, -0.56, 0.64)), ((0, -0.56, 0.64), (0, -0.86, 0.56)),
                                                  ((0, 0.48, 0.66), (0, 0.58, 0.72), (0, 0.65, 0.64)), legs))
    coat = _ma_mat("tint", _WB_COAT, 0.85, force=True)
    bristle = _ma_mat("tint2", _WB_BRISTLE, 0.85, force=True)
    light = _ma_mat("m_wb_light", _WB_LIGHT, 0.85)
    dark = _ma_mat("m_wb_dark", _WB_DARK, 0.6)
    ivory = _ma_mat("m_wb_ivory", _WB_IVORY, 0.5)
    nose = _ma_mat("m_wb_nose", _WB_NOSE, 0.7)
    leather = _ma_mat("m_wb_saddle", _WB_LEATHER, 0.7)
    blanket = _ma_mat("m_wb_blanket", _WB_BLANKET, 0.8)
    gold = _ma_mat("m_wb_gold", _WB_GOLD, 0.4)
    m_eye, m_white = mk.base_mats()
    parts = []
    # tronco de barril: ombro alto na frente, garupa redonda; barriga clara
    trunk = _ma_sweep("wb_trunk", [(0, 0.5, 0.6), (0, 0.45, 0.6), (0, 0.33, 0.6), (0, 0.12, 0.6), (0, -0.1, 0.605), (0, -0.3, 0.63), (0, -0.44, 0.62), (0, -0.54, 0.6), (0, -0.59, 0.6)],
                      [(0.05, 0.06), (0.15, 0.18), (0.205, 0.235), (0.215, 0.245), (0.21, 0.25), (0.205, 0.28), (0.19, 0.255), (0.13, 0.17), (0.04, 0.05)], coat, 14)      # ombro estreito: o escudo alto do cavaleiro desce rente (shield_ride_solve)
    parts.append((trunk, "body"))
    parts.append((blob("wb_belly", 0.17, (0, 0.0, 0.43), light, (1.0, 1.9, 0.55), 2), "body"))
    tops = []
    for bone, (top, knee, foot) in legs.items():
        top, knee, foot = V(top), V(knee), V(foot)
        front = _MA_LEG_SIDES[bone][0]
        sh = blob("wb_shoulder_" + bone, 0.115, top + V((0, 0.0, 0.03)), coat, (0.82, 1.05, 1.3), 2)
        tops.append(sh)
        parts.append((sh, bone))
        tops.append(ck.tube("wb_arm_" + bone, top, knee, 0.085, 0.06, coat, 8))
        parts.append((tops[-1], bone))
        parts.append((blob("wb_knee_" + bone, 0.062, knee, coat, cuts=2), bone + "_lo"))
        parts.append((ck.tube("wb_shin_" + bone, knee, foot + V((0, 0, 0.07)), 0.056, 0.05, coat, 8), bone + "_lo"))
        parts.append((ck.tube("wb_hoof_" + bone, foot + V((0, -0.005, 0.085)), foot + V((0, -0.01, 0.004)), 0.056, 0.07, dark, 8), bone + "_lo"))
    # cabeça grande (chibi): crânio, bochechas, focinho de tubo com disco rosa, presas, orelhas, olhos grandes
    hc = V((0, -0.65, 0.63))
    skull = blob("wb_skull", 0.2, hc, coat, (1.0, 1.05, 0.95))
    snout = _ma_sweep("wb_snout", [hc + V((0, -0.08, -0.04)), hc + V((0, -0.2, -0.07)), hc + V((0, -0.3, -0.1))], [(0.125, 0.115), (0.105, 0.095), (0.088, 0.08)], coat, 10)
    parts += [(skull, "head"), (snout, "head")]
    parts.append((blob("wb_disc", 0.082, hc + V((0, -0.305, -0.1)), nose, (1.0, 0.35, 0.92), 2), "head"))
    parts.append((blob("wb_chin", 0.1, hc + V((0, -0.14, -0.13)), light, (0.95, 1.3, 0.55), 2), "head"))
    for sx in (-1, 1):
        parts.append((blob("wb_cheek%d" % sx, 0.1, hc + V((sx * 0.14, -0.03, -0.09)), light, (0.75, 1.0, 0.9), 2), "head"))
        parts.append((ck.tube("wb_jowl%d" % sx, hc + V((sx * 0.15, 0.0, -0.09)), hc + V((sx * 0.235, 0.06, -0.15)), 0.07, 0.035, light, 6), "head"))
        parts.append((_ma_stud("wb_nostril%d" % sx, hc + V((sx * 0.03, -0.335, -0.095)), 0.014, dark, (1, 0.6, 1.3)), "head"))
        parts.append((_ma_sweep("wb_tusk%d" % sx, [hc + V((sx * 0.085, -0.19, -0.13)), hc + V((sx * 0.135, -0.23, -0.1)), hc + V((sx * 0.155, -0.24, -0.03)), hc + V((sx * 0.145, -0.23, 0.04))],
                                [0.03, 0.028, 0.02, 0.005], ivory, 6), "head"))
        parts.append((ck.tube("wb_ear%d" % sx, hc + V((sx * 0.12, 0.06, 0.1)), hc + V((sx * 0.235, 0.1, 0.225)), 0.07, 0.03, coat, 6), "head"))
        parts.append((ck.tube("wb_earin%d" % sx, hc + V((sx * 0.14, 0.035, 0.125)), hc + V((sx * 0.225, 0.07, 0.21)), 0.042, 0.018, nose, 5), "head"))
    parts += [(o, "head") for o in mk.eyes("wb", [hc + V((sx * 0.115, -0.16, 0.055)) for sx in (-1, 1)], 0.042, m_eye, m_white)]
    # crista de cerdas (2ª tinta): da testa ao ombro, baixa, parando antes da sela
    parts.append((ck.tube("wb_crest_h", hc + V((0, -0.04, 0.15)), hc + V((0, 0.04, 0.28)), 0.075, 0.03, bristle, 6), "head"))
    for k, y in enumerate((-0.52, -0.42, -0.32)):
        z0 = 0.83 + (0.045 if k else 0.0)
        parts.append((ck.tube("wb_crest%d" % k, (0, y, z0), (0, y + 0.07, z0 + 0.13 - 0.02 * k), 0.07, 0.03, bristle, 6), "body"))
    # rabinho enrolado com tufo
    parts.append((_ma_sweep("wb_tail", [(0, 0.46, 0.66), (0, 0.53, 0.71), (0, 0.585, 0.725)], [0.03, 0.024, 0.02], coat, 6), "tail"))
    parts.append((_ma_sweep("wb_tail2", [(0, 0.575, 0.725), (0.03, 0.63, 0.71), (0.0, 0.66, 0.66)], [0.02, 0.018, 0.016], coat, 6), "tail2"))
    parts.append((blob("wb_tuft", 0.04, (0, 0.665, 0.63), bristle, (0.8, 0.8, 1.3), 2), "tail2"))
    # sela, manta, freio e rédeas
    bvh = _ma_bvh([trunk])
    _ma_saddle("wb_", parts, bvh, h, leather, blanket, gold, wide=1.2, girth=0.23, cloth=(-0.24, 0.22, 78.0))
    parts += [(o, "head") for o in _ma_arc("wb_noseband", hc + V((0, -0.2, -0.07)), (0.112, 0.102), -150, 150, 0.011, leather, 8, 4)]
    parts += [(o, "head") for o in _ma_arc("wb_brow", hc + V((0, -0.02, 0.0)), (0.205, 0.195), -62, 62, 0.011, leather, 6, 4)]
    _ma_reins("wb_", parts, [(0.115, hc.y - 0.2, hc.z - 0.1), (0.2, -0.5, 0.79), (0.09, -0.3, 0.935)], leather, gold, h)
    # ---- bardas
    bard = _MaBard()
    iron, iron_d = _ma_iron("wb"), dark
    body_bvh = _ma_bvh([trunk] + tops)
    head_bvh = _ma_bvh([skull, snout])
    _ma_chanfron(bard, "wb_", head_bvh, hc + V((0, 0.08, 0.02)), hc + V((0, -0.3, -0.09)), 46, 40, iron, iron_d, gold, spike=(0, -0.05, 0.11))
    _ma_peytral(bard, "wb_", body_bvh, -0.54, -0.25, 0.6, 34, 178, 112, iron, iron_d, gold)
    _ma_crupper(bard, "wb_", body_bvh, 0.23, 0.47, 0.6, 106, 94, iron, iron_d, gold)
    _wb_barding(bard, hc, body_bvh, head_bvh, gold)
    parts += bard.parts()
    _ma_finish(arm, parts)
    _ma_clips(arm, {
        "legs": _MA_LEG_SIDES,
        "idle": {"neck_p": 3.0, "neck_p0": 1.0, "neck_y": 2.0, "head_p": 5.0, "head_f": 2, "head_y": 3.0, "tail_y": 24.0, "tail2_y": 30.0, "tail_f": 5, "breath": 0.007},
        "walk": (28, _MA_WALK, 0.62, 17.0, 45.0, 0.01, 2.0, 4.0),
        "run": (14, _MA_GALLOP, 0.4, 30.0, 80.0, 0.04, 5.5, 6.0),
        "run_neck": 4.0, "run_head": -2.0, "run_tail": 30.0, "drop": {"walk": 0.02},
    })
    return arm


def _wb_barding(bard, hc, body_bvh, head_bvh, gold):
    """Barda do Javali Ancestral: pele musguenta nos ombros e na garupa (cogumelos, costura de osso) e guardas nas presas."""
    V = Vector
    hide = _ma_mat("m_wb_hide", _WB_HIDE, 0.9)
    moss = _ma_mat("m_wb_moss", _WB_MOSS, 0.9)
    ivory = _ma_mat("m_wb_ivory", _WB_IVORY, 0.5)
    rnd = random.Random(7)
    body = []
    # ombros: duas abas (a crista passa no meio e o alto do ombro fica livre: é por onde o escudo alto do cavaleiro desce);
    # garupa: uma pele inteira com almofadas de musgo e cogumelos
    wave = lambda t, k: k * math.cos(t * math.pi * 3)
    specs = [("sh%d" % sx, -0.54, -0.25, (lambda t, sx=sx: (sx * 32.0, sx * (82.0 + wave(t, 8.0)))), 5,
              ((1, 2, 0.06), (2, 4, 0.065), (3, 1, 0.05), (3, 3, 0.04)), ((0, 0), (4, 0), (0, 5), (2, 5), (4, 5)), ()) for sx in (-1, 1)]
    specs.append(("ru", 0.23, 0.47, (lambda t: (-(100.0 + wave(t, 9.0)), 100.0 + wave(t, 9.0))), 10,
                  ((1, 4, 0.075), (2, 6, 0.08), (3, 4, 0.06), (1, 7, 0.055), (3, 7, 0.05), (2, 3, 0.05)),
                  ((0, 0), (2, 0), (4, 0), (0, 10), (2, 10), (4, 10), (0, 5), (4, 5)), ((2, 4), (1, 6), (3, 6))))
    for tag, y0, y1, span, na, pads, toggles, shrooms in specs:
        pl, grid, nrm = _ma_plate("wb_hide_" + tag, body_bvh, (0, y0, 0.6), (0, y1, 0.6), span, hide, off=0.024 if tag == "ru" else 0.018, nt=4, na=na, skirt=0.028)
        body.append(pl)
        for k, (i, j, r) in enumerate(pads):                  # almofadas de musgo
            body.append(_ma_pad("wb_moss_%s%d" % (tag, k), grid[i][j] + nrm[i][j] * 0.002, nrm[i][j], r, moss, 0.4 if tag == "ru" else 0.1))      # ombro: musgo raso
        for k, (i, j) in enumerate(toggles):                  # botões de osso
            body.append(_ma_flat(_ma_stud("wb_toggle_%s%d" % (tag, k), grid[i][j] + nrm[i][j] * 0.004, 0.017, ivory)))
        for k, (i, j) in enumerate(shrooms):                  # cogumelinhos
            p, n = grid[i][j], nrm[i][j]
            s = rnd.uniform(0.85, 1.15)
            body.append(ck.tube("wb_stem_%s%d" % (tag, k), p, p + n * 0.05 * s, 0.012, 0.01, ivory, 5))
            body.append(_ma_stud("wb_cap_%s%d" % (tag, k), p + n * 0.055 * s, 0.03 * s, gold, (1, 1, 0.6), 1))
    bard.add("barding_war_boar_body", "body", body)
    head = []
    for sx in (-1, 1):                    # guardas das presas: luva de couro com dois aros dourados e ponteira
        pts = [hc + V((sx * 0.085, -0.19, -0.13)), hc + V((sx * 0.135, -0.23, -0.1)), hc + V((sx * 0.155, -0.24, -0.03)), hc + V((sx * 0.145, -0.23, 0.04))]
        head.append(_ma_sweep("wb_guard%d" % sx, [pts[0].lerp(pts[1], 0.35), pts[1], pts[2].lerp(pts[1], 0.25)], [0.04, 0.038, 0.031], hide, 6))
        head.append(ck.tube("wb_guard_ring%da" % sx, pts[0].lerp(pts[1], 0.3), pts[0].lerp(pts[1], 0.55), 0.046, 0.045, gold, 6))
        head.append(ck.tube("wb_guard_ring%db" % sx, pts[2].lerp(pts[1], 0.45), pts[2].lerp(pts[1], 0.2), 0.039, 0.036, gold, 6))
        head.append(_ma_flat(mk.cone("wb_guard_tip%d" % sx, pts[2].lerp(pts[3], 0.55), pts[3] + (pts[3] - pts[2]) * 0.5, 0.017, gold, 5)))
    pl, grid, nrm = _ma_plate("wb_hide_brow", head_bvh, hc + V((0, 0.1, 0.02)), hc + V((0, -0.1, 0.0)), lambda t: (-50 + 8 * t, 50 - 8 * t), hide, off=0.022, nt=2, na=6, skirt=0.022)
    head.append(pl)
    head.append(_ma_pad("wb_moss_brow", grid[1][3] + nrm[1][3] * 0.004, nrm[1][3], 0.07, moss))
    head += [_ma_flat(_ma_stud("wb_toggle_brow%d" % k, grid[i][j] + nrm[i][j] * 0.004, 0.016, ivory)) for k, (i, j) in enumerate(((2, 0), (2, 6), (0, 0), (0, 6)))]
    bard.add("barding_war_boar_head", "head", head)


# ---------------------------------------------------------------------------
# Alce do Bosque (primo manso do Alce Ancião): pernas finas, pescoço erguido, gola de pelo (tint2), galhada
# ---------------------------------------------------------------------------
_FE_COAT = (0.62, 0.47, 0.33)
_FE_RUFF = (0.9, 0.84, 0.7)
_FE_LIGHT = (0.95, 0.9, 0.78)
_FE_DARK = (0.24, 0.19, 0.17)
_FE_ANTLER = (0.9, 0.82, 0.66)
_FE_LEATHER = (0.4, 0.26, 0.16)
_FE_BLANKET = (0.26, 0.46, 0.5)
_FE_GOLD = (0.88, 0.78, 0.48)
_FE_CRYSTAL = (0.5, 0.92, 0.88)
_FE_RIBBON = (0.62, 0.86, 0.56)


def _fe_antler(hc, sx):
    """Pontos da galhada de um lado: (haste, [galhos])."""
    V = Vector
    beam = [hc + V((sx * 0.05, 0.03, 0.08)), hc + V((sx * 0.13, 0.09, 0.2)), hc + V((sx * 0.23, 0.13, 0.29)), hc + V((sx * 0.3, 0.1, 0.4))]
    tines = [(hc + V((sx * 0.06, 0.02, 0.1)), hc + V((sx * 0.1, -0.11, 0.2))),            # galho da testa
             (beam[1], hc + V((sx * 0.16, -0.02, 0.33))),
             (beam[2], hc + V((sx * 0.35, 0.16, 0.34))),
             (beam[2], hc + V((sx * 0.21, 0.04, 0.42)))]
    return beam, tines


def _fe_mount(cid="mob_mount_forest_elk"):
    h = mk.HIP
    V = Vector
    blob = mk.blob
    legs = {}
    for bone, (x, yt, yk, zk, yh, _front) in mk.HORSE_LEGS.items():
        legs[bone] = ((x, yt, h + 0.02), (x, yk, zk), (x, yh, 0.0))
    arm = lp.make_armature("rig_" + cid, _ma_bones(h, ((0, -0.42, h + 0.18), (0, -0.55, h + 0.56)), ((0, -0.55, h + 0.56), (0, -0.84, h + 0.5)),
                                                  ((0, 0.47, h + 0.17), (0, 0.55, h + 0.14), (0, 0.6, h + 0.02)), legs))
    coat = _ma_mat("tint", _FE_COAT, 0.85, force=True)
    ruff = _ma_mat("tint2", _FE_RUFF, 0.85, force=True)
    light = _ma_mat("m_fe_light", _FE_LIGHT, 0.85)
    dark = _ma_mat("m_fe_dark", _FE_DARK, 0.6)
    antler = _ma_mat("m_fe_antler", _FE_ANTLER, 0.6)
    leather = _ma_mat("m_fe_saddle", _FE_LEATHER, 0.7)
    blanket = _ma_mat("m_fe_blanket", _FE_BLANKET, 0.8)
    gold = _ma_mat("m_fe_gold", _FE_GOLD, 0.4)
    m_eye, m_white = mk.base_mats()
    parts = []
    trunk = _ma_sweep("fe_trunk", [(0, 0.5, h + 0.1), (0, 0.45, h + 0.1), (0, 0.31, h + 0.1), (0, 0.05, h + 0.095), (0, -0.2, h + 0.1), (0, -0.36, h + 0.12), (0, -0.46, h + 0.13), (0, -0.5, h + 0.13)],
                      [(0.04, 0.05), (0.11, 0.14), (0.15, 0.185), (0.155, 0.19), (0.16, 0.2), (0.15, 0.2), (0.1, 0.14), (0.03, 0.04)], coat, 14)
    parts.append((trunk, "body"))
    parts.append((blob("fe_belly", 0.14, (0, 0.0, h - 0.04), light, (0.85, 2.1, 0.55), 2), "body"))
    parts.append((blob("fe_rump_patch", 0.13, (0, 0.43, h + 0.08), light, (0.95, 0.45, 1.1), 1), "body"))
    tops = []
    for bone, (top, knee, foot) in legs.items():
        top, knee, foot = V(top), V(knee), V(foot)
        front = _MA_LEG_SIDES[bone][0]
        fet = V((foot.x, foot.y, 0.09))
        if front:
            sh = blob("fe_shoulder_" + bone, 0.085, top + V((0, 0, -0.03)), coat, (0.8, 1.0, 1.35), 2)
            parts.append((ck.tube("fe_arm_" + bone, top, knee, 0.068, 0.04, coat, 6), bone))
        else:
            sh = blob("fe_haunch_" + bone, 0.118, top + V((0, -0.02, -0.05)), coat, (0.75, 1.1, 1.3), 2)
            parts.append((ck.tube("fe_gaskin_" + bone, top + V((0, 0, -0.08)), knee, 0.075, 0.038, coat, 6), bone))
        tops.append(sh)
        parts.append((sh, bone))
        parts.append((blob("fe_knee_" + bone, 0.043, knee, coat, cuts=1), bone + "_lo"))
        parts.append((ck.tube("fe_cannon_" + bone, knee, fet, 0.035, 0.03, light, 6), bone + "_lo"))
        parts.append((ck.tube("fe_hoof_" + bone, fet + V((0, 0, 0.005)), foot + V((0, -0.008, 0.004)), 0.036, 0.05, dark, 6), bone + "_lo"))
    # pescoço erguido com gola de pelo claro (2ª tinta) no peito
    n0, n1 = V((0, -0.4, h + 0.14)), V((0, -0.56, h + 0.56))
    neck = _ma_sweep("fe_neck", [n0 + V((0, 0.05, -0.08)), n0, n0.lerp(n1, 0.5), n1, n1 + V((0, -0.03, 0.05))], [(0.1, 0.12), (0.125, 0.15), (0.095, 0.11), (0.08, 0.085), (0.05, 0.05)], coat, 10)
    parts.append((neck, "neck"))
    parts.append((blob("fe_ruff0", 0.13, (0, -0.47, h + 0.16), ruff, (0.95, 0.85, 1.15), 2), "neck"))
    for k, (x, t, ln) in enumerate(((0, 0.12, 0.17), (-0.07, 0.22, 0.15), (0.07, 0.22, 0.15), (0, 0.4, 0.14), (0, 0.58, 0.1))):
        p = n0.lerp(n1, t) + V((x, -0.1 + 0.02 * t, -0.02))
        parts.append((blob("fe_ruff%d" % (k + 1), 0.062 + ln * 0.12, p + V((0, 0.035, 0.0)), ruff, (1.0, 0.85, 1.35), 2), "neck"))
    # cabeça de cervo: focinho comprido, nariz escuro, orelhas grandes para os lados, olhos grandes
    hc = V((0, -0.64, h + 0.6))
    skull = blob("fe_skull", 0.125, hc, coat, (0.9, 1.05, 0.95))
    muzzle = _ma_sweep("fe_muzzle", [hc + V((0, -0.05, -0.02)), hc + V((0, -0.19, -0.065)), hc + V((0, -0.29, -0.1))], [(0.1, 0.096), (0.074, 0.066), (0.058, 0.05)], coat, 10)
    parts += [(skull, "head"), (muzzle, "head")]
    parts.append((blob("fe_nose", 0.04, hc + V((0, -0.3, -0.085)), dark, (1.1, 0.7, 0.85), 2), "head"))
    parts.append((blob("fe_chin", 0.05, hc + V((0, -0.22, -0.11)), light, (0.9, 1.5, 0.5), 2), "head"))
    for sx in (-1, 1):
        parts.append((blob("fe_ear%d" % sx, 0.05, hc + V((sx * 0.155, 0.075, 0.065)), coat, (1.7, 0.5, 0.85), 2), "head"))
        parts.append((blob("fe_earin%d" % sx, 0.03, hc + V((sx * 0.165, 0.058, 0.065)), light, (1.7, 0.5, 0.8), 1), "head"))
        beam, tines = _fe_antler(hc, sx)
        parts.append((_ma_sweep("fe_beam%d" % sx, beam, [0.03, 0.026, 0.022, 0.008], antler, 6), "head"))
        for k, (a, b_) in enumerate(tines):
            parts.append((ck.tube("fe_tine%d_%d" % (sx, k), a, b_, 0.021, 0.006, antler, 5), "head"))
    parts += [(o, "head") for o in mk.eyes("fe", [hc + V((sx * 0.099, -0.055, 0.025)) for sx in (-1, 1)], 0.04, m_eye, m_white)]
    # rabinho: toco com o avesso branco
    parts.append((ck.tube("fe_tail", (0, 0.46, h + 0.17), (0, 0.55, h + 0.14), 0.045, 0.04, coat, 8), "tail"))
    parts.append((blob("fe_tail2", 0.05, (0, 0.575, h + 0.08), light, (0.8, 0.75, 1.5), 2), "tail2"))
    # sela, manta, cabresto e rédeas
    bvh = _ma_bvh([trunk])
    _ma_saddle("fe_", parts, bvh, h, leather, blanket, gold)
    parts += [(o, "head") for o in _ma_arc("fe_noseband", hc + V((0, -0.17, -0.058)), (0.082, 0.074), -160, 160, 0.009, leather, 8, 4)]
    parts += [(o, "head") for o in _ma_arc("fe_brow", hc + V((0, -0.03, 0.0)), (0.119, 0.122), -70, 70, 0.009, leather, 6, 4)]
    _ma_reins("fe_", parts, [(0.075, hc.y - 0.2, hc.z - 0.085), (0.145, -0.42, h + 0.3)], leather, gold, h)
    # ---- bardas
    bard = _MaBard()
    iron, iron_d = _ma_iron("fe"), dark
    body_bvh = _ma_bvh([trunk] + tops)
    head_bvh = _ma_bvh([skull, muzzle])
    _ma_chanfron(bard, "fe_", head_bvh, hc + V((0, 0.04, 0.02)), hc + V((0, -0.27, -0.085)), 44, 46, iron, iron_d, gold, off=0.016)
    _ma_peytral(bard, "fe_", body_bvh, -0.47, -0.22, h + 0.1, 46, 178, 118, iron, iron_d, gold)
    _ma_crupper(bard, "fe_", body_bvh, 0.2, 0.47, h + 0.1, 104, 92, iron, iron_d, gold)
    _fe_barding(bard, hc, h, body_bvh, gold)
    parts += bard.parts()
    _ma_finish(arm, parts)
    _ma_clips(arm, {
        "legs": _MA_LEG_SIDES,
        "idle": {"neck_p": 4.0, "neck_p0": 1.0, "neck_y": 3.0, "head_p": -3.0, "head_y": 6.0, "tail_y": 20.0, "tail2_y": 26.0, "tail_f": 4, "rest_leg": "leg_bl"},
        "walk": mk.GAITS["walk"],
        "run": (16, _MA_GALLOP, 0.4, 30.0, 85.0, 0.055, 6.0, 8.0),
        "run_neck": 10.0, "run_head": -8.0, "run_tail": 35.0, "drop": {"walk": 0.02},
    })
    return arm


def _fe_barding(bard, hc, h, body_bvh, gold):
    """Barda do Alce Ancião: ponteiras de cristal na galhada, fitas élficas, diadema; gola de folhas e manta de fitas na garupa."""
    V = Vector
    crystal = _ma_mat("m_fe_crystal", _FE_CRYSTAL, 0.3, 0.6)
    ribbon = _ma_mat("m_fe_ribbon", _FE_RIBBON, 0.8)
    head = []
    for sx in (-1, 1):
        beam, tines = _fe_antler(hc, sx)
        tips = [(beam[2], beam[3])] + tines
        for k, (a, b_) in enumerate(tips):
            d = (b_ - a).normalized()
            head.append(_ma_flat(_ma_crystal("fe_cap%d_%d" % (sx, k), b_ - d * 0.035, b_ + d * 0.075, 0.026, crystal)))
            head.append(ck.tube("fe_capring%d_%d" % (sx, k), b_ - d * 0.05, b_ - d * 0.025, 0.017, 0.019, gold, 5))
        for k, (p, drop, ph, dx) in enumerate(((beam[0], 0.3, 0.0, -0.012), (beam[0].lerp(beam[1], 0.45), 0.22, 1.3, -0.02))):   # fitas no pé da haste, caindo junto do pescoço
            head.append(ck.tube("fe_knot%d_%d" % (sx, k), p - V((0, 0.012, 0.012)), p + V((0, 0.012, 0.012)), 0.038, 0.038, ribbon, 6))
            pts = [p + V((sx * (dx * i + 0.01 * math.sin(ph + i * 1.4)), 0.05 + 0.03 * i + 0.012 * math.sin(ph + i * 1.9), -drop * i / 4.0)) for i in range(5)]
            head.append(_ma_ribbon("fe_ribbon%d_%d" % (sx, k), pts, 0.045, ribbon, (1, 0.25, 0), taper=0.55))
    head += _ma_arc("fe_circlet", hc + V((0, -0.035, 0.0)), (0.124, 0.13), -58, 58, 0.012, gold, 6, 4)
    head.append(_ma_flat(_ma_crystal("fe_gem", hc + V((0, -0.07, 0.11)), hc + V((0, -0.11, 0.21)), 0.03, crystal)))
    bard.add("barding_forest_elk_head", "head", head)
    body = []
    # gola de folhas no peito (duas fiadas) e broche de cristal
    for sx in (-1, 1):
        span = lambda t, sx=sx: (sx * 30, sx * (150 - 30 * t))
        pl, grid, nrm = _ma_plate("fe_collar%d" % sx, body_bvh, (0, -0.47, h + 0.1), (0, -0.3, h + 0.1), span, ribbon, off=0.02, nt=2, na=6, skirt=0.02)
        body.append(pl)
        for q, j in enumerate((1, 3, 5)):     # contas de cristal na gola
            body.append(_ma_flat(_ma_stud("fe_bead%d_%d" % (sx, q), grid[1][j] + nrm[1][j] * 0.004, 0.02, crystal, (1, 1, 1))))
        for j in range(6):
            body.append(ck.tube("fe_collar_rim%d_%d" % (sx, j), grid[0][j] + nrm[0][j] * 0.003, grid[0][j + 1] + nrm[0][j + 1] * 0.003, 0.011, 0.011, gold, 3))
    body.append(_ma_flat(_ma_crystal("fe_brooch", (0, -0.5, h - 0.02), (0, -0.56, h - 0.1), 0.035, crystal)))
    # manta de garupa em pontas de folha, com fitas soltas atrás da sela
    span = lambda t: (-(92 + 14 * math.cos(t * math.pi * 4)), 92 + 14 * math.cos(t * math.pi * 4))
    pl, grid, nrm = _ma_plate("fe_drape", body_bvh, (0, 0.2, h + 0.1), (0, 0.46, h + 0.1), span, ribbon, off=0.02, nt=4, na=10, skirt=0.018)
    body.append(pl)
    for j in range(10):
        body.append(ck.tube("fe_drape_rim%d" % j, grid[0][j] + nrm[0][j] * 0.003, grid[0][j + 1] + nrm[0][j + 1] * 0.003, 0.011, 0.011, gold, 3))
    for k, (i, j) in enumerate(((0, 0), (2, 0), (4, 0), (0, 10), (2, 10), (4, 10))):
        p, n = grid[i][j], nrm[i][j]
        body.append(_ma_flat(_ma_crystal("fe_drop%d" % k, p + n * 0.004, p + n * 0.004 + V((0, 0, -0.07)), 0.02, crystal)))
    for k, (i, j) in enumerate(((2, 5), (1, 3), (1, 7), (3, 3), (3, 7))):
        body.append(_ma_flat(_ma_stud("fe_drape_stud%d" % k, grid[i][j] + nrm[i][j] * 0.003, 0.018, gold, (1, 1, 0.5))))
    for sx in (-1, 1):
        p = grid[0][5 + sx * 3] + nrm[0][5 + sx * 3] * 0.01
        pts = [p + V((sx * (0.02 * i + 0.01 * math.sin(i * 1.7)), 0.035 * i, -0.075 * i + 0.01 * math.sin(i * 2.3))) for i in range(5)]
        body.append(_ma_ribbon("fe_stream%d" % sx, pts, 0.05, ribbon, (0, 1, 0), taper=0.5))
    bard.add("barding_forest_elk_body", "body", body)


# ---------------------------------------------------------------------------
# Lagarto das Ruínas (primo manso do Basilisco das Ruínas): pernas abertas, rabo comprido, placas no dorso (tint2)
# ---------------------------------------------------------------------------
_RL_SCALE = (0.44, 0.56, 0.54)
_RL_PLATE = (0.3, 0.38, 0.44)
_RL_BELLY = (0.86, 0.84, 0.7)
_RL_DARK = (0.2, 0.2, 0.22)
_RL_EYE = (0.98, 0.82, 0.36)
_RL_LEATHER = (0.36, 0.25, 0.18)
_RL_BLANKET = (0.72, 0.42, 0.22)
_RL_GOLD = (0.86, 0.72, 0.4)
_RL_STONE = (0.82, 0.76, 0.62)
_RL_RUNE = (0.36, 0.84, 0.86)


def _rl_mount(cid="mob_mount_ruins_lizard"):
    h = mk.HIP
    V = Vector
    blob = mk.blob
    legs = {}
    for bone, (front, sx) in _MA_LEG_SIDES.items():
        if front:
            legs[bone] = ((sx * 0.16, -0.36, 0.55), (sx * 0.31, -0.33, 0.33), (sx * 0.3, -0.4, 0.0))
        else:
            legs[bone] = ((sx * 0.16, 0.38, 0.55), (sx * 0.32, 0.34, 0.33), (sx * 0.31, 0.42, 0.0))
    arm = lp.make_armature("rig_" + cid, _ma_bones(h, ((0, -0.48, 0.68), (0, -0.66, 0.8)), ((0, -0.66, 0.8), (0, -0.98, 0.77)),
                                                  ((0, 0.55, 0.6), (0, 0.95, 0.43), (0, 1.42, 0.2)), legs))
    scale = _ma_mat("tint", _RL_SCALE, 0.8, force=True)
    plate = _ma_mat("tint2", _RL_PLATE, 0.8, force=True)
    belly = _ma_mat("m_rl_belly", _RL_BELLY, 0.85)
    dark = _ma_mat("m_rl_dark", _RL_DARK, 0.6)
    eye = _ma_mat("m_rl_eye", _RL_EYE, 0.4)
    leather = _ma_mat("m_rl_saddle", _RL_LEATHER, 0.7)
    blanket = _ma_mat("m_rl_blanket", _RL_BLANKET, 0.8)
    gold = _ma_mat("m_rl_gold", _RL_GOLD, 0.4)
    m_eye, m_white = mk.base_mats()
    parts = []
    trunk = _ma_sweep("rl_trunk", [(0, 0.62, 0.6), (0, 0.54, 0.6), (0, 0.37, 0.61), (0, 0.1, 0.63), (0, -0.15, 0.64), (0, -0.36, 0.65), (0, -0.5, 0.66), (0, -0.57, 0.67)],
                      [(0.05, 0.05), (0.14, 0.15), (0.185, 0.2), (0.2, 0.215), (0.2, 0.22), (0.19, 0.21), (0.14, 0.16), (0.05, 0.05)], scale, 14)
    parts.append((trunk, "body"))
    parts.append((blob("rl_belly", 0.17, (0, 0.0, 0.5), belly, (0.98, 2.4, 0.55), 2), "body"))
    tops = []
    for bone, (top, knee, foot) in legs.items():
        top, knee, foot = V(top), V(knee), V(foot)
        front, sx = _MA_LEG_SIDES[bone]
        sh = blob("rl_shoulder_" + bone, 0.11, top + V((sx * 0.02, 0, 0.0)), scale, (1.05, 1.1, 1.0), 2)
        tops.append(sh)
        parts.append((sh, bone))
        tops.append(ck.tube("rl_arm_" + bone, top, knee, 0.09, 0.066, scale, 8))
        parts.append((tops[-1], bone))
        parts.append((blob("rl_elbow_" + bone, 0.07, knee, scale, cuts=2), bone + "_lo"))
        parts.append((ck.tube("rl_shin_" + bone, knee, foot + V((0, 0.0, 0.05)), 0.062, 0.05, scale, 8), bone + "_lo"))
        parts.append((blob("rl_foot_" + bone, 0.075, foot + V((0, -0.035, 0.036)), scale, (1.1, 1.45, 0.48), 2), bone + "_lo"))
        for k in (-1, 0, 1):
            a = foot + V((k * 0.045, -0.1, 0.03))
            parts.append((mk.cone("rl_claw_%s%d" % (bone, k), a, a + V((k * 0.02, -0.075, -0.027)), 0.022, dark, 5), bone + "_lo"))
    # pescoço grosso e curto, papo claro
    neck = _ma_sweep("rl_neck", [(0, -0.42, 0.64), (0, -0.5, 0.68), (0, -0.6, 0.75), (0, -0.7, 0.8)], [(0.14, 0.15), (0.14, 0.15), (0.125, 0.125), (0.1, 0.09)], scale, 10)
    parts.append((neck, "neck"))
    parts.append((blob("rl_throat", 0.11, (0, -0.6, 0.67), belly, (0.9, 1.4, 0.7), 2), "neck"))
    # cabeça em cunha: crânio largo, focinho chato, queixo claro, olhos dourados grandes, coroa de três nós
    hc = V((0, -0.76, 0.83))
    skull = blob("rl_skull", 0.15, hc, scale, (1.05, 1.1, 0.8))
    snout = _ma_sweep("rl_snout", [hc + V((0, -0.06, -0.01)), hc + V((0, -0.2, -0.03)), hc + V((0, -0.31, -0.045)), hc + V((0, -0.35, -0.05))], [(0.14, 0.095), (0.115, 0.075), (0.09, 0.058), (0.05, 0.035)], scale, 10)
    parts += [(skull, "head"), (snout, "head")]
    parts.append((_ma_sweep("rl_jaw", [hc + V((0, 0.0, -0.085)), hc + V((0, -0.18, -0.085)), hc + V((0, -0.32, -0.08))], [(0.12, 0.04), (0.105, 0.035), (0.06, 0.022)], belly, 8), "head"))
    for sx in (-1, 1):
        ec = hc + V((sx * 0.105, -0.07, 0.075))
        parts.append((blob("rl_socket%d" % sx, 0.058, ec + V((0, 0.012, 0.0)), plate, (0.9, 1.0, 1.0), 2), "head"))
        parts.append((blob("rl_eye%d" % sx, 0.047, ec + V((sx * 0.012, -0.012, 0.004)), eye, (0.8, 0.85, 1.0), 2), "head"))
        parts.append((blob("rl_pupil%d" % sx, 0.026, ec + V((sx * 0.03, -0.04, 0.004)), m_eye, (0.6, 0.6, 1.25), 2), "head"))
        parts.append((_ma_stud("rl_hl%d" % sx, ec + V((sx * 0.036, -0.04, 0.026)), 0.011, m_white), "head"))
        parts.append((_ma_stud("rl_nostril%d" % sx, hc + V((sx * 0.035, -0.325, -0.01)), 0.012, dark, (1, 1, 0.7)), "head"))
        parts.append((mk.cone("rl_crown%d" % sx, hc + V((sx * 0.085, 0.07, 0.06)), hc + V((sx * 0.13, 0.17, 0.13)), 0.04, plate, 5), "head"))
    parts.append((mk.cone("rl_crown0", hc + V((0, 0.08, 0.08)), hc + V((0, 0.19, 0.17)), 0.045, plate, 5), "head"))
    # placas do dorso (2ª tinta): nuca, garupa e rabo; o lugar da sela fica livre
    for k, (y, zt, s) in enumerate(((-0.52, 0.83, 0.8), (-0.4, 0.855, 0.95), (0.36, 0.8, 0.95), (0.48, 0.745, 0.85))):
        parts.append((ck.blade("rl_fin%d" % k, (0, y - 0.01, zt - 0.03), (0, y + 0.05 * s, zt + 0.09 * s), 0.11 * s, 0.035, plate, (0, 1, 0), 0.4), "body"))
    # rabo comprido em dois ossos
    parts.append((_ma_sweep("rl_tail", [(0, 0.48, 0.6), (0, 0.62, 0.575), (0, 0.8, 0.5), (0, 0.96, 0.425)], [(0.15, 0.16), (0.135, 0.135), (0.11, 0.105), (0.088, 0.082)], scale, 10), "tail"))
    parts.append((_ma_sweep("rl_tail2", [(0, 0.93, 0.44), (0, 1.1, 0.355), (0, 1.27, 0.275), (0, 1.4, 0.215), (0, 1.47, 0.19)], [(0.084, 0.078), (0.07, 0.064), (0.048, 0.044), (0.028, 0.026), (0.008, 0.008)], scale, 10), "tail2"))
    for k, (y, zt, s, bone) in enumerate(((0.62, 0.7, 0.75, "tail"), (0.76, 0.615, 0.65, "tail"), (0.9, 0.54, 0.55, "tail"), (1.06, 0.435, 0.45, "tail2"), (1.2, 0.36, 0.36, "tail2"))):
        parts.append((ck.blade("rl_tfin%d" % k, (0, y - 0.01, zt - 0.03), (0, y + 0.05 * s, zt + 0.085 * s), 0.11 * s, 0.03, plate, (0, 1, 0), 0.4), bone))
    # sela, manta, cabresto e rédeas
    bvh = _ma_bvh([trunk])
    _ma_saddle("rl_", parts, bvh, h, leather, blanket, gold, wide=1.14, girth=0.21, cloth=(-0.26, 0.24, 80.0))
    parts += [(o, "head") for o in _ma_arc("rl_noseband", hc + V((0, -0.2, -0.045)), (0.122, 0.09), -180, 180, 0.01, leather, 10, 4)]
    _ma_reins("rl_", parts, [(0.125, hc.y - 0.2, hc.z - 0.05), (0.2, -0.5, 0.77), (0.15, -0.3, 0.87)], leather, gold, h)
    # ---- bardas
    bard = _MaBard()
    iron, iron_d = _ma_iron("rl"), dark
    body_bvh = _ma_bvh([trunk] + tops)
    head_bvh = _ma_bvh([skull, snout])
    _ma_chanfron(bard, "rl_", head_bvh, hc + V((0, 0.06, 0.0)), hc + V((0, -0.31, -0.045)), 30, 52, iron, iron_d, gold, off=0.016)
    _ma_peytral(bard, "rl_", body_bvh, -0.55, -0.22, 0.65, 40, 178, 104, iron, iron_d, gold)
    _ma_crupper(bard, "rl_", body_bvh, 0.24, 0.56, 0.61, 104, 92, iron, iron_d, gold)
    _rl_barding(bard, hc, body_bvh, head_bvh)
    parts += bard.parts()
    _ma_finish(arm, parts)
    _ma_clips(arm, {
        "legs": _MA_LEG_SIDES, "gallop": False, "twist": 22.0, "hock": 0.5,
        "sway": {"walk": 4.0, "run": 6.0},
        "idle": {"neck_p": 2.5, "neck_p0": 0.0, "neck_y": 5.0, "head_p": -2.0, "head_y": 8.0, "tail_y": 9.0, "tail2_y": 14.0, "tail_f": 1, "breath": 0.008},
        "walk": (32, _MA_WALK, 0.64, 15.0, 30.0, 0.006, 1.5, 2.5),
        "run": (16, _MA_TROT, 0.5, 26.0, 50.0, 0.018, 2.0, 3.0),
        "drop": {"walk": 0.02, "run": 0.02},
    })
    return arm


def _rl_barding(bard, hc, body_bvh, head_bvh):
    """Barda do Basilisco das Ruínas: lajes de pedra entalhada nos ombros, nas ancas e na testa, com runas de brilho fraco."""
    V = Vector
    stone = _ma_mat("m_rl_stone", _RL_STONE, 0.9)
    rune = _ma_mat("m_rl_rune", _RL_RUNE, 0.5, 0.5)
    glyphs = (                              # traços na grade 4 x 4 de cada laje
        (((1, 1), (3, 1)), ((1, 1), (1, 3)), ((2, 2), (3, 3))),
        (((1, 2), (3, 2)), ((1, 1), (1, 3)), ((3, 1), (3, 3))),
        (((1, 1), (3, 3)), ((1, 3), (2, 2)), ((3, 1), (3, 2))),
    )
    body = []
    k = 0
    for tag, y0, y1, a0, a1 in (("sh", -0.52, -0.25, 22.0, 92.0), ("hip", 0.26, 0.54, 20.0, 90.0)):
        for sx in (-1, 1):
            pl, grid, nrm = _ma_plate("rl_slab_%s%d" % (tag, sx), body_bvh, (0, y0, 0.64), (0, y1, 0.62), lambda t, sx=sx, a0=a0, a1=a1: (sx * a0, sx * a1), stone, off=0.036, nt=4, na=4, skirt=0.04)
            body.append(_ma_flat(pl))
            body += _ma_strokes("rl_rune_%s%d" % (tag, sx), grid, nrm, glyphs[k % 3], 0.011, rune)
            for q, (i, j) in enumerate(((0, 0), (0, 4), (4, 0), (4, 4))):
                body.append(_ma_flat(_ma_stud("rl_peg_%s%d_%d" % (tag, sx, q), grid[i][j] + nrm[i][j] * 0.003, 0.02, stone, (1, 1, 1))))
            k += 1
    # correias que prendem as lajes por cima do dorso
    for q, y in enumerate((-0.44, -0.33, 0.34, 0.46)):
        body += _ma_arc("rl_slab_strap%d" % q, (0, y, 0.64 if y < 0 else 0.615), (0.2, 0.225) if abs(y) < 0.4 else (0.185, 0.21), -30, 30, 0.012, _ma_mat("m_rl_saddle", _RL_LEATHER, 0.7), 4, 4)
    bard.add("barding_ruins_lizard_body", "body", body)
    head = []
    pl, grid, nrm = _ma_plate("rl_slab_brow", head_bvh, hc + V((0, 0.07, 0.0)), hc + V((0, -0.22, -0.03)), lambda t: (-(26 + 6 * t), 26 + 6 * t), stone, off=0.024, nt=4, na=4, skirt=0.03)
    head.append(_ma_flat(pl))
    head += _ma_strokes("rl_rune_brow", grid, nrm, (((1, 2), (3, 2)), ((1, 1), (1, 3)), ((2, 1), (3, 1)), ((2, 3), (3, 3))), 0.009, rune)
    head += [_ma_flat(_ma_stud("rl_peg_brow%d" % q, grid[i][j] + nrm[i][j] * 0.003, 0.016, stone)) for q, (i, j) in enumerate(((0, 0), (0, 4), (4, 0), (4, 4)))]
    bard.add("barding_ruins_lizard_head", "head", head)


# ---------------------------------------------------------------------------
# cavalo: só a barda de ferro (mob_kit.horse chama isto logo antes do finish; o resto do cavalo não muda)
# ---------------------------------------------------------------------------
def horse_barding(parts, h):
    """[(objeto, osso)] dos nós `barding_iron_head/chest/rump` moldados nas peças do cavalo (`parts` de mob_kit.horse)."""
    by = {o.name: o for o, _bone in parts}
    V = Vector
    iron, iron_d = _ma_iron("horse"), ck.mat("m_horse_hoof", (0.2, 0.17, 0.15), 0.6)
    gold = ck.mat("m_saddle_gold", (0.9, 0.7, 0.3), 0.4)
    hc = V((0, -0.67, h + 0.56))
    body_bvh = _ma_bvh([by[n] for n in ("barrel", "chest", "rump") + tuple(k + b for b in ("leg_fr", "leg_fl") for k in ("shoulder_", "arm_")) + tuple(k + b for b in ("leg_br", "leg_bl") for k in ("haunch_", "gaskin_"))])
    head_bvh = _ma_bvh([by[n] for n in ("skull", "snout", "muzzle", "forelock")])
    bard = _MaBard()
    _ma_chanfron(bard, "hb_", head_bvh, hc + V((0, 0.04, 0.02)), hc + V((0, -0.3, -0.1)), 44, 48, iron, iron_d, gold, off=0.016)
    _ma_peytral(bard, "hb_", body_bvh, -0.5, -0.24, h + 0.1, 48, 178, 118, iron, iron_d, gold)
    _ma_crupper(bard, "hb_", body_bvh, 0.2, 0.5, h + 0.1, 104, 92, iron, iron_d, gold)
    out = bard.parts()
    for o, _bone in out:                   # o finish do cavalo alisa tudo: os rebites são pequenos, não faz falta
        if "ma_keep_shading" in o:
            del o["ma_keep_shading"]
    return out


BUILDERS.update({
    "mob_mount_war_boar": lambda: _wb_mount(),
    "mob_mount_forest_elk": lambda: _fe_mount(),
    "mob_mount_ruins_lizard": lambda: _rl_mount(),
})
