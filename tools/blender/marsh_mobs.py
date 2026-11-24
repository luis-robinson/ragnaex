"""Bichos do Brejo das Teias (field_marsh, 12-16; GDD design/gdd/brejo-das-teias.md 3.3): Sapo-Boi (`mob_bog_toad`),
Bocarra, a Sapa-Mãe (`mob_bog_mother`, chefe de campo; escala 2,2 no jogo) e a Tecelã do Brejo (`mob_web_weaver`).
Peças rígidas, uma malha por osso (lp.export_glb). Os sapos têm rig próprio de ossos de pé (TOAD_BONES: eixos locais
x = X, y = para cima, z = para a FRENTE do bicho, que é -Y do Blender): giro x positivo = focinho para baixo, loc y = sobe,
loc z = avança. Todo clipe grava TODOS os ossos com escala (osso sem chave herdava a pose/escala do clipe anterior).
A Tecelã usa o rig e os clipes da aranha (bm.MOB_BONES) + `atk_throw`.

    mob_kit.build_all(out, only=set(marsh_mobs.BUILDERS))
    blender -b --factory-startup --python tools/blender/lumeria_mobs_preview.py -- --module=marsh_mobs --out=<pasta absoluta>
        [--only=mob_bog_toad] [--poses=idle:1,run:5,attack:5] [--ground] [--export=<abs assets/models>]
"""
import math

import bpy
from mathutils import Vector

import chibi_kit as ck
import lowpoly_lib as lp
import build_monsters as bm
import mob_kit as mk

TOAD_BONES = {
    "root": ((0, 0, 0), (0, 0, 0.2), None),
    "body": ((0, 0.25, 0.12), (0, 0.25, 0.6), "root"),            # o sapo todo, a partir da anca (empina e mergulha)
    "head": ((0, -0.15, 0.6), (0, -0.15, 0.95), "body"),          # crânio e olhos: abre a boca girando para trás
    "jaw": ((0, -0.15, 0.58), (0, -0.15, 0.88), "body"),          # queixo: abre girando para a frente (x positivo)
    "sac": ((0, -0.6, 0.36), (0, -0.6, 0.6), "jaw"),              # papo: incha (escala)
    "tongue": ((0, -0.3, 0.6), (0, -0.3, 0.8), "body"),           # língua: estica na escala z (frente)
    "sacs": ((0, 0.2, 0.8), (0, 0.2, 1.05), "body"),              # desova nas costas da Sapa-Mãe: pulsa
    "leg_fr": ((0.46, -0.3, 0.4), (0.46, -0.3, 0.7), "body"),
    "leg_fl": ((-0.46, -0.3, 0.4), (-0.46, -0.3, 0.7), "body"),
    "leg_br": ((0.5, 0.38, 0.32), (0.5, 0.38, 0.62), "body"),
    "leg_bl": ((-0.5, 0.38, 0.32), (-0.5, 0.38, 0.62), "body"),
}
Z, ONE = (0, 0, 0), (1, 1, 1)
# quadro do impacto de cada clipe = EntityView.IMPACT_FRAME (o jogo acerta a velocidade do clipe por ele)
IMPACT = {"attack": 5, "atk_throw": 7, "atk_claw": 6, "atk_spin": 8, "atk_charge": 5, "atk_leap": 12, "atk_sweep": 8, "cast_ground": 10,
          "cast_channel": 14, "cast_target": 8, "summon": 11, "shout": 7, "buff_focus": 8, "buff_guard": 6, "cast_fire": 8, "cast_ice": 8,
          "cast_shadow": 8, "cast_nature": 9, "cast_holy": 8, "cast_bolt": 7, "maul": 7, "pounce": 9, "slam": 8, "roar": 7, "brace": 6}
KINDS = {
    "toad": {"back": (0.38, 0.46, 0.24), "wart": (0.25, 0.32, 0.17), "belly": (0.84, 0.81, 0.6), "eye": (0.96, 0.8, 0.28), "fat": 1.0},
    "mother": {"back": (0.31, 0.39, 0.2), "wart": (0.2, 0.26, 0.15), "belly": (0.78, 0.74, 0.52), "eye": (0.98, 0.7, 0.22), "fat": 1.14},
}


class _Parts:
    """Junta as peças de cada osso numa malha só (um draw por osso antes da fusão do jogo)."""

    def __init__(self):
        self.by = {}

    def add(self, obj, bone):
        self.by.setdefault(bone, []).append(obj)
        return obj

    def finish(self, arm, prefix):
        for bone, objs in self.by.items():
            for o in objs:
                ck._smooth(o.data)
            o = lp.join(objs, "%s_%s" % (prefix, bone)) if len(objs) > 1 else objs[0]
            o.name = "%s_%s" % (prefix, bone)
            lp.attach(o, arm, bone)


def _surface(c, r, sc, lon, lat, lift=0.0):
    """Ponto na casca de um elipsoide (centro c, raio r, escala sc): lon em volta de Z a partir da frente, lat para cima."""
    a, b = math.radians(lon), math.radians(lat)
    d = Vector((math.sin(a) * math.cos(b), -math.cos(a) * math.cos(b), math.sin(b)))
    return Vector((c[0] + d.x * r * sc[0], c[1] + d.y * r * sc[1], c[2] + d.z * r * sc[2])) + d * lift


