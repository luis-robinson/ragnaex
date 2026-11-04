"""Gera os monstros low-poly (um GLB cada) com rig mínimo e animações idle/run/attack/hit/die.
    import build_monsters; build_monsters.build_all(r"<pasta>/ragnaex/assets/models")
"""
import bpy
import importlib
import os
import lowpoly_lib as lp

importlib.reload(lp)

MOB_BONES = {
    "root": ((0, 0, 0), (0, 0, 0.2), None),
    "body": ((0, 0, 0.3), (0, 0, 0.9), "root"),
    "head": ((0, -0.5, 0.7), (0, -0.9, 0.9), "body"),
    "leg_fr": ((0.3, -0.4, 0.3), (0.3, -0.4, 0.0), "body"),
    "leg_fl": ((-0.3, -0.4, 0.3), (-0.3, -0.4, 0.0), "body"),
    "leg_br": ((0.3, 0.4, 0.3), (0.3, 0.4, 0.0), "body"),
    "leg_bl": ((-0.3, 0.4, 0.3), (-0.3, 0.4, 0.0), "body"),
    "arm_r": ((0.4, 0, 0.9), (0.4, 0, 0.5), "body"),
    "arm_l": ((-0.4, 0, 0.9), (-0.4, 0, 0.5), "body"),
}


def mob_actions(arm, quadruped=False, floating=False):
    z = (0, 0, 0)
    lp.add_action(arm, "idle", {
        "body": [(1, (0, 0, 0), z), (24, (0, 0, 0), (0, 0, 0.06 if floating else 0.02)), (48, (0, 0, 0), z)],
        "head": [(1, (0, 0, 0), z), (24, (6, 0, 0), z), (48, (0, 0, 0), z)],
    }, 48)
    if quadruped:
        lp.add_action(arm, "run", {
            "body": [(1, (-6, 0, 0), z), (6, (6, 0, 0), (0, 0, 0.08)), (12, (-6, 0, 0), z)],
            "leg_fr": [(1, (35, 0, 0), z), (6, (-35, 0, 0), z), (12, (35, 0, 0), z)],
            "leg_bl": [(1, (35, 0, 0), z), (6, (-35, 0, 0), z), (12, (35, 0, 0), z)],
            "leg_fl": [(1, (-35, 0, 0), z), (6, (35, 0, 0), z), (12, (-35, 0, 0), z)],
            "leg_br": [(1, (-35, 0, 0), z), (6, (35, 0, 0), z), (12, (-35, 0, 0), z)],
        }, 12)
    else:
        lp.add_action(arm, "run", {
            "body": [(1, (8, 0, -6), z), (8, (8, 0, 6), (0, 0, 0.1)), (16, (8, 0, -6), z)],
            "arm_r": [(1, (-30, 0, 0), z), (8, (30, 0, 0), z), (16, (-30, 0, 0), z)],
            "arm_l": [(1, (30, 0, 0), z), (8, (-30, 0, 0), z), (16, (30, 0, 0), z)],
        }, 16)
    lp.add_action(arm, "attack", {
        "body": [(1, (-12, 0, 0), (0, 0.1, 0)), (6, (20, 0, 0), (0, -0.25, 0)), (14, (0, 0, 0), z)],
        "head": [(1, (-15, 0, 0), z), (6, (20, 0, 0), z), (14, (0, 0, 0), z)],
        "arm_r": [(1, (-100, 0, 0), z), (6, (20, 0, 0), z), (14, (0, 0, 0), z)],
    }, 14, loop=False)
    lp.add_action(arm, "hit", {
        "body": [(1, (-15, 0, 0), (0, 0.1, 0)), (8, (0, 0, 0), z)],
    }, 8, loop=False)
    lp.add_action(arm, "die", {
        "root": [(1, (0, 0, 0), z), (12, (0, 80, 0), (0, 0, -0.1)), (20, (0, 85, 0), (0, 0, -0.2))],
    }, 20, loop=False)


