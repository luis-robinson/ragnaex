"""Props élficos (Cidade Élfica): a arquitetura cresce das árvores. Inspiração: Lothlórien / cidades élficas noturnas —
casas que abraçam troncos vivos, paredes redondas de madeira clara, telhados em pétalas de folha, janelas em arco que
brilham, plataformas em anel no alto do tronco, portais em arco de dois troncos, lanternas em hastes curvas.
Registrados em prop_kit.BUILDERS (prop_<kind>.glb). "tint" = parede (cor do obstáculo), "roof" = pétalas (cor do telhado).
Frente = -Y, como os outros props.
"""
import math
import random
from mathutils import Vector

import chibi_kit as ck


def _mats(m):
    m = dict(m)
    m["bark"] = ck.mat("p_elf_bark", (0.5, 0.4, 0.3), 0.85)
    m["bark_d"] = ck.mat("p_elf_bark_d", (0.36, 0.28, 0.21), 0.85)
    m["leaf"] = ck.mat("p_elf_leaf", (0.24, 0.5, 0.3), 0.8)
    m["leaf_l"] = ck.mat("p_elf_leaf_l", (0.36, 0.62, 0.36), 0.8)
    m["moon"] = ck.mat("p_elf_glow", (0.7, 1.0, 0.8), 0.3, 2.2)
    m["silver"] = ck.mat("p_elf_silver", (0.86, 0.88, 0.84), 0.5)
    return m


def _trunk(pk, m, h, r0, r1, roots=6, seed=1):
    """Tronco afunilado com raízes em leque e leve torção."""
    rnd = random.Random(seed)
    out = []
    segs = 4
    prev, pr = Vector((0, 0, 0)), r0
    for i in range(1, segs + 1):
        t = i / segs
        p = Vector((math.sin(t * 2.2 + seed) * 0.18 * t, math.cos(t * 1.7 + seed) * 0.14 * t, h * t))
        r = r0 + (r1 - r0) * t
        out.append(ck.tube("trunk%d" % i, prev, p, pr, r, m["bark"], 12))
        prev, pr = p, r
    for k in range(roots):
        a = math.tau * k / roots + rnd.uniform(-0.2, 0.2)
        d = Vector((math.cos(a), math.sin(a), 0))
        mid = d * (r0 * 1.3) + Vector((0, 0, 0.45))
        tip = d * (r0 * 2.3 + rnd.uniform(0, 0.4)) + Vector((0, 0, -0.05))
        out.append(ck.tube("root%d_a" % k, d * r0 * 0.6 + Vector((0, 0, 1.1)), mid, r0 * 0.38, r0 * 0.26, m["bark_d"], 8))
        out.append(ck.tube("root%d_b" % k, mid, tip, r0 * 0.26, 0.06, m["bark_d"], 8))
    return out, prev


def _petal_roof(m, c, r_eave, z_eave, z_apex, n, name, mat, curl=0.5, width=None):
    """Telhado de pétalas: n folhas largas da beira ao ápice, sobrepostas, com a ponta da beira virada para fora."""
    out = []
    c = Vector(c)
    w = width or (math.tau * r_eave / n) * 1.45
    for k in range(n):
        a = math.tau * k / n
        d = Vector((math.cos(a), math.sin(a), 0))
        root = c + d * (r_eave * 0.12) + Vector((0, 0, z_apex))
        eave = c + d * r_eave + Vector((0, 0, z_eave))
        side = Vector((-d.y, d.x, 0))
        out.append(ck.blade("%s_petal%d" % (name, k), eave, root, w, 0.07, mat, side, 0.35))
        out.append(ck.blade("%s_curl%d" % (name, k), eave, eave + d * curl + Vector((0, 0, curl * 0.6)), w * 0.55, 0.05, mat, side, 0.4))
    out.append(ck.ball(name + "_tip", 0.2, c + Vector((0, 0, z_apex + 0.1)), m["silver"]))
    return out