def toad(cid, kind):
    """Sapo gordo (~1,1 m de altura): lombo oliva com verrugas, barriga e papo claros, boca larga (crânio e queixo em ossos
    separados), olhos saltados. `mother` = a Bocarra: mais larga, desova verde-clara nas costas (duas bolhas acesas), musgo e
    taboas na cabeça, o olho esquerdo leitoso."""
    K = KINDS[kind]
    f = K["fat"]
    boss = kind == "mother"
    arm = lp.make_armature("rig_" + cid, TOAD_BONES)
    back = ck.mat("m_%s_back" % cid, K["back"], 0.7)
    wart = ck.mat("m_%s_wart" % cid, K["wart"], 0.8)
    belly = ck.mat("m_%s_belly" % cid, K["belly"], 0.6)
    sacm = ck.mat("m_%s_sac" % cid, tuple(min(1.0, k * 1.06) for k in K["belly"]), 0.45)
    eye = ck.mat("m_%s_eye" % cid, K["eye"], 0.3)
    mouth = ck.mat("m_%s_mouth" % cid, (0.5, 0.17, 0.2), 0.6)
    tongue = ck.mat("m_%s_tongue" % cid, (0.88, 0.45, 0.5), 0.5)
    m_eye, m_white = mk.base_mats()
    P = _Parts()
    blob, tube = mk.blob, ck.tube

    # tronco
    bc, bs = (0, 0.12, 0.45), (1.18 * f, 1.3, 0.8)
    P.add(blob("back", 0.5, bc, back, bs, 4), "body")
    P.add(blob("belly", 0.48, (0, -0.07, 0.31), belly, (1.2 * f, 1.16, 0.6), 3), "body")
    P.add(blob("rump", 0.3, (0, 0.62, 0.34), back, (1.2 * f, 0.9, 0.85), 2), "body")
    warts = [(-150, 38, 0.1), (150, 40, 0.09), (-110, 20, 0.08), (112, 24, 0.1), (180, 55, 0.11), (-170, 22, 0.08), (165, 14, 0.07),
             (-60, 50, 0.08), (62, 48, 0.09), (-128, 58, 0.07), (128, 62, 0.08), (0, 70, 0.07)]
    for i, (lon, lat, r) in enumerate(warts):
        r *= 1.3 if boss else 1.0
        P.add(blob("wart%d" % i, r, _surface(bc, 0.5, bs, lon, lat, -r * 0.35), wart, (1, 1, 0.7), 1), "body")
    for sx in (-1, 1):                                              # listra escura dos lados (lê de cima)
        P.add(blob("stripe%d" % sx, 0.2, _surface(bc, 0.5, bs, 100 * sx, 30, -0.13), wart, (0.5, 1.9, 0.5), 2), "body")

    # cabeça: crânio largo e chato, olhos saltados em cima
    hc, hs = (0, -0.5, 0.73), (1.32 * f, 1.06, 0.5)
    P.add(blob("skull", 0.4, hc, back, hs, 3), "head")
    P.add(blob("lip", 0.4, (0, -0.52, 0.63), wart, (1.3 * f, 1.04, 0.16), 3), "head")       # beiço de cima: risca a boca larga
    for sx in (-1, 1):
        ex = sx * 0.28 * f
        P.add(blob("eyebump%d" % sx, 0.16, (ex, -0.46, 0.92), back, (1.0, 1.05, 0.95), 2), "head")
        cloudy = boss and sx < 0
        P.add(blob("eyeball%d" % sx, 0.125, (ex + sx * 0.035, -0.53, 0.955), ck.mat("m_%s_eye_blind" % cid, (0.78, 0.86, 0.86), 0.25) if cloudy else eye,
                   (1, 1, 1), 2), "head")
        if cloudy:
            P.add(tube("scar", (ex - 0.1, -0.6, 1.07), (ex + 0.02, -0.72, 0.8), 0.022, 0.012, wart, 5), "head")
        else:
            P.add(blob("pupil%d" % sx, 0.07, (ex + sx * 0.075, -0.62, 0.965), m_eye, (0.75, 0.75, 0.45), 1), "head")
            P.add(blob("glint%d" % sx, 0.028, (ex + sx * 0.07, -0.655, 1.0), m_white, (1, 1, 1), 1), "head")
        P.add(blob("nostril%d" % sx, 0.03, (sx * 0.09, -0.905, 0.77), m_eye, (1, 0.6, 0.8), 1), "head")
        P.add(blob("brow%d" % sx, 0.1, (ex, -0.36, 1.03), wart, (1.3, 1.1, 0.4), 1), "head")

    # queixo, céu da boca e papo
    P.add(blob("jaw", 0.4, (0, -0.49, 0.5), belly, (1.27 * f, 1.03, 0.36), 3), "jaw")
    P.add(blob("mouth", 0.36, (0, -0.48, 0.6), mouth, (1.22 * f, 0.98, 0.1), 2), "jaw")
    P.add(blob("throat", 0.21, (0, -0.6, 0.36), sacm, (1.25 * f, 1.05, 0.9), 2), "sac")
    P.add(blob("palate", 0.34, (0, -0.5, 0.64), mouth, (1.2 * f, 1.0, 0.08), 2), "head")

    # língua (guardada na boca; estica pela escala do osso)
    P.add(tube("tongue", (0, -0.3, 0.6), (0, -0.56, 0.6), 0.075, 0.065, tongue, 6), "tongue")
    P.add(blob("tongue_tip", 0.095, (0, -0.58, 0.6), tongue, (1.2, 0.5, 0.8), 1), "tongue")

    # patas da frente: braço curto dobrado, mão espalmada de três dedos
    for sx, bone in ((1, "leg_fr"), (-1, "leg_fl")):
        sh, el, hd = Vector((sx * 0.46 * f, -0.3, 0.4)), Vector((sx * 0.68 * f, -0.4, 0.2)), Vector((sx * 0.62 * f, -0.64, 0.06))
        P.add(tube("arm_a%d" % sx, sh, el, 0.11, 0.085, back, 6), bone)
        P.add(blob("elbow%d" % sx, 0.09, el, back, (1, 1, 1), 1), bone)
        P.add(tube("arm_b%d" % sx, el, hd, 0.085, 0.06, back, 6), bone)
        P.add(blob("hand%d" % sx, 0.1, hd + Vector((0, -0.04, -0.02)), belly, (1.2, 1.3, 0.4), 1), bone)
        for k in (-1, 0, 1):
            tip = hd + Vector((k * 0.1 + sx * 0.03, -0.22 + abs(k) * 0.04, -0.035))
            P.add(tube("finger%d_%d" % (sx, k), hd, tip, 0.035, 0.022, belly, 5), bone)
            P.add(blob("pad%d_%d" % (sx, k), 0.035, tip, belly, (1, 1, 0.6), 1), bone)

    # patas de trás: coxa gorda, canela dobrada para trás, pé comprido de nadadeira
    for sx, bone in ((1, "leg_br"), (-1, "leg_bl")):
        x = sx * f
        P.add(blob("thigh%d" % sx, 0.27, (x * 0.62, 0.26, 0.3), back, (0.85, 1.5, 1.0), 2), bone)
        knee, ankle = Vector((x * 0.7, -0.04, 0.3)), Vector((x * 0.72, 0.44, 0.1))
        P.add(blob("knee%d" % sx, 0.13, knee, back, (1, 1, 1), 1), bone)
        P.add(tube("shin%d" % sx, knee, ankle, 0.12, 0.075, back, 6), bone)
        P.add(blob("foot%d" % sx, 0.15, (x * 0.74, 0.22, 0.05), belly, (0.95, 2.1, 0.3), 2), bone)
        for k in (-1, 0, 1):
            tip = Vector((x * 0.74 + k * 0.13 + sx * 0.05, -0.2 + abs(k) * 0.06, 0.025))
            P.add(tube("toe%d_%d" % (sx, k), (x * 0.74, 0.0, 0.05), tip, 0.04, 0.02, belly, 5), bone)
        P.add(blob("spot%d" % sx, 0.1, (x * 0.8, 0.26, 0.5), wart, (0.6, 1.2, 0.5), 1), bone)

    if boss:
        # desova: cacho de bolhas verde-claras nas costas (duas acesas, fracas), cada uma com o girino escuro dentro
        eggm = ck.mat("m_%s_egg" % cid, (0.72, 0.86, 0.62), 0.3)
        eggg = ck.mat("glow_%s_egg" % cid, (0.78, 0.95, 0.6), 0.3, 1.25)
        eggs = [(175, 62, 0.2), (-150, 50, 0.17), (150, 48, 0.18), (180, 36, 0.19), (-125, 34, 0.15), (128, 30, 0.16), (-165, 22, 0.14),
                (165, 20, 0.15), (-100, 52, 0.13), (100, 56, 0.14), (-175, 78, 0.15)]
        for i, (lon, lat, r) in enumerate(eggs):
            p = _surface(bc, 0.5, bs, lon, lat, r * 0.35)
            P.add(blob("egg%d" % i, r, p, eggg if i in (0, 3) else eggm, (1, 1, 0.95), 2), "sacs")
            P.add(blob("tad%d" % i, r * 0.32, p + Vector((0.0, 0.0, r * 0.55)), wart, (1.0, 1.4, 0.5), 1), "sacs")
        # musgo e taboas na cabeça
        moss = ck.mat("m_%s_moss" % cid, (0.3, 0.46, 0.24), 0.9)
        moss2 = ck.mat("m_%s_moss2" % cid, (0.4, 0.54, 0.27), 0.9)
        reed = ck.mat("m_%s_reed" % cid, (0.36, 0.25, 0.16), 0.8)
        P.add(blob("moss", 0.2, (0, -0.4, 0.93), moss, (1.5, 1.2, 0.35), 2), "head")
        P.add(blob("moss_b", 0.12, (0.1, -0.62, 0.9), moss2, (1.4, 1.0, 0.4), 1), "head")
        P.add(blob("moss_c", 0.13, (-0.5, -0.3, 0.78), moss2, (1.0, 1.3, 0.5), 1), "head")
        for i, (x, y, h, lean) in enumerate(((0.02, -0.36, 0.5, 0.1), (-0.1, -0.42, 0.4, -0.06), (0.12, -0.44, 0.36, 0.16), (-0.03, -0.3, 0.44, -0.12))):
            a, b = Vector((x, y, 0.95)), Vector((x + lean, y + 0.12, 0.95 + h))
            P.add(tube("reed%d" % i, a, b, 0.022, 0.012, moss2, 5), "head")
            if i < 2:
                P.add(tube("cattail%d" % i, b - Vector((lean, 0.12, h)) * 0.3, b, 0.04, 0.035, reed, 6), "head")
        for sx in (-1, 1):                                          # beiço de baixo caído e duas presas rombudas
            P.add(blob("lip_low%d" % sx, 0.1, (sx * 0.34, -0.8, 0.56), belly, (1.5, 0.8, 0.6), 1), "jaw")
            P.add(mk.cone("tusk%d" % sx, (sx * 0.2, -0.86, 0.6), (sx * 0.19, -0.9, 0.72), 0.035, m_white, 5), "jaw")
    P.finish(arm, cid.replace("mob_", ""))
    (_mother_clips if boss else _toad_clips)(arm)
    _plant(arm)
    return arm