def quadruped(cid, color, dark, head_scale=1.0, body=(0.9, 1.3, 0.6), tusks=False, mane=False):
    arm = lp.make_armature("rig_" + cid, MOB_BONES)
    m = lp.material("m_%s" % cid, color)
    md = lp.material("m_%s_d" % cid, dark)
    parts = []
    parts.append((lp.box("body", body, (0, 0, 0.55), m), "body"))
    parts.append((lp.box("head", (0.6 * head_scale, 0.6 * head_scale, 0.5 * head_scale), (0, -0.85, 0.7), lp.material("m_%s_l" % cid, [min(1, c + 0.08) for c in color])), "head"))
    parts.append((lp.box("snout", (0.3, 0.3, 0.22), (0, -1.2, 0.6), md), "head"))
    for i, sx in enumerate((-1, 1)):
        parts.append((lp.box("eye%d" % i, (0.08, 0.04, 0.08), (sx * 0.18, -1.16, 0.8), lp.material("m_eye_red", (1.0, 0.3, 0.2), 1.0)), "head"))
        parts.append((lp.cylinder("ear%d" % i, 0.0, 0.08, 0.25, (sx * 0.22, -0.75, 1.05), md, 4), "head"))
        if tusks:
            parts.append((lp.cylinder("tusk%d" % i, 0.0, 0.05, 0.3, (sx * 0.18, -1.3, 0.5), lp.material("m_bone", (0.95, 0.9, 0.8)), 5, (1.2, 0, 0)), "head"))
    if mane:
        parts.append((lp.box("mane", (0.95, 0.5, 0.3), (0, -0.4, 0.95), md), "body"))
    for name, (sx, sy) in (("leg_fr", (1, -1)), ("leg_fl", (-1, -1)), ("leg_br", (1, 1)), ("leg_bl", (-1, 1))):
        parts.append((lp.box(name + "_m", (0.2, 0.2, 0.42), (sx * 0.3, sy * 0.4, 0.21), md), name))
    parts.append((lp.cylinder("tail", 0.0, 0.05, 0.4, (0, 0.75, 0.7), md, 4, (-1.0, 0, 0)), "body"))
    for obj, bone in parts:
        lp.attach(obj, arm, bone)
    mob_actions(arm, quadruped=True)
    return arm


def slime(cid):
    arm = lp.make_armature("rig_" + cid, MOB_BONES)
    m = lp.material("m_slime", (0.45, 0.9, 0.5))
    parts = [(lp.sphere("body", 0.5, (0, 0, 0.4), m, 12, 7, (1, 1, 0.8)), "body")]
    for i, sx in enumerate((-1, 1)):
        parts.append((lp.sphere("eye%d" % i, 0.08, (sx * 0.18, -0.42, 0.5), lp.material("m_eye", (0.1, 0.1, 0.15)), 6, 3), "body"))
    parts.append((lp.box("mouth", (0.2, 0.04, 0.04), (0, -0.48, 0.35), lp.material("m_eye", (0.1, 0.1, 0.15))), "body"))
    for obj, bone in parts:
        lp.attach(obj, arm, bone)
    z = (0, 0, 0)
    lp.add_action(arm, "idle", {"body": [(1, (0, 0, 0), z), (16, (0, 0, 0), (0, 0, 0.1)), (32, (0, 0, 0), z)]}, 32)
    lp.add_action(arm, "run", {"body": [(1, (0, 0, 0), z), (6, (10, 0, 0), (0, 0, 0.3)), (12, (0, 0, 0), z)]}, 12)
    lp.add_action(arm, "attack", {"body": [(1, (-15, 0, 0), z), (6, (25, 0, 0), (0, -0.4, 0.2)), (14, (0, 0, 0), z)]}, 14, loop=False)
    lp.add_action(arm, "hit", {"body": [(1, (0, 0, 0), (0, 0.15, 0)), (8, (0, 0, 0), z)]}, 8, loop=False)
    lp.add_action(arm, "die", {"root": [(1, (0, 0, 0), z), (12, (0, 0, 0), (0, 0, -0.35))]}, 12, loop=False)
    return arm