def _arched_window(m, c, normal, w=0.6, h=1.0, name="win"):
    c, n = Vector(c), Vector(normal).normalized()
    side = Vector((-n.y, n.x, 0))
    out = [ck.box(name + "_glow", (w if abs(n.y) > 0.5 else 0.08, 0.08 if abs(n.y) > 0.5 else w, h), c + n * 0.04, m["moon"], 0.02),
           ck.ball(name + "_arch", w * 0.5, c + n * 0.04 + Vector((0, 0, h * 0.5)), m["moon"], (1.0, 0.25, 0.7) if abs(n.y) > 0.5 else (0.25, 1.0, 0.7))]
    out.append(ck.tube(name + "_frame", c + n * 0.08 - side * w * 0.62 - Vector((0, 0, h * 0.5)), c + n * 0.08 - side * w * 0.62 + Vector((0, 0, h * 0.55)), 0.06, 0.05, m["silver"], 6))
    out.append(ck.tube(name + "_frame2", c + n * 0.08 + side * w * 0.62 - Vector((0, 0, h * 0.5)), c + n * 0.08 + side * w * 0.62 + Vector((0, 0, h * 0.55)), 0.06, 0.05, m["silver"], 6))
    return out


def _pod(m, c, r, h, name):
    """Parede redonda de madeira clara (cor do obstáculo) com friso prateado."""
    c = Vector(c)
    return [ck.tube(name + "_wall", c, c + Vector((0, 0, h)), r, r * 0.94, m["tint"], 20),
            ck.tube(name + "_base", c - Vector((0, 0, 0.05)), c + Vector((0, 0, 0.3)), r * 1.06, r * 1.04, m["bark_d"], 20),
            ck.tube(name + "_band", c + Vector((0, 0, h - 0.18)), c + Vector((0, 0, h)), r * 1.0, r * 0.98, m["silver"], 20)]