# ---------------------------------------------------------------------------------------------------------------
# clipes
# ---------------------------------------------------------------------------------------------------------------
def _clip(arm, name, end, keys, loop=False):
    """lp.add_action com TODOS os ossos e escala em toda chave (rot, loc, escala; o que faltar = repouso)."""
    full = {}
    for b in TOAD_BONES:
        ks = keys.get(b) or [(1, Z, Z, ONE), (end, Z, Z, ONE)]
        full[b] = [(int(k[0]), k[1], k[2], k[3] if len(k) > 3 else ONE) for k in ks]
    lp.add_action(arm, name, full, end, loop=loop)


def _g(imp, rec, seq):
    """Gesto em fases -> quadros: t de -1 a 0 = preparo (quadro 1 até o impacto `imp`), t de 0 a 1 = volta (`rec` quadros).
    seq = {osso: [(t, rot, loc[, escala])]}. Devolve (fim, chaves)."""
    out = {}
    for b, ks in seq.items():
        fr = {}
        for k in ks:
            t = k[0]
            f = int(round(imp + t * (imp - 1))) if t <= 0 else int(round(imp + t * rec))
            fr[max(1, f)] = (max(1, f),) + tuple(k[1:])
        out[b] = [fr[f] for f in sorted(fr)]
    return imp + rec, out