def biped(cid, color, dark, skeleton=False, weapon=True, big=1.0):
    arm = lp.make_armature("rig_" + cid, lp.BONES)
    m = lp.material("m_%s" % cid, color)
    md = lp.material("m_%s_d" % cid, dark)
    parts = {}
    if skeleton:
        parts["spine"] = (lp.cylinder("spine", 0.06, 0.06, 0.55, (0, 0, 0.65), m, 6), "body")
        for i in range(3):
            parts["rib%d" % i] = (lp.box("rib%d" % i, (0.45, 0.3, 0.05), (0, 0, 0.55 + i * 0.14), m), "body")
    else:
        parts["body"] = (lp.capsule("body", 0.3, 0.5, (0, 0, 0.65), m), "body")
        parts["belt"] = (lp.box("belt", (0.65, 0.65, 0.08), (0, 0, 0.45), md), "body")
    parts["head"] = (lp.sphere("head", 0.3, (0, 0, 1.3), m if skeleton else lp.material("m_skin", (0.98, 0.85, 0.72)), 10, 6), "head")
    parts["hat"] = (lp.sphere("hat", 0.32, (0, 0, 1.4), md, 10, 5, (1, 1, 0.6)), "head")
    for i, sx in enumerate((-1, 1)):
        parts["eye%d" % i] = (lp.box("eye%d" % i, (0.07, 0.03, 0.09), (sx * 0.11, -0.28, 1.3), lp.material("m_eye_red", (0.95, 0.2, 0.2), 1.0)), "head")
    for name, sx in (("arm_r", 1), ("arm_l", -1)):
        parts[name] = (lp.cylinder(name + "_m", 0.07, 0.08, 0.42, (sx * 0.36, 0, 0.66), m, 6), name)
    for name, sx in (("leg_r", 1), ("leg_l", -1)):
        parts[name] = (lp.cylinder(name + "_m", 0.09, 0.1, 0.32, (sx * 0.14, 0, 0.2), md, 6), name)
    if weapon:
        parts["blade"] = (lp.box("blade", (0.07, 0.03, 0.8), (0.36, -0.1, 0.9), lp.material("m_metal", (0.75, 0.75, 0.8))), "arm_r")
    for name, (obj, bone) in parts.items():
        lp.attach(obj, arm, bone)
    lp.humanoid_actions(arm)
    return arm


def spider():
    arm = lp.make_armature("rig_spider", MOB_BONES)
    m = lp.material("m_spider", (0.25, 0.2, 0.3))
    md = lp.material("m_spider_d", (0.15, 0.12, 0.18))
    parts = [(lp.sphere("abdomen", 0.5, (0, 0.35, 0.5), m, 10, 6, (1, 1.3, 0.8)), "body"),
             (lp.sphere("thorax", 0.3, (0, -0.4, 0.45), md, 8, 5), "head")]
    for i, sx in enumerate((-1, 1)):
        parts.append((lp.sphere("eye%d" % i, 0.07, (sx * 0.12, -0.66, 0.55), lp.material("m_eye_red", (1.0, 0.25, 0.2), 1.0), 6, 3), "head"))
        for j in range(4):
            y = -0.35 + j * 0.25
            parts.append((lp.cylinder("leg%d_%d" % (i, j), 0.03, 0.05, 0.9, (sx * 0.55, y, 0.35), md, 4, (0, sx * 1.1, 0)), "leg_fr" if (i, j) in ((1, 0), (0, 2)) else "leg_fl" if (i, j) in ((0, 0), (1, 2)) else "leg_br" if i == 1 else "leg_bl"))
    for obj, bone in parts:
        lp.attach(obj, arm, bone)
    mob_actions(arm, quadruped=True)
    return arm


def ent():
    arm = lp.make_armature("rig_ent", lp.BONES)
    bark = lp.material("m_bark", (0.35, 0.3, 0.2))
    leaf = lp.material("m_leaf", (0.35, 0.6, 0.3))
    parts = {"trunk": (lp.cylinder("trunk", 0.35, 0.5, 1.0, (0, 0, 0.6), bark, 7), "body"),
             "crown": (lp.sphere("crown", 0.6, (0, 0, 1.45), leaf, 8, 5), "head"),
             "face": (lp.box("face", (0.3, 0.1, 0.2), (0, -0.4, 0.75), lp.material("m_eye_y", (0.9, 0.8, 0.2), 1.0)), "body")}
    for name, sx in (("arm_r", 1), ("arm_l", -1)):
        parts[name] = (lp.cylinder(name + "_m", 0.08, 0.14, 0.9, (sx * 0.55, 0, 0.75), bark, 5, (0, sx * 0.4, 0)), name)
    for name, sx in (("leg_r", 1), ("leg_l", -1)):
        parts[name] = (lp.cylinder(name + "_m", 0.14, 0.2, 0.35, (sx * 0.22, 0, 0.18), bark, 5), name)
    for name, (obj, bone) in parts.items():
        lp.attach(obj, arm, bone)
    lp.humanoid_actions(arm)
    return arm