def elf_treehouse(m0):
    """Casa-árvore: tronco vivo, casa redonda abraçando a base, telhado de pétalas, plataforma em anel no alto e a copa."""
    m = _mats(m0)
    parts, top = _trunk(None, m, 10.0, 1.5, 0.75, roots=7, seed=3)
    # casa da base (abraça o tronco)
    parts += _pod(m, (0, 0, 0), 2.6, 2.9, "casa")
    parts += _petal_roof(m, (0, 0, 0), 3.1, 2.75, 4.8, 11, "teto", m["roof"], 0.55)
    # porta em arco (frente -Y) e janelas
    fy = -2.6
    parts += [ck.box("door", (1.1, 0.12, 1.7), (0, fy - 0.03, 0.95), m["bark_d"], 0.03),
              ck.ball("door_arch", 0.55, (0, fy - 0.03, 1.8), m["bark_d"], (1.0, 0.22, 0.75)),
              ck.tube("door_frame_l", (-0.66, fy - 0.08, 0.1), (-0.66, fy - 0.08, 1.95), 0.08, 0.06, m["silver"], 6),
              ck.tube("door_frame_r", (0.66, fy - 0.08, 0.1), (0.66, fy - 0.08, 1.95), 0.08, 0.06, m["silver"], 6),
              ck.box("step", (1.6, 0.6, 0.16), (0, fy - 0.4, 0.08), m["silver"], 0.04)]
    for k, a in enumerate((-150.0, -30.0, 40.0, 140.0)):
        d = Vector((math.cos(math.radians(a)), math.sin(math.radians(a)), 0))
        parts += _arched_window(m, d * 2.62 + Vector((0, 0, 1.55)), d, 0.55, 0.9, "win%d" % k)
    # raízes de fora sobem abraçando a parede da casa (a casa nasce da árvore)
    for k in range(5):
        a = math.tau * k / 5 + 1.1
        d = Vector((math.cos(a), math.sin(a), 0))
        p0 = d * 3.6 + Vector((0, 0, -0.05))
        p1 = d * 2.85 + Vector((0, 0, 1.2))
        p2 = d * 2.8 + Vector((0, 0, 2.6))
        p3 = d * 1.6 + Vector((0, 0, 4.2))
        parts += [ck.tube("hug%d_a" % k, p0, p1, 0.32, 0.24, m["bark_d"], 8), ck.tube("hug%d_b" % k, p1, p2, 0.24, 0.18, m["bark_d"], 8),
                  ck.tube("hug%d_c" % k, p2, p3, 0.18, 0.1, m["bark"], 8)]
    # plataforma em anel no meio do tronco, com guarda-corpo e lanternas penduradas
    pz = 6.4
    parts.append(ck.tube("deck", Vector((0, 0, pz - 0.18)), Vector((0, 0, pz + 0.05)), 2.7, 2.7, m["wood_l"], 20))
    parts.append(ck.tube("deck_rim", Vector((0, 0, pz - 0.3)), Vector((0, 0, pz - 0.15)), 2.75, 2.6, m["bark_d"], 20))
    for k in range(12):
        a = math.tau * k / 12
        p = Vector((math.cos(a) * 2.55, math.sin(a) * 2.55, pz))
        parts.append(ck.tube("rail_post%d" % k, p, p + Vector((0, 0, 0.75)), 0.05, 0.05, m["silver"], 6))
        q = Vector((math.cos(a + math.tau / 12) * 2.55, math.sin(a + math.tau / 12) * 2.55, pz))
        parts.append(ck.tube("rail%d" % k, p + Vector((0, 0, 0.75)), q + Vector((0, 0, 0.75)), 0.045, 0.045, m["silver"], 6))
        if k % 3 == 0:
            hp = Vector((math.cos(a) * 2.9, math.sin(a) * 2.9, pz - 0.4))
            parts.append(ck.tube("hang%d" % k, hp + Vector((0, 0, 0.35)), hp + Vector((0, 0, 0.12)), 0.015, 0.015, m["silver"], 4))
            parts.append(ck.ball("pod_glow%d" % k, 0.22, hp, m["moon"], (1, 1, 1.3)))
    # braços que seguram o deque
    for k in range(4):
        a = math.tau * k / 4 + 0.4
        d = Vector((math.cos(a), math.sin(a), 0))
        parts.append(ck.tube("brace%d" % k, d * 0.7 + Vector((0, 0, pz - 1.8)), d * 2.3 + Vector((0, 0, pz - 0.2)), 0.18, 0.1, m["bark"], 8))
    # pequena câmara na plataforma
    parts += _pod(m, (1.1, 1.0, pz), 0.95, 1.3, "camara")
    parts += _petal_roof(m, (1.1, 1.0, pz), 1.2, 1.25, 2.4, 7, "teto2", m["roof"], 0.3)
    # galhos e copa
    for k, (dx, dy) in enumerate(((1.6, -0.6), (-1.5, 0.4), (0.3, 1.6))):
        parts.append(ck.tube("branch%d" % k, top - Vector((0, 0, 1.4)), top + Vector((dx, dy, 0.6)), 0.32, 0.14, m["bark"], 8))
    for i, (c, r) in enumerate([((0, 0, 11.6), 2.9), ((2.6, -0.8, 10.9), 2.1), ((-2.5, 0.7, 11.0), 2.2), ((0.6, 2.6, 10.8), 2.0), ((-0.7, -2.5, 10.9), 1.9), ((0.2, 0.1, 13.0), 1.8), ((1.9, 1.9, 11.6), 1.5), ((-1.9, -1.6, 11.7), 1.5)]):
        parts.append(_lumpy("crown%d" % i, r, c, m["leaf"] if i % 2 == 0 else m["leaf_l"], (1, 1, 0.75), i))
    return parts


def elf_hut(m0):
    """Casulo élfico: botão de flor de madeira clara, pétalas fechando em ponta, raízes abraçando e lanterna na ponta."""
    m = _mats(m0)
    parts = _pod(m, (0, 0, 0), 1.8, 1.9, "casulo")
    parts += _petal_roof(m, (0, 0, 0), 2.15, 1.75, 4.3, 8, "petalas", m["roof"], 0.45)
    fy = -1.8
    parts += [ck.box("door", (0.85, 0.12, 1.35), (0, fy - 0.03, 0.75), m["bark_d"], 0.03),
              ck.ball("door_arch", 0.43, (0, fy - 0.03, 1.42), m["bark_d"], (1.0, 0.22, 0.75)),
              ck.box("step", (1.2, 0.5, 0.14), (0, fy - 0.35, 0.07), m["silver"], 0.04)]
    for k, a in enumerate((-20.0, 160.0, 70.0)):
        d = Vector((math.cos(math.radians(a)), math.sin(math.radians(a)), 0))
        parts += _arched_window(m, d * 1.82 + Vector((0, 0, 1.1)), d, 0.42, 0.65, "win%d" % k)
    for k in range(4):                       # raízes que sobem abraçando o casulo
        a = math.tau * k / 4 + 0.8
        d = Vector((math.cos(a), math.sin(a), 0))
        p0 = d * 2.6 + Vector((0, 0, -0.05))
        p1 = d * 2.0 + Vector((0, 0, 0.9))
        p2 = d * 1.95 + Vector((0, 0, 1.8))
        parts.append(ck.tube("hug%d_a" % k, p0, p1, 0.2, 0.15, m["bark_d"], 8))
        parts.append(ck.tube("hug%d_b" % k, p1, p2, 0.15, 0.06, m["bark_d"], 8))
    parts.append(ck.tube("tip_stem", (0, 0, 4.3), (0.35, 0, 4.9), 0.05, 0.03, m["bark"], 6))
    parts.append(ck.ball("tip_glow", 0.2, (0.42, 0, 4.65), m["moon"], (1, 1, 1.3)))
    return parts