def _legs(front, hind, splay=0.0):
    """Chaves iguais para os dois lados: `front`/`hind` = [(t, giro x, loc)], splay abre para fora (giro z)."""
    out = {}
    for bone, ks, sx in (("leg_fr", front, 1), ("leg_fl", front, -1), ("leg_br", hind, 1), ("leg_bl", hind, -1)):
        out[bone] = [(t, (rx, 0, -sx * splay), loc) for t, rx, loc in ks]
    return out


def _bite(imp, reach=0.5, rec=10):
    seq = {"body": [(-1, Z, Z), (-0.45, (-9, 0, 0), (0, 0, -0.12), (1.04, 0.96, 1.04)), (0, (9, 0, 0), (0, 0.1, reach)),
                    (0.4, (3, 0, 0), (0, 0.02, reach * 0.3)), (1, Z, Z)],
           "head": [(-1, Z, Z), (-0.45, (-30, 0, 0), Z), (-0.12, (-34, 0, 0), Z), (0, (2, 0, 0), Z), (1, Z, Z)],
           "jaw": [(-1, Z, Z), (-0.45, (20, 0, 0), Z), (-0.12, (24, 0, 0), Z), (0, (-2, 0, 0), Z), (1, Z, Z)]}
    seq.update(_legs([(-1, 0, Z), (-0.45, 10, Z), (0, -22, Z), (1, 0, Z)], [(-1, 0, Z), (-0.45, -8, Z), (0, 24, Z), (1, 0, Z)]))
    return _g(imp, rec, seq)


def _spit(imp, rec=11):
    seq = {"body": [(-1, Z, Z), (-0.35, (-16, 0, 0), (0, 0, -0.08), (1.06, 1.03, 1.06)), (0, (8, 0, 0), (0, 0.02, 0.14), (0.97, 1.0, 0.97)),
                    (0.45, (3, 0, 0), (0, 0, 0.05)), (1, Z, Z)],
           "sac": [(-1, Z, Z), (-0.35, Z, Z, (1.8, 1.8, 1.8)), (0, Z, Z, (0.75, 0.75, 0.75)), (1, Z, Z)],
           "head": [(-1, Z, Z), (-0.35, (-6, 0, 0), Z), (0, (-36, 0, 0), Z), (0.45, (-18, 0, 0), Z), (1, Z, Z)],
           "jaw": [(-1, Z, Z), (-0.35, (2, 0, 0), Z), (0, (22, 0, 0), Z), (0.45, (10, 0, 0), Z), (1, Z, Z)]}
    seq.update(_legs([(-1, 0, Z), (-0.35, 16, Z), (0, -8, Z), (1, 0, Z)], [(-1, 0, Z), (0, 6, Z), (1, 0, Z)]))
    return _g(imp, rec, seq)


def _lash(imp, reach=9.0, rec=12, sweep=0.0):
    """Chicotada de língua: boca abre, a língua sai inteira no impacto, fica um instante e volta. `sweep` = varre de lado."""
    seq = {"body": [(-1, Z, Z), (-0.4, (-10, -sweep * 0.6, 0), (0, 0, -0.1)), (0, (5, sweep * 0.2, 0), (0, 0.02, 0.12)), (0.35, (4, sweep, 0), (0, 0, 0.1)),
                    (1, Z, Z)],
           "head": [(-1, Z, Z), (-0.4, (-30, 0, 0), Z), (0, (-26, 0, 0), Z), (0.45, (-24, 0, 0), Z), (0.75, (2, 0, 0), Z), (1, Z, Z)],
           "jaw": [(-1, Z, Z), (-0.4, (18, 0, 0), Z), (0, (20, 0, 0), Z), (0.45, (18, 0, 0), Z), (0.75, (-2, 0, 0), Z), (1, Z, Z)],
           "tongue": [(-1, Z, Z), (-0.3, Z, Z), (-0.12, (-4, 0, 0), Z, (1.0, 1.0, 2.0)), (0, (0, 0, 0), Z, (0.9, 0.9, reach)),
                      (0.3, (2, 0, 0), Z, (0.9, 0.9, reach * 0.92)), (0.6, Z, Z, (1.0, 1.0, 1.6)), (0.7, Z, Z), (1, Z, Z)],
           "sac": [(-1, Z, Z), (-0.4, Z, Z, (1.5, 1.5, 1.5)), (0, Z, Z, (0.8, 0.8, 0.8)), (1, Z, Z)]}
    seq.update(_legs([(-1, 0, Z), (-0.4, 12, Z), (0, -10, Z), (1, 0, Z)], [(-1, 0, Z), (0, 8, Z), (1, 0, Z)]))
    return _g(imp, rec, seq)


def _flop(imp, high=1.5, rec=14):
    """Barrigada: agacha, salta alto, cai de barriga (amassa no impacto) e se recompõe."""
    seq = {"root": [(-1, Z, Z), (-0.72, Z, Z), (-0.38, Z, (0, high, 0)), (-0.14, Z, (0, high * 0.8, 0)), (0, Z, Z), (1, Z, Z)],
           "body": [(-1, Z, Z), (-0.72, (8, 0, 0), (0, -0.05, 0), (1.1, 0.84, 1.1)), (-0.38, (-22, 0, 0), Z, (0.94, 1.1, 0.94)),
                    (-0.14, (14, 0, 0), Z), (0, (4, 0, 0), Z, (1.26, 0.7, 1.26)), (0.25, Z, Z, (0.95, 1.08, 0.95)), (0.5, Z, Z, (1.03, 0.98, 1.03)), (1, Z, Z)],
           "head": [(-1, Z, Z), (-0.38, (-12, 0, 0), Z), (0, (6, 0, 0), Z), (1, Z, Z)],
           "jaw": [(-1, Z, Z), (-0.38, (10, 0, 0), Z), (0, (-2, 0, 0), Z), (1, Z, Z)],
           "sacs": [(-1, Z, Z), (0, Z, Z, (1.15, 0.8, 1.15)), (0.3, Z, Z, (0.95, 1.1, 0.95)), (1, Z, Z)]}
    seq.update(_legs([(-1, 0, Z), (-0.72, 18, Z), (-0.38, -40, Z), (-0.14, -30, Z), (0, -6, Z), (1, 0, Z)],
                     [(-1, 0, Z), (-0.72, -14, Z), (-0.38, 58, Z), (-0.14, 36, Z), (0, -4, Z), (1, 0, Z)], splay=0.0))
    for b in ("leg_fr", "leg_fl", "leg_br", "leg_bl"):          # espalma as patas na queda
        sx = 1 if b.endswith("r") else -1
        ks = seq[b]
        seq[b] = [k if k[0] != 0 else (0, (k[1][0], 0, -sx * 16), k[2]) for k in ks]
    return _g(imp, rec, seq)