def ghost():
    arm = lp.make_armature("rig_ghost", MOB_BONES)
    m = lp.material("m_ghost", (0.6, 0.9, 1.0), 0.6)
    parts = [(lp.cylinder("body", 0.45, 0.05, 1.3, (0, 0, 0.9), m, 8), "body"),
             (lp.sphere("head", 0.35, (0, 0, 1.6), m, 10, 6), "head")]
    for i, sx in enumerate((-1, 1)):
        parts.append((lp.box("eye%d" % i, (0.08, 0.04, 0.14), (sx * 0.12, -0.33, 1.62), lp.material("m_eye_dark", (0.2, 0.1, 0.3))), "head"))
    for obj, bone in parts:
        lp.attach(obj, arm, bone)
    mob_actions(arm, floating=True)
    return arm


def golem():
    arm = lp.make_armature("rig_golem", lp.BONES)
    rock = lp.material("m_rock", (0.5, 0.5, 0.45))
    core = lp.material("m_core", (0.95, 0.6, 0.2), 3.0)
    parts = {"body": (lp.box("body", (1.1, 0.8, 1.0), (0, 0, 0.8), rock), "body"),
             "head": (lp.box("head", (0.6, 0.6, 0.5), (0, 0, 1.55), rock), "head"),
             "core": (lp.sphere("core", 0.18, (0, -0.42, 0.85), core, 8, 4), "body")}
    for name, sx in (("arm_r", 1), ("arm_l", -1)):
        parts[name] = (lp.box(name + "_m", (0.35, 0.35, 0.9), (sx * 0.8, 0, 0.6), rock), name)
    for name, sx in (("leg_r", 1), ("leg_l", -1)):
        parts[name] = (lp.box(name + "_m", (0.4, 0.4, 0.4), (sx * 0.3, 0, 0.2), rock), name)
    for name, (obj, bone) in parts.items():
        lp.attach(obj, arm, bone)
    lp.humanoid_actions(arm)
    return arm


def dragon():
    arm = quadruped("mob_dragon", (0.8, 0.2, 0.3), (0.5, 0.1, 0.15), head_scale=1.3, body=(1.2, 2.0, 0.9))
    m = lp.material("m_wing", (0.6, 0.15, 0.2))
    for i, sx in enumerate((-1, 1)):
        w = lp.box("wing%d" % i, (1.6, 0.05, 0.9), (sx * 1.2, 0.2, 1.2), m, (0, sx * -0.5, 0))
        lp.attach(w, arm, "body")
    return arm


def build_all(out_dir):
    os.makedirs(out_dir, exist_ok=True)
    builders = {
        "mob_slime": lambda: slime("mob_slime"),
        "mob_boar": lambda: quadruped("mob_boar", (0.5, 0.35, 0.25), (0.3, 0.2, 0.15), tusks=True),
        "mob_wolf": lambda: quadruped("mob_wolf", (0.5, 0.5, 0.55), (0.3, 0.3, 0.35), mane=True),
        "mob_spider": spider,
        "mob_bandit": lambda: biped("mob_bandit", (0.6, 0.25, 0.25), (0.3, 0.15, 0.12)),
        "mob_ent": ent,
        "mob_skeleton": lambda: biped("mob_skeleton", (0.9, 0.9, 0.8), (0.6, 0.6, 0.5), skeleton=True),
        "mob_ghost": ghost,
        "mob_golem": golem,
        "mob_dragon": dragon,
    }
    for name, fn in builders.items():
        lp.clear_scene()
        arm = fn()
        lp.export_glb(os.path.join(out_dir, name + ".glb"), [arm])
    print("monsters done")


if __name__ == "__main__":
    import sys
    out = sys.argv[sys.argv.index("--") + 1] if "--" in sys.argv else os.path.join(os.path.dirname(__file__), "..", "..", "assets", "models")
    build_all(out)
