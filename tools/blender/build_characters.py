"""Gera os 8 personagens chibi (um GLB por classe) + npc_villager, com rig e animações.
Rodar dentro do Blender:
    import sys; sys.path.append(r"<pasta>/ragnaex/tools/blender")
    import build_characters; build_characters.build_all(r"<pasta>/ragnaex/assets/models")
"""
import bpy
import importlib
import os
import lowpoly_lib as lp

importlib.reload(lp)

SKIN = (0.98, 0.85, 0.72)
EYE = (0.12, 0.10, 0.16)
WOOD = (0.50, 0.35, 0.22)
METAL = (0.80, 0.82, 0.88)
GOLD = (0.85, 0.68, 0.30)

CLASSES = {
    # id: (cor principal, cor escura, arma, chapéu)
    "paladin": ((0.95, 0.85, 0.45), (0.55, 0.45, 0.2), "sword_shield", "helm"),
    "berserker": ((0.85, 0.30, 0.25), (0.45, 0.15, 0.12), "axe2h", "horns"),
    "bishop": ((0.95, 0.95, 0.90), (0.55, 0.5, 0.6), "staff", "mitre"),
    "druid": ((0.45, 0.80, 0.35), (0.25, 0.45, 0.2), "staff", "leaf"),
    "ranger": ((0.50, 0.75, 0.55), (0.25, 0.4, 0.3), "bow", "hood"),
    "assassin": ((0.55, 0.35, 0.75), (0.3, 0.15, 0.45), "daggers", "mask"),
    "elementalist": ((0.35, 0.60, 0.95), (0.15, 0.3, 0.6), "wand", "wizard"),
    "necromancer": ((0.40, 0.85, 0.65), (0.15, 0.4, 0.35), "scythe", "skullcap"),
    "npc_villager": ((0.8, 0.75, 0.6), (0.4, 0.35, 0.3), "", "cap"),
}