def _croak(imp, rec=16):
    """Coaxo de guerra (troca de fase): enche o papo, joga a cabeça para cima e solta, tremendo."""
    seq = {"body": [(-1, Z, Z), (-0.4, (-6, 0, 0), Z, (1.08, 1.05, 1.08)), (0, (-13, 0, 0), (0, 0.03, 0), (1.12, 0.96, 1.12)),
                    (0.2, (-12, 0, 3), Z, (1.07, 0.99, 1.07)), (0.4, (-12, 0, -3), Z, (1.1, 0.97, 1.1)), (0.6, (-9, 0, 2), Z, (1.05, 1.0, 1.05)), (1, Z, Z)],
           "sac": [(-1, Z, Z), (-0.4, Z, Z, (2.1, 2.1, 2.1)), (0, Z, Z, (1.0, 1.0, 1.0)), (0.2, Z, Z, (1.7, 1.7, 1.7)), (0.4, Z, Z, (1.0, 1.0, 1.0)),
                   (0.6, Z, Z, (1.5, 1.5, 1.5)), (1, Z, Z)],
           "head": [(-1, Z, Z), (-0.4, (-8, 0, 0), Z), (0, (-40, 0, 0), Z), (0.6, (-34, 0, 0), Z), (1, Z, Z)],
           "jaw": [(-1, Z, Z), (-0.4, Z, Z), (0, (24, 0, 0), Z), (0.6, (20, 0, 0), Z), (1, Z, Z)],
           "sacs": [(-1, Z, Z), (0, Z, Z, (1.18, 1.18, 1.18)), (0.4, Z, Z, (1.06, 1.06, 1.06)), (1, Z, Z)]}
    seq.update(_legs([(-1, 0, Z), (0, 14, Z), (1, 0, Z)], [(-1, 0, Z), (0, -6, Z), (1, 0, Z)]))
    return _g(imp, rec, seq)


def _gulp(imp, rec=12):
    """Magia/buff: engole em seco, a desova pulsa."""
    seq = {"body": [(-1, Z, Z), (-0.5, (5, 0, 0), (0, -0.03, 0), (1.05, 0.93, 1.05)), (0, (-8, 0, 0), (0, 0.04, 0), (0.98, 1.06, 0.98)), (1, Z, Z)],
           "sac": [(-1, Z, Z), (-0.5, Z, Z, (1.6, 1.6, 1.6)), (0, Z, Z, (0.8, 0.8, 0.8)), (0.5, Z, Z, (1.3, 1.3, 1.3)), (1, Z, Z)],
           "head": [(-1, Z, Z), (-0.5, (6, 0, 0), Z), (0, (-16, 0, 0), Z), (1, Z, Z)],
           "jaw": [(-1, Z, Z), (0, (8, 0, 0), Z), (1, Z, Z)],
           "sacs": [(-1, Z, Z), (-0.5, Z, Z, (0.92, 0.92, 0.92)), (0, Z, Z, (1.28, 1.28, 1.28)), (0.5, Z, Z, (1.08, 1.08, 1.08)), (1, Z, Z)]}
    seq.update(_legs([(-1, 0, Z), (0, 10, Z), (1, 0, Z)], [(-1, 0, Z), (0, -4, Z), (1, 0, Z)]))
    return _g(imp, rec, seq)


def _spin(imp, rec=12):
    """Giro com a língua de fora (varre em volta)."""
    seq = {"body": [(-1, Z, Z), (-0.5, (0, 35, 0), (0, -0.03, 0), (1.05, 0.94, 1.05)), (0, (0, -110, 0), (0, 0.08, 0)), (0.5, (0, -290, 0), (0, 0.08, 0)),
                    (0.85, (0, -360, 0), Z), (1, (0, -360, 0), Z)],
           "head": [(-1, Z, Z), (-0.5, (-20, 0, 0), Z), (0.6, (-24, 0, 0), Z), (0.9, Z, Z), (1, Z, Z)],
           "jaw": [(-1, Z, Z), (-0.5, (14, 0, 0), Z), (0.6, (16, 0, 0), Z), (0.9, Z, Z), (1, Z, Z)],
           "tongue": [(-1, Z, Z), (-0.5, Z, Z), (0, Z, Z, (0.9, 0.9, 6.0)), (0.5, Z, Z, (0.9, 0.9, 6.0)), (0.8, Z, Z, (1.0, 1.0, 1.4)), (0.9, Z, Z), (1, Z, Z)]}
    seq.update(_legs([(-1, 0, Z), (0, -14, Z), (1, 0, Z)], [(-1, 0, Z), (0, 18, Z), (1, 0, Z)]))
    return _g(imp, rec, seq)


def _brace(imp, rec=14):
    """Encolhe e trava (guarda): achata, cabeça baixa, patas recolhidas."""
    seq = {"body": [(-1, Z, Z), (0, (6, 0, 0), (0, -0.04, 0), (1.14, 0.84, 1.14)), (0.7, (6, 0, 0), (0, -0.04, 0), (1.12, 0.86, 1.12)), (1, Z, Z)],
           "head": [(-1, Z, Z), (0, (10, 0, 0), Z), (0.7, (10, 0, 0), Z), (1, Z, Z)],
           "sacs": [(-1, Z, Z), (0, Z, Z, (1.1, 0.9, 1.1)), (0.7, Z, Z, (1.1, 0.9, 1.1)), (1, Z, Z)]}
    seq.update(_legs([(-1, 0, Z), (0, 20, Z), (0.7, 20, Z), (1, 0, Z)], [(-1, 0, Z), (0, -10, Z), (0.7, -10, Z), (1, 0, Z)]))
    return _g(imp, rec, seq)