def elf_lantern(m0):
    """Lanterna élfica: haste curva de madeira viva com um casulo de luz pendurado e uma folha por cima."""
    m = _mats(m0)
    pts = [Vector((0, 0, 0)), Vector((0.05, 0, 1.2)), Vector((0.25, 0, 2.4)), Vector((0.7, 0, 3.1)), Vector((1.1, 0, 3.15))]
    parts = [ck.tube("root", (0, 0, -0.05), (0, 0, 0.3), 0.22, 0.14, m["bark_d"], 8)]
    for i in range(len(pts) - 1):
        parts.append(ck.tube("stem%d" % i, pts[i], pts[i + 1], 0.12 - i * 0.02, 0.1 - i * 0.02, m["bark"], 8))
    parts.append(ck.tube("hook", (1.05, 0, 3.12), (1.05, 0, 2.85), 0.015, 0.015, m["silver"], 4))
    parts.append(ck.ball("pod", 0.24, (1.05, 0, 2.62), m["moon"], (1, 1, 1.35)))
    parts.append(ck.blade("leaf", (1.05, 0, 3.15), (0.6, 0, 3.4), 0.4, 0.04, m["leaf"], (0, 1, 0), 0.4))
    return parts


def elf_arch(m0):
    """Portal em arco: dois troncos que se curvam e se encontram no alto, folhas e lanterna no topo. Largura em X."""
    m = _mats(m0)
    parts = []
    n = 8
    for sx in (-1, 1):
        prev = Vector((sx * 2.4, 0, 0))
        for i in range(1, n + 1):
            t = i / n
            a = t * math.pi * 0.5
            p = Vector((sx * 2.4 * math.cos(a), 0, 4.2 * math.sin(a)))
            parts.append(ck.tube("arm%d_%d" % (sx, i), prev, p, 0.34 - t * 0.16, 0.32 - t * 0.16, m["bark"], 8))
            prev = p
        parts.append(ck.tube("foot%d" % sx, Vector((sx * 2.4, 0, 0.6)), Vector((sx * 3.0, 0.3, -0.05)), 0.24, 0.08, m["bark_d"], 8))
    for i, (c, r) in enumerate([((0, 0, 4.4), 0.8), ((-0.9, 0.1, 4.1), 0.6), ((0.9, -0.1, 4.1), 0.6), ((0, 0.2, 4.9), 0.5)]):
        parts.append(_lumpy("leaves%d" % i, r, c, m["leaf"] if i % 2 == 0 else m["leaf_l"], (1.3, 0.8, 0.7), i))
    parts.append(ck.tube("hook", (0, 0, 3.8), (0, 0, 3.5), 0.015, 0.015, m["silver"], 4))
    parts.append(ck.ball("glow", 0.26, (0, 0, 3.25), m["moon"], (1, 1, 1.3)))
    return parts


def _lumpy(name, r, c, mat, scale, seed):
    import prop_kit
    return prop_kit.lumpy(name, r, c, mat, scale, 0.2, 40 + seed)


BUILDERS = {"elf_treehouse": elf_treehouse, "elf_hut": elf_hut, "elf_lantern": elf_lantern, "elf_arch": elf_arch}