def build_humanoid(cid, color, dark, weapon, hat):
    arm = lp.make_armature("rig_" + cid)
    m_body = lp.material("m_%s_body" % cid, color)
    m_dark = lp.material("m_%s_dark" % cid, dark)
    m_skin = lp.material("m_skin", SKIN)
    m_eye = lp.material("m_eye", EYE)
    parts = {}
    # corpo (cápsula curta)
    parts["body"] = (lp.capsule("body", 0.28, 0.45, (0, 0, 0.65), m_body), "body")
    # cinto
    parts["belt"] = (lp.box("belt", (0.6, 0.6, 0.08), (0, 0, 0.5), m_dark), "body")
    # cabeça + cabelo/chapéu + olhos
    parts["head"] = (lp.sphere("head", 0.34, (0, 0, 1.3), m_skin, 12, 8), "head")
    for i, sx in enumerate((-1, 1)):
        parts["eye%d" % i] = (lp.box("eye%d" % i, (0.07, 0.03, 0.1), (sx * 0.12, -0.31, 1.3), m_eye), "head")
    if hat == "helm":
        parts["hat"] = (lp.sphere("hat", 0.37, (0, 0, 1.4), lp.material("m_metal", METAL), 10, 6, (1, 1, 0.8)), "head")
        parts["plume"] = (lp.box("plume", (0.06, 0.4, 0.14), (0, 0.05, 1.78), m_body), "head")
    elif hat == "horns":
        parts["hair"] = (lp.sphere("hair", 0.36, (0, 0, 1.42), m_dark, 10, 5, (1, 1, 0.7)), "head")
        for i, sx in enumerate((-1, 1)):
            parts["horn%d" % i] = (lp.cylinder("horn%d" % i, 0.0, 0.07, 0.3, (sx * 0.3, 0, 1.62), lp.material("m_bone", (0.9, 0.88, 0.8)), 6, (0, sx * 0.6, 0)), "head")
    elif hat == "mitre":
        parts["hat"] = (lp.cylinder("hat", 0.02, 0.3, 0.6, (0, 0, 1.8), m_body, 6), "head")
        parts["band"] = (lp.cylinder("band", 0.33, 0.33, 0.1, (0, 0, 1.52), lp.material("m_gold", GOLD), 8), "head")
    elif hat == "leaf":
        parts["hair"] = (lp.sphere("hair", 0.36, (0, 0, 1.42), m_dark, 10, 5, (1, 1, 0.7)), "head")
        parts["leaf"] = (lp.box("leaf", (0.3, 0.12, 0.04), (0.2, 0, 1.7), m_body, (0, 0, 0.5)), "head")
    elif hat == "hood":
        parts["hood"] = (lp.sphere("hood", 0.38, (0, 0.03, 1.38), m_dark, 10, 6), "head")
        parts["hood_tip"] = (lp.cylinder("hood_tip", 0.0, 0.14, 0.35, (0, 0.15, 1.75), m_dark, 6, (-0.5, 0, 0)), "head")
    elif hat == "mask":
        parts["hair"] = (lp.sphere("hair", 0.36, (0, 0, 1.42), m_dark, 10, 5, (1, 1, 0.7)), "head")
        parts["mask"] = (lp.box("mask", (0.5, 0.08, 0.16), (0, -0.3, 1.2), m_dark), "head")
    elif hat == "wizard":
        parts["brim"] = (lp.cylinder("brim", 0.5, 0.5, 0.05, (0, 0, 1.55), m_dark, 10), "head")
        parts["cone"] = (lp.cylinder("cone", 0.0, 0.3, 0.7, (0.05, 0, 1.9), m_body, 8, (0, 0.25, 0)), "head")
    elif hat == "skullcap":
        parts["cap"] = (lp.sphere("cap", 0.36, (0, 0, 1.42), lp.material("m_bone", (0.9, 0.88, 0.8)), 10, 5, (1, 1, 0.65)), "head")
        parts["hair"] = (lp.sphere("hair", 0.35, (0, 0.08, 1.3), m_dark, 10, 5, (1, 0.8, 0.9)), "head")
    else:  # cap
        parts["hair"] = (lp.sphere("hair", 0.36, (0, 0, 1.42), m_dark, 10, 5, (1, 1, 0.7)), "head")
    # braços (cilindros) e mãos
    for name, sx in (("arm_r", 1), ("arm_l", -1)):
        parts[name] = (lp.cylinder(name + "_m", 0.08, 0.1, 0.42, (sx * 0.34, 0, 0.66), m_body, 6), name)
        parts[name + "_hand"] = (lp.sphere(name + "_hand", 0.1, (sx * 0.34, 0, 0.44), m_skin, 8, 4), name)
    # pernas
    for name, sx in (("leg_r", 1), ("leg_l", -1)):
        parts[name] = (lp.cylinder(name + "_m", 0.1, 0.11, 0.3, (sx * 0.14, 0, 0.2), m_dark, 6), name)
        parts[name + "_foot"] = (lp.box(name + "_foot", (0.18, 0.3, 0.12), (sx * 0.14, -0.04, 0.06), m_dark), name)
    # armas
    m_wood = lp.material("m_wood", WOOD)
    m_metal = lp.material("m_metal", METAL)
    hx = 0.34
    if weapon in ("sword_shield",):
        parts["blade"] = (lp.box("blade", (0.08, 0.03, 0.9), (hx, -0.1, 0.9), m_metal), "arm_r")
        parts["guard"] = (lp.box("guard", (0.3, 0.06, 0.06), (hx, -0.1, 0.46), lp.material("m_gold", GOLD)), "arm_r")
        parts["shield"] = (lp.box("shield", (0.45, 0.08, 0.6), (-hx - 0.06, -0.12, 0.7), m_dark), "arm_l")
        parts["shield_boss"] = (lp.sphere("shield_boss", 0.08, (-hx - 0.06, -0.18, 0.7), m_metal, 8, 4), "arm_l")
    elif weapon == "axe2h":
        parts["shaft"] = (lp.cylinder("shaft", 0.035, 0.035, 1.4, (hx, -0.15, 0.9), m_wood, 6), "arm_r")
        parts["axehead"] = (lp.box("axehead", (0.05, 0.5, 0.45), (hx, -0.4, 1.4), m_metal), "arm_r")
    elif weapon == "staff":
        parts["shaft"] = (lp.cylinder("shaft", 0.03, 0.03, 1.6, (hx, -0.12, 1.0), m_wood, 6), "arm_r")
        parts["orb"] = (lp.sphere("orb", 0.14, (hx, -0.12, 1.85), lp.material("m_%s_orb" % cid, color, 2.0), 8, 5), "arm_r")
    elif weapon == "bow":
        parts["bow"] = (lp.cylinder("bow", 0.03, 0.03, 1.1, (-hx - 0.05, -0.2, 0.75), m_wood, 6, (0, 0, 0)), "arm_l")
        parts["string"] = (lp.box("string", (0.01, 0.01, 1.05), (-hx - 0.05, -0.08, 0.75), lp.material("m_string", (0.9, 0.9, 0.9))), "arm_l")
    elif weapon == "daggers":
        for name, sx in (("arm_r", 1), ("arm_l", -1)):
            parts["dag_" + name] = (lp.box("dag_" + name, (0.05, 0.02, 0.45), (sx * hx, -0.12, 0.6), m_metal), name)
    elif weapon == "wand":
        parts["wand"] = (lp.cylinder("wand", 0.02, 0.02, 0.6, (hx, -0.12, 0.65), m_wood, 6), "arm_r")
        parts["orb"] = (lp.sphere("orb", 0.1, (hx, -0.12, 1.0), lp.material("m_%s_orb" % cid, color, 2.0), 8, 5), "arm_r")
    elif weapon == "scythe":
        parts["shaft"] = (lp.cylinder("shaft", 0.03, 0.03, 1.7, (hx, -0.12, 1.0), lp.material("m_bonewood", (0.3, 0.25, 0.3)), 6), "arm_r")
        parts["blade"] = (lp.box("blade", (0.7, 0.03, 0.14), (hx + 0.3, -0.12, 1.85), m_metal, (0, 0.25, 0)), "arm_r")
    for name, (obj, bone) in parts.items():
        lp.attach(obj, arm, bone)
    lp.humanoid_actions(arm, caster=weapon in ("staff", "wand", "scythe"))
    return arm


def build_all(out_dir):
    os.makedirs(out_dir, exist_ok=True)
    for cid, (color, dark, weapon, hat) in CLASSES.items():
        lp.clear_scene()
        arm = build_humanoid(cid, color, dark, weapon, hat)
        lp.export_glb(os.path.join(out_dir, "%s.glb" % cid), [arm])
    print("characters done")


if __name__ == "__main__":
    import sys
    out = sys.argv[sys.argv.index("--") + 1] if "--" in sys.argv else os.path.join(os.path.dirname(__file__), "..", "..", "assets", "models")
    build_all(out)