def _common(arm, hop=0.42, boss=False):
    """idle (papo pulsando), run (pulo), hit, die (vira de barriga para cima)."""
    idle = {"body": [(1, Z, Z), (24, (-1.5, 0, 0), Z, (1.025, 0.985, 1.025)), (48, Z, Z)],
            "sac": [(1, Z, Z), (9, Z, Z, (1.5, 1.5, 1.5)), (17, Z, Z), (30, Z, Z, (1.45, 1.45, 1.45)), (38, Z, Z), (48, Z, Z)],
            "head": [(1, Z, Z), (20, (-2, 4, 0), Z), (36, (-1, -4, 0), Z), (48, Z, Z)],
            "sacs": [(1, Z, Z), (24, Z, Z, (1.05, 1.05, 1.05)), (48, Z, Z)]}
    _clip(arm, "idle", 48, idle, loop=True)
    # pulo no lugar: agacha (1), solta (4), auge (8), cai de patas da frente (12), agacha (15)
    run = {"root": [(1, Z, Z), (4, Z, (0, hop * 0.55, 0)), (8, Z, (0, hop, 0)), (12, Z, (0, hop * 0.3, 0)), (15, Z, Z)],
           "body": [(1, (6, 0, 0), (0, -0.04, 0), (1.08, 0.88, 1.08)), (4, (-20, 0, 0), Z, (0.95, 1.08, 0.95)), (8, (-2, 0, 0), Z),
                    (12, (15, 0, 0), Z), (15, (6, 0, 0), (0, -0.04, 0), (1.08, 0.88, 1.08))],
           "head": [(1, Z, Z), (4, (8, 0, 0), Z), (12, (-8, 0, 0), Z), (15, Z, Z)],
           "leg_fr": [(1, (14, 0, 0), Z), (4, (-34, 0, 0), Z), (8, (-20, 0, 0), Z), (12, (-30, 0, 0), Z), (15, (14, 0, 0), Z)],
           "leg_br": [(1, (-12, 0, 0), Z), (4, (60, 0, 0), Z), (8, (40, 0, 0), Z), (12, (-6, 0, 0), Z), (15, (-12, 0, 0), Z)],
           "sacs": [(1, Z, Z, (1.06, 0.92, 1.06)), (8, Z, Z, (0.97, 1.06, 0.97)), (15, Z, Z, (1.06, 0.92, 1.06))]}
    run["leg_fl"], run["leg_bl"] = list(run["leg_fr"]), list(run["leg_br"])
    _clip(arm, "run", 15, run, loop=True)
    hit = {"body": [(1, (-14, 0, 5), (0, 0, -0.12), (1.1, 0.9, 1.1)), (4, (-5, 0, -3), (0, 0, -0.05), (0.98, 1.03, 0.98)), (9, Z, Z)],
           "head": [(1, (-10, 0, 0), Z), (9, Z, Z)], "sac": [(1, Z, Z, (1.5, 1.5, 1.5)), (9, Z, Z)],
           "leg_fr": [(1, (-20, 0, -12), Z), (9, Z, Z)], "leg_fl": [(1, (-20, 0, 12), Z), (9, Z, Z)]}
    _clip(arm, "hit", 9, hit)
    end = 30 if boss else 26
    die = {"root": [(1, Z, Z), (6, Z, (0, 0.5, 0)), (12, Z, (0, 0.2, 0)), (end, Z, Z)],
           "body": [(1, Z, Z), (6, (-20, 0, 70), Z), (12, (0, 0, 172), Z, (1.1, 0.9, 1.1)), (16, (0, 0, 184), Z, (0.97, 1.04, 0.97)), (20, (0, 0, 180), Z),
                    (end, (0, 0, 180), Z, (1.06, 0.92, 1.06))],
           "head": [(1, Z, Z), (6, (-24, 0, 0), Z), (20, (-14, 0, 0), Z), (end, (-10, 0, 0), Z)],
           "jaw": [(1, Z, Z), (6, (16, 0, 0), Z), (20, (12, 0, 0), Z), (end, (14, 0, 0), Z)],
           "tongue": [(1, Z, Z), (12, Z, Z), (20, (0, 0, 0), Z, (1.0, 1.0, 2.6)), (end, Z, Z, (1.0, 1.0, 2.8))],
           "sac": [(1, Z, Z), (6, Z, Z, (1.6, 1.6, 1.6)), (20, Z, Z, (0.8, 0.8, 0.8)), (end, Z, Z, (0.7, 0.7, 0.7))],
           "sacs": [(1, Z, Z), (12, Z, Z, (1.1, 0.8, 1.1)), (end, Z, Z, (1.05, 0.7, 1.05))],
           "leg_fr": [(1, Z, Z), (6, (-40, 0, -20), Z), (14, (30, 0, -30), Z), (18, (-10, 0, -22), Z), (22, (16, 0, -26), Z), (end, (10, 0, -26), Z)],
           "leg_fl": [(1, Z, Z), (6, (-40, 0, 20), Z), (14, (30, 0, 30), Z), (18, (-10, 0, 22), Z), (22, (16, 0, 26), Z), (end, (10, 0, 26), Z)],
           "leg_br": [(1, Z, Z), (6, (50, 0, -10), Z), (14, (-30, 0, -24), Z), (19, (20, 0, -18), Z), (23, (-12, 0, -22), Z), (end, (-8, 0, -22), Z)],
           "leg_bl": [(1, Z, Z), (6, (50, 0, 10), Z), (14, (-30, 0, 24), Z), (19, (20, 0, 18), Z), (23, (-12, 0, 22), Z), (end, (-8, 0, 22), Z)]}
    _clip(arm, "die", end, die)


def _toad_clips(arm):
    _common(arm)
    for name, fn in (("attack", _bite), ("atk_throw", _spit)):
        end, keys = fn(IMPACT[name])
        _clip(arm, name, end, keys)


def _mother_clips(arm):
    """Clipes do kit de chefe (ck.MOB_BOSS_KEEP) + maul/pounce/slam/roar/brace + jump/fall/land/dash, a partir de sete gestos."""
    _common(arm, hop=0.36, boss=True)
    table = {"attack": lambda i: _bite(i, 0.55), "atk_claw": lambda i: _bite(i, 0.6), "maul": lambda i: _bite(i, 0.7, 12),
             "atk_charge": lambda i: _bite(i, 1.0, 12),
             "atk_throw": _lash, "cast_target": _lash, "cast_bolt": lambda i: _lash(i, 7.0), "atk_sweep": lambda i: _lash(i, 7.5, 12, 55.0),
             "atk_spin": _spin,
             "atk_leap": lambda i: _flop(i, 1.7), "slam": lambda i: _flop(i, 1.3), "pounce": lambda i: _flop(i, 1.1, 12), "cast_ground": lambda i: _flop(i, 0.9, 12),
             "shout": _croak, "roar": _croak, "summon": _croak, "cast_channel": _croak,
             "buff_guard": _brace, "brace": _brace,
             "buff_focus": _gulp, "cast_fire": _gulp, "cast_ice": _gulp, "cast_shadow": _gulp, "cast_holy": _gulp, "cast_nature": _gulp}
    for name, fn in table.items():
        end, keys = fn(IMPACT[name])
        _clip(arm, name, end, keys)
    air = {"root": [(1, Z, (0, 0.5, 0)), (8, Z, (0, 0.5, 0))], "body": [(1, (-16, 0, 0), Z, (0.95, 1.08, 0.95)), (8, (-10, 0, 0), Z, (0.96, 1.06, 0.96))],
           "leg_fr": [(1, (-36, 0, 0), Z), (8, (-30, 0, 0), Z)], "leg_fl": [(1, (-36, 0, 0), Z), (8, (-30, 0, 0), Z)],
           "leg_br": [(1, (56, 0, 0), Z), (8, (50, 0, 0), Z)], "leg_bl": [(1, (56, 0, 0), Z), (8, (50, 0, 0), Z)]}
    up = {b: [(1, Z, Z)] + [(5,) + tuple(ks[0][1:]), (10,) + tuple(ks[1][1:])] for b, ks in air.items()}
    up["body"][0] = (1, (8, 0, 0), (0, -0.05, 0), (1.1, 0.85, 1.1))
    _clip(arm, "jump", 10, up)
    fall = {b: [(1,) + tuple(ks[1][1:]), (8,) + tuple(ks[1][1:])] for b, ks in air.items()}
    fall["body"] = [(1, (10, 0, 0), Z), (8, (14, 0, 0), Z)]
    _clip(arm, "fall", 8, fall, loop=True)
    land = {"body": [(1, (6, 0, 0), Z, (1.24, 0.72, 1.24)), (4, Z, Z, (0.95, 1.08, 0.95)), (9, Z, Z)],
            "sacs": [(1, Z, Z, (1.15, 0.8, 1.15)), (9, Z, Z)],
            "leg_fr": [(1, (-6, 0, -16), Z), (9, Z, Z)], "leg_fl": [(1, (-6, 0, 16), Z), (9, Z, Z)]}
    _clip(arm, "land", 9, land)
    dash = {"root": [(1, Z, Z), (4, Z, (0, 0.3, 0)), (9, Z, Z)], "body": [(1, (8, 0, 0), Z, (1.08, 0.88, 1.08)), (4, (-12, 0, 0), Z), (9, (10, 0, 0), Z)],
            "leg_fr": [(1, (14, 0, 0), Z), (4, (-34, 0, 0), Z), (9, (-10, 0, 0), Z)], "leg_fl": [(1, (14, 0, 0), Z), (4, (-34, 0, 0), Z), (9, (-10, 0, 0), Z)],
            "leg_br": [(1, (-12, 0, 0), Z), (4, (58, 0, 0), Z), (9, (10, 0, 0), Z)], "leg_bl": [(1, (-12, 0, 0), Z), (4, (58, 0, 0), Z), (9, (10, 0, 0), Z)]}
    _clip(arm, "dash", 9, dash)


def _plant(arm, margin=0.0, only=None):
    """Nada abaixo do chão: em cada quadro em que alguma peça desce de z = margin, a raiz sobe o que falta (chave em `root`
    loc Y). Nomes, tempos e impactos não mudam. (Mesma ideia de lumeria_mobs_b._plant.)"""
    ad = arm.animation_data
    pb = arm.pose.bones["root"]
    objs = [o for o in arm.children if o.type == "MESH"]
    tracks = {t.name: t for t in ad.nla_tracks}
    for t in ad.nla_tracks:
        t.mute = True
    for name, tr in tracks.items():
        if only and name not in only:
            continue
        act = tr.strips[0].action
        ad.action = act
        if getattr(ad, "action_slot", None) is None and getattr(act, "slots", None):
            ad.action_slot = act.slots[0]
        fix = {}
        for f in range(1, int(round(act.frame_range[1])) + 1):
            bpy.context.scene.frame_set(f)
            bpy.context.view_layer.update()
            low = min((o.matrix_world @ v.co).z for o in objs for v in o.data.vertices)
            fix[f] = (pb.location.y, max(0.0, margin - low))
        if max(d for _y, d in fix.values()) > 0.004:
            for f, (y, d) in fix.items():
                pb.location.y = y + d
                pb.keyframe_insert("location", index=1, frame=f)
        ad.action = None
    for t in ad.nla_tracks:
        t.mute = False
    for b in arm.pose.bones:
        b.rotation_euler = (0, 0, 0)
        b.location = (0, 0, 0)
        b.scale = (1, 1, 1)
    bpy.context.scene.frame_set(1)


# ---------------------------------------------------------------------------------------------------------------
# Tecelã do Brejo: aranha esguia de longe, abdômen inchado de seiva acesa, as patas da frente erguidas
# ---------------------------------------------------------------------------------------------------------------
def web_weaver(cid="mob_web_weaver"):
    arm = lp.make_armature("rig_" + cid, mk.pivots(leg_fr=(0.13, -0.16, 0.5), leg_fl=(-0.13, -0.16, 0.5), leg_br=(0.13, 0.08, 0.5),
                                                   leg_bl=(-0.13, 0.08, 0.5), head=(0, -0.2, 0.52)))
    m = ck.mat("m_%s" % cid, (0.34, 0.33, 0.26), 0.6)
    md = ck.mat("m_%s_dark" % cid, (0.2, 0.2, 0.17), 0.6)
    amber = ck.mat("glow_%s_sap" % cid, (0.95, 0.72, 0.28), 0.25, 1.5)
    shell = ck.mat("m_%s_band" % cid, (0.62, 0.5, 0.26), 0.5)
    silk = ck.mat("m_%s_silk" % cid, (0.88, 0.89, 0.82), 0.8)
    m_eye = ck.mat("m_%s_eye" % cid, (1.0, 0.8, 0.3), 0.3, 1.5)
    blob, tube = mk.blob, ck.tube
    parts = [(blob("abdomen", 0.4, (0, 0.5, 0.74), amber, (0.95, 1.2, 1.05), 3), "body"),            # bolsa de seiva: alta e inchada
             (blob("thorax", 0.17, (0, -0.06, 0.5), m, (0.9, 1.3, 0.85), 2), "body"),
             (blob("waist", 0.1, (0, 0.14, 0.56), md, (1, 1.2, 1), 1), "body"),
             (blob("head", 0.12, (0, -0.3, 0.53), m, (1, 1.1, 0.9), 2), "head"),
             (blob("spinneret", 0.09, (0, 0.98, 0.62), silk, (1, 1.2, 1), 1), "body")]
    for i, (yy, sc) in enumerate(((0.3, 0.86), (0.52, 1.0), (0.74, 0.84))):                     # cintas de casca por cima da bolsa
        rr = 0.4 * sc
        for k in range(10):
            a0, a1 = math.pi * (k / 10.0) - 0.0, math.pi * ((k + 1) / 10.0)
            p0 = (math.cos(a0) * rr * 0.97, yy, 0.74 + math.sin(a0) * rr * 1.07)
            p1 = (math.cos(a1) * rr * 0.97, yy, 0.74 + math.sin(a1) * rr * 1.07)
            parts.append((tube("band%d_%d" % (i, k), p0, p1, 0.035, 0.035, shell if i != 1 else md, 5), "body"))
    for i, (x, z) in enumerate([(-0.06, 0.6), (0.06, 0.6), (-0.1, 0.55), (0.1, 0.55), (-0.04, 0.53), (0.04, 0.53)]):
        parts.append((blob("eye%d" % i, 0.03 if i < 2 else 0.02, (x, -0.4, z), m_eye), "head"))
    horn = ck.mat("m_horn", (0.95, 0.9, 0.78), 0.5)
    for sx in (-1, 1):
        parts.append((mk.cone("fang%d" % sx, (sx * 0.04, -0.4, 0.47), (sx * 0.025, -0.47, 0.36), 0.022, horn), "head"))
        # par da frente ERGUIDO (preso ao tórax: não anda; é a pose de tecer/ameaçar)
        root, knee, tip = Vector((sx * 0.1, -0.2, 0.55)), Vector((sx * 0.3, -0.42, 1.0)), Vector((sx * 0.22, -0.78, 1.22))
        parts.append((tube("raise%d_a" % sx, root, knee, 0.04, 0.03, m, 6), "head"))
        parts.append((tube("raise%d_b" % sx, knee, tip, 0.03, 0.01, md, 6), "head"))
        parts.append((blob("raise%d_k" % sx, 0.04, knee, m), "head"))
        for i in range(3):                                          # três pares que andam, compridos e finos
            y = -0.1 + i * 0.13
            bone = ("leg_fr" if i < 1 else "leg_br") if sx > 0 else ("leg_fl" if i < 1 else "leg_bl")
            root = Vector((sx * 0.13, y, 0.5))
            knee = Vector((sx * 0.52, y + (i - 1.0) * 0.16, 0.92))
            foot = Vector((sx * 0.86, y + (i - 1.0) * 0.34, 0.0))
            parts.append((tube("leg%d%d_a" % (sx, i), root, knee, 0.038, 0.03, m, 6), bone))
            parts.append((tube("leg%d%d_b" % (sx, i), knee, foot, 0.03, 0.01, md, 6), bone))
            parts.append((blob("knee%d%d" % (sx, i), 0.04, knee, m), bone))
    P = _Parts()
    for o, bone in parts:
        P.add(o, bone)
    P.finish(arm, "weaver")
    bm.mob_actions(arm, quadruped=True)
    # cuspe de teia: recua, ergue o abdômen e dispara para a frente (impacto no quadro 7 = EntityView.IMPACT_FRAME["atk_throw"])
    z = (0, 0, 0)
    lp.add_action(arm, "atk_throw", {
        "body": [(1, z, z), (4, (-14, 0, 0), (0, 0.06, -0.06)), (7, (7, 0, 0), (0, 0.05, 0.1)), (11, (3, 0, 0), (0, 0.02, 0.03)), (18, z, z)],
        "head": [(1, z, z), (4, (-20, 0, 0), z), (7, (16, 0, 0), z), (18, z, z)],
        "leg_fr": [(1, z, z), (7, (0, 0, 0), z), (18, z, z)], "leg_fl": [(1, z, z), (18, z, z)],
        "leg_br": [(1, z, z), (18, z, z)], "leg_bl": [(1, z, z), (18, z, z)],
        "arm_r": [(1, z, z), (18, z, z)], "arm_l": [(1, z, z), (18, z, z)], "root": [(1, z, z), (18, z, z)]}, 18, loop=False)
    _plant(arm, only=("atk_throw",))
    return arm


BUILDERS = {
    "mob_bog_toad": lambda: toad("mob_bog_toad", "toad"),
    "mob_bog_mother": lambda: toad("mob_bog_mother", "mother"),
    "mob_web_weaver": web_weaver,
}
HUMANOIDS = set()          # todos de peças rígidas (lp.export_glb)
